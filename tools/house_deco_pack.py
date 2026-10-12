"""Pack the 15 house decoration GLBs into one import (one Studio Import 3D click), 이미지 생성 3, 10/12.

  blender --background --factory-startup --python tools/house_deco_pack.py -- <out.glb> [<out>.json written next to it]

Each art/models/tripo/house_deco/<house>/<house>_deco.glb (skeleton frame: x, y = front, z up, origin = plan centre) is put
where that house's skeleton stands in WorldKit's Workspace.SkeletonTest test rows (front row z 60: 01 02 03 04 05 06 08 09,
back row z 115: 10 11 12 Bakery Flower Juice Potion, x 2940 + 36 i). Studio's importer was seen (house 07, 10/11) to give
Roblox = (-x_b, z_b, y_b) + T, so a skeleton point (x, y, z) -> Roblox (OX + x, z, OZ - y) needs the GLB point
(-x - OX, -y + OZ, z): turned 180 degrees about z and moved. T (where Studio drops the import) is found afterwards from the
bounding box written to <out>.json ("roblox_bbox" min / max the import should have) and the model is moved by the difference.
Object names keep their house prefix (HaloDomeHouse_02_Dome, HaloShop_Juice_Lantern0, ...).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.environ.get("HH_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
# --houses a,b  --only-names Sign,PlaqueBack,...: a small extra import (10/12 빠진 장식) with only those pieces
HOUSES = ARGS[ARGS.index("--houses") + 1].split(",") if "--houses" in ARGS else None
ONLY = ARGS[ARGS.index("--only-names") + 1].split(",") if "--only-names" in ARGS else None
FRONT = ["01", "02", "03", "04", "05", "06", "08", "09"]
BACK = ["10", "11", "12", "Bakery", "Flower", "Juice", "Potion"]
ROWS = {}
for i, h in enumerate(FRONT):
    ROWS["HaloDomeHouse_" + h] = (2940 + 36 * i, 60)
for i, h in enumerate(BACK):
    ROWS[("HaloDomeHouse_" + h) if h.isdigit() else ("HaloShop_" + h)] = (2940 + 36 * i, 115)
bpy.ops.wm.read_factory_settings(use_empty=True)
info = {"houses": {}, "note": "Roblox = (-x_b, z_b, y_b) + T; move the imported model by (expected - imported) bbox min"}
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for name, (ox, oz) in ROWS.items():
    if HOUSES and name not in HOUSES:
        continue
    p = os.path.join(ROOT, "art", "models", "tripo", "house_deco", name, name + "_deco.glb")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=p)
    M = Matrix.Translation((-ox, oz, 0)) @ Matrix.Rotation(math.pi, 4, "Z")
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    if ONLY:
        for o in list(objs):
            if not any(("_" + k) in o.name for k in ONLY):
                bpy.data.objects.remove(o)
        objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in objs:                                      # no Blender ".001" suffixes in Studio names
        base = o.name.rsplit(".", 1)[0] if o.name.rsplit(".", 1)[-1].isdigit() else o.name
        if base != o.name and base not in bpy.data.objects:
            o.name = base
    for o in objs:
        o.data.transform(M @ o.matrix_world)
        o.matrix_world.identity()
        o.parent = None
        for v in o.data.vertices:                       # expected Roblox position of this vertex
            rx, ry, rz = -v.co.x, v.co.z, v.co.y
            lo = Vector((min(lo.x, rx), min(lo.y, ry), min(lo.z, rz)))
            hi = Vector((max(hi.x, rx), max(hi.y, ry), max(hi.z, rz)))
    info["houses"][name] = {"origin": [ox, 0, oz], "objects": sorted(o.name for o in objs)}
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="SELECT")
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
info["roblox_bbox"] = {"min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi]}
json.dump(info, open(os.path.splitext(OUT)[0] + ".json", "w"), indent=1)
n = sum(len(h["objects"]) for h in info["houses"].values())
print("[pack] %d houses, %d objects, roblox bbox %s .. %s -> %s" % (len(info["houses"]), n, info["roblox_bbox"]["min"], info["roblox_bbox"]["max"], OUT), flush=True)
