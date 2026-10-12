"""Block-body NPC, skeleton first (이미지 생성 4, 10/12, SPEC A23-149: "몸을 먼저 만든 다음에 입히는 식으로, 사람도 건물처럼").

Builds one R15 body from exact blocks (Blender units = studs, Z up, the NPC faces +Y, its right = +X):
  15 parts with the Roblox R15 names (Head, UpperTorso, LowerTorso, Left/Right Upper/Lower Arm + Hand, Left/Right
  Upper/Lower Leg + Foot), square torso and limbs like the 2D, C-shaped hands, round-cornered block head;
  dressing = solid colours: every face's UVs sit in one cell of a tiny palette PNG (closest filter), so the clothes /
  apron / buttons / cuffs / shoes are flat colours from the 2D, with the colour edges on real mesh edges.
  Hat + hair (+ the apron bow) are cut from the approved Tripo model (no new Tripo job): faces at or inside the head
  block are dropped (the old face goes), the rest keeps the Tripo mesh and texture; the halo is an exact torus.
  The face is left blank (A23-149: method still with the user).

Writes <out>/<npc>_block.glb (parts + HatHair + Bow + Halo), <out>/<npc>_rig.json (Roblox-space part centres and
the 15 R15 joints: Root, Waist, Neck, Left/Right Shoulder, Elbow, Wrist, Hip, Knee, Ankle) and preview renders.

  blender --background --factory-startup --python tools/npc_block_body.py -- BakerGranny [--render] [--px 900]
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# palette cells (sRGB, sampled from the approved 2D 4 views); the PNG is 4x4 cells of 4 px
PAL = {
    "dress": (134, 176, 234), "apron": (240, 232, 230), "cuff": (247, 241, 240), "button": (214, 161, 80),
    "skin": (250, 192, 148), "shoe": (132, 85, 59), "tights": (72, 60, 58), "halo": (236, 186, 82),
    "collar": (126, 169, 229), "sole": (95, 60, 42),
}

NPC = {
    "BakerGranny": {
        "tripo": "art/models/tripo/web/NPC_HaloBakerGranny_HD_src.glb",
        "k": 6.68,            # Tripo units -> studs (ground to head-block top 5.2)
        "head_scale": 1.08,   # 2D head is bigger than Tripo's: hat / hair / head grow together
        "waist": 2.70, "neck": 3.95,
        "torso": (1.44, 0.88), "torso_bevel": 0.10,
        "skirt": [(2.84, 1.36, 0.84, 0.18), (0.67, 2.68, 1.60, 0.34)],   # (z, width, depth, corner r)
        "belt": (2.56, 2.80),
        "bib": (0.84, 2.78, 3.60), "buttons": [3.38, 3.15, 2.92], "button_r": 0.10,
        "apron_skirt": (2.56, 0.92, 1.36, 2.00),      # z top, z bottom, width top, width bottom
        "straps": (0.36, 0.12),
        "collar": (0.70, 0.62, 3.80, 3.98),
        "shoulder": (0.98, 3.60), "arm": 0.50, "upper_arm": (0.20, 0.70), "lower_arm": 0.68, "cuff_h": 0.24,
        "splay": 22.0,
        "hip": (0.45, 2.35), "knee": 1.40, "ankle": 0.50, "leg": 0.52,
        "shoe": (0.80, 1.05, 0.46, 0.06, 0.07, 0.12),  # width, length, height, sole, outward offset, forward offset
        "hand": (0.19, 0.115, 75.0),                    # C centre radius, tube radius, opening degrees
        "bow_box": ((-0.20, -0.068), (-0.095, 0.095), (-0.20, -0.035)),   # Tripo coords: x (back), y, z
        "halo_tube": 0.05,
    },
}


# ---------------------------------------------------------------- mesh helpers
def new_obj(name, bm):
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:   # round parts smooth, block faces / caps keep a crisp edge
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.6:
            e.smooth = False
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tag(ob, col):
    ob["col"] = col
    return ob


def rbox(name, size, centre, bevel, col, segs=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=min(bevel, min(size) * 0.49), segments=segs,
                        profile=0.5, affect="EDGES")
    for v in bm.verts:
        v.co += Vector(centre)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return tag(new_obj(name, bm), col)


def rrect(w, d, r, n=5):
    r = min(r, w / 2 - 1e-3, d / 2 - 1e-3)
    pts = []
    for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def loft(name, rings, col, centre=(0, 0)):
    """rings = [(z, w, d, r)] top to bottom; capped."""
    bm = bmesh.new()
    loops = []
    for z, w, d, r in rings:
        loops.append([bm.verts.new((centre[0] + x, centre[1] + y, z)) for x, y in rrect(w, d, r)])
    n = len(loops[0])
    for a, b in zip(loops, loops[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(loops[0])
    bm.faces.new(list(reversed(loops[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return tag(new_obj(name, bm), col)


def slab(name, poly, col):
    """poly = list of (front Vector, back Vector) pairs around the outline -> closed prism."""
    bm = bmesh.new()
    f = [bm.verts.new(p) for p, _ in poly]
    b = [bm.verts.new(q) for _, q in poly]
    n = len(poly)
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    for i in range(n):
        bm.faces.new((f[i], b[i], b[(i + 1) % n], f[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return tag(new_obj(name, bm), col)


def sphere(name, centre, r, col, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(centre)
    return tag(new_obj(name, bm), col)


def c_hand(name, R, rt, open_deg, col):
    """C ring in the plane spanned by down (-Z) and the hole-axis' normal; hole axis = (cos45, sin45, 0)-ish,
    opening straight down. Built at the origin (top of the C at z = 0)."""
    axis = Vector((1, 1, 0)).normalized()
    up = Vector((0, 0, 1))
    side = axis.cross(up).normalized()
    centre = Vector((0, 0, -(R + rt) + 0.02))
    bm = bmesh.new()
    seg, ring = 28, 14
    a0, a1 = math.radians(-90 + open_deg / 2), math.radians(270 - open_deg / 2)
    rings = []
    for i in range(seg + 1):
        a = a0 + (a1 - a0) * i / seg
        c = centre + (side * math.cos(a) + up * math.sin(a)) * R
        rad = (side * math.cos(a) + up * math.sin(a))
        rv = []
        for j in range(ring):
            b = 2 * math.pi * j / ring
            rv.append(bm.verts.new(c + (rad * math.cos(b) + axis * math.sin(b)) * rt))
        rings.append(rv)
    for a, b in zip(rings, rings[1:]):
        for j in range(ring):
            bm.faces.new((a[j], a[(j + 1) % ring], b[(j + 1) % ring], b[j]))
    # round end caps
    for rv, sgn, i in ((rings[0], -1, 0), (rings[-1], 1, seg)):
        a = a0 + (a1 - a0) * i / seg
        tang = (-side * math.sin(a) + up * math.cos(a)) * sgn
        c = centre + (side * math.cos(a) + up * math.sin(a)) * R
        prev = rv
        for k in range(1, 4):
            t = k / 4
            rr = math.cos(t * math.pi / 2)
            cc = c + tang * rt * math.sin(t * math.pi / 2)
            nv = [bm.verts.new(cc + (v.co - c) * rr) for v in rv]
            for j in range(ring):
                q = (prev[j], prev[(j + 1) % ring], nv[(j + 1) % ring], nv[j])
                bm.faces.new(q)
            prev = nv
        tip = bm.verts.new(c + tang * rt)
        for j in range(ring):
            bm.faces.new((prev[j], prev[(j + 1) % ring], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return tag(new_obj(name, bm), col)


def torus(name, centre, R, r, col):
    bm = bmesh.new()
    seg, ring = 64, 16
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c = Vector((R * math.cos(a), R * math.sin(a), 0))
        rad = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(Vector(centre) + c + (rad * math.cos(b) + Vector((0, 0, 1)) * math.sin(b)) * r)
                      for b in (2 * math.pi * j / ring for j in range(ring))])
    for i in range(seg):
        a, b = rings[i], rings[(i + 1) % seg]
        for j in range(ring):
            bm.faces.new((a[j], a[(j + 1) % ring], b[(j + 1) % ring], b[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return tag(new_obj(name, bm), col)


def xform(ob, M):
    ob.data.transform(M)
    ob.data.update()


def join(name, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = ob.data.name = name
    return ob


# ---------------------------------------------------------------- palette
def palette_image(path):
    keys = list(PAL)
    W = 16
    img = bpy.data.images.new("palette", W, W, alpha=False)
    px = np.ones((W, W, 4), dtype=np.float32)
    for i, k in enumerate(keys):
        cx, cy = i % 4, i // 4
        px[cy * 4:(cy + 1) * 4, cx * 4:(cx + 1) * 4, :3] = np.array(PAL[k]) / 255.0
    img.pixels[:] = px.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "sRGB"
    return img, {k: ((i % 4) * 4 + 2) / W for i, k in enumerate(keys)}, {k: ((i // 4) * 4 + 2) / W for i, k in enumerate(keys)}


def set_pal_uv(ob, u, v):
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    c = ob["col"]
    for lp in uv:
        lp.uv = (u[c], v[c])


# ---------------------------------------------------------------- Tripo cut
def tripo_load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    obs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    ob = obs[0]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.parent = None
    for o in [o for o in bpy.data.objects if o not in before and o is not ob]:
        bpy.data.objects.remove(o)
    return ob


def base_image(ob):
    for n in ob.active_material.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            l = n.inputs["Base Color"].links
            if l and l[0].from_node.type == "TEX_IMAGE":
                return l[0].from_node.image
    return [n.image for n in ob.active_material.node_tree.nodes if n.type == "TEX_IMAGE"][0]


def vert_colours(ob):
    img = base_image(ob)
    w, h = img.size
    P = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[..., :3]
    me = ob.data
    uv = me.uv_layers.active.data
    acc = np.zeros((len(me.vertices), 3))
    cnt = np.zeros(len(me.vertices))
    for lp in me.loops:
        u = uv[lp.index].uv
        x = min(w - 1, max(0, int(u[0] * w)))
        y = min(h - 1, max(0, int(u[1] * h)))
        acc[lp.vertex_index] += P[y, x]
        cnt[lp.vertex_index] += 1
    return acc / np.maximum(cnt, 1)[:, None]


def is_skin(c):
    mx, mn = c.max(-1), c.min(-1)
    s = (mx - mn) / np.maximum(mx, 1e-4)
    return (c[..., 0] > c[..., 2] + 0.12) & (s > 0.15) & (s < 0.6) & (mx > 0.55) & (c[..., 0] >= c[..., 1])


def keep_faces(ob, keep):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep[f.index]], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def erode_spikes(ob, lo, hi, iters=3):
    """Faces near the head box that hang on by one edge (the saw-tooth left where skin triangles went) are removed."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)   # glTF splits at UV seams: weld before counting
    lo, hi = Vector(lo.tolist()), Vector(hi.tolist())
    gone = 0
    for _ in range(iters):
        kill = []
        for f in bm.faces:
            c = f.calc_center_median()
            if not all(lo[i] - 0.02 < c[i] < hi[i] + 0.02 for i in range(3)):
                continue
            if sum(1 for e in f.edges if len(e.link_faces) == 2) <= 1:
                kill.append(f)
        if not kill:
            break
        gone += len(kill)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    return gone


