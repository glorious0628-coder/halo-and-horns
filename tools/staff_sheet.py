"""Staff sheet for SPEC A23-142 (이미지 생성 4, 10/12): the 9 mage / alchemist staffs at true stud scale next to the
character height H 5.2, with the approved 2D front; red line = the hand (wrap centre = GLB pivot), yellow line =
hand + 1.2 studs (the orb / flask must start above it, 개발 1 68bef0e7).

  py tools/staff_sheet.py <renders dir: st_<job>.png> <out.jpg>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = ["Halo_LightMage_T1", "Halo_LightMage_T2", "Halo_LightMage_T3", "Horns_DarkMage_T1", "Horns_DarkMage_T2",
     "Horns_DarkMage_T3", "Neutral_Alchemist_T1", "Neutral_Alchemist_T2", "Neutral_Alchemist_T3"]
H, PX, CW = 5.2, 140, 230


def crop(im, thr=14):
    A = np.asarray(im.convert("RGB")).astype(int)
    bg = np.median(np.concatenate([A[:6].reshape(-1, 3), A[-6:].reshape(-1, 3)]), 0)
    ys, xs = np.nonzero(np.abs(A - bg).max(2) > thr)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def main():
    rd, out = sys.argv[1], sys.argv[2]
    font = ImageFont.truetype("arial.ttf", 15)
    o = Image.new("RGB", (len(J) * CW, int(H * PX) + 70), (105, 107, 112))
    d = ImageDraw.Draw(o)
    base = 60 + int(H * PX)
    d.line((0, base - int(H * PX), o.width, base - int(H * PX)), fill=(160, 60, 60))
    for i, j in enumerate(J):
        st = json.load(open(os.path.join(ROOT, "art", "models", "tripo", "weapons", "Weapon_" + j, "Weapon_%s_TU.json" % j)))
        L, g = st["length"], st["grip_from_bottom"] * st["length"]
        im = crop(Image.open(os.path.join(rd, "st_%s.png" % j)).convert("RGB"))
        im = im.resize((max(1, int(im.width * L * PX / im.height)), int(L * PX)))
        x0 = i * CW
        two = crop(Image.open(os.path.join(ROOT, "art", "out", "s2", "weapons_t13_4v", "Weapon_%s_front.png" % j)).convert("RGB"))
        two = two.resize((max(1, int(two.width * L * PX / two.height)), int(L * PX)))
        if two.width > CW // 2 - 10:                    # wide heads (LightMage T3): same height, the sides cut off
            cx = two.width // 2
            two = two.crop((cx - (CW // 2 - 10) // 2, 0, cx + (CW // 2 - 10) // 2, two.height))
        o.paste(two, (x0 + 8, base - two.height))
        o.paste(im, (x0 + CW - im.width - 8, base - im.height))
        for z, col in ((g, (255, 40, 40)), (g + 1.2, (255, 225, 40))):
            y = base - int(z * PX)
            d.line((x0 + 4, y, x0 + CW - 4, y), fill=col, width=2)
        d.text((x0 + 4, 4), j.split("_", 1)[1], fill=(255, 220, 140), font=font)
        d.text((x0 + 4, 22), "L %.2f (%.2fH) hand %.2f (%.0f%%)" % (L, L / H, g, 100 * st["grip_from_bottom"]), fill=(240, 240, 240), font=font)
    d.text((4, base - int(H * PX) + 2), "H 5.2 | left: 2D front, right: 3D | red = hand, yellow = hand + 1.2", fill=(255, 210, 210), font=font)
    o.save(out, quality=90)
    print(out, o.size)


if __name__ == "__main__":
    main()
