-- GearService.luau : gear slots (게임성 개발 3, 2026-10-12; contract docs/design/gear_slots_2026-10-12.md; A23-133). Switched
-- by Config.Features.Gear (off: nothing can be worn, no attribute, no GearInfo; every multiplier is 1).
--   * The things: data.Gear.Own["<Slot>:T:P"] = n (CraftService pays them, Kind "Gear"; at most Config.Gear.OwnSum in all,
--     Config.SaveV4.OwnKeyMax of one key). Worn: data.Gear.On.<Armor|Ring> = "T:P" or "" and data.Gear.Pet[uid].<PetArmor|
--     PetAcc> = "T:P". A thing is in ONE place: wearing takes it out of Own, the one it replaces (or a take-off) goes back
--     to Own, and when Own has no room for it the whole change is turned down (Full). Nothing is destroyed or sold.
--   * The +N of a gear is ONLY the hammer's +0..+2 (Config.GearParse / Config.SanitizeGear): this module never changes a
--     plus, and no scroll reaches gear (LootService.UseItem takes weapon tiers only).
--   * c->s EquipGear(slot, key) / EquipPetGear(uid, slot, key): key = "T:P" of an Own thing, or "" to take it off. A ready,
--     living player, the wear level of the tier (Config.Gear.Slots[slot].Wear), my own pet only (PetService.GetPet), the
--     exact argument count, one change every Config.RateLimits.EquipGear seconds, never in a fight (CombatService.IsInCombat,
--     like a weapon swap: no max HP / speed change mid-PvP; 게임성 개발 2). Notices are keys only (Config.Gear.Text).
--   * The player's attributes GearAtk (the ring: my hit x) and GearHp (the armor: max HP x) are the multipliers (1 = none;
--     Config.GearMultsOf reads them, PlayerService / CombatService / Config.CombatPower use them), set at PlayerReady and
--     after every change (a new GearHp refreshes the max HP). The following pet's PetAcc and the pet XP bonus come from
--     data.Gear.Pet through PetService (Refresh republishes after a pet-gear change).
--   * s->c GearInfo { Own, On, Pet } at PlayerReady and after changes (also after a turned-down change, so the window
--     shows the truth). A pet that is gone (a later feature) gives its gear back to Own at PlayerReady (room permitting).
--   GearService.Equip(player, slot, key) · EquipPet(player, uid, slot, key) -> "ok" | reason (the remote handlers; public for
--   the offline test) · Mults(player) -> atk, hp
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local GearService = {}

local TAG = "GearService"
local S = nil
local UID_LEN = 32

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function on()
	return Config.FeatureOn("Gear") and type(Config.Gear) == "table"
end

local function getData(player)
	if not S then return nil end
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

-- data.Gear with its three tables (a broken save is repaired by Config.SanitizeGear, never made up)
local function gearOf(data)
	local g = data.Gear
	if type(g) ~= "table" or type(g.Own) ~= "table" or type(g.On) ~= "table" or type(g.Pet) ~= "table" then
		data.Gear = Config.SanitizeGear(g)
	end
	return data.Gear
end

local function notify(player, key, kind)
	local ok, err = pcall(Net.NotifyKey, player, "Config.Gear.Text." .. key, nil, kind or "bad")
	if not ok then Util.Warn(TAG, "notice " .. key .. ": " .. tostring(err)) end
end

------------------------------------------------------------------ Own
local function ownSum(own)
	local n = 0
	for _, c in own do n += math.max(0, math.floor(num(c))) end
	return n
end

-- room for one more of `kind` (the sum cap and the key cap)
local function roomFor(own, kind)
	return ownSum(own) < Config.Gear.OwnSum and math.floor(num(own[kind])) < Config.SaveV4.OwnKeyMax
end

local function addOwn(own, kind)
	own[kind] = math.floor(num(own[kind])) + 1
end

local function takeOwn(own, kind)
	local n = math.floor(num(own[kind])) - 1
	own[kind] = n > 0 and n or nil
end

