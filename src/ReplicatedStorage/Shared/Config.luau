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

-- a ranking board's weekly cap (nil = none): Ranking.CraftWeekCap while Features.Crafting is on, else Ranking.WeekCap
function Config.WeekCapOf(board)
	local R = Config.Ranking
	if type(R) ~= "table" then return nil end
	local craft = type(R.CraftWeekCap) == "table" and R.CraftWeekCap[board] or nil
	if craft and Config.FeatureOn("Crafting") then return craft end
	return type(R.WeekCap) == "table" and R.WeekCap[board] or nil
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

-- Korean mode (contract docs/design/l10n_contract_2026-10-11.md §5-1): words of the shared L10n module. Join = the
-- separator of a list message { Join = { msg, ... } } (reward lists), key "Config.L10n.Join"
Config.L10n = { Join = " · ", JoinEn = " · " }

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
	-- zone_check_halo #34 (검수 2026-10-10): the CollectionService tag of EVERY potion seller Model besides the Crossroads one
	-- above (TownNpcs tags the Halo stall seller, Config.TownNpcs). ShopService sells at the nearest live seller (same prices,
	-- prompt and distance). Client contract (게임성 개발 1, pending): MiniMap / [Show me the way] point at the nearest seller.
	PotionMerchantTag = "PotionMerchant",
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
	-- C1 (save v4): 4 = weapon tier 9 (a 9-bit mask, WeaponEnhance[9]) + Spares / Market (save_v4_tables_2026-10-11.md).
	-- A23-153 (save v5): 5 = the monster codex (Codex; DataService.migrate fills it once from KillLog.ByKind).
	Version = 5,
	AutosaveInterval = 60,
	LockTimeout = 120, -- seconds; a lock older than this is considered dead
	-- A23-48 batch (검수 2026-10-06): a locked / failed load retries every 6 s, 5 tries (the last one takes the lock:
	-- dead-server recovery after ~24 s); the waiting player sees Config.Text.SaveLoading (attribute SaveLoading)
	LoadRetries = 5,
	LoadRetryDelay = 6,
	SaveRetries = 3,
	Defaults = {
		Version = 5,
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
		-- FieldBossService: per boss key { Kills = paid kills, Week = Config.WeekIndex last counted, Owed = weekly item
		-- guarantees not taken yet (<= Weekly.Max) } (J: Captain Clatter's badge)
		FieldBoss = {},
		TitleSel = "", -- BB16: the title shown on the nametag ("" = automatic: faction rank / gray legend)
		-- BB2: one settings blob per account (SettingsService; never mirrored). Keys = sparse { [Keybinds action id] =
		-- key name or "" (unbound) } holding only changes from the defaults. DataService runs Config.SanitizeSettings on it.
		-- Cam (A23-65): user 10/08 "카메라 뒤 따라가게 하는 거 없는 게 나을까? 좀 어색한데?" -> the default is Free (Roblox's own
		-- camera); Follow stays in Settings for whoever wants it. Settings V3 (검수 10/09): a save from before V3 gets Cam = Free
		-- once (SanitizeSettings); a Follow picked after that is kept. A23-91 (user 10/09 "콘솔 게임처럼"): the console-style
		-- Follow is the default again; Settings V4: a save from before V4 gets Cam = Follow once, a Free picked from V4 stays
		Settings = { V = 4, Keys = {}, Sfx = 1, Music = 1, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = false, Lang = "Auto", BagSort = "Default",
			Cam = "Follow", PvPCards = false, Weather = true, BagWide = false },
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
		-- A23-39 / PET-2 pets (PetService): List[uid] = { Sp, Lv, XP, Name, Lean, Bound, Roll? }, Equipped = { uid }, Next = the
		-- next uid number, Away = put away by the player (PET-2b: stays away after a rejoin; never the tamer).
		-- TamerNotice = the one-time "the hunter became the pet tamer" notice (+ free class change) is done
		Pets = { List = {}, Equipped = {}, Next = 1, Away = false },
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
	-- ...(target: Lv 10 in about 10-12 minutes of slime hunting; gameplay plan 2026-10-13 1-A #4: 0.5 -> 0.35, the sum to Lv10
	-- 1,381 -> 962 XP, measured in the 10/17 test)
	EarlyMult = 0.35,
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
-- Gameplay plan 2026-10-13 1-A #2 (A23-127: weapons come from drops and trades): Buy = false refuses only buying a weapon
-- not owned yet (ShopService, Text.WeaponDropOnly; the Forge hides its buy button). Equip, enhance and sell stay, and
-- MaxSoldTier still bounds the Forge rows (never 0: that closes enhance and sell too)
Config.WeaponShop = { MaxSoldTier = 3, Buy = false, PromptName = "HHC_BlacksmithPrompt", Distance = 12 }

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
	-- A23-127 (C1, save v4): the Mythic tier, made only by artisans (CraftService W9 -> spare weapons). Never dropped, never a
	-- jackpot, never sold at the Forge (WeaponShop.MaxSoldTier), never a commission. Price = the sale-value reference only.
	-- Color = placeholder until the image team picks the Mythic look.
	{ Tier = 9, Damage = 2200, Price = 250000, MinLevel = 50, Color = Color3.fromRGB(255, 70, 130), Material = Enum.Material.Neon, Length = 6.2 }, -- C1: 0.3 under T7 (the bigger orb keeps the staff within the avatar's height, A23-133)
}
Config.MaxWeaponTier = #Config.Weapons

-- display names per class (A23-48: English only); tier 7 is a table keyed by faction. Index = saved tier key: only
-- ever APPEND tiers. T4-T6 names come from the monsters that drop them (design skills_weapons_pets_2026-10-05 §1 B3).
Config.WeaponNames = {
	Warrior = { "Twig", "Wooden Sword", "Iron Sword", "Goblin Thief's Golden Sword", "Old Kingdom Crystal Sword", "Guardian Spirit Sword",
		{ Halo = "Dawn Sword", Horns = "Ruin Sword", None = "Crown Shard Sword" }, "Jelly Crown Sword", "Crownforged Sword" },
	Mage = { "Dry Staff", "Oak Staff", "Iron Staff", "Goblin Thief's Golden Staff", "Old Kingdom Crystal Staff", "Guardian Spirit Staff",
		{ Halo = "Dawn Staff", Horns = "Ruin Staff", None = "Crown Shard Staff" }, "Jelly Crown Staff", "Crownforged Staff" },
	Archer = { "Slingshot Bow", "Wooden Bow", "Iron Bow", "Goblin Thief's Golden Bow", "Old Kingdom Crystal Bow", "Guardian Spirit Bow",
		{ Halo = "Dawn Bow", Horns = "Ruin Bow", None = "Crown Shard Bow" }, "Jelly Crown Bow", "Crownforged Bow" },
}

-- A23-39: the pet tamer (artisan guild Archer, Config.IsTamer) holds taming batons instead of bows (same stats)
Config.WeaponNames.Tamer = { "Twig Baton", "Wooden Baton", "Iron Baton", "Goblin Thief's Golden Baton",
	"Old Kingdom Crystal Baton", "Guardian Spirit Baton", { Halo = "Dawn Baton", Horns = "Ruin Baton", None = "Crown Shard Baton" },
	"Jelly Crown Baton", "Crownforged Baton" }
-- the former English twin is the same tables now (readers of WeaponNamesEn keep working)
Config.WeaponNamesEn = Config.WeaponNames

-- Weapon grades (design §1 B1): stars are RARITY, not power. Colors = ART_DIRECTION 2.3 grade strokes.
Config.WeaponGrades = {
	Common = { Name = "Common", NameEn = "Common", Stars = 1, Color = Color3.fromRGB(200, 200, 200), Rank = 1 },
	Fine = { Name = "Fine", NameEn = "Fine", Stars = 2, Color = Color3.fromRGB(90, 200, 90), Rank = 2 },
	Rare = { Name = "Rare", NameEn = "Rare", Stars = 3, Color = Color3.fromRGB(70, 140, 255), Rank = 3 },
	Epic = { Name = "Epic", NameEn = "Epic", Stars = 4, Color = Color3.fromRGB(170, 90, 230), Rank = 4 },
	Legend = { Name = "Legendary", NameEn = "Legendary", Stars = 5, Color = Color3.fromRGB(255, 160, 40), Rank = 5 },
	-- A23-127 tier 9 (crafted). Color = placeholder: the image team may change it
	Mythic = { Name = "Mythic", NameEn = "Mythic", Stars = 6, Color = Color3.fromRGB(255, 70, 130), Rank = 6 },
}
-- per tier: grade id + where it comes from (one line, shown in the item list / blacksmith). A23-127 (plan 10/13 §1-A #2):
-- weapons come from monsters (the Forge sells none: WeaponShop.Buy = false) - the first Slime Prince always drops tier 2
-- (Config.Loot.FirstWeaponDrop), the first King Slime tier 3 (게임성 개발 2). ShopSource = the line while the Forge still
-- sells that tier (WeaponShop.Buy ~= false: the old flow, Config.WeaponSource picks it)
Config.WeaponInfo = {
	{ Grade = "Common", Source = "Your first weapon, a gift from the Blacksmith", SourceEn = "Your first weapon, a gift from the Blacksmith" }, -- A23-34
	{ Grade = "Common", Source = "Slime Prince drop (your first one always drops it)", ShopSource = "Sold at the Forge" },
	{ Grade = "Fine", Source = "King Slime drop (your first one always drops it)", ShopSource = "Sold at the Forge (from Lv5)" },
	{ Grade = "Rare", Source = "Rare drop from Goblins and Goblin Brutes, or a Forge commission" },
	{ Grade = "Epic", Source = "Rare drop from Skeletons and Skeleton Knights, or a Forge commission" },
	{ Grade = "Epic", Source = "Very rare drop from Skeleton Knights, or a Forge commission" },
	{ Grade = "Legend", Source = "Crafted by artisans (full launch)" },
	{ Grade = "Legend", Source = "Super rare slime drop (jackpot!)" },
	{ Grade = "Mythic", Source = "Crafted by artisans" },
}

function Config.WeaponGrade(tier)
	local info = Config.WeaponInfo[tier]
	return Config.WeaponGrades[info and info.Grade or "Common"] or Config.WeaponGrades.Common
end

function Config.WeaponSource(tier)
	local info = Config.WeaponInfo[tier]
	if info and info.ShopSource and not (type(Config.WeaponShop) == "table" and Config.WeaponShop.Buy == false) then
		return info.ShopSource
	end
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
		Desc = "Hits every enemy in front of you at once. Very tough!", -- 검수 10/11: A23-61 front half
		PickLine = "Get close and smash everything in front", -- addendum A7-4 (picker card action line)
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
		Stats = { "HP ×1.3", "ATK ×1.0", "Hits all in front" },
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
	-- A23-126 (user 2026-10-11 "추천대로"): a Halo heal's share for the caster itself is at most HaloSelfHealCapPct of its
	-- MaxHealth per 3 s (= the Horns life steal cap, Factions.Horns.LifestealCapPct); a friend's stays HaloHealCapPct.
	-- A ranged Q (Star Fall / Feather Rain: ReleaseCenter Target) heals around the caster within HaloHealRadius, like Z / X
	HaloSelfHealCapPct = 0.03, HaloHealRadius = 12,
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
			-- A23-116: Q and Z have a name and a line per side (the numbers are the same for both sides); a split slot seen
			-- with no side yet shows the Halo words (Config.SkillDef), like X
			Q = { Shape = "SelfCircle", Radius = 9, Mult = 6, MP = 20, CD = 3, Push = 2, Auto = { Min = 1, Radius = 9 },
				Halo = { NameEn = "Halo Slam", DescEn = "Slam your sword down. A gold ring hits and heals you and friends." },
				Horns = { NameEn = "Crater Smash", DescEn = "Smash the ground hard! Hit monsters around you and steal HP." } },
			Z = { Shape = "Line", Len = 22, Width = 10, AimCone = 75, Mult = 7.5, MP = 25, CD = 6, Pull = 5,
				Auto = { Min = 2, OrBig = true, NoPull = true },
				Halo = { NameEn = "Glow Lasso", DescEn = "Throw a glowing rope and pull monsters in. Heals you and friends." },
				Horns = { NameEn = "Fire Rake", DescEn = "Drag a fire crack ahead. Pull monsters in and steal HP." } },
			X = { Shape = "Roar", Radius = 12, Mult = 2, TauntRadius = 16, TauntSec = 4, SelfGuard = 0.4, GuardSec = 6,
				MP = 30, CD = 15, Auto = { Min = 3, Radius = 16, LowHP = 0.5, LowHPRadius = 10 },
				Halo = { NameEn = "Guardian Roar", DescEn = "Shout! Monsters chase you. You and your friends take less damage.",
					AllyGuard = 0.2, AllyRadius = 16 },
				Horns = { NameEn = "Rage Roar", DescEn = "Roar! Monsters chase you. Steal MP from every monster you hit.",
					MPSteal = 5 } },
		},
		Mage = {
			Q = { Shape = "TargetCircle", Range = 35, Radius = 9, Mult = 6, MP = 20, CD = 3, Auto = { Min = 1, Range = 35 },
				Halo = { NameEn = "Star Fall", DescEn = "A big star falls on the closest monster. Heals you and friends." },
				Horns = { NameEn = "Purple Pop", DescEn = "Purple bubbles pop up under the closest monster. Steal HP." } },
			Z = { Shape = "Chain", Range = 35, Jump = 10, Hits = 4, Mult = 5, MP = 25, CD = 5, NeedTarget = true,
				Auto = { Min = 1, Range = 35, BeforeQIfSpread = 2 },
				Halo = { NameEn = "Birdie Bounce", DescEn = "A gold bird hops from monster to monster. Heals you and friends." },
				Horns = { NameEn = "Bat Zigzag", DescEn = "A little bat zigzags from monster to monster. Steal HP." } },
			X = { Shape = "Field", Range = 35, Ahead = 10, Radius = 12, Duration = 5, Tick = 1, TickMult = 1.5, Slow = 0.5,
				MP = 30, CD = 14, Auto = { Min = 2, Radius = 12 },
				Halo = { NameEn = "Sun Circle", DescEn = "A sunny circle. Monsters slow down. Friends inside are guarded.",
					AllyGuard = 0.2 },
				Horns = { NameEn = "Hex Circle", DescEn = "A curse circle. Monsters slow down. Steal MP every second.",
					MPStealTick = 2 } },
		},
		Archer = {
			Q = { Shape = "TargetCircle", Range = 30, Radius = 9, Mult = 6, MP = 20, CD = 3, Auto = { Min = 1, Range = 30 },
				Halo = { NameEn = "Feather Rain", DescEn = "Gold arrows rain on the closest group. Heals you and friends." },
				Horns = { NameEn = "Spark Shower", DescEn = "Shoot twice! Dark arrows rain on the closest group. Steal HP." } },
			Z = { Shape = "Line", Range = 40, Len = 40, Width = 4, Mult = 9, MP = 25, CD = 5, Push = 3, Auto = { Min = 1 },
				Halo = { NameEn = "Comet Arrow", DescEn = "A giant gold arrow flies through a line. Heals you and friends." },
				Horns = { NameEn = "Moon Shot", DescEn = "A dark moon arrow flies through a line. Steal HP." } },
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
			QZHalo = "Halo: your hits heal friends", QZHorns = "Horns: your hits steal HP",
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
-- gear = { A, H } the gear multipliers (⑥, nil = 1, 1; Config.GearMult keeps a bad one at 1): they multiply the same two factors
function Config.PowerOf(level, weaponTier, rebirthMult, enhance, alloc, gear)
	local am, hm = 1, 1
	if type(alloc) == "table" then am, hm = Config.StatMults(alloc.A, alloc.H) end
	if type(gear) == "table" then am, hm = am * Config.GearMult(gear.A), hm * Config.GearMult(gear.H) end -- ⑥ gear (게임성 개발 3)
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
		-- 최종 검수 10/13 (ref_rpg_ui #2): a choice's power change as one short coloured line (Config.PowerDiff)
		Diff = { Up = "Power +%s", Down = "Power -%s", Same = "Power =" },
	},
}

-- A23-34 (user 2026-10-06 "처음에는 전투력이 0"): bare hands count from 0 — the Lv1 punch is taken off, so Lv1 with no
-- weapon (and no pet) shows 0 and every level still adds a little. With a weapon the number is the BB4 value as before,
-- so armed players keep their numbers and every armed comparison (bully rule, boldness, Tab list) its balance.
-- A23-69: alloc = { A, H } stat points (nil = none; Config.StatAllocOf reads a player's)
-- ⑥ gear = { A = atkMult, H = hpMult } (nil = 1, 1; Config.GearMultsOf reads a player's)
function Config.CombatPower(level, tier, enhance, alloc, gear)
	local raw = Config.PowerOf(level, tier, 1, enhance, alloc, gear)
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
	local gearAtk, gearHp = Config.GearMultsOf(player) -- ⑥ gear (게임성 개발 3): (1, 1) while Config.Features.Gear is off
	return Config.CombatPower(math.max(1, level), tier, enhance, Config.StatAllocOf(player), { A = gearAtk, H = gearHp })
end

-- 최종 검수 10/13 (ref_rpg_ui #1, 전투력 풀어 보기): the two numbers the power is made of (Config.PowerOf: the square root
-- of attack x health) - Attack = the weapon's damage at this level and +N x the attack points / ring, Health = the level's
-- base health x the health points / armor. Pure; the player's own in Config.PowerPartsOf
function Config.PowerParts(level, tier, enhance, alloc, gear)
	local atkMult, hpMult = 1, 1
	if type(alloc) == "table" then atkMult, hpMult = Config.StatMults(alloc.A, alloc.H) end
	if type(gear) == "table" then atkMult, hpMult = atkMult * Config.GearMult(gear.A), hpMult * Config.GearMult(gear.H) end
	return math.floor(Config.WeaponDamage(tier, level, enhance) * atkMult + 0.5), math.floor(Config.BaseHealth(level) * hpMult + 0.5)
end
function Config.PowerPartsOf(player)
	local level = tonumber(player:GetAttribute("Level")) or 1
	if level ~= level then level = 1 end
	local tier = tonumber(player:GetAttribute("WeaponTier")) or 0
	if tier ~= tier then tier = 0 end
	local gearAtk, gearHp = Config.GearMultsOf(player)
	return Config.PowerParts(math.max(1, level), math.clamp(math.floor(tier), 0, Config.MaxWeaponTier),
		tonumber(player:GetAttribute("WeaponEnhance")) or 0, Config.StatAllocOf(player), { A = gearAtk, H = gearHp })
end

-- 최종 검수 10/13 (ref_rpg_ui #2): the change from power `now` to `with` -> its size (>= 0) and a tone: "Good" (up),
-- "Bad" (down), "Same" (equal); nil when either is missing. Screens format Config.Power.Text.Diff with it
function Config.PowerDiff(now, with)
	now, with = tonumber(now), tonumber(with)
	if not (now and with) or now ~= now or with ~= with then return nil, nil end
	local d = math.floor(with + 0.5) - math.floor(now + 0.5)
	if d > 0 then return d, "Good" end
	if d < 0 then return -d, "Bad" end
	return 0, "Same"
end

-- the highest number anyone can reach (max level, the highest-damage weapon at the max scroll +N; A23-69 with the stat
-- points on: the even split of every point, the strongest build; ⑥ gear on: the best gear, T3 +2 armor and ring);
-- cached, one value per switch combination
function Config.MaxCombatPower()
	local stats = Config.FeatureOn("StatPoints")
	local gearOn = Config.FeatureOn("Gear")
	local key = stats and "MaxCacheStats" or "MaxCache"
	if gearOn then key ..= "Gear" end -- ⑥ gear (게임성 개발 3): its own cache value
	if not Config.Power[key] then
		local points = Config.StatPoints(Config.Levels.MaxLevel)
		local even = stats and { A = math.floor(points / 2), H = points - math.floor(points / 2) } or nil
		local top = gearOn and { A = 1 + Config.GearBonus("Ring", Config.Gear.MaxTier, Config.Gear.MaxPlus),
			H = 1 + Config.GearBonus("Armor", Config.Gear.MaxTier, Config.Gear.MaxPlus) } or nil
		local best = 0
		for t = 1, Config.MaxWeaponTier do
			best = math.max(best, Config.CombatPower(Config.Levels.MaxLevel, t, Config.Loot.MaxEnhance, even, top))
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

-- A23-105 (CR-L20 amended): WarService's war-sky ClockTime tween - only while no day cycle runs (Config.DayCycle.Enabled
-- false or its Start not done; a running DayCycleService owns the clock under every sky) - runs forward unless that is
-- more than ClockForwardMax hours (then the short way back): a guard against a whole day spun in 3 s from a clock moved
-- off the presets (8:00 -> Dawn 7.2 = 23.2 h). 18 keeps every change between the fixed presets forward exactly as before
-- (the longest: Dawn 7.2 -> Eclipse 0.5 = 17.3 h; Neutral 15.3 -> Dawn 7.2 = 15.9 h).
Config.Sky.ClockForwardMax = 18

-- A23-105 (user 2026-10-10 "해가 지고 떴으면 좋겠고 ... 건물이나 구조물들도 해 방향에 따라서 그림자 달라지면"; 검수 defaults):
-- the server turns the day. DayCycleService owns Lighting.ClockTime under every sky and the Neutral sky's look
-- (Brightness, Ambient, OutdoorAmbient, ExposureCompensation, FogColor / FogStart / FogEnd; WarService leaves them alone
-- while it runs) and writes them every Tick s, a small step each time, so the sun and the shadows move. A crown-war sky
-- (Dawn / Eclipse; 검수 2026-10-10, the user's choice (b)) covers only the LOOK - WarService's light values, fog, tint,
-- bloom, cloud colour - while ClockTime keeps turning under it (the sun and the shadows keep moving); when it ends the
-- look eases over Config.Sky.TweenTime from the war look to the look of the time of day it is then, no jump.
-- Pace = how fast the clock runs: each piece from its From hour (ClockTime) to the next one's in Seconds of real time; one
-- day = their sum (1440 s = 24 min). Slowest by day (0.08 degrees of sun per 0.5 s write), sunrise / sunset a little
-- faster (0.13 degrees: short, as asked), the night fastest (0.31 degrees). Tick 0.5 halves the step of each write (the
-- long low-sun shadows at sunrise / sunset are what would show a step).
-- Phases = GameState DayPhase by the clock shown (names only; WeatherFx: lamps on at Dusk / Night, off at Dawn / Day):
-- Dawn from 6:00, sunrise, when the light is already half up (NightLevel ~0.5 - never lamps off under the full night
-- look), Day 7-17, Dusk 17-19 (lamps on while the sun is low), Night 19-6. Real time: Dawn 60 s, Day 960 s (2/3 of the
-- day), Dusk 120 s, Night 300 s.
-- GameState DayPhase / NightLevel ALWAYS follow the ClockTime shown, under every sky (검수 2026-10-10 lens review): its
-- Phases name and the Night share of the time-of-day look at it (Looks / Keys below), 2 decimals. A war sky never fixes
-- them (the clock keeps turning under it: a Halo win at 17:30 runs into Dusk and Night, the lamps on; a Horns win at noon
-- is Day / 0, no night lift under the sun). With the cycle not running (Enabled false / its Start not done) they follow
-- WarService's shown clock (the fixed afternoon 15.3 = Day / 0, the Eclipse preset 0.5 = Night / 1).
-- Looks by ClockTime: Keys (ascending hours) mark where a look is exact; in between it eases (smoothstep). A look takes
-- what it leaves out from Config.Sky.Neutral, so Day = {} IS the approved toy-bright afternoon (one source; 8-16 exactly).
-- Night = a moonlit blue kids can walk in (the Eclipse sky's Brightness 1.4 / exposure +0.35), FogStart / FogEnd closer.
-- Floor = the least any written value may be (each colour channel; rain at night included). Night (0..1) per look ->
-- GameState NightLevel (ZoneLook's night lift). StartClock: a new server starts at the approved afternoon. MaxStepHours:
-- the offline test's guard for the biggest clock step of one write. SwitchService "DayCycle" off = the clock eases the
-- short way to StartClock and stays, the look with it unless a war sky covers it (live once Config.Switches.Defs lists
-- it; until then always on). Enabled = false: WarService keeps the fixed Neutral afternoon and the preset war clocks.
-- Studio: DebugCommand ("", "Clock", 21) / ("", "DayState") - no player, no save (under a war sky only the clock jumps).
Config.DayCycle = {
	-- on: ZoneLook C1 (night lift by NightLevel) + C2 (hollow dusk without the 6:00 jump) landed with it (game dev 1;
	-- tools/test_day_cycle.py checks the pair)
	Enabled = true,
	Tick = 0.5,
	StartClock = 15.3,
	MaxStepHours = 0.025,
	Pace = {
		{ From = 5, Seconds = 120 }, -- sunrise
		{ From = 7, Seconds = 960 }, -- the day
		{ From = 17, Seconds = 120 }, -- sunset
		{ From = 19, Seconds = 240 }, -- the night
	},
	Phases = {
		{ Name = "Dawn", From = 6 },
		{ Name = "Day", From = 7 },
		{ Name = "Dusk", From = 17 },
		{ Name = "Night", From = 19 },
	},
	Keys = {
		{ Hour = 5, Look = "Night" }, { Hour = 6.5, Look = "Dawn" }, { Hour = 8, Look = "Day" },
		{ Hour = 16, Look = "Day" }, { Hour = 17.5, Look = "Dusk" }, { Hour = 19, Look = "Night" },
	},
	Looks = {
		Day = {},
		Dawn = { Brightness = 1.6, Ambient = Color3.fromRGB(86, 78, 86), OutdoorAmbient = Color3.fromRGB(112, 104, 114),
			ExposureCompensation = -0.1, FogColor = Color3.fromRGB(236, 196, 178), Night = 0.3 },
		Dusk = { Brightness = 1.6, Ambient = Color3.fromRGB(88, 74, 82), OutdoorAmbient = Color3.fromRGB(116, 100, 108),
			ExposureCompensation = -0.1, FogColor = Color3.fromRGB(232, 168, 140), Night = 0.3 },
		Night = { Brightness = 1.4, Ambient = Color3.fromRGB(70, 78, 106), OutdoorAmbient = Color3.fromRGB(98, 110, 148),
			ExposureCompensation = 0.35, FogColor = Color3.fromRGB(46, 60, 100), FogStart = 120, FogEnd = 800, Night = 1 },
	},
	Floor = { Brightness = 1.2, Ambient = Color3.fromRGB(60, 66, 80), OutdoorAmbient = Color3.fromRGB(88, 96, 108),
		ExposureCompensation = -0.3 },
}

-- A23-105 weather (rain before the beta, snow in winter): one state for the whole server, GameState Weather = "Clear" /
-- "Rain" / "Snow" (the client WeatherFx draws the drops / flakes around each camera; Settings 'Weather effects' turns
-- them off on a phone). Mostly clear: a clear spell lasts Clear s (random in the range), then a shower starts with Chance
-- (else another clear spell) and lasts Rain s. Snow ONLY in the northern winter by the Korean date (KST = UTC +
-- UtcOffsetHours, SnowMonths 12 / 1 / 2): then every shower is snow INSTEAD of rain (WinterChance, Snow s) - one kind of
-- sky at a time, snow is the winter's treat (the 12/19 launch is in it) and rain at freezing would only be sleet; a
-- shower running when the month turns changes kind at midnight KST (its look eases across). A new server starts clear
-- for FirstClear s. One Random per server, seeded from os.time() and the JobId (a number Seed pins it). The light gets
-- wet with the weather, eased over BlendSeconds: the sun x BrightK, exposure + ExpAdd, the fog greyer (Desat) and
-- darker / lighter (FogK) and closer (FogEndK), the terrain clouds (when the place has them) toward Cover / Density.
-- Expected: rain ~12% of the time (0.45 x 270 s per ~1020 s), winter snow ~19%. The haunted hollow's fog is ZoneLook's.
-- SwitchService "Weather" off = always Clear (live once Config.Switches.Defs lists it). Studio: DebugCommand ("", "Weather",
-- "Snow:120") - snow in any month there.
Config.Weather = {
	Enabled = true,
	UtcOffsetHours = 9,
	SnowMonths = { [12] = true, [1] = true, [2] = true },
	FirstClear = { 300, 600 },
	Clear = { 600, 1200 },
	Chance = 0.45,
	WinterChance = 0.6,
	Rain = { 180, 360 },
	Snow = { 240, 480 },
	BlendSeconds = 20,
	Looks = {
		Rain = { BrightK = 0.8, ExpAdd = -0.05, Desat = 0.6, FogK = 0.85, FogEndK = 0.7, Cover = 0.85, Density = 0.55 },
		Snow = { BrightK = 0.9, ExpAdd = 0.05, Desat = 0.5, FogK = 1.1, FogEndK = 0.75, Cover = 0.8, Density = 0.45 },
	},
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
	StartSeconds = 2, -- A23-130: the start line (Text.Start) shows this long, once per goose
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
	WinWarPoints = 30, -- A23-137: the winning side +30 crown-war points (versus only)
	Tick = 0.25,
	-- A23-131 황금 알 줍기: "Eggs" = the egg hunt (GooseEggs.luau); "Tug" = the old tug (kept until the tests move, 11/10)
	Mode = "Eggs",
	-- A23-137: Eggs mode starts at fixed KST clock times (00/04/08/12/16/20 with Every 14400; TzOffset = KST UTC+9).
	-- A test server may set Every = 600 (every 10 min on the clock)
	Schedule = { Every = 14400, TzOffset = 32400 },
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
	-- English texts (string.format). Mode name: Halo "Team Rescue", Horns "Team Poach".
	Text = {
		-- A23-130 (user 2026-10-11 "너무 설명해주는 게 많은 거 같애"): NotifyAll at the start, one short line for StartSeconds,
		-- once per goose in every mode (the top gauge tells the rest: no co-op band, no line when the mode is fixed later)
		Start = "Golden Goose!",
		Label = "Golden Goose", -- the goose's name tag (GooseService billboard)
		NeedManual = "No reward: hit it yourself %d+ times", -- (MinManualHits)
		CoopFull = { -- NotifyAll once when the gauge is full (MinManualHits)
			Halo = "Rescue done! Hit it %d+ times yourself for a reward.",
			Horns = "Poach done! Hit it %d+ times yourself for a reward.",
		},
		CoopResult = { -- NotifyAll at the end, gauge filled
			Halo = "The Knights worked together and rescued the Golden Goose! The shard shines with light again.",
			Horns = "The Horn Legion worked together and poached the Golden Goose! The shard turned dark.",
		},
		CoopFail = "The gauge wasn't filled, so the Golden Goose flew away!", -- NotifyAll at the end, gauge not filled
		RivalLeft = "The other side all left, so the team rule decides it. %s", -- (CoopResult / CoopFail) tug whose rival left
		RivalWait = { -- to a rival who tries to pull during co-op (once per event), keyed by the CO-OP side
			Halo = "Not your goose this time.",
			Horns = "Not your goose this time.",
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
		-- Eggs mode: the only extra line (A23-99 fail fact): a side player who delivered 1+ egg but not enough for a reward
		BringTwo = "Bring 2 eggs for a reward.",
	},
}

-- A23-131 / A23-134 / A23-137 황금 알 줍기, the server rules (GooseEggs.luau; 게임성 개발 2). Contract:
-- docs/design/golden_egg_contract_2026-10-11.md §2 (the client reads Kinds, MaxSlots, PickRadius, PickHeight, Center,
-- RingRadius, WobbleFrom, Home, HomeRadius, IdleReturn, IdleWobble, FlyTime, Tag). Design: docs/design/golden_egg_2026-10-11.md.
Config.Goose.Egg = {
	Kinds = { -- Points = base points (the crown's is set when laid, part attribute Points), Slots = carried slots
		Gold = { Points = 10, Slots = 1 }, Bouncy = { Points = 20, Slots = 1 },
		Big = { Points = 30, Slots = 3 }, Crown = { Points = 50, Slots = 3 },
		Feather = { Points = 0, Slots = 0 }, -- A23-134: a ground feather, straight to the bag (GooseFeather)
	},
	MaxSlots = 3, PickRadius = 4.5, PickHeight = 6, PickSlack = 0.5, -- the server allows PickSlack more (phone ping)
	Center = Vector3.new(0, 0, 0), -- the ring centre (the Crossroads fountain)
	RingRadius = 54, WobbleFrom = 45, -- carried eggs return past RingRadius; the client wobbles them from WobbleFrom
	Home = { Halo = Vector3.new(-30, 0, -30), Horns = Vector3.new(-30, 0, 30) }, HomeRadius = 8, -- nest / egg cart
	IdleReturn = 10, IdleWobble = 7, -- carrying and not moving MoveMin studs for IdleReturn s = the eggs return
	FlyTime = 0.7, CrownFly = 1.0, -- s a laid / bounced egg flies (not pickable until it lands)
	Tag = { On = true, Radius = 3, Hold = 1, Shield = 3, Cooldown = 4 }, -- A23-134 egg tag
	Tick = 0.1, -- s between server checks while the hunt runs
	Duration = 60, LayStop = 55, Hurry = { From = 50, To = 55, Mult = 1.5 },
	-- eggs per s = clamp(Base + PerPlayer x P, Min, Max); P = ready Halo / Horns players who may pick inside the ring,
	-- recounted every Recount s
	Rate = { Base = 0.4, PerPlayer = 0.2, Min = 0.6, Max = 3, Recount = 5 },
	GroundCap = 30, Unpicked = 15, -- ground eggs at most; a landed egg nobody picks for Unpicked s returns
	Sneeze = 6, ArrivalFeathers = 3, NapFeathers = 1, -- the arrival sneeze (eggs in a ring + feathers), a feather per nap
	Bouncy = { From = 30, Share = 0.15, Near = 7, Hop = 6, Hops = 3 },
	-- drop spots: Min..Max studs from the goose on the half away from the fountain; never within Fountain of the centre
	-- (the basin is 13), within Home of a home, past Ring, on water, within Avoid (altar, Crossroads spawn, pads) or
	-- where the ground is more than Step studs above / below the goose's feet; a prop overlap (Prop radius) redraws,
	-- at most Tries draws
	Drop = { Min = 4, Max = 10, Fountain = 14, Home = 16, Ring = 46, Step = 4, Prop = 1.2, Tries = 8, AvoidRadius = 8,
		Avoid = { Vector3.new(0, 0, 45), Vector3.new(0, 0, -25), Vector3.new(52, 0, 24), Vector3.new(52, 0, -24),
			Vector3.new(68, 0, 24) } },
	Carry = { 0.9, 0.8, 0.7 }, HeavyMult = 0.7, -- speed x by carried slots (Big / Crown = x0.7)
	PlazaSpeed = 20, -- A23-134: inside the ring while the hunt runs everyone starts from this (no class / pet speed)
	-- a paid side player: MinDelivered eggs or MinPoints points (MinCrowd eggs once P reached CrowdFrom)
	MinDelivered = 2, MinPoints = 20, MinCrowd = 1, CrowdFrom = 16,
	CoopPerPerson = 80, -- co-op target = CoopPerPerson x the co-op side's ring entrants (min 1)
	HMax = 2, -- the fewer side's points x clamp(sqrt(more N / fewer N), 1, HMax); N = average ring presence
	-- crown = max(Min, Share x both totals), laid anywhere on the west half of the egg area (x < the fountain's)
	Crown = { At = 50, Min = 50, Share = 0.15, Gold = 4, Overtime = 8 },
	Naps = { 15, 30, 45 }, NapTime = 2,
	Chases = { 22, 38 }, ChaseTime = 4, ChaseAlert = 1, ChaseSpeed = 17, ChaseMinSlots = 2, ChaseHit = 3, ChaseBounce = { 6, 8 },
	Walk = { Radius = 18, Lap = 24, MinFountain = 16, MaxRing = 46 }, -- the goose's circle (s per lap) and its limits
	RePick = 1.5, MoveWindow = 0.5, MoveMin = 1, PickRateLog = 3, -- a dropped egg: its dropper waits RePick s
	-- cheat check: delivery time >= (last pick -> home ring edge) / (speed x SpeedSlack) - Grace; Enforce false = log only
	Cheat = { SpeedSlack = 1.4, Grace = 0.3, Enforce = false },
	HonorPoints = 5, HonorEvery = 3600, -- A23-134: Honor / Infamy +5 at most once an hour per paid player
	NeutralTopMult = 1.5, -- A23-134: the round's top Neutral picker gets 50% more eggs (floor, at least +1)
	Items = { Egg = "GoldenEgg", Feather = "GooseFeather" }, -- Neutral picks go to the bag as these
}

-- A23-141 (user 10/12): the egg hunt runs in the Goose Square, a separate space in the same server outside the map; only
-- players who press Join (remote GooseSquare "Join" | "Leave"; Config.Goose.Square = game dev 1's client table: Remote,
-- Attr, Block, Fade, Text - the server only reads it) go there. The real Crossroads plaza has no goose and no eggs.
-- The space = workspace.GooseSquare (the image team's skeleton, docs/design/goose_square_skeleton_2026-10-12.md): the
-- model attributes GooseSpotPos / NestPos / CartPos / SpawnHaloPos / SpawnHornsPos / SpawnNeutralPos (world positions) or
-- the parts of those names, the Floor's size = the area. Missing -> GooseSquare.luau builds a plain floor, invisible walls
-- and the markers ONCE at Center + Offsets (no decoration). Join gates: GooseActive, ready, alive, not the kaiju, no
-- grudge sack, no PvP combat tag (CombatTagTime) or NoTravelStars stars, like Travel (GooseJoinBlock "" | "Dead" | "Monster"
-- | "Grudge" | "PvP").
-- The way back: the spot Join was pressed at, unless it is a PvP spot, under the kill height, inside the square or its
-- zone is gone -> the own town start. Auto combat is paused inside (the attribute only: the saved choice stays).
Config.Goose.SquareSpace = {
	Enabled = true,
	Center = Vector3.new(6000, 200, 6000), -- the floor's top (the skeleton's default, outside every zone and the fog)
	Size = Vector3.new(110, 4, 90), -- the fallback floor (x, thickness, z)
	WallHeight = 30,
	Offsets = { -- the fallback markers from Center (north = -z: the Halo nest; south = +z: the Horns cart)
		GooseSpot = Vector3.new(0, 0, 0), Nest = Vector3.new(0, 0, -37), Cart = Vector3.new(0, 0, 37),
		SpawnHalo = Vector3.new(0, 0, -24), SpawnHorns = Vector3.new(0, 0, 24), SpawnNeutral = Vector3.new(-22, 0, 0),
	},
	SpawnSpread = 4, -- a joiner lands within this many studs of the side's spawn mark
	SpawnClear = 6, -- no egg lands within this of a spawn mark
	ReturnAfter = 4, -- s after the result: everyone still inside goes back
	FallBelow = 25, -- a root this far under the floor top, or Margin studs off the floor's area = left the square
	Margin = 20,
	BlockEvery = 0.5, -- s between GooseJoinBlock refreshes
	KillHeightPad = 50, -- a way-back spot must be this far above workspace.FallenPartsDestroyHeight
}
-- the player is in the Goose Square (the attribute GooseSquare.luau writes; the name comes from game dev 1's table)
function Config.InGooseSquare(p)
	local name = type(Config.Goose.Square) == "table" and Config.Goose.Square.Attr or "InGooseSquare"
	return typeof(p) == "Instance" and p:GetAttribute(name) == true
end

-- A23-134 plaza speed: base x the carry multiplier for `slots` carried (heavy = a Big / Crown egg). nil = no rule
function Config.GooseEggSpeed(slots, heavy)
	local E = Config.Goose.Egg
	local n = math.clamp(math.floor(tonumber(slots) or 0), 0, #E.Carry)
	local mult = n > 0 and E.Carry[n] or 1
	if heavy == true then mult = math.min(mult, E.HeavyMult) end
	return E.PlazaSpeed * mult
end

-- A23-141 Goose Square (user 2026-10-12; contract docs/design/goose_square_contract_2026-10-12.md): golden-egg play happens
-- in a separate square of the same server, off the map; only players who press Join go there. Remote = the c->s
-- RemoteEvent (one arg "Join" | "Leave"); Attr = my player attribute the server sets (true = I am in the square);
-- Block = my player attribute "" | "Dead" | "Monster" | "Grudge" | "PvP" (non-empty = the Join button is dimmed, no
-- text, A23-130); Fade = seconds of the screen going dark / clear again when Attr changes (EggFx); Text = the Join /
-- Leave words (EventHUD) and the server's refusal Notify lines (GooseEggs, 게임성 개발 2), easy short English.
if type(Config.Goose) == "table" then
	Config.Goose.Square = {
		Remote = "GooseSquare",
		Attr = "InGooseSquare",
		Block = "GooseJoinBlock",
		Fade = { In = 0.25, Out = 0.35 },
		Text = { Join = "Join", Leave = "Leave",
			Dead = "You can't join right now.", Monster = "You can't join right now.", Grudge = "You can't join right now.",
			PvP = "You can't join during a fight.", Closed = "The goose is gone." },
	}
end

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
-- 검수 10/09 (user: "물약 칸 있어야지. 퀵 슬롯!"): PotionsAlways = the potion pair shows from the start (the pouch keeps
-- its rule)
Config.HudReveal = { Level = 5, LowHP = 0.5, PotionsAlways = true }
function Config.HudReveal.Shows(kind, s)
	s = type(s) == "table" and s or {}
	local lv = tonumber(s.Level) or 0
	if lv >= Config.HudReveal.Level then return true end
	if kind == "Potions" then
		if Config.HudReveal.PotionsAlways == true then return true end
		local hp, maxHP = tonumber(s.HP) or 0, tonumber(s.MaxHP) or 0
		return (tonumber(s.Potions) or 0) > 0 or (maxHP > 0 and hp > 0 and hp < maxHP * Config.HudReveal.LowHP)
	elseif kind == "Pouch" then
		return (tonumber(s.Carried) or 0) > 0
	end
	return true
end

-- A23-113 ③ (user 2026-10-10 "마감 전 넣자", 고침 same day "처음부터 다 보이고, 그 자물쇠 해놓자"): every bottom menu
-- tile shows from the start; one not open yet is LOCKED (UIKit.TileLock: dark + lock + the small word TileWords[id];
-- a press only wiggles it, no window, no notice). The bag and the map are always open; the hero opens at the first level
-- up, the skills at the first skill (Config.Skills.Unlock.Q), the pet once I have a pet, the ranking once the first
-- chapter's main quests are done (FirstChapterLast). The lock pops away when it opens (no pop with reduced motion). The
-- quick slots always show (not a tile). Pure: s = { Level, SkillSlots, HasPet, ChapterDone }
Config.HudReveal.Tiles = { Character = "LevelUp", Skills = "Skill", Pet = "Pet", Ranking = "Chapter" }
Config.HudReveal.FirstChapterLast = "M1_4"
-- the locked tile's word (short, under the icon; %d = the level)
Config.HudReveal.TileWords = { Character = "Lv 2", Skills = "Lv %d", Pet = "Get pet", Ranking = "Story 1" }
function Config.HudReveal.TileWord(id)
	local w = Config.HudReveal.TileWords[id]
	if type(w) ~= "string" then return "" end
	if string.find(w, "%%d") then
		local q = type(Config.Skills) == "table" and type(Config.Skills.Unlock) == "table" and tonumber(Config.Skills.Unlock.Q) or 5
		return string.format(w, q)
	end
	return w
end
function Config.HudReveal.TileShows(id, s)
	s = type(s) == "table" and s or {}
	local rule = Config.HudReveal.Tiles[id]
	if rule == nil then return true end
	if rule == "LevelUp" then return (tonumber(s.Level) or 1) >= 2 end
	if rule == "Skill" then
		local q = type(Config.Skills) == "table" and type(Config.Skills.Unlock) == "table" and tonumber(Config.Skills.Unlock.Q) or 5
		return (tonumber(s.SkillSlots) or 0) >= 1 or (tonumber(s.Level) or 1) >= q
	end
	if rule == "Pet" then return s.HasPet == true end
	if rule == "Chapter" then return s.ChapterDone == true end
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
		FloorColor = Color3.fromRGB(228, 218, 190), FloorMaterial = Enum.Material.Marble, Spawn = Vector3.new(0, 0, -420),
		SpawnLook = Vector3.new(0, 0, -330) }, -- the gate at the bridge end: the first mission's spawn faces the way out (zone_check_halo #43)
	HornsTown = { Id = "HornsTown", Name = "Horns Den", Center = Vector3.new(0, 0, 515), Size = Vector3.new(400, 0, 370),
		MinLevel = 1, PvP = false, Town = true, Faction = "Horns",
		FloorColor = Color3.fromRGB(70, 40, 45), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(0, 0, 420),
		SpawnLook = Vector3.new(0, 0, 330) }, -- same for Horns Den (the gate at the bridge end)
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
	-- A23-90 (user 2026-10-09): the outer hunting ring is safe (no PvP); only the inner Crown Pit around the crown altar
	-- ruin (1700, 0) is a PvP area (Config.PvPAt): wanted stars, sacks and grudges happen there only; its kills roll
	-- their drop rows x LootMult; Captain Clatter appears there (Config.FieldBosses.Clatter.Spawn)
	SkeletonRuins = { Id = "SkeletonRuins", Name = "Skeleton Ruins", Center = Vector3.new(1520, 0, 0), Size = Vector3.new(520, 0, 580),
		MinLevel = 25, PvP = false, Town = false, Faction = nil,
		PvPArea = { Name = "Crown Pit", Center = Vector3.new(1660, 0, 0), Size = Vector3.new(200, 0, 240), LootMult = 1.25 },
		FloorColor = Color3.fromRGB(135, 125, 108), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(1280, 0, 0) },
	-- A23-119 / A23-123 (게임성 개발 2, 2026-10-11, docs/design/new_zones_monsters_2026-10-11.md): the two new fields that
	-- take the hidden Halloween fields' place, Season = "NewZones" (Config.NewZones.Enabled, false as shipped). They are
	-- NOT in Config.ZoneOrder while the switch is off (Config.NewZonesApply adds them when it is on), so ZoneAt, the maps
	-- (MiniMap / WorldMap / MapBuilder / tools/preview_map.lua) and the v2 layout see nothing new. TODO (world side): the
	-- real rects + land pieces; until then a PLACEHOLDER rect east of Config.Map.Bounds (x > 1840) that overlaps no zone.
	-- No level gate (like the Halloween fields): Coral Coast Lv 8-11, Crystal Cave Woods Lv 14-21 recommended.
	CoralCoast = { Id = "CoralCoast", Name = "Coral Coast", Center = Vector3.new(2300, 0, 300), Size = Vector3.new(200, 0, 180),
		MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = "NewZones",
		FloorColor = Color3.fromRGB(235, 215, 160), FloorMaterial = Enum.Material.Sand, Spawn = Vector3.new(2220, 0, 300) },
	CrystalWoods = { Id = "CrystalWoods", Name = "Crystal Cave Woods", Center = Vector3.new(2300, 0, -300), Size = Vector3.new(230, 0, 190),
		MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = "NewZones",
		FloorColor = Color3.fromRGB(90, 150, 140), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(2210, 0, -300) },
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

-- A23-90: the zone's PvP area (zone.PvPArea) that holds pos, else nil
function Config.PvPAreaAt(pos, zone)
	zone = zone or Config.ZoneAt(pos)
	local a = zone and zone.PvPArea
	if type(a) ~= "table" then return nil end
	if math.abs(pos.X - a.Center.X) <= a.Size.X / 2 and math.abs(pos.Z - a.Center.Z) <= a.Size.Z / 2 then return a end
	return nil
end

-- A23-90: true where players may fight players: a PvP zone, or the PvP area inside a zone (the ruins' Crown Pit)
function Config.PvPAt(pos, zone)
	zone = zone or Config.ZoneAt(pos)
	return zone ~= nil and (zone.PvP == true or Config.PvPAreaAt(pos, zone) ~= nil)
end

-- A23-90: a zone with PvP anywhere in it (a PvP zone, or one with a PvP area): maps, travel info, gates
function Config.ZoneHasPvP(zone)
	return type(zone) == "table" and (zone.PvP == true or type(zone.PvPArea) == "table")
end

function Config.HomeZoneId(factionId)
	if factionId == "Halo" then return "HaloTown" end
	if factionId == "Horns" then return "HornsTown" end
	return "Crossroads" -- "Neutral" (addendum A6) and "None"
end

-- the walking ground (A11-R1 + docs/design/halo_restart_2026-10-11.md '걷는 바닥', 2026-10-11): ground raycasts see
-- ONLY Terrain, workspace.Map.Ground, the bridges (Map.Decor children "Bridge_*"; in a Decor "*Props" kit folder the
-- cells / their models whose name has "Bridge") and every instance tagged Tag (CollectionService) - a building's floor,
-- a yard or later an inside built from parts. Other decor parts are never ground. Shared.Ground caches the raycast
-- params (rebuilt on a tag change, a new Map, or every Refresh s for a late MapBuilder pass). 게임성 검수 10/13
-- (e27_stairs: the Light Mage's staff 2..3.3 studs over the Halo town's stairs - Halo_Stairs is a kit piece, the rays
-- went through it): a kit piece whose name carries one of KitWalk is walking ground like the bridges; a floor or a deck
-- is still tagged WalkGround by the world builder (an untagged "Floor" stays decor)
Config.Ground = { Tag = "WalkGround", Refresh = 5, KitWalk = { "Bridge", "Stairs", "Steps", "Ramp" } }

-- the instances a ground raycast includes (pure): terrain, then the map's Ground, its bridges, then `tagged` (the
-- instances carrying Config.Ground.Tag, in any order; nil = none). map = workspace.Map or nil
function Config.GroundRoots(terrain, map, tagged)
	local list = {}
	local function walkPiece(name) -- a kit piece people walk on (Config.Ground.KitWalk in its name)
		for _, w in Config.Ground.KitWalk do
			if string.find(name, w, 1, true) then return true end
		end
		return false
	end
	if terrain then table.insert(list, terrain) end
	if map then
		local ground = map:FindFirstChild("Ground")
		if ground then table.insert(list, ground) end
		local decor = map:FindFirstChild("Decor")
		if decor then
			for _, d in decor:GetChildren() do
				if string.sub(d.Name, 1, 7) == "Bridge_" then
					table.insert(list, d)
				elseif string.sub(d.Name, -5) == "Props" then
					-- 검수 10/10: the world kits' bridges (Decor.HaloProps.Cell_*.Halo_ArchBridge_*); 10/13 their stairs too
					for _, cell in d:GetChildren() do
						if walkPiece(cell.Name) then
							table.insert(list, cell)
						else
							for _, m in cell:GetChildren() do
								if walkPiece(m.Name) then table.insert(list, m) end
							end
						end
					end
				end
			end
		end
	end
	local seen = {}
	for _, inst in list do seen[inst] = true end
	for _, inst in type(tagged) == "table" and tagged or {} do
		if not seen[inst] then
			seen[inst] = true
			table.insert(list, inst)
		end
	end
	return list
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

-- zone_check_halo_2026-10-10 #11 / #62 / #63 (검수 2026-10-10): the water rescue (ZoneService waterTick). A live player whose
-- root stays in Terrain water for Seconds in a row inside a town zone (Zones[*].Town) or within Margin studs of a town rect
-- is moved to the nearest dry land (rings of downward rays: nearest ring first, then the lowest climb); nothing found ->
-- the home spawn (an Active kaiju: Crossroads). No invisible edge walls (too many parts).
Config.WaterRescue = {
	Enabled = true,
	Seconds = 8, -- in water this long in a row (counted from the first wet sample)
	Margin = 40, -- studs around each town rect: the Halo canals + sea strip, the Crossroads river and sea edges
	CheckEvery = 0.5, -- s between two water samples of one player (one 3-voxel Terrain read; the zone loop runs every 0.2 s)
	RootSlack = 1, -- in water = the Terrain water surface is at most this far below the root (a swimmer floats at the surface)
	DryReset = 1.5, -- a dry spell shorter than this (a swim jump at a canal wall) keeps the count
	Rings = { 6, 10, 16, 24, 34, 46, 60, 80 }, -- search radii (studs), nearest first
	RaysPerRing = 12,
	RayTop = 60, -- rays start this far above the root / water (Halo tiers and wings reach Y 33; tall props fail the body box)
	DryAbove = 0.5, -- a landing spot is at least this far above the water surface by the player ...
	MaxRise = 42, -- ... and at most this far (Halo top tier / wings Y 33 + the 1.2 to the water + mounds; review 10/10)
	MaxSlope = 40, -- degrees; players walk up to 46 (PlayerService MAX_SLOPE_ANGLE)
	Lift = 4, -- the root is put at least this far above the landing spot (like a zone spawn)
	AvoidMaterials = { "CrackedLava" }, -- Horns Den's painted lava strips are floor, never a landing spot
	Toast = false, -- Text.WaterRescue after the move (false = silent); A23-130: off, the shore says it
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
-- GlobalCap 72 -> 76 (A23-87, 2026-10-09): room for the meadow's hidden Flower Slimes (2, at most 4 with players); the
-- woods' and the ruins' new kinds take base slots instead
Config.MonsterDensity ={ ExtraPerPlayer = 2, MaxZoneMult = 2, GlobalCap = 76, ReevalInterval = 5 }

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
-- (the NewZones families sit on the level ladder: Coral Coast after the meadow, Crystal Cave Woods after the woods)
Config.MonsterTypeOrder = { "Slime", "FlowerSlime", "PumpkinSlime", "BigSlime", "SlimeKing", "PumpkinKing",
	"CoralCrab", "Jellyfish", "HermitCrab", "Goblin",
	"SlingshotGoblin", "BatGoblin", "GoblinBrute", "GhostMinion", "LittleGhost", "GhostKing",
	"CrystalLizard", "CaveBat", "GlowMushroom", "CrystalGolem", "Skeleton", "SkeletonArcher",
	"SkeletonKnight", "CaptainClatter" }
-- Name = full name (nametag, lore); Short = short name for quest / HUD lines (optional: use `def.Short or def.Name`)
-- Season = Config[Season].Enabled gates the kind; Takes = { [baseKind] = n } slots of a base kind it replaces while on;
-- QuestAs = the kind quests count it as (Config.QuestKind); Float = studs the client hovers it above the floor (no
-- legs: slow bob, no waddle); Boss = event monster (never golden, never respawns, ContributorWindow override).
-- 검수 2026-10-09 (system review ④): a monster's name tag colour says how risky it is for me. The band is 게임성 개발 2's
-- Config.MonsterDanger(myLevel, monsterLevel) -> "Weak" | "Even" | "Strong" | "Deadly" and the level its "Level" attribute
-- / Config.MonsterLevel(kind) (dev2-mlevel); this table only holds the colours (MonsterLabels). Until dev2-mlevel is in
-- main, Tier / LevelOf use Fallback (the same bands) - DELETE Fallback and the two fallback branches at that merge.
Config.MonsterDangerLook = {
	Colors = { Weak = Color3.fromRGB(165, 165, 170), Even = Color3.fromRGB(255, 255, 255),
		Strong = Color3.fromRGB(255, 220, 70), Deadly = Color3.fromRGB(255, 80, 70) },
	Fallback = { Weak = -6, Strong = 3, Deadly = 8, Boss = 5 }, -- DELETE when dev2-mlevel is merged
}
function Config.MonsterDangerLook.LevelOf(kind, attrLevel)
	local lv = tonumber(attrLevel)
	if lv and lv == lv and lv > 0 then return math.floor(lv) end
	if type(Config.MonsterLevel) == "function" then return Config.MonsterLevel(kind) end
	-- fallback until dev2-mlevel (DELETE then): the zone's MinLevel (+ Boss for a boss)
	local def = type(Config.MonsterTypes) == "table" and Config.MonsterTypes[kind] or nil
	local zone = type(def) == "table" and type(Config.Zones) == "table" and Config.Zones[def.Zone] or nil
	local base = type(zone) == "table" and tonumber(zone.MinLevel) or nil
	if not base then return nil end
	return math.floor(base) + ((def.Boss == true) and Config.MonsterDangerLook.Fallback.Boss or 0)
end
function Config.MonsterDangerLook.Tier(myLevel, monsterLevel)
	if type(Config.MonsterDanger) == "function" then return Config.MonsterDanger(myLevel, monsterLevel) end
	-- fallback until dev2-mlevel (DELETE then): dev2's rule with the same bands
	local B = Config.MonsterDangerLook.Fallback
	local d = (tonumber(monsterLevel) or 1) - (tonumber(myLevel) or 1)
	if d >= B.Deadly then return "Deadly" end
	if d >= B.Strong then return "Strong" end
	if d <= B.Weak then return "Weak" end
	return "Even"
end

Config.MonsterTypes = {
	Slime = { Name = "Shard Slime", Short = "Slime", Zone = "SlimeMeadow", Count = 12, HP = 10, Damage = 2, XP = 5, Gold = 3, Speed = 10, Shape = "Slime", Scale = 1.0, Color = Color3.fromRGB(95, 205, 95) },
	-- A23-84 (user 2026-10-08): the slime family - the green Shard Slime is the youngest, the Slime Prince (this id, the
	-- old "King Slime": its quests, the first 70% scroll and the dailies stay) the eldest, the King Slime the dad
	BigSlime = { Name = "Slime Prince", Short = "Slime Prince", Zone = "SlimeMeadow", Count = 4, HP = 40, Damage = 4, XP = 18, Gold = 10, Speed = 9, Shape = "Slime", Scale = 1.8, Color = Color3.fromRGB(70, 160, 235) },
	-- A23-87: 3 of the 10 woods goblin slots are Slingshot Goblins, 3 of the 8 ruins skeleton slots Skeleton Archers (the
	-- zone totals stay); the meadow keeps its 12 green slimes (the first 10 minutes) and adds 2 hidden Flower Slimes
	-- (Config.MonsterDensity.GlobalCap + 4 for them)
	Goblin = { Name = "Shard Thief Goblin", Short = "Goblin", Zone = "GoblinWoods", Count = 7, HP = 90, Damage = 6, XP = 28, Gold = 16, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(110, 170, 70) },
	GoblinBrute = { Name = "Goblin Brute", Short = "Goblin Brute", Zone = "GoblinWoods", Count = 4, HP = 260, Damage = 12, XP = 70, Gold = 40, Speed = 10, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(80, 120, 50) },
	Skeleton = { Name = "Old Kingdom Skeleton", Short = "Skeleton", Zone = "SkeletonRuins", Count = 5, HP = 450, Damage = 14, XP = 65, Gold = 65, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(235, 235, 220) },
	-- A23-87 (user 2026-10-09 "넣자!", 검수 plan OK): three new year-round kinds, each on its family's model and moves
	-- (ModelFrom / AnimFrom) in its own colour until its own art. Ranged = { Range (shoots within), Stand (keeps this far
	-- from its target), Windup (s, telegraphed), Speed (studs/s: slow, kid-dodgeable), Radius (studs around the landing
	-- point that still hit: big, seen on a phone), Cooldown (s) } (MonsterService MOB3: the shot flies to where the
	-- target stood at the release; stepping aside dodges it; only the target can be hit). Damage stays under the zone's
	-- melee kind. Ambush = { Material (terrain under its spawn: the meadow flower patches), Tries, Pop (studs) }: hidden
	-- until a player it may chase comes within Pop or it is hit. PartnerOf = spawns beside a living one of that kind
	-- that has no partner of this kind yet (else anywhere in the zone).
	FlowerSlime = { Name = "Flower Slime", Short = "Flower Slime", Zone = "SlimeMeadow", Count = 2, HP = 14, Damage = 2,
		XP = 7, Gold = 4, Speed = 10, Shape = "Slime", Scale = 0.9, Color = Color3.fromRGB(165, 105, 230), ModelFrom = "Slime", -- A23-92 purple
		QuestAs = "Slime", Ambush = { Material = "Salt", Tries = 12, Pop = 8 } },
	SlingshotGoblin = { Name = "Slingshot Goblin", Short = "Slingshot Goblin", Zone = "GoblinWoods", Count = 3, HP = 70,
		Damage = 4, XP = 26, Gold = 15, Speed = 11, Shape = "Humanoid", Scale = 0.9, Color = Color3.fromRGB(150, 175, 70),
		ModelFrom = "Goblin", AnimFrom = "Goblin", QuestAs = "Goblin",
		Ranged = { Range = 22, Stand = 17, Windup = 0.9, Speed = 18, Radius = 3, Cooldown = 3 }, WindupTime = 0.9 },
	SkeletonArcher = { Name = "Skeleton Archer", Short = "Skeleton Archer", Zone = "SkeletonRuins", Count = 3, HP = 380,
		Damage = 10, XP = 60, Gold = 60, Speed = 11, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(215, 205, 170),
		ModelFrom = "Skeleton", AnimFrom = "Skeleton", QuestAs = "Skeleton", PartnerOf = "SkeletonKnight",
		Ranged = { Range = 26, Stand = 20, Windup = 1, Speed = 20, Radius = 3, Cooldown = 3.2 }, WindupTime = 1 },
	SkeletonKnight = { Name = "Skeleton Knight", Short = "Skeleton Knight", Zone = "SkeletonRuins", Count = 4, HP = 1300, Damage = 24, XP = 170, Gold = 170, Speed = 11, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(120, 120, 140) },
	-- Captain Clatter (content_beyond_10min_2026-10-08 J, 검수 OK 2026-10-09): the ruins' field boss (FieldBossService:
	-- every 20 min, stays 6 min), 300 years on duty with nobody to take his shift. The Skeleton Knight's model and moves x
	-- Scale 2.2 until his own (ModelFrom / AnimFrom). A23-113 ⑦: HP 20000 = one hunter's fight, about 2 min (116 s) for a
	-- Lv25 hunter with the T4 weapon a woods hunter brings (Goblin drops / the Lv12 commission; swings + skill Q MP20 / 3 s
	-- x6, 75% uptime: 172.9 DPS averaged over the 3 classes x 3 sides; 검수 bosshp_verify 2026-10-11: T3+0 is the weakest
	-- loadout, 9000 let a normal ruins hunter solo him in 20-80 s); more hunters add HP (Config.FieldBosses.Crowd). Lv30+
	-- T5 / T6 hunters still solo him fast (a share is at most 1). XP / Gold = 5 min of Lv25 hunting
	-- (3,900 each), paid per eligible contributor (A23-27: 3 own hits + the damage share)
	CaptainClatter = { Name = "Captain Clatter", Short = "Captain Clatter", Zone = "SkeletonRuins", Count = 0, Boss = true,
		-- 검수 2026-10-09: paid only with 2% of his HP dealt; 3 hits but less = MinorShare (15%) of XP / gold, nothing else
		ContributorWindow = 180, RewardMinHits = 3, RewardMinDamageFrac = 0.02, MinorShare = 0.15, ModelFrom = "SkeletonKnight",
		AnimFrom = "SkeletonKnight", HP = 20000, Damage = 30, XP = 3900, Gold = 3900, Speed = 8, Shape = "Humanoid",
		Scale = 2.2, Color = Color3.fromRGB(150, 140, 120) },
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
	-- the King Slime (A23-84 the slime family's dad; docs/design/king_slime_split_2026-10-08.md §3, 검수 OK 2026-10-08):
	-- a boss of the meadow (FieldBossService: one on the server, every 8 min at the King Slime Hill shrine, 5 min stay),
	-- never in the regular pool. Its own model comes later (image gen 2 -> Tripo): until then the Slime Prince's crowned
	-- cube x Scale (2.5 = the Pumpkin King's body: 3.0 put the body past the attack ring, test_monster_spacing).
	-- A23-113 ⑦: HP 2600 = one hunter's fight, about 2 min (118 s) for a Lv 5-8 hunter with the tier 2 weapon the first
	-- mission's 150 gold buys (swings + skill Q, 75% uptime: 22.1 DPS averaged over the 3 classes x 3 sides; 검수
	-- bosshp_verify 2026-10-11: T1 is gone by Lv5; was 2500); T1 only ~220 s, T3 ~46 s; more hunters add HP
	-- (Config.FieldBosses.Crowd: three = about 80 s). The finisher card is its (Config.Finisher.Kinds)
	SlimeKing = { Name = "King Slime", Short = "King Slime", Zone = "SlimeMeadow", Count = 0, Boss = true,
		ContributorWindow = 120, RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8, ModelFrom = "BigSlime",
		-- A23-92 (user 2026-10-09 "조금 더 크면"): Scale 2.5 -> 3.2; players reach its body's edge (MonsterService.HitPad);
		-- pink body (its texture: image gen 2 -> image dev; until then this Color tints the borrowed model)
		HP = 2600, Damage = 6, XP = 120, Gold = 60, Speed = 7, Shape = "Slime", Scale = 3.2, Color = Color3.fromRGB(255, 140, 190) },
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
	-- A23-119 / A23-123 new fields (게임성 개발 2, 2026-10-11; docs/design/new_zones_monsters_2026-10-11.md): Season =
	-- "NewZones" = inert while Config.NewZones.Enabled is false (no spawn, no drop list row, Config.MonsterActive). No
	-- slimes (A23-123), no ranged kind (A23-87 switch), no boss. Numbers sit between the neighbours of the same level
	-- (plain kinds between Slime Lv2 / Goblin Lv12 / Skeleton Lv26, the big ones between Slime Prince Lv5 / Goblin
	-- Brute Lv18 / Skeleton Knight Lv30). No 3D yet: each borrows an existing model (ModelFrom) in its own tint
	-- (TODO: own Tripo models, A23-96 / A23-125). Add-on kinds (no Takes): outside MonsterDensity.GlobalCap like the
	-- Halloween fields' kinds (Config.MonsterOutsideCap).
	-- Coral Coast (Lv 8-11): crab = the plain melee kind, jellyfish floats, hermit crab = the tougher one (counted as a
	-- crab by quests)
	CoralCrab = { Name = "Coral Crab", Short = "Coral Crab", Zone = "CoralCoast", Count = 8, Season = "NewZones",
		HP = 60, Damage = 4, XP = 20, Gold = 11, Speed = 11, Shape = "Humanoid", Scale = 0.9, Color = Color3.fromRGB(240, 110, 90),
		ModelFrom = "Goblin", AnimFrom = "Goblin" },
	Jellyfish = { Name = "Jellyfish", Short = "Jellyfish", Zone = "CoralCoast", Count = 5, Season = "NewZones",
		HP = 65, Damage = 5, XP = 22, Gold = 12, Speed = 9, Shape = "Humanoid", Scale = 0.9, Color = Color3.fromRGB(255, 170, 225),
		ModelFrom = "LittleGhost", Float = 1.5 },
	HermitCrab = { Name = "Hermit Crab", Short = "Hermit Crab", Zone = "CoralCoast", Count = 3, Season = "NewZones", QuestAs = "CoralCrab",
		HP = 120, Damage = 7, XP = 36, Gold = 20, Speed = 9, Shape = "Humanoid", Scale = 1.3, Color = Color3.fromRGB(210, 160, 110),
		ModelFrom = "GoblinBrute", AnimFrom = "GoblinBrute" },
	-- Crystal Cave Woods (Lv 14-21): lizards small, quick and many; the cave bat flies (Float); the glowing mushroom is a
	-- slow tank; the crystal golem is the big one (regular pool, few, NOT a field boss). The crystal hedgehog is the
	-- field's story-quest pet, not a monster (TODO, like the meadow's Baby Slime PET-4)
	CrystalLizard = { Name = "Crystal Lizard", Short = "Crystal Lizard", Zone = "CrystalWoods", Count = 9, Season = "NewZones",
		HP = 95, Damage = 6, XP = 30, Gold = 17, Speed = 14, Shape = "Humanoid", Scale = 0.8, Color = Color3.fromRGB(110, 210, 230),
		ModelFrom = "Goblin", AnimFrom = "Goblin" },
	CaveBat = { Name = "Cave Bat", Short = "Cave Bat", Zone = "CrystalWoods", Count = 5, Season = "NewZones",
		HP = 110, Damage = 7, XP = 34, Gold = 19, Speed = 13, Shape = "Humanoid", Scale = 0.8, Color = Color3.fromRGB(95, 80, 140),
		ModelFrom = "LittleGhost", Float = 2 },
	-- "Glowing" (not "Glow"): the Warrior's Z skill is "Glow Lasso" and skill names share no word with a monster
	GlowMushroom = { Name = "Glowing Mushroom", Short = "Mushroom", Zone = "CrystalWoods", Count = 4, Season = "NewZones",
		HP = 200, Damage = 8, XP = 50, Gold = 28, Speed = 8, Shape = "Humanoid", Scale = 1.2, Color = Color3.fromRGB(180, 140, 255),
		ModelFrom = "GoblinBrute", AnimFrom = "GoblinBrute" },
	CrystalGolem = { Name = "Crystal Golem", Short = "Crystal Golem", Zone = "CrystalWoods", Count = 2, Season = "NewZones",
		HP = 480, Damage = 15, XP = 110, Gold = 75, Speed = 8, Shape = "Humanoid", Scale = 1.9, Color = Color3.fromRGB(140, 200, 255),
		ModelFrom = "SkeletonKnight", AnimFrom = "SkeletonKnight" },
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
	BubbleFamily = { Slime = "Slime", FlowerSlime = "Slime", BigSlime = "Slime", SlimeKing = "Slime", PumpkinSlime = "Pumpkin", PumpkinKing = "Pumpkin",
		Goblin = "Goblin", SlingshotGoblin = "Goblin", BatGoblin = "Goblin", GoblinBrute = "Goblin", Skeleton = "Skeleton", SkeletonArcher = "Skeleton", SkeletonKnight = "Skeleton", CaptainClatter = "Skeleton",
		GhostMinion = "Ghost", LittleGhost = "Ghost", GhostKing = "Ghost",
		-- NewZones (A23-123): no bubble art yet (the keys below are not in Config.UIArt) = the round code bubble
		CrystalLizard = "Crystal", CaveBat = "Crystal", GlowMushroom = "Crystal", CrystalGolem = "Crystal",
		CoralCrab = "Coral", Jellyfish = "Coral", HermitCrab = "Coral" },
	BubbleArt = { Slime = "BarkBubbleSlime", Pumpkin = "BarkBubblePumpkinSlime", Goblin = "BarkBubbleGoblin",
		Skeleton = "BarkBubbleSkeleton", Ghost = "BarkBubbleGhostMinion",
		Crystal = "BarkBubbleCrystalLizard", Coral = "BarkBubbleCoralCrab" },
	LowAt = 0.3, -- HP fraction for Low (once per life)
	IdleEvery = 10, -- s between Idle rolls (no target, a player within IdleNear)
	IdleNear = 40,
	Chance = { Spot = 0.5, Hit = 0.2, Low = 1, Idle = 0.15 },
	Priority = { "Low", "Spot", "Hit", "Idle" }, -- same moment: only the first one speaks
	-- A23-74: sound words (Spot = it sees you, Hit = it is hit, Low = HP below LowAt, Idle = just hanging around)
	Lines = {
		FlowerSlime = { -- A23-87: hides in the flowers, pops out giggling
			Spot = { "Peekaboo!", "Surprise!" },
			Hit = { "Petal-ow!", "Bloom-boing!" },
			Low = { "Wilting…", "Petals off…" },
			Idle = { "Shh… hiding.", "Sniff sniff~" },
		},
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
		SlimeKing = { -- A23-84 the slime family's dad (A23-85: he raises the two kids alone): scary but playful
			Spot = { "MY KIDS?!", "Dad's here!" },
			Hit = { "OOF! BLUB!", "Daddy BOING!" },
			Low = { "Dad nap…", "Ugh… kids…" },
			Idle = { "Big hug~", "Hmm. Kids?" },
		},
		BigSlime = { -- Slime Prince (A23-84 the eldest; the old King Slime): big and royal
			Spot = { "BLOOP!", "Bow! Blub!" },
			Hit = { "SPLOOSH!", "Royal BOING!" },
			Low = { "Royal nap…", "Bloop… zzz" },
			Idle = { "Ahem. BLOOP.", "Big blub~" },
		},
		SlingshotGoblin = { -- A23-87: the first one that shoots from afar
			Spot = { "Ready… aim!", "Pew pew!" },
			Hit = { "Missed me!", "Ow! Pebble!" },
			Low = { "No rocks!", "Run away!" },
			Idle = { "Pebble time~", "Plink." },
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
		SkeletonArcher = { -- A23-87: the knight's partner, shooting from the back
			Spot = { "Target!", "Draw!" },
			Hit = { "Clink!", "Bad shot!" },
			Low = { "No arrows…", "Retreat!" },
			Idle = { "Aim… wait.", "Twang~" },
		},
		Skeleton = { -- a bony guard who lost track of the days
			Spot = { "Rattle!", "Clack clack!" },
			Hit = { "Clank!", "Clack!" },
			Low = { "Clatter…" },
			Idle = { "Rattle~", "Tuesday?" },
		},
		CaptainClatter = { -- J: the captain nobody relieved (300 years on duty)
			Spot = { "HALT!!", "Who's next?" },
			Hit = { "CLATTER!", "Bones! Ow!" },
			Low = { "Nap time…", "Off duty?" },
			Idle = { "300 years…", "Still here." },
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
		-- NewZones (A23-123, 2026-10-11): Coral Coast
		CoralCrab = { -- a busy little crab
			Spot = { "Snip snip!", "Pinch time!" },
			Hit = { "Ow, claw!", "Bubble-ow!" },
			Low = { "Sidestep!" },
			Idle = { "Snip~", "Sand nap~" },
		},
		Jellyfish = { -- a wobbly, floaty jelly of the sea
			Spot = { "Bloop-bloop!", "Wiggle!" },
			Hit = { "Zap-ow!", "Jiggle-ow!" },
			Low = { "Drifting…" },
			Idle = { "Float~", "Wibble~" },
		},
		HermitCrab = { -- loves its shell house
			Spot = { "My shell!", "Knock knock!" },
			Hit = { "Thunk!", "Shell bonk!" },
			Low = { "Hide time!" },
			Idle = { "Cozy shell~", "Peek~" },
		},
		-- NewZones: Crystal Cave Woods
		CrystalLizard = { -- quick and sparkly
			Spot = { "Skitter!", "Sparkle!" },
			Hit = { "Tink!", "Chip-ow!" },
			Low = { "Zip away!" },
			Idle = { "Skitter~", "Lick lick~" },
		},
		CaveBat = { -- a sleepy cave bat
			Spot = { "Eep-eep!", "Squeak!" },
			Hit = { "Squeak-ow!", "Ow, wings!" },
			Low = { "Flutter…" },
			Idle = { "Hang… zzz", "Squeak~" },
		},
		GlowMushroom = { -- a chubby, sleepy glow
			Spot = { "Pop-pop!", "Spore-y?" },
			Hit = { "Squash-ow!", "Puff!" },
			Low = { "Dim glow…" },
			Idle = { "Glow glow~", "Mush mush~" },
		},
		CrystalGolem = { -- big, slow, a little grumpy
			Spot = { "RUMBLE!", "Who taps?" },
			Hit = { "CRACK? No.", "BONK!" },
			Low = { "Crumble…" },
			Idle = { "Rumble~", "Big yawn." },
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
	-- A23-119 (user 2026-10-11, beta moved to 2026-12-01): the Pumpkin Patch and the Haunted Hollow are HIDDEN. false = the season is off
	-- for everyone (Config.SeasonOn): both zones leave Config.ZoneAt, no pumpkin / bat / ghost kind spawns (their slots go back to the base
	-- kinds), no king, no road sign, no HUD line, no map drawing (WorldMap / MiniMap skip Season lands, roads and zones), no candy bag
	-- (LostFound), no King Diary / candy jar row (QuestBook), no news line. No code and no data is deleted: true brings it all back (a
	-- new EndsAt too). The live switch Halloween can only turn it off further. A new zone with new monsters is to take the place.
	Enabled = false,
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

-- A23-119 / A23-123 (게임성 개발 2, 2026-10-11; docs/design/new_zones_monsters_2026-10-11.md): the two new fields that
-- replace the hidden Halloween fields - Coral Coast (CoralCrab / Jellyfish / HermitCrab) and Crystal Cave Woods
-- (CrystalLizard / CaveBat / GlowMushroom / CrystalGolem). One switch, the Halloween season's own path: every new zone and
-- kind carries Season = "NewZones", so Config.SeasonOn("NewZones") = this Enabled gates them (Config.MonsterActive /
-- EffectiveMonsterCounts / MonsterTargets = 0, Panels' drop list, the client maps skip a season that is off).
-- false (as shipped) = nothing changes in the running game. The zones also stay out of Config.ZoneOrder until it is on
-- (Config.NewZonesApply), so ZoneAt, MapBuilder's floor markers and the v2 map layout are untouched.
-- Before turning it on (TODO): the real zone rects + land pieces (world side; the Config.Zones rects are placeholders east
-- of Config.Map.Bounds), the 3D models, the minimap / zone art, music, bubble art, item icons.
Config.NewZones = {
	Enabled = false,
	ZoneIds = { "CoralCoast", "CrystalWoods" }, -- appended to Config.ZoneOrder (in this order) while Enabled
}

-- puts the new zones at the end of Config.ZoneOrder (once each) while their season is on; true when they are in.
-- Runs once below when this module loads; a test that turns Enabled on after loading calls it itself.
function Config.NewZonesApply()
	if not Config.SeasonOn("NewZones") then return false end
	for _, id in Config.NewZones.ZoneIds do
		if type(Config.Zones[id]) == "table" and table.find(Config.ZoneOrder, id) == nil then
			table.insert(Config.ZoneOrder, id)
		end
	end
	return true
end
Config.NewZonesApply()

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
		IronDrop = "King Slime", -- A23-127 (plan 10/13): the iron weapon is the King Slime's drop (Tutorial.Text.NextIronDrop)
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
	-- first sees it, also right after a rejoin) is paid automatically with Text.Claimed. [받기] still comes first.
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
			Lines = { -- page 1 = the mission card (검수 2026-10-07), page 2 = the catchphrase; two pages only (A23-99: less hand-holding)
				"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.", -- A23-74: weapon first
				"Hallie here! Now you know my name. Welcome to the Knights!",
			},
		},
		Horns = {
			Name = "Magpie", Title = "Horn Legion Guide",
			Lines = {
				"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.", -- A23-74: weapon first
				"Finders keepers! HA! You're with us now. I'm Magpie.",
			},
		},
		Neutral = {
			Name = "Kit", Title = "Guild Guide",
			Lines = {
				"First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.", -- A23-74: weapon first
				"Fix first. Talk later. I'm Kit. Welcome to the Guild!",
			},
		},
	},
	Text = {
		FirstFight = "Pick a class, then get your first mission from the Guide.",
		-- A23-40: the guide is met by tapping this quest line (the menu moved to the top-right fold)
		-- 3rd idea round #3: %s = the faction guide's name (Welcome[faction].Name), there is no guide NPC to look for
		Welcome = "Tap here: first quest from %s", WelcomeEn = "Tap here: first quest from %s",
		Travel = "Step on the glowing pad to go to Squishy Meadow", -- A23-88
		-- A23-130 (user 2026-10-11): no line when the hunt starts or reaches 5/5 (QuestStart / QuestReady removed)
		-- A23-74: the Forge step (3): its row, and Otto's line when he hands over the first weapon (then LootService's
		-- "You got your first weapon" line with the power change)
		Forge = "Go to Otto's Forge in the Crossroads", -- A23-88: walking; Otto hands over the first weapon (zone_check_halo #44: the Forge is outside the town)
		ForgeGift = "Otto: Clang, clang… done. Here's your first weapon! The Squishy Meadow is next.",
		-- A23-130 (user 2026-10-11): the claim line is the reward only, for a [Claim] and the F10-4 safety net alike
		-- (the old thank-you / next-weapon / "check the gear" variants are gone)
		Claimed = "+%s gold",
		-- the row after the claim while still bare-handed (no story row yet; A23-74 gives the weapon before that)
		VisitBlacksmith = "Get your first weapon · Crossroads Forge",
		VisitBlacksmithEn = "Get your first weapon · Crossroads Forge",
		-- the VisitBlacksmithArmed row is for a save that owns the first weapon (no first-weapon promise)
		VisitBlacksmithArmed = "Check the weapons · Crossroads Forge",
		VisitBlacksmithArmedEn = "Check the weapons · Crossroads Forge",
		-- A23-3: next goal after the blacksmith visit (computed from existing state only; no new reward)
		NextIronLevel = "Next goal · Iron weapon at Lv%d (now Lv%d)",
		-- A23-71 D6 / S16: the first skill comes at the iron weapon's level (Skills.Unlock.Q = Weapons[3].MinLevel), one line
		NextSkillIron = "Next goal · Lv%d: first skill + Iron weapon (now Lv%d)",
		NextIronGold = "Next goal · Iron weapon for %s gold (you have %s)",
		-- A23-127 (plan 10/13 §1-A #2): while the Forge sells no weapon (WeaponShop.Buy = false) the iron goal is a drop
		-- (QuestService GoalKind "IronDrop", 게임성 개발 2): the first King Slime always drops it. No number to format
		NextIronDrop = "Next goal · Beat a King Slime for an Iron weapon",
		NextZone = "Next goal · Lv%d opens %s (now Lv%d)",
		NextSkill = "Next goal · New skill at Lv%d (now Lv%d)", -- SKL-3 (skill_kit §2): the next skill to learn
		-- A23-86 F (content_beyond_10min): the ladder when no story row is pinned (after the last chapter, after a rebirth)
		NextRebirth = "Next goal · Lv%d: Rebirth and start again (now Lv%d)",
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
	-- zone_check_halo #19: true = every active sub is sent, the ones past MaxSubs marked More = true (the HUD must draw only the
	-- rows without More; the quest window lists all). On since 2026-10-10 (game dev 1's HUD skips More rows, b9a0d16b / cce87d8d:
	-- the quest window's In progress lists them, a More row's [Claim] goes straight to ClaimQuest).
	SendAllSubs = true,
	-- map v2: the slime pond in the meadow's south-west (kit_meadow M_Pond, 50 wide)
	Landmarks = { SlimePond = Vector3.new(290, 0, 150), Fountain = Vector3.new(0, 0, 0) },
	Speakers = { Shard = "Crown Shard", Fountain = "Fountain Shard", Smith = "Otto", Guild = "Kit", Potion = "Fizzby", -- ⑪
		Bright = "Bright", Smokey = "Rose", Tiny = "Tiny", Kids = "Bright & Rose", -- A23-46 town NPCs, A23-55 kids
		Pip = "Pip", Dibs = "Dibs", Grabbo = "Grabbo", -- story_depth §4 goblins (beta: names only, no models)
		Gleam = "Sir Gleam", Rex = "Rascal Rex", -- story_depth §4 (beta: names only)
		Scroll = "Terms of Fate", Notice = "Notice", Goose = "Golden Goose" }, -- the Easter eggs' speakers (no portrait: the card shows no face)
	-- 검수 2026-10-07: the Story window shows the speaker's face (a Config.UIArt.Parts key) in the PortraitFrame left of
	-- the words. Halo / Horns / Guild = no Speaker, my faction's guide; the crown shard and the fountain shard share
	-- PTR_CrownShard (94207f5). A speaker missing here or whose art id is empty (Kids, the goblins, Gleam, Rex) gets no
	-- portrait slot.
	Portraits = { Smith = "PortraitMerchantC", Potion = "PortraitPotionMerchant", Bright = "PTR_TownBright",
		Smokey = "PTR_TownSmokey", Tiny = "PTR_TownTiny", Guild = "PortraitGuideArtisan", Halo = "PortraitGuideHalo",
		Horns = "PortraitGuideHorns", Shard = "PTR_CrownShard", Fountain = "PTR_CrownShard" },
	NpcTag = "StoryNpc",
	NpcRange = 16, -- studs between the player and a quest NPC for Talk / Choose / Open
	-- 빛 마을 점검 #2: a workspace instance with this tag and the attribute Spot = a Landmarks key moves that spot to it
	-- (StoryQuestService; e.g. the hero statue pair's centre, Spot = "HeroStatue"). Without one the spot below stays.
	LandmarkTag = "StoryLandmark",
	Badge = { Main = "Main", Sub = "Side" },
	Main = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7",
		"M3_1", "M3_2", "M3_3", "M3_4", "M3_6", "M3_7", "M3_8" }, -- A23-86: M3_5 (graduation) is a side line now
	-- story_depth E0: an old save that reaches the story at Level >= Level skips the main chapters <= UpTo (once)
	SkipChapters = { { Level = 10, UpTo = 2 }, { Level = 25, UpTo = 3, Subs = { "M3_5" } } }, -- A23-86: M3_5 is a sub now
	-- user 2026-10-06: basic weapons are simply bought at the blacksmith (no "buy the iron weapon" quest); rare gear
	-- comes from quests, the crafter and monster drops
	Subs = { "S0", "Lunch1", "Pet1", "S1", "S2", "S3", "S4", "N1", "N2", "H1", "R1", "N3", "Pip1", -- quest_volume §3-2 (A23-56) below:
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
		Unlocked = "Auto Battle unlocked!", -- A23-130: the Auto button shows itself, the S4 row gives the key
		Good = "Honor +%d",
		Evil = "Infamy +%d",
		Recorded = "Your choice is saved.",
		-- shown under the two choice buttons on the last page (what a pick does, before picking)
		-- A23-58: picking against your own side lowers your own score (ChoiceHint keeps its two-number call; the
		-- faction lines are what a client should show)
		-- A23-130 (user 2026-10-11 "너무 설명해주는 게 많은 거 같애"): the card's line keeps only the score change
		ChoiceHint = "Left: angel side · Right: devil side",
		ChoiceHintHalo = "Left: Honor +%d · Right: Honor -%d", -- (Good.Points, Evil.Points)
		ChoiceHintHorns = "Left: Infamy -%d · Right: Infamy +%d", -- (Good.Points, Evil.Points)
		ChoiceHintNeutral = "No good or evil points.",
		OffSideHalo = "Honor -%d", -- A23-58 (points actually taken); A23-130: the loss only, no guide voice
		OffSideHorns = "Infamy -%d",
		-- 3rd idea round #5: the same pick at 0 points (nothing to take) + the lean line after it
		OffSideHaloZero = "Hallie: Hmm… not very angel-like!", OffSideHornsZero = "Magpie: Too nice for a devil!",
		RankDownHalo = "Rank down!",
		RankDownHorns = "Rank down!",
		GooseFirstHalo = "Honor +%d",
		GooseFirstHorns = "Infamy +%d",
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
		-- PET-4 (content_beyond_10min §2 B, 게임성 개발 2): after M1_1, 8 meadow slimes bring a lost baby slime. Either pick
		-- makes it my pet (PetService, Config.PetGrant): Halo's own side = [Take care of it] (Honor +1), Horns' = [Make it
		-- my minion] (Infamy +1), the other side's pick -1 (A23-58); the pick is its Lean (Good Buddy / Little Minion)
		Pet1 = {
			Kind = "Sub", Title = "The Lost Baby Slime", ShortName = "Baby Slime", Requires = { Done = { "M1_1" } },
			Steps = {
				{ Text = "Beat meadow slimes %d/%d", Guide = "SlimeMeadow",
					Start = "Something small is crying in the meadow...",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 8 } },
				{ Text = "A lost Baby Slime! What will you do?", Panel = true,
					Lines = { All = { "A tiny lost slime hops up to you.", "It wants to come with you!" } },
					Obj = { Type = "Choice", Good = { Label = "Take care of it", Points = 1, Pick = "Care" },
						Evil = { Label = "Make it my minion", Points = 1, Pick = "Minion" },
						Neutral = { A = "Take care of it", B = "Make it my minion" } } },
			},
		},
		-- A23-70 (user 2026-10-07 "아 좋다"): the first good / evil moment, one small card right after the first [Claim]
		-- (Pop = the card opens by itself once). No score either way (Points 0: the shard leans, the Choice sound and the
		-- afterglow answer); every side may press both buttons. Then the Forge row. A23-130 (user 2026-10-11 "너무 설명해주는
		-- 게 많은 거 같애"): no Reply line after a pick any more (the kid's "Thank you! …"), only the reward toast ("+HP
		-- Potion" / "+25 gold"); a pick with a Reward sends no lean / "saved" line either (StoryQuestService)
		Lunch1 = {
			Kind = "Sub", Title = "Lost Lunchbox!", ShortName = "Lost lunchbox", Pop = true,
			Requires = { TutorialDone = true, NotDone = { "M1_1" } },
			Steps = {
				{ Text = "Return the lunchbox, or take a bite?", Panel = true,
					Lines = { All = { "A slime dropped a lunchbox. It belongs to a kid at the Crossroads." } },
					Obj = { Type = "Choice",
						Good = { Label = "Give it back", Points = 0, Pick = "GiveBack",
							Reward = { Potion = "HP", N = 1 } },
						Evil = { Label = "One bite!", Points = 0, Pick = "Bite",
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
				{ Text = "Go to the Crossroads fountain", Guide = "Fountain",
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
		-- (owning tier 1 is the record: a no-op then). The quest pays like its chapter-1 siblings.
		-- Gameplay plan 2026-10-13 1-A #2 (A23-127): no weapon is sold any more, so the visit teaches enhancing: step 2
		-- opens with Otto's one Enhance Scroll (GiveItem, once per step) and passes when a scroll is used on a weapon
		-- (Event ScrollUsed, success or not; Past: a save that used one before passes at once). The first mission's 150 gold
		-- goes to potions
		M1_1 = {
			Kind = "Main", Chapter = 1, Title = "Sparkly Jelly", ShortName = "Slime jelly", Speaker = "Smith", GiveWeapon = 1,
			Steps = { { Text = "Show the jelly to the Blacksmith", Guide = "Blacksmith", Obj = { Type = "State", Key = "BlacksmithVisited" } },
				{ Text = "Use the Enhance Scroll on your weapon", ShortName = "Enhance", Guide = "Bag",
					GiveItem = { Item = "Enh70", N = 1 }, Obj = { Type = "Event", Name = "ScrollUsed", Past = true } } },
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
				{ Text = "Go to the Crossroads fountain", Guide = "Fountain",
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
				{ Text = "Hit 3 monsters with one skill %d/%d", Guide = "SlimeMeadow", Obj = { Type = "SkillHit", Min = 3, Count = 2 } },
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
						Evil = { Label = "Keep it. Goblins stole it first!", Points = 3, Reward = { Gold = 192 } },
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
			-- gameplay plan 1-A #3: one egg hunt joined (the step counts hunts, GooseFinished; a hunt every 4 hours)
			Steps = { { Text = "Join a Golden Egg hunt", Guide = "Goose", Obj = { Type = "Goose", Count = 1 } } },
			-- Tug mode only: the first rescue / poach +1. Eggs mode: GooseService gives +5 once an hour (A23-134)
			FirstPoints = 1,
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
			Steps = { { Text = "Hit 2 monsters with one skill %d/%d", Obj = { Type = "SkillHit", Min = 2, Count = 3 } } },
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
		-- (A: one 70% scroll, B: 3 HP potions + 220 gold, 검수 2026-10-10 #71) on top of 120 gold + half a level bar of XP. No weekly ranking
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
				{ Text = "Slime Princes in the meadow %d/%d", Guide = "SlimeMeadow",
					Start = "A sack fell open… and Slime Princes gobbled what was inside!",
					Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2 } },
				{ Text = "Tell Bright what you found", Guide = "HaloTown", Npc = "Bright", Panel = true,
					Lines = { All = { "Sticky… sweet… is this jelly?",
						"Their secret sacks… are full of birthday jelly? For Rose?",
						"One jar says: 'Happy birthday, S. From the bench.'\nBright: Not my writing! I mean… whose writing?",
						"So what do we tell everyone?" } },
					Obj = { Type = "Choice",
						Good = { Label = "Tell everyone the truth", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Keep the rumor going. It's more fun!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Bright: So who started the rumor? …Does anyone remember?",
			Clue = "Bright's wristband: gold and purple. Where have you seen one?",
		},
		R1 = {
			Kind = "Sub", Title = "The Halos Are Up to Something", ShortName = "Spy on Halos", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M2_3" } },
			Start = "Psst! Rose in Horns Den has a secret job for you.",
			Steps = {
				{ Text = "Talk to Rose in Horns Den", Guide = "HornsTown", Npc = "Smokey", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Psst! A Halo broke the Crown! My uncle's friend's cousin saw it!",
						"This gold spyglass? Found it. Gold is fine. For spying.\nPlan A: we spy. Plan B: same as Plan A, but sneakier!",
						"The Halos whisper at the fountain. A secret plan!\nGo listen there. Look natural!" } } },
				{ Text = "Listen at the fountain %d/%d s", Guide = "Fountain",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 16, Zone = "Crossroads", Stay = 15 } },
				{ Text = "Slimes in the meadow %d/%d", Guide = "SlimeMeadow",
					Start = "You heard: \"Slimes… sparkles… BOOM at sunset!\" Check the meadow!",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 6 } },
				{ Text = "Tell Rose what you heard", Guide = "HornsTown", Npc = "Smokey", Panel = true,
					Lines = { All = { "The slimes were full of sparkle dust. For a show?",
						"Their big secret… is a fireworks show? For everyone?",
						"One purple firework? In a Halo show?\nThe plan is signed 'B.' …Never heard of a B.",
						"So what do we tell everyone?" } },
					Obj = { Type = "Choice",
						Good = { Label = "Tell everyone the truth", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Keep the rumor going. It's more fun!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Rose: So who started the rumor? …Does anyone remember?",
			Clue = "Rose's wristband: gold and purple. Where have you seen one?",
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
						Evil = { Label = "Sell more spy glasses to both!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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
		-- A23-86 Sprout Oath (content_beyond_10min G): at Lv15 after M3_4 (검수 2026-10-10 #54: with or without the Sprout
		-- Shield), a small training that shows the player's graduation role (Halo: guard + catch, Horns: raid) and ends with an
		-- oath. Same steps count and walking for both sides' rewards: a stat-free title, 2 points (A23-58: the other side -2)
		-- and the woods-type reward (2 minutes of hunting gold + XP, like the other woods subs).
		OathH = {
			Kind = "Sub", Title = "The Sprout Promise", ShortName = "Sprout promise", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M3_4" }, Level = 15 },
			Start = "Bright has one more lesson for you.",
			Steps = {
				{ Text = "Talk to Bright in Halo Citadel", Guide = "HaloTown", Npc = "Bright", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Bright: A real Halo guard catches Wanted villains!",
						"Bright: First, guard the woods bridge. Then face a Goblin Brute!" } } },
				{ Text = "Guard the woods bridge %d/%d s", Guide = "WoodsGate", Obj = { Type = "Near", Spot = "WoodsGate", Radius = 14, Stay = 15 } },
				{ Text = "Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 } },
				{ Text = "Make your promise to Bright", Guide = "HaloTown", Npc = "Bright", Panel = true,
					Lines = { All = { "Bright: You did it! Make your promise. What kind of Halo are you?" } },
					Obj = { Type = "Choice", Good = { Label = "I'll guard the small ones", Points = 2 },
						Evil = { Label = "Rascals bow to no one!", Points = 2 } } },
			},
			Reward = { Gold = 2, XP = 2, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },
			Finish = "Promise made! Keep it close, wherever you go.",
		},
		OathR = {
			Kind = "Sub", Title = "The Sprout Promise", ShortName = "Sprout promise", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M3_4" }, Level = 15 },
			Start = "Rose has one more lesson for you.",
			Steps = {
				{ Text = "Talk to Rose in Horns Den", Guide = "HornsTown", Npc = "Smokey", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Rose: A real Horn raids knights in the woods!",
						"Rose: Hold the sack for 45 seconds and it's yours!",
						"Rose: Warm up first. Two goblin camps, then punch a Goblin Brute. Basic hits only!" } } },
				{ Text = "Find the first goblin camp", Guide = "GoblinCamp1", Obj = { Type = "Near", Spot = "GoblinCamp1", Radius = 10 } },
				{ Text = "Find the second goblin camp", Guide = "GoblinCamp2", Obj = { Type = "Near", Spot = "GoblinCamp2", Radius = 10 } },
				{ Text = "Basic hits on a Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "BasicKill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 } },
				{ Text = "Make your promise to Rose", Guide = "HornsTown", Npc = "Smokey", Panel = true,
					Lines = { All = { "Rose: Not bad, rascal! Make your promise. What kind of Horn are you?" } },
					Obj = { Type = "Choice", Good = { Label = "I'll guard the small ones", Points = 2 },
						Evil = { Label = "Rascals bow to no one!", Points = 2 } } },
			},
			Reward = { Gold = 2, XP = 2, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },
			Finish = "Promise made! Keep it close, wherever you go.",
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
						Good = { Label = "Hand it back", Points = 1, -- A23-130: no Reply line, the reward toast only
							Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Finders keepers!", Points = 1,
							Reward = { Potion = "HP", N = 3, Gold = 192 } },
						Neutral = { A = "Hand it back", B = "Finders keepers!" } } },
			},
			Finish = "The woods feel a little less dark.",
		},
		-- quest_volume §3-2 (A23-56, 검수 2026-10-06): 12 new subs + 6 pulled from story_depth §3 / town_npc_quests, each once,
		-- ending in an A (angel) / B (devil) pick with the same size of reward in a different kind (A23-58 scores the pick).
		-- Town-type (Lv5-10): 120 gold + half a level bar, A one 70% scroll / B 3 HP potions + 220 gold (#71). Woods-type (Lv10+):
		-- 2 minutes of hunting gold + XP, A one 70% scroll / B 3 HP potions + 220 gold (검수 2026-10-10: the same as the
		-- town-type B, #71; WB1's bridge card keeps its own 192 = 1 minute of Lv10 hunting).
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
						Evil = { Label = "Make them say \"Thanks, boss!\"", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } },
					Horns = { Obj = { Type = "Choice", Good = { Label = "Share snacks with the den", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Count it twice. Mine!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } } },
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
						Evil = { Label = "Sell it at the counter", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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
				{ Text = "Look around the fountain", Guide = "Fountain",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 22, Zone = "Crossroads" } },
				{ Text = "Slimes %d/%d", Guide = "SlimeMeadow", Start = "Glowing jelly tracks lead to the meadow!",
					Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 5 } },
				{ Text = "Bring the lantern home", Guide = "HaloTown", Start = "The lantern! Take it home to Halo Citadel.",
					Obj = { Type = "Enter", Zone = "HaloTown" } },
				{ Text = "The lantern is back!", Guide = "HaloTown", Panel = true,
					Lines = { All = { "Found it! Still warm. Still glowing.", "Inside the lamp: a tiny 'B.' scratched in.\nWhose is it now?" } },
					Obj = { Type = "Choice", Good = { Label = "Give it back to the town", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Hang it in my house", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Bright: Who was the first to carry it, I wonder?",
		},
		R5 = {
			Kind = "Sub", Title = "Rose's Hat Problem", ShortName = "Rose's hat", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M1_4" }, Level = 8 },
			Start = "Rose: A Slime Prince is wearing my sack as a crown!",
			Steps = {
				{ Text = "Find the slime by the pond", Guide = "SlimePond", Obj = { Type = "Near", Spot = "SlimePond", Radius = 30 } },
				{ Text = "Slime Prince %d/%d", Guide = "SlimePond", Obj = { Type = "Kill", Kind = "BigSlime", Count = 1 } },
				{ Text = "The sack is free!", Panel = true,
					Lines = { All = { "A sack! A bit slimy. Rose's name is on it.", "So whose sack is it now?" } },
					Obj = { Type = "Choice", Good = { Label = "Give it back to Rose", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Finders keepers!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { GoldN = 120, XPBar = 0.5 },
			Finish = "Rose: Did the slime look good in it, at least?",
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
						Evil = { Label = "Grab MORE dust!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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
			Start = "Sir Gleam needs help in Halo Citadel!",
			Steps = {
				{ Text = "Talk to Sir Gleam", Guide = "HaloTown", Npc = "Gleam", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Sir Gleam: Day 40: Cat in tree. Again!", "Sir Gleam: Each rescue is a heart. 10,001 hearts!\nClear the slimes so I can reach it." } } },
				{ Text = "Slimes %d/%d", Guide = "SlimeMeadow", Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Count = 6 } },
				{ Text = "Back to Sir Gleam", Guide = "HaloTown", Obj = { Type = "Enter", Zone = "HaloTown" } },
				{ Text = "Talk with Sir Gleam", Guide = "HaloTown", Npc = "Gleam", Panel = true, -- 검수 10/10: at Sir Gleam (TownNpcs)
					Lines = { All = { "Sir Gleam: The cat is down! …It is already climbing again.", "Sir Gleam: What should we do?" } },
					Obj = { Type = "Choice", Good = { Label = "Let the cat be. Help someone new.", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Put it back up. More hearts!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
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
						Evil = { Label = "Do prank 201. The same one!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
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
						Evil = { Label = "Put up a KEEP OUT sign", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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
						Evil = { Label = "Sell him more gold paint", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
						Neutral = { A = "Tell him he's fine as he is", B = "Sell him more gold paint" } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Does gold paint make anyone rich?",
		},
		H5 = {
			Kind = "Sub", Title = "Paperwork for a Brute", ShortName = "Paperwork", Speaker = "Bright", Factions = { Halo = true },
			Requires = { Done = { "M2_7" }, Level = 15 },
			Start = "Bright needs a form signed. Find her in Halo Citadel!",
			Steps = {
				{ Text = "Talk to Bright", Guide = "HaloTown", Npc = "Bright", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Bright: I need Form H-2 to fight a Brute.", "Bright: Who made these forms?! …Oh. Us." } } },
				{ Text = "Goblin Brute %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "GoblinBrute", Count = 1 } },
				{ Text = "Tell Bright", Guide = "HaloTown", Npc = "Bright", Panel = true,
					Lines = { All = { "Bright: You beat it! Without a form!", "Bright: So… what about the forms?" } },
					Obj = { Type = "Choice", Good = { Label = "Skip the form. Just help!", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Fill in three more forms", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Bright: Do rules help, or do people help?",
		},
		R6 = {
			Kind = "Sub", Title = "Plan B, Again", ShortName = "Plan B", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M2_7" }, Level = 15 },
			Steps = {
				{ Text = "Talk to Rose", Guide = "HornsTown", Npc = "Smokey", Panel = true, Obj = { Type = "Talk" },
					Lines = { All = { "Rose: Plan B failed. Time for… Plan B?", "Rose: Plans cost gold. Lots of it." } } },
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 200 } },
				{ Text = "Back to Rose", Guide = "HornsTown", Npc = "Smokey", Panel = true,
					Lines = { All = { "Rose: Gold! Now, the plan…", "Rose: Which plan?" } },
					Obj = { Type = "Choice", Good = { Label = "Try a brand-new plan", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Plan B again, but LOUDER", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Rose: What if a plan needs two people?",
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
						Evil = { Label = "Victory dance, our side only!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Who was the war really for?",
		},
		GW5 = {
			Kind = "Sub", Title = "The Tired Goose", ShortName = "Tired goose", Speaker = "Fountain", Factions = { Halo = true, Horns = true },
			Requires = { Done = { "M2_7" }, Level = 17 },
			Start = "Fountain Shard: The Golden Goose looks so tired…",
			Steps = {
				{ Text = "Join a Golden Egg hunt", Guide = "Goose", Obj = { Type = "Goose", Count = 1 } }, -- 1-A #3: was 2 (8 hours)
				{ Text = "Talk with the Fountain Shard", Guide = "Crossroads", Panel = true,
					Lines = { All = { "Fountain Shard: She runs every day. Pulled this way, then that way.", "Fountain Shard: What now?" } },
					Obj = { Type = "Choice", Good = { Label = "Let her rest a day", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Make her lay eggs faster!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
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
						Evil = { Label = "Draw a mustache on him", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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
						Evil = { Label = "Vote for MORE. Again!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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
				{ Text = "Look at the hero statues in Halo Citadel %d/%d s", Guide = "HeroStatue",
					Obj = { Type = "Near", Spot = "HeroStatue", Radius = 16, Stay = 10 } },
				{ Text = "Goblins %d/%d", Guide = "GoblinWoods", Obj = { Type = "Kill", Kind = "Goblin", Zone = "GoblinWoods", Count = 8 } },
				{ Text = "Back to the statues", Guide = "HeroStatue", Obj = { Type = "Near", Spot = "HeroStatue", Radius = 16 } },
				{ Text = "The statues shine again!", Guide = "HeroStatue", Panel = true,
					Lines = { All = { "Bright: The statues are shiny again!", "Bright: What should the road show next?" } },
					Obj = { Type = "Choice", Good = { Label = "Add a statue of a sprout too", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "Make OUR statue bigger", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Bright: Who is a hero? Only the big ones?",
		},
		R7 = {
			Kind = "Sub", Title = "Lava Party", ShortName = "Lava party", Speaker = "Smokey", Factions = { Horns = true },
			Requires = { Done = { "M2_7" }, Level = 22 },
			Start = "Rose: Party at the lava cracks! Bring snacks… or gold.",
			Steps = {
				{ Text = "Warm up at the lava %d/%d s", Guide = "LavaCrack",
					Obj = { Type = "Near", Spot = "LavaCrack", Radius = 16, Stay = 10 } },
				{ Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 300 } },
				{ Text = "Party time", Guide = "HornsTown", Panel = true,
					Lines = { All = { "Rose: Snacks! Gold! Music!", "Rose: Who gets in?" } },
					Obj = { Type = "Choice", Good = { Label = "Invite the whole den", Points = 1, Reward = { Item = "Enh70", N = 1 } },
						Evil = { Label = "VIP only. Just us!", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },
			},
			Reward = { Gold = 2, XP = 2 },
			Finish = "Rose: Is a party better big, or just right?",
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
						Evil = { Label = "Build a bigger vault", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },
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

-- story_depth (나) the beta Easter eggs EG01 / EG02 / EG03 / EG04 / EG14 (검수 2026-10-10: only what needs no new model; A23-52
-- grown-ups' jokes, never a real brand / person). Hidden subs of the Crossroads: they start for everybody after M2_3 (no start
-- toast, no row, no marker); walking to the spot finds one (its dialogue opens by itself and the row shows from then on). A
-- found egg pays a stat-free title only. Spots (the props are the world tools' job: a sign / scroll Part with a SurfaceGui):
--   TermsScroll = behind the Altar of Fate (Config.Map.AltarPosition (0,0,45)), PatchNote = the slip in front of the Wanted
--   Board (BoardPosition (-55,0,0), it faces +X), GooseNest = the Golden Goose perch (Config.Goose.Position), the fountain
--   (Fountain) and the kids' bench (KidsBench) already exist.
-- (literals: some offline Vector3 doubles have no arithmetic)
Config.StoryQuests.Landmarks.TermsScroll = Vector3.new(0, 0, 51)
Config.StoryQuests.Landmarks.PatchNote = Vector3.new(-52, 0, 0)
-- A23-131: GooseNest = the Knights' egg nest (Config.Goose.Egg.Home.Halo); the old perch (-30,0,30) is the Horns cart now
Config.StoryQuests.Landmarks.GooseNest = Vector3.new(-30, 0, -30)
Config.StoryQuests.Defs.EG01 = {
	Kind = "Sub", Title = "Terms of Fate", ShortName = "Terms of Fate", Hidden = true, Speaker = "Scroll", Requires = { Done = { "M2_3" } },
	Steps = {
		{ Text = "Read the scroll", Obj = { Type = "Near", Spot = "TermsScroll", Radius = 6 } },
		{ Text = "TERMS OF FATE", Panel = true, Lines = { All = { "TERMS OF FATE (page 1 of 4,000)" } },
			-- MyWay = false: a joke, not a choice of heart (the pick only picks the lines and the title; My Way never counts it)
			Obj = { Type = "Choice", MyWay = false, Good = { Label = "Read it all", Points = 0 }, Evil = { Label = "I agree", Points = 0 },
				Neutral = { A = "Read it all", B = "I agree" } } },
		{ Text = "The fine print", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "Thanks! You agreed to… something. Not even Fate knows what." } },
			LinesBy = { From = "EG01",
				Good = { All = { "Rule 1: No slimes on the altar. Rule 2: See Rule 1.", "…You're still reading? Nobody reads this far.",
					"Page 4,000: Be kind. That was the whole thing." } },
				Evil = { All = { "Thanks! You agreed to… something. Not even Fate knows what." } },
				Default = { All = { "Thanks! You agreed to… something. Not even Fate knows what." } } } },
	},
	Reward = { TitleBy = { Good = "ActuallyReadIt", Evil = "DidntReadIt" } },
}
Config.StoryQuests.Defs.EG02 = {
	Kind = "Sub", Title = "Patch Note", ShortName = "Patch Note", Hidden = true, Speaker = "Notice", Requires = { Done = { "M2_3" } },
	Steps = {
		{ Text = "Read the note", Obj = { Type = "Near", Spot = "PatchNote", Radius = 6 } },
		{ Text = "Patch Note", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "Patch 0.0.1: The crown is broken.", "Known issue. We are looking into it." } } },
	},
	Reward = { Title = "BugReporter" },
}
Config.StoryQuests.Defs.EG03 = {
	Kind = "Sub", Title = "Goose Fan", ShortName = "Goose Fan", Hidden = true, Speaker = "Goose", Requires = { Done = { "M2_3" } },
	Steps = {
		{ Text = "Visit the goose", Obj = { Type = "Near", Spot = "GooseNest", Radius = 6 } },
		{ Text = "Goose Fan", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "The Golden Goose has 0 followers. She has never been happier.",
				"Also, she saw who broke the Crown. Honk." } } },
	},
	Reward = { Title = "GooseFan" },
}
Config.StoryQuests.Defs.EG04 = {
	Kind = "Sub", Title = "Sky Watcher", ShortName = "Sky Watcher", Hidden = true, Speaker = "Shard", Requires = { Done = { "M2_3" } },
	Steps = {
		{ Text = "Look up %d/%d s", Obj = { Type = "Near", Spot = "Fountain", Radius = 12, Stay = 30 } },
		{ Text = "Sky Watcher", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "Stop staring. I'm broken, not famous." } } },
	},
	Reward = { Title = "SkyWatcher" },
}
Config.StoryQuests.Defs.EG14 = {
	Kind = "Sub", Title = "Bench Detective", ShortName = "Bench clue", Hidden = true, Speaker = "Notice", Requires = { Done = { "M2_3" } },
	Steps = {
		{ Text = "Look under the bench", Obj = { Type = "Near", Spot = "KidsBench", Radius = 6 } },
		{ Text = "Bench Detective", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "Under the bench: two small handprints in old paint.", "One gold. One purple. Side by side." } } },
	},
	Reward = { Title = "BenchDetective" },
}
for _, id in { "EG01", "EG02", "EG03", "EG04", "EG14" } do table.insert(Config.StoryQuests.Subs, id) end

-- A23-104: the intro of the daily jobs (QuestService opens them when this quest ends: Config.Daily.IntroQuest). It starts by
-- itself at the end of the first chapter (M1_4), one short dialogue from my side's guide, a small reward like a woods sub's.
Config.StoryQuests.Defs.D0 = {
	Kind = "Sub", Title = "Daily Jobs", ShortName = "Daily jobs", Requires = { Done = { "M1_4" } },
	Steps = {
		{ Text = "Hear about the daily jobs", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "Every day I have 3 small jobs for you. Do all 3 for a daily chest!",
				"Look in your Quests window. New jobs come every morning." } } },
	},
	Reward = { Gold = 1, XP = 1 }, -- no Finish line: the usual quest-done line, then the Daily tab opens (A23-99: no "daily quests are open" toast)
}
table.insert(Config.StoryQuests.Subs, "D0")

-- A23-113 (검수 2026-10-10: "원한 자루·강화 옮기기 주문서·덩치 저울도 처음 만날 때 퀘스트 한 줄", like the goose, the daily jobs and the quick
-- slots): the first meeting with three things the screen no longer explains (A23-99) leaves ONE plain talking row, the frame of D0
-- above: no popup, no toast, no Start / Finish line; the row opens a short dialogue when it is pressed, and pays a minute of hunting.
-- A meeting is a saved flag (data.Story.First[name]) that the quest waits for with Requires.Seen:
--   Meetings = the state the 1 s loop checks (StoryQuestService.refresh): ScrollMet = a transfer scroll sits in the bag
--     (Config.Loot.Items Kind "Transfer"; an old save that already holds one meets it at once), ScaleMet = the player's own SizeMult
--     is above 1 (JusticeService: their side is the smaller one, so their body is bigger and stronger)
--   Events.SackMet = a PvP KO took gold into a Grudge Sack (PvPService.PlayerKO info.Stolen > 0), reported for the thief AND the victim
-- The words are checked against the numbers (tools/test_first_meetings.py): 45 s = Config.Grudge.SackSeconds, 1.6 = Config.Justice.MaxScale.
Config.StoryQuests.Meetings = {
	ScrollMet = { HoldKind = "Transfer" },
	ScaleMet = { AttrOver = { Name = "SizeMult", Over = 1 } },
}
Config.StoryQuests.Defs.TS1 = {
	Kind = "Sub", Title = "Moving an Upgrade", ShortName = "Move upgrade", Speaker = "Smith", Requires = { Seen = "ScrollMet" },
	Steps = {
		{ Text = "Hear about your Transfer Scroll", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "A Transfer Scroll moves a weapon's + to another weapon.",
				"If it fails, the + stays where it was. Only the scroll is used up." } } },
	},
	Reward = { Gold = 1, XP = 1 },
}
Config.StoryQuests.Defs.SG1 = {
	Kind = "Sub", Title = "The Grudge Sack", ShortName = "Grudge Sack", Speaker = "Notice", Requires = { Seen = "SackMet" },
	Steps = {
		{ Text = "Read about the Grudge Sack", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "Gold taken in a PvP fight goes into the thief's Grudge Sack.",
				"The thief keeps it after 45 seconds in a PvP zone.",
				"Beat the thief first and the gold goes back to its owner!" } } },
	},
	Reward = { Gold = 1, XP = 1 },
}
Config.StoryQuests.Defs.SZ1 = {
	Kind = "Sub", Title = "The Size Scale", ShortName = "Size scale", Speaker = "Fountain", Requires = { Seen = "ScaleMet" },
	Steps = {
		{ Text = "Hear about the size scale", Panel = true, Obj = { Type = "Talk" },
			Lines = { All = { "The Fountain weighs both sides. The side with less power grows bigger and stronger!",
				"It grows up to 1.6 times, then shrinks back as the sides even out." } } },
	},
	Reward = { Gold = 1, XP = 1 },
}
for _, id in { "TS1", "SG1", "SZ1" } do table.insert(Config.StoryQuests.Subs, id) end

-- A23-109 / A23-110 (user 2026-10-10, 검수 design 2026-10-10): The King's Hop. After the Slime Princes (M1_2) a new player with no
-- potions meets the King Slime, who hops over and lands on them (a lossless KO: game dev 2's personal King, which tells us with
-- StoryQuestService.Event "FirstKO"), then buys a potion, puts it in a quick slot (a new player's slots start empty, 검수 10/10:
-- "물약 사고 슬롯에 장착하는 퀘스트"), drinks it from there and wins the rematch. Five plain rows, no popups, no tips, no closing
-- toast (A23-99). Event steps wait for a named happening (Config.StoryQuests.Events): FirstKO (the KO itself), PotionBought
-- (ShopService.BuyPotion), QuickSlotSet (QuickSlotService: an item put into a slot), PotionUsed (VitalsService, a drink from the
-- quick slot or the bag). Past = a step whose happening was seen before it opened passes at once (a player who ran ahead is never
-- stuck); Held = a saved text field of the player's data whose letters mean it is already done (an old save's quick slots hold
-- HP, MP: nothing to put). TopUpGold = the carried gold is topped up to this much when the step opens (once; two potions at 25
-- each); Personal = only the personal King counts. Guides: PotionShop = the seller, QuickSlot = the bag's quick slots.
Config.StoryQuests.Events = { FirstKO = true, PotionBought = true, QuickSlotSet = true, PotionUsed = true }
Config.StoryQuests.Events.SackMet = true -- A23-113: a PvP KO that took gold into a Grudge Sack (see Meetings above)
-- gameplay plan 2026-10-13 1-A #2: an Enhance scroll used on a weapon, success or not (LootService useEnhance; M1_1 step 2)
Config.StoryQuests.Events.ScrollUsed = true
Config.StoryQuests.Defs.KO1 = {
	Kind = "Sub", Title = "The King's Hop", ShortName = "King's hop",
	Requires = { Done = { "M1_2" }, MaxLevel = 8, NoPotionYet = true, KingOn = true },
	Steps = {
		{ Text = "Defeat the King Slime", ShortName = "Defeat King", Guide = "SlimeMeadow", Obj = { Type = "Event", Name = "FirstKO" } },
		{ Text = "Buy a potion", ShortName = "Buy a potion", Guide = "PotionShop", TopUpGold = 50,
			Obj = { Type = "Event", Name = "PotionBought", Past = true } },
		{ Text = "Put the potion in a quick slot", ShortName = "Quick slot", Guide = "QuickSlot",
			Obj = { Type = "Event", Name = "QuickSlotSet", Past = true, Held = "QuickSlots" } },
		{ Text = "Drink it from your quick slot", ShortName = "Drink potion", Guide = "QuickSlot",
			Obj = { Type = "Event", Name = "PotionUsed", Past = true } },
		{ Text = "Defeat the King Slime", ShortName = "Defeat King", Guide = "SlimeMeadow",
			Obj = { Type = "Kill", Kind = "SlimeKing", Zone = "SlimeMeadow", Personal = true, Count = 1 } },
	},
	Reward = { Gold = 2, XP = 2, Item = "Enh70", N = 1 }, -- two minutes of hunting + one 70% scroll
}
table.insert(Config.StoryQuests.Subs, "KO1")
-- game dev 2 (the personal King) reads these: the quest, the step the King's first hop waits at, the step of the rematch.
-- SipAttr = the player attribute (boolean) StoryQuestService keeps true while a quest step waits for a potion drink: game dev 1's
-- VitalsUI then lets a full HP / MP bar be used (the server counts a practice sip and keeps the potion)
Config.FirstKO = { Quest = "KO1", Step = 1, RematchStep = 5, SipAttr = "PotionSip" }

-- The town people's bodies (zone_check_halo #22 / #24 / #25 / #26 / #27 / #30 / #34, 검수 2026-10-10; TownNpcs.luau, built by
-- MapBuilder.Build): temporary default Roblox-style NPCs from a HumanoidDescription (colours only, long sleeves; the final looks
-- are remake P4). At = the spot (X, Z; the height comes from a ray onto the ground at build time), Look = what it faces.
--   Story = a quest NPC (tag StoryNpc, NpcId, a "Talk" prompt); Folk = a townsperson who only stands there (tag TownFolk);
--   Merchant = a potion stall seller (tag PotionMerchant; on since main took game dev 2's #34: ShopService sells at every
--   tagged seller); Anvil = Otto, 4 studs behind the Crossroads anvil, decorative (the prompt stays on the anvil).
-- Halo Citadel spots (docs/design/halo_layout_plan_2026-10-10.json, A23-112 asymmetric layout: the plaza terrace is Y 20 at z
-- -524..-606, the fountain (34.55,-566) 16 x 16, the four shops each at its own angle (a shop is 22.8 x 14.3 studs, its front
-- = kit -Z turned by its yaw): Bright at the foot of the first plaza stairs (z -424, on the grass right of them, not on them), Sir Gleam beside the gate
-- road, the shop people (Folk1 juice, Folk2 flowers, Folk3 bakery) and the potion seller about 5 studs in front of their shop's
-- face, Folk4 beside the fountain. Y = the ground the spot is meant to have (a roof, a pedestal top or a balcony above it is never the ground): the ray
-- goes on below a hit more than YTol studs away from it. Retries / RetryDelay: a body whose avatar call failed is made again.
Config.TownNpcs = {
	Enabled = true,
	PromptDistance = 10, -- studs (< Config.StoryQuests.NpcRange 16: a trigger is always near enough for the story's own check)
	RayTop = 150, -- the ground ray starts this high and goes RayTop + RayDepth down
	RayDepth = 60,
	RayTries = 8, -- casts under one spot (a roof, then a floor below it ...)
	YTol = 4, -- studs: a ground hit this far from an entry's Y is a roof / pedestal, not the ground
	Retries = 3, -- tries to make a body (the avatar service can fail for a moment)
	RetryDelay = 5, -- seconds between tries
	MaxCoord = 3000,
	List = {
		{ Id = "Bright", Name = "Npc_Bright", Story = "Bright", Label = "Bright", At = Vector3.new(18, 0, -424), Look = Vector3.new(18, 0, -380),
			Colors = { Head = Color3.fromRGB(240, 200, 170), Torso = Color3.fromRGB(140, 200, 240), Legs = Color3.fromRGB(245, 245, 250) } },
		{ Id = "Gleam", Name = "Npc_Gleam", Story = "Gleam", Label = "Sir Gleam", At = Vector3.new(-10, 0, -372), Look = Vector3.new(0, 0, -372),
			Colors = { Head = Color3.fromRGB(205, 160, 120), Torso = Color3.fromRGB(232, 196, 70), Legs = Color3.fromRGB(240, 240, 235) } },
		{ Id = "Folk1", Name = "Npc_Folk1", Folk = "Folk1", At = Vector3.new(38.42, 0, -499.19), Look = Vector3.new(49.53, 0, -496), Y = 9,
			Colors = { Head = Color3.fromRGB(234, 184, 146), Torso = Color3.fromRGB(255, 200, 150), Legs = Color3.fromRGB(110, 90, 70) } },
		{ Id = "Folk2", Name = "Npc_Folk2", Folk = "Folk2", At = Vector3.new(6.6, 0, -489.63), Look = Vector3.new(-4.57, 0, -486), Y = 9,
			Colors = { Head = Color3.fromRGB(198, 143, 105), Torso = Color3.fromRGB(180, 150, 220), Legs = Color3.fromRGB(80, 80, 110) } },
		{ Id = "Folk3", Name = "Npc_Folk3", Folk = "Folk3", At = Vector3.new(-6.35, 0, -476.52), Look = Vector3.new(-18.21, 0, -474), Y = 9,
			Colors = { Head = Color3.fromRGB(150, 105, 75), Torso = Color3.fromRGB(150, 210, 170), Legs = Color3.fromRGB(225, 220, 200) } },
		{ Id = "Folk4", Name = "Npc_Folk4", Folk = "Folk4", At = Vector3.new(46, 0, -556), Look = Vector3.new(34.55, 0, -566), Y = 20,
			Colors = { Head = Color3.fromRGB(245, 205, 175), Torso = Color3.fromRGB(255, 225, 140), Legs = Color3.fromRGB(90, 120, 160) } },
		{ Id = "PotionHalo", Name = "PotionMerchant_Halo", Merchant = true, Label = "Potion Seller", Y = 9,
			At = Vector3.new(20.07, 0, -468.17), Look = Vector3.new(32.38, 0, -466) },
		{ Id = "Otto", Name = "Npc_Otto", Anvil = true, Behind = 4,
			Colors = { Head = Color3.fromRGB(220, 170, 130), Torso = Color3.fromRGB(95, 95, 105), Legs = Color3.fromRGB(60, 50, 45) } },
	},
}
-- gameplay plan 2026-10-13 1-A #9: temporary default bodies for the two quest people who had none (a Talk step whose NPC has
-- no body passes silently, StoryQuestService npcNear): Tiny (every side's N3, at the Crossroads by the kids' bench) and Rose
-- (the Horns kid, beside the Horns Den spawn like Bright in Halo; her quest id stays "Smokey", A23-138 renamed what is shown).
-- Kept out of the table above (the Halo stage-6 branch edits its rows).
table.insert(Config.TownNpcs.List, { Id = "Tiny", Name = "Npc_Tiny", Story = "Tiny", Label = "Tiny", At = Vector3.new(24, 0, 12),
	Look = Vector3.new(18, 0, 18),
	Colors = { Head = Color3.fromRGB(230, 185, 150), Torso = Color3.fromRGB(240, 170, 90), Legs = Color3.fromRGB(120, 100, 80) } })
table.insert(Config.TownNpcs.List, { Id = "Rose", Name = "Npc_Rose", Story = "Smokey", Label = "Rose", At = Vector3.new(-18, 0, 424),
	Look = Vector3.new(-18, 0, 380),
	Colors = { Head = Color3.fromRGB(205, 150, 115), Torso = Color3.fromRGB(150, 60, 80), Legs = Color3.fromRGB(70, 50, 60) } })

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
		Bonus = "Bonus: +%s",
		Full = "Max 3 jobs.",
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
		["story:OathH"] = "Faction", ["story:OathR"] = "Faction", -- 빛 마을 점검 #40
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
		{ Id = "Goose", ShortName = "Egg hunt", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 20, NonHunt = true,
			Text = "Golden Egg hunt %d times" },
		{ Id = "Hunt", ShortName = "Catch Wanted", Weight = 3, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Halo", PvP = true, NonHunt = true,
			Text = "Catch %d Wanted players (Kaiju count)" },
		{ Id = "Plunder", ShortName = "Rob Knights", Weight = 3, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Horns", PvP = true, NonHunt = true,
			Text = "Rob %d Knights of Light" },
		-- A23-113 #8 (user "마감 전 넣자"; docs/design/player_reactions_research_2026-10-10.md §9): a daily that is not hunting: make one
		-- good or naughty choice (a choice card, the King's finisher, a job board Kind / Sneaky job - every one of them is a deed of
		-- the daily ledger, Deeds.Add; Deeds.Booked counts it). It is made only while one of those sources is on (a Board /
		-- LostFound / KillCards switch in Config), else the slot is another kind.
		{ Id = "Choice", ShortName = "Kind or sneaky", Weight = 14, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 20, NonHunt = true,
			Text = "Make a kind or sneaky choice" },
	},
	-- A23-113 #8: from Lv10 at least one of the three dailies is not hunting (a template with NonHunt: Goose, Hunt / Plunder, Choice):
	-- when the other two slots are both hunting, the last one is drawn from the non-hunting kinds that fit this player now (none
	-- fits: unchanged). Lv1-9 (the meadow set of 3) is not touched.
	NonHuntFrom = 10,
	-- 검수 2026-10-10: a daily that waits for the goose must not become homework, so it is never a daily two days running
	-- (Config.Data.Defaults.GooseDay = the KST day index of the last goose daily made). The rule is "one non-hunting daily if one
	-- fits": a day with none that fits (the goose rested or far, no choice source, a guild member) keeps its three hunting
	-- dailies. Gameplay plan 2026-10-13 1-A #3: the egg hunt comes every 4 hours (A23-137: 00/04/08/12/16/20 KST), so a goose
	-- daily is made only while the next hunt starts within GooseWindow s (or one is on); the PvP kinds (Hunt / Plunder) are
	-- never the forced non-hunting slot (A23-113: no PvP pushed on a child) - they stay a rare plain draw
	GooseRestDays = 1,
	GooseWindow = 3600,
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
			{ Id = "Hunt", Weight = 0.4, Targets = { 1 } }, -- PvP, Halo (A23-113: rarely drawn: never pushed on a child)
			{ Id = "Plunder", Weight = 0.4, Targets = { 1 } }, -- PvP, Horns
			{ Id = "Choice", Weight = 3, Targets = { 1 } }, -- A23-113: one kind or sneaky choice (only while a choice source is on)
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
	-- 최종 검수 10/13 (A23-14 "no Lv10 from vacation alone", EarlyMult 0.5 -> 0.35): a missed day below Levels.EarlyUntil pays
	-- its XP x EarlyMult / VacationEarlyBase (the EarlyMult the early days were tuned for); QuestService also stops a
	-- vacation claim's XP at the end of Lv(EarlyUntil - 1), which is what keeps the rule
	VacationEarlyBase = 0.5,
	CheckInterval = 30, -- seconds between day-rollover checks for online players
	-- A23-104 (user 2026-10-10): a new player is told about the daily jobs by a short quest (the sub IntroQuest, after the
	-- first chapter) before any is made; until then QuestService makes, shows and counts none and says DailyLocked. A save that
	-- already ran its dailies (DailyDay > 0) is open. IntroGate = false: always open (the old rule).
	IntroGate = true,
	IntroQuest = "D0",
}
-- A23-104: set when the intro quest is done (the daily jobs are open); additive save field (the data version stays 3)
Config.Data.Defaults.DailyIntro = false
-- A23-113 (검수 2026-10-10): the KST day index of the last day a Golden Goose daily was made (never two days running; 0 = never)
Config.Data.Defaults.GooseDay = 0

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
	if (tonumber(level) or 1) < Config.Levels.EarlyUntil and (tonumber(Config.Daily.VacationEarlyBase) or 0) > 0 then
		x = x * Config.Levels.EarlyMult / Config.Daily.VacationEarlyBase -- 최종 검수 10/13 (see Config.Daily)
	end
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
	Stickers = { Id = 0, Price = 99, Name = "Sticker Pack", Attr = "PassStickers" }, -- A23-143: 12 stickers + GG
	Bubbles = { Id = 0, Price = 99, Name = "Bubble Pack", Attr = "PassBubbles" }, -- A23-144: every chat bubble skin
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
-- 검수 2026-10-10 (A23-113 follow-up): what each pass really does, in plain easy English. Line = the one short line of a Shop
-- card (<= 38 letters: the card wraps longer ones); Desc = the description of the pass page on create.roblox.com (the user pastes
-- it with the pass id; <= 300 letters). Prices and the 2x are not changed here: the text only says what the code does, and its
-- "2x" is Config.PassBoost.Mult (tools/test_pass_text.py keeps the words and the numbers in step). VIP lists the crown, the
-- chat tag and the Supporters board (they exist); the VIP emote of the A23-75 list is not built, so it is not promised yet.
-- Look = the looks tab (every sold or attendance look), PrivateServer = the Shop's private server card.
Config.PassInfo = {
	NoStats = "No stats are for sale.",
	XP2 = { Line = "Level up 2x faster",
		Desc = "Get 2x XP from everything you do, so you level up 2x faster. It only speeds up leveling. No stats are for sale." },
	Gold2 = { Line = "Earn 2x gold",
		Desc = "Earn 2x gold from hunting, quests and rewards. Gold you take from other players is not doubled. No stats are for sale." },
	VIP = { Line = "Crown, chat tag, Supporters board",
		Desc = "A crown by your name, a VIP tag in chat, and your name on the village Supporters board. No stats are for sale." },
	Look = { Line = "New colors for halo or horns",
		Desc = "A new color for your halo or horns. It only changes how you look: the shape still shows your rank. No stats are for sale." },
	PrivateServer = { Line = "Play with just your friends.",
		Desc = "Your own private server for you and your friends. Create it on the game page: open Servers, then Create. No stats are for sale." },
	Bubbles = { Line = "Fancy chat bubbles",
		Desc = "Show off when you chat: every fancy chat bubble skin. Your side's own bubble is free for everyone. No stats are for sale." },
	Stickers = { Line = "13 more chat stickers",
		Desc = "13 more stickers to pop over your head: hearts, a crown, Nice!, GG and more. 5 basic stickers are free for everyone. No stats are for sale." },
	-- the Shop window's own words (ShopUI, game dev 1; plan 10/13 §1-A #6 moved them here from ShopUI). A pass card's name =
	-- Config.GamePasses[kind].Name (PrivateName for the private server card), its line = Line above; the private server
	-- card adds Config.PrivateServer.Text. Off = the [Buy] capsules while the live switch PassSales is off (GameState
	-- SwitchPassSales = false; a bought pass keeps working)
	Screen = {
		Title = "Shop",
		PrivateName = "Private Server",
		PriceF = "%s R$",
		MonthF = "%s R$ / mo",
		Owned = "Owned",
		Soon = "Coming soon",
		Off = "Not on sale",
		Wear = "Wear",
		Wearing = "Wearing",
		LooksSideF = "Looks for %s",
		Looks = "Looks",
		Tickets = "Change Tickets",
		TicketF = "%s · you have %d",
		SoonToast = "Not on sale yet. Check back soon!",
		OffToast = "Not on sale right now. Check back later!",
		OwnedToast = "You already have this!",
		ServerToast = "Get a private server on the game page: open Servers, then Create.",
		Note = "Always ask a grown-up before you buy.",
	},
}

-- A23-143 (user 10/12): chat stickers - a picture over my head that everyone sees, no text typed. Keys = Config.UIArt.Parts
-- Emo* ids (image dev's art). The 5 basic ones are free (the part's Free = true: ThumbsUp, Question, Exclaim, Help, Thanks);
-- the other 12 + GG need the Sticker Pack pass (Config.GamePasses.Stickers, 99 R$). Remote SendSticker(key) ->
-- Fx "Sticker" { UserId, Key } to everyone (the screen draws it over that player for Seconds; MonetizationService).
Config.Stickers = {
	Order = { "EmoThumbsUp", "EmoQuestion", "EmoExclaim", "EmoHelp", "EmoThanks", "EmoHeart", "EmoHaloHeart", "EmoHornSmiley",
		"EmoCrown", "EmoSweat", "EmoZzz", "EmoClap", "EmoSparkle", "EmoAnger", "EmoNice", "EmoOops", "EmoLetsGo", "EmoGG" },
	Pass = "Stickers",
	Seconds = 3,
}
function Config.IsSticker(key)
	return type(key) == "string" and table.find(Config.Stickers.Order, key) ~= nil
end
-- a free sticker (its art part says Free = true); every other sticker needs the pass
function Config.StickerFree(key)
	local parts = type(Config.UIArt) == "table" and Config.UIArt.Parts or nil
	local part = type(parts) == "table" and parts[key] or nil
	return Config.IsSticker(key) and type(part) == "table" and part.Free == true
end

-- A23-143 / A23-144 (user 10/12): chat bubble skins - how MY chat bubble looks to everyone (TextChatService bubbles: the
-- client styles a speaker's bubble from their attribute BubbleOn; the text stays Roblox-filtered, only art and colours).
-- Each side's own bubble is free for everyone of that side (Free: Halo white + gold rim, Horns dark red, the artisan guild
-- wood + brass) and only for that side; every other skin needs the Bubble Pack (Config.GamePasses.Bubbles, 99 R$). Keys =
-- Config.UIArt.Parts ids (image dev's art, Bubble<Name>); a pack skin goes into Order once drawn. Saved: data.Bubble = the
-- picked key ("" = my side's free one). SetBubble(key) (MonetizationService) checks and saves; BubbleOn = what shows now.
Config.Bubbles = {
	Free = { Halo = "BubbleHalo", Horns = "BubbleHorns", Neutral = "BubbleArtisan" },
	-- the 3 sides' + the pack's 6 (image dev's names, 10/12; until a Parts entry is uploaded the client draws a code fallback)
	Order = { "BubbleHalo", "BubbleHorns", "BubbleArtisan", "BubblePixel", "BubbleDonut", "BubbleNight", "BubbleCloud",
		"BubbleFlower", "BubbleCrown" },
	Pass = "Bubbles",
}
Config.Data.Defaults.Bubble = "" -- additive (no version step): the picked chat bubble skin
function Config.IsBubble(key)
	return type(key) == "string" and table.find(Config.Bubbles.Order, key) ~= nil
end
-- the side whose free bubble `key` is (nil = a pack skin)
function Config.BubbleSide(key)
	for side, k in Config.Bubbles.Free do
		if k == key then return side end
	end
	return nil
end
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
-- A23-91 보강 (user 2026-10-09 "조금 더 세세하게"): turning toward a monster when I attack (HUD L.FaceTarget /
-- HUD.PickTarget). Monsters only (never players; hidden ambushers and monsters owned by someone else are skipped), within
-- the attack's own Range (Config.AttackProfile: bare hands 7, class weapons their row). The turn takes TurnTime s (ease
-- out) and is skipped within SkipDeg of where I face; while I walk the body stays on the target for SwingHold s, then
-- walks on. A small ring (the approved round FxShockRing art, RingColor; no rays) under the target while I attack,
-- RingPad x its width within RingSize..RingMax studs, gone RingShow s after my last attack.
-- ServerHint = false: CombatService.Swing still aims by itself (A23-61: the nearest monster inside the front half, else
-- the nearest within Range), so the pick copies that rule and the turn, the ring and the hit agree. The client already
-- sends its pick (Swing / Release arg 1 = the monster Model); the server takes it since dev2 2026-10-10 (CombatService
-- HINT: a manual attack's valid pick within Range + 2, turned to outside 10 deg; tools/test_swing_hint.py), so game dev 1
-- may set true: then the
-- target stays for KeepFor s after each attack (until it dies / leaves Range) and a new one is picked by score: WDist x
-- closeness (within Inside x Range) + WFront x in front of me + WScreen x near the screen centre + WAttacker if it wound
-- up an attack (WindupAt, server time) within AttackerFor s and stands within AttackerReach studs; a monster behind me
-- (look . dir < BackDot) farther than BackNear studs is never picked
Config.AutoFace = {
	ServerHint = true,
	KeepFor = 1.5, Inside = 0.95, BackDot = -0.2, BackNear = 6,
	WDist = 1, WFront = 0.8, WScreen = 0.5, WAttacker = 1.5, AttackerReach = 9, AttackerFor = 2,
	SkipDeg = 10, TurnTime = 0.08, SwingHold = 0.35,
	RingSize = 3.2, RingMax = 12, RingPad = 1.1, RingShow = 1.5, RingTransparency = 0.2,
	RingColor = Color3.fromRGB(255, 236, 170),
}

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

-- the King Slime's thud (user 2026-10-09 "킹슬라임이 뛸 때는 쿵쿵 카메라 효과 있으면 좋겠어"; 검수: near players only,
-- short, a thud + a round dust ring, off with Settings 'Screen shake'). Client only (Fx). A slime of Kinds hops slower
-- (HopRate x a slime's walk hop pace) and higher (HopRatio of its body, at most HopMax studs) than a normal slime, and
-- every landing - its walk hops and its attack hop (x AttackMul) - drops my camera Bump studs and lets it bounce back
-- over BumpTime s while my character stands within Near studs of it (less and less out to Far, nothing beyond), plays
-- the thud (Config.Audio.Sounds.KingThud: full within Near, silent from SoundFar) and spreads a round dust ring (Ring x
-- its body height wide, RingPuffs dust clouds on its edge, no rays). 'Screen shake' off / Roblox Reduced Motion: no
-- camera drop (the sound and the dust stay). Landings closer than Gap s make one thud.
-- A23-113 ① (user 2026-10-10 "마감 전 넣자", LandShadow.luau): about a second before a big landing a round soft shadow on
-- the ground where it lands - outside the circle = not hit; no text, no rays. Server contract (게임성 개발 2): monster model
-- attributes DropAt (server time the warning starts; a new value = a new circle), DropTime (s to the landing), optional
-- DropRadius (studs) and DropPos (Vector3; else the ground under the model). Radius = studs by MonsterKind when the server
-- sends none (Default for any other); MaxTime clamps DropTime; StartAlpha -> EndAlpha = the disc's transparency from the
-- warning to the landing (darker as it comes); Linger + Fade = s it stays, then fades, after the landing.
Config.LandShadow = {
	Radius = { Default = 10, SlimeKing = 10, PumpkinKing = 12, CaptainClatter = 12 },
	MinRadius = 3, MaxRadius = 40,
	MaxTime = 3, MaxDistance = 160,
	StartAlpha = 0.82, EndAlpha = 0.45,
	Linger = 0.15, Fade = 0.25,
	Height = 0.08,
	Color = Color3.fromRGB(46, 24, 34),
}

-- A23-131 / A23-134 황금 알 줍기, the client's look (EggFx.luau, 게임성 개발 1; the rules and numbers are the server's
-- Config.Goose.Egg, 게임성 개발 2; contract docs/design/golden_egg_contract_2026-10-11.md). Kinds = the code egg when the
-- server part has no mesh of its own (Size studs across, 1.3x tall; Glow = a round soft glow that wide, Breathe = the big
-- egg's swell, Sparkle = round sparkles per s near the camera); ArcHeight = a flight's peak clamp(distance x [1], [2],
-- [3]); PredictHold = s a previewed pickup stays hidden before it shows again (the server kept it); GoneWait = s a
-- removed ground egg waits for an EggReturn before it pops as picked; SoundRange = studs others' egg sounds reach;
-- PickSpeed = my pickup sound's pitch by the eggs held (1st / 2nd / 3rd). Text = the only marks it writes.
Config.GooseEggFx = {
	Kinds = {
		Gold = { Size = 1.2, Color = Color3.fromRGB(255, 205, 60), Sparkle = 3 },
		Bouncy = { Size = 1.2, Color = Color3.fromRGB(255, 228, 130), Sparkle = 4 },
		Big = { Size = 2.4, Color = Color3.fromRGB(255, 190, 40), Breathe = 0.08, Sparkle = 5 },
		Crown = { Size = 1.8, Color = Color3.fromRGB(255, 236, 150), Glow = 4.5, GlowAlpha = 0.86, Sparkle = 8 },
		Feather = { Size = 0.9, Color = Color3.fromRGB(255, 246, 215), Sparkle = 2 },
	},
	ArcHeight = { 0.35, 1.5, 6 },
	SparkleRange = 60,
	NoPickAlpha = 0.6,
	PredictHold = 0.6,
	RetryAfter = 1.5, -- s: a preview the server turned down is not tried again sooner (no flicker)
	MoveWindow = 0.5, MoveMin = 1, -- the preview needs MoveMin studs walked in MoveWindow s (the server's away rule)
	GoneWait = 0.25,
	MineSlack = 1, MineWindow = 0.5, -- 최종 검수 10/11: a removed egg within PickRadius + MineSlack of me while my EggCarry rose within MineWindow s = mine (no "someone picked it" pop)
	SoundRange = 30,
	PickSpeed = { 1, 1.12, 1.26 },
	MarkHeight = 6,
	Home = { Alpha = 0.75, CarryAlpha = 0.45, Height = 0.15 },
	Boundary = { Dots = 48, Size = 0.7, Alpha = 0.35, Range = 160 },
	Wobble = { Max = 18, Speed = 14 },
	Return = { Time = 0.8, Range = 160 },
	Deliver = { Time = 0.45, Rise = 4 },
	Shield = { Size = 6, Alpha = 0.8, Range = 100 },
	Text = { Alert = "!", Nap = "Zzz", Plus = "+%d" },
}

-- A23-113 ① the server half of the circle (게임성 개발 2, MonsterService LEAP; docs/design/boss_leap_2026-10-11.md): per
-- monster kind a big landing with the LandShadow attributes (DropAt last, DropTime = Warn, DropRadius, DropPos, plus
-- DropFrom / DropHeight for the leap's arc). The rule never changes: Warn s later every player whose root is within
-- DropRadius - Grace studs of DropPos (flat, YRange up / down) and a valid target (a boss's new-player rules, towns, zone,
-- water; a personal monster: its owner only) is hit, nobody else. DropRadius = Config.LandShadow.Radius[kind] (else
-- Default) + a personal King's LeapGrow after each miss (FirstKOService's first King: it keeps hopping until it lands).
--   Mode "Leap" (the King Slime): every attack is a leap onto the ground where its target stands when it starts (within
--     Range studs; the body moves there at once and clients draw it falling there, Fx dropLift); between leaps it never
--     swings. Cycle = s from one leap's start to the next (default Config.Monsters.AttackCooldown) and Mult = x its hit
--     (default Cycle / AttackCooldown), so standing still costs what the plain swings did; stepping out costs nothing.
--   Mode "Slam" (Captain Clatter): every Every-th attack is a slam around itself (it stays) instead of a swing, Mult x hit.
Config.BossLeap = {
	Enabled = true,
	Kinds = {
		SlimeKing = { Mode = "Leap", Range = 14, Warn = 1, Height = 12 },
		CaptainClatter = { Mode = "Slam", Every = 3, Warn = 1, Mult = 2 },
	},
	Grace = 0.5, YRange = 12, RetryDelay = 0.5,
}

Config.BossThud = {
	Kinds = { SlimeKing = true },
	HopRate = 0.55, HopRatio = 0.2, HopMax = 2,
	Near = 18, Far = 45, SoundFar = 70,
	Bump = 0.6, BumpTime = 0.32, AttackMul = 1.4, BumpMax = 0.9, -- studs, s (the drop shows ~0.63 x Bump: the bounce damps)
	Gap = 0.3,
	Ring = 0.9, RingMin = 4, RingMax = 12, RingGrow = 0.25, RingFade = 0.5, RingPuffs = 8,
	DustColor = Color3.fromRGB(196, 178, 140),
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
	UseItem = 0.4, EquipWeapon = 0.3, SellMaterials = 1, SetAnnounceName = 0.5, SetTitle = 0.5, SetLook = 0.5, EquipPet = 0.5, GhostHold = 2.7, -- GhostHold: a bit under the 3 s client cooldown
	SetSettings = 1, -- BB2: the client sends at most one blob per this + 0.05 s (a dropped call gets no answer)
	UseSkill = 0.1, -- SKL-2: skill presses (the 0.5 s gap between skills is SkillService's)
	UiMetric = 2, -- BB38: window-open reports (each window counts once a session)
	SetQuickSlot = 0.2, -- A23-109: one quick-slot fill / empty / swap (QuickSlotService)
}

----------------------------------------------------------------- king finisher card (게임성 개발 2, 2026-10-08)
-- docs/design/king_finisher_2026-10-08.md (rpg_success_analysis §4-3 #9, 검수 2026-10-08 kid-safe cut): a King Slime
-- kill stays the same kill for everyone; each paid contributor with a manual hit in the last ContributorWindow s also
-- gets a card only they see (FinisherService): Help (the Good side: Jelly) or Tickle (the Evil side: bank gold, never
-- 2x), the same size (Help.N x Loot.Items[Help.Item].Sell == Tickle.Gold). Not picked within Seconds (+ Grace for the
-- network, server only) = no gift, no points. Points: my own side's score +Points (inside Config.Deeds.PerDay) or -Points
-- off side (A23-58, never below 0); Neutral / no side: the gift only. One open card a player at a time.
Config.Finisher = {
	-- the field bosses only (검수 2026-10-08: the Slime Prince has no card; J 2026-10-09: Captain Clatter). Gameplay plan
	-- 2026-10-13 1-A #10: empty (no card) until the card's window exists (2-A #3: { SlimeKing = true, CaptainClatter = true })
	Kinds = {},
	Seconds = 10,
	Grace = 1,
	Points = 1,
	-- per boss kind (FinisherCard .Kind): Help = the Good gift (Item x N; what does not fit is paid at the item's Sell,
	-- else Worth), Tickle = the Evil gift (bank gold), the same size (N x (Sell or Worth) == Gold), and the card's words
	-- (Title, Help / Tickle buttons, HelpDone / TickleDone lines). The shared words are Text below.
	Cards = {
		-- (the King Slime's name stays on the line with its SlimeKing key: the A23-84 Slime Prince name check)
		SlimeKing = { Text = { Title = "The King Slime is dizzy!", Help = "Help it hop home", Tickle = "Tickle out its coins",
				HelpDone = "It hops home happy!", TickleDone = "Coins pop out!" },
			Help = { Item = "Jelly", N = 2 }, Tickle = { Gold = 4 } }, -- (proposed) = 2 Jelly x Sell 2
		-- J: [Let him rest] the scroll side, [Count the old treasure!] the gold side (proposed: 1 Enh70 = 300 gold)
		CaptainClatter = { Help = { Item = "Enh70", N = 1, Worth = 300 }, Tickle = { Gold = 300 },
			Text = { Title = "Captain Clatter is worn out!", Help = "Let him rest", Tickle = "Count the old treasure!",
				HelpDone = "\"Is my shift over? Nobody ever told me.\"", TickleDone = "Old coins rain down!" } },
	},
	Text = {
		Score = "%s +%d", -- ("Honor" | "Infamy", points)
		ScoreDown = "%s -%d", -- the other side's pick on the card ("Honor -1")
		-- the card's Hint per option (FinisherCard Help / Tickle .Hint)
		HintFull = "No more points today. Your shard still leans.",
		HintZero = "Nothing to lose. Your shard still leans.",
		HintNeutral = "Just the gift. No good or evil points.",
	},
}
-- (the finisher's points go through the daily deeds ledger, Config.Deeds / Deeds.luau; ScoreBudget retired 2026-10-09)
Config.RateLimits.FinisherPick = 0.3
Config.RateLimits.GooseSquare = 1 -- A23-141 Join / Leave (GooseSquare.luau)
Config.RateLimits.SendSticker = 2 -- A23-143: one sticker every 2 s per player
Config.RateLimits.SetBubble = 0.5 -- A23-144: picking a chat bubble skin
-- the year-round field bosses (FieldBossService; content_beyond_10min_2026-10-08 FB). Order = the boss keys (each key
-- names its GameState <Key>Active / EndsAt / NextAt and its Announce <Key>Appear / Defeat / Leave lines). Per boss: one
-- on the server; the first slot FirstDelay s after the start, then every Interval s from its last appearance (a due
-- slot waits for a ready player in its zone); it stays Lifetime s. Spot: the Vector3 attribute Attr on an instance
-- under workspace.Map, else (Hill) ServerStorage.MeadowTerrainStore HillTop moved PathStep studs toward HillPathFoot,
-- else Spawn, else a normal spawn point of the zone. Radius = studs around the spot for ground. MinLevel = the client
-- chip shows it from this level (the boss itself never checks it).
Config.FieldBosses = {
	Order = { "SlimeKing", "Clatter" },
	Tick = 0.5,
	-- A23-113 ⑦ (user 2026-10-10 "마감 전 넣자"; numbers by game dev 2, docs/design/field_boss_crowd_2026-10-11.md): the
	-- def HP is one hunter's fight (SoloSeconds); each more hunter adds PerHunter of it (the kaiju's per-player way, bigger:
	-- 0.15 let ten melt a boss in 28 s). Hunters, recounted every Every s: each ready, alive player within Radius studs
	-- (flat) counts its own damage over the last Window s / one hunter's pace (def HP / SoloSeconds per s) over the time
	-- since its first hit in the window (at least Rise s), at most 1, so a newcomer counts fully within Rise s, one who
	-- stops fades over Window s (no on / off gain), a bystander adds 0 and a new player punching the King about 0.2
	-- (ByDamage = false: 1 for any damage); the shares added up, 1..Max. The HP fraction stays. Equal hunters: 2 = 90 s,
	-- 3 = 80 s, 5 = 72 s, 10 = 66 s, whenever they come. A boss's own Crowd table overrides this one; Crowd = false turns
	-- it off for that boss. The reward bar reads each hit as a share of the MaxHP it had then (MonsterService _share).
	Crowd = { PerHunter = 0.5, Max = 10, Radius = 50, Window = 15, Every = 0.5, Rise = 2, SoloSeconds = 120 },
	-- the King Slime (A23-84; docs/design/king_slime_split_2026-10-08.md §3 / §3-1, 검수 OK 2026-10-08): the shrine's
	-- KingSpawn, else the hill top (430, 14.6, -170) + 8 toward the path at 113 degrees
	-- (Spawn = the place's KingSpawn marker, 검수 2026-10-11: the old hill-top spot is inside the shrine's footprint)
	SlimeKing = { Enabled = true, Kind = "SlimeKing", FirstDelay = 180, Interval = 480, Lifetime = 300, Radius = 2,
		RetryDelay = 10, Attr = "KingSpawn", Hill = true, PathStep = 8, Spawn = Vector3.new(426, 26.1, -160.5), MinLevel = 0,
		MaxY = 40 }, -- the hill-top shrine stands above normal ground (MonsterService.SpawnEvent opts.MaxY)
	-- Captain Clatter (content_beyond_10min_2026-10-08 J, 검수 OK 2026-10-09): every 20 min, stays 6 min, a ruins spawn
	-- point until 검수's tool marks ClatterSpawn. The chip shows from Lv25. On a defeat every paid contributor: +War own
	-- side's crown-war points (WarService.AddPoints; one side online = the siege count), +1 Kills (Titles at 1 / 10 / 50),
	-- and the Weekly item: a week's first kill always gives one, untaken weeks bank up to Max (a skipped week loses nothing)
	Clatter = { Enabled = true, Kind = "CaptainClatter", FirstDelay = 300, Interval = 1200, Lifetime = 360, Radius = 6,
		RetryDelay = 10, Attr = "ClatterSpawn", Spawn = Vector3.new(1670, 0, 0), MinLevel = 25, War = 20, -- A23-90: the Crown Pit
		Weekly = { Item = "CaptainBadge", N = 1, Max = 2 },
		Titles = { [1] = "ClatterStopper", [10] = "ClatterStopper10", [50] = "ClatterStopper50" } },
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
		"Travel", "WorldMap", "WeaponShop", "PotionShop", "Shop", "Rebirth", "Altar", "Class", "PlayerList", "Feedback", "Pet",
		"Diary" },
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
		-- A23-109 quick slots: the keys 1 / 2 above use slots 1 / 2 (QuickSlots.luau), this one slot 3
		{ Id = "QuickSlot3", Group = "Potion", Key = "Three", Pad = "", Label = "Quick slot 3", LabelEn = "Quick slot 3", Button = "Quick slot 3", ButtonEn = "Quick slot 3" },
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
		-- A23-143: the chat-sticker picker (StickerUI, P); the phone button comes with the phone round (A23-145)
		{ Id = "Stickers", Group = "Other", Key = "P", Pad = "", Label = "Stickers", LabelEn = "Stickers", Button = "Stickers button", ButtonEn = "Stickers button" },
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
-- A23-91 (user 2026-10-09 "콘솔 게임처럼"): the console-style camera follow (CameraFollow.luau FOLLOW, same names; Start
-- copies these over its defaults). Change these when the user says how it feels. Angles in degrees here, radians there
Config.CameraFollow = {
	DeadZone = math.rad(15), -- walk vs camera look: a smaller angle is left alone
	Gain = 2.2, -- target turn speed (rad / s) per rad beyond DeadZone
	SideMin = 0.35, -- a sideways walk turns at this share (forward = 1)
	BackDot = -0.3, -- walking toward the camera (walk . look below this): no turn
	Response = 6, StopResponse = 14, -- 1 / s: the spring while walking / after a stop
	MaxAccel = math.rad(240), -- rad / s per s
	MaxRate = math.rad(90), SlowMaxRate = math.rad(50), -- rad / s (slow: Screen shake off / Reduced Motion)
	MinRadius = 45, -- studs: never a tighter circle
	ManualHold = 1.5, -- s after a hand turn
	CombatHold = 1.5, CombatScale = 0.3, -- s after my swing / skill, and the share then
}

Config.Settings = {
	-- Settings.V. 2 (A23-78, user 2026-10-08): key hints are off by default now; a blob saved before V2 (V < 2 or no V)
	-- drops its old KeyBadges once (SanitizeSettings), every other value stays; from V2 on the player's own pick stays.
	-- V3 (A23-65, 검수 2026-10-09): the camera default was Free; V4 (A23-91, user 2026-10-09): the console-style Follow is
	-- the default again - a blob saved before V4 gets Cam = Follow once (V3 turned everybody to Free a day ago; only a
	-- day of own Free picks is lost), a Free picked from V4 on stays
	Version = 4,
	MaxBlobKeys = 16, -- top-level keys of one SetSettings blob (V, Keys, the twelve values incl. Music / Weather / BagWide, Seq = 15)
	Defs = {
		Sfx = { Type = "Number", Min = 0, Max = 1, Step = 0.1 },
		Music = { Type = "Number", Min = 0, Max = 1, Step = 0.1 }, -- A23-100: the background music (Audio "Music" group)
		Shake = { Type = "Bool" },
		-- A23-105 (game dev 1): rain / snow and the weather's tint and sound (WeatherFx.SetEnabled; the evening lamps stay)
		Weather = { Type = "Bool" },
		DmgNum = { Type = "Enum", Options = { "All", "Off" } },
		Tags = { Type = "Enum", Options = { "All", "Near", "Off" } },
		KeyBadges = { Type = "Bool" }, -- user 2026-10-08: off by default (keys can be changed anyway; the row turns them on)
		Lang = { Type = "Enum", Options = { "Auto", "ko", "en" } },
		-- A23-32 (H-1 bag, 게임성 개발 4): Default = newest first (the server's ItemSeq order), name, grade, type; an old
		-- "Count" falls back to Default
		BagSort = { Type = "Enum", Options = { "Default", "Name", "Grade", "Kind" } },
		BagWide = { Type = "Bool" }, -- A23-32: the bag's wide (8 columns) look; the bag's own button (not a Settings row)
		Cam = { Type = "Enum", Options = { "Follow", "Free" } }, -- A23-91: Follow = the console-style camera turns behind me while I walk (the default again since user 10/09; Free = Roblox's own)
		-- 검수 10/09 (system review ②): the first-PvP-zone cards were seen (FirstSteps; not a row in the Settings window)
		PvPCards = { Type = "Bool" },
	},
	Order = { "Sfx", "Music", "Shake", "Weather", "KeyBadges", "DmgNum", "Tags", "Lang", "BagSort", "Cam" },
	Text = {
		Sfx = "Sound effects", SfxEn = "Sound effects",
		Music = "Music", MusicEn = "Music",
		Shake = "Screen shake", ShakeEn = "Screen shake",
		Weather = "Weather effects", WeatherEn = "Weather effects",
		DmgNum = "Damage numbers", DmgNumEn = "Damage numbers",
		Tags = "Other players' name tags", TagsEn = "Other players' name tags",
		KeyBadges = "Key hints", KeyBadgesEn = "Key hints",
		Lang = "Language", LangEn = "Language",
		BagSort = "Bag order", BagSortEn = "Bag order",
		BagWide = "Wide bag", BagWideEn = "Wide bag", -- not a row in the window (Order)
		Cam = "Camera", CamEn = "Camera",
		PvPCards = "PvP zone cards seen", PvPCardsEn = "PvP zone cards seen", -- not a row in the window (Order)
		Options = {
			All = "All", AllEn = "All", Off = "Off", OffEn = "Off", Near = "Nearby only", NearEn = "Nearby only",
			Auto = "Auto", AutoEn = "Auto", ko = "한국어", koEn = "한국어", en = "English", enEn = "English",
			Default = "Newest", DefaultEn = "Newest", Grade = "By grade", GradeEn = "By grade", Name = "By name", NameEn = "By name",
			Kind = "By type", KindEn = "By type",
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
Config.BuildLabel = "private-test 2026.10.16" -- shown in the settings footer (bump with a release)

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
		DayCycle = { Type = "Bool", Default = true }, -- A23-105 (DayCycleService): off = the clock eases to Config.DayCycle.StartClock and stays
		Weather = { Type = "Bool", Default = true }, -- A23-105 (DayCycleService): off = always clear
	},
}

-- HealthService (검수 2026-10-09, system_review_round1 더하기 9; contract docs/design/health_report_server_2026-10-09.md): hourly
-- sums of what the game does (gold in / out per source, XP per level band, the goose's wins and pay, plunder amounts, pass
-- view -> prompt -> bought), merged by every server into one DataStore document per UTC hour (Store, key "H<YYYYMMDDHH>") every
-- FlushSeconds (x0.5..1.5 random) and when the server closes. Read in Studio: DebugCommand("Health"[, "stored" | "live"[:hours]]).
-- Bands = the level bands of the player-minutes / XP (the same cut as the analytics' level band). MaxKeys = the most keys a sums
-- table (gold sources, passes) may hold in a document; more fall into "Other". Alerts (starter numbers, tune after the first
-- tests): MinPlayerMinutes = the player-minutes a band needs in an hour before its rates count; SurgeRatio = the newest full hour's
-- gold / XP per player-minute vs the earlier hours' average (MinBaseline hours needed); GooseMinRounds / GooseSkew = a goose
-- side that won at least this share of at least this many decided rounds; QuietHours = no server wrote for this long.
Config.Health = {
	Enabled = true,
	Store = "HaloHorns_Health_v1",
	FlushSeconds = 600,
	ReadHours = 24,
	MaxReadHours = 72,
	MaxKeys = 40,
	Bands = { { Name = "1-9", Max = 9 }, { Name = "10-24", Max = 24 }, { Name = "25-49", Max = 49 }, { Name = "50+", Max = 1000 } },
	Alerts = { MinPlayerMinutes = 60, SurgeRatio = 2, MinBaseline = 3, GooseMinRounds = 10, GooseSkew = 0.75, QuietHours = 3 },
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
		"Tap Menu (top right) for your Bag, Hero, Skills and more.",
	},
	-- A23-145 (최종 검수 10/13): a touch-only device (no keyboard: no Esc, no Tab) reads these lines instead of the topic's
	TouchTopics = {
		Safety = {
			"Block or report someone: tap the Roblox button (top left), then find their name.",
			"Player list: tap a name to add a friend or block them.",
			"PvP zones (orange and red on the map): other players can fight you there.",
			"Ask a parent before using Robux. Never share your password.",
		},
	},
	Topics = {
		{ Id = "Controls", Title = "Controls", Lines = {} },
		-- 검수 2026-10-09 (system review ③ Help & Safety): right after Controls, so kids and parents find it
		{ Id = "Safety", Title = "Safety", Lines = {
			"Block or report someone: open the Roblox menu (Esc), then Players.",
			"Player list (Tab): press a name for Add friend or Block.",
			"PvP zones (orange and red on the map): other players can fight you there.",
			"Ask a parent before using Robux. Never share your password.",
		} },
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
			"Golden Goose: every 4 hours. Press Join, pick up its golden eggs and bring them home!", -- A23-141: the Goose Square
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
			"Your beta save carries over to the full launch.", -- A23-119: the launch date is set in December
			"Everyone who joins before the launch gets the Beta Pioneer title.",
		} },
		{ Title = "New this week", Lines = {
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
	-- A23-91 / settings V4: a blob from before V4 gets the camera default (the console-style Follow) once
	local before4 = not (type(src.V) == "number" and src.V == src.V and src.V >= 4)
	for key, def in ST.Defs do
		local v, d = src[key], defaults[key]
		if key == "KeyBadges" and before2 then v = d end
		if key == "Cam" and before4 then v = d end
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
		-- A23-87: the Flower Slime's petals (a sell material; the FlowerPatch card's Evil gift)
		Petal = { Kind = "Material", Name = "Flower Petal", Sell = 3, Color = Color3.fromRGB(255, 160, 205), Icon = "IconPetal" },
		-- A23-134: what Neutral artisans pick in the golden egg hunt (craft materials; icons not drawn yet = code fallback)
		GoldenEgg = { Kind = "Material", Name = "Golden Egg", Sell = 25, Color = Color3.fromRGB(255, 205, 60), Icon = "IconGoldenEgg", Source = "Goose", Desc = "Artisans craft with it." },
		GooseFeather = { Kind = "Material", Name = "Goose Feather", Sell = 10, Color = Color3.fromRGB(255, 246, 215), Icon = "IconGooseFeather", Source = "Goose", Desc = "Artisans craft with it." },
		SlimeCore = { Kind = "Material", Name = "Slime Core", Sell = 8, Color = Color3.fromRGB(80, 160, 235), Icon = "IconSlimeCore" },
		GoblinTooth = { Kind = "Material", Name = "Goblin Tooth", Sell = 6, Color = Color3.fromRGB(235, 225, 190), Icon = "IconGoblinTooth" },
		BruteHorn = { Kind = "Material", Name = "Brute Horn", Sell = 18, Color = Color3.fromRGB(200, 150, 100), Icon = "IconBruteHorn" }, -- review ui-brutehorn-contrast: readable on the row
		Bone = { Kind = "Material", Name = "Old Bone", Sell = 14, Color = Color3.fromRGB(225, 225, 210), Icon = "IconBone" },
		KnightCrest = { Kind = "Material", Name = "Rusty Knight Crest", Sell = 40, Color = Color3.fromRGB(150, 150, 170), Icon = "IconKnightCrest" },
		-- J: Captain Clatter's badge (a week's first kill always gives one; the T6 commission needs it, A23-86 L)
		CaptainBadge = { Kind = "Material", Name = "Captain's Badge", Sell = 200, Color = Color3.fromRGB(220, 190, 110), Icon = "IconCaptainBadge" },
		-- C1 boss materials for the artisans' recipes (W7 / W9). Source "Boss": never in the Forge's sell-all (sold one at a
		-- time). Icons not drawn yet (no Config.UIArt part: the bag's code fallback until image gen 2 -> image dev)
		KingJelly = { Kind = "Material", Name = "Royal Jelly", Sell = 60, Color = Color3.fromRGB(255, 140, 190), Icon = "IconKingJelly", Source = "Boss", Feature = "Crafting", Desc = "Artisans craft with it." },
		ClatterGem = { Kind = "Material", Name = "Old Crown Gem", Sell = 400, Color = Color3.fromRGB(120, 200, 230), Icon = "IconClatterGem", Source = "Boss", Feature = "Crafting", Desc = "Artisans craft with it." }, -- Feature: drops only while that switch is on
		Candy = { Kind = "Material", Name = "Candy", Sell = 5, Color = Color3.fromRGB(255, 140, 60), Icon = "IconCandy" }, -- Halloween kinds
		-- NewZones (A23-123): one material per new field, priced between its level neighbours (Jelly 2 / Goblin Tooth 6 /
		-- Old Bone 14). Icons not drawn yet (TODO image gen 2 -> image dev; until then the code fallback)
		SeaShell = { Kind = "Material", Name = "Sea Shell", Sell = 4, Color = Color3.fromRGB(250, 205, 180), Icon = "IconSeaShell" }, -- Coral Coast
		CrystalShard = { Kind = "Material", Name = "Crystal Shard", Sell = 8, Color = Color3.fromRGB(130, 210, 240), Icon = "IconCrystalShard" }, -- Crystal Cave Woods
		-- gathering (Config.Gather, GatherService; ids fixed: the market key I:<id> and the recipes use them). Icon keys named
		-- by 디자인 검수 (10/11); the parts come with image session 2 -> image dev, until then the code fallback. CrownDust:
		-- only from a Shard Bloom
		Herb = { Kind = "Material", Name = "Meadow Herb", Sell = 1, Color = Color3.fromRGB(140, 210, 255), Icon = "IconMeadowHerb", Source = "Gather", Desc = "Artisans craft with it." },
		CopperOre = { Kind = "Material", Name = "Copper Ore", Sell = 2, Color = Color3.fromRGB(205, 125, 75), Icon = "IconCopperOre", Source = "Gather", Desc = "Artisans craft with it." },
		OakLog = { Kind = "Material", Name = "Oak Log", Sell = 3, Color = Color3.fromRGB(160, 115, 70), Icon = "IconOakLog", Source = "Gather", Desc = "Artisans craft with it." },
		Glowcap = { Kind = "Material", Name = "Glowcap", Sell = 4, Color = Color3.fromRGB(80, 225, 205), Icon = "IconGlowcap", Source = "Gather", Desc = "Artisans craft with it." },
		IronOre = { Kind = "Material", Name = "Iron Ore", Sell = 5, Color = Color3.fromRGB(130, 135, 145), Icon = "IconIronOre", Source = "Gather", Desc = "Artisans craft with it." },
		SilverOre = { Kind = "Material", Name = "Silver Ore", Sell = 8, Color = Color3.fromRGB(210, 215, 225), Icon = "IconSilverOre", Source = "Gather", Desc = "Artisans craft with it." },
		MoonCrystal = { Kind = "Material", Name = "Moon Crystal", Sell = 10, Color = Color3.fromRGB(175, 165, 255), Icon = "IconMoonCrystal", Source = "Gather", Desc = "Artisans craft with it." },
		CrownDust = { Kind = "Material", Name = "Crown Dust", Sell = 8, Color = Color3.fromRGB(255, 215, 110), Icon = "IconCrownDust", Source = "Gather", Desc = "Artisans craft with it." },
		-- alchemy tonics (Config.Alchemy, BuffService; 게임성 개발 3 2026-10-12): made by alchemists, drunk by anyone (A23-133),
		-- monsters only, 3 minutes, two at a time. Source "Craft": never in the Forge's sell-all. Icons named later (디자인 검수)
		MightTonic = { Kind = "Tonic", Name = "Might Tonic", Sell = 15, Color = Color3.fromRGB(235, 90, 70), Icon = "IconMightTonic", Source = "Craft", Desc = "Hit monsters harder for 3 minutes." },
		GuardTonic = { Kind = "Tonic", Name = "Guard Tonic", Sell = 20, Color = Color3.fromRGB(90, 150, 235), Icon = "IconGuardTonic", Source = "Craft", Desc = "Monsters hurt you less for 3 minutes." },
		LuckyTonic = { Kind = "Tonic", Name = "Lucky Tonic", Sell = 40, Color = Color3.fromRGB(110, 210, 110), Icon = "IconLuckyTonic", Source = "Craft", Desc = "More materials from monsters for 3 minutes." },
		WisdomTonic = { Kind = "Tonic", Name = "Wisdom Tonic", Sell = 60, Color = Color3.fromRGB(175, 120, 235), Icon = "IconWisdomTonic", Source = "Craft", Desc = "More XP from monsters for 3 minutes." },
		-- ⑤ tamers make it (recipe T1); anyone feeds it to a pet (FeedPet: pet XP + Config.Research.TreatXP)
		PetTreat = { Kind = "Treat", Name = "Pet Treat", Sell = 10, Color = Color3.fromRGB(240, 170, 90), Icon = "IconPetTreat", Source = "Craft", Desc = "Feed it to your pet for pet XP." },
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
		"Jelly", "Petal", "GoldenEgg", "GooseFeather", "SlimeCore", "SeaShell", "GoblinTooth", "BruteHorn", "CrystalShard", "Bone", "KnightCrest", "CaptainBadge", "KingJelly", "ClatterGem", "Candy",
		"Herb", "CopperOre", "OakLog", "Glowcap", "IronOre", "SilverOre", "MoonCrystal", "CrownDust",
		"MightTonic", "GuardTonic", "LuckyTonic", "WisdomTonic", "PetTreat" },
	-- per monster Kind: rows rolled independently. { Item = id, P = chance, N = count } | { Potion = "HP"|"MP", P }
	-- | { Weapon = tier, P }. Provisional numbers (A23-12: tune after play; drop income is measured separately).
	-- Review B2 (2026-10-05): scroll chances rise with the zone (Enh70 / Enh30 / Enh10 per row), transfer scrolls are
	-- about 1/3 of the same row. Move30 / Move10 stay in the tables (A23-11 "three kinds") at those tiny rates; they
	-- move the same amount as Move70 with lower odds, so they are a rare free retry, never a better pick.
	-- Review B13: potion chances are about half of the first values (≈ 8-14 potions per hour of manual hunting).
	Tables = {
		-- A23-87 Flower Slime: petals (a sell material) + the meadow's scroll rows
		FlowerSlime = {
			{ Item = "Petal", P = 0.5 },
			{ Item = "Enh70", P = 0.01 }, { Item = "Enh30", P = 0.003 },
			{ Potion = "HP", P = 0.03 },
		},
		Slime = {
			{ Item = "Jelly", P = 0.30 },
			{ Item = "Enh70", P = 0.003 }, { Item = "Enh30", P = 0.0008 }, { Item = "Enh10", P = 0.0002 },
			{ Item = "Move70", P = 0.001 }, { Item = "Move30", P = 0.0003 }, { Item = "Move10", P = 0.0001 },
			{ Potion = "HP", P = 0.01 }, { Potion = "MP", P = 0.01 },
			-- C2 (crafting_market §3; 게임성 개발 2 10/13): a weapon above the level stays in the bag (A23-28). Never a BelowLevel on
			-- a plain monster's row: LootService.rollRows pays it on EVERY kill below the level, without a draw (the boss rows only)
			{ Weapon = 2, P = 0.002 }, { Weapon = 3, P = 0.001 },
		},
		BigSlime = {
			{ Item = "SlimeCore", P = 0.5 }, { Item = "Jelly", P = 0.5, N = 2 },
			{ Item = "Enh70", P = 0.03 }, { Item = "Enh30", P = 0.008 }, { Item = "Enh10", P = 0.002 },
			{ Item = "Move70", P = 0.01 }, { Item = "Move30", P = 0.003 }, { Item = "Move10", P = 0.0007 },
			{ Potion = "HP", P = 0.03 }, { Potion = "MP", P = 0.03 },
			{ Weapon = 2, P = 0.02 }, { Weapon = 3, P = 0.015 }, -- C2 (crafting_market §3; no BelowLevel, see Slime)
		},
		-- the King Slime boss (each paid contributor rolls; proposed, tune after play): more of the Prince's things
		SlimeKing = {
			{ Item = "SlimeCore", P = 1, N = 2 }, { Item = "Jelly", P = 1, N = 4 },
			{ Item = "Enh70", P = 0.25 }, { Item = "Enh30", P = 0.06 }, { Item = "Enh10", P = 0.015 },
			{ Item = "Move70", P = 0.08 }, { Item = "Move30", P = 0.02 }, { Item = "Move10", P = 0.005 },
			{ Potion = "HP", P = 0.3 }, { Potion = "MP", P = 0.3 },
			{ Item = "KingJelly", P = 0.2 }, -- C1: last, so the rows above keep their draws
			{ Weapon = 3, P = 0.10 }, -- C2 (crafting_market §3; no BelowLevel: the King is fought from Lv1, see Slime)
		},
		SlingshotGoblin = { -- A23-87: the goblin's rows
			{ Item = "GoblinTooth", P = 0.4 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Potion = "HP", P = 0.04 }, { Potion = "MP", P = 0.04 },
			{ Weapon = 4, P = 0.002 }, -- C2 (crafting_market §3): the goblin's weapon too
		},
		Goblin = {
			{ Item = "GoblinTooth", P = 0.4 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
			{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
			{ Weapon = 4, P = 0.002 }, -- C2 (crafting_market §3): was 0.001
		},
		GoblinBrute = {
			{ Item = "BruteHorn", P = 0.5 },
			{ Item = "Enh70", P = 0.05 }, { Item = "Enh30", P = 0.014 }, { Item = "Enh10", P = 0.0035 },
			{ Item = "Move70", P = 0.017 }, { Item = "Move30", P = 0.0047 }, { Item = "Move10", P = 0.0012 },
			{ Potion = "HP", P = 0.04 }, { Potion = "MP", P = 0.04 },
			{ Weapon = 4, P = 0.005 },
			{ Weapon = 5, P = 0.0008 }, -- C2 (crafting_market §3; no BelowLevel, see Slime)
		},
		SkeletonArcher = { -- A23-87: the skeleton's rows
			{ Item = "Bone", P = 0.45 },
			{ Item = "Enh70", P = 0.05 }, { Item = "Enh30", P = 0.014 }, { Item = "Enh10", P = 0.004 },
			{ Potion = "HP", P = 0.05 }, { Potion = "MP", P = 0.05 },
			{ Weapon = 5, P = 0.001 }, -- C2 (crafting_market §3): the skeleton's weapon too
		},
		Skeleton = {
			{ Item = "Bone", P = 0.4 },
			{ Item = "Enh70", P = 0.025 }, { Item = "Enh30", P = 0.007 }, { Item = "Enh10", P = 0.0018 },
			{ Item = "Move70", P = 0.008 }, { Item = "Move30", P = 0.0023 }, { Item = "Move10", P = 0.0006 },
			{ Potion = "HP", P = 0.025 }, { Potion = "MP", P = 0.025 },
			{ Weapon = 5, P = 0.001 }, -- C2 (crafting_market §3): was 0.0005
		},
		-- J Captain Clatter (each eligible contributor rolls; the weekly badge is FieldBossService's, not a row)
		CaptainClatter = {
			{ Item = "KnightCrest", P = 1, N = 3 },
			{ Item = "Enh30", P = 0.2 }, { Item = "Enh10", P = 0.05 },
			{ Potion = "HP", P = 0.5 }, { Potion = "MP", P = 0.5 },
			-- below the weapon's MinLevel the row gives 2 more Knight Crests instead (A23-27)
			{ Weapon = 5, P = 0.03, BelowLevel = { Item = "KnightCrest", N = 2 } },
			{ Weapon = 6, P = 0.01, BelowLevel = { Item = "KnightCrest", N = 2 } }, -- C2 (crafting_market §3): was 0.005
			{ Item = "ClatterGem", P = 0.1 }, -- C1: last, so the rows above keep their draws
		},
		SkeletonKnight = {
			{ Item = "KnightCrest", P = 0.5 },
			{ Item = "Enh70", P = 0.08 }, { Item = "Enh30", P = 0.022 }, { Item = "Enh10", P = 0.006 },
			{ Item = "Move70", P = 0.027 }, { Item = "Move30", P = 0.0073 }, { Item = "Move10", P = 0.002 },
			{ Potion = "HP", P = 0.05 }, { Potion = "MP", P = 0.05 },
			{ Weapon = 5, P = 0.004 }, { Weapon = 6, P = 0.001 }, -- C2 (crafting_market §3): were 0.003 / 0.0005
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
		-- NewZones (A23-123; rolled only once the kinds spawn): the field's material + scroll / transfer / potion rows no
		-- higher than the neighbour of the same level (plain kinds <= the Goblin's rows, the tougher ones <= the Goblin
		-- Brute's); only the golem has a weapon row (T4, below the brute's)
		CoralCrab = {
			{ Item = "SeaShell", P = 0.35 },
			{ Item = "Enh70", P = 0.01 }, { Item = "Enh30", P = 0.0025 }, { Item = "Enh10", P = 0.0006 },
			{ Item = "Move70", P = 0.003 }, { Item = "Move30", P = 0.0008 }, { Item = "Move10", P = 0.0002 },
			{ Potion = "HP", P = 0.015 }, { Potion = "MP", P = 0.015 },
		},
		Jellyfish = {
			{ Item = "SeaShell", P = 0.3 },
			{ Item = "Enh70", P = 0.01 }, { Item = "Enh30", P = 0.0025 }, { Item = "Enh10", P = 0.0006 },
			{ Item = "Move70", P = 0.003 }, { Item = "Move30", P = 0.0008 }, { Item = "Move10", P = 0.0002 },
			{ Potion = "HP", P = 0.015 }, { Potion = "MP", P = 0.015 },
		},
		HermitCrab = {
			{ Item = "SeaShell", P = 0.5, N = 2 },
			{ Item = "Enh70", P = 0.03 }, { Item = "Enh30", P = 0.008 }, { Item = "Enh10", P = 0.002 },
			{ Item = "Move70", P = 0.01 }, { Item = "Move30", P = 0.003 }, { Item = "Move10", P = 0.0007 },
			{ Potion = "HP", P = 0.03 }, { Potion = "MP", P = 0.03 },
		},
		CrystalLizard = {
			{ Item = "CrystalShard", P = 0.3 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
			{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
		},
		CaveBat = {
			{ Item = "CrystalShard", P = 0.3 },
			{ Item = "Enh70", P = 0.015 }, { Item = "Enh30", P = 0.004 }, { Item = "Enh10", P = 0.001 },
			{ Item = "Move70", P = 0.005 }, { Item = "Move30", P = 0.0013 }, { Item = "Move10", P = 0.0003 },
			{ Potion = "HP", P = 0.02 }, { Potion = "MP", P = 0.02 },
		},
		GlowMushroom = {
			{ Item = "CrystalShard", P = 0.4 },
			{ Item = "Enh70", P = 0.02 }, { Item = "Enh30", P = 0.0055 }, { Item = "Enh10", P = 0.0014 },
			{ Item = "Move70", P = 0.0067 }, { Item = "Move30", P = 0.0018 }, { Item = "Move10", P = 0.0005 },
			{ Potion = "HP", P = 0.03 }, { Potion = "MP", P = 0.03 },
		},
		CrystalGolem = {
			{ Item = "CrystalShard", P = 0.6, N = 2 },
			{ Item = "Enh70", P = 0.05 }, { Item = "Enh30", P = 0.014 }, { Item = "Enh10", P = 0.0035 },
			{ Item = "Move70", P = 0.017 }, { Item = "Move30", P = 0.0047 }, { Item = "Move10", P = 0.0012 },
			{ Potion = "HP", P = 0.04 }, { Potion = "MP", P = 0.04 },
			{ Weapon = 4, P = 0.003 },
		},
	},
	-- "레벨1 몬스터" jackpot (user 2026-10-05): any player level, auto kills included, golden x GoldenMult. Pumpkin
	-- slimes are level-1 slimes of the PumpkinPatch (A23-30, on top of the meadow's), so they carry the same jackpot;
	-- the chance per kill is unchanged.
	Jackpot = { Monsters = { Slime = true, PumpkinSlime = true }, Chance = 1 / 20000, Tier = 8 },
	-- the first Slime Prince (BigSlime) a player defeats always drops one 70% scroll, plus a one-time hint (Text.FirstScroll shown
	-- NoticeSeconds; that kill's Loot Fx carries First = true so the client skips its own "where to use it" toast)
	FirstScroll = { Monster = "BigSlime", Item = "Enh70", NoticeSeconds = 6 },
	-- C2 (crafting_market §3 / §8): the first Slime Prince a player defeats always drops the tier-2 weapon (once, a paid
	-- kill; LootFlags.FirstWeapon), equipped at once when it beats the weapon in hand. A weapon owned already: the chance
	-- is used and nothing drops (no Spare, no gold)
	FirstWeaponDrop = { Monster = "BigSlime", Tier = 2 },
	-- gameplay plan 2026-10-13 1-A #2: the same for the first King Slime a player defeats (a paid kill, not a practice
	-- King; LootFlags.FirstKingWeapon): the tier-3 iron weapon (Text.FirstKingWeapon / FirstKingEquip)
	FirstKingDrop = { Monster = "SlimeKing", Tier = 3 },
	-- a weapon drop the player already owns turns into gold
	DuplicateWeaponGold = { [2] = 15, [3] = 80, [4] = 300, [5] = 1000, [6] = 3000, [7] = 9000, [8] = 3000 }, -- C2: 2 / 3 = 10% of the old price
	Text = {
		Got = "+%s",
		GotN = "+%s ×%d",
		Potion = { HP = "HP Potion", MP = "MP Potion" },
		PotionFull = "No room for %s.",
		-- full-stack notices: at most once per item id (or potion kind) per player per FullNoticeSeconds, kind "info"
		ItemFull = "%s is full (max %d).", -- materials (A23-130: the cap only, no sell / use tip)
		ItemFullUse = "%s is full (max %d).", -- scrolls (not sellable)
		ItemFullKeep = "%s is full (max %d).", -- gathered / crafted materials (a Source: not in the Forge's sell-all)
		UseCombat = "You can't use scrolls in combat.",
		EquipDead = "You can't change weapons while knocked out.",
		RareWeapon = "%s weapon! You got %s!", -- grade name (Rare / Epic / Legendary), weapon
		DuplicateWeapon = "%s again! +%s gold", -- (weapon, gold) only when the Spares are full (C2)
		SpareWeapon = "Spare [%s] in your Bag.", -- C2: a weapon owned already (weapon)
		FirstDropWeapon = "The Slime Prince dropped [%s]!", -- C2: the first Prince's weapon (weapon)
		FirstDropEquip = "The Slime Prince dropped [%s]! Equipped.", -- C2: ... and it beat the weapon in hand
		FirstKingWeapon = "The King Slime dropped [%s]!", -- 1-A #2: the first King's weapon (weapon)
		FirstKingEquip = "The King Slime dropped [%s]! Equipped.", -- ... and it beat the weapon in hand
		JackpotSelf = "Legendary weapon [%s]!",
		-- A23-34: the same jackpot found bare-handed is equipped at once
		JackpotEquip = "Legendary weapon [%s]!",
		JackpotEquipEn = "Legendary weapon [%s]!",
		FirstScroll = "You got a scroll! Enhance your weapon from your Bag. (Your weapon is safe even if it fails)",
		-- A23-34: the same one-time hint while still bare-handed (no weapon to enhance yet)
		FirstScrollBare = "You got a scroll! The Blacksmith gives you your first weapon. Then enhance it from your Bag.",
		FirstScrollBareEn = "You got a scroll! The Blacksmith gives you your first weapon. Then enhance it from your Bag.",
		-- A23-34: the M1_1 gift (LootService.GrantFirstWeapon). Bare-handed: equipped at once with the power change;
		-- a player who already bought a weapon gets it in the bag (no equip, no power change).
		FirstWeapon = "First weapon: [%s]!",
		FirstWeaponEn = "First weapon: [%s]!",
		FirstWeaponBag = "New weapon: [%s]!",
		FirstWeaponBagEn = "New weapon: [%s]!",
		-- A23-34: a weapon found while bare-handed is equipped at once (power change)
		BareEquip = "[%s] equipped! Power %s → %s",
		BareEquipEn = "[%s] equipped! Power %s → %s",
		-- 게임성 검수 10/12 (bag photo: "Enhance success! Wooden Sword +0 → +1 (attack…" cut at the column; A23-130 the
		-- result only - the sound and the colour tell success / failure, the confirm already says weapons never break).
		-- The callers' arguments stay (LootService, Panels: name, before, after, attack % before, after - the extra ones
		-- unused). MoveOk gets (from name, its level left, to name, its new level): only the weapon that took the
		-- enhance shows (%.0s prints nothing) - two long names did not fit one line
		EnhanceOk = "%s +%d → +%d!",
		EnhanceFailDown = "%s +%d → +%d", -- red (kind "bad") with ScrollFail: the lower number says it failed
		EnhanceFailKeep = "%s stays +%d", -- (kind "info" with ScrollFail)
		EnhanceMax = "Already at max enhance (+%d).",
		MoveOk = "%.0s%.0s%s +%d!",
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
-- 검수 2026-10-09 (user: "too kind"): the guide-style toasts / banners ("X is open!", "try ...") one switch each;
-- false = never shown. Rewards, danger and failures are no nudges and stay. 검수 decides the rest from the list
-- game dev 1 sent (2026-10-09)
Config.Nudges = {
	DailiesOpened = false, -- "Daily quests are open! ..." after the first [Claim] (HUD parseQuests)
	-- A23-99 추가 (user 2026-10-10 photo: "이거 없애달라니까 ㅋㅋ 위에 메인 퀘스트 관련한 내용 있잖아 이미"): the head line
	-- 'Quests (N) ▼' over the quest lines / tracker is gone (with its ▼); the quest window still opens with Q, the menu
	-- and a press on a quest line (phones: the block); the lines stay as many as before
	QuestHead = false,
	-- 검수 10/09 decision (docs/design/nudge_list_2026-10-09.md): client
	WarIntro = false, -- "Crown War: win points for your side!" when the war bar first shows (HUD.ApplyFold)
	-- A23-130 (user 2026-10-11 photo, Golden Goose): only the top bar (gauge + "0 / 20") stays; the line under it
	-- ("My points 0 · Knights, fill the gauge!" / the tug's "My points · hint") is gone (EventHUD updateGoose, TugSub)
	GooseSub = false,
	-- A23-130 sweep (docs/review/less_text_table_2026-10-11.md): the "Click to hit!" / "Tap to hit!" bubble over the attack
	-- button after 5 s idle near a monster in the first mission (FirstSteps HINT.Step) - the button is on screen already
	AttackHint = false,
	-- the weapon merchant's 4 s farewell toast after a manual close ("Nothing you like? Take your time!", Panels WSHOP)
	ShopFarewell = false,
	ZoneStoryLine = false, -- Config.StoryLines toasts at a zone unlock (Fx level up)
	SackLore = false, -- "Stolen gold carries a grudge ..." at the first sack arrow (EventHUD)
	HuntSlimes = false, -- "Hunt slimes and big slimes for XP." (HUD meadow guide)
	KeysTip = false, -- the keys tip card after the first skill (SkillBar LEARN.Tip)
	GuideLabel = false, -- 검수 10/09: the floating name chip over the guide target / pad ("First weapon"; HUD showGuide)
	GuideBeam = false, -- 검수 10/09 (user): the gold line on the ground to the target (HUD showGuide); A23-88 too
	-- A23-88 (검수 10/09, no lines / words): after the first weapon (TutorialStep Guide) the meadow travel pad itself glows
	-- softly while I am in the Crossroads, and [Menu] + its Travel square pulse until I open Travel once
	PadGlow = true,
	TravelPulse = true,
	-- server (the service owners read these keys; nil / true = shown as before)
	GuideDone = false, -- "That's all from me! Now hunt and get stronger." (QuestService)
	EnteredSafe = false, -- "Safe zone." on every safe-zone entry (ZoneService)
	DailyReady = false, -- "Daily quest done! Press [Claim]." (the line already says Done! / [Claim])
	WeaponUsableNow = false, -- "You can now use %s! ..." when a weapon's level limit opens
}

Config.ChatText = {
	Joined = "You joined the %s!", -- team name: "You joined the Horn Legion!"
	Choosing = "Pick a side to start!", -- TextChatService only: the line for the auto-assigned "Choosing a side" team
	-- 검수 2026-10-09 (UI clutter review ②: the team line stayed in the chat over the phone's joystick): the chat gets no
	-- team line (TextChatService, Announce.Incoming); the first side pick shows "You joined ...!" as one 3 s toast
	TeamToast = true,
	-- 검수 10/09 (user: "안 나오면 좋겠어, 너무 친절해"): no "You joined ...!" toast either (Halo and Horns); the chat line
	-- stays empty (TeamToast). true brings the first-pick toast back (Announce.JoinToast)
	JoinToast = false,
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
		-- J Captain Clatter (FieldBossService key Clatter)
		-- 게임성 검수 10/12: the appear toast names the place (Config.Zones[...].Name, test_field_boss checks it)
		ClatterAppear = "Captain Clatter is here! (Skeleton Ruins)",
		ClatterAppearEn = "Captain Clatter is here! (Skeleton Ruins)",
		ClatterDefeat = "Captain Clatter was defeated!",
		ClatterDefeatEn = "Captain Clatter was defeated!",
		ClatterLeave = "Captain Clatter left.",
		ClatterLeaveEn = "Captain Clatter left.",
		-- the King Slime boss (A23-84 the slime family's dad, A23-85 he raises the two kids alone; scary but playful)
		SlimeKingAppear = "King Slime is here! (Squishy Meadow)",
		SlimeKingAppearEn = "King Slime is here! (Squishy Meadow)",
		SlimeKingDefeat = "King Slime was defeated!",
		SlimeKingDefeatEn = "King Slime was defeated!",
		SlimeKingLeave = "King Slime went home.",
		SlimeKingLeaveEn = "King Slime went home.",
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
		-- Captain Clatter: a toast when he appears. Icon: the Skeleton Knight's head until his own art
		ClatterAppear = { Color = Color3.fromRGB(220, 200, 150), Toast = true, Icon = "IconMonSkeletonKnight" },
		ClatterDefeat = { Color = Color3.fromRGB(220, 200, 150), Icon = "IconMonSkeletonKnight" },
		ClatterLeave = { Color = Color3.fromRGB(200, 190, 170), Icon = "IconMonSkeletonKnight" },
		-- the King Slime (every 8 min: a toast only when it appears). Icon: the Slime Prince's head until the King's art
		SlimeKingAppear = { Color = Color3.fromRGB(90, 160, 255), Toast = true, Icon = "IconMonBigSlime" },
		SlimeKingDefeat = { Color = Color3.fromRGB(90, 160, 255), Icon = "IconMonBigSlime" },
		SlimeKingLeave = { Color = Color3.fromRGB(150, 195, 255), Icon = "IconMonBigSlime" },
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
-- J: Captain Clatter paid kills 1 / 10 / 50 (FieldBossService, Config.FieldBosses.Clatter.Titles)
Config.TitleDefs.ClatterStopper = { Name = "Clatter Stopper", NameEn = "Clatter Stopper", Color = Color3.fromRGB(220, 200, 150) }
Config.TitleDefs.ClatterStopper10 = { Name = "Clatter Stopper 10", NameEn = "Clatter Stopper 10", Color = Color3.fromRGB(235, 210, 140) }
Config.TitleDefs.ClatterStopper50 = { Name = "Clatter Stopper 50", NameEn = "Clatter Stopper 50", Color = Color3.fromRGB(255, 220, 120) }
for _, id in { "ClatterStopper", "ClatterStopper10", "ClatterStopper50" } do table.insert(Config.TitleOrder, id) end

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
		-- A23-113 ④ class hits (소리 14차 b09de5e7: Blade a, Magic a, Arrow b)
		HitBladeSoft = "rbxassetid://79062799855673",
		HitBladeHeavy = "rbxassetid://82160983185355",
		HitBladeCrit = "rbxassetid://96794463009444",
		HitMagicSoft = "rbxassetid://113932787040275",
		HitMagicHeavy = "rbxassetid://103466521988666",
		HitMagicCrit = "rbxassetid://123083371421263",
		HitArrowSoft = "rbxassetid://71567543920934",
		HitArrowHeavy = "rbxassetid://111127770916206",
		HitArrowCrit = "rbxassetid://83876322718434",
		-- 검수 10/10: monster death sounds by kind (소리 15차 86cd4a69, slimes first)
		DieSlime = "rbxassetid://105660948835844",
		DieBigSlime = "rbxassetid://135159844685749",
		DieFlowerSlime = "rbxassetid://108731319971001",
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
		-- batch 8 + C (소리 만들기 2026-10-10, docs/design/sound_gaps_2026-10-10.md A / C; art/sfx/asset_ids.json): wired in
		-- Audio.luau (the event table above its Public API)
		QuestOpen = "rbxassetid://132431286215692",
		QuestTab = "rbxassetid://80849245770259",
		StampPress = "rbxassetid://76569480136584",
		Chest7Open = "rbxassetid://137266411071976",
		WelcomeBack = "rbxassetid://86644525324244",
		DiaryPage = "rbxassetid://75472701527108",
		CandyPlop = "rbxassetid://71630733199634",
		KingHelpHome = "rbxassetid://129647790058754",
		KingTickleCoins = "rbxassetid://90219483742298",
		TipDing = "rbxassetid://111120758241059",
		Warp = "rbxassetid://132227699974979",
		WarpIn = "rbxassetid://127997176687568",
		SecretFound = "rbxassetid://121833019298027",
		BlipBright = "rbxassetid://126796215784360",
		BlipGleam = "rbxassetid://103851146620116",
		BlipFolk = "rbxassetid://98476528780032",
		-- 13차 (소리 만들기 2026-10-10, own synthesis tools/sfx_r13.py; DoorOpen is kept for later)
		LanternOn = "rbxassetid://94311196771631",
		PetCall = "rbxassetid://139309639843969",
		PetStow = "rbxassetid://109542349885083",
		PetLevel = "rbxassetid://128227928372563",
		DiamondTick = "rbxassetid://89172108649325",
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
		-- A23-113 ④: the class's own hits take the places of HitSoft / HitHeavy / HitCrit (Audio, Config.Audio.HitByClass)
		HitBladeSoft = { File = "HitBladeSoft", Volume = 0.32, Speed = { 0.95, 1.10 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		HitBladeHeavy = { File = "HitBladeHeavy", Volume = 0.36, Speed = { 0.90, 1.00 }, Max = 3, Gap = 0.06, Auto = true, Combat = true },
		HitBladeCrit = { File = "HitBladeCrit", Volume = 0.38, Speed = { 1, 1 }, Max = 1, Gap = 1.5, Auto = true, Combat = true },
		HitMagicSoft = { File = "HitMagicSoft", Volume = 0.32, Speed = { 0.95, 1.10 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		HitMagicHeavy = { File = "HitMagicHeavy", Volume = 0.36, Speed = { 0.90, 1.00 }, Max = 3, Gap = 0.06, Auto = true, Combat = true },
		HitMagicCrit = { File = "HitMagicCrit", Volume = 0.38, Speed = { 1, 1 }, Max = 1, Gap = 1.5, Auto = true, Combat = true },
		HitArrowSoft = { File = "HitArrowSoft", Volume = 0.32, Speed = { 0.95, 1.10 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		HitArrowHeavy = { File = "HitArrowHeavy", Volume = 0.36, Speed = { 0.90, 1.00 }, Max = 3, Gap = 0.06, Auto = true, Combat = true },
		HitArrowCrit = { File = "HitArrowCrit", Volume = 0.38, Speed = { 1, 1 }, Max = 1, Gap = 1.5, Auto = true, Combat = true },
		KillPop = { File = "KillPop", Volume = 0.40, Speed = { 0.95, 1.12 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		-- 검수 10/10: a monster kind's own death sound takes KillPop's place (Config.Audio.DeathByKind; same caps)
		DieSlime = { File = "DieSlime", Volume = 0.40, Speed = { 0.95, 1.12 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		DieBigSlime = { File = "DieBigSlime", Volume = 0.40, Speed = { 0.95, 1.12 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
		DieFlowerSlime = { File = "DieFlowerSlime", Volume = 0.40, Speed = { 0.95, 1.12 }, Max = 3, Gap = 0.05, Auto = true, Combat = true },
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
		-- A23-131 황금 알 줍기 (EggFx / Audio; design golden_egg §소리; files from 소리 만들기, "" until then = the stand-in in
		-- brackets plays): others' egg sounds only within Config.GooseEggFx.SoundRange, Max / Gap keep 30 players quiet
		EggPlop = { File = "EggPlop", Volume = 0.30, Speed = { 0.95, 1.08 }, Max = 2, Gap = 0.15 }, -- an egg lands (CandyPlop)
		EggPickup = { File = "EggPickup", Volume = 0.42, Speed = { 1, 1 }, Max = 2, Gap = 0.15 }, -- a pickup, pitch 1 / 1.12 / 1.26 by eggs held (GoldPickup)
		EggDeliverHalo = { File = "EggDeliverHalo", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 0.15 }, -- a Knight delivers: a clear bell (GoldPickup)
		EggDeliverHorns = { File = "EggDeliverHorns", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 0.15 }, -- a Horn delivers: coins (GoldPickup)
		EggBoing = { File = "EggBoing", Volume = 0.35, Speed = { 0.95, 1.1 }, Max = 2, Gap = 0.15 }, -- the bouncy egg hops away (silent)
		CrownEgg = { File = "CrownEgg", Volume = 0.55, Speed = { 1, 1 }, Max = 1, Gap = 5 }, -- the crown egg is laid: a short fanfare (GooseHonk)
		GooseSnore = { File = "GooseSnore", Volume = 0.35, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- the goose naps (silent)
		KaijuSiren = { File = "KaijuSiren", Volume = 0.70, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- B5 KaijuPhase -> 'Siren'; CountTick follows
		KaijuStomp = { File = "KaijuStomp", Volume = 0.45, Speed = { 0.97, 1.03 }, Max = 2, Gap = 1 }, -- B4 Fx Stomp: Volume x1 within 15 studs -> 0 at 60
		-- the King Slime's landing thud (Config.BossThud, Fx): the kaiju stomp file lower and softer until its own file
		KingThud = { File = "KaijuStomp", Volume = 0.38, Speed = { 0.86, 0.92 }, Max = 2, Gap = 0.25 },
		ZoneEnterPvP = { File = "ZoneEnterPvP", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B9 ZonePvP false->true, not within 3 s of a spawn / teleport, nothing on leaving
		GoldenSpot = { File = "GoldenSpot", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 10 }, -- B8 a golden monster first in view within 50 studs (once per monster); GoldenKill = same file
		GoldenKill = { File = "GoldenSpot", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 0.5 }, -- a golden kill (Reward Golden): the GoldenSpot file in its own pool (the spot's 10 s gap never eats it); the coin 0.1 s later
		KO = { File = "KO", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- B1 Fx KO (mine): cartoon dizzy, no death jingle
		Respawn = { File = "Respawn", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- B1 my character comes back after a KO
		Plunder = { File = "Plunder", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- B2 my sack / pocket is taken (the victim only; the taker hears GoldPickup)
		JackpotOther = { File = "JackpotOther", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- B10 someone else's Jackpot / FirstMax line (not RareWeapon)
		Loot = { File = "Loot", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.3 }, -- B14 Fx Loot with a scroll or a weapon (weapon SpeedMul 0.92); materials / potions silent
		-- sound_gaps 2026-10-10 A (batch 8): windows and moments that had no sound of their own
		QuestOpen = { File = "QuestOpen", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 0.15 }, -- the quest window "Journal" opening (instead of WindowOpen)
		QuestTab = { File = "QuestTab", Volume = 0.40, Speed = { 0.98, 1.02 }, Max = 1, Gap = 0.08 }, -- its tabs (the tab buttons have no Click)
		StampPress = { File = "StampPress", Volume = 0.55, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- Fx Attendance (the claim's QuestDone line gives way)
		Chest7Open = { File = "Chest7Open", Volume = 0.60, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- the 7-day box (Attendance Box), BoxAfter s after the stamp
		WelcomeBack = { File = "WelcomeBack", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 5 }, -- the "Welcome back!" card opening (PauseCard "Back")
		TipDing = { File = "TipDing", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- a tip card opening (PauseCard "Tip")
		DiaryPage = { File = "DiaryPage", Volume = 0.45, Speed = { 0.98, 1.02 }, Max = 1, Gap = 0.3 }, -- the King Diary opening on a page ([Read])
		CandyPlop = { File = "CandyPlop", Volume = 0.35, Speed = { 0.95, 1.08 }, Max = 2, Gap = 0.12 }, -- my drop with candy (Fx Loot)
		KingHelpHome = { File = "KingHelpHome", Volume = 0.55, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- Fx FinisherEnd Pick "Help"
		KingTickleCoins = { File = "KingTickleCoins", Volume = 0.55, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- Fx FinisherEnd Pick "Tickle"
		-- sound_gaps 2026-10-10 B / C
		Warp = { File = "Warp", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- I am moved far at once (pad, map travel, [Go]; not a respawn)
		WarpIn = { File = "WarpIn", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- ... and land: WarpInAfter s later
		SecretFound = { File = "SecretFound", Volume = 0.50, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- a hidden quest's row first shows (an easter egg found; instead of QuestNew)
		PetLevelUp = { File = "PetLevel", Volume = 0.45, Speed = { 1, 1 }, Max = 1, Gap = 2 }, -- one of my pets' Lv going up (PetList; 13차 its own file)
		PetCall = { File = "PetCall", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 0.3 }, -- a pet starts following me (PetList Equipped "" / other -> uid)
		PetStow = { File = "PetStow", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 0.3 }, -- my follower put away (Equipped uid -> "")
		MarkerMove = { File = "DiamondTick", Volume = 0.25, Speed = { 1, 1 }, Max = 1, Gap = 1 }, -- the quest marker's goal changing while it is on screen (13차 wood tick)
		LanternOn = { File = "LanternOn", Volume = 0.40, Speed = { 1, 1 }, Max = 1, Gap = 30 }, -- dusk: the lamps come on (GameState DayPhase -> "Dusk")
		-- NPC blips (asset_ids 'blips'): the story page of a speaker in Blips opens with that speaker's blip (instead of WindowOpen)
		BlipBright = { File = "BlipBright", Volume = 0.30, Speed = { 0.98, 1.02 }, Max = 1, Gap = 0.5 },
		BlipGleam = { File = "BlipGleam", Volume = 0.30, Speed = { 0.98, 1.02 }, Max = 1, Gap = 0.5 },
		BlipFolk = { File = "BlipFolk", Volume = 0.30, Speed = { 0.98, 1.02 }, Max = 1, Gap = 0.5 },
	},
	-- swing file per weapon style / class (Neutral Blacksmith / Alchemist: Speed x NeutralSpeed); SwingFaction picks the
	-- caster's faction file when it is uploaded (sound_gaps A2: Halo / Horns mages)
	Swing = { Warrior = "SwingWarrior", Mage = "SwingMage", Archer = "SwingArrow", Punch = "SwingWarrior",
		PetHeadbutt = "SwingTamer", PetDash = "SwingTamer" },
	SwingFaction = { Mage = { Halo = "SwingMageHalo", Horns = "SwingMageHorns" } },
	PunchSpeed = 1.3, -- bare hands: a short swish (volume x0.6)
	NeutralSpeed = { Warrior = 0.85, Mage = 0.9 },
	-- hit sound per monster kind: soft = slimes, ghosts, pumpkins; everything else and players = heavy
	-- A23-113 ④ (user 2026-10-10): the attacker's class picks its hit family (<family>Soft / Heavy / Crit, once uploaded);
	-- bare hands, the pet and a class not listed keep the material hits
	HitByClass = { Warrior = "HitBlade", Mage = "HitMagic", Archer = "HitArrow" },
	-- 검수 10/10: my kill's sound by the monster kind (the Reward packet's Kind, else the monster at its Pos); a kind not
	-- listed or not uploaded keeps KillPop (goblin, skeleton, pumpkin, ghost follow in their zone turns)
	DeathByKind = { Slime = "DieSlime", BigSlime = "DieBigSlime", FlowerSlime = "DieFlowerSlime" },
	SoftKinds = { Slime = true, FlowerSlime = true, BigSlime = true, SlimeKing = true, PumpkinSlime = true, LittleGhost = true, GhostMinion = true, GhostKing = true },
	-- typewriter voices (quality ②): speaker -> blip speed (the shard high and fast, the Horns guide low; Config story
	-- Speaker ids Shard / Smith / Guild / Fountain)
	Talk = { Default = 1, Shard = 1.45, Halo = 1.1, Horns = 0.78, Smith = 0.86, Guild = 0.95, Fountain = 1.2 },
	-- story Speaker -> the blip its page opens with (the Horns town's NPCs get theirs with the Horns zone; BlipFolk waits for
	-- a townsperson who talks)
	Blips = { Bright = "BlipBright", Gleam = "BlipGleam" },
	BoxAfter = 0.35, -- s after StampPress: the 7-day box opens
	WarpInAfter = 0.45, -- s after Warp: WarpIn
	-- a move of more than Jump studs in one frame that my speed cannot explain (+ Slack studs) = a warp
	Warp = { Jump = 40, Slack = 10 },
	ReplaceWithin = 0.3, -- s: a sound with Replace stops that event's copies started this recently (StampPress -> QuestDone)
}

-- A23-100 배경 음악 (소리 만들기 2026-10-10, art/sfx/asset_ids.json "bgm"; mono loops, -24 LUFS): Audio.luau plays the
-- track of the zone I stand in (Tracks[ZoneId], from TimePosition 0) in the "Music" SoundGroup at Volume (under Settings
-- "Music"), crossfading over Fade s when my ZoneId changes; a zone without a track (Outskirts, the sea, the bridges) is
-- quiet. The big moments (Duck.By) lower it to DuckMul. Boss[zone] = the boss layer (sample-for-sample the zone track's
-- length, -27 LUFS): while GameState[Active] is true and I am in that zone it plays with the track at the track's
-- TimePosition (fading in / out with the same Fade)
Config.Audio.Music = {
	Volume = 0.5, Fade = 1.5, DuckMul = 0.5,
	Tracks = {
		HaloTown = "rbxassetid://108661141883977", -- 88.646 s loop
		HornsTown = "rbxassetid://123430641290441", -- 63.264 s loop
		Crossroads = "rbxassetid://89489494811803", -- 82.244 s
		SlimeMeadow = "rbxassetid://107428223386912", -- 69.634 s
		GoblinWoods = "rbxassetid://114854716063832", -- 77.515 s
		SkeletonRuins = "rbxassetid://70596551890083", -- 64.779 s
		PumpkinPatch = "rbxassetid://97391238692429", -- 68.961 s
		HauntedHollow = "rbxassetid://103556459915929", -- 69.017 s
	},
	Boss = {
		SlimeMeadow = { Id = "rbxassetid://98188790457804", Active = "SlimeKingActive" }, -- King Slime
		PumpkinPatch = { Id = "rbxassetid://113774483516470", Active = "PumpkinKingActive" }, -- Pumpkin King
		HauntedHollow = { Id = "rbxassetid://97981769754135", Active = "GhostKingActive" }, -- Ghost King
		SkeletonRuins = { Id = "rbxassetid://88486401685380", Active = "ClatterActive" }, -- Captain Clatter
	},
}
-- 점검표 sound 60 (소리 만들기 2026-10-10; 20 s loops, -30 LUFS): 3D water by the fountains (FountainFx -> Audio.Ambient)
-- and the waterfalls (Map.Decor models named *Waterfall, + Spots for terrain-only falls: the Halo town's six =
-- tools/worldkit/halo_terrain.luau FALLS x WINGS, x = +-the wing's outer edge, y = half its drop to the sea). Outside the
-- MaxPlaying pools; the Sound effects setting scales them
-- the town's own air (soundboard 2026-10-10 'ambience' HaloDay / HornsDen, 25 s loops): a 2D loop in the zone, at Volume
-- x the Sound effects setting, crossfading with the zone like the music (Fade s)
Config.Audio.ZoneAmbient = {
	Volume = 0.25, Fade = 1.5,
	-- A23-105 (검수 10/10): the Halo birds only by day - at night they fade out and the crickets (Weather Night) carry it
	DayOnly = { HaloTown = true },
	Tracks = {
		HaloTown = "rbxassetid://76688623617177", -- birds + a tiny wind chime
		HornsTown = "rbxassetid://112972652651947", -- lava bubbling + campfire crackle
	},
}
-- A23-105 weather air (소리 만들기 2026-10-10 'ambience', 25 s loops): from WeatherFx.State() (GameState Weather / DayPhase,
-- the roof check, the 'Weather effects' setting): Rain (RainRoof instead under a roof) and WinterWind (snow) while the
-- weather effects are on; Night (crickets) at night unless it rains. 2D, each fading in / out over Fade s, at Volume x
-- the Sound effects setting
Config.Audio.Weather = {
	Fade = 1.5,
	Loops = {
		Rain = { Id = "rbxassetid://126445007194331", Volume = 0.35 },
		RainRoof = { Id = "rbxassetid://76655204420103", Volume = 0.25 },
		Night = { Id = "rbxassetid://99972569683856", Volume = 0.30 },
		WinterWind = { Id = "rbxassetid://113002054407080", Volume = 0.35 },
	},
}
Config.Audio.Ambient = {
	Fountain = { Id = "rbxassetid://136139057502455", Volume = 0.5, MinDistance = 6, MaxDistance = 40 },
	Waterfall = { Id = "rbxassetid://85234404217631", Volume = 0.5, MinDistance = 8, MaxDistance = 40,
		Spots = { Vector3.new(-188, 3, -493), Vector3.new(188, 3, -493), Vector3.new(-190, 7, -582), Vector3.new(190, 7, -582),
			Vector3.new(-190, 11, -660), Vector3.new(190, 11, -660) } },
}

-- A23-109 (user 2026-10-10 photo: the two potion circles out, quick slots 1 / 2 / 3 in a row): what a quick slot can hold.
-- QuickSlots.luau (game dev 1) uses and shows them; the server (game dev 2) saves data.QuickSlots and sends the owner's
-- attribute Attr = "HP,MP," (three entries, "" = empty), c->s Remote(slot 1..3, item key or ""): known keys only, the same
-- item in another slot swaps. Items[key] = { Name, Icon (Config.UIArt part), Use = "Potion" (VitalsUI's UsePotion), Kind,
-- Stock / ReadyAt (the owner's attributes), Cooldown (s) }; Order = the bag's quick items rows
Config.QuickSlots = {
	Count = 3,
	-- 검수 10/10 (user: "물약 사서 슬롯에 장착하는 퀘스트"): a new player starts with empty slots (the quest row says what to
	-- do); an old save gets HP / MP from the server
	Default = { "", "", "" },
	Attr = "QuickSlots",
	Remote = "SetQuickSlot",
	Order = { "HP", "MP" },
	Items = {
		HP = { Name = "HP Potion", Icon = "IconPotionHP", Use = "Potion", Kind = "HP", Stock = "HPPotionCount", ReadyAt = "HPPotionReadyAt",
			Cooldown = Config.Vitals.PotionCooldown },
		MP = { Name = "MP Potion", Icon = "IconPotionMP", Use = "Potion", Kind = "MP", Stock = "MPPotionCount", ReadyAt = "MPPotionReadyAt",
			Cooldown = Config.Vitals.PotionCooldown },
	},
}

-- A23-108 (user 2026-10-10 "직업별로 무기 쥐는 법 이런 것도 다 해야 된다"; docs/design/class_grips_a23_108_2026-10-10.md):
-- the weapon each class x faction holds. Key = Config.ClassGripKey(class, faction) ("Warrior_Halo" ... , a class alone
-- without a side). Weapon = the kind CharacterVisuals builds (a SHAPES builder or the old Sword / Staff / Bow / Baton);
-- how the hand holds it = Config.WeaponGrips[Weapon] below.
-- A23-150 7 (user 10/12 night (가) "로블록스 기본 그대로"): the standing / walking hold is Roblox's own - the weapon is a
-- Tool, the default Animate holds it (toolnone: the right arm forward at shoulder height, the weapon upright) - so the
-- old per-class standing poses (Hold / Walk / OneHand / OffHand / TwoHand, WeaponPose.luau) are gone. The attacks stay
-- each class x side's own clips (Fx MOTION.SIDE_CLIPS / CLASS_CLIPS).
Config.ClassGrips = {
	Warrior_Halo = { Weapon = "Sword" }, -- Paladin: the straight one-hand sword (A23-128)
	Warrior_Horns = { Weapon = "DarkSword" }, -- Berserker: the dark one-hand sword (A23-128)
	Warrior_Neutral = { Weapon = "Hammer" }, -- Blacksmith
	Mage_Halo = { Weapon = "Staff" }, -- Light Mage
	Mage_Horns = { Weapon = "CrookStaff" }, -- Dark Mage
	Mage_Neutral = { Weapon = "FlaskStaff" }, -- Alchemist (the approved 2D: a staff with a flask)
	Archer_Halo = { Weapon = "Bow" }, -- Ranger
	Archer_Horns = { Weapon = "ShortBow" }, -- Shadow Hunter
	Archer_Neutral = { Weapon = "Baton" }, -- Pet Tamer
}

-- A23-150 7 (user 10/12 night (가); table docs/design/weapon_grip_plan_2026-10-12.md, sheet
-- art/review/grip/grip_plan_sheet_2026-10-12.png): the grip table, one place. Every weapon is a Roblox Tool held in the
-- RIGHT hand (bows too): its part "Handle" hangs on the hand's RightGripAttachment by the engine's RightGrip weld with
-- Tool.Grip = Config.WeaponGrip(kind, handle length). The Handle is the part the fist wraps (the hilt, the shaft, the
-- bow's riser) and its +Y is the weapon's long axis (to the blade / head / orb). Point = where the fist holds the Handle,
-- a share of its length up from its bottom end (the sword just under the guard 0.75, staffs 0.45 so the orb sits higher
-- over the hand, the hammer and the baton low 0.3, the bow's riser in its middle 0.5). Turn = { x, y, z } degrees the
-- Handle is turned in the fist (the grip attachment's axes: +Y = the knuckle line, +Z = towards the wrist): 0 = upright
-- when the arm is forward (Roblox's own hold); the Shadow Hunter's short bow is canted 15 degrees. The Dark Mage's crook
-- staff takes the staffs' row and the short bow the bow's (the user's sheet showed seven kinds). The fist's frame is
-- Roblox's (R15 RightGripAttachment = 0.15 under the hand turned -90 degrees about X); the old per-weapon fist() angle
-- in CharacterVisuals is gone. The swords follow Roblox's ClassicSword (메인 반영 1 10/13, main_apply/classic_sword:
-- Tool.Grip (0, 0, -1.5) on its 4-stud handle mesh; side photo: the fist's middle 74% up the hilt from the pommel end,
-- its top against the guard): 0.75 of our 1.2-stud hilt (the table's first 0.6 left a gap under the guard).
Config.WeaponGrips = {
	Sword = { Point = 0.75 },
	DarkSword = { Point = 0.75 },
	Bow = { Point = 0.5 },
	ShortBow = { Point = 0.5, Turn = { 0, 0, 15 } },
	Staff = { Point = 0.45 },
	CrookStaff = { Point = 0.45 },
	FlaskStaff = { Point = 0.45 },
	Hammer = { Point = 0.3 },
	Baton = { Point = 0.3 },
}

-- (pure) the grip row of a weapon kind (a kind without a row: the sword's)
function Config.WeaponGripOf(kind)
	local rows = Config.WeaponGrips
	local row = type(kind) == "string" and rows[kind] or nil
	return type(row) == "table" and row or rows.Sword
end

-- (pure) the Tool.Grip of a weapon kind whose Handle is len studs long: the grip point (0, (Point - 0.5) x len, 0) on the
-- Handle, turned by Turn. The engine then puts the Handle at hand x RightGripAttachment x Grip:Inverse() - the Handle's
-- frame in the fist = CFrame.Angles(Turn) x CFrame.new(0, -(Point - 0.5) x len, 0)
function Config.WeaponGrip(kind, len)
	local row = Config.WeaponGripOf(kind)
	local point = math.clamp(tonumber(row.Point) or 0.5, 0, 1)
	local turn = type(row.Turn) == "table" and row.Turn or {}
	local angles = CFrame.Angles(math.rad(tonumber(turn[1]) or 0), math.rad(tonumber(turn[2]) or 0), math.rad(tonumber(turn[3]) or 0))
	return CFrame.new(0, (point - 0.5) * (tonumber(len) or 0), 0) * angles:Inverse()
end

function Config.ClassGripKey(classId, faction)
	if type(classId) ~= "string" then return nil end
	if faction == "Halo" or faction == "Horns" or faction == "Neutral" then return classId .. "_" .. faction end
	return classId
end

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
		-- bag / crafting material icons, round 1 (이미지 개발 2026-10-12, 디자인 검수 pass; art/out/s2/icons_bag_cut)
		IconPetal = { Id = "rbxassetid://133887324126001", Size = Vector2.new(512, 512) },
		IconCaptainBadge = { Id = "rbxassetid://79235006547470", Size = Vector2.new(512, 512) },
		IconSeaShell = { Id = "rbxassetid://126461746451387", Size = Vector2.new(512, 512) },
		IconCrystalShard = { Id = "rbxassetid://79705802311397", Size = Vector2.new(512, 512) },
		IconMeadowHerb = { Id = "rbxassetid://86098124636549", Size = Vector2.new(512, 512) },
		IconCopperOre = { Id = "rbxassetid://119596801981491", Size = Vector2.new(512, 512) },
		IconOakLog = { Id = "rbxassetid://122711143611444", Size = Vector2.new(512, 512) },
		IconIronOre = { Id = "rbxassetid://100831679530995", Size = Vector2.new(512, 512) },
		IconSilverOre = { Id = "rbxassetid://114879087694979", Size = Vector2.new(512, 512) },
		IconMoonCrystal = { Id = "rbxassetid://106196598879661", Size = Vector2.new(512, 512) },
		-- round 2 (이미지 개발 2026-10-12, 디자인 검수 pass): crafting ring screen + Crown Dust; IconGlowcap waits for a cutout fix (grey fragment)
		CraftRing = { Id = "rbxassetid://115071977806649", Size = Vector2.new(512, 512) },
		CraftTarget = { Id = "rbxassetid://134156748980991", Size = Vector2.new(512, 512) },
		CraftIngot = { Id = "rbxassetid://133966322294546", Size = Vector2.new(512, 512) },
		IconCrownDust = { Id = "rbxassetid://130666131385080", Size = Vector2.new(512, 512) },
		IconGlowcap = { Id = "rbxassetid://118269985242078", Size = Vector2.new(512, 512) },
		-- round 3 (이미지 개발 2026-10-12, 디자인 검수 pass): pet treat + the four tonics
		IconPetTreat = { Id = "rbxassetid://109038216387583", Size = Vector2.new(512, 512) },
		IconMightTonic = { Id = "rbxassetid://82167218233168", Size = Vector2.new(512, 512) },
		IconGuardTonic = { Id = "rbxassetid://113383235344315", Size = Vector2.new(512, 512) },
		IconLuckyTonic = { Id = "rbxassetid://124851169351640", Size = Vector2.new(512, 512) },
		IconWisdomTonic = { Id = "rbxassetid://131384631272950", Size = Vector2.new(512, 512) },
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
		-- skills18 (10/10): each class's own skill icon per faction (이미지 생성 2); empty Id = the kit icon above
		Skill_Warrior_Q_Halo = { Id = "rbxassetid://120532395379341", Size = Vector2.new(512, 512) },
		Skill_Warrior_Q_Horns = { Id = "rbxassetid://111763129346678", Size = Vector2.new(512, 512) },
		Skill_Mage_Q_Halo = { Id = "rbxassetid://92523085656561", Size = Vector2.new(512, 512) },
		Skill_Mage_Q_Horns = { Id = "rbxassetid://81157543004771", Size = Vector2.new(512, 512) },
		Skill_Archer_Q_Halo = { Id = "rbxassetid://92206547315755", Size = Vector2.new(512, 512) },
		Skill_Archer_Q_Horns = { Id = "rbxassetid://103422334299041", Size = Vector2.new(512, 512) },
		Skill_Warrior_Z_Halo = { Id = "rbxassetid://84642189475299", Size = Vector2.new(512, 512) },
		Skill_Warrior_Z_Horns = { Id = "rbxassetid://96701336601012", Size = Vector2.new(512, 512) },
		Skill_Mage_Z_Halo = { Id = "rbxassetid://117710924786358", Size = Vector2.new(512, 512) },
		Skill_Mage_Z_Horns = { Id = "rbxassetid://82944323163651", Size = Vector2.new(512, 512) },
		Skill_Archer_Z_Halo = { Id = "rbxassetid://116429631383462", Size = Vector2.new(512, 512) },
		Skill_Archer_Z_Horns = { Id = "rbxassetid://107578440852344", Size = Vector2.new(512, 512) },
		Skill_Warrior_X_Halo = { Id = "rbxassetid://78225248119957", Size = Vector2.new(512, 512) },
		Skill_Warrior_X_Horns = { Id = "rbxassetid://100908047802242", Size = Vector2.new(512, 512) },
		Skill_Mage_X_Halo = { Id = "rbxassetid://75459677268571", Size = Vector2.new(512, 512) },
		Skill_Mage_X_Horns = { Id = "rbxassetid://88850195258144", Size = Vector2.new(512, 512) },
		Skill_Archer_X_Halo = { Id = "rbxassetid://87471824044528", Size = Vector2.new(512, 512) },
		Skill_Archer_X_Horns = { Id = "rbxassetid://115987329631921", Size = Vector2.new(512, 512) },
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
		FactionPickSoon = { Id = "rbxassetid://73776589039158", Size = Vector2.new(619, 1024) }, -- A23-114 locked Artisan Guild card (이미지 생성 2, 검수 pick B)
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
		-- the faction pick screen (이미지 생성 2 b3ed558, 검수 OK 10/09): the sky behind the cards (gold left, red dusk right,
		-- the middle / bottom third left calm) and the two mascots beside the cards
		FactionBgA = { Id = "rbxassetid://128364866807552", Size = Vector2.new(1536, 1024) },
		FacMascotHaloA = { Id = "rbxassetid://118792983602547", Size = Vector2.new(612, 1024) }, -- C (hair, user pick 10/10; was 98817628227692)
		FacMascotHornsA = { Id = "rbxassetid://106604703369405", Size = Vector2.new(680, 1024) }, -- D (bat wings, user pick 10/10; was 91053337808874)
		-- Halo town shop signs (이미지 생성 2, 검수 OK 10/10; wall arm + chains + round plate, no words): the shop models' sign
		-- SurfaceGui (메인 반영 1 / 이미지 생성 1). The potion sign only at Halo town's real potion merchant
		HaloSignPotion = { Id = "rbxassetid://122788599616130", Size = Vector2.new(1024, 1024) },
		HaloSignBakery = { Id = "rbxassetid://77116902671887", Size = Vector2.new(1024, 1024) },
		HaloSignJuice = { Id = "rbxassetid://133684891699718", Size = Vector2.new(1024, 1024) },
		HaloSignFlower = { Id = "rbxassetid://93642542767036", Size = Vector2.new(1024, 1024) },
		IconDiary ={ Id = "rbxassetid://82663430349001", Size = Vector2.new(512, 512) }, -- 검수 10/08: the menu square / Diary window = the same King Diary book
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
		EmoGG = { Id = "rbxassetid://127627433457825", Size = Vector2.new(512, 512) }, -- speech bubble "GG" + stars (이미지 생성 2, 디자인 검수 pass 10/12)
		-- chat stickers (SPEC A23-143; 이미지 개발 2026-10-12, 디자인 검수 + 최종 검수 pass): Free = true -> the 5 free stickers; the other 12 + EmoGG come with the 99 R$ sticker pass (server = 게임성 개발 2, screen = 게임성 개발 1)
		EmoHeart = { Id = "rbxassetid://116034339526571", Size = Vector2.new(512, 512) },
		EmoThumbsUp = { Id = "rbxassetid://99361919161124", Size = Vector2.new(512, 512), Free = true },
		EmoHaloHeart = { Id = "rbxassetid://109758163455008", Size = Vector2.new(512, 512) },
		EmoHornSmiley = { Id = "rbxassetid://117420471282516", Size = Vector2.new(512, 512) },
		EmoCrown = { Id = "rbxassetid://97905763474900", Size = Vector2.new(512, 512) },
		EmoSweat = { Id = "rbxassetid://96260426785175", Size = Vector2.new(512, 512) },
		EmoZzz = { Id = "rbxassetid://97893011934493", Size = Vector2.new(512, 512) },
		EmoQuestion = { Id = "rbxassetid://75489472281895", Size = Vector2.new(512, 512), Free = true },
		EmoExclaim = { Id = "rbxassetid://76206051280301", Size = Vector2.new(512, 512), Free = true },
		EmoClap = { Id = "rbxassetid://113688216636921", Size = Vector2.new(512, 512) },
		EmoSparkle = { Id = "rbxassetid://133417532302751", Size = Vector2.new(512, 512) },
		EmoAnger = { Id = "rbxassetid://115342582792713", Size = Vector2.new(512, 512) },
		EmoNice = { Id = "rbxassetid://104631144898653", Size = Vector2.new(512, 512) },
		EmoThanks = { Id = "rbxassetid://79488363906961", Size = Vector2.new(512, 512), Free = true },
		EmoHelp = { Id = "rbxassetid://123531350239231", Size = Vector2.new(512, 512), Free = true },
		EmoOops = { Id = "rbxassetid://78458488744968", Size = Vector2.new(512, 512) },
		EmoLetsGo = { Id = "rbxassetid://75123567431432", Size = Vector2.new(512, 512) },
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
-- A23-95 (user 10/09): the minimap / big map drawn from top-down shots of the real world (메인 반영
-- tools/minimap_capture.py: square tiles, image right = +X east, image up = -Z north). Each tile covers X0..X1 x Z0..Z1
-- studs; MiniMap lays them on its turning canvas over the old code-drawn lands. Trial set (4 tiles, 2026-10-09); the
-- whole map follows when the dressing is done
Config.UIArt.MapTilesFull = false -- true when MapTiles cover the whole world: then the big map (M) draws them too
Config.UIArt.MapTiles = {
	-- crossroads, re-shot with --solid-parasols (its striped stall roofs read as rays from above, 검수 10/09)
	{ Id = "rbxassetid://136217481360826", X0 = -80, X1 = 80, Z0 = -80, Z1 = 80 },
	{ Id = "rbxassetid://133694892661834", X0 = 180, X1 = 340, Z0 = -80, Z1 = 80 }, -- meadow arrival
	{ Id = "rbxassetid://73887725585820", X0 = 210, X1 = 370, Z0 = 70, Z1 = 230 }, -- pond
	{ Id = "rbxassetid://106974672450070", X0 = 760, X1 = 920, Z0 = 26, Z1 = 186 }, -- woods camp
}

Config.UIArt.CardLayout = { -- bundle 2 regions (art/approved.json layout)
	-- A23-57 redraw: the faction cards' Name ribbon (Title), Panel (Perks) and Button - no Desc / Motto strips; the class
	-- card frames' Portrait window (the CLS_* picture fills it), Name, Body and Button
	-- A23-114 locked Artisan card: name on the brass ribbon, "Coming soon" + "Crafting update" on the parchment (the dark oval
	-- plate was too small for the second line at the 11 px floor, UiSandbox 10/10)
	FactionPickSoon = { Title = { 0.25, 0.332, 0.5, 0.05 }, Soon = { 0.18, 0.47, 0.64, 0.09 }, Sub = { 0.2, 0.585, 0.6, 0.05 },
		SubStyle = "ink" },
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
		Halo = "Crown won! Gold, XP +25%%", -- A23-130: to the winning side only (WarService)
		Horns = "Crown won! Gold, XP +25%%",
	},
	WarDraw = "Nobody won the crown this round!",
	GooseResult = {
		Halo = "The Knights rescued the Golden Goose! The shard shines with light again.",
		Horns = "The Horn Legion poached the Golden Goose! The shard turned dark.",
		Tie = "The Golden Goose flew away! It's a tie.",
	},
	-- (GooseNoRival removed by A23-14: a goose with no rival is now a "Team Rescue", texts in Config.Goose.Text)
	KaijuSiren = "Alert! %s is being swallowed by the Crown Shard's darkness! A Kaiju in 10 seconds!",
	KaijuStart = "Kaiju %s is here!",
	KaijuDefeated = "The Knights defeated the Kaiju %s! They share a %s gold reward.", -- (name, gold actually paid: CR-L19)
	KaijuDefeatedNoReward = "The Kaiju %s was defeated.", -- CR-L19: (name) nobody was paid
	KaijuSurvived = "The Kaiju %s survived to the end! A Final Boss is born!",
	SurviveTitle = "Final Boss",
	GrayLegendTitle = "Gray Legend",
	RebirthIntro = "Rebirth lets you pick your Crown Shard again. Which side will you be reborn on?",
	Fall = "Fall: Gold +5%% · black cape",
	Redeem = "Redeem: XP +5%% forever",
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
	EnteredPvP = "PvP zone!",
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
	WeaponAutoSwap = "Needs Lv %d. Now using %s.",
	WeaponAutoSwapEn = "Needs Lv %d. Now using %s.",
	-- A23-34: bare hands (weapon tier 0)
	BareHands = "Bare hands", BareHandsEn = "Bare hands",
	-- A23-74: the first weapon comes right after the Guide's first quest is accepted (the Forge step)
	WeaponFromQuest = "Not sold. Quest reward.",
	WeaponFromQuestEn = "Not sold. Quest reward.",
	WeaponUsableNow = "You can now use %s! Equip it at the Forge or from your Bag.",
	WeaponUsableNowEn = "You can now use %s! Equip it at the Forge or from your Bag.",
	NeedFaction = "Pick a side first.",
	-- ShopService (blacksmith / potion merchant)
	WeaponShopFar = "Too far from the Forge.",
	WeaponNotSold = "The Forge doesn't sell this weapon.",
	WeaponDropOnly = "New weapons drop from monsters!", -- 1-A #2: Config.WeaponShop.Buy == false (a weapon not owned)
	WeaponSellFar = "Too far from the Forge.",
	WeaponSold = "Sold %s! Gold +%s", -- (weaponName, gold)
	BlacksmithPromptAction = "See weapons",
	BlacksmithPromptObject = "Forge",
	PotionShopFar = "Too far from the Potion Seller.",
	-- ⑪ (lines_pack §1-3): the shop windows' greeting line (game dev 1: the top of WeaponShop / PotionShop); calm, no
	-- "hurry / sale" words next to a buy button
	ForgeGreeting = "Otto: Clang, clang… done. Cocoa time.",
	PotionGreeting = "Fizzby: Glug, glug, feel better!",
	PotionStockFull = "You can hold up to %d of each potion.", -- (PotionInventoryCap)
	PotionBought = "Bought %s potion ×%d!", -- (kind, amount)
	PotionPractice = "Cheers! The potion stays in your bag.", -- A23-110: a drink at full HP / MP while the quest step waits for it
	-- A23-130 §2 (server text verdicts 2026-10-11): VitalsService lines (were hard-coded there)
	NoMana = "Not enough MP.",
	PotionKaiju = "You can't use potions as a Kaiju.",
	PotionNone = "No potions left.",
	PotionHPFull = "HP is full.",
	PotionMPFull = "MP is full.",
	-- PvP
	Plundered = "%s stole %s gold from you!\nIf a knight catches the thief within 45 s, you get 120%% back.",
	PlunderGain = "+%s gold in Grudge Sack!", -- (gold)
	PlunderTooSoon = "Too soon to rob them again.",
	HonorGain = "Honor +%d",
	AutoSleepy = "The shard is sleepy… Take a step? (Auto Battle rests in 30 s)", -- P2
	AutoRestOn = "You seem away, so Auto Battle is resting. Move and it starts again.",
	AutoRestOff = "Welcome back! Auto Battle is on again.",
	AutoChoiceWait = "A choice card is waiting. Pick one and Auto Battle starts again.",
	GraduateStart = "Sprout Shield ends in 60 s!", -- A23-18
	GraduateEnd = "Now you can fight the other sides!",
	BoldStrong = "Stronger foe! Points ×2",
	BoldWeak = "Weaker foe: points halved.",
	BountyGain = "Got a %s gold bounty! Honor +%d",
	BountyAnnounce = "[Knights of Light] %s got a %s gold bounty!", -- BB37: AnnounceService.PublicName(p, true)
	-- BB37 (검수): a hidden knight is already "A member of the Knights of Light", so no "[Knights of Light]" prefix
	BountyAnnounceHidden = "%s got a %s gold bounty!",
	BountyAnnounceHiddenEn = "%s got a %s gold bounty!",
	BullyBountyGain = "Got a %s gold bully bounty!",
	MostWanted = "Most Wanted: %s · Bounty %s gold", -- BB37: PublicName(p, true)
	BullyKO = "Bully KO! No reward. ATK -15%%",
	BullyVictim = "A bully knocked you out. You lost nothing!",
	BullyDecay = "Your bully level went down (level %d)",
	BullyNoAuto = "No Auto during bully penalty.", -- A23-22
	BullyAutoOff = "Bully penalty: no Auto, half rewards", -- A23-22 (auto was ON)
	BullyPenaltyEnd = "Bully penalty over! Auto is back.", -- A23-22
	BullyPenaltyEndEn = "Bully penalty over! Auto is back.",
	BullyPenaltyEndNoAuto = "Bully penalty over!", -- auto combat not unlocked yet
	BullyPenaltyEndNoAutoEn = "Bully penalty over!",
	Revenge = "Revenge! ATK +25%%",
	RevengeDone = "Revenge done!",
	-- grudge sack
	SackPaid = "You kept the Grudge Sack! Got %s gold",
	SackLost = "You lost the Grudge Sack!",
	GrudgeRefund = "Stolen gold back: +%s", -- (gold)
	GrudgeReturned = "Stolen gold back: +%s",
	GrudgeMail = "Stolen gold back: +%s", -- P3
	DailyAllDone = "All done for today! Play more if you like.", -- P8
	GhostHoldOk = "Your ghost grabbed the thief! Their hold time +%d s (max +%d s)", -- A23-18
	GhostHoldMax = "Max hold reached.",
	GhostHeld = "Ghost holds you!",
	GhostButton = "Ghost grab ({GhostHold})", -- BB1 key token: the key part shows only on keyboards
	GhostWait = "Grab again in %d s",
	AvengerBonus = "Avenger bonus +%s gold!",
	GrudgeAvengedAll = "%s took the Grudge Sack back from %s!", -- BB37: PublicName(killer, true), PublicName(thief, true)
	-- travel / blocks
	TravelBlockedStars = "Too many Wanted stars to teleport!",
	TravelBlockedCombat = "You can't do that in combat.",
	TravelBlockedSack = "You can't teleport while carrying a Grudge Sack!",
	TravelBlockedKaiju = "A Kaiju can't teleport!",
	Traveling = "Traveling...",
	TravelCancelled = "Travel canceled.",
	BlockedSack = "You can't do that while carrying a Grudge Sack.",
	BlockedKaiju = "You can't do that during a Kaiju event.",
	BlockedStars = "You need zero Wanted stars to do that.",
	BlockedBully = "Not while you are a bully.", -- CR-L9: altar / rebirth to Neutral with bully stacks
	WaitRespawn = "You can do that after you respawn.", -- CR-L30: travel / class / rebirth / altar while dead
	-- faction / class / tickets
	UnderdogSignOn = "Smaller side bonus: +%d gold!",
	SwitchDoneFree = "%s back to 0.", -- (score name)
	SwitchDoneTicket = "You joined the %s! (Ticket used, points kept)",
	SwitchCooldown = "You can switch sides again in %s.",
	NoTicket = "No change ticket.",
	TicketSaving = "Still saving. Try again soon.", -- CR-L25: UseTicket returned "Pending"
	ClassChangedFree = "Class: %s. Back to Lv 1!", -- free change from Lv ClassChange.FreeKeepLevelBelow on
	ClassChangedFreeKeep = "Class: %s (level kept)", -- A23-14 (className)
	ClassFreeKeepLevelF = "Level kept under Lv%d", -- A23-14 client preview (FreeKeepLevelBelow)
	ClassChangeRuleF = "You can change class later in Menu. Free below Lv%d.", -- A23-14 ClassPicker footer (FreeKeepLevelBelow)
	ClassChangedTicket = "Class: %s (ticket used)",
	ClassSame = "You already have that class.",
	ClassNeedSafe = "You can only change class in a safe zone.",
	ClassTicketGot = "You got 1 Class Change Ticket!",
	FactionTicketGot = "You got 1 Side Change Ticket!",
	ProductNotReady = "This item isn't ready yet.",
	-- rebirth
	RebirthNeed = "You need Lv %d to be reborn.",
	RebirthDone = "Reborn! Gold, XP +%d%%", -- A23-14
	RebirthAnnounce = "%s was reborn! (Rebirth #%d)", -- BB37: PublicName(p, true)
	-- quests
	QuestDone = "Extra quest done! +%s gold",
	DailyReady = "Daily quest done! Press [Claim].",
	DailyClaimed = "Daily reward! +%s gold +%s XP",
	DailyChest = "Bonus chest! +%s gold +%s XP",
	DailyChestTicket = "+1 Class Change Ticket!",
	DailyAutoPaid = "Daily rewards! +%s gold",
	VacationClaimed = "Vacation bonus! +%s gold +%s XP",
	-- war
	WarChest = "War chest! +%s gold",
	-- goose
	GooseReward = "Golden Goose reward! +%s gold +%s XP",
	GooseCheer = "Cheer Star %d/5", -- (stars) added to the reward line
	RareToast = "Rare reward! ×5",
	RareAnnounce = "%s got a rare Golden Goose reward!", -- BB37: PublicName(p, true)
	-- kaiju
	KaijuQueued = "Another Kaiju is out. You'll transform when it's over!",
	KaijuReward = "Kaiju hunt reward +%s gold!",
	KaijuSurviveReward = "Survived! +%s gold to vault",
	-- addendum A3 (review fixes)
	AutoUnderAttack = "You're under attack! Hit back with the Attack button", -- M3: auto ON + took PvP damage (once per 60 s)
	EnemyTown = "You can't enter the other side's town!", -- L1: bounced to Crossroads (also Neutral in either town)
	KaijuNoTown = "A Kaiju can't enter towns!", -- ZoneService (was its hard-coded fallback)
	WaterRescue = "Splash! Back on dry land.", -- zone_check_halo #62: ZoneService water rescue (Config.WaterRescue.Toast)
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
	-- 게임성 검수 10/12: craft fame joins the Artisan board, so its cap is 100 - only while crafting is on (Config.WeekCapOf;
	-- off = the scroll-only 60 as before)
	CraftWeekCap = { Artisan = 100 },
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
		PvPTabNote = "Goes up when you KO weaker, away or new players. Top 3 (3+ points) become outlaws.",
		PvPTabNoteEn = "Goes up when you KO weaker, away or new players. Top 3 (3+ points) become outlaws.",
		RewardTabNote = "Top 3: XP and drops +10% next week", RewardTabNoteEn = "Top 3: XP and drops +10% next week",
		Ineligible = "New players join the ranking after 3 days and 30 min of play",
		IneligibleEn = "New players join the ranking after 3 days and 30 min of play",
		Private = "Private servers do not earn ranking points", PrivateEn = "Private servers do not earn ranking points",
		OutlawTag = "Outlaw", OutlawTagEn = "Outlaw",
		OutlawChip = "Outlaw: no Auto Battle · half XP and drops (until Monday)",
		OutlawChipEn = "Outlaw: no Auto Battle · half XP and drops (until Monday)",
		RewardChip = "This week's %s #%d: XP and drops +10%% (until Monday)", -- (board name, rank)
		RewardChipEn = "This week's %s #%d: XP and drops +10%% (until Monday)",
		OutlawStart = "Outlaw week: no Auto, half rewards, 2x bounty",
		OutlawStartEn = "Outlaw week: no Auto, half rewards, 2x bounty",
		OutlawEnd = "Outlaw week over! Auto is back.",
		OutlawEndEn = "Outlaw week over! Auto is back.",
		OutlawEndNoAuto = "Outlaw week over!", -- auto combat not unlocked yet
		OutlawEndNoAutoEn = "Outlaw week over!",
		-- (still a bully at the end of the outlaw week: no line here; CombatService says BullyPenaltyEnd when the stacks go)
		OutlawNoAuto = "No Auto for outlaws.",
		OutlawNoAutoEn = "No Auto for outlaws.",
		OutlawAutoOff = "Outlaw: no Auto, half rewards",
		OutlawAutoOffEn = "Outlaw: no Auto, half rewards",
		RewardStart = "%s #%d! New title · XP, drops +10%%", -- (board name, rank)
		RewardStartEn = "%s #%d! New title · XP, drops +10%%",
		-- a top-3 player who switched faction since: the title is given, the bonus waits for that faction
		RewardStartOff = "%s #%d! New title", -- (board, rank, faction)
		RewardStartOffEn = "%s #%d! New title",
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
			out[board] = int(rank[board], 0, Config.WeekCapOf(board) or 1e9)
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

-- EG05 Fun Tips (story_depth (나), 검수 2026-10-10; A23-52 jokes for the grown-ups, no real brand or person): about one KO in
-- `Every` shows one of these instead of the situation tip; the first `SkipFirst` KOs of an account never do (a new player
-- reads the real tip first). CombatService counts the KOs (data.KOs, saved) and sends the line in the KO fx as `Tip`; the
-- client's KO screen shows `Tip` when it is there (game dev 1). FunTip is pure: koCount = this KO counted, roll / pick in [0, 1).
Config.Data.Defaults.KOs = 0
Config.Death.Fun = {
	Every = 15,
	SkipFirst = 3,
	Lines = {
		"Tip: Slimes are 90% jelly and 10% attitude.",
		"Tip: Skeletons can't jump. Please don't tell them.",
		"Tip: Reading tips gives no XP. We checked.",
		"Tip: The goblins had a meeting about this tip. Same plan as last time.",
	},
}
function Config.FunTip(koCount, roll, pick)
	local F = Config.Death.Fun
	if type(koCount) ~= "number" or koCount ~= koCount or koCount <= F.SkipFirst then return nil end
	if type(roll) ~= "number" or roll ~= roll or roll < 0 or roll >= 1 / F.Every then return nil end
	local n = #F.Lines
	if n == 0 then return nil end
	local i = 1 + math.floor(math.clamp(type(pick) == "number" and pick == pick and pick or 0, 0, 0.999999) * n)
	return F.Lines[i]
end

-- EG06 Goblin Notes (story_depth (나)): one line under the News window, in its own colour, new every week (the KST week of
-- Config.DayIndex; the client shows Config.GoblinNote(Config.DayIndex(os.time())) - game dev 1). Patch-note jokes.
Config.GoblinNotes = {
	Title = "Goblin Notes",
	Lines = {
		"Fixed: goblins stealing dust. (Not fixed.)",
		"Known issue: slimes are squishy. Working as intended.",
		"Goblins now steal 0% more. Same as before.",
	},
}
function Config.GoblinNote(dayIndex)
	local lines = Config.GoblinNotes.Lines
	if type(dayIndex) ~= "number" or dayIndex ~= dayIndex or dayIndex == math.huge or dayIndex == -math.huge or #lines == 0 then
		return lines[1]
	end
	return lines[1 + math.floor(dayIndex / 7) % #lines]
end

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
	Pet = "BabySlime", -- the species granted (Config.Pets.Species; its levels / XP: Config.Pets)
	SwingStyle = "PetHeadbutt", -- basic attack Fx: the pet runs to the target, headbutts, comes back
	SkillStyle = "PetDash", -- skill Q Fx: the pet dashes into the target area
	Text = {
		PetName = "Baby Slime", PetNameEn = "Baby Slime",
		PetGot = "New pet: Baby Slime!",
		PetGotEn = "New pet: Baby Slime!",
		-- once, for a save that was the artisan hunter before A23-39 (with one free class change)
		Became = "You're a Pet Tamer now! +1 ticket",
		BecameEn = "You're a Pet Tamer now! +1 ticket",
		-- below Config.ClassChange.FreeKeepLevelBelow a free change keeps the level anyway (no ticket button there)
		BecameFree = "You're a Pet Tamer now!",
		BecameFreeEn = "You're a Pet Tamer now!",
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
-- PET-2: XPPerKill = pet XP for every kill its owner is paid for (auto combat too), Lv n -> n+1 needs XPPerLv x n.
-- Species = the species the game knows (PetService equips only these; a saved unknown one is kept). PET-2b: an
-- XP-only PetList goes at most once every ListEvery seconds (a level change at once); a pet line waits NoticeAfter
-- seconds so it comes after the quest's own lines (with a window open the toasts show one line at a time)
Config.Pets = {
	MaxLv = 10,
	XPPerKill = 1,
	XPPerLv = 15,
	-- a summoned pet (Pets.List[uid].Roll.Spd, whole %; 게임성 개발 3, docs/design/tamer_server_2026-10-12.md §4): its
	-- bonus is Spd % at Lv1 -> Spd % + RollGrow at MaxLv (the baby slime's own slope, 7 -> 10)
	RollGrow = 0.03,
	ListEvery = 1,
	NoticeAfter = 0.5,
	Species = {
		-- Name / Icon: the pet window (PetWindow.luau) when the pet has no story name
		BabySlime = { Speed = { 0.07, 0.10 }, Name = "Baby Slime", Icon = "IconPetBabySlime" },
	},
}

-- the walk speed bonus of a pet (0 for none / an unknown species); levels clamp to 1..MaxLv. roll = a summoned pet's
-- Roll.Spd (whole %, cut to Config.SaveV4.PetRollSpd): Lv1 = roll %, MaxLv = roll % + Pets.RollGrow; nil / 0 = the
-- species' own line
function Config.PetSpeedBonus(species, lv, roll)
	local P = Config.Pets
	local def = type(species) == "string" and P.Species[species] or nil
	if type(def) ~= "table" or type(def.Speed) ~= "table" then return 0 end
	if type(lv) ~= "number" or lv ~= lv then lv = 1 end
	lv = math.clamp(math.floor(lv), 1, P.MaxLv)
	local a, b = def.Speed[1], def.Speed[2]
	if type(roll) == "number" and roll > 0 then
		local range = Config.SaveV4.PetRollSpd
		a = math.clamp(roll, range[1], range[2]) / 100
		b = a + P.RollGrow
	end
	return a + (b - a) * (lv - 1) / math.max(1, P.MaxLv - 1)
end

-- studs per second for a class with a pet (species, level; nil = none); kaiju = an Active kaiju (no pet bonus);
-- petRoll = a summoned pet's Roll.Spd (nil / 0 = none); petAcc = the following pet's PetAcc gear bonus (a fraction, ⑥ gear:
-- added to the pet's bonus, never for a kaiju or without a pet; the Speed.Cap still holds)
function Config.WalkSpeed(classId, petSpecies, petLv, kaiju, petRoll, petAcc)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	local base = Config.Player.WalkSpeed
	local pet = kaiju == true and 0 or Config.PetSpeedBonus(petSpecies, petLv, petRoll)
	if kaiju ~= true and pet > 0 and type(petAcc) == "number" and petAcc == petAcc and petAcc > 0 and Config.FeatureOn("Gear") then
		pet += math.min(petAcc, Config.Gear.PetAccMax) -- ⑥ gear (게임성 개발 3)
	end
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
		-- the attendance window (AttendanceUI, game dev 1, plan 10/13 §1-A #5): the 7 slots, [Claim], the next slot. No
		-- clock or countdown on it (contract: "판에 시계 숫자 없음"); a missed day never resets anything (A23-77)
		Title = "Daily Gifts",
		Tile = "Gifts", -- the HUD [Menu] square
		Day = "Day %d",
		Claim = "Claim!",
		Wait = "Come back tomorrow!", -- the button once today's gift is taken
		Today = "Today · Day %d: %s", -- (slot, the parts with Gold / XP / Item / ItemN joined " · ")
		Next = "Tomorrow · Day %d: %s",
		WeekDone = "Week done! A new week starts tomorrow.",
		Collected = "Days collected: %d",
		Goal = "%d days: %s", -- the next milestone (days, what it gives joined " + ")
		GoalTitle = "%s title",
		Note = "Missed a day? No problem. Nothing resets.",
		Box = "Weekly Box",
	},
}
Config.TitleDefs.Regular ={ Name = "Regular", NameEn = "Regular", Color = Color3.fromRGB(130, 205, 255) }
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
	-- A23-113 #2: the first KO of the King's Hop (KO1), once per account; the steps are the quest's own five, in order:
	-- the King's hit, a potion bought, put in a quick slot, drunk, the King beaten (a step an early action already passed
	-- still logs, in order, when the quest passes it)
	FirstKO = { Once = true, Steps = { "KO", "PotionBought", "SlotSet", "PotionUsed", "KingWon" } },
}
-- A23-113 #2: story quests whose steps are a funnel's steps (quest id -> funnel name; step i done = Steps[i]; StoryQuestService.StepDone)
Config.Analytics.QuestFunnels = { KO1 = "FirstKO" }
-- A23-113 #2: minutes of play (data.PlaytimeSeconds) it took to reach Level (the custom event MinutesToLv5, once per account,
-- when the level is reached; field 1 = the faction)
Config.Analytics.TimeToLevel = { Level = 5, Event = "MinutesToLv5" }
-- A23-113 #5: every PvP KO -> the custom event PvPResult (value = the winner's faction size-scale multiplier, 1.0-1.6; fields =
-- winner faction, loser faction, "<winner level band>><loser level band>"), at most one per killer per this many seconds
Config.Analytics.PvPResultGap = 1
-- A23-113 (검수 2026-10-10): how many times the same player is KO'd by other players in one KST day (to see Lv15-20 sprouts hit again
-- and again in the Goblin Woods on the 10/17 test): the custom event PvPKOedDay is logged when that day's count reaches a step
-- (value = the count; fields = the victim's level band and zone). The count is saved with the account (data.Telemetry.PvPKO).
Config.Analytics.PvPKOedDay = { Event = "PvPKOedDay", Steps = { 1, 3, 5, 10, 20 } }
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
	Perf = "Perf", -- the phone / PC frame + memory summary of the last window (Config.Analytics.Perf, system_review 더하기 7)
}
Config.Analytics.InviteSources = { "Menu", "PlayerList", "GooseWin", "WarWin" }
Config.Analytics.PassIds = { "XP2", "Gold2", "VIP", "Look" } -- "Pass" args besides Config.GamePasses / Config.Looks ids
-- review 2026-10-08 (one client must not flood the whole game's analytics budget): ClientMetric calls LOGGED a minute per
-- player, and the ids logged once a session; every accepted call still fires TelemetryService.ClientMetric (no limit)
Config.Analytics.ClientMetricPerMinute = 10
Config.Analytics.ClientMetricOnce = { "OptIn", "WelcomeBackGo" }
-- ClientMetric "Perf" (검수 2026-10-09, system_review_round1 더하기 7; docs/design/phone_perf_server_2026-10-09.md): the one argument
-- is a table { D = device, F = average fps, W = lowest second's fps, M = memory MB, Q = graphics quality level } of the last
-- window (all whole numbers; D one of PerfDevices; W <= F). Logged (own limit, not the shared minute budget) as PerfFps (value F),
-- PerfFpsLow (value W, only when W < Low) and PerfMem (value M); fields = device, the zone now ("Other" outside the zone list),
-- "Q<level>". Every = the seconds between two samples the client sends; MinGap = the seconds the server needs between two.
Config.Analytics.PerfDevices = { "Phone", "Tablet", "Desktop", "Console" }
Config.Analytics.Perf = { Every = 120, MinGap = 60, Low = 20, MaxFps = 240, MaxMem = 16384, MaxQuality = 10 }
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
	-- A23-130 (fix/lesstext: PauseCard shows only the chapter card): the kinds sent at all; false = not sent and no MinGap
	-- taken (Daily still offers the notification opt-in through Fx OptInMoment)
	Cards = { Chapter = true, Daily = false, War = false },
	WelcomeAfter = 6 * 3600, -- "Welcome back!" when the last leave was at least this long ago (after the first mission)
	WelcomeDelay = 4, -- s after the join (the HUD is up by then)
	NextZone = "GoblinWoods", -- the next-goal row "Lv10 · Goblin Woods" travels there
	SeasonFallback = "SlimeMeadow", -- a seasonal field (no Travel destination): its entrance field
	-- quest guide spots that are not zones / landmarks ("Home" = the player's own town)
	-- (A23-141: no Goose - the egg hunt is joined from anywhere with the Join button, ReturnService gives it no zone)
	GuideZones = { Blacksmith = "Crossroads", HaloBridge = "Crossroads", HornsBridge = "Crossroads", OwnTown = "Home" },
	-- A23-86 F: the zone a next-goal ladder row (QuestService GoalKind) leads to; other kinds use the level's hunting zone
	GoalZones = { Rebirth = "Crossroads", RebirthReady = "Crossroads", Commission = "Crossroads", Commission4 = "Crossroads",
		Commission5 = "Crossroads", Commission6 = "Crossroads", Crystal = "Crossroads", IronDrop = "SlimeMeadow" },
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
-- A23-64 ② choice afterglow (zone_check_halo #39, 검수 2026-10-10): after a good / evil pick StoryQuestService sends Fx
-- "Afterglow" { UserId, Side = "Good" | "Evil", Seconds, Private }; game dev 1 draws round gold sparkles (Good) or soft
-- purple smoke puffs (Evil) at that player's feet for Seconds (a round soft glow only: user 10/07). In a PvP area only
-- the chooser gets it (Private = true). From = which picks glow: story picks, choice cards, the finisher card.
Config.Afterglow = {
	Enabled = true, -- A23-64 ②: the afterglow switch
	Seconds = 60, -- A23-64 ②: how long it stays at the feet
	From = { Story = true, Card = true, Finisher = true },
}
-- A23-64 ① townsfolk notice you (zone_check_halo #39, 검수 2026-10-10). The town people are Models tagged Tag (TownNpcs:
-- Config.TownNpcs Folk entries, attribute FolkId); a town person's Town = the Config.Zones id it stands in: its attribute
-- Town when set, else Config.ZoneAt(its pivot position).Id ("HaloTown" | "HornsTown" | "Crossroads"). Game dev 1's
-- TownReact shows one line over one of them while the local player is within Range: once every Every s a person, Show s
-- long, never while a shop or story window is open. Config.TownReactLines picks the lines: the player's faction rank
-- (Config.GetTitle), lean (My Way: attribute MyWay) and, in the player's own town only (Town == Config.HomeZoneId(faction):
-- the artisan guild's is the Crossroads), the last town pick (attribute TownPick "<quest id>:Good|Evil",
-- StoryQuestService), said only to the quest's own factions (StoryQuests.Defs[id].Factions). Lines never change a score.
-- Easy kid English, 12 words at most, nothing scary.
Config.TownReact = {
	Enabled = true,
	Tag = "TownFolk",
	Every = 30, -- s between two lines of one town person (A23-64 ①)
	Range = 30, -- studs: a town person speaks only to a player this close
	Show = 4, -- s the bubble stays up
	PickFirst = 600, -- s: a new TownPick is said first (once) for this long; after that it is one of the random lines
	-- the town picks in the order they open: only these quests' picks are remembered (StoryQuestService saves the last
	-- one as Story.TownLast); an old save's TownPick = the last of these with a saved pick
	Order = { "S6", "H1", "R1", "H2", "R5", "H3", "R3", "M3_4", "H5", "R6", "OathH", "OathR", "H6", "R7", "GW8" },
	-- every line the town people say (a table named Text: tools/test_story_text.py checks it too)
	Text = {
		-- by faction rank 1..5 (Config.Titles: Squire .. Archangel / Rascal .. Demon King); Neutral = the artisan guild
		Rank = {
			Halo = {
				{ "Welcome, little Squire!", "A new Halo! Hello there!" },
				{ "Oh! A real Knight! Shiny!", "Hi, Knight! Thanks for your help." },
				{ "A Paladin! The kids love you!", "Paladin! Our town feels so safe." },
				{ "A Saint is here! Everyone, wave!", "A Saint! My grandma will not believe this!" },
				{ "The Archangel! I can't believe it!", "Archangel! The whole town is cheering!" },
			},
			Horns = {
				{ "A little Rascal! Hide the cookies!", "Hey, Rascal! No pranks today, okay?" },
				{ "A Raider! I'm watching you…", "Raider! Hands off my snacks!" },
				{ "A Warlord? Gulp. Hello there!", "Warlord! Please don't take my lunch!" },
				{ "The Dread Lord! I'll be good, I promise!", "Dread Lord! Have a free muffin!" },
				{ "The Demon King! Everyone, bow!", "Demon King! Take my snacks. All of them!" },
			},
			Neutral = { { "A guild crafter! Can you fix my cart?", "Hi, crafter! Busy day?" } },
		},
		-- by lean: Config.MyWay.Names ids (2+ story picks; the player attribute MyWay holds the name)
		Lean = {
			TrueKnight = { "You always help. Thank you!", "A true knight! Always so kind." },
			RebelAngel = { "A Halo with a sneaky grin? Hmm!", "Halos don't do that… do they?" },
			ProudRascal = { "Trouble again? Classic you!", "Lock the cookie jar! Here comes trouble!" },
			SoftDevil = { "Huh? A NICE devil? …Suspicious.", "You helped again? You ARE a Horn, right?" },
			BalanceWalker = { "Kind one day, sneaky the next!", "Which side are you on today?" },
		},
		-- the last town pick's line by quest id (one per Order id); said only to the quest's own factions
		-- (StoryQuests.Defs[id].Factions)
		Good = {
			S6 = "The new kids say you helped them. Thank you!",
			H1 = "You told the truth! It was just birthday jelly!",
			R1 = "A fireworks show? Thanks for telling us!",
			H2 = "You brought the lantern back! The plaza glows again!",
			R5 = "You gave Rose her sack back? How nice…",
			H3 = "You helped someone new! Sir Gleam is proud.",
			R3 = "A surprise party? You are full of surprises!",
			M3_4 = "Pip's lamp glows in the woods. That was you!",
			H5 = "No forms, just help! Bright says thanks!",
			R6 = "A brand-new plan? Rose can't stop talking about it!",
			OathH = "You guard the small ones. We feel safe!",
			OathR = "A Horn who guards little ones? Huh. Nice!",
			H6 = "A sprout statue! Small heroes count too!",
			R7 = "Best lava party ever! Thanks for inviting everyone!",
			GW8 = "Thanks for the town fund! New benches for everyone!",
		},
		Evil = {
			S6 = "The new kids keep calling you boss. Hmm…",
			H1 = "Did you hear? The Horns are up to something!",
			R1 = "The Halos have a secret plan! Everyone says so!",
			H2 = "Is that our town lantern in your window?",
			R5 = "Finders keepers! Rose is still looking, you know.",
			H3 = "The cat is up the tree again. Was that you?",
			R3 = "Prank 201! Same as 200! Classic!",
			M3_4 = "Our vault shines! The goblins look a bit sad.",
			H5 = "Three more forms? Bright is still filling them in!",
			R6 = "Plan B again? We heard it. LOUDLY.",
			OathH = "Bow to no one? Bold words for a Halo!",
			OathR = "Rascals bow to no one! That's the spirit!",
			H6 = "Our statue got SO big! Is it yours?",
			R7 = "VIP only? I wasn't invited… sniff.",
			GW8 = "A bigger vault? It's bigger than my house!",
		},
		-- a faction's own pick line where both towns share a quest (S6: the Horns card is about the den's gold)
		FactionPick = {
			Horns = {
				Good = { S6 = "You shared snacks with the den? Yum, thanks!" },
				Evil = { S6 = "Still counting your gold? Twice?" },
			},
			-- the artisan guild's own M3_4 card: A = a real lamp, B = sell the dust back (not the vault)
			Neutral = {
				Good = { M3_4 = "A real lamp for the goblins? So kind!" },
				Evil = { M3_4 = "Sold the dust back? Business is business!" },
			},
		},
		-- A23-113 #6 (게임성 개발 3, 2026-10-10; the town people know my lean): the five Halo Citadel people say these in their OWN
		-- voice instead of the shared lines above (Config.TownReactLines(p) with p.Npc = the body's attribute HHC_TownNpc = the
		-- Config.TownNpcs entry id). Rank.Halo / Rank.Horns = one line per faction rank 1..5, Rank.Neutral = the guild; Lean = one
		-- line per Config.MyWay.Names id. No entry for an id (or no line in a group) = the shared lines. Bright is she (A23-59).
		Npc = {
			Bright = { -- the town guide: warm and bubbly
				Rank = {
					Halo = { "Welcome, Squire! I'm Bright. Stay shiny!", "Knight! Your halo is glowing today!",
						"Paladin! I told everyone you'd do it!", "A Saint! May I stand next to you?", "Archangel! I'm too happy to talk!" },
					Horns = { "A Rascal in our town? Behave, okay?", "Raider! You may visit. Just don't grab!",
						"Warlord! Please wipe your boots first.", "Dread Lord! Welcome! Please be gentle with the flowers.",
						"Demon King! Hello! The tea is warm." },
					Neutral = "A guild crafter! Our lamps need fixing!",
				},
				Lean = {
					TrueKnight = "You always help. I tell everyone about you!",
					RebelAngel = "A halo with a wink? I won't tell. Maybe.",
					ProudRascal = "Trouble again? I'll count the cookies!",
					SoftDevil = "A kind Horn? Come in, friend!",
					BalanceWalker = "Kind today, sneaky tomorrow? I'll keep guessing!",
				},
			},
			Gleam = { -- the town knight: polite, a little stiff, proud of his armor
				Rank = {
					Halo = { "Welcome, Squire. Stand tall!", "Knight! Your armor shines. Well done.", "Paladin! It is an honor.",
						"A Saint! I must polish my armor.", "Archangel! Sir Gleam salutes you!" },
					Horns = { "A Rascal! Halt. Hmm. Hello.", "Raider! Keep your hands to yourself.", "Warlord! I do not bow. Quite.",
						"Dread Lord! I shall stay polite. Barely.", "Demon King! A knight stays calm. Gulp." },
					Neutral = "A crafter! My armor needs a dent fixed.",
				},
				Lean = {
					TrueKnight = "A true knight's heart. Well done!",
					RebelAngel = "A halo with a wink? Not very knightly!",
					ProudRascal = "Trouble follows you. I follow too.",
					SoftDevil = "A gentle Horn? A knight respects that.",
					BalanceWalker = "Light or dark? I can't tell today.",
				},
			},
			Folk3 = { -- the baker granny: warm, always offering a bun
				Rank = {
					Halo = { "Welcome, dear Squire! Have a bun.", "Knight! Come in, the buns are warm!", "Paladin! A fresh loaf for you!",
						"A Saint in my shop! Take two!", "Archangel! My best cake is yours!" },
					Horns = { "A Rascal! Eyes off the cookies, dear.", "Raider! Pay for the buns, please!", "Warlord! One bun each. No more!",
						"Dread Lord! Even you want a muffin?", "Demon King! Sit. Eat. Be nice." },
					Neutral = "A crafter! Can you fix my oven?",
				},
				Lean = {
					TrueKnight = "Such a kind child. Here, a bun!",
					RebelAngel = "A halo with a grin? Eat your crust.",
					ProudRascal = "Trouble again? Sit and eat first.",
					SoftDevil = "A nice Horn? Take extra jam!",
					BalanceWalker = "Kind or naughty? Both like cake!",
				},
			},
			Folk1 = { -- the juice man: jolly, fresh-squeezed puns
				Rank = {
					Halo = { "Squire! Fresh juice for the new face!", "Knight! Orange or berry?", "Paladin! Squeezed this morning, just for you!",
						"A Saint! This one is on the house!", "Archangel! Best juice, best day!" },
					Horns = { "A Rascal! No pouring it on heads!", "Raider! Pay first, then sip!", "Warlord! Easy on the cups, please!",
						"Dread Lord! Berry juice looks great on you!", "Demon King! One juice, extra sweet!" },
					Neutral = "A crafter! My juicer squeaks. Help?",
				},
				Lean = {
					TrueKnight = "Always helping! Have a free sip!",
					RebelAngel = "A halo and a grin? Fun mix!",
					ProudRascal = "Trouble again? Juice first!",
					SoftDevil = "A sweet devil! Mango for you!",
					BalanceWalker = "Kind or sneaky? Mixed juice for you!",
				},
			},
			PotionHalo = { -- the Halo potion seller: shiny bottles, careful with them
				Rank = {
					Halo = { "Welcome, Squire! Bottles are cheap today.", "Knight! Stay healthy out there!", "Paladin! You almost never need me!",
						"A Saint! Even you drink water, right?", "Archangel! Please don't sneeze on my bottles!" },
					Horns = { "A Rascal! No tasting the blue one!", "Raider! Pay for each bottle, please!", "Warlord! Don't squeeze my bottles!",
						"Dread Lord! Red is for HP. Be gentle.", "Demon King! One potion, one coin. Fair?" },
					Neutral = "A crafter! Want to swap recipes?",
				},
				Lean = {
					TrueKnight = "A kind one! Take a sip of luck!",
					RebelAngel = "A halo that winks? Hmm!",
					ProudRascal = "Trouble again? Careful with the glass!",
					SoftDevil = "A nice Horn! Rare, like my gold bottle.",
					BalanceWalker = "Kind, sneaky, kind… keep it up!",
				},
			},
		},
	},
}

-- A23-64 ①: what one town person may say to the local player now (game dev 1's TownReact). p = { Faction, Honor, Infamy,
-- MyWay (the player attribute), TownPick (the player attribute), Town (the town person's Config.Zones id), Npc (A23-113: the
-- body's attribute HHC_TownNpc = its Config.TownNpcs entry id; the five Halo people have lines of their own, Text.Npc) }. Returns the
-- lines to pick from (rank + lean + the town pick; empty = stay quiet) and the town pick's own line (nil = none) so a new
-- pick can be said first. The town pick is said only in the player's own town (Town == Config.HomeZoneId(Faction)) and
-- only to its quest's factions (StoryQuests.Defs[id].Factions; no Factions = everyone).
function Config.TownReactLines(p)
	local R = Config.TownReact
	local out = {}
	if type(R) ~= "table" or R.Enabled ~= true or type(R.Text) ~= "table" or type(p) ~= "table" then return out, nil end
	local T = R.Text
	local f = p.Faction
	if f ~= "Halo" and f ~= "Horns" and f ~= "Neutral" then return out, nil end
	local _, rank = Config.GetTitle(f, tonumber(p.Honor) or 0, tonumber(p.Infamy) or 0)
	-- A23-113 #6: a town person with lines of his / her own (T.Npc[p.Npc]: the five Halo Citadel people) says that one line of a
	-- group instead of the shared ones; a group without an own line falls back to the shared lines
	local own = type(p.Npc) == "string" and type(T.Npc) == "table" and type(T.Npc[p.Npc]) == "table" and T.Npc[p.Npc] or nil
	local ownRank = own and type(own.Rank) == "table" and own.Rank[f] or nil
	local ownLine = nil
	if type(ownRank) == "string" then
		ownLine = ownRank
	elseif type(ownRank) == "table" and #ownRank > 0 then
		ownLine = ownRank[math.clamp(rank, 1, #ownRank)]
	end
	if type(ownLine) == "string" then
		table.insert(out, ownLine)
	else
		local byRank = type(T.Rank) == "table" and T.Rank[f] or nil
		if type(byRank) == "table" and #byRank > 0 then
			for _, line in byRank[math.clamp(rank, 1, #byRank)] or {} do table.insert(out, line) end
		end
	end
	for id, name in type(Config.MyWay) == "table" and Config.MyWay.Names or {} do
		if name == p.MyWay then
			local ownLean = own and type(own.Lean) == "table" and own.Lean[id] or nil
			if type(ownLean) == "string" then
				table.insert(out, ownLean)
			elseif type(T.Lean) == "table" then
				for _, line in T.Lean[id] or {} do table.insert(out, line) end
			end
		end
	end
	local id, side = string.match(type(p.TownPick) == "string" and p.TownPick or "", "^([%w_]+):(%a+)$")
	if not id or (side ~= "Good" and side ~= "Evil") or p.Town ~= Config.HomeZoneId(f) then return out, nil end
	local def = type(Config.StoryQuests) == "table" and Config.StoryQuests.Defs[id] or nil
	if type(def) ~= "table" or (type(def.Factions) == "table" and not def.Factions[f]) then return out, nil end
	local own = type(T.FactionPick) == "table" and type(T.FactionPick[f]) == "table" and T.FactionPick[f][side] or nil
	local line = (type(own) == "table" and own[id]) or (type(T[side]) == "table" and T[side][id]) or nil
	if type(line) ~= "string" then return out, nil end
	table.insert(out, line)
	return out, line
end
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
		Away = "Your friend is far away.",
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
-- 검수 10/10 (조사 '피할 것 6'): what my drop rows are multiplied by now (LootService: the bully / outlaw penalty x the
-- weekly top 3 reward; never the jackpot rule), with short reasons. s = { BullyStacks, Outlaw, RankReward } (player
-- attributes). x1 = no line in the bag's 'What Monsters Drop'. Pure
function Config.DropsNow(s)
	s = type(s) == "table" and s or {}
	local mult, why = 1, {}
	local pen = type(Config.Bully) == "table" and Config.Bully.Penalty or nil
	if type(pen) == "table" and ((tonumber(s.BullyStacks) or 0) >= 1 or s.Outlaw == true) then
		mult *= tonumber(pen.DropMult) or 1
		table.insert(why, s.Outlaw == true and "Outlaw" or "Bully")
	end
	if type(s.RankReward) == "string" and s.RankReward ~= "" and type(Config.Ranking) == "table" then
		mult *= tonumber(Config.Ranking.RewardMult) or 1
		table.insert(why, "Top 3 this week")
	end
	return mult, why
end

Config.QuestBook = {
	DoneMax = 80, -- every main (19) + every sub (~45) of a finished save still fits (검수 2026-10-08; 60 -> 80 with the daily intro, A23-104)
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
	Kinds = {
		-- A23-87 (검수 2026-10-09): a Flower Slime kill sometimes squishes a flower (KillCards.FlowerPatch). Good = a little
		-- XP (Reward.XP: ChoiceCard pays it never 2x), Evil = 2 petals (a sell material)
		FlowerPatch = { Title = "A flower got squished!",
			Good = { Label = "Replant it", Reward = { XP = 6 } },
			Evil = { Label = "Pick the petals", Reward = { Item = "Petal", N = 2 } } },
	},
	Text = {
		GoodDone = "Kind choice!",
		EvilDone = "Sneaky choice!",
		Score = "%s +%d", -- ("Honor" | "Infamy", points)
		XP = "+%s XP", -- A23-87: a Reward.XP (never 2x)
		Full = "Your shard is full for today. Come back tomorrow!", -- (the same line as Config.Deeds.Text.Full)
	},
}
Config.RateLimits.CardAction = 0.3
-- gameplay_plan 2-A #3 (게임성 개발 1, 2026-10-13): the shared choice card window (ChoiceCardUI.luau, Panels window
-- "ChoiceCard") draws both the ChoiceCard cards (Fx "Card") and the field boss finisher card (Fx "FinisherCard": its
-- words stay Config.Finisher.Cards[kind].Text). Screen = this window's own words; the hint lines are the finisher's
-- (Config.Finisher.Text HintNeutral / HintFull / HintZero), the score lines Config.Finisher.Text Score / ScoreDown.
-- Later = s a closed saved card waits before it opens again on a calm screen.
Config.ChoiceCard.Screen = {
	Title = "Make a choice", -- a card without its own title
	Item = "+%d %s", -- (count, item name)
	Gold = "+%s gold",
	Seconds = "%ds", -- the timed card's countdown
	Later = 30,
	-- the score names on the card (the cards send the stat key; A23-166: Infamy shows as "Mischief", the key stays)
	Stat = { Honor = "Honor", Infamy = "Mischief" },
}
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
		[6] = { Gold = 30000, Items = { KnightCrest = 30, Bone = 60, CaptainBadge = 1 }, ShowLevel = 25 }, -- Lv30 (the Captain's Badge: Captain Clatter's weekly gift, 검수 2026-10-09)
	},
	Text = {
		Done = "%s equipped!",
		NeedLevel = "You need Lv %d.",
		NeedMaterials = "Not enough materials.",
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
-- #45 Lost & Found (content_beyond_10min C; 게임성 개발 3, 2026-10-10; docs/design/lost_found_server_2026-10-10.md,
-- LostFoundService). A monster in a zone that has an item sometimes drops what somebody lost: the player's own kills
-- are counted (nothing below From, rising evenly to sure at Sure, then the count starts again), one thing is held at a time,
-- DayCap finds a KST day. A find opens the item's ChoiceCard (Good = give it back, Evil = the finder's fee, or - for what is
-- not a child's - keep it as a trophy); the card pays nothing, its points go through Deeds. The pick sends the player to the
-- Lost & Found bench (Bench) or to the own town (the vault); arriving pays RewardMinutes of hunting at the player's level:
-- Good = that much XP + Reward.Good.Give (+ one FirstScroll on the first find of a day), Evil = that much gold (all of it never
-- 2x). The numbers are PROPOSED (검수 decides). OFF until the quest window draws the Kind "Find" row (game dev 1) and the
-- four item icons are in (image session 2); switched on through Config.LostFound.Enabled (or the live switchboard).
Config.Data.Defaults.LostFound = { Day = 0, N = 0, K = 0 }
Config.LostFound = {
	Enabled = false,
	From = 60, -- kills before the first chance (about 5 minutes at 12 a minute)
	Sure = 100, -- the kill that surely drops it (about 8 minutes)
	DayCap = 3,
	RewardMinutes = 2,
	Bench = { Zone = "Crossroads", Spot = "KidsBench", Range = 10 },
	Order = { "Teddy", "ClubBadge", "GuardMedal", "CandyBag" },
	Items = {
		Teddy = { Name = "Lost Teddy", Zone = "SlimeMeadow", Owner = "Kid", Card = "LostTeddy" },
		ClubBadge = { Name = "Grab Club Badge", Zone = "GoblinWoods", Owner = "Goblin", Card = "LostBadge" },
		GuardMedal = { Name = "Old Guard Medal", Zone = "SkeletonRuins", Owner = "Guard", Card = "LostMedal" },
		CandyBag = { Name = "Lost Candy Bag", Zone = "PumpkinPatch", Owner = "Kid", Card = "LostCandy", Season = "Halloween" },
	},
	Reward = { Good = { Give = { HP = 2, MP = 2 }, FirstScroll = "Enh70" } },
	Text = {
		GoodDone = "Thank you for the %s! Here is a little gift.",
		FeeDone = "Cheeky! Here's a coin for the %s.",
		TrophyDone = "The %s is in your vault now.",
		RowBench = "Bring the %s to the Lost & Found · Crossroads",
		RowVault = "Put the %s in your vault · your town",
		ShortBench = "Lost & Found",
		ShortVault = "Trophy vault",
	},
}
Config.ChoiceCard.Kinds.LostTeddy = {
	Title = "A lost teddy! Someone must miss it.",
	Good = { Label = "Give it back", Points = 1, Done = "Kind! Take it to the Lost & Found." },
	Evil = { Label = "Finder's fee!", Points = 1, Done = "Sneaky! Ask for a fee at the Lost & Found." },
}
Config.ChoiceCard.Kinds.LostCandy = {
	Title = "A candy bag! Someone is looking for it.",
	Good = { Label = "Give it back", Points = 1, Done = "Kind! Take it to the Lost & Found." },
	Evil = { Label = "Finder's fee!", Points = 1, Done = "Sneaky! Ask for a fee at the Lost & Found." },
}
Config.ChoiceCard.Kinds.LostBadge = {
	Title = "A Grab Club badge! A big goblin must be sad.",
	Good = { Label = "Give it back", Points = 1, Done = "Kind! Take it to the Lost & Found." },
	Evil = { Label = "Keep it as a trophy", Points = 1, Done = "A fine trophy! Stash it in your vault." },
}
Config.ChoiceCard.Kinds.LostMedal = {
	Title = "An old guard medal! It still shines.",
	Good = { Label = "Give it back", Points = 1, Done = "Kind! Take it to the Lost & Found." },
	Evil = { Label = "Keep it as a trophy", Points = 1, Done = "A fine trophy! Stash it in your vault." },
}
-- A23-86 Sprout Oath titles (stat-free; the oath's pick decides which: Good = Guardian Cadet, Evil = Rascal Cadet)
Config.TitleDefs.GuardianCadet = { Name = "Guardian Cadet", NameEn = "Guardian Cadet", Color = Color3.fromRGB(255, 225, 120) }
Config.TitleDefs.RascalCadet = { Name = "Rascal Cadet", NameEn = "Rascal Cadet", Color = Color3.fromRGB(190, 120, 235) }
for _, id in { "GuardianCadet", "RascalCadet" } do
	if not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end
end

-- the egg titles (stat-free; the picker order follows)
Config.TitleDefs.ActuallyReadIt = { Name = "Actually Read It", NameEn = "Actually Read It", Color = Color3.fromRGB(130, 205, 255) }
Config.TitleDefs.DidntReadIt = { Name = "Didn't Read It", NameEn = "Didn't Read It", Color = Color3.fromRGB(190, 170, 140) }
Config.TitleDefs.BugReporter = { Name = "Bug Reporter", NameEn = "Bug Reporter", Color = Color3.fromRGB(150, 230, 170) }
Config.TitleDefs.GooseFan = { Name = "Goose Fan", NameEn = "Goose Fan", Color = Color3.fromRGB(255, 225, 120) }
Config.TitleDefs.SkyWatcher = { Name = "Sky Watcher", NameEn = "Sky Watcher", Color = Color3.fromRGB(150, 190, 255) }
Config.TitleDefs.BenchDetective = { Name = "Bench Detective", NameEn = "Bench Detective", Color = Color3.fromRGB(200, 150, 235) }
for _, id in { "ActuallyReadIt", "DidntReadIt", "BugReporter", "GooseFan", "SkyWatcher", "BenchDetective" } do
	if not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end
end

----------------------------------------------------------------- kill cards (게임성 개발 2, A23-87)
-- KillCardService: a kill of one of Kinds (by a paid contributor) offers that ChoiceCard kind with chance Chance, at
-- most once per Cooldown s per player (server memory; a rejoin starts fresh). The card itself is ChoiceCard's.
Config.KillCards = {
	-- 검수 10/09: off until the client's choice-card window exists (otherwise saved cards only pile up)
	FlowerPatch = { Enabled = false, Kinds = { FlowerSlime = true }, Chance = 0.25, Cooldown = 600 },
}

----------------------------------------------------------------- monster levels (게임성 개발 2, system_review_round1 #6)
-- docs/design/system_review_round1_2026-10-09.md #6: every monster model carries a Level attribute (MonsterService)
-- so the nametag can show a danger colour (Config.MonsterDanger below + game dev 1's MonsterDangerLook; the server's
-- fights never read it). Inside each field's band
-- (meadow Lv1-9, woods 10-24, ruins 25+; the Halloween fields are Lv1 fields): the field's plain kind lowest, the
-- bigger / ranged ones higher, the bosses on top. A kind not listed falls back to its zone's MinLevel.
Config.MonsterLevels = {
	Slime = 2, FlowerSlime = 3, BigSlime = 5, SlimeKing = 8,
	PumpkinSlime = 3, GhostMinion = 6, LittleGhost = 7, PumpkinKing = 10, GhostKing = 12,
	Goblin = 12, BatGoblin = 13, SlingshotGoblin = 14, GoblinBrute = 18,
	Skeleton = 26, SkeletonArcher = 28, SkeletonKnight = 30, CaptainClatter = 32,
	-- NewZones (A23-123; Season "NewZones", off as shipped): Coral Coast Lv 8-11 (meadow -> woods step), Crystal Cave
	-- Woods Lv 14-21 (woods -> ruins step)
	CoralCrab = 8, Jellyfish = 9, HermitCrab = 11,
	CrystalLizard = 14, CaveBat = 15, GlowMushroom = 17, CrystalGolem = 21,
}

function Config.MonsterLevel(kind)
	local lv = Config.MonsterLevels[kind]
	if type(lv) == "number" then return lv end
	local def = Config.MonsterTypes[kind]
	local zone = def and Config.Zones[def.Zone]
	return zone and zone.MinLevel or 1
end

-- the nametag's danger band for a player of level `myLevel` looking at a monster of level `monsterLevel` (검수
-- 2026-10-09: -6 / +3 / +8): "Weak" (gray: Weak or more levels below), "Even" (white), "Strong" (yellow: Strong or more
-- above), "Deadly" (red: Deadly or more above). Game dev 1's Config.MonsterDangerLook (colours, LevelOf) calls it.
Config.MonsterDangerBands = { Weak = -6, Strong = 3, Deadly = 8 }
function Config.MonsterDanger(myLevel, monsterLevel)
	local bands = Config.MonsterDangerBands
	local gap = (tonumber(monsterLevel) or 1) - (tonumber(myLevel) or 1)
	if gap >= bands.Deadly then return "Deadly" end
	if gap >= bands.Strong then return "Strong" end
	if gap <= bands.Weak then return "Weak" end
	return "Even"
end

----------------------------------------------------------------- private servers (게임성 개발 2, A23-90)
-- A23-90 (user 2026-10-09): in a private server (game.PrivateServerId ~= "") the golden goose, the crown-war chests
-- (incl. the siege chest) and the bounties pay x RewardMult (gold by these sources in ProgressionService.AddBankGold,
-- before the 2x gold pass; the goose's XP in GooseService). Hunting, quests, drops and playing with friends stay
-- as they are. Text = the line the shop's private-server card shows before buying (game dev 1).
Config.PrivateServer = {
	RewardMult = 0.5,
	HalfSources = { Event = true, War = true, Bounty = true },
	Text = "Rewards are halved in private servers",
}

----------------------------------------------------------------- A23-87 ranged kinds switch (검수 10/09)
-- The Slingshot Goblin and the Skeleton Archer need the client's shot drawing (Fx MonsterShot) and AnimFrom moves
-- (game dev 1): until those land they do not spawn (Count 0) and the goblins / skeletons get their slots back.
Config.Mobs3Ranged = false
if not Config.Mobs3Ranged then
	local MT = Config.MonsterTypes
	MT.Goblin.Count += MT.SlingshotGoblin.Count
	MT.Skeleton.Count += MT.SkeletonArcher.Count
	MT.SlingshotGoblin.Count, MT.SkeletonArcher.Count = 0, 0
end

----------------------------------------------------------------- PET-4 the lost baby slime (게임성 개발 2)
-- content_beyond_10min_2026-10-08 §2 B: a story pick of Quest makes Species my pet (PetService.GrantPet) for everyone,
-- not only the tamer. Lean = the pick's side (Picks: Halo / Horns picks and a Neutral's A / B), Names = the label only
-- my own client shows over my pet (game dev 1). The walk speed bonus stays as it is (A23-86 decision 4: +7-10%).
Config.PetGrant = {
	Quest = "Pet1", Species = "BabySlime",
	Picks = { Care = "Good", Minion = "Evil", A = "Good", B = "Evil" },
	Names = { Good = "Good Buddy", Evil = "Little Minion" },
	Text = { Got = "New pet: Baby Slime!" },
}

----------------------------------------------------------------- A23-110 the first KO King (게임성 개발 2)
-- The personal King Slime of game dev 3's quest Config.FirstKO (KO1; FirstKOService reads StoryQuestService.CurrentStep):
--   step Config.FirstKO.Step "Defeat the King Slime" = the FIRST King: a quiet personal King (only its owner sees and hits
--   it; its kill fires no MonsterKilled) appears SpawnDistance studs in front of the player in Zone (not a town; within
--   Radius of Landmark when one is set: a Config.StoryQuests.Landmarks key / StoryLandmark tag; never while the field
--   King stands within BossClear studs; never for a kaiju), lands DropTime s later (model attributes FirstKO = "First" |
--   "Retry", DropAt = server time, DropTime: game dev 1 draws the drop) and its landing thud (and every later hit) knocks
--   its owner out in one hit (OneHitMult x MaxHealth: through the 90% Guard cap), only below level OneHitBelow, once per
--   account (data.FirstKODone) and never while something is at stake (a grudge sack, wanted stars / bounty, a PvP fight,
--   the kaiju queue: plain hits and a normal death then). That KO is lossless (CombatService skips the sack, bounty, PvP
--   and ranking steps; Net.Fx "KO" First = true, RespawnIn), StoryQuestService.Event "FirstKO" moves the quest on, the
--   King floats away, and the player gets up GetUp.Back studs from where it fell (away from the King, never a town) after
--   RespawnIn s with GetUp.HealthFrac of MaxHealth (the next rows: buy and drink a potion). On that step with the KO
--   already had (or from OneHitBelow on) no King comes and the quest is told "FirstKO" again every SpawnGap.
--   step Config.FirstKO.RematchStep = the RETRY King: a normal personal King (its kill is a Personal MonsterKilled with
--   Practice = true: it counts for the quest's Kill row, never for a finisher card or boss drops, and pays the XP / gold
--   of Retry.PayAs) with HP and hits from Config.FirstKORetry (one HP potion wins); one win per session while the row stays.
--   A KO by it is a normal KO. Both Kings come only by the player (never the home-town spot) and never swing before the
--   landing.
-- Tick = s between the service's checks; SpawnGap = s before another King comes; ClaimGrace = s between the lethal hit and
-- the Died event that still count as the first KO.
Config.FirstKOKing = {
	-- false = no King at all; the KO row is still told "FirstKO" (never stuck); the rematch row then needs another way
	Enabled = true,
	Kind = "SlimeKing",
	OneHitBelow = 10, -- Lv 10+ is never one-shot (A7-2: the early levels end at 10; KO1 opens up to Lv 8)
	Zone = "SlimeMeadow", Radius = 90, -- Landmark = "KingHill": a Landmarks key (nil = anywhere in Zone)
	-- studs: no personal King while the field King stands this close (bodies apart). Small on purpose: the field King
	-- stays 300 s of every 480 s on its hill and never targets Lv < 5 / < 600 s players (A23-27), so a wide gap would
	-- leave a new player at the hill marker without a King for minutes
	BossClear = 24,
	SpawnDistance = 6, DropTime = 1.2, LandRadius = 10,
	-- A23-113 ①: the first King's leaps (Config.BossLeap) grow LeapGrow studs after each one that missed, up to LeapGrowMax
	-- more: by the third a player cannot step out in the second it shows (it keeps hopping until it lands, "결국 맞힘")
	LeapGrow = 6, LeapGrowMax = 18,
	-- s after the drop before both Kings' first leap (A23-113 ①): it lands FirstLeapAfter + Warn (1) = 1.8 s after the drop
	-- (which hits inside its circle), then one every 1.5 s - the old pace (first swing 0.28 s after the drop, then every
	-- 1.5 s) with the first hit 0.28 s sooner, which the retry numbers below still pass
	FirstLeapAfter = 0.8,
	FirstHP = 5000, -- the first King is not meant to fall (killed anyway: Event "FirstKO" with Beaten = true, the row counts)
	OneHitMult = 20, -- x MaxHealth: still >= 2 x MaxHealth through the 90% Guard cap (SKL-3)
	RespawnIn = 3, -- s before the get-up (the KO screen's 3-2-1)
	ClaimGrace = 1,
	-- studs away from the King, studs above the ground, s the spot is kept, the share of MaxHealth the player gets up with
	GetUp = { Back = 6, Lift = 4, Keep = 20, HealthFrac = 0.4 },
	SpawnGap = 4,
	Tick = 0.5,
	-- the retry King: HP = Seconds of the player's own basic attacks (the best weapon the save may use, with its +N), each
	-- hit HitPct of MaxHealth (+ regen, FirstKORetry). One HP potion is the lesson: KO1 may leave a player with only one
	-- (one purchase of any kind passes its buy row, the drink row may use it). tools/test_first_ko_king.py, 729 builds
	-- (3 classes x Halo / Horns / Neutral x Lv 1-9 x tier 1-3 x +0 / +3 / +5), a potion = 30% / 10 s drunk at 40-60% HP,
	-- a player who never steps out of a circle (A23-113 ①: the drop hits, the first leap 1.8 s later, then every 1.5 s):
	--   no potion LOSES at 60-80% uptime against a King every 1.5 s and at 60-70% against one every 1.6 s (>= 1.36 s
	--   short); at 80% against a 1.6 s King only 9 builds of 729 win without a potion;
	--   1 potion WINS at 80-110% uptime (King every 1.5 s) with >= 13% HP left; 2 potions win at 70-110% with >= 19% left.
	--   Stepping out of the circles wins without potions (the rematch lesson, A23-113).
	--   (Seconds 18 / HitPct 0.09 needed 2 potions; 16.5 / 0.075 leaves 342 no-potion wins at 80% vs a 1.6 s King.)
	-- PayAs = the kind whose XP / gold its kill pays (the Slime Prince's; the quest pays the real reward)
	Retry = { Seconds = 17, HitPct = 0.075, MinHP = 40, PayAs = "BigSlime" },
}
Config.Data.Defaults.FirstKODone = false -- A23-110: the lossless first KO happened (set once, before the quest is told)

-- the retry King against one player (A23-110): { HP, Hit }. HP = Retry.Seconds of that player's basic attacks (the swing
-- formula of Config.SwingHitsToKill: weapon x class x faction bonus x SwingImmediate, rounded, per SwingInterval; no
-- crit), at least MinHP, at most Retry.MaxHP (2500 when unset: the King's HP before A23-113; never follows the field
-- King's crowd HP, 검수 bosshp_verify 2026-10-11). Hit = the share of the player's MaxHealth one King hit takes: HitPct +
-- the faction's out-of-town regen over one King attack (Config.Monsters.AttackCooldown), so every faction needs the same
-- potions. Pure (FirstKOService and the offline test share it).
function Config.FirstKORetry(level, tier, classId, factionId, enhance)
	local FK = Config.FirstKOKing
	local R = FK.Retry
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	local c = Config.AttackProfile(classId, tonumber(tier), factionId)
	local f = Config.Factions[factionId] or Config.Factions.None
	local bonus = type(f.DamageBonus) == "number" and f.DamageBonus or 0
	local per = Config.WeaponDamage(tonumber(tier), lv, tonumber(enhance) or 0) * (c.Damage or 1) * (1 + bonus)
		* ((Config.BasicSkill and Config.BasicSkill.SwingImmediate) or 0.5)
	local dps = math.max(1, math.floor(per + 0.5)) / math.max(0.1, tonumber(c.SwingInterval) or 1)
	local hp = math.clamp(math.floor(R.Seconds * dps + 0.5), R.MinHP, math.max(R.MinHP, tonumber(R.MaxHP) or 2500))
	local regen = type(f.RegenPerSec) == "number" and f.RegenPerSec or 0
	return { HP = hp, Hit = R.HitPct + regen * Config.Monsters.AttackCooldown }
end

----------------------------------------------------------------- gathering (게임성 개발 3, 2026-10-11)
-- GatherService (contract docs/design/gather_server_2026-10-11.md, background gathering_2026-10-06.md). Everyone (Halo,
-- Horns, artisans) the same: hold the interact key at a node (PromptRange studs) for Nodes[kind].Hold s -> 1 material,
-- Double = the chance of 2. No XP, scroll, weapon or potion. A node rests Regrow s for the gatherer only (server memory).
-- Server checks: the held time >= Hold x MinHoldRatio, root <-> node <= ServerRange, one gather per RateLimits.Gather s,
-- my own node rest, DailyCap gathers a KST day (data.Gather.N), no hit from another player since the hold began.
-- Plant nodes sometimes show a Shard Bloom (Bloom: the ChoiceCard ShardBloom). Heavy = gathers in one hour above which
-- TelemetryService logs "GatherHeavy" (ids only). Spots[zone] = { { kind, u, v } } with u, v in 0..1 of the zone rectangle
-- (Config.GatherSpotPos); WorldKit "GatherSpot" tagged parts (attribute Node = kind) replace a zone's list. Ray = the
-- downward ground ray of a spot (from From studs up, Length studs long). Text = keys only on the wire (Net.NotifyKey,
-- prompt attributes ActionKey / ObjectKey); no first-time hint line (A23-130, 게임성 개발 4).
-- Switched by Config.Features.Gathering (off).
-- Gathering (게임성 개발 3): the herb / ore nodes. Off = no node is built and every gather handler returns at once; on
-- together with the artisan guild (검수)
Config.Features.Gathering = false
Config.Gather = {
	DailyCap = 400,
	MinHoldRatio = 0.8,
	PromptRange = 8,
	ServerRange = 12,
	Regrow = 180,
	Double = 0.2,
	Heavy = 200,
	Ray = { From = 300, Length = 600 },
	-- the jump watch (게임성 검수 10/12): samples every JumpSample s; a root that moved more than JumpStuds in one sample
	-- (a teleport / fling, never a walk) cannot gather for AfterJump s
	JumpSample = 0.5,
	JumpStuds = 60,
	AfterJump = 3,
	Nodes = {
		HerbBush = { Item = "Herb", Hold = 1.5, Action = "Pick", Plant = true, Zone = "SlimeMeadow", Color = Color3.fromRGB(140, 210, 255) },
		CopperRock = { Item = "CopperOre", Hold = 2.0, Action = "Mine", Zone = "SlimeMeadow", Color = Color3.fromRGB(205, 125, 75) },
		OakPile = { Item = "OakLog", Hold = 1.5, Action = "Pick", Zone = "GoblinWoods", Color = Color3.fromRGB(160, 115, 70) },
		GlowcapPatch = { Item = "Glowcap", Hold = 1.5, Action = "Pick", Plant = true, Zone = "GoblinWoods", Color = Color3.fromRGB(80, 225, 205) },
		IronRock = { Item = "IronOre", Hold = 2.0, Action = "Mine", Zone = "GoblinWoods", Color = Color3.fromRGB(130, 135, 145) },
		SilverRock = { Item = "SilverOre", Hold = 2.0, Action = "Mine", Zone = "SkeletonRuins", Color = Color3.fromRGB(210, 215, 225) },
		MoonCrystal = { Item = "MoonCrystal", Hold = 2.0, Action = "Mine", Zone = "SkeletonRuins", Color = Color3.fromRGB(175, 165, 255) },
	},
	-- gathering_2026-10-06 §2 stud spots in today's zone rectangles (the pumpkin-path clump dropped: the north-path
	-- candidates make two clumps). Nodes >= 8 studs apart, none within 40 studs of the meadow spawn (230, 0), none on the
	-- crown road (|z| <= 9). Studs in the comments.
	Spots = {
		SlimeMeadow = {
			-- HerbBush: south-east of the watchtower (260, -200)
			{ "HerbBush", 0.15, 0.1125 }, { "HerbBush", 0.1773, 0.125 }, { "HerbBush", 0.1455, 0.1417 }, -- (276,-186) (288,-180) (274,-172)
			-- the north ring path (x 480-560, z -205): two clumps
			{ "HerbBush", 0.6182, 0.0729 }, { "HerbBush", 0.6455, 0.08125 }, { "HerbBush", 0.6318, 0.05625 }, -- (482,-205) (494,-201) (488,-213)
			{ "HerbBush", 0.75, 0.0729 }, { "HerbBush", 0.7773, 0.08125 }, { "HerbBush", 0.7636, 0.05625 }, -- (540,-205) (552,-201) (546,-213)
			-- the pond's west edge (x 240-255, z 140-170)
			{ "HerbBush", 0.0773, 0.7958 }, { "HerbBush", 0.0909, 0.8229 }, { "HerbBush", 0.075, 0.85 }, -- (244,142) (250,155) (243,168)
			-- CopperRock: the King Slime hill's (430, -170) south-east slope
			{ "CopperRock", 0.5364, 0.175 }, { "CopperRock", 0.5636, 0.1917 }, -- (446,-156) (458,-148)
			{ "CopperRock", 0.5318, 0.2042 }, { "CopperRock", 0.5591, 0.2208 }, -- (444,-142) (456,-134)
			-- in front of the woods bridge (x 615-640), off the road
			{ "CopperRock", 0.9273, 0.4583 }, { "CopperRock", 0.9636, 0.4667 }, -- (618,-20) (634,-16)
			{ "CopperRock", 0.9273, 0.5417 }, { "CopperRock", 0.9636, 0.5333 }, -- (618,20) (634,16)
		},
		GoblinWoods = {
			-- OakPile: a ring of 16 studs around the goblin treehouse's old tree (960, -90)
			{ "OakPile", 0.5542, 0.3269 }, { "OakPile", 0.5438, 0.3481 }, { "OakPile", 0.5208, 0.3577 }, { "OakPile", 0.4979, 0.3481 }, -- (976,-90) (971,-79) (960,-74) (949,-79)
			{ "OakPile", 0.4875, 0.3269 }, { "OakPile", 0.4979, 0.3058 }, { "OakPile", 0.5208, 0.2962 }, { "OakPile", 0.5438, 0.3058 }, -- (944,-90) (949,-101) (960,-106) (971,-101)
			-- GlowcapPatch: the woods' north ring path (z about -222), two clumps
			{ "GlowcapPatch", 0.1458, 0.0731 }, { "GlowcapPatch", 0.1708, 0.0846 }, { "GlowcapPatch", 0.1958, 0.0692 }, { "GlowcapPatch", 0.1708, 0.0577 }, -- (780,-222) (792,-216) (804,-224) (792,-230)
			{ "GlowcapPatch", 0.6875, 0.0731 }, { "GlowcapPatch", 0.7125, 0.0846 }, { "GlowcapPatch", 0.7375, 0.0692 }, { "GlowcapPatch", 0.7125, 0.0577 }, -- (1040,-222) (1052,-216) (1064,-224) (1052,-230)
			-- IronRock: before the pass (x 1150-1180), off the road
			{ "IronRock", 0.9208, 0.4423 }, { "IronRock", 0.95, 0.4538 }, { "IronRock", 0.9792, 0.4385 }, -- (1152,-30) (1166,-24) (1180,-32)
			{ "IronRock", 0.9208, 0.5577 }, { "IronRock", 0.95, 0.5462 }, { "IronRock", 0.9792, 0.5615 }, -- (1152,30) (1166,24) (1180,32)
		},
		SkeletonRuins = {
			-- SilverRock: a ring of 18 studs around the broken tower (1560, -70)
			{ "SilverRock", 0.6115, 0.3793 }, { "SilverRock", 0.5942, 0.4069 }, { "SilverRock", 0.5596, 0.4069 }, -- (1578,-70) (1569,-54) (1551,-54)
			{ "SilverRock", 0.5423, 0.3793 }, { "SilverRock", 0.5596, 0.3517 }, { "SilverRock", 0.5942, 0.3517 }, -- (1542,-70) (1551,-86) (1569,-86)
			-- MoonCrystal: the south ring path (z 150-200), two clumps
			{ "MoonCrystal", 0.3077, 0.7931 }, { "MoonCrystal", 0.3346, 0.8069 }, { "MoonCrystal", 0.3577, 0.7862 }, -- (1420,170) (1434,178) (1446,166)
			{ "MoonCrystal", 0.6154, 0.7966 }, { "MoonCrystal", 0.6423, 0.8103 }, { "MoonCrystal", 0.6654, 0.7897 }, -- (1580,172) (1594,180) (1606,168)
		},
	},
	-- Item = what a bloom pays (the card's rewards, the share, the wilt), Card = the ChoiceCard kind
	Bloom = { Chance = 0.08, FirstAt = 5, DailyMax = 3, Radius = 40, GiftDailyMax = 10, Item = "CrownDust", Card = "ShardBloom" },
	Text = {
		Pick = "Pick",
		Mine = "Mine",
		DailyCap = "You gathered a lot today! Come back tomorrow!",
		PvPCut = "A player hit you! Try again.",
		BloomGift = "Someone shared a Shard Bloom! +1 Crown Dust",
		BloomWilt = "The bloom closed up. +1 Crown Dust",
	},
}
Config.RateLimits.Gather = 1

-- a Config.Gather spot (u, v in 0..1 of the zone rectangle Config.Zones[zone].Center / Size) -> Vector3 with y = 0; nil
-- for an unknown zone or u / v outside 0..1 (pure: GatherService and the offline test share it)
function Config.GatherSpotPos(zone, u, v)
	local z = type(zone) == "string" and Config.Zones[zone] or nil
	if type(z) ~= "table" or type(u) ~= "number" or type(v) ~= "number" then return nil end
	if not (u >= 0 and u <= 1 and v >= 0 and v <= 1) then return nil end -- NaN fails too
	return Vector3.new(z.Center.X - z.Size.X / 2 + u * z.Size.X, 0, z.Center.Z - z.Size.Z / 2 + v * z.Size.Z)
end

-- the Shard Bloom (a plant node's sometimes-bloom): a timed card (time up = +1 crown dust, GatherService). Points through
-- Deeds like every card (an artisan picks for the reward only)
Config.ChoiceCard.Kinds.ShardBloom = {
	Seconds = 120,
	Title = "A Shard Bloom! It sparkles with crown dust. What will you do?",
	Good = { Label = "Share it", Reward = { Item = "CrownDust", N = 2 }, Points = 1 },
	Evil = { Label = "Keep it all", Reward = { Item = "CrownDust", N = 3 }, Points = 1 },
}

----------------------------------------------------------------- crafting (게임성 개발 3, 2026-10-12)
-- CraftService (contract docs/design/craft_server_2026-10-12.md, 게임성 검수 OK 10/12; the hammer screen is 게임성 개발 4's
-- hammer_minigame_2026-10-12.md). Only artisans (faction Neutral) craft, each only the recipes of their role (Roles: the
-- artisan class -> role). A craft never fails and never loses materials (A23-56): the gold and materials go at the start,
-- the result (+0 / +1 / +2 from the hammer) comes at the end, a leave / KO / time-out finishes it at +0, and the save's
-- Craft.Pend finishes it at +0 on the next join if the server stops in between. A craft level per role (data.Craft.<role>
-- = { Lv, XP }), XP to the next = floor(XPBase x Lv ^ XPExp), at most MaxLv; the 2x XP pass does not touch it.
-- The hammer's numbers and rules live in Shared/CraftMini.luau (게임성 개발 4, the one place the screen and the server share:
-- a fixed ring schedule, CraftStrike(id, i, ms) on a press, CraftFinish(id) scores with CraftMini.Accept). No Finish by
-- StartAt + CraftMini.T.Timeout = +0. Recipes[id] = { Role, Kind "Weapon" | "Gear" | "Item", Tier?, Slot?, Item?, N?, Lv, Gold, Mats,
-- XP }; a recipe with a material id missing from Config.Loot.Items is off (new drops switch it on). Weapons go to the
-- spare weapons (LootService.AddSpare, 게임성 개발 2) and stay off until that exists. Switched by
-- Config.Features.Crafting (off; on with the artisan guild, 검수).
Config.Features.Crafting = false
Config.Craft = {
	Roles = { Warrior = "Smith", Mage = "Alch", Archer = "Tame" },
	MaxLv = 30,
	XPBase = 40,
	XPExp = 1.5,
	Range = 12, -- studs from the role's workbench (CollectionService tag StationTag, attribute Role; else the Crossroads anvil)
	StationTag = "CraftStation",
	StartsPerMinute = 6,
	-- blacksmith weapons (crafting_market §4 + the gathered ores; 게임성 검수 10/12: start values, tuned after play)
	Recipes = {
		W1 = { Role = "Smith", Kind = "Weapon", Tier = 1, Lv = 1, Gold = 10, Mats = { Jelly = 5, CopperOre = 2 }, XP = 10 },
		W2 = { Role = "Smith", Kind = "Weapon", Tier = 2, Lv = 1, Gold = 40, Mats = { Jelly = 10, Petal = 3, CopperOre = 4 }, XP = 20 },
		W3 = { Role = "Smith", Kind = "Weapon", Tier = 3, Lv = 5, Gold = 200, Mats = { SlimeCore = 6, Jelly = 20, CopperOre = 10 }, XP = 60 },
		W4 = { Role = "Smith", Kind = "Weapon", Tier = 4, Lv = 10, Gold = 750, Mats = { GoblinTooth = 20, BruteHorn = 10, IronOre = 8, OakLog = 4 }, XP = 150 },
		W5 = { Role = "Smith", Kind = "Weapon", Tier = 5, Lv = 15, Gold = 2500, Mats = { Bone = 30, KnightCrest = 12, IronOre = 15, OakLog = 6 }, XP = 400 },
		W6 = { Role = "Smith", Kind = "Weapon", Tier = 6, Lv = 20, Gold = 7500, Mats = { KnightCrest = 30, Bone = 60, CaptainBadge = 1, SilverOre = 12 }, XP = 900 },
		W7 = { Role = "Smith", Kind = "Weapon", Tier = 7, Lv = 25, Gold = 22500, Mats = { KnightCrest = 60, Bone = 100, CaptainBadge = 2, ClatterGem = 1, SilverOre = 25 }, XP = 2000 },
		W9 = { Role = "Smith", Kind = "Weapon", Tier = 9, Lv = 30, Gold = 60000, Mats = { KnightCrest = 100, CaptainBadge = 6, ClatterGem = 3, KingJelly = 10, MoonCrystal = 20 }, XP = 4000 },
		-- alchemist tonics (④, crafting_market §4 + the gathered herbs; Kind Item = N bottles + the hammer's +N)
		A1 = { Role = "Alch", Kind = "Item", Item = "MightTonic", N = 1, Lv = 1, Gold = 20, Mats = { Herb = 3, Jelly = 5 }, XP = 10 },
		A2 = { Role = "Alch", Kind = "Item", Item = "GuardTonic", N = 1, Lv = 3, Gold = 30, Mats = { Herb = 3, SlimeCore = 2, CopperOre = 2 }, XP = 20 },
		A3 = { Role = "Alch", Kind = "Item", Item = "LuckyTonic", N = 1, Lv = 8, Gold = 60, Mats = { Glowcap = 3, Petal = 5 }, XP = 40 },
		A4 = { Role = "Alch", Kind = "Item", Item = "WisdomTonic", N = 1, Lv = 12, Gold = 100, Mats = { Glowcap = 4, GoblinTooth = 5, Bone = 3 }, XP = 60 },
		-- tamer (⑤, crafting_market §4; docs/design/tamer_server_2026-10-12.md). Kind Pet = a summon: Research = the
		-- points of Family it needs (stage 2), Spd = the random walk bonus range (whole %) before the hammer's +N (at most
		-- Config.SaveV4.PetRollSpd[2]); the new pet is Bound (never sold). T1 = Pet Treats (N + the hammer's +N; 게임성 검수
		-- 10/12: the gathered herb, so the guild's gather -> craft loop feeds it, not hunting alone)
		S1 = { Role = "Tame", Kind = "Pet", Species = "BabySlime", Family = "Slime", Research = 150, Spd = { 5, 8 }, Lv = 1, Gold = 100, Mats = { Jelly = 30, SlimeCore = 5 }, XP = 40 },
		T1 = { Role = "Tame", Kind = "Item", Item = "PetTreat", N = 3, Lv = 1, Gold = 10, Mats = { Jelly = 5, Herb = 2 }, XP = 10 },
		-- ⑥ gear (docs/design/gear_slots_2026-10-12.md §4; 게임성 검수 OK 10/12; Config.Gear has the numbers). Kind Gear pays
		-- into data.Gear.Own["<Slot>:T:P"] (T = Tier, P = the hammer's +N). Smith: armor + ring (Lv 8 / 16 / 24: iron, silver,
		-- moon crystal + the monster materials of the same zones); the tamer: pet armor + pet accessory (Lv 5 / 12 / 20:
		-- jelly, petals, herbs -> goblin tooth -> bone, knight crest). Gold / XP sit between the weapon rows.
		G1 = { Role = "Smith", Kind = "Gear", Slot = "Armor", Tier = 1, Lv = 8, Gold = 450, Mats = { IronOre = 6, OakLog = 4, GoblinTooth = 10 }, XP = 100 },
		G2 = { Role = "Smith", Kind = "Gear", Slot = "Armor", Tier = 2, Lv = 16, Gold = 3500, Mats = { MoonCrystal = 8, IronOre = 12, KnightCrest = 10, Bone = 20 }, XP = 500 },
		G3 = { Role = "Smith", Kind = "Gear", Slot = "Armor", Tier = 3, Lv = 24, Gold = 15000, Mats = { SilverOre = 20, MoonCrystal = 15, KnightCrest = 40, Bone = 60 }, XP = 1400 },
		R1 = { Role = "Smith", Kind = "Gear", Slot = "Ring", Tier = 1, Lv = 8, Gold = 400, Mats = { CopperOre = 6, Glowcap = 4, GoblinTooth = 8 }, XP = 90 },
		R2 = { Role = "Smith", Kind = "Gear", Slot = "Ring", Tier = 2, Lv = 16, Gold = 3200, Mats = { SilverOre = 6, Glowcap = 8, BruteHorn = 10, Bone = 15 }, XP = 450 },
		R3 = { Role = "Smith", Kind = "Gear", Slot = "Ring", Tier = 3, Lv = 24, Gold = 14000, Mats = { SilverOre = 15, MoonCrystal = 12, Glowcap = 15, KnightCrest = 30 }, XP = 1300 },
		PA1 = { Role = "Tame", Kind = "Gear", Slot = "PetArmor", Tier = 1, Lv = 5, Gold = 150, Mats = { Jelly = 20, Herb = 4, SlimeCore = 4 }, XP = 50 },
		PA2 = { Role = "Tame", Kind = "Gear", Slot = "PetArmor", Tier = 2, Lv = 12, Gold = 900, Mats = { GoblinTooth = 20, Herb = 10, BruteHorn = 6, OakLog = 6 }, XP = 160 },
		PA3 = { Role = "Tame", Kind = "Gear", Slot = "PetArmor", Tier = 3, Lv = 20, Gold = 6000, Mats = { Bone = 40, KnightCrest = 20, Herb = 20 }, XP = 700 },
		PC1 = { Role = "Tame", Kind = "Gear", Slot = "PetAcc", Tier = 1, Lv = 5, Gold = 120, Mats = { Petal = 10, Herb = 3, Jelly = 12 }, XP = 45 },
		PC2 = { Role = "Tame", Kind = "Gear", Slot = "PetAcc", Tier = 2, Lv = 12, Gold = 800, Mats = { GoblinTooth = 15, Petal = 15, Glowcap = 6 }, XP = 150 },
		PC3 = { Role = "Tame", Kind = "Gear", Slot = "PetAcc", Tier = 3, Lv = 20, Gold = 5500, Mats = { Bone = 30, KnightCrest = 15, Glowcap = 12 }, XP = 650 },
	},
	Text = {
		NotArtisan = "Only artisans can make this.",
		NeedLevel = "Your craft level is too low.",
		NeedMats = "Not enough materials.",
		NeedGold = "Not enough gold.",
		Far = "Go to your workbench.",
		Busy = "Finish this craft first.",
		Full = "No room for it.",
		Auto = "Turn off auto combat first.",
		NotReady = "You can't make this yet.", -- a recipe the server has switched off (its drops / spares are not in yet)
		NeedResearch = "Research this monster more first.", -- a summon before its research stage
		Prompt = "Craft", -- the workbench prompt (ActionKey)
		Stations = { Smith = "Anvil", Alch = "Cauldron", Tame = "Research Table" }, -- the prompt's ObjectKey by role
	},
}
-- ⑦ artisan fame and rank (게임성 개발 3, docs/design/artisan_fame_2026-10-12.md; GDD: craft points join the weekly
-- "Artisan Fame" board, A23-24 / A23-135). A finished craft by an artisan of the recipe's role now (the craft XP rule,
-- A23-139) earns Fame = the band of the recipe's craft Lv (the first row whose Lv it reaches) + PerfectBonus at the
-- hammer's +2. It goes into data.Craft.Rep (lifetime) and RankingService's weekly "Artisan" board. The 2x XP pass never
-- touches it. Ranks: the lifetime Rep a rank needs (the attribute ArtisanRank 1..#Ranks, 0 = not an artisan now); a rank
-- shows (name / badge), it buys nothing.
Config.Craft.Fame = { Bands = { { Lv = 30, N = 4 }, { Lv = 20, N = 3 }, { Lv = 10, N = 2 }, { Lv = 1, N = 1 } }, PerfectBonus = 1 }
Config.Craft.Ranks = {
	{ Id = "Apprentice", Rep = 0 },
	{ Id = "Journeyman", Rep = 30 },
	{ Id = "Artisan", Rep = 150 },
	{ Id = "Master", Rep = 500 },
	{ Id = "Grandmaster", Rep = 1500 },
}
Config.Craft.Text.RankUp = "Artisan rank up: %s!" -- (the rank's name key)
Config.Craft.Text.Ranks = { Apprentice = "Apprentice", Journeyman = "Journeyman", Artisan = "Artisan", Master = "Master",
	Grandmaster = "Grandmaster" }

-- the Fame of one finished craft of recipe row r at the hammer's +plus (0 for a broken row)
function Config.CraftFame(r, plus)
	if type(r) ~= "table" or type(r.Lv) ~= "number" then return 0 end
	local F = Config.Craft.Fame
	local n = 0
	for _, band in F.Bands do
		if r.Lv >= band.Lv then
			n = band.N
			break
		end
	end
	if n > 0 and plus == 2 then n += F.PerfectBonus end
	return n
end

-- the artisan rank (1..#Ranks) a lifetime Rep reaches; the Rep of the next one (0 at the top)
function Config.ArtisanRank(rep)
	if type(rep) ~= "number" or rep ~= rep then rep = 0 end
	local rank = 1
	for i, row in Config.Craft.Ranks do
		if rep >= row.Rep then rank = i end
	end
	local nextRow = Config.Craft.Ranks[rank + 1]
	return rank, nextRow and nextRow.Rep or 0
end

Config.RateLimits.CraftStart = 3
Config.RateLimits.CraftFinish = 0.5

-- XP from craft level `lv` to the next (Config.Craft.XPBase x lv ^ XPExp, floored; 0 at MaxLv: no next level)
function Config.CraftXPToNext(lv)
	local K = Config.Craft
	local l = math.floor(tonumber(lv) or 1)
	if l ~= l or l >= K.MaxLv then return 0 end
	return math.floor(K.XPBase * math.max(1, l) ^ K.XPExp)
end

-- A23-129 (게임성 개발 2): what keeps a new monster's body out (MonsterService CLEAR; 검수 2026-10-11 spawnclear review).
-- TreeRule: a world-kit tree (a Model with exactly one TrunkPost and one mesh named here) blocks a disc of Base x the
-- mesh's wider plan size round the TrunkPost, from the ground up to Canopy x its height, plus the mesh box above that
-- (measured on the place 72a5f19b: 90% of the trunk / root geometry at body height, the canopy bottom). Any other mesh
-- (W_GiantTree, town trees, bushes, boulders) keeps its full box. PassRule: a NON-collidable part whose name has a Pass
-- word (and no NotPass word) never blocks: ground cover and effects, not props (A23-129 = trees, rocks, buildings, fences)
Config.SpawnClear = {
	TreeRule = true,
	Trees = {
		W_Tree_A = { Base = 0.26, Canopy = 0.26 },
		W_Tree_B = { Base = 0.36, Canopy = 0.36 },
		W_Tree_C = { Base = 0.34, Canopy = 0.46 },
	},
	PassRule = true,
	Pass = { "Flower", "Grass", "Tuft", "Clover", "Lily", "Petal", "Puddle", "Wisp", "RedEye", "GlowEye", "Sparkle", "Mist",
		"Falls", "Foam", "StepStone" },
	-- a flower cart / pot is furniture; a puddle's stone rim (Kit_M_PuddleRim, 최종 검수 2026-10-12) is a rock
	NotPass = { "Cart", "Pot", "Stand", "Basket", "Box", "Rim" },
}

----------------------------------------------------------------- alchemy tonics (게임성 개발 3, 2026-10-12)
-- BuffService (docs/design/alchemy_server_2026-10-12.md; A23-133: everyone drinks them, monsters only, 3 minutes, two at a
-- time, the speed tonic after the beta). Tonics[item] = { Stat, Mult }: MonsterDamage = every hit on a monster,
-- MonsterHurt = every monster's hit on me, MaterialDrop = the chance of a material row in a kill's drops (never a
-- weapon, scroll, potion or the jackpot), HuntXP = a kill's XP. Drinking the same tonic again starts its 3 minutes over;
-- a third different one waits. Saved in data.Buffs (tonic -> os.time() it ends; Config.SanitizeBuffs). Switched by
-- Config.Features.Tonics (off; on with the artisan guild, 검수).
Config.Features.Tonics = false
Config.Alchemy = {
	Duration = 180,
	MaxActive = 2,
	Tonics = {
		MightTonic = { Stat = "MonsterDamage", Mult = 1.10 },
		GuardTonic = { Stat = "MonsterHurt", Mult = 0.90 },
		LuckyTonic = { Stat = "MaterialDrop", Mult = 1.25 },
		WisdomTonic = { Stat = "HuntXP", Mult = 1.10 },
	},
	Text = {
		TwoMax = "Only two tonics at a time.",
		NoTonic = "You have none of that tonic.",
	},
}
Config.RateLimits.UseTonic = 1

----------------------------------------------------------------- tamer research (게임성 개발 3, 2026-10-12)
-- TamerService; contract docs/design/tamer_server_2026-10-12.md (crafting_market §4, A23-115). The pet tamer
-- (Config.IsTamer: the artisan Archer) gets 1 research point for every kill it is paid for (MonsterKilled, not a
-- MinorShare; auto combat too) in that monster's family (Config.MonsterFamily: Family below, else Config.QuestKind).
-- Stages = the points each stage needs; a summon recipe (Config.Craft.Recipes, Kind "Pet") asks for its Research
-- points. Saved in data.Research.Pts (Config.SanitizeResearch: at most Config.SaveV4.MaxKeys families). Switched by
-- Config.Features.Research (off; on with the artisan guild, 검수).
Config.Features.Research = false
Config.Research = {
	Stages = { 50, 150, 400, 1000, 2500 },
	InfoEvery = 1, -- TamerInfo goes at most once a second (a new stage at once)
	Treat = "PetTreat", -- FeedPet(uid): one of these -> that pet gets TreatXP pet XP (anyone with a pet)
	TreatXP = 20,
	-- the kinds that are not their own family (the rest: Config.QuestKind, e.g. a pumpkin slime is a Slime already)
	Family = {
		BigSlime = "Slime", FlowerSlime = "Slime", SlimeKing = "Slime",
		GoblinBrute = "Goblin", SlingshotGoblin = "Goblin",
		SkeletonArcher = "Skeleton", SkeletonKnight = "Skeleton", CaptainClatter = "Skeleton",
		GhostMinion = "Ghost", LittleGhost = "Ghost", GhostKing = "Ghost",
	},
	Text = {
		Stage = "%s research: stage %s!", -- (family name, stage) a new stage
		Names = { Slime = "Slime", Goblin = "Goblin", Skeleton = "Skeleton", Ghost = "Ghost" }, -- family names (a family
		-- without one never gets the stage line)
		Fed = "Pet XP +%s", -- (TreatXP) a treat eaten
		PetMax = "Your pet is at max level.",
		NoTreat = "You have no Pet Treats.",
	},
}
Config.RateLimits.FeedPet = 0.5

-- the research family of a monster kind (nil for a kind the game does not know)
function Config.MonsterFamily(kind)
	if type(kind) ~= "string" or Config.MonsterTypes[kind] == nil then return nil end
	local fam = Config.Research.Family[kind]
	if type(fam) == "string" then return fam end
	return Config.QuestKind(kind)
end

-- the research stage the points reach (0 = not stage 1 yet .. #Stages)
function Config.ResearchStage(pts)
	local stage = 0
	if type(pts) ~= "number" then return 0 end -- NaN passes no stage
	for i, need in Config.Research.Stages do
		if pts >= need then stage = i else break end
	end
	return stage
end

----------------------------------------------------------------- gear slots (게임성 개발 3, 2026-10-12)
-- GearService; contract docs/design/gear_slots_2026-10-12.md (A23-133; 게임성 검수 OK 10/12). A player wears Armor (max HP) and
-- Ring (my hits and power), the following pet wears PetArmor (the pet's XP) and PetAcc (the walk bonus). An item is the
-- save key "<Slot>:T:P" in data.Gear.Own (T 1..MaxTier, P 0..MaxPlus); a worn one lives in data.Gear.On.<Slot> or
-- data.Gear.Pet[uid].<Slot> as "T:P", never in both places. A gear's bonus x = Base[tier] + Step x P; P is ONLY the hammer's
-- +0..+2 (CraftService): the scrolls (Enhance / Transfer) never touch gear, Config.SanitizeGear drops any other P. Wear =
-- the level that wears tier 1 / 2 / 3 (the pets: any, Lv1). Armor: max HP x (1 + x); Ring: my hit x (1 + x) and power; PetArmor:
-- pet XP x (1 + x), floored; PetAcc: + x to the pet's walk bonus (at most PetAccMax = the best one, Speed.Cap stays). The
-- top (T3 +2 both): HP x1.22, hit x1.14, power about +18%. OwnSum = the 60 things in Own (CraftService.ST.GearSum), at
-- most Config.SaveV4.OwnKeyMax of one key. Never sold, never breaks. Switched by Config.Features.Gear (off; on with the
-- artisan guild, 검수): while off, every multiplier is 1 and nothing can be worn.
Config.Features.Gear = false
Config.Gear = {
	MaxTier = 3,
	MaxPlus = 2,
	OwnSum = 60,
	PetAccMax = 0.04,
	Slots = {
		Armor = { Stat = "Hp", Base = { 0.06, 0.12, 0.18 }, Step = 0.02, Wear = { 10, 20, 30 } },
		Ring = { Stat = "Atk", Base = { 0.04, 0.08, 0.12 }, Step = 0.01, Wear = { 10, 20, 30 } },
	},
	PetSlots = {
		PetArmor = { Stat = "PetXP", Base = { 0.20, 0.40, 0.60 }, Step = 0.10, Wear = { 1, 1, 1 } },
		PetAcc = { Stat = "PetSpeed", Base = { 0.01, 0.02, 0.03 }, Step = 0.005, Wear = { 1, 1, 1 } },
	},
	Text = {
		NotYours = "You don't have that.",
		NeedLevel = "Your level is too low for it.",
		Full = "No room for it.",
		Equipped = "Equipped.",
		Removed = "Taken off.",
		InCombat = "Not during a fight.", -- (게임성 개발 2: no gear change mid-PvP, like a weapon swap)
	},
}
Config.RateLimits.EquipGear = 0.5

-- the slot row of a player slot (Armor / Ring) or a pet slot (PetArmor / PetAcc), nil for anything else
function Config.GearDef(slot)
	if type(slot) ~= "string" then return nil end
	return Config.Gear.Slots[slot] or Config.Gear.PetSlots[slot]
end

-- a gear multiplier that is a real number >= 1 (nil / NaN / infinity / text / below 1 = 1)
function Config.GearMult(v)
	if type(v) ~= "number" or v ~= v or v == math.huge or v < 1 then return 1 end
	return v
end

-- "T:P" written plainly (no leading zeros) -> tier, plus; nil for anything else (tier 1..MaxTier, plus 0..MaxPlus)
function Config.GearParse(key)
	if type(key) ~= "string" or #key > 8 then return nil end
	local t, p = string.match(key, "^(%d+):(%d+)$")
	t, p = tonumber(t), tonumber(p)
	if not t or not p or t < 1 or t > Config.Gear.MaxTier or p > Config.Gear.MaxPlus then return nil end
	if string.format("%d:%d", t, p) ~= key then return nil end
	return t, p
end

-- the x of the table: Base[tier] + Step x plus (0 for an unknown slot, a tier outside 1..MaxTier or a plus outside
-- 0..MaxPlus: a bigger +N is never gear)
function Config.GearBonus(slot, tier, plus)
	local def = Config.GearDef(slot)
	if not def or type(tier) ~= "number" or type(plus) ~= "number" or tier ~= math.floor(tier) or plus ~= math.floor(plus) then return 0 end
	if tier < 1 or tier > Config.Gear.MaxTier or plus < 0 or plus > Config.Gear.MaxPlus then return 0 end
	return math.floor((def.Base[tier] + def.Step * plus) * 10000 + 0.5) / 10000
end

-- the bonus of a worn "T:P" (0 for none / a broken key)
function Config.GearBonusOf(slot, key)
	local t, p = Config.GearParse(key)
	if not t then return 0 end
	return Config.GearBonus(slot, t, p)
end

-- (atkMult, hpMult) of a player from the attributes GearService keeps (GearAtk = the ring, GearHp = the armor; missing /
-- NaN / below 1 = 1); (1, 1) while Config.Features.Gear is off. Server and client alike.
function Config.GearMultsOf(player)
	if not Config.FeatureOn("Gear") then return 1, 1 end
	local ok, a, h = pcall(function() return player:GetAttribute("GearAtk"), player:GetAttribute("GearHp") end)
	if not ok then return 1, 1 end
	return Config.GearMult(a), Config.GearMult(h)
end

-- the bonus (a fraction) a pet's worn PetArmor / PetAcc gives: gear = data.Gear, 0 while the switch is off
function Config.PetGearBonus(gear, uid, slot)
	if not Config.FeatureOn("Gear") or type(gear) ~= "table" or type(gear.Pet) ~= "table" or type(uid) ~= "string" then return 0 end
	local row = gear.Pet[uid]
	if type(row) ~= "table" or Config.Gear.PetSlots[slot] == nil then return 0 end
	return Config.GearBonusOf(slot, row[slot])
end

----------------------------------------------------------------- save v4 tables (docs/design/save_v4_tables_2026-10-11.md)
-- 게임성 개발 2 + 3 agreed 2026-10-11: every table the artisan guild, the gear slots and Otto / the golden egg will save
-- gets its shape and its repair NOW, while the save version is still 3 (additive fields like Stats / Looks: an older v3
-- server keeps them untouched). 게임성 개발 2's C1 then bumps Config.Data.Version to 4 on top (tier 9 = a 9-bit weapon
-- mask) with Spares and Market. Later branches only add behaviour, never another shape. Rules: ids and numbers only (no
-- player-facing text, A23-111 / A23-133); a repair never makes a value up (broken = the default or dropped, counts cut at
-- the caps); a sane flat key this code does not know is kept (a later key needs no version bump); a thing lives in one
-- place only (Gear.Own OR worn in Gear.On / Gear.Pet). Owners: Craft / Research / Gather / Gear / Buffs = 게임성 개발 3,
-- Shop / EggHonorAt = 게임성 개발 2. The services keep their own caps when they write (e.g. 60 things in Gear.Own).
Config.SaveV4 = {
	KeyLen = 32, -- longest id key kept (recipe, monster family, tonic, pet uid)
	SlotLen = 16, -- longest gear slot / kind name kept (letters only)
	MaxKeys = 64, -- most keys kept in one id map (Craft.Made, Research.Pts / Sum, Gear.Own, Gear.Pet)
	MaxCount = 10000000, -- a counter above this is cut (never a free huge number)
	CraftRoles = { "Smith", "Alch", "Tame" }, -- Blacksmith, Alchemist, Tamer: one craft level each (a class change starts over)
	CraftMaxLv = 30,
	GearSlots = { "Armor", "Ring" }, -- the player's worn slots (Gear.On, always present)
	GearMaxTier = 16,
	GearMaxPlus = 2, -- Gear: P (the hammer's +N) is 0..2 and nothing else; a scroll never reaches gear (⑥, 게임성 검수 10/12)
	OwnKeyMax = 20, -- Gear.Own: at most this many of one "<kind>:T:P" key
	BuffMax = 2, -- Buffs: at most two tonics at once
	BuffSeconds = 180, -- one tonic lasts 3 minutes: a saved end is never later than now + this
	ShopDayMax = 50, -- Shop.N: Otto's cheap materials a KST day (게임성 개발 2)
	PetRollSpd = { 5, 10 }, -- Pets.List[uid].Roll.Spd: a summoned pet's walk bonus in whole % (PetService.Sanitize)
	-- C1 (게임성 개발 2): spare weapons and the market ledger
	SpareTierMax = 32, -- Spares "T:P": the shape check keeps tiers 1..32 (a later tier survives this server)
	SpareKeyMax = 20, -- at most this many of one "T:P"
	SpareSum = 60, -- all spares together: the writers refuse above this (the repair never drops for it)
	MarketRows = 64, -- Market.Out / Market.In: most rows kept each (sorted ids)
	MarketDone = 50, -- Market.Done: most finished ids kept
	MarketIdLen = 40, -- a market row id
	MarketMaxN = 999, -- items in one market row
	MarketStates = { Open = true, Sold = true, Cancel = true, Expired = true, Paid = true },
}
-- Craft: a craft level per artisan role + Rep (lifetime artisan points: the rank; the weekly board is Rank.Artisan) +
-- Made (recipe id -> times made). Research: the tamer's points (Pts) and summons (Sum) per monster family (QuestKind).
-- Gather: Day (KST DayIndex of N / Bloom / Gift), N (gathers today), Bloom (shard blooms today), Gift (crown dust others
-- shared today), Total (gathers ever), FirstBloom (the sure first bloom came). Gear: Own["<kind>:T:P"] = n (kinds Armor,
-- Ring, PetArmor, PetAcc), On.<slot> = "T:P" | "" (the player wears it), Pet[pet uid].<slot> = "T:P" (a pet wears it; kept
-- outside Pets because PetService.Sanitize rebuilds every pet row). Buffs: tonic id -> os.time() it ends. Shop: Otto's
-- cheap materials { Day, N }. EggHonorAt: os.time() of the last golden egg Honor / Infamy +5 (A23-134, once an hour)
Config.Data.Defaults.Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {} }
Config.Data.Defaults.Research = { Pts = {}, Sum = {} }
Config.Data.Defaults.Gather = { Day = 0, N = 0, Bloom = 0, Gift = 0, Total = 0, FirstBloom = false }
Config.Data.Defaults.Gear = { Own = {}, On = { Armor = "", Ring = "" }, Pet = {} }
Config.Data.Defaults.Buffs = {}
Config.Data.Defaults.Shop = { Day = 0, N = 0 }
Config.Data.Defaults.EggHonorAt = 0
-- C1 (Version 4): Spares["T:P"] = n spare weapons (tier:plus, not owned in the mask; LootService.AddSpare / SpareRoom).
-- Market: Out[id] = { K, N, Price, St } my listings, In[id] = { Price, St } my buys, Done = finished ids, Day = KST DayIndex
-- of Lists / Buys. K = "I:<item id>" | "W:<T>:<P>"; St = Open | Sold | Cancel | Expired | Paid (MarketService later)
Config.Data.Defaults.Spares = {}
Config.Data.Defaults.Market = { Out = {}, In = {}, Done = {}, Day = 0, Lists = 0, Buys = 0 }

-- the repair helpers of the v4 tables (one local for the whole set: Config's top chunk is near the 200 locals limit)
local V4 = {}

-- a whole number in lo..hi (a fraction floored), or nil for NaN / +-inf / anything that is not a number
function V4.int(v, lo, hi)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
	return math.clamp(math.floor(v), lo, hi)
end

function V4.key(k)
	return type(k) == "string" and #k >= 1 and #k <= Config.SaveV4.KeyLen
end

function V4.slot(k)
	return type(k) == "string" and #k >= 1 and #k <= Config.SaveV4.SlotLen and string.match(k, "^%a+$") ~= nil
end

-- "T:P" -> "T:P" written plainly (tier 1..GearMaxTier, plus 0..maxPlus = Config.SaveV4.GearMaxPlus: gear only gets the
-- hammer's +0..+2), or nil
function V4.tierPlus(s)
	if type(s) ~= "string" or #s > 12 then return nil end
	local t, p = string.match(s, "^(%d+):(%d+)$")
	t, p = tonumber(t), tonumber(p)
	if not t or not p or t < 1 or t > Config.SaveV4.GearMaxTier or p > Config.SaveV4.GearMaxPlus then return nil end
	return string.format("%d:%d", t, p)
end

-- the keys of a table that pass `ok`, sorted (the same save always keeps the same ones when a map is cut)
function V4.sortedKeys(t, ok)
	local keys = {}
	if type(t) ~= "table" then return keys end
	for k in t do
		if ok(k) then table.insert(keys, k) end
	end
	table.sort(keys)
	return keys
end

-- { [id] = count }: sane ids, whole counts 1..max (0 / broken dropped), at most MaxKeys ids
function V4.countMap(src, max)
	local out, kept = {}, 0
	for _, k in V4.sortedKeys(src, V4.key) do
		local n = V4.int(src[k], 0, max)
		if n and n > 0 and kept < Config.SaveV4.MaxKeys then
			out[k] = n
			kept += 1
		end
	end
	return out
end

-- copies the sane flat keys of `src` that `known` does not name (a short string key with a boolean, a finite number or
-- a short string): a later version's new flat field survives this one
function V4.keepExtra(src, out, known)
	for k, v in src do
		if V4.key(k) and not known[k] and out[k] == nil then
			if type(v) == "boolean" or (type(v) == "string" and #v <= Config.SaveV4.KeyLen) then
				out[k] = v
			elseif V4.int(v, -math.huge, math.huge) ~= nil then
				out[k] = v
			end
		end
	end
	return out
end

function Config.SanitizeCraft(t)
	local L = Config.SaveV4
	local src = type(t) == "table" and t or {}
	local out, known = {}, { Rep = true, Made = true }
	for _, role in L.CraftRoles do
		known[role] = true
		local r = type(src[role]) == "table" and src[role] or {}
		out[role] = { Lv = V4.int(r.Lv, 1, L.CraftMaxLv) or 1, XP = V4.int(r.XP, 0, L.MaxCount) or 0 }
	end
	out.Rep = V4.int(src.Rep, 0, L.MaxCount) or 0
	out.Made = V4.countMap(src.Made, L.MaxCount)
	-- Pend (CraftService, 게임성 검수 10/12): a craft paid and not delivered yet = { Id = recipe id, Plus = -1 (not hammered
	-- yet) | 0..2, Gold = what was paid, Mats = { [item] = n } paid } (a vanished recipe pays it back); anything else = none
	known.Pend = true
	local p = src.Pend
	if type(p) == "table" and V4.key(p.Id) then
		out.Pend = { Id = p.Id, Plus = V4.int(p.Plus, -1, 2) or -1, Gold = V4.int(p.Gold, 0, L.MaxCount) or 0,
			Mats = V4.countMap(p.Mats, L.MaxCount) }
	end
	return V4.keepExtra(src, out, known)
end

function Config.SanitizeResearch(t)
	local src = type(t) == "table" and t or {}
	local out = { Pts = V4.countMap(src.Pts, Config.SaveV4.MaxCount), Sum = V4.countMap(src.Sum, Config.SaveV4.MaxCount) }
	return V4.keepExtra(src, out, { Pts = true, Sum = true })
end

function Config.SanitizeGather(t)
	local src = type(t) == "table" and t or {}
	local out = { FirstBloom = src.FirstBloom == true }
	for _, k in { "Day", "N", "Bloom", "Gift", "Total" } do
		out[k] = V4.int(src[k], 0, Config.SaveV4.MaxCount) or 0
	end
	return V4.keepExtra(src, out, { Day = true, N = true, Bloom = true, Gift = true, Total = true, FirstBloom = true })
end

-- worn slots { [slot] = "T:P" }: letter slot names, plain "T:P" values; anything else dropped
local function wornSlots(src)
	local out = {}
	if type(src) ~= "table" then return out end
	for k, v in src do
		local tp = V4.slot(k) and V4.tierPlus(v)
		if tp then out[k] = tp end
	end
	return out
end

function Config.SanitizeGear(t)
	local L = Config.SaveV4
	local src = type(t) == "table" and t or {}
	-- Own: "<kind>:T:P" written plainly ("Armor:01:0" and "Armor:1:0" are one key), counts 1..OwnKeyMax
	local own, kept = {}, 0
	for _, k in V4.sortedKeys(src.Own, function(k) return type(k) == "string" end) do
		local kind, rest = string.match(k, "^(%a+):(.+)$")
		local tp = kind and V4.slot(kind) and V4.tierPlus(rest)
		local n = V4.int(src.Own[k], 0, L.OwnKeyMax)
		if tp and n and n > 0 then
			local key = kind .. ":" .. tp
			if own[key] ~= nil then
				own[key] = math.min(L.OwnKeyMax, own[key] + n)
			elseif kept < L.MaxKeys then
				own[key] = n
				kept += 1
			end
		end
	end
	-- On: the player's slots, always present ("" = empty)
	local on = wornSlots(src.On)
	for _, slot in L.GearSlots do
		if on[slot] == nil then on[slot] = "" end
	end
	-- Pet: per pet uid, only uids that still wear something
	local pet, pets = {}, 0
	for _, uid in V4.sortedKeys(src.Pet, V4.key) do
		local worn = wornSlots(src.Pet[uid])
		if next(worn) ~= nil and pets < L.MaxKeys then
			pet[uid] = worn
			pets += 1
		end
	end
	return V4.keepExtra(src, { Own = own, On = on, Pet = pet }, { Own = true, On = true, Pet = true })
end

-- Buffs at `now` (os.time()): an end in the past is dropped, one later than now + BuffSeconds is cut to that (never a
-- longer buff), at most BuffMax (the ones that end last)
function Config.SanitizeBuffs(t, now)
	local L = Config.SaveV4
	now = V4.int(now, 0, 2 ^ 52) or os.time()
	local list = {}
	if type(t) == "table" then
		for id, v in t do
			local ends = V4.int(v, 0, now + L.BuffSeconds)
			if V4.key(id) and ends and ends > now then table.insert(list, { id, ends }) end
		end
	end
	table.sort(list, function(a, b)
		if a[2] ~= b[2] then return a[2] > b[2] end
		return a[1] < b[1]
	end)
	local out = {}
	for i = 1, math.min(#list, L.BuffMax) do
		out[list[i][1]] = list[i][2]
	end
	return out
end

function Config.SanitizeShop(t)
	local src = type(t) == "table" and t or {}
	local out = { Day = V4.int(src.Day, 0, Config.SaveV4.MaxCount) or 0, N = V4.int(src.N, 0, Config.SaveV4.ShopDayMax) or 0 }
	return V4.keepExtra(src, out, { Day = true, N = true })
end

-- EggHonorAt at `now`: a whole os.time() not after now. A future value (another server's clock a few seconds ahead) is cut
-- to now, never to 0: the next hourly +5 may open a little late but never early (게임성 검수 2026-10-11)
function Config.SanitizeEggHonorAt(v, now)
	now = V4.int(now, 0, 2 ^ 52) or os.time()
	local at = V4.int(v, 0, 2 ^ 52) or 0
	return math.min(at, now)
end

-- C1: a spare weapon key "T:P" written plainly (T 1..SpareTierMax, a later tier kept; P 0..MaxEnhance), or nil
function V4.spareKey(s)
	if type(s) ~= "string" or #s > 12 then return nil end
	local t, p = string.match(s, "^(%d+):(%d+)$")
	t, p = tonumber(t), tonumber(p)
	if not t or not p or t < 1 or t > Config.SaveV4.SpareTierMax or p > Config.Loot.MaxEnhance then return nil end
	return string.format("%d:%d", t, p) -- "04:0" -> "4:0"
end

-- Spares { ["T:P"] = n }: n 1..SpareKeyMax (0 / broken = key dropped), "04:0" + "4:0" merged, at most MaxKeys keys
-- (sorted). The total SpareSum is NOT cut here: the writers refuse (save_v4 §1)
function Config.SanitizeSpares(t)
	local L = Config.SaveV4
	local out, kept = {}, 0
	if type(t) ~= "table" then return out end
	for _, k in V4.sortedKeys(t, function(k) return type(k) == "string" end) do
		local key = V4.spareKey(k)
		local n = V4.int(t[k], 0, L.SpareKeyMax)
		if key and n and n > 0 then
			if out[key] ~= nil then
				out[key] = math.min(L.SpareKeyMax, out[key] + n)
			elseif kept < L.MaxKeys then -- a new key
				out[key] = n
				kept += 1
			end
		end
	end
	return out
end

-- a market row id: a string of 1..MarketIdLen characters
function V4.marketId(k)
	return type(k) == "string" and #k >= 1 and #k <= Config.SaveV4.MarketIdLen
end

-- a market thing key: "I:<item id>" or "W:<T>:<P>" (written plainly), at most KeyLen + 8 characters; else nil
function V4.marketKey(k)
	if type(k) ~= "string" or #k > Config.SaveV4.KeyLen + 8 then return nil end
	if string.match(k, "^I:[%w_]+$") then return k end
	local tp = string.match(k, "^W:(.+)$")
	tp = tp and V4.spareKey(tp)
	return tp and ("W:" .. tp) or nil
end

-- the rows of Out / In: sane ids (sorted, at most MarketRows), a row that `row` refuses is dropped
function V4.marketRows(src, row)
	local out, kept = {}, 0
	for _, id in V4.sortedKeys(src, V4.marketId) do
		local r = type(src[id]) == "table" and row(src[id]) or nil
		if r and kept < Config.SaveV4.MarketRows then
			out[id] = r
			kept += 1
		end
	end
	return out
end

-- Market { Out[id] = { K, N, Price, St }, In[id] = { Price, St }, Done = { ids }, Day, Lists, Buys }: a row with a
-- broken K / N / Price or an unknown St is dropped (never made up); Done keeps the newest MarketDone ids (list end)
function Config.SanitizeMarket(t)
	local L = Config.SaveV4
	local src = type(t) == "table" and t or {}
	local function price(r)
		local p = V4.int(r.Price, 0, L.MaxCount)
		return (p and p >= 1) and p or nil
	end
	local function state(r)
		return type(r.St) == "string" and L.MarketStates[r.St] == true and r.St or nil
	end
	local out = {}
	out.Out = V4.marketRows(src.Out, function(r)
		local k, n, p, st = V4.marketKey(r.K), V4.int(r.N, 0, L.MarketMaxN), price(r), state(r)
		if not (k and n and n >= 1 and p and st) then return nil end
		return V4.keepExtra(r, { K = k, N = n, Price = p, St = st }, { K = true, N = true, Price = true, St = true })
	end)
	out.In = V4.marketRows(src.In, function(r)
		local p, st = price(r), state(r)
		if not (p and st) then return nil end
		return V4.keepExtra(r, { Price = p, St = st }, { Price = true, St = true })
	end)
	-- Done: a list; sane unique ids, the last MarketDone of them in their order
	local ids, seen = {}, {}
	if type(src.Done) == "table" then
		for i = 1, math.min(#src.Done, 4096) do
			local id = src.Done[i]
			if V4.marketId(id) and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	out.Done = {}
	for i = math.max(1, #ids - L.MarketDone + 1), #ids do
		table.insert(out.Done, ids[i])
	end
	for _, k in { "Day", "Lists", "Buys" } do
		out[k] = V4.int(src[k], 0, L.MaxCount) or 0
	end
	return V4.keepExtra(src, out, { Out = true, In = true, Done = true, Day = true, Lists = true, Buys = true })
end

-- every v4 table of a save, in place (DataService.fillDefaults, after the default fill)
function Config.SanitizeSaveV4(d, now)
	now = V4.int(now, 0, 2 ^ 52) or os.time()
	d.Craft = Config.SanitizeCraft(d.Craft)
	d.Research = Config.SanitizeResearch(d.Research)
	d.Gather = Config.SanitizeGather(d.Gather)
	d.Gear = Config.SanitizeGear(d.Gear)
	d.Buffs = Config.SanitizeBuffs(d.Buffs, now)
	d.Shop = Config.SanitizeShop(d.Shop)
	d.EggHonorAt = Config.SanitizeEggHonorAt(d.EggHonorAt, now)
	d.Spares = Config.SanitizeSpares(d.Spares)
	d.Market = Config.SanitizeMarket(d.Market)
end

------------------------------------------------------------------ A23-153 monster codex (게임성 개발 2, 2026-10-13)
-- Design docs/design/codex_cards_2026-10-12.md (최종 검수); the screen contract docs/design/codex_cards_contract_2026-10-13.md.
-- Save v5 (DataService): Codex = { [kind] = { Kills, Golden, Stage, First } } for the series-1 kinds of Pages only. Every kill
-- CodexService counts (KillLog's rule: MonsterService.MonsterKilled, never a personal monster) adds one to Kills (a golden
-- one to Golden too). A card is born at the first kill (Stage 1), evolves at Steps[2] (Silver) and Steps[3] (Gold Holo);
-- the first golden kill of a kind gives its Gold Foil card (bosses are never golden: no foil). Each stage and the foil pay
-- Reward = that many kills' worth of the kind's own MonsterTypes XP / Gold (never golden x, never stats, never sold); a
-- full page (every kind at Stage >= 1) gives its Title; every card at Stage 3 lights the cosmetic CodexGlow (display only).
-- First = os.time() of the first kill (0 = before the codex: a card the v5 step made from the kill record).
Config.Codex = {
	Enabled = true,
	Steps = { 1, 100, 1000 }, -- kills for Stage 1 / 2 / 3 (A23-153)
	-- the field bosses (Boss = true): 최종 검수 2026-10-13 1 / 10 / 30 (1000 Captain Clatters, one every 20 min, = ~330 h)
	BossSteps = { 1, 10, 30 },
	Pages = { -- series 1 = the beta hunting zones (A23-152); later series add pages (Halloween, the new zones, pets)
		{ Id = "SlimeMeadow", Title = "SlimeScholar", Kinds = { "Slime", "FlowerSlime", "BigSlime", "SlimeKing" } },
		{ Id = "GoblinWoods", Title = "GoblinScholar", Kinds = { "Goblin", "SlingshotGoblin", "GoblinBrute" } },
		{ Id = "SkeletonRuins", Title = "SkeletonScholar", Kinds = { "Skeleton", "SkeletonArcher", "SkeletonKnight",
			"CaptainClatter" } },
	},
	-- kills' worth per stage (1, 2, 3), per stage for a boss, and for the Gold Foil card
	Reward = { Stage = { 3, 20, 100 }, BossStage = { 1, 3, 10 }, Golden = 5 },
	MaxKills = 1000000000,
	-- the server also sends the line as a toast (Net.Notify "reward"); 게임성 개발 1 turns this off once the card moment
	-- shows the line itself (CodexUp carries the same line). Off (게임성 개발 1 10/13): CodexUI.luau shows every line - a
	-- card moment, the reward popup (Page / Glow) or, with the codex window open, a toast
	ServerToast = false,
	Attr = { Cards = "CodexCards", Glow = "CodexGlow" }, -- player attributes (cards owned; every card Gold Holo)
	-- 최종 검수 10/13: the 3D card models the codex window draws (게임성 개발 1): ReplicatedStorage[ModelFolder][kind], copied at
	-- the server's start from ServerStorage.CustomModels by MonsterService's rule (the kind's own model, else its ModelFrom)
	ModelFolder = "CodexModels",
	Text = {
		Name = "Monster Codex",
		Card = "New card: %s!", -- (the monster's Short name)
		Silver = "%s card is now Silver!",
		Holo = "%s card is now Gold Holo!",
		Golden = "Gold Foil card: %s!",
		Reward = "+%s gold · +%s XP",
		RewardGold = "+%s gold", -- no XP added (the top level)
		Page = "%s page done! New title: %s", -- (the page's zone name, the title's name)
		Glow = "Every card is Gold Holo! Your sparkle is on.",
		Stages = { "Card", "Silver", "Gold Holo" }, -- the stage names, 1..3
		Foil = "Gold Foil",
		Before = "Before the Codex", -- the first-kill day of a card with First = 0
	},
	-- the card back's one line in my side's voice (GDD §0): Halo = a kind watcher, Horns = a playful tease, Neutral = an
	-- artisan's material note (side None reads Neutral). Draft lines for 최종 검수 to edit.
	Lore = {
		Slime = { Halo = "The youngest slime. Be gentle, it is just a baby.",
			Horns = "Poke it and it wobbles. Poke it again. Ha!",
			Neutral = "Drops Jelly. Soft, sticky, always handy." },
		FlowerSlime = { Halo = "It hides in the flowers and naps in the sun.",
			Horns = "It thinks it is a flower. Let's not tell it.",
			Neutral = "Its Flower Petals stay fresh for days." },
		BigSlime = { Halo = "The eldest slime. He tries hard to look brave.",
			Horns = "A prince with a wobbly crown. So royal. So squishy.",
			Neutral = "Big slime, big Slime Core. Bring a bag." },
		SlimeKing = { Halo = "The slime dad. He raises his kids all alone.",
			Horns = "He jumps, he lands, the ground goes boing!",
			Neutral = "Royal Jelly is rare and thick. Keep it safe." },
		Goblin = { Halo = "He steals shards, but he shares his snacks.",
			Horns = "A thief! I like his style. Not his smell.",
			Neutral = "Goblin Teeth are small, sharp and useful." },
		SlingshotGoblin = { Halo = "Step aside and his pebbles miss. Mostly.",
			Horns = "Pebbles in the face? Rude. Funny, but rude.",
			Neutral = "Same teeth as his friends. Same bad aim." },
		GoblinBrute = { Halo = "Big and slow. He only wants his nap.",
			Horns = "All muscles, no plan. I respect that.",
			Neutral = "A Brute Horn is hard as stone." },
		Skeleton = { Halo = "A guard of the old kingdom, still on duty.",
			Horns = "Rattle rattle! Who needs skin anyway?",
			Neutral = "Old Bones. Light, hard and useful." },
		SkeletonArcher = { Halo = "His arrows fly slow. Step aside and stay safe.",
			Horns = "No eyes, still aims. What a show-off.",
			Neutral = "More Old Bones. The ruins never run out." },
		SkeletonKnight = { Halo = "A knight who never left his post.",
			Horns = "Heavy armor, empty head. Classic.",
			Neutral = "His Rusty Knight Crest still shines a little." },
		CaptainClatter = { Halo = "300 years on duty. Please give him a break.",
			Horns = "He yells at everyone. Even the wind.",
			Neutral = "His Old Crown Gem is bright. Handle with care." },
	},
}
-- A23-153 the codex screen (게임성 개발 1, CodexUI.luau; contract docs/design/codex_cards_contract_2026-10-13.md §7): the
-- window's and the card moments' own words (game text English only; the server's lines are Config.Codex.Text), the card
-- rims by look (None = not met, Card / Silver / Holo by stage, Foil = the Gold Foil card) and the moments' timing. No
-- new art: the approved PanelCard / SlotEmpty / SlotCommon / Chip / Btn* parts with their UIKit fallbacks; the sparkles
-- are the round RewardSparkle (A23-153: never rays)
Config.Codex.Screen = {
	Text = {
		Count = "%d/%d cards",
		Kills = "Defeated: %s", -- (the key kept; final review 10/13: "Kills" is a banned word for kids, test_story_text)
		NextAt = "%s at %s", -- the next stage's name at that many kills ("Silver at 100")
		Top = "Top stage!",
		Unknown = "???",
		NotMet = "Not met yet",
		Flip = "Flip",
		Front = "Front",
		Tilt = "Auto tilt",
		ShowFoil = "Gold Foil",
		ShowCard = "Card",
		Where = "Found in: %s",
		Drops = "Drops: %s",
		First = "First met: %s",
		Ok = "Yay!",
		Months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
	},
	Rim = { None = Color3.fromRGB(90, 96, 120), Card = Color3.fromRGB(196, 150, 92), Silver = Color3.fromRGB(214, 222, 236),
		Holo = Color3.fromRGB(255, 214, 92), Foil = Color3.fromRGB(255, 186, 40) },
	Moment = { Hold = 2.6, Max = 8 }, -- s a card moment stays; moments waiting at most (the oldest go)
}

-- the series-1 kinds in card order, and the page index of each
Config.Codex.Order, Config.Codex.PageOf = {}, {}
for i, page in Config.Codex.Pages do
	for _, kind in page.Kinds do
		table.insert(Config.Codex.Order, kind)
		Config.Codex.PageOf[kind] = i
	end
end
Config.Data.Defaults.Codex = {} -- save v5 (the version step: DataService.migrate)
Config.RateLimits.CodexOpen = 1 -- c->s "CodexOpen" (no arguments): the answer is the "Codex" snapshot
Config.PassBoost.GoldSources.Codex = true -- earned gold (the 2x Gold pass doubles it)
Config.TitleDefs.SlimeScholar = { Name = "Slime Scholar", NameEn = "Slime Scholar", Color = Color3.fromRGB(140, 220, 140) }
Config.TitleDefs.GoblinScholar = { Name = "Goblin Scholar", NameEn = "Goblin Scholar", Color = Color3.fromRGB(170, 200, 90) }
Config.TitleDefs.SkeletonScholar = { Name = "Skeleton Scholar", NameEn = "Skeleton Scholar",
	Color = Color3.fromRGB(225, 220, 200) }
for _, id in { "SlimeScholar", "GoblinScholar", "SkeletonScholar" } do
	if not table.find(Config.TitleOrder, id) then table.insert(Config.TitleOrder, id) end
end

-- the kill steps of a kind's card (a boss: BossSteps)
function Config.CodexSteps(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return (type(def) == "table" and def.Boss == true) and Config.Codex.BossSteps or Config.Codex.Steps
end

-- the stage `kills` kills reach (0 = no card yet)
function Config.CodexStage(kind, kills)
	local n = tonumber(kills) or 0
	local stage = 0
	for i, need in Config.CodexSteps(kind) do
		if n >= need then stage = i end
	end
	return stage
end

-- a kind a page / the glow waits for: one that can appear now (a field boss, or a kind with a spawn count). Gameplay plan
-- 2026-10-13 1-A #7: the Slingshot Goblin and the Skeleton Archer spawn 0 while Config.Mobs3Ranged is off, so the woods /
-- ruins pages and the glow could never finish; they count again the moment they spawn
function Config.CodexCounts(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return type(def) == "table" and (def.Boss == true or (tonumber(def.Count) or 0) > 0)
end

-- a kind that can have a Gold Foil card (bosses are never golden)
function Config.CodexCanGold(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return type(def) == "table" and def.Boss ~= true
end

-- the repaired Codex of a save: series-1 kinds only, rows with Kills >= 1; whole numbers (Kills / Golden 0..MaxKills,
-- Golden <= Kills and 0 for a boss, First >= 0); Stage 0..3 and never below the stage its Kills reach (a stage is never
-- taken back). Repairing twice = once.
function Config.SanitizeCodex(src)
	local out = {}
	if type(src) ~= "table" then return out end
	local function int(v, hi)
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return 0 end
		return math.clamp(math.floor(v), 0, hi)
	end
	for _, kind in Config.Codex.Order do
		local e = src[kind]
		if type(e) == "table" then
			local kills = int(e.Kills, Config.Codex.MaxKills)
			if kills >= 1 then
				local golden = Config.CodexCanGold(kind) and math.min(int(e.Golden, Config.Codex.MaxKills), kills) or 0
				out[kind] = { Kills = kills, Golden = golden, Stage = math.max(int(e.Stage, 3), Config.CodexStage(kind, kills)),
					First = int(e.First, 2 ^ 52) }
			end
		end
	end
	return out
end

-- DataService.migrate's v5 step: the cards a record earned before the codex, from its kill record (KillLog.ByKind: no
-- golden split, no first day -> Golden 0, First 0). An existing row keeps its larger numbers. No reward, no toast.
function Config.CodexFromKillLog(killLog, codex)
	local out = Config.SanitizeCodex(codex)
	local byKind = (type(killLog) == "table" and type(killLog.ByKind) == "table") and killLog.ByKind or {}
	for _, kind in Config.Codex.Order do
		local n = byKind[kind]
		if type(n) == "number" and n == n and n >= 1 and n ~= math.huge then
			n = math.min(math.floor(n), Config.Codex.MaxKills)
			local e = out[kind]
			if not e then
				out[kind] = { Kills = n, Golden = 0, Stage = Config.CodexStage(kind, n), First = 0 }
			elseif e.Kills < n then
				e.Kills = n
				e.Stage = math.max(e.Stage, Config.CodexStage(kind, n))
			end
		end
	end
	return out
end

-- A23-160 ④ (게임성 개발 2, 10/13): the private test's numbers board (TestMetricsService; docs/design/test_metrics_2026-10-13.md,
-- read with tools/test_metrics_board.py). One document per test round in its own DataStore (Config.StoreName(Store); Studio: its
-- own "_STUDIO" copy), key = Round; no name or UserId. New = an account first seen this round as a fresh save (no intro, Lv1, no
-- kill, under FreshSeconds of play). Milestones of a new account, at whole minutes of play: Lv5, Lv10, Weapon (the first
-- dropped weapon, tier 2+), Claim (the first mission claimed). TenMinutes = the "10-minute run" (Lv5 + Weapon + Claim all
-- before it). Passes: bought, then on a later join (KeptDelay s after it, once the ownership check ran) still working or not.
Config.TestMetrics = {
	Enabled = true,
	Store = "HaloHorns_TestMetrics_v1",
	Round = "PT1", -- 10/17-20; the next test (12/3-6, A23-162) = "PT2"
	FlushSeconds = 60,
	FreshSeconds = 120,
	TenMinutes = 10,
	MaxMinute = 60, -- a later milestone is counted at minute 60
	KeptDelay = 20,
	Milestones = { "Lv5", "Lv10", "Weapon", "Claim" },
}

-- A23-156 (user 10/13): the private test server (10/17-20) plays with three settings on: the Z skill (Lv15; Z on players stays
-- off, PvPZX), a golden goose every 10 minutes (the real rule stays every 4 hours) and the pass sales. Applied by
-- Config.ApplyTestServer(), which Main.server.luau and ClientMain.client.luau call first thing (so both sides read the same
-- values, and the offline tests keep the real defaults). After the test: Enabled = false.
Config.TestServer = {
	Enabled = true,
	Skills = { ZEnabled = true },
	GooseEvery = 600,
	PassSales = true,
}

function Config.ApplyTestServer()
	-- 최종 검수 10/13 review: never on the Live game, even when Enabled = false is forgotten after the test
	if type(Config.EnvName) == "function" and Config.EnvName() == "Live" then return false end
	local T = Config.TestServer
	if type(T) ~= "table" or T.Enabled ~= true or T.Applied == true then return false end
	T.Applied = true
	if type(T.Skills) == "table" and type(Config.Skills) == "table" then
		for k, v in T.Skills do Config.Skills[k] = v end
	end
	local every = tonumber(T.GooseEvery)
	if every and every > 0 and type(Config.Goose) == "table" and type(Config.Goose.Schedule) == "table" then
		Config.Goose.Schedule.Every = math.floor(every)
	end
	local defs = type(Config.Switches) == "table" and Config.Switches.Defs or nil
	if T.PassSales ~= nil and type(defs) == "table" and type(defs.PassSales) == "table" then
		defs.PassSales.Default = T.PassSales == true
	end
	return true
end

return Config
