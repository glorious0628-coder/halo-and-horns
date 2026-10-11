"""Gold trim test maps for the HH_HaloGoldTrim look test (검수 2026-10-11: the gold bands read as flat pale yellow with no
shine in WorldKit; 이미지 개발). All maps are seamless squares (periodic FFT blur, wrap-around gradients).

  py tools/gold_trim_maps.py [--out art/ui/halo_tile/goldtest] [--size 512]
Writes:
  Halo_GoldTest_rough15.png / rough35.png / rough45.png   flat roughness 0.15 / 0.35 / 0.45
  Halo_GoldTest_roughvar.png    roughness 0.16..0.34 in soft patches (some spots catch the sun more than others)
  Halo_GoldTest_hammer_normal.png   soft hammered dents (tangent-space normal, tilt up to ~12 deg)
  Halo_GoldTest_brush_normal.png    fine horizontal brushing (tilt up to ~6 deg)
  Halo_GoldTest_metal50.png / metal70.png   flat metalness 0.5 / 0.7 (round 2)
The colour map stays the near-white Halo_GoldTrim_color (the part Color gives the gold), metal stays 1.
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def periodic_blur(a, sigma_x, sigma_y=None):
    """gaussian blur with wrap-around edges (multiplication in the frequency domain)"""
    sigma_y = sigma_x if sigma_y is None else sigma_y
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi ** 2) * ((fx * sigma_x) ** 2 + (fy * sigma_y) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def norm01(a):
    return (a - a.min()) / max(1e-9, a.max() - a.min())


def normal_map(height, strength):
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    n = np.stack([-dx * strength, dy * strength, np.ones_like(height)], -1)  # +y up (OpenGL style, as Roblox expects)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(np.clip((n * 0.5 + 0.5) * 255 + 0.5, 0, 255).astype(np.uint8), "RGB"), \
        float(np.degrees(np.arccos(n[..., 2].min())))


def fit_tilt(height, target_deg):
    """the normal map whose steepest tilt is about target_deg (strength found by bisection)"""
    lo, hi = 0.0, 10.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if normal_map(height, mid)[1] < target_deg:
            lo = mid
        else:
            hi = mid
    return normal_map(height, (lo + hi) / 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "ui", "halo_tile", "goldtest"))
    ap.add_argument("--size", type=int, default=512)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    n = a.size
    rng = np.random.default_rng(1011)
    save = lambda img, name: (img.save(os.path.join(a.out, name)), print(name, img.size, img.mode))  # noqa: E731

    for v in (15, 35, 45):
        save(Image.new("L", (n, n), round(v / 100 * 255)), f"Halo_GoldTest_rough{v}.png")
    # round 2 (the first board read olive at metalness 1: the blue sky tints the reflection): part-diffuse gold
    for v in (50, 70):
        save(Image.new("L", (n, n), round(v / 100 * 255)), f"Halo_GoldTest_metal{v}.png")

    patches = norm01(periodic_blur(rng.standard_normal((n, n)), n / 24))
    save(Image.fromarray(np.round((0.16 + 0.18 * patches) * 255).astype(np.uint8), "L"), "Halo_GoldTest_roughvar.png")

    # hammered: soft round dents ~ n/20 across
    dents = periodic_blur(rng.standard_normal((n, n)), n / 40)
    dents = (norm01(dents) - 0.5) * (n / 18)
    img, tilt = fit_tilt(dents, 12)
    save(img, "Halo_GoldTest_hammer_normal.png")
    print("  hammer max tilt", round(tilt, 1))

    # brushed: long thin streaks along x
    streak = periodic_blur(rng.standard_normal((n, n)), n / 6, 0.8)
    streak = (norm01(streak) - 0.5) * 6
    img, tilt = fit_tilt(streak, 6)
    save(img, "Halo_GoldTest_brush_normal.png")
    print("  brush max tilt", round(tilt, 1))


if __name__ == "__main__":
    main()
