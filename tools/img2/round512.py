"""Round badge -> 512 x 512 PNG: find the badge disc on the flat grey background (largest non-grey blob), crop a square
around it so the disc fills the frame, and make the corners transparent with an anti-aliased circle (no cutout of the
art itself). Used for game-pass icons and Roblox badges (Roblox shows them as circles).

  py tools/img2/round512.py <src.png> <out.png> [--size 512]
"""
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
N = int(sys.argv[sys.argv.index("--size") + 1]) if "--size" in sys.argv else 512
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(int)
c = np.median(np.concatenate([a[:10, :10].reshape(-1, 3), a[:10, -10:].reshape(-1, 3), a[-10:, :10].reshape(-1, 3), a[-10:, -10:].reshape(-1, 3)]), 0)
m = ndimage.binary_opening(np.abs(a - c).max(-1) > 24, iterations=2)
lab, k = ndimage.label(m)
big = lab == (np.argmax(ndimage.sum(m, lab, range(1, k + 1))) + 1)
ys, xs = np.where(big)
cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
r = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 + 2
sq = im.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r))).resize((N, N), Image.LANCZOS).convert("RGBA")
S = 4
mask = Image.new("L", (N * S, N * S), 0)
ImageDraw.Draw(mask).ellipse((2 * S, 2 * S, (N - 2) * S, (N - 2) * S), fill=255)
sq.putalpha(mask.resize((N, N), Image.LANCZOS))
sq.save(out)
print(out, (int(cx), int(cy), int(r)))
