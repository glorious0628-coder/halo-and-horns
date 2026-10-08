"""A23-81 decor that blocks players only (게임성 개발 3, 2026-10-08), offline.

User 2026-10-08: "나무·풀을 뚫으면 안 되지, 비켜 가야지" -> PlayerService registers the collision group
Config.Player.DecorGroup ("DecorPlayerOnly") next to "Players": collidable with Players, not with Default (monsters,
pets, the rest), not with itself and not with any other group registered by then. Runs PlayerService's collision-group
block (cut out of the CURRENT source) with a PhysicsService double on tools/fixtures/dev2_kit.luau +
tools/fixtures/decor_group_offline.luau and the installed official Luau CLI. Mutations on in-memory copies only.

Usage: py tools/test_decor_group.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_decor_group_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
}
C, P = "CONFIG_SOURCE", "PLAYER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    src = sources["PLAYER_SOURCE"]
    decor = re.search(r"^local DECOR_GROUP = .*$", src, re.M)
    if not decor:
        raise ValueError("Source boundary changed: local DECOR_GROUP; update the test extractor.")
    setup = function_block(src, "local function setupCollisionGroup(")
    extract = ("local PhysicsService, Config, Util = ...\nlocal TAG = \"PlayerService\"\n"
               "local COLLISION_GROUP = Config.Player.CollisionGroup or \"Players\"\n" + decor.group(0) + "\n"
               "local collisionGroupOk = false\n" + setup
               + "\nreturn function() setupCollisionGroup(); return collisionGroupOk end\n")
    return {"CONFIG_SOURCE": sources["CONFIG_SOURCE"], "UTIL_SOURCE": sources["UTIL_SOURCE"], "SETUP_EXTRACT": extract}


MUTATIONS = [
    ("decor never registered", P, "\t\tif not PhysicsService:IsCollisionGroupRegistered(DECOR_GROUP) then\n\t\t\tPhysicsService:RegisterCollisionGroup(DECOR_GROUP)\n\t\tend\n", ""),
    ("players walk through decor", P, "\t\tPhysicsService:CollisionGroupSetCollidable(DECOR_GROUP, COLLISION_GROUP, true)\n",
     "\t\tPhysicsService:CollisionGroupSetCollidable(DECOR_GROUP, COLLISION_GROUP, false)\n"),
    ("monsters blocked by decor", P, "\t\tPhysicsService:CollisionGroupSetCollidable(DECOR_GROUP, \"Default\", false)\n", ""),
    ("decor collides with itself", P, "\t\tPhysicsService:CollisionGroupSetCollidable(DECOR_GROUP, DECOR_GROUP, false)\n", ""),
    ("other groups blocked", P, "\t\t\tif type(name) == \"string\" and name ~= COLLISION_GROUP then\n", "\t\t\tif false then\n"),
    ("one pcall for both groups", P, "\tcollisionGroupOk = ok\n\tif not ok then\n\t\tUtil.Warn(TAG, \"collision group setup failed: \" .. tostring(err))\n\tend\n\t-- A23-81",
     "\tcollisionGroupOk = ok\n\t-- A23-81"),
    ("decor registered twice", P, "\t\tif not PhysicsService:IsCollisionGroupRegistered(DECOR_GROUP) then\n\t\t\tPhysicsService:RegisterCollisionGroup(DECOR_GROUP)\n",
     "\t\tdo\n\t\t\tPhysicsService:RegisterCollisionGroup(DECOR_GROUP)\n"),
    ("Config: another group name", C, "\tDecorGroup = \"DecorPlayerOnly\",\n", "\tDecorGroup = \"Decor\",\n"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    src = read(SSS / "PlayerService.luau")
    init = function_block(src, "function PlayerService.Init(")
    check("setupCollisionGroup()" in init, "PlayerService.Init runs setupCollisionGroup (both groups, before any player)")
    tool = ROOT / "tools/worldkit/meadow_dress.luau"
    if tool.is_file():
        check('PlayerOnlyGroup = "DecorPlayerOnly"' in read(tool), "the worldkit tool uses the same group name")
    return count, failures


SUITE = Suite(
    mark="DECOR_GROUP",
    fixture=ROOT / "tools/fixtures/decor_group_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_decor_group_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-81: PlayerService registers DecorPlayerOnly (Config.Player.DecorGroup) next to Players: collidable with "
             "Players, not with Default, not with itself, not with any other group registered by then; Players x Players "
             "stays off; idempotent when the groups are already registered (saved in the place); a decor failure has its "
             "own pcall and never takes the players' group down.",
    limitations="The real physics are not run offline. Putting decor parts into the group is the 검수 tool "
                "(tools/worldkit/decor_collision.luau) in Studio Edit; in Edit the group must be registered there too (the "
                "server registers it again at runtime). Anchored decor only: a group that skips Default also skips the "
                "terrain.",
)

if __name__ == "__main__":
    run(SUITE)
