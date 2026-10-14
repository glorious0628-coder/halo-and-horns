"""최종 검수 PBR final gate renders (A23-154 step 4, second look after 디자인 검수).
Independent of tools/design_review/pbr_gate.py (sun-follows-camera):
  - albedo  : Workbench FLAT + texture colour = the colour map exactly as painted (baked shadows / stains show as-is)
  - studio  : Workbench STUDIO light + texture = shape read, same light every view
  - lit q34 : EEVEE, fixed world sun + sky, PBR as imported (metal/rough look)
  - f_big   : albedo front at <big> px for 100% crops
Views (front = -Y for .glb from build_glb / touch-up): f (camera -Y), l (camera -X = 2D `_left`, front to image right),
r (camera +X = 2D `_right`), b (camera +Y), top (camera +Z). One ortho scale for f/l/r/b so sizes compare.
Writes <out>/<name>__<kind>_<view>.png (RGBA, transparent film) and <out>/<name>__stats.json.
blender --background --factory-startup --python final_gate.py -- <out_dir> <px> <big_px> <file.glb|file.fbx[@+x]> ...
Raw Tripo FBX faces +X: it is turned so +X -> -Y before rendering (default for .fbx; add @-y to skip).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
out, px, big = os.path.abspath(a[0]), int(a[1]), int(a[2])
os.makedirs(out, exist_ok=True)

GAME_TEX = 1024
VIEWS = {
    "f": Vector((0, -1, 0)),
    "l": Vector((-1, 0, 0)),
    "r": Vector((1, 0, 0)),
    "b": Vector((0, 1, 0)),
    "top": Vector((0.0001, -0.0001, 1)),
    "q34": Vector((0.8, -1.0, 0.75)),
}


def load(path, front):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".glb") or path.lower().endswith(".gltf"):
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(path))
    else:
        bpy.ops.import_scene.fbx(filepath=os.path.abspath(path))
    sc = bpy.context.scene
    if front == "+x":
        from mathutils import Matrix
        rot = Matrix.Rotation(math.radians(-90), 4, "Z")
        for o in sc.objects:
            if o.parent is None:
                o.matrix_world = rot @ o.matrix_world
        bpy.context.view_layer.update()
    obs = [o for o in sc.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return sc, obs, lo, hi


def stats(sc, obs, lo, hi):
    dg = bpy.context.evaluated_depsgraph_get()
    tris = 0
    for o in obs:
        me = o.evaluated_get(dg).to_mesh()
        tris += sum(len(p.vertices) - 2 for p in me.polygons)
        o.evaluated_get(dg).to_mesh_clear()
    imgs = []
    for im in bpy.data.images:
        if im.size[0]:
            imgs.append([im.name, im.size[0], im.size[1]])
    dark = None
    base = None
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                ln = n.inputs["Base Color"].links
                if ln and ln[0].from_node.type == "TEX_IMAGE":
                    base = ln[0].from_node.image
    if base is not None and base.size[0]:
        import numpy as np
        w, h = base.size
        p = np.empty(w * h * 4, dtype=np.float32)
        base.pixels.foreach_get(p)
        p = p.reshape(-1, 4)[:: max(1, (w * h) // 250000)]
        p = p[p[:, 3] >= 0.5]
        lum = 0.2126 * p[:, 0] + 0.7152 * p[:, 1] + 0.0722 * p[:, 2]
        dark = round(float((lum < 0.06).mean()) if len(lum) else 0.0, 4)
    ctr = (lo + hi) / 2
    return {
        "objects": [[o.name, o.type] for o in sc.objects],
        "meshes": len(obs),
        "materials": len([m for m in bpy.data.materials if m.users]),
        "tris": tris,
        "size_xyz": [round(v, 3) for v in (hi - lo)],
        "pivot_offset_xy": [round(ctr.x, 3), round(ctr.y, 3)],
        "min_z": round(lo.z, 3),
        "images": imgs,
        "base_dark_frac": dark,
    }


def set_active_base(sc):
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                ln = n.inputs["Base Color"].links
                if ln and ln[0].from_node.type == "TEX_IMAGE":
                    m.node_tree.nodes.active = ln[0].from_node


def camera(sc):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    return cam


def basis(d):
    d = d.normalized()
    right = (-d).cross(Vector((0, 0, 1)))
    if right.length < 1e-4:
        right = Vector((1, 0, 0))
    right.normalize()
    up = right.cross(-d).normalized()
    return d, right, up


def extent(lo, hi, d):
    ctr = (lo + hi) / 2
    d, right, up = basis(d)
    cs = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    return max(abs((c - ctr).dot(right)) for c in cs) * 2, max(abs((c - ctr).dot(up)) for c in cs) * 2


def aim(cam, lo, hi, d, scale):
    ctr = (lo + hi) / 2
    d, right, up = basis(d)
    dist = (hi - lo).length * 3 + 10
    cam.location = ctr + d * dist
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scale
    cam.data.clip_start = 0.01
    cam.data.clip_end = dist * 3


def render(sc, path, res):
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def workbench(sc, light):
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light = light
    sh.color_type = "TEXTURE"
    sh.show_backface_culling = False
    sh.show_shadows = False
    sh.show_cavity = False
    sc.display.render_aa = "16"


def eevee(sc, cam_dir):
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.72, 0.78, 0.88, 1)
    bg.inputs[1].default_value = 0.55
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 2.2
    sc.collection.objects.link(sun)
    # fixed world sun: from front-left, 55 deg up (not following the camera)
    sd = Vector((-0.6, -0.8, 1.35)).normalized()
    sun.rotation_euler = (-sd).to_track_quat("-Z", "Y").to_euler()


for f in a[3:]:
    front = None
    if "@" in f:
        f, front = f.rsplit("@", 1)
    elif f.lower().endswith(".fbx"):
        front = "+x"
    name = os.path.basename(f)
    for suf in ("_TU.glb", "_SM_tex4k_pbr_src.fbx", "_SM_tex8k_pbr_src.fbx", ".glb", ".fbx"):
        if name.endswith(suf):
            name = name[: -len(suf)]
            break
    try:
        sc, obs, lo, hi = load(f, front)
        st = stats(sc, obs, lo, hi)
        # game size: Roblox SurfaceAppearance uses 1024 maps -> judge what the player sees (and render fast)
        for im in bpy.data.images:
            if im.size[0] > GAME_TEX:
                im.scale(GAME_TEX, GAME_TEX)
        set_active_base(sc)
        cam = camera(sc)
        side = max(max(extent(lo, hi, VIEWS[v])) for v in ("f", "l", "r", "b")) * 1.06
        workbench(sc, "FLAT")
        for v in ("f", "l", "r", "b", "top"):
            sz = side if v != "top" else max(extent(lo, hi, VIEWS[v])) * 1.06
            aim(cam, lo, hi, VIEWS[v], sz)
            render(sc, os.path.join(out, f"{name}__albedo_{v}.png"), px)
        aim(cam, lo, hi, VIEWS["f"], side)
        render(sc, os.path.join(out, f"{name}__albedo_fbig.png"), big)
        workbench(sc, "STUDIO")
        for v in ("f", "l", "r", "b"):
            aim(cam, lo, hi, VIEWS[v], side)
            render(sc, os.path.join(out, f"{name}__studio_{v}.png"), px)
        eevee(sc, VIEWS["q34"])
        aim(cam, lo, hi, VIEWS["q34"], max(extent(lo, hi, VIEWS["q34"])) * 1.06)
        render(sc, os.path.join(out, f"{name}__lit_q34.png"), px)
        st["side_ortho"] = round(side, 3)
        json.dump(st, open(os.path.join(out, f"{name}__stats.json"), "w"), indent=1)
        print("DONE", name, st["tris"], st["size_xyz"], flush=True)
    except Exception as e:  # keep going for the other files
        print("FAIL", name, repr(e), flush=True)
