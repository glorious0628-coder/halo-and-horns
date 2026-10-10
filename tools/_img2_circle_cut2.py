"""Circle cut for badges whose subject pokes past the rim: circle fitted from left/right/bottom extents (top is unreliable);
pixels outside the circle that differ strongly from the background (the poking halo/hilt) are kept.
py tools/_img2_circle_cut2.py <in.png> <out.png> [size=512] [keep_poke=1]"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 512
keep = (sys.argv[4] != "0") if len(sys.argv) > 4 else True
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(int)
bg = np.median(np.concatenate([a[:8, :8].reshape(-1, 3), a[:8, -8:].reshape(-1, 3), a[-8:, :8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)]), axis=0)
d = np.abs(a - bg).sum(axis=2) > 150
ys, xs = np.where(d)
x0, x1, y1 = xs.min(), xs.max(), ys.max()
r = (x1 - x0) / 2 - 1
cx = (x0 + x1) / 2
cy = y1 - r - 1
S = 4
m = Image.new("L", (im.width * S, im.height * S), 0)
ImageDraw.Draw(m).ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=255)
m = m.resize(im.size, Image.LANCZOS)
if keep:
    strong = Image.fromarray(((np.abs(a - bg).sum(axis=2) > 150) * 255).astype("uint8"))
    strong = strong.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MaxFilter(3))
    yy = np.arange(im.height)[:, None] < cy
    strong = Image.fromarray(np.where(yy, np.asarray(strong), 0).astype("uint8")).filter(ImageFilter.GaussianBlur(0.8))
    m = Image.fromarray(np.maximum(np.asarray(m), np.asarray(strong)))
o = im.copy(); o.putalpha(m)
bb = m.point(lambda v: 255 if v > 8 else 0).getbbox()
side = max(bb[2] - bb[0], bb[3] - bb[1]) + 6
ccx, ccy = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
o = o.crop((int(ccx - side / 2), int(ccy - side / 2), int(ccx + side / 2), int(ccy + side / 2))).resize((size, size), Image.LANCZOS)
o.save(dst); print(round(cx), round(cy), round(r), bb)
