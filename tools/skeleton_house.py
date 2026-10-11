"""General Studio skeleton generator for Halo houses / shops (SPEC A23-120/121/125, ④ 건물 골격), 이미지 생성 3, 10/11.
House 07's tool (tools/skeleton_house07.py, the approved v4 board) made general: every house is a spec JSON.

  py tools/skeleton_house.py <spec.json> [--origin 3000,0,60] [--out build/skel_<name>.luau]

Writes <out> (Luau for WorldKit: Workspace.SkeletonTest.<name>_Skeleton), <out>.json (parts, tools/skeleton_preview.py),
<out>_ornaments.json (tools/metal_ornaments.py: leaf, knocker, hinges, lanterns, domes, arched dormers) and
<out>_cams.json (preview close-ups). Frame: Blender (x, y = front, z up, studs), plan centre (0, 0), door on the front.

Spec (all lengths in studs; see tools/house_specs/*.json):
  name, src2d                      the 2D the house follows
  plan     {"shape": "rect", "W", "D"} | {"shape": "oct", "HF", "XS", "DY", "D"} |
           {"shape": "round", "R", "seg" (32 = smooth), "flats": [polar deg, ...], "flat_w": 3.2 studs}
  Z0       plinth top = door sill (1.1)
  storeys  [{"h", "win": {"w": glass width, "type": "arch"|"rect", "h": max glass height 4.6, "gap": 1.1 under the storey
           line, "by_wall": {wall: w}}, "walls": {wall name: [u fractions]}}]   (bottom first); the gold frame, hood,
           keystone, sill scale with w (g = 0.1 w + 0.08), two bars when w > 2.4; a window that does not fit its wall
           edge (minus 0.3) is skipped with a warning
           wall names: rect = front, right, back, left (front holds the door); oct = front, front_r, right, back_r,
           back, back_l, left, front_l; round = s0..s(seg-1) (the one facing +y is "front") and w0.. = the flat facets
           at "flats" (polar angle, 0 = +x, 90 = front; give them in the order you want w0, w1, ...); "@k" = k edges on
  door     {"w", "h", "double": bool}
  pilasters  true / false (turned along the corner bisectors; big gold capitals, band on each storey line)
  towers   {"w", "h_extra", "dome": true (small gold ribbed dome cap, R = w / 2 + 0.2; else "finial": true = ball),
            "window": true (small arched window "win_w" 0.9 on the front face of the front towers)} square corner towers
           on a rect plan (house 02 / 04 style)
  pedestals  true: marble blocks with gold caps either side of the door (lanterns above them)
  awning   {"w", "colors": [[r,g,b], [r,g,b]], "n"} striped SmoothPlastic cloth + scalloped valance
  pots     [[x, y, d, h], ...] round pots with sand soil (plants: 4-view Tripo later, A23-122)
  steps    "half" (two half-round steps) | "three" (three straight steps, door + 3.0 wide) | "none"
  top      {"type": "flat", "parapet": "solid"|"balustrade", "h", "skylight": [w, d, h] or null,
            "topiary": [[x, y], ...]} |
           {"type": "drum_dome", "R", "h", "seg", "windows": n, "dome_h", "onion": bool} |
           {"type": "dome", "dome_h", "onion": bool}  (dome straight on the cornice of a round / oct plan)
  medals   [[wall, u, z], ...] raised gold quatrefoil medallions
Marble = Marble + HH_HaloMarbleBlock_Cream (255,244,222), gold = Metal + HH_HaloGoldTrim (255,175,25) (검수 10/11).
"""
import argparse
import json
import math
import os

ap = argparse.ArgumentParser()
ap.add_argument("spec")
ap.add_argument("--origin", default="3000,0,60")
ap.add_argument("--out")
a = ap.parse_args()
S = json.load(open(a.spec, encoding="utf-8"))
NAME = S["name"]
OX, OY, OZ = [float(v) for v in a.origin.split(",")]
OUT = a.out or "build/skel_%s.luau" % NAME
COURSE = 1.5                                          # cream 12-stud tile: 8 courses, top-anchored per part
parts = []
orn_items = []
UP = (0.0, 0.0, 1.0)


def vadd(*vs):
    return tuple(sum(c) for c in zip(*vs))


def vmul(v, s):
    return tuple(c * s for c in v)


def norm(v):
    L = math.sqrt(sum(c * c for c in v))
    return tuple(c / L for c in v)


def add(name, size, pos, X=(1.0, 0.0, 0.0), Y=UP, mat="marble", shape="Block"):
    parts.append(dict(name=name, shape=shape, size=[round(s, 4) for s in size], pos=[round(c, 4) for c in pos],
                      X=[round(c, 5) for c in X], Y=[round(c, 5) for c in Y], mat=mat, grp="house"))


def disk(name, d, th, pos, n, mat="gold"):
    add(name, (th, d, d), pos, n, UP if abs(n[2]) < 0.9 else (1.0, 0.0, 0.0), mat, "Cylinder")


def post(name, d, h, x, y, z0, mat="marble"):
    add(name, (h, d, d), (x, y, z0 + h / 2), UP, (1.0, 0.0, 0.0), mat, "Cylinder")


def ball(name, d, pos, mat="gold"):
    add(name, (d, d, d), pos, mat=mat, shape="Ball")


