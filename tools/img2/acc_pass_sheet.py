"""Review sheet for the A23-75 shop art candidates (Medium): faction cosmetics (halo / horns themes, A = R3 base,
B = R4 base, two views each) next to the current in-game R3/R4, then the game-pass icons (A = plain icon,
B = round badge) at full size, as a circle (Roblox store crop) and small (64 / 40 px).

  py tools/img2/acc_pass_sheet.py <out.jpg> [--rec tag,tag,...]
Sources: art/out/s2/shop/<tag>_src.png (Firefly downloads); base: art/out/acc/{Halo,Horns}R{3,4}_src.png.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
D = ROOT + "art/out/s2/shop/"
OUT = sys.argv[1]
REC = set(sys.argv[sys.argv.index("--rec") + 1].split(",")) if "--rec" in sys.argv else set()
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG, RED = (24, 30, 64), (250, 245, 236), (170, 40, 40)
HALO = [("Flame", "불꽃"), ("Frost", "얼음"), ("Rainbow", "무지개"), ("Royal", "황금")]
HORN = [("Lava", "용암"), ("Frost", "서리"), ("Shadow", "그림자"), ("Gem", "보석")]
ICON = [("Exp2", "경험치 2배"), ("Gold2", "골드 2배"), ("VIP", "VIP 왕관"), ("Bundle", "치장 묶음")]
CW, CH = 420, 280


def load(p, size):
    try:
        im = Image.open(p).convert("RGB")
    except OSError:
        im = Image.new("RGB", (3, 2), (200, 200, 200))
    im.thumbnail(size, Image.LANCZOS)
    t = Image.new("RGB", size, (128, 128, 128))
    t.paste(im, ((size[0] - im.width) // 2, (size[1] - im.height) // 2))
    return t


def circle(im, d):
    im = im.resize((d, d), Image.LANCZOS)
    m = Image.new("L", (d, d), 0)
    ImageDraw.Draw(m).ellipse((0, 0, d - 1, d - 1), fill=255)
    t = Image.new("RGB", (d, d), (240, 240, 240))
    t.paste(im, (0, 0), m)
    return t


rows_acc = [("빛 후광 (지금 R3 · R4 모양 그대로, 색·재질만)", "Halo", HALO), ("뿔 (지금 R3 · R4 모양 그대로, 색·재질만)", "Horns", HORN)]
W = 30 + (CW + 12) * 5
H = 120 + 2 * (40 + 2 * (CH + 34)) + 60 + 2 * (300 + 40)
s = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), "수익 상품 그림 시안 (A23-75, 중간 0크레딧) — 진영 치장 8종 × 2안 + 게임 패스 아이콘 4종 × 2안", font=F(28, True), fill=NAVY)
d.text((30, 56), "치장: A = 지금 R3 모양(앞·3/4 두 모습), B = 지금 R4 모양. 둥근 빛·작은 반짝이만(퍼지는 빛살 없음). "
       "아이콘: A = 우리 UI 아이콘처럼 그림만, B = 둥근 배지. 글자·숫자 없음.", font=F(16), fill=(80, 80, 80))
y = 96
for title, kind, themes in rows_acc:
    d.text((30, y), title, font=F(22, True), fill=NAVY)
    y += 36
    for j, v in enumerate("AB"):
        x = 30
        base = ROOT + f"art/out/acc/{kind}R{3 if v == 'A' else 4}_src.png"
        s.paste(load(base, (CW, CH)), (x, y))
        d.text((x + 4, y + CH + 4), f"지금 게임 {kind} R{3 if v == 'A' else 4}", font=F(15), fill=NAVY)
        for i, (name, ko) in enumerate(themes):
            tag = f"ACC_{kind}{name}_{v}"
            x = 30 + (i + 1) * (CW + 12)
            s.paste(load(D + tag + "_src.png", (CW, CH)), (x, y))
            rec = tag in REC
            d.text((x + 4, y + CH + 4), f"{ko} {v}" + ("  ★ 추천" if rec else ""), font=F(16, rec), fill=RED if rec else NAVY)
        y += CH + 34
    y += 6
d.text((30, y), "게임 패스 아이콘 (512×512용) — 왼쪽 큰 그림 · 가운데 상점 원형 자르기 · 오른쪽 64px·40px", font=F(22, True), fill=NAVY)
y += 40
for v in "AB":
    x = 30
    for name, ko in ICON:
        tag = f"PassIcon_{name}_{v}"
        im = load(D + tag + "_src.png", (230, 230))
        s.paste(im, (x, y))
        s.paste(circle(im, 150), (x + 236, y))
        sm = im.resize((64, 64), Image.LANCZOS)
        s.paste(sm, (x + 236, y + 160))
        s.paste(im.resize((40, 40), Image.LANCZOS), (x + 310, y + 172))
        rec = tag in REC
        d.text((x + 2, y + 236), f"{ko} {v}" + ("  ★ 추천" if rec else ""), font=F(16, rec), fill=RED if rec else NAVY)
        x += 236 + 160 + 160
    y += 300
s = s.crop((0, 0, W, y + 10))
s.save(OUT, quality=90)
print(OUT, s.size)
