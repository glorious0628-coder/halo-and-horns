"""Clean trim for a retextured tower body (이미지 생성 1, 2026-10-10, 검수 on 492289e: torn window frames, broken vertical strip,
ghost faces, gold bands cut into segments).

  blender --background --factory-startup --python tools/tower_trim.py -- <in_retile.glb> <out.glb> <render_dir> [--strip keep|remove]

Reads the Stone + Trim meshes written by tools/tower_retile.py (Z-up, front -Y) and adds clean modelled pieces over the Tripo trim:
- Gold bands: Trim faces whose Tripo colour is gold are grouped by height; a height band whose gold wraps most of the way round
  becomes one continuous ring (a short cylinder shell just outside the band) -> no broken segments.
- Windows: the other Trim clusters (small, dark or gold) become a clean arch window each: a round-topped gold frame (rounded
  corners) and a dark blue glass panel inside, bent onto the tower surface just outside it.
- The tall narrow gold cluster (the wall joint strip) becomes one straight gold strip (--strip keep) or is covered by stone
  (--strip remove: a stone-textured patch over it, same tiling UV).
- The Trim mesh is then only kept where it is not covered (its faces under rings / windows / strip are deleted), so no torn edges.
Writes <out.glb> (Stone, Gold, Glass, Trim) and <render_dir>/<Name>_trim_{front,back,close}.png.
"""
import colorsys
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT, RDIR = os.path.abspath(argv[0]), os.path.abspath(argv[1]), os.path.abspath(argv[2])
opt = {"strip": "keep", "side": "0"}  # side: +1 = the wall joint strip is on +X (left tower), -1 = on -X (right tower), 0 = none
i = 3
while i < len(argv):
    opt[argv[i][2:]] = argv[i + 1]
    i += 2
