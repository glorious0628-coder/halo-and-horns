"""Per-zone texture split / PBR 4 maps for the Tripo models of a zone (A23-107; 이미지 개발 2026-10-10).

  py tools/zone_split_batch.py <zone> [--only Name,Name] [--skip-split] [--skip-bundle] [--skip-shots] [--skip-sheet]

Two modes per model (검수 10/10, docs/design/sharpness_redo_list_2026-10-10.md):
- split: 4096 sources only. tools/split_uv_tiles.py cuts the UV into grid x grid tiles of 1024 (new meshes) ->
  bundle GLBs for the user's Roblox 3D import in build/import_all/<n>_<zone>/ (+ _list.json).
- maps:  the mesh and its UV stay as they are in the game; four 1024 maps for a SurfaceAppearance on the same MeshPart
  (Color, Normal, Metalness, Roughness) -> art/ui/sa_<zone>/<name>_{C,N,M,R}.png for upload; no import needed.
Maps for both modes:
  - metal + roughness from colour masks (tools/pbr_from_color.py rules, values per 검수 10/10: gold metal 0.9 / rough 0.28
    and the gold colour +12% saturation); no Tripo metal map (stylized props went chrome-grey with it, 2026-10-08);
  - normal: the model's own (Tripo) normal when it has one, its slopes x1.5 on wood and stone so grain and mortar show;
    otherwise one from the colour's brightness (blurred luminance as height, stronger on wood/stone) - 검수 judges these
    from the check sheets ("뺌" -> --no-gen-normal leaves them without a normal).
Check sheets per model (docs/design/3d_quality_check_2026-10-10.md): 2D | 3D, four 100% crops before/after, two tile seams,
numbers -> art/review/imgdev/<zone>_split/<name>.jpg; overview art/review/imgdev/<zone>_split_compare.jpg.
Work files: art/models/tripo/split_<zone>/ (regenerated from the sources). Blender path from AGENTS.md.
"""
import argparse
import io
import json
import os
import struct
import subprocess
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"
T = "art/models/tripo/"
K = T + "kit_crossroads/"

# name: (source glb, kind tripo|web, fit max studs (in-game size), grid, mode split|maps, in-game before: "tex" = one
# TextureID colour, "sa" = SurfaceAppearance colour + normal + roughness without metal)
ZONES = {
    "crossroads": {
        "bundle_dir": "build/import_all/7_crossroads",
        "prefix": "X",
        "bundle_mb": 60,
        "models": {
            # split: 4096 sources (all on the remake list too - this is the interim sharpness step)
            "X_GuildHall": (T + "X_GuildHall_raw.glb", "tripo", 24.0, 3, "split", "tex"),
            "Kit_X_StallRed": (K + "Kit_X_StallRed_raw.glb", "tripo", 12.915, 2, "split", "tex"),
            "Kit_X_StallBlue": (K + "Kit_X_StallBlue_raw.glb", "tripo", 12.915, 2, "split", "tex"),
            "Kit_X_StallGreen": (K + "Kit_X_StallGreen_raw.glb", "tripo", 12.915, 2, "split", "tex"),
            "Kit_X_BannerHalo": (K + "Kit_X_BannerHalo_raw.glb", "tripo", 14.0, 2, "split", "tex"),
            "Kit_X_BannerHorns": (K + "Kit_X_BannerHorns_raw.glb", "tripo", 14.0, 2, "split", "tex"),
            # maps: sharp enough, colour only today (the "재질만" list)
            "Kit_X_Lamp": (K + "Kit_X_Lamp_raw.glb", "tripo", 11.0, 1, "maps", "tex"),
            "X_PadBase": (T + "X_PadBase_raw.glb", "tripo", 12.089, 1, "maps", "tex"),
            "Kit_X_PotionCart": (K + "Kit_X_PotionCart_raw.glb", "tripo", 7.5, 1, "maps", "tex"),
            "Kit_X_Forge": (K + "Kit_X_Forge_raw.glb", "tripo", 6.921, 1, "maps", "tex"),
            "Kit_X_Bench": (K + "Kit_X_Bench_raw.glb", "tripo", 6.5, 1, "maps", "tex"),
            "Kit_X_Curb": (K + "Kit_X_Curb_raw.glb", "tripo", 6.0, 1, "maps", "tex"),
            "Kit_X_Anvil": (K + "Kit_X_Anvil_raw.glb", "tripo", 4.5, 1, "maps", "tex"),
            "Kit_X_Brazier": (K + "Kit_X_Brazier_raw.glb", "tripo", 4.0, 1, "maps", "tex"),
            "Kit_X_FruitCart": (K + "Kit_X_FruitCart_raw.glb", "tripo", 5.0, 1, "maps", "tex"),
            "Kit_X_Barrel": (K + "Kit_X_Barrel_raw.glb", "tripo", 3.0, 1, "maps", "tex"),
            "Kit_X_Crate": (K + "Kit_X_Crate_raw.glb", "tripo", 3.036, 1, "maps", "tex"),
            "Kit_X_Fence": (K + "Kit_X_Fence_raw.glb", "tripo", 6.0, 1, "maps", "tex"),
            "Kit_X_FlowerPot": (K + "Kit_X_FlowerPot_raw.glb", "tripo", 2.5, 1, "maps", "tex"),
            "Kit_X_Bush": (K + "Kit_X_Bush_raw.glb", "tripo", 3.448, 1, "maps", "tex"),
            "X_TreeA": (T + "X_TreeA_raw.glb", "tripo", 14.0, 1, "maps", "tex"),
            "X_SpawnPlaza": (T + "X_SpawnPlaza_raw.glb", "tripo", 16.0, 1, "maps", "tex"),
            # maps: SA in the game but no metal map (web HD, 1024 only: on the remake list; metal/rough now)
            "Town_Halo_Fountain": (T + "web_fixed/Town_Halo_Fountain_R2_fixed.glb", "web", 21.0, 1, "maps", "sa"),
            "X_NoticeBoard": (T + "web_fixed/X_NoticeBoard_fixed.glb", "web", 16.0, 1, "maps", "sa"),
            "X_GooseNest": (T + "web_fixed/X_GooseNest_fixed.glb", "web", 12.0, 1, "maps", "sa"),
            "X_MarketArch": (T + "web_fixed/X_MarketArch_fixed.glb", "web", 12.0, 1, "maps", "sa"),
            "X_Altar": (T + "web_fixed/X_Altar_fixed.glb", "web", 9.0, 1, "maps", "sa"),
        },
    },
}