def dup(ob, name):
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    return c


# ---------------------------------------------------------------- build
def build(P):
    k = P["k"]
    out = {}
    # --- Tripo measurements
    T = tripo_load(os.path.join(ROOT, P["tripo"]))
    V = np.array([v.co[:] for v in T.data.vertices])
    C = vert_colours(T)
    skin = is_skin(C)
    zg = V[:, 2].min()
    zs0 = np.sort(V[:, 2])[::-1]
    t0 = zs0[zs0 > zs0[0] - 0.09]
    g0 = int(np.argmax(t0[:-1] - t0[1:]))
    hv = V[V[:, 2] > (t0[g0] + t0[g0 + 1]) / 2]
    face = skin & (V[:, 2] > 0.105) & (V[:, 2] < 0.22) & (V[:, 0] > 0.0) & (np.abs(V[:, 1]) < 0.13)
    fv = V[face]
    head_w_t = float(np.percentile(fv[:, 1], 99) - np.percentile(fv[:, 1], 1))
    mid = skin & (V[:, 2] > 0.115) & (V[:, 2] < 0.25) & (np.abs(V[:, 1]) < 0.05) & (V[:, 0] > 0.0)
    head_front_t = float(np.percentile(V[mid, 0], 97))   # the face's own front (centre), not the cheeks / hair
    neck_t = float(np.percentile(fv[:, 2], 0.5))
    head_d_t = head_w_t * 0.92
    head_h_t = head_w_t * 1.15   # the top is hidden in the hat
    print("[block] tripo head w %.4f front %.4f neck %.4f ground %.4f halo z %.4f" % (head_w_t, head_front_t, neck_t, zg, hv[:, 2].mean()))
    kh = k * P["head_scale"]
    hw, hd, hh = head_w_t * kh, head_d_t * kh, head_h_t * kh
    neck = P["neck"]
    head_c = Vector((0, 0, neck + hh / 2))
    head_c_t = np.array([head_front_t - head_d_t / 2, 0.0, neck_t + head_h_t / 2])
    # Tripo (front +X) -> ours (front +Y): (x, y, z) -> (-y, x, z)
    Rz = Matrix.Rotation(math.radians(90), 4, "Z")
    M_head = Matrix.Translation(head_c) @ Rz @ Matrix.Scale(kh, 4) @ Matrix.Translation(Vector((-head_c_t).tolist()))
    M_body = Rz @ Matrix.Scale(k, 4) @ Matrix.Translation(Vector((0, 0, -zg)))

    # --- hat + hair: everything above the neck except the halo and the old face. Our head block is the Tripo head
    # block shrunk a little, so hair lying flat on the old head stays on top of ours; inside the head box only the
    # skin / face-feature colours go (eyes, mouth, blush, brows), cut along the Tripo triangles -> no torn fringe.
    F = np.array([p.center[:] for p in T.data.polygons])
    fc = np.array([C[list(p.vertices)].mean(0) for p in T.data.polygons])
    mx_, mn_ = fc.max(-1), fc.min(-1)
    sat = (mx_ - mn_) / np.maximum(mx_, 1e-4)
    reddish = (fc[:, 0] > fc[:, 1] + 0.25) & (sat > 0.3)   # mouth, blush; not the gold band
    feature = is_skin(fc) | reddish | (mx_ < 0.33)
    eps = 0.012
    lo = head_c_t - np.array([head_d_t, head_w_t, head_h_t]) / 2 - eps
    hi = head_c_t + np.array([head_d_t, head_w_t, head_h_t]) / 2 + eps
    inside = np.all((F > lo) & (F < hi), axis=1)
    brow_z = neck_t + 0.42 * head_w_t           # face features sit under this on the front
    front_low = (F[:, 0] > head_front_t - 0.012) & (F[:, 2] < brow_z) & (np.abs(F[:, 1]) < head_w_t / 2 - 0.01)
    zs = np.sort(V[:, 2])[::-1]
    top = zs[zs > zs[0] - 0.09]
    gi = int(np.argmax(top[:-1] - top[1:]))
    halo_cut = float((top[gi] + top[gi + 1]) / 2)
    fhalo = F[:, 2] > halo_cut
    near = np.all((F > lo - 0.02) & (F < hi + 0.02), axis=1)
    dark_bits = near & (mx_ < 0.33) & (F[:, 2] < brow_z + 0.03) & (F[:, 0] > head_c_t[0])   # black hair-shadow specks at the cheeks
    hat = (F[:, 2] > neck_t - 0.012) & ~fhalo & ~(inside & feature) & ~front_low & ~dark_bits
    print("[block] halo cut z %.4f" % halo_cut)
    HH = dup(T, "HatHair")
    keep_faces(HH, hat)
    print("[block] spikes removed %d" % erode_spikes(HH, lo, hi))
    xform(HH, M_head)
    # --- bow (back of the waist)
    (x0, x1), (y0, y1), (z0, z1) = P["bow_box"]
    bow = (F[:, 0] > x0) & (F[:, 0] < x1) & (F[:, 1] > y0) & (F[:, 1] < y1) & (F[:, 2] > z0) & (F[:, 2] < z1)
    bow &= ~(fc[:, 2] > fc[:, 0] + 0.15)        # the bow only (white), not the Tripo skirt behind it
    BW = dup(T, "Bow")
    keep_faces(BW, bow)
    xform(BW, M_body)
    print("[block] hat faces %d bow faces %d" % (int(hat.sum()), int(bow.sum())))
    # --- halo: exact ring at the Tripo halo place (head transform)
    hc = Vector(((hv.min(0) + hv.max(0)) / 2).tolist())
    hR = float(((hv[:, 0].max() - hv[:, 0].min()) + (hv[:, 1].max() - hv[:, 1].min())) / 4)
    hct = M_head @ hc
    halo_ob = torus("Halo", hct, hR * kh - P["halo_tube"] * 0.6, P["halo_tube"], "halo")
    bpy.data.objects.remove(T)

    parts = {}
    # --- head
    shr = 0.985
    parts["Head"] = [rbox("head", (hw * shr, hd * shr, hh), head_c, 0.16, "skin", segs=4)]
    # --- upper torso + dressing
    tw, td = P["torso"]
    wz = P["waist"]
    cz0, cz1 = P["collar"][2], P["collar"][3]
    top = cz0 + 0.02
    ut = [rbox("torso", (tw, td, top - wz), (0, 0, (top + wz) / 2), P["torso_bevel"], "dress")]
    ut.append(rbox("collar", (P["collar"][0], P["collar"][1], cz1 - cz0), (0, 0, (cz0 + cz1) / 2), 0.06, "collar"))
    bw, bz0, bz1 = P["bib"]
    ut.append(rbox("bib", (bw, 0.06, bz1 - bz0), (0, td / 2 + 0.02, (bz0 + bz1) / 2), 0.025, "apron"))
    for i, z in enumerate(P["buttons"]):
        ut.append(sphere("btn%d" % i, (0, td / 2 + 0.06, z), P["button_r"], "button", (1, 0.55, 1)))
    sx, sw = P["straps"]
    for s in (-1, 1):
        ut.append(rbox("strapF", (sw, 0.05, top - bz1 + 0.06), (s * sx, td / 2 + 0.015, (bz1 + top) / 2), 0.02, "apron"))
        ut.append(rbox("strapT", (sw, td + 0.06, 0.05), (s * sx, 0, top + 0.005), 0.02, "apron"))
        ut.append(rbox("strapB", (sw, 0.05, top - P["belt"][1] + 0.04), (s * sx, -td / 2 - 0.015, (P["belt"][1] + top) / 2), 0.02, "apron"))
    parts["UpperTorso"] = ut
    # --- lower torso = skirt + belt + apron skirt
    sk = P["skirt"]
    lt = [loft("skirt", [(z, w, d, r) for z, w, d, r in sk], "dress")]
    b0, b1 = P["belt"]
    def skirt_at(z):
        (za, wa, da, ra), (zb, wb, db, rb) = sk
        t = (za - z) / (za - zb)
        return wa + (wb - wa) * t, da + (db - da) * t, ra + (rb - ra) * t
    bwid, bdep, br = skirt_at((b0 + b1) / 2)
    lt.append(loft("belt", [(b1, max(bwid, tw) + 0.06, max(bdep, td) + 0.06, br + 0.03), (b0, max(bwid, tw) + 0.08, max(bdep, td) + 0.08, br + 0.03)], "apron"))
    az0, az1, aw0, aw1 = P["apron_skirt"]
    poly = []
    rr = 0.16
    outline = [(-aw0 / 2, az0), (aw0 / 2, az0)]   # top edge, then the rounded bottom corners
    for i in range(6):
        a = math.radians(90 * i / 5)
        outline.append((aw1 / 2 - rr + rr * math.cos(a), az1 + rr - rr * math.sin(a)))
    for i in range(6):
        a = math.radians(90 + 90 * i / 5)
        outline.append((-aw1 / 2 + rr + rr * math.cos(a), az1 + rr - rr * math.sin(a)))
    (za, wa, da, ra), (zb, wb, db, rb) = sk
    for x, z in outline:
        t = (za - z) / (za - zb)
        yf = (da + (db - da) * t) / 2
        poly.append((Vector((x, yf + 0.045, z)), Vector((x, yf - 0.02, z))))
    lt.append(slab("apronSkirt", poly, "apron"))
    parts["LowerTorso"] = lt
    # --- arms (built straight down from the shoulder joint, then splayed)
    shx, shz = P["shoulder"]
    a = P["arm"]
    ua_up, ua_dn = P["upper_arm"]
    la = P["lower_arm"]
    cuff = P["cuff_h"]
    R_, rt, od = P["hand"]
    joints = {}
    for side, s in (("Right", 1), ("Left", -1)):
        J = Vector((s * shx, 0, shz))
        rot = Matrix.Rotation(math.radians(-s * P["splay"]), 4, "Y")
        Mw = Matrix.Translation(J) @ rot
        ua = rbox("ua", (a, a, ua_up + ua_dn), (0, 0, (ua_up - ua_dn) / 2), 0.10, "dress")
        e = -ua_dn
        lw = loft("la", [(e + 0.06, a, a, 0.10), (e - la + cuff, a + 0.06, a + 0.06, 0.12)], "dress")
        cf = loft("cuff", [(e - la + cuff + 0.01, a + 0.14, a + 0.14, 0.14), (e - la, a + 0.16, a + 0.16, 0.15)], "cuff")
        w = e - la + 0.04
        stub = loft("wrist", [(w + 0.06, 0.24, 0.24, 0.11), (w - 0.10, 0.24, 0.24, 0.11)], "skin")
        hd_ = c_hand("hand", R_, rt, od, "skin")
        # C axis outward-forward for each side, opening straight down in the world (undo the splay)
        Mh = Matrix.Translation(Vector((0, 0, w - 0.06))) @ Matrix.Rotation(math.radians(s * P["splay"]), 4, "Y") @ (
            Matrix.Rotation(math.radians(0 if s > 0 else 90), 4, "Z"))
        xform(hd_, Mh)
        for o in (ua, lw, cf, stub, hd_):
            xform(o, Mw)
        parts[side + "UpperArm"] = [ua]
        parts[side + "LowerArm"] = [lw, cf]
        parts[side + "Hand"] = [stub, hd_]
        joints[side + "Shoulder"] = (side + "UpperArm", "UpperTorso", Mw)
        joints[side + "Elbow"] = (side + "LowerArm", side + "UpperArm", Mw @ Matrix.Translation(Vector((0, 0, e))))
        joints[side + "Wrist"] = (side + "Hand", side + "LowerArm", Mw @ Matrix.Translation(Vector((0, 0, w))))
    # --- legs
    hx, hz = P["hip"]
    kz, az = P["knee"], P["ankle"]
    L = P["leg"]
    swd, sln, sht, ssol, sout, sfwd = P["shoe"]
    for side, s in (("Right", 1), ("Left", -1)):
        x = s * hx
        parts[side + "UpperLeg"] = [rbox("ul", (L + 0.04, L + 0.04, hz - kz + 0.10), (x, 0, (hz + kz) / 2 + 0.02), 0.08, "tights")]
        parts[side + "LowerLeg"] = [rbox("ll", (L, L, kz - az + 0.06), (x, 0, (kz + az) / 2), 0.08, "tights")]
        fx = x + s * sout
        parts[side + "Foot"] = [rbox("shoe", (swd, sln, sht), (fx, sfwd, ssol + sht / 2), 0.14, "shoe", segs=4),
                                rbox("sole", (swd - 0.02, sln - 0.02, ssol + 0.02), (fx, sfwd, (ssol + 0.02) / 2), 0.03, "sole")]
        joints[side + "Hip"] = (side + "UpperLeg", "LowerTorso", Matrix.Translation(Vector((x, 0, hz))))
        joints[side + "Knee"] = (side + "LowerLeg", side + "UpperLeg", Matrix.Translation(Vector((x, 0, kz))))
        joints[side + "Ankle"] = (side + "Foot", side + "LowerLeg", Matrix.Translation(Vector((x, 0, az))))
    joints["Waist"] = ("UpperTorso", "LowerTorso", Matrix.Translation(Vector((0, 0, wz))))
    joints["Neck"] = ("Head", "UpperTorso", Matrix.Translation(Vector((0, 0, neck - 0.03))))
    joints["Root"] = ("LowerTorso", "HumanoidRootPart", Matrix.Translation(Vector((0, 0, wz - 0.25))))
    return parts, joints, [HH, BW, halo_ob]