# ---------------------------------------------------------------- plan
P = S["plan"]
if P["shape"] == "rect":
    W2, D2 = P["W"] / 2, P["D"] / 2
    V = [(-W2, D2), (-W2, -D2), (W2, -D2), (W2, D2)]
    NAMES = ["left", "back", "right", "front"]          # edge i runs V[i] -> V[i+1]; front runs +x -> -x
elif P["shape"] == "oct":
    HF, XS, DY, D2 = P["HF"], P["XS"], P["DY"], P["D"] / 2
    YF, YB = D2, -D2
    V = [(-HF, YF), (-XS, YF - DY), (-XS, YB + DY), (-HF, YB), (HF, YB), (XS, YB + DY), (XS, YF - DY), (HF, YF)]
    NAMES = ["front_l", "left", "back_l", "back", "back_r", "right", "front_r", "front"]
else:
    # a flat front chord wide enough for the door + its frame, the rest of the circle in seg - 1 equal segments
    R, SEG = P["R"], P.get("seg", 16)
    half = math.asin(min(0.95, (S["door"]["w"] / 2 + 1.6) / R))
    a0, a1 = math.pi / 2 + half, math.pi / 2 - half + 2 * math.pi        # from the front-left corner round the back
    # "flats": polar angles (deg, 0 = +x, 90 = front) of long flat facets for the windows (a window is a hole in ONE
    # wall edge, a 32-edge circle has edges ~1 stud wide); chord "flat_w" studs. The other edges share the rest evenly.
    FW = 2 * math.asin(min(0.9, P.get("flat_w", 3.2) / 2 / R))
    FL = sorted((f if f >= math.degrees(a0) else f + 360.0) for f in P.get("flats", []))
    STEP = ((a1 - a0) - len(FL) * FW) / max(1, SEG - 1 - len(FL))
    ANG, cur, ns = [], a0, 0
    for wi, f in enumerate(FL + [None]):
        end = a1 if f is None else math.radians(f) - FW / 2
        m = max(1, int(round((end - cur) / STEP))) if end - cur > 1e-6 else 0
        for k in range(m):
            ANG.append((cur + (end - cur) * k / m, "s%d" % ns))
            ns += 1
        if f is None:
            break
        ANG.append((end, "w%d" % wi))                     # flat facet wi: from here to the next vertex (end + FW)
        cur = end + FW
    ANG.append((a1, "s%d" % ns))
    V = [(R * math.cos(t), R * math.sin(t)) for t, _ in ANG]
    NAMES = [n for _, n in ANG]                           # the one facing +y is renamed "front" below
YF = max(y for _, y in V)
Z0 = S.get("Z0", 1.1)
T = 0.8
STOREYS = S["storeys"]
Z_LINES = [Z0]
for st in STOREYS:
    Z_LINES.append(Z_LINES[-1] + st["h"])
Z1 = Z_LINES[-1]