# 검수 10/10 ("매의 눈", docs/design/3d_quality_check_2026-10-10.md): gold = metal 0.9 / roughness 0.28 and its colour
# saturation +12% (0.18 read olive); wood and stone get a stronger normal so grain and mortar lines show.
MAT = {"gold": (0.9, 0.28), "wood": (0.0, 0.78), "leaf": (0.0, 0.8), "glass": (0.0, 0.12), "cloth": (0.0, 0.85),
       "stone": (0.0, 0.62), "gold_sat": 1.12, "normal_base": 1.6, "normal_wood": 4.0, "normal_stone": 3.2,
       "own_normal_boost": 1.5}
KINDS = ("gold", "wood", "leaf", "glass", "cloth", "stone")


def read_glb(path):
    data = open(path, "rb").read()
    off, js, binc = 12, None, None
    while off < len(data):
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == b"JSON":
            js = json.loads(chunk)
        elif ctype == b"BIN\x00":
            binc = chunk
        off += 8 + clen
    return js, binc


def glb_image(js, binc, tex_index):
    src = js["textures"][tex_index]["source"]
    bv = js["bufferViews"][js["images"][src]["bufferView"]]
    o = bv.get("byteOffset", 0)
    return Image.open(io.BytesIO(binc[o:o + bv["byteLength"]]))


