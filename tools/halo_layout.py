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
    "ArchBridge": dict(w=30, d=21.7, h=14.9, coll="solid"),  # 10/10 검수: the span (30) runs along the model's local X, the deck width (21.7) along local Z  # measured on Halo_ArchBridge_HD_LOD (fit h 30): width 21.7 incl. lantern posts, deck top at 0.59 of the height
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


# 10/10 검수 ③: kept empty for the two travel pads (Map.Pads Pad_Halo_SlimeMeadow / Pad_Halo_GoblinWoods, 메인 반영 1): flat tier-1 grass
# beside the hero road, off the spawn corridor, between the statue pairs; nothing is planned on these squares
PADS = [(-24, -357), (24, -357)]
RESERVE = [corners(px, pz, 12, 12, 0) for px, pz in PADS]


def free(kind, x, z, yaw, s, pad=0.4, ignore=()):
    fp = foot(kind, x, z, yaw, s, pad)
    if any(sat(fp, r) for r in RESERVE):
        return False
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

# ---------------------------------------------------------------- A23-112 (사용자 "빛 마을은 비대칭"): the same numbers as tools/worldkit/halo_terrain.luau
def CX(z):
    """S-curved road centre (halo_terrain cx)"""
    if z >= -432:
        return 0.0
    if z >= -582:
        return 34 * math.sin(math.pi * (-432 - z) / 150)
    if z >= -692:
        return -28 * math.sin(math.pi * (-582 - z) / 110)
    return 0.0


TIER_Z = [0, -444, -524, -606]
TIER_H = [0.2, 9, 20, 33]
WAVE = {2: (6, 23, 0), 3: (7, 31, 0), 4: (5, 19, 0)}
RAMPS = {2: [(0, 14), (30, 6)], 3: [(0, 10), (-38, 7)], 4: [(0, 18), (44, 6)]}
PAVEHALF = [(0, 15, 15), (-444, 22, 16), (-524, 54, 68), (-606, 40, 52)]
WINGS = [("WA", -186, -62, -430, -336), ("WB", -170, -46, -540, -452), ("WC", -184, -86, -614, -558), ("WD", -194, -132, -694, -632),
         ("EA", 70, 194, -428, -344), ("EB", 98, 176, -508, -452), ("EC", 106, 196, -628, -530), ("ED", 102, 176, -696, -652)]  # rects before the turn (halo_terrain Ang)


def bnd(i, x, z):
    A, L, ph = WAVE[i]
    return TIER_Z[i - 1] + A * math.sin((x - CX(z)) / L + ph)


def pave_half(z, u):
    h = PAVEHALF[0]
    for t in PAVEHALF[1:]:
        if z <= t[0]:
            h = t
    w = h[1] if u < 0 else h[2]
    if z < -524:
        w += 6 * math.sin(z / 17 + (1.3 if u < 0 else 0.2))
    return w


def near_road(x, z, extra):
    u = x - CX(z)
    return abs(u) < pave_half(z, u) + extra


def face(dx, dz):
    return math.degrees(math.atan2(-dx, -dz)) % 360


def face_to(x, z, tx, tz):
    return face(tx - x, tz - z)


SOUTH = 180.0  # front toward +Z (the gate / Crossroads side)

# ---------------------------------------------------------------- bridges (placed first so the houses / shops keep off the landings)
# (name, side, hint x, z, axis "x" = span along x from the spine, "z" = between two wings of one side, deck Y at both ends)
BR = [("BAW", -1, None, -385, "x", 0.2, 3), ("BAE", 1, None, -400, "x", 0.2, 5), ("BBW", -1, None, -492, "x", 9, 12), ("BBE", 1, None, -490, "x", 9, 15),
      ("BCW", -1, None, -580, "x", 20, 22), ("BCE", 1, None, -575, "x", 20, 26), ("BDW", -1, None, -662, "x", 33, 28), ("BDE", 1, None, -672, "x", 33, 30),
      ("BABW", -1, -170, -444, "z", 3, 12), ("BBCW", -1, -150, -544, "z", 12, 22), ("BCDW", -1, -160, -620, "z", 22, 28),
      ("BABE", 1, 130, -454, "z", 5, 15), ("BBCE", 1, 120, -527, "z", 15, 26), ("BCDE", 1, 170, -640, "z", 26, 30)]
