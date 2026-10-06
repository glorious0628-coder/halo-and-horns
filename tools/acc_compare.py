"""
Render rank accessories for review: the same lighting/cameras for a Blender-built GLB and a Tripo GLB, alone and on a
simple block head (game scale).

  blender --background --factory-startup --python tools/acc_compare.py -- <in.glb> <out_dir> <label> [--kind horns|halo] [--tripo]

- --tripo: the model is normalised (Tripo exports arbitrary size, front = +x): scaled to the Blender size of the same
  rank (halo ring width 1.34 studs, horn pair width ~1.5) and turned so its front faces -Y like the Blender ones.
- Views: front (az 0), 3/4 (az -25), head (block head 1.2 studs + accessory, game distance, 160 px).
- Writes <out_dir>/<label>_front.png, _34.png, _head.png and <label>_stats.json (tris).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT, LABEL = argv[0], os.path.abspath(argv[1]), argv[2]
KIND = argv[argv.index("--kind") + 1] if "--kind" in argv else ("halo" if "Halo" in LABEL else "horns")
TRIPO = "--tripo" in argv
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bbox():
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


root = bpy.data.objects.new("Root", None)
bpy.context.scene.collection.objects.link(root)
for o in list(bpy.context.scene.objects):
    if o.parent is None and o is not root:
        o.parent = root
bpy.context.view_layer.update()
if TRIPO:
    root.rotation_euler = (0, 0, math.radians(-90))  # Tripo front +x -> -y
    bpy.context.view_layer.update()
    lo, hi = bbox()
    # pair / ring+wing widths of the Blender set, so every rank sits at the same scale on the head
    WIDTH = {"HornsR3": 1.42, "HornsR4": 1.40, "HornsR5": 1.50, "HaloR3": 2.10, "HaloR4": 2.35, "HaloR5": 2.97}
    target_w = next((w for k, w in WIDTH.items() if k in LABEL), 1.34 if KIND == "halo" else 1.5)
    s = target_w / max(hi.x - lo.x, 1e-6)
    root.scale = (s, s, s)
    bpy.context.view_layer.update()
lo, hi = bbox()
root.location = root.location + Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
bpy.context.view_layer.update()
lo, hi = bbox()

tris = 0
deps = bpy.context.evaluated_depsgraph_get()
for o in meshes:
    m = o.evaluated_get(deps).to_mesh()
    tris += sum(len(p.vertices) - 2 for p in m.polygons)
    o.evaluated_get(deps).to_mesh_clear()

scene = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
scene.render.film_transparent = True
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
scene.world = world
sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 3.4
sun_o = bpy.data.objects.new("Sun", sun_d)
scene.collection.objects.link(sun_o)
sun_o.rotation_euler = (math.radians(50), 0, math.radians(-25))
cam_d = bpy.data.cameras.new("Cam")
cam_d.lens = 60
cam = bpy.data.objects.new("Cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(name, az, el, centre, dist, res):
    scene.render.resolution_x = scene.render.resolution_y = res
    a, e = math.radians(az), math.radians(el)
    cam.location = centre + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"{LABEL}_{name}.png")
    bpy.ops.render.render(write_still=True)


size = hi - lo
c = (lo + hi) / 2
d = max(size.x, size.y, size.z) * 2.2 + 0.4
shoot("front", 0, 10, c, d, 512)
shoot("34", -25, 16, c, d, 512)

if "--export" in argv:
    # normalised accessory for the game: front = +Z in glTF (-Y here), origin at the base centre, studs
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(argv[argv.index("--export") + 1]), export_format="GLB",
                              use_selection=True, export_image_format="JPEG", export_jpeg_quality=92)
    print("[acc_compare] exported", flush=True)

# block head: rounded cube 1.2 studs, accessory on top (halo floats 0.3 above)
bpy.ops.mesh.primitive_cube_add(size=1.2, location=(0, 0, -0.6))
head = bpy.context.active_object
bev = head.modifiers.new("B", "BEVEL")
bev.width = 0.18
bev.segments = 4
hm = bpy.data.materials.new("Skin")
hm.use_nodes = True
hm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.96, 0.80, 0.62, 1)
head.data.materials.append(hm)
if KIND == "halo":
    root.location = root.location + Vector((0, 0, 0.32))
else:
    root.location = root.location + Vector((0, 0, -0.06))
bpy.context.view_layer.update()
shoot("head", -15, 12, Vector((0, 0, -0.2)), 9.0, 160)
json.dump({"label": LABEL, "tris": tris, "size": [round(v, 3) for v in size]}, open(os.path.join(OUT, f"{LABEL}_stats.json"), "w"))
print("[acc_compare]", LABEL, tris, flush=True)
