"""Build the ore-free slime body + patched textures (0 credits).  py tools/slime_noore_build.py

1. UV coverage of the back-fixed mesh -> a free 56x56 texel block in the atlas.
2. blender_slime_noore.py: remove the ore, fill + relax the top, the filling's UV = that block; ring UVs written for colours.
3. Paint the block with each texture's own top colour (median of the texels just outside the hole): green (colorfix), blue
   (Prince, colorfix) and the embedded one -> art/models/tripo/Tex_*_noore.png (4096 embedded is saved 1024).
4. Export the E8 GLB (embedded texture = patched) named SlimePrinceBody3.
The in-game bodies keep their TextureID: only the patched PNGs (green / blue) need uploading (imgdev) and swapping (메인 반영).
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BL = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"
SRC = ROOT / "art/models/tripo/MonsterSlimeCube_backfix.glb"
TMP = ROOT / "build/retex"
TMP.mkdir(parents=True, exist_ok=True)


def blender(script, *args):
    r = subprocess.run([BL, "--background", "--factory-startup", "--python", str(ROOT / script), "--", *map(str, args)],
                       capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    for line in out.splitlines():
        if any(k in line for k in ("faces", "fill uv", "top texels", "Error", "Traceback")):
            print("  [blender]", line)
    return out


# 1. free block
blender("tools/blender_slime_backuv.py", SRC, TMP / "slime_all_uv.json", 99)
tris = json.load(open(TMP / "slime_all_uv.json"))
W = 1024
mask = Image.new("L", (W, W), 0)
d = ImageDraw.Draw(mask)
for t in tris:
    d.polygon([(u * W, (1 - v) * W) for u, v in t], fill=255)
from PIL import ImageFilter
m = np.asarray(mask.filter(ImageFilter.MaxFilter(13))) > 0
B = 56
best = None
for y in range(W - B, -1, -8):
    for x in range(W - B, -1, -8):
        if not m[y:y + B, x:x + B].any():
            best = (x, y)
            break
    if best:
        break
assert best, "no free texture block"
bx, by = best
patch_uv = ((bx + B / 2) / W, 1 - (by + B / 2) / W, (B - 4) / W)
print("free block", best, "uv", patch_uv)

# 2. mesh
out_glb = ROOT / "art/models/tripo/MonsterSlimeCube_noore.glb"
blender("tools/blender_slime_noore.py", SRC, TMP / "noore_tmp.glb", "--patch-uv", f"{patch_uv[0]},{patch_uv[1]},{patch_uv[2]}", "--ring-json", TMP / "ring.json")
ring = json.load(open(TMP / "ring.json"))


# 3. textures
CC, MAPR = (0.03, 0.15), 0.21 * 1.05


def patched(src_png, dst_png):
    """Paint the free block as an inverse-distance blend of the body-top texels round the hole (planar x, y map)."""
    im = Image.open(src_png).convert("RGB")
    w, h = im.size
    a = np.asarray(im).astype(float)
    pts, cols = [], []
    for u, v, x, y in ring:
        px_, py_ = min(w - 1, int(u * w)), min(h - 1, int((1 - v) * h))
        pts.append((x, y))
        cols.append(a[py_, px_])
    pts, cols = np.array(pts), np.array(cols)
    px0, py0 = int(bx / W * w), int(by / W * h)
    bw = int(B / W * w)
    inner = int((B - 4) / W * w)
    off = (bw - inner) // 2
    for j in range(bw):
        for i in range(bw):
            # the block's inner square maps to x, y in [CC - MAPR, CC + MAPR]; the 2 texel border repeats the edge colour
            ii, jj = min(max(i - off, 0), inner - 1), min(max(j - off, 0), inner - 1)
            x = CC[0] + (ii / (inner - 1) - 0.5) * 2 * MAPR
            y = CC[1] + (0.5 - jj / (inner - 1)) * 2 * MAPR  # image y grows down, v up
            dd = np.sqrt(((pts - (x, y)) ** 2).sum(axis=1)) + 1e-4
            idx = np.argsort(dd)[:20]
            wgt = 1.0 / dd[idx] ** 2.5
            a[py0 + j, px0 + i] = (cols[idx] * wgt[:, None]).sum(axis=0) / wgt.sum()
    Image.fromarray(a.astype(np.uint8)).save(dst_png)
    return cols.mean(axis=0)


tdir = ROOT / "art/models/tripo"
mg = patched(tdir / "MonsterSlimeCube_tex_colorfix.png", tdir / "MonsterSlimeCube_tex_colorfix_noore.png")
mb = patched(tdir / "BigSlimeCube_tex_blue_colorfix.png", tdir / "BigSlimeCube_tex_blue_colorfix_noore.png")
print("top colours green", mg.round(), "blue", mb.round())

# 4. E8 glb with the green patched texture embedded (the import preview)
blender("tools/blender_slime_noore.py", SRC, out_glb, "--patch-uv", f"{patch_uv[0]},{patch_uv[1]},{patch_uv[2]}", "--tex",
        tdir / "MonsterSlimeCube_tex_colorfix_noore.png")
blender("tools/blender_slime_noore.py", SRC, ROOT / "build/import_all/5_fifth/E8_SlimePrinceBody.glb", "--patch-uv",
        f"{patch_uv[0]},{patch_uv[1]},{patch_uv[2]}", "--tex", tdir / "MonsterSlimeCube_tex_colorfix_noore.png", "--name", "SlimePrinceBody3")
print("done")
