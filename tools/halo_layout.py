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


def free(kind, x, z, yaw, s, pad=0.4, ignore=(), noreserve=False):
    fp = foot(kind, x, z, yaw, s, pad)
    if not noreserve and any(sat(fp, r) for r in RESERVE):
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


def put(kind, x, z, yaw, s=1.0, need=WALK, flat=FLAT, pad=0.4, noreserve=False, why="", **extra):
    if not ok_ground(kind, x, z, yaw, s, need, flat):
        WHY[(kind, "ground")] = WHY.get((kind, "ground"), 0) + 1
        return None
    if not clear_keep(kind, x, z, yaw, s):
        WHY[(kind, "keep")] = WHY.get((kind, "keep"), 0) + 1
        return None
    if not free(kind, x, z, yaw, s, pad, noreserve=noreserve):
        WHY[(kind, "overlap")] = WHY.get((kind, "overlap"), 0) + 1
        return None
    ty, v = tagv(x, z)
    e = dict(kind=kind, x=round(x, 2), z=round(z, 2), y=round(v, 2), yaw=round(yaw % 360, 1), s=round(s, 3), why=why, zone=zone_of(x, z), **extra)
    if kind in ("PotFlowers", "Planter"):  # rule 9: 2-3 flower colours per district, set in clumps (the colour variants swap in by this)
        e["flower_kit"] = flower_pick(e["zone"], x, z, kind)
    P.append(e)
    return e


def face(dx, dz):
    return math.degrees(math.atan2(-dx, -dz)) % 360


SOUTH = 180.0  # front toward +Z (the gate / Crossroads side)

# ---------------------------------------------------------------- A23-112 2nd pass (모동숲 rules, docs/design/acnh_halo_layout_rules_2026-10-10.md):
# the same numbers as tools/worldkit/halo_terrain.luau
CXP = [(-432, 0), (-470, 10), (-510, 32), (-548, 44), (-580, 30), (-614, 0), (-650, -30), (-692, -36)]


def CX(z):
    """S-curved road centre (halo_terrain cx: Hermite through CXP, straight x 0 for z >= -432)"""
    if z >= CXP[0][0]:
        return 0.0
    n = len(CXP)
    if z <= CXP[-1][0]:
        return float(CXP[-1][1])
    i = 0
    while z < CXP[i + 1][0]:
        i += 1

    def slope(k):
        if k == 0:
            return 0.0
        if k == n - 1:
            return (CXP[k][1] - CXP[k - 1][1]) / (CXP[k][0] - CXP[k - 1][0])
        return (CXP[k + 1][1] - CXP[k - 1][1]) / (CXP[k + 1][0] - CXP[k - 1][0])
    za, zb = CXP[i][0], CXP[i + 1][0]
    t = (z - za) / (zb - za)
    d = zb - za
    t2, t3 = t * t, t * t * t
    return (2 * t3 - 3 * t2 + 1) * CXP[i][1] + (t3 - 2 * t2 + t) * slope(i) * d + (-2 * t3 + 3 * t2) * CXP[i + 1][1] + (t3 - t2) * slope(i + 1) * d


TIER_Z = [0, -444, -524, -606]
TIER_H = [0.2, 9, 20, 33]
WAVE = {2: (6, 23, 0.4), 3: (7, 31, 2.1), 4: (5, 19, 4.0)}
RAMPS = {2: [(0, 12)], 3: [(6, 9), (-54, 5)], 4: [(-4, 16)]}
PAVEHALF = [(0, 13, 13), (-444, 21, 17), (-524, 34, 42), (-606, 26, 20)]
WINGS = [("WA", -190, -62, -432, -338), ("WB", -170, -80, -538, -462), ("WC", -152, -110, -604, -570), ("WD", -192, -116, -690, -640),
         ("EA", 62, 172, -424, -352), ("EB", 104, 196, -520, -446), ("EC", 122, 196, -624, -554), ("ED", 96, 152, -694, -638)]  # rects before the turn
WING_H = {"WA": 3, "WB": 12, "WC": 22, "WD": 26, "EA": 5, "EB": 15, "EC": 26, "ED": 30}


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


LOBES = [("WA", -150, -100, -442, -420), ("EB", 150, 196, -446, -430)]  # halo_terrain lobes (same height as their wing)


def wing_of(x, z):
    for name, x0, x1, z0, z1 in WINGS + LOBES:
        if x0 - 6 <= x <= x1 + 6 and z0 - 6 <= z <= z1 + 6:
            return name
    return None


SOUTH = 180.0  # front toward +Z (the gate / Crossroads side)

