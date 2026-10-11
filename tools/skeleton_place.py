"""Move the kept Tripo pieces onto a Studio skeleton (이미지 생성 3, 10/11, SPEC A23-120).

  blender --background --factory-startup --python tools/skeleton_place.py -- <keep.glb> <place.json> <out.glb>

keep.glb = tools/skeleton_keep.py output (objects <base>_<Kind>[_tXY]). place.json (written by the skeleton generator):
  {"kinds": {Kind: [rule, ...]}}; kinds not listed are dropped. A rule takes the faces of that kind inside "region"
  (optional; "x"/"y"/"z": [min, max] of the face centre, "near": [x, y, r] in xy, "arch": [cx, spring_z, r] = inside
  an arched opening in the x-z plane, "no_white": true = skip pale stone-coloured faces by their base-colour texel, "drop_tall": h = skip loose pieces
  taller than h, e.g. strips of an old door frame left in the door hardware, "no_gold": true = skip gold texels,
  "drop_boxes": [[[x0, x1], [y0, y1], [z0, z1]], ...] = skip faces inside any of these boxes) into a new object (named
  <base>_<rename or Kind>[_tXY]) and then applies, in this order: "scale" [sx, sy, sz] about "about" [x, y, z],
  "move" [dx, dy, dz], "rotz" (degrees, counter-clockwise seen from above, about the rule's box centre), "align" {"cx", "cy", "ymin", "ymax", "zmin"} (moves the bounding box of everything that rule
  took over all tiles). Faces no rule takes are dropped. Transforms are written into the mesh (objects stay at identity),
  so the GLB lines up with the skeleton when its Blender origin is put on the skeleton origin.
Prints each object's box.
"""
import colorsys
import json
import sys

import bmesh
import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, PLACE, OUT = argv
rules = json.load(open(PLACE))["kinds"]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:  # bake the object transform into the mesh
    o.data.transform(o.matrix_world)
    o.matrix_world.identity()
    o.parent = None
base = objs[0].name.split("_")[0] + "_" + objs[0].name.split("_")[1]


def kind_of(name):
    rest = name[len(base) + 1:]
    k = rest.split("_")[0]
    tile = rest[len(k):]
    return k, tile


def take(o, mask, name):
    new = o.copy()
    new.data = o.data.copy()
    new.name = new.data.name = name
    bpy.context.scene.collection.objects.link(new)
    bm = bmesh.new()
    bm.from_mesh(new.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not mask[f.index]], context="FACES")
    bm.to_mesh(new.data)
    bm.free()
    return new


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


def in_region(cen, reg, o=None):
    m = np.ones(len(cen), bool)
    if "arch" in reg:
        cx, sp, r = reg["arch"]
        dx = np.abs(cen[:, 0] - cx)
        m &= (dx <= r) & ((cen[:, 2] <= sp) | (np.hypot(dx, cen[:, 2] - sp) <= r))
    if "drop_tall" in reg:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        seen = np.zeros(len(bm.faces), bool)
        for f0 in bm.faces:
            if seen[f0.index]:
                continue
            comp, stack = [], [f0]
            seen[f0.index] = True
            while stack:
                f = stack.pop()
                comp.append(f.index)
                for e in f.edges:
                    for g in e.link_faces:
                        if not seen[g.index]:
                            seen[g.index] = True
                            stack.append(g)
            z = cen[comp, 2]
            if z.max() - z.min() > reg["drop_tall"]:
                m[comp] = False
        bm.free()
    if reg.get("no_white") or reg.get("no_gold"):
        hsv = face_hsv(o)
        if reg.get("no_white"):
            m &= ~((hsv[:, 1] < 0.22) & (hsv[:, 2] > 0.7))
        if reg.get("no_gold"):
            m &= ~((hsv[:, 0] * 360 >= 41) & (hsv[:, 0] * 360 <= 62) & (hsv[:, 1] > 0.45) & (hsv[:, 2] > 0.7))
    for bx in reg.get("drop_boxes", []):
        m &= ~((cen[:, 0] >= bx[0][0]) & (cen[:, 0] <= bx[0][1]) & (cen[:, 1] >= bx[1][0]) & (cen[:, 1] <= bx[1][1])
               & (cen[:, 2] >= bx[2][0]) & (cen[:, 2] <= bx[2][1]))
    for ax, i in (("x", 0), ("y", 1), ("z", 2)):
        if ax in reg:
            m &= (cen[:, i] >= reg[ax][0]) & (cen[:, i] <= reg[ax][1])
    if "near" in reg:
        x, y, r = reg["near"]
        m &= np.hypot(cen[:, 0] - x, cen[:, 1] - y) <= r
    return m


made = {}  # rule id -> objects
for o in objs:
    k, tile = kind_of(o.name)
    if k not in rules or len(o.data.polygons) == 0:
        continue
    cen = np.array([p.center[:] for p in o.data.polygons])
    taken = np.zeros(len(cen), bool)
    for ri, rule in enumerate(rules[k]):
        m = in_region(cen, rule.get("region", {}), o) & ~taken
        taken |= m
        if m.any():
            made.setdefault((k, ri), []).append(take(o, m, "%s_%s%s" % (base, rule.get("rename", k), tile)))
for o in objs:
    bpy.data.objects.remove(o, do_unlink=True)
for group in made.values():
    for o in group:
        o.name = o.data.name = o.name.split(".")[0]

for (k, ri), group in made.items():
    rule = rules[k][ri]
    for o in group:
        if "scale" in rule:
            s, c = np.array(rule["scale"]), np.array(rule.get("about", [0, 0, 0]))
            for v in o.data.vertices:
                v.co = (np.array(v.co) - c) * s + c
        if "move" in rule:
            for v in o.data.vertices:
                v.co = np.array(v.co) + np.array(rule["move"])
    if "rotz" in rule:
        V = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in group])
        c = (V.min(0) + V.max(0)) / 2
        t = np.radians(rule["rotz"])
        R = np.array([[np.cos(t), -np.sin(t), 0], [np.sin(t), np.cos(t), 0], [0, 0, 1]])
        for o in group:
            for v in o.data.vertices:
                v.co = R @ (np.array(v.co) - c) + c
    if "align" in rule:
        V = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in group])
        mn, mx = V.min(0), V.max(0)
        al = rule["align"]
        d = np.zeros(3)
        if "cx" in al:
            d[0] = al["cx"] - (mn[0] + mx[0]) / 2
        if "cy" in al:
            d[1] = al["cy"] - (mn[1] + mx[1]) / 2
        if "ymin" in al:
            d[1] = al["ymin"] - mn[1]
        if "ymax" in al:
            d[1] = al["ymax"] - mx[1]
        if "zmin" in al:
            d[2] = al["zmin"] - mn[2]
        for o in group:
            for v in o.data.vertices:
                v.co = np.array(v.co) + d
        print("[place] align %s/%d by %s" % (k, ri, np.round(d, 2)), flush=True)

bpy.ops.object.select_all(action="DESELECT")
tris = 0
for group in made.values():
    for o in group:
        o.data.update()
        o.select_set(True)
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        V = np.array([v.co[:] for v in o.data.vertices])
        print("[place] %-36s tris %6d  x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % (
            o.name, len(o.data.loop_triangles), *[f for i in range(3) for f in (V[:, i].min(), V[:, i].max())]), flush=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[place] ok tris %d -> %s" % (tris, OUT), flush=True)
