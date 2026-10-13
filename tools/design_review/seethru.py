"""See-through check for a finished Tripo model (A23-174 PBR gate, magenta test).
Roblox draws MeshParts one-sided, so a hole or open seam shows the world behind it.
Each view is rendered twice on a magenta (1,0,1) background: A = backface culling OFF (silhouette),
B = culling ON (Roblox-like). Pixels magenta in B but not in A = see-through spots -> <label>__hole_<view>.png
(B with the spots painted bright green) + counts. Also prints open edges / loose pieces.
blender --background --factory-startup --python seethru.py -- <out_dir> <px> <file[:front]> ...
front = -y (default .glb) or +x (default .fbx, raw Tripo). Use repo-relative paths (glTF import KeyError otherwise).
Sheet: py tools/design_review/seethru_sheet.py <out_dir> <label> ...
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out, px = os.path.abspath(a[0]), int(a[1])
os.makedirs(out, exist_ok=True)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    else:
        bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    openE = parts = tris = 0
    for o in obs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)  # glTF splits verts at UV/normal seams
        openE += sum(1 for e in bm.edges if e.is_boundary)
        tris += sum(len(f.verts) - 2 for f in bm.faces)
        seen = set()
        for v in bm.verts:
            if v.index in seen:
                continue
            parts += 1
            st = [v]
            while st:
                x = st.pop()
                if x.index in seen:
                    continue
                seen.add(x.index)
                st.extend(e.other_vert(x) for e in x.link_edges)
        bm.free()
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = sc.render.resolution_y = px
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (1, 0, 1, 1)
    bg.inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    mats = {s.material for o in obs for s in o.material_slots if s.material}
    return sc, cam, sun, lo, hi, mats, (openE, parts, tris)


def cull(mats, on):
    for m in mats:
        m.use_backface_culling = on
        if hasattr(m, "use_backface_culling_shadow"):
            m.use_backface_culling_shadow = False


def shoot(sc, cam, sun, lo, hi, d, fp):
    ctr = (lo + hi) / 2
    d = d.normalized()
    cam.location = ctr + d * max(hi - lo) * 4
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = (hi - lo).length * 1.05
    sun.rotation_euler = cam.rotation_euler
    sc.render.filepath = fp
    bpy.ops.render.render(write_still=True)


def magenta(p):
    return p[0] > 0.9 and p[1] < 0.1 and p[2] > 0.9


for spec in a[2:]:
    path, _, front = spec.partition(":")
    front = front or ("-y" if path.lower().endswith(".glb") else "+x")
    label = os.path.splitext(os.path.basename(path))[0]
    F = {"-y": Vector((0, -1, 0)), "+x": Vector((1, 0, 0)), "+y": Vector((0, 1, 0)), "-x": Vector((-1, 0, 0))}[front]
    R = F.cross(Vector((0, 0, 1)))
    U = Vector((0, 0, 1))
    views = {}
    for k, az in enumerate((0, 90, 180, 270)):  # front, right, back, left; level, from above, from below
        h = F * math.cos(math.radians(az)) + R * math.sin(math.radians(az))
        views[f"s{az}"] = h + U * 0.15
        views[f"u{az}"] = h + U * 1.0
        views[f"d{az}"] = h - U * 0.8
    views["top"] = U + F * 0.02
    views["bot"] = -U + F * 0.02
    sc, cam, sun, lo, hi, mats, (openE, parts, tris) = load(path)
    res = []
    for k, d in views.items():
        fa = os.path.join(out, f"_{label}_{k}_A.png")
        fb = os.path.join(out, f"{label}__see_{k}.png")
        cull(mats, False)
        shoot(sc, cam, sun, lo, hi, d, fa)
        cull(mats, True)
        shoot(sc, cam, sun, lo, hi, d, fb)
        A = bpy.data.images.load(fa)
        B = bpy.data.images.load(fb)
        pa, pb = list(A.pixels), list(B.pixels)
        n = len(pa) // 4
        holes = 0
        body = 0
        for i in range(n):
            qa = pa[i * 4:i * 4 + 3]
            if magenta(qa):
                continue
            body += 1
            if magenta(pb[i * 4:i * 4 + 3]):
                holes += 1
                pb[i * 4:i * 4 + 4] = (0.0, 1.0, 0.2, 1.0)
        B.pixels[:] = pb
        B.filepath_raw = os.path.join(out, f"{label}__hole_{k}.png")
        B.file_format = "PNG"
        B.save()
        os.remove(fa)
        res.append((k, holes, body))
    worst = max(res, key=lambda t: t[1])
    print("SEETHRU", label, "open_edges", openE, "pieces", parts, "tris", tris,
          "| holes(px)", " ".join(f"{k}:{h}" for k, h, _ in res),
          "| worst", worst[0], f"{100.0 * worst[1] / max(1, worst[2]):.3f}%")
