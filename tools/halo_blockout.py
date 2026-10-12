"""halo_blockout.py (이미지 생성 1, 2026-10-11, SPEC A23-121 3단계 '회색 상자'): plan v2 -> one WorldKit script.

Reads docs/design/halo_plan_v2_2026-10-11.json and rasterizes it on a 4-stud grid:
  * land height per cell = its district's Y (ramps for y_to districts), land outside every district takes the nearest
    district's height; under each building footprint the ground is flattened to the building's ground_y (Terrain floor:
    the code only counts Terrain / Bridge_* as ground)
  * roads: the road's own height profile (heights at its points, linear in between) -> ramps; cells steeper than 24 deg
    are marked as stairs (Slate) so the photos show where real stairs must go
  * the stream: a channel 2 below its own falling profile, filled with water; pools; the sea outside the land
  * the underside: per cell a rock depth (cone from the sea ring's outer rim + hashed stalactites) -> data "und"
Then writes build/wk/halo_blockout_apply.lua = tools/worldkit/halo_blockout.luau with the data filled in.
usage: py tools/halo_blockout.py [--mode apply|terrain|remove|plan] [--offset X,Z]   (terrain: Terrain only, HaloV2 kept)
"""
import argparse
import json
import math
import os
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json")
TEMPLATE = os.path.join(ROOT, "tools", "worldkit", "halo_blockout.luau")
OUT = os.path.join(ROOT, "build", "wk", "halo_blockout_apply.lua")

CELL = 4
X0, X1 = -212, 212  # set from the plan's land in main() (③ 3차: the town grew 1.5x); north edge Z0 stays at the gate
Z0, Z1 = -324, -712  # north edge (gate side) .. south edge
EDGE = 32  # grid margin round the land: the 16-stud sea ring + its 16-stud rim (2차 10/11)
HOFF = 20  # stored height = round(y) + HOFF
ALPH = "".join(chr(c) for c in range(48, 48 + 80) if chr(c) not in "\\\"'`[]")  # safe chars
# material codes
M = dict(sea="s", grass="g", dirt="d", road1="c", road2="b", road3="p", stair="t", water="w", rock="r", sand="n", limestone="l")
SLOPES = {  # y -> y_to along this line (stage-1 coordinates; main() grows them like the plan). Since the 10/11 review the plan
    # carries its own district "slope" lines (FINAL coordinates) and these are only the fallback
    "market": ((12, -450), (112, -470)),
    "garden_homes": ((-96, -612), (-170, -672)),
    "cliff_homes": ((96, -540), (166, -630)),
}
DIST_MAT = {"training": "sand", "arrival": "grass"}  # 2차 10/11 검수: training was dirt (GE_Ground reads near black in C2c)
PAVED_R = dict(fountain=40, spawn=14)  # paved circle radii: round the plan's fountain pool and the spawn (0, -420)
APRON_D, APRON_RAMP = 8, 12  # level doorstep in front of every door, then a ramp back to the district slope (studs)
APRON_SIDE = 8  # review 10/11: sideways blend width of the doorstep (its sides were steps)
PAINT_IN = CELL  # 디자인 검수 10/11: road / yard / plaza terrain paint stops one cell inside the parts
WALL_MIN = 8.0  # 5단계 10/12: only steps of 8+ (the tiers: castle plateau, cathedral hill, cliff, flower terraces) get a wall;
# 4..8 steps are plain grass banks (walls on every district border read as a white maze from above). Inside a terrace
# district (cathedral_steps: the flower terraces beside the cathedral stairs) every step > FACE_DH gets its wall
WALL_TOL = 2.5  # 5단계 10/12: retaining-wall lines are the step edges straightened to this tolerance (studs)
WALL_T = 8.0  # wall thickness, centred on the line (covers the zigzag + the one-cell terrain slope)
WALL_MAXLEN = 24.0  # longest single wall piece (studs)
WALL_OVER = 0.6  # pieces overlap this much (no hairline gaps at the joints)
FACE_DH = 4.0  # 디자인 검수 10/11: only steps higher than 4 are rock faces (Limestone, light cream); lower ones stay grass slopes
PAVED_SINK = 1  # 2차 10/11 검수: the Terrain under the plaza disc parts sits 1 lower (it poked through the 0.5 disc); the disc
# height stays (tools/skeleton_ground.py adds D.plaza_sink back inside the discs)
ROAD_SINK = 2  # 5단계 10/12: Terrain under the road parts this much lower (skeleton_ground G() adds it back); 2 not 1:
# the drawn surface lands up to 1 above the planned height (voxel occupancy rounding), 1 left grass at the plate tops
BEACH_Z, BEACH_W = -400, 4  # sand on the north shore (z > -400) up to 4 cells from the sea
CLIFF_Z = -760  # rock lip on the south shore
SEA_R = 4  # sea ring width in cells (16 studs) round the coast (2차 10/11: was 5; the rim beyond it is RIM_W cells)
OUT_P1, OUT_P2 = 0.42, 0.3  # 5단계 10/12 ④: outcrop chance next to the rim / next to an outcrop (2-cell lumps)
RIM_RAG = (4, 26)  # ragged extra depth under the rim (studs, slow wave)
RIM_DRIP_P, RIM_DRIP = 0.14, (14, 40)  # drips hanging from the rim's bottom
RIM_OUT_D = (12, 30)  # outcrop depth under its own top
RING_DOWN = -18  # 5단계 10/12: the ring's rock bottom (the Luau RIM_DOWN; was -30 with the 24-deep water)
RIM_W = 4  # rock rim cells outside the water: 2 cells showed see-through holes at distance (terrain LOD) -> 4 (16 studs)
# pointed floating-rock underside (10/11 검수; 2차 10/11 17:10: the cone capped at 70 left a flat bottom with an even comb of
# short spikes -> longer toward the middle, a few big spikes + medium + small ones at uneven lengths and spacing)
UND_CENTER = 170  # 디자인 검수 10/12 ④: was 105 (from the side a flat slab + one spike; now an inverted cone)
# base depth in studs at the farthest-from-edge cell: UND_CENTER * dn ** UND_POW (dn = edge distance / max)
UND_POW = 0.75  # was 0.9: deeper right inside the rim
UND_WOB = 0.22  # low-frequency wobble of the base (+-)
UND_JIT = 0.12  # per-cell shake
UND_BIG = dict(n=6, min_dn=0.35, gap=90, L=(50, 110), R=(22, 36))  # a few big spikes (studs)
UND_MED = dict(n=22, min_dn=0.12, gap=34, L=(16, 42), R=(9, 16))
UND_STAL_P = 0.05  # small: a cell is a stalactite when its hash is below this ...
UND_STAL_MIN_D = 12  # ... and it is farther than this (studs) from the edge
UND_STAL_ADD = (5, 16)  # small stalactite adds 5..16 studs; the 4 neighbours get UND_STAL_NB of that
UND_STAL_NB = 0.35
UND_UNIT = 4  # 10/12: was 3 (cap 216 -> 288 for the deeper cone); one ALPH char = 3 studs of depth (the Luau reads D.und_unit)
UND_CAP = 72 * UND_UNIT  # hard cap (studs), ALPH has 74 chars


