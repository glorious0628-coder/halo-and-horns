"""
지형 타일 다시 칠하기(0 크레딧): 무늬는 그대로 두고 평균 색을 시안 색으로 옮긴다(Lab 공간: a·b는 그대로 옮기고,
밝기는 평균을 맞추고 변화 폭은 조금 줄임). 픽셀마다 같은 변환이라 이음매 없는 타일은 계속 이음매가 없다.

  py tools/tile_recolor.py <in.png> <out.png> <R,G,B 목표 평균> [--contrast 0.95]

Terrain:SetMaterialColor는 곱하기라 어두운 타일을 밝게 못 한다 — 그래서 타일 자체를 시안 밝기로 맞춘다
(2026-10-07: 올라간 GE_* 타일이 시안보다 최대 1.8배 어두웠음).
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("inp")
ap.add_argument("out")
ap.add_argument("target")
ap.add_argument("--contrast", type=float, default=0.95)
a = ap.parse_args()

src = np.asarray(Image.open(a.inp).convert("RGB")).astype(np.float32) / 255
lab = cv2.cvtColor(src, cv2.COLOR_RGB2LAB)  # float: L 0..100, a/b about -127..127
tgt = np.array([[[int(x) / 255 for x in a.target.split(",")]]], np.float32)
tl = cv2.cvtColor(tgt, cv2.COLOR_RGB2LAB)[0, 0]
# the mean colour of the tile as a single colour (what the eye averages at a distance)
mean_rgb = src.reshape(-1, 3).mean(0)
ml = cv2.cvtColor(mean_rgb[None, None, :].astype(np.float32), cv2.COLOR_RGB2LAB)[0, 0]
out = lab.copy()
out[..., 0] = tl[0] + (lab[..., 0] - lab[..., 0].mean()) * a.contrast + (ml[0] - lab[..., 0].mean()) * 0
out[..., 1] = lab[..., 1] + (tl[1] - ml[1])
out[..., 2] = lab[..., 2] + (tl[2] - ml[2])
rgb = np.clip(cv2.cvtColor(out, cv2.COLOR_LAB2RGB), 0, 1)
# second pass: nudge the plain RGB mean onto the target (Lab mean != RGB mean for textured tiles)
rgb = np.clip(rgb * (tgt[0, 0] / np.maximum(rgb.reshape(-1, 3).mean(0), 1e-4)), 0, 1)
Image.fromarray((rgb * 255 + 0.5).astype(np.uint8)).save(a.out)
print("mean", tuple(int(x * 255) for x in mean_rgb), "->", tuple(int(x * 255) for x in rgb.reshape(-1, 3).mean(0)), "target", a.target)
