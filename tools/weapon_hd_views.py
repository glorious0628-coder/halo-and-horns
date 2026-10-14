"""4-view renders of a raw Tripo HD weapon GLB for the 무기 디자인 judge sheet (10/14, A23-187).

Even light-box light (white world, no lamps), Cycles, transparent film. Long axis is vertical in the image.
Views: the 4 horizontal directions around the long axis (+X, -X, +Y, -Y), named by axis; the sheet tool
(tools/weapon_hd_sheet.py) matches them to the 2D front/left/right/back. Also a 3/4 view from above.

  blender --background --factory-startup --python tools/weapon_hd_views.py -- <in.glb> <out_prefix> [--px 1000]
  -> <out_prefix>_{px,nx,py,ny,q34}.png (RGBA) + _info.json (tris, size, long axis)
"""
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
import os
glb, pre = os.path.abspath(a[0]), os.path.abspath(a[1])
px = int(a[a.index("--px") + 1]) if "--px" in a else 1000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
tris = 0
for o in obs:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
W = np.array([(o.matrix_world @ v.co)[:] for o in obs for v in o.data.vertices])
lo, hi = W.min(0), W.max(0)
span = hi - lo
ctr = Vector(((lo + hi) / 2).tolist())
long_ax = int(np.argmax(span))
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (1, 1, 1, 1)
bg.inputs[1].default_value = 1.0
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
L = float(span[long_ax])
R = float(np.linalg.norm(span)) * 2 + 1
up = Vector((0, 0, 0))
up[long_ax] = 1.0
others = [i for i in range(3) if i != long_ax]
dirs = {}
for i in others:
    for s, nm in ((1, "p"), (-1, "n")):
        d = Vector((0, 0, 0))
        d[i] = s
        dirs[nm + "xyz"[i]] = d
q = Vector((0, 0, 0))
q[others[0]] = 1
q[others[1]] = 1
q[long_ax] = 0.8
dirs["q34"] = q.normalized()


def look(d):
    cam.location = ctr + d * R
    fwd = -d
    upv = up - fwd * fwd.dot(up)
    if upv.length < 1e-6:
        upv = Vector((0, 0, 1))
    rx = fwd.cross(upv.normalized())
    import mathutils
    m = mathutils.Matrix((rx, upv.normalized(), -fwd)).transposed()
    cam.rotation_euler = m.to_euler()


for nm, d in dirs.items():
    look(d)
    if nm == "q34":
        sc.render.resolution_x = sc.render.resolution_y = px
        cam.data.ortho_scale = L * 1.1
    else:
        sc.render.resolution_y = px
        sc.render.resolution_x = int(px * 0.45)
        cam.data.ortho_scale = L * 1.06
    sc.render.filepath = f"{pre}_{nm}.png"
    bpy.ops.render.render(write_still=True)
json.dump({"glb": glb, "tris": tris, "size": span.round(4).tolist(), "long_axis": "xyz"[long_ax],
           "views": list(dirs)}, open(f"{pre}_info.json", "w"), indent=1)
print("DONE", tris, span.round(3).tolist())
