"""Crown war bar first showing (검수 2026-10-09, UI clutter review ③: "show it when it is needed").

Runs the CURRENT HUD.WarHidden (cut out of src/StarterPlayer/StarterPlayerScripts/HUD.luau) with the CURRENT
Config.Tutorial.Steps in the official Luau CLI (build/luau_cli_0_741): hidden only while the first mission is at its
first fight or on the way to the Forge (TutorialStep Kill / Forge); no step (not loaded), Guide, Quest, Done = shown.
Static: L.ApplyFold shows / hides ui.war with that rule, and when it comes in during play shows one toast
(TXT.WarIntro, English) and a NEW! tag. Mutations: in-memory copies with one rule broken each; each must be caught.

Usage: py tools/test_war_intro.py
Report: docs/art/verification_2026-10-09/offline_war_intro_2026-10-09.json
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
OUT = ROOT / "docs/art/verification_2026-10-09/offline_war_intro_2026-10-09.json"

STATIC = [
    ("ApplyFold hides / shows the war bar by HUD.WarHidden",
     ['\tlocal hideWar = HUD.WarHidden(attr("TutorialStep", nil), TUT.Steps)\n',
      "\tif ui.war and ui.war.Visible == hideWar then\n\t\tui.war.Visible = not hideWar\n"]),
    ("coming in during play: no toast (A23-191, user 10/14)", ['\t\t-- A23-191 (user 10/14): no "Crown War" intro toast when it comes in\n']),
    ("the line is short English", ['\tWarIntro = "Crown War: win points for your side!",'], "CONFIG"),
    ("검수 10/09 (user: too kind): the toast is switched off in Config.Nudges", ["\tWarIntro = false, --"], "CONFIG"),
]
MUTATIONS = [
    ("hidden on the way to the Forge only", "\treturn step == tonumber(steps.Kill) or step == tonumber(steps.Forge)\n",
     "\treturn step == tonumber(steps.Forge)\n"),
    ("hidden at the first fight only", "\treturn step == tonumber(steps.Kill) or step == tonumber(steps.Forge)\n",
     "\treturn step == tonumber(steps.Kill)\n"),
    ("hidden until the first Claim (too long)", "\treturn step == tonumber(steps.Kill) or step == tonumber(steps.Forge)\n",
     "\treturn step ~= tonumber(steps.Done)\n"),
    ("hidden while not loaded", '\tif type(step) ~= "number" or type(steps) ~= "table" then return false end\n',
     '\tif type(step) ~= "number" or type(steps) ~= "table" then return true end\n'),
    ("the bar never hidden", "\t\tui.war.Visible = not hideWar\n", "\t\tui.war.Visible = true\n"),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local HUD = {}
local f = assert(loadstring(FN_SOURCE, "=WarHidden"))
setfenv(f, setmetatable({ HUD = HUD }, { __index = getfenv() }))
f()
local S = STEPS
check("the steps are Kill 0 / Guide 1 / Quest 2 / Forge 3 / Done 99", S.Kill == 0 and S.Guide == 1 and S.Quest == 2 and S.Forge == 3 and S.Done == 99)
check("first fight: hidden", HUD.WarHidden(S.Kill, S) == true)
check("on the way to the Forge: hidden", HUD.WarHidden(S.Forge, S) == true)
check("after the Forge (Guide): shown", HUD.WarHidden(S.Guide, S) == false)
check("first quest (Quest): shown", HUD.WarHidden(S.Quest, S) == false)
check("done: shown", HUD.WarHidden(S.Done, S) == false)
check("not loaded (nil): shown", HUD.WarHidden(nil, S) == false)
check("no steps table: shown", HUD.WarHidden(0, nil) == false)
print(("WAR_INTRO_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def steps_lua(config: str) -> str:
    m = re.search(r"\tSteps = (\{ Kill = \d+, Guide = \d+, Quest = \d+, Forge = \d+, Done = \d+(?:, Teacher = \d+)? \}),", config)
    if not m:
        raise ValueError("Config.Tutorial.Steps not found")
    return m[1]


def run(src: str, config: str) -> tuple[int, int, str]:
    m = re.search(r"\nfunction HUD\.WarHidden\(step, steps\)\n.*?\nend\n", src, re.S)
    if not m:
        return 0, 1, "HUD.WarHidden missing"
    text = f"local FN_SOURCE = [==========[{m.group(0)}]==========]\nlocal STEPS = {steps_lua(config)}\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "war_intro.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    mm = re.search(r"WAR_INTRO_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(mm[2]) if mm else 1
    for entry in STATIC:
        name, needles = entry[0], entry[1]
        text = config if len(entry) > 2 and entry[2] == "CONFIG" else src
        ok = all(text.count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(mm[1]) if mm else 0) + len(STATIC), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src, config = HUD.read_text(encoding="utf-8"), CONFIG.read_text(encoding="utf-8")
    checks, failed, out = run(src, config)
    print(out.strip())
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = hits == 1 and run(src.replace(old, new), config)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
