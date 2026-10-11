"""One result sheet for the "선이 없어 보여" comparison (이미지 생성 4, 10/11): per kit a block of rows
(day 5 / day 15 / night 5 / night 15 studs) x columns (2D | A | B | B2 | C | D1 | D2 ...), from tools/prop_compare_shots.py
photos. Columns with no Studio photo yet (C / D2 before upload) show the Blender preview of tools/prop_kit_bake.py in the
first row, marked "Blender".

  py tools/prop_compare_sheet.py <photos_dir> <bake_dir> <out.jpg> [--cols 2D,A,B,B2,C,Cs,D1,D2] [--cell 230]
         [--note "text line" ...]
"""
import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KITS = ["HaloReasonHQ_BenchA", "HaloVar4_Lantern_A", "NEW_Beehive", "HaloVar4_Planter_D__Body"]
ROWS = [("day", 5), ("day", 15), ("night", 5), ("night", 15)]
LABEL = {"2D": "2D 그림", "A": "A 지금", "Abl": "A (Blender)", "B": "B 땅+그림자", "B2": "B2 +Diffuse 0.3", "C": "C 색 굽기",
         "Cs": "C+ 진하게", "D1": "D1 Highlight 선", "D2": "D2 껍데기 선"}
PREV = {"Abl": "A"}      # sheet column -> tools/prop_kit_bake.py preview name
ROWL = {("day", 5): "낮 5칸", ("day", 15): "낮 15칸", ("night", 5): "밤 5칸", ("night", 15): "밤 15칸"}


def font(sz):
    for f in ("C:/Windows/Fonts/malgunbd.ttf", "C:/Windows/Fonts/malgun.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def fit(im, s):
    im = im.convert("RGB")
    w, h = im.size
    k = s / max(w, h)
    im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    out = Image.new("RGB", (s, s), (34, 34, 38))
    out.paste(im, ((s - im.size[0]) // 2, (s - im.size[1]) // 2))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("photos")
    ap.add_argument("bake")
    ap.add_argument("out")
    ap.add_argument("kits", nargs="*")
    ap.add_argument("--cols", default="2D,A,B,B2,D1,Abl,C,Cs,D2")
    ap.add_argument("--cell", type=int, default=230)
    ap.add_argument("--note", action="append", default=[])
    a = ap.parse_args()
    kits = a.kits or KITS
    cols = a.cols.split(",")
    S, LW, TH = a.cell, 90, 34
    f1, f2, f3 = font(20), font(16), font(15)
    blocks = []
    for kit in kits:
        K = json.load(open(os.path.join(ROOT, "build", "prop_kit", kit + ".json")))
        W = LW + S * len(cols)
        img = Image.new("RGB", (W, TH + 30 + S * len(ROWS)), (24, 24, 28))
        d = ImageDraw.Draw(img)
        d.text((8, 6), kit, font=f1, fill=(255, 255, 255))
        for j, c in enumerate(cols):
            d.text((LW + j * S + 6, TH + 6), LABEL.get(c, c), font=f2, fill=(255, 220, 150))
        for i, (ph, dist) in enumerate(ROWS):
            y = TH + 30 + i * S
            d.text((6, y + S // 2 - 10), ROWL[(ph, dist)], font=f2, fill=(220, 220, 220))
            for j, c in enumerate(cols):
                x = LW + j * S
                p = None
                tag = ""
                if c == "2D":
                    if i == 0:
                        p = os.path.join(ROOT, K["ref"])
                else:
                    q = os.path.join(a.photos, "%s_%s_%s_%d.png" % (kit, c, ph, dist))
                    if os.path.exists(q):
                        p = q
                    elif i == 0:
                        b = os.path.join(a.bake, "%s_prev_%s.png" % (kit, PREV.get(c, c)))
                        if os.path.exists(b):
                            p, tag = b, "Blender"
                if p and os.path.exists(p):
                    img.paste(fit(Image.open(p), S - 4), (x + 2, y + 2))
                    if tag:
                        d.rectangle((x + 4, y + 4, x + 78, y + 24), fill=(0, 0, 0))
                        d.text((x + 8, y + 5), tag, font=f3, fill=(140, 220, 255))
                else:
                    d.rectangle((x + 2, y + 2, x + S - 2, y + S - 2), outline=(60, 60, 66))
        blocks.append(img)
    notes = Image.new("RGB", (blocks[0].size[0], 30 + 24 * len(a.note)), (24, 24, 28))
    d = ImageDraw.Draw(notes)
    for i, n in enumerate(a.note):
        d.text((10, 10 + 24 * i), n, font=f2, fill=(230, 230, 230))
    H = sum(b.size[1] for b in blocks) + notes.size[1] + 8 * len(blocks)
    sheet = Image.new("RGB", (blocks[0].size[0], H), (12, 12, 14))
    y = 0
    for b in blocks:
        sheet.paste(b, (0, y))
        y += b.size[1] + 8
    sheet.paste(notes, (0, y))
    sheet.save(a.out, quality=90)
    print("sheet", a.out, sheet.size)


if __name__ == "__main__":
    main()
