-- ShopService.luau : chosen basic weapons at the blacksmith and potions from their merchant.
-- UpgradeWeapon is the legacy purchase remote name; it does not enhance the current weapon.
-- CharacterVisuals rebuilds the weapon model from the WeaponTier attribute change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local M = {}

local S = nil
local BLACKSMITH = { PromptName = "HHC_BlacksmithPrompt", Distance = 12, PromptRate = 0.5 }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function notifyBad(player, key, ...)
	Net.Notify(player, string.format(Config.Text[key], ...), "bad")
end

local function onUpgradeWeapon(player, selectedTier)
	-- Client chooses only the catalog tier. Price, ownership and all eligibility stay on the server.
	if not finite(selectedTier) or selectedTier ~= math.floor(selectedTier) or selectedTier < 1
		or selectedTier > Config.MaxWeaponTier then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "UpgradeWeapon", Config.RateLimits.UpgradeWeapon) then return end
	-- Recheck the physical shop on EVERY purchase, even if its panel was opened earlier.
	if not M.CanBuyWeapon(player) then
		Net.Notify(player, Config.Text.WeaponShopFar, "bad")
		return
	end

	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end

	local maxTier = Config.MaxWeaponTier
	local tier = data.WeaponTier
	-- A23-34: 0 = bare hands (a new player buys the optional wood weapon before or after the free M1_1 tier 1)
	if not finite(tier) or tier ~= math.floor(tier) or tier < 0 or tier > maxTier then return end
	local shop = Config.WeaponShop
	local saleLimit = type(shop) == "table" and shop.MaxSoldTier or nil
	-- An absent/malformed sale list must never silently expose rare tiers for gold.
	if not finite(saleLimit) or saleLimit ~= math.floor(saleLimit) or saleLimit < 1 or saleLimit > maxTier then
		Util.Warn("ShopService", "invalid WeaponShop.MaxSoldTier; weapon purchase refused")
		return
	end
	if selectedTier > saleLimit then
		Net.Notify(player, Config.Text.WeaponNotSold, "info")
		return
	end
	local selectedDef = Config.Weapons[selectedTier]
	if type(selectedDef) ~= "table" then return end
	local ownedMask = data.WeaponOwnedMask
	local validMask = bit32.lshift(1, maxTier) - 1
	-- A23-34: no bit is required any more (0 = nothing owned; tier 1 is owned only after the M1_1 gift)
	if not finite(ownedMask) or ownedMask ~= math.floor(ownedMask) or ownedMask < 0
		or ownedMask > validMask then return end
	local selectedBit = bit32.lshift(1, selectedTier - 1)
	local alreadyOwned = bit32.band(ownedMask, selectedBit) ~= 0
	if selectedTier == 1 and not alreadyOwned then -- tier 1 is never sold: the M1_1 blacksmith gives it (A23-34)
		Net.Notify(player, Config.Text.WeaponFromQuest, "info")
		return
	end

	-- A23-28: MinLevel gates the purchase AND the equip, an owned weapon too (after a rebirth / Lv5+ free class change
	-- it is equippable again once the level is back; same rule as LootService.onEquipWeapon, Config.WeaponUsable)
	local level, minLevel = data.Level, selectedDef.MinLevel
	if not finite(level) or not finite(minLevel) then return end
	if level < minLevel then
		notifyBad(player, alreadyOwned and "EquipNeedLevel" or "WeaponNeedLevel", minLevel)
		return
	end

	-- the faction weapon needs a chosen faction (Halo, Horns or Neutral — never "None")
	local faction = S.FactionService.GetFaction(player)
	if type(faction) ~= "string" then faction = "None" end
	if selectedDef.RequiresFaction and faction == "None" then
		notifyBad(player, "NeedFaction")
		return
	end
	-- review B6: the same state rules as the item-list equip (LootService.onEquipWeapon): alive (CanBuyWeapon above)
	-- and not in PvP combat. Checked before any gold is spent; a purchase always equips, so it is refused too.
	if S.CombatService.IsInCombat(player) then
		Net.Notify(player, Config.Loot.Text.EquipCombat, "bad")
		return
	end

	if not alreadyOwned then
		local price = selectedDef.Price
		if not finite(price) or price <= 0 or price ~= math.floor(price) then
			Util.Warn("ShopService", "invalid weapon price; weapon purchase refused")
			return
		end
		-- No yields between debit, ownership and equipment: duplicate requests cannot debit twice.
		if not S.ProgressionService.SpendGold(player, price, "Weapon") then
			notifyBad(player, "NotEnoughGold")
			return
		end
		S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(ownedMask, selectedBit))
	end

	S.PlayerService.SetStat(player, "WeaponTier", selectedTier)
	S.PlayerService.SetStat(player, "BlacksmithVisited", true) -- A23-4: a verified anvil trade counts as the visit
	S.PlayerService.MarkActive(player)
	local weaponName = Config.WeaponName(selectedTier, S.ClassService.GetClass(player), faction)
	local equipFmt = (Config.Loot and Config.Loot.Text and Config.Loot.Text.Equip) or Config.Text.WeaponBought
	Net.Notify(player, string.format(alreadyOwned and equipFmt or Config.Text.WeaponBought, weaponName), alreadyOwned and "info" or "reward")
	if tier ~= selectedTier then Net.Fx(player, "Upgrade", { Tier = selectedTier }) end
