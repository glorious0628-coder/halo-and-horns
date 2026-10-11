"""Cloth maps v3 candidates for HH_Fabric (이미지 개발 2026-10-12; 디자인 검수 10/11: v2 reads as an even 'screen door' grid from far;
the 2D banner is smooth cloth with a soft grain). Same idea as tools/fabric_weave_maps.py (periodic maps, near-white colour so Part.Color tints)
but: weave height/normal strength halved, thread cell positions bent by a periodic low-frequency warp (breaks the regular stripes),
per-thread width/brightness unevenness, slubs along threads. Candidates:
  a: contrast x0.5, warp 0.25 cell, 16 threads        b: contrast x0.5, warp 0.40 cell, 24 threads (finer)        c: like b, contrast x0.35
  py tools/fabric_weave_v3.py [--out art/ui/halo_tile/fabric_v3] [--size 512] [--sheet]
Writes <out>/<cand>/Halo_Fabric_{color,normal,rough}.png and, with --sheet, art/review/imgdev/fabric_v3_compare_2026-10-12.jpg: v2 | a | b | c as the
banner blue (104,170,240), tiled 5x5 and 15x15 tiles (2 studs per tile: 10 and 30 studs of cloth) at the same pixel size (colour x a simple lit-normal shading: sun from the upper left).
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def pnoise(n, rng, cells):
    f = np.fft.fft2(rng.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    f *= np.exp(-(fx * fx + fy * fy) / (2 * cells ** 2))
    a = np.real(np.fft.ifft2(f))
    a -= a.mean()
    return a / (a.std() + 1e-9)


def build(n, threads, contrast, warp, seed):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n].astype(float)
    cell = n / threads
    # periodic coordinate warp (bends the thread rows / columns a little, wraps with the tile)
    wx = pnoise(n, rng, 3.0) * warp * cell
    wy = pnoise(n, rng, 3.0) * warp * cell
    xs, ys = x + wx, y + wy
    u = (xs / cell) % 1.0
    v = (ys / cell) % 1.0
    iu = np.floor(xs / cell).astype(int) % threads
    iv = np.floor(ys / cell).astype(int) % threads
    warp_over = ((iu + iv) % 2) == 0
    across_w, along_w = np.sin(np.pi * u), np.sin(np.pi * v) ** 0.5
    across_f, along_f = np.sin(np.pi * v), np.sin(np.pi * u) ** 0.5
    h_warp = across_w * (0.55 + 0.45 * along_w)
    h_weft = across_f * (0.55 + 0.45 * along_f)
    h = np.where(warp_over, 0.35 + 0.65 * h_warp, 0.35 + 0.65 * h_weft)
    # per-thread brightness (balanced, shuffled) and slubs: slow brightness drift along each thread
    bal = (np.arange(threads) - (threads - 1) / 2) / ((threads - 1) / 2)
    tw, tf = rng.permutation(bal), rng.permutation(bal)
    var = np.where(warp_over, tw[iu], tf[iv]) * 0.012
    slub_w = pnoise(n, rng, 10.0) * 0.010
    fuzz = pnoise(n, rng, n / 6.0) * 0.010
    light = 0.92 + 0.10 * contrast * h + var + slub_w + fuzz
    grey = np.clip(light * 250.0, 0, 255)
    color = np.stack([grey, grey, grey * 0.985], -1)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    k = 2.2 * contrast
    nv = np.stack([-dx * k, dy * k, np.ones_like(h)], -1)
    nv /= np.linalg.norm(nv, axis=-1, keepdims=True)
    normal = np.clip((nv * 0.5 + 0.5) * 255 + 0.5, 0, 255)
    rough = np.clip((0.84 + 0.06 * (1 - h) + fuzz * 2) * 255, 0, 255)
    return color.astype(np.uint8), normal.astype(np.uint8), rough.astype(np.uint8)


CANDS = {"a": dict(threads=16, contrast=0.5, warp=0.25, seed=2012), "b": dict(threads=24, contrast=0.5, warp=0.40, seed=2013),
         "c": dict(threads=24, contrast=0.35, warp=0.40, seed=2014)}
BLUE = np.array([104, 170, 240]) / 255.0


def tinted(color_png, reps, out_px):
    t = np.array(Image.open(color_png).convert("RGB")).astype(float) / 255.0
    nrm = np.array(Image.open(color_png.replace("_color", "_normal")).convert("RGB")).astype(float) / 255.0 * 2 - 1
    L = np.array([-0.45, 0.45, 0.77])
    L /= np.linalg.norm(L)
    lam = np.clip(nrm @ L, 0, 1) / L[2]          # 1.0 on a flat surface; the weave relief darkens/brightens it (rough sun-lit look)
    t = np.clip(t * BLUE * lam[..., None], 0, 1)
    im = Image.fromarray((t * 255).astype(np.uint8))
    tile = im.resize((max(2, out_px // reps), max(2, out_px // reps)), Image.LANCZOS)
    big = Image.new("RGB", (tile.width * reps, tile.height * reps))
    for i in range(reps):
        for j in range(reps):
            big.paste(tile, (i * tile.width, j * tile.height))
    return big.resize((out_px, out_px), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "ui", "halo_tile", "fabric_v3"))
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--sheet", action="store_true")
    a = ap.parse_args()
    for k, p in CANDS.items():
        d = os.path.join(a.out, k)
        os.makedirs(d, exist_ok=True)
        c, nm, r = build(a.size, **p)
        Image.fromarray(c, "RGB").save(os.path.join(d, "Halo_Fabric_color.png"))
        Image.fromarray(nm, "RGB").save(os.path.join(d, "Halo_Fabric_normal.png"))
        Image.fromarray(r, "L").save(os.path.join(d, "Halo_Fabric_rough.png"))
        print(k, "colour mean", c.reshape(-1, 3).mean(0).round(1), "min", c.min(), "max", c.max())
    if a.sheet:
        srcs = [("v2 (now)", os.path.join(ROOT, "art", "ui", "halo_tile", "fabric_v2", "Halo_Fabric_color.png"))]
        srcs += [("v3" + k, os.path.join(a.out, k, "Halo_Fabric_color.png")) for k in CANDS]
        S = 380
        sh = Image.new("RGB", (S * len(srcs), S * 2 + 40), (25, 25, 25))
        d = ImageDraw.Draw(sh)
        for i, (name, f) in enumerate(srcs):
            d.text((i * S + 4, 4), name, fill=(255, 255, 255))
            d.text((i * S + 4, S + 24), name + " 15x15 tiles", fill=(255, 255, 255))
            sh.paste(tinted(f, 5, S), (i * S, 20))
            sh.paste(tinted(f, 15, S), (i * S, S + 40))
        sh.save(os.path.join(ROOT, "art", "review", "imgdev", "fabric_v3_compare_2026-10-12.jpg"), quality=90)


if __name__ == "__main__":
    main()
