"""halo_blockout.py (이미지 생성 1, 2026-10-11, SPEC A23-121 3단계 '회색 상자'): plan v2 -> one WorldKit script.

Reads docs/design/halo_plan_v2_2026-10-11.json and rasterizes it on a 4-stud grid:
  * land height per cell = its district's Y (ramps for y_to districts), land outside every district takes the nearest
    district's height; under each building footprint the ground is flattened to the building's ground_y (Terrain floor:
    the code only counts Terrain / Bridge_* as ground)
  * roads: the road's own height profile (heights at its points, linear in between) -> ramps; cells steeper than 24 deg
    are marked as stairs (Slate) so the photos show where real stairs must go
  * the stream: a channel 2 below its own falling profile, filled with water; pools; the sea outside the land
Then writes build/wk/halo_blockout_apply.lua = tools/worldkit/halo_blockout.luau with the data filled in.
usage: py tools/halo_blockout.py [--mode apply|remove|plan] [--offset X,Z]
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
EDGE = 32  # grid margin round the land: the 20-stud sea ring + its rim + air
HOFF = 20  # stored height = round(y) + HOFF
ALPH = "".join(chr(c) for c in range(48, 48 + 80) if chr(c) not in "\\\"'`[]")  # safe chars
# material codes
M = dict(sea="s", grass="g", dirt="d", road1="c", road2="b", road3="p", stair="t", water="w", rock="r", sand="n")
SLOPES = {  # y -> y_to along this line (stage-1 coordinates; main() grows them like the plan)
    "market": ((12, -450), (112, -470)),
    "garden_homes": ((-96, -612), (-170, -672)),
    "cliff_homes": ((96, -540), (166, -630)),
}
DIST_MAT = {"training": "dirt", "arrival": "grass"}
PAVED_R = dict(fountain=40, spawn=14)  # paved circle radii: round the plan's fountain pool and the spawn (0, -420)
BEACH_Z, BEACH_W = -400, 4  # sand on the north shore (z > -400) up to 4 cells from the sea
CLIFF_Z = -760  # rock lip on the south shore
SEA_R = 5  # sea ring width in cells (20 studs) round the coast


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
    cols = (X1 - X0) // CELL
    rows = (Z0 - Z1) // CELL
    H = [[None] * cols for _ in range(rows)]
    MAT = [["sea"] * cols for _ in range(rows)]
    DID = [[None] * cols for _ in range(rows)]

    def cxz(r, c):
        return X0 + c * CELL + CELL / 2, Z0 - r * CELL - CELL / 2

    def dist_y(d, p):
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
    for b in plan["buildings"]:
        fp = [tuple(p) for p in b["footprint"]]
        xs = [p[0] for p in fp]
        zs = [p[1] for p in fp]
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if min(xs) - 4 <= x <= max(xs) + 4 and min(zs) - 4 <= z <= max(zs) + 4:
                    if inside((x, z), fp) or min(math.hypot(x - px, z - pz) for px, pz in fp) < 3:
                        if MAT[r][c] != "sea":
                            H[r][c] = b["ground_y"]
                            PAD.add((r, c))
    base = [row[:] for row in H]

    # roads: own height profile, painted, ramps; stairs where steeper than 24 deg
    grade_mat = {1: "road1", 2: "road2", 3: "road3"}
    stairs = 0
    for rd in sorted(plan["roads"], key=lambda r: -r["grade"]):  # grade 1 painted last (on top)
        pts = [tuple(p) for p in rd["pts"]]
        prof = [ground_at(p) for p in pts]
        if rd["id"].startswith("door_"):
            prof[0] = prof[1] = ground_at(pts[0])
        half = rd["w"] / 2
        for r in range(rows):
            for c in range(cols):
                p = cxz(r, c)
                if MAT[r][c] == "sea":
                    continue
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
                if math.hypot(x - y["at"][0], z - y["at"][1]) <= y["r"] and MAT[r][c] not in ("sea", "water", "stair"):
                    MAT[r][c] = "road2"
    fpool = next(p for p in plan["water"]["pools"] if p["id"] == "fountain")
    PAVED = [(fpool["at"][0], fpool["at"][1], PAVED_R["fountain"]), (0, -420, PAVED_R["spawn"])]
    for (px, pz, pr) in PAVED:
        for r in range(rows):
            for c in range(cols):
                x, z = cxz(r, c)
                if math.hypot(x - px, z - pz) <= pr and MAT[r][c] not in ("sea", "water", "stair"):
                    MAT[r][c] = "road1"
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
                if DL[r][c] > ring:
                    SEA_TIER[r][c] = 4
                elif DL[r][c] == ring:
                    SEA_TIER[r][c] = 3
                elif z > BEACH_Z and abs(x) > 24 and DL[r][c] <= 3:
                    SEA_TIER[r][c] = 1
                elif DL[r][c] <= 1:
                    SEA_TIER[r][c] = 2
                else:
                    SEA_TIER[r][c] = 0

    # walking times (③ 3차 target: gate -> cathedral ~30 s, spawn -> any home <= 45 s at WalkSpeed 16): Dijkstra on the grid,
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
        return best / 16.0

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
        json.dump(dict(speed=16, note="seconds along the walkable terrain grid (blockout raster)", walk=walk), f, ensure_ascii=False, indent=1)

    # encode
    hrows, mrows = [], []
    for r in range(rows):
        hs, ms = [], []
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
    data = dict(cell=CELL, x0=X0, z0=Z0, cols=cols, rows=rows, hoff=HOFF, alph=ALPH, h=hrows, m=mrows, box=[X0, X1, Z0, Z1],
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
