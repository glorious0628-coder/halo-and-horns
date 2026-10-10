"""Halo Citadel props layout planner (이미지 생성 1, 2026-10-10; plan docs/design/halo_town_plan_2026-10-09.md, check docs/design/zone_check_halo_2026-10-10.md #6 #11 #46-48 #64).

  luau.exe build/halo_new/halo_terrain_dump.luau > build/halo_new/halo_dump.txt     (halo_terrain.luau with DUMP = true; rows "C,x,z,V,W,mat,tag")
  py tools/halo_layout.py [--dump build/halo_new/halo_dump.txt] [--out docs/design/halo_layout_plan_2026-10-10.json] [--png art/review/world/halo_new/layout_plan.png]

Reads the terrain columns (the same numbers tools/worldkit/halo_terrain.luau writes), places every kind of the plan on FLAT paved/grass tops
(footprint samples within +-FLAT of the centre height, no cliff / water / wall columns), keeps the spawn corridor clear (#46), checks that every
walkable column of the island can be reached from the spawn over the planned bridges (#6) and writes the plan JSON that
tools/worldkit/halo_props.luau embeds (tools/halo_embed_plan.py). Deterministic (fixed seed). Front of every kit model = Roblox -Z;
yaw (deg) is CFrame.Angles(0, rad(yaw), 0): the model front then points to (-sin yaw, -cos yaw) in (x, z).
"""
import argparse
import json
import math
import random
from collections import deque

from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("--dump", default="build/halo_new/halo_dump.txt")
ap.add_argument("--out", default="docs/design/halo_layout_plan_2026-10-10.json")
ap.add_argument("--walls", action="store_true", help="also write the invisible edge-guard runs (416 runs = too many parts; the server water rescue is the plan)")
ap.add_argument("--png", default="art/review/world/halo_new/layout_plan.png")
a = ap.parse_args()

R = 4  # terrain column size
# ---------------------------------------------------------------- terrain grid
COL = {}
for line in open(a.dump, encoding="utf-8"):
    if not line.startswith("C,"):
        continue
    p = line.strip().split(",")
    COL[(round(float(p[1])), round(float(p[2])))] = (float(p[3]), p[4], p[5], p[6])
XS = sorted({k[0] for k in COL})
ZS = sorted({k[1] for k in COL})
X0, Z0 = XS[0], ZS[0]


def col(x, z):
    i = round((x - X0) / R)
    k = round((z - Z0) / R)
    return COL.get((X0 + i * R, Z0 + k * R))


def tagv(x, z):
    c = col(x, z)
    return (c[3], c[0]) if c else ("sea", -6.0)


WALK = ("plaza", "top")  # tops a building / prop may stand on
FLAT = 1.2

# ---------------------------------------------------------------- kinds (footprint w x d (local x, local z), height h; fit sizes of the import)
# Coll: "solid" = normal collision (CanQuery true), "player" = DecorPlayerOnly, "post" = invisible trunk post, "none" = walk-through
KIND = {
    "Gate": dict(w=50.4, d=31.5, h=48.3, coll="gate"),
    "Cathedral": dict(w=69.9, d=70, h=53.5, coll="solid"),
    "Fountain": dict(w=16, d=16, h=12.9, coll="solid"),
    "Tower": dict(w=11.5, d=11.4, h=36, coll="solid"),
    "DomeHouseA": dict(w=12, d=11.2, h=15.1, coll="solid"),
    "DomeHouseB": dict(w=14, d=9.5, h=17.3, coll="solid"),
    "Shop": dict(w=12, d=7.5, h=14.3, coll="solid"),
    "Statue": dict(w=6.7, d=5.5, h=13, coll="player"),
    "ArchBridge": dict(w=21.7, d=30, h=14.9, coll="solid"),  # measured on Halo_ArchBridge_HD_LOD (fit h 30): width 21.7 incl. lantern posts, deck top at 0.59 of the height
    "Stairs": dict(w=20, d=20, h=15.2, coll="solid"),
    "Balustrade": dict(w=8, d=1.64, h=4.5, coll="player"),
    "Lantern": dict(w=1.3, d=1.3, h=7, coll="player"),
    "Planter": dict(w=6, d=5.7, h=5.8, coll="player"),
    "CloudBush": dict(w=5, d=4.9, h=3.7, coll="post"),
    "Topiary": dict(w=3.3, d=3.6, h=8, coll="post"),
    "RoundTree": dict(w=7.9, d=6.8, h=10, coll="post"),
    "PotFlowers": dict(w=3, d=2.8, h=3, coll="none"),
    "BannerPole": dict(w=4, d=2.4, h=12, coll="player"),
}
SOLID = ("Cathedral", "Fountain", "Tower", "DomeHouseA", "DomeHouseB", "Shop", "Statue", "Stairs", "Gate")
P = []  # placements
rng = random.Random(20261010)


