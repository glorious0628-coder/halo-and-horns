"""Open a visible Blender window showing 2D front | Tripo original | cleaned GLB side by side (Blender 손보기, 10/12).
Fixed scene only (no remote commands). Flat texture shading, front orthographic view.

  blender --factory-startup build/blender_live/start.blend --python tools/blender_view.py -- <2d_front.png> <tripo.glb> <clean.glb> [--face 0.215]
  (start.blend = an empty saved file, so the splash screen does not cover the view)
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P2D, SRC, NEW = (os.path.join(ROOT, x) for x in a[:3])
FACE = float(a[a.index("--face") + 1]) if "--face" in a else None
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()


def imp(path, dy, tag):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in set(bpy.data.objects) - before:
        if o.parent is None:
            o.location.y += dy
        o.name = tag + "_" + o.name


imp(SRC, 0.0, "Tripo")
imp(NEW, 0.4, "Clean")
img = bpy.data.images.load(P2D)
px = np.array(img.pixels[:], np.float32).reshape(img.size[1], img.size[0], -1)[::-1, :, :3]
c = np.median(np.concatenate([px[:8, :8].reshape(-1, 3), px[:8, -8:].reshape(-1, 3)]), axis=0)
ys, xs = np.nonzero(np.abs(px - c).sum(-1) > 40 / 255)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
Wd, Hd = img.size
s = 0.98 / (y1 - y0)
bpy.ops.mesh.primitive_plane_add(size=1)
p = bpy.context.active_object
p.name = "2D_front"
p.rotation_euler = (math.radians(90), 0, math.radians(90))
p.scale = (Wd * s, Hd * s, 1)
p.location = (0.05, -0.4 + ((x0 + x1) / 2 - Wd / 2) * s, (Hd / 2 - (y0 + y1) / 2) * s)
m = bpy.data.materials.new("2D")
m.use_nodes = True
t = m.node_tree.nodes.new("ShaderNodeTexImage")
t.image = img
m.node_tree.links.new(t.outputs[0], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
p.data.materials.append(m)


def setup_view():
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type != "VIEW_3D":
                continue
            sp = area.spaces.active
            sp.shading.type = "SOLID"
            sp.shading.light = "FLAT"
            sp.shading.color_type = "TEXTURE"
            sp.overlay.show_overlays = False
            sp.show_gizmo = False
            r3 = sp.region_3d
            r3.view_rotation = Vector((-1, 0, 0)).to_track_quat("-Z", "Y")
            r3.view_perspective = "ORTHO"
            if FACE is None:
                r3.view_location, r3.view_distance = Vector((0, 0, 0.02)), 1.9
            else:
                r3.view_location, r3.view_distance = Vector((0, 0, FACE)), 0.45
            area.tag_redraw()
    return None


bpy.app.timers.register(setup_view, first_interval=0.5)
