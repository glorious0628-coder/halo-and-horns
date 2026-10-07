"""
④' 짝 맞춘 색 손보기(0 크레딧): ③ 투영에서 '같은 자리'의 원래 텍스처 색 ↔ 시안 색 짝을 모아 색 바꾸는 규칙을 배우고,
텍스처 전체(옆·뒤 포함)에 같은 규칙을 쓴다. 색 띠 통계(tex_color_match.py)보다 덜 틀린다(불빛·그늘이 섞여도 짝끼리 비교).

  py tools/tex_pair_match.py <base png> <proj_dir> <out png> [--k 10] [--amount 0.8] [--ao ao.png --ao-strength 0.4]

- 짝 = project_bake.py의 proj_vis가 높고(정면) proj_alpha가 1인 텍셀.
- 원래 색을 Lab k-평균으로 무리 짓고, 무리마다 Lab 평균 차이(시안 - 원래, 밝기는 반만)를 구해 부드럽게 더한다.
- 짝이 적은 무리(< 300 텍셀)는 바꾸지 않는다.
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
ap.add_argument("--k", type=int, default=10)
ap.add_argument("--amount", type=float, default=0.8)
ap.add_argument("--light-mix", type=float, default=0.5)
ap.add_argument("--ao")
ap.add_argument("--ao-strength", type=float, default=0.4)
a = ap.parse_args()


def load(p, mode="RGB", size=None):
    im = Image.open(p).convert(mode)
    if size and im.size != size:
        im = im.resize(size, Image.BILINEAR)
    return np.asarray(im)


base8 = load(a.base)
size = (base8.shape[1], base8.shape[0])
col8 = load(os.path.join(a.proj, "proj_color.png"), size=size)
alp = load(os.path.join(a.proj, "proj_alpha.png"), "L", size).astype(np.float32) / 255
vis = load(os.path.join(a.proj, "proj_vis.png"), "L", size).astype(np.float32) / 255
vis = vis / max(np.percentile(vis[vis > 0.01], 99), 1e-6)
lab_b = cv2.cvtColor(base8, cv2.COLOR_RGB2LAB).astype(np.float32)
lab_c = cv2.cvtColor(col8, cv2.COLOR_RGB2LAB).astype(np.float32)
pair = (vis > 0.7) & (alp > 0.97)
# drop pairs where the two disagree wildly (misaligned edges): keep the closest 80 %
dE = np.linalg.norm(lab_b - lab_c, axis=-1)
pair &= dE < np.percentile(dE[pair], 80)
used = base8.reshape(-1, 3).max(-1) > 0
X = lab_b.reshape(-1, 3)
crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
sample = X[used][:: max(1, used.sum() // 60000)]
_, _, centers = cv2.kmeans(sample, a.k, None, crit, 3, cv2.KMEANS_PP_CENTERS)
d = np.linalg.norm(X[:, None, :] - centers[None], axis=-1)
lab_id = d.argmin(1).reshape(lab_b.shape[:2])
shift = np.zeros((a.k, 3), np.float32)
print("cluster  texels  pairs   L/a/b(orig)        shift L/a/b")
for i in range(a.k):
    m = pair & (lab_id == i)
    n_all = (lab_id == i).sum()
    if m.sum() >= 300:
        sh = np.median(lab_c[m] - lab_b[m], axis=0)
        sh[0] *= a.light_mix
        shift[i] = sh
    print(f"{i:5d} {n_all:8d} {m.sum():7d}   {centers[i].round(0)}   {shift[i].round(1)}")
# soft assignment so cluster borders do not band
w = np.exp(-(d ** 2) / (2 * 12.0 ** 2))
w /= w.sum(1, keepdims=True) + 1e-6
delta = (w @ shift).reshape(lab_b.shape) * a.amount
out_lab = np.clip(lab_b + delta, 0, 255).astype(np.uint8)
rgb = cv2.cvtColor(out_lab, cv2.COLOR_LAB2RGB).astype(np.float32) / 255
if a.ao:
    ao = load(a.ao, "L", size).astype(np.float32) / 255
    rgb = rgb * (1 - a.ao_strength * (1 - ao))[..., None]
Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)).save(a.out)
after = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2LAB).astype(np.float32)
print("pairs %d, mean ΔE on pairs %.1f -> %.1f -> %s" % (pair.sum(), dE[pair].mean(), np.linalg.norm(after - lab_c, axis=-1)[pair].mean(), a.out))
