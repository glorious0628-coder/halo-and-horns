"""Make a square ground texture tile seamlessly (wraps on all four sides) and write a 3x3 check sheet.

Usage:
  py tools/make_tileable.py <src.png> <out.png> [--overlap 160] [--size 1024] [--check art/review/<name>_3x3.png]
                           [--prefer-dark 0.3] (cobbles/planks: cut along dark gaps; -0.3 = bright gaps, lava) [--search]
                           [--reseat]          (round cobbles with clear mortar: re-seat whole stones over the seam cross)
                           [--graphcut]        (experimental free-shape seam; usually worse than the default cut)
                           [--grid x|y|xy]     (paving grids / plank rows: crop whole cells, no blending)

Which mode (checked 2026-10-06 on 100% seam crops):
  - default cut (+ --prefer-dark 0.3 --search for slabs/boulders, -0.3 for glowing lava cracks): grass,
    dirt, sand, flagstones, basalt, limestone, rock, lava.
  - --reseat: round cobbles separated by clear mortar (Tex_Cobblestone). Fails on thin-gap slabs.
  - --grid: regular paving grids and plank rows.
  - --graphcut: tends to cut straight through stones; kept only for experiments.
  - bark / vertical grain: --search --gap-weight 1 --feather-y 32 (wide blend on the top/bottom wrap so grain
    lines fade into each other instead of stepping every tile).
  - --gap-weight 1 (with --prefer-dark 0.3 --search): flagstones/basalt slabs - the cut avoids spots where one
    strip has a gap and the other has stone (a gap ending mid-slab). "gap breaks" in the report = share of
    cut rows that still end a gap; keep it near 0 and check the 2x2 seam crop at 100%.

How it works (image-quilting style, no AI):
  1. Horizontal wrap: the right strip (width = overlap) is laid over the left strip. Per row a
     cut column is chosen by dynamic programming so the cut follows the smallest colour
     difference between the two strips; left of the cut uses the right strip, right of it the
     left strip, with a short feather. The tile loses `overlap` columns and now wraps sideways.
  2. The same on the transposed image for the vertical wrap.
  3. Resize back to --size.
Prints the wrap-seam error before/after and the cut quality (share of cut rows whose two strips differ
by more than 40/255 — above 3% it warns). --check also writes <check>_seam.png, a 100% crop of a 2x2
tiling over the blended band; look at it, not only at the shrunken 3x3 sheet.
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage, sparse
from scipy.sparse.csgraph import breadth_first_order, maximum_flow


def min_cut_cols(err, cyclic=False):
    """err: (h, b) cost; returns cut column per row (0..b-1) along the min-cost 8-connected path.
    cyclic=True: the path must end in the same column it starts in (needed for the second pass,
    whose rows are the first pass's wrap direction)."""
    h, b = err.shape
    starts = np.arange(0, b, 2) if cyclic else np.array([-1])
    S = len(starts)
    cost = np.repeat(err[0][None, :], S, axis=0)
    if cyclic:
        mask = np.full((S, b), np.inf)
        mask[np.arange(S), starts] = 0.0
        cost = cost + mask
    back = np.zeros((h, S, b), np.int16)
    cols = np.arange(b)
    for y in range(1, h):
        left = np.concatenate([np.full((S, 1), np.inf), cost[:, :-1]], axis=1)
        right = np.concatenate([cost[:, 1:], np.full((S, 1), np.inf)], axis=1)
        stack = np.stack([left, cost, right])            # (3, S, b)
        k = stack.argmin(axis=0)
        cost = np.take_along_axis(stack, k[None], 0)[0] + err[y][None, :]
        back[y] = (cols[None, :] + (k - 1)).astype(np.int16)
    if cyclic:
        end_cost = cost[np.arange(S), starts]
        si = int(end_cost.argmin())
        end = int(starts[si])
    else:
        si, end = 0, int(cost[0].argmin())
    cut = np.empty(h, np.int64)
    cut[-1] = end
    for y in range(h - 1, 0, -1):
        cut[y - 1] = back[y, si, cut[y]]
    return cut


def otsu(values):
    hist, edges = np.histogram(values, bins=256, range=(0, 255))
    p = hist / max(1, hist.sum())
    w = np.cumsum(p)
    mu = np.cumsum(p * np.arange(256))
    between = (mu[-1] * w - mu) ** 2 / np.maximum(w * (1 - w), 1e-9)
    return edges[int(np.argmax(between))]


def graphcut_take_a(A, B, dark=0.0, cyclic=False, scale=1000):
    """Free-shape seam (graph cut / max flow): True where the band takes strip A. The left column is
    forced to A and the right column to B, so the cut can follow mortar lines in any direction.
    cyclic: the band's first and last rows are neighbours (second pass)."""
    h, b, _ = A.shape
    d = np.sqrt(((A - B) ** 2).mean(axis=2)) / 255.0
    c = d.copy()
    if dark != 0:
        # gaps (mortar / cracks) by Otsu on luminance; cutting outside a gap shared by both strips is
        # expensive, so a long path along the gaps beats a short straight cut through the stones
        la, lb = A @ [0.3, 0.59, 0.11], B @ [0.3, 0.59, 0.11]
        thr = otsu(np.concatenate([la.ravel(), lb.ravel()]))
        gap = (la < thr) & (lb < thr) if dark > 0 else (la > thr) & (lb > thr)
        gap = ndimage.binary_opening(gap, iterations=1)
        c = c + (~gap) * (10.0 * abs(dark))
    idx = np.arange(h * b).reshape(h, b)
    src, snk = h * b, h * b + 1
    pr, qr, wr = [], [], []

    def add(p, q, w):
        pr.extend([p, q]); qr.extend([q, p]); wr.extend([w, w])

    add(idx[:, :-1].ravel(), idx[:, 1:].ravel(), ((c[:, :-1] + c[:, 1:]) * scale).astype(np.int64).ravel() + 1)
    add(idx[:-1].ravel(), idx[1:].ravel(), ((c[:-1] + c[1:]) * scale).astype(np.int64).ravel() + 1)
    if cyclic:
        add(idx[-1], idx[0], ((c[-1] + c[0]) * scale).astype(np.int64) + 1)
    big = np.full(h, 10 ** 8)
    pr += [np.full(h, src), idx[:, -1]]; qr += [idx[:, 0], np.full(h, snk)]; wr += [big, big]
    G = sparse.csr_matrix((np.concatenate(wr).astype(np.int32), (np.concatenate(pr), np.concatenate(qr))),
                          shape=(h * b + 2, h * b + 2))
    G.sum_duplicates()
    flow = maximum_flow(G, src, snk, method="dinic").flow
    R = (G - flow).tocsr()
    R.data = (R.data > 0).astype(np.int8)
    R.eliminate_zeros()
    reach = np.zeros(h * b + 2, bool)
    reach[breadth_first_order(R, src, directed=True, return_predecessors=False)] = True
    return reach[:h * b].reshape(h, b)


def wrap_x(img, b, feather=4, dark=0.0, cyclic=False, graphcut=False, gap=0.0):
    """Returns (wrapped image, quality). Costs are normalised so the colour mismatch between the
    two strips always counts: cost = |A-B| (0..1) + dark * luminance (0..1)."""
    h, w, _ = img.shape
    A = img[:, w - b:]          # continues from the tile's right end
    B = img[:, :b]              # continues into the tile's middle
    diff = np.sqrt(((A - B) ** 2).mean(axis=2)) / 255.0
    cost = diff.copy()
    if dark != 0:
        # structured tiles (cobbles, planks): prefer cutting along dark gaps in both strips;
        # a negative weight prefers bright gaps instead (glowing lava cracks)
        lum = (A @ [0.3, 0.59, 0.11] + B @ [0.3, 0.59, 0.11]) / (2 * 255.0)
        cost = cost + (dark * lum if dark > 0 else -dark * (1.0 - lum))
    # gap continuity (slabs/flagstones/basalt): where one strip has a dark gap and the other has stone,
    # cutting there ends a gap mid-stone. gx marks those spots; --gap-weight steers the cut away and
    # quality["gap_breaks"] reports the share of cut rows that still end a gap.
    lum_all = img @ np.array([0.3, 0.59, 0.11], np.float32)
    thr = otsu(lum_all.ravel())
    gA = ndimage.binary_dilation((A @ [0.3, 0.59, 0.11]) < thr, iterations=2)
    gB = ndimage.binary_dilation((B @ [0.3, 0.59, 0.11]) < thr, iterations=2)
    gx = (gA ^ gB).astype(np.float32)
    if gap > 0:
        cost = cost + gap * gx
    if graphcut:
        # solve at half resolution (4x fewer nodes), then upsample the A/B choice and soften it a little
        a2 = np.asarray(Image.fromarray(A.clip(0, 255).astype(np.uint8)).resize((b // 2, h // 2), Image.BOX)).astype(np.float32)
        b2 = np.asarray(Image.fromarray(B.clip(0, 255).astype(np.uint8)).resize((b // 2, h // 2), Image.BOX)).astype(np.float32)
        take = graphcut_take_a(a2, b2, dark, cyclic)
        take = np.asarray(Image.fromarray((take * 255).astype(np.uint8)).resize((b, h), Image.NEAREST)) > 127
        take[:, :2] = True
        take[:, -2:] = False
        t = 1.0 - ndimage.gaussian_filter(take.astype(np.float32), 1.2)
        t[:, 0] = 0.0
        t[:, -1] = 1.0
        band = A * (1 - t[..., None]) + B * t[..., None]
        edge = take ^ ndimage.binary_erosion(take, iterations=1, border_value=1)
        on_cut = (diff * 255.0)[edge]
        quality = {"bad_rows": float((on_cut > 40).mean()) if on_cut.size else 0.0,
                   "mean_cut_diff": float(on_cut.mean()) if on_cut.size else 0.0, "max_step": 0.0}
        return np.concatenate([band, img[:, b:w - b]], axis=1), quality
    cost = ndimage.uniform_filter(cost, 5)
    # keep the cut away from the band edges so both sides blend in
    pad = max(4, b // 8)
    cost[:, :pad] += 1e6
    cost[:, -pad:] += 1e6
    cut = min_cut_cols(cost, cyclic)
    xs = np.arange(b)[None, :]
    t = np.clip((xs - cut[:, None] + feather) / (2 * feather), 0.0, 1.0)[..., None]  # 0 -> A, 1 -> B
    band = A * (1 - t) + B * t
    # quality: colour step across the cut, per row (0..255); rows above 40 show as a visible seam
    lo = np.clip(cut - feather - 1, 0, b - 1)
    hi = np.clip(cut + feather + 1, 0, b - 1)
    rows = np.arange(h)
    step = np.abs(A[rows, lo] - B[rows, hi]).mean(axis=1)
    on_cut = diff[rows, cut] * 255.0
    quality = {"bad_rows": float((on_cut > 40).mean()), "mean_cut_diff": float(on_cut.mean()),
               "max_step": float(step.max()), "gap_breaks": float(gx[rows, cut].mean())}
    return np.concatenate([band, img[:, b:w - b]], axis=1), quality


def wrap_both(img, overlap, dark, g, graphcut=False, gap=0.0, feather=4, feather_y=None):
    q = []
    if "x" not in g:   # horizontal wrap; must stay cyclic when the vertical wrap came from a grid crop
        img, qx = wrap_x(img, overlap, feather=feather, dark=dark, cyclic="y" in g, graphcut=graphcut, gap=gap)
        q.append(qx)
    if "y" not in g:
        t, qy = wrap_x(img.transpose(1, 0, 2), overlap, feather=feather if feather_y is None else feather_y, dark=dark, cyclic=True, graphcut=graphcut, gap=gap)
        img = t.transpose(1, 0, 2)
        q.append(qy)
    bad = max([x["bad_rows"] + x.get("gap_breaks", 0.0) for x in q] or [0.0])
    return img, q, bad


def grid_crop(img, axis):
    """Regular patterns (paving grid, plank rows): crop from one gap line to another so the tile
    holds a whole number of cells along `axis` (0 = rows/y, 1 = columns/x) and wraps exactly."""
    lum = img @ [0.3, 0.59, 0.11]
    prof = lum.mean(axis=1 - axis)                       # one value per row (axis 0) or column (axis 1)
    prof = ndimage.gaussian_filter1d(prof, 2)
    n = len(prof)
    x = prof - prof.mean()
    ac = np.correlate(x, x, "full")[n - 1:]
    ac = ac / ac[0]
    lo = n // 16
    seg = ac[lo:n // 2]
    # fundamental period = first clear autocorrelation peak (not a multiple of it)
    peaks = [i for i in range(1, len(seg) - 1) if seg[i] >= seg[i - 1] and seg[i] >= seg[i + 1]]
    strong = [i for i in peaks if seg[i] >= 0.5 * seg.max()]
    period = lo + (strong[0] if strong else int(np.argmax(seg)))
    # gap lines = darkest point inside each period window
    start = int(np.argmin(prof[:period]))
    lines = [start]
    while lines[-1] + period + period // 4 < n:
        c = lines[-1] + period
        w0, w1 = c - period // 4, min(n, c + period // 4 + 1)
        lines.append(w0 + int(np.argmin(prof[w0:w1])))
    a, b = lines[0], lines[-1]
    sl = [slice(None)] * 2
    sl[axis] = slice(a, b)
    print(f"  grid axis {'yx'[axis]}: period {period}px, {len(lines) - 1} cells, crop {a}-{b}")
    return img[tuple(sl)]


def solidity(m):
    """area / convex-hull area of a mask (1.0 = perfectly convex)."""
    from scipy.spatial import ConvexHull
    ys, xs = np.nonzero(m)
    if len(xs) < 10:
        return 0.0
    try:
        hull = ConvexHull(np.c_[xs, ys])
    except Exception:
        return 0.0
    return float(m.sum()) / max(hull.volume, 1.0)


def stone_mask(R, dark=0.3):
    """Stones vs gaps. Dark gaps (mortar, cracks): a pixel is stone when it is brighter than the
    luminance split OR less saturated than the saturation split (shaded stone undersides stay stone,
    saturated brown mortar stays gap). Bright gaps (glowing lava cracks): gap = bright AND saturated."""
    mx, mn = R.max(axis=2), R.min(axis=2)
    lum = ndimage.gaussian_filter(R @ [0.3, 0.59, 0.11], 1.5)
    sat = ndimage.gaussian_filter((mx - mn) / np.maximum(mx, 1) * 255.0, 1.5)
    tl, ts = otsu(lum.ravel()), otsu(sat.ravel())
    if dark >= 0:
        st = (lum > tl) | (sat < ts)
    else:
        st = ~((lum > tl) & (sat > ts))
    if st.mean() < 0.5:   # stones cover most of the floor; flip if the split came out inverted
        st = ~st
    print(f"  stone mask: lum split {tl:.0f}, sat split {ts:.0f}, stones {st.mean():.0%}")
    return st


def reseat(img, dark=0.3, band=6, rim=7, seed=7, verbose=True):
    """Blob textures (cobbles, flagstones, boulders, lava plates): roll by half so the source's own
    border seam becomes a cross in the middle (the new borders are continuous, so the tile already
    wraps), delete every stone the cross cuts, fill that hole with smooth gap colour, then re-seat
    whole stones (with their outline rim) copied from elsewhere in the same picture until the hole
    is packed. No blending across unrelated stones, so no cut or ghost stones."""
    rng = np.random.default_rng(seed)
    h, w, _ = img.shape
    R = np.roll(img, (h // 2, w // 2), axis=(0, 1)).astype(np.float32)
    stone = stone_mask(R, dark)
    stone = ndimage.binary_opening(stone, iterations=2)
    stone = ndimage.binary_fill_holes(stone)
    stone = ndimage.binary_opening(stone, iterations=3)
    lab, n = ndimage.label(stone)
    yy, xx = np.mgrid[0:h, 0:w]
    cross = (np.abs(xx - w // 2) <= band) | (np.abs(yy - h // 2) <= band)
    broken = np.unique(lab[cross & (lab > 0)])
    broken = broken[broken > 0]
    hole = ndimage.binary_dilation(np.isin(lab, broken), iterations=rim + 1) | ndimage.binary_dilation(cross, iterations=rim)
    occupied = stone & ~np.isin(lab, broken)
    # background: nearest gap colour from outside the hole, then heavily smoothed (no streaks)
    src_ok = ~ndimage.binary_dilation(stone, iterations=rim) & ~hole
    _, (iy, ix) = ndimage.distance_transform_edt(~src_ok, return_indices=True)
    fill = R[iy, ix]
    fill = np.stack([ndimage.gaussian_filter(fill[..., c], 8.0) for c in range(3)], axis=-1)
    soft = ndimage.gaussian_filter(hole.astype(np.float32), 3.0)[..., None]
    out = R * (1 - soft) + fill * soft
    # donor stones: complete, away from the cross and the borders; carry their outline rim
    keep = 48
    far = (np.abs(xx - w // 2) > keep) & (np.abs(yy - h // 2) > keep)
    donors = []
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl is None or i in broken:
            continue
        y0, y1, x0, x1 = sl[0].start - rim - 2, sl[0].stop + rim + 2, sl[1].start - rim - 2, sl[1].stop + rim + 2
        if y0 < 0 or x0 < 0 or y1 > h or x1 > w:
            continue
        m = lab[y0:y1, x0:x1] == i
        if m.sum() < 600 or not far[y0:y1, x0:x1][m].all():
            continue
        if solidity(m) < 0.9:   # ragged outline = badly separated stone; do not copy it
            continue
        core = ndimage.binary_dilation(m, iterations=rim - 3)
        foot = ndimage.binary_dilation(m, iterations=rim)
        alpha = np.clip(ndimage.distance_transform_edt(foot) / 3.0, 0, 1) * foot
        alpha = np.maximum(alpha, core.astype(np.float32))
        pix = R[y0:y1, x0:x1].copy()
        for sc in (1.0, 0.85, 0.7, 0.55):
            if sc == 1.0:
                donors.append({"m": m, "foot": foot, "alpha": alpha.astype(np.float32), "pix": pix,
                               "area": int(m.sum()), "src": i})
                continue
            nh, nw = max(4, int(m.shape[0] * sc)), max(4, int(m.shape[1] * sc))
            rs = lambda a, mode: np.asarray(Image.fromarray(a).resize((nw, nh), mode))
            m2 = rs((m * 255).astype(np.uint8), Image.BILINEAR) > 127
            if m2.sum() < 400:
                continue
            f2 = ndimage.binary_dilation(m2, iterations=rim)
            a2 = rs((alpha * 255).astype(np.uint8), Image.BILINEAR).astype(np.float32) / 255.0
            p2 = np.stack([rs(pix[..., c].clip(0, 255).astype(np.uint8), Image.LANCZOS) for c in range(3)], -1).astype(np.float32)
            donors.append({"m": m2, "foot": f2 | (a2 > 0), "alpha": a2, "pix": p2, "area": int(m2.sum()), "src": i})
    if not donors:
        return R, 0
    used_src = {}
    placed = 0
    blocked = np.zeros((h, w), bool)
    for _ in range(500):
        occ_rim = ndimage.binary_dilation(occupied, iterations=rim)
        free = hole & ~occ_rim & ~blocked
        if not free.any():
            break
        dist = ndimage.distance_transform_edt(free)
        py, px = np.unravel_index(int(np.argmax(dist)), dist.shape)
        if dist[py, px] < 8:
            break
        order = sorted(rng.permutation(len(donors)), key=lambda k: (used_src.get(donors[k]["src"], 0), -donors[k]["area"]))
        ok = False
        for k in order[:150]:
            d = donors[k]
            dh, dw = d["m"].shape
            y0, x0 = py - dh // 2, px - dw // 2
            if y0 < 0 or x0 < 0 or y0 + dh > h or x0 + dw > w:
                continue
            if (d["foot"] & ndimage.binary_dilation(occupied[y0:y0 + dh, x0:x0 + dw], iterations=2)).any():
                continue
            if (d["m"] & ~hole[y0:y0 + dh, x0:x0 + dw]).any():
                continue
            a = d["alpha"][..., None]
            out[y0:y0 + dh, x0:x0 + dw] = out[y0:y0 + dh, x0:x0 + dw] * (1 - a) + d["pix"] * a
            occupied[y0:y0 + dh, x0:x0 + dw] |= d["m"]
            used_src[d["src"]] = used_src.get(d["src"], 0) + 1
            placed += 1
            ok = True
            break
        if not ok:
            r = max(4, int(dist[py, px] // 2))
            blocked[max(0, py - r):py + r, max(0, px - r):px + r] = True
    if verbose:
        print(f"  reseat: removed {len(broken)} cut stones, placed {placed} whole stones from {len(donors)} donors")
    return out, len(broken)


def seam_error(img):
    """mean |step| across the wrap border vs. mean |step| inside, both directions."""
    a = img.astype(np.float32)
    wrap = (np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2
    inside = (np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean()) / 2
    return wrap, inside


def check_seam(tile, path, band):
    """100% crop of a 2x2 tiling around the wrap corner, covering the blended band."""
    t = np.asarray(tile)
    n = t.shape[0]
    big = np.tile(t, (2, 2, 1))
    a, b = n - 96, min(2 * n, n + band + 96)
    Image.fromarray(big[a:b, a:b]).save(path)


def check_3x3(tile, path, cell=384):
    t = tile.resize((cell, cell), Image.LANCZOS)
    sheet = Image.new("RGB", (cell * 3, cell * 3))
    for i in range(3):
        for j in range(3):
            sheet.paste(t, (i * cell, j * cell))
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--overlap", type=int, default=160)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--check")
    ap.add_argument("--grid", choices=["x", "y", "xy"], help="regular pattern: crop whole cells along these axes")
    ap.add_argument("--prefer-dark", type=float, default=0.0,
                    help="0..1 weight that pulls the cut into dark gaps (cobbles/planks: 0.3); negative = bright gaps (lava: -0.3)")
    ap.add_argument("--gap-weight", type=float, default=0.0,
                    help="slabs/flagstones/basalt: 0.5-2 keeps the cut where both strips agree on gap vs stone, so a gap never ends at the seam")
    ap.add_argument("--feather", type=int, default=4, help="half-width of the blend across the cut (px)")
    ap.add_argument("--feather-y", type=int, default=None,
                    help="blend half-width for the top/bottom wrap only (bark/plank grain: 24-40 hides grain steps)")
    ap.add_argument("--search", action="store_true", help="try overlaps 160/240/320/400 and keep the cleanest cut")
    ap.add_argument("--reseat", action="store_true",
                    help="blob textures (cobbles/flagstones/boulders/lava plates): re-seat whole stones over the seam cross")
    ap.add_argument("--graphcut", action="store_true",
                    help="free-shape seam by max-flow (irregular stones/slabs); ~20-60 s per tile")
    args = ap.parse_args()

    src = Image.open(args.src).convert("RGB")
    img0 = np.asarray(src).astype(np.float32)
    before = seam_error(img0)
    g = args.grid or ""
    img = img0
    if "y" in g:
        img = grid_crop(img, 0)
    if "x" in g:
        img = grid_crop(img, 1)
    if args.reseat:
        res, _ = reseat(img0, dark=args.prefer_dark if args.prefer_dark != 0 else 0.3)
        out = Image.fromarray(np.clip(res, 0, 255).round().astype(np.uint8), "RGB").resize((args.size, args.size), Image.LANCZOS)
        out.save(args.out)
        after = seam_error(np.asarray(out))
        print(f"{args.out}: {args.size}x{args.size}; reseat; wrap step before {before[0]:.1f} (inside {before[1]:.1f}) "
              f"-> after {after[0]:.1f} (inside {after[1]:.1f})")
        if args.check:
            check_3x3(out, args.check)
            t = np.asarray(out)
            n = t.shape[0]
            Image.fromarray(t[n // 4:3 * n // 4, n // 4:3 * n // 4]).save(args.check.replace(".png", "_seam.png"))
        return
    overlaps = [args.overlap] if not args.search else sorted({args.overlap, 160, 240, 320, 400})
    best = None
    for ov in overlaps:
        res, q, bad = wrap_both(img, ov, args.prefer_dark, g, args.graphcut, args.gap_weight, args.feather, args.feather_y)
        if args.search:
            print(f"  overlap {ov}: bad rows + gap breaks {bad:.1%}")
        if best is None or bad < best[2]:
            best = (res, q, bad, ov)
    res, q, bad, ov = best
    band_out = int(round(ov * args.size / max(1, res.shape[0])))
    out = Image.fromarray(np.clip(res, 0, 255).round().astype(np.uint8), "RGB")
    out = out.resize((args.size, args.size), Image.LANCZOS)
    out.save(args.out)
    after = seam_error(np.asarray(out))
    qs = "; ".join(f"cut diff {x['mean_cut_diff']:.1f}, rows>40 {x['bad_rows']:.1%}, gap breaks {x.get('gap_breaks', 0):.1%}" for x in q)
    print(f"{args.out}: {args.size}x{args.size}; overlap {ov}; wrap step before {before[0]:.1f} (inside {before[1]:.1f}) "
          f"-> after {after[0]:.1f} (inside {after[1]:.1f}); {qs or 'grid crop only'}")
    if bad > 0.03:
        print(f"  WARNING: {bad:.1%} of cut rows cross mismatched colour (>40) or end a gap mid-stone - look at "
              "the seam crop; irregular stones may need --gap-weight, a different source or a hand fix")
    if args.check:
        check_3x3(out, args.check)
        check_seam(out, args.check.replace(".png", "_seam.png"), band_out)


if __name__ == "__main__":
    main()
