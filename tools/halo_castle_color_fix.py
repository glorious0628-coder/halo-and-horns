"""
Halo castle (Tripo, ring banners): the 3D looked washed out next to its 2D concept (검수 2026-10-07: gold almost pale
yellow/white, weak blue, soft detail). Texture only, 0 credits: match the concept's gold and blue saturation by
quantile mapping inside each hue band, a slightly deeper gold hue, a touch warmer white walls, a light unsharp mask;
overall brightness is not lowered.

  py tools/halo_castle_color_fix.py <texture in> <concept png> <out png> [--size 1024]
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
a = ap.parse_args()


def hsv_of(rgb8):
    x = cv2.cvtColor(rgb8, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    return x[..., 0] / 255 * 360, x[..., 1] / 255, x[..., 2] / 255


tex = np.asarray(Image.open(a.tex).convert("RGB"))
con = np.asarray(Image.open(a.concept).convert("RGB"))
th, ts, tv = hsv_of(tex)
ch, cs, cv = hsv_of(con)
Q = np.linspace(2, 98, 25)


def qmap(src, dst):
    return np.percentile(src, Q), np.percentile(dst, Q)


def band(h, lo, hi, soft=6.0):
    return np.clip((h - lo) / soft + 0.5, 0, 1) * np.clip((hi - h) / soft + 0.5, 0, 1)


# gold: hue 25..65, mapped where the texture is clearly coloured (s > 0.22); faded in from s 0.12 so walls stay white
g_t = (th > 25) & (th < 65) & (ts > 0.22) & (tv > 0.3)
g_c = (ch > 25) & (ch < 65) & (cs > 0.22) & (cv > 0.3)
gs_src, gs_dst = qmap(ts[g_t], cs[g_c])
gv_src, gv_dst = qmap(tv[g_t], cv[g_c])
# blue: hue 185..250
b_t = (th > 185) & (th < 250) & (ts > 0.12) & (tv > 0.2)
b_c = (ch > 185) & (ch < 250) & (cs > 0.12) & (cv > 0.2)
bs_src, bs_dst = qmap(ts[b_t], cs[b_c])

wg = band(th, 25, 65) * np.clip((ts - 0.12) / 0.10, 0, 1)
wb = band(th, 185, 250) * np.clip((ts - 0.08) / 0.08, 0, 1)
s_new = ts.copy()
s_new = s_new * (1 - wg) + np.interp(ts, gs_src, gs_dst) * wg
s_new = s_new * (1 - wb) + np.interp(ts, bs_src, bs_dst) * wb
v_gold = np.maximum(tv, 0.5 * tv + 0.5 * np.interp(tv, gv_src, gv_dst))  # never darker; half-way to the concept
v_new = tv * (1 - wg) + v_gold * wg
h_new = th - 2.0 * wg  # a slightly deeper (more orange) gold, like the concept
out_hsv = np.stack([(h_new % 360) / 360 * 255, np.clip(s_new, 0, 1) * 255, np.clip(v_new, 0, 1) * 255], -1)
rgb = cv2.cvtColor(out_hsv.astype(np.uint8), cv2.COLOR_HSV2RGB_FULL).astype(np.float32) / 255
# white walls a touch warmer (no brightness change)
ww = np.clip((0.16 - ts) / 0.10, 0, 1) * np.clip((tv - 0.55) / 0.2, 0, 1)
rgb = rgb * (1 - ww[..., None]) + rgb * np.array([1.0, 0.988, 0.962], np.float32) * ww[..., None]
# light unsharp mask for detail (radius ~1.2 px at 4096)
blur = cv2.GaussianBlur(rgb, (0, 0), 1.2 * tex.shape[0] / 4096)
rgb = np.clip(rgb + 0.35 * (rgb - blur), 0, 1)
img = Image.fromarray((rgb * 255 + 0.5).astype(np.uint8))
img.save(a.out.replace(".png", "_full.png"))
if img.size[0] != a.size:
    img = img.resize((a.size, a.size), Image.LANCZOS)
img.save(a.out)
fh, fs, fv = hsv_of(np.asarray(img.resize((tex.shape[1], tex.shape[0]), Image.BILINEAR)))
for name, m in (("gold", g_t), ("blue", b_t)):
    print(f"{name}: s median {np.median(ts[m]):.2f} -> {np.median(fs[m]):.2f} (concept {np.median(cs[g_c if name == 'gold' else b_c]):.2f}),"
          f" v median {np.median(tv[m]):.2f} -> {np.median(fv[m]):.2f}")
print("mean brightness", round(float(tv.mean()), 3), "->", round(float(fv.mean()), 3), "->", a.out)
