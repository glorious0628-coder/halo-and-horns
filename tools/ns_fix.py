"""Make the 4 shadow-free views of one prop agree without drawing again (이미지 생성 3, 10/13; 디자인 검수 rule: 4 views
same object height, left and right the same shape).

  py tools/ns_fix.py <id> [--faces left,right,back] [--mirror left=right] [--dry]

Reads art/out/s2/noshadow/<id>_<face>_ns.png. The object is found against the plain grey background (corner median, soft
mask), the front view gives the target: object height + foot line + background colour. Every face in --faces is scaled to
that height, centred, its feet on the same line, on a canvas of the front's size and background (soft mask, so no box
edge). --mirror left=right: left := right flipped (after the right is fixed). Prints the heights before / after. PIL only.
"""
import argparse
import os

from PIL import Image, ImageChops, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser()
ap.add_argument("id")
ap.add_argument("--faces", default="left,right,back")
ap.add_argument("--mirror", default="")
ap.add_argument("--dry", action="store_true")
a = ap.parse_args()
P = os.path.join(ROOT, "art", "out", "s2", "noshadow", a.id + "_%s_ns.png")


def bg_of(im):
    w, h = im.size
    px = [im.getpixel((x, y)) for x in (4, w // 2, w - 5) for y in (4, h - 5)] + [im.getpixel((4, h // 2)), im.getpixel((w - 5, h // 2))]
    return tuple(sorted(p[i] for p in px)[len(px) // 2] for i in range(3))


def mask_of(im, bg):
    d = ImageChops.difference(im, Image.new("RGB", im.size, bg)).convert("L")
    # soft: 0 below 10, full above 28
    m = d.point(lambda v: 0 if v < 10 else (255 if v > 28 else int((v - 10) * 255 / 18)))
    return m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))


def box(m):
    return m.point(lambda v: 255 if v > 128 else 0).getbbox()


front = Image.open(P % "front").convert("RGB")
fbg = bg_of(front)
fb = box(mask_of(front, fbg))
H, foot, W = fb[3] - fb[1], fb[3], front.size
print("[fix] front height %d px (%d..%d), bg %s" % (H, fb[1], fb[3], fbg))
mir = dict(x.split("=") for x in a.mirror.split(",") if x)
for face in [f for f in a.faces.split(",") if f and f not in mir]:
    im = Image.open(P % face).convert("RGB")
    bg = bg_of(im)
    m = mask_of(im, bg)
    b = box(m)
    k = H / (b[3] - b[1])
    print("[fix] %s height %d -> %d (x%.3f), bg %s" % (face, b[3] - b[1], H, k, bg))
    if a.dry:
        continue
    pad = 6
    b2 = (max(0, b[0] - pad), max(0, b[1] - pad), min(im.size[0], b[2] + pad), min(im.size[1], b[3] + pad))
    obj, om = im.crop(b2), m.crop(b2)
    nw, nh = round(obj.size[0] * k), round(obj.size[1] * k)
    obj, om = obj.resize((nw, nh), Image.LANCZOS), om.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGB", W, fbg)
    x = (W[0] - nw) // 2
    y = foot + round(pad * k) - nh
    out.paste(obj, (x, y), om)
    out.save(P % face)
for dst, src in mir.items():
    if a.dry:
        print("[fix] %s := mirror of %s" % (dst, src))
        continue
    ImageOps.mirror(Image.open(P % src).convert("RGB")).save(P % dst)
    print("[fix] %s := mirror of %s" % (dst, src))
if not a.dry:
    for face in ("front", "left", "right", "back"):
        im = Image.open(P % face).convert("RGB")
        b = box(mask_of(im, bg_of(im)))
        print("[fix] check %s height %d foot %d centre x %d" % (face, b[3] - b[1], b[3], (b[0] + b[2]) // 2))
