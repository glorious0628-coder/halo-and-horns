"""Studio skeleton v3 for HaloDomeHouse_07 + RoundTree_E pot (검수 10/11, SPEC A23-120 "건물 골격 먼저"; 이미지 생성 3).

  py tools/skeleton_house07.py [--origin 3000,0,0] [--out build/skeleton_test_07.luau]

v3 follows the 2D front (art/out/s2/halo/roofs/HaloDomeHouse_07_roof_v2.png) instead of the Tripo body:
  - octagon with a wide front face (front 9.2, diagonals project ~0.3 of it as in the 2D), walls Z0..Z1 with real openings;
  - arched door (5.0 x 8.15, A23-106) and arched windows: rectangle + half circle, gold frame arc, marble arch band that
    also fills the hole corners, glass = rectangle + vertical strips under the arch, gold mullion + transom, sill,
    keystone and imposts;
  - pilasters on every corner turned along the corner bisector, gold capital / mid band / foot,
    gold quatrefoil medallions in raised panels on the upper walls, marble piers flanking the door (the lanterns hang
    on them), gold balls on the front face;
  - rings with exact mitred corners (offset polygon): plinth, gold lip, gold foot ring, string course, gold band,
    cornice + gold top;
  - planter beds along the left (front-left, left, back-left) and right (right, back-right) walls where the Tripo plants
    are, and a round front-right planter (gold base, rim, soil, gold quatrefoil / medallion); a top step + a low step at the door, gold blocks at the door foot, hollow inside (floor + ceiling slab), DoorFront.
  Gold = Metal + MaterialVariant HH_HaloGoldTrim, marble = Marble + HH_HaloMarbleBlock (이미지 개발, building_variants).
Also writes <out>.json (parts for tools/skeleton_preview.py) and <out>_place.json (where tools/skeleton_place.py moves the
kept Tripo pieces: roof, door, door hardware, awning, dormer + its pane, lanterns (stray bits behind them dropped), the plants of the beds and the round planter).
Frame: Blender of the parts GLB (x, y = front, z up, studs) -> Roblox (x, z, -y) + origin. Part axes are given as
Blender vectors X (part x) and Y (part y); the Luau uses CFrame.fromMatrix.
"""
import argparse
import json
import math
import os

ap = argparse.ArgumentParser()
ap.add_argument("--origin", default="3000,0,0")
ap.add_argument("--out", default="build/skeleton_test_07.luau")
a = ap.parse_args()
OX, OY, OZ = [float(v) for v in a.origin.split(",")]
parts = []
UP = (0.0, 0.0, 1.0)


def vadd(*vs):
    return tuple(sum(c) for c in zip(*vs))


def vmul(v, s):
    return tuple(c * s for c in v)


def norm(v):
    L = math.sqrt(sum(c * c for c in v))
    return tuple(c / L for c in v)


def add(name, size, pos, X=(1.0, 0.0, 0.0), Y=UP, mat="marble", shape="Block", grp="house"):
    """size = (along X, along Y, along X x Y); pos = centre; X, Y = part axes (Blender frame)"""
    parts.append(dict(name=name, shape=shape, size=[round(s, 4) for s in size], pos=[round(c, 4) for c in pos],
                      X=[round(c, 5) for c in X], Y=[round(c, 5) for c in Y], mat=mat, grp=grp))


def disk(name, d, th, pos, n, mat="gold", grp="house"):
    """flat cylinder facing n"""
    add(name, (th, d, d), pos, n, UP if abs(n[2]) < 0.9 else (1.0, 0.0, 0.0), mat, "Cylinder", grp)


def post(name, d, h, x, y, z0, mat="marble", grp="house"):
    """upright cylinder from z0 to z0 + h"""
    add(name, (h, d, d), (x, y, z0 + h / 2), UP, (1.0, 0.0, 0.0), mat, "Cylinder", grp)


