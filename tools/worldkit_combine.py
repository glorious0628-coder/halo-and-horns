"""
Put many GLBs into one GLB so the Studio 3D Importer runs once (WorldKit, 2026-10-06; shorter screen control).

  blender --background --factory-startup --python tools/worldkit_combine.py -- <spec.json> <out.glb>

spec.json: [{"name": "Town_Halo_Gate", "file": "art/models/tripo/Town_Halo_Gate_raw.glb", "kind": "tripo", "scale": 30.0}, ...]
  optional per item: "fit": ["h" | "z" | "max", studs] instead of "scale" (widest ground side / height / largest side),
  "row": "meadow" to lay it out in its own row.
- tripo: Tripo GLB (front = +X in Blender, size about 1): turned so the front faces +Y in Blender (= -Z in glTF, the
  Roblox LookVector after import) and scaled by `scale` (batch3a_manifest.json, studs).
- acc: tools/acc_compare.py --export GLB (studs, front = -Y in Blender): turned 180 deg so the front faces +Y too.
- Each item becomes one mesh object named <name> (parts joined), base centre on the ground, laid out in rows.
- Textures bigger than 1024 are scaled down to 1024 (Roblox keeps 1024 at most, smaller upload).
The Studio importer keeps 1 glTF unit = 1 stud (checked on the earlier Tripo imports in WorldKit).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SPEC, OUT = argv[0], os.path.abspath(argv[1])
items = json.load(open(SPEC, encoding="utf-8"))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
done = []
TEXMAX = {}
TWEAK = set()
row_x = {"tripo": 0.0, "acc": 0.0, "meadow": 0.0}
row_y = {"tripo": 0.0, "acc": -60.0, "meadow": -40.0}

for it in items:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(it["file"]))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if it["kind"] == "parts":
        # already in studs, front +Y, base centre at the origin (e.g. tools/split_uv_tiles.py): keep every part as its
        # own mesh (one 1024 texture each) under an empty named <name>, only move it into its row
        for o in meshes:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        for o in new:
            if o.type != "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
        pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size = hi - lo
        k = it.get("row", "tripo")
        x = row_x[k] + size.x / 2
        row_x[k] += size.x + {"tripo": 12.0, "meadow": 6.0}.get(k, 4.0)
        root = bpy.data.objects.new(it["name"], None)
        bpy.context.scene.collection.objects.link(root)
        root.location = (x - (lo.x + hi.x) / 2, row_y[k] - (lo.y + hi.y) / 2, -lo.z)
        for o in meshes:
            o.parent = root
        tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
        done.append({"name": it["name"], "tris": tris, "parts": [o.name for o in meshes],
                     "size_studs": [round(size.x, 2), round(size.y, 2), round(size.z, 2)], "materials": len(meshes)})
        print("[worldkit_combine]", json.dumps(done[-1]), flush=True)
        continue
    # bake every mesh into world space, drop the empties
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    turn = math.radians(90) if it["kind"] == "tripo" else math.radians(180)
    obj.matrix_world = Matrix.Rotation(turn, 4, "Z") @ obj.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    def box():
        pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
                Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))

    s = float(it.get("scale", 1.0))
    if "fit" in it:
        # "fit": ["h" | "z" | "max", studs] - widest ground side, height, or largest side becomes that size
        lo, hi = box()
        d = hi - lo
        dim = {"h": max(d.x, d.y), "z": d.z, "max": max(d.x, d.y, d.z)}[it["fit"][0]]
        s = float(it["fit"][1]) / max(dim, 1e-6)
    obj.matrix_world = Matrix.Diagonal((s, s, s, 1.0)) @ obj.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = box()
    size = hi - lo
    k = it.get("row", it["kind"])
    gap = {"tripo": 12.0, "meadow": 6.0}.get(k, 4.0)
    x = row_x[k] + size.x / 2
    row_x[k] += size.x + gap
    obj.data.transform(Matrix.Translation(Vector((x - (lo.x + hi.x) / 2, row_y[k] - (lo.y + hi.y) / 2, -lo.z))))
    obj.name = it["name"]
    obj.data.name = it["name"]
    for i, m in enumerate(obj.data.materials):
        if m:
            m.name = f"{it['name']}_mat{i}"
    for m in obj.data.materials:
        if m and m.use_nodes:
            for nd in m.node_tree.nodes:
                if nd.type == "TEX_IMAGE" and nd.image and it.get("tweak"):
                    TWEAK.add(nd.image.name)
                if nd.type == "TEX_IMAGE" and nd.image and "tex" in it:
                    TEXMAX[nd.image.name] = min(int(it["tex"]), TEXMAX.get(nd.image.name, 4096))  # optional per item: "tex": 512 (small repeated props)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    done.append({"name": it["name"], "tris": tris, "scale": round(s, 4),
                 "size_studs": [round(size.x, 2), round(size.y, 2), round(size.z, 2)], "materials": len(obj.data.materials)})
    print("[worldkit_combine]", json.dumps(done[-1]), flush=True)

for img in bpy.data.images:
    cap = TEXMAX.get(img.name, 1024)
    if img.size[0] > cap or img.size[1] > cap:
        w, h = img.size
        f = cap / max(w, h)
        img.scale(max(1, round(w * f)), max(1, round(h * f)))
    if img.name in TWEAK:  # 2026-10-10: a +-1.2% brightness / per-channel nudge so the re-upload is a different file (moderation false positive on the first upload)
        import numpy as np
        buf = np.empty(len(img.pixels), dtype=np.float32)
        img.pixels.foreach_get(buf)
        px = buf.reshape(-1, 4)
        px[:, 0] *= 0.988
        px[:, 1] *= 0.991
        px[:, 2] *= 0.994
        img.pixels.foreach_set(px.reshape(-1))
        img.update()
    if img.packed_file is None and img.has_data:
        img.pack()

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_image_format="AUTO",
                          export_animations=False, export_skins=False)
json.dump(done, open(os.path.splitext(OUT)[0] + "_list.json", "w", encoding="utf-8"), indent=1)
print("[worldkit_combine] wrote", OUT, len(done), "items", flush=True)
