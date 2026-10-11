"""Tripo HD decorations -> cut -> Blender fix -> onto the Studio skeleton slots (SPEC A23-125, 검수 10/11: "장식은 Tripo HD에서
잘라 Blender", metal_ornaments from scratch is not a final), 이미지 생성 3, 10/11.

  blender --background --factory-startup --python tools/house_deco.py -- <name> <params.json> <out.glb> [--report <json>]

Sources: art/models/tripo/halo_houses/<name>/<name>_parts.glb (the house's own Tripo HD multiview model, split into
Door / DoorHw / Awning / WinPane / Glass / Body_tXY with their maps), slots = build/skel_<name>_ornaments.json
(tools/skeleton_house.py: where the skeleton wants its leaf, lanterns, domes). Read the cut boxes off
tools/tripo_ortho.py grids (GLB frame: front = +Y, z up, studs) and write them into tools/house_deco/<name>.json:

  "dome":    {"c": [x, y], "z": [z0, z1], "r": max radius, "slot": "Dome" | "CupolaDome", "no_white": true}
             faces inside that cylinder (pale stone faces skipped) -> ROUND fix: per height band the circle centre is
             fitted (Kasa) and moved onto one vertical axis (a leaning finial / lopsided dome straightened), then the
             radius is divided by its own low-order (k = 1, 2) Fourier fit around that axis, so the outline is a true
             circle at every height while the ribs (k >= 6) and tile detail stay; uniform scale so the base radius
             (the widest of the lowest 12 %) = slot R, base on the slot's z.
             "fix": "oct" instead: an octagonal dome is scaled by its eave width onto the plan octagon (moved by "offset",
             default -0.6) and then warped by tools/roof_fit.py (eaves straight on the octagon, ribs on the corners).
  "caps":    {"src": {"c", "z", "r"}, "slots": ["TowerDome0", ...], "fit": "R" | "house"} one tower cap / finial,
             ROUND fix as above; one template <name>_Cap<i> (axis on the origin, base z 0) copied onto every slot after
             piece_fix (the same piece = symmetric towers, one map set), "fit" R: base radius = slot R, house: the house
             scale (Tripo door -> skeleton leaf).
  "lantern": {"box": [[x0, x1], [y0, y1], [z0, z1]], "keep": "+x" | "-x", "slots": [...], "no_white": true}
             one wall lantern -> MIRROR fix (left-right symmetric about its own centre, the better half kept) -> house
             scale -> template <name>_LanternT (back on y 0, glass centre x 0 / z 0), copied onto each slot (glass centre
             on the slot x / z, back on its wall_y) after piece_fix.
  "door":    {"mirror": bool (default = double door), "keep": "+x" | "-x", "double": bool, "flat": 0.32, "flatten_boxes":
             [[[x0, x1], [y0, y1], [z0, z1]], ...], "cx"/"R"/"bottom"/"top" overrides}  the wooden leaf of the Tripo Door
             object (brown plank faces give its outline; frame / jamb bits outside are dropped) -> MIRROR fix about its
             centre for a double door (hinges and knobs both sides by design) -> outline clamped to an exact round arch
             -> hardware in flatten_boxes pressed onto the planks (an exact metal knocker goes over it) -> depth pressed
             to the leaf thickness -> fitted to the leaf slot (arch scaled by R, jambs stretched), split for a double door.
             NOW (v2): the leaf is rebuilt as an exact arched slab and Tripo's paint / relief is projected onto it
             (tools/proj_bake.py); "knockers": [box, ...] = Tripo knocker spots for the exact metal rings, "knobs": [box,
             ...] = round knobs turned on a lathe with Tripo's paint.
  Domes / caps skip pale faces only below z0 + 0.8 / 0.5 ("white_below"): gold highlights are pale as well.
  Any region also takes "no_leaf": true (skip leaf-green and blue-petal faces) and "drop_boxes": [[[x0, x1], [y0, y1],
             [z0, z1]], ...].
  "extra":   [{"name", "obj": "Awning" | "Body", "box" | "cyl", "only_gold": bool, "no_white": bool, "fix": "round" |
             "mirror" | "none", "move": [dx, dy, dz], "scale": s}]  awning frames, parasols, brick domes ... (house
             scale about the GLB origin, then moved).
Knocker / hinges are not taken from Tripo: tools/metal_ornaments.py exact rings (검수-approved swap) after this.
Output objects are <name>_<Piece>[_tXY] with the Tripo materials; run tools/piece_fix.py on them next (joins the tiles,
drops crumbs, bakes each piece's own C/N/R/M). Custom normals are cleared, sharp edges from 40 degrees.
The out GLB is in the skeleton frame (origin = skeleton origin, front = +Y); the report (default <out>.json) lists the
template copies for tools/house_deco_place.py.
"""
import argparse
import colorsys
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("name")
ap.add_argument("params")
ap.add_argument("out")
ap.add_argument("--report", help="default <out>.json")
a = ap.parse_args(argv)
ROOT = os.environ.get("HH_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # HH_ROOT: run a private copy of tools/
NAME = a.name
PR = json.load(open(a.params, encoding="utf-8"))
SLOTS = {it["name"][len(NAME) + 1:]: it for it in json.load(open(os.path.join(ROOT, "build", "skel_%s_ornaments.json" % NAME)))["items"]}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "tripo", "halo_houses", NAME, NAME + "_parts.glb"))
SRC = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in SRC:
    o.data.transform(o.matrix_world)
    o.matrix_world.identity()
    o.parent = None
REPORT = {"name": NAME, "params": a.params.replace("\\", "/"), "pieces": {}}


def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


_px = {}


def face_hsv(o):
    img = None
    for m in o.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
                img = n.image
    if img is None:
        return np.zeros((len(o.data.polygons), 3))
    if img.name not in _px:
        W, H = img.size
        arr = np.empty(W * H * img.channels, np.float32)
        img.pixels.foreach_get(arr)
        _px[img.name] = arr.reshape(H, W, img.channels)
    px = _px[img.name]
    H, W = px.shape[:2]
    uv = o.data.uv_layers.active.data
    out = []
    for p in o.data.polygons:
        u = sum(uv[li].uv.x for li in p.loop_indices) / p.loop_total
        v = sum(uv[li].uv.y for li in p.loop_indices) / p.loop_total
        c = px[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W))), :3]
        out.append(colorsys.rgb_to_hsv(*[lin2srgb(float(x)) for x in c]))
    return np.array(out).reshape(-1, 3)


def centres(o):
    return np.array([p.center[:] for p in o.data.polygons]).reshape(-1, 3)


