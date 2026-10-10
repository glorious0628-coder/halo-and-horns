"""Assemble the Crown of Balance from its Tripo parts and render previews (이미지 생성 1, 2026-10-10, A23-107).

  blender --background --factory-startup --python tools/crown_assemble.py -- <out.glb> <render_dir> [--gap G] [--red-rot DEG] [--red-dx DX]

Parts (Z-up after glb_decimate --rotz -90, front = -Y):
- art/models/tripo/web/Crown_GoldHalf_HD_LOD.glb : gold half, broken (jagged) edge on its +X side -> placed on the left (-X)
- art/models/tripo/web/Crown_RedHalf_HD_LOD.glb  : red half, turned --red-rot (default 180) so its gem faces front and its
  jagged edge faces -X -> placed on the right (+X)
Both are scaled to the same height (1.0) and set on the ground; the two broken edges meet at X = 0 with --gap between them.
Each Tripo half came out as a whole ring: both are turned so their gems face the sides, sized to the same ring, then cut.
Gems and the halo ring are Roblox parts (Glass / Neon), not in this mesh.
Writes <out.glb> (two meshes, materials kept) and <render_dir>/crown_{front,top,front34}.png.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, RDIR = argv[0], argv[1]
opt = {"gap": 0.0, "red-rot": 180.0, "gold-rot": 0.0, "red-dx": 0.0, "keep": 0.12}
i = 2
while i < len(argv):
    opt[argv[i][2:]] = float(argv[i + 1])
    i += 2

bpy.ops.wm.read_factory_settings(use_empty=True)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(path, name):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, path))
    objs = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = name
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return ob


def bbox(ob):
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    return Vector([min(p[k] for p in pts) for k in range(3)]), Vector([max(p[k] for p in pts) for k in range(3)])


gold = load("art/models/tripo/web/Crown_GoldHalf_HD_LOD.glb", "Crown_GoldHalf")
red = load("art/models/tripo/web/Crown_RedHalf_HD_LOD.glb", "Crown_RedHalf")
# both gems turned to face the sides (gold -X, red +X) so the cut runs front-to-back between them
for ob, key in ((gold, "gold-rot"), (red, "red-rot")):
    ob.matrix_world = Matrix.Rotation(math.radians(opt[key]), 4, "Z") @ ob.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for ob in (gold, red):  # same height (1); the red ring's depth is matched to the gold one so the cut faces line up
    lo, hi = bbox(ob)
    ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    lo, hi = bbox(ob)
    s = 1.0 / (hi.z - lo.z)
    ob.data.transform(Matrix.Diagonal((s, s, s, 1.0)))
lo_g, hi_g = bbox(gold)
lo_r, hi_r = bbox(red)
red.data.transform(Matrix.Diagonal((1.0, (hi_g.y - lo_g.y) / (hi_r.y - lo_r.y), 1.0, 1.0)))
# Tripo made each "half" as a whole crown ring (2026-10-10): cut the gold ring at X = 0 and keep its left half, cut the
# red ring and keep its right half, cap the cuts, then set the halves apart by --gap (the crack; a Neon seam part covers it)
import bmesh


def keep_half(ob, keep_negative):
    # the cut sits --keep (fraction of the ring width) past the centre so the front gem stays whole on both halves
    lo, hi = bbox(ob)
    cx = opt["keep"] * (hi.x - lo.x) * (1 if keep_negative else -1)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(cx, 0, 0), plane_no=(1, 0, 0),
                                 clear_outer=keep_negative, clear_inner=not keep_negative)
    cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if cut_edges:
        try:
            bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
        except Exception as ex:  # noqa: BLE001 - an open cut is acceptable, the seam part hides it
            print("[crown] cap skipped", ex)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    bpy.context.view_layer.update()  # bound_box is stale after a bmesh write until the depsgraph updates


keep_half(gold, True)
keep_half(red, False)
lo_g, hi_g = bbox(gold)
lo_r, hi_r = bbox(red)
gold.location = (-hi_g.x - opt["gap"] / 2, 0, 0)
red.location = (-lo_r.x + opt["gap"] / 2 + opt["red-dx"], 0, 0)
bpy.context.view_layer.update()
lo = Vector([min(bbox(o)[0][k] for o in (gold, red)) for k in range(3)])
hi = Vector([max(bbox(o)[1][k] for o in (gold, red)) for k in range(3)])
print("[crown] size", [round(hi[k] - lo[k], 3) for k in range(3)], "gold", [round(v, 3) for v in bbox(gold)[0]], [round(v, 3) for v in bbox(gold)[1]],
      "red", [round(v, 3) for v in bbox(red)[0]], [round(v, 3) for v in bbox(red)[1]], flush=True)

# renders
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 900
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
c = (lo + hi) / 2
r = max(hi - lo) * 1.6
os.makedirs(RDIR, exist_ok=True)
for name, d in (("front", Vector((0, -1, 0.25))), ("top", Vector((0, -0.05, 1))), ("front34", Vector((0.7, -1, 0.45)))):
    d.normalize()
    cam.location = c + d * r
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RDIR, "crown_" + name + ".png")
    bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
gold.select_set(True)
red.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", use_selection=True, export_animations=False)
print("[crown] ok", OUT, flush=True)