BRIDGES = []


def bridge_spots():
    out = []
    for name, sx, hx, bz, ax, y0, y1 in BR:
        if ax == "x":
            z = bz
            x0 = CX(z)
            prev, edges = None, []
            for k in range(0, 220, 2):
                x = x0 + sx * k
                land = tagv(x, z)[0] in WALK
                if prev is not None and prev != land:
                    edges.append(x)
                prev = land
            if len(edges) >= 2:
                a_, b_ = edges[0], edges[1]
                out.append(dict(name=name, x=(a_ + b_) / 2, z=z, axis="x", span=abs(b_ - a_), y0=y0, y1=y1))
        else:
            prev, edges = None, []
            for zz in range(int(bz + 30), int(bz - 30), -2):
                land = tagv(hx, zz)[0] in WALK
                if prev is not None and prev != land:
                    edges.append(zz)
                prev = land
            if len(edges) >= 2:
                a_, b_ = edges[0], edges[1]
                out.append(dict(name=name, x=hx, z=(a_ + b_) / 2, axis="z", span=abs(b_ - a_), y0=y0, y1=y1))
    return out


for b in bridge_spots():
    span = b["span"] + 8  # 4 studs of landing each side
    s = max(0.7, min(1.4, span / KIND["ArchBridge"]["w"]))
    yaw = 0.0 if b["axis"] == "x" else 90.0
    e = dict(kind="ArchBridge", x=round(b["x"], 2), z=round(b["z"], 2), y=round((b["y0"] + b["y1"]) / 2, 2), yaw=yaw, s=round(s, 3),
             name=b["name"], span=b["span"], y0=b["y0"], y1=b["y1"], axis=b["axis"])
    P.append(e)
    BRIDGES.append(e)

# ---------------------------------------------------------------- the big pieces
P.append(dict(kind="Gate", x=0, z=-345.8, y=0.2, yaw=SOUTH, s=1.0, lintel=[0, 19, -330], towers=[], tower_size=[0, 0, 0]))
# cathedral: the highest tier, off the road to the east, turned toward the road's arrival (south-west)
cat = None
for cz_ in (-655, -652, -658, -650):
    for cx_ in (24, 20, 28, 16):
        cat = put("Cathedral", cx_, cz_, face(-0.18, 1.0), 0.9, flat=1.5)  # a 10 deg turn: a 24 deg turn pushed the 63-stud square over the step and the far end
        if cat:
            break
    if cat:
        break
# fountain on the plaza, a little east of the curved road
fnt = put("Fountain", CX(-566) - 3, -566, 15.0, 1.0)
# stairs models on every ramp (the ramp is the walkable terrain; the model is the look), width / rise from the ramp
STAIRS = []
for i in (2, 3, 4):
    rise = TIER_H[i - 1] - TIER_H[i - 2]
    for ru, half in RAMPS[i]:
        x = CX(TIER_Z[i - 1]) + ru
        z = bnd(i, x, TIER_Z[i - 1])
        e = dict(kind="Stairs", x=round(x, 2), z=round(z, 2), y=TIER_H[i - 2], yaw=0.0, s=1.0, sv=[round(2 * half / 20, 3), round(rise / 8.2, 3), 1.5], ramp=True)
        P.append(e)
        STAIRS.append(e)

# hero statues: single, scattered, each its own offset and side (no pairs), facing the road
for z, side, off in ((-372, -1, 19), (-403, 1, 22), (-468, -1, 27), (-548, 1, 30), (-598, -1, 34), (-640, 1, 58)):
    for dz, do in ((0, 0), (-6, 0), (6, 0), (-12, 0), (12, 0), (0, 6), (-6, 6), (6, 6), (0, -3)):
        x = CX(z + dz) + side * (pave_half(z + dz, side) + off * 0.25 + 3 + do)
        if put("Statue", x, z + dz, face_to(x, z + dz, CX(z + dz), z + dz + 6), 1.0, flat=1.5):
            break

