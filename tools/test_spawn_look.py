"""Halo town spawn faces the way out (zone_check_halo_2026-10-10 #43, 게임성 개발 3), offline.

While the first mission is open (TutorialStep < Config.Tutorial.Steps.Done: the spawn right after the faction pick, a KO in
town before the claim) a town spawn faces Config.Zones[town].SpawnLook (HaloTown (0,0,-330), HornsTown (0,0,330) = the gate
at the bridge end, where the Crossroads Forge lies) instead of the town middle; a finished first mission, a zone without
SpawnLook (the Crossroads, the meadow) and every Travel spawn keep facing the zone middle. Cuts ZoneService.GetSpawnCFrame
with its spawn constants and PlayerService stat / respawnZoneId / firstMissionOpen / spawnCFrame from the CURRENT sources
(with the CURRENT Config) and runs them on tools/fixtures/dev2_kit.luau doubles with tools/fixtures/spawn_look_offline.luau and
the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_spawn_look.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_spawn_look_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "ZONE_SOURCE": SSS / "ZoneService.luau",
    "PLAYER_SOURCE": SSS / "PlayerService.luau",
}
C, Z, P = "CONFIG_SOURCE", "ZONE_SOURCE", "PLAYER_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    zone, ply = sources[Z], sources[P]
    consts = []
    for pattern in (r"^local DEFAULT_ZONE = .*$", r"^local SPAWN_JITTER = .*$", r"^local SPAWN_LIFT = .*$"):
        found = re.search(pattern, zone, re.M)
        if not found:
            raise ValueError(f"ZoneService constant {pattern!r} missing; update the test extractor.")
        consts.append(found.group(0))
    return {
        "CONFIG_SOURCE": sources[C],
        "SPAWN_EXTRACT": (
            "local Config, Util, S = ...\n"
            "local TAG = \"PlayerService\"\n"
            + "\n".join(consts) + "\n"
            + function_block(ply, "local function stat(") + "\n"
            + function_block(ply, "local function respawnZoneId(") + "\n"
            + function_block(ply, "local function firstMissionOpen(") + "\n"
            + function_block(ply, "local function spawnCFrame(") + "\n"
            + "local ZoneService = {}\n"
            + function_block(zone, "function ZoneService.GetSpawnCFrame(") + "\n"
            + "return { stat = stat, respawnZoneId = respawnZoneId, firstMissionOpen = firstMissionOpen, spawnCFrame = spawnCFrame, "
              "ZoneService = ZoneService }\n"),
    }


MUTATIONS = [
    # --- Config
    ("Config: Halo looks at the town middle", C, "SpawnLook = Vector3.new(0, 0, -330) },", "SpawnLook = Vector3.new(0, 0, -515) },"),
    ("Config: Halo looks the wrong way", C, "SpawnLook = Vector3.new(0, 0, -330) },", "SpawnLook = Vector3.new(0, 0, -600) },"),
    ("Config: Horns looks at the town middle", C, "SpawnLook = Vector3.new(0, 0, 330) },", "SpawnLook = Vector3.new(0, 0, 515) },"),
    ("Config: Horns has no look", C, "\t\tSpawnLook = Vector3.new(0, 0, 330) }, -- same for Horns Den (the gate at the bridge end)", "\t\t}, -- same for Horns Den (the gate at the bridge end)"),
    # --- ZoneService
    ("zone: the look is never used", Z, "local target = faceOut == true and typeof(zone.SpawnLook) == \"Vector3\" and zone.SpawnLook or zone.Center",
     "local target = zone.Center"),
    ("zone: the look is always used", Z, "local target = faceOut == true and typeof(zone.SpawnLook) == \"Vector3\" and zone.SpawnLook or zone.Center",
     "local target = typeof(zone.SpawnLook) == \"Vector3\" and zone.SpawnLook or zone.Center"),
    ("zone: any truthy faceOut", Z, "local target = faceOut == true and", "local target = faceOut ~= nil and faceOut ~= false and"),
    ("zone: a zone without a look breaks", Z, "typeof(zone.SpawnLook) == \"Vector3\" and zone.SpawnLook or zone.Center", "zone.SpawnLook"),
    ("zone: the look keeps its own height", Z, "local look = Vector3.new(target.X, pos.Y, target.Z)", "local look = Vector3.new(target.X, target.Y, target.Z)"),
    ("zone: no jitter", Z, "base.X + Util.Random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER),", "base.X,"),
    # --- PlayerService
    ("player: the look is never asked for", P, "pcall(zs.GetSpawnCFrame, zoneId, faceOut == true)", "pcall(zs.GetSpawnCFrame, zoneId, false)"),
    ("player: the look is always asked for", P, "pcall(zs.GetSpawnCFrame, zoneId, faceOut == true)", "pcall(zs.GetSpawnCFrame, zoneId, true)"),
    ("player: a finished mission still looks out", P, "step < steps.Done", "step <= steps.Done"),
    ("player: only the first step looks out", P, "step < steps.Done", "step == 0"),
    ("player: nobody looks out", P, "step < steps.Done", "false"),
    ("player: the step is read from the wrong key", P, "stat(player, \"TutorialStep\", 0)\n\treturn type(steps.Done)", "stat(player, \"TutorialKills\", 0)\n\treturn type(steps.Done)"),
    ("player: no step counts as a finished mission", P, "local step = stat(player, \"TutorialStep\", 0)\n\treturn type(steps.Done)",
     "local step = stat(player, \"TutorialStep\", 99)\n\treturn type(steps.Done)"),
    ("player: the fallback spawn is kept for a missing zone service", P, "local z = Config.Zones[zoneId] or Config.Zones.Crossroads\n\treturn CFrame.new(z.Spawn",
     "local z = Config.Zones[zoneId] or Config.Zones.Crossroads\n\treturn CFrame.new(z.Center"),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    ply = read(SSS / "PlayerService.luau")
    code = strip_comments(ply)
    check(code.count("spawnCFrame(respawnZoneId(player), firstMissionOpen(player))") == 1,
          "the only spawn of a new character passes the first-mission flag")
    check(code.count("spawnCFrame(") == 2, "spawnCFrame has the definition and one call")
    zone = strip_comments(read(SSS / "ZoneService.luau"))
    check("character:PivotTo(ZoneService.GetSpawnCFrame(zoneId))" in zone,
          "a travel spawn (ZoneService.teleport) never faces out: no second argument")
    check(not re.search(r"[가-힣]", zone.split("function ZoneService.GetSpawnCFrame", 1)[1].split("\nend\n", 1)[0]),
          "GetSpawnCFrame: no Korean outside comments")
    return count, failures


SUITE = Suite(
    mark="SPAWN_LOOK",
    fixture=ROOT / "tools/fixtures/spawn_look_offline.luau",
    world=None,
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_spawn_look_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Zone_check_halo #43: a town spawn faces Config.Zones[town].SpawnLook (HaloTown (0,0,-330), HornsTown (0,0,330): the "
             "gate at the bridge end) while TutorialStep < Done (the first mission is open: the spawn after the faction pick, a "
             "KO in town); a finished mission and a zone without SpawnLook face the zone middle; a travel spawn "
             "(ZoneService.teleport) is unchanged. The spawn point (Spawn + jitter +-6 + 4 up) is unchanged.",
    limitations="CharacterAdded / PivotTo and the faction-pick flow (FactionService -> PlayerService.Respawn) are not run; the "
                "extracted functions and the one call site are checked (static).",
)

if __name__ == "__main__":
    run(SUITE)