def take(o, mask, name):
    """a new object called name with only the faces of o where mask is True (o itself is untouched)"""
    if not mask.any():
        return None
    new = o.copy()
    new.data = o.data.copy()
    new.name = new.data.name = name
    bpy.context.scene.collection.objects.link(new)
    bm = bmesh.new()
    bm.from_mesh(new.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not mask[f.index]], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(new.data)
    bm.free()
    return new


def region_mask(o, reg):
    c = centres(o)
    m = np.ones(len(c), bool)
    if "box" in reg:
        for k, (lo, hi) in enumerate(reg["box"]):
            m &= (c[:, k] >= lo) & (c[:, k] <= hi)
    if "cyl" in reg or "r" in reg:
        cy = reg.get("cyl", reg)
        m &= np.hypot(c[:, 0] - cy["c"][0], c[:, 1] - cy["c"][1]) <= cy["r"]
        m &= (c[:, 2] >= cy["z"][0]) & (c[:, 2] <= cy["z"][1])
    if reg.get("no_white") or reg.get("only_gold") or reg.get("no_leaf"):
        hsv = face_hsv(o)
        h, s, v = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
        if reg.get("no_white"):
            white = (s < 0.2) & (v > 0.6)
            if "white_below" in reg:                # gold highlights are pale too: only the stone band at the foot
                white &= c[:, 2] < reg["white_below"]
            m &= ~white
        if reg.get("no_leaf"):                      # plants growing over a roof piece (leaves, blue petals)
            m &= ~(((h >= 65) & (h <= 165) & (s >= 0.25)) | ((h > 185) & (h < 245) & (s > 0.25)))
        if reg.get("only_gold"):
            m &= (h >= 22) & (h <= 62) & (s >= 0.35) & (v >= 0.35)
    for b in reg.get("drop_boxes", []):
        inb = np.ones(len(c), bool)
        for k, (lo, hi) in enumerate(b):
            inb &= (c[:, k] >= lo) & (c[:, k] <= hi)
        m &= ~inb
    return m


def cut(piece, reg, objs=None):
    """faces of the source objects (default: Body tiles) inside reg -> objects <NAME>_<piece>_<tile>"""
    want = reg.get("obj", "Body")
    out = []
    for o in (objs or SRC):
        if "_%s" % want not in o.name:
            continue
        tile = o.name.split("_")[-1] if "_Body_" in o.name else ""
        n = take(o, region_mask(o, reg), "%s_%s%s" % (NAME, piece, "_" + tile if tile.startswith("t") else ""))
        if n:
            out.append(n)
    return out


def allv(objs):
    return np.concatenate([np.array([v.co[:] for v in o.data.vertices]).reshape(-1, 3) for o in objs]) if objs else np.zeros((0, 3))


def setv(objs, P):
    i = 0
    for o in objs:
        n = len(o.data.vertices)
        o.data.vertices.foreach_set("co", P[i:i + n].astype(np.float32).ravel())
        o.data.update()
        i += n


def apply(objs, M):
    for o in objs:
        o.data.transform(M)
        o.data.update()


def bbox(objs):
    P = allv(objs)
    return P.min(0), P.max(0)


def round_fix(objs, c, bands=36):
    """straighten the axis and make every height band a circle (ribs kept): returns (axis xy, report)"""
    P = allv(objs)
    z0, z1 = P[:, 2].min(), P[:, 2].max()
    edges = np.linspace(z0, z1 + 1e-6, bands + 1)
    zc = (edges[:-1] + edges[1:]) / 2
    cen = np.full((bands, 2), np.nan)
    for b in range(bands):
        q = P[(P[:, 2] >= edges[b]) & (P[:, 2] < edges[b + 1])]
        if len(q) < 12:
            continue
        x, y = q[:, 0], q[:, 1]
        A = np.c_[x, y, np.ones(len(x))]
        sol, *_ = np.linalg.lstsq(A, x * x + y * y, rcond=None)
        cx, cy = sol[0] / 2, sol[1] / 2
        ang = np.arctan2(y - cy, x - cx)
        if np.ptp(np.unwrap(np.sort(ang))) < 4.5:               # less than ~260 degrees of the ring there: not a ring
            continue
        cen[b] = (cx, cy)
    ok = ~np.isnan(cen[:, 0])
    if ok.sum() < 3:
        return np.array(c, float), {"bands_fitted": int(ok.sum()), "note": "too few rings: no round fix"}
    # the axis = the weighted median of the ring centres of the lower half (the dome body), every band moved onto it
    axis = np.median(cen[ok][: max(3, ok.sum() // 2)], 0)
    cx = np.interp(P[:, 2], zc[ok], cen[ok, 0])
    cy = np.interp(P[:, 2], zc[ok], cen[ok, 1])
    lean = float(np.max(np.hypot(cen[ok, 0] - axis[0], cen[ok, 1] - axis[1])))
    P[:, 0] += axis[0] - cx
    P[:, 1] += axis[1] - cy
    # radius: divide by the k = 1, 2 Fourier fit of each band (true circle), keep the k >= 3 detail (ribs)
    r = np.hypot(P[:, 0] - axis[0], P[:, 1] - axis[1])
    th = np.arctan2(P[:, 1] - axis[1], P[:, 0] - axis[0])
    coef = np.full((bands, 5), np.nan)
    for b in range(bands):
        sel = (P[:, 2] >= edges[b]) & (P[:, 2] < edges[b + 1])
        if sel.sum() < 16:
            continue
        t = th[sel]
        A = np.c_[np.ones(sel.sum()), np.cos(t), np.sin(t), np.cos(2 * t), np.sin(2 * t)]
        coef[b], *_ = np.linalg.lstsq(A, r[sel], rcond=None)
    okc = ~np.isnan(coef[:, 0])
    C = np.stack([np.interp(P[:, 2], zc[okc], coef[okc, k]) for k in range(5)], 1)
    fit = C[:, 0] + C[:, 1] * np.cos(th) + C[:, 2] * np.sin(th) + C[:, 3] * np.cos(2 * th) + C[:, 4] * np.sin(2 * th)
    ratio = np.where(fit > 0.05, np.clip(C[:, 0] / np.maximum(fit, 1e-6), 0.8, 1.25), 1.0)
    ecc = float(np.nanmax(np.hypot(coef[okc, 3], coef[okc, 4]) / np.maximum(coef[okc, 0], 1e-3)))
    P[:, 0] = axis[0] + (P[:, 0] - axis[0]) * ratio
    P[:, 1] = axis[1] + (P[:, 1] - axis[1]) * ratio
    setv(objs, P)
    return axis, {"bands_fitted": int(ok.sum()), "axis_lean_max": round(lean, 3), "ellipse_max": round(ecc, 3),
                  "radius_change_max": round(float(np.max(np.abs(ratio - 1))), 3)}


def mirror_fix(o, cx, keep):
    """left-right symmetric about x = cx: the kept half (+x / -x) and its mirror image, welded on the seam"""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-4, plane_co=(cx, 0, 0), plane_no=(1, 0, 0),
                           clear_inner=(keep == "+x"), clear_outer=(keep == "-x"))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    ret = bmesh.ops.duplicate(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:])
    nv = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
    nf = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMFace)]
    M = Matrix.Translation((cx, 0, 0)) @ Matrix.Scale(-1, 4, (1, 0, 0)) @ Matrix.Translation((-cx, 0, 0))
    bmesh.ops.transform(bm, matrix=M, verts=nv)
    bmesh.ops.reverse_faces(bm, faces=nf)
    seam = [v for v in bm.verts if abs(v.co.x - cx) < 2e-3]
    bmesh.ops.remove_doubles(bm, verts=seam, dist=2e-3)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def tidy_normals(objs):
    for o in objs:
        bm = bmesh.new()                           # Tripo shells: some faces wound inwards (dark patches once the
        bm.from_mesh(o.data)                       # imported custom normals are gone)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o]):
            try:
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
            except RuntimeError:
                pass
        o.data.shade_smooth()
        try:
            o.data.set_sharp_from_angle(angle=math.radians(40))
        except (AttributeError, TypeError):
            pass


