"""Smooth cream marble maps for small Halo-town props (이미지 개발 2026-10-11, 검수: HH_HaloMarbleBlock_Cream has a 1.5-cell
grout line that reads as brickwork on bench legs / lamp posts / planter bodies; the 2D props show a smooth cream stone with only
a faint grain). Seamless squares (everything is built from periodic FFT noise, so 3x3 tiling has no seam).

  py tools/marble_smooth_maps.py [--out art/ui/halo_tile/marble_smooth] [--size 1024]
Writes Halo_MarbleSmoothCream_color.png / _rough.png (+ _normal.png flat, not uploaded: the flat gold normal 131597673772642 is reused)
and a 3x3 tile check sheet _tilecheck.jpg.
colour: near the cream block's own average (237,231,220) with a soft warm/cool mottling (+-4) and a few thin pale-grey veins (about 6-8 darker);
no grout. Metalness: reuse the all-zero map (87489921567476). Roughness 0.55..0.70 with a slow variation (the cream block uses ~0.62).
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def periodic_noise(n, rng, sigma_cells):
    """Zero-mean, unit-std periodic noise: white noise low-passed in Fourier space (wraps by construction)."""
    f = np.fft.fft2(rng.standard_normal((n, n)))
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    k2 = fx * fx + fy * fy
    f *= np.exp(-k2 / (2 * sigma_cells ** 2))      # gaussian low-pass: keeps spatial frequencies up to about sigma_cells cycles per tile
    a = np.real(np.fft.ifft2(f))
    a -= a.mean()
    return a / (a.std() + 1e-9)


def build(n):
    rng = np.random.default_rng(1011)
    base = np.array([237.0, 231.0, 220.0])
    soft = periodic_noise(n, rng, 3.0)                 # large slow cloud
    mid = periodic_noise(n, rng, 8.0)                  # medium mottling
    # veins: long wavy diagonal lines. phase = 2*pi*(kx*x + ky*y)/n + warp (integer wave vector -> periodic); a vein sits where the
    # phase is near pi. warp noise bends them; a second finer, fainter set branches off at another angle.
    y, x = np.mgrid[0:n, 0:n].astype(float)
    def vein(kx, ky, amp, width, seed, sig):
        r = np.random.default_rng(seed)
        ph = 2 * np.pi * (kx * x + ky * y) / n + amp * periodic_noise(n, r, sig)
        d = np.angle(np.exp(1j * (ph - np.pi)))        # signed distance to the line, -pi..pi
        return np.exp(-(d ** 2) / (2 * width ** 2))
    v1 = vein(1, 2, 0.9, 0.05, 7, 3.0)
    v2 = vein(2, -1, 0.8, 0.035, 19, 4.0)
    lum = 1.0 + 0.006 * soft + 0.004 * mid - 0.034 * v1 - 0.020 * v2
    warm = 0.006 * periodic_noise(n, rng, 4.0)          # tiny hue drift: warm <-> cool
    col = np.empty((n, n, 3))
    col[..., 0] = base[0] * lum * (1 + warm)
    col[..., 1] = base[1] * lum
    col[..., 2] = base[2] * lum * (1 - warm)
    col = np.clip(col, 0, 255).astype(np.uint8)
    rough = 0.62 + 0.035 * soft + 0.02 * mid + 0.04 * v1
    rough = (np.clip(rough, 0, 1) * 255).astype(np.uint8)
    normal = np.zeros((n, n, 3), np.uint8)
    normal[..., 0] = 128
    normal[..., 1] = 128
    normal[..., 2] = 255
    return col, rough, normal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "ui", "halo_tile", "marble_smooth"))
    ap.add_argument("--size", type=int, default=1024)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    col, rough, normal = build(a.size)
    Image.fromarray(col).save(os.path.join(a.out, "Halo_MarbleSmoothCream_color.png"))
    Image.fromarray(rough, "L").save(os.path.join(a.out, "Halo_MarbleSmoothCream_rough.png"))
    Image.fromarray(normal).save(os.path.join(a.out, "Halo_MarbleSmoothCream_normal.png"))
    t = Image.fromarray(col).resize((384, 384), Image.LANCZOS)
    sheet = Image.new("RGB", (384 * 3, 384 * 3))
    for i in range(3):
        for j in range(3):
            sheet.paste(t, (i * 384, j * 384))
    sheet.save(os.path.join(a.out, "Halo_MarbleSmoothCream_tilecheck.jpg"), quality=92)
    print("ok", a.out, "mean colour", col.reshape(-1, 3).mean(0).round(1), "min", col.reshape(-1, 3).min(0), "max", col.reshape(-1, 3).max(0))


if __name__ == "__main__":
    main()
