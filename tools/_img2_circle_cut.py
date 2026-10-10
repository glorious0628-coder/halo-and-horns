"""Cut a perfectly round top-down medallion (on flat gray) into a square transparent PNG with a smooth circular edge.
py tools/_img2_circle_cut.py <in.png> <out.png> [size=1024]
Finds the circle from the pixels that differ from the corner background color, then applies an anti-aliased circular mask."""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(int)
bg = np.median(np.concatenate([a[:8, :8].reshape(-1, 3), a[:8, -8:].reshape(-1, 3), a[-8:, :8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)]), axis=0)
diff = np.abs(a - bg).sum(axis=2) > 40
ys, xs = np.where(diff)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
r = min(x1 - x0, y1 - y0) / 2 - 2
S = 4
mask = Image.new("L", (im.width * S, im.height * S), 0)
ImageDraw.Draw(mask).ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)
mask = mask.resize(im.size, Image.LANCZOS)
rgba = im.copy(); rgba.putalpha(mask)
box = (int(cx - r) - 2, int(cy - r) - 2, int(cx + r) + 3, int(cy + r) + 3)
rgba = rgba.crop(box).resize((size, size), Image.LANCZOS)
rgba.save(dst)
print("bg", bg, "circle", round(cx), round(cy), round(r), "->", dst)
