"""Old 2D vs shadow-free redraw (Codex) sheet for weapons (무기 디자인, 10/14).

Per weapon: row 1 old front/left/right/back (art/out/s2/weapons_t13_4v), row 2 new (art/out/s2/weapons_t13_4v_ns),
row 3 100% crops of the front: head / middle / grip, old | new.

  py tools/weapon_ns_sheet.py <out.jpg> <Name> [<Name> ...]
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = os.path.join(ROOT, "art", "out", "s2", "weapons_t13_4v")
NEW = os.path.join(ROOT, "art", "out", "s2", "weapons_t13_4v_ns")
SIDES = ["front", "left", "right", "back"]
T = 300
CROP = 330


def load(d, n, s):
    p = os.path.join(d, f"{n}_{s}.png")
    if d == OLD and os.path.exists(os.path.join(d, f"{n}_{s}_v2.png")):
        p = os.path.join(d, f"{n}_{s}_v2.png")
    return Image.open(p).convert("RGB").resize((1024, 1024), Image.LANCZOS) if os.path.exists(p) else None


def main():
    out, names = sys.argv[1], sys.argv[2:]
    blockh = 2 * (T + 16) + CROP + 30
    sheet = Image.new("RGB", (T * 4 + 10, blockh * len(names)), "white")
    dr = ImageDraw.Draw(sheet)
    for b, n in enumerate(names):
        y0 = b * blockh
        for r, (d, tag) in enumerate(((OLD, "old"), (NEW, "NEW no-shadow"))):
            for c, s in enumerate(SIDES):
                im = load(d, n, s)
                y = y0 + r * (T + 16) + 14
                dr.text((c * T + 4, y - 13), f"{n.replace('Weapon_', '')} {s} {tag}", fill="black")
                if im is None:
                    dr.text((c * T + 40, y + 100), "missing", fill="red")
                    continue
                sheet.paste(im.resize((T, T), Image.LANCZOS), (c * T, y))
        y = y0 + 2 * (T + 16) + 14
        fo, fn = load(OLD, n, "front"), load(NEW, n, "front")
        x = 0
        for lab, cy in (("head", 200), ("mid", 470), ("grip", 760)):
            for im, tag in ((fo, "old"), (fn, "new")):
                if im is None:
                    continue
                cr = im.crop((512 - 100, cy - 165, 512 + 100, cy + 165))
                sheet.paste(cr, (x, y))
                dr.text((x + 2, y - 12), f"100% {lab} {tag}", fill="black")
                x += 200
    sheet.save(out, quality=90)
    print("saved", out)


main()
