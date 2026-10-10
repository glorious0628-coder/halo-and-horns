"""Halo house/shop Tripo HD model -> separate parts with their own 1024 maps (이미지 생성 3, 2026-10-10; A23-106/107).

  blender --background --factory-startup --python-exit-code 1 --python tools/house_parts.py -- <src.glb> <Name> <regions.json> <work_dir>
          [--door-h 8.0] [--grid 2] [--front +X]

Pass A of three (pass B = py tools/house_maps.py, pass C = house_parts.py --assemble):
- the Tripo multi-view model (front = +X for web HD multi-view) is turned so the front is +Y (= Roblox -Z after the glTF
  export), scaled so the door leaf is --door-h studs tall (A23-106: door taller than an avatar), centred, base at z 0;
- faces are split into parts by the front-image regions (tools/house_regions.py: door box, awning boxes, u/v of the
  front silhouette) and the Tripo colour:
    <Name>_Door     door leaf with its hardware (wood faces in the door box facing the front, plus what sits on them)
    <Name>_Awning   faces in an awning box that stand out in front of the wall
    <Name>_WinPane  window panes (light blue glass colour on walls), textured -> can turn into a warm light at night
    <Name>_Glass    a copy of the panes pushed 0.04 studs outward: Studio sets Material Glass, Transparency 0.45,
                    Reflectance 0.25 (no texture)
    <Name>_Body_tRC the rest, cut into grid x grid UV tiles
- every textured part gets its own crops of the Tripo 4K colour / normal / ORM -> <work>/<Name>/<part>_{color,tnormal,orm}.png
  (1024; small parts 512), UVs remapped; <work>/<Name>/<Name>_A.blend + <Name>_parts.json (door box in studs, sizes).
"""
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
opt = {"door-h": 8.0, "grid": 2, "front": "+X", "assemble": False, "fit-h": None, "fit-w": None, "decimate": None, "lamp": None}
pos = []
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--assemble":
        opt["assemble"] = True
        i += 1
        continue
    if a.startswith("--"):
        opt[a[2:]] = argv[i + 1]
        i += 2
        continue
    pos.append(a)
    i += 1

if opt["assemble"]:
    # pass C: reload the blend, point every material at the final maps of pass B, export the GLB
    BLEND, OUT = os.path.abspath(pos[0]), os.path.abspath(pos[1])
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    d = os.path.dirname(os.path.abspath(BLEND))
    for m in bpy.data.materials:
        part = m.get("hh_part")
        if not part:
            continue
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
        if part.endswith("_Glass"):
            bsdf.inputs["Base Color"].default_value = (0.75, 0.88, 1.0, 1)
            bsdf.inputs["Roughness"].default_value = 0.05
            bsdf.inputs["Alpha"].default_value = 0.55
            continue

        def img(suffix, noncolor):
            im = bpy.data.images.load(os.path.join(d, part + suffix), check_existing=False)
            if noncolor:
                im.colorspace_settings.name = "Non-Color"
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = im
            return t

        c = img("_C.png", False)
        nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
        mr = img("_MR.png", True)
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(mr.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nn = img("_N.png", True)
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    for o in bpy.context.scene.objects:
        o.select_set(o.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False,
                              export_image_format="AUTO")
    print("[parts] assembled", OUT, flush=True)
    sys.exit(0)

SRC, NAME, REG, WORK = pos
DOOR_H, GRID = float(opt["door-h"]), int(opt["grid"])
reg = json.load(open(REG, encoding="utf-8")).get(NAME, {}) if os.path.exists(REG) else {}  # props: no regions
OUTD = os.path.join(os.path.abspath(WORK), NAME)
os.makedirs(OUTD, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(SRC))
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = NAME
me = ob.data
turn = {"+X": 90, "-Y": 180, "+Y": 0, "-X": -90}[opt["front"]]
ob.matrix_world = Matrix.Rotation(math.radians(turn), 4, "Z") @ ob.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if opt["decimate"]:
    # props: weld the Tripo seams, then collapse to the target triangle count (UVs follow the collapse)
    import bmesh as _bm
    b_ = _bm.new()
    b_.from_mesh(ob.data)
    _bm.ops.remove_doubles(b_, verts=b_.verts, dist=1e-5)
    b_.to_mesh(ob.data)
    b_.free()
    ob.data.calc_loop_triangles()
    t0 = len(ob.data.loop_triangles)
    tgt = int(opt["decimate"])
    if t0 > tgt:
        md = ob.modifiers.new("dec", "DECIMATE")
        md.ratio = tgt / t0
        bpy.ops.object.modifier_apply(modifier="dec")
    ob.data.calc_loop_triangles()
    print("[parts] decimate %d -> %d tris" % (t0, len(ob.data.loop_triangles)), flush=True)
    me = ob.data

# Tripo maps (4K): colour, ORM, normal
mat0 = me.materials[0]
tex = {}
for n in mat0.node_tree.nodes:
    if n.type == "TEX_IMAGE":
        nm = n.image.name.lower()
        key = "color" if nm.startswith("color") else "orm" if nm.startswith("orm") else "normal" if "normal" in nm else None
        if key:
            tex[key] = n.image


def pixels(img):
    a = np.empty(img.size[0] * img.size[1] * img.channels, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], img.channels)[::-1]  # top row first