def corners(x, z, w, d, yaw):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    pts = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        pts.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return pts


def sat(A, B):
    for poly in (A, B):
        for i in range(4):
            x1, z1 = poly[i]
            x2, z2 = poly[(i + 1) % 4]
            nx, nz = z1 - z2, x2 - x1
            pa = [nx * px + nz * pz for px, pz in A]
            pb = [nx * px + nz * pz for px, pz in B]
            if max(pa) < min(pb) or max(pb) < min(pa):
                return False
    return True


def foot(kind, x, z, yaw, s=1.0, pad=0.0):
    k = KIND[kind]
    return corners(x, z, k["w"] * s + 2 * pad, k["d"] * s + 2 * pad, yaw)


def samples(x, z, w, d, yaw, step=2.0):
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    out = []
    nx, nz = max(2, int(w / step) + 1), max(2, int(d / step) + 1)
    for i in range(nx):
        for j in range(nz):
            lx = -w / 2 + w * i / (nx - 1)
            lz = -d / 2 + d * j / (nz - 1)
            out.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return out


def clear_keep(kind, x, z, yaw, s):
    """#46: nothing solid on the spawn corridor (|x| <= 12 for z -330..-432, r 12 round (0,-420), first ramp foot z > -444 on the axis)."""
    if kind not in SOLID and kind not in ("ArchBridge", "Lantern", "Balustrade", "Planter", "BannerPole", "CloudBush", "Topiary", "RoundTree"):
        return True
    pts = foot(kind, x, z, yaw, s)
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    if min(xs) < 12.5 and max(xs) > -12.5 and max(zs) > -444 and min(zs) < -318 and kind != "Gate":
        return False
    return True


def ok_ground(kind, x, z, yaw, s=1.0, need=WALK, flat=FLAT):
    k = KIND[kind]
    pts = samples(x, z, k["w"] * s, k["d"] * s, yaw)
    ty, v0 = tagv(x, z)
    if ty not in need:
        return False
    for px, pz in pts:
        t, v = tagv(px, pz)
        if t not in need or abs(v - v0) > flat:
            return False
    return True


def free(kind, x, z, yaw, s, pad=0.4, ignore=()):
    fp = foot(kind, x, z, yaw, s, pad)
    for q in P:
        if q["kind"] in ignore or q.get("backdrop"):
            continue
        qk = KIND[q["kind"]]
        if q["kind"] in ("CloudBush",) and kind in ("CloudBush",):
            pass
        if sat(fp, corners(q["x"], q["z"], qk["w"] * q["s"], qk["d"] * q["s"], q["yaw"])):
            return False
    return True


WHY = {}