class Wall:
    def __init__(self, name, p0, p1):
        (x0, y0), (x1, y1) = p0, p1
        self.name, self.p0 = name, (x0, y0, 0.0)
        self.L = math.hypot(x1 - x0, y1 - y0)
        self.u = ((x1 - x0) / self.L, (y1 - y0) / self.L, 0.0)
        n = (self.u[1], -self.u[0], 0.0)
        if (0 - (x0 + x1) / 2) * n[0] + (0 - (y0 + y1) / 2) * n[1] > 0:
            n = (-n[0], -n[1], 0.0)
        self.n = n

    def at(self, uc, z, off=0.0):
        return vadd(self.p0, vmul(self.u, uc), (0.0, 0.0, z), vmul(self.n, off))

    def slab(self, nm, u0, u1, z0, z1, depth=T, off=0.0, mat="marble"):
        if u1 - u0 < 0.03 or z1 - z0 < 0.03:
            return
        add(nm, (u1 - u0, z1 - z0, depth), self.at((u0 + u1) / 2, (z0 + z1) / 2, off - depth / 2), self.u, UP, mat)

    def arc(self, nm, uc, zc, r_in, w, depth, off, n_seg, mat):
        r_out = r_in + w
        seg_len = 2 * r_out * math.tan(math.pi / (2 * n_seg)) * 1.04
        for k in range(n_seg):
            t = math.pi * (k + 0.5) / n_seg
            d = vadd(vmul(self.u, math.cos(t)), vmul(UP, math.sin(t)))
            tan = vadd(vmul(self.u, -math.sin(t)), vmul(UP, math.cos(t)))
            add("%s%d" % (nm, k), (seg_len, w, depth), vadd(self.at(uc, zc, off - depth / 2), vmul(d, r_in + w / 2)), tan, d, mat)

    def quatrefoil(self, nm, uc, zc, s=1.0):
        disk(nm + "_Rim", 1.3 * s, 0.14, self.at(uc, zc, 0.07), self.n)
        disk(nm + "_Boss", 1.1 * s, 0.26, self.at(uc, zc, 0.13), self.n, "marble")
        for k, (du, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
            disk("%s_Lobe%d" % (nm, k), 0.42 * s, 0.2, self.at(uc + du * 0.25 * s, zc + dz * 0.25 * s, 0.36), self.n)
        disk(nm + "_Core", 0.34 * s, 0.3, self.at(uc, zc, 0.41), self.n)


walls = {}
EDGES = []
for i, nm in enumerate(NAMES):
    p0, p1 = V[i], V[(i + 1) % len(V)]
    walls[nm] = Wall(nm, p0, p1)
    EDGES.append(nm)
front = max(EDGES, key=lambda n: walls[n].n[1])          # the wall facing +y holds the door
if front != "front":
    walls["front"] = walls.pop(front)
    walls["front"].name = "front"
    EDGES[EDGES.index(front)] = "front"
FI = EDGES.index("front")


def wall_name(nm):
    """'@k' = the wall k steps from the front (k > 0 towards the +x side's neighbour order), else the name itself"""
    if nm.startswith("@"):
        return EDGES[(FI + int(nm[1:])) % len(EDGES)]
    return nm


DOOR = S["door"]
DOOR_W, DOOR_H = DOOR["w"], DOOR["h"]
wf = walls["front"]
DU = wf.L / 2
DR = DOOR_W / 2
DSP = Z0 + DOOR_H - DR

# holes per wall: door + windows of every storey (window bottom on a course line under the storey top)
holes = {nm: [] for nm in EDGES}
win_list = []
holes["front"].append((DU, DOOR_W, Z0, Z0 + DOOR_H, "door"))
for si, st in enumerate(STOREYS):
    zb, zt = Z_LINES[si], Z_LINES[si + 1]
    WS = st.get("win", {})
    kind = WS.get("type", "arch")
    # window: top "gap" (1.1) under the storey line (room for keystone + band), height "h" (up to 4.6, bottom on a
    # course line); "w" = glass width, "by_wall" {wall: w} = another width on single walls
    top = zt - WS.get("gap", 1.1)
    hgt = min(st["h"] - 1.9, WS.get("h", 4.6))
    w0 = zt - math.ceil((zt - (top - hgt)) / COURSE - 1e-6) * COURSE
    w0 = max(w0, zb + 0.9)
    for nm0, us in st.get("walls", {}).items():
        nm = wall_name(nm0)
        if nm not in walls:
            continue
        ww = WS.get("by_wall", {}).get(nm0, WS.get("by_wall", {}).get(nm, WS.get("w", 1.6)))
        sp = top - ww / 2 if kind == "arch" else top
        for f in us:
            uc = f * walls[nm].L
            if uc - ww / 2 - 0.3 < 0 or uc + ww / 2 + 0.3 > walls[nm].L:       # must fit the wall edge (minus 0.3)
                print("[house] WARNING: window %.2f wide does not fit wall %s (%.2f long), skipped" % (ww, nm, walls[nm].L))
                continue
            holes[nm].append((uc, ww, w0, top, kind))
            win_list.append((nm, uc, ww, w0, sp, kind, si))
for nm in EDGES:
    w = walls[nm]
    # group openings that overlap along the wall (a window above the door), fill round them; every slab ends on a
    # course line from the top (wall slabs end at Z1)
    groups = []
    for h in sorted(holes[nm], key=lambda h: h[0] - h[1] / 2):
        if groups and h[0] - h[1] / 2 < groups[-1]["u1"]:
            g = groups[-1]
            g["u0"], g["u1"] = min(g["u0"], h[0] - h[1] / 2), max(g["u1"], h[0] + h[1] / 2)
            g["h"].append(h)
        else:
            groups.append({"u0": h[0] - h[1] / 2, "u1": h[0] + h[1] / 2, "h": [h]})
    u = 0.0
    for k, g in enumerate(groups):
        w.slab("%s_C%d" % (nm, k), u, g["u0"], Z0, Z1)
        z = Z0
        hs = sorted(g["h"], key=lambda h: h[2])
        for j, (uc, hw, hz0, hz1, _) in enumerate(hs):
            w.slab("%s_G%d_%d" % (nm, k, j), g["u0"], g["u1"], z, hz0)                 # between openings, full width
            w.slab("%s_GL%d_%d" % (nm, k, j), g["u0"], uc - hw / 2, hz0, hz1)          # beside a narrower opening
            w.slab("%s_GR%d_%d" % (nm, k, j), uc + hw / 2, g["u1"], hz0, hz1)
            z = hz1
        w.slab("%s_GT%d" % (nm, k), g["u0"], g["u1"], z, Z1)
        u = g["u1"]
    w.slab("%s_C%d" % (nm, len(groups)), u, w.L, Z0, Z1)


def window(w, nm, uc, ww, w0, sp, kind):
    r = ww / 2
    g = 0.1 * ww + 0.08                           # gold frame width scales with the window (0.22 at w 1.4, 0.31 at w 2.3)
    hood = 0.12 * ww + 0.12                       # marble hood width over the frame
    kw = 0.12 + 0.05 * ww                         # keystone half width
    ov = 0.5 * g + 0.25                           # sill overhang beyond the glass edge
    top = sp + (r if kind == "arch" else 0)
    w.slab(nm + "_Glass", uc - r, uc + r, w0, sp, 0.1, -0.12, "glass")
    for side, sg in (("L", -1), ("R", 1)):
        u0 = uc + sg * r
        w.slab(nm + "_Jamb" + side, min(u0, u0 + sg * g), max(u0, u0 + sg * g), w0 - 0.1, sp, T + 0.3, 0.15, "gold")
    if kind == "arch":
        K = max(6, int(ww * 4))
        for k in range(K):
            a0, a1 = -r + 2 * r * k / K, -r + 2 * r * (k + 1) / K
            h = math.sqrt(max(r * r - min(abs(a0), abs(a1)) ** 2, 0.0)) if a0 * a1 > 0 else r
            w.slab("%s_GlassArch%d" % (nm, k), uc + a0, uc + a1, sp, sp + h, 0.1, -0.12, "glass")
        w.arc(nm + "_FrameArc", uc, sp, r, g, T + 0.3, 0.15, max(9, int(ww * 5)), "gold")
        w.arc(nm + "_Hood", uc, sp, r + g - 0.02, hood, T + 0.45, 0.32, max(9, int(ww * 5)), "marble")
    else:
        w.slab(nm + "_Head", uc - r - g, uc + r + g, sp, sp + g, T + 0.3, 0.15, "gold")
        w.slab(nm + "_HoodStone", uc - r - g - 0.2, uc + r + g + 0.2, sp + g, sp + g + 0.35, 0.6, 0.35, "marble")
    w.slab(nm + "_Key", uc - kw, uc + kw, top + g + 0.05, top + g + 0.75, 0.8, 0.45, "gold")
    w.slab(nm + "_KeyCap", uc - kw - 0.1, uc + kw + 0.1, top + g + 0.75, top + g + 0.92, 0.95, 0.6, "gold")
    w.slab(nm + "_Sill", uc - r - ov, uc + r + ov, w0 - 0.3, w0, 0.75, 0.35, "gold")
    w.slab(nm + "_SillStone", uc - r - ov + 0.12, uc + r + ov - 0.12, w0 - 0.7, w0 - 0.3, 0.55, 0.25)
    bars = [0.0] if ww <= 2.4 else [-ww / 6, ww / 6]       # wide window: two vertical bars (three panes)
    for k, bx in enumerate(bars):
        w.slab("%s_BarV%d" % (nm, k), uc + bx - 0.05, uc + bx + 0.05, w0, sp + math.sqrt(max(r * r - bx * bx, 0.0)) if kind == "arch" else top, 0.08, -0.06, "gold")
    w.slab(nm + "_BarH", uc - r, uc + r, sp - 0.05, sp + 0.05, 0.08, -0.06, "gold")


for i, (nm, uc, ww, w0, sp, kind, si) in enumerate(win_list):
    window(walls[nm], "%s_Win%d_%d" % (nm, si, i), uc, ww, w0, sp, kind)

# ---------------------------------------------------------------- door
GW = 0.7
LEAF_R = DR - 0.45
LEAF_OFF = -0.4
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
wf.slab("Door_Back", DU - LEAF_R, DU + LEAF_R, Z0, DSP, 0.1, LEAF_OFF - 1.15, "wood")
LEAF_FRONT = YF + LEAF_OFF
CXD = wf.at(DU, 0)[0]
if DOOR.get("double"):
    for k, sx in enumerate((-1, 1)):
        orn_items.append({"type": "leaf", "name": "%s_Leaf%d" % (NAME, k), "c": [CXD, DSP], "R": LEAF_R + 0.1,
                          "bottom": Z0 + 0.1, "front": LEAF_FRONT, "t": 0.32, "half": sx})
    for k, sx in enumerate((-1, 1)):
        orn_items.append({"type": "knocker", "name": "%s_Knob%d" % (NAME, k), "pos": [CXD + sx * 0.45, Z0 + 3.4], "R": 0.28,
                          "r": 0.06, "plate": 0.42, "face_y": LEAF_FRONT})
else:
    orn_items.append({"type": "leaf", "name": NAME + "_Leaf", "c": [CXD, DSP], "R": LEAF_R + 0.1, "bottom": Z0 + 0.1,
                      "front": LEAF_FRONT, "t": 0.32})
    orn_items.append({"type": "knocker", "name": NAME + "_Knocker", "pos": [CXD + 0.45 * (LEAF_R + 0.1), Z0 + 0.46 * DOOR_H],
                      "face_y": LEAF_FRONT})
for k, z in enumerate((Z0 + 0.25 * DOOR_H, Z0 + 0.68 * DOOR_H)):
    orn_items.append({"type": "hinge", "name": "%s_Hinge%d" % (NAME, k), "edge": [CXD - LEAF_R, z], "dir": 1,
                      "len": min(1.35, LEAF_R * 0.65), "face_y": LEAF_FRONT})

# ---------------------------------------------------------------- floors / ceilings (hollow inside, WalkGround floor)
xs, ys = [x for x, _ in V], [y for _, y in V]
add("FloorInside", (max(xs) - min(xs) - 1.2, max(ys) - min(ys) - 1.2, 0.3), (0, 0, Z0 - 0.15), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), "floor")
for si in range(1, len(STOREYS)):
    add("FloorStorey%d" % si, (max(xs) - min(xs) - 1.2, max(ys) - min(ys) - 1.2, 0.3), (0, 0, Z_LINES[si] - 0.15),
        (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), "floor")
