"""Measure text regions of a blank faction/class card cutout -> fractions {x, y, w, h} + overlay png.

py measure_card.py <card.png> <kind faction|class> <accent halo|horns|artisan> <overlay.png>
Cream panels are found by colour; the ribbon/button by the faction accent colour.
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

path, kind, accent, out = sys.argv[1:5]
im = Image.open(path).convert("RGBA")
a = np.asarray(im).astype(int)
H, W = a.shape[:2]
r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
solid = al > 250


def comps(mask, min_frac=0.004):
    mask = ndimage.binary_opening(mask, iterations=2)
    lab, n = ndimage.label(mask)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        area = int((lab[sl] == i).sum())
        if area >= min_frac * W * H:
            out.append((sl[0].start, sl[0].stop, sl[1].start, sl[1].stop, area))
    return out


cream = solid & (r > 205) & (g > 190) & (b > 150) & (r - b < 75) & (r - b > 8)
if accent == "halo":
    acc = solid & (b > r + 50) & (b > 170)            # sky blue ribbon
    btn = solid & (r > 200) & (g > 150) & (b < 90)    # gold button
elif accent == "horns":
    acc = solid & (r > 140) & (g < 70) & (b < 80)     # crimson ribbon / button
    btn = acc
else:
    acc = solid & (g > 90) & (b > 90) & (r < 70)      # teal ribbon / button
    btn = acc

cr = sorted(comps(cream), key=lambda c: c[0])
ac = sorted(comps(acc), key=lambda c: c[0])
bt = sorted(comps(btn), key=lambda c: c[0])


def frac(c, inset=0.0):
    y0, y1, x0, x1 = c[:4]
    dx, dy = (x1 - x0) * inset, (y1 - y0) * inset
    return [round((x0 + dx) / W, 3), round((y0 + dy) / H, 3), round((x1 - x0 - 2 * dx) / W, 3), round((y1 - y0 - 2 * dy) / H, 3)]


res = {"Aspect": round(W / H, 3), "Size": [W, H]}
if kind == "faction":
    # cream: strip1 (Desc), strip2 (Motto), big panel (Perks); ribbon = first accent comp; button = last btn comp
    big = [c for c in cr if (c[1] - c[0]) * (c[3] - c[2]) > 0.02 * W * H]
    res["Desc"] = frac(big[0], 0.04)
    res["Motto"] = frac(big[1], 0.04)
    res["Perks"] = frac(big[2], 0.04)
    above = [c for c in ac if c[1] <= big[0][0] + 2]
    rib = max(above, key=lambda c: c[3] - c[2])
    y0, y1, x0, x1 = rib[:4]
    ix = int((x1 - x0) * 0.12)
    res["Title"] = frac((y0, y1, x0 + ix, x1 - ix), 0.0)
    res["Button"] = frac(bt[-1], 0.06)
else:
    big = [c for c in cr if (c[1] - c[0]) * (c[3] - c[2]) > 0.02 * W * H]
    body = max([c for c in big if c[0] > H * 0.5], key=lambda c: (c[1] - c[0]) * (c[3] - c[2]))
    big = [body]
    res["Body"] = frac(body, 0.05)
    if accent == "halo":
        ribm = solid & (b > r + 100) & (b > 180)
        win = solid & (b > r + 25) & (b > 200) & (r > 120)
    elif accent == "horns":
        ribm = acc
        win = solid & (r > 110) & (r < 215) & (b > 100) & (g < r - 8) & (g > 80) & (b > g)
    else:
        ribm = acc
        win = solid & (g > 170) & (b > 170) & (r < g - 25) & (r > 100)
    rc = [c for c in comps(ribm) if c[0] < big[-1][0]]
    rib = max(rc, key=lambda c: c[3] - c[2])
    y0, y1, x0, x1 = rib[:4]
    ix = int((x1 - x0) * 0.12)
    res["Name"] = frac((y0, y1, x0 + ix, x1 - ix), 0.0)
    res["Button"] = frac(bt[-1], 0.06)
    wc = sorted(comps(win, 0.03), key=lambda c: -c[4])
    if wc:
        res["Portrait"] = frac(wc[0], 0.02)

ov = im.copy()
d = ImageDraw.Draw(ov)
cols = {"Title": "red", "Name": "red", "Desc": "blue", "Motto": "green", "Perks": "magenta", "Body": "magenta",
        "Button": "orange", "Portrait": "cyan"}
for k, v in res.items():
    if k in cols:
        x, y, w, h = v
        d.rectangle([x * W, y * H, (x + w) * W, (y + h) * H], outline=cols[k], width=4)
        d.text((x * W + 6, y * H + 4), k, fill=cols[k])
bg = Image.new("RGBA", ov.size, (40, 40, 60, 255))
bg.alpha_composite(ov)
bg.convert("RGB").save(out)
print(json.dumps(res))
