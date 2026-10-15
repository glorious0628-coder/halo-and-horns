"""Scroll results on the weapon's cells (user 10/15 "강화가 된 건지 안 된 건지 모르겠어", 최종 검수 feedback ⑥), offline.

BagUI.ResultKind(r) -> "Up" / "Keep" / "Down" / nil (a move or a broken result) runs in the official Luau CLI; static:
the effect starts only from Panels' result (the server's Fx "Enhance": Before / After / Success), Up = a gold flash + a
ROUND gold ring (UICorner 0.5, never rays) + stars + the number popping to +After, Keep / Down = a grey dim + smoke +
a small shake (none with reduced motion), Down = the number red sliding to +After. Each mutation must make a check fail.

Usage: py tools/test_enhance_fx.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BAG = ROOT / "src/StarterPlayer/StarterPlayerScripts/BagUI.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local BagUI = {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
check("success +3 -> +4 = Up", BagUI.ResultKind({ Success = true, Before = 3, After = 4 }) == "Up")
check("fail, kept +3 = Keep", BagUI.ResultKind({ Success = false, Before = 3, After = 3 }) == "Keep")
check("fail, +3 -> +2 = Down", BagUI.ResultKind({ Success = false, Before = 3, After = 2 }) == "Down")
check("fail at +0 = Keep", BagUI.ResultKind({ Success = false, Before = 0, After = 0 }) == "Keep")
check("a move (transfer scroll) = none", BagUI.ResultKind({ Success = true, Move = true, Before = 0, After = 3 }) == nil)
check("a broken result = none", BagUI.ResultKind({ Success = true }) == nil and BagUI.ResultKind(nil) == nil)
check("a 'success' that did not go up is not Up", BagUI.ResultKind({ Success = true, Before = 5, After = 5 }) == "Keep")
print(fails == 0 and "ENHANCE_FX_PURE_OK" or "ENHANCE_FX_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def pure(src: str) -> tuple[bool, str]:
    fn = block(src, "BagUI.ResultKind")
    if not fn:
        return False, "ResultKind missing"
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "efx.luau"
        f.write_text(PURE.replace("__FUNC__", fn), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    return "ENHANCE_FX_PURE_OK" in out, out


def statics(s: str) -> list[tuple[str, bool]]:
    play = block(s, "BagUI.PlayResult")
    return [
        ("the effect starts from the server's result (pollResult)",
         "task.delay(BagUI.RES.Wait, function() pcall(BagUI.PlayResult, r) end)" in s
         and s.find("S.Result, S.ResultAt = r, at") < s.find("task.delay(BagUI.RES.Wait")),
        ("Up = gold flash + round ring + stars; else the grey dim / smoke / shake",
         "if kind == \"Up\" then resUp(box) else resFail(box) end" in play),
        ("the ring is round (never rays)", "rc.CornerRadius = UDim.new(0.5, 0)" in s and "Beam" not in play),
        ("stars are the approved sparkle art", 'kit.ArtImage("RewardSparkle"' in s),
        ("the number moves Before -> After on every cell", "resNumber(box, kind, math.floor(r.Before), math.floor(r.After))" in play),
        ("Down: the number red, sliding down", 'kind == "Down" and R.Red or colorOf("Gold")' in s
         and "txt.Position = UDim2.fromOffset(0, -L.Size.Count)" in s),
        ("Up: the number pops and settles (Back)", "{ Scale = R.Pop }" in s and "Enum.EasingStyle.Back" in s),
        ("no shake with reduced motion", "if not reduced then box.Position = base + UDim2.fromOffset(" in s),
        ("both the grid cell and the picked big cell", '"Cell_W:" .. tostring(tier)' in s and 'picked.Kind == "Weapon" and picked.Tier == tier' in s),
    ]


MUTATIONS = [
    ("never played", "\ttask.delay(BagUI.RES.Wait, function() pcall(BagUI.PlayResult, r) end)\n", ""),
    ("fail looks like success", "if kind == \"Up\" then resUp(box) else resFail(box) end", "resUp(box)"),
    ("Down not told apart", "\tif a < b then return \"Down\" end\n", ""),
    ("a move plays a result", "if type(r) ~= \"table\" or r.Move == true then return nil end", "if type(r) ~= \"table\" then return nil end"),
    ("a square ring", "rc.CornerRadius = UDim.new(0.5, 0)", "rc.CornerRadius = UDim.new(0, 0)"),
    ("Down number stays gold", 'kind == "Down" and R.Red or colorOf("Gold")', 'colorOf("Gold")'),
    ("shakes under reduced motion", "if not reduced then box.Position", "if true then box.Position"),
    ("the number never moves", "\t\tresNumber(box, kind, math.floor(r.Before), math.floor(r.After))\n", ""),
    ("Up on a success that did not go up", "if r.Success == true and a > b then return \"Up\" end", "if r.Success == true then return \"Up\" end"),
]


def run(src: str) -> tuple[bool, list, str]:
    ok, out = pure(src)
    st = statics(src)
    return ok and all(g for _, g in st), st, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = BAG.read_text(encoding="utf-8")
    good, st, out = run(src)
    print(out.strip())
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    caught = 0
    for name, old, new in MUTATIONS:
        if old not in src:
            print("MUTATION NOT_APPLIED " + name)
            continue
        bad, _, _ = run(src.replace(old, new, 1))
        if not bad:
            caught += 1
            print("MUTATION caught  " + name)
        else:
            print("MUTATION MISSED " + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
