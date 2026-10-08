"""
Render a PBR prop (Tripo web GLB: base colour + normal + metal/rough) with only its base-colour texture swapped,
several jobs in one Blender session (0 credits). Made from acc_render.py for the crossroads supporter board.

  blender --background --factory-startup --python tools/img2/prop_render.py -- <jobs.json>

jobs.json = [{"glb": abs path, "tex": abs path or null (= the GLB's own), "out": abs path prefix}, ...]
-> <out>_front34.png, <out>_game.png (640 px, transparent). Same light and the same front34 / game angles as
tools/tex_compare_render.py (white sky 0.9 + sun 2.2, Standard view). Front = -Y (web GLBs: check with a render first).
"""
import json
import math
import sys

import bpy
from mathutils import Vector

jobs = json.load(open(sys.argv[sys.argv.index("--") + 1], encoding="utf-8"))
RES = 640
VIEWS = {"front34": (30, 12, 50), "game": (20, 35, 50)}


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = RES
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 0.9
    sc.world = w
    sd = bpy.data.lights.new("Sun", "SUN")
    sd.energy = 2.2
    sd.angle = math.radians(8)
    sun = bpy.data.objects.new("Sun", sd)
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam, cd


for job in jobs:
    sc, cam, cd = setup_scene()
    bpy.ops.import_scene.gltf(filepath=job["glb"])
    meshes = [o for o in sc.objects if o.type == "MESH"]
    if job.get("tex"):
        img = bpy.data.images.load(job["tex"])
        img.colorspace_settings.name = "sRGB"
        for o in meshes:
            for m in o.data.materials:
                if not m or not m.node_tree:
                    continue
                bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if not bsdf or not bsdf.inputs["Base Color"].is_linked:
                    continue
                n = bsdf.inputs["Base Color"].links[0].from_node
                while n.type != "TEX_IMAGE" and n.inputs and n.inputs[0].is_linked:
                    n = n.inputs[0].links[0].from_node
                if n.type == "TEX_IMAGE":
                    n.image = img
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre, radius = (lo + hi) / 2, (hi - lo).length / 2
    for name, (az, el, lens) in VIEWS.items():
        cd.lens = lens
        fov = 2 * math.atan(cd.sensor_width / 2 / lens)
        dist = radius / math.sin(fov / 2) * 1.02
        a, e = math.radians(az), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        cam.location = centre + d * dist
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = job["out"] + f"_{name}.png"
        bpy.ops.render.render(write_still=True)
print("[prop_render] ok", len(jobs), flush=True)
