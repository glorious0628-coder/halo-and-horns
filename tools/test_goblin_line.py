"""News window Goblin Notes line (게임성 개발 1, EG06, 검수 2026-10-10 "News 줄만"), offline.

Runs, in the official Luau CLI, the CURRENT H.GoblinLine cut out of SettingsUI.luau with the CURRENT Config.luau:
"Goblin Notes: <the week's line>", a new line each KST week (Config.GoblinNote(Config.DayIndex(now))), the three lines
cycling. Static: H.BuildNews adds it after the news blocks, small (L.NoteSize) and in its own colour. Mutations: each
must be caught.

Usage: py tools/test_goblin_line.py
Report: docs/art/verification_2026-10-10/offline_goblin_line_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SUI = ROOT / "src/StarterPlayer/StarterPlayerScripts/SettingsUI.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_goblin_line_2026-10-10.json"
START, END = "function H.GoblinLine(now)", "function H.BuildNews(parent, kit)"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local base = { Vector3 = ctor(), Vector2 = ctor(), Color3 = ctor(), BrickColor = ctor(), Rect = ctor(), UDim2 = ctor(),
	UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(), NumberSequenceKeypoint = ctor(),
	ColorSequenceKeypoint = ctor(), CFrame = ctor(), TweenInfo = ctor(), Font = ctor(),
	Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end }),
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()
local H = {}
local f = assert(loadstring(LINE_SOURCE, "=GoblinLine"))
setfenv(f, setmetatable({ Config = Config, H = H }, { __index = getfenv() }))
f()
local t0 = 1790000000
local a = H.GoblinLine(t0)
local lines = Config.GoblinNotes.Lines
check(type(a) == "string" and string.sub(a, 1, #"Goblin Notes: ") == "Goblin Notes: ", "the line starts with the title", a)
check(table.find(lines, string.sub(a or "", #"Goblin Notes: " + 1)) ~= nil, "... and is one of the notes", a)
check(H.GoblinLine(t0 + 3600) == a, "the same line within the hour", "")
local seen, prev, changes = {}, nil, 0
for d = 0, 27 do
	local l = H.GoblinLine(t0 + d * 86400)
	seen[l] = true
	if prev and l ~= prev then changes += 1 end
	prev = l
end
local n = 0
for _ in seen do n += 1 end
check(n == #lines, "four weeks show all the notes", n)
check(changes >= 3 and changes <= 4, "a new line about once a week (not every day)", changes)
print(("GOBLIN_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("no title", '(notes.Title .. ": ")', '""'),
    ("the same line every week", "return pick(day(now))", "return pick(0)"),
    ("a new line every day", "return pick(day(now))", "return Config.GoblinNotes.Lines[day(now) % 3 + 1]"),
]
STATIC = [
    ("BuildNews adds the line after the news", "local goblin = H.GoblinLine(os.time())"),
    ("small, in its own colour", 'kit.Text(parent, goblin, { Name = "GoblinNote", Size = L.NoteSize, Color = kit.Theme.Gold or kit.Theme.SubText })'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(block: str, config: str) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(config) + "\nlocal LINE_SOURCE = " + lua_str(block) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "goblin.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"GOBLIN_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = SUI.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    a, b = src.find(START), src.find(END)
    block = src[a:b]
    checks, failed, out = run(block, config)
    print(out.strip())
    statics = [{"check": n, "ok": t in src} for n, t in STATIC]
    for s in statics:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = block.count(old)
        caught = hits == 1 and run(block.replace(old, new), config)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name)
    ok = a >= 0 and failed == 0 and checks > 0 and all(s["ok"] for s in statics) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": statics, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
