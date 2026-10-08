"""
UV 영역 마스크(색 이동 도우미, 2026-10-08): GLB 모델에서 위치 상자 안에 있는 면들을 텍스처(UV) 위에 흰색으로 칠한 마스크 PNG.
같은 색인데 부위가 다른 곳(게시판 지붕 대 바닥 이끼, 다리 기둥 꼭지 대 아래 돌 아치)을 tools/retex_hue.py 규칙에서 나눌 때 쓴다.

  py tools/uv_region_mask.py <in.glb> <out.png> --box X0,X1,Y0,Y1,Z0,Z1 [--box ...] [--nz A,B] [--size 1024] [--grow 3]

- 상자 숫자는 모델 크기를 0~1로 둔 비율(Blender 축, Z = 위). 면 가운데가 상자 하나라도 안에 들면 칠한다.
- --nz A,B: 면 법선의 위쪽 성분(Z)이 A~B인 면만(지붕 = 비탈면, 벽의 엠블럼 = 세로면 나누기).
- --grow: 마스크를 몇 픽셀 넓힘(UV 섬 가장자리 틈 메우기).
안에서 Blender(배경)를 불러 UV 삼각형을 뽑고(JSON), 여기서 cv2로 칠한다.
"""
import json
import os
import subprocess
import sys
import tempfile

BLENDER = r"C:\Users\glori\Tools\blender-5.2.2-windows-x64\blender.exe"

try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False


def blender_export(glb, boxes, out_json, nz=(-2.0, 2.0)):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    span = hi - lo
    tris = []
    for o in meshes:
        me = o.data
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        if uv is None:
            continue
        mw = o.matrix_world
        for poly in me.polygons:
            c = mw @ poly.center
            n = [(c[i] - lo[i]) / span[i] if span[i] > 0 else 0.5 for i in range(3)]
            if not any(b[0] <= n[0] <= b[1] and b[2] <= n[1] <= b[3] and b[4] <= n[2] <= b[5] for b in boxes):
                continue
            wn = (mw.to_3x3() @ poly.normal).normalized()
            if not (nz[0] <= wn.z <= nz[1]):
                continue
            tris.append([[uv[li].uv[0], uv[li].uv[1]] for li in poly.loop_indices])
    json.dump({"polys": tris, "size": [span.x, span.y, span.z]}, open(out_json, "w"))


def main():
    if IN_BLENDER:
        argv = sys.argv[sys.argv.index("--") + 1:]
        blender_export(argv[0], json.loads(argv[1]), argv[2], json.loads(argv[3]) if len(argv) > 3 else (-2.0, 2.0))
        return
    import argparse

    import cv2
    import numpy as np
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("out")
    ap.add_argument("--box", action="append", required=True)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--grow", type=int, default=3)
    ap.add_argument("--nz", default="-2,2", help="면 방향 위쪽 성분 범위(월드 법선 z): 지붕만 '0.35,1', 벽만 '-0.3,0.3'")
    a = ap.parse_args()
    boxes = [[float(v) for v in b.split(",")] for b in a.box]
    tmp = os.path.join(tempfile.gettempdir(), "uv_region_%d.json" % os.getpid())
    subprocess.run([BLENDER, "--background", "--factory-startup", "--python", os.path.abspath(__file__), "--",
                    a.glb, json.dumps(boxes), tmp, json.dumps([float(v) for v in a.nz.split(",")])], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    d = json.load(open(tmp))
    os.remove(tmp)
    S = a.size
    m = np.zeros((S, S), np.uint8)
    for p in d["polys"]:
        q = np.array([[u * S, (1 - v) * S] for u, v in p], np.float32)
        cv2.fillPoly(m, [np.round(q).astype(np.int32)], 255)
    if a.grow > 0:
        m = cv2.dilate(m, np.ones((2 * a.grow + 1, 2 * a.grow + 1), np.uint8))
    cv2.imwrite(a.out, m)
    print("[uv_region_mask]", json.dumps({"glb": a.glb, "out": a.out, "faces": len(d["polys"]),
                                          "cover": round(float((m > 0).mean()), 4), "model_size": d["size"]}))


main()
