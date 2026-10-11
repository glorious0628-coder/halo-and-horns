"""Studio part generator for the Halo town props (이미지 생성 4, 10/11, SPEC A23-120 / A23-125, split table
docs/design/halo_props_split_2026-10-11.md: (가) = all parts, (가+나) = part body + Tripo plant).

  py tools/prop_kit.py [KIT ...] [--all] [--apply] [--marble plain|block] [--list]

Every kit is a list of Roblox parts built in the Blender frame of tools/skeleton_house.py (x, y = front, z up,
studs, origin = ground centre; the kit looks along +y = Roblox LookVector, so halo_props_place.py can PivotTo it with
CFrame.lookAt). Someone looking at the front sees +x on their LEFT (2D "right" side = -x; mirror=True flips a kit).
Round things are Roblox Cylinder / Ball parts (exact circles); arches, rings and bowls are CSG
(GeometryService SubtractAsync / IntersectAsync, done in Studio at build time).

Writes build/prop_kit/<Kit>.json (parts, for tools/prop_kit_preview.py) and build/prop_kit/<Kit>.luau. --apply runs
the Luau in WorldKit (STUDIO_NAME=WorldKit, Edit): ServerStorage.HaloPropKits.<Kit> (Model, WorldPivot = ground centre,
attributes PropKit / Maker / Height). tools/worldkit/halo_props_place.py clones these by kit name.

Materials (이미지 개발 values): gold = Metal + HH_HaloGoldTrim (255,168,36); marble = Marble + HH_HaloMarbleSmooth_Cream + cream
(255,244,222) (default --marble smooth, 10/11; plain
(no variant: the 2D props are smooth marble, the 1.5-stud block joints of HH_HaloMarbleBlock_Cream read as bricks on a
bench leg) or --marble block; "mblock" = always HH_HaloMarbleBlock_Cream (tiled floors / walls that show joints in the
2D); cloth = Fabric + HH_Fabric; lamp glass = Glass + LampLight attribute + disabled PointLight (WeatherFx lights it).
"""
import argparse
import json
import math
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, "build", "prop_kit")
UP = (0.0, 0.0, 1.0)
EX = (1.0, 0.0, 0.0)
EY = (0.0, 1.0, 0.0)

# colours (RGB 0-255) per material key; a part may override with its own colour
COL = {
    "marble": (255, 244, 222), "mblock": (255, 244, 222), "gold": (255, 168, 36), "wood": (222, 166, 96),
    "woodcream": (240, 228, 206), "wooddk": (150, 98, 58), "blue": (118, 178, 236), "cloth": (250, 247, 240),
    "glass": (170, 215, 245), "lamp": (255, 228, 160), "neon": (255, 205, 120), "slate": (126, 172, 230),
    "rope": (232, 214, 170), "leaf": (120, 186, 70), "soil": (140, 100, 62), "iron": (58, 58, 64),
    "candle": (250, 246, 236), "paint": (255, 255, 255), "stone": (242, 236, 222), "dark": (70, 52, 40),
    "water": (120, 200, 235),
    # 디자인 검수 10/11: painted cream wood = smooth cream (Wood grain read as grey marble swirl) + thin seam parts
    "pcream": (242, 233, 214), "groove": (212, 198, 176), "ironblue": (92, 94, 102),
}

KITS = {}          # name -> builder
META = {}          # name -> dict(h, ref, note)
P = []             # parts of the kit being built


def kit(name, h, ref, note="", mirror=False):
    """mirror: the builder was written with the 2D front's right on +x; flip x after building."""
    def deco(fn):
        KITS[name] = fn
        META[name] = dict(h=h, ref=ref, note=note, mirror=mirror)
        return fn
    return deco


def mirror_x(t):
    """Mirror one part (and its CSG parts) in x. Boxes, cylinders and balls are symmetric, so only the position and the
    axis directions change (no wedges in mirrored kits)."""
    assert t["s"] != "Wedge", "mirror_x: wedge " + t["n"]
    t["p"][0] = -t["p"][0]
    t["X"][0] = -t["X"][0]
    t["Y"][0] = -t["Y"][0]
    for _, lst in t.get("ops", []):
        for c in lst:
            mirror_x(c)


# ---------------------------------------------------------------- vector helpers
def vadd(*vs):
    return tuple(sum(c) for c in zip(*vs))


def vsub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def vmul(v, s):
    return tuple(c * s for c in v)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(v):
    L = math.sqrt(dot(v, v))
    return tuple(c / L for c in v)


def perp(a):
    """A unit vector at right angles to a (as close to UP as possible, else to +x)."""
    ref = UP if abs(a[2]) < 0.9 else EX
    return norm(vsub(ref, vmul(a, dot(a, ref))))


def hdir(deg):
    """Horizontal unit vector: 0 = front (+y), 90 = +x."""
    r = math.radians(deg)
    return (math.sin(r), math.cos(r), 0.0)


def rotz(v, deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])


# ---------------------------------------------------------------- part makers (Blender frame)
def part(n, shape, size, pos, X=EX, Y=UP, m="marble", c=None, cc=None, ops=None):
    """size = Roblox local (X, Y, Z = X x Y). ops = [("minus"|"and", [part dicts made with keep=False])]."""
    d = dict(n=n, s=shape, size=[round(v, 4) for v in size], p=[round(v, 4) for v in pos], X=[round(v, 5) for v in norm(X)],
             Y=[round(v, 5) for v in norm(Y)], m=m, c=list(c) if c else None, cc=cc)
    if ops:
        d["ops"] = [[k, lst] for k, lst in ops]
    P.append(d)
    return d


def cut(fn, *args, **kw):
    """Make a cutter / intersect shape: the same makers, but not kept in the kit."""
    d = fn(*args, **kw)
    P.remove(d)
    return d


def box(n, w, d, h, x=0.0, y=0.0, z=0.0, m="marble", rot=0.0, **kw):
    """Axis box, z = bottom, rot = degrees about the vertical (w along x before the turn)."""
    return part(n, "Block", (w, h, d), (x, y, z + h / 2), rotz(EX, rot), UP, m, **kw)


def boxc(n, w, d, h, pos, X=EX, Y=UP, m="marble", **kw):
    """Box by centre and axes: w along X, h along Y, d along X x Y."""
    return part(n, "Block", (w, h, d), pos, X, Y, m, **kw)


def cyl(n, dia, h, x=0.0, y=0.0, z=0.0, m="marble", **kw):
    """Upright cylinder, z = bottom."""
    return part(n, "Cylinder", (h, dia, dia), (x, y, z + h / 2), UP, EX, m, **kw)


def rod(n, p0, p1, dia, m="gold", shape="Cylinder", **kw):
    a = vsub(p1, p0)
    L = math.sqrt(dot(a, a))
    ax = norm(a)
    return part(n, shape, (L, dia, dia), vmul(vadd(p0, p1), 0.5), ax, perp(ax), m, **kw)


def ball(n, dia, x, y, z, m="gold", **kw):
    """z = centre."""
    return part(n, "Ball", (dia, dia, dia), (x, y, z), EX, UP, m, **kw)


def wedge(n, length, rise, run, x, y, z, face, m="marble", **kw):
    """Triangular prism: bottom at z, high side away from `face` (horizontal unit vector the slope looks to)."""
    Z = vmul(norm(face), -1.0)
    X = cross(UP, Z)
    return part(n, "Wedge", (length, rise, run), (x, y, z + rise / 2), X, UP, m, **kw)


def ring(n, d_out, d_in, h, x, y, z, m="gold", axis=UP, **kw):
    """Exact ring (CSG): cylinder d_out minus d_in, axis through (x, y, z) = centre, h along the axis."""
    Y = perp(axis)
    hole = cut(part, n + "_hole", "Cylinder", (h + 0.2, d_in, d_in), (x, y, z), axis, Y, m)
    return part(n, "Cylinder", (h, d_out, d_out), (x, y, z), axis, Y, m, ops=[("minus", [hole])], **kw)


def face_axes(nrm):
    """Axes for a flat thing on a vertical face with outward normal nrm: X along the face, Y up, X x Y = -nrm."""
    nrm = norm(nrm)
    return vmul(cross(UP, nrm), -1.0), UP


def plate(n, w, h, t, centre, nrm, m="blue", rot=0.0, **kw):
    """Flat plate on a vertical face: centre on the face, out along nrm by t / 2; rot = degrees in the face plane."""
    X, Y = face_axes(nrm)
    if rot:
        r = math.radians(rot)
        X, Y = (vadd(vmul(X, math.cos(r)), vmul(Y, math.sin(r))), vadd(vmul(X, -math.sin(r)), vmul(Y, math.cos(r))))
    return part(n, "Block", (w, h, t), vadd(centre, vmul(norm(nrm), t / 2)), X, Y, m, cc=False, **kw)


def inlay(n, centre, nrm, w, h, kind="rect", fr=0.07, t=0.04):
    """Blue window with a gold border on a face: rect / arch (pointed top) / hex (pointed top and bottom)."""
    nrm = norm(nrm)
    plate(n + "_G", w + 2 * fr, h + 2 * fr, t, centre, nrm, "gold")
    plate(n + "_B", w, h, t, vadd(centre, vmul(nrm, 0.02)), nrm, "blue")
    if kind in ("arch", "hex"):
        s = (w + 2 * fr) / math.sqrt(2)
        for k, sgn in ((("T", 1),) if kind == "arch" else (("T", 1), ("D", -1))):
            c = vadd(centre, (0.0, 0.0, sgn * h / 2))
            plate(n + "_G" + k, s, s, t - 0.005, vadd(c, vmul(nrm, 0.002)), nrm, "gold", rot=45)
            sb = w / math.sqrt(2)
            plate(n + "_B" + k, sb, sb, t, vadd(c, vmul(nrm, 0.022)), nrm, "blue", rot=45)


def seam(n, centre, nrm, length, vertical=False, w=0.03):
    """Thin plank seam on a painted face (darker cream strip, sticks out 0.012)."""
    return plate(n, w if vertical else length, length if vertical else w, 0.012, centre, nrm, "groove")


def chamfer_slab(n, w, h, t, centre, ch, m="marble", keep=True, **kw):
    """Flat slab in the x-z plane (thickness along y) with its four corners cut at 45 deg (long octagon)."""
    r = math.sqrt(0.5)
    cuts = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            cuts.append(cut(part, "%s_c%d%d" % (n, sx, sz), "Block", (ch * 2 * r, ch * 2 * r, t + 0.2),
                            vadd(centre, (sx * w / 2, 0.0, sz * h / 2)), (r, 0.0, r), (-r, 0.0, r), m))
    d = part(n, "Block", (w, h, t), centre, EX, UP, m, ops=[("minus", cuts)], **kw)
    if not keep:
        P.remove(d)
    return d


def gold_ball(n, dia, x, y, z0, neck=True):
    """Gold ball finial standing on z0 (small collar under it)."""
    if neck:
        cyl(n + "_Neck", dia * 0.55, 0.12, x, y, z0, "gold", cc=False)
        z0 += 0.1
    ball(n, dia, x, y, z0 + dia / 2, "gold", cc=False)
    return z0 + dia


def spike(n, x, y, z0, h, dia=0.22):
    """Small gold spike: thin cylinder + ball tip (finial point)."""
    cyl(n, dia * 0.5, h * 0.75, x, y, z0, "gold", cc=False)
    ball(n + "_Tip", dia * 0.75, x, y, z0 + h * 0.75, "gold", cc=False)
    # diamond point above (two crossed square bars turned 45 deg about their own axis)
    s = dia * 0.6
    boxc(n + "_PtA", s, s * 0.5, s, (x, y, z0 + h * 0.75 + dia * 0.5), norm((1, 0, 1)), norm((-1, 0, 1)), "gold", cc=False)
    boxc(n + "_PtB", s, s * 0.5, s, (x, y, z0 + h * 0.75 + dia * 0.5), norm((0, 1, 1)), norm((0, -1, 1)), "gold", cc=False)


def onion(n, dia, x, y, z0, tip=0.5):
    """Gold onion dome finial: ball + collar + spike."""
    cyl(n + "_Base", dia * 0.75, 0.14, x, y, z0, "gold")
    ball(n, dia, x, y, z0 + 0.1 + dia * 0.45, "gold", cc=False)
    spike(n + "_Spk", x, y, z0 + 0.1 + dia * 0.9, tip, dia * 0.22)


def pedestal(n, w, d, h, x, y, z0=0.0, band=True, plinth=0.2):
    """Marble block with a wider plinth and a gold band on it (2D motif of benches, posts, lamps)."""
    box(n + "_Plinth", w + 0.22, d + 0.22, plinth, x, y, z0, "marble")
    if band:
        box(n + "_Band", w + 0.08, d + 0.08, 0.1, x, y, z0 + plinth, "gold")
    box(n, w, d, h - plinth - (0.1 if band else 0), x, y, z0 + plinth + (0.1 if band else 0), "marble")
    return z0 + h


def cap(n, w, d, x, y, z0, t=0.18, gold=True):
    if gold:
        box(n + "_Gold", w + 0.06, d + 0.06, 0.08, x, y, z0, "gold")
        z0 += 0.08
    box(n, w + 0.16, d + 0.16, t, x, y, z0, "marble")
    return z0 + t


def gable_roof(n, span, depth, rise, x, y, z0, ridge="y", over=0.25, t=0.14, m="slate", trim=True):
    """Gable roof on top of a box: wedges fill the gable, two tile plates on top. ridge = "y" (slopes face +-x) or "x"."""
    if ridge == "y":
        faces = [((1.0, 0.0, 0.0), span / 4), ((-1.0, 0.0, 0.0), -span / 4)]
        L = depth
    else:
        faces = [((0.0, 1.0, 0.0), span / 4), ((0.0, -1.0, 0.0), -span / 4)]
        L = depth
    run = span / 2
    ang = math.atan2(rise, run)
    for k, (f, off) in enumerate(faces):
        cx, cy = (x + off, y) if ridge == "y" else (x, y + off)
        wedge("%s_Fill%d" % (n, k), L, rise, run, cx, cy, z0, f, "marble")
        # tile plate along the slope, a little over the eave and the gable ends
        sl = math.hypot(run, rise) + over
        nrm = vadd(vmul(f, math.sin(ang)), (0, 0, math.cos(ang)))
        down = vadd(vmul(f, math.cos(ang)), (0, 0, -math.sin(ang)))     # along the slope, to the eave
        top = (x, y, z0 + rise)
        mid = vadd(top, vmul(down, sl / 2), vmul(nrm, t / 2))
        Xa = EY if ridge == "y" else EX
        part("%s_Tile%d" % (n, k), "Block", (L + 2 * over, t, sl), mid, Xa, nrm, m)
    if trim:
        ax = EY if ridge == "y" else EX
        top = (x, y, z0 + rise + t * 0.9)
        rod(n + "_Ridge", vadd(top, vmul(ax, -(L / 2 + over))), vadd(top, vmul(ax, L / 2 + over)), 0.16, "gold")


def planks(n, L, depth_total, count, thick, x, y0, y1, z, m="wood", gap=0.06, axis="x"):
    """Row of boards lying flat (seat): boards run along x, spread from y0 to y1, top at z."""
    wid = (abs(y1 - y0) - gap * (count - 1)) / count
    s = 1 if y1 > y0 else -1
    for k in range(count):
        yc = y0 + s * (wid / 2 + k * (wid + gap))
        box("%s%d" % (n, k), L, wid, thick, x, yc, z - thick, m)


# ---------------------------------------------------------------- kits: chunk 1 (all parts)
@kit("HaloReasonHQ_BenchA", 3.8, "art/out/s2/halo/props4/HaloProp4_BenchA_front.png")
def bench_a():
    for sx in (-1, 1):
        x = sx * 2.45
        pedestal("Leg%d" % sx, 1.1, 1.7, 1.45, x, 0.0)
        box("LegTop%d" % sx, 1.18, 1.78, 0.1, x, 0.0, 1.45, "gold")
        inlay("LegWin%d" % sx, (x, 0.85, 0.85), EY, 0.34, 0.62, "arch")
        inlay("LegWinS%d" % sx, (x + sx * 0.55, 0.0, 0.85), (sx, 0, 0), 0.34, 0.62, "arch")
        pedestal("Post%d" % sx, 0.85, 0.8, 1.45, x, -0.48, 1.55, band=False, plinth=0.12)
        inlay("PostWin%d" % sx, (x, -0.08, 2.3), EY, 0.24, 0.5, "arch", fr=0.05)
        z = cap("PostCap%d" % sx, 0.85, 0.8, x, -0.48, 3.0)
        gold_ball("PostBall%d" % sx, 0.62, x, -0.48, z)
    planks("Seat", 4.0, 1.4, 3, 0.16, 0.0, 0.78, -0.55, 1.55)
    for k in range(3):                       # back slats, leaning back 8 deg
        zc = 1.85 + k * 0.36
        part("Back%d" % k, "Block", (3.95, 0.3, 0.14), (0.0, -0.62 - (zc - 1.6) * 0.14, zc), EX, norm((0, -0.14, 1)), "wood")
    # arched marble crest (block AND big cylinder) with a gold arc band on top
    R, zt = 3.75, 3.75                      # chord 3.9, rise 0.55 (2D: big marble crest)
    zc = zt - R
    cyl_c = cut(part, "CrestCyl", "Cylinder", (0.6, 2 * R, 2 * R), (0.0, -0.78, zc), EY, UP, "marble")
    part("Crest", "Block", (3.9, 1.1, 0.3), (0.0, -0.78, zt - 0.55), EX, UP, "marble", ops=[("and", [cyl_c])])
    band_o = cut(part, "BandCyl", "Cylinder", (0.36, 2 * R + 0.16, 2 * R + 0.16), (0.0, -0.78, zc), EY, UP, "gold")
    band_i = cut(part, "BandIn", "Cylinder", (0.5, 2 * R - 0.12, 2 * R - 0.12), (0.0, -0.78, zc), EY, UP, "gold")
    part("CrestBand", "Block", (3.9, 0.7, 0.36), (0.0, -0.78, zt - 0.25), EX, UP, "gold", cc=False,
         ops=[("and", [band_o]), ("minus", [band_i])])
    box("CrestFoot", 3.9, 0.36, 0.1, 0.0, -0.78, 2.72, "gold")


