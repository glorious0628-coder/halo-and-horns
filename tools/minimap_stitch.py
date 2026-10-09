"""Stitch the top-down minimap tiles into a world mosaic and cut it into upload chunks (이미지 개발, A23-95, 2026-10-10).

tools/minimap_capture.py (메인 반영 1, main Studio Edit) shoots art/minimap/<set>/tile_*.png + tiles.json. This tool, offline
(no Studio, no network), keeps ONE world mosaic and cuts it into <= 1024 px chunks on a fixed grid, so a zone shot again
only replaces the chunks it touches:

  py tools/minimap_stitch.py add <set> [<set> ...]   paste the sets' tiles into the mosaic (newer over older), re-cut the
                                                     chunks they touch, write the seam sheet
  py tools/minimap_stitch.py ids KEY=rbxassetid://N [KEY=...]   record uploaded chunk ids (KEY like 'c3_1')
  py tools/minimap_stitch.py config                  print the Config.UIArt.MapTiles lines (chunks with ids) + what waits
  py tools/minimap_stitch.py sheet                   the seam sheet again
  py tools/minimap_stitch.py status                  chunks, coverage, ids, which need an upload
Options: --world DIR (default art/minimap/world), and for the first 'add' only: --res PX_PER_STUD (2.5),
--bounds X0 X1 Z0 Z1 (-614.4 1843.2 -1024 1024), --chunk PX (1024).

World mosaic: DIR/mosaic.png (RGBA, 8 bit; alpha = how much is covered by a shot; the drawn map shows through where it is 0),
DIR/world.json { res, bounds, chunkPx, chunkStuds, sets: [...], chunks: { KEY: { col, row, X0, X1, Z0, Z1, file, sha,
coverage, Id, OldId } } }. Axes as minimap_capture: image right = +X (east), image top = Z0 (north); a chunk covers
X0..X1, Z0..Z1 in studs (the MapTiles entry; MiniMap / WorldMap stretch the image over that box).
Blending: every tile's weight ramps 0 -> 1 across its overlap band (minimap_capture's overlapStuds) on each side, as a
product of the x and z ramps, so neighbours cross-fade (the weights add up to 1 inside the set) and the set's outer rim
fades into what was there before. A chunk whose pixels changed loses its Id (kept as OldId) until the new upload.
Seam sheet: art/review/minimap_stitch_<last set>.jpg - the mosaic small with the chunk grid (gold) and the last set's tile
edges (cyan), and the seams between neighbouring tiles of the last set at native size x2.
"""

import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# the grid (1024 px = 409.6 studs) puts the Crossroads in the middle of one chunk; it covers every zone in Config.Zones
# (Outskirts X -260..1840, the towns Z -700..700)
DEFAULTS = {"res": 2.5, "bounds": [-614.4, 1843.2, -1024.0, 1024.0], "chunkPx": 1024}
EMPTY = 0.005  # a chunk covered less than this (mean alpha) is not kept


def arg(args, name, n=1, cast=float):
    if name not in args:
        return None
    i = args.index(name)
    vals = [cast(v) for v in args[i + 1:i + 1 + n]]
    del args[i:i + 1 + n]
    return vals if n > 1 else vals[0]


