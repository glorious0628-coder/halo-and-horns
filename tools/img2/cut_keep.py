"""Aspect-kept cutout for frames/cards/ribbons (tools/cutout_flat.py squares everything).

py cut_keep.py <src> <out> --long 1024 [--tol 48 --soft 10 --holes --hole-tol 5] [--check sheet.png] [--keep-largest]
- cutout()/edge_fix() come from tools/cutout_flat.py (shared tool, not modified here).
- trims to the alpha bbox, pads 2px, scales so the longest side == --long (never upscales past source unless --allow-up).
- --keep-largest drops detached alpha islands smaller than 0.2% of the subject (stray specks).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from cutout_flat import cutout, edge_fix  # noqa: E402


def keep_largest(im, frac=0.002):
    a = np.asarray(im.getchannel("A"))
    lab, n = ndimage.label(a > 0)
    if n <= 1:
        return im, 0
    sizes = ndimage.sum(np.ones_like(a), lab, range(1, n + 1))
    big = sizes.max()
    drop = [i + 1 for i, s in enumerate(sizes) if s < big * frac]
    arr = np.asarray(im).copy()
    if drop:
        arr[np.isin(lab, drop), 3] = 0
    return Image.fromarray(arr, "RGBA"), len(drop)


def sheet(im, path, game_h=None):
    w, h = im.size
    scale = 420 / h
    tw, th = int(w * scale), 420
    small = im.resize((tw, th), Image.LANCZOS)
    tiles = []
    for col in [(245, 245, 245), (20, 28, 60), (255, 0, 255), (60, 120, 70)]:
        t = Image.new("RGBA", (tw, th), col + (255,))
        t.alpha_composite(small)
        tiles.append(t)
    if game_h:
        g = im.resize((max(1, int(w * game_h / h)), game_h), Image.LANCZOS)
        t = Image.new("RGBA", (max(tw, g.width + 20), th), (20, 28, 60, 255))
        t.alpha_composite(g, (10, (th - game_h) // 2))
        tiles.append(t)
    out = Image.new("RGB", (sum(t.width for t in tiles) + 8 * (len(tiles) - 1), th), (255, 255, 255))
    x = 0
    for t in tiles:
        out.paste(t.convert("RGB"), (x, 0))
        x += t.width + 8
    out.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--long", type=int, default=1024)
    ap.add_argument("--tol", type=float, default=48.0)
    ap.add_argument("--soft", type=float, default=10.0)
    ap.add_argument("--holes", action="store_true")
    ap.add_argument("--hole-tol", type=float, default=5.0)
    ap.add_argument("--check")
    ap.add_argument("--game-h", type=int, default=0)
    ap.add_argument("--keep-largest", action="store_true")
    ap.add_argument("--allow-up", action="store_true")
    a = ap.parse_args()

    im = cutout(a.src, a.tol, a.soft, a.holes, hole_tol=a.hole_tol)
    if a.keep_largest:
        im, n = keep_largest(im)
        print(f"  islands dropped: {n}")
    box = im.getchannel("A").getbbox()
    im = im.crop(box)
    pad = Image.new("RGBA", (im.width + 4, im.height + 4), (0, 0, 0, 0))
    pad.paste(im, (2, 2))
    im = pad
    s = a.long / max(im.size)
    if s < 1 or a.allow_up:
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    im, n_edge = edge_fix(im)
    im.save(a.out)
    if a.check:
        sheet(im, a.check, a.game_h or None)
    al = np.asarray(im.getchannel("A"))
    print(f"{a.out}: {im.size[0]}x{im.size[1]} RGBA, opaque {(al == 255).mean():.1%}, partial {((al > 0) & (al < 255)).mean():.1%}, edge fixed {n_edge}")


if __name__ == "__main__":
    main()
