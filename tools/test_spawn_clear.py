"""A23-129 (user 2026-10-11 "몹이 나무들을 뚫고 나오네"): a new monster never spawns inside a tree, rock or building, offline.

The CR-L14 centre ray only saw collidable, queryable parts of Map.Decor / Landmarks, but the world kits' trees, bushes and
rocks are CanQuery = false meshes (a visible mesh without collision + an invisible collidable post; place file
2026-10-11: MeadowDress / WoodsKit / HaloProps ...) that no raycast or GetPartBoundsInBox returns. MonsterService now keeps
its own index of prop boxes (CLEAR: every BasePart under workspace.Map except the walking ground of Config.GroundRoots,
Map.Ground / Zones / Pads and invisible non-collidable helpers) and checks a new monster's whole body (flat radius
SEP.RadiusOf, height Slime 3 x Scale / Humanoid 5 x Scale + Float, from 0.5 above the ground) against it: groundPoint(x, z,
maxY, def). pickSpawnPoint, SpawnEvent (bosses), MOB3.Spot (partners) and SpawnPersonal pass def; the walks do not.

Cuts getGroundParams .. groundPoint (incl. CLEAR) and SEP from the CURRENT MonsterService, the real pickSpawnPoint (the
test_tutorial_spawn cut), SpawnEvent, MOB3.Spot and SpawnPersonal, runs them on a map double (Folder / Model / Part /
MeshPart with rotated CFrames, a terrain + bridge + WalkGround ground under vertical rays) with
tools/fixtures/spawn_clear_offline.luau and the installed official Luau CLI. The "no overlap" claims are checked by a
sampling oracle written in the fixture (points of the body inside a part's box), not by CLEAR itself.

Usage: py tools/test_spawn_clear.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-11/offline_dev2_spawn_clear_2026-10-11.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, between, function_block, read, run, strip_comments
from test_tutorial_spawn import bindings as spawn_bindings

C, M = "CONFIG_SOURCE", "MONSTER_SOURCE"
FILES = {C: SHARED / "Config.luau", M: SSS / "MonsterService.luau"}
PROBE = ROOT / "tools/spawn_clear_probe.luau"


def consts(mon: str, names: list[str]) -> str:
    out = []
    for name in names:
        found = re.search(r"^local " + name + r"\b.*$", mon, re.M)
        if not found:
            raise ValueError(f"MonsterService constant {name} missing; update the test extractor.")
        out.append(found.group(0))
    return "\n".join(out) + "\n"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    mon = sources[M]
    sep = between(mon, "local SEP = {\n", "\n}\n") + "\n}\n" + function_block(mon, "function SEP.RadiusOf(") \
        + function_block(mon, "function SEP.Clear(")
    return {
        C: sources[C],
        # the ground probes, CR-L14 occupied, the A23-129 index and groundPoint
        "GROUND_EXTRACT": (
            "local Config, Util, warnThrottled, records = ...\n"
            + consts(mon, ["GROUND_RAY_TOP", "GROUND_RAY_LENGTH", "GROUND_MIN_Y", "GROUND_PARAMS_REFRESH"])
            + "local groundParams, groundParamsAt = nil, -math.huge\n" + sep
            + between(mon, "local function getGroundParams()", "\n-- unanchored monster part")
            + "\nreturn { groundPoint = groundPoint, CLEAR = CLEAR, SEP = SEP, getGroundParams = getGroundParams, "
              "probeGround = probeGround }\n"),
        # the real pickSpawnPoint (with its spread / tutorial helpers), on H.groundPoint = the real one above
        "SPAWN_EXTRACT": spawn_bindings(sources)["SPAWN_EXTRACT"],
        "EVENT_EXTRACT": (
            "local Config, Util, H = ...\nlocal MonsterService = {}\nlocal records = H.records\n"
            "local groundPoint, pickSpawnPoint, spawnMonster, warnThrottled = H.groundPoint, H.pickSpawnPoint, "
            "H.spawnMonster, H.warnThrottled\n" + consts(mon, ["SPAWN_TRIES"]) + sep
            + function_block(mon, "function MonsterService.SpawnEvent(")
            + function_block(mon, "function MonsterService.PickSpawnPoint(")
            + function_block(mon, "function MonsterService.GroundAt(") + "\nreturn MonsterService\n"),
        "SPOT_EXTRACT": (
            "local Config, Util, H = ...\nlocal records = H.records\n"
            "local groundPoint, pickSpawnPoint, getGroundParams = H.groundPoint, H.pickSpawnPoint, H.getGroundParams\n"
            + sep + "local MOB3 = {}\n" + function_block(mon, "local function num3(")
            + function_block(mon, "function MOB3.MaterialAt(") + function_block(mon, "function MOB3.Spot(")
            + "\nreturn MOB3.Spot\n"),
        "PERSONAL_EXTRACT": (
            "local Config, Util, personal, PERSONAL_DISTANCE, PERSONAL_LIFETIME, groundPoint, probeGround, spawnMonster, "
            "despawn, warnThrottled = ...\nlocal MonsterService = {}\n"
            + function_block(mon, "function MonsterService.SpawnPersonal(") + "\nreturn MonsterService\n"),
    }


GP = "local function groundPoint(x, z, maxY, def)"
MUTATIONS = [
    # who passes the body
    ("pickSpawnPoint: no body check", M, "\t\tlocal g, noHit = groundPoint(pt.X, pt.Z, nil, def)\n",
     "\t\tlocal g, noHit = groundPoint(pt.X, pt.Z)\n"),
    ("SpawnEvent: no body check", M, "groundPoint(x, z, opts.MaxY, def) -- A23-129", "groundPoint(x, z, opts.MaxY) --"),
    ("MOB3.Spot partner: no body check", M, "m.Z + math.sin(a) * d, nil, def) -- A23-129", "m.Z + math.sin(a) * d) --"),
    ("SpawnPersonal: no body check", M, "\t\t\tlocal g, noHit = groundPoint(p.X, p.Z, nil, def)\n",
     "\t\t\tlocal g, noHit = groundPoint(p.X, p.Z)\n"),
    ("groundPoint ignores def", M, "\tif def ~= nil and not CLEAR.Fits(g, def) then return nil, false end -- A23-129\n", ""),
    ("the walks get the body check too", M, "\tif def ~= nil and not CLEAR.Fits(g, def) then",
     "\tif not CLEAR.Fits(g, def or { Shape = \"Slime\", Scale = 1 }) then"),
    # what counts as a prop
    ("non-collidable parts never count (the old rule)", M,
     "\tif part.Transparency >= 0.95 and not part.CanCollide then return nil end",
     "\tif not part.CanCollide then return nil end"),
    ("invisible helpers count", M, "\tif part.Transparency >= 0.95 and not part.CanCollide then return nil end", ""),
    ("tagged floor parts count as props", M, "\t\tif t:IsA(\"BasePart\") then skip[t] = true end\n", ""),
    ("bridges / WalkGround models skipped whole again (rails never block)", M,
     "\tlocal ground = map:FindFirstChild(\"Ground\")\n\tif ground then skip[ground] = true end\n",
     "\tfor _, g in Config.GroundRoots(workspace.Terrain, map, Util.Tagged(\"WalkGround\")) do skip[g] = true end\n"),
    ("Map.Pads counts as props", M, "SKIP = { Ground = true, Zones = true, Pads = true }",
     "SKIP = { Ground = true, Zones = true }"),
    ("Map.Zones counts as props", M, "SKIP = { Ground = true, Zones = true, Pads = true }",
     "SKIP = { Ground = true, Pads = true }"),
    ("only Decor / Landmarks (other folders missed)", M, "\twalk(map)\n\treturn grid",
     "\tfor _, c in map:GetChildren() do if c.Name == \"Decor\" or c.Name == \"Landmarks\" then walk(c) end end\n\treturn grid"),
    ("parts inside parts missed", M, "\t\t\t\twalk(c)\n\t\t\tend\n\t\tend\n\tend\n\twalk(map)",
     "\t\t\t\tif not c:IsA(\"BasePart\") then walk(c) end\n\t\t\tend\n\t\tend\n\tend\n\twalk(map)"),
    # the body
    ("roads and decks block (no foot gap)", M, "\tFOOT = 0.5,", "\tFOOT = 0,"),
    ("height ignored (canopies block slimes)", M, "g.Y + math.max(h, CLEAR.FOOT + 0.1), CLEAR.CELL",
     "g.Y + 1000, CLEAR.CELL"),
    ("height too low (a King under a low canopy)", M, "g.Y + math.max(h, CLEAR.FOOT + 0.1), CLEAR.CELL",
     "g.Y + CLEAR.FOOT + 0.1, CLEAR.CELL"),
    ("Float ignored", M, " * s + math.max(0, tonumber(def.Float) or 0)", " * s"),
    ("radius ignored (centre only)", M, "\tlocal r, h = CLEAR.Body(def)\n\treturn CLEAR.Hit(g, r, h) == nil",
     "\tlocal _, h = CLEAR.Body(def)\n\treturn CLEAR.Hit(g, 0.01, h) == nil"),
    ("scale ignored in height", M, "local s = tonumber(def.Scale) or 1\n\treturn SEP.RadiusOf(def)",
     "local s = 1\n\treturn SEP.RadiusOf(def)"),
    # the geometry
    ("upright boxes as their bounding box (corners block)", M, "\t\treturn d2 < r * r\n", "\t\treturn true\n"),
    ("rotation ignored (world axes)", M, "local out = math.abs(dx * a.X + dz * a.Z) - e.Half[i]",
     "local out = math.abs(i == 1 and dx or dz) - e.Half[i]"),
    ("tilted parts by bounding box only", M,
     "\t\tif math.abs(dx * a.X + dy * a.Y + dz * a.Z) >= reach then return false end\n", ""),
    ("tilted parts never block", M, "\t\tif math.abs(dx * a.X + dy * a.Y + dz * a.Z) >= reach then return false end\n\tend\n\treturn true",
     "\t\tif math.abs(dx * a.X + dy * a.Y + dz * a.Z) >= reach then return false end\n\tend\n\treturn false"),
    ("vertical range ignored", M, "\tif e.Hi <= lo or e.Lo >= hi then return false end\n", ""),
    ("only the centre cell is searched", M,
     "\tfor cx = math.floor((g.X - r) / cell), math.floor((g.X + r) / cell) do\n\t\tfor cz = math.floor((g.Z - r) / cell), math.floor((g.Z + r) / cell) do",
     "\tfor cx = math.floor(g.X / cell), math.floor(g.X / cell) do\n\t\tfor cz = math.floor(g.Z / cell), math.floor(g.Z / cell) do"),
    ("big props only in their centre cell", M,
     "\t\tfor cx = math.floor((e.X - e.EX) / cell), math.floor((e.X + e.EX) / cell) do\n\t\t\tfor cz = math.floor((e.Z - e.EZ) / cell), math.floor((e.Z + e.EZ) / cell) do",
     "\t\tfor cx = math.floor(e.X / cell), math.floor(e.X / cell) do\n\t\t\tfor cz = math.floor(e.Z / cell), math.floor(e.Z / cell) do"),
    # the index life
    ("never rebuilt", M, "\telseif not CLEAR.Busy and now - CLEAR.At >= CLEAR.REFRESH\n", "\telseif false\n"),
    ("rebuilt but never swapped in", M, "\t\t\t\tCLEAR.Grid = grid\n\t\t\t\tCLEAR.Watch(map)\n",
     "\t\t\t\tCLEAR.Watch(map)\n"),
    ("a failed rebuild clears the index", M, "\t\t\t\tCLEAR.Dirty = true -- the old index stays",
     "\t\t\t\tCLEAR.Grid, CLEAR.Dirty = {}, true --"),
    ("a failed rebuild is never tried again", M, "\t\t\t\tCLEAR.Dirty = true -- the old index stays", "\t\t\t\tlocal _ = 0 --"),
    ("Busy never cleared", M, "\t\t\tCLEAR.Busy = false\n\t\tend)", "\t\tend)"),
    ("rebuilt in the foreground", M, "\t\ttask.spawn(function()\n\t\t\tlocal ok, grid, map = pcall(CLEAR.Build, true)",
     "\t\tlocal _ = (function(f) f() end)(function()\n\t\t\tlocal ok, grid, map = pcall(CLEAR.Build, true)"),
    ("no Map at first: never retried", M, "\tif not map then return nil end\n\tlocal skip = {}",
     "\tif not map then return {} end\n\tlocal skip = {}"),
    ("background rebuild never yields", M, "\t\t\tlocal ok, grid, map = pcall(CLEAR.Build, true)",
     "\t\t\tlocal ok, grid, map = pcall(CLEAR.Build)"),
    ("a change never marks the index dirty", M, "\tlocal function mark() CLEAR.Dirty = true end", "\tlocal function mark() end"),
    ("rebuilt every 60 s even when nothing changed", M,
     "\t\tand (CLEAR.Dirty or not CLEAR.Watched or CLEAR.Map == nil or CLEAR.Map.Parent ~= workspace) then", "\t\tthen"),
    ("an unwatched Map trusted to be clean", M, "(CLEAR.Dirty or not CLEAR.Watched or CLEAR.Map == nil", "(CLEAR.Dirty or CLEAR.Map == nil"),
    ("a Map out of the workspace swapped in", M, "\t\t\tif ok and grid and map.Parent == workspace then",
     "\t\t\tif ok and grid then"),
    ("a failed first build: a full build on every try", M, "\t\t\tCLEAR.Grid, CLEAR.Dirty = {}, true\n", ""),
    # 검수 2026-10-11: trees (trunk-base disc + canopy box)
    ("tree rule never applies", M, "\tif not post or not mesh then return nil end\n\treturn { Mesh",
     "\tif true then return nil end\n\treturn { Mesh"),
    ("tree switch ignored", M, "\tif type(SC) ~= \"table\" or SC.TreeRule == false or type(SC.Trees) ~= \"table\" then return nil end",
     "\tif type(SC) ~= \"table\" or type(SC.Trees) ~= \"table\" then return nil end"),
    ("trunk-base disc ignored", M, "\tif e.Disc then return dx * dx + dz * dz < (e.R + r) * (e.R + r) end",
     "\tif e.Disc then return false end"),
    ("disc as wide as the post only (roots let in)", M, "local p, r = t.Post.CFrame.Position, t.Base * plan",
     "local p, r = t.Post.CFrame.Position, t.Post.Size.Y / 2"),
    ("canopy box from the ground (no cut)", M, "\t\te.Lo = cut\n", ""),
    ("no canopy box (tall bodies pass under low canopies)", M, "\t\ttable.insert(out, e)\n\tend\n\treturn out",
     "\tend\n\treturn out"),
    ("a second TrunkPost accepted", M, "\t\t\t\tif post then return nil end\n", ""),
    ("the giant tree relaxed too", C, "\t\tW_Tree_C = { Base = 0.34, Canopy = 0.46 },\n",
     "\t\tW_Tree_C = { Base = 0.34, Canopy = 0.46 },\n\t\tW_GiantTree = { Base = 0.1, Canopy = 0.2 },\n"),
    ("a narrower trunk base", C, "W_Tree_B = { Base = 0.36, Canopy = 0.36 }", "W_Tree_B = { Base = 0.2, Canopy = 0.36 }"),
    # ground cover / effects
    ("pass rule ignores CanCollide", M, "SC.PassRule == false or part.CanCollide then return false end",
     "SC.PassRule == false then return false end"),
    ("NotPass ignored", M, "\tfor _, k in SC.NotPass or {} do\n\t\tif string.find(name, k, 1, true) then return false end\n\tend\n", ""),
    ("pass rule never applies", M, "\t\t\t\t\telseif not CLEAR.Passes(c) then", "\t\t\t\t\telseif true then"),
    ("pass switch ignored", M, "if type(SC) ~= \"table\" or SC.PassRule == false or part.CanCollide then",
     "if type(SC) ~= \"table\" or part.CanCollide then"),
    # personal / event rings, the town spot, GroundAt
    ("SpawnPersonal: the four sides only", M, "\t\tfor ring = 1, 2 do\n", "\t\tfor ring = 1, 0 do\n"),
    ("SpawnPersonal: no second ring", M, "\t\tfor ring = 1, 2 do\n", "\t\tfor ring = 1, 1 do\n"),
    ("SpawnPersonal: the second ring at the same distance", M, "ring == 1 and dist or dist * 1.5", "dist"),
    ("SpawnPersonal: the town spot without the body", M,
     "\t\tlocal g, noHit = groundPoint(p.X, p.Z, nil, def)\n\t\tif not g and not noHit then return nil end\n",
     "\t\tlocal g, noHit = groundPoint(p.X, p.Z)\n\t\tif not g and not noHit then return nil end\n"),
    ("SpawnEvent: no rings (a random meadow spot)", M, "\t\tfor ring = 1, (pos or crowded) and 0 or 3 do", "\t\tfor ring = 1, 0 do"),
    ("SpawnEvent: rings without the body", M, "\t\t\t\tlocal g = groundPoint(x, z, opts.MaxY, def)\n",
     "\t\t\t\tlocal g = groundPoint(x, z, opts.MaxY)\n"),
    ("GroundAt ignores the kind", M, "\treturn groundPoint(x, z, nil, def)\nend", "\treturn groundPoint(x, z)\nend"),
    # the skip rule
    ("every try blocked: a random point anyway", M, "\tif not anyHit then\n", "\tif true then\n"),
    ("the public probe passes no kind", M, "\treturn pickSpawnPoint(def, kind)\nend",
     "\treturn pickSpawnPoint({ Zone = def.Zone, Shape = def.Shape }, kind)\nend"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    mon = read(SSS / "MonsterService.luau")
    calls = re.findall(r"(?<!function )groundPoint\(([^\n]*)\)", mon)
    with_def = [c for c in calls if c.rstrip().endswith("def")]
    check(len(with_def) == 7, "exactly 7 groundPoint calls pass def (spawn, event + its rings, partner, personal + its town "
          f"spot, GroundAt with a kind): {len(with_def)}")
    for name in ("local function aiStep(", "local function steer(", "local function wander("):
        if name in mon:
            check("def)" not in "".join(re.findall(r"groundPoint\([^\n]*\)", function_block(mon, name))),
                  f"{name} walks never pass a body")
    code = strip_comments(mon)
    check("GetPartBoundsInBox" not in code and "GetPartsInPart" not in code and "GetPartBoundsInRadius" not in code,
          "no spatial query (CanQuery = false props are invisible to it)")
    probe = read(PROBE)
    body = "\n".join(line.split("--", 1)[0] for line in probe.splitlines())
    for bad in (".Parent =", ":Destroy(", ":SetAttribute(", ":Clone(", "Instance.new(", ":PivotTo(", ".CFrame =",
                ":ClearAllChildren(", "SpawnEvent", "SpawnPersonal", ":Remove("):
        check(bad not in body, f"probe is read-only: no {bad}")
    check("PickSpawnPoint" in probe and "GroundAt" in probe and "task.wait()" in probe,
          "probe: the real PickSpawnPoint, the old GroundAt picks, yields in chunks")
    return count, failures


SUITE = Suite(
    mark="SPAWNCLEAR",
    fixture=ROOT / "tools/fixtures/spawn_clear_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-11/offline_dev2_spawn_clear_2026-10-11.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-129: a new monster's body (flat radius SEP.RadiusOf, height Slime 3 x Scale / Humanoid 5 x Scale + Float, "
             "from 0.5 above the ground) never overlaps a BasePart under workspace.Map (collidable or not, any folder, "
             "upright boxes exact, tilted ones conservative), except Map.Ground, WalkGround-tagged floor parts, Map.Zones / "
             "Pads, invisible non-collidable helpers and non-collidable ground cover / effects named in "
             "Config.SpawnClear.Pass (no NotPass word); bridges and tagged models are walked (rails and lamps block, the "
             "deck under the foot gap never does). 검수 2026-10-11: a world-kit tree (one TrunkPost + a mesh named in "
             "Config.SpawnClear.Trees, upright) blocks a disc of Base x its wider plan size round the post up to Canopy x "
             "its height plus its box above; anything else keeps its full box. pickSpawnPoint skips such tries (every try "
             "blocked = nil), SpawnEvent tries rings of 12 at Radius + 3 / 6 / 9 before the zone's own spot, "
             "SpawnPersonal tries the four sides then 12 directions at the distance and at 1.5 x it (its town fallback "
             "keeps the body out too), MOB3.Spot passes the body, the walks do not; GroundAt(x, z, kind) for the probe. "
             "Index built at the first spawn (an empty one after a failed first build; retried while there is no Map), "
             "rebuilt in the background (time-budget yields) at a 60 s check only when the Map changed (DescendantAdded / "
             "Removing), is unwatched or left the workspace; swapped in only when it worked and its Map is in the "
             "workspace. Woods area (synthetic grove of kit trees): the tree rule leaves >= 25% more room than the box.",
    limitations="A map double under vertical rays (no real Terrain, meshes as their boxes, no CollisionFidelity); the "
                "real map is checked by tools/spawn_clear_probe.luau in Studio (main apply session).",
)

if __name__ == "__main__":
    run(SUITE)
