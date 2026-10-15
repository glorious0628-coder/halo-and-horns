"""Why a press failed, shown at the spot (최종 검수 10/15 #1; A23-180: still no shake, no words, no sound), static.

SkillBar: a refused skill press (SkillBar.Gate) flashes its why - MP short = the MP bar's rim, a cooldown = that slot's
rim - through UIKit.Refuse with Shake = false and Sound = false, at most once per T.WhyGap s; a locked key stays as it was.
HUD: an attack (Swing / Release) with nothing in reach outlines the nearest monster within Config.AutoFace.FarK x the
range (a soft Highlight, no fill) for FarShow s, at most once per FarGap s. Each mutation must make a check fail.

Usage: py tools/test_fail_spot.py
"""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"SB": SPS / "SkillBar.luau", "HUD": SPS / "HUD.luau", "CFG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}

STATIC = [
    ("SB", "a refused press shows its why", ["\tlocal ok, why = SkillBar.Gate(st, pressBuffer())\n",
                                              "\tif not ok then\n\t\tSkillBar.ShowWhy(slot, why)\n\t\treturn false\n\tend\n"]),
    ("SB", "MP = the MP bar, Cooldown = the slot, else nowhere",
     ['\tif why == "MP" then return "MPBar" elseif why == "Cooldown" then return "Slot" end\n\treturn nil\n']),
    ("SB", "no shake, no sound, once per WhyGap", ["\tpcall(UIKit.Refuse, target, { Shake = false, Sound = false })\n",
                                                   "os.clock() - (S.whyAt or -math.huge) < T.WhyGap", "\tWhyGap = 0.8,"]),
    ("SB", "the MP bar is found in MainGui", ['target = gui and gui:FindFirstChild("MPBar", true) or nil\n']),
    ("HUD", "nothing in reach -> the nearest just out of reach", [
        "\tlocal far, farD = nil, range * (tonumber(A.FarK) or 2)",
        "\t\t\telseif d < farD then\n\t\t\t\tfar, farD = m, d\n",
        "\t\tif best then L.AIM.ShowRing() elseif far then L.AIM.TooFar(far) end\n"]),
    ("HUD", "a soft outline, no fill, for FarShow s, once per FarGap s", [
        "\t\th.FillTransparency = 1\n", "task.delay(tonumber(A.FarShow) or 0.7, function()",
        "os.clock() - (L.AIM.FarAt or -math.huge) < (tonumber(A.FarGap) or 0.8)"]),
    ("CFG", "the numbers in Config.AutoFace", ["\tFarK = 2, FarShow = 0.7, FarGap = 0.8,\n"]),
]
MUTATIONS = [
    ("SB", "the why never shown", "\t\tSkillBar.ShowWhy(slot, why)\n", ""),
    ("SB", "a cooldown flashes the MP bar", 'elseif why == "Cooldown" then return "Slot" end', 'elseif why == "Cooldown" then return "MPBar" end'),
    ("SB", "the flash shakes", "{ Shake = false, Sound = false }", "{ Sound = false }"),
    ("SB", "the flash plays the Deny sound", "{ Shake = false, Sound = false }", "{ Shake = false }"),
    ("HUD", "the far monster never outlined", " elseif far then L.AIM.TooFar(far) end\n", " end\n"),
    ("HUD", "the outline filled", "\t\th.FillTransparency = 1\n", "\t\th.FillTransparency = 0.5\n"),
]


def check(texts: dict[str, str]) -> list[str]:
    return [name for fk, name, needles in STATIC if not all(texts[fk].count(n) == 1 for n in needles)]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    texts = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    fails = check(texts)
    for f in fails:
        print("STATIC_FAIL " + f)
    caught = 0
    for fk, name, old, new in MUTATIONS:
        ok = texts[fk].count(old) == 1 and len(check(dict(texts, **{fk: texts[fk].replace(old, new)}))) > 0
        caught += ok
        print(("MUTATION caught  " if ok else "MUTATION MISSED ") + name)
    status = "passed" if not fails and caught == len(MUTATIONS) else "failed"
    print(f"Status: {status} (statics {len(STATIC) - len(fails)}/{len(STATIC)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
