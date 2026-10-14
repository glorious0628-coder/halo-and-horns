"""Sheet for the PBR gate: row 1 = 2D 4 views (+ label), row 2 = lit renders f/fr/b/fl/q34 (pbr_gate.py),
row 2b = straight top | bottom, row 3 = three 100% crops (600 px) from the 2048 front render (the 3 most detailed spots).
py tools/design_review/pbr_gate_sheet.py <render_dir> <out_dir> <render_label>=<2d_prefix> ...
2d_prefix = path without _front_ns.png (e.g. art/out/s2/noshadow/chunks/HaloChunk_DoorSingle).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

rd, od = sys.argv[1], sys.argv[2]
os.makedirs(od, exist_ok=True)
C, CR, HDR = 360, 600, 22
for spec in sys.argv[3:]:
    lab, pre = spec.split("=", 1)
    W = C * 5
    o = Image.new("RGB", (W, HDR * 4 + C * 3 + CR), (28, 28, 30))
    dr = ImageDraw.Draw(o)
    # row 1: 2D (front, _left = front to image right, back, _right = front to image left)
    dr.text((4, 4), f"{os.path.basename(pre)}  2D: front | _left | back | _right", fill=(255, 220, 0))
    for k, s in enumerate(("front", "left", "back", "right")):
        p = f"{pre}_{s}_ns.png"
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            bgc = Image.new("RGBA", im.size, (200, 200, 205, 255))
            bgc.alpha_composite(im)
            o.paste(bgc.convert("RGB").resize((C, C)), (k * C, HDR))
    dr.text((4 * C + 6, HDR + 6), lab, fill=(255, 255, 255))
    # row 2: renders
    y2 = HDR * 2 + C
    dr.text((4, y2 - HDR + 4), "Tripo PBR (sun+sky): f | fr | b | fl | q34", fill=(255, 220, 0))
    for k, v in enumerate(("f", "fr", "b", "fl", "q34")):
        p = os.path.join(rd, f"{lab}__{v}.png")
        if os.path.exists(p):
            o.paste(Image.open(p).convert("RGB").resize((C, C)), (k * C, y2))
    # row 2b: straight top and underside (user 10/13: check all six sides)
    y2b = y2 + C + HDR
    dr.text((4, y2b - HDR + 4), "top | bottom (straight)", fill=(255, 220, 0))
    for k, v in enumerate(("top", "bot")):
        p = os.path.join(rd, f"{lab}__{v}.png")
        if os.path.exists(p):
            o.paste(Image.open(p).convert("RGB").resize((C, C)), (k * C, y2b))
    # row 3: 100% crops from f_big
    y3 = y2b + C + HDR
    dr.text((4, y3 - HDR + 4), "100% crops of f (2048): 3 most detailed spots", fill=(255, 220, 0))
    p = os.path.join(rd, f"{lab}__f_big.png")
    if os.path.exists(p):
        big = Image.open(p).convert("RGB")
        # pick the 3 most detailed 600 px windows (edge energy), not overlapping much
        G = 32
        e = big.convert("L").filter(ImageFilter.FIND_EDGES).resize((big.width // G, big.height // G), Image.BOX)
        ew, eh = e.size
        ev = list(e.getdata())
        n = CR // G
        cand = []
        for gy in range(0, eh - n + 1):
            for gx in range(0, ew - n + 1):
                s = sum(ev[(gy + j) * ew + gx + i] for j in range(0, n, 2) for i in range(0, n, 2))
                cand.append((s, gx, gy))
        cand.sort(reverse=True)
        picks = []
        for s, gx, gy in cand:
            if all(abs(gx - px_) >= n or abs(gy - py_) >= n for px_, py_ in picks):  # no overlap
                picks.append((gx, gy))
            if len(picks) == 3:
                break
        picks.sort(key=lambda t: (t[1], t[0]))
        for k, (gx, gy) in enumerate(picks):
            x0, y0 = gx * G, gy * G
            o.paste(big.crop((x0, y0, x0 + CR, y0 + CR)), (k * CR, y3))
        for k in (1, 2):  # dark gap so neighbouring crops never read as one picture with a seam
            dr.rectangle((k * CR - 4, y3, k * CR + 3, y3 + CR), fill=(28, 28, 30))
    o.save(os.path.join(od, f"{lab}.jpg"), quality=90)
    print("SHEET", lab)
