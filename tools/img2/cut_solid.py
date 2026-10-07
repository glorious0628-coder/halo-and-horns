"""Cutout for props with pale stone/shadows close to the gray backdrop: no bites, no pin holes.

py cut_solid.py <src> <out> [--tol 12 --soft 5 --close 3 --gap-min 300 --gap-tol 10]
1. tools/cutout_flat.cutout (flood from the border only, no hole clearing) at source size.
2. The flood can creep into the subject along dark cracks. Close the opaque mask by --close px and fill it:
   every pixel inside that solid silhouette (2 px in from the edge) that is not opaque gets alpha 255 and its
   original source colour back.
3. Real see-through gaps (between legs, pole and flag) are kept: an enclosed hole of the closed mask that is at
   least --gap-min px and whose median colour is within --gap-tol of the backdrop stays transparent.
4. Keep the largest piece (+ pieces >= 2% of it), trim to the alpha box + 2 px, no resize.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from cutout_flat import cutout  # noqa: E402


def disk(r):
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return x * x + y * y <= r * r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--tol", type=float, default=12.0)
    ap.add_argument("--soft", type=float, default=5.0)
    ap.add_argument("--close", type=int, default=3)
    ap.add_argument("--gap-min", type=int, default=300)
    ap.add_argument("--gap-tol", type=float, default=10.0)
    a = ap.parse_args()

    src = np.asarray(Image.open(a.src).convert("RGB")).astype(np.float32)
    cut = np.asarray(cutout(a.src, a.tol, a.soft, False)).copy()
    al = cut[..., 3]
    h, w = al.shape
    b = 20
    corners = np.concatenate([src[:b, :b].reshape(-1, 3), src[:b, -b:].reshape(-1, 3),
                              src[-b:, :b].reshape(-1, 3), src[-b:, -b:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((src - bg) ** 2).sum(axis=2))

    m = al > 128
    mc = ndimage.binary_closing(m, structure=disk(a.close))
    solid = ndimage.binary_fill_holes(mc)
    holes = solid & ~mc
    lab, n = ndimage.label(holes)
    kept = 0
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        reg = lab[sl] == i
        area = int(reg.sum())
        if area >= a.gap_min and float(np.median(dist[sl][reg])) <= a.gap_tol:
            solid[sl][reg] = False
            kept += 1
    interior = ndimage.binary_erosion(solid, iterations=2)
    fix = interior & (al < 250)
    cut[fix, :3] = src[fix].round().astype(np.uint8)
    cut[fix, 3] = 255

    # largest piece (+ big companions)
    lab2, n2 = ndimage.label(cut[..., 3] > 0, structure=np.ones((3, 3)))
    if n2 > 1:
        sizes = ndimage.sum(np.ones((h, w)), lab2, range(1, n2 + 1))
        big = sizes.max()
        drop = [i + 1 for i, s in enumerate(sizes) if s < big * 0.02]
        cut[np.isin(lab2, drop), 3] = 0
    im = Image.fromarray(cut, "RGBA")
    box = im.getchannel("A").getbbox()
    x0, y0, x1, y1 = box
    im = im.crop((max(0, x0 - 2), max(0, y0 - 2), min(w, x1 + 2), min(h, y1 + 2)))
    im.save(a.out)
    print(f"{os.path.basename(a.out)} {im.size} fixed {int(fix.sum())} px, see-through gaps kept {kept}")


if __name__ == "__main__":
    main()