def join(objs, name):
    """join several cut objects into one (keeps per-tile materials); returns it"""
    objs = [o for o in objs if o and len(o.data.polygons)]
    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = o.data.name = name
    return o


def copy_obj(o, name):
    n = o.copy()
    n.data = o.data.copy()
    n.name = n.data.name = name
    bpy.context.scene.collection.objects.link(n)
    return n


out_objs = []
COPIES = []          # templates (caps, lantern) placed after piece_fix by tools/house_deco_place.py (shared maps)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proj_bake  # noqa: E402

WORK = os.path.join(ROOT, "art", "models", "tripo", "house_deco", NAME)


def lathe_profile(objs, bands=28, samples=40000):
    """outer silhouette r(z) of pieces standing on z 0 round the z axis: area-weighted surface samples, 92nd percentile
    radius per height band, lightly smoothed, closed to a pole on top"""
    pts = []
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        V = np.array([v.co[:] for v in me.vertices])
        T = np.array([t.vertices[:] for t in me.loop_triangles])
        if not len(T):
            continue
        A, B, C = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
        ar = np.linalg.norm(np.cross(B - A, C - A), axis=1) / 2
        n = np.random.default_rng(0).choice(len(T), size=samples // max(len(objs), 1), p=ar / ar.sum())
        u, v = np.random.default_rng(1).random((2, len(n)))
        sw = u + v > 1
        u[sw], v[sw] = 1 - u[sw], 1 - v[sw]
        pts.append(A[n] + (B[n] - A[n]) * u[:, None] + (C[n] - A[n]) * v[:, None])
    P = np.concatenate(pts)
    r = np.hypot(P[:, 0], P[:, 1])
    z = P[:, 2]
    z0, z1 = 0.0, float(z.max())
    edges = np.linspace(z0, z1, bands + 1)
    prof = []
    for b in range(bands):
        sel = (z >= edges[b]) & (z < edges[b + 1] + 1e-9)
        if sel.sum() < 8:
            continue
        prof.append([float(np.percentile(r[sel], 92)), float((edges[b] + edges[b + 1]) / 2)])
    pr = np.array(prof)
    if len(pr) > 3:
        sm = pr[:, 0].copy()
        sm[1:-1] = 0.25 * pr[:-2, 0] + 0.5 * pr[1:-1, 0] + 0.25 * pr[2:, 0]
        pr[:, 0] = sm
    out = [(float(pr[0, 0]), 0.0)] + [(float(a), float(b)) for a, b in pr] + [(0.0, z1)]
    return out


# ------------------------------------------------------------------ house scale: Tripo door leaf -> skeleton leaf
door_src = [o for o in SRC if o.name.endswith("_Door")]
leaf_slots = [v for k, v in SLOTS.items() if v["type"] == "leaf"]


def _textured(o):
    return any(n.type == "TEX_IMAGE" and n.image for m in o.data.materials if m and m.use_nodes for n in m.node_tree.nodes)


def door_leaf_source(D):
    """Tripo's door leaf. The parts split's Door object is often not the leaf (house 03: steps + frame bits; the planks
    sit in the Body tiles), so the leaf is found on all objects: front-facing plank-brown faces near the door (x hint =
    the DoorHw / Door object centre, or D["hint_x"]). Returns (cx, R, bottom, top, y_leaf, source objects) where the
    source objects hold every face of the leaf box (planks + hardware on them) for the projection; D overrides any value."""
    hint_objs = [o for o in SRC if o.name.endswith("_DoorHw")] or door_src
    hx = D.get("hint_x", float(np.mean(allv(hint_objs)[:, 0])) if hint_objs else 0.0)
    pts = []
    for o in SRC:
        if not _textured(o) or "_Glass" in o.name or "_WinPane" in o.name or "_Awning" in o.name:
            continue
        hsv = face_hsv(o)
        c = centres(o)
        nrm = np.array([p_.normal[:] for p_ in o.data.polygons]).reshape(-1, 3)
        h, s_, v = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
        wood = (h >= 10) & (h <= 45) & (s_ >= 0.3) & (v >= 0.18) & (v <= 0.92) & (nrm[:, 1] > 0.6)
        wood &= (np.abs(c[:, 0] - hx) < D.get("hint_r", 3.2)) & (c[:, 2] > 0.2) & (c[:, 2] < 14)
        pts.append(c[wood])
    q = np.concatenate(pts) if pts else np.zeros((0, 3))
    if len(q) < 8:
        q = allv(door_src)
    # the leaf plane: the most common front depth of those faces (drop shelves / pots further out or in)
    yl = D.get("y_leaf", float(np.median(q[:, 1])))
    q = q[np.abs(q[:, 1] - yl) < 0.6]
    x0, x1 = np.percentile(q[:, 0], [2, 98])
    cx = D.get("cx", float((x0 + x1) / 2))
    R = D.get("R", float((x1 - x0) / 2))
    bot = D.get("bottom", float(np.percentile(q[:, 2], 1)))
    top = D.get("top", float(np.percentile(q[:, 2], 99)))
    srcs = []
    for o in SRC:
        if not _textured(o) or "_Glass" in o.name or "_WinPane" in o.name or "_Awning" in o.name:
            continue
        c = centres(o)
        m = (np.abs(c[:, 0] - cx) <= R + 0.15) & (c[:, 2] >= bot - 0.15) & (c[:, 2] <= top + 0.15) & (np.abs(c[:, 1] - yl) < 0.7)
        n = take(o, m, o.name + "_LeafSrc")
        if n:
            srcs.append(n)
    return cx, R, bot, top, yl, srcs


HS = 1.0
if door_src and leaf_slots:
    _cx, _R, _b, _t, _yl, _srcs = door_leaf_source(PR.get("door", {}))
    for _o in _srcs:
        bpy.data.objects.remove(_o)
    ls = leaf_slots[0]
    HS = (ls["c"][1] + ls["R"] - ls["bottom"]) / (_t - _b)
REPORT["house_scale"] = round(HS, 4)

def plan_poly(off):
    """the skeleton's plan polygon (tools/skeleton_house.py, oct / rect) moved out by off studs (in when < 0)"""
    S = json.load(open(os.path.join(ROOT, "tools", "house_specs", NAME + ".json"), encoding="utf-8"))["plan"]
    if S["shape"] == "oct":
        HF, XS, DY, D2 = S["HF"], S["XS"], S["DY"], S["D"] / 2
        V = [(-HF, D2), (-XS, D2 - DY), (-XS, -D2 + DY), (-HF, -D2), (HF, -D2), (XS, -D2 + DY), (XS, D2 - DY), (HF, D2)]
    else:
        W2, D2 = S["W"] / 2, S["D"] / 2
        V = [(-W2, D2), (-W2, -D2), (W2, -D2), (W2, D2)]
    V = np.array(V, float)
    n = len(V)
    area = sum(V[i, 0] * V[(i + 1) % n, 1] - V[(i + 1) % n, 0] * V[i, 1] for i in range(n))
    sgn = 1 if area > 0 else -1                               # outward normal side
    lines = []
    for i in range(n):
        p0, p1 = V[i], V[(i + 1) % n]
        e = (p1 - p0) / np.linalg.norm(p1 - p0)
        nrm = np.array([e[1], -e[0]]) * sgn
        lines.append((p0 + nrm * off, e))
    out = []
    for i in range(n):
        (a0, e0), (a1, e1) = lines[i - 1], lines[i]
        A = np.array([[e0[0], -e1[0]], [e0[1], -e1[1]]])
        t = np.linalg.solve(A, a1 - a0)
        out.append((a0 + e0 * t[0]).tolist())
    return out


# ------------------------------------------------------------------ main dome / cupola dome
if "dome" in PR and PR["dome"].get("fix") == "oct":
    # an octagonal dome: placed by its width onto the plan, then tools/roof_fit.py warps its eaves onto the plan
    # octagon moved by "offset" and its ribs onto the corners (house_deco_run.py runs it)
    d = PR["dome"]
    ps = cut("Dome", dict(d, cyl=d, white_below=d.get("white_below", d["z"][0] + 0.8)))
    if ps:
        P = allv(ps)
        zb = P[:, 2].min()
        low = P[P[:, 2] <= zb + 0.15 * (P[:, 2].max() - zb)]
        poly = plan_poly(d.get("offset", -0.6))
        x0t, x1t = np.percentile(low[:, 0], [1, 99])
        y0t, y1t = np.percentile(low[:, 1], [1, 99])
        ctx, cty = (x0t + x1t) / 2, (y0t + y1t) / 2
        hx_s = max(abs(x) for x, _ in poly)
        hy_s = max(abs(y) for _, y in poly)
        kx, ky = hx_s / ((x1t - x0t) / 2), hy_s / ((y1t - y0t) / 2)
        kz = (kx + ky) / 2
        # left-right symmetric: every vertex's |x - ctx| averaged with its mirror partner is not needed for the fit;
        # the per-axis fit keeps Tripo's 8 facets and ribs and puts its eave box on the plan octagon's box
        sl = SLOTS[d.get("slot", "Dome")]
        apply(ps, Matrix.Translation((sl["pos"][0], sl["pos"][1], sl["pos"][2] + d.get("dz", 0.0))) @
              Matrix.Diagonal((kx, ky, kz, 1.0)) @ Matrix.Translation((-ctx, -cty, -zb)))
        tidy_normals(ps)
        out_objs += ps
        rep = {"fix": "oct: Tripo's octagon box -> the plan octagon box %+.2f (x %.3f, y %.3f, z %.3f), facets / ribs kept" % (
            d.get("offset", -0.6), kx, ky, kz), "faces": sum(len(o.data.polygons) for o in ps)}
        REPORT["pieces"]["Dome"] = rep
        print("[deco] dome (oct)", rep, flush=True)
elif "dome" in PR:
    d = PR["dome"]
    ps = cut("DomeTmp", dict(d, cyl=d, white_below=d.get("white_below", d["z"][0] + 0.8)))
    if ps:
        axis, rep = round_fix(ps, d["c"])
        P = allv(ps)
        zb = P[:, 2].min()
        low = P[P[:, 2] <= zb + 0.12 * (P[:, 2].max() - zb)]
        Rt = float(np.percentile(np.hypot(low[:, 0] - axis[0], low[:, 1] - axis[1]), 98))
        sl = SLOTS[d.get("slot", "Dome")]
        k = sl["R"] / Rt * d.get("r_mul", 1.0)
        M = Matrix.Translation((sl["pos"][0], sl["pos"][1], sl["pos"][2] + d.get("dz", 0.0))) @ Matrix.Scale(k, 4) @ \
            Matrix.Translation((-axis[0], -axis[1], -zb))
        apply(ps, M)
        for o in ps:
            o.name = o.data.name = o.name.replace("DomeTmp", d.get("slot", "Dome"))
        tidy_normals(ps)
        out_objs += ps
        rep.update({"tripo_base_R": round(Rt, 3), "scale": round(k, 4), "tripo_axis": [round(float(v), 3) for v in axis],
                    "slot": d.get("slot", "Dome"), "faces": sum(len(o.data.polygons) for o in ps)})
        REPORT["pieces"][d.get("slot", "Dome")] = rep
        print("[deco] dome", rep, flush=True)

# ------------------------------------------------------------------ tower caps / finials (one piece, every slot)
for ci, cp in enumerate(PR.get("caps", [])):
    s = cp["src"]
    ps = cut("CapTmp%d" % ci, dict(s, cyl=s, no_white=cp.get("no_white", True), white_below=cp.get("white_below", s["z"][0] + 0.5)))
    if not ps:
        continue
    axis, rep = round_fix(ps, s["c"])
    P = allv(ps)
    zb = P[:, 2].min()
    low = P[P[:, 2] <= zb + 0.15 * (P[:, 2].max() - zb)]
    Rt = float(np.percentile(np.hypot(low[:, 0] - axis[0], low[:, 1] - axis[1]), 98))
    apply(ps, Matrix.Translation((-axis[0], -axis[1], -zb)))      # template: axis on the origin, base on z 0
    tidy_normals(ps)
    tname = "Cap%d" % ci
    # Tripo's finials are a few dozen facets: the fix turns the profile on a lathe (exact round, 24 sides) and projects
    # Tripo's paint onto it from the nearest point (so the colours, bands and shine stay Tripo's)
    prof = lathe_profile(ps, cp.get("bands", 20))
    lo_ = proj_bake.lathe(prof, seg=cp.get("seg", 16), name="%s_%s" % (NAME, tname))
    maps = proj_bake.bake(lo_, proj_bake.Source(ps), size=cp.get("size", 256), ray=None, relief=False)
    lo_.data.materials.append(proj_bake.save_maps(maps, WORK, "%s_%s" % (NAME, tname)))
    for o in ps:
        bpy.data.objects.remove(o)
    out_objs.append(lo_)
    rep["fix_shape"] = "lathe: %d profile rings x %d sides from the Tripo silhouette, paint projected (hit %.0f %%)" % (
        len(prof), cp.get("seg", 16), 100 * maps["hit"])
    for sn in cp["slots"]:
        sl = SLOTS[sn]
        k = (sl["R"] / Rt if cp.get("fit", "R") == "R" else HS) * cp.get("mul", 1.0)
        COPIES.append({"src": "%s_%s" % (NAME, tname), "name": "%s_%s" % (NAME, sn), "scale": round(k, 4),
                       "move": [sl["pos"][0], sl["pos"][1], sl["pos"][2] + cp.get("dz", 0.0)]})
        rep.setdefault("slots", {})[sn] = round(k, 4)
    rep.update({"tripo_base_R": round(Rt, 3), "tripo_axis": [round(float(v), 3) for v in axis]})
    REPORT["pieces"]["Caps%d" % ci] = rep
    print("[deco] caps", rep, flush=True)

# ------------------------------------------------------------------ wall lanterns
def box_obj(bm, a, b, w):
    """a square bar of width w from point a to point b (bmesh)"""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    L_ = d.length
    z = d.normalized()
    x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
    x = (x - z * x.dot(z)).normalized()
    y = z.cross(x)
    vs = []
    for t in (0.0, L_):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(bm.verts.new(a + z * t + x * sx * w / 2 + y * sy * w / 2))
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in f])


