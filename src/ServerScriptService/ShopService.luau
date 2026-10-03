-- ShopService.luau : weapon upgrades and server-priced potion stock from the physical merchant.
-- CharacterVisuals rebuilds the weapon model from the WeaponTier attribute change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

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

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function finitePosition(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

function M.CanBuyPotions(player)
	if Config.Vitals.MerchantEnabled ~= true or typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if player.Parent ~= Players or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return false end
	local map = workspace:FindFirstChild("Map")
	if not map or map.Parent ~= workspace or (not map:IsA("Folder") and not map:IsA("Model")) then return false end
	local npcs = map:FindFirstChild("NPCs")
	if not npcs or not npcs:IsA("Folder") or npcs.Parent ~= map then return false end
	local merchant = npcs:FindFirstChild(Config.Vitals.PotionMerchantName)
	local part = merchant and merchant:IsA("Model") and merchant:GetAttribute("HHC_PotionMerchant") == true and merchant.PrimaryPart
	local root = Util.GetRoot(player)
	if not merchant or merchant.Parent ~= npcs or not part or not part:IsA("BasePart")
		or not part:IsDescendantOf(merchant) or not root or not root:IsA("BasePart")
		or not finitePosition(part.Position) or not finitePosition(root.Position) then return false end
	local prompt = part:FindFirstChild(Config.Vitals.PotionMerchantPrompt)
	-- Direct BuyPotion calls require the same live server prompt as opening the shop, including its enabled state.
	if not prompt or not prompt:IsA("ProximityPrompt") or prompt.Parent ~= part or not prompt.Enabled then return false end
	local limit = Config.Vitals.PotionMerchantDistance
	if not finite(limit) or limit <= 0 then return false end
	local distance = (root.Position - part.Position).Magnitude
	return finite(distance) and distance <= limit
end

local function onPotionPrompt(prompt, player)
	if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return end
	if prompt.Name ~= Config.Vitals.PotionMerchantPrompt or not M.CanBuyPotions(player) then return end
	local map = workspace:FindFirstChild("Map")
	local npcs = map and map:FindFirstChild("NPCs")
	local merchant = npcs and npcs:FindFirstChild(Config.Vitals.PotionMerchantName)
	local part = merchant and merchant.PrimaryPart
	if not part or prompt.Parent ~= part or part:FindFirstChild(Config.Vitals.PotionMerchantPrompt) ~= prompt then return end
	if not Util.RateLimit(player, "PotionMerchantPrompt", Config.Vitals.PotionMerchantPromptRate) then return end
	Net.Get("OpenPanel"):FireClient(player, "PotionShop")
end

function M.BuyPotion(player, kind, amount)
	local key = Config.PotionStockKey(kind)
	if not key or type(amount) ~= "number" or (amount ~= 1 and amount ~= 5) then return false, "Invalid" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return false, "NotReady" end
	if not Util.RateLimit(player, "BuyPotion", Config.RateLimits.BuyPotion) then return false, "Cooldown" end
	if not M.CanBuyPotions(player) then
		Net.Notify(player, "물약 상인 가까이에서 구매해 주세요.", "bad")
		return false, "MerchantDistance"
	end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return false, "NotReady" end
	local count, cap = data[key], Config.Vitals.PotionInventoryCap
	if not finite(count) or count < 0 or count ~= math.floor(count) or count > cap then return false, "InvalidStock" end
	if count + amount > cap then
		Net.Notify(player, string.format("물약은 종류별 %d개까지 보관할 수 있어요.", cap), "bad")
		return false, "FullStock"
	end
	local price = Config.Vitals.PotionPrices[kind]
	if not finite(price) or price <= 0 or price ~= math.floor(price) then return false, "InvalidPrice" end
	-- Validate the whole purchase before debiting. SpendGold and SetStat do not yield; no request can interleave here.
	-- No datastore write, prompt callback, Notify or remote call occurs between these two mutations.
	if not S.ProgressionService.SpendGold(player, price * amount) then
		notifyBad(player, "NotEnoughGold")
		return false, "NotEnoughGold"
	end
	S.PlayerService.SetStat(player, key, count + amount)
	S.PlayerService.MarkActive(player)
	Net.Notify(player, string.format("%s 물약 %d개를 구매했어요!", kind, amount), "good")
	return true, "Bought"
end

function M.Init(registry)
	S = registry
end

function M.Start()
	-- Global, exact-instance validation survives a MapBuilder rebuild and rejects cloned/renamed prompts.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local ok, err = pcall(onPotionPrompt, prompt, player)
		if not ok then Util.Warn("ShopService", "potion prompt: " .. tostring(err)) end
	end)
	Net.Get("UpgradeWeapon").OnServerEvent:Connect(onUpgradeWeapon)
	Net.Get("BuyPotion").OnServerEvent:Connect(function(player, kind, amount)
		local ok, err = pcall(M.BuyPotion, player, kind, amount)
		if not ok then Util.Warn("ShopService", tostring(err)) end
	end)
	print("[ShopService] started")
end

return M
