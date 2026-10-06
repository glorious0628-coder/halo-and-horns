"""
Look at / patch the base-colour texture of a Tripo GLB without making a new model (0 credits).

  blender --background --factory-startup --python tools/glb_texture_patch.py -- render <in.glb> <out_dir> <label> [--tex new.png] [--front +x] [--views front,front34,game] [--add-crystal x,y,z,size]
  blender --background --factory-startup --python tools/glb_texture_patch.py -- pick   <in.glb> <out.json> --px x,y[;x,y...] [--front +x] [--view front]
  blender --background --factory-startup --python tools/glb_texture_patch.py -- export <in.glb> <out.glb> --tex new.png

- Same normalisation, light and cameras as tools/compare_3d_render.py (height 2, EEVEE, 768 px), plus a straight "front" view.
- pick: casts a ray from the chosen view through render pixels and prints the hit UV and texture pixel
  (so you can find a window or an eye in the 4096 texture).
- render --tex: swaps the base-colour image for a patched PNG (same size) to compare before/after.
- render --add-crystal: adds a simple glowing amber crystal (8 faces) at a normalised position, to try a shape fix.
- export: writes a GLB with the patched texture (only after the picture was approved).
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
MODE, IN_GLB, OUT = argv[0], argv[1], argv[2]


def opt(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


FRONT = opt("--front", "+x")
YAW = {"-y": 0, "+x": 90, "+y": 180, "-x": 270}[FRONT]
TEX = opt("--tex")
VIEWS_ALL = {"front": (0, 8), "front34": (30, 12), "front34L": (-30, 12), "back34": (210, 12), "game": (20, 35),
             "back": (180, 8), "back34L": (150, 12), "left": (-90, 8), "right": (90, 8)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def base_images():
    out = []
    for o in meshes:
        for m in o.data.materials:
            if not m or not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    link = n.inputs["Base Color"].links
                    if link and link[0].from_node.type == "TEX_IMAGE":
                        out.append(link[0].from_node.image)
    return out


if TEX:
    # packed GLB images ignore a new filepath on reload: load the patched PNG as a new image and point the
    # base-colour texture nodes at it (keeps the original colour space)
    new_img = bpy.data.images.load(os.path.abspath(TEX))
    for o in meshes:
        for m in o.data.materials:
            if not m or not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    link = n.inputs["Base Color"].links
                    if link and link[0].from_node.type == "TEX_IMAGE":
                        node = link[0].from_node
                        new_img.colorspace_settings.name = node.image.colorspace_settings.name
                        node.image = new_img
    new_img.pack()

if MODE == "export":
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB")
    print("[glb_texture_patch] exported", OUT, flush=True)
    sys.exit(0)


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


root = bpy.data.objects.new("Root", None)
bpy.context.scene.collection.objects.link(root)
for o in bpy.context.scene.objects:
    if o.parent is None and o is not root:
        o.parent = root
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
s = 2.0 / max(hi.z - lo.z, 1e-6)
root.scale = (s, s, s)
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
centre = (lo + hi) / 2
radius = (hi - lo).length / 2

scene = bpy.context.scene
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
bgn = world.node_tree.nodes["Background"]
bgn.inputs[0].default_value = (1, 1, 1, 1)
bgn.inputs[1].default_value = 0.9
scene.world = world
sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 2.2
sun_d.angle = math.radians(8)
sun = bpy.data.objects.new("Sun", sun_d)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35 + YAW))
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 768
cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
fov = 2 * math.atan(cam_data.sensor_width / 2 / cam_data.lens)
dist = radius / math.sin(fov / 2) * 1.05


def place(view):
    az, el = VIEWS_ALL[view]
    a, e = math.radians(az + YAW), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = centre + d * dist
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()


if "--add-crystal" in argv:
    x, y, z, size = (float(v) for v in opt("--add-crystal").split(","))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=4, ring_count=2, radius=1, location=(x, y, z))
    cr = bpy.context.active_object
    cr.scale = (size * 0.55, size * 0.55, size)
    mat = bpy.data.materials.new("Crystal")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (1.0, 0.62, 0.12, 1)
    b.inputs["Emission Color"].default_value = (1.0, 0.55, 0.1, 1)
    b.inputs["Emission Strength"].default_value = 1.5
    b.inputs["Roughness"].default_value = 0.25
    cr.data.materials.append(mat)

if MODE == "screen":
    # world points (normalised space, e.g. from a pick json) -> render pixel coords for a view
    from bpy_extras.object_utils import world_to_camera_view
    place(opt("--view", "front"))
    out = []
    for trip in opt("--world").split(";"):
        p = Vector([float(v) for v in trip.split(",")])
        c = world_to_camera_view(scene, cam, p)
        out.append([round(c.x * 768, 1), round((1 - c.y) * 768, 1), round(c.z, 3)])
    json.dump(out, open(OUT, "w"))
    print("[glb_texture_patch] screen", json.dumps(out), flush=True)
    sys.exit(0)

if MODE == "project":
    # screen-space decal -> texture texels. Writes <OUT>.npy rows (tx, ty, r, g, b, a) for every ray hit.
    # decal: RGBA PNG of the render size (768); RGB = colour to write into the texture, A > 0 = where.
    import numpy as np
    view = opt("--view", "front")
    ss = int(opt("--ss", "6"))
    place(view)
    deps = bpy.context.evaluated_depsgraph_get()
    tr, br, bl, tl = cam.data.view_frame(scene=scene)
    rot = cam.matrix_world.to_3x3()
    imgs = base_images()
    tw, th = imgs[0].size[0], imgs[0].size[1]
    dec = bpy.data.images.load(os.path.abspath(opt("--decal")))
    dw, dh = dec.size
    px = np.array(dec.pixels[:], dtype=np.float32).reshape(dh, dw, 4)[::-1]  # top-down
    ys, xs = np.nonzero(px[..., 3] > 0.01)
    rows = []
    cache = {}
    for y, x in zip(ys, xs):
        col = px[y, x]
        for sy in range(ss):
            for sx in range(ss):
                u = (x + (sx + 0.5) / ss) / dw
                v = (y + (sy + 0.5) / ss) / dh
                d = (rot @ (tl + (tr - tl) * u + (bl - tl) * v)).normalized()
                hit, loc, normal, index, obj, _ = scene.ray_cast(deps, cam.location, d)
                if not hit:
                    continue
                key = obj.name
                if key not in cache:
                    ev = obj.evaluated_get(deps)
                    cache[key] = (ev, ev.to_mesh(), obj.matrix_world.inverted())
                ev, me, inv = cache[key]
                poly = me.polygons[index]
                lp = inv @ loc
                uvl = me.uv_layers.active.data
                vs = list(poly.vertices)
                ls = list(poly.loop_indices)
                from mathutils.geometry import barycentric_transform, intersect_point_tri
                uvp = None
                for k in range(1, len(vs) - 1):
                    a, b2, c = me.vertices[vs[0]].co, me.vertices[vs[k]].co, me.vertices[vs[k + 1]].co
                    if len(vs) > 3 and intersect_point_tri(lp, a, b2, c) is None:
                        continue
                    uvp = barycentric_transform(lp, a, b2, c, uvl[ls[0]].uv.to_3d(), uvl[ls[k]].uv.to_3d(), uvl[ls[k + 1]].uv.to_3d())
                    break
                if uvp is None:
                    continue
                rows.append((uvp.x * tw, (1 - uvp.y) * th, col[0], col[1], col[2], col[3]))
    np.save(OUT, np.array(rows, dtype=np.float32))
    print("[glb_texture_patch] project hits", len(rows), "tex", tw, th, flush=True)
    sys.exit(0)

if MODE == "faces":
    # UV triangles (texture pixels) of the faces near given world points (from a pick json, same normalisation)
    picks = json.load(open(opt("--picks")))["picks"]
    idx = [int(v) for v in opt("--which", ",".join(str(i) for i in range(len(picks)))).split(",")]
    r = float(opt("--radius", "0.07"))
    deps = bpy.context.evaluated_depsgraph_get()
    imgs = base_images()
    tw, th = imgs[0].size[0], imgs[0].size[1]
    out = {"tex_size": [tw, th], "groups": []}
    for i in idx:
        p = Vector(picks[i]["world"])
        tris = []
        for obj in meshes:
            ev = obj.evaluated_get(deps)
            me = ev.to_mesh()
            mw = obj.matrix_world
            uvl = me.uv_layers.active.data
            for poly in me.polygons:
                c = mw @ poly.center
                if (c - p).length > r:
                    continue
                ls = list(poly.loop_indices)
                for k in range(1, len(ls) - 1):
                    t = []
                    for li in (ls[0], ls[k], ls[k + 1]):
                        u, v = uvl[li].uv
                        t.append([u * tw, (1 - v) * th])
                    tris.append(t)
            ev.to_mesh_clear()
        out["groups"].append({"pick": i, "world": picks[i]["world"], "tris": tris})
        print("[glb_texture_patch] faces", i, len(tris), flush=True)
    json.dump(out, open(OUT, "w"))
    sys.exit(0)

if MODE == "pick":
    view = opt("--view", "front")
    place(view)
    deps = bpy.context.evaluated_depsgraph_get()
    from bpy_extras.view3d_utils import region_2d_to_vector_3d  # noqa: F401 (not used in background)
    res = []
    W = H = 768
    frame = cam.data.view_frame(scene=scene)  # camera-space corners at distance 1 (top-right, bottom-right, bottom-left, top-left)
    tr, br, bl, tl = frame
    imgs = base_images()
    tw, th = (imgs[0].size[0], imgs[0].size[1]) if imgs else (0, 0)
    for pair in opt("--px").split(";"):
        px, py = (float(v) for v in pair.split(","))
        u, v = px / W, py / H
        p_cam = tl + (tr - tl) * u + (bl - tl) * v
        direction = (cam.matrix_world.to_3x3() @ p_cam).normalized()
        hit, loc, normal, index, obj, _ = scene.ray_cast(deps, cam.location, direction)
        if not hit:
            res.append({"px": [px, py], "hit": False})
            continue
        ev = obj.evaluated_get(deps)
        me = ev.to_mesh()
        poly = me.polygons[index]
        inv = obj.matrix_world.inverted()
        lp = inv @ loc
        uvl = me.uv_layers.active.data
        # barycentric on the triangle fan of the polygon
        best = None
        vs = list(poly.vertices)
        ls = list(poly.loop_indices)
        from mathutils.geometry import barycentric_transform
        for k in range(1, len(vs) - 1):
            a, b2, c = (me.vertices[vs[0]].co, me.vertices[vs[k]].co, me.vertices[vs[k + 1]].co)
            ua, ub, uc = (uvl[ls[0]].uv, uvl[ls[k]].uv, uvl[ls[k + 1]].uv)
            uvp = barycentric_transform(lp, a, b2, c, ua.to_3d(), ub.to_3d(), uc.to_3d())
            best = uvp
            break
        ev.to_mesh_clear()
        res.append({"px": [px, py], "hit": True, "uv": [round(best.x, 5), round(best.y, 5)],
                    "tex_px": [round(best.x * tw), round((1 - best.y) * th)], "world": [round(c, 4) for c in loc]})
    json.dump({"view": view, "tex_size": [tw, th], "picks": res}, open(OUT, "w"), indent=1)
    print("[glb_texture_patch] picks", json.dumps(res), flush=True)
    sys.exit(0)

# render
LABEL = argv[3]
os.makedirs(OUT, exist_ok=True)
views = opt("--views", "front,front34,game").split(",")
for v in views:
    place(v)
    scene.render.filepath = os.path.join(os.path.abspath(OUT), f"{LABEL}_{v}.png")
    bpy.ops.render.render(write_still=True)
print("[glb_texture_patch] rendered", LABEL, views, flush=True)
