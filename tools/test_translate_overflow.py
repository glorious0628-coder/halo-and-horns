"""Translated text must not spill (최종 검수 10/14 after A23-179: Roblox's automatic translation is on), offline.

Roblox translates only what is DRAWN; label.Text stays English. So a fit measured on label.Text (TextService) is blind to a
longer translation. Rules now:
1. HUD quest goal (L.FitGoal sizes the box for the English sentence): L.GoalGuard watches the engine's TextFits (computed
   on the drawn, translated text) and steps the size down by 1 (pure L.GuardStep) to max(GoalMin, the style floor).
2. FactionPicker perk lines: the card's one size for our English, but a translation may shrink down to MIN_TEXT
   (TextScaled draws the translated words) instead of being cut by the row clip.
3. DeathScreen: every line and the box grow with a wrapped translation (AutomaticSize Y).
UIKit.FitText already fits on the drawn TextBounds (max with the English measure); ClassPicker and the kit buttons are
TextScaled (they shrink on the drawn text; the buttons' floor is 12 px - a very long word can still be cut there).
Extracted and run: L.GuardStep, with a translation model 1.4x the English length (a line holds width / (size x 0.5)
characters): the goal ends inside GoalLines lines or at the floor, never grows, never passes the floor. Static: the call
sites. Mutations: each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_translate_overflow_2026-10-14.json (do not commit)
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
FILES = {"HUD": SPS / "HUD.luau", "FP": SPS / "FactionPicker.luau", "DS": SPS / "DeathScreen.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_translate_overflow_2026-10-14.json"
CUT = ("function L.GuardStep(fits, size, least)", "\nend\n")

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
L = {}
local f = assert(loadstring(PART, "=Part"))
setfenv(f, setmetatable({ L = L }, { __index = getfenv() }))
f()
check(L.GuardStep(false, 16, 12) == 15 and L.GuardStep(true, 16, 12) == 16 and L.GuardStep(false, 12, 12) == 12
	and L.GuardStep(nil, 16, 12) == 16, "one step down only while it does not fit, never below the floor", "")
-- the translation model: a line holds width / (size x 0.5) characters
local function lines(chars, size, width) return math.ceil(chars * size * 0.5 / width) end
local cases = {
	{ "Defeat 5 slimes in the meadow", 18, 12, 260, 2 },
	{ "Bring the jelly to the blacksmith in the Crossroads", 18, 12, 260, 2 },
	{ "Talk to the guide at the fountain and pick your side", 16, 12, 200, 2 },
}
for _, c in cases do
	local en, size, least, width, maxLines = c[1], c[2], c[3], c[4], c[5]
	local chars = math.ceil(#en * 1.4)
	local guard = 0
	while guard < 100 do
		guard += 1
		local fits = lines(chars, size, width) <= maxLines
		local nextSize = L.GuardStep(fits, size, least)
		if nextSize == size then break end
		check(nextSize < size, "it never grows", nextSize)
		size = nextSize
	end
	local fits = lines(chars, size, width) <= maxLines
	check(fits or size == least, "a 1.4x translation of '" .. en .. "' fits in " .. maxLines .. " lines or stops at the floor",
		("size %d, %d lines"):format(size, lines(chars, size, width)))
	check(size >= least, "never below the floor", size)
end
print(("TRANSLATE_OVERFLOW_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("HUD", "the guard grows the size", "then return size - 1 end", "then return size + 1 end"),
    ("HUD", "the guard ignores the floor", "and size > least then return size - 1 end", "then return size - 1 end"),
    ("HUD", "the guard never runs", '\tfor _, prop in { "TextFits", "TextBounds" } do -- A23-179: a longer translation shrinks it (L.GoalGuard)\n',
     '\tfor _, prop in {} do -- A23-179: a longer translation shrinks it (L.GoalGuard)\n'),
    ("HUD", "the guard below the style floor", "math.max(T.GoalMin, floorDu)", "T.GoalMin"),
    ("FP", "the perk line cut by its row again", "setTextRange(row.Text, MIN_TEXT, size)", "setTextRange(row.Text, size, size)"),
    ("DS", "the KO lines keep one line", "\tl.AutomaticSize = Enum.AutomaticSize.Y -- A23-179: a longer translation wraps to a second line inside the box\n", ""),
    ("DS", "the KO box keeps its height", "\tbox.AutomaticSize = Enum.AutomaticSize.Y -- A23-179: a translated line that wraps grows the box (never spills)\n", ""),
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
    h, fp, ds = src["HUD"], src["FP"], src["DS"]
    return [
        ("HUD: the goal watches TextFits / TextBounds and steps down to max(GoalMin, floor)",
         'for _, prop in { "TextFits", "TextBounds" } do' in h and "task.defer(L.GoalGuard)" in h
         and "L.GuardStep(goal.TextFits, goal.TextSize, math.max(T.GoalMin, floorDu))" in h),
        ("FactionPicker: perk lines may shrink to MIN_TEXT", "setTextRange(row.Text, MIN_TEXT, size)" in fp),
        ("DeathScreen: lines and box grow (AutomaticSize Y)", "l.AutomaticSize = Enum.AutomaticSize.Y" in ds
         and "box.AutomaticSize = Enum.AutomaticSize.Y" in ds),
    ]


def run(src: dict) -> tuple[int, int, str]:
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "overflow.luau"
        p.write_text("local PART = " + lua_str(cut(src["HUD"], *CUT)) + "\n" + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"TRANSLATE_OVERFLOW_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = cut(src["HUD"], *CUT) != ""
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
    ok = found and failed == 0 and checks > 3 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
