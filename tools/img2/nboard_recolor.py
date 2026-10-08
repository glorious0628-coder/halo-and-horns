"""Crossroads supporter board (A23-75 VIP board) = the wanted board X_NoticeBoard with only its base-colour texture
repainted gold + warm cream (0 credits, same mesh). Soft HSV classes, the new colour is mixed in RGB by class weight.

  py tools/img2/nboard_recolor.py <base.png> <out.png> [--crystal ruby|amber|keep] [--crystal-mask mask.png]

classes (from the texture's hue histogram): teal paint (roof tiles, pillars; h 160-200) -> gold, brown wood
(boards, beams; h 8-36) -> warm cream with the grain kept, brass fittings (h 34-52, saturated, bright) and cream stone
are kept, the crystal on top (geometry mask --crystal-mask, made with tools/img2/prop_mask.py ... 0.10 0.10) and the
lantern glass (h 140-174) -> --crystal (ruby or warm amber).
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--crystal", default="ruby", choices=["ruby", "amber", "keep"])
ap.add_argument("--crystal-mask", help="geometry mask png (white = crystal faces)")
args = ap.parse_args()


def soft(x, lo, hi):
    return np.clip((x - lo) / max(hi - lo, 1e-6), 0, 1)


def hue_w(h, lo, hi, edge=6.0):
    return soft(h, lo - edge, lo) * (1 - soft(h, hi, hi + edge))


def to_rgb(h, s, v):
    hsv = np.stack([h / 360 * 255, s * 255, v * 255], -1).clip(0, 255).astype(np.uint8)
    return cv2.cvtColor(hsv[None] if hsv.ndim == 2 else hsv, cv2.COLOR_HSV2RGB_FULL).astype(np.float32) / 255


rgb8 = np.asarray(Image.open(args.src).convert("RGB"))
x = cv2.cvtColor(rgb8, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
h, s, v = x[..., 0] / 255 * 360, x[..., 1] / 255, x[..., 2] / 255
rgb = rgb8.astype(np.float32) / 255
sat = soft(s, 0.15, 0.3)

teal = hue_w(h, 160, 200) * sat
# crystal on top: a geometry mask baked from the mesh (tools/img2/prop_mask.py, top-centre faces), inside it every
# cyan pixel incl. the pale facets; lantern glass: the green-cyan hue band (h 140-174) that the roof tiles do not use
geo = np.asarray(Image.open(args.crystal_mask).convert("L"), np.float32) / 255 if args.crystal_mask else np.zeros_like(h)
crystal = np.maximum(geo * hue_w(h, 150, 200) * soft(s, 0.05, 0.15),
                     hue_w(h, 140, 174, 3.0) * soft(s, 0.28, 0.38) * soft(v, 0.4, 0.5))
teal = teal * (1 - np.clip(crystal * 1.5, 0, 1))
brass = hue_w(h, 34, 52) * soft(s, 0.42, 0.55) * soft(v, 0.42, 0.55)
wood = hue_w(h, 8, 36) * sat * (1 - brass)

out = rgb.copy()
# teal paint -> rich gold: hue runs warm (34) in the shade to yellow (46) in the light so dark parts stay amber,
# not olive; value lifted
gv = np.clip(0.10 + 0.95 * v, 0, 0.95)
g = to_rgb(31 + 11 * gv, np.clip(0.97 - 0.2 * gv, 0, 1), gv)
out = out * (1 - teal[..., None]) + g * teal[..., None]
# brown wood -> warm cream; value lifted but the grain (relative value) kept
vc = np.clip(0.36 + 0.72 * v, 0, 0.9)
c = to_rgb(np.full_like(h, 33.0), np.clip(0.30 + 0.25 * s, 0, 0.5), vc)
out = out * (1 - wood[..., None]) + c * wood[..., None]
if args.crystal != "keep":
    ch, cs = (350.0, 0.8) if args.crystal == "ruby" else (36.0, 0.8)
    k = to_rgb(np.full_like(h, ch), np.full_like(h, cs), np.clip(v * 1.05, 0, 1))
    out = out * (1 - crystal[..., None]) + k * crystal[..., None]
Image.fromarray((out.clip(0, 1) * 255).round().astype(np.uint8)).save(args.out)
print(args.out, "teal %.1f%% wood %.1f%% brass %.1f%% crystal %.2f%%" % tuple(100 * m.mean() for m in (teal, wood, brass, crystal)))
