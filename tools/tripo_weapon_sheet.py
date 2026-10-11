"""Review sheet for the Blender-touched Tripo weapons (tools/tripo_weapon_touchup.py; 이미지 생성 4, 10/12).

Per weapon: the approved 2D front / left / right / back | the touched-up front / left / right / back (red ring = the hand /
pivot), with length, grip share and triangles. Two weapons per row, one sheet per faction.

  py tools/tripo_weapon_sheet.py [--jobs <scratch tripo_jobs_w.json>] [--out art/review/img4]
"""
import argparse
import glob
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W2D = os.path.join(ROOT, "art", "out", "s2", "weapons_t13_4v")
TU = os.path.join(ROOT, "art", "models", "tripo", "weapons")
CW, CH = 110, 230


def crop_obj(im):
    A = np.asarray(im.convert("RGB")).astype(int)
    bg = np.median(np.concatenate([A[:6].reshape(-1, 3), A[-6:].reshape(-1, 3)]), 0)
    m = np.abs(A - bg).max(2) > 18
    ys, xs = np.nonzero(m)
    if not len(ys):
        return im
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def fit(im, w, h, bg):
    im = im.convert("RGB")
    s = min(w / im.width, h / im.height)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    out = Image.new("RGB", (w, h), bg)
    out.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "review", "img4"))
    a = ap.parse_args()
    try:
        font = ImageFont.truetype("arial.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    jobs = sorted(os.path.basename(p) for p in glob.glob(os.path.join(TU, "Weapon_*")))
    for fac in ("Halo", "Horns", "Neutral"):
        js = [j for j in jobs if j.startswith("Weapon_%s_" % fac)]
        cols = 2
        rows = (len(js) + cols - 1) // cols
        cell_w, cell_h = 8 * (CW + 4) + 24, CH + 46
        sheet = Image.new("RGB", (cols * cell_w, rows * cell_h + 26), (34, 35, 38))
        d = ImageDraw.Draw(sheet)
        d.text((10, 4), "%s weapons: 2D front / left / right / back (light grey) | Blender touch-up front / left / right / back (dark), red ring = hand pivot" % fac,
               fill=(255, 220, 140), font=font)
        for i, j in enumerate(js):
            x, y = (i % cols) * cell_w + 10, (i // cols) * cell_h + 30
            st = json.load(open(os.path.join(TU, j, j + "_TU.json")))
            ims = []
            for v in ("front", "left", "right", "back"):
                f2 = os.path.join(W2D, "%s_%s.png" % (j, v))
                ims.append(crop_obj(Image.open(f2)) if os.path.exists(f2) else Image.new("RGB", (10, 10)))
            for v in ("front", "left", "right", "back"):
                f3 = os.path.join(TU, j, "%s_TU_%s.png" % (j, v))
                ims.append(crop_obj(Image.open(f3)) if os.path.exists(f3) else Image.new("RGB", (10, 10)))
            for k, im in enumerate(ims):
                sheet.paste(fit(im, CW, CH, (66, 68, 72) if k < 4 else (33, 34, 37)), (x + k * (CW + 4) + (8 if k >= 4 else 0), y))
            lab = "%s  L %.2f  grip %.0f%%  %d tris%s%s" % (j.replace("Weapon_", ""), st["length"], 100 * st.get("grip_from_bottom", st["hand_share"]),
                                                         st["tris"], "  blade x%.2f" % st["thickened_y"] if "thickened_y" in st else "",
                                                         "  mirrored" if "symmetric_x" in st else "")
            d.text((x, y + CH + 6), lab, fill=(235, 235, 235), font=font)
            d.text((x, y + CH + 24), "size %.2f x %.2f x %.2f studs (w x depth x length)" % tuple(st["size"]), fill=(170, 170, 170), font=font)
        os.makedirs(a.out, exist_ok=True)
        p = os.path.join(a.out, "weapons_tu_%s_1012.jpg" % fac.lower())
        sheet.save(p, quality=90)
        print(p, sheet.size)


if __name__ == "__main__":
    main()
