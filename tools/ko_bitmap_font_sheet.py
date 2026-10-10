"""Korean bitmap-font candidates (A23-111 보강, 이미지 개발 2026-10-10): one sheet, the same places as the Nanum sheet
(ribbon title, window title, 3 body lines, Claim / OK buttons, menu tile names, numbers) for each OFL font in art/fonts/,
drawn with PIL on the approved art (art/ui TitleRibbon / PanelDark / BtnPrimary / BtnConfirm, 9-sliced like Config.UIArt).
Below each column the body line again at the real screen sizes 14 / 16 / 18 px (1:1, no upscale). Numbers in Denk One
(Roblox's file, today's look) and in the font's own digits.

  py tools/ko_bitmap_font_sheet.py [--out art/review/imgdev/ko_bitmap_font_candidates_2026-10-10.png]
Fonts are only read to draw pictures; nothing is installed or run.
"""
import argparse
import glob
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "art", "ui")
FONTS = [
    ("Jua", "jua/Jua-Regular.ttf"),
    ("Do Hyeon", "dohyeon/DoHyeon-Regular.ttf"),
    ("Black Han Sans", "blackhansans/BlackHanSans-Regular.ttf"),
    ("Bagel Fat One", "bagelfatone/BagelFatOne-Regular.ttf"),
    ("Dongle Bold (x1.6)", "dongle/Dongle-Bold.ttf"),
    ("Gasoek One", "gasoekone/GasoekOne-Regular.ttf"),
]
NAVY = (16, 24, 56)
BROWN = (78, 44, 14)
WHITE = (255, 255, 255)
KO = {"ribbon": "퀘스트", "window": "가방",
      "body": ["고블린 대장을 처치하세요 (3/5)", "물약을 1번 칸에 넣고", "한 번 써 보세요."],
      "ok": "받기", "yes": "확인", "tags": ["영웅", "가방", "스킬", "지도", "순위", "펫"],
      "num": "Lv 12 · 150", "big": "+150G"}
# Config.UIArt slices (image px): left, top, right, bottom of the centre
SLICE = {"TitleRibbon": (118, 40, 394, 95), "PanelDark": (52, 52, 460, 177), "BtnPrimary": (73, 81, 443, 83),
         "BtnConfirm": (69, 77, 445, 79)}


def denk():
    hits = sorted(glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts",
                                         "DenkOne-Regular.ttf")))
    return hits[-1] if hits else None


def nine(name, w, h, edge=0.5):
    """9-slice the art to w x h; corners scaled by edge (Config SliceScale), capsules (thin centre) keep full height."""
    im = Image.open(os.path.join(UI, name + ".png")).convert("RGBA")
    L, T, R, B = SLICE[name]
    W, H = im.size
    k = min(edge, h / H) if B - T < 10 else edge  # capsule art: the height decides the edge scale
    if B - T < 10:
        k = h / H
    l, t, r, b = int(L * k), int(T * k), int((W - R) * k), int((H - B) * k)
    out = Image.new("RGBA", (w, h))
    xs_src = [0, L, R, W]
    ys_src = [0, T, B, H]
    xs_dst = [0, l, max(l, w - r), w]
    ys_dst = [0, t, max(t, h - b), h]
    for i in range(3):
        for j in range(3):
            sb = (xs_src[i], ys_src[j], xs_src[i + 1], ys_src[j + 1])
            db = (xs_dst[i], ys_dst[j], xs_dst[i + 1], ys_dst[j + 1])
            if sb[2] - sb[0] <= 0 or sb[3] - sb[1] <= 0 or db[2] - db[0] <= 0 or db[3] - db[1] <= 0:
                continue
            out.alpha_composite(im.crop(sb).resize((db[2] - db[0], db[3] - db[1]), Image.LANCZOS), (db[0], db[1]))
    return out


def text(img, xy, s, font, fill=WHITE, stroke=None, sw=0, shadow=None, anchor="mm"):
    d = ImageDraw.Draw(img)
    if shadow:
        dx, dy, col = shadow
        d.text((xy[0] + dx, xy[1] + dy), s, font=font, fill=col, stroke_width=sw, stroke_fill=col, anchor=anchor)
    d.text(xy, s, font=font, fill=fill, stroke_width=sw, stroke_fill=stroke or fill, anchor=anchor)


