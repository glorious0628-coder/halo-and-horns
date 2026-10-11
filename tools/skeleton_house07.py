"""Studio skeleton v4 for HaloDomeHouse_07 + RoundTree_E pot (검수 10/11, SPEC A23-120 "건물 골격 먼저"; 이미지 생성 3).

  py tools/skeleton_house07.py [--origin 3000,0,0] [--out build/skeleton_test_07.luau] [--marble cream|block]

v4 follows the 2D front (art/out/s2/halo/roofs/HaloDomeHouse_07_roof_v2.png; wall width : wall height : roof = 1 : 0.81 : 0.33)
and the 검수 v3 verdict (low and wide octagon, joined gold bands, visible diagonal windows, marble door reveal + thick gold
arch, round pots with soil, marble 1판 vs cream 2판):
  - octagon 16 wide (XS 8.0), front face 10.5 (HF 5.25), the front diagonals bent back 2.75 x 3.2 so they show in front view
    like the 2D; the door stays 5.0 x 8.15 (A23-106) and the house grows around it;
  - the marble tile's courses start at the TOP of each part (WorldKit probe 10/11), so every wall slab ends at the cornice
    line Z1 and the gold bands sit on course lines counted down from Z1: impost band at the window springs (Z1 - 4.5, a
    course line of both tiles), frieze band under the medallion panels, cornice + gold top, plinth + gold foot ring;
    window sills and front pedestals also end on course lines (course = 9/8 studs for the 9-stud block, 1.5 for cream 12);
  - arched windows: gold jambs + arc through the wall, glass only 0.12 inside, marble hood, gold keystone and sill;
  - door: marble reveal lining inside the opening down to the recessed Tripo leaf + a 0.7 gold arch frame standing 0.3 out,
    marble band outside; no more dark gap;
  - corner pilasters with big gold capitals and a band on the impost line; marble pedestals with a gold cap and plaque at the
    two front corners (the 2D blocks beside the door);
  - round pots at the front corners (marble body, ring rim, sand soil 0.25 under the rim, gold foot and line, quatrefoil)
    holding the front Tripo plants; troughs along the sides / back diagonals for the other plant clusters (each cluster is
    scaled 1.15 and moved onto its bed's centre line); a half-round two-step stair (upright cylinders half in the wall);
  - hollow inside (floor + ceiling slab), DoorFront in front of the steps.
Gold = Metal + MaterialVariant HH_HaloGoldTrim, marble = Marble + HH_HaloMarbleBlock / HH_HaloMarbleBlock_Cream (이미지 개발).
Also writes <out>.json (parts for tools/skeleton_preview.py), <out>_place.json (where tools/skeleton_place.py moves the
kept Tripo pieces), <out>_cams.json (close-up cameras for the preview) and <out>_ornaments.json (knocker, hinges and
lantern frames for tools/metal_ornaments.py; Blender-made, exact circles — no Tripo hardware).
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
ap.add_argument("--marble", default="cream", choices=["block", "cream"])   # 10/11 pick: cream 2판 + warm tint
a = ap.parse_args()
OX, OY, OZ = [float(v) for v in a.origin.split(",")]
VARIANT, COURSE = {"block": ("HH_HaloMarbleBlock", 9 / 8), "cream": ("HH_HaloMarbleBlock_Cream", 1.5)}[a.marble]
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


def ring_blocks(name, x, y, r_in, w, z0, z1, n_seg=18, mat="marble", grp="house"):
    """flat ring around an upright axis made of n_seg blocks (a hollow rim)"""
    r_out = r_in + w
    seg = 2 * r_out * math.tan(math.pi / n_seg) * 1.04
    for k in range(n_seg):
        t = 2 * math.pi * k / n_seg
        d = (math.cos(t), math.sin(t), 0.0)
        add("%s%d" % (name, k), (seg, z1 - z0, w), (x + d[0] * (r_in + w / 2), y + d[1] * (r_in + w / 2), (z0 + z1) / 2),
            (-d[1], d[0], 0.0), UP, mat, grp=grp)


def on_course(z_target):
    """first course line (texture courses start at the part top, counted down from Z1) at or under z_target"""
    return Z1 - math.ceil((Z1 - z_target) / COURSE - 1e-6) * COURSE


# ---------------- plan (studs)
CX, CY = -0.25, -0.125         # plan centre = centre of the Tripo body (its roof / plants are placed from it)
HF, XS, HB = 4.75, 7.6, 4.75   # half width of the front face / side planes / half width of the back face
GROW = XS / 6.72               # house size / Tripo body size (side planes 6.72)
DXF = DYF = XS - HF            # 45-degree diagonals (the Tripo roof's octagon), 2.85 across as the 2D front shows them
YF, YB = CY + 5.725 * GROW, CY - 5.725 * GROW  # front / back wall planes (Tripo body 5.6 / -5.85)
YD1, YD2 = YF - DYF, YB + DYF
Z0 = 1.1                       # plinth top = door sill
Z1 = Z0 + 10 * 9 / 8           # cornice bottom 12.35 (ten 9/8 courses; cornice top 13.25, the roof sits on it)
T = 0.8                        # wall thickness
DOOR_W, DOOR_H = 5.0, 8.15     # arched opening (A23-106); the Tripo leaf is 4.3 wide, its spring = the opening's
IMP0 = Z1 - 4.5                # impost band 7.85 (a course line of both tiles) .. 8.2 = window spring line
IMP1 = IMP0 + 0.35
WIN_W, WIN_SPRING = 1.6, IMP1
WIN_Z0 = on_course(5.6)        # window bottom on a course line (block 5.6, cream 4.85)
FRZ0 = on_course(10.9)         # frieze band under the medallion panels (block 10.1, cream 10.85)
FRZ1 = FRZ0 + 0.3
PED_Z = Z1 - round((Z1 - 4.5) / COURSE) * COURSE   # front pedestal top (block 4.475, cream 4.85)
V = [(CX - HF, YF), (CX - XS, YD1), (CX - XS, YD2), (CX - HB, YB), (CX + HB, YB), (CX + XS, YD2), (CX + XS, YD1), (CX + HF, YF)]
EDGES = [  # (name, from, to, windows as u fractions)
    ("WallFrontLeft", V[0], V[1], [0.5]),
    ("WallLeft", V[1], V[2], [0.5]),
    ("WallBackLeft", V[2], V[3], [0.5]),
    ("WallBack", V[3], V[4], [0.3, 0.7]),
    ("WallBackRight", V[4], V[5], [0.5]),
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
        if (CX - (x0 + x1) / 2) * n[0] + (CY - (y0 + y1) / 2) * n[1] > 0:
            n = (-n[0], -n[1], 0.0)        # away from the centre
        self.n = n

    def at(self, uc, z, off=0.0):
        """point on the outer face at u = uc (from p0), height z, `off` outward along n"""
        return vadd(self.p0, vmul(self.u, uc), (0.0, 0.0, z), vmul(self.n, off))

    def dist(self, x, y):
        """how far (x, y) is outside the wall face"""
        return (x - self.p0[0]) * self.n[0] + (y - self.p0[1]) * self.n[1]

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
        """raised medallion (검수 v4: no flat stickers): gold rim lip, marble boss 0.26 out, gold quatrefoil 0.2 more"""
        disk(nm + "_Rim", 1.3 * s, 0.14, self.at(uc, zc, 0.07), self.n)
        disk(nm + "_Boss", 1.1 * s, 0.26, self.at(uc, zc, 0.13), self.n, "marble")
        for k, (du, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
            disk("%s_Lobe%d" % (nm, k), 0.42 * s, 0.2, self.at(uc + du * 0.25 * s, zc + dz * 0.25 * s, 0.36), self.n)
        disk(nm + "_Core", 0.34 * s, 0.3, self.at(uc, zc, 0.41), self.n)


walls = {}
win_gaps = {}
for name, p0, p1, wins in EDGES:
    w = walls[name] = Wall(name, p0, p1)
    if name == "WallFront":
        holes = [(abs(p0[0] - CX), DOOR_W, Z0, Z0 + DOOR_H)]
    else:
        holes = [(f * w.L, WIN_W, WIN_Z0, WIN_SPRING + WIN_W / 2) for f in wins]
    win_gaps[name] = [(uc - hw / 2 - 0.22, uc + hw / 2 + 0.22) for uc, hw, _, _ in holes]
    u = 0.0
    for k, (uc, hw, hz0, hz1) in enumerate(sorted(holes)):
        w.slab("%s_C%d" % (name, k), u, uc - hw / 2, Z0, Z1)      # all wall slabs end at Z1: courses line up
        w.slab("%s_B%d" % (name, k), uc - hw / 2, uc + hw / 2, Z0, hz0)
        w.slab("%s_T%d" % (name, k), uc - hw / 2, uc + hw / 2, hz1, Z1)
        u = uc + hw / 2
    w.slab("%s_C%d" % (name, len(holes)), u, w.L, Z0, Z1)


def window(w, nm, uc):
    r = WIN_W / 2
    g = 0.22
    sp = WIN_SPRING
    # glass: rectangle up to the spring + strips under the arch, only 0.12 inside so the front view shows it
    w.slab(nm + "_Glass", uc - r, uc + r, WIN_Z0, sp, 0.1, -0.12, "glass")
    K = 6
    for k in range(K):
        a0, a1 = -r + 2 * r * k / K, -r + 2 * r * (k + 1) / K
        h = math.sqrt(max(r * r - min(abs(a0), abs(a1)) ** 2, 0.0)) if a0 * a1 > 0 else r
        w.slab("%s_GlassArch%d" % (nm, k), uc + a0, uc + a1, sp, sp + h, 0.1, -0.12, "glass")
    # gold frame: jambs + arc through the wall, 0.15 out; marble hood over the arc; keystone, sill, mullion + transom
    for side, sg in (("L", -1), ("R", 1)):
        u0 = uc + sg * r
        w.slab(nm + "_Jamb" + side, min(u0, u0 + sg * g), max(u0, u0 + sg * g), WIN_Z0 - 0.1, sp, T + 0.3, 0.15, "gold")
    w.arc(nm + "_FrameArc", uc, sp, r, g, T + 0.3, 0.15, 9, "gold")
    w.arc(nm + "_Hood", uc, sp, r + g - 0.02, 0.3, T + 0.45, 0.32, 9, "marble")
    w.slab(nm + "_Key", uc - 0.26, uc + 0.26, sp + r + g + 0.05, sp + r + g + 0.75, 0.8, 0.45, "gold")   # keystone + a cap
    w.slab(nm + "_KeyCap", uc - 0.36, uc + 0.36, sp + r + g + 0.75, sp + r + g + 0.92, 0.95, 0.6, "gold")
    w.slab(nm + "_Sill", uc - r - 0.4, uc + r + 0.4, WIN_Z0 - 0.3, WIN_Z0, 0.75, 0.35, "gold")
    w.slab(nm + "_SillStone", uc - r - 0.28, uc + r + 0.28, WIN_Z0 - 0.7, WIN_Z0 - 0.3, 0.55, 0.25, "marble")
    w.slab(nm + "_BarV", uc - 0.05, uc + 0.05, WIN_Z0, sp + r, 0.08, -0.06, "gold")
    w.slab(nm + "_BarH", uc - r, uc + r, sp - 0.05, sp + 0.05, 0.08, -0.06, "gold")


med_s = min(1.0, (Z1 - FRZ1 - 0.12) / 1.3)
MEDALS = ("WallFrontLeft", "WallFrontRight", "WallLeft", "WallRight", "WallBack")   # as in the 2D: a few, between the windows
for name, p0, p1, wins in EDGES:
    w = walls[name]
    for k, f in enumerate(wins):
        window(w, "%s_Win%d" % (name, k), f * w.L)
    if name in MEDALS:
        zc = (FRZ1 + Z1) / 2
        w.quatrefoil(name + "_Medal", w.L / 2, zc, med_s)
        u0, u1, z0, z1, b = 0.95, w.L - 0.95, FRZ1 + 0.15, Z1 - 0.12, 0.16   # raised marble panel around the medallion
        if z1 - z0 > 1.3 * med_s + 0.4:
            w.slab(name + "_PanelB", u0, u1, z0, z0 + b, 0.3, 0.12)
            w.slab(name + "_PanelT", u0, u1, z1 - b, z1, 0.3, 0.12)
            w.slab(name + "_PanelL", u0, u0 + b, z0 + b, z1 - b, 0.3, 0.12)
            w.slab(name + "_PanelR", u1 - b, u1, z0 + b, z1 - b, 0.3, 0.12)
    if name != "WallFront":
        # impost band: one gold line on the window springs, broken only by the window frames (the pilasters cover the corners)
        u = 0.0
        for g0, g1 in sorted(win_gaps[name]) + [(w.L, w.L)]:
            w.slab("%s_Impost%d" % (name, int(u * 10)), u, g0, IMP0, IMP1, 0.5, 0.18, "gold")
            u = g1

# ---------------- door: marble reveal down to the recessed leaf, thick gold arch frame, marble band
wf = walls["WallFront"]
DU = abs(V[7][0] - CX)          # door centre along the front edge
DR = DOOR_W / 2
DSP = Z0 + DOOR_H - DR          # spring line 6.75
LEAF_R = 2.05                   # reveal edge 0.1 over the Tripo leaf (4.3 wide, same spring) so no gap shows
LEAF_OFF = -0.4                 # leaf front face this far inside the wall face
GW = 0.7                        # gold frame width
for side, sg in (("A", 1), ("B", -1)):
    u0 = DU + sg * DR
    wf.slab("Door_Reveal" + side, min(u0, u0 - sg * (DR - LEAF_R)), max(u0, u0 - sg * (DR - LEAF_R)), Z0, DSP, T + 0.25, 0.25)
    wf.slab("Door_Jamb" + side, min(u0, u0 + sg * GW), max(u0, u0 + sg * GW), Z0, DSP, T + 0.3, 0.3, "gold")
    wf.slab("Door_FootBlock" + side, min(u0 + sg * GW, u0 + sg * (GW + 0.75)), max(u0 + sg * GW, u0 + sg * (GW + 0.75)),
            Z0, Z0 + 1.7, 0.9, 0.5, "gold")
wf.arc("Door_RevealArc", DU, DSP, LEAF_R, DR - LEAF_R, T + 0.25, 0.25, 12, "marble")
wf.arc("Door_FrameArc", DU, DSP, DR, GW, T + 0.3, 0.3, 14, "gold")
wf.arc("Door_ArchBand", DU, DSP, DR + GW - 0.02, 0.45, T + 0.2, 0.2, 14, "marble")
wf.slab("Door_Threshold", DU - LEAF_R, DU + LEAF_R, Z0 - 0.02, Z0 + 0.1, -LEAF_OFF + 0.05, 0.05)
# light wooden backing behind the leaf (no collision) so no gap ever shows the dark inside
wf.slab("Door_Back", DU - LEAF_R, DU + LEAF_R, Z0, DSP, 0.1, LEAF_OFF - 1.15, "wood")
for k in range(8):
    a0, a1 = -LEAF_R + 2 * LEAF_R * k / 8, -LEAF_R + 2 * LEAF_R * (k + 1) / 8
    h = math.sqrt(max(LEAF_R * LEAF_R - min(abs(a0), abs(a1)) ** 2, 0.0)) if a0 * a1 > 0 else LEAF_R
    wf.slab("Door_BackArch%d" % k, DU + a0, DU + a1, DSP, DSP + h, 0.1, LEAF_OFF - 1.15, "wood")
for k, (du, z) in enumerate(((3.5, Z1 - 0.75), (-3.5, Z1 - 0.75), (3.7, FRZ0 + 0.75), (-3.7, FRZ0 + 0.75))):
    add("FrontBall%d" % k, (0.5, 0.5, 0.5), wf.at(DU + du, z, 0.2), mat="gold", shape="Ball")

# ---------------- hollow inside: floor + ceiling as strips inside the octagon (검수 10/11 저녁: the old bounding-box
# ceiling stuck about 2 studs out past the diagonal walls); the strip over the plan centre keeps the plain name
def oct_slab(nm, d, zc, th, mat, tol=0.5):
    Pp = []
    for i in range(len(V)):
        na, nb = walls[EDGES[i - 1][0]].n, walls[EDGES[i][0]].n
        k = d / (1 + na[0] * nb[0] + na[1] * nb[1])
        Pp.append((V[i][0] + (na[0] + nb[0]) * k, V[i][1] + (na[1] + nb[1]) * k))

    def span(y):
        cut = []
        for i in range(len(Pp)):
            (x0, y0), (x1, y1) = Pp[i], Pp[(i + 1) % len(Pp)]
            if y0 != y1 and (y0 - y) * (y1 - y) <= 0:
                cut.append(x0 + (x1 - x0) * (y - y0) / (y1 - y0))
        return (min(cut), max(cut)) if len(cut) >= 2 else None
    py = [y for _, y in Pp]
    y0, yend, k = min(py) + 0.02, max(py) - 0.02, 0
    while y0 < yend - 0.05:
        for h in (3.0, 2.0, 1.0, 0.5):
            y1 = min(y0 + h, yend)
            s0, s1 = span(y0), span(y1)
            if s0 and s1 and abs(s0[0] - s1[0]) <= tol and abs(s0[1] - s1[1]) <= tol:
                break
        if s0 and s1 and min(s0[1], s1[1]) - max(s0[0], s1[0]) > 0.05:
            a_, b_ = max(s0[0], s1[0]), min(s0[1], s1[1])
            add(nm if y0 <= CY < y1 else "%s_%d" % (nm, k), (b_ - a_, y1 - y0, th), ((a_ + b_) / 2, (y0 + y1) / 2, zc),
                (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), mat)
            k += 1
        y0 = y1


oct_slab("FloorInside", -0.3, Z0 - 0.15, 0.3, "floor")
oct_slab("CeilingSlab", 0.2, Z1 + 0.25, 0.5, "marble")

# ---------------- pilasters: big gold capital, band on the impost line, gold foot. They stay inside the cornice line (the
# 2D cornice is the widest part of the walls). The two front ones face the front (the lanterns hang on them) and stand on
# the front pedestals; the others turn along the corner bisector.
PIL_OUT = 0.85                 # pilaster face this far outside the corner (검수 v4c: 0.4 more, the 2D pilasters stand out)
for i, (x, y) in enumerate(V):
    wa, wb = walls[EDGES[i - 1][0]], walls[EDGES[i][0]]
    if i in (0, 7):
        bis, wd, z0 = (0.0, 1.0, 0.0), 1.5, PED_Z + 0.35
    else:
        bis, wd, z0 = norm(vadd(wa.n, wb.n)), 1.3, Z0
    along = (-bis[1], bis[0], 0.0)

    def pc(face_out, depth):
        o = face_out - depth / 2
        return (x + bis[0] * o, y + bis[1] * o)

    add("Pilaster%d" % i, (wd, Z1 - z0, 1.2), (*pc(PIL_OUT, 1.2), (z0 + Z1) / 2), along, UP)
    add("PilasterCap%d" % i, (wd + 0.4, 1.0, 1.5), (*pc(PIL_OUT + 0.2, 1.5), Z1 - 0.5), along, UP, "gold")
    add("PilasterCapTop%d" % i, (wd + 0.55, 0.18, 1.6), (*pc(PIL_OUT + 0.27, 1.6), Z1 - 0.09), along, UP, "gold")
    add("PilasterBand%d" % i, (wd + 0.2, IMP1 - IMP0, 1.4), (*pc(PIL_OUT + 0.1, 1.4), (IMP0 + IMP1) / 2), along, UP, "gold")
    if i not in (0, 7):
        add("PilasterFoot%d" % i, (wd + 0.25, 0.4, 1.45), (*pc(PIL_OUT + 0.1, 1.45), Z0 + 0.2), along, UP, "gold")

# front pedestals (the 2D blocks beside the door, the feet of the front pilasters): marble block, gold cap, plaque, foot
PED_W, PED_FRONT = 1.8, YF + 1.1
for nm, i in (("PedestalL", 0), ("PedestalR", 7)):
    x, y = V[i]
    sx = -1 if i == 0 else 1
    pc = (x + sx * 0.1, (PED_FRONT + YF - 0.6) / 2)
    dep = PED_FRONT - (YF - 0.6)
    add(nm, (PED_W, PED_Z, dep), (pc[0], pc[1], PED_Z / 2))
    add(nm + "_Cap", (PED_W + 0.12, 0.35, dep + 0.12), (pc[0], pc[1], PED_Z + 0.175), mat="gold")   # half the old overhang
    add(nm + "_Foot", (PED_W + 0.2, 0.55, dep + 0.2), (pc[0], pc[1], 0.275), mat="gold")
    add(nm + "_Plaque", (0.7, 1.2, 0.1), (pc[0], PED_FRONT + 0.03, 2.0), mat="gold")


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
ring("FootRing", 1.4, 0.0, 0.55, 0.5, "gold")            # one unbroken gold foot line all round
ring("Frieze", 0.15, FRZ0, FRZ1, 0.45, "gold")           # the second gold line, front face too
ring("Cornice", 1.2, Z1, Z1 + 0.7, 2.0, "marble")       # still the widest line, past the pilaster capitals
ring("CorniceGold", 1.32, Z1 + 0.7, Z1 + 0.9, 0.85, "gold")

# ---------------- half-round two-step stair (upright cylinders, half in the wall)
post("StepTop", 6.6, Z0 - 0.01, CX, YF, 0.0)
post("StepLow", 8.4, Z0 / 2, CX, YF, 0.0)


# ---------------- planter troughs along the sides / back diagonals + round pots at the front corners
def bed(prefix, names, d_out, h, medal_on=()):
    """trough along the listed consecutive walls: outer wall at d_out, soil up to the house wall, open ends capped"""
    idx = [i for i, e in enumerate(EDGES) if e[0] in names]

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
        strip("%s_Rim_%s" % (prefix, en), i, d_out + 0.12, 0.6, h - 0.25, h, "marble")
        strip("%s_GoldBase_%s" % (prefix, en), i, d_out + 0.1, 0.4, 0.0, 0.55, "gold")
        strip("%s_GoldLine_%s" % (prefix, en), i, d_out + 0.05, 0.3, h - 0.42, h - 0.3, "gold")
        strip("%s_Soil_%s" % (prefix, en), i, d_out - 0.45, d_out - 0.45, h - 0.55, h - 0.25, "soil")
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


BED_D = 1.8                    # narrow side troughs: the 2D base is only a little wider than the walls
BEDS = [("BedL", ("WallLeft", "WallBackLeft"), 3.0, ("WallLeft",)), ("BedR", ("WallBackRight", "WallRight"), 2.75, ("WallRight",))]
for nm, names, h, medal in BEDS:
    bed(nm, names, BED_D, h, medal)


# round pots in front of the front corners (the 2D beds): partly sunk into the diagonal walls, the pedestals stand before
# their inner ends as in the 2D
POTS = [("PotL", (CX - 6.6, YF - 0.3), 4.2, 3.0), ("PotR", (CX + 6.6, YF - 0.3), 4.0, 2.65)]
pot_xy = {}
for nm, (x, y), d, h in POTS:
    pot_xy[nm] = (x, y)
    post(nm, d, h - 0.4, x, y, 0.0)                                  # body
    post(nm + "_Soil", d - 0.25, 0.15, x, y, h - 0.4, "soil")        # soil 0.25 under the rim top
    ring_blocks(nm + "_Rim", x, y, d / 2 - 0.12, 0.34, h - 0.4, h)  # hollow rim so the soil shows
    post(nm + "_GoldBase", d + 0.35, 0.55, x, y, 0.0, "gold")
    post(nm + "_GoldLine", d + 0.06, 0.12, x, y, h - 0.75, "gold")
    fy = y + d / 2 + 0.02
    for k, (dx, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
        disk("%s_Lobe%d" % (nm, k), 0.5, 0.14, (x + dx * 0.3, fy, h * 0.45 + dz * 0.3), (0.0, 1.0, 0.0))
    disk(nm + "_Core", 0.4, 0.2, (x, fy + 0.03, h * 0.45), (0.0, 1.0, 0.0))

# lanterns: gold frames made in Blender (tools/metal_ornaments.py, 검수 10/11 "round and straight metal by script, not
# Tripo"); the glass inside them is this skeleton part (Glass + PointLight for WeatherFx)
LANT_U, LANT_Y = HF - 0.35, YF + PIL_OUT   # lanterns hang on the front faces of the front pilasters
LANT_W, LANT_H, LANT_POST, LANT_Z = 0.9, 1.15, 0.09, 7.6
LANT_C = LANT_Y + 0.25 + LANT_W / 2        # glass box centre (y): bracket arm 0.25 off the pilaster
for nm, x in (("LampGlassL", CX - LANT_U), ("LampGlassR", CX + LANT_U)):
    g = LANT_W - 2 * LANT_POST - 0.02
    add(nm, (g, LANT_H - 0.1, g), (x, LANT_C, LANT_Z), mat="lamp")

# ---------------- awning (검수 v4c: the Tripo awning reads as a small gold lump; its map is cut into gold-orange islands,
# so a recolour would need a new texture upload + re-import): cream / yellow striped cloth of parts, Fabric + HH_Fabric (plain Fabric read as a dark check; 이미지 개발 10/11), a
# scalloped valance, a gold rod at the wall and gold balls at the corners, as in the 2D. Sits under the dormer.
AW_W, AW_D, AW_TOP, AW_DROP, AW_N = 7.4, 2.3, 10.55, 1.2, 7
aw_len = math.hypot(AW_D, AW_DROP)
aw_n = (0.0, AW_DROP / aw_len, AW_D / aw_len)          # cloth normal (up and out)
sw = AW_W / AW_N
for k in range(AW_N):
    x = CX - AW_W / 2 + sw * (k + 0.5)
    m = "fabricY" if k % 2 == 0 else "fabricC"
    add("Awning_Stripe%d" % k, (sw + 0.01, 0.15, aw_len), (x, YF + AW_D / 2, AW_TOP - AW_DROP / 2), (1.0, 0.0, 0.0), aw_n, m)
    add("Awning_Valance%d" % k, (sw + 0.01, 0.42, 0.12), (x, YF + AW_D + 0.02, AW_TOP - AW_DROP - 0.19), mat=m)
    disk("Awning_Scallop%d" % k, sw * 0.98, 0.14, (x, YF + AW_D + 0.02, AW_TOP - AW_DROP - 0.4), (0.0, 1.0, 0.0), m)
add("Awning_Rod", (AW_W + 0.4, 0.26, 0.26), (CX, YF + 0.16, AW_TOP + 0.02), (1.0, 0.0, 0.0), UP, "gold", "Cylinder")
for k, sx in enumerate((-1, 1)):
    add("Awning_BallFront%d" % k, (0.42, 0.42, 0.42), (CX + sx * (AW_W / 2 + 0.05), YF + AW_D + 0.05, AW_TOP - AW_DROP), mat="gold", shape="Ball")
    add("Awning_BallTop%d" % k, (0.36, 0.36, 0.36), (CX + sx * (AW_W / 2 + 0.25), YF + 0.16, AW_TOP + 0.02), mat="gold", shape="Ball")

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

# ---------------- where the kept Tripo pieces go (tools/skeleton_place.py; keep coordinates = v3 frame)
V3_YF = 5.5                       # front plane the v3 rules were made for
DY = YF - V3_YF
DZ = (Z1 + 0.9) - 13.7            # cornice top moved down (roof, dormer)
DOOR_LEAF = {"arch": [-0.85, 6.75, 2.42], "no_white": True}   # Tripo leaf centre x -0.85: drop old frame bits and stone flecks
DORMER_BOX = {"z": [11.0, 13.5], "y": [4.0, 9.0], "x": [-1.9, 1.9]}
LEAF_DY = (YF + LEAF_OFF) - 5.57  # v3 leaf front was at 5.57


def cluster(old_c, wall, d_target):
    """plants cluster rule: scale 1.15 about its own centre (base stays on the ground), then put its centre d_target
    outside `wall` at the place the cluster had, grown like the house (x 1.2 about the plan centre)"""
    nx, ny = CX + GROW * (old_c[0] - CX), CY + GROW * (old_c[1] - CY)
    w = walls[wall]
    k = d_target - w.dist(nx, ny)
    nx, ny = nx + w.n[0] * k, ny + w.n[1] * k
    return {"scale": [1.15, 1.15, 1.15], "about": [old_c[0], old_c[1], 0.0],
            "move": [round(nx - old_c[0], 3), round(ny - old_c[1], 3), 0.0]}


def into_pot(old_c, pot):
    x, y = pot_xy[pot]
    return {"scale": [1.15, 1.15, 1.15], "about": [old_c[0], old_c[1], 0.0], "move": [round(x - old_c[0], 3), round(y - old_c[1], 3), 0.0]}


place = {
    "note": "kept Tripo pieces of HaloDomeHouse_07 on the v4 skeleton (Blender frame of the parts GLB)",
    "kinds": {
        # Door: dropped too, the leaf is a Blender plank door now (the Tripo leaf had holes where its old hardware was cut)
        # DoorHw and Lanterns: dropped, knocker / hinges / lantern frames are Blender ornaments now (<out>_ornaments.json)
        # Awning: dropped, the awning is skeleton parts now (검수 v4c)
        # Dormer / WinPane / Glass: dropped, the dormer is a Blender arched window now (<out>_ornaments.json)
        # roof: its eave outline (keep GLB, 10/11) is x -8.1..7.4, y -7.15..6.0 around (-0.62, -0.575); as in the 2D the eaves
        # stop just inside the cornice line (0.3 past the walls), centred on the plan
        "Roof": [{"scale": [round((XS + 0.3) / 7.75, 4), round(((YF - YB) / 2 + 0.3) / 6.575, 4), 1.0], "about": [-0.62, -0.575, 13.7],
                  "move": [round(CX + 0.62, 3), round(CY + 0.575, 3), round(DZ, 3)]}],
        "Plants": [  # cluster centres measured on the keep GLB (10/11)
            dict(into_pot((4.84, 5.78), "PotR"), region={"near": [5.0, 5.65, 3.0], "y": [2.5, 20]}, rename="PlantsR"),
            dict(into_pot((-6.53, 2.72), "PotL"), region={"near": [-6.4, 3.4, 2.0]}, rename="PlantsL"),
            dict(cluster((-8.45, -0.77), "WallLeft", BED_D * 0.5), region={"x": [-20, -7.0], "y": [-3.6, 2.2]}, rename="PlantsSideL"),
            dict(cluster((-6.67, -6.25), "WallBackLeft", BED_D * 0.5), region={"x": [-20, -3.0], "y": [-20, -3.6]}, rename="PlantsBackL"),
            dict(cluster((8.34, -1.77), "WallRight", BED_D * 0.5), region={"x": [7.0, 20], "y": [-3.0, 2.5]}, rename="PlantsSideR"),
            dict(cluster((6.53, -5.04), "WallBackRight", BED_D * 0.5), region={"x": [3.0, 20], "y": [-20, -2.0]}, rename="PlantsBackR"),
        ],
    },
}

# Blender metal ornaments for tools/metal_ornaments.py (Blender frame): knocker on the latch side (+x, as in the 2D),
# two strap hinges on the -x edge, the two lantern frames; snapped onto the Tripo leaf by the tool
LEAF_HALF, LEAF_FRONT = 2.15, YF + LEAF_OFF
KN = (CX + 0.97, Z0 + 3.6)
orn = {
    "note": "house 07 metal ornaments (skeleton v4), positions from tools/skeleton_house07.py",
    "items": [
        {"type": "leaf", "name": "H07_Leaf", "c": [CX, DSP], "R": LEAF_HALF, "bottom": Z0 + 0.1, "front": LEAF_FRONT, "t": 0.32},
        {"type": "knocker", "name": "H07_Knocker", "pos": [KN[0], KN[1]], "face_y": LEAF_FRONT},
        {"type": "hinge", "name": "H07_HingeTop", "edge": [CX - LEAF_HALF + 0.1, Z0 + 5.4], "dir": 1, "face_y": LEAF_FRONT},
        {"type": "hinge", "name": "H07_HingeLow", "edge": [CX - LEAF_HALF + 0.1, Z0 + 1.8], "dir": 1, "face_y": LEAF_FRONT},
        # dormer: the Tripo one had gold spikes (roof ribs) and loose white bits -> exact arched window, breaking the
        # cornice line as in the 2D (front 0.1 past the cornice, arch top 0.4 above it)
        {"type": "arch_window", "name": "H07_Dormer", "pos": [CX, YF + 1.3, 10.75], "W": 1.5, "spring": 12.25, "pier": 0.45,
         "frame": 0.16, "depth": 1.6, "recess": 0.25},
        {"type": "lantern", "name": "H07_LanternL", "pos": [CX - LANT_U, LANT_C, LANT_Z], "w": LANT_W, "hgt": LANT_H,
         "post": LANT_POST, "wall_y": LANT_Y},
        {"type": "lantern", "name": "H07_LanternR", "pos": [CX + LANT_U, LANT_C, LANT_Z], "w": LANT_W, "hgt": LANT_H,
         "post": LANT_POST, "wall_y": LANT_Y},
    ],
    # roof octagon for tools/roof_fit.py: the eaves 0.7 out from the walls, just inside the cornice (1.2) as in the 2D
    "roof": {"center": [CX, CY], "poly": [[round(x, 4), round(y, 4)] for x, y in offset_poly(0.7)]},
    "shots": {  # name: [camera, look at, ortho width or null, lens]
        "door_front": [[CX, YF + 30, Z0 + 3.9], [CX, YF, Z0 + 3.9], 6.2, None],
        "door_side": [[CX + 30, LEAF_FRONT + 0.3, Z0 + 3.9], [CX, LEAF_FRONT + 0.3, Z0 + 3.9], 6.2, None],
        "knocker_close": [[KN[0] + 1.6, LEAF_FRONT + 2.6, KN[1] + 0.9], [KN[0], LEAF_FRONT, KN[1]], None, 50],
        "hinge_close": [[CX - 1.0, LEAF_FRONT + 2.8, Z0 + 6.2], [CX - LEAF_HALF + 0.8, LEAF_FRONT, Z0 + 5.4], None, 50],
        "lantern_front": [[CX + LANT_U, LANT_C + 30, LANT_Z + 0.5], [CX + LANT_U, LANT_C, LANT_Z + 0.5], 3.4, None],
        "lantern_side": [[CX + LANT_U + 30, LANT_C, LANT_Z + 0.5], [CX + LANT_U, LANT_C, LANT_Z + 0.5], 3.4, None],
        "lantern_close": [[CX + LANT_U + 2.2, LANT_C + 3.2, LANT_Z + 1.3], [CX + LANT_U, LANT_C, LANT_Z + 0.4], None, 45],
    },
}

# close-up cameras for tools/skeleton_preview.py (Blender frame)
wl = walls["WallFrontLeft"]
wc = wl.at(wl.L / 2, 7.4)
pl = pot_xy["PotL"]
cams = {
    "close_door": [[CX + 1.5, YF + 11.5, 6.0], [CX, YF, 5.4], 40],
    "close_window": [[wc[0] + wl.n[0] * 7.0, wc[1] + wl.n[1] * 7.0, 8.2], [wc[0], wc[1], 7.4], 45],
    "close_base": [[pl[0] - 2.5, pl[1] + 8.0, 3.2], [pl[0] + 1.5, pl[1] - 0.5, 1.6], 40],
}

# ---------------- Luau
MARBLE = 'p.Material = Enum.Material.Marble; p.MaterialVariant = "%s"; p.Color = Color3.fromRGB' % VARIANT
MAT = {
    "marble": MARBLE + '(255, 244, 222)',   # warm tint (WorldKit 10/11: the cream tile alone reads grey in the WorldKit light)
    "floor": MARBLE + '(238, 226, 205)',
    "gold": 'p.Material = Enum.Material.Metal; p.MaterialVariant = "HH_HaloGoldTrim"; p.Color = Color3.fromRGB(255, 168, 36)',
    "soil": 'p.Material = Enum.Material.Sand; p.Color = Color3.fromRGB(140, 100, 62)',
    "sky": 'p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(150, 200, 240)',
    "wood": 'p.Material = Enum.Material.Wood; p.Color = Color3.fromRGB(176, 118, 68); p.CanCollide = false',
    # lamp glass: warm see-through glass by day (검수 v4c: no white Neon box); the PointLight is off in the place and
    # WeatherFx switches it on at Dusk / Night (attribute LampLight on the part)
    "lamp": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(255, 228, 160); p.Transparency = 0.3; p:SetAttribute("LampLight", true); local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 214, 140); l.Brightness = 2.5; l.Range = 16; l.Shadows = false; l.Enabled = false; l.Parent = p',
    "fabricY": 'p.Material = Enum.Material.Fabric; p.MaterialVariant = "HH_Fabric"; p.Color = Color3.fromRGB(250, 205, 72)',
    "fabricC": 'p.Material = Enum.Material.Fabric; p.MaterialVariant = "HH_Fabric"; p.Color = Color3.fromRGB(255, 243, 212)',
    "glass": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(150, 205, 245); p.Transparency = 0.3; p.Reflectance = 0.15',
}


def r3(v):  # Blender vector -> Roblox
    return (v[0], v[2], -v[1])


L = ['-- skeleton v4 (generated by tools/skeleton_house07.py --marble %s, 이미지 생성 3 10/11, SPEC A23-120). WorldKit only.' % a.marble,
     'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end',
     'local root = workspace:FindFirstChild("SkeletonTest") or Instance.new("Folder"); root.Name = "SkeletonTest"; root.Parent = workspace',
     'for _, n in {"House07_Skeleton", "Tree_Pot_Skeleton"} do local o = root:FindFirstChild(n); if o then o:Destroy() end end',
     'local house = Instance.new("Model"); house.Name = "House07_Skeleton"; house.Parent = root',
     'house:SetAttribute("SkeletonVersion", 4); house:SetAttribute("Marble", "%s")' % VARIANT,
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
L.append('local d = Instance.new("Attachment"); d.Name = "DoorFront"; d.Parent = house:FindFirstChild("StepLow"); '
         'd.WorldPosition = Vector3.new(%.3f, %.3f, %.3f)' % (OX + CX, OY + Z0 / 2, OZ - (YF + 3.4)))
L.append('local n = 0; for _, q in root:GetDescendants() do if q:IsA("BasePart") then n += 1 end end')
L.append('return "SkeletonTest v4 built: " .. n .. " parts"')
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
open(a.out, "w", encoding="utf-8").write("\n".join(L) + "\n")
base = os.path.splitext(a.out)[0]
json.dump(parts, open(base + ".json", "w"), indent=0)
json.dump(place, open(base + "_place.json", "w"), indent=1)
json.dump(cams, open(base + "_cams.json", "w"), indent=1)
json.dump(orn, open(base + "_ornaments.json", "w"), indent=1)
print("[skeleton] v4 %s course %.3f: Z1 %.3f win %.3f imp %.2f frieze %.3f pedestal %.3f" % (VARIANT, COURSE, Z1, WIN_Z0, IMP0, FRZ0, PED_Z))
print("[skeleton] parts", len(parts), "(house %d, pot %d) ->" % (sum(p["grp"] == "house" for p in parts),
      sum(p["grp"] == "pot" for p in parts)), a.out)
print("[skeleton] pots", {k: (round(v[0], 2), round(v[1], 2)) for k, v in pot_xy.items()})
