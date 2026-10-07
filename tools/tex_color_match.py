"""
④ 색 손보기(A23-73, 0 크레딧): Tripo 텍스처 색을 고른 2D 시안 쪽으로 맞춘다. halo_castle_color_fix.py를 아무 모델에나 쓰게 넓힌 판.

  py tools/tex_color_match.py <texture in> <concept png> <out png> [--size 1024] [--ao ao.png --ao-strength 0.45]
                                [--bands gold,blue,red,green,purple] [--sharpen 0.35]

- 색 띠(금·파랑·빨강·초록·보라)마다: 색상은 시안 중앙값으로 옮기고(변화는 그대로), 채도는 분위수로 시안에 맞추고,
  밝기는 시안 쪽으로 반만(3D는 조명이 그림자를 따로 만들기 때문). 텍스처·시안 둘 다 그 색이 0.5% 넘게 있을 때만.
- 흰색(채도 낮고 밝은 곳)은 채도만 시안 흰색에 맞춘다.
- --ao: Blender로 구운 AO(흰 = 트임)를 곱해 둥근 덩어리 사이에 시안 같은 부드러운 그늘을 넣는다.
- 결과: <out>(size), <out>_full.png(원래 크기), 띠별 전후 숫자 출력.
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("tex")
ap.add_argument("concept")
ap.add_argument("out")
ap.add_argument("--size", type=int, default=1024)
ap.add_argument("--ao")
ap.add_argument("--ao-strength", type=float, default=0.45)
ap.add_argument("--bands", default="gold,blue,red,green,purple")
ap.add_argument("--sharpen", type=float, default=0.35)
ap.add_argument("--value-mix", type=float, default=0.5)
a = ap.parse_args()

BANDS = {"gold": (25, 65), "blue": (160, 250), "red": (-20, 20), "green": (70, 160), "purple": (250, 340)}


def hsv_of(rgb8):
    x = cv2.cvtColor(rgb8, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    return x[..., 0] / 255 * 360, x[..., 1] / 255, x[..., 2] / 255


def hdist(h, c):
    return (h - c + 180) % 360 - 180


def band_w(h, lo, hi, soft=8.0):
    c, half = (lo + hi) / 2, (hi - lo) / 2
    d = np.abs(hdist(h, c))
    return np.clip((half - d) / soft + 0.5, 0, 1)


tex = np.asarray(Image.open(a.tex).convert("RGB"))
con_rgb = np.asarray(Image.open(a.concept).convert("RGB"))
c = 12
corners = np.concatenate([con_rgb[:c, :c].reshape(-1, 3), con_rgb[:c, -c:].reshape(-1, 3), con_rgb[-c:, :c].reshape(-1, 3), con_rgb[-c:, -c:].reshape(-1, 3)])
fg = np.abs(con_rgb.astype(np.int16) - np.median(corners, 0)).max(-1) > 14  # not the flat grey background
th, ts, tv = hsv_of(tex)
ch, cs, cv = hsv_of(con_rgb)
Q = np.linspace(2, 98, 25)
h_new, s_new, v_new = th.copy(), ts.copy(), tv.copy()
report = []
for name in a.bands.split(","):
    lo, hi = BANDS[name]
    mt = (band_w(th, lo, hi) > 0.5) & (ts > 0.2) & (tv > 0.25)
    mc = (band_w(ch, lo, hi) > 0.5) & (cs > 0.2) & (cv > 0.25) & fg
    if mt.mean() < 0.005 or mc.sum() < 0.005 * fg.sum():
        continue
    w = band_w(th, lo, hi) * np.clip((ts - 0.12) / 0.10, 0, 1)
    cen = (lo + hi) / 2
    dh = np.median(hdist(ch[mc], cen)) - np.median(hdist(th[mt], cen))
    h_new = h_new + dh * w
    s_map = np.interp(ts, np.percentile(ts[mt], Q), np.percentile(cs[mc], Q))
    s_new = s_new * (1 - w) + s_map * w
    v_map = np.interp(tv, np.percentile(tv[mt], Q), np.percentile(cv[mc], Q))
    v_new = v_new * (1 - w) + ((1 - a.value_mix) * tv + a.value_mix * v_map) * w
    report.append((name, mt, mc))
# whites: saturation toward the concept's whites
wt = (ts < 0.15) & (tv > 0.6)
wc = (cs < 0.15) & (cv > 0.6) & fg
if wt.mean() > 0.005 and wc.sum() > 100:
    ww = np.clip((0.18 - ts) / 0.06, 0, 1) * np.clip((tv - 0.5) / 0.15, 0, 1)
    s_new = s_new * (1 - ww) + np.interp(ts, np.percentile(ts[wt], Q), np.percentile(cs[wc], Q)) * ww
    report.append(("white", wt, wc))

out_hsv = np.stack([(h_new % 360) / 360 * 255, np.clip(s_new, 0, 1) * 255, np.clip(v_new, 0, 1) * 255], -1)
rgb = cv2.cvtColor(out_hsv.astype(np.uint8), cv2.COLOR_HSV2RGB_FULL).astype(np.float32) / 255
if a.ao:
    ao = np.asarray(Image.open(a.ao).convert("L").resize((tex.shape[1], tex.shape[0]), Image.BILINEAR)).astype(np.float32) / 255
    rgb = rgb * (1 - a.ao_strength * (1 - ao))[..., None]
if a.sharpen > 0:
    blur = cv2.GaussianBlur(rgb, (0, 0), max(0.6, 1.2 * tex.shape[0] / 4096))
    rgb = np.clip(rgb + a.sharpen * (rgb - blur), 0, 1)
img = Image.fromarray((rgb * 255 + 0.5).astype(np.uint8))
img.save(a.out.replace(".png", "_full.png"))
if img.size[0] != a.size:
    img = img.resize((a.size, a.size), Image.LANCZOS)
img.save(a.out)
fh, fs, fv = hsv_of(np.asarray(img.resize((tex.shape[1], tex.shape[0]), Image.BILINEAR)))
for name, mt, mc in report:
    cen = (BANDS.get(name, (0, 360))[0] + BANDS.get(name, (0, 360))[1]) / 2
    print(f"{name:6s} h {np.median(th[mt]):5.0f} -> {np.median(fh[mt]):5.0f} (concept {np.median(ch[mc]):5.0f})"
          f"  s {np.median(ts[mt]):.2f} -> {np.median(fs[mt]):.2f} ({np.median(cs[mc]):.2f})"
          f"  v {np.median(tv[mt]):.2f} -> {np.median(fv[mt]):.2f} ({np.median(cv[mc]):.2f})")
print("mean brightness", round(float(tv.mean()), 3), "->", round(float(fv.mean()), 3), "->", a.out)
