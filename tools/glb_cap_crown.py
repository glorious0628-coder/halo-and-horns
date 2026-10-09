"""
Cap the open pit of the Crown Shrine (Tripo left the crown's top hollow), 0 credits (A23-84, 검수 2026-10-09).

  blender --background --factory-startup --python tools/glb_cap_crown.py -- <in.glb> <out.glb> [--z 0.085] [--r 0.185] [--rim 0.22,0.30]

Adds a flat round stone floor a little below the rim top (default z 0.085 vs rim 0.10, pit radius 0.16) and gives it
the UV of a stone-ring texel on the rim top, so the model keeps one material and one texture. Model units, Z up.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], os.path.abspath(argv[1])


def opt(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


Z = float(opt("--z", "0.085"))
RAD = float(opt("--r", "0.185"))
R0, R1 = (float(v) for v in opt("--rim", "0.22,0.30").split(","))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
uvl = me.uv_layers.active
# pick a stone texel: the rim-top face (normal up, near Z-0.10, radius R0..R1) whose UV is the most grey/light
img = None
for m in me.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                break
    if img:
        break
w, h = img.size
px = list(img.pixels)


def col(u, v):
    x = min(w - 1, max(0, int(u * w)))
    y = min(h - 1, max(0, int(v * h)))
    i = (y * w + x) * 4
    return px[i], px[i + 1], px[i + 2]


cands = []
for p in me.polygons:
    c = obj.matrix_world @ p.center
    r = math.hypot(c.x, c.y)
    if p.normal.z > 0.85 and 0.085 < c.z < 0.115 and R0 < r < R1:
        u = sum(uvl.data[l].uv.x for l in p.loop_indices) / len(p.loop_indices)
        v = sum(uvl.data[l].uv.y for l in p.loop_indices) / len(p.loop_indices)
        r_, g_, b_ = col(u, v)
        if g_ - max(r_, b_) < 0.04:  # skip mossy faces
            cands.append((u, v, (r_, g_, b_)))
avg = [sum(c[2][i] for c in cands) / len(cands) for i in range(3)]
cands.sort(key=lambda c: sum(c[2]))
PCT = float(opt("--pct", "0.8"))  # brightness percentile of the rim-top stone texels
c0 = cands[min(len(cands) - 1, int(len(cands) * PCT))]
best = (0, c0[0], c0[1], c0[2])
print("[cap] texel", best)
# a moss texel: the greenest sample among the upward faces on the rim and teeth
moss = None
for p in me.polygons:
    c = obj.matrix_world @ p.center
    if p.normal.z > 0.3 and c.z > 0.08:
        u = sum(uvl.data[l].uv.x for l in p.loop_indices) / len(p.loop_indices)
        v = sum(uvl.data[l].uv.y for l in p.loop_indices) / len(p.loop_indices)
        r_, g_, b_ = col(u, v)
        g_score = g_ - max(r_, b_)
        if moss is None or g_score > moss[0]:
            moss = (g_score, u, v, (r_, g_, b_))
print("[cap] moss", moss)
_, U, V, _c = best

bm = bmesh.new()
bm.from_mesh(me)
uv = bm.loops.layers.uv.active
N = 64
cen = bm.verts.new((0, 0, Z))
ring = [bm.verts.new((RAD * math.cos(2 * math.pi * i / N), RAD * math.sin(2 * math.pi * i / N), Z)) for i in range(N)]
for i in range(N):
    f = bm.faces.new((cen, ring[i], ring[(i + 1) % N]))
    f.material_index = 0
    for l in f.loops:
        l[uv].uv = (U, V)
# moss blobs on the floor: small flat ellipses a hair above it (fixed layout, no random)
BLOBS = [(0.12, 0.09, 0.03), (-0.13, 0.05, 0.026), (0.02, -0.15, 0.032), (-0.09, -0.11, 0.02), (0.14, -0.05, 0.02)]
for bx, by, br in BLOBS:
    bc = bm.verts.new((bx, by, Z + 0.002))
    ring2 = []
    for i in range(14):
        a = 2 * math.pi * i / 14
        k = 1.0 + 0.25 * math.sin(3 * a + bx * 40)
        ring2.append(bm.verts.new((bx + br * k * math.cos(a), by + br * 0.8 * k * math.sin(a), Z + 0.002)))
    for i in range(14):
        f = bm.faces.new((bc, ring2[i], ring2[(i + 1) % 14]))
        f.material_index = 0
        for l in f.loops:
            l[uv].uv = (moss[1], moss[2])
bm.normal_update()
bm.to_mesh(me)
bm.free()
me.update()
# make the new faces point up
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
for f in list(bm.faces)[-(N + 14 * 5):]:
    if f.normal.z < 0:
        f.normal_flip()
bm.to_mesh(me)
bm.free()
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="AUTO", export_apply=True)
print("[cap] wrote", OUT, flush=True)