# ---------------------------------------------------------------- district map (3rd pass, SPEC A23-117 "도시 지을 때 구획 정해서"): every building and
# prop belongs to one district and says why it is there
ZONES = {
    "gate": ("성문 앞 마당", (235, 200, 80)),  # spine tier 1: the gate, the hero road, the two travel pads
    "shops": ("상점 거리", (240, 120, 60)),  # spine tier 2: the four shops along one street, their stalls
    "plaza": ("분수 광장", (90, 190, 240)),  # spine tier 3: the fountain, the meeting place, the guide
    "cathedral": ("대성당 언덕", (250, 250, 250)),  # spine tier 4: the cathedral and its formal garden
    "homes": ("사는 동네", (240, 150, 200)),  # wings WA, WB, EB, EC: the twelve houses with their yards
    "training": ("기사 훈련장", (200, 60, 60)),  # wing EA: statues, dummies, shield rack, Sir Gleam
    "garden": ("꽃 정원·전망대", (120, 220, 120)),  # WC, WD, ED + every cliff edge: flowers, lookouts, photo spots, gather bushes
}
# rule 9 (검수 10/10: not one pot recoloured six ways, A23-96) -> each district gets its own flower-pot KINDS (variants already drawn,
# art/out/s2/halo/variants*/HaloVar*_<Kind>_<L>); the petals keep each model's own colour. Pink / orange / lilac flower kinds are
# still to draw (asked of 이미지 생성 2): until then those districts use the closest drawn kinds.
FLOWER_KITS = {
    "gate": {"PotFlowers": ("HaloVar_PotFlowers_B", "HaloVar4_PotFlowers_C"), "Planter": ("HaloVar4_Planter_A", "HaloVar_Planter_A")},
    "shops": {"PotFlowers": ("HaloVar3_PotFlowers_E", "HaloVar_PotFlowers_A"), "Planter": ("HaloVar3_Planter_E", "HaloVar_Planter_C")},
    "plaza": {"PotFlowers": ("HaloVar4_PotFlowers_D", "HaloVar_PotFlowers_D"), "Planter": ("HaloVar_Planter_B",)},
    "cathedral": {"PotFlowers": ("HaloVar3_PotFlowers_F", "HaloVar_PotFlowers_C"), "Planter": ("HaloVar_Planter_D", "HaloVar4_Planter_D")},
    "homes": {"PotFlowers": ("HaloVar_PotFlowers_A", "HaloVar4_PotFlowers_A"), "Planter": ("HaloVar_Planter_A", "HaloVar3_Planter_E")},
    "training": {"PotFlowers": ("HaloVar4_PotFlowers_C",), "Planter": ("HaloVar4_Planter_D", "HaloVar_Planter_C")},
    "garden": {"PotFlowers": ("HaloVar3_PotFlowers_E", "HaloVar3_PotFlowers_F", "HaloVar_PotFlowers_B", "HaloVar4_PotFlowers_D"), "Planter": ("HaloVar3_Planter_E", "HaloVar_Planter_B")},
}
WILD = (-180, -664, 30)  # the one mixed wildflower slope round the west lookout (rule 9): every garden kind mixed there


def flower_pick(zone, x, z, kind="PotFlowers"):
    kits = FLOWER_KITS.get(zone, FLOWER_KITS["garden"])[kind]
    if math.hypot(x - WILD[0], z - WILD[1]) < WILD[2]:
        kits = FLOWER_KITS["garden"][kind]
        return kits[int(abs(x * 3 + z * 7)) % len(kits)]
    # clumps: the kind follows a coarse grid cell, so neighbours share it (5-12 per clump)
    return kits[(int(math.floor(x / 18)) * 7 + int(math.floor(z / 18)) * 13) % len(kits)]


WING_ZONE = {"WA": "homes", "WB": "homes", "EB": "homes", "EC": "homes", "EA": "training", "WC": "garden", "WD": "garden", "ED": "garden"}


def zone_of(x, z):
    w = wing_of(x, z)
    if w and abs(x - CX(z)) > 40:
        return WING_ZONE[w]
    if z > TIER_Z[1] - 6 * 0 and z > bnd(2, x, z):
        return "gate"
    if z > bnd(3, x, z):
        return "shops"
    if z > bnd(4, x, z):
        return "plaza"
    return "cathedral"


# ---------------------------------------------------------------- reserved spots first (rule 12 + "게임에 가져올 것" 1, 2, 5): nothing big is
# planned on them; the scenes get a lantern + flowers now and a bench later (the kit has no bench yet: 2-3 new kinds to make)
SPOTS = {
    # 20 x 20 empty lawns, one per height band (rule 12): no props at all
    "lawn": [dict(x=-138, z=-372, r=10), dict(x=-40, z=-492, r=9), dict(x=-133, z=-588, r=8)],  # band 4: the exhibition step on ED
    # lookouts on the high ground (rule 12): edge 8 studs kept low, view over the lower tiers to the sea / islets
    "lookout": [dict(x=-180, z=-664, r=7, look=[-250, -610]), dict(x=134, z=-688, r=6, look=[30, -770])],
    # small scenes (rule 12): seat + light + flowers under a tree, facing something to see, 8-20 studs off the road
    "scene": [dict(x=-160, z=-506, r=5, look=[-190, -500], what="cascade pool bench"), dict(x=-140, z=-580, r=4, look=[-60, -560], what="small island tea table"),
              dict(x=160, z=-610, r=4, look=[172, -650], what="cascade side bench"), dict(x=-96, z=-396, r=5, look=[-48, -394], what="canal view bench"),
              dict(x=158, z=-392, r=4, look=[230, -400], what="sea balcony"), dict(x=-90, z=-626, r=4, look=[-160, -610], what="top-tier west edge, sea view"),
              dict(x=118, z=-474, r=4, look=[60, -440], what="angel niche")],
    # photo spots (게임에 가져올 것 2): small gold discs, no lettering, no ray pattern
    "photo": [dict(x=-4, z=-616, r=2), dict(x=-48, z=-394, r=2), dict(x=168, z=-640, r=2), dict(x=-182, z=-664, r=2), dict(x=6, z=-452, r=2), dict(x=140, z=-632, r=2)],
    # gather bushes (게임에 가져올 것 1): 4-6 garden bushes, 2-3 of them give something each day
    "gather": [dict(x=-150, z=-410, r=3), dict(x=124, z=-380, r=3), dict(x=-120, z=-520, r=3), dict(x=180, z=-520, r=3), dict(x=-170, z=-650, r=3), dict(x=110, z=-670, r=3)],
    # the exhibition garden (게임에 가져올 것 5, after the beta): one empty step about 30 x 30
    "exhibit": [dict(x=124, z=-666, r=15)],
    # training ground on EA (Sir Gleam): straw dummies and a shield rack (new props)
    "training": [dict(x=104, z=-372, r=3, what="training dummy"), dict(x=116, z=-382, r=3, what="training dummy"), dict(x=98, z=-392, r=3, what="training dummy"),
                 dict(x=128, z=-366, r=3, what="shield / sword rack"), dict(x=110, z=-400, r=3, what="Sir Gleam stand (NPC)")],
}
RES_SPOTS = []
for kind_, lst in SPOTS.items():
    for sp in lst:
        rr = sp["r"] + (8 if kind_ == "lookout" else 2)
        RES_SPOTS.append(corners(sp["x"], sp["z"], 2 * rr, 2 * rr, 0))
