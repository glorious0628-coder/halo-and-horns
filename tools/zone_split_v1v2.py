"""'now in game | v1 | v2' 100% crop sheet of a zone batch (이미지 개발 2026-10-10): the same close-up camera, the same spots.

  py tools/zone_split_v1v2.py <zone> [--only A,B]
now = shots/<name>_before.png, v1 = shots_v1/<name>_after.png (first recipe), v2 = shots/<name>_after.png (the run just made,
이미지 생성 1's recipe). Crop spots = the package's (art/review/imgdev/<zone>_split/package.json), 256 px each.
Writes art/review/imgdev/<zone>_split_v1v2.jpg.
"""
import argparse
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GREY = (128, 132, 140)


def on_grey(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, GREY + (255,))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("zone")
    ap.add_argument("--only")
    ap.add_argument("--no-v1", default="", help="models whose v1 renders used another camera (left blank)")
    a = ap.parse_args()
    no_v1 = set(x for x in a.no_v1.split(",") if x)
    work = os.path.join(ROOT, "art", "models", "tripo", f"split_{a.zone}")
    with open(os.path.join(ROOT, "art", "review", "imgdev", f"{a.zone}_split", "package.json"), encoding="utf-8") as f:
        pkg = json.load(f)
    names = [n for n in pkg if not a.only or n in a.only.split(",")]
    C, cols = 256, 3
    rows = []
    for n in names:
        paths = [os.path.join(work, "shots", n + "_before.png"), os.path.join(work, "shots_v1", n + "_after.png"),
                 os.path.join(work, "shots", n + "_after.png")]
        if not all(os.path.isfile(p) for i, p in enumerate(paths) if not (i == 1 and n in no_v1)):
            continue
        ims = [on_grey(p) if os.path.isfile(p) else Image.new("RGB", (1536, 1536), GREY) for p in paths]
        for x, y in pkg[n]["crops"][:2]:
            crops = [im.crop((x, y, x + C, y + C)) for im in ims]
            if n in no_v1:
                crops[1] = Image.new("RGB", (C, C), (60, 60, 66))
                ImageDraw.Draw(crops[1]).text((10, C // 2), "v1: other camera", fill=(200, 200, 200))
            rows.append((n, crops))
    W = 220 + cols * (C + 8)
    H = 30 + len(rows) * (C + 8)
    sheet = Image.new("RGB", (W, H), (34, 34, 40))
    d = ImageDraw.Draw(sheet)
    for i, t in enumerate(("now (game)", "v1 (first recipe)", "v2 (img1 recipe, gold hue >= 34)")):
        d.text((220 + i * (C + 8) + 4, 8), t, fill=(255, 230, 150))
    for r, (n, crops) in enumerate(rows):
        y = 30 + r * (C + 8)
        d.text((8, y + 8), n, fill=(240, 240, 240))
        for i, c in enumerate(crops):
            sheet.paste(c, (220 + i * (C + 8), y))
    out = os.path.join(ROOT, "art", "review", "imgdev", f"{a.zone}_split_v1v2.jpg")
    sheet.save(out, quality=90)
    print(out, len(rows), "rows")


if __name__ == "__main__":
    main()
