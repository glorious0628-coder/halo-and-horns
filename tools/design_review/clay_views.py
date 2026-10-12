"""Clay views of Tripo white models for the white-model gate (front = +X like tools/white_model_sheet.py).
blender --background --factory-startup --python pot_views.py -- <out_dir> <file.fbx> ...
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out_dir = a[0]
os.makedirs(out_dir, exist_ok=True)
VIEWS = [("f", 0, 0.25), ("r45", 45, 0.35), ("s90", 90, 0.25), ("b", 180, 0.25), ("s270", 270, 0.25),
         ("top", 0, 1.3), ("low", 135, -0.5)]
for path in a[1:]:
    label = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in obs:
        for p in o.data.polygons:
            p.use_smooth = True
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr, size = (lo + hi) / 2, max(hi - lo)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "SINGLE"
    sh.single_color = (0.85, 0.85, 0.85)
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_backface_culling = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.30, 0.31, 0.33)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = sc.render.resolution_y = 700
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.08
    for name, az, el in VIEWS:
        d = Vector((math.cos(math.radians(az)), math.sin(math.radians(az)), el)).normalized()
        cam.location = ctr + d * size * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, f"{label}__{name}.png")
        bpy.ops.render.render(write_still=True)
    print("DONE", label, sum(len(o.data.polygons) for o in obs), [round(v, 3) for v in (hi - lo)])
