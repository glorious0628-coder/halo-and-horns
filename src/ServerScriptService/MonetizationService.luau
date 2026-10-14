-- MonetizationService.luau : the change-ticket counters and A23-75 game passes. The ONLY server user of
-- MarketplaceService: game pass ownership (2x XP / 2x Gold / VIP / faction looks), subscriptions, SetLook and the VIP
-- supporter board. Change tickets are earned in play only (daily chest, the tamer's free one): A23-28 = no Robux change
-- tickets in the beta, so there is no Developer Product and no receipt handler (최종 검수 10/14 ③). data.Tickets is
-- mutated directly here (documented exception); data.ProcessedReceipts stays in the save, unused.
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "MonetizationService"

local MonetizationService = {}
-- A23-75 / A23-79 (game dev 3, metrics PassShop Bought): (player, key) once per real purchase of a game pass (key = a
-- Config.GamePasses kind or a sold look id), after it is on; never for the join check, a Studio override or Id 0
MonetizationService.PassBought = Util.Signal.new()

local S = nil

local ATTRIBUTE = { Class = "ClassTickets", Faction = "FactionTickets" }

------------------------------------------------------------------ helpers
local function ticketTable(player)
	local data = S.PlayerService.GetData(player)
	if not data then return nil end
	if type(data.Tickets) ~= "table" then
		data.Tickets = { Class = 0, Faction = 0 }
	end
	return data.Tickets
end

local function publish(player)
	for kind, attr in ATTRIBUTE do
		player:SetAttribute(attr, MonetizationService.GetTickets(player, kind))
	end
end

------------------------------------------------------------------ A23-75 game passes, looks, supporter board
-- docs/design/gamepass_server_2026-10-08.md. PASS.Owned[player][key] = true while the player owns that pass (key =
-- a Config.GamePasses kind or a sold Config.Looks id): the server's truth for HasPass (the attributes are only for the
-- screen). Ownership comes from Roblox when the player joins (UserOwnsGamePassAsync, Config.PassBoost.CheckTries with
-- a doubling wait; when every try fails, the last saved answer data.PassSeen counts) and at once from
-- PromptGamePassPurchaseFinished (purchased = true). A pass with Id 0 is never asked about (it is not sold yet).
-- PASS.Seen[player][key] = true: A23-75 review 2026-10-08, the last saved answer (data.PassSeen) set at PlayerReady; it
-- counts for a sold pass until Roblox answers about it (PASS.Owned), so grants paid while the player joins see it.
-- PASS.Debug[player][key] = true / false: a Studio DebugCommand "Pass" override (never saved, never on the board).
-- PASS.Want / Queued / Wrote [UserId]: the shared supporter list's pending change, its queued write, the last write.
-- PASS.Real[player][key] = true / false: what Roblox itself answered this session (the join check, a confirmed purchase);
-- never the saved fallback (PassAnswer, 최종 검수 10/13 review)
local PASS = { Owned = {}, Seen = {}, Debug = {}, Board = {}, Store = nil, Want = {}, Queued = {}, Wrote = {}, Tries = {}, Real = {} }

-- the passes this server sells: { { Key = kind or look id, Id = game pass id } }
function PASS.Sold()
	local list = {}
	for kind, p in Config.GamePasses do
		local id = tonumber(p.Id)
		if id and id > 0 then table.insert(list, { Key = kind, Id = id }) end
	end
	for lookId, look in Config.Looks do
		local id = tonumber(look.PassId)
		if id and id > 0 then table.insert(list, { Key = lookId, Id = id }) end
	end
	return list
end

-- one answer from Roblox: true / false, or nil when every try failed
function PASS.Ask(userId, passId)
	local wait = Config.PassBoost.CheckWait
	for i = 1, Config.PassBoost.CheckTries do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
		if ok and type(owns) == "boolean" then return owns end
		if i < Config.PassBoost.CheckTries then
			task.wait(wait)
			wait *= 2
		end
	end
	return nil
end

local function seenTable(data)
	if type(data.PassSeen) ~= "table" then data.PassSeen = {} end
	return data.PassSeen
end

