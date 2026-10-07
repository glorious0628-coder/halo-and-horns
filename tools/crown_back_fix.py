"""
Crown of Balance B2 (Tripo, 2026-10-07): repaint the back that Tripo invented (a gold->orange fade, dark navy gems, no
crack) so the split reads from every side, texture only (0 credits; 검수: "오른쪽 반은 진홍, 뒤 가운데에 빛나는 금 간 선,
보석은 앞과 같은 파랑·빨강").

  for v in back back34L right back34 left:  (the dumps must have pos/nor: hit points and normals)
    blender ... tools/castle_window_dump.py -- art/models/tripo/Crown_Broken_B_raw.glb <dir_v> --screen 382,411,110,92 \
        --view $v --ss 3
  py tools/crown_back_fix.py <out_1024.png> <dir_back>:back <dir_v>:<v> ... [--debug]

Each view is classified in its own screen space (3D hit point + normal + the ORIGINAL texture colour), then every
texel takes the vote of all views weighted by how squarely each view saw it (a stud half-hidden at a grazing angle in
one view is decided by the view that faces it):
- crimson half = the back half (X < axis) above the crack plane Y0 (the front crack sits at the same plane) plus the
  inside of the front wall above Y_IN; feathered into the original front crimson around the +Y side (theta 92..122);
- gold kept = raised round parts (studs, balls: closed rings of tilted surface, curved, gold in the original) and an
  ellipse fitted to each gem's rim; red horns kept whole;
- back gems: front ruby / sapphire colour ramps (measured from this texture) by each texel's brightness rank in its gem,
  red on the crimson side, blue on the gold side (front gems are never touched);
- the crack: a glowing zigzag seam (pale gold core, orange glow) on the back wall, from the 3D distance to the plane.
Written into a 1024 copy of the texture (Roblox size; writing at 4096 leaves texel gaps).
"""
import argparse
import math

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("dumps", nargs="+", help="<dump dir>:<view>, the back view first")
ap.add_argument("--debug", action="store_true")
a = ap.parse_args()

T = 1024
VIEWS = {"front": (0, 8), "front34": (30, 12), "front34L": (-30, 12), "game": (20, 35), "back34": (210, 12),
         "back": (180, 8), "back34L": (150, 12), "left": (-90, 8), "right": (90, 8)}  # = castle_window_dump.py
Y0, AMP, PER = -0.300, 0.030, 0.24  # crack plane (normalised space, crown height 2) and its zigzag in Y over Z
Y_IN = -0.14  # inside of the front wall: its gold centre spike + ball (the front crack's notch) end at Y ~ -0.15
BASE = np.array([0.53, 0.11, 0.12], np.float32)  # crimson body, between the front side's albedo and a clean crimson
HI = np.array([0.82, 0.20, 0.22], np.float32)  # its highlights
RAMPS = {"ruby": [[0.427, 0.008, 0.012], [0.553, 0.004, 0.02], [0.627, 0.0, 0.039], [0.671, 0.004, 0.043],
                  [0.745, 0.0, 0.043], [0.776, 0.0, 0.047], [0.816, 0.0, 0.051], [0.882, 0.008, 0.059],
                  [0.788, 0.086, 0.129], [0.843, 0.114, 0.176], [0.855, 0.173, 0.227], [0.933, 0.612, 0.643]],
         "sapphire": [[0.039, 0.106, 0.529], [0.039, 0.149, 0.604], [0.047, 0.231, 0.733], [0.047, 0.29, 0.835],
                      [0.055, 0.325, 0.855], [0.043, 0.349, 0.914], [0.039, 0.38, 0.957], [0.027, 0.404, 0.976],
                      [0.035, 0.424, 0.988], [0.035, 0.459, 0.988], [0.027, 0.502, 0.988], [0.55, 0.82, 1.0]]}
LUMW = np.array([0.2126, 0.7152, 0.0722], np.float32)

first = a.dumps[0].rsplit(":", 1)[0]
orig = np.clip(cv2.resize(np.load(f"{first}/tex0.npy")[..., :3].astype(np.float32), (T, T),
                          interpolation=cv2.INTER_AREA), 0, 1)  # bottom-up rows like the dumps
