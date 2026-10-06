"""
Tripo 모델에 '진짜 3D 눈'을 얹는다 (A23-47: 3D는 Tripo, 눈은 검수가 손봄).

  blender --background --factory-startup --python tools/fix_eyes_geo.py -- <in.glb> <out.glb> <work_dir> [--dark 0.37] [--depth 0.55] [--hl1 -0.36,0.38,0.30] [--hl2 0.36,-0.40,0.13]

왜: 로블록스는 텍스처를 1024로 줄여 넣어서, 텍스처에 칠한 눈은 흐리고 하이라이트가 각져 보인다.
어떻게:
1. 텍스처에서 어두운 눈 픽셀이 칠해진 면(입 안 진한 빨강 제외)을 찾아 3D 위치로 두 덩어리(두 눈)로 나눈다.
2. 덩어리마다 표면 방향에 맞춘 납작한 타원체(반들반들한 검은 눈)를 칠한 눈보다 조금 크게 얹고,
   그 위에 흰 하이라이트 타원체 2개(큰 것 왼쪽 위, 작은 것 오른쪽 아래 — 시안과 같은 자리)를 붙인다.
3. 텍스처의 빈 곳(UV가 안 쓰는 칸)에 검정·흰색 작은 칸을 칠하고 눈 메시의 UV를 그 칸 가운데로 보낸다.
4. 원래 메시에 합쳐서 메시 하나·재질 하나·텍스처 하나로 내보낸다(게임 CustomModels 그대로).
--hl1/--hl2 = 하이라이트 위치(가로·세로, 눈 반지름 단위)와 크기. 보는 사람 기준 왼쪽이 -.
"""