# shops round the plaza, each its own angle; the potion merchant (east) stays in sight of the gate
SHOPKIND = {}
for kindname, z, side, gap, tilt in (("Bakery", -548, -1, 4, 14), ("Juice", -546, 1, 7, -18), ("Flower", -596, -1, 0, 22), ("Potion", -592, 1, 2, -9)):
    x = CX(z) + side * (pave_half(z, side) - 6 + gap)
    for dz, dg in [(0, 0)] + [(d_, g_) for d_ in (-5, 5, -10, 10, -15, 15, -20, 20, -25) for g_ in (2, -4, 8)]:
        x = CX(z + dz) + side * (pave_half(z + dz, side) - 6 + gap + dg)
        yaw = face_to(x, z + dz, CX(z + dz), z + dz) + tilt
        if put("Shop", x, z + dz, yaw, 1.9, flat=1.5, shopkind=kindname):
            break

# towers: different heights, never in pairs
towers = 0
for x, z, s in ((-52, -540, 1.2), (78, -560, 0.85), (-86, -612, 1.0), (96, -650, 1.3), (-150, -600, 0.9), (170, -598, 1.1), (-60, -680, 0.8), (150, -380, 1.15),
                (-170, -470, 0.95), (110, -470, 1.05), (-120, -660, 1.2), (176, -680, 0.9), (-40, -400, 0.85), (60, -440, 1.0)):
    if towers >= 8:
        break
    if put("Tower", x, z, face_to(x, z, CX(z), z) + rng.uniform(-20, 20), s):
        towers += 1

# houses: 12, in clusters of 2-3 on the wings, each its own angle (+-10..25 deg off facing the road), set back unevenly
CLUSTERS = [(-118, -388, 3), (128, -398, 2), (-128, -495, 2), (122, -492, 2), (-146, -584, 1), (148, -582, 2)]
houses = 0
for cxw, czw, n in CLUSTERS:
    placed = 0
    tries = 0
    while placed < n and tries < 400:
        tries += 1
        ang = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(6, 32)
        x, z = cxw + r * math.cos(ang), czw + r * math.sin(ang)
        tilt = rng.choice((-1, 1)) * rng.uniform(10, 25)
        yaw = face_to(x, z, CX(z), z) + tilt
        kind = "DomeHouseA" if (houses % 2 == 0) else "DomeHouseB"
        if put(kind, x, z, yaw, rng.uniform(1.85, 2.05), pad=1.6):
            placed += 1
            houses += 1

# ---------------------------------------------------------------- small props (irregular: no rows, no mirrored pairs)
# lanterns along the road edges, side and spacing random
z = -352.0
while z > -690:
    side = rng.choice((-1, 1))
    x = CX(z) + side * (pave_half(z, side) + 1.6)
    put("Lantern", x, z, 0, 1.0, pad=0.2)
    z -= rng.uniform(13, 24)
# balustrades along the upper side of every wavy step (skipping the ramps) and some pieces along the road edge
for i in (2, 3, 4):
    xs_ = [x * 1.0 for x in range(-110, 112, 2)]
    for x in xs_:
        z = bnd(i, x, TIER_Z[i - 1]) - 5.0
        u = x - CX(z)
        if any(abs(u - ru) < half + 3 for ru, half in RAMPS[i]):
            continue
        if rng.random() < 0.25:
            continue
        if int(x) % 8 != 0:
            continue
        put("Balustrade", x, z, 0, 1.0, pad=0.0)
for z in range(-360, -440, -9):
    if rng.random() < 0.45:
        side = rng.choice((-1, 1))
        put("Balustrade", CX(z) + side * (pave_half(z, side) + 3.2), z, 90, 1.0, pad=0.0)
banners = 0
for x, z in ((-20, -462), (31, -522), (-58, -566), (60, -612), (-30, -500), (46, -470), (-70, -598), (-40, -640), (70, -590)):
    if banners >= 4:
        break
    if put("BannerPole", x, z, face_to(x, z, CX(z), z), 1.0, pad=0.3):
        banners += 1


def scatter(kind, n, centres, spread, smin=0.9, smax=1.25, keep_road=8, pad=0.8):
    done = 0
    tries = 0
    while done < n and tries < n * 80:
        tries += 1
        cxs, czs = rng.choice(centres)
        x, z = cxs + rng.gauss(0, spread), czs + rng.gauss(0, spread)
        if near_road(x, z, keep_road) and z > -700:
            continue
        if put(kind, x, z, rng.uniform(0, 360), rng.uniform(smin, smax), pad=pad):
            done += 1
    return done


