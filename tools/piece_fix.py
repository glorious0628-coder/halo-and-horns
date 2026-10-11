"""Blender fix pass for kept Tripo pieces (SPEC A23-125 step 2 "Blender 손보기"), 이미지 생성 3, 10/11.

  blender --background --factory-startup --python tools/piece_fix.py -- <in.glb> <out.glb> <work_dir> --only <name part> ...
          [--stats] [--flowers] [--sliver 8] [--pale-area 0.05] [--island 6] [--size 1024]

For every mesh object whose name contains one of --only (others are passed through unchanged):
  1. cut slivers: triangles whose longest edge^2 / (2 area) > --sliver and whose longest edge > 0.2 studs (Tripo's long
     thin shards along plant edges), and pale large faces (white / grey texel, area > --pale-area: leftover bits of the
     planter / wall Tripo fused into the plant);
  2. drop small loose islands (fewer than --island faces, or under 0.15 studs across) = floating crumbs; done after
     the UV tiles of a part are joined and welded (the tile split cuts leaves into small pieces);
  3. --flowers: white and blue petal faces are clustered into flowers; each cluster is cut out and replaced by an exact
     Blender flower (5 rounded petals + a yellow centre, sized and turned like the cluster) in separate objects
     Orn_<part>_FlowersWhite / _FlowersBlue / _FlowerCentres (flat materials; Studio: SmoothPlastic colours);
  4. the UV tiles of one part (<name>_t00.._t11) are joined into one object <name> and its own 4 maps are baked from the
     old (shared) textures into a packed UV: <work>/<name>_{C,N,R,M}.png (colour, tangent normal, roughness, metalness;
     --size, small parts 512) + _MR.png for the glTF material (G rough, B metal).
--stats prints face statistics per object (area, sliver ratio, colour classes) and stops.
Writes <work>/piece_fix_report.json (what was cut / added per object and part).
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
ap.add_argument("inp")
ap.add_argument("out")
ap.add_argument("work")
ap.add_argument("--only", nargs="+", required=True)
ap.add_argument("--stats", action="store_true")
ap.add_argument("--flowers", action="store_true")
ap.add_argument("--sliver", type=float, default=8.0)
ap.add_argument("--pale-area", type=float, default=0.05)
ap.add_argument("--island", type=int, default=6)
ap.add_argument("--size", type=int, default=1024)
a = ap.parse_args(argv)
os.makedirs(a.work, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    o.data.transform(o.matrix_world)
    o.matrix_world.identity()
    o.parent = None


def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def images_of(o):
    """{'color': img, 'normal': img, 'mr': img} from the glTF material"""
    out = {}
    m = o.data.materials[0]
    for n in m.node_tree.nodes:
        if n.type != "TEX_IMAGE" or not n.image:
            continue
        for l in n.outputs[0].links:
            t = l.to_node
            if t.type == "BSDF_PRINCIPLED" and l.to_socket.name == "Base Color":
                out["color"] = n.image
            elif t.type == "NORMAL_MAP":
                out["normal"] = n.image
            elif t.type in ("SEPRGB", "SEPARATE_COLOR", "SEPARATE_RGB"):
                out["mr"] = n.image
    return out


def face_colours(o, cimg):
    W, H = cimg.size
    arr = np.empty(W * H * cimg.channels, np.float32)
    cimg.pixels.foreach_get(arr)
    arr = arr.reshape(H, W, cimg.channels)
    uv = o.data.uv_layers.active.data
    hsv = []
    for p in o.data.polygons:
        us = [uv[li].uv for li in p.loop_indices]
        u = sum(q.x for q in us) / len(us)
        v = sum(q.y for q in us) / len(us)
        c = arr[min(H - 1, max(0, int(v * H))), min(W - 1, max(0, int(u * W))), :3]
        hsv.append(colorsys.rgb_to_hsv(*[lin2srgb(float(x)) for x in c]))
    return np.array(hsv).reshape(-1, 3)


def classes(hsv):
    h, s, v = hsv[:, 0] * 360, hsv[:, 1], hsv[:, 2]
    white = (s < 0.22) & (v > 0.72)
    pale = (s < 0.2) & (v > 0.5)
    blue = (h > 185) & (h < 240) & (s > 0.28) & (v > 0.45)
    yellow = (h > 35) & (h < 65) & (s > 0.45) & (v > 0.6)
    return white, pale, blue, yellow


def raw(img):
    W, H = img.size
    arr = np.empty(W * H * img.channels, np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(H, W, img.channels)[:, :, :3]
    if img.colorspace_settings.name != "Non-Color":
        arr = np.where(arr <= 0.0031308, arr * 12.92, 1.055 * np.power(np.clip(arr, 0, 1), 1 / 2.4) - 0.055)
    return (np.clip(arr, 0, 1) * 255)[::-1].astype(np.uint8)   # top row first


def petal_fan(bm, M, rx, ry, cup, seg=8):
    """one rounded petal: an elliptic fan (seg triangles a side, both sides), its rim lifted by `cup`"""
    ctr = bm.verts.new(M @ Vector((0.0, 0.0, 0.0)))
    rim = [bm.verts.new(M @ Vector((rx * math.cos(2 * math.pi * i / seg), ry * math.sin(2 * math.pi * i / seg),
                                    cup * (1 + math.cos(2 * math.pi * i / seg)) / 2))) for i in range(seg)]
    back = bm.verts.new(M @ Vector((0.0, 0.0, -cup * 0.6)))
    for i in range(seg):
        bm.faces.new((ctr, rim[i], rim[(i + 1) % seg]))
        bm.faces.new((back, rim[(i + 1) % seg], rim[i]))


report = {}
FLOWER_RGB = {"White": (250, 250, 244), "Blue": (110, 168, 236), "Centre": (250, 206, 62)}
targets = [o for o in objs if any(n in o.name for n in a.only)]
flower_bms = {}                                                  # part name -> {kind: bmesh}

# ---------------------------------------------------------------- 1-3: cut, islands, flowers (per object)
for o in targets:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    me = o.data
    imgs = images_of(o)
    hsv = face_colours(o, imgs["color"])
    white, pale, blue, yellow = classes(hsv)
    area = np.array([p.area for p in me.polygons])
    longest = np.array([max((me.vertices[p.vertices[i]].co - me.vertices[p.vertices[(i + 1) % 3]].co).length
                            for i in range(3)) for p in me.polygons])
    sliver = longest ** 2 / (2 * np.maximum(area, 1e-9))
    cen = np.array([p.center[:] for p in me.polygons]).reshape(-1, 3)
    nor = np.array([p.normal[:] for p in me.polygons]).reshape(-1, 3)
    if a.stats:
        print("[fix] %s faces %d | area p50 %.4f p90 %.4f max %.3f | sliver>8 %d >15 %d | white %d (area p50 %.4f) pale %d blue %d yellow %d"
              % (o.name, len(area), np.median(area), np.percentile(area, 90), area.max(), (sliver > 8).sum(), (sliver > 15).sum(),
                 white.sum(), np.median(area[white]) if white.any() else 0, pale.sum(), blue.sum(), yellow.sum()), flush=True)
        continue
    cut = (sliver > a.sliver) & (longest > 0.2)
    cut |= pale & (area > a.pale_area)
    if a.flowers:                                              # planter-rim leftovers at the foot of pot plants
        cut |= pale & ~white & (cen[:, 2] < cen[:, 2].min() + 0.35)
    rec = {"faces_in": int(len(area)), "slivers_pale": int(cut.sum())}
    part = o.name.split(".")[0]
    if len(part) > 4 and part[-4:-2] == "_t" and part[-2:].isdigit():
        part = part[:-4]
    if a.flowers:
        par = {}

        def find(i):
            while par[i] != i:
                par[i] = par[par[i]]
                i = par[i]
            return i
        groups = {}
        for cls in (blue & ~cut, white & ~blue & ~cut):            # blue and white flowers stay apart
            idx = np.nonzero(cls)[0]
            for i in idx:
                par[int(i)] = int(i)
            for i in idx:
                d = np.linalg.norm(cen[idx] - cen[i], axis=1)
                for j in idx[d < 0.3]:
                    ri, rj = find(int(i)), find(int(j))
                    if ri != rj:
                        par[ri] = rj
            for i in idx:
                groups.setdefault(find(int(i)), []).append(int(i))
        bc = cen.mean(0)
        nfl = 0
        for g in groups.values():
            if len(g) < 4:
                continue
            g = np.array(g)
            kind = "Blue" if blue[g].any() else "White"
            c = (cen[g] * area[g, None]).sum(0) / max(area[g].sum(), 1e-9)
            ext = np.linalg.norm(cen[g] - c, axis=1).max()
            n = (nor[g] * area[g, None]).sum(0)
            if np.linalg.norm(n) < 1e-6:
                n = c - bc
            n = n / np.linalg.norm(n)
            if np.dot(n, c - bc) < 0:
                n = -n
            n[2] = max(n[2], 0.25)                                 # flowers face out and a little up
            n = n / np.linalg.norm(n)
            d = float(np.clip(ext * 2.3, 0.5 if kind == "Blue" else 0.35, 0.95))
            cut[g] = True
            cut |= yellow & (np.linalg.norm(cen - c, axis=1) < max(ext, 0.12) * 1.1)   # the old centre goes too
            fb = flower_bms.setdefault(part, {k: bmesh.new() for k in FLOWER_RGB})
            cv, nv = Vector(c.tolist()), Vector(n.tolist())
            q = nv.to_track_quat("Z", "Y").to_matrix().to_4x4()
            spin = (int(abs(c[0] * 97 + c[1] * 31 + c[2] * 7)) % 100) / 100.0
            for k in range(5):
                t = 2 * math.pi * k / 5 + spin
                M = (Matrix.Translation(cv) @ q @ Matrix.Rotation(t, 4, "Z") @ Matrix.Translation((d * 0.27, 0, d * 0.02))
                     @ Matrix.Rotation(math.radians(-14), 4, "Y"))
                petal_fan(fb[kind], M, d * 0.27, d * 0.17, d * 0.035)
            M = Matrix.Translation(cv + nv * d * 0.05) @ q @ Matrix.Diagonal((d * 0.13, d * 0.13, d * 0.09, 1))
            gg = bmesh.ops.create_uvsphere(fb["Centre"], u_segments=6, v_segments=4, radius=1.0)
            bmesh.ops.transform(fb["Centre"], matrix=M, verts=gg["verts"])
            nfl += 1
        rec["flowers"] = nfl
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if cut[f.index]], context="FACES")
    bm.to_mesh(me)
    bm.free()
    rec["faces_out"] = len(me.polygons)
    report[o.name] = rec
    print("[fix] %s %s" % (o.name, rec), flush=True)

if a.stats:
    sys.exit(0)

for part, fb in flower_bms.items():
    for k, b in fb.items():
        if not b.verts:
            b.free()
            continue
        nm = "Orn_%s_%s" % (part.split("HaloDomeHouse_07_")[-1], {"White": "FlowersWhite", "Blue": "FlowersBlue", "Centre": "FlowerCentres"}[k])
        m2 = bpy.data.meshes.new(nm)
        b.to_mesh(m2)
        b.free()
        for f in m2.polygons:
            f.use_smooth = True
        mt = bpy.data.materials.new("Flower" + k)
        mt.use_nodes = True
        pb = mt.node_tree.nodes["Principled BSDF"]
        pb.inputs["Base Color"].default_value = (*[s2l(v / 255) for v in FLOWER_RGB[k]], 1)
        pb.inputs["Roughness"].default_value = 0.55
        m2.materials.append(mt)
        bpy.context.scene.collection.objects.link(bpy.data.objects.new(nm, m2))

# ---------------------------------------------------------------- 4: per part, join its UV tiles, bake its own 4 maps
groups = {}
for o in targets:
    part = o.name.split(".")[0]
    if len(part) > 4 and part[-4:-2] == "_t" and part[-2:].isdigit():
        part = part[:-4]
    groups.setdefault(part, []).append(o)
for gname, members in groups.items():
    members = [o for o in members if len(o.data.polygons)]
    if not members:
        continue
    srcs = []
    for i, o in enumerate(members):
        im = images_of(o)
        srcs.append([raw(im["color"]), raw(im["normal"]), raw(im["mr"])])
        mt = bpy.data.materials.new("src%02d" % i)               # slot i = member i (source maps)
        o.data.materials.clear()
        o.data.materials.append(mt)
    bpy.ops.object.select_all(action="DESELECT")
    for o in members:
        o.select_set(True)
    bpy.context.view_layer.objects.active = members[0]
    if len(members) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = o.data.name = gname
    me = o.data
    slot_src = [srcs[int(m.name[3:5])] for m in me.materials]
    # weld the tile seams, then drop small loose islands (floating crumbs)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.faces.ensure_lookup_table()
    seen = set()
    drop = []
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        comp, stack = [], [f0]
        seen.add(f0.index)
        while stack:
            f = stack.pop()
            comp.append(f)
            for e in f.edges:
                for g2 in e.link_faces:
                    if g2.index not in seen:
                        seen.add(g2.index)
                        stack.append(g2)
        co = np.array([v.co[:] for f in comp for v in f.verts])
        if len(comp) < a.island or np.linalg.norm(co.max(0) - co.min(0)) < 0.15:
            drop += comp
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    island_cut = len(drop)
    me.calc_loop_triangles()
    uvl = me.uv_layers.active.data
    old = [np.array([uvl[li].uv[:] for li in t.loops]) for t in me.loop_triangles]
    tri_src = [me.polygons[t.polygon_index].material_index for t in me.loop_triangles]
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    uvl = me.uv_layers.active.data
    new = [np.array([uvl[li].uv[:] for li in t.loops]) for t in me.loop_triangles]
    size = a.size if len(new) > 1200 else 512
    outs = [np.zeros((size, size, 3), np.float32) for _ in range(3)]
    filled = np.zeros((size, size), bool)
    for P, Q, si in zip(new, old, tri_src):
        src3 = slot_src[si]
        H, W = src3[0].shape[:2]
        P = P * size
        Q = Q * np.array([W, H])
        x0, y0 = np.floor(P.min(0)).astype(int) - 1
        x1, y1 = np.ceil(P.max(0)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        dd = (P[1, 1] - P[2, 1]) * (P[0, 0] - P[2, 0]) + (P[2, 0] - P[1, 0]) * (P[0, 1] - P[2, 1])
        if abs(dd) < 1e-9:
            continue
        l0 = ((P[1, 1] - P[2, 1]) * (xs - P[2, 0]) + (P[2, 0] - P[1, 0]) * (ys - P[2, 1])) / dd
        l1 = ((P[2, 1] - P[0, 1]) * (xs - P[2, 0]) + (P[0, 0] - P[2, 0]) * (ys - P[2, 1])) / dd
        l2 = 1 - l0 - l1
        ins = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not ins.any():
            continue
        qx = np.clip(l0 * Q[0, 0] + l1 * Q[1, 0] + l2 * Q[2, 0] - 0.5, 0, W - 1.001)
        qy = np.clip(H - (l0 * Q[0, 1] + l1 * Q[1, 1] + l2 * Q[2, 1]) - 0.5, 0, H - 1.001)
        ix, iy = qx.astype(int), qy.astype(int)
        fx, fy = (qx - ix)[..., None], (qy - iy)[..., None]
        rows = size - 1 - np.arange(y0, y1 + 1)
        cols = np.arange(x0, x1 + 1)
        for oo, src in zip(outs, src3):
            v = (src[iy, ix].astype(np.float32) * (1 - fx) * (1 - fy) + src[iy, ix + 1] * fx * (1 - fy)
                 + src[iy + 1, ix] * (1 - fx) * fy + src[iy + 1, ix + 1] * fx * fy) / 255.0
            sub = oo[rows[:, None], cols[None, :]]
            sub[ins] = v[ins]
            oo[rows[:, None], cols[None, :]] = sub
        fs = filled[rows[:, None], cols[None, :]]
        fs |= ins
        filled[rows[:, None], cols[None, :]] = fs
    cover = float(filled.mean())
    for _ in range(4):
        acc = [np.zeros_like(oo) for oo in outs]
        cnt = np.zeros((size, size), np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sf = np.roll(np.roll(filled, dy, 0), dx, 1)
            cnt += sf
            for ac, oo in zip(acc, outs):
                ac += np.roll(np.roll(oo, dy, 0), dx, 1) * sf[..., None]
        nw = (~filled) & (cnt > 0)
        for ac, oo in zip(acc, outs):
            oo[nw] = ac[nw] / cnt[nw][:, None]
        filled |= nw
    col, nrm, mr = outs
    made = {}

    def save(arr, tag, srgb):
        im = bpy.data.images.new(gname + "_" + tag, size, size, alpha=False, is_data=not srgb)
        if not srgb:
            im.colorspace_settings.name = "Non-Color"
        lin = arr if not srgb else np.where(arr <= 0.04045, arr / 12.92, ((arr + 0.055) / 1.055) ** 2.4)
        rgba = np.concatenate([lin, np.ones(lin.shape[:2] + (1,), np.float32)], -1)[::-1]
        im.pixels.foreach_set(rgba.ravel().astype(np.float32))
        im.filepath_raw = os.path.join(a.work, gname + "_" + tag + ".png")
        im.file_format = "PNG"
        im.save()
        made[tag] = im

    save(col, "C", True)
    save(nrm, "N", False)
    save(np.repeat(mr[:, :, 1:2], 3, 2), "R", False)
    save(np.repeat(mr[:, :, 2:3], 3, 2), "M", False)
    save(mr, "MR", False)
    m = bpy.data.materials.new(gname)
    m.use_nodes = True
    nt = m.node_tree
    pb = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = made["C"]
    nt.links.new(tc.outputs["Color"], pb.inputs["Base Color"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = made["N"]
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], pb.inputs["Normal"])
    tm = nt.nodes.new("ShaderNodeTexImage")
    tm.image = made["MR"]
    sp = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tm.outputs["Color"], sp.inputs["Color"])
    nt.links.new(sp.outputs["Green"], pb.inputs["Roughness"])
    nt.links.new(sp.outputs["Blue"], pb.inputs["Metallic"])
    me.materials.clear()
    me.materials.append(m)
    for p_ in me.polygons:
        p_.material_index = 0
    report.setdefault("_parts", {})[gname] = {"tiles_joined": len(members), "island_faces_cut": island_cut, "tris": len(new),
                                              "maps": size, "uv_fill": round(cover, 3)}
    print("[fix] part %s: %d tiles joined, %d tris, 4 maps %d, fill %.2f" % (gname, len(members), len(new), size, cover), flush=True)

json.dump(report, open(os.path.join(a.work, "piece_fix_report.json"), "w"), indent=1)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False)
print("[fix] ok ->", a.out, flush=True)
