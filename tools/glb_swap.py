"""Swap objects in a GLB for the same-named ones from another GLB (이미지 생성 3, 10/12; tools/house_deco_run.py --lantern-only).

  blender --background --factory-startup --python tools/glb_swap.py -- <base.glb> <new.glb> <name part>

Objects of <base.glb> whose name contains <name part> are removed, the objects of <new.glb> whose name contains it are put
in their place (their own materials / maps), and <base.glb> is written back. Transforms are baked into the meshes.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, NEW, PART = argv
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
gone = [o.name for o in bpy.context.scene.objects if o.type == "MESH" and PART in o.name]
for n in gone:
    bpy.data.objects.remove(bpy.data.objects[n])
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=NEW)
added = []
for o in list(bpy.data.objects):
    if o in before:
        continue
    if o.type == "MESH" and PART in o.name:
        added.append(o.name)
    else:
        bpy.data.objects.remove(o)
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        o.data.transform(o.matrix_world)
        o.matrix_world.identity()
        o.parent = None
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=BASE, export_format="GLB", use_selection=True, export_animations=False)
print("[swap] removed %s, added %s -> %s" % (gone, added, BASE), flush=True)