@kit("HaloReasonHQ_BenchC", 2.4, "art/out/s2/halo/props4/HaloProp4_BenchC_front.png")
def bench_c():
    for sx in (-1, 1):
        x = sx * 2.4
        pedestal("Ped%d" % sx, 1.15, 1.4, 1.55, x, 0.0)
        inlay("PedWin%d" % sx, (x, 0.7, 0.85), EY, 0.36, 0.66, "arch")
        inlay("PedWinB%d" % sx, (x, -0.7, 0.85), (0, -1, 0), 0.36, 0.66, "arch")
        inlay("PedWinS%d" % sx, (x + sx * 0.575, 0.0, 0.85), (sx, 0, 0), 0.36, 0.66, "arch")
        z = cap("PedCap%d" % sx, 1.15, 1.4, x, 0.0, 1.55)
        gold_ball("PedBall%d" % sx, 0.62, x, 0.0, z)
        box("Bracket%d" % sx, 0.18, 0.9, 0.3, x - sx * 0.67, 0.0, 1.0, "gold", cc=False)
    planks("Seat", 3.7, 1.2, 3, 0.3, 0.0, 0.6, -0.6, 1.4)


@kit("HaloReasonHQ_PhotoDisc", 0.6, "art/out/s2/halo/reason_hq/HaloReasonHQ_PhotoDisc.png")
def photo_disc():
    S = 10.0
    box("Slab", S, S, 0.35, 0, 0, 0, "mblock")
    cyl("Disc", 8.4, 0.12, 0, 0, 0.33, "gold")
    cyl("Step", 7.4, 0.17, 0, 0, 0.33, "gold")
    ring("Rim", 8.4, 7.9, 0.1, 0, 0, 0.5, "gold")
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        ball("Stud%d" % k, 0.62, 3.05 * math.cos(a), 3.05 * math.sin(a), 0.5, "gold", cc=False)
    cyl("Centre", 4.6, 0.22, 0, 0, 0.33, "gold")
    ring("CentreRim", 4.6, 4.1, 0.08, 0, 0, 0.6, "gold")
    cyl("Inner", 3.5, 0.26, 0, 0, 0.33, "gold")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (S / 2 - 0.65), sy * (S / 2 - 0.65)
            box("GemG%d%d" % (sx, sy), 1.0, 1.0, 0.06, x, y, 0.33, "gold")
            box("Gem%d%d" % (sx, sy), 0.78, 0.78, 0.08, x, y, 0.33, "blue")
            # gold strips from the gem along the two edges
            box("StripX%d%d" % (sx, sy), 0.12, 1.1, 0.05, x - sx * 0.85, sy * (S / 2 - 0.55), 0.33, "gold")
            box("StripY%d%d" % (sx, sy), 1.1, 0.12, 0.05, sx * (S / 2 - 0.55), y - sy * 0.85, 0.33, "gold")
    for k, (x, y) in enumerate(((0, 4.45), (0, -4.45), (4.45, 0), (-4.45, 0))):
        cyl("Knob%d" % k, 0.3, 0.45, x, y, 0.35, "gold", cc=False)
        ball("KnobBall%d" % k, 0.5, x, y, 0.95, "gold", cc=False)


def baluster(n, x, y, z0, h, d=0.62):
    """Vase baluster from z0 to z0 + h (square foot + bulb + neck + collar + square head)."""
    box(n + "_Foot", d * 0.85, d * 0.85, 0.14, x, y, z0, "marble")
    cyl(n + "_Ring0", d * 0.62, 0.08, x, y, z0 + 0.14, "gold", cc=False)
    zb = z0 + 0.22
    bh = h * 0.42
    cyl(n + "_Bulb", d, bh - d * 0.5, x, y, zb + d * 0.25, "marble")
    ball(n + "_BulbLo", d, x, y, zb + d * 0.5, "marble")
    ball(n + "_BulbHi", d * 0.92, x, y, zb + bh - d * 0.42, "marble")
    zn = zb + bh
    cyl(n + "_Neck", d * 0.45, h - (zn - z0) - 0.22, x, y, zn - 0.05, "marble")
    cyl(n + "_Ring1", d * 0.6, 0.08, x, y, z0 + h - 0.34, "gold", cc=False)
    cyl(n + "_Collar", d * 0.72, 0.1, x, y, z0 + h - 0.26, "marble")
    box(n + "_Head", d * 0.85, d * 0.85, 0.16, x, y, z0 + h - 0.16, "marble")


def rail_run(n, L, x0, x1, y, z0, top, count, d=0.62, plinth_h=0.55, depth=0.9):
    """Plinth + balusters + hand rail between x0 and x1 (straight along x)."""
    xc, L = (x0 + x1) / 2, abs(x1 - x0)
    box(n + "_Plinth", L, depth, plinth_h, xc, y, z0, "marble")
    box(n + "_PlinthBand", L, depth + 0.04, 0.08, xc, y, z0 + plinth_h - 0.18, "gold")
    hz0 = z0 + plinth_h
    rail_t = 0.36
    bh = top - rail_t - hz0
    step = L / count
    for k in range(count):
        baluster("%s_B%d" % (n, k), x0 + step * (k + 0.5) * (1 if x1 > x0 else -1), y, hz0, bh, d)
    box(n + "_Rail", L, depth + 0.1, rail_t, xc, y, top - rail_t, "marble")
    box(n + "_RailBand", L, depth + 0.14, 0.07, xc, y, top - rail_t - 0.07, "gold")


@kit("HaloVar4_Balustrade_A", 4.5, "art/out/s2/halo/variants4/HaloVar4_Balustrade_A_HQ_src.png")
def balustrade_a():
    for sx in (-1, 1):
        x = sx * 3.45
        pedestal("Post%d" % sx, 1.1, 1.1, 3.4, x, 0.0)
        inlay("PostWin%d" % sx, (x, 0.55, 1.9), EY, 0.42, 1.5, "rect", fr=0.06)
        inlay("PostWinB%d" % sx, (x, -0.55, 1.9), (0, -1, 0), 0.42, 1.5, "rect", fr=0.06)
        z = cap("PostCap%d" % sx, 1.1, 1.1, x, 0.0, 3.4)
        gold_ball("PostBall%d" % sx, 0.78, x, 0.0, z)
    rail_run("Run", 5.8, -2.9, 2.9, 0.0, 0.0, 3.25, 6)


@kit("HaloVar4_Balustrade_C", 4.5, "art/out/s2/halo/variants4/HaloVar4_Balustrade_C_HQ_src.png")
def balustrade_c():
    # two runs meeting at a taller centre post, bent back 15 deg each (a corner of a lookout)
    pedestal("PostC", 1.15, 1.15, 3.55, 0.0, 0.0)
    z = cap("PostCCap", 1.15, 1.15, 0.0, 0.0, 3.55)
    gold_ball("PostCBall", 0.9, 0.0, 0.0, z)
    inlay("PostCWin", (0.0, 0.575, 1.9), EY, 0.4, 1.4, "rect", fr=0.06)
    for sx in (-1, 1):
        a = -sx * 15.0
        dirx = rotz(EX, a)
        if sx < 0:
            dirx = rotz((-1.0, 0.0, 0.0), a)
        end = vmul(dirx, 4.1)
        mid = vmul(dirx, 2.3)
        rot = math.degrees(math.atan2(dirx[1], dirx[0]))
        # run: plinth, balusters, rail along dirx from 0.6 to 3.6
        L = 3.0
        box("Plinth%d" % sx, L, 0.85, 0.5, mid[0], mid[1], 0.0, "marble", rot=rot)
        box("PlinthBand%d" % sx, L, 0.89, 0.08, mid[0], mid[1], 0.32, "gold", rot=rot)
        for k in range(4):
            q = vmul(dirx, 0.6 + L / 4 * (k + 0.5))
            baluster("B%d_%d" % (sx, k), q[0], q[1], 0.5, 2.25, 0.56)
        box("Rail%d" % sx, L, 0.95, 0.34, mid[0], mid[1], 2.75, "marble", rot=rot)
        box("RailBand%d" % sx, L, 0.99, 0.07, mid[0], mid[1], 2.68, "gold", rot=rot)
        pedestal("PostE%d" % sx, 0.95, 0.95, 3.1, end[0], end[1])
        z = cap("PostECap%d" % sx, 0.95, 0.95, end[0], end[1], 3.1)
        gold_ball("PostEBall%d" % sx, 0.6, end[0], end[1], z)


@kit("HaloVar3_Balustrade_E", 4.5, "art/out/s2/halo/variants/HaloVar3_Balustrade_E_HQ_src.png")
def balustrade_e():
    W, T, H = 6.6, 0.6, 3.1                      # arcade wall between the posts
    holes = []
    n = 4
    pitch = W / n
    for k in range(n):
        x = -W / 2 + pitch * (k + 0.5)
        holes.append(cut(box, "Hole%d" % k, 1.05, T + 0.4, 1.3, x, 0.0, 0.95, "marble"))
        holes.append(cut(part, "HoleTop%d" % k, "Cylinder", (T + 0.4, 1.05, 1.05), (x, 0.0, 2.25), EY, UP, "marble"))
    box("Wall", W, T, H - 0.6, 0.0, 0.0, 0.6, "marble", ops=[("minus", holes)])
    box("Plinth", W + 0.1, T + 0.3, 0.6, 0.0, 0.0, 0.0, "marble")
    box("PlinthBand", W + 0.1, T + 0.34, 0.08, 0.0, 0.0, 0.5, "gold")
    box("Coping", W + 0.1, T + 0.24, 0.2, 0.0, 0.0, H, "marble")
    box("CopingBand", W + 0.1, T + 0.26, 0.07, 0.0, 0.0, H - 0.07, "gold")
    for k in range(n + 1):                         # gold impost blocks at the springing line
        x = -W / 2 + pitch * k
        if 0 < k < n:
            box("Impost%d" % k, 0.42, T + 0.08, 0.1, x, 0.0, 2.2, "gold", cc=False)
    for k in range(n):                             # gold arch bands round each opening (front and back)
        x = -W / 2 + pitch * (k + 0.5)
        for sy in (-1, 1):
            part("ArchBand%d%d" % (k, sy), "Cylinder", (0.06, 1.25, 1.25), (x, sy * (T / 2 + 0.02), 2.25), EY, UP, "gold", cc=False,
                 ops=[("minus", [cut(part, "AI%d%d" % (k, sy), "Cylinder", (0.2, 1.05, 1.05), (x, sy * (T / 2 + 0.02), 2.25), EY, UP, "gold"),
                                 cut(box, "AC%d%d" % (k, sy), 1.4, 0.3, 0.7, x, sy * (T / 2 + 0.02), 1.55, "gold")])])
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.6)
        pedestal("Post%d" % sx, 1.2, 1.2, 3.45, x, 0.0)
        inlay("PostWin%d" % sx, (x, 0.6, 1.95), EY, 0.42, 1.6, "rect", fr=0.07)
        inlay("PostWinB%d" % sx, (x, -0.6, 1.95), (0, -1, 0), 0.42, 1.6, "rect", fr=0.07)
        z = cap("PostCap%d" % sx, 1.2, 1.2, x, 0.0, 3.45)
        onion("PostDome%d" % sx, 0.85, x, 0.0, z, tip=0.45)


@kit("HaloVar3_Balustrade_F", 4.5, "art/out/s2/halo/variants/HaloVar3_Balustrade_F_HQ_src.png",
     note="top trough soil only: the hedge on top is a Tripo plant (가+나)")
def balustrade_f():
    for sx in (-1, 1):
        x = sx * 3.45
        pedestal("Post%d" % sx, 1.1, 1.1, 3.55, x, 0.0)
        inlay("PostWin%d" % sx, (x, 0.55, 1.95), EY, 0.36, 1.2, "arch", fr=0.06)
        inlay("PostWinB%d" % sx, (x, -0.55, 1.95), (0, -1, 0), 0.36, 1.2, "arch", fr=0.06)
        z = cap("PostCap%d" % sx, 1.1, 1.1, x, 0.0, 3.55)
        onion("PostDome%d" % sx, 0.75, x, 0.0, z, tip=0.35)
    rail_run("Run", 5.8, -2.9, 2.9, 0.0, 0.0, 2.6, 7, d=0.5)
    # flower trough on the rail: gold-banded marble box with soil (plants = Tripo later)
    box("Trough", 5.8, 1.0, 0.45, 0.0, 0.0, 2.6, "marble")
    box("TroughBand", 5.8, 1.04, 0.08, 0.0, 0.0, 2.95, "gold")
    box("Soil", 5.6, 0.8, 0.06, 0.0, 0.0, 3.02, "soil", cc=False)


@kit("HaloFlagpole_1", 12.0, "art/out/s2/halo/poles/HaloFlagpole_1_front_HQ_src.png")
def flagpole_1():
    pedestal("Base", 2.2, 2.2, 1.9, 0.0, 0.0, plinth=0.3)
    for k, nrm in enumerate((EY, (0, -1, 0), EX, (-1, 0, 0))):
        inlay("BaseWin%d" % k, vadd((0, 0, 1.05), vmul(nrm, 1.1)), nrm, 0.42, 0.6, "arch", fr=0.06)
    box("BaseTop", 2.3, 2.3, 0.14, 0, 0, 1.9, "gold")
    cyl("Shaft", 0.8, 8.0, 0, 0, 2.04, "marble")
    for k, z in enumerate((2.04, 3.6, 8.3)):
        cyl("Collar%d" % k, 1.0, 0.24, 0, 0, z, "gold")
    for nrm in (EY, (0, -1, 0)):
        inlay("ShaftWin%d" % int(nrm[1]), (0, nrm[1] * 0.36, 5.9), nrm, 0.28, 2.6, "hex", fr=0.06)
    box("TopBlock", 1.0, 1.0, 0.6, 0, 0, 10.0, "marble")
    box("TopBand", 1.08, 1.08, 0.12, 0, 0, 10.04, "gold")
    cyl("TopCollar", 0.85, 0.16, 0, 0, 10.6, "gold")
    ball("TopBall", 1.15, 0, 0, 11.3, "gold")
    spike("TopSpike", 0, 0, 11.75, 0.7, 0.24)
    cyl("ArmCollar", 0.95, 0.4, 0, 0, 9.35, "gold")
    rod("Arm", (-0.3, 0, 9.55), (-2.9, 0, 9.55), 0.24, "gold", cc=False)      # viewer's right in the 2D front = -x
    ball("ArmEnd", 0.42, -2.95, 0, 9.55, "gold", cc=False)


@kit("HaloFlagpole_2", 12.0, "art/out/s2/halo/poles/HaloFlagpole_2_front_HQ_src.png")
def flagpole_2():
    cyl("BaseGold", 3.1, 0.3, 0, 0, 0, "gold")
    cyl("BaseDisc", 2.7, 0.65, 0, 0, 0.3, "marble")
    cyl("Drum", 1.55, 1.2, 0, 0, 0.95, "marble")
    for k in range(4):
        nrm = hdir(90 * k)
        inlay("DrumWin%d" % k, vadd((0, 0, 1.55), vmul(nrm, 0.76)), nrm, 0.22, 0.62, "arch", fr=0.05)
    cyl("Collar0", 1.75, 0.3, 0, 0, 2.15, "gold")
    cyl("Shaft", 0.66, 5.4, 0, 0, 2.45, "marble")
    cyl("Collar1", 0.95, 0.25, 0, 0, 7.75, "gold")
    box("Upper", 0.9, 0.9, 1.35, 0, 0, 8.0, "marble")
    for k, nrm in enumerate((EY, (0, -1, 0), EX, (-1, 0, 0))):
        inlay("UpWin%d" % k, vadd((0, 0, 8.68), vmul(nrm, 0.45)), nrm, 0.24, 0.85, "hex", fr=0.05)
    cyl("Collar2", 1.05, 0.22, 0, 0, 9.35, "gold")
    ball("TopBall", 1.1, 0, 0, 10.1, "gold")
    # spear point: a gold diamond (two crossed flat diamonds) on a short neck
    cyl("PointNeck", 0.24, 0.35, 0, 0, 10.6, "gold", cc=False)
    for k, ax in enumerate((EY, EX)):
        Xd = norm(vadd(cross(ax, UP), UP))
        Yd = norm(vsub(UP, cross(ax, UP)))
        part("Point%d" % k, "Block", (0.85, 0.85, 0.12), (0, 0, 11.4), Xd, Yd, "gold", cc=False)


@kit("HaloFlagpole_3", 12.0, "art/out/s2/halo/poles/HaloFlagpole_3_front_HQ_src.png")
def flagpole_3():
    box("Step0", 4.8, 4.8, 0.6, 0, 0, 0, "marble")
    box("Step0Band", 4.86, 4.86, 0.1, 0, 0, 0.48, "gold")
    box("Step1", 4.1, 4.1, 1.5, 0, 0, 0.6, "marble")
    for k, nrm in enumerate((EY, (0, -1, 0), EX, (-1, 0, 0))):
        c = vadd((0, 0, 1.35), vmul(nrm, 2.05))
        for sx in (-1, 1):
            o = vmul(cross(UP, nrm), sx * 1.2)
            plate("StepGold%d%d" % (k, sx), 0.16, 0.9, 0.05, vadd(c, o), nrm, "gold")
    box("Step1Band", 4.2, 4.2, 0.12, 0, 0, 2.1, "gold")
    box("Step2", 3.0, 3.0, 0.5, 0, 0, 2.22, "marble")
    box("ShaftBand", 2.3, 2.3, 0.35, 0, 0, 2.72, "gold")
    box("Shaft", 2.0, 2.0, 5.2, 0, 0, 3.07, "marble")
    for k, nrm in enumerate((EY, (0, -1, 0), EX, (-1, 0, 0))):
        inlay("ShaftWin%d" % k, vadd((0, 0, 5.6), vmul(nrm, 1.0)), nrm, 0.62, 3.2, "hex", fr=0.1)
    box("TopBand", 2.1, 2.1, 0.14, 0, 0, 8.27, "gold")
    box("Top", 2.3, 2.3, 0.45, 0, 0, 8.41, "marble")
    cyl("DomeBase", 1.8, 0.22, 0, 0, 8.86, "gold")
    ball("Dome", 2.0, 0, 0, 9.95, "gold", cc=False)
    spike("DomeSpike", 0, 0, 10.85, 1.05, 0.34)
    for sx in (-1, 1):
        rod("Arm%d" % sx, (sx * 1.0, 0, 7.4), (sx * 3.0, 0, 7.4), 0.36, "gold", cc=False)
        cyl("ArmCup%d" % sx, 0.7, 0.3, sx * 3.15, 0, 7.15, "gold", cc=False)
        ball("ArmDome%d" % sx, 1.25, sx * 3.15, 0, 8.0, "gold", cc=False)
        spike("ArmSpike%d" % sx, sx * 3.15, 0, 8.5, 0.75, 0.24)


