"""Round badge candidates sheet (Roblox badges A23-79 / pass icons): per item A and B, each = full image, the round crop
Roblox shows, and small 64 / 40 px previews.

  py tools/img2/badge_sheet.py <out.jpg> <title> <prefix:Name:Korean,...> [--rec tag,tag]
Sources art/out/s2/shop/<prefix>_<Name>_<A|B>_src.png.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
D = ROOT + "art/out/s2/shop/"
OUT, TITLE, ITEMS = sys.argv[1], sys.argv[2], sys.argv[3]
REC = set(sys.argv[sys.argv.index("--rec") + 1].split(",")) if "--rec" in sys.argv else set()
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG, RED = (24, 30, 64), (250, 245, 236), (170, 40, 40)
items = [it.split(":") for it in ITEMS.split(",")]


def circle(im, d):
    im = im.resize((d, d), Image.LANCZOS)
    m = Image.new("L", (d * 4, d * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, d * 4 - 1, d * 4 - 1), fill=255)
    t = Image.new("RGB", (d, d), BG)
    t.paste(im, (0, 0), m.resize((d, d), Image.LANCZOS))
    return t


CW = 200 + 140 + 80 + 20
cols = 2
W = 30 + cols * 2 * (CW + 10)
rows = (len(items) + cols - 1) // cols
H = 100 + rows * (250 + 40)
s = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), TITLE, font=F(26, True), fill=NAVY)
d.text((30, 52), "칸마다: 큰 그림 · Roblox가 보여 주는 원형 · 64px · 40px. A / B 두 안. 글자·숫자·빛살 없음.", font=F(15), fill=(80, 80, 80))
for i, (prefix, name, ko) in enumerate(items):
    bx = 30 + (i % cols) * 2 * (CW + 10)
    by = 90 + (i // cols) * (250 + 40)
    d.text((bx, by), ko, font=F(18, True), fill=NAVY)
    for j, v in enumerate("AB"):
        tag = f"{prefix}_{name}_{v}"
        try:
            im = Image.open(D + tag + "_src.png").convert("RGB")
        except OSError:
            continue
        x = bx + j * (CW + 10)
        y = by + 28
        s.paste(im.resize((200, 200), Image.LANCZOS), (x, y))
        s.paste(circle(im, 130), (x + 206, y))
        s.paste(im.resize((64, 64), Image.LANCZOS), (x + 206, y + 136))
        s.paste(im.resize((40, 40), Image.LANCZOS), (x + 276, y + 148))
        rec = tag in REC
        d.text((x + 2, y + 204), v + ("  ★ 추천" if rec else ""), font=F(15, rec), fill=RED if rec else NAVY)
s.save(OUT, quality=90)
print(OUT, s.size)
