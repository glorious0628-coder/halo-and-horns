"""Icon cutout = tools/cutout_flat (cutout, square, edge_fix) + drop detached islands smaller than --frac of the main body.

py cut_icon.py <src> <out> [--frac 0.02] [--holes] [--hole-tol 5] [--size 512] [--fill 0.86] [--check sheet.png]
Prints every dropped island (area, bbox) so it can be confirmed.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from cutout_flat import check_sheet, cutout, edge_fix, square  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--frac", type=float, default=0.02)
ap.add_argument("--holes", action="store_true")
ap.add_argument("--hole-tol", type=float, default=5.0)
ap.add_argument("--size", type=int, default=512)
ap.add_argument("--fill", type=float, default=0.86)
ap.add_argument("--check")
ap.add_argument("--keep-r", type=int, default=0, help="keep only pixels within R px of the solid (alpha>200) components >= frac of the largest")
a = ap.parse_args()

im = cutout(a.src, 48.0, 10.0, a.holes, hole_tol=a.hole_tol)
arr = np.asarray(im).copy()
al = arr[..., 3]
lab, n = ndimage.label(al > 0, structure=np.ones((3, 3)))
if n > 1:
    sizes = ndimage.sum(np.ones_like(al), lab, range(1, n + 1))
    big = sizes.max()
    objs = ndimage.find_objects(lab)
    drop = []
    for i, s in enumerate(sizes):
        if s < big * a.frac:
            drop.append(i + 1)
            if s > 30:
                sl = objs[i]
                print(f"  island dropped: {int(s)}px y{sl[0].start}-{sl[0].stop} x{sl[1].start}-{sl[1].stop}")
    kept = [int(s) for s in sizes if s >= big * a.frac]
    print(f"  islands dropped {len(drop)}, kept components {kept}")
    arr[np.isin(lab, drop), 3] = 0
if a.keep_r:
    strong = arr[..., 3] > 200
    lab2, n2 = ndimage.label(strong, structure=np.ones((3, 3)))
    sz2 = ndimage.sum(np.ones_like(al), lab2, range(1, n2 + 1))
    keep_ids = [i + 1 for i, s in enumerate(sz2) if s >= sz2.max() * a.frac]
    for i, s in enumerate(sz2):
        if s < sz2.max() * a.frac and s > 30:
            sl = ndimage.find_objects(lab2)[i]
            print(f"  solid piece dropped: {int(s)}px y{sl[0].start}-{sl[0].stop} x{sl[1].start}-{sl[1].stop}")
    near = ndimage.binary_dilation(np.isin(lab2, keep_ids), iterations=a.keep_r)
    arr[~near, 3] = 0
im = Image.fromarray(arr, "RGBA")
im = square(im, a.size, a.fill)
im, ne = edge_fix(im)
im.save(a.out)
if a.check:
    check_sheet(im, a.check)
print(f"{a.out}: {im.size}")
