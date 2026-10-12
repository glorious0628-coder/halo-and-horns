"""Save v4 tables (게임성 개발 3, 2026-10-11), offline.

docs/design/save_v4_tables_2026-10-11.md (게임성 개발 2 + 3 agreed 2026-10-11): every table the artisan guild, the gear
slots and Otto / the golden egg will save gets its shape and its repair now, while the save version stays 3 (additive
fields like Stats / Looks); 게임성 개발 2's C1 bumps Config.Data.Version to 4 on top (tier 9, Spares, Market). Defaults
Craft { Smith / Alch / Tame { Lv, XP }, Rep, Made }, Research { Pts, Sum }, Gather { Day, N, Bloom, Gift, Total,
FirstBloom }, Gear { Own["<kind>:T:P"], On { Armor, Ring }, Pet[uid] }, Buffs { [tonic] = end }, Shop { Day, N },
EggHonorAt; one repair each (Config.Sanitize*), run by DataService.fillDefaults through Config.SanitizeSaveV4.
PetService.Sanitize keeps a pet's Roll { Spd = 5..10 } and drops every other Roll shape. Runs the CURRENT Config and Util
plus chunks cut from DataService (migrate / fillDefaults) and PetService (Sanitize with its helpers) with the installed
official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_save_v4_tables.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev3_save_v4_tables_2026-10-11.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
    "PET_SOURCE": SSS / "PetService.luau",
}
C, D, P = "CONFIG_SOURCE", "DATA_SOURCE", "PET_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE")}
    data = sources[D]
    out["DATA_EXTRACT"] = (
        "local Config, Util, TAG, TUTORIAL_DONE = ...\n"
        + function_block(data, "local function migrate(")
        + function_block(data, "local function fillDefaults(")
        + "\nreturn { Migrate = migrate, Fill = fillDefaults }\n")
    pet = sources[P]
    limit = re.search(r"^local LIMIT = \{.*?\}\n", pet, re.M)
    if not limit:
        raise ValueError("Source boundary changed: PetService LIMIT; update the test extractor.")
    out["PET_EXTRACT"] = (
        "local Config = ...\nlocal PETS = Config.Pets\n" + limit.group(0)
        + function_block(pet, "local function num(v, default)")
        + function_block(pet, "local function known(species)")
        + function_block(pet, "local function sanitizeRoll(r)")
        + "local PetService = {}\n"
        + function_block(pet, "function PetService.Sanitize(data)")
        + "\nreturn PetService.Sanitize\n")
    return out


MUTATIONS = [
    # --- defaults and limits
    ("config: the version back to 3 (C1 bumped it to 4)", C, "WeaponEnhance[9]) + Spares / Market (save_v4_tables_2026-10-11.md).\n\tVersion = 4,",
     "WeaponEnhance[9]) + Spares / Market (save_v4_tables_2026-10-11.md).\n\tVersion = 3,"),
    ("config: one craft level for all roles", C, "CraftRoles = { \"Smith\", \"Alch\", \"Tame\" },", "CraftRoles = { \"Smith\" },"),
    ("config: craft Lv40", C, "\tCraftMaxLv = 30,\n", "\tCraftMaxLv = 40,\n"),
    ("config: three buffs", C, "\tBuffMax = 2, -- Buffs", "\tBuffMax = 3, -- Buffs"),
    ("config: Otto 60 a day", C, "\tShopDayMax = 50, --", "\tShopDayMax = 60, --"),
    ("config: no Ring slot", C, "GearSlots = { \"Armor\", \"Ring\" },", "GearSlots = { \"Armor\" },"),
    ("config: a default craft Lv0", C, "Config.Data.Defaults.Craft = { Smith = { Lv = 1, XP = 0 },", "Config.Data.Defaults.Craft = { Smith = { Lv = 0, XP = 0 },"),
    ("config: no Gather default", C, "Config.Data.Defaults.Gather = { Day = 0, N = 0, Bloom = 0, Gift = 0, Total = 0, FirstBloom = false }\n", ""),
    ("config: no EggHonorAt default", C, "Config.Data.Defaults.EggHonorAt = 0\n", ""),
    ("config: the pet roll from 1%", C, "PetRollSpd = { 5, 10 },", "PetRollSpd = { 1, 10 },"),
    # --- helpers
    ("helper: NaN passes", C, "\tif type(v) ~= \"number\" or v ~= v or v == math.huge or v == -math.huge then return nil end\n\treturn math.clamp(math.floor(v), lo, hi)",
     "\tif type(v) ~= \"number\" or v == math.huge or v == -math.huge then return nil end\n\treturn math.clamp(math.floor(v), lo, hi)"),
    ("helper: inf passes", C, "\tif type(v) ~= \"number\" or v ~= v or v == math.huge or v == -math.huge then return nil end\n\treturn math.clamp(math.floor(v), lo, hi)",
     "\tif type(v) ~= \"number\" or v ~= v then return nil end\n\treturn math.clamp(math.floor(v), lo, hi)"),
    ("helper: no id length cap", C, "\treturn type(k) == \"string\" and #k >= 1 and #k <= Config.SaveV4.KeyLen\n", "\treturn type(k) == \"string\" and #k >= 1\n"),
    ("helper: slot names with digits", C, "and string.match(k, \"^%a+$\") ~= nil", "and string.match(k, \"^%w+$\") ~= nil"),
    ("helper: tier 0 allowed", C, "if not t or not p or t < 1 or t > Config.SaveV4.GearMaxTier", "if not t or not p or t < 0 or t > Config.SaveV4.GearMaxTier"),
    ("helper: no plus cap", C, "or t > Config.SaveV4.GearMaxTier or p > Config.Loot.MaxEnhance then return nil end", "or t > Config.SaveV4.GearMaxTier then return nil end"),
    ("helper: 'T:P' kept as written", C, "\treturn string.format(\"%d:%d\", t, p)\nend", "\treturn s\nend"),
    ("helper: count maps never cut", C, "\t\tif n and n > 0 and kept < Config.SaveV4.MaxKeys then\n", "\t\tif n and n > 0 then\n"),
    ("helper: 0 counts kept", C, "\t\tif n and n > 0 and kept < Config.SaveV4.MaxKeys then\n", "\t\tif n and kept < Config.SaveV4.MaxKeys then\n"),
    ("helper: unknown keys dropped", C, "\t\tif V4.key(k) and not known[k] and out[k] == nil then\n", "\t\tif false then\n"),
    ("helper: unknown tables kept", C, "\t\t\tif type(v) == \"boolean\" or (type(v) == \"string\" and #v <= Config.SaveV4.KeyLen) then\n",
     "\t\t\tif type(v) == \"boolean\" or type(v) == \"table\" or (type(v) == \"string\" and #v <= Config.SaveV4.KeyLen) then\n"),
    # --- Craft / Research / Gather
    ("craft: Lv without the cap", C, "out[role] = { Lv = V4.int(r.Lv, 1, L.CraftMaxLv) or 1,", "out[role] = { Lv = V4.int(r.Lv, 1, math.huge) or 1,"),
    ("craft: XP may go negative", C, "XP = V4.int(r.XP, 0, L.MaxCount) or 0 }", "XP = V4.int(r.XP, -math.huge, L.MaxCount) or 0 }"),
    ("craft: Rep dropped", C, "\tout.Rep = V4.int(src.Rep, 0, L.MaxCount) or 0\n", "\tout.Rep = 0\n"),
    ("craft: Made dropped", C, "\tout.Made = V4.countMap(src.Made, L.MaxCount)\n", "\tout.Made = {}\n"),
    ("craft: Pend dropped", C, "\tif type(p) == \"table\" and V4.key(p.Id) then\n", "\tif false then\n"),
    ("craft: Pend Plus unclamped", C, "Plus = V4.int(p.Plus, -1, 2) or -1,", "Plus = V4.int(p.Plus, -math.huge, math.huge) or -1,"),
    ("craft: Pend Mats as they are", C, "\t\t\tMats = V4.countMap(p.Mats, L.MaxCount) }\n", "\t\t\tMats = p.Mats }\n"),
    ("craft: Pend kept as a text", C, "\tif type(p) == \"table\" and V4.key(p.Id) then\n", "\tif type(p) == \"string\" then\n\t\tout.Pend = p\n\telseif type(p) == \"table\" and V4.key(p.Id) then\n"),
    ("research: Sum dropped", C, "Sum = V4.countMap(src.Sum, Config.SaveV4.MaxCount) }", "Sum = {} }"),
    ("gather: FirstBloom from any value", C, "\tlocal out = { FirstBloom = src.FirstBloom == true }\n", "\tlocal out = { FirstBloom = src.FirstBloom ~= nil and src.FirstBloom ~= false }\n"),
    ("gather: Total never repaired", C, "\tfor _, k in { \"Day\", \"N\", \"Bloom\", \"Gift\", \"Total\" } do\n", "\tout.Total = src.Total\n\tfor _, k in { \"Day\", \"N\", \"Bloom\", \"Gift\" } do\n"),
    # --- Gear
    ("gear: no per-key cap", C, "\t\tlocal n = V4.int(src.Own[k], 0, L.OwnKeyMax)\n", "\t\tlocal n = V4.int(src.Own[k], 0, math.huge)\n"),
    ("gear: a merged key over the cap", C, "\t\t\t\town[key] = math.min(L.OwnKeyMax, own[key] + n)\n", "\t\t\t\town[key] += n\n"),
    ("gear: a later key replaces the earlier one", C, "\t\t\t\town[key] = math.min(L.OwnKeyMax, own[key] + n)\n", "\t\t\t\town[key] = n\n"),
    ("gear: Own never cut", C, "\t\t\telseif kept < L.MaxKeys then\n", "\t\t\telse\n"),
    ("gear: any kind name", C, "\t\tlocal tp = kind and V4.slot(kind) and V4.tierPlus(rest)\n", "\t\tlocal tp = kind and V4.tierPlus(rest)\n"),
    ("gear: On without its slots", C, "\t\tif on[slot] == nil then on[slot] = \"\" end\n", ""),
    ("gear: empty pet entries kept", C, "\t\tif next(worn) ~= nil and pets < L.MaxKeys then\n", "\t\tif pets < L.MaxKeys then\n"),
    ("gear: pets never cut", C, "\t\tif next(worn) ~= nil and pets < L.MaxKeys then\n", "\t\tif next(worn) ~= nil then\n"),
    ("gear: worn values not checked", C, "\t\tlocal tp = V4.slot(k) and V4.tierPlus(v)\n", "\t\tlocal tp = V4.slot(k) and v\n"),
    # --- Buffs / Shop / Egg
    ("buffs: ended buffs kept", C, "\t\t\tif V4.key(id) and ends and ends > now then table.insert(list, { id, ends }) end\n",
     "\t\t\tif V4.key(id) and ends then table.insert(list, { id, ends }) end\n"),
    ("buffs: a long buff never cut", C, "\t\t\tlocal ends = V4.int(v, 0, now + L.BuffSeconds)\n", "\t\t\tlocal ends = V4.int(v, 0, 2 ^ 52)\n"),
    ("buffs: the earliest kept", C, "\t\tif a[2] ~= b[2] then return a[2] > b[2] end\n", "\t\tif a[2] ~= b[2] then return a[2] < b[2] end\n"),
    ("buffs: no count cap", C, "\tfor i = 1, math.min(#list, L.BuffMax) do\n", "\tfor i = 1, #list do\n"),
    ("shop: N without the cap", C, "N = V4.int(src.N, 0, Config.SaveV4.ShopDayMax) or 0 }", "N = V4.int(src.N, 0, Config.SaveV4.MaxCount) or 0 }"),
    ("egg: a future hour kept", C, "\treturn math.min(at, now)\n", "\treturn at\n"),
    ("egg: a future hour reopens at once", C, "\treturn math.min(at, now)\n", "\treturn at > now and 0 or at\n"),
    ("all: the load skips Gear", C, "\td.Gear = Config.SanitizeGear(d.Gear)\n", ""),
    ("all: the load skips Buffs", C, "\td.Buffs = Config.SanitizeBuffs(d.Buffs, now)\n", ""),
    ("all: the load skips EggHonorAt", C, "\td.EggHonorAt = Config.SanitizeEggHonorAt(d.EggHonorAt, now)\n", ""),
    # --- DataService / PetService
    ("DataService: the v4 repair never runs", D, "\tif Config.SanitizeSaveV4 then Config.SanitizeSaveV4(d, os.time()) end\n", ""),
    ("DataService: no v4 step in migrate (C1)", D, "\t\td.Version = 4\n", ""),
    ("pet: Roll dropped", P, "\t\t\t\t\tRoll = sanitizeRoll(p.Roll),\n", ""),
    ("pet: Roll kept as it was", P, "\t\t\t\t\tRoll = sanitizeRoll(p.Roll),\n", "\t\t\t\t\tRoll = p.Roll,\n"),
    ("pet: fractions allowed", P, "if type(spd) ~= \"number\" or spd ~= math.floor(spd) or spd < range[1]", "if type(spd) ~= \"number\" or spd ~= spd or spd < range[1]"),
    ("pet: no upper end", P, "or spd < range[1] or spd > range[2] then return nil end", "or spd < range[1] then return nil end"),
    ("pet: extra keys allowed", P, "\t\tif k ~= \"Spd\" then return nil end\n", ""),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    config = read(SHARED / "Config.luau")
    section = config[config.find("-- save v4 tables (docs/design/save_v4_tables_2026-10-11.md)"):]
    check(bool(section) and "Config.SanitizeSaveV4" in section, "Config: the save v4 section and Config.SanitizeSaveV4 exist")
    code = strip_comments(section)
    check(not re.search(r'"[A-Z][a-z]+ [a-z]+[^"]*"', code),
          "the v4 section has no English sentence (ids and numbers only, A23-111 / A23-133)")
    check("\nlocal V4 = {}\n" in section and not re.search(r"^local (?!V4 = \{\}|function wornSlots)", section, re.M),
          "the v4 section adds one top-level local table (+ one helper function): Config's 200-locals limit")
    data = read(SSS / "DataService.luau")
    check("Config.SanitizeSaveV4(d, os.time())" in function_block(data, "local function fillDefaults(")
          and "< 4 then" in function_block(data, "local function migrate("),
          "DataService: the v4 repair runs in fillDefaults, migrate has the C1 v4 step")
    mirrored = re.search(r"\tMirrored = \{(.*?)\n\t\}", config, re.S)
    check(bool(mirrored) and not re.search(r'"(Craft|Research|Gather|Gear|Buffs|Shop|EggHonorAt|Spares|Market)"', mirrored.group(1)),
          "no v4 table is mirrored")
    pet = read(SSS / "PetService.luau")
    check("Roll = sanitizeRoll(p.Roll)," in function_block(pet, "function PetService.Sanitize(data)"),
          "PetService.Sanitize keeps the pet row's Roll through sanitizeRoll")
    money = strip_comments(read(SSS / "MonetizationService.luau"))
    check(not re.search(r"\b(Gear|Craft|Research|Buffs)\b", money), "no Robux path touches the v4 tables (stats never sold)")
    return count, failures


SUITE = Suite(
    mark="SAVEV4",
    fixture=ROOT / "tools/fixtures/save_v4_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev3_save_v4_tables_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Save v4 tables (docs/design/save_v4_tables_2026-10-11.md, agreed by 게임성 개발 2 + 3 2026-10-11): additive "
             "defaults (the version is 4 since 게임성 개발 2's C1) - Craft { Smith / Alch / Tame { Lv 1..30, XP }, Rep, Made (64 ids) }, "
             "Research { Pts, Sum } (64 families), Gather { Day, N, Bloom, Gift, Total, FirstBloom }, Gear { Own "
             "'<kind>:T:P' -> 1..20 (letters-only kinds, tier 1..16, plus 0..10, written plainly and merged, 64 keys), On "
             "{ Armor, Ring always, '' = empty }, Pet { uid -> worn slots, 64 pets } }, Buffs { tonic -> end, ended "
             "dropped, cut to now + 180, the 2 that end last }, Shop { Day, N 0..50 }, EggHonorAt (a future hour = 0). "
             "A repair never makes a value up and keeps a sane unknown flat key; repairing twice = once. DataService."
             "fillDefaults runs Config.SanitizeSaveV4(d, os.time()); PetService.Sanitize keeps Roll { Spd = 5..10 } only.",
    limitations="No service writes these tables yet (GatherService, CraftService, GearService, the alchemy buffs, Otto's "
                "cheap materials and the golden egg come in their own branches). The version bump, Spares, Market and the "
                "9-bit weapon mask are 게임성 개발 2's C1. The real DataStore load (the CR-L3 refusal of a newer record) is "
                "in tools/test_onboarding.py.",
)

if __name__ == "__main__":
    run(SUITE)