# Dongle's em box is small: drawn 1.6x so its letters are as tall as the others (the same visual size)
SCALE = {"dongle/Dongle-Bold.ttf": 1.6}


def column(fontfile, label, dk, W=360, H=1060):
    col = Image.new("RGBA", (W, H), (196, 178, 140, 255))
    fk = next((v for key, v in SCALE.items() if fontfile.replace(os.sep, "/").endswith(key)), 1.0)
    f = lambda px: ImageFont.truetype(fontfile, max(1, round(px * fk)))  # noqa: E731
    d = ImageDraw.Draw(col)
    cap = ImageFont.truetype(dk, 18) if dk else f(18)
    d.rectangle((6, 6, W - 6, 40), fill=(40, 34, 24))
    d.text((W // 2, 23), label, font=cap, fill=(255, 250, 200), anchor="mm")
    # ribbon title
    col.alpha_composite(nine("TitleRibbon", W - 40, 84), (20, 50))
    text(col, (W // 2, 50 + 40), KO["ribbon"], f(46), stroke=NAVY, sw=4, shadow=(0, 3, (16, 24, 56, 140)))
    # window
    col.alpha_composite(nine("PanelDark", W - 28, 330, 0.35), (14, 146))
    text(col, (W // 2, 190), KO["window"], f(40), stroke=NAVY, sw=4, shadow=(0, 3, (0, 0, 0, 120)))
    for i, line in enumerate(KO["body"]):
        text(col, (36, 236 + i * 32), line, f(24), anchor="lm")
    col.alpha_composite(nine("BtnPrimary", 140, 64), (30, 384))
    text(col, (100, 414), KO["ok"], f(32), stroke=BROWN, sw=3)
    col.alpha_composite(nine("BtnConfirm", 140, 64), (W - 170, 384))
    text(col, (W - 100, 414), KO["yes"], f(32), stroke=BROWN, sw=3)
    # numbers: Denk One (today) | the font's own
    if dk:
        text(col, (W // 4, 512), KO["num"], ImageFont.truetype(dk, 30), stroke=NAVY, sw=3)
        text(col, (W // 4, 566), KO["big"], ImageFont.truetype(dk, 52), stroke=NAVY, sw=4)
    text(col, (3 * W // 4, 512), KO["num"], f(30), stroke=NAVY, sw=3)
    text(col, (3 * W // 4, 566), KO["big"], f(52), stroke=NAVY, sw=4)
    d.text((W // 4, 604), "Denk One", font=cap, fill=(60, 40, 20), anchor="mm")
    d.text((3 * W // 4, 604), "own digits", font=cap, fill=(60, 40, 20), anchor="mm")
    # menu tiles (the HUD 60 px squares at 1.5x = 90 px, names ~19 px)
    for k, tag in enumerate(KO["tags"]):
        x = 18 + (k % 3) * 110
        y = 630 + (k // 3) * 104
        d.rounded_rectangle((x, y, x + 96, y + 96), radius=12, fill=(34, 52, 104), outline=(230, 186, 84), width=3)
        text(col, (x + 48, y + 78), tag, f(22), stroke=NAVY, sw=3)
    # real screen sizes, 1:1
    y = 852
    d.rectangle((10, y - 8, W - 10, H - 10), fill=(22, 32, 70))
    for px in (14, 16, 18):
        d.text((20, y), f"{px}px", font=cap, fill=(255, 220, 140))
        d.text((64, y), KO["body"][0], font=f(px), fill=WHITE)
        d.text((64, y + px + 6), KO["body"][2] + " 순위 · 펫 · 받기", font=f(px), fill=WHITE)
        y += 2 * px + 22
    return col


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "review", "imgdev", "ko_bitmap_font_candidates_2026-10-10.png"))
    a = ap.parse_args()
    dk = denk()
    cols = []
    for label, rel in FONTS:
        p = os.path.join(ROOT, "art", "fonts", rel)
        if os.path.isfile(p):
            cols.append(column(p, label, dk))
    sheet = Image.new("RGBA", (sum(c.width for c in cols), cols[0].height), (30, 30, 36, 255))
    x = 0
    for c in cols:
        sheet.alpha_composite(c, (x, 0))
        x += c.width
    sheet.convert("RGB").save(a.out)
    print(a.out, sheet.size, len(cols), "fonts", "denk" if dk else "no denk")


if __name__ == "__main__":
    main()
