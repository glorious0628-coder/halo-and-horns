"""Invisible walls show themselves (최종 검수 10/15 #2, 'why does this not work?'), offline.

Runs the CURRENT ZoneLook.WallSpot / WallAlpha in the official Luau CLI on small doubles (an axis-aligned CFrame): a wall
shows a panel only while I stand within Near studs of its face and not past its ends; the panel goes on MY side, at the
spot along the wall nearest me, clearer the closer I am (Alpha at the face, clear at Near). Static: the walls are
Map.Walls' clear collidable parts and the Goose Square's Wall_* parts, the panel never collides / is never hit, and the
pass runs in ZoneLook.Start next to the PvP edge. Each mutation must make a check fail.

Usage: py tools/test_wall_edges.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ZL = ROOT / "src/StarterPlayer/StarterPlayerScripts/ZoneLook.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

FIXTURE = r"""
local V3mt = {}
V3mt.__index = V3mt
V3mt.__type = "Vector3"
local function V3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3mt) end
V3mt.__div = function(a, k) return V3(a.X / k, a.Y / k, a.Z / k) end
local CFmt = { __type = "CFrame" }
CFmt.__index = { PointToObjectSpace = function(self, p) return V3(p.X - self.P.X, p.Y - self.P.Y, p.Z - self.P.Z) end }
local function CF(x, y, z) return setmetatable({ P = V3(x, y, z) }, CFmt) end
local function typeof(v) local mt = type(v) == "table" and getmetatable(v) return mt and mt.__type or type(v) end
local ZoneLook = { WALL = { Near = 12, Alpha = 0.7 } }
local env = setmetatable({ ZoneLook = ZoneLook, typeof = typeof }, { __index = getfenv() })
for _, src in SOURCES do local f = assert(loadstring(src, "=cut")) setfenv(f, env) f() end
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
-- a wall along Z at x = 100 (thin in X): 2 thick, 40 tall, 200 long
local cf, size = CF(100, 20, 0), V3(2, 40, 200)
local s = ZoneLook.WallSpot(cf, size, V3(95, 3, 30), 12)
check("near the face (4 studs): a spot on my side (-X), along = my Z", s and s.Thin == "X" and s.Side == -1 and s.Along == 30
	and math.abs(s.Dist - 4) < 1e-6, s and s.Dist)
check("on the other side: Side +1", (ZoneLook.WallSpot(cf, size, V3(105, 3, 0), 12) or {}).Side == 1)
check("farther than Near: nothing", ZoneLook.WallSpot(cf, size, V3(80, 3, 0), 12) == nil)
check("past its end by more than Near: nothing", ZoneLook.WallSpot(cf, size, V3(95, 3, 130), 12) == nil)
local e = ZoneLook.WallSpot(cf, size, V3(95, 3, 105), 12)
check("just past its end: the spot stays on the wall (clamped)", e and e.Along == 100, e and e.Along)
check("a wall thin in Z", (ZoneLook.WallSpot(CF(0, 20, 50), V3(200, 40, 2), V3(10, 3, 45), 12) or {}).Thin == "Z")
check("alpha: Alpha at the face, clear at Near", math.abs(ZoneLook.WallAlpha(0, 12) - 0.7) < 1e-6
	and math.abs(ZoneLook.WallAlpha(12, 12) - 1) < 1e-6 and ZoneLook.WallAlpha(6, 12) < 1)
print(("WALL_SUMMARY checks=%d failed=%d"):format(checks, failed))
"""

STATIC = [
    ("walls = Map.Walls clear collidable + Goose Square Wall_*", [
        'local walls = map and map:FindFirstChild("Walls")',
        "if p:IsA(\"BasePart\") and p.Transparency >= 0.95 and p.CanCollide then table.insert(out, p) end",
        'string.sub(p.Name, 1, 5) == "Wall_"']),
    ("the panel never collides, is never hit",
     ["panel.Anchored, panel.CanCollide, panel.CanQuery, panel.CanTouch, panel.CastShadow = true, false, false, false, false"]),
    ("the pass runs in Start", ["\t\t\tok, err = pcall(ZoneLook.RefreshWalls)\n"]),
]
MUTATIONS = [
    ("shown from any distance", "if d < 0 or d > near or", "if d < 0 or"),
    ("shown past the ends", " or math.abs(lp[long]) > half[long] + near then return nil end", " then return nil end"),
    ("always on one side", "Side = lp[thin] >= 0 and 1 or -1,", "Side = 1,"),
    ("never clearer far away", "return W.Alpha + (1 - W.Alpha) * math.clamp(dist / math.max(near, 1), 0, 1)", "return W.Alpha"),
    ("the panel collides", "panel.Anchored, panel.CanCollide, panel.CanQuery", "panel.Anchored, panel.CanQuery, panel.CanCollide"),
]


def cut(src: str, name: str) -> str:
    m = re.search(r"\nfunction ZoneLook\." + name + r"\(.*?\nend\n", src, re.S)
    return m[0] if m else ""


def run(src: str) -> int:
    srcs = [cut(src, "WallSpot"), cut(src, "WallAlpha")]
    bad = sum(1 for s in srcs if not s)
    lua = "local SOURCES = {" + "".join(f"[==========[{s}]==========]," for s in srcs if s) + "}\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "walls.luau"
        p.write_text(lua, encoding="utf-8")
        out = subprocess.run([str(LUAU), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    text = out.stdout + out.stderr
    m = re.search(r"WALL_SUMMARY checks=(\d+) failed=(\d+)", text)
    bad += int(m[2]) if m else 1
    for name, needles in STATIC:
        if not all(src.count(n) == 1 for n in needles):
            bad += 1
            text += "\nSTATIC_FAIL " + name
    run.last = text
    return bad


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = ZL.read_text(encoding="utf-8")
    bad = run(src)
    print(run.last.strip())
    caught = 0
    for name, old, new in MUTATIONS:
        ok = src.count(old) == 1 and run(src.replace(old, new)) > 0
        caught += ok
        print(("MUTATION caught  " if ok else "MUTATION MISSED ") + name)
    status = "passed" if bad == 0 and caught == len(MUTATIONS) else "failed"
    print(f"Status: {status} (mutations {caught}/{len(MUTATIONS)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
