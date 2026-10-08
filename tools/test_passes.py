"""Passes offline check (SPEC A23-75: one thank-you line right after a purchase, never at the join).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/Passes.luau in tools/fixtures/passes_offline.luau with the
installed official Luau CLI (build/luau_cli_0_741): the LocalPlayer attributes, MarketplaceService purchase-finished
signals, UIKit.Toast and os.clock are small doubles. Static: ClientMain loads Passes; no purchase prompt in it (it only
thanks - the Shop window asks, A23-75 no pressure).
Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when the
fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_passes_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
PASSES = SCRIPTS / "Passes.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/passes_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_passes_2026-10-08.json"

MUTATIONS = [
    ("the join-time check speaks too", "\tif os.clock() - S.BoughtAt > T.BoughtWindow then return nil end\n", ""),
    ("a closed window counts as bought", "\tif purchased == true then S.BoughtAt = os.clock() end\n", "\tS.BoughtAt = os.clock()\n"),
    ("one purchase, many thank-yous", "\t\tS.BoughtAt = -math.huge -- one purchase, one thank-you\n", ""),
    ("another player's purchase counts", "\t\t\tif player == LocalPlayer then Passes.Bought(purchased) end\n",
     "\t\t\tPasses.Bought(purchased)\n"),
    ("a look list that did not grow speaks", "\t\tif type(value) == \"string\" and #value > #before then line = T.LookLine end\n",
     "\t\tif type(value) == \"string\" then line = T.LookLine end\n"),
    ("a flag turning off speaks", "\t\tif value == true and prev ~= true then line = T.Lines[attr] end\n",
     "\t\tif value ~= prev then line = T.Lines[attr] end\n"),
    ("looks bought as products are ignored", "\t\t\tif userId == LocalPlayer.UserId then Passes.Bought(purchased) end\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, name: str):
    path = ROOT / f"build/passes_offline{name}.luau"
    path.write_text("local PASSES_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"PASSES_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = PASSES.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
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
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    static = [
        ("ClientMain loads Passes", "Passes" in names),
        ("Passes never opens a purchase window (it only thanks)", "PromptGamePassPurchase(" not in code
         and "PromptProductPurchase(" not in code and "PromptPurchase(" not in code),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (PASSES, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of MarketplaceService: a real purchase (and the server turning the flag on) "
                             "is a live check with Robux test purchases after the pass ids exist (launch_ops_checklist)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
