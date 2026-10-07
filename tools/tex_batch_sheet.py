"""
여러 모델 2D↔3D 시트(A23-73, 큰 확대 위주): 모델마다 두 줄.
  위 줄: 2D 시안 | 3D 원본(시안 각도) | 3D 고친 판(시안 각도) | 고친 판 뒤 3/4 | 고친 판 게임 카메라
  아래 줄: 시안에서 가장 자세한 두 곳을 크게 — [2D | 원본 | 고친 판] × 2  (아래 작은 숫자 ΔE는 참고만)

  py tools/tex_batch_sheet.py <out_prefix> <work_root> <dir>[:<label>[:<concept name>]] ... [--per 5] [--title "..."]

- work_root/<name>/ 에 tex_fix.py 결과(cam.json, choice.json, r/<label>_orig_*.png, r/<label>_fixed_*.png)가 있어야 한다.
- 시안 = art/out/hq/HQ_<name>.png. 크기·개수 메모 = build/tripo_3b_web.json(있으면).
- 결과: <out_prefix>_1.jpg, _2.jpg ... (모델 --per 개씩)
"""
import argparse
import json
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("root")
ap.add_argument("names", nargs="+")
ap.add_argument("--per", type=int, default=5)
ap.add_argument("--title", default="2D↔3D 질감·재질 시트")
a = ap.parse_args()

FONT = "C:/Windows/Fonts/malgunbd.ttf"
f_big = ImageFont.truetype(FONT, 34)
f_mid = ImageFont.truetype(FONT, 24)
f_small = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 19)
LAB = 250
CELL = 320
BIG = 350
info = {}
if os.path.exists("build/tripo_3b_web.json"):
    for it in json.load(open("build/tripo_3b_web.json", encoding="utf-8")):
        info[it["name"]] = it


def bg_of(arr):
    c = 12
    return np.median(np.concatenate([arr[:c, :c].reshape(-1, 3), arr[-c:, -c:].reshape(-1, 3)]), 0)


