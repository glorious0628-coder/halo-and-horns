"""Draw a stud grid on tools/tripo_ortho.py renders (lines every 1 stud, labels every 2, bold every 5).

  py tools/tripo_ortho_grid.py <out_dir>        (reads frame.json, writes <view>_grid.png)
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

d = sys.argv[1]
F = json.load(open(os.path.join(d, "frame.json")))
try:
    font = ImageFont.truetype("arial.ttf", 13)
except OSError:
    font = ImageFont.load_default()
for vw, f in F["views"].items():
    p = os.path.join(d, vw + ".png")
    if not os.path.exists(p):
        continue
    im = Image.open(p).convert("RGB")
    W, H = im.size
    ua, umin, umax, us = f["u"]
    va, vmin, vmax, vs = f["v"]
    span = max(umax - umin, vmax - vmin)
    ppu = W / (umax - umin) if (umax - umin) >= (vmax - vmin) else H / (vmax - vmin)
    uc, vc = (umin + umax) / 2, (vmin + vmax) / 2
    dr = ImageDraw.Draw(im, "RGBA")

    def px_u(u):
        return W / 2 + (u - uc) * ppu * us

    def px_v(v):
        return H / 2 - (v - vc) * ppu * vs

    for k in range(math.floor(umin), math.ceil(umax) + 1):
        x = px_u(k)
        col = (255, 60, 60, 150) if k == 0 else ((255, 255, 255, 110) if k % 5 == 0 else (255, 255, 255, 40))
        dr.line([(x, 0), (x, H)], fill=col, width=1)
        if k % 2 == 0:
            dr.text((x + 2, H - 16), "%s%d" % (ua, k), fill=(255, 255, 0, 255), font=font)
    for k in range(math.floor(vmin), math.ceil(vmax) + 1):
        y = px_v(k)
        col = (255, 60, 60, 150) if k == 0 else ((255, 255, 255, 110) if k % 5 == 0 else (255, 255, 255, 40))
        dr.line([(0, y), (W, y)], fill=col, width=1)
        if k % 2 == 0:
            dr.text((2, y - 14), "%s%d" % (va, k), fill=(0, 255, 255, 255), font=font)
    im.save(os.path.join(d, vw + "_grid.png"))
    print("[grid]", vw, im.size)
