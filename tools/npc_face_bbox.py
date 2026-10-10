"""Silhouette box of a character on a flat grey 2D sheet (for tools/npc_face.py).  py tools/npc_face_bbox.py <front.png> -> x0,y0,x1,y1,W,H"""
import sys
import numpy as np
from PIL import Image
im = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(int)
H, W, _ = im.shape
c = np.median(np.concatenate([im[:8, :8].reshape(-1, 3), im[:8, -8:].reshape(-1, 3), im[-8:, :8].reshape(-1, 3), im[-8:, -8:].reshape(-1, 3)]), axis=0)
m = np.abs(im - c).sum(-1) > 40
ys, xs = np.nonzero(m)
print(f"{xs.min()},{ys.min()},{xs.max()},{ys.max()},{W},{H}")