W, H = tex["color"].size
# keep the 4K maps as 8-bit RGB (about 50 MB each instead of 268 MB float RGBA; the PC is shared with other sessions)
PX = {}
for k_, v_ in tex.items():
    PX[k_] = (pixels(v_)[..., :3] * 255.0 + 0.5).clip(0, 255).astype(np.uint8)
for v_ in list(tex.values()):
    v_.buffers_free()
import gc
gc.collect()
print("[parts] maps", {k: tuple(v.size) for k, v in tex.items()}, flush=True)


def lin2srgb(c):
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(np.clip(c, 0, None), 1 / 2.4) - 0.055)


# per-face colour (median of centroid + midpoints, sRGB) and geometry
uvl = me.uv_layers.active.data
nf = len(me.polygons)
fh, fs, fv = np.zeros(nf), np.zeros(nf), np.zeros(nf)
cen = np.zeros((nf, 3))
nrm = np.zeros((nf, 3))
area = np.zeros(nf)
col = PX["color"]
for poly in me.polygons:
    us = [uvl[li].uv for li in poly.loop_indices]
    cu = sum(u.x for u in us) / len(us)
    cv = sum(u.y for u in us) / len(us)
    pts = [(cu, cv)] + [((u.x + cu) / 2, (u.y + cv) / 2) for u in us]
    rgb = []
    for (u, v) in pts:
        x = min(W - 1, max(0, int(u * W)))
        y = min(H - 1, max(0, int((1 - v) * H)))
        rgb.append(col[y, x, :3] / 255.0)
    rgb = lin2srgb(np.array(rgb))
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in rgb])
    fh[poly.index] = np.median(hsv[:, 0]) * 360
    fs[poly.index] = np.median(hsv[:, 1])
    fv[poly.index] = np.median(hsv[:, 2])
    cen[poly.index] = poly.center
    nrm[poly.index] = poly.normal
    area[poly.index] = poly.area

lo = cen.min(0)
hi = cen.max(0)
vs = np.array([v.co for v in me.vertices])
lo, hi = vs.min(0), vs.max(0)
# front view: camera on +Y looking -Y -> image right = -X
U = (hi[0] - cen[:, 0]) / (hi[0] - lo[0])
V = (cen[:, 2] - lo[2]) / (hi[2] - lo[2])


def inbox(b, grow=0.0):
    return (U >= b[0] - grow) & (U <= b[2] + grow) & (V >= b[1] - grow) & (V <= b[3] + grow)


wood = (fh >= 10) & (fh <= 42) & (fs >= 0.3) & (fv >= 0.2) & (fv <= 0.85)
glassc = (fh >= 185) & (fh <= 228) & (fs >= 0.12) & (fs <= 0.75) & (fv >= 0.45)
front = nrm[:, 1] > 0.45
leafc = (fh >= 65) & (fh <= 165) & (fs >= 0.25)

