"""Blender touch-up of the Tripo 4-view weapons (SPEC A23-125 step 2; 이미지 생성 4, 10/12).

Sizes and grip points follow 게임성 개발 1's grip numbers (docs/design/grip_reference_2026-10-11.md §5-3 and
src/ServerScriptService/CharacterVisuals.luau LEN / tierLen with Config.Weapons Length T1 3, T2 3.5, T3 4):
  sword (Paladin)        total 3.85 / 3.95 / 4.05 studs, hand 14.5 % from the pommel end
  dark sword (Berserker) total 4.15 / 4.25 / 4.35 (final look 4.8), hand 19.5 %
  staff (Light / Dark Mage) total with the orb 4.42 / 4.54 / 4.66, hand 66 % from the foot
  bow (Ranger) 3.1 / 3.36 / 3.61, short bow (Shadow Hunter) x 0.75 = 2.33 / 2.52 / 2.71, hand in the middle
  hammer (Blacksmith) 2.2, hand 26 % from the bottom; baton (Pet Tamer) 2.13 / 2.2 / 2.34, hand 30 %
  alchemist: the approved 2D is a staff with a flask (the game code holds a flask today) - staff size, hand 62 % (개발 1 to add a shape)
Thin blades read as a line in Roblox: the depth (y) is scaled up until the blade / shaft is at least --min-thick studs
(code weapons use 0.25 blades, 0.22 .. 0.3 handles).

Steps: import art/models/tripo/web/<job>_MV4_HD_src.glb -> Tripo front +X turned to +y -> upright, scaled to the length ->
the grip point to the origin (the pivot the game attaches to the hand) -> dust islands dropped -> weld + decimate to --tris
-> smart UV -> bake colour / normal / roughness / metalness (tools/proj_bake.py) -> GLB + PNG + JSON (+ --preview).

  blender --background --factory-startup --python tools/tripo_weapon_touchup.py -- <job> [--tris 3500] [--px 1024]
          [--min-thick 0.2] [--preview]
"""
import argparse
import json
import math
import os
import re
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import proj_bake as PB  # noqa: E402

KIND = {  # class -> (kind, lengths T1..T3, hand share from the bottom)
    "Paladin": ("sword", (3.85, 3.95, 4.05), 0.145),
    "Berserker": ("darksword", (4.15, 4.25, 4.35), 0.195),
    "LightMage": ("staff", (4.42, 4.54, 4.66), 0.66),
    "DarkMage": ("staff", (4.42, 4.54, 4.66), 0.66),
    "Ranger": ("bow", (3.1, 3.36, 3.61), 0.5),
    "ShadowHunter": ("bow", (2.33, 2.52, 2.71), 0.5),
    "Blacksmith": ("hammer", (2.2, 2.2, 2.2), 0.26),
    "PetTamer": ("baton", (2.13, 2.2, 2.34), 0.3),
    "Alchemist": ("staff", (4.42, 4.54, 4.66), 0.62),   # the approved 2D is a staff with a flask; the game holds a flask today
}

