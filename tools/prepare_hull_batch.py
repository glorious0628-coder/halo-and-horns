"""Prepare one Import-3D batch of outline hull OBJs (이미지 개발 2026-10-12).
  py tools/prepare_hull_batch.py <batch 3..6> [--sheet-only] [--dst build/hull_import_b4]
Empties build/hull_import (Hull_*.obj only), copies build/prop_kit_hull035/<Kit>_D2_035.obj as Hull_<Kit>.obj, and writes a contact sheet of the
previews (build/prop_kit_hull035/<Kit>_prev_D2_035.png) to build/hull_import_sheet_<n>.png so every render can be viewed before the user imports.
After the user's Import 3D: STUDIO_NAME=WorldKit py tools/read_imported_hulls.py --clean   (records ids + centres, deletes the temp parts).
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "build", "prop_kit_hull035")
DST = os.path.join(ROOT, "build", "hull_import")
BATCHES = {
    2: "HaloVar3_RoundTree_F__Body HaloVar3_RoundTree_G__Body HaloReasonHQ_BenchC HaloFlowerPotHQ_Tulip__Body HaloReasonHQ_Clothesline HaloVar4_Planter_A__Body NEW_CafeTable HaloFlagpole_1 HaloFlowerPotHQ_Daisy__Body HaloFlowerPotHQ_Lavender__Body",
    3: "HaloFlowerPotHQ_Rose__Body HaloFlowerPotHQ_Sunflower__Body HaloReasonHQ_RackShieldSword HaloReasonHQ_VegGarden__Body HaloReasonHQ_Woodpile HaloVar3_Planter_E__Body HaloVar3_Topiary_C__Body HaloVar3_Topiary_D__Body HaloVar3_Topiary_E__Body HaloVar4_PotFlowers_A__Body",
    4: "HaloVar4_PotFlowers_C__Body NEW_CandleCrate NEW_Hedge__Body NEW_WallLamp HaloFlagpole_2 HaloFlagpole_3 HaloReasonHQ_BreadStand__Body HaloReasonHQ_FlowerCart__Body HaloReasonHQ_FruitStall__Body HaloReasonHQ_GuardPost",
    5: "HaloReasonHQ_PotionCrate__Body HaloVar3_Balustrade_E HaloVar3_Balustrade_F HaloVar3_PotFlowers_E__Body HaloVar3_PotFlowers_F__Body HaloVar4_Balustrade_A HaloVar4_Balustrade_C HaloVar4_PotFlowers_D__Body NEW_ArmoryBarrels NEW_BellFrame",
    6: "NEW_Cauldron NEW_Easel NEW_NoticeBoard NEW_Telescope NEW_WaterBuckets Town_Halo_Fountain3",
}


def main():
    global DST
    n = int(sys.argv[1])
    if "--dst" in sys.argv:
        DST = os.path.join(ROOT, sys.argv[sys.argv.index("--dst") + 1])
    kits = BATCHES[n].split()
    assert len(kits) <= 10
    os.makedirs(DST, exist_ok=True)
    if "--sheet-only" not in sys.argv:
        for f in os.listdir(DST):
            if f.startswith("Hull_") and f.endswith(".obj"):
                os.remove(os.path.join(DST, f))
    S = 380
    cols = 5
    rows = (len(kits) + cols - 1) // cols
    sh = Image.new("RGB", (S * cols, S * rows), (30, 30, 30))
    d = ImageDraw.Draw(sh)
    for i, k in enumerate(kits):
        src = os.path.join(SRC, "%s_D2_035.obj" % k)
        if not os.path.exists(src):
            print("MISSING obj", k)
            continue
        if "--sheet-only" not in sys.argv:
            shutil.copy(src, os.path.join(DST, "Hull_%s.obj" % k))
        pv = os.path.join(SRC, "%s_prev_D2_035.png" % k)
        if os.path.exists(pv):
            im = Image.open(pv).convert("RGB")
            im.thumbnail((S, S))
            sh.paste(im, ((i % cols) * S, (i // cols) * S))
        else:
            print("no preview", k)
        d.text(((i % cols) * S + 4, (i // cols) * S + 4), k, fill=(255, 255, 0))
    out = os.path.join(ROOT, "build", "hull_import_sheet_%d.png" % n)
    sh.save(out)
    print(len(os.listdir(DST)), "files in", DST, "; sheet", out)


if __name__ == "__main__":
    main()
