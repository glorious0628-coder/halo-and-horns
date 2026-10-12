"""Measure a gold dome's outline r(z) from its 2D front concept (이미지 생성 3, 10/12, 디자인 검수: domes 10 and 01 from
the 2D proportions, not from torn Tripo pieces).

  py tools/dome_profile_2d.py <2d.png> <cx px> <y_top px> <y_base px> <R studs> [--out prof.json] [--check check.png]
          [--side max] [--gap 5]

Gold pixels (hue 30-58 deg, saturation > 0.35, value > 0.3) are walked out from the axis column cx on every row between
y_top (the spike tip) and y_base (where the dome sits on the cornice); --side max (default) / min / left / right picks
the half width (a shadowed side can stop early at a dark rib), --gap N px of dark rib line do not end the run (default 5).
The base half width is scaled to R studs and the same scale is used for the height, so the dome keeps the 2D's proportions. Writes {"profile": [[r, z], ...] bottom -> top (studs, z 0 =
base), "px_per_stud"} and a check image with the measured outline drawn over the 2D.
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

a = sys.argv[1:]
src, cx, yt, yb, R = a[0], int(a[1]), int(a[2]), int(a[3]), float(a[4])
out = a[a.index("--out") + 1] if "--out" in a else None
chk = a[a.index("--check") + 1] if "--check" in a else None
SIDE = a[a.index("--side") + 1] if "--side" in a else "max"     # min / max / left / right
GAP = int(a[a.index("--gap") + 1]) if "--gap" in a else 5        # dark rib lines up to GAP px do not end the run
im = Image.open(src).convert("RGB")
A = np.asarray(im).astype(float) / 255.0
mx, mn = A.max(2), A.min(2)
sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
r_, g_, b_ = A[..., 0], A[..., 1], A[..., 2]
d_ = np.maximum(mx - mn, 1e-6)
hh = np.where(mx == r_, ((g_ - b_) / d_) % 6, np.where(mx == g_, (b_ - r_) / d_ + 2, (r_ - g_) / d_ + 4)) * 60
gold = (hh >= 30) & (hh <= 58) & (sat > 0.35) & (mx > 0.3)
gold |= (mx > 0.85) & (sat > 0.12) & (hh >= 30) & (hh <= 60)          # pale highlights on the gold
rows = []
for y in range(yt, yb + 1):
    row = gold[y]
    if not row[cx] and not row[max(cx - 1, 0)] and not row[min(cx + 1, row.size - 1)]:
        continue
    l = cx
    gap = 0
    while l > 0 and (row[l - 1] or gap < GAP):
        gap = gap + 1 if not row[l - 1] else 0
        l -= 1
    l += gap                                            # back to the last gold pixel
    r = cx
    gap = 0
    while r < row.size - 1 and (row[r + 1] or gap < GAP):
        gap = gap + 1 if not row[r + 1] else 0
        r += 1
    r -= gap
    rows.append((y, {"min": min, "max": max}[SIDE](cx - l, r - cx) if SIDE in ("min", "max") else (r - cx if SIDE == "right" else cx - l)))
rows = np.array(rows, float)
base_hw = float(np.median(rows[-4:, 1]))
k = R / base_hw                                         # studs per px
prof = []
for y, hw in rows[::-1]:                                # bottom -> top
    prof.append([round(hw * k, 3), round((yb - y) * k, 3)])
# rows where the walk stopped early at a dark rib line are dents: a 3-row running max (the outline is the outer edge),
# then a 7-row mean so the pixel steps do not turn into rings on the lathe; closed on top
P = np.array(prof)
Pm = np.pad(P[:, 0], 1, mode="edge")
P[:, 0] = np.max(np.stack([Pm[i:i + len(P)] for i in range(3)]), axis=0)          # 3-row max (dents out)
Pm = np.pad(P[:, 0], 3, mode="edge")
P[:, 0] = np.mean(np.stack([Pm[i:i + len(P)] for i in range(7)]), axis=0)         # 7-row mean (no pixel-step rings)
step = max(1, len(P) // 48)
P = P[::step]
prof = [[float(P[0, 0]), 0.0]] + [[float(r), float(z)] for r, z in P]
rt, zt = prof[-1]
if rt > 0.03:                                           # a round top (ball / spike tip), not a flat disk
    for th in (30, 55, 75):
        prof.append([rt * math.cos(math.radians(th)), zt + 0.5 * rt * math.sin(math.radians(th))])
    zt += 0.5 * rt
prof.append([0.0, zt])
res = {"src": src, "cx": cx, "y_top": yt, "y_base": yb, "R": R, "px_per_stud": round(1 / k, 3), "height_studs": round(prof[-1][1], 3),
       "profile": prof}
if out:
    json.dump(res, open(out, "w"), indent=1)
if chk:
    c = im.copy()
    dr = ImageDraw.Draw(c)
    for r, z in prof:
        y = yb - z / k
        dr.point([(cx - r / k, y), (cx + r / k, y)], fill=(255, 0, 255))
        dr.ellipse([cx - r / k - 1, y - 1, cx - r / k + 1, y + 1], outline=(255, 0, 255))
        dr.ellipse([cx + r / k - 1, y - 1, cx + r / k + 1, y + 1], outline=(255, 0, 255))
    c.crop((max(cx - int(1.4 * base_hw), 0), max(yt - 20, 0), cx + int(1.4 * base_hw), yb + 30)).save(chk)
print("[profile] %d rows, base half width %.1f px, %.3f px/stud, height %.2f studs" % (len(prof), base_hw, 1 / k, prof[-1][1]))
