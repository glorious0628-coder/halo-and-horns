"""2D half of tools/face_clean_bl.py (Blender 손보기, 10/12; SPEC A23-147): no new drawing, only the Tripo face made clean.

  py tools/face_clean_2d.py region <work_dir> [--depth-tol 0.008] [--keep 0.6]
      front.png + ray.npz -> region.png (face skin + brows on the face plane, hair left out) + face_polys.json
  py tools/face_clean_2d.py clean <work_dir>
      [--ref2d <approved 2D front.png>]  features drawn to the 2D's shapes / layout (user 10/12: 2D is the standard)
      face_color.png (baked Tripo face, planar front UV) -> face_color_clean.png + face_cmp.png (2x crops) + face_parts.png

clean: every feature keeps the Tripo shape and place; it only loses the smear.
  - dark shapes (eyes, open mouth) = dark pixels, holes filled; white (highlights, teeth) and pink (tongue) inside them;
    brows = blue blobs on the face. Each mask is smoothed (Gaussian sigma, threshold 0.5) and drawn back as ONE flat colour
    (the median of its own core) with a ~2 px soft edge.
  - small dark / blue specks that are not a feature (nostril smudge, dots) -> skin.
  - skin around the features (a band, where the smear was) = the nearby clean Tripo skin (normalized blur), so the
    nose / cheek shading of the original stays.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

a = sys.argv[1:]
MODE, WORK = a[0], os.path.abspath(a[1])


def opt(name, default):
    return type(default)(a[a.index(name) + 1]) if name in a else default


def hsv_of(rgb):
    im = Image.fromarray(rgb.astype(np.uint8)).convert("HSV")
    h = np.asarray(im).astype(np.float32)
    return h[..., 0] * 360 / 255, h[..., 1] / 255, h[..., 2] / 255


def biggest(m):
    lab, n = ndimage.label(m)
    if n == 0:
        return m
    sz = ndimage.sum(m, lab, range(1, n + 1))
    return lab == (1 + int(np.argmax(sz)))


if MODE == "region":
    tol, keep = opt("--depth-tol", 0.008), opt("--keep", 0.6)
    z = np.load(os.path.join(WORK, "ray.npz"))
    D, P = z["D"], z["P"]
    R = D.shape[0]
    rgb = np.asarray(Image.open(os.path.join(WORK, "front.png")).convert("RGB").resize((R, R), Image.LANCZOS)).astype(np.float32)
    h, s, v = hsv_of(rgb)
    skin = biggest((h >= 8) & (h <= 40) & (s >= 0.12) & (s <= 0.6) & (v >= 0.6))
    # depth above the nearby face skin: brows sit on the face (+0..0.008), hair strands stick out further
    sk = skin.astype(np.float32)
    loc = ndimage.gaussian_filter(np.nan_to_num(D) * sk, 25) / np.maximum(ndimage.gaussian_filter(sk, 25), 1e-4)
    r = D - loc
    blue = (h > 195) & (h < 255) & (s > 0.3)
    reg = biggest(ndimage.binary_fill_holes(skin | (blue & (np.abs(r) < tol))))
    # hair sticks out well past the raised brows (brow relief is up to ~0.008)
    hair = ndimage.binary_dilation(np.nan_to_num(r) > tol * 1.6, iterations=2) & ~skin
    Image.fromarray((reg * 255).astype(np.uint8)).save(os.path.join(WORK, "region.png"))
    Image.fromarray((hair * 255).astype(np.uint8)).save(os.path.join(WORK, "hair.png"))
    # nose = the big bump near the middle (kept as it is when the face is smoothed)
    yy_, xx_ = np.mgrid[0:R, 0:R]
    fit = skin & ~np.isnan(D) & (np.abs(xx_ - R / 2) < R * 0.37)
    cpl, *_ = np.linalg.lstsq(np.c_[xx_[fit], yy_[fit], np.ones(fit.sum())], D[fit], rcond=None)
    bump = np.nan_to_num(D - (cpl[0] * xx_ + cpl[1] * yy_ + cpl[2])) > 0.012
    labn, nn = ndimage.label(bump & reg)
    nose = np.zeros_like(bump)
    if nn:
        cy_, cx_ = R / 2, R / 2
        best = min(range(1, nn + 1), key=lambda k: np.hypot(*(np.array(ndimage.center_of_mass(labn == k)) - (cy_, cx_))) - 0.002 * (labn == k).sum())
        nose = ndimage.binary_dilation(labn == best, iterations=4)
    Image.fromarray((nose * 255).astype(np.uint8)).save(os.path.join(WORK, "nose.png"))
    flat_face = (np.abs(np.nan_to_num(r, nan=1.0)) < tol * 1.2)
    Image.fromarray((flat_face * 255).astype(np.uint8)).save(os.path.join(WORK, "flat_face.png"))
    ids, tot = np.unique(P[P >= 0], return_counts=True)
    inside = dict(zip(*np.unique(P[reg & (P >= 0)], return_counts=True)))
    polys = [int(i) for i, t in zip(ids, tot) if inside.get(i, 0) / t >= keep]
    json.dump({"polys": polys, "tol": tol, "keep": keep},
              open(os.path.join(WORK, "face_polys.json"), "w"))
    vis = rgb.copy()
    sel = np.isin(P, polys)
    vis[~sel] *= 0.35
    Image.fromarray(vis.astype(np.uint8)).save(os.path.join(WORK, "region_vis.png"))
    print("REGION polys", len(polys), "px", int(reg.sum()))

elif MODE == "clean":
    img = np.asarray(Image.open(os.path.join(WORK, "face_color.png")).convert("RGB")).astype(np.float32)
    N = img.shape[0]
    reg = np.asarray(Image.open(os.path.join(WORK, "region.png")).convert("L").resize((N, N), Image.NEAREST)) > 127
    # PNG row 0 = v 1 = top of the face window, u = +y = screen right: the same frame as region.png
    h, s, v = hsv_of(img)
    inner = ndimage.binary_erosion(reg, iterations=6)
    px = N / 2048.0
    amin = int(400 * px * px)

    hair = np.asarray(Image.open(os.path.join(WORK, "hair.png")).convert("L").resize((N, N), Image.NEAREST)) > 127
    bluish = (h > 195) & (h < 255) & (s > 0.3) & (v >= 0.12)
    blue = bluish & (v >= 0.2) & reg & ~hair

    def comps(m, amin_):
        lab, n = ndimage.label(m)
        out = np.zeros_like(m)
        small = np.zeros_like(m)
        for k, sl in enumerate(ndimage.find_objects(lab), 1):
            part = lab[sl] == k
            (out if part.sum() >= amin_ else small)[sl] |= part
        return out, small

    # brows first: blue blobs whose pixels mostly sit inside the face (hair comes in from the edge of the region)
    lab, n = ndimage.label(blue)
    brows = np.zeros_like(blue)
    blue_specks = np.zeros_like(blue)
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        part = lab[sl] == k
        frac_in = (part & inner[sl]).sum() / part.sum()
        if part.sum() >= amin * 4 and frac_in > 0.8:
            brows[sl] |= part
        elif part.sum() < amin * 4:
            blue_specks[sl] |= part
    brow_zone = ndimage.binary_dilation(brows, iterations=int(5 * px))
    # dark = eyes / mouth only (the dark blue rim of a brow is part of the brow, not a dark shape)
    dark = (v < 0.32) & inner & ~brow_zone & ~bluish
    white = (v > 0.80) & (s < 0.2) & inner
    pink = (((h < 22) | (h > 340)) & (s > 0.35) & (v > 0.45)) & inner
    dark_shapes, dark_specks = comps(ndimage.binary_fill_holes(ndimage.binary_closing(dark, iterations=2)), amin)

    # eyes (tall dark blobs) are clean ovals in the Tripo model and the 2D: fit an ellipse to the clean part of the
    # outline (points far off the fit = the smeared side are dropped, 4 rounds) and use it as the eye
    import cv2
    lab, n = ndimage.label(dark_shapes)
    eyes = []
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        part = lab == k
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if hh < ww * 1.15:
            continue
        cs, _ = cv2.findContours(part.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        pts = max(cs, key=len)[:, 0, :].astype(np.float32)
        keep = pts
        for _ in range(4):
            (cx, cy), (ma, mb), ang = cv2.fitEllipse(keep)
            t = np.radians(ang)
            dx, dy = pts[:, 0] - cx, pts[:, 1] - cy
            ex = dx * np.cos(t) + dy * np.sin(t)
            ey = -dx * np.sin(t) + dy * np.cos(t)
            r = np.sqrt((ex / (ma / 2)) ** 2 + (ey / (mb / 2)) ** 2)
            keep = pts[np.abs(r - 1) < max(0.012, 1.5 * np.median(np.abs(r - 1)))]
        (cx, cy), (ma, mb), ang = cv2.fitEllipse(keep)
        oval = np.zeros((N, N), np.uint8)
        S4 = 16
        cv2.ellipse(oval, (int(round(cx * S4)), int(round(cy * S4))), (int(round(ma / 2 * S4)), int(round(mb / 2 * S4))),
                    ang, 0, 360, 1, -1, cv2.LINE_8, 4)
        eyes.append(((cx, cy), (ma, mb), ang, len(keep), len(pts)))
        dark_shapes = (dark_shapes & ~part) | (oval > 0)
    # brows sit above the eyes; a big blue blob lower down (the strip under the nose) is a smudge, not a brow
    if eyes:
        top = min(e[0][1] - e[1][1] / 2 for e in eyes)
        lab, n = ndimage.label(brows)
        for k, sl in enumerate(ndimage.find_objects(lab), 1):
            if (sl[0].start + sl[0].stop) / 2 > top:
                part = lab == k
                brows &= ~part
                blue_specks |= part
    # one highlight per eye + the teeth; thin glints / tooth shards under ~900 px (2048) melt into the dark
    white_in, _ = comps(ndimage.binary_fill_holes(ndimage.binary_closing(white & ndimage.binary_erosion(dark_shapes, iterations=2), iterations=int(6 * px))), int(amin * 2.25))
    pink_in, _ = comps(pink & dark_shapes, amin)
    # eye highlights = round dots in the 2D and the Tripo model: the same oval fit (teeth keep their own shape)
    lab, n = ndimage.label(white_in)
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        part = lab == k
        cyw = (sl[0].start + sl[0].stop) / 2
        if not any(abs(cyw - e[0][1]) < e[1][1] / 2 for e in eyes):
            continue
        cs, _ = cv2.findContours(part.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        (cx, cy), (ma, mb), ang = cv2.fitEllipse(max(cs, key=len)[:, 0, :].astype(np.float32))
        dot = np.zeros((N, N), np.uint8)
        cv2.ellipse(dot, (int(round(cx * 16)), int(round(cy * 16))), (int(round(ma / 2 * 16)), int(round(mb / 2 * 16))), ang, 0, 360, 1, -1, cv2.LINE_8, 4)
        white_in = (white_in & ~part) | (dot > 0)

    def smooth(m, s_=1.6):
        # anti-aliased edge only (~2 px at 2048); the shape itself was ironed above
        g = ndimage.gaussian_filter(m.astype(np.float32), s_ * px)
        return np.clip((g - 0.5) / 0.45 + 0.5, 0, 1)

    def flat(m):
        core = ndimage.binary_erosion(m, iterations=max(2, int(4 * px)))
        core = core if core.sum() > 20 else m
        return np.median(img[core], axis=0)

    # smooth outlines like the 2D (round mouth, even brows, rounded teeth / tongue): a mask blurred by its own sigma
    # and cut at 0.5 keeps the shape and place but irons out the wobble; eyes / highlights are already ovals
    def iron(m, s_):
        return ndimage.gaussian_filter(m.astype(np.float32), s_ * px) > 0.5 if m.any() else m

    # eyes like the approved 2D (user 10/12 "눈이 2D랑 달라"): measured on NPC_HaloMailBoy_front_HQ_src.png -
    # pill shape (superellipse n 2.6), width = 0.56 x height, one upright oval highlight (x 0.34-0.61, y 0.16-0.36 of
    # the eye box), a thin light cream rim (~3 % of the eye height). Place = the Tripo eye centres; both eyes the same size.
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)

    def pill(cx, cy, a_, b_, n_=2.6):
        return (np.abs((xx - cx) / a_) ** n_ + np.abs((yy - cy) / b_) ** n_) <= 1.0

    eye_mask = np.zeros_like(dark_shapes)
    eye_white = np.zeros_like(dark_shapes)
    rim = np.zeros_like(dark_shapes)
    if eyes:
        EH = float(np.mean([max(e[1]) for e in eyes]))
        EW = 0.56 * EH
        for (cx, cy), _, _, _, _ in eyes:
            eye_mask |= pill(cx, cy, EW / 2, EH / 2)
            rim |= pill(cx, cy, EW / 2 + 0.03 * EH, EH / 2 + 0.03 * EH)
            hx, hy = cx - EW / 2 + 0.475 * EW, cy - EH / 2 + 0.26 * EH
            eye_white |= ((xx - hx) / (0.135 * EW)) ** 2 + ((yy - hy) / (0.10 * EH)) ** 2 <= 1.0
        rim &= ~eye_mask
        print("EYE size", round(EW), "x", round(EH))
    mouth = iron(dark_shapes & ~ndimage.binary_dilation(eye_mask, iterations=int(30 * px)), 8)
    dark_shapes = eye_mask | mouth
    brows = iron(brows, 6)
    teeth = iron(white_in & ~eye_mask, 5) & ndimage.binary_erosion(mouth, iterations=int(3 * px))
    white_in = eye_white | teeth
    pink_in = iron(pink_in, 6) & ndimage.binary_erosion(mouth, iterations=int(3 * px))
    cols2d = {}
    ref = opt("--ref2d", "")
    if ref:
        # user 10/12: "트리포 기준이 아니고, 2D 기준이야" - every feature takes the approved 2D's shape, size and
        # arrangement (not a decal: drawn as clean flat shapes, the Tripo skin and shading stay). The 2D layout is
        # placed by a least-squares scale + shift of its eye / mouth centres onto the Tripo ones, so it stays on the
        # sculpted eye / mouth bumps of the mesh.
        tripo_feats = dark_shapes | brows | rim | ndimage.binary_dilation(white_in, iterations=2)
        r2 = np.asarray(Image.open(ref).convert("RGB")).astype(np.float32)
        h2, s2, v2 = hsv_of(r2)
        sk2 = (h2 >= 8) & (h2 <= 40) & (s2 >= 0.12) & (s2 <= 0.6) & (v2 >= 0.6)
        sk2[int(r2.shape[0] * 0.5):] = False
        sk2 = biggest(sk2)
        face2 = ndimage.binary_fill_holes(sk2)
        lab2, n2 = ndimage.label(face2 & ~sk2)
        f2 = {"eye": [], "mouth": [], "brow": []}
        for k, sl in enumerate(ndimage.find_objects(lab2), 1):
            part = lab2 == k
            if part.sum() < 60:
                continue
            hh_, ww_ = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
            mc = np.median(r2[part], axis=0)
            hm = hsv_of(mc[None, None, :])[0][0, 0]
            if 195 < hm < 255 and mc[2] > mc[0] + 25:
                f2["brow"].append(part)
            elif hh_ > ww_ * 1.2:
                f2["eye"].append(part)
            elif ww_ > hh_:
                f2["mouth"].append(part)
        f2["mouth"] = sorted(f2["mouth"], key=lambda m: -m.sum())[:1]
        cen = lambda m: np.array(ndimage.center_of_mass(m))[::-1]
        eyes2 = sorted(f2["eye"], key=lambda m: cen(m)[0])
        # Tripo centres: the eye fits + the mouth blob
        e3 = sorted([np.array(e[0]) for e in eyes], key=lambda c: c[0])
        P2 = [cen(m) for m in eyes2] + [cen(f2["mouth"][0])]
        P3 = e3 + [cen(mouth)]
        P2, P3 = np.array(P2), np.array(P3)
        c2, c3 = P2.mean(0), P3.mean(0)
        k_ = float(((P3 - c3) * (P2 - c2)).sum() / ((P2 - c2) ** 2).sum())
        json.dump({"k": k_, "c2": c2.tolist(), "c3": c3.tolist()}, open(os.path.join(WORK, "ref2d_map.json"), "w"))
        print("REF2D scale", round(k_, 2), "centres 2D->3D err px", np.round(np.linalg.norm((P2 - c2) * k_ + c3 - P3, axis=1), 1))

        y3_, x3_ = np.mgrid[0:N, 0:N].astype(np.float32)
        X2, Y2 = (x3_ - c3[0]) / k_ + c2[0], (y3_ - c3[1]) / k_ + c2[1]
        del y3_, x3_

        def to3(m2, sig2=0.4, thr=0.5):
            # 2D soft mask (anti-aliased edge kept as 0..1) -> texture: cubic sample + light blur, cut at thr;
            # the edge lands between 2D pixels, so no 1024 px stair-steps (thin shapes: thr < 0.5 so the blur
            # does not make them thinner than the 2D)
            f = ndimage.map_coordinates(m2.astype(np.float32), [Y2, X2], order=3, mode="constant")
            return ndimage.gaussian_filter(f, sig2 * k_) > thr

        def med2(m2):
            return np.median(r2[m2], axis=0)

        white2 = (v2 > 0.8) & (s2 < 0.2)
        pink2 = ((h2 < 22) | (h2 > 340)) & (s2 > 0.35) & (v2 > 0.45)
        eye2 = np.zeros_like(sk2)
        for m in eyes2:
            eye2 |= m
        mouth2 = f2["mouth"][0]
        brow2 = np.zeros_like(sk2)
        for m in f2["brow"]:
            brow2 |= m
        hl2 = white2 & eye2
        teeth2 = white2 & mouth2
        tongue2 = pink2 & mouth2
        # soft versions (coverage from the 2D's own anti-aliasing) for drawing
        vs_, vd_ = float(np.median(v2[sk2])), 0.1
        darkness = np.clip((vs_ - v2) / (vs_ - vd_), 0, 1)
        whiteness = np.clip((v2 - 0.5) / 0.4, 0, 1) * np.clip((0.35 - s2) / 0.2, 0, 1)
        pinkness = np.clip((s2 - 0.25) / 0.25, 0, 1) * (((h2 < 30) | (h2 > 330)) & (v2 > 0.35))
        blueness = np.clip((s2 - 0.15) / 0.3, 0, 1) * ((h2 > 190) & (h2 < 260))

        def soft(m, a_):
            inside = ndimage.binary_erosion(m, iterations=1)
            return np.where(inside, 1.0, a_ * ndimage.binary_dilation(m, iterations=2))

        eye2s = soft(eye2, darkness)
        mouth2s = soft(mouth2, darkness)
        brow2s = np.where(ndimage.binary_erosion(brow2), 1.0, blueness * ndimage.binary_dilation(brow2, iterations=2))
        hl2s = whiteness * ndimage.binary_erosion(eye2, iterations=1)
        teeth2s = whiteness * ndimage.binary_erosion(mouth2, iterations=1)
        tongue2s = pinkness * ndimage.binary_erosion(mouth2, iterations=1)
        # rims: a thin ring lighter than the skin around a feature in the 2D -> drawn the same
        skin_c = med2(ndimage.binary_dilation(eye2 | mouth2, iterations=6) & ~ndimage.binary_dilation(eye2 | mouth2, iterations=4) & sk2)
        rim2 = np.zeros_like(sk2)
        rim_cols = []
        for m in [eye2, mouth2]:
            rr = [ndimage.binary_dilation(m, iterations=1) & ~m,
                  ndimage.binary_dilation(m, iterations=2) & ~ndimage.binary_dilation(m, iterations=1)]
            cc = [med2(r_) for r_ in rr]
            c_ = max(cc, key=lambda c: c[1] + c[2])
            if (c_[1] + c_[2]) - (skin_c[1] + skin_c[2]) > 8:  # the 2D's faint cream rim (G/B up ~10)
                rim2 |= rr[0] | rr[1]
                rim_cols.append(c_)
        # blur per feature, in 2D pixels: the 2D eye is only ~21 px wide, its JPEG-ish steps must go, not its shape
        eye_mask = to3(eye2s, 0.9)
        mouth = to3(mouth2s, 0.9)
        dark_shapes = eye_mask | mouth
        brows = to3(brow2s, 0.9, 0.4)
        # teeth: the 2D's straight-sided blocks with round corners -> a fitted rotated box, corners rounded ~22 %
        t3 = to3(teeth2s, 0.7, 0.42) & mouth
        teeth = np.zeros_like(t3)
        lab_, n_ = ndimage.label(t3)
        for k2 in range(1, n_ + 1):
            part = lab_ == k2
            if part.sum() < 200:
                continue
            cs, _ = cv2.findContours(part.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            (cx, cy), (bw, bh), ang = cv2.minAreaRect(max(cs, key=len))
            rr_ = 0.22 * min(bw, bh)
            box = np.zeros((N, N), np.uint8)
            inner_box = cv2.boxPoints(((cx, cy), (max(bw - 2 * rr_, 1), max(bh - 2 * rr_, 1)), ang))
            cv2.fillPoly(box, [np.round(inner_box).astype(np.int32)], 1)
            box = cv2.dilate(box, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(2 * rr_) | 1, int(2 * rr_) | 1)))
            teeth |= (box > 0) & part.any()
        teeth &= ndimage.binary_erosion(mouth, iterations=int(3 * px))
        pink_in = to3(tongue2s, 0.9, 0.4) & mouth
        # highlights: the 2D's upright oval dots, fitted as exact ellipses
        hl3 = to3(hl2s, 0.6) & eye_mask
        eye_white = np.zeros_like(hl3)
        lab_, n_ = ndimage.label(hl3)
        for k2 in range(1, n_ + 1):
            part = lab_ == k2
            if part.sum() < 50:
                continue
            cs, _ = cv2.findContours(part.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            (cx, cy), (ma, mb), ang = cv2.fitEllipse(max(cs, key=len)[:, 0, :].astype(np.float32))
            dot = np.zeros((N, N), np.uint8)
            cv2.ellipse(dot, (int(round(cx * 16)), int(round(cy * 16))), (int(round(ma / 2 * 16)), int(round(mb / 2 * 16))), ang, 0, 360, 1, -1, cv2.LINE_8, 4)
            eye_white |= dot > 0
        white_in = eye_white | teeth
        rim = to3(np.maximum(rim2.astype(np.float32), np.maximum(eye2s, mouth2s)), 0.9) & ~dark_shapes if rim_cols else np.zeros_like(eye_mask)
        cols2d = {"dark": med2(eye2 & (v2 < 0.3)), "brow": med2(ndimage.binary_erosion(brow2)), "white": med2(hl2),
                  "teeth": med2(teeth2), "pink": med2(ndimage.binary_erosion(tongue2)),
                  "rim": np.mean(rim_cols, axis=0) if rim_cols else np.array([252, 214, 174])}
        print("REF2D colours", {k: [int(x) for x in c] for k, c in cols2d.items()}, "rims", len(rim_cols))
        feats = dark_shapes | brows | rim | tripo_feats
    else:
        teeth = teeth if "teeth" in dir() else white_in
        feats = dark_shapes | brows | rim
    # smear = darkish (not skin-light) pixels next to a feature that are not part of it
    near = ndimage.binary_dilation(feats, iterations=int(40 * px)) & ~feats
    # plus anything next to a feature that differs clearly from the nearby clean skin (stray dots, grey streaks)
    cs0 = reg & ~ndimage.binary_dilation(feats | (v < 0.55) | bluish, iterations=int(5 * px))
    w0 = ndimage.gaussian_filter(cs0.astype(np.float32), 10 * px)
    u0 = np.stack([ndimage.gaussian_filter(img[..., c] * cs0, 10 * px) for c in range(3)], -1) / np.maximum(w0, 1e-4)[..., None]
    odd = near & inner & ~bluish & (np.abs(img - u0).sum(-1) > 30)
    smear = ndimage.binary_dilation(((v < 0.62) & ~bluish & inner & near) | odd | (dark & ~dark_shapes), iterations=3) | dark_specks
    # band = where the smear was; never over hair (blue that is not a brow)
    hair_px = ndimage.binary_dilation(bluish & ~brow_zone & ~blue_specks, iterations=int(3 * px))
    band = ndimage.binary_dilation(feats | smear, iterations=int(18 * px)) & ndimage.binary_dilation(reg, iterations=int(8 * px)) & ~hair_px
    clean_skin = reg & ~hair_px & ~ndimage.binary_dilation(feats | smear | (v < 0.55), iterations=int(5 * px))
    w = ndimage.gaussian_filter(clean_skin.astype(np.float32), 14 * px)
    under = np.stack([ndimage.gaussian_filter(img[..., c] * clean_skin, 14 * px) for c in range(3)], -1) / np.maximum(w, 1e-4)[..., None]
    out = img.copy()
    # blue specks away from the features (the smudge under the nose): filled from their own rim, so the nose shading stays
    faint_blue = (h > 185) & (h < 265) & (s > 0.1)
    spk = ndimage.binary_dilation(blue_specks | (faint_blue & ndimage.binary_dilation(blue_specks, iterations=int(14 * px))), iterations=int(4 * px))
    skinlike = (h >= 5) & (h <= 40) & (s > 0.25) & (v > 0.55)
    spk |= ndimage.binary_dilation(spk, iterations=int(4 * px)) & ~skinlike
    ring = ndimage.binary_dilation(spk, iterations=int(12 * px)) & ~spk & skinlike
    wr = ndimage.gaussian_filter(ring.astype(np.float32), 5 * px)
    fill = np.stack([ndimage.gaussian_filter(img[..., c] * ring, 5 * px) for c in range(3)], -1) / np.maximum(wr, 1e-4)[..., None]
    out[spk & (wr > 1e-3)] = fill[spk & (wr > 1e-3)]
    use = band & (w > 1e-3) & ~spk
    if cols2d:
        # Tripo brow bits that the 2D brow does not cover (blue on the face plane, not hair geometry) -> skin too
        flatb = np.asarray(Image.open(os.path.join(WORK, "flat_face.png")).convert("L").resize((N, N), Image.BILINEAR)) > 127
        stray = ndimage.binary_dilation(bluish & flatb & ~ndimage.binary_dilation(brows, iterations=int(2 * px)), iterations=int(4 * px)) & (w > 1e-3)
        use |= stray
    out[use] = under[use]
    cols = {}
    for name, m in (("rim", rim | (dark_shapes if cols2d else eye_mask)), ("dark", dark_shapes), ("brow", brows),
                    ("pink", pink_in), ("white", eye_white if cols2d else white_in), ("teeth", teeth if cols2d else teeth & False)):
        if not m.any() or (name == "rim" and not rim.any()):
            continue
        if name in cols2d:
            col = np.asarray(cols2d[name], np.float32)
        else:
            col = np.array([252, 214, 174], np.float32) if name == "rim" else flat(m)
        cols[name] = [int(x) for x in col]
        cov = smooth(m)
        if name in ("pink", "white", "teeth"):
            cov = cov * smooth(dark_shapes)
        out = out * (1 - cov[..., None]) + col * cov[..., None]
    print("EYES", [(round(e[0][0]), round(e[0][1]), round(e[1][0]), round(e[1][1]), round(e[2]), f"{e[3]}/{e[4]}") for e in eyes])
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(os.path.join(WORK, "face_color_clean.png"))
    parts = np.zeros((N, N, 3), np.uint8)
    parts[reg] = (90, 70, 60)
    parts[band] = (140, 110, 90)
    parts[dark_shapes] = (20, 20, 20)
    parts[brows] = (40, 60, 200)
    parts[white_in] = (255, 255, 255)
    parts[pink_in] = (240, 110, 100)
    parts[dark_specks | blue_specks] = (0, 255, 0)
    parts[spk & ~(dark_specks | blue_specks)] = (0, 140, 0)
    parts[ring] = (255, 0, 255)
    Image.fromarray(parts).save(os.path.join(WORK, "face_parts.png"))
    print("CLEAN colours", cols, "specks", int((dark_specks | blue_specks).sum()))
