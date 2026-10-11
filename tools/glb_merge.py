"""Merge GLBs into one (one Studio import = one user click), 이미지 생성 3, 10/11.

  blender --background --factory-startup --python tools/glb_merge.py -- <out.glb> <in.glb> [<in.glb> ...]

Objects keep their names, transforms are baked in; prints the object list and total triangles.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
out, ins = argv[0], argv[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
for g in ins:
    bpy.ops.import_scene.gltf(filepath=g)
tris = 0
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    o.data.transform(o.matrix_world)
    o.matrix_world.identity()
    o.parent = None
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
    print("[merge] %-40s %6d" % (o.name, len(o.data.loop_triangles)), flush=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False)
print("[merge] ok %d tris -> %s" % (tris, out), flush=True)
