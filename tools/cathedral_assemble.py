"""Assemble the Halo cathedral from its Tripo parts (이미지 생성 1, 2026-10-10, docs/design/halo_parts_plan_2026-10-10.md §3; 검수: new parts
only, the old one-piece cathedral is not reused, A23-107 / A23-96).

  blender --background --factory-startup --python tools/cathedral_assemble.py -- <out.glb> <render_dir> [--res 700]

Each part is art/models/tripo/web/HaloPart_<P>_HD_LOD.glb (Z-up, front = -Y). A part that is not made yet becomes a grey box of its
plan size (named Cath_<P>_PLACEHOLDER) so the frame (places and sizes) can be checked and the real part drops in later.
Plan (studs): base + front stairs 40 x 10 x 18 (wide oval platform under the body), body 56 x 26 x 50 (entrance at the front
middle), big gold dome dia 30 x 22 on the body top, small towers 8 x 30 x 8 on the four body corners (A front-left / back-right,
B front-right / back-left: left and right differ), door frame 10 x 14 + two leaves in the entrance, arched windows 4 x 8 on the
body front sides, the door-halo plate above the door frame. Pivot = bottom centre, front = -Y (Roblox -Z after import).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, RDIR = os.path.abspath(argv[0]), os.path.abspath(argv[1])
opt = {"res": 700.0, "body-depth": 34.0}
i = 2
while i < len(argv):
    opt[argv[i][2:]] = float(argv[i + 1])
    i += 2
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
GREY = bpy.data.materials.new("placeholder")
GREY.use_nodes = True
GREY.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.55, 0.6, 1)


def bbox(ob):
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    return Vector([min(p[k] for p in pts) for k in range(3)]), Vector([max(p[k] for p in pts) for k in range(3)])


def part(name, size, fit_axis="z"):
    """the Tripo part fitted to its plan size along fit_axis (pivot bottom centre), or a placeholder box of the plan size"""
    path = os.path.join(ROOT, "art/models/tripo/web/HaloPart_%s_HD_LOD.glb" % name)
    if os.path.exists(path):
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
        ob.name = "Cath_" + name
        lo, hi = bbox(ob)
        k = {"x": 0, "y": 1, "z": 2}[fit_axis]
        s = size[k] / (hi[k] - lo[k])
        ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
        ob.data.transform(Matrix.Diagonal((s, s, s, 1.0)))
        ob.data.update()
        print("[cath] %s: Tripo part, fit %s -> %s" % (name, fit_axis, [round(v, 1) for v in (hi - lo) * s]), flush=True)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        ob = bpy.context.active_object
        ob.data.transform(Matrix.Translation(Vector((0, 0, 0.5))))
        ob.data.transform(Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
        ob.data.update()
        ob.name = "Cath_%s_PLACEHOLDER" % name
        ob.data.materials.append(GREY)
        print("[cath] %s: not made yet -> placeholder %s" % (name, size), flush=True)
    bpy.context.view_layer.update()
    return ob


P = []
base = part("CathStairs", (66, 66, 10), "x")  # the oval platform + front stairs: wider than the body (the 2D platform holds the whole body)
lo_b, hi_b = bbox(base)
top = hi_b.z
body = part("CathBody", (56, 50, 26), "x")
REAL_BODY = not body.name.endswith("PLACEHOLDER")
if REAL_BODY:  # the Tripo body is a deep facade (about 13 deep): stretch it front-to-back into a real hall (like the gate arch)
    lo_, hi_ = bbox(body)
    body.data.transform(Matrix.Diagonal((1.0, opt["body-depth"] / (hi_.y - lo_.y), 1.0, 1.0)))
    body.data.update()
    bpy.context.view_layer.update()
body.location = (0, 0, top)
P += [base, body]
bpy.context.view_layer.update()
lo, hi = bbox(body)
dome = part("CathDome", (30, 30, 22), "x")


def metal_from_color(ob):
    """이미지 생성 3: the Tripo dome's metallic map came out rainbow -> metal / roughness from the colour (gold = metal 0.9 rough 0.28,
    the rest 0 / 0.62; the pbr_from_color.py gold mask), fed to the Principled inputs so the glTF export packs them"""
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
        gold = ((hue >= 20) & (hue <= 58) & (sat >= 0.4) & (mx >= 0.5)).astype(np.float32)  # linear values: 0.5 ~ sRGB 0.73
        for nm, val in (("metal", gold * 0.9), ("rough", gold * 0.28 + (1 - gold) * 0.62)):
            out = bpy.data.images.new(ob.name + "_" + nm, w, h, alpha=False, is_data=True)
            out.pixels.foreach_set(np.repeat(val[:, None], 4, axis=1).ravel())
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = out
            t.image.colorspace_settings.name = "Non-Color"
            for l in list(bsdf.inputs["Metallic" if nm == "metal" else "Roughness"].links):
                nt.links.remove(l)
            nt.links.new(t.outputs["Color"], bsdf.inputs["Metallic" if nm == "metal" else "Roughness"])
        print("[cath] %s: metal / roughness rebuilt from the colour (gold %.0f %%)" % (ob.name, 100 * gold.mean()), flush=True)


if not dome.name.endswith("PLACEHOLDER"):
    metal_from_color(dome)
dome.location = (0, (lo.y + hi.y) / 2, hi.z - 0.3)
P.append(dome)
# corner towers, A and B crossed so left and right differ
for kind, cx, cy in (("CathTowerA", -1, -1), ("CathTowerB", 1, -1), ("CathTowerB", -1, 1), ("CathTowerA", 1, 1)):
    t = part(kind, (8, 8, 30), "z")
    t.location = (cx * (hi.x - 3.0), (lo.y + 3.0) if cy < 0 else (hi.y - 3.0), top)
    t.name = "Cath_%s_%s%s" % (kind, "F" if cy < 0 else "B", "L" if cx < 0 else "R")
    P.append(t)
# entrance: door frame on the body front, two leaves inside (closed, they open in play later)
frame = part("CathDoorFrame", (10, 2, 14), "z")
frame.location = (0, lo.y - 0.2, top)
P.append(frame)
lo_f, hi_f = bbox(frame)
for side in (-1, 1):
    leaf = part("CathDoorLeaf", ((hi_f.x - lo_f.x) * 0.4, 0.6, 12), "x")  # each leaf about 0.4 of the frame width (the Tripo leaf came with its own rim)
    lw = (bbox(leaf)[1].x - bbox(leaf)[0].x)
    leaf.location = (side * lw / 2, lo.y + 0.2, top + 0.2)
    leaf.name = "Cath_DoorLeaf" + ("L" if side < 0 else "R")
    P.append(leaf)
# arched windows on the front (only on the placeholder body: the real body has its own windows and rose window)
for k, (wx, wz) in enumerate((() if REAL_BODY else ((-18, 8.5), (-11, 9.5), (11, 9.0), (18, 8.0)))):
    w = part("CathWindow", (4, 1, 8), "z")
    w.location = (wx, lo.y - 0.1, top + wz)
    w.name = "Cath_Window%d" % (k + 1)
    P.append(w)
bpy.context.view_layer.update()
LO = Vector([min(bbox(o)[0][k] for o in P) for k in range(3)])
HI = Vector([max(bbox(o)[1][k] for o in P) for k in range(3)])
print("[cath] size", [round(v, 1) for v in (HI - LO)], flush=True)

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
rad = max(HI - LO) * 2.3
os.makedirs(RDIR, exist_ok=True)
for name, dv in (("front", Vector((0, -1, 0.15))), ("front34", Vector((0.7, -1, 0.4))), ("back34", Vector((-0.7, 1, 0.4)))):
    dv.normalize()
    cam.location = c + dv * rad
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(RDIR, "cath_asm_" + name + ".png")
    bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action="DESELECT")
for o in P:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[cath] ok", OUT, flush=True)
