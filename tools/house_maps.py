"""Pass B of the Halo house parts (이미지 생성 3, 2026-10-10): PBR maps per part from the colour crops of pass A.

  py tools/house_maps.py <work_dir>/<Name> [--gold-hue-min 20]

For every <part>_color.png (+ <part>_tnormal.png, the Tripo normal crop) it runs tools/pbr_from_color.py (검수 10/10 values:
gold metal 0.9 / rough 0.28, stone 16 deg, wood 12 deg, cloth 6 deg, leaf 8 deg; gold colour +12 %) and writes the three
files pass C links into the GLB material:
  <part>_C.png  colour (sRGB)        <part>_N.png  OpenGL tangent normal        <part>_MR.png  G = roughness, B = metal
  <part>_M.png / <part>_R.png  the same metal / roughness as grey maps (SurfaceAppearance upload)
Per-part overrides (materials_redo_list §10): *_Awning = cloth (rough 0.88 except gold rods), *_WinPane = glass (rough 0.06,
no metal), *_Door = wood leaf, no metal; *_DoorHw = gold hardware (pbr mask).
"""
import glob
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.abspath(sys.argv[1])
extra = sys.argv[2:]
for cp in sorted(glob.glob(os.path.join(D, "*_color.png"))):
    part = os.path.basename(cp)[: -len("_color.png")]
    size = Image.open(cp).size[0]
    tmp = os.path.join(D, "_pbr")
    cmd = [sys.executable, os.path.join(ROOT, "tools", "pbr_from_color.py"), cp, tmp, "--name", part, "--size", str(size),
           "--normal-in", os.path.join(D, part + "_tnormal.png"), "--gold-boost", "0.12"] + extra
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout.strip() or r.stderr.strip()[-400:])
    metal = np.asarray(Image.open(os.path.join(tmp, part + "_metal.png"))).astype(np.float32) / 255
    rough = np.asarray(Image.open(os.path.join(tmp, part + "_rough.png"))).astype(np.float32) / 255
    if part.endswith("_Awning"):
        rough = np.where(metal > 0.3, rough, 0.88)
    if part.endswith("_Door"):
        # the wood leaf: no metal (its hardware is the _DoorHw part); light wood reads as gold by colour
        metal = metal * 0
        rough = np.maximum(rough, 0.72)
    if part.endswith("_DoorHw"):
        # hardware faces can carry some wood texels: metal only where the colour is real gold
        hsv = np.asarray(Image.open(cp).convert("HSV")).astype(np.float32)
        hue, sat, val = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
        g = ((hue >= 40) & (hue <= 58) & (sat >= 0.45) & (val >= 0.72)).astype(np.float32)
        metal = metal * g
        rough = np.where(g > 0, rough, np.maximum(rough, 0.72))
    if part.endswith("_Display"):
        metal = metal * 0
        rough = np.maximum(rough, 0.5)
    if part.endswith("_WinPane"):
        metal = metal * 0
        rough = rough * 0 + 0.06
    mr = np.stack([np.zeros_like(rough), rough, metal], -1)
    Image.fromarray((mr * 255).clip(0, 255).astype(np.uint8), "RGB").save(os.path.join(D, part + "_MR.png"))
    # separate grey maps for SurfaceAppearance upload (tools/upload_sa_maps.py: <name>_C/_N/_M/_R.png)
    Image.fromarray((metal * 255).clip(0, 255).astype(np.uint8), "L").save(os.path.join(D, part + "_M.png"))
    Image.fromarray((rough * 255).clip(0, 255).astype(np.uint8), "L").save(os.path.join(D, part + "_R.png"))
    os.replace(os.path.join(tmp, part + "_color.png"), os.path.join(D, part + "_C.png"))
    os.replace(os.path.join(tmp, part + "_normal.png"), os.path.join(D, part + "_N.png"))
print("[house_maps] ok", D)
