"""Projection bake for Blender touch-ups (SPEC A23-125 step 2), 이미지 생성 3, 10/11. Imported by tools/house_deco.py.

A clean mesh made in Blender (an exact arched door slab, a lathe-turned finial ...) takes its look from the Tripo piece it
replaces: for every texel of the new mesh's UV layout the matching point on the Tripo surface is found (a ray along a fixed
direction, or the nearest point) and Tripo's own base colour, roughness, metalness (and, if asked, its geometric relief as
a tangent-space normal) are copied. So the shape is exact and the paint is Tripo's.

  src = Source(objs)                       Tripo objects (each with its glTF material: colour / normal / metal-rough maps)
  maps = bake(new_obj, src, size=1024, ray=(0, -1, 0) | None, relief=True)
  -> {"C", "N", "R", "M", "MR"}: float arrays (size, size, 3), top row first; save_maps() writes PNGs and builds the material.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def _img_arr(img, srgb_to_display=True):
    W, H = img.size
    arr = np.empty(W * H * img.channels, np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(H, W, img.channels)[:, :, :3]
    if srgb_to_display and img.colorspace_settings.name != "Non-Color":
        arr = np.where(arr <= 0.0031308, arr * 12.92, 1.055 * np.power(np.clip(arr, 0, 1), 1 / 2.4) - 0.055)
    return np.clip(arr, 0, 1)                       # row 0 = bottom (Blender), values as stored in the PNG


def _images_of(o):
    out = {}
    for m in o.data.materials:
        if not m or not m.use_nodes:
            continue
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
        break
    return out


class Source:
    """all triangles of the given objects (world space) in one BVH, with their UVs and texture arrays"""

    def __init__(self, objs):
        verts, tris, uvs, nrm, sid = [], [], [], [], []
        self.tex = []
        base = 0
        for k, o in enumerate(objs):
            me = o.data
            me.calc_loop_triangles()
            M = o.matrix_world
            V = [M @ v.co for v in me.vertices]
            NM = M.to_3x3().inverted().transposed()
            VN = [(NM @ v.normal).normalized() for v in me.vertices]
            uvl = me.uv_layers.active.data
            for t in me.loop_triangles:
                tris.append([base + i for i in t.vertices])
                uvs.append([uvl[li].uv[:] for li in t.loops])
                sid.append(k)
            verts += [v[:] for v in V]
            nrm += [n[:] for n in VN]
            base += len(V)
            im = _images_of(o)
            self.tex.append({k2: _img_arr(v, k2 == "color") for k2, v in im.items()})
        self.V = np.array(verts, float)
        self.VN = np.array(nrm, float)
        self.T = np.array(tris, int)
        self.UV = np.array(uvs, float)
        self.S = np.array(sid, int)
        self.bvh = BVHTree.FromPolygons([Vector(v) for v in verts], [tuple(t) for t in tris])
        # Tripo's shards: long thin triangles (longest edge^2 / 2 area > 12, over 0.2 studs) a ray passes through
        A, B, C = (self.V[self.T[:, j]] for j in range(3))
        ar = np.linalg.norm(np.cross(B - A, C - A), axis=1) / 2
        le = np.max(np.stack([np.linalg.norm(B - A, axis=1), np.linalg.norm(C - B, axis=1), np.linalg.norm(A - C, axis=1)]), 0)
        self.bad = (le ** 2 / np.maximum(2 * ar, 1e-12) > 12) & (le > 0.2)
        self.FN = np.cross(B - A, C - A) / np.maximum(2 * ar, 1e-12)[:, None]   # unit face normals
        self.FC = (A + B + C) / 3
        self.strict = False                              # True: a ray that finds no accepted face leaves the texel empty

    def tri_hsv(self):
        """hue (deg), saturation, value of each triangle's base colour at its UV centre"""
        import colorsys
        out = np.zeros((len(self.T), 3))
        uvc = self.UV.mean(1)
        for k, tx in enumerate(self.tex):
            sel = self.S == k
            if not sel.any() or "color" not in tx:
                continue
            arr = tx["color"]
            H, W = arr.shape[:2]
            c = arr[np.clip((uvc[sel, 1] * H).astype(int), 0, H - 1), np.clip((uvc[sel, 0] * W).astype(int), 0, W - 1)]
            out[sel] = [(h * 360, s_, v) for h, s_, v in (colorsys.rgb_to_hsv(*q) for q in c)]
        return out

    def skip_where(self, mask):
        """rays pass through these triangles too (e.g. oblique faces, lumps standing out of a plank surface)"""
        self.bad = self.bad | mask

    def query(self, P, ray=None, back=0.6):
        """P (n, 3) points -> (tri index, barycentric (n, 3)); -1 where nothing was hit"""
        n = len(P)
        idx = np.full(n, -1, int)
        loc = np.zeros((n, 3))
        for i in range(n):
            p = Vector(P[i])
            if ray is not None:
                d = Vector(ray)
                o_ = p - d * back
                hit = self.bvh.ray_cast(o_, d, back * 4)
                for _ in range(4):                       # through shards to the surface behind
                    if hit[0] is None or not self.bad[hit[2]]:
                        break
                    o_ = hit[0] + d * 1e-3
                    hit = self.bvh.ray_cast(o_, d, back * 4)
                if hit[0] is not None and self.bad[hit[2]]:
                    hit = (None, None, None, None)
                if hit[0] is None and not self.strict:
                    hit = self.bvh.find_nearest(p)
            else:
                hit = self.bvh.find_nearest(p)
            if hit[0] is not None:
                idx[i] = hit[2]
                loc[i] = hit[0][:]
        ok = idx >= 0
        A, B, C = (self.V[self.T[idx[ok], j]] for j in range(3))
        v0, v1, v2 = B - A, C - A, loc[ok] - A
        d00 = (v0 * v0).sum(1)
        d01 = (v0 * v1).sum(1)
        d11 = (v1 * v1).sum(1)
        d20 = (v2 * v0).sum(1)
        d21 = (v2 * v1).sum(1)
        den = np.where(np.abs(d00 * d11 - d01 * d01) < 1e-12, 1e-12, d00 * d11 - d01 * d01)
        w1 = (d11 * d20 - d01 * d21) / den
        w2 = (d00 * d21 - d01 * d20) / den
        bary = np.zeros((n, 3))
        bary[ok] = np.clip(np.c_[1 - w1 - w2, w1, w2], 0, 1)
        bary[ok] /= bary[ok].sum(1, keepdims=True)
        return idx, bary

    def sample(self, idx, bary):
        """colour, roughness, metalness, smooth normal (world) at the query results"""
        n = len(idx)
        col = np.zeros((n, 3))
        rough = np.full(n, 0.5)
        metal = np.zeros(n)
        nor = np.zeros((n, 3))
        ok = idx >= 0
        uv = (self.UV[idx[ok]] * bary[ok][:, :, None]).sum(1)
        nn = (self.VN[self.T[idx[ok]]] * bary[ok][:, :, None]).sum(1)
        nor[ok] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
        sids = self.S[idx[ok]]
        rows = np.nonzero(ok)[0]
        for k, tx in enumerate(self.tex):
            sel = sids == k
            if not sel.any():
                continue
            for key in ("color", "mr"):
                if key not in tx:
                    continue
                arr = tx[key]
                H, W = arr.shape[:2]
                x = np.clip(uv[sel, 0] * W - 0.5, 0, W - 1.001)
                y = np.clip(uv[sel, 1] * H - 0.5, 0, H - 1.001)
                ix, iy = x.astype(int), y.astype(int)
                fx, fy = (x - ix)[:, None], (y - iy)[:, None]
                v = (arr[iy, ix] * (1 - fx) * (1 - fy) + arr[iy, ix + 1] * fx * (1 - fy) + arr[iy + 1, ix] * (1 - fx) * fy
                     + arr[iy + 1, ix + 1] * fx * fy)
                if key == "color":
                    col[rows[sel]] = v
                else:
                    rough[rows[sel]] = v[:, 1]
                    metal[rows[sel]] = v[:, 2]
        return col, rough, metal, nor


