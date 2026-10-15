-- MarketService.luau : C-5 / C-7 the player market, one for every server (게임성 개발 2, 2026-10-13). SPEC A23-127 / A23-133;
-- design docs/design/market_server_2026-10-13.md; window MarketWindow.luau (게임성 개발 4, market_window_2026-10-12.md §6).
-- Truth = the ledger DataStore (Config.Market.Store, "L_<id>"); the MemoryStore maps only list what is open (Maps .. key,
-- IndexMap, SoldMap: hints). Money and things are always in exactly one place: the seller's save -> the ledger row -> the
-- buyer's save. Rule: first my own save (DataService.Save must succeed), then the ledger, then the maps.
--   List   : checks -> the things leave my bag, Out[id] = Pend -> save -> ledger row (only if none) Open -> Out Open -> maps
--   Buy    : checks -> gold leaves, In[id] = Pay -> save -> ledger Open -> Sold + Buyer = me (one UpdateAsync; two buyers =
--            one wins) -> the thing to me, Done; the loser gets the gold back
--   Pay    : the seller's server (a SoldMap hint every PollSeconds, every open row from the ledger every LedgerSeconds, at
--            join) sees Sold -> total - Fee as bank gold "Market" (never 2x), Done -> the ledger Paid = true
--   Cancel / end : ledger Open -> Cancel / Expired (the same key as Buy: only one wins) -> the things back to the bag
--   Join   : every Out / In row is checked against the ledger (Pend, Pay, Sold, ended, things still owed) - Done ids are
--            never paid twice, so a server that stops between two steps loses nothing
-- Switch off: no new listing or purchase ("Off"), no window answers; a cancel and every settling still work.
-- Remotes (c->s, all rate-limited): MarketIndex(), MarketBrowse(key, page), MarketMine(), MarketList(kind, id, n, price),
-- MarketBuy(id, price), MarketCancel(id), PackWeapon(tier), UnpackSpare(key "T:P"). s->c: MarketIndex { Rows = { { Key,
-- Low, Count } }, At, Gate }, MarketPage { Key, Page, Pages, Rows = { { Id, Price, N, Plus, Left } }, Ref, Min, Max },
-- MarketMine { Rows = { { Id, Key, N, Plus, Price, State, Left, Paid } }, Waiting, Today = { Lists, Buys }, Gate }.
-- Gate = { Buy = "" | a refusal key, List = "" | a refusal key, ListIn = s until the next List }. Notices = Net.Notify
-- lines of Config.Market.Text. Signals Listed / Bought / Paid (player) for the market quests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local MarketService = {}
MarketService.Listed = Util.Signal.new() -- (player) a listing went open
MarketService.Bought = Util.Signal.new() -- (player) a purchase was delivered
MarketService.Paid = Util.Signal.new() -- (player, gold) a sale was paid to its seller

local TAG = "MarketService"
local S = nil
local M = Config.Market
local ST = {
	Ledger = nil, -- the DataStore (false = could not get it)
	Maps = {}, -- [market key] = MemoryStore sorted map
	IndexMap = nil, SoldMap = nil,
	Index = nil, -- { At = os.clock(), Rows }
	Pages = {}, -- [market key] = { At = os.clock(), Rows = { { Id, Price, N, X, Seller } } }
	Busy = {}, -- [player] = true while a market step of that player runs
	ListAt = {}, -- [player] = os.clock() of the last accepted List
	LedgerAt = {}, -- [player] = os.clock() of the last full ledger read of its open rows
	Warned = {}, -- [what] = os.clock() (warnings at most once a minute)
	GetOpts = nil, -- review 10/14: DataStoreGetOptions with UseCache = false (false = could not make one)
}

------------------------------------------------------------------ small helpers
local function num(v, d)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function warnOnce(what, err)
	local now = os.clock()
	if ST.Warned[what] and now - ST.Warned[what] < 60 then return end
	ST.Warned[what] = now
	Util.Warn(TAG, what .. ": " .. tostring(err))
end

-- Config.Features.Market (the build) AND the live switch Market (SwitchService; no switch service or a failed read = on)
local function switchOn()
	if not (type(Config.FeatureOn) == "function" and Config.FeatureOn("Market") == true) then return false end
	local sw = S and S.SwitchService
	if type(sw) ~= "table" or type(sw.On) ~= "function" then return true end
	local ok, value = pcall(sw.On, "Market")
	return not ok or value ~= false
end

