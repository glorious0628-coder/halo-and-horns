"""Ground rings on bridges (게임성 개발 1, 검수 2026-10-10: the new arch bridges were left out of the ground raycast), offline.

Runs, in the official Luau CLI, the CURRENT refreshRayFilter cut out of Fx.luau on doubles: the Include list holds
Terrain, Map.Ground, Decor children named Bridge_*, and in a Decor "*Props" kit folder the cells' models whose names
hold "Bridge" (HaloProps.Cell_*.Halo_ArchBridge_*) - never the other props. Mutations: each must be caught.

Usage: py tools/test_ground_rays.py
Report: docs/art/verification_2026-10-10/offline_ground_rays_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_ground_rays_2026-10-10.json"
START, END = "local function refreshRayFilter(map)", "local function groundY(pos)"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function node(name, kids)
	local o = { Name = name, Kids = kids or {} }
	function o.GetChildren(self) return self.Kids end
	function o.FindFirstChild(self, n) for _, k in self.Kids do if k.Name == n then return k end end return nil end
	return o
end
local arch = node("Halo_ArchBridge_1")
local tree = node("Halo_Tree_3")
local cellBridge = node("Cell_Bridge_2")
local oldBridge = node("Bridge_Halo")
local lamp = node("Lamp_1")
local map = node("Map", {
	node("Ground"),
	node("Decor", { oldBridge, lamp, node("HaloProps", { node("Cell_1", { tree, arch }), cellBridge }) }),
})
local params = {}
local env = setmetatable({ rayParams = params, workspace = { Terrain = { Name = "Terrain" } } }, { __index = getfenv() })
local f = assert(loadstring(BLOCK .. "\nreturn refreshRayFilter", "=Rays"))
setfenv(f, env)
local refresh = f()
refresh(map)
local set = {}
for _, i in params.FilterDescendantsInstances or {} do set[i.Name] = true end
check(set.Terrain and set.Ground and set.Bridge_Halo, "Terrain, Map.Ground and Decor Bridge_* stay in", "")
check(set.Halo_ArchBridge_1, "the kit's arch bridge (HaloProps.Cell_*.Halo_ArchBridge_*) is in", "")
check(set.Cell_Bridge_2, "a kit cell that is itself a bridge is in", "")
check(not set.Halo_Tree_3 and not set.Lamp_1 and not set.HaloProps and not set.Cell_1, "other props and folders stay out", "")
refresh(nil)
check(#params.FilterDescendantsInstances == 1, "no map: Terrain only", #params.FilterDescendantsInstances)
print(("RAYS_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("kit bridges left out", 'elseif string.sub(d.Name, -5) == "Props" then', "elseif false then"),
    ("every kit prop counts", '\t\t\t\t\t\t\tif string.find(m.Name, "Bridge", 1, true) then table.insert(list, m) end\n',
     "\t\t\t\t\t\t\ttable.insert(list, m)\n"),
    ("the old bridges dropped", '\t\t\t\t\ttable.insert(list, d)\n', "\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(block: str) -> tuple[int, int, str]:
    text = "local BLOCK = " + lua_str(block) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "rays.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"RAYS_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    a, b = src.find(START), src.find(END)
    block = src[a:b]
    checks, failed, out = run(block)
    print(out.strip())
    muts = []
    for name, old, new in MUTATIONS:
        hits = block.count(old)
        caught = hits == 1 and run(block.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = a >= 0 and failed == 0 and checks > 0 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
