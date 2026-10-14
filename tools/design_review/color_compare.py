"""Main colours of the 2D front vs a render (object pixels only, PIL quantize). Numbers are hints; judge by eye.
py tools/design_review/color_compare.py <2d_front.png> <render.png> [n=6]
"""
import sys

from PIL import Image, ImageChops


def obj_pixels(path):
    im = Image.open(path).convert("RGBA")
    if im.getextrema()[3][0] < 250:  # has transparency
        px = [p[:3] for p in im.getdata() if p[3] > 200]
    else:
        rgb = im.convert("RGB")
        bg = rgb.getpixel((2, 2))
        d = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L")
        px = [p for p, m in zip(rgb.getdata(), d.getdata()) if m > 18]
    return px


def main_colours(path, n):
    px = obj_pixels(path)
    im = Image.new("RGB", (len(px), 1))
    im.putdata(px)
    q = im.quantize(colors=n, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[: n * 3]
    cnt = sorted(q.getcolors(), reverse=True)
    tot = sum(c for c, _ in cnt)
    return [(round(100 * c / tot), tuple(pal[i * 3: i * 3 + 3])) for c, i in cnt]


n = int(sys.argv[3]) if len(sys.argv) > 3 else 6
for lab, p in (("2D", sys.argv[1]), ("3D", sys.argv[2])):
    print(lab, "  ".join(f"{s}% {c}" for s, c in main_colours(p, n)))