if "lantern" in PR:
    # Tripo's wall lantern (tapered glass body, gold corner posts, hip cap, base + drop, scroll bracket) is ~150 crude
    # faces with half its posts lost in the cut. The fix measures it (its silhouette r(z) round its own axis, the glass
    # band from the pale glowing faces) and rebuilds the frame exact and square-symmetric: cap and base + drop turned on a
    # 4-sided lathe (faces to the front), 4 corner posts along the taper, an arm to the wall; the glass stays the
    # skeleton's LampGlass + LampCore (Glass + Neon, lit at night), so the frame is open there. Gold = the median Tripo gold.
    L = PR["lantern"]
    ps = cut("LanternTmp", dict(L, no_white=False))
    wall_t = None
    if ps:
        # the wall behind the lantern (pale faces looking to the front): its plane, then everything behind it dropped
        wy = []
        for o in ps:
            hsv = face_hsv(o)
            nrm = np.array([p_.normal[:] for p_ in o.data.polygons]).reshape(-1, 3)
            sel = (hsv[:, 1] < 0.15) & (hsv[:, 2] > 0.7) & (nrm[:, 1] > 0.5)
            wy += list(centres(o)[sel, 1])
        if len(wy) >= 4:
            wall_t = float(np.percentile(wy, 80))
            for o in ps:
                keep = centres(o)[:, 1] > wall_t + 0.08
                bm = bmesh.new()
                bm.from_mesh(o.data)
                bm.faces.ensure_lookup_table()
                bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
                bmesh.ops.delete(bm, geom=[v_ for v_ in bm.verts if not v_.link_faces], context="VERTS")
                bm.to_mesh(o.data)
                bm.free()
            ps = [o for o in ps if len(o.data.polygons)]
    if ps:
        P = allv(ps)
        cx = L.get("cx", (P[:, 0].min() + P[:, 0].max()) / 2)
        glow_c, gold_rgb = [], []
        for o in ps:
            hsv = face_hsv(o)
            c = centres(o)
            h, s_, v = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
            glow = (v > 0.8) & (s_ > 0.12) & (s_ < 0.6) & (h >= 28) & (h <= 72)
            gold = (h >= 25) & (h <= 55) & (s_ > 0.5) & (v > 0.55)
            glow_c.append(c[glow])
            gold_rgb += [colorsys.hsv_to_rgb(*q) for q in hsv[gold]]
        G = np.concatenate(glow_c) if glow_c else np.zeros((0, 3))
        if len(G) >= 6:
            gz0, gz1 = np.percentile(G[:, 2], [5, 95])
        else:
            gz0, gz1 = np.percentile(P[:, 2], [35, 70])
        band = (P[:, 2] > gz0) & (P[:, 2] < gz1)
        hw = float(np.percentile(np.abs(P[band, 0] - cx), 95)) if band.any() else 0.6
        yc_t = float(P[:, 1].max()) - hw                          # body axis: its half width behind the front
        gzc = (gz0 + gz1) / 2
        apply(ps, Matrix.Translation((-cx, -yc_t, -gzc)))
        pts = []
        for o in ps:
            me = o.data
            me.calc_loop_triangles()
            V = np.array([v_.co[:] for v_ in me.vertices])
            hsv = face_hsv(o)                                      # lantern faces only: gold metal or warm glass
            hh, ss, vv = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
            lamp = ((hh >= 20) & (hh <= 60) & (ss > 0.35) & (vv > 0.35)) | ((vv > 0.8) & (ss > 0.12) & (hh >= 28) & (hh <= 72))
            T = np.array([t_.vertices[:] for t_ in me.loop_triangles if lamp[t_.polygon_index]])
            if len(T):
                A, B, C = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
                ar = np.linalg.norm(np.cross(B - A, C - A), axis=1) / 2
                n = np.random.default_rng(0).choice(len(T), size=8000, p=ar / ar.sum())
                u, w_ = np.random.default_rng(1).random((2, len(n)))
                sw = u + w_ > 1
                u[sw], w_[sw] = 1 - u[sw], 1 - w_[sw]
                pts.append(A[n] + (B[n] - A[n]) * u[:, None] + (C[n] - A[n]) * w_[:, None])
        Q = np.concatenate(pts)
        Q = Q[Q[:, 1] > -hw * 0.6]                                 # front part only (the bracket is behind)
        half = np.maximum(np.abs(Q[:, 0]), np.abs(Q[:, 1]))        # square "radius" = the larger of |x|, |y|
        z0, z1 = float(Q[:, 2].min()), float(Q[:, 2].max())
        edges = np.linspace(z0, z1, 25)
        prof = []
        for b in range(24):
            sel = (Q[:, 2] >= edges[b]) & (Q[:, 2] < edges[b + 1] + 1e-9)
            if sel.sum() >= 6:
                prof.append((float(np.percentile(half[sel], 90)), float((edges[b] + edges[b + 1]) / 2)))
        prof = np.array(prof)
        g0, g1 = gz0 - gzc, gz1 - gzc
        k = HS * L.get("mul", 1.0)
        rr = math.sqrt(2)                                       # 4-sided lathe at 45 deg: corner radius = half width * sqrt 2
        below = [(float(r) * rr, float(z)) for r, z in prof if z < g0]
        above = [(float(r) * rr, float(z)) for r, z in prof if z > g1]
        objs_l = []
        if below:
            objs_l.append(proj_bake.lathe([(0.0, z0)] + below + [(below[-1][0], g0)], seg=4, name=NAME + "_LanternBase"))
        if above:
            objs_l.append(proj_bake.lathe([(above[0][0], g1)] + above + [(0.0, z1)], seg=4, name=NAME + "_LanternCap"))
        for o in objs_l:                                     # the lathes' 4 corners on the diagonals: faces to the front
            o.data.transform(Matrix.Rotation(math.pi / 4, 4, "Z"))
        r0 = float(np.interp(g0, prof[:, 1], prof[:, 0]))
        r1 = float(np.interp(g1, prof[:, 1], prof[:, 0]))
        me = bpy.data.meshes.new(NAME + "_LanternPosts")
        bm = bmesh.new()
        pw = max(0.06 / k, 0.09 * (r0 + r1))
        for sx, sy in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
            box_obj(bm, (sx * (r0 - pw / 2), sy * (r0 - pw / 2), g0), (sx * (r1 - pw / 2), sy * (r1 - pw / 2), g1), pw)
        yc_s = L.get("out", 0.75) / k                       # the arm: wall -> back of the cap, and a wall plate
        za = g1 + 0.15 * (z1 - g1)
        box_obj(bm, (0, -yc_s, za), (0, -r1 * 0.5, za), pw * 1.1)
        box_obj(bm, (0, -yc_s + pw * 0.4, g0 + 0.3 * (g1 - g0)), (0, -yc_s + pw * 0.4, za + pw), pw * 1.6)
        bm.to_mesh(me)
        bm.free()
        po = bpy.data.objects.new(NAME + "_LanternPosts", me)
        bpy.context.scene.collection.objects.link(po)
        objs_l.append(po)
        lt = join(objs_l, NAME + "_LanternT")
        gr = np.median(np.array(gold_rgb), 0) if gold_rgb else np.array([1.0, 0.66, 0.14])
        m = bpy.data.materials.new(NAME + "_LanternGold")
        m.use_nodes = True
        pb = m.node_tree.nodes["Principled BSDF"]
        pb.inputs["Base Color"].default_value = (*[c_ / 12.92 if c_ <= 0.04045 else ((c_ + 0.055) / 1.055) ** 2.4 for c_ in gr], 1)
        pb.inputs["Metallic"].default_value = 1.0
        pb.inputs["Roughness"].default_value = 0.3
        lt.data.materials.clear()
        lt.data.materials.append(m)
        # template: wall (back) on y 0, glass centre on x 0 / z 0
        lt.data.transform(Matrix.Translation((0, L.get("out", 0.75), 0)) @ Matrix.Scale(k, 4))
        tidy_normals([lt])
        for o in ps:
            bpy.data.objects.remove(o)
        out_objs.append(lt)
        rep = {"tripo": {"wall_y": None if wall_t is None else round(wall_t, 3),
                         "axis_x": round(float(cx), 3), "axis_y": round(float(yc_t), 3), "glass_z": [round(float(gz0), 3), round(float(gz1), 3)],
                         "half_width": round(hw, 3), "height": round(z1 - z0, 3)},
               "fix": "rebuilt exact: 4-sided lathe cap + base/drop from the Tripo silhouette (%d rings), 4 corner posts, arm + wall plate; "
                      "open glass band for the skeleton LampGlass; gold = Tripo median (%d, %d, %d)" % ((len(prof),) + tuple(int(255 * c_) for c_ in gr)),
               "scale": round(k, 4), "glass_band_studs": [round(g0 * k, 3), round(g1 * k, 3)],
               "body_half_width_studs": [round(r0 * k, 3), round(r1 * k, 3)]}
        for sn in L["slots"]:
            sl = SLOTS[sn]
            COPIES.append({"src": NAME + "_LanternT", "name": "%s_%s" % (NAME, sn), "scale": 1.0,
                           "move": [sl["pos"][0], sl.get("wall_y", sl["pos"][1]) + L.get("dy", 0.0), sl["pos"][2] + L.get("dz", 0.0)]})
        REPORT["pieces"]["Lantern"] = rep
        print("[deco] lantern", rep, flush=True)

