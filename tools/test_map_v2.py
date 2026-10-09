"""World map v2 (SPEC A23-53) offline checks with mutations (게임성 개발 1, P1 of the map move).

Runs the CURRENT Config.luau, the data block of tools/preview_map.lua and the v2 layout
(docs/design/world_map_v2_2026-10-06.json) in tools/fixtures/map_v2_offline.luau with the installed official Luau CLI
(build/luau_cli_0_741):
- zones: every zone = its v2 land rectangle, spawns = the layout (the Crossroads keeps (0, -25)), inside their zone and on
  their own land, ZoneAt in / out of season, levels, PvP only in the woods and the ruins, no PvP zone overlapping a safe
  one, the three towns;
- lands: = the layout, LandPass = the mountain band (PassX / PassHalfZ), no overlaps, 20+ studs of sea to Bounds, every
  land inside image dev's big map picture UIP_WorldMapV2 (its map transform) and the picture covering Bounds;
- links: bridges = the layout and shore to shore, gates = the layout and on their zone borders, every road on land, no
  road through a kit landmark (King Slime Hill, pond, pumpkin house, ghost willow, treehouse trunk, broken tower, crown
  altar), the crown road and the town roads end to end, the travel pads in the Crossroads and off every road;
- halloween: Config.Map.Halloween (path, north / west gate, sign) fits the two fields and their season roads, the pumpkin
  king / ghost king spots (+ SpawnRadius) in the far half of their field and clear of the landmarks, the hollow props;
- places: the story spots (pond, WoodsGate, bridge ends, kids' bench, goblin camps, boards, hero statue, lava crack), the
  goose perch and the potion seller;
- preview: tools/preview_map.lua's tables = Config.
Static checks: QuestTarget / MapBuilder read Config.Map.Halloween, HUD's pond spot = Config + 3, the Intro town shots in
the towns, MapBuilder re-fits reused zone markers / walls / gates, preview_map defaults to "terrain" (never wipes the
Map), the mover defaults to a dry run, the Studio runner refuses outside Edit.
Mutations: in-memory copies with one rule broken each; each must fail a check that passes on the real sources. Status
"passed" only when everything passes AND every mutation was applied and caught (--no-mutations: "passed-no-mutations").

Usage: py tools/test_map_v2.py [--no-mutations]
Report: docs/art/verification_2026-10-07/offline_map_v2_2026-10-07.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {
    "config": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "mapbuilder": ROOT / "src/ServerScriptService/MapBuilder.luau",
    "questtarget": SPS / "QuestTarget.luau",
    "hud": SPS / "HUD.luau",
    "intro": SPS / "Intro.luau",
    "preview": ROOT / "tools/preview_map.lua",
    "move": ROOT / "tools/map_v2_move.lua",
    "apply": ROOT / "tools/map_v2_apply.py",
    "war": ROOT / "src/ServerScriptService/WarService.luau",
}
LAYOUT = ROOT / "docs/design/world_map_v2_2026-10-06.json"
FIXTURE = ROOT / "tools/fixtures/map_v2_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_map_v2_2026-10-07.json"

PREVIEW_START = "local ZONES = {"
PREVIEW_END = "------------------------------------------------------------------ Map 폴더 + 보관함"
TERRAIN_RETURN = 'if MODE == "terrain" then\n\tif fresh then map.Parent = workspace end'

# (name, file key, old, new): each old must match exactly once
MUTATIONS = [
    ("HaloTown centre back to v1", "config",
     'HaloTown = { Id = "HaloTown", Name = "Halo Citadel", Center = Vector3.new(0, 0, -515)',
     'HaloTown = { Id = "HaloTown", Name = "Halo Citadel", Center = Vector3.new(0, 0, -400)'),
    ("meadow spawn in the river", "config", "Spawn = Vector3.new(230, 0, 0) },", "Spawn = Vector3.new(200, 0, 0) },"),
    ("pumpkin king spot in the near half", "config", "Vector3.new(470, 0, 390)", "Vector3.new(470, 0, 300)"),
    ("ghost king on the ghost willow", "config", "Vector3.new(260, 0, 300)", "Vector3.new(300, 0, 360)"),
    ("goose out of the Crossroads", "config", "Position = Vector3.new(-30, 0, 30), -- Crossroads plaza",
     "Position = Vector3.new(-30, 0, 200), -- Crossroads plaza"),
    ("slime pond in the hollow", "config", "SlimePond = Vector3.new(290, 0, 150)", "SlimePond = Vector3.new(290, 0, 300)"),
    ("WoodsGate inside the PvP woods", "config", "Landmarks.WoodsGate = Vector3.new(636, 0, 0)",
     "Landmarks.WoodsGate = Vector3.new(720, 0, 0)"),
    ("QuestTarget sign back to the v1 spot", "questtarget", "Sign = HW_SIGN + Vector3.new(0, 3, 0),",
     "Sign = Vector3.new(368, 3, 136),"),
    ("HUD pond spot back to v1", "hud", "local STORY_SPOT = { SlimePond = Vector3.new(290, 3, 150) }",
     "local STORY_SPOT = { SlimePond = Vector3.new(280, 3, -45) }"),
    ("potion seller on the north road", "config", "PotionMerchantOffset = { X = 12, Z = -9 }", "PotionMerchantOffset = { X = 2, Z = -9 }"),
    ("Halo Citadel allows PvP", "config", 'MinLevel = 1, PvP = false, Town = true, Faction = "Halo",',
     'MinLevel = 1, PvP = true, Town = true, Faction = "Halo",'),
    ("pumpkin land overlaps the hollow", "config", '{ Name = "LandPumpkinPatch", MinX = 420,', '{ Name = "LandPumpkinPatch", MinX = 400,'),
    ("Bounds cut the ruins", "config", "Bounds = { MinX = -260, MaxX = 1840,", "Bounds = { MinX = -260, MaxX = 1700,"),
    ("Halo bridge ends in the water", "config", "To = Vector3.new(0, 0, -330), Width = 22", "To = Vector3.new(0, 0, -300), Width = 22"),
    ("ruins gate off the zone border", "config", '{ Zone = "SkeletonRuins", Position = Vector3.new(1260, 0, 0) },',
     '{ Zone = "SkeletonRuins", Position = Vector3.new(1225, 0, 0) },'),
    ("meadow ring road over the King Slime Hill", "config", "MinX = 260, MaxX = 600, MinZ = -125, MaxZ = -115",
     "MinX = 260, MaxX = 600, MinZ = -175, MaxZ = -165"),
    ("MapBuilder west gate back to v1", "mapbuilder", 'WestGateZ = (typeof(HW.HollowGate) == "Vector3" and HW.HollowGate.Z) or 340,',
     "WestGateZ = 245,"),
    ("preview meadow land narrower than Config", "preview", '{ Name = "LandMeadow", MinX = 210, MaxX = 650,',
     '{ Name = "LandMeadow", MinX = 210, MaxX = 640,'),
    ("Intro Halo shot back over the sea", "intro", "Halo = Vector3.new(0, 16, -410),", "Halo = Vector3.new(0, 16, -300),"),
    ("hollow gate off the shared edge", "config", "HollowGate = Vector3.new(420, 0, 340)", "HollowGate = Vector3.new(400, 0, 340)"),
    ("preview_map wipes the Map by default", "preview", 'if MODE ~= "full" then MODE = "terrain" end',
     'if MODE ~= "terrain" then MODE = "full" end'),
    ("the mover applies by default", "move", 'if MODE ~= "apply" then MODE = "dry" end', 'if MODE ~= "dry" then MODE = "apply" end'),
    ("MapBuilder stops moving reused gates", "mapbuilder", "\t\t\telseif placeGate(gate, entry.Position) then\n",
     "\t\t\telseif false then\n"),
    ("goblin camp 3 back on its v1 spot (the river)", "config", "Landmarks.GoblinCamp3 = Vector3.new(1090, 0, -150)",
     "Landmarks.GoblinCamp3 = Vector3.new(660, 0, -60)"),
    ("meadow board on the crown road", "config", "Landmarks.MeadowBoard = Vector3.new(230, 0, 12)",
     "Landmarks.MeadowBoard = Vector3.new(230, 0, 5)"),
    ("hero statue outside Halo Citadel", "config", "Landmarks.HeroStatue = Vector3.new(0, 0, -370)",
     "Landmarks.HeroStatue = Vector3.new(0, 0, -300)"),
    ("MapBuilder no longer re-fits reused walls", "mapbuilder",
     '\t\t\tif fitWall(wall, specs[name]) then Util.Log(TAG, "moved " .. name .. " onto Config.Map.Bounds") end\n', ""),
    ("the ruins road runs into the crown altar", "config", '{ Name = "RoadRuins", MinX = 1260, MaxX = 1684,',
     '{ Name = "RoadRuins", MinX = 1260, MaxX = 1760,'),
    # 검수 10/09 roads
    ("RoadSouth back to near-black red", "config", "RoadSouth = { Color = Color3.fromRGB(150, 115, 105)",
     "RoadSouth = { Color = Color3.fromRGB(70, 45, 45)"),
    ("preview RoadNorth keeps the old flat color", "preview", "MaxZ = -10, Color = RGB(170, 150, 130), Material = Enum.Material.Slate },",
     "MaxZ = -10, Color = RGB(215, 205, 185), Material = SP },"),
    ("FitRoads no longer cuts at the plaza", "mapbuilder", "\t\tif math.abs(c.X) < r and near < r and (c.Z - half) * (c.Z + half) >= 0 then\n",
     "\t\tif false then\n"),
    ("FitRoads cuts the far end", "mapbuilder", "\t\t\t\tp.CFrame = CFrame.new(c.X, c.Y, s * (r + far) / 2)\n",
     "\t\t\t\tp.CFrame = CFrame.new(c.X, c.Y, s * (r + near) / 2)\n"),
    ("FitRoads does not hide a part fully inside", "mapbuilder", "\t\t\t\tp.Transparency = 1\n", ""),
    ("Build never runs FitRoads", "mapbuilder", "pcall(MapBuilder.FitRoads, folders.Decor)", "pcall(function() end)"),
    ("preview stops cutting the south road", "preview", "if minZ >= 0 and minZ < ROAD_PLAZA_R then minZ = ROAD_PLAZA_R end", ""),
    ("Config.Map.Roads cut instead of the parts", "config", '{ Name = "RoadSouth", MinX = -8, MaxX = 8, MinZ = 10, MaxZ = 150 },',
     '{ Name = "RoadSouth", MinX = -8, MaxX = 8, MinZ = 60, MaxZ = 150 },'),
]


def lua_long(text: str) -> str:
    eq = "===="
    while f"]{eq}]" in text:
        eq += "="
    return f"[{eq}[{text}]{eq}]"


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return lua_long(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(x)}" if re.fullmatch(r"[A-Za-z_]\w*", k) else f"[ {lua_long(k)} ] = {lua_value(x)}"
                                for k, x in v.items()) + " }"
    return "nil"


def layout_lua(layout: dict) -> str:
    keep = {
        "zones": [{k: z[k] for k in ("id", "land", "spawn", "lv", "pvp", "season") if k in z} for z in layout["zones"]],
        "pass": {"land": layout["pass"]["land"]},
        "bridges": [{"from": b["from"], "to": b["to"], "width": b["width"]} for b in layout["bridges"]],
        "gates": [{"at": g["at"]} for g in layout["gates"]],
    }
    return lua_value(keep)


def preview_source(preview: str) -> str:
    a, b = preview.find(PREVIEW_START), preview.find(PREVIEW_END)
    if a < 0 or b < 0 or b < a:
        raise ValueError("tools/preview_map.lua: the v2 data block is missing; update the extractor")
    return ("local RGB = Color3.fromRGB\nlocal SP = Enum.Material.SmoothPlastic\nlocal NEON = Enum.Material.Neon\n" + preview[a:b]
            + "\nreturn { ZONES = ZONES, ZONE_ORDER = ZONE_ORDER, BOUNDS = BOUNDS, WALL_HEIGHT = WALL_HEIGHT, WATER_TOP = WATER_TOP, "
              "LANDS = LANDS, BRIDGES = BRIDGES, ROADS = ROADS, GATES = GATES, PASS = PASS, ALTAR = ALTAR, BOARD = BOARD, "
              "GOOSE_NEST = GOOSE_NEST, PADS = PADS, HW = HW }\n")


def hollow_uv(mapbuilder: str) -> str:
    m = re.search(r"\nlocal HOLLOW = \{.*?\n\tProps = \{\n(.*?)\n\t\},\n\}", mapbuilder, re.S)
    if not m:
        raise ValueError("MapBuilder.luau: HOLLOW.Props is missing; update the extractor")
    pairs = re.findall(r'\{ "GF_\w+", (-?[0-9.]+), (-?[0-9.]+),', m.group(1))
    if not pairs:
        raise ValueError("MapBuilder.luau: HOLLOW.Props has no (U, V) entries")
    return "{ " + ", ".join(f"{{ {u}, {v} }}" for u, v in pairs) + " }"


def fitroads_source(mapbuilder: str) -> str:
    m = re.search(r"\nfunction MapBuilder\.FitRoads\(decor\)\n.*?\nend\n", mapbuilder, re.S)
    if not m:
        raise ValueError("MapBuilder.luau: MapBuilder.FitRoads is missing; update the extractor")
    return m.group(0)


def vec_of(text: str, pattern: str):
    m = re.search(pattern, text)
    return tuple(float(x) for x in m.groups()) if m else None


def static_checks(src: dict[str, str], values: dict | None) -> list[tuple[str, bool]]:
    qt, hud, intro, mb, pv, mv, ap = (src["questtarget"], src["hud"], src["intro"], src["mapbuilder"], src["preview"], src["move"],
                                      src["apply"])
    out: list[tuple[str, bool]] = []
    out.append(("QuestTarget takes the Halloween sign / passage / hollow gate from Config.Map.Halloween",
                'local HW = type(Config.Map) == "table" and type(Config.Map.Halloween) == "table" and Config.Map.Halloween or {}' in qt
                and "Sign = HW_SIGN + Vector3.new(0, 3, 0)," in qt
                and "Passage = { MinX = HW_PATH_X - 9, MaxX = HW_PATH_X + 9, MinZ = HW_SIGN.Z - 4, MaxZ = HW_GATE_Z + 12 }," in qt
                and 'Gate = (typeof(HW.HollowGate) == "Vector3" and HW.HollowGate or Vector3.new(420, 0, 340)) + Vector3.new(0, 3, 0),' in qt))
    pond = values and values.get("SlimePond")
    hud_spot = vec_of(hud, r"local STORY_SPOT = \{ SlimePond = Vector3\.new\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\) \}")
    qt_spot = vec_of(qt, r"return typeof\(spot\) == \"Vector3\" and \(spot \+ K\.Lift\) or Vector3\.new\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)")
    want = (pond[0], pond[1] + 3, pond[2]) if pond else None
    out.append(("HUD's pond guide spot and QuestTarget's pond fallback = Config.StoryQuests.Landmarks.SlimePond + 3",
                want is not None and hud_spot == want and qt_spot == want))
    halo = vec_of(intro, r"\tHalo = Vector3\.new\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\),")
    horns = vec_of(intro, r"\tHorns = Vector3\.new\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\),")

    def in_rect(p, r):
        return p is not None and r is not None and r["MinX"] <= p[0] <= r["MaxX"] and r["MinZ"] <= p[2] <= r["MaxZ"]
    out.append(("the Intro's town shots stand in the towns, between the gate and the spawn",
                values is not None and in_rect(halo, values.get("HaloTown")) and in_rect(horns, values.get("HornsTown"))
                and values["HaloSpawnZ"] <= halo[2] <= values["HaloTown"]["MaxZ"] and values["HornsTown"]["MinZ"] <= horns[2] <= values["HornsSpawnZ"]))
    out.append(("MapBuilder PATCH / HOLLOW read Config.Map.Halloween (path, west gate, sign) and place the hollow by shares",
                'local HW = type(Config.Map.Halloween) == "table" and Config.Map.Halloween or {}' in mb
                and "PathX = tonumber(HW.PathX) or 535," in mb
                and 'WestGateZ = (typeof(HW.HollowGate) == "Vector3" and HW.HollowGate.Z) or 340,' in mb
                and 'SignPos = typeof(HW.SignPos) == "Vector3" and HW.SignPos or Vector3.new(525, 0, 226),' in mb
                and 'HOLLOW.place(ctx, root, "GF_Arch", l.MaxX - HOLLOW.ArchInset, PATCH.WestGateZ, 18, "w", -90, false)' in mb
                and "local x, z = HOLLOW.at(l, e[2], e[3])" in mb))
    out.append(("MapBuilder re-fits reused zone markers, walls and gates to Config (map v2 on an older place)",
                "floor.Size, floor.CFrame = size, CFrame.new(pos)" in mb
                and '\t\t\tif fitWall(wall, specs[name]) then Util.Log(TAG, "moved " .. name .. " onto Config.Map.Bounds") end\n' in mb
                and "\t\t\telseif placeGate(gate, entry.Position) then\n" in mb))
    out.append(("preview_map: \"terrain\" unless asked for \"full\"; only \"full\" destroys workspace.Map; PvP borders at the woods / "
                "ruins zone edges",
                'if MODE ~= "full" then MODE = "terrain" end' in pv and 'if MODE == "full" and map then\n\tmap:Destroy()' in pv
                # before the terrain-mode return the only Destroy is the full-mode Map (stash() keeps every replaced piece)
                and TERRAIN_RETURN in pv and pv[:pv.index(TERRAIN_RETURN)].count(":Destroy()") == 1
                and "pvpBorder(710, DANGER.PvP" in pv and "pvpBorder(1260, DANGER.Extreme" in pv))
    out.append(("the mover: a dry run unless told to apply; towns 10 studs out, castles to (0, -+630); bridges / roads / gates "
                "/ pads never moved",
                'if MODE ~= "apply" then MODE = "dry" end' in mv and "Shift = -10, Castle = Vector3.new(0, 0, -630)" in mv
                and "Shift = 10, Castle = Vector3.new(0, 0, 630)" in mv
                and 'local SKIP_PREFIX = { "Bridge_", "PvPBorder_", "Gate_", "Pad_", "Wall" }' in mv))
    out.append(("the Studio runner works only in Edit and runs preview_map only in terrain mode",
                '"Current Studio Mode: Edit" not in state' in ap
                and ".replace('local MODE = \"__MODE__\"'," in ap and "'local MODE = \"terrain\"', 1)" in ap
                # the runner's replace really reaches the code line (not the header comment)
                and 'local MODE = "terrain"' in pv.replace('local MODE = "__MODE__"', 'local MODE = "terrain"', 1)
                and 'local MODE = "apply"' in mv.replace('local MODE = "__MODE__"', 'local MODE = "apply"', 1)
                and "f'local MODE = \"{mode}\"', 1)" in ap
                and "'\"full\"'" not in ap))
    # A23-74 (user: "default terrain lumps clash with our art"): the v2 terrain is written voxel by voxel like the A2_2 map
    terr = pv[pv.find("-- 지형 (두 모드 공통)"):pv.find("-- 계약 조각 (두 모드 공통)")] if "-- 계약 조각 (두 모드 공통)" in pv else ""
    out.append(("A23-74 terrain: round coasts written as voxels (WriteVoxelChannels, WriteVoxels fallback), no ball lumps, "
                "islands kept apart by a channel, quays at the bridge ends, flat corridor through the pass, 3D sea rocks",
                "Terrain:WriteVoxelChannels(region, R, { SolidMaterial = sm, SolidOccupancy = so, LiquidOccupancy = lo })" in terr
                and "if not useChannels then Terrain:WriteVoxels(region, R, sm, so) end" in terr
                and "FillBall" not in terr and "FillBlock" not in terr
                and "out = math.min(out, math.max(1, (own + other - T.Channel) / 2))" in terr
                and re.search(r"Channel = (\d+)", terr) is not None and int(re.search(r"Channel = (\d+)", terr)[1]) >= 30
                and "out = T.PinE + (out - T.PinE) * w" in terr and "PinE = 3, PinBeach = 2.5" in terr
                and "if az < PASS.HalfZ + T.Shoulder then h *= smooth(math.clamp((az - PASS.HalfZ) / T.Shoulder, 0, 1)) end" in terr
                and 'kit:FindFirstChild(rng:NextNumber() < 0.5 and "W_Boulder_A" or "W_Boulder_B")' in terr
                and "if oldRocks then stash(oldRocks) end" in terr))

    def landmark(name):
        m = re.search(r"Landmarks\." + name + r" = Vector3\.new\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)", src["config"])
        return tuple(float(x) for x in m.groups()) if m else None
    pond = re.search(r"Landmarks = \{ SlimePond = Vector3\.new\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)", src["config"])
    pond_v = tuple(float(x) for x in pond.groups()) if pond else None
    camps = [landmark(f"GoblinCamp{i}") for i in (1, 2, 3)]
    camp_list = ", ".join(f"Vector3.new({c[0]:g}, {c[1]:g}, {c[2]:g})" for c in camps) if all(camps) else "?"
    out.append(("the mover puts the pond and the three goblin camps on the story spots (Config.StoryQuests.Landmarks), "
                "MeadowKit piece by piece, the kit swap's spots too, and notes the old ground height",
                pond_v is not None and f"SlimePond = {{ Vector3.new({pond_v[0]:g}, {pond_v[1]:g}, {pond_v[2]:g}) }}," in mv
                and f"GoblinCamp = {{ {camp_list} }}," in mv
                and "local GROUPS = { MeadowKit = true }" in mv and 'local KIT_SPOTS = "MeadowPrimitiveBackup"' in mv
                and 'elseif inst:IsA("Folder") or (inst:IsA("Model") and GROUPS[inst.Name]) then' in mv
                and 'inst:SetAttribute("MapV2Ground", off)' in mv
                and "if not hit or hit.Material == Enum.Material.Water then return nil end" in mv))
    out.append(("the terrain pond is a round basin on the story's slime pond (no flat plate), jelly stones round it; "
                "no grass blades, the 10/08 water colour (38, 128, 176), no gold / red road stripes",
                pond_v is not None and f"local PONDS = {{ {{ X = {pond_v[0]:g}, Z = {pond_v[2]:g}, R = 18, Rim = 7," in terr
                and 'if plate and plate:IsA("BasePart") then stash(plate) end' in terr
                and 'kit:FindFirstChild("Kit_M_JellyRock")' in terr
                and "pcall(function() Terrain.Decoration = false end)" in terr
                and "Terrain.WaterColor = RGB(38, 128, 176)" in terr
                and 'Name = "TrimGold"' not in pv and 'Name = "TrimRed"' not in pv))
    out.append(("the runner's settle step lifts / lowers only noted pieces, once, never over water or by more than 60",
                'local off = inst:GetAttribute("MapV2Ground")' in ap and 'inst:SetAttribute("MapV2Settled", true)' in ap
                and "if math.abs(dy) > 60 then" in ap and "hit.Material == Enum.Material.Water then" in ap
                and '"settle", "build", "kits"' in ap))
    plaza = re.search(r"local ROAD_PLAZA_R = (\d+)", pv)
    cfg_plaza = re.search(r"\tRoadLook = \{\n\t\tPlazaRadius = (\d+),", src["config"])
    out.append(("검수 10/09 roads: MapBuilder.Build runs FitRoads (pcall); preview_map cuts the town roads at the same plaza radius",
                "pcall(MapBuilder.FitRoads, folders.Decor)" in mb and plaza is not None and cfg_plaza is not None
                and plaza[1] == cfg_plaza[1] and "if minZ >= 0 and minZ < ROAD_PLAZA_R then minZ = ROAD_PLAZA_R end" in pv
                and "if maxZ <= 0 and maxZ > -ROAD_PLAZA_R then maxZ = -ROAD_PLAZA_R end" in pv))
    war = src["war"]
    out.append(("A23-74 no ray bursts: WarService turns the SunRaysEffect off and every sky's SunRays is 0",
                "local SUNRAYS_FIXED = { Spread = 0.4, Intensity = 0, Enabled = false }" in war
                and 'setProps(findOrCreate(Lighting, "SunRaysEffect"), SUNRAYS_FIXED)' in war
                and re.findall(r"SunRays = ([\d.]+)", war) == ["0", "0", "0"]))
    return out


def run(src: dict[str, str], layout: dict, directory: Path, name: str) -> dict:
    text = (f"local CONFIG_SOURCE = {lua_long(src['config'])}\n"
            f"local PREVIEW_SOURCE = {lua_long(preview_source(src['preview']))}\n"
            f"local LAYOUT = {layout_lua(layout)}\n"
            f"local HOLLOW_UV = {hollow_uv(src['mapbuilder'])}\n"
            f"local FITROADS_SOURCE = {lua_long(fitroads_source(src['mapbuilder']))}\n"
            + FIXTURE.read_text(encoding="utf-8"))
    path = directory / name
    path.write_text(text, encoding="utf-8")
    proc = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=300)
    result, values = None, None
    for line in proc.stdout.splitlines():
        if line.startswith("MAPV2_RESULT_JSON "):
            result = json.loads(line[len("MAPV2_RESULT_JSON "):])
        elif line.startswith("MAPV2_VALUES_JSON "):
            values = json.loads(line[len("MAPV2_VALUES_JSON "):])
    return {"stdout": proc.stdout, "stderr": proc.stderr, "result": result, "values": values}


def failing(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    raw = {p: p.read_bytes() for p in (*FILES.values(), LAYOUT, FIXTURE)}
    src = {k: raw[p].decode("utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    layout = json.loads(raw[LAYOUT].decode("utf-8-sig"))
    compiler = BINARY.with_name("luau-compile.exe")
    compiled = subprocess.run([str(compiler), str(FILES["config"]), str(FILES["mapbuilder"]), str(FILES["questtarget"]),
                               str(FILES["hud"]), str(FILES["intro"]), str(FILES["preview"]), str(FILES["move"]), str(FIXTURE)],
                              cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, encoding="utf-8",
                              errors="replace", timeout=120)
    mutations = []
    with tempfile.TemporaryDirectory(prefix="map_v2_") as tmp:
        tmpdir = Path(tmp)
        real = run(src, layout, tmpdir, "map_v2_real.luau")
        static = static_checks(src, real["values"])
        base = failing(real["result"])
        print(real["stdout"], end="")
        if real["stderr"]:
            print(real["stderr"], end="")
        if not args.no_mutations:
            for i, (name, key, old, new) in enumerate(MUTATIONS):
                hits = src[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "applied": False, "caught": False,
                                      "note": f"pattern matched {hits} times; update MUTATIONS"})
                    print(f"mutation NOT APPLIED: {name}")
                    continue
                mutated = dict(src)
                mutated[key] = src[key].replace(old, new, 1)
                try:
                    m = run(mutated, layout, tmpdir, f"map_v2_mut_{i:02d}.luau")
                    crashed = m["result"] is None
                    new_fail = sorted(failing(m["result"]) - base)
                    static_bad = [n for n, ok in static_checks(mutated, m["values"] or real["values"]) if not ok]
                except ValueError as err:
                    crashed, new_fail, static_bad = True, [str(err)], []
                caught = crashed or bool(new_fail) or bool(static_bad)
                mutations.append({"mutation": name, "file": key, "applied": True, "caught": caught, "crashed": crashed,
                                  "newFailingChecks": (new_fail + static_bad)[:6]})
                print(f"mutation {'caught' if caught else 'NOT CAUGHT'}: {name}")
    for name, ok in static:
        print(("STATIC ok   " if ok else "STATIC FAIL ") + name)
    changed = [p.relative_to(ROOT).as_posix() for p, b in raw.items() if p.read_bytes() != b]
    result = real["result"] or {}
    named = result.get("Named", [])
    bad = [n for n in named if n.get("Fail", 0) > 0]
    real_ok = real["result"] is not None and not bad and "MAPV2_OFFLINE_OK" in real["stdout"]
    mut_ok = all(m.get("applied") and m.get("caught") for m in mutations)
    static_ok = all(ok for _, ok in static)
    if compiled.returncode == 0 and real_ok and static_ok and not changed and mut_ok:
        status = "passed-no-mutations" if args.no_mutations else "passed"
    else:
        status = "failed"
    report = {
        "status": status,
        "checks": result.get("Checks", 0),
        "namedChecks": len(named),
        "failing": [{"group": n["Group"], "check": n["Name"], "firstFailure": n.get("FirstFailure")} for n in bad],
        "static": [{"check": n, "ok": ok} for n, ok in static],
        "mutations": {"total": len(MUTATIONS), "applied": sum(1 for m in mutations if m.get("applied")),
                      "caught": sum(1 for m in mutations if m.get("caught")), "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if real["result"] else (real["stderr"].strip() or real["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(b).hexdigest() for p, b in raw.items()},
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0,
        "contract": "SPEC A23-53 world map v2 (docs/design/world_map_v2_2026-10-06.json) in Config.Zones / Config.Map, the "
                    "Halloween fields (A23-30 / A23-45), the story places, tools/preview_map.lua terrain mode and the v1 -> v2 mover.",
        "limitations": "Numbers and source contracts only. The Terrain itself, the moved kit / town models, the bridges and "
                       "the play feel need the Studio step (P2: terrain -> move -> MapBuilder.Build -> photos -> Play).",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Named checks: {len(named) - len(bad)} passed, {len(bad)} failing; assertions "
          f"{result.get('Checks', 0) - result.get('Failed', 0)}/{result.get('Checks', 0)}")
    print(f"Status: {status} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if status in ("passed", "passed-no-mutations") else 1


if __name__ == "__main__":
    raise SystemExit(main())
