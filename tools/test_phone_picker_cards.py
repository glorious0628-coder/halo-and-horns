"""Phone faction cards (게임성 개발 1, English dump 10/15: phone_f10_02 had the cards' words at 11 px with 13 cut lines).

Static (FactionPicker.luau): on a phone (touch, a row under 700 real px) the 'what this pick changes' lines under the
cards are hidden and get no room, so the cards take that height; the PC keeps them under the cards. When the perk rows
under a two-line pitch would be shorter than a real 11 px line + 3, the pitch takes one line (its shorter wording) and
the rows get the room. Measured in the test Studio (Galaxy S22 Ultra 749 x 361): every card word fits (TextFits),
photos docs/art/verification_2026-10-15/phone_cards/ (f0 before, f2 after, c1 the class picker). Mutations: each must
be caught.

Usage: py tools/test_phone_picker_cards.py
"""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
FP = ROOT / "src/StarterPlayer/StarterPlayerScripts/FactionPicker.luau"

STATIC = [
    ("phone = touch and a row under 700 real px, worked out before the changes lines",
     ["\tlocal phone = UserInputService.TouchEnabled and areaW * s < 700\n\t-- A23-167 ④: room under the cards"]),
    ("phone: the changes lines hidden and no room kept", [
        "\t\t\tc.Changes.Frame.Visible = not phone\n",
        "\t\t\tif not phone then chLines = math.max(chLines, #c.Changes.Labels) end\n",
        "\t\t\tif c.Changes and not phone then -- A23-167 ④"]),
    ("the PC keeps the changes lines under the cards", ["\t\t\t\tplace(c.Changes.Frame, cx, y0, cw, chH - LAY.ChangesGap)\n"]),
    ("a short perk row makes the pitch one line (shorter wording)", [
        "if (ph - pitchH) / math.max(LAY.PerkRows, #c.Perks) * scale < MIN_TEXT + 3 then pitchH, lines = pitchH / 2, 1 end\n",
        "pw * lines * scale * 0.9,", "\t\tc.Motto.TextWrapped = lines == 2\n"]),
]
MUTATIONS = [
    ("the changes lines shown on a phone", "\t\t\tc.Changes.Frame.Visible = not phone\n", "\t\t\tc.Changes.Frame.Visible = true\n"),
    ("room kept for them on a phone", "\t\t\tif not phone then chLines = math.max(chLines, #c.Changes.Labels) end\n",
     "\t\t\tchLines = math.max(chLines, #c.Changes.Labels)\n"),
    ("the pitch always two lines", "then pitchH, lines = pitchH / 2, 1 end\n", "then pitchH, lines = pitchH, 2 end\n"),
    ("one line of pitch measured as two", "pw * lines * scale * 0.9,", "pw * 2 * scale * 0.9,"),
]


def check(src: str) -> list[str]:
    return [name for name, needles in STATIC if not all(src.count(n) == 1 for n in needles)]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = FP.read_text(encoding="utf-8")
    fails = check(src)
    for f in fails:
        print("STATIC_FAIL " + f)
    caught = 0
    for name, old, new in MUTATIONS:
        ok = src.count(old) == 1 and len(check(src.replace(old, new))) > 0
        caught += ok
        print(("MUTATION caught  " if ok else "MUTATION MISSED ") + name)
    status = "passed" if not fails and caught == len(MUTATIONS) else "failed"
    print(f"Status: {status} (statics {len(STATIC) - len(fails)}/{len(STATIC)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