orig_lum = orig @ LUMW


def disc(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


# crown axis: circle fit on the band in the back dump (all dumps share the same normalised space)
z0 = np.load(f"{first}/dump.npz")
P0, v0 = z0["pos"], z0["valid"] > 0
m0 = v0 & (P0[..., 2] > 0.35) & (P0[..., 2] < 0.9)
c0 = np.linalg.lstsq(np.column_stack([P0[..., 0][m0], P0[..., 1][m0], np.ones(m0.sum())]),
                     P0[..., 0][m0] ** 2 + P0[..., 1][m0] ** 2, rcond=None)[0]
AX, AY = c0[0] / 2, c0[1] / 2
del z0, P0, v0, m0

NT = T * T
acc = {k: np.zeros(NT) for k in ("Q", "QG", "QH", "QB", "QS")}
GLOW = np.zeros(NT)
CORE = np.zeros(NT)
gems = []  # global list: {"c": 3D centre, "red": bool, "QK": per-texel votes}
debug_imgs = []


def fit_sphere(Pm, Nm):
    # P = C + R n  ->  linear least squares in (C, R); returns C, R, rms
    A = np.zeros((len(Pm) * 3, 4))
    A[0::3, 0] = A[1::3, 1] = A[2::3, 2] = 1
    A[:, 3] = Nm.reshape(-1)
    sol = np.linalg.lstsq(A, Pm.reshape(-1), rcond=None)[0]
    C, R = sol[:3], sol[3]
    return C, R, float(np.sqrt(((Pm - C - R * Nm) ** 2).sum(-1).mean()))


spheres = []  # studs / balls found in any view, as 3D spheres (centre, radius): applied to every view


def process(d, view, find_only=False):
    z = np.load(f"{d}/dump.npz")
    texel, valid, P, N = z["texel"], z["valid"] > 0, z["pos"], z["nor"]
    H, W = valid.shape
    tx = np.clip((texel[..., 0] * T / 4096).astype(np.int64), 0, T - 1)
    ty = np.clip((texel[..., 1] * T / 4096).astype(np.int64), 0, T - 1)
    alb = orig[ty, tx]
    X, Y, Z = P[..., 0], P[..., 1], P[..., 2]
    r = np.hypot(X - AX, Y - AY) + 1e-9
    dot = (N[..., 0] * (X - AX) + N[..., 1] * (Y - AY)) / r
    outer = valid & (dot > 0)
    tilt = 1 - dot
    hsv = cv2.cvtColor((alb * 255).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    hue, sat, val = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    az, el = (math.radians(x) for x in (VIEWS[view][0] + 90, VIEWS[view][1]))
    vd = np.array([math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)], np.float32)
    q = np.clip(N @ vd, 0, 1) * valid  # how squarely this view sees the sample

    # ---- back gems: blue / purple facets (+ the red facets inside) -> convex discs; rim = fitted outer ellipse
    facet = valid & outer & (hue > 180) & (hue < 345) & (sat > 0.25) & (Z > 0.2) & (Z < 1.0) & (X < AX)
    n, lab, st, _ = cv2.connectedComponentsWithStats(cv2.dilate(facet.astype(np.uint8), disc(4)), 8)
    gem_id = -np.ones((H, W), np.int32)
    rim = np.zeros((H, W), bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 3000:
            continue
        hull = cv2.convexHull(np.column_stack(np.nonzero(lab == i))[:, ::-1].astype(np.int32))
        g = np.zeros((H, W), np.uint8)
        cv2.fillConvexPoly(g, hull, 1)
        g = (cv2.erode(g, disc(2)) > 0) & valid
        if g.sum() < 2000 or np.median(q[g]) < 0.45:  # seen too much from the side: leave it to a better view
            continue
        gy, gx = np.nonzero(g)
        gc = np.array([gx.mean(), gy.mean()])
        pts = []
        for ang in np.radians(np.arange(0, 360, 3)):
            dv = np.array([np.cos(ang), np.sin(ang)])
            s = np.arange(0, 400)
            pq = np.round(gc[None] + s[:, None] * dv[None]).astype(int)
            ok = (pq[:, 0] >= 0) & (pq[:, 0] < W) & (pq[:, 1] >= 0) & (pq[:, 1] < H)
            pq, s = pq[ok], s[ok]
            ing = g[pq[:, 1], pq[:, 0]]
            if not ing.any():
                continue
            e = s[ing].max()
            tl = np.where(valid[pq[:, 1], pq[:, 0]], tilt[pq[:, 1], pq[:, 0]], 1.0)
            for j in range(e + 1, min(len(s) - 20, int(e * 1.7) + 8)):  # a long flat run = the band (ridge is short)
                if tl[j] > 0.10 and (tl[j + 1:j + 21] < 0.05).all():
                    pts.append(gc + dv * s[j + 1])
                    break
        if len(pts) < 12:
            continue
        pts = np.array(pts, np.float32)
        dist = np.hypot(*(pts - gc).T)
        keep = np.abs(dist / np.median(dist) - 1) < 0.18
        if keep.sum() < 8:
            continue
        ell = cv2.fitEllipse(pts[keep])
        ring = np.zeros((H, W), np.uint8)
        cv2.ellipse(ring, ell, 1, -1)
        full = (ring > 0) & valid
        if not 1.0 <= full.sum() / g.sum() <= 2.4:  # a bad fit (rim merged with something): skip this view's gem
            continue
        c3 = np.median(P[g], axis=0)
        k = next((j for j, gm in enumerate(gems) if np.linalg.norm(gm["c"] - c3) < 0.3), None)
        if k is None:
            k = len(gems)
            gems.append({"c": c3, "red": bool(c3[1] > Y0), "QK": np.zeros(NT)})
        gem_id[g] = k
        rim |= full & ~g
    gem_any = gem_id >= 0
    rim &= ~gem_any

    # ---- studs and balls: closed rings of tilted surface -> filled; gold in the original, round and curved
    mk = (valid & (tilt > 0.10)).astype(np.uint8)
    mk = cv2.morphologyEx(mk, cv2.MORPH_CLOSE, disc(3))
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats((1 - mk).astype(np.uint8), 4)
    fill = mk.copy()
    for i in range(1, n2):
        x, y, w, h, ar = st2[i]
        if ar < 40000 and x > 0 and y > 0 and x + w < W and y + h < H:
            fill[lab2 == i] = 1
    goldish = (hue > 30) & (sat > 0.3) & (val > 0.5)
    op = cv2.morphologyEx(((fill > 0) & goldish).astype(np.uint8), cv2.MORPH_OPEN, disc(11))
    curv = np.zeros((H, W), np.float32)
    for dx, dy in ((3, 0), (0, 3), (-3, 0), (0, -3)):
        curv = np.maximum(curv, 1 - (N * np.roll(np.roll(N, dy, 0), dx, 1)).sum(-1))
    curv[~valid] = 0
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(op, 8)
    studs = np.zeros((H, W), bool)
    for i in range(1, n3):
        x, y, w, h, ar = st3[i]
        cm = lab3 == i
        if ar < 400 or ar > 40000 or (cm & (gem_any | rim)).sum() > 0.2 * ar:
            continue
        if ar / (np.pi * (max(w, h) / 2) ** 2) > 0.4 and np.median(curv[cm]) > 0.008:
            studs |= cv2.dilate(cm.astype(np.uint8), disc(3)) > 0
            if find_only:
                C, R, rms = fit_sphere(P[cm & valid], N[cm & valid])
                if 0.015 < R < 0.25 and rms < 0.12 * R and not any(np.linalg.norm(C - c) < 0.5 * rr for c, rr in spheres):
                    spheres.append((C, R))
    if find_only:
        return
    for C, R in spheres:  # the same studs and balls in every view, even where this view sees them merged or edge-on
        studs |= np.linalg.norm(P - C, axis=-1) < R * 1.08
    studs &= valid & ~gem_any & ~rim
    gold = studs | rim

    # ---- horns are already red: keep them whole (closed + filled, with their pale highlights and lowest folds)
    hr = (valid & ((hue < 14) | (hue > 336)) & (sat > 0.5) & (Z > 1.12)).astype(np.uint8)
    hr = cv2.morphologyEx(hr, cv2.MORPH_CLOSE, disc(7))
    near = cv2.dilate(hr, disc(15)) > 0
    shine = valid & (val > 0.88) & (sat < 0.6) & (Z > 1.12) & near
    low = valid & ((hue < 14) | (hue > 336)) & (sat > 0.5) & (Z > 1.05) & near
    hr = cv2.morphologyEx(hr | shine.astype(np.uint8) | low.astype(np.uint8), cv2.MORPH_CLOSE, disc(5))
    n4, lab4, st4, _ = cv2.connectedComponentsWithStats((1 - hr).astype(np.uint8), 4)
    for i in range(1, n4):
        if st4[i, cv2.CC_STAT_AREA] < 20000:
            hr[lab4 == i] = 1
    horn = (hr > 0) & valid & (Z > 1.05)

    # ---- the split and the crimson body (feathered into the original front crimson around the +Y side)
    zig = AMP * (4 * np.abs((Z / PER) % 1.0 - 0.5) - 1)  # triangle wave in [-AMP, AMP]
    back = valid & (X < AX)
    theta = np.degrees(np.arctan2(Y - AY, X - AX)) % 360  # +X 0, +Y 90, back 180
    crim = (back & (dot > -0.3) & (Y > Y0 + zig)) | (valid & ~back & (dot < 0.2) & (Y > Y_IN))
    body = crim & ~gold & ~gem_any & ~horn
    f = np.clip((theta - 92) / 30, 0, 1)
    feather = np.where(back, f * f * (3 - 2 * f), 1.0)
    w_body = np.clip(cv2.GaussianBlur(body.astype(np.float32), (0, 0), 0.8), 0, 1) * feather * valid
    bm = (valid & ~gem_any & ~gold).astype(np.float32)
    vs = cv2.GaussianBlur(val * bm, (0, 0), 40) / np.maximum(cv2.GaussianBlur(bm, (0, 0), 40), 1e-4)
    shade = np.clip(val / np.maximum(vs, 1e-3), 0.3, 1.6)

    # ---- the crack, from the 3D distance to the zigzag plane, on the back wall only
    dY = np.abs(Y - (Y0 + zig))
    crack_ok = back & (dot > -0.3) & ~gem_any & ~rim & ~studs
    core = np.clip((0.0085 - dY) / 0.003, 0, 1) * crack_ok
    glow = np.exp(-(dY / 0.022) ** 2) * 0.8 * crack_ok

    # ---- votes into the texels
    vy, vx = np.nonzero(valid)
    ti = (ty[vy, vx] * T + tx[vy, vx]).astype(np.int64)
    qv = q[vy, vx]
    acc["Q"] += np.bincount(ti, qv, NT)
    acc["QG"] += np.bincount(ti, qv * gold[vy, vx], NT)
    acc["QH"] += np.bincount(ti, qv * horn[vy, vx], NT)
    acc["QB"] += np.bincount(ti, qv * w_body[vy, vx], NT)
    acc["QS"] += np.bincount(ti, qv * w_body[vy, vx] * shade[vy, vx], NT)
    np.maximum.at(GLOW, ti, glow[vy, vx])
    np.maximum.at(CORE, ti, core[vy, vx])
    gv = gem_id[vy, vx]
    for k in np.unique(gv[gv >= 0]):
        gems[k]["QK"] += np.bincount(ti, qv * (gv == k), NT)
    if a.debug:
        dbg = np.zeros((H, W, 3), np.float32) + 0.5
        dbg[valid] = alb[valid] * 0.35
        dbg[crim] += np.array([0.25, 0, 0])
        dbg[studs] = (1, 1, 0)
        dbg[rim] = (1, 0.6, 0)
        dbg[gem_any] = (0, 0.8, 1)
        dbg[horn] = (1, 0, 1)
        debug_imgs.append((view, dbg))
    print(f"[{view}] gems seen {sorted(set(gv[gv >= 0].tolist()))}, stud px {int(studs.sum())}, rim px {int(rim.sum())}")


for spec in a.dumps:  # pass 1: studs and balls as 3D spheres
    dd, vw = spec.rsplit(":", 1)
    process(dd, vw, find_only=True)
print(f"spheres {len(spheres)}: radii {sorted(round(float(r), 3) for _, r in spheres)}")
gems.clear()
for spec in a.dumps:  # pass 2: classify and vote
    dd, vw = spec.rsplit(":", 1)
    process(dd, vw)

# ---- per-texel decision
Q = acc["Q"]
seen = Q > 1e-4
out = orig.reshape(-1, 3).astype(np.float64).copy()
o_flat = orig.reshape(-1, 3)
is_gold = seen & (acc["QG"] > 0.25 * Q)
gem_best = -np.ones(NT, np.int64)
gem_frac = np.zeros(NT)
for k, gm in enumerate(gems):
    fr = np.where(seen, gm["QK"] / np.maximum(Q, 1e-9), 0)
    better = fr > gem_frac
    gem_best[better] = k
    gem_frac[better] = fr[better]
is_gem = seen & ~is_gold & (gem_frac > 0.3)
is_horn = seen & ~is_gold & ~is_gem & (acc["QH"] > 0.5 * Q)
alpha = np.where(seen, acc["QB"] / np.maximum(Q, 1e-9), 0)
body = seen & ~is_gold & ~is_gem & ~is_horn & (alpha > 0.01)
sh = np.clip(acc["QS"] / np.maximum(acc["QB"], 1e-9), 0, 1.6)
cr = BASE[None] * np.clip(sh, 0, 1.1)[:, None]
hl = np.clip((sh - 1.08) / 0.3, 0, 1)[:, None]
cr = cr * (1 - hl) + HI[None] * hl
al = np.clip(alpha, 0, 1)[:, None]
out[body] = o_flat[body] * (1 - al[body]) + cr[body] * al[body]
for k, gm in enumerate(gems):
    sel = np.nonzero(is_gem & (gem_best == k))[0]
    if len(sel) == 0:
        continue
    rp = np.array(RAMPS["ruby" if gm["red"] else "sapphire"], np.float32)
    lum = orig_lum.reshape(-1)[sel]
    rank = np.argsort(np.argsort(lum)) / max(len(sel) - 1, 1)
    idx = rank * (len(rp) - 1)
    i0 = np.floor(idx).astype(int)
    i1 = np.minimum(i0 + 1, len(rp) - 1)
    fr = (idx - i0)[:, None]
    out[sel] = rp[i0] * (1 - fr) + rp[i1] * fr
    print(f"gem {k} {'red' if gm['red'] else 'blue'} centre {np.round(gm['c'], 2).tolist()} texels {len(sel)}")
plain = ~is_gold & ~is_gem
gl = np.where(plain, GLOW, 0)[:, None]
co = np.where(plain, CORE, 0)[:, None]
out = out * (1 - gl) + np.array([1.0, 0.6, 0.16]) * gl
out = out * (1 - co) + np.array([1.0, 0.96, 0.72]) * co
res = np.clip(out.reshape(T, T, 3), 0, 1)
Image.fromarray((res * 255 + 0.5).astype(np.uint8)[::-1]).save(a.out)
if a.debug:
    for vw, dbg in debug_imgs:
        Image.fromarray((np.clip(dbg, 0, 1) * 255).astype(np.uint8)).save(a.out.rsplit(".", 1)[0] + f"_debug_{vw}.png")
print(f"axis ({AX:.3f},{AY:.3f}); texels: gold {int(is_gold.sum())}, gem {int(is_gem.sum())}, horn {int(is_horn.sum())},"
      f" body {int(body.sum())}, crack {int((CORE > 0.01).sum())} -> {a.out}")