# garden clusters: random centres on the spine gardens and every wing
GC = []
for _ in range(60):
    w = rng.choice(WINGS)
    GC.append((rng.uniform(w[1] + 8, w[2] - 8), rng.uniform(w[3] + 8, w[4] - 8)))
for _ in range(30):
    z = rng.uniform(-350, -690)
    side = rng.choice((-1, 1))
    GC.append((CX(z) + side * (pave_half(z, side) + rng.uniform(8, 30)), z))
scatter("Topiary", 70, GC, 6, keep_road=6)
scatter("RoundTree", 32, GC, 8, keep_road=10)
scatter("CloudBush", 100, GC, 7, 0.9, 1.35, keep_road=4)
scatter("PotFlowers", 30, GC, 5, 1.0, 1.0, keep_road=2)
scatter("Planter", 34, GC, 6, 1.0, 1.0, keep_road=3)
# cliff-edge cloud bushes
edge = [(x, z) for (x, z), (v, w, m, t) in COL.items() if t == "top" and any(tagv(x + dx, z + dz)[0] == "cliff" for dx, dz in ((4, 0), (-4, 0), (0, 4), (0, -4)))]
done = 0
for _ in range(4000):
    if done >= 45 or not edge:
        break
    x, z = rng.choice(edge)
    if put("CloudBush", x, z, rng.uniform(0, 360), rng.uniform(1.0, 1.4), pad=0.2):
        done += 1

# ---------------------------------------------------------------- backdrop (beyond the land rect, no collision, nobody can stand there: #64)
BACK = [("Islet", -250, -430, 1.0), ("Islet", 268, -480, 1.25), ("Islet", -232, -610, 0.85), ("Islet", 244, -660, 1.1),
        ("FarArch", -305, -530, 0.9), ("FarArch", 286, -372, 1.15), ("FarArch", 30, -770, 1.4)]
for kind, x, z, s in BACK:
    P.append(dict(kind=kind, x=x, z=z, y=-1.2, yaw=rng.uniform(0, 360), s=s, backdrop=True))

# ---------------------------------------------------------------- gold inlay lines along the curved road edges + rings round the fountain, medallion spots
GOLD = []


def road_edge_poly(z0, z1, side, step=6.0):
    pts = []
    z = z0
    while z > z1:
        u_ = side * (pave_half(z, side) - 0.6)
        x = CX(z) + u_
        if tagv(x, z)[0] == "plaza":
            pts.append([round(x, 2), round(z, 2)])
        elif len(pts) > 1:
            GOLD.append(pts)
            pts = []
        else:
            pts = []
        z -= step
    if len(pts) > 1:
        GOLD.append(pts)


for side in (-1, 1):
    road_edge_poly(-334, -692, side)
fx, fz = (fnt["x"], fnt["z"]) if fnt else (CX(-566), -566)
for r in (17.5, 23.5):
    GOLD.append([[round(fx + r * math.cos(2 * math.pi * i / 48), 2), round(fz + r * math.sin(2 * math.pi * i / 48), 2)] for i in range(49)])
MEDALLIONS = [dict(x=0, z=-396, r=9), dict(x=round(CX(-488), 2), z=-488, r=8)]
if cat:
    MEDALLIONS.append(dict(x=round(cat["x"] - 30, 2), z=-628, r=6))
MEDALLIONS.append(dict(x=round(CX(-650) - 18, 2), z=-650, r=7))

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
    L = k["w"] * b["s"]  # span
    W = k["d"] * b["s"]  # deck width
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
    for wname, x0w, x1w, z0, z1 in WINGS:
        if x0w <= x <= x1w and z0 <= z <= z1:
            by_wing[wname] = by_wing.get(wname, 0) + 1


# ---------------------------------------------------------------- edge guard walls (#11): invisible low walls along every walkable-top edge that faces
# water / cliff, except the bridge landings and the stair ramps; merged into straight runs
WALKTAG = ("plaza", "top")
bridge_rects = []
for b in BRIDGES:
    k = KIND["ArchBridge"]
    L, W = k["w"] * b["s"], k["d"] * b["s"]  # span, deck width
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
want = {"Statue": 6, "Shop": 4, "Tower": 6, "DomeHouseA": 6, "DomeHouseB": 6, "Stairs": 6}
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