def glb_tris(js):
    return sum(js["accessors"][p["indices"]]["count"] // 3 for m in js.get("meshes", []) for p in m["primitives"] if "indices" in p)


def extract(glb, work, name):
    js, binc = read_glb(glb)
    mat = js["materials"][0]
    pbr = mat.get("pbrMetallicRoughness", {})
    color = glb_image(js, binc, pbr["baseColorTexture"]["index"]).convert("RGB")
    cpath = os.path.join(work, name + "_color.png")
    color.save(cpath)
    npath = None
    if "normalTexture" in mat:
        n = glb_image(js, binc, mat["normalTexture"]["index"]).convert("RGB")
        if n.size != color.size:
            n = n.resize(color.size, Image.BICUBIC)
        npath = os.path.join(work, name + "_normal_own.png")
        n.save(npath)
    return cpath, npath, color.size[0], glb_tris(js)


def masks(rgb):
    """Colour masks with the same rules as tools/pbr_from_color.py (이미지 생성 1)."""
    hsv = np.asarray(Image.fromarray(rgb).convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]

    def soft(m):
        im = Image.fromarray((m.astype(np.float32) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5 * rgb.shape[0] / 1024))
        return np.asarray(im).astype(np.float32) / 255.0

    gold = soft((h >= 30) & (h <= 58) & (s >= 0.5) & (v >= 0.55))
    wood = soft((h >= 12) & (h < 40) & (s >= 0.35) & (v < 0.62)) * (1 - gold)
    leaf = soft((h >= 70) & (h <= 160) & (s >= 0.25)) * (1 - gold)
    glass = soft((h >= 185) & (h <= 215) & (s >= 0.18) & (s < 0.45) & (v >= 0.85)) * (1 - gold)
    cloth = soft((s >= 0.3) & ~((h >= 28) & (h <= 58))) * (1 - gold - wood - leaf - glass).clip(0, 1)
    stone = (1 - gold - wood - leaf - glass - cloth).clip(0, 1)
    return {"gold": gold, "wood": wood, "leaf": leaf, "glass": glass, "cloth": cloth, "stone": stone}


def pbr_maps(work, name):
    """<name>_color_pbr.png (gold saturated), <name>_mr.png (G rough, B metal), <name>_metal/_rough.png; returns masks."""
    rgb = np.asarray(Image.open(os.path.join(work, name + "_color.png")).convert("RGB"))
    m = masks(rgb)
    metal = sum(m[k] * MAT[k][0] for k in KINDS)
    rough = sum(m[k] * MAT[k][1] for k in KINDS)
    hsv = np.asarray(Image.fromarray(rgb).convert("HSV")).astype(np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * (1 + (MAT["gold_sat"] - 1) * m["gold"]), 0, 255)
    Image.fromarray(hsv.round().astype(np.uint8), "HSV").convert("RGB").save(os.path.join(work, name + "_color_pbr.png"))
    to8 = lambda x: (x.clip(0, 1) * 255).round().astype(np.uint8)  # noqa: E731
    Image.fromarray(to8(np.stack([np.zeros_like(rough), rough, metal], -1)), "RGB").save(os.path.join(work, name + "_mr.png"))
    Image.fromarray(to8(metal), "L").save(os.path.join(work, name + "_metal.png"))
    Image.fromarray(to8(rough), "L").save(os.path.join(work, name + "_rough.png"))
    return m, {k: round(float(v.mean()), 3) for k, v in m.items()}


def brightness_slope(cpath, blur=1.2):
    im = Image.open(cpath).convert("L")
    im = im.filter(ImageFilter.GaussianBlur(blur * im.size[0] / 4096))
    h = np.asarray(im).astype(np.float32) / 255.0
    scale = h.shape[0] / 1024.0  # same slope look at any source size
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * scale
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * scale
    return -gx, gy  # OpenGL tangent normal: green = up (image rows run down)


def normal_map(cpath, own_normal, m, out, gen=True):
    """Own normal (slopes x1.5 on wood/stone), or a brightness normal (stronger on wood/stone). None when gen is off."""
    if own_normal:
        t = np.asarray(Image.open(own_normal).convert("RGB")).astype(np.float32) / 255.0 * 2 - 1
        tz = np.maximum(t[..., 2], 0.2)
        k = 1 + (MAT["own_normal_boost"] - 1) * (m["wood"] + m["stone"]).clip(0, 1)
        nx, ny = t[..., 0] / tz * k, t[..., 1] / tz * k
        how = "own (Tripo), x1.5 on wood/stone"
    elif gen:
        k = MAT["normal_base"] + (MAT["normal_wood"] - MAT["normal_base"]) * m["wood"] \
            + (MAT["normal_stone"] - MAT["normal_base"]) * m["stone"]
        dx, dy = brightness_slope(cpath)
        nx, ny = dx * k, dy * k
        how = "from colour brightness (review judges)"
    else:
        return None, "none"
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
    Image.fromarray((n * 255).round().astype(np.uint8), "RGB").save(out)
    return out, how


def save_sa_maps(work, n, npath, zone):
    """maps mode: the four 1024 SurfaceAppearance images for upload (same UV as the game mesh)."""
    d = os.path.join(ROOT, "art", "ui", f"sa_{zone}")
    os.makedirs(d, exist_ok=True)
    out = {}
    for tag, src, mode in (("C", n + "_color_pbr.png", "RGB"), ("N", npath, "RGB"), ("M", n + "_metal.png", "L"),
                           ("R", n + "_rough.png", "L")):
        if not src:
            continue
        p = src if os.path.isabs(src) else os.path.join(work, src)
        im = Image.open(p).convert(mode)
        if im.size != (1024, 1024):
            im = im.resize((1024, 1024), Image.LANCZOS)
        dst = os.path.join(d, f"{n}_{tag}.png")
        im.save(dst, optimize=True)
        out[tag] = os.path.relpath(dst, ROOT).replace("\\", "/")
    return out


def blender(script, *args):
    r = subprocess.run([BLENDER, "--background", "--factory-startup", "--python-exit-code", "1", "--python", script, "--", *args],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    tail = "\n".join(l for l in r.stdout.splitlines() if l.startswith(("[", "tiles", "source", "mr ", "normal ", "Error", "Traceback")))
    if r.returncode != 0:
        raise SystemExit(f"blender failed ({script}):\n{r.stdout[-3000:]}\n{r.stderr[-2000:]}")
    return tail


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("zone", choices=sorted(ZONES))
    ap.add_argument("--only")
    ap.add_argument("--skip-split", action="store_true", help="reuse the maps / split GLBs already in the work folder")
    ap.add_argument("--skip-bundle", action="store_true")
    ap.add_argument("--skip-shots", action="store_true", help="reuse the renders in shots/ (sheets only)")
    ap.add_argument("--skip-sheet", action="store_true")
    ap.add_argument("--no-gen-normal", action="store_true", help="no brightness normal where the model has none")
    a = ap.parse_args()
    z = ZONES[a.zone]
    work = os.path.join(ROOT, "art", "models", "tripo", f"split_{a.zone}")
    os.makedirs(work, exist_ok=True)
    names = [n for n in z["models"] if not a.only or n in a.only.split(",")]
    rp = os.path.join(work, "split_report.json")
    report = {}
    if os.path.isfile(rp):
        with open(rp, encoding="utf-8") as f:
            report = json.load(f)
    if not a.skip_split:
        for n in names:
            src, kind, fit, grid, mode, before = z["models"][n]
            cpath, own_n, size, tris = extract(os.path.join(ROOT, src), work, n)
            m, stats = pbr_maps(work, n)
            cpbr = os.path.join(work, n + "_color_pbr.png")
            npath, how = normal_map(cpbr, own_n, m, os.path.join(work, n + "_normal.png"), gen=not a.no_gen_normal)
            r = {"source": src, "source_px": size, "tris": tris, "grid": grid, "mode": mode, "before": before,
                 "masks": stats, "normal": how}
            if mode == "split":
                out = os.path.join(work, n + "_split.glb")
                args = [os.path.join(ROOT, "tools", "split_uv_tiles.py"), os.path.join(ROOT, src), out, n, "--grid", str(grid),
                        "--kind", kind, "--fit", "max", str(fit), "--tex", cpbr, "--mr", os.path.join(work, n + "_mr.png")]
                if npath:
                    args += ["--normal", npath]
                log = blender(*args)
                r["glb"] = os.path.relpath(out, ROOT).replace("\\", "/")
                r["log"] = log.splitlines()[-1] if log else ""
            else:
                r["sa_files"] = save_sa_maps(work, n, npath, a.zone)
            r.pop("rows", None)
            report[n] = r
            print(f"{n}: {mode} {size}px grid {grid} normal {how}", flush=True)
            with open(rp, "w", encoding="utf-8") as f:
                json.dump(report, f, ensure_ascii=False, indent=1)
    bdir = os.path.join(ROOT, z["bundle_dir"])
    split_names = [n for n in names if z["models"][n][4] == "split"]
    if not a.skip_bundle and split_names:
        print(blender(os.path.join(ROOT, "tools", "zone_split_bundle.py"), "bundle", a.zone, work,
                      bdir, z["prefix"], str(z["bundle_mb"]), ",".join(split_names)))
    for r in report.values():
        r.pop("rows", None)
    if os.path.isdir(bdir):
        for fn in sorted(os.listdir(bdir)):
            if fn.endswith("_list.json"):
                with open(os.path.join(bdir, fn), encoding="utf-8") as f:
                    for row in json.load(f):
                        if row["group"] in report:
                            report[row["group"]].setdefault("rows", []).append(row)
                            report[row["group"]]["bundle"] = fn[:-10] + ".glb"
    if not a.skip_sheet:
        shots = os.path.join(work, "shots")
        os.makedirs(shots, exist_ok=True)
        if not a.skip_shots:
            srcs = ";".join(f"{n}|{os.path.join(ROOT, z['models'][n][0])}|{z['models'][n][1]}|{z['models'][n][2]}|"
                            f"{z['models'][n][4]}|{z['models'][n][5]}" for n in names)
            print(blender(os.path.join(ROOT, "tools", "zone_split_bundle.py"), "shots", a.zone, work, shots, srcs))
        sheet(a.zone, names, shots)
        package(a.zone, names, shots, report)


GREY = (128, 132, 140)


def on_grey(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, GREY + (255,))
    bg.alpha_composite(im)
    return bg.convert("RGB"), np.asarray(im)[..., 3]


def two_d(n):
    short = n[4:] if n.startswith("Kit_") else n
    for p in (f"art/out/hq/HQ_{n}.png", f"art/out/kit/crossroads/{short}.png", f"art/out/town3/{n}_src.png"):
        if os.path.isfile(os.path.join(ROOT, p)):
            return p
    return None


def pick_windows(alpha, score, k, size=256, cover=0.92):
    """k non-overlapping size x size windows inside the model (alpha) with the highest score sum."""
    H, W = alpha.shape
    step = size // 4
    cands = []
    for y in range(0, H - size + 1, step):
        for x in range(0, W - size + 1, step):
            if (alpha[y:y + size, x:x + size] > 200).mean() < cover:
                continue
            cands.append((float(score[y:y + size, x:x + size].sum()), x, y))
    cands.sort(reverse=True)
    out = []
    for s, x, y in cands:
        if s <= 0:
            break
        if all(abs(x - ox) >= size or abs(y - oy) >= size for _, ox, oy in out):
            out.append((s, x, y))
        if len(out) == k:
            break
    return [(x, y) for _, x, y in out]


def package(zone, names, shots, report):
    """One check sheet per model for 검수 (docs/design/3d_quality_check_2026-10-10.md): 2D | 3D, four 100% crops (before
    over after, same spot), two tile-seam crops (seams outlined), numbers. In-game day/night shots are separate."""
    from PIL import ImageDraw
    outdir = os.path.join(ROOT, "art", "review", "imgdev", f"{zone}_split")
    os.makedirs(outdir, exist_ok=True)
    rows_json = {}
    for n in names:
        af = os.path.join(shots, n + "_after.png")
        if not os.path.isfile(af):
            continue
        r = report.get(n, {})
        after, alpha = on_grey(af)
        before, _ = on_grey(os.path.join(shots, n + "_before.png"))
        full, _ = on_grey(os.path.join(shots, n + "_after_full.png"))
        lum = np.asarray(after.convert("L")).astype(np.float32)
        edge = np.abs(np.diff(lum, axis=1, prepend=lum[:, :1])) + np.abs(np.diff(lum, axis=0, prepend=lum[:1]))
        crops = pick_windows(alpha, edge, 4)
        seams, seam_mask = [], None
        tid = os.path.join(shots, n + "_tileid.png")
        if r.get("mode") == "split" and os.path.isfile(tid):
            t = np.asarray(Image.open(tid).convert("RGBA")).astype(np.int32)
            rgb = t[..., :3]
            solid = t[..., 3] > 250
            sm = np.zeros(solid.shape, bool)
            # a seam = two touching model pixels of clearly different tile colours (flat pass: no AA, dither or grading)
            sm[:, 1:] |= (np.abs(rgb[:, 1:] - rgb[:, :-1]).sum(-1) > 24) & solid[:, 1:] & solid[:, :-1]
            sm[1:] |= (np.abs(rgb[1:] - rgb[:-1]).sum(-1) > 24) & solid[1:] & solid[:-1]
            seam_mask = sm
            seams = pick_windows(alpha, sm.astype(np.float32), 2)
        C = 256
        W = 4 * (C + 8) + 20
        H = 30 + 512 + 30 + 2 * C + 30 + (C + 30 if seams else 0) + 50
        sheet_im = Image.new("RGB", (W, H), (34, 34, 40))
        d = ImageDraw.Draw(sheet_im)
        p2d = two_d(n)
        bdesc = "one 1024 colour (TextureID)" if r.get("before") == "tex" else "SA colour + normal + rough, no metal"
        d.text((10, 8), f"{n} [{r.get('mode')}]  2D: {p2d or 'none'}  |  3D after", fill=(240, 240, 240))
        if p2d:
            im2 = Image.open(os.path.join(ROOT, p2d)).convert("RGBA")
            bg = Image.new("RGBA", im2.size, GREY + (255,))
            bg.alpha_composite(im2)
            im2 = bg.convert("RGB")
            im2.thumbnail((512, 512))
            sheet_im.paste(im2, (10, 30))
        f2 = full.copy()
        f2.thumbnail((512, 512))
        sheet_im.paste(f2, (W - 10 - f2.size[0], 30))
        y = 30 + 512 + 8
        d.text((10, y), f"100% crops (1536 close-up, same camera): top = before ({bdesc}), bottom = after", fill=(240, 240, 240))
        y += 22
        for i, (x0, y0) in enumerate(crops):
            sheet_im.paste(before.crop((x0, y0, x0 + C, y0 + C)), (10 + i * (C + 8), y))
            sheet_im.paste(after.crop((x0, y0, x0 + C, y0 + C)), (10 + i * (C + 8), y + C))
        y += 2 * C + 8
        if seams:
            d.text((10, y), "tile seams at 100% (left of each pair: seam outlined red)", fill=(240, 240, 240))
            y += 22
            for i, (x0, y0) in enumerate(seams):
                c = after.crop((x0, y0, x0 + C, y0 + C))
                mk = np.asarray(c).copy()
                mk[seam_mask[y0:y0 + C, x0:x0 + C]] = (255, 40, 40)
                sheet_im.paste(Image.fromarray(mk), (10 + i * 2 * (C + 8), y))
                sheet_im.paste(c, (10 + i * 2 * (C + 8) + C + 8, y))
            y += C + 8
        lst = r.get("rows", [])
        tri = sum(x["tris"] for x in lst) if lst else r.get("tris")
        maps = sorted(set(m for x in lst for m in x["maps"])) if lst else sorted(r.get("sa_files", {}))
        if not lst and r.get("glb") and os.path.isfile(os.path.join(ROOT, r["glb"])):  # split GLB not bundled yet
            js, _ = read_glb(os.path.join(ROOT, r["glb"]))
            lst = [{"tris": 0, "maps": []}] * len(js.get("meshes", []))
            tri = glb_tris(js)
            mat = js.get("materials", [{}])[0]
            maps = ["color"] + (["mr"] if "metallicRoughnessTexture" in mat.get("pbrMetallicRoughness", {}) else [])                 + (["n"] if "normalTexture" in mat else [])
        nums = (f"tris {tri} | tiles {len(lst) or 1} | maps {', '.join(maps)} (1024 each) | source {r.get('source_px')} px | "
                f"grid {r.get('grid')} | normal: {r.get('normal')}")
        d.text((10, y), nums, fill=(255, 230, 150))
        d.text((10, y + 18), f"colour masks: {r.get('masks')}", fill=(255, 230, 150))
        p = os.path.join(outdir, f"{n}.jpg")
        sheet_im.save(p, quality=90)
        rows_json[n] = {"sheet": os.path.relpath(p, ROOT).replace("\\", "/"), "mode": r.get("mode"), "tris": tri,
                        "tiles": len(lst) or 1, "maps": maps, "normal": r.get("normal"), "two_d": p2d,
                        "crops": crops, "seams": seams, "bundle": r.get("bundle"), "sa_files": r.get("sa_files")}
    with open(os.path.join(outdir, "package.json"), "w", encoding="utf-8") as f:
        json.dump(rows_json, f, ensure_ascii=False, indent=1)
    print("package", outdir, len(rows_json), "sheets")


def sheet(zone, names, shots):
    from PIL import ImageDraw
    cell = 384
    rows = []
    for n in names:
        b, af = os.path.join(shots, n + "_before.png"), os.path.join(shots, n + "_after.png")
        if os.path.isfile(b) and os.path.isfile(af):
            rows.append((n, on_grey(b)[0], on_grey(af)[0]))
    cols = 2  # pairs per row
    W = cols * (2 * cell + 12)
    H = ((len(rows) + cols - 1) // cols) * (cell + 22)
    out = Image.new("RGB", (W, H), (40, 40, 46))
    d = ImageDraw.Draw(out)
    for i, (n, b, af) in enumerate(rows):
        x = (i % cols) * (2 * cell + 12)
        y = (i // cols) * (cell + 22)
        d.text((x + 4, y + 4), f"{n}  before | after", fill=(235, 235, 235))
        out.paste(b.resize((cell, cell)), (x, y + 20))
        out.paste(af.resize((cell, cell)), (x + cell, y + 20))
    p = os.path.join(ROOT, "art", "review", "imgdev", f"{zone}_split_compare.jpg")
    out.save(p, quality=88)
    print("sheet", p)


if __name__ == "__main__":
    main()
