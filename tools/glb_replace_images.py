"""
GLB 안의 텍스처 그림을 바꿔 새 GLB로 저장한다(모양·UV는 그대로). 질감 고친 판을 WorldKit에 가져올 때 쓴다.

  py tools/glb_replace_images.py <in.glb> <out.glb> [--base new.png] [--mr new_mr.png] [--normal new_n.png]

- 첫 번째 재질의 baseColor / metallicRoughness / normal 텍스처가 가리키는 그림을 바꾼다(Tripo GLB는 재질 1개).
- PNG는 그대로 넣고, 나머지 버퍼 내용은 순서대로 다시 이어 붙인다(4바이트 정렬).
"""
import argparse
import json
import struct


def read_glb(path):
    b = open(path, "rb").read()
    o, chunks = 12, []
    while o < len(b):
        cl, ct = struct.unpack("<II", b[o:o + 8])
        chunks.append((ct, b[o + 8:o + 8 + cl]))
        o += 8 + cl
    j = json.loads(chunks[0][1])
    binc = next(c for t, c in chunks if t == 0x004E4942)
    return j, binc


def write_glb(path, j, binc):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binc += b"\0" * (-len(binc) % 4)
    total = 12 + 8 + len(js) + 8 + len(binc)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binc), 0x004E4942) + binc)


def replace(in_glb, out_glb, base=None, mr=None, normal=None):
    j, binc = read_glb(in_glb)
    m = j["materials"][0]
    want = {}
    if base:
        want[m["pbrMetallicRoughness"]["baseColorTexture"]["index"]] = base
    if mr:
        pbr = m["pbrMetallicRoughness"]
        if "metallicRoughnessTexture" not in pbr:  # add a new image + texture slot, factors 1 so the map rules
            binc += b"\0" * (-len(binc) % 4)
            j["bufferViews"].append({"buffer": 0, "byteOffset": len(binc), "byteLength": 0})
            j["images"].append({"bufferView": len(j["bufferViews"]) - 1, "mimeType": "image/png"})
            samp = {"sampler": j["textures"][pbr["baseColorTexture"]["index"]]["sampler"]} if "sampler" in j["textures"][pbr["baseColorTexture"]["index"]] else {}
            j["textures"].append(dict(source=len(j["images"]) - 1, **samp))
            pbr["metallicRoughnessTexture"] = {"index": len(j["textures"]) - 1}
            pbr["metallicFactor"] = 1.0
            pbr["roughnessFactor"] = 1.0
        want[pbr["metallicRoughnessTexture"]["index"]] = mr
    if normal:
        want[m["normalTexture"]["index"]] = normal
    new_bytes = {}  # bufferView index -> bytes
    for tex_i, path in want.items():
        img = j["images"][j["textures"][tex_i]["source"]]
        new_bytes[img["bufferView"]] = open(path, "rb").read()
        img["mimeType"] = "image/png" if path.lower().endswith(".png") else "image/jpeg"
    out = bytearray()
    for i, bv in enumerate(j["bufferViews"]):
        data = new_bytes.get(i, binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
        out += b"\0" * (-len(out) % 4)
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(data)
        out += data
    j["buffers"][0]["byteLength"] = len(out)
    write_glb(out_glb, j, bytes(out))
    return len(want)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--base")
    ap.add_argument("--mr")
    ap.add_argument("--normal")
    a = ap.parse_args()
    n = replace(a.inp, a.out, a.base, a.mr, a.normal)
    print(f"[glb_replace_images] {n} image(s) -> {a.out}")
