"""Skeleton test (검수 10/11, A23-120): keep only the Tripo pieces that Studio parts cannot make well (이미지 생성 3).

  blender --background --factory-startup --python tools/skeleton_keep.py -- <parts.glb> <out_keep.glb> <mode> [k=v ...]

mode house: keeps Door, DoorHw, Awning, WinPane, Glass as they are and cuts from the Body tiles
   Roof (z >= roof_z), Plants (leaf faces + petals around them), Lanterns (box lx0..lx1 |x|, lz0..lz1, y >= ly),
   Dormer (|x| <= dx, dz0..dz1, y >= dy). Everything else of the Body (walls, plinth, stairs, frames, cornice) is dropped:
   the Studio skeleton builds it.
mode tree: keeps the faces above pot_z (foliage + trunk); the pot is built in Studio.
Units are the parts GLB studs (front = +Y in Blender = -Z in Roblox). Prints the kept triangle counts and boxes.
"""
import colorsys
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, kdtree

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, MODE = argv[0], argv[1], argv[2]
P = {k: float(v) for k, v in (a.split("=") for a in argv[3:])}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def face_hsv(o):
    me = o.data
    img = None
    for m in me.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
                img = n.image
    W, H = img.size
    px = np.empty(W * H * img.channels, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(H, W, img.channels)
    uv = me.uv_layers.active.data
    out = []
    for p in me.polygons:
        us = [uv[li].uv for li in p.loop_indices]
        u = sum(x.x for x in us) / len(us)
        v = sum(x.y for x in us) / len(us)
        c = px[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W))), :3]
        out.append(colorsys.rgb_to_hsv(*[lin2srgb(float(x)) for x in c]))
    return np.array(out)


def _drop(me, mask):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if mask[f.index]], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()


def split(o, mask, name):
    """move faces where mask is True into a new object called name (object mode, bmesh); returns it (or None)"""
    if not mask.any():
        return None
    new = o.copy()
    new.data = o.data.copy()
    new.name = new.data.name = name
    bpy.context.scene.collection.objects.link(new)
    _drop(new.data, ~mask)
    _drop(o.data, mask)
    return new


kept = []
if MODE == "house":
    for o in objs:
        if not "_Body_" in o.name:
            kept.append(o)
    bodies = [o for o in objs if "_Body_" in o.name]
    # leaf faces of all bodies for the petal test
    leafpts = []
    data = {}
    for o in bodies:
        hsv = face_hsv(o)
        cen = np.array([o.matrix_world @ p.center for p in o.data.polygons])
        leaf = (hsv[:, 0] * 360 >= 65) & (hsv[:, 0] * 360 <= 165) & (hsv[:, 1] >= 0.25)
        data[o.name] = (hsv, cen, leaf)
        leafpts += list(cen[leaf])
    kd = kdtree.KDTree(len(leafpts))
    for i, c in enumerate(leafpts):
        kd.insert(Vector(c), i)
    kd.balance()
    base = bodies[0].name.split("_Body_")[0]
    def masks(o):
        hsv = face_hsv(o)
        cen = np.array([o.matrix_world @ p.center for p in o.data.polygons])
        x, y, z = cen[:, 0], cen[:, 1], cen[:, 2]
        leaf = (hsv[:, 0] * 360 >= 65) & (hsv[:, 0] * 360 <= 165) & (hsv[:, 1] >= 0.25)
        near_leaf = np.array([len(kd.find_range(Vector(c), P.get("petal_r", 0.4))) >= 5 for c in cen])
        petal = near_leaf & (((hsv[:, 1] < 0.2) & (hsv[:, 2] > 0.75)) | ((hsv[:, 0] * 360 > 180) & (hsv[:, 0] * 360 < 240)))
        roof = z >= P["roof_z"]
        plants = (leaf | petal) & ~roof
        stone = (hsv[:, 1] < 0.2) & (hsv[:, 2] > 0.65)
        lant = ~stone & (np.abs(x) >= P["lx0"]) & (np.abs(x) <= P["lx1"]) & (z >= P["lz0"]) & (z <= P["lz1"]) & (y >= P["ly"]) & ~plants & ~roof
        dorm = (np.abs(x) <= P["dx"]) & (z >= P["dz0"]) & (z <= P["dz1"]) & (y >= P["dy"]) & ~plants & ~roof & ~lant
        return {"Roof": roof, "Plants": plants, "Lanterns": lant, "Dormer": dorm}

    for o in bodies:
        tile = o.name.split("_")[-1]
        for nm in ("Roof", "Plants", "Lanterns", "Dormer"):
            if len(o.data.polygons) == 0:
                break
            n = split(o, masks(o)[nm], "%s_%s_%s" % (base, nm, tile))
            if n:
                kept.append(n)
else:  # tree
    for o in objs:
        cen = np.array([o.matrix_world @ p.center for p in o.data.polygons])
        n = split(o, cen[:, 2] >= P["pot_z"], o.name.replace("_Body_", "_Tree_"))
        if n:
            kept.append(n)

bpy.ops.object.select_all(action="DESELECT")
for o in kept:
    o.select_set(True)
    o.data.calc_loop_triangles()
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    print("[keep] %-40s tris %6d  x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f" % (o.name, len(o.data.loop_triangles), min(p.x for p in pts), max(p.x for p in pts),
          min(p.y for p in pts), max(p.y for p in pts), min(p.z for p in pts), max(p.z for p in pts)), flush=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[keep] ok", OUT, flush=True)
