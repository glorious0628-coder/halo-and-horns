"""
Step 2 of tools/castle_window_dump.py: inpaint the window in screen space and write it back to the texture.

  py tools/castle_window_inpaint.py <dump_dir> [--grain 0.05] [--protect-red]

Reads dump.npz + tex0.npy, fills the ellipse with OpenCV Telea inpainting of the surrounding wall (in sRGB),
adds a little stone grain, and writes every filled screen sample back to the texel it hit (soft edge).
Writes <dump_dir>/tex_after.png (top-down sRGB, same size as the model texture).
"""
import sys

import cv2
import numpy as np
from PIL import Image

D = sys.argv[1]
GRAIN = float(sys.argv[sys.argv.index("--grain") + 1]) if "--grain" in sys.argv else 0.05
PROTECT_RED = "--protect-red" in sys.argv  # keep strongly red texels (roofs, banners) and keep them out of the fill
z = np.load(f"{D}/dump.npz")
texel, alb, valid = z["texel"], z["alb"], z["valid"]
x0, y0, x1, y1, SS = z["box"]
cx, cy, rx, ry = z["ellipse"]
px = np.load(f"{D}/tex0.npy")  # bottom-up, float 0..1 (Blender image pixels are already the stored colour)
H_, W_ = valid.shape
yy, xx = np.mgrid[0:H_, 0:W_].astype(np.float32)
dn = np.sqrt(((x0 + (xx + 0.5) / SS - cx) / rx) ** 2 + ((y0 + (yy + 0.5) / SS - cy) / ry) ** 2)
# protect red/orange only around the window (a roof or banner next to it); the window's own orange frame inside
# the ellipse is painted over like the rest
red = ((alb[..., 0] - alb[..., 1] > 0.22) & (alb[..., 0] > 0.35) & (dn > 0.9)) if PROTECT_RED else np.zeros(valid.shape, bool)
hole = ((dn <= 1.0) & (valid > 0) & ~red).astype(np.uint8)
img8 = np.clip(alb * 255, 0, 255).astype(np.uint8)
# samples that missed the model (sky) are also "holes" for the inpaint source, so they never bleed in
src_mask = (hole | (valid == 0) | red).astype(np.uint8) * 255
filled = cv2.inpaint(img8, src_mask, 9, cv2.INPAINT_TELEA).astype(np.float32)
grain = cv2.GaussianBlur(np.random.default_rng(3).normal(0, 1, (H_, W_)).astype(np.float32), (0, 0), float(SS) * 0.6)
filled = np.clip(filled * (1 + GRAIN * grain[..., None]), 0, 255) / 255.0
w = np.clip((1.15 - dn) / 0.15, 0, 1) * (valid > 0) * (~red)
th, tw = px.shape[:2]
acc = np.zeros((th, tw, 3), np.float64)
wsum = np.zeros((th, tw), np.float64)
cnt = np.zeros((th, tw), np.float64)
ys, xs = np.nonzero(valid)
for j, i in zip(ys, xs):
    tx, ty = texel[j, i]
    acc[ty, tx] += filled[j, i] * w[j, i]
    wsum[ty, tx] += w[j, i]
    cnt[ty, tx] += 1
out = px[..., :3].astype(np.float64).copy()
m = cnt > 0
a = np.zeros_like(wsum)
a[m] = wsum[m] / cnt[m]
col = np.zeros_like(acc)
col[m] = acc[m] / np.maximum(wsum[m], 1e-9)[:, None]
out[m] = out[m] * (1 - a[m, None]) + col[m] * a[m, None]
# fill single-texel gaps between written texels from their neighbours
mm = (a > 0).astype(np.uint8)
closed = cv2.morphologyEx(mm, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0
gaps = closed & (mm == 0)
if gaps.any():
    k = np.ones((3, 3), np.float32)
    wn = cv2.filter2D(mm.astype(np.float32), -1, k)
    for c in range(3):
        cn = cv2.filter2D((out[..., c] * mm).astype(np.float32), -1, k)
        out[..., c] = np.where(gaps, cn / np.maximum(wn, 1e-6), out[..., c])
img = (np.clip(out, 0, 1) * 255).astype(np.uint8)[::-1]  # to top-down
Image.fromarray(img).save(f"{D}/tex_after.png")
print(f"texels written {int(m.sum())}, gaps filled {int(gaps.sum())} -> {D}/tex_after.png")
