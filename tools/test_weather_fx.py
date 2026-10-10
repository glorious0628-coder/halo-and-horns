"""WeatherFx (A23-105, 이미지 개발 2026-10-10): rain, snow and the evening lamps on the client, offline.

Runs, in the official Luau CLI, the CURRENT WeatherFx.luau in tools/fixtures/weather_fx_offline.luau. Checks: the pure
plan (rain 420/s, 12% under a roof, 55% on phones, snow 110/s, off = nothing falls and no tint while the lamps still
follow the time of day, lamps on at Dusk / Night, off at Dawn / Day, left alone before the server has a phase); Start
with night rain: one anchored, invisible, non-colliding / non-queried / non-touching emitter part under the camera, the
rain emitter on with the recorded free textures, a client ColorCorrection WeatherTint, the tagged and the marked lamps on
and an unmarked light untouched; the part follows 32 studs over the camera and 14 ahead; a roof thins the rain and it
comes back; day turns the marked lamps off; a light added later inside a marked lantern follows; SetEnabled(false) stops
the rain but not the lamps; snow; no phase leaves a lamp as the place has it; never an Atmosphere, never a Lighting
property, no beams. Mutations: each must be caught.

Usage: py tools/test_weather_fx.py
Report: docs/art/verification_2026-10-10/offline_weather_fx_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"WX": ROOT / "src/StarterPlayer/StarterPlayerScripts/WeatherFx.luau"}
FIXTURE = ROOT / "tools/fixtures/weather_fx_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_weather_fx_2026-10-10.json"

MUTATIONS = [
    ("WX", "lamps off at dusk", 'if phase == "Dusk" or phase == "Night" then return true end',
     'if phase == "Night" then return true end'),
    ("WX", "no phase turns the lamps off", "\treturn nil\nend\n\n-- what to show", "\treturn false\nend\n\n-- what to show"),
    ("WX", "off still rains", "\tif enabled ~= true then return plan end\n", ""),
    ("WX", "a roof does not thin the rain", "(covered and T.RoofK or 1)", "1"),
    ("WX", "phones get the full rate", "(touch and T.TouchK or 1)", "1"),
    ("WX", "the emitter can be queried", "\tp.CanQuery = false\n", "\tp.CanQuery = true\n"),
    ("WX", "the emitter collides", "\tp.CanCollide = false\n", "\tp.CanCollide = true\n"),
    ("WX", "an Atmosphere for the wet look", '\tcc.Name = "WeatherTint"\n',
     '\tcc.Name = "WeatherTint"\n\tlocal atm = Instance.new("Atmosphere")\n'),
    ("WX", "every light follows the night", "\tif light:IsA(\"Light\") then S.Lamps[light] = true end\n",
     "\tif light:IsA(\"Light\") then S.Lamps[light] = true end\n\tfor _, d in workspace:GetDescendants() do if d:IsA(\"Light\") then S.Lamps[d] = true end end\n"),
    ("WX", "the part does not follow the camera", "\tif S.Part then S.Part.CFrame =", "\tif false then S.Part.CFrame ="),
    ("WX", "a late lamp inside a lantern is missed", "\t\t\tif isMarked(p) then\n", "\t\t\tif false then\n"),
    ("WX", "rain streaks along the fall again", "e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp",
     "e.Orientation = Enum.ParticleOrientation.VelocityParallel"),
    ("WX", "off stops the lamps too", "\tsetLamps(plan.Lamps)\n", "\tif S.Enabled then setLamps(plan.Lamps) end\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    text = "local WX_SOURCE = " + lua_str(src["WX"]) + "\n" + FIXTURE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "weather_fx.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"WEATHER_FX_SUMMARY checks=(\d+) failed=(\d+)", out)
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
