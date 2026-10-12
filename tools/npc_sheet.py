"""NPC review sheet (이미지 생성 4, 10/12): per NPC the approved 2D front / left / right / back (light) next to the
Blender-touched model front / left / right / back (dark; tools/tripo_touchup.py previews).

  py tools/npc_sheet.py <out.jpg> [NPC_HaloBright ...]
2D sides are named from the viewer (NPC_*_left_HQ = the character seen from the viewer's left = its right side), the
touch-up previews by the model's own side, so the pairs are: 2D left <-> 3D right, 2D right <-> 3D left.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TU = os.path.join(ROOT, "art", "models", "tripo", "touchup")
NPC2D = os.path.join(ROOT, "art", "out", "s2", "npc")
FRONT = {"NPC_HaloFlowerGirl": "NPC_HaloFlowerGirl_C_src", "NPC_HaloPotionMerchant": "NPC_HaloPotionMerchant_front_HQ_src"}
CW, CH = 150, 260


def crop(im):
    A = np.asarray(im.convert("RGB")).astype(int)
    bg = np.median(np.concatenate([A[:6].reshape(-1, 3), A[-6:].reshape(-1, 3)]), 0)
    m = np.abs(A - bg).max(2) > 16
    ys, xs = np.nonzero(m)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)) if len(ys) else im


def cell(im, bgc):
    im = crop(im).convert("RGB")
    s = min(CW / im.width, CH / im.height)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))))
    c = Image.new("RGB", (CW, CH), bgc)
    c.paste(im, ((CW - im.width) // 2, CH - im.height))
    return c


def main():
    args = sys.argv[1:]
    prev = None
    if "--prev" in args:                     # clean renders from tools/glb_preview4.py: <prev>/<job>_<view>.png
        k = args.index("--prev")
        prev = args[k + 1]
        del args[k:k + 2]
    out = args[0]
    jobs = args[1:] or sorted(d for d in os.listdir(TU) if d.startswith("NPC_"))
    font = ImageFont.truetype("arial.ttf", 14)
    W = 8 * (CW + 4) + 30
    sheet = Image.new("RGB", (W, len(jobs) * (CH + 46) + 24), (34, 35, 38))
    d = ImageDraw.Draw(sheet)
    d.text((8, 4), "2D front / 2D right-side view / 2D left-side view / 2D back  |  3D front / left / right / back (character's own sides)", fill=(255, 220, 140), font=font)
    for r, j in enumerate(jobs):
        y = r * (CH + 46) + 24
        f2 = FRONT.get(j, j + "_A_src")
        ims2 = [os.path.join(NPC2D, f2 + ".png")] + [os.path.join(NPC2D, "%s_%s_HQ_src.png" % (j, v)) for v in ("right", "left", "back")]
        ims3 = [os.path.join(prev, "%s_%s.png" % (j, v)) if prev else os.path.join(TU, j, "%s_TU_%s.png" % (j, v)) for v in ("front", "left", "right", "back")]
        for k, p in enumerate(ims2 + ims3):
            if os.path.exists(p):
                sheet.paste(cell(Image.open(p), (70, 72, 76) if k < 4 else (30, 31, 34)), (8 + k * (CW + 4) + (14 if k >= 4 else 0), y))
        st = json.load(open(os.path.join(TU, j, j + "_TU.json")))
        halo = st.get("halo")
        txt = "%s  %d tris  size %.2f x %.2f x %.2f  halo %s%s" % (j, st["tris"], *st["size"], "exact ring" if isinstance(halo, dict) else "-",
                                                                   "  mirrored below %.0f%%" % (100 * st["sym_below"]["share"]) if "sym_below" in st else "")
        d.text((8, y + CH + 6), txt, fill=(235, 235, 235), font=font)
    sheet.save(out, quality=90)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
