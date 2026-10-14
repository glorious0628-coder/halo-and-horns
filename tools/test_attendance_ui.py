"""AttendanceUI offline check (plan docs/design/gameplay_plan_2026-10-13.md §1-A #5, SPEC A23-77; server = AttendanceService).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/AttendanceUI.luau with the CURRENT Config.luau and Util.luau in
tools/fixtures/attendance_ui_offline.luau with the installed official Luau CLI (build/luau_cli_0_741): Panels, the window
kit, UIKit's art, PauseCard, TweenService and the player are small doubles. Static: ClientMain loads it after Panels /
PauseCard; the HUD [Menu] square + glow; the words are English with no clock or countdown; nothing is sold in it; the
remote exists. Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only
when the fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-13/offline_attendance_ui_2026-10-13.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
MODULE = SCRIPTS / "AttendanceUI.luau"
HUD = SCRIPTS / "HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
UTIL = ROOT / "src/ReplicatedStorage/Shared/Util.luau"
NET = ROOT / "src/ReplicatedStorage/Shared/Net.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/attendance_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_attendance_ui_2026-10-13.json"

MUTATIONS = [
    # A23-167 ②: the tomorrow card's slot art (AttendanceUI.SlotIcon)
    ("the weekly box slot shows its first reward", "\tif def.Box == true then return L.Icons.Box end\n", ""),
    ("the slot art always the coin", "\treturn parts[1] and parts[1].Icon or nil\n", "\treturn L.Icons.Gold\n"),
    ("the 2x Gold pass ignored", "\t\tgold = math.floor(gold * (pass.Gold2 == true and mult or 1))\n", "\t\tgold = math.floor(gold)\n"),
    ("the 2x XP pass doubles gold", "(pass.Gold2 == true and mult or 1)", "(pass.XP2 == true and mult or 1)"),
    ("the materials forgotten", "\tif (tonumber(def.MaterialMin) or 0) > 0 then\n", "\tif false then\n"),
    ("the line in another order than the server's", "\tfor _, kind in { \"Gold\", \"XP\" } do\n", "\tfor _, kind in { \"XP\", \"Gold\" } do\n"),
    ("the weekly box taken: an empty board", "\tlocal weekDone = not ready and slot == 1 and int(ctx.Days) > 0 and ctx.ClassChosen == true\n",
     "\tlocal weekDone = false\n"),
    ("week done with no day collected", " and int(ctx.Days) > 0 and ctx.ClassChosen == true\n", " and ctx.ClassChosen == true\n"),
    ("week done without a class", " and int(ctx.Days) > 0 and ctx.ClassChosen == true\n", " and int(ctx.Days) > 0\n"),
    ("the next slot shown as today while taken", "\t\t\tstate = ready and \"Today\" or \"Next\"\n", "\t\t\tstate = \"Today\"\n"),
    ("the stamps one slot too far", "\t\tif weekDone or i < slot then\n", "\t\tif weekDone or i <= slot then\n"),
    ("a broken slot kept", "\tif slot < 1 or slot > n then slot = 1 end\n", ""),
    ("the farthest milestone first", "\ttable.sort(list, function(a, b) return int(a.Days) < int(b.Days) end)\n",
     "\ttable.sort(list, function(a, b) return int(a.Days) > int(b.Days) end)\n"),
    # final review 10/13 ②: never a reward that does not exist
    ("a milestone with nothing for me still shown", "\t\tif #what > 0 then return { Days = int(m.Days)",
     "\t\tif true then return { Days = int(m.Days)"),
    ("the name frame promised without its art", "and type(art.Id) == \"string\" and art.Id ~= \"\" then", "then"),
    ("the 28-day name frame skipped again (the photo's 50 days)", "then table.insert(what, tx(\"GoalBorder\")) end", "then end"),
    ("a phone keeps the PC rows ([Claim] cut off)", "\t\tfor key, v in L.Phone do z[key] = v end\n", ""),
    ("the other side's look promised", "\t\tif need == at and look.Faction == faction then", "\t\tif need == at then"),
    ("opens many times a day", "\tif ctx.Day == nil or ctx.Day == ctx.OpenedDay then return false end\n", ""),
    ("opens during the first mission", "\tif type(ctx.Step) ~= \"number\" or ctx.Step ~= (tonumber(ctx.Done) or 99) then return false end\n", ""),
    ("a first claim opens at once", "\treturn int(ctx.Days) > 0 or (tonumber(ctx.Played) or 0) >= L.FirstWait\n", "\treturn true\n"),
    ("a busy screen ignored", "\tctx.Busy = busy() -- (asked last: the checks above are cheap)\n", "\tctx.Busy = false\n"),
    ("a waiting pause card ignored", "\tfor _, fn in { \"IsOpen\", \"Waiting\" } do\n", "\tfor _, fn in { \"IsOpen\" } do\n"),
    ("opening by hand does not count", "\tS.OpenedDay = Config.DayIndex(os.time()) -- opened today", "\tlocal _ = Config.DayIndex(os.time()) -- opened today"),
    ("claim spam", "\tif attr(\"AttendReady\") ~= true or os.clock() - S.ClaimAt < L.ClaimWait then return end\n",
     "\tif attr(\"AttendReady\") ~= true then return end\n"),
    ("a claim sent with nothing open", "\tif attr(\"AttendReady\") ~= true or os.clock() - S.ClaimAt < L.ClaimWait then return end\n",
     "\tif os.clock() - S.ClaimAt < L.ClaimWait then return end\n"),
    ("the button never unlocks", "\tk.SetEnabled(VIEW.Button, b.Ready and not waiting)\n", "\tk.SetEnabled(VIEW.Button, b.Ready and S.ClaimAt < 0)\n"),
    ("the stamp never pops", "\t\tif got and animate and cell.Got == false and pop then", "\t\tif false then"),
    ("every refresh pops every stamp", "\t\tif got and animate and cell.Got == false and pop then", "\t\tif got and animate and pop then"),
    ("the glow ignores the claim", "\treturn S.Ready and attr(\"AttendReady\") == true\n", "\treturn S.Ready\n"),
    ("the ribbon never moves on", "\t\tif VIEW.RibbonKey ~= want and call(\"ArtId\", want) then\n", "\t\tif false then\n"),
    ("the board not redrawn on an answer", "\t\tif name == \"AttendReady\" or name == \"AttendSlot\"", "\t\tif name == \"AttendNone\" or name == \"AttendNone2\""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, config: str, util: str, name: str):
    path = ROOT / f"build/attendance_ui_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal UTIL_SOURCE = " + lua_str(util)
                    + "\nlocal UI_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"ATTENDANCE_UI_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = MODULE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    util = UTIL.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, config, util, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), config, util, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    block = re.search(r"\nConfig\.Attendance = \{(.*?)\n\}\n", config, re.S)
    words = re.search(r"\tText = \{(.*?)\n\t\},", block[1], re.S) if block else None
    words = [None, "\n".join(ln.split("--", 1)[0] for ln in words[1].splitlines())] if words else None  # the words only
    net = NET.read_text(encoding="utf-8-sig")
    static = [
        ("ClientMain loads AttendanceUI after Panels and PauseCard", "AttendanceUI" in names and "Panels" in names
         and "PauseCard" in names and names.index("AttendanceUI") > names.index("Panels")
         and names.index("AttendanceUI") > names.index("PauseCard")),
        ("the HUD [Menu] square opens the 'Attendance' window",
         '{ Id = "Attendance", Icon = "IconWeeklyBox", Window = "Attendance" }' in hud and "Config.Attendance.Text.Tile" in hud),
        ("[Menu] + the square glow while a claim is open (AttendanceUI.Ready, AttendReady redraws)",
         "local attend = L.AttendGlow()" in hud and 'L.SetGlow("attend", ui.attendGlow, attend)' in hud
         and "settings or travel or attend" in hud and '"VacationDays", "AttendReady" }, refreshMenuGlow)' in hud
         and "pcall(au.Ready)" in hud),
        ("the words are English (A23-48)", bool(words) and not re.search(r"[가-힣]", words[1])),
        ("no clock or countdown on the board (contract)", bool(words)
         and not re.search(r"hour|minute|left|%d:%d|countdown|streak", words[1], re.I)),
        ("nothing is sold in it", not re.search(r"MarketplaceService|Prompt[A-Za-z]*Purchase", code)),
        ("the claim remote exists (Net)", '"ClaimAttendance"' in net and 'Remote = "ClaimAttendance"' in src),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (MODULE, CONFIG, UTIL, HUD, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of Panels / UIKit: how the board looks on PC and phone is a Studio photo "
                             "check (메인 반영 1, after the merge); the claim itself, the KST day and the rewards are "
                             "AttendanceService's (tools/test_attendance.py)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
