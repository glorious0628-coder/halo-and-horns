"""Refusals without words (최종 검수 10/15, user "재미 = 조작에 게임이 어떻게 반응하는지를 비주얼로"; Codex
build/codex/feedback_audit.md #1; A23-191 no explanation text; A23-180 the skill gates never shake), offline.

UIKit.Refuse(target, opts) shows a refusal on the thing pressed: a short shake (not with reduced motion), the rim red
twice, the Deny sound (not when the server's Notify already rang it). Runs the CURRENT UIKit.RefuseOffset /
UIKit.RefuseRim in the official Luau CLI (build/luau_cli_0_741); static: a "bad" toast and a "bad" Notify refuse
instead of drawing words, a press remembers its button (FeelPress), the skill bar refuses on the locked slot, the HUD's
MP shortage flashes the MP bar (no shake, no sound). Each mutation must make a check fail.

Usage: py tools/test_refuse.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"UIKIT": SPS / "UIKit.luau", "SKILL": SPS / "SkillBar.luau", "HUD": SPS / "HUD.luau"}
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local MOTION = { Refuse = { Shake = 6, ShakeTime = 0.3, Flash = 0.5 } }
local UIKit = {}
__FUNCS__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
check("the shake rests at 0 before and after", UIKit.RefuseOffset(0) == 0 and UIKit.RefuseOffset(0.3) == 0 and UIKit.RefuseOffset(1) == 0)
local peak = 0
local flips = 0
local last = 0
for i = 1, 299 do
	local v = UIKit.RefuseOffset(i / 1000)
	peak = math.max(peak, math.abs(v))
	if v * last < 0 then flips += 1 end
	if v ~= 0 then last = v end
end
check("a small shake: under 6 px", peak > 3 and peak <= 6, peak)
check("it swings back and forth (5 turns)", flips == 5, flips)
check("it dies out (the last swing is smaller)", math.abs(UIKit.RefuseOffset(0.27)) < math.abs(UIKit.RefuseOffset(0.025)) + 1e-9,
	UIKit.RefuseOffset(0.27))
check("the rim is hidden before and after", UIKit.RefuseRim(0) == 1 and UIKit.RefuseRim(0.5) == 1 and UIKit.RefuseRim(2) == 1)
check("the rim flashes twice (solid at 1/4 and 3/4)", UIKit.RefuseRim(0.125) < 0.01 and UIKit.RefuseRim(0.375) < 0.01
	and UIKit.RefuseRim(0.25) > 0.99, UIKit.RefuseRim(0.25))
print(fails == 0 and "REFUSE_PURE_OK" or "REFUSE_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def pure(uikit: str) -> tuple[bool, str]:
    funcs = block(uikit, "UIKit.RefuseOffset") + block(uikit, "UIKit.RefuseRim")
    if not funcs:
        return False, "functions missing"
    code = PURE.replace("__FUNCS__", funcs)
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "refuse.luau"
        f.write_text(code, encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    return "REFUSE_PURE_OK" in out, out


def statics(s: dict[str, str]) -> list[tuple[str, bool]]:
    u, sk, hud = s["UIKIT"], s["SKILL"], s["HUD"]
    toast = block(u, "UIKit.Toast")
    return [
        ("a 'bad' toast refuses instead of drawing words",
         'if not NOTIFY.Words then\n\t\tUIKit.Refuse(nil)\n\t\treturn\n\tend' in toast
         and toast.find("UIKit.Refuse(nil)") < toast.find("toastCounter += 1")),
        ("a 'bad' Notify refuses without a second sound",
         'if payload.Kind == "bad" then UIKit.Refuse(nil, { Sound = false }) end' in u
         and 'UIKit.Toast(text, "bad"' not in u),
        ("a press remembers its button for the refusal",
         "if down == true then MOTION.Refuse.Last, MOTION.Refuse.At = btn, os.clock() end" in block(u, "UIKit.FeelPress")),
        ("no target: the last pressed button within Recent s",
         "if target == nil and R.Last and os.clock() - R.At <= R.Recent then target = R.Last end" in block(u, "UIKit.Refuse")),
        ("Deny sound unless Sound = false", 'if opts.Sound ~= false then' in block(u, "UIKit.Refuse")
         and 'pcall(audio.Play, "Deny")' in block(u, "UIKit.Refuse")),
        ("no shake with reduced motion or Shake = false",
         "local shake = opts.Shake ~= false and not UIKit.ReducedMotion()" in block(u, "UIKit.Refuse")),
        ("the button's own border stroke is put back", "\t\t\trestore()\n" in block(u, "UIKit.Refuse")
         and "rim.Color, rim.Transparency, rim.Enabled = saved[1], saved[2], saved[3]" in block(u, "UIKit.Refuse")),
        ("the skill bar never toasts a refusal", 'UIKit.Toast, line, "bad"' not in sk and '"Teach", name), "bad"' not in sk),
        ("a teacher-locked slot refuses on that slot", "pcall(UIKit.Refuse, SkillBar.Button(LEARN.TeachSlot))" in sk
         and "LEARN.TeachSlot = slot" in sk),
        ("MP short: the MP bar flashes, no shake, no sound (A23-180)",
         'UIKit.Refuse(ui.stats and ui.stats:FindFirstChild("MPBar", true) or nil, { Shake = false, Sound = false })' in hud
         and 'UIKit.Toast(TXT.NoMana, "bad"' not in hud),
    ]


MUTATIONS = [
    ("UIKIT", "a bad toast draws words again", "\tif not NOTIFY.Words then\n\t\tUIKit.Refuse(nil)\n\t\treturn\n\tend\n", ""),
    ("UIKIT", "the server's bad Notify rings twice", 'UIKit.Refuse(nil, { Sound = false })', "UIKit.Refuse(nil)"),
    ("UIKIT", "the pressed button forgotten", "\tif down == true then MOTION.Refuse.Last, MOTION.Refuse.At = btn, os.clock() end -- the button a refusal shakes\n", ""),
    ("UIKIT", "a shake under reduced motion", "local shake = opts.Shake ~= false and not UIKit.ReducedMotion()", "local shake = opts.Shake ~= false"),
    ("UIKIT", "a big shake", "return amp * (1 - t / time) * math.sin(t / time * math.pi * 6)", "return 3 * amp * math.sin(t / time * math.pi * 6)"),
    ("UIKIT", "one flash only", "return 1 - math.abs(math.sin(t / time * math.pi * 2))", "return 1 - math.abs(math.sin(t / time * math.pi))"),
    ("UIKIT", "the own stroke left red", "\t\t\trestore()\n", "\t\t\trim.Enabled = false\n"),
    ("SKILL", "the teacher slot not shaken", "pcall(UIKit.Refuse, SkillBar.Button(LEARN.TeachSlot))", "pcall(UIKit.Refuse, nil)"),
    ("HUD", "MP short shakes the bar", "{ Shake = false, Sound = false })", "{ Sound = false })"),
]


def run(src: dict[str, str]) -> tuple[bool, list[tuple[str, bool]], str]:
    ok, out = pure(src["UIKIT"])
    st = statics(src)
    return ok and all(g for _, g in st), st, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    good, st, out = run(src)
    print(out.strip())
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if old not in src[key]:
            print("MUTATION NOT_APPLIED " + name)
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new, 1)
        bad, _, _ = run(m)
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
