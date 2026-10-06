"""
개발 일지 영상용: GLB 하나를 한 바퀴 돌리며 투명 PNG 프레임으로 찍는다(EEVEE, 3점 조명).
애니메이션이 들어 있는 GLB(예: MonsterBatGoblin_Walk.glb)는 돌면서 동작도 반복한다.

  blender --background --factory-startup --python tools/devlog_turntable.py -- <in.glb> <out_dir> [frames=120] [size=1000] [start_deg=60]
  Blender path: C:/Users/glori/Tools/blender-5.2.2-windows-x64/blender.exe (the AppData copy does not start inside the Claude app)

출력: <out_dir>/f_0000.png …  (ffmpeg -framerate 30 -i f_%04d.png 로 붙인다)
"""

import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT_DIR = os.path.abspath(argv[0]), os.path.abspath(argv[1])
FRAMES = int(argv[2]) if len(argv) > 2 else 120
SIZE = int(argv[3]) if len(argv) > 3 else 1000
START = float(argv[4]) if len(argv) > 4 else 60.0  # degrees at frame 0 (Tripo GLBs face +X: 60 = a 3/4 front view)
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
scene = bpy.context.scene

# 작은 도우미 메시(예: Tripo 동작 GLB에 딸려 온 Icosphere)는 숨긴다
meshes = [o for o in scene.objects if o.type == "MESH"]
biggest = max((len(o.data.vertices) for o in meshes), default=0)
for o in meshes:
    if biggest > 1000 and len(o.data.vertices) < biggest * 0.02:
        o.hide_render = True
        o.hide_set(True)
        bpy.data.objects.remove(o, do_unlink=True)

# 모든 가져온 물체를 빈 물체 하나에 붙여서 그 빈 물체를 돌린다
roots = [o for o in scene.objects if o.parent is None]
pivot = bpy.data.objects.new("Pivot", None)
scene.collection.objects.link(pivot)
for o in roots:
    o.parent = pivot

# 애니메이션 범위(있으면)
anim_start, anim_len = 0, 0
acts = [a for a in bpy.data.actions]
if acts:
    r = acts[0].frame_range
    anim_start, anim_len = int(r[0]), max(1, int(r[1] - r[0]))
scene.frame_set(anim_start)
bpy.context.view_layer.update()


def bounds():
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in scene.objects:
        if o.type == "MESH":
            ev = o.evaluated_get(dg)
            m = ev.to_mesh()
            pts += [ev.matrix_world @ v.co for v in m.vertices]
            ev.to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


lo, hi = bounds()
center = (lo + hi) / 2
size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
# 바닥 가운데를 원점으로
pivot.location = Vector((-center.x, -center.y, -lo.z))
height = hi.z - lo.z

# 카메라: 살짝 위에서 내려다봄
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
dist = size * 2.6
target = Vector((0, 0, height * 0.48))
cam.location = target + Vector((0, -dist, dist * 0.32))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam


def light(name, kind, energy, loc, color=(1, 1, 1), size_=None):
    d = bpy.data.lights.new(name, kind)
    d.energy = energy
    d.color = color
    if size_ is not None and hasattr(d, "size"):
        d.size = size_
    o = bpy.data.objects.new(name, d)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, height * 0.5)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o)


s = size
light("Key", "AREA", 260 * s * s, (s * 1.6, -s * 2.0, s * 2.2), (1.0, 1.0, 1.0), s * 1.5)
light("Fill", "AREA", 110 * s * s, (-s * 2.2, -s * 1.2, s * 1.0), (0.85, 0.9, 1.0), s * 2.0)
light("Rim", "AREA", 220 * s * s, (0, s * 2.2, s * 2.0), (1.0, 1.0, 1.0), s * 1.5)

world = bpy.data.worlds.new("W")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.55, 0.57, 0.62, 1)
bg.inputs[1].default_value = 0.35
scene.world = world

for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        continue
try:
    scene.eevee.taa_render_samples = 32
except Exception:
    pass
scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = -0.45
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.resolution_x = scene.render.resolution_y = SIZE

for i in range(FRAMES):
    if anim_len > 1:
        scene.frame_set(anim_start + (i % anim_len))
    pivot.rotation_euler = (0, 0, math.radians(START + 360.0 * i / FRAMES))
    scene.render.filepath = os.path.join(OUT_DIR, f"f_{i:04d}.png")
    bpy.ops.render.render(write_still=True)
print("[devlog_turntable] ok", OUT_DIR, FRAMES, "anim", anim_len, flush=True)
