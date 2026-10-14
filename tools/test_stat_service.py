"""A23-69 stat points, stage 2 (docs/design/stat_points_2026-10-07.md §2, §3-3, §5-2, §6), offline.

StatService (remote StatAction: add / add5 / reset / auto, the blocks of §2-4, the level / class signals, the flat
attributes StatAtk / StatHp / StatFree / AutoStat, the lines of §6) and the connections: CombatService.ComputeMonsterHit
x Attack, ComputePvPHit inside the 0.8-1.5 clamp with the victim's Health once, Config.StatMaxHealth behind
PlayerService.computeMaxHealth and PvPService's bait rule. The switch Config.Features.StatPoints stays OFF in Config
(checked); the worlds switch it on to test. Runs the CURRENT Config, Util, CombatService, LootService, StoryQuestService,
PvPService, StatService and the unarmed suite's extracts on tools/fixtures/dev2_combat_world.luau with
tools/fixtures/stat_service_offline.luau and the installed official Luau CLI. No Studio, network, DataStore or Roblox API
calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_stat_service.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev2_stat_service_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["STAT_SOURCE"] = SSS / "StatService.luau"
FILES["PLAYER_SOURCE"] = SSS / "PlayerService.luau"
C, CO, ST, PS, P = "CONFIG_SOURCE", "COMBAT_SOURCE", "STAT_SOURCE", "PLAYER_SOURCE", "PVP_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    out["STAT_SOURCE"] = sources[ST]
    # ⑥ gear (게임성 개발 3) put gearHp in front of computeMaxHealth: both are extracted
    out["MAXHP_EXTRACT"] = ("local Config, stat, healthMult = ...\n"
                            + function_block(sources[PS], "local function gearHp(") + "\n"
                            + function_block(sources[PS], "local function computeMaxHealth(")
                            + "\nreturn computeMaxHealth\n")
    return out


MUTATIONS = [
    # --- the switch and the remote's gates
    ("Config: the switch on", C, "Market = false, StatPoints = false }", "Market = false, StatPoints = true }"),
    ("StatService ignores the switch", ST, "\treturn Config.FeatureOn(\"StatPoints\")\n", "\treturn true\n"),
    ("any op", ST, "\tif type(op) ~= \"string\" or not OPS[op] then return end\n", "\tif type(op) ~= \"string\" then return end\n"),
    ("any letter", ST, "and (type(arg) ~= \"string\" or not (ST.Letters or {})[arg]) then return end",
     "and type(arg) == \"nil\" then return end"),
    ("auto takes a non-boolean", ST, "\tif op == \"auto\" and type(arg) ~= \"boolean\" then return end\n", ""),
    ("extra arguments taken", ST, "\tif select(\"#\", ...) ~= 0 or not isPlayer(player) or not on() then return end\n",
     "\tif not isPlayer(player) or not on() then return end\n"),
    ("no rate limit", ST, "\tif not Util.RateLimit(player, \"StatAction\", Config.RateLimits.StatAction or 0.15) then return end\n", ""),
    ("the dead may pick", ST, "\tif not Util.IsAlive(player) then return end -- silent\n", ""),
    ("not ready players may pick", ST,
     "\tif not S.PlayerService.IsReady(player) or player:GetAttribute(\"ClassChosen\") ~= true then return end\n", ""),
    ("picks in PvP combat", ST, "if cs and type(cs.IsInCombat) == \"function\" and cs.IsInCombat(player) then return \"TravelBlockedCombat\" end",
     "if false then return \"TravelBlockedCombat\" end"),
    ("picks as a kaiju", ST, "if ok and type(st) == \"string\" and st ~= \"None\" then return \"BlockedKaiju\" end", ""),
    ("picks with the grudge sack", ST, "if ok and has == true then return \"BlockedSack\" end", ""),
    # --- the actions
    ("[+] while Auto is on", ST, "\t\tif stats.Auto ~= false then return end -- the client asks", "\t\tif false then return end -- the client asks"),
    ("[+] past the free points", ST, "\t\t\tif n < 1 then return end\n", ""),
    ("[+5] places 5 always", ST, "local n = op == \"add5\" and math.min(5, free) or math.min(1, free)",
     "local n = op == \"add5\" and 5 or math.min(1, free)"),
    ("no reset cooldown", ST, "if s and s.ResetAt and now - s.ResetAt < (ST.ResetCooldown or 3) then return end", "if false then return end"),
    ("Config: reset cooldown 0", C, "\tResetCooldown = 3, -- s between two free resets", "\tResetCooldown = 0, -- s between two free resets"),
    ("Auto off forgets the picks", ST,
     "saveStats(player, false, string.sub(string.rep(pattern, math.ceil(points / #pattern)), 1, points))",
     "saveStats(player, false, \"\")"),
    ("Auto on keeps the old picks", ST, "\t\t\tsaveStats(player, true, \"\") -- back to the class pattern\n",
     "\t\t\tsaveStats(player, true, stats.Order) -- back to the class pattern\n"),
    ("the manual hint every time", ST, "\t\t\tif firsts and firsts.StatManual ~= true then\n", "\t\t\tif firsts then\n"),
    ("a full heal after a pick", ST, "local ok, err = pcall(S.PlayerService.RefreshCharacter, player, false)",
     "local ok, err = pcall(S.PlayerService.RefreshCharacter, player, true)"),
    ("no re-read after a pick", ST, "\tif changed then\n\t\tlocal ok, err = pcall(S.PlayerService.RefreshCharacter", "\tif false then\n\t\tlocal ok, err = pcall(S.PlayerService.RefreshCharacter"),
    ("no power line", ST, "\tif after ~= before and type((Config.Power.Text or {}).Change) == \"string\" then\n",
     "\tif false then\n"),
    # --- the signals and the lines
    ("no level-up placement", ST, "\tconnect(\"ProgressionService\", \"LeveledUp\", onLeveledUp)\n", ""),
    ("no re-read after a class change", ST, "\tconnect(\"ClassService\", \"ClassChanged\", onRecount)\n", ""),
    ("no re-read after a level reset", ST, "\tconnect(\"ProgressionService\", \"LevelReset\", onRecount)\n", ""),
    ("lines before the first claim", ST, "\tif not talks(data) then return end\n", ""),
    ("the first-point line every time", ST, "\tlocal isFirst = firsts ~= nil and firsts.StatPoint ~= true\n",
     "\tlocal isFirst = firsts ~= nil\n"),
    ("by hand: no point line", ST, "\telseif free > 0 then\n\t\tnotify(player, Config.Plural(",
     "\telseif false then\n\t\tnotify(player, Config.Plural("),
    ("by hand: '+1 Stat Points'", ST, "notify(player, Config.Plural(string.format(TXT.LevelPoints, free)), \"info\", \"None\")",
     "notify(player, string.format(TXT.LevelPoints, free), \"info\", \"None\")"),
    # --- the numbers
    ("monster hits ignore Attack", CO, "\t\t* (Config.StatMults(alloc.A, alloc.H))\n", ""),
    # (the gear mults of ⑥ sit beside the stat mults in the same ratio)
    ("PvP ratio ignores Attack", CO, "* gearAtk(attacker) * aAtk\n", "* gearAtk(attacker)\n"),
    ("PvP: Health only in the base (a bigger hit)", CO, "/ (vWeapon * gearAtk(victim) * vHp)",
     "/ (vWeapon * gearAtk(victim))"),
    ("PvP base without Health", CO, "local base = Config.StatMaxHealth(vLevel, faction(victim), vClass, vAlloc.H) * Config.PvP.HitPctOfMaxHP",
     "local base = Config.MaxHealth(vLevel, faction(victim), vClass) * Config.PvP.HitPctOfMaxHP"),
    ("PvP clamp widened", CO, "\tratio = math.clamp(ratio, floor, Config.PvP.PowerRatioMax)\n", "\tratio = math.max(ratio, floor)\n"),
    ("max HP without Health", PS, "\tlocal hp = type(Config.StatAllocOf) == \"function\" and Config.StatAllocOf(player).H or 0\n",
     "\tlocal hp = 0\n"),
    ("StatMaxHealth ignores Health", C, "\tlocal _, hm = Config.StatMults(0, hpPoints)\n", "\tlocal hm = 1\n"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    main = read(SSS / "Main.server.luau")
    init = main[main.find("local INIT_ORDER"):main.find("local START_ORDER")]
    start = main[main.find("local START_ORDER"):main.find("local S = {}")]
    check('"StatService"' in init and '"StatService"' in start, "Main lists StatService in INIT_ORDER and START_ORDER")
    check(start.find('"StatService"') < start.find('"PlayerService"'), "StatService starts before PlayerService (last)")
    net = read(SHARED / "Net.luau")
    check(net.count('"StatAction"') == 1, "Net.Names has StatAction once")
    config = read(SHARED / "Config.luau")
    check("StatAction = 0.15," in config, "Config.RateLimits.StatAction = 0.15")
    pvp = strip_comments(read(SSS / "PvPService.luau"))
    check("Config.StatMaxHealth(num(killer, \"Level\", 1), fk, classOf(killer)," in pvp
          and "Config.StatAllocOf(killer).H" in pvp, "PvPService's bait rule uses the killer's StatMaxHealth")
    code = {name: strip_comments(read(SSS / name)) for name in ("CombatService.luau", "PlayerService.luau", "PvPService.luau")}
    check(all("Config.MaxHealth(" not in text for text in code.values()),
          "no player max HP outside Config.StatMaxHealth (CombatService / PlayerService / PvPService)")
    money = strip_comments(read(SSS / "MonetizationService.luau"))
    check("StatService" not in money and "Stats" not in money, "MonetizationService never touches the stats (A23-69: never sold)")
    stat = strip_comments(read(SSS / "StatService.luau"))
    check(re.search(r"OnServerEvent:Connect\(function\(player, \.\.\.\)", stat) is not None
          and "tonumber(arg" not in stat, "the remote takes letters / booleans only, never a number from the client")
    return count, failures


SUITE = Suite(
    mark="STAT_SERVICE",
    fixture=ROOT / "tools/fixtures/stat_service_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev2_stat_service_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-69 stage 2 (stat_points §2, §3-3, §5-2, §6), switch Features.StatPoints OFF in Config: while off "
             "StatService writes nothing and refuses StatAction, the numbers are today's. On: attributes StatAtk / StatHp "
             "/ StatFree / AutoStat = Config.StatAlloc(data.Stats, level, class) at PlayerReady, LeveledUp, LevelReset, "
             "Rebirthed, ClassChanged and after actions. StatAction(op, arg): add A|H, add5 A|H (min 5 free), reset (3 s), "
             "auto true|false (off copies the placed letters, on clears Order); add / add5 / reset need Auto off; refused "
             "in PvP combat / as a kaiju / with the grudge sack (TravelBlockedCombat / BlockedKaiju / BlockedSack), "
             "silently when dead, not ready, rate-limited (0.15 s) or with bad args. After a change RefreshCharacter(p, "
             "false) and 'Power X -> Y'; lines after the first [Claim]: the first point once, Auto level-up '+N Stat · "
             "Power X -> Y', by hand '+N Stat Point(s)! Tap Power.', the first Auto-off hint once; Fx Stat. Monster hits x "
             "(1 + f(Attack)); PvP ratio (aW x atk) / (vW x hp) clamped 0.8 (bare 0.4) - 1.5, base StatMaxHealth x 0.1: "
             "6.67-12.5 hits; max HP = StatMaxHealth x Justice; the bait rule uses StatMaxHealth.",
    limitations="RefreshCharacter is a recording double (its HP-ratio rule is PlayerService.applyStats, unchanged); the "
                "[Stats] tab, the red dot and the chip glow are game dev 1's client (StatUI). The world's Justice "
                "multipliers are doubles (1).",
)

if __name__ == "__main__":
    run(SUITE)
