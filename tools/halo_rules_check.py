"""Halo town layout rule check (이미지 생성 1, 2026-10-10; rules docs/design/acnh_halo_layout_rules_2026-10-10.md).

  py tools/halo_rules_check.py [--dump build/halo_new/halo_dump.txt] [--plan docs/design/halo_layout_plan_2026-10-10.json]

Prints the numbers the rules ask for: walkable area per height band (rule 1: 1 > 2 > 3 > 4), paved share (rule 5: <= 35 %),
mirror pairs (rule 8: same kind within 12 studs after flipping x, <= 1), bridge pairs per tier (rule 4: z gap >= 25),
same prop within any 40 x 40 (rule 11: <= 5), props all at yaw 0 / scale 1 (rule 11), three in a row (rule 8/11),
unreachable columns and the reserved spots (gather bushes, photo spots, small scenes, lookouts, empty lawns).
"""
import argparse
import json
import math
from collections import Counter

ap = argparse.ArgumentParser()
ap.add_argument("--dump", default="build/halo_new/halo_dump.txt")
ap.add_argument("--plan", default="docs/design/halo_layout_plan_2026-10-10.json")
a = ap.parse_args()

COL = {}
for line in open(a.dump, encoding="utf-8"):
    if line.startswith("C,"):
        p = line.strip().split(",")
        COL[(float(p[1]), float(p[2]))] = (float(p[3]), p[6])
plan = json.load(open(a.plan, encoding="utf-8"))
P = [e for e in plan["placements"] if not e.get("backdrop")]

# rule 1: walkable area per band (tops and plazas; band by height)
BANDS = [("1 (0-6)", -1, 6.5), ("2 (6.5-17)", 6.5, 17.5), ("3 (17.5-27)", 17.5, 27.5), ("4 (27.5+)", 27.5, 99)]
area = Counter()
paved = grass = 0
for (x, z), (v, tag) in COL.items():
    if tag in ("plaza", "top", "stair"):
        for name, lo, hi in BANDS:
            if lo <= v < hi:
                area[name] += 16
        if tag in ("plaza", "stair"):
            paved += 1
        else:
            grass += 1
print("rule 1 walkable area per band (stud^2):", ", ".join(f"{n} {area[n]}" for n, _, _ in BANDS),
      "| decreasing:", all(area[BANDS[i][0]] >= area[BANDS[i + 1][0]] for i in range(3)))
print(f"rule 5 paved share {100 * paved / max(1, paved + grass):.0f} % (plaza+stair {paved} / walkable {paved + grass} columns; want <= 35)")

# rule 8: mirror pairs
MK = ("DomeHouseA", "DomeHouseB", "Shop", "ArchBridge", "Tower", "Statue", "BannerPole", "Stairs", "Cathedral", "Fountain")
pairs = []
for i, e in enumerate(P):
    if e["kind"] not in MK:
        continue
    for f in P[i + 1:]:
        if f["kind"] != e["kind"] and not (e["kind"].startswith("DomeHouse") and f["kind"].startswith("DomeHouse")):
            continue
        if (e["x"] < 0) == (f["x"] < 0) and abs(e["x"]) > 6:
            continue
        if math.hypot(e["x"] + f["x"], e["z"] - f["z"]) < 12:
            pairs.append((e["kind"], e["x"], e["z"], f["x"], f["z"]))
print(f"rule 8 mirror pairs {len(pairs)} (want <= 1):", [(k, round(x1), round(z1), round(x2), round(z2)) for k, x1, z1, x2, z2 in pairs])

# rule 4: bridges
br = [e for e in P if e["kind"] in ("ArchBridge", "SmallBridge", "SteppingStones")]
print(f"rule 4 bridges {len(br)}:", [(e.get("name"), e["kind"], round(e["x"]), round(e["z"]), round(e.get("span", 0))) for e in br])

# rule 11: same prop in 40 x 40, yaw / scale variety
SMALL = ("Lantern", "Planter", "CloudBush", "Topiary", "RoundTree", "PotFlowers", "Balustrade", "BannerPole", "Bench")
worst = {}
for e in P:
    if e["kind"] not in SMALL:
        continue
    n = sum(1 for f in P if f["kind"] == e["kind"] and abs(f["x"] - e["x"]) <= 20 and abs(f["z"] - e["z"]) <= 20)
    worst[e["kind"]] = max(worst.get(e["kind"], 0), n)
print("rule 11 most of one kind in a 40x40 (want <= 5):", worst)
for k in ("Lantern", "Planter", "PotFlowers", "Balustrade", "Bench"):
    es = [e for e in P if e["kind"] == k]
    if es:
        print(f"   {k}: {len(es)}, yaws {len({round(e['yaw']) for e in es})} kinds, scales {len({round(e['s'], 2) for e in es})} kinds")

# three of a kind in a row with even gaps
rows = 0
for k in ("DomeHouseA", "Lantern", "Planter", "Topiary", "Tower", "Statue"):
    es = [e for e in P if e["kind"] == k or (k == "DomeHouseA" and e["kind"] == "DomeHouseB")]
    for i in range(len(es)):
        for j in range(len(es)):
            if j == i:
                continue
            ax, az = es[j]["x"] - es[i]["x"], es[j]["z"] - es[i]["z"]
            d = math.hypot(ax, az)
            if d < 3 or d > 40:
                continue
            tx, tz = es[j]["x"] + ax, es[j]["z"] + az
            if any(math.hypot(e["x"] - tx, e["z"] - tz) <= 1.0 for e in es):
                rows += 1
print(f"rule 8/11 even rows of three: {rows // 2}")

# A23-117: every building / prop says why it stands there and belongs to one district
nowhy = [e["kind"] for e in plan["placements"] if not e.get("why")]
print(f"A23-117 why empty: {len(nowhy)} (want 0)", sorted(set(nowhy)))
from collections import Counter as _C
print("A23-117 per district:", dict(_C(e.get("zone", "?") for e in plan["placements"])))
print("unreachable columns:", plan.get("unreachable"))
spots = plan.get("spots", {})
print("reserved spots:", {k: len(v) for k, v in spots.items()})
print("counts:", plan.get("counts"))
