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

import bmesh
import bpy
from mathutils import Matrix, Vector

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
COL = {"marble": (255, 244, 222), "gold": (255, 168, 36)}


def s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MCACHE = {}


def material(key, rgb):
    k = (key, tuple(rgb))
    if k in MCACHE:
        return MCACHE[k]
    m = bpy.data.materials.new("%s_%d_%d_%d" % (key, *rgb))
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple(s2l(c / 255) for c in rgb)
    b.inputs["Base Color"].default_value = (*lin, 1)
    rough, metal = 0.55, 0.0
    if key == "gold":
        rough, metal = 0.3, 0.85
    elif key in ("marble", "mblock", "stone"):
        rough = 0.35
    elif key in ("glass", "water"):
        rough = 0.05
        b.inputs["Alpha"].default_value = 0.5
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    elif key in ("lamp", "neon"):
        b.inputs["Emission Color"].default_value = (1.0, 0.72, 0.3, 1)
        b.inputs["Emission Strength"].default_value = 2.0 if key == "neon" else 1.0
    elif key in ("wood", "woodcream", "wooddk", "cloth", "rope", "leaf", "soil"):
        rough = 0.8
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    MCACHE[k] = m
    return m


def make_obj(t, coll):
    me = bpy.data.meshes.new(t["n"])
    bm = bmesh.new()
    s = t["s"]
    if s == "Block":
        bmesh.ops.create_cube(bm, size=1.0)
    elif s == "Cylinder":
        geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.5, radius2=0.5, depth=1.0)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))   # axis z -> x
    elif s == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=0.5)
    elif s == "Wedge":
        # Roblox wedge, local frame (X, Y up, Z back): low at -Z, high at +Z
        v = [bm.verts.new(p) for p in ((-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5))]
        for f in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)):
            bm.faces.new([v[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = s in ("Cylinder", "Ball")
    ob = bpy.data.objects.new(t["n"], me)
    X, Y = Vector(t["X"]), Vector(t["Y"])
    Z = X.cross(Y)
    # Roblox local Z = X x Y; our Blender frame keeps the same handedness (tools/prop_kit.py r3 is a rotation)
    R = Matrix((X, Y, Z)).transposed().to_4x4()
    ob.matrix_world = Matrix.Translation(Vector(t["p"])) @ R @ Matrix.Diagonal((*t["size"], 1))
    rgb = t["c"] or COL.get(t["m"], (200, 200, 200))
    me.materials.append(material(t["m"], rgb))
    coll.objects.link(ob)
    return ob


def apply_ops(ob, t, coll):
    for kind, lst in t.get("ops", []):
        for c in lst:
            co = make_obj(c, coll)
            if c.get("ops"):
                apply_ops(co, c, coll)
            mod = ob.modifiers.new("b", "BOOLEAN")
            mod.operation = "DIFFERENCE" if kind == "minus" else "INTERSECT"
            mod.object = co
            mod.solver = "EXACT"
            bpy.context.view_layer.objects.active = ob
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            ev = ob.evaluated_get(dg)
            nm = bpy.data.meshes.new_from_object(ev)
            ob.modifiers.clear()
            old = ob.data
            ob.data = nm
            bpy.data.meshes.remove(old)
            bpy.data.objects.remove(co)


def render_kit(path):
    K = json.load(open(path))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MCACHE.clear()
    sc = bpy.context.scene
    coll = sc.collection
    COL.update({k: tuple(v) for k, v in K.get("colors", {}).items()})
    for t in K["parts"]:
        COL.setdefault(t["m"], (200, 200, 200))
    print("[preview] build", K["name"], len(K["parts"]), flush=True)
    for t in K["parts"]:
        ob = make_obj(t, coll)
        if t.get("ops"):
            apply_ops(ob, t, coll)
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
