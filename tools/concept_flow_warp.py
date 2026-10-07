"""
③ 투영 굽기 준비: 2D 시안을 match 카메라 화면(1024)으로 옮기고, 3D 렌더와 그림 위치가 맞도록 광학 흐름으로 살짝 당긴다.

  py tools/concept_flow_warp.py <concept.png> <cam.json> <match render.png> <out.png> [--max-flow 40] [--smooth 6]

- cam.json(concept_cam_fit.py): concept_xy = render_xy * scale + (dx, dy) → 이 변환을 거꾸로 써서 시안을 렌더 화면으로 옮긴다.
- 흐름(DIS)은 렌더 → 시안 방향으로 구하고, 크기를 --max-flow 픽셀로 자르고 흐리게 해서 찢어짐을 막는다.
- out.png = RGBA(알파 = 시안의 물체 부분), out_noflow.png = 흐름 없이 옮긴 것(비교용).
"""
import argparse
import json

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("concept")
ap.add_argument("cam")
ap.add_argument("render")
ap.add_argument("out")
ap.add_argument("--max-flow", type=float, default=40)
ap.add_argument("--smooth", type=float, default=6)
a = ap.parse_args()

cam = json.load(open(a.cam, encoding="utf-8"))
con = np.asarray(Image.open(a.concept).convert("RGB"))
c = 12
bgc = np.median(np.concatenate([con[:c, :c].reshape(-1, 3), con[-c:, -c:].reshape(-1, 3)]), 0)
fg = (np.abs(con.astype(np.int16) - bgc).max(-1) > 14).astype(np.uint8) * 255
fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
rgba = np.dstack([con, fg])

ren = Image.open(a.render).convert("RGBA")
N = ren.width
s = cam["scale"] * cam.get("render_size", 1024) / N
# render px -> concept px: q = p * s + d
M = np.float32([[s, 0, cam["dx"]], [0, s, cam["dy"]]])
in_cam = cv2.warpAffine(rgba, M, (N, N), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
Image.fromarray(in_cam).save(a.out.replace(".png", "_noflow.png"))

r = np.asarray(ren).astype(np.float32)
bg = np.ones_like(r[..., :3]) * bgc
r_rgb = (r[..., :3] * (r[..., 3:] / 255) + bg * (1 - r[..., 3:] / 255)).astype(np.uint8)
c_rgb = (in_cam[..., :3].astype(np.float32) * (in_cam[..., 3:] / 255) + bg * (1 - in_cam[..., 3:] / 255)).astype(np.uint8)
g1 = cv2.cvtColor(r_rgb, cv2.COLOR_RGB2GRAY)
g2 = cv2.cvtColor(c_rgb, cv2.COLOR_RGB2GRAY)
dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
flow = dis.calc(g1, g2, None)  # g1(p) ~ g2(p + flow(p))
mag = np.linalg.norm(flow, axis=-1, keepdims=True)
flow = flow * np.minimum(1, a.max_flow / np.maximum(mag, 1e-6))
flow = cv2.GaussianBlur(flow, (0, 0), a.smooth)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
warped = cv2.remap(in_cam, xx + flow[..., 0], yy + flow[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
Image.fromarray(warped).save(a.out)
ra = r[..., 3] > 128
for name, im in (("noflow", in_cam), ("flow", warped)):
    both = ra & (im[..., 3] > 128)
    err = np.abs(cv2.cvtColor(r_rgb, cv2.COLOR_RGB2LAB).astype(np.float32) - cv2.cvtColor(im[..., :3], cv2.COLOR_RGB2LAB).astype(np.float32))[both].mean()
    iou = both.sum() / max((ra | (im[..., 3] > 128)).sum(), 1)
    print(f"{name:6s} silhouette IoU {iou:.3f}  mean |Lab| vs render {err:.1f}")
print("flow px: median %.1f, p95 %.1f" % (np.median(np.linalg.norm(flow, axis=-1)[ra]), np.percentile(np.linalg.norm(flow, axis=-1)[ra], 95)))
