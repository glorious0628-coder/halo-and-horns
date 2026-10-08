"""Sheet for the cosmetic recolors (A23-75 shop / A23-77 attendance): per theme one row of the rank meshes R1-R5,
each cell = front + 3/4 render + the front at game size (64 px and 40 px on a grass tone), with the theme's glow /
sparkle colours. Renders from tools/img2/acc_render.py (build/acctex/r/<theme>_<Kind>R<r>_{front,34}.png).

  py tools/img2/acc_theme_sheet.py <out.jpg>
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
R = ROOT + "build/acctex/r/"
META = json.load(open(ROOT + "build/acctex/themes.json"))
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG = (24, 30, 64), (250, 245, 236)
SECTIONS = [
    ("[상점 판매] 빛 후광 — 사용자 고름: 얼음 · 황금 (모양 = 계급 R1~R5 그대로, 색만)", [("Now", "Halo", "지금 게임(비교)"), ("HaloIce", "Halo", "얼음"), ("HaloGold", "Halo", "황금")]),
    ("[상점 판매] 뿔 — 사용자 고름: 용암 · 그림자", [("Now", "Horns", "지금 게임(비교)"), ("HornsLava", "Horns", "용암"), ("HornsShadow", "Horns", "그림자")]),
    ("[출석 전용 후보] 상점에 없는 색 — 14일 새싹 / 50·100일 별빛 (같은 방식, 색만)", [("HaloSprout", "Halo", "새싹 후광"), ("HornsSprout", "Horns", "새싹 뿔"),
                                                                    ("HaloStarlight", "Halo", "별빛 후광"), ("HornsStarlight", "Horns", "별빛 뿔")]),
]
V = 170          # render cell
G1, G2 = 64, 40  # game-size previews
CELL = 2 * V + G1 + 14
LEFT = 190


def load(theme, kind, r, view):
    im = Image.open(R + f"{theme}_{kind}R{r}_{view}.png").convert("RGBA")
    bg = Image.new("RGBA", im.size, (128, 128, 128, 255))
    bg.alpha_composite(im)
    return bg.convert("RGB"), im


def small(rgba, size):
    t = Image.new("RGBA", (size, size), (96, 150, 70, 255))
    x = rgba.copy()
    bb = x.getbbox()
    if bb:
        x = x.crop(bb)
    x.thumbnail((size - 4, size - 4), Image.LANCZOS)
    t.alpha_composite(x, ((size - x.width) // 2, (size - x.height) // 2))
    return t.convert("RGB")


rows = sum(len(r) for _, r in SECTIONS)
W = 30 + LEFT + 5 * (CELL + 10)
H = 110 + len(SECTIONS) * 44 + rows * (V + 30)
s = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), "진영 치장 색 바꾸기 (A23-75 · A23-77, 0크레딧) — 모양은 계급 R1~R5 그대로, 텍스처 색만", font=F(28, True), fill=NAVY)
d.text((30, 56), "칸마다: 앞 · 3/4 렌더 + 게임 크기(64px · 40px, 풀색 바탕). 왼쪽 색 = 테마의 둥근 빛(glow)·작은 별(sparkle) 색. 빛살 없음.", font=F(16), fill=(80, 80, 80))
y = 92
for title, items in SECTIONS:
    d.text((30, y), title, font=F(20, True), fill=NAVY)
    y += 34
    for theme, kind, label in items:
        d.text((30, y + 6), label, font=F(18, True), fill=NAVY)
        if theme in META:
            for i, key in enumerate(("glow", "sparkle")):
                c = tuple(META[theme][key])
                d.rounded_rectangle((30, y + 40 + i * 34, 60, y + 70 + i * 34), 6, fill=c, outline=(60, 60, 60))
                d.text((68, y + 44 + i * 34), f"{key} {c}", font=F(13), fill=(70, 70, 70))
        for r in range(1, 6):
            x = 30 + LEFT + (r - 1) * (CELL + 10)
            f_rgb, f_rgba = load(theme, kind, r, "front")
            t_rgb, _ = load(theme, kind, r, "34")
            s.paste(f_rgb.resize((V, V), Image.LANCZOS), (x, y))
            s.paste(t_rgb.resize((V, V), Image.LANCZOS), (x + V, y))
            s.paste(small(f_rgba, G1), (x + 2 * V + 8, y))
            s.paste(small(f_rgba, G2), (x + 2 * V + 8 + (G1 - G2) // 2, y + G1 + 8))
            if theme == items[0][0] or y < 140:
                pass
            d.text((x + 2, y + V + 2), f"R{r}", font=F(13, True), fill=NAVY)
        y += V + 30
    y += 10
s = s.crop((0, 0, W, y))
s.save(sys.argv[1], quality=90)
print(sys.argv[1], s.size)
