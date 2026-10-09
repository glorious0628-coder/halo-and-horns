-- CommissionService.luau : A23-86 decision 2 - Otto's commissions: the golden / crystal / spirit weapons (T4-T6) can be
-- ordered at the Forge with gold + materials + level (게임성 개발 3, 2026-10-09; contract
-- docs/design/commission_server_2026-10-09.md, content_beyond_10min H). No mini game (the 11/25 artisan update takes it
-- over). The drops stay a lucky shortcut. Switched by Config.Features.Commission (off until the Forge window has its
-- [Commission] row). Nothing here is sold for Robux and no 2x or purchase button belongs near it (A23-79).
--   c->s "Commission"(tier: integer): at the Forge (ShopService.CanBuyWeapon), ready, alive, not in combat, 1 s. The server
--        checks everything first (tier in Config.Commission.Orders, the weapon not owned yet, Level >= the weapon's MinLevel,
--        every material, the gold) and then takes it all in one go (no yield between check and take): gold through
--        ProgressionService.SpendGold(…, "Commission"), the materials through LootService.TakeItem. The weapon is owned and
--        equipped like a bought one (WeaponOwnedMask bit, WeaponTier, BlacksmithVisited).
--   s->c Fx "Commission" { Tier, Name } to the owner (the client plays its 'power A -> B' show with the existing "Upgrade" fx).
--   A moment later the apprentice card (ChoiceCard kind Config.Commission.Card, a saved card) opens: same size, fixed reward.
--   CommissionService.NextGoal(player, data) -> the next-goal ladder line, "Commission<tier>" (QuestService, Config.Tutorial.Ladder hook).
--   Signal CommissionService.Made(player, tier).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CommissionService = {}
CommissionService.Made = Util.Signal.new() -- (player, tier)

local TAG = "CommissionService"
local S = nil
local K = Config.Commission or {}
local TXT = K.Text or {}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function notify(player, text, kind, sound)
	local ok, err = pcall(Net.Notify, player, text, kind, nil, sound)
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

local function orderOf(tier)
	local orders = K.Orders
	local o = type(orders) == "table" and orders[tier] or nil
	if type(o) ~= "table" or type(Config.Weapons[tier]) ~= "table" then return nil end
	return o
end

-- the ids of an order's materials in the order they are listed
local function materials(order)
	local list = {}
	for id, n in order.Items or {} do
		if Config.Loot.Items[id] then table.insert(list, { Id = id, N = math.max(1, math.floor(num(n, 1))) }) end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	return list
end

local function have(data, id)
	local items = type(data.Items) == "table" and data.Items or {}
	return math.max(0, math.floor(num(items[id])))
end

local function owned(data, tier)
	return bit32.btest(math.floor(num(data.WeaponOwnedMask)), bit32.lshift(1, tier - 1))
end

local function gold(data)
	return math.max(0, math.floor(num(data.CarriedGold))) + math.max(0, math.floor(num(data.BankGold)))
end

local function weaponName(player, tier)
	local class = "Warrior"
	local okC, c = pcall(S.ClassService.GetClass, player)
	if okC and type(c) == "string" then class = c end
	local faction = player:GetAttribute("Faction")
	return Config.WeaponName(tier, class, type(faction) == "string" and faction or "None")
end

