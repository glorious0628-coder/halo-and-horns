"""Front-image regions for the Halo houses/shops (이미지 생성 3, 2026-10-10, A23-106/107: door, awning, glass as own parts).

  py tools/house_regions.py <jobs.json> <out.json> <sheet_dir> [--awning name=u0,v0,u1,v1 ...]

jobs.json: {name: {"front": png, ...}} (the Tripo inputs). For each front image (grey background):
- silhouette box = pixels that differ from the corner grey;
- door = the largest brown blob in the lower 65 % near the middle (auto);
- awning = a box given by hand (--awning, from the grid sheet) or "none".
Coordinates are normalised to the silhouette box: u = 0 left .. 1 right, v = 0 bottom .. 1 top (front view).
The sheet (<sheet_dir>/regions_<i>.jpg) draws the boxes on a 0.1 grid so they can be checked by eye.
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

jobs = json.load(open(sys.argv[1], encoding="utf-8"))
OUT, SHEET = sys.argv[2], sys.argv[3]
awn = {}
for a in sys.argv[4:]:
    if "=" in a:
        k, v = a.split("=")
        awn[k] = None if v == "none" else [float(x) for x in v.split(",")]
prev = json.load(open(OUT, encoding="utf-8")) if len(sys.argv) > 4 and __import__("os").path.exists(OUT) else {}

res = {}
tiles = []
for name, j in jobs.items():
    im = Image.open(j["front"]).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    bg = np.median(np.concatenate([a[:20, :20].reshape(-1, 3), a[:20, -20:].reshape(-1, 3)]), 0)
    sil = np.abs(a - bg).max(-1) > 18
    sil = ndimage.binary_opening(sil, iterations=2)
    lab, n = ndimage.label(sil)
    big = np.argmax(ndimage.sum(sil, lab, range(1, n + 1))) + 1
    ys, xs = np.nonzero(lab == big)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255
    h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    brown = (h >= 12) & (h <= 40) & (s >= 0.38) & (v >= 0.22) & (v <= 0.78)
    brown = ndimage.binary_closing(brown, iterations=3)
    lab2, n2 = ndimage.label(brown)
    best, bestsz = None, 0
    W = x1 - x0
    for i, sl in enumerate(ndimage.find_objects(lab2), 1):
        sz = (lab2[sl] == i).sum()
        cy = (sl[0].start + sl[0].stop) / 2
        if sz < 1500 or (cy - y0) / (y1 - y0) < 0.35:
            continue
        hgt = sl[0].stop - sl[0].start
        wid = sl[1].stop - sl[1].start
        if hgt < wid * 1.1:  # doors are tall
            continue
        if sz > bestsz:
            best, bestsz = sl, sz
    door = None
    if best is not None:
        door = [(best[1].start - x0) / W, 1 - (best[0].stop - y0) / (y1 - y0), (best[1].stop - x0) / W,
                1 - (best[0].start - y0) / (y1 - y0)]
    aw = awn.get(name, prev.get(name, {}).get("awning"))
    res[name] = {"sil_px": [int(x0), int(y0), int(x1), int(y1)], "door": door, "awning": aw}
    d = ImageDraw.Draw(im)
    for k in range(11):
        d.line([(x0 + W * k / 10, y0), (x0 + W * k / 10, y1)], fill=(255, 0, 255) if k % 5 == 0 else (120, 0, 120), width=1)
        yy = y1 - (y1 - y0) * k / 10
        d.line([(x0, yy), (x1, yy)], fill=(255, 0, 255) if k % 5 == 0 else (120, 0, 120), width=1)

    def box(b, col):
        if b:
            d.rectangle([x0 + b[0] * W, y1 - b[3] * (y1 - y0), x0 + b[2] * W, y1 - b[1] * (y1 - y0)], outline=col, width=4)

    box(door, (255, 60, 0))
    box(aw, (0, 220, 255))
    d.text((x0 + 4, y0 + 4), name, fill=(255, 255, 255))
    tiles.append(im.resize((512, 512)))
    print(name, "door", None if door is None else [round(x, 3) for x in door], "awning", aw)
json.dump(res, open(OUT, "w", encoding="utf-8"), indent=1)
for i in range(0, len(tiles), 8):
    sub = tiles[i:i + 8]
    S = Image.new("RGB", (2048, 1024), "black")
    for k, t in enumerate(sub):
        S.paste(t, ((k % 4) * 512, (k // 4) * 512))
    S.save(f"{SHEET}/regions_{i // 8}.jpg", quality=88)
