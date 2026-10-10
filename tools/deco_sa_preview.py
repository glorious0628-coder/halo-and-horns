"""Blender check renders for the flat deco plates (tools/deco_sa_maps.py): each plate as a plane, before = the colour alone
(a Decal today), after = Color (alpha) + Normal + Metalness + Roughness, seen 35 deg from the side under a sky + sun so the
gold reflects. 이미지 개발 2026-10-10.

  blender --background --factory-startup --python tools/deco_sa_preview.py -- <out_dir> Name [Name ...]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, NAMES = argv[0], argv[1:]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, "art", "ui", "sa_halodeco")
os.makedirs(OUT, exist_ok=True)


def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = 900, 900
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    sky = w.node_tree.nodes.new("ShaderNodeTexSky")
    w.node_tree.links.new(sky.outputs["Color"], w.node_tree.nodes["Background"].inputs["Color"])
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(200))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def tex(nt, path, non_color):
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = bpy.data.images.load(path)
    if non_color:
        n.image.colorspace_settings.name = "Non-Color"
    return n


def plate(name, full):
    c = os.path.join(SA, f"HaloDeco_{name}_C.png")
    img = bpy.data.images.load(c)
    w, h = img.size
    bpy.ops.mesh.primitive_plane_add(size=1)
    p = bpy.context.active_object
    p.scale = (w / max(w, h) * 4, h / max(w, h) * 4, 1)
    p.rotation_euler = (math.radians(90), 0, 0)  # stands up, faces -Y
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        m.blend_method = "BLEND"
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    src = os.path.join(ROOT, "art", "ui", f"HaloDeco_{name}.png") if not full else c
    tc = tex(nt, src, False)
    nt.links.new(tc.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tc.outputs["Alpha"], b.inputs["Alpha"])
    if full:
        nt.links.new(tex(nt, os.path.join(SA, f"HaloDeco_{name}_M.png"), True).outputs["Color"], b.inputs["Metallic"])
        nt.links.new(tex(nt, os.path.join(SA, f"HaloDeco_{name}_R.png"), True).outputs["Color"], b.inputs["Roughness"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex(nt, os.path.join(SA, f"HaloDeco_{name}_N.png"), True).outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    else:
        b.inputs["Roughness"].default_value = 0.6
        b.inputs["Metallic"].default_value = 0.0
    p.data.materials.append(m)
    return p


for name in NAMES:
    for full in (False, True):
        sc, cam = scene()
        plate(name, full)
        target = Vector((0, 0, 0))
        cam.location = Vector((math.sin(math.radians(35)) * 9, -math.cos(math.radians(35)) * 9, 1.2))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, f"{name}_{'after' if full else 'before'}.png")
        bpy.ops.render.render(write_still=True)
    print(f"[deco] {name}", flush=True)
