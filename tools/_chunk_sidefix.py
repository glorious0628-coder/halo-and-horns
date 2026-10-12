"""Fix chunk side views with PIL only (이미지 생성 2): right = mirror(left); both sides rescaled so the object height equals the front's, same vertical span as the front, same grey canvas.
Usage: py tools/_chunk_sidefix.py <HaloChunk_Id>   (originals saved once in build/img2_next/pil_orig/)"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageOps

D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art/out/s2/noshadow/chunks")


def P(n, v):
    return os.path.join(D, "%s_%s_ns.png" % (n, v))


def mask(im, thr=28):
    a = np.asarray(im).astype(int)
    c = np.array([a[:8, :8].reshape(-1, 3).mean(0), a[:8, -8:].reshape(-1, 3).mean(0), a[-8:, :8].reshape(-1, 3).mean(0), a[-8:, -8:].reshape(-1, 3).mean(0)]).mean(0)
    return Image.fromarray(((np.abs(a - c).max(2) > thr) * 255).astype("uint8")), tuple(int(x) for x in c)


def main(n):
    bk = os.path.join(os.path.dirname(D), "..", "..", "..", "build/img2_next/pil_orig")
    bk = os.path.abspath(os.path.join(D, "../../../../build/img2_next/pil_orig"))
    os.makedirs(bk, exist_ok=True)
    front = Image.open(P(n, "front")).convert("RGB")
    fb = mask(front)[0].getbbox()
    fh = fb[3] - fb[1]
    left = Image.open(P(n, "left")).convert("RGB")
    for v in ("left", "right"):
        b = os.path.join(bk, "%s_%s.png" % (n, v))
        if not os.path.exists(b):
            Image.open(P(n, v)).save(b)
    m, c = mask(left)
    m = m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2))
    bb = m.point(lambda x: 255 if x > 128 else 0).getbbox()
    obj, om = left.crop(bb), m.crop(bb)
    size = (round(obj.width * fh / obj.height), fh)
    obj, om = obj.resize(size, Image.LANCZOS), om.resize(size, Image.LANCZOS)
    cv = Image.new("RGB", left.size, c)
    cv.paste(obj, ((bb[0] + bb[2]) // 2 - size[0] // 2, fb[1]), om)
    cv.save(P(n, "left"))
    ImageOps.mirror(cv).save(P(n, "right"))
    print(n, "height", fh, "span", fb[1], fb[3])


if __name__ == "__main__":
    main(sys.argv[1])