local function looksTable(data)
	if type(data.Looks) ~= "table" then data.Looks = { Owned = {}, On = "" } end
	if type(data.Looks.Owned) ~= "table" then data.Looks.Owned = {} end
	if type(data.Looks.On) ~= "string" then data.Looks.On = "" end
	return data.Looks
end

-- true while the player owns the pass `key` (a Config.GamePasses kind or a sold look id); a Studio override first
function MonetizationService.HasPass(player, key)
	local d = PASS.Debug[player]
	if d and d[key] ~= nil then return d[key] == true end
	local o = PASS.Owned[player]
	if o ~= nil and o[key] ~= nil then return o[key] == true end
	local s = PASS.Seen[player] -- not answered yet this session: the last saved answer (A23-75 review 2026-10-08)
	return s ~= nil and s[key] == true
end

-- Roblox's own answer about the pass `key` THIS session (the join check or a confirmed purchase): true / false, or nil while
-- it has not answered (HasPass then uses the saved last answer). A Studio override counts as the answer. TestMetricsService's
-- "still works after a rejoin" counts only this (최종 검수 10/13 review)
function MonetizationService.PassAnswer(player, key)
	local d = PASS.Debug[player]
	if d and d[key] ~= nil then return d[key] == true end
	local r = PASS.Real[player]
	if r ~= nil and r[key] ~= nil then return r[key] == true end
	return nil
end

------------------------------------------------------------------ A23-182 subscriptions (Fast Travel)
local SUB = { Active = setmetatable({}, { __mode = "k" }) } -- [Player] = { [key] = true / false } Roblox's answer this session

-- the id Roblox's API takes: "EXP-<number>" for a number Id > 0, a non-empty string as it is; nil = off (0 / missing)
function MonetizationService.SubscriptionApiId(key)
	local def = type(Config.Subscriptions) == "table" and Config.Subscriptions[key] or nil
	local id = type(def) == "table" and def.Id or nil
	if type(id) == "number" and id == id and id > 0 and id == math.floor(id) then return string.format("EXP-%d", id) end
	if type(id) == "string" and id ~= "" and id ~= "0" then return id end
	return nil
end

-- the saved last answer's key in data.PassSeen (Config.SanitizeLooks keeps "Sub:<key>" of a Config.Subscriptions key)
function SUB.SeenKey(key)
	return "Sub:" .. tostring(key)
end

-- one answer from Roblox: true / false, or nil when every try failed (Config.PassBoost.CheckTries, doubling wait)
function SUB.Ask(player, apiId)
	local pause = Config.PassBoost.CheckWait
	for try = 1, Config.PassBoost.CheckTries do
		local ok, res = pcall(MarketplaceService.GetUserSubscriptionStatusAsync, MarketplaceService, player, apiId)
		if ok and type(res) == "table" and type(res.IsSubscribed) == "boolean" then return res.IsSubscribed end
		if try < Config.PassBoost.CheckTries and player.Parent ~= nil then
			task.wait(pause)
			pause *= 2
		else
			break
		end
	end
	return nil
end

function SUB.Set(player, key, on)
	local def = Config.Subscriptions[key]
	SUB.Active[player] = SUB.Active[player] or {}
	SUB.Active[player][key] = on
	if type(def) == "table" and type(def.Attr) == "string" then player:SetAttribute(def.Attr, on) end
end

-- asks Roblox about one subscription and mirrors it (attribute Attr). 최종 검수 10/14 ①: a failing ask is tried again
-- like the passes (PASS.Ask); when every try fails the last answer Roblox gave (saved, data.PassSeen["Sub:<key>"]) counts
-- (none saved = off). An off id (Id 0) = false, never asked, nothing saved
function SUB.Check(player, key)
	local apiId = MonetizationService.SubscriptionApiId(key)
	local answer = false
	if apiId then answer = SUB.Ask(player, apiId) end
	if player.Parent == nil then return end
	local data = S.PlayerService.GetData(player)
	if answer == nil then
		answer = data ~= nil and seenTable(data)[SUB.SeenKey(key)] == true
	elseif apiId and data then
		seenTable(data)[SUB.SeenKey(key)] = answer
	end
	SUB.Set(player, key, answer)
