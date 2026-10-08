"""
Geometry masks baked into a rank accessory's UV space (white = selected), so a recolor can treat small parts on
their own (0 credits). Blender, Cycles EMIT bake of a per-face vertex colour.

  blender --background --factory-startup --python tools/img2/acc_masks.py -- <in.glb> <out_dir> [size=1024]

-> <out_dir>/<name>_emblem.png : halo parts sticking out in front of the ring near the front centre (R3 gems,
                                 R4 / R5 sun emblem). The model faces -Y (Roblox -Z).
   <out_dir>/<name>_tips.png   : horn tips (the top 14 % of the height).
Only meaningful for the textured R3-R5 meshes (R1 / R2 sample whole cells of the shared 64 px palette).
"""
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
SIZE = int(argv[2]) if len(argv) > 2 else 1024
name = os.path.splitext(os.path.basename(IN))[0]
os.makedirs(OUT, exist_ok=True)

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


def ring_front_y():
    """front surface of the ring a little off the centre line (where no emblem sits)"""
    band = [c.y for _, _, c in centres if 0.18 * W < abs(c.x - cx) < 0.3 * W and abs(c.z - (lo.z + hi.z) / 2) < 0.35 * H]
    return min(band) if band else lo.y


rf = ring_front_y()
sel_emblem = {(o.name, i) for o, i, c in centres if abs(c.x - cx) < 0.16 * W and c.y < rf - 0.012 * max(W, D)}
sel_tips = {(o.name, i) for o, i, c in centres if c.z > hi.z - 0.14 * H}

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
    img.filepath_raw = os.path.join(OUT, f"{name}_{label}.png")
    img.file_format = "PNG"
    img.save()


bake(sel_emblem, "emblem")
bake(sel_tips, "tips")
print("[acc_masks] ok", name, "emblem faces", len(sel_emblem), "tip faces", len(sel_tips), "ring front y", round(rf, 4), flush=True)
