"""Monster levels for the nametag danger colour (게임성 개발 2, 2026-10-09; system_review_round1_2026-10-09 #6), offline.

Config.MonsterLevels (every kind, inside its field's band: meadow 1-9, woods 10-24, ruins 25+, the Halloween fields
Lv1 fields; the plain kind lowest, bosses on top), Config.MonsterLevel(kind) (else the zone's MinLevel) and
game dev 1's Config.MonsterDanger.Tier / LevelOf read the Level attribute (checked on these levels).
MonsterService puts the Level attribute on every monster model at spawn (checked as source text); the fights never
read it. Runs the CURRENT Config on tools/fixtures/dev2_kit.luau + tools/fixtures/monster_level_offline.luau with the
installed official Luau CLI. No Studio, network, DataStore or Roblox API calls.

Usage: py tools/test_monster_level.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev2_monster_level_2026-10-09.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "MONSTER_SOURCE": SSS / "MonsterService.luau",
}
C, M = "CONFIG_SOURCE", "MONSTER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return {"CONFIG_SOURCE": sources[C], "UTIL_SOURCE": sources["UTIL_SOURCE"],
            "SPAWN_SOURCE": function_block(sources[M], "local function spawnMonster(")}


MUTATIONS = [
    ("the slime as strong as the prince", C, "\tSlime = 2, FlowerSlime = 3, BigSlime = 5,", "\tSlime = 5, FlowerSlime = 3, BigSlime = 5,"),
    ("the brute out of the woods band", C, "SlingshotGoblin = 14, GoblinBrute = 18,", "SlingshotGoblin = 14, GoblinBrute = 26,"),
    ("a kind without a level", C, "Skeleton = 26, SkeletonArcher = 28,", "Skeleton = 26,"),
    ("the captain under the knight", C, "SkeletonKnight = 30, CaptainClatter = 32,", "SkeletonKnight = 30, CaptainClatter = 29,"),
    ("no zone fallback", C, "\treturn zone and zone.MinLevel or 1\n", "\treturn 1\n"),
    ("no Level attribute", M, "\trig.Model:SetAttribute(\"Level\", Config.MonsterLevel(kind))\n", ""),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mon = read(SSS / "MonsterService.luau")
    spawn = function_block(mon, "local function spawnMonster(")
    at = spawn.find('rig.Model:SetAttribute("Level", Config.MonsterLevel(kind))')
    check(0 <= at < spawn.find("rig.Model.Parent = getMonstersFolder()"), "spawnMonster sets Level before the model is parented")
    check('GetAttribute("Level")' not in mon.replace('info.Player:GetAttribute("Level")', "")
          .replace('p:GetAttribute("Level")', ""), "the fights never read a monster's Level attribute")
    return count, failures


SUITE = Suite(
    mark="MONSTERLEVEL",
    fixture=ROOT / "tools/fixtures/monster_level_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev2_monster_level_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="system_review_round1 #6: every monster model has the attribute Level = Config.MonsterLevel(kind) "
             "(Config.MonsterLevels, else the zone's MinLevel); game dev 1's Config.MonsterDanger.Tier / LevelOf colour "
             "the nametag from it. The server's fights never read it.",
    limitations="Config only + MonsterService as source text; the nametag colour is game dev 1's.",
)

if __name__ == "__main__":
    run(SUITE)
