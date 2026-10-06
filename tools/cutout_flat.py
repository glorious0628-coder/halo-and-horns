"""Cut a sprite/icon out of a flat solid background (e.g. Firefly "plain flat medium gray").

Keeps dark outlines that remote background removers sometimes eat.

Usage:
  py tools/cutout_flat.py <src.png> <out.png> [--size 512] [--fill 0.86] [--tol 48] [--soft 10]
  py tools/cutout_flat.py <src.png> <out.png> --check art/review/<name>_check.png
  py tools/cutout_flat.py <src.png> <out.png> --holes   (also clear enclosed background holes,
      e.g. trophy handles, bag strap loops; prints each hole so you can confirm it).
      Gray backgrounds only: on a white background, white shine spots match the backdrop
      and would be punched out.

How it works:
  1. Background colour = median of the four 20px corner blocks.
  2. Pixels within --tol (RGB distance) of it that connect to the image border are background.
  3. Inside that region alpha ramps from 0 (distance <= --soft) to 1 (distance >= --tol), and
     the colour is decontaminated: rgb = (I - (1 - a) * bg) / a.
  4. Alpha below 8 becomes 0, the result is trimmed, padded to a square with the subject at
     --fill of the side, and resized to --size.
--check writes a sheet on light / navy / magenta backgrounds plus a 48px copy.
Always look at the check sheet enlarged before showing or uploading (AGENTS.md cutout rule).
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage


def cutout(src, tol=48.0, soft=10.0, holes=False, hole_min=150, hole_tol=5.0):
    img = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    h, w, _ = img.shape
    b = 20
    corners = np.concatenate([
        img[:b, :b].reshape(-1, 3), img[:b, -b:].reshape(-1, 3),
        img[-b:, :b].reshape(-1, 3), img[-b:, -b:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)
    d = np.sqrt(((img - bg) ** 2).sum(axis=2))

    labels, _ = ndimage.label(d < tol)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    edge = edge[edge != 0]
    region = np.isin(labels, edge)
    if holes:
        # Enclosed pockets of flat background (not touching the border): clear them when the
        # pocket is big enough and its median colour is very close to the background.
        for lab, sl in enumerate(ndimage.find_objects(labels), start=1):
            if sl is None or lab in edge:
                continue
            m = labels[sl] == lab
            area = int(m.sum())
            med = float(np.median(d[sl][m]))
            if area >= hole_min and med <= hole_tol:
                region[sl] |= m
                print(f"  hole cleared: {area}px at y{sl[0].start}-{sl[0].stop} x{sl[1].start}-{sl[1].stop} (median dist {med:.1f})")

    a = np.ones((h, w), np.float32)
    a[region] = np.clip((d[region] - soft) / (tol - soft), 0.0, 1.0)

    rgb = img.copy()
    safe = np.maximum(a, 1e-3)[..., None]
    dec = (img - (1.0 - a)[..., None] * bg) / safe
    rgb[region] = np.clip(dec[region], 0, 255)

    alpha = (a * 255).round().astype(np.uint8)
    alpha[alpha < 8] = 0
    out = np.dstack([rgb.round().astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def square(im, size=512, fill=0.86):
    box = im.getchannel("A").getbbox()
    if box:
        im = im.crop(box)
    side = max(im.size) / fill
    side = int(round(side))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


def edge_fix(im, radius=3):
    """Recolour semi-transparent edge pixels with their opaque neighbours' mean colour."""
    arr = np.asarray(im).astype(np.float32)
    rgb, a = arr[..., :3], arr[..., 3]
    solid = (a >= 250).astype(np.float32)
    k = 2 * radius + 1
    num = np.stack([ndimage.uniform_filter(rgb[..., c] * solid, k) for c in range(3)], axis=-1)
    den = ndimage.uniform_filter(solid, k)[..., None]
    edge = (a > 0) & (a < 250) & (den[..., 0] > 1e-4)
    rgb[edge] = num[edge] / den[edge]
    out = np.dstack([np.clip(rgb, 0, 255), a]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA"), int(edge.sum())


def check_sheet(im, path):
    tiles = []
    for col in [(245, 245, 245), (20, 28, 60), (255, 0, 255)]:
        t = Image.new("RGBA", im.size, col + (255,))
        t.alpha_composite(im)
        tiles.append(t)
    small = im.resize((48, 48), Image.LANCZOS)
    s = Image.new("RGBA", im.size, (20, 28, 60, 255))
    s.alpha_composite(small, ((im.width - 48) // 2, (im.height - 48) // 2))
    tiles.append(s)
    sheet = Image.new("RGBA", (im.width * len(tiles), im.height))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * im.width, 0))
    sheet.convert("RGB").save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--fill", type=float, default=0.86)
    ap.add_argument("--tol", type=float, default=48.0)
    ap.add_argument("--soft", type=float, default=10.0)
    ap.add_argument("--check")
    ap.add_argument("--holes", action="store_true")
    ap.add_argument("--no-edgefix", action="store_true", help="skip the edge colour clean-up")
    ap.add_argument("--hole-tol", type=float, default=5.0,
                    help="max median distance from the backdrop for a pocket to count as a hole")
    args = ap.parse_args()

    im = square(cutout(args.src, args.tol, args.soft, args.holes, hole_tol=args.hole_tol), args.size, args.fill)
    if not args.no_edgefix:
        im, n_edge = edge_fix(im)
        print(f"  edge pixels recoloured: {n_edge}")
    im.save(args.out)
    if args.check:
        check_sheet(im, args.check)
    a = np.asarray(im.getchannel("A"))
    print(f"{args.out}: {im.size[0]}x{im.size[1]} RGBA, opaque {(a == 255).mean():.1%}, partial {((a > 0) & (a < 255)).mean():.1%}")


if __name__ == "__main__":
    main()