# ---------------- plan (studs)
CX = -0.25                     # house centre in x (the Tripo side windows / roof)
YF, YB = 5.5, -5.85            # front / back wall planes (Tripo door plane 5.6)
HF, HB = 4.6, 3.6              # half width of the front / back faces (2D: front face ~0.62 of the body width)
XS = 7.0                       # side planes CX +- XS (Tripo 6.72; the kept side plants are pushed out 8 %)
YD1, YD2 = 2.0, -2.3           # where the front / back diagonals meet the sides
Z0, Z1 = 1.1, 12.8             # plinth top (= door sill) / cornice bottom (cornice top 13.7 = Tripo roof base)
T = 0.8                        # wall thickness
DOOR_W, DOOR_H = 5.0, 8.15     # arched opening (the Tripo leaf is 4.9 x 8.0)
WIN_W, WIN_Z0, WIN_SPRING = 1.7, 5.9, 8.5   # arched windows (2D: tall and narrow)
V = [(CX - HF, YF), (CX - XS, YD1), (CX - XS, YD2), (CX - HB, YB), (CX + HB, YB), (CX + XS, YD2), (CX + XS, YD1), (CX + HF, YF)]
EDGES = [  # (name, from, to, windows as u fractions)
    ("WallFrontLeft", V[0], V[1], [0.5]),
    ("WallLeft", V[1], V[2], [0.5]),
    ("WallBackLeft", V[2], V[3], []),
    ("WallBack", V[3], V[4], [0.3, 0.7]),
    ("WallBackRight", V[4], V[5], []),
    ("WallRight", V[5], V[6], [0.5]),
    ("WallFrontRight", V[6], V[7], [0.5]),
    ("WallFront", V[7], V[0], []),  # the door (this edge runs +x -> -x)
]