add("CeilingSlab", (max(xs) - min(xs) + 0.4, max(ys) - min(ys) + 0.4, 0.5), (0, 0, Z1 + 0.25), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0))


# ---------------------------------------------------------------- rings
def offset_poly(d, poly=None):
    poly = poly or V
    out = []
    n = len(poly)
    for i in range(n):
        wa, wb = walls[EDGES[i - 1]], walls[EDGES[i]]
        na, nb = wa.n, wb.n
        k = d / (1 + na[0] * nb[0] + na[1] * nb[1])
        out.append((poly[i][0] + (na[0] + nb[0]) * k, poly[i][1] + (na[1] + nb[1]) * k))
    return out


def ring(prefix, d, z0, z1, depth, mat, skip=()):
    Pp = offset_poly(d)
    for i, nm in enumerate(EDGES):
        if nm in skip:
            continue
        w = walls[nm]
        p0, p1 = Pp[i], Pp[(i + 1) % len(Pp)]
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        add("%s_%s" % (prefix, nm), (L, z1 - z0, depth), (mx - w.n[0] * depth / 2, my - w.n[1] * depth / 2, (z0 + z1) / 2), w.u, UP, mat)


ring("Plinth", 1.2, 0.0, Z0, 2.0, "marble")
ring("FootRing", 1.4, 0.0, 0.55, 0.5, "gold")
for si in range(1, len(STOREYS)):                       # storey line: marble ledge + gold band
    z = Z_LINES[si]
    ring("StoreyLedge%d" % si, 0.5, z - 0.35, z + 0.15, 1.1, "marble", ("front",) if z < DSP + DR + 0.8 else ())
    ring("StoreyGold%d" % si, 0.6, z + 0.15, z + 0.4, 0.6, "gold", ("front",) if z < DSP + DR + 0.8 else ())
