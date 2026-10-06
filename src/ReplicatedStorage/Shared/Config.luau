-- Config.luau : every tuning number, pure helper formula and Korean string for Halo & Horns.
-- Shared by server and client. Pure data + pure functions only (no services, no instances).
local Config = {}

Config.Game = {
	Name = "선악 키우기: 헤일로 & 혼즈",
	MaxPlayers = 20, -- documentation only; set in Studio Game Settings
}

----------------------------------------------------------------- player / data
Config.Player = {
	WalkSpeed = 20,
	RespawnTime = 3,
	BaseMaxHealth = 100,
	MaxHealthPerLevel = 10,
	PlaytimeTick = 5, -- seconds between PlaytimeSeconds updates
	CollisionGroup = "Players", -- addendum A7-5: PhysicsService group, not collidable with itself (PlayerService)
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
	StoreName = "HaloHorns_Nicknames_v1", -- universe-wide claims; no Studio memory fallback
	MinLength = 2, MaxLength = 20, MaxBytes = 80,
	ChangeInterval = 10,
	-- Claimed aliases stay with their owner. Never free a name after an uncertain cross-key response.
	RetainPreviousClaims = true,
}

Config.Data = {
	StoreName = "HaloHorns_Player_v1", -- unchanged on purpose: v1 saves are migrated in place by DataService
	KeyPrefix = "P_",
	-- B4: 3 = weapon tier 8 + Items / WeaponEnhance / LootFlags. An older server refuses a newer record (CR-L3).
	Version = 3,
	AutosaveInterval = 60,
	LockTimeout = 120, -- seconds; a lock older than this is considered dead
	LoadRetries = 5,
	LoadRetryDelay = 3,
	SaveRetries = 3,
	Defaults = {
		Version = 3,
		Level = 1,
		XP = 0,
		BankGold = 0,
		CarriedGold = 0,
		WeaponTier = 1, -- v1 name: SwordTier (migrated by DataService)
		WeaponOwnedMask = 1, -- tier N uses bit N-1; the free starting weapon is always owned
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
		-- rebirth), one-time loot flags (e.g. FirstScroll = the guaranteed first king-slime scroll)
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
		Settings = { V = 1, Keys = {}, Sfx = 1, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = true, Lang = "Auto", BagSort = "Default" },
		Telemetry = {}, -- P6: { Onb = last onboarding funnel step logged, FirstDeath = true } (analytics only)
		-- CR-M4: anti-collusion pair cooldowns kept in the session-locked save so they follow the player across servers
		-- (never mirrored). ["<kind>:<otherUserId>"] = os.time() of the last reward (PlayerService.PairReady);
		-- "kolog:<victimUserId>" = { t1, t2 } (last two KOs). Pruned at PlayerReady (> 1800 s old, at most 200 keys).
		PairCD = {},
		-- CR-M12: bully stacks / wanted stars saved at leave with os.time(); restored minus decay on the next join
		SavedBully = 0,
		SavedBullyAt = 0,
		SavedStars = 0,
		SavedStarsAt = 0,
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

-- display names per class; tier 7 is a table keyed by faction. Index = saved tier key: only ever APPEND tiers.
-- T4-T6 names come from the monsters that drop them (design skills_weapons_pets_2026-10-05 §1 B3).
Config.WeaponNames = {
	Warrior = { "나뭇가지", "나무 검", "철 검", "숲도둑 황금 검", "옛 왕국 수정 검", "수호령 검",
		{ Halo = "여명의 검", Horns = "파멸의 검", None = "왕관 조각 검" }, "젤리 왕관 검" },
	Mage = { "마른 지팡이", "참나무 지팡이", "철 지팡이", "숲도둑 황금 지팡이", "옛 왕국 수정 지팡이", "수호령 지팡이",
		{ Halo = "여명의 지팡이", Horns = "파멸의 지팡이", None = "왕관 조각 지팡이" }, "젤리 왕관 지팡이" },
	Archer = { "새총 활", "나무 활", "철 활", "숲도둑 황금 활", "옛 왕국 수정 활", "수호령 활",
		{ Halo = "여명의 활", Horns = "파멸의 활", None = "왕관 조각 활" }, "젤리 왕관 활" },
}
-- English names (localization later; same indexes)
Config.WeaponNamesEn = {
	Warrior = { "Twig", "Wooden Sword", "Iron Sword", "Goblin Thief's Golden Sword", "Old Kingdom Crystal Sword", "Guardian Spirit Sword",
		{ Halo = "Dawn Sword", Horns = "Ruin Sword", None = "Crown Shard Sword" }, "Jelly Crown Sword" },
	Mage = { "Dry Staff", "Oak Staff", "Iron Staff", "Goblin Thief's Golden Staff", "Old Kingdom Crystal Staff", "Guardian Spirit Staff",
		{ Halo = "Dawn Staff", Horns = "Ruin Staff", None = "Crown Shard Staff" }, "Jelly Crown Staff" },
	Archer = { "Slingshot Bow", "Wooden Bow", "Iron Bow", "Goblin Thief's Golden Bow", "Old Kingdom Crystal Bow", "Guardian Spirit Bow",
		{ Halo = "Dawn Bow", Horns = "Ruin Bow", None = "Crown Shard Bow" }, "Jelly Crown Bow" },
}

-- Weapon grades (design §1 B1): stars are RARITY, not power. Colors = ART_DIRECTION 2.3 grade strokes.
Config.WeaponGrades = {
	Common = { Name = "일반", NameEn = "Common", Stars = 1, Color = Color3.fromRGB(200, 200, 200), Rank = 1 },
	Fine = { Name = "고급", NameEn = "Fine", Stars = 2, Color = Color3.fromRGB(90, 200, 90), Rank = 2 },
	Rare = { Name = "희귀", NameEn = "Rare", Stars = 3, Color = Color3.fromRGB(70, 140, 255), Rank = 3 },
	Epic = { Name = "영웅", NameEn = "Epic", Stars = 4, Color = Color3.fromRGB(170, 90, 230), Rank = 4 },
	Legend = { Name = "전설", NameEn = "Legendary", Stars = 5, Color = Color3.fromRGB(255, 160, 40), Rank = 5 },
}
-- per tier: grade id + where it comes from (one line, shown in the item list / blacksmith)
Config.WeaponInfo = {
	{ Grade = "Common", Source = "처음부터 가진 무기" },
	{ Grade = "Common", Source = "대장간에서 사요" },
	{ Grade = "Fine", Source = "대장간에서 사요 (Lv5부터)" },
	{ Grade = "Rare", Source = "고블린·고블린 우두머리가 드물게" },
	{ Grade = "Epic", Source = "해골 병사·해골 기사가 드물게" },
	{ Grade = "Epic", Source = "해골 기사가 아주 드물게" },
	{ Grade = "Legend", Source = "정식 출시 때 장인 제작" },
	{ Grade = "Legend", Source = "슬라임이 아주아주 드물게 (대박!)" },
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
-- weapon it is); tier 1 is always owned and usable
function Config.BestUsableWeapon(ownedMask, level)
	local best, bestDamage = 1, -1
	local mask = math.floor(tonumber(ownedMask) or 1)
	for tier, def in Config.Weapons do
		if type(def) == "table" and (tier == 1 or bit32.band(mask, bit32.lshift(1, tier - 1)) ~= 0)
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
	local names = Config.WeaponNames[classId] or Config.WeaponNames.Warrior
	local n = names[tier]
	if type(n) == "table" then return n[factionId] or n.None end
	return n or "?"
end

-- Existing GPT inventory icons; tier 7 uses the chosen faction, with the neutral icon as the unset fallback.
function Config.WeaponArtKey(tier, classId, factionId)
	if type(tier) ~= "number" or tier ~= tier or math.abs(tier) == math.huge then tier = 1 end
	tier = math.clamp(math.floor(tier), 1, Config.MaxWeaponTier)
	if classId ~= "Warrior" and classId ~= "Mage" and classId ~= "Archer" then classId = "Warrior" end
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

-- normal per-target damage of the weapon at this level and enhancement (before class, bonuses and multipliers)
function Config.WeaponDamage(tier, level, enhance)
	local w = Config.Weapons[tier] or Config.Weapons[1]
	return w.Damage * (1 + Config.Combat.LevelDamagePerLevel * (level - 1)) * Config.EnhanceMult(enhance)
end

-- basic attacks to defeat a monster with the server's swing formula (no crit / perks / faction bonuses):
-- what actually changes when the blacksmith sells a weapon (the shop never shows raw weapon Damage)
function Config.SwingHitsToKill(tier, level, classId, monsterId, factionId, enhance)
	local m = Config.MonsterTypes and Config.MonsterTypes[monsterId]
	local c = Config.Classes[classId] or Config.Classes.Warrior
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
		Names = { Halo = "성기사", Horns = "광전사", Neutral = "대장장이", None = "전사" },
		Desc = "내 주변 적을 한 번에 전부 베어요. 튼튼해요!",
		PickLine = "가까이 붙어서 주변을 한 번에 쾅", -- addendum A7-4 (picker card action line)
		Weapon = "Sword",
		HealthMult = 1.3, Damage = 1.0, SwingInterval = 1.0,
		Pattern = "Around", -- every valid target within Range of self
		Range = 10, Targets = 0, Splash = 0, -- Targets 0 = unlimited
		AimCone = 75, -- user 2026-10-06: every class attacks where it faces (basic swing = a front sweep)
		ReleaseCenter = "Self", -- shockwave on self (the skill stays an all-around blast)
		ChargeAuto = 1, ChargeManual = 2,
		Ranged = false, PvPMult = 1.0,
		WalkSpeedMult = 1.0,
		ReleaseMult = 1.0, -- tuning knob: multiplies this class's release damage
		Stats = { "체력 ×1.3", "공격 ×1.0", "주변 전체 공격" },
		DisplayStats = { HP = 4, Atk = 3, Spd = 2 }, -- picker card bars (체력 / 공격 / 속도), 5-point scale, cosmetic only
	},
	Mage = {
		Id = "Mage",
		Names = { Halo = "빛의 마법사", Horns = "흑마법사", Neutral = "연금술사", None = "마법사" },
		Desc = "멀리 있는 적에게 마법 구슬! 맞은 곳 주변까지 펑!",
		PickLine = "조금 떨어져서 넓게 펑", -- addendum A7-4
		Weapon = "Staff",
		HealthMult = 0.8, Damage = 1.3, SwingInterval = 1.1, -- 2026-10-06 user: mage a bit stronger (was 1.25)
		Pattern = "Splash", -- nearest valid target within Range, then every valid target within Splash of it
		Range = 35, Targets = 1, Splash = 7,
		AimCone = 80, -- only targets within 80 degrees of where I face (2026-10-06: no shots behind / sideways)
		ReleaseCenter = "Target", -- meteor on the nearest target within Range (self if none)
		ChargeAuto = 1, ChargeManual = 2,
		Ranged = true, PvPMult = 0.85,
		WalkSpeedMult = 1.0,
		ReleaseMult = 1.0,
		Stats = { "체력 ×0.8", "공격 ×1.3", "35칸 원거리 + 폭발" },
		DisplayStats = { HP = 2, Atk = 4, Spd = 3 },
	},
	Archer = {
		Id = "Archer",
		Names = { Halo = "레인저", Horns = "그림자 사냥꾼", Neutral = "사냥꾼", None = "궁수" },
		Desc = "빠르게 두 명씩 쏘고, 발이 빨라요.",
		PickLine = "멀리서 하나씩 슝", -- addendum A7-4
		Weapon = "Bow",
		HealthMult = 1.0, Damage = 0.55, SwingInterval = 0.5,
		Pattern = "Multi", -- the Targets nearest valid targets within Range
		Range = 30, Targets = 2, Splash = 0,
		AimCone = 80, -- only targets within 80 degrees of where I face (2026-10-06: no shots behind / sideways)
		ReleaseCenter = "Target", -- arrow rain on the nearest target within Range (self if none)
		ChargeAuto = 0.5, ChargeManual = 1, -- swings twice as often, so half the stacks per swing
		Ranged = true, PvPMult = 0.85,
		WalkSpeedMult = 1.1,
		ReleaseMult = 1.0,
		Stats = { "체력 ×1.0", "공격 ×0.55 (2배 빠름)", "30칸 2명 동시 · 이동 +10%" },
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
}

----------------------------------------------------------------- charge & release ("자동은 장전, 손은 발사")
-- Design intent: pure idle (auto swings + auto release) ~= 1.25x baseline DPS; auto swings + PERFECT release ~= 2.5x.
-- Compatibility constants for old fixtures only. Active combat uses BasicSkill and no charge state.
Config.BasicSkill = {
	ManaCost = 20, Cooldown = 3, DamageMultiplier = 6, Radius = 9,
	SwingImmediate = 0.5, PvPCapPct = 0.35, HaloHealPct = 0.10, HaloHealCapPct = 0.30,
}
-- BB9 fills Order / Defs (skill names per class). ZEnabled = the A23-15 Z skill flag: the SkillZ key (Config.Keybinds)
-- exists only while it is true.
Config.Skills = { ZEnabled = false }
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
		Id = "Halo", Name = "빛의 기사단", Short = "기사단", Emblem = "빛",
		TeamName = "빛의 기사단", TeamColor = BrickColor.new("New Yeller"),
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
			"경험치 +30% (레벨이 빨리 올라요)",
			"체력 +20%, 계속 체력 회복",
			"스킬을 쓰면 주변 동료 치유",
			"주머니 골드 절반 자동 저금",
			"원한 자루 도둑을 잡아 골드를 되찾아 줘요",
		},
		Pitch = "지키고, 치유하고, 되찾아 줘라!",
	},
	Horns = {
		Id = "Horns", Name = "뿔 군단", Short = "뿔 군단", Emblem = "뿔",
		TeamName = "뿔 군단", TeamColor = BrickColor.new("Really red"),
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
			"골드 +25% (빨리 부자가 돼요)",
			"공격력 +15%, 때리면 체력 흡수",
			"약탈한 골드를 지켜내면 내 것으로",
			"기사단을 털어 원한 자루를 지켜라",
			"현상수배 별 5개면 괴수로 변신!",
		},
		Pitch = "털고, 버티고, 괴수가 되어라!",
	},
	-- addendum A6: third playable faction "장인 길드". No combat/economy perks, PvP-immune both ways, no plunder,
	-- sacks, stars, bounty, bully stacks, revenge or kaiju; excluded from war points, blessing, power sums and ratios
	-- (Size Justice S always 1.0); goose swings count 0; home/respawn = Crossroads (Config.HomeZoneId already does that);
	-- may enter neither HaloTown nor HornsTown. Crafting perks come in phase 2.
	-- addendum A9-1: Neutral identity colour is TEAL (grey stays reserved for 회색 전설 / 금 간 후광 and for "None").
	-- Nametag, UIKit.Theme and the CharacterVisuals gear mark read Color; the Team uses TeamColor (distinct from the others).
	Neutral = {
		Id = "Neutral", Name = "장인 길드", Short = "장인", Emblem = "장", -- CR-L44: "⚙" renders as a tofu box
		TeamName = "장인 길드", TeamColor = BrickColor.new(Color3.fromRGB(40, 200, 190)),
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
			"싸움 버프 없음 (경험치·골드·체력·공격 보너스 없음)",
			"PvP 없음: 공격하지도, 공격받지도 않아요",
			"약탈·현상수배·원한 자루 걱정 없음",
			"교차로 마을이 우리 집",
			"제작 특화 (곧 추가)",
		},
		Pitch = "줍지 말고, 다듬고, 만들어라!",
		Note = "싸움 버프 없음 · PvP 없음 · 제작 특화(곧 추가)", -- picker card note (A6); plain text
	},
	None = {
		Id = "None", Name = "무소속", Short = "무소속", Emblem = "?",
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
	Halo = { "견습 기사", "기사", "성기사", "성자", "대천사" },
	Horns = { "불량배", "약탈자", "군벌", "공포의 군주", "마왕" },
	None = "모험가",
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

-- "base power" of a player (no Size Justice, no kaiju); rebirthMult = 1 + RebirthBonus.
-- enhance = scroll +N of the equipped weapon (the WeaponEnhance attribute); nil counts as +0 (Config.EnhanceMult).
function Config.PowerOf(level, weaponTier, rebirthMult, enhance)
	return math.sqrt(Config.WeaponDamage(weaponTier, level, enhance) * Config.BaseHealth(level)) * (rebirthMult or 1)
end

-- BB4 "전투력": the one power number players see = level + equipped weapon incl. scroll +N. It leaves out class,
-- faction, rebirth, Size Justice, bully, buffs and pets: same level + same weapon = same number for everyone.
-- The bully rule and the A23-18 boldness ratios compare this number (JusticeService.GetCombatPower).
-- Anything meaning "strongest weapon" sorts by Config.Weapons[t].Damage, never by the tier index (tier 8 is the
-- jelly legendary, damage 76 < tier 4).
Config.Power = {
	DisplayScale = 10,
	Text = {
		Label = "전투력", LabelEn = "Power",
		Formula = "레벨과 무기(강화 포함)로 정해져요", FormulaEn = "Set by your level and weapon (enhance included)",
		-- PvPNote / PvPNoteEn: finished lines, filled from Config.PvP.PowerRatioMax / Min right after Config.PvP below
		Up = "전투력 +%s", UpEn = "Power +%s",
		Change = "전투력 %s → %s", ChangeEn = "Power %s → %s",
	},
}

function Config.CombatPower(level, tier, enhance)
	return math.floor(Config.PowerOf(level, tier, 1, enhance) * Config.Power.DisplayScale + 0.5)
end

-- the highest number anyone can reach (max level, the highest-damage weapon at the max scroll +N); cached
function Config.MaxCombatPower()
	if not Config.Power.MaxCache then
		local best = 0
		for t = 1, Config.MaxWeaponTier do
			best = math.max(best, Config.CombatPower(Config.Levels.MaxLevel, t, Config.Loot.MaxEnhance))
		end
		Config.Power.MaxCache = best
	end
	return Config.Power.MaxCache
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
	-- DropMult halves the drop rows AND the slime jackpot (A23-22 has no exception); the first king-slime scroll stays.
	Penalty = { NoAuto = true, XPMult = 0.5, DropMult = 0.5 },
}