RESERVE.extend(RES_SPOTS)

# ---------------------------------------------------------------- bridges (placed first so the houses / shops keep off the landings)
# (name, side, hint x, z, axis "x" = span along x from the spine, "z" = between two wings of one side, deck Y at both ends)
BR = [("BAW", -1, None, -394, "x", 0.2, 3), ("BAE", 1, None, -366, "x", 0.2, 5), ("BBW", -1, None, -470, "x", 9, 12), ("BBE", 1, None, -498, "x", 9, 15),
      ("BCE", 1, None, -566, "x", 20, 26), ("BBCW", -1, -128, -553, "z", 12, 22), ("BCDW", -1, -136, -622, "z", 22, 26), ("BABE", 1, 132, -437, "z", 5, 15)]
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

# ---------------------------------------------------------------- reachability while placing: a solid that cuts off part of the
# island is taken back (3rd pass: a house / tower on a bridge landing left whole wings unreachable)
_WALK_CELLS = {(round((x - X0) / R), round((z - Z0) / R)) for (x, z), (v, w, m, t) in COL.items() if t in ("plaza", "top", "stair")}


def _unreach_now():
    blk = set()
    for e in P:
        if e["kind"] in SOLID and e["kind"] not in ("Stairs", "Gate", "Statue") and not e.get("backdrop"):
            fp = foot(e["kind"], e["x"], e["z"], e["yaw"], e["s"], 0.5)
            xs = [p_[0] for p_ in fp]
            zs = [p_[1] for p_ in fp]
            for x in range(int(min(xs) // R) * R, int(max(xs)) + R, R):
                for z in range(int(min(zs) // R) * R, int(max(zs)) + R, R):
                    if sat(fp, corners(x + R / 2, z + R / 2, R, R, 0)):
                        blk.add((round((x + R / 2 - X0) / R), round((z + R / 2 - Z0) / R)))
    cells = set(_WALK_CELLS)
    for b in BRIDGES:
        L, W = KIND["ArchBridge"]["w"] * b["s"], KIND["ArchBridge"]["d"] * b["s"]
        for t in range(int(-L / 2), int(L / 2) + 1, 2):
            for u in range(int(-W / 2), int(W / 2) + 1, 2):
                x, z = (b["x"] + t, b["z"] + u) if b["axis"] == "x" else (b["x"] + u, b["z"] + t)
                cells.add((round((x - X0) / R), round((z - Z0) / R)))
    start = (round((0 - X0) / R), round((-420 - Z0) / R))
    seen = {start}
    dq = deque([start])
    while dq:
        c = dq.popleft()
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                n = (c[0] + dx, c[1] + dz)
                if n in cells and n not in blk and n not in seen:
                    seen.add(n)
                    dq.append(n)
    return sum(1 for c in cells if c not in seen and c not in blk)


def put_reach(kind, x, z, yaw, s=1.0, slack=4, **kw):
    before = _unreach_now()
    e = put(kind, x, z, yaw, s, **kw)
    if e and _unreach_now() > before + slack:
        P.remove(e)
        WHY[(kind, "cuts off")] = WHY.get((kind, "cuts off"), 0) + 1
        return None
    return e


# ---------------------------------------------------------------- the big pieces
P.append(dict(kind="Gate", x=0, z=-345.8, y=0.2, yaw=SOUTH, s=1.0, lintel=[0, 19, -330], towers=[], tower_size=[0, 0, 0],
              why="마을 입구: 교차로 다리에서 들어오는 문", zone="gate"))
for b in BRIDGES:
    b["why"] = {"BAW": "서쪽 사는 동네(WA)로 가는 다리", "BAE": "기사 훈련장(EA)으로 가는 다리", "BBW": "상점 거리에서 서쪽 동네(WB)로",
                "BBE": "상점 거리에서 동쪽 동네(EB)로", "BCE": "분수 광장에서 동쪽 동네(EC)로", "BBCW": "WB 동네에서 작은 꽃 섬(WC)으로",
                "BCDW": "꽃 섬(WC)에서 서쪽 전망대 섬(WD)으로", "BABE": "훈련장(EA)에서 동쪽 동네(EB)로"}.get(b["name"], "섬 잇는 다리")
    b["zone"] = zone_of(b["x"], b["z"])
# ---- 대성당 언덕: the cathedral at full size (user 10/10: "빛 성전 어디 갔어?" -> 1.0 or more, the landmark), off the gate axis but its
# dome in sight from the gate; door turned toward the fountain plaza so the dome shows from the middle of town too
cat = None


def margin_bad(kind, x, z, yaw, sc, pad):
    k = KIND[kind]
    return sum(1 for px, pz in samples(x, z, k["w"] * sc + 2 * pad, k["d"] * sc + 2 * pad, yaw, 3.0) if tagv(px, pz)[0] not in WALK + ("stair",))


CAT_TRY = []
for sc_ in (1.0,):
    for tw_ in (6, 12, 0, 18):
        for cx_ in range(-60, -20, 2):
            for cz_ in range(-664, -646, 2):
                yaw_ = SOUTH + tw_  # door to the gate side, turned toward the fountain plaza
                if ok_ground("Cathedral", cx_, cz_, yaw_, sc_, flat=1.5) and free("Cathedral", cx_, cz_, yaw_, sc_):
                    CAT_TRY.append((margin_bad("Cathedral", cx_, cz_, yaw_, sc_, 4) // 6, abs(cx_ + 38), cx_, cz_, sc_, yaw_))
CAT_TRY.sort(key=lambda t: (t[1], t[0]))  # closest to x -38 first: further west it shut a pocket of the top tier behind it
if CAT_TRY:
    _, _, cx_, cz_, sc_, yaw_ = CAT_TRY[0]
    cat = put("Cathedral", cx_, cz_, yaw_, sc_, flat=1.5, why="빛 진영의 대성당: 마을의 목표 지점·랜드마크(문에서 돔이 보임)")
# ---- 분수 광장
fnt = None
for dz in (0, 4, -4, 8, -8):
    fnt = put("Fountain", CX(-566 + dz) - 4, -566 + dz, 15.0, 1.0, why="광장 가운데 모임 자리: 분수(동전 던지기 자리)")
    if fnt:
        break
# stairs models on every ramp (the ramp is the walkable terrain; the model is the look), width / rise from the ramp
STAIRS = []
for i in (2, 3, 4):
    rise = TIER_H[i - 1] - TIER_H[i - 2]
    for ru, half in RAMPS[i]:
        x = CX(TIER_Z[i - 1]) + ru
        z = bnd(i, x, TIER_Z[i - 1])
        e = dict(kind="Stairs", x=round(x, 2), z=round(z, 2), y=TIER_H[i - 2], yaw=0.0, s=1.0, sv=[round(2 * half / 20, 3), round(rise / 8.2, 3), 1.5], ramp=True,
                 why={2: "성문 마당 → 상점 거리 계단", 3: "상점 거리 → 분수 광장 계단", 4: "분수 광장 → 대성당 언덕 계단"}[i] + ("" if ru == RAMPS[i][0][0] else " (옆 지름길)"),
                 zone=zone_of(x, z - 4))
        P.append(e)
        STAIRS.append(e)

# ---- 성문 앞 마당: three hero statues along the road, each its own size / distance (no pairs)
for z, side, off, sc in ((-372, -1, 5, 1.0), (-404, 1, 9, 0.85), (-428, -1, 7, 1.1)):
    for dz, do in ((0, 0), (-6, 0), (6, 0), (-10, 0), (10, 0), (0, 4), (-6, 4), (6, 4)):
        x = CX(z + dz) + side * (pave_half(z + dz, side) + off + do)
        if put("Statue", x, z + dz, face_to(x, z + dz, CX(z + dz), z + dz + 6), sc, flat=1.5, why="영웅상 길: 처음 온 사람에게 빛 진영 영웅을 보여 줌"):
            break
# ---- 기사 훈련장 (EA): statues as models to train by (Sir Gleam stands here; dummies / rack spots reserved)
for x, z, sc in ((122, -392, 1.15), (102, -414, 0.95), (140, -404, 1.0)):
    for dx, dz in ((0, 0), (4, 0), (-4, 0), (0, 4), (0, -4), (6, 6), (-6, -6), (8, -4), (-8, 4), (10, 0), (0, 10), (-10, 0), (0, -10)):
        if put("Statue", x + dx, z + dz, face_to(x + dx, z + dz, 112, -386), sc, flat=1.5, why="기사 훈련장 동상: 훈련하는 기사의 본보기"):
            break

# ---- 상점 거리 fork (4th pass, rule 6): a statue on the grass island in the middle of the street; the road splits round it
for dx, dz in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
    if put("Statue", 19 + dx, -486 + dz, face_to(19, -486, 19, -440), 1.05, flat=1.5, why="상점 거리 갈림길 가운데 동상: 길이 둘로 갈렸다 다시 만나는 표지(규칙 6)"):
        break
# ---- 상점 거리 (tier 2): the four shops along ONE street, staggered sides, each facing the street at its own angle; the potion
# merchant first (in sight from the gate, rule 7)
SHOPKIND = {}
for kindname, z, side, gap, tilt, sc, why in (("Potion", -462, 1, 4, -10, 2.0, "물약 가게: 사냥 나가기 전 마지막 가게(문에서 차양이 보임)"),
                                              ("Bakery", -470, -1, 6, 12, 1.9, "빵집: 마을 사람들 아침 빵"),
                                              ("Juice", -500, 1, 8, -16, 1.75, "주스 가게: 광장 가는 길 목 축이기"),
                                              ("Flower", -506, -1, 5, 18, 1.8, "꽃집: 집 마당·성당 꽃을 대는 곳")):
    for dz, dg in [(0, 0)] + [(d_, g_) for d_ in (-4, 4, -8, 8, -12, 12, -16, 16, -20, 20, -24) for g_ in (2, -3, 6, -6, 10, 14, -9, 18, -12)]:
        x = CX(z + dz) + side * (pave_half(z + dz, side) + 9 + gap + dg)
        yaw = face_to(x, z + dz, CX(z + dz), z + dz) + tilt
        if not ok_ground("Shop", x, z + dz, yaw, sc + 0.6, need=WALK + ("stair",), flat=40):  # walkable ground all round (no pockets behind)
            continue
        if put_reach("Shop", x, z + dz, yaw, sc, flat=1.5, shopkind=kindname, why=why):
            SHOPKIND[kindname] = P[-1]
            break

# ---- 사는 동네: 12 houses in clusters 3-3-2-2 + 2 single houses with a terrace; each house its own angle / set-back,
# one per cluster looks out to the sea or a fall
CLUSTERS = [("WA", -128, -392, 3), ("EB", 150, -486, 3), ("WB", -122, -500, 2), ("EC", 166, -584, 2), ("WB", -146, -520, 1), ("EC", 176, -604, 1),
            ("WA", -166, -362, 1), ("EB", 176, -460, 1), ("WA", -100, -420, 1), ("EC", 150, -560, 1), ("WB", -100, -480, 1), ("EB", 126, -508, 1),
            ("WA", -150, -350, 1), ("EA", 150, -420, 1)]  # the tail only if a house above found no ground (all 12 must stand: each is its own model)
houses = 0
HOUSES = []
for wname, cxw, czw, n in CLUSTERS:
    placed = []
    cands = [(cxw + dx, czw + dz) for dx in range(-46, 47, 3) for dz in range(-46, 47, 3) if 5 <= math.hypot(dx, dz) <= 46]
    rng.shuffle(cands)
    cands.sort(key=lambda c: math.hypot(c[0] - cxw, c[1] - czw) // 8)
    if houses >= 12:
        break
    for x, z in cands:
        if len(placed) >= n or houses >= 12:
            break
        if wing_of(x, z) != wname:
            continue
        sea = len(placed) == n - 1 and n > 1
        yaw = face_to(x, z, CX(z), z) + (180 + rng.uniform(-25, 25) if sea else rng.choice((-1, 1)) * rng.uniform(10, 25))
        if any(abs(((yaw - q["yaw"]) + 180) % 360 - 180) < 10 for q in placed):
            continue
        if any(q["kind"].startswith("DomeHouse") and abs(q["x"] + x) < 14 and abs(q["z"] - z) < 14 for q in P):
            continue
        kind = "DomeHouseA" if (houses % 2 == 0) else "DomeHouseB"
        e = put_reach(kind, x, z, yaw, rng.uniform(1.75, 2.05), flat=1.6, pad=rng.uniform(1.0, 2.5),
                why="주민 집" + (" (바다 보는 창)" if sea else "") + (" — 혼자 있는 집, 작은 테라스" if n == 1 else ""))
        if e:
            placed.append(e)
            HOUSES.append(e)
            houses += 1

# ---- watch towers (망루, 검수 10/10 + A23-117): only where a watch is needed, four of them, three kinds (A watch tower / B open lookout /
# C gold tower, tools/tower_assemble.py --variant), no two of a kind near each other, never between the gate and the cathedral dome
edge_cells = [(x, z) for (x, z), (v, w, m, t) in COL.items() if t == "top" and any(tagv(x + dx, z + dz)[0] == "cliff" for dx, dz in ((8, 0), (-8, 0), (0, 8), (0, -8)))]


def blocks_dome(x, z):
    if not cat:
        return False
    gx, gz = 0.0, -346.0
    a1 = math.atan2(cat["x"] - gx, cat["z"] - gz)
    a2 = math.atan2(x - gx, z - gz)
    return abs(a1 - a2) < math.radians(9) and math.hypot(x - gx, z - gz) < math.hypot(cat["x"] - gx, cat["z"] - gz)


TOWER_SPOTS = [  # (centre x, z, kind, scale, why)
    (CX(-548) + 50, -548, "C", 1.0, "광장 동쪽 굽이 망루: 길이 꺾이는 곳 표지·광장 지킴(규칙 6)"),
    (-176, -676, "A", 1.0, "서쪽 바다 망루: 서쪽 전망대 옆, 바다 쪽 경계"),
    (-176, -398, "B", 1.0, "서쪽 동네 바다 전망 망루: 열린 아래층에서 운하·바다를 봄(동네 사람 쉼터)"),
    (182, -470, "A", 0.95, "동쪽 동네 바다 망루: 동쪽 바다 쪽 경계"),
]
towers = 0
for tx, tz, tkind, s_, why in TOWER_SPOTS:
    cands = sorted(((x, z) for (x, z), (v, w, m, t) in COL.items() if t == "top" and math.hypot(x - tx, z - tz) < 34),
                   key=lambda c: math.hypot(c[0] - tx, c[1] - tz))
    cands = [(tx, tz)] + cands
    for x, z in cands:
        if blocks_dome(x, z) or (cat and math.hypot(cat["x"] - x, cat["z"] - z) < 56):
            continue
        if any(e["kind"] == "Tower" and e.get("tower_kind") == tkind and math.hypot(e["x"] - x, e["z"] - z) < 90 for e in P):
            continue
        if put_reach("Tower", x, z, face_to(x, z, CX(z), z) + rng.uniform(-20, 20), s_, why=why, tower_kind=tkind):
            towers += 1
            break

# ---------------------------------------------------------------- small props: only where a person needs them (A23-117)
VAR = {"Lantern": 15, "Balustrade": 15, "Planter": 15, "BannerPole": 15}


def vs():
    return rng.uniform(0.87, 1.15)


def crowd_ok(kind, x, z, cap=3):
    return sum(1 for e in P if e["kind"] == kind and abs(e["x"] - x) <= 20 and abs(e["z"] - z) <= 20) <= cap


def put_v(kind, x, z, yaw, s, **kw):
    if not crowd_ok(kind, x, z):
        return None
    return put(kind, x, z, yaw, s, **kw)


# lanterns: along the walking route (gate -> shops -> plaza -> cathedral) and at the meeting places only
z = -356.0
side = -1
while z > -688:
    side = -side if rng.random() < 0.8 else side
    x = CX(z) + side * (pave_half(z, side) + 1.6)
    put_v("Lantern", x, z, rng.uniform(-15, 15), vs(), pad=0.2, why={"gate": "성문~계단 길 밤 등불", "shops": "상점 거리 밤 등불", "plaza": "광장 가는 길 등불",
                                                                        "cathedral": "대성당 오르는 길 등불"}.get(zone_of(x, z), "길 등불"))
    z -= rng.uniform(25, 40)
for z, side in ((-548, 1), (-552, -1), (-614, -1), (-650, -1), (-444, 1), (-524, -1), (-606, 1)):
    for dz in (0, 3, -3, 6, -6):
        x = CX(z + dz) + side * (pave_half(z + dz, side) + 1.6)
        if put_v("Lantern", x, z + dz, rng.uniform(-15, 15), vs(), pad=0.2, why="계단 머리·굽이 등불(밤에 길 꺾임 표시)"):
            break
for b in BRIDGES:
    sgn = rng.choice((-1, 1))
    L = KIND["ArchBridge"]["w"] * b["s"] / 2 + 3
    x, z = (b["x"] + sgn * L, b["z"] + 6) if b["axis"] == "x" else (b["x"] + 6, b["z"] + sgn * L)
    put_v("Lantern", x, z, rng.uniform(-15, 15), vs(), pad=0.2, why="다리 머리 등불(밤에 다리 찾기)")
if fnt:  # two lights at the meeting place
    for a_ in (rng.uniform(0, 1), rng.uniform(2.5, 3.6)):
        put_v("Lantern", fnt["x"] + 14 * math.cos(a_), fnt["z"] + 14 * math.sin(a_), rng.uniform(-15, 15), vs(), pad=0.2, why="분수 광장 밤 모임 등불")
# balustrades: on the upper edge of a step next to the road, where people walk by the drop
for i in (2, 3, 4):
    for x in range(-110, 112, 2):
        z = bnd(i, x, TIER_Z[i - 1]) - 5.0
        u = x - CX(z)
        if any(abs(u - ru) < half + 3 for ru, half in RAMPS[i]) or abs(u) > pave_half(z, u) + 16:
            continue
        if rng.random() < 0.4 or x % 8 != 0:
            continue
        put_v("Balustrade", x, z, rng.uniform(-8, 8), rng.uniform(0.9, 1.1), pad=0.0, why="단 턱 난간: 길가 떨어짐 막기")
# banners: the gate (faction sign), the shop street (market day), the cathedral
for zone_, zr, why in (("gate", (-352, -372), "성문 깃발: 빛 진영 마을 표시"), ("shops", (-470, -510), "상점 거리 깃발: 장날"), ("cathedral", (-620, -660), "대성당 깃발")):
    for _ in range(60):
        z = rng.uniform(*zr)
        side = rng.choice((-1, 1))
        x = CX(z) + side * (pave_half(z, side) + rng.uniform(3, 9))
        if put("BannerPole", x, z, face_to(x, z, CX(z), z) + rng.uniform(-15, 15), rng.uniform(0.9, 1.1), pad=0.3, why=why):
            break
# gate forecourt edge beds (검수 10/10: the front of the gate photo was one third bare paving): low flower beds along both road
# edges, irregular, out of the spawn corridor (|x| > 13), off the travel pads
gate_beds = []
for _ in range(400):
    if len(gate_beds) >= 9:
        break
    z = rng.uniform(-360, -438)
    side = rng.choice((-1, 1))
    x = CX(z) + side * (pave_half(z, side) + rng.uniform(1.5, 8.0))
    if abs(x) < 13.5 or any(math.hypot(b[0] - x, b[1] - z) < 7 for b in gate_beds):
        continue
    kind_ = rng.choice(("Planter", "Planter", "PotFlowers"))
    if put_v(kind_, x, z, face_to(x, z, CX(z), z) + rng.uniform(-25, 25), vs(), pad=0.5, why="성문 길 화단: 들어오는 길 꾸밈(흩어 심음)"):
        gate_beds.append((x, z))
# shop fronts: a pot / planter beside each door (the stall / cart / crate comes as a new reason prop)
SHOP_STALL = {"Bakery": "bread basket stand", "Juice": "fruit crate stall", "Flower": "flower cart", "Potion": "bottle crates + sign"}
SPOTS["stall"] = []
for kindname, e in SHOPKIND.items():
    yaw = math.radians(e["yaw"])
    fx, fz = -math.sin(yaw), -math.cos(yaw)
    rx, rz = math.cos(yaw), -math.sin(yaw)
    d = 7.5 * e["s"] / 2 + 3
    for sgn, kind_ in ((1, "PotFlowers"), (-1, "Planter")):
        put(kind_, e["x"] + fx * d + rx * sgn * 7, e["z"] + fz * d + rz * sgn * 7, e["yaw"] + rng.uniform(-10, 10), vs(), pad=0.2,
            why={"Flower": "꽃집 앞 꽃 화분(파는 꽃)", "Bakery": "빵집 문 옆 화분", "Juice": "주스 가게 문 옆 화분", "Potion": "물약 가게 약초 화분"}[kindname])
    SPOTS["stall"].append(dict(x=round(e["x"] + fx * d - rx * 10, 1), z=round(e["z"] + fz * d - rz * 10, 1), r=2.5, what=SHOP_STALL[kindname], shop=kindname))
# house yards: flowers by the door, a clothes line / small garden spot per cluster
SPOTS["yard"] = []
for e in HOUSES:
    yaw = math.radians(e["yaw"])
    fx, fz = -math.sin(yaw), -math.cos(yaw)
    rx, rz = math.cos(yaw), -math.sin(yaw)
    d = 11 * e["s"] / 2 + 3
    sgn = rng.choice((-1, 1))
    put(rng.choice(("PotFlowers", "Planter")), e["x"] + fx * d + rx * sgn * 6, e["z"] + fz * d + rz * sgn * 6, e["yaw"] + rng.uniform(-15, 15), vs(), pad=0.2,
        why="집 마당 화분")
    if rng.random() < 0.55:
        SPOTS["yard"].append(dict(x=round(e["x"] - fx * 2 + rx * -sgn * 13, 1), z=round(e["z"] - fz * 2 + rz * -sgn * 13, 1), r=3,
                                  what=rng.choice(("clothes line", "vegetable bed + watering can", "wood pile + bench"))))
# cathedral formal garden: a few clipped trees beside the approach (one side more than the other)
if cat:
    for _ in range(40):
        a_ = rng.uniform(0, 2 * math.pi)
        r_ = rng.uniform(42, 52)
        x, z = cat["x"] + r_ * math.cos(a_), cat["z"] + r_ * math.sin(a_)
        if zone_of(x, z) == "cathedral" and not near_road(x, z, 3):
            put_v("Topiary", x, z, rng.uniform(0, 360), vs(), pad=0.6, why="대성당 정원 다듬은 나무")


def tree_group(cx_, cz_, n, why):
    got = 0
    for _ in range(n * 30):
        if got >= n:
            break
        a_ = rng.uniform(0, 2 * math.pi)
        r_ = rng.uniform(2, 9)
        if put("RoundTree", cx_ + r_ * math.cos(a_), cz_ + r_ * math.sin(a_), rng.uniform(0, 360), rng.uniform(0.85, 1.25), pad=0.4, why=why):
            got += 1
    if not got:
        return 0
    for _ in range(12):
        a_ = rng.uniform(0, 2 * math.pi)
        r_ = rng.uniform(8, 13)
        k_ = rng.choice(("CloudBush", "CloudBush", "PotFlowers"))
        put_v(k_, cx_ + r_ * math.cos(a_), cz_ + r_ * math.sin(a_), rng.uniform(0, 360), vs(), pad=0.3, why="나무 무리 밑 꽃·덤불(3겹 심기)")
    return got


# tree groups: island edges and cliff feet only (A23-117), >= 16 apart, never on the road side of a bend
GROUPS = []
for x, z in rng.sample(edge_cells, min(1500, len(edge_cells))):
    if len(GROUPS) >= 22:
        break
    if near_road(x, z, 10) or any(math.hypot(g[0] - x, g[1] - z) < 18 for g in GROUPS):
        continue
    # step 6 studs inland from the edge
    best = None
    for dx, dz in ((6, 0), (-6, 0), (0, 6), (0, -6)):
        if tagv(x + dx, z + dz)[0] == "top" and tagv(x - dx, z - dz)[0] != "top":
            best = (x + dx, z + dz)
    if not best:
        continue
    zn = zone_of(*best)
    why = {"garden": "꽃 정원 숲", "homes": "동네 가장자리 그늘 숲", "training": "훈련장 바람막이 나무", "cathedral": "대성당 언덕 가장자리 숲"}.get(zn, "섬 가장자리 숲")
    if tree_group(best[0], best[1], rng.choice((3, 3, 4, 5)), why):
        GROUPS.append(best)
# cliff-edge cloud bushes (island edges: the densest part, A23-76)
done = 0
for _ in range(5000):
    if done >= 60 or not edge_cells:
        break
    x, z = rng.choice(edge_cells)
    if tagv(x, z)[0] != "top" or any(e["kind"] == "CloudBush" and math.hypot(e["x"] - x, e["z"] - z) < rng.uniform(8, 16) for e in P):
        continue
    if put_v("CloudBush", x, z, rng.uniform(0, 360), rng.uniform(0.95, 1.4), pad=0.2, why="절벽 가장자리 덤불(가장자리 채우기·떨어짐 막는 느낌)"):
        done += 1
# gather bushes (게임에 가져올 것 1): the reserved spots get their bush now
for sp in SPOTS["gather"]:
    put("CloudBush", sp["x"], sp["z"], rng.uniform(0, 360), rng.uniform(1.1, 1.3), pad=0.1, noreserve=True, why="채집 덤불: 매일 숨은 꽃·재료")
# flower garden islands: pots and beds on the garden wings
for _ in range(400):
    w = rng.choice([w_ for w_ in WINGS if WING_ZONE[w_[0]] == "garden"])
    x, z = rng.uniform(w[1] + 4, w[2] - 4), rng.uniform(w[3] + 4, w[4] - 4)
    put_v(rng.choice(("PotFlowers", "Planter")), x, z, rng.uniform(0, 360), vs(), pad=0.6, why="꽃 정원 꽃")
# small scenes: a lantern and flowers now (the bench comes with the new bench models)
for sp in SPOTS["scene"]:
    a_ = math.atan2(sp["look"][1] - sp["z"], sp["look"][0] - sp["x"])
    put("Lantern", sp["x"] - 3 * math.cos(a_) + 2 * math.sin(a_), sp["z"] - 3 * math.sin(a_) - 2 * math.cos(a_), rng.uniform(-15, 15), vs(), pad=0.1, noreserve=True,
        why="작은 장면 불빛: " + sp["what"])
    put("PotFlowers", sp["x"] - 2 * math.sin(a_), sp["z"] + 2 * math.cos(a_), rng.uniform(0, 360), vs(), pad=0.1, noreserve=True, why="작은 장면 꽃: " + sp["what"])

# ---------------------------------------------------------------- backdrop (beyond the land rect, no collision, nobody can stand there: #64)
BACK = [("Islet", -250, -430, 1.0), ("Islet", 268, -480, 1.25), ("Islet", -232, -610, 0.85), ("Islet", 244, -660, 1.1),
        ("FarArch", -305, -530, 0.9), ("FarArch", 286, -372, 1.15), ("FarArch", 30, -770, 1.4)]
for kind, x, z, s in BACK:
    P.append(dict(kind=kind, x=x, z=z, y=-1.2, yaw=rng.uniform(0, 360), s=s, backdrop=True, why="먼 바다 배경(전망대에서 보는 섬·아치)", zone="sea"))

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
MEDALLIONS = [dict(x=0, z=-396, r=9), dict(x=round(CX(-488), 2), z=-488, r=7)]
if cat:
    MEDALLIONS.append(dict(x=round(CX(-640) + 6, 2), z=-640, r=6))

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
print("refused:", {f"{k[0]}:{k[1]}": v for k, v in sorted(WHY.items()) if k[0] in ("Tower", "Stairs", "Statue", "Shop", "Lantern", "BannerPole", "DomeHouseA", "DomeHouseB", "Cathedral")})
print("bridges:", [(b["name"], b["span"]) for b in BRIDGES])
print(f"walkable columns {len(cells)}, reachable from the spawn {len(seen)}, unreachable {len(unreach)} {by_wing}")
print("   unreachable at:", sorted({(X0 + c[0] * R, Z0 + c[1] * R) for c in unreach})[:20])
want = {"Statue": 7, "Shop": 4, "Tower": 4, "DomeHouseA": 6, "DomeHouseB": 6, "Stairs": 4, "Cathedral": 1, "Fountain": 1}
for k, v in want.items():
    if count.get(k, 0) != v:
        print(f"!! {k}: placed {count.get(k, 0)} of {v}")
json.dump(dict(note="halo_layout.py output; yaw = CFrame.Angles(0,rad(yaw),0), front = kit -Z; why = the reason it stands there, zone = its district (A23-117)",
               zones={k: v[0] for k, v in ZONES.items()}, placements=P, walls=WALLS if a.walls else [], gold=GOLD, medallions=MEDALLIONS, counts=count, spots=SPOTS,
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
    if e.get("sv"):
        fp = corners(e["x"], e["z"], k["w"] * e["sv"][0], k["d"], e["yaw"])
    pts = [((px - X0 - R / 2) * S, (pz - Z0 - R / 2) * S) for px, pz in fp]
    dr.polygon(pts, fill=KC.get(e["kind"], (255, 0, 255)), outline=(0, 0, 0))
SPC = {"training": (200, 60, 60), "stall": (255, 140, 0), "yard": (255, 105, 180), "lawn": (150, 255, 150), "lookout": (255, 255, 255), "scene": (255, 120, 0), "photo": (255, 215, 0), "gather": (180, 0, 200), "exhibit": (0, 220, 220)}
for kind_, lst in SPOTS.items():
    for sp in lst:
        px, pz = (sp["x"] - X0) * S, (sp["z"] - Z0) * S
        rr = sp["r"] * S
        dr.ellipse([px - rr, pz - rr, px + rr, pz + rr], outline=SPC[kind_], width=3)
for c in unreach:
    px, pz = c[0] * R * S, c[1] * R * S
    dr.rectangle([px, pz, px + R * S, pz + R * S], outline=(255, 0, 0))
# north (more negative z) is up: the gate is at the bottom, the cathedral at the top
img.save(a.png)
# district map: every walkable column tinted by its district, buildings outlined, legend (3rd pass, A23-117)
zimg = Image.new("RGB", (W_, H_), (60, 120, 190))
zd = ImageDraw.Draw(zimg)
for (x, z), (v, w, m, t) in COL.items():
    px, pz = (x - X0 - R / 2) * S, (z - Z0 - R / 2) * S
    if t in ("plaza", "top", "stair", "wall"):
        c = ZONES[zone_of(x, z)][1]
    else:
        c = TAGC.get(t, (60, 120, 190))
    zd.rectangle([px, pz, px + R * S, pz + R * S], fill=c)
for e in P:
    k = KIND.get(e["kind"])
    if not k or e.get("backdrop") or e["kind"] not in ("Cathedral", "Fountain", "Tower", "DomeHouseA", "DomeHouseB", "Shop", "Statue", "ArchBridge", "Stairs", "Gate"):
        continue
    fp = foot(e["kind"], e["x"], e["z"], e["yaw"], e["s"])
    zd.polygon([((px - X0 - R / 2) * S, (pz - Z0 - R / 2) * S) for px, pz in fp], outline=(0, 0, 0), width=2)
ly = 10
for key, (label, c) in ZONES.items():
    zd.rectangle([10, ly, 30, ly + 16], fill=c, outline=(0, 0, 0))
    zd.text((36, ly + 2), key, fill=(0, 0, 0))
    ly += 22
zimg.save(a.png.replace(".png", "_zones.png"))
print("wrote", a.out, a.png)