def put(kind, x, z, yaw, s=1.0, need=WALK, flat=FLAT, pad=0.4, **extra):
    if not ok_ground(kind, x, z, yaw, s, need, flat):
        WHY[(kind, "ground")] = WHY.get((kind, "ground"), 0) + 1
        return None
    if not clear_keep(kind, x, z, yaw, s):
        WHY[(kind, "keep")] = WHY.get((kind, "keep"), 0) + 1
        return None
    if not free(kind, x, z, yaw, s, pad):
        WHY[(kind, "overlap")] = WHY.get((kind, "overlap"), 0) + 1
        return None
    ty, v = tagv(x, z)
    e = dict(kind=kind, x=round(x, 2), z=round(z, 2), y=round(v, 2), yaw=round(yaw % 360, 1), s=round(s, 3), **extra)
    P.append(e)
    return e


def face(dx, dz):
    return math.degrees(math.atan2(-dx, -dz)) % 360


SOUTH = 180.0  # front toward +Z (the gate / Crossroads side)

# ---------------------------------------------------------------- the big pieces
# gate: its front edge stands on z -330 (the bridge end / island edge), centre z -345.8; the invisible Lintel PrimaryPart sits at the front edge (0, 19, -330) so MapBuilder.placeGate does not slide it; the arch opening is ~14 wide at scale 1.2 (Halo_Gate fit h 50.4)
P.append(dict(kind="Gate", x=0, z=-345.8, y=0.2, yaw=SOUTH, s=1.0, lintel=[0, 19, -330], towers=[[-16.15, 22, -1.7], [16.15, 22, -1.7]], tower_size=[18.2, 44, 17.0]))
# cathedral on the far terrace, front toward the road
cat = put("Cathedral", 0, -655.5, SOUTH, 0.9, flat=1.5)  # 63 x 63: the tier-4 ramp ends at z -621 and the terrace at -692
# fountain on the plaza terrace
fnt = put("Fountain", 0, -565, 0, 1.0)
# stairs models on the three axis ramps (the collision is the terrain ramp; the model is only the look)
# stairs model rise = 8.2 studs over a 20 deep run at scale 1 (measured on the LOD mesh): stretch it to the ramp (28 wide, 22 long, rise of that tier)
for zb, yb, rise in ((-444, 0.2, 8.8), (-524, 9.0, 11.0), (-606, 20.0, 13.0)):  # ramps are 30 long now (halo_terrain RampLen)
    P.append(dict(kind="Stairs", x=0, z=zb, y=yb, yaw=SOUTH, s=1.0, sv=[1.4, round(rise / 8.2, 3), 1.5], ramp=True))

# hero statues (face the road axis): tier 1 pairs, one pair on tier 2
for z in (-384, -408, -466, -492):
    for sx in (-1, 1):
        put("Statue", sx * (24 if z > -440 else 28), z, face(-sx, 0), 1.0)

# shops on the plaza terrace: four, facing the fountain axis (bakery / juice / flowers / toys, decor only: 검수 #49 #51)
SHOPKIND = {(-1, -546): "Bakery", (1, -546): "Juice", (-1, -584): "Flower", (1, -584): "Potion"}  # Potion = the real potion merchant (검수 #34); signs = HaloSign* (이미지 개발)
for z in (-546, -584):
    for sx in (-1, 1):
        put("Shop", sx * 44, z, face(-sx, 0), 1.9, shopkind=SHOPKIND[(sx, z)])

# towers: plaza terrace corners and cathedral terrace corners
for sx in (-1, 1):
    for x, z in ((66, -542), (66, -592), (86, -624), (86, -680)):
        put("Tower", sx * x, z, face(-sx, 0), 1.0)

# wing houses, mirrored: A on the canal side, B further out, front toward the spine axis (the hero road side)
HOUSES = [("WA", -392, 106, 150), ("WB", -494, 112, 156), ("WC", -582, 124, 168)]
for name, z, xa, xb in HOUSES:
    for sx in (-1, 1):
        put("DomeHouseA", sx * xa, z, face(-sx, 0), 1.9)  # x1.9: the door (3.2 studs at scale 1) becomes avatar size
        put("DomeHouseB", sx * xb, z, face(-sx, 0), 2.0)

