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
ap.add_argument("--only", default="", help="comma list of dome,caps,lantern,door: run only these sections")
a = ap.parse_args(argv)
ROOT = os.environ.get("HH_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # HH_ROOT: run a private copy of tools/
NAME = a.name
PR = json.load(open(a.params, encoding="utf-8"))
if a.only:
    _keep = set(a.only.split(","))
    PR = {k: v for k, v in PR.items() if k not in ("dome", "caps", "lantern", "door", "extra") or k in _keep}
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


def slot_or_target(d, slot, axis, Rt):
    """the skeleton's ornament slot, or d["target"] / d["pos"]: {"pos": [x, y, z], "R": r} (R default = Tripo radius x the
    house scale); "pos": "tripo" puts it at Tripo's own xy x the house scale and z "z" (a dome the skeleton has no slot for:
    the Bakery's brick dome, its chimney cap)"""
    t = d.get("target", d if "pos" in d else None)
    if not t:
        return SLOTS[slot]
    pos = t["pos"]
    if pos == "tripo":
        pos = [float(axis[0]) * HS, float(axis[1]) * HS, t["z"]]
    return {"pos": pos, "R": t.get("R", Rt * HS)}


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
        sl = slot_or_target(d, d.get("slot", "Dome"), axis, Rt)
        k = sl["R"] / Rt * d.get("r_mul", 1.0)
        M = Matrix.Translation((sl["pos"][0], sl["pos"][1], sl["pos"][2] + d.get("dz", 0.0))) @ Matrix.Scale(k, 4) @ \
            Matrix.Translation((-axis[0], -axis[1], -zb))
        if d.get("fix") == "lathe":
            # a dented panel / a torn foot (ivy over the Tripo dome, house 09): the dome is turned again on a lathe from
            # its own silhouette (48 sides), the foot below "base_cut" studs made a plain straight band, and Tripo's paint
            # (gold, rib lines, shine) is projected from the nearest point; no relief taken (the dent would come back)
            apply(ps, Matrix.Translation((-axis[0], -axis[1], -zb)))
            prof = lathe_profile(ps, d.get("bands", 40))
            if d.get("profile_from"):                   # a messy foot: the clean upper outline, straight down below it
                zt_ = max(z_ for _, z_ in prof)
                z0_ = d["profile_from"] * zt_
                r0_ = float(np.interp(z0_, [z_ for _, z_ in prof], [r_ for r_, _ in prof]))
                prof = [(r0_, 0.0), (r0_, z0_)] + [(r_, z_) for r_, z_ in prof if z_ > z0_]
            bc = d.get("base_cut", 0.0)
            if bc > 0:
                rb = float(np.interp(bc, [z_ for _, z_ in prof], [r_ for r_, _ in prof]))
                prof = [(rb, 0.0), (rb, bc)] + [(r_, z_) for r_, z_ in prof if z_ > bc]
            dl = proj_bake.lathe(prof, seg=48, name="%s_%s" % (NAME, d.get("slot", "Dome")))
            if d.get("paint"):
                # a painted dome (the Bakery's brick dome): the clean lathe takes Tripo's own paint from the nearest point
                # (bricks, white stone bands), no exact ribs (the runner skips piece_fix for it: fix_shape "lathe")
                mp_ = proj_bake.bake(dl, proj_bake.Source(ps), size=d.get("size", 1024), ray=None, relief=False)
                if d.get("profile_from"):
                    # the straight foot band took smeared paint from Tripo's messy foot: repeat the brick courses just
                    # above it downwards (lathe UV: v = 0.01 + 0.98 * 0.92 * arc / total arc)
                    arc_ = [0.0]
                    for (r0_, z0_), (r1_, z1_) in zip(prof, prof[1:]):
                        arc_.append(arc_[-1] + math.hypot(r1_ - r0_, z1_ - z0_))
                    zf_ = prof[1][1]                               # top of the straight foot
                    vf_ = 0.01 + 0.98 * 0.92 * zf_ / arc_[-1]
                    per_ = 0.98 * 0.92 * d.get("course", 0.9) / arc_[-1]
                    S_ = mp_["C"].shape[0]
                    rows_ = np.arange(S_)
                    vv_ = 1 - (rows_ + 0.5) / S_                     # row 0 = top of the image
                    for r_ in rows_[vv_ < vf_]:
                        src_v = vf_ + (vf_ - vv_[r_]) % per_
                        sr_ = int(np.clip(round((1 - src_v) * S_ - 0.5), 0, S_ - 1))
                        for key_ in ("C", "N", "R", "M", "MR"):
                            mp_[key_][r_] = mp_[key_][sr_]
                dl.data.materials.append(proj_bake.save_maps(mp_, WORK, "%s_%s" % (NAME, d.get("slot", "Dome"))))
                for o in ps:
                    bpy.data.objects.remove(o)
                ps = [dl]
                M = Matrix.Translation((sl["pos"][0], sl["pos"][1], sl["pos"][2] + d.get("dz", 0.0))) @ Matrix.Scale(k, 4)
                rep["fix_shape"] = "lathe: %d rings x 48 sides from the Tripo silhouette, foot band %.2f, Tripo paint projected " \
                                   "(hit %.0f %%)" % (len(prof), bc, 100 * mp_["hit"])
            else:
                # ribs: as many as the spec says (the 2D), turned to where Tripo's dark rib lines are (mid height)
                spec_top = json.load(open(os.path.join(ROOT, "tools", "house_specs", NAME + ".json"), encoding="utf-8")).get("top", {})
                nrib = int(d.get("ribs", spec_top.get("ribs", 8)))
                angs, gold_rgb = [], []
                zt = max(z_ for _, z_ in prof)
                for o in ps:
                    hsv = face_hsv(o)
                    c = centres(o)
                    hh, ss, vv = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
                    isg = (hh >= 25) & (hh <= 55) & (ss > 0.45)
                    mid = (c[:, 2] > 0.25 * zt) & (c[:, 2] < 0.6 * zt)
                    dark = isg & (vv < 0.6) & mid
                    angs += list(np.degrees(np.arctan2(c[dark, 1], c[dark, 0])) % (360.0 / nrib))
                    gold_rgb += [colorsys.hsv_to_rgb(*q) for q in hsv[isg & (vv > 0.45)]]
                if angs:
                    hist, ed = np.histogram(angs, bins=36, range=(0, 360.0 / nrib))
                    phase = float((ed[np.argmax(hist)] + ed[np.argmax(hist) + 1]) / 2)
                else:
                    phase = 0.0
                me = bpy.data.meshes.new(NAME + "_DomeRibs")
                bm = bmesh.new()
                rib_w, rib_out = d.get("rib_w", 0.22), d.get("rib_out", 0.1)
                rmax = max(r_ for r_, _ in prof)
                path = [(r_, z_) for r_, z_ in prof if z_ >= bc and r_ > 0.18 * rmax]
                for kr in range(nrib):
                    th = math.radians(phase + kr * 360.0 / nrib)
                    rows = []
                    for r_, z_ in path:
                        a_ = (rib_w / 2) / max(r_, 1e-3)
                        rows.append([bm.verts.new(((r_ + o_) * math.cos(th + sgn * a_), (r_ + o_) * math.sin(th + sgn * a_), z_))
                                     for sgn, o_ in ((-1, -0.02), (-1, rib_out), (1, rib_out), (1, -0.02))])
                    for r0_, r1_ in zip(rows, rows[1:]):
                        for q_ in range(3):
                            bm.faces.new((r0_[q_], r0_[q_ + 1], r1_[q_ + 1], r1_[q_]))
                    if rows:                                   # end caps
                        bm.faces.new(rows[0][::-1])
                        bm.faces.new(rows[-1])
                bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
                bm.to_mesh(me)
                bm.free()
                ribs = bpy.data.objects.new("%s_%sRibs" % (NAME, d.get("slot", "Dome")), me)
                bpy.context.scene.collection.objects.link(ribs)
                gr = np.array([255, 168, 36]) / 255.0               # the approved gold (HH_HaloGoldTrim part colour) for a plain dome
                gm = bpy.data.materials.new(NAME + "_DomeGold")
                gm.use_nodes = True
                pb_ = gm.node_tree.nodes["Principled BSDF"]
                pb_.inputs["Base Color"].default_value = (*[c_ / 12.92 if c_ <= 0.04045 else ((c_ + 0.055) / 1.055) ** 2.4 for c_ in gr], 1)
                pb_.inputs["Metallic"].default_value = 1.0
                pb_.inputs["Roughness"].default_value = 0.28
                dl.data.materials.append(gm)
                ribs.data.materials.append(gm)
                me.shade_smooth()
                for o in ps:
                    bpy.data.objects.remove(o)
                ps = [dl, ribs]
                mp = {"hit": 1.0}
                M = Matrix.Translation((sl["pos"][0], sl["pos"][1], sl["pos"][2] + d.get("dz", 0.0))) @ Matrix.Scale(k, 4)
                rep["fix_shape"] = "lathe: %d rings x 48 sides from the Tripo silhouette, plain foot band %.2f, %d exact ribs at Tripo's " \
                                   "rib angle (phase %.1f deg), approved gold 255,168,36 (plain; Studio gold MaterialVariant)" % (len(prof), bc, nrib, phase)
        apply(ps, M)
        for o in ps:
            o.name = o.data.name = o.name.replace("DomeTmp", d.get("slot", "Dome"))
        if d.get("fix") != "lathe":
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
        sl = slot_or_target(cp.get("targets", {}).get(sn, {}), sn, axis, Rt)
        k = (sl["R"] / Rt if cp.get("fit", "R") == "R" else HS) * cp.get("mul", 1.0)
        COPIES.append({"src": "%s_%s" % (NAME, tname), "name": "%s_%s" % (NAME, sn), "scale": round(k, 4),
                       "move": [sl["pos"][0], sl["pos"][1], sl["pos"][2] + cp.get("dz", 0.0)]})
        rep.setdefault("slots", {})[sn] = round(k, 4)
    rep.update({"tripo_base_R": round(Rt, 3), "tripo_axis": [round(float(v), 3) for v in axis]})
    REPORT["pieces"]["Caps%d" % ci] = rep
    print("[deco] caps", rep, flush=True)

# ------------------------------------------------------------------ wall lanterns
def image_profile(L, cx):
    """front-view profile of the lantern from build/deco/ortho/<NAME>/front.png: [(half width, z) ...] bottom -> top,
    plus the glass band (rows that are mostly pale warm glow) when found; None if the render is missing"""
    d_ = os.path.join(ROOT, "build", "deco", "ortho", NAME)
    if not (os.path.isfile(os.path.join(d_, "front.png")) and os.path.isfile(os.path.join(d_, "frame.json"))):
        return None
    F = json.load(open(os.path.join(d_, "frame.json")))["views"]["front"]
    bimg = bpy.data.images.load(os.path.join(d_, "front.png"))
    bimg.colorspace_settings.name = "Non-Color"                 # raw PNG values
    Ww, Hh = bimg.size
    im = np.empty(Ww * Hh * bimg.channels, np.float32)
    bimg.pixels.foreach_get(im)
    im = im.reshape(Hh, Ww, bimg.channels)[::-1, :, :3]          # top row first, like the PNG
    bpy.data.images.remove(bimg)
    ua, umin, umax, us = F["u"]
    va, vmin, vmax, vs = F["v"]
    ppu = Hh / (vmax - vmin) if (vmax - vmin) > (umax - umin) else Ww / (umax - umin)

    def col(x):
        return Ww / 2 + (x - (umin + umax) / 2) * ppu * us

    def row(z):
        return Hh / 2 - (z - (vmin + vmax) / 2) * ppu * vs

    (x0, x1), _, (z0, z1) = L["box"]
    c0, c1 = sorted((int(col(x0)), int(col(x1))))
    r0, r1 = int(row(z1)), int(row(z0))
    sub_ = im[max(r0, 0):min(r1, Hh), max(c0, 0):min(c1, Ww)]
    mx, mn = sub_.max(2), sub_.min(2)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r_, g_, b_ = sub_[..., 0], sub_[..., 1], sub_[..., 2]
    warm = (r_ >= g_) & (g_ >= b_)
    lamp = warm & (((sat > 0.18) & (mx > 0.3)) | ((mx > 0.82) & (sat > 0.06)))     # gold, pale gold, warm glass
    glow = warm & (mx > 0.82) & (sat > 0.06) & (sat < 0.35)
    xc_px = col(cx) - max(c0, 0)
    prof, grows = [], []
    for i in range(sub_.shape[0] - 1, -1, -1):                  # bottom row first
        z = (vmin + vmax) / 2 + (Hh / 2 - (max(r0, 0) + i)) / ppu
        win = L.get("max_half", 1.4) * ppu
        js = np.nonzero(lamp[i])[0]
        js = js[np.abs(js - xc_px) <= win]
        if len(js) < 2:
            continue
        left, right = xc_px - js.min(), js.max() - xc_px
        if left < 1 or right < 1:                               # lantern pixels on both sides of the axis
            continue
        # symmetric lantern: the shorter side (a window frame or plant next to one side does not widen it); pale
        # highlights inside (cap tops) do not matter, only the outer ends
        half = min(left, right) / ppu
        a_, b_ = int(xc_px - min(left, right)), int(xc_px + min(left, right)) + 1
        prof.append((half, z))
        grows.append((z, glow[i, max(a_, 0):b_].mean()))
    if len(prof) < 10:
        return None
    pr = np.array(prof)
    nb = 24                                                    # resample into 24 bands
    edges = np.linspace(pr[:, 1].min(), pr[:, 1].max(), nb + 1)
    out = []
    for b in range(nb):
        sel = (pr[:, 1] >= edges[b]) & (pr[:, 1] <= edges[b + 1])
        if sel.any():
            out.append((float(np.median(pr[sel, 0])), float((edges[b] + edges[b + 1]) / 2)))
    G = np.array(grows)
    glass = None
    gl = G[G[:, 1] > 0.35, 0] if len(G) else np.zeros(0)
    if len(gl) >= 4:
        a0, a1 = float(np.percentile(gl, 5)), float(np.percentile(gl, 95))
        Hb = z1 - z0
        if 0.2 * Hb <= a1 - a0 <= 0.6 * Hb:
            glass = (a0, a1)
    return {"prof": out, "glass": glass}


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
        wy, ly = [], []
        for o in ps:
            hsv = face_hsv(o)
            nrm = np.array([p_.normal[:] for p_ in o.data.polygons]).reshape(-1, 3)
            hh, ss, vv = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
            sel = (ss < 0.15) & (vv > 0.7) & (nrm[:, 1] > 0.5)
            lamp_f = ((hh >= 20) & (hh <= 60) & (ss > 0.35) & (vv > 0.35))
            wy += list(centres(o)[sel, 1])
            ly += list(centres(o)[lamp_f, 1])
        if ly:
            wy = [w for w in wy if w < float(np.median(ly)) - 0.2]
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
        bxz = L["box"][2]
        Hb = bxz[1] - bxz[0]
        gz0, gz1 = bxz[0] + 0.35 * Hb, bxz[0] + 0.72 * Hb          # usual glass share of a wall lantern (fallback)
        glass_src = "fallback 35-72 % of the box height"
        if len(G) >= 6:
            a0, a1 = np.percentile(G[:, 2], [5, 95])
            if 0.22 * Hb <= a1 - a0 <= 0.6 * Hb and bxz[0] + 0.2 * Hb <= (a0 + a1) / 2 <= bxz[0] + 0.8 * Hb:
                gz0, gz1, glass_src = a0, a1, "glow faces"
        if "glass_z" in L:
            gz0, gz1, glass_src = L["glass_z"][0], L["glass_z"][1], "params"
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
            lamp = (hh >= 18) & (hh <= 72) & (ss > 0.12) & (vv > 0.35)    # gold incl. its pale highlights, warm glass
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
        bx = np.array(L["box"], float)                             # big triangles reach out of the box: clip to it
        Qw = Q + np.array([cx, yc_t, gzc])
        Q = Q[np.all((Qw >= bx[:, 0] - 0.15) & (Qw <= bx[:, 1] + 0.15), axis=1)]
        Q = Q[Q[:, 1] > -hw * 0.6]                                 # front part only (the bracket is behind)
        half = np.abs(Q[:, 0])                                     # square half width from the front view (x only:
                                                                   # the body axis depth is not needed, the bracket is thin)
        z0, z1 = float(Q[:, 2].min()), float(Q[:, 2].max())
        edges = np.linspace(z0, z1, 25)
        prof = []
        for b in range(24):
            sel = (Q[:, 2] >= edges[b]) & (Q[:, 2] < edges[b + 1] + 1e-9)
            if sel.sum() >= 6:
                prof.append((float(np.percentile(half[sel], 90)), float((edges[b] + edges[b + 1]) / 2)))
        prof = np.array(prof)
        # better: the Tripo front render (tools/tripo_ortho.py, build/deco/ortho/<name>/front.png): per pixel row the
        # outer ends of the lantern-coloured pixels (gold incl. pale highlights, warm glass) round the axis = its
        # front-view half width; the mesh faces miss the cap's highlight-white rim
        ip = image_profile(L, cx)
        if ip is not None:
            prof = np.array([(r_, z_ - gzc) for r_, z_ in ip["prof"]])
            z0, z1 = float(prof[0, 1]), float(prof[-1, 1])
            if ip.get("glass"):
                gz0, gz1 = ip["glass"]
                glass_src = "front render (pale glow rows)"
            profile_src = "front render rows"
            Ht = z1 - z0                                          # the lantern's whole height (drop .. finial)
            if gz1 - gz0 < 0.42 * Ht:                             # only the bright core was found: glass ~ half of it
                gcm = (gz0 + gz1) / 2
                gz0, gz1 = gcm - 0.25 * Ht, gcm + 0.25 * Ht
                glass_src += ", widened to 50 % of the lantern height"
        else:
            profile_src = "mesh faces"
        g0, g1 = gz0 - gzc, gz1 - gzc
        k = HS * L.get("mul", 1.0)
        rr = math.sqrt(2)                                       # 4-sided lathe at 45 deg: corner radius = half width * sqrt 2
        # the glass body is measured on Tripo (its band and its widths at the bottom / top); the cap, base and drop are
        # the shape every Tripo wall lantern here shares (wide hip roof + finial, tray base, drop finial) built exact in
        # those proportions: the cap's pale highlight made its measured outline unreliable
        inb_ = prof[(prof[:, 1] >= g0) & (prof[:, 1] <= g1)]
        if len(inb_) >= 4:
            nb_ = max(1, len(inb_) // 4)
            r0 = float(np.median(inb_[:nb_, 0]))
            r1 = float(np.median(inb_[-nb_:, 0]))
        else:
            r0 = float(np.interp(g0, prof[:, 1], prof[:, 0]))
            r1 = float(np.interp(g1, prof[:, 1], prof[:, 0]))
        r0, r1 = max(r0, 0.25), max(r1, 0.25)
        r_lo, r_hi = sorted((r0, r1))                         # the family shape: the body widens to the top
        r1, r0 = r_hi, max(r_lo, 0.75 * r_hi)
        hb = g1 - g0
        # size: the open glass band = the skeleton's LampGlass height (1.05), never narrower than the glass (0.7 wide)
        k = L.get("glass_h", 1.05) / max(hb, 1e-3)
        k = max(k, L.get("min_half", 0.42) / r0)
        base = [(0.0, g0 - 0.46 * hb), (r0 * 0.22, g0 - 0.40 * hb), (r0 * 0.45, g0 - 0.26 * hb), (r0 * 0.6, g0 - 0.16 * hb),
                (r0 * 1.15, g0 - 0.1 * hb), (r0 * 1.15, g0)]
        cap = [(r1 * 1.32, g1), (r1 * 1.32, g1 + 0.06 * hb), (r1 * 0.42, g1 + 0.34 * hb), (r1 * 0.24, g1 + 0.37 * hb),
               (r1 * 0.24, g1 + 0.41 * hb), (r1 * 0.16, g1 + 0.47 * hb), (0.0, g1 + 0.56 * hb)]
        z0, z1 = base[0][1], cap[-1][1]
        objs_l = [proj_bake.lathe([(r * rr, z) for r, z in base], seg=4, name=NAME + "_LanternBase"),
                  proj_bake.lathe([(r * rr, z) for r, z in cap], seg=4, name=NAME + "_LanternCap")]
        for o in objs_l:                                     # the lathes' 4 corners on the diagonals: faces to the front
            o.data.transform(Matrix.Rotation(math.pi / 4, 4, "Z"))
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
        rep = {"glass_from": glass_src, "tripo": {"wall_y": None if wall_t is None else round(wall_t, 3),
                         "axis_x": round(float(cx), 3), "axis_y": round(float(yc_t), 3), "glass_z": [round(float(gz0), 3), round(float(gz1), 3)],
                         "half_width": round(hw, 3), "height": round(z1 - z0, 3)},
               "fix": "rebuilt exact: glass body measured on Tripo (band + bottom / top widths, %d profile rows), hip-roof cap + finial, "
                      "tray base + drop in the shared Tripo lantern proportions (4-sided lathes), 4 corner posts, arm + wall plate; open "
                      "glass band for the skeleton LampGlass; gold = Tripo median (%d, %d, %d)" % ((len(prof),) + tuple(int(255 * c_) for c_ in gr)),
               "profile_from": profile_src, "scale": round(k, 4), "glass_band_studs": [round(g0 * k, 3), round(g1 * k, 3)],
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
    if D.get("skip_hues"):                              # things painted in front of the leaf (a cauldron's green glow)
        th = tri_src.tri_hsv()
        for h0, h1 in D["skip_hues"]:
            tri_src.skip_where((th[:, 0] >= h0) & (th[:, 0] <= h1) & (th[:, 1] > D.get("skip_sat", 0.25)))
    for b in D.get("skip_boxes", []):
        inb = np.ones(len(tri_src.FC), bool)
        for k, (lo_, hi_) in enumerate(b):
            inb &= (tri_src.FC[:, k] >= lo_) & (tri_src.FC[:, k] <= hi_)
        tri_src.skip_where(inb)
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
    if D.get("mirror_fill"):                           # hidden by a thing in front (potion shop cauldron): the mirror half
        hue_m = None
        if D.get("clean_hues"):
            proj_bake.clean_hues(maps, D["clean_hues"], D.get("clean_sat", 0.1))
            hue_m = maps.get("hue_mask")
        for u0_, u1_, v0_, v1_ in D.get("mirror_uv", []):  # leaf UV boxes forced to take the mirror half's paint
            S_ = maps["C"].shape[0]
            mb = np.zeros((S_, S_), bool)
            mb[int((1 - v1_) * S_):int((1 - v0_) * S_), int(u0_ * S_):int(u1_ * S_)] = True
            hue_m = mb if hue_m is None else (hue_m | mb)
        cleaned += proj_bake.mirror_fill(maps, hue_m)
    elif D.get("clean_hues"):
        cleaned += proj_bake.clean_hues(maps, D["clean_hues"], D.get("clean_sat", 0.1))
    bpy.data.objects.remove(tmp)
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
    KN_RK = []
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
                KN_RK.append(max(q[:, 0].max() - q[:, 0].min(), q[:, 2].max() - q[:, 2].min()) / 2)
    knob_list = D.get("knobs", [])
    if D.get("knob_at"):
        knob_list = [("at", xz) for xz in D["knob_at"]]
    for ki, b in enumerate(knob_list):
        if isinstance(b, tuple):                        # a given spot: a small box round it, no protrusion test
            kc = (b[1][0], b[1][1])
            rk = D.get("knob_r", 0.3)
            P = allv(hw_objs)
            sel_ = (np.abs(P[:, 0] - kc[0]) < 2 * rk) & (np.abs(P[:, 2] - kc[1]) < 2 * rk)
            yk = float(np.median(P[sel_, 1])) if sel_.any() else y_leaf
            q = None
        else:
            q = 0
        P = allv(hw_objs)
        if q is not None:
            inb = P[:, 1] > y_leaf + 0.12       # standing out of the planks
            for k, (lo_, hi_) in enumerate(b):
                inb &= (P[:, k] >= lo_) & (P[:, k] <= hi_)
            if not inb.any():
                continue
            q = P[inb]
            kc = ((q[:, 0].min() + q[:, 0].max()) / 2, (q[:, 2].min() + q[:, 2].max()) / 2)
            rk = max(q[:, 0].max() - q[:, 0].min(), q[:, 2].max() - q[:, 2].min()) / 2
            if mirror and KN_RK:
                rk = KN_RK[0]
            rk = float(np.clip(rk, 0.18 * Rt / Rs, 0.36 * Rt / Rs))   # 0.18 .. 0.36 studs once fitted
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
    # where the exact parts go (metal knocker rings, lathe knobs) Tripo's own paint of the old part is erased and the
    # planks above / below fill it, so no ghost of the old knob shows round the new one (디자인 검수 10/12)
    S_ = maps["C"].shape[0]
    yy, xx = np.mgrid[0:S_, 0:S_]
    erase = np.zeros((S_, S_), bool)
    spots = [(x_, z_, D.get("knocker_erase", 0.75)) for x_, z_ in REPORT.get("hardware_at", [])]
    spots += [(k_["at"][0], k_["at"][1], k_["R"] * D.get("knob_erase", 1.9)) for k_ in REPORT.get("knobs", [])]
    if D.get("mirror_fill"):                         # the mirror fill copied the old knocker's paint across: erase there too
        spots += [(2 * cs[0] - x_, z_, r_) for x_, z_, r_ in spots]
    for x_, z_, r_ in spots:
        u_, v_ = uv_of(x_, z_)
        cu, cv = u_ * S_, (1 - v_) * S_
        ru = r_ / W * 0.96 * S_
        rv = r_ / H * 0.96 * S_
        erase |= ((xx + 0.5 - cu) / ru) ** 2 + ((yy + 0.5 - cv) / rv) ** 2 <= 1
    erased = proj_bake.fill_mask(maps, erase)
    mat = proj_bake.save_maps(maps, WORK, NAME + "_Leaf")
    for o in leaf_objs:
        o.data.materials.append(mat)
        out_objs.append(o)
    rep = {"tripo_leaf": {"cx": round(float(cx), 3), "R": round(float(Rt), 3), "bottom": round(float(bot_t), 3), "top": round(float(top_t), 3)},
           "erased_under_parts": erased,
           "fix": "rebuilt as an exact arched slab (%s, R %.2f, t %.2f) + Tripo paint / rough / metal / relief projected from the "
                  "front (hit %.0f %%), %d thin gold drip texels filled with plank colour" % (
                      "double, 2 halves" if double else "single", Rs, t, 100 * maps["hit"], cleaned),
           "double": bool(double), "maps": D.get("size", 512)}
    REPORT["pieces"]["Leaf"] = rep
    print("[deco] door", rep, flush=True)

# ------------------------------------------------------------------ skeleton boxes (for the pieces below)
SKEL = json.load(open(os.path.join(ROOT, "build", "skel_%s.json" % NAME)))


def skel_box(prefix, exact=False):
    """axis-aligned box (min, max) of the skeleton parts whose name starts with prefix (or equals it)"""
    lo = np.array([1e9] * 3)
    hi = -lo
    for p_ in SKEL:
        if not (p_["name"] == prefix if exact else p_["name"].startswith(prefix)):
            continue
        X = np.array(p_["X"], float)
        Y = np.array(p_["Y"], float)
        Z = np.cross(X, Y)
        c = np.array(p_["pos"], float)
        sx, sy, sz = p_["size"]
        for a_ in (-0.5, 0.5):
            for b_ in (-0.5, 0.5):
                for c_ in (-0.5, 0.5):
                    q = c + X * a_ * sx + Y * b_ * sy + Z * c_ * sz
                    lo, hi = np.minimum(lo, q), np.maximum(hi, q)
    return (lo, hi) if lo[0] < 1e8 else None


def plain_mat(name, rgb, metal, rough, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    pb = m.node_tree.nodes["Principled BSDF"]
    pb.inputs["Base Color"].default_value = (*[(c_ / 255.0) / 12.92 if c_ / 255.0 <= 0.04045 else ((c_ / 255.0 + 0.055) / 1.055) ** 2.4
                                               for c_ in rgb], 1)                    # sRGB 0..255 -> linear
    pb.inputs["Metallic"].default_value = metal
    pb.inputs["Roughness"].default_value = rough
    return m


def sign_gold(objs):
    """the median Tripo gold of a piece (0..255), for plain plates that sit next to its paint"""
    rgb = []
    for o in objs:
        h_ = face_hsv(o)
        sel = (h_[:, 0] * 360 >= 25) & (h_[:, 0] * 360 <= 55) & (h_[:, 1] > 0.45) & (h_[:, 2] > 0.4)
        rgb += [colorsys.hsv_to_rgb(*q) for q in h_[sel]]
    return tuple(255 * np.median(np.array(rgb), 0)) if rgb else (255, 168, 36)


# ------------------------------------------------------------------ shop sign board (Tripo cut + mirror fix)
if "sign" in PR:
    # the ornate gold plaque over the awning: cut from the Tripo body (the wall behind it dropped), made left-right
    # symmetric about its own middle, scaled by the house scale and put on the front wall where the skeleton has room
    G = PR["sign"]
    ps = cut("SignTmp", dict(G, no_white=False, no_leaf=True))
    if ps:
        wy, gy = [], []
        for o in ps:
            hsv = face_hsv(o)
            nrm = np.array([p_.normal[:] for p_ in o.data.polygons]).reshape(-1, 3)
            hh, ss, vv = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
            wy += list(centres(o)[(ss < 0.12) & (vv > 0.7) & (nrm[:, 1] > 0.6), 1])
            gy += list(centres(o)[(hh >= 25) & (hh <= 55) & (ss > 0.45), 1])
        wall_g = float(np.percentile([w for w in wy if w < np.median(gy) - 0.1], 80)) if gy and len(wy) > 4 else None
        if wall_g is not None:
            # the plaque's own panel is pale and sits near the wall plane: inside the gold frame's outline keep what is
            # less than 0.35 behind the wall plane (the panel); outside it drop everything not standing out of the wall
            gxz = np.concatenate([centres(o)[(lambda h_: (h_[:, 0] * 360 >= 25) & (h_[:, 0] * 360 <= 55) & (h_[:, 1] > 0.45))(face_hsv(o))][:, [0, 2]]
                                  for o in ps])
            fx0, fx1 = np.percentile(gxz[:, 0], [2, 98])
            fz0, fz1 = np.percentile(gxz[:, 1], [2, 98])
            for o in ps:
                c_ = centres(o)
                inside = (c_[:, 0] > fx0) & (c_[:, 0] < fx1) & (c_[:, 2] > fz0) & (c_[:, 2] < fz1)
                keep = (c_[:, 1] > wall_g + 0.06) | (inside & (c_[:, 1] > wall_g - 0.35))
                bm = bmesh.new()
                bm.from_mesh(o.data)
                bm.faces.ensure_lookup_table()
                bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
                bmesh.ops.delete(bm, geom=[v_ for v_ in bm.verts if not v_.link_faces], context="VERTS")
                bm.to_mesh(o.data)
                bm.free()
            ps = [o for o in ps if len(o.data.polygons)]
        if G.get("drop_spikes", True):                    # long thin shards (Tripo leaf / ornament spikes) out
            for o in ps:
                me = o.data
                V_ = np.array([v_.co[:] for v_ in me.vertices])
                bad = []
                for f_ in me.polygons:
                    vs_ = V_[list(f_.vertices)]
                    if len(vs_) < 3:
                        continue
                    e_ = [np.linalg.norm(vs_[(k + 1) % len(vs_)] - vs_[k]) for k in range(len(vs_))]
                    ar_ = max(f_.area, 1e-9)
                    if max(e_) ** 2 / (2 * ar_) > G.get("spike_ratio", 7.0) and max(e_) > G.get("spike_len", 0.25):
                        bad.append(f_.index)
                if bad:
                    bm = bmesh.new()
                    bm.from_mesh(me)
                    bm.faces.ensure_lookup_table()
                    bmesh.ops.delete(bm, geom=[bm.faces[k] for k in bad], context="FACES")
                    bmesh.ops.delete(bm, geom=[v_ for v_ in bm.verts if not v_.link_faces], context="VERTS")
                    bm.to_mesh(me)
                    bm.free()
        for b in G.get("drop_boxes", []):                  # named bits to cut (Tripo frame)
            for o in ps:
                c_ = centres(o)
                inb = np.ones(len(c_), bool)
                for k, (lo_, hi_) in enumerate(b):
                    inb &= (c_[:, k] >= lo_) & (c_[:, k] <= hi_)
                if inb.any():
                    bm = bmesh.new()
                    bm.from_mesh(o.data)
                    bm.faces.ensure_lookup_table()
                    bmesh.ops.delete(bm, geom=[f for f in bm.faces if inb[f.index]], context="FACES")
                    bmesh.ops.delete(bm, geom=[v_ for v_ in bm.verts if not v_.link_faces], context="VERTS")
                    bm.to_mesh(o.data)
                    bm.free()
        ps = [o for o in ps if len(o.data.polygons)]
        if G.get("drop_pale"):                            # a gold plaque: pale bits left in it are wall shards
            for o in ps:
                h_ = face_hsv(o)
                keep = ~((h_[:, 1] < 0.12) & (h_[:, 2] > 0.7))
                bm = bmesh.new()
                bm.from_mesh(o.data)
                bm.faces.ensure_lookup_table()
                bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
                bmesh.ops.delete(bm, geom=[v_ for v_ in bm.verts if not v_.link_faces], context="VERTS")
                bm.to_mesh(o.data)
                bm.free()
            ps = [o for o in ps if len(o.data.polygons)]
        lo, hi = bbox(ps)
        gx_all = np.concatenate([centres(o)[(lambda h_: (h_[:, 0] * 360 >= 25) & (h_[:, 0] * 360 <= 55) & (h_[:, 1] > 0.45))(face_hsv(o)), 0]
                                 for o in ps])
        gcx = G.get("cx", float(np.mean(np.percentile(gx_all, [1, 99]))) if len(gx_all) > 10 else float((lo[0] + hi[0]) / 2))
        for o in ps:
            mirror_fix(o, gcx, G.get("keep", "+x"))
        ps = [o for o in ps if len(o.data.polygons)]
        lo, hi = bbox(ps)
        T = G["target"]                                    # skeleton: centre x, bottom z, wall face y, width
        k = T["w"] / (hi[0] - lo[0])
        apply(ps, Matrix.Translation((T["cx"], T["y"], T["zb"])) @ Matrix.Scale(k, 4) @ Matrix.Translation((-gcx, -lo[1], -lo[2])))
        tidy_normals(ps)
        for o in ps:
            o.name = o.data.name = o.name.replace("SignTmp", "Sign")
        out_objs += ps
        if G.get("panel_poly"):                         # a plate outline given in the params (x, z after fitting)
            ol_ = [tuple(q) for q in G["panel_poly"]]
            P_ = allv(ps)
            yb_ = float(np.percentile(P_[:, 1], 30)) - G.get("panel_back", 0.0)
            plate = slab(NAME + "_PlaqueBack", ol_ if _ccw(ol_) else ol_[::-1], yb_, 0.12, lambda x, z: (0.5, 0.5), (0.5, 0.5))
            plate.data.materials.append(plain_mat(NAME + "_SignGold", tuple(c_ * G.get("panel_shade", 1.0) for c_ in sign_gold(ps)),
                                                  G.get("panel_metal", 0.45), G.get("panel_rough", 0.3)))
            tidy_normals([plate])
            out_objs.append(plate)
        elif G.get("back_panel", True):
            # an exact plain-gold plate behind the Tripo frame (Tripo's panel has holes where its shine was pale), cut to
            # the sign's own front silhouette: the faces projected on x-z, inside holes filled, shrunk 0.15 so the frame
            # hides its edge; built as row strips
            res = 0.05
            P_ = allv(ps)
            x0_, x1_ = P_[:, 0].min() - 0.2, P_[:, 0].max() + 0.2
            z0_, z1_ = P_[:, 2].min() - 0.2, P_[:, 2].max() + 0.2
            nx_, nz_ = int((x1_ - x0_) / res) + 1, int((z1_ - z0_) / res) + 1
            mask = np.zeros((nz_, nx_), bool)
            # only the plaque's own front: gold faces looking forward, near the front plane (not the dome / wall behind)
            ylist = []
            for o in ps:
                h_ = face_hsv(o)
                nrm_ = np.array([p_.normal[:] for p_ in o.data.polygons]).reshape(-1, 3)
                g_ = (h_[:, 0] * 360 >= 25) & (h_[:, 0] * 360 <= 55) & (h_[:, 1] > 0.35) & (nrm_[:, 1] > 0.5)
                ylist += list(centres(o)[g_, 1])
            ythr = float(np.percentile(ylist, 40)) - G.get("panel_depth", 0.3) if ylist else -1e9
            for o in ps:
                me = o.data
                me.calc_loop_triangles()
                V_ = np.array([v_.co[:] for v_ in me.vertices])
                h_ = face_hsv(o)
                nrm_ = np.array([p_.normal[:] for p_ in me.polygons]).reshape(-1, 3)
                cy_ = centres(o)[:, 1]
                okf = (h_[:, 0] * 360 >= 20) & (h_[:, 0] * 360 <= 60) & (h_[:, 1] > 0.25) & (nrm_[:, 1] > 0.3) & (cy_ >= ythr)
                for t_ in me.loop_triangles:
                    if not okf[t_.polygon_index]:
                        continue
                    T_ = V_[list(t_.vertices)][:, [0, 2]]
                    a_ = ((T_ - [x0_, z0_]) / res)
                    c0, r0 = np.floor(a_.min(0)).astype(int)
                    c1, r1 = np.ceil(a_.max(0)).astype(int)
                    if c1 < c0 or r1 < r0:
                        continue
                    xs_, zs_ = np.meshgrid(np.arange(c0, c1 + 1) + 0.5, np.arange(r0, r1 + 1) + 0.5)
                    d_ = (a_[1, 1] - a_[2, 1]) * (a_[0, 0] - a_[2, 0]) + (a_[2, 0] - a_[1, 0]) * (a_[0, 1] - a_[2, 1])
                    if abs(d_) < 1e-9:
                        continue
                    l0 = ((a_[1, 1] - a_[2, 1]) * (xs_ - a_[2, 0]) + (a_[2, 0] - a_[1, 0]) * (zs_ - a_[2, 1])) / d_
                    l1 = ((a_[2, 1] - a_[0, 1]) * (xs_ - a_[2, 0]) + (a_[0, 0] - a_[2, 0]) * (zs_ - a_[2, 1])) / d_
                    ins = (l0 >= -0.05) & (l1 >= -0.05) & (1 - l0 - l1 >= -0.05)
                    rr_ = np.clip(np.arange(r0, r1 + 1), 0, nz_ - 1)
                    cc_ = np.clip(np.arange(c0, c1 + 1), 0, nx_ - 1)
                    sub_ = mask[rr_[:, None], cc_[None, :]]
                    sub_ |= ins
                    mask[rr_[:, None], cc_[None, :]] = sub_
            def _grow(m, k, grow=True):
                for _ in range(k):
                    m2 = m.copy()
                    if grow:
                        m2[1:] |= m[:-1]; m2[:-1] |= m[1:]; m2[:, 1:] |= m[:, :-1]; m2[:, :-1] |= m[:, 1:]
                    else:
                        m2[1:] &= m[:-1]; m2[:-1] &= m[1:]; m2[:, 1:] &= m[:, :-1]; m2[:, :-1] &= m[:, 1:]
                    m = m2
                return m
            kc_ = int(G.get("panel_close", 0.0) / res)
            mask = _grow(mask, kc_)                      # close gaps (a hole open at the bottom edge)
            # inside = not reachable from the border through empty cells
            out_ = np.zeros_like(mask)
            stack = [(0, c) for c in range(nx_)] + [(nz_ - 1, c) for c in range(nx_)] + [(r, 0) for r in range(nz_)] + [(r, nx_ - 1) for r in range(nz_)]
            while stack:
                r, c = stack.pop()
                if 0 <= r < nz_ and 0 <= c < nx_ and not out_[r, c] and not mask[r, c]:
                    out_[r, c] = True
                    stack += [(r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)]
            fill = _grow(~out_, kc_ + int(G.get("panel_inset", 0.15) / res), grow=False)   # undo the closing, then shrink
            # the biggest connected part only (the plaque), stray bits dropped
            lab = np.zeros(fill.shape, int)
            best_, bestn, cur = 0, 0, 0
            for r0_ in range(nz_):
                for c0_ in range(nx_):
                    if fill[r0_, c0_] and not lab[r0_, c0_]:
                        cur += 1
                        st_, n_ = [(r0_, c0_)], 0
                        lab[r0_, c0_] = cur
                        while st_:
                            r, c = st_.pop()
                            n_ += 1
                            for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                                if 0 <= rr < nz_ and 0 <= cc < nx_ and fill[rr, cc] and not lab[rr, cc]:
                                    lab[rr, cc] = cur
                                    st_.append((rr, cc))
                        if n_ > bestn:
                            best_, bestn = cur, n_
            fill = lab == best_
            yb_ = (ythr + G.get("panel_depth", 0.3) * 0.5) if ylist else float(np.percentile(P_[:, 1], 30))
            me2 = bpy.data.meshes.new(NAME + "_PlaqueBack")
            bm2 = bmesh.new()
            nq = 0
            for r in range(nz_):
                cols_ = np.nonzero(fill[r])[0]
                if not len(cols_):
                    continue
                runs = np.split(cols_, np.nonzero(np.diff(cols_) > 1)[0] + 1)
                for run in runs:
                    if len(run) < 3:
                        continue
                    xa, xb = x0_ + run[0] * res, x0_ + (run[-1] + 1) * res
                    za, zb = z0_ + r * res, z0_ + (r + 1) * res
                    vs = [bm2.verts.new(q) for q in ((xa, yb_, za), (xb, yb_, za), (xb, yb_, zb), (xa, yb_, zb))]
                    vb = [bm2.verts.new((q.co.x, yb_ - 0.12, q.co.z)) for q in vs]
                    bm2.faces.new(vs)
                    bm2.faces.new(vb[::-1])
                    nq += 1
            bmesh.ops.remove_doubles(bm2, verts=bm2.verts, dist=1e-5)
            bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
            bm2.to_mesh(me2)
            bm2.free()
            plate = bpy.data.objects.new(NAME + "_PlaqueBack", me2)
            bpy.context.scene.collection.objects.link(plate)
            plate.data.materials.append(plain_mat(NAME + "_SignGold", sign_gold(ps), G.get("panel_metal", 0.45), 0.3))
            out_objs.append(plate)
            REPORT.setdefault("pieces", {}).setdefault("SignPlate", {"strips": nq, "cell": res})
        lo2, hi2 = bbox(ps)
        REPORT["pieces"]["Sign"] = {"fix": "Tripo plaque cut (wall behind dropped at y %s), mirror about x = %.2f kept %s, scale %.3f"
                                    % (None if wall_g is None else round(wall_g, 2), gcx, G.get("keep", "+x"), k),
                                    "box": [[round(float(v), 2) for v in lo2], [round(float(v), 2) for v in hi2]],
                                    "faces": sum(len(o.data.polygons) for o in ps)}
        print("[deco] sign", REPORT["pieces"]["Sign"], flush=True)

# ------------------------------------------------------------------ shop window goods (projected backdrop)
if "display" in PR:
    # what Tripo shows behind the shop window (bread / fruit / potion shelves) is projected from the front onto an exact
    # panel standing behind the skeleton's shop glass (window glass and frame faces passed through): Tripo's paint +
    # relief, the opening's exact size
    Q = PR["display"]
    g = skel_box("Shop_Glass")
    if g is not None:
        (gx0, gy0, gz0), (gx1, gy1, gz1) = g
        top = max(gz1, (skel_box("Shop_Glass") or g)[1][2])
        yb = gy0 - Q.get("depth", 0.55)
        (tx0, tx1), (ty0, ty1), (tz0, tz1) = Q["box"]
        outline = [(gx1, gz0), (gx1, top), (gx0, top), (gx0, gz0)]
        W_, H_ = gx1 - gx0, top - gz0

        def uv_d(x, z):
            return (0.02 + 0.96 * (x - gx0) / W_, 0.02 + 0.96 * (z - gz0) / H_)

        pan = slab(NAME + "_Display", outline, yb, 0.1, uv_d, uv_d(gx0 + 0.1, gz0 + 0.1))
        srcs = []
        for o in SRC:
            if not _textured(o) or "_Awning" in o.name:
                continue
            c = centres(o)
            m = (c[:, 0] >= tx0) & (c[:, 0] <= tx1) & (c[:, 1] >= ty0) & (c[:, 1] <= ty1) & (c[:, 2] >= tz0) & (c[:, 2] <= tz1)
            n_ = take(o, m, o.name + "_DispSrc")
            if n_:
                srcs.append(n_)
        src_d = proj_bake.Source(srcs)
        th = src_d.tri_hsv()                                # glass panes (pale blue) and the gold window frame let rays through
        glass = (th[:, 0] > 175) & (th[:, 0] < 240) & (th[:, 1] > 0.08)
        src_d.skip_where(glass | (src_d.FN[:, 1] < 0.2))
        src_d.strict = True
        yt_mid = float((allv(srcs)[:, 1].max() + allv(srcs)[:, 1].min()) / 2)
        back_ = float((allv(srcs)[:, 1].max() - allv(srcs)[:, 1].min()) / 2 + 0.6)

        def xf_d(P):
            xt = tx1 - (P[:, 0] - gx0) / W_ * (tx1 - tx0) if Q.get("flip_x", False) else tx0 + (P[:, 0] - gx0) / W_ * (tx1 - tx0)
            zt = tz0 + (P[:, 2] - gz0) / H_ * (tz1 - tz0)
            return np.c_[xt, np.full(len(P), yt_mid), zt]

        _oq = src_d.query
        src_d.query = lambda P, ray=None, back=0.6: _oq(xf_d(P), ray, back_)
        tmpd = slab(NAME + "_DispBake", outline, yb, 0.1, uv_d, uv_d(gx0 + 0.1, gz0 + 0.1))
        mp = proj_bake.bake(tmpd, src_d, size=Q.get("size", 512), ray=(0, -1, 0), relief=True)
        bpy.data.objects.remove(tmpd)
        pan.data.materials.append(proj_bake.save_maps(mp, WORK, NAME + "_Display"))
        out_objs.append(pan)
        for o in srcs:
            bpy.data.objects.remove(o)
        REPORT["pieces"]["Display"] = {"fix": "exact panel %.2f x %.2f behind the shop glass (y %.2f) + Tripo window contents "
                                       "projected from the front (glass / frame passed through, hit %.0f %%)" % (W_, H_, yb, 100 * mp["hit"]),
                                       "tripo_box": Q["box"]}
        print("[deco] display", REPORT["pieces"]["Display"], flush=True)

# ------------------------------------------------------------------ roof glass (skylight / greenhouse): exact frame
if "roofglass" in PR:
    # Tripo's roof lantern (05: a hipped glass skylight on a gold curb) / greenhouse (flower shop: a gabled glass house,
    # ridge front to back, finials) measured on Tripo, built exact on the skeleton's Skylight_Base: gold bars + glass
    R_ = PR["roofglass"]
    b = skel_box("Skylight_Base", exact=True)
    if b is not None:
        (bx0, by0, bz0), (bx1, by1, bz1) = b
        ins = R_.get("inset", 0.3)
        x0, x1, y0, y1, z0 = bx0 + ins, bx1 - ins, by0 + ins, by1 - ins, bz1
        W_, D_ = x1 - x0, y1 - y0
        bw = R_.get("bar", 0.14)
        gm_ = bpy.data.meshes.new(NAME + "_RoofFrame")
        bm = bmesh.new()
        gl = bpy.data.meshes.new(NAME + "_RoofGlass")
        bg = bmesh.new()

        def bar(a, b):
            box_obj(bm, a, b, bw)

        def pane(pts):
            vs = [bg.verts.new(p_) for p_ in pts]
            bg.faces.new(vs)

        cx_, cy_ = (x0 + x1) / 2, (y0 + y1) / 2
        if R_["type"] == "hip":
            ch = R_.get("curb_h", 0.45)
            H_ = R_.get("h", 1.3)
            tw, td = W_ * R_.get("top_w", 0.6), D_ * R_.get("top_d", 0.35)
            # curb: a gold box band
            cm = bpy.data.meshes.new("curb")
            bmc = bmesh.new()
            bmesh.ops.create_cube(bmc, size=1.0)
            bmesh.ops.scale(bmc, vec=(W_ + 0.1, D_ + 0.1, ch), verts=bmc.verts)
            bmesh.ops.translate(bmc, vec=(cx_, cy_, z0 + ch / 2), verts=bmc.verts)
            bmc.to_mesh(cm)
            bmc.free()
            bm.from_mesh(cm)
            zb_, zt_ = z0 + ch, z0 + ch + H_
            B4 = [(x0, y0, zb_), (x1, y0, zb_), (x1, y1, zb_), (x0, y1, zb_)]
            T4 = [(cx_ - tw / 2, cy_ - td / 2, zt_), (cx_ + tw / 2, cy_ - td / 2, zt_), (cx_ + tw / 2, cy_ + td / 2, zt_), (cx_ - tw / 2, cy_ + td / 2, zt_)]
            for k_ in range(4):
                bar(B4[k_], B4[(k_ + 1) % 4])
                bar(T4[k_], T4[(k_ + 1) % 4])
                bar(B4[k_], T4[k_])
                pane([B4[k_], B4[(k_ + 1) % 4], T4[(k_ + 1) % 4], T4[k_]])
            pane(T4[::-1])
            for (a0, a1, b0, b1), nm_ in (((B4[3], B4[2], T4[3], T4[2]), R_.get("mull_front", 3)), ((B4[0], B4[1], T4[0], T4[1]), R_.get("mull_front", 3)),
                                         ((B4[1], B4[2], T4[1], T4[2]), R_.get("mull_side", 2)), ((B4[0], B4[3], T4[0], T4[3]), R_.get("mull_side", 2))):
                for j in range(1, nm_ + 1):
                    f = j / (nm_ + 1)
                    bar(tuple(np.array(a0) + (np.array(a1) - np.array(a0)) * f), tuple(np.array(b0) + (np.array(b1) - np.array(b0)) * f))
            if R_.get("finial", True):
                fz = zt_
                fo = proj_bake.lathe([(0.0, 0.0), (0.18, 0.02), (0.22, 0.1), (0.1, 0.18), (0.1, 0.24), (0.3, 0.42), (0.32, 0.55),
                                      (0.24, 0.72), (0.0, 0.86)], seg=16, name=NAME + "_RoofFinial")
                fo.data.transform(Matrix.Translation((cx_, cy_, fz)))
                fin_objs = [fo]
            else:
                fin_objs = []
        else:                                            # gable: ridge along y (front to back), the gable faces the front
            wh = R_.get("wall_h", 0.9)
            rh = R_.get("ridge_h", 3.6)
            za, zr = z0 + wh, z0 + wh + rh
            C = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)]
            Cw = [(x, y, za) for x, y, _ in C]
            Rf, Rb = (cx_, y1, zr), (cx_, y0, zr)        # front (+y) / back ridge ends
            for k_ in range(4):
                bar(C[k_], C[(k_ + 1) % 4])
                bar(C[k_], Cw[k_])
            bar(Cw[0], Cw[1])
            bar(Cw[2], Cw[3])
            bar(Cw[1], Cw[2])
            bar(Cw[3], Cw[0])
            bar(Rf, Rb)
            for (l_, r_), rr_ in (((Cw[3], Cw[2]), Rf), ((Cw[0], Cw[1]), Rb)):   # gable rafters
                bar(l_, rr_)
                bar(r_, rr_)
            nr = R_.get("rafters", 3)                    # roof rafters between the gables, both slopes
            for j in range(1, nr + 1):
                yj = y0 + (y1 - y0) * j / (nr + 1)
                bar((x0, yj, za), (cx_, yj, zr))
                bar((x1, yj, za), (cx_, yj, zr))
                bar((x0, yj, z0), (x0, yj, za))
                bar((x1, yj, z0), (x1, yj, za))
            nm_ = R_.get("mull_front", 3)                # gable mullions (front and back)
            for yg, top_ in ((y1, Rf), (y0, Rb)):
                for j in range(1, nm_ + 1):
                    xj = x0 + W_ * j / (nm_ + 1)
                    zt_ = za + rh * (1 - abs(xj - cx_) / (W_ / 2))
                    bar((xj, yg, z0), (xj, yg, zt_))
                bar((x0, yg, za + rh * 0.35), (x1, yg, za + rh * 0.35)) if R_.get("transom", True) else None
            # glass: low walls, two roof slopes, two gable triangles
            pane([C[0], C[1], Cw[1], Cw[0]])
            pane([C[2], C[3], Cw[3], Cw[2]])
            pane([C[1], C[2], Cw[2], Cw[1]])
            pane([C[3], C[0], Cw[0], Cw[3]])
            pane([Cw[0], Rb, Rf, Cw[3]])
            pane([Cw[1], Cw[2], Rf, Rb])
            pane([Cw[3], Cw[2], Rf])
            pane([Cw[0], Rb, Cw[1]])
            fin_objs = []
            for k_, (fx, fy, fz) in enumerate([Rf, Rb] + ([(x, y, za) for x, y, _ in C] if R_.get("corner_finials", True) else [])):
                sc_ = 1.0 if k_ < 2 else 0.7
                fo = proj_bake.lathe([(0.0, 0.0), (0.16 * sc_, 0.02), (0.2 * sc_, 0.1), (0.09 * sc_, 0.2), (0.24 * sc_, 0.38),
                                      (0.26 * sc_, 0.5), (0.12 * sc_, 0.7), (0.0, 0.95 * sc_)], seg=16, name="%s_RoofFinial%d" % (NAME, k_))
                fo.data.transform(Matrix.Translation((fx, fy, fz)))
                fin_objs.append(fo)
        bm.to_mesh(gm_)
        bm.free()
        bg.to_mesh(gl)
        bg.free()
        fr = bpy.data.objects.new(NAME + "_RoofFrame", gm_)
        bpy.context.scene.collection.objects.link(fr)
        go = bpy.data.objects.new(NAME + "_RoofGlass", gl)
        bpy.context.scene.collection.objects.link(go)
        gold_m = plain_mat(NAME + "_RoofGold", (255, 168, 36), 1.0, 0.28)
        fr.data.materials.append(gold_m)
        for fo in fin_objs:
            fo.data.materials.append(gold_m)
        go.data.materials.append(plain_mat(NAME + "_RoofGlassMat", (150, 205, 245), 0.0, 0.05, alpha=0.35))
        tidy_normals([fr] + fin_objs)
        out_objs += [fr, go] + fin_objs
        REPORT["pieces"]["RoofGlass"] = {"fix": "%s roof glass built exact on Skylight_Base %.1f x %.1f (Tripo proportions in params): "
                                         "gold bars %.2f, glass panes, finials" % (R_["type"], W_, D_, bw)}
        print("[deco] roofglass", REPORT["pieces"]["RoofGlass"], flush=True)

# ------------------------------------------------------------------ cloth canopy (Juice roof parasol): exact
if "canopy" in PR:
    # Tripo's striped square roof canopy measured (eave box, peak, valance): a square pyramid split into stripes per side
    # (two objects, CanopyA / CanopyB = the two cloth colours; Studio: Fabric + HH_Fabric + the colour), a scalloped
    # valance under the eave; posts are the skeleton's pergola, the finial a Tripo cap (caps with a target)
    C_ = PR["canopy"]
    cx_, cy_, W_, D_ = C_["cx"], C_["cy"], C_["w"], C_["d"]
    ze, hp, vh, ns = C_["z_eave"], C_["h"], C_.get("valance", 0.55), C_.get("n", 4)
    apex = (cx_, cy_, ze + hp)
    corners = [(cx_ - W_ / 2, cy_ - D_ / 2), (cx_ + W_ / 2, cy_ - D_ / 2), (cx_ + W_ / 2, cy_ + D_ / 2), (cx_ - W_ / 2, cy_ + D_ / 2)]
    bms = [bmesh.new(), bmesh.new()]
    k_ = 0
    for e in range(4):
        (x0_, y0_), (x1_, y1_) = corners[e], corners[(e + 1) % 4]
        nx_, ny_ = (y1_ - y0_), -(x1_ - x0_)
        ln_ = math.hypot(nx_, ny_)
        nx_, ny_ = nx_ / ln_, ny_ / ln_                # outward normal of this side
        for j in range(ns):
            ta, tb = j / ns, (j + 1) / ns
            pa = (x0_ + (x1_ - x0_) * ta, y0_ + (y1_ - y0_) * ta, ze)
            pb = (x0_ + (x1_ - x0_) * tb, y0_ + (y1_ - y0_) * tb, ze)
            bm_ = bms[(k_ + j) % 2]
            va, vb, vc = bm_.verts.new(pa), bm_.verts.new(pb), bm_.verts.new(apex)
            bm_.faces.new((va, vb, vc))
            # valance: a flat band below the eave with a half-round scallop, pushed out 0.02
            seg = 8
            pts = [(pa[0] + nx_ * 0.02, pa[1] + ny_ * 0.02, ze), (pb[0] + nx_ * 0.02, pb[1] + ny_ * 0.02, ze)]
            r_ = math.hypot(pb[0] - pa[0], pb[1] - pa[1]) / 2
            mx_, my_ = (pa[0] + pb[0]) / 2 + nx_ * 0.02, (pa[1] + pb[1]) / 2 + ny_ * 0.02
            ux_, uy_ = (pb[0] - pa[0]) / (2 * r_), (pb[1] - pa[1]) / (2 * r_)
            for q in range(seg + 1):
                a_ = math.pi * q / seg
                pts.append((mx_ + ux_ * r_ * math.cos(a_), my_ + uy_ * r_ * math.cos(a_), ze - vh - r_ * 0.55 * math.sin(a_)))
            vs_ = [bm_.verts.new(q) for q in pts]
            try:
                bm_.faces.new(vs_)
            except ValueError:
                pass
        k_ += ns
    objs_c = []
    cols_ = C_.get("colors", [[110, 165, 232], [250, 250, 248]])
    for bi, bm_ in enumerate(bms):
        bmesh.ops.remove_doubles(bm_, verts=bm_.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces)
        me_ = bpy.data.meshes.new("%s_Canopy%s" % (NAME, "AB"[bi]))
        bm_.to_mesh(me_)
        bm_.free()
        o_ = bpy.data.objects.new(me_.name, me_)
        bpy.context.scene.collection.objects.link(o_)
        o_.data.materials.append(plain_mat(me_.name + "Cloth", cols_[bi], 0.0, 0.85))
        # cloth is seen from both sides: a back copy of every face
        bm2_ = bmesh.new()
        bm2_.from_mesh(me_)
        dup = bmesh.ops.duplicate(bm2_, geom=bm2_.faces[:])
        bmesh.ops.reverse_faces(bm2_, faces=[g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)])
        bm2_.to_mesh(me_)
        bm2_.free()
        objs_c.append(o_)
    out_objs += objs_c
    REPORT["pieces"]["Canopy"] = {"fix": "exact square canopy %.2f x %.2f, eave %.2f, peak +%.2f, %d stripes a side, scalloped valance %.2f "
                                  "(Tripo measured), colours %s" % (W_, D_, ze, hp, ns, vh, cols_)}
    print("[deco] canopy", REPORT["pieces"]["Canopy"], flush=True)

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