part = np.full(nf, "Body", dtype=object)
door = None
if reg.get("door"):
    db = reg["door"]
    cand = inbox(db, 0.02) & front & wood
    if cand.sum() > 20:
        # door leaf = wood faces near the front-most wood depth in the box
        ymax = np.percentile(cen[cand, 1], 90)
        span = hi[1] - lo[1]
        leaf = cand & (cen[:, 1] > ymax - 0.06 * span)
        x0, x1 = cen[leaf, 0].min(), cen[leaf, 0].max()
        z0, z1 = cen[leaf, 2].min(), cen[leaf, 2].max()
        # fill: faces on the leaf plane inside the leaf box (edge faces with mixed colour), plus hardware in front of it
        plane = np.median(cen[leaf, 1])
        mx_ = 0.04 * (x1 - x0)
        inleaf = (cen[:, 0] >= x0 + mx_) & (cen[:, 0] <= x1 - mx_) & (cen[:, 2] >= z0) & (cen[:, 2] <= z1)
        hw = inleaf & (cen[:, 1] > plane - 0.035 * span) & (cen[:, 1] < plane + 0.05 * span) & front
        sel = leaf | hw
        part[sel] = "Door"
        # gold hardware (knobs, hinges, studs) by face colour -> its own part, so the wood leaf gets no metal
        goldf = (fh >= 41) & (fh <= 58) & (fs >= 0.5) & (fv >= 0.78)  # light wood sits at hue 30-40 (house 10)
        part[sel & goldf] = "DoorHw"
        door = {"x0": float(x0), "x1": float(x1), "z0": float(z0), "z1": float(z1), "y": float(ymax)}
for ab in reg.get("awning") or []:
    box = inbox(ab, 0.01) & (part == "Body")
    if box.sum() < 10:
        continue
    # wall plane = the stone faces behind the awning, facing the front
    stone = box & front & (fs < 0.2) & (fv > 0.6)
    wall = np.percentile(cen[stone, 1], 30) if stone.sum() > 10 else np.percentile(cen[box, 1], 20)
    span = hi[1] - lo[1]
    part[box & (cen[:, 1] > wall + 0.035 * span)] = "Awning"
for db in reg.get("display") or []:
    # shop display (bread, juice, potions) sits behind the facade: its own part, no metal (bread reads as gold by colour)
    box = inbox(db, 0.01) & (part == "Body")
    if box.sum() > 10:
        span = hi[1] - lo[1]
        ymax = np.percentile(cen[box, 1], 95)
        part[box & (cen[:, 1] < ymax - 0.03 * span)] = "Display"
if opt["lamp"]:
    # lantern lamp glass / glow core: very bright, pale warm faces -> own part (Studio: Neon + PointLight)
    lampc = (fh >= 30) & (fh <= 70) & (fs >= 0.18) & (fs <= 0.55) & (fv >= 0.92)  # cream marble is s < 0.15
    part[lampc & (part == "Body")] = "Lamp"
pane = glassc & (np.abs(nrm[:, 2]) < 0.35) & (part == "Body")
# drop blue petals: a pane face has few leaf faces around it (radius 2.5 % of the height); flowers sit in leaves
from mathutils import kdtree
Hh = hi[2] - lo[2]
kd_leaf = kdtree.KDTree(int(leafc.sum()) or 1)
for k in np.nonzero(leafc)[0]:
    kd_leaf.insert(Vector(cen[k]), int(k))
kd_leaf.balance()
kd_all = kdtree.KDTree(nf)
for k in range(nf):
    kd_all.insert(Vector(cen[k]), k)
kd_all.balance()
keep = np.zeros(nf, bool)
for k in np.nonzero(pane)[0]:
    c = Vector(cen[k])
    nl = sum(area[j] for (_, j, _) in kd_leaf.find_range(c, 0.025 * Hh)) if leafc.any() else 0.0
    na = sum(area[j] for (_, j, _) in kd_all.find_range(c, 0.025 * Hh))
    keep[k] = nl < 0.12 * max(na, 1e-12)
ngroups = int(keep.sum())
part[keep] = "WinPane"
print("[parts] window pane groups", ngroups, flush=True)
print("[parts] faces", {k: int((part == k).sum()) for k in ("Body", "Door", "DoorHw", "Awning", "WinPane", "Lamp", "Display")}, flush=True)

# scale: door leaf height -> DOOR_H studs (no door: height 22 studs)
if opt["fit-h"]:
    s = float(opt["fit-h"]) / (hi[2] - lo[2])
elif opt["fit-w"]:
    s = float(opt["fit-w"]) / max(hi[0] - lo[0], hi[1] - lo[1])
