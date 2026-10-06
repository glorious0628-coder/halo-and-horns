"""Make a square ground texture tile seamlessly (wraps on all four sides) and write a 3x3 check sheet.

Usage:
  py tools/make_tileable.py <src.png> <out.png> [--overlap 160] [--size 1024] [--check art/review/<name>_3x3.png]
                           [--prefer-dark 20]  (cobbles/planks: cut along dark gaps; -20 = bright gaps, lava)
                           [--grid x|y|xy]     (paving grids / plank rows: crop whole cells, no blending)

How it works (image-quilting style, no AI):
  1. Horizontal wrap: the right strip (width = overlap) is laid over the left strip. Per row a
     cut column is chosen by dynamic programming so the cut follows the smallest colour
     difference between the two strips; left of the cut uses the right strip, right of it the
     left strip, with a short feather. The tile loses `overlap` columns and now wraps sideways.
  2. The same on the transposed image for the vertical wrap.
  3. Resize back to --size.
Prints the wrap-seam error (mean RGB step across the border) before and after; the after value
should be close to the inside step. Always look at the 3x3 sheet enlarged before showing it.
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage


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


def wrap_x(img, b, feather=4, dark=0.0, cyclic=False):
    h, w, _ = img.shape
    A = img[:, w - b:]          # continues from the tile's right end
    B = img[:, :b]              # continues into the tile's middle
    err = ((A - B) ** 2).sum(axis=2)
    if dark != 0:
        # structured tiles (cobbles, planks): prefer cutting along dark gaps in both strips;
        # a negative weight prefers bright gaps instead (glowing lava cracks)
        lum = (A @ [0.3, 0.59, 0.11] + B @ [0.3, 0.59, 0.11]) / 2
        err = err + dark * lum ** 2
        err -= err.min()
    err = ndimage.uniform_filter(err, 5)
    # keep the cut away from the band edges so both sides blend in
    pad = max(4, b // 8)
    err[:, :pad] += 1e9
    err[:, -pad:] += 1e9
    cut = min_cut_cols(err, cyclic)
    xs = np.arange(b)[None, :]
    t = np.clip((xs - cut[:, None] + feather) / (2 * feather), 0.0, 1.0)[..., None]  # 0 -> A, 1 -> B
    band = A * (1 - t) + B * t
    return np.concatenate([band, img[:, b:w - b]], axis=1)


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


def seam_error(img):
    """mean |step| across the wrap border vs. mean |step| inside, both directions."""
    a = img.astype(np.float32)
    wrap = (np.abs(a[:, 0] - a[:, -1]).mean() + np.abs(a[0] - a[-1]).mean()) / 2
    inside = (np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean()) / 2
    return wrap, inside


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
                    help="weight that pulls the cut into dark gaps (cobbles/planks: 20); negative = bright gaps (lava: -20)")
    args = ap.parse_args()

    src = Image.open(args.src).convert("RGB")
    img = np.asarray(src).astype(np.float32)
    before = seam_error(img)
    g = args.grid or ""
    if "y" in g:
        img = grid_crop(img, 0)
    if "x" in g:
        img = grid_crop(img, 1)
    if "x" not in g:   # horizontal wrap; must stay cyclic when the vertical wrap came from a grid crop
        img = wrap_x(img, args.overlap, dark=args.prefer_dark, cyclic="y" in g)
    if "y" not in g:
        img = wrap_x(img.transpose(1, 0, 2), args.overlap, dark=args.prefer_dark, cyclic=True).transpose(1, 0, 2)
    out = Image.fromarray(np.clip(img, 0, 255).round().astype(np.uint8), "RGB")
    out = out.resize((args.size, args.size), Image.LANCZOS)
    out.save(args.out)
    after = seam_error(np.asarray(out))
    print(f"{args.out}: {args.size}x{args.size}; wrap step before {before[0]:.1f} (inside {before[1]:.1f}) "
          f"-> after {after[0]:.1f} (inside {after[1]:.1f})")
    if args.check:
        check_3x3(out, args.check)


if __name__ == "__main__":
    main()