@kit("NEW_CafeTable", 3.0, "art/out/s2/halo/kits_new/HaloKit_CafeTable_front.png")
def cafe_table():
    cyl("FootGold", 1.75, 0.1, 0, 0, 0, "gold")
    cyl("Foot", 1.6, 0.25, 0, 0, 0.08, "marble")
    cyl("FootRing", 1.05, 0.08, 0, 0, 0.33, "gold", cc=False)
    cyl("Stem", 0.42, 2.4, 0, 0, 0.35, "marble")
    cyl("Belly", 0.72, 1.0, 0, 0, 1.05, "marble")
    ball("BellyLo", 0.72, 0, 0, 1.05, "marble")
    ball("BellyHi", 0.72, 0, 0, 2.05, "marble")
    cyl("Ring1", 0.5, 0.08, 0, 0, 0.62, "gold", cc=False)
    cyl("Ring2", 0.5, 0.08, 0, 0, 2.45, "gold", cc=False)
    for k in range(4):
        nrm = hdir(90 * k + 45)
        inlay("Win%d" % k, vadd((0, 0, 1.55), vmul(nrm, 0.36)), nrm, 0.14, 0.62, "hex", fr=0.04)
    cyl("Collar", 0.68, 0.14, 0, 0, 2.6, "gold")
    cyl("TopGold", 2.6, 0.14, 0, 0, 2.74, "gold")
    cyl("Top", 2.5, 0.2, 0, 0, 2.8, "marble")


@kit("NEW_CandleCrate", 2.0, "art/out/s2/halo/kits_new/HaloKit_CandleCrate_front.png")
def candle_crate():
    W, D, H, t = 2.0, 1.5, 1.15, 0.12
    box("Bottom", W, D, 0.12, 0, 0, 0, "pcream")
    box("Front", W, t, H, 0, D / 2 - t / 2, 0, "pcream")
    box("Back", W, t, H, 0, -D / 2 + t / 2, 0, "pcream")
    box("Left", t, D - 2 * t, H, -W / 2 + t / 2, 0, 0, "pcream")
    box("Right", t, D - 2 * t, H, W / 2 - t / 2, 0, 0, "pcream")
    for k, f in enumerate(((0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0))):      # one plank seam round the middle
        L = (W if f[1] else D) - 0.4
        seam("Seam%d" % k, (f[0] * W / 2, f[1] * D / 2, H * 0.62), f, L)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Corner%d%d" % (sx, sy), 0.18, 0.18, H + 0.04, sx * (W / 2 - 0.07), sy * (D / 2 - 0.07), 0, "gold")
            ball("Stud%d%d" % (sx, sy), 0.14, sx * (W / 2 - 0.02), sy * (D / 2 + 0.0), H * 0.5, "gold", cc=False)
    for sy in (-1, 1):
        box("BandTop%d" % sy, W + 0.02, 0.06, 0.12, 0, sy * (D / 2 + 0.01), H - 0.14, "gold", cc=False)
        box("BandBot%d" % sy, W + 0.02, 0.06, 0.12, 0, sy * (D / 2 + 0.01), 0.02, "gold", cc=False)
    # diagonal brace on the front
    part("Brace", "Block", (math.hypot(W - 0.4, H - 0.4), 0.16, 0.05), (0, D / 2 + 0.025, H / 2), norm((W - 0.4, 0, H - 0.4)),
         norm((-(H - 0.4), 0, W - 0.4)), "pcream", cc=False)
    # white candles standing in the crate (no flame)
    for k, (x, y, d, h) in enumerate(((-0.45, 0.2, 0.42, 1.55), (0.15, 0.25, 0.4, 1.75), (0.6, -0.2, 0.38, 1.45),
                                       (-0.2, -0.3, 0.44, 1.9), (0.35, 0.3, 0.32, 1.25), (-0.65, -0.25, 0.34, 1.35))):
        cyl("Candle%d" % k, d, h - 0.12, x, y, 0.12, "candle")
        cyl("Drip%d" % k, d + 0.05, 0.08, x, y, h - 0.25, "candle", cc=False)
        cyl("Wick%d" % k, 0.05, 0.12, x, y, h, "dark", cc=False)


def barrel(n, d, h, x, y, z0=0.0):
    """Bulged barrel: three stacked cylinders + gold hoops."""
    cyl(n + "_Lo", d * 0.92, h * 0.26, x, y, z0, "pcream")
    cyl(n + "_Mid", d, h * 0.48, x, y, z0 + h * 0.26, "pcream")
    cyl(n + "_Hi", d * 0.92, h * 0.26, x, y, z0 + h * 0.74, "pcream")
    for k in range(8):                                          # stave seams, one per section
        f = hdir(22.5 + 45 * k)
        for j, (zz, hh, dd) in enumerate(((0.0, 0.26, 0.92), (0.26, 0.48, 1.0), (0.74, 0.26, 0.92))):
            seam("%s_Stave%d_%d" % (n, k, j), (x + f[0] * d * dd / 2, y + f[1] * d * dd / 2, z0 + h * (zz + hh / 2)), f,
                 h * hh, vertical=True)
    for k, (zz, dd) in enumerate(((0.06, 0.92), (0.26, 0.96), (0.7, 0.96), (0.9, 0.92))):
        cyl("%s_Hoop%d" % (n, k), d * dd + 0.08, 0.14, x, y, z0 + h * zz - 0.07, "gold", cc=False)
    cyl(n + "_Lid", d * 0.84, 0.04, x, y, z0 + h, "groove", cc=False)


@kit("NEW_ArmoryBarrels", 3.5, "art/out/s2/halo/kits_new/HaloKit_ArmoryBarrels_front.png", mirror=True)
def armory_barrels():
    barrel("BarrelA", 1.9, 3.0, -0.95, -0.35)
    barrel("BarrelB", 1.6, 2.1, -0.35, 0.95)
    # crate (right back), cream planks, gold corners and an X brace
    S = 1.85
    x, y = 1.15, -0.15
    box("Crate", S, S, S, x, y, 0, "pcream")
    for k, f in enumerate(((0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0))):      # two plank seams per side
        for j, zz in enumerate((S / 3, 2 * S / 3)):
            seam("CrateSeam%d_%d" % (k, j), (x + f[0] * S / 2, y + f[1] * S / 2, zz), f, S - 0.4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("CrateCorner%d%d" % (sx, sy), 0.2, 0.2, S + 0.02, x + sx * (S / 2 - 0.08), y + sy * (S / 2 - 0.08), 0, "gold", cc=False)
    for sz in (0, 1):
        box("CrateBand%d" % sz, S + 0.04, S + 0.04, 0.14, x, y, 0.02 + sz * (S - 0.18), "gold", cc=False)
    for k, sgn in enumerate((1, -1)):
        a = norm((sgn * 1.0, 0, 1.0))
        part("CrateX%d" % k, "Block", (S * 1.15, 0.18, 0.06), (x, y + S / 2 + 0.06 + 0.02 * k, S / 2), a, norm((-a[2], 0, a[0])), "pcream", cc=False)
    # white cloth with a blue stripe hanging over barrel A's rim (Fabric)
    box("ClothTop", 0.9, 0.9, 0.06, -1.45, -0.35, 3.0, "cloth", cc=False)          # lies on barrel A's lid edge
    box("Cloth", 0.06, 0.9, 1.0, -1.93, -0.35, 2.02, "cloth", cc=False)             # hangs down its outer side
    box("ClothStripe", 0.07, 0.9, 0.12, -1.935, -0.35, 2.2, "cloth", c=(110, 170, 235), cc=False)


@kit("NEW_Beehive", 3.0, "art/out/s2/halo/kits_mv/HaloKit_Beehive_front_HQ_src.png")
def beehive():
    W, D = 1.75, 1.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Leg%d%d" % (sx, sy), 0.32, 0.32, 0.38, sx * (W / 2 - 0.12), sy * (D / 2 - 0.12), 0, "marble")
    box("Floor", W + 0.1, D + 0.1, 0.12, 0, 0, 0.38, "gold")
    z = 0.5
    for k in range(2):
        box("Box%d" % k, W, D, 0.82, 0, 0, z, "pcream")
        for j, f in enumerate(((0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0))):  # plank seams below / above the slot
            for i, zz in enumerate((0.2, 0.62)):
                if f[1] > 0 and i == 1:
                    continue
                seam("BoxSeam%d_%d_%d" % (k, j, i), (f[0] * W / 2, f[1] * D / 2, z + zz), f, (W if f[1] else D) - 0.26)
        box("BoxBand%d" % k, W + 0.06, D + 0.06, 0.1, 0, 0, z + 0.7, "gold", cc=False)
        for sx in (-1, 1):
            for sy in (-1, 1):
                box("BoxEdge%d%d%d" % (k, sx, sy), 0.12, 0.12, 0.82, sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), z, "gold", cc=False)
        # front handle slot (dark) with a gold lip
        box("Slot%d" % k, 0.7, 0.04, 0.09, 0, D / 2 + 0.02, z + 0.4, "dark", cc=False)
        box("SlotLip%d" % k, 0.82, 0.05, 0.05, 0, D / 2 + 0.035, z + 0.33, "gold", cc=False)
        z += 0.84
    box("Eave", W + 0.2, D + 0.2, 0.1, 0, 0, z, "gold")
    gable_roof("Roof", W + 0.1, D + 0.1, 0.6, 0, 0, z + 0.1, ridge="y", over=0.22, t=0.12)
    # round entrance hole in the front gable
    cyl_d = 0.3
    part("Hole", "Cylinder", (0.06, cyl_d, cyl_d), (0, D / 2 + 0.08, z + 0.32), EY, UP, "dark", cc=False)
    ring("HoleRim", cyl_d + 0.12, cyl_d, 0.07, 0, D / 2 + 0.085, z + 0.32, "gold", axis=EY, cc=False)
    gold_ball("RidgeBallF", 0.22, 0, D / 2 + 0.3, z + 0.8, neck=False)
    gold_ball("RidgeBallB", 0.22, 0, -D / 2 - 0.3, z + 0.8, neck=False)


@kit("NEW_NoticeBoard", 6.0, "art/out/s2/halo/kits_new/HaloKit_NoticeBoard_front.png")
def notice_board():
    for sx in (-1, 1):
        x = sx * 1.75
        pedestal("Post%d" % sx, 0.62, 0.62, 4.5, x, 0.0, plinth=0.4)
        inlay("PostWin%d" % sx, (x, 0.31, 2.9), EY, 0.18, 1.1, "arch", fr=0.045)
        box("PostTop%d" % sx, 0.72, 0.72, 0.1, x, 0, 4.5, "gold")
    box("Lintel", 4.3, 0.85, 0.42, 0, 0, 4.6, "marble")
    box("LintelBand", 4.36, 0.91, 0.08, 0, 0, 4.62, "gold")
    gable_roof("Roof", 1.3, 4.4, 0.72, 0, 0, 5.02, ridge="x", over=0.3, t=0.13)
    for sx in (-1, 1):
        inlay("GableWin%d" % sx, (sx * 2.2, 0, 5.3), (sx, 0, 0), 0.14, 0.3, "arch", fr=0.04)
        gold_ball("Finial%d" % sx, 0.3, sx * 2.45, 0, 5.84, neck=False)
    # board: light wood planks with a gold frame, slightly in front of the posts
    box("Board", 2.9, 0.16, 2.3, 0, 0.05, 1.7, "pcream")
    for k in range(4):
        box("BoardSeam%d" % k, 2.9, 0.02, 0.03, 0, 0.14, 2.15 + k * 0.48, "groove", cc=False)
    for sz, zz in ((0, 1.62), (1, 4.0)):
        box("FrameH%d" % sz, 3.06, 0.2, 0.09, 0, 0.06, zz, "gold", cc=False)
    for sx in (-1, 1):
        box("FrameV%d" % sx, 0.09, 0.2, 2.38, sx * 1.49, 0.06, 1.66, "gold", cc=False)


@kit("NEW_Easel", 5.5, "art/out/s2/halo/kits_mv/HaloKit_Easel_front_HQ_src.png")
def easel():
    lean = 0.12                                  # front frame leans back: y = y0 - lean * z
    def fy(z, y0=0.3):
        return y0 - lean * z
    for sx in (-1, 1):
        rod("LegF%d" % sx, (sx * 1.0, fy(0.0) + 0.05, 0.12), (sx * 0.2, fy(4.6), 4.6), 0.2, "woodcream", shape="Block")
        cyl("FootF%d" % sx, 0.34, 0.16, sx * 1.0, fy(0.0) + 0.05, 0.0, "gold", cc=False)
    rod("LegB", (0.0, -1.0, 0.12), (0.0, fy(4.2) - 0.1, 4.2), 0.17, "woodcream", shape="Block")
    cyl("FootB", 0.3, 0.14, 0.0, -1.0, 0.0, "gold", cc=False)
    rod("Mast", (0.0, fy(1.6) + 0.05, 1.6), (0.0, fy(5.15) + 0.05, 5.15), 0.16, "woodcream", shape="Block")
    rod("CrossLo", (-0.78, fy(1.4) + 0.05, 1.4), (0.78, fy(1.4) + 0.05, 1.4), 0.14, "woodcream", shape="Block")
    # tray the canvas stands on
    ty = fy(2.25) + 0.16
    box("Tray", 2.5, 0.34, 0.12, 0.0, ty, 2.2, "woodcream")
    box("TrayLip", 2.5, 0.05, 0.12, 0.0, ty + 0.17, 2.26, "gold", cc=False)
    for sx in (-1, 1):
        cyl("TrayKnob%d" % sx, 0.14, 0.14, sx * 1.28, ty, 2.18, "gold", cc=False)
    # canvas (leaning with the frame) + a simple sea painting of flat colour pieces
    nrm = norm((0.0, 1.0, lean))
    Xc, Yc = EX, norm((0.0, -lean, 1.0))
    cz = 3.35
    cc_ = (0.0, fy(cz) + 0.17, cz)
    part("Canvas", "Block", (2.3, 2.0, 0.08), cc_, Xc, Yc, "paint", c=(250, 248, 240))
    def paint(nm, w, h, du, dv, col):
        pos = vadd(cc_, vmul(Xc, du), vmul(Yc, dv), vmul(nrm, 0.045))
        part(nm, "Block", (w, h, 0.02), pos, Xc, Yc, "paint", c=col, cc=False)
    paint("Sky", 2.14, 1.0, 0.0, 0.42, (150, 205, 245))
    paint("Sea", 2.14, 0.55, 0.0, -0.35, (40, 140, 215))
    paint("SeaLight", 2.14, 0.1, 0.0, -0.1, (120, 200, 240))
    paint("Sand", 2.14, 0.28, 0.0, -0.77, (242, 222, 175))
    paint("Foam", 2.14, 0.06, 0.0, -0.62, (250, 250, 250))
    for k, (du, dv, w) in enumerate(((-0.55, 0.6, 0.55), (0.45, 0.72, 0.42), (0.62, 0.48, 0.28))):
        paint("Cloud%d" % k, w, 0.15, du, dv, (255, 255, 255))
    # clamp + top knob
    ctop = vadd(cc_, vmul(Yc, 1.08), vmul(nrm, 0.06))
    part("Clamp", "Block", (0.3, 0.22, 0.2), ctop, Xc, Yc, "woodcream", cc=False)
    cyl("Knob", 0.2, 0.1, 0.0, fy(5.15) + 0.05, 5.15, "gold", cc=False)
    ball("KnobBall", 0.26, 0.0, fy(5.3) + 0.05, 5.33, "gold", cc=False)


@kit("NEW_Telescope", 5.0, "art/out/s2/halo/kits_mv/HaloKit_Telescope_front_HQ_src.png")
def telescope():
    apex = (0.0, 0.0, 3.05)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        foot = (0.95 * math.cos(a), 0.95 * math.sin(a), 0.16)
        rod("Leg%d" % k, foot, vadd(apex, (0, 0, -0.1)), 0.17, "wooddk")
        cyl("Foot%d" % k, 0.3, 0.16, foot[0], foot[1], 0.0, "gold", cc=False)
        mid = vadd(vmul(foot, 0.55), vmul(apex, 0.45))
        part("LegBand%d" % k, "Cylinder", (0.12, 0.24, 0.24), mid, norm(vsub(apex, foot)), perp(norm(vsub(apex, foot))), "gold", cc=False)
    cyl("Head", 0.55, 0.3, 0, 0, 2.9, "gold")
    cyl("Mount", 0.22, 0.45, 0, 0, 3.2, "gold")
    box("Yoke", 0.5, 0.36, 0.2, 0, 0, 3.55, "gold")
    e = math.radians(32)
    az = math.radians(55)                         # toward the viewer's right (-x), like the 2D
    ax = (-math.sin(az) * math.cos(e), math.cos(az) * math.cos(e), math.sin(e))
    c = (0.0, 0.05, 3.95)
    L = 2.7
    part("Tube", "Cylinder", (L, 0.56, 0.56), c, ax, perp(ax), "marble")
    for k, f in enumerate((-0.42, -0.1, 0.3)):
        part("TubeBand%d" % k, "Cylinder", (0.12, 0.64, 0.64), vadd(c, vmul(ax, f * L)), ax, perp(ax), "gold", cc=False)
    front = vadd(c, vmul(ax, L / 2 + 0.2))
    part("Hood", "Cylinder", (0.45, 0.74, 0.74), front, ax, perp(ax), "gold")
    part("Lens", "Cylinder", (0.04, 0.58, 0.58), vadd(front, vmul(ax, 0.23)), ax, perp(ax), "glass", c=(140, 190, 240), cc=False)
    back = vadd(c, vmul(ax, -L / 2 - 0.2))
    part("Eyepiece", "Cylinder", (0.4, 0.26, 0.26), back, ax, perp(ax), "gold", cc=False)
    # small finder scope on top
    up = perp(ax)
    fc = vadd(c, vmul(up, 0.42), vmul(ax, 0.25))
    part("Finder", "Cylinder", (1.0, 0.18, 0.18), fc, ax, up, "marble", cc=False)
    part("FinderRing", "Cylinder", (0.1, 0.24, 0.24), vadd(fc, vmul(ax, 0.48)), ax, up, "gold", cc=False)
    rod("FinderPost", vadd(c, vmul(up, 0.25)), vadd(fc, vmul(up, -0.08)), 0.08, "gold", cc=False)


