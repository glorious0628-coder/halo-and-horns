"""Alchemy tonics (BuffService, 게임성 개발 3, 2026-10-12), offline.

Contract docs/design/alchemy_server_2026-10-12.md (A23-133: everyone drinks them, monsters only, 3 minutes, two at a time,
no speed tonic in the beta): four tonics made by alchemists (recipes A1..A4, one bottle + the hammer's +N), Might x1.1 on
every hit on a monster, Guard x0.9 on every monster hit, Lucky x1.25 on material drop rows only, Wisdom x1.1 on a kill's
XP; UseTonic(itemId) for a ready, living player with a bottle and fewer than two other tonics running, the same tonic
again starts its 3 minutes over; data.Buffs keeps the end times, Buff_<item> attributes show them; switched by
Config.Features.Tonics. Runs the CURRENT Config, Util, LootService and BuffService on tools/fixtures/dev2_kit.luau +
tools/fixtures/dev3_world.luau with tools/fixtures/alchemy_offline.luau and the installed official Luau CLI; the
CombatService and ProgressionService hooks are one line each and checked statically. No Studio, network, DataStore or
Roblox API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_alchemy.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev3_alchemy_2026-10-12.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "BUFF_SOURCE": SSS / "BuffService.luau",
}
C, L, B = "CONFIG_SOURCE", "LOOT_SOURCE", "BUFF_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # A23-219 ② B special potions / tonics / treats (게임성 개발 2)
    ('B: a special runs as itself (two of one effect)', B, '\tdata.Buffs[base] = ends\n', '\tdata.Buffs[id] = ends\n'),
    ('B: no Extra time', B, '+ math.max(0, math.floor(num(tonic.Extra, 0)))', '+ 0'),
    # --- the table
    ("config: on by default", C, "Config.Features.Tonics = false\n", "Config.Features.Tonics = true\n"),
    ("config: 4 minutes", C, "Config.Alchemy = {\n\tDuration = 180,", "Config.Alchemy = {\n\tDuration = 240,"),
    ("config: three at a time", C, "\tMaxActive = 2,\n\tTonics = {", "\tMaxActive = 3,\n\tTonics = {"),
    ("config: Might +20%", C, "MightTonic = { Stat = \"MonsterDamage\", Mult = 1.10 },", "MightTonic = { Stat = \"MonsterDamage\", Mult = 1.20 },"),
    ("config: Guard helps in PvP too", C, "GuardTonic = { Stat = \"MonsterHurt\", Mult = 0.90 },", "GuardTonic = { Stat = \"AnyHurt\", Mult = 0.90 },"),
    ("config: Lucky x1.5", C, "LuckyTonic = { Stat = \"MaterialDrop\", Mult = 1.25 },", "LuckyTonic = { Stat = \"MaterialDrop\", Mult = 1.5 },"),
    ("config: Wisdom on gold", C, "WisdomTonic = { Stat = \"HuntXP\", Mult = 1.10 },", "WisdomTonic = { Stat = \"HuntGold\", Mult = 1.10 },"),
    ("config: tonics sold at the Forge", C, "Icon = \"IconMightTonic\", Source = \"Craft\", Desc = \"Hit monsters harder for 3 minutes.\"", "Icon = \"IconMightTonic\", Desc = \"Hit monsters harder for 3 minutes.\""),
    ("config: A1 at craft Lv2", C, "Item = \"MightTonic\", N = 1, Lv = 1, Gold = 20,", "Item = \"MightTonic\", N = 1, Lv = 2, Gold = 20,"),
    ("config: tonics out of the bag order", C, "\t\t\"MightTonic\", \"GuardTonic\", \"LuckyTonic\", \"WisdomTonic\", \"PetTreat\",\n", "\t\t\"PetTreat\",\n"),
    # --- drinking
    ("use: the switch not checked", B, "\tif not on() then return \"off\" end\n\tlocal tonic", "\tlocal tonic"),
    ("use: any item drinks", B, "\tif type(tonic) ~= \"table\" or not Config.Loot.Items[id] then return \"tonic\" end\n", "\tif type(tonic) ~= \"table\" then tonic = { Stat = \"x\", Mult = 1 } end\n"),
    ("use: not-ready players drink", B, "\tif not data or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return \"state\" end\n", "\tif not data or not Util.IsAlive(player) then return \"state\" end\n"),
    ("use: KO'd players drink", B, "\tif not data or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return \"state\" end\n", "\tif not data or not S.PlayerService.IsReady(player) then return \"state\" end\n"),
    ("use: no bottle needed", B, "\tif have < 1 then\n", "\tif false then\n"),
    ("use: no limit of two", B, "\tif others >= num(A().MaxActive, 2) then\n", "\tif false then\n"),
    ("use: the same tonic counts against the limit", B, "\t\tif other ~= base then others += 1 end\n", "\t\tothers += 1\n"),
    ("use: the bottle stays", B, "\tif not S.LootService.TakeItem(player, id, 1) then return \"none\" end\n", ""),
    ("use: no end time", B, "\tdata.Buffs[base] = ends\n", ""),
    ("use: no attribute", B, "\tdata.Buffs[base] = ends\n\tpublish(player)\n", "\tdata.Buffs[base] = ends\n"),
    ("use: never runs out on screen", B, "\twatch(player, base, ends)\n\tif S.PlayerService.MarkActive", "\tif S.PlayerService.MarkActive"),
    ("use: no telemetry", B, "\tif S.TelemetryService and S.TelemetryService.Custom then pcall(S.TelemetryService.Custom, player, \"TonicUse\", 1, id) end\n", ""),
    # --- running / mult
    ("mult: ended tonics still count", B, "\t\tif type(A().Tonics[id]) == \"table\" and num(ends) > now then out[id] = num(ends) end\n", "\t\tif type(A().Tonics[id]) == \"table\" then out[id] = num(ends) end\n"),
    ("mult: any stat", B, "\t\tif t.Stat == stat then mult *= num(t.Mult, 1) end\n", "\t\tmult *= num(t.Mult, 1)\n"),
    ("mult: the switch not checked", B, "\tif not on() or typeof(player) ~= \"Instance\" then return 1 end\n", "\tif typeof(player) ~= \"Instance\" then return 1 end\n"),
    ("join: nothing shown", B, "\t\t\tpublish(player)\n\t\t\tfor id, ends in BuffService.Running(player) do watch(player, id, ends) end\n", ""),
    # --- remote
    ("remote: extra arguments taken", B, "\tif select(\"#\", ...) ~= 1 then return end\n\tlocal id = ...\n", "\tlocal id = ...\n"),
    ("remote: no rate limit", B, "\tif not Util.RateLimit(player, \"UseTonic\", num(Config.RateLimits.UseTonic, 1)) then return end\n", ""),
    # --- the Lucky Tonic hook in LootService
    ("loot: Lucky on every row", L, "\t\tlocal rowBonus = rowBonus * ((def and def.Kind == \"Material\" and def.Source == nil) and num(info.MatMult, 1) or 1)\n", "\t\tlocal rowBonus = rowBonus * num(info.MatMult, 1)\n"),
    ("loot: Lucky on boss / gathered material rows", L, " and def.Source == nil) and num(info.MatMult, 1) or 1)\n", ") and num(info.MatMult, 1) or 1)\n"),
    ("loot: Lucky never asked", L, "\tif S.BuffService then info.MatMult = S.BuffService.Mult(player, \"MaterialDrop\") end\n", ""),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    combat = strip_comments(read(SSS / "CombatService.luau"))
    dm = combat[combat.index("local function damageMonster("):]
    dm = dm[:dm.index("\nend\n")]
    check('dealt = dealt * S.BuffService.Mult(player, "MonsterDamage")' in dm, "CombatService.damageMonster: every hit on a monster x the Might Tonic")
    dp = combat[combat.index("function CombatService.DamagePlayer("):]
    dp = dp[:dp.index("amount = Util.RoundDamage(amount)")]
    check(re.search(r'attacker == nil and type\(sourceKind\) == "string" and Config\.MonsterTypes\[sourceKind\] ~= nil and S\.BuffService then\s*'
                    r'amount = amount \* S\.BuffService\.Mult\(victim, "MonsterHurt"\)', dp) is not None,
          "CombatService.DamagePlayer: only a monster's hit x the Guard Tonic (before the rounding)")
    check(combat.count("S.BuffService.Mult(") == 2, "no other combat path asks the tonics (never PvP)")
    prog = strip_comments(read(SSS / "ProgressionService.luau"))
    kill = prog[prog.index("local function onMonsterKilled("):]
    kill = kill[:kill.index("\nend\n")]
    check('S.BuffService.Mult(player, "HuntXP")' in kill and prog.count("S.BuffService.Mult(") == 1,
          "ProgressionService: the Wisdom Tonic only on a monster kill's XP (never a quest)")
    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    ni = re.findall(r'"(\w+)"', strip_comments(init.group(1))) if init else []
    ns = re.findall(r'"(\w+)"', strip_comments(start.group(1))) if start else []
    check("BuffService" in ni and ni.index("BuffService") > ni.index("LootService"), "Main INIT_ORDER has BuffService")
    check("BuffService" in ns and ns.index("BuffService") < ns.index("PlayerService"), "Main START_ORDER has BuffService before PlayerService")
    net = read(SHARED / "Net.luau")
    names = re.search(r"Net\.Names = \{(.*?)\n\}", net, re.S)
    check(bool(names) and '"UseTonic"' in strip_comments(names.group(1)), "Net.Names has UseTonic")
    buff = strip_comments(read(SSS / "BuffService.luau"))
    check("Net.Notify(" not in buff and "Net.NotifyKey" in buff, "BuffService sends notices by key only")
    check(not re.search(r"MarketplaceService|PromptPurchase|Robux", buff), "no purchase path for tonics (A23-75: no stats sold)")
    return count, failures


SUITE = Suite(
    mark="ALCHEMY",
    fixture=ROOT / "tools/fixtures/alchemy_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-12/offline_dev3_alchemy_2026-10-12.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Alchemy tonics (docs/design/alchemy_server_2026-10-12.md, A23-133): switch Config.Features.Tonics off; Might "
             "x1.1 hits on monsters, Guard x0.9 monster hits, Lucky x1.25 material rows only, Wisdom x1.1 kill XP; 180 s, "
             "two at a time, the same again starts over; UseTonic(item) for a ready living player with a bottle; "
             "data.Buffs end times, Buff_<item> attributes (server time, 0 = none), cleared on time and shown at a join; "
             "recipes A1..A4 (Alch, one bottle + the hammer's +N, craft Lv 1 / 3 / 8 / 12); items Kind Tonic, Source "
             "Craft; key-only notices; one drink a second.",
    limitations="The Might / Guard / Wisdom hooks in CombatService and ProgressionService are checked statically (those "
                "modules are not run here); the bag's Drink button and a tonic quick slot are client work (게임성 개발 4 / "
                "1); the market (게임성 개발 2) is where non-alchemists will buy them.",
)

if __name__ == "__main__":
    run(SUITE)