-- BB4: the bully rules in plain words (character window, help, first-time tips, PvP warnings share these lines)
Config.Bully.Text = {
	Title = "깡패가 되는 경우", TitleEn = "When you become a bully",
	Lines = {
		string.format("내 전투력의 %d%%보다 약한 상대를 쓰러뜨릴 때", math.floor(Config.Bully.WeakPowerRatio * 100 + 0.5)),
		string.format("막 부활한 상대(%d초 안)를 쓰러뜨릴 때", Config.Bully.FreshSpawnSeconds),
		string.format("같은 상대를 %d분 안에 %d번 쓰러뜨릴 때", math.floor(Config.Bully.RepeatWindow / 60), Config.Bully.RepeatKOs),
	},
	LinesEn = {
		string.format("KO a player weaker than %d%% of your power", math.floor(Config.Bully.WeakPowerRatio * 100 + 0.5)),
		string.format("KO a player who respawned less than %d s ago", Config.Bully.FreshSpawnSeconds),
		string.format("KO the same player %d times within %d minutes", Config.Bully.RepeatKOs, math.floor(Config.Bully.RepeatWindow / 60)),
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
Config.Power.Text.PvPNote = string.format("무기 공격력 차이가 커도 PvP 피해는 최대 %s배, 최소 %s배예요",
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
-- WarService SKY_EXTRAS).
Config.Sky = {
	TweenTime = 3,
	Neutral = { ClockTime = 14.2, Brightness = 2.0, Ambient = Color3.fromRGB(110, 108, 106), OutdoorAmbient = Color3.fromRGB(128, 126, 124), FogColor = Color3.fromRGB(205, 215, 230), FogStart = 250, FogEnd = 1100, ExposureCompensation = -0.2, BloomIntensity = 0.2, Tint = Color3.fromRGB(255, 255, 255) },
	Dawn = { ClockTime = 7.2, Brightness = 2.1, Ambient = Color3.fromRGB(128, 112, 92), OutdoorAmbient = Color3.fromRGB(150, 130, 104), FogColor = Color3.fromRGB(255, 220, 150), FogStart = 120, FogEnd = 650, Tint = Color3.fromRGB(255, 240, 200) },
	Eclipse = { ClockTime = 0.5, Brightness = 1.4, Ambient = Color3.fromRGB(100, 62, 78), OutdoorAmbient = Color3.fromRGB(115, 76, 92), FogColor = Color3.fromRGB(90, 10, 20), FogStart = 120, FogEnd = 650, Tint = Color3.fromRGB(255, 200, 200) },
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
	-- Korean texts (string.format). Mode name: Halo "함께 구조", Horns "함께 밀렵" (구조/밀렵 flavour of GooseStart).
	Text = {
		NeedManual = "황금 거위 보상은 직접 %d번 이상 때린 사람만 받아요! (자동 전투 타격은 세지 않아요)", -- (MinManualHits)
		CoopStart = { -- NotifyAll when the event becomes co-op (at start, or when the first faction player appears)
			Halo = "황금 거위가 교차로 마을에 내려왔어요! 지금은 뿔 군단이 없어서 '함께 구조'예요. 기사단끼리 게이지를 채워요!",
			Horns = "황금 거위가 교차로 마을에 내려왔어요! 지금은 기사단이 없어서 '함께 밀렵'이에요. 뿔 군단끼리 게이지를 채워요!",
		},
		CoopFull = { -- NotifyAll once when the gauge is full (MinManualHits)
			Halo = "게이지 가득! 함께 구조 성공이에요. 끝나기 전에 직접 %d번 이상 때린 기사단은 보상을 받아요!",
			Horns = "게이지 가득! 함께 밀렵 성공이에요. 끝나기 전에 직접 %d번 이상 때린 뿔 군단은 보상을 받아요!",
		},
		CoopResult = { -- NotifyAll at the end, gauge filled
			Halo = "기사단이 힘을 모아 황금 거위를 구조했어요! 조각이 빛을 되찾았어요.",
			Horns = "뿔 군단이 힘을 모아 황금 거위를 밀렵했어요! 조각이 어둠에 물들었어요.",
		},
		CoopFail = "게이지를 다 채우지 못해서 황금 거위가 날아가 버렸어요!", -- NotifyAll at the end, gauge not filled
		RivalLeft = "상대 진영이 모두 떠나서 '함께' 규칙으로 정했어요. %s", -- (CoopResult / CoopFail) tug whose rival left
		RivalWait = { -- to a rival who tries to pull during co-op (once per event), keyed by the CO-OP side
			Halo = "이번 황금 거위는 기사단의 '함께 구조'예요. 다음 거위부터 줄다리기로 겨뤄요!",
			Horns = "이번 황금 거위는 뿔 군단의 '함께 밀렵'이에요. 다음 거위부터 줄다리기로 겨뤄요!",
		},
		CoopReward = { -- (gold, xp) personal toast for a co-op success
			Halo = "함께 구조 성공 보상! +%s골드 +%s 경험치",
			Horns = "함께 밀렵 성공 보상! +%s골드 +%s 경험치",
		},
		-- EventHUD labels while GameState GooseActive and GooseMode == "Coop" (side = GooseCoopSide)
		HudTitle = { Halo = "함께 구조! %s", Horns = "함께 밀렵! %s" }, -- (time left)
		HudProgress = "%d / %d", -- (side total = GooseRescue for Halo / GoosePoach for Horns, GooseCoopTarget)
		HudPeople = "%d명이 함께", -- (GooseCoopPeople)
		HudSub = { -- (my GooseCount) players of the co-op side, gauge not full yet
			Halo = "내 기여 %d · 기사단끼리 게이지를 채워요!",
			Horns = "내 기여 %d · 뿔 군단끼리 게이지를 채워요!",
		},
		HudFull = { -- (my GooseCount, MinManualHits) players of the co-op side, gauge full
			Halo = "내 기여 %d · 구조 성공! 직접 %d번 때리면 보상",
			Horns = "내 기여 %d · 밀렵 성공! 직접 %d번 때리면 보상",
		},
		HudOther = { -- the other tug faction during co-op (keyed by the CO-OP side)
			Halo = "이번 거위는 기사단의 함께 구조예요",
			Horns = "이번 거위는 뿔 군단의 함께 밀렵이에요",
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
-- World layout v3 (addendum A10, = tools/preview_map.lua): an RPG continent of three land pieces along +X (Crossroads,
-- Slime Meadow, the wild lands of Goblin Woods + Skeleton Ruins) split by rivers, plus two faction islands north/south of
-- Crossroads across the sea, joined by bridges. Ground is Terrain with its top at Y = 0 on land (zone floor parts are
-- invisible, non-colliding contract parts: A11); the sea/river surface is Config.Map.WaterTop. Size.Y is unused (0).
-- Zones are XZ rectangles; first match in ZoneOrder wins; everything else (incl. sea, bridges, the pass) is Outskirts.
-- A23-30: PumpkinPatch (Season = "Halloween") is its own land south of the meadow; with its season off ZoneAt skips it
-- (that ground reads as Outskirts) and nothing spawns there.
Config.ZoneOrder = { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "PumpkinPatch", "HauntedHollow", "GoblinWoods",
	"SkeletonRuins" }
Config.Zones = {
	Crossroads = { Id = "Crossroads", Name = "교차로 마을", Center = Vector3.new(0, 0, 0), Size = Vector3.new(160, 0, 160),
		MinLevel = 1, PvP = false, Town = true, Faction = nil,
		FloorColor = Color3.fromRGB(190, 176, 150), FloorMaterial = Enum.Material.Cobblestone, Spawn = Vector3.new(0, 0, -25) },
	HaloTown = { Id = "HaloTown", Name = "빛의 성채", Center = Vector3.new(0, 0, -400), Size = Vector3.new(160, 0, 160),
		MinLevel = 1, PvP = false, Town = true, Faction = "Halo",
		FloorColor = Color3.fromRGB(228, 218, 190), FloorMaterial = Enum.Material.Marble, Spawn = Vector3.new(0, 0, -410) },
	HornsTown = { Id = "HornsTown", Name = "뿔 소굴", Center = Vector3.new(0, 0, 400), Size = Vector3.new(160, 0, 160),
		MinLevel = 1, PvP = false, Town = true, Faction = "Horns",
		FloorColor = Color3.fromRGB(70, 40, 45), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(0, 0, 410) },
	SlimeMeadow = { Id = "SlimeMeadow", Name = "말랑 초원", Center = Vector3.new(330, 0, 0), Size = Vector3.new(260, 0, 260),
		MinLevel = 1, PvP = false, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(115, 195, 95), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(220, 0, 0) },
	-- A23-30 (user 2026-10-06 "슬라임은 슬라임만, 고블린은 고블린, 호박은 호박!"): every Halloween kind lives here, a
	-- Lv1-walkable field joined to the meadow's south shore (land x 280..440, z 175..295; MapBuilder fills it)
	PumpkinPatch = { Id = "PumpkinPatch", Name = "호박밭", Center = Vector3.new(360, 0, 235), Size = Vector3.new(160, 0, 120),
		MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = "Halloween",
		-- Mud = the pumpkin-soil texture slot (Config.UIArt Tex_PumpkinSoil; Ground is the ruins soil)
		FloorColor = Color3.fromRGB(150, 118, 72), FloorMaterial = Enum.Material.Mud, Spawn = Vector3.new(360, 0, 190) },
	-- A23-45 (user 2026-10-06 "유령은 유령끼리"): the ghost family's own seasonal field west of the PumpkinPatch (land
	-- x 160..280, z 185..295 joined to it; MapBuilder fills it), entered only through the pumpkin field's west gate.
	-- Goblin-woods strength (Lv 8-14 recommended, no level gate), no PvP. Floor: Ground until its own tile comes.
	HauntedHollow = { Id = "HauntedHollow", Name = "유령 숲", Center = Vector3.new(220, 0, 240), Size = Vector3.new(104, 0, 90),
		MinLevel = 1, PvP = false, Town = false, Faction = nil, Season = "Halloween",
		FloorColor = Color3.fromRGB(118, 106, 150), FloorMaterial = Enum.Material.Ground, Spawn = Vector3.new(262, 0, 240) },
	GoblinWoods = { Id = "GoblinWoods", Name = "고블린 숲", Center = Vector3.new(720, 0, 0), Size = Vector3.new(300, 0, 300),
		MinLevel = 10, PvP = true, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(60, 125, 55), FloorMaterial = Enum.Material.Grass, Spawn = Vector3.new(590, 0, 0) },
	SkeletonRuins = { Id = "SkeletonRuins", Name = "해골 유적", Center = Vector3.new(1120, 0, 0), Size = Vector3.new(320, 0, 320),
		MinLevel = 25, PvP = true, Town = false, Faction = nil,
		FloorColor = Color3.fromRGB(135, 125, 108), FloorMaterial = Enum.Material.Slate, Spawn = Vector3.new(980, 0, 0) },
	Outskirts = { Id = "Outskirts", Name = "바깥 들판", Center = Vector3.new(595, 0, 0), Size = Vector3.new(1450, 0, 1040),
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
	-- invisible walls only: NEVER a ground plate covering Bounds (it would cover the sea and rivers: A10-V3-1)
	Bounds = { MinX = -130, MaxX = 1320, MinZ = -520, MaxZ = 520 },
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
	Gates = { -- decorative arches with a level sign, centered on zone borders
		{ Zone = "SlimeMeadow", Position = Vector3.new(200, 0, 0) },
		{ Zone = "GoblinWoods", Position = Vector3.new(570, 0, 0) },
		{ Zone = "SkeletonRuins", Position = Vector3.new(960, 0, 0) },
		{ Zone = "HaloTown", Position = Vector3.new(0, 0, -320) },
		{ Zone = "HornsTown", Position = Vector3.new(0, 0, 320) },
	},
	MaxParts = 1600, -- total map parts budget (decor included); ART_DIRECTION 9 [SPEC] raised it from 450
	-- addendum A10 (values = tools/preview_map.lua v3/v4)
	WaterTop = -1.2, -- Terrain water surface Y everywhere outside the lands (sea + rivers)
	PassX = 915, -- Terrain rock mountain pass between GoblinWoods and SkeletonRuins (road corridor |z| < 20)
	-- land pieces (Terrain top at Y = 0); rivers between the continent pieces, sea around the islands
	Lands = {
		{ Name = "LandCrossroads", MinX = -110, MaxX = 115, MinZ = -175, MaxZ = 175 },
		{ Name = "LandMeadow", MinX = 155, MaxX = 490, MinZ = -175, MaxZ = 175 },
		{ Name = "LandWild", MinX = 530, MaxX = 1300, MinZ = -175, MaxZ = 175 },
		{ Name = "IslandHalo", MinX = -110, MaxX = 110, MinZ = -500, MaxZ = -300 },
		{ Name = "IslandHorns", MinX = -110, MaxX = 110, MinZ = 300, MaxZ = 500 },
		{ Name = "LandPumpkinPatch", MinX = 280, MaxX = 440, MinZ = 175, MaxZ = 295, Season = "Halloween" }, -- A23-30, joined to LandMeadow; WorldMap draws it only in season
		{ Name = "LandHauntedHollow", MinX = 160, MaxX = 280, MinZ = 185, MaxZ = 295, Season = "Halloween" }, -- A23-45, joined to the patch's west edge
	},
	-- bridge decks (top at Y = 0); the built models are workspace.Map.Decor["Bridge_" .. Name]
	Bridges = {
		{ Name = "Meadow", From = Vector3.new(113, 0, 0), To = Vector3.new(157, 0, 0), Width = 18 },
		{ Name = "Goblin", From = Vector3.new(488, 0, 0), To = Vector3.new(532, 0, 0), Width = 18 },
		{ Name = "Halo", From = Vector3.new(0, 0, -173), To = Vector3.new(0, 0, -302), Width = 18 },
		{ Name = "Horns", From = Vector3.new(0, 0, 173), To = Vector3.new(0, 0, 302), Width = 18 },
	},
	-- road strips on land (drawing data for the World Map, A12; built by tools/preview_map.lua as Decor.Roads)
	Roads = {
		{ Name = "RoadCross", MinX = 13, MaxX = 115, MinZ = -8, MaxZ = 8 },
		{ Name = "RoadMeadow", MinX = 155, MaxX = 490, MinZ = -8, MaxZ = 8 },
		{ Name = "RoadWild", MinX = 530, MaxX = 1300, MinZ = -8, MaxZ = 8 },
		{ Name = "RoadWest", MinX = -43, MaxX = -13, MinZ = -8, MaxZ = 8 },
		{ Name = "RoadNorth", MinX = -8, MaxX = 8, MinZ = -175, MaxZ = -10 },
		{ Name = "RoadNorthIsland", MinX = -8, MaxX = 8, MinZ = -398, MaxZ = -300 },
		{ Name = "RoadSouth", MinX = -8, MaxX = 8, MinZ = 10, MaxZ = 175 },
		{ Name = "RoadSouthIsland", MinX = -8, MaxX = 8, MinZ = 300, MaxZ = 398 },
	},
	SkyCrownPosition = Vector3.new(0, 350, 0), -- A11 "Crown of Balance" landmark floating above Crossroads (radius ~80)
}

Config.Travel = {
	ChannelSeconds = 3,
	PadDebounce = 2,
	ZoneTick = 0.2, -- ZoneService polling interval (CR-H2: 0.5 -> 0.2 so a short teleport hop is sampled)
	Destinations = {
		{ Id = "Home", Name = "우리 진영 마을" }, -- resolves to Config.HomeZoneId(faction)
		{ Id = "Crossroads", Name = "교차로 마을" },
		{ Id = "SlimeMeadow", Name = "말랑 초원" },
		{ Id = "GoblinWoods", Name = "고블린 숲" },
		{ Id = "SkeletonRuins", Name = "해골 유적" },
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

-- addendum A7-1: on each (re)spawn of a non-personal monster, prefer a point 18-28 studs from the most "starved"
-- player in def.Zone (fewest monsters within 30 studs) when that player has fewer than StarvedThreshold nearby.
Config.SpawnSpread = { Enabled = true, StarvedThreshold = 2, MinDist = 18, MaxDist = 28, Tries = 6 }

-- seasonal kinds sit right after the base kind of their zone (drop table / UI order); they spawn only while their
-- season is on (Config.MonsterActive / Config.EffectiveMonsterCounts)
Config.MonsterTypeOrder = { "Slime", "PumpkinSlime", "BigSlime", "PumpkinKing", "Goblin", "BatGoblin", "GoblinBrute",
	"GhostMinion", "LittleGhost", "GhostKing", "Skeleton", "SkeletonKnight" }
-- Name = full name (nametag, lore); Short = short name for quest / HUD lines (optional: use `def.Short or def.Name`)
-- Season = Config[Season].Enabled gates the kind; Takes = { [baseKind] = n } slots of a base kind it replaces while on;
-- QuestAs = the kind quests count it as (Config.QuestKind); Float = studs the client hovers it above the floor (no
-- legs: slow bob, no waddle); Boss = event monster (never golden, never respawns, ContributorWindow override).
Config.MonsterTypes = {
	Slime = { Name = "조각먹은 슬라임", Short = "슬라임", Zone = "SlimeMeadow", Count = 12, HP = 10, Damage = 2, XP = 5, Gold = 3, Speed = 10, Shape = "Slime", Scale = 1.0, Color = Color3.fromRGB(95, 205, 95) },
	BigSlime = { Name = "왕 슬라임", Short = "왕 슬라임", Zone = "SlimeMeadow", Count = 4, HP = 40, Damage = 4, XP = 18, Gold = 10, Speed = 9, Shape = "Slime", Scale = 1.8, Color = Color3.fromRGB(70, 160, 235) },
	Goblin = { Name = "조각 도둑 고블린", Short = "고블린", Zone = "GoblinWoods", Count = 10, HP = 90, Damage = 6, XP = 28, Gold = 16, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(110, 170, 70) },
	GoblinBrute = { Name = "고블린 우두머리", Short = "고블린 우두머리", Zone = "GoblinWoods", Count = 4, HP = 260, Damage = 12, XP = 70, Gold = 40, Speed = 10, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(80, 120, 50) },
	Skeleton = { Name = "옛 왕국 해골 병사", Short = "해골 병사", Zone = "SkeletonRuins", Count = 8, HP = 450, Damage = 14, XP = 65, Gold = 65, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(235, 235, 220) },
	SkeletonKnight = { Name = "왕관을 지키던 해골 기사", Short = "해골 기사", Zone = "SkeletonRuins", Count = 4, HP = 1300, Damage = 24, XP = 170, Gold = 170, Speed = 11, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(120, 120, 140) },
	-- Halloween (Config.Halloween; provisional numbers). A23-45 (user 2026-10-06 "고블린은 고블린끼리, 호박은 호박, 유령은
	-- 유령끼리"): one family per field. PumpkinPatch = pumpkin slimes + the pumpkin king; the bat goblins take 3 goblin
	-- slots in the GoblinWoods (the first plan, woods numbers, counted as goblins); the HauntedHollow = the ghost family
	-- (minions in packs of 3-4, little ghosts, the ghost king), goblin-woods strength.
	PumpkinSlime = { Name = "호박 슬라임", Short = "호박 슬라임", Zone = "PumpkinPatch", Count = 10, QuestAs = "Slime",
		Season = "Halloween", HP = 14, Damage = 2, XP = 6, Gold = 4, Speed = 10, Shape = "Slime", Scale = 1.1, Color = Color3.fromRGB(255, 150, 40) },
	BatGoblin = { Name = "박쥐 고블린", Short = "박쥐 고블린", Zone = "GoblinWoods", Count = 3, Takes = { Goblin = 3 }, QuestAs = "Goblin",
		Season = "Halloween", HP = 95, Damage = 6, XP = 30, Gold = 17, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(120, 80, 150) },
	-- Pack = spawned next to a living one of its kind whose pack has fewer than Max (within Radius), else a new pack.
	-- ModelFrom = the custom model used while its own 3D model is not imported yet (scaled by Scale).
	GhostMinion = { Name = "똘마니 유령", Short = "똘마니 유령", Zone = "HauntedHollow", Count = 8, Season = "Halloween",
		Pack = { Max = 4, Radius = 7 }, ModelFrom = "LittleGhost",
		HP = 40, Damage = 3, XP = 13, Gold = 7, Speed = 12, Shape = "Humanoid", Scale = 0.7, Color = Color3.fromRGB(190, 220, 255), Float = 1.2 },
	LittleGhost = { Name = "꼬마 유령", Short = "꼬마 유령", Zone = "HauntedHollow", Count = 4, Season = "Halloween", HP = 70, Damage = 5,
		XP = 24, Gold = 14, Speed = 11, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(220, 215, 255), Float = 1.5 },
	-- miniboss (HalloweenService schedule, never in the regular pool). HP 9000 = about 4 minutes for one Lv 8-12
	-- player with a tier 2-3 weapon, about 70 s for three. Per player DPS (Config.WeaponDamage x class Damage; swing =
	-- 0.5 x D x 1.1 crit avg per SwingInterval; skill = 6 x D every 3 s while MP lasts: 100 MP + 4/s regen, 20 per
	-- cast, mage swings 2 MP), averaged over Lv 8/10/12 x tier 2/3 x the three classes: 50.8 DPS over 240 s (tier 2
	-- ~29, tier 3 ~73), 58.2 DPS over an 80 s fight (the full MP pool counts more). With 75% uptime (walking,
	-- dodging, aim cone): 1 player 50.8 x 0.75 x 240 = 9141 -> 9000 HP; 3 players 9000 / (3 x 58.2 x 0.75) = 69 s.
	PumpkinKing = { Name = "호박 대왕", Short = "호박 대왕", Zone = "PumpkinPatch", Count = 0, Boss = true, Season = "Halloween",
		ContributorWindow = 120, -- a 1-2 min fight: everyone who hit it in the last 2 minutes shares the kill
		-- A23-27: paid only with >= RewardMinHits own hits (auto hits count) AND >= RewardMinDamageFrac of MaxHP; below
		-- Lv XPCapBelowLevel the king's XP is capped to one level (Config.XPToNext of the current level)
		RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8,
		HP = 9000, Damage = 8, XP = 300, Gold = 150, Speed = 7, Shape = "Slime", Scale = 2.5, Color = Color3.fromRGB(255, 130, 30) },
	-- A23-45: the ghost family's miniboss, the pumpkin king's rules and numbers (A23-27 safety / reward gate / XP cap,
	-- 5 min stay, nameless lines), 10 minutes after it in the schedule (Config.Halloween.Bosses), HauntedHollow
	GhostKing = { Name = "유령 왕", Short = "유령 왕", Zone = "HauntedHollow", Count = 0, Boss = true, Season = "Halloween",
		ContributorWindow = 120, RewardMinHits = 3, RewardMinDamageFrac = 0.005, XPCapBelowLevel = 8, ModelFrom = "LittleGhost",
		HP = 9000, Damage = 8, XP = 300, Gold = 150, Speed = 7, Shape = "Humanoid", Scale = 2.4, Color = Color3.fromRGB(200, 190, 255), Float = 2.2 },
}

-- the kind quests / tutorial / story objectives count a kill as (a pumpkin slime counts as a slime)
function Config.QuestKind(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	if type(def) == "table" and type(def.QuestAs) == "string" and Config.MonsterTypes[def.QuestAs] ~= nil then
		return def.QuestAs
	end
	return kind
end

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
	-- A23-30: the king appears in the PumpkinPatch (x 280..440, z 175..295; entrance from the meadow at the north
	-- edge), in its far half (one spot picked at random each time)
	SpawnSpots = { Vector3.new(330, 0, 255), Vector3.new(390, 0, 255) },
	-- A23-45: the minibosses HalloweenService runs. Each entry may override FirstDelay / SpawnSpots (and Interval /
	-- Lifetime); Interval, Lifetime, RetryDelay, SpawnRadius and the A23-27 safety are shared. The ghost king comes 10
	-- minutes after the pumpkin king (FirstDelay 360 + 600, both every Interval), in the HauntedHollow.
	-- Key = the GameState prefix (<Key>NextAt / <Key>Active / <Key>EndsAt) and the Config.Announce event prefix.
	Bosses = {
		{ Kind = "PumpkinKing", Key = "PumpkinKing" },
		{ Kind = "GhostKing", Key = "GhostKing", FirstDelay = 960,
			SpawnSpots = { Vector3.new(205, 0, 255), Vector3.new(235, 0, 230) } },
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
		HudNext = "호박 대왕까지 %s", HudNextEn = "Pumpkin King in %s",
		HudActive = "호박 대왕 출현! 남은 시간 %s", HudActiveEn = "Pumpkin King is here! %s left",
		GhostHudNext = "유령 왕까지 %s", GhostHudNextEn = "Ghost King in %s",
		GhostHudActive = "유령 왕 출현! 남은 시간 %s", GhostHudActiveEn = "Ghost King is here! %s left",
		-- the one road sign on the meadow's south shore (MapBuilder; hidden when the season is off). It does not name
		-- the season, so it needs no "comes back every year" line (P10)
		PatchSign = "↓ 호박밭 · 호박 몬스터 사냥터", PatchSignEn = "↓ Pumpkin Patch · pumpkin monsters",
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
Config.Tutorial = {
	Steps = { Kill = 0, Guide = 1, Quest = 2, Done = 99 },
	Monster = "Slime",
	MonsterHP = 10,
	Golden = true,
	SpawnDistance = 8, -- studs in front of the player's spawn
	Lifetime = 120, -- personal monster despawns after this many seconds (then the tutorial advances to step 1)
	GuideZone = "SlimeMeadow",
	GuideText = "말랑 초원 · 빛나는 발판을 밟아요", -- plain
	QuestId = "tutorial",
	QuestKills = 5,
	QuestText = "보급로 되찾기 · 슬라임 %d마리", -- string.format(QuestText, QuestKills)
	QuestRewardGold = 150, -- A23-3: enough for the wood weapon (150); buying stays optional
	QuestRewardXP = 0,
	-- F10-4 safety net (2026-10-06): a 5/5 first mission left unclaimed this long (counted from when this server
	-- first sees it, also right after a rejoin) is paid automatically with Text.AutoClaimed. [받기] still comes first.
	AutoClaimSeconds = 60,
	WelcomeRate = 0.5,
	Welcome = { -- existing approved faction/class portrait; no world NPC is spawned by this dialogue
		Halo = {
			Name = "빛의 안내자",
			Lines = {
				"빛의 기사단에 와 줘서 고마워요. 거창한 맹세는 나중에 해도 돼요. 지금은 당신 도움이 필요해요.",
				"균형의 왕관이 부서진 뒤, 조각에 이끌린 슬라임이 말랑 초원의 보급로를 막았어요.",
				"슬라임 5마리를 물리쳐 길을 되찾아 주세요. 전쟁에서 동료를 지키는 영웅도, 누군가의 길을 열어 주는 일부터 시작하니까요.",
			},
		},
		Horns = {
			Name = "뿔 군단 안내자",
			Lines = {
				"잘 왔어, 신입! 우리 편이 되어 줘서 고맙다. 세상을 차지하기 전에… 군단의 점심부터 구하자.",
				"부서진 왕관 조각에 이끌린 슬라임이 말랑 초원의 보급로를 차지했어. 식량도 장비도 못 지나간다니까!",
				"슬라임 5마리를 물리치고 길을 되찾아 줘. 전쟁을 이끄는 건 힘만 센 녀석이 아니라, 동료를 움직이게 하는 녀석이야.",
			},
		},
		Neutral = {
			Name = "길드 안내자",
			Lines = {
				"장인 길드에 와 줘서 고마워요. 전쟁은 칼로만 이기는 게 아니죠. 그 칼을 고칠 사람도 있어야 하니까요.",
				"왕관 조각에 이끌린 슬라임 때문에 말랑 초원의 보급로가 막혔어요.",
				"슬라임 5마리를 물리쳐 길을 되찾아 주세요. 동료들의 장비 보급을 돕는 첫걸음이에요.",
			},
		},
	},
	Text = {
		FirstFight = "직업을 고른 뒤 안내자에게 첫 임무를 받아요.",
		Welcome = "첫 임무 · 메뉴에서 안내자 만나기",
		Travel = "보급로 되찾기 · 메뉴 > 이동 > 말랑 초원",
		QuestStart = "첫 임무: %s! (보상 %s골드)",
		QuestReady = "보급로 임무 완료! [받기]를 눌러요.",
		Claimed = "보급로를 지켜 줘서 고마워요! +%s골드 · 교차로 대장간에서 장비를 살펴봐요.",
		ClaimedEn = "Thanks for guarding the supply road! +%s gold · Check the gear at the Crossroads smithy.",
		AutoClaimed = "첫 임무 보상 +%s골드를 금고에 넣었어요! 교차로 대장간에서 장비를 살펴봐요.",
		AutoClaimedEn = "Your first mission reward, +%s gold, is in your bank! Check the gear at the Crossroads smithy.",
		VisitBlacksmith = "무기 살펴보기 · 교차로 마을 대장간",
		-- A23-3: next goal after the blacksmith visit (computed from existing state only; no new reward)
		NextIronLevel = "다음 목표 · Lv%d 되면 철 무기 (지금 Lv%d)",
		NextIronGold = "다음 목표 · 철 무기 %s골드 (보유 %s)",
		NextZone = "다음 목표 · Lv%d 되면 %s (지금 Lv%d)",
		GuideDone = "안내는 여기까지! 이제 사냥하며 강해져요.",
		DailiesOpened = "일일 임무가 열렸어요! 첫 임무와 함께 해 봐요.",
	},
}

----------------------------------------------------------------- story quests "부서진 왕관 이야기" (user OK 2026-10-06)
-- Design: docs/design/quest_chain_2026-10-06.md (decisions 1-8 = recommended). Main = one chain after the first
-- mission (TutorialStep 99); Subs are accepted automatically and listed under the main row (S0 right after the
-- class pick). Step Obj types (StoryQuestService): Kill{Kind,Zone,Golden,Near,Radius,Count} BasicKill SafeKill{MinHP}
-- AutoKill SkillHit{Min,Count} WarPoints{Count} EarnGold{Source,Count} Enter{Zone|"OwnTown"|"AnyTown"} Level{Level}
-- State{Key} Goose WarChest Talk Choice{Good,Evil,Neutral} Trials{List}. Rewards: Gold / XP = minutes of
-- Config.HuntValue (1 = one minute of hunting), Claim = true -> the player presses [받기] (chapter ends).
Config.StoryQuests = {
	MaxSubs = 2, -- sub rows sent with the quest list (after the main row)
	Landmarks = { SlimePond = Vector3.new(280, 0, -45), Fountain = Vector3.new(0, 0, 0) },
	Speakers = { Shard = "왕관 조각", Fountain = "분수의 조각", Smith = "대장장이", Guild = "길드 안내자" },
	Badge = { Main = "메인", Sub = "선택" },
	Main = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7" },
	-- user 2026-10-06: basic weapons are simply bought at the blacksmith (no "buy the iron weapon" quest); rare gear
	-- comes from quests, the crafter and monster drops
	Subs = { "S0", "S1", "S2", "S3", "S4", "N1", "N2" },
	Text = {
		Claim = "%s 완료! [받기]를 눌러요.",
		Done = "%s 완료!",
		Reward = "%s 완료! +%s골드",
		RewardXP = "%s 완료! +%s골드 · 경험치 +%s",
		RewardOnlyXP = "%s 완료! 경험치 +%s",
		Unlocked = "자동 전투가 열렸어요! {Auto}키(폰은 자동 버튼)로 켜고 끌 수 있어요.", -- {Auto}: BB1 key token (server fills)
		Good = "조각이 빛 쪽으로 기울었어요 (명예 +%d)",
		Evil = "조각이 어둠 쪽으로 기울었어요 (악명 +%d)",
		Recorded = "선택을 기록했어요.",
		-- shown under the two choice buttons on the last page (what a pick does, before picking)
		ChoiceHint = "고르면 → 왼쪽: 명예 +%d (천사 쪽) · 오른쪽: 악명 +%d (악마 쪽)",
		ChoiceHintNeutral = "장인 길드는 선악 점수 없이 고른 것만 기록돼요.",
		OddHalo = "안내자: 음… 그것도 당신 선택이에요.",
		OddHorns = "안내자: 착하게 갔네? 그것도 네 맘이야!",
		GooseFirstHalo = "황금 거위 구조에 처음 함께했어요! (명예 +%d)",
		GooseFirstHorns = "황금 거위 밀렵에 처음 함께했어요! (악명 +%d)",
		Next = "다음",
		Ok = "알겠어요",
		Later = "나중에",
		Title = "%s · %s",
	},
	Defs = {
		-- S0 (A23-2): the shard that fell in front of me in the opening was swallowed by a king slime
		S0 = {
			Kind = "Sub", Title = "내 싸움을 배우는 왕관 조각", Speaker = "Shard", Requires = { ClassChosen = true },
			Steps = {
				{ Text = "왕 슬라임 잡고 조각 찾기 %d/%d", Guide = "SlimeMeadow",
					Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 1 } },
				{ Text = "조각의 시험 %d/3", Guide = "SlimeMeadow", Start = "조각: 네가 싸우는 법을 보여 줘!",
					Obj = { Type = "Trials", List = {
						{ Key = "a", Type = "BasicKill", Kind = "Slime", Count = 3 },
						{ Key = "b", Type = "SkillHit", Min = 2, Count = 1 },
						{ Key = "c", Type = "SafeKill", Kind = "BigSlime", MinHP = 0.5, Count = 1 },
					} } },
				{ Text = "조각을 어떻게 할까요?", Panel = true,
					Lines = { All = { "다 봤어! 이제 나는 너처럼 싸울 수 있어.", "나를 어떻게 할래?" } },
					Obj = { Type = "Choice", Good = { Label = "정화해요", Points = 2, Pick = "Purify" },
						Evil = { Label = "삼켜요", Points = 2, Pick = "Devour" },
						Neutral = { A = "정화해요", B = "삼켜요" } } },
			},
			Unlock = "AutoCombat",
		},
		M1_1 = {
			Kind = "Main", Chapter = 1, Title = "반짝이는 젤리", Speaker = "Smith",
			Steps = { { Text = "대장장이에게 젤리 보이기", Guide = "Blacksmith", Obj = { Type = "State", Key = "BlacksmithVisited" } } },
			Finish = "대장장이: 왕관 조각 가루네! 제일 많이 먹은 건 왕 슬라임이지.",
		},
		M1_2 = {
			Kind = "Main", Chapter = 1, Title = "가루를 삼킨 왕",
			Start = "가루를 잔뜩 삼킨 왕 슬라임이 초원을 돌아다녀요.",
			Steps = { { Text = "왕 슬라임 %d/%d", Guide = "SlimeMeadow", Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2 } } },
			Finish = "가루가 와르르 쏟아졌어요!", Reward = { Gold = 1 },
		},
		M1_3 = {
			Kind = "Main", Chapter = 1, Title = "한 번에 펑!",
			Start = "가루 먹은 슬라임은 떼로 다녀요. 스킬은 MP를 써요!",
			Steps = { { Text = "스킬로 몬스터 맞히기 %d/%d", Guide = "SlimeMeadow", Obj = { Type = "SkillHit", Min = 1, Count = 3 } } },
			Reward = { Gold = 1 },
		},
		M1_4 = {
			Kind = "Main", Chapter = 1, Title = "우리 편에 보고", Claim = true,
			Steps = {
				{ Text = "우리 마을로 가요", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "OwnTown" } },
				{ Text = "안내자에게 보고하기", Panel = true, Obj = { Type = "Talk" }, Lines = {
					Halo = { "영웅의 길 석상 봤어요? 조각을 지킨 기사들이에요." },
					Horns = { "용암 틈 보여? 우리 뿔 힘은 여기서 끓어!" },
					Neutral = { "좋은 가루네요. 길드는 줍지 않고 다듬어요." },
				} },
			},
			Reward = { Gold = 2, XP = 2 },
		},
		M2_1 = {
			Kind = "Main", Chapter = 2, Title = "하늘의 왕관",
			Start = "하늘 왕관은 조각을 더 모은 편 색으로 빛나요. 1마리 = 우리 편 1점!",
			Steps = { { Text = "왕관 점수 %d/%d", Obj = { Type = "WarPoints", Count = 15 },
				Neutral = { Text = "보급 골드 %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 45 } } } },
			Reward = { Gold = 1 },
		},
		M2_2 = {
			Kind = "Main", Chapter = 2, Title = "연못의 반짝임",
			Start = "가루가 연못에 녹았대요. 연못가 슬라임이 수상해요.",
			Steps = { { Text = "연못가 슬라임 %d/%d", Guide = "SlimePond",
				Obj = { Type = "Kill", Kind = "Slime", Near = "SlimePond", Radius = 40, Count = 4 } } },
			Reward = { Gold = 1 },
		},
		M2_3 = {
			Kind = "Main", Chapter = 2, Title = "균형의 분수", Speaker = "Fountain",
			Start = "교차로 마을 분수에 왕관 조각이 박혀 있대요. 분수 앞으로 가 봐요! (퀘스트 줄을 누르면 길 안내)",
			Steps = {
				-- user 2026-10-05 ("균형의 분수가 뭐야? 튜토리얼이 없어서 엥?"): walk up to the fountain, then talk
				{ Text = "교차로 분수 앞으로 가요 (눌러서 길 안내)", Guide = "Fountain",
					Obj = { Type = "Near", Spot = "Fountain", Radius = 22, Zone = "Crossroads" } },
				{ Text = "분수의 조각과 이야기", Panel = true,
					Lines = { All = {
						"나는 분수에 박힌 왕관 조각이야. 하늘의 왕관이 깨질 때 여기로 떨어졌어.",
						"네가 연못 슬라임에게서 모은 반짝이 가루, 그게 사실 왕관 가루야.",
						"가루를 분수에 돌려주면 세상이 빛 쪽으로, 네가 가지면 어둠 쪽으로 기울어. 어떻게 할래?",
					} },
					Obj = { Type = "Choice", Good = { Label = "분수에 돌려줘요", Points = 2 }, Evil = { Label = "내가 가질래요", Points = 2 },
						Neutral = { A = "다듬어서 돌려줘요", B = "길드에 맡겨요" } } },
			},
			Reward = { Gold = 1 },
		},
		M2_4 = {
			Kind = "Main", Chapter = 2, Title = "보급로 기금",
			Start = "보급로를 고칠 골드를 모아요. 마을에 들어가면 금고에 쏙!",
			Steps = {
				{ Text = "사냥 골드 %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 60 } },
				{ Text = "마을 금고에 넣기", Guide = "OwnTown", Obj = { Type = "Enter", Zone = "AnyTown" } },
			},
			Reward = { Gold = 1 },
		},
		M2_5 = {
			Kind = "Main", Chapter = 2, Title = "가루 먹은 슬라임 떼",
			Start = "가루 냄새에 슬라임이 떼로 몰려와요! 모아서 한 방에!",
			Steps = { { Text = "스킬 한 번에 3마리 %d/%d", Guide = "SlimeMeadow", Obj = { Type = "SkillHit", Min = 3, Count = 2 } } },
			Reward = { Gold = 1 },
		},
		M2_6 = {
			Kind = "Main", Chapter = 2, Title = "언덕의 작은 발자국",
			Start = "왕 슬라임 가루가 사라졌어요. 작은 발자국이 숲 쪽으로…",
			Steps = { { Text = "왕 슬라임 %d/%d", Guide = "SlimeMeadow", Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2 } } },
			Finish = "고블린이 가루를 훔쳐 갔대요!", Reward = { Gold = 1 },
		},
		M2_7 = {
			Kind = "Main", Chapter = 2, Title = "숲 너머의 부름", Claim = true,
			Steps = {
				{ Text = "Lv10 · 고블린 숲 (지금 Lv%d)", Obj = { Type = "Level", Level = 10 } },
				{ Text = "안내자의 경고 듣기", Panel = true, Obj = { Type = "Talk" }, Lines = {
					All = { "숲 너머에서 왕관 조각이 부른다. 도둑을 조심해!",
						"숲에선 들고 있는 골드를 뺏길 수 있어요. 마을 금고에 먼저!",
						"Lv15·1시간 전까지는 새싹 보호예요." },
					Neutral = { "숲 너머에서 왕관 조각이 부른다. 도둑을 조심해!", "장인 길드는 숲에서도 공격받지 않아요." },
				} },
				{ Text = "고블린 숲으로 가요", Guide = "GoblinWoods", Obj = { Type = "Enter", Zone = "GoblinWoods" } },
			},
			Reward = { Gold = 2, XP = 2 },
		},
		S1 = {
			Kind = "Sub", Title = "조각을 품은 황금 거위", Factions = { Halo = true, Horns = true },
			Requires = { Tutorial = true }, Show = "GooseSoon",
			Steps = { { Text = "황금 거위 직접 3번 때리기", Guide = "Goose", Obj = { Type = "Goose", Count = 1 } } },
			FirstPoints = 1, -- 구조(빛) 명예 / 밀렵(뿔) 악명, 첫 1회만; 거위 보상은 GooseService가 그대로 준다
		},
		S2 = {
			Kind = "Sub", Title = "왕관 쟁탈전 첫 상자", Factions = { Halo = true, Horns = true }, Requires = { Done = { "M2_1" } },
			Steps = { { Text = "한 판에 내 점수 30 · 상자 받기", Obj = { Type = "WarChest", Count = 1 } } },
		},
		S3 = {
			Kind = "Sub", Title = "금빛 젤리", Requires = { Done = { "M1_4" } },
			Steps = {
				{ Text = "황금 몬스터 %d/%d", Obj = { Type = "Kill", Golden = true, Count = 1 } },
				{ Text = "금빛 가루를 어떻게 할까요?", Panel = true,
					Lines = { All = { "가루를 아주 많이 먹으면 금빛이 돼요!", "이 금빛 가루, 어떻게 할래요?" } },
					Obj = { Type = "Choice", Good = { Label = "분수에 돌려줘요", Points = 1 }, Evil = { Label = "내 주머니에!", Points = 1 },
						Neutral = { A = "분수에 돌려줘요", B = "길드에 맡겨요" } } },
			},
		},
		S4 = {
			Kind = "Sub", Title = "조각이 대신 싸워요", Speaker = "Shard", Requires = { Done = { "S0" } },
			Start = "조각: 이제 내가 대신 싸울게. 사람은 네 손으로!",
			Steps = {
				{ Text = "자동 전투 켜기 ({Auto})", Obj = { Type = "State", Key = "AutoOn" } }, -- {Auto}: HUD fills it (phone: button name)
				{ Text = "자동으로 처치 %d/%d", Obj = { Type = "AutoKill", Count = 5 } },
			},
			Reward = { Gold = 1 },
		},
		N1 = {
			Kind = "Sub", Title = "장인의 손놀림", Speaker = "Guild", Factions = { Neutral = true }, Requires = { Done = { "M1_4" } },
			Start = "길드 안내자: 다듬기는 정확하게. 한 번에 두 마리!",
			Steps = { { Text = "스킬 한 번에 2마리 %d/%d", Obj = { Type = "SkillHit", Min = 2, Count = 3 } } },
			Reward = { Gold = 1 },
		},
		N2 = {
			Kind = "Sub", Title = "길드 보급 장부", Speaker = "Guild", Factions = { Neutral = true }, Requires = { Done = { "M2_1" } },
			Start = "길드 안내자: 두 편 다 우리 장비가 필요해요. 보급 골드를 모아요.",
			Steps = {
				{ Text = "보급 장부 %d/2", Obj = { Type = "Trials", List = {
					{ Key = "a", Type = "Kill", Kind = "BigSlime", Count = 3 },
					{ Key = "b", Type = "EarnGold", Source = "Monster", Count = 60 },
				} } },
				{ Text = "교차로로 가요", Guide = "Crossroads", Obj = { Type = "Enter", Zone = "Crossroads" } },
			},
			Reward = { Gold = 1 },
		},
	},
}

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
		{ Id = "Kill", Weight = 40, Units = { 25, 40 }, DailyUnits = { 50, 60 }, RewardPerUnit = 1.0,
			Text = "%s %d마리 쓰러뜨리기" },
		{ Id = "Golden", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 30,
			Text = "황금 %s %d마리 처치" },
		{ Id = "Gold", Weight = 20, Units = { 40, 60 }, DailyUnits = { 50, 60 }, RewardPerUnit = 0.5,
			Text = "사냥으로 골드 %s 벌기" },
		{ Id = "Release", Weight = 20, Units = { 2, 3 }, DailyUnits = { 3 }, RewardPerUnit = 8,
			Text = "몬스터에게 스킬 %d번 맞히기" },
		{ Id = "Goose", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 20,
			Text = "황금 거위 줄다리기 %d번 참여" },
		{ Id = "Hunt", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Halo", PvP = true,
			Text = "현상수배범 %d명 잡기 (괴수 토벌 포함)" },
		{ Id = "Plunder", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Horns", PvP = true,
			Text = "빛의 기사단 %d명 털기" },
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
			{ Id = "Kill", Weight = 3, Monster = "BigSlime", Strict = true, Targets = { 3 } }, -- 왕 슬라임 3마리
			{ Id = "Kill", Weight = 1, Monster = "Slime", Targets = { 12, 15 } }, -- sometimes / on reroll: 슬라임 12~15마리
			{ Id = "Release", Weight = 3, Targets = { 3, 4, 5 } }, -- 몬스터에게 스킬 3~5번 맞히기
			{ Id = "Gold", Weight = 3, Targets = { 40, 50, 60 } }, -- 사냥으로 골드 40~60 벌기
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
-- Lv1..Quests.Newbie.MaxLevel = Newbie.RewardMinutes x Slots + Newbie.ChestMinutes (10), else Daily's (25)
function Config.DailyDayMinutes(level)
	local nb = Config.Quests.Newbie
	local slots = Config.Quests.Slots
	if type(nb) == "table" and type(nb.Dailies) == "table" and #nb.Dailies > 0
		and (tonumber(level) or 1) <= (tonumber(nb.MaxLevel) or 0) then
		return (tonumber(nb.RewardMinutes) or Config.Daily.QuestMinutes) * slots
			+ (tonumber(nb.ChestMinutes) or Config.Daily.ChestMinutes)
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
	ClassTicket = { Id = 0, PriceHint = 49, Kind = "Class", Name = "직업 변경권" },
	FactionTicket = { Id = 0, PriceHint = 79, Kind = "Faction", Name = "진영 변경권" },
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
	ChooseFaction = 1, ChooseClass = 1, StoryAction = 0.4, Swing = 0.1, Release = 0.25, SetAutoAttack = 0.25,
	UpgradeWeapon = 0.3, SellWeapon = 0.3, Rebirth = 1, SwitchFaction = 1, ChangeClass = 1, Travel = 0.5,
	RerollQuest = 0.5, ClaimQuest = 0.3, ClaimVacation = 1, UsePotion = 0.3, BuyPotion = 0.3,
	UseItem = 0.4, EquipWeapon = 0.3, SellMaterials = 1, SetAnnounceName = 0.5, SetTitle = 0.5, GhostHold = 2.7, -- GhostHold: a bit under the 3 s client cooldown
	SetSettings = 1, -- BB2: the client sends at most one blob per this + 0.05 s (a dropped call gets no answer)
}

----------------------------------------------------------------- keys + settings (BB1 / BB2)
-- Contract: docs/design/beta_basics_2026-10-05.md BB1 / BB2; A23-21: only PC keyboard keys can be changed in the beta,
-- the gamepad layout is fixed and touch-only devices show button names instead of keys.
-- Actions (in order: the KeyMap order and the settings list order):
--   Id, Group ("Combat" | "Potion" | "Window" | "Other"), Key = Enum.KeyCode name ("" = unbound), Pad = fixed gamepad
--   button ("" = none), Label / LabelEn = the action's name, Button / ButtonEn = what a touch-only device calls it,
--   Flag = "Table.Field" under Config (the action exists only while that is true), Window = Panels id (Group "Window").
-- Live rule: Flag on and, for the Window group, the Panels window registered (client). Non-live actions hold no key and
-- never take part in swaps. PadWired = the pad buttons that already work (BB21 wires the rest of the Pad column).
Config.Keybinds = {
	Actions = {
		{ Id = "Attack", Group = "Combat", Key = "F", Pad = "ButtonR2", Label = "공격", LabelEn = "Attack", Button = "공격 버튼", ButtonEn = "Attack button" },
		{ Id = "SkillQ", Group = "Combat", Key = "Q", Pad = "ButtonL2", Label = "스킬", LabelEn = "Skill", Button = "스킬 버튼", ButtonEn = "Skill button" },
		{ Id = "SkillZ", Group = "Combat", Key = "Z", Pad = "ButtonL1", Label = "스킬 2", LabelEn = "Skill 2", Button = "스킬 2 버튼", ButtonEn = "Skill 2 button", Flag = "Skills.ZEnabled" },
		{ Id = "Auto", Group = "Combat", Key = "R", Pad = "ButtonR1", Label = "자동 전투", LabelEn = "Auto combat", Button = "자동 버튼", ButtonEn = "Auto button" },
		{ Id = "GhostHold", Group = "Combat", Key = "T", Pad = "DPadRight", Label = "유령 붙잡기", LabelEn = "Ghost hold", Button = "유령 버튼", ButtonEn = "Ghost button" },
		{ Id = "PotionHP", Group = "Potion", Key = "One", Pad = "DPadUp", Label = "HP 물약", LabelEn = "HP potion", Button = "HP 물약 버튼", ButtonEn = "HP potion button" },
		{ Id = "PotionMP", Group = "Potion", Key = "Two", Pad = "DPadDown", Label = "MP 물약", LabelEn = "MP potion", Button = "MP 물약 버튼", ButtonEn = "MP potion button" },
		-- KeySet "Prompt" + NoClear: the default ProximityPrompt UI must be able to draw the key (review of 27246d1)
		{ Id = "Interact", Group = "Other", Key = "E", Pad = "ButtonX", Label = "상호작용", LabelEn = "Interact", Button = "상호작용 버튼", ButtonEn = "Interact button",
			KeySet = "Prompt", NoClear = true },
		{ Id = "Upgrade", Group = "Other", Key = "U", Pad = "", Label = "다음 무기", LabelEn = "Next weapon", Button = "다음 무기 카드", ButtonEn = "Next weapon card" },
		{ Id = "Bag", Group = "Window", Key = "G", Pad = "", Label = "가방", LabelEn = "Bag", Button = "가방 버튼", ButtonEn = "Bag button", Window = "Bag" },
		{ Id = "Character", Group = "Window", Key = "C", Pad = "", Label = "내 캐릭터", LabelEn = "Character", Button = "메뉴 → 내 캐릭터", ButtonEn = "Menu → Character", Window = "Character" },
		{ Id = "Skills", Group = "Window", Key = "K", Pad = "", Label = "스킬 창", LabelEn = "Skills", Button = "메뉴 → 스킬", ButtonEn = "Menu → Skills", Window = "Skills" },
		{ Id = "Ranking", Group = "Window", Key = "L", Pad = "", Label = "랭킹", LabelEn = "Ranking", Button = "메뉴 → 랭킹", ButtonEn = "Menu → Ranking", Window = "Ranking" },
		{ Id = "Help", Group = "Window", Key = "H", Pad = "", Label = "도움말", LabelEn = "Help", Button = "메뉴 → 도움말", ButtonEn = "Menu → Help", Window = "Help" },
		{ Id = "Journal", Group = "Window", Key = "J", Pad = "", Label = "퀘스트 일지", LabelEn = "Quest journal", Button = "메뉴 → 퀘스트 일지", ButtonEn = "Menu → Quest journal", Window = "Journal" },
		{ Id = "Map", Group = "Other", Key = "M", Pad = "DPadLeft", Label = "지도", LabelEn = "Map", Button = "지도 버튼", ButtonEn = "Map button" },
		{ Id = "Menu", Group = "Other", Key = "B", Pad = "ButtonY", Label = "메뉴", LabelEn = "Menu", Button = "메뉴 버튼", ButtonEn = "Menu button" },
	},
	-- Roblox / the default camera use these (I/O zoom, Comma/Period + arrows + PageUp/PageDown camera, W A S D move,
	-- Space jump, Shift lock, Tab player list, / and ` chat, Esc menu, F9-F12 Studio / developer keys). A key Roblox
	-- turns out to swallow in a Studio Play check moves here.
	Reserved = { "Escape", "Slash", "Tab", "Backquote", "Return", "KeypadEnter", "Space", "LeftShift", "RightShift",
		"W", "A", "S", "D", "I", "O", "Comma", "Period", "PageUp", "PageDown", "Up", "Down", "Left", "Right",
		"F9", "F10", "F11", "F12" },
	-- filled below: A-Z, Zero-Nine, F1-F8, KeypadZero-KeypadNine, symbols, LeftControl, LeftAlt, CapsLock (minus Reserved)
	Allowed = {},
	PadWired = { Attack = true, SkillQ = true }, -- R2 attack, L2 skill (as before BB1); BB21 wires the other Pad buttons
	MaxKeyLen = 24, -- longest key name a save may hold
	Labels = { LeftControl = "Ctrl", LeftAlt = "Alt", CapsLock = "Caps", Minus = "-", Equals = "=", LeftBracket = "[",
		RightBracket = "]", Semicolon = ";", Quote = "'", BackSlash = "\\" }, -- + digits / keypad digits below
	None = "없음", -- label of an unbound action
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

-- 'One' -> '1', 'KeypadOne' (or 'Keypad1') -> 'Num1', 'LeftControl' -> 'Ctrl', '' -> '없음' ('None' with en), letters stay
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
	Version = 1, -- Settings.V
	MaxBlobKeys = 16, -- top-level keys of one SetSettings blob (V, Keys, the seven values, Seq)
	Defs = {
		Sfx = { Type = "Number", Min = 0, Max = 1, Step = 0.1 },
		Shake = { Type = "Bool" },
		DmgNum = { Type = "Enum", Options = { "All", "Off" } },
		Tags = { Type = "Enum", Options = { "All", "Near", "Off" } },
		KeyBadges = { Type = "Bool" },
		Lang = { Type = "Enum", Options = { "Auto", "ko", "en" } },
		BagSort = { Type = "Enum", Options = { "Default", "Grade", "Count" } },
	},
	Order = { "Sfx", "Shake", "KeyBadges", "DmgNum", "Tags", "Lang", "BagSort" },
	Text = {
		Sfx = "효과음 크기", SfxEn = "Sound effects",
		Shake = "화면 흔들림", ShakeEn = "Screen shake",
		DmgNum = "피해 숫자", DmgNumEn = "Damage numbers",
		Tags = "다른 사람 이름표", TagsEn = "Other players' name tags",
		KeyBadges = "키 표시", KeyBadgesEn = "Key hints",
		Lang = "언어", LangEn = "Language",
		BagSort = "가방 정렬", BagSortEn = "Bag order",
		Options = {
			All = "모두", AllEn = "All", Off = "끄기", OffEn = "Off", Near = "가까운 사람만", NearEn = "Nearby only",
			Auto = "자동", AutoEn = "Auto", ko = "한국어", koEn = "한국어", en = "English", enEn = "English",
			Default = "기본", DefaultEn = "Default", Grade = "등급순", GradeEn = "By grade", Count = "개수순", CountEn = "By count",
		},
		On = "켜기", OnEn = "On",
		Off = "끄기", OffEn = "Off",
		-- (action name, key) once per action per session: a new action's default key was already one of my keys
		KeyCollision = "새 동작 [%s]의 기본 키 %s가 이미 쓰여서 비워 뒀어요. 설정에서 정해 주세요",
		KeyCollisionEn = "The new action [%s] has no key: its default key %s is already in use. Pick one in Settings.",
		Reserved = "그 키는 로블록스가 써요", ReservedEn = "Roblox uses that key",
		NotAllowed = "그 키는 쓸 수 없어요", NotAllowedEn = "That key can't be used",
		Swapped = "%s · %s 키를 서로 바꿨어요", SwappedEn = "Swapped the keys %s and %s", -- (key label, key label)
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
	for key, def in ST.Defs do
		local v, d = src[key], defaults[key]
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
		Jelly = { Kind = "Material", Name = "슬라임 젤리", Sell = 2, Color = Color3.fromRGB(110, 210, 110), Icon = "IconJelly" },
		SlimeCore = { Kind = "Material", Name = "왕 슬라임 핵", Sell = 8, Color = Color3.fromRGB(80, 160, 235), Icon = "IconSlimeCore" },
		GoblinTooth = { Kind = "Material", Name = "고블린 이빨", Sell = 6, Color = Color3.fromRGB(235, 225, 190), Icon = "IconGoblinTooth" },
		BruteHorn = { Kind = "Material", Name = "우두머리 뿔", Sell = 18, Color = Color3.fromRGB(200, 150, 100), Icon = "IconBruteHorn" }, -- review ui-brutehorn-contrast: readable on the row
		Bone = { Kind = "Material", Name = "낡은 뼛조각", Sell = 14, Color = Color3.fromRGB(225, 225, 210), Icon = "IconBone" },
		KnightCrest = { Kind = "Material", Name = "녹슨 기사 문장", Sell = 40, Color = Color3.fromRGB(150, 150, 170), Icon = "IconKnightCrest" },
		Candy = { Kind = "Material", Name = "핼러윈 사탕", Sell = 5, Color = Color3.fromRGB(255, 140, 60), Icon = "IconCandy" }, -- Halloween kinds
		Enh70 = { Kind = "Enhance", Name = "강화 주문서 70%", Chance = 0.7, Plus = 1, Color = Color3.fromRGB(120, 200, 255), Icon = "IconScrollEnh", IconBand = "IconScrollEnhBand" },
		-- A23-14 gains 70% = +1 / 30% = +3 / 10% = +5 with the 50% fail-drop: expected change at +1..+9 is
		-- +0.55 / +0.55 / +0.05 per use (at +0: +0.70 / +0.90 / +0.50), so the rarest scroll is never a loss on average
		Enh30 = { Kind = "Enhance", Name = "강화 주문서 30%", Chance = 0.3, Plus = 3, Color = Color3.fromRGB(190, 130, 255), Icon = "IconScrollEnh", IconBand = "IconScrollEnhBand" },
		Enh10 = { Kind = "Enhance", Name = "강화 주문서 10%", Chance = 0.1, Plus = 5, Color = Color3.fromRGB(255, 190, 60), Icon = "IconScrollEnh", IconBand = "IconScrollEnhBand" },
		Move70 = { Kind = "Transfer", Name = "강화 옮기기 주문서 70%", Chance = 0.7, Color = Color3.fromRGB(120, 230, 200), Icon = "IconScrollMove", IconBand = "IconScrollMoveBand" },
		Move30 = { Kind = "Transfer", Name = "강화 옮기기 주문서 30%", Chance = 0.3, Color = Color3.fromRGB(210, 150, 255), Icon = "IconScrollMove", IconBand = "IconScrollMoveBand" },
		Move10 = { Kind = "Transfer", Name = "강화 옮기기 주문서 10%", Chance = 0.1, Color = Color3.fromRGB(255, 210, 90), Icon = "IconScrollMove", IconBand = "IconScrollMoveBand" },
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
	-- the first king slime a player defeats always drops one 70% scroll, plus a one-time hint (Text.FirstScroll shown
	-- NoticeSeconds; that kill's Loot Fx carries First = true so the client skips its own "where to use it" toast)
	FirstScroll = { Monster = "BigSlime", Item = "Enh70", NoticeSeconds = 6 },
	-- a weapon drop the player already owns turns into gold
	DuplicateWeaponGold = { [4] = 300, [5] = 1000, [6] = 3000, [7] = 9000, [8] = 3000 },
	Text = {
		Got = "+%s",
		GotN = "+%s ×%d",
		Potion = { HP = "HP 물약", MP = "MP 물약" },
		PotionFull = "물약이 가득 차서 %s은(는) 못 받았어요.",
		-- full-stack notices: at most once per item id (or potion kind) per player per FullNoticeSeconds, kind "info"
		ItemFull = "%s이(가) 가득 찼어요 (최대 %d개). 대장간에서 팔 수 있어요.", -- materials
		ItemFullUse = "%s이(가) 가득 찼어요 (최대 %d개). 메뉴 → 아이템에서 써 보세요.", -- scrolls (not sellable)
		UseCombat = "전투 중에는 주문서를 쓸 수 없어요.",
		EquipDead = "쓰러진 동안에는 무기를 바꿀 수 없어요.",
		RareWeapon = "%s 무기! %s 획득!", -- grade name (희귀 / 영웅 / 전설), weapon
		DuplicateWeapon = "이미 가진 %s → %s골드로 바뀌었어요.",
		JackpotSelf = "전설 무기 [%s]! 메뉴 → 아이템에서 장착해요.",
		FirstScroll = "주문서를 얻었어요! 메뉴 → 아이템에서 무기를 강화해 봐요. (실패해도 무기는 안전해요)",
		EnhanceOk = "강화 성공! %s +%d → +%d (공격 %d%% → %d%%)",
		EnhanceFailDown = "강화 실패… %s +%d → +%d (무기는 안전해요)",
		EnhanceFailKeep = "강화 실패… 그래도 %s +%d 그대로예요!",
		EnhanceMax = "이미 최대 강화(+%d)예요.",
		MoveOk = "옮기기 성공! %s +%d · %s +%d",
		MoveFail = "옮기기 실패… %s +%d 그대로 남아 있어요.",
		MoveSame = "다른 무기를 골라 주세요.",
		MoveNothing = "옮길 강화가 없어요.",
		NotOwned = "가지고 있지 않은 무기예요.",
		NoItem = "그 아이템이 없어요.",
		Equip = "%s 장착!",
		EquipCombat = "전투 중에는 무기를 바꿀 수 없어요.",
		SellDone = "재료 %d개 판매! 골드 +%s",
		SellNothing = "팔 재료가 없어요.",
		SellFar = "대장간 모루 가까이에서 재료를 팔 수 있어요.",
	},
}

-- A23-15 server-wide chat announcements (AnnounceService -> remote "Announce" -> client Announce.luau). Server sends
-- { Key, Args, Grade }; the client formats Text[Key] in its language and shows a TextChatService system message.
Config.Announce = {
	WindowSeconds = 10, -- one player's announcements within this window are grouped into one "…외 N개" line
	MinWeaponGrade = 3, -- weapon drops of this grade rank or better are announced (3 = 희귀)
	Text = {
		Subject = "%s님이", -- the finder's game nickname
		Anon = "%s 한 명이", -- name hidden (P5): "빛의 기사단 한 명이"
		RareWeapon = "%s %s에게서 %s 무기 [%s]을(를) 얻었어요!", -- subject, monster, grade, weapon
		Jackpot = "★ 대박! %s 슬라임에게서 전설 무기 [%s]을(를) 얻었어요! ★", -- subject, weapon
		FirstMax = "%s [%s]을(를) 처음으로 +10까지 강화했어요!", -- subject, weapon
		More = "%s 좋은 것을 %d개 더 얻었어요!", -- subject, count (grouped)
		-- server-wide event lines (Events below; plain text, no names)
		PumpkinKingAppear = "호박 대왕이 호박밭에 나타났어요! 함께 잡아요!", -- A23-30: it appears in the PumpkinPatch
		PumpkinKingAppearEn = "The Pumpkin King appeared in the Pumpkin Patch! Let's beat it together!",
		PumpkinKingDefeat = "호박 대왕이 사탕을 와르르 쏟았다!",
		PumpkinKingDefeatEn = "The Pumpkin King spilled a pile of candy!",
		PumpkinKingLeave = "호박 대왕이 사탕 자루를 들고 돌아갔어요. 다음에 또 와요!",
		PumpkinKingLeaveEn = "The Pumpkin King went home with its candy sack. See you next time!",
		GhostKingAppear = "유령 왕이 유령 숲에 나타났어요! 함께 잡아요!", -- A23-45
		GhostKingAppearEn = "The Ghost King appeared in the Haunted Hollow! Let's beat it together!",
		GhostKingDefeat = "유령 왕이 사탕을 우수수 떨어뜨렸어요!",
		GhostKingDefeatEn = "The Ghost King dropped a shower of candy!",
		GhostKingLeave = "유령 왕이 스르르 사라졌어요. 다음에 또 만나요!",
		GhostKingLeaveEn = "The Ghost King faded away. See you next time!",
		NameHidden = "이제 전체 알림·랭킹에 내 이름 대신 진영 이름이 나와요.",
		NameShown = "이제 전체 알림·랭킹에 내 이름이 나와요.",
		MenuShow = "알림·랭킹에 내 이름: 보여요",
		MenuHide = "알림·랭킹에 내 이름: 숨겨요",
		-- BB37 AnnounceService.PublicName (server-wide NotifyAll lines, town board, ranking rows) and the settings row
		HiddenName = "%s 한 명", HiddenNameEn = "A member of %s", -- (faction name)
		Someone = "누군가", SomeoneEn = "Someone", -- hidden name without a faction
		Honorific = "님", HonorificEn = "", -- appended to a shown name when the line reads "%s이 …"
		SettingLabel = "알림·랭킹에 내 이름 숨기기", SettingLabelEn = "Hide my name in announcements and rankings",
		SettingNotes = {
			"같은 서버의 머리 위 이름표와 Tab 목록은 숨길 수 없어요",
			"전체 랭킹에는 로블록스 이름과 얼굴이 나와요. 숨기면 \"<진영> 한 명\"으로 보여요",
		},
		SettingNotesEn = {
			"Nametags and the Tab list in your server always show your name",
			"Global rankings show your Roblox name and face. Hidden, they show \"A member of <faction>\"",
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
	BetaPioneer = { Name = "★베타 개척자", NameEn = "★Beta Pioneer", Color = Color3.fromRGB(255, 210, 60) },
	GrayLegend = { Name = "회색 전설", NameEn = "Gray Legend", Color = Color3.fromRGB(190, 190, 200) },
}
Config.TitleOrder = { "BetaPioneer", "GrayLegend" }

Config.Sounds = { -- optional built-in files; client must pcall and ignore failures
	Swing = "rbxasset://sounds/swordslash.wav",
	Release = "rbxasset://sounds/swordlunge.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
}

Config.Combo = { ResetSeconds = 4, Milestones = { { 10, "좋아요! x10" }, { 25, "멋져요! x25" }, { 50, "폭주! x50" }, { 100, "전설! x100" } } }

-- addendum A3-H4 / H5 / M1: client layout rules (UI uses IgnoreGuiInset = true)
Config.UI = {
	TopInsetPad = 8, -- every top-anchored HUD block starts at Y >= GuiService:GetGuiInset().Y + TopInsetPad...
	TopInsetFallback = 64, -- ...or this many px when the inset is unknown (never use the top 0..64 px band)
	ScaleMin = 0.75, -- UIScale = clamp(viewportY / 720, ScaleMin, ScaleMax)
	ScaleMax = 1.25,
	-- desktop (no touch): UIScale = clamp(viewportY / 720 * DesktopScaleMult, DesktopScaleMin, DesktopScaleMax)
	DesktopScaleMult = 0.8,
	DesktopScaleMin = 0.6,
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
		RibbonHeader = { Id = "rbxassetid://71822647719938", Size = Vector2.new(512, 121), Slice = Rect.new(130, 40, 460, 81), FitHeight = true, Tone = "Navy", Inner = Rect.new(114, 33, 497, 100) }, -- Firefly PanelHeader: navy plate, left disc (icon); light text
		Pill = { Id = "rbxassetid://116332974579615", Size = Vector2.new(512, 120), Slice = Rect.new(41, 23, 472, 98), FitHeight = true, Tone = "Parchment" },
		BarTrack = { Id = "rbxassetid://137159149395361", Size = Vector2.new(512, 86), Slice = Rect.new(45, 25, 467, 61), FitHeight = true, Tone = "NavyDeep", Inner = Rect.new(21, 21, 491, 63) }, -- Firefly redraw (bundle 5)
		BtnSquare = { Id = "rbxassetid://91067965003210", Size = Vector2.new(510, 512), Slice = Rect.new(100, 100, 410, 412), SliceScale = 0.22, Tone = "Navy" }, -- Firefly navy square (bundle 4): light labels
		-- round buttons / rings (Fit)
		BtnAttack = { Id = "rbxassetid://77268479686299", Size = Vector2.new(512, 512), Round = true, Tone = "Orange", Inner = Rect.new(58, 50, 452, 427) }, -- Firefly orange attack disc (bundle 6)
		BtnSpecial = { Id = "rbxassetid://78355405067281", Size = Vector2.new(512, 512), Round = true, Tone = "QuestBlue", Inner = Rect.new(61, 57, 450, 425) }, -- Firefly blue skill disc BtnSkill (bundle 6)
		LevelBadge = { Id = "rbxassetid://97341840194719", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(75, 77, 436, 427) }, -- Firefly (bundle 6): no faction / white number
		PortraitRing = { Id = "rbxassetid://81879569016992", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(85, 82, 427, 424) }, -- Firefly (bundle 6): transparent hole
		-- bundle 6 (Firefly 2026-10-06, art/review/b6_hud_sheet.png): faction level badges, HUD discs, minimap frame, class glyphs
		LevelBadgeHalo = { Id = "rbxassetid://140072275905868", Size = Vector2.new(512, 512), Round = true, Tone = "Parchment", Inner = Rect.new(122, 150, 386, 400) }, -- ivory centre: dark number
		LevelBadgeHorns = { Id = "rbxassetid://131043118998343", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(92, 101, 420, 414) },
		LevelBadgeArtisan = { Id = "rbxassetid://135233332138906", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(118, 112, 389, 365) },
		BtnPotion = { Id = "rbxassetid://100849701844741", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(67, 72, 447, 436) }, -- count socket bottom-right
		MinimapFrame = { Id = "rbxassetid://121102769530414", Size = Vector2.new(512, 512), Tone = "Navy", Inner = Rect.new(74, 76, 439, 428) }, -- A23-26 live minimap
		GlyphSword = { Id = "rbxassetid://104681533093026", Size = Vector2.new(512, 512) }, -- attack button glyph: Warrior
		GlyphStaff = { Id = "rbxassetid://123664178583457", Size = Vector2.new(512, 512) }, -- attack button glyph: Mage (bow: bundle 7)
		-- bundle 4/5 + bundle 1 masters (Firefly 2026-10-06, art/review/s2/b45_common_ui_sheet.png): common window kit
		PanelMain = { Id = "rbxassetid://96251321300093", Size = Vector2.new(512, 308), Slice = Rect.new(37, 37, 475, 270), SliceScale = 0.35, Tone = "Parchment" },
		DialogBox = { Id = "rbxassetid://112964393409287", Size = Vector2.new(512, 189), Slice = Rect.new(50, 50, 462, 139), SliceScale = 0.35, Tone = "Parchment" },
		ListRow = { Id = "rbxassetid://125160937753435", Size = Vector2.new(512, 128), Slice = Rect.new(50, 45, 462, 83), FitHeight = true, Tone = "Parchment" },
		StatusPlate = { Id = "rbxassetid://111562222428548", Size = Vector2.new(512, 153), Slice = Rect.new(140, 50, 460, 103), FitHeight = true, Tone = "Navy", Inner = Rect.new(145, 41, 498, 129) },
		Chip = { Id = "rbxassetid://98251464747498", Size = Vector2.new(512, 189), Slice = Rect.new(95, 60, 417, 129), FitHeight = true, Tone = "Parchment" }, -- white: tint with ImageColor3
		BarFill = { Id = "rbxassetid://106350683674684", Size = Vector2.new(512, 76), Slice = Rect.new(38, 20, 474, 56), FitHeight = true }, -- white: HP green / MP #3B5BDB / XP sky
		BtnPrimary = { Id = "rbxassetid://71722849741284", Size = Vector2.new(512, 165), Slice = Rect.new(83, 45, 429, 120), FitHeight = true, Tone = "Gold" }, -- gold capsule
		BtnSecondary = { Id = "rbxassetid://81644397617472", Size = Vector2.new(512, 160), Slice = Rect.new(80, 50, 432, 110), FitHeight = true, Tone = "QuestBlue" }, -- blue capsule
		BtnConfirm = { Id = "rbxassetid://105674867912092", Size = Vector2.new(512, 156), Slice = Rect.new(78, 50, 434, 106), FitHeight = true, Tone = "Confirm" }, -- green capsule
		BtnRound = { Id = "rbxassetid://115852818963492", Size = Vector2.new(512, 495), Round = true, Tone = "Navy" }, -- do not stretch
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
		ShieldHalo = { Id = "rbxassetid://137212311874878", Size = Vector2.new(490, 512) },
		ShieldHorns = { Id = "rbxassetid://134547958841068", Size = Vector2.new(497, 512) },
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
		IconGoose = { Id = "rbxassetid://105838105764489", Size = Vector2.new(218, 256) },
		IconSafe = { Id = "rbxassetid://137095933008547", Size = Vector2.new(512, 512) }, -- Firefly green shield (bundle 5)
		IconSprout = { Id = "rbxassetid://88235635858040", Size = Vector2.new(512, 512) }, -- Firefly (bundle 8)
		IconStar = { Id = "rbxassetid://117033474251317", Size = Vector2.new(256, 243) },
		IconStarEmpty = { Id = "rbxassetid://78608910520884", Size = Vector2.new(256, 255) },
		IconClover = { Id = "rbxassetid://132542570098556", Size = Vector2.new(246, 256) },
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
		PortraitGuideHalo = { Id = "rbxassetid://110194702566253", Size = Vector2.new(512, 512) },
		PortraitGuideHorns = { Id = "rbxassetid://131286803604294", Size = Vector2.new(512, 512) },
		PortraitGuideArtisan = { Id = "rbxassetid://123450056288234", Size = Vector2.new(512, 512) },
		-- A23-40 layout B parts (Firefly 2026-10-06: 83eaffb minimap_ring_sheet, ccab705 / a601f39 b12 / b1213 sheets)
		MinimapRing = { Id = "rbxassetid://134883699176479", Size = Vector2.new(512, 512), Round = true, Tone = "Navy", Inner = Rect.new(63, 63, 449, 449) }, -- hole d386 at (256,256): the map circle d392 tucks under the inner rim
		WarMeterFrame = { Id = "rbxassetid://73887778381300", Size = Vector2.new(512, 74), Tone = "Navy", Inner = Rect.new(66, 22, 442, 54) }, -- opaque navy inside: the fills draw above it
		WarCrownPip = { Id = "rbxassetid://100273975086572", Size = Vector2.new(512, 512) }, -- the war split marker
		QuestRow = { Id = "rbxassetid://77896448940362", Size = Vector2.new(512, 124), Slice = Rect.new(118, 56, 388, 68), FitHeight = true, Tone = "Navy" }, -- left disc (60,62) r45, number box (400,49)-(462,78)
		AutoRingOn = { Id = "rbxassetid://82348810388598", Size = Vector2.new(512, 512) }, -- turns around the auto button while ON
		GlyphQuest = { Id = "rbxassetid://85735330851016", Size = Vector2.new(512, 512) },
		GlyphAuto = { Id = "rbxassetid://125607651991448", Size = Vector2.new(512, 512) },
		NameTag = { Id = "rbxassetid://101536515759381", Size = Vector2.new(512, 153), Slice = Rect.new(80, 72, 432, 82), FitHeight = true, Tone = "Navy" },
		ListRowSelected = { Id = "rbxassetid://117472551663985", Size = Vector2.new(512, 173), Slice = Rect.new(64, 52, 448, 121), FitHeight = true, Tone = "Gold" }, -- b: deep gold
		Toast = { Id = "rbxassetid://92139413642355", Size = Vector2.new(512, 102), Slice = Rect.new(100, 50, 460, 52), FitHeight = true, Tone = "Navy" }, -- icon disc centre (49,51) r~37
		-- Firefly GPT Image 2.5 batch 2026-10-06 (art/approved.json), 512x512, transparent
		-- monster heads (quest kill rows IconMon<Unit>, drop notices)
		IconMonBigSlime = { Id = "rbxassetid://137346108147632", Size = Vector2.new(512, 512) },
		IconMonGoblin = { Id = "rbxassetid://84081351311140", Size = Vector2.new(512, 512) },
		IconMonGoblinBrute = { Id = "rbxassetid://121297622077113", Size = Vector2.new(512, 512) },
		IconMonSkeleton = { Id = "rbxassetid://140176829708782", Size = Vector2.new(512, 512) },
		IconMonSkeletonKnight = { Id = "rbxassetid://81833958125033", Size = Vector2.new(512, 512) },
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
		FactionCardHaloE = { Id = "rbxassetid://115165874013728", Size = Vector2.new(380, 636) },
		FactionCardHornsE = { Id = "rbxassetid://117803151290007", Size = Vector2.new(380, 636) },
		FactionCardNeutralE = { Id = "rbxassetid://78748710982730", Size = Vector2.new(380, 636) },
		FactionTitleRibbonE = { Id = "rbxassetid://77703498329138", Size = Vector2.new(549, 108) },
		FactionPremisePanelE = { Id = "rbxassetid://101379550181314", Size = Vector2.new(1024, 130) },
		FactionPremiseFreshTyped = { Id = "rbxassetid://105024415024705", Size = Vector2.new(1024, 174) },
		FactionCardHaloFreshTyped = { Id = "rbxassetid://76818879022385", Size = Vector2.new(570, 954) },
		FactionCardHornsFreshTyped = { Id = "rbxassetid://137806621328187", Size = Vector2.new(570, 954) },
		FactionCardNeutralFreshTyped = { Id = "rbxassetid://127475794518664", Size = Vector2.new(570, 954) },
		FactionTitleFreshTypedBalanced = { Id = "rbxassetid://81044633324158", Size = Vector2.new(1024, 210) },
		FactionTitleFreshTyped = { Id = "rbxassetid://111239293270560", Size = Vector2.new(1024, 210) },
		FactionFooterFreshTyped = { Id = "rbxassetid://128423642459976", Size = Vector2.new(1024, 126) },
		FactionFooterPanelE = { Id = "rbxassetid://99568724265364", Size = Vector2.new(928, 86) },
		-- pick screens (mockups art/out/UI_Faction_B.png, UI_Class_A.png): text-free card backgrounds, regions in CardLayout
		CardHalo = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(635, 1024) },
		CardHorns = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(617, 1024) },
		CardNeutral = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(612, 1024) },
		ClassCardHalo = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(647, 1024) },
		ClassCardHorns = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(608, 1024) },
		ClassCardNeutral = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(618, 1024) },
		ShieldNeutral = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(251, 256) },
		TitleRibbon = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(256, 63) }, -- empty title ribbon
		-- class characters (Firefly blocky toy style, bundle 10, 50bf8ea, user OK): Char<Faction><Class><M|F>.
		-- One gender per class for now: ClassPicker shows the other gender's picture until bundle 19. Neutral Archer
		-- stays empty (A23-39: the Artisan third class becomes the pet tamer; its picture comes later).
		CharHaloWarriorM = { Id = "rbxassetid://107223446177550", Size = Vector2.new(476, 663) },
		CharHaloWarriorF = { Id = "", Size = Vector2.new(464, 512) },
		CharHaloMageM = { Id = "", Size = Vector2.new(460, 512) },
		CharHaloMageF = { Id = "rbxassetid://86506033601447", Size = Vector2.new(408, 768) },
		CharHaloArcherM = { Id = "rbxassetid://129427231445677", Size = Vector2.new(421, 768) },
		CharHaloArcherF = { Id = "", Size = Vector2.new(406, 512) },
		CharHornsWarriorM = { Id = "", Size = Vector2.new(446, 512) },
		CharHornsWarriorF = { Id = "rbxassetid://125807011729545", Size = Vector2.new(561, 768) },
		CharHornsMageM = { Id = "rbxassetid://88874835473142", Size = Vector2.new(540, 768) },
		CharHornsMageF = { Id = "", Size = Vector2.new(449, 512) },
		CharHornsArcherM = { Id = "", Size = Vector2.new(488, 512) },
		CharHornsArcherF = { Id = "rbxassetid://75414336669920", Size = Vector2.new(422, 768) },
		CharNeutralWarriorM = { Id = "rbxassetid://112070391814033", Size = Vector2.new(401, 768) },
		CharNeutralWarriorF = { Id = "", Size = Vector2.new(476, 512) },
		CharNeutralMageM = { Id = "", Size = Vector2.new(465, 512) },
		CharNeutralMageF = { Id = "rbxassetid://116514332783939", Size = Vector2.new(402, 768) },
		CharNeutralArcherM = { Id = "", Size = Vector2.new(416, 512) },
		CharNeutralArcherF = { Id = "", Size = Vector2.new(463, 512) },
		-- perk / misc icons
		IconExp = { Id = "rbxassetid://125679953240313", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconHeart = { Id = "rbxassetid://92865909915468", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconWings = { Id = "rbxassetid://78896204690689", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconGoldPile = { Id = "rbxassetid://140588051269822", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconGoldGuard = { Id = "rbxassetid://137696635031445", Size = Vector2.new(512, 512) }, -- Firefly 2026-10-06: Horns perk 3 (keep plundered gold)
		IconBloodSword = { Id = "rbxassetid://80973759611362", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconGauge = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(256, 70) },
		IconDemon = { Id = "rbxassetid://101305375688321", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconNoBuff = { Id = "rbxassetid://125613826056625", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06, re-cut 3f1716b (faction perk row)
		IconShieldBlue = { Id = "rbxassetid://97867243551313", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconNoLoot = { Id = "rbxassetid://105527491154744", Size = Vector2.new(512, 512) }, -- Firefly redraw 2026-10-06 (faction perk row)
		IconHammer = { Id = "rbxassetid://134187840367993", Size = Vector2.new(512, 512) }, -- Firefly (bundle 5): artisan perk 4
		IconAltar = { Id = "" --[[old-account upload removed 2026-10-05: code fallback until the Firefly redraw]] , Size = Vector2.new(241, 256) },
		IconBoot = { Id = "rbxassetid://121630849275556", Size = Vector2.new(512, 512) }, -- Firefly winged boot (bundle 5): class speed / pet speed
		-- A15 hit/pain art; empty IDs retain the code fallback.
		FxSlash = { Id = "rbxassetid://99494789057875", Size = Vector2.new(256, 251) },
		FxHitSpark = { Id = "rbxassetid://76401646477744", Size = Vector2.new(254, 256) },
		FxShockRing = { Id = "rbxassetid://135827777163619", Size = Vector2.new(256, 252) },
		FxMagicBurst = { Id = "rbxassetid://92519617657939", Size = Vector2.new(256, 256) },
		FxDust = { Id = "rbxassetid://108076168454993", Size = Vector2.new(222, 256) },
		EmoOuch = { Id = "rbxassetid://72032537654477", Size = Vector2.new(256, 175) },
		EmoTears = { Id = "rbxassetid://70917213593538", Size = Vector2.new(256, 197) },
		EmoDizzy = { Id = "rbxassetid://124025733418147", Size = Vector2.new(256, 232) },
		EmoAngry = { Id = "rbxassetid://123879588166068", Size = Vector2.new(256, 232) },
		EmoStress = { Id = "rbxassetid://135439617637591", Size = Vector2.new(256, 213) },
		Weapon_Warrior_T1 = { Id = "rbxassetid://110253568224769", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T2 = { Id = "rbxassetid://134296432983209", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T3 = { Id = "rbxassetid://118676171420516", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T4 = { Id = "rbxassetid://121628920172881", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T5 = { Id = "rbxassetid://78787056413343", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T6 = { Id = "rbxassetid://134912361470616", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T7_Halo = { Id = "rbxassetid://81358930713578", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T7_Horns = { Id = "rbxassetid://109996418847092", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T7_Neutral = { Id = "rbxassetid://113768226721190", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T1 = { Id = "rbxassetid://94017465082266", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T2 = { Id = "rbxassetid://124480073241910", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T3 = { Id = "rbxassetid://98652791112835", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T4 = { Id = "rbxassetid://114114689990814", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T5 = { Id = "rbxassetid://82923455323942", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T6 = { Id = "rbxassetid://86455721876057", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T7_Halo = { Id = "rbxassetid://83762763419599", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T7_Horns = { Id = "rbxassetid://112320137471828", Size = Vector2.new(1024, 1024) },
		Weapon_Mage_T7_Neutral = { Id = "rbxassetid://111298666053873", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T1 = { Id = "rbxassetid://114530628874023", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T2 = { Id = "rbxassetid://77934186009567", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T3 = { Id = "rbxassetid://107992927949121", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T4 = { Id = "rbxassetid://135806799928152", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T5 = { Id = "rbxassetid://76246016710761", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T6 = { Id = "rbxassetid://111067065096221", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T7_Halo = { Id = "rbxassetid://123944650415871", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T7_Horns = { Id = "rbxassetid://129557918253283", Size = Vector2.new(1024, 1024) },
		Weapon_Archer_T7_Neutral = { Id = "rbxassetid://134108221476202", Size = Vector2.new(1024, 1024) },
		Weapon_Warrior_T8 = { Id = "rbxassetid://73318746668169", Size = Vector2.new(512, 512) }, -- jelly-crown legendary (bundle 9)
		Weapon_Mage_T8 = { Id = "rbxassetid://109033955946235", Size = Vector2.new(512, 512) },
		Weapon_Archer_T8 = { Id = "rbxassetid://118154781260735", Size = Vector2.new(512, 512) },
		Tex_Grass = { Id = "rbxassetid://104463174886181", Size = Vector2.new(1024, 1024) }, -- A23-30 E: Firefly painted meadow (Tex_Grass_FF)
		Tex_LeafyGrass = { Id = "rbxassetid://92129043469297", Size = Vector2.new(1024, 1024) }, -- A23-30 E: forest floor (Tex_LeafyGrass_FF)
		Tex_HaloTiles = { Id = "rbxassetid://108329087203475", Size = Vector2.new(1024, 1024) },
		Tex_Ground = { Id = "rbxassetid://140158008208812", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: ruins dirt (Tex_Ground_FF)
		Tex_DirtPath = { Id = "rbxassetid://85612652410118", Size = Vector2.new(1024, 1024) }, -- A23-30 E: road (Tex_DirtPath_FF)
		Tex_CrownShardGround = { Id = "rbxassetid://114856730896342", Size = Vector2.new(1024, 1024) },
		Tex_CrackedLava = { Id = "rbxassetid://116294435572633", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: Horns lava cracks (Tex_CrackedLava_FF)
		Tex_Cobblestone = { Id = "rbxassetid://106614155699357", Size = Vector2.new(1024, 1024) }, -- A23-30 E: town cobbles (Tex_Cobblestone_FF)
		Tex_Basalt = { Id = "rbxassetid://106904976329450", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: Horns lair floor (Tex_Basalt_FF)
		Tex_WoodPlanks = { Id = "rbxassetid://89937004688664", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: bridges / benches (parts) (Tex_WoodPlanks_FF)
		Tex_Slate = { Id = "rbxassetid://71336203326371", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: ruins flagstones (Tex_RuinsFlagstone_FF)
		Tex_Sand = { Id = "rbxassetid://131974232864115", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: beaches (Tex_Sand_FF)
		Tex_Rock = { Id = "rbxassetid://104777096316045", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: every cliff (Tex_Rock_FF)
		Tex_Marble = { Id = "rbxassetid://82709638100363", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: fountain / Halo parts (Tex_Marble_FF)
		Tex_Limestone = { Id = "rbxassetid://75666187308111", Size = Vector2.new(1024, 1024) }, -- A23-29/30 Firefly: Halo town floor (Tex_Limestone_FF)
		Tex_PumpkinSoil = { Id = "rbxassetid://126628778707353", Size = Vector2.new(1024, 1024) }, -- A23-30 pumpkin field soil (Mud slot)
		Tex_TreeLeaves = { Id = "rbxassetid://139379724133324", Size = Vector2.new(1024, 1024) }, -- tree leaf balls (neutral: the part Color tints it)
		Tex_TreeBark = { Id = "rbxassetid://75619597726241", Size = Vector2.new(1024, 1024) }, -- tree trunks (neutral: the part Color tints it)
		-- sky sun / moon (black = transparent, additive): WarService Sky.SunTextureId / MoonTextureId per war sky
		Sky_Sun = { Id = "rbxassetid://104329382887122", Size = Vector2.new(512, 512) }, -- Neutral sun
		Sky_SunDawn = { Id = "rbxassetid://134904669662412", Size = Vector2.new(512, 512) }, -- Dawn (Halo crown) sun
		Sky_MoonEclipse = { Id = "rbxassetid://101354392666522", Size = Vector2.new(512, 512) }, -- Eclipse (Horns crown) moon
		MapParchment = { Id = "rbxassetid://133911744102396", Size = Vector2.new(1536, 1024) },
	},
	-- Lettering images (TXT_*) were deleted 2026-10-06 (unused: UseTextImages=false). Text stays live TextLabels.
	TextLabels = {},
	-- picked from the mockup (UI_HUD_Final.png) and the part images
	Colors = {
		-- text
		Ink = Color3.fromRGB(66, 40, 18), -- brown ink text on parchment
		InkSoft = Color3.fromRGB(122, 84, 46), -- secondary text on parchment (3/5, hints)
		InkOutline = Color3.fromRGB(255, 247, 228), -- light halo around ink text
		Light = Color3.fromRGB(255, 255, 255), -- white text on navy / red / ribbon
		LightSub = Color3.fromRGB(226, 222, 206), -- labels on navy (금고, 주머니)
		TextOutline = Color3.fromRGB(34, 20, 10), -- dark outline for white / gold text
		GoldText = Color3.fromRGB(255, 228, 100), -- numbers on navy (금고 1,250 / Lv)
		GoldInk = Color3.fromRGB(236, 164, 16), -- gold numbers on parchment (150G, +120); use with TextOutline
		GoodInk = Color3.fromRGB(40, 140, 60), -- done / 받기 on parchment
		BadInk = Color3.fromRGB(190, 40, 40),
		-- fills (also the IMG-R4 fallback fills, keyed by Part.Tone)
		Parchment = Color3.fromRGB(242, 221, 178),
		ParchmentDark = Color3.fromRGB(214, 182, 128), -- dividers / empty slots on parchment
		Ribbon = Color3.fromRGB(241, 207, 132),
		Rim = Color3.fromRGB(110, 66, 24), -- hand-inked brown outline (fallback stroke)
		Navy = Color3.fromRGB(26, 40, 79),
		NavyDeep = Color3.fromRGB(19, 31, 56), -- bar track interior
		Gold = Color3.fromRGB(240, 190, 60), -- gold trim
		Red = Color3.fromRGB(225, 40, 36), -- attack button face (pre-Firefly)
		Orange = Color3.fromRGB(246, 130, 32), -- Firefly attack disc face (bundle 6)
		Confirm = Color3.fromRGB(76, 175, 60), -- Firefly green capsule (BtnConfirm)
		-- bars
		XPBlue = Color3.fromRGB(30, 170, 255),
		QuestBlue = Color3.fromRGB(56, 144, 253),
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
Config.UIArt.CardLayout = {
	CardHalo = { Aspect = 0.620, Title = { 0.169, 0.297, 0.658, 0.088 }, Desc = { 0.153, 0.424, 0.698, 0.051 },
		Motto = { 0.170, 0.498, 0.660, 0.053 }, Perks = { 0.079, 0.577, 0.847, 0.257 }, Button = { 0.224, 0.869, 0.553, 0.080 } },
	CardHorns = { Aspect = 0.603, Title = { 0.165, 0.264, 0.665, 0.086 }, Desc = { 0.214, 0.366, 0.567, 0.062 },
		Motto = { 0.146, 0.434, 0.710, 0.065 }, Perks = { 0.143, 0.509, 0.729, 0.277 }, Button = { 0.167, 0.807, 0.661, 0.100 } },
	CardNeutral = { Aspect = 0.598, Title = { 0.208, 0.272, 0.587, 0.080 }, Desc = { 0.225, 0.369, 0.547, 0.056 },
		Motto = { 0.163, 0.433, 0.675, 0.064 }, Perks = { 0.137, 0.518, 0.724, 0.296 }, Button = { 0.180, 0.837, 0.624, 0.101 } },
	ClassCardHalo = { Aspect = 0.632, Portrait = { 0.121, 0.096, 0.762, 0.347 }, Name = { 0.170, 0.445, 0.666, 0.070 },
		Body = { 0.073, 0.527, 0.858, 0.302 }, Button = { 0.202, 0.845, 0.592, 0.091 } },
	ClassCardHorns = { Aspect = 0.594, Portrait = { 0.123, 0.088, 0.758, 0.302 }, Name = { 0.202, 0.396, 0.595, 0.071 },
		Body = { 0.133, 0.479, 0.725, 0.319 }, Button = { 0.189, 0.840, 0.623, 0.075 } },
	ClassCardNeutral = { Aspect = 0.604, Portrait = { 0.089, 0.107, 0.827, 0.294 }, Name = { 0.136, 0.410, 0.728, 0.077 },
		Body = { 0.083, 0.497, 0.830, 0.323 }, Button = { 0.142, 0.848, 0.712, 0.088 } },
}

-- faction card perk rows (icon part + short plain text, mockup art/out/UI_Faction_B.png). Numbers must match
-- Config.Factions (XPBonus, MaxHPMult, GoldBonus, DamageBonus, ChargeCap) and Config.Kaiju.StarsNeeded.
-- Short (optional) = shorter line used when Text cannot fit its row at the min text size (landscape phones).
Config.UIArt.FactionPerks = {
	Halo = {
		{ Icon = "IconExp", Text = "경험치 +30%" },
		{ Icon = "IconHeart", Text = "체력 +20%, 계속 회복" },
		{ Icon = "IconWings", Text = "스킬로 동료 치유" },
		{ Icon = "IconPouch", Text = "주머니 골드 자동 저금" },
	},
	Horns = {
		{ Icon = "IconGoldPile", Text = "골드 +25%" },
		{ Icon = "IconBloodSword", Text = "공격력 +15%, 체력 흡수", Short = "공격력 +15%, 흡혈" },
		{ Icon = "IconGoldGuard", Text = "약탈한 골드 지켜내기" },
		{ Icon = "IconDemon", Text = "별 5개면 괴수 변신!" },
	},
	Neutral = {
		{ Icon = "IconNoBuff", Text = "싸움 버프 없음" },
		{ Icon = "IconShieldBlue", Text = "PvP 없음 (안전)" },
		{ Icon = "IconNoLoot", Text = "약탈·현상수배 걱정 없음", Short = "약탈·수배 걱정 없음" },
		{ Icon = "IconHammer", Text = "제작 특화 (곧 추가)" },
	},
}

-- E approval: 2026-10-04. Fixed Korean glyphs preserve the approved illustration.
-- English/localized sprites are a separate release item; live fallbacks stay available.
Config.UIArt.FactionE = {
    Enabled = true,
    Locale = "ko",
    BakedText = true,
    BakedPerkIcons = true,
    BakedFooterIcon = true,
    CardAspect = 380 / 636,
    Parts = {
        Halo = "FactionCardHaloFreshTyped", Horns = "FactionCardHornsFreshTyped", Neutral = "FactionCardNeutralFreshTyped",
        Title = "FactionTitleFreshTypedBalanced", Premise = "FactionPremiseFreshTyped", Footer = "FactionFooterFreshTyped",
    },
    ButtonRects = {
		Halo = { 0.24793872, 0.80211072, 0.50513279, 0.07605582 },
		Horns = { 0.20268785, 0.78690554, 0.59458409, 0.07466372 },
		Neutral = { 0.17223303, 0.81271190, 0.65554510, 0.07833555 },
    },
    -- Last benefit glyph bottom + 6px in each 570x954 export; enlarged touch hitboxes stay below it.
    ButtonHitTop = { Halo = 0.76277029, Horns = 0.75550551, Neutral = 0.77759915 },
    MinBakedWidth = { Premise = 460 },
    Layout = {
        ReferenceSize = Vector2.new(1584, 1050),
        Title = { 514/1584, 5/1050, 557/1584, 111/1050 },
        Premise = { 240/1584, 124/1050, 1100/1584, 187/1050 },
        Cards = { 238/1584, 318/1050, 1102/1584, 627/1050 },
        Footer = { 326/1584, 929/1050, 929/1584, 116/1050 },
    },
    SemanticText = {
        Title = "어느 편에 설래요?",
        Premise = {
            "세상을 지키던 균형의 왕관이 부서졌다.",
            "조각을 주운 자들 중 누구는 머리 위에 후광이, 누구는 뿔이 돋았다.",
            "조각을 더 많이 모으는 쪽이 세상을 다시 만든다.",
        },
        Footer = "나중에 교차로 마을의 운명의 제단에서 바꿀 수 있어요 (무료 또는 변경권)",
        Cards = {
            Halo = {Name="빛의 기사단",Desc="후광을 얻은 자들.",Motto="지키고, 치유하고, 되찾아 줘라!",Button="이 편으로!",
                Perks={"경험치 +30%","체력 +20%, 계속 회복","스킬로 동료 치유","주머니 골드 자동 저금"}},
            Horns = {Name="뿔 군단",Desc="뿔을 얻은 자들.",Motto="털고, 버티고, 괴수가 되어라!",Button="이 편으로!",
                Perks={"골드 +25%","공격력 +15%, 체력 흡수","약탈한 골드 지켜내기","별 5개면 괴수 변신!"}},
            Neutral = {Name="장인 길드",Desc="조각을 다듬는 자들.",Motto="줍지 말고, 다듬고, 만들어라!",Button="이 편으로!",
                Perks={"싸움 버프 없음","PvP 없음 (안전)","약탈·현상수배 걱정 없음","제작 특화 (곧 추가)"}},
        },
    },
}

-- addendum A1: optional custom visual models in ServerStorage[FolderName] named by monster id or GooseId
Config.CustomModels = {
	FolderName = "CustomModels",
	GooseId = "GoldenGoose",
	-- golden variant: gold Highlight instead of recoloring parts. 0.5 looked like see-through jelly on the textured cube
	-- (user 2026-10-06 "투명해 보여"): a stronger fill reads as gold
	GoldenFillTransparency = 0.25,
}

-- A23-5 (2026-10-05): every chibi 3D class costume is out of the game (CostumeService and its folders were removed
-- 2026-10-06); players are their own Roblox avatar + class weapon + halo/horns. Roblox-style outfits come later.

----------------------------------------------------------------- story ("세계관": flavor text only)
Config.Story = {
	-- plain lines (no format specifiers)
	Premise = {
		"세상을 지키던 균형의 왕관이 부서졌다.",
		"조각을 주운 자들 중 누구는 머리 위에 후광이, 누구는 뿔이 돋았다.",
		"조각을 더 많이 모으는 쪽이 세상을 다시 만든다.",
	},
	-- The server opens Config.Tutorial.Welcome after the first class choice. Do not overlap it with old toasts.
	Intro = {},
	-- A23-9 opening (subtitles = Premise lines; plain text)
	OpeningAsk = "어느 편에 설래?",
	OpeningSkip = "건너뛰기",
	OpeningReplay = "오프닝 다시 보기",
	OpeningReplayUnsafe = "오프닝은 마을 안에서 다시 볼 수 있어요.",
	IntroNeutral = {},
	FactionLore = {
		Halo = "왕관 조각이 후광이 된 자들. 조각을 지키고 세상을 고친다.",
		Horns = "왕관 조각이 뿔이 된 자들. 조각을 빼앗아 세상을 차지한다.",
		Neutral = "조각을 줍지 않고, 다듬기로 한 자들.", -- addendum A6
	},
	MarkLore = "후광과 뿔은 왕관 조각의 힘이에요. 계급이 오를수록 커져요.",
	ZoneLore = {
		Crossroads = "부서진 왕관이 떨어진 곳",
		HaloTown = "후광을 얻은 자들의 성",
		HornsTown = "뿔이 돋은 자들의 굴",
		SlimeMeadow = "조각 가루를 먹은 슬라임 들판",
		GoblinWoods = "조각 도둑들의 숲",
		SkeletonRuins = "옛 왕국의 무덤",
	},
	-- format strings (always through string.format)
	WarWin = {
		Halo = "이번 판 왕관은 빛의 기사단이 차지했다! 하늘이 왕관의 금빛으로 물들어요. (10분간 골드·경험치 +25%%)",
		Horns = "이번 판 왕관은 뿔 군단이 차지했다! 하늘이 왕관의 핏빛으로 물들어요. (10분간 골드·경험치 +25%%)",
	},
	WarDraw = "이번 판 왕관은 아무도 차지하지 못했어요!",
	GooseStart = "왕관 조각을 품은 황금 거위가 교차로 마을에 내려왔어요! 기사단은 구조, 뿔 군단은 밀렵!",
	GooseResult = {
		Halo = "기사단이 황금 거위를 구조했어요! 조각이 빛을 되찾았어요.",
		Horns = "뿔 군단이 황금 거위를 밀렵했어요! 조각이 어둠에 물들었어요.",
		Tie = "황금 거위가 날아가 버렸어요! 무승부예요.",
	},
	-- (GooseNoRival removed by A23-14: a goose with no rival is now "함께 구조", texts in Config.Goose.Text)
	KaijuSiren = "경보! %s이(가) 왕관 조각의 어둠에 삼켜지고 있어요! 10초 뒤 괴수가 돼요!",
	KaijuStart = "괴수 %s 출현! 기사단은 어디서든 공격할 수 있어요!",
	KaijuDefeated = "기사단이 괴수 %s을(를) 쓰러뜨렸어요! 보상 %s골드를 나눠 가져요.", -- (name, gold actually paid: CR-L19)
	KaijuDefeatedNoReward = "괴수 %s이(가) 쓰러졌어요.", -- CR-L19: (name) nobody was paid
	KaijuSurvived = "괴수 %s이(가) 끝까지 살아남았어요! 전설의 악당 탄생!",
	SurviveTitle = "전설의 악당",
	GrayLegendTitle = "회색 전설",
	RebirthIntro = "환생하면 왕관 조각을 다시 고를 수 있어요. 어느 편으로 다시 태어날까요?",
	Fall = "타락: 후광이 깨지고 뿔이 돋았다. (골드 +5%% 영구 · 찢어진 검은 망토)",
	Redeem = "구원: 뿔이 부서지고 금 간 후광이 떠올랐다. (경험치 +5%% 영구)",
	SackLore = "빼앗긴 골드에는 원한이 붙어요. 기사단이 도둑을 잡으면 120%%로 돌아와요!",
}

-- addendum A7-3: crown-shard one-liners (<= 30 chars, plain text, no format specifiers) shown only at the matching
-- unlock moment (reaching that zone's MinLevel) and only while Rebirths == 0. Keyed by zone id.
Config.StoryLines = {
	GoblinWoods = "숲 너머에서 왕관 조각이 부른다. 도둑을 조심해!",
	SkeletonRuins = "옛 왕국의 무덤에 큰 조각이 잠들어 있다.",
}

-- addendum A7-3: client "next goal" helpers
Config.NextGoal = {
	RewardSamples = 10, -- "N마리 더!" uses the average gold of the player's last 10 kill rewards
	MaxKillsShown = 99, -- above this keep the normal upgrade text
	GuideSeconds = 90, -- zone guide (HUD.ShowGuide) auto-clears after this many seconds
	GuideZones = { "GoblinWoods", "SkeletonRuins" }, -- guide on reaching these zones' MinLevel (Lv 10 / Lv 25)
}

-- Korean message templates (always through string.format). Use these for the listed situations.
Config.Text = {
	LoadFailed = "데이터를 불러오지 못했어요. 잠시 후 다시 접속해 주세요.",
	NeedLevel = "레벨 %d 이상만 들어갈 수 있어요!",
	EnteredPvP = "PvP 지역이에요! 다른 진영을 조심하세요.",
	EnteredPvPNeutral = "PvP 지역이지만 장인 길드는 공격받지 않아요.", -- CR-L24: Neutral entering a PvP zone ("info")
	EnteredSafe = "안전 지대예요.",
	Banked = "골드 %s을(를) 금고에 넣었어요.",
	HaloCourier = "천사 배달부가 골드 %s을(를) 금고에 넣었어요.",
	LevelUp = "레벨 업! Lv %d",
	NotEnoughGold = "골드가 부족해요.",
	WeaponBought = "%s 장착!",
	WeaponMaxed = "이미 최고의 무기예요!",
	WeaponNeedLevel = "이 무기는 레벨 %d부터 살 수 있어요.", -- purchase gate (an owned one: EquipNeedLevel)
	-- A23-28: equipping keeps MinLevel too (also after a rebirth / Lv5+ free class change)
	EquipNeedLevel = "이 무기는 레벨 %d부터 쓸 수 있어요.", EquipNeedLevelEn = "You can use this weapon from Lv %d.",
	WeaponAutoSwap = "Lv %d부터 쓸 수 있는 무기예요 → %s 무기로 바꿨어요.",
	WeaponAutoSwapEn = "That weapon needs Lv %d → switched to %s.",
	WeaponUsableNow = "이제 %s 무기를 쓸 수 있어요! 대장간이나 메뉴 → 아이템에서 장착해요.",
	WeaponUsableNowEn = "You can now use %s! Equip it at the blacksmith or in Menu → Items.",
	NeedFaction = "먼저 진영을 골라야 해요.",
	-- ShopService (blacksmith / potion merchant)
	WeaponShopFar = "대장간 모루 가까이에서 무기를 구매해 주세요.",
	WeaponNotSold = "이 무기는 대장간 상점에서 판매하지 않아요.",
	WeaponSellFar = "대장간 모루 가까이에서 무기를 판매해 주세요.",
	WeaponSold = "%s 판매! 골드 +%s", -- (weaponName, gold)
	BlacksmithPromptAction = "무기 보기",
	BlacksmithPromptObject = "대장간",
	PotionShopFar = "물약 상인 가까이에서 구매해 주세요.",
	PotionStockFull = "물약은 종류별 %d개까지 보관할 수 있어요.", -- (PotionInventoryCap)
	PotionBought = "%s 물약 %d개를 구매했어요!", -- (kind, amount)
	-- PvP
	Plundered = "%s에게 골드 %s을(를) 빼앗겼어요! 기사단이 45초 안에 도둑을 잡으면 120%%로 돌아와요.",
	PlunderGain = "골드 %s을(를) 원한 자루에 담았어요! PvP 지역에서 45초 버티면 내 것! (현상수배 별 %d개)",
	PlunderTooSoon = "방금 턴 상대예요. 3분 동안은 또 털 수 없어요.",
	HonorGain = "명예 +%d",
	AutoSleepy = "조각이 졸려요… 한 걸음 움직여 볼까? (30초 뒤 자동 전투가 쉬어요)", -- P2
	AutoRestOn = "자리를 비운 것 같아 자동 전투가 쉬어요. 움직이면 바로 다시 돌아요.",
	AutoRestOff = "다시 왔네요! 자동 전투가 다시 돌아요.",
	AutoChoiceWait = "선택 카드가 기다리고 있어요. 고르면 자동 전투가 다시 돌아요.",
	GraduateStart = "새싹 졸업! 60초 뒤부터 대결 가능", -- A23-18
	GraduateEnd = "이제 다른 진영과 대결할 수 있어요!",
	BoldStrong = "센 상대를 이겼어요! 명예·악명·전쟁 점수 ×2",
	BoldWeak = "약한 상대라 명예·악명·전쟁 점수가 절반이에요.",
	BountyGain = "현상금 %s골드 획득! 명예 +%d",
	BountyAnnounce = "[빛의 기사단] %s이 현상금 %s골드를 받았어요!", -- BB37: AnnounceService.PublicName(p, true)
	-- BB37 (검수): a hidden knight is already "빛의 기사단 한 명", so no "[빛의 기사단]" prefix (the faction twice)
	BountyAnnounceHidden = "%s이 현상금 %s골드를 받았어요!",
	BountyAnnounceHiddenEn = "%s got a %s gold bounty!",
	BullyBountyGain = "깡패 현상금 %s골드 획득!",
	MostWanted = "%s이 최고 현상수배범이 되었어요! 현상금 %s골드", -- BB37: PublicName(p, true)
	BullyKO = "깡패 처치! 보상 없음, 덩치·공격력 -15%% (깡패 %d단계)",
	BullyVictim = "깡패에게 당했어요. 잃은 건 없어요!",
	BullyDecay = "깡패 단계가 줄었어요 (%d단계)",
	BullyNoAuto = "깡패 벌칙 중에는 자동 전투를 쓸 수 없어요. 단계가 다 빠지면 다시 돼요.", -- A23-22
	BullyAutoOff = "무단 PvP 벌칙: 자동 전투가 꺼졌어요. 경험치·드랍도 절반이에요.", -- A23-22 (auto was ON)
	BullyPenaltyEnd = "깡패 벌칙이 끝났어요! 자동 전투를 다시 켤 수 있어요. 경험치·드랍도 원래대로예요.", -- A23-22
	BullyPenaltyEndEn = "Your bully penalty is over! You can turn auto combat on again. XP and drops are back to normal.",
	BullyPenaltyEndNoAuto = "깡패 벌칙이 끝났어요! 경험치·드랍이 원래대로예요.", -- auto combat not unlocked yet
	BullyPenaltyEndNoAutoEn = "Your bully penalty is over! XP and drops are back to normal.",
	Revenge = "%s에게 복수하세요! 90초 동안 공격력 +25%%",
	RevengeDone = "복수 성공!",
	-- grudge sack
	SackPaid = "원한 자루를 지켜냈어요! 골드 %s 획득",
	SackLost = "원한 자루를 빼앗겼어요!",
	GrudgeRefund = "%s님이 원한 자루를 되찾아 줬어요! 골드 %s이(가) 금고로!",
	GrudgeReturned = "도둑이 쓰러져서 빼앗긴 골드 %s이(가) 금고로 돌아왔어요.",
	GrudgeMail = "원한 우편이 왔어요! 털렸던 골드 %s이(가) 금고로 돌아왔어요.", -- P3
	DailyAllDone = "오늘 할 일 끝! 이제 쉬어도 손해 없어요. 더 하고 싶으면 이야기 퀘스트나 사냥을 즐겨요.", -- P8
	GhostHoldOk = "유령이 도둑을 붙잡았어요! 버텨야 하는 시간 +%d초 (최대 +%d초)", -- A23-18
	GhostHoldMax = "이 자루는 더 붙잡을 수 없어요 (최대 +%d초).",
	GhostHeld = "원한 유령이 붙잡고 있어요! 버텨야 하는 시간이 늘었어요.",
	GhostButton = "유령으로 붙잡기 ({GhostHold})", -- BB1 key token: the key part shows only on keyboards
	GhostWait = "다시 붙잡기 %d초",
	AvengerBonus = "복수 대행 보너스 +%s골드!",
	GrudgeAvengedAll = "%s이 %s의 원한 자루를 되찾았어요!", -- BB37: PublicName(killer, true), PublicName(thief, true)
	-- travel / blocks
	TravelBlockedStars = "현상수배 별이 3개 이상이면 걸어서 도망쳐야 해요!",
	TravelBlockedCombat = "전투 중에는 할 수 없어요.",
	TravelBlockedSack = "원한 자루를 든 동안은 순간이동할 수 없어요!",
	TravelBlockedKaiju = "괴수는 순간이동할 수 없어요!",
	Traveling = "이동 중...",
	TravelCancelled = "이동이 취소됐어요.",
	BlockedSack = "원한 자루를 든 동안은 할 수 없어요.",
	BlockedKaiju = "괴수 이벤트 중에는 할 수 없어요.",
	BlockedStars = "현상수배 별이 없어야 할 수 있어요.",
	BlockedBully = "깡패 단계가 모두 풀린 뒤에 장인 길드로 갈 수 있어요.", -- CR-L9: altar / rebirth to Neutral with bully stacks
	WaitRespawn = "다시 살아난 뒤에 할 수 있어요.", -- CR-L30: travel / class / rebirth / altar while dead
	-- faction / class / tickets
	UnderdogSignOn = "약한 편 합류 보너스 +%d골드!",
	SwitchDoneFree = "%s(으)로 진영을 바꿨어요! (배신의 대가: %s 0)",
	SwitchDoneTicket = "%s(으)로 진영을 바꿨어요! (변경권 사용, 점수 유지)",
	SwitchCooldown = "진영 변경은 %s 후에 가능해요.",
	NoTicket = "변경권이 없어요. 메뉴 > 변경권 상점에서 살 수 있어요.",
	TicketSaving = "변경권 구매를 저장하는 중이에요. 잠시 뒤 다시 눌러 주세요.", -- CR-L25: UseTicket returned "Pending"
	ClassChosen = "%s이(가) 되었어요!",
	ClassChangedFree = "%s(으)로 직업을 바꿨어요! 레벨 1부터 다시 시작해요.", -- free change from Lv ClassChange.FreeKeepLevelBelow on
	ClassChangedFreeKeep = "%s(으)로 직업을 바꿨어요! (Lv%d 전이라 레벨 유지)", -- A23-14 (className, FreeKeepLevelBelow)
	ClassFreeKeepLevelF = "Lv%d 전에는 레벨 유지", -- A23-14 client preview (FreeKeepLevelBelow)
	ClassChangeRuleF = "직업은 나중에 메뉴 > 직업 변경에서 바꿀 수 있어요 (무료: Lv%d 전에는 레벨 유지, 그 뒤엔 Lv1부터 / 변경권: 레벨 유지)", -- A23-14 ClassPicker footer (FreeKeepLevelBelow)
	ClassChangedTicket = "%s(으)로 직업을 바꿨어요! (변경권 사용, 레벨 유지)",
	ClassSame = "이미 그 직업이에요.",
	ClassNeedSafe = "직업은 안전 지대에서만 바꿀 수 있어요.",
	ClassTicketGot = "직업 변경권 1장을 받았어요!",
	FactionTicketGot = "진영 변경권 1장을 받았어요!",
	ProductNotReady = "상품 준비 중이에요.",
	-- rebirth
	RebirthNeed = "환생하려면 레벨 %d이(가) 필요해요.",
	RebirthDone = "환생 완료! 레벨만 처음부터, 골드·무기·아이템은 그대로예요. 골드·경험치 영구 +%d%%", -- A23-14
	RebirthAnnounce = "%s이 %d번째 환생을 했어요!", -- BB37: PublicName(p, true)
	-- quests
	QuestDone = "추가 퀘스트 완료! +%s골드",
	DailyReady = "일일 퀘스트 완료! [받기]를 눌러요.",
	DailyClaimed = "일일 보상! +%s골드 +%s 경험치",
	DailyChest = "일일 퀘스트 3개 완료! 보너스 상자 +%s골드 +%s 경험치",
	DailyChestTicket = "보너스 상자에서 직업 변경권이 나왔어요!",
	DailyAutoPaid = "어제 받지 않은 일일 보상을 금고에 넣었어요. (+%s골드)",
	VacationClaimed = "휴가 보너스! +%s골드 +%s 경험치",
	-- war
	WarChest = "전쟁 상자! +%s골드",
	-- goose
	GooseReward = "황금 거위 보상! +%s골드 +%s 경험치",
	GooseCheer = "응원별 +1 (%d/5) — 5개 모이면 다음 황금 보상은 희귀!",
	RareToast = "희귀 보상! ×5",
	RareAnnounce = "%s이 황금 거위 희귀 보상을 받았어요!", -- BB37: PublicName(p, true)
	-- kaiju
	KaijuQueued = "다른 괴수가 있어요. 그 괴수가 끝나면 변신해요!",
	KaijuReward = "괴수 토벌 보상 +%s골드!",
	KaijuSurviveReward = "살아남았다! 주머니 골드 ×1.5 = %s골드가 금고로!",
	-- addendum A3 (review fixes)
	AutoUnderAttack = "공격받는 중! 공격 버튼으로 반격하세요", -- M3: auto ON + took PvP damage (once per 60 s)
	EnemyTown = "상대 진영 마을에는 들어갈 수 없어요!", -- L1: bounced to Crossroads (also Neutral in either town)
	-- addendum A7-3 (next goal, client)
	Unlocked = "해금! %s", -- (unlockText)
	KillsToAfford = "%s %d마리 더!", -- (monsterName, kills)
	CanAfford = "교차로 대장간에서 %s 구입 가능!", -- (weaponName)
	Recommended = "추천", -- Travel panel badge
	-- addendum A7-4 (pick / change screens, client)
	FirstTimeRecommend = "처음이면 추천", -- Warrior class card
	ChangeFree = "무료로 바꾸기",
	ChangeTicket = "티켓으로 바꾸기 (보유 %d장)", -- (tickets)
	LossScore = "%s %s 초기화", -- ("명예" | "악명", Util.FormatNumber(score)) e.g. "명예 340 초기화"
	LossLevel = "Lv %d → Lv 1", -- (current level)
	KeepAll = "전부 유지",
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
	Names = { Power = "전투력", Level = "레벨", Rebirths = "환생", Fame = "명성", Gold = "골드" },
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
		BoardNames = { Honor = "명예", Infamy = "악명", Artisan = "장인 명성", PvP = "무단 PvP" },
		BoardNamesEn = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan fame", PvP = "Unfair PvP" },
		-- the timed titles: "이번 주 명예 1위" / "이번 주 악명 1위" / "이번 주 장인 1위" (A23-22 / A23-24 wording)
		TitleNames = { Honor = "명예", Infamy = "악명", Artisan = "장인" },
		TitleNamesEn = { Honor = "Honor", Infamy = "Infamy", Artisan = "Artisan" },
		Empty = "아직 기록이 없어요", EmptyEn = "No records yet",
		Unknown = "플레이어", UnknownEn = "Player",
		Test = "테스트", TestEn = "Test",
		PvPTabNote = "약한 상대·자리 비운 사람·새내기를 쓰러뜨리면 올라가요. 3점 이상인 1~3위는 다음 주 무법자가 돼요.",
		PvPTabNoteEn = "Goes up when you KO weaker, idle or new players. Top 3 with 3+ points are outlaws next week.",
		RewardTabNote = "1~3위는 다음 주 경험치·드랍 +10%", RewardTabNoteEn = "Top 3: XP and drops +10% next week",
		Ineligible = "새 계정은 3일·플레이 30분이 지나야 전체 랭킹에 올라가요",
		IneligibleEn = "New accounts join the global ranking after 3 days and 30 minutes of play",
		Private = "비공개 서버에서는 랭킹 점수가 쌓이지 않아요", PrivateEn = "Private servers do not earn ranking points",
		OutlawTag = "무법자", OutlawTagEn = "Outlaw",
		OutlawChip = "무법자: 자동 전투 불가 · 경험치·드랍 절반 (월요일까지)",
		OutlawChipEn = "Outlaw: no auto combat · half XP and drops (until Monday)",
		RewardChip = "이번 주 %s %d위: 경험치·드랍 +10%% (월요일까지)", -- (board name, rank)
		RewardChipEn = "This week's %s #%d: XP and drops +10%% (until Monday)",
		OutlawStart = "지난주 무단 PvP %d위라서 이번 주는 무법자예요. 자동 전투 불가 · 경험치·드랍 절반 · 현상금 2배 (월요일까지)",
		OutlawStartEn = "Last week's unfair PvP #%d: you are an outlaw this week. No auto combat, half XP and drops, double bounty (until Monday)",
		OutlawEnd = "무법자 기간이 끝났어요! 자동 전투를 다시 켤 수 있어요.",
		OutlawEndEn = "Your outlaw week is over! Auto combat is back.",
		OutlawEndNoAuto = "무법자 기간이 끝났어요! 경험치·드랍이 원래대로예요.", -- auto combat not unlocked yet
		OutlawEndNoAutoEn = "Your outlaw week is over! XP and drops are back to normal.",
		-- (still a bully at the end of the outlaw week: no line here; CombatService says BullyPenaltyEnd when the stacks go)
		OutlawNoAuto = "무법자 기간에는 자동 전투를 쓸 수 없어요 (월요일까지).",
		OutlawNoAutoEn = "Outlaws cannot use auto combat (until Monday).",
		OutlawAutoOff = "무법자: 자동 전투가 꺼졌어요. 경험치·드랍도 절반이에요 (월요일까지).",
		OutlawAutoOffEn = "Outlaw: auto combat is off and XP / drops are halved (until Monday).",
		RewardStart = "지난주 %s %d위! 이번 주 경험치·드랍 +10%%와 칭호를 받았어요 (월요일까지).", -- (board name, rank)
		RewardStartEn = "Last week's %s #%d! XP and drops +10%% and a title this week (until Monday).",
		-- a top-3 player who switched faction since: the title is given, the bonus waits for that faction
		RewardStartOff = "지난주 %s %d위! 칭호를 받았어요. 경험치·드랍 +10%%는 %s에 있을 때만 켜져요 (월요일까지).", -- (board, rank, faction)
		RewardStartOffEn = "Last week's %s #%d! You got the title. XP and drops +10%% only while in %s (until Monday).",
		ArtisanGain = "+%d 장인 명성", ArtisanGainEn = "+%d artisan fame",
		-- BB11 town board (PvPService.updateBoard; 검수 2026-10-06): this server's weekly boards + one wanted line.
		-- RichText: the red outlaw tag is fixed text, names are escaped. Row = (rank, name, value).
		Board = {
			Header = "이 서버 · 이번 주 순위",
			Titles = { Honor = "기사단 명예", Infamy = "뿔 군단 악명", Artisan = "장인 명성", PvP = "이번 주 PvP" },
			Wanted = "현상수배",
			Row = "%d. %s %s", Sep = " · ", Empty = "(아직 없음)", Bully = "깡패", Gold = "G",
		},
		BoardEn = {
			Header = "This server · this week",
			Titles = { Honor = "Knights' honor", Infamy = "Horns' infamy", Artisan = "Artisan fame", PvP = "This week's PvP" },
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
				Name = string.format("이번 주 %s %d위", R.Text.TitleNames[board], rank),
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
		Player = "%s에게 쓰러졌어요", PlayerEn = "Knocked out by %s",
		Kaiju = "괴수 %s에게 쓰러졌어요", KaijuEn = "Knocked out by the kaiju %s",
		Monster = "%s에게 쓰러졌어요", MonsterEn = "Knocked out by %s",
		Fall = "떨어졌어요", FallEn = "You fell",
		Other = "쓰러졌어요", OtherEn = "You were knocked out",
		LostNone = "잃은 것 없음", LostNoneEn = "Nothing lost",
		Lost = "주머니 골드 %s 잃음", LostEn = "Lost %s pouch gold",
		Sack = "원한 자루를 놓쳤어요", SackEn = "You lost the grudge sack",
		Respawn = "%d초 뒤 부활", RespawnEn = "Back in %d s",
	},
	-- one tip per situation (%s = the potion key name, or '물약 버튼' on touch)
	Tips = {
		Monster = "HP가 낮으면 %s 물약!", MonsterEn = "Low HP? Drink a potion with %s!",
		Plundered = "기사단이 45초 안에 잡으면 120% 돌려받아요", PlunderedEn = "If a knight catches the thief within 45 s you get 120% back",
		Player = "비슷하거나 센 상대와 싸우면 명예·악명이 쌓여요", PlayerEn = "Fair fights build honor and infamy",
		Fall = "떨어지면 마을에서 다시 시작해요", FallEn = "A fall sends you back to town",
		Other = "갇혔을 땐 메뉴 → 이동", OtherEn = "Stuck? Menu -> Travel",
		PotionTouch = "물약 버튼", PotionTouchEn = "the potion button",
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

return Config