@kit("NEW_WaterBuckets", 2.5, "art/out/s2/halo/kits_new/HaloKit_WaterBuckets_front.png", mirror=True)
def water_buckets():
    for k, (x, y, d, h) in enumerate(((-0.6, 0.2, 1.25, 1.15), (0.55, -0.35, 1.2, 1.1))):
        cyl("Bucket%d" % k, d, h, x, y, 0, "wood")
        cyl("BandLo%d" % k, d + 0.06, 0.16, x, y, 0.12, "cloth", c=(250, 248, 240), cc=False)
        cyl("BandStripe%d" % k, d + 0.08, 0.08, x, y, 0.16, "cloth", c=(110, 170, 235), cc=False)
        cyl("BandHi%d" % k, d + 0.06, 0.14, x, y, h - 0.3, "gold", cc=False)
        cyl("Water%d" % k, d - 0.16, 0.03, x, y, h, "water", cc=False)
        for sx in (-1, 1):                         # rope handle: two side posts + bar
            px = x + sx * (d / 2 - 0.02)
            rod("HandleSide%d%d" % (k, sx), (px, y, h - 0.15), (x + sx * 0.32, y, h + 0.42), 0.07, "rope", cc=False)
        rod("HandleBar%d" % k, (x - 0.32, y, h + 0.42), (x + 0.32, y, h + 0.42), 0.08, "rope", cc=False)
    # long rake leaning on the buckets
    p0, p1 = (0.95, 0.75, 0.3), (-0.05, -0.2, 2.45)
    rod("RakeHandle", p0, p1, 0.12, "wood")
    cyl_ax = norm(vsub(p1, p0))
    part("RakeTip", "Cylinder", (0.22, 0.17, 0.17), vadd(p1, vmul(cyl_ax, 0.1)), cyl_ax, perp(cyl_ax), "cloth", c=(110, 170, 235), cc=False)
    ball("RakeTipBall", 0.18, *vadd(p1, vmul(cyl_ax, 0.24)), "gold", cc=False)
    hx = norm(cross(cyl_ax, UP))
    hc = vadd(p0, vmul(cyl_ax, -0.08))
    part("RakeHead", "Block", (0.85, 0.14, 0.14), hc, hx, perp(hx), "wood", cc=False)
    for k in range(5):
        q = vadd(hc, vmul(hx, -0.36 + 0.18 * k))
        rod("Tine%d" % k, q, (q[0] + 0.0, q[1] + 0.12, 0.0), 0.06, "wood", shape="Block", cc=False)


@kit("NEW_SteppingStones", 0.5, "art/out/s2/halo/kits_new/HaloKit_SteppingStones_front.png")
def stepping_stones():
    """Flat rounded-square stones in a loose line (2D: cream slabs with moss at the edges)."""
    stones = ((-3.1, 0.25, 1.25, 1.05, 12), (-1.75, -0.2, 1.4, 1.1, -8), (-0.35, 0.18, 1.3, 1.0, 20), (1.05, -0.22, 1.45, 1.1, -14),
              (2.4, 0.2, 1.25, 1.0, 6), (3.55, -0.12, 1.0, 0.9, -20))
    r = 0.22
    for k, (x, y, w, d, rot) in enumerate(stones):
        h = 0.42
        box("Stone%dA" % k, w - 2 * r, d, h, x, y, 0.0, "stone", rot=rot)
        box("Stone%dB" % k, w, d - 2 * r, h, x, y, 0.0, "stone", rot=rot)
        for sx in (-1, 1):
            for sy in (-1, 1):
                q = rotz((sx * (w / 2 - r), sy * (d / 2 - r), 0.0), rot)
                cyl("Stone%dC%d%d" % (k, sx, sy), 2 * r, h, x + q[0], y + q[1], 0.0, "stone", cc=False)
        # moss: flat, uneven patches tucked under one or two edges (round green balls in pairs read as a face, 디자인 검수 10/11)
        for j, (ang, dd) in enumerate(((35 + 83 * k, 0.55), (160 + 61 * k, 0.4))[: 1 + k % 2]):
            a = math.radians(ang)
            cyl("Moss%d_%d" % (k, j), dd, 0.07, x + math.cos(a) * w * 0.46, y + math.sin(a) * d * 0.46, 0.0, "leaf",
                c=(108, 150, 70), cc=False)
            cyl("Moss%d_%db" % (k, j), dd * 0.6, 0.06, x + math.cos(a + 0.5) * w * 0.52, y + math.sin(a + 0.5) * d * 0.52, 0.0,
                "leaf", c=(120, 165, 78), cc=False)


# ---------------------------------------------------------------- kits: chunk 2 (lamps, bell)
def hexa(n, s, h, x, y, z0, m="gold", **kw):
    """Regular hexagonal prism (side s, flats toward +-y): three boxes s x s*sqrt3 turned 0 / 60 / 120 deg."""
    for k in range(3):
        box("%s%d" % (n, k), s, s * math.sqrt(3), h, x, y, z0, m, rot=60 * k, **kw)


def arc(n, R, w, t, centre, a0, a1, m="gold", axis=EY, **kw):
    """Exact circular arc band (CSG): radius R to the band middle, width w (radial), thickness t along axis, from angle
    a0 to a1 (deg, in the plane at right angles to axis; 0 = the plane's first direction, 90 = up). Only quarter arcs
    (a1 - a0 = 90) inside one quadrant."""
    u = norm(cross(axis, UP)) if abs(dot(axis, UP)) < 0.9 else EX     # in-plane first direction
    v = UP if abs(dot(axis, UP)) < 0.9 else norm(cross(axis, u))
    hole = cut(part, n + "_in", "Cylinder", (t + 0.2, 2 * R - w, 2 * R - w), centre, axis, v, m)
    am = math.radians((a0 + a1) / 2)
    q = vadd(centre, vmul(u, math.cos(am) * (R + w) / 2 * 1.0), vmul(v, math.sin(am) * (R + w) / 2))
    # quadrant box: from the centre out to R + w along both edge directions
    e0 = vadd(vmul(u, math.cos(math.radians(a0))), vmul(v, math.sin(math.radians(a0))))
    e1 = vadd(vmul(u, math.cos(math.radians(a1))), vmul(v, math.sin(math.radians(a1))))
    qc = vadd(centre, vmul(vadd(e0, e1), (R + w) / 2))
    quad = cut(part, n + "_q", "Block", (R + w, R + w, t + 0.2), qc, e0, e1, m)
    return part(n, "Cylinder", (t, 2 * R + w, 2 * R + w), centre, axis, v, m, ops=[("minus", [hole]), ("and", [quad])], **kw)


def dome(n, dia, x, y, z0, m="gold", **kw):
    """Exact half ball standing on z0 (ball AND upper box)."""
    top = cut(box, n + "_cut", dia + 0.2, dia + 0.2, dia / 2 + 0.1, x, y, z0, m)
    return part(n, "Ball", (dia, dia, dia), (x, y, z0), EX, UP, m, ops=[("and", [top])], **kw)


def lantern_head(n, x, y, z0, s=0.42, gh=0.76, hang=False):
    """Hexagonal lantern: gold base plate, warm glass (LampLight), gold corner posts, neon core, stepped gold roof,
    ball finial (+ a bottom drop when it hangs). Returns the top z."""
    if hang:
        ball(n + "_Drop", 0.2, x, y, z0 - 0.12, "gold", cc=False)
        cyl(n + "_DropNeck", 0.14, 0.12, x, y, z0 - 0.08, "gold", cc=False)
    hexa(n + "_Base", s + 0.1, 0.12, x, y, z0, "gold", cc=False)
    z = z0 + 0.12
    hexa(n + "_Glass", s, gh, x, y, z, "lamp", cc=False)
    cyl(n + "_Core", s * 0.6, gh * 0.55, x, y, z + gh * 0.2, "neon", cc=False)
    for k in range(6):
        a = math.radians(60 * k)
        cyl("%s_Post%d" % (n, k), 0.07, gh, x + s * math.cos(a), y + s * math.sin(a), z, "gold", cc=False)
    z += gh
    hexa(n + "_Top", s + 0.12, 0.1, x, y, z, "gold", cc=False)
    hexa(n + "_Roof1", s * 0.8, 0.12, x, y, z + 0.1, "gold", cc=False)
    hexa(n + "_Roof2", s * 0.5, 0.12, x, y, z + 0.22, "gold", cc=False)
    ball(n + "_Fin", 0.22, x, y, z + 0.44, "gold", cc=False)
    return z + 0.56


def frame_panel(n, centre, nrm, w, h, fr=0.06, t=0.04):
    """Gold outline (four strips) on a marble face: the 2D lamp-post panels."""
    X, _ = face_axes(nrm)
    for k, (du, dv, ww, hh) in enumerate(((0, h / 2, w, fr), (0, -h / 2, w, fr), (w / 2, 0, fr, h), (-w / 2, 0, fr, h))):
        plate("%s%d" % (n, k), ww + (fr if hh == fr else 0), hh, t, vadd(centre, vmul(X, du), (0, 0, dv)), nrm, "gold")


FACES = (EY, (0.0, -1.0, 0.0), EX, (-1.0, 0.0, 0.0))


@kit("HaloVar4_Lantern_A", 7.0, "art/out/s2/halo/props4/HaloProp4_LanternA_front.png")
def lantern_a():
    box("Plinth", 1.5, 1.5, 0.3, 0, 0, 0)
    box("Step", 1.25, 1.25, 0.2, 0, 0, 0.3)
    box("StepBand", 1.3, 1.3, 0.07, 0, 0, 0.41, "gold")
    box("Base", 1.0, 1.0, 1.05, 0, 0, 0.5)
    for k, f in enumerate(FACES):
        frame_panel("BasePanel%d_" % k, vadd((0, 0, 1.02), vmul(f, 0.5)), f, 0.6, 0.62, fr=0.05)
    z = cap("BaseCap", 1.0, 1.0, 0, 0, 1.55, t=0.15)
    box("ShaftBand", 0.66, 0.66, 0.12, 0, 0, z, "gold")
    box("Shaft", 0.56, 0.56, 4.75 - z - 0.12, 0, 0, z + 0.12)
    for k, f in enumerate(FACES):
        frame_panel("ShaftPanel%d_" % k, vadd((0, 0, 3.3), vmul(f, 0.28)), f, 0.3, 2.5, fr=0.045)
    z = cap("ShaftCap", 0.56, 0.56, 0, 0, 4.75, t=0.12)
    ball("Knob", 0.62, 0, 0, z + 0.28, "marble")
    cyl("KnobCollar", 0.46, 0.12, 0, 0, z + 0.52, "gold")
    top = lantern_head("Head", 0, 0, z + 0.64, s=0.5, gh=0.9)
    spike("HeadSpike", 0, 0, top - 0.02, 7.0 - top, 0.16)


