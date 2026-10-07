"""
2D↔3D 질감·재질 비교 시트(A23-73): 방법(①~⑤)마다 한 줄 — 2D 시안과 같은 각도(match) + 앞·뒤·게임 카메라 + 질감 확대 칸.

  py tools/tex_compare_sheet.py <render_dir> <concept.png> <cam.json> <out.jpg> <spec.json>

spec.json = {"title": "...", "subtitle": "...",
             "crops": [["이름", x0, y0, x1, y1], ...],          # 시안(1024) 좌표, 질감 확대 칸
             "rows": [{"label": "orig", "name": "0 원본", "cost": "0", "note": "..."}, ...]}

- match 렌더는 cam.json 변환(scale, dx, dy)으로 시안 위치에 맞춰 시안과 같은 회색 바탕에 놓는다.
- 확대 칸 아래 숫자 = 시안과의 색 차이 ΔE(Lab, 둘 다 물체인 픽셀 평균, 낮을수록 시안과 비슷).
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

RD, CONCEPT, CAM, OUT, SPEC = sys.argv[1:6]
spec = json.load(open(SPEC, encoding="utf-8"))
cam = json.load(open(CAM, encoding="utf-8"))
FONT = "C:/Windows/Fonts/malgunbd.ttf"
f_big = ImageFont.truetype(FONT, 34)
f_mid = ImageFont.truetype(FONT, 22)
f_small = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 18)
con = Image.open(CONCEPT).convert("RGB")
arr = np.asarray(con).astype(np.int16)
c = 12
bgc = np.median(np.concatenate([arr[:c, :c].reshape(-1, 3), arr[-c:, -c:].reshape(-1, 3)]), 0)
BG = tuple(int(x) for x in bgc)
con_fg = np.abs(arr - bgc).max(-1) > 14


def aligned(path):
    r = Image.open(path).convert("RGBA")
    s = cam["scale"] * cam.get("render_size", 1024) / r.width
    r2 = r.resize((round(r.width * s), round(r.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", con.size, BG + (255,))
    dx, dy = round(cam["dx"]), round(cam["dy"])
    crop = r2.crop((max(0, -dx), max(0, -dy), r2.width, r2.height))
    out.alpha_composite(crop, (max(0, dx), max(0, dy)))
    alpha = np.zeros(con.size[::-1], bool)
    a = np.asarray(crop)[..., 3] > 128
    h, w = alpha.shape
    y0, x0 = max(0, dy), max(0, dx)
    hh, ww = min(a.shape[0], h - y0), min(a.shape[1], w - x0)
    alpha[y0:y0 + hh, x0:x0 + ww] = a[:hh, :ww]
    return out.convert("RGB"), alpha


def on_bg(path):
    """render on the concept grey, cropped square around the object (renders frame the bounding sphere, so the object is small)"""
    im = Image.open(path).convert("RGBA")
    x0, y0, x1, y1 = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0, im.width, im.height)
    side = int(max(x1 - x0, y1 - y0) * 1.08)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    bg = Image.new("RGBA", (side, side), BG + (255,))
    bg.alpha_composite(im.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)))
    return bg.convert("RGB")


def fit_box(img, w, h):
    s = min(w / img.width, h / img.height)
    im = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    box = Image.new("RGB", (w, h), BG)
    box.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
    return box


def lab(img):
    return cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2LAB).astype(np.float32) * [100 / 255, 1, 1] - [0, 128, 128]


con_lab = lab(con)
CELL = 300
CROP = 220
LABW = 300
crops = spec["crops"]
views = ["front34", "back34", "game"]
ncol_w = LABW + CELL * (1 + len(views)) + CROP * len(crops) + 20
rows = spec["rows"]
H_HEAD = 120
row_h = CELL + 40
sheet = Image.new("RGB", (ncol_w, H_HEAD + row_h * (len(rows) + 1) + 20), (236, 238, 242))
d = ImageDraw.Draw(sheet)
d.text((20, 16), spec["title"], font=f_big, fill=(20, 20, 30))
d.text((20, 64), spec.get("subtitle", ""), font=f_small, fill=(60, 60, 70))
x_cols = [LABW + CELL * i for i in range(1 + len(views))] + [LABW + CELL * (1 + len(views)) + CROP * i for i in range(len(crops))]
heads = ["2D 각도(match)", "앞 3/4", "뒤 3/4", "게임 카메라"] + [f"질감: {cr[0]}" for cr in crops]
for x, t in zip(x_cols, heads):
    d.text((x + 6, H_HEAD - 30), t, font=f_mid, fill=(30, 30, 40))


def wrap(text, font, width):
    lines, cur = [], ""
    for ch in text:
        if d.textlength(cur + ch, font=font) > width:
            lines.append(cur)
            cur = ch.lstrip()
        else:
            cur += ch
    return lines + ([cur] if cur else [])


def put_row(y, label_lines, match_img, alpha, view_imgs):
    yy = y + 8
    for i, t in enumerate(label_lines):
        font = f_mid if i == 0 else f_small
        for part in wrap(t, font, LABW - 24):
            d.text((14, yy), part, font=font, fill=(20, 20, 30) if i == 0 else (60, 60, 70))
            yy += 30 if i == 0 else 24
    if match_img is None:
        return
    sheet.paste(match_img.resize((CELL - 8, CELL - 8), Image.LANCZOS), (x_cols[0] + 4, y + 4))
    for k, im in enumerate(view_imgs):
        if im is not None:
            sheet.paste(im.resize((CELL - 8, CELL - 8), Image.LANCZOS), (x_cols[1 + k] + 4, y + 4))
    for k, (nm, x0, y0, x1, y1) in enumerate(crops):
        cx = x_cols[1 + len(views) + k]
        sheet.paste(fit_box(match_img.crop((x0, y0, x1, y1)), CROP - 8, CELL - 40), (cx + 4, y + 4))
        if alpha is not None:
            both = alpha[y0:y1, x0:x1] & con_fg[y0:y1, x0:x1]
            if both.sum() > 50:
                de = np.sqrt(((lab(match_img.crop((x0, y0, x1, y1))) - con_lab[y0:y1, x0:x1]) ** 2).sum(-1))[both].mean()
                d.text((cx + 8, y + CELL - 32), f"ΔE {de:.1f}", font=f_mid, fill=(150, 30, 30) if de > 25 else (30, 110, 40))


y = H_HEAD
put_row(y, ["2D 시안(기준)", "고른 2D 그대로"], con, None, [None] * len(views))
for r in rows:
    y += row_h
    lines = [r["name"], f"비용 {r.get('cost', '0')}"] + [s for s in r.get("note", "").split("\n") if s]
    if not os.path.exists(os.path.join(RD, f"{r['label']}_match.png")):
        put_row(y, lines, None, None, [])
        d.text((x_cols[0] + 14, y + CELL // 2 - 14), r.get("pending", "아직 없음"), font=f_mid, fill=(120, 120, 130))
        d.line((0, y - 4, ncol_w, y - 4), fill=(200, 202, 208), width=2)
        continue
    m, al = aligned(os.path.join(RD, f"{r['label']}_match.png"))
    vimgs = [on_bg(os.path.join(RD, f"{r['label']}_{v}.png")) if os.path.exists(os.path.join(RD, f"{r['label']}_{v}.png")) else None for v in views]
    put_row(y, lines, m, al, vimgs)
    d.line((0, y - 4, ncol_w, y - 4), fill=(200, 202, 208), width=2)
sheet.save(OUT, quality=88)
print("[tex_compare_sheet]", OUT, sheet.size)