class Wall:
    def __init__(self, name, p0, p1):
        (x0, y0), (x1, y1) = p0, p1
        self.name, self.p0 = name, (x0, y0, 0.0)
        self.L = math.hypot(x1 - x0, y1 - y0)
        self.u = ((x1 - x0) / self.L, (y1 - y0) / self.L, 0.0)
        n = (self.u[1], -self.u[0], 0.0)
        if (CX - (x0 + x1) / 2) * n[0] + (0 - (y0 + y1) / 2) * n[1] > 0:
            n = (-n[0], -n[1], 0.0)        # away from the centre
        self.n = n

    def at(self, uc, z, off=0.0):
        """point on the outer face at u = uc (from p0), height z, `off` outward along n"""
        return vadd(self.p0, vmul(self.u, uc), (0.0, 0.0, z), vmul(self.n, off))

    def slab(self, nm, u0, u1, z0, z1, depth=T, off=0.0, mat="marble"):
        """block on the wall plane, outer face `off` outside the wall face, going `depth` inward"""
        if u1 - u0 < 0.03 or z1 - z0 < 0.03:
            return
        add(nm, (u1 - u0, z1 - z0, depth), self.at((u0 + u1) / 2, (z0 + z1) / 2, off - depth / 2), self.u, UP, mat)

    def arc(self, nm, uc, zc, r_in, w, depth, off, n_seg, mat):
        """half ring (0..180 deg) in the wall plane around (uc, zc): radial r_in..r_in + w, outer face at `off`"""
        r_out = r_in + w
        seg_len = 2 * r_out * math.tan(math.pi / (2 * n_seg)) * 1.04
        for k in range(n_seg):
            t = math.pi * (k + 0.5) / n_seg
            d = vadd(vmul(self.u, math.cos(t)), vmul(UP, math.sin(t)))
            tan = vadd(vmul(self.u, -math.sin(t)), vmul(UP, math.cos(t)))
            c = vadd(self.at(uc, zc, off - depth / 2), vmul(d, r_in + w / 2))
            add("%s%d" % (nm, k), (seg_len, w, depth), c, tan, d, mat)

    def quatrefoil(self, nm, uc, zc, s=1.0):
        for k, (du, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
            disk("%s_Lobe%d" % (nm, k), 0.46 * s, 0.14, self.at(uc + du * 0.27 * s, zc + dz * 0.27 * s, 0.07), self.n)
        disk(nm + "_Core", 0.36 * s, 0.2, self.at(uc, zc, 0.1), self.n)


walls = {}
for name, p0, p1, wins in EDGES:
    w = walls[name] = Wall(name, p0, p1)
    if name == "WallFront":
        holes = [(abs(p0[0] - CX), DOOR_W, Z0, Z0 + DOOR_H)]
    else:
        holes = [(f * w.L, WIN_W, WIN_Z0, WIN_SPRING + WIN_W / 2) for f in wins]
    u = 0.0
    for k, (uc, hw, hz0, hz1) in enumerate(sorted(holes)):
        w.slab("%s_C%d" % (name, k), u, uc - hw / 2, Z0, Z1)
        w.slab("%s_B%d" % (name, k), uc - hw / 2, uc + hw / 2, Z0, hz0)
        w.slab("%s_T%d" % (name, k), uc - hw / 2, uc + hw / 2, hz1, Z1)
        u = uc + hw / 2
    w.slab("%s_C%d" % (name, len(holes)), u, w.L, Z0, Z1)


def window(w, nm, uc):
    r = WIN_W / 2
    g = 0.22
    sp = WIN_SPRING
    # glass: rectangle up to the spring + strips under the arch (recessed 0.3)
    w.slab(nm + "_Glass", uc - r, uc + r, WIN_Z0, sp, 0.12, -0.3, "glass")
    K = 6
    for k in range(K):
        a0, a1 = -r + 2 * r * k / K, -r + 2 * r * (k + 1) / K
        h = math.sqrt(max(r * r - min(abs(a0), abs(a1)) ** 2, 0.0)) if a0 * a1 > 0 else r
        w.slab("%s_GlassArch%d" % (nm, k), uc + a0, uc + a1, sp, sp + h, 0.12, -0.3, "glass")
    # gold frame: jambs + arc (through the wall, 0.12 out on both faces); marble arch band fills the hole corners, 0.2 out
    for side, sg in (("L", -1), ("R", 1)):
        u0 = uc + sg * r
        w.slab(nm + "_Jamb" + side, min(u0, u0 + sg * g), max(u0, u0 + sg * g), WIN_Z0 - 0.1, sp, T + 0.24, 0.12, "gold")
        w.slab(nm + "_Impost" + side, min(u0 + sg * g, u0 + sg * (g + 0.5)), max(u0 + sg * g, u0 + sg * (g + 0.5)),
               sp - 0.12, sp + 0.14, 0.45, 0.25, "gold")
    w.arc(nm + "_FrameArc", uc, sp, r, g, T + 0.24, 0.12, 9, "gold")
    w.arc(nm + "_ArchBand", uc, sp, r + g - 0.02, r * 0.42 + 0.22, T + 0.4, 0.4, 9, "marble")
    w.slab(nm + "_Key", uc - 0.24, uc + 0.24, sp + r + g + 0.1, sp + r + g + 0.75, 0.7, 0.5, "gold")
    w.slab(nm + "_Sill", uc - r - 0.45, uc + r + 0.45, WIN_Z0 - 0.38, WIN_Z0 - 0.08, 0.75, 0.35, "gold")
    w.slab(nm + "_SillStone", uc - r - 0.3, uc + r + 0.3, WIN_Z0 - 0.8, WIN_Z0 - 0.38, 0.55, 0.25, "marble")
    w.slab(nm + "_BarV", uc - 0.05, uc + 0.05, WIN_Z0, sp + r, 0.1, -0.22, "gold")
    w.slab(nm + "_BarH", uc - r, uc + r, sp - 0.05, sp + 0.05, 0.1, -0.22, "gold")


for name, p0, p1, wins in EDGES:
    w = walls[name]
    for k, f in enumerate(wins):
        window(w, "%s_Win%d" % (name, k), f * w.L)
    if name != "WallFront":
        w.quatrefoil(name + "_Medal", w.L / 2, 11.65, 1.15)
        u0, u1, z0, z1, b = 0.95, w.L - 0.95, 10.85, 12.45, 0.18   # raised panel frame around the medallion
        w.slab(name + "_PanelB", u0, u1, z0, z0 + b, 0.3, 0.12)
        w.slab(name + "_PanelT", u0, u1, z1 - b, z1, 0.3, 0.12)
        w.slab(name + "_PanelL", u0, u0 + b, z0 + b, z1 - b, 0.3, 0.12)
        w.slab(name + "_PanelR", u1 - b, u1, z0 + b, z1 - b, 0.3, 0.12)

# ---------------- door: arched opening with a gold frame and a marble band
wf = walls["WallFront"]
DU = abs(V[7][0] - CX)          # door centre along the front edge
DR = DOOR_W / 2
DSP = Z0 + DOOR_H - DR          # spring line
for side, sg in (("A", 1), ("B", -1)):
    u0 = DU + sg * DR
    wf.slab("Door_Jamb" + side, min(u0, u0 + sg * 0.5), max(u0, u0 + sg * 0.5), Z0, DSP, T + 0.3, 0.18, "gold")
    wf.slab("Door_FootBlock" + side, min(u0 + sg * 0.45, u0 + sg * 1.45), max(u0 + sg * 0.45, u0 + sg * 1.45),
            Z0, Z0 + 1.7, 0.9, 0.5, "gold")
wf.arc("Door_FrameArc", DU, DSP, DR, 0.5, T + 0.3, 0.18, 12, "gold")
wf.arc("Door_ArchBand", DU, DSP, DR + 0.48, 0.8, T + 0.3, 0.3, 12, "marble")
# wooden backing behind the Tripo leaf (its arch is narrower than the opening); no collision, the leaf is the door
wf.slab("Door_Back", DU - DR, DU + DR, Z0, DSP, 0.15, -1.15, "wood")
for k in range(8):
    a0, a1 = -DR + DOOR_W * k / 8, -DR + DOOR_W * (k + 1) / 8
    h = math.sqrt(max(DR * DR - min(abs(a0), abs(a1)) ** 2, 0.0)) if a0 * a1 > 0 else DR
    wf.slab("Door_BackArch%d" % k, DU + a0, DU + a1, DSP, DSP + h, 0.15, -1.15, "wood")
wf.slab("Door_Key", DU - 0.3, DU + 0.3, DSP + DR + 0.5, DSP + DR + 1.15, 0.6, 0.35, "gold")
PIER_U = 3.95   # marble piers flanking the door frame; the Tripo lanterns hang on them
for side, sg in (("A", 1), ("B", -1)):
    uc = DU + sg * PIER_U
    wf.slab("DoorPier" + side, uc - 0.6, uc + 0.6, Z0, Z1, 0.9, 0.5)
    wf.slab("DoorPierCap" + side, uc - 0.75, uc + 0.75, Z1 - 1.0, Z1, 1.1, 0.65, "gold")
    wf.slab("DoorPierBand" + side, uc - 0.7, uc + 0.7, 9.25, 9.55, 1.0, 0.6, "gold")
    wf.slab("DoorPierFoot" + side, uc - 0.75, uc + 0.75, Z0, Z0 + 0.4, 1.1, 0.65, "gold")
    wf.slab("DoorPierPlaque" + side, uc - 0.32, uc + 0.32, Z0 + 1.0, Z0 + 2.1, 0.1, 0.6, "gold")
for k, (du, z) in enumerate(((2.9, 11.5), (-2.9, 11.5), (3.6, 10.5), (-3.6, 10.5))):
    add("FrontBall%d" % k, (0.5, 0.5, 0.5), wf.at(DU + du, z, 0.2), mat="gold", shape="Ball")

# ---------------- hollow inside
add("FloorInside", (2 * XS - 0.6, (YF - YB) - 0.6, 0.3), (CX, (YF + YB) / 2, Z0 - 0.15), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), "floor")
add("CeilingSlab", (2 * XS + 0.4, (YF - YB) + 0.4, 0.5), (CX, (YF + YB) / 2, Z1 + 0.25), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), "marble")

