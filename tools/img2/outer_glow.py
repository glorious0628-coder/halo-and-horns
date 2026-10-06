"""Add a soft colored outer glow behind an RGBA icon (same canvas size).

py outer_glow.py <in.png> <out.png> --color 255,200,60 [--grow 10 --blur 9 --alpha 0.85]
Used to make the top rank badge (R5) stand out at 24 px. Check the margin: the glow must not touch the canvas edge.
"""
import argparse

import numpy as np
from PIL import Image, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--color", default="255,200,60")
ap.add_argument("--grow", type=int, default=10)
ap.add_argument("--blur", type=float, default=9.0)
ap.add_argument("--alpha", type=float, default=0.85)
a = ap.parse_args()

im = Image.open(a.src).convert("RGBA")
mask = im.getchannel("A").point(lambda v: 255 if v > 40 else 0)
mask = mask.filter(ImageFilter.MaxFilter(a.grow * 2 + 1)).filter(ImageFilter.GaussianBlur(a.blur))
mask = mask.point(lambda v: int(v * a.alpha))
rgb = tuple(int(c) for c in a.color.split(","))
glow = Image.new("RGBA", im.size, rgb + (0,))
glow.putalpha(mask)
glow.alpha_composite(im)
arr = np.asarray(glow)[..., 3]
edge = max(arr[0].max(), arr[-1].max(), arr[:, 0].max(), arr[:, -1].max())
glow.save(a.out)
print(f"{a.out}: glow {a.color}, edge alpha {edge}")
