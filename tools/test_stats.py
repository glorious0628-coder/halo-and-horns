"""A23-69 stat points, stage 1 (docs/design/stat_points_2026-10-07.md §1-§3, §5-1, §7-3), offline.

Stage 1 puts the stat points in with the switch Config.Features.StatPoints OFF: the Config.Stats table and its helpers
(StatBonus / StatPoints / StatAlloc / StatMults / StatAllocOf / SanitizeStats), the additive save field Stats = { Auto,
Order } (검수 2026-10-07: the save version stays 3),
and one power formula, Config.CombatPowerOf, behind JusticeService (the CombatPower attribute, the bully rule, boldness),
PvPService's fallback, the Tab list column and LootService's "Power X -> Y". Runs the CURRENT Config and Util plus
chunks cut from DataService (migrate / fillDefaults), JusticeService (levelAndTier .. POWER), PvPService (combatPower),
PlayerService (the leaderstats section) and LootService (equipIfBare) with the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_stats.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_stats_2026-10-07.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
    "JUSTICE_SOURCE": SSS / "JusticeService.luau",
    "PVP_SOURCE": SSS / "PvPService.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
}
C, D, J, P, PS, L = "CONFIG_SOURCE", "DATA_SOURCE", "JUSTICE_SOURCE", "PVP_SOURCE", "PLAYER_SOURCE", "LOOT_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE")}
    data = sources[D]
    out["DATA_EXTRACT"] = (
        "local Config, Util, TAG, TUTORIAL_DONE = ...\n"
        + function_block(data, "local function migrate(")
        + function_block(data, "local function fillDefaults(")
        + "\nreturn { Migrate = migrate, Fill = fillDefaults }\n")
    justice = between(sources[J], "local function levelAndTier(", "-- 1 for \"None\"")
    out["JUSTICE_EXTRACT"] = ("local Config = ...\nlocal JusticeService = {}\n" + justice
                              + "\nreturn { J = JusticeService, POWER = POWER }\n")
    pvp = sources[P]
    out["PVP_EXTRACT"] = (
        "local Config = ...\nlocal S = nil\n" + function_block(pvp, "local function num(p, key, default)") + "\n"
        + function_block(pvp, "local function combatPower(p)")
        + "\nreturn { combatPower = function(p, registry) S = registry; return combatPower(p) end }\n")
    player = sources[PS]
    keys = re.search(r"^local LEADERSTAT_KEYS = \{.*?\}\n", player, re.M | re.S)
    if not keys:
        raise ValueError("Source boundary changed: PlayerService LEADERSTAT_KEYS; update the test extractor.")
    out["COLUMN_EXTRACT"] = (
        "local Config, Util, addConn = ...\nlocal TAG = \"PlayerService\"\n" + keys.group(0)
        + between(player, "------------------------------------------------------------------ leaderstats",
                  "------------------------------------------------------------------ character lifecycle")
        + "\nreturn COLUMN\n")
    loot = sources[L]
    out["LOOT_EXTRACT"] = (
        "local Config, S, Net, publish, LOOT = ...\n"
        + function_block(loot, "local function num(v, default)")
        + function_block(loot, "local function enhanceOf(data, tier)")
        + function_block(loot, "local function equipIfBare(player, data, tier)")
        + "\nreturn equipIfBare\n")
    return out


MUTATIONS = [
    # --- Config.Stats and the helpers
    ("Config: no 0.5% step", C, "Curve = { { 20, 0.01 }, { 40, 0.005 }, { math.huge, 0.0025 } },",
     "Curve = { { 20, 0.01 }, { math.huge, 0.0025 } },"),
    ("Config: Archer's pattern like the others", C, "AutoPattern = { Warrior = \"HA\", Mage = \"HA\", Archer = \"AH\" },",
     "AutoPattern = { Warrior = \"HA\", Mage = \"HA\", Archer = \"HA\" },"),
    ("Config: a third letter", C, "Letters = { A = true, H = true },", "Letters = { A = true, H = true, C = true },"),
    ("Config: Auto off for a new save", C, "\t\tStats = { Auto = true, Order = \"\" },\n", "\t\tStats = { Auto = false, Order = \"\" },\n"),
    ("Config: the switch on", C, "Market = false, StatPoints = false }", "Market = false, StatPoints = true }"),
    ("Config: the save version back to 3 (C1 made it 4)", C, "Spares / Market (save_v4_tables_2026-10-11.md).\n\tVersion = 4,\n",
     "Spares / Market (save_v4_tables_2026-10-11.md).\n\tVersion = 3,\n"),
    ("SanitizeStats: only the known letters (the old rule)", C, "\t\tif string.match(ch, \"^%u$\") then table.insert(kept, ch) end\n",
     "\t\tif Config.Stats.Letters[ch] then table.insert(kept, ch) end\n"),
    ("SanitizeStats: lowercase kept", C, "\t\tif string.match(ch, \"^%u$\") then table.insert(kept, ch) end\n",
     "\t\tif string.match(ch, \"^%a$\") then table.insert(kept, ch) end\n"),
    ("StatBonus without a cap", C, "local r = math.clamp(math.floor(tonumber(points) or 0), 0, Config.Stats.MaxPoints)",
     "local r = math.max(0, math.floor(tonumber(points) or 0))"),
    ("StatBonus: NaN not caught", C, "\tif r ~= r then return 0 end\n\tlocal bonus, from = 0, 0\n", "\tlocal bonus, from = 0, 0\n"),
    ("StatBonus: the next step starts at 0", C, "\t\tfrom = step[1]\n", ""),
    ("StatPoints from Lv1", C, "return math.clamp(lv - 1, 0, Config.Stats.MaxPoints)", "return math.clamp(lv, 0, Config.Stats.MaxPoints)"),
    ("StatPoints without the cap", C, "return math.clamp(lv - 1, 0, Config.Stats.MaxPoints)", "return math.max(lv - 1, 0)"),
    ("auto ignores the class", C, "local pattern = Config.Stats.AutoPattern[classId] or Config.Stats.AutoPattern.Warrior",
     "local pattern = Config.Stats.AutoPattern.Warrior"),
    ("by hand counts the whole Order", C,
     "letters = string.sub(type(stats.Order) == \"string\" and stats.Order or \"\", 1, points)",
     "letters = type(stats.Order) == \"string\" and stats.Order or \"\""),
    ("Auto off ignored", C, "if type(stats) ~= \"table\" or stats.Auto ~= false then", "if true then"),
    ("free points never counted", C, "\treturn a, h, points - (a + h)\nend", "\treturn a, h, 0\nend"),
    ("StatMults ignores the switch", C, "\tif not Config.FeatureOn(\"StatPoints\") then return 1, 1 end\n", ""),
    ("StatMults: Health from the Attack points", C, "return 1 + Config.StatBonus(a), 1 + Config.StatBonus(h)",
     "return 1 + Config.StatBonus(a), 1 + Config.StatBonus(a)"),
    ("StatAllocOf without a cap", C,
     "return { A = math.clamp(math.floor(a), 0, Config.Stats.MaxPoints), H = math.clamp(math.floor(h), 0, Config.Stats.MaxPoints) }",
     "return { A = math.floor(a), H = math.floor(h) }"),
    ("StatAllocOf: NaN kept", C, "\tif a ~= a then a = 0 end\n", ""),
    ("SanitizeStats keeps every character", C, "\t\tif string.match(ch, \"^%u$\") then table.insert(kept, ch) end\n",
     "\t\ttable.insert(kept, ch)\n"),
    ("SanitizeStats: no length cap", C, "\t\tif #kept >= Config.Stats.MaxPoints then break end\n", ""),
    ("SanitizeStats loses Auto off", C, "\tif type(src.Auto) == \"boolean\" then auto = src.Auto end\n", ""),
    # (no 'a number Order' mutation: a number or table has no A / H letters, so tostring() gives the same "": equivalent)
    ("SanitizeStats reads the whole of a huge Order", C, "\tfor i = 1, math.min(#order, 4096) do\n", "\tfor i = 1, #order do\n"),
    # --- the power formula
    ("PowerOf ignores the stats", C, "\tif type(alloc) == \"table\" then am, hm = Config.StatMults(alloc.A, alloc.H) end\n", ""),
    ("PowerOf: the stats outside the square root", C,
     "return math.sqrt(Config.WeaponDamage(weaponTier, level, enhance) * am * Config.BaseHealth(level) * hm) * (rebirthMult or 1)",
     "return math.sqrt(Config.WeaponDamage(weaponTier, level, enhance) * Config.BaseHealth(level)) * am * hm * (rebirthMult or 1)"),
    ("CombatPower drops the stats", C, "\tlocal raw = Config.PowerOf(level, tier, 1, enhance, alloc)\n",
     "\tlocal raw = Config.PowerOf(level, tier, 1, enhance)\n"),
    ("CombatPowerOf ignores the stats", C,
     "return Config.CombatPower(math.max(1, level), tier, enhance, Config.StatAllocOf(player))",
     "return Config.CombatPower(math.max(1, level), tier, enhance)"),
    ("CombatPowerOf ignores the weapon override", C, "\tlocal tier = tierOverride\n", "\tlocal tier = nil\n"),
    ("CombatPowerOf ignores the +N override", C, "\tlocal enhance = enhOverride\n", "\tlocal enhance = nil\n"),
    ("CombatPowerOf: an unclamped tier", C,
     "\t\ttier = math.clamp(math.floor(tier), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands\n", "\t\ttier = math.floor(tier)\n"),
    ("MaxCombatPower ignores the stats", C,
     "local even = stats and { A = math.floor(points / 2), H = points - math.floor(points / 2) } or nil", "local even = nil"),
    ("MaxCombatPower: a one-stat build", C, "{ A = math.floor(points / 2), H = points - math.floor(points / 2) }",
     "{ A = points, H = 0 }"),
    ("MaxCombatPower: one cache for both", C, "local key = stats and \"MaxCacheStats\" or \"MaxCache\"", "local key = \"MaxCache\""),
    # --- the save: Stats additive (검수 2026-10-07); C1's v4 step changes nothing else
    ("DataService: the v4 step resets Stats", D, "\tif (tonumber(d.Version) or 1) < 4 then\n\t\td.Version = 4\n",
     "\tif (tonumber(d.Version) or 1) < 4 then\n\t\td.Stats = nil\n\t\td.Version = 4\n"),
    ("DataService: Stats never repaired", D, "\tif Config.SanitizeStats then d.Stats = Config.SanitizeStats(d.Stats) end\n", ""),
    # --- one formula everywhere
    ("Justice: the attribute without the stats", J, "\treturn Config.CombatPowerOf(player)\nend",
     "\tlocal level, tier, enhance = levelAndTier(player)\n\treturn Config.CombatPower(level, tier, enhance)\nend"),
    ("Justice: the faction sum without the stats", J, "1 + rebirthBonus, enhance, Config.StatAllocOf(player))",
     "1 + rebirthBonus, enhance)"),
    ("Justice: the faction sum clamps bare hands to tier 1", J,
     "or 0), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands", "or 1), 1, Config.MaxWeaponTier) -- A23-34: 0 = bare hands"),
    ("Justice: StatAtk not watched", J, "\"WeaponEnhance\", \"StatAtk\", \"StatHp\" }", "\"WeaponEnhance\", \"StatHp\" }"),
    ("Justice: StatHp not watched", J, "\"WeaponEnhance\", \"StatAtk\", \"StatHp\" }", "\"WeaponEnhance\", \"StatAtk\" }"),
    ("PvP fallback without the stats", P, "\treturn Config.CombatPowerOf(p)\nend",
     "\treturn Config.CombatPower(math.max(1, num(p, \"Level\", 1)), math.clamp(math.floor(num(p, \"WeaponTier\", 0)), 0, "
     "Config.MaxWeaponTier), tonumber(p:GetAttribute(\"WeaponEnhance\")) or 0)\nend"),
    ("Tab column without the stats", PS, "v = Config.CombatPowerOf(p) -- A23-69",
     "v = Config.CombatPower(math.max(1, toInt(p:GetAttribute(\"Level\"))), math.clamp(toInt(p:GetAttribute(\"WeaponTier\")), 0, "
     "Config.MaxWeaponTier), toInt(p:GetAttribute(\"WeaponEnhance\"))) -- A23-69"),
    ("Loot 'Power X -> Y' without the stats", L,
     "return Config.CombatPowerOf(player, 0, 0), Config.CombatPowerOf(player, tier, enhanceOf(data, tier))",
     "return Config.CombatPower(level, 0, 0), Config.CombatPower(level, tier, enhanceOf(data, tier))"),
    ("Loot 'Power X -> Y' before = the new weapon", L,
     "return Config.CombatPowerOf(player, 0, 0), Config.CombatPowerOf(player, tier, enhanceOf(data, tier))",
     "return Config.CombatPowerOf(player, tier, 0), Config.CombatPowerOf(player, tier, enhanceOf(data, tier))"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    users = {}
    for path in sorted((ROOT / "src").rglob("*.luau")):
        rel = path.relative_to(ROOT).as_posix()
        code = strip_comments(read(path))
        if "Config.CombatPower(" in code and not rel.endswith("Shared/Config.luau"):
            users[rel] = code.count("Config.CombatPower(")
    check(set(users) <= {"src/StarterPlayer/StarterPlayerScripts/HUD.luau"},
          f"every server power number goes through Config.CombatPowerOf (Config.CombatPower used directly in {sorted(users)})")
    for name in ("JusticeService", "PvPService", "PlayerService", "LootService"):
        check("Config.CombatPowerOf(" in strip_comments(read(SSS / f"{name}.luau")), f"{name} uses Config.CombatPowerOf")
    justice = read(SSS / "JusticeService.luau")
    watch = function_block(justice, "function POWER.Watch(")
    check('"StatAtk"' in watch and '"StatHp"' in watch, "the CombatPower attribute follows StatAtk / StatHp")
    money = strip_comments(read(SSS / "MonetizationService.luau"))
    check(not re.search(r"Stat(s|Points|Atk|Hp|Alloc|Mults)\b", money) and "SanitizeStats" not in money,
          "no Robux path touches the stat points (A23-69: no stat is sold)")
    data = read(SSS / "DataService.luau")
    mig = function_block(data, "local function migrate(")
    check(mig.count("< 4 then") == 1 and "< 4 then\n\t\td.Version = 4\n\tend\n" in mig and "Stats" not in strip_comments(mig)
          and "Config.SanitizeStats" in function_block(data, "local function fillDefaults("),
          "DataService: migrate's only v4 step is C1's (sets Version only; Stats is additive), SanitizeStats in fillDefaults")
    config = read(SHARED / "Config.luau")
    mirrored = re.search(r"\tMirrored = \{(.*?)\n\t\}", config, re.S)
    check(bool(mirrored) and not re.search(r'"Stat', mirrored.group(1)),
          "the stat attributes are not mirrored (StatService writes them; Stats is a table)")
    return count, failures


SUITE = Suite(
    mark="STATS",
    fixture=ROOT / "tools/fixtures/stats_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_stats_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-69 stage 1 (switch Config.Features.StatPoints OFF): Config.Stats { MaxPoints 99, Letters A / H, Curve "
             "1% to 20 / 0.5% to 40 / 0.25% after, AutoPattern Warrior HA / Mage HA / Archer AH }; StatPoints(L) = L - 1 "
             "(0..99, no points from rebirths); StatAlloc = the class pattern (Auto) or Order's first points (by hand, the "
             "rest free; a level reset keeps Order); StatMults = (1, 1) while off; SanitizeStats (boolean Auto, letters "
             "A-Z kept for later stats, the rest dropped, at most 99); PowerOf / CombatPower take alloc { A, H } (sqrt of attack x health with both mults); "
             "MaxCombatPower 37,805 off / 50,044 on (C1: the Mythic tier 9; tier 7 alone 25,488 / 33,740; the even split), cached apart; Config.CombatPowerOf(player, tier?, "
             "+N?) reads Level / WeaponTier / WeaponEnhance / StatAtk / StatHp and is the one formula of JusticeService "
             "(GetCombatPower, GetPower with the rebirth bonus, the CombatPower attribute watching StatAtk / StatHp), "
             "PvPService's fallback, the Tab list column and LootService's 'Power X -> Y'; the save gains Stats = { Auto "
             "true, Order '' } as an additive field (검수 2026-10-07: no version step of its own; Version 4 since C1; fillDefaults adds / repairs it, "
             "idempotent).",
    limitations="Stage 2 (10/16-17) adds StatService (the StatAction remote, auto placement, the blocks, StatAtk / StatHp "
                "/ StatFree / AutoStat attributes), the hits (ComputeMonsterHit, ComputePvPHit inside the 0.8-1.5 caps), "
                "max HP (Config.StatMaxHealth) and the bait threshold; game dev 1 builds the [Stats] tab and switches the "
                "HUD fallback to Config.CombatPowerOf. The real DataStore load (the CR-L3 refusal of a newer record) is in "
                "tools/test_onboarding.py.",
)

if __name__ == "__main__":
    run(SUITE)