elif door:
    # door leaf DOOR_H studs tall, and at least 4.5 studs wide (검수 10/10, A23-106 interiors: avatar shoulders + room)
    s = max(DOOR_H / max(door["z1"] - door["z0"], 1e-6), 4.5 / max(door["x1"] - door["x0"], 1e-6))
else:
    s = 22.0 / (hi[2] - lo[2])
cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
T = Matrix.Diagonal((s, s, s, 1.0)) @ Matrix.Translation(Vector((-cx, -cy, -lo[2])))
me.transform(T)
me.update()


def tr(x, y, z):
    p = T @ Vector((x, y, z))
    return p


info = {"name": NAME, "scale": float(s), "size_studs": [float((hi[0] - lo[0]) * s), float((hi[2] - lo[2]) * s), float((hi[1] - lo[1]) * s)],
        "front": "+Y blender = -Z roblox", "door": None}
if door:
    a = tr(door["x0"], door["y"], door["z0"])
    b = tr(door["x1"], door["y"], door["z1"])
    info["door"] = {"center_x": float((a.x + b.x) / 2), "bottom_z": float(a.z), "width": float(abs(b.x - a.x)),
                    "height": float(b.z - a.z), "front_y": float(a.y),
                    "note": "DoorFront: Roblox position (x, 0, -front_y - 1) facing -Z; door leaf = <Name>_Door"}
print("[parts] scale %.3f size %s door %s" % (s, [round(x, 1) for x in info["size_studs"]], info["door"]), flush=True)

# body tiles by UV centroid
cu = np.zeros(nf)
cv = np.zeros(nf)
for poly in me.polygons:
    us = [uvl[li].uv for li in poly.loop_indices]
    cu[poly.index] = sum(u.x for u in us) / len(us)
    cv[poly.index] = sum(u.y for u in us) / len(us)
for k in range(nf):
    if part[k] == "Body":
        ti = min(GRID - 1, max(0, int(cu[k] * GRID)))
        tj = min(GRID - 1, max(0, int(cv[k] * GRID)))
        part[k] = "Body_t%d%d" % (tj, ti)
names = sorted(set(part))


