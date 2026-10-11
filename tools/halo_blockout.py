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
X0, X1 = -212, 212
Z0, Z1 = -324, -712  # north edge (gate side) .. south edge
HOFF = 20  # stored height = round(y) + HOFF
ALPH = "".join(chr(c) for c in range(48, 48 + 80) if chr(c) not in "\\\"'`[]")  # safe chars
# material codes
M = dict(sea="s", grass="g", dirt="d", road1="c", road2="b", road3="p", stair="t", water="w", rock="r", sand="n")
SLOPES = {  # y -> y_to along this line
    "market": ((12, -450), (112, -470)),
    "garden_homes": ((-96, -612), (-170, -672)),
    "cliff_homes": ((96, -540), (166, -630)),
}
DIST_MAT = {"training": "dirt", "arrival": "grass"}


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

    # encode
    hrows, mrows = [], []
    for r in range(rows):
        hs, ms = [], []
        for c in range(cols):
            if MAT[r][c] == "sea":
                hs.append(ALPH[0])
                ms.append(M["sea"])
            else:
                v = int(round(H[r][c])) + HOFF
                v = max(1, min(len(ALPH) - 1, v))
                hs.append(ALPH[v])
                ms.append(M[MAT[r][c]])
        hrows.append("".join(hs))
        mrows.append("".join(ms))

    ox, oz = (float(v) for v in a.offset.split(","))
    data = dict(cell=CELL, x0=X0, z0=Z0, cols=cols, rows=rows, hoff=HOFF, alph=ALPH, h=hrows, m=mrows,
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
