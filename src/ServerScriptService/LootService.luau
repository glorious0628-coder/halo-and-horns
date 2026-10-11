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
	Level = {}, -- [Player] = the level last seen (A23-28: one "you can use it now" notice per MinLevel crossing)
	Watching = {}, -- [Player] = true once the PlayerReady attribute watchers (A23-32 '얻은 순') are connected
	SavedIdMaxLen = 64, -- B10: unknown saved item ids are kept only when they are sane strings
}

LootService.ItemsGranted = Util.Signal.new() -- (player, { { Id = itemId, N = n } ... })
LootService.Enhanced = Util.Signal.new() -- (player, tier, before, after, success, itemId) (itemId: BB10 장인 명성)

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function notify(player, text, kind, sound)
	if type(text) == "string" and text ~= "" then pcall(Net.Notify, player, text, kind or "info", nil, sound) end
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
	-- P7: monsters this player has defeated (LootFlags "Seen:<kind>") -> the item list shows only their drop tables
	local seen = {}
	if type(data.LootFlags) == "table" then
		for k, v in data.LootFlags do
			local kind = type(k) == "string" and string.match(k, "^Seen:(%w+)$")
			if kind and v == true and LOOT.Tables[kind] then seen[kind] = true end
		end
	end
	-- A23-32 bag '얻은 순': the order numbers (bigger = more recent; 0 = before this existed)
	local itemSeq, weaponSeq = {}, {}
	if type(data.ItemSeq) == "table" then
		for k, v in data.ItemSeq do
			if type(k) == "string" and (LOOT.Items[k] or Config.ItemSeqPotions[k]) and type(v) == "number" then itemSeq[k] = v end
		end
	end
	for tier = 1, Config.MaxWeaponTier do
		weaponSeq[tier] = type(data.WeaponSeq) == "table" and math.max(0, math.floor(num(data.WeaponSeq[tier]))) or 0
	end
	return { Items = items, Enhance = enh, Seen = seen, ItemSeq = itemSeq, WeaponSeq = weaponSeq }
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
		if def.Kind == "Material" and def.Source ~= nil then fmt = TXT.ItemFullKeep or fmt end -- not sold at the Forge
		fullNotice(player, id, string.format(fmt, def.Name, LOOT.ItemCap))
	end
	if given <= 0 then return 0 end
	data.Items[id] = have + given
	Config.NoteGained(data, id) -- A23-32 '얻은 순'
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
-- info = { Kind = monster kind, Golden = true?, Level = killer's level? } (RollKill passes the MonsterKilled info,
-- DebugSimulate a stand-in without Level). Draw order is fixed: one draw per row in table order, then one for the
-- jackpot when this kind has one. info.DropMult = the A23-22/23 penalty (rows AND the jackpot), info.RowBonus = the
-- A23-22 weekly top-3 reward (rows only, never the jackpot); a row's chance is cut at 1 after every multiplier.
-- A23-27: a weapon row with BelowLevel is not rolled below that weapon's MinLevel; it pays its BelowLevel item instead
-- (the king's T4 row: 3 candies).
local function rollRows(info, onHit)
	local mult = info.Golden == true and LOOT.GoldenMult or 1
	local rowMult = mult * num(info.DropMult, 1) -- A23-22 bully penalty (rows and the jackpot; not the first scroll)
	local rowBonus = num(info.RowBonus, 1) * num(info.AreaMult, 1) -- A23-90: the Crown Pit's better drops (rows only)
	for _, row in LOOT.Tables[info.Kind] or {} do
		-- ④ alchemy (BuffService): a Lucky Tonic raises a material row only (info.MatMult, set by RollKill)
		local def = row.Item and LOOT.Items[row.Item]
		local rowBonus = rowBonus * ((def and def.Kind == "Material") and num(info.MatMult, 1) or 1)
		if row.Weapon and type(row.BelowLevel) == "table" and info.Level ~= nil
			and not Config.WeaponUsable(row.Weapon, info.Level) then
			onHit(row.BelowLevel, false)
		elseif rng:NextNumber() < math.min(1, num(row.P) * rowMult * rowBonus) then
			onHit(row, false)
		end
	end
	local jackpot = LOOT.Jackpot
	-- A23-22 (review): the bully penalty halves the jackpot too (DropMult); the golden bonus applies as before
	if jackpot and jackpot.Monsters[info.Kind] and rng:NextNumber() < math.min(1, num(jackpot.Chance) * rowMult) then
		onHit({ Weapon = jackpot.Tier }, true)
	end
end

-- A23-15 server-wide chat line (AnnounceService); never blocks or breaks the grant itself
local function announce(player, key, args, tier)
	local svc = S.AnnounceService
	if type(svc) ~= "table" or type(svc.Announce) ~= "function" then return end
	local info = Config.WeaponInfo and Config.WeaponInfo[tier]
	pcall(svc.Announce, player, key, args, info and info.Grade or "Common")
end

-- the first time any of my weapons reaches +MaxEnhance (once per player, LootFlags.FirstMax)
local function firstMax(player, data, tier, after)
	if after < LOOT.MaxEnhance or data.LootFlags.FirstMax == true then return end
	data.LootFlags.FirstMax = true
	announce(player, "FirstMax", { Weapon = tier }, tier)
end

local function formatNumber(n)
	return Util.FormatNumber and Util.FormatNumber(n) or tostring(n)
end

-- A23-34: a bare-handed player (WeaponTier 0) equips a weapon the moment they get one (the M1_1 gift, a lucky drop)
-- when the level allows it (A23-28). Returns the power before and after, or nil (already armed / level too low).
-- No alive / PvP check: only ever from bare hands to a weapon, and only from the server.
local function equipIfBare(player, data, tier)
	local level = math.floor(num(data.Level, 1))
	if math.floor(num(data.WeaponTier, 0)) ~= 0 or not Config.WeaponUsable(tier, level) then return nil end
	S.PlayerService.SetStat(player, "WeaponTier", tier) -- CharacterVisuals builds the model; WeaponEnhance follows
	publish(player, data)
	pcall(Net.Fx, player, "Upgrade", { Tier = tier })
	-- A23-69: Config.CombatPowerOf with only the weapon swapped (the level and the stat points are the player's)
	return Config.CombatPowerOf(player, 0, 0), Config.CombatPowerOf(player, tier, enhanceOf(data, tier))
end

local function grantWeapon(player, data, tier, gained, isJackpot, kind)
	if not validTier(tier) then return end
	if owns(data, tier) then
		local gold = LOOT.DuplicateWeaponGold[tier] or 0
		if gold > 0 then
			gold = S.ProgressionService.AddCarriedGold(player, gold, "Loot") or gold -- A23-75: as added (2x Gold)
			notify(player, string.format(TXT.DuplicateWeapon, weaponName(player, tier), Util.FormatNumber and Util.FormatNumber(gold) or tostring(gold)), "reward", "GoldPickup")
		end
		return
	end
	-- ownership is saved before any announcement, so a repeated signal cannot give it twice
	S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(math.floor(num(data.WeaponOwnedMask, 0)), bit32.lshift(1, tier - 1)))
	local name = weaponName(player, tier)
	table.insert(gained, { Weapon = tier, Name = name })
	-- A23-34: found while still bare-handed (e.g. the slime jackpot before the first weapon) -> equipped at once, and
	-- the line says so (never "equip it in the menu" for a weapon already in hand)
	local before, after = equipIfBare(player, data, tier)
	if isJackpot then
		-- sound_gaps C1: equipped from bare hands = the HUD's power-up moment sounds it (None), else Equip
		notify(player, before and string.format(TXT.JackpotEquip, name, formatNumber(before), formatNumber(after))
			or string.format(TXT.JackpotSelf, name), "reward", before and "None" or "Equip")
		announce(player, "Jackpot", { Weapon = tier }, tier) -- everyone sees it in chat (A23-15)
	else
		notify(player, string.format(TXT.RareWeapon, Config.WeaponGrade(tier).Name, name), "reward", before and "None" or "Equip")
		local g = Config.WeaponGrade(tier)
		if g.Rank >= ((Config.Announce and Config.Announce.MinWeaponGrade) or 3) then
			announce(player, "RareWeapon", { Weapon = tier, Monster = kind }, tier)
		end
		if before then notify(player, string.format(TXT.BareEquip, name, formatNumber(before), formatNumber(after)), "reward", "None") end
	end
end

-- A23-34: the M1_1 blacksmith gift (StoryQuestService, Config.StoryQuests.Defs.M1_1.GiveWeapon) = the class basic
-- weapon. Paid once: tier 1 is never sold, so owning it is the record (a save from before A23-34 owns it already and
-- gets nothing, no notice). Bare-handed: equipped at once with "전투력 X → Y"; a player who bought a weapon first gets
-- it in the bag. Returns the tier given, or nil.
function LootService.GrantFirstWeapon(player, tier)
	tier = tier or 1
	local data = getData(player)
	if not data or not validTier(tier) or owns(data, tier) then return nil end
	ensureTables(data)
	S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(math.floor(num(data.WeaponOwnedMask, 0)), bit32.lshift(1, tier - 1)))
	-- A23-32 '얻은 순': paid at a join (StoryQuestService's PlayerReady runs before ours), the mask watcher is not there yet
	if not STATE.Watching[player] then Config.NoteGained(data, nil, tier) end
	local name = weaponName(player, tier)
	local before, after = equipIfBare(player, data, tier)
	if before then
		-- sound_gaps C1: the HUD's first-weapon moment plays PowerUp; no QuestDone on top
		notify(player, string.format(TXT.FirstWeapon, name, formatNumber(before), formatNumber(after)), "reward", "None")
	else
		publish(player, data)
		notify(player, string.format(TXT.FirstWeaponBag, name), "reward", "Equip")
	end
	return tier
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

-- E6 (story_depth 6-1) / A23-46: a quest reward of `n` (1..99) of one Config.Loot.Items id or potion kind ("HP" /
-- "MP"), through the same caps and full notices as drops. Returns how many were given (0 for a bad id / n or no data).
function LootService.GrantItem(player, id, n)
	local data = getData(player)
	n = math.floor(num(n))
	if not data or type(id) ~= "string" or n < 1 or n > 99 then return 0 end
	ensureTables(data)
	if Config.PotionStockKey(id) then
		local gained = {}
		for _ = 1, n do grantPotion(player, data, id, gained) end
		return #gained
	end
	if not LOOT.Items[id] then return 0 end
	local given = addItem(player, data, id, n)
	if given > 0 then publish(player, data) end
	return given
end

-- A23-79 (게임성 개발 3, the candy jar): take `n` (1..ItemCap) of one Config.Loot.Items id; false = not enough (nothing
-- taken). The bag push follows like after a drop.
function LootService.TakeItem(player, id, n)
	local data = getData(player)
	n = math.floor(num(n))
	if not data or type(id) ~= "string" or not LOOT.Items[id] or n < 1 or n > LOOT.ItemCap then return false end
	ensureTables(data)
	local have = math.floor(num(data.Items[id]))
	if have < n then return false end
	data.Items[id] = have > n and have - n or nil
	publish(player, data)
	return true
end

-- one roll for one contributor of one kill
function LootService.RollKill(player, info)
	local data = getData(player)
	if not data or type(info) ~= "table" or type(info.Kind) ~= "string" then return nil end
	if info.Minor == true then return nil end -- a free rider's share (MonsterService MinorShare): XP / gold only
	if info.Practice == true then return nil end -- A23-110: the retry King (a practice King): no boss drops (the quest pays)
	ensureTables(data)
	-- P7: the first kill of a kind reveals its drop table in the item list
	local seenKey = "Seen:" .. info.Kind
	if LOOT.Tables[info.Kind] and data.LootFlags[seenKey] ~= true then
		data.LootFlags[seenKey] = true
		publish(player, data)
	end
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
			-- A23-34: no weapon owned yet (the M1_1 gift comes later) -> the hint says where the first weapon comes from
			local line = math.floor(num(data.WeaponOwnedMask, 0)) == 0 and TXT.FirstScrollBare or TXT.FirstScroll
			pcall(Net.Notify, player, line, "reward", num(first.NoticeSeconds, 6), "None") -- the drop has its own sound
		end
	end

	info = table.clone(info) -- the caller's info stays untouched
	info.Level = math.floor(num(data.Level, 1)) -- A23-27 weapon rows with BelowLevel
	-- A23-22 / A23-23: drop rows x0.5 while a bully or this week's outlaw (once, both at once never x0.25); A23-22 / 24
	-- weekly top 3: rows x RewardMult while RankingService shows the reward (RankReward attribute: only in that faction)
	local pen = Config.Bully.Penalty
	local penal = type(pen) == "table" and (num(player:GetAttribute("BullyStacks")) >= 1 or player:GetAttribute("Outlaw") == true)
	local reward = player:GetAttribute("RankReward")
	local bonus = type(reward) == "string" and reward ~= "" and Config.Ranking ~= nil
	if penal then info.DropMult = num(pen.DropMult, 1) end
	if bonus then
		info.RowBonus = num(Config.Ranking.RewardMult, 1)
	end
	if S.BuffService then info.MatMult = S.BuffService.Mult(player, "MaterialDrop") end
	rollRows(info, function(row, isJackpot)
		if row.Item then
			giveItem(row.Item, math.max(1, math.floor(num(row.N, 1))))
		elseif row.Potion then
			grantPotion(player, data, row.Potion, gained)
		elseif row.Weapon then
			grantWeapon(player, data, row.Weapon, gained, isJackpot, info.Kind)
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

-- 게임성 개발 3 (gathering, docs/design/gather_server_2026-10-11.md): items from something other than a kill. list = { { Id
-- = a Config.Loot.Items id, N = 1..99 } }; the same caps / full notices as drops, then one Loot Fx (pos may be nil) and
-- ItemsGranted with the drop rows' shape. Returns the rows actually given ({} when nothing fit). `source` is for callers'
-- logs only (gathering gives no gold, so nothing here is doubled).
function LootService.GrantItems(player, list, pos, source)
	local data = getData(player)
	local gained = {}
	if not data or type(list) ~= "table" then return gained end
	ensureTables(data)
	local counts = {}
	for _, row in list do
		local id = type(row) == "table" and row.Id or nil
		local n = type(row) == "table" and math.floor(num(row.N)) or 0
		if type(id) == "string" and n >= 1 and n <= 99 then
			local given = addItem(player, data, id, n) -- 0 for an id missing from LOOT.Items
			if given > 0 then counts[id] = (counts[id] or 0) + given end
		end
	end
	for _, id in LOOT.Order do
		local n = counts[id]
		if n then
			table.insert(gained, { Item = id, Name = LOOT.Items[id].Name, N = n })
			counts[id] = nil
		end
	end
	for id, n in counts do -- an item missing from LOOT.Order still shows
		table.insert(gained, { Item = id, Name = LOOT.Items[id].Name, N = n })
	end
	if #gained > 0 then
		publish(player, data)
		pcall(Net.Fx, player, "Loot", { Pos = typeof(pos) == "Vector3" and pos or nil, Items = gained })
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
		firstMax(player, data, tier, after)
		notify(player, string.format(TXT.EnhanceOk, name, before, after,
			math.floor(Config.EnhanceMult(before) * 100 + 0.5), math.floor(Config.EnhanceMult(after) * 100 + 0.5)), "reward",
			"ScrollSuccess")
	elseif after < before then
		notify(player, string.format(TXT.EnhanceFailDown, name, before, after), "bad", "ScrollFail")
	else
		notify(player, string.format(TXT.EnhanceFailKeep, name, before), "info", "ScrollFail")
	end
	pcall(Net.Fx, player, "Enhance", { Item = id, Tier = tier, Before = before, After = after, Success = success })
	LootService.Enhanced:Fire(player, tier, before, after, success, id)
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
		firstMax(player, data, toTier, after) -- after both tiers are saved
		notify(player, string.format(TXT.MoveOk, fromName, data.WeaponEnhance[fromTier], toName, after), "reward", "ScrollSuccess")
	else
		notify(player, string.format(TXT.MoveFail, fromName, amount), "info", "ScrollFail")
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
	-- A23-28 (user 2026-10-06): equipping keeps MinLevel, an owned weapon too (ShopService matches). Owning and
	-- enhancing have no level limit; after a rebirth the weapon is equippable again once the level is back.
	if not Config.WeaponUsable(tier, num(data.Level, 1)) then
		notify(player, string.format(Config.Text.EquipNeedLevel, math.floor(num(def.MinLevel, 1))), "bad")
		return
	end
	if def.RequiresFaction and factionName(player) == "None" then
		notify(player, Config.Text.NeedFaction, "bad")
		return
	end
	-- B6: the same state rules as the blacksmith equip path (alive, not in PvP combat)
	if not Util.IsAlive(player) then notify(player, TXT.EquipDead, "bad"); return end
	if S.CombatService.IsInCombat(player) then notify(player, TXT.EquipCombat, "bad"); return end
	S.PlayerService.SetStat(player, "WeaponTier", tier) -- CharacterVisuals rebuilds the model; WeaponEnhance follows
	S.PlayerService.MarkActive(player)
	notify(player, string.format(TXT.Equip, weaponName(player, tier)), "info", "Equip")
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
		-- 게임성 검수 2026-10-11: the sell-all takes monster materials only; gathered / crafted ones (a Source, e.g.
		-- "Gather") stay for the artisans (sold one at a time later from the bag: SellItem)
		if def and def.Source ~= nil then def = nil end
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
	notify(player, Config.Plural(string.format(TXT.SellDone, count, tostring(gold))), "good")
end

------------------------------------------------------------------ A23-28 weapon level rule
-- the level went down (rebirth / Lv5+ free class change) or the save holds an equipped weapon above the level: equip
-- the best owned weapon usable now (ownership and +N untouched) and say so in one line
function LootService.FitWeaponToLevel(player, quiet)
	local data = getData(player)
	if not data then return end
	local level = math.floor(num(data.Level, 1))
	STATE.Level[player] = level
	local tier = math.floor(num(data.WeaponTier, 1))
	if not validTier(tier) or Config.WeaponUsable(tier, level) then return end
	local best = Config.BestUsableWeapon(data.WeaponOwnedMask, level)
	if best == 0 then
		-- A23-34: a weapon owner never goes back to bare hands (owns only weapons above this level, e.g. bought T3 and
		-- never got the M1_1 gift): the free class weapon, tier 1, is theirs now (a later M1_1 stays silent)
		S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(math.floor(num(data.WeaponOwnedMask, 0)), 1))
		best = 1
	end
	if best == tier then return end
	S.PlayerService.SetStat(player, "WeaponTier", best) -- CharacterVisuals rebuilds; WeaponEnhance follows (Start)
	if not quiet then
		notify(player, string.format(Config.Text.WeaponAutoSwap, math.floor(num(Config.Weapons[tier].MinLevel, 1)),
			weaponName(player, best)), "info")
	end
	publish(player, data)
end

-- a level-up crossed the MinLevel of an owned weapon stronger than the equipped one: say it once (never auto-equip)
local function onLeveledUp(player, level)
	local data = getData(player)
	if not data then return end
	level = math.floor(num(level, num(data.Level, 1)))
	local before = STATE.Level[player] or (level - 1)
	STATE.Level[player] = level
	if level <= before then return end
	local equipped = Config.Weapons[math.floor(num(data.WeaponTier, 0))]
	local bestDamage = equipped and num(equipped.Damage) or 0
	local mask = math.floor(num(data.WeaponOwnedMask, 0))
	local best = nil
	for t, def in Config.Weapons do
		local min = math.floor(num(def.MinLevel, 1))
		if t ~= 1 and bit32.band(mask, bit32.lshift(1, t - 1)) ~= 0 and min > before and min <= level
			and num(def.Damage) > bestDamage then
			best, bestDamage = t, num(def.Damage)
		end
	end
	if best and (Config.Nudges or {}).WeaponUsableNow ~= false then notify(player, string.format(Config.Text.WeaponUsableNow, weaponName(player, best)), "good") end
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
		LootService.FitWeaponToLevel(player) -- A23-28: a save from before the rule may hold a weapon above the level
		player:GetAttributeChangedSignal("WeaponTier"):Connect(function()
			local d = getData(player)
			if d then player:SetAttribute("WeaponEnhance", enhanceOf(d, math.floor(num(d.WeaponTier, 1)))) end
		end)
		-- A23-32 '얻은 순': potions and weapons reach the save from many services (shop, quests, story, drops); a rise of
		-- the mirrored stat is the one place every path passes, so it is noted here
		local seen = {}
		local function watch(attr, onChange)
			seen[attr] = math.floor(num(player:GetAttribute(attr)))
			player:GetAttributeChangedSignal(attr):Connect(function()
				local v = math.floor(num(player:GetAttribute(attr)))
				local was = seen[attr]
				seen[attr] = v
				local d = getData(player)
				if d and onChange(d, v, was) then publish(player, d) end
			end)
		end
		for key, attr in Config.ItemSeqPotions do
			watch(attr, function(d, v, was)
				if v <= was then return false end
				Config.NoteGained(d, key)
				return true
			end)
		end
		STATE.Watching[player] = true
		watch("WeaponOwnedMask", function(d, v, was)
			local any = false
			for tier = 1, Config.MaxWeaponTier do
				local bit = bit32.lshift(1, tier - 1)
				if bit32.btest(v, bit) and not bit32.btest(was, bit) then
					Config.NoteGained(d, nil, tier)
					any = true
				end
			end
			return any
		end)
		-- A23-34 safety net: a finished M1_1 always means the first weapon was handed over (a grant cut off by an error
		-- is paid at the next join; a save that owns it already stays silent)
		local story = data.Story
		if type(story) == "table" and type(story.Done) == "table" and story.Done.M1_1 == true then
			local ok, err = pcall(LootService.GrantFirstWeapon, player)
			if not ok then Util.Warn(TAG, "GrantFirstWeapon: " .. tostring(err)) end
		end
	end)
	-- safety net (same as the quest list): resend the inventory once per real spawn; the client keeps the last payload
	if S.PlayerService.CharacterSpawned then
		S.PlayerService.CharacterSpawned:Connect(function(player, _, _, cosmetic)
			if cosmetic == true or not S.PlayerService.IsReady(player) then return end
			local ok, err = pcall(publish, player)
			if not ok then Util.Warn(TAG, "Inventory resend: " .. tostring(err)) end
		end)
	end
	-- A23-28: the level went down -> fit the equipped weapon; a level-up past an owned weapon's MinLevel -> one notice
	local prog = S.ProgressionService
	for _, sig in { prog and prog.LevelReset, prog and prog.Rebirthed } do
		if type(sig) == "table" and type(sig.Connect) == "function" then
			sig:Connect(function(player)
				local ok, err = pcall(LootService.FitWeaponToLevel, player)
				if not ok then Util.Warn(TAG, "FitWeaponToLevel: " .. tostring(err)) end
			end)
		end
	end
	if prog and type(prog.LeveledUp) == "table" then
		prog.LeveledUp:Connect(function(player, level)
			local ok, err = pcall(onLeveledUp, player, level)
			if not ok then Util.Warn(TAG, "LeveledUp: " .. tostring(err)) end
		end)
	end
	S.PlayerService.PlayerLeaving:Connect(function(player)
		STATE.Pending[player] = nil
		STATE.FullAt[player] = nil
		STATE.Level[player] = nil
		STATE.Watching[player] = nil
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
	-- A23-34: mask 0 = a new bare-handed player (nothing owned); an unowned equipped tier -> the best usable owned one
	mask = math.floor(num(mask, 0))
	if mask < 0 or mask >= bit32.lshift(1, Config.MaxWeaponTier) then mask = 0 end
	S.PlayerService.SetStat(player, "WeaponOwnedMask", mask)
	if not owns(data, math.floor(num(data.WeaponTier, 0))) then
		S.PlayerService.SetStat(player, "WeaponTier", Config.BestUsableWeapon(mask, num(data.Level, 1)))
	end
	publish(player, data)
	return "ok"
end

return LootService
