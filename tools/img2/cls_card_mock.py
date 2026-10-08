"""Class picker mock: each CLS_<faction><class>_<M|F>_Card picture placed in its ClassPick<faction> frame's Portrait
region (approved.json layout), at full card size and at a phone-ish small size, to judge contrast (0 credits).

  py tools/img2/cls_card_mock.py <out.jpg> [--dir art/ui] [--suffix _Card] [names...]
names default to all 12 Halo / Horns cards; --dir lets a candidate folder be compared.
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
args = sys.argv[1:]
OUT = args.pop(0)
DIR = args[args.index("--dir") + 1] if "--dir" in args else ROOT + "art/ui"
names = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] != "--dir")]
if not names:
    names = [f"CLS_{f}{c}_{g}_Card" for f in ("Halo", "Horns") for c in ("Warrior", "Mage", "Archer") for g in ("M", "F")]
A = json.load(open(ROOT + "art/approved.json", encoding="utf-8"))
F = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 14)
CW = 300
cards = []
for n in names:
    fac = "Halo" if "_Halo" in n or n.startswith("CLS_Halo") else "Horns"
    frame = Image.open(ROOT + f"art/ui/ClassPick{fac}.png").convert("RGBA")
    W, H = frame.size
    x, y, w, h = A[f"ClassPick{fac}"]["layout"]["Portrait"]
    pic = Image.open(f"{DIR}/{n}.png").convert("RGBA").resize((round(w * W), round(h * H)), Image.LANCZOS)
    card = Image.new("RGBA", frame.size, (40, 44, 70, 255))
    card.alpha_composite(frame)
    card.alpha_composite(pic, (round(x * W), round(y * H)))
    cards.append((n, card.convert("RGB")))
ch = round(CW * cards[0][1].height / cards[0][1].width)
cols = 6
rows = (len(cards) + cols - 1) // cols
s = Image.new("RGB", (cols * (CW + 10) + 10, rows * (ch + 130) + 10), (40, 44, 70))
d = ImageDraw.Draw(s)
for i, (n, c) in enumerate(cards):
    x0, y0 = 10 + (i % cols) * (CW + 10), 10 + (i // cols) * (ch + 130)
    s.paste(c.resize((CW, ch), Image.LANCZOS), (x0, y0))
    small = c.resize((90, round(90 * c.height / c.width)), Image.LANCZOS)
    s.paste(small, (x0, y0 + ch + 4))
    d.text((x0 + 100, y0 + ch + 10), n.replace("CLS_", "").replace("_Card", ""), font=F, fill=(230, 230, 240))
s.save(OUT, quality=90)
print(OUT, s.size)