def aligned(path, cam, size, bg):
    r = Image.open(path).convert("RGBA")
    s = cam["scale"] * cam.get("render_size", 1024) / r.width
    r2 = r.resize((round(r.width * s), round(r.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", size, bg + (255,))
    dx, dy = round(cam["dx"]), round(cam["dy"])
    crop = r2.crop((max(0, -dx), max(0, -dy), r2.width, r2.height))
    out.alpha_composite(crop, (max(0, dx), max(0, dy)))
    return out.convert("RGB")


def square_on_bg(path, bg):
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox() or (0, 0, im.width, im.height)
    side = int(max(box[2] - box[0], box[3] - box[1]) * 1.08)
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    out = Image.new("RGBA", (side, side), bg + (255,))
    out.alpha_composite(im.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)))
    return out.convert("RGB")


def detail_windows(con, fg, n=2):
    """the n most detailed square windows inside the object (edge density), not overlapping much"""
    ys, xs = np.nonzero(fg)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
    s = int(0.42 * max(x1 - x0, y1 - y0))
    g = cv2.cvtColor(con, cv2.COLOR_RGB2GRAY).astype(np.float32)
    e = np.hypot(cv2.Sobel(g, cv2.CV_32F, 1, 0), cv2.Sobel(g, cv2.CV_32F, 0, 1)) * fg
    ii = cv2.integral(e)
    fi = cv2.integral(fg.astype(np.float32))
    best = []
    step = max(8, s // 8)
    for yy in range(max(0, y0 - s // 4), min(con.shape[0] - s, y1 - s // 2) + 1, step):
        for xx in range(max(0, x0 - s // 4), min(con.shape[1] - s, x1 - s // 2) + 1, step):
            area = fi[yy + s, xx + s] - fi[yy, xx + s] - fi[yy + s, xx] + fi[yy, xx]
            if area < 0.45 * s * s:
                continue
            sc = ii[yy + s, xx + s] - ii[yy, xx + s] - ii[yy + s, xx] + ii[yy, xx]
            best.append((sc, xx, yy))
    best.sort(reverse=True)
    picked = []
    for sc, xx, yy in best:
        if all(abs(xx - px) > s * 0.6 or abs(yy - py) > s * 0.6 for _, px, py in picked):
            picked.append((sc, xx, yy))
        if len(picked) == n:
            break
    return [(xx, yy, xx + s, yy + s) for _, xx, yy in picked]


def lab(img):
    return cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2LAB).astype(np.float32)


def block(name, label, cname=None):
    W = os.path.join(a.root, name)
    R = os.path.join(W, "r")
    cam = json.load(open(os.path.join(W, "cam.json")))
    choice = json.load(open(os.path.join(W, "choice.json"))) if os.path.exists(os.path.join(W, "choice.json")) else {}
    con_img = Image.open(f"art/out/hq/HQ_{cname or name}.png").convert("RGB")
    con = np.asarray(con_img)
    bgc = bg_of(con.astype(np.int16))
    BG = tuple(int(v) for v in bgc)
    fg = (np.abs(con.astype(np.int16) - bgc).max(-1) > 14).astype(np.uint8)
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    orig_m = aligned(os.path.join(R, f"{label}_orig_match.png"), cam, con_img.size, BG)
    fix_m = aligned(os.path.join(R, f"{label}_fixed_match.png"), cam, con_img.size, BG)
    back = square_on_bg(os.path.join(R, f"{label}_fixed_back34.png"), BG)
    game = square_on_bg(os.path.join(R, f"{label}_fixed_game.png"), BG)
    wins = detail_windows(con, fg)
    h = 40 + CELL + 30 + BIG + 50
    img = Image.new("RGB", (LAB + 6 * BIG + 40, h), (236, 238, 242))
    d = ImageDraw.Draw(img)
    it = info.get(cname or name, {})
    lines = [name, f"크기 {it.get('size_studs', '?')} · {it.get('count', '?')}개",
             "색: " + {"pair": "④' 앞면 짝", "band": "④ 색 띠"}.get(choice.get("colour_fix"), "?") + " + AO",
             "③ 앞면 투영" if choice.get("front_projection") else "③ 없음(사방에서 봄)",
             "금속 0.15 · 거칠기 맵"]
    yy = 46
    for i, t in enumerate(lines):
        d.text((14, yy), t, font=f_mid if i == 0 else f_small, fill=(20, 20, 30) if i == 0 else (60, 60, 70))
        yy += 34 if i == 0 else 26
    heads = ["2D 시안", "3D 원본(시안 각도)", "3D 고친 판(시안 각도)", "고친 판 뒤 3/4", "고친 판 게임 카메라"]
    for k, (t, im) in enumerate(zip(heads, [con_img, orig_m, fix_m, back, game])):
        x = LAB + k * (CELL + 8)
        d.text((x + 4, 8), t, font=f_small, fill=(30, 30, 40))
        img.paste(im.resize((CELL, CELL), Image.LANCZOS), (x, 36))
    y2 = 36 + CELL + 26
    con_l, orig_l, fix_l = lab(con_img), lab(orig_m), lab(fix_m)
    for wi, (x0, y0, x1, y1) in enumerate(wins):
        for k, (t, im, L) in enumerate((("2D", con_img, None), ("원본", orig_m, orig_l), ("고친 판", fix_m, fix_l))):
            x = LAB + (wi * 3 + k) * BIG + wi * 20
            img.paste(im.crop((x0, y0, x1, y1)).resize((BIG - 6, BIG - 6), Image.LANCZOS), (x, y2))
            d.text((x + 6, y2 + BIG - 4), f"확대 {wi + 1} · {t}", font=f_small, fill=(30, 30, 40))
            if L is not None:
                m = fg[y0:y1, x0:x1] > 0
                de = np.linalg.norm(L[y0:y1, x0:x1] - con_l[y0:y1, x0:x1], axis=-1)[m].mean() if m.sum() > 50 else float("nan")
                d.text((x + BIG - 110, y2 + BIG - 4), f"ΔE {de:.0f}", font=f_small, fill=(110, 110, 120))
    return img


blocks = []
for n in a.names:
    name, label, cname = (n.split(":") + [None, None])[:3]
    try:
        blocks.append(block(name, label or name, cname))
        print("ok", name, flush=True)
    except Exception as e:
        print("SKIP", name, e, flush=True)
for si in range(0, len(blocks), a.per):
    part = blocks[si:si + a.per]
    Wd = max(b.width for b in part)
    sheet = Image.new("RGB", (Wd, 90 + sum(b.height + 16 for b in part)), (236, 238, 242))
    d = ImageDraw.Draw(sheet)
    d.text((20, 18), f"{a.title} ({si // a.per + 1}/{(len(blocks) + a.per - 1) // a.per})", font=f_big, fill=(20, 20, 30))
    d.text((20, 60), "같은 조명(Blender EEVEE) · 시안 각도 = 실루엣 맞춤 · 확대 칸은 시안에서 가장 자세한 두 곳 · ΔE는 참고(눈으로 판단)", font=f_small, fill=(70, 70, 80))
    y = 90
    for b in part:
        sheet.paste(b, (0, y))
        y += b.height + 16
        ImageDraw.Draw(sheet).line((0, y - 8, Wd, y - 8), fill=(200, 202, 208), width=3)
    out = f"{a.out}_{si // a.per + 1}.jpg"
    sheet.save(out, quality=88)
    print("[tex_batch_sheet]", out, sheet.size, flush=True)