@kit("HaloVar4_Lantern_B", 7.0, "art/out/s2/halo/props4/HaloProp4_LanternB_front.png")
def lantern_b():
    box("Plinth", 3.6, 3.6, 0.25, 0, 0, 0)
    box("Step", 3.3, 3.3, 0.2, 0, 0, 0.25)
    box("StepBand", 3.36, 3.36, 0.08, 0, 0, 0.35, "gold")
    box("Block", 2.9, 2.9, 2.95, 0, 0, 0.45)
    for k, f in enumerate(FACES):
        frame_panel("Panel%d_" % k, vadd((0, 0, 1.9), vmul(f, 1.45)), f, 1.5, 2.0, fr=0.09)
    z = cap("Cap", 2.9, 2.9, 0, 0, 3.4, t=0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            ball("CornerBall%d%d" % (sx, sy), 0.42, sx * 1.35, sy * 1.35, z + 0.21, "gold", cc=False)
    cyl("GlobeFoot", 1.6, 0.3, 0, 0, z, "gold")
    cyl("GlobeFootRing", 1.95, 0.12, 0, 0, z + 0.06, "gold", cc=False)
    gc = z + 0.3 + 1.15
    ball("Globe", 2.3, 0, 0, gc, "lamp", cc=True)
    cyl("Core", 0.9, 0.9, 0, 0, gc - 0.45, "neon", cc=False)
    ring("Equator", 2.42, 2.22, 0.16, 0, 0, gc, "gold", cc=False)
    ring("MeridianX", 2.4, 2.22, 0.12, 0, 0, gc, "gold", axis=EX, cc=False)
    ring("MeridianY", 2.4, 2.22, 0.12, 0, 0, gc, "gold", axis=EY, cc=False)
    cyl("TopCap", 0.72, 0.22, 0, 0, gc + 1.08, "gold")
    gold_ball("TopBall", 0.42, 0, 0, gc + 1.3)


def lamp_post(n, h_shaft, z_base=0.0):
    """Square post of lamps C / D: plinth, base block with a gold panel, shaft with outline panels, cap."""
    box(n + "Plinth", 1.25, 1.25, 0.3, 0, 0, z_base)
    box(n + "Step", 1.05, 1.05, 0.2, 0, 0, z_base + 0.3)
    box(n + "StepBand", 1.1, 1.1, 0.07, 0, 0, z_base + 0.41, "gold")
    box(n + "Base", 0.85, 0.85, 1.0, 0, 0, z_base + 0.5)
    for k, f in enumerate(FACES):
        frame_panel("%sBasePanel%d_" % (n, k), vadd((0, 0, z_base + 1.0), vmul(f, 0.425)), f, 0.46, 0.56, fr=0.045)
    z = cap(n + "BaseCap", 0.85, 0.85, 0, 0, z_base + 1.5, t=0.14)
    box(n + "ShaftBand", 0.58, 0.58, 0.12, 0, 0, z, "gold")
    box(n + "Shaft", 0.48, 0.48, h_shaft, 0, 0, z + 0.12)
    for k, f in enumerate(FACES):
        frame_panel("%sShaftPanel%d_" % (n, k), vadd((0, 0, z + 0.12 + h_shaft * 0.5), vmul(f, 0.24)), f, 0.24, h_shaft * 0.8, fr=0.04)
    return z + 0.12 + h_shaft


@kit("HaloVar4_Lantern_C", 7.0, "art/out/s2/halo/props4/HaloProp4_LanternC_front.png")
def lantern_c():
    zt = lamp_post("", 3.8)                       # ~5.6
    box("ShaftBand2", 0.58, 0.58, 0.1, 0, 0, zt, "gold")
    R = 0.85
    zc = zt + 0.1
    # marble arm: up from the post top, curving over to the viewer's right (-x), then a short straight end
    arc("Arm", R, 0.36, 0.36, (-R, 0.0, zc), 0, 90, "marble", cc=False)
    box("ArmEnd", 0.6, 0.36, 0.36, -R - 0.3, 0, zc + R - 0.18)
    box("ArmEndBlock", 0.42, 0.42, 0.42, -R - 0.75, 0, zc + R - 0.21)
    box("ArmEndBand", 0.46, 0.46, 0.06, -R - 0.75, 0, zc + R - 0.24, "gold", cc=False)
    gold_ball("ArmEndBall", 0.3, -R - 0.75, 0, zc + R + 0.21)
    gold_ball("PostTopBall", 0.3, 0.0, 0, zc + 0.02, neck=False)
    # gold scroll inside the curve
    arc("Scroll", R * 0.55, 0.07, 0.1, (-R, 0.0, zc), 0, 90, "gold", cc=False)
    rod("ScrollStem", (-0.24, 0.0, zt - 0.9), (-0.24, 0.0, zc), 0.07, "gold", cc=False)
    # hanging lantern under the arm end
    hx = -R - 0.75
    rod("Chain", (hx, 0, zc + R - 0.42), (hx, 0, zc + R - 0.62), 0.06, "gold", cc=False)
    lantern_head("Head", hx, 0, zc + R - 0.62 - 1.38, s=0.4, gh=0.75, hang=True)


@kit("HaloVar4_Lantern_D", 7.0, "art/out/s2/halo/props4/HaloProp4_LanternD_front.png")
def lantern_d():
    zt = lamp_post("", 3.6)
    box("Hub", 0.62, 0.62, 0.7, 0, 0, zt)
    for k, f in enumerate(FACES[:2]):
        frame_panel("HubPanel%d_" % k, vadd((0, 0, zt + 0.35), vmul(f, 0.31)), f, 0.3, 0.4, fr=0.035)
    za = zt + 0.45
    box("Bar", 3.2, 0.36, 0.32, 0, 0, za, "marble")
    box("BarBand", 3.2, 0.4, 0.06, 0, 0, za + 0.32, "gold", cc=False)
    z = cap("HubCap", 0.62, 0.62, 0, 0, zt + 0.7, t=0.12)
    box("Top", 0.4, 0.4, 0.35, 0, 0, z)
    z = cap("TopCap", 0.4, 0.4, 0, 0, z + 0.35, t=0.1)
    gold_ball("TopBall", 0.34, 0, 0, z)
    for sx in (-1, 1):
        ex = sx * 1.6
        box("End%d" % sx, 0.4, 0.4, 0.45, ex, 0, za - 0.08)
        gold_ball("EndBall%d" % sx, 0.26, ex, 0, za + 0.37)
        # gold brace curve under each arm
        arc("Brace%d" % sx, 0.55, 0.07, 0.08, (sx * 0.86, 0.0, za - 0.55), 90 if sx > 0 else 0, 180 if sx > 0 else 90, "gold", cc=False)
        rod("Chain%d" % sx, (ex, 0, za - 0.08), (ex, 0, za - 0.3), 0.06, "gold", cc=False)
        lantern_head("Head%d" % sx, ex, 0, za - 0.3 - 1.3, s=0.36, gh=0.7, hang=True)


@kit("HaloVar3_Lantern_E", 7.0, "art/out/s2/halo/props4/HaloProp4_LanternE_front.png")
def lantern_e():
    box("Plinth", 3.0, 3.0, 0.3, 0, 0, 0)
    box("Step", 2.7, 2.7, 0.25, 0, 0, 0.3)
    box("StepBand", 2.76, 2.76, 0.08, 0, 0, 0.45, "gold")
    box("Block", 2.35, 2.35, 2.85, 0, 0, 0.55)
    for k, f in enumerate(FACES):
        inlay("Win%d" % k, vadd((0, 0, 1.95), vmul(f, 1.175)), f, 0.62, 1.05, "rect", fr=0.09)
    z = cap("Cap", 2.35, 2.35, 0, 0, 3.4, t=0.24)
    cyl("HeadFoot", 1.95, 0.16, 0, 0, z, "gold")
    gz = z + 0.16
    gh = 1.25
    cyl("Glass", 1.45, gh, 0, 0, gz, "lamp")
    cyl("Core", 0.7, gh * 0.6, 0, 0, gz + gh * 0.2, "neon", cc=False)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        cyl("Post%d" % k, 0.16, gh, 0.74 * math.cos(a), 0.74 * math.sin(a), gz, "gold", cc=False)
        ball("PostBall%d" % k, 0.16, 0.74 * math.cos(a), 0.74 * math.sin(a), gz + gh + 0.02, "gold", cc=False)
    cyl("Rim", 1.8, 0.2, 0, 0, gz + gh, "gold")
    dome("Dome", 1.62, 0, 0, gz + gh + 0.2, "gold")
    zt = gz + gh + 0.2 + 0.81
    spike("Spike", 0, 0, zt - 0.05, 7.0 - zt + 0.05, 0.26)


@kit("NEW_WallLamp", 1.5, "art/out/s2/halo/kits_mv/HaloKit_WallLamp_front_HQ_src.png",
     note="origin = the wall face at the plate's foot; the lamp sticks out along +y")
def wall_lamp():
    chamfer_slab("Plate", 0.56, 1.5, 0.12, (0, 0.06, 0.75), 0.12, "marble")
    inner = chamfer_slab("PlateRim_in", 0.44, 1.38, 0.3, (0, 0.14, 0.75), 0.08, "gold", keep=False)
    chamfer_slab("PlateRim", 0.58, 1.52, 0.04, (0, 0.14, 0.75), 0.13, "gold", cc=False)["ops"][0][1].append(inner)
    inlay("PlateWin", (0, 0.12, 0.75), EY, 0.12, 0.6, "hex", fr=0.035)
    box("ArmBlock", 0.24, 0.3, 0.24, 0, 0.3, 1.1, "marble")
    box("Arm", 0.16, 0.75, 0.16, 0, 0.8, 1.2, "gold", cc=False)
    arc("ArmBrace", 0.32, 0.06, 0.08, (0.0, 0.47, 0.88), 0, 90, "gold", axis=EX, cc=False)
    box("ArmEnd", 0.24, 0.24, 0.2, 0, 1.18, 1.14, "marble", cc=False)
    rod("Chain", (0, 1.18, 1.14), (0, 1.18, 1.02), 0.05, "gold", cc=False)
    lantern_head("Head", 0, 1.18, 0.12, s=0.22, gh=0.45, hang=True)


@kit("NEW_BellFrame", 6.0, "art/out/s2/halo/kits_mv/HaloKit_BellFrame_front_HQ_src.png")
def bell_frame():
    for sx in (-1, 1):
        x = sx * 1.15
        pedestal("Pillar%d" % sx, 0.82, 0.82, 4.6, x, 0.0, plinth=0.35)
        for k, f in enumerate(FACES[:2]):
            inlay("PillarWin%d%d" % (sx, k), vadd((x, 0, 2.6), vmul(f, 0.41)), f, 0.24, 1.1, "arch", fr=0.05)
        z = cap("PillarCap%d" % sx, 0.82, 0.82, x, 0, 4.6, t=0.16)
        onion("PillarDome%d" % sx, 0.55, x, 0, z, tip=0.35)
    rod("Beam", (-0.75, 0, 4.25), (0.75, 0, 4.25), 0.32, "wood", shape="Block")
    for sx in (-1, 1):
        box("BeamCap%d" % sx, 0.08, 0.38, 0.38, sx * 0.75, 0, 4.06, "gold", cc=False)
    cyl_ax = EX
    part("RopeWrap", "Cylinder", (0.36, 0.38, 0.38), (0, 0, 4.25), cyl_ax, UP, "rope", cc=False)
    rod("Rope", (0, 0, 4.1), (0, 0, 3.8), 0.08, "rope", cc=False)
    # bell: crown loop, half-ball top, waist, flared lip, clapper (1.4x of the first try, 2D bell ~ 40 % of the gap)
    ring("BellLoop", 0.3, 0.15, 0.08, 0, 0, 3.76, "gold", axis=EY, cc=False)
    dome("BellTop", 0.86, 0, 0, 3.2, "gold", cc=False)
    cyl("BellWaist", 0.86, 0.55, 0, 0, 2.65, "gold", cc=False)
    cyl("BellFlare", 1.08, 0.18, 0, 0, 2.52, "gold", cc=False)
    cyl("BellLip", 1.24, 0.13, 0, 0, 2.42, "gold", cc=False)
    ball("Clapper", 0.28, 0, 0, 2.36, "gold", cc=False)


# ---------------------------------------------------------------- kits: chunk 3 (guard post, wood shed, clothesline, rack, fountain)
def cap_bowl(n, d, depth, y_rim, x=0.0, y=0.0, m="marble", **kw):
    """Solid bowl = spherical cap under a flat top at y_rim (sphere AND box below the rim), exact round."""
    a = d / 2
    Rs = (a * a + depth * depth) / (2 * depth)
    zc = y_rim - depth + Rs
    below = cut(box, n + "_cut", d + 0.4, d + 0.4, depth + 0.2, x, y, y_rim - depth - 0.1, m)
    return part(n, "Ball", (2 * Rs, 2 * Rs, 2 * Rs), (x, y, zc), EX, UP, m, ops=[("and", [below])], **kw)


def stripes_disc(n, d, t, centre, nrm, cols, count=3):
    """Round shield face: white disc + vertical blue stripes cut to the circle (CSG AND), facing nrm."""
    nrm = norm(nrm)
    X, _ = face_axes(nrm)
    Yf = norm(cross(X, nrm))                       # "up" inside the (maybe tilted) shield face
    part(n, "Cylinder", (t, d, d), centre, nrm, Yf, "cloth", c=cols[0], cc=False)
    w = d / (2 * count + 1)
    for k in range(count):
        u = -d / 2 + w * (2 * k + 1.5)
        disc = cut(part, "%s_d%d" % (n, k), "Cylinder", (t + 0.2, d, d), centre, nrm, Yf, "cloth")
        part("%s_S%d" % (n, k), "Block", (w, d, t + 0.02), vadd(centre, vmul(X, u)), X, Yf, "cloth", c=cols[1], cc=False,
             ops=[("and", [disc])])


@kit("HaloReasonHQ_GuardPost", 12.0, "art/out/s2/halo/props4/HaloProp4_ReasonGuard_front.png",
     note="small wall lantern heads are parts for now (Tripo heads come with the lamp batch)")
def guard_post():
    R = 2.8
    cyl("Plinth", 2 * R + 0.6, 0.4, 0, 0, 0)
    box("PlinthFront", 2 * R + 0.6, 1.8, 0.4, 0, R - 0.6, 0)
    box("PlinthBand", 2 * R + 0.2, 1.84, 0.08, 0, R - 0.6, 0.34, "gold")
    # body: round back + flat front, an arched service window cut into the front
    WW, WZ, WH = 3.2, 1.7, 2.6                       # window width, sill, straight height (+ half-round top)
    def win():
        return [cut(box, "WinHole", WW, 3.0, WH, 0, R, WZ), cut(part, "WinTop", "Cylinder", (3.0, WW, WW), (0, R, WZ + WH), EY, UP, "marble")]
    cyl("Body", 2 * R, 7.1, 0, 0, 0.4, "mblock", ops=[("minus", win())])
    box("Front", 2 * R, 1.6, 7.1, 0, R - 0.8, 0.4, "mblock", ops=[("minus", win())])
    box("NicheBack", WW, 0.14, WH + WW / 2, 0, R - 1.45, WZ, "wood", cc=False)
    for k in range(3):
        box("Shelf%d" % k, WW - 0.1, 0.5, 0.08, 0, R - 1.15, WZ + 0.9 + 0.8 * k, "wood", cc=False)
    box("Counter", WW + 0.3, 1.2, 0.24, 0, R - 0.25, WZ - 0.24, "wood")
    box("CounterFront", WW + 0.3, 0.12, WZ - 0.4, 0, R + 0.3, 0.4, "wood")
    box("CounterGold", WW + 0.3, 0.06, 0.26, 0, R + 0.36, WZ - 0.25, "gold", cc=False)
    # gold arch band round the window
    part("WinArch", "Cylinder", (0.12, WW + 0.36, WW + 0.36), (0, R + 0.02, WZ + WH), EY, UP, "gold", cc=False,
         ops=[("minus", [cut(part, "AB_i", "Cylinder", (0.3, WW, WW), (0, R + 0.02, WZ + WH), EY, UP, "gold"),
                         cut(box, "AB_low", WW + 0.6, 0.4, 2.0, 0, R + 0.02, WZ + WH - 2.0, "gold")])])
    for sx in (-1, 1):
        box("WinJamb%d" % sx, 0.16, 0.12, WH, sx * (WW / 2 + 0.08), R + 0.02, WZ, "gold", cc=False)
    # striped awning over the window (Fabric), scalloped edge = half discs
    ang = math.radians(28)
    nrm = (0.0, math.sin(ang), math.cos(ang))
    down = (0.0, math.cos(ang), -math.sin(ang))
    top = (0.0, R + 0.05, WZ + WH + 0.35)
    n_str = 7
    for k in range(n_str):
        x = -1.7 + 3.4 / n_str * (k + 0.5)
        col = (110, 170, 235) if k % 2 == 0 else (250, 248, 240)
        part("Awning%d" % k, "Block", (3.4 / n_str, 0.08, 1.3), vadd((x, 0, 0), top, vmul(down, 0.65)), EX, nrm, "cloth", c=col, cc=False)
        edge = vadd((x, 0, 0), top, vmul(down, 1.3))
        part("Scallop%d" % k, "Cylinder", (0.06, 3.4 / n_str, 3.4 / n_str), vadd(edge, (0, 0.02, -0.0)), EY, UP, "cloth", c=col, cc=False)
    # pilasters at the front corners with small wall lanterns
    for sx in (-1, 1):
        x = sx * (R - 0.35)
        box("Pilaster%d" % sx, 0.7, 0.5, 7.1, x, R - 0.05, 0.4, "marble")
        box("PilasterCap%d" % sx, 0.86, 0.66, 0.2, x, R - 0.05, 7.3, "gold")
        box("LampArm%d" % sx, 0.12, 0.5, 0.12, x, R + 0.4, 4.4, "gold", cc=False)
        lantern_head("Lamp%d" % sx, x, R + 0.6, 3.5, s=0.2, gh=0.42, hang=True)
    # cornice, drum, dome, finial
    cyl("CorniceGold", 2 * R + 0.2, 0.18, 0, 0, 7.5, "gold")
    box("CorniceFront", 2 * R + 0.2, 1.7, 0.18, 0, R - 0.8, 7.5, "gold")
    cyl("Cornice", 2 * R + 0.4, 0.3, 0, 0, 7.68, "marble")
    box("CorniceFrontM", 2 * R + 0.4, 1.8, 0.3, 0, R - 0.8, 7.68, "marble")
    cyl("Drum", 2 * R - 0.6, 0.5, 0, 0, 7.98, "marble")
    cyl("DrumGold", 2 * R - 0.4, 0.12, 0, 0, 8.4, "gold")
    dome("Dome", 2 * R - 0.6, 0, 0, 8.48, "gold")
    zt = 8.48 + R - 0.3
    cyl("FinialBase", 0.7, 0.2, 0, 0, zt - 0.05, "gold")
    ball("FinialBall", 0.75, 0, 0, zt + 0.5, "gold", cc=False)
    spike("FinialSpike", 0, 0, zt + 0.8, 12.0 - zt - 0.8, 0.28)
    # notice sign on the viewer's right (-x): two posts + framed board
    sx = -1
    for k, dx in enumerate((-0.85, 0.85)):
        box("SignPost%d" % k, 0.3, 0.3, 4.2, sx * 4.2 + dx, R - 0.6, 0.0, "marble")
        gold_ball("SignBall%d" % k, 0.3, sx * 4.2 + dx, R - 0.6, 4.2, neck=False)
    box("SignBoard", 1.5, 0.12, 1.9, sx * 4.2, R - 0.6, 1.9, "paint", c=(250, 246, 236))
    box("SignFrame", 1.7, 0.08, 2.1, sx * 4.2, R - 0.68, 1.8, "gold", cc=False)


@kit("HaloReasonHQ_Woodpile", 4.9, "art/out/s2/halo/props4/HaloProp4_ReasonWood_front.png")
def woodpile():
    W, D = 6.0, 2.9
    box("Floor", W - 0.5, D - 0.5, 0.3, 0, 0, 0.05, "wood", c=(196, 130, 66))
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.25), sy * (D / 2 - 0.25)
            box("Foot%d%d" % (sx, sy), 0.62, 0.62, 0.62, x, y, 0, "marble")
            box("FootBand%d%d" % (sx, sy), 0.66, 0.66, 0.08, x, y, 0.5, "gold", cc=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.25), sy * (D / 2 - 0.25)
            box("Post%d%d" % (sx, sy), 0.42, 0.42, 3.0, x, y, 0.6, "wood", c=(196, 130, 66))
            box("PostBand%d%d" % (sx, sy), 0.48, 0.48, 0.1, x, y, 1.6, "gold", cc=False)
            box("PostCap%d%d" % (sx, sy), 0.5, 0.5, 0.12, x, y, 3.6, "gold", cc=False)
    for sy in (-1, 1):
        box("Beam%d" % sy, W, 0.3, 0.3, 0, sy * (D / 2 - 0.25), 3.6, "wood", c=(196, 130, 66))
    for sx in (-1, 1):
        box("BeamS%d" % sx, 0.3, D, 0.3, sx * (W / 2 - 0.25), 0, 3.6, "wood", c=(196, 130, 66))
    gable_roof("Roof", D + 0.4, W + 0.2, 1.0, 0, 0, 3.9, ridge="x", over=0.3, t=0.16, m="marble")
    for sx in (-1, 1):
        # blue gable triangle (two wedges, high side at the ridge) like the 2D
        gx = sx * (W / 2 + 0.1 + 0.04)          # just outside the roof's marble gable fill (ends at W / 2 + 0.1)
        for sy in (-1, 1):
            Z = (0.0, -sy, 0.0)
            part("Gable%d_%d" % (sx, sy), "Wedge", (0.08, 0.86, (D + 0.4) / 2 - 0.2), (gx, sy * ((D + 0.4) / 4 - 0.1), 3.9 + 0.43),
                 cross(UP, Z), UP, "blue", cc=False)
        gold_ball("RidgeBall%d" % sx, 0.3, sx * (W / 2 + 0.35), 0, 4.95, neck=False)
    # log stack: rows of logs lying front-back, pale wood with a darker end ring
    rows = ((0.4, 6), (1.1, 5), (1.8, 6), (2.5, 5))
    for r, (z, n) in enumerate(rows):
        span = W - 1.2
        d = span / 6
        for k in range(n):
            x = -span / 2 + d * (k + 0.5 + (0.5 if n == 5 else 0))
            part("Log%d_%d" % (r, k), "Cylinder", (D - 0.7, d * 0.95, d * 0.95), (x, 0, z + d * 0.47), EY, UP, "wood",
                 c=(178, 110, 52))
            for sy in (-1, 1):
                part("LogEnd%d_%d_%d" % (r, k, sy), "Cylinder", (0.03, d * 0.86, d * 0.86), (x, sy * (D / 2 - 0.34), z + d * 0.47), EY, UP,
                     "paint", c=(225, 165, 95), cc=False)
                ring("LogRing%d_%d_%d" % (r, k, sy), d * 0.62, d * 0.48, 0.035, x, sy * (D / 2 - 0.34), z + d * 0.47, "paint",
                     axis=EY, c=(170, 105, 55), cc=False)
                part("LogCore%d_%d_%d" % (r, k, sy), "Cylinder", (0.04, d * 0.16, d * 0.16), (x, sy * (D / 2 - 0.34), z + d * 0.47),
                     EY, UP, "paint", c=(170, 105, 55), cc=False)


@kit("HaloReasonHQ_Clothesline", 4.7, "art/out/s2/halo/props4/HaloProp4_ReasonCloth_front.png")
def clothesline():
    for sx in (-1, 1):
        x = sx * 4.3
        pedestal("Post%d" % sx, 1.0, 1.0, 4.1, x, 0.0, plinth=0.3)
        inlay("PostWin%d" % sx, (x, 0.5, 1.8), EY, 0.3, 1.1, "rect", fr=0.06)
        inlay("PostWinB%d" % sx, (x, -0.5, 1.8), (0, -1, 0), 0.3, 1.1, "rect", fr=0.06)
        z = cap("PostCap%d" % sx, 1.0, 1.0, x, 0, 4.1, t=0.16)
        gold_ball("PostBall%d" % sx, 0.55, x, 0, z)
    # rope with a little sag (two runs)
    zr, sag = 3.9, 0.35
    rod("RopeL", (3.8, 0, zr), (0, 0, zr - sag), 0.1, "paint", c=(214, 186, 136), cc=False)
    rod("RopeR", (0, 0, zr - sag), (-3.8, 0, zr), 0.1, "paint", c=(214, 186, 136), cc=False)
    blue, white, sky = (110, 170, 235), (250, 248, 240), (150, 196, 245)

    # 2D left to right (= +x to -x): big white towel with a blue band, small square one with a blue border,
    # plain blue one, big white one with blue stripes
    def zt_at(x):
        return zr - sag * (1 - abs(x) / 3.8)
    x, w, h = 2.45, 1.75, 2.3
    box("Towel0", w, 0.05, h, x, 0.0, zt_at(x) - h, "cloth", c=white, cc=False)
    box("Towel0Band", w, 0.06, 0.24, x, 0.0, zt_at(x) - h + 0.3, "cloth", c=blue, cc=False)
    box("Towel0Line", w, 0.06, 0.07, x, 0.0, zt_at(x) - h + 0.62, "cloth", c=blue, cc=False)
    x = 1.0
    box("Towel1Edge", 0.92, 0.05, 0.92, x, 0.0, zt_at(x) - 0.92, "cloth", c=blue, cc=False)
    box("Towel1", 0.76, 0.06, 0.76, x, 0.0, zt_at(x) - 0.84, "cloth", c=white, cc=False)
    x = -0.2
    box("Towel2", 1.0, 0.05, 1.45, x, 0.0, zt_at(x) - 1.45, "cloth", c=sky, cc=False)
    x, w, h = -1.95, 1.7, 2.55
    box("Towel3", w, 0.05, h, x, 0.0, zt_at(x) - h, "cloth", c=white, cc=False)
    for j in range(3):
        box("Towel3Stripe%d" % j, w * 0.15, 0.06, h, x - w * 0.33 + j * w * 0.33, 0.0, zt_at(x) - h, "cloth", c=blue, cc=False)
    for k, (x, w) in enumerate(((2.45, 1.75), (1.0, 0.92), (-0.2, 1.0), (-1.95, 1.7))):
        for sxp in (-1, 1):
            box("Peg%d_%d" % (k, sxp), 0.08, 0.14, 0.26, x + sxp * w * 0.36, 0.0, zt_at(x) - 0.14, "wood", cc=False)
    # one warm-wood basket with folded towels in front of the left post (2D)
    x = 3.2
    box("Basket", 1.8, 1.25, 0.85, x, 1.0, 0, "wood", c=(205, 140, 76))
    for j, zz in enumerate((0.28, 0.56)):
        seam("BasketSeam%d" % j, (x, 1.0 + 0.625, zz), EY, 1.6)
    box("BasketRim", 1.88, 1.33, 0.12, x, 1.0, 0.77, "gold", cc=False)
    for j, col in enumerate((white, blue, white)):
        box("Folded%d" % j, 1.35, 0.95, 0.18, x, 1.0, 0.89 + j * 0.18, "cloth", c=col, cc=False)
    box("FoldedHang", 0.7, 0.05, 0.75, x - 0.3, 1.66, 0.4, "cloth", c=white, cc=False)


