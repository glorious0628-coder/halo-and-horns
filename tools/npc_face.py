"""NPC face fix (이미지 생성 1, 2026-10-10, 검수: "얼굴이 흐림 — 머리를 따로 부품(자기 1024 텍스처)으로, 얼굴은 2D 앞면에서 투사로 다시 굽기").

  blender --background --factory-startup --python tools/npc_face.py -- <npc_LOD.glb> <front_2d.png> <bbox x0,y0,x1,y1,W,H> <out.glb> <render_dir>
          [--neck 0.64] [--size 1024] [--front-lo 0.35] [--front-hi 0.75] [--mask <face_mask.png>] [--face-scale 3] [--plane-eps 0.02]

- The model (Z-up, front = -Y, as tools/npc_lod.sh writes it) is split at --neck x height: the faces above become <Name>_Head with
  their own UV (the Tripo islands packed again) and their own SIZE x SIZE colour texture; the rest stays <Name>_Body with the Tripo texture.
- The head texture is baked (Cycles EMIT) from a mix: the Tripo colour, and where a face looks toward the front (normal . -Y from
  --front-lo to --front-hi) the 2D front art projected straight from the front (orthographic: the model's x / z box maps onto the
  2D character's silhouette box <bbox>, measured outside with PIL).
- --mask (tools/npc_face_mask.py, same pixel space as the 2D front) limits the projection to the face skin: helmets and hair keep the
  Tripo colour, because their 3D shape does not line up with the 2D (smeared grilles/strands otherwise).
- Writes <out.glb> (Head + Body) and <render_dir>/<Name>_face_{front,head}.png.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, FRONT, BBOX, OUT, RDIR = argv[0], os.path.abspath(argv[1]), [float(v) for v in argv[2].split(",")], os.path.abspath(argv[3]), os.path.abspath(argv[4])
opt = {"neck": 0.64, "size": 1024, "front-lo": 0.35, "front-hi": 0.75}
i = 5
while i < len(argv):
    opt[argv[i][2:]] = argv[i + 1] if argv[i] == "--mask" else float(argv[i + 1])
    i += 2
NAME = os.path.basename(IN).split("_HD_")[0]
os.makedirs(RDIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(IN))
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
body.name = NAME + "_Body"
pts = [body.matrix_world @ Vector(c) for c in body.bound_box]
mx0, mx1 = min(p.x for p in pts), max(p.x for p in pts)
mz0, mz1 = min(p.z for p in pts), max(p.z for p in pts)
neck_z = mz0 + opt["neck"] * (mz1 - mz0)

# --- split the head off
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(body.data)
for f in bm.faces:
    f.select = f.calc_center_median().z > neck_z
bmesh.update_edit_mesh(body.data)
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
head = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != body][0]
head.name = NAME + "_Head"
print("[face] split at z %.3f of %.3f..%.3f, head faces %d" % (neck_z, mz0, mz1, len(head.data.polygons)), flush=True)

# --- head UVs: keep the Tripo UV for reading, add HeadUV (target) and Front (projection)
me = head.data
src_uv = me.uv_layers[0].name
bpy.context.view_layer.objects.active = head
bpy.ops.object.select_all(action="DESELECT")
head.select_set(True)
me.uv_layers.new(name="HeadUV")
me.uv_layers.active = me.uv_layers["HeadUV"]
# HeadUV = the Tripo UV islands of the head faces, packed again to fill the head's own texture: no overlaps
# (a cylindrical unwrap put the helmet shell, hair and face on the same texels -> smeared helmets; smart project cut
# the decimated head into thousands of one-triangle islands -> dotted texture)
huv = me.uv_layers["HeadUV"]
suv = me.uv_layers[src_uv]
for li in range(len(me.loops)):
    huv.data[li].uv = suv.data[li].uv
front_uv = me.uv_layers.new(name="Front")
bx0, by0, bx1, by1, W, H = BBOX
for poly in me.polygons:
    for li in poly.loop_indices:
        co = head.matrix_world @ me.vertices[me.loops[li].vertex_index].co
        u = (bx0 + (co.x - mx0) / (mx1 - mx0) * (bx1 - bx0)) / W
        v = 1.0 - (by0 + (mz1 - co.z) / (mz1 - mz0) * (by1 - by0)) / H
        front_uv.data[li].uv = (u, v)

# islands that hold the face skin (mask) get --face-scale x more texels before packing
if opt.get("mask"):
    import numpy as np
    mimg = bpy.data.images.load(os.path.abspath(opt["mask"]))
    mw_, mh_ = mimg.size
    mpx = np.empty(mw_ * mh_ * 4, dtype=np.float32)
    mimg.pixels.foreach_get(mpx)
    mpx = mpx.reshape(mh_, mw_, 4)[..., 0]
    parent = list(range(len(me.polygons)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    edge_owner = {}
    for poly in me.polygons:
        for k_, li in enumerate(poly.loop_indices):
            lj = poly.loop_indices[(k_ + 1) % len(poly.loop_indices)]
            va, vb = me.loops[li].vertex_index, me.loops[lj].vertex_index
            ua, ub = tuple(round(c, 5) for c in huv.data[li].uv), tuple(round(c, 5) for c in huv.data[lj].uv)
            key = (min(va, vb), max(va, vb))
            val = {va: ua, vb: ub}
            if key in edge_owner:
                op, ov = edge_owner[key]
                if ov == val:
                    parent[find(poly.index)] = find(op)
            else:
                edge_owner[key] = (poly.index, val)
    hot = set()
    skin_polys = []
    for poly in me.polygons:
        n = head.matrix_world.to_3x3() @ poly.normal
        if n.y > -0.5:
            continue
        uv = [front_uv.data[li].uv for li in poly.loop_indices]
        cu, cv = sum(u[0] for u in uv) / len(uv), sum(u[1] for u in uv) / len(uv)
        px, py_ = int(cu * mw_), int(cv * mh_)  # Blender image rows start at the bottom, like UV v
        if 0 <= px < mw_ and 0 <= py_ < mh_ and mpx[py_, px] > 0.5:
            hot.add(find(poly.index))
            skin_polys.append(poly.index)
    fs = opt.get("face-scale", 3.0)
    groups = {}
    for poly in me.polygons:
        r = find(poly.index)
        if r in hot:
            groups.setdefault(r, []).append(poly)
    for polys in groups.values():
        lis = [li for p_ in polys for li in p_.loop_indices]
        cu = sum(huv.data[li].uv[0] for li in lis) / len(lis)
        cv = sum(huv.data[li].uv[1] for li in lis) / len(lis)
        for li in lis:
            u, v = huv.data[li].uv
            huv.data[li].uv = (cu + (u - cu) * fs, cv + (v - cv) * fs)
    # the face is a flat front plane; hair locks lying on the forehead stick out in front of it -> no projection on them
    # (they got skin colour from the 2D and looked like ghost strands)
    ys_ = sorted((head.matrix_world @ me.polygons[i_].center).y for i_ in skin_polys)
    plane_y = ys_[len(ys_) // 2]
    eps = opt.get("plane-eps", 0.02) * (mz1 - mz0)
    proj = me.color_attributes.new("proj", "FLOAT_COLOR", "CORNER")
    n_front = 0
    for poly in me.polygons:
        ok = 1.0
        if (head.matrix_world @ poly.center).y < plane_y - eps:
            ok = 0.0
            n_front += 1
        for li in poly.loop_indices:
            proj.data[li].color = (ok, ok, ok, 1.0)
    print("[face] face plane y %.4f, %d polys in front of it skip the projection" % (plane_y, n_front), flush=True)
    print("[face] face islands scaled x%.1f: %d of %d islands" % (fs, len(groups), len({find(p_.index) for p_ in me.polygons})), flush=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
# --- bake material: mix(Tripo colour, 2D front by facing) -> emission
src_mat = head.data.materials[0]
src_img = None
for n in src_mat.node_tree.nodes:
    if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
        src_img = n.image
mat = bpy.data.materials.new(NAME + "_HeadBake")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
out = nt.nodes.new("ShaderNodeOutputMaterial")
em = nt.nodes.new("ShaderNodeEmission")
mix = nt.nodes.new("ShaderNodeMix")
mix.data_type = "RGBA"
t_src = nt.nodes.new("ShaderNodeTexImage")
t_src.image = src_img
uv_src = nt.nodes.new("ShaderNodeUVMap")
uv_src.uv_map = src_uv
nt.links.new(uv_src.outputs["UV"], t_src.inputs["Vector"])
t_front = nt.nodes.new("ShaderNodeTexImage")
t_front.image = bpy.data.images.load(FRONT)
t_front.extension = "CLIP"
uv_f = nt.nodes.new("ShaderNodeUVMap")
uv_f.uv_map = "Front"
nt.links.new(uv_f.outputs["UV"], t_front.inputs["Vector"])
geo = nt.nodes.new("ShaderNodeNewGeometry")
dot = nt.nodes.new("ShaderNodeVectorMath")
dot.operation = "DOT_PRODUCT"
dot.inputs[1].default_value = (0, -1, 0)
nt.links.new(geo.outputs["Normal"], dot.inputs[0])
mr = nt.nodes.new("ShaderNodeMapRange")
mr.inputs["From Min"].default_value = opt["front-lo"]
mr.inputs["From Max"].default_value = opt["front-hi"]
nt.links.new(dot.outputs["Value"], mr.inputs["Value"])
if opt.get("mask"):
    t_mask = nt.nodes.new("ShaderNodeTexImage")
    t_mask.image = bpy.data.images.load(os.path.abspath(opt["mask"]))
    t_mask.image.colorspace_settings.name = "Non-Color"
    t_mask.extension = "CLIP"
    nt.links.new(uv_f.outputs["UV"], t_mask.inputs["Vector"])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(mr.outputs["Result"], mul.inputs[0])
    nt.links.new(t_mask.outputs["Color"], mul.inputs[1])
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "proj"
    mul2 = nt.nodes.new("ShaderNodeMath")
    mul2.operation = "MULTIPLY"
    nt.links.new(mul.outputs["Value"], mul2.inputs[0])
    nt.links.new(attr.outputs["Fac"], mul2.inputs[1])
    nt.links.new(mul2.outputs["Value"], mix.inputs["Factor"])
else:
    nt.links.new(mr.outputs["Result"], mix.inputs["Factor"])
nt.links.new(t_src.outputs["Color"], mix.inputs[6])
nt.links.new(t_front.outputs["Color"], mix.inputs[7])
nt.links.new(mix.outputs[2], em.inputs["Color"])
nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
size = int(opt["size"])
target = bpy.data.images.new(NAME + "_head", size, size, alpha=False)
t_target = nt.nodes.new("ShaderNodeTexImage")
t_target.image = target
nt.nodes.active = t_target
head.data.materials.clear()
head.data.materials.append(mat)
me.uv_layers.active = me.uv_layers["HeadUV"]
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1
bpy.ops.object.bake(type="EMIT", margin=6)
target.filepath_raw = os.path.join(RDIR, NAME + "_head.png")
target.file_format = "PNG"
target.save()
print("[face] baked", target.filepath_raw, flush=True)

# --- final head material: the baked colour on HeadUV only
fm = bpy.data.materials.new(NAME + "_Head")
fm.use_nodes = True
bsdf = fm.node_tree.nodes["Principled BSDF"]
tn = fm.node_tree.nodes.new("ShaderNodeTexImage")
tn.image = target
fm.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.6
head.data.materials.clear()
head.data.materials.append(fm)
if "proj" in me.color_attributes:
    me.color_attributes.remove(me.color_attributes["proj"])
for name in [l.name for l in me.uv_layers if l.name != "HeadUV"]:
    me.uv_layers.remove(me.uv_layers[name])

# --- check renders (EEVEE): full front + head close-up
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 900
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(60), 0, math.radians(-20))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
scene.collection.objects.link(cam)
scene.camera = cam
hgt = mz1 - mz0
for nm, cz, scale in (("front", (mz0 + mz1) / 2, hgt * 1.1), ("head", (neck_z + mz1) / 2, (mz1 - neck_z) * 1.3)):
    cam.data.ortho_scale = scale
    cam.location = ((mx0 + mx1) / 2, -10, cz)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.render.filepath = os.path.join(RDIR, NAME + "_face_" + nm + ".png")
    bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="SELECT")
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        o.select_set(False)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[face] ok", OUT, flush=True)
