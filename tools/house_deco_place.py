"""Place the decoration templates of tools/house_deco.py after tools/piece_fix.py baked them (이미지 생성 3, 10/11).

  blender --background --factory-startup --python tools/house_deco_place.py -- <fixed.glb> <deco report.json> <out.glb>

Every report "copies" entry {"src", "name", "scale", "move"} becomes a new object <name> = src scaled about the origin then
moved (mesh transformed, the material and its maps shared, so one map set per template); the templates are dropped.
Everything else passes through. Prints each object's box and the triangle total.
"""
import json
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, REP, OUT = argv
copies = json.load(open(REP, encoding="utf-8")).get("copies", [])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
objs = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
for o in objs.values():
    o.data.transform(o.matrix_world)
    o.matrix_world.identity()
    o.parent = None
templates = set()
for c in copies:
    src = objs.get(c["src"])
    if src is None:
        print("[place] missing template", c["src"], flush=True)
        continue
    templates.add(c["src"])
    n = src.copy()
    n.data = src.data.copy()
    n.name = n.data.name = c["name"]
    bpy.context.scene.collection.objects.link(n)
    n.data.transform(Matrix.Translation(c["move"]) @ Matrix.Scale(c["scale"], 4))
for t in templates:
    bpy.data.objects.remove(objs[t])
bpy.ops.object.select_all(action="DESELECT")
tris = 0
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    o.select_set(True)
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
    pts = [Vector(v.co) for v in o.data.vertices]
    print("[place] %-40s %6d tris  x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % (
        o.name, len(o.data.loop_triangles), min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts),
        max(p.y for p in pts), min(p.z for p in pts), max(p.z for p in pts)), flush=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[place] ok %d tris -> %s" % (tris, OUT), flush=True)
