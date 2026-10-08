"""Paint white eye highlights onto a monster's base-colour texture by projecting from the front camera (style drift
#25: the cube slime's black eyes have no highlight; eye rule = black oval + 1-2 highlights). 0 credits, Blender.
The eyes are split over several UV islands, so the dots are placed in screen space and ray-cast onto the mesh.

  blender --background --factory-startup --python tools/img2/mon_eye_highlight.py -- <in.glb> <tex.png> <out_tex.png>
          <render_dir> [--res 1024] [--dot 0.24] [--dot2 0.11]

1. render the front (monster faces +X) with the texture -> <render_dir>/eye_front.png
2. find the two largest dark blobs in the face area = eyes; per eye a big dot (radius dot * eye width) at the top over the
   texture's own small grey highlight and a small dot (dot2) low-left
3. for every screen pixel inside a dot, cast a ray from the camera; the hit's UV gets white (soft 1.5 px edge)
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import barycentric_transform

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, TEX, OUT, RD = [os.path.abspath(a) for a in argv[:4]]


def opt(n, d):
    return float(argv[argv.index(n) + 1]) if n in argv else d


RES, DOT, DOT2 = int(opt("--res", 1024)), opt("--dot", 0.24), opt("--dot2", 0.11)
os.makedirs(RD, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = RES
w = bpy.data.worlds.new("W")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.world = w
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in sc.objects if o.type == "MESH"]
img = bpy.data.images.load(TEX)
for o in meshes:
    for m in o.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.image = img
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:  # flat emission-like look for eye detection: no speculars
            bsdf.inputs["Roughness"].default_value = 1.0
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
centre, radius = (lo + hi) / 2, (hi - lo).length / 2
cd = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
cd.lens = 50
fov = 2 * math.atan(cd.sensor_width / 2 / cd.lens)
dist = radius / math.sin(fov / 2) * 1.02
cam.location = centre + Vector((1, 0, 0)) * dist  # front = +X, straight on
cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = os.path.join(RD, "eye_front.png")
bpy.ops.render.render(write_still=True)

r = np.array(bpy.data.images.load(sc.render.filepath).pixels[:], dtype=np.float32).reshape(RES, RES, 4)[::-1]
lum = r[..., :3].max(-1)
dark = (lum < 0.22) & (r[..., 3] > 0.5)
# connected blobs (simple flood fill on a coarse grid)
from collections import deque
seen = np.zeros_like(dark)
blobs = []
for y0, x0 in zip(*np.nonzero(dark)):
    if seen[y0, x0]:
        continue
    q = deque([(y0, x0)])
    seen[y0, x0] = True
    pix = []
    while q:
        y, x = q.popleft()
        pix.append((y, x))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < RES and 0 <= nx < RES and dark[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    if len(pix) > RES * RES * 0.0008:
        p = np.array(pix)
        blobs.append((len(pix), p[:, 1].min(), p[:, 1].max(), p[:, 0].min(), p[:, 0].max()))
# eyes = the two largest blobs that are roughly the same size and side by side (the mouth is wider than tall)
blobs.sort(reverse=True)
eyes = [b for b in blobs if (b[4] - b[3]) > (b[2] - b[1]) * 1.05][:2]
print("[eye] blobs", blobs[:5], "eyes", eyes, flush=True)
dots = []
for _, x0, x1, y0, y1 in eyes:
    ew, eh = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    dots.append((cx + 0.02 * ew, cy - 0.26 * eh, DOT * ew))   # over the texture's small grey highlight
    dots.append((cx - 0.2 * ew, cy + 0.24 * eh, DOT2 * ew))

# ray-cast every pixel of each dot onto the mesh; paint UV texels white
tw, th = img.size
tex = np.array(img.pixels[:], dtype=np.float32).reshape(th, tw, 4)
dg = bpy.context.evaluated_depsgraph_get()
frame = cd.view_frame(scene=sc)  # camera-space corners: top-right, bottom-right, bottom-left, top-left
tr, bl, tl = frame[0], frame[2], frame[3]
mw_cam = cam.matrix_world
painted = 0
uvl = {o.name: o.data.uv_layers.active.data for o in meshes}
for (dx, dy, rad) in dots:
    for py in range(int(dy - rad - 2), int(dy + rad + 3)):
        for px in range(int(dx - rad - 2), int(dx + rad + 3)):
            dd = math.hypot(px - dx, py - dy)
            a = min(1.0, max(0.0, (rad + 0.75 - dd) / 1.5))
            if a <= 0:
                continue
            u, v = (px + 0.5) / RES, (py + 0.5) / RES
            pc = tl + (tr - tl) * u + (bl - tl) * v
            d = (mw_cam.to_3x3() @ pc).normalized()
            ok, loc, nrm, fi, ob, _ = sc.ray_cast(dg, cam.location, d)
            if not ok:
                continue
            me = ob.data
            poly = me.polygons[fi]
            mi = ob.matrix_world.inverted()
            lp = mi @ loc
            vs = [me.vertices[i].co for i in poly.vertices]
            uvs = [uvl[ob.name][li].uv for li in poly.loop_indices]
            # triangles of the polygon (fan); pick the one containing the point
            for k in range(1, len(vs) - 1):
                tri = (vs[0], vs[k], vs[k + 1])
                uvt = (uvs[0].to_3d(), uvs[k].to_3d(), uvs[k + 1].to_3d())
                uvp = barycentric_transform(lp, *tri, *uvt)
                if -0.01 <= uvp.x <= 1.01 and -0.01 <= uvp.y <= 1.01:
                    tx, ty = int(uvp.x * tw) % tw, int(uvp.y * th) % th
                    for oy in (0, 1):
                        for ox in (0, 1):
                            yy, xx = min(th - 1, ty + oy), min(tw - 1, tx + ox)
                            tex[yy, xx, :3] = tex[yy, xx, :3] * (1 - a) + np.array([1.0, 1.0, 1.0]) * a
                    painted += 1
                    break
img.pixels[:] = tex.ravel()
img.filepath_raw = OUT
img.file_format = "PNG"
img.save()
print("[eye] dots", [(round(a, 1), round(b, 1), round(c, 1)) for a, b, c in dots], "painted", painted, flush=True)
