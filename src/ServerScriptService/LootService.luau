-- LootService.luau : A23-11 / A23-12 monster drops, items, scroll enhancement and weapon equip from the item list.
-- Server-authoritative. Every kill contributor gets one own roll per kill (MonsterService fires MonsterKilled once
-- per contributor). Items go straight into the save: no ground pickup, never lost on death / looting / grudge sacks.
--   data.Items = { [itemId] = count }          (1..ItemCap; ids missing from Config.Loot.Items stay in the save but are
--                                               never shown or usable — review B10, so a renamed id is recoverable)
--   data.WeaponEnhance = { [tier] = 0..MaxEnhance }  (array by weapon tier; kept through rebirth)
--   data.LootFlags = { FirstScroll = true }
-- Client mirror (display only, review B11): the owner-only "Inventory" remote { Items, Enhance } and the numeric
-- WeaponEnhance attribute (+N of the EQUIPPED tier; CombatService / JusticeService / PvPService read it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LootService = {}
local S = nil
local TAG = "LootService"
local LOOT = Config.Loot
local TXT = LOOT.Text
local rng = Random.new()

-- per-player server state (cleared on PlayerLeaving)
local STATE = {
	Pending = {}, -- [Player] = true while one deferred Inventory push is queued (a burst of changes sends once)
	FullAt = {}, -- [Player] = { [itemId | "Potion:HP" | "Potion:MP"] = os.clock() of the last "가득 찼어요" notice }
	SavedIdMaxLen = 64, -- B10: unknown saved item ids are kept only when they are sane strings
}

LootService.ItemsGranted = Util.Signal.new() -- (player, { { Id = itemId, N = n } ... })
LootService.Enhanced = Util.Signal.new() -- (player, tier, before, after, success)

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function notify(player, text, kind)
	if type(text) == "string" and text ~= "" then pcall(Net.Notify, player, text, kind or "info") end
end

-- review B7: a full-stack notice at most once per key per player per Config.Loot.FullNoticeSeconds, always "info"
local function fullNotice(player, key, text)
	local seen = STATE.FullAt[player]
	if not seen then
		seen = {}
		STATE.FullAt[player] = seen
	end
	local now, last = os.clock(), seen[key]
	if last and now - last < num(LOOT.FullNoticeSeconds, 300) then return end
	seen[key] = now
	notify(player, text, "info")
end

local function className(player)
	local ok, c = pcall(S.ClassService.GetClass, player)
	return ok and c or "Warrior"
end

local function factionName(player)
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function weaponName(player, tier)
	return Config.WeaponName(tier, className(player), factionName(player))
end

local function validTier(tier)
	return type(tier) == "number" and tier == tier and tier == math.floor(tier) and tier >= 1 and tier <= Config.MaxWeaponTier
end

local function owns(data, tier)
	local mask = data.WeaponOwnedMask
	return validTier(tier) and type(mask) == "number" and mask == math.floor(mask) and mask >= 1
		and bit32.btest(mask, bit32.lshift(1, tier - 1))
end

------------------------------------------------------------------ data
local function sanitize(data)
	local items = {}
	if type(data.Items) == "table" then
		for id, n in data.Items do
			-- B10: unknown ids (an item renamed or removed by a later update) are preserved, not deleted; every reader
			-- below looks the id up in Config.Loot.Items first, so they are never shown, used or sold
			if type(id) == "string" and #id >= 1 and #id <= STATE.SavedIdMaxLen then
				local c = math.floor(num(n)) -- NaN / inf / non-numbers count as 0 and are dropped (never free items)
				if c > 0 then items[id] = math.min(c, LOOT.ItemCap) end
			end
		end
	end
	data.Items = items
	local enh = {}
	local old = type(data.WeaponEnhance) == "table" and data.WeaponEnhance or {}
	for tier = 1, Config.MaxWeaponTier do
		enh[tier] = math.clamp(math.floor(num(old[tier])), 0, LOOT.MaxEnhance)
	end
	data.WeaponEnhance = enh
	if type(data.LootFlags) ~= "table" then data.LootFlags = {} end
	for k, v in data.LootFlags do
		if type(k) ~= "string" or v ~= true then data.LootFlags[k] = nil end
	end
end

local function ensureTables(data)
	if type(data.Items) ~= "table" or type(data.WeaponEnhance) ~= "table" or type(data.LootFlags) ~= "table" then
		sanitize(data)
	end
end

local function enhanceOf(data, tier)
	local enh = data.WeaponEnhance
	return type(enh) == "table" and math.clamp(math.floor(num(enh[tier])), 0, LOOT.MaxEnhance) or 0
end

-- the SHARED CONTRACT payload: known item ids with count >= 1, and +N for every weapon tier (array 1..MaxWeaponTier)
local function inventoryPayload(data)
	local items = {}
	if type(data.Items) == "table" then
		for id, n in data.Items do
			if type(id) == "string" and LOOT.Items[id] then
				local c = math.floor(num(n))
				if c >= 1 then items[id] = math.clamp(c, 1, LOOT.ItemCap) end
			end
		end
	end
	local enh = {}
	for tier = 1, Config.MaxWeaponTier do
		enh[tier] = enhanceOf(data, tier)
	end
	return { Items = items, Enhance = enh }
end

local function pushInventory(player)
	STATE.Pending[player] = nil
	if typeof(player) ~= "Instance" or player.Parent ~= Players then return end -- left: never fire to a removed player
	local data = getData(player)
	if not data then return end
	Net.Get("Inventory"):FireClient(player, inventoryPayload(data))
end

-- mirror for the client (display only); the server always decides from data. The equipped +N attribute updates at
-- once; the owner-only Inventory push is deferred and coalesced (at most one per frame per player).
local function publish(player, data)
	data = data or getData(player)
	if not data then return end
	player:SetAttribute("WeaponEnhance", enhanceOf(data, math.floor(num(data.WeaponTier, 1))))
	if STATE.Pending[player] then return end
	STATE.Pending[player] = true
	task.defer(function()
		local ok, err = pcall(pushInventory, player)
		if not ok then
			STATE.Pending[player] = nil
			Util.Warn(TAG, "Inventory push: " .. tostring(err))
		end
	end)
end

local function addItem(player, data, id, n)
	local def = LOOT.Items[id]
	if not def or n <= 0 then return 0 end
	local have = math.floor(num(data.Items[id]))
	local room = math.max(0, LOOT.ItemCap - have)
	local given = math.clamp(n, 0, room)
	if given < n then
		-- full (or only part of a multi-count drop fits): say so instead of dropping the rest silently (throttled, B7);
		-- only materials can be sold at the anvil, scrolls are used from the item list
		local fmt = def.Kind == "Material" and TXT.ItemFull or TXT.ItemFullUse
		fullNotice(player, id, string.format(fmt, def.Name, LOOT.ItemCap))
	end
	if given <= 0 then return 0 end
	data.Items[id] = have + given
	return given
end

local function takeItem(data, id)
	local have = math.floor(num(data.Items[id]))
	if have < 1 then return false end
	data.Items[id] = have > 1 and have - 1 or nil
	return true
end

------------------------------------------------------------------ drops
-- one kill's drop rows (and the slime jackpot) with the server RNG; onHit(row, isJackpot) for every success.
-- info = { Kind = monster kind, Golden = true? } (RollKill passes the MonsterKilled info, DebugSimulate a stand-in).
-- Draw order is fixed: one draw per row in table order, then one for the jackpot when this kind has one.
local function rollRows(info, onHit)
	local mult = info.Golden == true and LOOT.GoldenMult or 1
	for _, row in LOOT.Tables[info.Kind] or {} do
		if rng:NextNumber() < math.min(1, num(row.P) * mult) then onHit(row, false) end
	end
	local jackpot = LOOT.Jackpot
	if jackpot and jackpot.Monsters[info.Kind] and rng:NextNumber() < math.min(1, num(jackpot.Chance) * mult) then
		onHit({ Weapon = jackpot.Tier }, true)
	end
end

local function grantWeapon(player, data, tier, gained, isJackpot)
	if not validTier(tier) then return end
	if owns(data, tier) then
		local gold = LOOT.DuplicateWeaponGold[tier] or 0
		if gold > 0 then
			S.ProgressionService.AddCarriedGold(player, gold, "Loot")
			notify(player, string.format(TXT.DuplicateWeapon, weaponName(player, tier), Util.FormatNumber and Util.FormatNumber(gold) or tostring(gold)), "reward")
		end
		return
	end
	-- ownership is saved before any announcement, so a repeated signal cannot give it twice
	S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(math.floor(num(data.WeaponOwnedMask, 1)), bit32.lshift(1, tier - 1)))
	local name = weaponName(player, tier)
	table.insert(gained, { Weapon = tier, Name = name })
	if isJackpot then
		notify(player, string.format(TXT.JackpotSelf, name), "reward")
		pcall(Net.NotifyAll, string.format(TXT.JackpotAll, Util.PlayerDisplayName(player), name), "announce", 8)
	else
		notify(player, string.format(TXT.RareWeapon, name), "reward")
	end
