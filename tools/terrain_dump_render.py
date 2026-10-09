"""Render a meadow_terrain.luau offline dump from 3 angles (top, SW oblique, NE oblique) with Blender.

  luau.exe tools/worldkit/meadow_terrain.luau > dump.txt      (rows "C,x,z,V,W,mat,tag")
  blender --background --factory-startup --python tools/terrain_dump_render.py -- dump.txt out_prefix [x0 x1 z0 z1] [zscale]

Writes out_prefix_top.png, _sw.png, _ne.png (workbench, vertex colours by material, heights x zscale (default 1.6)
so the relief reads from the air). Used for the before / after sheets of the meadow tiers (A23-76).
"""
import math
import sys

import bmesh
import bpy
from mathutils import Vector

argv = [a for a in sys.argv[sys.argv.index("--") + 1:] if a != "--halo"]
DUMP, PREFIX = argv[0], argv[1]
X0, X1, Z0, Z1 = (float(v) for v in argv[2:6]) if len(argv) >= 6 else (206, 654, -244, 244)
ZS = float(argv[6]) if len(argv) >= 7 else 1.6
rows = {}
for line in open(DUMP, encoding="utf-8"):
    if not line.startswith("C,"):
        continue
    p = line.strip().split(",")
    x, z, v, w, mat, tag = float(p[1]), float(p[2]), float(p[3]), p[4], p[5], p[6]
    if X0 <= x <= X1 and Z0 <= z <= Z1:
        rows[(x, z)] = (v, w, mat, tag)
xs = sorted({k[0] for k in rows})
zs = sorted({k[1] for k in rows})
bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
idx = {}
for i, x in enumerate(xs):
    for k, z in enumerate(zs):
        v = rows[(x, z)][0]
        idx[(i, k)] = bm.verts.new((x, z, v * ZS))
for i in range(len(xs) - 1):
    for k in range(len(zs) - 1):
        bm.faces.new((idx[(i, k)], idx[(i + 1, k)], idx[(i + 1, k + 1)], idx[(i, k + 1)]))
col = bm.loops.layers.color.new("c")
COL = {"Grass": (0.25, 0.5, 0.15), "LeafyGrass": (0.22, 0.45, 0.15), "Rock": (0.45, 0.45, 0.48), "Sand": (0.78, 0.68, 0.45),
       "Pavement": (0.62, 0.48, 0.32), "Mud": (0.4, 0.3, 0.2), "Salt": (0.8, 0.8, 0.5), "Sandstone": (0.2, 0.4, 0.12),
       "Marble": (0.93, 0.92, 0.88), "Concrete": (0.93, 0.9, 0.8), "Limestone": (0.78, 0.76, 0.70)}
for f in bm.faces:
    for loop in f.loops:
        x, z = loop.vert.co.x, loop.vert.co.y
        v, w, mat, tag = rows[(x, z)]
        c = COL.get(mat, (0.3, 0.5, 0.2))
        if w != "-" and float(w) > v * 1.0 + 0.05 or tag in ("bed",):
            c = (0.2, 0.45, 0.8)
        loop[col] = (c[0], c[1], c[2], 1)
me = bpy.data.meshes.new("T")
bm.to_mesh(me)
if me.color_attributes:
    me.color_attributes.active_color = me.color_attributes[0]
    me.color_attributes.render_color_index = 0
ob = bpy.data.objects.new("T", me)
bpy.context.scene.collection.objects.link(ob)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "VERTEX"
sc.display.shading.show_shadows = True
sc.display.shading.background_type = "VIEWPORT"
sc.display.shading.background_color = (0.75, 0.85, 0.95)
cd = bpy.data.cameras.new("C")
cam = bpy.data.objects.new("C", cd)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1400, 1100
cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
span = max(X1 - X0, Z1 - Z0)
def hypso(v):  # height colour ramp for the top view: low = blue-green, high = red
    t = max(0.0, min(1.0, (v + 3) / 28))
    stops = [(0.0, (0.15, 0.35, 0.6)), (0.2, (0.2, 0.6, 0.3)), (0.45, (0.85, 0.85, 0.3)), (0.7, (0.9, 0.5, 0.2)), (1.0, (0.8, 0.15, 0.15))]
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if t <= b:
            u = (t - a) / (b - a)
            return tuple(ca[i] + (cb[i] - ca[i]) * u for i in range(3))
    return stops[-1][1]
VIEWS = (("top", "top"), ("sw", "oblique_sw"), ("ne", "oblique_ne"))
if "--halo" in sys.argv:  # camera on the gate side (south of the island) looking north, like the Halo concept
    VIEWS = (("top", "top"), ("gate", "oblique_gate"), ("side", "oblique_side"))
for name, kind in VIEWS:
    if kind == "top":
        sc.render.resolution_x, sc.render.resolution_y = 1100, 1200
        sc.display.shading.light = "FLAT"
        for f in me.polygons:
            for li in f.loop_indices:
                vz = me.vertices[me.loops[li].vertex_index].co.z / ZS
                c = hypso(vz)
                me.color_attributes[0].data[li].color = (c[0], c[1], c[2], 1)
        cd.type, cd.ortho_scale = "ORTHO", max(X1 - X0, Z1 - Z0) * 1.04
        cam.location = (cx, cz, 400)
        cam.rotation_euler = (0, 0, 0)
    else:
        sc.render.resolution_x, sc.render.resolution_y = 1400, 1100
        sc.display.shading.light = "STUDIO"
        cd.type, cd.ortho_scale = "ORTHO", span * 0.95
        d = 700
        az = math.radians({"oblique_sw": 225, "oblique_ne": 45, "oblique_gate": 90, "oblique_side": 160}.get(kind, 45))
        el = math.radians(33)
        cam.location = (cx + d * math.cos(el) * math.cos(az), cz + d * math.cos(el) * math.sin(az), d * math.sin(el))
        cam.rotation_euler = (Vector((cx, cz, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{PREFIX}_{name}.png"
    bpy.ops.render.render(write_still=True)
print("rendered", PREFIX)
