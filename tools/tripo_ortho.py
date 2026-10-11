"""Ortho measuring views of a Tripo parts GLB with a stud grid (이미지 생성 3, 10/11, SPEC A23-125 cutting step).

  blender --background --factory-startup --python tools/tripo_ortho.py -- <in.glb> <out_dir> [--px 1100] [--views front,side,top]
          [--hide Glass,WinPane] [--only Door,Lantern]

Workbench, texture colours, orthographic, the whole model framed. Writes <out_dir>/<view>.png and <out_dir>/frame.json
({view: {"u": [axis, min, max], "v": [axis, min, max], "px": [w, h]}}); then draws a 1-stud grid (labels every 2) with
PIL so cut heights / boxes can be read off in the GLB's own frame (front = +Y, z up). front = camera on +Y looking -Y
(x grows to the left of the image), side = camera on +X (the house's left side, y grows to the right), top = from +Z.
"""
import argparse
import json
import math
import os
import subprocess
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("inp")
ap.add_argument("out")
ap.add_argument("--px", type=int, default=1100)
ap.add_argument("--views", default="front,side,top")
ap.add_argument("--hide", default="")
ap.add_argument("--only", default="", help="draw only objects whose name contains one of these (comma list)")
a = ap.parse_args(argv)
os.makedirs(a.out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
hide = [h for h in a.hide.split(",") if h]
only = [h for h in a.only.split(",") if h]
pts = []
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    if any(h in o.name for h in hide) or (only and not any(h in o.name for h in only)):
        o.hide_render = True
        continue
    pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "TEXTURE"
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.18, 0.18, 0.2)
cam_d = bpy.data.cameras.new("c")
cam_d.type = "ORTHO"
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
pad = 1.0
frame = {}
V = {
    # view: (camera location fn, rotation euler, u axis (image right), v axis (image up), u sign)
    "front": ("y", (math.radians(90), 0, math.radians(180)), ("x", -1), ("z", 1)),
    "side": ("x", (math.radians(90), 0, math.radians(90)), ("y", 1), ("z", 1)),
    "top": ("z", (0, 0, math.radians(180)), ("x", -1), ("y", -1)),
}
for vw in a.views.split(","):
    ax, rot, (ua, us), (va, vs) = V[vw]
    umin, umax = getattr(lo, ua) - pad, getattr(hi, ua) + pad
    vmin, vmax = getattr(lo, va) - pad, getattr(hi, va) + pad
    w, h = umax - umin, vmax - vmin
    cam_d.ortho_scale = max(w, h)
    sc.render.resolution_x = int(a.px * (w / max(w, h)))
    sc.render.resolution_y = int(a.px * (h / max(w, h)))
    c = (lo + hi) / 2
    loc = Vector(c)
    setattr(loc, ax, getattr(hi, ax) + 50)
    cam.location = loc
    cam.rotation_euler = rot
    cam_d.clip_end = 500
    sc.render.filepath = os.path.join(a.out, vw + ".png")
    bpy.ops.render.render(write_still=True)
    # image left -> right covers u from (us > 0 ? umin : umax) towards the other end
    frame[vw] = {"u": [ua, umin, umax, us], "v": [va, vmin, vmax, vs], "px": [sc.render.resolution_x, sc.render.resolution_y]}
json.dump({"lo": list(lo), "hi": list(hi), "views": frame}, open(os.path.join(a.out, "frame.json"), "w"), indent=1)
print("[ortho] bounds", tuple(round(v, 2) for v in lo), tuple(round(v, 2) for v in hi), flush=True)
subprocess.run(["py", os.path.join(os.path.dirname(os.path.abspath(__file__)), "tripo_ortho_grid.py"), a.out], check=False)