# ------------------------------------------------------------------ door leaf
def slab(name, outline, y_front, t, uv_of, back_uv):
    """a flat slab: front face = outline [(x, z), ...] at y_front (UV from uv_of(x, z)), back face t behind, sides"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    fr = [bm.verts.new((x, y_front, z)) for x, z in outline]
    bk = [bm.verts.new((x, y_front - t, z)) for x, z in outline]
    f = bm.faces.new(fr[::-1] if _ccw(outline) else fr)
    for lp in f.loops:
        lp[uvl].uv = uv_of(lp.vert.co.x, lp.vert.co.z)
    f = bm.faces.new(bk if _ccw(outline) else bk[::-1])
    for lp in f.loops:
        lp[uvl].uv = back_uv
    n = len(outline)
    for i in range(n):
        a, b = i, (i + 1) % n
        f = bm.faces.new((fr[a], fr[b], bk[b], bk[a]) if _ccw(outline) else (fr[b], fr[a], bk[a], bk[b]))
        for lp in f.loops:
            lp[uvl].uv = back_uv
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def _ccw(pts):
    return sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts))) > 0


if "door" in PR and door_src and leaf_slots:
    # the Tripo leaf is a crude low-poly surface (long triangles, lumpy knobs, frame bits): the Blender fix rebuilds it as an
    # exact arched slab (straight jambs, semicircle top, the slot's size) and projects Tripo's own paint, roughness, metal
    # and relief (as a normal map) onto it with a ray from the front: the planks / hinges are Tripo's, the shape is exact
    D = PR["door"]
    cx, Rt, bot_t, top_t, y_leaf, leaf_srcs = door_leaf_source(D)
    src = door_src[0]
    spring_t = top_t - Rt
    sl0 = leaf_slots[0]
    double = sl0.get("half") is not None or D.get("double", False)
    Rs, cs, bs, fs = sl0["R"], sl0["c"], sl0["bottom"], sl0["front"]
    t = sl0.get("t", 0.32)

    def to_tripo_xz(x, z):
        xt = cx + (x - cs[0]) * Rt / Rs
        zt = np.where(z <= cs[1], bot_t + (z - bs) * (spring_t - bot_t) / max(cs[1] - bs, 1e-3), spring_t + (z - cs[1]) * Rt / Rs)
        return xt, zt

    def from_tripo_xz(x, z):
        zz = bs + (z - bot_t) * (cs[1] - bs) / max(spring_t - bot_t, 1e-3) if z <= spring_t else cs[1] + (z - spring_t) * Rs / Rt
        return [round(float(cs[0] + (x - cx) * Rs / Rt), 4), round(float(zz), 4)]

    arc = [(cs[0] + Rs * math.cos(math.pi * k / 32), cs[1] + Rs * math.sin(math.pi * k / 32)) for k in range(33)]
    whole = [(cs[0] + Rs, bs)] + arc + [(cs[0] - Rs, bs)]       # counter-clockwise seen from the front (+y)
    W, H = 2 * Rs, cs[1] + Rs - bs

    def uv_of(x, z):
        return (0.02 + 0.96 * (x - (cs[0] - Rs)) / W, 0.02 + 0.96 * (z - bs) / H)

    back_uv = uv_of(cs[0] + Rs * 0.55, bs + 0.4)                # a plank spot for the back / edges
    tri_src = proj_bake.Source(leaf_srcs)
    # only the plank surface and the flat hardware on it take part: oblique faces (knob sides, shards hanging off them)
    # and lumps standing out of the planks (Tripo's knobs: the exact ones go on top) are passed through; empty texels
    # are filled from their neighbours
    _hsv = face_hsv(src)
    _h, _s, _v = _hsv[:, 0] * 360, _hsv[:, 1], _hsv[:, 2]
    _wood = (_h >= 12) & (_h <= 42) & (_s >= 0.35) & (_v >= 0.2) & (_v <= 0.78)
    _wood_y = y_leaf
    tri_src.skip_where((tri_src.FN[:, 1] < D.get("min_facing", 0.45)) | (tri_src.FC[:, 1] > _wood_y + D.get("max_out", 0.22)))
    tri_src.strict = True
    _ys = allv(leaf_srcs)[:, 1]
    yt_front = float((_ys.max() + _ys.min()) / 2)               # ray from in front of the whole object, right through it
    RAY_BACK = float((_ys.max() - _ys.min()) / 2 + 0.6)
    if double:
        right = [(x, z) for x, z in arc if x >= cs[0] - 1e-6]
        left = [(x, z) for x, z in arc if x <= cs[0] + 1e-6]
        outlines = {"Leaf1": [(cs[0], bs), (cs[0] + Rs, bs)] + right[:-1] + [(cs[0], cs[1] + Rs)],
                    "Leaf0": [(cs[0], bs), (cs[0], cs[1] + Rs)] + left[1:] + [(cs[0] - Rs, bs)]}
        # Leaf1 = +x half (the viewer's left), Leaf0 = -x half, as the slot halves -1 / +1 of metal_ornaments
    else:
        outlines = {"Leaf": whole}
    leaf_objs = []
    for nm, ol in outlines.items():
        if not _ccw(ol):
            ol = ol[::-1]
        leaf_objs.append(slab("%s_%s" % (NAME, nm), ol, fs, t, uv_of, back_uv))
    # one bake over the whole door outline (both halves share the map)
    tmp = slab(NAME + "_LeafBake", whole if _ccw(whole) else whole[::-1], fs, t, uv_of, back_uv)

    mirror = D.get("mirror", double)
    keep_sign = 1.0 if D.get("keep", "+x") == "+x" else -1.0

    def xf(P):
        x = P[:, 0]
        if mirror:                                   # a double door is symmetric: the better half's paint both sides
            x = cs[0] + keep_sign * np.abs(x - cs[0])
        xt, zt = to_tripo_xz(x, P[:, 2])
        return np.c_[xt, np.full(len(P), yt_front), zt]

    _orig_query = tri_src.query
    tri_src.query = lambda P, ray=None, back=0.6: _orig_query(xf(P), ray, RAY_BACK)
    maps = proj_bake.bake(tmp, tri_src, size=D.get("size", 512), ray=(0, -1, 0), relief=True)
    cleaned = proj_bake.clean_thin_gold(maps, k=D["clean_px"]) if D.get("clean_px") else 0
    bpy.data.objects.remove(tmp)
    mat = proj_bake.save_maps(maps, WORK, NAME + "_Leaf")
    for o in leaf_objs:
        o.data.materials.append(mat)
        out_objs.append(o)
    hw_at = []
    for b in D.get("knockers", D.get("flatten_boxes", [])):      # Tripo knocker / knob spots -> exact metal parts there
        P = allv(leaf_srcs + [o for o in SRC if o.name.endswith("_DoorHw")])
        inb = np.ones(len(P), bool)
        for k, (lo_, hi_) in enumerate(b):
            inb &= (P[:, k] >= lo_) & (P[:, k] <= hi_)
        if inb.any():
            hw_at.append(from_tripo_xz((P[inb, 0].min() + P[inb, 0].max()) / 2, (P[inb, 2].min() + P[inb, 2].max()) / 2))
    if mirror and len(hw_at) == 2:                   # a symmetric pair on a double door
        dx_ = (abs(hw_at[0][0] - cs[0]) + abs(hw_at[1][0] - cs[0])) / 2
        z_ = (hw_at[0][1] + hw_at[1][1]) / 2
        hw_at = [[round(cs[0] + (dx_ if h[0] > cs[0] else -dx_), 4), round(z_, 4)] for h in hw_at]
    REPORT["hardware_at"] = hw_at
    REPORT["leaf_front"] = round(float(fs), 4)
    # round door knobs (double doors): Tripo's lumpy knob -> a lathe-turned exact knob with Tripo's paint, on its spot
    knob_mat = None
    hw_objs = leaf_srcs + [o for o in SRC if o.name.endswith("_DoorHw")]
    KN_KEPT = []                                     # the knob centre on the kept half (Tripo frame)
    for b in D.get("knobs", []):
        P = allv(hw_objs)
        inb = P[:, 1] > y_leaf + 0.12
        for k, (lo_, hi_) in enumerate(b):
            inb &= (P[:, k] >= lo_) & (P[:, k] <= hi_)
        if inb.any():
            q = P[inb]
            c_ = ((q[:, 0].min() + q[:, 0].max()) / 2, (q[:, 2].min() + q[:, 2].max()) / 2)
            if (c_[0] - cx) * keep_sign > 0:
                KN_KEPT.append(c_)
    for ki, b in enumerate(D.get("knobs", [])):
        P = allv(hw_objs)
        inb = P[:, 1] > y_leaf + 0.12       # standing out of the planks
        for k, (lo_, hi_) in enumerate(b):
            inb &= (P[:, k] >= lo_) & (P[:, k] <= hi_)
        if not inb.any():
            continue
        q = P[inb]
        kc = ((q[:, 0].min() + q[:, 0].max()) / 2, (q[:, 2].min() + q[:, 2].max()) / 2)
        rk = max(q[:, 0].max() - q[:, 0].min(), q[:, 2].max() - q[:, 2].min()) / 2
        yk = float(np.percentile(P[(np.abs(P[:, 0] - kc[0]) < 2 * rk) & (np.abs(P[:, 2] - kc[1]) < 2 * rk), 1], 50))
        prof = [(rk * 0.8, 0.0), (rk * 0.95, 0.12 * rk), (rk, 0.35 * rk), (rk * 0.9, 0.62 * rk), (rk * 0.62, 0.86 * rk),
                (rk * 0.3, 0.98 * rk), (0.0, 1.02 * rk)]
        kn = proj_bake.lathe(prof, seg=20, name="%s_Knob%d" % (NAME, ki))
        kn.data.transform(Matrix.Translation((kc[0], yk, kc[1])) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
        if knob_mat is None:                         # Tripo's knob paint is blotchy: its median gold, plain metal
            hsv = np.concatenate([face_hsv(o_) for o_ in hw_objs])
            gsel = (hsv[:, 0] * 360 >= 25) & (hsv[:, 0] * 360 <= 55) & (hsv[:, 1] > 0.5) & (hsv[:, 2] > 0.55)
            gr = np.median(np.array([colorsys.hsv_to_rgb(*q) for q in hsv[gsel]]), 0) if gsel.any() else np.array([1.0, 0.66, 0.14])
            knob_mat = bpy.data.materials.new(NAME + "_KnobGold")
            knob_mat.use_nodes = True
            pb_ = knob_mat.node_tree.nodes["Principled BSDF"]
            pb_.inputs["Base Color"].default_value = (*[c_ / 12.92 if c_ <= 0.04045 else ((c_ + 0.055) / 1.055) ** 2.4 for c_ in gr], 1)
            pb_.inputs["Metallic"].default_value = 1.0
            pb_.inputs["Roughness"].default_value = 0.3
        kn.data.materials.append(knob_mat)
        sx, sz = from_tripo_xz(*kc)
        if mirror:                                   # symmetric knobs: the kept side's spot, mirrored for the other
            kept = [from_tripo_xz(*kc2) for kc2 in KN_KEPT] if KN_KEPT else []
            if kept:
                sx = cs[0] + np.sign(sx - cs[0]) * abs(kept[0][0] - cs[0])
                sz = kept[0][1]
        kk = Rs / Rt
        kn.data.transform(Matrix.Translation((sx, fs, sz)) @ Matrix.Scale(kk, 4) @ Matrix.Translation((-kc[0], -yk, -kc[1])))
        out_objs.append(kn)
        rep_k = REPORT.setdefault("knobs", [])
        rep_k.append({"tripo_at": [round(float(kc[0]), 3), round(float(kc[1]), 3)], "R": round(float(rk * kk), 3), "at": [sx, sz]})
    rep = {"tripo_leaf": {"cx": round(float(cx), 3), "R": round(float(Rt), 3), "bottom": round(float(bot_t), 3), "top": round(float(top_t), 3)},
           "fix": "rebuilt as an exact arched slab (%s, R %.2f, t %.2f) + Tripo paint / rough / metal / relief projected from the "
                  "front (hit %.0f %%), %d thin gold drip texels filled with plank colour" % (
                      "double, 2 halves" if double else "single", Rs, t, 100 * maps["hit"], cleaned),
           "double": bool(double), "maps": D.get("size", 512)}
    REPORT["pieces"]["Leaf"] = rep
    print("[deco] door", rep, flush=True)

# ------------------------------------------------------------------ extras (awning frames, parasols, brick domes ...)
for ex in PR.get("extra", []):
    ps = cut(ex["name"] + "Tmp", ex)
    if not ps:
        print("[deco] extra %s: nothing in the region" % ex["name"], flush=True)
        continue
    rep = {}
    if ex.get("fix") == "round":
        axis, rep = round_fix(ps, ex.get("cyl", {}).get("c", [0, 0]))
    elif ex.get("fix") == "mirror":
        lo, hi = bbox(ps)
        for o in ps:
            mirror_fix(o, ex.get("cx", (lo[0] + hi[0]) / 2), ex.get("keep", "+x"))
        ps = [o for o in ps if len(o.data.polygons)]
        rep = {"fix": "mirror"}
    k = ex.get("scale", HS)
    apply(ps, Matrix.Translation(ex.get("move", (0, 0, 0))) @ Matrix.Scale(k, 4))
    for o in ps:
        o.name = o.data.name = o.name.replace(ex["name"] + "Tmp", ex["name"])
    tidy_normals(ps)
    out_objs += ps
    rep.update({"scale": round(k, 4), "faces": sum(len(o.data.polygons) for o in ps)})
    REPORT["pieces"][ex["name"]] = rep
    print("[deco] extra", ex["name"], rep, flush=True)

# ------------------------------------------------------------------ export only the decoration objects
for o in SRC:
    bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
tris = 0
for o in out_objs:
    o.select_set(True)
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
    lo, hi = bbox([o])
    print("[deco] %-40s %6d tris  x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % (o.name, len(o.data.loop_triangles), lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]), flush=True)
REPORT["tris"] = tris
REPORT["copies"] = COPIES
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False)
json.dump(REPORT, open(a.report or os.path.splitext(a.out)[0] + ".json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print("[deco] ok %d tris -> %s" % (tris, a.out), flush=True)
