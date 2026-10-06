"""Remove semi-transparent background haze that sits away from the solid subject.

py clean_haze.py <in.png> <out.png> [--solid 240] [--keep 3]
Pixels with alpha < --solid that are farther than --keep px from any solid pixel become fully transparent.
Use for people/props whose gray backdrop had blotches or a floor shadow (cut_keep leaves them as partial alpha).
Do not use on art with thin semi-transparent strokes (bow strings) far from the body.
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--solid", type=int, default=240)
ap.add_argument("--keep", type=float, default=3.0)
ap.add_argument("--min-island", type=int, default=200, help="also drop detached pieces smaller than this many px (0 = off)")
a = ap.parse_args()

im = Image.open(a.src).convert("RGBA")
arr = np.asarray(im).copy()
al = arr[..., 3]
solid = al >= a.solid
dist = ndimage.distance_transform_edt(~solid)
kill = (~solid) & (al > 0) & (dist > a.keep)
arr[kill, 3] = 0
if a.min_island:
    lab, n = ndimage.label(arr[..., 3] > 0, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(np.ones(lab.shape), lab, range(1, n + 1))
        small = [i + 1 for i, s in enumerate(sizes) if s < a.min_island]
        arr[np.isin(lab, small), 3] = 0
        print(f"  dropped {len(small)} specks < {a.min_island}px")
Image.fromarray(arr, "RGBA").save(a.out)
part = ((arr[..., 3] > 0) & (arr[..., 3] < a.solid)).sum()
print(f"{a.out}: cleared {int(kill.sum())} hazy px, partial left {int(part)} ({part * 100.0 / al.size:.1f}%)")
