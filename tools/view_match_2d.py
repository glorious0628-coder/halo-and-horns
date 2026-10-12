"""Render a GLB framed exactly like each approved 2D view (Blender 손보기, 10/12; user: compare with the 2D, fix every
smear / unclear line / mushy part). Flat texture shading (= the colour map as it is), orthographic, the model's box in
that view fitted onto the 2D character box (tools/npc_face_bbox.py), so 2D and render can be laid side by side / cropped
at the same place.

  blender --background --factory-startup --python tools/view_match_2d.py -- <in.glb> <out_prefix> <2d_prefix> [--px 2048]
      2d_prefix e.g. art/out/s2/npc2_hq/NPC_HaloMailBoy_  -> uses <2d_prefix>{front,back,left,right}_HQ_src.png
      [--front -y]  for Tripo Studio exports that face -y
  -> <out_prefix>_{front,back,left,right}.png (left/right = camera on the model's +y / -y side, named like the 2D files
     after checking which 2D side matches; see SIDE below)
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
GLB, PRE, P2 = a[0], a[1], a[2]
PX = int(a[a.index("--px") + 1]) if "--px" in a else 2048
# camera direction for each 2D file (Tripo front = +x). 2D 'left' file = the viewer-left name used by the 2D sheet:
# the image of the character's right side -> camera on the model's -y side (checked on MailBoy: bag strap side)
SIDE = {"front": (1, 0, 0), "back": (-1, 0, 0), "left": (0, -1, 0), "right": (0, 1, 0)}
# --front -y : Tripo Studio exports (Smart Mesh / 텍스처, bottom-centre pivot) face Blender -y instead of +x
if "--front" in a and a[a.index("--front") + 1] == "-y":
    SIDE = {"front": (0, -1, 0), "back": (0, 1, 0), "left": (-1, 0, 0), "right": (1, 0, 0)}


def bbox2d_np(path):
    img = bpy.data.images.load(os.path.abspath(path))
    w, h = img.size
    px = np.array(img.pixels[:], np.float32).reshape(h, w, -1)[::-1, :, :3] * 255
    c = np.median(np.concatenate([px[:8, :8].reshape(-1, 3), px[:8, -8:].reshape(-1, 3), px[-8:, :8].reshape(-1, 3), px[-8:, -8:].reshape(-1, 3)]), axis=0)
    ys, xs = np.nonzero(np.abs(px - c).sum(-1) > 40)
    return xs.min(), ys.min(), xs.max(), ys.max(), w, h


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(GLB))
obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
V = np.array([(o.matrix_world @ v.co)[:] for o in obs for v in o.data.vertices])
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "TEXTURE"
sc.view_settings.view_transform = "Standard"
sc.display.shading.background_type = "VIEWPORT"
sc.display.shading.background_color = (0.42, 0.43, 0.45)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
for name, d in SIDE.items():
    p2 = f"{P2}{name}_HQ_src.png"
    x0, y0, x1, y1, W, H = bbox2d_np(p2)
    d = Vector(d)
    rot = (-d).to_track_quat("-Z", "Y")
    right = rot @ Vector((1, 0, 0))
    up = rot @ Vector((0, 1, 0))
    u = V @ np.array(right[:])
    v = V @ np.array(up[:])
    # metres per 2D pixel from the height; the box centres line up
    mpp = (v.max() - v.min()) / (y1 - y0)
    cu, cv = (u.max() + u.min()) / 2, (v.max() + v.min()) / 2
    # world point at the image centre
    du = (W / 2 - (x0 + x1) / 2) * mpp
    dv = -(H / 2 - (y0 + y1) / 2) * mpp
    ctr = Vector(right) * (cu + du) + Vector(up) * (cv + dv)
    cam.data.ortho_scale = W * mpp
    cam.location = ctr + d * 5
    cam.rotation_euler = rot.to_euler()
    sc.render.resolution_x = sc.render.resolution_y = PX
    sc.render.filepath = os.path.abspath(f"{PRE}_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("VIEW", name, "m/px", round(mpp, 6))