# ---------------------------------------------------------------- bridges
# (name, centre x, centre z, axis "x" = span along x, deck Y at the low / high end)
BR = [("BA", 0, -385, "x", 0.2, 3), ("BB", 0, -492, "x", 9, 12), ("BC", 0, -582, "x", 20, 22), ("BD", 0, -662, "x", 33, 33),
      ("BAB", 130, -442, "z", 3, 12), ("BBC", 150, -544, "z", 12, 22), ("BCD", 150, -620, "z", 22, 33)]
BRIDGES = []


def canal_extent(cx, cz, axis, sx):
    """walk from the centre along the span axis until a top / plaza column; returns (inner, outer) edge coordinates"""
    # for the spine <-> wing bridges the centre x is the canal centre between the spine edge and the wing edge
    return None


def bridge_spots():
    out = []
    for name, bx, bz, ax, y0, y1 in BR:
        if ax == "x":
            for sx in (-1, 1):
                # scan outward from the spine edge: first non-top column after the spine, then the wing's first top column
                z = bz
                xs_ = [x * 1.0 for x in range(0, 200, 2)]
                inside = [x for x in xs_ if tagv(x, z)[0] in WALK or tagv(x, z)[0] in ("stair",)]
                # canal columns = bed / fall / basin between two tops
                prev = None
                edges = []
                for x in xs_:
                    t = tagv(x, z)[0]
                    land = t in WALK
                    if prev is not None and prev != land:
                        edges.append(x)
                    prev = land
                # edges[0] = spine -> canal, edges[1] = canal -> wing
                if len(edges) >= 2:
                    a_, b_ = edges[0], edges[1]
                    out.append(dict(name=name, side=sx, x=sx * (a_ + b_) / 2, z=z, axis="x", span=b_ - a_, y0=y0, y1=y1))
        else:
            for sx in (-1, 1):
                x = sx * bx
                prev = None
                edges = []
                for zz in range(int(bz - 30), int(bz + 30), 2):
                    t = tagv(x, zz)[0]
                    land = t in WALK
                    if prev is not None and prev != land:
                        edges.append(zz)
                    prev = land
                if len(edges) >= 2:
                    a_, b_ = edges[0], edges[1]
                    out.append(dict(name=name, side=sx, x=x, z=(a_ + b_) / 2, axis="z", span=b_ - a_, y0=y0, y1=y1))
    return out


for b in bridge_spots():
    span = b["span"] + 8  # 4 studs of landing each side
    s = span / KIND["ArchBridge"]["d"]
    s = max(0.7, min(1.4, s))
    yaw = 90.0 if b["axis"] == "x" else 0.0  # model span runs along its local X: yaw 0 -> span along x ; yaw 90 -> along z
    yaw = 0.0 if b["axis"] == "x" else 90.0
    # the model: width = local z (deck width), span = local x. The table above stores w=deck width / d=span, so swap for the footprint
    e = dict(kind="ArchBridge", x=round(b["x"], 2), z=round(b["z"], 2), y=round((b["y0"] + b["y1"]) / 2, 2), yaw=yaw, s=round(s, 3),
             name=b["name"] + ("W" if b["side"] < 0 else "E"), span=b["span"], y0=b["y0"], y1=b["y1"], axis=b["axis"])
    P.append(e)
    BRIDGES.append(e)

# ---------------------------------------------------------------- small props
def spine_edge_x(z):
    for zb, hw in ((-330, 38), (-444, 50), (-524, 76), (-606, 100)):
        pass
    t = [(-330, 38), (-444, 50), (-524, 76), (-606, 100)]
    hw = t[0][1]
    for zb, h in t:
        if z <= zb:
            hw = h
    return hw


