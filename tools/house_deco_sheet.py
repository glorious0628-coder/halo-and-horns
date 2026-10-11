"""Review sheet for the Tripo decorations of tools/house_deco_run.py (이미지 생성 3, 10/11).

  py tools/house_deco_sheet.py <out.jpg> <name> [<name> ...]

One row per house: 2D front (spec src2d) | Tripo HD front (build/deco/ortho/<name>/front.png) | skeleton + decorations
front / 3-4 / door close-up (build/deco/<name>/preview/). Korean labels.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.environ.get("HH_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out, names = sys.argv[1], sys.argv[2:]
CELL = 380
COLS = [("2D 앞", None), ("Tripo HD 앞", None), ("골격 + 장식 앞", "front"), ("3/4", "q34"), ("문 가까이", "close_door")]
try:
    font = ImageFont.truetype("malgun.ttf", 20)
    small = ImageFont.truetype("malgun.ttf", 16)
except OSError:
    font = small = ImageFont.load_default()
H = 40 + len(names) * (CELL + 34)
sheet = Image.new("RGB", (len(COLS) * (CELL + 8) + 8, H), (24, 24, 28))
d = ImageDraw.Draw(sheet)
d.text((10, 8), "빛 마을 집 장식 — Tripo HD에서 잘라 Blender 손보기 (돔·꼭지·등불·문짝·손잡이)", fill=(240, 240, 240), font=font)


def fit(im):
    im = im.convert("RGB")
    im.thumbnail((CELL, CELL))
    c = Image.new("RGB", (CELL, CELL), (60, 60, 66))
    c.paste(im, ((CELL - im.width) // 2, (CELL - im.height) // 2))
    return c


for r, n in enumerate(names):
    y = 40 + r * (CELL + 34)
    d.text((10, y), n, fill=(255, 210, 120), font=small)
    spec = json.load(open(os.path.join(ROOT, "tools", "house_specs", n + ".json"), encoding="utf-8"))
    srcs = [os.path.join(ROOT, spec.get("src2d", "")), os.path.join(ROOT, "build", "deco", "ortho", n, "front.png")]
    srcs += [os.path.join(ROOT, "build", "deco", n, "preview", v + ".png") for _, v in COLS[2:]]
    for c, ((lab, _), p) in enumerate(zip(COLS, srcs)):
        x = 8 + c * (CELL + 8)
        if os.path.isfile(p):
            sheet.paste(fit(Image.open(p)), (x, y + 24))
        else:
            d.rectangle([x, y + 24, x + CELL, y + 24 + CELL], outline=(120, 60, 60))
            d.text((x + 10, y + 40), "없음", fill=(255, 120, 120), font=small)
        d.text((x + 6, y + 28), lab, fill=(255, 255, 255), font=small)
sheet.save(out, quality=88)
print("[sheet]", out, sheet.size)
