"""
GLB의 UV에 AO(주변 가림, 흰 = 트임)를 구워 PNG로 저장한다. tex_color_match.py --ao 와 함께 쓴다(0 크레딧).

  blender --background --factory-startup --python tools/bake_ao.py -- <in.glb> <out.png> [size=1024] [samples=64] [distance=0.15]

- distance는 모델 높이를 1로 볼 때의 비율(둥근 덩어리 사이 그늘 정도만 잡게 짧게).
"""
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT = argv[0], os.path.abspath(argv[1])
SIZE = int(argv[2]) if len(argv) > 2 else 1024
SAMPLES = int(argv[3]) if len(argv) > 3 else 64
DIST = float(argv[4]) if len(argv) > 4 else 0.15

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
height = max(p.z for p in pts) - min(p.z for p in pts)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.device = "CPU"
world = bpy.data.worlds.new("W")
scene.world = world
world.light_settings.distance = DIST * height

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
print("[bake_ao] ok", OUT, flush=True)