@kit("HaloReasonHQ_RackShieldSword", 4.9, "art/out/s2/halo/props4/HaloProp4_ReasonRack_front.png")
def rack_shield_sword():
    for sx in (-1, 1):
        x = sx * 2.3
        pedestal("Pillar%d" % sx, 0.75, 0.75, 4.1, x, 0.0, plinth=0.3)
        for k, f in enumerate(FACES[:2]):
            inlay("PillarWin%d%d" % (sx, k), vadd((x, 0, 2.2), vmul(f, 0.375)), f, 0.22, 1.2, "rect", fr=0.05)
        z = cap("PillarCap%d" % sx, 0.75, 0.75, x, 0, 4.1, t=0.14)
        gold_ball("PillarBall%d" % sx, 0.46, x, 0, z)
        # pennant on a gold arm outside the pillar
        px = x + sx * 0.75
        rod("PennantArm%d" % sx, (x + sx * 0.38, 0, 3.75), (px + sx * 0.1, 0, 3.75), 0.08, "gold", cc=False)
        box("Pennant%d" % sx, 0.5, 0.05, 1.0, px, 0, 2.75, "cloth", c=(110, 170, 235), cc=False)
        box("PennantStripe%d" % sx, 0.14, 0.06, 1.0, px, 0, 2.75, "cloth", c=(250, 248, 240), cc=False)
        part("PennantTip%d" % sx, "Block", (0.354, 0.354, 0.05), (px, 0, 2.75), norm((1, 0, 1)), norm((-1, 0, 1)), "cloth",
             c=(110, 170, 235), cc=False)
    WOOD = (196, 130, 66)
    box("TopBeam", 3.9, 0.36, 0.42, 0, 0, 3.15, "wood", c=WOOD)
    for k, bx in enumerate((-1.86, -0.62, 0.62, 1.86)):
        box("TopBracket%d" % k, 0.24, 0.42, 0.56, bx, 0.02, 3.08, "gold", cc=False)
        ball("TopBolt%d" % k, 0.12, bx, 0.24, 3.36, "gold", cc=False)
    box("LowBeam", 3.9, 0.5, 0.3, 0, 0, 0.3, "marble")
    box("MidBar", 3.9, 0.3, 0.26, 0, 0.0, 1.6, "wood", c=WOOD)
    for k, bx in enumerate((-1.86, 1.86)):
        box("MidBracket%d" % k, 0.24, 0.36, 0.4, bx, 0.02, 1.53, "gold", cc=False)
    # three wooden practice swords hanging point-down in front of the top beam (2D: wide blade, gold guard, blue grip)
    for k, x in enumerate((-1.25, 0.0, 1.25)):
        y, zg = 0.26, 3.36                              # guard centre height
        box("Blade%d" % k, 0.5, 0.1, 1.4, x, y, zg - 0.07 - 1.4, "wood", c=(222, 172, 110), cc=False)
        part("Tip%d" % k, "Block", (0.354, 0.354, 0.1), (x, y, zg - 0.07 - 1.4), norm((1, 0, 1)), norm((-1, 0, 1)), "wood",
             c=(222, 172, 110), cc=False)
        box("Fuller%d" % k, 0.06, 0.11, 1.0, x, y, zg - 1.25, "groove", c=(196, 146, 90), cc=False)
        box("Guard%d" % k, 0.92, 0.2, 0.2, x, y, zg - 0.1, "gold", cc=False)
        box("Grip%d" % k, 0.24, 0.22, 0.55, x, y, zg + 0.1, "blue", cc=False)
        for j, zz in enumerate((0.24, 0.44)):
            box("GripRing%d_%d" % (k, j), 0.28, 0.26, 0.05, x, y, zg + 0.1 + zz, "gold", cc=False)
        box("PommelNeck%d" % k, 0.3, 0.26, 0.08, x, y, zg + 0.65, "gold", cc=False)
        ball("Pommel%d" % k, 0.42, x, y, zg + 0.92, "gold", cc=False)
    # two round shields leaning in front, white with blue stripes, gold rim + boss, wooden back
    for k, x in enumerate((-0.9, 0.9)):
        c = (x, 0.55, 1.0)
        nrm = norm((0.0, 1.0, 0.25))
        stripes_disc("Shield%d" % k, 1.5, 0.12, c, nrm, ((250, 248, 240), (110, 170, 235)))
        part("ShieldBack%d" % k, "Cylinder", (0.14, 1.52, 1.52), vadd(c, vmul(nrm, -0.12)), nrm, perp(nrm), "wood")
        ring("ShieldRim%d" % k, 1.66, 1.42, 0.2, c[0], c[1], c[2], "gold", axis=nrm, cc=False)
        ball("ShieldBoss%d" % k, 0.44, *vadd(c, vmul(nrm, 0.08)), "gold", cc=False)


@kit("Town_Halo_Fountain3", 12.85, "art/out/s2/halo/HaloProp_Fountain_front_HQ_src.png",
     note="keep the model name Town_Halo_Fountain3: FountainFx draws the water by that name (fractions of 16 x 16 x 12.85)")
def fountain3():
    H = 12.85
    # basin wall (two tiers + coping) round the pool: outer d 16, inner d 14.56 (FountainFx pool R 0.45 x 16)
    ring("WallLo", 16.0, 14.4, 0.9, 0, 0, 0.45, "marble")
    ring("WallBand", 15.7, 14.5, 0.14, 0, 0, 0.97, "gold")
    ring("WallHi", 15.5, 14.56, 1.0, 0, 0, 1.54, "marble")
    ring("Coping", 15.8, 14.4, 0.3, 0, 0, 2.19, "marble")
    cyl("PoolFloor", 14.6, 0.3, 0, 0, 0, "marble")
    cyl("Water", 14.56, 0.06, 0, 0, 2.06, "water", cc=False)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        x, y = 7.55 * math.cos(a), 7.55 * math.sin(a)
        rot = math.degrees(a) + 90
        box("Pier%d" % k, 1.6, 1.6, 2.7, x, y, 0.0, "marble", rot=rot)
        box("PierBand%d" % k, 1.66, 1.66, 0.1, x, y, 2.6, "gold", rot=rot, cc=False)
        box("PierCap%d" % k, 1.8, 1.8, 0.2, x, y, 2.7, "marble", rot=rot)
        out = (math.cos(a), math.sin(a), 0.0)
        plate("PierPlate%d" % k, 0.45, 0.8, 0.05, vadd((x, y, 1.35), vmul(out, 0.8)), out, "gold")
        gold_ball("PierBall%d" % k, 0.95, x, y, 2.9)
    # centre: pedestal, middle bowl (water 0.53 H, rim R 0.25 x 16), stem, top bowl (water 0.75 H, rim R 0.15 x 16), finial
    cyl("PedFoot", 2.8, 0.5, 0, 0, 0.3, "marble")
    cyl("Ped", 2.1, 3.3, 0, 0, 0.8, "marble")
    cyl("PedCollar", 2.4, 0.35, 0, 0, 3.6, "gold")
    cyl("Stem1", 1.5, 1.2, 0, 0, 3.9, "marble")
    ym = 0.53 * H + 0.08
    cap_bowl("BowlMid", 8.0, 2.3, ym, m="marble")
    ring("BowlMidBand", 8.1, 7.0, 0.45, 0, 0, ym - 0.45, "gold", cc=False)
    ring("BowlMidRim", 8.15, 7.3, 0.18, 0, 0, ym + 0.02, "marble")
    cyl("BowlMidWater", 7.3, 0.04, 0, 0, ym - 0.02, "water", cc=False)
    cyl("Stem2", 1.0, 1.6, 0, 0, ym, "marble")
    cyl("Stem2Collar", 1.3, 0.3, 0, 0, ym + 0.4, "gold")
    yt = 0.75 * H + 0.06
    cap_bowl("BowlTop", 4.8, 1.4, yt, m="marble")
    ring("BowlTopBand", 4.88, 4.1, 0.3, 0, 0, yt - 0.3, "gold", cc=False)
    ring("BowlTopRim", 4.9, 4.3, 0.14, 0, 0, yt + 0.02, "marble")
    cyl("BowlTopWater", 4.3, 0.04, 0, 0, yt - 0.02, "water", cc=False)
    cyl("Spout", 0.75, 0.75, 0, 0, yt, "marble")
    cyl("SpoutCollar", 0.9, 0.2, 0, 0, yt + 0.55, "gold")
    ball("TopBall", 1.3, 0, 0, 0.85 * H, "gold", cc=False)
    spike("TopSpike", 0, 0, 0.85 * H + 0.55, H - 0.85 * H - 0.55, 0.36)


# ---------------------------------------------------------------- kits: chunk 4 = (가+나) bodies (the plant / bread / veg on top is a
# Tripo piece; a body kit is named <Kit>__Body so halo_props_place.py does not swap it in before the plant is added)
def octa(n, w, h, x, y, z0, m="marble", **kw):
    """Regular octagonal prism, flat-to-flat w, faces toward 0 / 45 / 90 ... deg (box AND the box turned 45 deg)."""
    other = cut(box, n + "_r", w, w, h + 0.02, x, y, z0 - 0.01, m, rot=45)
    return box(n, w, w, h, x, y, z0, m, ops=[("and", [other])], **kw)


def soil(n, d, x, y, z, shape="round", m="soil"):
    """Soil / moss top a little under the rim (the Tripo plant stands on it)."""
    if shape == "round":
        cyl(n, d, 0.07, x, y, z - 0.04, m, cc=False)
    elif shape == "oct":
        octa(n, d, 0.07, x, y, z - 0.04, m, cc=False)
    else:
        box(n, d[0], d[1], 0.07, x, y, z - 0.04, m, cc=False)


def rim_box(n, w, d, h, t, x, y, z0, m="gold", **kw):
    """Square frame rim (box minus the inner box), t = frame width."""
    hole = cut(box, n + "_in", w - 2 * t, d - 2 * t, h + 0.2, x, y, z0 - 0.1, m)
    return box(n, w, d, h, x, y, z0, m, ops=[("minus", [hole])], **kw)


def octa_ring(n, w, t, h, x, y, z0, m="gold", **kw):
    """Octagonal frame rim: octagon w minus octagon w - 2 t."""
    o = octa(n, w, h, x, y, z0, m, **kw)
    inner = cut(octa, n + "_in", w - 2 * t, h + 0.2, x, y, z0 - 0.1, m)
    P.remove(inner) if inner in P else None
    o["ops"] = o.get("ops", []) + [["minus", [inner]]]
    return o


def foot(n, d, h, x=0.0, y=0.0, z0=0.0):
    """Round gold-ringed foot of a vase / bowl. Returns the top z."""
    cyl(n + "Gold", d + 0.12, 0.12, x, y, z0, "gold")
    cyl(n, d, h, x, y, z0 + 0.12, "marble")
    cyl(n + "Ring", d * 0.8, 0.1, x, y, z0 + 0.12 + h, "gold", cc=False)
    return z0 + 0.22 + h


def round_inlays(n, r, z, count, w, h, kind="arch", a0=0.0, fr=0.05):
    for k in range(count):
        nrm = hdir(a0 + 360.0 / count * k)
        inlay("%s%d" % (n, k), vadd((0, 0, z), vmul(nrm, r * 0.97)), nrm, w, h, kind, fr=fr)


@kit("HaloFlowerPotHQ_Daisy__Body", 1.65, "art/out/s2/halo/props4/HaloProp4_PotDaisy_front.png")
def pot_daisy():
    w = 2.7
    octa("BandLo", w + 0.12, 0.16, 0, 0, 0, "gold")
    octa("Body", w, 1.26, 0, 0, 0.16)
    octa_ring("Rim", w + 0.1, 0.25, 0.12, 0, 0, 1.42, "gold")
    octa_ring("Lip", w + 0.2, 0.3, 0.1, 0, 0, 1.54, "marble")
    side = w * math.tan(math.radians(22.5))
    for k in range(8):
        nrm = hdir(45 * k)
        frame_panel("Panel%d_" % k, vadd((0, 0, 0.8), vmul(nrm, w / 2)), nrm, side * 0.6, 0.72, fr=0.05)
        a = math.radians(22.5 + 45 * k)
        rc = (w / 2) / math.cos(math.radians(22.5))
        ball("Corner%d" % k, 0.24, rc * math.sin(a), rc * math.cos(a), 1.74, "gold", cc=False)
    soil("Soil", w - 0.1, 0, 0, 1.62, "oct")


@kit("HaloFlowerPotHQ_Tulip__Body", 1.55, "art/out/s2/halo/props4/HaloProp4_PotTulip_front.png")
def pot_tulip():
    w = 2.3
    box("Band", w + 0.1, w + 0.1, 0.14, 0, 0, 0, "gold")
    box("Body", w, w, 1.26, 0, 0, 0.14)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.15), sy * (w / 2 - 0.15)
            box("Post%d%d" % (sx, sy), 0.4, 0.4, 1.4, x, y, 0.0)
            gold_ball("PostBall%d%d" % (sx, sy), 0.26, x, y, 1.4, neck=False)
    for k, f in enumerate(FACES):
        frame_panel("Panel%d_" % k, vadd((0, 0, 0.75), vmul(f, w / 2)), f, w * 0.55, 0.7, fr=0.05)
        for sxp in (-1, 1):
            X, _ = face_axes(f)
            plate("Strip%d%d" % (k, sxp), 0.08, 1.0, 0.04, vadd((0, 0, 0.72), vmul(f, w / 2 + 0.05), vmul(X, sxp * (w / 2 - 0.15))), f, "gold")
    rim_box("Rim", w + 0.06, w + 0.06, 0.1, 0.3, 0, 0, 1.4, "marble")
    soil("Soil", (w - 0.3, w - 0.3), 0, 0, 1.46, "box")


@kit("HaloFlowerPotHQ_Sunflower__Body", 1.4, "art/out/s2/halo/props4/HaloProp4_PotSunflower_front.png")
def pot_sunflower():
    cyl("Lo", 1.85, 0.5, 0, 0, 0)
    cyl("Hi", 2.0, 0.85, 0, 0, 0.5)
    ring("Band0", 1.97, 1.7, 0.16, 0, 0, 0.18, "gold")
    ring("Band1", 2.12, 1.8, 0.18, 0, 0, 1.05, "gold")
    ring("Lip", 2.08, 1.7, 0.1, 0, 0, 1.38)
    soil("Soil", 1.9, 0, 0, 1.38)


@kit("HaloFlowerPotHQ_Rose__Body", 1.5, "art/out/s2/halo/props4/HaloProp4_PotRose_front.png")
def pot_rose():
    z = foot("Foot", 1.1, 0.25)
    cyl("Stem", 0.8, 0.25, 0, 0, z, "marble")
    cap_bowl("Bowl", 3.0, 0.95, 1.45)
    ring("Rim", 3.1, 2.75, 0.14, 0, 0, 1.45, "gold")
    soil("Soil", 2.8, 0, 0, 1.44)


@kit("HaloFlowerPotHQ_Lavender__Body", 2.3, "art/out/s2/halo/props4/HaloProp4_PotLavender_front.png")
def pot_lavender():
    z = foot("Foot", 1.0, 0.28)
    cyl("Stem", 0.7, 0.2, 0, 0, z, "marble")
    bc = z + 0.2 + 0.72
    ball("Bulb", 1.6, 0, 0, bc, "marble")
    for k, ax in enumerate((EX, EY)):
        ring("Rib%d" % k, 1.63, 1.55, 0.06, 0, 0, bc, "gold", axis=ax, cc=False)
    cyl("Neck", 1.0, 0.38, 0, 0, bc + 0.6, "marble")
    ring("Lip", 1.24, 0.9, 0.14, 0, 0, bc + 1.0, "gold")
    soil("Soil", 0.92, 0, 0, bc + 0.98)


@kit("HaloVar4_PotFlowers_A__Body", 1.75, "art/out/s2/halo/variants4/HaloVar4_PotFlowers_A_HQ_src.png")
def potflowers_a():
    z = foot("Foot", 1.25, 0.3)
    cyl("Stem", 0.7, 0.25, 0, 0, z, "marble")
    cap_bowl("Bowl", 2.5, 1.05, 1.68)
    ring("Rim", 2.6, 2.25, 0.16, 0, 0, 1.66, "gold")
    soil("Soil", 2.3, 0, 0, 1.66)


@kit("HaloVar4_PotFlowers_C__Body", 2.1, "art/out/s2/halo/variants4/HaloVar4_PotFlowers_C_HQ_src.png")
def potflowers_c():
    z = foot("Foot", 1.0, 0.3)
    cyl("Stem", 0.55, 0.3, 0, 0, z, "marble")
    ring("Knot", 0.75, 0.5, 0.14, 0, 0, z + 0.2, "gold", cc=False)
    cap_bowl("Bowl", 1.7, 0.85, 1.55)
    cyl("Upper", 1.7, 0.4, 0, 0, 1.55)
    ring("Rim", 1.86, 1.5, 0.14, 0, 0, 1.98, "gold")
    for k in range(6):
        nrm = hdir(30 + 60 * k)
        plate("Rib%d" % k, 0.07, 0.5, 0.04, vadd((0, 0, 1.68), vmul(nrm, 0.85)), nrm, "gold")
    soil("Soil", 1.55, 0, 0, 1.96)


@kit("HaloVar4_PotFlowers_D__Body", 1.4, "art/out/s2/halo/variants4/HaloVar4_PotFlowers_D_HQ_src.png")
def potflowers_d():
    z = foot("Foot", 1.6, 0.25)
    cap_bowl("Bowl", 3.2, 0.85, 1.32)
    ring("Rim", 3.3, 2.95, 0.16, 0, 0, 1.3, "gold")
    soil("Soil", 3.0, 0, 0, 1.3)


@kit("HaloVar3_PotFlowers_E__Body", 1.95, "art/out/s2/halo/variants/HaloVar3_PotFlowers_E_HQ_src.png")
def potflowers_e():
    z = foot("Foot", 1.35, 0.4)
    cyl("Stem", 0.9, 0.2, 0, 0, z, "marble")
    cap_bowl("Bowl", 2.6, 0.75, 1.4)
    cyl("Band", 2.6, 0.45, 0, 0, 1.4)
    round_inlays("Win", 1.3, 1.62, 6, 0.16, 0.26, "arch", a0=0, fr=0.04)
    ring("Rim", 2.72, 2.35, 0.16, 0, 0, 1.9, "gold")
    soil("Soil", 2.4, 0, 0, 1.88)


@kit("HaloVar3_PotFlowers_F__Body", 2.45, "art/out/s2/halo/variants/HaloVar3_PotFlowers_F_HQ_src.png")
def potflowers_f():
    cyl("Base", 1.5, 0.3, 0, 0, 0)
    cyl("BaseGold", 1.6, 0.08, 0, 0, 0.3, "gold")
    cyl("Stem", 0.55, 0.45, 0, 0, 0.38)
    ball("Knot", 0.62, 0, 0, 0.62, "marble")
    ring("KnotRing", 0.7, 0.5, 0.1, 0, 0, 0.82, "gold", cc=False)
    cap_bowl("Bowl", 1.7, 0.7, 1.6)
    cyl("Upper", 1.7, 0.7, 0, 0, 1.6)
    round_inlays("Win", 0.85, 1.95, 4, 0.18, 0.4, "arch", a0=0, fr=0.04)
    ring("Rim", 1.86, 1.5, 0.14, 0, 0, 2.33, "gold")
    soil("Soil", 1.55, 0, 0, 2.3)


