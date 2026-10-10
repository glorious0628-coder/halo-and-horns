"""Renders for the 2D | 3D check sheet of a Halo house parts GLB (이미지 생성 3, 2026-10-10; docs/design/3d_quality_check).

  blender --background --factory-startup --python tools/house_sheet_render.py -- <parts.glb> <out_dir> [--ppstud 32]

Writes (ortho, front = +Y looking -Y; sky-ish world so metal reflects something like the game sky):
  front_pbr.png   all maps connected            front_matte.png  colour only (metal 0, rough 0.6, no normal)
  front_id.png    flat colour per object (for seam / part crops)   q34_pbr.png, back_pbr.png
  ids.json        object -> id colour, render px per stud, model box
Resolution = model height (studs) x --ppstud, so a 100 % crop shows about one texel per pixel.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
PPS = float(argv[argv.index("--ppstud") + 1]) if "--ppstud" in argv else 32.0
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2
ext = max(mx.x - mn.x, mx.z - mn.z) * 1.04
res = int(min(4096, max(1024, ext * PPS)))

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = res
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
nt = world.node_tree
bg = nt.nodes["Background"]
sky = nt.nodes.new("ShaderNodeTexSky") if hasattr(bpy.types, "ShaderNodeTexSky") else None
grad = nt.nodes.new("ShaderNodeTexGradient")
mapn = nt.nodes.new("ShaderNodeMapping")
tco = nt.nodes.new("ShaderNodeTexCoord")
ramp = nt.nodes.new("ShaderNodeValToRGB")
nt.links.new(tco.outputs["Generated"], mapn.inputs["Vector"])
mapn.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
nt.links.new(mapn.outputs["Vector"], grad.inputs["Vector"])
nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
ramp.color_ramp.elements[0].color = (0.55, 0.52, 0.45, 1)  # ground
ramp.color_ramp.elements[1].color = (0.45, 0.65, 0.95, 1)  # sky
nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(200))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = ext
cam.data.clip_end = 5000
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(name, yaw, pitch=0.0):
    a = math.radians(yaw)
    d = ext * 4
    cam.location = (c.x + d * math.sin(a) * math.cos(math.radians(pitch)), c.y - d * math.cos(a) * math.cos(math.radians(pitch)),
                    c.z + d * math.sin(math.radians(pitch)))
    cam.rotation_euler = (math.radians(90 - pitch), 0, a)
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


# glass: see-through-ish preview
for o in objs:
    if o.name.endswith("_Glass"):
        for m in o.data.materials:
            m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
shoot("front_pbr", 180)
shoot("q34_pbr", 145, 8)
shoot("back_pbr", 0)

# matte: colour only
saved = {}
for o in objs:
    for m in o.data.materials:
        if not m or not m.use_nodes or m.name in saved:
            continue
        b = [n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"]
        if not b:
            continue
        b = b[0]
        saved[m.name] = True
        for sock in ("Roughness", "Metallic", "Normal"):
            for l in list(b.inputs[sock].links):
                m.node_tree.links.remove(l)
        b.inputs["Roughness"].default_value = 0.6
        b.inputs["Metallic"].default_value = 0.0
shoot("front_matte", 180)

# id pass
ids = {}
pal = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 0), (1, 0, 1), (0, 1, 1), (1, .5, 0), (.5, 0, 1), (0, .5, .25), (.5, .5, .5),
       (1, .75, .8), (.3, .2, .1)]
for i, o in enumerate(objs):
    col = pal[i % len(pal)]
    if o.name.endswith("_Glass") or o.name.endswith("_WinPane"):
        col = (1.0, 1.0, 1.0)  # white: a blend of two other ids can never make it (window crop of the sheet)
    m = bpy.data.materials.new("id%d" % i)
    m.use_nodes = True
    t = m.node_tree
    for n in list(t.nodes):
        t.nodes.remove(n)
    e = t.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = col + (1,)
    out = t.nodes.new("ShaderNodeOutputMaterial")
    t.links.new(e.outputs[0], out.inputs[0])
    o.data.materials.clear()
    o.data.materials.append(m)
    ids[o.name] = [int(x * 255) for x in col]
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
for n in list(world.node_tree.links):
    pass
sun.data.energy = 0
scene.view_settings.view_transform = "Standard"
shoot("front_id", 180)
json.dump({"ids": ids, "res": res, "ext_studs": ext, "pp_stud": res / ext, "min": list(mn), "max": list(mx)},
          open(os.path.join(OUT, "ids.json"), "w"), indent=1)
print("[sheet_render] ok", res, flush=True)
