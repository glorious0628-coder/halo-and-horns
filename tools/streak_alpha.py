"""streak_alpha.py (이미지 생성 1, 2026-10-11): a white-on-black streak texture -> a white PNG with alpha from brightness.
Beam textures in Roblox are tinted by Beam.Color, so the colour is kept (pale aqua stays) and only the black turns see-through.
usage: py tools/streak_alpha.py <in.png> <out.png> [--size 512] [--lo 0.08] [--hi 0.68]
"""
import argparse
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--size", type=int, default=512)
ap.add_argument("--lo", type=float, default=0.08)
ap.add_argument("--hi", type=float, default=0.68)
a = ap.parse_args()

im = Image.open(a.src).convert("RGB")
if a.size and im.width != a.size:
    im = im.resize((a.size, a.size), Image.LANCZOS)
rgb = np.asarray(im).astype(np.float32) / 255.0
lum = rgb.max(axis=2)
alpha = np.clip((lum - a.lo) / (a.hi - a.lo), 0, 1)
# un-premultiply against black so edges stay light instead of grey
col = np.where(alpha[..., None] > 0.01, np.clip(rgb / np.maximum(alpha[..., None], 0.01), 0, 1), 1.0)
out = np.dstack([col, alpha])
Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(a.out)
print(f"[streak_alpha] {a.out} {im.size} alpha mean {alpha.mean():.3f} opaque {(alpha > 0.95).mean():.3f}")
