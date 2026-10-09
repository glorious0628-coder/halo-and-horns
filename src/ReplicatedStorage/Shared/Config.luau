-- Config.luau : every tuning number, pure helper formula and player string (English only, A23-48) for Halo & Horns.
-- Shared by server and client. Pure data + pure functions only (no services, no instances).
local Config = {}

Config.Game = {
	Name = "Halo & Horns",
	MaxPlayers = 20, -- documentation only; set in Studio Game Settings
}

-- feature switches. A23-57 (user 2026-10-06): NeutralFaction = the artisan guild as a faction a player can newly pick;
-- off for the beta (the artisan update brings it back). Off: no new Neutral pick at the faction picker, the altar or a
-- rebirth (Config.Pickable), its own sub quests are not offered; saves that are Neutral already stay as they are.
-- Code and data stay; game dev 1's faction picker reads the switch for its cards.
-- Market = the trading market (RELEASE_PLAN: after the full launch). 검수 2026-10-07: no "coming soon" signs for things
-- the beta does not have (confusing for kids). Off: the world map shows no Market landmark. While NeutralFaction is off
-- the world map calls the Crossroads anvil spot "Forge" (the weapon shop) instead of "Artisan Guild".
-- StatPoints (A23-69, user 2026-10-07 "베타에 넣는다, 끌 수 있게"): the stat points (Config.Stats). Off = every number is
-- the same as without stats (Config.StatMults is 1, 1); the saved picks stay and count again once it is on.
Config.Features = { NeutralFaction = false, Market = false, StatPoints = false }

function Config.FeatureOn(name)
	return type(Config.Features) == "table" and Config.Features[name] == true
end

-- A23-63 (user 2026-10-07 "폰트 이쁜 걸로"): the game's two fonts, in one place. Head = titles, buttons, numbers and the
-- name on a name tag (Denk One, one weight); Body = body text and the other name-tag lines (Montserrat). The server-built
-- name tags (CharacterVisuals, UI round 2 #7) read Nametag; UIKit's FONT.Sets can read Head / Body from here too.
Config.Fonts = {
	Head = "rbxasset://fonts/families/DenkOne.json",
	Body = "rbxasset://fonts/families/Montserrat.json",
	Nametag = { Line1 = "Head", Line2 = "Body", Line3 = "Body", Ghost = "Body" },
}

-- 1 day / 2 days (검수 2026-10-07, 'You were away for 1 days'): string.format a count line, then Config.Plural(line)
-- turns "1 <plural>" into "1 <singular>" for the phrases below (only after a lone 1: not 11, 0.1, 1,000 or 1/3).
-- A new "%d <noun>s" text adds its phrase here (tools/test_story_text.py: plural-one / plural-word / plural-callsite).
Config.PluralWords = {
	days = "day", times = "time", minutes = "minute", seconds = "second", hits = "hit", ["basic hits"] = "basic hit",
	slimes = "slime", monsters = "monster", materials = "material", quests = "quest", players = "player",
	["Wanted players"] = "Wanted player", Knights = "Knight", ["more great items"] = "more great item",
}

function Config.Plural(text)
	if type(text) ~= "string" then return text end
	for many, one in Config.PluralWords do
		text = string.gsub(text, "%f[%d%.,]1 " .. (string.gsub(many, "%p", "%%%0")) .. "%f[^%w]", "1 " .. one)
	end
	return text
end

----------------------------------------------------------------- player / data
Config.Player = {
	WalkSpeed = 20,
	RespawnTime = 3,
	BaseMaxHealth = 100,
	MaxHealthPerLevel = 10,
	PlaytimeTick = 5, -- seconds between PlaytimeSeconds updates
	CollisionGroup = "Players", -- addendum A7-5: PhysicsService group, not collidable with itself (PlayerService)
	-- A23-81 (user 2026-10-08 "나무·풀을 뚫으면 안 되지, 비켜 가야지"): decor parts in this group block players only;
	-- monsters, pets and everything else (Default and every other group) pass through them (PlayerService registers it)
	DecorGroup = "DecorPlayerOnly",
}

-- Approved HP/MP HUD. Potions are now purchased stock; prices are provisional balance values.
Config.Vitals = {
	MaxMana = 100,
	ManaRegen = 4, -- per second; session state, not persisted
	MageSwingCost = 2, -- 2026-10-06 user: mage a bit stronger (was 3)
	ReleaseCost = 20,
	HPRecovery = 0.30,
	MPRecovery = 0.40,
	PotionCooldown = 10, -- HP and MP have independent server deadlines
	PotionPrices = { HP = 25, MP = 25 }, -- gold per bottle (user 2026-10-06)
	PotionInventoryCap = 99,
	PotionMerchantName = "PotionMerchant", -- server-owned workspace.Map.NPCs model; missing NPC rejects buying
	PotionMerchantLabel = "Fizzby", -- ⑪ the prompt's ObjectText (ActionText stays "Buy potions"); the model name stays
	PotionMerchantDistance = 12,
	MerchantEnabled = true, -- A23-6: shop screen works; price 25 confirmed by the user 2026-10-06
	-- A23-6: temporary default Roblox-style NPC (HumanoidDescription, no new art) until the Firefly redraw
	PotionMerchantColors = { Head = Color3.fromRGB(234, 184, 146), Torso = Color3.fromRGB(46, 120, 92), Legs = Color3.fromRGB(70, 55, 45) },
	PotionMerchantPrompt = "PotionShopPrompt",
	PotionMerchantPromptRate = 0.5,
	PotionMerchantOffset = { X = 12, Z = -9 }, -- beside the Crossroads spawn, off the north road/pads
}

function Config.PotionStockKey(kind)
	if kind == "HP" then return "HPPotionCount" end
	if kind == "MP" then return "MPPotionCount" end
	return nil
end

-- Additive save field: no free stock on first join or migration. Invalid/fractional values grant no bottles.
function Config.NormalizePotionCount(value)
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge
		or value ~= math.floor(value) then return 0 end
	return math.min(value, Config.Vitals.PotionInventoryCap)
end

Config.Nickname = {
	StoreName = "HaloHorns_Nicknames_v1", -- universe-wide claims; no Studio memory fallback (use Config.StoreName(StoreName))
	MinLength = 2, MaxLength = 20, MaxBytes = 80,
	ChangeInterval = 10,
	-- Claimed aliases stay with their owner. Never free a name after an uncertain cross-key response.
	RetainPreviousClaims = true,
}

Config.Data = {
	StoreName = "HaloHorns_Player_v1", -- unchanged on purpose: v1 saves are migrated in place by DataService
	KeyPrefix = "P_",
	-- B4: 3 = weapon tier 8 + Items / WeaponEnhance / LootFlags. A23-69 (검수 2026-10-07): Stats { Auto, Order } is an
	-- additive field like Settings / Rank / SkillsA71 (a v3 server keeps it as it is), so the version stays 3; a bump
	-- is decided with stage 2 (the switch on). An older server refuses a newer record (CR-L3).
	Version = 3,
	AutosaveInterval = 60,
	LockTimeout = 120, -- seconds; a lock older than this is considered dead
	-- A23-48 batch (검수 2026-10-06): a locked / failed load retries every 6 s, 5 tries (the last one takes the lock:
	-- dead-server recovery after ~24 s); the waiting player sees Config.Text.SaveLoading (attribute SaveLoading)
	LoadRetries = 5,
	LoadRetryDelay = 6,
	SaveRetries = 3,
	Defaults = {
		Version = 3,
		Level = 1,
		XP = 0,
		BankGold = 0,
		CarriedGold = 0,
		-- A23-34: a new player starts bare-handed (tier 0, nothing owned); the M1_1 blacksmith gives tier 1. Records
		-- saved before A23-34 keep their weapons (they always own tier 1). v1 name: SwordTier (migrated by DataService)
		WeaponTier = 0,
		WeaponOwnedMask = 0, -- tier N uses bit N-1; 0 = no weapon owned
		BlacksmithVisited = false,
		Faction = "None",
		Class = "Warrior",
		ClassChosen = false, -- false -> ClassPicker shows (first pick is free and keeps level)
		CharacterGender = "M",
		Nickname = "", -- filtered cache only; NicknameService's global directory is authoritative
		HPPotionCount = 0,
		MPPotionCount = 0,
		Rebirths = 0,
		RebirthBonus = 0, -- sum of per-rebirth bonuses (0.25 or 0.40 each); v1 data: Rebirths * 0.25
		FallMarks = 0, -- "타락" stacks (Halo -> Horns at rebirth), max Config.Rebirth.MarkMax
		RedeemMarks = 0, -- "구원" stacks (Horns -> Halo at rebirth), max Config.Rebirth.MarkMax
		Honor = 0, -- Halo rank points (kept while in Horns)
		Infamy = 0, -- Horns rank points (kept while in Halo)
		SwitchCount = 0,
		LastSwitchTime = 0, -- os.time() of the last ALTAR faction change
		PlaytimeSeconds = 0,
		TotalKills = 0,
		Quests = {},
		DailyDay = 0, -- Config.DayIndex of the day the current dailies were generated (0 = never)
		DailyClaims = 0, -- dailies claimed on DailyDay (0..3)
		DailyLevel = 0, -- level when DailyDay's dailies were generated (0 = unknown); caps the chest to that band
		VacationDays = 0, -- pending vacation reward (0 = nothing pending)
		VacationGold = 0,
		VacationXP = 0,
		CheerStars = 0, -- "응원별"
		Tickets = { Class = 0, Faction = 0 },
		ProcessedReceipts = {}, -- recent PurchaseId strings, oldest first, at most Config.Tickets.MaxReceiptsKept
		FirstJoinTime = 0,
		LastLogoutTime = 0,
		-- addendum A4 / A5-C5: onboarding step (0 = brand-new, 1 = guide, 2 = tutorial quest, 99 = done).
		-- DataService sets 99 for any STORED record lacking the field BEFORE this default fill.
		TutorialStep = 0,
		TutorialKills = 0, -- saved owner-only progress; quest remote supplies the HUD
		IntroSeen = false, -- A23-9: the first-time opening was watched or skipped (set only by the server)
		AutoCombatUnlocked = false, -- A23-1: set once by the crown-shard quest
		AutoCombatEnabled = false, -- A23-1: the player's saved ON/OFF (starts OFF, never auto-enabled)
		-- story quests (StoryQuestService): active main + subs, finished ids, choices, one-time firsts
		Story = { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = {} },
		-- A23-12 drops (LootService): item id -> count, scroll enhancement per weapon tier (array, kept through
		-- rebirth), one-time loot flags (e.g. FirstScroll = the guaranteed first Slime Prince scroll)
		Items = {},
		WeaponEnhance = {},
		LootFlags = {},
		HideAnnounceName = false, -- P5: server-wide chat announcements show "<faction> 한 명" instead of my name
		LuckDay = 0, -- A23-18 오늘의 운: Config.DayIndex of LuckEvents (another day -> 0)
		LuckEvents = 0, -- goose / kaiju events taken part in on LuckDay
		GraduateGraceUntil = 0, -- A23-18: os.time() when the rookie graduation grace ends (survives a rejoin)
		BetaPioneer = false, -- A23-18 first build (legacy): migrated into Titles.BetaPioneer by TitleService
		Titles = {}, -- BB16: { [Config.TitleDefs id] = os.time() first owned } (no stats)
		TitleSel = "", -- BB16: the title shown on the nametag ("" = automatic: faction rank / gray legend)
		-- BB2: one settings blob per account (SettingsService; never mirrored). Keys = sparse { [Keybinds action id] =
		-- key name or "" (unbound) } holding only changes from the defaults. DataService runs Config.SanitizeSettings on it.
		-- Cam (A23-65): user 10/08 "카메라 뒤 따라가게 하는 거 없는 게 나을까? 좀 어색한데?" -> the default is Free (Roblox's own
		-- camera); Follow stays in Settings for whoever wants it. Settings V3 (검수 10/09): a save from before V3 gets Cam = Free
		-- once (SanitizeSettings); a Follow picked after that is kept
		Settings = { V = 3, Keys = {}, Sfx = 1, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = false, Lang = "Auto", BagSort = "Default",
			Cam = "Free" },
		-- P6 / BB38 (TelemetryService, analytics only): { Funnel = { [step name] = true }, FirstDeath = true, Sessions = n }
		Telemetry = {},
		-- CR-M4: anti-collusion pair cooldowns kept in the session-locked save so they follow the player across servers
		-- (never mirrored). ["<kind>:<otherUserId>"] = os.time() of the last reward (PlayerService.PairReady);
		-- "kolog:<victimUserId>" = { t1, t2 } (last two KOs). Pruned at PlayerReady (> 1800 s old, at most 200 keys).
		PairCD = {},
		-- CR-M12: bully stacks / wanted stars saved at leave with os.time(); restored minus decay on the next join
		SavedBully = 0,
		SavedBullyAt = 0,
		SavedStars = 0,
		SavedStarsAt = 0,
		-- A23-39 / PET-2 pets (PetService): List[uid] = { Sp, Lv, XP, Name, Lean, Bound }, Equipped = { uid }, Next = the
		-- next uid number. TamerNotice = the one-time "the hunter became the pet tamer" notice (+ free class change) is done
		Pets = { List = {}, Equipped = {}, Next = 1 },
		TamerNotice = false,
		-- SKL-2 (A23-49): skill slots opened so far (0 = none yet, 1 = Q, 2 = +Z, 3 = +X at Config.Skills.Unlock; all after
		-- a rebirth). The most ever reached is kept through rebirths, class / faction changes and level resets (SkillService)
		SkillSlots = 0,
		-- A23-71: this save's SkillSlots follow the Lv5 / 15 / 25 rule (older saves are fixed once at load: DataService)
		SkillsA71 = true,
		-- A23-69 stat points (an additive field, Version stays 3): Auto = the class pattern places every point (default ON); Order = the letters
		-- picked by hand, in order ("HAHA...", at most Config.Stats.MaxPoints). No balance is kept: the points come from
		-- the level (Config.StatPoints), so a level reset shrinks the build and leveling up again rebuilds it
		Stats = { Auto = true, Order = "" },
		-- A23-75 (additive, Version stays 3): faction looks unlocked without a pass (attendance) + the worn one, and the
		-- last ownership answer Roblox gave per pass / look (used only when the check at join fails)
		Looks = { Owned = {}, On = "" },
		PassSeen = {},
	},
	-- keys mirrored 1:1 to Player attributes (same name) by PlayerService
	Mirrored = {
		"Level", "XP", "BankGold", "CarriedGold", "WeaponTier", "WeaponOwnedMask", "BlacksmithVisited", "Faction", "Class", "ClassChosen",
		"CharacterGender",
		"HPPotionCount", "MPPotionCount", "HideAnnounceName", "LuckEvents", "TitleSel",
		"Rebirths", "RebirthBonus", "FallMarks", "RedeemMarks", "Honor", "Infamy", "SwitchCount",
		"LastSwitchTime", "PlaytimeSeconds", "TotalKills", "DailyDay", "DailyClaims",
		"VacationDays", "VacationGold", "VacationXP", "CheerStars",
		"TutorialStep", "TutorialKills", -- addendum A4 (kills: meadow guide after a mid-mission death)
		"IntroSeen", -- A23-9
		"AutoCombatUnlocked", "AutoCombatEnabled", -- A23-1
		"SkillSlots", -- SKL-2: the SkillBar shows these slots
	},
}

----------------------------------------------------------------- levels
Config.Levels = {
	MaxLevel = 100,
	XPBase = 30,
	XPExponent = 1.4,
	EarlyUntil = 10, -- addendum A7-2: levels below this need only EarlyMult of the normal XP...
	EarlyMult = 0.5, -- ...(target: Lv 10 in about 10-12 minutes of slime hunting)
}

function Config.XPToNext(level)
	local xp = math.floor(Config.Levels.XPBase * level ^ Config.Levels.XPExponent)
	if level < Config.Levels.EarlyUntil then
		xp = math.max(1, math.floor(xp * Config.Levels.EarlyMult)) -- addendum A7-2 (min 1)
	end
	return xp
end

----------------------------------------------------------------- weapons (7 tiers shared by every class)
-- Damage = normal per-target swing damage at Lv 1 for class Damage multiplier 1.0, BEFORE the 50% immediate rule.
Config.WeaponShop = { MaxSoldTier = 3, PromptName = "HHC_BlacksmithPrompt", Distance = 12 }

Config.Weapons = {
	{ Tier = 1, Damage = 8, Price = 0, MinLevel = 1, Color = Color3.fromRGB(120, 85, 50), Material = Enum.Material.Wood, Length = 3 },
	{ Tier = 2, Damage = 15, Price = 150, MinLevel = 1, Color = Color3.fromRGB(165, 120, 75), Material = Enum.Material.WoodPlanks, Length = 3.5 },
	{ Tier = 3, Damage = 38, Price = 800, MinLevel = 5, Color = Color3.fromRGB(175, 180, 190), Material = Enum.Material.Metal, Length = 4 },
	{ Tier = 4, Damage = 88, Price = 3000, MinLevel = 12, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, Length = 4.5 },
	{ Tier = 5, Damage = 200, Price = 10000, MinLevel = 20, Color = Color3.fromRGB(140, 220, 255), Material = Enum.Material.Glass, Length = 5 },
	{ Tier = 6, Damage = 450, Price = 30000, MinLevel = 30, Color = Color3.fromRGB(180, 150, 255), Material = Enum.Material.Neon, Length = 5.5 }, -- 3rd review: lilac like the approved Weapon_*_T6 art
	{ Tier = 7, Damage = 1000, Price = 90000, MinLevel = 40, Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Length = 6.5,
		RequiresFaction = true,
		FactionColors = { Halo = Color3.fromRGB(255, 230, 120), Horns = Color3.fromRGB(200, 30, 40) },
	},
	-- A23-12: the slime jackpot ("젤리 왕관" legendary). Never sold; dropped only by Config.Loot.Jackpot monsters,
	-- exactly 2x the best shop weapon (tier 3: 38 -> 76, so the tier-4 drop at 88 stays an upgrade), usable at any level.
	{ Tier = 8, Damage = 76, Price = 0, MinLevel = 1, Legend = true, Color = Color3.fromRGB(120, 240, 190), Material = Enum.Material.Neon, Length = 4.5 },
}
Config.MaxWeaponTier = #Config.Weapons

-- display names per class (A23-48: English only); tier 7 is a table keyed by faction. Index = saved tier key: only
-- ever APPEND tiers. T4-T6 names come from the monsters that drop them (design skills_weapons_pets_2026-10-05 §1 B3).
Config.WeaponNames = {
	Warrior = { "Twig", "Wooden Sword", "Iron Sword", "Goblin Thief's Golden Sword", "Old Kingdom Crystal Sword", "Guardian Spirit Sword",
		{ Halo = "Dawn Sword", Horns = "Ruin Sword", None = "Crown Shard Sword" }, "Jelly Crown Sword" },
	Mage = { "Dry Staff", "Oak Staff", "Iron Staff", "Goblin Thief's Golden Staff", "Old Kingdom Crystal Staff", "Guardian Spirit Staff",
		{ Halo = "Dawn Staff", Horns = "Ruin Staff", None = "Crown Shard Staff" }, "Jelly Crown Staff" },
	Archer = { "Slingshot Bow", "Wooden Bow", "Iron Bow", "Goblin Thief's Golden Bow", "Old Kingdom Crystal Bow", "Guardian Spirit Bow",
		{ Halo = "Dawn Bow", Horns = "Ruin Bow", None = "Crown Shard Bow" }, "Jelly Crown Bow" },
}

-- A23-39: the pet tamer (artisan guild Archer, Config.IsTamer) holds taming batons instead of bows (same stats)
Config.WeaponNames.Tamer = { "Twig Baton", "Wooden Baton", "Iron Baton", "Goblin Thief's Golden Baton",
	"Old Kingdom Crystal Baton", "Guardian Spirit Baton", { Halo = "Dawn Baton", Horns = "Ruin Baton", None = "Crown Shard Baton" },
	"Jelly Crown Baton" }
-- the former English twin is the same tables now (readers of WeaponNamesEn keep working)
Config.WeaponNamesEn = Config.WeaponNames

-- Weapon grades (design §1 B1): stars are RARITY, not power. Colors = ART_DIRECTION 2.3 grade strokes.
Config.WeaponGrades = {
	Common = { Name = "Common", NameEn = "Common", Stars = 1, Color = Color3.fromRGB(200, 200, 200), Rank = 1 },
	Fine = { Name = "Fine", NameEn = "Fine", Stars = 2, Color = Color3.fromRGB(90, 200, 90), Rank = 2 },
	Rare = { Name = "Rare", NameEn = "Rare", Stars = 3, Color = Color3.fromRGB(70, 140, 255), Rank = 3 },
	Epic = { Name = "Epic", NameEn = "Epic", Stars = 4, Color = Color3.fromRGB(170, 90, 230), Rank = 4 },
	Legend = { Name = "Legendary", NameEn = "Legendary", Stars = 5, Color = Color3.fromRGB(255, 160, 40), Rank = 5 },
}
-- per tier: grade id + where it comes from (one line, shown in the item list / blacksmith)
Config.WeaponInfo = {
	{ Grade = "Common", Source = "Your first weapon, a gift from the Blacksmith", SourceEn = "Your first weapon, a gift from the Blacksmith" }, -- A23-34
	{ Grade = "Common", Source = "Sold at the Forge" },
	{ Grade = "Fine", Source = "Sold at the Forge (from Lv5)" },
	{ Grade = "Rare", Source = "Rare drop from Goblins and Goblin Brutes, or a Forge commission" },
	{ Grade = "Epic", Source = "Rare drop from Skeletons and Skeleton Knights, or a Forge commission" },
	{ Grade = "Epic", Source = "Very rare drop from Skeleton Knights, or a Forge commission" },
	{ Grade = "Legend", Source = "Crafted by artisans (full launch)" },
	{ Grade = "Legend", Source = "Super rare slime drop (jackpot!)" },
}

function Config.WeaponGrade(tier)
	local info = Config.WeaponInfo[tier]
	return Config.WeaponGrades[info and info.Grade or "Common"] or Config.WeaponGrades.Common
end

function Config.WeaponSource(tier)
	local info = Config.WeaponInfo[tier]
	return info and info.Source or ""
end

-- A23-28: a weapon is EQUIPPED only at Level >= its MinLevel (owning / enhancing it has no level limit; the legendary
-- T8 has MinLevel 1). Server rule (LootService / ShopService); clients use it to show the lock.
function Config.WeaponUsable(tier, level)
	local def = type(tier) == "number" and Config.Weapons[tier] or nil
	if type(def) ~= "table" then return false end
	return (tonumber(level) or 1) >= (tonumber(def.MinLevel) or 1)
end

-- the best owned tier (bit t-1 of ownedMask) usable at `level` (by Damage, so the legendary T8 counts as the 76-damage
-- weapon it is); 0 = bare hands when no owned weapon is usable (A23-34: tier 1 is owned only after the M1_1 gift)
function Config.BestUsableWeapon(ownedMask, level)
	local best, bestDamage = 0, -1
	local mask = math.floor(tonumber(ownedMask) or 0)
	for tier, def in Config.Weapons do
		if type(def) == "table" and bit32.band(mask, bit32.lshift(1, tier - 1)) ~= 0
			and Config.WeaponUsable(tier, level) and (tonumber(def.Damage) or 0) > bestDamage then
			best, bestDamage = tier, tonumber(def.Damage) or 0
		end
	end
	return best
end

-- "★★★" (filled stars only; rarity, not power)
function Config.WeaponStars(tier)
	return string.rep("★", Config.WeaponGrade(tier).Stars)
end

function Config.WeaponName(tier, classId, factionId)
	if tier == 0 then return Config.Text.BareHands end -- A23-34: no weapon equipped
	local names = (Config.IsTamer(classId, factionId) and Config.WeaponNames.Tamer) -- A23-39: batons
		or Config.WeaponNames[classId] or Config.WeaponNames.Warrior
	local n = names[tier]
	if type(n) == "table" then return n[factionId] or n.None end
	return n or "?"
end

-- Existing GPT inventory icons; tier 7 uses the chosen faction, with the neutral icon as the unset fallback.
-- A23-34: tier 0 (bare hands) has no icon -> nil (UIKit.ArtId(nil) keeps the slot's code fallback)
function Config.WeaponArtKey(tier, classId, factionId)
	if type(tier) ~= "number" or tier ~= tier or math.abs(tier) == math.huge then tier = 1 end
	if tier < 1 then return nil end
	tier = math.clamp(math.floor(tier), 1, Config.MaxWeaponTier)
	if classId ~= "Warrior" and classId ~= "Mage" and classId ~= "Archer" then classId = "Warrior" end
	-- A23-39: the pet tamer's batons (icons T1-T6; T7 / T8 keep the Archer keys until they are drawn)
	if tier <= 6 and Config.IsTamer(classId, factionId) then return "Weapon_Tamer_T" .. tostring(tier) end
	local key = "Weapon_" .. classId .. "_T" .. tostring(tier)
	if tier == 7 then
		local faction = (factionId == "Halo" or factionId == "Horns") and factionId or "Neutral"
		key ..= "_" .. faction
	end
	return key
end

function Config.WeaponColor(tier, factionId)
	local w = Config.Weapons[tier]
	if not w then return Color3.new(1, 1, 1) end
	if w.FactionColors and w.FactionColors[factionId] then return w.FactionColors[factionId] end
	return w.Color
end

-- A23-12: scroll enhancement +N multiplies weapon damage by 1 + 0.10 * N (N = 0..Config.Loot.MaxEnhance)
function Config.EnhanceMult(enhance)
	if type(enhance) ~= "number" or enhance ~= enhance or math.abs(enhance) == math.huge then return 1 end
	local loot = Config.Loot
	return 1 + loot.EnhancePerLevel * math.clamp(math.floor(enhance), 0, loot.MaxEnhance)
end

-- normal per-target damage of the weapon at this level and enhancement (before class, bonuses and multipliers).
-- A23-34: a tier with no Config.Weapons row (0 = bare hands) is the punch, Config.Combat.Unarmed.Damage (no +N).
function Config.WeaponDamage(tier, level, enhance)
	local w = type(tier) == "number" and Config.Weapons[tier] or nil
	local byLevel = 1 + Config.Combat.LevelDamagePerLevel * (level - 1)
	if not w then return Config.Combat.Unarmed.Damage * byLevel end
	return w.Damage * byLevel * Config.EnhanceMult(enhance)
end

-- basic attacks to defeat a monster with the server's swing formula (no crit / perks / faction bonuses):
-- what actually changes when the blacksmith sells a weapon (the shop never shows raw weapon Damage)
function Config.SwingHitsToKill(tier, level, classId, monsterId, factionId, enhance)
	local m = Config.MonsterTypes and Config.MonsterTypes[monsterId]
	local c = Config.AttackProfile(classId, tier, factionId) -- A23-34: a punch has no class multiplier
	if type(m) ~= "table" or type(m.HP) ~= "number" then return nil end
	local f = factionId and Config.Factions[factionId]
	local bonus = (type(f) == "table" and type(f.DamageBonus) == "number") and f.DamageBonus or 0 -- Horns +15%
	local per = Config.WeaponDamage(tier, math.max(1, level or 1), enhance) * (c.Damage or 1) * (1 + bonus)
		* ((Config.BasicSkill and Config.BasicSkill.SwingImmediate) or 0.5)
	per = math.max(1, math.floor(per + 0.5)) -- Util.RoundDamage
	return math.ceil(m.HP / per)
end

----------------------------------------------------------------- classes
-- Same buttons for everyone; the class only changes attack SHAPE, stats, weapon look and release shape.
Config.ClassOrder = { "Warrior", "Mage", "Archer" }
Config.Classes = {
	Warrior = {
		Id = "Warrior",
		Names = { Halo = "Paladin", Horns = "Berserker", Neutral = "Blacksmith", None = "Warrior" },
		Desc = "Hits every enemy around you at once. Very tough!",
		PickLine = "Get close and smash everything around", -- addendum A7-4 (picker card action line)
		Weapon = "Sword",
		HealthMult = 1.3, Damage = 1.0, SwingInterval = 1.0,
		Pattern = "Around", -- every valid target within Range of self
		Range = 10, Targets = 0, Splash = 0, -- Targets 0 = unlimited
		-- A23-61 (user 2026-10-06 night): the basic attack hits the whole front half - AimCone is the half-angle from where
		-- I face, so 90 = left / right 90 deg each (180 in all); nothing behind me
		AimCone = 90,
		ReleaseCenter = "Self", -- shockwave on self (the skill stays an all-around blast)
		ChargeAuto = 1, ChargeManual = 2,
		Ranged = false, PvPMult = 1.0,
		WalkSpeedMult = 1.0,
		ReleaseMult = 1.0, -- tuning knob: multiplies this class's release damage
		Stats = { "HP ×1.3", "ATK ×1.0", "Hits all around" },
		DisplayStats = { HP = 4, Atk = 3, Spd = 2 }, -- picker card bars (체력 / 공격 / 속도), 5-point scale, cosmetic only
	},
	Mage = {
		Id = "Mage",
		Names = { Halo = "Light Mage", Horns = "Dark Mage", Neutral = "Alchemist", None = "Mage" },
		Desc = "Magic orbs for far enemies! Boom, it hits the area too!",
		PickLine = "Stay back and blast a wide area", -- addendum A7-4
		Weapon = "Staff",
		HealthMult = 0.8, Damage = 1.3, SwingInterval = 1.1, -- 2026-10-06 user: mage a bit stronger (was 1.25)
		Pattern = "Splash", -- nearest valid target within Range, then every valid target within Splash of it
		Range = 35, Targets = 1, Splash = 7,
		AimCone = 90, -- A23-61: the front half (90 deg each side of where I face), nothing behind
		ReleaseCenter = "Target", -- meteor on the nearest target within Range (self if none)
		ChargeAuto = 1, ChargeManual = 2,
		Ranged = true, PvPMult = 0.85,
		WalkSpeedMult = 1.0,
		ReleaseMult = 1.0,
		Stats = { "HP ×0.8", "ATK ×1.3", "35-stud range + blast" },
		DisplayStats = { HP = 2, Atk = 4, Spd = 3 },
	},
	Archer = {
		Id = "Archer",
		-- A23-39: the artisan guild's Archer is the pet tamer (same Archer numbers; the baby slime fights, Config.Tamer)
		Names = { Halo = "Ranger", Horns = "Shadow Hunter", Neutral = "Pet Tamer", None = "Archer" },
		Desc = "Shoots two foes at a time, fast. Quick feet!",
		PickLine = "Shoot foes one by one from afar", -- addendum A7-4
		Weapon = "Bow",
		HealthMult = 1.0, Damage = 0.55, SwingInterval = 0.5,
		Pattern = "Multi", -- the Targets nearest valid targets within Range
		Range = 30, Targets = 2, Splash = 0,
		AimCone = 90, -- A23-61: the front half (90 deg each side of where I face), nothing behind
		ReleaseCenter = "Target", -- arrow rain on the nearest target within Range (self if none)
		ChargeAuto = 0.5, ChargeManual = 1, -- swings twice as often, so half the stacks per swing
		Ranged = true, PvPMult = 0.85,
		WalkSpeedMult = 1.1,
		ReleaseMult = 1.0,
		Stats = { "HP ×1.0", "ATK ×0.55 (2x fast)", "Hits 2 at 30 studs · Move +10%" },
		DisplayStats = { HP = 3, Atk = 2, Spd = 4 },
	},
}

function Config.ClassName(classId, factionId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return c.Names[factionId] or c.Names.None
end

-- A23-14 class change (user 2026-10-05): below Lv FreeKeepLevelBelow a free change keeps level and XP (the server
-- then never spends a ticket, even when one was requested); from that level on: free = back to Lv 1 / XP 0,
-- change ticket = level kept. Server: ClassService.onChangeClass. Client previews use Config.ClassChangeKeepsLevel.
Config.ClassChange = {
	FreeKeepLevelBelow = 5,
}

-- true when a free class change at `level` keeps the level (same rule as the server)
function Config.ClassChangeKeepsLevel(level)
	local lv = tonumber(level)
	if lv == nil or lv ~= lv then return false end
	return math.floor(lv) < (tonumber(Config.ClassChange.FreeKeepLevelBelow) or 0)
end

----------------------------------------------------------------- combat
Config.Combat = {
	CritChance = 0.10, -- PvE swings only (never releases, never PvP)
	CritMult = 2,
	LevelDamagePerLevel = 0.02, -- weapon damage * (1 + 0.02 * (level - 1))
	AutoTick = 0.2, -- A23-1 auto-combat loop (unlocked by the crown-shard quest, never by level)
	TownRegenPerSec = 0.10, -- fraction of max HP per second inside Town zones (all factions)
	AutoLoopInterval = 0.1,
	RegenTick = 1,
	ChargeTick = 0.1, -- perfect-window watcher interval
	-- addendum A3-H3 / CR-M17: after a manual swing the auto loop skips the player for the class SwingInterval +
	-- ManualYieldPad (a fixed 1.0 s window was <= the Warrior / Mage interval, so held manual attacks went auto).
	ManualYieldPad = 0.3,
	-- P2 idle rest: OFF by user decision (2026-10-05 "계속 사냥": auto combat keeps hunting while the player is away;
	-- Roblox itself disconnects a player after 20 min without input). Kept switchable: true = after AutoIdleSeconds
	-- auto rests (Zzz, monsters don't start fights) with a warning AutoIdleWarnSeconds before.
	AutoIdleRest = false,
	AutoIdleSeconds = 900,
	AutoIdleWarnSeconds = 30,
	AutoIdleMoveStuds = 1.5, -- moving this far within a second counts as activity (server-side check)
	ManualPriority = 1.0, -- legacy fixed window (pre CR-M17); kept only so old references never read nil
	AutoPvPHintCooldown = 60, -- addendum A3-M3: "under attack" hint at most once per this many seconds
	-- A23-34 (user 2026-10-06): new players start bare-handed. Every class throws the same short punch until the first
	-- weapon (M1_1 blacksmith gift): Damage at Lv1 before the 50% swing rule (= 2 per punch, a slime takes about 5),
	-- no class multiplier, no MP, one nearest target within Range in front (AimCone). Range 7 > monster AttackRange 5.5.
	-- PvPRatioMin (검수 2026-10-06): a bare-handed attacker's PvP weapon ratio floor (weapons: Config.PvP.PowerRatioMin
	-- 0.8). With 0.4 a punch is weaker than every class's tier-1 basic attack against any opponent at the same level.
	Unarmed = { Damage = 4, Range = 7, Interval = 0.8, AimCone = 90, PvPRatioMin = 0.4 }, -- AimCone: A23-61 front half
}

-- A23-34: the basic attack's shape for a class holding `tier`. With a weapon it is the class row itself (Pattern, Range,
-- SwingInterval, AimCone, Targets, Splash, Damage, Ranged, PvPMult); with no weapon row (0 = bare hands) every class
-- throws the same punch: Style "Punch", Unarmed = true, one nearest target (Pattern "Multi", Targets 1), Damage
-- (class multiplier) 1, not ranged, no Mage MP. Server: CombatService.Swing / auto combat; clients read the same table
-- for facing and swing timing. Skill Q never uses it (it stays the class skill). factionId: kept for A23-39.
-- A23-39: the pet tamer (Config.IsTamer) uses the same numbers (the Archer row armed, the punch bare-handed) with
-- Style = Config.Tamer.SwingStyle ("PetHeadbutt": the baby slime runs to the target, headbutts it and comes back).
local BARE_PROFILES, TAMER_PROFILES = {}, {}
function Config.AttackProfile(classId, tier, factionId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	local armed = type(tier) == "number" and Config.Weapons[tier] ~= nil
	local p = c
	if not armed then
		p = BARE_PROFILES[c.Id]
		if not p then
			local u = Config.Combat.Unarmed
			p = { Id = c.Id, Style = "Punch", Unarmed = true, Pattern = "Multi", Targets = 1, Splash = 0, Range = u.Range,
				SwingInterval = u.Interval, AimCone = u.AimCone, Damage = 1, Ranged = false, PvPMult = 1 }
			BARE_PROFILES[c.Id] = p
		end
	end
	if not Config.IsTamer(c.Id, factionId) then return p end
	local key = armed and "Armed" or "Bare"
	local tp = TAMER_PROFILES[key]
	if not tp then
		tp = table.clone(p)
		tp.Style = Config.Tamer.SwingStyle
		TAMER_PROFILES[key] = tp
	end
	return tp
end

----------------------------------------------------------------- charge & release ("자동은 장전, 손은 발사")
-- Design intent: pure idle (auto swings + auto release) ~= 1.25x baseline DPS; auto swings + PERFECT release ~= 2.5x.
-- Compatibility constants for old fixtures only. Active combat uses BasicSkill and no charge state.
Config.BasicSkill = {
	ManaCost = 20, Cooldown = 3, DamageMultiplier = 6, Radius = 9,
	SwingImmediate = 0.5, PvPCapPct = 0.35, HaloHealPct = 0.10, HaloHealCapPct = 0.30,
}
-- SKL-1 (A23-49, docs/design/skill_kit_beta_2026-10-06.md section 1 rules / 4 tables / 5 English / 8-1 shape): every
-- class has three skills Q / Z / X, learned at Unlock (A23-71, user 2026-10-07: none at the start, Q Lv5, Z Lv15,
-- X Lv25; all three after a rebirth). Defs[kit][slot]; an X with Halo / Horns tables differs per
-- faction (Config.SkillDef merges the faction table over the base). Kits: Warrior / Mage / Archer, and for the
-- artisan guild Blacksmith / Alchemist / Tamer (Config.SkillKit). Q keeps Config.BasicSkill's numbers (MP 20, 3 s, x6,
-- radius 9). Mult = x the monster hit D (ComputeMonsterHit); MP / CD (s); Shape: SelfCircle, TargetCircle (Range =
-- aim range), Line (Len x Width ahead), Chain (Range, Jump studs, Hits max), Field (Radius, Duration, Tick, TickMult),
-- Roar (Radius + Taunt), Hop (Hop studs back, Radius wind). Auto = when auto combat may use it (Never = true: never).
-- Flags stay off until the 10/20 decision (Studio checks only): ZEnabled / XEnabled (the SkillZ / SkillX keys and
-- SkillBar slots exist only while on), PvPZX (Z / X may hit players). MoveSkills / Fields / Taunt = the section 10
-- fall-backs. No skill, slot or power is sold (A23-49).
Config.Skills = {
	ZEnabled = false, XEnabled = false, PvPZX = false,
	MoveSkills = true, Fields = true, Taunt = true,
	Order = { "Q", "Z", "X" }, Unlock = { Q = 5, Z = 15, X = 25 }, GlobalGap = 0.5, MPStealCap = 20,
	Kits = { "Warrior", "Mage", "Archer", "Blacksmith", "Alchemist", "Tamer" },
	Defs = {
		Warrior = {
			Q = { NameEn = "Shockwave", DescEn = "Slam the ground. Hit and push everything around you.",
				Shape = "SelfCircle", Radius = 9, Mult = 6, MP = 20, CD = 3, Push = 2, Auto = { Min = 1, Radius = 9 } },
			Z = { NameEn = "Earth Cleave", DescEn = "Crack the ground ahead and pull monsters to you.",
				Shape = "Line", Len = 22, Width = 10, AimCone = 75, Mult = 7.5, MP = 25, CD = 6, Pull = 5,
				Auto = { Min = 2, OrBig = true, NoPull = true } },
			X = { Shape = "Roar", Radius = 12, Mult = 2, TauntRadius = 16, TauntSec = 4, SelfGuard = 0.4, GuardSec = 6,
				MP = 30, CD = 15, Auto = { Min = 3, Radius = 16, LowHP = 0.5, LowHPRadius = 10 },
				Halo = { NameEn = "Guardian Roar", DescEn = "Shout! Monsters chase you. You and your friends take less damage.",
					AllyGuard = 0.2, AllyRadius = 16 },
				Horns = { NameEn = "Rage Roar", DescEn = "Roar! Monsters chase you. Steal MP from every monster you hit.",
					MPSteal = 5 } },
		},
		Mage = {
			Q = { NameEn = "Meteor", DescEn = "Drop a meteor on the closest monster.",
				Shape = "TargetCircle", Range = 35, Radius = 9, Mult = 6, MP = 20, CD = 3, Auto = { Min = 1, Range = 35 } },
			Z = { NameEn = "Chain Bolt", DescEn = "A spark that jumps from monster to monster.",
				Shape = "Chain", Range = 35, Jump = 10, Hits = 4, Mult = 5, MP = 25, CD = 5, NeedTarget = true,
				Auto = { Min = 1, Range = 35, BeforeQIfSpread = 2 } },
			X = { Shape = "Field", Range = 35, Ahead = 10, Radius = 12, Duration = 5, Tick = 1, TickMult = 1.5, Slow = 0.5,
				MP = 30, CD = 14, Auto = { Min = 2, Radius = 12 },
				Halo = { NameEn = "Sun Circle", DescEn = "A sunny circle. Monsters slow down. Friends inside are guarded.",
					AllyGuard = 0.2 },
				Horns = { NameEn = "Hex Circle", DescEn = "A curse circle. Monsters slow down. Steal MP every second.",
					MPStealTick = 2 } },
		},
		Archer = {
			Q = { NameEn = "Arrow Rain", DescEn = "Arrows rain on the closest group.",
				Shape = "TargetCircle", Range = 30, Radius = 9, Mult = 6, MP = 20, CD = 3, Auto = { Min = 1, Range = 30 } },
			Z = { NameEn = "Pierce Shot", DescEn = "One big arrow through a whole line.",
				Shape = "Line", Range = 40, Len = 40, Width = 4, Mult = 9, MP = 25, CD = 5, Push = 3, Auto = { Min = 1 } },
			X = { Shape = "Hop", Hop = 10, HopTime = 0.25, Radius = 7, Mult = 3, Push = 6, MP = 25, CD = 10,
				Auto = { Never = true },
				Halo = { NameEn = "Light Step", DescEn = "Hop back on the wind. Friends near you are guarded.",
					AllyGuard = 0.2, AllyRadius = 12, GuardSec = 4 },
				Horns = { NameEn = "Shadow Step", DescEn = "Hop back in a puff. Steal MP from monsters you blow away.",
					MPSteal = 5 } },
		},
		-- the artisan guild (A6: no healing, life steal or faction extras; never hits or is hit by players): the same
		-- numbers as the class kit, its own names and crafted looks (Craft = the prop the skill shows)
		Blacksmith = {
			Q = { NameEn = "Hammer Quake", DescEn = "Bonk the ground with your hammer.", Shape = "SelfCircle", Radius = 9,
				Mult = 6, MP = 20, CD = 3, Push = 2, Auto = { Min = 1, Radius = 9 } },
			Z = { NameEn = "Hook Chain", DescEn = "Throw a hook and reel monsters in.", Shape = "Line", Len = 22, Width = 10,
				AimCone = 75, Mult = 7.5, MP = 25, CD = 6, Pull = 5, Auto = { Min = 2, OrBig = true, NoPull = true } },
			X = { NameEn = "Anvil Guard", DescEn = "Drop an anvil. Monsters chase you. You take less damage.", Shape = "Roar",
				Radius = 12, Mult = 2, TauntRadius = 16, TauntSec = 4, SelfGuard = 0.4, GuardSec = 6, MP = 30, CD = 15,
				Craft = "Anvil", CraftSec = 6, Auto = { Min = 3, Radius = 16, LowHP = 0.5, LowHPRadius = 10 } },
		},
		Alchemist = {
			Q = { NameEn = "Potion Bomb", DescEn = "Throw a fizzy potion at the closest monster.", Shape = "TargetCircle",
				Range = 35, Radius = 9, Mult = 6, MP = 20, CD = 3, Auto = { Min = 1, Range = 35 } },
			Z = { NameEn = "Bubble Hop", DescEn = "A bubble that bounces from monster to monster.", Shape = "Chain", Range = 35,
				Jump = 10, Hits = 4, Mult = 5, MP = 25, CD = 5, NeedTarget = true, Auto = { Min = 1, Range = 35, BeforeQIfSpread = 2 } },
			X = { NameEn = "Jelly Brew", DescEn = "A bubbling pot. Monsters inside turn wobbly and slow.", Shape = "Field",
				Range = 35, Ahead = 10, Radius = 12, Duration = 5, Tick = 1, TickMult = 1.5, Slow = 0.5, MP = 30, CD = 14,
				Craft = "Cauldron", Auto = { Min = 2, Radius = 12 } },
		},
		Tamer = {
			Q = { NameEn = "Pet Rush", DescEn = "Your slime jumps in and bonks the group.", Shape = "TargetCircle", Range = 30,
				Radius = 9, Mult = 6, MP = 20, CD = 3, Style = "PetDash", Auto = { Min = 1, Range = 30 } },
			Z = { NameEn = "Slime Roll", DescEn = "Your slime rolls through a whole line.", Shape = "Line", Range = 40, Len = 40,
				Width = 4, Mult = 9, MP = 25, CD = 5, Push = 3, Auto = { Min = 1 } },
			X = { NameEn = "Big Boing", DescEn = "Your slime grows big and bounces you back.", Shape = "Hop", Hop = 10,
				HopTime = 0.25, Radius = 7, Mult = 3, Push = 6, MP = 25, CD = 10, Craft = "BigSlime", Auto = { Never = true } },
		},
	},
	-- player-facing words (A23-48 English; A23-60: MP shows in the skill info / tooltips, never on the buttons)
	Text = {
		NewSkill = "New skill! %s (%s)", NewSkillTouch = "New skill! Tap the new button.", TryIt = "Try it",
		NoMP = "Not enough MP", NoTarget = "No target", TooHeavy = "Too heavy to jump!", CantHop = "Can't hop here",
		UnlocksAt = "Unlocks at Lv%d", WhereToHunt = "Where to hunt", Guarded = "Guarded", MPGain = "+%d MP",
		Cost = "Costs %d MP", Cooldown = "%s s cooldown", Ready = "Ready", NeedMP = "Need MP",
		XHalo = "Halo: guards friends", XHorns = "Horns: steals MP", XArtisan = "Artisan: crafted look",
		ShapeLine = "Line %d", ShapeCircle = "Area %d", ShapeChain = "Jumps %d", ShapeField = "Field %d s", ShapeHop = "Hop %d",
	},
}

-- A23-71: the skill slots (0..3) a level / rebirth count opens: Q at Unlock.Q, Z at Unlock.Z, X at Unlock.X, all three
-- after a rebirth (SKL-2). SkillService raises the saved SkillSlots to this; DataService fixes older saves once
function Config.SkillSlotsFor(level, rebirths)
	if (tonumber(rebirths) or 0) >= 1 then return 3 end
	local unlock, lv, n = Config.Skills.Unlock or {}, tonumber(level) or 1, 0
	for _, slot in Config.Skills.Order or { "Q", "Z", "X" } do
		if lv >= (tonumber(unlock[slot]) or math.huge) then n += 1 end
	end
	return n
end

-- A23-71: the player has a skill (Q) = saved slots >= 1 (kept after a level reset) or the level / rebirths open one
-- (also true in the moment before SkillService's catch-up raised the saved slots)
function Config.SkillLearned(slots, level, rebirths)
	return (tonumber(slots) or 0) >= 1 or Config.SkillSlotsFor(level, rebirths) >= 1
end

-- the skill kit of a class in a faction: Neutral -> Blacksmith / Alchemist / Tamer (Config.IsTamer), else the class id
function Config.SkillKit(classId, factionId)
	local class = Config.Classes[classId] and classId or "Warrior"
	if factionId == "Neutral" then
		if Config.IsTamer(class, factionId) then return "Tamer" end
		if class == "Warrior" then return "Blacksmith" end
		if class == "Mage" then return "Alchemist" end
		return "Tamer"
	end
	return class
end

-- one skill of a class in a faction: a new table = the kit's slot def with the faction's table (Halo / Horns) merged
-- over it (NameEn, DescEn and the faction extras); nil for an unknown slot. Callers may read it freely.
do
	local cache = {}
	function Config.SkillDef(classId, factionId, slot)
		local kit = Config.SkillKit(classId, factionId)
		local key = kit .. "|" .. tostring(factionId) .. "|" .. tostring(slot)
		local hit = cache[key]
		if hit ~= nil then return hit or nil end
		local defs = Config.Skills.Defs[kit]
		local base = defs and defs[slot]
		if type(base) ~= "table" then
			cache[key] = false
			return nil
		end
		local out = {}
		for k, v in base do
			if k ~= "Halo" and k ~= "Horns" then out[k] = v end
		end
		local fx = (factionId == "Halo" or factionId == "Horns") and base[factionId] or nil
		if type(fx) == "table" then
			for k, v in fx do out[k] = v end
		elseif out.NameEn == nil then
			-- a faction-split X seen without a side (None while picking): the Halo words
			local halo = base.Halo
			if type(halo) == "table" then out.NameEn, out.DescEn = halo.NameEn, halo.DescEn end
		end
		out.Kit, out.Slot = kit, slot
		cache[key] = out
		return out
	end
end

-- the numbers line of a skill for its info / tooltip (A23-60: MP is shown here, not on the button):
-- "Costs 25 MP · 6 s cooldown · Line 22"
function Config.SkillNumbers(def)
	if type(def) ~= "table" then return "" end
	local T = Config.Skills.Text
	local parts = { string.format(T.Cost, math.floor(tonumber(def.MP) or 0)) }
	table.insert(parts, string.format(T.Cooldown, tostring(tonumber(def.CD) or 0)))
	if def.Shape == "Line" then
		table.insert(parts, string.format(T.ShapeLine, math.floor(tonumber(def.Len) or 0)))
	elseif def.Shape == "Chain" then
		table.insert(parts, string.format(T.ShapeChain, math.max(0, math.floor((tonumber(def.Hits) or 1) - 1))))
	elseif def.Shape == "Field" then
		table.insert(parts, string.format(T.ShapeField, math.floor(tonumber(def.Duration) or 0)))
	elseif def.Shape == "Hop" then
		table.insert(parts, string.format(T.ShapeHop, math.floor(tonumber(def.Hop) or 0)))
	else
		table.insert(parts, string.format(T.ShapeCircle, math.floor(tonumber(def.Radius) or 0)))
	end
	return table.concat(parts, " · ")
end
Config.Charge = {
	SwingImmediate = 0.5, -- a swing that hits deals 50% of the normal per-target damage right away
	MinRelease = 10, -- minimum (floored) stacks to release
	BaseFactor = 0.5, -- release per target = BaseFactor * D * stacks * mult
	PerStackBonus = 0.02, -- manual release: mult = 1 + 0.02 * stacks
	AutoReleaseMult = 1.5, -- automatic release (PERFECT window missed): mult = 1.5
	PerfectWindow = 3, -- seconds the golden ring glows after reaching the cap
	-- CR-L22: added to PerfectWindow both for the manual PERFECT check and before the auto release fires, so a
	-- manual release sent at the very end of the window is not stolen by the auto release (latency)
	PerfectGrace = 0.25,
	RadiusBase = 8,
	RadiusPerStack = 0.1,
	PvPCapPct = 0.35, -- release damage to a player <= 35% of the target's current MaxHealth
	HaloHealPct = 0.10, -- Halo release heals allies in the radius by 10% of the total damage dealt...
	HaloHealCapPct = 0.30, -- ...capped at 30% of each ally's MaxHealth...
	HaloAllyStacks = 10, -- ...and gives each OTHER ally in the radius +10 stacks...
	HaloAllyStackCooldown = 5, -- ...at most once per 5 s per receiving ally (CR-H1: stops endless release ping-pong)
}

function Config.ReleaseRadius(stacks)
	return Config.Charge.RadiusBase + Config.Charge.RadiusPerStack * stacks
end

-- perTargetDamage = D (the player's normal per-target swing damage vs that target); stacks = floored stacks
function Config.ReleaseDamage(perTargetDamage, stacks, isAuto)
	local mult = isAuto and Config.Charge.AutoReleaseMult or (1 + Config.Charge.PerStackBonus * stacks)
	return Config.Charge.BaseFactor * perTargetDamage * stacks * mult
end

----------------------------------------------------------------- factions
-- playable factions in picker / team order (addendum A6 adds "Neutral").
-- War, Size Justice, underdog and every faction RATIO are Halo vs Horns only: never loop this list for those.
Config.FactionOrder = { "Halo", "Horns", "Neutral" }
Config.Factions = {
	Halo = {
		Id = "Halo", Name = "Knights of Light", Short = "Knights", Emblem = "K",
		TeamName = "Knights of Light", TeamColor = BrickColor.new("New Yeller"),
		Color = Color3.fromRGB(255, 215, 90),
		XPBonus = 0.30, GoldBonus = 0, DamageBonus = 0,
		MaxHPMult = 1.2,
		RegenPerSec = 0.02, -- always on (outside towns)
		Lifesteal = 0, LifestealCapPct = 0,
		AutoBankInterval = 90, AutoBankFraction = 0.5,
		PartyAuraPerAlly = 0.05, PartyAuraMaxAllies = 3, PartyAuraRadius = 30,
		CanBeWanted = false,
		ChargeCap = 150,
		ReleaseSupport = true, -- MP skill heals allies (Config.BasicSkill)
		Perks = {
			"XP +30% (level up faster)",
			"HP +20%, keeps healing",
			"Your skill heals nearby allies",
			"Half your pouch gold goes to the vault",
			"Catch Grudge Sack thieves to win gold back",
		},
		Pitch = "Heal friends and catch thieves!", -- 검수 10/09 (system review ①): the card's one big easy line
	},
	Horns = {
		Id = "Horns", Name = "Horn Legion", Short = "Horn Legion", Emblem = "H",
		TeamName = "Horn Legion", TeamColor = BrickColor.new("Really red"),
		Color = Color3.fromRGB(220, 50, 60),
		XPBonus = 0, GoldBonus = 0.25, DamageBonus = 0.15,
		MaxHPMult = 1.0,
		RegenPerSec = 0,
		Lifesteal = 0.10, LifestealCapPct = 0.03, -- heal 10% of damage dealt, max 3% max HP per swing/release
		AutoBankInterval = 0, AutoBankFraction = 0,
		PartyAuraPerAlly = 0, PartyAuraMaxAllies = 0, PartyAuraRadius = 0,
		CanBeWanted = true,
		ChargeCap = 175,
		ReleaseSupport = false,
		Perks = {
			"Gold +25% (get rich faster)",
			"ATK +15%, your hits steal HP",
			"Keep stolen gold safe and it is yours",
			"Rob the Knights and guard the Grudge Sack",
			"5 Wanted stars = turn into a Kaiju!",
		},
		Pitch = "Sneaky tricks and grab gold in PvP zones!", -- 검수 10/09 (system review ①)
	},
	-- addendum A6: third playable faction "장인 길드". No combat/economy perks, PvP-immune both ways, no plunder,
	-- sacks, stars, bounty, bully stacks, revenge or kaiju; excluded from war points, blessing, power sums and ratios
	-- (Size Justice S always 1.0); goose swings count 0; home/respawn = Crossroads (Config.HomeZoneId already does that);
	-- may enter neither HaloTown nor HornsTown. Crafting perks come in phase 2.
	-- addendum A9-1: Neutral identity colour is TEAL (grey stays reserved for 회색 전설 / 금 간 후광 and for "None").
	-- Nametag, UIKit.Theme and the CharacterVisuals gear mark read Color; the Team uses TeamColor (distinct from the others).
	Neutral = {
		Id = "Neutral", Name = "Artisan Guild", Short = "Artisan", Emblem = "A", -- CR-L44: "⚙" renders as a tofu box
		TeamName = "Artisan Guild", TeamColor = BrickColor.new(Color3.fromRGB(40, 200, 190)),
		Color = Color3.fromRGB(40, 200, 190), -- teal (A9-1)
		XPBonus = 0, GoldBonus = 0, DamageBonus = 0,
		MaxHPMult = 1.0,
		RegenPerSec = 0, -- no regen bonus (town regen still applies)
		Lifesteal = 0, LifestealCapPct = 0,
		AutoBankInterval = 0, AutoBankFraction = 0,
		PartyAuraPerAlly = 0, PartyAuraMaxAllies = 0, PartyAuraRadius = 0,
		CanBeWanted = false,
		ChargeCap = 150,
		ReleaseSupport = false, -- release: no heal, no stack sharing
		Perks = {
			"No fight buffs (no XP, gold, HP or ATK bonus)",
			"No PvP: you never attack or get attacked",
			"No worries about loot, Wanted or Grudge Sacks",
			"The Crossroads is your home",
			"Crafting expert (coming soon)",
		},
		Pitch = "Don't grab it. Shape it and craft it!",
		Note = "No fight buffs · No PvP · Crafting (coming soon)", -- picker card note (A6); plain text
	},
	None = {
		Id = "None", Name = "No Side", Short = "No Side", Emblem = "?",
		TeamName = nil, TeamColor = BrickColor.new("Medium stone grey"),
		Color = Color3.fromRGB(200, 200, 200),
		XPBonus = 0, GoldBonus = 0, DamageBonus = 0,
		MaxHPMult = 1.0,
		RegenPerSec = 0.01,
		Lifesteal = 0, LifestealCapPct = 0,
		AutoBankInterval = 0, AutoBankFraction = 0,
		PartyAuraPerAlly = 0, PartyAuraMaxAllies = 0, PartyAuraRadius = 0,
		CanBeWanted = false,
		ChargeCap = 150,
		ReleaseSupport = false,
		Perks = {},
		Pitch = "",
	},
}

-- a faction a player may newly pick (faction picker, altar switch, rebirth): Halo / Horns; the artisan guild only while
-- Config.Features.NeutralFaction is on (A23-57). A save that is Neutral already keeps it.
function Config.Pickable(factionId)
	if factionId == "Neutral" and not Config.FeatureOn("NeutralFaction") then return false end
	return (factionId == "Halo" or factionId == "Horns" or factionId == "Neutral") and Config.Factions[factionId] ~= nil
end

-- level-only base health (no faction, class, Size Justice or kaiju)
function Config.BaseHealth(level)
	return Config.Player.BaseMaxHealth + Config.Player.MaxHealthPerLevel * (level - 1)
end

-- "base MaxHealth": level x faction x class. PlayerService multiplies by JusticeService.GetHealthMult on top.
function Config.MaxHealth(level, factionId, classId)
	local f = Config.Factions[factionId] or Config.Factions.None
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return math.floor(Config.BaseHealth(level) * f.MaxHPMult * c.HealthMult)
end

Config.Titles = {
	Thresholds = { 0, 10, 50, 200, 1000 },
	Halo = { "Squire", "Knight", "Paladin", "Saint", "Archangel" },
	Horns = { "Rascal", "Raider", "Warlord", "Dread Lord", "Demon King" },
	None = "Adventurer",
}

-- returns (titleText, rankIndex 1..5; 0 for None)
function Config.GetTitle(factionId, honor, infamy)
	local names = Config.Titles[factionId]
	if type(names) ~= "table" then return Config.Titles.None, 0 end
	local points = (factionId == "Halo") and (honor or 0) or (infamy or 0)
	local rank = 1
	for i, t in Config.Titles.Thresholds do
		if points >= t then rank = i end
	end
	return names[rank], rank
end

-- title shown on nametag / HUD: session title > gray legend > rank title
-- BB16 order: session title (kaiju) > selected title (TitleSel) > gray legend > faction rank
function Config.DisplayTitle(factionId, honor, infamy, fallMarks, redeemMarks, sessionTitle, selected)
	if type(sessionTitle) == "string" and sessionTitle ~= "" then return sessionTitle end
	local def = type(selected) == "string" and selected ~= "" and Config.TitleDefs[selected] or nil
	if def then return def.Name end
	if (fallMarks or 0) >= Config.Rebirth.GrayLegendMin and (redeemMarks or 0) >= Config.Rebirth.GrayLegendMin then
		return Config.Story.GrayLegendTitle
	end
	local title = Config.GetTitle(factionId, honor, infamy)
	return title
end

----------------------------------------------------------------- Size Justice ("덩치 저울")
Config.Justice = {
	RecalcInterval = 30, -- seconds; also recomputed (deferred) on join / leave / faction change / rebirth
	MinScale = 1.0,
	MaxScale = 1.6,
	SignOnGold = 300, -- banked gold for picking the weaker faction on the FIRST faction choice only
	MaxVisualScale = 3.0, -- cap of the combined visual scale (S x bully x kaiju)
	ScaleRatePerSec = 0.6, -- character scale moves toward its target at this many scale units per second
	ScaleTick = 0.1,
}

----------------------------------------------------------------- A23-69 stat points (docs/design/stat_points_2026-10-07.md)
-- Every level from Lv2 gives one point (Config.StatPoints(L) = L - 1, at most MaxPoints; a rebirth gives none, CR-L5).
-- Attack (A) = every hit x (1 + f), Health (H) = max HP x (1 + f), f(r) = 1% a point up to 20, 0.5% for 21-40, 0.25%
-- from 41 (Curve), so a one-stat build is weaker than an even one. Auto (default ON) places the class pattern
-- (AutoPattern, repeated); by hand the save keeps Order, the letters picked in order (the free points are counted, never
-- saved). Power (Config.PowerOf / CombatPowerOf), and later the hits and HP, read the points through Config.StatMults,
-- which is (1, 1) while Config.Features.StatPoints is off. No stat, point or reset is ever sold (A23-69).
Config.Stats = {
	MaxPoints = 99,
	Letters = { A = true, H = true }, -- the beta stats: Attack, Health (Crit "C" comes with the full launch)
	-- f(points), in order: { up to this many points, + this much a point }
	Curve = { { 20, 0.01 }, { 40, 0.005 }, { math.huge, 0.0025 } },
	AutoPattern = { Warrior = "HA", Mage = "HA", Archer = "AH" }, -- repeated: Lv100 = H50 / A49 (Archer A50 / H49)
}

-- f(points): the bonus of `points` in one stat (0.1 at 10, 0.2 at 20, 0.25 at 30, 0.3 at 40, 0.4475 at 99; more points
-- than MaxPoints count as MaxPoints, NaN / text as 0)
function Config.StatBonus(points)
	local r = math.clamp(math.floor(tonumber(points) or 0), 0, Config.Stats.MaxPoints)
	if r ~= r then return 0 end
	local bonus, from = 0, 0
	for _, step in Config.Stats.Curve do
		if r <= from then break end
		bonus += (math.min(r, step[1]) - from) * step[2]
		from = step[1]
	end
	return bonus
end

-- the stat points a level gives: Lv1 0, then one a level, at most Config.Stats.MaxPoints
function Config.StatPoints(level)
	local lv = math.floor(tonumber(level) or 1)
	if lv ~= lv then lv = 1 end
	return math.clamp(lv - 1, 0, Config.Stats.MaxPoints)
end

-- a save's points (A, H, free) at `level`: Auto = the class pattern's first StatPoints(level) letters; by hand = the
-- first min(#Order, StatPoints(level)) letters of Order, the rest free. stats = data.Stats ({ Auto, Order })
function Config.StatAlloc(stats, level, classId)
	local points = Config.StatPoints(level)
	local letters
	if type(stats) ~= "table" or stats.Auto ~= false then
		local pattern = Config.Stats.AutoPattern[classId] or Config.Stats.AutoPattern.Warrior
		letters = string.sub(string.rep(pattern, math.ceil(points / #pattern)), 1, points)
	else
		letters = string.sub(type(stats.Order) == "string" and stats.Order or "", 1, points)
	end
	local a, h = 0, 0
	for i = 1, #letters do
		local ch = string.sub(letters, i, i)
		if ch == "A" then a += 1 elseif ch == "H" then h += 1 end
	end
	return a, h, points - (a + h)
end

-- (atkMult, hpMult) of a split: 1 + f each; (1, 1) while Config.Features.StatPoints is off
function Config.StatMults(a, h)
	if not Config.FeatureOn("StatPoints") then return 1, 1 end
	return 1 + Config.StatBonus(a), 1 + Config.StatBonus(h)
end

-- a player's split from the attributes StatService keeps (StatAtk / StatHp; missing = 0): the alloc of Config.PowerOf
function Config.StatAllocOf(player)
	local a, h = tonumber(player:GetAttribute("StatAtk")) or 0, tonumber(player:GetAttribute("StatHp")) or 0
	if a ~= a then a = 0 end
	if h ~= h then h = 0 end
	return { A = math.clamp(math.floor(a), 0, Config.Stats.MaxPoints), H = math.clamp(math.floor(h), 0, Config.Stats.MaxPoints) }
end

-- a save's Stats repaired (DataService.fillDefaults): Auto a boolean (else true), Order = its uppercase letters A-Z
-- (검수 2026-10-07: kept for the stats a later stage adds; StatAlloc counts only A / H), at most MaxPoints of them (a
-- broken or huge Order is cut, never trusted)
function Config.SanitizeStats(t)
	local src = type(t) == "table" and t or {}
	local auto = true
	if type(src.Auto) == "boolean" then auto = src.Auto end
	local order = type(src.Order) == "string" and src.Order or ""
	local kept = {}
	for i = 1, math.min(#order, 4096) do
		if #kept >= Config.Stats.MaxPoints then break end
		local ch = string.sub(order, i, i)
		if string.match(ch, "^%u$") then table.insert(kept, ch) end
	end
	return { Auto = auto, Order = table.concat(kept) }
end

-- "base power" of a player (no Size Justice, no kaiju); rebirthMult = 1 + RebirthBonus.
-- enhance = scroll +N of the equipped weapon (the WeaponEnhance attribute); nil counts as +0 (Config.EnhanceMult).
-- alloc = { A, H } stat points (A23-69, nil = none): sqrt(attack x atkMult x health x hpMult) like the plain formula
function Config.PowerOf(level, weaponTier, rebirthMult, enhance, alloc)
	local am, hm = 1, 1
	if type(alloc) == "table" then am, hm = Config.StatMults(alloc.A, alloc.H) end
	return math.sqrt(Config.WeaponDamage(weaponTier, level, enhance) * am * Config.BaseHealth(level) * hm) * (rebirthMult or 1)
end

-- BB4 "전투력": the one power number players see = level + equipped weapon incl. scroll +N. It leaves out class,
-- faction, rebirth, Size Justice, bully, buffs and pets: same level + same weapon = same number for everyone.
-- The bully rule and the A23-18 boldness ratios compare this number (JusticeService.GetCombatPower).
-- Anything meaning "strongest weapon" sorts by Config.Weapons[t].Damage, never by the tier index (tier 8 is the
-- jelly legendary, damage 76 < tier 4).
Config.Power = {
	DisplayScale = 10,
	Text = {
		Label = "Power", LabelEn = "Power",
		Formula = "Set by your level and weapon (enhance included)", FormulaEn = "Set by your level and weapon (enhance included)",
		-- PvPNote / PvPNoteEn: finished lines, filled from Config.PvP.PowerRatioMax / Min right after Config.PvP below
		Up = "Power +%s", UpEn = "Power +%s",
		Change = "Power %s → %s", ChangeEn = "Power %s → %s",
	},
}

-- A23-34 (user 2026-10-06 "처음에는 전투력이 0"): bare hands count from 0 — the Lv1 punch is taken off, so Lv1 with no
-- weapon (and no pet) shows 0 and every level still adds a little. With a weapon the number is the BB4 value as before,
-- so armed players keep their numbers and every armed comparison (bully rule, boldness, Tab list) its balance.
-- A23-69: alloc = { A, H } stat points (nil = none; Config.StatAllocOf reads a player's)
function Config.CombatPower(level, tier, enhance, alloc)
	local raw = Config.PowerOf(level, tier, 1, enhance, alloc)
	if not (type(tier) == "number" and Config.Weapons[tier]) then raw -= Config.PowerOf(1, 0, 1, 0) end
	return math.max(0, math.floor(raw * Config.Power.DisplayScale + 0.5))
end

-- BB4 / A23-69: THE power number of a player, from the attributes (Level, WeaponTier, WeaponEnhance and the stat points
-- StatAtk / StatHp). JusticeService (the CombatPower attribute, the bully rule, boldness), PvPService, the Tab list and
-- the HUD all use this one formula. tierOverride / enhOverride: the same player with another weapon (LootService's
-- "Power X -> Y"). Server and client alike.
function Config.CombatPowerOf(player, tierOverride, enhOverride)
	local level = tonumber(player:GetAttribute("Level")) or 1
	if level ~= level then level = 1 end
	local tier = tierOverride
	if tier == nil then
		tier = tonumber(player:GetAttribute("WeaponTier")) or 0
		if tier ~= tier then tier = 0 end
		tier = math.clamp(math.floor(tier), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands
	end
	local enhance = enhOverride
	if enhance == nil then enhance = tonumber(player:GetAttribute("WeaponEnhance")) or 0 end
	return Config.CombatPower(math.max(1, level), tier, enhance, Config.StatAllocOf(player))
end

-- the highest number anyone can reach (max level, the highest-damage weapon at the max scroll +N; A23-69 with the stat
-- points on: the even split of every point, the strongest build); cached, one value with and one without stats
function Config.MaxCombatPower()
	local stats = Config.FeatureOn("StatPoints")
	local key = stats and "MaxCacheStats" or "MaxCache"
	if not Config.Power[key] then
		local points = Config.StatPoints(Config.Levels.MaxLevel)
		local even = stats and { A = math.floor(points / 2), H = points - math.floor(points / 2) } or nil
		local best = 0
		for t = 1, Config.MaxWeaponTier do
			best = math.max(best, Config.CombatPower(Config.Levels.MaxLevel, t, Config.Loot.MaxEnhance, even))
		end
		Config.Power[key] = best
	end
	return Config.Power[key]
end

-- S for a faction: weaker side = clamp(sqrt(enemy / ours), 1.0, 1.6); the stronger side naturally clamps to 1.0
function Config.SizeJustice(ourSum, enemySum)
	if ourSum <= 0 or enemySum <= 0 then return 1 end
	return math.clamp(math.sqrt(enemySum / ourSum), Config.Justice.MinScale, Config.Justice.MaxScale)
end

Config.Bully = {
	WeakPowerRatio = 0.5, -- (a) victim base power < 50% of the attacker's
	BaitWindow = 10, -- (a) does not apply if the victim damaged the attacker within the last 10 s...
	BaitMinPct = 0.2, -- ...for a total of >= 20% of the attacker's base MaxHealth (CR-M15: one stray hit is not bait)
	WantedIgnoresWeakRule = true, -- (a) does not apply if the victim had Wanted stars or bully stacks (lead decision)
	FreshSpawnSeconds = 15, -- (b) victim respawned less than 15 s ago
	RepeatKOs = 3, -- (c) 3rd+ KO of the same victim by the same attacker...
	RepeatWindow = 600, -- ...within 10 minutes
	MaxStacks = 3,
	PerStack = 0.15, -- each stack: -15% visual size and -15% damage (multiplies with S)
	DecaySeconds = 300, -- one stack decays per 5 min without a new bully KO
	BountyMult = 2, -- bounty for KOing a bully is doubled
	-- A23-22 penalty while BullyStacks >= 1 (ends when every stack decayed): no auto combat, XP and drop rows x0.5.
	-- Combat power and stats are NOT touched by it (the existing PerStack size / damage cut stays as it was).
	-- DropMult halves the drop rows AND the slime jackpot (A23-22 has no exception); the first Slime Prince scroll stays.
	Penalty = { NoAuto = true, XPMult = 0.5, DropMult = 0.5 },
}

-- BB4: the bully rules in plain words (character window, help, first-time tips, PvP warnings share these lines)
Config.Bully.Text = {
	Title = "When you become a bully", TitleEn = "When you become a bully",
	Lines = {
		string.format("KO a player weaker than %d%% of your power", math.floor(Config.Bully.WeakPowerRatio * 100 + 0.5)),
		string.format("KO a player who respawned less than %d s ago", Config.Bully.FreshSpawnSeconds),
		Config.Plural(string.format("KO the same player %d times within %d minutes", Config.Bully.RepeatKOs, math.floor(Config.Bully.RepeatWindow / 60))),
	},
	LinesEn = {
		string.format("KO a player weaker than %d%% of your power", math.floor(Config.Bully.WeakPowerRatio * 100 + 0.5)),
		string.format("KO a player who respawned less than %d s ago", Config.Bully.FreshSpawnSeconds),
		Config.Plural(string.format("KO the same player %d times within %d minutes", Config.Bully.RepeatKOs, math.floor(Config.Bully.RepeatWindow / 60))),
	},
}

function Config.BullyMult(stacks)
	return math.max(0, 1 - Config.Bully.PerStack * (stacks or 0))
end

Config.Revenge = {
	Bonus = 0.25, -- after being KO'd by a player: +25% damage to that killer...
	Duration = 90, -- ...for 90 s (plus a screen-edge arrow to them)
}

Config.Switch = {
	AltarRange = 20,
	Cooldown = 600, -- minimum seconds between two ALTAR faction changes (everyone, free or ticket)
}

----------------------------------------------------------------- PvP
Config.PvP = {
	RookieLevel = 15, -- rookie if Rebirths == 0 and (Level < 15 or PlaytimeSeconds < 3600)
	RookiePlaytime = 3600,
	-- A23-18 rookie graduation: for this many seconds after the rookie shield ends the player can neither hit nor be
	-- hit by players (the shield can't be used to strike first)
	GraduateGraceSeconds = 60,
	-- A23-18 boldness: honor / infamy / war points from a PvP KO x2 when the victim's power (Config.PowerOf) is at least
	-- StrongRatio of mine, x0.5 below WeakRatio. Gold, stars and grudge sacks are unchanged. (WeakPowerRatio stays.)
	BoldStrongRatio = 1.2,
	BoldWeakRatio = 0.8,
	BoldStrongMult = 2,
	BoldWeakMult = 0.5,
	SpawnProtection = 10, -- seconds; broken early when the protected player damages a player
	-- ⑤ (quality_ideas §1, 검수 2026-10-07): no shield bubble; while protected the body wears a soft outline in its
	-- faction color (Config.Factions[f].Color: Halo gold, Horns red), PvPService Highlight "ProtectGlow"
	ProtectGlow = { OutlineTransparency = 0.35 },
	HitPctOfMaxHP = 0.10, -- normal per-target PvP hit = victim BASE MaxHealth * 0.10 * powerRatio * ... (§4.9)
	PowerRatioMin = 0.8,
	PowerRatioMax = 1.5,
	CombatTagTime = 15, -- PvP damage within this window credits the KO and blocks travel/switch/class change
	PlunderRate = 0.20, -- Horns KO Halo: take 20% of (carried - safe floor) into the grudge sack
	PlunderCapPerLevel = 100, -- max stolen per KO = victim level * 100
	SafeFloorPerLevel = 10, -- never-stealable carried gold = victim level * 10
	BountyPerLevelStar = 15, -- bounty = 15 * level * stars (minted)
	VillainLossOnBountyKO = 0.25, -- Wanted Horns KO'd by Halo lose 25% of remaining carried gold
	VillainLossOnWantedPvEDeath = 0.25, -- Wanted Horns dying without a PvP killer
	MaxStars = 5,
	StarDecaySeconds = 120,
	StarDamageBonus = 0.05,
	StarGoldBonus = 0.10, -- monster gold bonus per star
	GlowStars = 3, -- red Highlight at >= 3
	NoTravelStars = 3, -- cannot use Travel at >= 3
	AnnounceStars = 5,
	PairRewardCooldown = 300, -- minted rewards (bounty, honor, infamy, war points) once per killer/victim pair per 300 s
	-- (stored in Data.Defaults.PairCD so it survives a server hop: CR-M4)
	HonorPerKOMin = 1, -- Halo KO of a 0-star, non-bully Horns gives 1 Honor
	CombatLogPenalty = 0.25, -- leaving while combat-tagged loses 25% of carried gold
	BoardRefresh = 5,
}

-- BB4 help line (character window / help / PvP tips): the real damage clamp, finished text (no format at the caller)
Config.Power.Text.PvPNote = string.format("However strong the weapons, PvP damage is at most x%s and at least x%s",
	tostring(Config.PvP.PowerRatioMax), tostring(Config.PvP.PowerRatioMin))
Config.Power.Text.PvPNoteEn = string.format("However strong the weapons, PvP damage is at most x%s and at least x%s",
	tostring(Config.PvP.PowerRatioMax), tostring(Config.PvP.PowerRatioMin))

-- bounty on a player: stars (Horns) or bully stacks (anyone), doubled while the player is a bully
function Config.Bounty(level, stars, bullyStacks)
	bullyStacks = bullyStacks or 0
	local units = math.max(stars or 0, bullyStacks)
	local b = Config.PvP.BountyPerLevelStar * level * units
	if bullyStacks > 0 then b *= Config.Bully.BountyMult end
	return b
end

----------------------------------------------------------------- grudge sack ("원한 돈자루")
Config.Grudge = {
	SackSeconds = 45, -- countdown; ticks ONLY while the thief is in a PvP zone; each new steal resets it to 45
	AvengeRefundRate = 1.2, -- a Halo player KOs the thief in time: each victim gets 120% (to the bank)...
	RefundBonusCooldown = 600, -- ...the extra 20% at most once per VICTIM per 10 min, whatever the thief (CR-L6)
	ReturnRate = 1.0, -- thief died without a Halo killer, or left the server: victims get 100% back
	RestealWindow = 180, -- the same thief stealing from the same victim again within 3 min steals 0
	-- "복수 대행" bonus (minted, to the bank) for the Halo player who KO'd the thief; at most once per AVENGER per
	-- PvP.PairRewardCooldown, whatever the thief (CR-L6: per-pair keys paid once per thief alt)
	AvengerBonus = 100,
	Tick = 0.25,
	-- P3 grudge mail (2026-10-05): a victim who left / is on another server gets their share at the next join instead of
	-- it being destroyed (TECH_SPEC §4.14 replaced). Separate DataStore, at most MailMax letters kept.
	MailStore = "HaloHorns_GrudgeMail_v1",
	MailMax = 20,
	-- A23-18 grudge ghost hold: the respawned victim presses [유령으로 붙잡기] once per HoldCooldown -> the thief must
	-- survive HoldAddSeconds longer, at most HoldMaxSeconds per sack (45 -> 55 s). No release option, no honor.
	HoldCooldown = 3,
	HoldAddSeconds = 2,
	HoldMaxSeconds = 10,
	HoldGlowSeconds = 3,
}

----------------------------------------------------------------- wanted kaiju ("수배범 괴수화")
Config.Kaiju = {
	StarsNeeded = 5,
	SirenSeconds = 10, -- server-wide siren banner before the transformation
	Duration = 120,
	VisualScale = 3, -- combined visual scale is capped at Config.Justice.MaxVisualScale
	HPMult = 20, -- MaxHealth = base MaxHealth x S x 20 x (1 + 0.15 x Halo players within 80 studs)
	HPPerNearbyHalo = 0.15,
	NearbyRadius = 80,
	HPRecalc = 5, -- seconds; preserves HP %
	StompInterval = 4,
	StompRadius = 15,
	StompPct = 0.06, -- of each stomped Halo player's MaxHealth (never rookies, never Protected, never in towns)
	BountyPoolMult = 3, -- reward pool = 3 x current bounty + the kaiju's carried gold
	DamageShare = 0.5, -- 50% of the pool split by damage share, the rest split equally among participants
	SurviveBankMult = 1.5, -- survived: carried gold x1.5 moved to the bank
	ShieldSeconds = 10, -- spawn-protection-style shield after the event
	HaloWarPoints = 150, -- war points to Halo's pool when the kaiju is KO'd
	HornsWarPoints = 150, -- war points to Horns' pool when the kaiju survives
	-- CR-M3: the minted pool share is paid once per participant/kaiju pair per 30 min (stored in Data PairCD as
	-- "kaiju:<kaijuUserId>", CR-M4); the kaiju's carried gold moved into the pool is capped at PvP.PlunderCapPerLevel x
	-- the kaiju's level (the rest is destroyed)
	PairRewardCooldown = 1800,
	ReleaseCapPct = 0.08, -- CR-M7: one release on an ACTIVE kaiju deals <= 8% of its current MaxHealth (players: Charge.PvPCapPct)
	Tick = 0.25,
}

----------------------------------------------------------------- war meter ("왕관 쟁탈전")
Config.War = {
	RoundSeconds = 600,
	MonsterPoints = 1, -- carried in MonsterKilled info.WarPoints
	GoldenPoints = 5,
	PvPKOPoints = 20,
	PvPKOPerStar = 5,
	SiegeTarget = 150, -- per-capita points needed when only one faction is online
	ChestMinPoints = 30, -- personal points needed for a chest
	WinnerChestPerLevel = 100,
	LoserChestPerLevel = 30,
	BlessingGold = 0.25,
	BlessingXP = 0.25,
	Tick = 1,
}

-- Sky presets applied by WarService (Lighting + WarTint). Never add an Atmosphere (A9-3; the per-zone mood is the
-- client ZoneLook, A23-30). A23-29/30 user pick 'E' (docs/design/world_blend_2026-10-06.md): Neutral = the bright toy
-- midday 'B' (ClockTime 14.2, fog 250-1100 pale blue); Dawn / Eclipse keep their hues and fog (120-650) with the
-- ZoneLook base light (Brightness / Ambient / OutdoorAmbient = ZoneLook SKY table, so the 3 s war-sky tween and
-- ZoneLook agree); Eclipse = the night proposal (blood-red mood, monsters still readable).
-- Optional keys (WarService applies them only if present): FogStart, ExposureCompensation, BloomIntensity (otherwise
-- WarService SKY_EXTRAS). 2026-10-08 (검수 style drift #18): Neutral's fog = the sky's horizon colour in the photos
-- (~150, 206, 226 - the old pale 205, 215, 230 drew a grey band where the sea ends) and a slightly warm day tint.
-- 2026-10-08 later (user on the meadow photo: "입체적이지 않아"; 검수: the darkest 10% of our picture was 0.69-0.74 bright vs
-- the concept's 0.41): depth for Neutral - the sun lower (15.3: longer shadows), a darker, cooler shade (Ambient /
-- OutdoorAmbient: the sky fill no longer lights the shadow side flat), a little more sun (Brightness 2.2, exposure
-- -0.05) so the lit side stays bright, the haze closer (FogStart 150, FogEnd 950: far hills fade into the horizon
-- colour). WarService pairs it with sharper shadows (ShadowSoftness 0.15), less sky diffuse, contrast +0.12 and a
-- touch less saturation. Still no Atmosphere (A9-3): it would replace FogColor / FogStart / FogEnd and break the war
-- skies' fog and ZoneLook's zone fog; the closer classic fog does the far haze.
-- user 10/08 (the cloud main's Play) "조명이 전체적으로 밝아" -> one step darker: Neutral exposure -0.05 -> -0.25, Brightness
-- 2.2 -> 2.0, OutdoorAmbient 110,120,135 -> 95,104,118 (shadows and Contrast 0.12 kept). The crown-war skies take the same
-- step (Dawn: -0.2 exposure, Brightness -0.2, OutdoorAmbient x0.87; the Eclipse night only half of it so monsters stay
-- visible); their exposures are now in the presets (WarService / ZoneLook read the preset first). The Halloween fields'
-- moods are ZoneLook factors on this base, so they follow by themselves.
Config.Sky = {
	TweenTime = 3,
	Neutral = { ClockTime = 15.3, Brightness = 2, Ambient = Color3.fromRGB(72, 76, 86), OutdoorAmbient = Color3.fromRGB(95, 104, 118), FogColor = Color3.fromRGB(150, 205, 228), FogStart = 150, FogEnd = 950, ExposureCompensation = -0.25, BloomIntensity = 0.2, Tint = Color3.fromRGB(255, 245, 230) },
	Dawn = { ClockTime = 7.2, Brightness = 1.9, Ambient = Color3.fromRGB(128, 112, 92), OutdoorAmbient = Color3.fromRGB(130, 113, 90), FogColor = Color3.fromRGB(255, 220, 150), FogStart = 120, FogEnd = 650, ExposureCompensation = -0.35, Tint = Color3.fromRGB(255, 240, 200) },
	Eclipse = { ClockTime = 0.5, Brightness = 1.4, Ambient = Color3.fromRGB(100, 62, 78), OutdoorAmbient = Color3.fromRGB(104, 68, 83), FogColor = Color3.fromRGB(90, 10, 20), FogStart = 120, FogEnd = 650, ExposureCompensation = 0.35, Tint = Color3.fromRGB(255, 200, 200) },
}
-- 2026-10-08 (이미지 생성 1 a333f3f, 검수 OK): the painted day sky's six faces for Lighting.Sky (SkyboxFt / Bk / Lf / Rt /
-- Up / Dn; seen from above Ft 0, Rt 90, Bk 180, Lf 270 degrees clockwise; Up has Ft at its bottom - turn Up by 90 if its
-- seam is off, swap Lf / Rt if the sides run backwards; Dn = FogColor 150, 205, 228). No rays; the sun stays Sky_Sun.
-- WarService puts them on Lighting.Sky at Start (an empty / missing face keeps what the place has); the war skies never
-- touch the faces. Lf / Rt swapped (메인 반영 33a77cb8 compare "B": no seam; 검수 10/09 saw the seam in the meadow photo)
Config.Sky.Faces = {
	Ft = "rbxassetid://86737469798577", Bk = "rbxassetid://106230772458054", Lf = "rbxassetid://80981399991828",
	Rt = "rbxassetid://113124022425103", Up = "rbxassetid://139860275275280", Dn = "rbxassetid://111194337613180",
}

-- addendum A9-2: client hit feel (Fx only). White flash of monsters within FlashRadius of my own Swing/Release hit
-- positions for FlashTime (original colours stored once per flash start); crit and my Release numbers pop
-- PopScale -> 1.0 over PopTime; numbers spawned within MergeRadius studs and MergeWindow seconds merge into one label.
-- No hit-stop, no extra screen shake.
Config.HitFeel = { FlashTime = 0.06, PopScale = 1.4, PopTime = 0.1, MergeWindow = 0.25, FlashRadius = 3, MergeRadius = 3 }

----------------------------------------------------------------- golden goose tug ("황금 거위 줄다리기")
Config.Goose = {
	Interval = 600, -- one goose every 10 min...
	OffsetFromWarEnd = 300, -- ...starting 5 min before each war round end (something happens every 5 min)
	Duration = 60,
	Position = Vector3.new(-30, 0, 30), -- Crossroads plaza (safe zone); MapBuilder builds the perch here
	HoverHeight = 4, -- goose body center = Position + (0, HoverHeight, 0)
	HitRadius = 4, -- added to a class's Range when checking whether a swing reaches the goose
	ManualCount = 2,
	AutoCount = 1,
	MaxCountsPerSecond = 3, -- per player (rolling 1 s window); each count is multiplied by the player's faction S
	RewardMinutes = 10, -- winner reward ~ 10 min of hunting at the player's level (Config.HuntValue)
	MainShare = 1.0, -- Halo winners: XP x Main, gold x Off; Horns winners: gold x Main, XP x Off
	OffShare = 0.3,
	LoserShare = 0.4, -- losers (and both sides on a tie) get 40% + 1 cheer star
	CheerStarsForRare = 5, -- 5 cheer stars -> the next golden reward is guaranteed RARE (stars consumed)
	RareMult = 5,
	WinWarPoints = 60,
	Tick = 0.25,
	-- anti-AFK: a reward (and GooseFinished/quest credit) needs this many ACCEPTED manual hits this event; auto hits
	-- still pull but never pay (review fix, kept by A23-14)
	MinManualHits = 3,
	-- A23-14 "함께 구조" (co-op): when the goose lands and only ONE of Halo/Horns has ready players on the server, the
	-- event is co-op for that side for its whole 60 s (fixed at start; a rival joining later cannot pull this time).
	-- Gauge target = CoopPerPerson x that side's ready players at the start (min 1 person). 20 = 10 manual hits per
	-- person (Warrior ~10 s, Mage ~11 s, Archer ~5 s), so one player alone can fill it. A full gauge stays full (totals
	-- never go down) and the event still runs to its timer so late teammates can join. Success = CoopWinShare (70%) of
	-- the winner reward, no war points, no cheer star; a gauge not filled = the tie path (LoserShare 40% + 1 cheer star).
	CoopPerPerson = 20,
	CoopWinShare = 0.7,
	-- English texts (string.format). Mode name: Halo "Team Rescue", Horns "Team Poach" (rescue / poach flavour of GooseStart).
	Text = {
		NeedManual = "Only players who hit the Golden Goose themselves %d+ times get the reward! (Auto Battle hits don't count)", -- (MinManualHits)
		CoopStart = { -- NotifyAll when the event becomes co-op (at start, or when the first faction player appears)
			Halo = "The Golden Goose is in the Crossroads!\nOnly Knights here: Team Rescue. Fill the gauge together!",
			Horns = "The Golden Goose is in the Crossroads!\nOnly the Horn Legion here: Team Poach. Fill the gauge together!",
		},
		CoopFull = { -- NotifyAll once when the gauge is full (MinManualHits)
			Halo = "Gauge full! Team Rescue done.\nHit it yourself %d+ times before the end for a reward!",
			Horns = "Gauge full! Team Poach done.\nHit it yourself %d+ times before the end for a reward!",
		},
		CoopResult = { -- NotifyAll at the end, gauge filled
			Halo = "The Knights worked together and rescued the Golden Goose! The shard shines with light again.",
			Horns = "The Horn Legion worked together and poached the Golden Goose! The shard turned dark.",
		},
		CoopFail = "The gauge wasn't filled, so the Golden Goose flew away!", -- NotifyAll at the end, gauge not filled
		RivalLeft = "The other side all left, so the team rule decides it. %s", -- (CoopResult / CoopFail) tug whose rival left
		RivalWait = { -- to a rival who tries to pull during co-op (once per event), keyed by the CO-OP side
			Halo = "This Golden Goose is the Knights' Team Rescue. From the next goose it's a tug-of-war again!",
			Horns = "This Golden Goose is the Horn Legion's Team Poach. From the next goose it's a tug-of-war again!",
		},
		CoopReward = { -- (gold, xp) personal toast for a co-op success
			Halo = "Team Rescue reward! +%s gold +%s XP",
			Horns = "Team Poach reward! +%s gold +%s XP",
		},
		-- EventHUD labels while GameState GooseActive and GooseMode == "Coop" (side = GooseCoopSide)
		HudTitle = { Halo = "Team Rescue! %s", Horns = "Team Poach! %s" }, -- (time left)
		HudProgress = "%d / %d", -- (side total = GooseRescue for Halo / GoosePoach for Horns, GooseCoopTarget)
		HudPeople = "%d together", -- (GooseCoopPeople)
		HudSub = { -- (my GooseCount) players of the co-op side, gauge not full yet
			Halo = "My points %d · Knights, fill the gauge!",
			Horns = "My points %d · Horn Legion, fill the gauge!",
		},
		HudFull = { -- (my GooseCount, MinManualHits) players of the co-op side, gauge full
			Halo = "My points %d · Rescued! Hit it %d times for a reward",
			Horns = "My points %d · Poached! Hit it %d times for a reward",
		},
		HudOther = { -- the other tug faction during co-op (keyed by the CO-OP side)
			Halo = "This goose is the Knights' Team Rescue",
			Horns = "This goose is the Horn Legion's Team Poach",
		},
	},
}

-- gold, xp of one golden-goose reward. share (optional, A23-14 co-op success) replaces the won/lost multiplier.
function Config.GooseReward(level, factionId, won, rare, share)
	local g, x = Config.HuntValue(level, Config.Goose.RewardMinutes)
	local gm, xm = Config.Goose.MainShare, Config.Goose.OffShare -- Horns shape (gold-heavy)
	if factionId == "Halo" then gm, xm = Config.Goose.OffShare, Config.Goose.MainShare end -- XP-heavy
	local base = won and 1 or Config.Goose.LoserShare
	if type(share) == "number" and share == share and share >= 0 then base = share end
	local m = base * (rare and Config.Goose.RareMult or 1)
	return math.floor(g * gm * m), math.floor(x * xm * m)
end

-- A23-18 "오늘의 운" (replaces the per-server "단골 운" minutes): golden-goose / kaiju events I took part in TODAY
-- (KST day, saved with the day so a server hop or a dropped phone keeps it). 3 events = 11%, 4 events = the 12.5% cap
-- ("15~30분 동안 이벤트 3~4번이면 거의 최대").
-- 검수 2026-10-09 (UI clutter review ④, "show it when it is needed"): the potion pair shows once I hold a potion, my HP
-- fell under LowHP once this session, or from Level on; the pouch line once I carry gold or from Level on
-- (Config.HudReveal.Shows, pure: VitalsUI / HUD and the offline test call it)
Config.HudReveal = { Level = 5, LowHP = 0.5 }
function Config.HudReveal.Shows(kind, s)
	s = type(s) == "table" and s or {}
	local lv = tonumber(s.Level) or 0
	if lv >= Config.HudReveal.Level then return true end
	if kind == "Potions" then
		local hp, maxHP = tonumber(s.HP) or 0, tonumber(s.MaxHP) or 0
		return (tonumber(s.Potions) or 0) > 0 or (maxHP > 0 and hp > 0 and hp < maxHP * Config.HudReveal.LowHP)
	elseif kind == "Pouch" then
		return (tonumber(s.Carried) or 0) > 0
	end
	return true
end

Config.Luck = {
	BaseRare = 0.05,
	PerEvent = 0.02, -- +2 percentage points per event today
	MaxRare = 0.125,
}

function Config.RareChance(eventsToday)
	local n = tonumber(eventsToday) or 0
	if n ~= n or n < 0 then n = 0 end
	return math.min(Config.Luck.MaxRare, Config.Luck.BaseRare + Config.Luck.PerEvent * math.floor(n))
end

Config.Economy = {
	KillsPerMinute = 12, -- reference hunting speed used for event / daily / vacation rewards
}

-- gold, xp of `minutes` of hunting the main monster of the player's level zone (before multipliers)
function Config.HuntValue(level, minutes)
	local zone = Config.QuestZoneForLevel(level)
	local def = Config.MonsterTypes[Config.ZoneMainMonster[zone]]
	local kills = Config.Economy.KillsPerMinute * minutes
	return math.floor(kills * def.Gold), math.floor(kills * def.XP)
end

----------------------------------------------------------------- rebirth ("전향 환생")
Config.Rebirth = {
	BaseLevel = 50,
	PerRebirth = 5,
	MaxLevelReq = 100,
	BonusNormal = 0.25, -- permanent gold & XP bonus added to RebirthBonus per rebirth
	BonusUnderdog = 0.40, -- if the chosen faction has < UnderdogShare of the OTHER faction players
	UnderdogShare = 0.45,
	UnderdogMinOthers = 2, -- the ratio only counts with at least 2 other faction players online
	MarkMax = 5,
	FallGoldPer = 0.05, -- per "타락" mark (Halo -> Horns at rebirth)
	RedeemXPPer = 0.05, -- per "구원" mark (Horns -> Halo at rebirth)
	GrayLegendMin = 3, -- both marks >= 3 -> title "회색 전설" + gray aura
	-- aura by rebirth count (highest matching entry wins); Color nil = faction color
	Auras = {
		{ Min = 1, Color = Color3.fromRGB(205, 127, 50) },
		{ Min = 3, Color = Color3.fromRGB(200, 200, 215) },
		{ Min = 5, Color = Color3.fromRGB(255, 205, 60) },
		{ Min = 10, Color = nil },
	},
}

function Config.RebirthLevel(rebirths)
	return math.min(Config.Rebirth.MaxLevelReq, Config.Rebirth.BaseLevel + Config.Rebirth.PerRebirth * rebirths)
end

-- bonus for rebirthing into a faction that has targetCountOthers of othersTotal OTHER faction players (self excluded)
function Config.RebirthBonusFor(targetCountOthers, othersTotal)
	if othersTotal >= Config.Rebirth.UnderdogMinOthers and targetCountOthers / othersTotal < Config.Rebirth.UnderdogShare then
		return Config.Rebirth.BonusUnderdog
	end
	return Config.Rebirth.BonusNormal
end

----------------------------------------------------------------- zones & map
-- World map v2 (SPEC A23-53, docs/design/world_map_v2_2026-10-06.md + .json; = tools/preview_map.lua): the same order
-- as before, about 2.1x the land. Crossroads in the middle, the Halo / Horns islands north / south across the sea, east
-- the Squishy Meadow -> Goblin Woods -> the mountain pass -> Skeleton Ruins split by two rivers, the Halloween fields
-- south of the meadow. Every zone is now its whole land piece. Ground is Terrain with its top at Y = 0 on land (zone
-- floor parts are invisible, non-colliding contract parts: A11); the sea/river surface is Config.Map.WaterTop. Size.Y is
-- unused (0). Zones are XZ rectangles; first match in ZoneOrder wins; everything else (incl. sea, bridges, the pass)
-- is Outskirts. tools/test_map_v2.py checks these numbers against the v2 layout.
-- A23-30: PumpkinPatch (Season = "Halloween") is its own land south of the meadow; with its season off ZoneAt skips it
-- (that ground reads as Outskirts) and nothing spawns there.
Config.ZoneOrder = { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "PumpkinPatch", "HauntedHollow", "GoblinWoods",
	"SkeletonRuins" }
Config.Zones = {
	-- the Crossroads core (fountain, kit, pads, spawn plaza, potion seller next to the spawn) keeps its v1 place
	Crossroads = { Id = "Crossroads", Name = "Crossroads", Center = Vector3.new(0, 0, 0), Size = Vector3.new(300, 0, 300),
		MinLevel = 1, PvP = false, Town = true, Faction = nil,
		FloorColor = Color3.fromRGB(190, 176, 150), FloorMaterial = Enum.Material.Cobblestone, Spawn = Vector3.new(0, 0, -25) },
	-- the towns: land x -200..200, z -700..-330 / 330..700; the gate at the bridge end, the castle at the far end (z -+630)
	HaloTown = { Id = "HaloTown", Name = "Halo Citadel", Center = Vector3.new(0, 0, -515), Size = Vector3.new(400, 0, 370),
		MinLevel = 1, PvP = false, Town = true, Faction = "Halo",
		FloorColor = Color3.fromRGB(228, 218, 190), FloorMaterial = Enum.Material.Marble, Spawn = Vector3.new(0, 0, -420) },
	HornsTown = { Id = "HornsTown", Name = "Horns Den", Center = Vector3.new(0, 0, 515), Size = Vector3.new(400, 0, 370),
		MinLevel = 1, PvP = false, Town = true, Faction = "Horns",
		FloorColor = Color3.fromRGB(70, 40, 45), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(0, 0, 420) },
	SlimeMeadow = { Id = "SlimeMeadow", Name = "Squishy Meadow", Center = Vector3.new(430, 0, 0), Size = Vector3.new(440, 0, 480),
		MinLevel = 1, PvP = false, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(115, 195, 95), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(230, 0, 0) },
	-- A23-30 (user 2026-10-06 "슬라임은 슬라임만, 고블린은 고블린, 호박은 호박!"): every Halloween kind lives here, a
	-- Lv1-walkable field joined to the meadow's south shore (land x 420..650, z 240..430; the north gate on the pumpkin
	-- path x 535, Config.Map.Halloween)
	PumpkinPatch = { Id = "PumpkinPatch", Name = "Pumpkin Patch", Center = Vector3.new(535, 0, 335), Size = Vector3.new(230, 0, 190),
		MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = "Halloween",
		-- Mud = the pumpkin-soil texture slot (Config.UIArt Tex_PumpkinSoil; Ground is the ruins soil)
		FloorColor = Color3.fromRGB(150, 118, 72), FloorMaterial = Enum.Material.Mud, Spawn = Vector3.new(535, 0, 255) },
	-- A23-45 (user 2026-10-06 "유령은 유령끼리"): the ghost family's own seasonal field west of the PumpkinPatch (land
	-- x 220..420, z 255..430 joined to it, a narrow strait from the meadow), entered through the pumpkin field's west gate
	-- (Config.Map.Halloween.HollowGate). Goblin-woods strength (Lv 8-14 recommended, no level gate), no PvP. Floor:
	-- Asphalt = the Tex_HauntedFloor slot.
	HauntedHollow = { Id = "HauntedHollow", Name = "Haunted Hollow", Center = Vector3.new(320, 0, 342.5), Size = Vector3.new(200, 0, 175),
		MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = "Halloween",
		FloorColor = Color3.fromRGB(118, 106, 150), FloorMaterial = Enum.Material.Asphalt, Spawn = Vector3.new(400, 0, 340) },
	GoblinWoods = { Id = "GoblinWoods", Name = "Goblin Woods", Center = Vector3.new(950, 0, 0), Size = Vector3.new(480, 0, 520),
		MinLevel = 10, PvP = true, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(60, 125, 55), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(730, 0, 0) },
	SkeletonRuins = { Id = "SkeletonRuins", Name = "Skeleton Ruins", Center = Vector3.new(1520, 0, 0), Size = Vector3.new(520, 0, 580),
		MinLevel = 25, PvP = true, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(135, 125, 108), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(1280, 0, 0) },
	-- = Config.Map.Bounds
	Outskirts = { Id = "Outskirts", Name = "Outskirts", Center = Vector3.new(790, 0, 0), Size = Vector3.new(2100, 0, 1440),
		MinLevel = 1, PvP = false, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(130, 165, 100), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(0, 0, -25) },
}

function Config.ZoneAt(pos)
	for _, id in Config.ZoneOrder do
		local z = Config.Zones[id]
		if (z.Season == nil or Config.SeasonOn(z.Season)) -- a seasonal zone exists only while its season is on
			and math.abs(pos.X - z.Center.X) <= z.Size.X / 2 and math.abs(pos.Z - z.Center.Z) <= z.Size.Z / 2 then
			return z
		end
	end
	return Config.Zones.Outskirts
end

function Config.HomeZoneId(factionId)
	if factionId == "Halo" then return "HaloTown" end
	if factionId == "Horns" then return "HornsTown" end
	return "Crossroads" -- "Neutral" (addendum A6) and "None"
end

Config.Map = {
	-- invisible walls only: NEVER a ground plate covering Bounds (it would cover the sea and rivers: A10-V3-1). Map v2:
	-- 60 studs of sea past the lands east / west, 20 past the town ends (= the big map picture UIP_WorldMapV2 covers x
	-- -295..1865, z -720..720). New islands (A23-53 "차차 넓힌다") push these out later.
	Bounds = { MinX = -260, MaxX = 1840, MinZ = -720, MaxZ = 720 },
	WallHeight = 80,
	FountainPosition = Vector3.new(0, 0, 0),
	AltarPosition = Vector3.new(0, 0, 45), -- "운명의 제단": Part named "Altar" + ProximityPrompt "AltarPrompt"
	BoardPosition = Vector3.new(-55, 0, 0), -- "현상수배 게시판": faces +X
	PadSize = Vector3.new(10, 1, 10),
	-- inside Crossroads; touching = instant Travel. CR-M22 (ART_DIRECTION 5): every pad is OFF the east road (RoadCross
	-- |z| <= 8) so walking the road never teleports anyone; safe meadow pad north, both PvP pads south (Horns side).
	-- MapBuilder.ensurePads moves already-built pads to these values; tools/preview_map.lua PADS must match.
	Pads = {
		{ Dest = "SlimeMeadow", Position = Vector3.new(52, 0, -24) },
		{ Dest = "GoblinWoods", Position = Vector3.new(52, 0, 24) },
		{ Dest = "SkeletonRuins", Position = Vector3.new(68, 0, 24) },
	},
	Gates = { -- decorative arches centered on zone borders (map v2: at the bridge ends; MapBuilder moves built ones here)
		{ Zone = "SlimeMeadow", Position = Vector3.new(210, 0, 0) },
		{ Zone = "GoblinWoods", Position = Vector3.new(710, 0, 0) },
		{ Zone = "SkeletonRuins", Position = Vector3.new(1260, 0, 0) },
		{ Zone = "HaloTown", Position = Vector3.new(0, 0, -330) },
		{ Zone = "HornsTown", Position = Vector3.new(0, 0, 330) },
	},
	MaxParts = 1600, -- total map parts budget (decor included); ART_DIRECTION 9 [SPEC] raised it from 450
	WaterTop = -1.2, -- Terrain water surface Y everywhere outside the lands (sea + rivers)
	-- map v2: the rock mountain band between GoblinWoods and SkeletonRuins is LandPass (x 1190..1260); its walkable road
	-- corridor is |z| < PassHalfZ around the crown road, the rest is mountains (tools/preview_map.lua)
	PassX = 1225,
	PassHalfZ = 70,
	-- land pieces (Terrain top at Y = 0, sand beaches, no ridges: the coasts of the big map picture); the rivers x
	-- 150..210 and 650..710 and the sea between them. The two Halloween fields are drawn on the maps only in season.
	Lands = {
		{ Name = "LandCrossroads", MinX = -150, MaxX = 150, MinZ = -150, MaxZ = 150 },
		{ Name = "LandMeadow", MinX = 210, MaxX = 650, MinZ = -240, MaxZ = 240 },
		{ Name = "LandWoods", MinX = 710, MaxX = 1190, MinZ = -260, MaxZ = 260 },
		{ Name = "LandPass", MinX = 1190, MaxX = 1260, MinZ = -260, MaxZ = 260 },
		{ Name = "LandRuins", MinX = 1260, MaxX = 1780, MinZ = -290, MaxZ = 290 },
		{ Name = "IslandHalo", MinX = -200, MaxX = 200, MinZ = -700, MaxZ = -330 },
		{ Name = "IslandHorns", MinX = -200, MaxX = 200, MinZ = 330, MaxZ = 700 },
		{ Name = "LandPumpkinPatch", MinX = 420, MaxX = 650, MinZ = 240, MaxZ = 430, Season = "Halloween" }, -- A23-30, joined to LandMeadow
		{ Name = "LandHauntedHollow", MinX = 220, MaxX = 420, MinZ = 255, MaxZ = 430, Season = "Halloween" }, -- A23-45, joined to the patch's west edge
	},
	-- bridge decks (top at Y = 0) from shore to shore; the built models are workspace.Map.Decor["Bridge_" .. Name]
	Bridges = {
		{ Name = "Meadow", From = Vector3.new(150, 0, 0), To = Vector3.new(210, 0, 0), Width = 22 },
		{ Name = "Goblin", From = Vector3.new(650, 0, 0), To = Vector3.new(710, 0, 0), Width = 22 },
		{ Name = "Halo", From = Vector3.new(0, 0, -150), To = Vector3.new(0, 0, -330), Width = 22 },
		{ Name = "Horns", From = Vector3.new(0, 0, 150), To = Vector3.new(0, 0, 330), Width = 22 },
	},
	-- road strips on land (drawing data for the world map / minimap, A12; built by tools/preview_map.lua as
	-- Decor.Roads). The crown road (z 0, 18 wide) runs from the Crossroads to the ruins; the town roads end at the castles;
	-- one ring road per hunting field. Season roads are drawn only in season (preview_map paints them as soil).
	Roads = {
		{ Name = "RoadCross", MinX = 13, MaxX = 150, MinZ = -9, MaxZ = 9 },
		{ Name = "RoadWest", MinX = -43, MaxX = -13, MinZ = -9, MaxZ = 9 }, -- to the wanted board (BoardPosition)
		{ Name = "RoadMeadow", MinX = 210, MaxX = 650, MinZ = -9, MaxZ = 9 },
		{ Name = "RoadWoods", MinX = 710, MaxX = 1190, MinZ = -9, MaxZ = 9 },
		{ Name = "RoadPass", MinX = 1190, MaxX = 1260, MinZ = -9, MaxZ = 9 },
		-- ends at the crown altar ruin (kit_ruins R_CrownAltar (1700, 0), 30 wide): the crown road leads up to it
		{ Name = "RoadRuins", MinX = 1260, MaxX = 1684, MinZ = -9, MaxZ = 9 },
		{ Name = "RoadNorth", MinX = -8, MaxX = 8, MinZ = -150, MaxZ = -10 },
		{ Name = "RoadNorthIsland", MinX = -8, MaxX = 8, MinZ = -600, MaxZ = -330 },
		{ Name = "RoadSouth", MinX = -8, MaxX = 8, MinZ = 10, MaxZ = 150 },
		{ Name = "RoadSouthIsland", MinX = -8, MaxX = 8, MinZ = 330, MaxZ = 600 },
		-- the layout's z -170 would cross the King Slime Hill (kit_meadow M_KingHill (430, -170), 60 wide): south of it
		{ Name = "RoadMeadowLoop", MinX = 260, MaxX = 600, MinZ = -125, MaxZ = -115 },
		{ Name = "RoadWoodsTrail", MinX = 760, MaxX = 1120, MinZ = -155, MaxZ = -145 },
		{ Name = "RoadRuinsSouth", MinX = 1300, MaxX = 1700, MinZ = 145, MaxZ = 155 },
		{ Name = "RoadPumpkin", MinX = 529, MaxX = 541, MinZ = 9, MaxZ = 330, Season = "Halloween" },
		{ Name = "RoadHollow", MinX = 330, MaxX = 535, MinZ = 335, MaxZ = 345, Season = "Halloween" },
	},
	-- 검수 10/09 (main photo: a dark red-brown band in front of the Crossroads fountain): the town road parts
	-- (Decor.Roads, CanCollide off) are not drawn inside the plaza (PlazaRadius around the fountain: MapBuilder cuts the
	-- part back to the plaza edge, a part fully inside is hidden) and get a light earthy color that the GE_Slate tile
	-- multiplies into a dirt-road look (the old 70,45,45 turned near black-red). Roads above stays the map/minimap data.
	RoadLook = {
		PlazaRadius = 60,
		Parts = {
			RoadSouth = { Color = Color3.fromRGB(150, 115, 105), Material = Enum.Material.Slate },
			RoadSouthIsland = { Color = Color3.fromRGB(150, 115, 105), Material = Enum.Material.Slate },
			RoadNorth = { Color = Color3.fromRGB(170, 150, 130), Material = Enum.Material.Slate },
			RoadNorthIsland = { Color = Color3.fromRGB(170, 150, 130), Material = Enum.Material.Slate },
		},
	},
	-- A23-30 / A23-45 on map v2 (MapBuilder PATCH / HOLLOW, QuestTarget): the pumpkin path along x = PathX from the meadow
	-- road to the patch's north gate (PatchGateZ), the patch's west gate into the HauntedHollow, the road sign at the
	-- path's meadow end (HalloweenService shows it only in season)
	Halloween = { PathX = 535, PatchGateZ = 240, HollowGate = Vector3.new(420, 0, 340), SignPos = Vector3.new(525, 0, 226) },
	SkyCrownPosition = Vector3.new(0, 350, 0), -- A11 "Crown of Balance" landmark floating above Crossroads (radius ~80)
}

Config.Travel = {
	ChannelSeconds = 3,
	PadDebounce = 2,
	ZoneTick = 0.2, -- ZoneService polling interval (CR-H2: 0.5 -> 0.2 so a short teleport hop is sampled)
	Destinations = {
		{ Id = "Home", Name = "Home Town" }, -- resolves to Config.HomeZoneId(faction)
		{ Id = "Crossroads", Name = "Crossroads" },
		{ Id = "SlimeMeadow", Name = "Squishy Meadow" },
		{ Id = "GoblinWoods", Name = "Goblin Woods" },
		{ Id = "SkeletonRuins", Name = "Skeleton Ruins" },
	},
}

-- CR-H2: server-side movement sanity check (ZoneService.IsPlausible / validateMove, run every Travel.ZoneTick).
-- A move is plausible when the flat distance since the last good position <= Humanoid.WalkSpeed * MoveMult * dt + Slack
-- and the rise <= RisePerSec * dt + RiseSlack (falling is never limited). Server-side teleports call
-- ZoneService.MarkTeleported(player, TeleportGrace) first; CharacterSpawned uses SpawnGrace.
-- Enforce = false is LOG-ONLY: suspicious moves are logged (at most once per LogCooldown s per player) and players
-- are never pulled back. Always enforced regardless of Enforce: a travel pad touch counts only when the root is
-- within max(pad.Size.X, pad.Size.Z) / 2 + PadSlack studs of the pad, and Swing / Release ignore zones whose
-- MinLevel is above the attacker's level.
Config.AntiCheat = {
	Enforce = false,
	MoveMult = 1.6,
	Slack = 8,
	RisePerSec = 60,
	RiseSlack = 12,
	TeleportGrace = 1,
	SpawnGrace = 2,
	PadSlack = 4,
	LogCooldown = 10,
}

----------------------------------------------------------------- monsters
Config.Monsters = {
	AIInterval = 0.25,
	AggroRadius = 30,
	LeashRadius = 60, -- from the monster's home point
	AttackRange = 5.5,
	AttackCooldown = 1.5,
	RespawnDelay = 4,
	ContributorWindow = 15, -- every player who damaged it within 15 s gets full rewards
	SpawnInset = 25, -- spawn points are at least 25 studs inside the zone edge
	GoldenChance = 0.04,
	GoldenHPMult = 3,
	GoldenGoldMult = 10,
	GoldenXPMult = 3,
	GoldenColor = Color3.fromRGB(255, 200, 30),
	ReaggroDelay = 3, -- addendum A3-M4: after a target enters a safe zone the monster goes home and cannot re-aggro for 3 s
}

-- addendum A3-M2 / A5-C1: per monster type, target count =
--   min(def.Count + ExtraPerPlayer * max(0, playersInZone - 1), def.Count * MaxZoneMult), total alive <= GlobalCap.
-- Re-evaluated every ReevalInterval s. Lowering the target never despawns living monsters (it only skips respawns).
-- Personal (tutorial) monsters are excluded from these counts, and so are event monsters (the Pumpkin King) and add-on
-- seasonal kinds (Config.MonsterOutsideCap: the little ghosts, at most Count x MaxZoneMult = 6 on top while on).
Config.MonsterDensity ={ ExtraPerPlayer = 2, MaxZoneMult = 2, GlobalCap = 72, ReevalInterval = 5 }

-- addendum A7-1: on each (re)spawn of a non-personal monster, prefer a point 18-28 studs from a "starved" player in
-- def.Zone (fewer than StarvedThreshold monsters within 30 studs; a Rookie first, then the lowest level, then the fewest).
Config.SpawnSpread = { Enabled = true, StarvedThreshold = 2, MinDist = 18, MaxDist = 28, Tries = 6,
	-- 3rd idea round #7: a first-mission hunter (TutorialStep = Tutorial.Steps.Quest in Tutorial.GuideZone) is chosen
	-- first (then a Rookie, then the lowest level, then the fewest monsters near) and gets its slimes 10-18 studs away
	-- (the half circle facing the zone middle) while it has fewer than 3 near; each hunter raises the meadow's
	-- Tutorial.Monster target by Extra (max Count x MonsterDensity.MaxZoneMult) so a lone sprout on a quiet server sees
	-- a new one at once
	Tutorial = { StarvedThreshold = 3, MinDist = 10, MaxDist = 18, Extra = 3 } }

-- seasonal kinds sit right after the base kind of their zone (drop table / UI order); they spawn only while their
-- season is on (Config.MonsterActive / Config.EffectiveMonsterCounts)
Config.MonsterTypeOrder = { "Slime", "PumpkinSlime", "BigSlime", "PumpkinKing", "Goblin", "BatGoblin", "GoblinBrute",
	"GhostMinion", "LittleGhost", "GhostKing", "Skeleton", "SkeletonKnight" }
-- Name = full name (nametag, lore); Short = short name for quest / HUD lines (optional: use `def.Short or def.Name`)
-- Season = Config[Season].Enabled gates the kind; Takes = { [baseKind] = n } slots of a base kind it replaces while on;
-- QuestAs = the kind quests count it as (Config.QuestKind); Float = studs the client hovers it above the floor (no
-- legs: slow bob, no waddle); Boss = event monster (never golden, never respawns, ContributorWindow override).
Config.MonsterTypes = {
	Slime = { Name = "Shard Slime", Short = "Slime", Zone = "SlimeMeadow", Count = 12, HP = 10, Damage = 2, XP = 5, Gold = 3, Speed = 10, Shape = "Slime", Scale = 1.0, Color = Color3.fromRGB(95, 205, 95) },
	BigSlime = { Name = "Slime Prince", Short = "Slime Prince", Zone = "SlimeMeadow", Count = 4, HP = 40, Damage = 4, XP = 18, Gold = 10, Speed = 9, Shape = "Slime", Scale = 1.8, Color = Color3.fromRGB(70, 160, 235) },
	Goblin = { Name = "Shard Thief Goblin", Short = "Goblin", Zone = "GoblinWoods", Count = 10, HP = 90, Damage = 6, XP = 28, Gold = 16, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(110, 170, 70) },
	GoblinBrute = { Name = "Goblin Brute", Short = "Goblin Brute", Zone = "GoblinWoods", Count = 4, HP = 260, Damage = 12, XP = 70, Gold = 40, Speed = 10, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(80, 120, 50) },
	Skeleton = { Name = "Old Kingdom Skeleton", Short = "Skeleton", Zone = "SkeletonRuins", Count = 8, HP = 450, Damage = 14, XP = 65, Gold = 65, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(235, 235, 220) },
	SkeletonKnight = { Name = "Skeleton Knight", Short = "Skeleton Knight", Zone = "SkeletonRuins", Count = 4, HP = 1300, Damage = 24, XP = 170, Gold = 170, Speed = 11, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(120, 120, 140) },
	-- Halloween (Config.Halloween; provisional numbers). A23-45 (user 2026-10-06 "고블린은 고블린끼리, 호박은 호박, 유령은
	-- 유령끼리"): one family per field. PumpkinPatch = pumpkin slimes + the pumpkin king; the bat goblins take 3 goblin
	-- slots in the GoblinWoods (the first plan, woods numbers, counted as goblins); the HauntedHollow = the ghost family
	-- (minions in packs of 3-4, little ghosts, the ghost king), goblin-woods strength.
	PumpkinSlime = { Name = "Pumpkin Slime", Short = "Pumpkin Slime", Zone = "PumpkinPatch", Count = 10, QuestAs = "Slime",
		Season = "Halloween", HP = 14, Damage = 2, XP = 6, Gold = 4, Speed = 10, Shape = "Slime", Scale = 1.1, Color = Color3.fromRGB(255, 150, 40) },
	BatGoblin = { Name = "Bat Goblin", Short = "Bat Goblin", Zone = "GoblinWoods", Count = 3, Takes = { Goblin = 3 }, QuestAs = "Goblin",
		Season = "Halloween", HP = 95, Damage = 6, XP = 30, Gold = 17, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(120, 80, 150) },
	-- Pack = spawned next to a living one of its kind whose pack has fewer than Max (within Radius), else a new pack.
	-- ModelFrom = the custom model used while its own 3D model is not imported yet (scaled by Scale). Heights (Humanoid
	-- shape = 5 x Scale): minion 3, little ghost 5, ghost king 9 (the pumpkin king is 7.5); own models since 2026-10-06.
	GhostMinion = { Name = "Ghost Minion", Short = "Ghost Minion", Zone = "HauntedHollow", Count = 8, Season = "Halloween",
		Pack = { Max = 4, Radius = 7 }, ModelFrom = "LittleGhost",
		HP = 40, Damage = 3, XP = 13, Gold = 7, Speed = 12, Shape = "Humanoid", Scale = 0.6, Color = Color3.fromRGB(190, 220, 255), Float = 1.2 },
	LittleGhost = { Name = "Little Ghost", Short = "Little Ghost", Zone = "HauntedHollow", Count = 4, Season = "Halloween", HP = 70, Damage = 5,
		XP = 24, Gold = 14, Speed = 11, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(220, 215, 255), Float = 1.5 },
	-- miniboss (HalloweenService schedule, never in the regular pool). HP 9000 = about 4 minutes for one Lv 8-12
	-- player with a tier 2-3 weapon, about 70 s for three. Per player DPS (Config.WeaponDamage x class Damage; swing =
	-- 0.5 x D x 1.1 crit avg per SwingInterval; skill = 6 x D every 3 s while MP lasts: 100 MP + 4/s regen, 20 per
	-- cast, mage swings 2 MP), averaged over Lv 8/10/12 x tier 2/3 x the three classes: 50.8 DPS over 240 s (tier 2
	-- ~29, tier 3 ~73), 58.2 DPS over an 80 s fight (the full MP pool counts more). With 75% uptime (walking,
	-- dodging, aim cone): 1 player 50.8 x 0.75 x 240 = 9141 -> 9000 HP; 3 players 9000 / (3 x 58.2 x 0.75) = 69 s.
	PumpkinKing = { Name = "Pumpkin King", Short = "Pumpkin King", Zone = "PumpkinPatch", Count = 0, Boss = true, Season = "Halloween",
		ContributorWindow = 120, -- a 1-2 min fight: everyone who hit it in the last 2 minutes shares the kill
		-- A23-27: paid only with >= RewardMinHits own hits (auto hits count) AND >= RewardMinDamageFrac of MaxHP; below
		-- Lv XPCapBelowLevel the king's XP is capped to one level (Config.XPToNext of the current level)
		RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8,
		HP = 9000, Damage = 8, XP = 300, Gold = 150, Speed = 7, Shape = "Slime", Scale = 2.5, Color = Color3.fromRGB(255, 130, 30) },
	-- A23-45: the ghost family's miniboss, the pumpkin king's rules and numbers (A23-27 safety / reward gate / XP cap,
	-- 5 min stay, nameless lines), 10 minutes after it in the schedule (Config.Halloween.Bosses), HauntedHollow
	GhostKing = { Name = "Ghost King", Short = "Ghost King", Zone = "HauntedHollow", Count = 0, Boss = true, Season = "Halloween",
		ContributorWindow = 120, RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8, ModelFrom = "LittleGhost",
		HP = 9000, Damage = 8, XP = 300, Gold = 150, Speed = 7, Shape = "Humanoid", Scale = 1.8, Color = Color3.fromRGB(200, 190, 255), Float = 2.2 },
}

-- the kind quests / tutorial / story objectives count a kill as (a pumpkin slime counts as a slime)
function Config.QuestKind(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	if type(def) == "table" and type(def.QuestAs) == "string" and Config.MonsterTypes[def.QuestAs] ~= nil then
		return def.QuestAs
	end
	return kind
end

-- quality_ideas ③ monster barks: BarkService picks a line at MonsterService.Moment (Spot / Hit) and its Idle roll and
-- writes it on the monster model (attributes Bark, BarkAt); game dev 1's MonsterLabels shows it in a BillboardGui bubble.
-- A23-74 (user 2026-10-07 "몬스터들이 말하는 건 의성어 의태어나 단어 수준이면 좋겠어"): every line is a sound word or one
-- short word in the monster's own voice - at most 2 words and 12 letters (marks included), English (A23-48), no two
-- kinds share a line. They replace lines_pack §2-2's sentences; kinds and moments stay, so BarkService is unchanged.
-- Cadence: one bark per monster per PerMonster s, per zone per PerZone s.
-- Missing kind -> Config.QuestKind(kind) lines. Golden monsters (Config.Monsters.GoldenChance, incl. the tutorial
-- golden slime) prefer Lines.Golden for EVERY trigger; a trigger Golden lacks falls back to the kind's lines.
-- Lines.Goose is for GooseService (the optional goose barks, lines_pack §2-1: not wired yet; BarkService skips it).
Config.Barks = {
	Enabled = true,
	PerMonster = 12, -- s: at most one bark per monster
	PerZone = 6, -- s: at most one bark per zone (all monsters in it share this)
	Show = 3, -- s the bubble stays up
	MaxDistance = 60, -- studs: bubble visible range
	-- A23-74 (user 2026-10-07 "몬스터마다 다른 말풍선 그려야지"): one bubble art per monster kind, Config.UIArt.Parts
	-- "BarkBubble" .. kind (12 keys). MonsterLabels tries the kind's own key, then its family's key (BubbleFamily = kind ->
	-- family; a kind not listed uses its Config.QuestKind's family; BubbleArt = family -> the family's base monster key),
	-- each only while its Id is uploaded (not "") and it is round (no Slice), then the round code bubble - never the
	-- shared 9-slice BarkBubble (user "말풍선 가로로 길쭉한 거 말고": drawn small its body stays ~2.4 : 1).
	BubbleFamily = { Slime = "Slime", BigSlime = "Slime", PumpkinSlime = "Pumpkin", PumpkinKing = "Pumpkin",
		Goblin = "Goblin", BatGoblin = "Goblin", GoblinBrute = "Goblin", Skeleton = "Skeleton", SkeletonKnight = "Skeleton",
		GhostMinion = "Ghost", LittleGhost = "Ghost", GhostKing = "Ghost" },
	BubbleArt = { Slime = "BarkBubbleSlime", Pumpkin = "BarkBubblePumpkinSlime", Goblin = "BarkBubbleGoblin",
		Skeleton = "BarkBubbleSkeleton", Ghost = "BarkBubbleGhostMinion" },
	LowAt = 0.3, -- HP fraction for Low (once per life)
	IdleEvery = 10, -- s between Idle rolls (no target, a player within IdleNear)
	IdleNear = 40,
	Chance = { Spot = 0.5, Hit = 0.2, Low = 1, Idle = 0.15 },
	Priority = { "Low", "Spot", "Hit", "Idle" }, -- same moment: only the first one speaks
	-- A23-74: sound words (Spot = it sees you, Hit = it is hit, Low = HP below LowAt, Idle = just hanging around)
	Lines = {
		Slime = { -- a happy jelly
			Spot = { "Blub?", "Boing!" },
			Hit = { "Squish!", "Plop!" },
			Low = { "Wobble…", "Blub… blub…" },
			Idle = { "Blub blub~", "Jiggle~" },
		},
		PumpkinSlime = { -- a giggly pumpkin jelly
			Spot = { "Hehe!", "Blub-kin?" },
			Hit = { "Thump!", "Squash!" },
			Low = { "Squelch…", "Too squishy!" },
			Idle = { "Thump thump~", "Hehe~" },
		},
		BigSlime = { -- Slime Prince (A23-84: the big brother; King Slime SlimeKing = the dad): big and royal
			Spot = { "BLOOP!", "Bow! Blub!" },
			Hit = { "SPLOOSH!", "Royal BOING!" },
			Low = { "Royal nap…", "Bloop… zzz" },
			Idle = { "Ahem. BLOOP.", "Big blub~" },
		},
		Goblin = { -- Grab Club: wants everything shiny
			Spot = { "Heh!", "Mine!", "Ooh, shiny!" },
			Hit = { "Hey! Mine!", "Oof!" },
			Low = { "Yikes!", "Eep! Run!" },
			Idle = { "Heh heh.", "Grab grab~" },
		},
		BatGoblin = { -- a squeaky night goblin
			Spot = { "Skree!", "Flap flap!" },
			Hit = { "Eek!", "Skreek!" }, -- A23-74: fits the bat bubble (검수 2026-10-07)
			Low = { "Flap away!" },
			Idle = { "Flap flap~", "Skree~" },
		},
		GoblinBrute = { -- a grumpy goblin with a big sack
			Spot = { "Grrr!", "Sack time!" },
			Hit = { "Hmph!", "Ugh! Sack!" },
			Low = { "Heavy sack…" },
			Idle = { "Big sack~", "Grumble~" },
		},
		Skeleton = { -- a bony guard who lost track of the days
			Spot = { "Rattle!", "Clack clack!" },
			Hit = { "Clank!", "Clack!" },
			Low = { "Clatter…" },
			Idle = { "Rattle~", "Tuesday?" },
		},
		SkeletonKnight = { -- an old knight, always on duty
			Spot = { "Halt!", "Who goes?" },
			Hit = { "CLANG!", "My armor!" },
			Low = { "Shift over?" },
			Idle = { "On duty.", "Clank… yawn." },
		},
		GhostMinion = { -- Team Boo
			Spot = { "Boo!", "Team Boo!" },
			Hit = { "Eep!", "Boo-hoo!" },
			Low = { "Float away!" },
			Idle = { "Boo-boo-boo!", "Hoo-hoo~" },
		},
		LittleGhost = { -- a shy little ghost
			Spot = { "Wooo~", "Boo…?" },
			Hit = { "Tickles!", "Oopsie!" },
			Low = { "Fading…" },
			Idle = { "Floaty~", "Wooo-ooo~" },
		},
		GhostKing = { -- a dramatic ghost king
			Spot = { "OOOH!", "Visitors!" },
			Hit = { "Ow-ooh!", "Hoo-ouch!" },
			Low = { "Ooh… fading…" },
			Idle = { "OOOH~", "Ooh-hoo-hoo~" },
		},
		PumpkinKing = { -- a jolly pumpkin king
			Spot = { "HA-HA!", "Welcome!" },
			Hit = { "HA! Tickles!", "Ho-ho!" },
			Low = { "Candy time!" },
			Idle = { "HA-HA-HA!", "Best patch!" },
		},
		Golden = { -- any golden monster: used first for every trigger
			Spot = { "Bling!", "Shiny me!" },
			Hit = { "My shine!" },
			Low = { "Okay, share!" },
			Idle = { "Burp. Shiny." },
		},
		Goose = { -- GooseService: Spot = appears, Hit = accepted tug (RegisterHit), Idle = hovering,
			-- Low = co-op gauge >= 0.8, or tug-of-war pivot >= 0.8 of the way to either end
			Spot = { "HONK!" },
			Hit = { "Honk?!", "Tug-HONK!" },
			Low = { "Honk… okay!" },
			Idle = { "Honk honk~", "Waddle~" },
		},
	},
}

-- true while a season id (MonsterTypes[*].Season) is on; nil = no season (always on). override = true / false forces
-- every season on / off (tests, previews)
-- the server clock seasons end on (A23-28 HW-13: workspace server time; os.time outside a running place)
function Config.SeasonNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	if ok and type(t) == "number" then return t end
	return os.time()
end

-- Enabled and, when the season has an EndsAt (Unix seconds), before it
function Config.SeasonOn(season, override)
	if season == nil then return true end
	if override ~= nil then return override == true end
	local s = type(season) == "string" and Config[season] or nil
	if type(s) ~= "table" or s.Enabled ~= true then return false end
	return type(s.EndsAt) ~= "number" or Config.SeasonNow() < s.EndsAt
end

-- the kind exists and its season (if any) is on: spawns, drop table rows and HUD lines use this
function Config.MonsterActive(kind, override)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return type(def) == "table" and Config.SeasonOn(def.Season, override)
end

-- true for a seasonal kind that adds its Count on top of its zone instead of taking base slots (no Takes, e.g. the
-- little ghost): MonsterService spawns it to its own Config.MonsterTargets target outside MonsterDensity.GlobalCap, so
-- with the season on the other zones keep the density they have with it off, also when the cap is full
function Config.MonsterOutsideCap(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return type(def) == "table" and def.Season ~= nil and type(def.Takes) ~= "table"
end

-- the kind whose GlobalCap share a kind uses (MonsterService): a seasonal kind that takes slots of one base kind shares
-- that kind's share (pumpkin slimes + slimes get exactly the capped slime count of the season off); else the kind itself
function Config.MonsterCapGroup(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	if type(def) == "table" and type(def.Takes) == "table" then
		local only = nil
		for base in def.Takes do
			if only ~= nil then return kind end -- takes from several kinds: its own share
			only = base
		end
		if type(only) == "string" and Config.MonsterTypes[only] ~= nil then return only end
	end
	return kind
end

-- { [kind] = base count } of the regular pool for every kind in MonsterTypeOrder: an active seasonal kind spawns its
-- Count and takes its Takes slots from the base kinds (the zone's total stays the same); inactive kinds = 0.
-- seasonOn: nil = each season's own Enabled flag, true / false = force every season on / off.
function Config.EffectiveMonsterCounts(seasonOn)
	local out = {}
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if type(def) == "table" then
			out[kind] = Config.MonsterActive(kind, seasonOn) and math.max(0, math.floor(tonumber(def.Count) or 0)) or 0
		end
	end
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if type(def) == "table" and type(def.Takes) == "table" and Config.MonsterActive(kind, seasonOn) then
			for base, n in def.Takes do
				if out[base] ~= nil then out[base] = math.max(0, out[base] - math.max(0, math.floor(tonumber(n) or 0))) end
			end
		end
	end
	return out
end

-- { [kind] = target count } before the GlobalCap split (MonsterService): Config.MonsterDensity per kind,
--   min(count + ExtraPerPlayer * max(0, playersInZone - 1), count * MaxZoneMult) with count = EffectiveMonsterCounts.
-- A seasonal kind that took slots of a base kind shares that kind's growth instead of adding its own, so a zone's
-- total target is the same with the season on as off for every player count (also after the GlobalCap split:
-- Config.MonsterCapGroup); an add-on seasonal kind (Config.MonsterOutsideCap) comes on top, outside the cap.
-- zonePlayers = { [zoneId] = n }.
function Config.MonsterTargets(zonePlayers, seasonOn)
	local dens = Config.MonsterDensity or {}
	local per, mult = tonumber(dens.ExtraPerPlayer) or 2, tonumber(dens.MaxZoneMult) or 2
	local counts = Config.EffectiveMonsterCounts(seasonOn)
	local function grow(count, zone)
		if count <= 0 then return 0 end
		local n = type(zonePlayers) == "table" and tonumber(zonePlayers[zone]) or 0
		return math.min(count + per * math.max(0, (n or 0) - 1), count * mult)
	end
	local out, shared = {}, {} -- shared[base] = target the base kind would have alone (split below)
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if type(def) == "table" and out[kind] == nil then out[kind] = grow(counts[kind] or 0, def.Zone) end
	end
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if type(def) == "table" and type(def.Takes) == "table" and (counts[kind] or 0) > 0 then
			local taken, part = 0, 0
			for base, n in def.Takes do
				local bdef = Config.MonsterTypes[base]
				local full = type(bdef) == "table" and math.max(0, math.floor(tonumber(bdef.Count) or 0)) or 0
				local t = math.min(full, math.max(0, math.floor(tonumber(n) or 0)))
				if t > 0 and Config.MonsterActive(base, seasonOn) then
					if shared[base] == nil then
						shared[base] = grow(full, bdef.Zone)
						out[base] = shared[base]
					end
					local p = math.floor(shared[base] * t / full) -- this kind's slice of the base kind's target
					out[base] = math.max(0, out[base] - p)
					part += p
					taken += t
				end
			end
			out[kind] = part + grow(math.max(0, counts[kind] - taken), def.Zone)
		end
	end
	return out
end

-- Halloween season (2026-10 decision; numbers provisional). Enabled = false: no Halloween kind spawns (their slots go
-- back to the base kinds), no Pumpkin King schedule and no HUD line; everything else is unchanged.
-- HalloweenService runs the Pumpkin King: first FirstDelay s after server start, then every Interval s (counted from
-- the previous appearance) at one of SpawnSpots (meadow corners away from the entrance where the first mission is
-- hunted and from the road, review 2026-10-06); it stays Lifetime s, then leaves when not defeated. GameState:
-- PumpkinKingNextAt (server time of the next appearance, 0 = off), PumpkinKingActive, PumpkinKingEndsAt.
Config.Halloween = {
	Enabled = true,
	-- A23-28 HW-13: the season switches itself off at 2026-11-09 00:00 KST (= 2026-11-08 15:00 UTC) by the server clock:
	-- no seasonal spawns, no king, no PumpkinPatch zone / sign after it. Candy already earned stays in the bag.
	EndsAt = 1794150000,
	King = "PumpkinKing", -- the miniboss kind (Config.MonsterTypes)
	FirstDelay = 360,
	Interval = 1200,
	Lifetime = 300,
	RetryDelay = 10, -- no walkable spot found this time: try again this many seconds later
	SpawnRadius = 12, -- studs around the chosen spot (walkable ground inside the zone, never in solid decor)
	-- A23-30: the king appears in the PumpkinPatch (map v2: x 420..650, z 240..430; entrance from the meadow at the north
	-- gate x 535), in its far half, clear of the giant pumpkin house (585, 370) and the west gate (one spot picked at
	-- random each time)
	SpawnSpots = { Vector3.new(470, 0, 390), Vector3.new(545, 0, 405) },
	-- A23-45: the minibosses HalloweenService runs. Each entry may override FirstDelay / SpawnSpots (and Interval /
	-- Lifetime); Interval, Lifetime, RetryDelay, SpawnRadius and the A23-27 safety are shared. The ghost king comes 10
	-- minutes after the pumpkin king (FirstDelay 360 + 600, both every Interval), in the HauntedHollow.
	-- Key = the GameState prefix (<Key>NextAt / <Key>Active / <Key>EndsAt) and the Config.Announce event prefix.
	Bosses = {
		{ Kind = "PumpkinKing", Key = "PumpkinKing" },
		-- map v2: the hollow's far (west) half, clear of the ghost willow (300, 360)
		{ Kind = "GhostKing", Key = "GhostKing", FirstDelay = 960,
			SpawnSpots = { Vector3.new(260, 0, 300), Vector3.new(255, 0, 400) } },
	},
	-- A23-27: rookies are safe from the king whatever their faction: it never targets or hits a player below
	-- SafeBelowLevel OR with less than SafePlaySeconds played (the PvP Rookie shield is NOT used here). They can still
	-- hit it and share the candy (if they also meet the king's RewardMinHits / RewardMinDamageFrac).
	SafeBelowLevel = 5,
	SafePlaySeconds = 600,
	Tick = 0.5,
	-- EventHUD line (Next / Active take m:ss); kid-safe, no time pressure. A line that names the season says it comes
	-- back every year.
	Text = {
		HudNext = "Pumpkin King in %s", HudNextEn = "Pumpkin King in %s",
		HudActive = "Pumpkin King is here! %s left", HudActiveEn = "Pumpkin King is here! %s left",
		GhostHudNext = "Ghost King in %s", GhostHudNextEn = "Ghost King in %s",
		GhostHudActive = "Ghost King is here! %s left", GhostHudActiveEn = "Ghost King is here! %s left",
		-- the one road sign on the meadow's south shore (MapBuilder; hidden when the season is off). It does not name
		-- the season, so it needs no "comes back every year" line (P10)
		PatchSign = "↓ Pumpkin Patch · pumpkin monsters", PatchSignEn = "↓ Pumpkin Patch · pumpkin monsters",
	},
	-- ⑫ (review 2026-10-06): one line after each king's Appear announcement, by KST day (Day 1 = 2026-10-31)
	-- day = math.floor((Config.SeasonNow() - DayOneStart) / 86400) + 1, clamped 1..#Days
	-- Day 9 GhostKing: string.format(line, count) FIRST (count = both kings' defeats on this server, memory only;
	-- 0 -> GhostKingZero), THEN string.format(Format, Config.MonsterTypes[kind].Short, line). Chat only, no toast.
	-- HalloweenService sends the finished line as Args.Banter of the <Key>Appear broadcast (lines_pack §4); game dev 1's
	-- Announce shows it as the next chat line in that event's Color.
	Banter = {
		DayOneStart = 1793372400, -- 2026-10-31 00:00 KST
		Format = "%s: \"%s\"",
		Days = { -- keys = Config.Halloween.Bosses[i].Key
			{ PumpkinKing = "Happy Halloween! Just so you know, the best king here is me.",
				GhostKing = "Best king? My ribbon says it's me. I made the ribbon." },
			{ PumpkinKing = "My candy pile is taller than the trees in the Haunted Hollow!",
				GhostKing = "Cute pile. Mine has a second pile sitting on top." },
			{ PumpkinKing = "I can bounce from here to the Crossroads in one hop!",
				GhostKing = "I floated there and back twice. You were still bouncing." },
			{ PumpkinKing = "My best candy is gone! Clue: glowy crumbs. Hmm, Ghost King?",
				GhostKing = "Not me! And why is there orange jelly on MY candy?" },
			{ PumpkinKing = "New crown! Bigger than yours. With extra sprinkles!",
				GhostKing = "Mine has a bell on top. It rings when I'm right. Ding!" },
			{ PumpkinKing = "Biggest crown, pile, AND bounce! …So why is it so quiet?",
				GhostKing = "Quiet here too. Nobody plays tag with a king." },
			{ PumpkinKing = "Both sides teamed up on me. They looked like they had fun!",
				GhostKing = "Same here. Teaming up looks fun. …Hey, Pumpkin. Want to try it?" },
			{ PumpkinKing = "Okay, Ghost King. One crown, two kings? It's sticky, but it's big.",
				GhostKing = "Deal. You hold the left side. I hold the shiny side." },
			{ PumpkinKing = "Truce! One big candy party. Ghost King, you bring the music!",
				GhostKing = "Truce! Kings beaten on this server: %d. Fine, you're all invited!" }, -- the only %d (⑭ exception)
		},
		GhostKingZero = "Truce! No kings beaten here yet. Party anyway. Come on in!",
	},
}

-- the "unit" monster used for quest targets / rewards and Config.HuntValue
Config.ZoneMainMonster ={ SlimeMeadow = "Slime", GoblinWoods = "Goblin", SkeletonRuins = "Skeleton" }

function Config.QuestZoneForLevel(level)
	if level >= Config.Zones.SkeletonRuins.MinLevel then return "SkeletonRuins" end
	if level >= Config.Zones.GoblinWoods.MinLevel then return "GoblinWoods" end
	return "SlimeMeadow"
end

----------------------------------------------------------------- first-60-seconds onboarding (addendum A4 / A5)
-- TutorialStep transitions are owned by QuestService. Step 0 waits for the faction guide mission acceptance.
-- After acceptance: step 1 guides the player to the meadow. No personal monster spawns in the safe town.
-- Step 1: HUD guide beam to the GuideZone pad/entrance; entering GuideZone -> step 2. Step 2: pinned quest
-- (first quest-list entry, Id = QuestId, Pinned = true, Slot = nil; sent by the "Quests" remote since CR-L50);
-- claim -> step 99.
-- A23-74 (user 2026-10-07 "맨 손이니까 무기를 제일 먼저 줘야지"): Forge = 3 sits between the acceptance and the hunt for a
-- player without the first weapon: [Accept] -> step 3 (the trip to the Crossroads Forge) -> the anvil prompt hands over
-- the class basic weapon (QuestService.ForgeGift) -> step 1 (the trip to the meadow) -> step 2 -> claim -> step 99.
-- A save that owns the first weapon already (from before A23-34) goes from [Accept] straight to step 1.
Config.Tutorial = {
	Steps = { Kill = 0, Guide = 1, Quest = 2, Forge = 3, Done = 99 },
	Monster = "Slime",
	MonsterHP = 10,
	Golden = true,
	SpawnDistance = 8, -- studs in front of the player's spawn
	Lifetime = 120, -- personal monster despawns after this many seconds (then the tutorial advances to step 1)
	GuideZone = "SlimeMeadow",
	GuideText = "Squishy Meadow", -- the guide label: one short line on a small chip (검수 2026-10-08)
	QuestId = "tutorial",
	QuestKills = 5,
	QuestText = "Free the supply road · %d slimes", -- string.format(QuestText, QuestKills)
	-- ShortName per first-mission row (검수 2026-10-07: the phone HUD quest row; %d = the level the goal needs)
	ShortNames = { Welcome = "Meet %s", Travel = "To the meadow", Quest = "Supply road", Forge = "To the Forge",
		IronLevel = "Reach Lv %d", SkillIron = "Reach Lv %d", IronGold = "Iron weapon", Zone = "Reach Lv %d",
		Skill = "Skill at Lv %d", Rebirth = "Rebirth Lv %d", RebirthReady = "Rebirth ready",
		Commission = "Weapon order", Commission4 = "Golden weapon", Commission5 = "Crystal weapon", Commission6 = "Spirit weapon",
		Clatter = "Capt. Clatter", Crystal = "Crystal weapon" }, -- A23-86 F ladder rows
	-- A23-86 F (content_beyond_10min): the next-goal ladder once the early goals (iron weapon, first skills, the woods) are
	-- done and no story row is pinned. Hooks, in order: a feature row asks its service for its line (S[Service].NextGoal(
	-- player, data) -> text or nil) and only while Config.Features[Feature] is on (the features are not built yet, so the
	-- rows wait switched off); then the rebirth line from Warn levels below the rebirth level. No clock, no minute numbers,
	-- no purchase or 2x button near it (A23-79).
	Ladder = {
		Hooks = {
			{ Kind = "Commission", Service = "CommissionService", Feature = "Commission" },
			{ Kind = "Clatter", Service = "ClatterService", Feature = "Clatter" },
			{ Kind = "Crystal", Service = "CrystalService", Feature = "Crystal" },
		},
		Rebirth = { Warn = 5 },
	},
	QuestRewardGold = 150, -- A23-3: enough for the wood weapon (150); buying stays optional
	QuestRewardXP = 0,
	-- F10-4 safety net (2026-10-06): a 5/5 first mission left unclaimed this long (counted from when this server
	-- first sees it, also right after a rejoin) is paid automatically with Text.AutoClaimed. [받기] still comes first.
	AutoClaimSeconds = 60,
	-- A23-68 (user 2026-10-07, early churn): RespawnInMeadow: while the first mission runs (accepted, not claimed) a KO
	-- respawns at the meadow entrance; #4 FoldOthers: until the first [Claim] every other quest-list row is sent with
	-- Folded = true (kept, only its line is folded). A23-88 (user 2026-10-09): the server never moves the player by itself
	-- any more (the old [Accept] -> Forge / meadow trips are gone); walking to the Forge and the travel pad are the lessons.
	RespawnInMeadow = true,
	FoldOthers = true,
	-- A23-88: Near = how close to the Crossroads anvil counts as "arrived" (the walked_to_forge metric: Custom event
	-- ForgeWalk, the seconds since [I'm In!]); the step itself ends when the blacksmith hands over the first weapon.
	Forge = { Near = 24 },
	WelcomeRate = 0.5,
	-- ⑪ (lines_pack §1): Name = the guide's own name (speaker / nametag line 1), Title = the role (nametag line 2; quest,
	-- help and system lines keep the role). The catchphrase is its own first line, once a dialogue.
	Welcome = { -- existing approved faction/class portrait; no world NPC is spawned by this dialogue
		Halo = {
			Name = "Hallie", Title = "Guide of Light",
			Lines = { -- 3rd idea round #2: page 1 = the mission card (검수 2026-10-07), then the catchphrase
				"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.", -- A23-74: weapon first
				"Hallie here! Now you know my name. Welcome to the Knights!",
				"Thank you for joining the Knights of Light. Big oaths can wait. Right now, we need your help.",
				"The Crown of Balance broke. Its shards drew slimes onto the Squishy Meadow road.",
			},
		},
		Horns = {
			Name = "Magpie", Title = "Horn Legion Guide",
			Lines = {
				"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.", -- A23-74: weapon first
				"Finders keepers! HA! You're with us now. I'm Magpie.",
				"Welcome, rookie! Thanks for joining us. Before we take over the world… let's save the Legion's lunch.",
				"Slimes chasing Crown Shards took the Squishy Meadow road. No food gets through!",
			},
		},
		Neutral = {
			Name = "Kit", Title = "Guild Guide",
			Lines = {
				"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.", -- A23-74: weapon first
				"Fix first. Talk later. I'm Kit. Welcome to the Guild!",
				"Thank you for joining the Artisan Guild. Wars aren't won with swords alone. Someone has to fix those swords too.",
				"Slimes drawn to the Crown Shards have blocked the supply road in the Squishy Meadow.",
			},
		},
	},
	Text = {
		FirstFight = "Pick a class, then get your first mission from the Guide.",
		-- A23-40: the guide is met by tapping this quest line (the menu moved to the top-right fold)
		-- 3rd idea round #3: %s = the faction guide's name (Welcome[faction].Name), there is no guide NPC to look for
		Welcome = "Tap here: first quest from %s", WelcomeEn = "Tap here: first quest from %s",
		Travel = "Travel to Squishy Meadow — step on the glowing travel pad (or Map → Travel)", -- A23-88
		QuestStart = "First mission: %s! (Reward: %s gold)",
		QuestReady = "Supply road mission done! Press [Claim].",
		-- A23-74: the Forge step (3): its row, and Otto's line when he hands over the first weapon (then LootService's
		-- "You got your first weapon" line with the power change)
		Forge = "Go to Otto's Forge", -- A23-88: walking; Otto hands over the first weapon
		ForgeGift = "Otto: Clang, clang… done. Here's your first weapon! The Squishy Meadow is next.",
		-- A23-74: the first weapon is in hand already, so QuestRewardGold (150) is the NEXT weapon's price (tier 2 at Lv1);
		-- the M1_1 visit (show the jelly) opens the weapon shop right after Otto's lines
		Claimed = "Thanks for guarding the supply road! +%s gold. That buys a new weapon at the Forge!",
		ClaimedEn = "Thanks for guarding the supply road! +%s gold. That buys a new weapon at the Forge!",
		AutoClaimed = "Your first mission reward, +%s gold, is in your vault! That buys a new weapon at the Forge!",
		AutoClaimedEn = "Your first mission reward, +%s gold, is in your vault! That buys a new weapon at the Forge!",
		-- the row after the claim while still bare-handed (no story row yet; A23-74 gives the weapon before that)
		VisitBlacksmith = "Get your first weapon · Crossroads Forge",
		VisitBlacksmithEn = "Get your first weapon · Crossroads Forge",
		-- the claim lines for a save that owns a better weapon than the first one already (no "new weapon" promise); the
		-- VisitBlacksmithArmed row is for a save that owns the first weapon (no first-weapon promise)
		ClaimedArmed = "Thanks for guarding the supply road! +%s gold. Check the gear at the Crossroads Forge.",
		ClaimedArmedEn = "Thanks for guarding the supply road! +%s gold. Check the gear at the Crossroads Forge.",
		AutoClaimedArmed = "Your first mission reward, +%s gold, is in your vault! Check the gear at the Crossroads Forge.",
		AutoClaimedArmedEn = "Your first mission reward, +%s gold, is in your vault! Check the gear at the Crossroads Forge.",
		VisitBlacksmithArmed = "Check the weapons · Crossroads Forge",
		VisitBlacksmithArmedEn = "Check the weapons · Crossroads Forge",
		-- A23-3: next goal after the blacksmith visit (computed from existing state only; no new reward)
		NextIronLevel = "Next goal · Iron weapon at Lv%d (now Lv%d)",
		-- A23-71 D6 / S16: the first skill comes at the iron weapon's level (Skills.Unlock.Q = Weapons[3].MinLevel), one line
		NextSkillIron = "Next goal · Lv%d: first skill + Iron weapon (now Lv%d)",
		NextIronGold = "Next goal · Iron weapon for %s gold (you have %s)",
		NextZone = "Next goal · Lv%d opens %s (now Lv%d)",
		NextSkill = "Next goal · New skill at Lv%d (now Lv%d)", -- SKL-3 (skill_kit §2): the next skill to learn
		-- A23-86 F (content_beyond_10min): the ladder when no story row is pinned (after the last chapter, after a rebirth)
		NextRebirth = "Next goal · Lv%d: Rebirth, choose your side again (now Lv%d)",
		NextRebirthReady = "Next goal · Rebirth is open! Choose your side again",
		RebirthNoteHalo = "Stay a knight, or not?", -- a second line under the rebirth goal, by side
		RebirthNoteHorns = "Stay a rascal, or not?",
		GuideDone = "That's all from me! Now hunt and get stronger.",
		DailiesOpened = "Daily quests are open! Try them along with your first mission.",
	},
}

----------------------------------------------------------------- story quests "부서진 왕관 이야기" (user OK 2026-10-06)
-- Design: docs/design/quest_chain_2026-10-06.md (decisions 1-8 = recommended). Main = one chain after the first
-- mission (TutorialStep 99); Subs are accepted automatically and listed under the main row (S0 right after the
-- class pick). Step Obj types (StoryQuestService): Kill{Kind,Zone,Golden,Near,Radius,Count} BasicKill SafeKill{MinHP}
-- AutoKill SkillHit{Min,Count} WarPoints{Count} EarnGold{Source,Count} Enter{Zone|"OwnTown"|"AnyTown"} Level{Level,
-- Skill = also done once the first skill is learned (A23-71)}
-- State{Key: BlacksmithVisited | AutoOn | OwnIron | Graduated (E7: no Sprout Shield)} Goose WarChest Talk
-- Choice{Good,Evil,Neutral} Trials{List; a list entry may carry Say = a line when it is done} Near{Spot,Radius,Zone,Stay}.
-- Reward.Item = a Loot item id (+ N) is given through LootService.GrantItem when the quest ends. Rewards: Gold / XP
-- = minutes of Config.HuntValue (1 = one minute of hunting), GoldN = exact gold, XPBar = a share of the current level's
-- XP bar; Claim = true -> the player presses [Claim] (chapter ends).
-- A23-46 / story_depth E4 + E6 (게임성 개발 2, 2026-10-07): Near.Stay = seconds to stay inside in one go (leaving
-- resets; the row shows "%d/%d s"); Choice.Good / .Evil.Reward = { Item = Loot item id | Potion = "HP" | "MP", N,
-- Gold } paid on that pick (a Neutral A takes Good's, B takes Evil's); a step with Npc = id is talked through that town
-- NPC: game dev 1 tags its model CollectionService "StoryNpc" (NpcTag) with the attribute NpcId = id, and Talk / Choose
-- / Open then need the player within NpcRange of it (before the NPC exists in the world, anywhere).
-- story_depth E1 / E2 / E3 / E5 (게임성 개발 2, 2026-10-07). A pick's side: Good / Purify / A = "Good", Evil / Devour / B
-- = "Evil". E1 Requires.Pick = { Id, Is }: Is "Good" / "Evil" = that side of the saved pick of Id, else the exact pick.
-- E2 step.LinesBy = { From = id, Good, Evil, A, B, Default } (each entry shaped like Lines: All / Halo / Horns / Neutral):
-- the server sends Var = the exact pick of From when listed, else its side, else "Default" (OpenPanel "Story" payload
-- and row.Story.Var); every LinesBy needs a Default (old saves have no picks). A real pick (its Choice carries points)
-- on the other side from the last real pick adds one line (ChangedGood / ChangedEvil). E3 Reward.Title = a
-- Config.TitleDefs id, or Reward.TitleBy = { Good = id, Evil = id } by the side of this quest's own pick (TitleService,
-- no stats). E5 Hidden = true (a sub): no Start toast and no row until it is found (past its first step or waiting for
-- [Claim]); a Choice with Points = 0 leans the shard (LeanGood / LeanEvil) instead of a score line.
Config.StoryQuests = {
	MaxSubs = 3, -- sub rows sent with the quest list (after the main row); the HUD shows 2, the open list all (quest_volume §2-6)
	-- map v2: the slime pond in the meadow's south-west (kit_meadow M_Pond, 50 wide)
	Landmarks = { SlimePond = Vector3.new(290, 0, 150), Fountain = Vector3.new(0, 0, 0) },
	Speakers = { Shard = "Crown Shard", Fountain = "Fountain Shard", Smith = "Otto", Guild = "Kit", Potion = "Fizzby", -- ⑪
		Bright = "Bright", Smokey = "Smokey", Tiny = "Tiny", Kids = "Bright & Smokey", -- A23-46 town NPCs, A23-55 kids
		Pip = "Pip", Dibs = "Dibs", Grabbo = "Grabbo", -- story_depth §4 goblins (beta: names only, no models)
		Gleam = "Sir Gleam", Rex = "Rascal Rex" }, -- story_depth §4 (beta: names only)
	-- 검수 2026-10-07: the Story window shows the speaker's face (a Config.UIArt.Parts key) in the PortraitFrame left of
	-- the words. Halo / Horns / Guild = no Speaker, my faction's guide; the crown shard and the fountain shard share
	-- PTR_CrownShard (94207f5). A speaker missing here or whose art id is empty (Kids, the goblins, Gleam, Rex) gets no
	-- portrait slot.
	Portraits = { Smith = "PortraitMerchantC", Potion = "PortraitPotionMerchant", Bright = "PTR_TownBright",
		Smokey = "PTR_TownSmokey", Tiny = "PTR_TownTiny", Guild = "PortraitGuideArtisan", Halo = "PortraitGuideHalo",
		Horns = "PortraitGuideHorns", Shard = "PTR_CrownShard", Fountain = "PTR_CrownShard" },
	NpcTag = "StoryNpc",
	NpcRange = 16, -- studs between the player and a quest NPC for Talk / Choose / Open
	Badge = { Main = "Main", Sub = "Side" },
	Main = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7",
		"M3_1", "M3_2", "M3_3", "M3_4", "M3_6", "M3_7", "M3_8" }, -- A23-86: M3_5 (graduation) is a side line now
	-- story_depth E0: an old save that reaches the story at Level >= Level skips the main chapters <= UpTo (once)
	SkipChapters = { { Level = 10, UpTo = 2 }, { Level = 25, UpTo = 3, Subs = { "M3_5" } } }, -- A23-86: M3_5 is a sub now
	-- user 2026-10-06: basic weapons are simply bought at the blacksmith (no "buy the iron weapon" quest); rare gear
	-- comes from quests, the crafter and monster drops
	Subs = { "S0", "Lunch1", "S1", "S2", "S3", "S4", "N1", "N2", "H1", "R1", "N3", "Pip1", -- quest_volume §3-2 (A23-56) below:
		"S6", "XR1", "H2", "R5", "GW1", "H3", "R3", "GW2", "GW3", "H5", "R6", "GW4", "GW5", "GW6", "GW7", "H6", "R7", "GW8",
		"SK1", "SK2", -- SKL-3: the practice subs of a new skill
		"WB1", -- A23-86 Call of the Woods: the lantern on the woods bridge
		"M3_5", "OathH", "OathR" }, -- A23-86 Sprout Oath: the graduation side line + one oath a side
	Text = {
		Claim = "%s done! Press [Claim].",
		Done = "%s done!",
		Reward = "%s done! +%s gold",
		RewardXP = "%s done! +%s gold · +%s XP",
		RewardOnlyXP = "%s done! +%s XP",
		Unlocked = "Auto Battle unlocked! Turn it on or off with {Auto} (phone: the Auto button).", -- {Auto}: BB1 key token (server fills)
		Good = "The shard leans toward the light (Honor +%d)",
		Evil = "The shard leans toward the dark (Infamy +%d)",
		Recorded = "Your choice is saved.",
		-- shown under the two choice buttons on the last page (what a pick does, before picking)
		-- A23-58: picking against your own side lowers your own score (ChoiceHint keeps its two-number call; the
		-- faction lines are what a client should show)
		ChoiceHint = "Left: the angel side. Right: the devil side. Picking against your side lowers your score!",
		ChoiceHintHalo = "Left: Honor +%d · Right: Honor -%d (not very angel-like)", -- (Good.Points, Evil.Points)
		ChoiceHintHorns = "Left: Infamy -%d (too nice) · Right: Infamy +%d", -- (Good.Points, Evil.Points)
		ChoiceHintNeutral = "The Artisan Guild just saves your pick, with no good or evil points.",
		OffSideHalo = "Hallie: Hmm… not very angel-like! Honor -%d", -- A23-58 (points actually taken), ⑪ the guide says it
		OffSideHorns = "Magpie: Too nice for a devil! Your call. Infamy -%d",
		-- 3rd idea round #5: the same pick at 0 points (nothing to take) + the lean line after it
		OffSideHaloZero = "Hallie: Hmm… not very angel-like!", OffSideHornsZero = "Magpie: Too nice for a devil!",
		RankDownHalo = "Your rank went down. Do good deeds to get it back!",
		RankDownHorns = "Your rank went down. Do devilish deeds to get it back!",
		GooseFirstHalo = "Your first Golden Goose rescue! (Honor +%d)",
		GooseFirstHorns = "Your first Golden Goose poach! (Infamy +%d)",
		Next = "Next",
		Ok = "Got it",
		Later = "Later",
		Title = "%s · %s",
		ChoiceGold = "+%s gold", -- E6: a pick's own reward line ("+Enhance Scroll 70%" / "+HP Potion ×3 · +60 gold")
		LeanGood = "Your shard leaned to the light.", -- E5: a 0-point pick (no score)
		LeanEvil = "Your shard leaned to the dark.",
		ChangedGood = "You kept it last time. Now you give. People change. Shards too.", -- E2 (story_depth §7)
		ChangedEvil = "You gave it last time. Now you keep. Shards change too.",
		NewTitle = "New title: %s!", -- E3 (a stat-free title)
		SkillLater = "%s · Skills come at Lv%d", -- A23-71: a skill step before the first skill (the row, %s = its text)
	},
	Defs = {
		-- S0 (A23-2): the shard that fell in front of me in the opening was swallowed by a Slime Prince (A23-84)
		S0 = {
			Kind = "Sub", Title = "The Shard That Learns to Fight", ShortName = "Learn to fight", Speaker = "Shard", Requires = { ClassChosen = true },
			Steps = {
				{ Text = "Beat a Slime Prince and find the shard %d/%d", Guide = "SlimeMeadow",
					Start = "A Slime Prince swallowed a shard! Beat it to free the shard.",
					Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 1 } },
				{ Text = "The shard's test %d/3", Guide = "SlimeMeadow", Start = "Shard: Show me how you fight!",
					Obj = { Type = "Trials", List = {
						{ Key = "a", Type = "BasicKill", Kind = "Slime", Count = 3 },
						{ Key = "b", Type = "SkillHit", Min = 2, Count = 1 },
						{ Key = "c", Type = "SafeKill", Kind = "BigSlime", MinHP = 0.5, Count = 1 },
					} } },
				{ Text = "What will you do with the shard?", Panel = true,
					Lines = { All = { "I saw it all! Now I can fight like you.", "What will you do with me?" } },
					Obj = { Type = "Choice", Good = { Label = "Purify it", Points = 2, Pick = "Purify" },
						Evil = { Label = "Devour it", Points = 2, Pick = "Devour" },
						Neutral = { A = "Purify it", B = "Devour it" } } },
			},
			Unlock = "AutoCombat",
		},
		-- A23-70 (user 2026-10-07 "아 좋다"): the first good / evil moment, one small card right after the first [Claim]
		-- (Pop = the card opens by itself once). No score either way (Points 0: the shard leans, the Choice sound and the
		-- afterglow answer); every side may press both buttons. Reply = the kid's line after the pick. Then the Forge row.
		Lunch1 = {
			Kind = "Sub", Title = "Lost Lunchbox!", ShortName = "Lost lunchbox", Pop = true,
			Requires = { TutorialDone = true, NotDone = { "M1_1" } },
			Steps = {
				{ Text = "Return the lunchbox, or take a bite?", Panel = true,
					Lines = { All = { "A slime dropped a lunchbox. It belongs to a kid at the Crossroads." } },
					Obj = { Type = "Choice",
						Good = { Label = "Give it back", Points = 0, Pick = "GiveBack", Reply = "Thank you! Here, take this potion.",
							Reward = { Potion = "HP", N = 1 } },
						Evil = { Label = "One bite!", Points = 0, Pick = "Bite", Reply = "Yum! ...Nobody saw that, right?",
							Reward = { Gold = 25 } },
						Neutral = { A = "Give it back", B = "One bite!" } } },
			},
		},
		-- SKL-3 (skill_kit §2): practice a new skill right after learning it. Requires.Skill = that skill is learned (its
		-- switch on and the slot open: Z at Skills.Unlock.Z, X at Unlock.X). SkillHit Slot = only that skill's casts count
		SK1 = {
			Kind = "Sub", Title = "A New Move", ShortName = "New move", Speaker = "Shard", Requires = { Skill = "Z" },
			Start = "Shard: A new move! Try it on a group.",
			Steps = { { Text = "Hit 2 monsters at once with your new skill %d/%d", Obj = { Type = "SkillHit", Slot = "Z", Min = 2, Count = 1 } } },
			Reward = { Gold = 1 },
		},
		SK2 = {
			Kind = "Sub", Title = "The Shard's Gift", ShortName = "Shard's gift", Speaker = "Shard", Requires = { Skill = "X" },
			Start = "Shard: You grew strong. Come to the Crossroads fountain.",
			Steps = {
				{ Text = "Go to the Crossroads fountain (tap for directions)", Guide = "Fountain",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 22, Zone = "Crossroads" } },
				{ Text = "How will you use your power?", Panel = true,
					Lines = { All = { "You grew strong. Your side's power woke up in you.\nHow will you use it?" } },
					Obj = { Type = "Choice",
						Good = { Label = "Guard my friends", Points = 1, Pick = "Guard" },
						Evil = { Label = "Take what I want", Points = 1, Pick = "Take" },
						Neutral = { A = "Build things", B = "Fix things" } } },
				{ Text = "Hit monsters with your new skill %d/%d", Obj = { Type = "SkillHit", Slot = "X", Min = 1, Count = 3 } },
			},
			Reward = { Gold = 1 },
		},
		-- A23-34: GiveWeapon = the blacksmith gives the class basic weapon (tier 1) once (LootService.GrantFirstWeapon)
		-- A23-74: the first weapon now comes before the hunt (Tutorial.Steps.Forge), so GiveWeapon is only the safety net
		-- (owning tier 1 is the record: a no-op then). The visit is the next-weapon moment (the shop opens after the
		-- lines; the first mission's 150 gold buy tier 2), and the quest pays like its chapter-1 siblings
		M1_1 = {
			Kind = "Main", Chapter = 1, Title = "Sparkly Jelly", ShortName = "Slime jelly", Speaker = "Smith", GiveWeapon = 1,
			Steps = { { Text = "Show the jelly to the Blacksmith", Guide = "Blacksmith", Obj = { Type = "State", Key = "BlacksmithVisited" } } },
			Finish = "Otto: Clang, clang… done. Cocoa time.\nOtto: That's Crown Shard dust! The Slime Princes ate the most of it.\nOtto: Big brothers always grab the biggest bite!",
			Reward = { Gold = 1 },
		},
		M1_2 = {
			Kind = "Main", Chapter = 1, Title = "The Prince Who Ate the Dust", ShortName = "Slime Princes",
			Start = "Slime Princes full of shard dust guard their little brothers and sisters.",
			Steps = { { Text = "Slime Princes %d/%d", Guide = "SlimeMeadow", Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2 } } },
			Finish = "Dust spills out! …And a braided band? Gold and purple.", Reward = { Gold = 1 },
		},
		-- A23-71: the first skill comes at Lv5 (Level = Config.Skills.Unlock.Q), so the step before waits for it. Skill =
		-- the step is also done once Q is learned below that level (slots kept after a free class change resets the level).
		-- S8: the Level step's own Start is said when the quest starts below Lv5; at Lv5+ the step passes at once and the
		-- skill step's Start is said instead.
		M1_3 = {
			Kind = "Main", Chapter = 1, Title = "Boom, All at Once!", ShortName = "Skill boom",
			Steps = {
				{ Text = "Lv5 · Learn your first skill (now Lv%d)", ShortName = "Reach Lv 5", Guide = "SlimeMeadow",
					Start = "Grow to Lv5 to learn your first skill!", Obj = { Type = "Level", Level = 5, Skill = true } },
				{ Text = "Hit monsters with a skill %d/%d", Guide = "SlimeMeadow", Start = "Dusty slimes move in groups. Skills use MP!",
					Obj = { Type = "SkillHit", Min = 1, Count = 3 } },
			},
			Reward = { Gold = 1 },
		},
		M1_4 = {
			Kind = "Main", Chapter = 1, Title = "Report to Your Side", ShortName = "Report home", Claim = true,
			Steps = {
				{ Text = "Go to your town", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "OwnTown" } },
				{ Text = "Report to the Guide", Panel = true, Obj = { Type = "Talk" }, Lines = {
					Halo = { "Hallie here! Now you know my name.", "Did you see the statues on the Heroes' Road? They are the knights who guarded the shards.",
						"They say a Horn broke the Crown. Pure greed!\nBroken things get fixed. Right?",
						"More shards are out there.\nWhat will you do with the next one?" },
					Horns = { "Finders keepers! HA!", "See the lava cracks? Our horn power boils up from there!",
						"They say a Halo broke it. So greedy. Typical!\nShiny! Finders keepers!",
						"More shards are out there.\nWhat will you do with the next one?" },
					Neutral = { "Fix first. Talk later.", "Nice dust. The guild doesn't grab, it shapes.",
						"More shards are out there.\nWhat will you do with the next one?" },
				} },
			},
			Reward = { Gold = 2, XP = 2 },
		},
		M2_1 = {
			Kind = "Main", Chapter = 2, Title = "The Crown in the Sky", ShortName = "Crown points",
			Start = "The sky crown glows for the side with more shards.\nEach monster you beat = 1 point for your side!",
			Steps = { { Text = "Crown points %d/%d", Obj = { Type = "WarPoints", Count = 15 },
				Neutral = { Text = "Supply gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 45 } } } },
			Reward = { Gold = 1 },
		},
		M2_2 = {
			Kind = "Main", Chapter = 2, Title = "Sparkles in the Pond", ShortName = "Pond slimes",
			Start = "They say the dust melted into the pond. The pond slimes look fishy.",
			Steps = { { Text = "Pond slimes %d/%d", Guide = "SlimePond",
				Obj = { Type = "Kill", Kind = "Slime", Near = "SlimePond", Radius = 40, Count = 4 } } },
			Reward = { Gold = 1 },
		},
		M2_3 = {
			Kind = "Main", Chapter = 2, Title = "The Fountain of Balance", ShortName = "The fountain", Speaker = "Fountain",
			Start = "They say a Crown Shard is stuck in the Crossroads fountain. Go look!\n(Tap the quest line for directions)",
			Steps = {
				-- user 2026-10-05 ("균형의 분수가 뭐야? 튜토리얼이 없어서 엥?"): walk up to the fountain, then talk
				{ Text = "Go to the Crossroads fountain (tap for directions)", Guide = "Fountain",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 22, Zone = "Crossroads" } },
				{ Text = "Talk to the Fountain Shard", Panel = true,
					Lines = { All = {
						"I'm a Crown Shard, stuck in this fountain since the sky crown broke.\nHalos and Horns tell the same story. They just swap who did it.",
						"The sparkly dust you got from the pond slimes? That's crown dust.",
						"Give the dust to the fountain: the world leans to the light.\nKeep it: it leans to the dark. What will you do?",
					} },
					Obj = { Type = "Choice", Good = { Label = "Give it to the fountain", Points = 2 }, Evil = { Label = "Keep it", Points = 2 },
						Neutral = { A = "Shape it and give it back", B = "Leave it with the guild" } } },
			},
			Reward = { Gold = 1 },
			Finish = "Two kids by the fountain. They see you and run… opposite ways.", -- story_depth §2-1 (no speaker)
		},
		M2_4 = {
			Kind = "Main", Chapter = 2, Title = "Supply Road Fund", ShortName = "Road fund",
			Start = "Collect gold to fix the supply road. Walk into a town and it goes into your vault!",
			Steps = {
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 60 } },
				{ Text = "Put it in the town vault", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "AnyTown" } },
			},
			Reward = { Gold = 1 },
		},
		M2_5 = {
			Kind = "Main", Chapter = 2, Title = "The Dusty Slime Swarm", ShortName = "Slime swarm",
			Start = "The dust smell brings a slime swarm! Gather them and hit them all at once!",
			Steps = {
				{ Text = "Lv5 · Learn your first skill (now Lv%d)", ShortName = "Reach Lv 5", -- A23-71 (Skill: see M1_3)
					Obj = { Type = "Level", Level = 5, Skill = true } },
				{ Text = "Hit 3 with one skill %d/%d", Guide = "SlimeMeadow", Obj = { Type = "SkillHit", Min = 3, Count = 2 } },
			},
			Reward = { Gold = 1 },
		},
		M2_6 = {
			Kind = "Main", Chapter = 2, Title = "Little Footprints on the Hill", ShortName = "Hill tracks",
			Start = "The Slime Prince dust is gone. Little footprints lead to the woods…",
			-- A23-86 "Call of the Woods" (content_beyond_10min A): from Lv10 the woods can fill this step too (Alt.Pairs = a
			-- kind AND its zone that count as well: Goblin Brutes in the Goblin Woods), so a Lv10 hunter is not tied to the
			-- meadow. AltText is the row from that level.
			Steps = { { Text = "Slime Princes %d/%d", Guide = "SlimeMeadow",
				AltText = "Slime Princes or Goblin Brutes %d/%d",
				Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2,
					Alt = { MinLevel = 10, Pairs = { { Kind = "GoblinBrute", Zone = "GoblinWoods" } } } } } },
			Finish = "Goblins stole the dust!", Reward = { Gold = 1 },
		},
		M2_7 = {
			Kind = "Main", Chapter = 2, Title = "A Call From Beyond the Woods", ShortName = "To the woods", Claim = true,
			Steps = {
				{ Text = "Lv10 · Goblin Woods (now Lv%d)", Obj = { Type = "Level", Level = 10 } },
				{ Text = "Hear the Guide's warning", Panel = true, Obj = { Type = "Talk" }, Lines = {
					All = { "A Crown Shard calls from beyond the woods. Watch out for thieves!",
						"In the woods, others can steal the gold you carry. Put it in the town vault first!",
						"Until Lv15 and 1 hour of play, the Sprout Shield keeps you safe.",
						"The goblins took the dust.\nBut why would a goblin need dust?" },
					Horns = { "A Crown Shard calls from beyond the woods. Watch out for thieves!",
						"In the woods, others can steal the gold you carry. Put it in the town vault first!",
						"Until Lv15 and 1 hour of play, the Sprout Shield keeps you safe.",
						"Goblins grab for a boss. We grab for US. Big difference! …Right?",
						"The goblins took the dust.\nBut why would a goblin need dust?" },
					Neutral = { "A Crown Shard calls from beyond the woods. Watch out for thieves!", "The Artisan Guild can't be attacked in the woods either.",
						"The goblins took the dust.\nBut why would a goblin need dust?" },
				} },
				{ Text = "Go to the Goblin Woods", Guide = "GoblinWoods", Obj = { Type = "Enter", Zone = "GoblinWoods" } },
			},
			Reward = { Gold = 2, XP = 2 },
		},
		-- 3장 "Grab Club" (story_depth §2 3장 + §5 ③④, quest_chain 3장; A23-56: the whole chapter in the beta). Rewards:
		-- G1 = { Gold = 1 }, the chapter ends M3_4 / M3_8 = { Gold = 2, XP = 2 } with [Claim]. Echoes of M3_4: Good / A ->
		-- the sub Pip1 at Lv15 (one 70% scroll), Evil / B -> Dibs pays the same worth in gold at once (HuntValue 1 minute
		-- of Lv10-24 = 192, quest_volume §2-4).
		M3_1 = {
			Kind = "Main", Chapter = 3, Title = "Thief Footprints", ShortName = "Goblin thieves",
			Start = "The dust thieves were goblins! Go stop them.",
			Steps = { { Text = "Goblins %d/%d", Guide = "GoblinWoods",
				Obj = { Type = "Kill", Kind = "Goblin", Zone = "GoblinWoods", Count = 5 } } },
			Finish = "A note: 'IOU 1 dust. Will pay back. Maybe.'", Reward = { Gold = 1 },
		},
		M3_2 = {
			Kind = "Main", Chapter = 3, Title = "Three Camps", ShortName = "Three camps",
			Start = "They hid dust sacks in three goblin camps.",
			Steps = { { Text = "Goblin camps %d/3", Guide = "GoblinWoods", Obj = { Type = "Trials", List = {
				{ Key = "a", Type = "Kill", Kind = "Goblin", Near = "GoblinCamp1", Radius = 40, Count = 1,
					Say = "Jars of dust… glowing like night-lights?" },
				{ Key = "b", Type = "Kill", Kind = "Goblin", Near = "GoblinCamp2", Radius = 40, Count = 1,
					Say = "A goblin drawing: a tiny goblin, a big dark." },
				{ Key = "c", Type = "Kill", Kind = "Goblin", Near = "GoblinCamp3", Radius = 40, Count = 1,
					Say = "Meeting #47. Topic: Grab more. Result: Meet again." },
			} } } },
			Reward = { Gold = 1 },
		},
		M3_3 = {
			Kind = "Main", Chapter = 3, Title = "The Brute's Sack", ShortName = "Brute's sack",
			Start = "The Goblin Brute has the sack. Beat it with friends. Everyone counts!",
			Steps = { { Text = "Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "GoblinBrute", Count = 1 } } },
			Finish = "Brute: Not stealing! I'm a… surprise collector.",
			Clue = "In the sack: a crayon drawing. Two kids holding something round.\nThe sun? A cookie?\n"
				.. "Brute: Found it by the fountain. The night of the big CRACK!",
			Reward = { Gold = 1 },
		},
		M3_4 = {
			Kind = "Main", Chapter = 3, Title = "Whose Shard?", ShortName = "Whose shard?", Claim = true,
			Start = "A Crown Shard shines in the sack! Take it home.",
			Steps = {
				{ Text = "Go to your town", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "OwnTown" } },
				{ Text = "Whose shard is it?", Panel = true,
					-- Lines = the Default for a client without LinesBy (E2)
					Lines = { All = { "Another shard. Another choice.", "Pip: Wait! A tiny goblin followed you home.\nPlease, just a little dust? Our woods are so dark at night.", "Pip: We took it for lamps. Then the big ones kept taking." } },
					LinesBy = { From = "M2_3",
						Good = { All = { "Last time you gave the shard back. The fountain still sparkles.", "Pip: Wait! A tiny goblin followed you home.\nPlease, just a little dust? Our woods are so dark at night.", "Pip: We took it for lamps. Then the big ones kept taking." } },
						Evil = { All = { "Last time you kept the shard. Still shiny in your pocket!", "Pip: Wait! A tiny goblin followed you home.\nPlease, just a little dust? Our woods are so dark at night.", "Pip: We took it for lamps. Then the big ones kept taking." } },
						Default = { All = { "Another shard. Another choice.", "Pip: Wait! A tiny goblin followed you home.\nPlease, just a little dust? Our woods are so dark at night.", "Pip: We took it for lamps. Then the big ones kept taking." } } },
					Obj = { Type = "Choice",
						Good = { Label = "Leave some for their lamps", Points = 3 },
						Evil = { Label = "Into our vault. They took it first!", Points = 3, Reward = { Gold = 192 } },
						Neutral = { A = "Make them a real lamp", B = "Sell the dust back to them" } } },
				{ Text = "Hear the Guide", Panel = true, Obj = { Type = "Talk" }, Lines = { All = { "The shard found a home." } },
					LinesBy = { From = "M3_4",
						Good = { Halo = { "A little light for them. Not bad." },
							All = { "You left them some? Soft! …The little ones look happy, though." } },
						Evil = { Horns = { "Ha! Finders keepers!", "Dibs: Ka-ching! Same as always? Same as always!" },
							All = { "Into the vault? …It does shine nicely.", "Dibs: Ka-ching! Same as always? Same as always!" } },
						A = { All = { "A real lamp! The little goblins will love it." } },
						B = { All = { "Sold it back? Business is business.", "Dibs: Ka-ching! Same as always? Same as always!" } },
						Default = { All = { "The shard found a home." } } } },
			},
			Reward = { Gold = 2, XP = 2 },
		},
		-- A23-86 (content_beyond_10min G): the graduation clock is a side line, not a wall in the main chain. The row says
		-- what ends the shield, with no minute numbers (no clock, A23-68 / A23-79). Saved in-progress tracks move here.
		M3_5 = {
			Kind = "Sub", Chapter = 3, Title = "Sprout Graduation", ShortName = "Graduation",
			Requires = { Done = { "M3_4" } },
			Steps = {
				{ Text = "Sprout Shield on · ends at Lv15 + 1 hour of play", Obj = { Type = "State", Key = "Graduated" } },
				{ Text = "Talk with the Guide", Panel = true, Obj = { Type = "Talk" }, Lines = {
					Halo = { "No more Sprout Shield. Now you can catch Wanted villains!",
						"When the crown broke, I was lost. A stranger gave me their lamp.\nI never knew their name. So now I give mine.",
						"And you? Why are you here?" },
					Horns = { "No more Sprout Shield. Now you can raid the knights. Hold the sack for 45 seconds!",
						"When the shards fell, we were too far. We got nothing.\nSo now we never wait. We take first!",
						"And you? Why are you here?" },
					Neutral = { "The Guild is still safe, shield or not.",
						"Both sides break things. We fix them. For both.\n…Is fixing for both sides a side too?",
						"And you? Why are you here?" },
				} },
			},
			Reward = { Gold = 1 },
		},
		M3_6 = {
			Kind = "Main", Chapter = 3, Title = "Brute Hunt", ShortName = "Brute hunt",
			Steps = {
				{ Text = "Lv18 · Brute Hunt (now Lv%d)", Obj = { Type = "Level", Level = 18 } },
				{ Text = "Goblin Brutes %d/%d", Guide = "GoblinWoods", Start = "The Brutes carry the sacks to the mountain path!",
					Obj = { Type = "Kill", Kind = "GoblinBrute", Count = 2 } },
			},
			Reward = { Gold = 1 },
		},
		M3_7 = {
			Kind = "Main", Chapter = 3, Title = "Campfire Dust", ShortName = "Campfire dust",
			Steps = {
				{ Text = "Lv21 · Campfire Dust (now Lv%d)", Obj = { Type = "Level", Level = 21 } },
				{ Text = "Hit 3 at once with a skill %d/%d", Guide = "GoblinWoods", Start = "They grab in a line. Break the line!",
					Obj = { Type = "SkillHit", Min = 3, Count = 2 } },
			},
			Reward = { Gold = 1 },
		},
		M3_8 = {
			Kind = "Main", Chapter = 3, Title = "Call of the Tombs", ShortName = "The tombs", Claim = true,
			Steps = {
				{ Text = "Lv25 · Skeleton Ruins (now Lv%d)", Obj = { Type = "Level", Level = 25 } },
				{ Text = "Go to the Skeleton Ruins", Guide = "SkeletonRuins", Obj = { Type = "Enter", Zone = "SkeletonRuins" } },
				{ Text = "Listen to the tombs", Panel = true, Obj = { Type = "Talk" }, Lines = {
					All = { "A big shard sleeps in the old kingdom's tombs.",
						"From the tombs, a sleepy voice: 'Is it still Tuesday?'",
						"The goblins took for light. Then they forgot why.\nWhat do YOU want the shard for?" },
				} },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Chapter 4 is coming!", -- A23-86 F: one closing line, no date, no clock
		},
		S1 = {
			Kind = "Sub", Title = "The Golden Goose With a Shard", ShortName = "Golden Goose", Factions = { Halo = true, Horns = true },
			Requires = { Tutorial = true }, Show = "GooseSoon",
			Steps = { { Text = "Hit the Golden Goose yourself 3 times", Guide = "Goose", Obj = { Type = "Goose", Count = 1 } } },
			FirstPoints = 1, -- 구조(빛) 명예 / 밀렵(뿔) 악명, 첫 1회만; 거위 보상은 GooseService가 그대로 준다
		},
		S2 = {
			Kind = "Sub", Title = "First Crown War Chest", ShortName = "War chest", Factions = { Halo = true, Horns = true }, Requires = { Done = { "M2_1" } },
			Steps = { { Text = "Get 30 points in one round · win the chest", Obj = { Type = "WarChest", Count = 1 } } },
		},
		S3 = {
			Kind = "Sub", Title = "Golden Jelly", ShortName = "Golden jelly", Requires = { Done = { "M1_4" } },
			Steps = {
				{ Text = "Golden monsters %d/%d", Obj = { Type = "Kill", Golden = true, Count = 1 } },
				{ Text = "What will you do with the gold dust?", Panel = true,
					Lines = { All = { "Monsters that eat lots of dust turn gold!", "What will you do with this gold dust?" } },
					Obj = { Type = "Choice", Good = { Label = "Give it to the fountain", Points = 1 }, Evil = { Label = "Into my pouch!", Points = 1 },
						Neutral = { A = "Give it to the fountain", B = "Leave it with the guild" } } },
			},
		},
		S4 = {
			Kind = "Sub", Title = "The Shard Fights for You", ShortName = "Auto Battle", Speaker = "Shard", Requires = { Done = { "S0" } },
			Start = "Shard: Now I'll fight monsters for you. Players, only by your own hand!",
			Steps = {
				{ Text = "Turn on Auto Battle ({Auto})", Obj = { Type = "State", Key = "AutoOn" } }, -- {Auto}: HUD fills it (phone: button name)
				{ Text = "Auto Battle defeats %d/%d", Obj = { Type = "AutoKill", Count = 5 } },
			},
			Reward = { Gold = 1 },
		},
		N1 = {
			Kind = "Sub", Title = "The Artisan's Touch", ShortName = "Artisan touch", Speaker = "Guild", Factions = { Neutral = true }, Requires = { Done = { "M1_4" }, Level = 5 }, -- A23-71: a skill quest
			Start = "Kit: Shape with care. Two at once!",
			Steps = { { Text = "Hit 2 with one skill %d/%d", Obj = { Type = "SkillHit", Min = 2, Count = 3 } } },
			Reward = { Gold = 1 },
		},
		N2 = {
			Kind = "Sub", Title = "Guild Supply Book", ShortName = "Supply book", Speaker = "Guild", Factions = { Neutral = true }, Requires = { Done = { "M2_1" } },
			Start = "Kit: Both sides need our gear. Collect supply gold.",
			Steps = {
				{ Text = "Supply book %d/2", Obj = { Type = "Trials", List = {
					{ Key = "a", Type = "Kill", Kind = "BigSlime", Count = 3 },
					{ Key = "b", Type = "EarnGold", Source = "Monster", Count = 60 },
				} } },
				{ Text = "Go to the Crossroads", Guide = "Crossroads", Obj = { Type = "Enter", Zone = "Crossroads" } },
			},
			Reward = { Gold = 1 },
		},
		-- A23-46 town people "they're up to something" (docs/design/town_npc_quests_2026-10-06.md + story_depth §3 / §5-⑥,
		-- 검수 decisions): open after M2_3 for the town's own side, once each. The rumor turns out to be harmless (the
		-- twist); the last pick is A (angel, Good) or B (devil, Evil) with the same size of reward in a different kind
		-- (A: one 70% scroll, B: 3 HP potions + 60 gold) on top of 120 gold + half a level bar of XP. No weekly ranking
		-- points (A23-23 D1). The last line asks a question (story_depth §1).
		H1 = {
			Kind = "Sub", Title = "The Horns Are Up to Something", ShortName = "Spy on Horns", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M2_3" } },
			Start = "Bright, the young guard, needs help. Find her in Halo Citadel!",
			Steps = {
				{ Text = "Talk to Bright in Halo Citadel", Guide = "HaloTown", Npc = "Bright", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "The Horns are up to something! I need Form H-1.\nTo get Form H-1, I need Form H-0. …Can you just help?",
						"They say a Horn broke the Crown. Everyone says so.\n…Who said so first?",
						"Page 12 of my rulebook is missing. Don't look at me!\nThe Horns sneak past the woods with big sacks. Go take a look!" } } },
				{ Text = "Spy by the woods' edge %d/%d s", Guide = "WoodsGate",
					Obj = { Type = "Near", Spot = "WoodsGate", Radius = 14, Stay = 10 } },
				{ Text = "Slime Princes near the woods %d/%d", Guide = "SlimeMeadow",
					Start = "A sack fell open… and Slime Princes gobbled what was inside!",
					Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2 } },
				{ Text = "Tell Bright what you found", Guide = "HaloTown", Npc = "Bright", Panel = true,
					Lines = { All = { "Sticky… sweet… is this jelly?",
						"Their secret sacks… are full of birthday jelly? For Smokey?",
						"One jar says: 'Happy birthday, S. From the bench.'\nBright: Not my writing! I mean… whose writing?",
						"So what do we tell everyone?" } },
					Obj = { Type = "Choice",
						Good = { Label = "Tell everyone the truth", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Keep the rumor going. It's more fun!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Bright: So who started the rumor? …Does anyone remember?",
			Clue = "Bright's wristband: gold and purple. Where have you seen one?",
		},
		R1 = {
			Kind = "Sub", Title = "The Halos Are Up to Something", ShortName = "Spy on Halos", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M2_3" } },
			Start = "Psst! Smokey in Horns Den has a secret job for you.",
			Steps = {
				{ Text = "Talk to Smokey in Horns Den", Guide = "HornsTown", Npc = "Smokey", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Psst! A Halo broke the Crown! My uncle's friend's cousin saw it!",
						"This gold spyglass? Found it. Gold is fine. For spying.\nPlan A: we spy. Plan B: same as Plan A, but sneakier!",
						"The Halos whisper at the fountain. A secret plan!\nGo listen there. Look natural!" } } },
				{ Text = "Listen at the fountain %d/%d s", Guide = "Fountain",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 16, Zone = "Crossroads", Stay = 15 } },
				{ Text = "Slimes in the meadow %d/%d", Guide = "SlimeMeadow",
					Start = "You heard: \"Slimes… sparkles… BOOM at sunset!\" Check the meadow!",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 6 } },
				{ Text = "Tell Smokey what you heard", Guide = "HornsTown", Npc = "Smokey", Panel = true,
					Lines = { All = { "The slimes were full of sparkle dust. For a show?",
						"Their big secret… is a fireworks show? For everyone?",
						"One purple firework? In a Halo show?\nThe plan is signed 'B.' …Never heard of a B.",
						"So what do we tell everyone?" } },
					Obj = { Type = "Choice",
						Good = { Label = "Tell everyone the truth", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Keep the rumor going. It's more fun!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Smokey: So who started the rumor? …Does anyone remember?",
			Clue = "Smokey's wristband: gold and purple. Where have you seen one?",
		},
		N3 = {
			Kind = "Sub", Title = "Both Sides Are Suspicious", ShortName = "Spy on both", Speaker = "Tiny", -- everyone (A23-57: no Factions)
			Requires = { Done = { "M2_3" } },
			Start = "Tiny from the guild is taking notes. Find Tiny at the Crossroads!",
			Steps = {
				{ Text = "Talk to Tiny at the Crossroads", Guide = "Crossroads", Npc = "Tiny", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Halos blame Horns. Horns blame Halos.\nNoted: nobody saw it.",
						"Can you watch both bridges for me? Quietly." } } },
				{ Text = "Watch the Halo bridge", Guide = "HaloBridge", Obj = { Type = "Near", Spot = "HaloBridge", Radius = 14 } },
				{ Text = "Watch the Horns bridge", Guide = "HornsBridge", Obj = { Type = "Near", Spot = "HornsBridge", Radius = 14 } },
				{ Text = "Hunting gold for the guild %d/%d", Guide = "SlimeMeadow",
					Obj = { Type = "EarnGold", Source = "Monster", Count = 30 } },
				{ Text = "Show Tiny your notes", Guide = "Crossroads", Npc = "Tiny", Panel = true,
					Lines = { All = { "Both sides buy spy glasses. To spy on each other. From us.",
						"Suspicious: two kids. Bench behind the fountain. Every evening.\nTheir halo and horns are tiny. Smaller than anyone's.",
						"Noted. …Is selling to both sides a side too?" } },
					Obj = { Type = "Choice",
						Good = { Label = "Send both sides a peace letter", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Sell more spy glasses to both!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } },
						Neutral = { A = "Send both sides a peace letter", B = "Sell more spy glasses to both!" } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Tiny: Noted. Suspicious: everyone. …So who started it?",
		},
		-- story_depth §3 echo of M3_4 Good / A (beta): Pip waits at the woods' edge with a lamp at Lv15
		Pip1 = {
			Kind = "Sub", Title = "Pip's Lamp", ShortName = "Pip's lamp", Speaker = "Pip",
			Requires = { Done = { "M3_4" }, Pick = { Id = "M3_4", Is = "Good" }, Level = 15 },
			Start = "Someone small is waving at the woods' edge…",
			Steps = {
				{ Text = "Go to the woods' edge", Guide = "WoodsGate", Obj = { Type = "Near", Spot = "WoodsGate", Radius = 14 } },
				{ Text = "Talk to Pip", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Pip: Look! My own lamp! It glows purple. I never knew purple!" } } },
			},
			Reward = { Item = "Enh70", N = 1 },
		},
		-- A23-86 Sprout Oath (content_beyond_10min G): while the Sprout Shield is still on (Requires.Sprout) at Lv15 after M3_4,
		-- a small training that shows the player's graduation role (Halo: guard + catch, Horns: raid) and ends with an oath.
		-- Same steps count and walking for both sides' rewards: a stat-free title and 2 points (A23-58: the other side -2).
		OathH = {
			Kind = "Sub", Title = "The Sprout Oath", ShortName = "Sprout oath", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M3_4" }, Level = 15, Sprout = true },
			Start = "Bright has a last lesson before your Sprout Shield ends.",
			Steps = {
				{ Text = "Talk to Bright in Halo Citadel", Guide = "HaloTown", Npc = "Bright", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Bright: Almost a graduate! Soon you can catch Wanted villains.",
						"Bright: First, guard the woods bridge. Then face a Goblin Brute!" } } },
				{ Text = "Guard the woods bridge %d/%d s", Guide = "WoodsGate", Obj = { Type = "Near", Spot = "WoodsGate", Radius = 14, Stay = 15 } },
				{ Text = "Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 } },
				{ Text = "Make your oath to Bright", Guide = "HaloTown", Npc = "Bright", Panel = true,
					Lines = { All = { "Bright: You did it! Say your oath. What kind of Halo are you?" } },
					Obj = { Type = "Choice", Good = { Label = "I'll guard the small ones", Points = 2 },
						Evil = { Label = "Rascals bow to no one!", Points = 2 } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },
			Finish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",
		},
		OathR = {
			Kind = "Sub", Title = "The Sprout Oath", ShortName = "Sprout oath", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M3_4" }, Level = 15, Sprout = true },
			Start = "Smokey has a last lesson before your Sprout Shield ends.",
			Steps = {
				{ Text = "Talk to Smokey in Horns Den", Guide = "HornsTown", Npc = "Smokey", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Smokey: Almost a graduate! When the shield ends, you can raid knights.",
						"Smokey: Hold the sack for 45 seconds and it's yours!",
						"Smokey: Warm up first. Two goblin camps, then punch a Goblin Brute. Basic hits only!" } } },
				{ Text = "Find the first goblin camp", Guide = "GoblinCamp1", Obj = { Type = "Near", Spot = "GoblinCamp1", Radius = 10 } },
				{ Text = "Find the second goblin camp", Guide = "GoblinCamp2", Obj = { Type = "Near", Spot = "GoblinCamp2", Radius = 10 } },
				{ Text = "Basic hits on a Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "BasicKill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 } },
				{ Text = "Make your oath to Smokey", Guide = "HornsTown", Npc = "Smokey", Panel = true,
					Lines = { All = { "Smokey: Not bad, rascal! Say your oath. What kind of Horn are you?" } },
					Obj = { Type = "Choice", Good = { Label = "I'll guard the small ones", Points = 2 },
						Evil = { Label = "Rascals bow to no one!", Points = 2 } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },
			Finish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",
		},
		-- A23-86 Call of the Woods (content_beyond_10min A): the first time a Lv10 hunter stands on the woods bridge, one
		-- small card. Same size, fixed reward: A (angel) one 70% scroll / B (devil) 3 HP potions + 1 minute of hunting gold at
		-- Lv10 (Config.HuntValue(10, 1) = 192, a test holds it). The bridge is outside the PvP woods (WoodsGate).
		WB1 = {
			Kind = "Sub", Title = "The Dropped Lantern", ShortName = "Bridge lamp", Factions = { Halo = true, Horns = true, Neutral = true },
			Requires = { Done = { "M1_4" }, Level = 10 },
			Start = "A light flickers on the woods bridge…",
			Steps = {
				{ Text = "Step onto the woods bridge", Guide = "WoodsGate", Obj = { Type = "Near", Spot = "WoodsGate", Radius = 14 } },
				{ Text = "Pick up the lantern?", Panel = true,
					Lines = { All = { "A goblin dropped his lantern on the bridge. It is still warm." } },
					Obj = { Type = "Choice",
						Good = { Label = "Hand it back", Points = 1, Reply = "A grateful grunt echoes from the trees.",
							Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Finders keepers!", Points = 1, Reply = "The lantern glows brighter in your hands.",
							Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Hand it back", B = "Finders keepers!" } } },
			},
			Finish = "The woods feel a little less dark.",
		},
		-- quest_volume §3-2 (A23-56, 검수 2026-10-06): 12 new subs + 6 pulled from story_depth §3 / town_npc_quests, each once,
		-- ending in an A (angel) / B (devil) pick with the same size of reward in a different kind (A23-58 scores the pick).
		-- Town-type (Lv5-10): 120 gold + half a level bar, A one 70% scroll / B 3 HP potions + 60 gold. Woods-type (Lv10+):
		-- 2 minutes of hunting gold + XP, A one 70% scroll / B 3 HP potions + 192 gold (HuntValue 1 minute of Lv10-24).
		-- They open after M1_4 at Lv5+ (the first ten minutes stay as they are). No weekly ranking points (A23-23 D1).
		S6 = {
			Kind = "Sub", Title = "Keep the Path Safe", ShortName = "Safe path", Factions = { Halo = true, Horns = true },
			Requires = { Done = { "M1_4" }, Level = 5 },
			Steps = {
				{ Text = "Slimes by the meadow arrival %d/%d", Guide = "SlimeMeadow",
					Obj = { Type = "Kill", Kind = "Slime", Near = "MeadowArrival", Radius = 40, Count = 5 },
					Horns = { Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 80 } } },
				{ Text = "Back to your town", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "OwnTown" } },
				{ Text = "Talk with the Guide", Panel = true,
					Lines = { Halo = { "New kids walk this path. Keep it safe!", "The new kids keep asking for help…" },
						Horns = { "A Horn Legion pouch must be FAT!", "So. What will you do with all that gold?" } },
					Obj = { Type = "Choice", Good = { Label = "Help them find the slimes", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Make them say \"Thanks, boss!\"", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } },
					Horns = { Obj = { Type = "Choice", Good = { Label = "Share snacks with the den", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Count it twice. Mine!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Who walks this path next?",
		},
		XR1 = {
			Kind = "Sub", Title = "Lost & Found", ShortName = "Lost bear", Speaker = "Tiny",
			Requires = { Done = { "M1_4" }, Level = 5 },
			Steps = {
				{ Text = "Talk to Tiny at the Crossroads", Guide = "Crossroads", Npc = "Tiny", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Tiny: A Slime Prince swallowed a teddy bear!", "Tiny: Noted. Teddy bear: very loved. Very lost." } } },
				{ Text = "Slime Prince %d/%d", Guide = "SlimeMeadow", Obj = { Type = "Kill", Kind = "BigSlime", Count = 1 } },
				{ Text = "Bring the bear to Tiny", Guide = "Crossroads", Npc = "Tiny", Panel = true,
					Lines = { All = { "Tiny: A bit sticky. Still very soft.", "Tiny: So. What now?" } },
					Obj = { Type = "Choice", Good = { Label = "Return it to its owner", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Sell it at the counter", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } },
						Neutral = { A = "Return it to its owner", B = "Sell it at the counter" } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Tiny: Thanks for your business. …Who lost it, anyway?",
		},
		H2 = {
			Kind = "Sub", Title = "The Missing Halo Lantern", ShortName = "Lost lantern", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M1_4" }, Level = 8 },
			Start = "Bright: The town lantern is gone! Did a slime eat it?",
			Steps = {
				{ Text = "Look around the fountain", Guide = "Crossroads",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 22, Zone = "Crossroads" } },
				{ Text = "Slimes %d/%d", Guide = "SlimeMeadow", Start = "Glowing jelly tracks lead to the meadow!",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 5 } },
				{ Text = "The lantern is back!", Panel = true,
					Lines = { All = { "Found it! Still warm. Still glowing.", "Inside the lamp: a tiny 'B.' scratched in.\nWhose is it now?" } },
					Obj = { Type = "Choice", Good = { Label = "Give it back to the town", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Hang it in my house", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Bright: Who was the first to carry it, I wonder?",
		},
		R5 = {
			Kind = "Sub", Title = "Smokey's Hat Problem", ShortName = "Smokey's hat", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M1_4" }, Level = 8 },
			Start = "Smokey: A Slime Prince is wearing my sack as a crown!",
			Steps = {
				{ Text = "Find the slime by the pond", Guide = "SlimePond", Obj = { Type = "Near", Spot = "SlimePond", Radius = 30 } },
				{ Text = "Slime Prince %d/%d", Guide = "SlimePond", Obj = { Type = "Kill", Kind = "BigSlime", Count = 1 } },
				{ Text = "The sack is free!", Panel = true,
					Lines = { All = { "A sack! A bit slimy. Smokey's name is on it.", "So whose sack is it now?" } },
					Obj = { Type = "Choice", Good = { Label = "Give it back to Smokey", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Finders keepers!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Smokey: Did the slime look good in it, at least?",
		},
		GW1 = {
			Kind = "Sub", Title = "Grab Club Meeting", ShortName = "Grab Club", Speaker = "Grabbo",
			Requires = { Done = { "M2_7" }, Level = 12 },
			Steps = {
				{ Text = "Find the goblin camp meeting", Guide = "GoblinCamp1",
					Obj = { Type = "Near", Spot = "GoblinCamp1", Radius = 10 } },
				{ Text = "Grab Club, meeting #47", Panel = true,
					Lines = { All = { "Grabbo: Welcome to Grab Club! This is meeting number 47.",
						"Grabbo: Last week we grabbed 100 dust. This week's goal: MORE.",
						"Pip: Um, boss? Why do we grab?\nGrabbo: Because we grabbed last week! Next meeting: right now." } },
					Obj = { Type = "Choice", Good = { Label = "Give the dust back", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Grab MORE dust!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Give the dust back", B = "Grab MORE dust!" } } },
				{ Text = "Grabbo's answer", Panel = true, Obj = { Type = "Talk" }, Lines = { All = { "Grabbo: Hmm. Noted!" } },
					LinesBy = { From = "GW1", Good = { All = { "Grabbo: Give it… back? Write that down! A new idea!" } },
						Evil = { All = { "Grabbo: Same plan, but MORE! Meeting 48 starts now!" } },
						Default = { All = { "Grabbo: Hmm. Noted!" } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Grabbo: What were we grabbing for again?",
		},
		H3 = {
			Kind = "Sub", Title = "Day 40: Cat in Tree", ShortName = "Cat in a tree", Speaker = "Gleam", Factions = { Halo = true },
			Requires = { Done = { "M2_7" }, Level = 12 },
			Steps = {
				{ Text = "Talk to Sir Gleam", Guide = "HaloTown", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Sir Gleam: Day 40: Cat in tree. Again!", "Sir Gleam: Each rescue is a heart. 10,001 hearts!\nClear the slimes so I can reach it." } } },
				{ Text = "Slimes %d/%d", Guide = "SlimeMeadow", Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 6 } },
				{ Text = "Back to Sir Gleam", Guide = "HaloTown", Panel = true,
					Lines = { All = { "Sir Gleam: The cat is down! …It is already climbing again.", "Sir Gleam: What should we do?" } },
					Obj = { Type = "Choice", Good = { Label = "Let the cat be. Help someone new.", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Put it back up. More hearts!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Sir Gleam: Is it still helping if you do it for the hearts?",
		},
		R3 = {
			Kind = "Sub", Title = "Prank #200", ShortName = "Prank #200", Speaker = "Rex", Factions = { Horns = true },
			Requires = { Done = { "M2_7" }, Level = 12 },
			Steps = {
				{ Text = "Talk to Rascal Rex", Guide = "HornsTown", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Rascal Rex: Prank number 200! Same as 199?", "Rascal Rex: Pranks cost gold. Go hunt some!" } } },
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 60 } },
				{ Text = "Back to Rascal Rex", Guide = "HornsTown", Panel = true,
					Lines = { All = { "Rascal Rex: The boos are the best part!", "Rascal Rex: So. Which prank?" } },
					Obj = { Type = "Choice", Good = { Label = "Plan a surprise party instead", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Do prank 201. The same one!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Rascal Rex: Classic! …Is classic getting old?",
		},
		GW2 = {
			Kind = "Sub", Title = "The Dark Path", ShortName = "Dark path",
			Requires = { Done = { "M2_7" }, Level = 11 },
			Start = "The woods path has no light. Kids won't walk it in the dark.",
			Steps = {
				{ Text = "Watch the woods path %d/%d s", Guide = "WoodsGate",
					Obj = { Type = "Near", Spot = "WoodsGate", Radius = 14, Stay = 10 } },
				{ Text = "Goblins by the woods arrival %d/%d", Guide = "GoblinWoods",
					Obj = { Type = "Kill", Kind = "Goblin", Near = "WoodsArrival", Radius = 40, Count = 4 } },
				{ Text = "What will you put up?", Panel = true,
					Lines = { All = { "The path is clear for now.", "What will you put up by the path?" } },
					Obj = { Type = "Choice", Good = { Label = "Put up a lamp for everyone", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Put up a KEEP OUT sign", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Put up a lamp for everyone", B = "Put up a KEEP OUT sign" } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Who will walk this path tomorrow?",
		},
		GW3 = {
			Kind = "Sub", Title = "Gold Paint", ShortName = "Gold paint",
			Requires = { Done = { "M2_7" }, Level = 14 },
			Start = "A goblin painted himself gold to look rich!",
			Steps = {
				{ Text = "A golden monster in the woods %d/%d", Guide = "GoblinWoods",
					Obj = { Type = "Kill", Golden = true, Zone = "GoblinWoods", Count = 1 } },
				{ Text = "The gold goblin", Panel = true,
					Lines = { All = { "Goblin: Don't tell! The gold comes off in the rain.", "Goblin: Do I look rich? Be honest." } },
					Obj = { Type = "Choice", Good = { Label = "Tell him he's fine as he is", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Sell him more gold paint", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Tell him he's fine as he is", B = "Sell him more gold paint" } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Does gold paint make anyone rich?",
		},
		H5 = {
			Kind = "Sub", Title = "Form H-2", ShortName = "Form H-2", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M2_7" }, Level = 15 },
			Steps = {
				{ Text = "Talk to Bright", Guide = "HaloTown", Npc = "Bright", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Bright: I need Form H-2 to fight a Brute.", "Bright: Who made these forms?! …Oh. Us." } } },
				{ Text = "Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "GoblinBrute", Count = 1 } },
				{ Text = "Tell Bright", Guide = "HaloTown", Npc = "Bright", Panel = true,
					Lines = { All = { "Bright: You beat it! Without a form!", "Bright: So… what about the forms?" } },
					Obj = { Type = "Choice", Good = { Label = "Skip the form. Just help!", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Fill in three more forms", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Bright: Do rules help, or do people help?",
		},
		R6 = {
			Kind = "Sub", Title = "Plan B, Again", ShortName = "Plan B", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M2_7" }, Level = 15 },
			Steps = {
				{ Text = "Talk to Smokey", Guide = "HornsTown", Npc = "Smokey", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Smokey: Plan B failed. Time for… Plan B?", "Smokey: Plans cost gold. Lots of it." } } },
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 200 } },
				{ Text = "Back to Smokey", Guide = "HornsTown", Npc = "Smokey", Panel = true,
					Lines = { All = { "Smokey: Gold! Now, the plan…", "Smokey: Which plan?" } },
					Obj = { Type = "Choice", Good = { Label = "Try a brand-new plan", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Plan B again, but LOUDER", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Smokey: What if a plan needs two people?",
		},
		GW4 = {
			Kind = "Sub", Title = "The Crown War Is Close", ShortName = "Crown War", Factions = { Halo = true, Horns = true },
			Requires = { Done = { "M2_7" }, Level = 16 },
			Start = "The Crown War is close! Win points for your side.",
			Steps = {
				{ Text = "Crown points %d/%d", Obj = { Type = "WarPoints", Count = 40 } },
				{ Text = "The round is over", Panel = true,
					Lines = { All = { "What a round!", "How will you end it?" } },
					Obj = { Type = "Choice", Good = { Label = "Cheer for both sides", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Victory dance, our side only!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Who was the war really for?",
		},
		GW5 = {
			Kind = "Sub", Title = "The Tired Goose", ShortName = "Tired goose", Speaker = "Fountain", Factions = { Halo = true, Horns = true },
			Requires = { Done = { "M2_7" }, Level = 17 },
			Start = "Fountain Shard: The Golden Goose looks so tired…",
			Steps = {
				{ Text = "Join the Golden Goose tug %d/%d", Guide = "Goose", Obj = { Type = "Goose", Count = 2 } },
				{ Text = "Talk with the Fountain Shard", Guide = "Crossroads", Panel = true,
					Lines = { All = { "Fountain Shard: She runs every day. Pulled this way, then that way.", "Fountain Shard: What now?" } },
					Obj = { Type = "Choice", Good = { Label = "Let her rest a day", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Make her lay eggs faster!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Fountain Shard: Are more eggs ever enough?",
		},
		GW6 = {
			Kind = "Sub", Title = "Nap Time", ShortName = "Nap time",
			Requires = { Done = { "M2_7" }, Level = 19 },
			Start = "Beat a Brute and stay above half HP. He wants a nap.",
			Steps = {
				{ Text = "Goblin Brute above half HP %d/%d", Guide = "GoblinWoods",
					Obj = { Type = "SafeKill", Kind = "GoblinBrute", MinHP = 0.5, Count = 1 } },
				{ Text = "The sleepy Brute", Panel = true,
					Lines = { All = { "Brute: Zzz… five more minutes…", "What will you do?" } },
					Obj = { Type = "Choice", Good = { Label = "Tuck him in for a nap", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Draw a mustache on him", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Tuck him in for a nap", B = "Draw a mustache on him" } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Even Brutes get tired. What makes you tired?",
		},
		GW7 = {
			Kind = "Sub", Title = "Grab Club, Again", ShortName = "Grab Club 2", Speaker = "Grabbo",
			Requires = { Done = { "GW1" }, Level = 21 },
			Steps = {
				{ Text = "Back to the goblin camp", Guide = "GoblinCamp1", Obj = { Type = "Near", Spot = "GoblinCamp1", Radius = 10 } },
				{ Text = "Grab Club meets again", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Grabbo: Grab Club meets again. Same topic?" } },
					LinesBy = { From = "GW1",
						Good = { All = { "Grabbo: Last time someone said 'give it back'. We wrote it down!", "Grabbo: Now help us practice. Gently!" } },
						Evil = { All = { "Grabbo: Meeting #48! Topic: MORE. Same as always!", "Grabbo: Show us how you grab three at once!" } },
						Default = { All = { "Grabbo: Grab Club meets again. Same topic?", "Grabbo: Show us how you grab three at once!" } } } },
				{ Text = "Hit 3 at once with a skill %d/%d", Guide = "GoblinWoods", Obj = { Type = "SkillHit", Min = 3, Count = 2 } },
				{ Text = "The club votes", Panel = true,
					Lines = { All = { "Grabbo: Time to vote!" } },
					Obj = { Type = "Choice", Good = { Label = "Bring the club a new idea", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Vote for MORE. Again!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Bring the club a new idea", B = "Vote for MORE. Again!" } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Grabbo: What else can a club do?",
		},
		H6 = {
			Kind = "Sub", Title = "Dusty Heroes", ShortName = "Dusty heroes", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M2_7" }, Level = 22 },
			Start = "Bright: The hero statues are dusty. Who were they, really?",
			Steps = {
				{ Text = "Look at the hero statues %d/%d s", Guide = "HeroStatue",
					Obj = { Type = "Near", Spot = "HeroStatue", Radius = 16, Stay = 10 } },
				{ Text = "Goblins %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "Goblin", Zone = "GoblinWoods", Count = 8 } },
				{ Text = "Back to the statues", Guide = "HaloTown", Panel = true,
					Lines = { All = { "Bright: The statues are shiny again!", "Bright: What should the road show next?" } },
					Obj = { Type = "Choice", Good = { Label = "Add a statue of a sprout too", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Make OUR statue bigger", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Bright: Who is a hero? Only the big ones?",
		},
		R7 = {
			Kind = "Sub", Title = "Lava Party", ShortName = "Lava party", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M2_7" }, Level = 22 },
			Start = "Smokey: Party at the lava cracks! Bring snacks… or gold.",
			Steps = {
				{ Text = "Warm up at the lava %d/%d s", Guide = "LavaCrack",
					Obj = { Type = "Near", Spot = "LavaCrack", Radius = 16, Stay = 10 } },
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 300 } },
				{ Text = "Party time", Guide = "HornsTown", Panel = true,
					Lines = { All = { "Smokey: Snacks! Gold! Music!", "Smokey: Who gets in?" } },
					Obj = { Type = "Choice", Good = { Label = "Invite the whole den", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "VIP only. Just us!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Smokey: Is a party better big, or just right?",
		},
		GW8 = {
			Kind = "Sub", Title = "A Very Full Vault", ShortName = "Full vault",
			Requires = { Done = { "M2_7" }, Level = 23 },
			Start = "Your vault is SO full. What is all this gold for?",
			Steps = {
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 500 } },
				{ Text = "Back to your town", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "OwnTown" } },
				{ Text = "Talk about the vault", Panel = true,
					Lines = { All = { "So much gold! The vault door barely shuts.", "Is a bigger vault ever big enough?" } },
					Obj = { Type = "Choice", Good = { Label = "Give some to the town fund", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Build a bigger vault", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Give some to the town fund", B = "Build a bigger vault" } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "What is gold for, really?",
		},
	},
}

-- A23-46 town sub-quest spots at the bridge ends of Config.Map.Bridges: the meadow end of the Goblin bridge (650, 0, 0)
-- 14 studs back, outside the PvP woods (H1 spies there), and the Crossroads ends of the Halo / Horns bridges (0, 0, -150)
-- / (0, 0, 150) 12 studs onto the land (N3 watches them). They move with the bridges: tools/test_town_quests.py fails
-- when a bridge end moves away from its spot.
Config.StoryQuests.Landmarks.WoodsGate = Vector3.new(636, 0, 0)
Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -138)
Config.StoryQuests.Landmarks.HornsBridge = Vector3.new(0, 0, 138)
-- story_depth §2-1: the Crossroads bench behind the fountain where two kids meet every evening (the Crossroads core
-- keeps its place on map v2)
Config.StoryQuests.Landmarks.KidsBench = Vector3.new(18, 0, 18)
-- quest_chain M3-2: the three goblin camps on map v2 (docs/design/kit_woods.md camps 1-3; the boss clearing (1110, 120)
-- stays 40+ studs from camp 2)
Config.StoryQuests.Landmarks.GoblinCamp1 = Vector3.new(840, 0, 95)
Config.StoryQuests.Landmarks.GoblinCamp2 = Vector3.new(1010, 0, 130)
Config.StoryQuests.Landmarks.GoblinCamp3 = Vector3.new(1090, 0, -150)
-- quest_volume §3-5: the fields' arrival points follow their zones' Spawn (map v2 moves them along), and the two job
-- boards (E11): the meadow board beside the meadow arrival, the woods board at the meadow end of the woods bridge
-- (WoodsGate, outside the PvP woods). Game dev 1 places the boards there (the server checks the distance to these).
Config.StoryQuests.Landmarks.MeadowArrival = Config.Zones.SlimeMeadow.Spawn
Config.StoryQuests.Landmarks.WoodsArrival = Config.Zones.GoblinWoods.Spawn
-- (a literal: some offline Vector3 doubles have no arithmetic; test_board checks it stays beside the arrival) - map v2:
-- just south of the crown road (|z| <= 9), its face toward the arrival
Config.StoryQuests.Landmarks.MeadowBoard = Vector3.new(230, 0, 12)
Config.StoryQuests.Landmarks.WoodsBoard = Config.StoryQuests.Landmarks.WoodsGate
-- quest_volume §3-2 H6 / R7: the Heroes' Road between the hero statues (Halo Citadel) and the east lava channel (Horns
-- Den). Map v2 moves the town cores 10 studs outward with their gates (Halo z -320 -> -330, Horns 320 -> 330).
Config.StoryQuests.Landmarks.HeroStatue = Vector3.new(0, 0, -370)
Config.StoryQuests.Landmarks.LavaCrack = Vector3.new(48, 0, 410)

-- E11 (quest_volume §3-3 / §4, 검수 OK 2026-10-07): the hunting-field job boards (BoardService). Enabled = false until
-- game dev 1's board window ships; on, extra quests stop (a claimed daily slot stays empty) and the boards take that
-- role. A card is taken as [Kind] or [Sneaky]: only the side is counted (data.Story.N), no honor / infamy / ranking.
-- Reward = HuntValue(the board's Level, 1) (meadow 36 gold + 60 XP, woods 192 + 336), x AfterMult after FullPerDay jobs
-- a KST day; the BonusAt-th job of a day also gives one BonusItem. Jobs: Obj like a story step ("$Key" = the board's
-- value), Count per board, Goal = the quest-list line ({Unit} / {Big} / {Camp} names, then %d/%d), Kind / Sneaky = the
-- card's two buttons (a table = per board). Weight default 3; NeedAuto = only after Auto Battle is unlocked. A board's
-- SafeIds: at least one such card is always on it (the woods: done outside the PvP zone).
Config.Board = {
	Enabled = false,
	Cards = 4,
	Hold = 3,
	Range = 14, -- studs from the board spot for BoardAction
	RerollCooldown = 60, -- one card swap per this many seconds (like the dailies)
	FullPerDay = 10,
	AfterMult = 0.5,
	BonusAt = 5,
	BonusItem = "Enh30",
	HintAfter = "M1_4", -- the "Job Board" guide row shows after this story quest until the first job is taken
	HintBoard = "Meadow",
	Boards = {
		Meadow = { Zone = "SlimeMeadow", Spot = "MeadowBoard", Level = 1, Unit = "Slime", Big = "BigSlime",
			Arrival = "MeadowArrival", Camp = "SlimePond", CampName = "pond", Gate = "MeadowArrival" },
		Woods = { Zone = "GoblinWoods", Spot = "WoodsBoard", Level = 10, Unit = "Goblin", Big = "GoblinBrute",
			Arrival = "WoodsArrival", Camp = "GoblinCamp1", CampName = "camp", Gate = "WoodsGate",
			SafeIds = { J6 = true, J10 = true } },
	},
	Jobs = {
		{ Id = "J1", ShortName = "Clear the path", Obj = { Type = "Kill", Kind = "$Unit", Near = "$Arrival", Radius = 40 }, Count = { Meadow = 5, Woods = 4 },
			Goal = "Clear the path · {Unit} %d/%d",
			Kind = "Clear the path so new kids can walk.", Sneaky = "Clear the path. Now it's YOUR road!" },
		{ Id = "J2", ShortName = "Camp patrol", Obj = { Type = "Kill", Kind = "$Unit", Near = "$Camp", Radius = 40 }, Count = { Meadow = 4, Woods = 3 },
			Goal = "By the {Camp} · {Unit} %d/%d",
			Kind = { Meadow = "The pond is too crowded. Give the frogs room.", Woods = "The camp is too crowded. Give the little ones room." },
			Sneaky = { Meadow = "Best spot in the meadow. Claim it!", Woods = "Best spot in the woods. Claim it!" } },
		{ Id = "J3", ShortName = "Big hunt", Obj = { Type = "Kill", Kind = "$Big" }, Count = { Meadow = 2, Woods = 1 }, Goal = "{Big} %d/%d",
			Kind = "A big one blocks the road. Stop it!", Sneaky = "Bonk the big one. Show who's boss!" },
		{ Id = "J4", ShortName = "Hit 3 at once", Obj = { Type = "SkillHit", Min = 3 }, Count = { Meadow = 2, Woods = 2 }, NeedSkill = true, Goal = "Hit 3 at once with a skill %d/%d",
			Kind = "A swarm blocks a cart. Clear it at once!", Sneaky = "Hit three at once. Make everyone look!" },
		{ Id = "J5", ShortName = "Basic hits", Obj = { Type = "BasicKill", Kind = "$Unit" }, Count = { Meadow = 6, Woods = 4 }, Goal = "Basic hits only · {Unit} %d/%d",
			Kind = "Basic hits only. Keep it quiet for the birds.", Sneaky = "No skills needed. Too easy!" },
		{ Id = "J6", ShortName = "Hunting gold", Obj = { Type = "EarnGold", Source = "Monster" }, Count = { Meadow = 40, Woods = 150 }, Goal = "Hunting gold %d/%d",
			Kind = "Collect gold for the town road fund.", Sneaky = "Fill your pouch. Bigger pouch, bigger grin!" },
		{ Id = "J7", ShortName = "Auto defeats", Obj = { Type = "AutoKill" }, Count = { Meadow = 8, Woods = 6 }, NeedAuto = true, Goal = "Auto Battle defeats %d/%d",
			Kind = "Let your shard guard the road.", Sneaky = "Let your shard do the boring part." },
		{ Id = "J8", ShortName = "Golden monster", Obj = { Type = "Kill", Golden = true }, Count = 1, Weight = 1, Goal = "A golden monster %d/%d",
			Kind = "A golden one is lost. Bring it home!", Sneaky = "A golden one! Finders keepers!" },
		{ Id = "J9", ShortName = "Safe big hunt", Obj = { Type = "SafeKill", Kind = "$Big", MinHP = 0.5 }, Count = 1, Goal = "{Big} above half HP %d/%d",
			Kind = "Show the sprouts how to fight safely.", Sneaky = "Win without a scratch. Show off!" },
		{ Id = "J10", ShortName = "Gate guard", Obj = { Type = "Near", Spot = "$Gate", Radius = 14 }, Count = 15, Goal = "Stand guard at the gate %d/%d s",
			Kind = "Stand guard at the gate.", Sneaky = "Stand at the gate and look tough." },
	},
	Text = {
		Done = "Job done! +%s gold · +%s XP",
		LeanKind = "Your shard leaned to the light.",
		LeanSneaky = "Your shard leaned to the dark.",
		Score = "%s +%d", -- A23-86: ("Honor" | "Infamy", points) one deed of the daily ledger
		Bonus = "5th job today! +%s",
		Full = "You carry 3 jobs. Finish one first!",
		Hint = "Job Board · tap for directions",
		HintShort = "Job Board", -- ShortName of the hint row (phone quest row)
	},
}

----------------------------------------------------------------- the quest window's tabs (A23-81)
-- A23-81 (user 2026-10-08 15:05): Q opens the whole quest window, five tabs by kind of quest. One table decides the tab
-- of a quest: ById (the "Quests" row Id - "story:<id>", "job:<n>", a daily template id, Config.Tutorial.QuestId) wins,
-- then ByKind (the row's Kind), then Default. Faction = the Halo / Horns / guild stories (deeds of a side); Event = the
-- goose and crown war stories (and later event quests); every daily / extra slot is Daily. HudLines = the HUD's quest
-- lines on the left (only quests in progress, main first).
Config.QuestTabs = {
	Order = { "Main", "Side", "Daily", "Event", "Faction" },
	Names = { Main = "Main", Side = "Side", Daily = "Daily", Event = "Event", Faction = "Faction" }, -- game text: English only
	ByKind = { Tutorial = "Main", Main = "Main", Sub = "Side", Job = "Side", Daily = "Daily", Extra = "Daily", Weekly = "Daily",
		Event = "Event", Faction = "Faction", Bounty = "Faction" },
	ById = {
		["story:S1"] = "Event", ["story:S2"] = "Event", ["story:GW4"] = "Event", ["story:GW5"] = "Event",
		["story:H1"] = "Faction", ["story:H2"] = "Faction", ["story:H3"] = "Faction", ["story:H5"] = "Faction",
		["story:H6"] = "Faction", ["story:R1"] = "Faction", ["story:R3"] = "Faction", ["story:R5"] = "Faction",
		["story:R6"] = "Faction", ["story:R7"] = "Faction", ["story:N1"] = "Faction", ["story:N2"] = "Faction",
	},
	Default = "Side",
	HudLines = 3,
}

-- the quest window tab of a "Quests" row (id, kind): ById, else ByKind, else Default
function Config.QuestTab(id, kind)
	local qt = Config.QuestTabs
	local byId = type(id) == "string" and qt.ById[id] or nil
	if byId then return byId end
	return (type(kind) == "string" and qt.ByKind[kind]) or qt.Default
end

----------------------------------------------------------------- quests (3 slots: dailies first, then rolling extras)
Config.Quests = {
	Slots = 3,
	RerollCooldown = 60,
	EndowedMin = 0.10, -- new quests with Target >= 5 start 10-20% done
	EndowedMax = 0.20,
	MaxPvPQuests = 1,
	PvPMinLevel = 15,
	ExtraRewardMult = 0.5, -- extras pay floor(units * mainMonster.Gold|XP * RewardPerUnit * ExtraRewardMult)
	-- Units = extra-quest sizes, DailyUnits = daily sizes (~5 min of play). For Id "Gold": Target = units * mainMonster.Gold.
	-- Every Lv10+ DAILY pays Config.DailyQuestReward(level at generation) regardless of template (Lv1-9: see Newbie).
	-- CR-M27: Kill / Golden Text = string.format(Text, mainMonsterName, target) (the level zone's unit monster). Their
	-- progress per kill = killed monster XP / unit monster XP (max 1), so it can be fractional (shown with 1 decimal).
	-- Every other template: string.format(Text, target) ("Gold" passes the target as a string).
	Templates = {
		{ Id = "Kill", ShortName = "Monster hunt", Weight = 40, Units = { 25, 40 }, DailyUnits = { 50, 60 }, RewardPerUnit = 1.0,
			Text = "Defeat %s ×%d" },
		{ Id = "Golden", ShortName = "Golden hunt", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 30,
			Text = "Defeat golden %s ×%d" },
		{ Id = "Gold", ShortName = "Earn gold", Weight = 20, Units = { 40, 60 }, DailyUnits = { 50, 60 }, RewardPerUnit = 0.5,
			Text = "Earn %s gold by hunting" },
		{ Id = "Release", ShortName = "Skill hits", Weight = 20, Units = { 2, 3 }, DailyUnits = { 3 }, RewardPerUnit = 8,
			Text = "Hit monsters with skills %d times" },
		{ Id = "Goose", ShortName = "Goose tug", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 20,
			Text = "Join the Golden Goose tug %d times" },
		{ Id = "Hunt", ShortName = "Catch Wanted", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Halo", PvP = true,
			Text = "Catch %d Wanted players (Kaiju count)" },
		{ Id = "Plunder", ShortName = "Rob Knights", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Horns", PvP = true,
			Text = "Rob %d Knights of Light" },
	},
	-- A23-14 (user 2026-10-05 "짧고 다양하게"): DAILIES generated at Lv1..Newbie.MaxLevel (meadow levels; Goblin Woods
	-- opens at Lv10) come from Newbie.Dailies instead of Templates[].DailyUnits. The "different template" rule picks one
	-- row per Id, so the 3 slots are always 3 different goals (kill / skill / gold). Extras and Lv10+ dailies unchanged.
	-- Row: Id = a Templates Id (its Text, progress rule and faction filter are reused, so saves stay valid).
	--   Targets = exact targets (Kill: kills, Release: manual skills that hit >= 1 monster, Gold: hunting gold).
	--   Monster = the monster a Kill row counts (default: the level zone's unit monster).
	--   Strict = only that monster (or a stronger one) counts, 1 per kill: no fractional slime progress.
	-- Size: about 1-3 min each at an assumed manual pace of ~5 kills/min in the meadow (not hand-measured yet); the
	-- three progress together while hunting, so the whole set is about 3-5 min.
	-- Rewards: each daily pays Config.HuntValue(level, RewardMinutes), the full-set chest HuntValue(level, ChestMinutes).
	-- Lv1-9: 72 gold + 120 XP per daily, chest 144 gold + 240 XP -> one day's set = 360 gold + 600 XP, below the
	-- 1381 XP from Lv1 to Lv10 (was 3 x 300 + 600 = 1500 XP). Vacation follows the same band (Config.DailyDayMinutes):
	-- a missed Lv1-9 day pays 70% of 10 min = 252 gold + 420 XP, below a played day; 3 days = 1260 XP < 1381.
	-- The full-set chest never pays more than the band the day's dailies were generated in (QuestService DailyLevel).
	Newbie = {
		MaxLevel = 9,
		RewardMinutes = 2,
		ChestMinutes = 4,
		Dailies = {
			{ Id = "Kill", Weight = 3, Monster = "BigSlime", Strict = true, Targets = { 3 } }, -- Slime Prince x3
			{ Id = "Kill", Weight = 1, Monster = "Slime", Targets = { 12, 15 } }, -- sometimes / on reroll: 슬라임 12~15마리
			{ Id = "Release", Weight = 3, Targets = { 3, 4, 5 } }, -- 몬스터에게 스킬 3~5번 맞히기
			{ Id = "Gold", Weight = 3, Targets = { 40, 50, 60 } }, -- 사냥으로 골드 40~60 벌기
		},
	},
	-- E12 (quest_volume §3-4, A23-56): the Goblin Woods band Lv10-24 works like Newbie (rows reuse a template Id, exact
	-- Targets, about 3 minutes each, the three goals differ). Each daily pays HuntValue(level, 3), the full-set chest
	-- HuntValue(level, 6): one day = 15 minutes of hunting (the template dailies paid 25 for about 3x the work).
	-- Hunt / Plunder keep the PvP rules (Lv15+, no Sprout Shield, at most one) and their sides; Goose is Halo / Horns
	-- only. Lv25+ keeps Templates[].DailyUnits. Vacation follows the band (Config.DailyDayMinutes = 15).
	Woods = {
		MinLevel = 10,
		MaxLevel = 24,
		RewardMinutes = 3,
		ChestMinutes = 6,
		Dailies = {
			{ Id = "Kill", Weight = 3, Monster = "Goblin", Targets = { 12, 13, 14, 15 } }, -- goblins 12~15
			{ Id = "Kill", Weight = 2, Monster = "GoblinBrute", Strict = true, Targets = { 2 } }, -- Goblin Brutes 2
			{ Id = "Release", Weight = 3, Targets = { 4, 5, 6 } }, -- skills that hit monsters 4~6
			{ Id = "Gold", Weight = 3, Targets = { 150, 200, 250 } }, -- hunting gold
			{ Id = "Golden", Weight = 1, Targets = { 1 } }, -- one golden monster
			{ Id = "Goose", Weight = 1, Targets = { 1 } }, -- the Golden Goose tug (Halo / Horns)
			{ Id = "Hunt", Weight = 1, Targets = { 1 } }, -- PvP, Halo
			{ Id = "Plunder", Weight = 1, Targets = { 1 } }, -- PvP, Horns
		},
	},
}

Config.Daily = {
	TimezoneOffset = 9 * 3600, -- KST: the day flips at 00:00 Korea time
	QuestMinutes = 5, -- each Lv10+ daily pays HuntValue(level, 5) (Lv1-9: Config.Quests.Newbie.RewardMinutes)
	ChestMinutes = 10, -- claiming all 3 Lv10+ dailies pays a bonus chest of HuntValue(level, 10) (Lv1-9: Newbie.ChestMinutes)
	ChestTicketChance = 0.10, -- the chest also drops 1 class change ticket with this chance
	-- per missed whole day: 70% of a full day (3 dailies + chest, Config.DailyDayMinutes) at the CURRENT level
	VacationRate = 0.7,
	VacationMaxDays = 3,
	CheckInterval = 30, -- seconds between day-rollover checks for online players
}

function Config.DayIndex(unixTime)
	return math.floor((unixTime + Config.Daily.TimezoneOffset) / 86400)
end

function Config.DailyQuestReward(level) -- gold, xp
	return Config.HuntValue(level, Config.Daily.QuestMinutes)
end

function Config.DailyChestReward(level) -- gold, xp
	return Config.HuntValue(level, Config.Daily.ChestMinutes)
end

-- minutes of hunting one full day of dailies is worth (all dailies + the chest) in the daily band of `level`:
-- Lv1..Quests.Newbie.MaxLevel = Newbie.RewardMinutes x Slots + Newbie.ChestMinutes (10), E12 Woods.MinLevel..MaxLevel
-- = Woods' (3 x 3 + 6 = 15), else Daily's (25)
function Config.DailyDayMinutes(level)
	local nb = Config.Quests.Newbie
	local slots = Config.Quests.Slots
	local lv = tonumber(level) or 1
	if type(nb) == "table" and type(nb.Dailies) == "table" and #nb.Dailies > 0
		and lv <= (tonumber(nb.MaxLevel) or 0) then
		return (tonumber(nb.RewardMinutes) or Config.Daily.QuestMinutes) * slots
			+ (tonumber(nb.ChestMinutes) or Config.Daily.ChestMinutes)
	end
	local wd = Config.Quests.Woods
	if type(wd) == "table" and type(wd.Dailies) == "table" and #wd.Dailies > 0
		and lv >= (tonumber(wd.MinLevel) or math.huge) and lv <= (tonumber(wd.MaxLevel) or 0) then
		return (tonumber(wd.RewardMinutes) or Config.Daily.QuestMinutes) * slots
			+ (tonumber(wd.ChestMinutes) or Config.Daily.ChestMinutes)
	end
	return Config.Daily.QuestMinutes * slots + Config.Daily.ChestMinutes
end

function Config.VacationReward(level, days) -- gold, xp for `days` missed days (clamped)
	local d = math.clamp(days or 0, 0, Config.Daily.VacationMaxDays)
	local g, x = Config.HuntValue(level, Config.DailyDayMinutes(level))
	-- + 1e-6: 360 * 0.7 is 251.99999999999997 in floating point; the documented day pays 252
	return math.floor(g * Config.Daily.VacationRate * d + 1e-6), math.floor(x * Config.Daily.VacationRate * d + 1e-6)
end

----------------------------------------------------------------- Robux change tickets ("변경권")
-- Id 0 = Developer Product not created yet -> buy buttons show "상품 준비 중". After publishing, create two
-- consumable Developer Products on create.roblox.com and paste their ids here.
Config.Products = {
	ClassTicket = { Id = 0, PriceHint = 49, Kind = "Class", Name = "Class Change Ticket" },
	FactionTicket = { Id = 0, PriceHint = 79, Kind = "Faction", Name = "Side Change Ticket" },
}
Config.Tickets = {
	MaxReceiptsKept = 50,
	ReceiptWaitSeconds = 15, -- ProcessReceipt waits this long for the buyer's data to load
}

function Config.ProductByKind(kind)
	for _, p in Config.Products do
		if p.Kind == kind then return p end
	end
	return nil
end

----------------------------------------------------------------- A23-75 game passes (Robux, user 2026-10-08)
-- docs/design/gamepass_server_2026-10-08.md. Prices are the user's ("추천 가격대로"). Id 0 = the pass is not created
-- yet: the shop shows "Coming soon" and the server never asks Roblox about it. After publishing, the user creates the
-- passes on create.roblox.com (the game > Monetization > Passes) and pastes their ids here (launch_ops_checklist).
-- Attr = the Player attribute (true / false) the server keeps while the player owns it. No stat is ever sold (A23-75):
-- 2x XP / 2x Gold double what is EARNED, and that counts for the level cap and the rankings as it is.
Config.GamePasses = {
	XP2 = { Id = 0, Price = 199, Name = "2x XP", Attr = "PassXP2" },
	Gold2 = { Id = 0, Price = 149, Name = "2x Gold", Attr = "PassGold2" },
	VIP = { Id = 0, Price = 249, Name = "VIP", Attr = "PassVIP" },
}
-- where the 2x counts (ProgressionService, once per grant): every XP grant, and gold from these EARNED sources (kills,
-- quests / dailies / vacation / boards / story, the goose, bounties, war chests, drops, the newly made part of the kaiju
-- hunt reward, the underdog sign-on, attendance). Never: Sale, Refund, Plunder, KaijuBank / KaijuTransfer (gold that was
-- already someone's), KaijuBonus (the survive bonus: made from a pouch that already holds the pass, only its cap
-- doubles; A23-75 review 2026-10-08), Penalty, Other (test gold).
Config.PassBoost = {
	Mult = 2,
	GoldSources = { Monster = true, Quest = true, Event = true, Bounty = true, War = true, Loot = true, Kaiju = true,
		SignOn = true, Attendance = true },
	-- the ownership check when a player joins: tries, first wait between them (doubling); when every try fails, the
	-- last answer Roblox gave (saved, data.PassSeen) counts until the next check
	CheckTries = 3,
	CheckWait = 1,
	-- a purchase signal Roblox answers "no" (maybe a cached answer from the join check): asked again this many s after
	-- the signal; still no = ignored (gamepass_3f5dd020_verify, 2026-10-09)
	PurchaseRecheck = { 2, 5 },
	-- the supporter board (A23-75 VIP: "마을 후원자 게시판 이름"): VIP owners of every server, newest first, at most
	-- MaxSupporters display names in GameState SupporterNames (one per line), read again every RefreshSeconds
	SupporterStore = "HaloHorns_Supporters_v1",
	SupporterKey = "List",
	MaxSupporters = 30,
	RefreshSeconds = 300,
	-- A23-75 review 2026-10-08: the shared list is written at most once per player per WriteGap seconds (a hide on / off
	-- spam cannot use up the server's DataStore budget; the write then carries the latest choice)
	WriteGap = 10,
	-- a failed write of the shared list is tried again this many times (each after WriteGap), unless a newer choice
	-- is queued by then
	WriteRetries = 3,
}
-- A23-75 faction looks (halo / horns textures; image dev's Config.LookThemes sets, same ids): sold one game pass each
-- (PassId, Price 99), or A23-77 attendance-only (Unlock.Attendance = days collected, never sold). Name <= 12 letters
-- (the shop slot); Icon = a Config.UIArt key; Order = the shop order. Owned looks: Player attribute LooksOwned (ids,
-- comma-separated, in Order); worn: LookOn (an id of the player's own faction, or "").
Config.Looks = {
	HaloIce = { Faction = "Halo", PassId = 0, Price = 99, Name = "Ice Halo", Icon = "LookHaloIce", Order = 1 },
	HaloGold = { Faction = "Halo", PassId = 0, Price = 99, Name = "Gold Halo", Icon = "LookHaloGold", Order = 2 },
	HornsLava = { Faction = "Horns", PassId = 0, Price = 99, Name = "Lava Horns", Icon = "LookHornsLava", Order = 3 },
	HornsShadow = { Faction = "Horns", PassId = 0, Price = 99, Name = "Shadow Horns", Icon = "LookHornsShadow", Order = 4 },
	HaloSprout = { Faction = "Halo", Unlock = { Attendance = 14 }, Name = "Sprout Halo", Icon = "LookHaloSprout", Order = 5 },
	HornsSprout = { Faction = "Horns", Unlock = { Attendance = 14 }, Name = "Sprout Horns", Icon = "LookHornsSprout", Order = 6 },
	HaloStarlight = { Faction = "Halo", Unlock = { Attendance = 50 }, Name = "Star Halo", Icon = "LookHaloStarlight", Order = 7 },
	HornsStarlight = { Faction = "Horns", Unlock = { Attendance = 50 }, Name = "Star Horns", Icon = "LookHornsStarlight",
		Order = 8 },
	HaloPlatinum = { Faction = "Halo", Unlock = { Attendance = 100 }, Name = "Plat Halo", Icon = "LookHaloPlatinum", Order = 9 },
	HornsPlatinum = { Faction = "Horns", Unlock = { Attendance = 100 }, Name = "Plat Horns", Icon = "LookHornsPlatinum",
		Order = 10 },
}

-- the look ids in shop order
function Config.LookOrder()
	local ids = {}
	for id in Config.Looks do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local oa, ob = tonumber(Config.Looks[a].Order) or 0, tonumber(Config.Looks[b].Order) or 0
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	return ids
end

-- A23-75 save fields (additive, Version stays 3): Looks = { Owned = { [look id] = os.time() unlocked without a pass
-- (attendance) }, On = the worn id or "" }; PassSeen = { [pass kind or look id] = the last ownership answer from
-- Roblox (true / false) }. Unknown ids and broken values are dropped; returns the repaired Looks and PassSeen.
function Config.SanitizeLooks(looks, seen)
	local out = { Owned = {}, On = "" }
	if type(looks) == "table" then
		if type(looks.Owned) == "table" then
			for id, t in looks.Owned do
				if type(id) == "string" and Config.Looks[id] and type(t) == "number" and t == t and t >= 0
					and t ~= math.huge then
					out.Owned[id] = math.floor(t)
				end
			end
		end
		if type(looks.On) == "string" and (looks.On == "" or Config.Looks[looks.On]) then out.On = looks.On end
	end
	local passSeen = {}
	if type(seen) == "table" then
		for id, v in seen do
			if type(id) == "string" and type(v) == "boolean" and (Config.GamePasses[id] or Config.Looks[id]) then
				passSeen[id] = v
			end
		end
	end
	return out, passSeen
end

----------------------------------------------------------------- visuals
Config.Visuals = {
	MarkScalePerRank = 0.15, -- halo/horn scale = 1 + 0.15 * (rank - 1)
	SackThresholdsPerLevel = { 10, 40, 120, 300, 800 }, -- sack tier = count of thresholds t with gold >= t * level
	SackSizes = { 0.8, 1.2, 1.6, 2.1, 2.8 }, -- ball diameter per tier (tier 0 = no sack)
	NametagMaxDistance = 120,
	MaxDamagePopups = 25,
	FxCullDistance = 150,
	GrudgeSackColor = Color3.fromRGB(110, 40, 150),
	GhostColor = Color3.fromRGB(170, 210, 255),
	GhostTransparency = 0.6,
	GhostHeight = 4, -- studs above the head (x character scale)
	CapeColor = Color3.fromRGB(20, 20, 25),
	CrackedHaloColor = Color3.fromRGB(200, 200, 200),
	GrayAuraColor = Color3.fromRGB(160, 160, 170),
	BullyColor = Color3.fromRGB(255, 50, 50),
	KaijuFireColor = Color3.fromRGB(255, 90, 30),
	ShakeOwnRelease = 0.6, -- camera shake magnitude (studs) for your own release / stomp hit
	ShakeNearRelease = 0.25, -- other players' releases within ShakeNearDistance
	ShakeNearDistance = 40,
	HugeNumberScale = 2.5, -- release total damage number scale
}

-- A23-75 / A23-77 looks (이미지 생성 2 dd217fc, 검수 OK): a worn look (player attribute LookOn = one of these ids, set by
-- the server; Config.Looks sells / awards them under the same id) recolours the rank's own mark mesh - TextureID per
-- rank, R1 and R2 share one 64 px palette - so the shape stays the rank's (a bought look never passes for a higher
-- rank). Glow = the halo's light, Sparkle = the top rank's sparkles (round, no rays). Ids: UiSandbox upload (이미지 개발)
Config.LookThemes = {
	HaloIce = { Faction = "Halo", R1R2 = "rbxassetid://137659488563185", R3 = "rbxassetid://108650983430092", R4 = "rbxassetid://76422994410695", R5 = "rbxassetid://130485697124157",
		Glow = Color3.fromRGB(170, 225, 255), Sparkle = Color3.fromRGB(225, 245, 255) }, -- shop
	HaloGold = { Faction = "Halo", R1R2 = "rbxassetid://124557820913278", R3 = "rbxassetid://124870710556969", R4 = "rbxassetid://104125803475842", R5 = "rbxassetid://121454866183175",
		Glow = Color3.fromRGB(255, 170, 110), Sparkle = Color3.fromRGB(255, 120, 130) }, -- shop
	HornsLava = { Faction = "Horns", R1R2 = "rbxassetid://80238307725390", R3 = "rbxassetid://82767525442280", R4 = "rbxassetid://78943828071190", R5 = "rbxassetid://85082048989349",
		Glow = Color3.fromRGB(255, 120, 40), Sparkle = Color3.fromRGB(255, 190, 90) }, -- shop
	HornsShadow = { Faction = "Horns", R1R2 = "rbxassetid://77090857785800", R3 = "rbxassetid://134445622258892", R4 = "rbxassetid://97761533502616", R5 = "rbxassetid://112202207856048",
		Glow = Color3.fromRGB(160, 100, 255), Sparkle = Color3.fromRGB(215, 190, 255) }, -- shop
	HaloSprout = { Faction = "Halo", R1R2 = "rbxassetid://86617186225584", R3 = "rbxassetid://126112718924134", R4 = "rbxassetid://70457193636840", R5 = "rbxassetid://84485205872223",
		Glow = Color3.fromRGB(150, 235, 120), Sparkle = Color3.fromRGB(210, 255, 180) }, -- attendance 14 days
	HornsSprout = { Faction = "Horns", R1R2 = "rbxassetid://98729066506053", R3 = "rbxassetid://111198088905000", R4 = "rbxassetid://92425781835056", R5 = "rbxassetid://88143987545459",
		Glow = Color3.fromRGB(150, 235, 120), Sparkle = Color3.fromRGB(210, 255, 180) }, -- attendance 14 days
	HaloStarlight = { Faction = "Halo", R1R2 = "rbxassetid://79900622177360", R3 = "rbxassetid://106125508143560", R4 = "rbxassetid://120783323880170", R5 = "rbxassetid://112919940044810",
		Glow = Color3.fromRGB(120, 150, 255), Sparkle = Color3.fromRGB(255, 220, 120) }, -- attendance 50 days
	HornsStarlight = { Faction = "Horns", R1R2 = "rbxassetid://87973276568961", R3 = "rbxassetid://120704216649593", R4 = "rbxassetid://77284887873440", R5 = "rbxassetid://114837008556596",
		Glow = Color3.fromRGB(120, 150, 255), Sparkle = Color3.fromRGB(255, 220, 120) }, -- attendance 50 days
	HaloPlatinum = { Faction = "Halo", R1R2 = "rbxassetid://129286691726526", R3 = "rbxassetid://125145984859168", R4 = "rbxassetid://116074292544544", R5 = "rbxassetid://73047553511936",
		Glow = Color3.fromRGB(210, 235, 255), Sparkle = Color3.fromRGB(255, 255, 255) }, -- attendance 100 days
	HornsPlatinum = { Faction = "Horns", R1R2 = "rbxassetid://118578097813756", R3 = "rbxassetid://98158447043587", R4 = "rbxassetid://88887895520232", R5 = "rbxassetid://127877205287600",
		Glow = Color3.fromRGB(210, 235, 255), Sparkle = Color3.fromRGB(255, 255, 255) }, -- attendance 100 days
}

-- 계급 장식 3D (이미지 생성 1 45b6220, user OK "좋아, 넣어"): the rank's own halo / horns model replaces the drawn mark
-- once it is in Studio. ServerStorage[Folder] holds MeshParts (or Models with one mesh) named as below, imported at their
-- real size (studs, built for a 1.2-stud head, origin = the bottom center; files art/models/acc/*.glb). Horns sink
-- HornsDepth into the head top, halos float HaloGap above it (both x head height / HeadRef); Yaw turns the model to the
-- head's front (0: 이미지 생성 1 turned the models to face Roblox -Z before the import, 427baf8). A missing model keeps
-- the drawn mark.
Config.Visuals.MarkModels = {
	Folder = "MarkModels",
	Halo = { "Acc_HaloR1", "Acc_HaloR2", "Acc_HaloR3", "Acc_HaloR4", "Acc_HaloR5" },
	Horns = { "Acc_HornsR1", "Acc_HornsR2", "Acc_HornsR3", "Acc_HornsR4", "Acc_HornsR5" },
	HeadRef = 1.2,
	HaloGap = 0.3,
	HornsDepth = 0.06,
	Yaw = 0,
	HaloLight = { Range = 8, Brightness = 1.2 }, -- the old halo disc's light
	-- R5: a soft gold glow / embers as an effect (이미지 생성 1: "금빛 번짐·불씨는 효과로")
	Glow = { Rank = 5, Rate = 5, Size = 0.25, Halo = Color3.fromRGB(255, 225, 130), Horns = Color3.fromRGB(255, 140, 60) },
	-- 3rd idea round #6 (검수 2026-10-07): R1 / R2 were lost in hair, so their clone is x1.4 / x1.2 (ranks 3-5 x1).
	-- The mark stands on the head top, or on the top of a hat / hair accessory when that is higher, at most
	-- MaxRise x (head height / HeadRef) above the head top (a giant hat keeps it near the head)
	RankScale = { 1.4, 1.2 },
	MaxRise = 1.0,
}

function Config.SackTier(gold, level)
	local tier = 0
	for _, t in Config.Visuals.SackThresholdsPerLevel do
		if gold >= t * math.max(1, level) then tier += 1 end
	end
	return tier
end

----------------------------------------------------------------- remotes / misc
-- minimum seconds between two accepted calls of the same remote from the same player (Util.RateLimit)
Config.RateLimits = {
	ChooseFaction = 1, ChooseClass = 1, StoryAction = 0.4, BoardAction = 0.3, Swing = 0.1, Release = 0.25, SetAutoAttack = 0.25,
	UpgradeWeapon = 0.3, SellWeapon = 0.3, Rebirth = 1, SwitchFaction = 1, ChangeClass = 1, Travel = 0.5,
	RerollQuest = 0.5, ClaimQuest = 0.3, ClaimVacation = 1, UsePotion = 0.3, BuyPotion = 0.3,
	UseItem = 0.4, EquipWeapon = 0.3, SellMaterials = 1, SetAnnounceName = 0.5, SetTitle = 0.5, SetLook = 0.5, GhostHold = 2.7, -- GhostHold: a bit under the 3 s client cooldown
	SetSettings = 1, -- BB2: the client sends at most one blob per this + 0.05 s (a dropped call gets no answer)
	UseSkill = 0.1, -- SKL-2: skill presses (the 0.5 s gap between skills is SkillService's)
	UiMetric = 2, -- BB38: window-open reports (each window counts once a session)
}

----------------------------------------------------------------- beta metrics (BB38, TelemetryService)
-- docs/design/beta_basics_2026-10-05.md BB38 + 검수 2026-10-07 (economy, friends) + emergent_play_watch §2. Roblox
-- AnalyticsService only; no names, UserIds or free text: every event name and field comes from these lists, zone /
-- monster ids or gold sources. Steps = the onboarding funnel in order (each once per account). UiIds = the windows the
-- client reports with c->s "UiMetric"(id) when it opens one (WindowOpen_<id>, once a session each; game dev 1 sends
-- them from Panels / the Tab list). AwayAfter = s with no own action while auto combat is ON (AutoAwayMinutes).
-- EnhanceFailLeave = s after a failed enhance a leave is counted. SameKindStreak = kills of one kind in a row worth a
-- note. ReturnActs = the first actions logged for a returning player. FriendCheckMax = IsFriendsWith calls per join.
-- Debug = print every call (nil = Studio only).
Config.Analytics = {
	-- A23-68 #5 (the first 3 minutes; renumbered before the beta, nothing is public yet): MeadowArrive, FirstHit,
	-- FirstKill, FirstSkillHit and ForgeArrive between the old steps. A23-71 D5 / S13: the first skill comes at Lv5, after
	-- the first weapon, and Auto Battle opens after it (S0 trial b is a skill hit), so FirstSkillHit sits right before
	-- AutoUnlocked (in the order players reach it, no false drop-off). A23-74: the Forge and the first weapon now come
	-- right after the acceptance, before the meadow
	Steps = { "IntroDone", "Faction", "Class", "FirstMissionAccept", "ForgeArrive", "FirstWeapon", "MeadowArrive",
		"FirstHit", "FirstKill", "FirstMissionDone", "FirstSkillHit", "AutoUnlocked", "Level10" },
	UiIds = { "Menu", "Items", "Bag", "Skills", "Character", "Ranking", "Journal", "Board", "Settings", "Help", "News",
		"Travel", "WorldMap", "WeaponShop", "PotionShop", "Shop", "Rebirth", "Altar", "Class", "PlayerList", "Feedback" },
	AwayAfter = 300,
	EnhanceFailLeave = 300,
	SameKindStreak = 30,
	ReturnActs = 3,
	FriendCheckMax = 12,
	Debug = nil,
}

----------------------------------------------------------------- keys + settings (BB1 / BB2)
-- Contract: docs/design/beta_basics_2026-10-05.md BB1 / BB2; A23-21: only PC keyboard keys can be changed in the beta,
-- the gamepad layout is fixed and touch-only devices show button names instead of keys.
-- Actions (in order: the KeyMap order and the settings list order):
--   Id, Group ("Combat" | "Potion" | "Window" | "Other"), Key = Enum.KeyCode name ("" = unbound), Pad = fixed gamepad
--   button ("" = none), Label / LabelEn = the action's name, Button / ButtonEn = what a touch-only device calls it,
--   Flag = "Table.Field" under Config (the action exists only while that is true), Window = Panels id (Group "Window"),
--   Alt = an older Panels window the key opens until Window is registered (the HUD tile's Alt), Soon = the key answers
--   before its window exists, like its HUD tile ('coming soon'; Ranking = the ranking list, Journal = the HUD quest list).
-- Live rule: Flag on and, for the Window group, the Panels window (or its Alt) registered or Soon (client). Non-live
-- actions hold no key and never take part in swaps. PadWired = the pad buttons that already work (BB21 wires the rest).
-- User 2026-10-08 (MMO keys): I items, E equipment (Hero), K skills, M map, Q quest list -> the skills moved to Z / X / C
-- and Interact (the prompts) to G; I is no longer reserved (Keybinds sinks Roblox's I / O camera zoom while one of our
-- actions holds the key).
Config.Keybinds = {
	Actions = {
		{ Id = "Attack", Group = "Combat", Key = "F", Pad = "ButtonR2", Label = "Attack", LabelEn = "Attack", Button = "Attack button", ButtonEn = "Attack button" },
		{ Id = "SkillQ", Group = "Combat", Key = "Z", Pad = "ButtonL2", Label = "Skill", LabelEn = "Skill", Button = "Skill button", ButtonEn = "Skill button" },
		{ Id = "SkillZ", Group = "Combat", Key = "X", Pad = "ButtonL1", Label = "Skill 2", LabelEn = "Skill 2", Button = "Skill 2 button", ButtonEn = "Skill 2 button", Flag = "Skills.ZEnabled" },
		{ Id = "SkillX", Group = "Combat", Key = "C", Pad = "ButtonR3", Label = "Skill 3", LabelEn = "Skill 3", Button = "Skill 3 button", ButtonEn = "Skill 3 button", Flag = "Skills.XEnabled" },
		{ Id = "Auto", Group = "Combat", Key = "R", Pad = "ButtonR1", Label = "Auto Battle", LabelEn = "Auto Battle", Button = "Auto Battle button", ButtonEn = "Auto Battle button" },
		{ Id = "GhostHold", Group = "Combat", Key = "T", Pad = "DPadRight", Label = "Ghost hold", LabelEn = "Ghost hold", Button = "Ghost button", ButtonEn = "Ghost button" },
		{ Id = "PotionHP", Group = "Potion", Key = "One", Pad = "DPadUp", Label = "HP potion", LabelEn = "HP potion", Button = "HP potion button", ButtonEn = "HP potion button" },
		{ Id = "PotionMP", Group = "Potion", Key = "Two", Pad = "DPadDown", Label = "MP potion", LabelEn = "MP potion", Button = "MP potion button", ButtonEn = "MP potion button" },
		-- KeySet "Prompt" + NoClear: the default ProximityPrompt UI must be able to draw the key (review of 27246d1)
		{ Id = "Interact", Group = "Other", Key = "G", Pad = "ButtonX", Label = "Interact", LabelEn = "Interact", Button = "Interact button", ButtonEn = "Interact button",
			KeySet = "Prompt", NoClear = true },
		{ Id = "Upgrade", Group = "Other", Key = "U", Pad = "", Label = "Next weapon", LabelEn = "Next weapon", Button = "Next weapon card", ButtonEn = "Next weapon card" },
		{ Id = "Bag", Group = "Window", Key = "I", Pad = "", Label = "Bag", LabelEn = "Bag", Button = "Bag button", ButtonEn = "Bag button", Window = "Bag", Alt = "Items" },
		{ Id = "Character", Group = "Window", Key = "E", Pad = "", Label = "Hero", LabelEn = "Hero", Button = "Menu → Hero", ButtonEn = "Menu → Hero", Window = "Character", Soon = true },
		{ Id = "Skills", Group = "Window", Key = "K", Pad = "", Label = "Skills", LabelEn = "Skills", Button = "Menu → Skills", ButtonEn = "Menu → Skills", Window = "Skills", Soon = true },
		{ Id = "Ranking", Group = "Window", Key = "L", Pad = "", Label = "Ranking", LabelEn = "Ranking", Button = "Menu → Ranking", ButtonEn = "Menu → Ranking", Window = "Ranking", Soon = true },
		{ Id = "Help", Group = "Window", Key = "H", Pad = "", Label = "Help", LabelEn = "Help", Button = "Menu → Help", ButtonEn = "Menu → Help", Window = "Help" },
		{ Id = "Journal", Group = "Window", Key = "Q", Pad = "", Label = "Quest list", LabelEn = "Quest list", Button = "Quest list", ButtonEn = "Quest list", Window = "Journal", Soon = true },
		{ Id = "Map", Group = "Other", Key = "M", Pad = "DPadLeft", Label = "Map", LabelEn = "Map", Button = "Map button", ButtonEn = "Map button" },
		{ Id = "Menu", Group = "Other", Key = "B", Pad = "ButtonY", Label = "Menu", LabelEn = "Menu", Button = "Menu button", ButtonEn = "Menu button" },
	},
	-- Roblox / the default camera use these (O zoom - I is the bag key since 10/08, its zoom sunk by Keybinds -, Comma /
	-- Period + arrows + PageUp/PageDown camera, W A S D move,
	-- Space jump, Shift lock, Tab player list, / and ` chat, Esc menu, F9-F12 Studio / developer keys). A key Roblox
	-- turns out to swallow in a Studio Play check moves here.
	Reserved = { "Escape", "Slash", "Tab", "Backquote", "Return", "KeypadEnter", "Space", "LeftShift", "RightShift",
		"W", "A", "S", "D", "O", "Comma", "Period", "PageUp", "PageDown", "Up", "Down", "Left", "Right",
		"F9", "F10", "F11", "F12" },
	-- filled below: A-Z, Zero-Nine, F1-F8, KeypadZero-KeypadNine, symbols, LeftControl, LeftAlt, CapsLock (minus Reserved)
	Allowed = {},
	PadWired = { Attack = true, SkillQ = true }, -- R2 attack, L2 skill (as before BB1); BB21 wires the other Pad buttons
	MaxKeyLen = 24, -- longest key name a save may hold
	Labels = { LeftControl = "Ctrl", LeftAlt = "Alt", CapsLock = "Caps", Minus = "-", Equals = "=", LeftBracket = "[",
		RightBracket = "]", Semicolon = ";", Quote = "'", BackSlash = "\\" }, -- + digits / keypad digits below
	None = "None", -- label of an unbound action
	NoneEn = "None",
}
do
	local KB = Config.Keybinds
	for c = string.byte("A"), string.byte("Z") do table.insert(KB.Allowed, string.char(c)) end
	for i, n in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" } do
		table.insert(KB.Allowed, n)
		table.insert(KB.Allowed, "Keypad" .. n)
		KB.Labels[n] = tostring(i - 1)
		KB.Labels["Keypad" .. n] = "Num" .. tostring(i - 1)
	end
	for i = 1, 8 do table.insert(KB.Allowed, "F" .. i) end
	for _, n in { "Minus", "Equals", "LeftBracket", "RightBracket", "Semicolon", "Quote", "BackSlash", "LeftControl", "LeftAlt", "CapsLock" } do
		table.insert(KB.Allowed, n)
	end
	KB.ReservedSet, KB.AllowedSet, KB.ById = {}, {}, {}
	for _, n in KB.Reserved do KB.ReservedSet[n] = true end
	for _, n in KB.Allowed do
		if not KB.ReservedSet[n] then KB.AllowedSet[n] = true end
	end
	for _, a in KB.Actions do KB.ById[a.Id] = a end
	-- keys the default ProximityPrompt UI draws: letters, digits, F1-F8, Ctrl, Alt (no keypad / symbols / Caps)
	KB.PromptSet = {}
	for c = string.byte("A"), string.byte("Z") do KB.PromptSet[string.char(c)] = true end
	for _, n in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "LeftControl", "LeftAlt" } do
		KB.PromptSet[n] = true
	end
	for i = 1, 8 do KB.PromptSet["F" .. i] = true end
	for n in KB.PromptSet do
		if not KB.AllowedSet[n] then KB.PromptSet[n] = nil end
	end
end

-- may this action hold this key? (KeySet "Prompt" limits Interact; NoClear forbids "")
function Config.KeyAllowedFor(actionId, name)
	local KB = Config.Keybinds
	local def = KB.ById[actionId]
	if type(def) ~= "table" or type(name) ~= "string" then return false end
	if name == "" then return def.NoClear ~= true end
	if not Config.KeyUsable(name) then return false end
	if def.KeySet == "Prompt" then return KB.PromptSet[name] == true end
	return true
end

-- true when the action's Flag ("Table.Field" under Config) is on; actions without a Flag always are
function Config.KeyFlagOn(def)
	if type(def) ~= "table" then return false end
	if def.Flag == nil then return true end
	local node = Config
	for part in string.gmatch(tostring(def.Flag), "[^%.]+") do
		if type(node) ~= "table" then return false end
		node = node[part]
	end
	return node == true
end

-- a key a player may bind: an Allowed key name (24 chars or fewer) that Roblox does not use (not Reserved)
function Config.KeyUsable(name)
	local KB = Config.Keybinds
	return type(name) == "string" and #name <= KB.MaxKeyLen and KB.AllowedSet[name] == true
end

function Config.KeyReserved(name)
	return type(name) == "string" and Config.Keybinds.ReservedSet[name] == true
end

-- 'One' -> '1', 'KeypadOne' (or 'Keypad1') -> 'Num1', 'LeftControl' -> 'Ctrl', '' -> 'None', letters stay
function Config.KeyLabel(name, en)
	local KB = Config.Keybinds
	if type(name) ~= "string" or name == "" then return en == true and KB.NoneEn or KB.None end
	local label = KB.Labels[name]
	if label then return label end
	local digit = string.match(name, "^Keypad(%d)$")
	if digit then return "Num" .. digit end
	return name
end

-- BB1 / BB2: saved sparse Keys + live set -> full map { [actionId] = key name or "" }, plus the live default-only
-- actions whose default key was already taken (reported once per session by the client). Never wipes a player's keys:
--   1. explicit entries first, in Actions order; an explicit key already taken becomes "";
--   2. a live action without an explicit entry gets its default, or "" (and is reported) when that key is taken.
-- liveSet = { [actionId] = true } (client: Flag on + Panels window registered); nil = every action whose Flag is on
-- (server: it has no windows, and window keys never change the labels of the other actions).
function Config.KeyMap(sparse, liveSet)
	local KB = Config.Keybinds
	local keys = type(sparse) == "table" and sparse or {}
	local map, taken, collisions = {}, {}, {}
	local function live(def)
		if liveSet ~= nil then return type(liveSet) == "table" and liveSet[def.Id] == true end
		return Config.KeyFlagOn(def)
	end
	local function explicit(def)
		local v = keys[def.Id]
		return type(v) == "string" and Config.KeyAllowedFor(def.Id, v)
	end
	for _, def in KB.Actions do
		map[def.Id] = ""
		if live(def) and explicit(def) then
			local v = keys[def.Id]
			if v ~= "" and not taken[v] then
				map[def.Id], taken[v] = v, def.Id
			end
		end
	end
	for _, def in KB.Actions do
		if live(def) and not explicit(def) and def.Key ~= "" then
			if taken[def.Key] then
				table.insert(collisions, def.Id)
			else
				map[def.Id], taken[def.Key] = def.Key, def.Id
			end
		end
	end
	-- a NoClear action (Interact) always ends with a key: if its key went to another action, it takes its default
	-- back and that other action loses it (it is reported like a collision)
	for _, def in KB.Actions do
		if def.NoClear and live(def) and map[def.Id] == "" and def.Key ~= "" then
			local holder = taken[def.Key]
			if holder and holder ~= def.Id then
				map[holder] = ""
				table.insert(collisions, holder)
				local i = table.find(collisions, def.Id)
				if i then table.remove(collisions, i) end
			end
			map[def.Id], taken[def.Key] = def.Key, def.Id
		end
	end
	return map, collisions
end

-- '{Auto}' / '{GhostHold}' / '{Map}' (any Keybinds action id) -> the key label from a KeyMap map; other {…} stay
function Config.FillKeys(text, map, en)
	if type(text) ~= "string" or not string.find(text, "{", 1, true) then return text end
	return (string.gsub(text, "{(%w+)}", function(id)
		if not Config.Keybinds.ById[id] then return nil end
		return Config.KeyLabel(type(map) == "table" and map[id] or "", en)
	end))
end

-- BB2 saved settings: value rules (defaults: Config.Data.Defaults.Settings). Text = the settings window (BB3) + toasts.
Config.Settings = {
	-- Settings.V. 2 (A23-78, user 2026-10-08): key hints are off by default now; a blob saved before V2 (V < 2 or no V)
	-- drops its old KeyBadges once (SanitizeSettings), every other value stays; from V2 on the player's own pick stays.
	-- V3 (A23-65, 검수 2026-10-09): the camera default is Free; a blob saved before V3 gets Cam = Free once, a Follow
	-- picked from V3 on stays
	Version = 3,
	MaxBlobKeys = 16, -- top-level keys of one SetSettings blob (V, Keys, the eight values, Seq)
	Defs = {
		Sfx = { Type = "Number", Min = 0, Max = 1, Step = 0.1 },
		Shake = { Type = "Bool" },
		DmgNum = { Type = "Enum", Options = { "All", "Off" } },
		Tags = { Type = "Enum", Options = { "All", "Near", "Off" } },
		KeyBadges = { Type = "Bool" }, -- user 2026-10-08: off by default (keys can be changed anyway; the row turns them on)
		Lang = { Type = "Enum", Options = { "Auto", "ko", "en" } },
		BagSort = { Type = "Enum", Options = { "Default", "Grade", "Count" } },
		Cam = { Type = "Enum", Options = { "Follow", "Free" } }, -- A23-65: Follow = the camera turns behind me while I walk (default Free, user 10/08)
	},
	Order = { "Sfx", "Shake", "KeyBadges", "DmgNum", "Tags", "Lang", "BagSort", "Cam" },
	Text = {
		Sfx = "Sound effects", SfxEn = "Sound effects",
		Shake = "Screen shake", ShakeEn = "Screen shake",
		DmgNum = "Damage numbers", DmgNumEn = "Damage numbers",
		Tags = "Other players' name tags", TagsEn = "Other players' name tags",
		KeyBadges = "Key hints", KeyBadgesEn = "Key hints",
		Lang = "Language", LangEn = "Language",
		BagSort = "Bag order", BagSortEn = "Bag order",
		Cam = "Camera", CamEn = "Camera",
		Options = {
			All = "All", AllEn = "All", Off = "Off", OffEn = "Off", Near = "Nearby only", NearEn = "Nearby only",
			Auto = "Auto", AutoEn = "Auto", ko = "한국어", koEn = "한국어", en = "English", enEn = "English",
			Default = "Default", DefaultEn = "Default", Grade = "By grade", GradeEn = "By grade", Count = "By count", CountEn = "By count",
			Follow = "Follow", FollowEn = "Follow", Free = "Free", FreeEn = "Free",
		},
		On = "On", OnEn = "On",
		Off = "Off", OffEn = "Off",
		-- (action name, key) once per action per session: a new action's default key was already one of my keys
		KeyCollision = "New action [%s] has no key: %s is already used. Pick one in Settings.",
		KeyCollisionEn = "New action [%s] has no key: %s is already used. Pick one in Settings.",
		Reserved = "Roblox uses that key", ReservedEn = "Roblox uses that key",
		NotAllowed = "That key can't be used", NotAllowedEn = "That key can't be used",
		Swapped = "Swapped the keys %s and %s", SwappedEn = "Swapped the keys %s and %s", -- (key label, key label)
	},
}

-- A23-48 (user 2026-10-06 evening): the game shows English only (UIKit.Lang decides for the modules with KO / EN twins);
-- new window texts are written in English only
Config.BuildLabel = "beta-prep 2026.10.09" -- shown in the settings footer (bump with a release)

----------------------------------------------------------------- environments + ops safety (시스템 점검 1회차, 2026-10-09)
-- Env: which copy of the game this server is. Names[<place id>] = "Beta" | "Live" is filled when those places are published
-- (docs/design/launch_ops_checklist.md); every other place (the dev place, Studio) is "Dev". Config.StoreName(base) is the
-- DataStore name of a store in this environment: Dev keeps the names that already exist (nothing moves), Beta and Live get
-- "_Beta" / "_Live" appended so a test never touches the real saves, rankings or the supporter list.
Config.Env = { Default = "Dev", Names = {} }

function Config.EnvName()
	local ok, id = pcall(function() return game.PlaceId end)
	local name = ok and type(id) == "number" and Config.Env.Names[id] or nil
	if name == "Beta" or name == "Live" then return name end
	return Config.Env.Default
end

function Config.StoreName(base)
	local env = Config.EnvName()
	if env == "Beta" or env == "Live" then return base .. "_" .. env end
	return base
end

-- ServerErrorService: ScriptContext.Error + a slow tick -> ONE analytics event "ServerError" (fields: script, message, kind),
-- at most MaxPerMinute a minute for the server; the last Keep records are kept and saved (Store, every StoreSeconds and at
-- the close) for Studio's DebugCommand("Errors"). SlowSeconds = a Heartbeat longer than this; SlowIgnoreFirst = the world
-- builds in the first seconds.
Config.ServerErrors = { MaxPerMinute = 5, Keep = 50, ScriptMax = 40, MessageMax = 80, SlowSeconds = 0.5, SlowIgnoreFirst = 30,
	StoreSeconds = 120, Store = "HaloHorns_Errors_v1" }

-- SwitchService: the live switchboard. One document (Store / Key) read every Interval seconds; only the switches below are
-- applied (Type "Bool" or "Number" with Min / Max), the rest of the document is ignored. A switch that is not set keeps its
-- Default; a failed read keeps the last answer.
Config.Switches = {
	Store = "HaloHorns_Switches_v1",
	Key = "Live",
	Interval = 60,
	Defs = {
		PassSales = { Type = "Bool", Default = true }, -- the screen's pass / look [Buy] buttons (a bought pass keeps working)
		Halloween = { Type = "Bool", Default = true }, -- Config.Halloween.Enabled follows it
		CrownWar = { Type = "Bool", Default = true }, -- war points and rounds
		Goose = { Type = "Bool", Default = true }, -- no new goose
	},
}

-- BB3 settings window (user 2026-10-06: class change, rebirth, opening, name hiding and vacation are settings rows;
-- A23-48: no language row). SettingsUI.luau builds it; Sfx / Shake / KeyBadges labels come from Config.Settings.Text*En.
Config.Settings.Window = {
	Title = "Settings",
	TabMain = "Settings", TabKeys = "Keys",
	Open = "Open", Watch = "Watch", Change = "Change",
	Class = "Change Class",
	Rebirth = "Rebirth", RebirthReady = "Rebirth (ready!)",
	Intro = "Replay Opening", IntroUnsafe = "You can replay the opening inside a town.",
	Vacation = "Vacation Bonus",
	Nickname = "Nickname", -- until the Character window (BB8) holds it
	NameHide = "Hide my name", -- + Config.Announce.Text.SettingNotesEn under it
	Keys = "Key Settings",
	On = "On", Off = "Off",
	SfxValue = "%d%%",
	Footer = "%s · place v%d · server %s · %d/%d players", -- (BuildLabel, PlaceVersion, JobId:sub(1, 8), n, max)
	Studio = "studio",
	SaveOff = "Saving is off on this server.",
	-- [Keys] tab
	KeysHint = "Pick an action, then press its new key. Esc cancels.",
	Press = "Press a key (5 s)",
	Clear = "Clear", None = "None",
	Reset = "Default Keys", ResetTitle = "Default keys", ResetBody = "Put every key back the way it was at the start?",
	ResetOk = "Reset",
	NoKeyboard = "No keyboard here. Use the buttons on the screen.",
	PadTitle = "Gamepad buttons (fixed)",
	Groups = { Combat = "Combat", Potion = "Potions", Window = "Windows", Other = "Other" },
	Pad = { ButtonR2 = "R2", ButtonL2 = "L2", ButtonR1 = "R1", ButtonL1 = "L1", ButtonX = "X", ButtonY = "Y", ButtonA = "A",
		ButtonB = "B", DPadUp = "D-pad Up", DPadDown = "D-pad Down", DPadLeft = "D-pad Left", DPadRight = "D-pad Right" },
}

-- BB15 help window + the news window (SettingsUI.luau; A23-48 English only). "Controls" is built from my live keys
-- (TouchLines on touch-only devices). Rules checked against Config and the services on 2026-10-06; the bully numbers
-- come from Config.Bully. At most 4 lines a topic (phones); the lines are shown as they are (never string.format them).
Config.Help = {
	Title = "Help", NewsTitle = "News",
	GuideAgain = "Meet the Guide Again", BackToHelp = "< Help", TalkToGuide = "Talk to the Guide",
	CameraLine = "Hold the right mouse button and drag to turn the camera.", -- A23-51: right drag only
	-- A23-81 (user 2026-10-08): the keys tip again (the Lv5 card shows it once): a line under the keys + a button
	KeysTip = "Tip: You can change your keys in Settings!", KeysButton = "Key settings",
	TouchLines = {
		"Tap the buttons on the screen to attack, use skills and drink potions.",
		"Drag with one finger to turn the camera.",
	},
	Topics = {
		{ Id = "Controls", Title = "Controls", Lines = {} },
		{ Id = "Combat", Title = "Combat & Auto Battle", Lines = {
			"One press = one attack. Holding it down won't repeat it.",
			"Your first skill comes at Lv 5. It costs 20 MP; wait 3 s to use it again.", -- A23-71 D6 / S14
			"Finish the Crown Shard side quest to unlock Auto Battle. It only hits monsters.",
			"No input for 20 minutes? Roblox will disconnect you.",
		} },
		{ Id = "Honor", Title = "Honor & Infamy", Lines = {
			"Knights earn Honor and the Horn Legion earns Infamy, from fair fights and story choices.",
			"Artisan Guild: each success with a scroll you hunted yourself earns Artisan Fame.",
			"A free side switch at the Altar resets your old side's points to 0.",
			"Each week's top 3 get a title and +10% XP and drops the next week.",
		} },
		{ Id = "Sprout", Title = "Sprout Shield & Bullies", Lines = {
			"Sprout Shield: no PvP until you reach Lv 15 and play for 1 hour.",
			string.format("KO someone under %d%% of your power, or who respawned less than %d s ago: Bully!",
				math.floor(Config.Bully.WeakPowerRatio * 100 + 0.5), Config.Bully.FreshSpawnSeconds),
			Config.Plural(string.format("KO the same player %d times in %d minutes: Bully too!", Config.Bully.RepeatKOs,
				math.floor(Config.Bully.RepeatWindow / 60))),
			"Bullies get no Auto Battle, and half XP and drops.",
		} },
		{ Id = "Wanted", Title = "Wanted Stars & Grudge Sacks", Lines = {
			"When the Horn Legion KOs a Knight, they get a Wanted star (max 5).",
			"Knights who KO a Wanted player win the Bounty gold.",
			"Stolen gold goes in the thief's Grudge Sack. After 45 s in PvP, it's theirs.",
			"If a Knight catches the thief within 45 s, you get 120% back.",
		} },
		{ Id = "Events", Title = "Golden Goose, Kaiju & Rebirth", Lines = {
			"Golden Goose: every 10 minutes in the Crossroads. Knights rescue it, the Horn Legion poaches it!",
			"Kaiju: a 5-star villain turns huge for 120 s. Knights can hit it anywhere!",
			"Rebirth from Lv 50: only your level resets. Gold, weapons and items stay.",
			"Each Rebirth: +25% gold and XP forever (+40% on the smaller side).",
		} },
		{ Id = "Scrolls", Title = "Scrolls", Lines = {
			"Enhance Scroll: 70% gives +1, 30% gives +3, 10% gives +5.",
			"On a fail it stays or drops one step (50/50), never below +0.",
			"Weapons never break! Max +10, and each +1 adds 10% attack.",
			"Transfer Scroll: moves your + to another weapon. A fail changes nothing.",
		} },
		{ Id = "Chat", Title = "Team Chat", Lines = {
			"Type /t in the chat to talk only to your own side.",
		} },
	},
	-- the news window (and the last help topic): update weekly
	News = {
		{ Title = "Beta", Lines = {
			"Your beta save carries over to the full launch on December 19.",
			"Everyone who joins before the launch gets the Beta Pioneer title.",
		} },
		{ Title = "New this week", Lines = {
			"Halloween: the Pumpkin Patch and the new Haunted Hollow with ghosts and the Ghost King.",
			"New players get their first weapon from the Blacksmith before the first hunt.", -- A23-74
			"New Settings window: change your keys, sound effects and screen shake.",
		} },
	},
}

-- BB2 (pure, server + client): unknown keys dropped; numbers finite, clamped and snapped to Step; bools boolean; enums in
-- Options; anything else -> the default. Keys: sparse action id -> "" or a usable key name (Config.KeyUsable), entries
-- equal to the default dropped, and an explicit key already used by an earlier action (Actions order, actions whose
-- Flag is on) becomes "" (the KeyMap rule, so two actions never save one key). Never reads more than the known fields.
function Config.SanitizeSettings(t)
	local ST = Config.Settings
	local defaults = Config.Data.Defaults.Settings
	local src = type(t) == "table" and t or {}
	local out = { V = ST.Version, Keys = {} }
	-- A23-78: a blob from before settings V2 (no V, V < 2, NaN) forgets its KeyBadges once (the old default was on)
	local before2 = not (type(src.V) == "number" and src.V == src.V and src.V >= 2)
	-- A23-65 / settings V3: a blob from before V3 (Follow was the old default) gets the Free camera once
	local before3 = not (type(src.V) == "number" and src.V == src.V and src.V >= 3)
	for key, def in ST.Defs do
		local v, d = src[key], defaults[key]
		if key == "KeyBadges" and before2 then v = d end
		if key == "Cam" and before3 then v = d end
		if def.Type == "Number" then
			if type(v) == "number" and v == v and v > -math.huge and v < math.huge then
				v = math.clamp(v, def.Min, def.Max)
				if type(def.Step) == "number" and def.Step > 0 then
					v = def.Min + math.floor((v - def.Min) / def.Step + 0.5) * def.Step
				end
				v = math.clamp(math.floor(v * 1000 + 0.5) / 1000, def.Min, def.Max)
			else
				v = d
			end
		elseif def.Type == "Bool" then
			if type(v) ~= "boolean" then v = d end
		elseif def.Type == "Enum" then
			if type(v) ~= "string" or not table.find(def.Options, v) then v = d end
		else
			v = d
		end
		out[key] = v
	end
	local keys = type(src.Keys) == "table" and src.Keys or {}
	local used = {}
	for _, a in Config.Keybinds.Actions do
		local v = keys[a.Id]
		if type(v) == "string" and Config.KeyAllowedFor(a.Id, v) and v ~= a.Key then
			if v ~= "" and Config.KeyFlagOn(a) then
				if used[v] then v = if a.NoClear then nil else "" else used[v] = true end
			end
			out.Keys[a.Id] = v
		end
	end
	return out
end

-- A23-11 / A23-12 drops, items and scroll enhancement (user decisions 2026-10-05; LootService is the only writer).
-- Every contributor of a kill gets an own server roll (MonsterKilled is fired per contributor). Items go straight
-- into the save (still no ground pickup; the bag window comes with A23-19 / BB7, until then the menu "아이템" list) and are never lost on death.
Config.Loot = {
	MaxEnhance = 10, -- +10 = attack x2
	EnhancePerLevel = 0.10, -- +1 = attack +10% (Config.EnhanceMult)
	FailDropChance = 0.5, -- a failed enhance scroll: 50% the weapon loses one level (never below +0), 50% it stays
	ItemCap = 999, -- per item id
	FullNoticeSeconds = 300, -- review B7: a "가득 찼어요" notice repeats at most once per item id per 5 minutes
	GoldenMult = 3, -- golden monsters: every drop chance x3 (capped at 100%)
	-- Kind: Material (sold at the blacksmith; crafting comes with the full launch), Enhance (+Plus to one owned weapon
	-- with Chance), Transfer (with Chance ADDS all of one weapon's +N onto another owned weapon up to MaxEnhance, the
	-- rest stays on the source; failure keeps both — no enhancement is ever lost)
	Items = {
		Jelly = { Kind = "Material", Name = "Jelly", Sell = 2, Color = Color3.fromRGB(110, 210, 110), Icon = "IconJelly" },
		SlimeCore = { Kind = "Material", Name = "Slime Core", Sell = 8, Color = Color3.fromRGB(80, 160, 235), Icon = "IconSlimeCore" },
		GoblinTooth = { Kind = "Material", Name = "Goblin Tooth", Sell = 6, Color = Color3.fromRGB(235, 225, 190), Icon = "IconGoblinTooth" },
		BruteHorn = { Kind = "Material", Name = "Brute Horn", Sell = 18, Color = Color3.fromRGB(200, 150, 100), Icon = "IconBruteHorn" }, -- review ui-brutehorn-contrast: readable on the row
		Bone = { Kind = "Material", Name = "Old Bone", Sell = 14, Color = Color3.fromRGB(225, 225, 210), Icon = "IconBone" },
		KnightCrest = { Kind = "Material", Name = "Rusty Knight Crest", Sell = 40, Color = Color3.fromRGB(150, 150, 170), Icon = "IconKnightCrest" },
		Candy = { Kind = "Material", Name = "Candy", Sell = 5, Color = Color3.fromRGB(255, 140, 60), Icon = "IconCandy" }, -- Halloween kinds
		Enh70 = { Kind = "Enhance", Name = "Enhance Scroll 70%", Chance = 0.7, Plus = 1, Color = Color3.fromRGB(120, 200, 255), Icon = "IconScrollEnh", IconBand = "IconScrollEnhBand" },
		-- A23-14 gains 70% = +1 / 30% = +3 / 10% = +5 with the 50% fail-drop: expected change at +1..+9 is
		-- +0.55 / +0.55 / +0.05 per use (at +0: +0.70 / +0.90 / +0.50), so the rarest scroll is never a loss on average
		Enh30 = { Kind = "Enhance", Name = "Enhance Scroll 30%", Chance = 0.3, Plus = 3, Color = Color3.fromRGB(190, 130, 255), Icon = "IconScrollEnh", IconBand = "IconScrollEnhBand" },
		Enh10 = { Kind = "Enhance", Name = "Enhance Scroll 10%", Chance = 0.1, Plus = 5, Color = Color3.fromRGB(255, 190, 60), Icon = "IconScrollEnh", IconBand = "IconScrollEnhBand" },
		Move70 = { Kind = "Transfer", Name = "Transfer Scroll 70%", Chance = 0.7, Color = Color3.fromRGB(120, 230, 200), Icon = "IconScrollMove", IconBand = "IconScrollMoveBand" },
		Move30 = { Kind = "Transfer", Name = "Transfer Scroll 30%", Chance = 0.3, Color = Color3.fromRGB(210, 150, 255), Icon = "IconScrollMove", IconBand = "IconScrollMoveBand" },
		Move10 = { Kind = "Transfer", Name = "Transfer Scroll 10%", Chance = 0.1, Color = Color3.fromRGB(255, 210, 90), Icon = "IconScrollMove", IconBand = "IconScrollMoveBand" },
	},
	-- display order in the item list
	Order = { "Enh70", "Enh30", "Enh10", "Move70", "Move30", "Move10",
		"Jelly", "SlimeCore", "GoblinTooth", "BruteHorn", "Bone", "KnightCrest", "Candy" },
	-- per monster Kind: rows rolled independently. { Item = id, P = chance, N = count } | { Potion = "HP"|"MP", P }
	-- | { Weapon = tier, P }. Provisional numbers (A23-12: tune after play; drop income is measured separately).
	-- Review B2 (2026-10-05): scroll chances rise with the zone (Enh70 / Enh30 / Enh10 per row), transfer scrolls are
	-- about 1/3 of the same row. Move30 / Move10 stay in the tables (A23-11 "three kinds") at those tiny rates; they
	-- move the same amount as Move70 with lower odds, so they are a rare free retry, never a better pick.
	-- Review B13: potion chances are about half of the first values (≈ 8-14 potions per hour of manual hunting).
	Tables = {
		Slime = {
			{ Item = "Jelly", P = 0.30 },
			{ Item = "Enh70", P = 0.003 }, { Item = "Enh30", P = 0.0008 }, { Item = "Enh10", P = 0.0002 },
			{ Item = "Move70", P = 0.001 }, { Item = "Move30", P = 0.0003 }, { Item = "Move10", P = 0.0001 },
			{ Potion = "HP", P = 0.01 }, { Potion = "MP", P = 0.01 },
		},
		BigSlime = {
			{ Item = "SlimeCore", P = 0.5 }, { Item = "Jelly", P = 0.5, N = 2 },
			{ Item = "Enh70", P = 0.03 }, { Item = "Enh30", P = 0.008 }, { Item = "Enh10", P = 0.002 },
			{ Item = "Move70", P = 0.01 }, { Item = "Move30", P = 0.003 }, { Item = "Move10", P = 0.0007 },
			{ Potion = "HP", P = 0.03 }, { Potion = "MP", P = 0.03 },
		},
		Goblin = {
			{ Item = "GoblinTooth", P = 0.4 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
			{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
			{ Weapon = 4, P = 0.001 },
		},
		GoblinBrute = {
			{ Item = "BruteHorn", P = 0.5 },
			{ Item = "Enh70", P = 0.05 }, { Item = "Enh30", P = 0.014 }, { Item = "Enh10", P = 0.0035 },
			{ Item = "Move70", P = 0.017 }, { Item = "Move30", P = 0.0047 }, { Item = "Move10", P = 0.0012 },
			{ Potion = "HP", P = 0.04 }, { Potion = "MP", P = 0.04 },
			{ Weapon = 4, P = 0.005 },
		},
		Skeleton = {
			{ Item = "Bone", P = 0.4 },
			{ Item = "Enh70", P = 0.025 }, { Item = "Enh30", P = 0.007 }, { Item = "Enh10", P = 0.0018 },
			{ Item = "Move70", P = 0.008 }, { Item = "Move30", P = 0.0023 }, { Item = "Move10", P = 0.0006 },
			{ Potion = "HP", P = 0.025 }, { Potion = "MP", P = 0.025 },
			{ Weapon = 5, P = 0.0005 },
		},
		SkeletonKnight = {
			{ Item = "KnightCrest", P = 0.5 },
			{ Item = "Enh70", P = 0.08 }, { Item = "Enh30", P = 0.022 }, { Item = "Enh10", P = 0.006 },
			{ Item = "Move70", P = 0.027 }, { Item = "Move30", P = 0.0073 }, { Item = "Move10", P = 0.002 },
			{ Potion = "HP", P = 0.05 }, { Potion = "MP", P = 0.05 },
			{ Weapon = 5, P = 0.003 }, { Weapon = 6, P = 0.0005 },
		},
		-- Halloween kinds (Config.Halloween): candy + the scroll / transfer / potion rows of the base kind of their zone
		PumpkinSlime = {
			{ Item = "Candy", P = 0.35 }, { Item = "Jelly", P = 0.1 },
			{ Item = "Enh70", P = 0.003 }, { Item = "Enh30", P = 0.0008 }, { Item = "Enh10", P = 0.0002 },
			{ Item = "Move70", P = 0.001 }, { Item = "Move30", P = 0.0003 }, { Item = "Move10", P = 0.0001 },
			{ Potion = "HP", P = 0.01 }, { Potion = "MP", P = 0.01 },
		},
		BatGoblin = { -- A23-45: a GoblinWoods kind again: candy + the goblin's rows (tooth, scrolls, potions, T4)
			{ Item = "Candy", P = 0.45 }, { Item = "GoblinTooth", P = 0.2 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
			{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
			{ Weapon = 4, P = 0.001 },
		},
		GhostMinion = { -- A23-45 HauntedHollow (goblin-woods strength): a small, weak pack ghost
			{ Item = "Candy", P = 0.3 },
			{ Item = "Enh70", P = 0.008 }, { Item = "Enh30", P = 0.002 }, { Item = "Enh10", P = 0.0005 },
			{ Item = "Move70", P = 0.0025 }, { Item = "Move30", P = 0.0007 }, { Item = "Move10", P = 0.0002 },
			{ Potion = "HP", P = 0.012 }, { Potion = "MP", P = 0.012 },
		},
		LittleGhost = { -- A23-45 HauntedHollow: candy + the goblin's scroll / potion rows
			{ Item = "Candy", P = 0.45 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
			{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
		},
		PumpkinKing = { -- every eligible contributor rolls these once (MonsterKilled per contributor; A23-27 rows)
			{ Item = "Candy", P = 1, N = 8 },
			{ Item = "Enh70", P = 0.25 }, { Item = "Enh30", P = 0.08 }, { Item = "Enh10", P = 0.02 },
			{ Item = "Move70", P = 0.08 },
			{ Potion = "HP", P = 0.5 }, { Potion = "MP", P = 0.5 },
			-- rolled only at Level >= that weapon's MinLevel (A23-27); below it the row gives BelowLevel instead
			{ Weapon = 4, P = 0.05, BelowLevel = { Item = "Candy", N = 3 } },
		},
		GhostKing = { -- A23-45: the pumpkin king's table ("같은 사탕", same size)
			{ Item = "Candy", P = 1, N = 8 },
			{ Item = "Enh70", P = 0.25 }, { Item = "Enh30", P = 0.08 }, { Item = "Enh10", P = 0.02 },
			{ Item = "Move70", P = 0.08 },
			{ Potion = "HP", P = 0.5 }, { Potion = "MP", P = 0.5 },
			{ Weapon = 4, P = 0.05, BelowLevel = { Item = "Candy", N = 3 } },
		},
	},
	-- "레벨1 몬스터" jackpot (user 2026-10-05): any player level, auto kills included, golden x GoldenMult. Pumpkin
	-- slimes are level-1 slimes of the PumpkinPatch (A23-30, on top of the meadow's), so they carry the same jackpot;
	-- the chance per kill is unchanged.
	Jackpot = { Monsters = { Slime = true, PumpkinSlime = true }, Chance = 1 / 20000, Tier = 8 },
	-- the first Slime Prince (BigSlime) a player defeats always drops one 70% scroll, plus a one-time hint (Text.FirstScroll shown
	-- NoticeSeconds; that kill's Loot Fx carries First = true so the client skips its own "where to use it" toast)
	FirstScroll = { Monster = "BigSlime", Item = "Enh70", NoticeSeconds = 6 },
	-- a weapon drop the player already owns turns into gold
	DuplicateWeaponGold = { [4] = 300, [5] = 1000, [6] = 3000, [7] = 9000, [8] = 3000 },
	Text = {
		Got = "+%s",
		GotN = "+%s ×%d",
		Potion = { HP = "HP Potion", MP = "MP Potion" },
		PotionFull = "Your potions are full, so you couldn't take the %s.",
		-- full-stack notices: at most once per item id (or potion kind) per player per FullNoticeSeconds, kind "info"
		ItemFull = "%s is full (max %d). You can sell it at the Forge.", -- materials
		ItemFullUse = "%s is full (max %d). Use some from your Bag.", -- scrolls (not sellable)
		UseCombat = "You can't use scrolls in combat.",
		EquipDead = "You can't change weapons while knocked out.",
		RareWeapon = "%s weapon! You got %s!", -- grade name (Rare / Epic / Legendary), weapon
		DuplicateWeapon = "You already have %s → it became %s gold.",
		JackpotSelf = "Legendary weapon [%s]! Equip it from your Bag.",
		-- A23-34: the same jackpot found bare-handed is equipped at once
		JackpotEquip = "Legendary weapon [%s] equipped! Power %s → %s",
		JackpotEquipEn = "Legendary weapon [%s] equipped! Power %s → %s",
		FirstScroll = "You got a scroll! Enhance your weapon from your Bag. (Your weapon is safe even if it fails)",
		-- A23-34: the same one-time hint while still bare-handed (no weapon to enhance yet)
		FirstScrollBare = "You got a scroll! The Blacksmith gives you your first weapon. Then enhance it from your Bag.",
		FirstScrollBareEn = "You got a scroll! The Blacksmith gives you your first weapon. Then enhance it from your Bag.",
		-- A23-34: the M1_1 gift (LootService.GrantFirstWeapon). Bare-handed: equipped at once with the power change;
		-- a player who already bought a weapon gets it in the bag (no equip, no power change).
		FirstWeapon = "You got your first weapon, [%s]! Power %s → %s",
		FirstWeaponEn = "You got your first weapon, [%s]! Power %s → %s",
		FirstWeaponBag = "The Blacksmith also gave you [%s]. Find it in your Bag.",
		FirstWeaponBagEn = "The Blacksmith also gave you [%s]. Find it in your Bag.",
		-- A23-34: a weapon found while bare-handed is equipped at once (power change)
		BareEquip = "[%s] equipped! Power %s → %s",
		BareEquipEn = "[%s] equipped! Power %s → %s",
		EnhanceOk = "Enhance success! %s +%d → +%d (attack %d%% → %d%%)",
		EnhanceFailDown = "Enhance failed… %s +%d → +%d (your weapon is safe)",
		EnhanceFailKeep = "Enhance failed… but %s stays +%d!",
		EnhanceMax = "Already at max enhance (+%d).",
		MoveOk = "Transfer success! %s +%d · %s +%d",
		MoveFail = "Transfer failed… %s stays +%d.",
		MoveSame = "Pick a different weapon.",
		MoveNothing = "There is no enhance to move.",
		NotOwned = "You don't have that weapon.",
		NoItem = "You don't have that item.",
		Equip = "%s equipped!",
		EquipCombat = "You can't change weapons in combat.",
		SellDone = "Sold %d materials! Gold +%s",
		SellNothing = "No materials to sell.",
		SellFar = "Sell materials near the Forge anvil.",
	},
}

-- Roblox's own chat lines in English (A23-48; 검수 2026-10-07: the team line showed in the player's Roblox language).
-- ChatText.luau rewrites them on the legacy chat (server), Announce.luau on TextChatService (client).
Config.ChatText = {
	Joined = "You joined the %s!", -- team name: "You joined the Horn Legion!"
	Choosing = "Pick a side to start!", -- TextChatService only: the line for the auto-assigned "Choosing a side" team
	-- 검수 2026-10-09 (UI clutter review ②: the team line stayed in the chat over the phone's joystick): the chat gets no
	-- team line (TextChatService, Announce.Incoming); the first side pick shows "You joined ...!" as one 3 s toast
	TeamToast = true,
}

-- A23-15 server-wide chat announcements (AnnounceService -> remote "Announce" -> client Announce.luau). Server sends
-- { Key, Args, Grade }; the client formats Text[Key] in its language and shows a TextChatService system message.
Config.Announce = {
	WindowSeconds = 10, -- one player's announcements within this window are grouped into one "…외 N개" line
	MinWeaponGrade = 3, -- weapon drops of this grade rank or better are announced (3 = Rare)
	Text = {
		Subject = "%s", -- the finder's game nickname
		Anon = "A member of the %s", -- name hidden (P5): "A member of the Knights of Light"
		RareWeapon = "%s beat a %s and got a %s weapon: [%s]!", -- subject, monster, grade, weapon
		Jackpot = "★ JACKPOT! %s got the legendary weapon [%s] from a slime! ★", -- subject, weapon
		FirstMax = "%s is the first to enhance [%s] to +10!", -- subject, weapon
		More = "%s found %d more great items!", -- subject, count (grouped)
		-- server-wide event lines (Events below; plain text, no names)
		PumpkinKingAppear = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!", -- A23-30: it appears in the PumpkinPatch
		PumpkinKingAppearEn = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!",
		PumpkinKingDefeat = "The Pumpkin King spilled a pile of candy!",
		PumpkinKingDefeatEn = "The Pumpkin King spilled a pile of candy!",
		PumpkinKingLeave = "The Pumpkin King went home with its candy sack. See you next time!",
		PumpkinKingLeaveEn = "The Pumpkin King went home with its candy sack. See you next time!",
		GhostKingAppear = "The Ghost King appeared in the Haunted Hollow! Let's beat it together!", -- A23-45
		GhostKingAppearEn = "The Ghost King appeared in the Haunted Hollow! Let's beat it together!",
		GhostKingDefeat = "The Ghost King dropped a shower of candy!",
		GhostKingDefeatEn = "The Ghost King dropped a shower of candy!",
		GhostKingLeave = "The Ghost King faded away. See you next time!",
		GhostKingLeaveEn = "The Ghost King faded away. See you next time!",
		NameHidden = "Announcements and rankings now show your side's name instead of your name.",
		NameShown = "Announcements and rankings now show your name.",
		MenuShow = "My name in announcements and rankings: shown",
		MenuHide = "My name in announcements and rankings: hidden",
		-- BB37 AnnounceService.PublicName (server-wide NotifyAll lines, town board, ranking rows) and the settings row
		HiddenName = "A member of the %s", HiddenNameEn = "A member of the %s", -- (faction name)
		Someone = "Someone", SomeoneEn = "Someone", -- hidden name without a faction
		Honorific = "", HonorificEn = "", -- appended to a shown name (English lines need none)
		SettingLabel = "Hide my name in announcements and rankings", SettingLabelEn = "Hide my name in announcements and rankings",
		SettingNotes = {
			"Nametags and the Tab list in your server always show your name",
			"Global rankings show your Roblox name and face. Hidden, they show \"A member of the <side>\"",
		},
		SettingNotesEn = {
			"Nametags and the Tab list in your server always show your name",
			"Global rankings show your Roblox name and face. Hidden, they show \"A member of the <side>\"",
		},
	},
	-- AnnounceService.Broadcast event lines: no finder, never grouped; the client shows Text[Key] (Text[Key .. "En"]
	-- in English) in the chat in Color, and Toast = also a toast (skipped while a picker / the opening is open)
	Events = {
		PumpkinKingAppear = { Color = Color3.fromRGB(255, 150, 40), Toast = true, Icon = "IconMonPumpkinKing" },
		PumpkinKingDefeat = { Color = Color3.fromRGB(255, 150, 40), Toast = true, Icon = "IconMonPumpkinKing" },
		PumpkinKingLeave = { Color = Color3.fromRGB(255, 190, 120), Icon = "IconMonPumpkinKing" }, -- Icon: toast / banner art (Announce)
		GhostKingAppear = { Color = Color3.fromRGB(170, 160, 255), Toast = true, Icon = "IconMonGhostKing" },
		GhostKingDefeat = { Color = Color3.fromRGB(170, 160, 255), Toast = true, Icon = "IconMonGhostKing" },
		GhostKingLeave = { Color = Color3.fromRGB(200, 195, 255), Icon = "IconMonGhostKing" },
	},
}

-- A23-18 beta: saves carry over to the full launch; everyone who plays before it gets the stat-free title
Config.Beta = {
	GrantPioneer = true, -- BB16: false stops new grants (owned titles stay)
	PioneerUntil = 1797645600, -- 2026-12-19 11:00 KST (full launch)
}

-- BB16 selectable nametag titles (never give stats). TitleOrder = picker order.
Config.TitleDefs = {
	BetaPioneer = { Name = "★Beta Pioneer", NameEn = "★Beta Pioneer", Color = Color3.fromRGB(255, 210, 60) },
	GrayLegend = { Name = "Gray Legend", NameEn = "Gray Legend", Color = Color3.fromRGB(190, 190, 200) },
}
Config.TitleOrder = { "BetaPioneer", "GrayLegend" }

Config.Sounds = { -- optional built-in files; client must pcall and ignore failures
	Swing = "rbxasset://sounds/swordslash.wav",
	Release = "rbxasset://sounds/swordlunge.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
}

-- quality ① (docs/design/quality_ideas_2026-10-06.md §1) with 검수's sound table (docs/design/lines_pack_2026-10-06.md §6):
-- Audio.luau's sound effects. Files: art/sfx/<file>.wav (tools/sfx_game.py final: Kenney CC0 + our synth; sources in
-- art/sfx/sources.json and docs/devlog/sfx_licenses.md), each levelled the same (loudest 100 ms RMS -18 dBFS, peak -3 dBFS),
-- so Volume alone sets the mix: combat 0.28-0.40 < UI 0.42-0.60 < big moments 0.65-0.75 < level up 0.85.
-- Files[file] = asset id; "" = silent until uploaded (nothing changes before the uploads).
-- Sounds[event] = { File (or Files = variants, one picked at random), Volume (Sound.Volume, x the Sound effects setting),
--   Speed = { min, max } (random per play), Max (copies at once), Gap (cooldown s), Auto (auto combat plays it at AutoMul),
--   Combat (ducked under the big moments; other players' at OthersMul) }
Config.Audio = {
	AutoMul = 0.5, -- auto-combat sounds: volume x0.5, speed unchanged
	OthersMul = 0.35, -- other players' swings / hits: x0.35 ...
	OthersRange = 40, -- ... and only within this many studs; UI sounds are mine only
	MaxPlaying = 8, -- all sounds at once
	-- these moments lower the combat sounds to Mul for Seconds
	-- (SecondsBy: sound_spec §4-2 10, the kings hold it a little longer)
	Duck = { Mul = 0.5, Seconds = 1.2, SecondsBy = { PumpkinKing = 1.6, GhostKing = 1.6 },
		By = { LevelUp = true, PumpkinKing = true, GhostKing = true, ScrollSuccess = true, GooseArrive = true,
			CrownHalo = true, CrownHorns = true, KaijuSiren = true } },
	-- combo coin speed = Base x 2^(step / 12), steps of a major scale, held at Top from the 8th kill (phones: no shrill end)
	Combo = { Base = 0.8, Top = 1.6, Steps = { 0, 2, 4, 5, 7, 9, 11, 12 } },
	-- sound_spec §4-2 6: a swing that hits From+ monsters plays its material louder and a little lower (it stays
	-- squishy on slimes); ghosts squish higher
	HitMany = { From = 3, Volume = 1.25, Speed = 0.95 },
	GhostSpeed = 1.15,
	GhostKinds = { LittleGhost = true, GhostMinion = true, GhostKing = true },
	-- §4-2 5: a bow shot that hits From+ targets plays a second arrow After s later (Speed x, Volume x)
	ArrowDouble = { From = 2, After = 0.068, Speed = 1.10, Volume = 0.85 },
	-- §4-2 3: the faction mage files are loudest PeakAt s into the file: they start that much before the launch
	MagePeak = 0.20,
	-- B13: a Z / X cast (Fx "Skill") has no launch / contact times: the cast at once, the hits right after
	SkillContact = 0.12,
	HurtBigFrac = 0.15, -- a hit taking at least this share of my max HP (or leaving me under 30 %) = HurtBig
	-- sound_wiring_r4 Loot: my drop rings only when it holds a scroll of these Config.Loot kinds or a weapon (a weapon at
	-- LootWeaponSpeed); materials and potions stay silent. KingPrize: s after KingDefeat, a paid contributor's KillPop + coin
	LootKinds = { Enhance = true, Transfer = true },
	LootWeaponSpeed = 0.92,
	KingPrize = 0.25,
	-- uploaded 2026-10-07 (Creator Hub, Darugi_S2, Restricted; art/sfx/asset_ids.json): the round-4 picks (picks_r4.json)
	-- where they are uploaded, the round-3 file otherwise. "" = not uploaded yet: the event stays silent or plays its
	-- stand-in (Equip -> GoldPickup, GooseArrive -> GooseHonk, SkillReady -> Fx Click, SkillLearn -> PowerUp)
	Files = {
		SwingWarrior = "rbxassetid://114585478722203",
		SwingMage = "rbxassetid://136838684864577", -- the Guild's alchemist (no faction file)
		SwingMageHalo = "rbxassetid://101498441090410",
		SwingMageHorns = "rbxassetid://139514092831666",
		SwingArrow = "rbxassetid://76900813038959", -- sound_gaps A1: one arrow, no twang
		SwingTamer = "rbxassetid://126503879214394",
		HitSoft = "rbxassetid://96440842663562",
		HitHeavy = "rbxassetid://95463530376920",
		HitCrit = "rbxassetid://78018534821425",
		HurtBig = "rbxassetid://73666772845621",
		KillPop = "rbxassetid://117802423144289",
		ComboCoin = "rbxassetid://132925998560879",
		ComboMilestone = "rbxassetid://73147095978331",
		LevelUp = "rbxassetid://108525821312554",
		PowerUp = "rbxassetid://118952858498086",
		Jump = "rbxassetid://119789949243782",
		WindowOpen = "rbxassetid://129419018750436",
		WindowClose = "rbxassetid://86085176622331",
		Deny = "rbxassetid://124536292557880",
		AutoOn = "rbxassetid://90300088723425",
		AutoOff = "rbxassetid://128226305896103",
		Purify = "rbxassetid://126260420453106",
		Purify_b = "rbxassetid://75155843966047",
		Devour = "rbxassetid://118262766439187",
		PumpkinKing = "rbxassetid://112500082253148",
		GhostKing = "rbxassetid://100319357258743",
		GooseHonk = "rbxassetid://115693307820380",
		QuestDone = "rbxassetid://131457371135343",
		GoldPickup = "rbxassetid://119243238199900",
		ScrollSuccess = "rbxassetid://116061752455414",
		ScrollFail = "rbxassetid://124525939049830",
		Tap = "rbxassetid://118436931537673",
		SkillHalo = "rbxassetid://75898672312875",
		SkillHorns = "rbxassetid://110780992455213",
		Potion = "rbxassetid://133789691162407",
		QuestNew = "rbxassetid://123199271616228",
		RankDown = "rbxassetid://81421593114766",
		TalkBlip = "rbxassetid://94593126133806",
		Equip = "rbxassetid://132294814566104",
		SkillReady = "rbxassetid://99319219774246",
		Spend = "rbxassetid://80768400627761",
		RankUp = "rbxassetid://84902463002053",
		SkillLearn = "rbxassetid://113535664889883",
		GooseArrive = "rbxassetid://113800368972766",
		-- new events (sound_gaps B1-B14): wire their hooks below
		CrownHalo = "rbxassetid://123752635254582",
		CrownHorns = "rbxassetid://131150435186247",
		KingDefeat = "rbxassetid://115530599858312",
		WarFinal30 = "rbxassetid://102592807006385",
		CountTick = "rbxassetid://96016194154678",
		GooseEnd = "rbxassetid://103362677938359",
		KaijuSiren = "rbxassetid://110447360461794",
		KaijuStomp = "rbxassetid://82058880758348",
		ZoneEnterPvP = "rbxassetid://104461336219672",
		GoldenSpot = "rbxassetid://128057879317544",
		KO = "rbxassetid://137556643487651",
		Respawn = "rbxassetid://128867123359602",
		Plunder = "rbxassetid://74602898707411",
		JackpotOther = "rbxassetid://99814762304779",
		Loot = "rbxassetid://114739645345413",
	},
	Sounds = {
		SwingWarrior = { File = "SwingWarrior", Volume = 0.30, Speed = { 0.92, 1.05 }, Max = 2, Gap = 0.08, Auto = true, Combat = true },
		SwingMage = { File = "SwingMage", Volume = 0.28, Speed = { 1.00, 1.10 }, Max = 2, Gap = 0.08, Auto = true, Combat = true },
		SwingMageHalo = { File = "SwingMageHalo", Volume = 0.28, Speed = { 0.98, 1.04 }, Max = 2, Gap = 0.08, Auto = true, Combat = true },
		SwingMageHorns = { File = "SwingMageHorns", Volume = 0.28, Speed = { 0.98, 1.04 }, Max = 2, Gap = 0.08, Auto = true, Combat = true },
		SwingArrow = { File = "SwingArrow", Volume = 0.25, Speed = { 0.97, 1.03 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		SwingTamer = { File = "SwingTamer", Volume = 0.28, Speed = { 0.95, 1.05 }, Max = 2, Gap = 0.08, Auto = true, Combat = true },
		HitSoft = { File = "HitSoft", Volume = 0.32, Speed = { 0.95, 1.10 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		HitHeavy = { File = "HitHeavy", Volume = 0.36, Speed = { 0.90, 1.00 }, Max = 3, Gap = 0.06, Auto = true, Combat = true },
		-- §4-2 6: a layer over the material hit when the first target is a critical hit
		HitCrit = { File = "HitCrit", Volume = 0.38, Speed = { 1, 1 }, Max = 1, Gap = 1.5, Auto = true, Combat = true },
		KillPop = { File = "KillPop", Volume = 0.40, Speed = { 0.95, 1.12 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		ComboCoin = { File = "ComboCoin", Volume = 0.29, Speed = { 1, 1 }, Max = 2, Gap = 0.06, Auto = true, Combat = true },
		ComboMilestone = { File = "ComboMilestone", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 1.0, Auto = true },
		LevelUp = { File = "LevelUp", Volume = 0.85, Speed = { 1, 1 }, Max = 1, Gap = 2.0 },
		-- A23-68 #3 the first weapon's big moment (HUD L.FirstWeapon); the stand-in when SkillLearn has no file
		PowerUp = { File = "PowerUp", Volume = 0.60, Speed = { 1, 1 }, Max = 1, Gap = 2.0 },
		Jump = { File = "Jump", Volume = 0.25, Speed = { 0.96, 1.04 }, Max = 1, Gap = 0.25 }, -- sound_gaps A11 (user)
		WindowOpen = { File = "WindowOpen", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.15 },
		WindowClose = { File = "WindowClose", Volume = 0.42, Speed = { 1, 1 }, Max = 1, Gap = 0.15 },
		Deny = { File = "Deny", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.5 },
		-- two files (rising / falling blips) instead of one file at 1.1 / 0.9: on and off are told apart by ear
		AutoOn = { File = "AutoOn", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 0.3 },
		AutoOff = { File = "AutoOff", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.3 },
		-- sound_gaps A12: two purify files taken in turn
		Purify = { Files = { "Purify", "Purify_b" }, Alternate = true, Volume = 0.55, Speed = { 1.00, 1.05 }, Max = 1, Gap = 1.0 },
		Devour = { File = "Devour", Volume = 0.55, Speed = { 1.00, 1.05 }, Max = 1, Gap = 1.0 }, -- same size as Purify, a pleasant gulp
		-- sound_gaps A6: each king its own file at 1.0x (never under 0.85x: lower turns scary)
		PumpkinKing = { File = "PumpkinKing", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 60 },
		GhostKing = { File = "GhostKing", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 60 },
		GooseHonk = { File = "GooseHonk", Volume = 0.40, Speed = { 0.95, 1.10 }, Max = 1, Gap = 3.0 },
		GooseArrive = { File = "GooseArrive", Volume = 0.65, Speed = { 1, 1 }, Max = 1, Gap = 3.0 }, -- A7: GooseActive turning on
		QuestDone = { File = "QuestDone", Volume = 0.65, Speed = { 1, 1 }, Max = 1, Gap = 1.0 },
		GoldPickup = { File = "GoldPickup", Volume = 0.45, Speed = { 0.95, 1.10 }, Max = 3, Gap = 0.08 },
		ScrollSuccess = { File = "ScrollSuccess", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 0.5 },
		ScrollFail = { File = "ScrollFail", Volume = 0.40, Speed = { 0.90, 0.90 }, Max = 1, Gap = 0.5 },
		Tap = { File = "Tap", Volume = 0.46, Speed = { 0.98, 1.02 }, Max = 1, Gap = 0.05 },
		-- the skill cast plays my class's swing file at 0.85x (the file comes from the class, not from here)
		SkillCast = { Volume = 0.40, Speed = { 0.85, 0.85 }, Max = 2, Gap = 0.1, Auto = true, Combat = true },
		SkillHalo = { File = "SkillHalo", Volume = 0.36, Speed = { 1, 1 }, Max = 1, Gap = 0.3, Auto = true, Combat = true },
		SkillHorns = { File = "SkillHorns", Volume = 0.36, Speed = { 1, 1 }, Max = 1, Gap = 0.3, Auto = true, Combat = true },
		HurtBig = { File = "HurtBig", Volume = 0.36, Speed = { 0.95, 1.05 }, Max = 1, Gap = 0.6 }, -- sound_gaps A5: its own file
		Potion = { File = "Potion", Volume = 0.40, Speed = { 1.00, 1.05 }, Max = 1, Gap = 0.3 },
		QuestNew = { File = "QuestNew", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 1.0 },
		RankDown = { File = "RankDown", Volume = 0.32, Speed = { 1, 1 }, Max = 1, Gap = 2.0 },
		TalkBlip = { File = "TalkBlip", Volume = 0.25, Speed = { 1, 1 }, Max = 3, Gap = 0.045 }, -- quality ② typewriter
		-- sound_gaps A8: the keys the server's Notify lines already send (LootService / ShopService Equip, ShopService
		-- Spend, StoryQuestService RankUp) and SkillBar's A9 / A10 - silent until their files are uploaded
		Equip = { File = "Equip", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.3 },
		Spend = { File = "Spend", Volume = 0.35, Speed = { 1, 1 }, Max = 1, Gap = 0.2 },
		RankUp = { File = "RankUp", Volume = 0.32, Speed = { 1, 1 }, Max = 1, Gap = 2.0 },
		SkillLearn = { File = "SkillLearn", Volume = 0.60, Speed = { 1, 1 }, Max = 1, Gap = 2.0 },
		SkillReady = { File = "SkillReady", Volume = 0.25, Speed = { 1, 1 }, Max = 1, Gap = 0.3 },
		CrownHalo = { File = "CrownHalo", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 60 }, -- B6 war round won by Halo (everyone; a draw has none); the chest reward 1.5 s later
		CrownHorns = { File = "CrownHorns", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 60 }, -- B6 war round won by Horns
		KingDefeat = { File = "KingDefeat", Volume = 0.65, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B11 a king is beaten; contributors' KillPop + coin 0.25 s later
		WarFinal30 = { File = "WarFinal30", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 60 }, -- B7 once per round at 30 s left (WarRoundEndsAt), faction set, joined > 30 s ago
		CountTick = { File = "CountTick", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 0.5 }, -- B7 3-2-1 before a reveal: SpeedMul 1.0 / 1.12 / 1.26
		GooseEnd = { File = "GooseEnd", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 5 }, -- B3 Fx GooseEnd near the camera; the reward is GoldPickup 1.5 s later
		KaijuSiren = { File = "KaijuSiren", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- B5 KaijuPhase -> 'Siren'; CountTick follows
		KaijuStomp = { File = "KaijuStomp", Volume = 0.45, Speed = { 0.97, 1.03 }, Max = 2, Gap = 1 }, -- B4 Fx Stomp: Volume x1 within 15 studs -> 0 at 60
		ZoneEnterPvP = { File = "ZoneEnterPvP", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B9 ZonePvP false->true, not within 3 s of a spawn / teleport, nothing on leaving
		GoldenSpot = { File = "GoldenSpot", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B8 a golden monster first in view within 50 studs (once per monster); GoldenKill = same file
		GoldenKill = { File = "GoldenSpot", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 0.5 }, -- a golden kill (Reward Golden): the GoldenSpot file in its own pool (the spot's 10 s gap never eats it); the coin 0.1 s later
		KO = { File = "KO", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- B1 Fx KO (mine): cartoon dizzy, no death jingle
		Respawn = { File = "Respawn", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- B1 my character comes back after a KO
		Plunder = { File = "Plunder", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- B2 my sack / pocket is taken (the victim only; the taker hears GoldPickup)
		JackpotOther = { File = "JackpotOther", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- B10 someone else's Jackpot / FirstMax line (not RareWeapon)
		Loot = { File = "Loot", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.3 }, -- B14 Fx Loot with a scroll or a weapon (weapon SpeedMul 0.92); materials / potions silent
	},
	-- swing file per weapon style / class (Neutral Blacksmith / Alchemist: Speed x NeutralSpeed); SwingFaction picks the
	-- caster's faction file when it is uploaded (sound_gaps A2: Halo / Horns mages)
	Swing = { Warrior = "SwingWarrior", Mage = "SwingMage", Archer = "SwingArrow", Punch = "SwingWarrior",
		PetHeadbutt = "SwingTamer", PetDash = "SwingTamer" },
	SwingFaction = { Mage = { Halo = "SwingMageHalo", Horns = "SwingMageHorns" } },
	PunchSpeed = 1.3, -- bare hands: a short swish (volume x0.6)
	NeutralSpeed = { Warrior = 0.85, Mage = 0.9 },
	-- hit sound per monster kind: soft = slimes, ghosts, pumpkins; everything else and players = heavy
	SoftKinds = { Slime = true, BigSlime = true, PumpkinSlime = true, LittleGhost = true, GhostMinion = true, GhostKing = true },
	-- typewriter voices (quality ②): speaker -> blip speed (the shard high and fast, the Horns guide low; Config story
	-- Speaker ids Shard / Smith / Guild / Fountain)
	Talk = { Default = 1, Shard = 1.45, Halo = 1.1, Horns = 0.78, Smith = 0.86, Guild = 0.95, Fountain = 1.2 },
}

Config.Combo = { ResetSeconds = 4, Milestones = { { 10, "Nice! x10" }, { 25, "Great! x25" }, { 50, "Wild! x50" }, { 100, "Legend! x100" } } }

-- addendum A3-H4 / H5 / M1: client layout rules (UI uses IgnoreGuiInset = true)
Config.UI = {
	TopInsetPad = 8, -- every top-anchored HUD block starts at Y >= GuiService:GetGuiInset().Y + TopInsetPad...
	TopInsetFallback = 64, -- ...or this many px when the inset is unknown (never use the top 0..64 px band)
	ScaleMin = 0.75, -- UIScale = clamp(viewportY / 720, ScaleMin, ScaleMax)
	ScaleMax = 1.25,
	-- desktop (no touch): UIScale = clamp(viewportY / 720 * DesktopScaleMult, DesktopScaleMin, DesktopScaleMax)
	DesktopScaleMult = 0.8,
	DesktopScaleMin = 0.5, -- review 2026-10-07: short PC windows keep the desktop layout, smaller (was 0.6)
	DesktopScaleMax = 1.0,
	MinTextSize = 11, -- UITextSizeConstraint.MinTextSize on every TextLabel/TextButton
	JumpButtonWait = 5, -- WaitForChild timeout for PlayerGui.TouchGui.TouchControlFrame.JumpButton
	AttackFallbackOffset = Vector2.new(-200, -170), -- attack button offset from bottom-right without a jump button
}

-- addendum A14-3: GPT-drawn HUD parts (art/ui/asset_ids.json + art/ui/ui_meta.json; mockup art/out/UI_HUD_Final.png).
-- Plain data only; the client reads it through UIKit.ArtImage / ArtFrame / ArtButton / ArtBar.
-- Part fields: Id (empty or missing = not uploaded -> UIKit draws the old code-styled frame, IMG-R4), Size (image px),
-- Slice (SliceCenter rect in image px = 9-slice frame), SliceScale (default edge scale), FitHeight (capsule: edge
-- scale follows the element height), Round (fallback is a circle), Tone (Colors key for the fallback fill and the
-- label style), Inner (content rect in image px: hole / face / track interior).
Config.UIArt = {
	Enabled = true, -- false = every part counts as missing (forces the IMG-R4 fallback)
	Parts = {
		-- frames (9-slice)
		PanelParchment = { Id = "rbxassetid://71017857503225", Size = Vector2.new(512, 327), Slice = Rect.new(22, 23, 490, 300), SliceScale = 0.5, Tone = "Parchment" },
		PanelCard = { Id = "rbxassetid://91331609258606", Size = Vector2.new(512, 229), Slice = Rect.new(52, 52, 460, 177), SliceScale = 0.35, Tone = "Navy", Inner = Rect.new(22, 43, 490, 206) }, -- Firefly PanelDark (bundle 5)
		RibbonHeader = { Id = "rbxassetid://71822647719938", Size = Vector2.new(512, 121), Slice = Rect.new(130, 59, 460, 61), FitHeight = true, Tone = "Navy", Inner = Rect.new(114, 33, 497, 100) }, -- Firefly PanelHeader: navy plate, left disc (icon); light text
		-- Skip button: the old Rect(41, 23, 472, 98) cut the round ends into corner pieces + stretched edges (square notches
		-- at the top corners on phones, user via review 2026-10-07); see the FitHeight slice note above Parts
		Pill = { Id = "rbxassetid://116332974579615", Size = Vector2.new(512, 120), Slice = Rect.new(60, 59, 452, 61), FitHeight = true, Tone = "Parchment" },
		BarTrack = { Id = "rbxassetid://137159149395361", Size = Vector2.new(512, 86), Slice = Rect.new(45, 42, 467, 44), FitHeight = true, Tone = "NavyDeep", Inner = Rect.new(21, 21, 491, 63) }, -- Firefly redraw (bundle 5)
		BtnSquare = { Id = "rbxassetid://115107332625256", Size = Vector2.new(510, 512), Slice = Rect.new(121, 150, 396, 368), SliceScale = 0.22, Tone = "Navy" }, -- Firefly navy square (bundle 4): light labels
		-- round buttons / rings (Fit)
		BtnAttack = { Id = "rbxassetid://138359104403150", Size = Vector2.new(512, 512), Round = true, Tone = "Orange", Inner = Rect.new(58, 50, 452, 427) }, -- Firefly orange attack disc (bundle 6)
		BtnSpecial = { Id = "rbxassetid://78355405067281", Size = Vector2.new(512, 512), Round = true, Tone = "QuestBlue", Inner = Rect.new(61, 57, 450, 425) }, -- Firefly blue skill disc BtnSkill (bundle 6)
		LevelBadge = { Id = "rbxassetid://97341840194719", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(75, 77, 436, 427) }, -- Firefly (bundle 6): no faction / white number
		PortraitRing = { Id = "rbxassetid://81879569016992", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(85, 82, 427, 424) }, -- Firefly (bundle 6): transparent hole
		-- bundle 6 (Firefly 2026-10-06, art/review/b6_hud_sheet.png): faction level badges, HUD discs, minimap frame, class glyphs
		LevelBadgeHalo = { Id = "rbxassetid://140072275905868", Size = Vector2.new(512, 512), Round = true, Tone = "Parchment", Inner = Rect.new(122, 150, 386, 400) }, -- ivory centre: dark number
		LevelBadgeHorns = { Id = "rbxassetid://131043118998343", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(92, 101, 420, 414) },
		LevelBadgeArtisan = { Id = "rbxassetid://135233332138906", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(118, 112, 389, 365) },
		BtnPotion = { Id = "rbxassetid://70624679686039", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(67, 72, 447, 436) }, -- count socket bottom-right
		MinimapFrame = { Id = "rbxassetid://121102769530414", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(74, 76, 439, 428) }, -- A23-26 live minimap
		GlyphSword = { Id = "rbxassetid://104681533093026", Size = Vector2.new(512, 512) }, -- attack button glyph: Warrior
		GlyphStaff = { Id = "rbxassetid://123664178583457", Size = Vector2.new(512, 512) }, -- attack button glyph: Mage (bow: bundle 7)
		-- bundle 4/5 + bundle 1 masters (Firefly 2026-10-06, art/review/s2/b45_common_ui_sheet.png): common window kit
		PanelMain = { Id = "rbxassetid://88644317713609", Size = Vector2.new(512, 308), Slice = Rect.new(50, 45, 463, 260), SliceScale = 0.35, Tone = "Parchment" },
		DialogBox = { Id = "rbxassetid://81677603849224", Size = Vector2.new(512, 189), Slice = Rect.new(40, 34, 472, 154), SliceScale = 0.35, Tone = "Parchment" },
		ListRow = { Id = "rbxassetid://125160937753435", Size = Vector2.new(512, 128), Slice = Rect.new(50, 63, 462, 65), FitHeight = true, Tone = "Parchment" },
		StatusPlate = { Id = "rbxassetid://111562222428548", Size = Vector2.new(512, 153), Slice = Rect.new(140, 75, 460, 77), FitHeight = true, Tone = "Navy", Inner = Rect.new(145, 41, 498, 129) },
		Chip = { Id = "rbxassetid://98251464747498", Size = Vector2.new(512, 189), Slice = Rect.new(95, 93, 417, 95), FitHeight = true, Tone = "Parchment" }, -- white: tint with ImageColor3
		BarFill = { Id = "rbxassetid://106350683674684", Size = Vector2.new(512, 76), Slice = Rect.new(38, 37, 474, 39), FitHeight = true }, -- white: HP green / MP #3B5BDB / XP sky
		BtnPrimary = { Id = "rbxassetid://127738422299817", Size = Vector2.new(512, 165), Slice = Rect.new(73, 81, 443, 83), FitHeight = true, Tone = "Gold" }, -- gold capsule
		BtnSecondary = { Id = "rbxassetid://114817071398745", Size = Vector2.new(512, 160), Slice = Rect.new(72, 79, 442, 81), FitHeight = true, Tone = "QuestBlue" }, -- blue capsule
		BtnConfirm = { Id = "rbxassetid://108547133403905", Size = Vector2.new(512, 156), Slice = Rect.new(69, 77, 445, 79), FitHeight = true, Tone = "Confirm" }, -- green capsule
		BtnRound = { Id = "rbxassetid://130540388825411", Size = Vector2.new(512, 495), Round = true, Tone = "Navy" }, -- do not stretch
		GlyphClose = { Id = "rbxassetid://139183604533147", Size = Vector2.new(512, 507) }, -- on BtnRound at 60%
		SlotRare = { Id = "rbxassetid://74934960438246", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(76, 80, 436, 436) }, -- A23-32 dark inside (bundle 7; replaces the cream master)
		-- bundle 7 (Firefly 2026-10-06, art/review/s2/b7_slots_glyphs_sheet.png): grade slots share the body Rect(36,40,476,480),
		-- the icon goes in Inner (count bottom-right, +N top-left: game text); Legendary sparkles with a UIGradient
		SlotCommon = { Id = "rbxassetid://111292751531225", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(76, 80, 436, 436) },
		SlotUncommon = { Id = "rbxassetid://89522895923707", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(76, 80, 436, 436) },
		SlotEpic = { Id = "rbxassetid://101182830551153", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(76, 80, 436, 436) },
		SlotLegendary = { Id = "rbxassetid://120984431833878", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(76, 80, 436, 436) },
		SlotEmpty = { Id = "rbxassetid://76893994002938", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(76, 80, 436, 436) },
		-- white glyphs: tint with ImageColor3; rail (BtnSquare ~70%), bag window head (BtnRound ~65%), archer attack
		GlyphBow = { Id = "rbxassetid://112757908729756", Size = Vector2.new(512, 512) },
		GlyphBag = { Id = "rbxassetid://93351533176297", Size = Vector2.new(512, 512) },
		GlyphMap = { Id = "rbxassetid://119097076903144", Size = Vector2.new(512, 512) },
		GlyphMenu = { Id = "rbxassetid://111602356012086", Size = Vector2.new(512, 512) },
		GlyphShrink = { Id = "rbxassetid://76902251335169", Size = Vector2.new(512, 512) },
		GlyphExpand = { Id = "rbxassetid://75596947594085", Size = Vector2.new(512, 512) },
		GlyphSort = { Id = "rbxassetid://80959026636822", Size = Vector2.new(512, 512) },
		-- bundle 8/9 (art/review/s2/b89_items_marker_sheet.png)
		IconQuestMarker = { Id = "rbxassetid://86276211066214", Size = Vector2.new(512, 512) }, -- A23-36 white diamond: tint (in progress / claim)
		IconQuestMarkerArrow = { Id = "rbxassetid://133907500836640", Size = Vector2.new(512, 512) }, -- points UP: Rotation turns it
		Star = { Id = "rbxassetid://121090596161898", Size = Vector2.new(512, 512) }, -- white star: filled = gold 245,197,66, empty = 70,78,110
		IconWantedStar = { Id = "rbxassetid://110523293522605", Size = Vector2.new(512, 512) }, -- Horns wanted star
		-- emblems
		ShieldHalo = { Id = "rbxassetid://73353334079892", Size = Vector2.new(512, 512) }, -- 2026-10-08 redraw: no rays (halo + gem)
		ShieldHorns = { Id = "rbxassetid://100359282407005", Size = Vector2.new(512, 512) }, -- 2026-10-08 redraw (horn shield, gem)
		Crown = { Id = "rbxassetid://87428837580998", Size = Vector2.new(256, 175) },
		-- icons
		IconCoin = { Id = "rbxassetid://86252987066467", Size = Vector2.new(512, 512) }, -- Firefly (bundle 8)
		IconPouch = { Id = "rbxassetid://130257832801072", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (carried gold / Halo auto-bank perk)
		IconPotionHP = { Id = "rbxassetid://108192030084262", Size = Vector2.new(512, 512) }, -- Firefly master (bundle 1)
		IconPotionMP = { Id = "rbxassetid://94345565073683", Size = Vector2.new(512, 512) }, -- Firefly (bundle 8)
		IconSword = { Id = "rbxassetid://112025111517770", Size = Vector2.new(255, 256) }, -- wooden sword (next weapon)
		IconAttack = { Id = "rbxassetid://74944938867654", Size = Vector2.new(512, 512) }, -- Firefly sword (bundle 5)
		IconSpecial = { Id = "rbxassetid://96492143551436", Size = Vector2.new(256, 146) }, -- winged gold star (발사)
		IconLock = { Id = "rbxassetid://91132729692542", Size = Vector2.new(246, 256) },
		IconMap = { Id = "rbxassetid://90459703873799", Size = Vector2.new(256, 202) },
		IconGear = { Id = "rbxassetid://99179510720767", Size = Vector2.new(247, 256) },
		IconGoose = { Id = "rbxassetid://92080848582218", Size = Vector2.new(512, 512) },
		IconSafe = { Id = "rbxassetid://137095933008547", Size = Vector2.new(512, 512) }, -- Firefly green shield (bundle 5)
		IconSprout = { Id = "rbxassetid://88235635858040", Size = Vector2.new(512, 512) }, -- Firefly (bundle 8)
		IconStar = { Id = "rbxassetid://117033474251317", Size = Vector2.new(256, 243) },
		IconStarEmpty = { Id = "rbxassetid://78608910520884", Size = Vector2.new(256, 255) },
		IconClover = { Id = "rbxassetid://131514392052133", Size = Vector2.new(512, 512) },
		IconScroll = { Id = "rbxassetid://103880967919087", Size = Vector2.new(256, 192) },
		IconSlime = { Id = "rbxassetid://112355880587310", Size = Vector2.new(256, 245) },
		-- GPT image 2.5 (Firefly) monster heads / items, user-approved 2026-10-05 (art/approved.json), 512x512
		IconMonSlime = { Id = "rbxassetid://89523202269656", Size = Vector2.new(512, 512) }, -- cube jelly slime
		IconMonPumpkinSlime = { Id = "rbxassetid://138137363654055", Size = Vector2.new(512, 512) },
		IconMonLittleGhost = { Id = "rbxassetid://91616805843424", Size = Vector2.new(512, 512) },
		IconMonBatGoblin = { Id = "rbxassetid://83904275165898", Size = Vector2.new(512, 512) },
		IconMonPumpkinKing = { Id = "rbxassetid://96292404288645", Size = Vector2.new(512, 512) },
		IconCandy = { Id = "rbxassetid://98209525611627", Size = Vector2.new(512, 512) },
		IconPetBabySlime = { Id = "rbxassetid://95348587877182", Size = Vector2.new(512, 512) }, -- pets (later)
		-- window buttons (BB13 menu; UIKit.CharacterIconKey picks IconCharacterF for CharacterGender "F")
		IconBag = { Id = "rbxassetid://110554679799730", Size = Vector2.new(512, 512) },
		IconCharacter = { Id = "rbxassetid://85845386405558", Size = Vector2.new(512, 512) },
		IconCharacterF = { Id = "rbxassetid://106504549276560", Size = Vector2.new(512, 512) },
		IconSkills = { Id = "rbxassetid://113811090785765", Size = Vector2.new(512, 512) },
		IconRanking = { Id = "rbxassetid://119501472065745", Size = Vector2.new(512, 512) },
		IconHelp = { Id = "rbxassetid://102236302870647", Size = Vector2.new(512, 512) },
		-- A23-38/A23-40 menu row (Firefly 2026-10-06, 471686b, art/review/s2/a2338_menu_sheet.png): navy tile + thin gold
		-- trim (ImageTransparency 0.15 over the world), icon ~74% centred, the name below in game text
		MenuTile = { Id = "rbxassetid://137120062999958", Size = Vector2.new(512, 504), Slice = Rect.new(96, 96, 416, 408), SliceScale = 0.12, Tone = "Navy" },
		IconSettings = { Id = "rbxassetid://140338353841950", Size = Vector2.new(512, 512) }, -- settings gear
		IconNews = { Id = "rbxassetid://124574116225607", Size = Vector2.new(512, 512) }, -- news scroll (IconHelp stays help)
		-- guide portraits (Firefly 2026-10-06, 50bf8ea, user OK): square bust, bottom cut straight (welcome dialog, rings)
		PortraitGuideHalo = { Id = "rbxassetid://86660279667138", Size = Vector2.new(512, 512) },
		PortraitGuideHorns = { Id = "rbxassetid://81858266071600", Size = Vector2.new(512, 512) },
		PortraitGuideArtisan = { Id = "rbxassetid://79157745259396", Size = Vector2.new(512, 512) },
		-- shop NPCs (2975f24, user OK): portraits for a ring / dialogue, full body beside a shop window (the 3D NPCs stay)
		PortraitPotionMerchant = { Id = "rbxassetid://87346642697895", Size = Vector2.new(486, 512) },
		PortraitMerchantC = { Id = "rbxassetid://85592132165738", Size = Vector2.new(487, 512) },
		FullPotionMerchant = { Id = "rbxassetid://119279738895658", Size = Vector2.new(449, 768) },
		-- FullMerchantC (the old blacksmith full body) removed 2026-10-07: unused (검수); 이미지 생성 2 cleans the file
		-- A23-40 layout B parts (Firefly 2026-10-06: 83eaffb minimap_ring_sheet, ccab705 / a601f39 b12 / b1213 sheets)
		MinimapRing = { Id = "rbxassetid://79170457332929", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(63, 63, 449, 449) }, -- hole d386 at (256,256): the map circle d392 tucks under the inner rim
		WarMeterFrame = { Id = "rbxassetid://73887778381300", Size = Vector2.new(512, 74), Tone = "Navy", Inner = Rect.new(66, 22, 442, 54) }, -- opaque navy inside: the fills draw above it
		WarCrownPip = { Id = "rbxassetid://100273975086572", Size = Vector2.new(512, 512) }, -- the war split marker
		QuestRow = { Id = "rbxassetid://77896448940362", Size = Vector2.new(512, 124), Slice = Rect.new(118, 61, 388, 63), FitHeight = true, Tone = "Navy" }, -- left disc (60,62) r45, number box (425,48)-(489,80)
		AutoRingOn = { Id = "rbxassetid://82348810388598", Size = Vector2.new(512, 512) }, -- turns around the auto button while ON
		GlyphQuest = { Id = "rbxassetid://85735330851016", Size = Vector2.new(512, 512) },
		QuestTabIconMain = { Id = "rbxassetid://89637504554244", Size = Vector2.new(512, 512) }, -- quest window tabs + HUD line icons (Config.QuestTabs; 이미지 생성 2, 2026-10-08): crown book
		QuestTabIconSide = { Id = "rbxassetid://98437304116587", Size = Vector2.new(512, 512) }, -- ribbon scroll
		QuestTabIconDaily = { Id = "rbxassetid://103609446225386", Size = Vector2.new(512, 512) }, -- calendar + check
		QuestTabIconEvent = { Id = "rbxassetid://123628411800049", Size = Vector2.new(512, 512) }, -- pumpkin + bow
		QuestTabIconFaction = { Id = "rbxassetid://111149297376842", Size = Vector2.new(512, 512) }, -- halo | horns shield
		GlyphAuto = { Id = "rbxassetid://125607651991448", Size = Vector2.new(512, 512) },
		NameTag = { Id = "rbxassetid://101536515759381", Size = Vector2.new(512, 153), Slice = Rect.new(80, 75, 432, 77), FitHeight = true, Tone = "Navy" },
		ListRowSelected = { Id = "rbxassetid://117472551663985", Size = Vector2.new(512, 173), Slice = Rect.new(64, 85, 448, 87), FitHeight = true, Tone = "Gold" }, -- b: deep gold
		Toast = { Id = "rbxassetid://92139413642355", Size = Vector2.new(512, 102), Slice = Rect.new(100, 50, 460, 52), FitHeight = true, Tone = "Navy" }, -- icon disc centre (49,51) r~37
		-- 2026-10-06 uploads (bundles 12/13 rest, 15/16 tamer staffs, 17, 18, map markers 9a8b47a, skill Q ae9a7ea; sheets in
		-- art/review/s2/): new keys. EmoOuch (now a blank burst for an '아야!' TextLabel) waits for its screen (Fx text
		-- overlay); TitleRibbon is in use since 2026-10-08 (the nickname window)
		Weapon_Tamer_T1 = { Id = "rbxassetid://71978061313848", Size = Vector2.new(512, 512) }, -- A23-39 pet tamer staff (Artisan Archer)
		Weapon_Tamer_T2 = { Id = "rbxassetid://121246970163140", Size = Vector2.new(512, 512) },
		Weapon_Tamer_T3 = { Id = "rbxassetid://127142057835154", Size = Vector2.new(512, 512) },
		Weapon_Tamer_T4 = { Id = "rbxassetid://88649237611687", Size = Vector2.new(512, 512) },
		Weapon_Tamer_T5 = { Id = "rbxassetid://100807011781382", Size = Vector2.new(512, 512) },
		Weapon_Tamer_T6 = { Id = "rbxassetid://115255861303177", Size = Vector2.new(512, 512) },
		GlyphExclaim = { Id = "rbxassetid://121061168473918", Size = Vector2.new(512, 512) }, -- white !, inside NpcMarkerBubble
		BadgeLeanCare = { Id = "rbxassetid://77335188385721", Size = Vector2.new(512, 512) }, -- pet lean badges next to a name tag (24-32 px)
		BadgeLeanTame = { Id = "rbxassetid://97846315594608", Size = Vector2.new(512, 512) },
		BadgeLeanGuild = { Id = "rbxassetid://74850129740155", Size = Vector2.new(512, 512) },
		IconMonGhostMinion = { Id = "rbxassetid://93544533194341", Size = Vector2.new(512, 512) }, -- A23-45 ghost family heads
		IconMonGhostKing = { Id = "rbxassetid://77166897215168", Size = Vector2.new(512, 512) },
		LogoPlate = { Id = "rbxassetid://130599938745953", Size = Vector2.new(1024, 731) }, -- title band empty: the name is a TextLabel at (0.15, 0.48, 0.70, 0.19)
		EventBannerHalloween = { Id = "rbxassetid://132425576520690", Size = Vector2.new(1024, 316) }, -- text box (0.22, 0.17, 0.56, 0.34)
		ShardBase = { Id = "rbxassetid://137006454032810", Size = Vector2.new(512, 512) }, -- crown shard (S0 quest, reward notices, map)
		-- E11 job board (d53ad3b, user OK 2026-10-07 via review; sheet art/review/s2/e11_job_board_sheet.jpg). Regions in
		-- CardLayout.JobBoard / JobCard. Phones (749x361): the board shows 2 cards a page (< > + page dots), PC / tablet 4
		-- in a row (image dev 2026-10-07: 4 across made the words too small on a phone)
		JobBoard = { Id = "rbxassetid://115013449737046", Size = Vector2.new(1024, 647), Slice = Rect.new(320, 130, 704, 550) }, -- the slice skips the plate's gold studs
		JobCard = { Id = "rbxassetid://89823627909881", Size = Vector2.new(339, 512) }, -- the red pin: keep the ratio (Fit), no 9-slice
		BtnKind = { Id = "rbxassetid://96995284140099", Size = Vector2.new(512, 175), Slice = Rect.new(88, 86, 424, 88), FitHeight = true, TextRect = { 0.053, 0.123, 0.893, 0.596 } }, -- sky blue, white "Kind"
		BtnSneaky = { Id = "rbxassetid://82745606719708", Size = Vector2.new(512, 171), Slice = Rect.new(86, 84, 426, 86), FitHeight = true, TextRect = { 0.057, 0.117, 0.887, 0.612 } }, -- purple, white "Sneaky"
		JobTag = { Id = "rbxassetid://87413375917921", Size = Vector2.new(256, 106), TextRect = { 0.2, 0.118, 0.745, 0.578 } }, -- the quest row's "Job" tag (accepted jobs only), keep the ratio
		-- the job board buttons' icons (c51be3f, review OK): icon + 8 px + word as one centred group inside BtnKind /
		-- BtnSneaky's TextRect (icon about 1.4x the word height) - the shape tells the two apart for red-green colour blindness
		GlyphKindWing = { Id = "rbxassetid://73020277343948", Size = Vector2.new(256, 256) },
		GlyphSneakyHorns = { Id = "rbxassetid://101558632670193", Size = Vector2.new(256, 256) },
		-- monster bark bubble (8e517a6, user OK via review): white + thick navy rim, tail at the bottom left (points down at
		-- the monster), no letters - dark navy text in TextRect. SliceScale 0.3 keeps the tail the same size at ~52 px and
		-- lets only the 24 px middle band grow for a second line. Now the HUD hint bubble's only (HUD.luau); monster barks
		-- no longer use it (A23-74: BarkBubble<Kind> below, else MonsterLabels' round code bubble)
		BarkBubble = { Id = "rbxassetid://124351323911597", Size = Vector2.new(512, 190), Slice = Rect.new(84, 65, 446, 89), SliceScale = 0.3, TextRect = { 0.077, 0.181, 0.844, 0.448 } },
		-- A23-74 (user 2026-10-07 "몬스터마다 다른 말풍선 그려야지" / "가로로 길쭉한 거 말고"): one bark bubble per monster
		-- kind, "BarkBubble" .. kind. A round chubby bubble (about 1.2-1.5 : 1, small tail at the bottom left, big empty middle),
		-- NOT 9-sliced: MonsterLabels draws it ~104 px wide with ScaleType Fit, height from Size. Id = "" = not drawn yet:
		-- the family's key (Config.Barks.BubbleFamily / BubbleArt), else the round code bubble (IMG-R4; never the wide
		-- 9-slice BarkBubble above, which only the HUD hint bubble uses). With the id add Size (the PNG px) and TextRect
		-- (the empty middle as fractions); no Slice (a sliced key is skipped).
		BarkBubbleSlime = { Id = "rbxassetid://121607411194048", Size = Vector2.new(512, 415), TextRect = { 0.125, 0.376, 0.752, 0.318 } },
		BarkBubbleBigSlime = { Id = "rbxassetid://121478824500297", Size = Vector2.new(512, 445), TextRect = { 0.232, 0.351, 0.549, 0.391 } },
		BarkBubblePumpkinSlime = { Id = "rbxassetid://85044172676856", Size = Vector2.new(512, 438), TextRect = { 0.158, 0.384, 0.68, 0.301 } },
		BarkBubblePumpkinKing = { Id = "rbxassetid://110500874816557", Size = Vector2.new(512, 431), TextRect = { 0.148, 0.376, 0.695, 0.278 } },
		BarkBubbleGoblin = { Id = "rbxassetid://135198528423754", Size = Vector2.new(512, 409), TextRect = { 0.254, 0.352, 0.49, 0.411 } },
		BarkBubbleBatGoblin = { Id = "rbxassetid://136707268128149", Size = Vector2.new(512, 298), TextRect = { 0.295, 0.302, 0.4, 0.463 } },
		BarkBubbleGoblinBrute = { Id = "rbxassetid://137522622485063", Size = Vector2.new(512, 379), TextRect = { 0.217, 0.222, 0.535, 0.443 } },
		BarkBubbleSkeleton = { Id = "rbxassetid://128451193232701", Size = Vector2.new(512, 369), TextRect = { 0.158, 0.26, 0.684, 0.358 } },
		BarkBubbleSkeletonKnight = { Id = "rbxassetid://134713081207957", Size = Vector2.new(512, 409), TextRect = { 0.24, 0.308, 0.52, 0.44 } },
		BarkBubbleGhostMinion = { Id = "rbxassetid://121325988367395", Size = Vector2.new(512, 333), TextRect = { 0.13, 0.37, 0.75, 0.33 } },
		BarkBubbleLittleGhost = { Id = "rbxassetid://106182896723807", Size = Vector2.new(512, 344), TextRect = { 0.117, 0.366, 0.777, 0.331 } },
		BarkBubbleGhostKing = { Id = "rbxassetid://120140777254240", Size = Vector2.new(512, 395), TextRect = { 0.127, 0.41, 0.742, 0.273 } },
		-- King Slime (SlimeKing, A23-84; 이미지 생성 2 189998d): crown + cape bubble. TextRect = the white middle (measured
		-- 10/09: 0.07-0.92 wide at mid height), wider than the first 0.506 so a 2-line line reads at ~104 px
		BarkBubbleSlimeKing = { Id = "rbxassetid://98179139339766", Size = Vector2.new(512, 473), TextRect = { 0.15, 0.4, 0.7, 0.33 } },
		MapBlacksmith = { Id = "rbxassetid://94328996197556", Size = Vector2.new(512, 512) }, -- map markers: a white-rimmed disc with the icon, drawn as is
		MapPotionShop = { Id = "rbxassetid://131897716268568", Size = Vector2.new(512, 512) },
		MapAltar = { Id = "rbxassetid://75215424047711", Size = Vector2.new(512, 512) },
		MapGooseNest = { Id = "rbxassetid://83187866833677", Size = Vector2.new(512, 512) },
		MapHuntEntrance = { Id = "rbxassetid://120015572780851", Size = Vector2.new(512, 512) },
		MapQuestTarget = { Id = "rbxassetid://112520423325135", Size = Vector2.new(512, 512) },
		BadgeDot = { Id = "rbxassetid://107622736106569", Size = Vector2.new(512, 512) }, -- news dot (top-right of a button; the count is a TextLabel)
		IconPetPaw = { Id = "rbxassetid://101099487202511", Size = Vector2.new(512, 512) }, -- 'my pet' row head icon
		GradeSlotBack = { Id = "rbxassetid://120590954007382", Size = Vector2.new(512, 498) }, -- navy plate behind weapon / pet icons (no grade rim)
		BannerGold = { Id = "rbxassetid://105577140932665", Size = Vector2.new(512, 178) }, -- Fit (no slice); text box (0.254, 0.225, 0.492, 0.365)
		TabOn = { Id = "rbxassetid://102062478132150", Size = Vector2.new(512, 228), Slice = Rect.new(110, 113, 402, 115), FitHeight = true, Tone = "Gold" }, -- selected tab: navy text
		TabOff = { Id = "rbxassetid://76306323831801", Size = Vector2.new(512, 202), Slice = Rect.new(100, 100, 412, 102), FitHeight = true, Tone = "Navy" }, -- idle tab: white text
		InputField = { Id = "rbxassetid://108042300963591", Size = Vector2.new(512, 129), Slice = Rect.new(52, 63, 460, 65), FitHeight = true, Tone = "Parchment" }, -- text box: navy text
		QuestTab = { Id = "rbxassetid://124642276890798", Size = Vector2.new(512, 138), Slice = Rect.new(70, 68, 430, 70), FitHeight = true, Tone = "Gold" }, -- the arrow box (x 440+) never stretches
		BannerAlert = { Id = "rbxassetid://104830795997617", Size = Vector2.new(512, 133), Slice = Rect.new(84, 65, 428, 67), FitHeight = true, Tone = "Red" }, -- white text, dark red rim
		NpcMarkerBubble = { Id = "rbxassetid://76402030324791", Size = Vector2.new(512, 512) }, -- gold pin over NPC heads; a glyph inside
		-- RewardRays removed 2026-10-07 (user: the turning rays looked like the Rising Sun flag; AGENTS: no ray bursts)
		-- 창 꾸미기 ③ reward popup parts, High (1d58f6c; art/approved.json, 검수 picks 2026-10-07). Plates: 9-slice
		-- (SliceScale 0.7 = the sheet's look), Inner = the cream / plum inside. Their slice lines sit on the straight rim only
		-- (rows / columns measured identical, ~10 px clear of every wing, knot, horn and corner curve): approved.json's
		-- (62, 66, 449, 231) / (60, 65, 452, 239) cut through the knots, and the phone's small plate (UiSandbox 749x361) drew
		-- the bottom corners with a visible jog. Curved ribbons: keep the ratio (stretching breaks the curve), TextRect = the
		-- band for the title. Straight ribbons (spare, for places that must stretch): pill slice. Slot: Fit, Inner = icon +
		-- amount. Glow / Sparkle: white + brightness alpha, tint with ImageColor3 (Halo gold, Horns orange)
		RewardPanelHalo = { Id = "rbxassetid://117046183906202", Size = Vector2.new(512, 294), Slice = Rect.new(80, 80, 432, 212), SliceScale = 0.7, Tone = "Parchment", Inner = Rect.new(39, 47, 473, 255) }, -- cream inside: navy text
		RewardPanelHorns = { Id = "rbxassetid://119301483003268", Size = Vector2.new(512, 305), Slice = Rect.new(82, 92, 430, 225), SliceScale = 0.7, Tone = "Navy", Inner = Rect.new(34, 39, 479, 269) }, -- plum inside: white text
		RewardRibbonHalo = { Id = "rbxassetid://108314581848410", Size = Vector2.new(512, 143), TextRect = { 0.22, 0.31, 0.56, 0.44 } }, -- gold band with wings
		RewardRibbonHorns = { Id = "rbxassetid://80274270130287", Size = Vector2.new(512, 149), TextRect = { 0.12, 0.33, 0.76, 0.41 } }, -- red band, horns + forked tails
		RewardRibbonHaloStraight = { Id = "rbxassetid://127336158318218", Size = Vector2.new(512, 100), Slice = Rect.new(71, 49, 441, 51), FitHeight = true, TextRect = { 0.14, 0.3, 0.72, 0.52 } },
		RewardRibbonHornsStraight = { Id = "rbxassetid://83671618689638", Size = Vector2.new(512, 106), Slice = Rect.new(42, 52, 469, 54), FitHeight = true, TextRect = { 0.1, 0.26, 0.8, 0.5 } },
		RewardSlot = { Id = "rbxassetid://131467829477534", Size = Vector2.new(256, 252), Tone = "Navy", Inner = Rect.new(31, 32, 225, 219) }, -- gold rim, navy inside
		RewardGlow = { Id = "rbxassetid://134856789083293", Size = Vector2.new(512, 512) }, -- round soft glow behind the ribbon (breathes)
		RewardSparkle = { Id = "rbxassetid://139083428436055", Size = Vector2.new(256, 256) }, -- 4-point twinkle
		GlyphBack = { Id = "rbxassetid://84595951514011", Size = Vector2.new(512, 512) },
		GlyphLock = { Id = "rbxassetid://140357879006452", Size = Vector2.new(512, 512) },
		GlyphCheck = { Id = "rbxassetid://76746602947118", Size = Vector2.new(512, 512) },
		Skill_Warrior_Q = { Id = "rbxassetid://113383058913403", Size = Vector2.new(512, 512) }, -- bundle 14 skill Q icons (in the round BtnSkill ~74%)
		Skill_Mage_Q = { Id = "rbxassetid://125518430228988", Size = Vector2.new(512, 512) },
		Skill_Archer_Q = { Id = "rbxassetid://107372298235964", Size = Vector2.new(512, 512) },
		-- A23-49 skill kit icons (a133773, SKL-5a / 5b): Skill_<Kit>_<Slot>, one icon for both factions (the BtnSkill rim
		-- colour tells them apart); Blacksmith Q / Z = Warrior's, Alchemist Q / Z = Mage's in the beta (skill_kit §7)
		Skill_Warrior_Z = { Id = "rbxassetid://110543257179920", Size = Vector2.new(512, 512) },
		Skill_Warrior_X = { Id = "rbxassetid://137447181619302", Size = Vector2.new(512, 512) },
		Skill_Mage_Z = { Id = "rbxassetid://115260232234150", Size = Vector2.new(512, 512) },
		Skill_Mage_X = { Id = "rbxassetid://132993828889391", Size = Vector2.new(512, 512) },
		Skill_Archer_Z = { Id = "rbxassetid://128895673530336", Size = Vector2.new(512, 512) },
		Skill_Archer_X = { Id = "rbxassetid://113854418875147", Size = Vector2.new(512, 512) },
		Skill_Tamer_Q = { Id = "rbxassetid://120034309999138", Size = Vector2.new(512, 512) },
		Skill_Tamer_Z = { Id = "rbxassetid://74796187578422", Size = Vector2.new(512, 512) },
		Skill_Tamer_X = { Id = "rbxassetid://81030071007443", Size = Vector2.new(512, 512) },
		Skill_Blacksmith_X = { Id = "rbxassetid://74870682122468", Size = Vector2.new(512, 512) },
		Skill_Alchemist_X = { Id = "rbxassetid://130441529340108", Size = Vector2.new(512, 512) },
		-- A23-51 my arrow on the live minimap (a133773): white + light grey shading, thick navy rim; ImageColor3 = my faction
		-- colour keeps the rim; up = forward; 24-32 px at the map's centre
		MapPlayerArrow = { Id = "rbxassetid://113931548210892", Size = Vector2.new(512, 512) },
		-- A23-66 / UI idea #1 (17817e6, user OK): my arrow per faction, drawn as is (white, never tinted), up = forward,
		-- the centre = the turning point; MapPlayerArrow (tinted) stays for the Guild / no faction
		MapArrowHalo = { Id = "rbxassetid://102236026912773", Size = Vector2.new(512, 512) },
		MapArrowHorns = { Id = "rbxassetid://119222134756742", Size = Vector2.new(512, 512) },
		-- A23-53 the big map window's background (world map v2 A2_2, High 1d58f6c: no face look on the horned fortress's
		-- middle tower, a crown medallion in the ruins; coastlines within 0.9 px): 1024x683, no lettering. It lines up with the
		-- v2 world layout only (Config.Map v2 numbers, 게임성 개발 1): px = X0 + (x + OffX) * K, py = (z + OffZ) * K (studs ->
		-- image px; 이미지 생성 1's 1536 transform x 2/3)
		WorldMapV2 = { Id = "rbxassetid://94679214685541", Size = Vector2.new(1024, 683),
			Map = { X0 = 30.815, K = 0.47407, OffX = 230, OffZ = 720 } },
		-- A23-40 정정 fold-out / window icons (7fb375a): 이동 is a [메뉴] square; 직업 바꾸기 · 환생 · 오프닝 · 알림(이름 공개) · 휴가
		-- go on 설정 rows and 닉네임 on 내 캐릭터 (BB13). BB11 ranking medals (3c9166a): in front of rows 1-3 (~85% of the row
		-- height); rank 4+ is a number TextLabel
		IconTravel = { Id = "rbxassetid://122749396717224", Size = Vector2.new(512, 512) },
		IconClassChange = { Id = "rbxassetid://84376751004017", Size = Vector2.new(512, 512) },
		IconRebirth = { Id = "rbxassetid://96377940849921", Size = Vector2.new(512, 512) },
		IconNickname = { Id = "rbxassetid://112860477776524", Size = Vector2.new(512, 512) },
		IconOpening = { Id = "rbxassetid://74327546251541", Size = Vector2.new(512, 512) },
		IconAnnounce = { Id = "rbxassetid://82534665069625", Size = Vector2.new(512, 512) },
		IconVacation = { Id = "rbxassetid://104205149645477", Size = Vector2.new(512, 512) },
		IconMedalGold = { Id = "rbxassetid://100897193417032", Size = Vector2.new(512, 512) },
		IconMedalSilver = { Id = "rbxassetid://86859981439769", Size = Vector2.new(512, 512) },
		IconMedalBronze = { Id = "rbxassetid://129231723184529", Size = Vector2.new(512, 512) },
		-- rank title badges (9be09d8 / 1f059dc / 552fd95, 검수 OK): beside a name tag title / on a profile at 24-40 px, in the
		-- order of the Halo / Horns title tables (R1 lowest)
		BadgeHaloR1 = { Id = "rbxassetid://127364191131841", Size = Vector2.new(512, 512) },
		BadgeHaloR2 = { Id = "rbxassetid://137484666307607", Size = Vector2.new(512, 512) },
		BadgeHaloR3 = { Id = "rbxassetid://129437049523618", Size = Vector2.new(512, 512) },
		BadgeHaloR4 = { Id = "rbxassetid://118999354181738", Size = Vector2.new(512, 512) },
		BadgeHaloR5 = { Id = "rbxassetid://74618033435632", Size = Vector2.new(512, 512) },
		BadgeHornsR1 = { Id = "rbxassetid://99890678318399", Size = Vector2.new(512, 512) },
		BadgeHornsR2 = { Id = "rbxassetid://136024745343474", Size = Vector2.new(512, 512) },
		BadgeHornsR3 = { Id = "rbxassetid://89904764899716", Size = Vector2.new(512, 512) },
		BadgeHornsR4 = { Id = "rbxassetid://133292927494210", Size = Vector2.new(512, 512) },
		BadgeHornsR5 = { Id = "rbxassetid://140229377846074", Size = Vector2.new(512, 512) },
		BadgeArtisan = { Id = "rbxassetid://112093801966686", Size = Vector2.new(512, 512) }, -- the Artisan guild title
		BadgeGrayLegend = { Id = "rbxassetid://127823734946281", Size = Vector2.new(512, 512) }, -- the grey legend (turncoat) title
		-- world map markers (white-rimmed discs like MapBlacksmith; 648f8f9 + 1f059dc): towns = navy discs, zones = mood colours
		MapCrossroads = { Id = "rbxassetid://78524981424841", Size = Vector2.new(512, 512) },
		MapHaloTown = { Id = "rbxassetid://96148211490451", Size = Vector2.new(512, 512) },
		MapHornsTown = { Id = "rbxassetid://118698770642566", Size = Vector2.new(512, 512) },
		MapArtisanGuild = { Id = "rbxassetid://88247282089612", Size = Vector2.new(512, 512) },
		MapZoneMeadow = { Id = "rbxassetid://90468366478665", Size = Vector2.new(512, 512) },
		MapZoneGoblinWoods = { Id = "rbxassetid://87656535919420", Size = Vector2.new(512, 512) },
		MapZoneSkeletonRuins = { Id = "rbxassetid://140159489622516", Size = Vector2.new(512, 512) },
		MapZonePumpkinField = { Id = "rbxassetid://137146546854171", Size = Vector2.new(512, 512) },
		MapZoneHauntedHollow = { Id = "rbxassetid://126361608809712", Size = Vector2.new(512, 512) },
		MapKaiju = { Id = "rbxassetid://105547922444119", Size = Vector2.new(512, 512) },
		MapGrudgeSack = { Id = "rbxassetid://84005598517360", Size = Vector2.new(512, 512) },
		MapPvP = { Id = "rbxassetid://118074682518530", Size = Vector2.new(512, 512) },
		IconChipPumpkinKing = { Id = "rbxassetid://137587017958008", Size = Vector2.new(512, 512) }, -- event chip heads (left of '호박 대왕까지 m:ss' / the ghost king's chip)
		IconChipGhostKing = { Id = "rbxassetid://139986664903918", Size = Vector2.new(512, 512) },
		ToggleTrack = { Id = "rbxassetid://101018450994489", Size = Vector2.new(512, 183) }, -- BB3 settings switch track (ON colour = ImageColor3); ToggleKnob rides on it (~1.15x its height)
		ToggleKnob = { Id = "rbxassetid://115651000790819", Size = Vector2.new(512, 512) },
		GlyphGear = { Id = "rbxassetid://103647965370087", Size = Vector2.new(512, 512) }, -- settings gear glyph (window title / buttons)
		PortraitFrame = { Id = "rbxassetid://128161442754384", Size = Vector2.new(512, 498) }, -- dialogue NPC portrait frame: the portrait sits on Window (0.107, 0.116, 0.783, 0.759)
		-- A23-46 / A23-59 town quest NPC portraits (이미지 생성 2, user OK 2026-10-06: 91cc2c9 · 309c692), transparent, no
		-- lettering: UIKit.Portrait draws one on PortraitFrame's window (bottom-aligned, centred, rounded corners)
		PTR_TownBright = { Id = "rbxassetid://121040553911308", Size = Vector2.new(512, 512) }, -- Halo town guard trainee (chest star, 2026-10-08)
		PTR_TownSmokey = { Id = "rbxassetid://91810571998991", Size = Vector2.new(400, 512) }, -- Horns den lookout
		PTR_TownTiny = { Id = "rbxassetid://107434856525614", Size = Vector2.new(445, 512) }, -- Crossroads artisan trainee
		PTR_CrownShard = { Id = "rbxassetid://131966294834604", Size = Vector2.new(443, 512) }, -- the Crown Shard speaker (Speakers.Shard / Fountain; High, d9aec52)
		PetCard = { Id = "rbxassetid://129842998819313", Size = Vector2.new(462, 768) }, -- pet window / book card: picture Window (0.126, 0.121, 0.747, 0.444), Name (0.10, 0.60, 0.80, 0.075), Body (0.08, 0.70, 0.84, 0.18)
		-- Firefly GPT Image 2.5 batch 2026-10-06 (art/approved.json), 512x512, transparent
		-- monster heads (quest kill rows IconMon<Unit>, drop notices)
		IconMonBigSlime = { Id = "rbxassetid://137346108147632", Size = Vector2.new(512, 512) },
		IconMonGoblin = { Id = "rbxassetid://84081351311140", Size = Vector2.new(512, 512) },
		IconMonGoblinBrute = { Id = "rbxassetid://121297622077113", Size = Vector2.new(512, 512) },
		IconMonSkeleton = { Id = "rbxassetid://140176829708782", Size = Vector2.new(512, 512) },
		IconMonSkeletonKnight = { Id = "rbxassetid://81833958125033", Size = Vector2.new(512, 512) },
		-- E12 woods daily / PvP daily rows (28c6324, High, the navy-rimmed icon frame; drawn as is, no tint): the golden
		-- monster row, Halo's Hunt row, Horns' Plunder row, the woods daily chest (Lv10-24)
		IconGoldenMon = { Id = "rbxassetid://117889924897289", Size = Vector2.new(512, 512) },
		IconHunt = { Id = "rbxassetid://73974758192262", Size = Vector2.new(512, 512) },
		IconPlunder = { Id = "rbxassetid://79074522466902", Size = Vector2.new(512, 512) },
		IconChestWoods = { Id = "rbxassetid://121321744394366", Size = Vector2.new(512, 512) },
		-- materials (Config.Loot.Items[*].Icon)
		IconJelly = { Id = "rbxassetid://120712914963442", Size = Vector2.new(512, 512) },
		IconSlimeCore = { Id = "rbxassetid://135486964395284", Size = Vector2.new(512, 512) },
		IconGoblinTooth = { Id = "rbxassetid://100497489565353", Size = Vector2.new(512, 512) },
		IconBruteHorn = { Id = "rbxassetid://98889017812315", Size = Vector2.new(512, 512) },
		IconBone = { Id = "rbxassetid://100958295836955", Size = Vector2.new(512, 512) },
		IconKnightCrest = { Id = "rbxassetid://110078802549970", Size = Vector2.new(512, 512) },
		-- scrolls: body + Band tint mask on the same canvas (UIKit.ItemIcon tints Band with the item's Color)
		IconScrollEnh = { Id = "rbxassetid://101934277204994", Size = Vector2.new(512, 512) },
		IconScrollEnhBand = { Id = "rbxassetid://95290541806447", Size = Vector2.new(512, 512) },
		IconScrollMove = { Id = "rbxassetid://104385440203016", Size = Vector2.new(512, 512) },
		IconScrollMoveBand = { Id = "rbxassetid://71896284079944", Size = Vector2.new(512, 512) },
		-- ranking window tabs (BB10 / BB11, A23-23 / A23-24)
		IconRankHonor = { Id = "rbxassetid://82203370340706", Size = Vector2.new(512, 512) },
		IconRankInfamy = { Id = "rbxassetid://129377069179379", Size = Vector2.new(512, 512) },
		IconRankArtisan = { Id = "rbxassetid://96372902638765", Size = Vector2.new(512, 512) },
		IconRankPvP = { Id = "rbxassetid://118972460416266", Size = Vector2.new(512, 512) }, -- redrawn 2026-10-06 (blades cross in an X)
		-- User-approved E sprites; shared legacy keys remain unchanged.
		-- pick screens: bundle 2 (5d16034, Firefly, wordless) text-free card backgrounds, regions in CardLayout; A23-48 the
		-- game writes every word on them in English (the baked Korean FactionE cards are off)
		CardHalo = { Id = "rbxassetid://116448859963324", Size = Vector2.new(622, 1024) },
		CardHorns = { Id = "rbxassetid://116416538185922", Size = Vector2.new(657, 1024) },
		CardNeutral = { Id = "rbxassetid://117830833611240", Size = Vector2.new(586, 1024) }, -- FactionCardArtisan
		ClassCardHalo = { Id = "rbxassetid://83370147336230", Size = Vector2.new(569, 1024) },
		ClassCardHorns = { Id = "rbxassetid://96506679569017", Size = Vector2.new(529, 1024) },
		ClassCardNeutral = { Id = "rbxassetid://112912477016552", Size = Vector2.new(581, 1024) }, -- ClassCardArtisan
		-- bundle 2 title ribbon (crown + halo + horn, text in TextRect), premise panel and footer capsule (navy: white text)
		FactionTitle = { Id = "rbxassetid://126167902049009", Size = Vector2.new(1024, 389), TextRect = { 0.22, 0.38, 0.56, 0.34 } }, -- the scroll band between its folds
		-- A23-57 picker redraw (이미지 생성 2, user OK 2026-10-06, c7c13d4): wordless art, the game's English text on top
		-- (CardLayout FactionPick* / ClassPick* regions). Ids "" until the upload: the pickers keep the bundle 2 cards
		-- (CardHalo / ClassCardHalo ...) meanwhile (IMG-R4). The 12 class pictures are already cut to the card's window
		-- (eyes at 20 %, feet at 92 %): drawn exactly on ClassPick*'s Portrait region, by the player's chosen gender.
		FactionPickTitle = { Id = "rbxassetid://109240387368574", Size = Vector2.new(1024, 373), TextRect = { 0.148, 0.41, 0.704, 0.343 } }, -- HQ redraw 4ceaabf: the band sits a little higher
		FactionPickHalo = { Id = "rbxassetid://78441813872022", Size = Vector2.new(624, 1024) },
		FactionPickHorns = { Id = "rbxassetid://92021424719072", Size = Vector2.new(624, 1024) },
		ClassPickHalo = { Id = "rbxassetid://124189187259241", Size = Vector2.new(555, 1024) },
		ClassPickHorns = { Id = "rbxassetid://71780267521296", Size = Vector2.new(555, 1024) },
		CLS_HaloWarrior_M_Card = { Id = "rbxassetid://113804016014809", Size = Vector2.new(460, 550) },
		CLS_HaloWarrior_F_Card = { Id = "rbxassetid://129768786563436", Size = Vector2.new(460, 550) },
		CLS_HaloMage_M_Card = { Id = "rbxassetid://118225411450017", Size = Vector2.new(460, 550) },
		CLS_HaloMage_F_Card = { Id = "rbxassetid://113800216565552", Size = Vector2.new(460, 550) },
		CLS_HaloArcher_M_Card = { Id = "rbxassetid://115817198015355", Size = Vector2.new(460, 550) },
		CLS_HaloArcher_F_Card = { Id = "rbxassetid://126666354590986", Size = Vector2.new(460, 550) },
		CLS_HornsWarrior_M_Card = { Id = "rbxassetid://74863399200858", Size = Vector2.new(460, 550) },
		CLS_HornsWarrior_F_Card = { Id = "rbxassetid://74943559632831", Size = Vector2.new(460, 550) },
		CLS_HornsMage_M_Card = { Id = "rbxassetid://87840664026840", Size = Vector2.new(460, 550) },
		CLS_HornsMage_F_Card = { Id = "rbxassetid://136362714347322", Size = Vector2.new(460, 550) },
		CLS_HornsArcher_M_Card = { Id = "rbxassetid://75310398708603", Size = Vector2.new(460, 550) },
		CLS_HornsArcher_F_Card = { Id = "rbxassetid://71626258615966", Size = Vector2.new(460, 550) },
		FactionPremise = { Id = "rbxassetid://75757875574311", Size = Vector2.new(1024, 434), Slice = Rect.new(120, 120, 904, 314), SliceScale = 0.22, Tone = "Navy" },
		FactionFooter = { Id = "rbxassetid://97044636639921", Size = Vector2.new(1024, 142), Slice = Rect.new(100, 70, 924, 72), FitHeight = true, Tone = "Navy" },
		ShieldNeutral = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(251, 256) },
		-- empty cream title ribbon (Firefly, 2026-10-06; 그림체 #44 2026-10-08 put it in: the nickname window). Only the
		-- middle stretches (FitHeight): the folded tails x 75-110 / 402-437 stay out of the stretched band. TextRect = the
		-- words' box inside the front band (fractions of the ribbon)
		TitleRibbon = { Id = "rbxassetid://80637744024215", Size = Vector2.new(512, 135), Slice = Rect.new(118, 40, 394, 95),
			FitHeight = true, Tone = "Parchment", TextRect = { 0.19, 0.13, 0.62, 0.55 } },
		-- class characters (Firefly blocky toy style, bundles 10 / 19, 50bf8ea + af64891 clean + 2975f24, user OK):
		-- Char<Faction><Class><M|F>. The Artisan Archer slot is the pet tamer (A23-39: same class id, Artisan look).
		CharHaloWarriorM = { Id = "rbxassetid://99834593537592", Size = Vector2.new(476, 663) },
		CharHaloWarriorF = { Id = "rbxassetid://77794697082835", Size = Vector2.new(514, 768) },
		CharHaloMageM = { Id = "rbxassetid://111869235299985", Size = Vector2.new(540, 768) },
		CharHaloMageF = { Id = "rbxassetid://80196979774942", Size = Vector2.new(408, 768) },
		CharHaloArcherM = { Id = "rbxassetid://84025350196989", Size = Vector2.new(421, 768) },
		CharHaloArcherF = { Id = "rbxassetid://140703417172799", Size = Vector2.new(412, 768) },
		CharHornsWarriorM = { Id = "rbxassetid://78913683328711", Size = Vector2.new(545, 768) },
		CharHornsWarriorF = { Id = "rbxassetid://80398924855230", Size = Vector2.new(561, 768) },
		CharHornsMageM = { Id = "rbxassetid://103776157579556", Size = Vector2.new(540, 768) },
		CharHornsMageF = { Id = "rbxassetid://119210041139755", Size = Vector2.new(502, 768) },
		CharHornsArcherM = { Id = "rbxassetid://86882952509293", Size = Vector2.new(449, 768) },
		CharHornsArcherF = { Id = "rbxassetid://115512398752881", Size = Vector2.new(422, 768) },
		CharNeutralWarriorM = { Id = "rbxassetid://136710646034221", Size = Vector2.new(401, 768) },
		CharNeutralWarriorF = { Id = "rbxassetid://111502444868547", Size = Vector2.new(498, 768) },
		CharNeutralMageM = { Id = "rbxassetid://83660332451200", Size = Vector2.new(464, 768) },
		CharNeutralMageF = { Id = "rbxassetid://103974202488908", Size = Vector2.new(402, 768) },
		CharNeutralArcherM = { Id = "rbxassetid://139781808666841", Size = Vector2.new(414, 768) },
		CharNeutralArcherF = { Id = "rbxassetid://116024640272965", Size = Vector2.new(431, 768) },
		-- perk / misc icons
		IconExp = { Id = "rbxassetid://125679953240313", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconHeart = { Id = "rbxassetid://92865909915468", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconWings = { Id = "rbxassetid://78896204690689", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconGoldPile = { Id = "rbxassetid://140588051269822", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconGoldGuard = { Id = "rbxassetid://137696635031445", Size = Vector2.new(512, 512) }, -- Firefly 2026-10-06: Horns perk 3 (keep plundered gold)
		IconBloodSword = { Id = "rbxassetid://80973759611362", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconGauge = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(256, 70) },
		IconDemon = { Id = "rbxassetid://101305375688321", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		-- A23-75 round pass badges (user pick "B", 이미지 생성 2 2096b5f, 512 round alpha): the Shop cards show them alone
		IconPassXP2 = { Id = "rbxassetid://84663066597118", Size = Vector2.new(512, 512) }, -- PassIconExp2.png
		IconPassGold2 = { Id = "rbxassetid://100341080284667", Size = Vector2.new(512, 512) }, -- PassIconGold2.png
		IconPassVIP = { Id = "rbxassetid://98036294458431", Size = Vector2.new(512, 512) }, -- PassIconVIP.png
		IconPassLooks = { Id = "rbxassetid://136373208143894", Size = Vector2.new(512, 512) }, -- PassIconBundle.png (the Looks header)
		-- A23-75 / A23-77 look icons (이미지 생성 2 5cd9d28 / 565e19f, 검수 OK): 'Look' .. the Config.LookThemes id; the
		-- shop's Looks tiles and the attendance board draw them (R3 shape render, navy rim)
		LookHaloIce = { Id = "rbxassetid://131721415854040", Size = Vector2.new(512, 512) },
		LookHaloGold = { Id = "rbxassetid://90123867490784", Size = Vector2.new(512, 512) },
		LookHornsLava = { Id = "rbxassetid://110647559507483", Size = Vector2.new(512, 512) },
		LookHornsShadow = { Id = "rbxassetid://135507968189284", Size = Vector2.new(512, 512) },
		LookHaloSprout = { Id = "rbxassetid://83263248829283", Size = Vector2.new(512, 512) },
		LookHornsSprout = { Id = "rbxassetid://116226794293707", Size = Vector2.new(512, 512) },
		LookHaloStarlight = { Id = "rbxassetid://132781328122100", Size = Vector2.new(512, 512) },
		LookHornsStarlight = { Id = "rbxassetid://140058187507403", Size = Vector2.new(512, 512) },
		LookHaloPlatinum = { Id = "rbxassetid://78646024449809", Size = Vector2.new(512, 512) },
		LookHornsPlatinum = { Id = "rbxassetid://123042000375413", Size = Vector2.new(512, 512) },
		IconPrivateServer = { Id = "rbxassetid://95789432053642", Size = Vector2.new(512, 512) }, -- PassIconPrivate.png (이미지 생성 2 c5150fa, 검수 고름 A23-79)
		-- A23-77 attendance board / A23-79 come-back art (이미지 생성 2 514737f, 검수 OK; 512, no letters - numbers are TextLabels)
		IconWeeklyBox = { Id = "rbxassetid://134725206012544", Size = Vector2.new(512, 512) }, -- the 7th slot's weekly box
		StampClaimed = { Id = "rbxassetid://133963492491506", Size = Vector2.new(512, 512) }, -- laid over a claimed slot
		-- collected-days ribbons: the number sits in the empty cream disc - centre (0.497, 0.407), size 0.432 x 0.412 of the
		-- picture (이미지 생성 2 measured all five); keep the digits inside ~70 % of it so they never touch the rim
		RibbonDays7 = { Id = "rbxassetid://74039691524147", Size = Vector2.new(512, 512) },
		RibbonDays14 = { Id = "rbxassetid://128474383322866", Size = Vector2.new(512, 512) },
		RibbonDays28 = { Id = "rbxassetid://105857078981391", Size = Vector2.new(512, 512) },
		RibbonDays50 = { Id = "rbxassetid://127528019933746", Size = Vector2.new(512, 512) },
		RibbonDays100 = { Id = "rbxassetid://104467679017156", Size = Vector2.new(512, 512) },
		IconKingDiary = { Id = "rbxassetid://82663430349001", Size = Vector2.new(512, 512) }, -- [King Diary] book
		IconDiary = { Id = "rbxassetid://82663430349001", Size = Vector2.new(512, 512) }, -- 검수 10/08: the menu square / Diary window = the same King Diary book
		IconCandyJar = { Id = "rbxassetid://94570617639866", Size = Vector2.new(512, 512) }, -- candy jar
		IconInviteFriend = { Id = "rbxassetid://72491188968210", Size = Vector2.new(512, 512) }, -- [Invite a friend]
		IconSaved = { Id = "rbxassetid://112371750811683", Size = Vector2.new(512, 512) }, -- the pause card's 'Saved!'
		IconNoBuff = { Id = "rbxassetid://125613826056625", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06, re-cut 3f1716b (faction perk row)
		IconShieldBlue = { Id = "rbxassetid://97867243551313", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconNoLoot = { Id = "rbxassetid://105527491154744", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconHammer = { Id = "rbxassetid://134187840367993", Size = Vector2.new(512, 512) }, -- Firefly (bundle 5): artisan perk 4
		IconAltar = { Id = "rbxassetid://115731843863081", Size = Vector2.new(512, 512) },
		IconBoot = { Id = "rbxassetid://121630849275556", Size = Vector2.new(512, 512) }, -- Firefly winged boot (bundle 5): class speed / pet speed
		-- A15 hit/pain art; empty IDs retain the code fallback.
		FxSlash = { Id = "rbxassetid://99494789057875", Size = Vector2.new(256, 251) },
		FxHitSpark = { Id = "rbxassetid://122673635344930", Size = Vector2.new(512, 512) }, -- 2026-10-08 redraw: a puff + stars, no rays
		FxShockRing = { Id = "rbxassetid://135827777163619", Size = Vector2.new(256, 252) },
		FxMagicBurst = { Id = "rbxassetid://124326448818980", Size = Vector2.new(512, 512) }, -- 2026-10-08 redraw: a round cloud
		FxDust = { Id = "rbxassetid://108076168454993", Size = Vector2.new(222, 256) },
		-- 검수 2026-10-08 (user: "아야 영어로"): 72032537654477 has a Korean "아야!" drawn in and a spiky burst rim (ray rule) -
		-- off until 이미지 생성 2's round English bubble; empty = Fx's code "Ouch!" bubble (EMO_FALLBACK)
		-- 2026-10-08: a blank round bubble; Fx draws "Ouch!" in TextRect (x, y, w, h of the art, 0..1)
		EmoOuch = { Id = "rbxassetid://114387365320855", Size = Vector2.new(512, 512), TextRect = { 0.17, 0.26, 0.66, 0.42 } },
		EmoTears = { Id = "rbxassetid://113193582610345", Size = Vector2.new(512, 512) },
		EmoDizzy = { Id = "rbxassetid://117032268995160", Size = Vector2.new(512, 512) },
		EmoAngry = { Id = "rbxassetid://79994000943963", Size = Vector2.new(512, 512) },
		EmoStress = { Id = "rbxassetid://132610409379166", Size = Vector2.new(512, 512) },
		Weapon_Warrior_T1 = { Id = "rbxassetid://128452607217223", Size = Vector2.new(512, 512) },
		Weapon_Warrior_T2 = { Id = "rbxassetid://115882263046090", Size = Vector2.new(512, 512) },
		Weapon_Warrior_T3 = { Id = "rbxassetid://99916196093265", Size = Vector2.new(512, 512) }, -- 그림체 #28: the approved b1 master (navy rim, blue grip)
		Weapon_Warrior_T4 = { Id = "rbxassetid://104179222312415", Size = Vector2.new(512, 512) },
		Weapon_Warrior_T5 = { Id = "rbxassetid://94672890742115", Size = Vector2.new(512, 512) },
		Weapon_Warrior_T6 = { Id = "rbxassetid://90778236753102", Size = Vector2.new(512, 512) },
		Weapon_Warrior_T7_Halo = { Id = "rbxassetid://81358930713578", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T7_Horns = { Id = "rbxassetid://109996418847092", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T7_Neutral = { Id = "rbxassetid://113768226721190", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T1 = { Id = "rbxassetid://101211434272271", Size = Vector2.new(512, 512) },
		Weapon_Mage_T2 = { Id = "rbxassetid://116724090045503", Size = Vector2.new(512, 512) },
		Weapon_Mage_T3 = { Id = "rbxassetid://133774997043450", Size = Vector2.new(512, 512) },
		Weapon_Mage_T4 = { Id = "rbxassetid://128100201964506", Size = Vector2.new(512, 512) },
		Weapon_Mage_T5 = { Id = "rbxassetid://126284521382436", Size = Vector2.new(512, 512) },
		Weapon_Mage_T6 = { Id = "rbxassetid://90089061818132", Size = Vector2.new(512, 512) },
		Weapon_Mage_T7_Halo = { Id = "rbxassetid://83762763419599", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T7_Horns = { Id = "rbxassetid://112320137471828", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T7_Neutral = { Id = "rbxassetid://111298666053873", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T1 = { Id = "rbxassetid://81095006038493", Size = Vector2.new(512, 512) },
		Weapon_Archer_T2 = { Id = "rbxassetid://134554794160337", Size = Vector2.new(512, 512) },
		Weapon_Archer_T3 = { Id = "rbxassetid://109990549438603", Size = Vector2.new(512, 512) },
		Weapon_Archer_T4 = { Id = "rbxassetid://108956952874353", Size = Vector2.new(512, 512) },
		Weapon_Archer_T5 = { Id = "rbxassetid://99169898262905", Size = Vector2.new(512, 512) },
		Weapon_Archer_T6 = { Id = "rbxassetid://113396206645322", Size = Vector2.new(512, 512) },
		Weapon_Archer_T7_Halo = { Id = "rbxassetid://123944650415871", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T7_Horns = { Id = "rbxassetid://129557918253283", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T7_Neutral = { Id = "rbxassetid://134108221476202", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T8 = { Id = "rbxassetid://73318746668169", Size = Vector2.new(512, 512) }, -- jelly-crown legendary (bundle 9)
		Weapon_Mage_T8 = { Id = "rbxassetid://109033955946235", Size = Vector2.new(512, 512) },
		Weapon_Archer_T8 = { Id = "rbxassetid://118154781260735", Size = Vector2.new(512, 512) },
		-- 2026-10-08 meadow terrain v3 (이미지 생성 1, 검수 OK; user: "너무 초록, 입체적이지 않아"): Tex_Grass_FF3 on Grass and three
		-- new meadow tiles on base materials no part uses (Salt / Sandstone / Pavement, 검수 checked the main save);
		-- tools/apply_surface_materials.lua pairs them (Organic, 22 / 16 studs a tile)
		Tex_Grass = { Id = "rbxassetid://116841810719907", Size = Vector2.new(1024, 1024) }, -- Tex_Grass_FF3 (was FF2)
		Tex_MeadowFlowers = { Id = "rbxassetid://112552326538919", Size = Vector2.new(1024, 1024) }, -- Tex_MeadowFlowers_FF3 -> Salt (GE_MeadowFlowers)
		Tex_MeadowShade = { Id = "rbxassetid://100025729953105", Size = Vector2.new(1024, 1024) }, -- Tex_GrassShade_FF3 -> Sandstone (GE_MeadowShade)
		Tex_MeadowDirt = { Id = "rbxassetid://111724093383818", Size = Vector2.new(1024, 1024) }, -- Tex_MeadowDirt_FF3code -> Pavement (GE_MeadowDirt)
		Tex_LeafyGrass = { Id = "rbxassetid://96379070214723", Size = Vector2.new(1024, 1024) }, -- forest floor Tex_LeafyGrass_FF3 (2026-10-08 woods gap ④: mossier, fewer brown spots; was FF2)
		Tex_HaloTiles = { Id = "rbxassetid://108329087203475", Size = Vector2.new(1024, 1024) },
		Tex_Ground = { Id = "rbxassetid://140158008208812", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: ruins dirt (Tex_Ground_FF)
		Tex_DirtPath = { Id = "rbxassetid://140356696032031", Size = Vector2.new(1024, 1024) }, -- A23-30 E: road (Tex_DirtPath_FF)
		Tex_CrownShardGround = { Id = "rbxassetid://114856730896342", Size = Vector2.new(1024, 1024) },
		Tex_CrackedLava = { Id = "rbxassetid://116294435572633", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: Horns lava cracks (Tex_CrackedLava_FF)
		Tex_Cobblestone = { Id = "rbxassetid://86097337095441", Size = Vector2.new(1024, 1024) }, -- A23-30 E: town cobbles (Tex_Cobblestone_FF)
		Tex_Basalt = { Id = "rbxassetid://90858017609308", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: Horns lair floor; quality 7 (cdaaeaa) Tex_Basalt_FF2 = darks lifted (was Tex_Basalt_FF rbxassetid://82958066906333)
		Tex_WoodPlanks = { Id = "rbxassetid://89937004688664", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: bridges / benches (parts) (Tex_WoodPlanks_FF)
		Tex_Slate = { Id = "rbxassetid://117516477244385", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: ruins flagstones (Tex_RuinsFlagstone_FF)
		Tex_Sand = { Id = "rbxassetid://131974232864115", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: beaches (Tex_Sand_FF)
		Tex_Rock = { Id = "rbxassetid://81976112942859", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: every cliff (Tex_Rock_FF)
		Tex_Marble = { Id = "rbxassetid://82709638100363", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: fountain / Halo parts (Tex_Marble_FF)
		Tex_Limestone = { Id = "rbxassetid://105789118055805", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: Halo town floor (Tex_Limestone_FF)
		Tex_PumpkinSoil = { Id = "rbxassetid://101513604708442", Size = Vector2.new(1024, 1024) }, -- A23-30 pumpkin field soil (Mud slot)
		Tex_TreeLeaves = { Id = "rbxassetid://139379724133324", Size = Vector2.new(1024, 1024) }, -- tree leaf balls (neutral: the part Color tints it)
		Tex_TreeBark = { Id = "rbxassetid://85265884740870", Size = Vector2.new(1024, 1024) }, -- tree trunks (neutral: the part Color tints it)
		Tex_HauntedFloor = { Id = "rbxassetid://78580688016455", Size = Vector2.new(1024, 1024) }, -- A23-45 유령 숲 floor (Tex_HauntedFloor_FF): Asphalt slot GE_HauntedFloor
		Tex_WaterfallFlow = { Id = "rbxassetid://86909517913668", Size = Vector2.new(1024, 1024) }, -- A23-76 waterfall face (이미지 생성 1 ca0dfea, Tex_WaterfallFlow_FF2): streams run top -> bottom (V down)
		-- sky sun / moon (black = transparent, additive): WarService Sky.SunTextureId / MoonTextureId per war sky
		Sky_Sun = { Id = "rbxassetid://104329382887122", Size = Vector2.new(512, 512) }, -- Neutral sun
		Sky_SunDawn = { Id = "rbxassetid://134904669662412", Size = Vector2.new(512, 512) }, -- Dawn (Halo crown) sun
		Sky_MoonEclipse = { Id = "rbxassetid://101354392666522", Size = Vector2.new(512, 512) }, -- Eclipse (Horns crown) moon
		MapParchment = { Id = "rbxassetid://114711223801871", Size = Vector2.new(1536, 1024) },
	},
	-- Lettering images (TXT_*) were deleted 2026-10-06 (unused: UseTextImages=false). Text stays live TextLabels.
	TextLabels = {},
	-- picked from the mockup (UI_HUD_Final.png) and the part images
	Colors = {
		-- text
		-- 그림체 #44 (검수 2026-10-08): the words, rims and outlines are navy like the Firefly frames (UIKit STYLE.Navy);
		-- they were the old GPT art's brown (66,40,18 / 110,66,24 / 34,20,10)
		Ink = Color3.fromRGB(27, 33, 64), -- navy words on light plates (parchment, cream rows, chips)
		InkSoft = Color3.fromRGB(70, 78, 110), -- secondary words on light plates (3/5, hints)
		InkOutline = Color3.fromRGB(255, 247, 228), -- light halo around ink text
		Light = Color3.fromRGB(255, 255, 255), -- white text on navy / red / ribbon
		LightSub = Color3.fromRGB(226, 222, 206), -- labels on navy (금고, 주머니)
		TextOutline = Color3.fromRGB(27, 33, 64), -- navy outline for white / gold text
		GoldText = Color3.fromRGB(255, 228, 100), -- numbers on navy (금고 1,250 / Lv)
		GoldInk = Color3.fromRGB(236, 164, 16), -- gold numbers on parchment (150G, +120); use with TextOutline
		GoodInk = Color3.fromRGB(40, 140, 60), -- done / 받기 on parchment
		BadInk = Color3.fromRGB(190, 40, 40),
		-- fills (also the IMG-R4 fallback fills, keyed by Part.Tone)
		Parchment = Color3.fromRGB(242, 221, 178),
		ParchmentDark = Color3.fromRGB(214, 182, 128), -- dividers / empty slots on parchment
		Ribbon = Color3.fromRGB(241, 207, 132),
		Rim = Color3.fromRGB(27, 33, 64), -- navy outline (fallback stroke)
		Navy = Color3.fromRGB(26, 40, 79),
		NavyDeep = Color3.fromRGB(19, 31, 56), -- bar track interior
		Gold = Color3.fromRGB(240, 190, 60), -- gold trim
		-- 그림체 #14: the white Firefly 'Star' part tinted (ImageColor3): a filled star / an empty star
		StarGold = Color3.fromRGB(245, 197, 66),
		StarEmpty = Color3.fromRGB(70, 78, 110),
		Red = Color3.fromRGB(225, 40, 36), -- attack button face (pre-Firefly)
		Orange = Color3.fromRGB(246, 130, 32), -- Firefly attack disc face (bundle 6)
		Confirm = Color3.fromRGB(76, 175, 60), -- Firefly green capsule (BtnConfirm)
		-- bars
		XPBlue = Color3.fromRGB(30, 170, 255),
		QuestBlue = Color3.fromRGB(56, 144, 253),
		-- A23-36 quest marker tint (white IconQuestMarker art, navy rim): in progress white, waiting for [Claim] light gold.
		-- Sky blue was tried first: 2.2:1 on the meadow's dark grass (UiSandbox 2026-10-06), under the rubric's 3:1
		MarkerGo = Color3.fromRGB(255, 255, 255),
		MarkerClaim = Color3.fromRGB(255, 228, 128),
		UpgradeGold = Color3.fromRGB(245, 196, 64),
		WarHalo = Color3.fromRGB(252, 198, 52),
		WarHorns = Color3.fromRGB(243, 38, 44),
		-- status chips
		ChipSafe = Color3.fromRGB(112, 214, 120),
		ChipSafeText = Color3.fromRGB(18, 50, 22),
		ChipSafeRim = Color3.fromRGB(40, 120, 50),
		ChipRookie = Color3.fromRGB(182, 229, 251),
		ChipRookieText = Color3.fromRGB(16, 40, 110),
		ChipRookieRim = Color3.fromRGB(60, 130, 200),
		-- key hint badges (F / Q / R / M ..., keyboard only)
		KeyHintBg = Color3.fromRGB(60, 44, 34),
		KeyHintText = Color3.fromRGB(255, 255, 255),
	},
	-- ART_DIRECTION: Korean labels in Gotham (Korean renders in the fallback font), numbers / Lv / timers in FredokaOne
	Fonts = {
		Title = Enum.Font.GothamBlack,
		Body = Enum.Font.GothamBold,
		Number = Enum.Font.FredokaOne,
	},
	-- UIStroke outline thickness for UIKit.InkText / UIKit.LightText
	OutlineInk = 1,
	OutlineLight = 1.5,
}

-- empty regions of the pick-screen cards, measured from the GPT card art (art/ui/UIP_*.png, PIL region fill).
-- Each region = { x, y, w, h } as fractions of the card image (use UDim2.fromScale(x, y) / UDim2.fromScale(w, h)
-- inside a card box that keeps Aspect = image width / height). Faction cards: Title (name ribbon), Desc (description
-- strip), Motto (motto ribbon), Perks (perk panel), Button (glossy button). Class cards: Portrait (alcove for the
-- character), Name (name ribbon), Body (description + stat bars), Button.
Config.UIArt.CardLayout = { -- bundle 2 regions (art/approved.json layout)
	-- A23-57 redraw: the faction cards' Name ribbon (Title), Panel (Perks) and Button - no Desc / Motto strips; the class
	-- card frames' Portrait window (the CLS_* picture fills it), Name, Body and Button
	FactionPickHalo = { Aspect = 0.609, Title = { 0.2, 0.425, 0.6, 0.076 }, Perks = { 0.146, 0.551, 0.707, 0.266 },
		Button = { 0.224, 0.859, 0.548, 0.061 } },
	FactionPickHorns = { Aspect = 0.609, Title = { 0.2, 0.425, 0.6, 0.076 }, Perks = { 0.146, 0.551, 0.707, 0.266 },
		Button = { 0.224, 0.859, 0.548, 0.061 } },
	-- RibbonTop: the name ribbon's gold rim under the window (centre column of the 555x1024 frames: y 507), the class
	-- word chip sits on it
	ClassPickHalo = { Aspect = 0.542, Portrait = { 0.224, 0.15, 0.552, 0.358 }, Name = { 0.2, 0.509, 0.6, 0.066 },
		Body = { 0.15, 0.646, 0.699, 0.181 }, Button = { 0.225, 0.859, 0.551, 0.072 }, RibbonTop = 0.495 },
	ClassPickHorns = { Aspect = 0.542, Portrait = { 0.224, 0.15, 0.552, 0.358 }, Name = { 0.2, 0.509, 0.6, 0.066 },
		Body = { 0.15, 0.646, 0.699, 0.181 }, Button = { 0.225, 0.859, 0.551, 0.072 }, RibbonTop = 0.495 },
	-- E11 job board: the navy name plate (white "Job Board"), the cork (top line "Kind 12 · Sneaky 3" / "Jobs 1 / 3" +
	-- the cards); a job card's paper (sheet layout by Body height: title 14%, goal 31%, reward 47%, Kind 56-76%,
	-- Sneaky 78-98%, buttons 92% of the Body width)
	JobBoard = { Header = { 0.27, 0.04, 0.461, 0.1 }, Inner = { 0.087, 0.182, 0.829, 0.683 } },
	JobCard = { Body = { 0.065, 0.079, 0.867, 0.861 } },
	CardHalo = { Aspect = 0.607, Title = { 0.217, 0.156, 0.566, 0.115 }, Desc = { 0.154, 0.313, 0.692, 0.049 },
		Motto = { 0.154, 0.392, 0.692, 0.049 }, Perks = { 0.157, 0.491, 0.686, 0.381 }, Button = { 0.243, 0.886, 0.492, 0.083 } },
	CardHorns = { Aspect = 0.642, Title = { 0.236, 0.161, 0.519, 0.097 }, Desc = { 0.184, 0.313, 0.632, 0.062 },
		Motto = { 0.184, 0.408, 0.632, 0.062 }, Perks = { 0.184, 0.518, 0.63, 0.314 }, Button = { 0.27, 0.886, 0.458, 0.05 } },
	CardNeutral = { Aspect = 0.572, Title = { 0.247, 0.203, 0.503, 0.068 }, Desc = { 0.148, 0.332, 0.703, 0.049 },
		Motto = { 0.148, 0.416, 0.703, 0.047 }, Perks = { 0.148, 0.511, 0.703, 0.328 }, Button = { 0.239, 0.88, 0.523, 0.058 } },
	ClassCardHalo = { Aspect = 0.556, Portrait = { 0.177, 0.138, 0.646, 0.313 }, Name = { 0.26, 0.463, 0.485, 0.083 },
		Body = { 0.196, 0.593, 0.609, 0.256 }, Button = { 0.205, 0.904, 0.591, 0.064 } },
	ClassCardHorns = { Aspect = 0.517, Portrait = { 0.169, 0.117, 0.661, 0.349 }, Name = { 0.242, 0.484, 0.518, 0.076 },
		Body = { 0.142, 0.607, 0.715, 0.258 }, Button = { 0.235, 0.898, 0.531, 0.063 } },
	ClassCardNeutral = { Aspect = 0.567, Portrait = { 0.179, 0.123, 0.643, 0.331 }, Name = { 0.239, 0.465, 0.508, 0.079 },
		Body = { 0.196, 0.584, 0.609, 0.276 }, Button = { 0.278, 0.888, 0.439, 0.077 } },
}

-- faction card perk rows (icon part + short plain text, mockup art/out/UI_Faction_B.png). Numbers must match
-- Config.Factions (XPBonus, MaxHPMult, GoldBonus, DamageBonus, ChargeCap) and Config.Kaiju.StarsNeeded.
-- Short (optional) = shorter line used when Text cannot fit its row at the min text size (landscape phones).
Config.UIArt.FactionPerks = {
	Halo = {
		{ Icon = "IconExp", Text = "XP +30%" },
		{ Icon = "IconHeart", Text = "HP +20%, keeps healing", Short = "HP +20%, regen" },
		{ Icon = "IconWings", Text = "Skills heal allies" },
		{ Icon = "IconPouch", Text = "Pouch gold auto-saved", Short = "Auto-save gold" },
	},
	Horns = {
		{ Icon = "IconGoldPile", Text = "Gold +25%" },
		{ Icon = "IconBloodSword", Text = "ATK +15%, Lifesteal", Short = "ATK +15%, steal HP" },
		{ Icon = "IconGoldGuard", Text = "Keep your loot gold", Short = "Guard loot gold" },
		{ Icon = "IconDemon", Text = "5 stars = Kaiju form!", Short = "5★ = Kaiju!" },
	},
	Neutral = {
		{ Icon = "IconNoBuff", Text = "No fight buffs" },
		{ Icon = "IconShieldBlue", Text = "No PvP (safe)" },
		{ Icon = "IconNoLoot", Text = "No loot or Wanted worries", Short = "No loot or Wanted" },
		{ Icon = "IconHammer", Text = "Crafting (coming soon)", Short = "Crafting (soon)" },
	},
}

-- E approval: 2026-10-04. Fixed Korean glyphs preserve the approved illustration.
-- English/localized sprites are a separate release item; live fallbacks stay available.
-- addendum A1: optional custom visual models in ServerStorage[FolderName] named by monster id or GooseId
Config.CustomModels = {
	FolderName = "CustomModels",
	GooseId = "GoldenGoose",
	-- golden variant: gold Highlight instead of recoloring parts. 0.5 looked like see-through jelly on the textured cube
	-- (user 2026-10-06 "투명해 보여"), 0.25 still a flat half-see-through gold layer (an olive ghost on the green slime,
	-- user 2026-10-07 "왜 반투명한 애들이 생기냐고", A23-74): no fill, the body stays opaque under a solid gold rim
	-- (with the gold sparkles, light and name)
	GoldenFillTransparency = 1,
}

-- A23-5 (2026-10-05): every chibi 3D class costume is out of the game (CostumeService and its folders were removed
-- 2026-10-06); players are their own Roblox avatar + class weapon + halo/horns. Roblox-style outfits come later.

----------------------------------------------------------------- story (world flavor text only)
Config.Story = {
	-- plain lines (no format specifiers)
	-- A23-55 / story_depth §0-1 (final ending 1a2475e): the story everyone tells — someone greedy broke the Crown, each
	-- side blames the other. It is a rumor (two kids broke it together, shown only in the last chapter), so every
	-- line says "They say". Premise = the faction picker's premise panel (3 lines, GDD §1-1).
	Premise = {
		"They say someone broke the Crown of Balance.",
		"Some who picked up its shards grew a halo. Others grew horns.",
		"Now each side says the other did it.",
	},
	-- the opening (A23-44 remake) shows OpeningRumor 1-3, then Premise 2-3, then OpeningAsk (story_depth §2-1)
	OpeningRumor = {
		"They say the Crown kept the world in balance.",
		"They say someone wanted it all to themselves.",
		"\"If I can't have it, no one can!\" CRACK.",
	},
	-- The server opens Config.Tutorial.Welcome after the first class choice. Do not overlap it with old toasts.
	Intro = {},
	-- A23-9 opening (subtitles: see OpeningRumor above; plain text). The last chapter asks the same with "today".
	OpeningAsk = "Which side will you choose?",
	OpeningSkip = "Skip",
	OpeningReplay = "Watch the opening again",
	OpeningReplayUnsafe = "You can rewatch the opening inside a town.",
	IntroNeutral = {},
	FactionLore = {
		Halo = "Their Crown Shards became halos. They guard the shards and fix the world.",
		Horns = "Their Crown Shards became horns. They take the shards and rule the world.",
		Neutral = "Those who shape the shards instead of grabbing them.", -- addendum A6
	},
	MarkLore = "Halos and horns are the power of the Crown Shards. They grow as your rank goes up.",
	ZoneLore = {
		Crossroads = "Where the broken crown fell",
		HaloTown = "The castle of those with halos",
		HornsTown = "The den of those with horns",
		SlimeMeadow = "A field of slimes that ate shard dust",
		GoblinWoods = "The woods of the shard thieves",
		SkeletonRuins = "The tomb of the old kingdom",
	},
	-- format strings (always through string.format)
	WarWin = {
		Halo = "The Knights of Light won the crown this round! The sky glows gold.\n(Gold and XP +25%% for 10 minutes)",
		Horns = "The Horn Legion won the crown this round! The sky glows crimson.\n(Gold and XP +25%% for 10 minutes)",
	},
	WarDraw = "Nobody won the crown this round!",
	GooseStart = "A Golden Goose with a Crown Shard landed in the Crossroads!\nKnights rescue it. The Horn Legion poaches it!",
	GooseResult = {
		Halo = "The Knights rescued the Golden Goose! The shard shines with light again.",
		Horns = "The Horn Legion poached the Golden Goose! The shard turned dark.",
		Tie = "The Golden Goose flew away! It's a tie.",
	},
	-- (GooseNoRival removed by A23-14: a goose with no rival is now a "Team Rescue", texts in Config.Goose.Text)
	KaijuSiren = "Alert! %s is being swallowed by the Crown Shard's darkness! A Kaiju in 10 seconds!",
	KaijuStart = "Kaiju %s is here! Knights can attack it anywhere!",
	KaijuDefeated = "The Knights defeated the Kaiju %s! They share a %s gold reward.", -- (name, gold actually paid: CR-L19)
	KaijuDefeatedNoReward = "The Kaiju %s was defeated.", -- CR-L19: (name) nobody was paid
	KaijuSurvived = "The Kaiju %s survived to the end! A Legendary Villain is born!",
	SurviveTitle = "Legendary Villain",
	GrayLegendTitle = "Gray Legend",
	RebirthIntro = "Rebirth lets you pick your Crown Shard again. Which side will you be reborn on?",
	Fall = "Fall: the halo cracked and horns grew. (Gold +5%% forever · torn black cape)",
	Redeem = "Redeem: the horns broke and a cracked halo rose. (XP +5%% forever)",
	SackLore = "Stolen gold carries a grudge. If a knight catches the thief, it comes back at 120%%!",
}

-- addendum A7-3: crown-shard one-liners (<= 30 chars, plain text, no format specifiers) shown only at the matching
-- unlock moment (reaching that zone's MinLevel) and only while Rebirths == 0. Keyed by zone id.
Config.StoryLines = {
	GoblinWoods = "A Crown Shard calls from beyond the woods. Watch out for thieves!",
	SkeletonRuins = "A big shard sleeps in the old kingdom's tomb.",
}

-- addendum A7-3: client "next goal" helpers
Config.NextGoal = {
	RewardSamples = 10, -- "Slime: N more!" uses the average gold of the player's last 10 kill rewards
	MaxKillsShown = 99, -- above this keep the normal upgrade text
	GuideSeconds = 90, -- zone guide (HUD.ShowGuide) auto-clears after this many seconds
	GuideZones = { "GoblinWoods", "SkeletonRuins" }, -- guide on reaching these zones' MinLevel (Lv 10 / Lv 25)
}

-- English message templates (always through string.format). Use these for the listed situations.
Config.Text = {
	LoadFailed = "We couldn't load your save. Please rejoin in a moment.",
	SaveLoading = "Loading your save…", -- A23-48 batch: a load waits for a retry (another server's lock / a DataStore error)
	NeedLevel = "You need Lv %d or higher to enter!",
	EnteredPvP = "PvP zone! Watch out for the other sides.",
	EnteredPvPNeutral = "PvP zone, but the Artisan Guild can't be attacked.", -- CR-L24: Neutral entering a PvP zone ("info")
	EnteredSafe = "Safe zone.",
	Banked = "Put %s gold in your vault.",
	HaloCourier = "An angel courier put %s gold in your vault.",
	LevelUp = "Level up! Lv %d",
	NotEnoughGold = "Not enough gold.",
	WeaponBought = "%s equipped!",
	WeaponMaxed = "You already have the best weapon!",
	WeaponNeedLevel = "You can buy this weapon from Lv %d.", -- purchase gate (an owned one: EquipNeedLevel)
	-- A23-28: equipping keeps MinLevel too (also after a rebirth / Lv5+ free class change)
	EquipNeedLevel = "You can use this weapon from Lv %d.", EquipNeedLevelEn = "You can use this weapon from Lv %d.",
	WeaponAutoSwap = "That weapon needs Lv %d → switched to %s.",
	WeaponAutoSwapEn = "That weapon needs Lv %d → switched to %s.",
	-- A23-34: bare hands (weapon tier 0)
	BareHands = "Bare hands", BareHandsEn = "Bare hands",
	-- A23-74: the first weapon comes right after the Guide's first quest is accepted (the Forge step)
	WeaponFromQuest = "The Blacksmith gives you your first weapon for free. Take the Guide's first quest!",
	WeaponFromQuestEn = "The Blacksmith gives you your first weapon for free. Take the Guide's first quest!",
	WeaponUsableNow = "You can now use %s! Equip it at the Forge or from your Bag.",
	WeaponUsableNowEn = "You can now use %s! Equip it at the Forge or from your Bag.",
	NeedFaction = "Pick a side first.",
	-- ShopService (blacksmith / potion merchant)
	WeaponShopFar = "Get close to the Forge anvil to buy weapons.",
	WeaponNotSold = "The Forge doesn't sell this weapon.",
	WeaponSellFar = "Get close to the Forge anvil to sell weapons.",
	WeaponSold = "Sold %s! Gold +%s", -- (weaponName, gold)
	BlacksmithPromptAction = "See weapons",
	BlacksmithPromptObject = "Forge",
	PotionShopFar = "Get close to the Potion Seller to buy.",
	-- ⑪ (lines_pack §1-3): the shop windows' greeting line (game dev 1: the top of WeaponShop / PotionShop); calm, no
	-- "hurry / sale" words next to a buy button
	ForgeGreeting = "Otto: Clang, clang… done. Cocoa time.",
	PotionGreeting = "Fizzby: Glug, glug, feel better!",
	PotionStockFull = "You can hold up to %d of each potion.", -- (PotionInventoryCap)
	PotionBought = "Bought %s potion ×%d!", -- (kind, amount)
	-- PvP
	Plundered = "%s stole %s gold from you!\nIf a knight catches the thief within 45 s, you get 120%% back.",
	PlunderGain = "Put %s gold in your Grudge Sack!\nKeep it: survive 45 s in a PvP zone. (Wanted stars: %d)",
	PlunderTooSoon = "You just robbed this player. You can't rob them again for 3 minutes.",
	HonorGain = "Honor +%d",
	AutoSleepy = "The shard is sleepy… Take a step? (Auto Battle rests in 30 s)", -- P2
	AutoRestOn = "You seem away, so Auto Battle is resting. Move and it starts again.",
	AutoRestOff = "Welcome back! Auto Battle is on again.",
	AutoChoiceWait = "A choice card is waiting. Pick one and Auto Battle starts again.",
	GraduateStart = "Sprout graduate! You can fight other sides in 60 s", -- A23-18
	GraduateEnd = "Now you can fight the other sides!",
	BoldStrong = "You beat a stronger foe! Honor, Infamy and war points ×2",
	BoldWeak = "A weaker foe: Honor, Infamy and war points are halved.",
	BountyGain = "Got a %s gold bounty! Honor +%d",
	BountyAnnounce = "[Knights of Light] %s got a %s gold bounty!", -- BB37: AnnounceService.PublicName(p, true)
	-- BB37 (검수): a hidden knight is already "A member of the Knights of Light", so no "[Knights of Light]" prefix
	BountyAnnounceHidden = "%s got a %s gold bounty!",
	BountyAnnounceHiddenEn = "%s got a %s gold bounty!",
	BullyBountyGain = "Got a %s gold bully bounty!",
	MostWanted = "%s is now the Most Wanted! Bounty: %s gold", -- BB37: PublicName(p, true)
	BullyKO = "Bully KO! No reward, size and ATK -15%% (bully level %d)",
	BullyVictim = "A bully knocked you out. You lost nothing!",
	BullyDecay = "Your bully level went down (level %d)",
	BullyNoAuto = "No Auto Battle during a bully penalty. It comes back when your bully levels are gone.", -- A23-22
	BullyAutoOff = "Unfair PvP penalty: Auto Battle is off. XP and drops are halved too.", -- A23-22 (auto was ON)
	BullyPenaltyEnd = "Your bully penalty is over! Auto Battle, XP and drops are back.", -- A23-22
	BullyPenaltyEndEn = "Your bully penalty is over! Auto Battle, XP and drops are back.",
	BullyPenaltyEndNoAuto = "Your bully penalty is over! XP and drops are back to normal.", -- auto combat not unlocked yet
	BullyPenaltyEndNoAutoEn = "Your bully penalty is over! XP and drops are back to normal.",
	Revenge = "Get revenge on %s! ATK +25%% for 90 s",
	RevengeDone = "Revenge done!",
	-- grudge sack
	SackPaid = "You kept the Grudge Sack! Got %s gold",
	SackLost = "You lost the Grudge Sack!",
	GrudgeRefund = "%s got your Grudge Sack back! %s gold went to your vault!",
	GrudgeReturned = "The thief went down, so your stolen %s gold came back to your vault.",
	GrudgeMail = "Grudge mail! Your stolen %s gold came back to your vault.", -- P3
	DailyAllDone = "All done for today! You can rest now without missing out. Want more? Enjoy story quests or hunting.", -- P8
	GhostHoldOk = "Your ghost grabbed the thief! Their hold time +%d s (max +%d s)", -- A23-18
	GhostHoldMax = "This sack can't be held any longer (max +%d s).",
	GhostHeld = "A grudge ghost is holding you! You must survive longer.",
	GhostButton = "Ghost grab ({GhostHold})", -- BB1 key token: the key part shows only on keyboards
	GhostWait = "Grab again in %d s",
	AvengerBonus = "Avenger bonus +%s gold!",
	GrudgeAvengedAll = "%s took the Grudge Sack back from %s!", -- BB37: PublicName(killer, true), PublicName(thief, true)
	-- travel / blocks
	TravelBlockedStars = "With 3 or more Wanted stars, you have to run away on foot!",
	TravelBlockedCombat = "You can't do that in combat.",
	TravelBlockedSack = "You can't teleport while carrying a Grudge Sack!",
	TravelBlockedKaiju = "A Kaiju can't teleport!",
	Traveling = "Traveling...",
	TravelCancelled = "Travel canceled.",
	BlockedSack = "You can't do that while carrying a Grudge Sack.",
	BlockedKaiju = "You can't do that during a Kaiju event.",
	BlockedStars = "You need zero Wanted stars to do that.",
	BlockedBully = "You can join the Artisan Guild after all your bully levels are gone.", -- CR-L9: altar / rebirth to Neutral with bully stacks
	WaitRespawn = "You can do that after you respawn.", -- CR-L30: travel / class / rebirth / altar while dead
	-- faction / class / tickets
	UnderdogSignOn = "Bonus for joining the smaller side: +%d gold!",
	SwitchDoneFree = "You joined the %s! (Price of switching: %s back to 0)",
	SwitchDoneTicket = "You joined the %s! (Ticket used, points kept)",
	SwitchCooldown = "You can switch sides again in %s.",
	NoTicket = "You have no change ticket. Get one at Menu > Ticket Shop.",
	TicketSaving = "Saving your ticket purchase. Please tap again in a moment.", -- CR-L25: UseTicket returned "Pending"
	ClassChosen = "Your class is now %s!",
	ClassChangedFree = "You changed your class to %s! You start again from Lv 1.", -- free change from Lv ClassChange.FreeKeepLevelBelow on
	ClassChangedFreeKeep = "You changed your class to %s! (Level kept: under Lv%d)", -- A23-14 (className, FreeKeepLevelBelow)
	ClassFreeKeepLevelF = "Level kept under Lv%d", -- A23-14 client preview (FreeKeepLevelBelow)
	ClassChangeRuleF = "Change class later in Menu. Free: level kept below Lv%d. Ticket: level always kept.", -- A23-14 ClassPicker footer (FreeKeepLevelBelow)
	ClassChangedTicket = "You changed your class to %s! (Ticket used, level kept)",
	ClassSame = "You already have that class.",
	ClassNeedSafe = "You can only change class in a safe zone.",
	ClassTicketGot = "You got 1 Class Change Ticket!",
	FactionTicketGot = "You got 1 Side Change Ticket!",
	ProductNotReady = "This item isn't ready yet.",
	-- rebirth
	RebirthNeed = "You need Lv %d to be reborn.",
	RebirthDone = "Rebirth done! Only your level starts over; gold, weapons and items stay. Gold and XP +%d%% forever", -- A23-14
	RebirthAnnounce = "%s was reborn! (Rebirth #%d)", -- BB37: PublicName(p, true)
	-- quests
	QuestDone = "Extra quest done! +%s gold",
	DailyReady = "Daily quest done! Press [Claim].",
	DailyClaimed = "Daily reward! +%s gold +%s XP",
	DailyChest = "3 daily quests done! Bonus chest +%s gold +%s XP",
	DailyChestTicket = "A Class Change Ticket came out of the bonus chest!",
	DailyAutoPaid = "Yesterday's unclaimed daily rewards went to your vault. (+%s gold)",
	VacationClaimed = "Vacation bonus! +%s gold +%s XP",
	-- war
	WarChest = "War chest! +%s gold",
	-- goose
	GooseReward = "Golden Goose reward! +%s gold +%s XP",
	GooseCheer = "Cheer Star +1 (%d/5): at 5, your next goose reward is rare!",
	RareToast = "Rare reward! ×5",
	RareAnnounce = "%s got a rare Golden Goose reward!", -- BB37: PublicName(p, true)
	-- kaiju
	KaijuQueued = "Another Kaiju is out. You'll transform when it's over!",
	KaijuReward = "Kaiju hunt reward +%s gold!",
	KaijuSurviveReward = "You survived! Pouch gold ×1.5 = %s gold to your vault!",
	-- addendum A3 (review fixes)
	AutoUnderAttack = "You're under attack! Hit back with the Attack button", -- M3: auto ON + took PvP damage (once per 60 s)
	EnemyTown = "You can't enter the other side's town!", -- L1: bounced to Crossroads (also Neutral in either town)
	-- addendum A7-3 (next goal, client)
	Unlocked = "Unlocked! %s", -- (unlockText)
	KillsToAfford = "%s: %d more!", -- (monsterName, kills)
	CanAfford = "You can buy %s at the Crossroads Forge!", -- (weaponName)
	Recommended = "Best", -- Travel panel badge
	-- addendum A7-4 (pick / change screens, client)
	FirstTimeRecommend = "Best for beginners", -- Warrior class card
	ChangeFree = "Change for free",
	ChangeTicket = "Change with a ticket (you have %d)", -- (tickets)
	LossScore = "%s %s → 0", -- ("Honor" | "Infamy", Util.FormatNumber(score)) e.g. "Honor 340 → 0"
	LossLevel = "Lv %d → Lv 1", -- (current level)
	KeepAll = "Keep everything",
}

----------------------------------------------------------------- A15 hit feel (server: MonsterService / CombatService)
-- Monster attacks are telegraphed: model attribute "WindupAt" (server time) -> MonsterWindup s later "AttackSeq" +1 and
-- the damage (cancelled if the target got farther than AttackRange + WindupLeeway or became invalid). A damaged
-- monster that survives gets "HurtBig" then "HurtSeq" +1 (once per MonsterHurtGap s); a damaged player sends
-- Fx "Pain" { UserId, Pos, Big } to all clients (once per PainGap s per victim). Big = crit or >= BigHitFraction of
-- max HP. Swing / release hits shove monsters ShoveSwing / ShoveCrit / ShoveRelease studs (<= ShoveMax, / body scale)
-- over ShoveTime s, at most once per ShoveGap s per monster, starting ShoveDelay[attack][class] s after the damage
-- (when clients show the hit: contact frame / projectile flight, minus ~0.07 s of physics replication lag).
Config.HitReact = {
	MonsterWindup = 0.28, WindupLeeway = 2, MonsterHurtGap = 0.15, PainGap = 0.4, BigHitFraction = 0.5,
	ShoveSwing = 1.2, ShoveCrit = 1.6, ShoveRelease = 2, ShoveMax = 2, ShoveTime = 0.12, ShoveGap = 0.5,
	ShoveDelay = {
		Swing = { Warrior = 0.06, Archer = 0.17, Mage = 0.25 },
		Release = { Warrior = 0.17, Mage = 0.28, Archer = 0.33 },
	},
}

----------------------------------------------------------------- 게임성 개발 2 (server-only session) block
-- New top-level tables of the server session live here, in one block at the end of the file (file-owner rule
-- docs/design/dev2_session_handoff_2026-10-06.md).

-- BB12 Tab player list (A23-21: power, level, rebirths, fame; gold hidden so the list is no plunder picker).
-- Column ids (PlayerService COLUMN): Power = the CombatPower attribute (BB4, same number as the HUD), Level, Rebirths,
-- Fame = Halo Honor / Horns Infamy / Neutral this week's 장인 명성 (WeekArtisan, A23-24) / None 0, Gold = bank + carried.
-- Creation order = column order; Roblox sorts the list by the first column. Changing the list is this one line.
Config.Leaderstats = {
	Columns = { "Power", "Level", "Rebirths", "Fame" },
	Names = { Power = "Power", Level = "Level", Rebirths = "Rebirths", Fame = "Fame", Gold = "Gold" },
}

-- BB10 / A23-22 / A23-23 / A23-24 weekly rankings (RankingService). Plan + 검수 decisions D1-D6:
-- docs/design/ranking_service_plan_2026-10-06.md. Boards are weekly (Monday 00:00 KST): Honor (Halo), Infamy (Horns),
-- Artisan (Neutral, 장인 명성) and PvP (every faction, the "unfair KO" board). Honor / Infamy count ONLY fair PvP points
-- (D1: one-time story / goose points stay in the stats, never on a board). The week's top 3 of Honor / Infamy /
-- Artisan get a stat-free title + XP and drop rows +10% for the next week (only while in that faction); PvP top 3 with
-- at least OutlawMinScore become outlaws for the next week (bully penalty, red nametag tag, bounty like a bully).
-- Week index: flips at Monday 00:00 KST (2026-10-05 00:00 KST = week 2962).
function Config.WeekIndex(unixTime)
	return math.floor((unixTime + Config.Daily.TimezoneOffset + 3 * 86400) / 604800)
end

-- os.time of the Monday 00:00 KST that starts `week`
function Config.WeekStart(week)
	return week * 604800 - 3 * 86400 - Config.Daily.TimezoneOffset
end

Config.Ranking = {
	Season = "PRE", -- LAUNCH-OPS: "B1" on beta day (and "PRE" stays in SeasonHistory). Studio / memory mode = "STUDIO"
	SeasonHistory = { "PRE" },
	Order = { "Honor", "Infamy", "Artisan", "PvP" },
	Boards = {
		Honor = { Faction = "Halo", Stat = "Honor", Reward = true },
		Infamy = { Faction = "Horns", Stat = "Infamy", Reward = true },
		Artisan = { Faction = "Neutral", Reward = true },
		PvP = { Outlaw = true },
	},
	WeekCap = { Honor = 150, Infamy = 150, Artisan = 60 }, -- provisional, tune from beta logs (PvP: no cap)
	TopN = 50,
	RefreshSeconds = 180, -- each board's global read; boards are staggered by ReadStagger
	ReadStagger = 45,
	WriteEverySeconds = 120, -- a dirty player's rows are written at most this often (faction change / leave / hide: at once)
	LoopSeconds = 10,
	MinBudget = 5, -- SetIncrementSortedAsync budget kept free for others
	MinReadBudget = 2, -- GetSortedAsync budget
	-- global boards: accounts younger than this / with less play are shown only on the server board
	MinAccountDays = 3,
	MinPlaySeconds = 1800,
	-- fair PvP points (PvPCreditOK): victim acted (own input / walking) within this, account age, playtime, per pair
	VictimActiveSeconds = 60,
	PvPMinVictimAccountDays = 7,
	PvPMinVictimPlaytime = 10800,
	MaxCreditPerVictimPerWeek = 3,
	MaxYieldPerVictimPerDay = 5,
	MaxVictimKeys = 100,
	DefenseWindowSeconds = 10, -- D2: the victim struck first and the KO landed within this after that first hit = self-defense
	FriendWaitSeconds = 1, -- the death pipeline waits at most this (< respawn time) for the IsFriendsWith call the first hit started
	LeaveWaitSeconds = 5, -- a leave write waits at most this for the loop's write of the same player to finish
	LeaveWriteTries = 3, -- the last write of a leaving player is tried this often (1 s apart) before it is given up
	-- A23-24 장인 명성: Enh scrolls dropped by my own kills while in the guild and active within HandActiveSeconds
	HandActiveSeconds = 60,
	HandScrollIds = { "Enh70", "Enh30", "Enh10" },
	RewardTop = 3,
	RewardMult = 1.10, -- XP and drop rows (never the jackpot)
	OutlawMinScore = 3, -- D5: fewer unfair KOs than this never make an outlaw, whatever the rank
	SettleDelaySeconds = 600, -- D4: settle 10 min after Monday 00:00 KST (last week's rows are written by then)
	SettleRetrySeconds = 60,
	-- D4: after 2 h of failed board reads that week is skipped (no reward, no outlaw) and logged; the skip is stored in the
	-- settle document first-writer-wins, so every server agrees (a document another server stored first still wins)
	SettleGiveUpSeconds = 7200,
	ExcludeUserIds = {},
	NameCacheSeconds = 3600,
	StudioNames = "Player%d",
	StorePrefix = "HH_Rank_", -- ordered store HH_Rank_<season>_<board>_W<week>, key U_<userId>
	SettleStorePrefix = "HH_RankSettle_", -- DataStore HH_RankSettle_<season>, key W<week> (D4: the season is in the name)
	FactionCode = { None = 0, Halo = 1, Horns = 2, Neutral = 3 },
	Text = {
		BoardNames = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan Fame", PvP = "Unfair PvP" },
		BoardNamesEn = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan Fame", PvP = "Unfair PvP" },
		-- the timed titles: "This week's Honor #1" / "This week's Infamy #1" / "This week's Artisan #1" (A23-22 / A23-24)
		TitleNames = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan" },
		TitleNamesEn = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan" },
		Empty = "No records yet", EmptyEn = "No records yet",
		Unknown = "Player", UnknownEn = "Player",
		Test = "Test", TestEn = "Test",
		PvPTabNote = "Rises when you KO weaker, idle or new players. Top 3 (3+ points) turn outlaw.",
		PvPTabNoteEn = "Rises when you KO weaker, idle or new players. Top 3 (3+ points) turn outlaw.",
		RewardTabNote = "Top 3: XP and drops +10% next week", RewardTabNoteEn = "Top 3: XP and drops +10% next week",
		Ineligible = "New accounts join the global ranking after 3 days and 30 minutes of play",
		IneligibleEn = "New accounts join the global ranking after 3 days and 30 minutes of play",
		Private = "Private servers do not earn ranking points", PrivateEn = "Private servers do not earn ranking points",
		OutlawTag = "Outlaw", OutlawTagEn = "Outlaw",
		OutlawChip = "Outlaw: no Auto Battle · half XP and drops (until Monday)",
		OutlawChipEn = "Outlaw: no Auto Battle · half XP and drops (until Monday)",
		RewardChip = "This week's %s #%d: XP and drops +10%% (until Monday)", -- (board name, rank)
		RewardChipEn = "This week's %s #%d: XP and drops +10%% (until Monday)",
		OutlawStart = "Last week's Unfair PvP #%d: you are an outlaw this week!\nNo Auto Battle, half XP and drops, double bounty (until Monday).",
		OutlawStartEn = "Last week's Unfair PvP #%d: you are an outlaw this week!\nNo Auto Battle, half XP and drops, double bounty (until Monday).",
		OutlawEnd = "Your outlaw week is over! Auto Battle is back.",
		OutlawEndEn = "Your outlaw week is over! Auto Battle is back.",
		OutlawEndNoAuto = "Your outlaw week is over! XP and drops are back to normal.", -- auto combat not unlocked yet
		OutlawEndNoAutoEn = "Your outlaw week is over! XP and drops are back to normal.",
		-- (still a bully at the end of the outlaw week: no line here; CombatService says BullyPenaltyEnd when the stacks go)
		OutlawNoAuto = "Outlaws can't use Auto Battle (until Monday).",
		OutlawNoAutoEn = "Outlaws can't use Auto Battle (until Monday).",
		OutlawAutoOff = "Outlaw: Auto Battle is off and XP and drops are halved (until Monday).",
		OutlawAutoOffEn = "Outlaw: Auto Battle is off and XP and drops are halved (until Monday).",
		RewardStart = "Last week's %s #%d! XP and drops +10%% and a title this week (until Monday).", -- (board name, rank)
		RewardStartEn = "Last week's %s #%d! XP and drops +10%% and a title this week (until Monday).",
		-- a top-3 player who switched faction since: the title is given, the bonus waits for that faction
		RewardStartOff = "Last week's %s #%d! You got the title.\nXP and drops +10%% only while in the %s (until Monday).", -- (board, rank, faction)
		RewardStartOffEn = "Last week's %s #%d! You got the title.\nXP and drops +10%% only while in the %s (until Monday).",
		ArtisanGain = "+%d Artisan Fame", ArtisanGainEn = "+%d Artisan Fame",
		-- BB11 town board (PvPService.updateBoard; 검수 2026-10-06): this server's weekly boards + one wanted line.
		-- RichText: the red outlaw tag is fixed text, names are escaped. Row = (rank, name, value).
		Board = {
			Header = "This server · this week",
			Titles = { Honor = "Knights' Honor", Infamy = "Horns' Infamy", Artisan = "Artisan Fame", PvP = "This week's PvP" },
			Wanted = "Wanted",
			Row = "%d. %s %s", Sep = " · ", Empty = "(nobody yet)", Bully = "Bully", Gold = "G",
		},
		BoardEn = {
			Header = "This server · this week",
			Titles = { Honor = "Knights' Honor", Infamy = "Horns' Infamy", Artisan = "Artisan Fame", PvP = "This week's PvP" },
			Wanted = "Wanted",
			Row = "%d. %s %s", Sep = " · ", Empty = "(nobody yet)", Bully = "Bully", Gold = "G",
		},
	},
}
Config.RateLimits.RequestRankings = 1

-- A23-22 / A23-24 weekly titles (stat-free, Timed: granted at the settle, removed when the week ends; never permanent)
do
	local R = Config.Ranking
	for _, board in { "Honor", "Infamy", "Artisan" } do
		for rank = 1, R.RewardTop do
			local id = "Rank" .. board .. rank
			Config.TitleDefs[id] = {
				Name = string.format("This week's %s #%d", R.Text.TitleNames[board], rank),
				NameEn = string.format("This week's %s #%d", R.Text.TitleNamesEn[board], rank),
				Color = Config.Factions[R.Boards[board].Faction].Color,
				Timed = true,
			}
			table.insert(Config.TitleOrder, id)
		end
	end
end

-- BB10 save fields (added here, not in Config.Data above: one block per session). Version stays 3 (additive).
--   Rank: this week's board points + the fairness counters (week fields reset when WeekId is not the current week);
--     Victims ['U'..userId] = fair points I got from that player this week (1..99, at most MaxVictimKeys keys),
--     HandScroll [Enh70|Enh30|Enh10] = 장인 tags still unused this week, YieldDay / YieldN = fair points I gave today.
--     Drop [board] = week id: a faction change zeroed that board and its row of that week is still to be removed (kept in
--     the save until the RemoveAsync lands, on any server; this week's and last week's entries survive the Monday flip). Season = the ranking season these points belong to: points,
--     rewards and outlaw weeks of another season (a Studio test on the live place's saves) never carry over.
--   RankReward: the A23-22/24 top-3 reward that is on during week WeekId. Outlaw: the A23-23 outlaw week.
--   DebugTainted: a DebugCommand touched this save (never written to PRE / B1 boards).
Config.Data.Defaults.Rank = { WeekId = 0, Season = "", Honor = 0, Infamy = 0, Artisan = 0, PvP = 0, Victims = {},
	HandScroll = {}, Drop = {}, YieldDay = 0, YieldN = 0, HideSynced = false }
Config.Data.Defaults.RankReward = { WeekId = 0, Season = "", Board = "", Rank = 0 }
Config.Data.Defaults.Outlaw = { WeekId = 0, Season = "" }
Config.Data.Defaults.DebugTainted = false

-- DataService.fillDefaults: repair the BB10 fields of a loaded save in place (now = os.time). Week fields of an older
-- week start over (their last values were written to that week's boards when the player left); YieldN resets daily.
function Config.SanitizeRank(d, now)
	local R = Config.Ranking
	local function int(v, lo, hi)
		v = tonumber(v)
		if v == nil or v ~= v or v == math.huge or v == -math.huge then return lo end
		return math.clamp(math.floor(v), lo, hi)
	end
	local function season(v) -- a short season id ("PRE", "B1", "STUDIO"), else ""
		return (type(v) == "string" and #v <= 16 and string.match(v, "^%w+$")) and v or ""
	end
	local rank = type(d.Rank) == "table" and d.Rank or {}
	local week = Config.WeekIndex(now)
	local out = { WeekId = week, Season = season(rank.Season), Honor = 0, Infamy = 0, Artisan = 0, PvP = 0, Victims = {},
		HandScroll = {}, Drop = {}, YieldDay = Config.DayIndex(now), YieldN = 0, HideSynced = rank.HideSynced == true }
	if int(rank.WeekId, 0, 1e9) == week then
		for _, board in R.Order do
			out[board] = int(rank[board], 0, R.WeekCap[board] or 1e9)
		end
		local n = 0
		if type(rank.Victims) == "table" then
			for k, v in rank.Victims do
				if n >= R.MaxVictimKeys then break end
				if type(k) == "string" and string.match(k, "^U%-?%d+$") then
					local c = int(v, 0, 99)
					if c >= 1 then
						out.Victims[k] = c
						n += 1
					end
				end
			end
		end
		if type(rank.HandScroll) == "table" then
			for _, id in R.HandScrollIds do
				local c = int(rank.HandScroll[id], 0, Config.Loot.ItemCap)
				if c > 0 then out.HandScroll[id] = c end
			end
		end
	end
	if type(rank.Drop) == "table" then -- removals of this week and last week (the settle reads last week's rows)
		for _, board in R.Order do
			local wk = int(rank.Drop[board], 0, 1e9)
			if R.Boards[board].Faction and (wk == week or wk == week - 1) then out.Drop[board] = wk end
		end
	end
	if int(rank.YieldDay, 0, 1e9) == out.YieldDay then out.YieldN = int(rank.YieldN, 0, 99) end
	d.Rank = out
	local rr = type(d.RankReward) == "table" and d.RankReward or {}
	local board = type(rr.Board) == "string" and R.Boards[rr.Board] and R.Boards[rr.Board].Reward and rr.Board or ""
	d.RankReward = { WeekId = board ~= "" and int(rr.WeekId, 0, 1e9) or 0, Season = board ~= "" and season(rr.Season) or "",
		Board = board, Rank = board ~= "" and int(rr.Rank, 0, R.RewardTop) or 0 }
	local ol = type(d.Outlaw) == "table" and d.Outlaw or {}
	d.Outlaw = { WeekId = int(ol.WeekId, 0, 1e9), Season = season(ol.Season) }
	if type(d.DebugTainted) ~= "boolean" then d.DebugTainted = false end
end

-- BB14 KO screen: CombatService sends the owner-only Net.Fx(victim, "KO", { By, Name, Faction, Lost, Sack, RespawnIn })
-- after the death pipeline. By = "Player" (a PvP KO; Name = PublicName, Faction = the killer's) | "Kaiju" (a kaiju stomp
-- outside PvP zones; Name = the kaiju's PublicName) | "Monster" (Name = Config.MonsterTypes[kind].Name) | "Fall" | "Other"
-- (a reset, the void without a fall, anything else). Lost = carried gold actually lost by this KO, Sack = a grudge sack
-- was carried (and is gone). Texts / tips for the client DeathScreen (BB14): KO/EN, the tip picked by the situation.
Config.Death = {
	SourceSeconds = 3, -- a monster / kaiju hit this recent is the cause
	FallBelowFloor = 30, -- the body this far below its zone's floor (or in free fall) = a fall
	Text = {
		Player = "Knocked out by %s", PlayerEn = "Knocked out by %s",
		Kaiju = "Knocked out by the Kaiju %s", KaijuEn = "Knocked out by the Kaiju %s",
		Monster = "Knocked out by %s", MonsterEn = "Knocked out by %s",
		Fall = "You fell", FallEn = "You fell",
		Other = "You were knocked out", OtherEn = "You were knocked out",
		LostNone = "Nothing lost", LostNoneEn = "Nothing lost",
		Lost = "Lost %s pouch gold", LostEn = "Lost %s pouch gold",
		Sack = "You lost the Grudge Sack", SackEn = "You lost the Grudge Sack",
		Respawn = "Back in %d s", RespawnEn = "Back in %d s",
	},
	-- one tip per situation (%s = the potion key name, or 'the potion button' on touch)
	Tips = {
		Monster = "Low HP? Drink a potion with %s!", MonsterEn = "Low HP? Drink a potion with %s!",
		Plundered = "If a knight catches the thief within 45 s, you get 120% back", PlunderedEn = "If a knight catches the thief within 45 s, you get 120% back",
		Player = "Fair fights build Honor and Infamy", PlayerEn = "Fair fights build Honor and Infamy",
		Fall = "A fall sends you back to town", FallEn = "A fall sends you back to town",
		Other = "Stuck? Menu → Travel", OtherEn = "Stuck? Menu → Travel",
		PotionTouch = "the potion button", PotionTouchEn = "the potion button",
	},
}

-- A23-32 bag sort '얻은 순' (the most recent first): data.ItemSeq[key] / data.WeaponSeq[tier] = a number from the ONE
-- counter data.ItemSeqNext (bigger = gained more recently; 0 / missing = before this existed, an old save). Keys: the
-- Config.Loot item ids and the potion keys of Config.ItemSeqPotions. Numbers only, unknown keys dropped: a small save.
-- LootService notes every gain (items in addItem; potions and weapons from their mirrored attributes, whatever service
-- gave them) and sends ItemSeq / WeaponSeq in the owner's "Inventory" payload.
Config.ItemSeqPotions = { PotionHP = "HPPotionCount", PotionMP = "MPPotionCount" } -- key -> the save field it follows
Config.Data.Defaults.ItemSeq = {}
Config.Data.Defaults.WeaponSeq = {}
Config.Data.Defaults.ItemSeqNext = 0

-- DataService.fillDefaults: repair the fields of a loaded save in place
function Config.SanitizeItemSeq(d)
	local function int(v)
		v = tonumber(v)
		if v == nil or v ~= v or v == math.huge or v == -math.huge then return 0 end
		return math.max(0, math.floor(v))
	end
	local top = 0
	local items = {}
	if type(d.ItemSeq) == "table" then
		for k, v in d.ItemSeq do
			if type(k) == "string" and (Config.Loot.Items[k] ~= nil or Config.ItemSeqPotions[k] ~= nil) then
				local n = int(v)
				if n > 0 then
					items[k] = n
					top = math.max(top, n)
				end
			end
		end
	end
	local weapons = {}
	local old = type(d.WeaponSeq) == "table" and d.WeaponSeq or {}
	for tier = 1, Config.MaxWeaponTier do
		weapons[tier] = int(old[tier])
		top = math.max(top, weapons[tier])
	end
	d.ItemSeq, d.WeaponSeq = items, weapons
	d.ItemSeqNext = math.max(int(d.ItemSeqNext), top) -- never hands out a number already used
end

-- one gain: `key` (an item id / potion key) or weapon `tier` becomes the most recent; returns its number
function Config.NoteGained(d, key, tier)
	if type(d.ItemSeq) ~= "table" or type(d.WeaponSeq) ~= "table" then Config.SanitizeItemSeq(d) end
	local n = math.max(0, math.floor(tonumber(d.ItemSeqNext) or 0)) + 1
	d.ItemSeqNext = n
	if tier ~= nil then
		d.WeaponSeq[tier] = n
	else
		d.ItemSeq[key] = n
	end
	return n
end

----------------------------------------------------------------- A23-39 pet tamer (게임성 개발 2, 2026-10-06)
-- The artisan guild's third class (internal class id Archer) is the pet tamer: the baby slime pet fights for it with
-- the Archer numbers (range / interval / damage / Q table); only the names and the look change. Server: CombatService
-- sends Style SwingStyle / SkillStyle in the Swing / Release Fx, PetService grants the pet and the one-time notice.
Config.Tamer = {
	Faction = "Neutral", Class = "Archer",
	Pet = "BabySlime", -- the species granted (Config.Data.Defaults.Pets; PET-2 adds levels / XP later)
	SwingStyle = "PetHeadbutt", -- basic attack Fx: the pet runs to the target, headbutts, comes back
	SkillStyle = "PetDash", -- skill Q Fx: the pet dashes into the target area
	Text = {
		PetName = "Baby Slime", PetNameEn = "Baby Slime",
		PetGot = "A Baby Slime became your pet! Now your pet fights for you.",
		PetGotEn = "A Baby Slime became your pet! Now your pet fights for you.",
		-- once, for a save that was the artisan hunter before A23-39 (with one free class change)
		Became = "The hunter is now the Pet Tamer!\nWant another class? Use the free Class Change Ticket you got.",
		BecameEn = "The hunter is now the Pet Tamer!\nWant another class? Use the free Class Change Ticket you got.",
		-- below Config.ClassChange.FreeKeepLevelBelow a free change keeps the level anyway (no ticket button there)
		BecameFree = "The hunter is now the Pet Tamer! You can change your class for free.",
		BecameFreeEn = "The hunter is now the Pet Tamer! You can change your class for free.",
	},
	-- the class card / picker lines for the tamer (Config.ClassCard)
	Card = {
		Desc = "Your Baby Slime pet fights for you! It headbutts enemies from afar.",
		DescEn = "Your Baby Slime pet fights for you! It headbutts enemies from afar.",
		PickLine = "Your pet bonks foes one by one",
		PickLineEn = "Your pet bonks foes one by one",
		Stats = { "HP ×1.0", "ATK ×0.55 (2x fast)", "Pet hits 2 at 30 studs · Move +10%" },
		StatsEn = { "HP ×1.0", "ATK ×0.55 (2x fast)", "Pet hits 2 at 30 studs · Move +10%" },
	},
}

-- true for the pet tamer: the artisan guild (Neutral) Archer
function Config.IsTamer(classId, factionId)
	local T = Config.Tamer
	return T ~= nil and classId == T.Class and factionId == T.Faction
end

-- the class card lines a picker / character window shows: { Desc, DescEn, PickLine, PickLineEn, Stats, StatsEn } (the
-- class row, or the tamer's card for the artisan Archer)
function Config.ClassCard(classId, factionId)
	if Config.IsTamer(classId, factionId) then return Config.Tamer.Card end
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return { Desc = c.Desc, PickLine = c.PickLine, Stats = c.Stats }
end

----------------------------------------------------------------- PET-1 walk speed (게임성 개발 2, 2026-10-07)
-- The ONE player walk speed (design skills_weapons_pets_2026-10-05 §0-1, SPEC A23-15, A23-49): Config.Player.WalkSpeed x
-- the class WalkSpeedMult x (1 + the equipped pet's bonus), no skill buff (A23-49), at most Speed.Cap x the base. The pet
-- bonus is on everywhere, PvP too (A23-15); an Active kaiju gets none (the kaiju rule). PlayerService.ComputeWalkSpeed
-- feeds it and is the only source of a player's WalkSpeed. No zone / combat / grudge-sack speed rule exists, so those
-- states need no recompute; a later rule adds its input here and its trigger next to it.
Config.Speed = { Cap = 1.35 }
-- pets by species: Speed = { bonus at pet Lv1, bonus at MaxLv }, a straight line between (design §2: +7% -> +10%)
Config.Pets = {
	MaxLv = 10,
	Species = {
		BabySlime = { Speed = { 0.07, 0.10 } },
	},
}

-- the walk speed bonus of a pet (0 for none / an unknown species); levels clamp to 1..MaxLv
function Config.PetSpeedBonus(species, lv)
	local P = Config.Pets
	local def = type(species) == "string" and P.Species[species] or nil
	if type(def) ~= "table" or type(def.Speed) ~= "table" then return 0 end
	if type(lv) ~= "number" or lv ~= lv then lv = 1 end
	lv = math.clamp(math.floor(lv), 1, P.MaxLv)
	local a, b = def.Speed[1], def.Speed[2]
	return a + (b - a) * (lv - 1) / math.max(1, P.MaxLv - 1)
end

-- studs per second for a class with a pet (species, level; nil = none); kaiju = an Active kaiju (no pet bonus)
function Config.WalkSpeed(classId, petSpecies, petLv, kaiju)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	local base = Config.Player.WalkSpeed
	local pet = kaiju == true and 0 or Config.PetSpeedBonus(petSpecies, petLv)
	local raw = base * (c.WalkSpeedMult or 1) * (1 + pet)
	return math.min(raw, base * Config.Speed.Cap)
end

----------------------------------------------------------------- A23-77 attendance (게임성 개발 3, 2026-10-08)
-- AttendanceService; contract docs/design/attendance_server_2026-10-08.md. User 2026-10-08: "끊기면 0되면 안 돼" ->
-- days COLLECTED, never a streak. Additive save field (Version stays 3): Attendance = { Days = days collected (lifetime,
-- never back to 0), LastDay = Config.DayIndex of the last claim (0 = never), Slot = the board slot the next claim pays
-- (1..#Board) }. AttendanceService repairs it at PlayerReady (DataService only refills a missing / wrong-type table).
Config.Data.Defaults.Attendance = { Days = 0, LastDay = 0, Slot = 1 }
Config.Attendance = {
	Enabled = true,
	-- one claim a KST day (Config.DayIndex, 00:00 Korea time); a missed day is simply skipped: the next claim pays the next
	-- slot and nothing resets. After slot 7 (the weekly box) the board starts at slot 1 again.
	-- GoldMin / XPMin = Config.HuntValue minutes at the player's level (A23-77: about 3-5 hunting minutes a day, ~30 a
	-- week). Potion = "HP" | "MP" bottles (bottles that do not fit the bag are paid in gold at Config.Vitals.PotionPrices).
	-- Item = a Config.Loot.Items id. MaterialMin = the materials that many minutes of hunting the level zone's main monster
	-- drop on average (Config.Economy.KillsPerMinute x minutes x the drop chance; a slime zone: 14 Jelly for 4 minutes).
	Board = {
		{ Potion = "HP", N = 2 },
		{ GoldMin = 3 },
		{ Item = "Enh70", N = 1 },
		{ GoldMin = 3 },
		{ Potion = "HP", N = 3, MaterialMin = 4 },
		{ XPMin = 5 },
		{ GoldMin = 10, XPMin = 10, Item = "Enh30", N = 1, Box = true }, -- the weekly box
	},
	-- days collected -> a stat-free reward once: Title = a Config.TitleDefs id, Border = the nametag frame id (drawn by the
	-- client from the AttendDays attribute). The attendance-only halo / horn looks are Config.Looks entries with
	-- Unlock.Attendance = days (A23-75's look frame, MonetizationService.GrantLook; both factions' looks, never sold).
	Milestones = {
		{ Days = 7, Title = "Regular" },
		{ Days = 14 },
		{ Days = 28, Border = "Days28" },
		{ Days = 50, Title = "SuperRegular" },
		{ Days = 100, Title = "MegaRegular" },
	},
	CheckInterval = 30, -- seconds between the day checks of online players (AttendReady turns on at 00:00 KST)
	-- game text (English only, A23-48; 검수 owns the words)
	Text = {
		Claimed = "Day %d reward! %s", -- (board slot, the parts below joined with " · ")
		Gold = "+%s gold",
		XP = "+%s XP",
		Item = "+%s",
		ItemN = "+%s x%d",
		Days = "%d days collected!",
		NewTitle = "New title: %s!",
		NewLook = "New look: %s!",
		NewBorder = "New name frame!",
	},
}
Config.TitleDefs.Regular = { Name = "Regular", NameEn = "Regular", Color = Color3.fromRGB(130, 205, 255) }
Config.TitleDefs.SuperRegular = { Name = "Super Regular", NameEn = "Super Regular", Color = Color3.fromRGB(150, 230, 170) }
Config.TitleDefs.MegaRegular = { Name = "Mega Regular", NameEn = "Mega Regular", Color = Color3.fromRGB(255, 200, 90) }
for _, id in { "Regular", "SuperRegular", "MegaRegular" } do
	if not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end
end
Config.RateLimits.ClaimAttendance = 1

----------------------------------------------------------------- A23-79 beta metrics (게임성 개발 3, 2026-10-08)
-- TelemetryService; docs/design/retention_round_2026-10-08.md "베타에서 잴 것", contract
-- docs/design/beta_metrics_server_2026-10-08.md. Roblox limits: 10 funnels (the onboarding one is
-- Config.Analytics.Steps), 100 custom event names, 3 fields; events only from published servers (never Studio).
-- Funnels: steps in order, each logged once per funnel session. Once = one session per account; DailyVisit's session =
-- the KST day; PassShop's = one shop visit. Roblox completes the earlier steps of a later one, so a funnel holds only
-- steps that always come in order (review 2026-10-08): the attendance claim, the story's chapter ends and the first
-- ruins daily are custom events (Attendance, ChapterEnd, RuinsDaily), not steps.
Config.Analytics.Funnels = {
	LongRoad = { Once = true, Steps = { "Level15", "Level25", "Level30", "Level40", "Level50", "Rebirth1" } },
	DailyVisit = { Steps = { "Join", "Daily1", "Daily3", "SetChest", "StopCardSeen" } },
	Social = { Once = true, Steps = { "InviteSeen", "InvitePrompt", "InviteSent", "InviteeJoined", "PlayedTogether10m" } },
	KingDiary = { Once = true, Steps = { "Page1", "Page3", "Page6", "Page9" } },
	PassShop = { Steps = { "ShopOpen", "PassView", "PurchasePrompt", "Bought" } },
}
-- c->s "ClientMetric"(id, arg?): what only the client sees. The rule for the one argument: "None" (no argument),
-- "Count" (a whole number 1..50), "Source" (one of InviteSources), "Pass" (a Config.GamePasses / Config.Looks id or
-- "Look"), or a list of the allowed strings. Anything else is ignored.
Config.Analytics.ClientMetrics = {
	ShopOpen = "None", -- the Shop window opened (every open; a visit lasts until ShopVisitGap s after its start)
	InviteSeen = "Source", -- an [Invite a friend] button showed
	InvitePrompt = "Source", -- Roblox's invite window opened
	InviteSent = "Count", -- the invite window closed with this many friends picked (SocialService.GameInvitePromptClosed)
	PassView = "Pass", -- a pass card was looked at in the Shop (a visit starts here when none is open)
	PurchasePrompt = "Pass", -- Roblox's buy window opened for a pass
	OptIn = { "shown", "cannot" }, -- the notification prompt was shown / could not be (CanPromptOptInAsync false)
	WelcomeBackGo = "None", -- [Go] on the welcome-back card
}
Config.Analytics.InviteSources = { "Menu", "PlayerList", "GooseWin", "WarWin" }
Config.Analytics.PassIds = { "XP2", "Gold2", "VIP", "Look" } -- "Pass" args besides Config.GamePasses / Config.Looks ids
-- review 2026-10-08 (one client must not flood the whole game's analytics budget): ClientMetric calls LOGGED a minute per
-- player, and the ids logged once a session; every accepted call still fires TelemetryService.ClientMetric (no limit)
Config.Analytics.ClientMetricPerMinute = 10
Config.Analytics.ClientMetricOnce = { "OptIn", "WelcomeBackGo" }
Config.Analytics.ShopVisitGap = 30 -- s: a shop open within this of the visit's start keeps the visit
Config.Analytics.ShopVisitMax = 600 -- s: a visit older than this is over
Config.Analytics.KOLeave = 60 -- s after a KO a leave counts as KOLeave60 (and LeaveContext "KO")
Config.Analytics.PromptNearKO = 30 -- s after a KO / a failed scroll a purchase prompt is logged (must stay 0)
Config.Analytics.LeaveRecent = 120 -- s a pause card / the day's last daily still names the leave (LeaveContext)
Config.Analytics.IdleAfter = 120 -- s with no own action = an "Idle" leave
-- gold on the Roblox economy dashboard (LogEconomyEvent, currency "Gold"): the sums per source / sink every 5 minutes and
-- at the leave; item SKU = the ProgressionService tag, transaction type from these tables (else "Gameplay")
Config.Analytics.EconomySources = { Attendance = "TimedReward", Sale = "Shop", Refund = "Shop" }
Config.Analytics.EconomySinks = { Weapon = "Shop", Potion = "Shop", LookChange = "Shop" }
Config.RateLimits.ClientMetric = 0.5 -- per metric id

----------------------------------------------------------------- A23-79 coming back (게임성 개발 3, 2026-10-08)
-- ReturnService / InviteService / DiaryService; contract docs/design/return_server_2026-10-08.md. Additive save fields
-- (Version stays 3), each repaired by its service at PlayerReady:
--   Return = { Badges = { [Config.Badges key] = { Id = the badge id awarded, At } }, OptIn = "" | "shown" | "cannot", OptInAt }
--   Diary = { Pages = King Diary pages open (0..9), Done = the full book's title was given }
--   Invite = { By = the UserId whose invite brought this player first, At = os.time() } (empty when never invited)
Config.Data.Defaults.Return = { Badges = {}, OptIn = "", OptInAt = 0 }
Config.Data.Defaults.Diary = { Pages = 0, Done = false }
Config.Data.Defaults.Invite = {}
-- #1 the pause card + welcome back (no clock numbers, no automatic next dialogue, never a buy button near it)
Config.Return = {
	CardDelay = 1.5, -- s after the moment (the quest list has moved on to the next goal by then)
	MinGap = 120, -- s between two pause cards of one player
	CombatWaitSeconds = 3, -- a card that comes in a fight waits for the fight to end (this often, at most this many times)
	CombatWaitTries = 10,
	War = { MinSession = 900, MinGap = 1800 }, -- a crown-war end: only after 15 minutes of play, at most one in 30 minutes
	WelcomeAfter = 6 * 3600, -- "Welcome back!" when the last leave was at least this long ago (after the first mission)
	WelcomeDelay = 4, -- s after the join (the HUD is up by then)
	NextZone = "GoblinWoods", -- the next-goal row "Lv10 · Goblin Woods" travels there
	SeasonFallback = "SlimeMeadow", -- a seasonal field (no Travel destination): its entrance field
	-- quest guide spots that are not zones / landmarks ("Home" = the player's own town)
	GuideZones = { Blacksmith = "Crossroads", HaloBridge = "Crossroads", HornsBridge = "Crossroads", OwnTown = "Home",
		Goose = "Crossroads" },
	-- A23-86 F: the zone a next-goal ladder row (QuestService GoalKind) leads to; other kinds use the level's hunting zone
	GoalZones = { Rebirth = "Crossroads", RebirthReady = "Crossroads", Commission = "Crossroads", Commission4 = "Crossroads",
		Commission5 = "Crossroads", Commission6 = "Crossroads", Crystal = "Crossroads" },
	Text = {
		NextHunt = "Hunt and get stronger!", -- nothing pinned
		TomorrowDaily = "New dailies", -- the daily card's tomorrow line (the King Diary's page while one waits)
	},
}
-- #2 "My Way" (A23-79, psychology 2a): a name from the player's own good / evil story picks, no stats, no judging.
-- At least MinPicks picks; |good - evil| <= floor(picks x BalanceShare) = Balance Walker; else by faction and lean.
Config.MyWay = {
	MinPicks = 2,
	BalanceShare = 0.2,
	-- A23-86 (검수 2026-10-09): repeated cards (ChoiceCard picks data.Story.N[kind][side], the job board's N.Kind = good /
	-- N.Sneaky = devil) count one story pick for every RepeatPer of them, and all of them together never weigh more than
	-- the story picks do (so a grinder cannot out-vote the story; the story picks decide first, 2+ are still needed)
	RepeatPer = 5,
	Names = { TrueKnight = "True Knight", RebelAngel = "Rebel Angel", ProudRascal = "Proud Rascal",
		SoftDevil = "Soft-Hearted Devil", BalanceWalker = "Balance Walker" },
}
-- #2 the 8 Roblox badges (one badge for the angel and the devil path alike). Ids = the badge ids the user creates on
-- create.roblox.com at publishing (5 free a day: two days; launch_ops_checklist). 0 = not made yet: never asked, awarded
-- at a later join once the id is set. Stronger = a weapon above the first tier owned; FirstSkill = the first skill
-- learned (Lv5); Rank2 = faction rank 2 (Config.Titles.Thresholds); Halloween2026 = candy or a king beaten together in
-- the 2026 season.
Config.Badges = {
	Order = { "ChoseSide", "FirstSlime", "LostLunchbox", "Stronger", "FirstSkill", "ShardChoice", "Rank2", "Halloween2026" },
	Ids = { ChoseSide = 0, FirstSlime = 0, LostLunchbox = 0, Stronger = 0, FirstSkill = 0, ShardChoice = 0, Rank2 = 0,
		Halloween2026 = 0 },
	RetrySeconds = 300, -- a failed AwardBadge is tried again after this long
}
-- #5 the notification opt-in moment (13+ only: Roblox decides in CanPromptOptInAsync on the client). Once a shown prompt,
-- again after RetryCannot s when the client could not prompt; never in the first MinPlaySeconds of play or within Calm s
-- of a KO / a failed scroll / a purchase prompt. Store = the asked list (UserId -> { At }) for the launch-day send
-- (Open Cloud, 11/09 update; the key lives in Secrets, never in the code).
Config.Notify = {
	MinPlaySeconds = 600,
	Calm = 60,
	RetryCannot = 30 * 86400,
	Store = "HaloHorns_NotifyAsked_v1",
}
-- #3 invites (A23-68: no reward for inviting). TogetherMinutes = an invite pair on one server this long -> the
-- PlayedTogether metric. SeasonZone = where "Go to friend" goes for a friend in a seasonal field.
Config.Invite = {
	TogetherMinutes = 10,
	SeasonZone = "SlimeMeadow",
	Text = {
		NotHere = "Your friend is not on this server.",
		Away = "Your friend is exploring far away. Try again soon!",
		OtherTown = "Your friend is in the other side's town.",
		SproutPvP = "Your friend is in a PvP zone. Come at Lv %d!",
		SameZone = "You're already there!",
	},
}
-- #4 the King Diary (Config.Halloween.Banter.Days = its pages) and the candy jar (open after the season too)
Config.Diary = {
	Title = "PartyGuest2026", -- all 9 pages
	Text = {
		Page = "King Diary: page %d!",
		Tomorrow = "King Diary page %d",
		NewTitle = "New title: %s!",
		JarOwned = "You already have it!",
		JarNeed = "You need %d candy.",
	},
}
Config.CandyJar = {
	Trades = {
		{ Id = "PumpkinPal", Title = "PumpkinPal", Candy = 50 },
		{ Id = "CandyKeeper", Title = "CandyKeeper", Candy = 200 },
	},
}
Config.TitleDefs.PartyGuest2026 = { Name = "Party Guest 2026", NameEn = "Party Guest 2026", Color = Color3.fromRGB(255, 160, 70) }
Config.TitleDefs.PumpkinPal = { Name = "Pumpkin Pal", NameEn = "Pumpkin Pal", Color = Color3.fromRGB(255, 140, 60) }
Config.TitleDefs.CandyKeeper = { Name = "Candy Keeper", NameEn = "Candy Keeper", Color = Color3.fromRGB(240, 120, 200) }
for _, id in { "PartyGuest2026", "PumpkinPal", "CandyKeeper" } do
	if not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end
end
Config.RateLimits.GoToFriend = 3
Config.RateLimits.CandyTrade = 1

----------------------------------------------------------------- A23-81 quest window book (게임성 개발 3, 2026-10-08)
-- the "Quests" remote also carries Book = { Available, Done } (StoryQuestService.BookRows; the client's Q window tabs).
-- DoneMax = finished story quests listed (newest first); AvailableMax = subs listed that wait for a level / start.
Config.QuestBook = {
	DoneMax = 60, -- every main (19) + every sub (~35) of a finished save still fits (검수 2026-10-08)
	AvailableMax = 10,
	Text = { OpensAt = "%s · Opens at Lv %d" }, -- (quest Title, level)
}

----------------------------------------------------------------- A23-86 Deeds + shared choice card (게임성 개발 3, 2026-10-09)
-- Deeds.luau: ONE cap a KST day for every REPEATED Honor / Infamy change (user 2026-10-09, decision 1 = A): PerDay = 6
-- points, +Points on my own side / -Points on the other side (A23-58, never below 0). Gold paid for something is never
-- a deed. Additive save field (Version stays 3): Deeds = { Day = Config.DayIndex, N = points used today }.
Config.Data.Defaults.Deeds = { Day = 0, N = 0 }
Config.Deeds = {
	PerDay = 6,
	Points = 1, -- a deed's default size
	CheckInterval = 60, -- seconds between the day checks of online players (DeedsToday goes back to 0 at 00:00 KST)
	Text = { Full = "Your shard is full for today. Come back tomorrow!" },
}
-- ChoiceCard.luau (contract docs/design/choice_card_server_2026-10-09.md): a card only the player sees, Good and Evil of
-- the same size, a FIXED reward. Kinds[kind] = { Title, Seconds? (timed, not saved), Good / Evil = { Label, Done?,
-- Reward = { Item | Potion, N, Gold }, Points? (default Deeds.Points) } }. The kinds come with the content that opens
-- them (the lost items, the apprentice card, the clatter card, ...). Additive save field: Cards = { Serial, Pending }.
Config.Data.Defaults.Cards = { Serial = 0 }
Config.ChoiceCard = {
	Grace = 1, -- seconds after a timed card's Seconds in which a pick still counts (the network)
	Kinds = {},
	Text = {
		GoodDone = "Kind choice!",
		EvilDone = "Sneaky choice!",
		Score = "%s +%d", -- ("Honor" | "Infamy", points)
		Full = "Your shard is full for today. Come back tomorrow!", -- (the same line as Config.Deeds.Text.Full)
	},
}
Config.RateLimits.CardAction = 0.3
-- A23-86 D (content_beyond_10min D): the monster kill record from the first beta day (KillLog.luau). Additive save field
-- (Version stays 3): KillLog = { Total, M (by hand), A (auto combat), Golden, ByKind = { [monster kind] = n },
-- ByTier = { ["tier"] = { M, A } } }. The sticker book screen comes 11/04; nothing is paid for it here.
Config.Data.Defaults.KillLog = { Total = 0, M = 0, A = 0, Golden = 0, ByKind = {}, ByTier = {} }
-- A23-86 decision 2 = A (user 2026-10-09): Otto's commissions (CommissionService, content_beyond_10min H). The golden / crystal
-- / spirit weapons (T4-T6) can be ordered at the Forge: gold (the weapon's own Price) + materials + the weapon's MinLevel.
-- The numbers below are PROPOSED (decision 2-2 is 검수's): T4 as designed (3,000 gold + 10 Brute Horn + 20 Goblin Tooth), T5 /
-- T6 from the Skeleton Ruins drops (Bone P 0.4, Knight Crest P 0.5; about 20 kills a minute in a zone => T5 ~6 min of bones
-- + 2 of crests, T6 ~13 + 5). The gold is far below a first day's stack, so the door is materials and level (A23 H).
-- Switched by Config.Features.Commission (OFF until the Forge window shows its [Commission] row: the client is game dev 1's).
-- ShowLevel = from which level the next-goal ladder names the order. Card = the ChoiceCard kind that opens after the order.
Config.Features.Commission = false
Config.Commission = {
	Card = "ApprenticeScratch",
	CardDelay = 1.5, -- seconds after the equip line
	Orders = {
		[4] = { Gold = 3000, Items = { BruteHorn = 10, GoblinTooth = 20 }, ShowLevel = 10 }, -- Lv12 (the weapon's MinLevel)
		[5] = { Gold = 10000, Items = { KnightCrest = 12, Bone = 30 }, ShowLevel = 25 }, -- Lv20
		[6] = { Gold = 30000, Items = { KnightCrest = 30, Bone = 60 }, ShowLevel = 25 }, -- Lv30
	},
	Text = {
		Done = "Otto made your %s!",
		NeedLevel = "Otto says: come back at Lv %d!",
		NeedMaterials = "Otto needs more materials for this one.",
		Owned = "You already have this weapon.",
		GoalLabel = { [4] = "Golden weapon", [5] = "Crystal weapon", [6] = "Spirit weapon" },
		GoalMaterial = "Next goal · %s: %s %d/%d · %s/%s gold",
		GoalGold = "Next goal · %s: %s/%s gold",
		GoalLevel = "Next goal · %s: Lv%d (now Lv%d)",
		GoalReady = "Next goal · %s is ready at the Forge!",
	},
}
Config.RateLimits.Commission = 1
Config.ChoiceCard.Kinds.ApprenticeScratch = {
	Title = "The apprentice scratched the hilt a little.",
	Good = { Label = "It's fine. Thank you!", Reward = { Item = "Enh70", N = 1 }, Points = 1, Done = "Otto's apprentice beams." },
	Evil = { Label = "Fix it AND give me a discount!", Reward = { GoldMin = 2 }, Points = 1, Done = "A discount, just for you." },
}
-- A23-86 Sprout Oath titles (stat-free; the oath's pick decides which: Good = Guardian Cadet, Evil = Rascal Cadet)
Config.TitleDefs.GuardianCadet = { Name = "Guardian Cadet", NameEn = "Guardian Cadet", Color = Color3.fromRGB(255, 225, 120) }
Config.TitleDefs.RascalCadet = { Name = "Rascal Cadet", NameEn = "Rascal Cadet", Color = Color3.fromRGB(190, 120, 235) }
for _, id in { "GuardianCadet", "RascalCadet" } do
	if not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end
end

return Config
