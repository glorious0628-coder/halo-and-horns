"""Flatten a face relief that Tripo sculpted on a monster's BACK (A23-81: the slime cube shows embossed eyes / cheeks
on its back even with a plain texture). Blender, 0 credits. The model faces +X (Tripo API), so the back is -X.

  blender --background --factory-startup --python tools/img2/mon_back_flatten.py -- <in.glb> <out.glb>
          [--depth 0.22] [--ymax 0.42] [--zlo 0.12] [--zhi 0.85] [--iters 40]

Back-region vertices (x within --depth * X-size of the back, |y - cy| < ymax * Y-size, z between zlo and zhi of the
height, normal pointing backwards) are smoothed in X only (each x moves to its neighbours' mean, the region border
fixed), so bumps sink into the surrounding surface while the outline (y, z) and the UVs stay. Front untouched.
"""
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], argv[1]


def opt(name, d):
    return float(argv[argv.index(name) + 1]) if name in argv else d


DEPTH, YMAX, ZLO, ZHI, ITERS = opt("--depth", 0.22), opt("--ymax", 0.42), opt("--zlo", 0.12), opt("--zhi", 0.85), int(opt("--iters", 40))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
size = hi - lo
cy = (lo.y + hi.y) / 2
total = 0
for o in meshes:
    mw, mi = o.matrix_world, o.matrix_world.inverted()
    bm = bmesh.new()
    bm.from_mesh(o.data)
    # glTF import splits vertices at UV seams; weld them first (UVs live on loops, so they stay) or the seams crack
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    sel = set()
    for v in bm.verts:
        w = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        if (w.x < lo.x + DEPTH * size.x and abs(w.y - cy) < YMAX * size.y
                and lo.z + ZLO * size.z < w.z < lo.z + ZHI * size.z and n.x < 0.9):
            sel.add(v.index)
    # 1) smooth surface x = f(y, z): quadratic fit over the region, bumps rejected as outliers (3 rounds)
    import numpy as np
    ids = sorted(sel)
    P = np.array([tuple(mw @ bm.verts[i].co) for i in ids])
    Y, Z, X = P[:, 1], P[:, 2], P[:, 0]

    def basis(y, z):
        return np.stack([np.ones_like(y), y, z, y * y, y * z, z * z, y ** 3, z ** 3, y * y * z, y * z * z], -1)
    keep = np.ones(len(ids), bool)
    for _ in range(3):
        coef, *_ = np.linalg.lstsq(basis(Y[keep], Z[keep]), X[keep], rcond=None)
        res = X - basis(Y, Z) @ coef
        keep = np.abs(res) < 2.0 * np.median(np.abs(res[keep])) + 1e-6
    # 2) relax folds: y / z Laplacian inside the region, then put x on the fitted surface; region border stays
    border = {i for i in sel if any(e.other_vert(bm.verts[i]).index not in sel for e in bm.verts[i].link_edges)}
    inner = [i for i in ids if i not in border]
    pos = {v.index: np.array(tuple(mw @ v.co)) for v in bm.verts}
    nbr = {i: [e.other_vert(bm.verts[i]).index for e in bm.verts[i].link_edges] for i in inner}
    for _ in range(ITERS):
        for i in inner:
            m = np.mean([pos[j] for j in nbr[i]], 0)
            pos[i][1] = 0.5 * pos[i][1] + 0.5 * m[1]
            pos[i][2] = 0.5 * pos[i][2] + 0.5 * m[2]
            pos[i][0] = float(basis(np.array([pos[i][1]]), np.array([pos[i][2]])) @ coef)
    for i in inner:
        bm.verts[i].co = mi @ Vector(pos[i])
    sel = inner
    bm.to_mesh(o.data)
    bm.free()
    # the glTF's custom normals still carry the old relief: drop them and shade smooth from the new geometry
    if o.data.has_custom_normals:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for poly in o.data.polygons:
        poly.use_smooth = True
    total += len(sel)
print("[mon_back_flatten] smoothed verts", total, flush=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
print("[mon_back_flatten] ok", OUT, flush=True)
