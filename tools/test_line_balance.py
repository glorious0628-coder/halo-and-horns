"""Line balance (검수 2026-10-10, user: the Vacation card "균형이 안 맞아" - one word alone on the last line), offline.

Runs the CURRENT UIKit.BalanceWidth (cut out of src/StarterPlayer/StarterPlayerScripts/UIKit.luau) in the official Luau
CLI with a greedy word wrap (a fixed width per letter): the Vacation line and other centred lines that leave one word
alone at the box width wrap into the same number of lines at the balanced width, and their lines come out even (the
shortest line at least ~60% of the longest); one-line text keeps the full width; the result never exceeds the box and is the narrowest such width.
Static: the reward popup lines get UIKit.WrapHeight + UIKit.BalanceLines, toasts / the announce banner / UIKit.Confirm
balance too, Panels' centred addText labels and the pause card's body call it, BalanceLines leaves left / right text
and labels with their own UIPadding alone and pads left = right, the Vacation lines are shorter ("You were away %d days.
That's okay!"). Mutations: each must be caught.

Usage: py tools/test_line_balance.py
Report: docs/art/verification_2026-10-10/offline_line_balance_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
S = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"UIKIT": S / "UIKit.luau", "PANELS": S / "Panels.luau", "PAUSE": S / "PauseCard.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_line_balance_2026-10-10.json"

HARNESS = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local UIKit = {}
local BAL = { Steps = 8 }
__FN__
-- greedy wrap with CW px per letter (spaces too), like the engine: words never split
local CW = 9
local function wrap(text, w)
	local lines, cur = {}, ""
	for word in string.gmatch(text, "%S+") do
		local try = cur == "" and word or (cur .. " " .. word)
		if #try * CW <= w or cur == "" then cur = try else table.insert(lines, cur) cur = word end
	end
	if cur ~= "" then table.insert(lines, cur) end
	return lines
end
local cases = {
	{ "You were away for 1 day, and that's okay.", 340 },
	{ "Welcome back! Next: beat the Slime Prince in the Squishy Meadow", 420 },
	{ "Rare drops come a bit more often today!", 330 },
	{ "Crown War: win points for your side and help your town win", 470 },
}
for _, c in cases do
	local text, full = c[1], c[2]
	local before = wrap(text, full)
	local w, n = UIKit.BalanceWidth(function(x) return #wrap(text, x) end, full, #text * CW)
	local after = wrap(text, w)
	local lo, hi = math.huge, 0
	for _, l in after do lo, hi = math.min(lo, #l), math.max(hi, #l) end
	local blo = math.huge
	for _, l in before do blo = math.min(blo, #l) end
	check(n == #before and #after == n, "same lines after balancing: " .. text, n .. " vs " .. #after)
	check(lo >= hi * 0.6, "even lines (shortest >= 60% of longest): " .. text,
		table.concat(after, " | ") .. "  (before: " .. table.concat(before, " | ") .. ")")
	check(w <= full, "never wider than the box: " .. text, w .. " > " .. full)
	-- tight: one letter narrower would need another line (unless only the full box gives n lines)
	check(w >= full or #wrap(text, w - CW) > n, "the narrowest such width: " .. text, w)
end
local w1, n1 = UIKit.BalanceWidth(function(x) return #wrap("Okay!", x) end, 300, 5 * CW)
check(w1 == 300 and n1 == 1, "one line keeps the full width", w1 .. " " .. n1)
print(string.format("LINE_BALANCE_SUMMARY checks=%d failed=%d", checks, failed))
'''


def cut_fn(src: str) -> str:
    m = re.search(r"function UIKit\.BalanceWidth\(.*?\n end\n".replace(" end", "end"), src, re.S)
    if not m:
        return "error('UIKit.BalanceWidth not found')"
    return m.group(0)


def static_checks(src: dict) -> list[tuple[str, bool]]:
    u, p, pc = src["UIKIT"], src["PANELS"], src["PAUSE"]
    pop = u[u.find("function UIKit.RewardPopup"):]
    pop = pop[:pop.find("local counters")]
    bl = u[u.find("function UIKit.BalanceLines"):]
    bl = bl[:bl.find("\nend\n")]
    add = p[p.find("local function addText"):]
    add = add[:add.find("\nend\n")]
    return [
        ("the reward popup lines balance (AutomaticSize kept: it sized them right at 991x451)",
         "UIKit.BalanceLines(label)" in pop and "AutomaticSize = Enum.AutomaticSize.Y" in pop),
        ("toasts and the art toast balance", u.count("UIKit.BalanceLines(label) -- 검수 10/10: no word alone") == 2),
        ("the announce banner balances", "UIKit.BalanceLines(announceLabel)" in u),
        ("UIKit.Confirm's body balances", "UIKit.BalanceLines(bodyLabel)" in u),
        ("BalanceLines leaves left / right aligned text alone", "label.TextXAlignment ~= Enum.TextXAlignment.Center" in bl),
        ("BalanceLines leaves a label with its own UIPadding alone", "if own and own ~= pad then return end" in bl),
        ("BalanceLines pads left = right", "pad.PaddingLeft, pad.PaddingRight = UDim.new(0, du), UDim.new(0, du)" in bl),
        ("Panels' centred addText labels balance", "UIKit.BalanceLines(l)" in add and "Enum.TextXAlignment.Center" in add),
        ("the pause card's body balances", "kit.BalanceLines(body)" in pc),
        ("BalanceLines keeps a margin over the narrowest width", "w = math.min(full, math.ceil(w * BAL.Margin))" in bl),
        ("a balance whose text no longer fits drops its padding", "and not label.TextFits then" in bl),
        ("the copy drops the label's padding / size limits (it measures the full width)",
         'if ch:IsA("UIPadding") or ch:IsA("UISizeConstraint")' in bl),
        ("BalanceLines counts lines with the engine (an off-screen copy), not TextService",
         "local probe = label:Clone()" in bl and "GetTextBoundsAsync" not in bl),
        ("the Vacation popup line is shorter", "VacationAwayF = \"You were away %d days. That's okay!\"" in p),
        ("the Vacation window header is shorter", "VacationHeaderF = \"Vacation Bonus! You were away %d days. That's okay!\"" in p),
    ]


MUTATIONS = [
    ("UIKIT", "no search: the full width back", "\tif n <= 1 then return full, n end\n", "\tdo return full, n end\n"),
    ("UIKIT", "the search keeps the wider half", "if linesAt(mid) <= n then hi = mid else lo = mid end",
     "if linesAt(mid) <= n then lo = mid else hi = mid end"),
    ("UIKIT", "a balanced width may exceed the box", "return math.min(full, math.ceil(hi)), n", "return math.ceil(hi) + 40, n"),
    ("UIKIT", "the reward popup lines not balanced", "\t\tUIKit.BalanceLines(label) -- 검수 10/10 (the Vacation card",
     "\t\tlocal _ = label -- (the Vacation card"),
    ("UIKIT", "left text balanced too", "if label.TextXAlignment ~= Enum.TextXAlignment.Center or", "if false or"),
    ("UIKIT", "padding on the left only", "pad.PaddingLeft, pad.PaddingRight = UDim.new(0, du), UDim.new(0, du)",
     "pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 2 * du), UDim.new(0, 0)"),
    ("UIKIT", "no margin: the exact narrowest width", "\t\tw = math.min(full, math.ceil(w * BAL.Margin))\n", ""),
    ("UIKIT", "a clipped balance stays", "\t\tif token == state.Token and label.Parent and not label.TextFits then\n",
     "\t\tif false then\n"),
    ("UIKIT", "the probe keeps its padding", "\t\t\tif ch:IsA(\"UIPadding\") or ch:IsA(\"UISizeConstraint\")",
     "\t\t\tif ch:IsA(\"UISizeConstraint\")"),
    ("PANELS", "addText does not balance", "\t\tUIKit.BalanceLines(l)\n", "\t\tlocal _ = l\n"),
    ("PANELS", "the old long Vacation line", "VacationAwayF = \"You were away %d days. That's okay!\"",
     "VacationAwayF = \"You were away for %d days, and that's okay.\""),
]


def run(src: dict) -> tuple[int, int, str]:
    text = HARNESS.replace("__FN__", cut_fn(src["UIKIT"]))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "line_balance.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"LINE_BALANCE_SUMMARY checks=(\d+) failed=(\d+)", out)
    checks, failed = (int(m[1]) if m else 0), (int(m[2]) if m else 1)
    for name, ok in static_checks(src):
        checks += 1
        if not ok:
            failed += 1
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    return checks, failed, out


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
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