ring("Cornice", 1.2, Z1, Z1 + 0.7, 2.0, "marble")
ring("CorniceGold", 1.32, Z1 + 0.7, Z1 + 0.9, 0.85, "gold")
ZT = Z1 + 0.9                                           # top of the cornice

# ---------------------------------------------------------------- pilasters / towers
PIL_OUT = 0.85
if S.get("pilasters", True):
    for i, (x, y) in enumerate(V):
        wa, wb = walls[EDGES[i - 1]], walls[EDGES[i]]
        bis = norm(vadd(wa.n, wb.n))
        along = (-bis[1], bis[0], 0.0)
        wd = 1.3

        def pc(face_out, depth):
            o = face_out - depth / 2
            return (x + bis[0] * o, y + bis[1] * o)
        add("Pilaster%d" % i, (wd, Z1 - Z0, 1.2), (*pc(PIL_OUT, 1.2), (Z0 + Z1) / 2), along, UP)
        add("PilasterCap%d" % i, (wd + 0.4, 1.0, 1.5), (*pc(PIL_OUT + 0.2, 1.5), Z1 - 0.5), along, UP, "gold")
        add("PilasterFoot%d" % i, (wd + 0.25, 0.4, 1.45), (*pc(PIL_OUT + 0.1, 1.45), Z0 + 0.2), along, UP, "gold")
        for si in range(1, len(STOREYS)):
            add("PilasterBand%d_%d" % (i, si), (wd + 0.2, 0.35, 1.4), (*pc(PIL_OUT + 0.1, 1.4), Z_LINES[si] + 0.27), along, UP, "gold")
TW = S.get("towers")
if TW and P["shape"] == "rect":
    tw, hx = TW["w"], TW.get("h_extra", 3.0)
    for i, (x, y) in enumerate(V):
        th = ZT + hx
        add("Tower%d" % i, (tw, th, tw), (x, y, th / 2))
        for k, z in enumerate([Z_LINES[s] for s in range(1, len(STOREYS))] + [Z1 - 0.6, th - 0.5]):
            add("TowerBand%d_%d" % (i, k), (tw + 0.3, 0.45, tw + 0.3), (x, y, z), mat="gold")
        add("TowerCap%d" % i, (tw + 0.5, 0.4, tw + 0.5), (x, y, th + 0.2))
        add("TowerFoot%d" % i, (tw + 0.4, 0.55, tw + 0.4), (x, y, 0.275), mat="gold")
        if TW.get("dome", False):                      # small gold dome cap (ornament) with a small finial of its own
            dr = tw / 2 + 0.2
            orn_items.append({"type": "dome", "name": "%s_TowerDome%d" % (NAME, i), "pos": [x, y, th + 0.4], "R": dr,
                              "h": dr * TW.get("dome_h", 1.1), "ribs": 6, "fin": TW.get("fin", 0.45)})
        elif TW.get("finial", True):
            post("TowerFinialBase%d" % i, tw * 0.55, 0.5, x, y, th + 0.4, "gold")
            ball("TowerFinialBall%d" % i, tw * 0.5, (x, y, th + 1.15))
            orn_items.append({"type": "finial", "name": "%s_Finial%d" % (NAME, i), "pos": [x, y, th + 1.4], "d": tw * 0.32})
        if TW.get("window", False) and y > 0:          # small arched window on the front (+y) face of the front towers
            ww_ = TW.get("win_w", 0.9)
            orn_items.append({"type": "arch_window", "name": "%s_TowerWin%d" % (NAME, i), "pos": [x, y + tw / 2, ZT + 0.6],
                              "yaw": 0, "W": ww_, "spring": ZT + 0.6 + TW.get("win_h", 1.6), "pier": 0.25, "frame": 0.1,
                              "depth": 0.9, "recess": 0.2})

