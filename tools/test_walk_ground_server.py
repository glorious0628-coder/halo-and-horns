"""The servers' walking ground (게임성 개발 2; halo_restart 2026-10-11 '걷는 바닥 태그'), offline.

Every server ground raycast uses the one rule game dev 1's Shared Ground.luau uses: Config.GroundRoots = Terrain,
workspace.Map.Ground, the bridges (Decor Bridge_* and the world kits' *Props bridge cells / models) and every instance
tagged Config.Ground.Tag "WalkGround" (Util.Tagged; {} when tags cannot be read). MonsterService.getGroundParams (the
monsters' walkable ground, GroundAt, FirstKO get-up) and KaijuService.groundTargets (the stomp ring) run here from the
current sources on instance doubles; ZoneService's water-rescue landing spots run in tools/test_water_rescue.py.

Usage: py tools/test_walk_ground_server.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_walk_ground_server_2026-10-11.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

C, U, M, K = "CONFIG_SOURCE", "UTIL_SOURCE", "MONSTER_SOURCE", "KAIJU_SOURCE"
FILES = {C: SHARED / "Config.luau", U: SHARED / "Util.luau", M: SSS / "MonsterService.luau", K: SSS / "KaijuService.luau"}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    refresh = re.search(r"^local GROUND_PARAMS_REFRESH = .*$", mon, re.M)
    if not refresh:
        raise ValueError("MonsterService GROUND_PARAMS_REFRESH missing; update the test extractor.")
    return {
        C: sources[C],
        U: sources[U],
        "MON_GROUND_EXTRACT": (
            "local Config, Util = ...\n" + refresh.group(0) + "\nlocal groundParams, groundParamsAt = nil, -math.huge\n"
            + function_block(mon, "local function getGroundParams(") + "\nreturn getGroundParams\n"),
        "KAIJU_GROUND_EXTRACT": (
            "local Config, Util = ...\n" + function_block(sources[K], "local function groundTargets(")
            + "\nreturn groundTargets\n"),
    }


MUTATIONS = [
    ("monsters: no tagged floors", M, "\tlocal list = Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild(\"Map\"),\n"
     "\t\tUtil.Tagged((Config.Ground or {}).Tag or \"WalkGround\"))",
     "\tlocal list = Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild(\"Map\"), {})"),
    ("monsters: the whole Map is ground", M, "\tlocal list = Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild(\"Map\"),\n"
     "\t\tUtil.Tagged((Config.Ground or {}).Tag or \"WalkGround\"))",
     "\tlocal list = { workspace.Terrain, workspace:FindFirstChild(\"Map\") }"),
    ("monsters: water ignored", M, "\tparams.IgnoreWater = false\n\tgroundParams, groundParamsAt = params, now",
     "\tparams.IgnoreWater = true\n\tgroundParams, groundParamsAt = params, now"),
    ("monsters: never cached", M, "\tif groundParams and now - groundParamsAt < GROUND_PARAMS_REFRESH then return groundParams end\n", ""),
    ("monsters: never rebuilt", M, "if groundParams and now - groundParamsAt < GROUND_PARAMS_REFRESH then return groundParams end",
     "if groundParams then return groundParams end"),
    ("kaiju: no tagged floors", K, "\treturn Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild(\"Map\"),\n"
     "\t\tUtil.Tagged((Config.Ground or {}).Tag or \"WalkGround\"))",
     "\treturn Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild(\"Map\"), {})"),
    ("kaiju: old bridge-only list", K, "\treturn Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild(\"Map\"),\n"
     "\t\tUtil.Tagged((Config.Ground or {}).Tag or \"WalkGround\"))",
     "\treturn { workspace.Terrain, workspace:FindFirstChild(\"Map\"):FindFirstChild(\"Ground\") }"),
    ("Util.Tagged throws", U, "\tlocal ok, list = pcall(function()\n\t\treturn game:GetService(\"CollectionService\"):GetTagged(tag)\n\tend)",
     "\tlocal ok, list = true, game:GetService(\"CollectionService\"):GetTagged(tag)"),
    ("Util.Tagged passes a non-table", U, "\treturn (ok and type(list) == \"table\") and list or {}\nend\n\nfunction Util.PlayersExcept",
     "\treturn ok and list or {}\nend\n\nfunction Util.PlayersExcept"),
    ("Util.Tagged takes any tag", U, "\tif type(tag) ~= \"string\" then return {} end\n\tlocal ok, list = pcall(function()\n\t\treturn game:GetService(\"CollectionService\"):GetTagged(tag)",
     "\tlocal ok, list = pcall(function()\n\t\treturn game:GetService(\"CollectionService\"):GetTagged(tag)"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    tag_call = 'Util.Tagged((Config.Ground or {}).Tag or "WalkGround")'
    mon = function_block(read(SSS / "MonsterService.luau"), "local function getGroundParams(")
    kai = function_block(read(SSS / "KaijuService.luau"), "local function groundTargets(")
    zone = read(SSS / "ZoneService.luau")
    for name, body in (("MonsterService.getGroundParams", mon), ("KaijuService.groundTargets", kai),
                       ("ZoneService.waterParams", function_block(zone, "local function waterParams("))):
        check("Config.GroundRoots(" in body and tag_call in body and "Bridge_" not in body,
              f"{name}: Config.GroundRoots + the WalkGround tag, no ground list of its own")
    check("Bridge_" not in function_block(zone, "local function walkableHit("), "ZoneService.walkableHit: no ground list of its own")
    ground = read(SHARED / "Ground.luau")
    check("Config.GroundRoots(" in ground and "Config.Ground" in ground, "game dev 1's Ground.luau uses the same Config.GroundRoots")
    cfg = read(SHARED / "Config.luau")
    check('Config.Ground = { Tag = "WalkGround"' in cfg, 'Config.Ground.Tag = "WalkGround"')
    return count, failures


SUITE = Suite(
    mark="WALKGROUND",
    fixture=ROOT / "tools/fixtures/walk_ground_server_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_walk_ground_server_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="halo_restart 2026-10-11: MonsterService.getGroundParams (Include, water not ignored, cached "
             "GROUND_PARAMS_REFRESH s) and KaijuService.groundTargets = Config.GroundRoots(workspace.Terrain, "
             "workspace.Map, Util.Tagged(Config.Ground.Tag)): Terrain, Map.Ground, Decor Bridge_*, the *Props kits' bridge "
             "cells / models, every WalkGround-tagged instance once; never other props or the whole Map; tags unreadable = "
             "none (never thrown). ZoneService.waterParams / walkableHit use the same roots (static here, run in "
             "test_water_rescue).",
    limitations="Instance doubles (no real raycasts); MonsterService's groundPoint / occupied and the kaiju stomp ring "
                "themselves are not run here (test_monster_spacing / test_kaiju_town); the clients' Ground.luau is game "
                "dev 1's test_ground_rays.",
)

if __name__ == "__main__":
    run(SUITE)
