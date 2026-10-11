"""Opening shot 3a through the new Halo gate (게임성 개발 1, 2026-10-11; A23-121, 검수 10/11: 이미지 생성 1's WorldKit
blockout photos art/review/world/halo_v2/blockout/03_opening_start, 03b, 04), offline / static.

Reads the CURRENT Intro.luau: HALO_SHOT offsets from SPOT.Halo, the Halo cut uses them and still looks at SPOT.Halo,
the gold shard still starts at SPOT.Halo + (0, 55, 70). Geometry in world studs (halo_restart_2026-10-11.md fixed
points): the start hangs over Bridge_Halo (z -150..-330, deck y ~0.2, width 22) well above the deck; the end is
just inside the gate (Gate_HaloTown z -330, passage 16 wide x 30 long = z -315..-345) toward the town; on every step
through the passage the camera keeps to the middle (|x| <= 2) at 12..14 high; it moves toward the town. Mutations:
each must be caught.

Usage: py tools/test_intro_halo_shot.py
Report: docs/art/verification_2026-10-11/offline_intro_halo_shot_2026-10-11.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
INTRO = ROOT / "src/StarterPlayer/StarterPlayerScripts/Intro.luau"
OUT = ROOT / "docs/art/verification_2026-10-11/offline_intro_halo_shot_2026-10-11.json"

BRIDGE_Z = (-330.0, -150.0)
BRIDGE_HALF_W, DECK_Y = 11.0, 0.2
GATE_Z, PASSAGE_HALF_W, PASSAGE_Z = -330.0, 8.0, (-345.0, -315.0)
PASS_Y = (12.0, 14.0)
NUM = r"(-?[\d.]+)"

MUTATIONS = [
    ("the old shot from the side", "local HALO_SHOT = { From = Vector3.new(0, -4, 140), To = Vector3.new(0, -2, 58) }",
     "local HALO_SHOT = { From = Vector3.new(18, -2, 95), To = Vector3.new(6, -6, 70) }"),
    ("ends outside the gate", "To = Vector3.new(0, -2, 58) }", "To = Vector3.new(0, -2, 90) }"),
    ("hits the passage ceiling", "From = Vector3.new(0, -4, 140)", "From = Vector3.new(0, 4, 140)"),
    ("starts off the bridge", "From = Vector3.new(0, -4, 140)", "From = Vector3.new(30, -4, 140)"),
    ("the cut ignores HALO_SHOT",
     "look(SPOT.Halo + HALO_SHOT.From, SPOT.Halo), look(SPOT.Halo + HALO_SHOT.To, SPOT.Halo), 3)",
     "look(SPOT.Halo + Vector3.new(18, 14, 95), SPOT.Halo), look(SPOT.Halo + Vector3.new(6, 10, 70), SPOT.Halo), 3)"),
    ("looks somewhere else", "look(SPOT.Halo + HALO_SHOT.To, SPOT.Halo), 3)", "look(SPOT.Halo + HALO_SHOT.To, SPOT.Shard), 3)"),
    ("the gold shard moved", "local gold = shard(SPOT.Gold, SPOT.Halo + Vector3.new(0, 55, 70))",
     "local gold = shard(SPOT.Gold, SPOT.Halo + Vector3.new(0, 55, 140))"),
    ("flies away from the town", "local HALO_SHOT = { From = Vector3.new(0, -4, 140), To = Vector3.new(0, -2, 58) }",
     "local HALO_SHOT = { From = Vector3.new(0, -2, 58), To = Vector3.new(0, -4, 140) }"),
]


def vec(src: str, pattern: str):
    m = re.search(pattern, src)
    return tuple(float(m[i]) for i in (1, 2, 3)) if m else None


def checks(src: str) -> list[tuple[str, bool]]:
    halo = vec(src, r"\tHalo = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\),")
    m = re.search(r"local HALO_SHOT = \{ From = Vector3\.new\(" + NUM + ", " + NUM + ", " + NUM + r"\), To = Vector3\.new\("
                  + NUM + ", " + NUM + ", " + NUM + r"\) \}", src)
    out = [("SPOT.Halo and HALO_SHOT are readable", halo is not None and m is not None)]
    if not out[0][1]:
        return out
    f = tuple(halo[i] + float(m[i + 1]) for i in range(3))
    t = tuple(halo[i] + float(m[i + 4]) for i in range(3))
    out.append(("the Halo cut flies HALO_SHOT and looks at SPOT.Halo",
                "if not shot(token, look(SPOT.Halo + HALO_SHOT.From, SPOT.Halo), look(SPOT.Halo + HALO_SHOT.To, SPOT.Halo), 3) "
                "then return end" in src))
    out.append(("the gold shard still starts at SPOT.Halo + (0, 55, 70)",
                "local gold = shard(SPOT.Gold, SPOT.Halo + Vector3.new(0, 55, 70))" in src))
    out.append(("start = (0, 12, -270) over the bridge", f == (0.0, 12.0, -270.0)
                and BRIDGE_Z[0] < f[2] < BRIDGE_Z[1] and abs(f[0]) <= BRIDGE_HALF_W and f[1] - DECK_Y >= 8))
    out.append(("end = (0, 14, -352) just inside the gate", t == (0.0, 14.0, -352.0) and t[2] < PASSAGE_Z[0]
                and abs(t[0]) <= 2 and PASS_Y[0] <= t[1] <= PASS_Y[1]))
    out.append(("it moves toward the town (through the gate)", f[2] > GATE_Z > t[2]))
    ok = True
    for i in range(201):
        k = i / 200
        p = tuple(f[j] + (t[j] - f[j]) * k for j in range(3))
        if PASSAGE_Z[0] <= p[2] <= PASSAGE_Z[1]:
            ok = ok and abs(p[0]) <= min(2.0, PASSAGE_HALF_W) and PASS_Y[0] <= p[1] <= PASS_Y[1]
    out.append(("through the passage it keeps to the middle at 12..14 high", ok))
    return out


def run(src: str) -> tuple[int, int, list[str]]:
    res = checks(src)
    lines = [("CHECK_OK " if ok else "CHECK_FAIL ") + name for name, ok in res]
    return len(res), sum(0 if ok else 1 for _, ok in res), lines


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = INTRO.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    n, failed, lines = run(src)
    print("\n".join(lines))
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = hits == 1 and run(src.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and n > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": n, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {n}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
