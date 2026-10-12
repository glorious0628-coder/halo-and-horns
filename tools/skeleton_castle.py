"""Studio part skeleton of the Halo light castle C2 (이미지 생성 3, 10/12; SPEC A23-120 skeleton = simple masses, real doors;
2D = art/out/s2/halo/castle6/HaloCastle_C2_{final,front_HQ,left,right_HQ,back,top}_src.png, user-approved "나도 C2!").

  py tools/skeleton_castle.py [--origin 3000,0,260] [--out build/skel_rows/HaloCastle_C2.luau]

Same outputs as tools/skeleton_house.py (<out> Luau for WorldKit: Workspace.SkeletonTest.HaloCastle_C2_Skeleton, <out>.json
parts for tools/skeleton_preview.py, <out>_ornaments.json slots for the Tripo decoration parts). Frame: x across the facade,
y = front (+y), z up, studs; plan centre (0, 0).

What the skeleton is (the 2D read as masses): a marble platform with a front plaza; a long nave (blue gable roof, clerestory
lancets) between two lower side aisles (lean-to roofs, tall lancet windows, buttress pinnacles with small blue spires); the
front facade (pointed gable, round rose-window opening, a pointed-arch portal with two real gold door leaves) between two
facade towers with tall square spires; a crossing tower with the tallest spire; a back block with two corner towers; four
small corner turrets. Decoration slots (not built here, Tripo parts -> Blender 손보기): the wings either side of the facade,
the rose window tracery, the halo ring over the crossing spire, the gold star finials, trees / hedges.
Fit to the plan site (w 100 x d 70): 46 wide x 62 deep body on a 62 x 70 platform (the 2D is deeper than wide).
"""
import argparse
import json
import math
import os

ap = argparse.ArgumentParser()
ap.add_argument("--origin", default="3000,0,260")
ap.add_argument("--out", default="build/skel_rows/HaloCastle_C2.luau")
ap.add_argument("--roof", default="40,110,215")
a = ap.parse_args()
OX, OY, OZ = [float(v) for v in a.origin.split(",")]
NAME = "HaloCastle_C2"
ROOF = tuple(int(v) for v in a.roof.split(","))
UP = (0.0, 0.0, 1.0)
parts, orn = [], []


def norm(v):
    L_ = math.sqrt(sum(c * c for c in v))
    return tuple(c / L_ for c in v)


def add(name, size, pos, X=(1.0, 0.0, 0.0), Y=UP, mat="marble", shape="Block"):
    parts.append(dict(name=name, shape=shape, size=[round(s, 4) for s in size], pos=[round(c, 4) for c in pos],
                      X=[round(c, 5) for c in X], Y=[round(c, 5) for c in Y], mat=mat, grp="house"))


