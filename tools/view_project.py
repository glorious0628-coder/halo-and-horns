"""Blender (background): paint a mesh with our own 2D 4 views by orthographic PROJECTION - no AI, no credits (A23-168, user
10/13: "구조물만 대강 만들고 그 위에 디자인 입히기"). Every face takes the view its normal faces most (front / left / right /
back / top=front), the view image is projected orthographically onto it, and the result is baked into the mesh's own UV map
as one base-colour PNG. Seams show where views meet at ~45 deg; fine for toy props seen from a few metres.

  blender --background --factory-startup --python tools/view_project.py -- <in.glb> <out.glb> <front.png> <left.png> <right.png> <back.png> [size]

Conventions: GLB front = -Y after import (Roblox/Meshy -Z front -> Blender -Y). Our 2D views: left view shows the object's
left side (camera on -X looking +X), right view camera on +X, back camera on +Y. The object region in each 2D image is found
from the non-background pixels (plain grey/white background) so the silhouettes line up with the mesh bounds.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = a[0], a[1]
views = {"front": a[2], "left": a[3], "right": a[4], "back": a[5]}
SIZE = int(a[6]) if len(a) > 6 else 2048
HEIGHT_RATIO = float(a[7]) if len(a) > 7 else 0.0
EXTEND = int(a[8]) if len(a) > 8 else 120  # edge-extend passes (pixels) for the background  # optional: force mesh height = ratio * width (match the 2D silhouette)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.active_object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = obj.data
if HEIGHT_RATIO > 0:
    co0 = np.array([v.co[:] for v in me.vertices])
    w0 = co0[:, 0].max() - co0[:, 0].min()
    h0 = co0[:, 2].max() - co0[:, 2].min()
    zmin = co0[:, 2].min()
    k = (HEIGHT_RATIO * w0) / max(h0, 1e-6)
    for v in me.vertices:
        v.co.z = zmin + (v.co.z - zmin) * k
    print("VIEWPROJ squashed height x%.3f" % k)
if not me.uv_layers:
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
base_uv = me.uv_layers[0]
base_uv.name = "UVMap"
proj_uv = me.uv_layers.new(name="proj")

# object bounds
co = np.array([v.co[:] for v in me.vertices])
mn, mx = co.min(0), co.max(0)
size = mx - mn


def load_view(path):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "sRGB"
    W, H = img.size
    arr = np.empty(W * H * img.channels, np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(H, W, img.channels)
    rgb = arr[:, :, :3]
    # background = the colour at the corners; object = pixels that differ from it
    bg = np.median(np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[-8:, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)]), 0)
    diff = np.abs(rgb - bg).sum(2) > 0.12
    if img.channels == 4 and arr[:, :, 3].min() < 0.5:  # a real alpha cutout: use it (an opaque PNG has alpha 1 everywhere)
        diff = arr[:, :, 3] > 0.5
    print("VIEWPROJ", os.path.basename(path), "object px %.1f%%" % (100.0 * diff.mean()))
    # edge-extend: fill the background with the nearest object colour so faces that project outside the drawn
    # silhouette (the mesh is never exactly the 2D shape) get leaf/flower colour, not grey
    fill = rgb.copy()
    m = diff.copy()
    for _ in range(int(EXTEND)):
        if m.all():
            break
        pad = np.pad(fill, ((1, 1), (1, 1), (0, 0)), mode="edge")
        pm = np.pad(m, ((1, 1), (1, 1)), mode="edge")
        acc = np.zeros_like(fill)
        cntn = np.zeros(m.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy == 0 and dx == 0:
                    continue
                sl = pad[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]
                sm = pm[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]
                acc += sl * sm[:, :, None]
                cntn += sm
        new = cntn > 0
        grow = new & ~m
        fill[grow] = (acc[grow] / cntn[grow][:, None])
        m = m | grow
    arr2 = arr.copy()
    arr2[:, :, :3] = fill
    img.pixels.foreach_set(arr2.reshape(-1))
    tmp = os.path.join(os.path.dirname(os.path.abspath(dst)), "_fill_" + os.path.basename(path))
    img.filepath_raw = tmp
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    img = bpy.data.images.load(tmp)  # Cycles bakes from the file, so reload the filled copy
    img.colorspace_settings.name = "sRGB"
    ys, xs = np.where(diff)
    if len(xs) == 0:
        x0, x1, y0, y1 = 0, W - 1, 0, H - 1
    else:
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    # Blender image rows: row 0 = bottom. Return region in UV units (0..1): u0,u1,v0,v1 (v0 = bottom of object)
    return img, (x0 / W, (x1 + 1) / W, y0 / H, (y1 + 1) / H)


imgs = {k: load_view(p) for k, p in views.items()}

# which axes each view maps: (u_axis, u_sign, v_axis) ; v is always +Z (up)
#  front: camera at -Y looking +Y -> screen right = +X
#  back : camera at +Y looking -Y -> screen right = -X
#  left : camera at -X looking +X -> screen right = -Y  (object's left side; its front (-Y) appears on screen right)
#  right: camera at +X looking -X -> screen right = +Y
AXES = {"front": (0, 1.0), "back": (0, -1.0), "left": (1, -1.0), "right": (1, 1.0)}


def pick_view(n):
    ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
    if az > ax and az > ay and n.z > 0:
        return "front"  # top faces borrow the front view (our top view is not drawn)
    if az > ax and az > ay:
        return "front"
    if ay >= ax:
        return "front" if n.y < 0 else "back"
    return "right" if n.x > 0 else "left"


# materials per view
mats = {}
for k, (img, _) in imgs.items():
    m = bpy.data.materials.new("proj_" + k)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "proj"
    nt.links.new(uvn.outputs[0], tex.inputs[0])
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    mats[k] = m
me.materials.clear()
order = ["front", "left", "right", "back"]
for k in order:
    me.materials.append(mats[k])
slot = {k: i for i, k in enumerate(order)}

uvl = proj_uv.data
cnt = {k: 0 for k in order}
for poly in me.polygons:
    k = pick_view(poly.normal)
    poly.material_index = slot[k]
    cnt[k] += 1
    img, (u0, u1, v0, v1) = imgs[k]
    ua, us = AXES[k]
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index].co
        tu = (v[ua] - mn[ua]) / max(size[ua], 1e-6)
        if us < 0:
            tu = 1.0 - tu
        tv = (v.z - mn[2]) / max(size[2], 1e-6)
        uvl[li].uv = (u0 + tu * (u1 - u0), v0 + tv * (v1 - v0))
print("VIEWPROJ faces per view", cnt)

# bake the projected colour into the base UV map
bake_img = bpy.data.images.new("baked", SIZE, SIZE, alpha=False)
for m in mats.values():
    nt = m.node_tree
    bn = nt.nodes.new("ShaderNodeTexImage")
    bn.image = bake_img
    uvb = nt.nodes.new("ShaderNodeUVMap")
    uvb.uv_map = "UVMap"
    nt.links.new(uvb.outputs[0], bn.inputs[0])
    nt.nodes.active = bn
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.device = "CPU"
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
scene.render.bake.margin = 8
me.uv_layers.active = base_uv
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.bake(type="DIFFUSE")
png = os.path.splitext(dst)[0] + "_basecolor.png"
bake_img.filepath_raw = png
bake_img.file_format = "PNG"
bake_img.save()
print("VIEWPROJ baked", png)

# final material: one slot with the baked image on UVMap
final = bpy.data.materials.new("baked_mat")
final.use_nodes = True
nt = final.node_tree
bsdf = nt.nodes["Principled BSDF"]
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = bake_img
nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.55
me.materials.clear()
me.materials.append(final)
for poly in me.polygons:
    poly.material_index = 0
me.uv_layers.remove(proj_uv)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True)
print("VIEWPROJ saved", dst)
