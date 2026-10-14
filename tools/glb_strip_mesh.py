"""Mesh-only copy of GLB files for the Studio 3D importer (이미지 생성 3, 10/13).

  py tools/glb_strip_mesh.py <out_dir> <a.glb> [<b.glb> ...] [--part-names]

Keeps only POSITION / NORMAL / TEXCOORD_0 / indices of every primitive (one node per primitive, names from the source
mesh), drops images / materials, so the importer uploads a small mesh and no 8K texture (the maps go up separately as
SurfaceAppearance through tools/upload_sa_maps.py). Axes and pivot stay as in the source. Writes <out_dir>/<same name>.glb.
Why: AssetService:CreateAssetAsync is "not available yet" in our Studio (10/12, 10/13), so a mesh asset needs one 3D import
by the user (최종 검수 batches them: statue, fountain, flower pots ...).
"""
import json
import os
import struct
import sys

# --part-names: node name = <file>_p<NN>_m<material index> (multi-material assembled models: each MeshPart can find its
# SurfaceAppearance set after the import; 이미지 생성 3, 10/14). Without it all nodes carry the file name (one material).
PART_NAMES = "--part-names" in sys.argv
ARGV = [a for a in sys.argv if a != "--part-names"]
out_dir = ARGV[1]
os.makedirs(out_dir, exist_ok=True)
for src in ARGV[2:]:
    f = open(src, "rb").read()
    jl = struct.unpack("<I", f[12:16])[0]
    g = json.loads(f[20:20 + jl])
    b0 = 20 + jl + 8
    binb, bvs, accs, meshes, nodes = bytearray(), [], [], [], []

    def take(i):
        ac = dict(g["accessors"][i])
        bv = g["bufferViews"][ac["bufferView"]]
        o = b0 + bv.get("byteOffset", 0)
        data = f[o:o + bv["byteLength"]]
        while len(binb) % 4:
            binb.append(0)
        nbv = {"buffer": 0, "byteOffset": len(binb), "byteLength": len(data)}
        for k in ("byteStride", "target"):
            if k in bv:
                nbv[k] = bv[k]
        binb.extend(data)
        bvs.append(nbv)
        ac["bufferView"] = len(bvs) - 1
        accs.append(ac)
        return len(accs) - 1

    for m in g["meshes"]:
        for j, p in enumerate(m["primitives"]):
            at = {k: take(p["attributes"][k]) for k in ("POSITION", "NORMAL", "TEXCOORD_0") if k in p["attributes"]}
            meshes.append({"name": m.get("name", "mesh"), "primitives": [{"attributes": at, "indices": take(p["indices"]), "mode": 4}]})
            base = os.path.splitext(os.path.basename(src))[0]
            nm = ("%s_p%02d_m%d" % (base, len(nodes), p.get("material", 0))) if PART_NAMES else "%s%s" % (base, "" if j == 0 else "_%d" % j)
            nodes.append({"name": nm, "mesh": len(meshes) - 1})
    while len(binb) % 4:
        binb.append(0)
    ng = {"asset": {"version": "2.0", "generator": "glb_strip_mesh"}, "scene": 0, "scenes": [{"nodes": list(range(len(nodes)))}],
          "nodes": nodes, "meshes": meshes, "accessors": accs, "bufferViews": bvs, "buffers": [{"byteLength": len(binb)}]}
    js = json.dumps(ng).encode()
    while len(js) % 4:
        js += b" "
    body = struct.pack("<I", len(js)) + b"JSON" + js + struct.pack("<I", len(binb)) + b"BIN\0" + bytes(binb)
    dst = os.path.join(out_dir, os.path.basename(src))
    open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)
    print("[strip] %s -> %s (%.2f MB, %d primitives)" % (src, dst, os.path.getsize(dst) / 1e6, len(nodes)))
