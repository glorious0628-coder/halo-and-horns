"""A23-61 offline test (user 2026-10-06 night): the basic attack hits the whole front half.

AimCone is a half-angle (CombatService.inAim: dot(look, dir) >= cos(AimCone); 180+ = everything), so the SPEC's
"front semicircle, 90 deg left / right, nothing behind" is AimCone = 90 on every class row and on bare hands; the SKL
skill cones (Config.Skills.Defs) are not part of it. Runs the real Config.luau and the inAim function cut out of
CombatService.luau in tools/fixtures/aim_cone_offline.luau (installed Luau CLI); static check: the client's
FaceTarget uses the same cone for its front half (HUD.luau; the pick itself: tools/test_auto_face.py). Mutations must each be caught.
Status "passed" only when the fixture and the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_aim_cone_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
COMBAT = ROOT / "src/ServerScriptService/CombatService.luau"
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
FIXTURE = ROOT / "tools/fixtures/aim_cone_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_aim_cone_2026-10-07.json"

INAIM = "\tif type(cone) ~= \"number\" or cone >= 180 then return true end\n"
# (name, file, old, new)
MUTATIONS = [
    ("the Warrior back to 75 (misses monsters right beside)", "config", "\t\tAimCone = 90,\n\t\tReleaseCenter = \"Self\"",
     "\t\tAimCone = 75,\n\t\tReleaseCenter = \"Self\""),
    ("bare hands back to 75", "config", "Interval = 0.8, AimCone = 90, PvPRatioMin", "Interval = 0.8, AimCone = 75, PvPRatioMin"),
    ("bare hands hit behind me (180 = everything)", "config", "Interval = 0.8, AimCone = 90, PvPRatioMin",
     "Interval = 0.8, AimCone = 180, PvPRatioMin"),
    ("the Mage at 120 (shots behind the side line)", "config",
     "AimCone = 90, -- A23-61: the front half (90 deg each side of where I face), nothing behind\n\t\tReleaseCenter = \"Target\", -- meteor",
     "AimCone = 120, -- A23-61: the front half (90 deg each side of where I face), nothing behind\n\t\tReleaseCenter = \"Target\", -- meteor"),
    ("the skill cone pulled into A23-61", "config", "Shape = \"Line\", Len = 22, Width = 10, AimCone = 75,",
     "Shape = \"Line\", Len = 22, Width = 10, AimCone = 90,"),
    ("inAim lets 90 hit everything", "combat", INAIM, "\tif type(cone) ~= \"number\" or cone >= 90 then return true end\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut_inaim(combat: str) -> str:
    m = re.search(r"\n(local function inAim\(root, pos, cone\)\n.*?\nend)\n", combat, re.S)
    if not m:
        raise ValueError("CombatService.inAim missing; update the extractor")
    return m.group(1)


def static_checks(hud: str):
    m = re.search(r"\nfunction L\.FaceTarget\(which\)\n(.*?)\nend\n", hud, re.S)
    body = m.group(1) if m else ""
    return [
        ("client FaceTarget reads the swing profile's AimCone (Config.AttackProfile) as the same half-angle",
         'which == "Swing" and Config.AttackProfile(' in body
         and "local frontDot = def.AimCone >= 180 and -2 or math.cos(math.rad(def.AimCone)) -- CombatService.inAim" in body),
        # A23-91 보강 (2026-10-09): the client now turns smoothly to the server's own pick (tools/test_auto_face.py):
        # a monster inside that cone is picked before a nearer one outside it (no server turn, the same target)
        ("client FaceTarget marks a monster inside that cone (on top of me counts, as inAim)",
         "Front = d < 1 or dot >= frontDot" in body),
    ]


def run(config: str, combat: str, name: str):
    path = ROOT / f"build/aim_cone_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal INAIM_SOURCE = " + lua_str(cut_inaim(combat)) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"AIM_CONE_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = {"config": CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
           "combat": COMBAT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")}
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src["config"], src["combat"], "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    static = static_checks(hud)
    for name, good in static:
        print(("STATIC ok   " if good else "STATIC FAIL ") + name)
    rows = []
    for name, key, old, new in MUTATIONS:
        applied = src[key].count(old) == 1
        caught, why = False, []
        if applied:
            mutated = dict(src)
            mutated[key] = src[key].replace(old, new)
            m_ok, _, why, _ = run(mutated["config"], mutated["combat"], "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "file": key, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(g for _, g in static) and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (CONFIG, COMBAT, HUD)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The feel in a real Play (SPEC: tune 120-180 deg total = AimCone 60-90 by playing) is a "
                             "Studio check."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"AIM_CONE checks={checks}")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
