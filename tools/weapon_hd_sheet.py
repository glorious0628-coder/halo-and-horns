"""Judge sheet for one raw Tripo HD weapon (무기 디자인, 10/14, A23-187).

Rows: (1) approved 2D front / left / right / back, (2) the Tripo HD renders matched to those views (tools/weapon_hd_views.py;
the best-fitting render per 2D view by silhouette + colour), on the same grey, (3) the same renders on MAGENTA - any
magenta inside the object = see-through, (4) 100% crops (top / middle / grip) of 2D front vs 3D front + the 3/4 view.
Also counts enclosed magenta pixels (holes) per view.

  py tools/weapon_hd_sheet.py <Name> <views_prefix> <out.jpg>
    e.g. py tools/weapon_hd_sheet.py Weapon_Halo_Paladin_T2 art/review/weapon_design/Paladin_T2/v art/review/weapon_design/Paladin_T2_sheet.jpg
"""
import itertools
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W2D = os.path.join(ROOT, "art", "out", "s2", "weapons_t13_4v")
GREY = (104, 104, 104)
MAG = (255, 0, 255)
SIDES = ["front", "left", "right", "back"]


def path2d(name, side):
    v2 = os.path.join(W2D, f"{name}_{side}_v2.png")
    return v2 if os.path.exists(v2) else os.path.join(W2D, f"{name}_{side}.png")


def cut2d(im):
    A = np.asarray(im.convert("RGB")).astype(int)
    bg = np.median(np.concatenate([A[:8].reshape(-1, 3), A[-8:].reshape(-1, 3), A[:, :8].reshape(-1, 3)]), 0)
    m = np.abs(A - bg).max(2) > 22
    m = ndimage.binary_opening(m, iterations=1)
    ys, xs = np.nonzero(m)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgba = im.convert("RGBA")
    rgba.putalpha(Image.fromarray((m * 255).astype(np.uint8)))
    return rgba.crop(box)


def cut3d(im):
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.nonzero(a > 10)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def norm(im, h=400, w=160):
    im = im.copy()
    r = h / im.height
    im = im.resize((max(1, int(im.width * r)), h), Image.LANCZOS)
    c = Image.new("RGBA", (max(w, im.width), h), (0, 0, 0, 0))
    c.paste(im, ((c.width - im.width) // 2, 0))
    return c.crop(((c.width - w) // 2, 0, (c.width - w) // 2 + w, h))


def diff(a, b):
    A = np.asarray(norm(a)).astype(float)
    B = np.asarray(norm(b)).astype(float)
    ma, mb = A[:, :, 3] > 128, B[:, :, 3] > 128
    sil = (ma ^ mb).mean()
    both = ma & mb
    col = np.abs(A[both, :3] - B[both, :3]).mean() / 255 if both.any() else 1
    return sil * 3 + col


def on(im, bg):
    c = Image.new("RGB", im.size, bg)
    c.paste(im, (0, 0), im)
    return c


def holes(im):
    a = np.asarray(im)[:, :, 3] < 128
    lab, n = ndimage.label(a)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    inner = [(lab == i).sum() for i in range(1, n + 1) if i not in edge]
    return sum(inner), len(inner)


def main():
    name, pre, out = sys.argv[1], sys.argv[2], sys.argv[3]
    info = json.load(open(pre + "_info.json"))
    views = [v for v in info["views"] if v != "q34"]
    r3 = {v: cut3d(Image.open(f"{pre}_{v}.png").convert("RGBA")) for v in views}
    r2 = {s: cut2d(Image.open(path2d(name, s))) for s in SIDES}
    best, bestc = None, 9e9
    for perm in itertools.permutations(views, 4):
        c = sum(diff(r2[s], r3[v]) for s, v in zip(SIDES, perm))
        if c < bestc:
            best, bestc = perm, c
    match = dict(zip(SIDES, best))
    CW, CH = 230, 620
    pad = 26
    QW = 420
    sheet = Image.new("RGB", (CW * 4 + 20 + QW, pad + 3 * (CH + pad) + 470), "white")
    dr = ImageDraw.Draw(sheet)
    dr.text((6, 6), f"{name}  |  tris {info['tris']}  size {info['size']}  long {info['long_axis']}  |  match {match}",
            fill="black")
    hole_txt = []
    for col, s in enumerate(SIDES):
        x = col * CW + 10
        for row, (im, bg, lab) in enumerate([(r2[s], GREY, f"2D {s}"), (r3[match[s]], GREY, f"3D {s} ({match[s]})"),
                                             (r3[match[s]], MAG, f"3D {s} magenta")]):
            y = pad + row * (CH + pad)
            t = im.copy()
            t.thumbnail((CW - 10, CH))
            sheet.paste(on(t, bg), (x + (CW - 10 - t.width) // 2, y))
            dr.text((x, y - 13), lab, fill="black")
        hp, hn = holes(r3[match[s]])
        hole_txt.append(f"{s}:{hp}px/{hn}")
    y0 = pad + 3 * (CH + pad)
    dr.text((10, y0 - 14), "enclosed see-through (px/regions): " + "  ".join(hole_txt), fill="black")
    f2, f3 = r2["front"], r3[match["front"]]
    H = 1200
    f2 = f2.resize((int(f2.width * H / f2.height), H), Image.LANCZOS)
    f3 = f3.resize((int(f3.width * H / f3.height), H), Image.LANCZOS)
    x = 10
    for lab, (a, b) in (("top", (0.0, 0.33)), ("mid", (0.33, 0.66)), ("grip", (0.66, 1.0))):
        for im, tag in ((f2, "2D"), (f3, "3D")):
            c = on(im.crop((0, int(a * H), im.width, int(b * H))), GREY)
            c.thumbnail((205, 440))
            sheet.paste(c, (x, y0 + 14))
            dr.text((x, y0), f"{tag} {lab}", fill="black")
            x += c.width + 6
        x += 10
    q = Image.open(f"{pre}_q34.png").convert("RGBA")
    q = cut3d(q)
    q.thumbnail((QW - 20, 3 * (CH + pad) - 20))
    qx = CW * 4 + 20
    sheet.paste(on(q, GREY), (qx, pad))
    dr.text((qx, pad - 13), "3D 3/4 from above", fill="black")
    sheet.save(out, quality=90)
    print("match", match, "holes", hole_txt)


main()