end

local function grantPotion(player, data, kind, gained)
	local key = Config.PotionStockKey(kind)
	if not key then return end
	local cap = Config.Vitals.PotionInventoryCap
	local have = math.floor(num(data[key]))
	if have >= cap then
		fullNotice(player, "Potion:" .. tostring(kind), string.format(TXT.PotionFull, TXT.Potion[kind] or kind))
		return
	end
	S.PlayerService.SetStat(player, key, have + 1)
	table.insert(gained, { Potion = kind, Name = TXT.Potion[kind] or kind, N = 1 })
end

-- one roll for one contributor of one kill
function LootService.RollKill(player, info)
	local data = getData(player)
	if not data or type(info) ~= "table" or type(info.Kind) ~= "string" then return nil end
	ensureTables(data)
	local gained = {}
	local itemCounts = {}
	local function giveItem(id, n)
		local given = addItem(player, data, id, n)
		if given > 0 then itemCounts[id] = (itemCounts[id] or 0) + given end
		return given
	end

	local first = LOOT.FirstScroll
	local firstNow = false
	if first and info.Kind == first.Monster and data.LootFlags.FirstScroll ~= true then
		-- B8: the flag is set only when the scroll really fits, so a full stack keeps the guarantee for a later kill.
		-- Grant and flag happen together with no yield in between: it is still paid at most once.
		if giveItem(first.Item, 1) > 0 then
			data.LootFlags.FirstScroll = true
			firstNow = true
			-- the one-time guide (A23-12). The Loot Fx below carries First = true so the client skips its own
			-- "where to use it" toast for this scroll (one toast, not two)
			pcall(Net.Notify, player, TXT.FirstScroll, "reward", num(first.NoticeSeconds, 6))
		end
	end

	rollRows(info, function(row, isJackpot)
		if row.Item then
			giveItem(row.Item, math.max(1, math.floor(num(row.N, 1))))
		elseif row.Potion then
			grantPotion(player, data, row.Potion, gained)
		elseif row.Weapon then
			grantWeapon(player, data, row.Weapon, gained, isJackpot)
		end
	end)

	for _, id in LOOT.Order do
		local n = itemCounts[id]
		if n then table.insert(gained, { Item = id, Name = LOOT.Items[id].Name, N = n }) end
	end
	if #gained > 0 then
		publish(player, data)
		local pos = typeof(info.Position) == "Vector3" and info.Position or nil
		pcall(Net.Fx, player, "Loot", { Pos = pos, Items = gained, First = firstNow or nil })
		LootService.ItemsGranted:Fire(player, gained)
	end
	return gained
