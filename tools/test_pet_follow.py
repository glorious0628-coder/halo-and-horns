"""Offline test of the real PetFollow (PET-3, review 2026-10-06), plus mutations: the pet follows behind-right of its
owner, a headbutt reaches the target at about the contact time, and the pet runs back over P.Back seconds (it used to
jump back in one frame); Attack / Dash / Has answers.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_pet_follow_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/StarterPlayer/StarterPlayerScripts/PetFollow.luau"
FIXTURE = ROOT / "tools/fixtures/pet_follow_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_pet_follow_2026-10-07.json"

MUTATIONS = [
    ("the pet jumps back in one frame (old)", "goal = a.BackFrom:Lerp(goal, 1 - (1 - k) * (1 - k))", "goal = goal"),
    ("the pet reaches the target at once", "goal = from:Lerp(target, k * k)", "goal = target"),
    ("the pet follows on the left", "return root.Position + right * P.Offset.X - flat * P.Offset.Z",
     "return root.Position - right * P.Offset.X - flat * P.Offset.Z"),
    ("Attack ignores a missing pet", "if not st or not st.Model or not st.Model.Parent or st.Hidden then return false end",
     "if false then return false end"),
    # PET-4 (검수 2026-10-09)
    ("phones draw every pet", " or (phone and uid ~= me and not S.Near[uid])", ""),
    ("the phone limit hides my own pet", "(phone and uid ~= me and not S.Near[uid])", "(phone and not S.Near[uid])"),
    ("no range on phones", "\t\tif i > max or e.D > range then break end\n", "\t\tif i > max then break end\n"),
    ("never re-ranked", "\t\tS.RankAt = now + P.RankEvery\n", "\t\tS.RankAt = math.huge\n"),
    ("the tag stays without a story name", "\t\tif tag then tag.Enabled = false end\n", ""),
    ("the tag keeps its first name", "\tif st.TagLabel and st.TagLabel.Text ~= name then st.TagLabel.Text = name end\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(source: str, name: str):
    path = ROOT / f"build/pet_follow_offline{name}.luau"
    path.write_text("local SOURCE = " + lua_str(source) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"PET_FOLLOW_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    source = SOURCE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(source, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = source.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(source.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {SOURCE.relative_to(ROOT).as_posix(): hashlib.sha256(SOURCE.read_bytes()).hexdigest()},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Ground rays, real model scaling and the look in Studio need a Studio check."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
