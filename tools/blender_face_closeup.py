"""Face close-up render of a slime GLB with a texture (workbench, studio light): blender --background --factory-startup --python tools/blender_face_closeup.py -- <glb> <tex.png> <out.png>"""
import math
import sys
import bpy
from mathutils import Vector

GLB, TEX, OUT = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
body = [x for x in bpy.context.scene.objects if x.type == "MESH"][0]
im = bpy.data.images.load(TEX)
for m in body.data.materials:
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            n.image = im
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.studio_light = "rim.sl"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_shadows = True
sc.display.shading.background_type = "VIEWPORT"
sc.display.shading.background_color = (0.85, 0.85, 0.85)
cd = bpy.data.cameras.new("C")
cd.type = "ORTHO"
cd.ortho_scale = 0.62
cam = bpy.data.objects.new("C", cd)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.resolution_x = sc.render.resolution_y = 900
c = Vector((0.36, 0.0, -0.02))
for name, off in (("front", (3, 0, 0.0)), ("q", (2.5, -1.4, 0.6))):
    cam.location = c + Vector(off)
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = OUT.replace(".png", f"_{name}.png")
    bpy.ops.render.render(write_still=True)
