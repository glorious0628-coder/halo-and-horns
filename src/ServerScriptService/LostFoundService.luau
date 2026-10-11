-- LostFoundService.luau : #45 Lost & Found (content_beyond_10min C; 게임성 개발 3, 2026-10-10; contract
-- docs/design/lost_found_server_2026-10-10.md). A monster sometimes drops what somebody lost; the player's own hunting is
-- the choice: give it back (Good) or ask a finder's fee / keep it as a trophy (Evil). Built on the shared ChoiceCard and
-- the daily Deeds ledger: this module owns only the beat, the one held thing, the walk and the payment.
--   * The beat: every kill (a paid one, not a free rider's) in a zone that has an item counts for that player. Below
--     Config.LostFound.From nothing drops; from there the chance rises evenly to 1 at Sure. A find resets the count. At
--     most DayCap finds a KST day (the count then waits), one thing is held at a time (no counting while holding).
--   * A find opens the ChoiceCard of the item (Config.LostFound.Items[id].Card). The card pays nothing itself (its
--     points go through Deeds); the pick decides the walk: Good and a child's Evil = the Lost & Found bench in the
--     Crossroads, a non-child's Evil = the player's own town (the vault). Arriving pays RewardMinutes of hunting.
--   * The walk is a quest-list row (Kind "Find", QuestService.publish calls LostFoundService.Rows). Nothing is lost
--     by a KO or a plunder: the held thing is only this record (data.LostFound.Holding), not a bag item.
-- Save: data.LostFound = { Day, N (finds today), K (kills since the last find), Holding = { Id, Phase "Choose" | "Carry",
--   Side, Leg "Bench" | "Vault", First } | nil }, repaired on every read. Nothing is sold; no purchase prompt belongs near.
--   LostFoundService.Chance(kills) -> 0..1      the beat
--   LostFoundService.OnKilled(player, info)      MonsterService.MonsterKilled
--   LostFoundService.Deliver(player) -> bool     at the bench / the vault now? (the 1 s loop; public for tests)
--   LostFoundService.Rows(player, data) -> rows  the quest-list row while a thing is on its way
--   LostFoundService.DebugFind(player, id?) / DebugClear(player)   Studio test aids
-- Signals: Found(player, itemId, zoneId), Delivered(player, itemId, side, leg, result).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LostFoundService = {}
LostFoundService.Found = Util.Signal.new() -- (player, itemId, zoneId)
LostFoundService.Delivered = Util.Signal.new() -- (player, itemId, side, leg, result = { Gold, XP, Count })

local TAG = "LostFoundService"
local S = nil
local CARRY = {} -- [Player] = true while a found thing is on its way (the 1 s loop looks at these only)

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function cfg()
	return type(Config.LostFound) == "table" and Config.LostFound or {}
end

local function on()
	return cfg().Enabled == true
end

local function itemDef(id)
	local items = cfg().Items
	if type(id) ~= "string" or type(items) ~= "table" or type(items[id]) ~= "table" then return nil end
	return items[id]
end

local function dirty(player)
	local q = S and S.QuestService
	if q and type(q.MarkDirty) == "function" then pcall(q.MarkDirty, player) end
end

local function notify(player, text, kind)
	if type(text) ~= "string" or text == "" then return end
	local ok, err = pcall(Net.Notify, player, text, kind or "reward")
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

------------------------------------------------------------------ save
-- data.LostFound repaired in place; a new KST day starts at 0 finds (the kill count carries over)
local function state(data)
	if type(data.LostFound) ~= "table" then data.LostFound = {} end
	local st = data.LostFound
	local today = Config.DayIndex(os.time())
	if num(st.Day, -1) ~= today then st.Day, st.N = today, 0 end
	st.N = math.clamp(math.floor(num(st.N)), 0, 1000)
	st.K = math.clamp(math.floor(num(st.K)), 0, 1000000)
	local h = st.Holding
	if h ~= nil then
		local good = type(h) == "table" and itemDef(h.Id) ~= nil and (h.Phase == "Choose" or h.Phase == "Carry")
		if good and h.Phase == "Carry" then
			good = (h.Side == "Good" or h.Side == "Evil") and (h.Leg == "Bench" or h.Leg == "Vault")
		end
		if good then
			h.First = h.First == true
		else
			st.Holding = nil
		end
	end
	return st
end

local function dataOf(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	if ok and type(data) == "table" then return data end
	return nil
end

------------------------------------------------------------------ the beat
function LostFoundService.Chance(kills)
	local C = cfg()
	local from = math.max(1, math.floor(num(C.From, 60)))
	local sure = math.max(from, math.floor(num(C.Sure, 100)))
	kills = math.floor(num(kills))
	if kills < from then return 0 end
	if kills >= sure then return 1 end
	return (kills - from + 1) / (sure - from + 1)
end

-- the item that drops in a zone (its season, if any, must be on), or nil
local function itemForZone(zoneId)
	for _, id in cfg().Order or {} do
		local d = itemDef(id)
		if d and d.Zone == zoneId and Config.SeasonOn(d.Season) then return id, d end
	end
	return nil
end

-- opens the item's card (false = another card is open; the next kill tries again)
local function offer(player, st)
	local h = st.Holding
	local d = h and itemDef(h.Id)
	if not d or h.Phase ~= "Choose" or type(d.Card) ~= "string" then return false end
	local ok, opened = pcall(S.ChoiceCard.Offer, player, d.Card, { Item = h.Id })
	if not ok then
		Util.Warn(TAG, "Offer " .. d.Card .. ": " .. tostring(opened))
		return false
	end
	return opened == true
end

local function find(player, st, id, zoneId)
	st.N += 1
	st.K = 0
	st.Holding = { Id = id, Phase = "Choose", First = st.N == 1 }
	LostFoundService.Found:Fire(player, id, zoneId)
	offer(player, st)
end

function LostFoundService.OnKilled(player, info)
	if not on() or typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
	if type(info) ~= "table" or info.Minor == true then return end
	local okReady, ready = pcall(S.PlayerService.IsReady, player)
	if not okReady or not ready then return end
	local data = dataOf(player)
	if not data then return end
	local st = state(data)
	if st.Holding then
		-- a find whose card could not open yet (another card was open) is offered again (ChoiceCard opens one card at a time)
		if st.Holding.Phase == "Choose" then offer(player, st) end
		return
	end
	if st.N >= math.max(0, math.floor(num(cfg().DayCap, 3))) then return end
	local id = itemForZone(info.ZoneId)
	if not id then return end
	st.K = math.min(1000000, st.K + 1)
	local chance = LostFoundService.Chance(st.K)
	if chance > 0 and Util.Random:NextNumber() < chance then
		find(player, st, id, info.ZoneId)
	end
end

------------------------------------------------------------------ the pick
local function onPicked(player, kind, side)
	local id, d = nil, nil
	for itemId, def in cfg().Items or {} do
		if type(def) == "table" and def.Card == kind then id, d = itemId, def end
	end
	if not id or (side ~= "Good" and side ~= "Evil") then return end
	local data = dataOf(player)
	if not data then return end
	local st = state(data)
	local h = st.Holding
	if not h or h.Id ~= id or h.Phase ~= "Choose" then return end
	h.Phase, h.Side = "Carry", side
	h.Leg = (side == "Evil" and d.Owner ~= "Kid") and "Vault" or "Bench"
	CARRY[player] = true
	dirty(player)
end

------------------------------------------------------------------ the walk
local function factionOf(player)
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

-- is the player where this leg ends? the bench (a spot in the Crossroads) or the own town (the vault)
local function legReady(player, leg)
	local okZone, zoneId = pcall(S.ZoneService.GetZoneId, player)
	if not okZone then return false end
	if leg == "Vault" then return zoneId == Config.HomeZoneId(factionOf(player)) end
	local B = cfg().Bench or {}
	if zoneId ~= (B.Zone or "Crossroads") then return false end
	local spot = Config.StoryQuests.Landmarks[B.Spot or "KidsBench"]
	if typeof(spot) ~= "Vector3" then return true end
	local root = Util.GetRoot(player)
	return root ~= nil and Util.FlatDistance(root.Position, spot) <= num(B.Range, 10)
end

-- what the bench / vault pays (a fixed amount of hunting at the player's level, never 2x)
local function rewardOf(data, h)
	local C = cfg()
	local R = type(C.Reward) == "table" and C.Reward or {}
	local level = math.max(1, math.floor(num(data.Level, 1)))
	local gold, xp = Config.HuntValue(level, num(C.RewardMinutes, 2))
	local out = { Gold = 0, XP = 0, Bag = {} }
	if h.Side == "Good" then
		local g = type(R.Good) == "table" and R.Good or {}
		out.XP = xp
		for id, n in g.Give or {} do out.Bag[id] = math.max(0, math.floor(num(n))) end
		if h.First and type(g.FirstScroll) == "string" then out.Bag[g.FirstScroll] = (out.Bag[g.FirstScroll] or 0) + 1 end
	else
		out.Gold = gold
	end
	return out
end

local function itemName(id)
	local item = Config.Loot.Items[id]
	return (item and item.Name) or (Config.Loot.Text.Potion and Config.Loot.Text.Potion[id]) or id
end

-- the payment: items through LootService (a full bag pays the rest at its sell price), gold to the bank as "Choice" (never
-- 2x), XP with its own amount as the cap (never 2x). Returns the line parts and what was really paid
local function pay(player, reward)
	local parts, paid = {}, { Gold = 0, XP = 0, Count = 0 }
	local ids = {}
	for id in reward.Bag do table.insert(ids, id) end
	table.sort(ids)
	local gold = math.max(0, math.floor(num(reward.Gold)))
	for _, id in ids do
		local want = reward.Bag[id]
		if want > 0 then
			local given = 0
			local ok, res = pcall(S.LootService.GrantItem, player, id, want)
			if ok then
				given = math.clamp(math.floor(num(res)), 0, want)
			else
				Util.Warn(TAG, "GrantItem: " .. tostring(res))
			end
			local item = Config.Loot.Items[id]
			gold += (want - given) * math.max(0, math.floor(num(item and item.Sell)))
			if given > 0 then
				paid.Count += given
				table.insert(parts, given > 1 and string.format(Config.Loot.Text.GotN, itemName(id), given)
					or string.format(Config.Loot.Text.Got, itemName(id)))
			end
		end
	end
	if gold > 0 then
		local ok, added = pcall(S.ProgressionService.AddBankGold, player, gold, "Choice")
		if ok then
			paid.Gold = type(added) == "number" and added or gold
			table.insert(parts, string.format(Config.StoryQuests.Text.ChoiceGold, Util.FormatNumber(paid.Gold)))
		else
			Util.Warn(TAG, "gold: " .. tostring(added))
		end
	end
	local xp = math.max(0, math.floor(num(reward.XP)))
	if xp > 0 then
		local ok, added = pcall(S.ProgressionService.AddXP, player, xp, xp)
		if ok then
			paid.XP = type(added) == "number" and added or xp
			table.insert(parts, string.format((Config.ChoiceCard.Text or {}).XP or "+%s XP", Util.FormatNumber(paid.XP)))
		else
			Util.Warn(TAG, "xp: " .. tostring(added))
		end
	end
	return parts, paid
end

function LostFoundService.Deliver(player)
	if not on() or typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false end
	local okReady, ready = pcall(S.PlayerService.IsReady, player)
	if not okReady or not ready then return false end
	local data = dataOf(player)
	if not data then return false end
	local st = state(data)
	local h = st.Holding
	if not h or h.Phase ~= "Carry" then
		CARRY[player] = nil
		return false
	end
	if not legReady(player, h.Leg) then return false end
	local d = itemDef(h.Id)
	-- committed before anything is paid: a failing payment never pays twice
	st.Holding = nil
	CARRY[player] = nil
	local parts, paid = pay(player, rewardOf(data, h))
	-- A23-130: the reward parts only (no NPC thank-you lead); nothing paid = no line
	notify(player, table.concat(parts, " · "), "reward")
	dirty(player)
	LostFoundService.Delivered:Fire(player, h.Id, h.Side, h.Leg, paid)
	return true
end

------------------------------------------------------------------ the quest-list row
function LostFoundService.Rows(player, data)
	if not on() or type(data) ~= "table" then return {} end
	local st = state(data)
	local h = st.Holding
	local d = h and h.Phase == "Carry" and itemDef(h.Id) or nil
	if not d then return {} end
	local C = cfg()
	local T = C.Text or {}
	local bench = h.Leg == "Bench"
	local reward = rewardOf(data, h)
	return { {
		Id = "find:" .. h.Id, Kind = "Find", Pinned = false,
		Text = string.format(bench and (T.RowBench or "%s") or (T.RowVault or "%s"), d.Name),
		ShortName = bench and T.ShortBench or T.ShortVault,
		Progress = 0, Target = 1, RewardGold = reward.Gold, RewardXP = reward.XP, CanClaim = false, ShowProgress = false,
		-- Guide: the same names the story rows use ("Fountain": the bench is 25 studs from it; "OwnTown")
		Find = { Item = h.Id, Leg = h.Leg, Guide = bench and "Fountain" or "OwnTown" },
	} }
end

------------------------------------------------------------------ Studio test aids
-- a find now (id, or the item of the player's zone, or the first item); the card opens like a real find
function LostFoundService.DebugFind(player, id)
	local data = dataOf(player)
	if not data then return "no data" end
	local st = state(data)
	if st.Holding then return "already holding " .. tostring(st.Holding.Id) end
	local zoneId = nil
	local okZone, z = pcall(S.ZoneService.GetZoneId, player)
	if okZone then zoneId = z end
	local itemId = itemDef(id) and id or select(1, itemForZone(zoneId)) or (cfg().Order or {})[1]
	local d = itemDef(itemId)
	if not d then return "no such item" end
	find(player, st, itemId, d.Zone)
	return "found " .. itemId
end

function LostFoundService.DebugClear(player)
	local data = dataOf(player)
	if not data then return "no data" end
	data.LostFound = nil
	CARRY[player] = nil
	dirty(player)
	return "cleared"
end

------------------------------------------------------------------ service
function LostFoundService.Init(registry)
	S = registry
end

function LostFoundService.Start()
	S.MonsterService.MonsterKilled:Connect(function(player, info)
		local ok, err = pcall(LostFoundService.OnKilled, player, info)
		if not ok then Util.Warn(TAG, "kill: " .. tostring(err)) end
	end)
	S.ChoiceCard.Picked:Connect(function(player, kind, side)
		local ok, err = pcall(onPicked, player, kind, side)
		if not ok then Util.Warn(TAG, "picked: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(function()
			local st = state(data)
			if st.Holding and st.Holding.Phase == "Carry" then CARRY[player] = true end
		end)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		CARRY[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in CARRY do
				if player.Parent ~= Players then
					CARRY[player] = nil
				else
					local ok, err = pcall(LostFoundService.Deliver, player)
					if not ok then Util.Warn(TAG, "deliver: " .. tostring(err)) end
				end
			end
		end
	end)
	print("[LostFoundService] started")
end

return LostFoundService
