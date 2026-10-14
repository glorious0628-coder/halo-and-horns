"""Sheet for 최종 검수 PBR final gate (renders from final_gate.py).
row 1: 2D front | _left | _right | back  + stats text
row 2: albedo (Workbench flat = colour map as painted) f | l | r | b | top
row 3: studio light (shape) f | l | r | b  + EEVEE fixed-sun q34
row 4: three 100% crops from albedo f (2048) + 2D-vs-albedo silhouette overlay (front)
Silhouette numbers per view: aspect h/w of 2D vs render and IoU after fitting both to one box (hints only, judge by eye).
py tools/final_review/final_gate_sheet.py <render_dir> <out_dir> <name> ...   (2D found under art/out/s2/noshadow/**)
Writes <out_dir>/<name>_final.jpg and <out_dir>/metrics.json (merged).
"""
import glob
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

rd, od = sys.argv[1], sys.argv[2]
os.makedirs(od, exist_ok=True)
C, CR, HDR = 340, 560, 22
BG = (200, 200, 205)
ALIAS = {"HaloChunk_GateLeaf": "HaloChunk_CastleGateLeaf"}


def find2d(name, view):
    n = ALIAS.get(name, name)
    fs = glob.glob(f"art/out/s2/noshadow/**/{n}_{view}_ns.png", recursive=True)
    return fs[0] if fs else None


def mask2d(im):
    """object mask of a flat-grey-background 2D: flood fill from the border with tolerance."""
    sm = im.convert("RGB").resize((256, 256))
    w, h = sm.size
    marker = (255, 0, 255)
    f = sm.copy()
    for x in range(0, w, 16):
        for y in (0, h - 1):
            if f.getpixel((x, y)) != marker:
                ImageDraw.floodfill(f, (x, y), marker, thresh=26)
    for y in range(0, h, 16):
        for x in (0, w - 1):
            if f.getpixel((x, y)) != marker:
                ImageDraw.floodfill(f, (x, y), marker, thresh=26)
    m = Image.new("L", (w, h), 0)
    px, mp = f.load(), m.load()
    for y in range(h):
        for x in range(w):
            if px[x, y] != marker:
                mp[x, y] = 255
    return m.filter(ImageFilter.MedianFilter(5))


def mask_render(im):
    return im.getchannel("A").resize((256, 256)).point(lambda v: 255 if v > 127 else 0)


def fit(m):
    bb = m.getbbox()
    if not bb:
        return None, 0
    c = m.crop(bb)
    asp = c.height / max(1, c.width)
    return c.resize((128, 128)), asp


def iou(a, b):
    if a is None or b is None:
        return 0
    inter = ImageChops.multiply(a, b).histogram()[255]
    uni = ImageChops.lighter(a, b).histogram()[255]
    return inter / max(1, uni)


def on_bg(im):
    im = im.convert("RGBA")
    bg = Image.new("RGBA", im.size, BG + (255,))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def crops(big, n=3):
    """pick n most detailed 560 px windows (edge energy) inside the object."""
    g = big.convert("L").filter(ImageFilter.FIND_EDGES)
    a = big.getchannel("A")
    W, H = big.size
    cand = []
    step = CR // 2
    for y in range(0, H - CR + 1, step):
        for x in range(0, W - CR + 1, step):
            cov = sum(a.crop((x, y, x + CR, y + CR)).resize((16, 16)).getdata()) / (256 * 255)
            if cov < 0.55:
                continue
            e = sum(g.crop((x, y, x + CR, y + CR)).resize((32, 32)).getdata())
            cand.append((e, x, y))
    cand.sort(reverse=True)
    out = []
    for e, x, y in cand:
        if all(abs(x - ox) >= CR or abs(y - oy) >= CR for ox, oy in out):
            out.append((x, y))
        if len(out) == n:
            break
    return [on_bg(big.crop((x, y, x + CR, y + CR))) for x, y in out]


allm = {}
mp = os.path.join(od, "metrics.json")
if os.path.exists(mp):
    allm = json.load(open(mp, encoding="utf-8"))
