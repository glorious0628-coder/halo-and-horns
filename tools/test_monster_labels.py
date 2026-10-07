"""MonsterLabels name-tag offline test (review devlog 12 + 2026-10-07 photos): one label pass (MonsterLabels.Tick) over
workspace.Monsters with a level camera double. A same-kind name whose tag would land on a shown same-kind tag on screen
(NameW x NameH px) hides, even when the two monsters are farther apart than Cluster studs (one behind the other); a
same-kind tag far away on screen and another kind's tag stay; the old world rule (same kind within Cluster studs) holds;
off-screen monsters never break the pass; a dying monster (anchored root, A23-74) shows no tag and takes no name slot. Runs the real MonsterLabels.luau + Config.luau in
tools/fixtures/monster_labels_offline.luau. Status "passed" only when the fixture passes AND every mutation was applied
and caught.
Report: docs/art/verification_2026-10-07/offline_monster_labels_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
LABELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/MonsterLabels.luau"
FIXTURE = ROOT / "tools/fixtures/monster_labels_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_monster_labels_2026-10-07.json"

MUTATIONS = [
    ("no screen check (the 2026-10-07 overlap)", "if a and b and math.abs(a.X - b.X) < T.NameW and math.abs(a.Y - b.Y) < T.NameH then",
     "if false then"),
    ("the screen check hides other kinds too", "\t\t\t\tif o.Kind == r.Kind then\n", "\t\t\t\tif true then\n"),
    ("no world cluster rule", "\t\t\t\t\tif (o.Pos - r.Pos).Magnitude < T.Cluster then\n", "\t\t\t\t\tif false then\n"),
    ("a far tag counts as overlapping", "Cluster = 5, NameW = 135, NameH = 24 }", "Cluster = 5, NameW = 1350, NameH = 24 }"),
    # A23-74 (user 2026-10-07): a dying monster (anchored root) shows no tag and takes no name slot
    ("a dying monster gets its tag back (no anchored check)", "and root.Anchored then", "and false then"),
    ("a tag left on over a dying body stays on", "\t\t\tif bb.Enabled then bb.Enabled = false end\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, labels: str, name: str):
    path = ROOT / f"build/monster_labels_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal LABELS_SOURCE = " + lua_str(labels) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"MONSTER_LABELS_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    labels = LABELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, labels, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = labels.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config, labels.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (CONFIG, LABELS)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Real camera angles / phone sizes are a Studio check (the projection here is a level camera)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