end

function SUB.CheckAll(player)
	-- the saved last answers first (nothing waits for Roblox), then Roblox's answer replaces each
	local data = S.PlayerService.GetData(player)
	for key in type(Config.Subscriptions) == "table" and Config.Subscriptions or {} do
		if player.Parent == nil then return end
		local saved = data ~= nil and MonetizationService.SubscriptionApiId(key) ~= nil and seenTable(data)[SUB.SeenKey(key)] == true
		SUB.Set(player, key, saved)
	end
	for key in type(Config.Subscriptions) == "table" and Config.Subscriptions or {} do
		local ok, err = pcall(SUB.Check, player, key)
		if not ok then Util.Warn(TAG, "subscription " .. tostring(key) .. ": " .. tostring(err)) end
	end
end

-- true while Roblox said this session that the player is subscribed to `key` (Config.Subscriptions)
function MonetizationService.HasSub(player, key)
	local a = SUB.Active[player]
	return a ~= nil and a[key] == true
end

-- A23-75 review 2026-10-08: PlayerReady, before every later handler (QuestService's day check pays finished dailies and
-- the chest there, attendance pays at join): the saved answers of the sold passes count at once. PASS.Check then
-- replaces each with Roblox's answer (a refund turns it off).
function PASS.Seed(player)
	local data = S.PlayerService.GetData(player)
	local seen = {}
	if data then
		for _, p in PASS.Sold() do
			if seenTable(data)[p.Key] == true then seen[p.Key] = true end
		end
	end
	PASS.Seen[player] = seen
end

-- A23-75 review 2026-10-08 (검수 3rd look): Roblox has said yes to VIP (the saved answer); an unconfirmed VIP (Roblox
-- did not answer after a purchase) is shown on this server's board only
function PASS.Confirmed(player)
	local data = S.PlayerService.GetData(player)
	return data ~= nil and seenTable(data).VIP == true
end

-- true when the player may wear the look: its pass is owned, or it was unlocked (attendance, data.Looks.Owned)
function MonetizationService.OwnsLook(player, id)
	if type(id) ~= "string" or not Config.Looks[id] then return false end
	if MonetizationService.HasPass(player, id) then return true end
	local data = S.PlayerService.GetData(player)
	return data ~= nil and looksTable(data).Owned[id] ~= nil
end

-- the owned look ids in shop order
function MonetizationService.LooksOwned(player)
	local list = {}
	for _, id in Config.LookOrder() do
		if MonetizationService.OwnsLook(player, id) then table.insert(list, id) end
	end
	return list
end

-- the worn look: the saved one while it is owned and of the player's faction (a faction switch hides it; switching back
-- shows it again), else ""
function PASS.Worn(player)
	local data = S.PlayerService.GetData(player)
	if not data then return "" end
	local id = looksTable(data).On
	local look = Config.Looks[id]
	if not look or look.Faction ~= player:GetAttribute("Faction") or not MonetizationService.OwnsLook(player, id) then
		return ""
	end
	return id
end

