"""
되풀이 이음 확인용(2026-10-08, 교차로 광장 담): 모듈 조각 GLB를 폭 W 스터드로 맞추고, 끝 기둥이 겹치게 N개 이어 붙여 GLB 하나로.

  blender --background --factory-startup --python-exit-code 1 --python tools/tile_row_glb.py -- <in.glb> <out.glb> [--width 8] [--count 3] [--post auto|<studs>]

- 입력 앞 = -Y(웹 GLB를 glb_decimate.py --rotz -90 으로 돌린 것), 이어 붙이는 방향 = X.
- --post auto: 맨 위 8% 높이에 있는 꼭짓점(끝 기둥 머리)의 X 범위로 왼쪽 기둥 폭을 재고, 그만큼 겹쳐 놓는다(기둥 하나를 같이 씀).
- 결과 JSON(stdout): 폭·높이·깊이, 기둥 폭, 간격. 크기는 렌더 확인용이고 실제 배치 크기는 worldkit_combine.py fit으로 정한다.
"""
import json
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], argv[1]
opt = {"width": "8", "count": "3", "post": "auto"}
for i in range(2, len(argv), 2):
    opt[argv[i][2:]] = argv[i + 1]
W, N = float(opt["width"]), int(opt["count"])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
vs = [v.co.copy() for v in obj.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
s = W / (hi.x - lo.x)
obj.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
obj.data.transform(Matrix.Diagonal((s, s, s, 1.0)))
vs = [v.co.copy() for v in obj.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
if opt["post"] == "auto":
    top = [v.x for v in vs if v.z > hi.z - 0.08 * (hi.z - lo.z)]
    left = [x for x in top if x < (lo.x + hi.x) / 2]
    post = (max(left) - lo.x) if left else 0.0
else:
    post = float(opt["post"])
step = (hi.x - lo.x) - post
for k in range(1, N):
    dup = obj.copy()
    dup.data = obj.data
    dup.location = (k * step, 0, 0)
    bpy.context.scene.collection.objects.link(dup)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_image_format="AUTO")
print("[tile_row_glb]", json.dumps({"width": round(hi.x - lo.x, 2), "depth": round(hi.y - lo.y, 2), "height": round(hi.z - lo.z, 2),
                                     "post": round(post, 2), "step": round(step, 2), "count": N}), flush=True)
