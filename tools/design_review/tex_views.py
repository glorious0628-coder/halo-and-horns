"""Texture-colour views of Tripo textured FBX (front = +X). Flat light = the colour map as painted.
blender --background --factory-startup --python tex_views.py -- <out_dir> <px> <file.fbx> ...
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out_dir, px = a[0], int(a[1])
os.makedirs(out_dir, exist_ok=True)
VIEWS = [("f", 0, 0.15), ("r45", 45, 0.3), ("s90", 90, 0.15), ("b", 180, 0.15), ("s270", 270, 0.15),
         ("t34", 315, 1.0), ("top", 0, 8.0)]
for path in a[2:]:
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
    ctr, size = (lo + hi) / 2, (hi - lo).length
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "TEXTURE"
    sh.show_backface_culling = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.62, 0.64, 0.67)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = sc.render.resolution_y = px
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 0.92
    for name, az, el in VIEWS:
        d = Vector((math.cos(math.radians(az)), math.sin(math.radians(az)), el)).normalized()
        cam.location = ctr + d * size * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, f"{label}__{name}.png")
        bpy.ops.render.render(write_still=True)
    imgs = [i.name + ":" + "x".join(map(str, i.size)) for i in bpy.data.images]
    print("DONE", label, imgs)
