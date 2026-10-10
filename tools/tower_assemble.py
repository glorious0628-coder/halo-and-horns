"""Assemble the Halo town tower (the watch towers) from its Tripo parts (이미지 생성 1, 2026-10-11, docs/design/halo_parts_plan_2026-10-10.md §4;
new parts only, A23-107 / A23-96).

  blender --background --factory-startup --python tools/tower_assemble.py -- <out.glb> <render_dir> [--res 700]

Parts (art/models/tripo/web/HaloPart_<P>_HD_LOD.glb, Z-up, front = -Y): TowerBody (3 floors, entrance) fitted to 26 high, TowerDome
fitted to the body top width + 1 (its metal / roughness rebuilt from the colour: the Tripo metal map came out rainbow), a halo ring
over the dome, TowerDoorFrame (4 x 7) on the entrance with TowerDoorLeaf inside, TowerWindow (2 x 3) on the round wall at three
heights, turned to face outward (only with --windows 1: the Tripo body already has its own windows). Pivot = bottom centre, front = -Y.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, RDIR = os.path.abspath(argv[0]), os.path.abspath(argv[1])
opt = {"res": 700.0}
i = 2
while i < len(argv):
    opt[argv[i][2:]] = float(argv[i + 1])
    i += 2
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)


def bbox(ob):
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    return Vector([min(p[k] for p in pts) for k in range(3)]), Vector([max(p[k] for p in pts) for k in range(3)])


def part(name, size, axis):
    path = os.path.join(ROOT, "art/models/tripo/web/HaloPart_%s_HD_LOD.glb" % name)
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
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
    for o in list(bpy.context.scene.objects):
        if o not in before and o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    ob.name = "Tower_" + name
    lo, hi = bbox(ob)
    k = {"x": 0, "y": 1, "z": 2}[axis]
    s = size / (hi[k] - lo[k])
    ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    ob.data.transform(Matrix.Diagonal((s, s, s, 1.0)))
    ob.data.update()
    bpy.context.view_layer.update()
    print("[tower] %s -> %s" % (name, [round(v, 2) for v in (hi - lo) * s]), flush=True)
    return ob


def metal_from_color(ob):
    import numpy as np
    for slot in ob.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        nt = m.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        col = next((l.from_node for l in bsdf.inputs["Base Color"].links), None) if bsdf else None
        if not col or col.type != "TEX_IMAGE":
            continue
        img = col.image
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        rgb = px.reshape(-1, 4)[:, :3]
        mx, mn = rgb.max(1), rgb.min(1)
        sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
        gold = ((hue >= 20) & (hue <= 58) & (sat >= 0.4) & (mx >= 0.5)).astype(np.float32)
        for nm, val in (("metal", gold * 0.9), ("rough", gold * 0.28 + (1 - gold) * 0.62)):
            out = bpy.data.images.new(ob.name + "_" + nm, w, h, alpha=False, is_data=True)
            out.pixels.foreach_set(np.repeat(val[:, None], 4, axis=1).ravel())
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = out
            t.image.colorspace_settings.name = "Non-Color"
            inp = bsdf.inputs["Metallic" if nm == "metal" else "Roughness"]
            for l in list(inp.links):
                nt.links.remove(l)
            nt.links.new(t.outputs["Color"], inp)
        print("[tower] %s: metal / roughness from the colour (gold %.0f %%)" % (ob.name, 100 * gold.mean()), flush=True)


P = []
body = part("TowerBody", 26.0, "z")
lo, hi = bbox(body)
P.append(body)
# the radius of the wall at a height: rays from outside toward the axis
cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2


def wall_r(z, ang):
    d = Vector((math.sin(ang), -math.cos(ang), 0))
    start = Vector((cx, cy, z)) + d * 40
    hit, loc, *_ = body.ray_cast(body.matrix_world.inverted() @ start, -d)
    return (Vector((loc.x, loc.y, 0)) - Vector((cx, cy, 0))).length if hit else (hi.x - lo.x) / 2


top_w = 2 * max(wall_r(hi.z - 0.3, a) for a in (0, math.pi / 2, math.pi, -math.pi / 2))
dome = part("TowerDome", top_w + 1.0, "x")
dome.location = (cx, cy, hi.z - 0.2)
metal_from_color(dome)
P.append(dome)
ld, hd = bbox(dome)
bpy.ops.mesh.primitive_torus_add(major_radius=max(1.4, top_w * 0.22), minor_radius=0.2, major_segments=48, minor_segments=10,
                                 location=(cx, cy, hd.z + 1.4), rotation=(math.radians(12), 0, 0))
ring = bpy.context.active_object
ring.name = "Tower_HaloRing"
m_ = bpy.data.materials.new("Tower_HaloRing")
m_.use_nodes = True
b_ = m_.node_tree.nodes["Principled BSDF"]
b_.inputs["Base Color"].default_value = (1.0, 0.86, 0.45, 1)
b_.inputs["Emission Color"].default_value = (1.0, 0.86, 0.45, 1)
b_.inputs["Emission Strength"].default_value = 3.0
ring.data.materials.append(m_)
P.append(ring)
# entrance: door frame at the front wall (ground), leaf just inside
r0 = wall_r(3.5, 0.0)
frame = part("TowerDoorFrame", 7.0, "z")
frame.location = (cx, cy - r0 - 0.15, lo.z)
P.append(frame)
lf, hf = bbox(frame)
leaf = part("TowerDoorLeaf", (hf.z - lf.z) * 0.85, "z")
leaf.location = (cx, cy - r0 + 0.3, lo.z + 0.1)
P.append(leaf)
# windows: one per floor, each floor its own angle (not stacked in a line), facing outward
for k, (zf, deg) in enumerate(() if opt.get("windows", 0) < 1 else ((0.36, 35), (0.58, -40), (0.8, 150))):  # off by default: the body has its own windows
    z = lo.z + (hi.z - lo.z) * zf
    a = math.radians(deg)
    r = wall_r(z, a)
    w = part("TowerWindow", 3.0, "z")
    w.rotation_euler = (0, 0, a)
    w.location = (cx + math.sin(a) * (r + 0.1), cy - math.cos(a) * (r + 0.1), z - 1.5)
    w.name = "Tower_Window%d" % (k + 1)
    P.append(w)
bpy.context.view_layer.update()
LO = Vector([min(bbox(o)[0][k] for o in P) for k in range(3)])
HI = Vector([max(bbox(o)[1][k] for o in P) for k in range(3)])
print("[tower] size", [round(v, 1) for v in (HI - LO)], flush=True)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = int(opt["res"])
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
c = (LO + HI) / 2
rad = max(HI - LO) * 2.0
os.makedirs(RDIR, exist_ok=True)
for name, dv in (("front", Vector((0, -1, 0.15))), ("front34", Vector((0.7, -1, 0.35))), ("back34", Vector((-0.7, 1, 0.35)))):
    dv.normalize()
    cam.location = c + dv * rad
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RDIR, "tower_asm_" + name + ".png")
    bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in P:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[tower] ok", OUT, flush=True)
