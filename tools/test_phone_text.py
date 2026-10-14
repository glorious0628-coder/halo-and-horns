"""Phone text before the private test (A23-145, 최종 검수 10/13: "10/17 전에 할 것 2개"), offline.

Runs, in the official Luau CLI, the CURRENT pieces cut out of the sources with the CURRENT Config.luau:
1. Util.FormatTime: under an hour "M:SS" (0:00, 2:05, 59:59), an hour or more "H:MM:SS" (1:00:00, 1:57:23 - the goose
   chip said "117:23"), never negative.
2b. EventHUD SQ.GooseNeed (최종 검수 10/14, publish4: a PC showed "Goose 3:35" with room to spare): the chip's width in
   du = the whole line measured at the text floor in SCREEN px / UIScale, so SQ.chipLine at that width picks the whole line.
2. EventHUD SQ.chipLine (the goose chip): the longest line that fits the chip at its smallest text size - a PC chip
   (156 px, 11 px text) keeps "Golden Goose 1:57:23", a phone chip (117 px, 15 px text) "Goose 1:57:23", a narrower one
   the time alone; it measures every digit as a 0 (one measure per length); no UIKit / no width = the whole line.
3. SettingsUI H.TopicLines (Help): Controls from H.ControlLines; a touch-only device (KeyboardEnabled false) reads
   Config.Help.TouchTopics lines where a topic has them (Safety: no Esc, no Tab), a keyboard the topic's own lines.
Static: Config.Help.TouchTopics.Safety keeps block / report, PvP zones and "Ask a parent before using Robux", at most 4
lines, English only, no "Esc" / "Tab"; TouchLines at most 4 lines; BuildHelp draws every topic through H.TopicLines;
both goose chip lines go through SQ.chipLine. (Skills: SkillBook already drops [F] / [Z] and [Change keys] without a
keyboard - tools/test_skill_book.py "touch: no key in the name".) Studio's phone emulator keeps KeyboardEnabled true, so
its photos still show the keyboard lines; a real phone has none. Mutations: each must be caught.

Usage: py tools/test_phone_text.py
Report: docs/art/verification_2026-10-13/offline_phone_text_2026-10-13.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = "src/StarterPlayer/StarterPlayerScripts/"
FILES = {"UTIL": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
         "EVENT": ROOT / (SPS + "EventHUD.luau"),
         "GOOSE": ROOT / (SPS + "EventHUD.luau"),
         "SETTINGS": ROOT / (SPS + "SettingsUI.luau"),
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_phone_text_2026-10-13.json"
CUTS = {"UTIL": ("function Util.FormatTime(seconds)", "\nend\n"),
        "EVENT": ("function SQ.chipLine(seconds)", "\nend\n"),
        "GOOSE": ("function SQ.GooseNeed(h)", "\nend\n"),
        "SETTINGS": ("function H.TopicLines(t)", "\nend\n")}

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

-- 1. Util.FormatTime
local Util = {}
local fu = assert(loadstring(UTIL_SOURCE, "=FormatTime"))
setfenv(fu, setmetatable({ Util = Util }, { __index = getfenv() }))
fu()
local ft = Util.FormatTime
check(ft(0) == "0:00" and ft(125) == "2:05" and ft(3599) == "59:59", "under an hour: M:SS", ft(3599))
check(ft(3600) == "1:00:00" and ft(7043) == "1:57:23" and ft(36000 + 61) == "10:01:01", "an hour or more: H:MM:SS (not 117:23)",
	ft(7043))
check(ft(-5) == "0:00" and ft(nil) == "0:00" and ft(125.9) == "2:05", "never negative, whole seconds", ft(-5))

-- 2. the goose chip line
local measured = {}
local kit = { MeasureText = function(text, size)
	table.insert(measured, text)
	return size, #text * size * 0.55, false
end }
local function chip(width, minSize)
	return { AbsoluteSize = { X = width }, TextSize = 16, FontFace = "Font",
		FindFirstChildOfClass = function(_, cls)
			if cls == "UITextSizeConstraint" and minSize then return { MinTextSize = minSize } end
			return nil
		end }
end
local TXT = { GooseNext = "Golden Goose %s", GooseNextShort = "Goose %s" }
local ev = { ui = {}, C = { UIKit = kit }, SQ = {}, Util = Util }
do
	local src = EVENT_SOURCE:gsub("^function SQ%.chipLine", "function SQ.chipLine")
	local fe = assert(loadstring(TXT_SOURCE .. "\n" .. src, "=chipLine"))
	setfenv(fe, setmetatable(ev, { __index = getfenv() }))
	fe()
end
local line = ev.SQ.chipLine
ev.ui.GooseChipText = chip(156, 11)
check(line(7043) == "Golden Goose 1:57:23", "a PC chip (156 px, 11 px text): the whole line", line(7043))
ev.ui.GooseChipText = chip(117, 15)
check(line(7043) == "Goose 1:57:23", "a phone chip (117 px, 15 px text): Goose + the time", line(7043))
check(line(3443) == "Goose 57:23", "... under an hour too", line(3443))
ev.ui.GooseChipText = chip(70, 15)
check(line(7043) == "1:57:23", "a narrower chip: the time alone", line(7043))
ev.ui.GooseChipText = chip(30, 15)
check(line(7043) == "1:57:23", "nothing fits: still the time (never the word alone)", line(7043))
measured = {}
ev.ui.GooseChipText = chip(117, 15)
line(7043)
local zeros = true
for _, m in measured do zeros = zeros and not string.find(m, "[1-9]") end
check(#measured > 0 and zeros, "measures every digit as a 0 (one measure per length)", measured[1])
ev.ui.GooseChipText = chip(0, 15)
check(line(7043) == "Golden Goose 1:57:23", "no width yet: the whole line", line(7043))
ev.ui.GooseChipText = chip(117, nil)
check(line(7043) == "Goose 1:57:23", "no size constraint: the label's TextSize", line(7043))
ev.C = { UIKit = nil }
check(line(7043) == "Golden Goose 1:57:23", "no UIKit: the whole line", line(7043))
ev.C = { UIKit = kit }
ev.ui.GooseChipText = nil
check(line(7043) == "Golden Goose 1:57:23", "no chip label: the whole line", line(7043))

-- 2b. the goose chip's width (SQ.GooseNeed): the whole line at the text floor (screen px) back in du
do
	local SCALE = 0.8
	local env = { ui = { GooseChipText = chip(0, 18) }, C = { UIKit = kit }, SQ = {}, GOOSE_CHIP_W = 100,
		L = { GooseChip = { Left = 10, Right = 12, Gap = 6, IconK = 0.75 }, PillH = 26 },
		currentScale = function() return SCALE end }
	local fg = assert(loadstring(GOOSE_SOURCE, "=GooseNeed"))
	setfenv(fg, setmetatable(env, { __index = getfenv() }))
	fg()
	env.SQ.FullLine = "Golden Goose 3:35"
	local need = env.SQ.GooseNeed(30)
	local labelPx = (need - 22) * SCALE -- the words' box (chip minus Left + Right) on screen
	local fullPx = #"Golden Goose 0:00" * 18 * 0.55
	check(labelPx >= fullPx, "PC (UIScale 0.8): the chip holds the whole line at its 18 px floor", labelPx .. " < " .. fullPx)
	ev.ui.GooseChipText = chip(labelPx, 18)
	check(line(215) == "Golden Goose 3:35", "... so the PC chip shows 'Golden Goose 3:35', not 'Goose 3:35'", line(215))
	SCALE = 1
	local need1 = env.SQ.GooseNeed(30)
	check(math.abs((need1 - 22) - fullPx) <= 3, "UIScale 1: the same width in du and px", need1)
	env.SQ.FullLine = "Hi"
	check(env.SQ.GooseNeed(30) == 100, "a short line: never narrower than GOOSE_CHIP_W", env.SQ.GooseNeed(30))
end

-- 3. Help topic lines
local UIS = { KeyboardEnabled = true }
local H = { ControlLines = function() return { "KEYS" } end }
local fs = assert(loadstring(SETTINGS_SOURCE, "=TopicLines"))
setfenv(fs, setmetatable({ H = H, Config = Config, UserInputService = UIS }, { __index = getfenv() }))
fs()
local topics = {}
for _, t in Config.Help.Topics do topics[t.Id] = t end
check(H.TopicLines(topics.Controls)[1] == "KEYS", "Controls: from my live keys", "")
check(H.TopicLines(topics.Safety) == topics.Safety.Lines, "a keyboard: the Safety topic's own lines (Esc, Tab)", "")
UIS.KeyboardEnabled = false
local tl = H.TopicLines(topics.Safety)
check(tl == Config.Help.TouchTopics.Safety, "touch only: the touch Safety lines", tl and tl[1])
local noKeys = true
for _, l in tl do noKeys = noKeys and not string.find(l, "Esc") and not string.find(l, "Tab") end
check(noKeys, "touch Safety: no Esc, no Tab", tl[1])
check(H.TopicLines(topics.Combat) == topics.Combat.Lines, "touch only, a topic without touch lines: its own lines", "")
check(H.TopicLines(topics.Controls)[1] == "KEYS", "touch only: Controls still from H.ControlLines (its TouchLines)", "")
print(("PHONE_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("UTIL", "over an hour stays M:SS", "\tif seconds >= 3600 then\n", "\tif seconds >= math.huge then\n"),
    ("UTIL", "minutes not wrapped", "seconds // 60 % 60, seconds % 60)", "seconds // 60, seconds % 60)"),
    ("EVENT", "no short line", "L.Tx(TXT, \"GooseNextShort\", t), t }", "t }"),
    ("EVENT", "the PC width ignored", "lw <= w + 1 then return line end", "lw <= w * 0.5 then return line end"),
    ("EVENT", "real digits measured", '(string.gsub(line, "%d", "0"))', "line"),
    ("EVENT", "the word alone when nothing fits", "\treturn t\nend", "\treturn lines[1]\nend"),
    ("GOOSE", "the goose chip measured in du again (PC 'Goose 3:35')", "math.ceil(room + w / s + 2)", "math.ceil(room + w + 2)"),
    ("SETTINGS", "touch reads the keyboard lines", "if not UserInputService.KeyboardEnabled and type(touch)",
     "if false and type(touch)"),
    ("SETTINGS", "keyboards read the touch lines", "if not UserInputService.KeyboardEnabled and type(touch)",
     "if type(touch)"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(key: str, text: str) -> str:
    start, end = CUTS[key]
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def txt_line(event: str) -> str:
    # the chip's TXT entries, as a local table the cut function reads
    m1 = re.search(r'\tGooseNext = ("[^"]*"),', event)
    m2 = re.search(r'\tGooseNextShort = ("[^"]*"),', event)
    return "local TXT = { GooseNext = %s, GooseNextShort = %s }" % (m1[1] if m1 else '""', m2[1] if m2 else '""')


def tx_cut(event: str) -> str:
    """EventHUD's L.Tx (10/14: the words by key; no UIKit here = string.format)"""
    a = event.find("function L.Tx(t, key, ...)")
    b = event.find("\nend\n", a)
    return event[a:b + 5] if a >= 0 and b >= 0 else ""


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal UTIL_SOURCE = " + lua_str(cut("UTIL", src["UTIL"]))
            + "\nlocal EVENT_SOURCE = " + lua_str(cut("EVENT", src["EVENT"])) + "\nlocal GOOSE_SOURCE = "
            + lua_str(cut("GOOSE", src["GOOSE"])) + "\nlocal TXT_SOURCE = "
            + lua_str(txt_line(src["CONFIG"]) + "\nlocal L = {}\n" + tx_cut(src["EVENT"])) + "\nlocal SETTINGS_SOURCE = " + lua_str(cut("SETTINGS", src["SETTINGS"]))
            + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "phone_text.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"PHONE_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def touch_safety(config: str):
    m = re.search(r"\tTouchTopics = \{\n\t\tSafety = \{\n(.*?)\n\t\t\},\n\t\},", config, re.S)
    return re.findall(r'"([^"]*)"', m.group(1)) if m else None


