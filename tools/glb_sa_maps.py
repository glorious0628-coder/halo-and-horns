"""SurfaceAppearance maps (1024) from a touched-up Tripo GLB (이미지 생성 3, 10/13).

  py tools/glb_sa_maps.py <out_dir> <a.glb> [<b.glb> ...] [--raw]

For each GLB (one material, glTF PBR): <out_dir>/<Name>_C.png (base colour), _N.png (normal), _R.png (roughness = G of the
metallicRoughness map), _M.png (metalness = B), 1024 x 1024; Name = the file name without "_TU". Unless --raw, the matte
rule used for the Halo flower pots (10/13): where metalness < 0.5 the part is not gold -> metalness 0 and roughness at least
0.6 (2D concepts are matte except the gold; Tripo PBR put 0.3 metal on leaves and near-0 roughness on petals); gold keeps
its maps. Writes <out_dir>/_check.jpg (one row a model: C N R M) to view before upload (AGENTS.md hard rule 1).
Upload: py tools/upload_sa_maps.py <out_dir> --names <Name,...> --tags CNMR (MCP upload_image, batches of 10).
"""
import io
import json
import os
import struct
import sys

from PIL import Image

args = [a for a in sys.argv[1:] if not a.startswith("--")]
raw = "--raw" in sys.argv
out = args[0]
os.makedirs(out, exist_ok=True)
rows = []
for src in args[1:]:
    f = open(src, "rb").read()
    jl = struct.unpack("<I", f[12:16])[0]
    g = json.loads(f[20:20 + jl])
    b0 = 20 + jl + 8

    def img(i):
        bv = g["bufferViews"][g["images"][i]["bufferView"]]
        o = b0 + bv.get("byteOffset", 0)
        return Image.open(io.BytesIO(f[o:o + bv["byteLength"]]))

    if len(g.get("materials", [])) != 1:
        print("[sa] %s: %d materials - first one only" % (src, len(g.get("materials", []))))
    m = g["materials"][0]
    pb = m.get("pbrMetallicRoughness", {})
    tex = lambda t: g["textures"][t["index"]]["source"]  # noqa: E731
    name = os.path.splitext(os.path.basename(src))[0].replace("_TU", "")
    S = (1024, 1024)
    C = img(tex(pb["baseColorTexture"])).convert("RGB").resize(S, Image.LANCZOS)
    N = img(tex(m["normalTexture"])).convert("RGB").resize(S, Image.LANCZOS) if "normalTexture" in m else Image.new("RGB", S, (128, 128, 255))
    if "metallicRoughnessTexture" in pb:
        _, R, M = img(tex(pb["metallicRoughnessTexture"])).convert("RGB").split()
        R, M = R.resize(S, Image.LANCZOS), M.resize(S, Image.LANCZOS)
    else:
        R = Image.new("L", S, int(255 * pb.get("roughnessFactor", 1.0)))
        M = Image.new("L", S, int(255 * pb.get("metallicFactor", 0.0)))
    if not raw:
        gold = M.point(lambda v: 255 if v >= 128 else 0)
        M = Image.composite(M, Image.new("L", S, 0), gold)
        R = Image.composite(R, R.point(lambda v: max(v, 153)), gold)
    for t, im in (("C", C), ("N", N), ("R", R), ("M", M)):
        im.save(os.path.join(out, "%s_%s.png" % (name, t)))
    print("[sa] %s -> %s_{C,N,R,M}.png, doubleSided %s" % (src, name, m.get("doubleSided")))
    rows.append([C, N, R.convert("RGB"), M.convert("RGB")])
T = 220
sheet = Image.new("RGB", (4 * (T + 4), len(rows) * (T + 4)), (40, 40, 40))
for r, row in enumerate(rows):
    for c, im in enumerate(row):
        t = im.copy()
        t.thumbnail((T, T))
        sheet.paste(t, (c * (T + 4), r * (T + 4)))
sheet.save(os.path.join(out, "_check.jpg"), quality=85)
