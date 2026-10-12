"""Pixel (block) cosmetics for the meme halo / horns (SPEC A23-138; 이미지 생성 4, 10/12; 디자인 검수: "픽셀 뿔은 블록 격자 맞춤,
후광은 정확한 원/블록 정렬, 뿔은 좌우 거울 대칭").

Two ways to get the blocks, then one way to build them:
  voxel <job>      the Tripo 4-view model (art/models/tripo/web/<job>_MV4_HD_src.glb, front +X -> +y) is filled on a cube grid
                   (inside = ray parity along 3 axes, 2 of 3), mirrored left / right (x), each block coloured from the Tripo
                   colour at the nearest surface point, the colours snapped to a small palette (flat pixel colours)
  pixelhalo        Meme_PixelHalo: Tripo read the 4 side views as a flat bar, so the ring is built from the approved 2D:
                   a level ring of gold blocks, pale ice-blue blocks stepping up at the left / right ends, three small
                   gold sparkle cubes floating over the middle (colours sampled from the 2D front)
Build: full 2x2x2 groups of one colour become one big block (the 2D mixes big and small blocks), every block a cube with a
small bevel, palette atlas texture (flat normal; gold / yellow = a little metallic), a thin outline shell (0.035, like the
props) as <name>_Outline, GLB + C/N/R/M/MR + 4 previews (front / side / back / top 3/4) + JSON.

  blender --background --factory-startup --python tools/meme_voxel.py -- voxel Meme_PixelHorns --width 1.8 --cells 13
  blender --background --factory-startup --python tools/meme_voxel.py -- pixelhalo Meme_PixelHalo --width 2.4
Out: art/models/tripo/touchup/<job>/<job>_TU.glb ...
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import proj_bake as PB  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("mode", choices=["voxel", "pixelhalo", "chain"])
ap.add_argument("job")
ap.add_argument("--width", type=float, default=1.8, help="overall width (x) in studs")
ap.add_argument("--cells", type=int, default=13, help="voxel: cells across the height (z)")
ap.add_argument("--palette", type=int, default=3, help="voxel: colours (from the 2D front)")
ap.add_argument("--bevel", type=float, default=0.12, help="bevel as a share of the block size")
ap.add_argument("--outline", type=float, default=0.035)
ap.add_argument("--px", type=int, default=256)
a = ap.parse_args(argv)
OUT = os.path.join(ROOT, "art", "models", "tripo", "touchup", a.job)
os.makedirs(OUT, exist_ok=True)
NAME = a.job + "_TU"
stats = {"job": a.job, "mode": a.mode}


def log(*x):
    print("[meme]", *x, flush=True)


def load_png(path):
    """RGB float array, rows top-down (Blender's own loader: no PIL inside Blender)"""
    img = bpy.data.images.load(path)
    w, h = img.size
    arr = np.array(img.pixels[:]).reshape(h, w, 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    return arr


def kmeans(X, k, it=25):
    rng = np.random.default_rng(0)
    C = X[rng.choice(len(X), min(k, len(X)), replace=False)]
    for _ in range(it):
        lab = np.argmin(((X[:, None, :] - C[None]) ** 2).sum(-1), 1)
        C = np.array([X[lab == i].mean(0) if (lab == i).any() else C[i] for i in range(len(C))])
    return C, np.argmin(((X[:, None, :] - C[None]) ** 2).sum(-1), 1)


# ---------------------------------------------------------------- blocks: dict (i, j, k) -> palette index; cell size
if a.mode == "voxel":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "tripo", "web", a.job + "_MV4_HD_src.glb"))
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in obs:
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        o.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))        # Tripo front +X -> +y
    V = np.array([v.co[:] for o in obs for v in o.data.vertices])
    s = a.width / np.ptp(V[:, 0])
    c0 = np.array([(V[:, 0].min() + V[:, 0].max()) / 2, (V[:, 1].min() + V[:, 1].max()) / 2, V[:, 2].min()])
    for o in obs:
        o.data.transform(Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation(Vector((-c0).tolist())))
        o.data.update()
    V = np.array([v.co[:] for o in obs for v in o.data.vertices])
    src = PB.Source(obs)
    verts, tris_ = [], []
    off = 0
    for o in obs:
        verts += [v.co.copy() for v in o.data.vertices]
        tris_ += [[off + i for i in p.vertices] for p in o.data.polygons]
        off += len(o.data.vertices)
    bvh = BVHTree.FromPolygons(verts, tris_)
    H = float(np.ptp(V[:, 2]))
    cell = H / a.cells
    lo = V.min(0)
    n = np.ceil(np.ptp(V, axis=0) / cell).astype(int) + 1
    log("grid", n, "cell %.3f" % cell)

    def inside(p):
        votes = 0
        for d in (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))):
            q, cnt = Vector(p), 0
            for _ in range(40):
                hit = bvh.ray_cast(q, d, 50)
                if hit[0] is None:
                    break
                cnt += 1
                q = hit[0] + d * 1e-4
            votes += cnt % 2
        return votes >= 2
    filled = {}
    for i in range(n[0]):
        for j in range(n[1]):
            for k in range(n[2]):
                p = lo + (np.array([i, j, k]) + 0.5) * cell
                if inside(p):
                    filled[(i, j, k)] = p
    # left / right mirror: x mirrored around the grid centre; a cell is kept when it or its mirror is inside
    xc = (n[0] - 1) / 2.0
    keys = set(filled)
    sym = set()
    for (i, j, k) in keys:
        m = int(round(2 * xc - i))
        sym.add((i, j, k))
        sym.add((m, j, k))
    blocks_p = {key: lo + (np.array(key) + 0.5) * cell for key in sym}
    # colour: nearest Tripo surface colour, from the +x side for mirrored pairs (one colour each pair)
    order = sorted(blocks_p)
    P = np.array([blocks_p[key] if key[0] >= xc else blocks_p[(int(round(2 * xc - key[0])), key[1], key[2])] for key in order])
    # palette from the approved 2D front (object pixels minus the grey background and the dark navy outline); each
    # block = the 2D colour nearest to its Tripo colour (the Tripo texture has the 2D's navy outline baked in: samples
    # that are navy are skipped, the block takes its neighbours' colour)
    im = load_png(os.path.join(ROOT, "art", "out", "s2", "memes_4v", a.job + "_front_HQ.png"))
    bg = np.median(np.concatenate([im[:6].reshape(-1, 3), im[-6:].reshape(-1, 3)]), 0)
    obj = im[np.abs(im - bg).max(-1) > 0.12]
    navy = lambda X: (X[:, 2] > X[:, 0]) & (X.max(-1) < 0.42)
    obj = obj[~navy(obj)]
    pal, _ = kmeans(obj[:: max(1, len(obj) // 20000)], a.palette)
    labs = np.full(len(P), -1)
    cols = np.zeros((len(P), 3))
    for dd in ((0, 0, 0), (0, cell, 0), (0, -cell, 0), (cell, 0, 0), (0, 0, cell), (0, 0, -cell)):
        idx, bary = src.query(P + np.array(dd) * 0.4)
        col, _, _, _ = src.sample(idx, bary)
        ok = (labs < 0) & ~navy(col) & (idx >= 0)
        labs[ok] = np.argmin(((col[ok][:, None, :] - pal[None]) ** 2).sum(-1), 1)
        cols[ok] = col[ok]
    blocks = {key: int(l) for key, l in zip(order, labs)}
    for _ in range(4):                                 # still unknown (all samples navy): most common neighbour colour
        for key, l in list(blocks.items()):
            if l >= 0:
                continue
            nb = [blocks.get((key[0] + d[0], key[1] + d[1], key[2] + d[2]), -1) for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
            nb = [x for x in nb if x >= 0]
            if nb:
                blocks[key] = max(set(nb), key=nb.count)
    blocks = {k_: (v_ if v_ >= 0 else 0) for k_, v_ in blocks.items()}
    stats.update(cells=a.cells, cell=round(cell, 4), voxels=len(blocks), grid=[int(x) for x in n])
elif a.mode == "chain":
    # Meme_PixelHorns from the approved 2D front (art/out/s2/memes_4v/Meme_PixelHorns_front_HQ.png, cropped to the
    # horns and scaled to 900 px wide): one horn = a staircase of cubes shrinking towards the tip, read block by block
    # (centre x, centre y, size in px; y down), the other horn mirrored. The voxel fill joined the two horns at the base
    # and lost the block steps, so the 2D blocks are placed directly (axis-aligned = block grid).
    CH = [(337, 600, 165, 0), (243, 535, 168, 0), (175, 475, 160, 0), (67, 437, 100, 0), (137, 360, 140, 0),
          (180, 268, 122, 0), (222, 195, 108, 0), (247, 132, 95, 2), (292, 70, 82, 2)]
    im = load_png(os.path.join(ROOT, "art", "out", "s2", "memes_4v", a.job + "_front_HQ.png"))
    bg = np.median(np.concatenate([im[:6].reshape(-1, 3), im[-6:].reshape(-1, 3)]), 0)
    obj = im[np.abs(im - bg).max(-1) > 0.12]
    navy = lambda X: (X[:, 2] > X[:, 0]) & (X.max(-1) < 0.42)
    obj = obj[~navy(obj)]
    pal, _ = kmeans(obj[:: max(1, len(obj) // 20000)], 3)
    pal = pal[np.argsort(-pal.sum(1))]                 # bright red, dark red, tip brown
    W2, Y0 = 870.0, 690.0
    k_ = a.width / W2
    cubes_pre = []
    for sx in (-1, 1):
        for (x, y, sz, ci) in CH:
            cx = (x - 450.0) * k_ * (1 if sx < 0 else -1)
            cubes_pre.append((np.array([cx, 0.0, (Y0 - y) * k_]), sz * k_, ci))
    zmin = min(c[2] - sz / 2 for c, sz, _ in cubes_pre)
    cubes_pre = [(c - np.array([0, 0, zmin]), sz, ci) for c, sz, ci in cubes_pre]
    blocks = {}
    cell = min(sz for _, sz, _ in cubes_pre)
    stats.update(blocks_per_horn=len(CH), px_to_stud=round(k_, 5))
else:
    # Meme_PixelHalo from the approved 2D (art/out/s2/memes_4v/Meme_PixelHalo_front_HQ.png): colours sampled there
    im = load_png(os.path.join(ROOT, "art", "out", "s2", "memes_4v", "Meme_PixelHalo_front_HQ.png"))
    hsv_s = im.max(-1) - im.min(-1)
    gold = im[(im[..., 0] > 0.85) & (im[..., 1] > 0.6) & (im[..., 2] < 0.3)]
    ice = im[(im[..., 2] > 0.85) & (im[..., 0] > 0.75) & (hsv_s < 0.25) & (im[..., 0] < im[..., 2])]
    pal = np.array([np.median(gold, 0), np.percentile(gold, 80, axis=0), np.median(ice, 0)])
    R = a.width / 2 * 0.86                         # ring radius to the block centres; ends stick out a little
    cell = a.width / 15.0
    blocks = {}
    # pixel circle (midpoint algorithm, 8-way symmetric = evenly stepped, no long straight runs)
    r = int(round(R / cell))
    pts = set()
    x, y, err = r, 0, 1 - r
    while x >= y:
        for px_, py_ in ((x, y), (y, x), (-y, x), (-x, y), (-x, -y), (-y, -x), (y, -x), (x, -y)):
            pts.add((px_, py_))
        y += 1
        if err < 0:
            err += 2 * y + 1
        else:
            x -= 1
            err += 2 * (y - x) + 1
    nring = len(pts)
    for (px_, py_) in pts:
        ang = math.atan2(py_, px_)
        side = abs(math.cos(ang))
        blocks[(px_, py_, 0)] = 2 if side > 0.95 else (1 if (px_ + py_) % 3 == 0 else 0)
    R = r * cell
    # ice blocks stepping up and out at the left / right ends (2D: two steps)
    for sgn in (-1, 1):
        x0 = int(round(sgn * R / cell))
        for dz, dx in ((1, sgn), (2, 2 * sgn)):
            for dy in (-1, 0, 1) if dz == 1 else (0,):
                blocks[(x0 + dx, dy, dz)] = 2
    # three sparkle cubes over the middle (2D: one higher in the centre)
    sparkles = [((-3.2, 0, 2.6), 0.55), ((0, 0, 3.6), 0.7), ((3.2, 0, 2.6), 0.55)]
    stats.update(ring_radius=round(R, 3), cell=round(cell, 4), ring_blocks=nring)

# ---------------------------------------------------------------- merge 2x2x2 groups of one colour into big blocks
cubes = list(cubes_pre) if a.mode == "chain" else []   # (centre (3,), size, palette index)
if a.mode == "voxel":
    lo = np.array(lo)
used = set()
for key in sorted(blocks):
    if key in used:
        continue
    i, j, k = key
    grp = [(i + di, j + dj, k + dk) for di in (0, 1) for dj in (0, 1) for dk in (0, 1)]
    if all(g in blocks and g not in used and blocks[g] == blocks[key] for g in grp) and i % 2 == 0 and k % 2 == 0:
        used.update(grp)
        c = (np.array(key) + 1.0) * cell + (lo if a.mode == "voxel" else 0)
        cubes.append((c, 2 * cell, blocks[key]))
for key in sorted(blocks):
    if key in used:
        continue
    c = (np.array(key) + (0.5 if a.mode == "voxel" else 0.0)) * cell + (lo if a.mode == "voxel" else 0)
    cubes.append((c, cell, blocks[key]))
if a.mode == "pixelhalo":
    for (x, y, z), f in sparkles:
        cubes.append((np.array([x, y, z]) * cell, f * cell, 1))
# drop cubes buried on all six sides (never seen): occupancy on the small-cell grid
base = lo if a.mode == "voxel" else np.zeros(3)
if a.mode == "chain":
    stats["blocks"] = len(cubes)
    keep_all = True
else:
    keep_all = False
occ = set()
spans = []
for c, sz, _ in cubes:
    m_ = max(1, int(round(sz / cell)))
    c0_ = np.floor((c - base) / cell - m_ / 2 + 0.5).astype(int) if a.mode == "voxel" else np.round(c / cell - (m_ - 1) / 2).astype(int)
    cells = [(c0_[0] + i, c0_[1] + j, c0_[2] + k) for i in range(m_) for j in range(m_) for k in range(m_)]
    spans.append(cells)
    occ.update(cells)
keep = [] if not keep_all else list(cubes)
for (c, sz, pi), cells in ([] if keep_all else zip(cubes, spans)):
    cs = set(cells)
    shell = {(x + d[0], y + d[1], z + d[2]) for (x, y, z) in cells for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))} - cs
    if shell <= occ and sz >= cell * 0.99:
        continue
    keep.append((c, sz, pi))
stats["blocks"] = len(keep)
stats["hidden_dropped"] = len(cubes) - len(keep)
cubes = keep

# ---------------------------------------------------------------- mesh: bevelled cubes, palette atlas UVs
bpy.ops.wm.read_factory_settings(use_empty=True)
P_N = len(pal)
G = int(math.ceil(math.sqrt(P_N)))
bm = bmesh.new()
uvl = bm.loops.layers.uv.new("UVMap")
for c, sz, pi in cubes:
    before = set(bm.faces)
    geom = bmesh.ops.create_cube(bm, size=sz)
    vs = geom["verts"]
    bmesh.ops.translate(bm, verts=vs, vec=Vector(c.tolist()))
    fs = list({f for v in vs for f in v.link_faces})
    res = bmesh.ops.bevel(bm, geom=list({e for f in fs for e in f.edges}) + vs, offset=a.bevel * sz, segments=1,
                          affect="EDGES", profile=0.5)
    allf = set(bm.faces) - before                  # every face of this cube after the bevel (the old 6 are replaced)
    u0, v0 = (pi % G + 0.5) / G, (pi // G + 0.5) / G
    for f in allf:
        if not f.is_valid:
            continue
        for l in f.loops:
            l[uvl].uv = (u0, v0)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me)
bm.free()
work = bpy.data.objects.new(NAME, me)
bpy.context.scene.collection.objects.link(work)
for p in me.polygons:
    p.use_smooth = False
tri = work.modifiers.new("t", "TRIANGULATE")
bpy.context.view_layer.objects.active = work
work.select_set(True)
bpy.ops.object.modifier_apply(modifier=tri.name)
stats["tris"] = sum(len(p.vertices) - 2 for p in me.polygons)
W = np.array([v.co[:] for v in me.vertices])
stats["size"] = [round(float(x), 3) for x in np.ptp(W, axis=0)]

# ---------------------------------------------------------------- maps
S = a.px
C = np.zeros((S, S, 3))
Rm = np.full((S, S), 0.5)
Mm = np.zeros((S, S))
pal_srgb = np.clip(pal, 0, 1)
for pi in range(P_N):
    x0, y0 = (pi % G) * S // G, (pi // G) * S // G
    sl = (slice(S - (y0 + S // G), S - y0), slice(x0, x0 + S // G))          # image rows run top-down
    C[sl] = pal_srgb[pi]
    r, g_, b = pal_srgb[pi]
    goldish = r > 0.7 and g_ > 0.45 and b < 0.35
    Rm[sl] = 0.3 if goldish else 0.5
    Mm[sl] = 0.15 if goldish else 0.0              # toy-plastic gold like the 2D (0.45 read orange-brown, 10/12)
# PB.save_maps turns C from display to linear before writing the 8-bit PNG, and the PNG keeps those values (it is
# meant for bake() output, whose reader did the opposite); hand it the palette pre-encoded so the PNG = the palette
C = np.where(C <= 0.0031308, C * 12.92, 1.055 * np.power(np.clip(C, 0, 1), 1 / 2.4) - 0.055)
maps = {"C": C, "R": Rm[..., None].repeat(3, 2), "M": Mm[..., None].repeat(3, 2), "N": np.dstack([np.full((S, S), 0.5), np.full((S, S), 0.5), np.ones((S, S))])}
maps["MR"] = np.dstack([np.zeros((S, S)), Rm, Mm])
mat = PB.save_maps(maps, OUT, NAME)
for tn in mat.node_tree.nodes:                       # pixel palette: no blending between colour cells
    if tn.type == "TEX_IMAGE":
        tn.interpolation = "Closest"
me.materials.append(mat)
stats["palette"] = [[int(round(255 * x)) for x in p] for p in pal_srgb]

# ---------------------------------------------------------------- outline shell (same rule as tools/tripo_touchup.py)
ol = work.copy()
ol.data = work.data.copy()
ol.name = NAME + "_Outline"
bpy.context.scene.collection.objects.link(ol)
ol.data.materials.clear()
for o in bpy.context.view_layer.objects:
    o.select_set(o is ol)
bpy.context.view_layer.objects.active = ol
rm = ol.modifiers.new("r", "REMESH")
rm.mode = "VOXEL"
rm.voxel_size = max(0.02, 0.25 * cell)
bpy.ops.object.modifier_apply(modifier=rm.name)
nt_ = sum(len(p.vertices) - 2 for p in ol.data.polygons)
if nt_ > 4000:
    dm = ol.modifiers.new("d", "DECIMATE")
    dm.ratio = 4000 / nt_
    bpy.ops.object.modifier_apply(modifier=dm.name)
tm = ol.modifiers.new("t", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tm.name)
obm = bmesh.new()
obm.from_mesh(ol.data)
obm.normal_update()
for v in obm.verts:
    v.co += v.normal * a.outline * min(v.calc_shell_factor(), 3.0)
bmesh.ops.reverse_faces(obm, faces=obm.faces)
obm.to_mesh(ol.data)
obm.free()
while ol.data.uv_layers:
    ol.data.uv_layers.remove(ol.data.uv_layers[0])
om = bpy.data.materials.new("Outline")
om.use_nodes = True
om.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.069, 0.031, 0.017, 1)
om.use_backface_culling = True
ol.data.materials.append(om)
stats["outline"] = {"thickness": a.outline, "tris": sum(len(p.vertices) - 2 for p in ol.data.polygons)}

for o in bpy.context.view_layer.objects:
    o.select_set(o in (work, ol))
bpy.context.view_layer.objects.active = work
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
stats["pivot"] = "origin = bottom centre (x, y centre, z = lowest block); front +y (Roblox -Z), up +z (Roblox +Y)"
json.dump(stats, open(os.path.join(OUT, NAME + ".json"), "w"), indent=1)
log("done", json.dumps(stats))
