"""White-model gate, every side (user 10/13: look at top, bottom, front, back, both sides).
Renders per FBX: f, b, s90, s270, top (straight down), bottom (straight up), q34 — clay, no backface culling
(holes show as see-through), then one sheet per object: rows = candidates, columns = views.
blender --background --factory-startup --python wm_six.py -- <out_dir> <sheet.jpg> <file.fbx> ...
front = +X (raw Tripo FBX).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out, sheet = os.path.abspath(a[0]), os.path.abspath(a[1])
os.makedirs(out, exist_ok=True)
VIEWS = [("f", Vector((1, 0, 0.001))), ("s90", Vector((0, 1, 0.001))), ("b", Vector((-1, 0, 0.001))),
         ("s270", Vector((0, -1, 0.001))), ("top", Vector((0.001, 0, 1))), ("bottom", Vector((0.001, 0, -1))),
         ("q34", Vector((0.7, -0.7, 0.6)))]
PX = 500
labels = []
for path in a[2:]:
    label = os.path.splitext(os.path.basename(path))[0]
    labels.append(label)
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
    sh.show_backface_culling = False
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.12, 0.12, 0.14)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = sc.render.resolution_y = PX
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.1
    for name, d in VIEWS:
        d = d.normalized()
        cam.location = ctr + d * size * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out, f"{label}__{name}.png")
        bpy.ops.render.render(write_still=True)
    print("DONE", label)

# sheet (Blender's bundled Python has no PIL: build it with bpy images)
W, H = PX * len(VIEWS), PX * len(labels)
img = bpy.data.images.new("sheet", W, H)
buf = [0.0] * (W * H * 4)
for r, label in enumerate(labels):
    for c, (name, _) in enumerate(VIEWS):
        t = bpy.data.images.load(os.path.join(out, f"{label}__{name}.png"))
        tp = t.pixels[:]
        y0 = (len(labels) - 1 - r) * PX
        for y in range(PX):
            src = y * PX * 4
            dst = ((y0 + y) * W + c * PX) * 4
            buf[dst:dst + PX * 4] = tp[src:src + PX * 4]
        bpy.data.images.remove(t)
img.pixels[:] = buf
img.filepath_raw = sheet
img.file_format = "JPEG"
img.save()
print("SHEET", sheet, "rows:", labels, "cols:", [v[0] for v in VIEWS])
