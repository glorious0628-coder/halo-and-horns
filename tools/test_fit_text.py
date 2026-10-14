"""UIKit.FitText pass scheduling (검수 2026-10-08: main Play printed 9x "Maximum re-entrancy depth (80) exceeded calling
task.defer" from FitText - a pass deferred its next pass from inside a deferred resumption, 80 deep in one frame).

Runs the FIT block + UIKit.FitText cut from the CURRENT src/StarterPlayer/StarterPlayerScripts/UIKit.luau in
tools/fixtures/fit_text_offline.luau with the installed official Luau CLI (build/luau_cli_0_741): a frame / task
scheduler double that behaves like Roblox's deferred mode (deeper than 80 = the engine's error), deferred property
signals, a label double whose TextBounds / box follow its TextSize. Scenarios: a normal label converges; a feedback
label (its box grows with the text) never overflows the defer depth, writes at most a little a frame, does not run every
frame and still gets a pass after a capped burst; new words refit. Mutations: in-memory copies with one rule broken
each; each must make a check fail. Status "passed" only when the fixture passes AND every mutation was applied and
caught.
Report: docs/art/verification_2026-10-08/offline_fit_text_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
UIKIT = ROOT / "src/StarterPlayer/StarterPlayerScripts/UIKit.luau"
FIXTURE = ROOT / "tools/fixtures/fit_text_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_fit_text_2026-10-08.json"

MUTATIONS = [
    ("every pass deferred again in the same frame (the 80-deep error)",
     "local schedule = fit.PassFrame == FIT.Frame and FIT.NextFrame or task.defer", "local schedule = task.defer"),
    ("a pass never remembers its frame", "\t\t\t\tfit.PassFrame = FIT.Frame\n", ""),
    ("no burst cap (a feedback label runs every frame)", "\t\t\t\tif fit.Burst > FIT.BurstPasses then\n",
     "\t\t\t\tif false then\n"),
    ("no last pass after a capped burst", "\t\t\t\t\tif not fit.Settle then\n", "\t\t\t\t\tif false then\n"),
    ("the follow-up pass is dropped", "then fit.Pending = false; fit.Request(false) end",
     "then fit.Pending = false end"),
    # 10/14: a label's own floor (FitMinPx, PC tile names)
    ("FitMinPx ignored", "math.min(math.floor(minSize), fit.FloorPx or MIN_TEXT_SIZE)",
     "math.min(math.floor(minSize), MIN_TEXT_SIZE)"),
    ("FitMinPx never read", 'local floorPx = tonumber(label:GetAttribute("FitMinPx"))', "local floorPx = nil"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(src: str) -> str:
    """the FIT block (from its comment) through the end of function UIKit.FitText"""
    a = src.index("-- UIKit.FitText passes:")
    b = src.index("function UIKit.FitText(label, minSize, maxSize)", a)
    end = re.search(r"\nend\n", src[b:])
    assert end, "UIKit.FitText has no end"
    return src[a:b + end.end()]


def run(src: str, name: str):
    path = ROOT / f"build/fit_text_offline{name}.luau"
    path.write_text("local FIT_SOURCE = " + lua_str(cut(src)) + "\n" + FIXTURE.read_text(encoding="utf-8"),
                    encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=300)
    match = re.search(r"FIT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines()
             if ln.startswith("CHECK_FAIL") or ln.startswith("ITEM_ERROR") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = UIKIT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {UIKIT.relative_to(ROOT).as_posix(): hashlib.sha256(UIKIT.read_bytes()).hexdigest()},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "A scheduler double, not the engine: the real re-entrancy count and signal order are a "
                             "Studio Play check (the client console after a Play)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
