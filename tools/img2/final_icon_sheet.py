"""Final transparent icons check sheet: each icon on light / navy / magenta, plus 64 / 48 / 40 / 32 px on light and navy.

  py tools/img2/final_icon_sheet.py <out.jpg> <title> <art/ui name:Korean,...>
"""
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
OUT, TITLE, ITEMS = sys.argv[1], sys.argv[2], [it.split(":") for it in sys.argv[3].split(",")]
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG, DARK, MAG = (24, 30, 64), (250, 245, 236), (40, 44, 70), (200, 40, 200)


def tile(im, d, bg):
    t = Image.new("RGBA", (d, d), bg + (255,))
    x = im.copy()
    x.thumbnail((d, d), Image.LANCZOS)
    t.alpha_composite(x, ((d - x.width) // 2, (d - x.height) // 2))
    return t.convert("RGB")


RH = 300
W = 30 + 3 * 230 + 2 * 250
s = Image.new("RGB", (W, 90 + RH * len(ITEMS)), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), TITLE, font=F(24, True), fill=NAVY)
d.text((30, 50), "밝은 · 어두운 · 자홍(누끼 점검) 바탕 + 64 · 48 · 40 · 32px. 512 투명 PNG.", font=F(15), fill=(80, 80, 80))
for i, (name, ko) in enumerate(ITEMS):
    im = Image.open(ROOT + "art/ui/" + name + ".png").convert("RGBA")
    y = 90 + i * RH
    d.text((30, y), f"{ko}  —  art/ui/{name}.png {im.size[0]}×{im.size[1]}", font=F(17, True), fill=NAVY)
    for k, bg in enumerate([BG, DARK, MAG]):
        s.paste(tile(im, 220, bg), (30 + k * 230, y + 30))
    for r, bg in enumerate([BG, DARK]):
        x = 30 + 3 * 230 + 10
        for sz in (64, 48, 40, 32):
            s.paste(tile(im, sz, bg), (x, y + 40 + r * 110))
            x += sz + 14
s.save(OUT, quality=92)
print(OUT, s.size)
