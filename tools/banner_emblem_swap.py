"""
Swap a painted banner emblem for a gold halo ring on a Tripo model, texture only (Halo castle, user 2026-10-06:
winged cross -> gold halo ring). Works in screen space like tools/castle_window_inpaint.py, so emblems split over
UV seams are handled.

  1) blender ... tools/castle_window_dump.py -- <in.glb> <dump_dir> --screen cx,cy,rx,ry --view <view>   (one per emblem;
     the ellipse sits on the emblem, inside the banner's gold edge)
  2) py tools/banner_emblem_swap.py <tex_out.png> <dump_dir> [<dump_dir> ...] [--aspect 0.62] [--size 0.40] [--band 0.26] [--shift E1:0,0.3]
  3) blender ... tools/glb_texture_patch.py -- export <in.glb> <out.glb> --tex <tex_out.png>

Per dump: the gold pieces inside the ellipse (the emblem) are filled from the blue banner around them (OpenCV
Telea), then a flat gold halo ring (ellipse, slightly lit from the top, darker rim) is painted at the emblem's
centre; only those samples are written back to their texels (soft edge). All dumps go into one texture.
- --size: ring outer radius as a part of the emblem width; --aspect: ring height / width; --band: ring thickness.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

args = [a for a in sys.argv[1:]]


def opt(name, default):
    if name in args:
        i = args.index(name)
        v = args[i + 1]
        del args[i:i + 2]
        return float(v)
    return default


ASPECT = opt("--aspect", 0.62)
SIZE = opt("--size", 0.40)
BAND = opt("--band", 0.26)
# --shift <dump folder name>:dx,dy moves that banner's ring by dx, dy ring radii (e.g. off a crease highlight)
SHIFT = {}
while "--shift" in args:
    i = args.index("--shift")
    key, xy = args[i + 1].split(":")
    SHIFT[key] = tuple(float(v) for v in xy.split(","))
    del args[i:i + 2]
OUT, DUMPS = args[0], args[1:]
px = np.load(f"{DUMPS[0]}/tex0.npy")  # bottom-up, 0..1 stored colour
out = px[..., :3].astype(np.float64).copy()
th, tw = out.shape[:2]
report = []

for D in DUMPS:
    z = np.load(f"{D}/dump.npz")
    texel, alb, valid = z["texel"], z["alb"], z["valid"]
    x0, y0, x1, y1, SS = z["box"]
    cx, cy, rx, ry = z["ellipse"]
    H_, W_ = valid.shape
    yy, xx = np.mgrid[0:H_, 0:W_].astype(np.float32)
    dn = np.sqrt(((x0 + (xx + 0.5) / SS - cx) / rx) ** 2 + ((y0 + (yy + 0.5) / SS - cy) / ry) ** 2)
    R, G, B = alb[..., 0], alb[..., 1], alb[..., 2]
    gold = (R > 0.55) & (G > 0.42) & (B < 0.6) & (R - B > 0.18) & (valid > 0) & (dn <= 1.15)
    n, lab, st, cen = cv2.connectedComponentsWithStats(gold.astype(np.uint8), 8)
    keep = np.zeros_like(gold)
    for i in range(1, n):
        ccx, ccy = cen[i]
        d = np.sqrt(((x0 + (ccx + 0.5) / SS - cx) / rx) ** 2 + ((y0 + (ccy + 0.5) / SS - cy) / ry) ** 2)
        if st[i, cv2.CC_STAT_AREA] >= SS * SS and d < 0.9:
            keep |= lab == i
    if not keep.any():
        report.append(f"{D}: no emblem found")
        continue
    ys, xs = np.nonzero(keep)
    ex0, ex1, ey0, ey1 = xs.min(), xs.max(), ys.min(), ys.max()
    ew = ex1 - ex0 + 1
    ecx, ecy = (ex0 + ex1) / 2.0, (ey0 + ey1) / 2.0
    gold_col = np.median(alb[keep], axis=0)
    # other gold bits: wing tips cut off by UV seams sit in blue; the banner's gold edge touches the wall instead
    all_gold = (R > 0.55) & (G > 0.42) & (B < 0.6) & (R - B > 0.18) & (valid > 0)
    deep_blue = (B - R > 0.25) & (valid > 0)
    n2, lab2, st2, cen2 = cv2.connectedComponentsWithStats((all_gold & ~keep).astype(np.uint8), 8)
    kr = np.ones((int(2 * SS) + 1,) * 2, np.uint8)
    for i in range(1, n2):
        x, y, w_, h_ = st2[i, :4]
        if w_ * h_ > (ew * ew):  # long border strips
            continue
        sl = (slice(max(0, y - 2 * SS), y + h_ + 2 * SS), slice(max(0, x - 2 * SS), x + w_ + 2 * SS))
        m = (lab2[sl] == i).astype(np.uint8)
        ring = (cv2.dilate(m, kr) > 0) & (m == 0)
        ccx, ccy = cen2[i]
        d = np.sqrt(((x0 + (ccx + 0.5) / SS - cx) / rx) ** 2 + ((y0 + (ccy + 0.5) / SS - cy) / ry) ** 2)
        # small bits near the emblem are emblem (the long edge strips were skipped above); a bit in clear blue
        # may sit a little further out
        if d < 1.15 or (ring.any() and deep_blue[sl][ring].mean() > 0.6 and d < 1.35):
            keep[sl] |= m > 0
    # banner inside = convex hull of the deep-blue cloth around the emblem (the banner is a convex shape); inside it
    # everything that is not deep blue (emblem, its outline, seam specks) is refilled from the blue cloth only, so
    # the gold edge and the wall never bleed in
    near = cv2.dilate(keep.astype(np.uint8), np.ones((int(3 * SS) + 1,) * 2, np.uint8)) > 0
    nb, labb, stb, _ = cv2.connectedComponentsWithStats(deep_blue.astype(np.uint8), 8)
    cloth = np.zeros_like(keep)
    for i in range(1, nb):
        mi = labb == i
        if (mi & near).any():
            cloth |= mi
    pts = np.column_stack(np.nonzero(cloth))[:, ::-1].astype(np.int32)
    hull = np.zeros(keep.shape, np.uint8)
    cv2.fillConvexPoly(hull, cv2.convexHull(pts), 1)
    # stay a little inside the cloth hull: the gold edge is shaded and not always "gold" by colour, so reaching
    # outward would paint over it
    inside = cv2.erode(hull, np.ones((int(SS) // 2 * 2 + 1,) * 2, np.uint8)) > 0
    hole = (inside & ~deep_blue & (valid > 0)) | (keep & inside)
    # grow 2 px so the soft edge of the refill lies on clean blue cloth, not on the emblem's outline
    hole = (cv2.dilate(hole.astype(np.uint8), np.ones((int(2 * SS) + 1,) * 2, np.uint8)) > 0) & inside & (valid > 0)
    protect = ~inside
    # refill = smooth mix of the clean blue cloth only (normalised blur). An inpaint (Telea) would carry the thin
    # seam lines that touch the hole on into it.
    known = (deep_blue & ~hole & inside).astype(np.float32)
    filled = np.zeros_like(alb)
    have = np.zeros(known.shape, bool)
    for sig in (2.0, 4.0, 8.0):
        num = cv2.GaussianBlur(alb * known[..., None], (0, 0), SS * sig)
        den = cv2.GaussianBlur(known, (0, 0), SS * sig)
        ok = (den > 1e-3) & ~have
        filled[ok] = num[ok] / den[ok][:, None]
        have |= ok
    filled = np.where(hole[..., None], filled, alb).astype(np.float32)
    # halo ring
    ro = SIZE * ew
    sdx, sdy = SHIFT.get(os.path.basename(os.path.normpath(D)), (0.0, 0.0))
    ecx, ecy = ecx + sdx * ro, ecy + sdy * ro
    q = np.sqrt(((xx - ecx) / ro) ** 2 + ((yy - ecy) / (ro * ASPECT)) ** 2)
    dist = np.abs(q - 1.0)
    half = BAND / 2
    aa = 1.5 / ro  # about 1.5 samples of soft edge
    ring_a = np.clip((half - dist) / aa + 0.5, 0, 1)
    rim = np.clip((dist - (half - 0.07)) / 0.04, 0, 1)  # darker edge of the band
    yrel = np.clip((yy - ecy) / (ro * ASPECT), -1, 1)
    light = 1.12 - 0.22 * (yrel + 1) / 2  # lit from the top
    ring_col = np.clip(gold_col[None, None, :] * light[..., None] * (1 - 0.28 * rim[..., None]), 0, 1)
    final = filled * (1 - ring_a[..., None]) + ring_col * ring_a[..., None]
    w = np.maximum(cv2.GaussianBlur(hole.astype(np.float32), (0, 0), SS * 0.35) * ~protect, ring_a) * (valid > 0)
    w = np.clip(w, 0, 1)
    acc = np.zeros((th, tw, 3), np.float64)
    wsum = np.zeros((th, tw), np.float64)
    cnt = np.zeros((th, tw), np.float64)
    vy, vx = np.nonzero(valid)
    t = texel[vy, vx]
    np.add.at(acc, (t[:, 1], t[:, 0]), final[vy, vx] * w[vy, vx, None])
    np.add.at(wsum, (t[:, 1], t[:, 0]), w[vy, vx])
    np.add.at(cnt, (t[:, 1], t[:, 0]), 1)
    m = (cnt > 0) & (wsum > 1e-6)
    a = np.zeros_like(wsum)
    a[m] = wsum[m] / cnt[m]
    col = np.zeros_like(acc)
    col[m] = acc[m] / wsum[m][:, None]
    out[m] = out[m] * (1 - a[m, None]) + col[m] * a[m, None]
    report.append(f"{D}: emblem {int(keep.sum())} samples, width {ew / SS:.1f}px, gold {np.round(gold_col, 2).tolist()}, texels {int(m.sum())}")
    vis = alb * (1 - w[..., None]) + final * w[..., None]  # what the written samples look like on screen
    Image.fromarray((np.clip(vis, 0, 1) * 255).astype(np.uint8)).save(f"{D}/after_screen.png")

img = (np.clip(out, 0, 1) * 255).astype(np.uint8)[::-1]  # to top-down
Image.fromarray(img).save(OUT)
print("\n".join(report))
print("->", OUT)