# ---------------------------------------------------------------- pedestals + lanterns
LANT_W, LANT_H = 0.9, 1.15
if S.get("pedestals", True):
    pz = Z0 + 3.75
    for k, sx in enumerate((-1, 1)):
        x = CXD + sx * (DR + GW + 0.75 + 1.0)
        add("Pedestal%d" % k, (1.8, pz, 2.0), (x, YF + 0.45, pz / 2))
        add("Pedestal%d_Cap" % k, (1.92, 0.35, 2.12), (x, YF + 0.45, pz + 0.175), mat="gold")
        add("Pedestal%d_Foot" % k, (2.0, 0.55, 2.2), (x, YF + 0.45, 0.275), mat="gold")
        add("Pedestal%d_Plaque" % k, (0.7, 1.2, 0.1), (x, YF + 1.48, 2.0), mat="gold")
        lc = (x, YF + 0.25 + LANT_W / 2 + 0.05, DSP + 0.6)
        g = LANT_W - 0.2
        add("LampGlass%d" % k, (g, LANT_H - 0.1, g), lc, mat="lamp")
        orn_items.append({"type": "lantern", "name": "%s_Lantern%d" % (NAME, k), "pos": list(lc), "w": LANT_W, "hgt": LANT_H,
                          "post": 0.09, "wall_y": YF})

# ---------------------------------------------------------------- awning
AW = S.get("awning")
if AW:
    AW_W, AW_D, AW_DROP, AW_N = AW.get("w", DOOR_W + 2.4), AW.get("d", 2.3), AW.get("drop", 1.2), AW.get("n", 7)
    AW_TOP = AW.get("top", DSP + DR + GW + 0.9)
    cols = AW.get("colors", [[250, 205, 72], [255, 243, 212]])
    aw_len = math.hypot(AW_D, AW_DROP)
    aw_n = (0.0, AW_DROP / aw_len, AW_D / aw_len)
    sw = AW_W / AW_N
    for k in range(AW_N):
        x = CXD - AW_W / 2 + sw * (k + 0.5)
        m = "cloth%d" % (k % 2)
        add("Awning_Stripe%d" % k, (sw + 0.01, 0.15, aw_len), (x, YF + AW_D / 2, AW_TOP - AW_DROP / 2), (1.0, 0.0, 0.0), aw_n, m)
        add("Awning_Valance%d" % k, (sw + 0.01, 0.42, 0.12), (x, YF + AW_D + 0.02, AW_TOP - AW_DROP - 0.19), mat=m)
        disk("Awning_Scallop%d" % k, sw * 0.98, 0.14, (x, YF + AW_D + 0.02, AW_TOP - AW_DROP - 0.4), (0.0, 1.0, 0.0), m)
    add("Awning_Rod", (AW_W + 0.4, 0.26, 0.26), (CXD, YF + 0.16, AW_TOP + 0.02), (1.0, 0.0, 0.0), UP, "gold", "Cylinder")
    for k, sx in enumerate((-1, 1)):
        ball("Awning_BallFront%d" % k, 0.42, (CXD + sx * (AW_W / 2 + 0.05), YF + AW_D + 0.05, AW_TOP - AW_DROP))
        ball("Awning_BallTop%d" % k, 0.36, (CXD + sx * (AW_W / 2 + 0.25), YF + 0.16, AW_TOP + 0.02))
else:
    cols = [[250, 205, 72], [255, 243, 212]]

# ---------------------------------------------------------------- steps, pots, medals
if S.get("steps", "half") == "half":
    post("StepTop", DOOR_W + 1.6, Z0 - 0.01, CXD, YF, 0.0)
    post("StepLow", DOOR_W + 3.4, Z0 / 2, CXD, YF, 0.0)
elif S.get("steps") == "three":                         # three straight steps (0.37 high, 0.9 deep, door + 3.0 wide), top one flush with the plinth
    for k in range(3):
        sh = Z0 - 0.01 - 0.37 * k
        add("Step%d" % k, (DOOR_W + 3.0, sh, 0.9), (CXD, YF + 1.2 + 0.9 * (k + 0.5), sh / 2))
for i, (x, y, d, h) in enumerate(S.get("pots", [])):
    post("Pot%d" % i, d, h - 0.4, x, y, 0.0)
    post("Pot%d_Soil" % i, d - 0.25, 0.15, x, y, h - 0.4, "soil")
    seg = 18
    r_in, wdt = d / 2 - 0.12, 0.34
    r_out = r_in + wdt
    sl = 2 * r_out * math.tan(math.pi / seg) * 1.04
    for k in range(seg):
        t = 2 * math.pi * k / seg
        dd = (math.cos(t), math.sin(t), 0.0)
        add("Pot%d_Rim%d" % (i, k), (sl, 0.4, wdt), (x + dd[0] * (r_in + wdt / 2), y + dd[1] * (r_in + wdt / 2), h - 0.2), (-dd[1], dd[0], 0.0), UP)
    post("Pot%d_GoldBase" % i, d + 0.35, 0.55, x, y, 0.0, "gold")
    post("Pot%d_GoldLine" % i, d + 0.06, 0.12, x, y, h - 0.75, "gold")
for i, (nm, u, z) in enumerate(S.get("medals", [])):
    nm = wall_name(nm)
    if nm in walls:
        walls[nm].quatrefoil("Medal%d" % i, u * walls[nm].L, z, 1.0)

