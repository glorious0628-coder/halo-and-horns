"""Check render of tools/weapon_hd_fit.py results (무기 디자인, 10/14). Per GLB: front (Roblox -Z face) and side,
ortho, even light; red line = origin height (the grip point), grey ticks every 1 stud, label = size in studs.

  blender --background --factory-startup --python tools/weapon_fit_check.py -- <out.png> <fit.glb> [<fit.glb> ...]
"""
import math
import os
import subprocess
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out, glbs = os.path.abspath(a[0]), [os.path.abspath(p) for p in a[1:]]
PX = 90  # pixels per stud
Z0, Z1 = -2.2, 6.0
tiles = []
for g in glbs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=g)
    W = np.vstack([np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices]) for o in sc.objects if o.type == "MESH"])
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    sc.render.film_transparent = True
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = Z1 - Z0
    sc.render.resolution_y = int(PX * (Z1 - Z0))
    sc.render.resolution_x = int(PX * 2.0)
    cam.data.sensor_fit = "VERTICAL"
    for nm, loc, rot in (("front", (0, 20, (Z0 + Z1) / 2), (90, 0, 180)), ("side", (20, 0, (Z0 + Z1) / 2), (90, 0, 90))):
        cam.location = Vector(loc)
        cam.rotation_euler = [math.radians(r) for r in rot]
        p = f"{out[:-4]}_{os.path.basename(g)[:-4]}_{nm}.png"
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        tiles.append((p, os.path.basename(g)[:-4] + " " + nm, np.ptp(W, 0).round(2).tolist()))
open(out[:-4] + "_tiles.txt", "w").write("\n".join(f"{p}|{lab}|{s}" for p, lab, s in tiles))
print("TILES", len(tiles))
