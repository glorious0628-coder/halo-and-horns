"""Face mask for tools/npc_face.py (이미지 생성 1, 2026-10-10): the 2D front is projected only on the face skin, not on helmets/hair
(their 3D shape does not line up with the 2D, which smeared grilles and hair strands).

  py tools/npc_face_mask.py <front_2d.png> <bbox x0,y0,x1,y1,W,H> <out_mask.png> [--grow 10] [--feather 6]

Skin = warm, light, not too saturated pixels in the upper 45 % of the silhouette box; the biggest connected blob is the face.
Holes inside it (eyes, mouth, moustache) are filled, then the blob is grown by --grow px and feathered by --feather px.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

a = sys.argv[1:]
src, bb, out = a[0], [int(float(v)) for v in a[1].split(",")], a[2]
opt = {"grow": 10, "feather": 6}
for i in range(3, len(a), 2):
    opt[a[i][2:]] = int(a[i + 1])
im = Image.open(src).convert("RGB")
hsv = np.asarray(im.convert("HSV")).astype(np.float32)
h, s, v = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
skin = (h >= 8) & (h <= 40) & (s >= 0.12) & (s <= 0.5) & (v >= 0.62)
x0, y0, x1, y1 = bb[:4]
area = np.zeros_like(skin)
area[y0:y0 + int((y1 - y0) * 0.45), x0:x1] = True
skin &= area
skin = ndimage.binary_opening(skin, iterations=2)
lab, n = ndimage.label(skin)
if n == 0:
    sys.exit("no skin found")
big = np.argmax(ndimage.sum(skin, lab, range(1, n + 1))) + 1
face = ndimage.binary_fill_holes(lab == big)
# close gaps at the edge (smile/moustache touching the border) before filling again
face = ndimage.binary_fill_holes(ndimage.binary_closing(face, iterations=12))
face = ndimage.binary_dilation(face, iterations=opt["grow"])
m = Image.fromarray((face * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(opt["feather"]))
m.save(out)
ys, xs = np.nonzero(face)
print("face box", xs.min(), ys.min(), xs.max(), ys.max())