# ---------------- pilasters (turned along the corner bisector)
for i, (x, y) in enumerate(V):
    wa, wb = walls[EDGES[i - 1][0]], walls[EDGES[i][0]]
    bis = norm(vadd(wa.n, wb.n))
    along = (-bis[1], bis[0], 0.0)
    c = (x + bis[0] * 0.15, y + bis[1] * 0.15)
    add("Pilaster%d" % i, (1.45, Z1 - Z0, 1.2), (c[0] + bis[0] * 0.1, c[1] + bis[1] * 0.1, (Z0 + Z1) / 2), along, UP)
    add("PilasterCap%d" % i, (1.85, 1.0, 1.6), (c[0] + bis[0] * 0.2, c[1] + bis[1] * 0.2, Z1 - 0.5), along, UP, "gold")
    add("PilasterBand%d" % i, (1.65, 0.3, 1.4), (c[0] + bis[0] * 0.15, c[1] + bis[1] * 0.15, 9.4), along, UP, "gold")
    add("PilasterFoot%d" % i, (1.7, 0.4, 1.45), (c[0] + bis[0] * 0.15, c[1] + bis[1] * 0.15, Z0 + 0.2), along, UP, "gold")


# ---------------- rings with mitred corners
def offset_poly(d):
    out = []
    for i in range(len(V)):
        na, nb = walls[EDGES[i - 1][0]].n, walls[EDGES[i][0]].n
        k = d / (1 + na[0] * nb[0] + na[1] * nb[1])
        out.append((V[i][0] + (na[0] + nb[0]) * k, V[i][1] + (na[1] + nb[1]) * k))
    return out