def touch_lines(config: str):
    m = re.search(r"\tTouchLines = \{\n(.*?)\n\t\},", config, re.S)
    return re.findall(r'"([^"]*)"', m.group(1)) if m else None


def statics(src: dict) -> list[tuple[str, bool]]:
    c, s, e = src["CONFIG"], src["SETTINGS"], src["EVENT"]
    ts, tl = touch_safety(c), touch_lines(c)
    return [
        ("touch Safety: block / report, PvP zones, ask a parent, at most 4 lines, English, no Esc / Tab", bool(ts)
         and len(ts) <= 4 and any("Block or report" in x for x in ts) and any("PvP" in x for x in ts)
         and any("Ask a parent before using Robux" in x for x in ts)
         and all(not re.search(r"[가-힣]|\bEsc\b|\bTab\b", x) for x in ts)),
        ("touch Controls: at most 4 lines, no keys", bool(tl) and len(tl) <= 4
         and all(not re.search(r"[가-힣]|\bEsc\b|\bTab\b|mouse", x) for x in tl)),
        ("BuildHelp draws every topic through H.TopicLines", "\t\tH.Topic(kit, parent, t.Title, H.TopicLines(t))\n" in s),
        ("both goose chip lines go through SQ.chipLine",
         e.count("setText(ui.GooseChipText, SQ.chipLine(") == 2 and "string.format(TXT.GooseNext," not in e.replace(
             "string.format(TXT.GooseNext, t)", "")),
    ]


STATIC_MUTATIONS = [
    ("CONFIG", "touch Safety names Esc", '"Block or report someone: tap the Roblox button (top left), then find their name."',
     '"Block or report someone: open the Roblox menu (Esc), then Players."'),
    ("SETTINGS", "BuildHelp skips the touch lines", "H.Topic(kit, parent, t.Title, H.TopicLines(t))",
     'H.Topic(kit, parent, t.Title, t.Id == "Controls" and H.ControlLines() or t.Lines)'),
    ("EVENT", "the phone chip keeps the long line", "setText(ui.GooseChipText, SQ.chipLine(nextAt - now))",
     "setText(ui.GooseChipText, string.format(TXT.GooseNext, Util.FormatTime(nextAt - now)))"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(k, src[k]) for k in CUTS)
    checks, failed, out = run(src)
    print(out.strip())
    st = [{"check": n, "ok": ok} for n, ok in statics(src)]
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    for key, name, old, new in STATIC_MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and not all(ok for _, ok in statics(m))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks > 0 and all(s["ok"] for s in st) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
