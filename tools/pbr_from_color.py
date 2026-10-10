"""Metalness + roughness maps from a colour texture by colour masks (이미지 생성 1, 2026-10-10, A23-107 재질).

  py tools/pbr_from_color.py <color.png> <out_dir> [--name N] [--size 1024]

Tripo's own metal maps rendered stylized props chrome-grey (2026-10-08), so the shine comes from simple colour rules instead:
- gold / brass (yellow-orange hue, saturated, bright)  -> metal 1.0, roughness 0.18 (mirror-like gold)
- silver armour (light, unsaturated, cool)             -> left non-metal (white marble walls look the same in colour)
- white / cream stone and marble                       -> metal 0, roughness 0.62
- blue / coloured cloth (banners, awnings)             -> metal 0, roughness 0.85
- wood / brown                                         -> metal 0, roughness 0.78
- green leaves                                         -> metal 0, roughness 0.8
- glass / bright light-blue windows                    -> metal 0, roughness 0.12
Masks are softened (3 px blur) so seams between materials do not alias. Writes <N>_metal.png and <N>_rough.png (8-bit grey).
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
a = ap.parse_args()

name = a.name or os.path.splitext(os.path.basename(a.color))[0]
im = Image.open(a.color).convert("RGB")
if im.size != (a.size, a.size):
    im = im.resize((a.size, a.size), Image.LANCZOS)
hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]


def soft(mask):
    m = Image.fromarray((mask.astype(np.float32) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))
    return np.asarray(m).astype(np.float32) / 255.0


gold = soft((h >= 30) & (h <= 58) & (s >= 0.5) & (v >= 0.55))
wood = soft((h >= 12) & (h < 40) & (s >= 0.35) & (v < 0.62)) * (1 - gold)
leaf = soft((h >= 70) & (h <= 160) & (s >= 0.25)) * (1 - gold)
glass = soft((h >= 185) & (h <= 215) & (s >= 0.18) & (s < 0.45) & (v >= 0.85)) * (1 - gold)
cloth = soft((s >= 0.3) & ~((h >= 28) & (h <= 58))) * (1 - gold - wood - leaf - glass).clip(0, 1)
stone = (1 - gold - wood - leaf - glass - cloth).clip(0, 1)

metal = gold
rough = gold * 0.18 + wood * 0.78 + leaf * 0.8 + glass * 0.12 + cloth * 0.85 + stone * 0.62
os.makedirs(a.out_dir, exist_ok=True)
Image.fromarray((metal.clip(0, 1) * 255).astype(np.uint8), "L").save(os.path.join(a.out_dir, name + "_metal.png"))
Image.fromarray((rough.clip(0, 1) * 255).astype(np.uint8), "L").save(os.path.join(a.out_dir, name + "_rough.png"))
print(f"[pbr_from_color] {name}: gold {gold.mean():.2f} stone {stone.mean():.2f} cloth {cloth.mean():.2f} wood {wood.mean():.2f} leaf {leaf.mean():.2f} glass {glass.mean():.2f}")