------------------------------------------------------------------ the order
local function onCommission(player, ...)
	if select("#", ...) ~= 1 then return end
	local tier = ...
	if type(tier) ~= "number" then return end
	if not Config.FeatureOn("Commission") then return end
	local order = orderOf(tier)
	if not order then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "Commission", num(Config.RateLimits.Commission, 1)) then return end
	if not S.ShopService.CanBuyWeapon(player) then
		notify(player, Config.Text.WeaponShopFar, "bad")
		return
	end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	if owned(data, tier) then
		notify(player, TXT.Owned, "info")
		return
	end
	local def = Config.Weapons[tier]
	if num(data.Level, 1) < num(def.MinLevel, 1) then
		notify(player, string.format(TXT.NeedLevel, math.floor(num(def.MinLevel, 1))), "bad")
		return
	end
	if S.CombatService.IsInCombat(player) then
		notify(player, Config.Loot.Text.EquipCombat, "bad")
		return
	end
	local list = materials(order)
	for _, m in list do
		if have(data, m.Id) < m.N then
			notify(player, TXT.NeedMaterials, "bad")
			return
		end
	end
	local price = math.max(0, math.floor(num(order.Gold)))
	-- no yield from here: check -> take -> own cannot be split or repeated (SpendGold refuses a short purse before any
	-- material is touched)
	if not S.ProgressionService.SpendGold(player, price, "Commission") then
		notify(player, Config.Text.NotEnoughGold, "bad")
		return
	end
	for _, m in list do
		if not S.LootService.TakeItem(player, m.Id, m.N) then
			-- cannot happen after the check above; put back what was taken and the gold
			Util.Warn(TAG, "TakeItem failed after the check: " .. m.Id)
			if price > 0 then S.ProgressionService.AddBankGold(player, price, "Refund") end
			return
		end
	end
	local mask = math.floor(num(data.WeaponOwnedMask))
	S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(mask, bit32.lshift(1, tier - 1)))
	S.PlayerService.SetStat(player, "WeaponTier", tier)
	S.PlayerService.SetStat(player, "BlacksmithVisited", true)
	S.PlayerService.MarkActive(player)
	local name = weaponName(player, tier)
	notify(player, string.format(TXT.Done, name), "reward", "Equip")
	pcall(Net.Fx, player, "Upgrade", { Tier = tier })
	pcall(Net.Fx, player, "Commission", { Tier = tier, Name = name })
	local t = S.TelemetryService
	if type(t) == "table" and type(t.Custom) == "function" then pcall(t.Custom, player, "Commission", 1, "T" .. tier) end
	CommissionService.Made:Fire(player, tier)
	-- the apprentice card, a moment later (the equip line first)
	local card = K.Card
	if type(card) == "string" and S.ChoiceCard then
		task.delay(num(K.CardDelay, 1.5), function()
			if player.Parent == Players then pcall(S.ChoiceCard.Offer, player, card, { Tier = tier }) end
		end)
	end
end

------------------------------------------------------------------ the next-goal ladder line
-- the lowest order not owned yet that is worth showing (ShowLevel), as one line: the material that is furthest from done,
-- then the gold; a finished list says the weapon is ready at the Forge
function CommissionService.NextGoal(player, data)
	if not Config.FeatureOn("Commission") or type(data) ~= "table" then return nil end
	local tiers = {}
	for tier in K.Orders or {} do table.insert(tiers, tier) end
	table.sort(tiers)
	local level = math.max(1, math.floor(num(data.Level, 1)))
	for _, tier in tiers do
		local order = orderOf(tier)
		if order and not owned(data, tier) then
			if level < num(order.ShowLevel, num(Config.Weapons[tier].MinLevel, 1)) then return nil end
			local worst, worstFrac = nil, 2
			for _, m in materials(order) do
				local frac = math.min(1, have(data, m.Id) / m.N)
				if frac < 1 and frac < worstFrac then worst, worstFrac = m, frac end
			end
			local label = TXT.GoalLabel[tier] or "Commission"
			local price = math.max(0, math.floor(num(order.Gold)))
			local mine = gold(data)
			if worst then
				local item = Config.Loot.Items[worst.Id]
				return string.format(TXT.GoalMaterial, label, (item and item.Name) or worst.Id, have(data, worst.Id), worst.N,
					Util.FormatNumber(math.min(mine, price)), Util.FormatNumber(price)), "Commission" .. tier
			elseif mine < price then
				return string.format(TXT.GoalGold, label, Util.FormatNumber(mine), Util.FormatNumber(price)), "Commission" .. tier
			elseif level < num(Config.Weapons[tier].MinLevel, 1) then
				return string.format(TXT.GoalLevel, label, math.floor(num(Config.Weapons[tier].MinLevel, 1)), level), "Commission" .. tier
			end
			return string.format(TXT.GoalReady, label), "Commission" .. tier
		end
	end
	return nil
end

function CommissionService.Init(registry)
	S = registry
end

function CommissionService.Start()
	Net.Get("Commission").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onCommission, player, ...)
		if not ok then Util.Warn(TAG, "Commission: " .. tostring(err)) end
	end)
	print("[CommissionService] started")
end

return CommissionService
