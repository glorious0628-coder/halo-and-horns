"""Grade-slot cutout normalised so every sibling's square body lands on the same pixels.

py cut_slot.py <src> <out> [--canvas 512 --body 440 --top 48]
Body = rows/cols whose alpha run is >= 70% of the widest (ignores the small top ornament).
Prints body box and the dark inner rect (for icon placement) in output pixels.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from cutout_flat import cutout, edge_fix  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--canvas", type=int, default=512)
ap.add_argument("--body", type=int, default=440)
ap.add_argument("--top", type=int, default=48)
a = ap.parse_args()

im = cutout(a.src, 48.0, 10.0, True, hole_tol=5.0)
arr = np.asarray(im).copy()
al = arr[..., 3]
lab, n = ndimage.label(al > 0, structure=np.ones((3, 3)))
if n > 1:
    sizes = ndimage.sum(np.ones_like(al), lab, range(1, n + 1))
    drop = [i + 1 for i, s in enumerate(sizes) if s < sizes.max() * 0.002]
    arr[np.isin(lab, drop), 3] = 0
im = Image.fromarray(arr, "RGBA")
al = np.asarray(im.getchannel("A")) > 128
rows = al.sum(axis=1)
cols = al.sum(axis=0)
ry = np.where(rows >= rows.max() * 0.7)[0]
cx = np.where(cols >= cols.max() * 0.7)[0]
by0, by1, bx0, bx1 = ry.min(), ry.max() + 1, cx.min(), cx.max() + 1
bw, bh = bx1 - bx0, by1 - by0
s = a.body / bw
sy = a.body / bh  # square body: tiny non-uniform fix (siblings differ by a few %)
print(f"  body aspect fix: x{s:.3f} y{sy:.3f} ({abs(sy / s - 1) * 100:.1f}%)")
im2 = im.resize((round(im.width * s), round(im.height * sy)), Image.LANCZOS)
ox = (a.canvas - a.body) // 2 - round(bx0 * s)
oy = a.top - round(by0 * sy)
canvas = Image.new("RGBA", (a.canvas, a.canvas), (0, 0, 0, 0))
canvas.alpha_composite(im2, (ox, oy)) if ox >= 0 and oy >= 0 else canvas.paste(im2, (ox, oy), im2)
canvas, _ = edge_fix(canvas)
canvas.save(a.out)
c = np.asarray(canvas).astype(int)
bb = canvas.getchannel("A").getbbox()
# dark inner: pixels with max channel < 70 and alpha 255, largest component
dark = (c[..., :3].max(axis=2) < 70) & (c[..., 3] == 255)
dark = ndimage.binary_erosion(dark, iterations=3)
lab2, n2 = ndimage.label(dark)
inner = None
if n2:
    sz = ndimage.sum(np.ones(dark.shape), lab2, range(1, n2 + 1))
    k = int(np.argmax(sz)) + 1
    sl = ndimage.find_objects(lab2)[k - 1]
    inner = [sl[1].start, sl[0].start, sl[1].stop, sl[0].stop]
body = [(a.canvas - a.body) // 2, a.top, (a.canvas - a.body) // 2 + a.body, a.top + a.body]
print(f"{a.out}: alpha bbox {bb}, body {body}, inner {inner}, top overflow {bb[1] if bb else None}")