end

------------------------------------------------------------------ remotes
local function ready(player, key)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
		and S.PlayerService.IsReady(player) and Util.RateLimit(player, key, Config.RateLimits[key] or 0.5)
end

local function useEnhance(player, data, id, def, tier)
	if not owns(data, tier) then notify(player, TXT.NotOwned, "bad"); return end
	local before = enhanceOf(data, tier)
	if before >= LOOT.MaxEnhance then notify(player, string.format(TXT.EnhanceMax, LOOT.MaxEnhance), "bad"); return end
	if not takeItem(data, id) then notify(player, TXT.NoItem, "bad"); return end
	local name = weaponName(player, tier)
	local success = rng:NextNumber() < def.Chance
	local after = before
	if success then
		after = math.min(LOOT.MaxEnhance, before + def.Plus)
	elseif before > 0 and rng:NextNumber() < LOOT.FailDropChance then
		after = before - 1
	end
	data.WeaponEnhance[tier] = after
	publish(player, data)
	if success then
		notify(player, string.format(TXT.EnhanceOk, name, before, after,
			math.floor(Config.EnhanceMult(before) * 100 + 0.5), math.floor(Config.EnhanceMult(after) * 100 + 0.5)), "reward")
	elseif after < before then
		notify(player, string.format(TXT.EnhanceFailDown, name, before, after), "bad")
	else
		notify(player, string.format(TXT.EnhanceFailKeep, name, before), "info")
	end
	pcall(Net.Fx, player, "Enhance", { Item = id, Tier = tier, Before = before, After = after, Success = success })
	LootService.Enhanced:Fire(player, tier, before, after, success)
end

