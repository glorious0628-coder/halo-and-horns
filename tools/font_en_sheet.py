"""A23-43 English font candidates as one review sheet, rendered offline with PIL from the font files Roblox ships
(%LOCALAPPDATA%/Roblox/Versions/<newest>/content/fonts): no Studio, no screen control.

Each candidate = one face for titles / buttons / numbers + one body face. Every sample is drawn the way UIKit.StyleText
draws text over the world (white -> cream gradient look approximated by white, navy #1B2140 rim 1.5-3 px by size) on
the game's dark plate, a bright ground photo strip and parchment (navy text, no rim), at the real pixel sizes of the
text style plan (12 / 14 / 16 / 20 / 28 / 40 px).

Usage: py tools/font_en_sheet.py [--out art/review/font_en_candidates_2026-10-06.png]
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
NAVY = (27, 33, 64)
WHITE = (255, 255, 255)
CREAM = (255, 236, 190)
PARCH = (238, 222, 186)
DARK = (22, 26, 44)

CANDIDATES = [
    ("1  Fredoka One + Builder Sans", "FredokaOne-Regular.ttf", "BuilderSans-Regular.otf", "BuilderSans-Bold.otf"),
    ("2  Luckiest Guy + Nunito", "LuckiestGuy-Regular.ttf", "Nunito-Regular.ttf", "Nunito-Regular.ttf"),
    ("3  Denk One + Montserrat", "DenkOne-Regular.ttf", "Montserrat-Regular.ttf", "Montserrat-Bold.ttf"),
]
TITLE = "Halo & Horns"
BUTTONS = ["Attack", "Skill  MP20", "Auto", "Menu", "Settings", "Travel"]
NUMBERS = "Lv 12 · Power 1,284 · 1,250/1,250 HP · 9:40"
BODY = "Defeat 5 slimes to reclaim the supply road. Then visit the smith at the Crossroads."
QUEST = "Daily: Hunt goblins  3/5"
TAG = "Darugi_52  [Holy Knight]"


def font_dir() -> Path:
    base = Path(os.environ.get("LOCALAPPDATA", "")) / "Roblox" / "Versions"
    dirs = [d / "content" / "fonts" for d in base.glob("version-*") if (d / "content" / "fonts").is_dir()]
    if not dirs:
        raise SystemExit("Roblox font folder not found")
    return max(dirs, key=lambda d: d.stat().st_mtime)


def rim(px: float) -> int:
    # UIKit.StrokeTiers: <= 16 px -> 1.5, <= 28 -> 2, else 3 (PIL takes whole pixels: 1.5 -> 2)
    return 2 if px <= 28 else 3


def draw_text(d: ImageDraw.ImageDraw, xy, text, font, on_light=False):
    if on_light:
        d.text(xy, text, font=font, fill=NAVY)
    else:
        d.text(xy, text, font=font, fill=WHITE, stroke_width=rim(font.size), stroke_fill=NAVY)


def ground_strip(w: int, h: int) -> Image.Image:
    """a bright 'marble square / sky' strip like the town ground behind HUD text"""
    im = Image.new("RGB", (w, h), (226, 232, 238))
    d = ImageDraw.Draw(im)
    for i in range(0, w, 46):
        d.rectangle([i, 0, i + 22, h], fill=(244, 246, 250))
    for j in range(0, h, 30):
        d.line([0, j, w, j], fill=(206, 212, 220), width=2)
    return im


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default="art/review/font_en_candidates_2026-10-06.png")
    args = ap.parse_args()
    fd = font_dir()
    W, block_h = 1500, 420
    sheet = Image.new("RGB", (W, 70 + block_h * len(CANDIDATES)), (245, 243, 236))
    d = ImageDraw.Draw(sheet)
    label = ImageFont.truetype(str(fd / "BuilderSans-Bold.otf"), 26)
    small = ImageFont.truetype(str(fd / "BuilderSans-Regular.otf"), 16)
    d.text((20, 18), "A23-43 English fonts (Roblox built-in, rendered at real px; white + navy rim = HUD over the world)",
           font=label, fill=NAVY)
    for i, (name, head_file, body_file, body_bold) in enumerate(CANDIDATES):
        y0 = 70 + i * block_h
        d.text((20, y0 + 6), name, font=label, fill=NAVY)
        d.text((520, y0 + 12), f"title / button / number: {head_file}   body: {body_file} (+ {body_bold})", font=small,
               fill=(90, 90, 110))
        # dark plate
        plate = Image.new("RGB", (W - 40, 170), DARK)
        pd = ImageDraw.Draw(plate)
        head40 = ImageFont.truetype(str(fd / head_file), 40)
        head20 = ImageFont.truetype(str(fd / head_file), 20)
        head16 = ImageFont.truetype(str(fd / head_file), 16)
        body14 = ImageFont.truetype(str(fd / body_file), 14)
        body16 = ImageFont.truetype(str(fd / body_file), 16)
        bold12 = ImageFont.truetype(str(fd / body_bold), 12)
        bold14 = ImageFont.truetype(str(fd / body_bold), 14)
        draw_text(pd, (16, 10), TITLE, head40)
        x = 330
        for b in BUTTONS:
            draw_text(pd, (x, 22), b, head20)
            x += int(pd.textlength(b, font=head20)) + 28
        draw_text(pd, (16, 70), NUMBERS, head16)
        draw_text(pd, (16, 100), BODY, body16)
        draw_text(pd, (16, 130), QUEST + "     " + TAG, bold14)
        draw_text(pd, (760, 130), "12 px tag: " + TAG, bold12)
        sheet.paste(plate, (20, y0 + 44))
        # bright ground strip (the quest lines / war line case)
        strip = ground_strip(700, 150)
        sd = ImageDraw.Draw(strip)
        draw_text(sd, (14, 12), QUEST, bold14)
        draw_text(sd, (14, 40), "Crown decided in 9:40 · My points 0", bold14)
        draw_text(sd, (14, 70), "Attack   Skill MP20", head20)
        draw_text(sd, (14, 108), NUMBERS, head16)
        sheet.paste(strip, (20, y0 + 222))
        # parchment (navy text, no rim)
        parch = Image.new("RGB", (W - 40 - 720, 150), PARCH)
        qd = ImageDraw.Draw(parch)
        draw_text(qd, (14, 10), "Travel", ImageFont.truetype(str(fd / head_file), 28), on_light=True)
        first, rest = BODY.split(". ", 1)
        draw_text(qd, (14, 52), first + ".", body14, on_light=True)
        draw_text(qd, (14, 74), rest, body14, on_light=True)
        draw_text(qd, (14, 104), "Buy  120 gold   ·   Lv 10+", head20, on_light=True)
        sheet.paste(parch, (740, y0 + 222))
    out = ROOT / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print("saved", out.relative_to(ROOT).as_posix(), sheet.size, "fonts from", fd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
