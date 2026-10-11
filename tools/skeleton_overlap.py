"""Overlap check for Studio skeleton parts (이미지 생성 3, 10/11): every pair of parts of one house that sink more than
<thr> studs into each other, grouped by part kind, minus the kinds that are meant to touch (frames in walls, rings on
the plinth, caps on posts, ...). Boxes are oriented boxes (SAT); an upright Cylinder against an upright part is tested
as a circle in plan.

  py tools/skeleton_overlap.py <dir with skel_<name>.json> [0.12]
"""
import json, sys, glob, os, re, itertools
import numpy as np
D = sys.argv[1]
THR = float(sys.argv[2]) if len(sys.argv) > 2 else 0.12

def group(n):
    m = re.match(r"(.+?)_Win\d+_\d+_", n)
    if m: return "Win"
    for p in ["Door_", "Plinth_", "FootRing_", "CorniceGold", "Cornice", "StoreyLedge", "StoreyGold", "PilasterCap", "PilasterFoot", "PilasterBand", "Pilaster",
              "TowerBand", "TowerCap", "TowerFoot", "TowerFinial", "Tower", "Pedestal", "LampGlass", "Awning_", "Step", "Pot", "Medal", "Balc", "WBox",
              "RailBase_", "Rail_", "Baluster_", "ParapetPost", "ParapetGold", "Parapet_", "RoofDeck", "Skylight", "Topiary", "HipLine", "HipRidge", "HipEave", "HipFinial", "Hip",
              "Chimney", "Pergola", "Cupola", "DrumBase", "DrumTop", "Drum", "Shop_", "FloorInside", "FloorStorey", "CeilingSlab"]:
        if n.startswith(p): return p.rstrip("_")
    if re.match(r".+_(C|G|GL|GR|GT)\d+(_\d+)?$", n): return "Wall"
    return "?" + n

def obb(p):
    X = np.array(p["X"], float); Y = np.array(p["Y"], float); Z = np.cross(X, Y)
    return np.array(p["pos"], float), np.stack([X, Y, Z]), np.array(p["size"], float) / 2

def upright(p):
    (x, y, z), sz = p["pos"], p["size"]
    if abs(p["X"][2]) > 0.99 and p.get("shape") == "Cylinder":
        return ("c", (x, y), sz[1] / 2), z - sz[0] / 2, z + sz[0] / 2
    if abs(p["Y"][2]) > 0.99 and p.get("shape") != "Cylinder":
        L = (p["X"][0] ** 2 + p["X"][1] ** 2) ** 0.5
        return ("r", (x, y), (p["X"][0] / L, p["X"][1] / L), sz[0] / 2, sz[2] / 2), z - sz[1] / 2, z + sz[1] / 2
    return None, 0, 0

def circ_pen(c, r, fp):
    import math
    if fp[0] == "c":
        return r + fp[2] - math.hypot(c[0] - fp[1][0], c[1] - fp[1][1])
    _, (cx, cy), u, hu, hv = fp
    v = (-u[1], u[0])
    lu, lv = (c[0] - cx) * u[0] + (c[1] - cy) * u[1], (c[0] - cx) * v[0] + (c[1] - cy) * v[1]
    qu, qv = max(-hu, min(hu, lu)), max(-hv, min(hv, lv))
    if (qu, qv) != (lu, lv):
        return r - math.hypot(lu - qu, lv - qv)
    return r + min(hu - abs(lu), hv - abs(lv))

def pen2(pa, pb, a, b):
    """cylinder-aware: an upright cylinder against an upright part is tested as a circle in plan"""
    fa, za0, za1 = upright(pa)
    fb, zb0, zb1 = upright(pb)
    if fa and fb and (fa[0] == "c" or fb[0] == "c"):
        dz = min(za1, zb1) - max(za0, zb0)
        if dz <= 0:
            return 0.0
        if fa[0] != "c":
            fa, fb = fb, fa
        return max(0.0, min(dz, circ_pen(fa[1], fa[2], fb)))
    return pen(a, b)

def pen(a, b):
    ca, Ra, ea = a; cb, Rb, eb = b
    t = cb - ca
    axes = list(Ra) + list(Rb)
    for i in range(3):
        for j in range(3):
            c = np.cross(Ra[i], Rb[j])
            if np.linalg.norm(c) > 1e-6: axes.append(c / np.linalg.norm(c))
    best = 1e9
    for L in axes:
        ra = sum(ea[k] * abs(Ra[k] @ L) for k in range(3))
        rb = sum(eb[k] * abs(Rb[k] @ L) for k in range(3))
        d = ra + rb - abs(t @ L)
        if d <= 0: return 0.0
        best = min(best, d)
    return best

