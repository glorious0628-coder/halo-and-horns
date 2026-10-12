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
Z0 = 1.0                                   # platform top = floor
NX = 9.0                                   # nave half width
AX = 20.0                                  # aisle outer wall
YF = 25.0                                  # facade front face
YB = -24.0                                 # nave / aisles back end
NAVE_TOP, AISLE_TOP = 17.0, 10.0
RIDGE = 25.0
BAYS = [YF - 5 - 7 * k for k in range(7)]   # bay centres along the aisles: 20 13 6 -1 -8 -15 -22

# platform + front plaza + steps
box("Platform", -31, 31, -32, 38, 0.0, Z0, "floor")
for e_, (x0, x1, y0, y1) in enumerate(((-31.2, 31.2, 37.8, 38.2), (-31.2, 31.2, -32.2, -31.8), (-31.2, -30.8, -32, 38), (30.8, 31.2, -32, 38))):
    box("PlatformEdge%d" % e_, x0, x1, y0, y1, 0.0, Z0 + 0.1, "gold")
for s_ in range(3):
    box("Step%d" % s_, -7 + s_ * 0.0, 7, YF + 4.5 - s_ * 1.4, YF + 4.5 - s_ * 1.4 + 1.4, Z0, Z0 + 0.35 * (s_ + 1), "floor")
box("FloorInside", -NX + 0.6, NX - 0.6, YB + 0.6, YF - 0.6, Z0, Z0 + 0.1, "floor")

