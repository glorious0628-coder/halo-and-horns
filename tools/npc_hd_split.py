"""HD NPC GLB -> Roblox-ready GLB with the mesh's own halo ring split off (이미지 생성 3, 10/14, 최종 검수 NPC rule).

  blender -b --factory-startup --python tools/npc_hd_split.py -- <in.glb> <out.glb> [--thr 0.46]

Tripo HD people carry a thin floating halo ring (faces entirely above --thr in Blender Z, above the hat). Those faces become a
second object <Name>_Halo (same material); everything else stays <Name>. Pivot = bottom centre of the body (halo moved with it).
No shape / colour change, no decimation (A23-154): only a face-set split + axis move. Facing stays glTF +Z (like the *_TU kits).
Absolute paths only (Blender resolves relative ones against C:\).
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
THR = float(a[a.index("--thr") + 1]) if "--thr" in a else 0.46
name = os.path.basename(SRC).replace("_HD_pbr_src.glb", "")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(ob.data)
top = [f for f in bm.faces if min(v.co.z for v in f.verts) > THR]
print("HALO faces", len(top), "of", len(bm.faces))
for f in bm.faces:
    f.select = False
for f in top:
    f.select = True
bm.to_mesh(ob.data)
bm.free()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = max(objs, key=lambda o: len(o.data.polygons))
halo = [o for o in objs if o is not body][0]
body.name, halo.name = name, name + "_Halo"
body.data.name, halo.data.name = name, name + "_Halo"
vs = [v.co for v in body.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
M = Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))
for o in (body, halo):
    o.data.transform(M)
    o.data.update()
hv = [v.co for v in halo.data.vertices]
print("BODY size", tuple(round(x, 4) for x in (hi - lo)), "tris", len(body.data.polygons) * 1, "halo tris", len(halo.data.polygons),
      "halo z", round(min(v.z for v in hv), 3), round(max(v.z for v in hv), 3), "body top", round(max(v.co.z for v in body.data.vertices), 3))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="AUTO", export_yup=True)
print("EXPORTED", OUT, os.path.getsize(OUT))
