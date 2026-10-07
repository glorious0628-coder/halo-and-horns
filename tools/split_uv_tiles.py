"""
큰 모델(성 등)을 텍스처 칸으로 나눠 조각마다 1024 텍스처를 준다 — Roblox는 텍스처를 1024까지만 써서, 70스터드 성 전체에
1024 한 장이면 가까이서 흐리다. N×N 칸으로 나누면 선명도가 N배(4K 원본이 있을 때).

  blender --background --factory-startup --python-exit-code 1 --python tools/split_uv_tiles.py -- <in.glb> <out.glb> <name>
          [--grid 3] [--tex 4k_base.png] [--kind tripo|web] [--fit h|z|max studs] [--pad 0.02] [--size 1024]

- 면마다 UV 중심이 들어간 칸에 넣고, 칸마다 그 칸 면들의 UV 상자(+여유)를 원본 텍스처에서 잘라 1024로 만든다.
- 조각 = 따로 된 메시 오브젝트 <name>_t<행><열>(재질 1개씩) → Roblox 3D 가져오기에서 MeshPart 여러 개인 Model 하나.
- 방향·크기는 worldkit_combine.py와 같은 규칙: tripo(API) 앞 = +X → 90도, web 앞 = -Y → 180도 돌려 앞 = +Y(Roblox -Z),
  fit으로 스터드 크기, 밑면 가운데가 원점.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT, NAME = argv[0], os.path.abspath(argv[1]), argv[2]
opt = {"grid": "3", "tex": None, "kind": "tripo", "fit": None, "pad": "0.02", "size": "1024"}
i = 3
while i < len(argv):
    k = argv[i][2:]
    if k == "fit":
        opt["fit"] = (argv[i + 1], float(argv[i + 2]))
        i += 3
        continue
    opt[k] = argv[i + 1]
    i += 2
N, PAD, SIZE = int(opt["grid"]), float(opt["pad"]), int(opt["size"])
OUTDIR = os.path.splitext(OUT)[0] + "_tiles"
os.makedirs(OUTDIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(IN))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active

# source texture (4K if given, else the base colour image in the GLB)
mat0 = obj.data.materials[0]
img_node = None
for n in mat0.node_tree.nodes:
    if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
        img_node = n
src = bpy.data.images.load(os.path.abspath(opt["tex"])) if opt["tex"] else img_node.image
W, H = src.size
px = np.array(src.pixels[:], dtype=np.float32).reshape(H, W, src.channels)[::-1]  # top row first
print("source texture", W, H)

# orientation + size
turn = math.radians(90) if opt["kind"] == "tripo" else math.radians(180)
obj.matrix_world = Matrix.Rotation(turn, 4, "Z") @ obj.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def box():
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


if opt["fit"]:
    lo, hi = box()
    d = hi - lo
    dim = {"h": max(d.x, d.y), "z": d.z, "max": max(d.x, d.y, d.z)}[opt["fit"][0]]
    s = opt["fit"][1] / max(dim, 1e-6)
    obj.matrix_world = Matrix.Diagonal((s, s, s, 1.0)) @ obj.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
lo, hi = box()
obj.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))

# assign faces to tiles by UV centroid
me = obj.data
uvl = me.uv_layers.active.data
tile_of = []
for poly in me.polygons:
    us = [uvl[li].uv for li in poly.loop_indices]
    cu = sum(u.x for u in us) / len(us)
    cv = sum(u.y for u in us) / len(us)
    ti = min(N - 1, max(0, int(cu * N)))
    tj = min(N - 1, max(0, int(cv * N)))
    tile_of.append(tj * N + ti)
tile_of = np.array(tile_of)

# per tile: UV box of its faces (+pad), crop the source, new material, remap UVs
me.materials.clear()
info = []
for t in range(N * N):
    faces = np.nonzero(tile_of == t)[0]
    if len(faces) == 0:
        continue
    us, vs = [], []
    for fi in faces:
        for li in me.polygons[fi].loop_indices:
            us.append(uvl[li].uv.x)
            vs.append(uvl[li].uv.y)
    u0, u1 = max(0.0, min(us) - PAD / N), min(1.0, max(us) + PAD / N)
    v0, v1 = max(0.0, min(vs) - PAD / N), min(1.0, max(vs) + PAD / N)
    # crop in pixel space (v up in Blender UV, row 0 = top in px)
    x0, x1 = int(math.floor(u0 * W)), int(math.ceil(u1 * W))
    y0, y1 = int(math.floor((1 - v1) * H)), int(math.ceil((1 - v0) * H))
    crop = px[y0:y1, x0:x1]
    # resize to SIZE x SIZE (area average when shrinking)
    info.append((t, len(faces), (x1 - x0, y1 - y0)))
    tile_name = f"{NAME}_t{t // N}{t % N}"
    img = bpy.data.images.new(tile_name, SIZE, SIZE, alpha=False)
    # simple resample with numpy (box filter then nearest to SIZE)
    ys = np.linspace(0, crop.shape[0], SIZE + 1).astype(int)
    xs = np.linspace(0, crop.shape[1], SIZE + 1).astype(int)
    csum = np.cumsum(np.cumsum(np.pad(crop[..., :3], ((1, 0), (1, 0), (0, 0))), 0), 1)
    A = csum[ys[1:]][:, xs[1:]] - csum[ys[:-1]][:, xs[1:]] - csum[ys[1:]][:, xs[:-1]] + csum[ys[:-1]][:, xs[:-1]]
    cnt = ((ys[1:] - ys[:-1])[:, None] * (xs[1:] - xs[:-1])[None, :]).astype(np.float32)[..., None]
    out = A / np.maximum(cnt, 1)
    rgba = np.concatenate([out, np.ones(out.shape[:2] + (1,), np.float32)], -1)[::-1]
    img.pixels = rgba.ravel()
    img.filepath_raw = os.path.join(OUTDIR, tile_name + ".png")
    img.file_format = "PNG"
    img.save()
    m = bpy.data.materials.new(tile_name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    tn = m.node_tree.nodes.new("ShaderNodeTexImage")
    tn.image = img
    m.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Metallic"].default_value = 0.0
    me.materials.append(m)
    slot = len(me.materials) - 1
    for fi in faces:
        poly = me.polygons[fi]
        poly.material_index = slot
        for li in poly.loop_indices:
            u, v = uvl[li].uv
            uvl[li].uv = ((u - u0) / max(u1 - u0, 1e-6), (v - v0) / max(v1 - v0, 1e-6))
print("tiles", [(t, nf, wh) for t, nf, wh in info])

# separate by material -> one object per tile
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")
for o in bpy.context.scene.objects:
    if o.type == "MESH" and o.data.materials:
        o.name = o.data.materials[0].name
        o.data.name = o.name
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_image_format="AUTO",
                          export_animations=False, export_skins=False)
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in bpy.context.scene.objects:
    for c in o.bound_box:
        p = o.matrix_world @ Vector(c)
        lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
        hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
print("[split_uv_tiles] ok", OUT, "parts", len([o for o in bpy.context.scene.objects if o.type == "MESH"]),
      "size_studs", [round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)], flush=True)
