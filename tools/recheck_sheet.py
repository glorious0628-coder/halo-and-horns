"""3D re-check sheets (SPEC A23-122, 2026-10-11): one comparison sheet per model from tools/recheck_render_blender.py.

  py tools/recheck_sheet.py <items.json> <outdir> [--only Name1,Name2]

<items.json>: docs/review/3d_recheck_2026-10-11_items.json (key "render") or a plain list.
<outdir>:     the render folder (art/review/recheck_2026-10-11): reads <outdir>/<safe name>/{front,right,back,left,q34,
              detail}.png + front_mask.png + meta.json, writes <outdir>/sheets/<safe name>.jpg (quality 90) and
              <outdir>/index.json = [{name, zone, inputs, sheet, status, note}].
Sheet (judge with docs/design/3d_quality_check_2026-10-10.md):
  header  name, zone, kind, inputs/views, tris, used_in, files, front axis + why, materials/textures
  row 1   2D source (fit to 900 tall) | front | 3/4 (front-right, 20 deg up)
  row 2   right | back | left   (labels carry the Blender axis each view looks at)
  row 3   detail (2x render of the busiest region) | 100 % crop of the front render: most inner edges | centre
          (crops are 450 native px shown 2x with nearest-neighbour; their boxes are outlined on the front panel)
Missing inputs get a gray panel that says what is missing.
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

argv = sys.argv[1:]
ITEMS, OUT = argv[0], argv[1]
ONLY = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else set()
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = 900          # panel size
CROP = 450       # native crop size (shown 2x)
HEAD = 190
GAP = 6
BGC = (40, 42, 46)
PANEL_BG = (140, 140, 140)
COL = {"detail": (0, 220, 255), "edge": (255, 60, 200), "centre": (255, 220, 0)}
VIEW_TXT = {"front": "front", "right": "right (viewer's right)", "back": "back", "left": "left", "q34": "3/4 front-right, 20 deg up"}


def font(sz, bold=False):
    for f in (("arialbd.ttf" if bold else "arial.ttf"), "segoeui.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", f), sz)
        except OSError:
            continue
    return ImageFont.load_default()


F_T, F_H, F_L = font(40, True), font(22), font(24, True)


def safe_name(n):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", n).strip("_")


def resolve(p):
    if not p or p in ("unknown", "None"):
        return None
    for base in (os.getcwd(), ROOT):
        q = p if os.path.isabs(p) else os.path.join(base, p)
        if os.path.exists(q):
            return q
    return None


def missing_panel(w, h, text):
    im = Image.new("RGB", (w, h), (95, 95, 100))
    d = ImageDraw.Draw(im)
    for i in range(-h, w, 60):
        d.line([(i, h), (i + h, 0)], fill=(105, 105, 110), width=14)
    tw = d.textlength(text, font=F_L)
    d.rectangle([w / 2 - tw / 2 - 16, h / 2 - 26, w / 2 + tw / 2 + 16, h / 2 + 26], fill=(30, 30, 30))
    d.text((w / 2 - tw / 2, h / 2 - 15), text, font=F_L, fill=(255, 120, 90))
    return im


def label(im, text, color=(255, 255, 255)):
    d = ImageDraw.Draw(im)
    tw = d.textlength(text, font=F_L)
    d.rectangle([0, 0, tw + 20, 38], fill=(0, 0, 0))
    d.text((10, 6), text, font=F_L, fill=color)
    return im


def edges(a, mask):
    lum = a.astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32) / 255.0
    gy = np.abs(np.diff(lum, axis=0, prepend=lum[:1]))
    gx = np.abs(np.diff(lum, axis=1, prepend=lum[:, :1]))
    m = mask.copy()
    for dy in (-4, -2, 0, 2, 4):
        for dx in (-4, -2, 0, 2, 4):
            m &= np.roll(np.roll(mask, dy, 0), dx, 1)
    return (gx + gy) * m


def best_window(g, win, avoid=None, step=15, mask=None, min_cover=0.0):
    h, w = g.shape
    ii = np.zeros((h + 1, w + 1), dtype=np.float64)
    ii[1:, 1:] = g.cumsum(0).cumsum(1)
    mi = None
    if mask is not None and min_cover > 0:
        mi = np.zeros((h + 1, w + 1), dtype=np.float64)
        mi[1:, 1:] = mask.astype(np.float64).cumsum(0).cumsum(1)
    best, bxy = -1.0, None
    for y in range(0, h - win + 1, step):
        for x in range(0, w - win + 1, step):
            if mi is not None and (mi[y + win, x + win] - mi[y, x + win] - mi[y + win, x] + mi[y, x]) < \
                    min_cover * win * win:
                continue
            if avoid is not None:
                ax, ay, aw, ah = avoid
                ox = max(0, min(x + win, ax + aw) - max(x, ax))
                oy = max(0, min(y + win, ay + ah) - max(y, ay))
                if ox * oy > 0.25 * win * win:
                    continue
            s = ii[y + win, x + win] - ii[y, x + win] - ii[y + win, x] + ii[y, x]
            if s > best:
                best, bxy = s, (x, y)
    return bxy


def make_sheet(item, outdir, sheets_dir):
    name = item["name"]
    sname = safe_name(name)
    rdir = os.path.join(outdir, sname)
    meta = {}
    mp = os.path.join(rdir, "meta.json")
    if os.path.exists(mp):
        meta = json.load(open(mp, encoding="utf-8"))
    rstatus = meta.get("status", "not_rendered")
    have = {v: os.path.join(rdir, v + ".png") for v in ("front", "right", "back", "left", "q34", "detail")}
    have = {v: p for v, p in have.items() if os.path.exists(p)} if rstatus == "ok" else {}
    if rstatus == "no_glb" or not resolve(item.get("glb")):
        why_r = "NO GLB (%s)" % (item.get("glb") or "none recorded")
        rstatus = "no_glb"
    elif rstatus == "fail":
        why_r = "RENDER FAILED (see render_log.txt)"
    else:
        why_r = "NOT RENDERED"
    vax = meta.get("view_axes", {})

    def view(v, txt=None):
        if v not in have:
            return missing_panel(P, P, why_r)
        im = Image.open(have[v]).convert("RGB")
        if im.size != (P, P):
            im = im.resize((P, P), Image.LANCZOS)
        ax = vax.get(v)
        return label(im, (txt or VIEW_TXT.get(v, v)) + (" [faces %s]" % ax if ax else ""))

    # 2D source
    p2 = resolve(item.get("image_2d"))
    if p2:
        s = Image.open(p2)
        if s.mode in ("RGBA", "LA", "P"):
            s = s.convert("RGBA")
            bg = Image.new("RGBA", s.size, PANEL_BG + (255,))
            s = Image.alpha_composite(bg, s)
        s = s.convert("RGB")
        w2 = max(1, round(s.width * P / s.height))
        if w2 > int(P * 1.6):  # very wide: fit width instead, pad height
            s2 = s.resize((int(P * 1.6), max(1, round(s.height * P * 1.6 / s.width))), Image.LANCZOS)
            src = Image.new("RGB", (s2.width, P), PANEL_BG)
            src.paste(s2, (0, (P - s2.height) // 2))
        else:
            src = s.resize((w2, P), Image.LANCZOS)
        if src.width < P:
            pad = Image.new("RGB", (P, P), PANEL_BG)
            pad.paste(src, ((P - src.width) // 2, 0))
            src = pad
        label(src, "2D source (%s)" % item.get("inputs", "?"))
    else:
        src = missing_panel(P, P, "NO 2D SOURCE (%s)" % (item.get("image_2d") or "none recorded"))
        label(src, "2D source")

    front = view("front")
    q34 = view("q34")
    right, back, left = view("right"), view("back"), view("left")
    detail = view("detail", "detail 2x render (%s)" % meta.get("detail_how", "?")) if "detail" in have else \
        missing_panel(P, P, why_r)
    crop_e = crop_c = None
    if "front" in have:
        fa = np.asarray(Image.open(have["front"]).convert("RGB"))
        mpath = os.path.join(rdir, "front_mask.png")
        if os.path.exists(mpath):
            mask = np.asarray(Image.open(mpath).convert("L")) > 127
        else:
            mask = np.abs(fa.astype(int) - 140).sum(axis=2) > 12
        g = edges(fa, mask)
        dw = meta.get("detail_window_px")
        ex = best_window(g, CROP, avoid=dw, mask=mask, min_cover=0.5) or best_window(g, CROP, mask=mask, min_cover=0.5) \
            or best_window(g, CROP, avoid=dw) or best_window(g, CROP) or ((P - CROP) // 2, (P - CROP) // 2)
        ys, xs = np.nonzero(mask)
        if len(xs):
            cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
        else:
            cx = cy = P // 2
        cxy = (int(min(max(cx - CROP // 2, 0), P - CROP)), int(min(max(cy - CROP // 2, 0), P - CROP)))
        src_front = Image.open(have["front"]).convert("RGB")
        crop_e = src_front.crop((ex[0], ex[1], ex[0] + CROP, ex[1] + CROP)).resize((P, P), Image.NEAREST)
        crop_c = src_front.crop((cxy[0], cxy[1], cxy[0] + CROP, cxy[1] + CROP)).resize((P, P), Image.NEAREST)
        label(crop_e, "100%% crop front: most edges (%dpx native, shown 2x)" % CROP, COL["edge"])
        label(crop_c, "100%% crop front: centre (%dpx native, shown 2x)" % CROP, COL["centre"])
        # outline the regions on the front panel
        d = ImageDraw.Draw(front)
        if dw:
            d.rectangle([dw[0], dw[1], dw[0] + dw[2], dw[1] + dw[3]], outline=COL["detail"], width=3)
        d.rectangle([ex[0], ex[1], ex[0] + CROP, ex[1] + CROP], outline=COL["edge"], width=3)
        d.rectangle([cxy[0], cxy[1], cxy[0] + CROP, cxy[1] + CROP], outline=COL["centre"], width=3)
        if "detail" in have:
            label(detail, "detail 2x render (%s)" % meta.get("detail_how", "?"), COL["detail"])
    if crop_e is None:
        crop_e = missing_panel(P, P, why_r)
        crop_c = missing_panel(P, P, why_r)

    rows = [[src, front, q34], [right, back, left], [detail, crop_e, crop_c]]
    W = max(sum(im.width for im in r) + GAP * (len(r) - 1) for r in rows)
    H = HEAD + sum(P for _ in rows) + GAP * len(rows)
    sheet = Image.new("RGB", (W, H), BGC)
    y = HEAD
    for r in rows:
        x = 0
        for im in r:
            sheet.paste(im, (x, y))
            x += im.width + GAP
        y += P + GAP
    # header
    d = ImageDraw.Draw(sheet)
    status = "ok" if rstatus == "ok" else rstatus
    if rstatus == "ok" and not p2:
        status = "ok_no_2d"
    st_col = (120, 230, 120) if status == "ok" else (255, 190, 80) if status == "ok_no_2d" else (255, 110, 90)
    d.text((16, 10), name, font=F_T, fill=(255, 255, 255))
    tx = 16 + d.textlength(name, font=F_T) + 30
    d.text((tx, 22), "zone %s | kind %s | inputs %s (%s) | status %s" % (
        item.get("zone"), item.get("kind"), item.get("inputs"), item.get("views", "?"), status), font=F_H, fill=st_col)
    tris_r = meta.get("tris_render")
    lines = [
        "tris %s (render count %s) | objects %s | materials %s | textures %s | size xyz %s" % (
            item.get("tris"), tris_r, meta.get("objects"), meta.get("materials"),
            ",".join(meta.get("images", [])) or "-", meta.get("size_xyz")),
        "used_in: %s" % ", ".join(item.get("used_in") or []) or "-",
        "glb: %s   |   2D: %s" % (item.get("glb") or "-", item.get("image_2d") or "-"),
        "front axis %s%s - %s" % (meta.get("front_axis", "-"),
                                  "  (UNCERTAIN: check all 4 sides)" if meta.get("front_uncertain") else "",
                                  meta.get("front_rule", "-")),
        "2D match per side (silhouette+colour, 1 = same): " + "  ".join(
            "%s %.2f" % (k, v["score"]) for k, v in sorted(meta.get("match", {}).items())) if meta.get("match") else
        "2D match: -",
    ]
    for i, ln in enumerate(lines):
        d.text((16, 62 + i * 25), ln[:260], font=F_H, fill=(215, 215, 220))
    os.makedirs(sheets_dir, exist_ok=True)
    out = os.path.join(sheets_dir, sname + ".jpg")
    sheet.save(out, quality=90)
    note = []
    if meta.get("front_axis"):
        note.append("front %s%s (%s)" % (meta["front_axis"], ", uncertain" if meta.get("front_uncertain") else "",
                                         meta.get("front_rule", "")))
    if not p2:
        note.append("no 2D source (%s)" % (item.get("image_2d") or "none recorded"))
    if rstatus != "ok":
        note.append(why_r)
        if meta.get("error"):
            note.append(meta["error"].strip().splitlines()[-1])
    return {"name": name, "zone": item.get("zone"), "inputs": item.get("inputs"),
            "sheet": os.path.relpath(out, ROOT).replace("\\", "/"), "status": status, "note": "; ".join(note)}


def main():
    data = json.load(open(ITEMS, encoding="utf-8"))
    items = data["render"] if isinstance(data, dict) else data
    if ONLY:
        items = [i for i in items if i["name"] in ONLY or safe_name(i["name"]) in ONLY]
    outdir = os.path.abspath(OUT)
    sheets = os.path.join(outdir, "sheets")
    index = []
    for it in items:
        try:
            index.append(make_sheet(it, outdir, sheets))
        except Exception as e:  # keep going, record the failure
            index.append({"name": it["name"], "zone": it.get("zone"), "inputs": it.get("inputs"), "sheet": None,
                          "status": "sheet_fail", "note": "%s: %s" % (type(e).__name__, e)})
        print("[sheet] %-10s %s" % (index[-1]["status"], it["name"]), flush=True)
    if not ONLY:
        json.dump(index, open(os.path.join(outdir, "index.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    from collections import Counter
    print("[sheet] done", dict(Counter(i["status"] for i in index)), flush=True)


main()
