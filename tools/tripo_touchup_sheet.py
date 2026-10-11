"""Sheet for tools/tripo_touchup.py results (이미지 생성 4, 10/12): per job one row = the 2D front Tripo got | the touched-up
model with its part-built body (front / left / back / right Blender renders) | the baked colour map, plus the numbers.

  py tools/tripo_touchup_sheet.py <out.jpg> <job> [<job> ...] [--cell 240]
"""
import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TU = os.path.join(ROOT, "art", "models", "tripo", "touchup")


def font(sz):
    for f in ("C:/Windows/Fonts/malgunbd.ttf", "C:/Windows/Fonts/malgun.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("jobs", nargs="+")
    ap.add_argument("--cell", type=int, default=240)
    a = ap.parse_args()
    rec = json.load(open(os.path.join(ROOT, "art", "models", "tripo", "records.json"), encoding="utf-8"))
    S, TH = a.cell, 26
    f1 = font(16)
    sheet = Image.new("RGB", (S * 6, (S + TH) * len(a.jobs)), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    for i, job in enumerate(a.jobs):
        y = i * (S + TH)
        st = json.load(open(os.path.join(TU, job, job + "_TU.json")))
        d.text((6, y + 4), "%s  [%s]  삼각형 %s→%s, 크기 %s, 맵 %dpx C/N/R/M  |  2D | 앞 | 왼 | 뒤 | 오른 (파트 몸통 같이) | 색 맵"
               % (job, st["kind"], st["src_tris"], st["tris"], "×".join("%.2f" % v for v in st["size"]), st["px"]),
               font=f1, fill=(255, 255, 255))
        e = rec[job + "_web_hd_mv4"][-1]
        ims = [os.path.join(ROOT, e["inputs"]["front"])]
        ims += [os.path.join(TU, job, "%s_TU_%s.png" % (job, v)) for v in ("front", "left", "back", "right", "C")]
        for j, p in enumerate(ims):
            if os.path.exists(p):
                im = Image.open(p).convert("RGB").resize((S - 4, S - 4))
                sheet.paste(im, (j * S + 2, y + TH))
    sheet.save(a.out, quality=88)
    print("sheet", a.out, sheet.size)


if __name__ == "__main__":
    main()
