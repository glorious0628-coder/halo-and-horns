"""Cloth maps for the HH_Fabric MaterialVariant (이미지 개발 2026-10-11, 검수: Enum.Material.Fabric renders dark and does not
take Part.Color - its built-in albedo is dark grey). A near-white plain-weave colour map + weave normal + rough map, seamless
squares (everything is periodic), so Part.Color tints the cloth like it tints Plastic.

  py tools/fabric_weave_maps.py [--out art/ui/halo_tile/fabric] [--size 512] [--threads 16]
Writes Halo_Fabric_color.png / _normal.png / _rough.png (and a 3x3 tile check sheet _tilecheck.jpg).
colour: 226..250 grey-white with slight thread-to-thread brightness (a cloth, not a flat plastic); roughness 0.85; no metal map.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def build(n, threads):
    rng = np.random.default_rng(1011)
    y, x = np.mgrid[0:n, 0:n].astype(float)
    cell = n / threads
    u = (x / cell) % 1.0           # position inside a thread cell, 0..1
    v = (y / cell) % 1.0
    iu = (x // cell).astype(int)   # thread index
    iv = (y // cell).astype(int)
    # plain weave: warp (vertical thread) is over where (iu + iv) is even
    warp_over = ((iu + iv) % 2) == 0
    # a thread's height profile: rounded across its width, dipping where it goes under at the cell ends
    across_w = np.sin(np.pi * u)               # warp thread: round across x
    along_w = np.sin(np.pi * v) ** 0.5          # ... and over the cell length
    across_f = np.sin(np.pi * v)                # weft thread: round across y
    along_f = np.sin(np.pi * u) ** 0.5
    h_warp = across_w * (0.55 + 0.45 * along_w)
    h_weft = across_f * (0.55 + 0.45 * along_f)
    h = np.where(warp_over, 0.35 + 0.65 * h_warp, 0.35 + 0.65 * h_weft)
    # per-thread brightness variation and fuzz (periodic: indices wrap with the tile)
    rng.uniform(-1, 1, threads)   # keep the rng stream (fuzz) identical to v1
    rng.uniform(-1, 1, threads)
    # v2 (검수 10/11: one bright vertical thread repeated per tile): the old +-0.035 spread let one random thread stand out as
    # a bright column in the 3x3. Now a balanced, zero-mean, shuffled spread of +-0.010 (no outlier thread, same fuzz).
    bal = (np.arange(threads) - (threads - 1) / 2) / ((threads - 1) / 2)       # -1..1 evenly spaced
    tw = rng.permutation(bal)
    tf = rng.permutation(bal)
    var = np.where(warp_over, tw[iu % threads], tf[iv % threads]) * 0.010
    fuzz = rng.standard_normal((n, n))
    fz = np.real(np.fft.ifft2(np.fft.fft2(fuzz) * np.exp(-2 * np.pi ** 2 * ((np.fft.fftfreq(n)[None, :] * 1.2) ** 2 + (np.fft.fftfreq(n)[:, None] * 1.2) ** 2))))
    fz = (fz - fz.mean()) / (fz.std() + 1e-9) * 0.012
    light = 0.90 + 0.10 * h + var + fz       # ~0.86..1.0
    grey = np.clip(light * 250.0, 0, 255)
    color = np.stack([grey, grey, grey * 0.985], -1)
    # normal from the height field
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    k = 2.2
    nv = np.stack([-dx * k, dy * k, np.ones_like(h)], -1)
    nv /= np.linalg.norm(nv, axis=-1, keepdims=True)
    normal = np.clip((nv * 0.5 + 0.5) * 255 + 0.5, 0, 255)
    rough = np.clip((0.82 + 0.10 * (1 - h) + fz * 2) * 255, 0, 255)
    tilt = float(np.degrees(np.arccos(nv[..., 2].min())))
    return color.astype(np.uint8), normal.astype(np.uint8), rough.astype(np.uint8), tilt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "ui", "halo_tile", "fabric"))
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--threads", type=int, default=16)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    c, nrm, r, tilt = build(a.size, a.threads)
    Image.fromarray(c, "RGB").save(os.path.join(a.out, "Halo_Fabric_color.png"))
    Image.fromarray(nrm, "RGB").save(os.path.join(a.out, "Halo_Fabric_normal.png"))
    Image.fromarray(r, "L").save(os.path.join(a.out, "Halo_Fabric_rough.png"))
    print("colour mean", c.reshape(-1, 3).mean(0).round(1), "min", c.min(), "max", c.max(), "normal max tilt", round(tilt, 1), "deg")
    # 3x3 tile check at 1/2 size
    t = Image.new("RGB", (a.size * 3 // 2, a.size * 3 // 2))
    small = Image.fromarray(c, "RGB").resize((a.size // 2, a.size // 2), Image.LANCZOS)
    for i in range(3):
        for j in range(3):
            t.paste(small, (i * a.size // 2, j * a.size // 2))
    t.save(os.path.join(a.out, "Halo_Fabric_tilecheck.jpg"), quality=90)


if __name__ == "__main__":
    main()
