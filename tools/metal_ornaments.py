"""Exact round / straight metal ornaments made by script in Blender, not by Tripo (검수 10/11 rule: rings are rings,
symmetric things are symmetric — door knocker rings, hinge straps, lantern frames, window bars, railing post heads).
이미지 생성 3, 10/11.

  blender --background --factory-startup --python tools/metal_ornaments.py -- <spec.json> <out.glb> [--snap <glb> <object>]
          [--render <abs dir>] [--context <glb> ...] [--context-keep <name part> ...]

spec.json: {"items": [ {...}, ... ]} in the house frame (Blender: x, y = front, z up, studs). Item types and their size
arguments (all optional except the position):
  knocker : "pos": [x, z] on the door face; "R" ring radius 0.55, "r" tube radius 0.085, "plate" back plate diameter 0.62
  hinge   : "edge": [x, z] = the door edge the barrel sits on, "dir": +1 / -1 = the way the strap runs, "len" 1.35,
            "h" strap height 0.34, "end" end disk diameter 0.56, "barrel" [diameter 0.24, height 0.85]
  lantern : "pos": [x, y, z] = centre of the glass box, "w" body width 0.9, "hgt" body height 1.15, "wall_y" = the face
            it hangs from (bracket arm from there), "post" 0.09
  arch_window : a dormer / blind arched window with an exact arch, as four objects (<name>_Surround marble, _Frame gold,
            _Glass, _Pane): "pos": [x, y_front, z_bottom], "W" opening width 1.5, "spring" z of the spring line, "pier" 0.45
            marble round the frame, "frame" 0.16 gold width, "depth" 1.6, "recess" 0.25, "yaw" degrees (turned about
            the vertical through pos; the window's front is +y before the turn)
  dome    : gold dome by revolution (exact): "pos": [x, y, z_base], "R", "h", "onion": bool, "ribs" 8 (raised gold ribs),
            base ring + finial
  finial  : gold finial (ball + ring + spike): "pos": [x, y, z_base], "d"
  leaf    : an arched plank door leaf (wood) with an exact arch ("half": -1 / +1 = one leaf of a double door): "c": [x, z] arch centre (spring line), "R" half width,
            "bottom" z, "front" y of the plank faces, "t" thickness 0.32, "planks" 5, "gap" 0.06, "groove" 0.1
Each item becomes one joined mesh object named "Orn_<name>" with one material: "OrnGold" (metal 1, roughness 0.3,
base colour 255,175,25 = HH_HaloGoldTrim's part colour) or, for a leaf, "OrnWood" (176,112,58, roughness 0.75; Studio:
Material Wood). Lantern glass is not made here (a Glass part of the skeleton
fills the frame: LampGlass). --snap: knocker and hinges are put flat on the first surface of <object> in <glb> hit by
a ray from the front (+y) at their position (the Tripo door leaf), so they sit on the planks.
--render: front / side ortho of the door group and of each lantern + a 3/4 close-up, with --context models drawn too.
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("spec")
ap.add_argument("out")
ap.add_argument("--snap", nargs=2)
ap.add_argument("--render")
ap.add_argument("--context", nargs="*", default=[])
ap.add_argument("--context-keep", nargs="*", default=[], help="keep only context objects whose name contains one of these")
a = ap.parse_args(argv)
spec = json.load(open(a.spec))
bpy.ops.wm.read_factory_settings(use_empty=True)


def s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


GOLD = bpy.data.materials.new("OrnGold")
GOLD.use_nodes = True
_b = GOLD.node_tree.nodes["Principled BSDF"]
_b.inputs["Base Color"].default_value = (*[s2l(c / 255) for c in (255, 175, 25)], 1)
_b.inputs["Metallic"].default_value = 1.0
_b.inputs["Roughness"].default_value = 0.3
def flat_mat(name, rgb, metal=0.0, rough=0.5, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[s2l(c / 255) for c in rgb], 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    return m


MARBLE = flat_mat("OrnMarble", (255, 244, 222), 0.0, 0.45)   # Studio: Marble + HH_HaloMarbleBlock_Cream
GLASSM = flat_mat("OrnGlass", (150, 205, 245), 0.0, 0.05, 0.4)   # Studio: Glass, Transparency 0.3
PANE = flat_mat("OrnPane", (120, 175, 225), 0.0, 0.3)        # behind the glass of a blind window
WOOD = bpy.data.materials.new("OrnWood")
WOOD.use_nodes = True
_w = WOOD.node_tree.nodes["Principled BSDF"]
_w.inputs["Base Color"].default_value = (*[s2l(c / 255) for c in (176, 112, 58)], 1)
_w.inputs["Roughness"].default_value = 0.75

# ---------------------------------------------------------------- snapping surface
bvh = None
if a.snap:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=a.snap[0])
    new = [o for o in bpy.data.objects if o not in before]
    tgt = [o for o in new if o.type == "MESH" and o.name.split(".")[0] == a.snap[1]]
    if not tgt:
        sys.exit("[orn] snap object %s not in %s" % (a.snap[1], a.snap[0]))
    bm = bmesh.new()
    for o in tgt:
        me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        me.transform(o.matrix_world)
        bm.from_mesh(me)
    bvh = BVHTree.FromBMesh(bm)
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)


def surface_y(x, z, default):
    """front-most surface y of the snap object at (x, z); default when nothing is hit"""
    if bvh is None:
        return default
    hit = bvh.ray_cast(Vector((x, 50.0, z)), Vector((0.0, -1.0, 0.0)), 100.0)
    return hit[0].y if hit[0] is not None else default


# ---------------------------------------------------------------- primitive helpers (each returns new bmesh geometry)
class Piece:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()

    def _add(self, fn, M, **kw):
        g = fn(self.bm, **kw)
        bmesh.ops.transform(self.bm, matrix=M, verts=g["verts"])

    def box(self, size, centre, rot=Matrix()):
        M = Matrix.Translation(Vector(centre)) @ rot.to_4x4() @ Matrix.Diagonal((*size, 1))
        self._add(bmesh.ops.create_cube, M, size=1.0)

    def cyl(self, d, length, centre, axis="z", seg=20):
        R = {"z": Matrix(), "x": Matrix.Rotation(math.pi / 2, 4, "Y"), "y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        M = Matrix.Translation(Vector(centre)) @ R
        self._add(bmesh.ops.create_cone, M, cap_ends=True, segments=seg, radius1=d / 2, radius2=d / 2, depth=length)

    def cone(self, d0, d1, length, centre, seg=20, axis="z", spin=0.0):
        R = {"z": Matrix(), "y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis] @ Matrix.Rotation(spin, 4, "Z")
        M = Matrix.Translation(Vector(centre)) @ R
        self._add(bmesh.ops.create_cone, M, cap_ends=True, segments=seg, radius1=d0 / 2, radius2=d1 / 2, depth=length)

    def ball(self, d, centre):
        M = Matrix.Translation(Vector(centre))
        self._add(bmesh.ops.create_uvsphere, M, u_segments=12, v_segments=8, radius=d / 2)

    def torus(self, R, r, centre, plane="xz", seg=40, tseg=10, arc=(0.0, 2 * math.pi)):
        """torus (or an arc of one) around the plane's normal; tube made of rings so the circle stays a true circle"""
        a0, a1 = arc
        full = abs(a1 - a0 - 2 * math.pi) < 1e-6
        n = seg if full else max(4, int(seg * (a1 - a0) / (2 * math.pi)))
        rings = []
        for i in range(n + (0 if full else 1)):
            t = a0 + (a1 - a0) * i / n
            c = Vector((math.cos(t) * R, 0.0, math.sin(t) * R))          # ring centre in xz
            out = Vector((math.cos(t), 0.0, math.sin(t)))
            ring = []
            for j in range(tseg):
                u = 2 * math.pi * j / tseg
                p = c + out * (r * math.cos(u)) + Vector((0.0, r * math.sin(u), 0.0))
                ring.append(p)
            rings.append(ring)
        P = {"xz": Matrix(), "yz": Matrix.Rotation(math.pi / 2, 3, "Z"), "xy": Matrix.Rotation(math.pi / 2, 3, "X")}[plane]
        vs = [[self.bm.verts.new(Vector(centre) + P @ p) for p in ring] for ring in rings]
        for i in range(len(vs) - (0 if full else 1)):
            A, B = vs[i], vs[(i + 1) % len(vs)]
            for j in range(tseg):
                self.bm.faces.new((A[j], A[(j + 1) % tseg], B[(j + 1) % tseg], B[j]))
        if not full:
            for ring in (vs[0], vs[-1]):
                self.bm.faces.new(ring if ring is vs[-1] else list(reversed(ring)))

    def prism(self, outline, y_front, depth):
        """flat polygon in the x-z plane (list of (x, z), counter-clockwise seen from the front) from y_front back by depth"""
        fr = [self.bm.verts.new((x, y_front, z)) for x, z in outline]
        bk = [self.bm.verts.new((x, y_front - depth, z)) for x, z in outline]
        self.bm.faces.new(fr)
        self.bm.faces.new(list(reversed(bk)))
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((fr[i], bk[i], bk[j], fr[j]))

    def finish(self, smooth=True, mat=None):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new("Orn_" + self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for f in me.polygons:
            f.use_smooth = smooth
        o = bpy.data.objects.new("Orn_" + self.name, me)
        o.data.materials.append(mat or GOLD)
        bpy.context.scene.collection.objects.link(o)
        try:
            o.data.set_sharp_from_angle(angle=math.radians(40))
        except AttributeError:
            pass
        return o


# ---------------------------------------------------------------- ornaments
def knocker(it):
    x, z = it["pos"]
    R, r, plate = it.get("R", 0.55), it.get("r", 0.085), it.get("plate", 0.62)
    top = z + R                                   # the ring hangs from the plate centre
    y0 = surface_y(x, top, it.get("face_y", 0.0))
    p = Piece(it.get("name", "Knocker"))
    p.cyl(plate, 0.08, (x, y0 + 0.04, top), "y", 28)                       # round back plate
    p.cyl(plate * 0.72, 0.05, (x, y0 + 0.1, top), "y", 28)                  # raised step
    p.ball(0.26, (x, y0 + 0.16, top))                                       # boss
    p.cyl(0.11, 0.42, (x, y0 + 0.2, top), "x", 16)                          # pin the ring hangs on
    yc = y0 + 0.2
    p.torus(R, r, (x, yc, z), "xz")                                         # the ring: a true circle, even tube
    zb = z - R                                                             # strike plate where the ring knocks
    yb = surface_y(x, zb, y0)
    p.cyl(0.3, 0.06, (x, yb + 0.03, zb), "y", 32)
    p.ball(0.14, (x, yb + 0.07, zb))
    return p.finish()


def hinge(it):
    ex, z = it["edge"]
    sg = it.get("dir", 1)
    L, h, endd = it.get("len", 1.35), it.get("h", 0.34), it.get("end", 0.56)
    bd, bh = it.get("barrel", [0.24, 0.85])
    t = 0.07
    p = Piece(it.get("name", "Hinge"))
    xs = [ex + sg * (L * k / 8) for k in range(9)]
    y0 = max(surface_y(xx, z, it.get("face_y", 0.0)) for xx in xs)          # flat strap on the highest plank
    p.box((L, t, h), (ex + sg * L / 2, y0 + t / 2, z))                     # strap
    p.box((L * 0.55, t * 0.6, h * 0.45), (ex + sg * L * 0.3, y0 + t + t * 0.3, z))   # raised rib
    xe = ex + sg * L
    p.cyl(endd, t, (xe, y0 + t / 2, z), "y", 28)                            # round end
    tip = [(xe + sg * endd * 0.3, z + endd * 0.42), (xe + sg * endd * 1.05, z), (xe + sg * endd * 0.3, z - endd * 0.42)]
    p.prism(tip if sg < 0 else list(reversed(tip)), y0 + t, t)               # flat spear tip, same plane as the strap
    for k, f in enumerate((0.2, 0.55)):                                     # rivets
        p.ball(0.11, (ex + sg * L * f, y0 + t + 0.02, z))
    p.ball(0.12, (xe, y0 + t + 0.02, z))
    p.cyl(bd, bh, (ex, y0 + bd * 0.35, z), "z", 24)                         # barrel (knuckle) on the edge
    for dz in (-1, 1):
        p.ball(bd * 0.9, (ex, y0 + bd * 0.35, z + dz * bh / 2))
    return p.finish()


def lantern(it):
    x, y, z = it["pos"]
    w, H, post = it.get("w", 0.9), it.get("hgt", 1.15), it.get("post", 0.09)
    wall_y = it.get("wall_y", y - w / 2 - 0.3)
    p = Piece(it.get("name", "Lantern"))
    z0, z1 = z - H / 2, z + H / 2
    for sx in (-1, 1):                                                      # four posts
        for sy in (-1, 1):
            p.box((post, post, H), (x + sx * (w / 2 - post / 2), y + sy * (w / 2 - post / 2), z))
    for zz in (z0 + 0.03, z1 - 0.03):                                       # rails round the glass
        for sy in (-1, 1):
            p.box((w, post * 0.8, post * 0.8), (x, y + sy * (w / 2 - post / 2), zz))
        for sx in (-1, 1):
            p.box((post * 0.8, w, post * 0.8), (x + sx * (w / 2 - post / 2), y, zz))
    p.box((w + 0.22, w + 0.22, 0.12), (x, y, z0 - 0.06))                   # base plate
    p.cone((w + 0.1) * 1.414, 0.2, 0.34, (x, y, z0 - 0.12 - 0.17), 4, "z", math.pi / 4)   # base taper
    p.ball(0.18, (x, y, z0 - 0.12 - 0.34 - 0.06))                          # drop
    p.box((w + 0.26, w + 0.26, 0.12), (x, y, z1 + 0.06))                   # top plate
    p.cone((w + 0.3) * 1.414, 0.06, 0.55, (x, y, z1 + 0.12 + 0.275), 4, "z", math.pi / 4)  # roof
    p.ball(0.2, (x, y, z1 + 0.12 + 0.55 + 0.06))                           # finial
    p.cone(0.1, 0.0, 0.2, (x, y, z1 + 0.12 + 0.55 + 0.25), 16)
    ztop = z1 + 0.12 + 0.55 + 0.42                                         # bracket arm over the finial
    p.cyl(0.4, 0.06, (x, wall_y + 0.03, ztop - 0.25), "y", 32)             # wall plate
    p.box((0.1, y - wall_y, 0.1), (x, (wall_y + y) / 2, ztop))             # arm
    p.cyl(0.05, ztop - (z1 + 0.12 + 0.55 + 0.3), (x, y, (ztop + z1 + 0.12 + 0.55 + 0.3) / 2), "z", 12)   # hanger
    rr = (y - wall_y) * 0.42                                               # scroll under the arm
    p.torus(rr, 0.035, (x, wall_y + rr, ztop - rr), "yz", 40, 10, (math.pi, 1.5 * math.pi))
    p.ball(0.12, (x, y, ztop))
    return p.finish()


def leaf(it):
    xc, zs = it["c"]
    R, zb, yf = it["R"], it["bottom"], it["front"]
    t, n, gap, groove = it.get("t", 0.32), it.get("planks", 5), it.get("gap", 0.06), it.get("groove", 0.1)
    p = Piece(it.get("name", "Leaf"))

    def arc_z(x):
        return zs + math.sqrt(max(R * R - (x - xc) ** 2, 0.0))

    def outline(x0, x1, inset=0.0):
        pts = [(x0, zb), (x1, zb)]
        K = max(3, int(24 * (x1 - x0) / (2 * R)) + 2)
        for k in range(K + 1):                      # top edge along the arch, right to left
            x = x1 - (x1 - x0) * k / K
            pts.append((x, arc_z(x) - inset))
        return pts

    half = it.get("half")
    xa, xb = (xc - R, xc + R) if not half else ((xc, xc + R - 0.02) if half > 0 else (xc - R + 0.02, xc))
    if half:
        xa, xb = (xa + 0.025, xb) if half > 0 else (xa, xb - 0.025)        # a thin gap between the two leaves
        n = max(2, n // 2)
    p.prism(outline(xa, xb), yf - groove, t - groove)                      # back board
    w = (xb - xa) / n
    for i in range(n):                                                  # planks with grooves between them
        x0, x1 = xa + w * i + gap / 2, xa + w * (i + 1) - gap / 2
        p.prism(outline(x0, x1, gap / 2), yf, groove + 0.01)
    return p.finish(smooth=False, mat=WOOD)


def arch_window(it):
    px, py, zb = it["pos"]
    yaw = it.get("yaw")
    x, yf = (0.0, 0.0) if yaw is not None else (px, py)
    W, zs = it.get("W", 1.5), it["spring"]
    pier, fr, depth, rec = it.get("pier", 0.45), it.get("frame", 0.16), it.get("depth", 1.6), it.get("recess", 0.25)
    R = W / 2
    Ri, Ro = R + fr, R + fr + pier
    nm = it.get("name", "ArchWin")

    def arch(r, z_from=zb, k=40):
        return [(x - r, z_from), (x + r, z_from)] + [(x + r * math.cos(math.pi * i / k), zs + r * math.sin(math.pi * i / k)) for i in range(k + 1)]

    def ring(r0, r1, k=40):
        return ([(x + r1 * math.cos(math.pi * i / k), zs + r1 * math.sin(math.pi * i / k)) for i in range(k + 1)]
                + [(x + r0 * math.cos(math.pi * (k - i) / k), zs + r0 * math.sin(math.pi * (k - i) / k)) for i in range(k + 1)])

    sur = Piece(nm + "_Surround")
    sur.prism(arch(Ro), yf - rec, depth - rec)                                   # back block, full outline
    for sx in (-1, 1):                                                            # piers either side of the opening
        a0, a1 = sorted((x + sx * Ri, x + sx * Ro))
        sur.prism([(a0, zb), (a1, zb), (a1, zs), (a0, zs)], yf, rec + 0.01)
    sur.prism(ring(Ri, Ro), yf, rec + 0.01)                                       # arch band (exact half ring)
    sur.prism([(x - Ri, zb), (x + Ri, zb), (x + Ri, zb + 0.2), (x - Ri, zb + 0.2)], yf, rec + 0.01)   # sill stone
    out = [sur.finish(smooth=False, mat=MARBLE)]
    frm = Piece(nm + "_Frame")
    frm.prism(ring(R, Ri), yf + 0.05, rec + 0.05)                                 # gold arch frame
    for sx in (-1, 1):
        a0, a1 = sorted((x + sx * R, x + sx * Ri))
        frm.prism([(a0, zb + 0.2), (a1, zb + 0.2), (a1, zs), (a0, zs)], yf + 0.05, rec + 0.05)
    frm.prism([(x - Ri - 0.08, zb + 0.08), (x + Ri + 0.08, zb + 0.08), (x + Ri + 0.08, zb + 0.24), (x - Ri - 0.08, zb + 0.24)],
              yf + 0.12, rec + 0.12)                                              # gold sill
    frm.box((0.07, 0.06, zs + R - zb - 0.2), (x, yf - rec + 0.16, (zb + 0.2 + zs + R) / 2))   # mullion
    frm.box((W, 0.06, 0.07), (x, yf - rec + 0.16, zs))                           # transom
    frm.box((0.3, rec + 0.2, 0.36), (x, yf - rec / 2 + 0.1, zs + Ro - 0.12))     # keystone
    out.append(frm.finish(smooth=False))
    gl = Piece(nm + "_Glass")
    gl.prism(arch(R, zb + 0.2), yf - rec + 0.12, 0.03)
    out.append(gl.finish(smooth=False, mat=GLASSM))
    pn = Piece(nm + "_Pane")
    pn.prism(arch(R, zb + 0.2), yf - rec + 0.02, 0.02)
    out.append(pn.finish(smooth=False, mat=PANE))
    if yaw is not None:
        M = Matrix.Translation((px, py, 0.0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
        for o in out:
            o.data.transform(M)
    return out


def revolve(p, prof, centre, seg=48):
    """surface of revolution of a (r, z) profile (bottom to top) about the vertical through centre"""
    cx, cy, cz = centre
    rings = []
    for r, z in prof:
        rings.append([p.bm.verts.new((cx + r * math.cos(2 * math.pi * k / seg), cy + r * math.sin(2 * math.pi * k / seg), cz + z))
                      for k in range(seg)])
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        for k in range(seg):
            p.bm.faces.new((A[k], A[(k + 1) % seg], B[(k + 1) % seg], B[k]))
    p.bm.faces.new(list(reversed(rings[0])))


def dome(it):
    x, y, z = it["pos"]
    R, H, onion, nrib = it["R"], it.get("h", it["R"]), it.get("onion", False), it.get("ribs", 8)
    K = 24
    prof = []
    for i in range(K + 1):
        s_ = i / K
        if onion:
            r = R * (1 + 0.16 * math.sin(math.pi * min(1.0, s_ * 1.3))) * math.sqrt(max(0.0, 1 - s_ ** 1.7))
        else:
            r = R * math.cos(s_ * math.pi / 2)
        zz = H * (s_ if onion else math.sin(s_ * math.pi / 2))
        prof.append((max(r, 0.02), zz))
    p = Piece(it.get("name", "Dome"))
    revolve(p, prof, (x, y, z))
    for j in range(nrib):                                   # raised ribs following the profile
        t = 2 * math.pi * j / nrib + math.pi / nrib
        d = Vector((math.cos(t), math.sin(t), 0.0))
        side = Vector((-d.y, d.x, 0.0)) * 0.13
        strip = []
        for r, zz in prof[:-2]:
            c = Vector((x, y, z)) + d * (r - 0.02) + Vector((0, 0, zz))
            out = d * 0.16
            strip.append([p.bm.verts.new(c - side), p.bm.verts.new(c + side), p.bm.verts.new(c + side + out), p.bm.verts.new(c - side + out)])
        for i in range(len(strip) - 1):
            A, B = strip[i], strip[i + 1]
            for k in range(4):
                p.bm.faces.new((A[k], A[(k + 1) % 4], B[(k + 1) % 4], B[k]))
    p.torus(R + 0.06, 0.16, (x, y, z + 0.1), "xy", 64, 10)   # base ring
    zt = z + H
    p.cyl(0.7, 0.3, (x, y, zt + 0.1), "z", 24)
    p.ball(0.62, (x, y, zt + 0.55))
    p.torus(0.22, 0.06, (x, y, zt + 0.92), "xy", 24, 8)
    p.cone(0.3, 0.0, 0.9, (x, y, zt + 1.4), 16)
    p.ball(0.22, (x, y, zt + 1.05))
    return p.finish()


def finial(it):
    x, y, z = it["pos"]
    d = it.get("d", 0.5)
    p = Piece(it.get("name", "Finial"))
    p.ball(d, (x, y, z + d / 2))
    p.torus(d * 0.35, d * 0.08, (x, y, z + d * 1.02), "xy", 24, 8)
    p.cone(d * 0.5, 0.0, d * 1.4, (x, y, z + d * 1.7), 16)
    return p.finish()


MAKE = {"knocker": knocker, "hinge": hinge, "lantern": lantern, "leaf": leaf, "arch_window": arch_window, "dome": dome,
        "finial": finial}
made = []
for it in spec["items"]:
    r = MAKE[it["type"]](it)
    made += r if isinstance(r, list) else [r]
for o in made:
    me = o.data
    me.calc_loop_triangles()
    co = [o.matrix_world @ v.co for v in me.vertices]
    print("[orn] %-18s tris %5d  x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % (o.name, len(me.loop_triangles),
          min(c.x for c in co), max(c.x for c in co), min(c.y for c in co), max(c.y for c in co), min(c.z for c in co), max(c.z for c in co)), flush=True)
bpy.ops.object.select_all(action="DESELECT")
for o in made:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False)
print("[orn] ok %d objects -> %s" % (len(made), a.out), flush=True)

# ---------------------------------------------------------------- renders
if a.render:
    os.makedirs(a.render, exist_ok=True)
    for g in a.context:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=g)
        for o in [o for o in bpy.data.objects if o not in before]:
            if a.context_keep and o.type == "MESH" and not any(k in o.name for k in a.context_keep):
                bpy.data.objects.remove(o, do_unlink=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 1200
    w = bpy.data.worlds.new("w")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(52), 0, math.radians(205))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    def shot(name, loc, look, ortho=None, lens=50):
        cam.data.type = "ORTHO" if ortho else "PERSP"
        if ortho:
            cam.data.ortho_scale = ortho
        else:
            cam.data.lens = lens
        cam.location = loc
        cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(a.render, name + ".png")
        bpy.ops.render.render(write_still=True)

    for nm, (loc, look, ortho, lens) in spec.get("shots", {}).items():
        shot(nm, tuple(loc), tuple(look), ortho, lens or 50)
    print("[orn] renders ->", a.render, flush=True)
