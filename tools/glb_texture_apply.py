"""
Apply projected decal hits (from tools/glb_texture_patch.py project) to a texture.

  py tools/glb_texture_apply.py <tex.png> <hits.npy> <out.png> --mode decal
  py tools/glb_texture_apply.py <tex.png> <hits.npy> <out.png> --mode fill --color 90,68,77 [--noise 0.08] [--only-glow]

- hits rows: (tx, ty, r, g, b, a) with r, g, b, a in 0..1 (decal colour and alpha at that screen sample).
- decal: texel colour = average decal colour, blended by average alpha.
- fill: texel colour = --color with soft low-frequency noise (for painting a window over with plain stone),
  blended by average alpha.
- Small holes between hit texels are closed (3x3) and filled from their neighbours.
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("tex")
ap.add_argument("hits")
ap.add_argument("out")
ap.add_argument("--mode", choices=["decal", "fill"], required=True)
ap.add_argument("--color", default="90,68,77")
ap.add_argument("--noise", type=float, default=0.08)
ap.add_argument("--only-glow", action="store_true", help="touch only bright orange/yellow texels (left-over window glow)")
args = ap.parse_args()

tex = np.asarray(Image.open(args.tex).convert("RGB")).astype(np.float32)
H, W = tex.shape[:2]
h = np.load(args.hits)
tx = np.clip(h[:, 0].astype(np.int64), 0, W - 1)
ty = np.clip(h[:, 1].astype(np.int64), 0, H - 1)
idx = ty * W + tx
cnt = np.bincount(idx, minlength=H * W).astype(np.float32).reshape(H, W)
asum = np.bincount(idx, weights=h[:, 5], minlength=H * W).astype(np.float32).reshape(H, W)
col = np.zeros((H, W, 3), np.float32)
for c in range(3):
    col[..., c] = np.bincount(idx, weights=h[:, 2 + c] * h[:, 5], minlength=H * W).reshape(H, W)
hit = cnt > 0
a = np.where(hit, asum / np.maximum(cnt, 1), 0)
col = np.where(hit[..., None], col / np.maximum(asum, 1e-6)[..., None], 0) * 255.0

# close 1-texel holes between hits and fill them from neighbours
m8 = hit.astype(np.uint8)
closed = cv2.morphologyEx(m8, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0
holes = closed & ~hit
k = np.ones((3, 3), np.float32)
wn = cv2.filter2D(m8.astype(np.float32), -1, k, borderType=cv2.BORDER_CONSTANT)
an = cv2.filter2D(a * m8, -1, k, borderType=cv2.BORDER_CONSTANT)
a = np.where(holes, an / np.maximum(wn, 1e-6), a)
for c in range(3):
    cn = cv2.filter2D(col[..., c] * m8, -1, k, borderType=cv2.BORDER_CONSTANT)
    col[..., c] = np.where(holes, cn / np.maximum(wn, 1e-6), col[..., c])
region = hit | holes
if args.only_glow:
    R, G, B = tex[..., 0], tex[..., 1], tex[..., 2]
    glow = (R > 150) & (G > 80) & (R - B > 60)
    glow = cv2.dilate(glow.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    region = region & glow
    a = np.where(region, 1.0, 0.0).astype(np.float32)

if args.mode == "fill":
    base = np.array([float(v) for v in args.color.split(",")], np.float32)
    rng = np.random.default_rng(11)
    small = rng.normal(0, 1, (H // 32, W // 32)).astype(np.float32)
    noise = cv2.resize(small, (W, H), interpolation=cv2.INTER_CUBIC)
    fine = cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 1.2)
    col = base[None, None, :] * (1 + args.noise * noise[..., None] + 0.03 * fine[..., None])

out = tex.copy()
aa = a[..., None]
out = np.where(region[..., None], tex * (1 - aa) + col * aa, tex)
Image.fromarray(out.clip(0, 255).astype(np.uint8)).save(args.out)
print(f"texels written {int(region.sum())} (holes filled {int(holes.sum())}) -> {args.out}")