def box(name, x0, x1, y0, y1, z0, z1, mat="marble"):
    add(name, (x1 - x0, z1 - z0, y1 - y0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat=mat)


def disk(name, d, th, pos, n, mat="gold"):
    add(name, (th, d, d), pos, n, UP if abs(n[2]) < 0.9 else (1.0, 0.0, 0.0), mat, "Cylinder")


def ball(name, d, pos, mat="gold"):
    add(name, (d, d, d), pos, mat=mat, shape="Ball")


def spire(name, cx, cy, z0, w, h, finial=0.7):
    """a square blue spire: stacked shrinking slabs + a gold eave band + a gold finial ball"""
    n = max(6, int(h / 0.6))
    for k in range(n):
        wk = w * (1 - (k + 0.5) / n) + 0.06
        add("%s_Sp%d" % (name, k), (wk, h / n + 0.02, wk), (cx, cy, z0 + h * (k + 0.5) / n), mat="slate")
    add("%s_Eave" % name, (w + 0.3, 0.35, w + 0.3), (cx, cy, z0 + 0.15), mat="gold")
    add("%s_FinialPost" % name, (0.22, 0.9, 0.22), (cx, cy, z0 + h + 0.4), mat="gold")
    ball("%s_Finial" % name, finial, (cx, cy, z0 + h + 0.9))


def lancet(name, wall_n, cx, cy, z0, w, h, glass="wglass"):
    """a tall pointed (lancet) window on a wall facing wall_n (unit xy): glass + a pointed top (a 45-degree turned square
    over the glass) + a gold frame behind it, proud of the wall face by 0.05"""
    nx, ny = wall_n
    t = (-ny, nx, 0.0)
    d_ = 0.12
    add(name + "_Frame", (w + 0.5, h + 0.4, 0.1), (cx + nx * 0.02, cy + ny * 0.02, z0 + h / 2), t, UP, "gold")
    add(name + "_Glass", (w, h, 0.1), (cx + nx * d_, cy + ny * d_, z0 + h / 2), t, UP, glass)
    s_ = w / math.sqrt(2)
    zt = z0 + h
    add(name + "_TipFrame", (s_ + 0.35, s_ + 0.35, 0.1), (cx + nx * 0.02, cy + ny * 0.02, zt), norm((t[0] + 0, t[1] + 0, 1.0)), norm((-t[0], -t[1], 1.0)), "gold")
    # the turned square lies in the wall plane: its axes are (t + up) / sqrt2 and (-t + up) / sqrt2; Y must be the wall normal
    parts[-1]["X"] = [round(c, 5) for c in norm((t[0], t[1], 1.0))]
    parts[-1]["Y"] = [round(c, 5) for c in norm((-t[0], -t[1], 1.0))]
    parts[-1]["size"] = [round(s_ + 0.35, 4), round(s_ + 0.35, 4), 0.1]
    add(name + "_Tip", (s_, s_, 0.1), (cx + nx * d_, cy + ny * d_, zt), norm((t[0], t[1], 1.0)), norm((-t[0], -t[1], 1.0)), glass)


def gable_roof_y(name, x0, x1, y0, y1, z_eave, z_ridge, over=0.6):
    """a gable roof whose ridge runs along y (nave): two tilted blue slabs + gold ridge + gold eaves"""
    hw = (x1 - x0) / 2 + over
    xc = (x0 + x1) / 2
    rise = z_ridge - z_eave
    hyp = math.hypot(hw, rise)
    for sg in (-1, 1):
        nrm = norm((sg * rise, 0.0, hw))
        c = (xc + sg * hw / 2 - nrm[0] * 0.2, (y0 + y1) / 2, z_eave + rise / 2 - nrm[2] * 0.2)
        add("%s_Roof%d" % (name, (sg + 1) // 2), (y1 - y0 + 2 * over, 0.4, hyp), c, (0.0, 1.0, 0.0), nrm, "slate")
        add("%s_Eave%d" % (name, (sg + 1) // 2), (y1 - y0 + 2 * over, 0.35, 0.4), (xc + sg * hw, (y0 + y1) / 2, z_eave), (0.0, 1.0, 0.0), UP, "gold")
    add("%s_Ridge" % name, (y1 - y0 + 2 * over, 0.4, 0.45), (xc, (y0 + y1) / 2, z_ridge + 0.1), (0.0, 1.0, 0.0), UP, "gold")


def gable_roof_x(name, x0, x1, y0, y1, z_eave, z_ridge, over=0.6):
    """the same with the ridge along x (back block)"""
    hd = (y1 - y0) / 2 + over
    yc = (y0 + y1) / 2
    rise = z_ridge - z_eave
    hyp = math.hypot(hd, rise)
    for sg in (-1, 1):
        nrm = norm((0.0, sg * rise, hd))
        c = ((x0 + x1) / 2, yc + sg * hd / 2 - nrm[1] * 0.2, z_eave + rise / 2 - nrm[2] * 0.2)
        add("%s_Roof%d" % (name, (sg + 1) // 2), (x1 - x0 + 2 * over, 0.4, hyp), c, (1.0, 0.0, 0.0), nrm, "slate")
        add("%s_Eave%d" % (name, (sg + 1) // 2), (x1 - x0 + 2 * over, 0.35, 0.4), ((x0 + x1) / 2, yc + sg * hd, z_eave), (1.0, 0.0, 0.0), UP, "gold")
    add("%s_Ridge" % name, (x1 - x0 + 2 * over, 0.4, 0.45), ((x0 + x1) / 2, yc, z_ridge + 0.1), (1.0, 0.0, 0.0), UP, "gold")


def lean_roof(name, sg, x_out, x_in, y0, y1, z_low, z_high, over=0.6):
    """an aisle's lean-to roof on side sg (+1 = +x): from the outer wall (low) up to the nave wall (high)"""
    run = abs(x_out - x_in) + over
    rise = z_high - z_low
    hyp = math.hypot(run, rise)
    nrm = norm((sg * rise, 0.0, run))
    xc = (x_out + sg * over + x_in) / 2
    add(name + "_Roof", (y1 - y0 + 2 * over, 0.4, hyp), (xc - nrm[0] * 0.2, (y0 + y1) / 2, (z_low + z_high) / 2 - nrm[2] * 0.2),
        (0.0, 1.0, 0.0), nrm, "slate")
    add(name + "_Eave", (y1 - y0 + 2 * over, 0.35, 0.4), (x_out + sg * over, (y0 + y1) / 2, z_low), (0.0, 1.0, 0.0), UP, "gold")


def tower(name, cx, cy, w, z0, z1, spire_h, bands=(), win_faces=(), win=(1.0, 3.4), turrets=True, spire_w=0.66):
    box(name, cx - w / 2, cx + w / 2, cy - w / 2, cy + w / 2, z0, z1)
    for k, zb in enumerate(list(bands) + [z1 - 0.4]):
        add("%s_Band%d" % (name, k), (w + 0.4, 0.45, w + 0.4), (cx, cy, zb), mat="gold")
    add(name + "_Cornice", (w + 0.8, 0.6, w + 0.8), (cx, cy, z1 + 0.3))
    for fi, (nx, ny) in enumerate(win_faces):
        lancet("%s_Win%d" % (name, fi), (nx, ny), cx + nx * w / 2, cy + ny * w / 2, z1 - win[1] - 2.2, win[0], win[1])
    spire(name + "_Spire", cx, cy, z1 + 0.6, w * spire_w, spire_h)
    if turrets and w >= 5:                                  # small corner pinnacles round the spire foot
        for ti, (sx, sy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
            px, py = cx + sx * (w / 2 - 0.4), cy + sy * (w / 2 - 0.4)
            add("%s_Pin%d" % (name, ti), (0.8, 1.6, 0.8), (px, py, z1 + 1.4))
            spire("%s_Pin%d_Sp" % (name, ti), px, py, z1 + 2.2, 0.9, 2.2, 0.35)


# ---------------------------------------------------------------- dimensions (studs)
# v2 (최종 검수 10/12): measured on the 2D front (art/out/s2/halo/castle6/HaloCastle_C2_front_HQ_src.png, platform 770 px =
# 62 studs, 12.4 px a stud): a staircase of towers from the middle out - centre spire tip 53, then 45, 40, 34, 25.5, 17,
# 8.5 at x 0, 8, 12.5, 18.5, 23.4, 26.6, 28.6; portal ~10 wide, pointed apex 15.7; rose window centre 20.3, 6.9 across.
Z0 = 1.6                                   # platform top = floor (a wide white two-step base)
NX = 9.0                                   # nave half width
AX = 20.0                                  # aisle outer wall
YF = 25.0                                  # facade front face
YB = -24.0                                 # nave / aisles back end
NAVE_TOP, AISLE_TOP = 17.0, 10.5
RIDGE = 25.0
BAYS = [YF - 5 - 7 * k for k in range(7)]   # bay centres along the aisles: 20 13 6 -1 -8 -15 -22

# platform (two steps) + front plaza + wide front stairs
box("PlatformLow", -32.5, 32.5, -33.5, 39.5, 0.0, 0.8, "floor")
box("Platform", -31.0, 31.0, -32.0, 38.0, 0.8, Z0, "floor")
for e_, (x0, x1, y0, y1) in enumerate(((-31.2, 31.2, 37.8, 38.2), (-31.2, 31.2, -32.2, -31.8), (-31.2, -30.8, -32, 38), (30.8, 31.2, -32, 38))):
    box("PlatformEdge%d" % e_, x0, x1, y0, y1, 0.8, Z0 + 0.1, "gold")
for s_ in range(4):                          # the front stairs down from the portal to the plaza
    box("Step%d" % s_, -9.0, 9.0, YF + 6.5 - s_ * 1.2, YF + 6.5 - s_ * 1.2 + 1.2, Z0, Z0 + 0.3 * (s_ + 1), "floor")
box("FloorInside", -NX + 0.6, NX - 0.6, YB + 0.6, YF - 0.6, Z0, Z0 + 0.1, "floor")

# nave: side walls above the aisle roofs with clerestory lancets, gable roof, pinnacles on the cornice, small roof dormers
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    box("NaveWall%d" % k_, sg * NX - 0.5, sg * NX + 0.5, YB, YF, Z0, NAVE_TOP)
    add("NaveCornice%d" % k_, (YF - YB + 0.6, 0.5, 1.1), (sg * (NX + 0.3), (YF + YB) / 2, NAVE_TOP - 0.25), (0.0, 1.0, 0.0), UP, "gold")
    for b_, yb in enumerate(BAYS[1:-1]):
        lancet("Clere%d_%d" % (k_, b_), (sg, 0.0), sg * (NX + 0.5), yb, AISLE_TOP + 2.6, 1.2, 3.4)
    for b_, yb in enumerate([y - 3.5 for y in BAYS[1:]]):   # cornice pinnacles between the clerestory windows
        px = sg * (NX + 0.4)
        add("NavePin%d_%d" % (k_, b_), (0.9, 1.4, 0.9), (px, yb, NAVE_TOP + 0.7))
        spire("NavePinSp%d_%d" % (k_, b_), px, yb, NAVE_TOP + 1.4, 1.0, 2.8, 0.35)
gable_roof_y("Nave", -NX - 0.5, NX + 0.5, YB, YF - 1.0, NAVE_TOP, RIDGE)
for d_, yb in enumerate((BAYS[2], BAYS[4], BAYS[6] + 2.0)):  # small pointed dormers on both nave slopes
    for sg in (-1, 1):
        dx_ = sg * 4.6
        zr_ = NAVE_TOP + (RIDGE - NAVE_TOP) * (1 - abs(dx_) / (NX + 1.1))
        box("NaveDormer%d_%d" % (d_, (sg + 1) // 2), dx_ - 0.8, dx_ + 0.8, yb - 0.8, yb + 0.8, zr_ - 1.2, zr_ + 1.3)
        lancet("NaveDormerWin%d_%d" % (d_, (sg + 1) // 2), (sg, 0.0), dx_ + sg * 0.8, yb, zr_ - 0.6, 0.7, 1.2)
        spire("NaveDormerSp%d_%d" % (d_, (sg + 1) // 2), dx_, yb, zr_ + 1.3, 1.5, 2.0, 0.3)
box("NaveBackWall", -NX, NX, YB - 1.0, YB, Z0, NAVE_TOP)

# aisles: outer walls with tall pointed windows, buttress piers + pinnacles between the bays, lean-to roofs
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    box("AisleWall%d" % k_, sg * AX - 0.5, sg * AX + 0.5, YB, YF - 12.0, Z0, AISLE_TOP)
    add("AisleBase%d" % k_, (YF - 12.0 - YB + 0.6, 0.6, 1.4), (sg * (AX + 0.2), (YF - 12.0 + YB) / 2, Z0 + 0.3), (0.0, 1.0, 0.0), UP, "gold")
    box("AisleBack%d" % k_, min(sg * NX, sg * AX), max(sg * NX, sg * AX), YB - 0.5, YB + 0.5, Z0, AISLE_TOP)
    for b_, yb in enumerate(BAYS[2:]):
        lancet("AisleWin%d_%d" % (k_, b_), (sg, 0.0), sg * (AX + 0.5), yb, Z0 + 1.6, 2.0, 6.4)
    for b_, yb in enumerate([y - 3.5 for y in BAYS[1:]]):
        px = sg * (AX + 1.0)
        box("Buttress%d_%d" % (k_, b_), px - 0.7, px + 0.7, yb - 0.7, yb + 0.7, Z0, AISLE_TOP + 1.6)
        add("ButtressCap%d_%d" % (k_, b_), (1.7, 0.35, 1.7), (px, yb, AISLE_TOP + 1.75), mat="gold")
        spire("ButtressSp%d_%d" % (k_, b_), px, yb, AISLE_TOP + 1.95, 1.3, 3.6, 0.4)
    lean_roof("Aisle%d" % k_, sg, sg * AX, sg * NX, YB, YF - 1.0, AISLE_TOP, AISLE_TOP + 4.2)

# front chapels (the low wide front either side, under the outer towers): x 20..30, the front 12 studs
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    x0_, x1_ = sorted((sg * AX - sg * 0.5, sg * 30.0))
    box("Chapel%d" % k_, x0_, x1_, YF - 12.0, YF - 0.5, Z0, 7.5)
    add("ChapelCornice%d" % k_, (x1_ - x0_ + 0.4, 0.45, 11.9), ((x0_ + x1_) / 2, YF - 6.25, 7.3), mat="gold")
    lean_roof("Chapel%d" % k_, sg, sg * 30.0, sg * AX, YF - 12.0, YF - 0.5, 7.5, 9.5)
    for w_, xw in enumerate((sg * 21.5, sg * 25.0)):
        lancet("ChapelWin%d_%d" % (k_, w_), (0.0, 1.0), xw, YF - 0.5, Z0 + 1.4, 1.6, 4.0)
    lancet("ChapelSideWin%d" % k_, (sg, 0.0), sg * 30.0, YF - 6.0, Z0 + 1.4, 1.6, 4.0)

# facade screen between the centre block and the chapels (the aisle fronts): wall + pointed windows
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    x0_, x1_ = sorted((sg * 5.8, sg * AX))
    box("Screen%d" % k_, x0_, x1_, YF - 1.5, YF - 0.5, Z0, AISLE_TOP + 3.5)
    add("ScreenBand%d" % k_, (x1_ - x0_, 0.4, 0.5), ((x0_ + x1_) / 2, YF - 0.3, AISLE_TOP + 3.5), mat="gold")
    for w_, xw in enumerate((sg * 10.2, sg * 15.5)):
        lancet("ScreenWin%d_%d" % (k_, w_), (0.0, 1.0), xw, YF - 0.5, Z0 + 1.6, 1.9, 6.6)

# facade centre block: front wall, a steep pointed gable, the rose window, the tall pointed portal with real doors
FW = 5.8                                     # centre block half width (2D 330..470 px)
FT = 22.0                                    # wall top (gable foot)
GH = 7.5                                     # gable height (apex 29.5)
DW, DH = 9.6, 11.3                           # portal opening + door leaf height (2D)
AP = 4.4                                     # pointed arch rise above the leaves (apex 15.7 + base)
box("FacadeL", -FW, -DW / 2, YF - 1.5, YF + 0.5, Z0, FT)
box("FacadeR", DW / 2, FW, YF - 1.5, YF + 0.5, Z0, FT)
box("FacadeTop", -DW / 2, DW / 2, YF - 1.5, YF + 0.5, Z0 + DH + AP, FT)
n_ = 16
for k in range(n_):
    wk = 2 * FW * (1 - (k + 0.5) / n_)
    box("FacadeGable%d" % k, -wk / 2, wk / 2, YF - 1.5, YF + 0.5, FT + GH * k / n_, FT + GH * (k + 1) / n_ + 0.02)
for sg in (-1, 1):
    ln_ = math.hypot(FW, GH)
    add("FacadeCoping%d" % ((sg + 1) // 2), (ln_ + 0.4, 0.5, 2.4), (sg * FW / 2, YF - 0.5, FT + GH / 2 + 0.3),
        norm((-sg * FW, 0.0, GH)) if sg > 0 else norm((FW, 0.0, GH)), norm((sg * GH, 0.0, FW)), "gold")
spire("FacadeGableSp", 0.0, YF - 0.5, FT + GH, 1.2, 3.0, 0.4)
for sg in (-1, 1):                            # pinnacles on the centre block corners
    add("FacadePin%d" % ((sg + 1) // 2), (1.2, FT + 1.5 - Z0, 1.2), (sg * (FW + 0.3), YF, (FT + 1.5 + Z0) / 2))
    spire("FacadePinSp%d" % ((sg + 1) // 2), sg * (FW + 0.3), YF, FT + 1.5, 1.4, 4.0, 0.4)
# the portal: the opening DW x (DH + AP) with a pointed head (stepped fill), two gold arch bands, a glowing inner window
nA = 10
for k in range(nA):                           # the pointed head: fill strips either side, narrowing upwards
    f0, f1 = k / nA, (k + 1) / nA
    hw = DW / 2 * math.sqrt(max(0.0, 1 - ((f0 + f1) / 2) ** 2))    # a rounded-point (gothic) curve
    for sg in (-1, 1):
        x0_, x1_ = sorted((sg * hw, sg * DW / 2))
        if x1_ - x0_ > 0.02:
            box("PortalHead%d_%d" % (k, (sg + 1) // 2), x0_, x1_, YF - 1.5, YF + 0.5, Z0 + DH + AP * f0, Z0 + DH + AP * f1 + 0.02)
for band, (off, wd) in enumerate(((0.0, 0.55), (0.9, 0.45))):
    for sg in (-1, 1):
        pts = []
        for k in range(nA + 1):
            f = k / nA
            pts.append((sg * (DW / 2 + off) * math.sqrt(max(0.0, 1 - f * f)), Z0 + DH + (AP + off) * f))
        for k in range(nA):
            (xa, za), (xb, zb) = pts[k], pts[k + 1]
            ln_ = math.hypot(xb - xa, zb - za)
            add("PortalArch%d_%d_%d" % (band, (sg + 1) // 2, k), (ln_ + 0.06, 0.5, wd), ((xa + xb) / 2, YF + 0.65, (za + zb) / 2),
                norm((xb - xa, 0.0, zb - za)), (0.0, 1.0, 0.0), "gold")
    for sg in (-1, 1):
        box("PortalJamb%d_%d" % (band, (sg + 1) // 2), sg * (DW / 2 + off) - wd / 2, sg * (DW / 2 + off) + wd / 2, YF + 0.4, YF + 0.9, Z0, Z0 + DH, "gold")
lancet("PortalInnerWin", (0.0, 1.0), 0.0, YF - 3.6, Z0 + 3.0, 3.0, 9.0)          # the glowing window behind the doors (2D)
box("PortalReveal_L", -DW / 2, -DW / 2 + 0.4, YF - 4.0, YF - 1.5, Z0, Z0 + DH + AP)
box("PortalReveal_R", DW / 2 - 0.4, DW / 2, YF - 4.0, YF - 1.5, Z0, Z0 + DH + AP)
box("PortalBack", -DW / 2, DW / 2, YF - 4.2, YF - 3.8, Z0, Z0 + DH + AP)
for sg in (-1, 1):                            # A23-120 real doors: two leaves standing open a little (2D), hinge on the jambs
    leaf_w = DW / 2 - 0.2
    hx = sg * (DW / 2 - 0.15)
    ang = math.radians(28)
    cx_ = hx - sg * leaf_w / 2 * math.cos(ang)
    cy_ = YF - 0.2 + leaf_w / 2 * math.sin(ang)
    add("Door_Leaf%s" % ("L" if sg < 0 else "R"), (leaf_w, DH - 0.2, 0.35), (cx_, cy_, Z0 + (DH - 0.2) / 2),
        norm((-sg * math.cos(ang), math.sin(ang), 0.0)), UP, "gold")
# rose window: round glass + gold rings (the 8-petal tracery = a Tripo / Blender part in this slot)
RZ, RD = 22.4, 6.9                              # above the portal arch apex (18.2)
disk("RoseRingOuter", RD + 1.0, 0.5, (0, YF + 0.6, RZ), (0.0, 1.0, 0.0))
disk("RoseGlass", RD, 0.3, (0, YF + 0.75, RZ), (0.0, 1.0, 0.0), "wglass")
disk("RoseRingInner", 2.0, 0.5, (0, YF + 0.85, RZ), (0.0, 1.0, 0.0))
orn.append({"type": "rose_window", "name": NAME + "_Rose", "pos": [0, YF + 0.9, RZ], "D": RD, "petals": 8,
            "src": "art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_*.png"})
for sg, nm in ((1, "WingL"), (-1, "WingR")):
    orn.append({"type": "wing", "name": NAME + "_" + nm, "pos": [sg * (FW + 4.0), YF + 1.5, 24.0], "h": 30,
                "src": "art/out/s2/halo/castle6/parts_high/CastlePartHigh_%s_*.png" % nm})

# the tower staircase across the front (2D): (x, body width, body top, spire h); centre tower behind the gable
STAIR = [(8.0, 3.4, 35.0, 10.0), (12.5, 3.2, 30.5, 9.0), (18.5, 3.8, 25.5, 8.0), (23.4, 3.4, 18.5, 6.5),
         (26.6, 3.0, 12.0, 4.6), (28.6, 2.4, 5.2, 3.0)]
for i_, (xt, wt, zt, sh) in enumerate(STAIR):
    for sg in (-1, 1):
        yt = YF - 1.0 - wt / 2 - (0.8 if i_ in (0, 1) else 0.0)
        tower("StairTower%d_%d" % (i_, (sg + 1) // 2), sg * xt, yt, wt, Z0, zt, sh, bands=tuple(z for z in (8.0, 15.0, 22.0, 29.0) if z < zt - 2),
              win_faces=((0.0, 1.0),) if zt > 10 else (), win=(0.8, 2.6 if zt > 14 else 1.6), turrets=False, spire_w=0.8)
CY, CW = YF - 5.4, 7.8                        # the centre tower (the tallest spire, the halo ring over it)
tower("CentreTower", 0.0, CY, CW, Z0, 40.0, 13.0, spire_w=0.62, bands=(29.0, 34.0),
      win_faces=((0.0, 1.0), (1.0, 0.0), (-1.0, 0.0), (0.0, -1.0)), win=(1.3, 4.2))
orn.append({"type": "halo_ring", "name": NAME + "_HaloRing", "pos": [0.0, CY, 46.5], "R": 7.3,
            "note": "exact circle ring (Blender), 디자인 검수 10/12; 2D ring 180 px = 14.5 studs across"})

# back block + back towers + the great back window
BX0, BX1, BY0, BY1 = -22.0, 22.0, -31.0, YB
box("BackBlock", BX0, BX1, BY0, BY1, Z0, 13.0)
add("BackBlockCornice", (BX1 - BX0 + 0.6, 0.5, BY1 - BY0 + 0.6), (0, (BY0 + BY1) / 2, 12.9), mat="gold")
gable_roof_x("Back", BX0, BX1, BY0, BY1, 13.0, 18.0)
for b_, xb in enumerate((-15.0, -8.0, 8.0, 15.0)):
    lancet("BackWin%d" % b_, (0.0, -1.0), xb, BY0, Z0 + 2.2, 2.0, 6.0)
lancet("BackGreatWin", (0.0, -1.0), 0.0, BY0, Z0 + 2.0, 4.0, 9.0)
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    tower("BackTower%d" % k_, sg * (BX1 - 2.5), BY0 + 2.5, 6.0, Z0, 24.0, 10.0, bands=(13.0,),
          win_faces=((0.0, -1.0), (sg, 0.0)), win=(1.0, 3.4))
    for b_, xb in enumerate((sg * 9.0, sg * 14.0)):          # back block pinnacles
        add("BackPin%d_%d" % (k_, b_), (0.9, 1.4, 0.9), (xb, BY0 + 0.2, 13.7))
        spire("BackPinSp%d_%d" % (k_, b_), xb, BY0 + 0.2, 14.4, 1.0, 2.8, 0.35)
orn.append({"type": "star_finials", "name": NAME + "_Stars", "note": "gold star tops on the spires (2D), Tripo parts"})

# ---------------------------------------------------------------- outputs (same Luau writer as tools/skeleton_house.py)
MARBLE = 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleBlock_Cream"; p.Color = Color3.fromRGB'
MAT = {
    "marble": MARBLE + "(255, 244, 222)",
    "floor": MARBLE + '(238, 226, 205); game:GetService("CollectionService"):AddTag(p, "WalkGround")',
    "gold": 'p.Material = Enum.Material.Metal; p.MaterialVariant = "HH_HaloGoldTrim"; p.Color = Color3.fromRGB(255, 168, 36)',
    "wglass": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(255, 222, 150); p.Transparency = 0.25; p.Reflectance = 0.1',
    "glass": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(150, 205, 245); p.Transparency = 0.3; p.Reflectance = 0.15',
    "slate": 'p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(%d, %d, %d)' % ROOF,
}


def r3(v):
    return (v[0], v[2], -v[1])


OUT = a.out
L = ['-- %s skeleton (generated by tools/skeleton_castle.py, 이미지 생성 3, SPEC A23-120). WorldKit only.' % NAME,
     'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end',
     'local root = workspace:FindFirstChild("SkeletonTest") or Instance.new("Folder"); root.Name = "SkeletonTest"; root.Parent = workspace',
     'local old = root:FindFirstChild("%s_Skeleton"); if old then old:Destroy() end' % NAME,
     'local house = Instance.new("Model"); house.Name = "%s_Skeleton"; house.Parent = root' % NAME,
     'local function mk(parent, name, shape, sx, sy, sz, x, y, z, ax, ay, az, bx, by, bz, mat)',
     '  local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth',
     '  p.Shape = Enum.PartType[shape]; p.Size = Vector3.new(sx, sy, sz)',
     '  p.CFrame = CFrame.fromMatrix(Vector3.new(x, y, z), Vector3.new(ax, ay, az), Vector3.new(bx, by, bz))']
for i, (k, v) in enumerate(MAT.items()):
    L.append('  %s mat == "%s" then %s' % ("if" if i == 0 else "elseif", k, v))
L += ['  end', '  if mat == "glass" or mat == "wglass" then p.CastShadow = false end', '  p.Parent = parent; return p', 'end']
for p in parts:
    x, y, z = p["pos"]
    X, Y = r3(p["X"]), r3(p["Y"])
    L.append('mk(house, "%s", "%s", %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, "%s")' % (
        p["name"], p["shape"], *p["size"], OX + x, OY + z, OZ - y, *X, *Y, p["mat"]))
L.append('local d = Instance.new("Attachment"); d.Name = "DoorFront"; d.Parent = house:FindFirstChild("FloorInside"); '
         'd.WorldPosition = Vector3.new(%.3f, %.3f, %.3f)' % (OX, OY + Z0 / 2, OZ - (YF + 5.0)))
L.append('do local CS = game:GetService("CollectionService"); for _, q in house:GetDescendants() do if q:IsA("BasePart") then '
         'for _, pt in {"^Step%d", "^FloorInside", "^Platform$"} do if string.match(q.Name, pt) then CS:AddTag(q, "WalkGround"); break end end end end end')
L.append('local n = 0; for _, q in house:GetDescendants() do if q:IsA("BasePart") then n += 1 end end')
L.append('return "%s skeleton built: " .. n .. " parts"' % NAME)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
base = os.path.splitext(OUT)[0]
json.dump(parts, open(base + ".json", "w"), indent=0)
json.dump({"note": "%s decoration slots (tools/skeleton_castle.py): Tripo parts -> Blender 손보기 (A23-147)" % NAME, "items": orn},
          open(base + "_ornaments.json", "w"), indent=1)
print("[castle] %s: %d parts, %d slots, body x %.0f..%.0f y %.0f..%.0f, crossing spire tip %.1f -> %s"
      % (NAME, len(parts), len(orn), -32.5, 32.5, BY0, YF + 6.5, 40.0 + 0.6 + 13.0, OUT))
