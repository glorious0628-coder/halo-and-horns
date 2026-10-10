"""zone_check_halo #11 / #62 / #63 (검수 2026-10-10): the water rescue, offline.

A live player whose root stays in Terrain water for Config.WaterRescue.Seconds (8) in a row inside a town zone or within
Margin (40) studs of a town rect is moved to the nearest dry land (ZoneService waterTick after the gates; rays and the
body box query in the players' collision group); nothing dry nearby -> the spawn of the town the swimmer is near when the
player may stand there, else the Crossroads spawn. Runs the WHOLE current ZoneService with the real Config / Util / Net on
tools/fixtures/dev2_kit.luau with tools/fixtures/water_rescue_offline.luau (fake Terrain, Raycast, GetPartBoundsInBox,
PhysicsService), with the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls. Mutations run on
in-memory copies of the sources only.

Usage: py tools/test_water_rescue.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev2_water_rescue_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments

C, U, Z = "CONFIG_SOURCE", "UTIL_SOURCE", "ZONE_SOURCE"
FILES = {C: SHARED / "Config.luau", U: SHARED / "Util.luau", Z: SSS / "ZoneService.luau"}


def bindings(sources: dict[str, str]) -> dict[str, str]:
    zone = sources[Z]
    tail = "\nreturn ZoneService\n"
    if not zone.endswith(tail) or zone.count(tail) != 1:
        raise ValueError("ZoneService must end with a single 'return ZoneService'")
    # a test-only hook (never in src): the loop body and the probes the fixture drives
    hook = ("\nZoneService.__WaterTest = { updateZone = updateZone, cleanup = cleanup, water = water, "
            "waterProbe = waterProbe, move = move, nearTown = nearTown }")
    return {C: sources[C], U: sources[U], "ZONE_WATER_SOURCE": zone[:-len(tail)] + hook + tail}


MUTATIONS = [
    ('no water tick in the zone loop', Z, '\tlocal okW, errW = pcall(waterTick, player, root)\n',
     '\tlocal okW, errW = true, nil\n'),
    ('no pcall around the water tick', Z, 'pcall(waterTick, player, root)',
     'true, waterTick(player, root)'),
    ('rescued on the first wet sample', Z, '\tif now - st.Since < wrNum("Seconds", 8) then return end\n',
     ''),
    ('half the time', Z, 'now - st.Since < wrNum("Seconds", 8)',
     'now - st.Since < wrNum("Seconds", 8) / 2'),
    ('a swim jump restarts the count', Z, 'now - st.DrySince >= wrNum("DryReset", 1.5)',
     'now - st.DrySince >= 0'),
    ('leaving the water never restarts the count', Z, '\t\tif st.DrySince and now - st.DrySince >= wrNum("DryReset", 1.5) then st.Since, st.DrySince = nil, nil end\n',
     ''),
    ('no margin', Z, '\tlocal margin = wrNum("Margin", 40)\n',
     '\tlocal margin = 0\n'),
    ('every zone counts as a town', Z, '\t\tif z and z.Town == true and',
     '\t\tif z and'),
    ('no root slack', Z, 'surface < pos.Y - wrNum("RootSlack", 1)',
     'surface < pos.Y'),
    ('a basin counts', Z, 'surface < pos.Y - wrNum("RootSlack", 1)',
     'surface < pos.Y - 3'),
    ('no sample throttle', Z, '\tst.NextAt = now + wrNum("CheckEvery", 0.5)\n',
     '\tst.NextAt = now\n'),
    ('Terrain read away from the towns', Z, 'local surface = nearTown(pos) and waterProbe.Surface(pos) or nil',
     'local surface = (nearTown(pos) or true) and waterProbe.Surface(pos) or nil'),
    ('a new character keeps the count', Z, '\tif not st or st.Char ~= char then\n',
     '\tif not st then\n'),
    ('roofs are shore', Z, 'if hit and hit.Walkable == true\n',
     'if hit\n'),
    ('wet spots are shore', Z, '\t\t\t\tand hit.Material ~= Enum.Material.Water\n',
     ''),
    ('a ledge under DryAbove is shore', Z, '\t\t\t\tand y >= minY\n',
     ''),
    ('no MaxRise', Z, '\t\t\t\tand y <= maxY\n',
     ''),
    ('steep is shore', Z, '\t\t\t\tand hit.NormalY >= minNormal\n',
     ''),
    ('first found wins (no lowest climb)', Z, '\t\t\t\tand y - surface < bestRise\n',
     '\t\t\t\tand best == nil\n'),
    ('lava is shore', Z, '\t\t\t\tand not avoidFloor(hit.Material)\n',
     ''),
    ('enemy towns are shore', Z, '\t\t\t\tand allowedAt(player, hit.Position)\n',
     ''),
    ('no room check', Z, '\t\t\t\tand waterProbe.Clear(hit.Position + Vector3.new(0, 0.5 + stand, 0), box) then\n',
     '\t\t\t\tthen\n'),
    ('the rings never stop at a hit', Z, '\t\tif best then return best end\n',
     ''),
    ('no CR-H2 grace on the shore move', Z, '\t\tmarkTeleported(player) -- CR-H2: the move to the shore is not a suspicious move\n',
     ''),
    ('no lift', Z, 'math.max(stand + 0.5, wrNum("Lift", 4))',
     '0'),
    ('faces the water', Z, 'CFrame.lookAt(at, at + away)',
     'CFrame.lookAt(at, at - away)'),
    ('velocity kept', Z, '\t\troot.AssemblyLinearVelocity = Vector3.zero\n\telse\n',
     '\telse\n'),
    ('no line', Z, 'notify(player, fmt("WaterRescue"), "info", "None")',
     'notify(player, nil, "info", "None")'),
    ('the line with a sound', Z, 'fmt("WaterRescue"), "info", "None")',
     'fmt("WaterRescue"), "info")'),
    ('Toast ignored', Z, '\tif Config.WaterRescue.Toast ~= false then\n',
     '\tif true then\n'),
    ('state kept after leaving', Z, '\twater[player] = nil -- water rescue',
     '\tlocal _ = nil -- water rescue'),
    ('surface ignores the occupancy', Z, 'top = y0 + (j - 1) * r + r * math.min(occ, 1)',
     'top = y0 + j * r'),
    ('the lowest wet voxel decides', Z, '\tfor j = 1, 3 do\n',
     '\tfor j = 3, 1, -1 do\n'),
    ('a column off the voxel grid', Z, 'math.floor(pos.Y / r) * r - r',
     'pos.Y - r'),
    ('a film counts as water', Z, 'occ > 0.02 then top',
     'occ > 0 then top'),
    ('solid-material water ignored', Z, '\t\tif voxel(mats, j) == Enum.Material.Water then occ = math.max(occ, tonumber(voxel(occs, j)) or 0) end\n',
     ''),
    ('only LiquidOccupancy read', Z, '{ "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }',
     '{ "LiquidOccupancy" }'),
    ('no ReadVoxels fallback', Z, '\t\tif not okV or type(m) ~= "table" or type(o) ~= "table" then return nil end\n',
     '\t\tdo return nil end\n'),
    ('rays ignore water', Z, '\tparams.IgnoreWater = false\n',
     '\tparams.IgnoreWater = true\n'),
    ('rays see characters (Exclude)', Z, '\tparams.FilterType = Enum.RaycastFilterType.Include\n',
     '\tparams.FilterType = Enum.RaycastFilterType.Exclude\n'),
    ('non-colliding parts stop the rays', Z, '\tpcall(function() params.RespectCanCollide = true end)\n',
     ''),
    ('ray params never rebuilt', Z, 'now - waterProbe.ParamsAt < 5',
     'true'),
    ('any Decor child is a bridge', Z, '(parent.Name == "Decor" and string.sub(node.Name, 1, 7) == "Bridge_")',
     '(parent.Name == "Decor")'),
    ('any Ground is the map ground', Z, '(node.Name == "Ground" and parent.Name == "Map" and parent.Parent == workspace)',
     '(node.Name == "Ground")'),
    ('a room error reads as room', Z, 'return ok and type(parts) == "table" and #parts == 0',
     'return not ok or #parts == 0'),
    ('non-colliding parts take the room', Z, '\tpcall(function() overlap.RespectCanCollide = true end)\n',
     ''),
    ('Config: off', C, 'Config.WaterRescue = {\n\tEnabled = true,',
     'Config.WaterRescue = {\n\tEnabled = false,'),
    ('Config: 80 s', C, '\tSeconds = 8, -- in water this long in a row',
     '\tSeconds = 80, -- in water this long in a row'),
    ('Config: 4-stud margin', C, '\tMargin = 40, -- studs around each town rect',
     '\tMargin = 4, -- studs around each town rect'),
    ('Config: slack 4', C, '\tRootSlack = 1, -- in water',
     '\tRootSlack = 4, -- in water'),
    ('Config: steep landings', C, '\tMaxSlope = 40, -- degrees',
     '\tMaxSlope = 89, -- degrees'),
    ('Config: no lava rule', C, '\tAvoidMaterials = { "CrackedLava" },',
     '\tAvoidMaterials = {},'),
    ('Config: no line', C, '\tWaterRescue = "Splash! Back on dry land.",',
     '\tWaterRescue = nil,'),
    ('no fallback', Z, '\t\tteleport(player, fallbackZone(player, pos))\n',
     '\t\tlocal _ = fallbackZone\n'),
    ('the fallback is the home town', Z, '\t\tteleport(player, fallbackZone(player, pos))\n',
     '\t\tteleport(player, Config.HomeZoneId(getFaction(player)))\n'),
    ("the other side's town as fallback", Z, ' and forbiddenTownText(player, town) == nil then return town.Id end',
     ' then return town.Id end'),
    ('the near town never used', Z, '\tif town and getLevel(player) >= town.MinLevel',
     '\tif false and town and getLevel(player) >= town.MinLevel'),
    ('rays in the Default group', Z, '\t\tpcall(function() params.CollisionGroup = group end)\n',
     ''),
    ('box in the Default group', Z, '\t\tpcall(function() overlap.CollisionGroup = group end)\n',
     ''),
    ('group set even when not registered', Z, '\tif okG and registered == true then\n',
     '\tif true then\n'),
    ('R6 legs ignored', Z, '\t\tstand += (leg and leg:IsA("BasePart")) and leg.Size.Y or 2\n',
     ''),
]


def static_checks(sources: dict[str, str]) -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok, message):
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    zone, cfg = sources[Z], sources[C]
    upd = function_block(zone, "local function updateZone(")
    a, b = upd.find("applyZone(player, zone, root.Position)"), upd.find("pcall(waterTick, player, root)")
    check(0 <= a < b, "updateZone: the water tick runs after the gates and applyZone, in its own pcall")
    check("water[player] = nil" in function_block(zone, "local function cleanup("), "cleanup forgets the water state")
    section = strip_comments(between(zone, "------------------------------------------------------------------ water rescue",
                                     "-- the zone-loop body"))
    for word in ("task.wait", "wait(", "GetState", "FloorMaterial", "TouchedWater", "Swimming", "spawn(", "delay("):
        check(word not in section, f"the water rescue reads the Terrain, never the client's humanoid state, and never yields ({word})")
    halo = read(ROOT / "tools/worldkit/halo_terrain.luau")
    m1 = re.search(r"WaterTop = (-?[\d.]+), -- Terrain water surface", cfg)
    m2 = re.search(r"R = 4, Lift = 2, WaterTop = (-?[\d.]+)", halo)
    check(bool(m1 and m2) and float(m1.group(1)) == float(m2.group(1)),
          "Config.Map.WaterTop = halo_terrain G.WaterTop (the canals the rule is sized for)")
    ps = read(SSS / "PlayerService.luau")
    m3 = re.search(r"^local MAX_SLOPE_ANGLE = (\d+)", ps, re.M)
    m4 = re.search(r"\tMaxSlope = (\d+), -- degrees", cfg)
    check(bool(m3 and m4) and int(m4.group(1)) < int(m3.group(1)), "a landing slope the player can walk off (MaxSlope < MAX_SLOPE_ANGLE)")
    return count, failures


def static() -> tuple[int, list[str]]:
    return static_checks({C: read(FILES[C]), Z: read(FILES[Z])})


SUITE = Suite(
    mark="WATERRESCUE",
    fixture=ROOT / "tools/fixtures/water_rescue_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev2_water_rescue_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="zone_check_halo #11 / #62 / #63: ZoneService.updateZone runs waterTick (pcall) after the gates and applyZone. "
             "In a town zone or within Config.WaterRescue.Margin studs of a town rect, a live player whose root is in "
             "Terrain water (ReadVoxelChannels at the root, RootSlack) for Seconds in a row (a dry spell of DryReset "
             "restarts it; a new character restarts it) is moved to the nearest dry land: rings of downward rays "
             "(Include Terrain / Map.Ground / Decor Bridge_*, IgnoreWater false, RespectCanCollide, the players' "
             "collision group when registered), a walkable non-water hit DryAbove..MaxRise above the surface, slope "
             "<= MaxSlope, not AvoidMaterials (CrackedLava), allowed for the player (level, enemy town), with room for "
             "the body (GetPartBoundsInBox; R6 legs counted); the lowest climb in the first ring that has one wins; "
             "markTeleported, PivotTo facing inland, zero velocity, one Toast line (Config.Text.WaterRescue, Sound None). "
             "Nothing dry: the near town's spawn when the player may stand there, else the Crossroads spawn. cleanup "
             "forgets the state.",
    limitations="The engine's ReadVoxelChannels values, a swimmer's real root height and the collision-group queries are "
                "faked; 메인 반영 1 checks the canals, the outer sea, the spring basins and the bridges in Play.",
)

if __name__ == "__main__":
    run(SUITE)