local function useTransfer(player, data, id, def, fromTier, toTier)
	if not owns(data, fromTier) or not owns(data, toTier) then notify(player, TXT.NotOwned, "bad"); return end
	if fromTier == toTier then notify(player, TXT.MoveSame, "bad"); return end
	local amount = enhanceOf(data, fromTier)
	if amount <= 0 then notify(player, TXT.MoveNothing, "bad"); return end
	local target = enhanceOf(data, toTier)
	if target >= LOOT.MaxEnhance then notify(player, string.format(TXT.EnhanceMax, LOOT.MaxEnhance), "bad"); return end
	if not takeItem(data, id) then notify(player, TXT.NoItem, "bad"); return end
	local success = rng:NextNumber() < def.Chance
	local fromName, toName = weaponName(player, fromTier), weaponName(player, toTier)
	local after = target
	if success then
		-- "전부 옮김" (user 2026-10-05) without any loss: the source's +N is ADDED to the target's +M up to MaxEnhance;
		-- only what does not fit stays on the source (no enhancement ever disappears)
		after = math.min(LOOT.MaxEnhance, target + amount)
		data.WeaponEnhance[toTier] = after
		data.WeaponEnhance[fromTier] = amount - (after - target)
		notify(player, string.format(TXT.MoveOk, fromName, data.WeaponEnhance[fromTier], toName, after), "reward")
	else
		notify(player, string.format(TXT.MoveFail, fromName, amount), "info")
	end
	publish(player, data)
	pcall(Net.Fx, player, "Enhance", { Item = id, Tier = toTier, From = fromTier, Before = target, After = after, Success = success, Move = true })
end

-- (itemId, tier) for an enhance scroll, (itemId, fromTier, toTier) for a transfer scroll; nothing else is accepted
local function onUseItem(player, id, a, b, ...)
	if select("#", ...) ~= 0 or type(id) ~= "string" or not ready(player, "UseItem") then return end
	local def = LOOT.Items[id] -- unknown (B10) and material ids are never usable
	if not def then return end
	if def.Kind == "Enhance" then
		if not validTier(a) or b ~= nil then return end
	elseif def.Kind == "Transfer" then
		if not validTier(a) or not validTier(b) then return end
	else
		return
	end
	-- B6: no scroll during PvP combat (it would change the WeaponEnhance the PvP ratio reads mid-fight)
	if S.CombatService.IsInCombat(player) then notify(player, TXT.UseCombat, "bad"); return end
	local data = getData(player)
	if not data then return end
	ensureTables(data)
	if def.Kind == "Enhance" then
		useEnhance(player, data, id, def, a)
	else
		useTransfer(player, data, id, def, a, b)
	end
	S.PlayerService.MarkActive(player)
end

local function onEquipWeapon(player, tier, ...)
	if select("#", ...) ~= 0 or not validTier(tier) or not ready(player, "EquipWeapon") then return end
	local data = getData(player)
	if not data or data.ClassChosen ~= true then return end
	if not owns(data, tier) then notify(player, TXT.NotOwned, "bad"); return end
	if math.floor(num(data.WeaponTier, 1)) == tier then return end
	local def = Config.Weapons[tier]
	-- review (A23-4 / A23-14): MinLevel gates the PURCHASE only. An owned weapon is always re-equippable, so a reborn
	-- or free-class-changed Lv1 player who swaps away from a kept T5 can always swap back (ShopService matches).
	if def.RequiresFaction and factionName(player) == "None" then
		notify(player, Config.Text.NeedFaction, "bad")
		return
	end
	-- B6: the same state rules as the blacksmith equip path (alive, not in PvP combat)
	if not Util.IsAlive(player) then notify(player, TXT.EquipDead, "bad"); return end
	if S.CombatService.IsInCombat(player) then notify(player, TXT.EquipCombat, "bad"); return end
	S.PlayerService.SetStat(player, "WeaponTier", tier) -- CharacterVisuals rebuilds the model; WeaponEnhance follows
	S.PlayerService.MarkActive(player)
	notify(player, string.format(TXT.Equip, weaponName(player, tier)), "info")
	pcall(Net.Fx, player, "Upgrade", { Tier = tier })
end

local function onSellMaterials(player, ...)
	if select("#", ...) ~= 0 or not ready(player, "SellMaterials") then return end
	if not S.ShopService.CanBuyWeapon(player) then notify(player, TXT.SellFar, "bad"); return end
	local data = getData(player)
	if not data then return end
	ensureTables(data)
	local count, gold = 0, 0
	for id, n in data.Items do
		local def = LOOT.Items[id]
		if def and def.Kind == "Material" then
			local c = math.floor(num(n))
			count += c
			gold += c * def.Sell
			data.Items[id] = nil -- removed before paying: a repeated request cannot pay twice
		end
	end
	if count <= 0 then notify(player, TXT.SellNothing, "info"); return end
	publish(player, data)
	S.ProgressionService.AddCarriedGold(player, gold, "Sale")
	S.PlayerService.SetStat(player, "BlacksmithVisited", true)
	S.PlayerService.MarkActive(player)
	notify(player, string.format(TXT.SellDone, count, tostring(gold)), "good")
