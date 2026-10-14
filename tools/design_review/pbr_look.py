"""Lit render (EEVEE, sun + sky) of a Tripo PBR FBX: as-is vs. colour-only (metal 0, rough 0.6).
blender --background --factory-startup --python pbr_look.py -- <out_dir> <file.fbx> ...
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out = os.path.abspath(a[0])
os.makedirs(out, exist_ok=True)
for path in a[1:]:
    label = os.path.splitext(os.path.basename(path))[0]
    for mode in ("pbr", "flat"):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
        obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        if mode == "flat":
            for mat in bpy.data.materials:
                if not mat.use_nodes:
                    continue
                for n in mat.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        for sock, val in (("Metallic", 0.0), ("Roughness", 0.6)):
                            s = n.inputs[sock]
                            for l in list(s.links):
                                mat.node_tree.links.remove(l)
                            s.default_value = val
        pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        ctr, size = (lo + hi) / 2, max(hi - lo)
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_EEVEE"
        sc.render.resolution_x = sc.render.resolution_y = 700
        sc.view_settings.view_transform = "Standard"
        world = bpy.data.worlds.new("w")
        sc.world = world
        world.use_nodes = True
        bg = world.node_tree.nodes.get("Background")
        bg.inputs[0].default_value = (0.75, 0.8, 0.9, 1)
        bg.inputs[1].default_value = 0.9
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        sc.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = size * 1.15
        d = Vector((math.cos(math.radians(20)), math.sin(math.radians(20)), 0.3)).normalized()
        cam.location = ctr + d * size * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out, f"{label}__{mode}.png")
        bpy.ops.render.render(write_still=True)
        print("DONE", label, mode)
