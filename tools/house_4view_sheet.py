"""4-side sheet for the house skeletons: 2D front / left / right / back next to the Blender skeleton from the same side
(이미지 생성 3, 10/11, A23-120/122 '4면 근거').

  py tools/house_4view_sheet.py <out.jpg> <name> [<name> ...] [--renders art/review/img3/houses] [--tile 300]

2D: the spec's src2d (front) + art/out/s2/halo/houses_mv/<name>_{left,right,back}.png (the 4 views the Tripo HD
multiview job used). left = seen from the viewer's left (front on the right of the picture) = preview "side" (camera
at +x); right = preview "side_r"; back = preview "back". Renders: tools/skeleton_preview.py --views
front,side,side_r,back (ortho). Each tile is cropped to its content and fitted into the tile, keeping the scale of
the four skeleton views of one house the same (so the sides read at the true depth).
"""
import argparse
import json
import os

from PIL import Image, ImageChops, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("names", nargs="+")
ap.add_argument("--renders", default="art/review/img3/houses")
ap.add_argument("--tile", type=int, default=300)
a = ap.parse_args()
T = a.tile
VIEWS = [("front", "front"), ("left", "side"), ("right", "side_r"), ("back", "back")]
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 18)
    SMALL = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 14)
except OSError:
    FONT = SMALL = ImageFont.load_default()


def content_box(im, tol=18):
    """bounding box of everything that differs from the corner colour"""
    rgb = im.convert("RGB")
    bg = Image.new("RGB", rgb.size, rgb.getpixel((2, 2)))
    diff = ImageChops.difference(rgb, bg).convert("L").point(lambda v: 255 if v > tol else 0)
    return diff.getbbox() or (0, 0, im.width, im.height)


def fit(im, box, scale=None):
    c = im.convert("RGB").crop(box)
    s = scale or min((T - 12) / c.width, (T - 12) / c.height)
    c = c.resize((max(1, int(c.width * s)), max(1, int(c.height * s))), Image.LANCZOS)
    tile = Image.new("RGB", (T, T), im.convert("RGB").getpixel((2, 2)))
    tile.paste(c, ((T - c.width) // 2, T - 6 - c.height))           # stand on the bottom edge
    return tile


rows = []
for n in a.names:
    spec = json.load(open("tools/house_specs/%s.json" % n, encoding="utf-8"))
    src = {"front": spec["src2d"]}
    for v in ("left", "right", "back"):
        src[v] = "art/out/s2/halo/houses_mv/%s_%s.png" % (n, v)
    rend = {v: os.path.join(a.renders, n, r + ".png") for v, r in VIEWS}
    ims3 = {v: Image.open(p) for v, p in rend.items() if os.path.exists(p)}
    boxes = {v: content_box(im) for v, im in ims3.items()}
    # one scale for the four skeleton views: the tallest / widest of them fills the tile
    s3 = min(min((T - 12) / (b[2] - b[0]), (T - 12) / (b[3] - b[1])) for b in boxes.values()) if boxes else 1.0
    tiles = []
    for v, _ in VIEWS:
        if os.path.exists(src[v]):
            im = Image.open(src[v])
            tiles.append(fit(im, content_box(im)))
        else:
            tiles.append(Image.new("RGB", (T, T), (90, 30, 30)))
        tiles.append(fit(ims3[v], boxes[v], s3) if v in ims3 else Image.new("RGB", (T, T), (90, 30, 30)))
    rows.append((n, tiles))

head = 34
W = 8 * T + 9 * 4
H = head + len(rows) * (T + 26)
sheet = Image.new("RGB", (W, H), (24, 24, 30))
d = ImageDraw.Draw(sheet)
d.text((8, 6), "집 골격 4면 — 2D | 골격 (앞 · 왼쪽에서 · 오른쪽에서 · 뒤), tools/skeleton_house.py + skeleton_preview.py", fill=(235, 235, 235), font=FONT)
for r, (n, tiles) in enumerate(rows):
    y = head + r * (T + 26)
    d.text((8, y + 2), n, fill=(255, 210, 120), font=SMALL)
    for k, t in enumerate(tiles):
        x = 4 + k * (T + 4)
        sheet.paste(t, (x, y + 22))
        lab = ("2D " if k % 2 == 0 else "골격 ") + ["앞", "왼쪽", "오른쪽", "뒤"][k // 2]
        d.text((x + 4, y + 24), lab, fill=(20, 20, 20) if k % 2 else (240, 240, 240), font=SMALL)
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
sheet.save(a.out, quality=90)
print("[sheet]", a.out, sheet.size)