------------------------------------------------------------------ what the clients see
-- the multipliers of what is worn now (1 + the bonus): ring -> atk, armor -> hp
function GearService.Mults(player)
	local data = getData(player)
	if not data then return 1, 1 end
	local g = gearOf(data)
	return 1 + Config.GearBonusOf("Ring", g.On.Ring), 1 + Config.GearBonusOf("Armor", g.On.Armor)
end

local function publishAttrs(player, g)
	local atk, hp = 1 + Config.GearBonusOf("Ring", g.On.Ring), 1 + Config.GearBonusOf("Armor", g.On.Armor)
	local before = num(player:GetAttribute("GearHp"), 1)
	player:SetAttribute("GearAtk", atk)
	player:SetAttribute("GearHp", hp)
	-- the armor moves the max HP now (the HP ratio stays)
	local ps = S and S.PlayerService
	if before ~= hp and type(ps) == "table" and type(ps.RefreshCharacter) == "function" then
		local ok, err = pcall(ps.RefreshCharacter, player, false)
		if not ok then Util.Warn(TAG, "RefreshCharacter: " .. tostring(err)) end
	end
end

local function sendInfo(player, g)
	local pet = {}
	for uid, row in g.Pet do
		if type(row) == "table" then pet[uid] = table.clone(row) end
	end
	local ok, err = pcall(function()
		Net.Get("GearInfo"):FireClient(player, { Own = table.clone(g.Own), On = table.clone(g.On), Pet = pet })
	end)
	if not ok then Util.Warn(TAG, "GearInfo: " .. tostring(err)) end
end

local function refreshPet(player)
	local P = S and S.PetService
	if type(P) == "table" and type(P.Refresh) == "function" then
		local ok, err = pcall(P.Refresh, player)
		if not ok then Util.Warn(TAG, "PetService.Refresh: " .. tostring(err)) end
	end
end

------------------------------------------------------------------ the one-place move
-- `worn` = the table that holds `slot` (data.Gear.On, or one pet's row). Returns "ok" + the notice key, or a reason (a notice
-- key for the ones the player should be told about). Own and `worn` change together or not at all.
local function move(g, data, slot, key, worn)
	local own = g.Own
	local current = type(worn[slot]) == "string" and worn[slot] or ""
	if key == "" then
		if current == "" then return "none" end
		local oldKind = slot .. ":" .. current
		if not roomFor(own, oldKind) then return "full", "Full" end
		addOwn(own, oldKind)
		worn[slot] = nil
		return "ok", "Removed"
	end
	local tier = Config.GearParse(key)
	if not tier then return "key" end
	if current == key then return "same" end
	local kind = slot .. ":" .. key
	if math.floor(num(own[kind])) < 1 then return "notyours", "NotYours" end
	local def = Config.GearDef(slot)
	if math.floor(num(data.Level, 1)) < num(def.Wear[tier], 1) then return "level", "NeedLevel" end
	takeOwn(own, kind)
	if current ~= "" then
		local oldKind = slot .. ":" .. current
		if not roomFor(own, oldKind) then
			addOwn(own, kind) -- undone: all of it or nothing
			return "full", "Full"
		end
		addOwn(own, oldKind)
	end
	worn[slot] = key
	return "ok", "Equipped"
end

-- in a fight now (CombatService.IsInCombat; false when it cannot tell)
local function fighting(player)
	local C = S.CombatService
	if type(C) ~= "table" or type(C.IsInCombat) ~= "function" then return false end
	local ok, yes = pcall(C.IsInCombat, player)
	return ok and yes == true
end

-- the checks both remotes share: the switch, a real ready living player; returns data, g or a reason
local function ready(player)
	if not on() then return nil, "off" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return nil, "state" end
	local data = getData(player)
	if not data or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return nil, "state" end
	return data, gearOf(data)
end

local function done(player, data, g, result, noteKey, petChanged)
	if result == "ok" then
		publishAttrs(player, g)
		sendInfo(player, g)
		if petChanged then refreshPet(player) end
		notify(player, noteKey, "info")
		if S.PlayerService.MarkActive then pcall(S.PlayerService.MarkActive, player) end
	elseif noteKey then
		sendInfo(player, g) -- the window may already show the change: the truth again
		notify(player, noteKey, "bad")
	end
	return result
