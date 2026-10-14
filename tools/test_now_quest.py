"""A23-94 "the quest now" check (user 2026-10-09: one quest big at the left middle; 이미지 개발 draws line 1).

Runs, in the official Luau CLI, the CURRENT HUD.NowQuestIndex and HUD.QuestGoal (cut out of HUD.luau): line 1 = the
pinned row, else the waiting story, else the main story, else a row ready to [Claim], else the unfinished row closest to
done; the goal = the server's Goal, else the row's words without the " · ..." tail, ending with a full stop. Static:
refreshQuests uses NowQuestIndex for line 1 and every row carries Goal. Mutations: each must be caught.

Usage: py tools/test_now_quest.py
Report: docs/art/verification_2026-10-09/offline_now_quest_2026-10-09.json
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
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_now_quest_2026-10-09.json"

STATIC = [
    ("refreshQuests picks line 1 with HUD.NowQuestIndex (no pin / no story waiting)",
     ["\t\tshown = HUD.NowQuestIndex(entries, nil, function(e)\n"]),
    ("every row carries Goal (the server's first)",
     ['\t\t\tentry.Goal = HUD.QuestGoal(entry.Text, type(e.Goal) == "string" and L.QuestText(e.Goal) or nil) -- A23-94\n']),
]
MUTATIONS = [
    ("main ignored", '\t\tlocal main = e.Kind == "Main" or (type(e.Story) == "table" and e.Story.Kind == "Main")\n',
     "\t\tlocal main = false\n"),
    ("claim before main", "\t\tif main and (e.Progress < e.Target or claimRule(e)) then return i end\n",
     "\t\tif claimRule(e) then return i end\n"),
    ("the first unfinished, not the closest", "\t\t\tif share > bestShare then best, bestShare = i, share end\n",
     "\t\t\tif best == nil then best, bestShare = i, share end\n"),
    ("the story waiting ignored", "\tif callIndex and rows[callIndex] then return callIndex end\n", ""),
    ("the tail kept", '\tlocal main = string.match(text, "^(.-)%s+·%s") or text\n', "\tlocal main = text\n"),
    ("no full stop", '\tif not string.find(main, "[%.!%?。]$") then main ..= "." end\n', ""),
    ("the server's Goal ignored", '\tif type(serverGoal) == "string" and serverGoal ~= "" then return serverGoal end\n', ""),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local HUD = {}
for _, src in { GOAL_SOURCE, NOW_SOURCE } do
	local f = assert(loadstring(src, "=part"))
	setfenv(f, setmetatable({ HUD = HUD }, { __index = getfenv() }))
	f()
end
local function claim(e) return e.Progress >= e.Target and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub") end
local function row(kind, p, t, extra)
	local e = { Kind = kind, Progress = p, Target = t, CanClaim = true, Pinned = false }
	for k, v in extra or {} do e[k] = v end
	return e
end
local N = HUD.NowQuestIndex
check("a pinned row first", N({ row("Tutorial", 0, 5, { Pinned = true }), row("Daily", 5, 5) }, nil, claim) == 1)
check("the waiting story next", N({ row("Daily", 5, 5), row("Sub", 0, 1, { Story = { Id = "S1" } }) }, 2, claim) == 2)
check("main before a claimable daily", N({ row("Daily", 5, 5), row("Main", 1, 3) }, nil, claim) == 2)
check("main by its story kind", N({ row("Daily", 1, 5), row("Sub", 0, 2, { Story = { Kind = "Main" } }) }, nil, claim) == 2)
check("no main: the claimable row", N({ row("Daily", 1, 5), row("Daily", 5, 5) }, nil, claim) == 2)
check("nothing to claim: the closest to done", N({ row("Daily", 1, 5), row("Daily", 8, 10), row("Sub", 0, 1) }, nil, claim) == 2)
check("a tie keeps the earlier row", N({ row("Daily", 1, 2), row("Daily", 5, 10) }, nil, claim) == 1)
check("everything done but unclaimable: line 1", N({ row("Extra", 5, 5, { CanClaim = false }) }, nil, claim) == 1)
check("no rows: nil", N({}, nil, claim) == nil)
local G = HUD.QuestGoal
check("the tail goes, a full stop comes", G("Free the supply road · 5 slimes") == "Free the supply road.", G("Free the supply road · 5 slimes"))
check("a full stop is not doubled", G("Meet the guide!") == "Meet the guide!" and G("Go to Otto's Forge.") == "Go to Otto's Forge.")
check("plain words get a full stop", G("Defeat Slime ×5") == "Defeat Slime ×5.")
check("the server's Goal wins", G("x · y", "Defeat 5 slimes in Squishy Meadow.") == "Defeat 5 slimes in Squishy Meadow.")
check("no words: nil", G("", nil) == nil and G(nil, nil) == nil)
print(("NOW_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def run(src: str) -> tuple[int, int, str]:
    goal = re.search(r"\nfunction HUD\.QuestGoal\(text, serverGoal\)\n.*?\nend\n", src, re.S)
    now = re.search(r"\nfunction HUD\.NowQuestIndex\(rows, callIndex, claimRule\)\n.*?\n\treturn best or 1\nend\n", src, re.S)
    if not goal or not now:
        return 0, 1, "HUD.QuestGoal / HUD.NowQuestIndex missing"
    text = (f"local GOAL_SOURCE = [==========[{goal.group(0)}]==========]\n"
            f"local NOW_SOURCE = [==========[{now.group(0)}]==========]\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "now.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"NOW_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    for name, needles in STATIC:
        ok = all(src.count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(STATIC), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = HUD.read_text(encoding="utf-8")
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = hits == 1 and run(src.replace(old, new))[1] > 0
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
