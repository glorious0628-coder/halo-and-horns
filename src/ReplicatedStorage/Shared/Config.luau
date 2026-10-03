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

Config.Data = {
	StoreName = "HaloHorns_Player_v1", -- unchanged on purpose: v1 saves are migrated in place by DataService
	KeyPrefix = "P_",
	Version = 2,
	AutosaveInterval = 60,
	LockTimeout = 120, -- seconds; a lock older than this is considered dead
	LoadRetries = 5,
	LoadRetryDelay = 3,
	SaveRetries = 3,
	Defaults = {
		Version = 2,
		Level = 1,
		XP = 0,
		BankGold = 0,
		CarriedGold = 0,
		WeaponTier = 1, -- v1 name: SwordTier (migrated by DataService)
		Faction = "None",
		Class = "Warrior",
		ClassChosen = false, -- false -> ClassPicker shows (first pick is free and keeps level)
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
	},
	-- keys mirrored 1:1 to Player attributes (same name) by PlayerService
	Mirrored = {
		"Level", "XP", "BankGold", "CarriedGold", "WeaponTier", "Faction", "Class", "ClassChosen",
		"Rebirths", "RebirthBonus", "FallMarks", "RedeemMarks", "Honor", "Infamy", "SwitchCount",
		"LastSwitchTime", "PlaytimeSeconds", "TotalKills", "DailyDay", "DailyClaims",
		"VacationDays", "VacationGold", "VacationXP", "CheerStars",
		"TutorialStep", -- addendum A4
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
Config.Weapons = {
	{ Tier = 1, Damage = 8, Price = 0, MinLevel = 1, Color = Color3.fromRGB(120, 85, 50), Material = Enum.Material.Wood, Length = 3 },
	{ Tier = 2, Damage = 15, Price = 150, MinLevel = 1, Color = Color3.fromRGB(165, 120, 75), Material = Enum.Material.WoodPlanks, Length = 3.5 },
	{ Tier = 3, Damage = 38, Price = 800, MinLevel = 5, Color = Color3.fromRGB(175, 180, 190), Material = Enum.Material.Metal, Length = 4 },
	{ Tier = 4, Damage = 88, Price = 3000, MinLevel = 12, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, Length = 4.5 },
	{ Tier = 5, Damage = 200, Price = 10000, MinLevel = 20, Color = Color3.fromRGB(140, 220, 255), Material = Enum.Material.Glass, Length = 5 },
	{ Tier = 6, Damage = 450, Price = 30000, MinLevel = 30, Color = Color3.fromRGB(80, 255, 170), Material = Enum.Material.Neon, Length = 5.5 },
	{ Tier = 7, Damage = 1000, Price = 90000, MinLevel = 40, Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Length = 6.5,
		RequiresFaction = true,
		FactionColors = { Halo = Color3.fromRGB(255, 230, 120), Horns = Color3.fromRGB(200, 30, 40) },
	},
}
Config.MaxWeaponTier = #Config.Weapons

-- display names per class; tier 7 is a table keyed by faction
Config.WeaponNames = {
	Warrior = { "나뭇가지", "나무 검", "철 검", "황금 검", "크리스탈 검", "네온 검",
		{ Halo = "여명의 검", Horns = "파멸의 검", None = "왕관 조각 검" } },
	Mage = { "마른 지팡이", "참나무 지팡이", "철 지팡이", "황금 지팡이", "크리스탈 지팡이", "네온 지팡이",
		{ Halo = "여명의 지팡이", Horns = "파멸의 지팡이", None = "왕관 조각 지팡이" } },
	Archer = { "새총 활", "나무 활", "철 활", "황금 활", "크리스탈 활", "네온 활",
		{ Halo = "여명의 활", Horns = "파멸의 활", None = "왕관 조각 활" } },
}

function Config.WeaponName(tier, classId, factionId)
	local names = Config.WeaponNames[classId] or Config.WeaponNames.Warrior
	local n = names[tier]
	if type(n) == "table" then return n[factionId] or n.None end
	return n or "?"
end

function Config.WeaponColor(tier, factionId)
	local w = Config.Weapons[tier]
	if not w then return Color3.new(1, 1, 1) end
	if w.FactionColors and w.FactionColors[factionId] then return w.FactionColors[factionId] end
	return w.Color
end

-- normal per-target damage of the weapon at this level (before class, bonuses and multipliers)
function Config.WeaponDamage(tier, level)
	local w = Config.Weapons[tier] or Config.Weapons[1]
	return w.Damage * (1 + Config.Combat.LevelDamagePerLevel * (level - 1))
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
		ReleaseCenter = "Self", -- shockwave on self
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
		HealthMult = 0.8, Damage = 1.3, SwingInterval = 1.25,
		Pattern = "Splash", -- nearest valid target within Range, then every valid target within Splash of it
		Range = 35, Targets = 1, Splash = 7,
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

----------------------------------------------------------------- combat
Config.Combat = {
	CritChance = 0.10, -- PvE swings only (never releases, never PvP)
	CritMult = 2,
	LevelDamagePerLevel = 0.02, -- weapon damage * (1 + 0.02 * (level - 1))
	AutoUnlockLevel = 5,
	TownRegenPerSec = 0.10, -- fraction of max HP per second inside Town zones (all factions)
	AutoLoopInterval = 0.1,
	RegenTick = 1,
	ChargeTick = 0.1, -- perfect-window watcher interval
	ManualPriority = 1.0, -- addendum A3-H3: the auto loop skips a player for this long after a manual swing
	AutoPvPHintCooldown = 60, -- addendum A3-M3: "under attack" hint at most once per this many seconds
}

----------------------------------------------------------------- charge & release ("자동은 장전, 손은 발사")
-- Design intent: pure idle (auto swings + auto release) ~= 1.25x baseline DPS; auto swings + PERFECT release ~= 2.5x.
Config.Charge = {
	SwingImmediate = 0.5, -- a swing that hits deals 50% of the normal per-target damage right away
	MinRelease = 10, -- minimum (floored) stacks to release
	BaseFactor = 0.5, -- release per target = BaseFactor * D * stacks * mult
	PerStackBonus = 0.02, -- manual release: mult = 1 + 0.02 * stacks
	AutoReleaseMult = 1.5, -- automatic release (PERFECT window missed): mult = 1.5
	PerfectWindow = 3, -- seconds the golden ring glows after reaching the cap
	RadiusBase = 8,
	RadiusPerStack = 0.1,
	PvPCapPct = 0.35, -- release damage to a player <= 35% of the target's current MaxHealth
	HaloHealPct = 0.10, -- Halo release heals allies in the radius by 10% of the total damage dealt...
	HaloHealCapPct = 0.30, -- ...capped at 30% of each ally's MaxHealth...
	HaloAllyStacks = 10, -- ...and gives each OTHER ally in the radius +10 stacks
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
		ReleaseSupport = true, -- release heals allies + shares stacks (Config.Charge.Halo*)
		Perks = {
			"경험치 +30% (레벨이 빨리 올라요)",
			"체력 +20%, 계속 체력 회복",
			"발사하면 주변 동료 치유 + 게이지 +10",
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
			"발사 게이지가 더 높이 쌓여요 (175)",
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
		Id = "Neutral", Name = "장인 길드", Short = "장인", Emblem = "⚙",
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
function Config.DisplayTitle(factionId, honor, infamy, fallMarks, redeemMarks, sessionTitle)
	if type(sessionTitle) == "string" and sessionTitle ~= "" then return sessionTitle end
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

-- "base power" of a player (no Size Justice, no kaiju); rebirthMult = 1 + RebirthBonus
function Config.PowerOf(level, weaponTier, rebirthMult)
	return math.sqrt(Config.WeaponDamage(weaponTier, level) * Config.BaseHealth(level)) * (rebirthMult or 1)
end

-- S for a faction: weaker side = clamp(sqrt(enemy / ours), 1.0, 1.6); the stronger side naturally clamps to 1.0
function Config.SizeJustice(ourSum, enemySum)
	if ourSum <= 0 or enemySum <= 0 then return 1 end
	return math.clamp(math.sqrt(enemySum / ourSum), Config.Justice.MinScale, Config.Justice.MaxScale)
end

Config.Bully = {
	WeakPowerRatio = 0.5, -- (a) victim base power < 50% of the attacker's
	BaitWindow = 10, -- (a) does not apply if the victim damaged the attacker within the last 10 s
	WantedIgnoresWeakRule = true, -- (a) does not apply if the victim had Wanted stars or bully stacks (lead decision)
	FreshSpawnSeconds = 15, -- (b) victim respawned less than 15 s ago
	RepeatKOs = 3, -- (c) 3rd+ KO of the same victim by the same attacker...
	RepeatWindow = 600, -- ...within 10 minutes
	MaxStacks = 3,
	PerStack = 0.15, -- each stack: -15% visual size and -15% damage (multiplies with S)
	DecaySeconds = 300, -- one stack decays per 5 min without a new bully KO
	BountyMult = 2, -- bounty for KOing a bully is doubled
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
	HonorPerKOMin = 1, -- Halo KO of a 0-star, non-bully Horns gives 1 Honor
	CombatLogPenalty = 0.25, -- leaving while combat-tagged loses 25% of carried gold
	BoardRefresh = 5,
}

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
	RefundBonusCooldown = 600, -- ...the extra 20% only if this victim/thief pair had no refund in the last 10 min
	ReturnRate = 1.0, -- thief died without a Halo killer, or left the server: victims get 100% back
	RestealWindow = 180, -- the same thief stealing from the same victim again within 3 min steals 0
	AvengerBonus = 100, -- "복수 대행" bonus (minted, to the bank) for the Halo player who KO'd the thief
	Tick = 0.25,
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

-- Sky presets applied by WarService (Lighting + WarTint). Never add an Atmosphere or per-zone ColorCorrection (A9-3).
-- Neutral = A11 golden "Elden Ring" dusk (supersedes A9-4). Dawn/Eclipse keep their hues, darkened per A9-4
-- (Brightness x0.65, Ambient/OutdoorAmbient -40 per channel). Fog: FogStart 120 / FogEnd 650 for every gameplay preset
-- (A12, supersedes the 1600 of A11-R4) so distant regions vanish in haze; the sky crown stays visible as a silhouette.
-- Optional keys (WarService applies them only if present): FogStart, ExposureCompensation (Neutral only: A9-4 / A11),
-- BloomIntensity (Neutral only: A11).
Config.Sky = {
	TweenTime = 3,
	Neutral = { ClockTime = 16.8, Brightness = 1.8, Ambient = Color3.fromRGB(70, 60, 55), OutdoorAmbient = Color3.fromRGB(120, 105, 90), FogColor = Color3.fromRGB(190, 170, 140), FogStart = 120, FogEnd = 650, ExposureCompensation = -0.1, BloomIntensity = 0.4, Tint = Color3.fromRGB(255, 255, 255) },
	Dawn = { ClockTime = 7.2, Brightness = 1.95, Ambient = Color3.fromRGB(110, 90, 40), OutdoorAmbient = Color3.fromRGB(165, 135, 65), FogColor = Color3.fromRGB(255, 220, 150), FogStart = 120, FogEnd = 650, Tint = Color3.fromRGB(255, 240, 200) },
	Eclipse = { ClockTime = 0.5, Brightness = 0.78, Ambient = Color3.fromRGB(75, 5, 5), OutdoorAmbient = Color3.fromRGB(85, 5, 5), FogColor = Color3.fromRGB(90, 10, 20), FogStart = 120, FogEnd = 650, Tint = Color3.fromRGB(255, 185, 185) },
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
}

-- gold, xp of one golden-goose reward
function Config.GooseReward(level, factionId, won, rare)
	local g, x = Config.HuntValue(level, Config.Goose.RewardMinutes)
	local gm, xm = Config.Goose.MainShare, Config.Goose.OffShare -- Horns shape (gold-heavy)
	if factionId == "Halo" then gm, xm = Config.Goose.OffShare, Config.Goose.MainShare end -- XP-heavy
	local m = (won and 1 or Config.Goose.LoserShare) * (rare and Config.Goose.RareMult or 1)
	return math.floor(g * gm * m), math.floor(x * xm * m)
end

Config.Luck = { -- "단골 운"
	BaseRare = 0.05,
	PerActiveMinute = 0.0025, -- +0.25 percentage points per active minute on THIS server
	MaxRare = 0.125,
	MinuteSeconds = 60, -- a minute counts if the player had input/combat within it
}

function Config.RareChance(activeMinutes)
	return math.min(Config.Luck.MaxRare, Config.Luck.BaseRare + Config.Luck.PerActiveMinute * (activeMinutes or 0))
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
Config.ZoneOrder = { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "GoblinWoods", "SkeletonRuins" }
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
		if math.abs(pos.X - z.Center.X) <= z.Size.X / 2 and math.abs(pos.Z - z.Center.Z) <= z.Size.Z / 2 then
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
	Pads = { -- inside Crossroads; touching = instant Travel
		{ Dest = "SlimeMeadow", Position = Vector3.new(60, 0, -30) },
		{ Dest = "GoblinWoods", Position = Vector3.new(60, 0, 0) },
		{ Dest = "SkeletonRuins", Position = Vector3.new(60, 0, 30) },
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
	ZoneTick = 0.5, -- ZoneService polling interval
	Destinations = {
		{ Id = "Home", Name = "우리 진영 마을" }, -- resolves to Config.HomeZoneId(faction)
		{ Id = "Crossroads", Name = "교차로 마을" },
		{ Id = "SlimeMeadow", Name = "말랑 초원" },
		{ Id = "GoblinWoods", Name = "고블린 숲" },
		{ Id = "SkeletonRuins", Name = "해골 유적" },
	},
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
-- Personal (tutorial) monsters are excluded from these counts.
Config.MonsterDensity = { ExtraPerPlayer = 2, MaxZoneMult = 2, GlobalCap = 72, ReevalInterval = 5 }

-- addendum A7-1: on each (re)spawn of a non-personal monster, prefer a point 18-28 studs from the most "starved"
-- player in def.Zone (fewest monsters within 30 studs) when that player has fewer than StarvedThreshold nearby.
Config.SpawnSpread = { Enabled = true, StarvedThreshold = 2, MinDist = 18, MaxDist = 28, Tries = 6 }

Config.MonsterTypeOrder = { "Slime", "BigSlime", "Goblin", "GoblinBrute", "Skeleton", "SkeletonKnight" }
Config.MonsterTypes = {
	Slime = { Name = "조각먹은 슬라임", Zone = "SlimeMeadow", Count = 12, HP = 10, Damage = 2, XP = 5, Gold = 3, Speed = 10, Shape = "Slime", Scale = 1.0, Color = Color3.fromRGB(95, 205, 95) },
	BigSlime = { Name = "왕 슬라임", Zone = "SlimeMeadow", Count = 4, HP = 40, Damage = 4, XP = 18, Gold = 10, Speed = 9, Shape = "Slime", Scale = 1.8, Color = Color3.fromRGB(70, 160, 235) },
	Goblin = { Name = "조각 도둑 고블린", Zone = "GoblinWoods", Count = 10, HP = 90, Damage = 6, XP = 28, Gold = 16, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(110, 170, 70) },
	GoblinBrute = { Name = "고블린 우두머리", Zone = "GoblinWoods", Count = 4, HP = 260, Damage = 12, XP = 70, Gold = 40, Speed = 10, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(80, 120, 50) },
	Skeleton = { Name = "옛 왕국 해골 병사", Zone = "SkeletonRuins", Count = 8, HP = 450, Damage = 14, XP = 65, Gold = 65, Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = Color3.fromRGB(235, 235, 220) },
	SkeletonKnight = { Name = "왕관을 지키던 해골 기사", Zone = "SkeletonRuins", Count = 4, HP = 1300, Damage = 24, XP = 170, Gold = 170, Speed = 11, Shape = "Humanoid", Scale = 1.5, Color = Color3.fromRGB(120, 120, 140) },
}

-- the "unit" monster used for quest targets / rewards and Config.HuntValue
Config.ZoneMainMonster = { SlimeMeadow = "Slime", GoblinWoods = "Goblin", SkeletonRuins = "Skeleton" }

function Config.QuestZoneForLevel(level)
	if level >= Config.Zones.SkeletonRuins.MinLevel then return "SkeletonRuins" end
	if level >= Config.Zones.GoblinWoods.MinLevel then return "GoblinWoods" end
	return "SlimeMeadow"
end

----------------------------------------------------------------- first-60-seconds onboarding (addendum A4 / A5)
-- TutorialStep transitions are owned by QuestService. Step 0: personal golden slime ~8 studs in front of the spawn
-- (MonsterService.SpawnPersonal(player, Monster, { Golden = true, HP = MonsterHP })); kill or timeout -> step 1.
-- Step 1: HUD guide beam to the GuideZone pad/entrance; entering GuideZone -> step 2. Step 2: pinned quest
-- (first QuestsJson entry, Id = QuestId, Pinned = true, Slot = nil); claim -> step 99.
Config.Tutorial = {
	Steps = { Kill = 0, Guide = 1, Quest = 2, Done = 99 },
	Monster = "Slime",
	MonsterHP = 10,
	Golden = true,
	SpawnDistance = 8, -- studs in front of the player's spawn
	Lifetime = 120, -- personal monster despawns after this many seconds (then the tutorial advances to step 1)
	GuideZone = "SlimeMeadow",
	GuideText = "여기로!", -- plain
	QuestId = "tutorial",
	QuestKills = 5,
	QuestText = "말랑 슬라임 %d마리 잡기", -- string.format(QuestText, QuestKills)
	QuestRewardGold = 120, -- with starting gold enough for the 2nd weapon tier in ~60 s
	QuestRewardXP = 0,
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
	-- Every DAILY pays Config.DailyQuestReward(level at generation) regardless of template.
	Templates = {
		{ Id = "Kill", Weight = 40, Units = { 25, 40 }, DailyUnits = { 50, 60 }, RewardPerUnit = 1.0,
			Text = "몬스터 %d마리 쓰러뜨려 조각 모으기" },
		{ Id = "Golden", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 30,
			Text = "황금 몬스터 %d마리 처치" },
		{ Id = "Gold", Weight = 20, Units = { 40, 60 }, DailyUnits = { 50, 60 }, RewardPerUnit = 0.5,
			Text = "사냥으로 골드 %s 벌기" },
		{ Id = "Release", Weight = 20, Units = { 2, 3 }, DailyUnits = { 3 }, RewardPerUnit = 8, MinStacks = 50,
			Text = "게이지 50 이상으로 %d번 발사하기" },
		{ Id = "Goose", Weight = 10, Units = { 1 }, DailyUnits = { 1 }, RewardPerUnit = 20,
			Text = "황금 거위 줄다리기 %d번 참여" },
		{ Id = "Hunt", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Halo", PvP = true,
			Text = "현상수배범 %d명 잡기 (괴수 토벌 포함)" },
		{ Id = "Plunder", Weight = 12, Units = { 1, 2 }, DailyUnits = { 1 }, RewardPerUnit = 40, Faction = "Horns", PvP = true,
			Text = "빛의 기사단 %d명 털기" },
	},
}

Config.Daily = {
	TimezoneOffset = 9 * 3600, -- KST: the day flips at 00:00 Korea time
	QuestMinutes = 5, -- each daily pays HuntValue(level, 5)
	ChestMinutes = 10, -- claiming all 3 dailies pays a bonus chest of HuntValue(level, 10)
	ChestTicketChance = 0.10, -- the chest also drops 1 class change ticket with this chance
	VacationRate = 0.7, -- per missed whole day: 70% of a full day (3 dailies + chest) at the CURRENT level
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

function Config.VacationReward(level, days) -- gold, xp for `days` missed days (clamped)
	local d = math.clamp(days or 0, 0, Config.Daily.VacationMaxDays)
	local g, x = Config.HuntValue(level, Config.Daily.QuestMinutes * Config.Quests.Slots + Config.Daily.ChestMinutes)
	return math.floor(g * Config.Daily.VacationRate * d), math.floor(x * Config.Daily.VacationRate * d)
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
	ChooseFaction = 1, ChooseClass = 1, Swing = 0.1, Release = 0.25, SetAutoAttack = 0.25,
	UpgradeWeapon = 0.3, Rebirth = 1, SwitchFaction = 1, ChangeClass = 1, Travel = 0.5,
	RerollQuest = 0.5, ClaimQuest = 0.3, ClaimVacation = 1,
}

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
		PanelParchment = { Id = "rbxassetid://72205434910489", Size = Vector2.new(512, 327), Slice = Rect.new(22, 23, 490, 300), SliceScale = 0.5, Tone = "Parchment" },
		PanelCard = { Id = "rbxassetid://136335526027749", Size = Vector2.new(512, 233), Slice = Rect.new(39, 40, 472, 193), SliceScale = 0.35, Tone = "Navy", Inner = Rect.new(27, 35, 484, 197) },
		RibbonHeader = { Id = "rbxassetid://139030670576287", Size = Vector2.new(512, 124), Slice = Rect.new(42, 21, 470, 104), FitHeight = true, Tone = "Ribbon" },
		Pill = { Id = "rbxassetid://104493989064174", Size = Vector2.new(512, 120), Slice = Rect.new(41, 23, 472, 98), FitHeight = true, Tone = "Parchment" },
		BarTrack = { Id = "rbxassetid://83211717779640", Size = Vector2.new(512, 94), Slice = Rect.new(45, 20, 466, 73), FitHeight = true, Tone = "NavyDeep", Inner = Rect.new(20, 17, 492, 76) },
		BtnSquare = { Id = "rbxassetid://139680959679196", Size = Vector2.new(512, 491), Slice = Rect.new(94, 34, 416, 392), SliceScale = 0.22, Tone = "Parchment" },
		-- round buttons / rings (Fit)
		BtnAttack = { Id = "rbxassetid://132704332440668", Size = Vector2.new(509, 512), Round = true, Tone = "Red", Inner = Rect.new(53, 56, 456, 444) },
		BtnSpecial = { Id = "rbxassetid://109104625287455", Size = Vector2.new(512, 504), Round = true, Tone = "Gold", Inner = Rect.new(55, 50, 458, 454) },
		LevelBadge = { Id = "rbxassetid://119498869874355", Size = Vector2.new(512, 511), Round = true, Tone = "Navy", Inner = Rect.new(89, 93, 422, 405) },
		PortraitRing = { Id = "rbxassetid://79459292166016", Size = Vector2.new(498, 512), Round = true, Tone = "Navy", Inner = Rect.new(70, 102, 427, 445) },
		-- emblems
		ShieldHalo = { Id = "rbxassetid://75337774918722", Size = Vector2.new(490, 512) },
		ShieldHorns = { Id = "rbxassetid://86370929061230", Size = Vector2.new(497, 512) },
		Crown = { Id = "rbxassetid://119142490435797", Size = Vector2.new(256, 175) },
		-- icons
		IconCoin = { Id = "rbxassetid://94164695982355", Size = Vector2.new(254, 256) },
		IconPouch = { Id = "rbxassetid://140252516996220", Size = Vector2.new(256, 249) },
		IconSword = { Id = "rbxassetid://72547608031298", Size = Vector2.new(255, 256) }, -- wooden sword (next weapon)
		IconAttack = { Id = "rbxassetid://108907022902105", Size = Vector2.new(256, 253) }, -- silver sword (attack button)
		IconSpecial = { Id = "rbxassetid://85317688210710", Size = Vector2.new(256, 146) }, -- winged gold star (발사)
		IconLock = { Id = "rbxassetid://139055212938008", Size = Vector2.new(246, 256) },
		IconMap = { Id = "rbxassetid://138000833306308", Size = Vector2.new(256, 202) },
		IconGear = { Id = "rbxassetid://125495221925556", Size = Vector2.new(247, 256) },
		IconGoose = { Id = "rbxassetid://75561315472577", Size = Vector2.new(218, 256) },
		IconSafe = { Id = "rbxassetid://79507893882404", Size = Vector2.new(254, 256) }, -- green shield
		IconSprout = { Id = "rbxassetid://113278909940414", Size = Vector2.new(256, 254) },
		IconStar = { Id = "rbxassetid://119757093512057", Size = Vector2.new(256, 243) },
		IconStarEmpty = { Id = "rbxassetid://105701738413323", Size = Vector2.new(256, 255) },
		IconClover = { Id = "rbxassetid://130220802039072", Size = Vector2.new(246, 256) },
		IconScroll = { Id = "rbxassetid://104306436967552", Size = Vector2.new(256, 192) },
		IconSlime = { Id = "rbxassetid://132864964926977", Size = Vector2.new(256, 245) },
		-- pick screens (mockups art/out/UI_Faction_B.png, UI_Class_A.png): text-free card backgrounds, regions in CardLayout
		CardHalo = { Id = "rbxassetid://127968705264649", Size = Vector2.new(635, 1024) },
		CardHorns = { Id = "rbxassetid://118772199487027", Size = Vector2.new(617, 1024) },
		CardNeutral = { Id = "rbxassetid://91054727125376", Size = Vector2.new(612, 1024) },
		ClassCardHalo = { Id = "rbxassetid://106511467901627", Size = Vector2.new(647, 1024) },
		ClassCardHorns = { Id = "rbxassetid://88897242529915", Size = Vector2.new(608, 1024) },
		ClassCardNeutral = { Id = "rbxassetid://111415926358171", Size = Vector2.new(618, 1024) },
		ShieldNeutral = { Id = "rbxassetid://108855002367843", Size = Vector2.new(251, 256) },
		TitleRibbon = { Id = "rbxassetid://105521181481849", Size = Vector2.new(256, 63) }, -- empty title ribbon
		-- class characters (transparent chibi): Char<Faction><Class><M|F>
		CharHaloWarriorM = { Id = "rbxassetid://91124975552923", Size = Vector2.new(420, 512) },
		CharHaloWarriorF = { Id = "rbxassetid://112844299339258", Size = Vector2.new(464, 512) },
		CharHaloMageM = { Id = "rbxassetid://132965528745270", Size = Vector2.new(460, 512) },
		CharHaloMageF = { Id = "rbxassetid://114828753943727", Size = Vector2.new(478, 512) },
		CharHaloArcherM = { Id = "rbxassetid://122481808871259", Size = Vector2.new(501, 512) },
		CharHaloArcherF = { Id = "rbxassetid://124348927719351", Size = Vector2.new(504, 512) },
		CharHornsWarriorM = { Id = "rbxassetid://123139571964542", Size = Vector2.new(489, 512) },
		CharHornsWarriorF = { Id = "rbxassetid://125995393023187", Size = Vector2.new(473, 512) },
		CharHornsMageM = { Id = "rbxassetid://96352144576106", Size = Vector2.new(478, 512) },
		CharHornsMageF = { Id = "rbxassetid://77910369681201", Size = Vector2.new(496, 512) },
		CharHornsArcherM = { Id = "rbxassetid://105137475844346", Size = Vector2.new(467, 512) },
		CharHornsArcherF = { Id = "rbxassetid://100148164488141", Size = Vector2.new(467, 512) },
		CharNeutralWarriorM = { Id = "rbxassetid://74407898891261", Size = Vector2.new(485, 512) },
		CharNeutralWarriorF = { Id = "rbxassetid://120947459158861", Size = Vector2.new(476, 512) },
		CharNeutralMageM = { Id = "rbxassetid://102550410777063", Size = Vector2.new(465, 512) },
		CharNeutralMageF = { Id = "rbxassetid://82933568473532", Size = Vector2.new(457, 512) },
		CharNeutralArcherM = { Id = "rbxassetid://127668674323208", Size = Vector2.new(416, 512) },
		CharNeutralArcherF = { Id = "rbxassetid://103757200729319", Size = Vector2.new(463, 512) },
		-- perk / misc icons
		IconExp = { Id = "rbxassetid://71570492311980", Size = Vector2.new(229, 256) },
		IconHeart = { Id = "rbxassetid://117251570083495", Size = Vector2.new(256, 222) },
		IconWings = { Id = "rbxassetid://100448040477725", Size = Vector2.new(256, 166) },
		IconGoldPile = { Id = "rbxassetid://121580818331312", Size = Vector2.new(256, 166) },
		IconBloodSword = { Id = "rbxassetid://89539033522501", Size = Vector2.new(256, 239) },
		IconGauge = { Id = "rbxassetid://105265456701675", Size = Vector2.new(256, 70) },
		IconDemon = { Id = "rbxassetid://138771309720551", Size = Vector2.new(256, 231) },
		IconNoBuff = { Id = "rbxassetid://110309392433326", Size = Vector2.new(256, 243) },
		IconShieldBlue = { Id = "rbxassetid://98551767326821", Size = Vector2.new(227, 256) },
		IconNoLoot = { Id = "rbxassetid://106989595509471", Size = Vector2.new(243, 256) },
		IconHammer = { Id = "rbxassetid://74147674132543", Size = Vector2.new(236, 256) },
		IconAltar = { Id = "rbxassetid://112545534083025", Size = Vector2.new(241, 256) },
		IconBoot = { Id = "rbxassetid://118619367792480", Size = Vector2.new(256, 232) },
	},
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
		Red = Color3.fromRGB(225, 40, 36), -- attack button face
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
Config.UIArt.FactionPerks = {
	Halo = {
		{ Icon = "IconExp", Text = "경험치 +30%" },
		{ Icon = "IconHeart", Text = "체력 +20%, 계속 회복" },
		{ Icon = "IconWings", Text = "발사하면 동료 치유" },
		{ Icon = "IconGoldPile", Text = "주머니 골드 자동 저금" },
	},
	Horns = {
		{ Icon = "IconGoldPile", Text = "골드 +25%" },
		{ Icon = "IconBloodSword", Text = "공격력 +15%, 체력 흡수" },
		{ Icon = "IconGauge", Text = "발사 게이지 175" },
		{ Icon = "IconDemon", Text = "별 5개면 괴수 변신!" },
	},
	Neutral = {
		{ Icon = "IconNoBuff", Text = "싸움 버프 없음" },
		{ Icon = "IconShieldBlue", Text = "PvP 없음 (안전)" },
		{ Icon = "IconNoLoot", Text = "약탈·현상수배 걱정 없음" },
		{ Icon = "IconHammer", Text = "제작 특화 (곧 추가)" },
	},
}

-- addendum A1: optional custom visual models in ServerStorage[FolderName] named by monster id or GooseId
Config.CustomModels = {
	FolderName = "CustomModels",
	GooseId = "GoldenGoose",
	GoldenFillTransparency = 0.5, -- golden variant: gold Highlight instead of recoloring parts
}

----------------------------------------------------------------- story ("세계관": flavor text only)
Config.Story = {
	-- plain lines (no format specifiers)
	Premise = {
		"세상을 지키던 균형의 왕관이 부서졌다.",
		"조각을 주운 자들 중 누구는 머리 위에 후광이, 누구는 뿔이 돋았다.",
		"조각을 더 많이 모으는 쪽이 세상을 다시 만든다.",
	},
	Intro = { -- one-time toasts right after the first class choice (auto-dismiss, never blocking)
		"몬스터를 때리면 왕관 조각의 힘이 모여요! (공격 버튼)",
		"발사 게이지가 꽉 차서 금빛 고리가 빛나면 바로 [발사]!",
		"10분마다 왕관의 주인이 바뀌어요. 우리 편을 도와주세요!",
	},
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
	KaijuSiren = "경보! %s이(가) 왕관 조각의 어둠에 삼켜지고 있어요! 10초 뒤 괴수가 돼요!",
	KaijuStart = "괴수 %s 출현! 기사단은 어디서든 공격할 수 있어요!",
	KaijuDefeated = "기사단이 괴수 %s을(를) 쓰러뜨렸어요! 보상 %s골드를 나눠 가져요.",
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
	EnteredSafe = "안전 지대예요.",
	Banked = "골드 %s을(를) 금고에 넣었어요.",
	HaloCourier = "천사 배달부가 골드 %s을(를) 금고에 넣었어요.",
	LevelUp = "레벨 업! Lv %d",
	NotEnoughGold = "골드가 부족해요.",
	WeaponBought = "%s 장착!",
	WeaponMaxed = "이미 최고의 무기예요!",
	WeaponNeedLevel = "이 무기는 레벨 %d부터 쓸 수 있어요.",
	NeedFaction = "먼저 진영을 골라야 해요.",
	AutoLocked = "자동 공격은 레벨 %d부터 쓸 수 있어요.",
	ReleaseNeed = "게이지가 %d 이상이어야 발사할 수 있어요.",
	-- PvP
	Plundered = "%s에게 골드 %s을(를) 빼앗겼어요! 기사단이 45초 안에 도둑을 잡으면 120%%로 돌아와요.",
	PlunderGain = "골드 %s을(를) 원한 자루에 담았어요! PvP 지역에서 45초 버티면 내 것! (현상수배 별 %d개)",
	PlunderTooSoon = "방금 턴 상대예요. 3분 동안은 또 털 수 없어요.",
	HonorGain = "명예 +%d",
	BountyGain = "현상금 %s골드 획득! 명예 +%d",
	BountyAnnounce = "[빛의 기사단] %s님이 현상금 %s골드를 받았어요!",
	BullyBountyGain = "깡패 현상금 %s골드 획득!",
	MostWanted = "%s이(가) 최고 현상수배범이 되었어요! 현상금 %s골드",
	BullyKO = "깡패 처치! 보상 없음, 덩치·공격력 -15%% (깡패 %d단계)",
	BullyVictim = "깡패에게 당했어요. 잃은 건 없어요!",
	BullyDecay = "깡패 단계가 줄었어요 (%d단계)",
	Revenge = "%s에게 복수하세요! 90초 동안 공격력 +25%%",
	RevengeDone = "복수 성공!",
	-- grudge sack
	SackPaid = "원한 자루를 지켜냈어요! 골드 %s 획득",
	SackLost = "원한 자루를 빼앗겼어요!",
	GrudgeRefund = "%s님이 원한 자루를 되찾아 줬어요! 골드 %s이(가) 금고로!",
	GrudgeReturned = "도둑이 쓰러져서 빼앗긴 골드 %s이(가) 금고로 돌아왔어요.",
	AvengerBonus = "복수 대행 보너스 +%s골드!",
	GrudgeAvengedAll = "%s님이 %s의 원한 자루를 되찾았어요!",
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
	-- faction / class / tickets
	UnderdogSignOn = "약한 편 합류 보너스 +%d골드!",
	SwitchDoneFree = "%s(으)로 진영을 바꿨어요! (배신의 대가: %s 0)",
	SwitchDoneTicket = "%s(으)로 진영을 바꿨어요! (변경권 사용, 점수 유지)",
	SwitchCooldown = "진영 변경은 %s 후에 가능해요.",
	NoTicket = "변경권이 없어요. 메뉴 > 변경권 상점에서 살 수 있어요.",
	ClassChosen = "%s이(가) 되었어요!",
	ClassChangedFree = "%s(으)로 직업을 바꿨어요! 레벨 1부터 다시 시작해요.",
	ClassChangedTicket = "%s(으)로 직업을 바꿨어요! (변경권 사용, 레벨 유지)",
	ClassSame = "이미 그 직업이에요.",
	ClassNeedSafe = "직업은 안전 지대에서만 바꿀 수 있어요.",
	ClassTicketGot = "직업 변경권 1장을 받았어요!",
	FactionTicketGot = "진영 변경권 1장을 받았어요!",
	ProductNotReady = "상품 준비 중이에요.",
	-- rebirth
	RebirthNeed = "환생하려면 레벨 %d이(가) 필요해요.",
	RebirthDone = "환생 완료! 골드·경험치 영구 +%d%%",
	RebirthAnnounce = "%s님이 %d번째 환생을 했어요!",
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
	RareAnnounce = "%s님이 황금 거위 희귀 보상을 받았어요!",
	-- kaiju
	KaijuQueued = "다른 괴수가 있어요. 그 괴수가 끝나면 변신해요!",
	KaijuReward = "괴수 토벌 보상 +%s골드!",
	KaijuSurviveReward = "살아남았다! 주머니 골드 ×1.5 = %s골드가 금고로!",
	-- addendum A3 (review fixes)
	AutoUnderAttack = "공격받는 중! 공격 버튼으로 반격하세요", -- M3: auto ON + took PvP damage (once per 60 s)
	EnemyTown = "상대 진영 마을에는 들어갈 수 없어요!", -- L1: bounced to Crossroads (also Neutral in either town)
	-- addendum A7-3 (next goal, client)
	LevelUpNext = "레벨 업! Lv %d · 다음 해금: Lv %d %s", -- (level, unlockLevel, unlockText)
	Unlocked = "해금! %s", -- (unlockText)
	KillsToAfford = "%s %d마리 더!", -- (monsterName, kills)
	CanAfford = "%s 살 수 있어요!", -- (weaponName)
	Recommended = "추천", -- Travel panel badge
	-- addendum A7-4 (pick / change screens, client)
	FirstTimeRecommend = "처음이면 추천", -- Warrior class card
	ChangeFree = "무료로 바꾸기",
	ChangeTicket = "티켓으로 바꾸기 (보유 %d장)", -- (tickets)
	LossScore = "%s %s 초기화", -- ("명예" | "악명", Util.FormatNumber(score)) e.g. "명예 340 초기화"
	LossLevel = "Lv %d → Lv 1", -- (current level)
	KeepAll = "전부 유지",
}

return Config