end

function GearService.Equip(player, slot, key)
	local data, g = ready(player)
	if not data then return g end
	if type(slot) ~= "string" or Config.Gear.Slots[slot] == nil then return "slot" end
	if type(key) ~= "string" then return "key" end
	if fighting(player) then
		notify(player, "InCombat")
		return "combat"
	end
	local result, noteKey = move(g, data, slot, key, g.On)
	if result == "ok" then g.On[slot] = g.On[slot] or "" end -- On always has both slots ("" = empty)
	return done(player, data, g, result, noteKey, false)
end

function GearService.EquipPet(player, uid, slot, key)
	local data, g = ready(player)
	if not data then return g end
	if type(uid) ~= "string" or #uid < 1 or #uid > UID_LEN then return "pet" end
	if type(slot) ~= "string" or Config.Gear.PetSlots[slot] == nil then return "slot" end
	if type(key) ~= "string" then return "key" end
	local P = S.PetService
	if not (type(P) == "table" and type(P.GetPet) == "function" and P.GetPet(player, uid)) then return "pet" end
	if fighting(player) then
		notify(player, "InCombat")
		return "combat"
	end
	local row = type(g.Pet[uid]) == "table" and g.Pet[uid] or {}
	local result, noteKey = move(g, data, slot, key, row)
	if result == "ok" then
		if next(row) ~= nil then g.Pet[uid] = row else g.Pet[uid] = nil end -- a pet that wears nothing has no row
	end
	return done(player, data, g, result, noteKey, true)
end

------------------------------------------------------------------ join
-- gear of a pet that is not mine any more goes back to Own (room permitting; what does not fit stays where it is)
local function returnOrphans(player, data, g)
	local pets = data.Pets
	if type(pets) ~= "table" or type(pets.List) ~= "table" or not S.PetService or type(S.PetService.GetPet) ~= "function" then return end
	for uid, row in g.Pet do
		if type(uid) == "string" and type(row) == "table" and not S.PetService.GetPet(player, uid) then
			for slot, key in row do
				local kind = tostring(slot) .. ":" .. tostring(key)
				if roomFor(g.Own, kind) then
					addOwn(g.Own, kind)
					row[slot] = nil
				end
			end
			if next(row) == nil then g.Pet[uid] = nil end
		end
	end
end

local function onReady(player)
	if not on() then return end
	local data = getData(player)
	if not data then return end
	local g = gearOf(data)
	returnOrphans(player, data, g)
	publishAttrs(player, g)
	sendInfo(player, g)
end

------------------------------------------------------------------ remotes
local function onEquip(player, ...)
	if select("#", ...) ~= 2 then return end
	local slot, key = ...
	if type(slot) ~= "string" or #slot > 16 or type(key) ~= "string" or #key > 8 then return end
	if not Util.RateLimit(player, "EquipGear", num(Config.RateLimits.EquipGear, 0.5)) then return end
	GearService.Equip(player, slot, key)
end

local function onEquipPet(player, ...)
	if select("#", ...) ~= 3 then return end
	local uid, slot, key = ...
	if type(uid) ~= "string" or #uid > UID_LEN or type(slot) ~= "string" or #slot > 16 or type(key) ~= "string" or #key > 8 then return end
	if not Util.RateLimit(player, "EquipPetGear", num(Config.RateLimits.EquipGear, 0.5)) then return end
	GearService.EquipPet(player, uid, slot, key)
end

function GearService.Init(registry)
	S = registry
end

function GearService.Start()
	Net.Get("EquipGear").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onEquip, player, ...)
		if not ok then Util.Warn(TAG, "EquipGear: " .. tostring(err)) end
	end)
	Net.Get("EquipPetGear").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onEquipPet, player, ...)
		if not ok then Util.Warn(TAG, "EquipPetGear: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player)
		local ok, err = pcall(onReady, player)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	print("[GearService] started")
end

return GearService