def ring(prefix, d, z0, z1, depth, mat, skip=()):
    P = offset_poly(d)
    for i, (name, _, _, _) in enumerate(EDGES):
        if name in skip:
            continue
        w = walls[name]
        p0, p1 = P[i], P[(i + 1) % len(P)]
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        add("%s_%s" % (prefix, name), (L, z1 - z0, depth),
            (mx - w.n[0] * depth / 2, my - w.n[1] * depth / 2, (z0 + z1) / 2), w.u, UP, mat)


ring("Plinth", 1.2, 0.0, Z0, 2.0, "marble")
ring("FootRing", 1.4, 0.0, 0.45, 0.5, "gold")
ring("StringCourse", 0.28, 10.25, 10.6, 0.7, "marble", ("WallFront",))
ring("Cornice", 0.6, Z1, Z1 + 0.7, 1.4, "marble")
ring("CorniceGold", 0.72, Z1 + 0.7, Z1 + 0.9, 0.6, "gold")

# ---------------- door steps
add("StepTop", (DOOR_W + 1.6, Z0, 1.5), (CX, YF + 0.75, Z0 / 2))
add("StepLow", (DOOR_W + 2.8, Z0 / 2, 1.1), (CX, YF + 2.05, Z0 / 4))
add("StepTopEdge", (DOOR_W + 1.7, 0.12, 0.25), (CX, YF + 1.45, Z0 - 0.06), mat="gold")

