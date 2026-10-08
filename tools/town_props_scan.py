"""
마을 안 소품 조사(읽기만, 2026-10-08): place/GoodEvil.rbxlx에서 두 마을(Config.Zones HaloTown/HornsTown 상자) 안에 있는
보이는 모델·파트를 모아, 원시 파트(Part/Wedge/Cylinder 등)로 된 것과 3D(MeshPart+MeshId)로 된 것을 나눈다.

  py tools/town_props_scan.py [place.rbxlx] > out.json

- 묶는 단위: Workspace 아래에서 '처음 만나는 Model'(폴더는 내려감). 모델이 아닌 낱개 파트는 그 폴더 이름으로 묶는다.
- 보임: Transparency < 0.95 인 BasePart만 센다(투명 계약 파트·존 바닥 제외). Terrain·SpawnLocation·Camera 제외.
- 마을 상자: HaloTown 가운데 (0, -515) 크기 400 × 370, HornsTown (0, 515) 같은 크기(Config.luau 지도 v2).
"""
import json
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

PLACE = sys.argv[1] if len(sys.argv) > 1 else "place/GoodEvil.rbxlx"
TOWNS = {"HaloTown": (0, -515, 200, 185), "HornsTown": (0, 515, 200, 185)}
PRIM = {"Part", "WedgePart", "CornerWedgePart", "TrussPart", "Seat", "VehicleSeat", "SpawnLocation"}

root = ET.parse(PLACE).getroot()


def props(it):
    p = it.find("Properties")
    return p if p is not None else ET.Element("x")


def name(it):
    n = props(it).find("string[@name='Name']")
    return n.text if n is not None else "?"


def pos(it):
    c = props(it).find("CoordinateFrame[@name='CFrame']")
    if c is None or c.find("X") is None:
        return None
    return tuple(float(c.find(a).text) for a in ("X", "Y", "Z"))


def transp(it):
    t = props(it).find("float[@name='Transparency']")
    return float(t.text) if t is not None else 0.0


def mesh_id(it):
    for key in ("MeshId", "MeshID"):
        c = props(it).find(f"Content[@name='{key}']/url")
        if c is not None and c.text:
            return c.text
    return ""


def town_of(p):
    for t, (cx, cz, hx, hz) in TOWNS.items():
        if abs(p[0] - cx) <= hx and abs(p[2] - cz) <= hz:
            return t
    return None


groups = defaultdict(lambda: {"prim": 0, "mesh": 0, "other": 0, "pts": [], "classes": defaultdict(int), "path": ""})


def visit_parts(it, key, path):
    for d in it.iter("Item"):
        cls = d.get("class")
        p = pos(d)
        if p is None or cls in ("Camera", "SpawnLocation", "Terrain"):
            continue
        if not (cls in PRIM or cls in ("Part", "MeshPart", "UnionOperation", "NegateOperation") or cls.endswith("Part")):
            continue
        if transp(d) >= 0.95:
            continue
        t = town_of(p)
        if not t:
            continue
        g = groups[(t, key)]
        g["path"] = path
        g["classes"][cls] += 1
        if cls == "MeshPart" and mesh_id(d):
            g["mesh"] += 1
        elif cls in PRIM or cls == "Part":
            g["prim"] += 1
        else:
            g["other"] += 1
        g["pts"].append(p)


def walk(it, path):
    for ch in it.findall("Item"):
        cls = ch.get("class")
        nm = name(ch)
        p2 = path + "/" + nm
        if cls == "Model":
            visit_parts(ch, nm, p2)
        elif cls in ("Folder", "Workspace") or cls is None:
            walk(ch, p2)
        elif cls == "Terrain":
            continue
        else:
            # a loose part (or a part that holds parts): group by its parent folder path
            visit_parts(ch, path.split("/")[-1] + "/(parts)", path)


ws = [it for it in root.findall("Item") if it.get("class") == "Workspace"][0]
walk(ws, "Workspace")
out = []
for (t, key), g in groups.items():
    xs = [p[0] for p in g["pts"]]
    zs = [p[2] for p in g["pts"]]
    out.append({"town": t, "model": key, "path": g["path"], "prim": g["prim"], "mesh": g["mesh"], "other": g["other"],
                "classes": dict(g["classes"]), "center": [round(sum(xs) / len(xs), 1), round(sum(zs) / len(zs), 1)]})
out.sort(key=lambda r: (r["town"], r["path"], r["model"]))
print(json.dumps(out, ensure_ascii=False))
