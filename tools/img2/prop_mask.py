"""
Geometry mask baked into a prop's UV space (white = selected faces), so a texture recolor can treat one part on its own
(0 credits). Blender, Cycles EMIT bake of a per-face vertex colour. Made from acc_masks.py.

  blender --background --factory-startup --python tools/img2/prop_mask.py -- <in.glb> <out.png> <ztop_frac> <xhalf_frac> [size=1024]

selects faces whose centre is in the top <ztop_frac> of the height and within <xhalf_frac> * width of the centre line
(e.g. the crystal on top of the crossroads notice board: 0.14 0.08).
"""
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
ZTOP, XHALF = float(argv[2]), float(argv[3])
SIZE = int(argv[4]) if len(argv) > 4 else 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
W, D, H = hi.x - lo.x, hi.y - lo.y, hi.z - lo.z
cx = (lo.x + hi.x) / 2

centres = []
for o in meshes:
    mw = o.matrix_world
    for p in o.data.polygons:
        centres.append((o, p.index, mw @ p.center))


sel = {(o.name, i) for o, i, c in centres if c.z > hi.z - ZTOP * H and abs(c.x - cx) < XHALF * W}

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 1
scene.cycles.device = "CPU"


def bake(sel, label):
    img = bpy.data.images.new(label, SIZE, SIZE, alpha=False, float_buffer=False)
    for o in meshes:
        me = o.data
        attr = me.color_attributes.get("MaskCol") or me.color_attributes.new("MaskCol", "BYTE_COLOR", "CORNER")
        for p in me.polygons:
            v = 1.0 if (o.name, p.index) in sel else 0.0
            for li in p.loop_indices:
                attr.data[li].color = (v, v, v, 1.0)
        for m in me.materials:
            nt = m.node_tree
            for n in list(nt.nodes):
                if n.name.startswith("MaskBake"):
                    nt.nodes.remove(n)
            out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
            vc = nt.nodes.new("ShaderNodeVertexColor")
            vc.name = "MaskBakeVC"
            vc.layer_name = "MaskCol"
            em = nt.nodes.new("ShaderNodeEmission")
            em.name = "MaskBakeEm"
            nt.links.new(vc.outputs["Color"], em.inputs["Color"])
            nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.name = "MaskBakeImg"
            tex.image = img
            nt.nodes.active = tex
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    scene.render.bake.margin = 6
    bpy.ops.object.bake(type="EMIT", margin=6)
    img.filepath_raw = OUT
    img.file_format = "PNG"
    img.save()


bake(sel, "mask")
print("[prop_mask] ok", len(sel), "faces of", len(centres), flush=True)
