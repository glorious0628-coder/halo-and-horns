"""Smooth the shading of the slime body mesh (0 credits): weld the UV-seam split vertices, drop the Tripo split normals and
shade smooth by angle, then a weighted-normal pass, so the face (eyes, cheeks) has no triangle creases. Silhouette, size and
UVs stay the same (positions untouched).

  blender --background --factory-startup --python tools/blender_slime_smooth.py -- <in.glb> <out.glb> [--name NAME] [--angle 75]
"""
import math
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], argv[1]
NAME = argv[argv.index("--name") + 1] if "--name" in argv else None
ANGLE = float(argv[argv.index("--angle") + 1]) if "--angle" in argv else 75.0
TEX = argv[argv.index("--tex") + 1] if "--tex" in argv else None  # replace the embedded texture (the cleaned in-game one)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
print("custom normals before:", me.has_custom_normals, "verts", len(me.vertices))
# weld the split vertices (UVs are per loop and stay)
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
bm.to_mesh(me)
bm.free()
me.update()
# drop the baked split normals
try:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
except Exception as e:
    print("clear normals:", e)
for p in me.polygons:
    p.use_smooth = True
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(ANGLE))
except Exception as e:
    print("smooth by angle:", e)
wn = obj.modifiers.new("wn", "WEIGHTED_NORMAL")
wn.keep_sharp = True
wn.weight = 60
wn.mode = "FACE_AREA"
bpy.ops.object.modifier_apply(modifier="wn")
print("custom normals after:", me.has_custom_normals)
if TEX:
    newim = bpy.data.images.load(TEX)
    for m in me.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.image = newim
if NAME:
    obj.name = NAME
    me.name = NAME
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="AUTO", export_apply=True, export_normals=True)
print("wrote", OUT)