def bake(obj, src, size=1024, ray=None, relief=True, pad=4):
    """rasterise obj's UV layout; every covered texel takes the Tripo look at its 3D point. Returns the maps (top row first)."""
    me = obj.data
    me.calc_loop_triangles()
    M = obj.matrix_world
    V = np.array([(M @ v.co)[:] for v in me.vertices])
    uvl = me.uv_layers.active.data
    pts, tbn, pix = [], [], []
    for t in me.loop_triangles:
        P = np.array([uvl[li].uv[:] for li in t.loops]) * size
        X = V[list(t.vertices)]
        # tangent frame from the UV gradients (T = d pos / d u, B = d pos / d v)
        e1, e2 = X[1] - X[0], X[2] - X[0]
        d1, d2 = P[1] - P[0], P[2] - P[0]
        det = d1[0] * d2[1] - d2[0] * d1[1]
        if abs(det) < 1e-12:
            continue
        T = (e1 * d2[1] - e2 * d1[1]) / det
        Bv = (e2 * d1[0] - e1 * d2[0]) / det
        Nf = np.cross(e1, e2)
        Nf /= max(np.linalg.norm(Nf), 1e-12)
        T = T - Nf * T.dot(Nf)
        T /= max(np.linalg.norm(T), 1e-12)
        Bv = np.cross(Nf, T) * (1 if np.cross(Nf, T).dot(Bv) >= 0 else -1)
        x0, y0 = np.floor(P.min(0)).astype(int)
        x1, y1 = np.ceil(P.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        dd = (P[1, 1] - P[2, 1]) * (P[0, 0] - P[2, 0]) + (P[2, 0] - P[1, 0]) * (P[0, 1] - P[2, 1])
        if abs(dd) < 1e-12:
            continue
        l0 = ((P[1, 1] - P[2, 1]) * (xs - P[2, 0]) + (P[2, 0] - P[1, 0]) * (ys - P[2, 1])) / dd
        l1 = ((P[2, 1] - P[0, 1]) * (xs - P[2, 0]) + (P[0, 0] - P[2, 0]) * (ys - P[2, 1])) / dd
        l2 = 1 - l0 - l1
        ins = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not ins.any():
            continue
        L = np.c_[l0[ins], l1[ins], l2[ins]]
        pts.append(L @ X)
        tbn.append(np.repeat(np.array([T, Bv, Nf])[None], len(L), 0))
        pix.append(np.c_[xs[ins].astype(int), ys[ins].astype(int)])
    pts = np.concatenate(pts)
    tbn = np.concatenate(tbn)
    pix = np.concatenate(pix)
    idx, bary = src.query(pts, ray)
    col, rough, metal, nor = src.sample(idx, bary)
    C = np.zeros((size, size, 3))
    R = np.full((size, size), 0.5)
    Mt = np.zeros((size, size))
    N = np.zeros((size, size, 3))
    N[:, :] = (0.5, 0.5, 1.0)
    filled = np.zeros((size, size), bool)
    rows = size - 1 - pix[:, 1]
    cols = pix[:, 0]
    ok = idx >= 0
    C[rows[ok], cols[ok]] = col[ok]
    R[rows[ok], cols[ok]] = rough[ok]
    Mt[rows[ok], cols[ok]] = metal[ok]
    if relief:
        nt = np.einsum("nij,nj->ni", tbn[ok], nor[ok])          # world normal in the new surface's tangent frame
        nt[:, 2] = np.maximum(nt[:, 2], 0.25)
        nt /= np.linalg.norm(nt, axis=1, keepdims=True)
        N[rows[ok], cols[ok]] = nt * 0.5 + 0.5
    filled[rows[ok], cols[ok]] = True
    covered = np.zeros((size, size), bool)
    covered[rows, cols] = True
    outs = [C, R[..., None].repeat(3, 2), Mt[..., None].repeat(3, 2), N]
    it = 0
    while it < pad or ((covered & ~filled).any() and it < 4 * size):   # bleed past the island edges; strict-ray holes
        it += 1
        acc = [np.zeros_like(o) for o in outs]
        cnt = np.zeros((size, size))
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sf = np.roll(np.roll(filled, dy, 0), dx, 1)
            cnt += sf
            for a_, o in zip(acc, outs):
                a_ += np.roll(np.roll(o, dy, 0), dx, 1) * sf[..., None]
        nw = (~filled) & (cnt > 0)
        for a_, o in zip(acc, outs):
            o[nw] = a_[nw] / cnt[nw][:, None]
        filled |= nw
    C, R3, M3, N = outs
    MR = np.zeros((size, size, 3))
    MR[..., 1] = R3[..., 0]
    MR[..., 2] = M3[..., 0]
    return {"C": C, "R": R3, "M": M3, "N": N, "MR": MR, "hit": float(ok.mean())}


def _shift_min(m, k):
    out = m.copy()
    for _ in range(k):
        o2 = out.copy()
        o2[1:] &= out[:-1]
        o2[:-1] &= out[1:]
        o2[:, 1:] &= out[:, :-1]
        o2[:, :-1] &= out[:, 1:]
        out = o2
    return out


def _shift_max(m, k):
    out = m.copy()
    for _ in range(k):
        o2 = out.copy()
        o2[1:] |= out[:-1]
        o2[:-1] |= out[1:]
        o2[:, 1:] |= out[:, :-1]
        o2[:, :-1] |= out[:, 1:]
        out = o2
    return out


def clean_thin_gold(maps, k=6, vert=24):
    """Tripo paints gold drips / shards across planks: gold texels thinner than ~2k px (gone after an opening by k) are
    filled with the plank colour around them (a tall box average of the non-gold texels: planks run up and down);
    compact gold (hinge plates, studs) stays. Returns the number of texels changed."""
    import colorsys as _cs
    C = maps["C"]
    mx = C.max(2)
    mn = C.min(2)
    s = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    # hue of the max channel order: gold = r >= g > b
    r, g, b = C[..., 0], C[..., 1], C[..., 2]
    gold = (r >= g) & (g > b) & (s > 0.45) & (mx > 0.6) & ((g - b) > 0.35 * (r - b))
    opened = _shift_max(_shift_min(gold, k), k)
    thin = gold & ~opened
    if not thin.any():
        return 0
    good = (~gold).astype(float)

    def boxv(a):                                    # vertical box sum over 2 * vert + 1 rows, 3 columns
        c = np.cumsum(np.pad(a, ((vert + 1, vert), (0, 0)) + ((0, 0),) * (a.ndim - 2), mode="edge"), 0)
        v = c[2 * vert + 1:] - c[:-2 * vert - 1]
        return v + np.roll(v, 1, 1) + np.roll(v, -1, 1)

    wsum = boxv(good)
    for key in ("C", "R", "M", "N"):
        a = maps[key]
        bg = boxv(a * good[..., None]) / np.maximum(wsum, 1e-6)[..., None]
        a[thin] = bg[thin]
    maps["N"][thin] = (0.5, 0.5, 1.0)
    maps["MR"][..., 1] = maps["R"][..., 0]
    maps["MR"][..., 2] = maps["M"][..., 0]
    return int(thin.sum())


def clean_hues(maps, ranges, s_min=0.1, grow=2, vert=24):
    """texels whose hue (deg) is in one of ranges (and saturation > s_min) are things painted over the planks in Tripo's
    texture (a cauldron's green sparkles): grown by `grow` texels and filled with the plank colour around them (tall box
    average of the other texels). Returns the number of texels changed."""
    C = maps["C"]
    mx, mn = C.max(2), C.min(2)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = C[..., 0], C[..., 1], C[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    bad = np.zeros(sat.shape, bool)
    for h0, h1 in ranges:
        bad |= (h >= h0) & (h <= h1) & (sat > s_min)
    bad = _shift_max(bad, grow)
    if not bad.any():
        return 0
    good = (~bad).astype(float)

    def boxv(a):
        c = np.cumsum(np.pad(a, ((vert + 1, vert), (0, 0)) + ((0, 0),) * (a.ndim - 2), mode="edge"), 0)
        v = c[2 * vert + 1:] - c[:-2 * vert - 1]
        return v + np.roll(v, 2, 1) + np.roll(v, -2, 1) + np.roll(v, 1, 1) + np.roll(v, -1, 1)

    wsum = boxv(good)
    for key in ("C", "R", "M", "N"):
        a = maps[key]
        bg = boxv(a * good[..., None]) / np.maximum(wsum, 1e-6)[..., None]
        a[bad] = bg[bad]
    maps["N"][bad] = (0.5, 0.5, 1.0)
    maps["MR"][..., 1] = maps["R"][..., 0]
    maps["MR"][..., 2] = maps["M"][..., 0]
    return int(bad.sum())


def save_maps(maps, work, name):
    """write <work>/<name>_{C,N,R,M,MR}.png and return a glTF-ready material using them"""
    os.makedirs(work, exist_ok=True)
    made = {}
    for tag in ("C", "N", "R", "M", "MR"):
        arr = maps[tag]
        size = arr.shape[0]
        srgb = tag == "C"
        im = bpy.data.images.new(name + "_" + tag, size, size, alpha=False, is_data=not srgb)
        if not srgb:
            im.colorspace_settings.name = "Non-Color"
        lin = np.where(arr <= 0.04045, arr / 12.92, ((arr + 0.055) / 1.055) ** 2.4) if srgb else arr
        rgba = np.concatenate([lin, np.ones(lin.shape[:2] + (1,))], -1)[::-1]
        im.pixels.foreach_set(rgba.ravel().astype(np.float32))
        im.filepath_raw = os.path.join(work, name + "_" + tag + ".png")
        im.file_format = "PNG"
        im.save()
        made[tag] = im
    m = bpy.data.materials.new(name)
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
    return m


def lathe(profile, seg=32, name="Lathe"):
    """surface of revolution about +Z from profile [(r, z), ...] (bottom -> top; r ~ 0 at the end = a pole); UV u = angle,
    v = arc length; the bottom ring is closed by a flat disk"""
    import bmesh
    pr = [(max(r, 0.0), z) for r, z in profile]
    arc = [0.0]
    for (r0, z0), (r1, z1) in zip(pr, pr[1:]):
        arc.append(arc[-1] + math.hypot(r1 - r0, z1 - z0))
    tot = max(arc[-1], 1e-9)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rings = []
    for r, z in pr:
        if r < 1e-4:
            rings.append([bm.verts.new((0.0, 0.0, z))] * seg)
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])

    def uvset(f, us, vs):
        for lp, u, v in zip(f.loops, us, vs):
            lp[uvl].uv = (0.01 + 0.98 * u, 0.01 + 0.98 * v * 0.92)

    for j in range(len(pr) - 1):
        v0, v1 = arc[j] / tot, arc[j + 1] / tot
        for i in range(seg):
            a, b = rings[j][i], rings[j][(i + 1) % seg]
            c, d = rings[j + 1][(i + 1) % seg], rings[j + 1][i]
            u0, u1 = i / seg, (i + 1) / seg
            if c is d:                                  # pole on top
                f = bm.faces.new((a, b, c))
                uvset(f, [u0, u1, (u0 + u1) / 2], [v0, v0, v1])
            elif a is b:                                # pole at the bottom
                f = bm.faces.new((a, c, d))
                uvset(f, [(u0 + u1) / 2, u1, u0], [v0, v1, v1])
            else:
                f = bm.faces.new((a, b, c, d))
                uvset(f, [u0, u1, u1, u0], [v0, v0, v1, v1])
    if pr[0][0] > 1e-4:                                 # bottom disk (own strip of the UV square, top 6 %)
        ctr = bm.verts.new((0.0, 0.0, pr[0][1]))
        for i in range(seg):
            a, b = rings[0][i], rings[0][(i + 1) % seg]
            f = bm.faces.new((b, a, ctr))
            for lp in f.loops:
                ang = math.atan2(lp.vert.co.y, lp.vert.co.x)
                rr = 0.5 * math.hypot(lp.vert.co.x, lp.vert.co.y) / max(pr[0][0], 1e-6)
                lp[uvl].uv = (0.5 + 0.03 * rr * math.cos(ang) * 2, 0.965 + 0.03 * rr * math.sin(ang))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.shade_smooth()
    return o
