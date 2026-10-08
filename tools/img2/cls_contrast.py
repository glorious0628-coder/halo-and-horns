"""Class picker portraits: local contrast fix (style drift #24, 0 credits). Skin (face, hands) is left alone.

  py tools/img2/cls_contrast.py light <in.png> <out.png>   Halo mage / warrior: white-on-light-blue -> deeper shading,
                                                           richer blue sash and gold trim, a soft dark rim on the silhouette
  py tools/img2/cls_contrast.py dark  <in.png> <out.png>   Horns warrior / archer: near-black clothes -> lifted shadows
                                                           (about +15-25 % value), brighter red trim
"""
import sys

import cv2
import numpy as np
from PIL import Image

mode, src, dst = sys.argv[1:4]
im = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32) / 255
rgb, al = im[..., :3], im[..., 3]
hsv = cv2.cvtColor((rgb * 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
h, s, v = hsv[..., 0] / 255 * 360, hsv[..., 1] / 255, hsv[..., 2] / 255


def soft(x, lo, hi):
    return np.clip((x - lo) / max(hi - lo, 1e-6), 0, 1)


def hue_w(lo, hi, e=8.0):
    return soft(h, lo - e, lo) * (1 - soft(h, hi, hi + e))


skin = hue_w(12, 40) * soft(s, 0.18, 0.28) * (1 - soft(s, 0.62, 0.72)) * soft(v, 0.55, 0.7)
keep = 1 - skin
if mode == "light":
    # deeper mid / high tones on the white cloth (value gamma), more saturated blue sash and gold trim
    nv = v ** 1.22
    blue = hue_w(185, 235) * soft(s, 0.12, 0.25)
    gold = hue_w(30, 60) * soft(s, 0.25, 0.4)
    ns = np.clip(s * (1 + 0.6 * blue + 0.25 * gold), 0, 1)
    nv = nv * (1 - 0.06 * blue)
    # soft dark rim just inside the silhouette (about 3 px)
    inside = (al > 0.5).astype(np.uint8)
    d = cv2.distanceTransform(inside, cv2.DIST_L2, 5)
    rim = np.clip(1 - d / 3.5, 0, 1) * inside
    nv = nv * (1 - 0.35 * rim)
elif mode == "dark":
    # lift the dark cloth: value curve that raises shadows most, red trim brighter and a bit more saturated
    nv = 1 - (1 - v) ** 1.45
    red = (hue_w(-20, 15) + hue_w(340, 380)) * soft(s, 0.4, 0.55)
    nv = np.clip(nv * (1 + 0.12 * red), 0, 1)
    ns = np.clip(s * (1 + 0.1 * red) * (1 - 0.15 * (1 - red) * soft(0.35 - v, 0, 0.2)), 0, 1)
else:
    raise SystemExit("mode = light | dark")
nv = v * (1 - keep) + nv * keep
ns = s * (1 - keep) + ns * keep
out = cv2.cvtColor(np.stack([hsv[..., 0], ns * 255, nv * 255], -1).clip(0, 255).astype(np.uint8), cv2.COLOR_HSV2RGB_FULL)
Image.fromarray(np.concatenate([out, (al[..., None] * 255).astype(np.uint8)], -1), "RGBA").save(dst)
print(dst)
