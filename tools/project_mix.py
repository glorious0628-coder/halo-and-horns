"""
③ 섞기: project_bake.py 결과를 기존 텍스처(보통 ④ 색 손보기 판) 위에 정면만 덮는다.

  py tools/project_mix.py <base png> <proj_dir> <out png> [--strength 0.9] [--vis 0.30,0.65] [--alpha 0.6,0.97]

- 무게 = 보이는 정도(정면일수록 1) × 시안 물체 부분(가장자리 회색 번짐은 버림) × strength.
- 결과 out(1024), out_weight.png(어디가 덮였는지 확인용).
"""
import argparse
import os

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("base")
ap.add_argument("proj")
ap.add_argument("out")
ap.add_argument("--strength", type=float, default=0.9)
ap.add_argument("--vis", default="0.30,0.65")
ap.add_argument("--alpha", default="0.6,0.97")
a = ap.parse_args()


def load(p, mode="RGB"):
    return np.asarray(Image.open(p).convert(mode)).astype(np.float32) / 255


base = load(a.base)
col = load(os.path.join(a.proj, "proj_color.png"))
alp = load(os.path.join(a.proj, "proj_alpha.png"), "L")
vis = load(os.path.join(a.proj, "proj_vis.png"), "L")
if col.shape[:2] != base.shape[:2]:
    size = (base.shape[1], base.shape[0])
    col = cv2.resize(col, size, interpolation=cv2.INTER_LINEAR)
    alp = cv2.resize(alp, size, interpolation=cv2.INTER_LINEAR)
    vis = cv2.resize(vis, size, interpolation=cv2.INTER_LINEAR)
vis = vis / max(np.percentile(vis[vis > 0.01], 99), 1e-6)


def smooth(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


v0, v1 = (float(x) for x in a.vis.split(","))
a0, a1 = (float(x) for x in a.alpha.split(","))
w = smooth(vis, v0, v1) * smooth(alp, a0, a1) * a.strength
w = cv2.GaussianBlur(w, (0, 0), 1.2)
out = base * (1 - w[..., None]) + col * w[..., None]
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(a.out)
Image.fromarray((w * 255).astype(np.uint8)).save(a.out.replace(".png", "_weight.png"))
print("covered (w>0.5): %.1f%% of texels" % (100 * (w > 0.5).mean()), "->", a.out)
