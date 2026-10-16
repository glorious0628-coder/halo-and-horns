"""A23-216 ⑤ (user 2026-10-16 "진 쪽도 웃는 왕관전") - the crown-war round's end on the screen (게임성 개발 1).

Runs, in the official Luau CLI (build/luau_cli_0_741), HUD.WarRoundEnded cut out of HUD.luau: a round ended = the
server's WarRoundEndsAt moved forward after a round that was played (WarMode not Idle); the first look, an Idle round,
the same / an older time are not. Static: on that end the war bar slides back to balance from the share the round left
(L.WarFracSeen, kept while 0 : 0 of the new round arrives first), both badges pop once together (L.BadgePop), the next
round's bell (Config.Audio.Sounds.WarNext = the 30-s bell's file, 0 won) after the winner's crown sound; no words, no
banner, no darkening (no Notify / Toast / Banner / Darken in the new code). Mutations: in-memory copies with one rule
broken each; each must be caught.

Usage: py tools/test_war_round_end.py
Report: docs/art/verification_2026-10-16/offline_war_round_end_2026-10-16.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-16/offline_war_round_end_2026-10-16.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name) end
end
local E = HUD.WarRoundEnded
check("a played round ended: the time moved on", E({ Ends = 1000, Mode = "Normal" }, { Ends = 1600, Mode = "Normal" }) == true)
check("the first look is no end", E(nil, { Ends = 1600, Mode = "Normal" }) == false)
check("an Idle round (nobody playing) ends quietly", E({ Ends = 1000, Mode = "Idle" }, { Ends = 1600, Mode = "Normal" }) == false)
check("the same time is no end", E({ Ends = 1000, Mode = "Normal" }, { Ends = 1000, Mode = "Normal" }) == false)
check("an older time is no end", E({ Ends = 1600, Mode = "Normal" }, { Ends = 1000, Mode = "Normal" }) == false)
check("no time yet (0) is no end", E({ Ends = 0, Mode = "Normal" }, { Ends = 600, Mode = "Normal" }) == false)
check("no mode known is no end", E({ Ends = 1000 }, { Ends = 1600 }) == false)
print(("WAR_END_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

STATIC = [
    ("HUD", "a round end starts the slide from the share it left, then forgets it", [
        "\tif HUD.WarRoundEnded(L.WarSeen, now) then\n\t\tL.WarRoundEnd(L.WarFracSeen or 0.5)\n\t\tL.WarFracSeen = nil\n"]),
    ("HUD", "the share kept only while the round has points", ["if h + r > 0 and not L.WarSliding then L.WarFracSeen = frac end"]),
    ("HUD", "the bar slides back to balance", ["{ Value = 0.5 }", "v.Changed:Connect(function(f) pcall(L.WarDraw, f) end)"]),
    ("HUD", "both badges pop once together", ["\t\tpcall(L.BadgePop, ui.warBadgeHalo)\n\t\tpcall(L.BadgePop, ui.warBadgeHorns)\n"]),
    ("HUD", "the next round's bell after the winner's crown sound", ['L.RoundEnd = { Back = 0.9, Bell = 2.0, Sound = "WarNext" }',
                                                                    "pcall(C.Audio.Play, P.Sound)"]),
    ("HUD", "my own crown point still pops only my side", ["\treturn L.BadgePop(badge)\nend\n"]),
    ("CONFIG", "the bell = the 30-s bell's file (0 won), higher and softer", [
        'WarNext = { File = "WarFinal30", Volume = 0.35, Speed = { 1.25, 1.25 }, Max = 1, Gap = 30 },']),
]


def cut(src: str, name: str) -> str:
    m = re.search(r"\nfunction HUD\." + name + r"\(.*?\nend\n", src, re.S)
    return m[0] if m else ""


def run(files: dict[str, str]) -> tuple[int, int, str]:
    fn = cut(files["HUD"], "WarRoundEnded")
    lua = "local HUD = {}\n" + fn + FIXTURE
    out, failed, checks = "", 0, 0
    if not fn:
        failed += 1
        out += "\nCHECK_FAIL HUD.WarRoundEnded not found"
    else:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "war_end.luau"
            p.write_text(lua, encoding="utf-8")
            proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
        out += proc.stdout + proc.stderr
        m = re.search(r"WAR_END_SUMMARY checks=(\d+) failed=(\d+)", out)
        checks += int(m[1]) if m else 0
        failed += int(m[2]) if m else 1
    for fk, name, needles in STATIC:
        ok = all(files[fk].count(n) == 1 for n in needles)
        checks += 1
        failed += 0 if ok else 1
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    a = files["HUD"].find("\nL.RoundEnd = {")
    b = files["HUD"].find("\nlocal function refreshWar()")
    new = files["HUD"][a:b] if a >= 0 and b > a else ""
    quiet = new != "" and not re.search(r"Notify|Toast|Banner|Darken|Text =", new)
    checks += 1
    failed += 0 if quiet else 1
    out += ("\nSTATIC_OK " if quiet else "\nSTATIC_FAIL ") + "no words, no banner, no darkening in the round end"
    return checks, failed, out


MUTATIONS = [
    ("HUD", "an Idle round celebrates", 'old.Mode ~= nil and old.Mode ~= "Idle"', "old.Mode ~= nil"),
    ("HUD", "the first look celebrates", "return a > 0 and b > a + 1", "return b > a + 1"),
    ("HUD", "the slide starts from balance", "L.WarRoundEnd(L.WarFracSeen or 0.5)", "L.WarRoundEnd(0.5)"),
    ("HUD", "the new round's 0 : 0 wipes the share", "if h + r > 0 and not L.WarSliding then L.WarFracSeen = frac end",
     "if not L.WarSliding then L.WarFracSeen = frac end"),
    ("HUD", "only one badge pops", "\t\tpcall(L.BadgePop, ui.warBadgeHorns)\n", ""),
    ("HUD", "no bell", "pcall(C.Audio.Play, P.Sound)", "pcall(print, P.Sound)"),
    ("HUD", "a banner line", "\tL.WarSliding = true\n", "\tL.WarSliding = true\n\tpcall(UIKit.Toast, \"Next round!\")\n"),
    ("CONFIG", "a new paid sound file", 'WarNext = { File = "WarFinal30",', 'WarNext = { File = "WarNextBell",'),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    files = {"HUD": HUD.read_text(encoding="utf-8").replace("\r\n", "\n"),
             "CONFIG": CONFIG.read_text(encoding="utf-8").replace("\r\n", "\n")}
    checks, failed, out = run(files)
    print(out.strip())
    muts = []
    for fk, name, old, new in MUTATIONS:
        hits = files[fk].count(old)
        caught = False
        if hits == 1:
            copy = dict(files)
            copy[fk] = files[fk].replace(old, new)
            caught = run(copy)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