end

------------------------------------------------------------------ lifecycle
function LootService.Init(registry)
	S = registry
end

function LootService.Start()
	Net.Get("UseItem").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onUseItem, player, ...)
		if not ok then Util.Warn(TAG, "UseItem: " .. tostring(err)) end
	end)
	Net.Get("EquipWeapon").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onEquipWeapon, player, ...)
		if not ok then Util.Warn(TAG, "EquipWeapon: " .. tostring(err)) end
	end)
	Net.Get("SellMaterials").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onSellMaterials, player, ...)
		if not ok then Util.Warn(TAG, "SellMaterials: " .. tostring(err)) end
	end)
	S.MonsterService.MonsterKilled:Connect(function(player, info)
		local ok, err = pcall(LootService.RollKill, player, info)
		if not ok then Util.Warn(TAG, "RollKill: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		data = type(data) == "table" and data or getData(player)
		if not data then return end
		sanitize(data)
		publish(player, data)
		player:GetAttributeChangedSignal("WeaponTier"):Connect(function()
			local d = getData(player)
			if d then player:SetAttribute("WeaponEnhance", enhanceOf(d, math.floor(num(d.WeaponTier, 1)))) end
		end)
	end)
	-- safety net (same as the quest list): resend the inventory once per real spawn; the client keeps the last payload
	if S.PlayerService.CharacterSpawned then
		S.PlayerService.CharacterSpawned:Connect(function(player, _, _, cosmetic)
			if cosmetic == true or not S.PlayerService.IsReady(player) then return end
			local ok, err = pcall(publish, player)
			if not ok then Util.Warn(TAG, "Inventory resend: " .. tostring(err)) end
		end)
	end
	S.PlayerService.PlayerLeaving:Connect(function(player)
		STATE.Pending[player] = nil
		STATE.FullAt[player] = nil
	end)
	print("[LootService] started")
end

-- re-mirror the owner's items / per-tier +N (Inventory remote) and the equipped WeaponEnhance attribute; for other
-- services after they change WeaponTier / ownership in a way the client should see at once (no data is changed)
function LootService.Refresh(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	publish(player)
end

-- Studio test aid (DebugCommand "Item"): add n of an item id
function LootService.DebugGive(player, id, n)
	local data = getData(player)
	if not data or not LOOT.Items[id] then return 0 end
	ensureTables(data)
	local given = addItem(player, data, id, math.floor(num(n, 1)))
	publish(player, data)
	return given
end

-- Studio test aid (DebugCommand "LootRoll", review B12): COUNT-ONLY. Rolls n kills of this monster kind with the real
-- drop tables and RNG but grants nothing, saves nothing and sends no Fx / notice (no first-scroll guarantee, caps or
-- duplicate-weapon gold either). Returns { Kills = n, [itemId | "HP" | "MP" | "Weapon<tier>"] = count } or nil.
function LootService.DebugSimulate(kind, n, golden)
	if type(kind) ~= "string" or type(LOOT.Tables[kind]) ~= "table" then return nil end
	local kills = math.clamp(math.floor(num(n, 1)), 1, 100000)
	local tally = { Kills = kills }
	local info = { Kind = kind, Golden = golden == true }
	for _ = 1, kills do
		rollRows(info, function(row)
			local key = row.Item or row.Potion or ("Weapon" .. tostring(row.Weapon))
			local count = row.Item and math.max(1, math.floor(num(row.N, 1))) or 1
			tally[key] = (tally[key] or 0) + count
		end)
	end
	return tally
end

-- Studio test aid (DebugCommand "LootReset"): undo test drops on the test account (items, +N, flags, weapons)
function LootService.DebugReset(player, mask)
	local data = getData(player)
	if not data then return "no data" end
	data.Items, data.WeaponEnhance, data.LootFlags = {}, {}, {}
	sanitize(data)
	mask = math.floor(num(mask, 1))
	if mask < 1 or mask >= bit32.lshift(1, Config.MaxWeaponTier) then mask = 1 end
	mask = bit32.bor(mask, 1)
	S.PlayerService.SetStat(player, "WeaponOwnedMask", mask)
	if not owns(data, math.floor(num(data.WeaponTier, 1))) then S.PlayerService.SetStat(player, "WeaponTier", 1) end
	publish(player, data)
	return "ok"
end

return LootService
