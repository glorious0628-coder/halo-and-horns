"""Make a tint mask layer from the neutral (silver-white) band of an approved icon.

Roblox ImageColor3 multiplies the whole image, so a coloured band needs its own layer:
the base icon is drawn as is, and this mask (white/gray band with the base's shading,
transparent elsewhere) is laid on top in the same 512 canvas and tinted in code.

Usage:
  py tools/band_mask.py art/ui/IconScrollEnh.png art/ui/IconScrollEnhBand.png
      [--sat 0.15] [--val 0.40] [--preview art/review/<name>_tints.png --tints "120,200,255;190,140,255"]

The mask is read straight from the final cutout, so it lines up pixel for pixel with it.
Only large low-saturation bright regions are kept (the band pieces plus the seal); small
stray parchment highlights are dropped. Check the preview enlarged before handing it over.
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage


def band_mask(path, sat_max=0.15, val_min=0.40, min_part=0.08, near_px=12, near_frac=0.6):
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    rgb, a = im[..., :3], im[..., 3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    val = mx

    core = (a > 0.5) & (sat < sat_max) & (val > val_min)
    labels, n = ndimage.label(core)
    if n == 0:
        raise SystemExit("no neutral band found")
    sizes = np.asarray(ndimage.sum(core, labels, range(1, n + 1)))
    # the seal's rim can split the band into pieces: keep every piece at least
    # min_part of the largest one (stray parchment highlights stay far smaller)
    main = int(np.argmax(sizes)) + 1
    near = ndimage.binary_dilation(labels == main, iterations=near_px)
    big = [main]
    for lab in np.flatnonzero(sizes >= min_part * sizes.max()) + 1:
        if lab == main:
            continue
        piece = labels == lab
        inside = (piece & near).sum() / piece.sum()
        # a band piece cut off by the seal rim sits right next to the main band;
        # long parchment highlight streaks run away from it
        if inside >= near_frac:
            big.append(int(lab))
        print(f"  piece {int(sizes[lab - 1])}px: {inside:.0%} within {near_px}px of the band -> {'kept' if inside >= near_frac else 'dropped'}")
    keep = np.isin(labels, big)
    keep = ndimage.binary_fill_holes(keep)
    region = ndimage.binary_dilation(keep, iterations=2)

    soft = np.clip((sat_max + 0.05 - sat) / 0.05, 0, 1) * np.clip((val - (val_min - 0.08)) / 0.08, 0, 1)
    w = np.where(keep, 1.0, np.where(region, soft, 0.0))
    # close the band's own soft rim (else a thin silver crescent of the base peeks out)
    rim = ndimage.binary_dilation(keep, iterations=1) & (sat < 0.25)
    w = np.where(rim, 1.0, w) * a
    # drop specks that are not attached to the band
    specks, m = ndimage.label(w > 0.02)
    attached = np.unique(specks[keep & (specks > 0)])
    w = np.where(np.isin(specks, attached), w, 0.0)

    ref = np.percentile(val[keep], 98)
    lum = np.clip(val / max(ref, 1e-3), 0, 1)
    out = np.dstack([lum, lum, lum, w])
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA"), int(keep.sum())


def preview(base_path, mask, tints, out_path, extra=None):
    base = Image.open(base_path).convert("RGBA")
    tiles = []
    for t in tints:
        m = np.asarray(mask).astype(np.float32)
        m[..., :3] = m[..., :3] * np.array(t, np.float32) / 255.0
        layer = Image.fromarray(m.round().astype(np.uint8), "RGBA")
        c = Image.new("RGBA", base.size, (239, 233, 221, 255))
        c.alpha_composite(base)
        c.alpha_composite(layer)
        tiles.append(c)
    big = [t.resize((256, 256), Image.LANCZOS) for t in tiles]
    small = [t.resize((48, 48), Image.LANCZOS) for t in tiles]
    if extra:
        e = Image.new("RGBA", base.size, (239, 233, 221, 255))
        e.alpha_composite(Image.open(extra).convert("RGBA"))
        small.append(e.resize((48, 48), Image.LANCZOS))
    w = 256 * len(big)
    sheet = Image.new("RGB", (w, 256 + 72), (250, 248, 240))
    for i, b in enumerate(big):
        sheet.paste(b.convert("RGB"), (i * 256, 0))
    for i, s in enumerate(small):
        sheet.paste(s.convert("RGB"), (12 + i * 60, 256 + 12))
    sheet.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--sat", type=float, default=0.15)
    ap.add_argument("--val", type=float, default=0.40)
    ap.add_argument("--preview")
    ap.add_argument("--tints", default="")
    ap.add_argument("--extra", help="another icon to show at 48px next to the tinted ones")
    args = ap.parse_args()

    mask, px = band_mask(args.src, args.sat, args.val)
    mask.save(args.out)
    print(f"{args.out}: band {px}px ({px / (mask.size[0] * mask.size[1]):.1%} of canvas)")
    if args.preview:
        tints = [tuple(int(v) for v in t.split(",")) for t in args.tints.split(";") if t]
        preview(args.src, mask, tints or [(255, 255, 255)], args.preview, args.extra)


if __name__ == "__main__":
    main()
