"""Colour-correct object pixels only (diff from corner bg >20): R*0.62, G*0.80 (이미지 생성 2, 디자인 검수 ConeTree). Usage: py tools/_tint_obj.py <png> [rmul gmul]"""
import sys
import numpy as np
from PIL import Image


def tint(path, rm=0.62, gm=0.80):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(float)
    c = np.array([a[:8, :8].reshape(-1, 3).mean(0), a[:8, -8:].reshape(-1, 3).mean(0), a[-8:, :8].reshape(-1, 3).mean(0), a[-8:, -8:].reshape(-1, 3).mean(0)]).mean(0)
    m = np.abs(a - c).max(2) > 20
    b = a.copy()
    b[m, 0] *= rm
    b[m, 1] *= gm
    Image.fromarray(np.clip(b, 0, 255).astype("uint8")).save(path)
    return b[m].mean(0)


if __name__ == "__main__":
    args = sys.argv[1:]
    print(tint(args[0], *(float(x) for x in args[1:3])))
