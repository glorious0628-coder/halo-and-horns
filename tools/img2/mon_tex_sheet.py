"""Review sheet for the monster texture fix (A23-73 ④ + AO): per fixed monster two rows
  top:    concept | now (concept angle) | fixed (concept angle) | now (game camera) | fixed (game camera) | fixed back 3/4
          [| in-game photo]
  bottom: 100% crops (render pixels, no scaling) of one detail box: concept | now | fixed
then one small row with the monsters left as they are (concept | now).

  py tools/img2/mon_tex_sheet.py <out.jpg> <spec.json>

spec.json = {"title": "...", "subtitle": "...", "subtitle2": "...", "hue": {"Slime": [65, 100], ...},
             "fixed": [{"kind": "Slime", "label": "v0h0.80", "name": "...", "note": "...", "crop": [x0, y0, x1, y1],
                        "photo": ["art/review/pc_check/x.jpg", x0, y0, x1, y1],
                        "frame_kind": "Slime", "concept_crop": [x0, y0, x1, y1]}, ...],   (last two optional)
             "kept": [{"kind": "LittleGhost", "name": "...", "note": "..."}, ...]}
crop = a box in concept pixels (the match render is moved onto the concept frame first, like mon_tex_view.py).
"""
import json
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/glori/Documents/Roblox/Game/"
sys.path.insert(0, ROOT + "tools/img2")
from mon_tex import M  # noqa: E402

OUT, SPEC = sys.argv[1], json.load(open(sys.argv[2], encoding="utf-8"))
F = lambda s, b=False: ImageFont.truetype("C:/Windows/Fonts/malgunbd.ttf" if b else "C:/Windows/Fonts/malgun.ttf", s)
NAVY, BG = (24, 30, 64), (250, 245, 236)
CELL = 330


def concept_of(kind):
    return Image.open(ROOT + M[kind][1]).convert("RGB")


def on_grey(im, grey):
    bg = Image.new("RGBA", im.size, grey + (255,))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def aligned(kind, label, view, frame):
    """render on the concept's grey; match = moved onto the concept frame (cam.json), game = as rendered"""
    W = ROOT + f"build/montex/{kind}/"
    grey = frame.getpixel((6, 6))
    r = Image.open(W + f"r/{label}_{view}.png").convert("RGBA")
    if view != "match":
        return on_grey(r, grey)
    cam = json.load(open(W + "cam.json"))
    sc = cam["scale"]
    r = r.resize((round(r.width * sc), round(r.height * sc)), Image.LANCZOS)
    bg = Image.new("RGBA", frame.size, grey + (255,))
    tmp = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    tmp.paste(r, (round(cam["dx"]), round(cam["dy"])), r)
    bg.alpha_composite(tmp)
    return bg.convert("RGB")