def load_world(wdir):
    path = os.path.join(wdir, "world.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return None


def save_world(wdir, world):
    with open(os.path.join(wdir, "world.json"), "w", encoding="utf-8") as f:
        json.dump(world, f, ensure_ascii=False, indent=1)


def new_world(res, bounds, chunk_px):
    x0, x1, z0, z1 = bounds
    w, h = int(round((x1 - x0) * res)), int(round((z1 - z0) * res))
    return {"res": res, "bounds": [x0, x1, z0, z1], "size": [w, h], "chunkPx": chunk_px, "chunkStuds": chunk_px / res,
            "sets": [], "chunks": {}}


def ramp(n, band):
    """weights 0..1 over n samples: rising over `band` samples at each end (0 when band <= 0 never happens: 1)."""
    if band <= 0:
        return np.ones(n, dtype=np.float32)
    i = np.arange(n, dtype=np.float32) + 0.5
    return np.clip(np.minimum(i, n - i) / band, 0.0, 1.0).astype(np.float32)


def set_dir(name):
    return name if os.path.isdir(name) else os.path.join(ROOT, "art", "minimap", name)


def set_name(name):
    """the set as world.json keeps it: its folder name under art/minimap, else the path as given"""
    d = os.path.normpath(os.path.abspath(set_dir(name)))
    base = os.path.normpath(os.path.join(ROOT, "art", "minimap"))
    return os.path.relpath(d, base).replace(os.sep, "/") if d.startswith(base + os.sep) else name


def read_set(name):
    sdir = set_dir(name)
    with open(os.path.join(sdir, "tiles.json"), encoding="utf-8") as f:
        meta = json.load(f)
    return sdir, meta


def add_set(world, mosaic, name):
    """paste one set into the mosaic (uint8 RGBA, H x W x 4) inside the set's own box; returns its tile boxes (mosaic px)"""
    sdir, meta = read_set(name)
    res = world["res"]
    bx0, _, bz0, _ = world["bounds"]
    W, H = world["size"]
    over = float(meta.get("overlapStuds", 0))
    tiles = []
    for t in meta["tiles"]:
        tx0, tx1, tz0, tz1 = float(t["x0"]), float(t["x1"]), float(t["z0"]), float(t["z1"])
        px0, pz0 = int(round((tx0 - bx0) * res)), int(round((tz0 - bz0) * res))
        pw, ph = int(round((tx1 - tx0) * res)), int(round((tz1 - tz0) * res))
        if px0 >= W or pz0 >= H or px0 + pw <= 0 or pz0 + ph <= 0:
            print("  tile outside the world bounds:", t.get("id"))
            continue
        tiles.append((t, px0, pz0, pw, ph))
    if not tiles:
        return [], meta
    # the set's box in the mosaic (clipped): every array below is only that big
    rx0 = max(0, min(px0 for _, px0, _, _, _ in tiles))
    rz0 = max(0, min(pz0 for _, _, pz0, _, _ in tiles))
    rx1 = min(W, max(px0 + pw for _, px0, _, pw, _ in tiles))
    rz1 = min(H, max(pz0 + ph for _, _, pz0, _, ph in tiles))
    acc = np.zeros((rz1 - rz0, rx1 - rx0, 3), dtype=np.float32)
    wsum = np.zeros((rz1 - rz0, rx1 - rx0), dtype=np.float32)
    boxes = []
    for t, px0, pz0, pw, ph in tiles:
        img = Image.open(os.path.join(sdir, t["file"])).convert("RGB").resize((pw, ph), Image.LANCZOS)
        a = np.asarray(img, dtype=np.float32)
        wt = np.outer(ramp(ph, over * res), ramp(pw, over * res))
        cx0, cz0 = max(rx0, px0), max(rz0, pz0)
        cx1, cz1 = min(rx1, px0 + pw), min(rz1, pz0 + ph)
        sx, sz = cx0 - px0, cz0 - pz0
        a = a[sz:sz + (cz1 - cz0), sx:sx + (cx1 - cx0)]
        wt = wt[sz:sz + (cz1 - cz0), sx:sx + (cx1 - cx0)]
        acc[cz0 - rz0:cz1 - rz0, cx0 - rx0:cx1 - rx0] += a * wt[..., None]
        wsum[cz0 - rz0:cz1 - rz0, cx0 - rx0:cx1 - rx0] += wt
        boxes.append((t.get("id"), px0, pz0, pw, ph))
    hit = wsum > 1e-6
    new_rgb = np.zeros_like(acc)
    new_rgb[hit] = acc[hit] / wsum[hit][..., None]
    alpha = np.clip(wsum, 0.0, 1.0)  # 1 inside the set (the ramps add up to 1), fading at its outer rim
    region = mosaic[rz0:rz1, rx0:rx1].astype(np.float32)
    old_rgb, old_a = region[..., :3], region[..., 3] / 255.0
    rgb = old_rgb * (1 - alpha[..., None]) + new_rgb * alpha[..., None]
    # where nothing was before, the colour under the soft rim is the new colour (not a fade to black)
    fresh = old_a < 1e-6
    rgb[fresh] = new_rgb[fresh]
    out_a = np.maximum(old_a, alpha) * 255.0
    mosaic[rz0:rz1, rx0:rx1] = np.clip(np.dstack([rgb, out_a]) + 0.5, 0, 255).astype(np.uint8)
    key = set_name(name)
    world["sets"] = [s for s in world["sets"] if s != key] + [key]
    return boxes, meta


def chunk_grid(world):
    W, H = world["size"]
    c = world["chunkPx"]
    return int(math.ceil(W / c)), int(math.ceil(H / c))


def cut(world, mosaic, wdir, touched_px=None):
    """re-cut the chunks touching the px boxes (all when None); returns the keys that changed"""
    W, H = world["size"]
    c = world["chunkPx"]
    res = world["res"]
    bx0, _, bz0, _ = world["bounds"]
    cols, rows = chunk_grid(world)
    os.makedirs(os.path.join(wdir, "chunks"), exist_ok=True)
    changed = []
    for row in range(rows):
        for col in range(cols):
            x0p, z0p = col * c, row * c
            x1p, z1p = min(W, x0p + c), min(H, z0p + c)
            if touched_px is not None and not any(
                    bx < x1p and bx + bw > x0p and bz < z1p and bz + bh > z0p for _, bx, bz, bw, bh in touched_px):
                continue
            key = f"c{col}_{row}"
            part = mosaic[z0p:z1p, x0p:x1p]
            cover = float(part[..., 3].mean()) / 255.0
            rec = world["chunks"].get(key)
            if cover < EMPTY:
                if rec:
                    print("  chunk now empty, dropped:", key)
                    world["chunks"].pop(key, None)
                continue
            img = Image.fromarray(np.ascontiguousarray(part), "RGBA")
            file = f"chunks/{key}.png"
            img.save(os.path.join(wdir, file), optimize=True)
            sha = hashlib.sha1(img.tobytes()).hexdigest()[:16]
            entry = {"col": col, "row": row, "X0": round(bx0 + x0p / res, 2), "X1": round(bx0 + x1p / res, 2),
                     "Z0": round(bz0 + z0p / res, 2), "Z1": round(bz0 + z1p / res, 2), "file": file, "sha": sha,
                     "px": [x1p - x0p, z1p - z0p], "coverage": round(cover, 3), "Id": "", "OldId": ""}
            if rec and rec.get("sha") == sha:
                entry["Id"], entry["OldId"] = rec.get("Id", ""), rec.get("OldId", "")
            else:
                if rec and rec.get("Id"):
                    entry["OldId"] = rec["Id"]
                changed.append(key)
            world["chunks"][key] = entry
    return changed


def load_mosaic(world, wdir):
    path = os.path.join(wdir, "mosaic.png")
    W, H = world["size"]
    if os.path.exists(path):
        img = Image.open(path).convert("RGBA")
        if img.size == (W, H):
            return np.array(img, dtype=np.uint8)
        print("mosaic.png has another size - starting a new one")
    return np.zeros((H, W, 4), dtype=np.uint8)


def save_mosaic(mosaic, wdir):
    Image.fromarray(mosaic, "RGBA").save(os.path.join(wdir, "mosaic.png"))


def sheet(world, mosaic, wdir, last_boxes=None, last_set=None):
    """the mosaic small with the chunk grid + the last set's tile edges, and its seams at native size x2"""
    W, H = world["size"]
    ys, xs = np.nonzero(mosaic[..., 3] > int(EMPTY * 255))
    if len(xs) == 0:
        print("nothing in the mosaic yet")
        return None
    # the covered part (+ a margin), shrunk first, then laid on a dark checker so the alpha rim shows
    m = 40
    x0, x1 = max(0, int(xs.min()) - m), min(W, int(xs.max()) + m)
    z0, z1 = max(0, int(ys.min()) - m), min(H, int(ys.max()) + m)
    over = Image.fromarray(np.ascontiguousarray(mosaic[z0:z1, x0:x1]), "RGBA")
    scale = min(1.0, 1600 / over.width, 1000 / over.height)
    small_rgba = over.resize((max(1, int(over.width * scale)), max(1, int(over.height * scale))), Image.LANCZOS)
    yy, xx = np.mgrid[0:small_rgba.height, 0:small_rgba.width]
    check = np.where(((xx // 12) + (yy // 12)) % 2 == 0, 40, 70).astype(np.uint8)
    small = Image.fromarray(np.dstack([check, check, check]), "RGB")
    small.paste(small_rgba, (0, 0), small_rgba)
    d = ImageDraw.Draw(small)
    c = world["chunkPx"]
    for key, ch in world["chunks"].items():
        cx0, cz0 = (ch["col"] * c - x0) * scale, (ch["row"] * c - z0) * scale
        cx1, cz1 = cx0 + ch["px"][0] * scale, cz0 + ch["px"][1] * scale
        d.rectangle([cx0, cz0, cx1, cz1], outline=(255, 200, 60), width=2)
        # the label at the chunk's top-left corner, kept inside the picture (the crop starts at the covered part)
        lx = min(max(cx0, 0), small.width - 1) + 4
        lz = min(max(cz0, 0), small.height - 1) + 4
        d.text((lx, lz), f"{key} {'id' if ch.get('Id') else 'NEW'} {ch['coverage']:.0%}", fill=(255, 220, 90))
    for _, bx, bz, bw, bh in (last_boxes or []):
        d.rectangle([(bx - x0) * scale, (bz - z0) * scale, (bx + bw - x0) * scale, (bz + bh - z0) * scale],
                    outline=(60, 220, 255), width=1)
    # seams: the middle of every band shared by two tiles of the last set, 96 px around it at native size, x2
    crops = []
    boxes = last_boxes or []
    for i, (_, ax, az, aw, ah) in enumerate(boxes):
        for _, bx, bz, bw, bh in boxes[i + 1:]:
            ox0, ox1 = max(ax, bx), min(ax + aw, bx + bw)
            oz0, oz1 = max(az, bz), min(az + ah, bz + bh)
            if ox1 > ox0 and oz1 > oz0 and (ox1 - ox0 < aw * 0.5 or oz1 - oz0 < ah * 0.5):
                cx, cz = (ox0 + ox1) // 2, (oz0 + oz1) // 2
                box = (max(0, cx - 48), max(0, cz - 48), min(W, cx + 48), min(H, cz + 48))
                sub = Image.fromarray(np.ascontiguousarray(mosaic[box[1]:box[3], box[0]:box[2], :3]), "RGB")
                crops.append(sub.resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2), Image.NEAREST))
            if len(crops) >= 8:
                break
        if len(crops) >= 8:
            break
    strip_h = 200 if crops else 0
    out = Image.new("RGB", (max(small.width, 8 * 200), small.height + strip_h + 30), (24, 26, 34))
    out.paste(small, (0, 30))
    ImageDraw.Draw(out).text((8, 8), f"minimap mosaic - res {world['res']} px/stud, chunk {world['chunkPx']} px "
                             f"({world['chunkStuds']:.0f} studs), sets {', '.join(world['sets'])}; gold = chunks, "
                             f"cyan = tiles of {last_set or '-'}", fill=(230, 230, 230))
    for i, cimg in enumerate(crops):
        out.paste(cimg.resize((196, 196)), (i * 200 + 2, small.height + 32))
    os.makedirs(os.path.join(ROOT, "art", "review"), exist_ok=True)
    tag = os.path.basename(os.path.normpath(last_set)) if last_set else "world"
    path = os.path.join(ROOT, "art", "review", f"minimap_stitch_{tag}.jpg")
    out.save(path, quality=88)
    print("sheet:", path, f"({len(crops)} seam crops)")
    return path


def status(world):
    keys = sorted(world["chunks"], key=lambda k: (world["chunks"][k]["row"], world["chunks"][k]["col"]))
    need = [k for k in keys if not world["chunks"][k].get("Id")]
    print(f"world res {world['res']} px/stud, chunk {world['chunkPx']} px = {world['chunkStuds']:.1f} studs, "
          f"sets: {', '.join(world['sets']) or '-'}")
    for k in keys:
        ch = world["chunks"][k]
        print(f"  {k}: X {ch['X0']}..{ch['X1']} Z {ch['Z0']}..{ch['Z1']} {ch['px'][0]}x{ch['px'][1]} px, "
              f"covered {ch['coverage']:.0%}, {ch.get('Id') or 'needs upload'}" + (
                  f" (was {ch['OldId']})" if ch.get("OldId") else ""))
    print(f"{len(keys)} chunks, {len(need)} to upload: {' '.join(need) or '-'}")


def config(world):
    keys = sorted(world["chunks"], key=lambda k: (world["chunks"][k]["row"], world["chunks"][k]["col"]))
    print("Config.UIArt.MapTiles = {")
    print(f"\t-- tools/minimap_stitch.py (sets: {', '.join(world['sets'])}; {world['res']} px/stud)")
    for k in keys:
        ch = world["chunks"][k]
        # a re-shot chunk keeps its old picture until the new one is uploaded (the screen never goes blank)
        aid = ch.get("Id") or ch.get("OldId")
        note = "" if ch.get("Id") else " (old picture: upload the new one)"
        if aid:
            print(f"\t{{ Id = \"{aid}\", X0 = {ch['X0']:g}, X1 = {ch['X1']:g}, Z0 = {ch['Z0']:g}, Z1 = {ch['Z1']:g} }}, -- {k}{note}")
    print("}")
    waiting = [k for k in keys if not ch_id(world, k)]
    if waiting:
        print("-- to upload:", " ".join(waiting))


def ch_id(world, k):
    return world["chunks"][k].get("Id")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    wdir = arg(args, "--world", cast=str) or os.path.join(ROOT, "art", "minimap", "world")
    res = arg(args, "--res")
    bounds = arg(args, "--bounds", 4)
    chunk_px = arg(args, "--chunk", cast=int)
    if not args:
        sys.exit(__doc__)
    cmd, rest = args[0], args[1:]
    os.makedirs(wdir, exist_ok=True)
    world = load_world(wdir)
    if cmd == "add":
        if not rest:
            sys.exit("add needs a set name (art/minimap/<set>)")
        if world is None:
            world = new_world(res or DEFAULTS["res"], bounds or DEFAULTS["bounds"], chunk_px or DEFAULTS["chunkPx"])
        elif res or bounds or chunk_px:
            print("note: --res / --bounds / --chunk only apply to a new world (delete world.json + mosaic.png first)")
        mosaic = load_mosaic(world, wdir)
        all_boxes, last = [], None
        for name in rest:
            boxes, _ = add_set(world, mosaic, name)
            print(f"set {name}: {len(boxes)} tiles")
            all_boxes += boxes
            last = set_name(name)
        changed = cut(world, mosaic, wdir, all_boxes)
        save_mosaic(mosaic, wdir)
        save_world(wdir, world)
        print("changed chunks (upload these):", " ".join(changed) or "-")
        sheet(world, mosaic, wdir, all_boxes, last)
        status(world)
    elif cmd == "ids":
        if world is None:
            sys.exit("no world yet")
        for pair in rest:
            key, _, aid = pair.partition("=")
            if key not in world["chunks"] or not aid.startswith("rbxassetid://"):
                sys.exit(f"bad pair {pair!r} (KEY=rbxassetid://N, keys: {' '.join(sorted(world['chunks']))})")
            world["chunks"][key]["Id"] = aid
        save_world(wdir, world)
        status(world)
    elif cmd == "config":
        if world is None:
            sys.exit("no world yet")
        config(world)
    elif cmd == "sheet":
        if world is None:
            sys.exit("no world yet")
        sheet(world, load_mosaic(world, wdir), wdir, None, world["sets"][-1] if world["sets"] else None)
    elif cmd == "status":
        if world is None:
            sys.exit("no world yet")
        status(world)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
