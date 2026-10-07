"""Quick look for one monster: concept (match-aligned) | render labels in the match view, then the same labels in the game
view, each on the concept's grey. Optional 100% crop box (concept pixels) for a close row.

  py tools/img2/mon_tex_view.py <Kind> <out.png> <label> [label ...] [--crop x0,y0,x1,y1] [--cell 420]
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
args = sys.argv[1:]
kind, out = args[0], args[1]
labels, crop, cell = [], None, 420
i = 2
while i < len(args):
    if args[i] == "--crop":
        crop = [int(v) for v in args[i + 1].split(",")]
        i += 2
    elif args[i] == "--cell":
        cell = int(args[i + 1])
        i += 2
    else:
        labels.append(args[i])
        i += 1
sys.path.insert(0, ROOT + "tools/img2")
from mon_tex import M  # noqa: E402

W = ROOT + f"build/montex/{kind}/"
cam = json.load(open(W + "cam.json"))
concept = Image.open(ROOT + M[kind][1]).convert("RGB")
CW, CH = concept.size
corner = concept.getpixel((6, 6))
F = ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf", 18)


def aligned(label, view="match"):
    """The render on the concept's grey; match renders are moved onto the concept's frame (cam.json transform)."""
    r = Image.open(W + f"r/{label}_{view}.png").convert("RGBA")
    if view == "match":
        sc = cam["scale"]
        r = r.resize((round(r.width * sc), round(r.height * sc)), Image.LANCZOS)
        bg = Image.new("RGBA", (CW, CH), corner + (255,))
        bg.alpha_composite(r, (round(cam["dx"]), round(cam["dy"]))) if cam["dx"] >= 0 and cam["dy"] >= 0 else bg.paste(r, (round(cam["dx"]), round(cam["dy"])), r)
        return bg.convert("RGB")
    bg = Image.new("RGBA", r.size, corner + (255,))
    bg.alpha_composite(r)
    return bg.convert("RGB")


def fit(im, box):
    im = im.copy()
    im.thumbnail((box, box), Image.LANCZOS)
    t = Image.new("RGB", (box, box), corner)
    t.paste(im, ((box - im.width) // 2, (box - im.height) // 2))
    return t


cols = ["concept"] + labels
rows = []
rows.append([fit(concept, cell)] + [fit(aligned(l), cell) for l in labels])
rows.append([Image.new("RGB", (cell, cell), corner)] + [fit(aligned(l, "game"), cell) for l in labels])
if crop:
    x0, y0, x1, y1 = crop
    rows.append([concept.crop(crop).resize((cell, round(cell * (y1 - y0) / (x1 - x0))))] +
                [aligned(l).crop(crop).resize((cell, round(cell * (y1 - y0) / (x1 - x0)))) for l in labels])
H = sum(r[0].height for r in rows) + 30
s = Image.new("RGB", (cell * len(cols), H), (250, 245, 236))
d = ImageDraw.Draw(s)
for j, c in enumerate(cols):
    d.text((j * cell + 6, 4), c, font=F, fill=(20, 20, 60))
y = 30
for r in rows:
    for j, im in enumerate(r):
        s.paste(im, (j * cell, y))
    y += r[0].height
s.save(out)
print(out, s.size)
