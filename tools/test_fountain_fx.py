"""FountainFx: the 3-tier Halo fountain (검수 2026-10-09 night; 이미지 생성 1's measurements of Halo_Fountain_HD_plain,
docs/design/halo_town_plan_2026-10-09.md last section), offline.

Runs, in the official Luau CLI, the CURRENT FountainFx.luau in tools/fixtures/fountain_fx_offline.luau. Checks (검수
2026-10-10: each fountain by its own kit Model name, no mark guessing): Town_Halo_Fountain3 gets its spec (A23-121 stage 6:
the new Tripo model 1.0 x 1.0 x 0.733, measured on its mesh): a small jet off the finial tip (Y 1.0), 8 streams from the
top bowl rim (Y 0.748, R 0.118; its water 0.738, rim 0.121) into the middle bowl (water 0.525, rim 0.208), 12 from the
middle rim (Y 0.545, R 0.205) onto the deep pool's water (0.053) with ripples, pool twinkles on that water inside the
inner wall (r 0.39-0.40), more of them in a deeper blue, and no halo ring glow / light;
Town_Halo_Fountain (the cloud fountain, now in the Crossroads plaza) keeps the cloud spec with its ring glow whatever is
inside it; the
Crossroads K_Fountain is unchanged. Mutations: each must be caught.

Usage: py tools/test_fountain_fx.py
Report: docs/art/verification_2026-10-09/offline_fountain_fx_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"FX": ROOT / "src/StarterPlayer/StarterPlayerScripts/FountainFx.luau"}
FIXTURE = ROOT / "tools/fixtures/fountain_fx_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_fountain_fx_2026-10-09.json"

MUTATIONS = [
    ("FX", "the 3-tier spec under another name", "\tTown_Halo_Fountain3 = {\n", "\tTown_Halo_Fountain_X = {\n"),
    ("FX", "the jet back inside the gold ball", "\t\tJet = { Y = 1.0, Up = 5 },", "\t\tJet = { Y = 0.80, Up = 5 },"),
    ("FX", "the top bowl streams from the wrong rim", "{ FromY = 0.748, FromR = 0.118,", "{ FromY = 0.748, FromR = 0.145,"),
    ("FX", "the pool at the old model's height", "Pool = { Y = 0.053, R = 0.39, Rate = 8, Deep = true },",
     "Pool = { Y = 0.165, R = 0.39, Rate = 8, Deep = true },"),
    ("FX", "the twinkles as wide as the old pool", "Pool = { Y = 0.053, R = 0.39, Rate = 8, Deep = true },",
     "Pool = { Y = 0.053, R = 0.45, Rate = 8, Deep = true },"),
    ("FX", "the pool streams land on the old water", "ToY = 0.058, ToR = 0.26,", "ToY = 0.17, ToR = 0.26,"),
    ("FX", "the middle bowl streams leave the old rim", "{ FromY = 0.545, FromR = 0.205,", "{ FromY = 0.545, FromR = 0.25,"),
    ("FX", "the twinkles spill over the rim", "local side = spec.Pool.Deep and r * 1.4 or r * 1.6", "local side = r * 1.6"),
    ("FX", "the twinkles stay pale", "Color = spec.Pool.Deep and ColorSequence.new(COL.Deep, COL.Water) or", "Color ="),
    ("FX", "no more twinkles", "Rate = spec.Pool.Rate or 4,", "Rate = 4,"),
    ("FX", "the new one keeps a halo ring", "\t\tPool = { Y = 0.053, R = 0.39, Rate = 8, Deep = true },\n",
     "\t\tPool = { Y = 0.053, R = 0.39, Rate = 8, Deep = true },\n\t\tHalo = { Y = 1.02, R = 0.18 },\n"),
    ("FX", "the cloud fountain swapped for the new one by a mark", "\treturn SPECS[model.Name], model.Name\n",
     "\tif model:GetAttribute(\"FountainSpec\") then return SPECS.Town_Halo_Fountain3, \"Town_Halo_Fountain3\" end\n\treturn SPECS[model.Name], model.Name\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    text = "local FX_SOURCE = " + lua_str(src["FX"]) + "\n" + FIXTURE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "fountain_fx.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"FOUNTAIN_FX_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


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
