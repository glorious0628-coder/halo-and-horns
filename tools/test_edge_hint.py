"""EdgeHint (게임성 개발 1, 큐 #2 '이게 왜 안 돼?', 2026-10-17), offline.

Runs, in the official Luau CLI, the CURRENT EdgeHint.Plan / Alpha: the nearest map edge within Show studs (X or Z, the
closer of two near a corner), nothing farther; the curtain clearer the closer (Near touching, Far at Show). Static:
ClientMain loads EdgeHint; the curtain never collides / is never queried / sits under the camera (local); ForceField, no
Beam (no rays). Mutations: each must be caught.

Usage: py tools/test_edge_hint.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"EH": ROOT / "src/StarterPlayer/StarterPlayerScripts/EdgeHint.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

FIXTURE = r'''
local function V(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, { __type = "Vector3" }) end
local function typeof(v) local mt = type(v) == "table" and getmetatable(v) return mt and mt.__type or type(v) end
local T = { Near = 0.62, Far = 0.97 }
local EdgeHint = {}
__FUNCS__
local n, failed = 0, 0
local function check(v, name, detail)
    n += 1
    if v then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local B = { MinX = -260, MaxX = 1840, MinZ = -720, MaxZ = 720 }
local e = EdgeHint.Plan(V(-252, 3, 0), B, 12)
check(e and e.Axis == "X" and e.At == -260 and math.abs(e.Dist - 8) < 1e-9, "8 studs from MinX: that edge", e and e.Dist)
check(EdgeHint.Plan(V(0, 3, 0), B, 12) == nil, "the middle of the map: nothing")
check(EdgeHint.Plan(V(-240, 3, 0), B, 12) == nil, "20 studs from the edge: nothing")
e = EdgeHint.Plan(V(1835, 3, 712), B, 12)
check(e and e.Axis == "X" and e.At == 1840, "a corner: the closer edge (MaxX 5 studs, MaxZ 8)", e and (e.Axis .. e.At))
check(math.abs(EdgeHint.Alpha(0, 12) - 0.62) < 1e-9 and math.abs(EdgeHint.Alpha(12, 12) - 0.97) < 1e-9
    and EdgeHint.Alpha(3, 12) < EdgeHint.Alpha(9, 12), "clearer the closer (Near touching, Far at Show)")
check(EdgeHint.Plan(nil, B, 12) == nil and EdgeHint.Plan(V(0, 0, 0), nil, 12) == nil, "no position / no bounds: nil")
print("EDGE_SUMMARY checks=" .. n .. " failed=" .. failed)
'''

MUTATIONS = [
    ("EH", "the farther edge wins", "if d <= show and (best == nil or d < best.Dist) then", "if d <= show then"),
    ("EH", "no distance limit", "if d <= show and (best == nil or d < best.Dist) then", "if (best == nil or d < best.Dist) then"),
    ("EH", "dimmer the closer", "return T.Near + (T.Far - T.Near) * k", "return T.Far - (T.Far - T.Near) * k"),
    ("EH", "the curtain collides", "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false",
     "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false"),
    ("MAIN", "never loaded", '"SignFit", "EdgeHint",', '"SignFit",'),
]


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def run(src: dict) -> tuple[int, str]:
    funcs = block(src["EH"], "EdgeHint.Plan") + block(src["EH"], "EdgeHint.Alpha")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "edge.luau"
        p.write_text(FIXTURE.replace("__FUNCS__", funcs), encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    out = proc.stdout + proc.stderr
    m = re.search(r"EDGE_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    eh = src["EH"]
    statics = [
        ("ClientMain loads EdgeHint", '"EdgeHint"' in (re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"]) or [""])[0]),
        ("the curtain is local, never collides / queried", "p.Parent = workspace.CurrentCamera" in eh
         and "p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false" in eh),
        ("r7: a soft haze, no hard panel (invisible part, edge-faded picture on both faces), no rays",
         "p.Transparency = 1" in eh and "Enum.Material.ForceField" not in eh and "gy.Rotation = 90" in eh
         and "haze(p, Enum.NormalId.Back)" in eh and "Beam" not in eh),
    ]
    for name, ok in statics:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: v.read_text(encoding="utf-8") for k, v in FILES.items()}
    failed, out = run(src)
    print(out)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        f, _ = run(m)
        if f > 0:
            caught += 1
            print(f"mutation caught: {name}")
        else:
            print(f"MUTATION_SURVIVED {name}")
    good = failed == 0 and caught == len(MUTATIONS)
    print(f"Status: {'passed' if good else 'failed'} (failed {failed}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
