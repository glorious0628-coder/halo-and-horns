"""
3D 도구 비교용(Tripo vs Meshy 등): GLB 하나를 같은 조건으로 찍고 숫자를 남긴다.

  blender --background --factory-startup --python tools/compare_3d_render.py -- <in.glb> <out_dir> <label> [target_tris] [front=-y|+x|-x|+y]

- 크기를 높이 2로 맞추고 바닥에 세운다. 조명·카메라·해상도는 모든 모델이 같다.
- 찍는 것: 앞 3/4, 뒤 3/4, 게임 카메라(위에서 비스듬히). target_tris를 주면 같은 면 수로 줄인 판도 찍는다.
- 결과: <out_dir>/<label>_<view>[_dec].png, <out_dir>/<label>_stats.json
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT_DIR, LABEL = argv[0], argv[1], argv[2]
TARGET = int(argv[3]) if len(argv) > 3 else 0
# which Blender axis the model's face points to (Tripo export_orientation default +x)
FRONT = argv[4] if len(argv) > 4 else "-y"
YAW = {"-y": 0, "+x": 90, "+y": 180, "-x": 270}[FRONT]
OUT_DIR = os.path.abspath(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def tri_count(objs):
    n = 0
    for o in objs:
        dg = bpy.context.evaluated_depsgraph_get()
        m = o.evaluated_get(dg).to_mesh()
        n += sum(len(p.vertices) - 2 for p in m.polygons)
        o.evaluated_get(dg).to_mesh_clear()
    return n


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


# normalise: height 2, centred on x/y, standing on z=0
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

stats = {
    "label": LABEL,
    "front": FRONT,
    "file": IN_GLB.replace("\\", "/"),
    "bytes": os.path.getsize(IN_GLB),
    "objects": len(meshes),
    "tris": tri_count(meshes),
    "verts": sum(len(o.data.vertices) for o in meshes),
    "materials": len({m.name for o in meshes for m in o.data.materials if m}),
    "images": sorted({f"{i.size[0]}x{i.size[1]}" for i in bpy.data.images if i.size[0]}),
    "size_wdh_norm": [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)],
}

scene = bpy.context.scene
# EEVEE + sun + even sky light, Standard colours: close to Roblox's look and keeps texture colours honest
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
bgn = world.node_tree.nodes["Background"]
bgn.inputs[0].default_value = (1, 1, 1, 1)
bgn.inputs[1].default_value = 0.9
scene.world = world
sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 2.2
sun_d.angle = math.radians(8)
sun = bpy.data.objects.new("Sun", sun_d)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35 + YAW))
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 768

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
fov = 2 * math.atan(cam_data.sensor_width / 2 / cam_data.lens)
dist = radius / math.sin(fov / 2) * 1.05

VIEWS = {  # (azimuth from front, elevation) degrees; glTF front faces -Y after import
    "front34": (30, 12),
    "back34": (210, 12),
    "game": (20, 35),
}


def shoot(suffix=""):
    for name, (az, el) in VIEWS.items():
        a, e = math.radians(az + YAW), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        cam.location = centre + d * dist
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT_DIR, f"{LABEL}_{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)


shoot()

if TARGET and stats["tris"] > TARGET:
    ratio = TARGET / stats["tris"]
    for o in meshes:
        mod = o.modifiers.new("Dec", "DECIMATE")
        mod.ratio = ratio
    bpy.context.view_layer.update()
    stats["dec_target"] = TARGET
    stats["dec_tris"] = tri_count(meshes)
    shoot("_dec")

json.dump(stats, open(os.path.join(OUT_DIR, f"{LABEL}_stats.json"), "w"), indent=1)
print("[compare_3d_render] ok", json.dumps(stats), flush=True)
