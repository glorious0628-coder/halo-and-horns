-- ShopService.luau : the UpgradeWeapon remote (TECH_SPEC §4.19). Buys the next weapon tier for the player's class.
-- CharacterVisuals rebuilds the weapon model from the WeaponTier attribute change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local M = {}

local S = nil

local function notifyBad(player, key, ...)
	Net.Notify(player, string.format(Config.Text[key], ...), "bad")
end

local function onUpgradeWeapon(player)
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "UpgradeWeapon", Config.RateLimits.UpgradeWeapon) then return end

	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end

	local maxTier = Config.MaxWeaponTier
	local tier = math.clamp(math.floor(tonumber(data.WeaponTier) or 1), 1, maxTier)
	if tier >= maxTier then
		notifyBad(player, "WeaponMaxed")
		return
	end

	local nextTier = tier + 1
	local nextDef = Config.Weapons[nextTier]
	if type(nextDef) ~= "table" then
		notifyBad(player, "WeaponMaxed")
		return
	end

	local level = tonumber(data.Level) or 1
	local minLevel = tonumber(nextDef.MinLevel) or 1
	if level < minLevel then
		notifyBad(player, "WeaponNeedLevel", minLevel)
		return
	end

	-- the faction weapon needs a chosen faction (Halo, Horns or Neutral — never "None")
	local faction = S.FactionService.GetFaction(player)
	if type(faction) ~= "string" then faction = "None" end
	if nextDef.RequiresFaction and faction == "None" then
		notifyBad(player, "NeedFaction")
		return
	end

	if not S.ProgressionService.SpendGold(player, tonumber(nextDef.Price) or 0) then
		notifyBad(player, "NotEnoughGold")
		return
	end

	S.PlayerService.SetStat(player, "WeaponTier", nextTier)
	local weaponName = Config.WeaponName(nextTier, S.ClassService.GetClass(player), faction)
	Net.Notify(player, string.format(Config.Text.WeaponBought, weaponName), "reward")
	Net.Fx(player, "Upgrade", { Tier = nextTier })
end

function M.Init(registry)
	S = registry
end

function M.Start()
	Net.Get("UpgradeWeapon").OnServerEvent:Connect(onUpgradeWeapon)
	print("[ShopService] started")
end

return M