# nave: side walls above the aisle roofs with clerestory lancets, gable roof
for sg in (-1, 1):
    box("NaveWall%d" % ((sg + 1) // 2), sg * NX - 0.5, sg * NX + 0.5, YB, YF, Z0, NAVE_TOP) if sg > 0 else \
        box("NaveWall%d" % ((sg + 1) // 2), sg * NX - 0.5, sg * NX + 0.5, YB, YF, Z0, NAVE_TOP)
    add("NaveCornice%d" % ((sg + 1) // 2), (YF - YB + 0.6, 0.5, 1.1), (sg * (NX + 0.3), (YF + YB) / 2, NAVE_TOP - 0.25), (0.0, 1.0, 0.0), UP, "gold")
    for b_, yb in enumerate(BAYS[1:-1]):
        lancet("Clere%d_%d" % ((sg + 1) // 2, b_), (sg, 0.0), sg * (NX + 0.5), yb, AISLE_TOP + 3.6, 1.2, 2.6)
gable_roof_y("Nave", -NX - 0.5, NX + 0.5, YB, YF - 1.0, NAVE_TOP, RIDGE)
box("NaveBackWall", -NX, NX, YB - 1.0, YB, Z0, NAVE_TOP)

# aisles: outer walls with tall lancets, buttress pinnacles between the bays, lean-to roofs
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    box("AisleWall%d" % k_, sg * AX - 0.5, sg * AX + 0.5, YB, YF - 3.0, Z0, AISLE_TOP) if sg > 0 else \
        box("AisleWall%d" % k_, sg * AX - 0.5, sg * AX + 0.5, YB, YF - 3.0, Z0, AISLE_TOP)
    add("AisleBase%d" % k_, (YF - 3.0 - YB + 0.6, 0.6, 1.4), (sg * (AX + 0.2), (YF - 3.0 + YB) / 2, Z0 + 0.3), (0.0, 1.0, 0.0), UP, "gold")
    box("AisleFront%d" % k_, min(sg * NX, sg * AX), max(sg * NX, sg * AX), YF - 3.5, YF - 2.5, Z0, AISLE_TOP + 2.0)
    box("AisleBack%d" % k_, min(sg * NX, sg * AX), max(sg * NX, sg * AX), YB - 0.5, YB + 0.5, Z0, AISLE_TOP)
    for b_, yb in enumerate(BAYS[1:]):
        lancet("AisleWin%d_%d" % (k_, b_), (sg, 0.0), sg * (AX + 0.5), yb, Z0 + 2.0, 2.0, 5.4)
    for b_, yb in enumerate([y - 3.5 for y in BAYS]):    # buttress piers + pinnacles between the windows
        px = sg * (AX + 1.0)
        box("Buttress%d_%d" % (k_, b_), px - 0.7, px + 0.7, yb - 0.7, yb + 0.7, Z0, AISLE_TOP + 1.6)
        add("ButtressCap%d_%d" % (k_, b_), (1.7, 0.35, 1.7), (px, yb, AISLE_TOP + 1.75), mat="gold")
        spire("ButtressSp%d_%d" % (k_, b_), px, yb, AISLE_TOP + 1.95, 1.3, 3.2, 0.4)
    lean_roof("Aisle%d" % k_, sg, sg * AX, sg * NX, YB, YF - 3.0, AISLE_TOP, AISLE_TOP + 4.2)

# facade: front wall + pointed gable + rose-window opening + pointed-arch portal with two real gold door leaves
FW = 12.0                                    # facade half width (between the towers)
FT = 27.0                                    # facade wall top (gable foot)
GH = 10.0                                    # gable height
DW, DH = 10.0, 12.0                          # portal (plan door size 10 x 12)
box("FacadeL", -FW, -DW / 2, YF - 1.5, YF, Z0, FT)
box("FacadeR", DW / 2, FW, YF - 1.5, YF, Z0, FT)
box("FacadeTop", -DW / 2, DW / 2, YF - 1.5, YF, Z0 + DH, FT)          # solid above the lintel (the pointed arch is gold trim on it)
n_ = 16
for k in range(n_):                           # the pointed gable: horizontal strips (marble), gold coping
    wk = 2 * FW * (1 - (k + 0.5) / n_)
    box("FacadeGable%d" % k, -wk / 2, wk / 2, YF - 1.5, YF, FT + GH * k / n_, FT + GH * (k + 1) / n_ + 0.02)
for sg in (-1, 1):
    ln_ = math.hypot(FW, GH)
    X_ = norm((-sg * FW, 0.0, GH)) if sg > 0 else norm((FW, 0.0, GH))
    add("FacadeCoping%d" % ((sg + 1) // 2), (ln_ + 0.4, 0.5, 2.0), (sg * FW / 2, YF - 0.75, FT + GH / 2 + 0.3), X_,
        norm((sg * GH, 0.0, FW)), "gold")
add("FacadeGableFinial", (0.3, 1.2, 0.3), (0, YF - 0.75, FT + GH + 0.6), mat="gold")
ball("FacadeGableBall", 0.9, (0, YF - 0.75, FT + GH + 1.5))
# the portal: tympanum under a pointed arch (two tilted gold bars), the opening DW x DH, a deep reveal, two gold leaves
for sg in (-1, 1):
    ln_ = math.hypot(DW / 2, DW / 2)
    add("PortalArch%d" % ((sg + 1) // 2), (ln_ + 0.6, 0.7, 0.9), (sg * DW / 4, YF + 0.15, Z0 + DH + DW / 4),
        norm((-sg * 1.0, 0.0, 1.0)), (0.0, 1.0, 0.0), "gold")
    parts[-1]["X"] = [round(c, 5) for c in norm((-sg, 0.0, 1.0))]
    parts[-1]["Y"] = [0.0, 1.0, 0.0]
    parts[-1]["size"] = [round(ln_ + 0.6, 4), 0.9, 0.7]
    box("PortalJamb%d" % ((sg + 1) // 2), sg * DW / 2 - 0.45, sg * DW / 2 + 0.45, YF - 0.2, YF + 0.5, Z0, Z0 + DH, "gold")
box("PortalLintel", -DW / 2, DW / 2, YF - 0.3, YF + 0.3, Z0 + DH - 0.3, Z0 + DH + 0.3, "gold")
box("PortalReveal_L", -DW / 2, -DW / 2 + 0.4, YF - 4.0, YF - 1.5, Z0, Z0 + DH)
box("PortalReveal_R", DW / 2 - 0.4, DW / 2, YF - 4.0, YF - 1.5, Z0, Z0 + DH)
box("PortalReveal_T", -DW / 2, DW / 2, YF - 4.0, YF - 1.5, Z0 + DH - 0.4, Z0 + DH)
for sg in (-1, 1):                            # A23-120 real doors: two leaves, hinge on the outer jamb (names for a door script)
    box("Door_Leaf%s" % ("L" if sg < 0 else "R"), min(sg * 0.05, sg * (DW / 2 - 0.45)), max(sg * 0.05, sg * (DW / 2 - 0.45)),
        YF - 3.4, YF - 3.0, Z0 + 0.05, Z0 + DH - 0.45, "gold")
# rose window opening: a round glass + gold rings (the 8-petal tracery = a Tripo / Blender part in this slot)
RZ, RD = Z0 + DH + DW / 2 + 5.0, 7.0
disk("RoseRingOuter", RD + 1.0, 0.5, (0, YF + 0.1, RZ), (0.0, 1.0, 0.0))
disk("RoseGlass", RD, 0.3, (0, YF + 0.25, RZ), (0.0, 1.0, 0.0), "wglass")
disk("RoseRingInner", 2.0, 0.5, (0, YF + 0.35, RZ), (0.0, 1.0, 0.0))
orn.append({"type": "rose_window", "name": NAME + "_Rose", "pos": [0, YF + 0.4, RZ], "D": RD, "petals": 8,
            "src": "art/out/s2/halo/castle6/parts_high/CastlePartHigh_Rose_*.png"})
orn.append({"type": "wing", "name": NAME + "_WingL", "pos": [FW + 3.0, YF + 1.0, FT - 2], "h": 26,
            "src": "art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingL_*.png"})
orn.append({"type": "wing", "name": NAME + "_WingR", "pos": [-FW - 3.0, YF + 1.0, FT - 2], "h": 26,
            "src": "art/out/s2/halo/castle6/parts_high/CastlePartHigh_WingR_*.png"})
for k in range(3):                            # facade lancets beside the portal
    for sg in (-1, 1):
        lancet("FacadeWin%d_%d" % ((sg + 1) // 2, k), (0.0, 1.0), sg * (DW / 2 + 1.9), YF, Z0 + 2.0 + 0.0 * k, 1.6, 6.0) if k == 0 else None
add("FacadeBand", (2 * FW + 0.4, 0.5, 0.6), (0, YF + 0.2, Z0 + DH + DW / 2 + 0.6), mat="gold")

# facade towers, front turrets, crossing tower, back block + back towers
TWF = 6.5
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    tower("FrontTower%d" % k_, sg * (FW + TWF / 2), YF - TWF / 2, TWF, Z0, 31.0, 16.0, bands=(10.0, 20.0),
          win_faces=((0.0, 1.0), (sg, 0.0)), win=(1.2, 4.0))
    tower("FrontTurret%d" % k_, sg * (AX + 0.7), YF - 3.0, 3.6, Z0, AISLE_TOP + 5.0, 6.0, bands=(AISLE_TOP,), turrets=False)
CY, CW = YF - 7.5, 11.0                        # the tall spire tower stands right behind the facade (2D left / right)
tower("CrossTower", 0.0, CY, CW, NAVE_TOP - 1.0, 33.0, 22.0, spire_w=0.55, bands=(RIDGE - 0.5,),
      win_faces=((0.0, 1.0), (1.0, 0.0), (-1.0, 0.0), (0.0, -1.0)), win=(1.4, 4.4))
orn.append({"type": "halo_ring", "name": NAME + "_HaloRing", "pos": [0.0, CY, 33.0 + 22.0 + 2.0], "R": 7.5,
            "note": "exact circle ring (Blender), 디자인 검수 10/12"})
BX0, BX1, BY0, BY1 = -22.0, 22.0, -31.0, YB
box("BackBlock", BX0, BX1, BY0, BY1, Z0, 13.0)
add("BackBlockCornice", (BX1 - BX0 + 0.6, 0.5, BY1 - BY0 + 0.6), (0, (BY0 + BY1) / 2, 12.9), mat="gold")
gable_roof_x("Back", BX0, BX1, BY0, BY1, 13.0, 18.0)
for b_, xb in enumerate((-15.0, -8.0, 8.0, 15.0)):
    lancet("BackWin%d" % b_, (0.0, -1.0), xb, BY0, Z0 + 2.2, 2.0, 6.0)
lancet("BackGreatWin", (0.0, -1.0), 0.0, BY0, Z0 + 2.0, 4.0, 9.0)        # the tall pointed window of the 2D back
for sg in (-1, 1):
    k_ = (sg + 1) // 2
    tower("BackTower%d" % k_, sg * (BX1 - 2.5), BY0 + 2.5, 6.0, Z0, 24.0, 10.0, bands=(13.0,),
          win_faces=((0.0, -1.0), (sg, 0.0)), win=(1.0, 3.4))
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
      % (NAME, len(parts), len(orn), -AX - 1.7, AX + 1.7, BY0, YF + 5, 33.0 + 0.6 + 22.0, OUT))