TIERS = [("T1", -364, -440, 38, 15), ("T2", -450, -520, 50, 19), ("T3", -530, -602, 76, 62), ("T4", -612, -690, 100, 46)]  # name, z start, z end, terrace half-width, paved half-width (halo_terrain PAVEHALF)
# the narrow road (T1, T2): a balustrade line on each paved edge with lantern posts in it, banner poles and statues just outside, garden rows behind
for name, za, zb, hw, rh in TIERS[:2]:
    z = za - 12
    while z > zb:
        for sx in (-1, 1):
            put("Lantern", sx * (rh + 1.8), z, 0, 1.0, pad=0.2)
        z -= 24
    z = za - 4
    while z > zb:
        for sx in (-1, 1):
            put("Balustrade", sx * (rh + 1.8), z, 90, 1.0, pad=0.0)
        z -= 8.2
# plaza + forecourt (T3, T4): balustrade round the terrace edge, lanterns on the forecourt edge
for name, za, zb, hw, rh in TIERS[2:]:
    z = za - 6
    while z > zb:
        for sx in (-1, 1):
            put("Balustrade", sx * (hw - 3.2), z, 90, 1.0, pad=0.0)
        z -= 8.2
    z = za - 14
    while z > zb:
        for sx in (-1, 1):
            put("Lantern", sx * (rh - 2), z, 0, 1.0, pad=0.2)
        z -= 26
for z in (-340 - 30, -404, -466, -498):
    for sx in (-1, 1):
        put("BannerPole", sx * (15 + 6 if z > -440 else 19 + 6), z, face(-sx, 0), 1.0, pad=0.3)
# garden rows on the grass beside the narrow road (cypress rows) and planters at the terrace corners
for name, za, zb, hw, rh in TIERS[:2]:
    z = za - 8
    while z > zb:
        for sx in (-1, 1):
            put("Topiary", sx * (rh + 14), z, 0, 1.0, pad=1.0)
        z -= 12
for name, za, zb, hw, rh in TIERS:
    z = za - 14
    while z > zb:
        for sx in (-1, 1):
            put("Planter", sx * (hw - 9 if rh > 20 else rh + 9), z, 90, 1.0)
        z -= 22
# wing gardens: topiary + trees + bushes + pots on every wing top (random within, off the footprints)
WINGS = [("WA", 60, 188, -434, -336), ("WB", 74, 188, -536, -450), ("WC", 100, 190, -612, -552), ("WD", 124, 190, -692, -628)]
# counts follow the real triangle budget (Planter 4.5k, Topiary 3.5k, RoundTree 5k, CloudBush 1.8k, PotFlowers 3k; Roblox automatic LOD cuts the far ones)
target = {"Topiary": 20, "RoundTree": 16, "CloudBush": 24, "PotFlowers": 24, "Planter": 8}
have = {}
for e in P:
    have[e["kind"]] = have.get(e["kind"], 0) + 1
tries = 0
need_more = {k: v for k, v in target.items()}
while any(need_more.values()) and tries < 60000:
    tries += 1
    kind = rng.choice([k for k, v in need_more.items() if v > 0])
    wname, a0, a1, z0, z1 = rng.choice(WINGS)
    ax = rng.uniform(a0 + 6, a1 - 6)
    z = rng.uniform(z0 + 6, z1 - 6)
    sx = rng.choice((-1, 1))
    s = rng.uniform(0.9, 1.25) if kind in ("Topiary", "RoundTree", "CloudBush") else 1.0
    yaw = rng.uniform(0, 360)
    # keep the bridge landings and the house fronts open
    if put(kind, sx * ax, z, yaw, s, pad=1.5 if kind in ("RoundTree", "Topiary") else 0.6):
        need_more[kind] -= 1
