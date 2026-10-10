"""PBR maps from a colour texture by colour masks (이미지 생성 1, 2026-10-10, A23-107 재질 + 검수 재질 값 표).

  py tools/pbr_from_color.py <color.png> <out_dir> [--name N] [--size 1024] [--normal-in tile_n.png] [--gold-boost 0.12] [--gold-hue-min 20] [--gold-v-min 0.72]

Writes <N>_metal.png and <N>_rough.png (8-bit grey). With --normal-in also <N>_normal.png (the Tripo tangent normal plus a
detail normal baked from the colour, per material), and with --gold-boost <N>_color.png (gold areas a little more saturated
and brighter so a sky reflection does not turn them olive).

Masks (HSV of the colour map, softened 1.5 px):
- gold / brass (yellow-orange, saturated, bright)  -> metal 0.9, roughness 0.28 (검수 10/10: 0.18 mirrored the green sky -> olive)
- white / cream stone, marble                     -> metal 0, roughness 0.62, detail normal ~12 deg (block joints, chips)
- blue / coloured cloth (banners, awnings)        -> metal 0, roughness 0.85, detail ~6 deg (weave)
- wood / brown                                    -> metal 0, roughness 0.78, detail ~10 deg (grain)
- green leaves                                    -> metal 0, roughness 0.8,  detail ~8 deg
- glass / bright light-blue windows               -> metal 0, roughness 0.12, no detail
Detail normal: height = high-passed luminance (colour minus a 6 px blur), gradient scaled so the 95th percentile tilt of each
material reaches its angle; combined with the input normal by a whiteout blend. Gold keeps the mesh/Tripo normal only.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument("color")
ap.add_argument("out_dir")
ap.add_argument("--name", default=None)
ap.add_argument("--size", type=int, default=1024)
ap.add_argument("--normal-in", default=None)
ap.add_argument("--gold-boost", type=float, default=0.0)
# lowest hue counted as gold. 20 suits the Halo gate (gold hue 25-46); light wood props (Crossroads kit: hue 23-30) need 34
# (이미지 개발 10/10: crates/barrels/benches read as metal). Bright pixels below it fall to wood instead.
ap.add_argument("--gold-hue-min", type=float, default=20.0)
# lowest brightness counted as gold (the Crossroads API kit's gold is darker: hue 34-38, value 0.56-0.70 -> 0.55 with --gold-hue-min 34)
ap.add_argument("--gold-v-min", type=float, default=0.72)
a = ap.parse_args()

name = a.name or os.path.splitext(os.path.basename(a.color))[0]
im = Image.open(a.color).convert("RGB")
if im.size != (a.size, a.size):
    im = im.resize((a.size, a.size), Image.LANCZOS)
hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]


def soft(mask, r=1.5):
    m = Image.fromarray((mask.astype(np.float32) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))
    return np.asarray(m).astype(np.float32) / 255.0


gold = soft((h >= a.gold_hue_min) & (h <= 58) & (s >= 0.4) & (v >= a.gold_v_min))  # 10/10 measured: the gate gold sits at hue 25-46, value 0.7-1.0
wood = soft((h >= 12) & (h < 38) & (s >= 0.3) & ((v < 0.72) | ((h >= 20) & (h < a.gold_hue_min)))) * (1 - gold)  # the shop doors: hue 25-34, value 0.5-0.7
leaf = soft((h >= 70) & (h <= 160) & (s >= 0.25)) * (1 - gold)
glass = soft((h >= 185) & (h <= 215) & (s >= 0.18) & (s < 0.45) & (v >= 0.85)) * (1 - gold)
cloth = soft((s >= 0.3) & ~((h >= 28) & (h <= 58))) * (1 - gold - wood - leaf - glass).clip(0, 1)
stone = (1 - gold - wood - leaf - glass - cloth).clip(0, 1)

metal = gold * 0.9
rough = gold * 0.28 + wood * 0.78 + leaf * 0.8 + glass * 0.12 + cloth * 0.85 + stone * 0.62
os.makedirs(a.out_dir, exist_ok=True)
Image.fromarray((metal.clip(0, 1) * 255).astype(np.uint8), "L").save(os.path.join(a.out_dir, name + "_metal.png"))
Image.fromarray((rough.clip(0, 1) * 255).astype(np.uint8), "L").save(os.path.join(a.out_dir, name + "_rough.png"))

if a.normal_in:
    base = np.asarray(Image.open(a.normal_in).convert("RGB").resize((a.size, a.size), Image.LANCZOS)).astype(np.float32) / 127.5 - 1.0
    lum = np.asarray(im.convert("L")).astype(np.float32) / 255.0
    blur = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    height = lum - blur  # high-pass: joints and grain darker than their surroundings -> grooves
    gy, gx = np.gradient(height)
    g = np.sqrt(gx * gx + gy * gy)
    tilt = np.zeros_like(g)
    for mask, deg in ((stone, 16.0), (wood, 12.0), (cloth, 6.0), (leaf, 8.0)):  # 10/10 검수: stone 12 gave 4.2-4.9/255 shading change (< 5) -> 16
        sel = mask > 0.5
        if sel.sum() > 200:
            p95 = np.percentile(g[sel], 95) + 1e-6
            tilt += mask * (np.tan(np.radians(deg)) / p95)
    dx, dy = gx * tilt, gy * tilt
    # whiteout blend of the base tangent normal and the detail (detail z = 1)
    n = np.stack([base[..., 0] - dx, base[..., 1] + dy, base[..., 2]], -1)  # OpenGL (+Y) map: a dark groove tilts toward its own centre
    n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-6
    Image.fromarray(((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8), "RGB").save(os.path.join(a.out_dir, name + "_normal.png"))

if a.gold_boost > 0:
    hsv2 = hsv.copy()
    hsv2[..., 1] = np.clip(s * (1 + a.gold_boost * gold), 0, 1)
    hsv2[..., 2] = np.clip(v * (1 + a.gold_boost * gold), 0, 1)
    out = Image.fromarray((hsv2 * 255).astype(np.uint8), "HSV").convert("RGB")
    out.save(os.path.join(a.out_dir, name + "_color.png"))

print(f"[pbr_from_color] {name}: gold {gold.mean():.2f} stone {stone.mean():.2f} cloth {cloth.mean():.2f} wood {wood.mean():.2f} leaf {leaf.mean():.2f} glass {glass.mean():.2f}")
