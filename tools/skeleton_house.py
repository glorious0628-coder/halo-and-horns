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
  door     {"w", "h", "double": bool, "u": 0..1 along the front (default 0.5; u grows to the viewer's right = -x)}; reveal,
           frame, leaf, pedestals, awning, steps, DoorFront follow it (a pedestal with no room beside an off-centre door
           or next to the shopwin is skipped)
  shopwin  {"u", "w", "h": glass height, "type": "arch" (flat segment top) | "rect", "counter": 2.0 studs above Z0}: one wide
           display opening on the front: gold frame, marble counter + gold sill, glass, 2-3 gold mullions; skipped with a
           warning if it overlaps the door, leaves the front or is too tall
  balconies  [{"storey": k >= 1, "walls": [...], "depth": 1.4, "margin"}] floor slab + gold band under it + marble rail
           with round balusters and gold cap at the bottom line of storey k (rect: between the margins + return rails)
  window_boxes  [[wall or "all", storey (0 = ground) or "all"], ...] marble box + gold rim + soil under those windows
  pilasters  true / false (turned along the corner bisectors; big gold capitals, band on each storey line)
  towers   {"w", "h_extra", "dome": true (small gold ribbed dome cap, R = w / 2 + 0.2; else "finial": true = ball),
            "window": true (small arched window "win_w" 0.9 on the front face of the front towers)} square corner towers
           on a rect plan (house 02 / 04 style)
  pedestals  true: marble blocks with gold caps either side of the door (lanterns above them); a pedestal in front of a
           ground-floor front window is cut down under the sill with a gold ball (10/11)
  lanterns [u, ...] wall lanterns along the front (0..1 like door.u) instead of the pedestal ones (shops); a lantern that
           would sit in a corner pilaster / tower is moved out in front of it
  awning   {"w", "colors": [[r,g,b], [r,g,b]], "n", "u": centre along the front (default = the door's), "top"} striped
           Fabric + HH_Fabric cloth + scalloped valance; without "top" it is kept under a front storey ledge / balcony / the cornice
  pots     [[x, y, d, h], ...] round pots with sand soil (plants: 4-view Tripo later, A23-122); a pot that hits a wall,
           pilaster, tower, pedestal, step, the door or another pot is moved the shortest way out (printed)
  steps    "half" (two half-round steps) | "three" (three straight steps, door + 3.0 wide) | "none"
  top      {"type": "flat", "parapet": "solid"|"balustrade", "h", "skylight": [w, d, h] or null,
            "topiary": [[x, y], ...], roof extras:
            "hip": {"h", "eave": 1.5, "chimney": [x, y, w, h]} (rect plan: blue slate SmoothPlastic (90,140,210) hip roof,
            gold hip lines + ridge + ball finial; use "parapet": "none"), "pergola": {"w", "d", "h", "columns": 4|6, "x", "y"},
            "cupola": {"r", "h", "x", "y"} (6 marble posts + gold ring + small dome ornament)} |
           {"type": "drum_dome", "R", "h", "seg", "windows": n, "dome_h", "onion": bool} |
           {"type": "dome", "dome_h", "onion": bool}  (dome straight on the cornice of a round / oct plan)
  medals   [[wall, u, z], ...] raised gold quatrefoil medallions
Marble = Marble + HH_HaloMarbleBlock_Cream (255,244,222), gold = Metal + HH_HaloGoldTrim (255,175,25) (검수 10/11).
"""
import argparse
import json
import math
import os
import re

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
    FL = sorted(((f if f >= math.degrees(a0) else f + 360.0), i) for i, f in enumerate(P.get("flats", [])))   # w<i> = spec order
    STEP = ((a1 - a0) - len(FL) * FW) / max(1, SEG - 1 - len(FL))
    ANG, cur, ns = [], a0, 0
    for fi in FL + [None]:
        f, wi = (None, None) if fi is None else fi
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

    def arc(self, nm, uc, zc, r_in, w, depth, off, n_seg, mat, a0=0.0, a1=math.pi):
        # a0..a1 = angle range from the +u axis (default 0..pi = half circle; the shop window uses a segment of a circle)
        r_out = r_in + w
        seg_len = 2 * r_out * math.tan((a1 - a0) / (2 * n_seg)) * 1.04
        for k in range(n_seg):
            t = a0 + (a1 - a0) * (k + 0.5) / n_seg
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
DU = DOOR.get("u", 0.5) * wf.L                            # door centre along the front (u 0..1, default centred)
OFFC = "u" in DOOR
DR = DOOR_W / 2
DSP = Z0 + DOOR_H - DR
DOOR_HALF = DR + 0.7 + 0.75                               # door + gold jamb + foot block (half width)

# holes per wall: door + windows of every storey (window bottom on a course line under the storey top)
holes = {nm: [] for nm in EDGES}
win_list = []
holes["front"].append((DU, DOOR_W, Z0, Z0 + DOOR_H, "door"))

# shopwin {u, w, h, type: "arch"|"rect", counter}: one wide display opening on the front (hole from Z0 + counter, h tall)
SHOP = S.get("shopwin")
SH = None
if SHOP:
    sh_w, sh_h = SHOP["w"], SHOP["h"]
    sh_u = SHOP.get("u", 0.5) * wf.L
    sh_kind = SHOP.get("type", "arch")
    sh_zb = Z0 + SHOP.get("counter", 2.0)
    sh_top = sh_zb + sh_h
    if abs(sh_u - DU) < DOOR_HALF + sh_w / 2 + 0.5:
        print("[house] WARNING: shopwin overlaps the door hole, skipped")
    elif sh_u - sh_w / 2 - 1.2 < 0 or sh_u + sh_w / 2 + 1.2 > wf.L:
        print("[house] WARNING: shopwin %.2f wide does not fit the front (%.2f long), skipped" % (sh_w, wf.L))
    elif sh_top > Z_LINES[1] - 1.3:
        print("[house] WARNING: shopwin too tall for the ground storey, skipped")
    else:
        SH = (sh_u, sh_w, sh_zb, sh_top, sh_kind)
        holes["front"].append((sh_u, sh_w, sh_zb, sh_top, "shop"))
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


def shop_window(w, uc, ww, zb, top, kind):
    """wide display window: gold frame, marble counter + gold sill, glass, 2-3 gold mullions; an arched one has a flat
    segment-of-a-circle top (rise = half the radius, max 1.6) with marble spandrel steps filling the hole corners"""
    nm = "Shop"
    r = ww / 2
    g = 0.45
    rise = min(r / 2, 1.6) if kind == "arch" else 0.0
    sp = top - rise                                       # spring line (top of the straight part)
    Rc = (r * r + rise * rise) / (2 * rise) if rise > 0 else 0.0
    zc = sp + rise - Rc                                   # circle centre height
    th = math.asin(min(1.0, r / Rc)) if rise > 0 else 0.0

    def hin(d):                                           # inner arch height at distance d from the centre line
        return zc + math.sqrt(max(Rc * Rc - d * d, 0.0)) if rise > 0 else top
    w.slab(nm + "_Glass", uc - r, uc + r, zb, sp, 0.1, -0.12, "glass")
    for side, sg in (("L", -1), ("R", 1)):
        u0 = uc + sg * r
        w.slab(nm + "_Jamb" + side, min(u0, u0 + sg * g), max(u0, u0 + sg * g), zb - 0.1, sp, T + 0.3, 0.15, "gold")
    if rise > 0:
        N = max(4, int(math.ceil(r / 0.3)))
        for sg, sd in ((-1, "L"), (1, "R")):
            for k in range(N):
                d0, d1 = r * k / N, r * (k + 1) / N
                w.slab("%s_Glass%s%d" % (nm, sd, k), uc + sg * d0 if sg > 0 else uc - d1, uc + sg * d1 if sg > 0 else uc - d0,
                       sp, hin(d1), 0.1, -0.12, "glass")
                zs = hin(d0)
                w.slab("%s_Span%s%d" % (nm, sd, k), uc + sg * d0 if sg > 0 else uc - d1, uc + sg * d1 if sg > 0 else uc - d0,
                       zs, top, T, 0.0, "marble")
        w.arc(nm + "_FrameArc", uc, zc, Rc, g, T + 0.3, 0.15, max(12, int(ww * 3)), "gold", math.pi / 2 - th, math.pi / 2 + th)
        w.arc(nm + "_Hood", uc, zc, Rc + g - 0.02, 0.4, T + 0.45, 0.32, max(12, int(ww * 3)), "marble", math.pi / 2 - th, math.pi / 2 + th)
        w.slab(nm + "_Key", uc - 0.3, uc + 0.3, top + g + 0.05, top + g + 0.85, 0.8, 0.45, "gold")
        w.slab(nm + "_KeyCap", uc - 0.42, uc + 0.42, top + g + 0.85, top + g + 1.05, 0.95, 0.6, "gold")
    else:
        w.slab(nm + "_Head", uc - r - g, uc + r + g, top, top + g, T + 0.3, 0.15, "gold")
        w.slab(nm + "_HoodStone", uc - r - g - 0.2, uc + r + g + 0.2, top + g, top + g + 0.35, 0.6, 0.35, "marble")
    # counter: gold sill line + marble counter top, a little wider than the opening
    w.slab(nm + "_SillGold", uc - r - g - 0.3, uc + r + g + 0.3, zb - 0.55, zb - 0.35, 1.2, 0.6, "gold")
    w.slab(nm + "_Counter", uc - r - g - 0.2, uc + r + g + 0.2, zb - 0.35, zb, 1.4, 0.7, "marble")
    nmul = 2 if ww <= 6.0 else 3
    for k in range(nmul):
        bx = -r + ww * (k + 1) / (nmul + 1)
        w.slab("%s_Mullion%d" % (nm, k), uc + bx - 0.07, uc + bx + 0.07, zb, hin(abs(bx)), 0.1, -0.05, "gold")
    w.slab(nm + "_Transom", uc - r, uc + r, sp - 0.07, sp + 0.07, 0.1, -0.05, "gold")


if SH:
    shop_window(walls["front"], *SH)

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

xs, ys = [x for x, _ in V], [y for _, y in V]


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


def poly_slab(nm, d, zc, th, mat="marble", tol=0.5):
    """flat slab filling the plan polygon offset by d (studs, < 0 = inside the wall line). rect: one block (the old
    bounding box); round / oct: strips along x whose ends stay inside the polygon, so no square corner pokes out of the
    body (10/11 check: the bounding-box floor/ceiling stuck 1.3-3.2 studs out of houses 01/03/06/09/10). The strip over
    the plan centre keeps the plain name (DoorFront hangs on FloorInside)."""
    Pp = offset_poly(d)
    px, py = [x for x, _ in Pp], [y for _, y in Pp]
    if P["shape"] == "rect":
        add(nm, (max(px) - min(px), max(py) - min(py), th), ((max(px) + min(px)) / 2, (max(py) + min(py)) / 2, zc),
            (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), mat)
        return

    def span(y):
        cut = []
        for i in range(len(Pp)):
            (x0, y0), (x1, y1) = Pp[i], Pp[(i + 1) % len(Pp)]
            if y0 != y1 and (y0 - y) * (y1 - y) <= 0:
                cut.append(x0 + (x1 - x0) * (y - y0) / (y1 - y0))
        return (min(cut), max(cut)) if len(cut) >= 2 else None
    y0, yend, k = min(py) + 0.02, max(py) - 0.02, 0
    while y0 < yend - 0.05:
        for h in (3.0, 2.0, 1.0, 0.5):                 # widest strip whose two ends move less than tol (gaps stay under the wall / cornice)
            y1 = min(y0 + h, yend)
            s0, s1 = span(y0), span(y1)
            if s0 and s1 and abs(s0[0] - s1[0]) <= tol and abs(s0[1] - s1[1]) <= tol:
                break
        if s0 and s1 and min(s0[1], s1[1]) - max(s0[0], s1[0]) > 0.05:
            a_, b_ = max(s0[0], s1[0]), min(s0[1], s1[1])
            add(nm if y0 <= 0 < y1 else "%s_%d" % (nm, k), (b_ - a_, y1 - y0, th), ((a_ + b_) / 2, (y0 + y1) / 2, zc),
                (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), mat)
            k += 1
        y0 = y1


# ---------------------------------------------------------------- floors / ceilings (hollow inside, WalkGround floor)
poly_slab("FloorInside", -0.6, Z0 - 0.15, 0.3, "floor")
for si in range(1, len(STOREYS)):
    poly_slab("FloorStorey%d" % si, -0.6, Z_LINES[si] - 0.15, 0.3, "floor")
poly_slab("CeilingSlab", 0.2, Z1 + 0.25, 0.5)


# ---------------------------------------------------------------- rings


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

# ---------------------------------------------------------------- clearance helpers (pedestals, lanterns, pots; 10/11 check)
def footprint(p):
    """2D footprint + height range of an upright part: ("c", (x, y), r) for a post (X = up), ("r", (x, y), u, hu, hv) for a
    block standing up (Y = up); None for anything tilted"""
    (x, y, z), sz = p["pos"], p["size"]
    if abs(p["X"][2]) > 0.99:
        return ("c", (x, y), sz[1] / 2), z - sz[0] / 2, z + sz[0] / 2
    if abs(p["Y"][2]) > 0.99:
        u = norm((p["X"][0], p["X"][1], 0.0))
        return ("r", (x, y), u, sz[0] / 2, sz[2] / 2), z - sz[1] / 2, z + sz[1] / 2
    return None, 0.0, 0.0


def push_out(c, r, fp):
    """penetration of a circle (c, r) into a footprint and the unit direction that frees it (0, None if clear)"""
    if fp[0] == "c":
        dx, dy = c[0] - fp[1][0], c[1] - fp[1][1]
        dd = math.hypot(dx, dy)
        return (r + fp[2] - dd, (dx / dd, dy / dd) if dd > 1e-6 else (0.0, 1.0)) if dd < r + fp[2] else (0.0, None)
    _, (cx, cy), u, hu, hv = fp
    v = (-u[1], u[0])
    lu, lv = (c[0] - cx) * u[0] + (c[1] - cy) * u[1], (c[0] - cx) * v[0] + (c[1] - cy) * v[1]
    qu, qv = max(-hu, min(hu, lu)), max(-hv, min(hv, lv))
    if (qu, qv) != (lu, lv):                              # centre outside the rectangle
        du, dv = lu - qu, lv - qv
        dd = math.hypot(du, dv)
        if dd >= r:
            return 0.0, None
        return r - dd, ((du * u[0] + dv * v[0]) / dd, (du * u[1] + dv * v[1]) / dd)
    pu, pv = hu - abs(lu) + r, hv - abs(lv) + r
    if pu < pv:
        s = 1.0 if lu >= 0 else -1.0
        return pu, (s * u[0], s * u[1])
    s = 1.0 if lv >= 0 else -1.0
    return pv, (s * v[0], s * v[1])


def obstacles(prefixes, z0, z1, walls_too=False):
    out = []
    for p in parts:
        nm = p["name"]
        m = walls_too and re.match(r"(.+)_(C|G|GL|GR|GT)\d+(_\d+)?$", nm)
        if not (nm.startswith(prefixes) or m and m.group(1) in walls):
            continue
        fp, a_, b_ = footprint(p)
        if fp and b_ > z0 + 0.02 and a_ < z1 - 0.02:
            out.append((nm, fp))
    return out


def front_win_x():
    """ground-storey windows on the front: (x centre, half width incl. frame and sill, glass bottom)"""
    return [(wf.at(uc, 0)[0], ww / 2 + 0.1 * ww + 0.08 + 0.5, w0) for (nm, uc, ww, w0, sp, kind, si) in win_list
            if nm == "front" and si == 0]


def lantern_at(k, x):
    """wall lantern at the door's spring height + 0.6; pushed out (+y) of a corner pilaster / tower it would sit in"""
    y = YF + 0.25 + LANT_W / 2 + 0.05
    obs = obstacles(("Pilaster", "Tower"), DSP + 0.6 - LANT_H / 2, DSP + 0.6 + LANT_H / 2)
    for _ in range(40):
        if not any(push_out((x, y), LANT_W / 2 + 0.05, fp)[0] > 0.01 for _, fp in obs):
            break
        y += 0.05
    if y > YF + 0.8:
        print("[house] lantern %d moved %.2f out to clear a pilaster" % (k, y - (YF + 0.75)))
    lc = (x, y, DSP + 0.6)
    g = LANT_W - 0.2
    add("LampGlass%d" % k, (g, LANT_H - 0.1, g), lc, mat="lamp")
    orn_items.append({"type": "lantern", "name": "%s_Lantern%d" % (NAME, k), "pos": list(lc), "w": LANT_W, "hgt": LANT_H,
                      "post": 0.09, "wall_y": YF})


# ---------------------------------------------------------------- pedestals + lanterns
LANT_W, LANT_H = 0.9, 1.15
LANTS = S.get("lanterns")                               # [u, ...] wall lanterns along the front (0..1 like door.u); replaces the pedestal ones
if S.get("pedestals", True):
    for k, sx in enumerate((-1, 1)):
        x = CXD + sx * (DR + GW + 0.75 + 1.0)
        if OFFC or SH:                                  # off-centre door / shop window: skip a pedestal that leaves the wall or hits the window
            fx0, fx1 = sorted((wf.p0[0], wf.at(wf.L, 0)[0]))
            ush = wf.at(SH[0], 0)[0] if SH else None
            if x - 1.0 < fx0 + 1.2 or x + 1.0 > fx1 - 1.2 or (SH and abs(x - ush) < SH[1] / 2 + 0.45 + 0.4 + 1.0):
                print("[house] pedestal %d skipped (no room beside the door)" % k)
                continue
        # a pedestal in front of a ground-floor window is cut down under its sill stone (a low post with a gold ball, as
        # the 2D step posts); the full one (07) stood 4.85 high and hid half the window (08, 12, Flower)
        pz = Z0 + 3.75
        low = [w0 for wx, hw, w0 in front_win_x() if abs(x - wx) < 1.0 + hw]
        if low:
            pz = max(Z0 + 1.2, min(low) - 0.7 - 0.45)
        add("Pedestal%d" % k, (1.8, pz, 2.0), (x, YF + 0.45, pz / 2))
        add("Pedestal%d_Cap" % k, (1.92, 0.35, 2.12), (x, YF + 0.45, pz + 0.175), mat="gold")
        add("Pedestal%d_Foot" % k, (2.0, 0.55, 2.2), (x, YF + 0.45, 0.275), mat="gold")
        if pz > 3.0:
            add("Pedestal%d_Plaque" % k, (0.7, 1.2, 0.1), (x, YF + 1.48, 2.0), mat="gold")
        if low:
            ball("Pedestal%d_Ball" % k, 0.8, (x, YF + 0.45, pz + 0.35 + 0.38))
        if LANTS is None:
            lantern_at(k, x)
for k, u in enumerate(LANTS or []):
    lantern_at(k, wf.at(u * wf.L, 0)[0])

# ---------------------------------------------------------------- awning
AW = S.get("awning")
if AW:
    AW_W, AW_D, AW_DROP, AW_N = AW.get("w", DOOR_W + 2.4), AW.get("d", 2.3), AW.get("drop", 1.2), AW.get("n", 7)
    AW_TOP = AW.get("top", DSP + DR + GW + 0.9)
    if "top" not in AW:                                 # rod + balls stay under a front storey ledge, a front balcony, the cornice
        lim = [(Z1 - 0.25, "cornice")]
        for si in range(1, len(STOREYS)):
            if Z_LINES[si] >= DSP + DR + 0.8:           # the storey ledge runs across the front (see the rings)
                lim.append((Z_LINES[si] - 0.6, "storey ledge %d" % si))
            if any(B["storey"] == si and "front" in [wall_name(n) for n in B["walls"]] for B in S.get("balconies", [])):
                lim.append((Z_LINES[si] - 0.55, "balcony %d" % si))
        zl, why = min(lim)
        if zl < AW_TOP:
            print("[house] awning top %.2f -> %.2f (under the %s)" % (AW_TOP, zl, why))
            AW_TOP = zl
    cols = AW.get("colors", [[250, 205, 72], [255, 243, 212]])
    aw_len = math.hypot(AW_D, AW_DROP)
    aw_n = (0.0, AW_DROP / aw_len, AW_D / aw_len)
    sw = AW_W / AW_N
    AWX = wf.at(AW["u"] * wf.L, 0)[0] if "u" in AW else CXD       # awning centre: the door's unless "u" is given
    for k in range(AW_N):
        x = AWX - AW_W / 2 + sw * (k + 0.5)
        m = "cloth%d" % (k % 2)
        add("Awning_Stripe%d" % k, (sw + 0.01, 0.15, aw_len), (x, YF + AW_D / 2, AW_TOP - AW_DROP / 2), (1.0, 0.0, 0.0), aw_n, m)
        add("Awning_Valance%d" % k, (sw + 0.01, 0.42, 0.12), (x, YF + AW_D + 0.02, AW_TOP - AW_DROP - 0.19), mat=m)
        disk("Awning_Scallop%d" % k, sw * 0.98, 0.14, (x, YF + AW_D + 0.02, AW_TOP - AW_DROP - 0.4), (0.0, 1.0, 0.0), m)
    add("Awning_Rod", (AW_W + 0.4, 0.26, 0.26), (AWX, YF + 0.16, AW_TOP + 0.02), (1.0, 0.0, 0.0), UP, "gold", "Cylinder")
    for k, sx in enumerate((-1, 1)):
        ball("Awning_BallFront%d" % k, 0.42, (AWX + sx * (AW_W / 2 + 0.05), YF + AW_D + 0.05, AW_TOP - AW_DROP))
        ball("Awning_BallTop%d" % k, 0.36, (AWX + sx * (AW_W / 2 + 0.25), YF + 0.16, AW_TOP + 0.02))
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
def clear_pot(i, x, y, r, h):
    """move a pot (outer rim radius r) the shortest way out of walls, pilasters, towers, pedestals, steps, the door and
    earlier pots (the plinth and foot ring may run under it); the spec x, y is the 2D guess (10/11 check: pots sat 0.5-1.2
    studs inside pedestals, pilasters and walls on 11 houses)"""
    obs = obstacles(("Pedestal", "Pilaster", "Step", "Door_FootBlock", "Door_Jamb", "Door_Reveal", "Tower", "Pot"), 0.0, h, True)
    x0, y0, last = x, y, ""
    for _ in range(80):
        pen, dv, nm = max(((*push_out((x, y), r, fp), nm) for nm, fp in obs), key=lambda t: t[0], default=(0.0, None, ""))
        if pen <= 0.02:
            break
        x, y, last = x + dv[0] * (pen + 0.02), y + dv[1] * (pen + 0.02), nm
    else:
        print("[house] WARNING: pot %d still hits %s" % (i, last))
    if math.hypot(x - x0, y - y0) > 0.05:
        print("[house] pot %d moved (%+.2f, %+.2f) -> (%.2f, %.2f) to clear %s" % (i, x - x0, y - y0, x, y, last))
    return x, y


for i, (x, y, d, h) in enumerate(S.get("pots", [])):
    x, y = clear_pot(i, x, y, d / 2 + 0.22, h)
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

# ---------------------------------------------------------------- balconies + window boxes
def edge_box(nm, w, p0, p1, z0, z1, dep, mat="marble", grow=0.0):
    """box along a wall edge p0 -> p1 (xy points): outer face `grow` studs outside the p line, `dep` thick towards the wall"""
    ln = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.02
    mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    k = dep / 2 - grow
    add(nm, (ln, z1 - z0, dep), (mx - w.n[0] * k, my - w.n[1] * k, (z0 + z1) / 2), w.u, UP, mat)


BALC_SEEN = set()
for bi, B in enumerate(S.get("balconies", [])):
    # {"storey": k (1 = the first upper storey), "walls": [names or "@k"], "depth": 1.4, "margin": studs kept free at both
    # ends of a rect wall (default 1.5, or half a tower + 0.1)}: floor slab + gold band under it + marble rail with gold cap
    si = B["storey"]
    if si < 1 or si >= len(STOREYS):
        print("[house] WARNING: balcony storey %s must be 1..%d, skipped" % (si, len(STOREYS) - 1))
        continue
    dd = B.get("depth", 1.4)
    zf = Z_LINES[si]
    zs = zf + 0.4                                         # walking level (above the storey-line gold band)
    Pb = offset_poly(dd)
    for wn0 in B["walls"]:
        nm = wall_name(wn0)
        if nm not in walls:
            continue
        w = walls[nm]
        if P["shape"] == "rect":
            m = B.get("margin", (TW["w"] / 2 + 0.1) if TW else 1.5)
            if w.L - 2 * m < 2.0:
                print("[house] WARNING: balcony on %s too short, skipped" % nm)
                continue
            p0, p1 = w.at(m, 0, dd)[:2], w.at(w.L - m, 0, dd)[:2]
        else:
            i = EDGES.index(nm)
            p0, p1 = Pb[i], Pb[(i + 1) % len(Pb)]
        pre = "Balc%d_%s" % (bi, nm)
        edge_box(pre + "_Slab", w, p0, p1, zf - 0.1, zs, dd, "floor")
        edge_box(pre + "_Band", w, p0, p1, zf - 0.3, zf - 0.1, dd, "gold", 0.08)
        edge_box(pre + "_RailBase", w, p0, p1, zs, zs + 0.25, 0.5, "marble", -0.15)
        edge_box(pre + "_Rail", w, p0, p1, zs + 1.0, zs + 1.2, 0.5, "marble", -0.15)
        edge_box(pre + "_RailCap", w, p0, p1, zs + 1.2, zs + 1.3, 0.6, "gold", -0.1)
        ln = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        nb = max(2, int(ln / 0.7))
        for k in range(nb):
            f = (k + 0.5) / nb
            post("%s_Baluster%d" % (pre, k), 0.3, 0.75, p0[0] + (p1[0] - p0[0]) * f - w.n[0] * 0.4,
                 p0[1] + (p1[1] - p0[1]) * f - w.n[1] * 0.4, zs + 0.25)
        for k, pe in enumerate((p0, p1)):
            px, py = pe[0] - w.n[0] * 0.4, pe[1] - w.n[1] * 0.4
            if (round(px, 2), round(py, 2), zf) in BALC_SEEN:
                continue
            BALC_SEEN.add((round(px, 2), round(py, 2), zf))
            add("%s_Post%d" % (pre, k), (0.6, 1.3, 0.6), (px, py, zs + 0.65), w.u, UP)
            add("%s_PostCap%d" % (pre, k), (0.78, 0.15, 0.78), (px, py, zs + 1.375), w.u, UP, "gold")
            if P["shape"] == "rect":                      # rect plan: a short return rail from the end post back to the wall
                rl = dd - 0.3
                cx_, cy_ = pe[0] - w.n[0] * (dd - rl / 2 - 0.0), pe[1] - w.n[1] * (dd - rl / 2 - 0.0)
                add("%s_Return%d" % (pre, k), (rl, 0.95, 0.3), (cx_, cy_, zs + 0.725), w.n, UP)
                add("%s_ReturnCap%d" % (pre, k), (rl, 0.1, 0.4), (cx_, cy_, zs + 1.25), w.n, UP, "gold")

# window_boxes: [[wall or "all", storey index (0 = ground) or "all"], ...]: marble box + gold rim + soil under each window
WBN = 0
for wn0, sq in S.get("window_boxes", []):
    wl = list(walls) if wn0 == "all" else [wall_name(wn0)]
    for (nm, uc, ww, w0, sp, kind, si) in win_list:
        if nm not in wl or (sq != "all" and si != sq):
            continue
        w = walls[nm]
        bw = ww + 0.6
        zt = w0 - 0.65
        zb_ = max(zt - 0.6, Z_LINES[si] - 0.3)            # not lower than the storey ledge's underside
        pre = "WBox%d_%s" % (WBN, nm)
        WBN += 1
        w.slab(pre + "_Box", uc - bw / 2, uc + bw / 2, zb_, zt, 0.7, 0.7, "marble")
        w.slab(pre + "_Rim", uc - bw / 2 - 0.04, uc + bw / 2 + 0.04, zt - 0.12, zt, 0.78, 0.74, "gold")
        w.slab(pre + "_Foot", uc - bw / 2 - 0.04, uc + bw / 2 + 0.04, zb_, zb_ + 0.1, 0.78, 0.74, "gold")
        w.slab(pre + "_Soil", uc - bw / 2 + 0.15, uc + bw / 2 - 0.15, zt - 0.05, zt + 0.1, 0.5, 0.6, "soil")

# ---------------------------------------------------------------- top
TOP = S.get("top", {"type": "flat", "parapet": "solid", "h": 1.6})
if TOP["type"] == "flat":
    ph = TOP.get("h", 1.6)
    Pp = offset_poly(0.9)
    # parapet posts on the real corners (turn >= 25 deg) and every 5 studs round a curve; a 32-edge round plan used to get
    # a post on every edge with the balusters run into them (10/11 check)
    POST_I, since = [], 0.0
    for i in range(len(Pp)):
        na, nb = walls[EDGES[i - 1]].n, walls[EDGES[i]].n
        turn = math.degrees(math.acos(max(-1.0, min(1.0, na[0] * nb[0] + na[1] * nb[1]))))
        since += math.hypot(Pp[i][0] - Pp[i - 1][0], Pp[i][1] - Pp[i - 1][1]) if i else 0.0
        if turn >= 25.0 or since >= 5.0 or i == 0 and P["shape"] != "round":
            POST_I.append(i)
            since = 0.0
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
                if any(math.hypot(bx - Pp[j][0], by - Pp[j][1]) < 0.85 for j in POST_I):
                    continue                              # no baluster inside a post
                post("Baluster_%s_%d" % (nm, k), 0.32, ph - 0.55, bx, by, ZT + 0.25)
        elif TOP.get("parapet") != "none":                # "none" = no parapet (a hip roof sits on the cornice)
            add("Parapet_%s" % nm, (L, ph, 0.7), (mx - w.n[0] * 0.35, my - w.n[1] * 0.35, ZT + ph / 2), w.u, UP)
            add("ParapetGold_%s" % nm, (L + 0.02, 0.2, 0.8), (mx - w.n[0] * 0.35, my - w.n[1] * 0.35, ZT + ph - 0.1), w.u, UP, "gold")
    for i, (x, y) in enumerate(Pp if TOP.get("parapet") != "none" else []):
        if i not in POST_I:
            continue
        add("ParapetPost%d" % i, (1.1, ph + 0.5, 1.1), (x, y, ZT + (ph + 0.5) / 2))
        add("ParapetPostCap%d" % i, (1.3, 0.25, 1.3), (x, y, ZT + ph + 0.62), mat="gold")
    if not TOP.get("hip"):                                # a hip roof has no walkable deck
        poly_slab("RoofDeck", 0.8, ZT + 0.1, 0.2, "floor")
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
    # ---- roof extras (sub-keys of the flat top)
    HIP = TOP.get("hip")                                  # {"h": rise, "eave": 1.5 overhang, "chimney": [x, y, w, h above the roof]}
    if HIP and P["shape"] != "rect":
        print("[house] WARNING: top.hip needs a rect plan, skipped")
        HIP = None
    if HIP:
        eo = HIP.get("eave", 1.5)
        Wb, Db = max(xs) - min(xs) + 2 * eo, max(ys) - min(ys) + 2 * eo
        hh = HIP["h"]
        Hm = min(Wb, Db) / 2                              # plan run of every face (equal pitch)
        slope = math.hypot(Hm, hh)
        sa, ca = hh / slope, Hm / slope
        # four faces, each = strips (tilted slabs) whose length follows the hip line: full run in the middle, shorter near the ends
        for fi, (nx, ny, Eh, A) in enumerate(((0, 1, Db / 2, Wb / 2), (0, -1, Db / 2, Wb / 2), (1, 0, Wb / 2, Db / 2), (-1, 0, Wb / 2, Db / 2))):
            tt = (-ny, nx, 0.0)
            nrm = (nx * sa, ny * sa, ca)
            M = max(2, int(math.ceil(2 * A / 0.9)))
            dx = 2 * A / M
            for k in range(M):
                s = -A + dx * (k + 0.5)
                lr = Hm - max(0.0, abs(s) - (A - Hm))
                if lr < 0.15:
                    continue
                r = Eh - lr / 2
                pc_ = (nx * r + tt[0] * s - nrm[0] * 0.125, ny * r + tt[1] * s - nrm[1] * 0.125, ZT + hh * lr / (2 * Hm) - nrm[2] * 0.125)
                add("Hip%d_%d" % (fi, k), (dx + 0.02, 0.25, lr / ca), pc_, tt, nrm, "slate")
        rl2 = abs(Wb - Db) / 2
        for ci, (sx_, sy_) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1))):
            c0 = (sx_ * Wb / 2, sy_ * Db / 2, ZT)
            c1 = (sx_ * rl2, 0.0, ZT + hh) if Wb >= Db else (0.0, sy_ * rl2, ZT + hh)
            dv = (c1[0] - c0[0], c1[1] - c0[1], c1[2] - c0[2])
            Xh = norm(dv)
            Yh = norm(vadd(UP, vmul(Xh, -Xh[2])))
            add("HipLine%d" % ci, (math.sqrt(sum(c * c for c in dv)) + 0.2, 0.3, 0.35),
                ((c0[0] + c1[0]) / 2, (c0[1] + c1[1]) / 2, (c0[2] + c1[2]) / 2 + 0.05), Xh, Yh, "gold")
        if rl2 > 0.1:
            add("HipRidge", (2 * rl2 + 0.4, 0.35, 0.4), (0, 0, ZT + hh + 0.05), (1.0, 0.0, 0.0) if Wb >= Db else (0.0, 1.0, 0.0), UP, "gold")
        for ei, (ex, ey) in enumerate(((0, 1), (0, -1), (1, 0), (-1, 0))):                     # gold fascia along the eaves
            alongx = ex == 0
            add("HipEave%d" % ei, ((Wb if alongx else Db) + 0.1, 0.35, 0.35), (ex * Wb / 2, ey * Db / 2, ZT + 0.1),
                (1.0, 0.0, 0.0) if alongx else (0.0, 1.0, 0.0), UP, "gold")
        post("HipFinialBase", 0.55, 0.6, 0.0, 0.0, ZT + hh, "gold")
        ball("HipFinialBall", 0.95, (0.0, 0.0, ZT + hh + 1.05))
        ch = HIP.get("chimney")
        if ch:
            ccx_, ccy_, cw_, chh_ = ch

            def roof_z(px, py):
                return ZT + min(hh, hh / Hm * min(Wb / 2 - abs(px), Db / 2 - abs(py)))
            zlo = min(roof_z(ccx_ + a_ * cw_ / 2, ccy_ + b_ * cw_ / 2) for a_ in (-1, 1) for b_ in (-1, 1)) - 0.3
            ztop = roof_z(ccx_, ccy_) + chh_
            add("Chimney", (cw_, ztop - zlo, cw_), (ccx_, ccy_, (zlo + ztop) / 2))
            add("Chimney_Band", (cw_ + 0.25, 0.25, cw_ + 0.25), (ccx_, ccy_, ztop - 0.8), mat="gold")
            add("Chimney_Cap", (cw_ + 0.5, 0.3, cw_ + 0.5), (ccx_, ccy_, ztop + 0.15), mat="gold")
    PG = TOP.get("pergola")                               # {"w", "d", "h", "columns": 4|6, "x", "y"}: gold columns, marble beams + rafters
    if PG:
        pw_, pd_, ph_ = PG["w"], PG["d"], PG["h"]
        pcx, pcy = PG.get("x", 0.0), PG.get("y", 0.0)
        z0p = ZT + 0.2
        xl = [-pw_ / 2, pw_ / 2] if PG.get("columns", 4) <= 4 else [-pw_ / 2, 0.0, pw_ / 2]
        for k, (a_, b_) in enumerate((a_, b_) for a_ in xl for b_ in (-pd_ / 2, pd_ / 2)):
            post("Pergola_Col%d" % k, 0.55, ph_, pcx + a_, pcy + b_, z0p, "gold")
            post("Pergola_ColBase%d" % k, 0.95, 0.35, pcx + a_, pcy + b_, z0p)
            post("Pergola_ColCap%d" % k, 0.9, 0.3, pcx + a_, pcy + b_, z0p + ph_ - 0.3, "gold")
        for k, b_ in enumerate((-pd_ / 2, pd_ / 2)):
            add("Pergola_BeamX%d" % k, (pw_ + 1.2, 0.45, 0.5), (pcx, pcy + b_, z0p + ph_ + 0.225))
        for k, a_ in enumerate(xl):
            add("Pergola_BeamY%d" % k, (0.5, 0.4, pd_ + 1.2), (pcx + a_, pcy, z0p + ph_ + 0.65))
        nr = int(pw_ / 1.0) + 1
        for k in range(nr):
            add("Pergola_Rafter%d" % k, (0.22, 0.28, pd_ + 1.4), (pcx - pw_ / 2 + pw_ * k / max(1, nr - 1), pcy, z0p + ph_ + 0.99))
    CU = TOP.get("cupola")                                # {"r", "h", "x", "y"}: 6 marble posts + gold ring + small gold dome
    if CU:
        cr, chh_ = CU["r"], CU["h"]
        ccx_, ccy_ = CU.get("x", 0.0), CU.get("y", 0.0)
        z0c = ZT + 0.2
        post("Cupola_Base", 2 * cr + 1.2, 0.4, ccx_, ccy_, z0c)
        post("Cupola_BaseGold", 2 * cr + 1.35, 0.15, ccx_, ccy_, z0c + 0.4, "gold")
        zp = z0c + 0.55
        cpts = [(ccx_ + cr * math.cos(k * math.pi / 3), ccy_ + cr * math.sin(k * math.pi / 3)) for k in range(6)]
        for k, (px, py) in enumerate(cpts):
            post("Cupola_Post%d" % k, 0.5, chh_, px, py, zp)
            post("Cupola_PostCap%d" % k, 0.7, 0.2, px, py, zp + chh_, "gold")
        for k in range(6):
            pa, pb = cpts[k], cpts[(k + 1) % 6]
            dxy = (pb[0] - pa[0], pb[1] - pa[1], 0.0)
            add("Cupola_Ring%d" % k, (math.hypot(dxy[0], dxy[1]) + 0.3, 0.4, 0.5), ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2, zp + chh_ + 0.4),
                norm(dxy), UP, "gold")
        orn_items.append({"type": "dome", "name": NAME + "_CupolaDome", "pos": [ccx_, ccy_, zp + chh_ + 0.6], "R": cr + 0.35,
                          "h": (cr + 0.35) * 1.1, "ribs": 6, "fin": 0.4})
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
    "slate": 'p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(90, 140, 210)',
    "cloth0": 'p.Material = Enum.Material.Fabric; p.MaterialVariant = "HH_Fabric"; p.Color = Color3.fromRGB(%d, %d, %d)' % tuple(cols[0]),
    "cloth1": 'p.Material = Enum.Material.Fabric; p.MaterialVariant = "HH_Fabric"; p.Color = Color3.fromRGB(%d, %d, %d)' % tuple(cols[1]),
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