end

local function onSellWeapon(player, selectedTier)
	if not finite(selectedTier) or selectedTier ~= math.floor(selectedTier) or selectedTier < 2
		or selectedTier > Config.MaxWeaponTier then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "SellWeapon", Config.RateLimits.SellWeapon or Config.RateLimits.UpgradeWeapon) then return end
	if not M.CanBuyWeapon(player) then
		Net.Notify(player, Config.Text.WeaponSellFar, "bad")
		return
	end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	local maxTier = Config.MaxWeaponTier
	local shop = Config.WeaponShop
	local saleLimit = type(shop) == "table" and shop.MaxSoldTier or nil
	if not finite(saleLimit) or saleLimit ~= math.floor(saleLimit) or saleLimit < 1 or saleLimit > maxTier then return end
	if selectedTier > saleLimit then return end
	local tier, ownedMask = data.WeaponTier, data.WeaponOwnedMask
	if not finite(tier) or tier ~= math.floor(tier) or tier < 0 or tier > maxTier then return end -- A23-34: 0 = bare hands
	local validMask = bit32.lshift(1, maxTier) - 1
	if not finite(ownedMask) or ownedMask ~= math.floor(ownedMask) or ownedMask < 0
		or ownedMask > validMask then return end
	local selectedBit = bit32.lshift(1, selectedTier - 1)
	if bit32.band(ownedMask, selectedBit) == 0 then return end
	local definition = Config.Weapons[selectedTier]
	local price = type(definition) == "table" and definition.Price or nil
	if not finite(price) or price <= 0 or price ~= math.floor(price) then return end
	local proceeds = math.floor(price * 0.1)
	-- Remove ownership before emitting any gold signal: a repeated or reentrant sale cannot pay twice.
	local leftMask = bit32.band(ownedMask, bit32.bnot(selectedBit))
	S.PlayerService.SetStat(player, "WeaponOwnedMask", leftMask)
	-- A23-34: selling the equipped weapon equips the best weapon still owned and usable (0 = bare hands), never an
	-- unowned tier 1
	if tier == selectedTier then S.PlayerService.SetStat(player, "WeaponTier", Config.BestUsableWeapon(leftMask, data.Level)) end
	S.ProgressionService.AddCarriedGold(player, proceeds, "Sale")
	S.PlayerService.SetStat(player, "BlacksmithVisited", true)
	S.PlayerService.MarkActive(player)
	local weaponName = Config.WeaponName(selectedTier, S.ClassService.GetClass(player), S.FactionService.GetFaction(player))
	Net.Notify(player, string.format(Config.Text.WeaponSold, weaponName, tostring(proceeds)), "good")
end

