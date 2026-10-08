"""Faction pick card medallion swap (style drift #2, rays -> round glow): Firefly redrew only the medallion crop; this puts
the new medallion inside the ORIGINAL card, so the card silhouette, ribbon, panel and button regions stay exactly as
approved (0 credits for the paste; the redraw itself is Firefly).

  py tools/img2/medal_swap.py <card.png> <firefly_medal.png> <out.png> [--box 110,90,510,490] [--centre 311,293]
                              [--r 186] [--ybot 431] [--feather 3] [--check sheet.jpg]

1. the Firefly image (square, any size) is resized to the crop box and aligned to the card crop with ECC (affine),
   using only the frame (the gold ring and the bar above the ribbon) so the new inside does not pull the fit;
2. pasted through a mask = circle(centre, r) cut at y < ybot (card px), edges feathered; the seam sits on the gold ring.
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("card")
ap.add_argument("medal")
ap.add_argument("out")
ap.add_argument("--box", default="110,90,510,490")
ap.add_argument("--centre", default="311,293")
ap.add_argument("--r", type=float, default=186)
ap.add_argument("--ybot", type=float, default=431)
ap.add_argument("--feather", type=float, default=3)
ap.add_argument("--check")
a = ap.parse_args()
x0, y0, x1, y1 = [int(v) for v in a.box.split(",")]
cx, cy = [float(v) for v in a.centre.split(",")]
card = Image.open(a.card).convert("RGBA")
C = np.asarray(card).astype(np.float32)
W, H = x1 - x0, y1 - y0
crop = C[y0:y1, x0:x1].copy()
bg = np.full_like(crop[..., :3], 128.0)
crop_rgb = crop[..., :3] * (crop[..., 3:] / 255) + bg * (1 - crop[..., 3:] / 255)
med = np.asarray(Image.open(a.medal).convert("RGB").resize((W, H), Image.LANCZOS)).astype(np.float32)

yy, xx = np.mgrid[0:H, 0:W]
d = np.hypot(xx + x0 - cx, yy + y0 - cy)
frame = ((d > a.r - 2) & (d < a.r + 22)) | ((yy + y0 > a.ybot - 18) & (yy + y0 < a.ybot + 4) & (np.abs(xx + x0 - cx) < a.r))
g1 = cv2.cvtColor(crop_rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
g2 = cv2.cvtColor(med.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
warp = np.eye(2, 3, dtype=np.float32)
try:
    _, warp = cv2.findTransformECC(g1, g2, warp, cv2.MOTION_AFFINE,
                                   (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-6),
                                   frame.astype(np.uint8), 5)
except cv2.error as e:
    print("ECC failed, no alignment:", e)
aligned = cv2.warpAffine(med, warp, (W, H), flags=cv2.INTER_LINEAR + cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REFLECT)
print("warp", np.round(warp, 4).tolist())

inside = np.clip((a.r - d) / a.feather + 0.5, 0, 1) * np.clip((a.ybot - (yy + y0)) / a.feather + 0.5, 0, 1)
out = crop.copy()
out[..., :3] = crop[..., :3] * (1 - inside[..., None]) + aligned * inside[..., None]
out[..., 3] = np.maximum(crop[..., 3], inside * 255)
C2 = C.copy()
C2[y0:y1, x0:x1] = out
Image.fromarray(C2.clip(0, 255).astype(np.uint8), "RGBA").save(a.out)
print(a.out)
if a.check:
    def on(img, col):
        t = Image.new("RGBA", img.size, col + (255,))
        t.alpha_composite(img)
        return t.convert("RGB")
    new = Image.open(a.out).convert("RGBA")
    s = Image.new("RGB", (W * 3 * 2, H * 2), (40, 44, 70))
    s.paste(on(card, (40, 44, 70)).crop((x0, y0, x1, y1)).resize((W * 2, H * 2)), (0, 0))
    s.paste(on(new, (40, 44, 70)).crop((x0, y0, x1, y1)).resize((W * 2, H * 2)), (W * 2, 0))
    s.paste(on(new, (40, 44, 70)).resize((round(card.width * H * 2 / card.height), H * 2)), (W * 4, 0))
    s.save(a.check, quality=92)
