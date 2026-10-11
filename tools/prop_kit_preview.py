"""Blender preview of tools/prop_kit.py kits (이미지 생성 4, 10/11): the part list with its CSG ops, four views like the 2D
sheets (front / left / back / right, camera a little above), for a side-by-side check before the Studio photos.

  blender --background --factory-startup --python tools/prop_kit_preview.py -- <out_dir> <kit.json> [<kit.json> ...]
          [--px 640] [--elev 14]

Writes <out_dir>/<Kit>_<view>.png. "left" = camera at +x (the kit's own left side, like the 2D *_left.png),
"right" = camera at -x. Colours are the part colours; gold metallic, glass see-through, lamp glass glowing.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prop_kit_bl import build_kit  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("kits", nargs="+")
ap.add_argument("--px", type=int, default=640)
ap.add_argument("--elev", type=float, default=14.0)
ap.add_argument("--samples", type=int, default=24)
a = ap.parse_args(argv)
a.out = os.path.abspath(a.out)
os.makedirs(a.out, exist_ok=True)


def render_kit(path):
    K = json.load(open(path))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = sc.collection
    print("[preview] build", K["name"], len(K["parts"]), flush=True)
    build_kit(K, coll)
    # bounds
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for ob in coll.objects:
        for v in ob.bound_box:
            w = ob.matrix_world @ Vector(v)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    ctr = (mn + mx) / 2
    size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    sc.render.engine = "CYCLES"          # EEVEE hangs in --background on this PC (10/11, shared GPU)
    sc.cycles.device = "CPU"
    sc.cycles.samples = a.samples
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 3
    sc.render.resolution_x = sc.render.resolution_y = a.px
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.13, 0.135, 0.145, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(200))
    coll.objects.link(sun)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
    fill.data.energy = 1.0
    fill.rotation_euler = (math.radians(60), 0, math.radians(20))
    coll.objects.link(fill)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    coll.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.18
    el = math.radians(a.elev)
    for view, az in (("front", 0), ("left", 90), ("back", 180), ("right", 270)):
        d = Vector((math.sin(math.radians(az)), math.cos(math.radians(az)), 0)) * math.cos(el) + Vector((0, 0, math.sin(el)))
        cam.location = ctr + d * (size * 3)
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(a.out, "%s_%s.png" % (K["name"], view))
        print("[preview] render", K["name"], view, flush=True)
        bpy.ops.render.render(write_still=True)
    print("[preview] %s %d objects, size %.2f x %.2f x %.2f" % (K["name"], len(coll.objects), mx.x - mn.x, mx.y - mn.y, mx.z - mn.z))


for k in a.kits:
    render_kit(k)