-- the saves are real (not Studio's memory mode): nothing in the market works without them
local function persistent()
	local ok, ready = pcall(function() return S.DataService.IsPersistentReady() end)
	return ok and ready == true
end

local function note(player, key, ...)
	local text = M.Text[key]
	if type(text) ~= "string" then return end
	if select("#", ...) > 0 then
		local ok, s = pcall(string.format, text, ...)
		text = ok and s or text
	end
	local kind = (key == "MarketBought" or key == "MarketPaid" or key == "MarketListed") and "reward"
		or ((key == "MarketCancelled" or key == "MarketExpired" or key == "MarketRefund" or key == "Checking") and "info" or "bad")
	pcall(Net.Notify, player, text, kind)
end

local function dataOf(player)
	local ok, d = pcall(S.PlayerService.GetData, player)
	return ok and type(d) == "table" and d or nil
end

-- the save's Market table (repaired at load by Config.SanitizeMarket); a new KST day starts the day counters over
local function marketOf(data)
	local m = data.Market
	if type(m) ~= "table" then
		m = Config.SanitizeMarket(nil)
		data.Market = m
	end
	if type(m.Out) ~= "table" then m.Out = {} end
	if type(m.In) ~= "table" then m.In = {} end
	if type(m.Done) ~= "table" then m.Done = {} end
	local today = Config.DayIndex(os.time())
	if m.Day ~= today then
		m.Day, m.Lists, m.Buys = today, 0, 0
		for k in m do
			if type(k) == "string" and string.match(k, "^P%d+$") then m[k] = nil end -- the day's purchases per seller
		end
	end
	m.Lists, m.Buys = math.floor(num(m.Lists, 0)), math.floor(num(m.Buys, 0))
	return m
end

local function isDone(m, id)
	return table.find(m.Done, id) ~= nil
end

local function markDone(m, id)
	if isDone(m, id) then return end
	table.insert(m.Done, id)
	while #m.Done > Config.SaveV4.MarketDone do table.remove(m.Done, 1) end
end

local function openRows(m)
	local n = 0
	for _, r in m.Out do
		if r.St == "Open" then n += 1 end -- a Pend row is an Open row with Pend = true
	end
	return n
end

local function nameOf(player, key)
	local info = Config.MarketParse(key)
	if not info then return key end
	if info.Kind == "I" then return Config.Loot.Items[info.Id].Name end
	local ok, class = pcall(S.ClassService.GetClass, player)
	local w = Config.WeaponName(info.Tier, ok and class or "Warrior", player:GetAttribute("Faction"))
	return info.Plus > 0 and string.format("%s +%d", w, info.Plus) or w
end

-- A23-133 the market quests: a named happening for StoryQuestService (Config.StoryQuests.Events) + our own signal
local function happened(player, signal, name, ...)
	pcall(signal.Fire, signal, player, ...)
	local sq = S.StoryQuestService
	if type(sq) == "table" and type(sq.Event) == "function" then
		local ok, err = pcall(sq.Event, player, name)
		if not ok then warnOnce("quest event", err) end
	end
end

-- a forced save of the player's data (yields); true only when it reached the DataStore
local function saveNow(player)
	local ok, saved = pcall(S.DataService.Save, player, false)
	if not ok then warnOnce("save", saved) end
	return ok and saved == true
end

------------------------------------------------------------------ the gates (the client never computes them)
local function gateOf(player, data)
	local m = marketOf(data)
	local level = math.floor(num(data.Level, 1))
	local g = { Buy = "", List = "", ListIn = 0 }
	if not switchOn() then
		g.Buy, g.List = "Off", "Off"
		return g
	end
	if not persistent() then
		g.Buy, g.List = "Resting", "Resting"
		return g
	end
	if level < M.BuyLevel then
		g.Buy = "NeedLevelBuy"
	elseif m.Buys >= M.DayBuys then
		g.Buy = "DayLimit"
	end
	local age = 0
	pcall(function() age = player.AccountAge end)
	if level < M.ListLevel then
		g.List = "NeedLevelList"
	elseif num(data.PlaytimeSeconds, 0) < M.ListPlaySeconds then
		g.List = "NeedPlaytime"
	elseif num(age, 0) < M.ListAccountDays then
		g.List = "NeedAccountAge"
	elseif openRows(m) >= M.OpenMax then
		g.List = "TooMany"
	elseif m.Lists >= M.DayLists then
		g.List = "DayLimit"
	end
	local last = ST.ListAt[player]
	if last then g.ListIn = math.max(0, math.ceil(Config.RateLimits.MarketList - (os.clock() - last))) end
	return g
end

------------------------------------------------------------------ the ledger (DataStore)
local function ledger()
	if ST.Ledger == nil then
		local ok, store = pcall(function() return DataStoreService:GetDataStore(Config.StoreName(M.Store)) end)
		ST.Ledger = ok and store or false
		if not ok then warnOnce("ledger", store) end
	end
	return ST.Ledger or nil
end

-- review 10/14: the ledger is read past the server's ~4 s GetAsync cache (a write that errored but landed is seen)
local function getOpts()
	if ST.GetOpts == nil then
		local ok, o = pcall(Instance.new, "DataStoreGetOptions")
		if ok and o then
			local okU = pcall(function() o.UseCache = false end)
			ST.GetOpts = okU and o or false
		else
			ST.GetOpts = false
		end
	end
	return ST.GetOpts or nil
end

-- (ok, record): ok = the read worked (record nil = no row)
local function lget(id)
	local store = ledger()
	if not store then return false, nil end
	local ok, v = pcall(store.GetAsync, store, "L_" .. id, getOpts())
	if not ok then
		warnOnce("ledger read", v)
		return false, nil
	end
	return true, type(v) == "table" and v or nil
end

-- (ok, record after): fn(old) returns the new record or nil (no change)
local function lupdate(id, fn)
	local store = ledger()
	if not store then return false, nil end
	local ok, v = pcall(store.UpdateAsync, store, "L_" .. id, function(old)
		return fn(type(old) == "table" and old or nil)
	end)
	if not ok then
		warnOnce("ledger write", v)
		return false, nil
	end
	return true, type(v) == "table" and v or nil
end

------------------------------------------------------------------ the maps (MemoryStore: hints, never money)
local function sortedMap(name)
	local ok, map = pcall(function() return MemoryStoreService:GetSortedMap(Config.StoreName(name)) end)
	if not ok then warnOnce("map", map) end
	return ok and map or nil
end

local function mapOf(key)
	local map = ST.Maps[key]
	if map == nil then
		map = sortedMap(M.Maps .. string.gsub(key, ":", "_")) or false
		ST.Maps[key] = map
	end
	return map or nil
end

local function indexMap()
	if ST.IndexMap == nil then ST.IndexMap = sortedMap(M.IndexMap) or false end
	return ST.IndexMap or nil
end

local function soldMap()
	if ST.SoldMap == nil then ST.SoldMap = sortedMap(M.SoldMap) or false end
	return ST.SoldMap or nil
end

-- the open rows of one key, cheapest first (PageFetch at most); nil = the map could not be read
local function readKey(key)
	local map = mapOf(key)
	if not map then return nil end
	local ok, list = pcall(map.GetRangeAsync, map, Enum.SortDirection.Ascending, M.PageFetch)
	if not ok then
		warnOnce("map read", list)
		return nil
	end
	local rows, now = {}, os.time()
	for _, e in type(list) == "table" and list or {} do
		local v = type(e) == "table" and e.value or nil
		if type(v) == "table" and type(e.key) == "string" and num(v.x, 0) > now then
			table.insert(rows, { Id = e.key, Price = math.floor(num(v.p, 0)), N = math.floor(num(v.n, 1)), X = v.x, Seller = v.s })
		end
	end
	table.sort(rows, function(a, b)
		if a.Price ~= b.Price then return a.Price < b.Price end
		return a.Id < b.Id
	end)
	ST.Pages[key] = { At = os.clock(), Rows = rows }
	return rows
end

-- the index row of a key from its map (lowest price, open rows); one write
local function refreshIndex(key, rows)
	rows = rows or readKey(key)
	local im = indexMap()
	if not rows or not im then return end
	local low, n = nil, 0
	for _, r in rows do
		n += 1
		low = low and math.min(low, r.Price) or r.Price
	end
	local ok, err
	if n == 0 then
		ok, err = pcall(im.RemoveAsync, im, key)
	else
		ok, err = pcall(im.SetAsync, im, key, { L = low, C = n }, M.IndexTTL)
	end
	if not ok then warnOnce("index write", err) end
	ST.Index = nil
end

-- puts an open listing in its key's map (true = done)
local function mapPut(id, rec)
	local map = mapOf(rec.K)
	if not map then return false end
	local ttl = math.max(60, math.floor(num(rec.Exp, 0) - os.time()) + M.MapTTL)
	local ok, err = pcall(map.SetAsync, map, id, { p = rec.Price, n = rec.N, x = rec.Exp, s = rec.Seller }, ttl, rec.Price)
	if not ok then
		warnOnce("map write", err)
		return false
	end
	refreshIndex(rec.K)
	return true
end

local function mapDrop(key, id)
	local map = mapOf(key)
	if not map then return end
	local ok, err = pcall(map.RemoveAsync, map, id)
	if not ok then warnOnce("map remove", err) end
	refreshIndex(key)
end

-- the seller's hint: these ids were sold (its server pays sooner than the ledger round)
local function hintSold(sellerId, id)
	local sm = soldMap()
	if not sm then return end
	local ok, err = pcall(sm.UpdateAsync, sm, tostring(sellerId), function(old)
		local list = type(old) == "table" and old or {}
		if not table.find(list, id) then table.insert(list, id) end
		while #list > 50 do table.remove(list, 1) end
		return list
	end, M.Hours * 3600 + M.MapTTL)
	if not ok then warnOnce("sold hint", err) end
end

local function takeHints(player)
	local sm = soldMap()
	if not sm then return {} end
	local ok, list = pcall(sm.GetAsync, sm, tostring(player.UserId))
	if not ok or type(list) ~= "table" or #list == 0 then return {} end
	pcall(sm.RemoveAsync, sm, tostring(player.UserId)) -- the ledger is read for each; a lost hint only waits for the round
	return list
end

------------------------------------------------------------------ things in and out of the bag
-- gives `n` of a key back (items up to the cap, spares while there is room); the number that did NOT fit
local function giveThing(player, data, key, n)
	local info = Config.MarketParse(key)
	if not info then return 0 end -- a key that cannot be given (a removed item): nothing more to do
	if info.Kind == "I" then
		local left = n
		while left > 0 do
			local ok, got = pcall(S.LootService.GrantItem, player, info.Id, math.min(99, left))
			got = ok and math.floor(num(got, 0)) or 0
			if got <= 0 then break end
			left -= got
		end
		return left
	end
	local left = n
	while left > 0 do
		local ok, got = pcall(S.LootService.AddSpare, player, info.Tier, info.Plus)
		if not ok or got ~= true then break end
		left -= 1
	end
	return left
end

-- room for `n` of a key in this bag
local function hasRoom(data, key, n)
	local info = Config.MarketParse(key)
	if not info then return false end
	local counts = Config.BagSlots.Counts
	if info.Kind == "I" then
		local items = type(data.Items) == "table" and data.Items or {}
		local have = math.floor(num(items[info.Id], 0))
		-- bag slots (10/14): a new kind needs a free slot
		local def = Config.Loot.Items[info.Id]
		if have < 1 and def and counts[def.Kind] and not Config.BagHasRoom(data) then return false end
		return have + n <= Config.Loot.ItemCap
	end
	local spares = type(data.Spares) == "table" and data.Spares or {}
	local sum = 0
	for _, c in spares do sum += math.max(0, math.floor(num(c, 0))) end
	local key2 = string.format("%d:%d", info.Tier, info.Plus)
	-- bag slots (10/14): a new spare key needs a free slot (a tier not owned yet is owned, no slot)
	local owned = bit32.btest(math.floor(num(data.WeaponOwnedMask, 0)), bit32.lshift(1, info.Tier - 1))
	if owned and math.floor(num(spares[key2], 0)) < 1 and counts.Spare and not Config.BagHasRoom(data) then return false end
	return math.floor(num(spares[key2], 0)) + n <= Config.SaveV4.SpareKeyMax and sum + n <= Config.SaveV4.SpareSum
end

local function ownsTier(data, tier)
	local mask = math.floor(num(data.WeaponOwnedMask, 0))
	return mask >= 1 and bit32.btest(mask, bit32.lshift(1, tier - 1))
end

------------------------------------------------------------------ settling (seller side and buyer side)
-- an Out row whose listing ended unsold (Cancel / Expired): the things go back; a row whose things do not fit waits (Ret)
local function giveBack(player, data, id, row, state)
	local m = marketOf(data)
	if isDone(m, id) then return end
	row.St, row.Pend = state, nil
	local left = giveThing(player, data, row.K, math.floor(num(row.N, 0)))
	if left > 0 then
		row.N, row.Ret = left, true
		return
	end
	row.Ret, row.Fin = nil, os.time()
	markDone(m, id)
	note(player, state == "Cancel" and "MarketCancelled" or "MarketExpired")
end

-- a Sold listing: the seller is paid once (Done), then the ledger is marked Paid
local function payOut(player, data, id, row, rec)
	local m = marketOf(data)
	if isDone(m, id) then return end
	local total = math.floor(num(rec.Price, 0)) * math.floor(num(rec.N, 0))
	local get = total - math.floor(total * M.Fee)
	local ok, added = pcall(S.ProgressionService.AddBankGold, player, get, "Market")
	if not ok then
		warnOnce("pay", added)
		return
	end
	row.St, row.Fin, row.Ret, row.Pend = "Paid", os.time(), nil, nil
	markDone(m, id)
	note(player, "MarketPaid", Util.FormatInt(get))
	happened(player, MarketService.Paid, "MarketPaid", get)
	task.spawn(function()
		if saveNow(player) then
			lupdate(id, function(old)
				if old and old.St == "Sold" and old.Paid ~= true then
					old.Paid = true
					return old
				end
				return nil
			end)
		end
	end)
end

-- one Out row against its ledger record (rec nil = no record). Ends an open listing past its time.
local function settleOut(player, data, id, rec)
	local m = marketOf(data)
	local row = m.Out[id]
	if not row or isDone(m, id) then return end
	if row.Ret then -- things still owed back from an earlier end
		giveBack(player, data, id, row, row.St)
		return
	end
	if row.St == "Paid" or row.St == "Cancel" or row.St == "Expired" then return end -- finished (kept for the Mine tab)
	if rec == nil and row.Pend == true then
		-- review 10/14 BLOCK 1: "no ledger row" is decided IN the ledger: a tombstone (Cancel) is written where the row would
		-- be, so a listing write still on its way (another session of mine, a closing server) can never create it later
		local uid, won = player.UserId, false
		local ok = lupdate(id, function(old)
			won = false
			if old ~= nil then return nil end
			won = true
			return { Id = id, Seller = uid, K = row.K, St = "Cancel", At = os.time(), Tomb = true }
		end)
		if not ok then return end -- tried again at the next round
		if won then
			giveBack(player, data, id, row, "Cancel") -- never published: the things come back
			return
		end
		local okR, now = lget(id) -- the listing landed after all: settle it as it is
		if okR and now and now.Seller == player.UserId then settleOut(player, data, id, now) end
		return
	end
	if rec == nil or rec.Seller ~= player.UserId then
		-- a row under my id that is someone else's: my listing never landed (never public): the things come back
		if rec ~= nil and row.Pend == true then giveBack(player, data, id, row, "Cancel") end
		return
	end
	if rec.Paid == true then -- paid by a save of ours already (the ledger is marked only after that save)
		row.St, row.Fin = "Paid", os.time()
		markDone(m, id)
		return
	end
	if rec.St == "Open" then
		if row.Pend == true then
			row.Pend, row.Idx = nil, false
		end
		if os.time() >= num(rec.Exp, 0) then
			local won = false
			local ok = lupdate(id, function(old)
				won = false
				if old and old.St == "Open" and os.time() >= num(old.Exp, 0) then
					old.St = "Expired"
					won = true
					return old
				end
				return nil
			end)
			if ok and won then
				giveBack(player, data, id, row, "Expired")
				mapDrop(row.K, id)
			elseif ok then
				local okR, now = lget(id) -- someone bought it first
				if okR and now and now.St == "Sold" then payOut(player, data, id, row, now) end
			end
			return
		end
		if row.Idx == false and mapPut(id, rec) then row.Idx = nil end
		return
	end
	if rec.St == "Sold" then
		payOut(player, data, id, row, rec)
	elseif rec.St == "Cancel" or rec.St == "Expired" then
		giveBack(player, data, id, row, rec.St)
	end
end

-- the thing bought goes to the buyer once (Done); a thing that does not fit waits in the In row
local function deliver(player, data, id, row)
	local m = marketOf(data)
	if isDone(m, id) then
		m.In[id] = nil
		return
	end
	local info = Config.MarketParse(row.K)
	local n = math.floor(num(row.N, 0))
	local left = 0
	if info and info.Kind == "W" then
		for _ = 1, n do
			local ok, got = pcall(S.LootService.GrantMarketWeapon, player, info.Tier, info.Plus)
			if not ok or got == nil then left += 1 end
		end
	elseif info then
		left = giveThing(player, data, row.K, n)
	end
	if left > 0 then
		row.N, row.Ret = left, true
		return
	end
	m.In[id] = nil
	markDone(m, id)
	note(player, "MarketBought", nameOf(player, row.K))
	happened(player, MarketService.Bought, "MarketBought")
end

local function refund(player, data, id, row)
	local m = marketOf(data)
	if isDone(m, id) then
		m.In[id] = nil
		return
	end
	local gold = math.floor(num(row.Price, 0))
	local ok, err = pcall(S.ProgressionService.AddBankGold, player, gold, "MarketRefund")
	if not ok then
		warnOnce("refund", err)
		return
	end
	m.In[id] = nil
	markDone(m, id)
	note(player, "MarketRefund", Util.FormatInt(gold))
end

-- one In row (a purchase paid) against its ledger record
local function settleIn(player, data, id, rec)
	local m = marketOf(data)
	local row = m.In[id]
	if not row then return end
	if row.Ret then
		deliver(player, data, id, row)
		return
	end
	local uid = player.UserId
	if rec and rec.St == "Sold" and rec.Buyer == uid then
		deliver(player, data, id, row)
		return
	end
	if rec and rec.St == "Open" then
		-- review 10/14 BLOCK 2: the listing is still open, so this attempt's write may still be on its way: void the attempt
		-- (Void[Tok]) in the ledger first; the purchase write refuses a voided attempt. A row without a token waits.
		local tok = row.Tok
		if type(tok) ~= "string" or tok == "" then return end
		local voided, mine = false, false
		local ok = lupdate(id, function(old)
			voided, mine = false, false
			if old and old.St == "Sold" and old.Buyer == uid then
				mine = true
				return nil
			end
			if old and old.St == "Open" then
				old.Void = type(old.Void) == "table" and old.Void or {}
				old.Void[tok] = true
				voided = true
				return old
			end
			voided = true -- ended or someone else's: this attempt can never land
			return nil
		end)
		if not ok then return end -- tried again at the next round
		if mine then
			deliver(player, data, id, row)
		elseif voided then
			refund(player, data, id, row)
		end
		return
	end
	refund(player, data, id, row) -- the purchase never landed (gone, ended or someone else's): it never can now
end

------------------------------------------------------------------ the owner's round (hints, ended rows, retries, join)
-- full = read every open row from the ledger (the join, LedgerSeconds); else only hints, ended rows and owed things
local function round(player, full)
	local data = dataOf(player)
	if not data or ST.Busy[player] then return end
	ST.Busy[player] = true
	local ok, err = pcall(function()
		local m = marketOf(data)
		local now = os.time()
		local hinted = {}
		for _, id in takeHints(player) do hinted[id] = true end
		local ids = {}
		for id in m.Out do table.insert(ids, id) end
		table.sort(ids)
		for _, id in ids do
			local row = m.Out[id]
			if row and not isDone(m, id) then
				local due = full or hinted[id] or row.Pend == true or row.Ret or row.Idx == false
					or ((row.St == "Open") and now >= num(row.Exp, 0))
				if due then
					if row.Ret then
						settleOut(player, data, id, nil)
					else
						local okR, rec = lget(id)
						if okR then settleOut(player, data, id, rec) end
					end
				end
			end
		end
		local ins = {}
		for id in m.In do table.insert(ins, id) end
		table.sort(ins)
		for _, id in ins do
			local row = m.In[id]
			if row then
				if row.Ret then
					settleIn(player, data, id, nil)
				elseif full or row.Pay == true then
					local okR, rec = lget(id)
					if okR then settleIn(player, data, id, rec) end
				end
			end
		end
		-- finished rows leave the Mine tab after KeepFinished
		for id, row in m.Out do
			if (row.St == "Paid" or row.St == "Cancel" or row.St == "Expired") and not row.Ret
				and now - num(row.Fin, now) >= M.KeepFinished then
				m.Out[id] = nil
			end
		end
	end)
	ST.Busy[player] = nil
	if not ok then warnOnce("round", err) end
end

------------------------------------------------------------------ answers to the window
local function plusOf(key)
	local info = Config.MarketParse(key)
	return info and info.Kind == "W" and info.Plus or 0
end

local function sendMine(player)
	local data = dataOf(player)
	if not data then return end
	local m = marketOf(data)
	local rows, now = {}, os.time()
	local ids = {}
	for id in m.Out do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local ra, rb = m.Out[a], m.Out[b]
		if num(ra.At, 0) ~= num(rb.At, 0) then return num(ra.At, 0) > num(rb.At, 0) end
		return a < b
	end)
	for _, id in ids do
		local r = m.Out[id]
		local state = r.St == "Open" and "Open" or (r.St == "Paid" and "Sold" or r.St)
		table.insert(rows, { Id = id, Key = r.K, N = r.N, Plus = plusOf(r.K), Price = r.Price, State = state,
			Left = state == "Open" and math.max(0, num(r.Exp, now) - now) or 0, Paid = r.St == "Paid" })
	end
	local waiting = 0
	for _ in m.In do waiting += 1 end
	Net.Get("MarketMine"):FireClient(player, { Rows = rows, Waiting = waiting, Today = { Lists = m.Lists, Buys = m.Buys },
		Gate = gateOf(player, data) })
end

local function sendIndex(player)
	local data = dataOf(player)
	if not data then return end
	local idx = ST.Index
	if not idx or os.clock() - idx.At >= M.IndexCache then
		local im = indexMap()
		local rows = {}
		if im then
			local ok, list = pcall(im.GetRangeAsync, im, Enum.SortDirection.Ascending, 200)
			if ok then
				for _, e in type(list) == "table" and list or {} do
					local v = type(e) == "table" and e.value or nil
					if type(v) == "table" and Config.MarketParse(e.key) and num(v.C, 0) >= 1 then
						table.insert(rows, { Key = e.key, Low = math.floor(num(v.L, 0)), Count = math.floor(num(v.C, 0)) })
					end
				end
				idx = { At = os.clock(), Rows = rows }
				ST.Index = idx
			else
				warnOnce("index read", list)
			end
		end
	end
	Net.Get("MarketIndex"):FireClient(player, { Rows = idx and idx.Rows or {}, At = os.time(), Gate = gateOf(player, data) })
end

local function sendPage(player, key, page)
	local ref, lo, hi = Config.MarketRange(key)
	if not ref then return end
	local cache = ST.Pages[key]
	local rows = cache and os.clock() - cache.At < M.PageCache and cache.Rows or nil
	if not rows then
		rows = readKey(key)
		if rows then refreshIndex(key, rows) end -- the index heals from what we just read
	end
	local mine, now = {}, os.time()
	for _, r in rows or {} do
		if r.Seller ~= player.UserId and num(r.X, 0) > now then table.insert(mine, r) end
	end
	local pages = math.max(1, math.ceil(#mine / M.PageRows))
	page = math.clamp(page, 1, pages)
	local out = {}
	for i = (page - 1) * M.PageRows + 1, math.min(#mine, page * M.PageRows) do
		local r = mine[i]
		table.insert(out, { Id = r.Id, Price = r.Price, N = r.N, Plus = plusOf(key), Left = math.max(0, num(r.X, now) - now) })
	end
	Net.Get("MarketPage"):FireClient(player, { Key = key, Page = page, Pages = pages, Rows = out, Ref = ref, Min = lo, Max = hi })
end

------------------------------------------------------------------ the actions
-- a remote's common checks: ready, the rate limit, one step at a time. Returns the data or nil (refused, noted)
local function begin(player, name, quiet)
	if not S.PlayerService.IsReady(player) then return nil end
	if not Util.RateLimit(player, name, Config.RateLimits[name] or 1) then
		if not quiet then note(player, "TooFast") end
		return nil
	end
	if ST.Busy[player] then
		if not quiet then note(player, "TooFast") end
		return nil
	end
	return dataOf(player)
end

local function doList(player, data, kind, id, n, price)
	local g = gateOf(player, data)
	if g.List ~= "" then return note(player, g.List) end
	local key = Config.MarketKey(kind, id)
	if not key then return note(player, "CantSell") end
	local info = Config.MarketParse(key)
	if info.Kind == "W" and n ~= 1 then return note(player, "CantSell") end
	local _, lo, hi = Config.MarketRange(key)
	if price < lo or price > hi then return note(player, "PriceRange") end
	if info.Kind == "I" then
		local items = type(data.Items) == "table" and data.Items or {}
		if math.floor(num(items[info.Id], 0)) < n then return note(player, "NoItem") end
		-- A23-206: bound quest rewards never leave the character (the free ones of the same item still list)
		local okB, free = pcall(S.LootService.Bound, player, info.Id)
		if okB and type(free) == "number" and free < n then return note(player, "Bound") end
		if not S.LootService.TakeItem(player, info.Id, n, "Trade") then return note(player, "NoItem") end
	else
		if not S.LootService.TakeSpare(player, info.Tier, info.Plus, n) then return note(player, "NoItem") end
	end
	local m = marketOf(data)
	-- review 10/14b: the save keeps at most SaveV4.MarketRows rows a side; one more would be dropped at the next load
	local outRows = 0
	for _ in m.Out do outRows += 1 end
	if outRows >= Config.SaveV4.MarketRows then
		giveThing(player, data, key, n) -- the things were taken above: back at once (nothing public)
		return note(player, "Full")
	end
	local lid = string.gsub(HttpService:GenerateGUID(false), "[{}]", "")
	local now = os.time()
	local row = { K = key, N = n, Price = price, St = "Open", Pend = true, At = now, Exp = now + M.Hours * 3600 }
	m.Out[lid] = row
	m.Lists += 1
	ST.ListAt[player] = os.clock()
	if not saveNow(player) then -- nothing is public yet: undo
		m.Lists -= 1
		-- review 10/14 FIX: what does not fit back (the bag filled while the save waited) stays owed (Ret), never lost
		local left = giveThing(player, data, key, n)
		if left > 0 then
			row.St, row.Pend, row.N, row.Ret = "Cancel", nil, left, true
		else
			m.Out[lid] = nil
		end
		return note(player, "Resting")
	end
	local rec = { Id = lid, Seller = player.UserId, K = key, N = n, Price = price, At = now, Exp = row.Exp, St = "Open" }
	local created = false
	local ok = lupdate(lid, function(old)
		created = false
		if old ~= nil then return nil end
		created = true
		return rec
	end)
	if not ok then
		local okR, now2 = lget(lid)
		if okR and now2 == nil then -- it never landed: undo (the Pend row is settled the same way at a join)
			settleOut(player, data, lid, nil)
			return note(player, "Resting")
		end
		if not (okR and now2 and now2.Seller == player.UserId) then return note(player, "Checking") end -- the round finishes it
	elseif not created then
		return note(player, "Checking")
	end
	row.Pend = nil
	if not mapPut(lid, rec) then row.Idx = false end
	note(player, "MarketListed")
	happened(player, MarketService.Listed, "MarketListed")
end

local function doBuy(player, data, id, price)
	local g = gateOf(player, data)
	if g.Buy ~= "" then return note(player, g.Buy) end
	local m = marketOf(data)
	if m.In[id] or isDone(m, id) then return note(player, "AlreadySold") end
	local okR, rec = lget(id)
	if not okR then return note(player, "Resting") end
	if not rec or rec.St ~= "Open" or os.time() >= num(rec.Exp, 0) then
		if rec and type(rec.K) == "string" then mapDrop(rec.K, id) end
		return note(player, "AlreadySold")
	end
	if rec.Seller == player.UserId then return note(player, "Own") end
	if math.floor(num(rec.Price, -1)) ~= price then return note(player, "PriceChanged") end
	local info = Config.MarketParse(rec.K)
	local n = math.floor(num(rec.N, 0))
	if not info or n < 1 then return note(player, "AlreadySold") end
	-- GPT review ② (10/14): a tier owned may still be bought at a higher +N (it comes as a spare: UnpackSpare swaps it in)
	if info.Kind == "W" and ownsTier(data, info.Tier)
		and info.Plus <= math.floor(num(type(data.WeaponEnhance) == "table" and data.WeaponEnhance[info.Tier])) then
		return note(player, "Owned")
	end
	if info.Kind == "I" and not hasRoom(data, rec.K, n) then return note(player, "CantReceive") end
	local pairKey = "P" .. tostring(math.floor(num(rec.Seller, 0)))
	if math.floor(num(m[pairKey], 0)) >= M.PairDay then return note(player, "PairLimit") end
	local inRows = 0
	for _ in m.In do inRows += 1 end
	if inRows >= Config.SaveV4.MarketRows then return note(player, "Full") end -- review 10/14b (the save's row cap)
	local total = price * n
	if not S.ProgressionService.SpendGold(player, total, "Market") then return note(player, "NotEnoughGold") end
	local tok = string.sub(string.gsub(HttpService:GenerateGUID(false), "[{}%-]", ""), 1, 16) -- review 10/14 BLOCK 2
	local row = { Price = total, St = "Sold", Pay = true, K = rec.K, N = n, Tok = tok }
	m.In[id] = row
	m.Buys += 1
	m[pairKey] = math.floor(num(m[pairKey], 0)) + 1
	if not saveNow(player) then -- nothing changed in the market: undo
		m.In[id] = nil
		m.Buys -= 1
		m[pairKey] = math.max(0, m[pairKey] - 1)
		pcall(S.ProgressionService.AddBankGold, player, total, "MarketRefund")
		return note(player, "Resting")
	end
	local won = false
	local uid = player.UserId
	local ok, after = lupdate(id, function(old)
		won = false
		if old and old.St == "Open" and os.time() < num(old.Exp, 0) and old.Seller ~= uid and old.Price == rec.Price
			and old.N == rec.N and not (type(old.Void) == "table" and old.Void[tok]) then
			old.St, old.Buyer, old.SoldAt = "Sold", uid, os.time()
			won = true
			return old
		end
		return nil
	end)
	if not ok then
		local okA, again = lget(id) -- the write may have landed before the error
		if not okA then return note(player, "Checking") end -- the In row stays Pay; the round settles it
		-- review 10/14b: the errored write may still land later: settle as the round does (an Open row is voided first,
		-- Sold to me = delivered), never a bare refund
		local mine = again ~= nil and again.St == "Sold" and again.Buyer == uid
		settleIn(player, data, id, again)
		if mine then hintSold(rec.Seller, id) end
		if not (again and again.St == "Open") then mapDrop(rec.K, id) end
		return
	end
	if won then
		deliver(player, data, id, row)
		hintSold(rec.Seller, id)
		mapDrop(rec.K, id)
	else
		refund(player, data, id, row)
		if not (after and after.St == "Open") then mapDrop(rec.K, id) end
	end
end

local function doCancel(player, data, id)
	local m = marketOf(data)
	local row = m.Out[id]
	if not row or row.St ~= "Open" or isDone(m, id) then return note(player, "AlreadySold") end
	if not hasRoom(data, row.K, math.floor(num(row.N, 0))) then return note(player, "CantReceive") end
	local won = false
	local uid = player.UserId
	local ok = lupdate(id, function(old)
		won = false
		if old and old.St == "Open" and old.Seller == uid then
			old.St = "Cancel"
			won = true
			return old
		end
		return nil
	end)
	if not ok then return note(player, "Resting") end
	if won then
		giveBack(player, data, id, row, "Cancel")
		mapDrop(row.K, id)
		return
	end
	local okR, rec = lget(id)
	if okR then settleOut(player, data, id, rec) end -- sold first (paid now) or already ended
end

-- one action at a time per player; the Mine rows go back after it (the window asks the page again itself)
local function act(player, name, fn, ...)
	local data = begin(player, name)
	if not data then return end
	if not persistent() then return note(player, "Resting") end
	ST.Busy[player] = true
	local ok, err = pcall(fn, player, data, ...)
	ST.Busy[player] = nil
	if not ok then
		warnOnce(name, err)
		note(player, "Resting")
	end
	pcall(sendMine, player)
end

local function whole(v, lo, hi)
	return type(v) == "number" and v == v and v == math.floor(v) and v >= lo and v <= hi
end

local function goodId(id)
	return type(id) == "string" and #id >= 1 and #id <= Config.SaveV4.MarketIdLen and string.match(id, "^[%w%-_]+$") ~= nil
end

local HANDLERS = {
	MarketIndex = function(player)
		if begin(player, "MarketIndex", true) and switchOn() then sendIndex(player) end
	end,
	MarketMine = function(player)
		if begin(player, "MarketMine", true) then sendMine(player) end
	end,
	MarketBrowse = function(player, key, page)
		if type(key) ~= "string" or #key > 48 or not Config.MarketParse(key) then return end
		page = whole(page, 1, 100) and page or 1
		if begin(player, "MarketBrowse", true) and switchOn() then sendPage(player, key, page) end
	end,
	MarketList = function(player, kind, id, n, price)
		if (kind ~= "I" and kind ~= "W") or type(id) ~= "string" or #id > 32 or not whole(n, 1, Config.SaveV4.MarketMaxN)
			or not whole(price, 1, Config.SaveV4.MaxCount) then return end
		act(player, "MarketList", doList, kind, id, n, price)
	end,
	MarketBuy = function(player, id, price)
		if not goodId(id) or not whole(price, 1, Config.SaveV4.MaxCount) then return end
		act(player, "MarketBuy", doBuy, id, price)
	end,
	MarketCancel = function(player, id)
		if not goodId(id) then return end
		act(player, "MarketCancel", doCancel, id)
	end,
	PackWeapon = function(player, tier)
		if not whole(tier, 2, Config.MaxWeaponTier) or Config.Weapons[tier].Meme then return end -- A23-186: no joke weapon
		local data = begin(player, "PackWeapon")
		if not data or not switchOn() then return end
		local r = S.LootService.PackWeapon(player, tier)
		if r ~= true then note(player, r) end
	end,
	UnpackSpare = function(player, key)
		local info = type(key) == "string" and Config.MarketParse("W:" .. key) or nil
		if not info then return end
		local data = begin(player, "UnpackSpare")
		-- review 10/14: a crafted weapon is taken out with Crafting on, the market switched off or not
		if not data or not (switchOn() or Config.FeatureOn("Crafting")) then return end
		local r = S.LootService.UnpackSpare(player, info.Tier, info.Plus)
		if r ~= true then note(player, r) end
	end,
}

------------------------------------------------------------------ service
function MarketService.Init(registry)
	S = registry
end

function MarketService.Start()
	for name, fn in HANDLERS do
		Net.Get(name).OnServerEvent:Connect(function(player, ...)
			local ok, err = pcall(fn, player, ...)
			if not ok then warnOnce(name, err) end
		end)
	end
	S.PlayerService.PlayerReady:Connect(function(player)
		-- the join check (rows of a server that stopped between two steps); off the join's own thread
		task.spawn(function()
			if persistent() then
				ST.LedgerAt[player] = os.clock()
				round(player, true)
			end
		end)
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		ST.Busy[player], ST.ListAt[player], ST.LedgerAt[player] = nil, nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(M.PollSeconds)
			if persistent() then
				for _, player in S.PlayerService.GetReadyPlayers() do
					local data = dataOf(player)
					local m = data and data.Market
					if type(m) == "table" and (next(type(m.Out) == "table" and m.Out or {}) ~= nil
						or next(type(m.In) == "table" and m.In or {}) ~= nil) then
						local full = os.clock() - (ST.LedgerAt[player] or 0) >= M.LedgerSeconds
						if full then ST.LedgerAt[player] = os.clock() end
						local ok, err = pcall(round, player, full)
						if not ok then warnOnce("poll", err) end
					end
				end
			end
		end
	end)
	print("[MarketService] started")
end

-- offline checks
MarketService._T = { ST = ST, Round = round, Gate = gateOf }

return MarketService
