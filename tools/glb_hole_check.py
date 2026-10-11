"""See-through hole check for GLB models (이미지 생성 4, 10/12): orthographic silhouettes (front +y, side +x) with a
transparent film; transparent pixels that the outside cannot reach are holes. Legit openings (bow / string, staff
curls, hanging charms) show up too - compare with the Tripo source (same check on the _src.glb).

  blender --background --factory-startup --python tools/glb_hole_check.py -- <out_dir> <glob> [<glob> ...]
  -> <out_dir>/<name>_front.png / _side.png + holes.txt (name, view, hole pixels, rows)
"""
import glob
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out = os.path.abspath(a[0])
os.makedirs(out, exist_ok=True)
paths = sorted(p for g in a[1:] for p in glob.glob(g))
rows = []
for p in paths:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.name.endswith("_Outline")]
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o not in obs:
            bpy.data.objects.remove(o)
    W = np.array([(o.matrix_world @ v.co)[:] for o in obs for v in o.data.vertices])
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.film_transparent = True
    span = np.ptp(W, axis=0)
    tall = span[2] >= max(span[0], span[1])
    sc.render.resolution_x, sc.render.resolution_y = (300, 1000) if tall else (800, 800)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = float(max(span)) * 1.05
    ctr = Vector(((W.min(0) + W.max(0)) / 2).tolist())
    name = os.path.splitext(os.path.basename(p))[0]
    for view, d in (("front", Vector((0, 1, 0))), ("side", Vector((1, 0, 0)))):
        cam.location = ctr + d * 50
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        f = os.path.join(out, "%s_%s.png" % (name, view))
        sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(f)
        A = np.array(img.pixels[:]).reshape(img.size[1], img.size[0], 4)[::-1, :, 3] > 0.03
        bpy.data.images.remove(img)
        # flood the outside from the border; whatever transparent stays unreached is a hole
        reach = np.zeros(A.shape, bool)
        stack = [(y, x) for y in range(A.shape[0]) for x in (0, A.shape[1] - 1)] + \
                [(y, x) for x in range(A.shape[1]) for y in (0, A.shape[0] - 1)]
        while stack:
            y, x = stack.pop()
            if reach[y, x] or A[y, x]:
                continue
            reach[y, x] = True
            if y > 0:
                stack.append((y - 1, x))
            if y < A.shape[0] - 1:
                stack.append((y + 1, x))
            if x > 0:
                stack.append((y, x - 1))
            if x < A.shape[1] - 1:
                stack.append((y, x + 1))
        H = ~A & ~reach
        n = int(H.sum())
        ys = np.nonzero(H)[0]
        rows.append("%s\t%s\t%d\t%s" % (name, view, n, "%d-%d" % (ys.min(), ys.max()) if n else ""))
        print("[holes]", rows[-1], flush=True)
open(os.path.join(out, "holes.txt"), "w").write("\n".join(rows) + "\n")
