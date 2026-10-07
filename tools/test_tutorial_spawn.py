"""3rd idea round #7 (ideas_first10 §3-#7, 검수 2026-10-07): the first mission's slimes come near the sprout, offline.

A player on the first mission's hunt (TutorialStep = Config.Tutorial.Steps.Quest in Tutorial.GuideZone) is the spawn
spread's first choice for the tutorial monster: with fewer than Config.SpawnSpread.Tutorial.StarvedThreshold (3)
monsters within 30 studs the slime comes 10-18 studs away on the half circle facing the zone middle (twice the tries;
the meadow entrance sits on the spawn-inset edge), and each hunter raises the meadow's slime target by Extra (3, never
above Count x MaxZoneMult) so a lone sprout on a quiet server sees new slimes at once (ReevalInterval 5 s). Other
starved players: a Rookie first, then the lowest level, then the fewest monsters near (A7-1 ring 18-28 unchanged).

Cuts the A7-1 spread constants, TUTORIAL / TUT_SPAWN, GLOBAL_CAP, insideZone, tutorialHunter, playersPerZone,
wantedTargets .. cappedTargets and pickSpawnPoint from the CURRENT MonsterService (with the CURRENT Config) and runs them
on tools/fixtures/dev2_kit.luau doubles with tools/fixtures/tutorial_spawn_offline.luau and the installed official Luau
CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_tutorial_spawn.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-07/offline_dev2_tutorial_spawn_2026-10-07.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
}
C, M = "CONFIG_SOURCE", "MONSTER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    consts = []
    for pattern in (r"^local TUTORIAL = .*$", r"^local TUT_SPAWN = .*$", r"^local SPAWN_TRIES = .*$"):
        found = re.search(pattern, mon, re.M)
        if not found:
            raise ValueError(f"MonsterService constant {pattern!r} missing; update the test extractor.")
        consts.append(found.group(0))
    return {
        "CONFIG_SOURCE": sources[C],
        "SPAWN_EXTRACT": (
            "local Config, Util, MonsterService, H = ...\n"
            "local MC = Config.Monsters\n"
            "local DENSITY = Config.MonsterDensity or {}\n"
            "local records, pending = H.records, H.pending\n"
            "local readyPlayers, groundPoint, warnThrottled = H.readyPlayers, H.groundPoint, H.warnThrottled\n"
            + between(mon, "local SPREAD = Config.SpawnSpread or {}\n", "\n-- shared Config keys (G1) with fallbacks") + "\n"
            + "\n".join(consts) + "\n"
            + between(mon, "local GLOBAL_CAP\n", "\n------------------------------------------------------------------ helpers")
            + "\n"
            + function_block(mon, "local function insideZone(")
            + function_block(mon, "local function tutorialHunter(")
            + function_block(mon, "local function playersPerZone(")
            + between(mon, "local function wantedTargets(",
                      "------------------------------------------------------------------ public queries")
            + function_block(mon, "local function pickSpawnPoint(")
            + "return { tutorialHunter = tutorialHunter, playersPerZone = playersPerZone, wantedTargets = wantedTargets, "
              "targetCount = targetCount, cappedTargets = cappedTargets, pickSpawnPoint = pickSpawnPoint, "
              "TUT_SPAWN = TUT_SPAWN, GLOBAL_CAP = GLOBAL_CAP }\n"),
    }


MUTATIONS = [
    # who goes first
    ("the hunter is not first", M, "if best == nil or (cand.Tut ~= best.Tut and cand.Tut)", "if best == nil or false"),
    ("the hunter keeps the regular threshold", M,
     "if c < (tut and (TUT_SPAWN.Cfg.StarvedThreshold or 3) or SPREAD_THRESHOLD) then", "if c < SPREAD_THRESHOLD then"),
    ("Rookies are not first", M, "(cand.Rookie ~= best.Rookie and cand.Rookie", "(false"),
    ("the lower level is not first", M, "(cand.Level < best.Level", "(false"),
    ("the fewest near is not the last tie-break", M, "(cand.Level == best.Level and cand.Count < best.Count)", "false"),
    ("a dead player pulls slimes", M, "\t\t\tif Util.IsAlive(p) then\n\t\t\t\tlocal root = Util.GetRoot(p)\n\t\t\t\tif root then\n\t\t\t\t\tlocal pos = root.Position",
     "\t\t\tif true then\n\t\t\t\tlocal root = Util.GetRoot(p)\n\t\t\t\tif root then\n\t\t\t\t\tlocal pos = root.Position"),
    ("the ring for every kind", M,
     "local tutKind = kind ~= nil and kind == TUTORIAL.Monster and def.Zone == TUTORIAL.GuideZone", "local tutKind = kind ~= nil"),
    # the ring
    ("the hunter gets the old ring start (18)", M, "local minD = best.Tut and (TUT_SPAWN.Cfg.MinDist or 10) or SPREAD_MIN",
     "local minD = SPREAD_MIN"),
    ("the hunter ring reaches 28", M, "local maxD = best.Tut and (TUT_SPAWN.Cfg.MaxDist or 18) or SPREAD_MAX",
     "local maxD = SPREAD_MAX"),
    ("a full circle at the entrance", M,
     "local a = face and face + Util.Random:NextNumber(-math.pi / 2, math.pi / 2) or Util.Random:NextNumber(0, math.pi * 2)",
     "local a = Util.Random:NextNumber(0, math.pi * 2)"),
    ("the ring faces away from the middle", M, "math.atan2(zone.Center.Z - bestPos.Z, zone.Center.X - bestPos.X)",
     "math.atan2(bestPos.Z - zone.Center.Z, bestPos.X - zone.Center.X)"),
    ("no extra tries", M, "for _ = 1, face and SPREAD_TRIES * 2 or SPREAD_TRIES do", "for _ = 1, SPREAD_TRIES do"),
    # hunters and targets
    ("any step counts as a hunter", M, 'p:GetAttribute("TutorialStep") == (TUTORIAL.Steps or {}).Quest',
     'p:GetAttribute("TutorialStep") ~= nil'),
    ("any zone counts", M, "return zoneId == TUTORIAL.GuideZone and p:GetAttribute", "return p:GetAttribute"),
    ("no hunter count", M, "\t\t\tif tutorialHunter(p, id) then hunters[id] = (hunters[id] or 0) + 1 end\n", ""),
    ("the hunters are never stored", M, "\tTUT_SPAWN.Hunters = hunters\n", ""),
    ("old hunters linger after the claim", M, "\tTUT_SPAWN.Hunters = hunters\n",
     "\tfor k, v in hunters do TUT_SPAWN.Hunters[k] = v end\n"),
    ("one bonus for any number of hunters", M, "math.min(wanted[kind] + extra * n, cap)", "math.min(wanted[kind] + extra, cap)"),
    ("no cap", M, "math.min(wanted[kind] + extra * n, cap)", "wanted[kind] + extra * n"),
    ("cappedTargets ignores the bonus", M, "local wanted, counts = wantedTargets(zoneCounts), Config.EffectiveMonsterCounts()",
     "local wanted, counts = Config.MonsterTargets(zoneCounts), Config.EffectiveMonsterCounts()"),
    ("targetCount ignores the bonus", M, "return wantedTargets(zoneCounts or playersPerZone())[kind] or 0",
     "return Config.MonsterTargets(zoneCounts or playersPerZone())[kind] or 0"),
    # Config
    ("Config: no Extra", C, "MaxDist = 18, Extra = 3 } }", "MaxDist = 18, Extra = 0 } }"),
    ("Config: the old ring", C, "Tutorial = { StarvedThreshold = 3, MinDist = 10, MaxDist = 18,",
     "Tutorial = { StarvedThreshold = 3, MinDist = 18, MaxDist = 28,"),
    ("Config: threshold 2", C, "Tutorial = { StarvedThreshold = 3,", "Tutorial = { StarvedThreshold = 2,"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mon = read(SSS / "MonsterService.luau")
    reeval = function_block(mon, "local function reevaluate()")
    at = reeval.find("local zoneCounts = playersPerZone()")
    check(0 <= at < reeval.find("cappedTargets(zoneCounts)"),
          "reevaluate refreshes the hunters (playersPerZone) before it reads the targets")
    check("pickSpawnPoint(def, kind)" in function_block(mon, "local function spawnMonster("),
          "spawnMonster passes the kind to pickSpawnPoint (the hunter ring needs it)")
    code = strip_comments(mon)
    check(code.count("Config.MonsterTargets(") == 1
          and "Config.MonsterTargets(" in function_block(mon, "local function wantedTargets("),
          "Config.MonsterTargets is read only through wantedTargets (no target path skips the bonus)")
    check("local SPREAD_COUNT_RADIUS = 30\n" in mon, "starved = monsters within 30 studs (A7-1)")
    config = read(SHARED / "Config.luau")
    check("ReevalInterval = 5 }" in config, "the targets are re-read every 5 s (a new slime within seconds of arrival)")
    return count, failures


SUITE = Suite(
    mark="TUTORIAL_SPAWN",
    fixture=ROOT / "tools/fixtures/tutorial_spawn_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-07/offline_dev2_tutorial_spawn_2026-10-07.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="ideas_first10 §3-#7 (검수 2026-10-07): Config.SpawnSpread.Tutorial = { StarvedThreshold 3, MinDist 10, "
             "MaxDist 18, Extra 3 }. A hunter = TutorialStep Tutorial.Steps.Quest (2) standing in Tutorial.GuideZone "
             "(SlimeMeadow). For the tutorial monster (Slime) a starved hunter (< 3 monsters within 30 studs) is chosen "
             "first and gets the point 10-18 studs away on the half circle facing the zone middle (12 tries); other "
             "starved players (< 2): a Rookie first, then the lowest level, then the fewest near, ring 18-28 (6 tries); "
             "King Slimes and other kinds keep the A7-1 rule. Each hunter in the meadow raises the Slime target by 3 "
             "(never above Count x MaxZoneMult = 24) through targetCount and cappedTargets; the bonus ends when the "
             "hunt ends (playersPerZone refreshes the hunters every pass).",
    limitations="Players, Util (Random seeded, scripted draws), the ground ray (always flat ground) and the monster "
                "count near a player are doubles; the real Studio check (first kill within 10 s after the trip) is game "
                "dev 1's. The season (Config.SeasonOn) follows the machine clock; the checks compare with Config's own "
                "MonsterTargets so they hold either way.",
)

if __name__ == "__main__":
    run(SUITE)
