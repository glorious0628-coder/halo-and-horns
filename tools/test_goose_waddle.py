"""The golden goose waddles (user 10/15 "거위가 스스스슥 미끄러지듯 가, 뒤뚱뒤뚱 안 걸어"; 0-won code until its Tripo rig),
offline.

Runs the CURRENT EggFx.WaddleAt in the official Luau CLI (side to side up to WADDLE.Roll degrees, a small bob on each
step, nothing while standing) and checks the wiring: the server goose's looks hidden on this client
(LocalTransparencyModifier), a local copy following its root every frame with the waddle by its ground speed, the copy
gone and the looks back when the goose leaves. Each mutation must make a check fail.

Usage: py tools/test_goose_waddle.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EGG = ROOT / "src/StarterPlayer/StarterPlayerScripts/EggFx.luau"
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local EggFx = {}
__CFG__
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local r, b = EggFx.WaddleAt(math.pi / 2, 1)
check("full speed, mid step: the full roll and bob", math.abs(r - EggFx.WADDLE.Roll) < 1e-9 and math.abs(b - EggFx.WADDLE.Bob) < 1e-9, r)
r, b = EggFx.WaddleAt(-math.pi / 2, 1)
check("the other step leans the other way, bob still up", math.abs(r + EggFx.WADDLE.Roll) < 1e-9 and b > 0, r)
r, b = EggFx.WaddleAt(1.0, 0)
check("standing still: no waddle", r == 0 and b == 0)
r = EggFx.WaddleAt(math.pi / 2, 0.5)
check("half speed: half the lean", math.abs(r - EggFx.WADDLE.Roll / 2) < 1e-9, r)
check("a lean of 8 degrees at most", EggFx.WADDLE.Roll <= 8 and EggFx.WADDLE.Bob <= 0.3)
print(fails == 0 and "WADDLE_PURE_OK" or "WADDLE_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def run(src: str) -> tuple[bool, str]:
    cfg = re.search(r"^EggFx\.WADDLE = \{.*?\}\n", src, re.M)
    fn = block(src, "EggFx.WaddleAt")
    if not (cfg and fn):
        return False, "WADDLE / WaddleAt missing"
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "w.luau"
        f.write_text(PURE.replace("__CFG__", cfg.group(0)).replace("__FUNC__", fn), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    step = block(src, "EggFx.WaddleStep")
    statics = [
        ("the server goose's looks hidden here, a local copy instead", "d.LocalTransparencyModifier = 1" in src
         and 'c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false' in src),
        ("the copy follows the root with the waddle", "local base = root.CFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, math.rad(roll))" in step
         and "part.CFrame = base * off" in step),
        ("the waddle follows the ground speed", "speed = Vector3.new(d.X, 0, d.Z).Magnitude / dt" in step
         and "WADDLE.Phase += speed * dt * W.StepPerStud * math.pi" in step),
        ("the goose gone: the copy goes, the looks come back", "if WADDLE.Model then waddleDrop() end" in step
         and "d.LocalTransparencyModifier = 0" in src),
        ("every frame", "local okW, errW = pcall(EggFx.WaddleStep, dt)" in src),
    ]
    for name, ok in statics:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    return "WADDLE_PURE_OK" in out and all(ok for _, ok in statics), out


MUTATIONS = [
    ("a waddle while standing", "return math.sin(p) * W.Roll * k, math.abs(math.sin(p)) * W.Bob * k",
     "return math.sin(p) * W.Roll, math.abs(math.sin(p)) * W.Bob"),
    ("a bob down too", "math.abs(math.sin(p)) * W.Bob * k", "math.sin(p) * W.Bob * k"),
    ("the waddle never drawn", "\t\tif part.Parent then part.CFrame = base * off end\n", ""),
    ("the server goose still shows", "\t\t\td.LocalTransparencyModifier = 1\n", ""),
    ("the looks never come back", "\t\t\tif d:IsA(\"BasePart\") then d.LocalTransparencyModifier = 0 end\n", ""),
    ("not each frame", "\t\tlocal okW, errW = pcall(EggFx.WaddleStep, dt)\n", "\t\tlocal okW, errW = true, nil\n"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = EGG.read_text(encoding="utf-8")
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
