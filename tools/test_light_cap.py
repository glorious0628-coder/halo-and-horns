"""LightCap (게임성 개발 1, 빛 마을 점검 #61, 2026-10-10), offline.

Runs, in the official Luau CLI, the CURRENT LightCap.luau in tools/fixtures/light_cap_offline.luau. Checks: the nearest
6 other characters (by distance to the camera) keep their lights; the rest go dark on this screen only; my own lights
are never touched; coming near brings back only the lights this module turned off (one the server turned off stays
off); going far turns them off. Static: ClientMain loads LightCap. Mutations: each must be caught.

Usage: py tools/test_light_cap.py
Report: docs/art/verification_2026-10-10/offline_light_cap_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"CAP": ROOT / "src/StarterPlayer/StarterPlayerScripts/LightCap.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/light_cap_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_light_cap_2026-10-10.json"

MUTATIONS = [
    ("CAP", "every light stays on", "\t\t\tif not on and l.Enabled then\n", "\t\t\tif false then\n"),
    ("CAP", "my own lights are capped too", "\t\tlocal char = p ~= me and p.Character or nil\n", "\t\tlocal char = p.Character\n"),
    ("CAP", "a server-off light comes back on", "\t\t\telseif on and S.Off[l] then\n", "\t\t\telseif on then\n"),
    ("CAP", "lights never come back", "\t\t\telseif on and S.Off[l] then\n", "\t\t\telseif false then\n"),
    ("CAP", "the farthest kept (no sort)", "\ttable.sort(list, function(a, b) return a.D < b.D end)\n",
     "\ttable.sort(list, function(a, b) return a.D > b.D end)\n"),
    ("MAIN", "never loaded", "\"StoryNpcs\", \"LightCap\",", "\"StoryNpcs\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    text = "local CAP_SOURCE = " + lua_str(src["CAP"]) + "\n" + FIXTURE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "light_cap.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"LIGHT_CAP_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    ok = order is not None and '"LightCap"' in order.group(1)
    out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + "ClientMain loads LightCap"
    failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + 1, failed, out


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
