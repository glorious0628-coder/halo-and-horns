"""Glow / sparkle drawn white on black -> pure white PNG whose alpha is the brightness (tinted in code with ImageColor3).

py lum_alpha.py <src> <out> [--size 512 --black 12 --gamma 1.0 --pad 0.04 --center]
- black: brightness at or below this is fully transparent (kills the JPEG-ish noise of the black background).
- the result is cropped square around the light (bbox of alpha > 2), padded, and resized to --size.
- --center puts the brightest point (or the alpha centroid) in the middle of the square so a rotating glow does not wobble.
"""
import argparse

import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--size", type=int, default=512)
ap.add_argument("--black", type=float, default=12.0)
ap.add_argument("--gamma", type=float, default=1.0)
ap.add_argument("--pad", type=float, default=0.04)
ap.add_argument("--center", action="store_true")
a = ap.parse_args()

im = np.asarray(Image.open(a.src).convert("RGB")).astype(np.float32)
lum = im.max(axis=2)  # brightest channel: a warm-tinted glow still keeps its full strength
al = np.clip((lum - a.black) / max(1.0, lum.max() - a.black), 0, 1) ** a.gamma
H, W = al.shape
ys, xs = np.nonzero(al > 2 / 255)
if a.center:
    wsum = al.sum()
    cy, cx = (al * np.arange(H)[:, None]).sum() / wsum, (al * np.arange(W)[None, :]).sum() / wsum
    r = max(cx - xs.min(), xs.max() - cx, cy - ys.min(), ys.max() - cy)
    x0, y0, x1, y1 = cx - r, cy - r, cx + r, cy + r
else:
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    s = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    x0, y0, x1, y1 = cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2
side = (x1 - x0) * (1 + 2 * a.pad)
cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
box = (int(round(cx - side / 2)), int(round(cy - side / 2)), int(round(cx + side / 2)), int(round(cy + side / 2)))
A = Image.fromarray((al * 255).astype(np.uint8), "L").crop(box).resize((a.size, a.size), Image.LANCZOS)
out = Image.new("RGBA", (a.size, a.size), (255, 255, 255, 0))
out.putalpha(A)
out.save(a.out)
edge = np.asarray(A).astype(int)
print(f"{a.out} {a.size}x{a.size} box {box} max alpha {edge.max()} edge max alpha {max(edge[0].max(), edge[-1].max(), edge[:, 0].max(), edge[:, -1].max())}")