@kit("HaloVar4_Planter_A__Body", 2.75, "art/out/s2/halo/variants4/HaloVar4_Planter_A_HQ_src.png")
def planter_a():
    w = 4.2
    box("Band", w + 0.14, w + 0.14, 0.16, 0, 0, 0, "gold")
    box("Body", w, w, 2.0, 0, 0, 0.16)
    rim_box("Rim", w + 0.12, w + 0.12, 0.12, 0.4, 0, 0, 2.16, "gold")
    for k, f in enumerate(FACES):
        frame_panel("Panel%d_" % k, vadd((0, 0, 1.15), vmul(f, w / 2)), f, w * 0.62, 1.2, fr=0.07)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - 0.2), sy * (w / 2 - 0.2)
            box("Post%d%d" % (sx, sy), 0.62, 0.62, 2.4, x, y, 0.0)
            box("PostCap%d%d" % (sx, sy), 0.72, 0.72, 0.12, x, y, 2.4, "gold")
            gold_ball("PostBall%d%d" % (sx, sy), 0.52, x, y, 2.52, neck=False)
    soil("Soil", (w - 0.4, w - 0.4), 0, 0, 2.22, "box")


@kit("HaloVar4_Planter_D__Body", 1.8, "art/out/s2/halo/variants4/HaloVar4_Planter_D_HQ_src.png")
def planter_d():
    w = 2.9
    octa("Band", w + 0.14, 0.16, 0, 0, 0, "gold")
    octa("Body", w, 1.4, 0, 0, 0.16)
    octa_ring("Rim", w + 0.12, 0.3, 0.14, 0, 0, 1.56, "gold")
    side = w * math.tan(math.radians(22.5))
    for k in range(8):
        nrm = hdir(45 * k)
        frame_panel("Panel%d_" % k, vadd((0, 0, 0.86), vmul(nrm, w / 2)), nrm, side * 0.6, 0.8, fr=0.05)
    soil("Soil", w - 0.2, 0, 0, 1.68, "oct")


@kit("HaloVar3_Planter_E__Body", 2.9, "art/out/s2/halo/variants/HaloVar3_Planter_E_HQ_src.png")
def planter_e():
    W, D = 5.6, 3.0
    box("Band", W + 0.12, D + 0.12, 0.14, 0, 0, 0, "gold")
    box("Lower", W, D, 1.3, 0, 0, 0.14)
    rim_box("LowerRim", W + 0.1, D + 0.1, 0.12, 0.35, 0, 0, 1.44, "gold")
    for k, u in enumerate((-1.7, -0.6, 0.6, 1.7)):
        inlay("WinF%d" % k, (u, D / 2, 0.8), EY, 0.18, 0.4, "arch", fr=0.04)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.25), sy * (D / 2 - 0.25)
            box("Post%d%d" % (sx, sy), 0.6, 0.6, 1.8, x, y, 0.0)
            inlay("PostWin%d%d" % (sx, sy), (x, y + sy * 0.3, 0.95), (0, sy, 0), 0.14, 0.4, "arch", fr=0.035)
            onion("PostDome%d%d" % (sx, sy), 0.5, x, y, 1.8, tip=0.22)
    soil("SoilLo", (W - 0.7, D - 0.7), 0, 0, 1.5, "box")
    # upper tier at the back
    box("Upper", 3.4, 1.6, 0.95, 0, -0.55, 1.56)
    rim_box("UpperRim", 3.5, 1.7, 0.1, 0.25, 0, -0.55, 2.51, "gold")
    for sx in (-1, 1):
        box("UpPost%d" % sx, 0.5, 0.5, 1.3, sx * 1.6, -0.55, 1.56)
        onion("UpDome%d" % sx, 0.45, sx * 1.6, -0.55, 2.86, tip=0.2)
    soil("SoilHi", (3.0, 1.2), 0, -0.55, 2.55, "box")


def tree_planter(d, h):
    cyl("BandLo", d + 0.12, 0.16, 0, 0, 0, "gold")
    cyl("Body", d, h - 0.3, 0, 0, 0.16)
    round_inlays("Win", d / 2, h * 0.5, 6, 0.18, 0.38, "arch", a0=0, fr=0.04)
    ring("BandHi", d + 0.14, d - 0.3, 0.16, 0, 0, h - 0.14, "gold")
    soil("Grass", d - 0.25, 0, 0, h - 0.04, m="leaf")


@kit("HaloVar3_RoundTree_E__Body", 1.3, "art/out/s2/halo/props4/HaloProp4_TreeE_front.png")
def tree_e_body():
    tree_planter(3.4, 1.3)


@kit("HaloVar3_RoundTree_F__Body", 1.35, "art/out/s2/halo/props4/HaloProp4_TreeF_front.png")
def tree_f_body():
    tree_planter(3.7, 1.35)


@kit("HaloVar3_RoundTree_G__Body", 1.25, "art/out/s2/halo/props4/HaloProp4_TreeG_front.png")
def tree_g_body():
    tree_planter(3.3, 1.25)


@kit("HaloVar3_Topiary_C__Body", 1.7, "art/out/s2/halo/props4/HaloProp4_TopC_front.png")
def topiary_c_body():
    z = foot("Foot", 0.95, 0.22)
    cyl("Stem", 0.7, 0.2, 0, 0, z, "marble")
    cap_bowl("Bowl", 1.6, 0.45, 0.95)
    cyl("Wall", 1.6, 0.6, 0, 0, 0.95)
    round_inlays("Win", 0.8, 1.22, 4, 0.14, 0.3, "arch", a0=0, fr=0.035)
    ring("Rim", 1.72, 1.4, 0.14, 0, 0, 1.6, "gold")
    soil("Moss", 1.45, 0, 0, 1.6, m="leaf")


@kit("HaloVar3_Topiary_D__Body", 1.75, "art/out/s2/halo/props4/HaloProp4_TopD_front.png")
def topiary_d_body():
    w = 2.0
    octa("Band", w + 0.12, 0.16, 0, 0, 0, "gold")
    octa("Body", w, 1.4, 0, 0, 0.16)
    octa_ring("Rim", w + 0.12, 0.25, 0.14, 0, 0, 1.56, "gold")
    side = w * math.tan(math.radians(22.5))
    for k in range(8):
        nrm = hdir(45 * k)
        inlay("Win%d" % k, vadd((0, 0, 0.86), vmul(nrm, w / 2)), nrm, side * 0.35, 0.5, "arch", fr=0.035)
    soil("Moss", w - 0.2, 0, 0, 1.68, "oct", m="leaf")


@kit("HaloVar3_Topiary_E__Body", 3.0, "art/out/s2/halo/props4/HaloProp4_TopE_front.png")
def topiary_e_body():
    z = foot("Foot", 1.4, 0.45)
    cyl("Stem", 1.0, 0.55, 0, 0, z, "marble")
    ring("StemRing", 1.2, 0.9, 0.12, 0, 0, z + 0.3, "gold", cc=False)
    cap_bowl("Bowl", 3.4, 1.3, 2.35)
    cyl("Wall", 3.4, 0.45, 0, 0, 2.35)
    round_inlays("Win", 1.7, 2.0, 4, 0.22, 0.45, "arch", a0=0, fr=0.045)
    ring("Rim", 3.55, 3.1, 0.18, 0, 0, 2.8, "gold")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        onion("RimDome%d" % k, 0.42, 1.62 * math.sin(a), 1.62 * math.cos(a), 2.89, tip=0.2)
    soil("Moss", 3.1, 0, 0, 2.86, m="leaf")


@kit("HaloReasonHQ_BenchB__Body", 3.3, "art/out/s2/halo/props4/HaloProp4_BenchB_front.png")
def bench_b_body():
    # round planter at the viewer's left end (+x), armrest end at -x
    px = 2.45
    cyl("PlanterBand", 1.92, 0.14, px, -0.1, 0, "gold")
    cyl("Planter", 1.8, 1.55, px, -0.1, 0.14)
    round_inlays_at = [(px + 0.9 * math.sin(math.radians(a)), -0.1 + 0.9 * math.cos(math.radians(a)), a) for a in (0, 90, 180, 270)]
    for k, (x, y, a) in enumerate(round_inlays_at):
        inlay("PlanterWin%d" % k, (x, y, 0.8), hdir(a), 0.2, 0.45, "arch", fr=0.04)
    ring("PlanterRim", 1.94, 1.6, 0.14, px, -0.1, 1.62, "gold")
    soil("PlanterSoil", 1.62, px, -0.1, 1.68)
    x = -2.45
    pedestal("Leg", 1.1, 1.7, 1.45, x, 0.0)
    box("LegTop", 1.18, 1.78, 0.1, x, 0.0, 1.45, "gold")
    inlay("LegWin", (x, 0.85, 0.85), EY, 0.34, 0.62, "arch")
    inlay("LegWinS", (x - 0.55, 0.0, 0.85), (-1, 0, 0), 0.34, 0.62, "arch")
    pedestal("Post", 0.85, 0.8, 1.45, x, -0.48, 1.55, band=False, plinth=0.12)
    z = cap("PostCap", 0.85, 0.8, x, -0.48, 3.0)
    gold_ball("PostBall", 0.62, x, -0.48, z)
    # inner post beside the planter (holds the seat and back)
    pedestal("PostP", 0.6, 0.8, 2.75, px - 1.15, -0.48, 0.0, plinth=0.12)
    z = cap("PostPCap", 0.6, 0.8, px - 1.15, -0.48, 2.75)
    gold_ball("PostPBall", 0.5, px - 1.15, -0.48, z)
    box("SeatLeg", 0.5, 1.3, 1.39, px - 1.15, 0.2, 0.0)
    planks("Seat", 3.1, 1.4, 3, 0.16, -0.55, 0.78, -0.55, 1.55)
    for k in range(3):
        zc = 1.85 + k * 0.36
        part("Back%d" % k, "Block", (3.1, 0.3, 0.14), (-0.55, -0.62 - (zc - 1.6) * 0.14, zc), EX, norm((0, -0.14, 1)), "wood")


@kit("HaloReasonHQ_VegGarden__Body", 1.15, "art/out/s2/halo/props4/HaloProp4_ReasonVeg_front.png")
def veg_body():
    W, D, H, t = 7.6, 4.6, 1.05, 0.4
    for k, (w, d, x, y) in enumerate(((W, t, 0, D / 2 - t / 2), (W, t, 0, -D / 2 + t / 2), (t, D - 2 * t, W / 2 - t / 2, 0), (t, D - 2 * t, -W / 2 + t / 2, 0))):
        box("Wall%d" % k, w, d, H, x, y, 0, "mblock")
    box("RimF", W + 0.06, t + 0.06, 0.1, 0, D / 2 - t / 2, H, "gold")
    box("RimB", W + 0.06, t + 0.06, 0.1, 0, -D / 2 + t / 2, H, "gold")
    box("RimL", t + 0.06, D - 2 * t, 0.1, W / 2 - t / 2, 0, H, "gold")
    box("RimR", t + 0.06, D - 2 * t, 0.1, -W / 2 + t / 2, 0, H, "gold")
    box("Soil", W - 2 * t, D - 2 * t, H - 0.15, 0, 0, 0, "soil", cc=False)
    for k, u in enumerate((-2.6, -0.9, 0.9, 2.6)):
        inlay("WinF%d" % k, (u, D / 2, 0.52), EY, 0.18, 0.42, "rect", fr=0.04)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.25), sy * (D / 2 - 0.25)
            box("Post%d%d" % (sx, sy), 0.6, 0.6, 1.3, x, y, 0, "marble")
            box("PostCap%d%d" % (sx, sy), 0.7, 0.7, 0.1, x, y, 1.3, "gold")


@kit("HaloReasonHQ_BreadStand__Body", 3.7, "art/out/s2/halo/props4/HaloProp4_ReasonBread_front.png")
def bread_body():
    W, D = 6.6, 2.3
    box("Plinth", W + 0.2, D + 0.2, 0.2, 0, 0, 0)
    box("PlinthBand", W + 0.06, D + 0.06, 0.08, 0, 0, 0.2, "gold")
    box("Counter", W, D, 1.5, 0, 0, 0.28)
    box("CounterTop", W + 0.16, D + 0.16, 0.14, 0, 0, 1.78, "marble")
    box("CounterGold", W + 0.1, D + 0.1, 0.08, 0, 0, 1.7, "gold")
    frame_panel("PanelF", (0, D / 2, 1.0), EY, W * 0.7, 0.9, fr=0.07)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.3), sy * (D / 2 - 0.3)
            box("Post%d%d" % (sx, sy), 0.16, 0.16, 1.9, x, y, 1.92, "gold")
            gold_ball("PostBall%d%d" % (sx, sy), 0.28, x, y, 3.82, neck=False)
    for k, z in enumerate((2.55, 3.25)):
        box("Shelf%d" % k, W - 0.4, D - 0.5, 0.1, 0, -0.05, z, "wood")
        box("ShelfLip%d" % k, W - 0.4, 0.05, 0.12, 0, D / 2 - 0.3, z + 0.05, "gold", cc=False)
    blue, white = (110, 170, 235), (250, 248, 240)
    for k, x in enumerate((-1.4, 1.4)):
        box("Cloth%d" % k, 1.1, 0.05, 0.9, x, D / 2 + 0.06, 1.0, "cloth", c=white, cc=False)
        for j in range(2):
            box("ClothS%d_%d" % (k, j), 0.2, 0.06, 0.9, x - 0.3 + 0.6 * j, D / 2 + 0.065, 1.0, "cloth", c=blue, cc=False)
        part("ClothTip%d" % k, "Block", (0.78, 0.78, 0.05), (x, D / 2 + 0.06, 1.0), norm((1, 0, 1)), norm((-1, 0, 1)), "cloth", c=white, cc=False)


def awning(n, W, D, z_back, z_front, y_back, y_front, count, cols=((110, 170, 235), (250, 248, 240))):
    """Striped cloth awning sloping from (y_back, z_back) to (y_front, z_front) + a scalloped front edge."""
    p0, p1 = (0.0, y_back, z_back), (0.0, y_front, z_front)
    L = math.sqrt(dot(vsub(p1, p0), vsub(p1, p0)))
    down = norm(vsub(p1, p0))
    nrm = cross(EX, down)
    if nrm[2] < 0:
        nrm = vmul(nrm, -1)
    for k in range(count):
        x = -W / 2 + W / count * (k + 0.5)
        c = cols[k % 2]
        part("%s%d" % (n, k), "Block", (W / count, 0.08, L), vadd((x, 0, 0), vmul(vadd(p0, p1), 0.5)), EX, nrm, "cloth", c=c, cc=False)
        part("%sScal%d" % (n, k), "Cylinder", (0.06, W / count, W / count), (x, y_front + 0.02, z_front), EY, UP, "cloth", c=c, cc=False)


@kit("HaloReasonHQ_FruitStall__Body", 8.6, "art/out/s2/halo/props4/HaloProp4_ReasonFruit_front.png")
def fruit_body():
    W, D = 5.2, 2.8
    box("Plinth", W + 0.2, D + 0.2, 0.25, 0, 0, 0)
    box("Counter", W, D, 1.9, 0, 0, 0.25, "wood")
    for k in range(3):
        box("CounterPanel%d" % k, W / 3 - 0.2, 0.05, 1.4, -W / 3 + W / 3 * k, D / 2 + 0.02, 0.5, "woodcream", cc=False)
    box("CounterTop", W + 0.16, D + 0.16, 0.14, 0, 0, 2.15, "marble")
    box("CounterGold", W + 0.1, D + 0.1, 0.08, 0, 0, 2.07, "gold")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.25), sy * (D / 2 - 0.25)
            box("Post%d%d" % (sx, sy), 0.5, 0.5, 8.0 if sy < 0 else 6.2, x, y, 0.0)
            box("PostBand%d%d" % (sx, sy), 0.56, 0.56, 0.1, x, y, 2.3, "gold", cc=False)
            ztop = 8.0 if sy < 0 else 6.2
            box("PostCap%d%d" % (sx, sy), 0.6, 0.6, 0.12, x, y, ztop, "gold")
            gold_ball("PostBall%d%d" % (sx, sy), 0.4, x, y, ztop + 0.12, neck=False)
    box("BackBeam", W, 0.4, 0.4, 0, -D / 2 + 0.25, 7.6)
    box("FrontBeam", W, 0.4, 0.4, 0, D / 2 - 0.25, 5.8)
    awning("Awning", W + 0.4, D, 8.05, 6.0, -D / 2, D / 2 + 0.5, 7)
    # tilted fruit crates on the counter, fruit = balls
    fruit = ((255, 150, 40), (130, 200, 60), (225, 60, 50), (70, 90, 200))
    for k in range(3):
        cx = -1.6 + 1.6 * k
        tilt = norm((0, 0.35, 1))
        cc_ = (cx, 0.1, 2.75)
        part("Crate%d" % k, "Block", (1.4, 0.5, 1.4), cc_, EX, tilt, "woodcream", c=(225, 190, 140))
        top = vadd(cc_, vmul(tilt, 0.25))
        across = cross(EX, tilt)
        for i in range(3):
            for j in range(3):
                q = vadd(top, vmul(EX, -0.42 + 0.42 * i), vmul(across, -0.42 + 0.42 * j), vmul(tilt, 0.12))
                ball("Fruit%d_%d%d" % (k, i, j), 0.42, q[0], q[1], q[2], "paint", c=fruit[(k + i + j) % len(fruit)], cc=False)


def wheel(n, d, x, y, z, axis=EY, spokes=8):
    ring(n + "Rim", d, d - 0.22, 0.16, x, y, z, "gold", axis=axis)
    part(n + "Hub", "Cylinder", (0.3, 0.36, 0.36), (x, y, z), axis, UP, "gold")
    for k in range(spokes):
        a = math.radians(360.0 / spokes * k)
        u = vadd(vmul(EX if abs(axis[0]) < 0.5 else EY, math.cos(a)), vmul(UP, math.sin(a)))
        rod("%sSpoke%d" % (n, k), (x, y, z), vadd((x, y, z), vmul(u, d / 2 - 0.1)), 0.08, "wood", cc=False)


