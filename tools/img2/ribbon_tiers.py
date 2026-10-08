"""Day-count ribbon (A23-77) -> 5 colour tiers from one approved gold cutout, 0 credits: gold pixels (hue 28-62, saturated)
get a new hue / saturation / value scale; the red tails, cream centre and navy outline stay.

  py tools/img2/ribbon_tiers.py <gold_cut.png> <out_prefix>   -> <out_prefix>{7,14,28,50,100}.png
"""
import sys

import numpy as np
from PIL import Image

# days: (hue, saturation, value scale) — 28 = the original gold
TIERS = {7: (24, 0.72, 0.80), 14: (215, 0.06, 1.0), 28: None, 50: (222, 0.70, 0.95), 100: (190, 0.40, 1.12)}


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h * 60, s, mx


def hsv_to_rgb(h, s, v):
    c = v * s
    x = c * (1 - np.abs((h / 60) % 2 - 1))
    m = v - c
    z = np.zeros_like(h)
    k = (h // 60).astype(int) % 6
    r = np.choose(k, [c, x, z, z, x, c])
    g = np.choose(k, [x, c, c, x, z, z])
    b = np.choose(k, [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], -1)


def recolor(im, tier):
    if tier is None:
        return im.copy()
    h0, s0, vm = tier
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:]
    h, s, v = rgb_to_hsv(rgb)
    gold = (h > 28) & (h < 62) & (s > 0.38) & (v > 0.25)
    out = rgb.copy()
    nv = np.clip(v * vm, 0, 1)
    ns = np.clip(s * s0 / 0.8, 0, 1)
    out[gold] = hsv_to_rgb(np.full(gold.sum(), float(h0)), ns[gold], nv[gold])
    return Image.fromarray((np.concatenate([out, al], -1) * 255).round().astype(np.uint8), "RGBA")


if __name__ == "__main__":
    src, prefix = sys.argv[1], sys.argv[2]
    im = Image.open(src).convert("RGBA")
    for days, tier in TIERS.items():
        recolor(im, tier).save(f"{prefix}{days}.png")
        print(f"{prefix}{days}.png")
