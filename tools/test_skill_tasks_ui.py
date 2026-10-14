"""99N D class tasks for skills 2 / 3 (게임성 개발 2 dev2-skill-tasks; 최종 검수 10/15), the screens, offline.

1. SkillBar.TaskLine(kit, slot, done): the same English line as the server's Config.SkillTaskLine for every kit x slot
   ("Lv15 skill: Defeat 40 monsters with basic attacks (3/40)"), each piece by its key (the slot name too); "" for Q /
   an unknown kit / the tasks off.
2. SkillBook.State: a locked slot whose level is there shows its task line; below the level "Unlocks at Lv15".
3. HUD L.GoalTiers: while a class task runs (SkillTaskSlot), its line is the 'Next' goal; else "Lv 15 · new skill".
Static: SkillBar's lock = the saved SkillSlots (the level rule only before the data), SkillBook.learned never the level
alone, a locked key press says the task line, the task attributes redraw the bar / book / goal chip.
Runs the CURRENT Config.luau (doubles) + the cut functions. Mutations: each must be caught.
Report: docs/art/verification_2026-10-15/offline_skill_tasks_ui_2026-10-15.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "BAR": SPS / "SkillBar.luau",
         "BOOK": SPS / "SkillBook.luau", "HUD": SPS / "HUD.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-15/offline_skill_tasks_ui_2026-10-15.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local base = { Vector3 = { new = vec, zero = vec() }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
	NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
	CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()

local SkillBar, SkillBook, L = {}, {}, {}
local function num(v, d) return tonumber(v) or d or 0 end
local T = { Text = { Wait = "%.1f s" } }
local WORDS = { UnlocksAt = "Unlocks at Lv%d", NeedMP = "Need MP", Ready = "Ready" }
local function word(k) return WORDS[k] end
local C = nil
local f = assert(loadstring(PARTS, "=Parts"))
setfenv(f, setmetatable({ SkillBar = SkillBar, SkillBook = SkillBook, L = L, Config = Config, num = num, T = T, word = word, C = C },
	{ __index = getfenv() }))
f()

-- 1. the line
local same, n = true, 0
for _, kit in { "Warrior", "Mage", "Archer", "Blacksmith", "Alchemist", "Tamer" } do
	for _, slot in { "Z", "X" } do
		for _, done in { 0, 3, 999 } do
			n += 1
			local a, b = SkillBar.TaskLine(kit, slot, done), Config.SkillTaskLine(kit, slot, done)
			if a ~= b or a == "" then same = false print("DIFF " .. kit .. slot .. ": " .. tostring(a) .. " | " .. tostring(b)) end
		end
	end
end
check(same and n == 36, "SkillBar.TaskLine = Config.SkillTaskLine for every kit x slot (36 cases)")
check(SkillBar.TaskLine("Warrior", "Z", 3) == "Lv15 skill: Defeat 40 monsters with basic attacks (3/40)",
	"the user's example line", SkillBar.TaskLine("Warrior", "Z", 3))
check(SkillBar.TaskLine("Warrior", "Q", 0) == "" and SkillBar.TaskLine("Nobody", "Z", 0) == "", "Q / an unknown kit: no line")
Config.Skills.Tasks.Enabled = false
check(SkillBar.TaskLine("Warrior", "Z", 0) == "", "the tasks off: no line")
Config.Skills.Tasks.Enabled = true

-- 2. the skill book state
local line = SkillBar.TaskLine("Warrior", "Z", 3)
local row = { Slot = "Z", Locked = true, Unlock = 15, MP = 10 }
local s1, k1 = SkillBook.State(row, { Level = 16, Tasks = { Z = line } })
check(s1 == line and k1 == "lock", "skill book: level there, task running -> its line", s1)
local s2 = SkillBook.State(row, { Level = 9, Tasks = { Z = line } })
check(s2 == "Unlocks at Lv15", "skill book: below the level -> 'Unlocks at Lv15'", s2)

-- 3. the goal chip (skill 2 switched on, as from 10/20: Config.Skills.ZEnabled)
local keepZ = Config.Skills.ZEnabled
Config.Skills.ZEnabled = true
local nextLine = L.GoalTiers(16, 0, 1, "Halo", nil, { Slot = "Z", Text = line })
check(nextLine == string.format(Config.GoalChips.Text.Next, line), "goal chip: the running task is the next goal", nextLine)
local plain = L.GoalTiers(12, 0, 1, "Halo", nil, nil)
check(type(plain) == "string" and not plain:find("Defeat", 1, true), "goal chip: no task -> the usual step", plain)
Config.Skills.ZEnabled = keepZ
print(("SKILL_TASKS_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("BOOK", "the book opens a slot by the level again", "\t\tif ok and num(n, 0) >= idx then return true end\n\tend\n\treturn false\nend",
     "\t\tif ok and num(n, 0) >= idx then return true end\n\tend\n\treturn num(ctx.Level, 1) >= unlockLevel(slot)\nend"),
    ("BAR", "the bar opens a slot by the level again", "\tif type(slots) == \"number\" then locked = slots < idx end\n",
     "\tif locked and type(slots) == \"number\" and slots >= idx then locked = false end\n"),
    ("BOOK", "the book never shows the task", "if type(task) == \"string\" and task ~= \"\" and num(ctx.Level, 1) >= row.Unlock then return task, \"lock\" end", ""),
    ("HUD", "the goal chip ignores the task", "\t\t\t\t\tat, text = level + 0.001, task.Text\n", ""),
    ("BAR", "the slot name not by its key", 'and trx(TT.SlotName, def.Slot) or "a skill"', 'and "Skill" or "a skill"'),
    ("BAR", "a locked key never says the task", "\tlocal line = task ~= \"\" and task or trx(TXT, \"Later\", level)\n",
     "\tlocal line = trx(TXT, \"Later\", level)\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find("\nend\n", a)
    return text[a:b + 5] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    bar, book, hud = src["BAR"], src["BOOK"], src["HUD"]
    return [
        ("SkillBar: the lock = the saved SkillSlots; a locked key says the task line; the task attributes redraw it",
         "\tif type(slots) == \"number\" then locked = slots < idx end\n" in bar
         and "\tlocal line = task ~= \"\" and task or trx(TXT, \"Later\", level)\n" in bar
         and '"SkillSlots", "SkillTaskSlot", "SkillTaskN", "SkillLearnReady" }, refreshAll)' in bar
         and "if st.On and st.Locked then LEARN.Tell(st.Unlock, slot) end" in bar),
        ("SkillBook: never the level alone; its context carries the task lines; the task attributes rebuild it",
         "\t\tif ok and num(n, 0) >= idx then return true end\n\tend\n\treturn false\nend" in book
         and "\t\tTasks = tasks," in book and "SkillTaskSlot = true, SkillTaskN = true," in book),
        ("HUD: the goal chip gets the running task (SkillBar.TaskFor) and redraws on its count",
         "math.floor(num(\"SkillSlots\", 0)), getFaction(), e, task," in hud
         and '"SkillTaskSlot", "SkillTaskN", "SkillLearnReady", "SkillTeacher" }, function() L.RefreshGoalTiers() end)' in hud),
    ]


def run(src: dict) -> tuple[int, int, str]:
    parts = (cut(src["BAR"], "local function trx(t, key, ...)") + "\n" + cut(src["BAR"], "function SkillBar.TaskLine(kit, slot, done)")
             + "\n" + cut(src["BOOK"], "function SkillBook.State(row, ctx)") + "\n" + cut(src["HUD"], "function L.GoalTiers("))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "skill_tasks_ui.luau"
        p.write_text("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal PARTS = " + lua_str(parts) + "\n" + FIXTURE,
                     encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"SKILL_TASKS_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks >= 10 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Runs the")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
