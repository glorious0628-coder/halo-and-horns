"""My crown share made readable (최종 검수 10/15 #11), static. WarService already sends Fx CrownPoint { N, Total } only
for whole personal points it really added (never "+1" per monster). HUD: such a point pops MY side's badge on the war bar
once (a UIScale tween, no number, no banner, none with ReducedMotion, the Guild has no badge); the war window (a press
on the bar) gets a third line "My points: N" from the attribute WarPoints, hidden for the Guild. Each mutation must
make a check fail. (HUD.WarInfoLines' words are run in tools/test_hud_top_1an.py.)

Usage: py tools/test_crown_pop.py
"""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {"HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau", "CFG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
STATIC = [
    ("HUD", "Fx CrownPoint -> L.CrownPop", ['\t\t\tif kind == "CrownPoint" then pcall(L.CrownPop, data) end\n']),
    ("HUD", "only a real whole point, my side's badge, not with ReducedMotion", [
        "\tif type(data) ~= \"table\" or (tonumber(data.N) or 0) < 1 then return false end\n",
        "\tlocal badge = (f == \"Halo\" and ui.warBadgeHalo) or (f == \"Horns\" and ui.warBadgeHorns) or nil\n",
        "or UIKit.ReducedMotion() then return false end\n"]),
    ("HUD", "the war window's third line from WarPoints, hidden for the Guild", [
        'UIKit.GameAttr("WarHornsScore", 0), num("WarPoints", 0))',
        '\t\t\t\tmine.Visible = getFaction() == "Halo" or getFaction() == "Horns"']),
    ("CFG", "the words", ['\t\tMine = "My points: %d",']),
]
MUTATIONS = [
    ("HUD", "the pop never runs", '\t\t\tif kind == "CrownPoint" then pcall(L.CrownPop, data) end\n', ""),
    ("HUD", "a pop for a zero point", "(tonumber(data.N) or 0) < 1 then return false end", "(tonumber(data.N) or 0) < 0 then return false end"),
    ("HUD", "the other side's badge", '(f == "Halo" and ui.warBadgeHalo) or (f == "Horns" and ui.warBadgeHorns)',
     '(f == "Halo" and ui.warBadgeHorns) or (f == "Horns" and ui.warBadgeHalo)'),
    ("HUD", "the Guild sees the line", '\t\t\t\tmine.Visible = getFaction() == "Halo" or getFaction() == "Horns"', "\t\t\t\tmine.Visible = true"),
]


def check(texts):
    return [n for fk, n, needles in STATIC if not all(texts[fk].count(x) == 1 for x in needles)]


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