# ---------------- planter beds (the Tripo plants wrap the left and right sides) + the round front-right planter
def bed(prefix, names, d_out, h, medal_on=()):
    """trough along the listed consecutive walls: outer wall at d_out, soil up to the house wall, open ends capped"""
    idx = [i for i, e in enumerate(EDGES) if e[0] in names]
    full = offset_poly(d_out)

    def ends(i, d):
        w = walls[EDGES[i][0]]
        P = offset_poly(d)
        a0 = P[i] if (i - 1) % len(EDGES) in idx else (V[i][0] + w.n[0] * d, V[i][1] + w.n[1] * d)
        j = (i + 1) % len(EDGES)
        a1 = P[j] if j in idx else (V[j][0] + w.n[0] * d, V[j][1] + w.n[1] * d)
        return a0, a1

    def strip(nm, i, d, depth, z0, z1, mat):
        w = walls[EDGES[i][0]]
        p0, p1 = ends(i, d)
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        add(nm, (L, z1 - z0, depth), ((p0[0] + p1[0]) / 2 - w.n[0] * depth / 2, (p0[1] + p1[1]) / 2 - w.n[1] * depth / 2,
                                      (z0 + z1) / 2), w.u, UP, mat)

    for i in idx:
        en = EDGES[i][0]
        strip("%s_Wall_%s" % (prefix, en), i, d_out, 0.45, 0.0, h - 0.25, "marble")
        strip("%s_Rim_%s" % (prefix, en), i, d_out + 0.12, 0.7, h - 0.25, h, "marble")
        strip("%s_GoldBase_%s" % (prefix, en), i, d_out + 0.1, 0.4, 0.0, 0.55, "gold")
        strip("%s_GoldLine_%s" % (prefix, en), i, d_out + 0.05, 0.3, h - 0.42, h - 0.3, "gold")
        strip("%s_Soil_%s" % (prefix, en), i, d_out - 0.4, d_out - 0.4, h - 0.4, h - 0.1, "soil")
        if en in medal_on:
            w = walls[en]
            p0, p1 = ends(i, d_out)
            mid = ((p0[0] + p1[0]) / 2 + w.n[0] * 0.02, (p0[1] + p1[1]) / 2 + w.n[1] * 0.02)
            for k, (du, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
                disk("%s_%s_Lobe%d" % (prefix, en, k), 0.46, 0.14,
                     (mid[0] + w.u[0] * du * 0.28 + w.n[0] * 0.07, mid[1] + w.u[1] * du * 0.28 + w.n[1] * 0.07, h * 0.5 + dz * 0.28), w.n)
            disk("%s_%s_Core" % (prefix, en), 0.36, 0.2, (mid[0] + w.n[0] * 0.1, mid[1] + w.n[1] * 0.1, h * 0.5), w.n)
    for i in idx:   # caps where the bed stops
        w = walls[EDGES[i][0]]
        for j, vi in ((i - 1, i), ((i + 1) % len(EDGES), (i + 1) % len(EDGES))):
            if j % len(EDGES) in idx:
                continue
            x, y = V[vi]
            add("%s_Cap%d" % (prefix, vi), (d_out + 0.1, h, 0.45), (x + w.n[0] * d_out / 2, y + w.n[1] * d_out / 2, h / 2), w.n, UP)
            add("%s_CapGold%d" % (prefix, vi), (d_out + 0.2, 0.55, 0.55), (x + w.n[0] * d_out / 2, y + w.n[1] * d_out / 2, 0.275), w.n, UP, "gold")


bed("BedL", ("WallFrontLeft", "WallLeft", "WallBackLeft"), 2.1, 2.6, ("WallFrontLeft",))
bed("BedR", ("WallBackRight", "WallRight"), 2.1, 2.4, ("WallRight",))
PLANTERS = [("PlanterR", 5.2, 5.6, 4.0, 2.3)]
for nm, x, y, d, h in PLANTERS:
    post(nm, d, h - 0.3, x, y, 0.0)
    post(nm + "_Rim", d + 0.3, 0.3, x, y, h - 0.3)
    post(nm + "_GoldBase", d + 0.35, 0.6, x, y, 0.0, "gold")
    post(nm + "_GoldRimLine", d + 0.34, 0.1, x, y, h - 0.42, "gold")
    post(nm + "_Soil", d - 0.35, 0.12, x, y, h - 0.05, "soil")
    fy = y + d / 2 + 0.02
    for k, (dx, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        disk("%s_Lobe%d" % (nm, k), 0.5, 0.14, (x + dx * 0.3, fy, 1.3 + dz * 0.3), (0.0, 1.0, 0.0))
    disk(nm + "_Core", 0.4, 0.2, (x, fy + 0.03, 1.3), (0.0, 1.0, 0.0))

# lamp glass inside the kept Tripo lantern frames (Neon + PointLight; the Tripo lamp glass is stone-coloured and was cut)
for nm, x in (("LampGlassL", CX - 3.92), ("LampGlassR", CX + 3.98)):
    add(nm, (0.62, 0.85, 0.62), (x, YF + 0.95, 7.45), mat="lamp")

# ---------------- RoundTree_E pot (r 2.4, h 2.0), well away from the house
PX, PY = 26.0, 0.0
post("Pot_Body", 4.6, 1.85, PX, PY, 0.08, grp="pot")
post("Pot_RingBottom", 5.0, 0.35, PX, PY, 0.0, "gold", "pot")
post("Pot_Rim", 5.0, 0.3, PX, PY, 1.75, "gold", "pot")
post("Pot_Soil", 4.4, 0.12, PX, PY, 2.04, "soil", "pot")
for k in range(4):
    ang = math.radians(45 + 90 * k)
    n = (math.cos(ang), math.sin(ang), 0.0)
    add("Pot_Plaque%d" % k, (0.6, 0.9, 0.12), (PX + 2.32 * n[0], PY + 2.32 * n[1], 1.05), (-n[1], n[0], 0.0), UP, "sky", grp="pot")

# ---------------- where the kept Tripo pieces go (tools/skeleton_place.py)
DOOR_LEAF = {"arch": [-0.85, DSP, 2.42], "no_white": True}   # Tripo leaf centre x -0.85: drop old frame bits and stone flecks
DORMER_BOX = {"z": [11.0, 13.5], "y": [4.0, 9.0], "x": [-1.9, 1.9]}
place = {
    "note": "kept Tripo pieces of HaloDomeHouse_07 on the v3 skeleton (Blender frame of the parts GLB)",
    "kinds": {
        # the planked leaf is 3.7 wide around x -0.2 (the rest of the Tripo door was its reveal): widen it 15 % and centre it
        "Door": [{"region": dict(DOOR_LEAF, no_gold=True), "scale": [1.15, 1, 1], "about": [-0.2, 0, 0], "move": [CX + 0.2, 0, 0]}],
        "DoorHw": [{"region": dict(DOOR_LEAF, drop_tall=2.0, z=[0.0, 8.3]), "scale": [1.15, 1, 1], "about": [-0.2, 0, 0],
                    "move": [CX + 0.2, 0, 0]}],
        "Awning": [{"region": {"drop_boxes": [[[-9, 9], [0, 6.0], [0, 9.5]]]}, "move": [CX - 0.13, 0, 0]}],
        "Dormer": [{"move": [CX - 0.1, 0, 0]}],
        "WinPane": [{"region": DORMER_BOX, "move": [CX - 0.1, 0, 0], "rename": "DormerPane"}],
        "Glass": [{"region": DORMER_BOX, "move": [CX - 0.1, 0, 0], "rename": "DormerGlass"}],
        "Roof": [{"scale": [1.12, 1.08, 1.0], "about": [CX, (YF + YB) / 2, 13.6]}],
        "Lanterns": [{"region": {"x": [-20, -0.5], "y": [4.0, 20]}, "align": {"cx": CX - 3.95, "ymin": YF + 0.25}, "rename": "LanternL"},
                     {"region": {"x": [0.5, 20], "y": [4.0, 20]}, "align": {"cx": CX + 3.95, "ymin": YF + 0.25}, "rename": "LanternR"}],
        "Plants": [{"region": {"near": [5.0, 5.65, 3.0], "y": [2.5, 20]}, "rename": "PlantsR"},
                   {"scale": [1.08, 1.06, 1.0], "about": [CX, (YF + YB) / 2, 0.0], "rename": "PlantsBed"}],
    },
}

# ---------------- Luau
MAT = {
    "marble": 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleBlock"; p.Color = Color3.fromRGB(255, 252, 245)',
    "floor": 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleBlock"; p.Color = Color3.fromRGB(235, 228, 215)',
    "gold": 'p.Material = Enum.Material.Metal; p.MaterialVariant = "HH_HaloGoldTrim"; p.Color = Color3.fromRGB(240, 186, 56)',
    "soil": 'p.Material = Enum.Material.Ground; p.Color = Color3.fromRGB(139, 101, 66)',
    "sky": 'p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(150, 200, 240)',
    "wood": 'p.Material = Enum.Material.Wood; p.Color = Color3.fromRGB(150, 94, 52); p.CanCollide = false',
    "lamp": 'p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 226, 150); local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 214, 140); l.Brightness = 1.2; l.Range = 14; l.Parent = p',
    "glass": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(170, 215, 245); p.Transparency = 0.35; p.Reflectance = 0.2',
}


def r3(v):  # Blender vector -> Roblox
    return (v[0], v[2], -v[1])


L = ['-- skeleton v3 (generated by tools/skeleton_house07.py, 이미지 생성 3 10/11, SPEC A23-120). WorldKit only.',
     'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end',
     'local root = workspace:FindFirstChild("SkeletonTest") or Instance.new("Folder"); root.Name = "SkeletonTest"; root.Parent = workspace',
     'for _, n in {"House07_Skeleton", "Tree_Pot_Skeleton"} do local o = root:FindFirstChild(n); if o then o:Destroy() end end',
     'local house = Instance.new("Model"); house.Name = "House07_Skeleton"; house.Parent = root',
     'local pot = Instance.new("Model"); pot.Name = "Tree_Pot_Skeleton"; pot.Parent = root',
     'local function mk(parent, name, shape, sx, sy, sz, x, y, z, ax, ay, az, bx, by, bz, mat)',
     '  local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth',
     '  p.Shape = Enum.PartType[shape]',
     '  p.Size = Vector3.new(sx, sy, sz)',
     '  p.CFrame = CFrame.fromMatrix(Vector3.new(x, y, z), Vector3.new(ax, ay, az), Vector3.new(bx, by, bz))']
for i, (k, v) in enumerate(MAT.items()):
    L.append('  %s mat == "%s" then %s' % ("if" if i == 0 else "elseif", k, v))
L += ['  end', '  if mat == "glass" or mat == "lamp" then p.CastShadow = false end', '  p.Parent = parent; return p', 'end']
for p in parts:
    x, y, z = p["pos"]
    X, Y = r3(p["X"]), r3(p["Y"])
    L.append('mk(%s, "%s", "%s", %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, "%s")' % (
        p["grp"], p["name"], p["shape"], *p["size"], OX + x, OY + z, OZ - y, *X, *Y, p["mat"]))
L.append('local d = Instance.new("Attachment"); d.Name = "DoorFront"; d.Position = Vector3.new(0, %.2f, 0); d.Parent = house:FindFirstChild("StepLow")' % (Z0 / 4))
L.append('local n = 0; for _, q in root:GetDescendants() do if q:IsA("BasePart") then n += 1 end end')
L.append('return "SkeletonTest v3 built: " .. n .. " parts"')
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
open(a.out, "w", encoding="utf-8").write("\n".join(L) + "\n")
base = os.path.splitext(a.out)[0]
json.dump(parts, open(base + ".json", "w"), indent=0)
json.dump(place, open(base + "_place.json", "w"), indent=1)
print("[skeleton] parts", len(parts), "(house %d, pot %d) ->" % (sum(p["grp"] == "house" for p in parts),
      sum(p["grp"] == "pot" for p in parts)), a.out)
