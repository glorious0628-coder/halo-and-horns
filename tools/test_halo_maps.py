"""Halo v2 island on the 2D maps (A23-121 stage 6, 게임성 개발 1, 최종 검수 10/13), offline.

Runs, in the official Luau CLI, the CURRENT Util.PathSegments and WorldMap.PaintCover (cut out of their sources) with
the CURRENT Config.luau:
1. Config.Map.RoadPaths RoadHaloMain = docs/design/halo_plan_v2_2026-10-11.json roads main (the x / z of every point,
   Y 0, width w): the first 10 minutes' spine (gate -> spawn -> market -> fountain plaza -> cathedral stairs); it lies on
   the island (the v2 box x -310..305, z -863..-330) and Config.Map.Roads has no straight RoadNorthIsland strip.
2. Util.PathSegments: one piece per straight part (centre, length + width so the round ends overlap at the bends,
   Rotation = atan2(dz, dx) in degrees: the maps draw +X right, +Z down), zero-length parts skipped, bad input = none.
3. WorldMap.PaintCover: the lands the painted big map does not cover, from its Map transform (as drawWorld places it):
   today's lands are all covered; the v2 Halo island box (dev2-halo-stage6) is not (only it); no picture = every land.
Static: MiniMap reads RoadPaths and draws each piece turned (Rotation, round, opaque); WorldMap reads RoadPaths, draws
the pieces, and over the picture draws the code shapes (lands / zones / roads / paths) only on a land it does not cover;
MiniMap / WorldMap / Util / Config still compile (luau-compile --null). Mutations: each must be caught.

Usage: py tools/test_halo_maps.py
Report: docs/art/verification_2026-10-13/offline_halo_maps_2026-10-13.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = "src/StarterPlayer/StarterPlayerScripts/"
FILES = {"UTIL": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
         "WORLD": ROOT / (SPS + "WorldMap.luau"),
         "MINI": ROOT / (SPS + "MiniMap.luau"),
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
PLAN = ROOT / "docs/design/halo_plan_v2_2026-10-11.json"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_halo_maps_2026-10-13.json"
CUTS = {"UTIL": "function Util.PathSegments(points, width)", "WORLD": "function WorldMap.PaintCover(pic, lands)"}

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function vec(x, y, z) return { X = x, Y = y, Z = z, __type = "Vector3" } end
local function v2(x, y) return { X = x, Y = y, __type = "Vector2" } end
local function typeofD(v) return type(v) == "table" and rawget(v, "__type") or type(v) end
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local base = { Vector3 = { new = vec }, Vector2 = { new = v2 }, Color3 = ctor(), BrickColor = ctor(), Rect = ctor(),
	UDim2 = ctor(), UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(),
	NumberSequenceKeypoint = ctor(), ColorSequenceKeypoint = ctor(), CFrame = ctor(), TweenInfo = ctor(), Font = ctor(),
	typeof = typeofD,
	Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end }),
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()
local function near(a, b, e) return type(a) == "number" and math.abs(a - b) <= (e or 1e-6) end

-- 1. the main road = the plan's
local main = nil
for _, p in Config.Map.RoadPaths or {} do if p.Name == "RoadHaloMain" then main = p end end
check(main ~= nil and main.Width == PLAN_W and #main.Points == #PLAN_PTS, "RoadHaloMain: the plan's main road (count, width)",
	main and (#main.Points .. " / " .. tostring(main.Width)))
local same, onIsland = main ~= nil, main ~= nil
for i, q in PLAN_PTS do
	local p = main and main.Points[i]
	same = same and p ~= nil and near(p.X, q[1]) and near(p.Z, q[2]) and p.Y == 0
	onIsland = onIsland and p ~= nil and p.X >= -310 and p.X <= 305 and p.Z >= -863 and p.Z <= -330
end
check(same, "every point = the plan's x / z (Y 0)", "")
check(onIsland, "the road lies on the v2 island box", "")
local strip = false
for _, r in Config.Map.Roads do if r.Name == "RoadNorthIsland" then strip = true end end
check(not strip, "no straight RoadNorthIsland strip in Config.Map.Roads", "")

-- 2. the pieces
local Util = {}
local fu = assert(loadstring(UTIL_SOURCE, "=PathSegments"))
setfenv(fu, setmetatable({ Util = Util, typeof = typeofD }, { __index = getfenv() }))
fu()
local segs = Util.PathSegments(main.Points, main.Width)
check(#segs == #main.Points - 1, "one piece per straight part", #segs)
local s1 = segs[1]
check(s1 and near(s1.X, 0) and near(s1.Z, -349) and near(s1.Length, 26 + 20) and near(s1.Width, 20) and near(s1.Rotation, -90),
	"the first piece: centre (0, -349), 26 + 20 long, turned -90 (north = up)", s1 and (s1.Z .. " " .. s1.Length .. " " .. s1.Rotation))
local s5 = segs[5] -- (34, -452) -> (70, -485)
check(s5 and near(s5.X, 52) and near(s5.Z, -468.5) and near(s5.Length, math.sqrt(36 * 36 + 33 * 33) + 20)
	and near(s5.Rotation, math.deg(math.atan2(-33, 36))), "a slanted piece: its middle, length and turn", s5 and s5.Rotation)
local s7 = segs[7] -- (88, -524) -> (60, -562): west and south
check(s7 and near(s7.Rotation, math.deg(math.atan2(-38, -28))) and s7.Rotation < -90, "a piece back west turns past -90", s7 and s7.Rotation)
check(#Util.PathSegments({ vec(0, 0, 0), vec(0, 0, 0), vec(10, 0, 0) }, 4) == 1, "a zero-length part is skipped", "")
check(#Util.PathSegments(nil, 4) == 0 and #Util.PathSegments({ vec(0, 0, 0) }, 4) == 0
	and #Util.PathSegments({ vec(0, 0, 0), "x" }, 4) == 0, "bad input = no piece", "")
check(near(Util.PathSegments({ vec(0, 0, 0), vec(10, 0, 0) }, nil)[1].Length, 10), "no width = the bare length", "")

-- 3. the picture's bare lands
local WorldMap = {}
local function num(v, d) if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end return d end
local fw = assert(loadstring(WORLD_SOURCE, "=PaintCover"))
setfenv(fw, setmetatable({ WorldMap = WorldMap, num = num, typeof = typeofD }, { __index = getfenv() }))
fw()
local pic = Config.UIArt.Parts.WorldMapV2
local lands = {}
for _, l in Config.Map.Lands do table.insert(lands, { Name = l.Name, MinX = l.MinX, MaxX = l.MaxX, MinZ = l.MinZ, MaxZ = l.MaxZ }) end
local bareNow = WorldMap.PaintCover(pic, lands)
local nBare = 0
for _ in bareNow do nBare += 1 end
local v2Island = { Name = "IslandHalo", MinX = -310, MaxX = 305, MinZ = -863, MaxZ = -330 }
local stage6 = {}
for _, l in lands do table.insert(stage6, l.Name == "IslandHalo" and v2Island or l) end
local bare6 = WorldMap.PaintCover(pic, stage6)
local n6 = 0
for _ in bare6 do n6 += 1 end
local isNew = true
for _, l in lands do if l.Name == "IslandHalo" and l.MinZ == -863 then isNew = true elseif l.Name == "IslandHalo" then isNew = false end end
check(isNew and nBare == 1 and bareNow.IslandHalo or (not isNew and nBare == 0),
	"the painted map covers every land of this Config but the v2 island (if it is in)", nBare)
check(n6 == 1 and bare6.IslandHalo == true, "the v2 Halo island box is bare on the old picture (only it)", n6)
local all = WorldMap.PaintCover(nil, lands)
local nAll = 0
for _ in all do nAll += 1 end
check(nAll == #lands, "no picture: every land is bare", nAll)
local edge = WorldMap.PaintCover(pic, { { Name = "Edge", MinX = -295, MaxX = 0, MinZ = -720, MaxZ = 0 } })
check(edge.Edge == nil, "a land on the picture's own edge is covered (x -295, z -720)", "")
local out = WorldMap.PaintCover(pic, { { Name = "Out", MinX = -300, MaxX = 0, MinZ = -700, MaxZ = 0 } })
check(out.Out == true, "a land 5 studs past the picture's west edge is bare", "")
print(("HALO_MAPS_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("UTIL", "pieces without the round-end overlap", "Length = len + width,", "Length = len,"),
    ("UTIL", "pieces turned the other way", "Rotation = math.deg(math.atan2(dz, dx))", "Rotation = math.deg(math.atan2(dx, dz))"),
    ("UTIL", "zero-length parts kept", "if len > 1e-3 then", "if len >= 0 then"),
    ("WORLD", "the picture's x start without its X0 offset",
     "local x0, z0 = -num(m.OffX, 0) - num(m.X0, 0) / K, -num(m.OffZ, 0)\n\tlocal x1, z1",
     "local x0, z0 = -num(m.OffX, 0), -num(m.OffZ, 0)\n\tlocal x1, z1"),
    ("WORLD", "every land is bare", "then bare[l.Name] = true end\n\tend\n\treturn bare", "or true then bare[l.Name] = true end\n\tend\n\treturn bare"),
    ("WORLD", "no picture = nothing bare", "\t\tfor _, l in lands do bare[l.Name] = true end\n", ""),
    ("CONFIG", "the main road from the old straight strip", "Vector3.new(34, 0, -452), Vector3.new(70, 0, -485)",
     "Vector3.new(0, 0, -452), Vector3.new(0, 0, -485)"),
]
STATIC = [
    ("MiniMap reads RoadPaths (season off = none)", "MINI", "for _, p in (type(map.RoadPaths) == \"table\" and map.RoadPaths or {}) do\n"
     "\t\tif type(p) == \"table\" and type(p.Points) == \"table\" and not seasonOff(p) then"),
    ("MiniMap draws each piece turned, round, opaque", "MINI", "for j, s in Util.PathSegments(p.Points, p.Width) do"),
    ("... with its rotation", "MINI", "\t\t\t\tRotation = s.Rotation,\n\t\t\t\tBackgroundColor3 = COL.Road,\n\t\t\t\tZIndex = 4,"),
    ("WorldMap reads RoadPaths", "WORLD", "for _, p in (type(map.RoadPaths) == \"table\" and map.RoadPaths or {}) do"),
    ("WorldMap draws the pieces", "WORLD", "for j, s in Util.PathSegments(p.Points, p.Width) do"),
    ("over the picture: shapes only on its bare lands", "WORLD", "local bare = painted and WorldMap.PaintCover(pic, landsData) or {}"),
    ("... shown = no picture, or on a bare land", "WORLD", "local function shown(x, z) return not painted or onBare(x, z) end"),
    ("... lands", "WORLD", "\tfor _, l in landsData do\n\t\tif not shown((l.MinX + l.MaxX) / 2, (l.MinZ + l.MaxZ) / 2) then continue end\n\t\tlocal dark"),
    ("... zones", "WORLD", "\tfor _, z in zonesData do\n\t\tif not shown(z.Center.X, z.Center.Z) then continue end"),
    ("... roads", "WORLD", "\tfor i, r in roadsData do\n\t\tif not shown((r.MinX + r.MaxX) / 2, (r.MinZ + r.MaxZ) / 2) then continue end"),
    ("... paths", "WORLD", "if typeof(first) ~= \"Vector3\" or not shown(first.X, first.Z) then continue end"),
    ("bridges stay picture-only", "WORLD", "for i, br in (painted and {} or bridgesData) do"),
]
STATIC_MUTATIONS = [
    ("MiniMap draws no path", "MINI", "for j, s in Util.PathSegments(p.Points, p.Width) do", "for j, s in {} do"),
    ("the picture hides the bare island", "WORLD", "local function shown(x, z) return not painted or onBare(x, z) end",
     "local function shown(x, z) return not painted end"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(key: str, text: str) -> str:
    a = text.find(CUTS[key])
    if a < 0:
        return ""
    b = text.find("\nend\n", a)
    return text[a:b + 5] if b >= 0 else ""


def run(src: dict, plan_pts, plan_w) -> tuple[int, int, str]:
    pts = "{" + ", ".join("{%s, %s}" % (repr(float(p[0])), repr(float(p[1]))) for p in plan_pts) + "}"
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal UTIL_SOURCE = " + lua_str(cut("UTIL", src["UTIL"]))
            + "\nlocal WORLD_SOURCE = " + lua_str(cut("WORLD", src["WORLD"])) + "\nlocal PLAN_PTS = " + pts
            + "\nlocal PLAN_W = " + str(plan_w) + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "halo_maps.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"HALO_MAPS_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def statics(src: dict) -> list[tuple[str, bool]]:
    return [(n, t in src[k]) for n, k, t in STATIC]


def compiles() -> list[tuple[str, bool, str]]:
    compiler = BINARY.with_name("luau-compile" + BINARY.suffix)
    out = []
    for key, path in FILES.items():
        r = subprocess.run([str(compiler), "--null", str(path)], capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=120)
        out.append((f"compiles: {path.name}", r.returncode == 0, (r.stderr or r.stdout).strip()[:300]))
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    road = next(r for r in plan["roads"] if r["id"] == "main")
    pts, w = road["pts"], road["w"]
    found = all(cut(k, src[k]) for k in CUTS)
    checks, failed, out = run(src, pts, w)
    print(out.strip())
    st = [{"check": n, "ok": ok} for n, ok in statics(src)]
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    comp = [{"check": n, "ok": ok, "error": e if not ok else ""} for n, ok, e in compiles()]
    for c in comp:
        print(("CHECK_OK " if c["ok"] else "CHECK_FAIL ") + c["check"] + ("" if c["ok"] else " :: " + c["error"]))
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and run(m, pts, w)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    for name, key, old, new in STATIC_MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and not all(ok for _, ok in statics(m))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = (found and failed == 0 and checks > 0 and all(s["ok"] for s in st) and all(c["ok"] for c in comp)
          and all(m["caught"] for m in muts))
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "compile": comp, "mutations": muts,
                               "status": status, "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0},
                              indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
