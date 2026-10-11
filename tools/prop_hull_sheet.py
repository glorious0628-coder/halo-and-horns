"""Sheet of the outline hull previews (tools/prop_kit_bake.py --hull-only --preview; 이미지 생성 4, 10/12).

  py tools/prop_hull_sheet.py <out.jpg> [--dir build/prop_kit_hull035] [--cols 8] [--cell 190] [--first K1,K2,...]

Kits in --first come first (marked *), the rest by name; label = short name + hull triangles.
"""
import argparse
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def short(k):
    for p in ("HaloReasonHQ_", "HaloFlowerPotHQ_", "HaloVar3_", "HaloVar4_", "Town_Halo_"):
        k = k.replace(p, "")
    return k.replace("__Body", "_B")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--dir", default=os.path.join(ROOT, "build", "prop_kit_hull035"))
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--cell", type=int, default=190)
    ap.add_argument("--first", default="")
    a = ap.parse_args()
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    first = [k for k in a.first.split(",") if k]
    kits = sorted(os.path.basename(p)[:-len("_D2_035.json")] for p in glob.glob(os.path.join(a.dir, "*_D2_035.json")))
    kits = [k for k in first if k in kits] + [k for k in kits if k not in first]
    S, TH = a.cell, 18
    rows = (len(kits) + a.cols - 1) // a.cols
    sheet = Image.new("RGB", (a.cols * S, rows * (S + TH)), (30, 31, 34))
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(kits):
        x, y = (i % a.cols) * S, (i // a.cols) * (S + TH)
        st = json.load(open(os.path.join(a.dir, k + "_D2_035.json")))
        d.text((x + 4, y + 2), "%s%s %d" % ("*" if k in first else "", short(k), st["D2_tris"]), fill=(240, 240, 240), font=font)
        p = os.path.join(a.dir, k + "_prev_D2_035.png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((S - 4, S - 4))
            sheet.paste(im, (x + 2, y + TH))
    sheet.save(a.out, quality=90)
    print(a.out, sheet.size, len(kits))


if __name__ == "__main__":
    main()
