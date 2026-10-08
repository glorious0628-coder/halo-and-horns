"""A23-77 / A23-79 small-art candidate sheet: per item A and B, the cutout on light and navy, 64 / 40 px previews;
the day-count ribbon row also shows a 5-tier local recolor (7 / 14 / 28 / 50 / 100 days, 0 credits).

  py tools/img2/ret_sheet.py <out.jpg> [--rec tag,tag]
Cutouts art/out/s2/ret/<tag>_cut.png (made with tools/img2/cut_icon.py).
"""
import colorsys
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
D = ROOT + "art/out/s2/ret/"
OUT = sys.argv[1]
REC = set(sys.argv[sys.argv.index("--rec") + 1].split(",")) if "--rec" in sys.argv else set()
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG, DARK, RED = (24, 30, 64), (250, 245, 236), (40, 44, 70), (170, 40, 40)
ROWS = [
    ("IconWeeklyBox", "① 출석판 7칸째 주간 상자 (빛·뿔 둘 다)"),
    ("IconWeeklyBox_A2", "① 주간 상자 A 다시(A의 뿔 장식이 빨간 물방울처럼 보여서 뿔 모양으로 다시 그림)", "ab"),
    ("StampClaimed", "① '받음' 도장 (받은 칸 위에 얹음)"),
    ("RibbonDays", "① 모은 날 수 리본 (숫자는 게임 글자로 가운데에) — 아래 5색은 같은 그림 색만 바꾼 것"),
    ("IconKingDiary", "② King Diary 책 (호박 대왕 일기, 호박 얼굴 없음)"),
    ("IconCandyJar", "② 사탕 단지"),
    ("IconInviteFriend", "② 친구 초대 (편지 + 후광·뿔 스티커)"),
    ("IconSaved", "② 멈춤 카드 'Saved!' 표시 (책갈피 / 깃발)"),
]
TIERS = [("7", (24, 0.72, 0.80)), ("14", (215, 0.06, 1.0)), ("28", None), ("50", (222, 0.70, 0.95)), ("100", (190, 0.40, 1.12))]


def tile(im, d, bg):
    t = Image.new("RGB", (d, d), bg)
    x = im.copy()
    x.thumbnail((d - 8, d - 8), Image.LANCZOS)
    t.paste(x, ((d - x.width) // 2, (d - x.height) // 2), x)
    return t


def recolor(im, tier):
    """gold pixels (hue 28-62, saturated) -> target hue / sat / value scale; red tails, cream centre, navy outline kept"""
    if tier is None:
        return im
    h0, s0, vm = tier
    a = np.asarray(im).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3:]
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb.reshape(-1, 3)]).reshape(rgb.shape)
    h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    gold = (h > 28) & (h < 62) & (s > 0.38) & (v > 0.25)
    out = rgb.copy()
    nv = np.clip(v * vm, 0, 1)
    ns = np.clip(s * s0 / 0.8, 0, 1)
    flat = np.array([colorsys.hsv_to_rgb(h0 / 360, ns_, nv_) for ns_, nv_ in zip(ns[gold], nv[gold])])
    if len(flat):
        out[gold] = flat
    return Image.fromarray((np.concatenate([out, al], -1) * 255).astype(np.uint8), "RGBA")


CW = 180 * 2 + 90 + 16
W = 30 + 2 * (CW + 24)
heights = [270 + (110 if r[0] == "RibbonDays" else 0) for r in ROWS]
H = 100 + sum(heights)
s = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), "출석판 · 다시 오기 작은 그림 시안 (A23-77 · A23-79) — 중간 0크레딧", font=F(26, True), fill=NAVY)
d.text((30, 52), "칸마다: 밝은 바탕 · 어두운 바탕 · 64px · 40px. A / B 두 안. 글자·숫자·빛살 없음, 투명 누끼.", font=F(15), fill=(80, 80, 80))
y = 90
for row, rh in zip(ROWS, heights):
    key, ko = row[0], row[1]
    variants = row[2] if len(row) > 2 else "AB"
    d.text((30, y), ko, font=F(18, True), fill=NAVY)
    for j, v in enumerate(variants):
        tag = f"{key}{v}" if len(row) > 2 else f"{key}_{v}"
        try:
            im = Image.open(D + tag + "_cut.png").convert("RGBA")
        except OSError:
            continue
        x = 30 + j * (CW + 24)
        yy = y + 30
        s.paste(tile(im, 180, BG), (x, yy))
        s.paste(tile(im, 180, DARK), (x + 186, yy))
        s.paste(tile(im, 64, BG), (x + 372, yy))
        s.paste(tile(im, 40, BG), (x + 384, yy + 72))
        s.paste(tile(im, 64, DARK), (x + 372, yy + 120))
        rec = tag in REC
        d.text((x + 2, yy + 184), tag.split("_", 1)[1] + ("  ★ 추천" if rec else ""), font=F(15, rec), fill=RED if rec else NAVY)
        if key == "RibbonDays":
            for k, (lab, tier) in enumerate(TIERS):
                t = tile(recolor(im, tier), 84, BG)
                s.paste(t, (x + k * 90, yy + 212))
                d.text((x + k * 90 + 30, yy + 296), lab + "일", font=F(13), fill=NAVY)
    y += rh
s.save(OUT, quality=90)
print(OUT, s.size)