import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT_GLB, WORK = argv[0], argv[1], argv[2]
opt = {argv[i][2:]: argv[i + 1] for i in range(3, len(argv) - 1) if argv[i].startswith("--")}
DARK = float(opt.get("dark", 0.37))
DEPTH = float(opt.get("depth", 0.55))  # eye depth as a fraction of its smaller radius
HL1 = [float(x) for x in opt.get("hl1", "-0.36,0.38,0.30").split(",")]
HL2 = [float(x) for x in opt.get("hl2", "0.36,-0.40,0.13").split(",")]
BASE_TRIS = int(opt.get("base-tris", 14000))  # Roblox mesh limit is about 20k triangles; eyes add ~2k
os.makedirs(WORK, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
mat = me.materials[0]
img = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE").image
TW, TH = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(TH, TW, 4)  # bottom-up rows
if BASE_TRIS:
    now = sum(len(p.vertices) - 2 for p in me.polygons)
    if now > BASE_TRIS:
        bpy.context.view_layer.objects.active = obj
        dm = obj.modifiers.new("Dec", "DECIMATE")
        dm.ratio = BASE_TRIS / now
        bpy.ops.object.modifier_apply(modifier=dm.name)
        me = obj.data
uvl = me.uv_layers.active.data
mw = obj.matrix_world

# ---- 1. eye faces -> two clusters -----------------------------------------------------------
eye_faces, cov = [], []
for p in me.polygons:
    uvs = [uvl[li].uv for li in p.loop_indices]
    cov.append([(u.x, u.y) for u in uvs])
    u = sum(t.x for t in uvs) / len(uvs)
    v = sum(t.y for t in uvs) / len(uvs)
    r, g, b, _ = px[min(TH - 1, max(0, int(v * TH))), min(TW - 1, max(0, int(u * TW)))]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx < DARK and (mx - mn) < 0.22:
        eye_faces.append(p.index)
if len(eye_faces) < 20:
    sys.exit("[fix_eyes_geo] no eyes found")
cent = np.array([tuple(mw @ me.polygons[i].center) for i in eye_faces])
area = np.array([me.polygons[i].area for i in eye_faces])
nrm = np.array([tuple((mw.to_3x3() @ me.polygons[i].normal).normalized()) for i in eye_faces])
spread = cent.max(axis=0) - cent.min(axis=0)
ax = int(np.argmax(spread))  # the two eyes lie side by side along the widest axis
c0, c1 = cent[np.argmin(cent[:, ax])], cent[np.argmax(cent[:, ax])]
for _ in range(25):
    gsel = np.linalg.norm(cent - c1, axis=1) < np.linalg.norm(cent - c0, axis=1)
    c0 = np.average(cent[~gsel], axis=0, weights=area[~gsel])
    c1 = np.average(cent[gsel], axis=0, weights=area[gsel])
groups = [np.where(~gsel)[0], np.where(gsel)[0]]

# ---- 2. free texture cells for solid black / white --------------------------------------------
COVN = 1024
covmask = np.zeros((COVN, COVN), bool)  # row 0 = top of the image
for poly in cov:
    P = np.array([[u * COVN, (1 - v) * COVN] for u, v in poly], np.float64)
    for k in range(1, len(P) - 1):  # fan-triangulate, rasterise each triangle
        a_, b_, c_ = P[0], P[k], P[k + 1]
        x0, x1 = int(max(0, min(a_[0], b_[0], c_[0]) - 1)), int(min(COVN - 1, max(a_[0], b_[0], c_[0]) + 1))
        y0, y1 = int(max(0, min(a_[1], b_[1], c_[1]) - 1)), int(min(COVN - 1, max(a_[1], b_[1], c_[1]) + 1))
        if x1 < x0 or y1 < y0:
            continue
        yy_, xx_ = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
        def e(p, q):
            return (q[0] - p[0]) * (yy_ - p[1]) - (q[1] - p[1]) * (xx_ - p[0])
        w0, w1, w2 = e(b_, c_), e(c_, a_), e(a_, b_)
        ins = ((w0 >= -1) & (w1 >= -1) & (w2 >= -1)) | ((w0 <= 1) & (w1 <= 1) & (w2 <= 1))
        covmask[y0:y1 + 1, x0:x1 + 1] |= ins
# grow coverage by 6 cells, then look for cells whose 13x13 neighbourhood is empty
grown = covmask.copy()
for _ in range(6):
    g2 = grown.copy()
    g2[1:] |= grown[:-1]; g2[:-1] |= grown[1:]; g2[:, 1:] |= grown[:, :-1]; g2[:, :-1] |= grown[:, 1:]
    grown = g2
ii = np.cumsum(np.cumsum(grown.astype(np.int32), 0), 1)
K = 13
box = ii[K:, K:] - ii[:-K, K:] - ii[K:, :-K] + ii[:-K, :-K]
free = np.argwhere(box == 0) + K // 2 + 1  # (row, col) centres of empty KxK blocks
if len(free) < 2:
    sys.exit("[fix_eyes_geo] no free texture cell")
cells = [free[0]]
for f_ in free[1:]:
    if np.abs(f_ - cells[0]).max() > 16:
        cells.append(f_)
        break


def paint_cell(rc, col):
    r_, c_ = int(rc[0]), int(rc[1])
    s = TW // COVN
    y0 = TH - (r_ + 5) * s
    x0 = (c_ - 5) * s
    px[max(0, y0):y0 + 10 * s, max(0, x0):x0 + 10 * s, :3] = col
    return ((c_ + 0.5) / COVN, 1 - (r_ + 0.5) / COVN)


DARK_RGB = (0.055, 0.045, 0.05)
uv_dark = paint_cell(cells[0], DARK_RGB)
uv_white = paint_cell(cells[1], (0.97, 0.97, 0.97))
img.pixels[:] = px.ravel()
img.update()

# ---- 3. eye + highlight ellipsoids -----------------------------------------------------------
bm = bmesh.new()
uvlay = bm.loops.layers.uv.new("UVMap")
info = []


def ellipsoid(centre, ex, ey, ez, rx, ry, rz, uv, seg=28, rings=14):
    verts = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        row = []
        for j in range(seg):
            ph = 2 * math.pi * j / seg
            p = centre + ex * (rx * math.sin(th) * math.cos(ph)) + ey * (ry * math.sin(th) * math.sin(ph)) + ez * (rz * math.cos(th))
            row.append(bm.verts.new(Vector(tuple(p))))
        verts.append(row)
    for i in range(rings):
        for j in range(seg):
            a, b = verts[i][j], verts[i][(j + 1) % seg]
            c, d = verts[i + 1][(j + 1) % seg], verts[i + 1][j]
            try:
                f = bm.faces.new((a, d, c, b))
            except ValueError:
                continue
            for lp in f.loops:
                lp[uvlay].uv = uv
    return verts


VW = np.array([tuple(mw @ v.co) for v in me.vertices])

for gi, idx in enumerate(groups):
    w = area[idx]
    c = np.average(cent[idx], axis=0, weights=w)
    n = np.average(nrm[idx], axis=0, weights=w)
    n /= np.linalg.norm(n)
    up = np.array([0, 0, 1.0]) - n * n[2]
    up /= np.linalg.norm(up)
    right = np.cross(up, n)  # viewer's right: forward(-n) x up = up x n (viewer stands on +n)
    right /= np.linalg.norm(right)
    vs = np.array([tuple(mw @ me.vertices[vi].co) for fi in np.array(eye_faces)[idx] for vi in me.polygons[fi].vertices])
    du, dv = (vs - c) @ right, (vs - c) @ up
    lo_u, hi_u = np.percentile(du, 2), np.percentile(du, 98)
    lo_v, hi_v = np.percentile(dv, 2), np.percentile(dv, 98)
    ru, rv = (hi_u - lo_u) / 2 * 1.04, (hi_v - lo_v) / 2 * 1.04
    c = c + right * (hi_u + lo_u) / 2 + up * (hi_v + lo_v) / 2
    # sit the eye just high enough that its dome covers every face vertex inside the ellipse (no painted eye shows)
    rz = DEPTH * min(ru, rv)
    d = VW - c
    uu, vv, hh = d @ right, d @ up, d @ n
    r2 = (uu / ru) ** 2 + (vv / rv) ** 2
    near = (r2 < 1.0) & (hh > -1.5 * max(ru, rv))
    dome = rz * np.sqrt(np.clip(1.0 - r2[near], 0.0784, 1.0))
    off = float(np.max(hh[near] + 0.06 * rz - dome)) if near.any() else 0.0
    centre = c + n * off
    ellipsoid(centre, right, up, n, ru, rv, rz, uv_dark, seg=24, rings=12)
    for hx, hy, hs in (HL1, HL2):
        x, y = hx * ru, hy * rv
        k = max(0.0, 1 - (hx ** 2 + hy ** 2))
        z = rz * math.sqrt(k)
        hc = centre + right * x + up * y + n * (z * 0.98)
        hr = hs * ru
        ellipsoid(hc, right, up, n, hr, hr * (rv / ru) ** 0.3, hr * 0.32, uv_white, seg=16, rings=8)
    info.append({"centre": [round(float(t), 4) for t in c], "ru": round(float(ru), 4), "rv": round(float(rv), 4),
                 "depth": round(float(rz), 4), "faces": int(len(idx))})

eye_me = bpy.data.meshes.new("Eyes")
bm.to_mesh(eye_me)
bm.free()
eye_me.materials.append(mat)
eye_ob = bpy.data.objects.new("Eyes", eye_me)
bpy.context.scene.collection.objects.link(eye_ob)
# eye mesh is in world space; bring it into the model's space so join keeps the model's own transform
eye_ob.matrix_world = obj.matrix_world.copy()
eye_me.transform(obj.matrix_world.inverted())
for poly in eye_me.polygons:
    poly.use_smooth = True

bpy.ops.object.select_all(action="DESELECT")
eye_ob.select_set(True)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.join()
img.pack()
bpy.ops.export_scene.gltf(filepath=OUT_GLB, use_selection=True, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=92)
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
json.dump({"eye_faces": len(eye_faces), "eyes": info, "tris_after": tris, "uv_dark": uv_dark, "uv_white": uv_white},
          open(os.path.join(WORK, "eyes_geo.json"), "w"), indent=1)
print("[fix_eyes_geo] ok", OUT_GLB, "tris", tris, json.dumps(info), flush=True)
