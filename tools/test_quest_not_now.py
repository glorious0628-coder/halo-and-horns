"""Rows you cannot do now fold away (최종 검수 10/14, 감사 2 '못 하는 일 숨기기'), offline.

Config.QuestNotNow { Enabled, Window = 3600, Check, GooseGuide = "Goose", WarRows = { S2 = true } }; HUD L.NotNow(e, gs, now):
1. a story row guided to the goose (S1 / GW5 'Join a Golden Egg hunt'): shown while a hunt runs (GooseActive) or the
   next one (GooseNextAt) is within Window s; else folded (no next time known = folded).
2. a WarRows row (S2 crown war chest): folded while the war is not fought (WarMode Idle) or the round ends later than
   Window s.
3. every other row (dailies, mains, rows without Story) is never folded; Enabled = false folds nothing.
HUD: parseQuests skips a folded row (the quest window keeps it); the lines redraw when GooseActive / GooseNextAt /
WarMode / WarRoundEndsAt change or every Check s when the set of folded rows changed (the clock passing).
The Lv15 empty Z slot: already hidden while Config.Skills.ZEnabled is off (SkillBar, SkillBook, goal chips, the server's
next-goal row) - checked statically here.
Extracted and run: Config.QuestNotNow (from Config.luau) + L.NotNow with a GameState double. Mutations: each must fail.
Report: docs/art/verification_2026-10-14/offline_quest_not_now_2026-10-14.json (do not commit)
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
FILES = {"HUD": SPS / "HUD.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "SKILLBAR": SPS / "SkillBar.luau", "SKILLBOOK": SPS / "SkillBook.luau",
         "QUEST": ROOT / "src/ServerScriptService/QuestService.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_quest_not_now_2026-10-14.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local Config = {}
local cf = assert(loadstring(CFG_LINE, "=Config"))
setfenv(cf, setmetatable({ Config = Config }, { __index = getfenv() }))
cf()
local L = {}
local f = assert(loadstring(PART, "=HUD"))
setfenv(f, setmetatable({ L = L, Config = Config }, { __index = getfenv() }))
f()
local GS = {}
local function gs(k, d) local v = GS[k] if v == nil then return d end return v end
local NOW = 100000
local goose = { Id = "story:S1", Story = { Id = "S1", Guide = "Goose" } }
local gw5 = { Id = "story:GW5", Story = { Id = "GW5", Guide = "Goose" } }
local chest = { Id = "story:S2", Story = { Id = "S2" } }
local main = { Id = "story:M1_3", Story = { Id = "M1_3", Guide = "Crossroads" } }
local daily = { Id = "Kill", Kind = "Daily" }

check(Config.QuestNotNow.Window == 3600 and Config.QuestNotNow.WarRows.S2 == true, "Config: an hour, S2 the war row")
-- goose
GS = { GooseActive = true }
check(L.NotNow(goose, gs, NOW) == false, "a hunt running: the goose row shows")
GS = { GooseNextAt = NOW + 1800 }
check(L.NotNow(goose, gs, NOW) == false and L.NotNow(gw5, gs, NOW) == false, "the next hunt in 30 min: shows (S1 and GW5)")
GS = { GooseNextAt = NOW + 3600 }
check(L.NotNow(goose, gs, NOW) == false, "exactly an hour: shows")
GS = { GooseNextAt = NOW + 3601 }
check(L.NotNow(goose, gs, NOW) == true, "more than an hour: folded")
GS = { GooseNextAt = NOW + 4 * 3600 }
check(L.NotNow(goose, gs, NOW) == true, "four hours away: folded")
GS = {}
check(L.NotNow(goose, gs, NOW) == true, "no next time known: folded")
-- war chest
GS = { WarMode = "Idle", WarRoundEndsAt = NOW + 60 }
check(L.NotNow(chest, gs, NOW) == true, "the war not fought (Idle): the chest row folded")
GS = { WarMode = "Normal", WarRoundEndsAt = NOW + 300 }
check(L.NotNow(chest, gs, NOW) == false, "a round ends in 5 min: shows")
GS = { WarMode = "Siege", WarRoundEndsAt = NOW + 7200 }
check(L.NotNow(chest, gs, NOW) == true, "a round ending in 2 h (the switch pushing it): folded")
-- the rest
GS = {}
check(L.NotNow(main, gs, NOW) == false and L.NotNow(daily, gs, NOW) == false, "a main / a daily: never folded")
check(L.NotNow(nil, gs, NOW) == false and L.NotNow(goose, nil, NOW) == false, "no row / no GameState reader: nothing folds")
Config.QuestNotNow.Enabled = false
check(L.NotNow(goose, gs, NOW) == false and L.NotNow(chest, gs, NOW) == false, "switched off: nothing folds")
print(("QUEST_NOT_NOW_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("HUD", "a running hunt still folds", '\t\tif gs("GooseActive", false) == true then return false end\n', ""),
    ("HUD", "an hour off by one", "return not (nextAt > 0 and nextAt - now <= window)", "return not (nextAt > 0 and nextAt - now < window)"),
    ("HUD", "an unknown next time shows", "return not (nextAt > 0 and nextAt - now <= window)", "return not (nextAt - now <= window)"),
    ("HUD", "an idle war shows the chest", '\t\tif gs("WarMode", "Idle") == "Idle" then return true end\n', ""),
    ("HUD", "a far round shows the chest", "return not (ends > 0 and ends - now <= window)", "return false"),
    ("HUD", "the switch ignored", "or R.Enabled ~= true or", "or"),
    ("HUD", "every story row folds", '\tif not story then return false end\n', '\tif true then return story ~= nil end\n'),
    ("HUD", "parseQuests ignores it", "or L.NotNow(e, UIKit.GameAttr, now)) then table.insert(shown, e) end",
     ") then table.insert(shown, e) end"),
    ("HUD", "no redraw when the goose / war changes",
     'UIKit.OnGameAttr({ "GooseActive", "GooseNextAt", "WarMode", "WarRoundEndsAt" }, notNowCheck)', "local _ = notNowCheck"),
    ("CONFIG", "the window not an hour", "Window = 3600, Check = 15,", "Window = 60, Check = 15,"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    h = src["HUD"]
    return [
        ("parseQuests folds a row you cannot do now (the quest window keeps it)",
         "or L.NotNow(e, UIKit.GameAttr, now)) then table.insert(shown, e) end" in h),
        ("the lines redraw on the goose / war attributes and every Check s when the folded set changed",
         'UIKit.OnGameAttr({ "GooseActive", "GooseNextAt", "WarMode", "WarRoundEndsAt" }, notNowCheck)' in h
         and "task.wait(tonumber((Config.QuestNotNow or {}).Check) or 15)" in h and "if sig ~= L.NotNowLast then" in h),
        ("the Lv15 empty Z slot is already hidden while Z is off (SkillBar, SkillBook, server next-goal row)",
         "return skills()[T.Flag[slot]] == true or preview()" in src["SKILLBAR"]
         and "return s[T.Flag[slot]] == true or ctx.Preview == true" in src["SKILLBOOK"]
         and '(slot == "Q" or skills[slot .. "Enabled"] == true)' in src["QUEST"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    part = cut(src["HUD"], "function L.NotNow(e, gs, now)", "\nend\n")
    cfg = cut(src["CONFIG"], "Config.QuestNotNow = {", "}\n")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "quest_not_now.luau"
        p.write_text("local PART = " + lua_str(part) + "\nlocal CFG_LINE = " + lua_str(cfg) + "\n" + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"QUEST_NOT_NOW_SUMMARY checks=(\d+) failed=(\d+)", out)
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
    ok = failed == 0 and checks > 5 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
