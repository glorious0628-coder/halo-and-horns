"""Close-up renders of chosen objects of a GLB (front / side / 3/4 / top, auto-framed) for Blender fix checks
(A23-125 "Tripo -> Blender 손보기 -> Roblox": before / after sheets). 이미지 생성 3, 10/11.

  blender --background --factory-startup --python tools/glb_closeups.py -- <glb> <abs out dir> <name part> [<name part> ...]
          [--prefix before_] [--px 900]

Only mesh objects whose name contains one of the name parts are kept; renders <prefix><views>.png framed on their box.
Front = from +y (the house front), side = from +x, q34 = from (+x, +y, up), top = from above. Prints the box and tris.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("glb")
ap.add_argument("out")
ap.add_argument("names", nargs="+")
ap.add_argument("--prefix", default="")
ap.add_argument("--px", type=int, default=900)
a = ap.parse_args(argv)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.glb)
keep = []
for o in list(bpy.data.objects):
    if o.type == "MESH" and any(n in o.name for n in a.names):
        keep.append(o)
    elif o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
if not keep:
    sys.exit("[close] nothing matches %s" % a.names)
pts = [o.matrix_world @ v.co for o in keep for v in o.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
c = (lo + hi) / 2
size = max(hi - lo) * 1.15
tris = 0
for o in keep:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print("[close] %d objects, tris %d, box %s .. %s" % (len(keep), tris, tuple(round(v, 2) for v in lo), tuple(round(v, 2) for v in hi)), flush=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = a.px
w = bpy.data.worlds.new("w")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(52), 0, math.radians(205))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = size
os.makedirs(a.out, exist_ok=True)
for nm, d in (("front", (0, 1, 0)), ("side", (1, 0, 0)), ("q34", (0.7, 0.7, 0.45)), ("top", (0, 0.001, 1))):
    loc = c + Vector(d).normalized() * 60
    cam.location = loc
    cam.rotation_euler = (c - loc).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(a.out, a.prefix + nm + ".png")
    bpy.ops.render.render(write_still=True)
print("[close] ok", a.out, flush=True)
