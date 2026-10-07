"""
③ 앞면 투영 굽기(0 크레딧): match 카메라(2D 시안과 같은 각도)에서 시안 그림을 모델에 비춰 원래 UV 텍스처로 굽는다.

  blender --background --factory-startup --python tools/project_bake.py -- <in.glb> <cam.json> <concept_in_cam.png> <out_dir> [size=1024]

- concept_in_cam.png = concept_flow_warp.py 결과(RGBA, match 렌더 화면 좌표).
- 굽는 것(원래 UV, out_dir):
    proj_color.png  시안 색(카메라에서 비춘 것)
    proj_alpha.png  시안의 물체 부분(흰 = 그림 있음)
    proj_vis.png    카메라에서 보이는 정도(정면 = 흰, 옆·가려짐 = 검정)
- 섞기는 밖에서(tools/project_mix.py): 정면만 시안 색, 옆·뒤는 기존(④) 텍스처.
- 정규화(높이 2, 바닥 가운데)·카메라 공식은 tex_compare_render.py와 같다.
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, CAM_JSON, CIC, OUT_DIR = argv[0], argv[1], os.path.abspath(argv[2]), os.path.abspath(argv[3])
SIZE = int(argv[4]) if len(argv) > 4 else 1024
os.makedirs(OUT_DIR, exist_ok=True)
cam_fit = json.load(open(CAM_JSON, encoding="utf-8"))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


root = bpy.data.objects.new("Root", None)
bpy.context.scene.collection.objects.link(root)
for o in bpy.context.scene.objects:
    if o.parent is None and o is not root:
        o.parent = root
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
s = 2.0 / max(hi.z - lo.z, 1e-6)
root.scale = (s, s, s)
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
centre = (lo + hi) / 2
radius = (hi - lo).length / 2

scene = bpy.context.scene
scene.render.resolution_x = scene.render.resolution_y = 1024
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam_data.lens = cam_fit["lens"]
fov = 2 * math.atan(cam_data.sensor_width / 2 / cam_data.lens)
dist = radius / math.sin(fov / 2) * 1.05
a, e = math.radians(cam_fit["az"]), math.radians(cam_fit["el"])
d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
cam.location = centre + d * dist
cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.view_layer.update()

# projection UVs: each loop's vertex seen through the match camera
for o in meshes:
    me = o.data
    base_uv = me.uv_layers.active.name
    pl = me.uv_layers.new(name="proj")
    mw = o.matrix_world
    for loop in me.loops:
        p = world_to_camera_view(scene, cam, mw @ me.vertices[loop.vertex_index].co)
        pl.data[loop.index].uv = (p.x, p.y)
    me.uv_layers.active = me.uv_layers[base_uv]

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.render.bake.margin = 6
cic = bpy.data.images.load(CIC)
cic.colorspace_settings.name = "sRGB"


def new_target(name):
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False, float_buffer=False)
    return img


def set_materials(builder, target):
    for o in meshes:
        for m in o.data.materials:
            nt = m.node_tree
            for n in list(nt.nodes):
                nt.nodes.remove(n)
            out = nt.nodes.new("ShaderNodeOutputMaterial")
            sh = builder(nt)
            nt.links.new(sh.outputs[0], out.inputs["Surface"])
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = target
            nt.nodes.active = t


def proj_emission(channel):
    def build(nt):
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "proj"
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = cic
        tex.extension = "CLIP"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(tex.outputs[channel], em.inputs["Color"])
        return em
    return build


def select_all():
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]


select_all()
scene.cycles.samples = 4
for name, channel in (("proj_color", "Color"), ("proj_alpha", "Alpha")):
    img = new_target(name)
    set_materials(proj_emission(channel), img)
    bpy.ops.object.bake(type="EMIT", margin=6)
    img.filepath_raw = os.path.join(OUT_DIR, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("[project_bake]", name, flush=True)

# visibility from the camera: a sun shining along the camera's view, white diffuse, direct light only
world = bpy.data.worlds.new("W")
world.use_nodes = True  # new worlds light the scene grey otherwise (back faces came out ~0.21)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
scene.world = world
sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 1.0
sun_d.angle = math.radians(0.5)
sun = bpy.data.objects.new("Sun", sun_d)
scene.collection.objects.link(sun)
sun.rotation_euler = cam.rotation_euler
img = new_target("proj_vis")


def diffuse(nt):
    df = nt.nodes.new("ShaderNodeBsdfDiffuse")
    df.inputs["Color"].default_value = (1, 1, 1, 1)
    return df


set_materials(diffuse, img)
scene.cycles.samples = 16
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"DIRECT"}, margin=6)
img.filepath_raw = os.path.join(OUT_DIR, "proj_vis.png")
img.file_format = "PNG"
img.save()
print("[project_bake] ok", OUT_DIR, flush=True)
