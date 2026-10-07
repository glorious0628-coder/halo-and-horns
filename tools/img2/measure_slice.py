"""Measure a cut UI part for Roblox 9-slice and text/icon boxes.

py measure_slice.py <part.png> [--kind panel|pill|ribbon|slot] [--tol 7] [--blur 0] [--flat-tol 34] [--overlay out.png]
- stretch range: columns (rows) whose whole profile matches the middle column (row) within --tol (mean abs RGBA
  difference) can be stretched; the slice edges are where that run ends, so ornaments and rounded corners stay in the
  corner cells. Roblox only shrinks corner cells, so this is what keeps a part clean at small sizes.
- flat box: the flat area connected to the centre pixel (colour within --flat-tol), its bbox as fractions of the image
  -> the inner panel / ribbon text band / slot icon area.
- pill: slice = (endW, H/2-1, W-endW, H/2+1) (이미지 개발 rule for capsules and ribbons).
Prints JSON {size, slice, stretch, flat, flat_px}.
"""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


def stretch(a, axis, tol):
    """Return (lo, hi): the run around the middle where every line matches the middle line."""
    if axis == 0:  # columns
        prof = a.transpose(1, 0, 2)  # x, y, c
    else:
        prof = a  # y, x, c
    n = prof.shape[0]
    mid = prof[n // 2].astype(float)
    diff = np.abs(prof.astype(float) - mid[None]).mean(axis=(1, 2))
    lo = n // 2
    while lo > 0 and diff[lo - 1] < tol:
        lo -= 1
    hi = n // 2
    while hi < n - 1 and diff[hi + 1] < tol:
        hi += 1
    return lo, hi + 1


def flat_box(a, tol):
    H, W = a.shape[:2]
    c0 = a[H // 2, W // 2, :3].astype(float)
    m = (np.abs(a[..., :3].astype(float) - c0).max(axis=2) < tol) & (a[..., 3] > 250)
    lab, _ = ndimage.label(m)
    k = lab[H // 2, W // 2]
    if k == 0:
        return None
    ys, xs = np.nonzero(lab == k)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("img")
    ap.add_argument("--kind", default="panel", choices=["panel", "pill", "ribbon", "slot"])
    ap.add_argument("--tol", type=float, default=7.0)
    ap.add_argument("--flat-tol", type=float, default=34.0)
    ap.add_argument("--blur", type=float, default=0.0, help="Gaussian blur (px) before comparing lines: lets wood grain / cork / gloss gradients count as stretchable")
    ap.add_argument("--overlay")
    o = ap.parse_args()
    im = Image.open(o.img).convert("RGBA")
    a = np.asarray(im)
    H, W = a.shape[:2]
    # premultiply so fully transparent pixels compare equal whatever their RGB
    pm = a.astype(float)
    pm[..., :3] *= pm[..., 3:4] / 255.0
    if o.blur > 0:
        pm = ndimage.gaussian_filter(pm, sigma=(o.blur, o.blur, 0))
    x0, x1 = stretch(pm, 0, o.tol)
    y0, y1 = stretch(pm, 1, o.tol)
    if o.kind in ("pill", "ribbon"):
        sl = [x0, H // 2 - 1, x1, H // 2 + 1]
    else:
        sl = [x0, y0, x1, y1]
    fb = flat_box(a, o.flat_tol)
    res = {"size": [W, H], "slice": sl, "stretch": {"x": [x0, x1], "y": [y0, y1]}}
    if fb:
        fx0, fy0, fx1, fy1 = fb
        res["flat_px"] = [fx0, fy0, fx1, fy1]
        res["flat"] = [round(fx0 / W, 3), round(fy0 / H, 3), round((fx1 - fx0) / W, 3), round((fy1 - fy0) / H, 3)]
    print(json.dumps(res))
    if o.overlay:
        ov = Image.new("RGBA", (W, H), (60, 60, 60, 255))
        ov.alpha_composite(im)
        d = ImageDraw.Draw(ov)
        for x in (sl[0], sl[2]):
            d.line([(x, 0), (x, H)], fill=(255, 0, 255, 255), width=1)
        for y in (sl[1], sl[3]):
            d.line([(0, y), (W, y)], fill=(255, 0, 255, 255), width=1)
        if fb:
            d.rectangle(fb, outline=(0, 255, 120, 255), width=2)
        ov.save(o.overlay)


if __name__ == "__main__":
    main()