def to_roblox(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def mat_to_roblox(M):
    """Blender world matrix -> Roblox CFrame components (x y z R00..R22), axes mapped (x, z, -y)."""
    A = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
    R = A @ M.to_3x3() @ A.inverted()
    p = to_roblox(M.translation)
    return p + [round(R[i][j], 6) for i in range(3) for j in range(3)]


def render(prefix, px, obs, views):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.film_transparent = False
    if not sc.world:
        w = bpy.data.worlds.new("w")
        sc.world = w
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.43, 0.45, 1)
        key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
        key.data.energy = 3.0
        sc.collection.objects.link(key)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
    cam, key = sc.camera, bpy.data.objects["key"]
    for name, az, el, ctr, size, res in views:
        sc.render.resolution_x = res[0]
        sc.render.resolution_y = res[1]
        cam.data.ortho_scale = size
        d = Vector((math.sin(math.radians(az)), math.cos(math.radians(az)), 0)) * math.cos(math.radians(el)) + Vector((0, 0, math.sin(math.radians(el))))
        cam.location = Vector(ctr) + d * 30
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        side = Vector((d.x, d.y, 0)).normalized().cross(Vector((0, 0, 1)))
        key.rotation_euler = (-(d * 0.75 + side * 0.45 + Vector((0, 0, 0.7))).normalized()).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = "%s_%s.png" % (prefix, name)
        bpy.ops.render.render(write_still=True)


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    npc = a[0]
    P = NPC[npc]
    px = int(a[a.index("--px") + 1]) if "--px" in a else 900
    out = os.path.join(ROOT, "art", "models", "npc_block", npc)
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts, joints, acc = build(P)
    img, U, Vv = palette_image(os.path.join(out, npc + "_palette.png"))
    mat = bpy.data.materials.new(npc + "_palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.55
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    built = {}
    for name, obs in parts.items():
        for o in obs:
            set_pal_uv(o, U, Vv)
        ob = join(name, obs)
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        built[name] = ob
    halo = acc[2]
    set_pal_uv(halo, U, Vv)
    halo.data.materials.append(mat)
    # origins at each part's box centre (= the Roblox MeshPart CFrame after import)
    info = {"npc": npc, "parts": {}, "joints": {}, "accessories": {}}
    for ob in list(built.values()) + acc:
        W = np.array([v.co[:] for v in ob.data.vertices])
        c = Vector(((W.min(0) + W.max(0)) / 2).tolist())
        ob.data.transform(Matrix.Translation(-c))
        ob.location = c
        rec = {"centre": to_roblox(c), "size": [round(float(x), 4) for x in np.ptp(W, 0)[[0, 2, 1]]], "tris": sum(len(p.vertices) - 2 for p in ob.data.polygons)}
        (info["parts"] if ob.name in built else info["accessories"])[ob.name] = rec
    info["accessories"]["HatHair"]["weld_to"] = "Head"
    info["accessories"]["Halo"]["weld_to"] = "Head"
    info["accessories"]["Bow"]["weld_to"] = "LowerTorso"
    for jn, (p1, p0, M) in joints.items():
        info["joints"][jn] = {"part0": p0, "part1": p1, "cframe": mat_to_roblox(M)}
    bpy.context.view_layer.update()
    lo = min(min((o.matrix_world @ v.co).z for v in o.data.vertices) for o in built.values())
    info["ground_z"] = round(lo, 4)
    info["note"] = "Roblox space: x = Blender x, y = Blender z, z = -Blender y (the NPC faces -Z). Joint cframes are world; C0 = part0^-1 * J, C1 = part1^-1 * J."
    json.dump(info, open(os.path.join(out, npc + "_rig.json"), "w"), indent=1)
    bpy.ops.object.select_all(action="DESELECT")
    for o in list(built.values()) + acc:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, npc + "_block.glb"), use_selection=True, export_format="GLB",
                              export_yup=True, export_apply=True)
    print("[block] parts", len(built), "tris", sum(r["tris"] for r in info["parts"].values()))
    if "--render" in a:
        H = 6.6
        ctr = (0, 0, H / 2)
        views = [("front", 0, 4, ctr, H * 1.08, (px, px)), ("right", 90, 4, ctr, H * 1.08, (px, px)),
                 ("back", 180, 4, ctr, H * 1.08, (px, px)), ("left", -90, 4, ctr, H * 1.08, (px, px)),
                 ("q34", 35, 12, ctr, H * 1.08, (px, px))]
        hand = built["RightHand"]
        hc = hand.location
        views.append(("crop_hand", 35, 8, tuple(hc), 1.2, (600, 600)))
        hh = [o for o in acc if o.name == "HatHair"][0]
        views.append(("crop_hat", 20, 8, (0, 0, hh.location.z + 0.1), 3.0, (700, 700)))
        render(os.path.join(out, "prev_" + npc), px, None, views)
    print("[block] done", out)


main()
