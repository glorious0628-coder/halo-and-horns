"""Contact sheet of GLBs (front 3/4, workbench textured). 
  blender --background --factory-startup --python tools/blender_kit_sheet.py -- <out_dir> <a.glb> <b.glb> ...
Writes <out_dir>/<name>.png (480x480 each); tools/sheet_compose.py-style composing is done by the caller with PIL."""
import math, os, sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out, files = argv[0], argv[1:]
os.makedirs(out, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x = sc.render.resolution_y = 480
sc.render.film_transparent = False
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_shadows = False
w = bpy.data.worlds.new("w"); w.color = (0.78, 0.8, 0.84); sc.world = w
for f in files:
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=f)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            v = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, v)); hi = Vector(map(max, hi, v))
    ctr = (lo + hi) / 2; size = max(hi - lo)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera = cam
    d = size * 1.9
    cam.location = ctr + Vector((d * 0.6, -d * 0.75, d * 0.45))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = 1000
    name = os.path.splitext(os.path.basename(f))[0]
    sc.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)
