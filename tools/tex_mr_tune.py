"""
⑤ 재질 손보기(0 크레딧): base color 색으로 금·물·흰 부분을 골라 glTF 금속/거칠기 맵(G = 거칠기, B = 금속)을 고친다.
Roblox SurfaceAppearance의 MetalnessMap·RoughnessMap으로 그대로 쓸 수 있게 따로 회색 PNG도 남긴다.

  py tools/tex_mr_tune.py <base color png> <mr png> <out mr png> [--gold 0.15,0.3] [--blue 0.0,0.05] [--white 0.0,0.30]

- 각 값 = 금속,거칠기. 경계는 부드럽게 섞는다. 결과: <out>, <out>_metal.png, <out>_rough.png
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("base")
ap.add_argument("mr")
ap.add_argument("out")
ap.add_argument("--gold", default="0.15,0.3")
ap.add_argument("--blue", default="0.0,0.05")
ap.add_argument("--white", default="0.0,0.30")
a = ap.parse_args()

base = np.asarray(Image.open(a.base).convert("RGB"))
mr = np.asarray(Image.open(a.mr).convert("RGB").resize((base.shape[1], base.shape[0]), Image.BILINEAR)).astype(np.float32) / 255
hsv = cv2.cvtColor(base, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
h, s, v = hsv[..., 0] / 255 * 360, hsv[..., 1] / 255, hsv[..., 2] / 255


def soft(x, lo, hi):
    return np.clip((x - lo) / max(hi - lo, 1e-6), 0, 1)


w_gold = soft(s, 0.25, 0.4) * soft(-np.abs(((h - 42 + 180) % 360) - 180), -24, -14)
w_blue = soft(s, 0.2, 0.35) * soft(-np.abs(((h - 200 + 180) % 360) - 180), -40, -28)
w_white = soft(-s, -0.16, -0.10) * soft(v, 0.55, 0.7)
rough, metal = mr[..., 1].copy(), mr[..., 2].copy()
for w, val in ((w_gold, a.gold), (w_blue, a.blue), (w_white, a.white)):
    m_, r_ = (float(x) for x in val.split(","))
    w = cv2.GaussianBlur(w, (0, 0), 1.0)
    metal = metal * (1 - w) + m_ * w
    rough = rough * (1 - w) + r_ * w
out = np.stack([mr[..., 0], rough, metal], -1)
Image.fromarray((out * 255 + 0.5).astype(np.uint8)).save(a.out)
Image.fromarray((metal * 255 + 0.5).astype(np.uint8)).save(a.out.replace(".png", "_metal.png"))
Image.fromarray((rough * 255 + 0.5).astype(np.uint8)).save(a.out.replace(".png", "_rough.png"))
for nm, w in (("gold", w_gold), ("blue", w_blue), ("white", w_white)):
    m = w > 0.5
    if not m.any():
        continue
    print(f"{nm:5s} px {m.mean():.3f}  metal {np.median(mr[..., 2][m]):.2f}->{np.median(metal[m]):.2f}  rough {np.median(mr[..., 1][m]):.2f}->{np.median(rough[m]):.2f}")
