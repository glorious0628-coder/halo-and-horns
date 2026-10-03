"""
GLB를 정면에서 평면 조명으로 찍는다 (얼굴 보정 전/후 비교용).

  blender --background --factory-startup --python tools/render_front.py -- <in.glb> <out.png> [z_from_frac] [z_to_frac]
"""

import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT_PNG = argv[0], argv[1]
F0 = float(argv[2]) if len(argv) > 2 else 0.0
F1 = float(argv[3]) if len(argv) > 3 else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
pts = []
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        pts += [o.matrix_world @ v.co for v in o.data.vertices]
zmin = min(p.z for p in pts); zmax = max(p.z for p in pts)
xmin = min(p.x for p in pts); xmax = max(p.x for p in pts)
H = zmax - zmin
z0, z1 = zmin + F0 * H, zmin + F1 * H

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.background_type = "VIEWPORT"
scene.display.shading.background_color = (0.85, 0.85, 0.85)
cam_data = bpy.data.cameras.new("Cam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam)
cam_data.ortho_scale = max(z1 - z0, xmax - xmin if F0 == 0 else 0) * 1.1
cam.location = ((xmin + xmax) / 2, -10, (z0 + z1) / 2)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.filepath = OUT_PNG
bpy.ops.render.render(write_still=True)
print("[render_front] ok", OUT_PNG, flush=True)