NAME = os.path.basename(IN).split("_retile")[0]
os.makedirs(RDIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH":
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
stone = [o for o in bpy.context.scene.objects if o.name.endswith("_Stone")][0]
trim = [o for o in bpy.context.scene.objects if o.name.endswith("_Trim")][0]
for o in (stone, trim):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

pts = [Vector(c) for o in (stone, trim) for c in [o.matrix_world @ Vector(b) for b in o.bound_box]]
z0, z1 = min(p.z for p in pts), max(p.z for p in pts)
cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
H = z1 - z0


def _wall_radius():
    bins = {}
    for v in stone.data.vertices:
        c = stone.matrix_world @ v.co
        bins.setdefault(int((c.z - z0) / H * 60), []).append(math.hypot(c.x - cx, c.y - cy))
    return {k: sorted(v)[len(v) // 2] for k, v in bins.items()}


WALL = _wall_radius()


def wall_r(z):
    k = int((z - z0) / H * 60)
    for d in (0, 1, -1, 2, -2, 3, -3):
        if k + d in WALL:
            return WALL[k + d]
    return 0.0


def ang_of(x, y):
    return math.atan2(x - cx, -(y - cy))  # 0 at the front (-Y)


def rad_of(x, y):
    return math.hypot(x - cx, y - cy)


# ---- classify trim faces by Tripo colour
me = trim.data
src_img = None
for n in me.materials[0].node_tree.nodes:
    if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
        src_img = n.image
W_, H_ = src_img.size
px = list(src_img.pixels)
uvl = me.uv_layers[0]


def sample(u, v):
    x = min(W_ - 1, max(0, int((u % 1.0) * W_)))
    y = min(H_ - 1, max(0, int((v % 1.0) * H_)))
    k = (y * W_ + x) * 4
    return [12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055 for c in px[k:k + 3]]


info = []  # per face: (gold?, angle, z, radius, area, normal z)
for poly in me.polygons:
    uvs = [uvl.data[li].uv for li in poly.loop_indices]
    cu = sum(p[0] for p in uvs) / len(uvs)
    cv = sum(p[1] for p in uvs) / len(uvs)
    hh, ss, vv = colorsys.rgb_to_hsv(*sample(cu, cv))
    c = poly.center
    info.append(dict(gold=(0.06 <= hh <= 0.17 and ss >= 0.35 and vv >= 0.45), a=ang_of(c.x, c.y), z=c.z, r=rad_of(c.x, c.y), area=poly.area, nz=poly.normal.z))

# ---- gold bands: angular coverage per height slice
NB = 120
slice_cov = [set() for _ in range(NB)]
for f in info:
    if f["gold"]:
        k = min(NB - 1, int((f["z"] - z0) / H * NB))
        slice_cov[k].add(int((f["a"] + math.pi) / (2 * math.pi) * 36) % 36)
band_slices = [len(s) >= 24 for s in slice_cov]  # >= 2/3 of the way round
bands = []
k = 0
while k < NB:
    if band_slices[k]:
        k2 = k
        while k2 + 1 < NB and band_slices[k2 + 1]:
            k2 += 1
        bz0, bz1 = z0 + H * k / NB, z0 + H * (k2 + 1) / NB
        rs = [f["r"] for f in info if f["gold"] and bz0 <= f["z"] <= bz1]
        if rs and (bz1 - bz0) > H * 0.006:
            bands.append((bz0, bz1, max(rs)))
        k = k2 + 1
    else:
        k += 1
print("[trim] gold bands:", [(round(a, 3), round(b, 3), round(r, 3)) for a, b, r in bands], flush=True)


def in_band(z, pad=0.0):
    return any(b0 - pad <= z <= b1 + pad for b0, b1, _ in bands)


# ---- clusters of the other trim faces (windows / strip): connectivity on the trim mesh
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
free = [not in_band(info[f.index]["z"], H * 0.004) and abs(info[f.index]["nz"]) < 0.8 for f in bm.faces]
seen = [False] * len(bm.faces)
clusters = []
for f in bm.faces:
    if not free[f.index] or seen[f.index]:
        continue
    stack, comp = [f], []
    seen[f.index] = True
    while stack:
        g = stack.pop()
        comp.append(g.index)
        for e in g.edges:
            for h in e.link_faces:
                if free[h.index] and not seen[h.index]:
                    seen[h.index] = True
                    stack.append(h)
    clusters.append(comp)
bm.free()
R_med = sorted(f["r"] for f in info)[len(info) // 2]
wins, strips = [], []
for comp in clusters:
    area = sum(info[i]["area"] for i in comp)
    if area < (H * 0.012) ** 2:
        continue
    zs = [info[i]["z"] for i in comp]
    angs = [info[i]["a"] for i in comp]
    # unwrap angles round the cluster's mean direction
    sx = sum(math.sin(a) for a in angs)
    sy = sum(math.cos(a) for a in angs)
    am = math.atan2(sx, sy)
    du = [((a - am + math.pi) % (2 * math.pi) - math.pi) for a in angs]
    rr = sorted(info[i]["r"] for i in comp)[len(comp) // 2]
    w = (max(du) - min(du)) * rr
    h = max(zs) - min(zs)
    rec = dict(a=am + (max(du) + min(du)) / 2, w=w, z0=min(zs), z1=max(zs), r=max(info[i]["r"] for i in comp), faces=comp)
    if h > H * 0.35 and w < h * 0.35:
        strips.append(rec)
    elif h > H * 0.03 and w > H * 0.015 and h < H * 0.3:
        wins.append(rec)
# the wall joint strip: gold faces off the bands, piled up in one narrow angle range over a tall height
abins = {}
for i_, f in enumerate(info):
    if f["gold"] and not in_band(f["z"], H * 0.004):
        abins.setdefault(int((f["a"] + math.pi) / (2 * math.pi) * 72) % 72, []).append(i_)
best_ = None
side_ = float(opt["side"])
for k_, lst in abins.items():
    a_c = -math.pi + (k_ + 0.5) * 2 * math.pi / 72
    if side_ == 0 or abs(((a_c - side_ * math.pi / 2) + math.pi) % (2 * math.pi) - math.pi) > math.radians(35):
        continue
    zs_ = [info[i_]["z"] for i_ in lst]
    if max(zs_) - min(zs_) > H * 0.35 and (best_ is None or len(lst) > len(abins[best_])):
        best_ = k_
for k_, lst in ([(best_, abins[best_])] if best_ is not None else []):
    zs_ = [info[i_]["z"] for i_ in lst]
    if True:
        nb = abins.get((k_ + 1) % 72, []) + abins.get((k_ - 1) % 72, [])
        allf = lst + [i_ for i_ in nb if max(zs_) >= info[i_]["z"] >= min(zs_)]
        if any(set(allf) & set(r_["faces"]) for r_ in strips):
            continue
        a_ = -math.pi + (k_ + 0.5) * 2 * math.pi / 72
        strips.append(dict(a=a_, w=wall_r((max(zs_) + min(zs_)) / 2) * 2 * math.pi / 72, z0=min(zs_), z1=max(zs_),
                           r=wall_r((max(zs_) + min(zs_)) / 2), faces=allf))
wins = [w_ for w_ in wins if not any(abs(((w_["a"] - s_["a"]) + math.pi) % (2 * math.pi) - math.pi) * s_["r"] < s_["w"] and s_["z0"] <= w_["z0"] <= s_["z1"] for s_ in strips)]
# two detections of one window (frame + recess as separate clusters) -> keep the bigger one
wins.sort(key=lambda w_: -(w_["w"] * (w_["z1"] - w_["z0"])))
kept_ = []
for w_ in wins:
    if any(abs(((w_["a"] - k_["a"]) + math.pi) % (2 * math.pi) - math.pi) * k_["r"] < (k_["w"] + w_["w"]) / 2 and w_["z0"] < k_["z1"] and k_["z0"] < w_["z1"] for k_ in kept_):
        continue
    kept_.append(w_)
wins = kept_
print("[trim] windows %d, strips %d" % (len(wins), len(strips)), flush=True)

# ---- materials (small flat textures so Roblox gets a colour map too)


def flat_mat(name, rgb, rough, metal, emit=0.0):
    img = bpy.data.images.new(name + "_tex", 16, 16, alpha=False)
    img.pixels.foreach_set([c for _ in range(256) for c in (*rgb, 1.0)])
    img.filepath_raw = os.path.join(RDIR, name + "_tex.png")
    img.file_format = "PNG"
    img.save()
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


GOLD = flat_mat(NAME + "_GoldTrim", (0.86, 0.62, 0.18), 0.3, 0.9)
GLASS = flat_mat(NAME + "_Glass", (0.10, 0.17, 0.32), 0.12, 0.0, 0.0)

gold_bm = bmesh.new()
glass_bm = bmesh.new()


def add_shell(bmx, za, zb, r, a0=-math.pi, a1=math.pi, seg=96, thick=0.0):
    """a cylinder shell piece (outer face; with thick also top/bottom lips) from angle a0 to a1"""
    n = max(4, int(seg * (a1 - a0) / (2 * math.pi)))
    rows = []
    for zz in (za, zb):
        row = []
        for k in range(n + 1):
            a = a0 + (a1 - a0) * k / n
            row.append(bmx.verts.new((cx + r * math.sin(a), cy - r * math.cos(a), zz)))
        rows.append(row)
    for k in range(n):
        bmx.faces.new((rows[0][k], rows[0][k + 1], rows[1][k + 1], rows[1][k]))
    if thick:
        for zz, row, flip in ((za, rows[0], True), (zb, rows[1], False)):
            inner = []
            for k in range(n + 1):
                a = a0 + (a1 - a0) * k / n
                inner.append(bmx.verts.new((cx + (r - thick) * math.sin(a), cy - (r - thick) * math.cos(a), zz)))
            for k in range(n):
                q = (row[k], row[k + 1], inner[k + 1], inner[k])
                bmx.faces.new(q if not flip else q[::-1])


def arch_outline(w, h, n_arc=14):
    """round-topped window outline in (u, z) local coords, bottom corners rounded (radius w*0.12)"""
    r = w / 2
    pts = []
    rc = w * 0.12
    for k in range(5):  # bottom-left corner
        t = math.pi + (math.pi / 2) * k / 4
        pts.append((-r + rc + rc * math.cos(t), rc + rc * math.sin(t)))
    for k in range(5):  # bottom-right corner
        t = 1.5 * math.pi + (math.pi / 2) * k / 4
        pts.append((r - rc + rc * math.cos(t), rc + rc * math.sin(t)))
    for k in range(n_arc + 1):  # the round top
        t = (math.pi) * k / n_arc
        pts.append((r * math.cos(t), h - r + r * math.sin(t)))
    return pts


def bend(u, zz, a_c, r):
    a = a_c + u / r
    return (cx + r * math.sin(a), cy - r * math.cos(a), zz)


def add_window(rec):
    w = max(rec["w"] * 1.08, H * 0.03)
    h = max(rec["z1"] - rec["z0"], w * 1.4) * 1.06
    zb = (rec["z0"] + rec["z1"]) / 2 - h / 2
    r_out = max(rec["r"], wall_r((rec["z0"] + rec["z1"]) / 2)) + H * 0.004
    fr = w * 0.16
    outer = arch_outline(w, h)
    inner = [(u * (w - 2 * fr) / w, fr + (zz) * (h - 2 * fr) / h) for u, zz in outer]
    # glass panel (fan), a hair behind the frame
    vs = [glass_bm.verts.new(bend(u, zb + zz, rec["a"], r_out - H * 0.003)) for u, zz in outer]  # the full outline, behind the frame: no gap at the edge
    glass_bm.faces.new(vs)
    # frame ring (outer -> inner quads) + a lip round the outside
    vo = [gold_bm.verts.new(bend(u, zb + zz, rec["a"], r_out)) for u, zz in outer]
    vi = [gold_bm.verts.new(bend(u, zb + zz, rec["a"], r_out)) for u, zz in inner]
    vb = [gold_bm.verts.new(bend(u, zb + zz, rec["a"], r_out - H * 0.006)) for u, zz in outer]
    n = len(outer)
    for k in range(n):
        k2 = (k + 1) % n
        gold_bm.faces.new((vo[k], vo[k2], vi[k2], vi[k]))
        gold_bm.faces.new((vb[k], vb[k2], vo[k2], vo[k]))
    return zb, zb + h, w


covered = set()
for b0, b1, r in bands:
    wr_ = max(wall_r((b0 + b1) / 2), 1e-4)
    add_shell(gold_bm, b0 - H * 0.002, b1 + H * 0.002, max(wr_ + H * 0.004, min(r, wr_ + H * 0.008)), thick=H * 0.008)  # on the wall, not floating
    for i_, f in enumerate(info):
        if f["gold"] and b0 - H * 0.004 <= f["z"] <= b1 + H * 0.004:
            covered.add(i_)
for rec in wins:
    wb0, wb1, ww = add_window(rec)
    covered.update(rec["faces"])
    for i_, f in enumerate(info):
        du_ = abs(((f["a"] - rec["a"]) + math.pi) % (2 * math.pi) - math.pi) * max(f["r"], 1e-4)
        if du_ <= ww / 2 and wb0 <= f["z"] <= wb1:
            covered.add(i_)
for rec in strips:
    covered.update(rec["faces"])
    half = rec["w"] / 2 + H * 0.004
    da = half / rec["r"]
    if opt["strip"] == "keep":
        add_shell(gold_bm, rec["z0"], rec["z1"], max(rec["r"], wall_r((rec["z0"] + rec["z1"]) / 2)) + H * 0.003, rec["a"] - da, rec["a"] + da, seg=360, thick=H * 0.004)

# leftover gold stubs off the bands / windows / strip (torn sockets): turned into wall stone (pushed onto the wall, marble, tiling UV)
stone_mat = stone.data.materials[0]
me.materials.append(stone_mat)
TILE = None
suv0 = stone.data.uv_layers[0]
for poly in stone.data.polygons:  # recover the tile size from the stone UVs (u = arc / tile)
    if abs(poly.normal.z) < 0.5:
        l0, l1 = poly.loop_indices[0], poly.loop_indices[1]
        dz_ = (stone.data.vertices[stone.data.loops[l1].vertex_index].co.z - stone.data.vertices[stone.data.loops[l0].vertex_index].co.z)
        dv_ = suv0.data[l1].uv[1] - suv0.data[l0].uv[1]
        if abs(dv_) > 1e-4 and abs(dz_) > 1e-4:
            TILE = dz_ / dv_
            break
stubs = [i_ for i_, f in enumerate(info) if f["gold"] and i_ not in covered]
R_all = sorted(WALL.values())[len(WALL) // 2]
for i_ in stubs:
    poly = me.polygons[i_]
    poly.material_index = 1
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index]
        a_ = ang_of(v.co.x, v.co.y)
        wr = wall_r(v.co.z)
        r_ = rad_of(v.co.x, v.co.y)
        if wr and r_ > wr:
            v.co.x = cx + (v.co.x - cx) * wr / r_
            v.co.y = cy + (v.co.y - cy) * wr / r_
        if TILE:
            uvl.data[li].uv = (a_ * R_all / TILE, (v.co.z - z0) / TILE)
print("[trim] gold stubs turned to stone: %d" % len(stubs), flush=True)

# delete covered trim faces
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i_] for i_ in covered], context="FACES")
bm.to_mesh(me)
bm.free()
print("[trim] trim faces removed %d, kept %d" % (len(covered), len(me.polygons)), flush=True)


def to_obj(bmx, name, mat):
    m = bpy.data.meshes.new(name)
    bmx.to_mesh(m)
    bmx.free()
    o = bpy.data.objects.new(name, m)
    bpy.context.scene.collection.objects.link(o)
    uvx = m.uv_layers.new(name="UVMap")
    for l in uvx.data:
        l.uv = (0.5, 0.5)
    m.materials.append(mat)
    for p_ in m.polygons:
        p_.use_smooth = False
    return o


gold_o = to_obj(gold_bm, NAME + "_Gold", GOLD)
glass_o = to_obj(glass_bm, NAME + "_Glass", GLASS)
objs = [stone, gold_o, glass_o] + ([trim] if len(me.polygons) else [])

# check renders
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 900
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
scene.collection.objects.link(cam)
scene.camera = cam
for nm, yaw, cz, scale in (("front", 0, (z0 + z1) / 2, H * 1.1), ("back", 180, (z0 + z1) / 2, H * 1.1),
                           ("close", 20, z0 + H * 0.45, H * 0.35)):
    a = math.radians(yaw)
    cam.data.ortho_scale = scale
    cam.location = (cx + 10 * math.sin(a), cy - 10 * math.cos(a), cz)
    cam.rotation_euler = (math.radians(90), 0, a)
    scene.render.filepath = os.path.join(RDIR, NAME + "_trim_" + nm + ".png")
    bpy.ops.render.render(write_still=True)

bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[trim] ok", OUT, flush=True)