# ---------------------------------------------------------------- top
TOP = S.get("top", {"type": "flat", "parapet": "solid", "h": 1.6})
if TOP["type"] == "flat":
    ph = TOP.get("h", 1.6)
    Pp = offset_poly(0.9)
    for i, nm in enumerate(EDGES):
        w = walls[nm]
        p0, p1 = Pp[i], Pp[(i + 1) % len(Pp)]
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        if TOP.get("parapet") == "balustrade":
            add("Rail_%s" % nm, (L, 0.3, 0.9), (mx - w.n[0] * 0.45, my - w.n[1] * 0.45, ZT + ph - 0.15), w.u, UP)
            add("RailBase_%s" % nm, (L, 0.25, 0.9), (mx - w.n[0] * 0.45, my - w.n[1] * 0.45, ZT + 0.125), w.u, UP)
            nb = max(2, int(L / 0.7))
            for k in range(nb):
                f = (k + 0.5) / nb
                bx, by = p0[0] + (p1[0] - p0[0]) * f - w.n[0] * 0.45, p0[1] + (p1[1] - p0[1]) * f - w.n[1] * 0.45
                post("Baluster_%s_%d" % (nm, k), 0.32, ph - 0.55, bx, by, ZT + 0.25)
        else:
            add("Parapet_%s" % nm, (L, ph, 0.7), (mx - w.n[0] * 0.35, my - w.n[1] * 0.35, ZT + ph / 2), w.u, UP)
            add("ParapetGold_%s" % nm, (L + 0.02, 0.2, 0.8), (mx - w.n[0] * 0.35, my - w.n[1] * 0.35, ZT + ph - 0.1), w.u, UP, "gold")
    for i, (x, y) in enumerate(Pp):
        add("ParapetPost%d" % i, (1.1, ph + 0.5, 1.1), (x, y, ZT + (ph + 0.5) / 2))
        add("ParapetPostCap%d" % i, (1.3, 0.25, 1.3), (x, y, ZT + ph + 0.62), mat="gold")
    add("RoofDeck", (max(xs) - min(xs) + 1.6, max(ys) - min(ys) + 1.6, 0.2), (0, 0, ZT + 0.1), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), "floor")
    sk = TOP.get("skylight")
    if sk:
        sw_, sd_, sh_ = sk
        add("Skylight_Base", (sw_ + 0.6, 0.6, sd_ + 0.6), (0, 0, ZT + 0.5), mat="marble")
        add("Skylight_Glass", (sw_, sh_, sd_), (0, 0, ZT + 0.8 + sh_ / 2), mat="glass")
        for k, (dx, dy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
            add("Skylight_Post%d" % k, (0.18, sh_ + 0.1, 0.18), (dx * sw_ / 2, dy * sd_ / 2, ZT + 0.8 + sh_ / 2), mat="gold")
        add("Skylight_Ridge", (sw_ + 0.2, 0.18, 0.18), (0, 0, ZT + 0.85 + sh_), mat="gold")
        ball("Skylight_Ball", 0.4, (0, 0, ZT + 1.1 + sh_))
    for i, (x, y) in enumerate(TOP.get("topiary", [])):
        post("TopiaryPot%d" % i, 1.4, 0.9, x, y, ZT + 0.2)
        post("TopiaryPotGold%d" % i, 1.5, 0.15, x, y, ZT + 1.0, "gold")
        post("TopiarySoil%d" % i, 1.2, 0.1, x, y, ZT + 1.0, "soil")
else:
    zb = ZT
    if TOP["type"] == "drum_dome":
        R_, H_, seg = TOP["R"], TOP["h"], TOP.get("seg", 16)
        nwin = TOP.get("windows", 3)
        sl = 2 * R_ * math.tan(math.pi / seg) * 1.02
        for k in range(seg):
            t = math.pi / 2 + 2 * math.pi * k / seg
            dd = (math.cos(t), math.sin(t), 0.0)
            win = nwin and (k % max(1, seg // max(nwin, 1)) == 0) and abs(dd[1] - 1) < 1.3
            add("Drum%d" % k, (sl, H_, 0.7), (dd[0] * (R_ - 0.35), dd[1] * (R_ - 0.35), zb + H_ / 2), (-dd[1], dd[0], 0.0), UP)
        for k in range(nwin):                           # arched windows on the front half of the drum
            t = math.pi / 2 + (k - (nwin - 1) / 2) * (2 * math.pi / seg) * 2
            dd = (math.cos(t), math.sin(t), 0.0)
            orn_items.append({"type": "arch_window", "name": "%s_DrumWin%d" % (NAME, k), "pos": [dd[0] * (R_ + 0.05), dd[1] * (R_ + 0.05), zb + 0.8],
                              "yaw": math.degrees(t) - 90, "W": 1.2, "spring": zb + H_ - 1.6, "pier": 0.3, "frame": 0.14, "depth": 0.9, "recess": 0.2})
        add("DrumBase", (2 * R_ + 0.8, 0.5, 2 * R_ + 0.8), (0, 0, zb + 0.25), mat="marble", shape="Block")
        add("DrumTopGold", (0.35, 2 * R_ + 0.6, 2 * R_ + 0.6), (0, 0, zb + H_ - 0.1), UP, (1.0, 0.0, 0.0), "gold", "Cylinder")
        zb += H_
        dome_r = R_ + 0.15
    else:
        dome_r = max(abs(x) for x, _ in V) + 0.6
    orn_items.append({"type": "dome", "name": NAME + "_Dome", "pos": [0.0, 0.0, zb], "R": dome_r, "h": TOP.get("dome_h", dome_r * 1.05),
                      "onion": TOP.get("onion", False), "ribs": TOP.get("ribs", 8)})

# ---------------------------------------------------------------- outputs
MARBLE = 'p.Material = Enum.Material.Marble; p.MaterialVariant = "HH_HaloMarbleBlock_Cream"; p.Color = Color3.fromRGB'
MAT = {
    "marble": MARBLE + "(255, 244, 222)",
    "floor": MARBLE + '(238, 226, 205); game:GetService("CollectionService"):AddTag(p, "WalkGround")',
    "gold": 'p.Material = Enum.Material.Metal; p.MaterialVariant = "HH_HaloGoldTrim"; p.Color = Color3.fromRGB(255, 175, 25)',
    "soil": 'p.Material = Enum.Material.Sand; p.Color = Color3.fromRGB(140, 100, 62)',
    "wood": 'p.Material = Enum.Material.Wood; p.Color = Color3.fromRGB(176, 118, 68); p.CanCollide = false',
    "lamp": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(255, 228, 160); p.Transparency = 0.3; p:SetAttribute("LampLight", true); local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 214, 140); l.Brightness = 1.2; l.Range = 14; l.Enabled = false; l.Parent = p',
    "glass": 'p.Material = Enum.Material.Glass; p.Color = Color3.fromRGB(150, 205, 245); p.Transparency = 0.3; p.Reflectance = 0.15',
    "cloth0": 'p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(%d, %d, %d)' % tuple(cols[0]),
    "cloth1": 'p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(%d, %d, %d)' % tuple(cols[1]),
}


def r3(v):
    return (v[0], v[2], -v[1])


L = ['-- %s skeleton (generated by tools/skeleton_house.py from %s, 이미지 생성 3, SPEC A23-120/125). WorldKit only.' % (NAME, a.spec.replace("\\", "/")),
     'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end',
     'local root = workspace:FindFirstChild("SkeletonTest") or Instance.new("Folder"); root.Name = "SkeletonTest"; root.Parent = workspace',
     'local old = root:FindFirstChild("%s_Skeleton"); if old then old:Destroy() end' % NAME,
     'local house = Instance.new("Model"); house.Name = "%s_Skeleton"; house.Parent = root' % NAME,
     'house:SetAttribute("Spec", "%s")' % a.spec.replace("\\", "/"),
     'local function mk(parent, name, shape, sx, sy, sz, x, y, z, ax, ay, az, bx, by, bz, mat)',
     '  local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth',
     '  p.Shape = Enum.PartType[shape]; p.Size = Vector3.new(sx, sy, sz)',
     '  p.CFrame = CFrame.fromMatrix(Vector3.new(x, y, z), Vector3.new(ax, ay, az), Vector3.new(bx, by, bz))']
for i, (k, v) in enumerate(MAT.items()):
    L.append('  %s mat == "%s" then %s' % ("if" if i == 0 else "elseif", k, v))
L += ['  end', '  if mat == "glass" or mat == "lamp" then p.CastShadow = false end', '  p.Parent = parent; return p', 'end']
for p in parts:
    x, y, z = p["pos"]
    X, Y = r3(p["X"]), r3(p["Y"])
    L.append('mk(house, "%s", "%s", %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, "%s")' % (
        p["name"], p["shape"], *p["size"], OX + x, OY + z, OZ - y, *X, *Y, p["mat"]))
L.append('local d = Instance.new("Attachment"); d.Name = "DoorFront"; d.Parent = house:FindFirstChild("FloorInside"); '
         'd.WorldPosition = Vector3.new(%.3f, %.3f, %.3f)' % (OX + CXD, OY + Z0 / 2, OZ - (YF + DOOR_W / 2 + 2.5)))
L.append('local n = 0; for _, q in house:GetDescendants() do if q:IsA("BasePart") then n += 1 end end')
L.append('return "%s skeleton built: " .. n .. " parts"' % NAME)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
base = os.path.splitext(OUT)[0]
json.dump(parts, open(base + ".json", "w"), indent=0)
zc = (Z1 + Z0) / 2
spanx = max(xs) - min(xs)
orn = {"note": "%s ornaments (tools/skeleton_house.py)" % NAME, "items": orn_items,
       "shots": {"door_front": [[CXD, YF + 30, Z0 + DOOR_H / 2], [CXD, YF, Z0 + DOOR_H / 2], DOOR_W + 2.5, None]}}
json.dump(orn, open(base + "_ornaments.json", "w"), indent=1)
cams = {"close_door": [[CXD + 1.5, YF + 11.5, Z0 + 5], [CXD, YF, Z0 + 4.4], 40],
        "close_window": [[spanx * 0.6, YF + 9, zc + 1], [spanx * 0.25, YF, zc], 45],
        "close_base": [[spanx * 0.55, YF + 9, 3.0], [spanx * 0.3, YF, 1.5], 40]}
json.dump(cams, open(base + "_cams.json", "w"), indent=1)
print("[house] %s: %d parts, %d ornaments, width %.1f depth %.1f, walls top %.2f, cornice top %.2f -> %s"
      % (NAME, len(parts), len(orn_items), spanx, max(ys) - min(ys), Z1, ZT, OUT))
