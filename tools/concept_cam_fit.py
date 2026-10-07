"""
2D 시안과 같은 시점 찾기: tex_compare_render.py --masks 로 찍은 실루엣들 중 시안 실루엣과 가장 잘 겹치는 az/el/lens를 고른다.

  py tools/concept_cam_fit.py <concept.png> <masks_dir> <out.json> [--min-area 0.0015]

- 시안 실루엣 = 모서리 배경색과 다른 픽셀(작은 반짝이 조각은 버림).
- 각 실루엣은 테두리 상자 높이·가운데를 시안에 맞춘 뒤 IoU로 점수를 낸다.
- out.json: {"az","el","lens","iou","scale","dx","dy"} — match 렌더(1024)를 시안(같은 크기) 위에 놓는 변환:
  concept_xy = render_xy * scale + (dx, dy)
"""
import argparse
import glob
import json
import os
import re

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("concept")
ap.add_argument("masks")
ap.add_argument("out")
ap.add_argument("--min-area", type=float, default=0.0015)
a = ap.parse_args()


def concept_mask(path, size):
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.int16)
    h, w = im.shape[:2]
    c = 12
    corners = np.concatenate([im[:c, :c].reshape(-1, 3), im[:c, -c:].reshape(-1, 3), im[-c:, :c].reshape(-1, 3), im[-c:, -c:].reshape(-1, 3)])
    bg = np.median(corners, 0)
    diff = np.abs(im - bg).max(-1)
    m = (diff > 14).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    keep = np.zeros_like(m)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= a.min_area * h * w:
            keep[lab == i] = 1
    keep = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    return keep, cv2.resize(keep, (size, size), interpolation=cv2.INTER_AREA) > 0


def bbox(m):
    ys, xs = np.nonzero(m)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


full, cm = concept_mask(a.concept, 256)
cx0, cy0, cx1, cy1 = bbox(cm)
res = []
for p in glob.glob(os.path.join(a.masks, "m_*.png")):
    az, el, ln = (float(x) for x in re.match(r"m_(-?[\d.]+)_(-?[\d.]+)_(-?[\d.]+)\.png", os.path.basename(p)).groups())
    rm = np.asarray(Image.open(p).convert("L")) > 128
    if rm.sum() < 50:
        continue
    rx0, ry0, rx1, ry1 = bbox(rm)
    sc = (cy1 - cy0) / (ry1 - ry0)
    dx = (cx0 + cx1) / 2 - (rx0 + rx1) / 2 * sc
    dy = cy0 - ry0 * sc
    M = np.float32([[sc, 0, dx], [0, sc, dy]])
    warped = cv2.warpAffine(rm.astype(np.uint8), M, (256, 256), flags=cv2.INTER_NEAREST) > 0
    iou = (warped & cm).sum() / max((warped | cm).sum(), 1)
    res.append((iou, az, el, ln, sc, dx, dy, rm.shape[0]))
res.sort(reverse=True)
for r in res[:8]:
    print(f"iou {r[0]:.4f}  az {r[1]:g} el {r[2]:g} lens {r[3]:g}")
best = res[0]
# masks are 256 px and the match render is 1024 px; the concept was compared at 256 px too.
# scale maps match-render px -> concept px; dx, dy are in concept px.
out = {"az": best[1], "el": best[2], "lens": best[3], "iou": round(float(best[0]), 4),
       "scale": float(best[4]) * (full.shape[0] / 256) / (1024 / 256),
       "dx": float(best[5]) * full.shape[1] / 256, "dy": float(best[6]) * full.shape[0] / 256,
       "concept_size": [int(full.shape[1]), int(full.shape[0])], "render_size": 1024}
json.dump(out, open(a.out, "w"), indent=1)
Image.fromarray((full * 255).astype(np.uint8)).save(os.path.splitext(a.out)[0] + "_concept_mask.png")
print("best", json.dumps(out))
