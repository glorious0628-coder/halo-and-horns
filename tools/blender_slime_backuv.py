"""List the UV triangles of the slime cube's BACK half (raw x < XB), to paint the baked eye / cheek marks out of the texture.

  blender --background --factory-startup --python tools/blender_slime_backuv.py -- <in.glb> <out.json> [x_back_max=-0.02]
"""
import json
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], argv[1]
XB = float(argv[2]) if len(argv) > 2 else -0.02
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
o = [x for x in bpy.context.scene.objects if x.type == "MESH"][0]
me = o.data
uv = me.uv_layers.active
tris = []
for p in me.polygons:
    if p.center.x < XB:
        tris.append([(uv.data[l].uv.x, uv.data[l].uv.y) for l in p.loop_indices])
json.dump(tris, open(OUT, "w"))
print("back faces", len(tris), "of", len(me.polygons))