local function finitePosition(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function blacksmithAnvil()
	local map = workspace:FindFirstChild("Map")
	if not map or map.Parent ~= workspace or (not map:IsA("Folder") and not map:IsA("Model")) then return nil end
	local landmarks = map:FindFirstChild("Landmarks")
	if not landmarks or not landmarks:IsA("Folder") or landmarks.Parent ~= map then return nil end
	local guild = landmarks:FindFirstChild("ArtisanGuild")
	if not guild or not guild:IsA("Model") or guild.Parent ~= landmarks then return nil end
	local anvil = guild:FindFirstChild("Anvil")
	if not anvil or not anvil:IsA("BasePart") or anvil.Parent ~= guild or not anvil.Anchored then return nil end
	return anvil
end

-- Attach the interaction to the existing approved map prop; create no new NPC or scenery.
function M.EnsureBlacksmithPrompt()
	local anvil = blacksmithAnvil()
	if not anvil then return false end
	local prompt = anvil:FindFirstChild(BLACKSMITH.PromptName)
	if prompt and not prompt:IsA("ProximityPrompt") then return false end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = BLACKSMITH.PromptName
	end
	prompt.ActionText, prompt.ObjectText = Config.Text.BlacksmithPromptAction, Config.Text.BlacksmithPromptObject
	prompt.KeyboardKeyCode = Enum.KeyCode.E -- standard interact key; the skill is Q only (2026-10-06 playtest)
	prompt.HoldDuration, prompt.MaxActivationDistance = 0, BLACKSMITH.Distance -- a shop opens on a tap, no hold
	prompt.RequiresLineOfSight, prompt.Enabled = false, true
	prompt.Parent = anvil
	return true
end

local function blacksmith()
	local anvil = blacksmithAnvil()
	if not anvil then return nil end
	local prompt = anvil:FindFirstChild(BLACKSMITH.PromptName)
	if not prompt or not prompt:IsA("ProximityPrompt") or prompt.Parent ~= anvil or not prompt.Enabled then return nil end
	return anvil, prompt
end

function M.CanBuyWeapon(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return false end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" or data.ClassChosen ~= true then return false end
	local anvil, prompt = blacksmith()
	local root = Util.GetRoot(player)
	if not anvil or not root or not root:IsA("BasePart")
		or not finitePosition(anvil.Position) or not finitePosition(root.Position) then return false end
	local activation = prompt.MaxActivationDistance
	if not finite(activation) or activation <= 0 then return false end
	-- Increasing a prompt's radius never expands the purchase radius beyond the server contract.
	local distance = (root.Position - anvil.Position).Magnitude
	return finite(distance) and distance <= math.min(BLACKSMITH.Distance, activation)
end

local function onBlacksmithPrompt(prompt, player)
	if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt")
		or prompt.Name ~= BLACKSMITH.PromptName or not M.CanBuyWeapon(player) then return end
	local _, expected = blacksmith()
	if expected ~= prompt then return end -- cloned/renamed prompts cannot open the weapon shop
	if not Util.RateLimit(player, "BlacksmithPrompt", BLACKSMITH.PromptRate) then return end
	S.PlayerService.SetStat(player, "BlacksmithVisited", true)
	-- A23-34: an active M1_1 finishes right here, so its free first weapon is in hand before the shop opens
	local story = S.StoryQuestService
	if type(story) == "table" and type(story.Refresh) == "function" then pcall(story.Refresh, player) end
	Net.Get("OpenPanel"):FireClient(player, "WeaponShop")
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
		Net.Notify(player, Config.Text.PotionShopFar, "bad")
		return false, "MerchantDistance"
	end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return false, "NotReady" end
	local count, cap = data[key], Config.Vitals.PotionInventoryCap
	if not finite(count) or count < 0 or count ~= math.floor(count) or count > cap then return false, "InvalidStock" end
	if count + amount > cap then
		Net.Notify(player, string.format(Config.Text.PotionStockFull, cap), "bad")
		return false, "FullStock"
	end
	local price = Config.Vitals.PotionPrices[kind]
	if not finite(price) or price <= 0 or price ~= math.floor(price) then return false, "InvalidPrice" end
	-- Validate the whole purchase before debiting. SpendGold and SetStat do not yield; no request can interleave here.
	-- No datastore write, prompt callback, Notify or remote call occurs between these two mutations.
	if not S.ProgressionService.SpendGold(player, price * amount, "Potion") then
		notifyBad(player, "NotEnoughGold")
		return false, "NotEnoughGold"
	end
	S.PlayerService.SetStat(player, key, count + amount)
	S.PlayerService.MarkActive(player)
	Net.Notify(player, string.format(Config.Text.PotionBought, kind, amount), "good")
	return true, "Bought"
end

function M.Init(registry)
	S = registry
end

function M.Start()
	if not M.EnsureBlacksmithPrompt() then
		-- Minimal/headless maps may intentionally omit this optional town prop.
		print("[ShopService] no ArtisanGuild.Anvil; weapon shop stays closed")
	end
	-- Global, exact-instance validation survives a MapBuilder rebuild and rejects cloned/renamed prompts.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local ok, err = pcall(onPotionPrompt, prompt, player)
		if not ok then Util.Warn("ShopService", "potion prompt: " .. tostring(err)) end
		local shopOk, shopErr = pcall(onBlacksmithPrompt, prompt, player)
		if not shopOk then Util.Warn("ShopService", "blacksmith prompt: " .. tostring(shopErr)) end
	end)
	Net.Get("UpgradeWeapon").OnServerEvent:Connect(function(player, ...)
		-- Exactly one catalog tier is accepted; prices, quantities or extra payloads are rejected.
		if select("#", ...) ~= 1 then return end
		local ok, err = pcall(onUpgradeWeapon, player, ...)
		if not ok then Util.Warn("ShopService", "weapon purchase: " .. tostring(err)) end
	end)
	Net.Get("SellWeapon").OnServerEvent:Connect(function(player, ...)
		if select("#", ...) ~= 1 then return end
		local ok, err = pcall(onSellWeapon, player, ...)
		if not ok then Util.Warn("ShopService", "weapon sale: " .. tostring(err)) end
	end)
	Net.Get("BuyPotion").OnServerEvent:Connect(function(player, kind, amount)
		local ok, err = pcall(M.BuyPotion, player, kind, amount)
		if not ok then Util.Warn("ShopService", tostring(err)) end
	end)
	print("[ShopService] started")
end

return M