-- A23-144: may this player show the chat bubble `key` now? (my side's free one, or a pack skin with the Bubble Pack)
function PASS.BubbleUsable(player, key)
	if not Config.IsBubble(key) then return false end
	local side = Config.BubbleSide(key)
	if side then return side == player:GetAttribute("Faction") end
	return MonetizationService.HasPass(player, Config.Bubbles.Pass)
end

-- A23-144: the bubble that shows now: the saved pick while I may use it, else my side's free one ("" = no side yet)
function PASS.BubbleOf(player)
	local data = S.PlayerService.GetData(player)
	local want = type(data) == "table" and data.Bubble or ""
	if type(want) == "string" and want ~= "" and PASS.BubbleUsable(player, want) then return want end
	local free = Config.Bubbles.Free[player:GetAttribute("Faction")]
	return type(free) == "string" and free or ""
end

-- A23-144: SetBubble(key): one argument, "" or a skin I may use now, at most every RateLimits.SetBubble s; saved, then
-- BubbleOn. A skin I may not use is dropped without a word (the screen shows it locked)
function PASS.OnSetBubble(player, ...)
	if select("#", ...) ~= 1 then return end
	local key = ...
	if type(key) ~= "string" or #key > 32 then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "SetBubble", Config.RateLimits.SetBubble or 0.5) then return end
	local data = S.PlayerService.GetData(player)
	if not data then return end
	if key ~= "" and not PASS.BubbleUsable(player, key) then return end
	data.Bubble = key
	player:SetAttribute("BubbleOn", PASS.BubbleOf(player))
end

-- the screen's copy: PassXP2 / PassGold2 / PassVIP (Config.GamePasses Attr), LooksOwned, LookOn
function PASS.Publish(player)
	if player.Parent == nil then return end
	for kind, p in Config.GamePasses do
		player:SetAttribute(p.Attr, MonetizationService.HasPass(player, kind))
	end
	player:SetAttribute("LooksOwned", table.concat(MonetizationService.LooksOwned(player), ","))
	player:SetAttribute("LookOn", PASS.Worn(player))
	player:SetAttribute("BubbleOn", PASS.BubbleOf(player)) -- A23-144
end

-- the join check (its own thread: Roblox can take a few seconds)
function PASS.Check(player)
	local data = S.PlayerService.GetData(player)
	if not data or player.Parent == nil then return end
	local owned = PASS.Owned[player] or {}
	PASS.Owned[player] = owned
	local wasVip = seenTable(data).VIP == true
	PASS.Publish(player) -- the saved answers / looks first: nothing waits for Roblox
	for _, p in PASS.Sold() do
		local answer = PASS.Ask(player.UserId, p.Id)
		if player.Parent == nil or S.PlayerService.GetData(player) ~= data then return end
		if answer == nil then
			answer = seenTable(data)[p.Key] == true -- Roblox did not answer: the last answer it gave
		else
			-- A23-75 review 2026-10-08 (2nd look): a purchase while Roblox was asked keeps its saved yes
			seenTable(data)[p.Key] = answer or owned[p.Key] == true
			local real = PASS.Real[player] or {}
			PASS.Real[player] = real
			if real[p.Key] ~= true then real[p.Key] = answer end -- a purchase meanwhile is never taken back
		end
		if owned[p.Key] ~= true then owned[p.Key] = answer end -- a purchase meanwhile is never taken back
	end
	PASS.Publish(player)
	-- a VIP owner who shows their name is listed. A23-75 review 2026-10-08: one who hides it, or a refunded one (Roblox
	-- now says no to a VIP saved as owned), comes off this server's board and the shared list
	if owned.VIP == true then
		if player:GetAttribute("HideAnnounceName") == true then
			PASS.RemoveSupporter(player)
		elseif MonetizationService.HasPass(player, "VIP") then
			PASS.AddSupporter(player)
		end
	elseif wasVip and owned.VIP == false then
		PASS.RemoveSupporter(player)
	end
end

-- PromptGamePassPurchaseFinished. A23-75 review 2026-10-08 (검수 3rd look): its `purchased` comes from the client's
-- prompt, so Roblox is asked again (PASS.Ask) before anything is kept: yes = the purchase (on, saved in PassSeen, the
-- shared supporter list, PassBought); no answer = on for this session only (nothing saved, this server's board only,
-- no PassBought; the next join asks again); no = ignored with a warning. Studio: the DebugSetPass road (this session
-- only, nothing saved or shared, no PassBought, the save marked DebugTainted) - the main Studio is the real place.
function PASS.Purchased(player, passId, purchased)
	if purchased ~= true or typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then return end
	for _, p in PASS.Sold() do
		if p.Id ~= passId then continue end
		if RunService:IsStudio() then
			local data = S.PlayerService.GetData(player)
			if data then data.DebugTainted = true end
			MonetizationService.DebugSetPass(player, p.Key, "on")
			continue
		end
		local answer = PASS.Ask(player.UserId, p.Id)
		-- gamepass_3f5dd020_verify (개발 3, 2026-10-09): right after a purchase Roblox may still answer an old cached
		-- "no"; a no is asked again at each PurchaseRecheck time (s after the signal) before it is believed
		local waited = 0
		for _, at in Config.PassBoost.PurchaseRecheck or {} do
			if answer ~= false or player.Parent == nil then break end
			task.wait(math.max(0, at - waited))
			waited = math.max(waited, at)
			if player.Parent == nil then return end
			answer = PASS.Ask(player.UserId, p.Id)
		end
		if player.Parent == nil then return end
		if answer == false then
			Util.Warn(TAG, ("%s: a purchase of %s that Roblox does not confirm (ignored)"):format(player.Name, p.Key))
			continue
		end
		local owned = PASS.Owned[player] or {}
		PASS.Owned[player] = owned
		owned[p.Key] = true
		local data = S.PlayerService.GetData(player)
		if answer == true and data then seenTable(data)[p.Key] = true end
		if answer == true then
			local real = PASS.Real[player] or {}
			PASS.Real[player] = real
			real[p.Key] = true
		end
		PASS.Publish(player)
		if p.Key == "VIP" then PASS.AddSupporter(player, answer ~= true) end
		if answer == true then
			print(("[MonetizationService] %s bought game pass %s"):format(player.Name, p.Key))
			MonetizationService.PassBought:Fire(player, p.Key)
		end
	end
end

-- c->s SetLook(id): one string <= 32, an owned look of the player's faction, or "" (wear none); anything else ignored
-- A23-143: a chat sticker over my head for everyone: one argument, a known sticker, every RateLimits.SendSticker s, ready
-- and alive, free or the Sticker Pack owned; anything else is dropped without a word
function PASS.OnSticker(player, ...)
	if select("#", ...) ~= 1 then return end
	local key = ...
	if not Config.IsSticker(key) then return end
	if not Util.RateLimit(player, "SendSticker", Config.RateLimits.SendSticker or 2) then return end
	if not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return end
	if not Config.StickerFree(key) and not MonetizationService.HasPass(player, Config.Stickers.Pass) then return end
	local ok, err = pcall(Net.Fx, nil, "Sticker", { UserId = player.UserId, Key = key })
	if not ok then Util.Warn(TAG, "sticker: " .. tostring(err)) end
end

function PASS.OnSetLook(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or #id > 32 then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "SetLook", Config.RateLimits.SetLook) then return end
	local data = S.PlayerService.GetData(player)
	if not data then return end
	if id ~= "" then
		local look = Config.Looks[id]
		if not look or look.Faction ~= player:GetAttribute("Faction") or not MonetizationService.OwnsLook(player, id) then
			return
		end
	end
	looksTable(data).On = id
	player:SetAttribute("LookOn", PASS.Worn(player))
end

-- A23-77 (AttendanceService): unlock an attendance look (Config.Looks with Unlock, never a sold one). True when new.
function MonetizationService.GrantLook(player, id)
	local look = type(id) == "string" and Config.Looks[id] or nil
	if not look or type(look.Unlock) ~= "table" then return false end
	local data = S.PlayerService.GetData(player)
	if not data then return false end
	local owned = looksTable(data).Owned
	if owned[id] ~= nil then return false end
	owned[id] = os.time()
	PASS.Publish(player)
	return true
end

------------------------------------------------------------------ supporter board (VIP owners of every server)
-- a clean board list: { { U = UserId, N = name, T = os.time() } }, one entry per UserId (the newest), newest first,
-- at most MaxSupporters; anything broken is dropped
function PASS.Clean(raw)
	local list, seen = {}, {}
	if type(raw) == "table" then
		for _, e in raw do
			if type(e) == "table" and type(e.U) == "number" and type(e.N) == "string" and e.N ~= "" and #e.N <= 80
				and type(e.T) == "number" and not seen[e.U] then
				seen[e.U] = true
				table.insert(list, { U = e.U, N = e.N, T = e.T })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.T ~= b.T then return a.T > b.T end
		return a.U < b.U
	end)
	while #list > Config.PassBoost.MaxSupporters do table.remove(list) end
	return list
end

-- `list` with `entry` put first (its older line removed)
function PASS.Insert(list, entry)
	local out = { entry }
	for _, e in list do
		if e.U ~= entry.U then table.insert(out, e) end
	end
	return PASS.Clean(out)
end

-- `list` without the line of `userId`
function PASS.Without(list, userId)
	local out = {}
	for _, e in list do
		if e.U ~= userId then table.insert(out, e) end
	end
	return out
end

-- A23-75 review 2026-10-08: a player on this server who hides their name never shows, whatever the shared list still
-- says (their removal may not have landed yet)
function PASS.Show(list)
	local shown = {}
	for _, e in list do
		local here = Players:GetPlayerByUserId(e.U)
		if not (here and here:GetAttribute("HideAnnounceName") == true) then table.insert(shown, e) end
	end
	PASS.Board = shown
	local names = {}
	for _, e in shown do table.insert(names, e.N) end
	local ok, err = pcall(function() Net.GameState():SetAttribute("SupporterNames", table.concat(names, "\n")) end)
	if not ok then Util.Warn(TAG, "supporter board: " .. tostring(err)) end
end

function PASS.GetStore()
	if PASS.Store == nil then
		-- A23-75 review 2026-10-08 (검수 3rd look): Studio writes its own list (like RankingService's STUDIO season)
		local name = Config.StoreName(Config.PassBoost.SupporterStore) .. (RunService:IsStudio() and "_STUDIO" or "")
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, name)
		PASS.Store = ok and store or false
	end
	return PASS.Store or nil
end

-- a VIP owner joined or bought VIP: on this server's board at once, then in the shared list (a player who hides
-- their name in announcements, P5, stays off the board)
function PASS.AddSupporter(player, localOnly)
	if player.Parent == nil or player:GetAttribute("HideAnnounceName") == true then return end
	local entry = { U = player.UserId, N = Util.PlayerDisplayName(player), T = os.time() }
	PASS.Show(PASS.Insert(PASS.Board, entry))
	if localOnly then return end
	PASS.Write(player.UserId, entry)
