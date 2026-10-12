"""Goose Square Join / Leave button as wide as its word (최종 검수 10/13: main photo goose_square4/03, PC 1920 - "Leav"),
offline.

Runs the CURRENT EventHUD.luau SQ.need in Luau with a label double (its UITextSizeConstraint floor in real px, its drawn
line TextBounds.Y) and a MeasureText double (0.62 em a letter, the Montserrat-ish average; a second one that throws =
the estimate path). Checks, on PC (floor 18 real px) and phone (19) at UIScale 0.75 / 0.91 (the photo's 656-high view)
/ 1 / 1.25, drawn or not drawn yet: "Leave" and "Join" fit inside the label (its 8 logical px inset: (W - 8) x scale >=
the word measured at the real px it is drawn), the button never narrower than 64 nor wider than 160, "Join" stays at 64
on a big screen. Static: SQ.update sizes the button from SQ.need (cached per word / scale / drawn line), the build uses
SQ.MinW / SQ.H. Mutations: each must be caught.

Usage: py tools/test_square_button_width.py
Report: docs/art/verification_2026-10-13/offline_square_button_width_2026-10-13.json
"""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/EventHUD.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_square_button_width_2026-10-13.json"

TESTS = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK   " .. name) else failed += 1; print("CHECK_FAIL " .. name .. (detail ~= nil and (" :: " .. tostring(detail)) or "")) end
end
local EM = 0.62
local function measure(text, size) return 0, #text * size * EM, true end
local kit = { MeasureText = function(text, size) local h, w = measure(text, size); return h, w end }
local broken = { MeasureText = function() error("offline: no TextService") end }
local function label(floor, drawnReal)
	local tc = { MinTextSize = floor }
	return { TextBounds = { Y = drawnReal }, FontFace = "Montserrat",
		FindFirstChildOfClass = function(_, cls) return cls == "UITextSizeConstraint" and tc or nil end }
end
for _, dev in { { "PC", 18 }, { "phone", 19 } } do
	for _, s in { 0.75, 0.91, 1, 1.25 } do
		for _, drawn in { 0, dev[2] + 2 } do
			for _, k in { { "kit", kit }, { "no TextService", broken } } do
				for _, word in { "Leave", "Join" } do
					local lab = label(dev[2], drawn)
					local w = SQ.need(word, lab, k[2], s)
					local px = math.max(dev[2], drawn, 15 * s) -- the real px the word is drawn at
					local _, need = measure(word, px)
					local tag = string.format("%s s=%.2f drawn=%d %s %s", dev[1], s, drawn, k[1], word)
					check((w - 8) * s >= need - 1e-6, tag .. ": the word fits inside the label", string.format("W=%d need=%.1f px", w, need))
					check(w >= SQ.MinW and w <= SQ.MaxW, tag .. ": within 64..160", w)
				end
			end
		end
	end
end
check(SQ.need("Join", label(15, 0), kit, 1.25) == SQ.MinW, "a short word on a big screen keeps the 64 button")
check(SQ.need(string.rep("W", 40), label(18, 0), kit, 1) == SQ.MaxW, "a very long word stops at 160")
check(SQ.need("Leave", nil, nil, 0.91) >= SQ.MinW, "no label yet: still a button width")
-- the photo: PC 1920 x 656 (UIScale 0.91), floor 18 real px - "Leave" no longer cut at 64
check(SQ.need("Leave", label(18, 20), kit, 656 / 720) > 64, "the photo's case: wider than the old 64")
print("SQBTN_CHECKS " .. checks .. " FAILED " .. failed)
'''


def extract(hud: str) -> str:
    a = hud.index("local SQ = {")
    sq = hud[a:hud.index("\n", a)]
    b = hud.index("function SQ.need(")
    e = hud.index("\n-- every tick: the button from EggFx.SquareButton", b)
    return sq + "\n" + hud[b:e]


def statics(hud: str) -> list[tuple[str, bool]]:
    return [
        ("the button builds at SQ.MinW x SQ.H with SQ.Size words", "Size = UDim2.fromOffset(SQ.MinW, SQ.H)," in hud
         and "TextSize = SQ.Size," in hud),
        ("SQ.update sizes the button from SQ.need (cached per word / scale / drawn line)",
         'local key = word .. "|" .. s .. "|" .. SQ.Label.TextBounds.Y' in hud
         and "SQ.Fit = { Key = key, W = SQ.need(word, SQ.Label, C and C.UIKit, s) }" in hud
         and "if btn.Size.X.Offset ~= SQ.Fit.W then btn.Size = UDim2.fromOffset(SQ.Fit.W, SQ.H) end" in hud),
        ("the word still comes from Config.Goose.Square.Text (SQ.word)", "local word = SQ.word(want.Word)\n\tsetText(SQ.Label, word)" in hud),
    ]


def run(hud: str) -> list[tuple[str, bool]]:
    res = statics(hud)
    try:
        code = extract(hud) + "\n" + TESTS
    except ValueError:
        return res + [("SQ.need found in EventHUD", False)]
    path = ROOT / "build/square_button_width_test.luau"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(code, encoding="utf-8")
    done = subprocess.run([str(LUAU), str(path)], capture_output=True, text=True, encoding="utf-8")
    for line in done.stdout.splitlines():
        if line.startswith("CHECK_OK   "):
            res.append((line[11:], True))
        elif line.startswith("CHECK_FAIL "):
            res.append((line[11:], False))
    if done.returncode != 0 or "SQBTN_CHECKS" not in done.stdout:
        res.append(("the Luau run finished: " + (done.stderr or "")[-300:], False))
    return res


MUTATIONS = [
    ("no room for the label inset / round ends", "Pad = 20,", "Pad = 0,"),
    ("the screen-px floor ignored (the logical 15 only)", "if tc then size = math.max(size, tc.MinTextSize / s) end", "if tc then size = size end"),
    ("the floor read as logical px", "size = math.max(size, tc.MinTextSize / s)", "size = math.max(size, tc.MinTextSize * s)"),
    ("the old fixed 64 button", "return math.clamp(math.ceil(w + SQ.Pad), SQ.MinW, SQ.MaxW)", "return SQ.MinW"),
    ("no cap on a long word", "return math.clamp(math.ceil(w + SQ.Pad), SQ.MinW, SQ.MaxW)", "return math.max(math.ceil(w + SQ.Pad), SQ.MinW)"),
    ("the estimate too narrow without TextService", "w = w or (utf8.len(text) or #text) * size * 0.62", "w = w or (utf8.len(text) or #text) * size * 0.4"),
    ("the button never resized", "\tif btn.Size.X.Offset ~= SQ.Fit.W then btn.Size = UDim2.fromOffset(SQ.Fit.W, SQ.H) end\n", ""),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    res = run(hud)
    for name, ok in res:
        print(("CHECK_OK   " if ok else "CHECK_FAIL ") + name)
    failed = [n for n, ok in res if not ok]
    muts = []
    for name, old, new in MUTATIONS:
        hits = hud.count(old)
        caught = hits >= 1 and not all(ok for _, ok in run(hud.replace(old, new, 1)))
        muts.append({"name": name, "applied": hits >= 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits >= 1 else " (not applied)"))
    ok = not failed and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": len(res), "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Named checks: {len(res) - len(failed)} passed, {len(failed)} failing")
    print(f"MUTATIONS caught={sum(m['caught'] for m in muts)}/{len(muts)}")
    print(f"Status: {status}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
