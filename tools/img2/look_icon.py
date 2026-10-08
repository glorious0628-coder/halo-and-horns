"""Shop / attendance cosmetic icon from a transparent 3D render (0 credits): trim, square (subject at --fill), resize to
512 and put our UI-icon dark navy outline around the silhouette (anti-aliased, from a distance transform), so a pale
platinum halo still reads on a light panel.

  py tools/img2/look_icon.py <render.png> <out.png> [--fill 0.84] [--outline 11] [--size 512]
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--fill", type=float, default=0.84)
ap.add_argument("--outline", type=float, default=11.0, help="outline width in px at the output size")
ap.add_argument("--size", type=int, default=512)
args = ap.parse_args()

NAVY = np.array([22, 28, 62], np.float32)
im = Image.open(args.src).convert("RGBA")
a = np.asarray(im)[..., 3]
ys, xs = np.where(a > 8)
c = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
N = args.size
side = int(max(c.size) / args.fill)
sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
sq.alpha_composite(c, ((side - c.width) // 2, (side - c.height) // 2))
sq = np.asarray(sq.resize((N, N), Image.LANCZOS)).astype(np.float32) / 255
rgb, al = sq[..., :3], sq[..., 3]
# distance (px) from the silhouette -> outline alpha with a 1 px soft edge; inner holes (between horns) are filled too
dist = cv2.distanceTransform((al < 0.5).astype(np.uint8), cv2.DIST_L2, 5)
ol = np.clip(args.outline + 0.5 - dist, 0, 1)
out_a = np.maximum(al, ol)
out_rgb = (rgb * al[..., None] + NAVY / 255 * (ol * (1 - al))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
res = np.concatenate([out_rgb, out_a[..., None]], -1)
Image.fromarray((res.clip(0, 1) * 255).round().astype(np.uint8), "RGBA").save(args.out)
print(args.out, c.size)