# cliff-edge cloud bushes: along the wing outer edge + the spine edge shoulders
edge_target = 16
tries = 0
while edge_target > 0 and tries < 20000:
    tries += 1
    wname, a0, a1, z0, z1 = rng.choice(WINGS)
    sx = rng.choice((-1, 1))
    side = rng.choice(("out", "n", "s"))
    if side == "out":
        ax, z = a1 - rng.uniform(3, 6), rng.uniform(z0 + 10, z1 - 10)
    elif side == "n":
        ax, z = rng.uniform(a0 + 10, a1 - 10), z1 + rng.uniform(3, 6)
    else:
        ax, z = rng.uniform(a0 + 10, a1 - 10), z0 - rng.uniform(3, 6)
    if put("CloudBush", sx * ax, z, rng.uniform(0, 360), rng.uniform(1.0, 1.4), pad=0.2):
        edge_target -= 1

# ---------------------------------------------------------------- backdrop (beyond the land rect, no collision, nobody can stand there: #64)
BACK = [("Islet", -250, -420, 1.0), ("Islet", 262, -470, 1.2), ("Islet", -238, -600, 0.9), ("Islet", 248, -650, 1.1),
        ("FarArch", -300, -540, 1.0), ("FarArch", 290, -380, 1.1), ("FarArch", 0, -760, 1.4)]
for kind, x, z, s in BACK:
    P.append(dict(kind=kind, x=x, z=z, y=-1.2, yaw=rng.uniform(0, 360), s=s, backdrop=True))


# ---------------------------------------------------------------- gold inlay lines (thin gold Parts laid on the paving, 검수 10/10 ①-b) + medallion spots (Decal later, ①-c)
GOLD = []  # polylines [[x, z], ...] sampled every ~6 studs; the tool raycasts every point
def line(x0, z0, x1, z1, step=6.0):
    n = max(1, int(round(math.hypot(x1 - x0, z1 - z0) / step)))
    return [[round(x0 + (x1 - x0) * i / n, 2), round(z0 + (z1 - z0) * i / n, 2)] for i in range(n + 1)]
for sx in (-1, 1):
    GOLD.append(line(sx * 14.4, -332, sx * 14.4, -431))   # tier 1 road edges
    GOLD.append(line(sx * 18.4, -457, sx * 18.4, -519))   # tier 2 road edges
    GOLD.append(line(sx * 61.5, -531, sx * 61.5, -601))   # plaza edge
    GOLD.append(line(sx * 45.5, -614, sx * 45.5, -688))   # forecourt edge
for r in (17.5, 23.5):                                      # two rings round the fountain (concentric inlay, no rays)
    GOLD.append([[round(r * math.cos(2 * math.pi * i / 48), 2), round(-565 + r * math.sin(2 * math.pi * i / 48), 2)] for i in range(49)])
GOLD.append(line(-45.5, -614, 45.5, -614, 8.0))             # forecourt front edge (broken by the stairs model)
MEDALLIONS = [dict(x=0, z=-352, r=9), dict(x=0, z=-486, r=8), dict(x=0, z=-590, r=7.5), dict(x=-30, z=-640, r=8), dict(x=30, z=-640, r=8)]

