"""Side-by-side check sheet for a skeleton house: 2D front | Tripo model | skeleton (+ kept Tripo pieces), whole views and
100% crops of the door, a window, the top corner and the base band (이미지 생성 3, 10/11, SPEC A23-120).

  py tools/skeleton_sheet.py <2d.png> <tripo_dir> <skel_dir> <out.jpg> [--cx -0.25] [--title "..."] [--note "..."]
        [--first "row title|label=path;label=path" ...] [--studio "row title|label=path;..." ...]

tripo_dir / skel_dir = tools/skeleton_preview.py outputs (front.png etc.: ortho, 24 studs across, centre (cx, z 9.8)).
Crop boxes are in studs on the front view (x, z; +x is on the image left); the 2D boxes are given in its own pixels.
"""
import argparse

from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("img2d")
ap.add_argument("tripo")
ap.add_argument("skel")
ap.add_argument("out")
ap.add_argument("--cx", type=float, default=-0.25)
ap.add_argument("--title", default="")
ap.add_argument("--note", default="")
ap.add_argument("--studio", nargs="*", default=[], help="extra row(s) of Studio photos: 'row title|label=path;label=path'")
ap.add_argument("--first", nargs="*", default=[], help="row(s) in the same form, put at the top")
a = ap.parse_args()
PX = 1400 / 24.0
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 22)
    FONT_S = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 18)
except OSError:
    FONT = FONT_S = ImageFont.load_default()

# (label, Tripo render box, skeleton render box (studs: x_left, x_right, z_bottom, z_top; x_left > x_right because +x is
# image left), 2D box px). The skeleton v4 is 1.13 x the Tripo body (door kept 5.0 x 8.15), so its boxes differ.
CROPS = [
    ("문", (4.0, -4.0, 0.0, 10.6), (4.0, -4.0, 0.0, 10.6), (365, 515, 660, 905)),
    ("창 (대각면)", (7.4, 4.3, 4.6, 10.8), (7.0, 3.9, 4.4, 10.6), (190, 420, 315, 680)),
    ("윗 모서리·처마", (8.6, 3.2, 9.4, 14.8), (9.0, 3.6, 9.0, 14.4), (160, 285, 430, 520)),
    ("바닥 띠·화단", (9.8, 2.0, -0.4, 3.8), (9.6, 1.8, -0.4, 4.0), (130, 640, 530, 905)),
]


def render_crop(path, box):
    im = Image.open(path).convert("RGB")
    xl, xr, zb, zt = box
    l = 700 - (xl - a.cx) * PX
    r = 700 - (xr - a.cx) * PX
    t = 700 - (zt - 9.8) * PX
    b = 700 - (zb - 9.8) * PX
    return im.crop((int(l), int(t), int(r), int(b)))


def crop2d(box, size):
    im = Image.open(a.img2d).convert("RGB")
    l, r, t, b = box[0], box[2], box[1], box[3]
    c = im.crop((l, t, r, b))
    s = size[1] / c.height
    return c.resize((max(1, int(c.width * s)), size[1]), Image.LANCZOS)


rows = []
# whole views
views = [("2D 시안", Image.open(a.img2d).convert("RGB").resize((560, 560), Image.LANCZOS)),
         ("Tripo판 앞", Image.open(a.tripo + "/front.png").convert("RGB").resize((560, 560), Image.LANCZOS)),
         ("골격판 앞", Image.open(a.skel + "/front.png").convert("RGB").resize((560, 560), Image.LANCZOS)),
         ("골격판 3/4", Image.open(a.skel + "/q34.png").convert("RGB").resize((560, 560), Image.LANCZOS)),
         ("골격판 뒤", Image.open(a.skel + "/back.png").convert("RGB").resize((560, 560), Image.LANCZOS))]
rows.append(("전체 (같은 카메라·같은 빛)", views))
for label, box, sbox, box2d in CROPS:
    t = render_crop(a.tripo + "/front.png", box)
    s = render_crop(a.skel + "/front.png", sbox)
    rows.append(("100%% 크롭 — %s" % label, [("2D (같은 높이로 확대)", crop2d(box2d, t.size)), ("Tripo판", t), ("골격판", s)]))
close = [(n, Image.open(a.skel + "/%s.png" % f).convert("RGB").resize((560, 560), Image.LANCZOS))
         for n, f in (("골격판 문 가까이", "close_door"), ("골격판 창 가까이", "close_window"), ("골격판 바닥·화단 가까이", "close_base"))]
close += [(n, Image.open(a.tripo + "/%s.png" % f).convert("RGB").resize((560, 560), Image.LANCZOS))
          for n, f in (("Tripo판 문 가까이", "close_door"), ("Tripo판 창 가까이", "close_window"))]
rows.append(("가까이 (원근)", close))


def spec_rows(specs, h=330):
    out = []
    for spec in specs:
        title, items = spec.split("|", 1)
        row = []
        for it in items.split(";"):
            lab, path = it.split("=", 1)
            im = Image.open(path).convert("RGB")
            row.append((lab, im.resize((int(im.width * h / im.height), h), Image.LANCZOS)))
        out.append((title, row))
    return out


rows = spec_rows(a.first, 520) + rows + spec_rows(a.studio)

GAP, HEAD, CAP = 12, 40, 30
W = max(sum(im.width for _, im in items) + GAP * (len(items) + 1) for _, items in rows)
H = 60 + (30 if a.note else 0) + sum(HEAD + CAP + max(im.height for _, im in items) + GAP for _, items in rows)
sheet = Image.new("RGB", (W, H), (24, 24, 28))
d = ImageDraw.Draw(sheet)
d.text((GAP, 12), a.title, fill=(255, 255, 255), font=FONT)
y = 50
if a.note:
    d.text((GAP, y), a.note, fill=(220, 220, 160), font=FONT_S)
    y += 30
for head, items in rows:
    d.text((GAP, y + 8), head, fill=(255, 210, 120), font=FONT)
    y += HEAD
    x = GAP
    for cap, im in items:
        d.text((x, y), cap, fill=(230, 230, 230), font=FONT_S)
        sheet.paste(im, (x, y + CAP))
        x += im.width + GAP
    y += CAP + max(im.height for _, im in items) + GAP
sheet.save(a.out, quality=90)
print("[sheet]", a.out, sheet.size)
