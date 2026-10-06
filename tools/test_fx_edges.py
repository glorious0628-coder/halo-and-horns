"""Offline test of the real Fx red screen edges (quality ideas 2026-10-06 #6), plus mutations.

A hit flashes the edges by its size (5% of MaxHealth or less = 0.94 transparency, 15% or more = 0.35), below 30% HP the
edges throb slowly (0.55-0.85, 1.1 s), never over an open window (Panels / WorldMap / pickers / Intro), with shake off
(setting or Roblox reduced motion) no flash or throb, only a steady faint 0.82 edge while HP is low; a running flash wins
over the throb. Extracted: MOTION.EDGE, flashEdges, MOTION.EdgeCovered / EdgeStep / ShakeAllowed.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-06/offline_fx_edges_2026-10-06.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FX = ROOT / "src/StarterPlayer/StarterPlayerScripts/Fx.luau"
FIXTURE = ROOT / "tools/fixtures/fx_edges_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_fx_edges_2026-10-06.json"

MUTATIONS = [
    ("every hit flashes fully", "f.BackgroundTransparency = E.SmallT + (E.BigT - E.SmallT) * k", "f.BackgroundTransparency = 0.3"),
    ("the edges draw over open windows", "if MOTION.EdgeCovered() or not MOTION.ShakeAllowed() then return end",
     "if not MOTION.ShakeAllowed() then return end"),
    ("shake off still flashes", "if MOTION.EdgeCovered() or not MOTION.ShakeAllowed() then return end",
     "if MOTION.EdgeCovered() then return end"),
    ("no low-HP throb",
     "local low = hum ~= nil and hum.Health > 0 and hum.MaxHealth > 0 and hum.Health / hum.MaxHealth < E.LowHP",
     "local low = false"),
    ("the throb overwrites a running flash", "\tif os.clock() < E.FlashUntil then return end\n", "\n"),
    ("shake off throbs anyway", "\t\t\tt = E.CalmT\n", "\t\t\tt = E.PulseHi + 0.1 * math.sin(os.clock())\n"),
    ("the throb draws over the bag", "if low and not MOTION.EdgeCovered() then", "if low then"),
    ("a dead player's edges still throb", "hum.Health > 0 and hum.MaxHealth > 0", "hum.MaxHealth > 0"),
]


def block(src: str, start: str) -> str:
    i = src.index(start)
    j = src.index("\nend\n", i)
    return src[i:j + 5]


def chunk(fx: str) -> str:
    edge = re.search(r"\tEDGE = \{.*?FlashUntil = 0 \},\n", fx, re.S)
    if not edge:
        raise ValueError("MOTION.EDGE missing; update the extractor")
    return ("local flashFrames, flashTweens = {}, {}\n"
            "local MOTION = {\n" + edge.group(0) + "}\n"
            + block(fx, "local function flashEdges(color, strength)")
            + block(fx, "function MOTION.EdgeCovered()")
            + block(fx, "function MOTION.EdgeStep()")
            + block(fx, "function MOTION.ShakeAllowed()")
            + "return { flash = flashEdges, MOTION = MOTION, frames = flashFrames }\n")


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(fx: str, name: str):
    path = ROOT / f"build/fx_edges_offline{name}.luau"
    path.write_text("local EDGE_SOURCE = " + lua_str(chunk(fx)) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=60)
    match = re.search(r"FX_EDGES_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    fx = FX.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(fx, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    static = [
        ("Hurt passes the hit's size",
         "flashEdges(COLOR_HURT, math.clamp((frac - E.Small) / math.max(E.Big - E.Small, 0.01), 0, 1))" in fx),
        ("the throb runs every frame", "local okE, errE = pcall(MOTION.EdgeStep)" in fx),
        ("no other caller flashes at full strength", fx.count("flashEdges(") == 2),
    ]
    for name, good in static:
        print(("STATIC ok   " if good else "STATIC FAIL ") + name)
    rows = []
    for name, old, new in MUTATIONS:
        applied = fx.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(fx.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(g for _, g in static) and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {FX.relative_to(ROOT).as_posix(): hashlib.sha256(FX.read_bytes()).hexdigest()},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The edge frames' look on PC / phone and the Hurt packet timing need a Studio check."}
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
