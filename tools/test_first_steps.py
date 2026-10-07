"""A23-68 first-minutes helpers offline test (FirstSteps.luau; user 2026-10-07 "ㅇㅇ 모두 좋다 구현하자").
#1 travel fade (dev2 324055a contract: Fx "Travel" { UserId, To, T } -> the server moves me T s later -> always
Fx "TravelDone" { UserId }): only my Travel counts; the guide window closes; 'Off to Squishy Meadow!  3' / 2 / 1;
black from T - Fade; TravelDone lifts it at once, else T + MaxExtra; the gui goes afterwards; a newer Travel keeps its
own timing. #2 hints in place during the first mission (TutorialStep 1..98): Idle s within my reach of a monster
without a swing of mine -> C.HUD.Hint("Attack") once (my swing restarts the wait, others' swings do not); in the meadow
before my first kill a marker over the nearest monster (my own slime first) via C.QuestMarker.Focus, not re-sent while
unchanged, cleared outside the meadow; my first kill (Reward) clears it (the Q hint moved to the Lv5 learn moment,
A23-71: no hint after the kill); nothing before / after the first mission. Static: ClientMain loads FirstSteps before SkillBar / Audio.
Runs the real FirstSteps.luau + Config.luau in tools/fixtures/first_steps_offline.luau.
Status "passed" only when the fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_first_steps_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
STEPS = ROOT / "src/StarterPlayer/StarterPlayerScripts/FirstSteps.luau"
CLIENT_MAIN = ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/first_steps_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_first_steps_2026-10-07.json"

MUTATIONS = [
    ("other players' Travel shows", "\tif kind == \"Travel\" and mine(data) then\n", "\tif kind == \"Travel\" then\n"),
    ("the guide window stays open", "\tcall(\"Panels\", \"Close\", false)", "\t-- (no close)"),
    ("no fade to black", "\t\tif token == TRAVEL.Token and not TRAVEL.Done then fade(0, TRAVEL.Fade) end\n", ""),
    ("TravelDone ignored", "\t\tTRAVEL.Finish(TRAVEL.Token)\n", "\t\t-- ignored\n"),
    ("no time limit", "\ttask.delay(t + TRAVEL.MaxExtra, function() TRAVEL.Finish(token) end)\n", ""),
    ("old timers lift a newer fade", "\tif token ~= TRAVEL.Token or TRAVEL.Done then return end\n", "\tif TRAVEL.Done then return end\n"),
    ("hints before the first mission", "\treturn step >= 1 and step < 99 and step ~= (tonumber(steps.Forge) or 3)\n",
     "\treturn step < 99 and step ~= (tonumber(steps.Forge) or 3)\n"),
    ("hints on the way to the Forge (A23-74)", "\treturn step >= 1 and step < 99 and step ~= (tonumber(steps.Forge) or 3)\n",
     "\treturn step >= 1 and step < 99\n"),
    ("the Forge walk says the zone", '(data.Spot == "Forge" and TXT.Forge) or ', ""),
    ("my swing does not restart the wait", "and mine(data) then\n\t\tHINT.NearSince = nil\n", "and mine(data) then\n"),
    ("the attack hint repeats", "\t\t\t\tHINT.AttackShown = true\n", ""),
    ("the marker ignores my own slime", "(isMine and not bestMine) or ", ""),
    ("the marker is re-sent every tick", "\tif HINT.Marked == model then return end\n", ""),
    ("the marker stays outside the meadow", "attr(\"ZoneId\", \"\") ~= \"SlimeMeadow\"", "false"),
    ("the kill keeps the marker", "\tHINT.Killed = true\n\tif HINT.Marked then HINT.Mark(nil) end\n", "\tHINT.Killed = true\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, steps: str, name: str):
    path = ROOT / f"build/first_steps_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal STEPS_SOURCE = " + lua_str(steps) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"FIRST_STEPS_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    steps = STEPS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, steps, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = steps.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config, steps.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    static = [
        ("ClientMain loads FirstSteps before SkillBar and Audio",
         "FirstSteps" in names and names.index("FirstSteps") < names.index("SkillBar") < names.index("Audio")),
        ("the travel line is English", 'Travel = "Off to %s!"' in steps),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (CONFIG, STEPS, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The hint looks (HUD.Hint, QuestMarker.Focus) are image dev's; how the fade and the hints "
                             "feel with the real server move is a Studio check (accept -> meadow)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