# the hand = the middle of the wrapped grip in the approved 2D front (share of the height from the bottom, measured on
# art/out/s2/weapons_t13_4v/<job>_front.png with a 5 % ruler; 디자인 검수 10/12: the wrap says "hold here" - never a
# bare shaft). It replaces the code shares above; the arm pose stays, the weapon only slides along the hand.
WRAP = {
    "Weapon_Halo_LightMage_T1": 0.445, "Weapon_Halo_LightMage_T2": 0.505, "Weapon_Halo_LightMage_T3": 0.345,
    "Weapon_Halo_Paladin_T1": 0.155, "Weapon_Halo_Paladin_T2": 0.16, "Weapon_Halo_Paladin_T3": 0.18,
    "Weapon_Halo_Ranger_T1": 0.505, "Weapon_Halo_Ranger_T2": 0.52, "Weapon_Halo_Ranger_T3": 0.50,
    "Weapon_Horns_Berserker_T1": 0.165, "Weapon_Horns_Berserker_T2": 0.185, "Weapon_Horns_Berserker_T3": 0.185,
    "Weapon_Horns_Berserker_final_b": 0.175,
    "Weapon_Horns_DarkMage_T1": 0.395, "Weapon_Horns_DarkMage_T2": 0.55, "Weapon_Horns_DarkMage_T3": 0.375,
    "Weapon_Horns_ShadowHunter_T1": 0.47, "Weapon_Horns_ShadowHunter_T2": 0.50, "Weapon_Horns_ShadowHunter_T3": 0.50,
    "Weapon_Neutral_Alchemist_T1": 0.37, "Weapon_Neutral_Alchemist_T2": 0.345, "Weapon_Neutral_Alchemist_T3": 0.26,
    "Weapon_Neutral_Blacksmith_T1": 0.26, "Weapon_Neutral_Blacksmith_T2": 0.215, "Weapon_Neutral_Blacksmith_T3": 0.235,
    "Weapon_Neutral_PetTamer_T1": 0.26, "Weapon_Neutral_PetTamer_T2": 0.28, "Weapon_Neutral_PetTamer_T3": 0.245,
}

# 개발 1 (fix/staff-hip, 10/12): on these staffs the wrapped grip moves UP so the hand holds it in the hip pose; the wrap
# band (wrap + its rings, share of the height measured on the Tripo width profile) is cut out, moved along the staff so
# its middle sits at <target> studs from the foot, the hole is filled by stretching the bare shaft just below it (knots
# and branches stay where they are). (lo, hi, target studs)
MOVE = {
    "Weapon_Halo_LightMage_T1": (0.365, 0.515, 2.63), "Weapon_Halo_LightMage_T3": (0.235, 0.455, 2.63),
    "Weapon_Horns_DarkMage_T1": (0.295, 0.515, 2.53), "Weapon_Horns_DarkMage_T3": (0.265, 0.495, 2.53),
    "Weapon_Neutral_Alchemist_T1": (0.245, 0.495, 2.59), "Weapon_Neutral_Alchemist_T2": (0.235, 0.455, 2.59),
    "Weapon_Neutral_Alchemist_T3": (0.135, 0.385, 2.59),
}


