-- market_offline.luau : C-5 / C-7 the player market (MarketService, 게임성 개발 2, 2026-10-13; design
-- docs/design/market_server_2026-10-13.md). tools/test_market.py binds CONFIG_SOURCE, UTIL_SOURCE, LOOT_SOURCE and
-- MARKET_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows. MarketService and LootService run from
-- source; PlayerService / ProgressionService / DataService are doubles; the ledger is the kit's DataStore double and the
-- MemoryStore maps a double below. Two worlds sharing Stores + Mem = two servers of the same game.

local NOW = 1790000000
local NAN, INF = 0 / 0, math.huge

-- MemoryStore sorted maps shared by the worlds of one test (mem = { Maps, Fail, Now }); Fail["Set" | "Get" | "Remove" |
-- "Update" | "Range"] = n: the next n calls of that kind error
local function memoryStore(mem)
	mem.Maps = mem.Maps or {}
	mem.Fail = mem.Fail or {}
	mem.Calls = mem.Calls or 0
	local api = {}
	function api.GetSortedMap(_, name)
		local rows = mem.Maps[name]
		if not rows then
			rows = {}
			mem.Maps[name] = rows
		end
		local function op(kind)
			mem.Calls += 1
			local n = mem.Fail[kind]
			if n and n > 0 then
				mem.Fail[kind] = n - 1
				error("offline MemoryStore failure " .. kind)
			end
		end
		local function live(r) return r ~= nil and r.Exp > mem.Now() end
		local map = {}
		function map.SetAsync(_, key, value, ttl, sortKey)
			op("Set")
			assert(type(key) == "string" and type(ttl) == "number" and ttl > 0, "SetAsync arguments")
			rows[key] = { Value = deepCopy(value), Sort = sortKey, Exp = mem.Now() + ttl }
			return true
		end
		function map.GetAsync(_, key)
			op("Get")
			local r = rows[key]
			if live(r) then return deepCopy(r.Value), r.Sort end
			return nil
		end
		function map.RemoveAsync(_, key)
			op("Remove")
			rows[key] = nil
		end
		function map.UpdateAsync(_, key, fn, ttl)
			op("Update")
			local r = rows[key]
			local new = fn(live(r) and deepCopy(r.Value) or nil)
			if new == nil then return nil end
			rows[key] = { Value = deepCopy(new), Sort = r and r.Sort, Exp = mem.Now() + ttl }
			return deepCopy(new)
		end
		function map.GetRangeAsync(_, direction, count)
			op("Range")
			local list = {}
			for k, r in rows do
				if live(r) then table.insert(list, { key = k, value = deepCopy(r.Value), sortKey = r.Sort }) end
			end
			table.sort(list, function(a, b)
				local sa, sb = a.sortKey, b.sortKey
				if sa ~= sb then
					if sa == nil then return true end
					if sb == nil then return false end
					return sa < sb
				end
				return a.key < b.key
			end)
			local out = {}
			for i = 1, math.min(count, #list) do out[i] = list[i] end
			return out
		end
		return map
	end
	return api
end

-- one server. o = { Time, Stores, Mem, On (false = Features.Market off), EditConfig }
local function marketWorld(o)
	o = o or {}
	local w = dev3World({ Time = o.Time or NOW, Stores = o.Stores, EditConfig = function(c)
		c.Features.Market = o.On ~= false
		if o.EditConfig then o.EditConfig(c) end
	end })
	local C = w.Config
	w.Mem = o.Mem or {}
	w.Mem.Now = w.Mem.Now or function() return w.Time end
	w.Services.MemoryStoreService = memoryStore(w.Mem)
	-- the ledger: the kit's DataStore double; LedgerAfterError = n: the next n UpdateAsync calls WRITE and then error
	local dss = w.Services.DataStoreService
	local plainGet = dss.GetDataStore
	w.LedgerName = C.StoreName(C.Market.Store)
	function dss.GetDataStore(self, name, scope)
		local store = plainGet(self, name, scope)
		if name ~= w.LedgerName then return store end
		local proxy = setmetatable({}, { __index = store })
		-- review 10/14: the read options MarketService passes (UseCache = false) are kept for a check
		function proxy.GetAsync(s, key, opts)
			w.GetOpts = opts
			return store.GetAsync(s, key)
		end
		function proxy.UpdateAsync(s, key, fn)
			if (w.LedgerFailArmGet or 0) > 0 then -- an error before the write; the next n reads fail too
				w.Fail[w.LedgerName .. ":Get"] = w.LedgerFailArmGet
				w.LedgerFailArmGet = 0
				error("offline: no write, an error")
			end
			local out = store.UpdateAsync(s, key, fn)
			if (w.LedgerAfterError or 0) > 0 then
				w.LedgerAfterError -= 1
				error("offline: written, then an error")
			end
			return out
		end
		return proxy
	end
	w.Saved, w.SaveCalls = {}, 0
	w.Reg.DataService = {
		Save = function(p)
			w.SaveCalls += 1
			if w.SaveFail then return false end
			w.Saved[p.UserId] = deepCopy(w.Data[p])
			return true
		end,
		IsPersistentReady = function() return w.Persistent ~= false end,
	}
	w.Reg.ClassService.GetClass = function() return "Warrior" end
	w.QuestEvents = {} -- StoryQuestService.Event(player, name): the market quests' happenings
	w.Reg.StoryQuestService.Event = function(p, name)
		table.insert(w.QuestEvents, p.UserId .. ":" .. name)
		return true
	end
	function w.Prog.SpendGold(p, amount, reason)
		local d = w.Data[p]
		local carried, bank = math.floor(tonumber(d.CarriedGold) or 0), math.floor(tonumber(d.BankGold) or 0)
		if carried + bank < amount then return false end
		local fromCarried = math.min(carried, amount)
		w.PS.SetStat(p, "CarriedGold", carried - fromCarried)
		w.PS.SetStat(p, "BankGold", bank - (amount - fromCarried))
		w.Spent = (w.Spent or 0) + amount
		return true
	end
	w:Service("LootService", LOOT_SOURCE)
	w:Service("MarketService", MARKET_SOURCE)
	w.Reg.ShopService = { CanBuyWeapon = function() return true end }
	w:InitStart({ "LootService", "MarketService" })
	local bank = w.Prog.AddBankGold
	w.Prog.AddCarriedGold = function(...)
		w.Carried = true
		return bank(...)
	end
	w.Gap = 6.1 -- every action's rate limit
	return w
end

local function hero(w, id, extra)
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 12, PlaytimeSeconds = 4000, WeaponTier = 3,
		WeaponOwnedMask = 7, Items = { Jelly = 30, Enh70 = 2 }, Spares = { ["4:2"] = 1 }, BankGold = 1000, CarriedGold = 0 }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function fired(w, name, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Fired do
		local f = w.Fired[i]
		if f.Remote == name and f.Player == p then table.insert(out, f.Payload) end
	end
	return out
end

local function last(w, name, p)
	local list = fired(w, name, p, 0)
	return list[#list]
end

local function notes(w, p, from)
	return table.concat(w:NoticesFor(p, from), " | ")
end

local function ledgerRows(w)
	local s = w.Stores[w.LedgerName]
	return s and s.Rows or {}
end

local function ledgerOf(w, id)
	return ledgerRows(w)["L_" .. id]
end

local function namedRows(w, name)
	w.Services.MemoryStoreService:GetSortedMap(name)
	return w.Mem.Maps[name]
end

local function mapRows(w, key)
	return namedRows(w, w.Config.StoreName(w.Config.Market.Maps .. string.gsub(key, ":", "_")))
end

local function indexRow(w, key)
	local rows = w.Mem.Maps[w.Config.StoreName(w.Config.Market.IndexMap)] or {}
	return rows[key] and rows[key].Value or nil
end

local function onlyId(t)
	local id = next(t)
	return id
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function sameTable(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not sameTable(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local function hasHangul(s)
	return type(s) == "string" and string.find(s, "[\234-\237][\128-\191][\128-\191]") ~= nil
end

-- the seller lists 10 Jelly at 5 each; returns the new listing's id
local function listJelly(w, p, n, price)
	local before = {}
	for k in w.Data[p].Market.Out do before[k] = true end
	w:Remote("MarketList", p, "I", "Jelly", n or 10, price or 5)
	for k in w.Data[p].Market.Out do
		if not before[k] then return k end
	end
	return nil
end

-- the warnings a failure test causes on purpose
local FAILWARN = { "ledger write", "ledger read", "map write", "map read", "map remove", "index write", "sold hint" }

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local M = C.Market
	check(C.Features.Market == false, "the switch ships off (Config.Features.Market)", "")
	check(M.BuyLevel == 5 and M.ListLevel == 10 and M.ListPlaySeconds == 3600 and M.ListAccountDays == 7 and M.Fee == 0.07,
		"A23-133: buy Lv5, sell Lv10 + 1 hour + a 7-day account, 10% fee", "")
	check(M.Hours == 72 and M.OpenMax == 10 and M.DayLists == 20 and M.DayBuys == 30 and M.PairDay == 3 and M.PageRows == 50
		and M.IndexCache == 30, "72 h listings, 10 open, 20 lists / 30 buys a day, 3 a day from one seller, 50 rows a page, index 30 s", "")
	-- review 10/14: only the states an older server knows; Pend / Pay are flags on Open / Sold rows (keepExtra keeps them)
	check(C.SaveV4.MarketStates.Pend == nil and C.SaveV4.MarketStates.Pay == nil, "no new St (an older server keeps every row)", "")
	local kept = C.SanitizeMarket({ Out = { x1 = { K = "I:Jelly", N = 1, Price = 2, St = "Open", Pend = true } },
		In = { y1 = { Price = 5, St = "Sold", Pay = true, K = "I:Jelly", N = 1, Tok = "abcdef0123456789" } } })
	check(kept.Out.x1 and kept.Out.x1.Pend == true and kept.In.y1 and kept.In.y1.Pay == true and kept.In.y1.Tok == "abcdef0123456789",
		"the save keeps the Pend / Pay flags and the attempt token", show(kept))
	check(C.PassBoost.GoldSources.Market == nil and C.PassBoost.GoldSources.MarketRefund == nil, "market gold is never 2x", "")
	local rl = C.RateLimits
	check(rl.MarketIndex == 1 and rl.MarketBrowse == 1 and rl.MarketMine == 1 and rl.MarketList == 6 and rl.MarketBuy == 6
		and rl.MarketCancel == 6, "rate limits 1 / 6 s (the window's gaps)", "")
	check(C.MarketKey("I", "Jelly") == "I:Jelly" and C.MarketKey("I", "Enh70") == "I:Enh70" and C.MarketKey("I", "WisdomTonic") == "I:WisdomTonic"
		and C.MarketKey("I", "PetTreat") == "I:PetTreat", "materials, scrolls, tonics, treats can be listed", "")
	check(C.MarketKey("I", "HP") == nil and C.MarketKey("I", "Nope") == nil and C.MarketKey("X", "Jelly") == nil
		and C.MarketKey("I", 5) == nil, "potions, unknown ids, other kinds: no", "")
	check(C.MarketKey("W", "4:2") == "W:4:2" and C.MarketKey("W", "1:0") == nil and C.MarketKey("W", "4:11") == nil
		and C.MarketKey("W", "10:0") == nil and C.MarketKey("W", "4:2.5") == nil and C.MarketKey("W", "04:2") == "W:4:2"
		and C.MarketKey("W", "11:3") == nil and C.MarketKey("W", "12:0") == nil and C.MarketParse("W:10:0") == nil and C.MarketParse("W:9:0") ~= nil,
		"weapons: tier 2..9, +0..10 (tier 1 never; A23-186: never the joke tiers 10 / 11), written plainly", "")
	local r, lo, hi = C.MarketRange("I:Jelly")
	check(r == 6 and lo == 2 and hi == 50, "Jelly (Sell 2): Ref 6, 2..50", show({ r, lo, hi }))
	r, lo, hi = C.MarketRange("I:Enh70")
	check(r == 300 and lo == 60 and hi == 1500, "Enh70: Ref 300, 60..1500", show({ r, lo, hi }))
	r, lo, hi = C.MarketRange("W:4:2")
	check(r == 4800 and lo == 960 and hi == 24000, "T4 +2: 3000 x 1.6 = 4800, 960..24000", show({ r, lo, hi }))
	r = C.MarketRange("W:8:0")
	check(r == 20000 and C.MarketRange("W:1:0") == nil and C.MarketRange("I:HP") == nil, "T8 (no price) 20000; T1 / potions none", "")
	local Q = C.StoryQuests
	local mk1, mk2, mk3 = Q.Defs.MK1, Q.Defs.MK2, Q.Defs.MK3
	check(mk1 and mk2 and mk3 and Q.Events.MarketBought and Q.Events.MarketListed and Q.Events.MarketPaid
		and table.find(Q.Subs, "MK1") and table.find(Q.Subs, "MK3"), "A23-133: three market quests in the book", "")
	check(mk1.Requires.Level == 5 and mk1.Requires.Feature == "Market" and mk2.Requires.Level == 10 and mk3.Requires.Done[1] == "MK2"
		and mk1.Steps[1].Obj.Name == "MarketBought" and mk2.Steps[1].Obj.Name == "MarketListed" and mk3.Steps[1].Obj.Name == "MarketPaid"
		and mk1.Steps[1].Obj.Past == true and mk3.Steps[1].Obj.Past == true, "buy Lv5, list Lv10, get paid after MK2; Past steps", "")
	local textOk = true
	for _, s in M.Text do
		if type(s) ~= "string" or s == "" or hasHangul(s) or #s > 60 then textOk = false end
	end
	check(textOk, "every market line is short English", "")
end)

------------------------------------------------------------------ gates
runGroup("gates", function()
	local w = marketWorld()
	local G = w.Reg.MarketService._T.Gate
	local p, d = hero(w, 1)
	check(sameTable(G(p, d), { Buy = "", List = "", ListIn = 0 }), "Lv12, 1 hour, 30-day account: open", show(G(p, d)))
	d.Level = 4
	check(G(p, d).Buy == "NeedLevelBuy" and G(p, d).List == "NeedLevelList", "Lv4: no buying, no selling", show(G(p, d)))
	d.Level = 9
	check(G(p, d).Buy == "" and G(p, d).List == "NeedLevelList", "Lv9: buying only", show(G(p, d)))
	d.Level, d.PlaytimeSeconds = 12, 3599
	check(G(p, d).List == "NeedPlaytime", "under an hour of play", show(G(p, d)))
	d.PlaytimeSeconds = 3600
	p.AccountAge = 6
	check(G(p, d).List == "NeedAccountAge", "a 6-day account", show(G(p, d)))
	p.AccountAge = 7
	for i = 1, 10 do d.Market.Out["o" .. i] = { K = "I:Jelly", N = 1, Price = 2, St = "Open", Pend = i % 2 == 1 or nil, At = NOW, Exp = NOW + 99 } end
	check(G(p, d).List == "TooMany", "10 open (or placing) listings: TooMany", show(G(p, d)))
	d.Market.Out.o1.St = "Paid"
	check(G(p, d).List == "", "a finished row does not count", show(G(p, d)))
	d.Market.Out = {}
	d.Market.Lists = 20
	check(G(p, d).List == "DayLimit", "20 listings today", show(G(p, d)))
	d.Market.Lists, d.Market.Buys = 0, 30
	check(G(p, d).Buy == "DayLimit", "30 purchases today", show(G(p, d)))
	d.Market.Day = d.Market.Day - 1
	check(G(p, d).Buy == "" and d.Market.Buys == 0, "a new KST day starts over", show(d.Market))
	w.Persistent = false
	check(G(p, d).Buy == "Resting" and G(p, d).List == "Resting", "no real saves (Studio memory mode): resting", "")
	local w2 = marketWorld({ On = false })
	local q, qd = hero(w2, 2)
	check(G ~= nil and w2.Reg.MarketService._T.Gate(q, qd).Buy == "Off", "switch off: Off", "")
end)

------------------------------------------------------------------ listing
runGroup("list", function()
	local w = marketWorld()
	local p, d = hero(w, 3)
	local n0 = #w.Notices
	local id = listJelly(w, p)
	local row = id and d.Market.Out[id]
	check(row and row.St == "Open" and row.K == "I:Jelly" and row.N == 10 and row.Price == 5 and row.Exp == row.At + 259200,
		"an Out row Open: 10 Jelly at 5 each, 72 hours", show(row))
	check(d.Items.Jelly == 20, "the Jelly left the bag", show(d.Items))
	local saved = w.Saved[3] and w.Saved[3].Market.Out[id]
	check(saved and saved.St == "Open" and saved.Pend == true and w.Saved[3].Items.Jelly == 20,
		"saved BEFORE the ledger: Open + Pend, the bag already lighter", show(saved))
	local rec = ledgerOf(w, id)
	check(rec and rec.St == "Open" and rec.Seller == 3 and rec.K == "I:Jelly" and rec.N == 10 and rec.Price == 5 and rec.Exp == row.Exp,
		"the ledger row: Open, seller, key, N, price, end", show(rec))
	local mr = mapRows(w, "I:Jelly")[id]
	check(mr and mr.Value.p == 5 and mr.Value.n == 10 and mr.Value.s == 3 and mr.Sort == 5, "the key's map lists it (sorted by price)", show(mr))
	check(sameTable(indexRow(w, "I:Jelly"), { L = 5, C = 1 }), "the index: lowest 5, 1 row", show(indexRow(w, "I:Jelly")))
	check(string.find(notes(w, p, n0), "Listed on the Market.", 1, true) ~= nil, "the notice", notes(w, p, n0))
	local mine = last(w, "MarketMine", p)
	check(mine and #mine.Rows == 1 and mine.Rows[1].State == "Open" and mine.Rows[1].Left == 259200 and mine.Rows[1].Paid == false
		and mine.Today.Lists == 1 and mine.Waiting == 0 and mine.Gate.ListIn > 0, "the Mine rows go back (Open, 72 h, Today 1)", show(mine))
	-- refusals: nothing taken
	local before = deepCopy(d.Items)
	w:Remote("MarketList", p, "I", "Jelly", 5, 51)
	check(string.find(notes(w, p, #w.Notices - 1), "out of range", 1, true) ~= nil, "a price over Max: PriceRange", notes(w, p, #w.Notices - 1))
	w:Remote("MarketList", p, "I", "Jelly", 5, 1)
	w:Remote("MarketList", p, "I", "Jelly", 21, 5)
	check(string.find(notes(w, p, #w.Notices - 1), "You don't have that.", 1, true) ~= nil, "more than I have: NoItem", "")
	w:Remote("MarketList", p, "I", "HP", 1, 5)
	w:Remote("MarketList", p, "W", "4:2", 2, 5000)
	check(string.find(notes(w, p, #w.Notices - 1), "can't sell", 1, true) ~= nil, "two weapons in a row: no", "")
	w:Remote("MarketList", p, "W", "5:0", 1, 10000)
	check(string.find(notes(w, p, #w.Notices - 1), "You don't have that.", 1, true) ~= nil and d.Spares["5:0"] == nil,
		"a spare I do not have: NoItem", "")
	check(sameTable(d.Items, before) and count(d.Market.Out) == 1, "refused lists take nothing", show(d.Items))
	-- a weapon spare
	w:Remote("MarketList", p, "W", "4:2", 1, 5000)
	check(d.Spares["4:2"] == nil and count(d.Market.Out) == 2, "a spare T4 +2 listed", show(d.Spares))
	-- too fast
	w.Gap = 1
	local n1 = #w.Notices
	w:Remote("MarketList", p, "I", "Enh70", 1, 300)
	check(notes(w, p, n1) == "Too fast. Try again." and d.Items.Enh70 == 2, "inside 6 s: TooFast", notes(w, p, n1))
	-- bad arguments: ignored, no warning
	w.Gap = 6.1
	for _, args in { { "I", "Jelly", 0, 5 }, { "I", "Jelly", 1.5, 5 }, { "I", "Jelly", 1, NAN }, { "I", "Jelly", 1, INF }, { "Z", "Jelly", 1, 5 },
		{ "I", string.rep("x", 40), 1, 5 }, { "I", nil, 1, 5 } } do
		w:Remote("MarketList", p, table.unpack(args, 1, 4))
	end
	check(count(d.Market.Out) == 2, "broken arguments: nothing", count(d.Market.Out))
end)

runGroup("list failures", function()
	local w = marketWorld()
	w.AllowWarn = FAILWARN
	local p, d = hero(w, 4)
	w.SaveFail = true
	local n0 = #w.Notices
	listJelly(w, p)
	check(next(d.Market.Out) == nil and d.Items.Jelly == 30 and d.Market.Lists == 0 and next(ledgerRows(w)) == nil,
		"the save fails: undone, nothing public", show(d.Market))
	check(notes(w, p, n0) == "The market is resting.", "Resting", notes(w, p, n0))
	w.SaveFail = false
	-- the ledger write errors and the read says nothing landed: the things come back
	w.Fail[w.LedgerName .. ":Update"] = 1
	listJelly(w, p)
	check(next(d.Market.Out) == nil or d.Market.Out[onlyId(d.Market.Out)].St == "Cancel", "a ledger error with no row: no open listing", show(d.Market.Out))
	check(d.Items.Jelly == 30, "and the Jelly is back", show(d.Items))
	-- the ledger write errors and the read errors too: Pend stays, the next round finishes it
	local w2 = marketWorld()
	w2.AllowWarn = FAILWARN
	local q, qd = hero(w2, 5)
	w2.Fail[w2.LedgerName .. ":Update"] = 1
	w2.Fail[w2.LedgerName .. ":Get"] = 1
	local n1 = #w2.Notices
	local id = listJelly(w2, q)
	check(id and qd.Market.Out[id].Pend == true and qd.Items.Jelly == 20 and notes(w2, q, n1) == "Checking the Market…",
		"no answer from the ledger: Pend (Checking)", show(qd.Market.Out))
	w2:Tick(w2.Config.Market.PollSeconds)
	check(qd.Market.Out[id].St == "Cancel" and qd.Items.Jelly == 30, "the round: no ledger row -> the Jelly back", show(qd.Market.Out[id]))
	-- a ledger row already under the new id (never overwritten): Checking, then the round gives the Jelly back
	local w4 = marketWorld()
	w4.AllowWarn = FAILWARN
	local u, ud = hero(w4, 9)
	local foreign
	w4.BeforeUpdate = function(name, key)
		if name == w4.LedgerName and foreign == nil then
			foreign = key
			w4.Stores[name].Rows[key] = { Id = "x", Seller = 999, K = "I:Jelly", N = 1, Price = 2, At = NOW, Exp = NOW + 99999, St = "Open" }
		end
	end
	local n4 = #w4.Notices
	local id4 = listJelly(w4, u)
	w4.BeforeUpdate = nil
	check(foreign ~= nil and w4.Stores[w4.LedgerName].Rows[foreign].Seller == 999 and ud.Market.Out[id4].Pend == true
		and string.find(notes(w4, u, n4), "Checking", 1, true) ~= nil, "a taken id: the other row stays, mine waits (Pend)", show(ud.Market.Out[id4]))
	w4:Tick(w4.Config.Market.PollSeconds)
	check(ud.Market.Out[id4].St == "Cancel" and ud.Items.Jelly == 30, "the round: not mine -> the Jelly back", show(ud.Market.Out[id4]))
	-- the map write fails: Open with Idx = false, the round puts it in
	local w3 = marketWorld()
	w3.AllowWarn = FAILWARN
	local r, rd = hero(w3, 6)
	w3.Mem.Fail.Set = 1
	local id3 = listJelly(w3, r)
	check(rd.Market.Out[id3].St == "Open" and rd.Market.Out[id3].Idx == false and mapRows(w3, "I:Jelly")[id3] == nil,
		"a map error: Open, not listed yet (Idx false)", show(rd.Market.Out[id3]))
	w3:Tick(w3.Config.Market.PollSeconds)
	check(rd.Market.Out[id3].Idx == nil and mapRows(w3, "I:Jelly")[id3] ~= nil, "the round lists it", show(rd.Market.Out[id3]))
end)

------------------------------------------------------------------ browsing
runGroup("browse and index", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 7, { Items = { Jelly = 999 } })
	local buyer = hero(b, 8)
	a.Gap = 6.1
	for i = 1, 3 do a:Remote("MarketList", s, "I", "Jelly", i, 2 + i) end
	b:Remote("MarketBrowse", buyer, "I:Jelly", 1)
	local page = last(b, "MarketPage", buyer)
	check(page and page.Key == "I:Jelly" and page.Page == 1 and page.Pages == 1 and #page.Rows == 3 and page.Ref == 6
		and page.Min == 2 and page.Max == 50, "a page: 3 rows, Ref / Min / Max", show(page))
	check(page and page.Rows[1].Price == 3 and page.Rows[1].N == 1 and page.Rows[3].Price == 5 and page.Rows[1].Plus == 0
		and page.Rows[1].Left == 259200 and page.Rows[1].Id ~= nil, "cheapest first; Id, Price, N, Plus, Left (no seller)", show(page and page.Rows))
	check(page and page.Rows[1].Seller == nil, "never the seller", "")
	a:Remote("MarketBrowse", s, "I:Jelly", 1)
	check(#last(a, "MarketPage", s).Rows == 0, "my own rows are not in my page", "")
	b:Remote("MarketIndex", buyer)
	local idx = last(b, "MarketIndex", buyer)
	check(idx and #idx.Rows == 1 and idx.Rows[1].Key == "I:Jelly" and idx.Rows[1].Low == 3 and idx.Rows[1].Count == 3
		and idx.Gate.Buy == "", "the index: { Key, Low, Count } + Gate", show(idx))
	-- the index is cached 30 s
	a:Advance(1)
	a:Remote("MarketList", s, "I", "Jelly", 1, 2)
	b:Advance(7)
	b:Remote("MarketIndex", buyer)
	check(last(b, "MarketIndex", buyer).Rows[1].Low == 3, "within 30 s: the cached index", show(last(b, "MarketIndex", buyer)))
	b:Advance(31)
	b:Remote("MarketIndex", buyer)
	check(last(b, "MarketIndex", buyer).Rows[1].Low == 2 and last(b, "MarketIndex", buyer).Rows[1].Count == 4, "after 30 s: the new low", "")
	-- pages: 120 rows -> 3 pages of 50
	local rows = mapRows(a, "I:Enh70")
	for i = 1, 120 do
		rows[string.format("x%03d", i)] = { Value = { p = 100 + i, n = 1, x = NOW + 99999, s = 99 }, Sort = 100 + i, Exp = NOW + 999999 }
	end
	b:Remote("MarketBrowse", buyer, "I:Enh70", 3)
	local p3 = last(b, "MarketPage", buyer)
	check(p3.Pages == 3 and p3.Page == 3 and #p3.Rows == 20 and p3.Rows[1].Price == 201, "page 3 of 3: rows 101-120", show({ p3.Pages, #p3.Rows }))
	b:Remote("MarketBrowse", buyer, "I:Enh70", 9)
	check(last(b, "MarketPage", buyer).Page == 3, "a page past the end: the last page", "")
	b:Remote("MarketBrowse", buyer, "I:HP", 1)
	b:Remote("MarketBrowse", buyer, 5, 1)
	check(last(b, "MarketPage", buyer).Key == "I:Enh70", "a key that cannot be listed: no answer", "")
end)

------------------------------------------------------------------ buying (two servers)
runGroup("buy and pay", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 10)
	local buyer, bd = hero(b, 11, { Items = {}, BankGold = 100, CarriedGold = 20 })
	local id = listJelly(a, s)
	local n0 = #b.Notices
	b:Remote("MarketBuy", buyer, id, 5)
	check(bd.Items.Jelly == 10 and bd.BankGold + bd.CarriedGold == 70 and b.Spent == 50, "the buyer pays 10 x 5 = 50 and gets 10 Jelly",
		show({ bd.Items, bd.BankGold, bd.CarriedGold }))
	local saved = b.Saved[11] and b.Saved[11].Market.In[id]
	check(saved and saved.St == "Sold" and saved.Pay == true and type(saved.Tok) == "string" and #saved.Tok >= 1 and #saved.Tok <= 16 and saved.Price == 50 and b.Saved[11].BankGold + b.Saved[11].CarriedGold == 70,
		"saved BEFORE the ledger: In Pay, the gold already gone", show(saved))
	local rec = ledgerOf(b, id)
	check(rec.St == "Sold" and rec.Buyer == 11 and type(rec.SoldAt) == "number", "the ledger: Sold to the buyer", show(rec))
	check(bd.Market.In[id] == nil and table.find(bd.Market.Done, id) ~= nil and bd.Market.Buys == 1 and bd.Market.P10 == 1,
		"the buyer's In row is done (Done, Buys, the pair count)", show(bd.Market))
	check(mapRows(b, "I:Jelly")[id] == nil and indexRow(b, "I:Jelly") == nil, "off the map and the index", "")
	check(string.find(notes(b, buyer, n0), "Bought Jelly!", 1, true) ~= nil, "the buyer's notice", notes(b, buyer, n0))
	-- the seller's server pays on its next round (the sold hint)
	local n1 = #a.Notices
	a:Tick(a.Config.Market.PollSeconds)
	check(sd.BankGold == 1047 and sd.Market.Out[id].St == "Paid" and table.find(sd.Market.Done, id) ~= nil,
		"the seller gets 50 - 3 (7% fee, floored) = 47 in the bank", show({ sd.BankGold, sd.Market.Out[id] }))
	local g = a.Gold[#a.Gold]
	check(g and g.Src == "Market" and g.N == 47, "as bank gold 'Market' (never 2x)", show(g and { g.Src, g.N }))
	check(ledgerOf(a, id).Paid == true and a.Saved[10].Market.Out[id].St == "Paid", "the ledger is marked Paid after the seller's save", show(ledgerOf(a, id)))
	check(string.find(notes(a, s, n1), "Sold on the Market! +47 gold", 1, true) ~= nil, "the seller's notice", notes(a, s, n1))
	check(table.find(a.QuestEvents, "10:MarketListed") ~= nil and table.find(b.QuestEvents, "11:MarketBought") ~= nil
		and table.find(a.QuestEvents, "10:MarketPaid") ~= nil, "the market quests hear MarketListed / MarketBought / MarketPaid",
		show({ a.QuestEvents, b.QuestEvents }))
	a:Tick(a.Config.Market.PollSeconds)
	a:Tick(a.Config.Market.LedgerSeconds)
	check(sd.BankGold == 1047, "paid once", sd.BankGold)
	a:Remote("MarketMine", s)
	local mine = last(a, "MarketMine", s)
	check(mine.Rows[1].State == "Sold" and mine.Rows[1].Paid == true, "Mine: Sold, Paid", show(mine.Rows[1]))
	-- a finished row leaves the Mine tab after a day
	a:Tick(a.Config.Market.KeepFinished)
	check(sd.Market.Out[id] == nil, "a day later the Paid row is gone", show(sd.Market.Out))
end)

runGroup("buy refusals", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 12)
	local buyer, bd = hero(b, 13, { BankGold = 30 })
	local id = listJelly(a, s)
	local function try(p, w, ...)
		local n = #w.Notices
		w:Remote("MarketBuy", p, ...)
		return notes(w, p, n)
	end
	check(try(s, a, id, 5) == "That's your own listing.", "my own listing", "")
	check(try(buyer, b, id, 4) == "The price changed.", "another price", "")
	check(try(buyer, b, id, 5) == "Not enough gold.", "30 gold for 50", "")
	check(ledgerOf(a, id).St == "Open" and bd.BankGold == 30 and next(bd.Market.In) == nil, "nothing changed", show(bd.Market))
	bd.BankGold = 1000
	bd.Items.Jelly = 995
	check(try(buyer, b, id, 5) == "No room for it.", "995 + 10 Jelly > 999", "")
	-- bag slots (10/14): no Jelly yet and 12 other kinds in 12 slots: no room for a new kind
	local kinds = {}
	for k, def in b.Config.Loot.Items do
		if def.Kind == "Material" and k ~= "Jelly" then table.insert(kinds, k) end
	end
	table.sort(kinds)
	bd.Items = {}
	for i = 1, 12 do bd.Items[kinds[i]] = 1 end
	check(try(buyer, b, id, 5) == "No room for it." and next(bd.Market.In) == nil and bd.BankGold == 1000,
		"a full bag (12 kinds): no new kind bought, nothing taken", show(bd.Market))
	bd.Items = {}
	bd.Items.Jelly = 1
	bd.Level = 4
	check(try(buyer, b, id, 5) == "You can buy from Lv 5.", "Lv4", "")
	bd.Level = 12
	-- a weapon tier I own
	a:Remote("MarketList", s, "W", "4:2", 1, 5000)
	local wid
	for k, r in sd.Market.Out do if r.K == "W:4:2" then wid = k end end
	bd.WeaponOwnedMask = 15
	check(try(buyer, b, wid, 4800 + 200) == "You have this weapon already.", "owning T4: no", "")
	-- an ended listing
	b:Advance(72 * 3600)
	a:Advance(72 * 3600)
	check(try(buyer, b, id, 5) == "Already sold.", "after 72 h: gone", "")
	check(try(buyer, b, "nope-id", 5) == "Already sold.", "an unknown id", "")
	b:Remote("MarketBuy", buyer, string.rep("x", 41), 5)
	b:Remote("MarketBuy", buyer, "bad id!", 5)
	b:Remote("MarketBuy", buyer, id, 0)
	b:Remote("MarketBuy", buyer, id, 1.5)
	check(true, "broken arguments are ignored", "")
end)

runGroup("pair and day limits", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 14, { Items = { Jelly = 999 } })
	local buyer, bd = hero(b, 15, { Items = {}, BankGold = 10000 })
	local ids = {}
	for i = 1, 4 do
		a:Remote("MarketList", s, "I", "Jelly", 1, 2 + i)
	end
	for k in sd.Market.Out do table.insert(ids, k) end
	table.sort(ids, function(x, y) return sd.Market.Out[x].Price < sd.Market.Out[y].Price end)
	for i = 1, 3 do b:Remote("MarketBuy", buyer, ids[i], 2 + i) end
	check(bd.Items.Jelly == 3 and bd.Market.P14 == 3, "3 from one seller", show(bd.Market))
	local n = #b.Notices
	b:Remote("MarketBuy", buyer, ids[4], 6)
	check(notes(b, buyer, n) == "Too many trades with them today." and bd.Items.Jelly == 3, "the 4th from the same seller: PairLimit", notes(b, buyer, n))
	b:ToDay(1)
	a:ToDay(1)
	b:Remote("MarketBuy", buyer, ids[4], 6)
	check(bd.Items.Jelly == 4 and bd.Market.P14 == 1, "the next KST day: again", show(bd.Market))
end)

------------------------------------------------------------------ races and errors
runGroup("two buyers", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local c = marketWorld({ Mem = mem, Stores = stores })
	local s = hero(a, 16)
	local b1, b1d = hero(b, 17, { Items = {} })
	local b2, b2d = hero(c, 18, { Items = {} })
	local id = listJelly(a, s)
	-- buyer 2 has read the row Open; just before its write, buyer 1's server buys it
	c.BeforeUpdate = function(name, key)
		if name == c.LedgerName and key == "L_" .. id then
			c.BeforeUpdate = nil
			b:Remote("MarketBuy", b1, id, 5)
		end
	end
	local n = #c.Notices
	c:Remote("MarketBuy", b2, id, 5)
	check(b1d.Items.Jelly == 10 and ledgerOf(a, id).Buyer == 17, "buyer 1 wins", show(ledgerOf(a, id)))
	check((b2d.Items.Jelly or 0) == 0 and b2d.BankGold == 1000 and b2d.Market.In[id] == nil and table.find(b2d.Market.Done, id) ~= nil,
		"buyer 2 gets the gold back, no Jelly", show({ b2d.Items, b2d.BankGold }))
	check(string.find(notes(c, b2, n), "Purchase failed.", 1, true) ~= nil, "MarketRefund", notes(c, b2, n))
	local g = c.Gold[#c.Gold]
	check(g and g.Src == "MarketRefund" and g.N == 50 and not c.Carried, "a refund 'MarketRefund' to the bank (never 2x)", show(g and g.Src))
end)

runGroup("buy failures", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	b.AllowWarn = FAILWARN
	local s = hero(a, 19, { Items = { Jelly = 999 } })
	local buyer, bd = hero(b, 20, { Items = {} })
	local id1 = listJelly(a, s)
	-- the buyer's save fails: undone
	b.SaveFail = true
	local n = #b.Notices
	b:Remote("MarketBuy", buyer, id1, 5)
	check(bd.BankGold == 1000 and next(bd.Market.In) == nil and bd.Market.Buys == 0 and ledgerOf(a, id1).St == "Open"
		and notes(b, buyer, n) == "The market is resting.", "the save fails: the gold back, the listing open", show(bd.Market))
	b.SaveFail = false
	-- the write lands, then errors: the read says Sold to me -> delivered
	b.LedgerAfterError = 1
	b:Remote("MarketBuy", buyer, id1, 5)
	check(bd.Items.Jelly == 10 and ledgerOf(a, id1).Buyer == 20 and bd.Market.In[id1] == nil, "written then an error: delivered", show(bd.Items))
	-- the write errors (nothing written) and the read errors: In Pay waits (Checking), the round refunds
	a.Gap = 6.1
	a:Remote("MarketList", s, "I", "Jelly", 10, 6)
	local id2
	for k, r in a.Data[s].Market.Out do if r.Price == 6 then id2 = k end end
	b.LedgerFailArmGet = 2 -- the write errors; the check after it and the round's first read fail too
	n = #b.Notices
	b:Remote("MarketBuy", buyer, id2, 6)
	check(bd.Market.In[id2] and bd.Market.In[id2].Pay == true and string.find(notes(b, buyer, n), "Checking", 1, true) ~= nil,
		"no answer: In Pay (Checking)", show(bd.Market.In))
	b:Remote("MarketMine", buyer)
	check(last(b, "MarketMine", buyer).Waiting == 1, "Mine: Waiting 1", "")
	b:Tick(b.Config.Market.PollSeconds) -- the Get still fails once
	check(bd.Market.In[id2] ~= nil, "a failed read: still waiting", "")
	b:Tick(b.Config.Market.PollSeconds)
	check(bd.Market.In[id2] == nil and bd.BankGold == 1000 - 50 and ledgerOf(a, id2).St == "Open", "the round: never sold to me -> refund",
		show({ bd.Market.In, bd.BankGold }))
	-- the listing ends between my read and my write: refunded
	local idE = listJelly(a, s, 3, 7)
	local g0, j0 = bd.BankGold, bd.Items.Jelly or 0
	b.BeforeUpdate = function(name)
		if name == b.LedgerName then
			b.BeforeUpdate = nil
			b:Advance(72 * 3600)
		end
	end
	b:Remote("MarketBuy", buyer, idE, 7)
	check(ledgerOf(a, idE).St == "Open" and bd.Market.In[idE] == nil and bd.BankGold == g0 and (bd.Items.Jelly or 0) == j0,
		"ended after my read: never sold to me, gold back", show({ ledgerOf(a, idE).St, bd.BankGold }))
end)

------------------------------------------------------------------ cancel and end
runGroup("cancel and expire", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 21)
	local buyer, bd = hero(b, 22, { Items = {} })
	local id = listJelly(a, s)
	local n = #a.Notices
	a:Remote("MarketCancel", s, id)
	check(ledgerOf(a, id).St == "Cancel" and sd.Items.Jelly == 30 and sd.Market.Out[id].St == "Cancel" and table.find(sd.Market.Done, id) ~= nil,
		"cancel: the ledger Cancel, the Jelly back", show(sd.Market.Out[id]))
	check(mapRows(a, "I:Jelly")[id] == nil and notes(a, s, n) == "Listing cancelled. It's back in your bag.", "off the map, the notice", notes(a, s, n))
	b:Remote("MarketBuy", buyer, id, 5)
	check((bd.Items.Jelly or 0) == 0 and bd.BankGold == 1000, "a cancelled listing cannot be bought", show(bd.Items))
	-- cancel with a full bag
	local id2 = listJelly(a, s)
	sd.Items.Jelly = 995
	n = #a.Notices
	a:Remote("MarketCancel", s, id2)
	check(notes(a, s, n) == "No room for it." and ledgerOf(a, id2).St == "Open", "no room: not cancelled", notes(a, s, n))
	sd.Items.Jelly = 20
	-- cancel after someone bought it: paid instead
	b:Remote("MarketBuy", buyer, id2, 5)
	local hints = namedRows(a, a.Config.StoreName(a.Config.Market.SoldMap))
	for k in hints do hints[k] = nil end -- the hint is lost
	n = #a.Notices
	a:Remote("MarketCancel", s, id2)
	check(sd.Market.Out[id2].St == "Paid" and sd.BankGold == 1047 and sd.Items.Jelly == 20, "cancel a sold row: paid, not given back",
		show(sd.Market.Out[id2]))
	-- the end after 72 hours: back in the bag
	local id3 = listJelly(a, s, 5, 4)
	a:Advance(72 * 3600)
	n = #a.Notices
	a:Tick(a.Config.Market.PollSeconds)
	check(ledgerOf(a, id3).St == "Expired" and sd.Market.Out[id3].St == "Expired" and sd.Items.Jelly == 20, "ended: Expired, the Jelly back",
		show(sd.Market.Out[id3]))
	check(string.find(notes(a, s, n), "A listing ended.", 1, true) ~= nil, "MarketExpired", notes(a, s, n))
end)

------------------------------------------------------------------ the join check (a server stopped between two steps)
runGroup("join check", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	a.StoreOf(a.LedgerName, "Standard")
	local L = a.Stores[a.LedgerName]
	local exp = NOW + 72 * 3600
	-- a Pend row whose ledger row landed: Open (and listed)
	L.Rows["L_p1"] = { Id = "p1", Seller = 30, K = "I:Jelly", N = 5, Price = 3, At = NOW, Exp = exp, St = "Open" }
	-- a Pend row that never landed: the things back
	-- an Open row sold while away: paid
	L.Rows["L_o1"] = { Id = "o1", Seller = 30, K = "I:Jelly", N = 2, Price = 10, At = NOW, Exp = exp, St = "Sold", Buyer = 31 }
	-- an In row (Pay) sold to me: delivered; another one still open (never sold to me): refunded
	L.Rows["L_i1"] = { Id = "i1", Seller = 32, K = "I:Enh70", N = 1, Price = 300, At = NOW, Exp = exp, St = "Sold", Buyer = 30 }
	L.Rows["L_i2"] = { Id = "i2", Seller = 32, K = "I:Enh70", N = 1, Price = 310, At = NOW, Exp = exp, St = "Open" }
	-- an Open row whose id is in Done already (a save between two steps): never paid
	L.Rows["L_o2"] = { Id = "o2", Seller = 30, K = "I:Jelly", N = 1, Price = 40, At = NOW, Exp = exp, St = "Sold", Buyer = 31 }
	-- an Open row whose ledger says Paid (only after a save of ours): marked Paid, no gold
	L.Rows["L_o3"] = { Id = "o3", Seller = 30, K = "I:Jelly", N = 1, Price = 60, At = NOW, Exp = exp, St = "Sold", Buyer = 31, Paid = true }
	-- a Paid row out of Done whose ledger was never marked Paid: never paid again
	L.Rows["L_d2"] = { Id = "d2", Seller = 30, K = "I:Jelly", N = 1, Price = 70, At = NOW, Exp = exp, St = "Sold", Buyer = 31 }
	-- an In row whose id is in Done already: never delivered twice
	L.Rows["L_i3"] = { Id = "i3", Seller = 32, K = "I:Enh70", N = 1, Price = 300, At = NOW, Exp = exp, St = "Sold", Buyer = 30 }
	-- an In row whose id is in Done already and whose listing is still open: never refunded twice
	L.Rows["L_i4"] = { Id = "i4", Seller = 32, K = "I:Enh70", N = 1, Price = 320, At = NOW, Exp = exp, St = "Open" }
	-- an Out row already paid (save + Paid) whose id fell out of Done: never paid again
	L.Rows["L_d1"] = { Id = "d1", Seller = 30, K = "I:Jelly", N = 1, Price = 50, At = NOW, Exp = exp, St = "Sold", Buyer = 31, Paid = true }
	local market = { Day = 0, Lists = 0, Buys = 0, Done = { "o2", "i3", "i4" },
		Out = { p1 = { K = "I:Jelly", N = 5, Price = 3, St = "Open", Pend = true, At = NOW, Exp = exp },
			p2 = { K = "I:Jelly", N = 4, Price = 3, St = "Open", Pend = true, At = NOW, Exp = exp },
			o1 = { K = "I:Jelly", N = 2, Price = 10, St = "Open", At = NOW, Exp = exp }, d1 = { K = "I:Jelly", N = 1, Price = 50, St = "Paid", At = NOW, Exp = exp, Fin = NOW },
			o2 = { K = "I:Jelly", N = 1, Price = 40, St = "Open", At = NOW, Exp = exp }, o3 = { K = "I:Jelly", N = 1, Price = 60, St = "Open", At = NOW, Exp = exp },
			d2 = { K = "I:Jelly", N = 1, Price = 70, St = "Paid", At = NOW, Exp = exp, Fin = NOW } },
		In = { i1 = { Price = 300, St = "Sold", Pay = true, Tok = "t1", K = "I:Enh70", N = 1 },
			i2 = { Price = 310, St = "Sold", Pay = true, Tok = "t2", K = "I:Enh70", N = 1 },
			i3 = { Price = 300, St = "Sold", Pay = true, Tok = "t3", K = "I:Enh70", N = 1 },
			i4 = { Price = 320, St = "Sold", Pay = true, Tok = "t4", K = "I:Enh70", N = 1 } } }
	local p, d = hero(a, 30, { Items = { Jelly = 10 }, BankGold = 0, Market = market })
	check(d.Market.Out.p1.St == "Open" and mapRows(a, "I:Jelly").p1 ~= nil, "Pend + a ledger row: Open and listed", show(d.Market.Out.p1))
	check(d.Market.Out.p2.St == "Cancel" and d.Market.Out.p2.Pend == nil and d.Items.Jelly == 14, "Pend + no ledger row: 4 Jelly back (Pend cleared)",
		show({ d.Market.Out.p2, d.Items }))
	local tomb = L.Rows["L_p2"]
	check(tomb and tomb.St == "Cancel" and tomb.Tomb == true and tomb.Seller == 30 and tomb.K == "I:Jelly",
		"review 10/14: ... and a tombstone where the row would be (a late listing write can never open it)", show(tomb))
	check(d.Market.Out.o1.St == "Paid" and d.BankGold == 19 + 310 and table.find(d.Market.Done, "o1") ~= nil,
		"Open + Sold while away: paid 20 - 1 (7% floored)", show({ d.Market.Out.o1, d.BankGold }))
	check(L.Rows["L_i2"].St == "Open" and type(L.Rows["L_i2"].Void) == "table" and L.Rows["L_i2"].Void.t2 == true,
		"review 10/14: the still-open purchase is voided in the ledger before its refund", show(L.Rows["L_i2"]))
	check(d.Items.Enh70 == 1 and d.Market.In.i1 == nil and d.Market.In.i2 == nil, "In Pay + Sold to me: delivered; + still Open: refunded (310)",
		show({ d.Items, d.Market.In }))
	check(d.Market.Out.d1.St == "Paid" and d.Market.Out.d2.St == "Paid" and d.BankGold == 329, "a Paid row out of Done: never paid twice", show(d.BankGold))
	check(d.Market.Out.o2.St == "Open" and d.Market.Out.o3.St == "Paid" and d.BankGold == 329,
		"an id in Done: never paid; a ledger Paid row: marked Paid, no gold", show({ d.Market.Out.o2, d.Market.Out.o3 }))
	check(d.Market.In.i3 == nil and d.Market.In.i4 == nil and d.Items.Enh70 == 1 and d.BankGold == 329,
		"an In id in Done: never delivered or refunded twice", show({ d.Market.In, d.Items, d.BankGold }))
end)

------------------------------------------------------------------ review 10/14: the duplication races (BLOCK 1 / 2, FIX)
runGroup("races", function()
	-- BLOCK 1: another session settles my Pend listing (tombstone) while this server's listing write is on its way
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 60)
	a.BeforeUpdate = function(name, key)
		if name ~= a.LedgerName then return end
		a.BeforeUpdate = nil
		a.Stores[name].Rows[key] = { Id = string.sub(key, 3), Seller = 60, St = "Cancel", At = NOW, Tomb = true }
	end
	local id = listJelly(a, s)
	check(id and sd.Items.Jelly == 20 and sd.Market.Out[id].Pend == true, "the listing write lost to the tombstone: Pend, Checking", show(sd.Market.Out))
	a:Tick(30)
	local row = ledgerOf(a, id)
	check(row.St == "Cancel" and sd.Items.Jelly == 30 and mapRows(a, "I:Jelly")[id] == nil,
		"the round: the tombstone wins, the 10 Jelly come back ONCE, never listed", show({ row, sd.Items }))
	-- BLOCK 1: the tombstone write fails: nothing comes back yet (the ledger has not decided), the next round settles it
	local t = marketWorld()
	t.AllowWarn = FAILWARN
	local exp9 = NOW + 72 * 3600
	t.Fail[t.LedgerName .. ":Update"] = 1
	local tp, td = hero(t, 64, { Items = { Jelly = 10 }, Market = { Day = 0, Lists = 0, Buys = 0, Done = {}, In = {},
		Out = { z9 = { K = "I:Jelly", N = 5, Price = 3, St = "Open", Pend = true, At = NOW, Exp = exp9 } } } })
	check(td.Items.Jelly == 10 and td.Market.Out.z9.Pend == true and ledgerOf(t, "z9") == nil,
		"the tombstone write fails: no Jelly back yet, still Pend", show({ td.Items.Jelly, td.Market.Out.z9 }))
	t:Tick(30)
	check(td.Items.Jelly == 15 and td.Market.Out.z9.St == "Cancel" and ledgerOf(t, "z9").Tomb == true,
		"the next round: the tombstone, then the 5 Jelly back once", show({ td.Items.Jelly, ledgerOf(t, "z9") }))
	-- BLOCK 2: my purchase attempt is voided by another session before this server's purchase write lands
	local mem2, stores2 = {}, {}
	local b = marketWorld({ Mem = mem2, Stores = stores2 })
	local c = marketWorld({ Mem = mem2, Stores = stores2 })
	local seller = hero(b, 61)
	local lid = listJelly(b, seller)
	local buyer, bd = hero(c, 62, { Items = {} })
	local gold0 = bd.BankGold + bd.CarriedGold
	c.BeforeUpdate = function(name, key)
		if name ~= c.LedgerName or key ~= "L_" .. lid then return end
		c.BeforeUpdate = nil
		local tok = bd.Market.In[lid] and bd.Market.In[lid].Tok
		local rec = c.Stores[name].Rows[key]
		rec.Void = { [tok] = true }
	end
	c:Remote("MarketBuy", buyer, lid, 5)
	check(ledgerOf(b, lid).St == "Open" and (bd.Items.Jelly or 0) == 0 and bd.BankGold + bd.CarriedGold == gold0,
		"a voided attempt: the purchase write is refused, the buyer refunded once, the listing still open", show({ ledgerOf(b, lid), bd.BankGold }))
	-- review 10/14b BLOCK: the buy write errors before writing and the read says Open: the attempt is voided first, then
	-- refunded once (a late landing of that write is refused); the listing stays open, the seller is never paid
	local mem3, stores3 = {}, {}
	local e = marketWorld({ Mem = mem3, Stores = stores3 })
	local f = marketWorld({ Mem = mem3, Stores = stores3 })
	f.AllowWarn = FAILWARN
	local es = hero(e, 65)
	local eid = listJelly(e, es)
	local fb, fbd = hero(f, 66, { Items = {} })
	local fgold = fbd.BankGold + fbd.CarriedGold
	f.Fail[f.LedgerName .. ":Update"] = 1
	f:Remote("MarketBuy", fb, eid, 5)
	local erow = ledgerOf(e, eid)
	local voids = 0
	for _ in type(erow.Void) == "table" and erow.Void or {} do voids += 1 end
	check(erow.St == "Open" and voids == 1 and fbd.BankGold + fbd.CarriedGold == fgold and fbd.Market.In[eid] == nil
		and table.find(fbd.Market.Done, eid) ~= nil, "an errored buy write with the row Open: voided in the ledger, then refunded once",
		show({ erow, fbd.BankGold }))
	-- the tombstone keeps the listing's K
	check(ledgerOf(a, id).K == nil or ledgerOf(a, id).K == "I:Jelly", "(a tombstone written by another session may lack K)", "")
	-- the save's row cap: one more Out row than SaveV4.MarketRows is refused and the things stay
	local cw = marketWorld()
	local rows = {}
	for i = 1, cw.Config.SaveV4.MarketRows do
		rows["c" .. string.format("%03d", i)] = { K = "I:Jelly", N = 1, Price = 2, St = "Cancel", At = NOW, Exp = NOW + 99, Fin = NOW }
	end
	local cp, cpd = hero(cw, 67, { Items = { Jelly = 30 }, Market = { Day = 0, Lists = 0, Buys = 0, Done = {}, In = {}, Out = rows } })
	local cn = #cw.Notices
	listJelly(cw, cp)
	local outN = 0
	for _ in cpd.Market.Out do outN += 1 end
	check(outN == cw.Config.SaveV4.MarketRows and cpd.Items.Jelly == 30 and notes(cw, cp, cn) == "The market is full.",
		"the save's row cap: no 65th row, the Jelly stays, 'The market is full.'", show({ outN, cpd.Items.Jelly, notes(cw, cp, cn) }))
	-- FIX: the ledger is read without the server cache
	check(c.GetOpts ~= nil and c.GetOpts.UseCache == false, "ledger reads pass UseCache = false", show(c.GetOpts and c.GetOpts.UseCache))
	-- FIX: a listing undone after a failed save keeps what no longer fits (owed, Ret)
	local u = marketWorld()
	u.AllowWarn = FAILWARN
	local q, qd = hero(u, 63, { Items = { Jelly = 30 } })
	u.SaveFail = true
	local cap = u.Config.Loot.ItemCap
	local realTake = u.Reg.LootService.TakeItem
	u.Reg.LootService.TakeItem = function(pl, itemId, n2)
		local ok = realTake(pl, itemId, n2)
		u.Data[pl].Items.Jelly = cap -- the bag filled up again while the save waited
		return ok
	end
	local lid2 = listJelly(u, q)
	u.Reg.LootService.TakeItem = realTake
	local owed = lid2 and qd.Market.Out[lid2]
	check(qd.Items.Jelly == cap and owed and owed.St == "Cancel" and owed.Ret == true and owed.N == 10,
		"the save fails with a full bag: the 10 Jelly stay owed (Ret), none lost", show({ qd.Items.Jelly, owed }))
end)

------------------------------------------------------------------ weapons
runGroup("weapons", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 40, { WeaponOwnedMask = 31, WeaponTier = 3, WeaponEnhance = { 0, 0, 0, 4, 0, 0, 0, 0, 0 }, Spares = {} })
	-- pack the T4 +4 (not in hand), refuse the one in hand and tier 1
	local n = #a.Notices
	a.Gap = 1.1
	a:Remote("PackWeapon", s, 3)
	check(notes(a, s, n) == "Put it away first." and bit32.btest(sd.WeaponOwnedMask, 4), "the weapon in hand: no", notes(a, s, n))
	a:Remote("PackWeapon", s, 1)
	a:Remote("PackWeapon", s, 4)
	check(sd.Spares["4:4"] == 1 and not bit32.btest(sd.WeaponOwnedMask, 8) and sd.WeaponEnhance[4] == 0 and bit32.btest(sd.WeaponOwnedMask, 1),
		"T4 +4 packed: a spare '4:4', the tier not owned, its +N 0", show({ sd.Spares, sd.WeaponOwnedMask }))
	a:Remote("UnpackSpare", s, "4:4")
	check(sd.Spares["4:4"] == nil and bit32.btest(sd.WeaponOwnedMask, 8) and sd.WeaponEnhance[4] == 4, "and back: owned +4", show(sd.Spares))
	sd.Spares["5:0"] = 1
	n = #a.Notices
	a:Remote("UnpackSpare", s, "5:0")
	check(notes(a, s, n) == "You have this weapon already." and sd.Spares["5:0"] == 1, "unpacking a tier I own: no", notes(a, s, n))
	sd.Spares["5:0"] = nil
	a:Remote("PackWeapon", s, 4)
	a.Gap = 6.1
	a:Remote("MarketList", s, "W", "4:4", 1, 7000)
	local id = onlyId(sd.Market.Out)
	check(id and sd.Market.Out[id].K == "W:4:4" and sd.Spares["4:4"] == nil, "a weapon listed (W:4:4)", show(sd.Market.Out))
	local buyer, bd = hero(b, 41, { WeaponOwnedMask = 7, WeaponTier = 3, BankGold = 10000 })
	b:Remote("MarketBuy", buyer, id, 7000)
	check(bit32.btest(bd.WeaponOwnedMask, 8) and bd.WeaponEnhance[4] == 4 and bd.WeaponTier == 3 and bd.BankGold == 3000,
		"the buyer owns T4 +4 now (not equipped)", show({ bd.WeaponOwnedMask, bd.WeaponEnhance }))
	a:Tick(a.Config.Market.PollSeconds)
	check(sd.BankGold == 1000 + 6510, "the seller: 7000 - 490 (7%)", sd.BankGold)
end)

------------------------------------------------------------------ the switch and Mine rows
runGroup("switch off", function()
	local mem, stores = {}, {}
	local a = marketWorld({ Mem = mem, Stores = stores })
	local b = marketWorld({ Mem = mem, Stores = stores })
	local s, sd = hero(a, 50)
	local buyer = hero(b, 51)
	local id = listJelly(a, s)
	b:Remote("MarketBuy", buyer, id, 5)
	a.Config.Features.Market = false
	local n = #a.Notices
	a:Remote("MarketList", s, "I", "Jelly", 1, 5)
	check(notes(a, s, n) == "The market is closed.", "off: no new listing", notes(a, s, n))
	a:Remote("MarketIndex", s)
	check(last(a, "MarketIndex", s) == nil, "off: no index", "")
	a:Tick(a.Config.Market.PollSeconds)
	check(sd.Market.Out[id].St == "Paid" and sd.BankGold == 1047, "off: a sale made before still pays", show(sd.Market.Out[id]))
	a.Config.Features.Market = true
	local id2 = listJelly(a, s, 5, 5)
	a.Config.Features.Market = false
	b.Config.Features.Market = false
	a:Remote("MarketCancel", s, id2)
	check(sd.Market.Out[id2].St == "Cancel" and sd.Items.Jelly == 20, "off: a seller can still take a listing back", show(sd.Market.Out[id2]))
	n = #b.Notices
	b:Remote("MarketBuy", buyer, id2, 5)
	check(notes(b, buyer, n) == "The market is closed.", "off: no purchase", notes(b, buyer, n))
	-- review 10/14: a crafted weapon (a spare) is taken out with Crafting on even while the market is off; both off = nothing
	local u, ud = hero(a, 52, { WeaponOwnedMask = 7, Spares = { ["5:0"] = 1 } })
	a.Config.Features.Crafting = false
	a:Remote("UnpackSpare", u, "5:0")
	check(ud.Spares["5:0"] == 1 and not bit32.btest(ud.WeaponOwnedMask, 16), "market and crafting off: the spare stays", show(ud.Spares))
	a.Config.Features.Crafting = true
	a:Remote("UnpackSpare", u, "5:0")
	check(ud.Spares["5:0"] == nil and bit32.btest(ud.WeaponOwnedMask, 16), "market off, crafting on: the crafted weapon comes out", show(ud.Spares))
	a.Config.Features.Crafting = false
end)

runGroup("mine rows", function()
	local w = marketWorld()
	local p, d = hero(w, 60, { Items = { Jelly = 999 } })
	listJelly(w, p, 1, 3)
	w:Advance(10)
	listJelly(w, p, 2, 4)
	w:Remote("MarketMine", p)
	local mine = last(w, "MarketMine", p)
	check(#mine.Rows == 2 and mine.Rows[1].Price == 4 and mine.Rows[2].Price == 3, "newest first", show(mine.Rows))
	check(mine.Rows[1].Key == "I:Jelly" and mine.Rows[1].N == 2 and mine.Rows[1].Plus == 0 and mine.Rows[1].State == "Open"
		and mine.Today.Lists == 2 and mine.Today.Buys == 0, "Key, N, Plus, State, Today", show(mine.Rows[1]))
	check(mine.Gate and mine.Gate.Buy == "" and mine.Gate.List == "", "Gate", show(mine.Gate))
end)

finish()
