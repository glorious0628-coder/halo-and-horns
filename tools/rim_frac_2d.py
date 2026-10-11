"""Where the pot's gold rim sits in a 2D front (fraction of the object's height from its foot), for tools/tripo_touchup.py
--rim-frac (이미지 생성 4, 10/12): the Tripo plant is scaled so that its pot rim lands on the part body's top.

  py tools/rim_frac_2d.py <front.png> [--from 0.15] [--to 0.8] [--debug out.png]

Object = pixels that differ from the grey background; gold = warm saturated pixels. The rim = the widest gold row
between --from and --to of the height (measured from the foot); prints the fraction of the TOP edge of that gold band.
"""
import argparse
import colorsys

import numpy as np
from PIL import Image, ImageDraw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("img")
    ap.add_argument("--from", dest="lo", type=float, default=0.15)
    ap.add_argument("--to", dest="hi", type=float, default=0.8)
    ap.add_argument("--debug", default="")
    a = ap.parse_args()
    im = Image.open(a.img).convert("RGB")
    A = np.asarray(im).astype(float) / 255
    bg = np.median(np.concatenate([A[:8].reshape(-1, 3), A[-8:].reshape(-1, 3)]), 0)
    obj = np.abs(A - bg).max(2) > 0.08
    rows = np.nonzero(obj.any(1))[0]
    top, bot = rows.min(), rows.max()
    Hh = bot - top
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in A.reshape(-1, 3)]).reshape(A.shape)
    gold = obj & (hsv[..., 0] * 360 > 28) & (hsv[..., 0] * 360 < 58) & (hsv[..., 1] > 0.45) & (hsv[..., 2] > 0.5)
    width = np.zeros(A.shape[0])
    for y in range(top, bot + 1):
        xs = np.nonzero(gold[y])[0]
        if len(xs) > 3:
            width[y] = xs.max() - xs.min()
    ylo, yhi = int(bot - a.hi * Hh), int(bot - a.lo * Hh)
    seg = width[ylo:yhi]
    y = ylo + int(np.argmax(seg))
    w = width[y]
    # walk up while the gold band stays nearly as wide: its top edge is the rim top
    yt = y
    while yt - 1 > top and width[yt - 1] > 0.85 * w:
        yt -= 1
    frac = (bot - yt) / Hh
    print("%s rim_frac %.3f (band rows %d-%d, width %d px)" % (a.img, frac, yt, y, w))
    if a.debug:
        d = ImageDraw.Draw(im)
        d.line((0, yt, im.size[0], yt), fill=(255, 0, 0), width=3)
        im.save(a.debug)


if __name__ == "__main__":
    main()
