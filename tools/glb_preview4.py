"""Clean 4-view previews of a touched-up GLB (이미지 생성 4, 10/12): Cycles 96 samples + denoise, grey sky + a key light
from the camera side, the <name>_Outline mesh drawn one-sided like Roblox (back faces see-through, no shadows).
Front = +y (tools/tripo_touchup.py kit frame).

  blender --background --factory-startup --python tools/glb_preview4.py -- <in.glb> <out_prefix> [--px 520]
  -> <out_prefix>_front.png / _left.png / _right.png / _back.png (left / right = the model's own sides)
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
glb, pre = a[0], a[1]
px = int(a[a.index("--px") + 1]) if "--px" in a else 520
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in obs:
    if o.name.endswith("_Outline"):
        for m in o.data.materials:
            nt = m.node_tree
            outn = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
            src = outn.inputs["Surface"].links[0].from_socket
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            tr = nt.nodes.new("ShaderNodeBsdfTransparent")
            mix = nt.nodes.new("ShaderNodeMixShader")
            nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
            nt.links.new(src, mix.inputs[1])
            nt.links.new(tr.outputs[0], mix.inputs[2])
            nt.links.new(mix.outputs[0], outn.inputs["Surface"])
        o.visible_shadow = o.visible_diffuse = o.visible_glossy = o.visible_transmission = False
W = np.array([(o.matrix_world @ v.co)[:] for o in obs for v in o.data.vertices])
ctr = Vector(((W.min(0) + W.max(0)) / 2).tolist())
size = float(np.ptp(W, axis=0).max())
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 96
sc.cycles.use_denoising = True
sc.render.resolution_x = sc.render.resolution_y = px
w = bpy.data.worlds.new("w")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.43, 0.45, 1)
key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
key.data.energy = 3.2
sc.collection.objects.link(key)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = size * 1.12
el = math.radians(8)
for view, az in (("front", 0), ("left", -90), ("back", 180), ("right", 90)):
    d = Vector((math.sin(math.radians(az)), math.cos(math.radians(az)), 0)) * math.cos(el) + Vector((0, 0, math.sin(el)))
    cam.location = ctr + d * (size * 3)
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    side = Vector((d.x, d.y, 0)).normalized().cross(Vector((0, 0, 1)))
    key.rotation_euler = (-(d * 0.75 + side * 0.45 + Vector((0, 0, 0.7))).normalized()).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = "%s_%s.png" % (pre, view)
    bpy.ops.render.render(write_still=True)
print("[preview4] done", pre)
