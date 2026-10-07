"""
Erase a face that Tripo painted on the BACK of a model (slimes, 2026-10-07: "왜 슬라임이 앞뒤에 얼굴이 있냐"), texture
only, 0 credits. Works in screen space on a tools/castle_window_dump.py dump taken from the back view, so UV seams do not
matter, and writes the result back to the texels the rays hit.

  blender ... tools/castle_window_dump.py -- <in.glb> <dump_dir> --screen cx,cy,rx,ry --view back
  py tools/back_face_erase.py <dump_dir> <out.png> [--tex other_texture.png] [--size 1024]

- The face = dark eyes (and their white highlights), pink blush and their soft edges inside the ellipse; it is refilled
  from the body colour around it by a normalised blur (a smooth jelly gradient, no smudged features carried in).
- --tex: use another texture with the same UVs (e.g. the blue king-slime recolour); texel positions are scaled to it.
- --size: the output is saved at this size (Roblox keeps 1024 at most).
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("dump")
ap.add_argument("out")
ap.add_argument("--tex")
ap.add_argument("--size", type=int, default=1024)
a = ap.parse_args()

z = np.load(f"{a.dump}/dump.npz")
texel, valid = z["texel"], z["valid"] > 0
x0, y0, x1, y1, SS = z["box"]
cx, cy, rx, ry = z["ellipse"]
if a.tex:
    t = np.asarray(Image.open(a.tex).convert("RGB")).astype(np.float32)[::-1] / 255.0  # bottom-up like the dump
else:
    t = np.load(f"{a.dump}/tex0.npy")[..., :3].astype(np.float32)
th, tw = t.shape[:2]
k = tw / 4096.0  # the dump's texel coordinates are for the GLB's 4096 texture
tx = np.clip((texel[..., 0] * k).astype(np.int64), 0, tw - 1)
ty = np.clip((texel[..., 1] * k).astype(np.int64), 0, th - 1)
alb = t[ty, tx]
H_, W_ = valid.shape
yy, xx = np.mgrid[0:H_, 0:W_].astype(np.float32)
dn = np.sqrt(((x0 + (xx + 0.5) / SS - cx) / rx) ** 2 + ((y0 + (yy + 0.5) / SS - cy) / ry) ** 2)
R, G, B = alb[..., 0], alb[..., 1], alb[..., 2]
lum = 0.2126 * R + 0.7152 * G + 0.0722 * B
dark = (lum < 0.22) & valid
pink = (R - np.maximum(G, B) > 0.12) & (R > 0.55) & valid
# everything that is not the smooth jelly body: compare with a wide blur of the body-coloured samples (catches the eye
# catch-lights, eye rims and blush edges that a colour rule misses)
body = (valid & ~dark & ~pink & (dn <= 1.8)).astype(np.float32)
guess = cv2.GaussianBlur(alb * body[..., None], (0, 0), SS * 12) / np.maximum(cv2.GaussianBlur(body, (0, 0), SS * 12), 1e-4)[..., None]
odd = (np.sqrt(((alb - guess) ** 2).sum(-1)) > 0.06) & valid
face = (dark | pink | odd) & (dn <= 1.0)
hole = (cv2.dilate(face.astype(np.uint8), np.ones((int(5 * SS) + 1,) * 2, np.uint8)) > 0) & valid & (dn <= 1.15)
known = (valid & ~hole & (dn <= 1.8)).astype(np.float32)
filled = alb.copy()
have = np.zeros(hole.shape, bool)
for sig in (3.0, 6.0, 12.0, 24.0):
    num = cv2.GaussianBlur(alb * known[..., None], (0, 0), SS * sig)
    den = cv2.GaussianBlur(known, (0, 0), SS * sig)
    ok = hole & (den > 1e-3) & ~have
    filled[ok] = num[ok] / den[ok][:, None]
    have |= ok
w = np.clip(cv2.GaussianBlur(hole.astype(np.float32), (0, 0), SS * 0.8), 0, 1) * valid
out = t.copy().astype(np.float64)
acc = np.zeros((th, tw, 3))
wsum = np.zeros((th, tw))
cnt = np.zeros((th, tw))
vy, vx = np.nonzero(valid)
np.add.at(acc, (ty[vy, vx], tx[vy, vx]), filled[vy, vx] * w[vy, vx, None])
np.add.at(wsum, (ty[vy, vx], tx[vy, vx]), w[vy, vx])
np.add.at(cnt, (ty[vy, vx], tx[vy, vx]), 1)
m = (cnt > 0) & (wsum > 1e-6)
aa = np.zeros_like(wsum)
aa[m] = wsum[m] / cnt[m]
col = np.zeros_like(acc)
col[m] = acc[m] / wsum[m][:, None]
out[m] = out[m] * (1 - aa[m, None]) + col[m] * aa[m, None]
img = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)[::-1])
if img.size[0] != a.size:
    img = img.resize((a.size, a.size), Image.LANCZOS)
img.save(a.out)
vis = alb * (1 - w[..., None]) + filled * w[..., None]
Image.fromarray((np.clip(vis, 0, 1) * 255).astype(np.uint8)).save(a.out.rsplit(".", 1)[0] + "_screen.png")
print(f"face samples {int(face.sum())}, hole {int(hole.sum())}, texels written {int(m.sum())} -> {a.out}")
