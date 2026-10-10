"""2D | 3D check sheet for one Halo house parts model (이미지 생성 3, 2026-10-10; docs/design/3d_quality_check_2026-10-10.md).

  py tools/house_sheet.py <Name> <front_2d.png> <work_dir>/<Name> <out.jpg>

Needs <work>/<Name>/sheet/ from tools/house_sheet_render.py and <Name>_parts.json from tools/house_parts.py.
Row 1: 2D front | 3D colour only (matte) | 3D all maps (PBR) | 3D three-quarter | 3D back.
Rows 2-3: 100 % crops (one render pixel ~ one texel), each as 2D | matte | PBR at the same spot: door, gold, stone wall,
awning, window, and two seams between the body texture tiles (PBR only). Last line: numbers.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

NAME, F2D, WD, OUT = sys.argv[1:5]
S = os.path.join(WD, "sheet")
info = json.load(open(os.path.join(WD, NAME + "_parts.json"), encoding="utf-8"))
ids = json.load(open(os.path.join(S, "ids.json")))
pbr = Image.open(os.path.join(S, "front_pbr.png")).convert("RGB")
mat = Image.open(os.path.join(S, "front_matte.png")).convert("RGB")
idi = np.asarray(Image.open(os.path.join(S, "front_id.png")).convert("RGB")).astype(int)
R = pbr.size[0]
try:
    FONT = ImageFont.truetype("arial.ttf", 18)
except Exception:
    FONT = ImageFont.load_default()

# silhouettes: 3D from the id pass (non-black), 2D from the grey background
nz = np.nonzero(idi.max(-1) > 30)
b3 = (nz[1].min(), nz[0].min(), nz[1].max(), nz[0].max())
a2 = np.asarray(Image.open(F2D).convert("RGB")).astype(np.float32)
bgc = np.median(np.concatenate([a2[:20, :20].reshape(-1, 3), a2[:20, -20:].reshape(-1, 3)]), 0)
m2 = np.abs(a2 - bgc).max(-1) > 18
nz2 = np.nonzero(m2)
b2 = (nz2[1].min(), nz2[0].min(), nz2[1].max(), nz2[0].max())
img2 = Image.open(F2D).convert("RGB")


def to2d(x, y):
    u = (x - b3[0]) / (b3[2] - b3[0])
    v = (y - b3[1]) / (b3[3] - b3[1])
    return b2[0] + u * (b2[2] - b2[0]), b2[1] + v * (b2[3] - b2[1])


def mask_of(suffix):
    want = [tuple(v) for k, v in ids["ids"].items() if k.endswith(suffix)]
    m = np.zeros(idi.shape[:2], bool)
    for w in want:
        m |= (np.abs(idi - np.array(w)).sum(-1) < 20)
    return m


CS = 300  # crop size in render px (100 %)


def crop_at(cx, cy, label, three=True):
    cx = int(min(max(cx, CS // 2), R - CS // 2))
    cy = int(min(max(cy, CS // 2), R - CS // 2))
    box = (cx - CS // 2, cy - CS // 2, cx + CS // 2, cy + CS // 2)
    tiles = []
    if three:
        p0 = to2d(box[0], box[1])
        p1 = to2d(box[2], box[3])
        tiles.append(img2.crop((int(p0[0]), int(p0[1]), int(p1[0]), int(p1[1]))).resize((CS, CS)))
        tiles.append(mat.crop(box))
    tiles.append(pbr.crop(box))
    w = CS * len(tiles) + 6 * (len(tiles) - 1)
    t = Image.new("RGB", (w, CS + 26), (25, 25, 28))
    for i, im in enumerate(tiles):
        t.paste(im, (i * (CS + 6), 26))
    ImageDraw.Draw(t).text((4, 3), label + ("  (2D | matte | PBR)" if three else "  (PBR)"), fill=(255, 230, 120), font=FONT)
    return t


def center(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return int(np.median(xs)), int(np.median(ys))


crops = []
door = center(mask_of("_Door"))
if door:
    crops.append(crop_at(*door, "door"))
aw = center(mask_of("_Awning"))
if aw:
    crops.append(crop_at(*aw, "awning (cloth)"))
win = mask_of("_WinPane") | mask_of("_Glass")
if win.any():
    from scipy import ndimage
    lab, n = ndimage.label(ndimage.binary_dilation(win, iterations=3))
    big = np.argmax(ndimage.sum(win, lab, range(1, n + 1))) + 1
    crops.append(crop_at(*center(lab == big), "window glass"))
# gold: top quarter of the silhouette, middle
body = np.zeros(idi.shape[:2], bool)
for k, v in ids["ids"].items():
    if "_Body_" in k:
        body |= (np.abs(idi - np.array(v)).sum(-1) < 40)
hsv = np.asarray(pbr.convert("HSV")).astype(int)
goldish = (hsv[..., 0] > 20) & (hsv[..., 0] < 45) & (hsv[..., 1] > 110) & (hsv[..., 2] > 150) & body
if goldish.any():
    # the window with the most gold pixels (box sum over a crop-sized window)
    from scipy import ndimage
    dens = ndimage.uniform_filter(goldish.astype(np.float32), size=CS)
    gy, gx = np.unravel_index(np.argmax(dens), dens.shape)
    crops.append(crop_at(int(gx), int(gy), "gold (metal)"))
stoneish = (hsv[..., 1] < 40) & (hsv[..., 2] > 170) & body
if stoneish.any():
    ys, xs = np.nonzero(stoneish)
    mid = (ys > b3[1] + 0.45 * (b3[3] - b3[1])) & (ys < b3[1] + 0.75 * (b3[3] - b3[1]))
    i = np.nonzero(mid)[0]
    i = i[len(i) // 3] if len(i) else len(ys) // 2
    crops.append(crop_at(int(xs[i]), int(ys[i]), "stone wall"))
# seams: body pixels whose right/down neighbour is another body tile
tid = np.full(idi.shape[:2], -1)
for j, (k, v) in enumerate(sorted(ids["ids"].items())):
    if "_Body_" in k:
        tid[np.abs(idi - np.array(v)).sum(-1) < 40] = j
edge = ((tid[:, :-4] >= 0) & (tid[:, 4:] >= 0) & (tid[:, :-4] != tid[:, 4:]))  # 4 px apart: the id pass is anti-aliased
ys, xs = np.nonzero(edge)
picked = []
if len(xs):
    order = np.random.RandomState(1).permutation(len(xs))
    for i in order:
        if all(abs(xs[i] - a) + abs(ys[i] - b) > 500 for a, b in picked):
            picked.append((xs[i], ys[i]))
        if len(picked) == 2:
            break
for n, (x, y) in enumerate(picked):
    crops.append(crop_at(x, y, "tile seam %d" % (n + 1), three=False))

# row 1
H1 = 560
row = []
for im in (img2.crop(b2), mat.crop(b3), pbr.crop(b3), Image.open(os.path.join(S, "q34_pbr.png")).convert("RGB"),
           Image.open(os.path.join(S, "back_pbr.png")).convert("RGB")):
    r = H1 / im.size[1]
    row.append(im.resize((max(1, int(im.size[0] * r)), H1)))
W1 = sum(i.size[0] for i in row) + 8 * (len(row) - 1)
# crop rows: pack widths
lines, cur, cw = [], [], 0
maxw = max(W1, 1900)
for c in crops:
    if cw + c.size[0] > maxw and cur:
        lines.append(cur)
        cur, cw = [], 0
    cur.append(c)
    cw += c.size[0] + 12
if cur:
    lines.append(cur)
Wt = max(W1, max(sum(c.size[0] + 12 for c in l) for l in lines))
Ht = 40 + H1 + 20 + sum(max(c.size[1] for c in l) + 12 for l in lines) + 90
sheet = Image.new("RGB", (Wt, Ht), (18, 18, 20))
d = ImageDraw.Draw(sheet)
d.text((8, 8), "%s  —  2D | 3D matte (colour only) | 3D PBR (4 maps) | 3/4 | back" % NAME, fill=(255, 255, 255), font=FONT)
x = 0
for im in row:
    sheet.paste(im, (x, 40))
    x += im.size[0] + 8
y = 40 + H1 + 20
for l in lines:
    x = 0
    for c in l:
        sheet.paste(c, (x, y))
        x += c.size[0] + 12
    y += max(c.size[1] for c in l) + 12
parts = info["parts"]
txt1 = "size %.1f x %.1f x %.1f studs (W x H x D), door %.1f x %.1f studs, tris total %d, render %.1f px/stud" % (
    info["size_studs"][0], info["size_studs"][1], info["size_studs"][2], (info["door"] or {}).get("width", 0),
    (info["door"] or {}).get("height", 0), info["tris_total"], ids["pp_stud"])
txt2 = "parts: " + ", ".join("%s %d tris %s" % (k[len(NAME) + 1:], v.get("tris") or 0, ("%dpx" % v["tex"]) if "tex" in v else "no tex")
                            for k, v in parts.items())
d.text((8, y + 4), txt1, fill=(220, 220, 220), font=FONT)
d.text((8, y + 30), txt2[:230], fill=(220, 220, 220), font=FONT)
d.text((8, y + 56), "maps per textured part: Color + Normal + Roughness + Metalness (SurfaceAppearance); Glass = Studio Glass part",
       fill=(220, 220, 220), font=FONT)
sheet.save(OUT, quality=90)
print("[house_sheet] ok", OUT, sheet.size)
