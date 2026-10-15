"""A potion drink on screen (최종 검수 10/15, Codex build/codex/feedback_audit.md #4; server Fx "Drink" { Kind, From, To,
Max } = a real drink only), offline.

Runs the CURRENT VitalsUI.DrinkSpan in the official Luau CLI (the lit part of the bar = From..To of Max, clamped; nothing
for no rise / a broken payload) and checks the wiring: Fx "Drink" -> VitalsUI.OnDrink; the lit part on that kind's bar
fades out; small drops of the potion's colour rise round me; no words. Each mutation must make a check fail.

Usage: py tools/test_drink_fx.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VITALS = ROOT / "src/StarterPlayer/StarterPlayerScripts/VitalsUI.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local VitalsUI = {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local a, w = VitalsUI.DrinkSpan(40, 100, 200)
check("40 -> 100 of 200: from 0.2, 0.3 wide", math.abs(a - 0.2) < 1e-9 and math.abs(w - 0.3) < 1e-9, tostring(a) .. "," .. tostring(w))
a, w = VitalsUI.DrinkSpan(180, 260, 200)
check("past the top: clamped to the bar", math.abs(a - 0.9) < 1e-9 and math.abs(w - 0.1) < 1e-9, tostring(w))
check("no rise: nothing", VitalsUI.DrinkSpan(100, 100, 200) == nil)
check("a drop: nothing", VitalsUI.DrinkSpan(100, 50, 200) == nil)
check("a broken payload: nothing", VitalsUI.DrinkSpan(nil, 5, 10) == nil and VitalsUI.DrinkSpan(1, 5, 0) == nil)
print(fails == 0 and "DRINK_PURE_OK" or "DRINK_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def run(src: str) -> tuple[bool, str]:
    fn = block(src, "VitalsUI.DrinkSpan")
    if not fn:
        return False, "DrinkSpan missing"
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "drink.luau"
        f.write_text(PURE.replace("__FUNC__", fn), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    on = block(src, "VitalsUI.OnDrink")
    statics = [
        ("Fx Drink reaches the bar", 'if kind == "Drink" then pcall(VitalsUI.OnDrink, data) end' in src),
        ("the lit part sits on that kind's bar and fades", "local bar = ui[data.Kind]" in on and "glow.Position = UDim2.fromScale(x, 0)" in on
         and "{ BackgroundTransparency = 1 }" in on),
        ("drops of the potion's colour rise round me", "e.Color = ColorSequence.new(COL[data.Kind])" in on and "e:Emit(D.Drops)" in on),
        ("no words", "Toast" not in on and "Announce" not in on and ".Text" not in on),
    ]
    for name, ok in statics:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    return "DRINK_PURE_OK" in out and all(ok for _, ok in statics), out


MUTATIONS = [
    ("never hooked", 'if kind == "Drink" then pcall(VitalsUI.OnDrink, data) end', ""),
    ("the whole bar lights", "glow.Position = UDim2.fromScale(x, 0)", "glow.Position = UDim2.fromScale(0, 0)"),
    ("not clamped", "local b = math.clamp(to / max, 0, 1)", "local b = to / max"),
    ("no drops", "\t\te:Emit(D.Drops)\n", ""),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = VITALS.read_text(encoding="utf-8")
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