def fit(im, w, h, grey):
    """crop to the object (non-grey) with a margin, then fit into w x h"""
    a = np.asarray(im).astype(int)
    m = np.abs(a - np.array(grey)).max(-1) > 14
    if m.any():
        ys, xs = np.where(m)
        pad = 12
        im = im.crop((max(0, xs.min() - pad), max(0, ys.min() - pad), min(im.width, xs.max() + pad), min(im.height, ys.max() + pad)))
    im = im.copy()
    im.thumbnail((w, h), Image.LANCZOS)
    t = Image.new("RGB", (w, h), grey)
    t.paste(im, ((w - im.width) // 2, (h - im.height) // 2))
    return t


def body_txt(im, kind):
    """median body colour (the dominant saturated hue of the concept) - a hint only"""
    a = np.asarray(im.convert("RGB"))
    hsv = cv2.cvtColor(a, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    h, s, v = hsv[..., 0] / 255 * 360, hsv[..., 1] / 255, hsv[..., 2] / 255
    win = SPEC.get("hue", {}).get(kind)
    if not win:
        return ""
    lo, hi = win
    m = (h > lo) & (h < hi) & (s > 0.35)
    if m.sum() < 50:
        return ""
    rgb = tuple(int(x) for x in np.median(a[m], 0))
    return f"몸 {rgb} 밝기 {np.median(v[m]):.2f}"


rows = []
for f in SPEC["fixed"]:
    k, lab = f["kind"], f["label"]
    con = concept_of(k)
    frame = concept_of(f.get("frame_kind", k))  # BigSlime: the cube camera belongs to the Slime concept frame
    grey = con.getpixel((6, 6))
    top = [("시안", con), ("지금 · 시안 각도", aligned(k, "now", "match", frame)), ("고친 판 · 시안 각도", aligned(k, lab, "match", frame)),
           ("지금 · 게임 카메라", aligned(k, "now", "game", frame)), ("고친 판 · 게임 카메라", aligned(k, lab, "game", frame)),
           ("고친 판 · 뒤 3/4", aligned(k, lab, "back34", frame))]
    if f.get("photo"):
        p = f["photo"]
        top.append(("실제 게임 사진(지금)", Image.open(ROOT + p[0]).convert("RGB").crop(tuple(p[1:5]))))
    x0, y0, x1, y1 = f["crop"]
    cc = f.get("concept_crop", f["crop"])
    crops = [("시안 100%", con.crop(tuple(cc))), ("지금 100%", aligned(k, "now", "match", frame).crop((x0, y0, x1, y1))),
             ("고친 판 100%", aligned(k, lab, "match", frame).crop((x0, y0, x1, y1)))]
    rows.append((f, top, crops, grey))

kept = SPEC.get("kept", [])
cw, ch = CELL, CELL
crop_h = max((max(c[1].height for c in r[2]) for r in rows), default=0)
W = 30 + 7 * (cw + 10)
H = 120 + sum(36 + ch + 28 + crop_h + 64 for _ in rows) + (60 + 210 if kept else 0)
s = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(s)
d.text((30, 14), SPEC["title"], font=F(28, True), fill=NAVY)
d.text((30, 58), SPEC.get("subtitle", ""), font=F(15), fill=(90, 90, 90))
d.text((30, 82), SPEC.get("subtitle2", ""), font=F(15), fill=(90, 90, 90))
y = 118
for f, top, crops, grey in rows:
    d.text((30, y), f["name"], font=F(20, True), fill=NAVY)
    d.text((30 + 420, y + 3), f.get("note", ""), font=F(15), fill=(70, 70, 70))
    y += 36
    for j, (cap, im) in enumerate(top):
        x = 30 + j * (cw + 10)
        if j < 6:
            cell = fit(im, cw, ch, grey)
        else:  # the in-game photo crop: scaled to the cell width, top part
            cell = im.resize((cw, round(cw * im.height / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
        s.paste(cell, (x, y))
        fixed = j in (2, 4)
        d.text((x + 2, y + ch + 2), cap + ("   " + body_txt(im, f["kind"]) if j < 5 else ""), font=F(13, fixed), fill=(170, 40, 40) if fixed else NAVY)
    y += ch + 28
    x = 30
    for cap, im in crops:
        s.paste(im, (x, y))
        d.text((x + 2, y + im.height + 2), cap, font=F(13, cap.startswith("고친")), fill=(170, 40, 40) if cap.startswith("고친") else NAVY)
        x += im.width + 10
    y += crop_h + 64
if kept:
    d.text((30, y), SPEC.get("kept_title", "그대로 둠"), font=F(20, True), fill=NAVY)
    y += 36
    x = 30
    for kp in kept:
        con = concept_of(kp["kind"])
        grey = con.getpixel((6, 6))
        a = fit(con, 150, 150, grey)
        b = fit(aligned(kp["kind"], "now", "match", con), 150, 150, grey)
        s.paste(a, (x, y))
        s.paste(b, (x + 154, y))
        d.text((x, y + 152), kp["name"] + " · " + kp.get("note", ""), font=F(13), fill=NAVY)
        x += 154 * 2 + 24
s.save(OUT, quality=92)
print(OUT, s.size)
