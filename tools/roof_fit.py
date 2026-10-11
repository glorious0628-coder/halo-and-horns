"""Blender fix for a Tripo octagonal roof (SPEC A23-125 "Blender 손보기": symmetric things symmetric), 이미지 생성 3, 10/11.

  blender --background --factory-startup --python tools/roof_fit.py -- <in.glb> <out.glb> <plan.json> [--name _Roof]
          [--report <json>] [--corners gold|radius]

plan.json: {"roof": {"center": [x, y], "poly": [[x, y] x 8]}} (the octagon the eaves must follow; tools/skeleton_house07.py
writes it into <out>_ornaments.json). The Tripo roof's eave outline is uneven and its 8 gold ribs are not at the body's
corners. The warp keeps the tile detail and fixes the shape:
  - apex: the xy of the top vertices; every vertex is taken in polar coordinates around it;
  - ribs: the angles where gold faces gather (mid height; up to 16, a roof may also have ribs down its face middles) ->
    each to the nearest corner or face middle of the plan octagon, piecewise-linear between them (ribs land on corners);
  - radius: the old eave outline is taken as the polygon through the old corners (corner-rib angles, robust radius on the
    lowest band); each vertex is scaled so that polygon becomes the plan octagon (straight eaves stay straight), every
    height the same way, apex on the plan centre.
UVs and textures are untouched (bake the part's own maps after this with tools/piece_fix.py).
"""
import argparse
import colorsys
import json
import math
import sys

import bmesh
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("inp")
ap.add_argument("out")
ap.add_argument("plan")
ap.add_argument("--name", default="_Roof")
ap.add_argument("--report")
ap.add_argument("--corners", default="gold", choices=["gold", "radius"],
                help="gold: rib angles from gold faces (a tiled roof with gold ribs, house 07); radius: the corners of the "
                     "eave outline from the radius peaks of the lowest band (an all-gold faceted dome, tools/house_deco.py)")
a = ap.parse_args(argv)
plan = json.load(open(a.plan))["roof"]
PC = np.array(plan["center"], float)
POLY = np.array(plan["poly"], float)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    o.data.transform(o.matrix_world)
    o.matrix_world.identity()
    o.parent = None
roofs = [o for o in objs if a.name in o.name]
if not roofs:
    sys.exit("[roof] no object with %s" % a.name)


def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


V = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in roofs])
zmin, zmax = V[:, 2].min(), V[:, 2].max()
apex = V[V[:, 2] > zmax - 0.35, :2].mean(0)
# gold faces at mid height -> rib angles
angs = []
for o in roofs:
    img = None
    for n in o.data.materials[0].node_tree.nodes:
        if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
            img = n.image
    W, H = img.size
    px = np.empty(W * H * img.channels, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(H, W, img.channels)
    uv = o.data.uv_layers.active.data
    for p in o.data.polygons:
        c = p.center
        if not (zmin + 0.25 * (zmax - zmin) < c.z < zmin + 0.6 * (zmax - zmin)):
            continue
        us = [uv[li].uv for li in p.loop_indices]
        u = sum(q.x for q in us) / len(us)
        v = sum(q.y for q in us) / len(us)
        col = px[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W))), :3]
        h, s_, val = colorsys.rgb_to_hsv(*[lin2srgb(float(x)) for x in col])
        if 35 <= h * 360 <= 62 and s_ > 0.45 and val > 0.6:
            angs.append(math.degrees(math.atan2(c.y - apex[1], c.x - apex[0])) % 360)
hist = np.zeros(360)
for t in angs:
    hist[int(t) % 360] += 1
k = np.exp(-0.5 * (np.arange(-12, 13) / 4.0) ** 2)
sm = np.array([sum(hist[(i + j) % 360] * k[j + 12] for j in range(-12, 13)) for i in range(360)])
# rib peaks: up to 16 (a roof can also have ribs down the middle of its faces, like the 2D front), strong ones only
ribs = []
order = np.argsort(-sm)
for i in order:
    if sm[i] < 0.25 * sm[order[0]]:
        break
    if all(min(abs(i - r), 360 - abs(i - r)) > 14 for r in ribs):
        ribs.append(int(i))
    if len(ribs) == 16:
        break
ribs = sorted(ribs)
if a.corners == "radius":                                    # one peak per plan corner in the lowest band's outline
    lowb = V[V[:, 2] < zmin + 0.12 * (zmax - zmin)]
    la_ = np.degrees(np.arctan2(lowb[:, 1] - apex[1], lowb[:, 0] - apex[0])) % 360
    lr_ = np.hypot(lowb[:, 0] - apex[0], lowb[:, 1] - apex[1])
    rb = np.zeros(360)
    for t_, r_ in zip(la_, lr_):
        rb[int(t_) % 360] = max(rb[int(t_) % 360], r_)
    for i in range(360):                                     # empty degrees: the neighbours' value
        if rb[i] == 0:
            rb[i] = max(rb[(i - 1) % 360], rb[(i + 1) % 360])
    sm = np.array([sum(rb[(i + j) % 360] * k[j + 12] for j in range(-12, 13)) for i in range(360)])
    ribs = []
    for i in np.argsort(-sm):
        if all(min(abs(i - r), 360 - abs(i - r)) > 22 for r in ribs):
            ribs.append(int(i))
        if len(ribs) == len(POLY):
            break
    ribs = sorted(ribs)