def move_wrap(me, z0, L, lo_s, hi_s, target, rmax=0.3, foot=0.12):
    """cut the band [lo, hi] (faces near the staff axis) and move it up by d; the hole [lo, lo + h] (h = min(hi - lo, d))
    is filled with COPIES of the bare shaft just below it (knots and twists repeat like the 2D branch; 디자인 검수 10/12:
    a stretched slice read as a smooth striped tube), stacked when the shaft below is shorter than the hole; every seam
    is closed by snapping the upper piece's edge onto the lower one; the top seam sits under the moved band's ring.
    returns (lo, hi, d) in studs"""
    lo, hi = z0 + lo_s * L - 0.03, z0 + hi_s * L + 0.03          # a little past the rings: no ring sliver left behind
    d = z0 + target - (lo + hi) / 2
    h = min(hi - lo, d)
    V = np.array([v.co[:] for v in me.vertices])
    mid = V[(V[:, 2] > lo) & (V[:, 2] < hi)]
    cx, cy = float(np.median(mid[:, 0])), float(np.median(mid[:, 1]))
    R = np.hypot(V[:, 0] - cx, V[:, 1] - cy)
    ang = ((np.arctan2(V[:, 1] - cy, V[:, 0] - cx) + math.pi) / (2 * math.pi) * 24).astype(int) % 24

    def prof(z):
        m = (np.abs(V[:, 2] - z) < 0.02) & (R < rmax)
        out = np.zeros(24)
        np.maximum.at(out, ang[m], R[m])
        return out
    target = prof(lo - 0.005)
    bottom = z0 + foot * L
    ref_r = float(np.median(target[target > 0])) if (target > 0).any() else 0.1

    def lumpy(a_, w_):
        """a ring / flange inside the window (a mean radius > 1.15 x the shaft at the hole) = never copy it"""
        rs = [prof(z) for z in np.arange(a_ + 0.01, a_ + w_, 0.02)]
        return any(np.median(r[r > 0]) > 1.15 * ref_r for r in rs if (r > 0).any())
    # the source piece [a, a + w] (n copies stacked, n*w = h) is picked where its cross-sections best match the hole's
    # lower edge and each other, so seams barely show and no knot is cut in half (DarkMage T1 10/12)
    best = None
    for n_ in (1, 2, 3, 4, 5, 6):                               # more copies = a visibly repeating pattern: only
        w_ = h / n_                                             # when the shaft below is too short (straight staffs)
        if w_ < 0.15 or (n_ > 2 and best is not None):
            break
        for a_ in np.arange(bottom, lo - w_ + 1e-6, 0.01):
            pa, pb = prof(a_ + 0.005), prof(a_ + w_ - 0.005)
            cost = np.abs(pa - target).mean() + 0.02 * (n_ - 1)        # copies alternate upside down: their seams match
            if best is None or cost < best[0]:
                best = (cost, float(a_), w_, n_)
    if best is None:
        # the shaft below is too short (Alchemist T3: gold foot right under the wrap): copy plain shaft from above the
        # moved band instead
        for n_ in (1, 2, 3, 4, 5, 6):
            w_ = h / n_
            for a_ in np.arange(hi + d + 0.02, z0 + 0.8 * L - w_ + 1e-6, 0.01):
                if lumpy(a_, w_):
                    continue
                pa = prof(a_ + 0.005)
                cost = np.abs(pa - target).mean() + 0.02 * (n_ - 1)
                if best is None or cost < best[0]:
                    best = (cost, float(a_), w_, n_)
            if best is not None:
                break
    _, a, w, n = best
    src_hi = a + w
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    for zc in (a, src_hi, lo, hi, lo + d, hi + d):
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, zc), plane_no=(0, 0, 1))
    P = np.array([v.co[:] for v in bm.verts if lo <= v.co.z <= hi])
    ax, ay = float(np.median(P[:, 0])), float(np.median(P[:, 1]))

    def near(f, lo_, hi_):
        c = f.calc_center_median()
        return lo_ - 1e-5 <= c.z <= hi_ + 1e-5 and math.hypot(c.x - ax, c.y - ay) < rmax
    band = [f for f in bm.faces if near(f, lo, hi)]
    src = [f for f in bm.faces if near(f, a, src_hi)]
    # where the wrap lands, everything of the staff there (shaft, knots, an old metal ring - LightMage T3 10/12) is
    # replaced by the moved band: clean cuts at lo + d / hi + d, no teeth of old shaft showing past the rings
    poke = [f for f in bm.faces if near(f, lo + d, hi + d)]
    dup = bmesh.ops.duplicate(bm, geom=band)
    bmesh.ops.translate(bm, verts=[g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)], vec=(0, 0, d))
    bmesh.ops.delete(bm, geom=band + [f for f in poke if f not in band], context="FACES")

    def edge_verts(faces, z):
        return [v for v in {v for f in faces for v in f.verts} if abs(v.co.z - z) < 1e-4]

    def snap(upper, lower, z, blend=0.12, sign=1):
        """close the seam at z: the upper piece's edge goes onto the lower piece's edge, and its verts within `blend`
        of the seam follow part of the way (a short taper instead of a step; sign -1 = the moving piece is below)"""
        lv = edge_verts(lower, z)
        if not lv:
            return
        L2 = np.array([v.co[:2] for v in lv])
        up = edge_verts(upper, z)
        moves = []
        for v in up:
            k = int(np.argmin(((L2 - np.array(v.co[:2])) ** 2).sum(1)))
            if np.hypot(*(L2[k] - np.array(v.co[:2]))) < 0.2:
                moves.append((np.array(v.co[:2]), L2[k] - np.array(v.co[:2])))
                v.co.x, v.co.y = L2[k]
        if not moves:
            return
        M0 = np.array([m[0] for m in moves])
        for v in {v for f in upper for v in f.verts}:
            t = (v.co.z - z) * sign
            if 1e-4 < t < blend:
                k = int(np.argmin(((M0 - np.array(v.co[:2])) ** 2).sum(1)))
                f = 1.0 - t / blend
                v.co.x += moves[k][1][0] * f
                v.co.y += moves[k][1][1] * f
    below = [f for f in bm.faces if near(f, lo - 0.2, lo)]
    for k in range(1, n + 1):
        cp = bmesh.ops.duplicate(bm, geom=src)
        cf = [g for g in cp["geom"] if isinstance(g, bmesh.types.BMFace)]
        cv = [g for g in cp["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=cv, vec=(0, 0, lo + (k - 1) * w - a))
        if k % 2 == 0:
            # every second copy upside down: neighbouring copies then meet with the same cross-section and the same
            # texture at the seam (no stripes where straight staffs need several copies, Alchemist T3 10/12)
            zm = 2 * lo + (2 * k - 1) * w
            for v in cv:
                v.co.z = zm - v.co.z
            bmesh.ops.reverse_faces(bm, faces=cf)
        if lo + k * w > lo + h + 1e-5:                            # (n * w = h: never cut; kept for safety)
            geom = list({e for f in cf for e in f.edges}) + list({v for f in cf for v in f.verts}) + cf
            res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, lo + h), plane_no=(0, 0, 1), clear_outer=True)
            cf = [f for f in bm.faces if f.is_valid and near(f, lo + (k - 1) * w, lo + h) and f not in below]
        snap(cf, below, lo + (k - 1) * w)
        below = cf
    if h < d - 1e-5:                                              # original shaft above the hole: snap it onto the copy
        above = [f for f in bm.faces if near(f, lo + h, lo + h + 0.2) and f not in below]
        snap(above, below, lo + h)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if any(abs(v.co.z - (lo + q * w)) < 1e-4 for q in range(n + 1))], dist=2e-4)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return lo, hi, d


argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("job")
ap.add_argument("--tris", type=int, default=3500)
ap.add_argument("--px", type=int, default=1024)
ap.add_argument("--min-thick", type=float, default=0.2)
ap.add_argument("--rotz", type=float, default=90.0)
ap.add_argument("--out", default=os.path.join(ROOT, "art", "models", "tripo", "weapons"))
ap.add_argument("--preview", action="store_true")
ap.add_argument("--no-move", action="store_true", help="keep the wrap where Tripo made it (MOVE table off)")
ap.add_argument("--preview-only", action="store_true", help="only re-render the previews of an existing <job>_TU.glb")
ap.add_argument("--sym", action="store_true", help="left / right mirror (the 2D front is symmetric): keep the +x half, mirror it")
a = ap.parse_args(argv)
m = re.match(r"Weapon_\w+?_([A-Za-z]+)_(T(\d)|final_b)$", a.job)
cls = m.group(1)
tier = int(m.group(3)) if m.group(3) else 0
kind, lens, hand = KIND[cls]
length = lens[tier - 1] if tier else 4.8
OUT = os.path.join(os.path.abspath(a.out), a.job)
os.makedirs(OUT, exist_ok=True)
NAME = a.job + "_TU"
stats = {"job": a.job, "kind": kind, "length": length, "hand_share": hand}


def log(*x):
    print("[weapon]", *x, flush=True)