# pairs that are designed to touch / embed (frames into walls etc.)
OK = {frozenset(x) for x in [("Wall","Win"),("Wall","Door"),("Wall","Plinth"),("Wall","FootRing"),("Wall","Cornice"),("Wall","StoreyLedge"),("Wall","StoreyGold"),
      ("Wall","Pilaster"),("Wall","PilasterCap"),("Wall","PilasterFoot"),("Wall","PilasterBand"),("Wall","CeilingSlab"),("Wall","FloorInside"),("Wall","FloorStorey"),
      ("Plinth","FootRing"),("Cornice","CorniceGold"),("StoreyLedge","StoreyGold"),("Pilaster","PilasterCap"),("Pilaster","PilasterFoot"),("Pilaster","PilasterBand"),
      ("Plinth","FloorInside"),("Plinth","Pilaster"),("Plinth","PilasterFoot"),("FootRing","PilasterFoot"),("Cornice","PilasterCap"),("Cornice","Pilaster"),("CeilingSlab","Cornice"),
      ("Pedestal","Pedestal"),("Pot","Pot"),("Awning","Awning"),("Balc","Balc"),("WBox","WBox"),("Door","Door"),("Win","Win"),("Shop","Shop"),("Wall","Shop"),
      ("Tower","TowerBand"),("Tower","TowerCap"),("Tower","TowerFoot"),("Tower","Wall"),("Tower","Plinth"),("Tower","FootRing"),("Tower","Cornice"),("Tower","CorniceGold"),("Tower","StoreyLedge"),("Tower","StoreyGold"),
      ("TowerFinial","TowerFinial"),("TowerFinial","TowerCap"),("Rail","RailBase"),("Rail","Baluster"),("RailBase","Baluster"),("ParapetPost","ParapetPostCap"),
      ("Parapet","ParapetGold"),("Parapet","ParapetPost"),("ParapetGold","ParapetPost"),("Rail","ParapetPost"),("RailBase","ParapetPost"),("RoofDeck","Rail"),("RoofDeck","RailBase"),("RoofDeck","Parapet"),("RoofDeck","ParapetPost"),
      ("RoofDeck","CorniceGold"),("RoofDeck","Cornice"),("RoofDeck","CeilingSlab"),("Topiary","Topiary"),("Skylight","Skylight"),("Hip","Hip"),("Hip","HipLine"),("Hip","HipRidge"),("Hip","HipEave"),
      ("HipLine","HipRidge"),("HipLine","HipEave"),("HipFinial","HipRidge"),("HipFinial","Hip"),("HipFinial","HipLine"),("HipFinial","HipFinial"),("Chimney","Chimney"),("Chimney","Hip"),
      ("Pergola","Pergola"),("Cupola","Cupola"),("Drum","Drum"),("Drum","DrumBase"),("Drum","DrumTop"),("DrumBase","DrumTop"),("DrumBase","CorniceGold"),("DrumBase","Cornice"),("DrumBase","CeilingSlab"),
      ("Step","Step"),("Step","Plinth"),("Step","FootRing"),("Medal","Medal"),("Medal","Wall"),("Wall","Wall"),("Plinth","Plinth"),("FootRing","FootRing"),("Cornice","Cornice"),("CorniceGold","CorniceGold"),
      ("StoreyLedge","StoreyLedge"),("StoreyGold","StoreyGold"),("Pilaster","Pilaster"),("PilasterCap","PilasterCap"),("Tower","Tower"),("TowerBand","TowerBand"),
      ("Rail","Rail"),("RailBase","RailBase"),("Parapet","Parapet"),("ParapetGold","ParapetGold"),("ParapetPost","ParapetPost"),("Baluster","Baluster"),("HipEave","HipEave"),("HipLine","HipLine"),
      ("Pedestal","Plinth"),("Pedestal","FootRing"),("Pedestal","Wall"),("LampGlass","LampGlass"),("Balc","Wall"),("Balc","StoreyLedge"),("Balc","StoreyGold"),("WBox","Wall"),
      ("Door","Plinth"),("Door","FloorInside"),("Door","Step"),("Door","FootRing"),("CornicePilaster","x"),("Pot","Plinth"),("Pot","FootRing"),("FloorStorey","StoreyLedge"),("FloorStorey","StoreyGold"),
      ("FloorInside","FootRing"),("FloorStorey","Balc"),("Win","FloorStorey"),("Win","FloorInside"),("CeilingSlab","Win"),("Door","CeilingSlab"),("FloorStorey","Door"),
      ("CeilingSlab","CorniceGold"),("CeilingSlab","Pilaster"),("CeilingSlab","PilasterCap"),("CeilingSlab","Tower"),("FloorInside","Pilaster"),("FloorStorey","Pilaster"),("FloorInside","Tower"),("FloorStorey","Tower"),
      ("FloorStorey","Wall"),("FloorInside","FloorInside"),("Shop","FloorInside"),("Shop","Plinth"),("Shop","FootRing"),("Shop","FloorStorey"),
      ]}

out = []
for f in sorted(glob.glob(os.path.join(D, "skel_*.json"))):
    if f.endswith(("_cams.json", "_ornaments.json")): continue
    n = os.path.basename(f)[5:-5]
    P = json.load(open(f))
    G = [group(p["name"]) for p in P]
    B = [obb(p) for p in P]
    rad = [np.linalg.norm(b[2]) for b in B]
    hits = {}
    for i, j in itertools.combinations(range(len(P)), 2):
        gi, gj = G[i], G[j]
        if frozenset((gi, gj)) in OK: continue
        if np.linalg.norm(B[i][0] - B[j][0]) > rad[i] + rad[j]: continue
        d = pen2(P[i], P[j], B[i], B[j])
        if d > THR:
            key = tuple(sorted((gi, gj)))
            hits.setdefault(key, []).append((round(d, 2), P[i]["name"], P[j]["name"]))
    for k, v in sorted(hits.items()):
        v.sort(reverse=True)
        out.append("%s  %s x %s: %d pairs, max %.2f e.g. %s" % (n, k[0], k[1], len(v), v[0][0], " | ".join("%s~%s(%.2f)" % (a, b, d) for d, a, b in v[:3])))
print("\n".join(out))
