"""Blender (background): assemble per-part Meshy/Tripo GLBs into ONE prop (A23-169, user 10/14: parts drawn and
meshed separately, then joined in Blender). Only size / pivot / placement / duplication / join - no colour or shape edits.

  blender --background --factory-startup --python tools/assemble_parts.py -- <layout.json> <out.glb>

layout.json:
  {"parts": {"post": "a.glb", "baluster": "b.glb"},           # name -> glb (textures embedded)
   "place": [ {"part": "post", "at": [x, y, z], "height": 0.77, "rot": 0},  ... ],   # bottom-centre at `at`, scaled to height
   "join": true,                                              # false = keep parts separate (Roblox <= 20k tris each)
   "boxes": [ {"name": "rail", "min": [x0,y0,z0], "max": [x1,y1,z1], "rgb": [0.96,0.92,0.86]},            # Studio-part stand-ins
              {"name": "rail2", "centre": [x,y,z], "size": [sx,sy,sz], "rot": 45} ... ] }
Every placed part is normalised first: bottom centre -> origin, uniform scale so bbox height == `height` (same ratio both ways,
A23-159 #5 no one-axis stretching).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
layout = json.load(open(a[0], encoding="utf-8"))
dst = os.path.abspath(a[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

src = {}
for name, path in layout["parts"].items():
    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    new = [o for o in scene.objects if o not in before and o.type == "MESH"]
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    cos = [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector((min(c.x for c in cos), min(c.y for c in cos), min(c.z for c in cos)))
    mx = Vector((max(c.x for c in cos), max(c.y for c in cos), max(c.z for c in cos)))
    centre = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for v in o.data.vertices:
        v.co -= centre
    o.location = (0, 0, 0)
    src[name] = (o, mx.z - mn.z, len(o.data.polygons))
    o.hide_set(True)
    o.hide_render = True
    print("ASM part", name, "height %.3f" % (mx.z - mn.z), "tris", len(o.data.polygons))

placed = []
for p in layout["place"]:
    o0, h0, _ = src[p["part"]]
    o = o0.copy()
    o.data = o0.data.copy()
    scene.collection.objects.link(o)
    o.hide_set(False)
    o.hide_render = False
    k = p["height"] / max(h0, 1e-6)
    o.scale = (k, k, k)
    o.rotation_mode = "XYZ"  # glTF import leaves QUATERNION mode, where rotation_euler is ignored (10/14 bug: rails did not turn)
    o.rotation_euler = (0, 0, math.radians(p.get("rot", 0)))
    o.location = Vector(p["at"])
    placed.append(o)

for b in layout.get("boxes", []):
    if "min" in b:
        mn, mx = Vector(b["min"]), Vector(b["max"])
        centre, size, rot = (mn + mx) / 2, mx - mn, 0.0
    else:  # centre / size / rot (deg about Z) for arms that are not axis-aligned
        centre, size, rot = Vector(b["centre"]), Vector(b["size"]), float(b.get("rot", 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
    o = bpy.context.active_object
    o.scale = size
    o.rotation_euler = (0, 0, math.radians(rot))
    o.name = b["name"]
    m = bpy.data.materials.new("box_" + b["name"])
    m.use_nodes = True
    rgb = b.get("rgb", [0.96, 0.92, 0.86])
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    o.data.materials.append(m)
    placed.append(o)

for o0, _, _ in src.values():
    bpy.data.objects.remove(o0, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in placed:
    o.select_set(True)
bpy.context.view_layer.objects.active = placed[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if layout.get("join", True):  # one mesh (review renders); Roblox wants <= 20k tris per MeshPart -> "join": false keeps
    bpy.ops.object.join()      # every part its own object (imports as a Model of MeshParts)
    obj = bpy.context.active_object
    obj.name = os.path.splitext(os.path.basename(dst))[0]
    cos = [v.co for v in obj.data.vertices]
    print("ASM joined tris", len(obj.data.polygons), "bbox min", [round(min(c[i] for c in cos), 3) for i in range(3)], "max", [round(max(c[i] for c in cos), 3) for i in range(3)])
else:
    for i, o in enumerate(placed):
        if o.type == "MESH" and len(o.data.polygons) > 20000:
            print("ASM WARN part over 20k tris:", o.name, len(o.data.polygons))
    print("ASM kept", len(placed), "objects, total tris", sum(len(o.data.polygons) for o in placed if o.type == "MESH"))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True)
print("ASM saved", dst)
