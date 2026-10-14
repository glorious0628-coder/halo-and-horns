"""PBR gate renders (A23-154): finished Tripo model (GLB from build_glb.py or Tripo FBX), lit like a sunny day.
Views: f (front), fr (camera on -X: front points to image right = 2D `_left`), b (back),
fl (camera on +X: front points to image left = 2D `_right`), q34 (front-right from above), top, bot (straight top/underside),
plus f_big for 100% crops.
Sun follows each camera (upper left behind it) so every side gets the same light; sky fill.
blender --background --factory-startup --python pbr_gate.py -- <out_dir> <px> <big_px> <file[:front]> ...
front = -y (default for .glb, build_glb.py) or +x (default for .fbx, raw Tripo).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out, px, big = os.path.abspath(a[0]), int(a[1]), int(a[2])
os.makedirs(out, exist_ok=True)


def setup(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    else:
        bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.72, 0.78, 0.88, 1)
    bg.inputs[1].default_value = 0.85
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    return sc, cam, sun, lo, hi


def frame(lo, hi, d):
    ctr = (lo + hi) / 2
    d = d.normalized()
    right = (-d).cross(Vector((0, 0, 1)))
    if right.length < 1e-4:
        right = Vector((1, 0, 0))
    right.normalize()
    up = right.cross(-d).normalized()
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    w = max(abs((c - ctr).dot(right)) for c in corners) * 2
    h = max(abs((c - ctr).dot(up)) for c in corners) * 2
    return max(w, h) * 1.08, right, up


def shoot(sc, cam, sun, lo, hi, d, res, fp, scale=None):
    ctr = (lo + hi) / 2
    ext = hi - lo
    d = d.normalized()
    cam.location = ctr + d * max(ext) * 4
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    s, right, up = frame(lo, hi, d)
    cam.data.ortho_scale = scale or s  # same scale for the 4 side views = same size as the 2D sheets
    # sun from behind the camera, upper left
    ld = (d + up * 0.9 - right * 0.6).normalized()
    sun.rotation_euler = (-ld).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.filepath = fp
    bpy.ops.render.render(write_still=True)


for spec in a[3:]:
    path, _, front = spec.partition(":")
    front = front or ("-y" if path.lower().endswith(".glb") else "+x")
    label = os.path.splitext(os.path.basename(path))[0]
    F = {"-y": Vector((0, -1, 0)), "+x": Vector((1, 0, 0)), "+y": Vector((0, 1, 0)), "-x": Vector((-1, 0, 0))}[front]
    # object's right-hand side when it faces the viewer: F x up
    R = F.cross(Vector((0, 0, 1)))
    views = {
        "f": F,
        "fr": R,  # camera on the object's right-hand side: front points to image right (2D `_left`)
        "b": -F,
        "fl": -R,  # front points to image left (2D `_right`)
        "q34": F - R * 0.8 + Vector((0, 0, 0.75)),  # front + the side on the front view's image right, from above
        "top": Vector((0, 0, 1)) + F * 0.02,  # straight down onto the top, front at image bottom (user 10/13: all six sides)
        "bot": Vector((0, 0, -1)) + F * 0.02,  # straight up at the underside (holes, open bottoms)
    }
    sc, cam, sun, lo, hi = setup(path)
    ring = max(frame(lo, hi, views[k])[0] for k in ("f", "fr", "b", "fl"))
    for k, d in views.items():
        shoot(sc, cam, sun, lo, hi, d, px, os.path.join(out, f"{label}__{k}.png"), ring if k in ("f", "fr", "b", "fl") else None)
    shoot(sc, cam, sun, lo, hi, views["f"], big, os.path.join(out, f"{label}__f_big.png"))
    print("DONE", label, "size", tuple(round(v, 3) for v in (hi - lo)))
