"""Goblin Woods layout plan: validate + top-down render (A23-76).

py tools/woods_plan_check.py [plan.json] [--png out.png] [--concept]  (--concept also writes woods_plan_vs_concept.jpg next to the png)

Reads docs/design/woods_layout_plan_2026-10-08.json (world studs, X east, Z south) and checks that
the pieces do not fight each other, then draws a top-down sheet. Exit code 1 if any check fails.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PLAN = ROOT / "docs/design/woods_layout_plan_2026-10-08.json"
OUT = ROOT / "art/review/world/woods_layout_plan_check.png"


def dist_pt_seg(p, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L = dx * dx + dz * dz
    t = 0 if L == 0 else max(0, min(1, ((p[0] - ax) * dx + (p[1] - az) * dz) / L))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))


def dist_pt_line(p, pts):
    return min(dist_pt_seg(p, pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def creek_width_at(creek, p):
    pts = creek["pts"]
    w0, w1 = creek["w"]
    best, bi = 1e9, 0
    for i in range(len(pts) - 1):
        d = dist_pt_seg(p, pts[i], pts[i + 1])
        if d < best:
            best, bi = d, i
    t = bi / max(1, len(pts) - 2)
    return best, w0 + (w1 - w0) * t


def check(plan):
    errs, warns = [], []
    land = plan["land"]
    keep = plan["keep"]
    clr = plan["camp_clearings"]
    paths = plan["paths"]
    creek = plan["creek"]

    def inside(p, m=0):
        return land["MinX"] + m <= p[0] <= land["MaxX"] - m and land["MinZ"] + m <= p[1] <= land["MaxZ"] - m

    # everything inside the land
    for c in clr:
        if not inside(c["c"], c["r"]):
            errs.append(f"clearing {c['c']} r{c['r']} leaves the land")
    for pa in paths:
        for q in pa["pts"]:
            if not inside(q):
                errs.append(f"path {pa['name']} point {q} outside the land")
    for q in creek["pts"]:
        if not inside(q):
            errs.append(f"creek point {q} outside the land")
    for m in plan["mounds"]:
        if not inside(m["c"], m["r"] * 0.5):
            warns.append(f"mound {m['c']} pokes out of the land")

    # keep spots: camps and boss sit inside their clearing, giant / arrival near a path or open
    for kc in keep["camps"] + [keep["boss"]]:
        if not any(math.dist(kc, c["c"]) <= 1.0 for c in clr):
            errs.append(f"quest spot {kc} has no clearing centred on it")
    for q in (keep["giant"], keep["arrival"]):
        if not inside(q):
            errs.append(f"quest spot {q} outside the land")

    # every path ends/starts at the road (z 0 side) or in a clearing/keep spot
    road_z = keep["crown_road_z"]
    spots = [c["c"] for c in clr] + [keep["giant"], keep["arrival"]]
    for pa in paths:
        for q in (pa["pts"][0], pa["pts"][-1]):
            ok = abs(q[1] - road_z) <= 12 or any(math.dist(q, s) <= 24 for s in spots)
            ok = ok or any(dist_pt_line(q, o["pts"]) <= o["w"] for o in paths if o is not pa)
            ok = ok or q[0] <= land["MinX"] + 45 or q[0] >= land["MaxX"] - 45
            if not ok:
                warns.append(f"path {pa['name']} end {q} dangles (no road, clearing or other path near)")

    # creek must not cut paths or clearings (crossings are StepStones only)
    for pa in paths:
        for q in pa["pts"]:
            d, w = creek_width_at(creek, q)
            if d < w / 2 + pa["w"] / 2:
                errs.append(f"path {pa['name']} point {q} is in the creek")
    for c in clr:
        d, w = creek_width_at(creek, c["c"])
        if d < c["r"] + w / 2 + 6:
            errs.append(f"clearing {c['c']} too close to the creek ({d:.0f})")

    # mounds keep off paths, clearings and quest spots (mounds are for the eye, not for walking over roads)
    for m in plan["mounds"]:
        for pa in paths:
            d = dist_pt_line(m["c"], pa["pts"])
            if d < m["r"] * 0.6 + pa["w"] / 2:
                warns.append(f"mound {m['c']} r{m['r']} sits on path {pa['name']} (dist {d:.0f})")
        for c in clr:
            if math.dist(m["c"], c["c"]) < m["r"] + c["r"]:
                errs.append(f"mound {m['c']} overlaps clearing {c['c']}")
        for k in (keep["giant"], keep["arrival"]):
            if math.dist(m["c"], k) < m["r"] + 6:
                warns.append(f"mound {m['c']} covers quest spot {k}")
        d, w = creek_width_at(creek, m["c"])
        if d < m["r"] + w / 2:
            warns.append(f"mound {m['c']} overlaps the creek")

    # boulder groups: not on paths, clearings, creek bed, quest spots
    for (c, n) in plan["boulder_groups"]:
        for pa in paths:
            if dist_pt_line(c, pa["pts"]) < pa["w"] / 2 + 4:
                errs.append(f"boulder group {c} on path {pa['name']}")
        for cl in clr:
            if math.dist(c, cl["c"]) < cl["r"] + 3:
                errs.append(f"boulder group {c} inside clearing {cl['c']}")
        for k in (keep["giant"], keep["arrival"]):
            if math.dist(c, k) < 10:
                errs.append(f"boulder group {c} on quest spot {k}")
        d, w = creek_width_at(creek, c)
        if d < w / 2 + 2 and abs(c[1] - creek["pts"][0][1]) > 20:
            warns.append(f"boulder group {c} in the creek bed (fine only as bank rocks)")

    # waterfall at the creek start
    wf = plan["waterfall"]
    if math.dist(wf["c"], creek["pts"][0]) > 12:
        errs.append("waterfall is not at the creek start")
    if not inside(wf["c"], wf["pool_r"]):
        warns.append("waterfall pool leaves the land")
    return errs, warns


def render(plan, out):
    from PIL import ImageDraw

    land = plan["land"]
    S = 2.0  # px per stud
    pad = 30
    W = int((land["MaxX"] - land["MinX"]) * S) + pad * 2
    H = int((land["MaxZ"] - land["MinZ"]) * S) + pad * 2
    im = Image.new("RGB", (W, H), (96, 140, 70))
    d = ImageDraw.Draw(im, "RGBA")

    def P(q):
        return ((q[0] - land["MinX"]) * S + pad, (q[1] - land["MinZ"]) * S + pad)

    def circ(c, r, fill, outline=None):
        x, y = P(c)
        d.ellipse([x - r * S, y - r * S, x + r * S, y + r * S], fill=fill, outline=outline)

    road_z = plan["keep"]["crown_road_z"]
    d.rectangle([P((land["MinX"], road_z - 9)), P((land["MaxX"], road_z + 9))], fill=(120, 105, 90, 255))
    ins = plan["edge_rim"]["inset"]
    d.rectangle([P((land["MinX"] + ins, land["MinZ"] + ins)), P((land["MaxX"] - ins, land["MaxZ"] - ins))],
                outline=(40, 90, 40, 255), width=2)
    for m in plan["mounds"]:
        circ(m["c"], m["r"], (70, 120, 55, 150), (40, 80, 40, 255))
    cr = plan["creek"]
    w0, w1 = cr["w"]
    for i in range(len(cr["pts"]) - 1):
        w = w0 + (w1 - w0) * i / max(1, len(cr["pts"]) - 2)
        d.line([P(cr["pts"][i]), P(cr["pts"][i + 1])], fill=(70, 150, 220, 255), width=int(w * S))
    wf = plan["waterfall"]
    circ(wf["c"], wf["pool_r"], (90, 170, 235, 255), (255, 255, 255, 255))
    for pa in plan["paths"]:
        pts = [P(q) for q in pa["pts"]]
        d.line(pts, fill=(176, 140, 96, 255), width=int(pa["w"] * S), joint="curve")
    for c in plan["camp_clearings"]:
        circ(c["c"], c["r"], (190, 150, 100, 255), (110, 80, 50, 255))
    for (c, n) in plan["boulder_groups"]:
        circ(c, 2.5 + n, (130, 130, 135, 255), (70, 70, 75, 255))
    k = plan["keep"]
    for q, col in [(k["giant"], (200, 60, 60, 255)), (k["arrival"], (240, 220, 60, 255)), (k["boss"], (160, 60, 200, 255))]:
        circ(q, 4, col, (0, 0, 0, 255))
    for q in k["camps"]:
        circ(q, 3, (255, 140, 30, 255), (0, 0, 0, 255))
    for i, q in enumerate(k["camps"]):
        d.text((P(q)[0] + 8, P(q)[1] - 22), f"camp {i + 1}", fill=(255, 255, 255, 255))
    d.text((P(k["boss"])[0] + 10, P(k["boss"])[1] - 26), "boss", fill=(255, 255, 255, 255))
    d.text((P(k["giant"])[0] + 8, P(k["giant"])[1] - 18), "giant", fill=(255, 255, 255, 255))
    d.text((P(k["arrival"])[0] + 8, P(k["arrival"])[1] - 18), "arrival", fill=(255, 255, 255, 255))
    d.text((P(wf["c"])[0] - 70, P(wf["c"])[1] + 14), "waterfall", fill=(255, 255, 255, 255))
    d.rectangle([P((land["MinX"], land["MinZ"])), P((land["MaxX"], land["MaxZ"]))], outline=(0, 0, 0, 255), width=2)
    d.text((pad, 6), "Goblin Woods plan (N = up; red giant, yellow arrival, purple boss, orange camps)", fill=(255, 255, 255, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    return im


def main():
    args = sys.argv[1:]
    out = OUT
    plan_path = PLAN
    i = 0
    while i < len(args):
        if args[i] == "--png":
            out = Path(args[i + 1])
            i += 2
        elif args[i] == "--concept":
            i += 1
        else:
            plan_path = Path(args[i])
            i += 1
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    errs, warns = check(plan)
    for e in errs:
        print("ERROR", e)
    for w in warns:
        print("warn ", w)
    im = render(plan, out)
    if "--concept" in args:
        c = Image.open(ROOT / "art/review/concept/Concept_GoblinWoods.jpg").convert("RGB")
        h = im.height
        c = c.resize((int(c.width * h / c.height), h))
        sheet = Image.new("RGB", (c.width + im.width, h), (255, 255, 255))
        sheet.paste(c, (0, 0))
        sheet.paste(im.convert("RGB"), (c.width, 0))
        sheet.save(out.with_name("woods_plan_vs_concept.jpg"), quality=88)
    print(f"{len(errs)} errors, {len(warns)} warnings; sheet {out}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
