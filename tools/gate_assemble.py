"""Assemble the Halo gate from its Tripo parts (이미지 생성 1, 2026-10-10, A23-107 부품별 새로 만들기, docs/design/halo_parts_plan_2026-10-10.md §1).

  blender --background --factory-startup --python tools/gate_assemble.py -- <out.glb> <render_dir> [--door-open 70]

Parts (art/models/tripo/web/HaloPart_<P>_HD_LOD.glb, Z-up, front = -Y after glb_decimate --rotz -90), sizes in studs (1 unit = 1 stud):
- GateArch      : arch wall + paved passage, fit height 26, centred at x 0, its base on z 0
- GateTowerL/R  : tower bodies, fit height 30, centres x -/+ (arch half width + r) so each touches the arch side
- GateDomeL/R   : gold domes, fit width = tower diameter + 1, sitting on the tower tops
- GateDoorLeafL/R (only with --doors 1): door leaves, fit height = 0.8 x the measured opening height, hinged at the opening edges, opened --door-open degrees
The opening (width, height) is measured with rays through the arch mesh. Writes <out.glb> (one mesh per part, names kept) and
<render_dir>/gate_asm_{front,front34,back34}.png. Model front = -Y (Roblox -Z after import), pivot = bottom centre.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, RDIR = os.path.abspath(argv[0]), os.path.abspath(argv[1])
opt = {"door-open": 70.0, "doors": 0.0}
i = 2
while i < len(argv):
    opt[argv[i][2:]] = float(argv[i + 1])
    i += 2
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)


def load(part):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art/models/tripo/web/HaloPart_%s_HD_LOD.glb" % part))
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
    ob.name = "Gate_" + part
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return ob


def bbox(ob):
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    return Vector([min(p[k] for p in pts) for k in range(3)]), Vector([max(p[k] for p in pts) for k in range(3)])


def fit(ob, axis, size):
    lo, hi = bbox(ob)
    d = {"x": hi.x - lo.x, "y": hi.y - lo.y, "z": hi.z - lo.z, "h": max(hi.x - lo.x, hi.y - lo.y)}[axis]
    s = size / d
    ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    ob.data.transform(Matrix.Diagonal((s, s, s, 1.0)))
    ob.data.update()
    bpy.context.view_layer.update()
    return ob


arch = fit(load("GateArch"), "z", 26.0)  # plan: arch wall 26 high (the Tripo arch is wider than the 2D, so the width follows)
lo_a, hi_a = bbox(arch)
AW = (hi_a.x - lo_a.x) / 2
# measure the opening: rays along -Y through the arch at several heights / widths
deps = bpy.context.evaluated_depsgraph_get()


def blocked(x, z):
    hit, *_ = arch.ray_cast(Vector((x, hi_a.y + 5, z)), Vector((0, -1, 0)))
    return hit


open_w = 0.0
for x10 in range(0, 110):
    if blocked(x10 / 10.0, 3.0):
        open_w = 2 * x10 / 10.0
        break
open_h = 0.0
for z10 in range(20, 300):
    if blocked(0.0, z10 / 10.0):
        open_h = z10 / 10.0
        break
print("[gate] arch", [round(v, 2) for v in (hi_a - lo_a)], "opening w %.2f h %.2f" % (open_w, open_h), flush=True)

parts = []
for side, sx in (("L", -1), ("R", 1)):
    t = fit(load("GateTower" + side), "z", 30.0)
    lo_t, hi_t = bbox(t)
    r = (hi_t.x - lo_t.x) / 2
    t.location = (sx * (AW + r - 0.3), 0, 0)
    d = fit(load("GateDome" + side), "h", 2 * r + 1.0)
    d.location = (sx * (AW + r - 0.3), 0, 30.0 - 0.2)
    parts += [t, d]
    if not opt["doors"]:
        continue  # 10/10: the Tripo leaves came with their own stone frame; the concept gate is an open arch -> leaves kept for the interior pass
    leaf = fit(load("GateDoorLeaf" + side), "z", 0.8 * open_h if open_h > 4 else 10.0)
    lo_l, hi_l = bbox(leaf)
    w = hi_l.x - lo_l.x
    # hinge on the opening edge at the front face of the arch wall; the leaf swings inward (toward +Y) by door-open degrees
    hx = sx * (open_w / 2 if open_w > 2 else 5.0)
    leaf.data.transform(Matrix.Translation(Vector((-sx * w / 2, 0, 0))))  # hinge edge at the local origin
    ang = math.radians(opt["door-open"]) * (-sx)
    leaf.matrix_world = Matrix.Translation(Vector((hx, lo_a.y + 0.6, 0.1))) @ Matrix.Rotation(-ang, 4, "Z")
    parts.append(leaf)
bpy.context.view_layer.update()
lo = Vector([min(bbox(o)[0][k] for o in [arch] + parts) for k in range(3)])
hi = Vector([max(bbox(o)[1][k] for o in [arch] + parts) for k in range(3)])
print("[gate] size", [round(v, 2) for v in (hi - lo)], flush=True)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1100, 900
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
c = (lo + hi) / 2
rad = max(hi - lo) * 1.5
os.makedirs(RDIR, exist_ok=True)
for name, dv in (("front", Vector((0, -1, 0.12))), ("front34", Vector((0.7, -1, 0.35))), ("back34", Vector((-0.7, 1, 0.35)))):
    dv.normalize()
    cam.location = c + dv * rad
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RDIR, "gate_asm_" + name + ".png")
    bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in [arch] + parts:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[gate] ok", OUT, flush=True)
