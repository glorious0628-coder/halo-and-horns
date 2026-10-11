"""Review sheet for the extra decorations (sign, shop window goods, roof glass), 이미지 생성 3, 10/12.

  py tools/house_extras_sheet.py <out.jpg>

Rows: Bakery / Juice / Potion (2D | Tripo crop | sign close-up | shop-window close-up | whole front), 05 and Flower
(2D | Tripo roof crop | roof close-up | whole front). Images from build/deco/<house>/preview_extras/ (tools/house_deco_closeups.py)
and build/deco/<house>/preview/front.png.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1]
CELL = 380
try:
    font = ImageFont.truetype("malgun.ttf", 20)
    small = ImageFont.truetype("malgun.ttf", 16)
except OSError:
    font = small = ImageFont.load_default()


def tripo_crop(n, x0, x1, z0, z1):
    F = json.load(open(os.path.join(ROOT, "build", "deco", "ortho", n, "frame.json")))["views"]["front"]
    im = Image.open(os.path.join(ROOT, "build", "deco", "ortho", n, "front.png")).convert("RGB")
    W, H = im.size
    ua, umin, umax, us = F["u"]
    va, vmin, vmax, vs = F["v"]
    ppu = H / (vmax - vmin) if (vmax - vmin) > (umax - umin) else W / (umax - umin)

    def px(x, z):
        return (W / 2 + (x - (umin + umax) / 2) * ppu * us, H / 2 - (z - (vmin + vmax) / 2) * ppu * vs)
    a, b = px(x1, z1), px(x0, z0)
    return im.crop((int(min(a[0], b[0])), int(a[1]), int(max(a[0], b[0])), int(b[1])))


ROWS = [
    ("HaloShop_Bakery", "간판·진열창", (-8, 8, 2, 17), ["close_sign", "close_shop"]),
    ("HaloShop_Juice", "간판·진열창", (-10, 10, 2, 22), ["close_sign", "close_shop"]),
    ("HaloShop_Potion", "간판·진열창", (-10, 10, 2, 20), ["close_sign", "close_shop"]),
    ("HaloDomeHouse_05", "지붕 유리 채광창", (-6, 6, 13, 22), ["close_roof"]),
    ("HaloShop_Flower", "지붕 유리 온실", (-9, 9, 12, 30), ["close_roof"]),
]
COLS = 5
S = Image.new("RGB", (COLS * (CELL + 8) + 8, 40 + len(ROWS) * (CELL + 34)), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((10, 8), "빛 마을 빠진 장식 — 간판(Tripo 잘라 대칭) · 진열창 속(Tripo 투영) · 지붕 유리(정확한 금 틀)", fill=(240, 240, 240), font=font)
for r, (n, lab, box, closes) in enumerate(ROWS):
    y = 40 + r * (CELL + 34)
    d.text((10, y), "%s — %s" % (n, lab), fill=(255, 210, 120), font=small)
    spec = json.load(open(os.path.join(ROOT, "tools", "house_specs", n + ".json"), encoding="utf-8"))
    cells = [("2D", Image.open(os.path.join(ROOT, spec["src2d"]))), ("Tripo HD", tripo_crop(n, *box))]
    for cname in closes:
        p = os.path.join(ROOT, "build", "deco", n, "preview_extras", cname + ".png")
        cells.append(({"close_sign": "간판 가까이", "close_shop": "진열창 가까이", "close_roof": "지붕 가까이"}[cname],
                      Image.open(p) if os.path.isfile(p) else None))
    cells.append(("골격 + 장식 앞", Image.open(os.path.join(ROOT, "build", "deco", n, "preview", "front.png"))))
    for c, (t, im) in enumerate(cells):
        x = 8 + c * (CELL + 8)
        if im is not None:
            im = im.convert("RGB")
            im.thumbnail((CELL, CELL))
            S.paste(im, (x + (CELL - im.width) // 2, y + 24 + (CELL - im.height) // 2))
        d.text((x + 6, y + 28), t, fill=(255, 255, 255), font=small)
S.save(OUT, quality=88)
print("[extras]", OUT, S.size)
