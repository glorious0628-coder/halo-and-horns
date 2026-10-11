"""Side-by-side sheet for tools/prop_kit.py kits (이미지 생성 4, 10/11): per kit one row = the approved 2D (4 views when
they exist, else the front) | the Blender preview (front / left / back / right, tools/prop_kit_preview.py) or Studio
photos (--photos <dir> with <Kit>_<view>.png).

  py tools/prop_kit_sheet.py <out.jpg> <Kit> [<Kit> ...] [--renders build/prop_kit/preview] [--cell 260]
"""
import argparse
import glob
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S2 = os.path.join(ROOT, "art", "out", "s2", "halo")
# kit -> props4 stem (4-view 2D) when there is one
MV = {"HaloReasonHQ_BenchA": "BenchA", "HaloReasonHQ_BenchB": "BenchB", "HaloReasonHQ_BenchC": "BenchC",
      "HaloVar4_Lantern_A": "LanternA", "HaloVar4_Lantern_B": "LanternB", "HaloVar4_Lantern_C": "LanternC",
      "HaloVar4_Lantern_D": "LanternD", "HaloVar3_Lantern_E": "LanternE", "HaloReasonHQ_BreadStand": "ReasonBread",
      "HaloReasonHQ_Clothesline": "ReasonCloth", "HaloReasonHQ_FlowerCart": "ReasonFlowerCart",
      "HaloReasonHQ_FruitStall": "ReasonFruit", "HaloReasonHQ_GuardPost": "ReasonGuard",
      "HaloReasonHQ_PotionCrate": "ReasonPotion", "HaloReasonHQ_RackShieldSword": "ReasonRack",
      "HaloReasonHQ_Scarecrow": "ReasonScare", "HaloReasonHQ_VegGarden": "ReasonVeg", "HaloReasonHQ_Woodpile": "ReasonWood",
      "HaloFlowerPotHQ_Daisy": "PotDaisy", "HaloFlowerPotHQ_Lavender": "PotLavender", "HaloFlowerPotHQ_Rose": "PotRose",
      "HaloFlowerPotHQ_Sunflower": "PotSunflower", "HaloFlowerPotHQ_Tulip": "PotTulip",
      "HaloVar3_Topiary_C": "TopC", "HaloVar3_Topiary_D": "TopD", "HaloVar3_Topiary_E": "TopE",
      "HaloVar3_RoundTree_E": "TreeE", "HaloVar3_RoundTree_F": "TreeF", "HaloVar3_RoundTree_G": "TreeG"}


def refs(kit):
    kit = kit.replace("__Body", "")
    if kit in MV:
        out = []
        for v in ("front", "left", "back", "right"):
            c = [os.path.join(S2, "props4", "HaloProp4_%s_%s2_HQ.png" % (MV[kit], v)),
                 os.path.join(S2, "props4", "HaloProp4_%s_%s2.png" % (MV[kit], v)),
                 os.path.join(S2, "props4", "HaloProp4_%s_%s.png" % (MV[kit], v))]
            out.append(next((p for p in c if os.path.exists(p)), None))
        return out
    if kit.startswith("NEW_"):
        k = kit[4:]
        c = glob.glob(os.path.join(S2, "kits_mv", "HaloKit_%s_front_HQ_src.png" % k)) + \
            glob.glob(os.path.join(S2, "kits_new", "HaloKit_%s_front.png" % k))
        return c[:1]
    c = glob.glob(os.path.join(S2, "*", kit + "_HQ_src.png")) + glob.glob(os.path.join(S2, "*", kit + "_front_HQ_src.png")) + \
        glob.glob(os.path.join(S2, "*", kit + ".png"))
    return c[:1]


def fit(im, cell):
    im = im.convert("RGB")
    bg = Image.new("RGB", (cell, cell), (60, 62, 66))
    im.thumbnail((cell, cell))
    bg.paste(im, ((cell - im.width) // 2, (cell - im.height) // 2))
    return bg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("kits", nargs="+")
    ap.add_argument("--renders", default=os.path.join(ROOT, "build", "prop_kit", "preview"))
    ap.add_argument("--cell", type=int, default=260)
    ap.add_argument("--label", default="Blender")
    ap.add_argument("--views", default="front,left,back,right", help="Studio photos: front,q34,back,night")
    a = ap.parse_args()
    C = a.cell
    font = ImageFont.load_default()
    rows = []
    for k in a.kits:
        r = refs(k)
        cells = [fit(Image.open(p), C) if p else Image.new("RGB", (C, C), (40, 40, 40)) for p in r]
        while len(cells) < 4:
            cells.append(Image.new("RGB", (C, C), (40, 40, 40)))
        for v in a.views.split(","):
            p = os.path.join(a.renders, "%s_%s.png" % (k, v))
            cells.append(fit(Image.open(p), C) if os.path.exists(p) else Image.new("RGB", (C, C), (40, 40, 40)))
        row = Image.new("RGB", (C * 8 + 8, C + 18), (30, 30, 32))
        d = ImageDraw.Draw(row)
        d.text((4, 2), "%s   2D (front/left/back/right) | %s (%s)" % (k, a.label, a.views.replace(",", "/")), fill=(255, 255, 255), font=font)
        for i, c in enumerate(cells):
            row.paste(c, (i * C + (8 if i >= 4 else 0), 18))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (30, 30, 32))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    sheet.save(a.out, quality=88)
    print("[sheet]", a.out, sheet.size)


if __name__ == "__main__":
    main()
