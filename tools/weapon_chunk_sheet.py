"""One sheet per chunk (3 weapons) for 최종 검수 (무기 디자인, 10/14). Uses the renders of tools/weapon_hd_views.py and
the view match of tools/weapon_hd_sheet.py. Per weapon one row: 2D front | 3D front | 2D left | 3D left | 3D front on
magenta | 3D 3/4 from above, plus tris / size / enclosed see-through.

  py tools/weapon_chunk_sheet.py <out.jpg> <Name>=<views_prefix> [...]
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_hd_sheet as _hs
hs = vars(_hs)
import itertools
import json

CH, CWs = 560, [150, 150, 70, 70, 150, 300]


def main():
    out, items = sys.argv[1], [a.split("=", 1) for a in sys.argv[2:]]
    W = sum(CWs) + 10 * len(CWs) + 10
    sheet = Image.new("RGB", (W, len(items) * (CH + 40)), "white")
    dr = ImageDraw.Draw(sheet)
    for r, (name, pre) in enumerate(items):
        info = json.load(open(pre + "_info.json"))
        views = [v for v in info["views"] if v != "q34"]
        r3 = {v: hs["cut3d"](Image.open(f"{pre}_{v}.png").convert("RGBA")) for v in views}
        r2 = {s: hs["cut2d"](Image.open(hs["path2d"](name, s))) for s in hs["SIDES"]}
        best = min(itertools.permutations(views, 4),
                   key=lambda p: sum(hs["diff"](r2[s], r3[v]) for s, v in zip(hs["SIDES"], p)))
        m = dict(zip(hs["SIDES"], best))
        holes = sum(hs["holes"](r3[v])[0] for v in views)
        q = hs["cut3d"](Image.open(f"{pre}_q34.png").convert("RGBA"))
        cells = [(r2["front"], hs["GREY"], "2D front"), (r3[m["front"]], hs["GREY"], "3D front"),
                 (r2["left"], hs["GREY"], "2D side"), (r3[m["left"]], hs["GREY"], "3D side"),
                 (r3[m["front"]], hs["MAG"], "3D magenta"), (q, hs["GREY"], "3D 3/4")]
        y = r * (CH + 40) + 30
        dr.text((10, y - 26), f"{name}   tris {info['tris']}   size {info['size']}   see-through px {holes}", fill="black")
        x = 10
        for (im, bg, lab), cw in zip(cells, CWs):
            t = im.copy()
            t.thumbnail((cw, CH))
            sheet.paste(hs["on"](t, bg), (x + (cw - t.width) // 2, y))
            dr.text((x, y - 12), lab, fill="black")
            x += cw + 10
    sheet.save(out, quality=90)
    print("saved", out)


main()
