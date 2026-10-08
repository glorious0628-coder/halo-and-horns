"""Generic candidate sheet: rows of labelled transparent images, each on light and navy plus a small preview.

  py tools/img2/cand_sheet.py <spec.json> <out.jpg>
spec = {"title": "...", "sub": "...", "tile": 200, "small": 48,
        "rows": [{"title": "...", "items": [{"label": "A", "path": "art/...png", "rec": true}, ...]}, ...]}
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
spec = json.load(open(sys.argv[1], encoding="utf-8"))
OUT = sys.argv[2]
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG, DARK, RED = (24, 30, 64), (250, 245, 236), (40, 44, 70), (170, 40, 40)
T = spec.get("tile", 200)
SM = spec.get("small", 48)
cell = 2 * T + SM + 30
maxn = max(len(r["items"]) for r in spec["rows"])
W = 30 + maxn * cell
H = 100 + len(spec["rows"]) * (T + 70)
s = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), spec["title"], font=F(24, True), fill=NAVY)
d.text((30, 50), spec.get("sub", ""), font=F(14), fill=(80, 80, 80))


def tile(im, n, bg):
    t = Image.new("RGBA", (n, n), bg + (255,))
    x = im.copy()
    x.thumbnail((n - 6, n - 6), Image.LANCZOS)
    t.alpha_composite(x, ((n - x.width) // 2, (n - x.height) // 2))
    return t.convert("RGB")


y = 84
for r in spec["rows"]:
    d.text((30, y), r["title"], font=F(17, True), fill=NAVY)
    for i, it in enumerate(r["items"]):
        im = Image.open(ROOT + it["path"]).convert("RGBA")
        x = 30 + i * cell
        s.paste(tile(im, T, BG), (x, y + 26))
        s.paste(tile(im, T, DARK), (x + T + 4, y + 26))
        s.paste(tile(im, SM, BG), (x + 2 * T + 10, y + 26))
        s.paste(tile(im, SM, DARK), (x + 2 * T + 10, y + 26 + SM + 6))
        rec = it.get("rec")
        d.text((x + 2, y + T + 30), it["label"] + ("  ★ 추천" if rec else ""), font=F(14, rec), fill=RED if rec else NAVY)
    y += T + 70
s.save(OUT, quality=90)
print(OUT, s.size)
