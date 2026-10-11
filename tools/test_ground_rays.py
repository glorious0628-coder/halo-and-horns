"""The walking ground (게임성 개발 1; 검수 2026-10-10: bridges; 2026-10-11 걷는 바닥 태그,
docs/design/halo_restart_2026-10-11.md 'WalkGround'), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau (Config.Ground, Config.GroundRoots) and the Shared Ground.luau
in tools/fixtures/ground_rays_offline.luau. The Include list holds Terrain, Map.Ground, Decor children named Bridge_*,
in a Decor "*Props" kit folder the cells / their models whose names hold "Bridge", and every instance tagged
"WalkGround" (listed once) - never the other props or untagged floors. Ground.Params: Include, water not ignored,
cached between rays, rebuilt at once on a tag added / removed or a new Map, and after Config.Ground.Refresh s.
Ground.Cast(pos, up, down). Static: LandShadow, SkillFx and Fx find the ground only through Ground.Cast (no ground
list of their own). Mutations: each must be caught.

Usage: py tools/test_ground_rays.py
Report: docs/art/verification_2026-10-11/offline_ground_rays_2026-10-11.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "GROUND": ROOT / "src/ReplicatedStorage/Shared/Ground.luau",
         "SHADOW": SS / "LandShadow.luau", "SKILLFX": SS / "SkillFx.luau", "FX": SS / "Fx.luau"}
FIXTURE = ROOT / "tools/fixtures/ground_rays_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_ground_rays_2026-10-11.json"

MUTATIONS = [
    ("CONFIG", "kit bridges left out", 'elseif string.sub(d.Name, -5) == "Props" then', "elseif false then"),
    ("CONFIG", "every kit prop counts", "\t\t\t\t\t\t\t\tif walkPiece(m.Name) then table.insert(list, m) end\n",
     "\t\t\t\t\t\t\t\ttable.insert(list, m)\n"),
    ("CONFIG", "a bridge cell left out", "\t\t\t\t\t\tif walkPiece(cell.Name) then\n\t\t\t\t\t\t\ttable.insert(list, cell)\n",
     "\t\t\t\t\t\tif walkPiece(cell.Name) then\n"),
    # 게임성 검수 10/13 (e27_stairs)
    ("CONFIG", "the kit's stairs left out (bridges only again)", 'KitWalk = { "Bridge", "Stairs", "Steps", "Ramp" }',
     'KitWalk = { "Bridge" }'),
    ("CONFIG", "floors by name too (an untagged Floor counts)", 'KitWalk = { "Bridge", "Stairs", "Steps", "Ramp" }',
     'KitWalk = { "Bridge", "Stairs", "Steps", "Ramp", "Floor" }'),
    ("CONFIG", "the old bridges dropped", "\t\t\t\t\ttable.insert(list, d)\n", "\n"),
    ("CONFIG", "tagged parts ignored", "\tfor _, inst in type(tagged) == \"table\" and tagged or {} do\n",
     "\tfor _, inst in {} do\n"),
    ("CONFIG", "tagged parts listed twice", "\t\tif not seen[inst] then\n", "\t\tif true then\n"),
    ("CONFIG", "Map.Ground dropped", "\t\tif ground then table.insert(list, ground) end\n\t\tlocal decor = map:FindFirstChild(\"Decor\")",
     "\t\tlocal decor = map:FindFirstChild(\"Decor\")"),
    ("CONFIG", "another tag name", 'Config.Ground = { Tag = "WalkGround", Refresh = 5,', 'Config.Ground = { Tag = "Floor", Refresh = 5,'),
    ("GROUND", "a tag change waits for the refresh", "\t\tlocal function dirty() S.Dirty = true end\n",
     "\t\tlocal function dirty() end\n"),
    ("GROUND", "a new Map waits for the refresh", "and map == S.Map and now", "and now"),
    ("GROUND", "never refreshed", "now - S.At < (tonumber(G.Refresh) or 5)", "true"),
    ("GROUND", "rebuilt every ray", "if S.Params and not S.Dirty and", "if false and"),
    ("GROUND", "water ignored", "params.IgnoreWater = false", "params.IgnoreWater = true"),
    ("GROUND", "Cast starts at pos", "pos + Vector3.new(0, up or 3, 0)", "pos"),
    ("SHADOW", "LandShadow back to its own list", "\tlocal hit = Ground.Cast(pos, 6, 80)\n\treturn hit and hit.Position",
     "\tlocal hit = nil\n\treturn hit and hit.Position"),
    ("SKILLFX", "SkillFx back to its own list", "function SkillFx.Ground(pos)\n\tlocal hit = Ground.Cast(pos, 6, 80)",
     "function SkillFx.Ground(pos)\n\tlocal hit = workspace:Raycast(pos, Vector3.new(0, -80, 0))"),
    ("FX", "Fx back to its own list", "local function groundY(pos)\n\tlocal hit = Ground.Cast(pos, 3, 80)",
     "local function groundY(pos)\n\tlocal hit = workspace:Raycast(pos, Vector3.new(0, -80, 0))"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    def uses(key, needle):
        return 'WaitForChild("Ground"))' in src[key] and needle in src[key]
    return [
        ("LandShadow finds the ground through Ground.Cast",
         uses("SHADOW", "local hit = Ground.Cast(pos, 6, 80)\n\treturn hit and hit.Position")
         and "RaycastParams" not in src["SHADOW"]),
        ("SkillFx finds the ground through Ground.Cast",
         uses("SKILLFX", "function SkillFx.Ground(pos)\n\tlocal hit = Ground.Cast(pos, 6, 80)")
         and "RAY.FilterDescendantsInstances" not in src["SKILLFX"]),
        ("Fx finds the ground through Ground.Cast",
         uses("FX", "local function groundY(pos)\n\tlocal hit = Ground.Cast(pos, 3, 80)")
         and "refreshRayFilter" not in src["FX"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal GROUND_SOURCE = " + lua_str(src["GROUND"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "rays.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"RAYS_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