# ---------------------------------------------------------------- reachability (#6): BFS over walkable columns from the spawn, bridges and ramps join tiers
def solid_blocked():
    blk = set()
    for e in P:
        if e["kind"] in SOLID and e["kind"] not in ("Stairs", "Gate", "Statue"):
            k = KIND[e["kind"]]
            fp = foot(e["kind"], e["x"], e["z"], e["yaw"], e["s"], 0.5)
            xs = [p[0] for p in fp]
            zs = [p[1] for p in fp]
            for x in range(int(min(xs) // R) * R, int(max(xs)) + R, R):
                for z in range(int(min(zs) // R) * R, int(max(zs)) + R, R):
                    if sat(fp, corners(x + R / 2, z + R / 2, R, R, 0)):
                        blk.add((round((x + R / 2 - X0) / R), round((z + R / 2 - Z0) / R)))
    return blk


def walkable_cells():
    cells = set()
    for (x, z), (v, w, m, t) in COL.items():
        if t in ("plaza", "top", "stair"):
            cells.add((round((x - X0) / R), round((z - Z0) / R)))
    return cells


cells = walkable_cells()
blk = solid_blocked()
bridge_cells = set()
for b in BRIDGES:
    k = KIND["ArchBridge"]
    L = k["d"] * b["s"]
    W = k["w"] * b["s"]
    for t in range(int(-L / 2), int(L / 2) + 1, 2):
        for u in range(int(-W / 2), int(W / 2) + 1, 2):
            if b["axis"] == "x":
                x, z = b["x"] + t, b["z"] + u
            else:
                x, z = b["x"] + u, b["z"] + t
            bridge_cells.add((round((x - X0 - R / 2 * 0) / R), round((z - Z0) / R)))
cells |= bridge_cells
spawn = (round((0 - X0) / R), round((-420 - Z0) / R))
seen = {spawn}
dq = deque([spawn])
while dq:
    c = dq.popleft()
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            n = (c[0] + dx, c[1] + dz)
            if n in cells and n not in blk and n not in seen:
                seen.add(n)
                dq.append(n)
unreach = [c for c in cells if c not in seen and c not in blk]
by_wing = {}
for c in unreach:
    x, z = X0 + c[0] * R, Z0 + c[1] * R
    for wname, a0, a1, z0, z1 in WINGS:
        if a0 <= abs(x) <= a1 and z0 <= z <= z1:
            by_wing[wname + ("W" if x < 0 else "E")] = by_wing.get(wname + ("W" if x < 0 else "E"), 0) + 1


# ---------------------------------------------------------------- edge guard walls (#11): invisible low walls along every walkable-top edge that faces
# water / cliff, except the bridge landings and the stair ramps; merged into straight runs
WALKTAG = ("plaza", "top")
bridge_rects = []
for b in BRIDGES:
    k = KIND["ArchBridge"]
    L, W = k["d"] * b["s"], k["w"] * b["s"]
    if b["axis"] == "x":
        bridge_rects.append((b["x"] - L / 2 - 2, b["x"] + L / 2 + 2, b["z"] - W / 2 - 3, b["z"] + W / 2 + 3))
    else:
        bridge_rects.append((b["x"] - W / 2 - 3, b["x"] + W / 2 + 3, b["z"] - L / 2 - 2, b["z"] + L / 2 + 2))


def near_bridge(x, z):
    return any(r[0] <= x <= r[1] and r[2] <= z <= r[3] for r in bridge_rects)


def isw(x, z):
    return tagv(x, z)[0] in WALKTAG + ("stair",)


segs_h, segs_v = {}, {}  # horizontal (along x) keyed by z edge, vertical (along z) keyed by x edge
for (x, z), (v, w, m, t) in COL.items():
    if t not in WALKTAG:
        continue
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, nz = x + dx * R, z + dz * R
        if isw(nx, nz):
            continue
        ex, ez = x + dx * (R / 2 - 1.0), z + dz * (R / 2 - 1.0)  # the wall line sits 1 stud inside the cell edge
        if near_bridge(ex, ez) or near_bridge(x, z):
            continue
        if dz != 0:
            segs_h.setdefault(round(ez, 1), []).append(x)
        else:
            segs_v.setdefault(round(ex, 1), []).append(z)
WALLS = []


def runs(vals):
    vals = sorted(set(vals))
    out, a0, prev = [], None, None
    for v in vals:
        if a0 is None:
            a0 = prev = v
        elif v - prev <= R + 0.1:
            prev = v
        else:
            out.append((a0, prev))
            a0 = prev = v
    if a0 is not None:
        out.append((a0, prev))
    return out


for ez, xs_ in segs_h.items():
    for a_, b_ in runs(xs_):
        WALLS.append([a_ - R / 2, ez, b_ + R / 2, ez])
for ex, zs_ in segs_v.items():
    for a_, b_ in runs(zs_):
        WALLS.append([ex, a_ - R / 2, ex, b_ + R / 2])
print("edge walls:", len(WALLS), "runs, total length", round(sum(abs(w[2] - w[0]) + abs(w[3] - w[1]) for w in WALLS)))

# ---------------------------------------------------------------- report + files
count = {}
for e in P:
    count[e["kind"]] = count.get(e["kind"], 0) + 1
print("placed:", ", ".join(f"{k}={v}" for k, v in sorted(count.items())))
print("refused:", {f"{k[0]}:{k[1]}": v for k, v in sorted(WHY.items()) if k[0] in ("Tower", "Stairs", "Statue", "Shop", "Lantern", "BannerPole")})
print("bridges:", [(b["name"], b["span"]) for b in BRIDGES])
print(f"walkable columns {len(cells)}, reachable from the spawn {len(seen)}, unreachable {len(unreach)} {by_wing}")
want = {"Statue": 8, "Shop": 4, "Tower": 8, "DomeHouseA": 6, "DomeHouseB": 6, "Stairs": 3}
for k, v in want.items():
    if count.get(k, 0) != v:
        print(f"!! {k}: placed {count.get(k, 0)} of {v}")
json.dump(dict(note="halo_layout.py output; yaw = CFrame.Angles(0,rad(yaw),0), front = kit -Z", placements=P, walls=WALLS if a.walls else [], gold=GOLD, medallions=MEDALLIONS, counts=count,
               unreachable=len(unreach)), open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

# plan picture, 3 px per stud
S = 3
W_, H_ = (XS[-1] - XS[0] + R) * S, (ZS[-1] - ZS[0] + R) * S
img = Image.new("RGB", (W_, H_), (60, 120, 190))
dr = ImageDraw.Draw(img)
TAGC = {"plaza": (235, 228, 205), "top": (130, 175, 110), "stair": (255, 215, 120), "wall": (170, 170, 170), "cliff": (200, 195, 185),
        "bed": (70, 130, 190), "fall": (150, 210, 245), "basin": (120, 200, 235)}
for (x, z), (v, w, m, t) in COL.items():
    c = TAGC.get(t, (60, 120, 190))
    px, pz = (x - X0 - R / 2) * S, (z - Z0 - R / 2) * S
    sh = int(min(40, max(0, v * 1.5)))
    dr.rectangle([px, pz, px + R * S, pz + R * S], fill=tuple(max(0, ch - sh) for ch in c))
KC = {"Gate": (230, 190, 40), "Cathedral": (255, 255, 255), "Fountain": (60, 200, 255), "Tower": (240, 240, 240), "DomeHouseA": (255, 190, 90),
      "DomeHouseB": (255, 140, 60), "Shop": (120, 90, 220), "Statue": (200, 60, 60), "ArchBridge": (160, 100, 40), "Stairs": (255, 120, 180),
      "Balustrade": (150, 150, 150), "Lantern": (255, 240, 0), "Planter": (200, 120, 200), "CloudBush": (255, 255, 255), "Topiary": (20, 90, 30),
      "RoundTree": (20, 130, 40), "PotFlowers": (255, 140, 200), "BannerPole": (50, 90, 240)}
for e in P:
    k = KIND.get(e["kind"])
    if not k or e.get("backdrop"):
        continue
    fp = foot(e["kind"], e["x"], e["z"], e["yaw"], e["s"])
    pts = [((px - X0 - R / 2) * S, (pz - Z0 - R / 2) * S) for px, pz in fp]
    dr.polygon(pts, fill=KC.get(e["kind"], (255, 0, 255)), outline=(0, 0, 0))
for c in unreach:
    px, pz = c[0] * R * S, c[1] * R * S
    dr.rectangle([px, pz, px + R * S, pz + R * S], outline=(255, 0, 0))
# north (more negative z) is up: the gate is at the bottom, the cathedral at the top
img.save(a.png)
print("wrote", a.out, a.png)