def select_only(obs, active):
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        if o is not None:
            o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def render_preview(W):
    """Front / left / right / back orthographic renders; the key light comes from the camera side (upper left) for
    every view so the front is never in shade, grey sky for soft fill; red ring = the hand pivot."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = 320, 640
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.43, 0.45, 1)
    key = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    key.data.energy = 3.2
    sc.collection.objects.link(key)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.03, location=(0, 0, 0))
    ring = bpy.context.active_object
    rm = bpy.data.materials.new("grip")
    rm.use_nodes = True
    rm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 0.05, 0.05, 1)
    ring.data.materials.append(rm)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    zc = (W[:, 2].min() + W[:, 2].max()) / 2
    cam.data.ortho_scale = (W[:, 2].max() - W[:, 2].min()) * 1.1
    # the weapon's own left = the viewer's right when it faces you = -x (front = +y)
    for view, d in (("front", Vector((0, 1, 0))), ("left", Vector((-1, 0, 0))), ("right", Vector((1, 0, 0))), ("back", Vector((0, -1, 0)))):
        cam.location = Vector((0, 0, zc)) + d * 20
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        side = d.cross(Vector((0, 0, 1)))                    # the viewer's left
        to_light = (d * 0.75 + side * 0.45 + Vector((0, 0, 0.7))).normalized()
        key.rotation_euler = (-to_light).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (NAME, view))
        bpy.ops.render.render(write_still=True)
    log("preview done")


if a.preview_only:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"))
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    W = np.array([(o.matrix_world @ v.co)[:] for o in obs for v in o.data.vertices])
    render_preview(W)
    raise SystemExit(0)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "tripo", "web", a.job + "_MV4_HD_src.glb"))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
select_only(meshes, meshes[0])
if len(meshes) > 1:
    bpy.ops.object.join()
src = bpy.context.view_layer.objects.active
mw = src.matrix_world.copy()
src.parent = None
src.matrix_world = mw
select_only([src], src)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o is not src:
        bpy.data.objects.remove(o)
me = src.data
me.transform(Matrix.Rotation(math.radians(a.rotz), 4, "Z"))
V = np.array([v.co[:] for v in me.vertices])
z0, z1 = V[:, 2].min(), V[:, 2].max()
s = length / (z1 - z0)
me.transform(Matrix.Scale(s, 4))
V = np.array([v.co[:] for v in me.vertices])
z0 = V[:, 2].min()
if a.job in MOVE and not a.no_move:
    lo_s, hi_s, tgt = MOVE[a.job]
    mlo, mhi, md = move_wrap(me, z0, length, lo_s, hi_s, tgt)
    stats["wrap_moved"] = {"from": [round(mlo - z0, 3), round(mhi - z0, 3)], "up": round(md, 3), "centre_now": tgt}
    V = np.array([v.co[:] for v in me.vertices])
    z0 = V[:, 2].min()
zg = z0 + hand * length                                     # the grip height (share of the length)
zguard = None
if kind in ("sword", "darksword"):
    # the guard = the widest slice in the lower 40 %; the hand = the middle of the longest run of handle-wide slices
    # below it (handle width = the median below the guard; the pommel ball and the guard fall outside 0.55 .. 1.3 of it)
    zs = np.linspace(z0, z0 + length, 81)
    wid = np.zeros(80)
    for k in range(80):
        sl = V[(V[:, 2] >= zs[k]) & (V[:, 2] < zs[k + 1])]
        wid[k] = np.ptp(sl[:, 0]) if len(sl) > 3 else 0
    g = int(np.argmax(wid[:32]))
    hw = wid[:g]
    if g > 3 and (hw > 0).any():
        ref = float(np.median(hw[hw > 0]))
        best, run = (0, 0), None
        for k in range(g):
            if 0.55 * ref <= wid[k] <= 1.3 * ref:
                run = (run[0], k) if run else (k, k)
                if run[1] - run[0] >= best[1] - best[0]:
                    best = run
            else:
                run = None
        zg = (zs[best[0]] + zs[best[1] + 1]) / 2
        # guard top = first slice above the guard that is back under half the guard width
        gt = g
        while gt < 79 and wid[gt] > 0.5 * wid[g]:
            gt += 1
        zguard = float(zs[gt])
        stats["guard_z"] = round(float(zs[g] - z0), 3)
if a.job in WRAP:
    stats["grip_code_share"] = round(float((zg - z0) / length), 3)
    zg = z0 + WRAP[a.job] * length
    stats["grip_source"] = "2D wrap centre"
if "wrap_moved" in stats:
    zg = z0 + stats["wrap_moved"]["centre_now"]
    stats["grip_source"] = "moved wrap centre (개발 1 hip pose)"
band = V[np.abs(V[:, 2] - zg) < 0.08 * length]
stats["grip_from_bottom"] = round(float((zg - z0) / length), 3)
cx, cy = (band[:, 0].min() + band[:, 0].max()) / 2, (band[:, 1].min() + band[:, 1].max()) / 2
me.transform(Matrix.Translation((-cx, -cy, -zg)))
me.update()
stats["scale"] = round(s, 4)
stats["src_tris"] = tris(src)

# blade thickness: the median depth (y) of the blade slices above the guard; a thin blade is thickened in y there only
# (guard / handle / pommel keep their shape; 0.15-stud blend above the guard)
if zguard is not None:
    zb = zguard - zg
    V = np.array([v.co[:] for v in me.vertices])
    zs = np.linspace(zb + 0.05, V[:, 2].max() - 0.1, 31)
    depths = []
    for k in range(30):
        sl = V[(V[:, 2] >= zs[k]) & (V[:, 2] < zs[k + 1])]
        if len(sl) > 8:
            depths.append(np.ptp(sl[:, 1]))
    thin = float(np.median(depths)) if depths else a.min_thick
    stats["blade_depth"] = round(thin, 3)
    if thin < a.min_thick:
        k = min(a.min_thick / max(thin, 1e-3), 2.5)
        for v in me.vertices:
            w = min(max((v.co.z - zb) / 0.15, 0.0), 1.0)
            v.co.y *= 1.0 + (k - 1.0) * w
        me.update()
        stats["thickened_y"] = round(k, 3)

work = src.copy()
work.data = src.data.copy()
work.name = NAME
bpy.context.scene.collection.objects.link(work)
bm = bmesh.new()
bm.from_mesh(work.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)     # weld before the island search (glTF splits at UV seams)
bm.faces.index_update()
seen, islands = set(), []
for f in bm.faces:
    if f.index in seen:
        continue
    stack, isl = [f], []
    seen.add(f.index)
    while stack:
        g = stack.pop()
        isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    islands.append(isl)
dust = [g for isl in islands if len(isl) < 4 for g in isl]
bmesh.ops.delete(bm, geom=dust, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bm.to_mesh(work.data)
bm.free()
stats["dust_faces"] = len(dust)
if a.sym:
    W0 = np.array([v.co[:] for v in work.data.vertices])
    xc = float((W0[:, 0].min() + W0[:, 0].max()) / 2)
    work.data.transform(Matrix.Translation((-xc, 0, 0)))
    bm = bmesh.new()
    bm.from_mesh(work.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(1, 0, 0), clear_inner=True)
    bm.to_mesh(work.data)
    bm.free()
    mm = work.modifiers.new("sym", "MIRROR")
    mm.use_axis[0] = True
    mm.use_clip = True
    mm.use_mirror_merge = True
    mm.merge_threshold = 0.003
    select_only([work], work)
    bpy.ops.object.modifier_apply(modifier=mm.name)
    work.data.transform(Matrix.Translation((xc, 0, 0)))
    stats["symmetric_x"] = round(xc, 4)
select_only([work], work)
cur = tris(work)
if cur > a.tris:
    dm = work.modifiers.new("dec", "DECIMATE")
    dm.ratio = a.tris / cur
    dm.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=dm.name)
tm = work.modifiers.new("tri", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tm.name)
for p in work.data.polygons:
    p.use_smooth = True
stats["tris"] = tris(work)
while work.data.uv_layers:
    work.data.uv_layers.remove(work.data.uv_layers[0])
work.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
maps = PB.bake(work, PB.Source([src]), size=a.px, ray=None, relief=True)
mat = PB.save_maps(maps, OUT, NAME)
work.data.materials.clear()
work.data.materials.append(mat)
W = np.array([(work.matrix_world @ v.co)[:] for v in work.data.vertices])
stats["size"] = [round(float(x), 3) for x in np.ptp(W, axis=0)]
stats["z_range"] = [round(float(W[:, 2].min()), 3), round(float(W[:, 2].max()), 3)]
stats["pivot"] = "origin = the grip point (hand), the long axis +Z (Roblox +Y), front +y (Roblox -Z)"
select_only([work], work)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
json.dump(stats, open(os.path.join(OUT, NAME + ".json"), "w"), indent=1)
log("done", json.dumps(stats))

if a.preview:
    bpy.data.objects.remove(src)
    render_preview(W)
