"""Old PBR monster base colours (style drift #35, 0 credits): lift the value and calm the grime so they sit next to the
glossy baked-colour monsters.

  py tools/img2/mon_tone.py <in.png> <out.png> [--lift 0.25] [--sat 1.08] [--clean 0.6] [--keep-hues 260-300,35-55] [--tint 250,0.35]

--lift   value lift for dark pixels (v' = v + lift * (1 - v) * shadow weight); bright parts barely move
--sat    saturation scale (kept hues are not scaled down)
--clean  0..1 mix of an edge-preserving smoothed copy (bilateral) = fewer rust / grime specks, outlines kept
--keep-hues  hue ranges (deg) whose saturation is kept at least as it was (purple glow, gold trim ...)
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--lift", type=float, default=0.25)
ap.add_argument("--sat", type=float, default=1.08)
ap.add_argument("--clean", type=float, default=0.6)
ap.add_argument("--keep-hues", default="")
ap.add_argument("--tint", default="", help="H,S: give lifted near-grey dark pixels this hue / saturation (armour -> deep indigo, not grey)")
a = ap.parse_args()
rgb = np.asarray(Image.open(a.src).convert("RGB"))
if a.clean > 0:
    sm = cv2.bilateralFilter(rgb, 9, 40, 7)
    sm = cv2.bilateralFilter(sm, 9, 30, 5)
    rgb = (rgb.astype(np.float32) * (1 - a.clean) + sm.astype(np.float32) * a.clean).clip(0, 255).astype(np.uint8)
hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
h, s, v = hsv[..., 0] / 255 * 360, hsv[..., 1] / 255, hsv[..., 2] / 255
shadow = np.clip((0.75 - v) / 0.5, 0, 1)
nv = v + a.lift * (1 - v) * shadow
ns = np.clip(s * a.sat, 0, 1)
for rng in [r for r in a.keep_hues.split(",") if r]:
    lo, hi = [float(x) for x in rng.split("-")]
    keep = (h >= lo) & (h <= hi)
    ns[keep] = np.maximum(ns[keep], s[keep])
nh = hsv[..., 0].copy()
if a.tint:
    th, ts = [float(x) for x in a.tint.split(",")]
    wgt = shadow * np.clip((0.3 - s) / 0.2, 0, 1)
    nh = np.where(wgt > 0.05, th / 360 * 255, nh)
    ns = ns * (1 - wgt) + ts * wgt
out = cv2.cvtColor(np.stack([nh, ns * 255, nv.clip(0, 1) * 255], -1).astype(np.uint8), cv2.COLOR_HSV2RGB_FULL)
Image.fromarray(out).save(a.out)
print(a.out, "mean v %.2f -> %.2f" % (v.mean(), nv.mean()))
