"""
Step 1 of removing a painted window from a Tripo GLB (Horns castle, user request 2026-10-06), 0 credits.
Blender side: optional decimate, then shoot rays through a screen box around the window in the same "front" view as
tools/glb_texture_patch.py and dump, per screen sample, which texel it hits and that texel's colour.

  blender --background --factory-startup --python tools/castle_window_dump.py -- <in.glb> <out_dir> --screen cx,cy,rx,ry [--view front|front34|front34L|game] [--decimate 10000] [--ss 6] [--front +x]

Writes <out_dir>/dump.npz (texel x/y per sample, valid mask, albedo, box origin, supersampling),
<out_dir>/tex0.png (the original base-colour texture) and <out_dir>/model.glb (decimated, texture untouched).
Step 2: py tools/castle_window_inpaint.py <out_dir>  (OpenCV inpaint in screen space, written back to the texels)
Step 3: blender ... tools/glb_texture_patch.py -- export <out_dir>/model.glb <final.glb> --tex <out_dir>/tex_after.png
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import barycentric_transform, intersect_point_tri

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT = argv[0], os.path.abspath(argv[1])


def opt(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


SCX, SCY, SRX, SRY = (float(v) for v in opt("--screen").split(","))
DEC = int(opt("--decimate", "0"))
SS = int(opt("--ss", "6"))
YAW = {"-y": 0, "+x": 90, "+y": 180, "-x": 270}[opt("--front", "+x")]
VIEWS = {"front": (0, 8), "front34": (30, 12), "front34L": (-30, 12), "game": (20, 35)}
VAZ, VEL = VIEWS[opt("--view", "front")]
PAD = 2.2
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
if DEC:
    tris0 = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris0 > DEC:
        mod = obj.modifiers.new("Dec", "DECIMATE")
        mod.ratio = DEC / tris0
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
# export the (decimated) model with its texture untouched, in the original space
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "model.glb"), export_format="GLB", use_selection=True,
                          export_image_format="JPEG", export_jpeg_quality=92)


def bbox(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


# same normalisation and front camera as glb_texture_patch.py (screen coordinates must match its renders)
root = bpy.data.objects.new("Root", None)
bpy.context.scene.collection.objects.link(root)
obj.parent = root
bpy.context.view_layer.update()
lo, hi = bbox(obj)
s = 2.0 / (hi.z - lo.z)
root.scale = (s, s, s)
bpy.context.view_layer.update()
lo, hi = bbox(obj)
root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
bpy.context.view_layer.update()
MWI = obj.matrix_world.inverted()
scene = bpy.context.scene
scene.render.resolution_x = scene.render.resolution_y = 768
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
lo, hi = bbox(obj)
centre = (lo + hi) / 2
radius = (hi - lo).length / 2
fov = 2 * math.atan(cam_data.sensor_width / 2 / cam_data.lens)
dist = radius / math.sin(fov / 2) * 1.05
a_, e_ = math.radians(VAZ + YAW), math.radians(VEL)
cam.location = centre + Vector((math.sin(a_) * math.cos(e_), -math.cos(a_) * math.cos(e_), math.sin(e_))) * dist
cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
tr, br, bl, tl = cam.data.view_frame(scene=scene)
rot = cam.matrix_world.to_3x3()
me = obj.data
uvl = me.uv_layers.active.data
img = None
for m in me.materials:
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            img = n.image
tw, th = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(th, tw, 4)


def uv_at(local_pt, poly_index):
    poly = me.polygons[poly_index]
    vs, ls = list(poly.vertices), list(poly.loop_indices)
    for k in range(1, len(vs) - 1):
        a, b2, c = me.vertices[vs[0]].co, me.vertices[vs[k]].co, me.vertices[vs[k + 1]].co
        if len(vs) > 3 and intersect_point_tri(local_pt, a, b2, c) is None:
            continue
        return barycentric_transform(local_pt, a, b2, c, uvl[ls[0]].uv.to_3d(), uvl[ls[k]].uv.to_3d(), uvl[ls[k + 1]].uv.to_3d())
    return None


x0, x1 = int(SCX - SRX * PAD), int(SCX + SRX * PAD) + 1
y0, y1 = int(SCY - SRY * PAD), int(SCY + SRY * PAD) + 1
W_, H_ = (x1 - x0) * SS, (y1 - y0) * SS
texel = -np.ones((H_, W_, 2), np.int32)
alb = np.zeros((H_, W_, 3), np.float32)
valid = np.zeros((H_, W_), np.uint8)
for j in range(H_):
    for i in range(W_):
        x = x0 + (i + 0.5) / SS
        y = y0 + (j + 0.5) / SS
        dd = (rot @ (tl + (tr - tl) * (x / 768) + (bl - tl) * (y / 768))).normalized()
        hit, loc, nrm, idx, hobj, _ = scene.ray_cast(deps, cam.location, dd)
        if not hit or hobj != obj:
            continue
        tuv = uv_at(MWI @ loc, idx)
        if tuv is None:
            continue
        tx, ty = int(tuv.x * tw) % tw, int(tuv.y * th) % th
        texel[j, i] = (tx, ty)
        alb[j, i] = px[ty, tx, :3]
        valid[j, i] = 1
np.savez(os.path.join(OUT, "dump.npz"), texel=texel, alb=alb, valid=valid,
         box=np.array([x0, y0, x1, y1, SS]), ellipse=np.array([SCX, SCY, SRX, SRY]))
np.save(os.path.join(OUT, "tex0.npy"), px)  # bottom-up rows, linear float RGBA
print("[castle_window_dump] samples", int(valid.sum()), "of", W_ * H_, "tex", tw, th, flush=True)