end

-- A23-75 review 2026-10-08: a VIP owner who hides their name (now or when joining) or was refunded: off this server's
-- board at once, then off the shared list
function PASS.RemoveSupporter(player)
	PASS.Show(PASS.Without(PASS.Board, player.UserId))
	PASS.Write(player.UserId, false)
end

-- A23-75 review 2026-10-08: the board follows a later P5 hide / show toggle at once (as KaijuService's KaijuName and
-- RankingService.MarkHideChanged do). Hidden: off this server's board and, for a VIP owner, off the shared list; shown
-- again: a VIP owner is listed again. Nobody else writes to the shared list.
function PASS.OnHideChanged(player)
	if player.Parent == nil then return end
	local vip = PASS.Owned[player] ~= nil and PASS.Owned[player].VIP == true
	if player:GetAttribute("HideAnnounceName") == true then
		if vip then PASS.RemoveSupporter(player) else PASS.Show(PASS.Board) end
	elseif vip and MonetizationService.HasPass(player, "VIP") then
		PASS.AddSupporter(player, not PASS.Confirmed(player))
	end
end

-- A23-75 review 2026-10-08 (검수 3rd look): the board shows the verified nickname (Util.PlayerDisplayName): a listed VIP
-- owner's line follows a later NicknameVerified / Nickname change (unchanged names write nothing)
function PASS.OnNameChanged(player)
	if player.Parent == nil or PASS.Owned[player] == nil or PASS.Owned[player].VIP ~= true then return end
	if player:GetAttribute("HideAnnounceName") == true or not MonetizationService.HasPass(player, "VIP") then return end
	local name = Util.PlayerDisplayName(player)
	for _, e in PASS.Board do
		if e.U == player.UserId and e.N == name then return end
	end
	PASS.AddSupporter(player, not PASS.Confirmed(player))
