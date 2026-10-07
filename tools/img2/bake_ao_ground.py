"""
AO bake with a ground plane (0 credits): like tools/bake_ao.py (shared, unchanged), but a big floor sits under the model
so the bottom gets the soft contact shade a 2D concept paints under a monster. White = open. Use with
tools/tex_color_match.py --ao (A23-73 ④ + AO).

  blender --background --factory-startup --python tools/img2/bake_ao_ground.py -- <in.glb> <out.png> [size=1024] [samples=48] [distance=0.25] [floor_gap=0.0]

- distance = fraction of the model height (longer than bake_ao.py's 0.12-0.15 so the floor shade reaches up the sides).
- floor_gap = how far below the lowest point the floor sits, as a fraction of the height (0 = touching).
- Paths must be absolute or relative to the current folder (they are made absolute here; Blender alone would write a
  bare relative path under C:\\ ).
"""
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
SIZE = int(argv[2]) if len(argv) > 2 else 1024
SAMPLES = int(argv[3]) if len(argv) > 3 else 48
DIST = float(argv[4]) if len(argv) > 4 else 0.25
GAP = float(argv[5]) if len(argv) > 5 else 0.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
height = hi.z - lo.z

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.device = "CPU"
world = bpy.data.worlds.new("W")
scene.world = world
world.light_settings.distance = DIST * height

# the floor: not selected, so it only occludes
bpy.ops.mesh.primitive_plane_add(size=max(hi.x - lo.x, hi.y - lo.y) * 6, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z - GAP * height))
floor = bpy.context.active_object
floor.name = "AOFloor"

img = bpy.data.images.new("AO", SIZE, SIZE, alpha=False, float_buffer=False)
for o in meshes:
    for m in o.data.materials:
        nt = m.node_tree
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        nt.nodes.active = n
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
scene.render.bake.margin = 8
bpy.ops.object.bake(type="AO", margin=8)
img.filepath_raw = OUT
img.file_format = "PNG"
img.save()
print("[bake_ao_ground] ok", OUT, f"height {height:.3f} dist {DIST} gap {GAP}", flush=True)
