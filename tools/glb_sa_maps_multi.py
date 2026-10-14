"""Per-material SurfaceAppearance maps (1024) from a multi-material GLB, e.g. a Blender-assembled Tripo parts model (이미지 생성 3, 10/14).

  py tools/glb_sa_maps_multi.py <out_dir> <in.glb> [--name Halo...] [--mat A:rock,B:...]

For every material k of the GLB: <out_dir>/<Name>_m<k>_{C,N,R,M}.png (base colour, normal, roughness = G of the metallicRoughness
map, metalness = B), 1024 x 1024, RAW (no tuning; tuning = tools/hd_mat_tune.py). Also prints which meshes use which material and
writes <out_dir>/_raw_check.jpg (one row a material: C N R M). Same channel rule as glb_sa_maps.py. Never uploads.
"""
import io
import json
import os
import struct
import sys

from PIL import Image

args = [a for a in sys.argv[1:]]
name = None
if "--name" in args:
    i = args.index("--name"); name = args[i + 1]; del args[i:i + 2]
out, src = args[0], args[1]
name = name or os.path.splitext(os.path.basename(src))[0].replace("_tripo", "")
os.makedirs(out, exist_ok=True)
f = open(src, "rb").read()
jl = struct.unpack("<I", f[12:16])[0]
g = json.loads(f[20:20 + jl])
b0 = 20 + jl + 8


def img(i):
    bv = g["bufferViews"][g["images"][i]["bufferView"]]
    o = b0 + bv.get("byteOffset", 0)
    return Image.open(io.BytesIO(f[o:o + bv["byteLength"]]))


S = (1024, 1024)
use = {}
for mi, m in enumerate(g["meshes"]):
    for p in m["primitives"]:
        use.setdefault(p.get("material", 0), []).append(m.get("name", str(mi)))
tex = lambda t: g["textures"][t["index"]]["source"]  # noqa: E731
rows = []
for k, m in enumerate(g["materials"]):
    pb = m.get("pbrMetallicRoughness", {})
    C = img(tex(pb["baseColorTexture"])).convert("RGB")
    print("[m%d] %s src %dx%d used by %s" % (k, m.get("name"), C.size[0], C.size[1], use.get(k)))
    C = C.resize(S, Image.LANCZOS)
    N = img(tex(m["normalTexture"])).convert("RGB").resize(S, Image.LANCZOS) if "normalTexture" in m else Image.new("RGB", S, (128, 128, 255))
    _, R, M = img(tex(pb["metallicRoughnessTexture"])).convert("RGB").split()
    R, M = R.resize(S, Image.LANCZOS), M.resize(S, Image.LANCZOS)
    for t, im in (("C", C), ("N", N), ("R", R), ("M", M)):
        im.save(os.path.join(out, "%s_m%d_%s.png" % (name, k, t)))
    rows.append([C, N, R.convert("RGB"), M.convert("RGB")])
T = 300
sheet = Image.new("RGB", (4 * (T + 4), len(rows) * (T + 4)), (40, 40, 40))
for r, row in enumerate(rows):
    for c, im in enumerate(row):
        t = im.copy(); t.thumbnail((T, T)); sheet.paste(t, (c * (T + 4), r * (T + 4)))
sheet.save(os.path.join(out, "_raw_check.jpg"), quality=88)