corners = sorted((math.degrees(math.atan2(y - PC[1], x - PC[0])) % 360) for x, y in POLY)
mids = []
for i in range(len(POLY)):                                   # face middles of the plan octagon
    m_ = (POLY[i] + POLY[(i + 1) % len(POLY)]) / 2
    mids.append(math.degrees(math.atan2(m_[1] - PC[1], m_[0] - PC[0])) % 360)
tgt = corners
targets = sorted(corners + mids)
# each rib goes to the nearest corner or face middle (keeping the order round the roof)
pairs = []
for r in ribs:
    c = min(targets, key=lambda t: abs((t - r + 180) % 360 - 180))
    if all(abs((c - p[1] + 180) % 360 - 180) > 1e-6 for p in pairs):
        pairs.append((r, c))
pairs.sort()
NP = len(pairs)


def remap(t):
    """piecewise-linear map of an old angle (deg) through the rib -> corner pairs"""
    for i in range(NP):
        r0, c0 = pairs[i]
        r1, c1 = pairs[(i + 1) % NP]
        span = (r1 - r0) % 360
        d = (t - r0) % 360
        if d <= span:
            cspan = (c1 - c0) % 360
            return (c0 + cspan * d / max(span, 1e-6)) % 360
    return t


# old eave outline = the polygon through the old corners (corner ribs at the lowest band, robust radius), so straight
# eaves stay straight (a per-degree radius picked up the tile scallops and made the eaves wavy)
low = V[V[:, 2] < zmin + 0.5]
lr = np.hypot(low[:, 0] - apex[0], low[:, 1] - apex[1])
la = np.degrees(np.arctan2(low[:, 1] - apex[1], low[:, 0] - apex[0])) % 360
old_corners = []
for r, c in pairs:
    if min(abs((c - t + 180) % 360 - 180) for t in corners) > 1e-6:
        continue                                               # a face-middle rib, not a corner
    sel = np.abs((la - r + 180) % 360 - 180) < 4
    rad = float(np.percentile(lr[sel], 85)) if sel.sum() >= 3 else float(np.percentile(lr, 85))
    old_corners.append((math.radians(r), rad))
old_corners.sort()
OLD = np.array([[apex[0] + R * math.cos(t), apex[1] + R * math.sin(t)] for t, R in old_corners])


def poly_radius(poly, centre, t):
    """distance from centre to the polygon edge along angle t (deg)"""
    d = np.array([math.cos(math.radians(t)), math.sin(math.radians(t))])
    best_r = None
    for i in range(len(poly)):
        p0, p1 = poly[i] - centre, poly[(i + 1) % len(poly)] - centre
        e = p1 - p0
        den = d[0] * (-e[1]) - d[1] * (-e[0])
        if abs(den) < 1e-9:
            continue
        r = (p0[0] * (-e[1]) - p0[1] * (-e[0])) / den
        s_ = (d[0] * p0[1] - d[1] * p0[0]) / den
        if r > 0 and -1e-6 <= s_ <= 1 + 1e-6:
            best_r = r if best_r is None else min(best_r, r)
    return best_r


moved = 0
for o in roofs:
    for v in o.data.vertices:
        x, y, z = v.co
        r = math.hypot(x - apex[0], y - apex[1])
        t = math.degrees(math.atan2(y - apex[1], x - apex[0])) % 360
        t2 = remap(t)
        er = poly_radius(OLD, apex, t)
        s_ = poly_radius(POLY, PC, t2) / er if er else 1.0
        r2 = r * s_
        v.co = (PC[0] + r2 * math.cos(math.radians(t2)), PC[1] + r2 * math.sin(math.radians(t2)), z)
        moved += 1
    o.data.update()
# lumps that still stick out past the eaves after the warp (the old dormer hood fused into the Tripo roof): cut faces
# whose every corner is more than 0.35 studs outside the plan octagon
cut_faces = 0
for o in roofs:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    out = []
    for f in bm.faces:
        if all(math.hypot(v.co.x - PC[0], v.co.y - PC[1]) > poly_radius(POLY, PC, math.degrees(math.atan2(v.co.y - PC[1], v.co.x - PC[0])) % 360) + 0.35
               for v in f.verts):
            out.append(f)
    bmesh.ops.delete(bm, geom=out, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    cut_faces += len(out)
rep = {"apex_old": apex.round(3).tolist(), "ribs_old": ribs, "rib_strength": [int(sm[r]) for r in ribs],
       "corners": [round(c, 1) for c in corners],
       "pairs": [[r, round(c, 1)] for r, c in pairs], "vertices": moved,
       "old_corner_radius": [round(R, 2) for _, R in old_corners], "lump_faces_cut": cut_faces}
print("[roof]", json.dumps(rep), flush=True)
if a.report:
    json.dump(rep, open(a.report, "w"), indent=1)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False)
print("[roof] ok ->", a.out, flush=True)