@kit("HaloReasonHQ_FlowerCart__Body", 4.8, "art/out/s2/halo/props4/HaloProp4_ReasonFlowerCart_front.png")
def flowercart_body():
    # wheel on +x = the viewer's left, handles to -x (2D front)
    W, D = 4.2, 2.0
    box("Bed", W, D, 0.2, 0, 0, 1.0, "wood")
    for k, (w, d, x, y) in enumerate(((W, 0.14, 0, D / 2 - 0.07), (W, 0.14, 0, -D / 2 + 0.07), (0.14, D, W / 2 - 0.07, 0), (0.14, D, -W / 2 + 0.07, 0))):
        box("Side%d" % k, w, d, 1.0, x, y, 1.2, "wood")
    for k, x in enumerate((-1.2, 0.0, 1.2)):
        box("PanelF%d" % k, 1.0, 0.04, 0.6, x, D / 2 + 0.02, 1.4, "blue", cc=False)
        box("PanelFG%d" % k, 1.1, 0.03, 0.7, x, D / 2 + 0.005, 1.35, "gold", cc=False)
    box("RimF", W + 0.06, 0.2, 0.08, 0, D / 2 - 0.07, 2.2, "gold", cc=False)
    box("RimB", W + 0.06, 0.2, 0.08, 0, -D / 2 + 0.07, 2.2, "gold", cc=False)
    soil("Soil", (W - 0.3, D - 0.3), 0, 0, 2.05, "box")
    wheel("WheelF", 1.9, 1.1, D / 2 + 0.2, 0.95)
    wheel("WheelB", 1.9, 1.1, -D / 2 - 0.2, 0.95)
    rod("Axle", (1.1, D / 2 + 0.2, 0.95), (1.1, -D / 2 - 0.2, 0.95), 0.14, "gold", cc=False)
    for sy in (-1, 1):
        box("Leg%d" % sy, 0.2, 0.2, 1.0, -W / 2 + 0.3, sy * (D / 2 - 0.15), 0.0, "wood")
        rod("Handle%d" % sy, (-W / 2, sy * 0.7, 1.35), (-W / 2 - 1.6, sy * 0.7, 1.55), 0.12, "wood")
        ball("HandleEnd%d" % sy, 0.2, -W / 2 - 1.65, sy * 0.7, 1.56, "gold", cc=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("AwPost%d%d" % (sx, sy), 0.12, 0.12, 2.3, sx * (W / 2 - 0.2), sy * (D / 2 - 0.15), 2.2, "gold")
    awning("Aw", W + 0.2, D, 4.7, 4.3, -D / 2 - 0.1, D / 2 + 0.2, 6)
    gold_ball("Finial", 0.3, 0, -0.1, 4.75)


@kit("HaloReasonHQ_PotionCrate__Body", 3.5, "art/out/s2/halo/props4/HaloProp4_ReasonPotion_front.png")
def potion_body():
    W, D, H = 3.6, 2.1, 1.5
    box("Crate", W, D, H, 0.3, 0, 0, "woodcream", c=(226, 190, 140))
    for k in range(3):
        box("Plank%d" % k, W, 0.03, 0.04, 0.3, D / 2 + 0.01, 0.4 + 0.45 * k, "wood", cc=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Corner%d%d" % (sx, sy), 0.2, 0.2, H + 0.02, 0.3 + sx * (W / 2 - 0.08), sy * (D / 2 - 0.08), 0, "gold", cc=False)
    box("BandTop", W + 0.04, D + 0.04, 0.12, 0.3, 0, H - 0.16, "gold", cc=False)
    blue, white = (110, 170, 235), (250, 248, 240)
    box("Cloth", 1.6, 0.05, 0.9, 0.3, D / 2 + 0.06, 0.55, "cloth", c=white, cc=False)
    for j in range(3):
        box("ClothS%d" % j, 0.22, 0.06, 0.9, 0.3 - 0.5 + 0.5 * j, D / 2 + 0.065, 0.55, "cloth", c=blue, cc=False)
    part("ClothTip", "Block", (1.13, 1.13, 0.05), (0.3, D / 2 + 0.06, 0.55), norm((1, 0, 1)), norm((-1, 0, 1)), "cloth", c=white, cc=False)
    cols = ((90, 150, 245), (245, 120, 170), (90, 210, 110), (90, 220, 230), (250, 200, 80))
    for k, (x, y, d) in enumerate(((-0.9, 0.3, 0.75), (-0.1, -0.2, 0.85), (0.7, 0.35, 0.7), (1.4, -0.25, 0.8), (0.3, 0.45, 0.6))):
        zc = H + d / 2
        ball("Flask%d" % k, d, x, y, zc, "glass", c=cols[k])
        cyl("FlaskNeck%d" % k, d * 0.35, d * 0.4, x, y, zc + d * 0.4, "glass", c=cols[k], cc=False)
        cyl("FlaskCollar%d" % k, d * 0.42, 0.06, x, y, zc + d * 0.45, "gold", cc=False)
        cyl("Cork%d" % k, d * 0.3, 0.18, x, y, zc + d * 0.8, "wood", cc=False)
        ball("FlaskGlow%d" % k, d * 0.7, x, y, zc - d * 0.05, "neon", c=cols[k], cc=False)
    # sign post at the viewer's right end (-x)
    sxp = -W / 2 - 0.1
    pedestal("SignPost", 0.5, 0.5, 3.2, sxp, -0.4, plinth=0.2)
    gold_ball("SignPostBall", 0.32, sxp, -0.4, 3.2, neck=False)
    rod("SignArm", (sxp, -0.4, 2.9), (sxp - 1.0, -0.4, 2.9), 0.1, "gold", cc=False)
    box("SignBoard", 0.08, 0.9, 0.7, sxp - 0.7, -0.4, 2.05, "paint", c=(250, 246, 236), rot=90)
    box("SignFrame", 0.06, 1.0, 0.8, sxp - 0.7, -0.38, 2.0, "gold", rot=90, cc=False)


@kit("NEW_Hedge__Body", 1.75, "art/out/s2/halo/kits_new/HaloKit_Hedge_b_front.png")
def hedge_body():
    W, D = 6.4, 1.5
    box("Band", W + 0.12, D + 0.12, 0.14, 0, 0, 0, "gold")
    box("Body", W, D, 1.0, 0, 0, 0.14)
    rim_box("Rim", W + 0.1, D + 0.1, 0.12, 0.25, 0, 0, 1.14, "gold")
    frame_panel("PanelF", (0, D / 2, 0.64), EY, W * 0.7, 0.6, fr=0.05)
    frame_panel("PanelB", (0, -D / 2, 0.64), (0, -1, 0), W * 0.7, 0.6, fr=0.05)
    soil("Soil", (W - 0.4, D - 0.4), 0, 0, 1.2, "box")
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.35)
        box("End%d" % sx, 0.8, 0.8, 1.6, x, 0, 0)
        box("EndBand%d" % sx, 0.86, 0.86, 0.1, x, 0, 0.12, "gold")
        inlay("EndWin%d" % sx, (x, 0.4, 0.85), EY, 0.18, 0.5, "arch", fr=0.04)
        z = cap("EndCap%d" % sx, 0.8, 0.8, x, 0, 1.6, t=0.12)
        onion("EndDome%d" % sx, 0.55, x, 0, z, tip=0.25)


@kit("NEW_Cauldron", 3.5, "art/out/s2/halo/kits_new/HaloKit_Cauldron_front.png", note="all parts (CSG pot); steam = particles outside the model")
def cauldron():
    cyl("Base", 3.2, 0.45, 0, 0, 0, "marble")
    cyl("BaseTop", 3.0, 0.08, 0, 0, 0.45, "marble")
    for k in range(8):
        nrm = hdir(22.5 + 45 * k)
        plate("BaseGold%d" % k, 0.35, 0.3, 0.05, vadd((0, 0, 0.22), vmul(nrm, 1.6)), nrm, "gold")
    for k in range(3):
        a = math.radians(90 + 120 * k)
        box("Foot%d" % k, 0.35, 0.35, 0.5, 0.85 * math.cos(a), 0.85 * math.sin(a), 0.45, "ironblue", rot=math.degrees(a))
    R, zc, zo = 1.3, 1.8, 2.6
    top = cut(box, "PotTop", 3.0, 3.0, 2.0, 0, 0, zo, "ironblue")
    inner = cut(ball, "PotIn", 2 * R - 0.24, 0, 0, zc, "ironblue")
    ball("Pot", 2 * R, 0, 0, zc, "ironblue", ops=[("minus", [top, inner])])
    ro = math.sqrt(R * R - (zo - zc) ** 2)
    ring("Rim", 2 * ro + 0.24, 2 * ro - 0.18, 0.2, 0, 0, zo + 0.06, "gold")
    zb = zc + 0.45
    rb = math.sqrt(R * R - (zb - zc) ** 2)
    ring("Belt", 2 * rb + 0.1, 2 * rb - 0.3, 0.16, 0, 0, zb, "gold", cc=False)
    for k in range(6):
        a = math.radians(60 * k)
        ball("Stud%d" % k, 0.14, (rb + 0.04) * math.cos(a), (rb + 0.04) * math.sin(a), zb, "gold", cc=False)
    for sx in (-1, 1):
        ring("Handle%d" % sx, 0.6, 0.38, 0.12, sx * (R + 0.08), 0, zc + 0.35, "ironblue", axis=EY, cc=False)
    # brew: glowing surface just over the gold rim top, so it shows from eye height (2D key point)
    # Neon blooms towards white: a deeper teal reads as the 2D's glowing blue-green (디자인 검수 10/12 ~90,220,190)
    cyl("Brew", 2 * ro - 0.2, 0.1, 0, 0, zo + 0.14, "neon", c=(60, 196, 170), cc=False)
    for k, (x, y, d, col) in enumerate(((0.25, 0.15, 0.46, (120, 235, 150)), (-0.3, -0.05, 0.36, (140, 225, 250)),
                                         (0.0, -0.4, 0.3, (120, 235, 150)), (-0.15, 0.4, 0.28, (140, 225, 250)),
                                         (0.5, -0.2, 0.24, (140, 225, 250)), (-0.55, 0.3, 0.2, (120, 235, 150)))):
        ball("Bubble%d" % k, d, x, y, zo + 0.22 + d * 0.3, "glass", c=col, cc=False)


# ---------------------------------------------------------------- output
MAT_LUA = {
    "marble": None,   # set from --marble
    "mblock": 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleBlock_Cream"',
    "gold": 'p.Material = Enum.Material.Metal; p.MaterialVariant = "HH_HaloGoldTrim"',
    "wood": 'p.Material = Enum.Material.Wood',
    "woodcream": 'p.Material = Enum.Material.Wood',
    "wooddk": 'p.Material = Enum.Material.Wood',
    "blue": 'p.Material = Enum.Material.SmoothPlastic; p.Reflectance = 0.05',
    "cloth": 'p.Material = Enum.Material.Fabric; p.MaterialVariant = "HH_Fabric"',
    "rope": 'p.Material = Enum.Material.Fabric',
    "glass": 'p.Material = Enum.Material.Glass; p.Transparency = 0.3; p.Reflectance = 0.15; p.CastShadow = false',
    "lamp": 'p.Material = Enum.Material.Glass; p.Transparency = 0.3; p.CastShadow = false; p:SetAttribute("LampLight", true); '
            'local l = Instance.new("PointLight"); l.Name = "LampLight"; l.Color = Color3.fromRGB(255, 214, 140); l.Brightness = 2.5; '
            'l.Range = 16; l.Shadows = false; l.Enabled = false; l.Parent = p',
    "neon": 'p.Material = Enum.Material.Neon; p.CastShadow = false',
    "slate": 'p.Material = Enum.Material.SmoothPlastic',
    "leaf": 'p.Material = Enum.Material.Grass',
    "soil": 'p.Material = Enum.Material.Sand',
    "iron": 'p.Material = Enum.Material.Metal',
    "candle": 'p.Material = Enum.Material.SmoothPlastic',
    "paint": 'p.Material = Enum.Material.SmoothPlastic',
    "stone": 'p.Material = Enum.Material.Marble',
    "dark": 'p.Material = Enum.Material.SmoothPlastic',
    "water": 'p.Material = Enum.Material.Glass; p.Transparency = 0.25; p.Reflectance = 0.2',
    "pcream": 'p.Material = Enum.Material.SmoothPlastic',
    "groove": 'p.Material = Enum.Material.SmoothPlastic',
    "ironblue": 'p.Material = Enum.Material.Metal; p.Reflectance = 0.05',
}


def r3(v):
    return (v[0], v[2], -v[1])


def lua_part(t):
    s = t["size"]
    x, y, z = r3(t["p"])
    X, Y = r3(t["X"]), r3(t["Y"])
    col = t["c"] or COL[t["m"]]
    small = max(s) < 0.35
    cc = t["cc"] if t["cc"] is not None else (min(s) >= 0.3 and not small)
    ops = ""
    if t.get("ops"):
        ops = ", {" + ", ".join('{"%s", {%s}}' % (k, ", ".join(lua_part(c) for c in lst)) for k, lst in t["ops"]) + "}"
    return '{"%s", "%s", %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, "%s", %d, %d, %d, %s, %s%s}' % (
        t["n"], t["s"], s[0], s[1], s[2], x, y, z, X[0], X[1], X[2], Y[0], Y[1], Y[2], t["m"], col[0], col[1], col[2],
        "true" if cc else "false", "true" if small else "false", ops)


def build_lua(name, parts, marble):
    # smooth = HH_HaloMarbleSmooth_Cream (이미지 개발 10/11: props' joint-free cream marble, 8 studs/tile); plain = no variant
    MAT_LUA["marble"] = {"block": 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleBlock_Cream"',
                         "smooth": 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleSmooth_Cream"',
                         "plain": 'p.Material = Enum.Material.Marble'}[marble]
    MAT_LUA["stone"] = MAT_LUA["marble"]
    m = META[name]
    L = ['-- %s (generated by tools/prop_kit.py, 이미지 생성 4, SPEC A23-120/125). WorldKit only.' % name,
         'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end',
         'local GS = game:GetService("GeometryService")',
         'local SS = game:GetService("ServerStorage")',
         'local root = SS:FindFirstChild("HaloPropKits") or Instance.new("Folder"); root.Name = "HaloPropKits"; root.Parent = SS',
         'local old = root:FindFirstChild("%s"); if old then old:Destroy() end' % name,
         'local M = Instance.new("Model"); M.Name = "%s"' % name,
         'local function mat(p, m)']
    for i, (k, v) in enumerate(MAT_LUA.items()):
        L.append('  %s m == "%s" then %s' % ("if" if i == 0 else "elseif", k, v))
    L += ['  end', 'end',
          'local fails = {}',
          'local function mk(t, keep)',
          '  local p',
          '  if t[2] == "Wedge" then p = Instance.new("WedgePart") else p = Instance.new("Part"); p.Shape = Enum.PartType[t[2]] end',
          '  p.Name = t[1]; p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth',
          '  p.Size = Vector3.new(t[3], t[4], t[5])',
          '  p.CFrame = CFrame.fromMatrix(Vector3.new(t[6], t[7], t[8]), Vector3.new(t[9], t[10], t[11]), Vector3.new(t[12], t[13], t[14]))',
          '  p.Color = Color3.fromRGB(t[16], t[17], t[18]); mat(p, t[15])',
          # 디자인 검수 10/12 (comparison test B): every part casts a shadow; only glass / lamp / neon turn it off in mat()
          '  p.CanCollide = t[19]; p.CanTouch = false',
          '  if t[21] then                 -- cutters may carry their own ops too (octagon holes)',
          '    local cur = p',
          '    for _, op in t[21] do',
          '      local others = {}',
          '      for _, c in op[2] do table.insert(others, mk(c, false)) end',
          '      local ok, res = pcall(function()',
          '        if op[1] == "minus" then return GS:SubtractAsync(cur, others, {RenderFidelity = Enum.RenderFidelity.Precise, CollisionFidelity = Enum.CollisionFidelity.Box})',
          '        else return GS:IntersectAsync(cur, others, {RenderFidelity = Enum.RenderFidelity.Precise, CollisionFidelity = Enum.CollisionFidelity.Box}) end',
          '      end)',
          '      if ok and res and res[1] then',
          '        local u = res[1]; u.Name = t[1]; u.Anchored = true; u.UsePartColor = true; u.Color = p.Color; u.CanCollide = t[19]; u.CanTouch = false',
          '        if cur ~= p then cur:Destroy() end',
          '        cur = u',
          '      else table.insert(fails, t[1] .. ":" .. tostring(res)) end',
          '      for _, o in others do o:Destroy() end',
          '    end',
          '    if cur ~= p then p:Destroy(); p = cur end',
          '  end',
          '  return p',
          'end',
          'local R = {']
    L += ["  " + lua_part(t) + "," for t in parts]
    L += ['}',
          'for _, t in R do local p = mk(t, true); p.Parent = M end',
          'M.WorldPivot = CFrame.new()',
          'M:SetAttribute("PropKit", "%s"); M:SetAttribute("Maker", "tools/prop_kit.py"); M:SetAttribute("Height", %.2f); M:SetAttribute("Ref2D", "%s")'
          % (name, m["h"], m["ref"]),
          'M.Parent = root',
          'local cf, sz = M:GetBoundingBox()',
          'return string.format("%s: %%d parts, size %%.2f x %%.2f x %%.2f, CSG fails %%d %%s", #M:GetChildren(), sz.X, sz.Y, sz.Z, #fails, table.concat(fails, " "))' % name]
    return "\n".join(L) + "\n"


def run_lua(code, tag):
    jp = os.path.join(OUTDIR, "_run_%s.json" % tag)
    json.dump({"code": code, "datamodel_type": "Edit"}, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + jp],
                       env=dict(os.environ, STUDIO_NAME="WorldKit"), capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
    return (r.stdout.strip() or r.stderr.strip())[-600:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kits", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--marble", default="smooth", choices=["smooth", "plain", "block"])
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        for k, m in META.items():
            print(k, m["h"], m["ref"], m["note"])
        return
    names = list(KITS) if a.all else a.kits
    bad = [k for k in names if k not in KITS]
    if bad:
        sys.exit("unknown kit: %s" % bad)
    os.makedirs(OUTDIR, exist_ok=True)
    for k in names:
        del P[:]
        KITS[k]()
        parts = list(P)
        if META[k]["mirror"]:
            for t in parts:
                mirror_x(t)
        zs = [t["p"][2] + max(t["size"]) / 2 for t in parts]
        json.dump(dict(name=k, **META[k], colors=COL, parts=parts), open(os.path.join(OUTDIR, k + ".json"), "w"), indent=0)
        code = build_lua(k, parts, a.marble)
        open(os.path.join(OUTDIR, k + ".luau"), "w", encoding="utf-8").write(code)
        msg = "[prop_kit] %s: %d parts (top ~%.2f, target %.2f)" % (k, len(parts), max(zs), META[k]["h"])
        if a.apply:
            msg += " -> " + run_lua(code, k)
        print(msg)


if __name__ == "__main__":
    main()