end

-- the shared list follows the player's latest choice (entry = listed first, false = taken off). A23-75 review
-- 2026-10-08: at most one write per UserId per Config.PassBoost.WriteGap seconds, so a hide on / off spam cannot use up
-- the server's DataStore budget; a change inside the gap is written once when the gap ends, with the choice as it is
-- then (also after the player left)
function PASS.Write(userId, entry)
	PASS.Want[userId] = entry
	if PASS.Queued[userId] then return end
	PASS.Queued[userId] = true
	local function run()
		PASS.Queued[userId] = nil
		PASS.Wrote[userId] = os.clock()
		local want = PASS.Want[userId]
		PASS.Want[userId] = nil
		local store = PASS.GetStore()
		if not store then return end
		local ok, result = pcall(store.UpdateAsync, store, Config.PassBoost.SupporterKey, function(old)
			local list = PASS.Clean(old)
			if want then return PASS.Insert(list, want) end
			local kept = PASS.Without(list, userId)
			if #kept == #list then return nil end -- not listed: nothing to write
			return kept
		end)
		if ok and type(result) == "table" then
			PASS.Show(PASS.Clean(result))
		elseif not ok then
			Util.Warn(TAG, "supporter board save: " .. tostring(result))
		end
		-- A23-75 review 2026-10-08 (2nd look): a failed write (a hide's removal too) is tried again WriteRetries times,
		-- unless a newer choice is queued by then
		local tries = ok and 0 or (PASS.Tries[userId] or 0) + 1
		if tries > 0 and tries <= Config.PassBoost.WriteRetries and not PASS.Queued[userId] then
			PASS.Tries[userId] = tries
			PASS.Write(userId, want)
		else
			PASS.Tries[userId] = nil
		end
	end
	local wait = (PASS.Wrote[userId] or -math.huge) + Config.PassBoost.WriteGap - os.clock()
	if wait > 0 then task.delay(wait, run) else task.spawn(run) end
end

-- every RefreshSeconds: the shared list (other servers' VIPs)
function PASS.Refresh()
	local store = PASS.GetStore()
	if not store then return end
	local ok, raw = pcall(store.GetAsync, store, Config.PassBoost.SupporterKey)
	if ok then PASS.Show(PASS.Clean(raw)) end
end

-- Studio test aid (Main DebugCommand "Pass", value "XP2:on" / "VIP:off" / "HaloIce:clear"): overrides the pass for
-- this session only (never saved, never on the shared board)
function MonetizationService.DebugSetPass(player, key, mode)
	if not (Config.GamePasses[key] or (Config.Looks[key] and Config.Looks[key].PassId ~= nil)) then
		return "unknown pass: " .. tostring(key)
	end
	local d = PASS.Debug[player] or {}
	PASS.Debug[player] = d
	if mode == "on" then d[key] = true elseif mode == "off" then d[key] = false else d[key] = nil end
	PASS.Publish(player)
	if key == "VIP" and MonetizationService.HasPass(player, "VIP") then PASS.AddSupporter(player, true) end
	return ("%s %s (HasPass = %s)"):format(key, tostring(mode), tostring(MonetizationService.HasPass(player, key)))
end

------------------------------------------------------------------ public API
function MonetizationService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		publish(player)
		PASS.Seed(player) -- A23-75 review 2026-10-08: before QuestService's (later) PlayerReady handler pays anything
		player:GetAttributeChangedSignal("HideAnnounceName"):Connect(function() -- A23-75 review 2026-10-08
			local ok, err = pcall(PASS.OnHideChanged, player)
			if not ok then Util.Warn(TAG, "supporter board: " .. tostring(err)) end
		end)
		for _, attr in { "NicknameVerified", "Nickname" } do -- A23-75 review 2026-10-08 (검수 3rd look)
			player:GetAttributeChangedSignal(attr):Connect(function()
				local ok, err = pcall(PASS.OnNameChanged, player)
				if not ok then Util.Warn(TAG, "supporter board: " .. tostring(err)) end
			end)
		end
		task.spawn(function() -- A23-75: game pass ownership (Roblox can take a few seconds)
			local ok, err = pcall(PASS.Check, player)
			if not ok then Util.Warn(TAG, "pass check: " .. tostring(err)) end
		end)
		task.spawn(SUB.CheckAll, player) -- A23-182: subscriptions, every join
	end)
end

function MonetizationService.Start()
	-- A23-75 game passes
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local ok, err = pcall(PASS.Purchased, player, passId, purchased)
		if not ok then Util.Warn(TAG, "pass purchase: " .. tostring(err)) end
	end)
	Net.Get("SetLook").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(PASS.OnSetLook, player, ...)
		if not ok then Util.Warn(TAG, "SetLook: " .. tostring(err)) end
	end)
	Net.Get("SetBubble").OnServerEvent:Connect(function(player, ...) -- A23-144
		local ok, err = pcall(PASS.OnSetBubble, player, ...)
		if not ok then Util.Warn(TAG, "SetBubble: " .. tostring(err)) end
	end)
	Net.Get("SendSticker").OnServerEvent:Connect(function(player, ...) -- A23-143
		local ok, err = pcall(PASS.OnSticker, player, ...)
		if not ok then Util.Warn(TAG, "SendSticker: " .. tostring(err)) end
	end)
	if S.FactionService and S.FactionService.FactionChanged then -- a look of the other side comes off (and back)
		S.FactionService.FactionChanged:Connect(function(player)
			pcall(PASS.Publish, player)
		end)
	end
	S.PlayerService.PlayerLeaving:Connect(function(player)
		PASS.Owned[player], PASS.Seen[player], PASS.Debug[player], PASS.Real[player] = nil, nil, nil, nil
		SUB.Active[player] = nil
	end)
	-- A23-182: a subscription bought / ended during the session (Roblox fires it on the server)
	local okSig, sig = pcall(function() return Players.UserSubscriptionStatusChanged end)
	if okSig and typeof(sig) == "RBXScriptSignal" then
		sig:Connect(function(player, subscriptionId)
			for key in type(Config.Subscriptions) == "table" and Config.Subscriptions or {} do
				if MonetizationService.SubscriptionApiId(key) == subscriptionId then
					local ok, err = pcall(SUB.Check, player, key)
					if not ok then Util.Warn(TAG, "subscription change: " .. tostring(err)) end
				end
			end
		end)
	end
	task.spawn(function() -- the shared supporter board, now and every RefreshSeconds
		while true do
			local ok, err = pcall(PASS.Refresh)
			if not ok then Util.Warn(TAG, "supporter board: " .. tostring(err)) end
			task.wait(Config.PassBoost.RefreshSeconds)
		end
	end)

	if RunService:IsStudio() then
		local ids = {}
		for _, p in PASS.Sold() do -- A23-75 review 2026-10-08 (2nd look): one id in two entries = one purchase, both on
			if ids[p.Id] then Util.Warn(TAG, ("game pass id %d is used twice: %s and %s"):format(p.Id, ids[p.Id], p.Key)) end
			ids[p.Id] = p.Key
		end
		if #PASS.Sold() == 0 then
			print("[MonetizationService] A23-75 game pass ids are 0: the shop shows 'Coming soon'. Create the passes on create.roblox.com (your game > Monetization > Passes) and paste their ids into Config.GamePasses / Config.Looks PassId.")
		end
	end

	print("[MonetizationService] started")
end

function MonetizationService.GetTickets(player, kind)
	if not ATTRIBUTE[kind] then return 0 end
	local t = ticketTable(player)
	if not t then return 0 end
	local n = tonumber(t[kind]) or 0
	if n ~= n then return 0 end
	return math.max(0, math.floor(n))
end

-- data.Tickets[kind] (>= 0) + attribute; returns the new count
function MonetizationService.AddTickets(player, kind, delta)
	if not ATTRIBUTE[kind] then
		Util.Warn(TAG, "unknown ticket kind: " .. tostring(kind))
		return 0
	end
	local t = ticketTable(player)
	if not t then return 0 end
	delta = tonumber(delta) or 0
	if delta ~= delta or delta == math.huge or delta == -math.huge then delta = 0 end
	local newCount = math.max(0, math.floor(MonetizationService.GetTickets(player, kind) + delta))
	t[kind] = newCount
	player:SetAttribute(ATTRIBUTE[kind], newCount)
	return newCount
end

-- consumes 1 if available; false, "None" when there is none
function MonetizationService.UseTicket(player, kind)
	if MonetizationService.GetTickets(player, kind) < 1 then return false, "None" end
	MonetizationService.AddTickets(player, kind, -1)
	return true
end

return MonetizationService