def write(arr, path, srgb):
    hgt, wid = arr.shape[:2]
    im = bpy.data.images.new(os.path.basename(path), wid, hgt, alpha=False, is_data=not srgb)
    if not srgb:
        im.colorspace_settings.name = "Non-Color"
    rgba = np.concatenate([arr, np.ones(arr.shape[:2] + (1,), np.float32)], -1)[::-1]
    im.pixels.foreach_set(rgba.ravel().astype(np.float32))
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def transfer(tris_new, tris_old, size, srcs):
    """Rasterise every triangle in its new (packed) UV and sample the 4K source maps at the matching old UV
    (barycentric, bilinear). Then bleed 4 px into the empty texels so mip levels do not show seams."""
    outs = [np.zeros((size, size, 3), np.float32) for _ in srcs]
    filled = np.zeros((size, size), bool)
    for P, Q in zip(tris_new, tris_old):
        P = P * size  # pixel space, y up
        Q = Q * np.array([W, H])
        x0, y0 = np.floor(P.min(0)).astype(int) - 1
        x1, y1 = np.ceil(P.max(0)).astype(int) + 1
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (P[1, 1] - P[2, 1]) * (P[0, 0] - P[2, 0]) + (P[2, 0] - P[1, 0]) * (P[0, 1] - P[2, 1])
        if abs(d) < 1e-9:
            continue
        l0 = ((P[1, 1] - P[2, 1]) * (xs - P[2, 0]) + (P[2, 0] - P[1, 0]) * (ys - P[2, 1])) / d
        l1 = ((P[2, 1] - P[0, 1]) * (xs - P[2, 0]) + (P[0, 0] - P[2, 0]) * (ys - P[2, 1])) / d
        l2 = 1 - l0 - l1
        ins = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not ins.any():
            continue
        qx = l0 * Q[0, 0] + l1 * Q[1, 0] + l2 * Q[2, 0] - 0.5
        qy = H - (l0 * Q[0, 1] + l1 * Q[1, 1] + l2 * Q[2, 1]) - 0.5  # row index (top row first)
        qx = np.clip(qx, 0, W - 1.001)
        qy = np.clip(qy, 0, H - 1.001)
        ix, iy = qx.astype(int), qy.astype(int)
        fx, fy = (qx - ix)[..., None], (qy - iy)[..., None]
        rows = size - 1 - np.arange(y0, y1 + 1)  # output row (top first)
        for o, src in zip(outs, srcs):
            v = (src[iy, ix].astype(np.float32) * (1 - fx) * (1 - fy) + src[iy, ix + 1] * fx * (1 - fy)
                 + src[iy + 1, ix] * (1 - fx) * fy + src[iy + 1, ix + 1] * fx * fy) / 255.0
            sub = o[rows[:, None], np.arange(x0, x1 + 1)[None, :]]
            sub[ins] = v[ins]
            o[rows[:, None], np.arange(x0, x1 + 1)[None, :]] = sub
        fsub = filled[rows[:, None], np.arange(x0, x1 + 1)[None, :]]
        fsub |= ins
        filled[rows[:, None], np.arange(x0, x1 + 1)[None, :]] = fsub
    for _ in range(4):  # bleed
        if filled.all():
            break
        acc = [np.zeros_like(o) for o in outs]
        cnt = np.zeros((size, size), np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sf = np.roll(np.roll(filled, dy, 0), dx, 1)
            cnt += sf
            for a_, o in zip(acc, outs):
                a_ += np.roll(np.roll(o, dy, 0), dx, 1) * sf[..., None]
        new = (~filled) & (cnt > 0)
        for a_, o in zip(acc, outs):
            o[new] = a_[new] / cnt[new][:, None]
        filled |= new
    return outs, float(filled.mean())


me.materials.clear()
pinfo = {}
for pn in names:
    full = NAME + "_" + pn
    m = bpy.data.materials.new(full)
    m.use_nodes = True
    m["hh_part"] = full
    me.materials.append(m)
    slot = len(me.materials) - 1
    for k in np.nonzero(part == pn)[0]:
        me.polygons[int(k)].material_index = slot

# separate by material
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")
srcs = [PX["color"], PX["normal"], PX["orm"]]
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    full = o.data.materials[0]["hh_part"]
    o.name = o.data.name = full
    pn = full[len(NAME) + 1:]
    me2 = o.data
    me2.calc_loop_triangles()
    uv = me2.uv_layers.active.data
    old = [np.array([uv[li].uv[:] for li in t.loops]) for t in me2.loop_triangles]
    # pack this part's UV islands into the full 0..1 square (rotation allowed: the transfer is per triangle)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    uv = me2.uv_layers.active.data
    new = [np.array([uv[li].uv[:] for li in t.loops]) for t in me2.loop_triangles]
    size = 1024 if (pn.startswith("Body") or len(new) > 1500) else 512
    (c_, n_, r_), cov = transfer(new, old, size, srcs)
    write(c_, os.path.join(OUTD, full + "_color.png"), True)
    write(n_, os.path.join(OUTD, full + "_tnormal.png"), False)
    write(r_, os.path.join(OUTD, full + "_orm.png"), False)
    pinfo[full] = {"faces": len(me2.polygons), "tex": size, "uv_fill": round(cov, 3)}
    print("[parts] baked", full, size, "fill %.2f" % cov, flush=True)

# glass shell over the panes (+0.04 studs along the face normals)
wp = bpy.data.objects.get(NAME + "_WinPane")
if wp:
    g = wp.copy()
    g.data = wp.data.copy()
    g.name = g.data.name = NAME + "_Glass"
    bpy.context.scene.collection.objects.link(g)
    bm = bmesh.new()
    bm.from_mesh(g.data)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * 0.04
    bm.to_mesh(g.data)
    bm.free()
    gm = bpy.data.materials.new(NAME + "_Glass")
    gm.use_nodes = True
    gm["hh_part"] = NAME + "_Glass"
    g.data.materials.clear()
    g.data.materials.append(gm)
    pinfo[NAME + "_Glass"] = {"faces": len(g.data.polygons), "note": "Studio: Material Glass, Transparency 0.45, Reflectance 0.25"}

tris = {}
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris[o.name] = len(o.data.loop_triangles)
info["parts"] = {k: dict(v, tris=tris.get(k)) for k, v in pinfo.items()}
info["tris_total"] = sum(tris.values())
json.dump(info, open(os.path.join(OUTD, NAME + "_parts.json"), "w", encoding="utf-8"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTD, NAME + "_A.blend"))
print("[parts] ok", NAME, tris, flush=True)