for name in sys.argv[3:]:
    st = {}
    sp = os.path.join(rd, f"{name}__stats.json")
    if os.path.exists(sp):
        st = json.load(open(sp, encoding="utf-8"))
    W = 3 * (CR + 4) + (CR - 140) + 10
    o = Image.new("RGB", (W, HDR * 4 + C * 3 + CR), (28, 28, 30))
    dr = ImageDraw.Draw(o)
    met = {"views": {}}
    # row 1: 2D
    dr.text((4, 4), f"{name}   2D: front | _left | _right | back", fill=(255, 220, 0))
    m2 = {}
    for k, (v2, vr) in enumerate((("front", "f"), ("left", "l"), ("right", "r"), ("back", "b"))):
        p = find2d(name, v2)
        if p:
            im = Image.open(p).convert("RGB")
            o.paste(im.resize((C, C)), (k * C, HDR))
            m2[vr] = mask2d(im)
    # stats text
    tx = 4 * C + 6
    lines = [f"tris {st.get('tris')}", f"size {st.get('size_xyz')}", f"pivot xy {st.get('pivot_offset_xy')} minz {st.get('min_z')}",
             f"meshes {st.get('meshes')} mats {st.get('materials')}", f"dark(<6%) {st.get('base_dark_frac')}"]
    for im_ in st.get("images", []):
        lines.append(f"{im_[0][-22:]} {im_[1]}")
    # row 2: albedo
    y2 = HDR * 2 + C
    dr.text((4, y2 - HDR + 4), "ALBEDO (colour map as painted, flat): f | l | r | b | top", fill=(255, 220, 0))
    for k, v in enumerate(("f", "l", "r", "b", "top")):
        p = os.path.join(rd, f"{name}__albedo_{v}.png")
        if os.path.exists(p):
            im = Image.open(p)
            o.paste(on_bg(im).resize((C, C)), (k * C, y2))
            if v in m2:
                a2, asp2 = fit(m2[v])
                ar, aspr = fit(mask_render(im))
                met["views"][v] = {"asp2d": round(asp2, 3), "asp3d": round(aspr, 3), "asp_ratio": round(aspr / max(1e-6, asp2), 3), "iou": round(iou(a2, ar), 3)}
    for v, d in met["views"].items():
        lines.append(f"{v}: asp 2D {d['asp2d']} 3D {d['asp3d']} (x{d['asp_ratio']}) IoU {d['iou']}")
    for i, s in enumerate(lines):
        dr.text((tx, HDR + 6 + i * 14), s, fill=(255, 255, 255))
    # row 3: studio + lit
    y3 = y2 + C + HDR
    dr.text((4, y3 - HDR + 4), "STUDIO light (shape): f | l | r | b   |  EEVEE fixed sun q34 (PBR)", fill=(255, 220, 0))
    for k, v in enumerate(("studio_f", "studio_l", "studio_r", "studio_b", "lit_q34")):
        p = os.path.join(rd, f"{name}__{v}.png")
        if os.path.exists(p):
            o.paste(on_bg(Image.open(p)).resize((C, C)), (k * C, y3))
    # row 4: crops + silhouette overlay
    y4 = y3 + C + HDR
    dr.text((4, y4 - HDR + 4), "100% crops of albedo f (2048)  |  silhouette front: 2D red, 3D cyan (fitted to box)", fill=(255, 220, 0))
    p = os.path.join(rd, f"{name}__albedo_fbig.png")
    if os.path.exists(p):
        big = Image.open(p).convert("RGBA")
        for k, c in enumerate(crops(big)):
            o.paste(c, (k * (CR + 4), y4))
        fa = os.path.join(rd, f"{name}__albedo_f.png")
        if "f" in m2 and os.path.exists(fa):
            a2, _ = fit(m2["f"])
            ar, _ = fit(mask_render(Image.open(fa)))
            if a2 is not None and ar is not None:
                ov = Image.merge("RGB", (a2, ar, ar)).resize((CR - 140, CR - 140), Image.NEAREST)
                o.paste(ov, (3 * (CR + 4), y4 + 20))
    met["stats"] = st
    allm[name] = met
    o.save(os.path.join(od, f"{name}_final.jpg"), quality=88)
    print("sheet", name, {v: (d["asp_ratio"], d["iou"]) for v, d in met["views"].items()})
json.dump(allm, open(mp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
