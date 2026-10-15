"""Window title ribbon centred (최종 검수 10/15, user photo: '안내자 · 보급로 되찾기' stuck to the icon, the right half empty -
"가운데 정렬, 그래야지 퀄리티가 높아 보여"), offline.

Runs the CURRENT Panels FRAME.TitleWidth in the official Luau CLI (the label's width = its drawn words + air, between the
least and the most room; words that do not fit take the most) and checks the wiring: the label is no AutomaticSize
(that ignored the least width and left short titles on the left), it refits on its drawn words / size and on every
layout. Each mutation must make a check fail.

Usage: py tools/test_title_center.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PANELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local FRAME = {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local W = FRAME.TitleWidth
check("a short title takes the least width (its words centred in it)", W(80, 1, true, 140, 400) == 140, W(80, 1, true, 140, 400))
check("a long title: its words + air", W(250, 1, true, 140, 400) == 256, W(250, 1, true, 140, 400))
check("screen px back to du by the scale", W(250, 0.5, true, 140, 600) == 506, W(250, 0.5, true, 140, 600))
check("never past the most room", W(900, 1, true, 140, 400) == 400)
check("words that do not fit take the most room", W(100, 1, false, 140, 400) == 400)
check("a broken scale counts as 1", W(200, 0, true, 140, 400) == 206)
print(fails == 0 and "TITLE_CENTER_OK" or "TITLE_CENTER_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def run(src: str) -> tuple[bool, str]:
    fn = block(src, "FRAME.TitleWidth")
    if not fn:
        return False, "TitleWidth missing"
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "tc.luau"
        f.write_text(PURE.replace("__FUNC__", fn), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    statics = [
        ("the label is not AutomaticSize", "\ttitleLabel.AutomaticSize = Enum.AutomaticSize.None\n" in src),
        ("it refits on its drawn words and size",
         'titleLabel:GetPropertyChangedSignal("TextBounds"):Connect(function() FRAME.FitTitle() end)' in src
         and 'titleLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() FRAME.FitTitle() end)' in src),
        ("every layout refits it", "\t\t\tFRAME.TitleCap.MaxSize = Vector2.new(capW, th)\n\t\t\tFRAME.FitTitle()\n" in src),
        ("the words stay centred in the label", "\t\tTextXAlignment = Enum.TextXAlignment.Center,\n" in block(src, "FRAME.BuildTitle")),
        ("the right end as wide as the icon disc", 'UIKit.Create("Frame", { Name = "End", Size = UDim2.new(0, disc0, 1, 0)' in src),
    ]
    for name, ok in statics:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    return "TITLE_CENTER_OK" in out and all(ok for _, ok in statics), out


MUTATIONS = [
    ("AutomaticSize again", "\ttitleLabel.AutomaticSize = Enum.AutomaticSize.None\n", ""),
    ("no refit on the words", 'titleLabel:GetPropertyChangedSignal("TextBounds"):Connect(function() FRAME.FitTitle() end)', ""),
    ("no refit on layout", "\t\t\tFRAME.TitleCap.MaxSize = Vector2.new(capW, th)\n\t\t\tFRAME.FitTitle()\n",
     "\t\t\tFRAME.TitleCap.MaxSize = Vector2.new(capW, th)\n"),
    ("the least width ignored", "return math.clamp(want, lo, math.max(lo, hi))", "return math.min(want, hi)"),
    ("a cut title stays short", "local want = fits == false and hi or", "local want ="),
    ("the scale ignored", "(math.ceil((tonumber(boundsX) or 0) / scale) + 6)", "(math.ceil(tonumber(boundsX) or 0) + 6)"),
    ("the left words again", "\t\tTextXAlignment = Enum.TextXAlignment.Center,\n\t\tLayoutOrder = 2,",
     "\t\tTextXAlignment = Enum.TextXAlignment.Left,\n\t\tLayoutOrder = 2,"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = PANELS.read_text(encoding="utf-8")
    good, out = run(src)
    print(out.strip())
    caught = 0
    for name, old, new in MUTATIONS:
        if src.count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src.count(old)})")
            continue
        bad, _ = run(src.replace(old, new))
        caught += 0 if bad else 1
        print(("MUTATION caught  " if not bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