def hash01(r, c, seed):
    """deterministic integer hash of a cell -> 0..1 (no random module)"""
    n = ((r + 1) * 73856093) ^ ((c + 1) * 19349663) ^ ((seed + 1) * 83492791)
    n &= 0xFFFFFFFF
    n ^= n >> 13
    n = (n * 0x5BD1E995) & 0xFFFFFFFF
    n ^= n >> 15
    n = (n * 0x27D4EB2D) & 0xFFFFFFFF
    n ^= n >> 16
    return n / 4294967296.0


def underside(active, rows, cols):
    """UND[r][c] = rock depth in studs under every active cell (0 for inactive cells). Edge distance = chamfer distance
    (orthogonal 1, diagonal 1.4142 cells) from the nearest inactive cell / the grid border; a cell next to the edge is 0.5 cell
    from it."""
    import heapq
    dist = [[math.inf] * cols for _ in range(rows)]
    pq = []
    for r in range(rows):
        for c in range(cols):
            if not active[r][c]:
                dist[r][c] = 0.0
                pq.append((0.0, r, c))
            elif r in (0, rows - 1) or c in (0, cols - 1):
                dist[r][c] = 1.0  # the grid border counts as an edge
                pq.append((1.0, r, c))
    heapq.heapify(pq)
    while pq:
        dd, r, c = heapq.heappop(pq)
        if dd > dist[r][c]:
            continue
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                rr, cc = r + dr, c + dc
                if (dr or dc) and 0 <= rr < rows and 0 <= cc < cols:
                    nd = dd + (1.4142 if dr and dc else 1.0)
                    if nd < dist[rr][cc]:
                        dist[rr][cc] = nd
                        heapq.heappush(pq, (nd, rr, cc))
    dmax = max((dist[r][c] for r in range(rows) for c in range(cols) if active[r][c]), default=1.0) or 1.0
    ph = [hash01(0, 0, 40 + i) * 6.2832 for i in range(3)]
    und = [[0.0] * cols for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            if not active[r][c]:
                continue
            dn = dist[r][c] / dmax
            x, z = c * CELL, -r * CELL
            wob = (math.sin(x / 53.0 + ph[0]) + math.sin(z / 41.0 + ph[1]) + math.sin((x + z) / 67.0 + ph[2])) / 3.0
            und[r][c] = UND_CENTER * dn ** UND_POW * (1.0 + UND_WOB * wob) * (1.0 + UND_JIT * (2.0 * hash01(r, c, 1) - 1.0))
    # big and medium spikes: candidates in hash order, kept apart by `gap`, pointed cones of radius R adding up to L
    cand = sorted(((hash01(r, c, 7), r, c) for r in range(rows) for c in range(cols) if active[r][c]))
    spikes, counts = [], []
    for k, spec in enumerate((UND_BIG, UND_MED)):
        got = []
        for _, r, c in cand:
            if len(got) >= spec["n"]:
                break
            if dist[r][c] / dmax < spec["min_dn"]:
                continue
            if any(math.hypot((r - r2) * CELL, (c - c2) * CELL) < spec["gap"] for r2, c2, _, _ in spikes):
                continue
            L = spec["L"][0] + (spec["L"][1] - spec["L"][0]) * hash01(r, c, 11 + k)
            R = spec["R"][0] + (spec["R"][1] - spec["R"][0]) * hash01(r, c, 13 + k)
            R = min(R, dist[r][c] * CELL)  # never wider than the rock above it
            got.append((r, c, L, R))
            spikes.append((r, c, L, R))
        counts.append(len(got))
    for r0, c0, L, R in spikes:
        n = int(R // CELL) + 1
        for r in range(r0 - n, r0 + n + 1):
            for c in range(c0 - n, c0 + n + 1):
                if 0 <= r < rows and 0 <= c < cols and active[r][c]:
                    t = math.hypot((r - r0) * CELL, (c - c0) * CELL) / max(R, 1.0)
                    if t < 1.0:
                        und[r][c] += L * (1.0 - t) ** 1.6
    extra = [[0.0] * cols for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            if active[r][c] and hash01(r, c, 2) < UND_STAL_P and (dist[r][c] - 0.5) * CELL > UND_STAL_MIN_D:
                add = UND_STAL_ADD[0] + (UND_STAL_ADD[1] - UND_STAL_ADD[0]) * hash01(r, c, 3)
                extra[r][c] += add
                for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    rr, cc = r + dr, c + dc
                    if 0 <= rr < rows and 0 <= cc < cols and active[rr][cc]:
                        extra[rr][cc] += add * UND_STAL_NB
    for r in range(rows):
        for c in range(cols):
            if active[r][c]:
                und[r][c] = max(0.0, min(UND_CAP, und[r][c] + extra[r][c]))
    print(f"[blockout] underside spikes big {counts[0]} medium {counts[1]}, dmax {dmax * CELL:.0f} studs")
    return und


def inside(pt, poly):
    x, z = pt
    c = False
    for i in range(len(poly)):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % len(poly)]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def seg_t(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / max(dx * dx + dz * dz, 1e-9)))
    q = (a[0] + t * dx, a[1] + t * dz)
    return t, math.hypot(p[0] - q[0], p[1] - q[1])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="apply")
    ap.add_argument("--offset", default="0,0")
    a = ap.parse_args()
    plan = json.load(open(PLAN, encoding="utf-8"))
    land = [tuple(p) for p in plan["land"]]
    dists = plan["districts"]
    global X0, X1, Z1
    X0 = int(math.floor((min(p[0] for p in land) - EDGE) / CELL)) * CELL
    X1 = int(math.ceil((max(p[0] for p in land) + EDGE) / CELL)) * CELL
    Z1 = int(math.floor((min(p[1] for p in land) - EDGE) / CELL)) * CELL
    g = plan["frame"].get("grow")
    if g:
        def grow(x, z):
            if abs(x) > g["core_x"]:
                x = math.copysign(g["core_x"] + (abs(x) - g["core_x"]) * g["kx"], x)
            if z < g["core_z"]:
                z = g["core_z"] + (z - g["core_z"]) * g["kz"]
            return x, z
        for k in list(SLOPES):
            SLOPES[k] = tuple(grow(*q) for q in SLOPES[k])
    for d in dists:
        if d.get("slope"):
            SLOPES[d["id"]] = tuple(tuple(q) for q in d["slope"])
    roads_by_id = {r["id"]: r for r in plan["roads"]}

    def road_y(rd, p):
        """height on a road with its own profile 'ys' at the centre-line point nearest p"""
        pts = rd["pts"]
        best = None
        for i in range(len(pts) - 1):
            t, dd = seg_t(p, pts[i], pts[i + 1])
            if best is None or dd < best[0]:
                best = (dd, rd["ys"][i] + (rd["ys"][i + 1] - rd["ys"][i]) * t)
        return best[1]
    cols = (X1 - X0) // CELL
    rows = (Z0 - Z1) // CELL
    H = [[None] * cols for _ in range(rows)]
    MAT = [["sea"] * cols for _ in range(rows)]
    DID = [[None] * cols for _ in range(rows)]

    def cxz(r, c):
        return X0 + c * CELL + CELL / 2, Z0 - r * CELL - CELL / 2

    def dist_y(d, p):
        # review 10/11: real tiers (cliff village 18 / 22) and the terrace hill face (each cell = the height of the nearest
        # point of its stair, so the legs can not be cut by walking up the grass)
        for tr in d.get("tiers", []):
            if inside(p, [tuple(v) for v in tr["poly"]]):
                return tr["y"]
        if d.get("terrace"):
            return road_y(roads_by_id[d["terrace"]], p)
        if d.get("y_to") is None:
            return d["y"]
        s0, s1 = SLOPES[d["id"]]
        t, _ = seg_t(p, s0, s1)
        return d["y"] + (d["y_to"] - d["y"]) * t

    q = deque()
    for r in range(rows):
        for c in range(cols):
            p = cxz(r, c)
            if not inside(p, land):
                continue
            MAT[r][c] = "grass"
            for d in dists:
                if inside(p, [tuple(v) for v in d["poly"]]):
                    H[r][c] = dist_y(d, p)
                    DID[r][c] = d["id"]
                    MAT[r][c] = DIST_MAT.get(d["id"], "grass")
                    q.append((r, c))
                    break
    # land outside the districts: nearest district height (grass strips between districts)
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            rr, cc = r + dr, c + dc
            if 0 <= rr < rows and 0 <= cc < cols and MAT[rr][cc] != "sea" and H[rr][cc] is None:
                H[rr][cc] = H[r][c]
                q.append((rr, cc))
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] != "sea" and H[r][c] is None:
                H[r][c] = 0

    def ground_at(p):
        c = int((p[0] - X0) // CELL)
        r = int((Z0 - p[1]) // CELL)
        if 0 <= r < rows and 0 <= c < cols and H[r][c] is not None:
            return H[r][c]
        return 0

    # building pads: flatten under each footprint (+1 cell) to its ground_y
    PAD = set()
    INFP = set()  # cells whose centre is inside a footprint (the gate passage excepted)
    for b in plan["buildings"]:
        fp = [tuple(p) for p in b["footprint"]]
        xs = [p[0] for p in fp]
        zs = [p[1] for p in fp]
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if min(xs) - 6 <= x <= max(xs) + 6 and min(zs) - 6 <= z <= max(zs) + 6:
                    # 골격 다듬기 10/11: margin from the WALLS (was corner points only, so the slope reached the wall and the
                    # 4-stud voxels lifted the floor inside by up to 4 on sloped districts)
                    infp = inside((x, z), fp)
                    if infp or min(seg_t((x, z), fp[i], fp[(i + 1) % len(fp)])[1] for i in range(len(fp))) < 5:
                        if MAT[r][c] != "sea":
                            H[r][c] = b["ground_y"]
                            PAD.add((r, c))
                            if infp and b["kind"] != "Gate":
                                INFP.add((r, c))
    # 골격 다듬기 10/11: in sloped districts (market 4->8, garden 12->16, cliff 18->22) the ground in front of a door rose up to
    # 4 above the sill. A level doorstep apron (door width + 6, APRON_D deep) at ground_y, then a ramp back to the slope
    apron = 0
    for b in plan["buildings"]:
        if b["kind"] == "Gate":
            continue
        ux, uz = b["door_dir"]
        ax, az = b["door_at"]
        half = b["door_size"][0] / 2 + 3
        for r in range(rows):
            for c in range(cols):
                if MAT[r][c] == "sea" or H[r][c] is None or (r, c) in PAD:
                    continue
                x, z = cxz(r, c)
                u = (x - ax) * ux + (z - az) * uz
                v = abs(-(x - ax) * uz + (z - az) * ux)
                # review 10/11: blend sideways too (the apron's sides were 3-4 stud steps): a soft edge APRON_SIDE wide
                side = half + (u - APRON_D) * 0.5 * (u > APRON_D)
                if 0 <= u <= APRON_D + APRON_RAMP and v <= side + APRON_SIDE:
                    t_u = 0.0 if u <= APRON_D else (u - APRON_D) / APRON_RAMP
                    t = max(t_u, min(1.0, max(0.0, (v - side) / APRON_SIDE)))
                    if t <= 0.0:
                        H[r][c] = b["ground_y"]
                        PAD.add((r, c))
                    else:
                        H[r][c] = b["ground_y"] + (H[r][c] - b["ground_y"]) * t
                    apron += 1
    print(f"[blockout] door aprons: {apron} cells")
    base = [row[:] for row in H]
    RSINK = set()  # 5단계 10/12: cells under the road parts (sunk ROAD_SINK at the end, see below)

    # roads: own height profile, painted, ramps; stairs where steeper than 24 deg
    grade_mat = {1: "road1", 2: "road2", 3: "road3"}
    stairs = 0
    for rd in sorted(plan["roads"], key=lambda r: -r["grade"]):  # grade 1 painted last (on top)
        pts = [tuple(p) for p in rd["pts"]]
        prof = [ground_at(p) if not rd.get("ys") or rd["ys"][k] is None else rd["ys"][k] for k, p in enumerate(pts)]  # ys: None = ground
        if rd["id"].startswith("door_"):
            prof[0] = prof[1] = ground_at(pts[0])
        half = rd["w"] / 2
        for r in range(rows):
            for c in range(cols):
                p = cxz(r, c)
                if MAT[r][c] == "sea" or (r, c) in INFP:
                    continue  # review 10/11: a road (door spurs included) never repaints the floor inside a footprint
                best = None
                for i in range(len(pts) - 1):
                    t, dd = seg_t(p, pts[i], pts[i + 1])
                    if dd <= half and (best is None or dd < best[0]):
                        best = (dd, i, t)
                if best is None:
                    continue
                _, i, t = best
                y = prof[i] + (prof[i + 1] - prof[i]) * t
                seg_len = math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
                slope = math.degrees(math.atan2(abs(prof[i + 1] - prof[i]), max(seg_len, 1e-6)))
                H[r][c] = y
                RSINK.add((r, c))
                if best[0] > half - PAINT_IN:
                    continue  # 디자인 검수 10/11: the paint stays one cell inside the parts (it bled white round them)
                if slope > 24:
                    MAT[r][c] = "stair"
                    stairs += 1
                else:
                    MAT[r][c] = grade_mat[rd["grade"]]

    # the stream: falling profile from the spring to the sea, channel 2 below, water in it
    w = plan["water"]
    st = [tuple(p) for p in w["stream"]]
    sw = w["stream_w"]
    sprof = []
    lo = 99
    for p in st:
        y = min(base_y for base_y in [ground_at(p)])
        lo = min(lo, y)
        sprof.append(lo)
    sprof[-1] = -1.2
    water_cells = 0
    for r in range(rows):
        for c in range(cols):
            p = cxz(r, c)
            if MAT[r][c] == "sea":
                continue
            for i in range(len(st) - 1):
                t, dd = seg_t(p, st[i], st[i + 1])
                if dd <= (sw[i] + (sw[i + 1] - sw[i]) * t) / 2:
                    y = sprof[i] + (sprof[i + 1] - sprof[i]) * t
                    H[r][c] = y - 1.6  # water surface = y - 0.4 (stored as bed; the script fills 1.2 water on top)
                    MAT[r][c] = "water"
                    water_cells += 1
                    break
    for pool in w["pools"]:
        if pool["id"] == "fountain":
            continue
        for r in range(rows):
            for c in range(cols):
                p = cxz(r, c)
                if math.hypot(p[0] - pool["at"][0], p[1] - pool["at"][1]) <= pool["r"]:
                    H[r][c] = pool["y"] - 1.6
                    MAT[r][c] = "water"

    # 10/11 검수 (③ 사진 05-06 "거의 잔디"): paved circles (white marble + gold lines = road1) round the fountain and the
    # spawn so the square reads as a square at once; water and stairs inside keep their own look
    for y in plan.get("yards", []):
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if math.hypot(x - y["at"][0], z - y["at"][1]) <= y["r"] - PAINT_IN and MAT[r][c] not in ("sea", "water", "stair"):
                    MAT[r][c] = "road2"
    fpool = next(p for p in plan["water"]["pools"] if p["id"] == "fountain")
    PAVED = [(fpool["at"][0], fpool["at"][1], PAVED_R["fountain"]), (0, -420, PAVED_R["spawn"])]
    for (px, pz, pr) in PAVED:
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if math.hypot(x - px, z - pz) <= pr and MAT[r][c] not in ("sea", "water", "stair"):
                    if math.hypot(x - px, z - pz) <= pr - PAINT_IN:
                        MAT[r][c] = "road1"
                    if H[r][c] is not None:
                        H[r][c] -= PAVED_SINK  # the sink keeps the full radius (tools/skeleton_ground G() tests the same cells)
                    RSINK.discard((r, c))
    # shore: distance to the sea in cells (4-neighbour BFS)
    DS = [[None] * cols for _ in range(rows)]
    q = deque()
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] == "sea":
                DS[r][c] = 0
                q.append((r, c))
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            rr, cc = r + dr, c + dc
            if 0 <= rr < rows and 0 <= cc < cols and DS[rr][cc] is None:
                DS[rr][cc] = DS[r][c] + 1
                q.append((rr, cc))
    beach = cliff = 0
    for r in range(rows):
        for c in range(cols):
            x, z = cxz(r, c)
            d = DS[r][c]
            if MAT[r][c] in ("sea", "water", "stair") or (r, c) in PAD or d is None:
                continue
            # sandy beach on the bridge side (north shore, low land, not the gate): slopes into the sea
            if z > BEACH_Z and abs(x) > 30 and H[r][c] <= 4 and d <= BEACH_W and not MAT[r][c].startswith("road"):
                H[r][c] = min(H[r][c], -2.0 + (d - 1) * 1.0)  # 1 stud per cell: -2 (shallow), -1, 0, 1
                MAT[r][c] = "sand"
                beach += 1
            # the back (south) is a cliff coast: a rock lip on the top edge
            elif z < CLIFF_Z and d == 1 and H[r][c] >= 8:
                MAT[r][c] = "rock"
                cliff += 1
    print(f"[blockout] paved circles {len(PAVED)}, beach cells {beach}, cliff lip cells {cliff}")
    # sea depth tiers (10/11: the shallow -20 sand bed showed through the clear water as a square slab from above, so the
    # sea is deep and dark; only a sand shelf off the north beach and a ledge at the cliff feet)
    DL = [[None] * cols for _ in range(rows)]
    q = deque()
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] != "sea":
                DL[r][c] = 0
                q.append((r, c))
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            rr, cc = r + dr, c + dc
            if 0 <= rr < rows and 0 <= cc < cols and DL[rr][cc] is None:
                DL[rr][cc] = DL[r][c] + 1
                q.append((rr, cc))
    # 10/11 검수 ③ 2차 (passed, "떠 있는 섬 그대로"): the sea is a ring SEA_R cells wide round the coast, a rock rim on its
    # outer edge holds the water, beyond it nothing (the islands float in the sky like the other zones); the base under the
    # island + ring follows the outline (stage 5 shapes it into a pointed floating-rock underside). The ring narrows to
    # nothing toward the box's north edge where the bridge lands on the entry neck.
    SEA_TIER = [[4] * cols for _ in range(rows)]
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] == "sea" and DL[r][c] is not None:
                x, z = cxz(r, c)
                ring = min(SEA_R, int((-326 - z) // CELL))
                if ring == 0 or DL[r][c] >= ring + RIM_W:
                    SEA_TIER[r][c] = 4
                elif DL[r][c] >= ring:  # 2차: the rim is RIM_W cells wide so no water face shows from the side
                    SEA_TIER[r][c] = 3
                elif z > BEACH_Z and abs(x) > 24 and DL[r][c] <= 3:
                    SEA_TIER[r][c] = 1
                elif DL[r][c] <= 1:
                    SEA_TIER[r][c] = 2
                else:
                    SEA_TIER[r][c] = 0
    # 5단계 10/12 ④ (디자인 검수: from the side the rim was one dark, thick, straight band): rock outcrops (tier 5) stick out
    # of the rim's outer face below its top, in lumps of 1-2 cells (clustered hash), the Luau gives them a lower, uneven top
    outc = 0
    for layer, (seed, p_) in enumerate(((21, OUT_P1), (22, OUT_P2))):
        want = 3 if layer == 0 else 5
        pick = []
        for r in range(rows):
            for c in range(cols):
                if SEA_TIER[r][c] != 4 or MAT[r][c] != "sea" or Z0 - (r + 0.5) * CELL > -340:
                    continue  # the entry neck (north edge) stays open for the bridge
                if any(0 <= r + dr < rows and 0 <= c + dc < cols and SEA_TIER[r + dr][c + dc] == want
                       for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1))) and hash01(r // 2, c // 2, seed) < p_:
                    pick.append((r, c))
        for r, c in pick:
            SEA_TIER[r][c] = 5
            outc += 1
    print(f"[blockout] rim outcrops {outc} cells")

    # walking times (③ 3차 target: gate -> cathedral ~30 s, spawn -> any home <= 45 s at Config.Player.WalkSpeed): Dijkstra on the grid,
    # 8 neighbours, blocked by sea / water (bridges excepted) / building footprints (the gate passage excepted) and by steps
    # steeper than 1 stud per stud
    import heapq
    blocked = [[MAT[r][c] in ("sea", "water") for c in range(cols)] for r in range(rows)]
    for br in plan["bridges"]:
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if math.hypot(x - br["at"][0], z - br["at"][1]) <= br["len"] / 2 + 3:
                    blocked[r][c] = False
    for b in plan["buildings"]:
        fp = [tuple(p) for p in b["footprint"]]
        xs, zs = [p[0] for p in fp], [p[1] for p in fp]
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if min(xs) <= x <= max(xs) and min(zs) <= z <= max(zs) and inside((x, z), fp):
                    if not (b["kind"] == "Gate" and abs(x - b["x"]) < b["door_size"][0] / 2):
                        blocked[r][c] = True

    # roads with rails (the cathedral switchback, 결정 1): the cells just outside the band are balustrades, so the walk can not
    # step from one leg's flower terrace to the next; the road ends and any other road crossing the rail line stay open
    on_road = set()
    for rd in plan["roads"]:
        pts = [tuple(p) for p in rd["pts"]]
        for r in range(rows):
            for c in range(cols):
                if any(seg_t(cxz(r, c), pts[i], pts[i + 1])[1] <= rd["w"] / 2 for i in range(len(pts) - 1)):
                    on_road.add((r, c))
    railed = 0
    for rd in plan["roads"]:
        if not rd.get("rails"):
            continue
        pts = [tuple(p) for p in rd["pts"]]
        half = rd["w"] / 2
        for r in range(rows):
            for c in range(cols):
                p = cxz(r, c)
                if (r, c) in on_road or blocked[r][c]:
                    continue
                dd = min(seg_t(p, pts[i], pts[i + 1])[1] for i in range(len(pts) - 1))
                if dd <= half + CELL and min(math.hypot(p[0] - pts[0][0], p[1] - pts[0][1]),
                                             math.hypot(p[0] - pts[-1][0], p[1] - pts[-1][1])) > half + CELL:
                    blocked[r][c] = True
                    railed += 1
    print(f"[walk] rail cells {railed}")

    def cell_of(x, z):
        return int((Z0 - z) // CELL), int((x - X0) // CELL)

    def walk_from(x, z):
        D = [[math.inf] * cols for _ in range(rows)]
        r0, c0 = cell_of(x, z)
        D[r0][c0] = 0.0
        pq = [(0.0, r0, c0)]
        while pq:
            dd, r, c = heapq.heappop(pq)
            if dd > D[r][c]:
                continue
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    rr, cc = r + dr, c + dc
                    if (dr or dc) and 0 <= rr < rows and 0 <= cc < cols and not blocked[rr][cc]:
                        if dr and dc and (blocked[r][cc] or blocked[rr][c]):
                            continue  # no corner cutting through a rail / wall line
                        step = CELL * (1.4142 if dr and dc else 1.0)
                        if abs(H[rr][cc] - H[r][c]) > step:
                            continue
                        nd = dd + math.hypot(step, H[rr][cc] - H[r][c])
                        if nd < D[rr][cc]:
                            D[rr][cc] = nd
                            heapq.heappush(pq, (nd, rr, cc))
        return D

    def at_door(D, b):
        x, z = b["door_at"][0] + b["door_dir"][0] * 3, b["door_at"][1] + b["door_dir"][1] * 3
        r, c = cell_of(x, z)
        best = math.inf
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if 0 <= r + dr < rows and 0 <= c + dc < cols:
                    best = min(best, D[r + dr][c + dc])
        return best / speed

    speed = float(plan.get("walk_speed") or 16)  # 검수 결정 1: Config.Player.WalkSpeed (20), was a hard-coded 16
    if os.environ.get("HALO_DUMP"):  # debug: the walk grid for path checks (build/wk/blockout_grid.json)
        with open(os.path.join(ROOT, "build", "wk", "blockout_grid.json"), "w") as f:
            json.dump(dict(x0=X0, z0=Z0, cell=CELL, H=H, blocked=blocked, mat=MAT), f)
    from_gate = walk_from(0, -346)
    from_spawn = walk_from(0, -416)
    walk = {}
    for b in plan["buildings"]:
        if b["kind"] == "Gate":
            continue
        walk[b["id"]] = dict(from_spawn_s=round(at_door(from_spawn, b), 1), from_gate_s=round(at_door(from_gate, b), 1))
    homes = {k: v for k, v in walk.items() if k.startswith("House")}
    worst = max(homes.items(), key=lambda kv: kv[1]["from_spawn_s"])
    print(f"[walk] gate -> cathedral {walk['Cathedral']['from_gate_s']} s (target ~30), farthest home {worst[0]} "
          f"{worst[1]['from_spawn_s']} s from spawn (target <= 45), unreachable: "
          f"{[k for k, v in walk.items() if v['from_spawn_s'] == math.inf] or 0}")
    with open(os.path.join(ROOT, "art", "review", "world", "halo_v2", "walk_times.json"), "w", encoding="utf-8") as f:
        json.dump(dict(speed=speed, note="seconds along the walkable terrain grid (blockout raster), speed = Config.Player.WalkSpeed",
                       walk=walk), f, ensure_ascii=False, indent=1)

    # pointed rock underside: depth under every cell that is land or inside the sea ring (SEA_TIER != 4)
    active = [[MAT[r][c] != "sea" or SEA_TIER[r][c] != 4 for c in range(cols)] for r in range(rows)]
    UND = underside(active, rows, cols)
    # 5단계 10/12 ④: the rim's bottom edge was one straight line under the band -> ragged: a slow wave + drips; outcrops
    # (tier 5) hang RIM_OUT_D deep under their own top (the Luau adds nothing for them)
    ph = hash01(0, 0, 50) * 6.2832
    for r in range(rows):
        for c in range(cols):
            t = SEA_TIER[r][c] if MAT[r][c] == "sea" else None
            if t not in (3, 5):
                continue
            x, z = c * CELL, -r * CELL
            wave = 0.5 + 0.5 * math.sin(x / 37.0 + z / 29.0 + ph) * math.sin(z / 23.0 - x / 47.0)
            add = RIM_RAG[0] + (RIM_RAG[1] - RIM_RAG[0]) * wave
            if hash01(r, c, 31) < RIM_DRIP_P:
                add += RIM_DRIP[0] + (RIM_DRIP[1] - RIM_DRIP[0]) * hash01(r, c, 32)
            if t == 5:
                add = RIM_OUT_D[0] + (RIM_OUT_D[1] - RIM_OUT_D[0]) * hash01(r, c, 33) + add * 0.6
            UND[r][c] = min(UND_CAP, UND[r][c] + add) if t == 3 else min(UND_CAP, add)
    # 2차 10/11: a low beach cell (water on top in the Luau) next to the open sky (sea tier 4, the entry neck where the ring
    # narrows to nothing) showed a thin water edge: keep those cells dry (surface 0.5 above the -1.2 water)
    dry = 0
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] != "sea" and H[r][c] is not None and H[r][c] < 0.5:
                if any(0 <= r + dr < rows and 0 <= c + dc < cols and MAT[r + dr][c + dc] == "sea" and SEA_TIER[r + dr][c + dc] == 4
                       for dr in (-1, 0, 1) for dc in (-1, 0, 1)):
                    H[r][c] = 0.5
                    dry += 1
    print(f"[blockout] dry edge cells {dry}")
    # 2차 10/11: the deep ring water (floor -24) must never sit beside air under the shore. Land within 3 cells (8 neighbours)
    # of ring water gets rock down to the ring's bottom (-30, the Luau RIM_DOWN) + 4; the ring cells do it in the Luau
    near = [[None] * cols for _ in range(rows)]
    q = deque()
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] == "sea" and SEA_TIER[r][c] in (0, 1, 2):
                near[r][c] = 0
                q.append((r, c))
    while q:
        r, c = q.popleft()
        if near[r][c] >= 3:
            continue
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                rr, cc = r + dr, c + dc
                if 0 <= rr < rows and 0 <= cc < cols and near[rr][cc] is None and MAT[rr][cc] != "sea":
                    near[rr][cc] = near[r][c] + 1
                    q.append((rr, cc))
                    UND[rr][cc] = min(UND_CAP, max(UND[rr][cc], H[rr][cc] - 2 - RING_DOWN + 4 + 6 * (3 - near[rr][cc])))
    und_max = max(max(row) for row in UND)
    print(f"[blockout] underside depth max {und_max:.1f} studs (cap {UND_CAP}), unit {UND_UNIT}")

    # 5단계 10/12 (디자인 검수 r2_03·04·05·07: big cream / grey faces, black bands between the flower terraces and tiers):
    # every cell edge with a drop > FACE_DH is a retaining-wall edge. The edges are chained into lines and straightened
    # (Douglas-Peucker WALL_TOL: a diagonal district border is a zigzag of cell edges), then cut into pieces of one top
    # height -> build/wk/halo_walls.json -> tools/skeleton_ground.py stage "walls" (marble, WalkGround top). A piece is
    # WALL_T thick, centred on the line, so the terrain slope between the low and the high cell centres is inside it; top =
    # the high side. Stair cells stay open (their own rails). A face cell whose every steep edge got a wall is grass
    # again; the rest stay Limestone (not Rock: Rock is dark and is the island underside too)
    def wall_ok(m):
        return m not in ("sea", "water", "stair")
    TERRACE_D = {d["id"] for d in dists if d.get("terrace")}
    wedges = []  # (vertex a, vertex b, top, bot, low normal x, z) on grid vertices (col, row)
    faces = grassed = 0
    for r in range(rows):
        for c in range(cols):
            if MAT[r][c] in ("sea", "water") or H[r][c] is None:
                continue
            steep, walled = 0, 0
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                rr, cc = r + dr, c + dc
                if not (0 <= rr < rows and 0 <= cc < cols) or MAT[rr][cc] in ("sea", "water") or H[rr][cc] is None:
                    continue
                if H[r][c] - H[rr][cc] <= FACE_DH:
                    continue
                steep += 1
                if H[r][c] - H[rr][cc] < WALL_MIN and not (DID[r][c] in TERRACE_D or DID[rr][cc] in TERRACE_D):
                    walled += 1  # a grass bank: no wall, no Limestone
                elif wall_ok(MAT[r][c]) and wall_ok(MAT[rr][cc]):
                    walled += 1
                    if dr:  # the line between rows r and rr (z = Z0 - line*CELL), from column c to c+1; low side = -dr in z
                        ln = max(r, rr)
                        wedges.append(((c, ln), (c + 1, ln), H[r][c], H[rr][cc], 0.0, -float(dr)))
                    else:  # the line between columns c and cc, from row r to r+1; low side = +dc in x
                        ln = max(c, cc)
                        wedges.append(((ln, r), (ln, r + 1), H[r][c], H[rr][cc], float(dc), 0.0))
            if not steep or MAT[r][c] in ("stair",) or MAT[r][c].startswith("road") or (r, c) in PAD:
                continue
            if walled == steep:
                grassed += 1
            else:
                MAT[r][c] = "limestone"
                faces += 1

    def vxz(v):
        return X0 + v[0] * CELL, Z0 - v[1] * CELL
    adj = {}
    for i, e in enumerate(wedges):
        adj.setdefault(e[0], []).append(i)
        adj.setdefault(e[1], []).append(i)
    used = [False] * len(wedges)
    chains = []  # [vertex list, edge id list]

    def walk(v, i):
        vs, es = [v], []
        while True:
            used[i] = True
            es.append(i)
            e = wedges[i]
            v = e[1] if e[0] == v else e[0]
            vs.append(v)
            nxt = [j for j in adj[v] if not used[j]]
            if len(adj[v]) != 2 or not nxt:
                return vs, es
            i = nxt[0]
    for v in adj:
        if len(adj[v]) != 2:
            for i in adj[v]:
                if not used[i]:
                    chains.append(walk(v, i))
    for i in range(len(wedges)):  # closed loops
        if not used[i]:
            chains.append(walk(wedges[i][0], i))

    def dp(pts, lo, hi, keep):
        ax, az = pts[lo]
        bx, bz = pts[hi]
        best, bi = -1.0, None
        for k in range(lo + 1, hi):
            t, d = seg_t(pts[k], (ax, az), (bx, bz))
            if d > best:
                best, bi = d, k
        if bi is not None and best > WALL_TOL:
            keep.add(bi)
            dp(pts, lo, bi, keep)
            dp(pts, bi, hi, keep)
    walls = []
    for vs, es in chains:
        pts = [vxz(v) for v in vs]
        keep = {0, len(pts) - 1}
        dp(pts, 0, len(pts) - 1, keep)
        ks = sorted(keep)
        mids = [((vxz(wedges[i][0])[0] + vxz(wedges[i][1])[0]) / 2, (vxz(wedges[i][0])[1] + vxz(wedges[i][1])[1]) / 2, wedges[i]) for i in es]
        for a_, b_ in zip(ks, ks[1:]):
            (ax, az), (bx, bz) = pts[a_], pts[b_]
            L = math.hypot(bx - ax, bz - az)
            if L < 1e-6:
                continue
            ux, uz = (bx - ax) / L, (bz - az) / L
            n = max(1, int(round(L / CELL)))
            cuts = []
            for k in range(n):  # one 4-stud cut: the edges whose midpoints project into it
                t0, t1 = k * L / n, (k + 1) * L / n
                tops, bots, nx, nz = [], [], 0.0, 0.0
                for mx, mz, e in mids:
                    t = (mx - ax) * ux + (mz - az) * uz
                    d = abs((mx - ax) * uz - (mz - az) * ux)
                    if t0 - 0.01 <= t <= t1 + 0.01 and d <= WALL_TOL + CELL:
                        tops.append(e[2])
                        bots.append(e[3])
                        nx += e[4]
                        nz += e[5]
                if not tops:
                    cuts.append(cuts[-1][:2] + (t0, t1) + cuts[-1][4:] if cuts else None)
                    continue
                cuts.append((max(tops), min(bots), t0, t1, nx, nz))
            if cuts and cuts[0] is None:
                cuts = [c_ for c_ in cuts if c_ is not None]
            pieces = []
            for cu in cuts:
                if cu is None:
                    continue
                if pieces and abs(cu[0] - pieces[-1][0]) <= 0.25 and cu[3] - pieces[-1][2] <= WALL_MAXLEN:
                    pv = pieces[-1]
                    pieces[-1] = (max(pv[0], cu[0]), min(pv[1], cu[1]), pv[2], cu[3], pv[4] + cu[4], pv[5] + cu[5])
                else:
                    pieces.append(cu)
            for tp, bt, t0, t1, nx, nz in pieces:
                # the low side as the unit perpendicular of the line (sign from the edges' own low normals)
                px, pz = -uz, ux
                sg = 1.0 if px * nx + pz * nz >= 0 else -1.0
                cx, cz = ax + ux * (t0 + t1) / 2, az + uz * (t0 + t1) / 2
                walls.append(dict(x=round(cx, 2), z=round(cz, 2), len=round(t1 - t0 + WALL_OVER, 2), ux=round(ux, 4), uz=round(uz, 4),
                                  nx=round(px * sg, 4), nz=round(pz * sg, 4), top=round(tp, 2), bot=round(bt, 2), t=WALL_T))
    # 디자인 검수 10/12 (r2_07 / r2_03: short walls standing alone on the grass): a piece is kept only where the ground
    # really steps there - high side ~ its top, low side >= FACE_DH under it - at 2 of 3 points along it (junction / corner
    # leftovers of the straightening fail)
    def hgrid(x, z):
        c_, r_ = int((x - X0) // CELL), int((Z0 - z) // CELL)
        if 0 <= r_ < rows and 0 <= c_ < cols and MAT[r_][c_] != "sea" and H[r_][c_] is not None:
            return H[r_][c_]
        return -99.0
    kept = []
    for w_ in walls:
        ok = 0
        for f in (-0.33, 0.0, 0.33):
            px_, pz_ = w_["x"] + w_["ux"] * w_["len"] * f, w_["z"] + w_["uz"] * w_["len"] * f
            off = w_["t"] / 2 + CELL * 0.75
            hi = hgrid(px_ - w_["nx"] * off, pz_ - w_["nz"] * off)
            lo = hgrid(px_ + w_["nx"] * off, pz_ + w_["nz"] * off)
            ok += hi >= w_["top"] - 2.5 and w_["top"] - lo >= FACE_DH
        if ok >= 2:
            kept.append(w_)
    print(f"[blockout] wall pieces without a real step there: {len(walls) - len(kept)} dropped")
    walls = kept
    os.makedirs(os.path.join(ROOT, "build", "wk"), exist_ok=True)
    with open(os.path.join(ROOT, "build", "wk", "halo_walls.json"), "w", encoding="utf-8") as f:
        json.dump(dict(cell=CELL, walls=walls), f)
    print(f"[blockout] retaining walls: {len(wedges)} cell edges -> {len(chains)} lines -> {len(walls)} pieces; "
          f"face cells grass {grassed}, limestone left {faces}")

    # 5단계 10/12 (① grass poking through the road plates on ramps and bends): the Terrain under the road parts sits
    # ROAD_SINK lower; tools/skeleton_ground.py G() adds it back from build/wk/halo_sink.json (the parts keep their height)
    sunk = 0
    mask = []
    for r in range(rows):
        row = []
        for c in range(cols):
            on = (r, c) in RSINK and MAT[r][c] not in ("sea", "water") and H[r][c] is not None
            if on:
                H[r][c] -= ROAD_SINK
                sunk += 1
            row.append("1" if on else "0")
        mask.append("".join(row))
    with open(os.path.join(ROOT, "build", "wk", "halo_sink.json"), "w", encoding="utf-8") as f:
        json.dump(dict(x0=X0, z0=Z0, cell=CELL, sink=ROAD_SINK, rows=mask), f)
    print(f"[blockout] road sink {ROAD_SINK}: {sunk} cells")

    # encode
    hrows, mrows, urows = [], [], []
    for r in range(rows):
        hs, ms = [], []
        urows.append("".join(ALPH[min(len(ALPH) - 1, int(round(UND[r][c] / UND_UNIT)))] for c in range(cols)))
        for c in range(cols):
            if MAT[r][c] == "sea":
                hs.append(ALPH[SEA_TIER[r][c]])  # 0 deep sea, 1 sand shelf off the north beach, 2 cliff foot
                ms.append(M["sea"])
            else:
                v = int(round(H[r][c])) + HOFF
                v = max(1, min(len(ALPH) - 1, v))
                hs.append(ALPH[v])
                ms.append(M[MAT[r][c]])
        hrows.append("".join(hs))
        mrows.append("".join(ms))

    ox, oz = (float(v) for v in a.offset.split(","))
    data = dict(cell=CELL, x0=X0, z0=Z0, cols=cols, rows=rows, hoff=HOFF, alph=ALPH, h=hrows, m=mrows, und=urows, und_unit=UND_UNIT, box=[X0, X1, Z0, Z1],
                offset=[ox, oz], buildings=plan["buildings"], bridges=plan["bridges"], roads=[
                    dict(id=r["id"], pts=r["pts"], w=r["w"]) for r in plan["roads"] if r["id"] in ("main", "loop", "plaza_castle")],
                falls=plan["water"]["falls"], pools=plan["water"]["pools"],
                fixed=plan["fixed_points"], first10=plan["first_10_minutes"], districts=[
                    dict(id=d["id"], name=d["name"], y=d["y"], poly=d["poly"]) for d in dists])
    src = open(TEMPLATE, encoding="utf-8").read()
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    src = src.replace("__MODE__", a.mode).replace("__DATA__", blob.replace("]]", "] ]"))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    land_cells = sum(1 for r in range(rows) for c in range(cols) if MAT[r][c] != "sea")
    print(f"[blockout] grid {cols}x{rows} land {land_cells} water {water_cells} stair cells {stairs} -> {OUT} ({len(src) // 1024} KB)")


if __name__ == "__main__":
    main()
