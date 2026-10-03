"""
Tripo 코스튬 GLB(2k 텍스처로 받은 것)를 로블록스용으로 다듬는다 — 얼굴·눈이 덜 뭉개지게 (블렌더 백그라운드).

  blender --background --factory-startup --python tools/fix_face.py -- <in_2k.glb> <out.glb>

로블록스 텍스처는 한 장에 최대 1024라서, 몸 전체가 1024 한 장을 나눠 쓰면 얼굴 몫이 아주 작아진다.
1) 머리(키의 위쪽 44%)를 따로 떼고, 머리 UV 섬들을 0~1 전체로 다시 펼친다(섬 모양은 그대로 → 이음매 최소).
2) 2k 원본 텍스처에서 머리 전용 1024 텍스처로 굽는다 → 얼굴 픽셀이 몇 배로 늘어난다.
3) 몸은 원래 UV 그대로 1024로 줄인다. 몸 + 머리 두 메시로 GLB를 내보낸다.
환경변수 HEAD_FRAC(기본 0.56): 이 높이 비율 위를 머리로 본다.
"""

import os
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT_GLB = argv[0], argv[1]
RES = 1024
HEAD_FRAC = float(os.environ.get("HEAD_FRAC", "0.56"))


def log(*a):
    print("[fix_face]", *a, flush=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = body.data
src_mat = me.materials[0]
src_img = next(n.image for n in src_mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
log("source texture", src_img.size[0], "x", src_img.size[1])

zs = [v.co.z for v in me.vertices]
zmin, zmax = min(zs), max(zs)
neck_z = zmin + HEAD_FRAC * (zmax - zmin)

# ---------------------------------------------------------------- split the head off
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(me)
for f in bm.faces:
    f.select = f.calc_center_median().z > neck_z
bmesh.update_edit_mesh(me)
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
head = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != body][0]
head.name, body.name = "Head", "Body"

# ---------------------------------------------------------------- head: copy the UV, pack its islands over the whole 0..1 square
hm = head.data
old_uv = hm.uv_layers[0].name
new_uv = hm.uv_layers.new(name="HeadUV")
for i, d in enumerate(hm.uv_layers[old_uv].data):
    new_uv.data[i].uv = d.uv
hm.uv_layers.active = new_uv
bpy.ops.object.select_all(action="DESELECT")
head.select_set(True)
bpy.context.view_layer.objects.active = head
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.select_all(action="SELECT")
bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")


def bake_to(obj, src_uv, dst_uv, name):
    """emission-bake src_img (via src_uv) into a new RES x RES image laid out on dst_uv"""
    img = bpy.data.images.new(name, RES, RES, alpha=False)
    mat = bpy.data.materials.new(name + "_bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    uvs = nt.nodes.new("ShaderNodeUVMap"); uvs.uv_map = src_uv
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = src_img; tex.interpolation = "Cubic"
    target = nt.nodes.new("ShaderNodeTexImage"); target.image = img
    uvt = nt.nodes.new("ShaderNodeUVMap"); uvt.uv_map = dst_uv
    nt.links.new(uvs.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(uvt.outputs["UV"], target.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    nt.nodes.active = target
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.data.uv_layers.active = obj.data.uv_layers[dst_uv]
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT", margin=12)
    return img


scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1
scene.render.bake.margin = 12

head_img = bake_to(head, old_uv, "HeadUV", "HeadTex")
body_uv = me.uv_layers[0].name
body_img = bake_to(body, body_uv, body_uv, "BodyTex")
log("baked head + body at", RES)


def final_material(obj, img, uv_name, name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    bsdf = t.nodes.get("Principled BSDF")
    tx = t.nodes.new("ShaderNodeTexImage"); tx.image = img
    uv = t.nodes.new("ShaderNodeUVMap"); uv.uv_map = uv_name
    t.links.new(uv.outputs["UV"], tx.inputs["Vector"])
    t.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(m)
    for n in [l.name for l in obj.data.uv_layers if l.name != uv_name]:
        obj.data.uv_layers.remove(obj.data.uv_layers[n])


def crisp(img, amount, sat):
    """unsharp mask (3x3 gaussian) + a small saturation lift, in place — counters Tripo's soft textures"""
    import numpy as np
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(h, w, 4)
    rgb = a[:, :, :3]
    p = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
    k = (1, 2, 1)
    blur = sum(k[i] * k[j] * p[i:i + h, j:j + w] for i in range(3) for j in range(3)) / 16.0
    rgb = rgb + amount * (rgb - blur)
    grey = rgb.mean(axis=2, keepdims=True)
    rgb = grey + (rgb - grey) * sat
    a[:, :, :3] = np.clip(rgb, 0.0, 1.0)
    img.pixels.foreach_set(a.ravel())
    img.update()


crisp(head_img, float(os.environ.get("SHARP_HEAD", "0.9")), float(os.environ.get("SAT", "1.08")))
crisp(body_img, float(os.environ.get("SHARP_BODY", "0.6")), float(os.environ.get("SAT", "1.08")))
final_material(head, head_img, "HeadUV", "HeadMat")
final_material(body, body_img, body_uv, "BodyMat")
for img, suffix in ((head_img, "_head.png"), (body_img, "_body.png")):
    img.file_format = "PNG"
    img.filepath_raw = os.path.splitext(OUT_GLB)[0] + suffix
    img.save()

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_yup=True)
log("exported", OUT_GLB)
