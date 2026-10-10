"""Blender helper for tools/zone_split_batch.py (이미지 개발 2026-10-10).

  blender --background --factory-startup --python tools/zone_split_bundle.py -- bundle <zone> <work> <bundle_dir> <prefix> <mb> <names>
  blender --background --factory-startup --python tools/zone_split_bundle.py -- shots  <zone> <work> <shots_dir> "<name|src|kind|fit|mode|before;...>"

bundle: imports <work>/<name>_split.glb for each name and writes import bundles <prefix><i>_<Zone>Split.glb (about <mb> MB each,
        whole models only) + <same>_list.json: one row per tile mesh (name, group = model, tris, size_studs X,Y(height),Z).
shots:  for each model two renders from the same camera (front 3/4, close enough to see texture detail):
        <name>_before.png = source mesh with its colour shrunk to one 1024 (the in-game look before), roughness 0.6, metal 0;
        <name>_after.png  = the split tiles with their colour / normal / metal-rough maps.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
MODE = argv[0]


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def world_box(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    return lo, hi


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


if MODE == "bundle":
    import json
    zone, work, bdir, prefix, mb, names = argv[1], argv[2], argv[3], argv[4], float(argv[5]), argv[6].split(",")
    os.makedirs(bdir, exist_ok=True)
    groups, cur, size = [], [], 0.0
    for n in names:
        p = os.path.join(work, n + "_split.glb")
        s = os.path.getsize(p) / 1e6
        if cur and size + s > mb:
            groups.append(cur)
            cur, size = [], 0.0
        cur.append(n)
        size += s
    if cur:
        groups.append(cur)
    Zone = zone[:1].upper() + zone[1:]
    for gi, g in enumerate(groups, 1):
        clear()
        rows = []
        for n in g:
            objs = import_glb(os.path.join(work, n + "_split.glb"))
            for o in objs:
                if o.type == "MESH":
                    mw = o.matrix_world.copy()
                    o.parent = None
                    o.matrix_world = mw
            for o in objs:
                if o.type != "MESH":
                    bpy.data.objects.remove(o, do_unlink=True)
            for o in [o for o in objs if o.name in bpy.data.objects and o.type == "MESH"]:
                lo, hi = world_box([o])
                rows.append({"name": o.name, "group": n, "tris": tris(o),
                             "size_studs": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
                             "maps": sorted({nd.image.name.rsplit("_", 1)[-1] if nd.image.name.endswith(("_n", "_mr")) else "color"
                                             for m in o.data.materials for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE" and nd.image})})
        out = os.path.join(bdir, f"{prefix}{gi}_{Zone}Split.glb")
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_image_format="AUTO",
                                  export_animations=False, export_skins=False)
        with open(out[:-4] + "_list.json", "w", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, indent=1)
        print(f"[bundle] {os.path.basename(out)} {os.path.getsize(out) / 1e6:.1f}MB models {len(g)} meshes {len(rows)}: {', '.join(g)}", flush=True)

elif MODE == "shots":
    zone, work, shots, spec = argv[1], argv[2], argv[3], argv[4]

    def setup_scene():
        sc = bpy.context.scene
        for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
            try:
                sc.render.engine = eng
                break
            except TypeError:
                continue
        sc.render.resolution_x = sc.render.resolution_y = 768
        sc.render.film_transparent = True  # alpha = model mask for the crop picker; sheets composite on grey
        w = bpy.data.worlds.new("w")
        sc.world = w
        w.use_nodes = True
        bg = w.node_tree.nodes["Background"]
        sky = w.node_tree.nodes.new("ShaderNodeTexSky")
        try:
            sky.sky_type = "HOSEK_WILKIE"
        except TypeError:
            pass
        w.node_tree.links.new(sky.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 1.0
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 5.0
        sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(215))  # light from the front-left (front = +Y)
        sc.collection.objects.link(sun)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.lens = 50
        sc.collection.objects.link(cam)
        sc.camera = cam
        return cam

    def aim(cam, lo, hi, frac=0.55):
        c = (lo + hi) / 2
        d = hi - lo
        size = max(d.x, d.y, d.z)
        # close-up: the camera sees about 55% of the model's largest side (texture detail, same distance both shots);
        # frac 1.25 = the whole model
        dist = size * frac / (2 * math.tan(cam.data.angle / 2))
        direction = Vector((0.55, 1.0, 0.35)).normalized()
        target = Vector((c.x, hi.y - d.y * 0.25, c.z + d.z * 0.05)) if frac < 1 else c
        cam.location = target + direction * (dist + d.y * 0.25)
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()

    def render(path):
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)

    def load_src(src, kind, fit):
        """The source mesh with split_uv_tiles.py's orientation / fit rules (front +Y, fit max studs, bottom centre at 0)."""
        objs = [o for o in import_glb(src) if o.type == "MESH"]
        for o in objs:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        for o in list(bpy.context.scene.objects):
            if o.type == "EMPTY":
                bpy.data.objects.remove(o, do_unlink=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        turn = math.radians(90) if kind == "tripo" else math.radians(180)
        obj.matrix_world = Matrix.Rotation(turn, 4, "Z") @ obj.matrix_world
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        blo, bhi = world_box([obj])
        d = bhi - blo
        s = fit / max(d.x, d.y, d.z, 1e-6)
        obj.matrix_world = Matrix.Diagonal((s, s, s, 1.0)) @ obj.matrix_world
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        blo, bhi = world_box([obj])
        obj.data.transform(Matrix.Translation(Vector((-(blo.x + bhi.x) / 2, -(blo.y + bhi.y) / 2, -blo.z))))
        obj.data.update()
        bpy.context.view_layer.update()  # bound_box is stale after a data transform (the camera aimed too low)
        return obj

    def as_before(obj, before):
        """tex: the colour alone (1024), roughness 0.6, metal 0. sa: colour + own normal + roughness, metal 0."""
        for m in obj.data.materials:
            nt = m.node_tree
            bsdf = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
            drop = ("Metallic",) if before == "sa" else ("Metallic", "Roughness", "Normal")
            for link in list(nt.links):
                if link.to_node == bsdf and link.to_socket.name in drop:
                    nt.links.remove(link)
            bsdf.inputs["Metallic"].default_value = 0.0
            if before != "sa":
                bsdf.inputs["Roughness"].default_value = 0.6
            for x in nt.nodes:
                if x.type == "TEX_IMAGE" and x.image and x.image.size[0] > 1024:
                    x.image.scale(1024, 1024)

    def with_maps(obj, files):
        """New material from the four SA images (C colour, N normal, M metal, R rough)."""
        m = bpy.data.materials.new(obj.name + "_sa")
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]

        def tex(path, non_color):
            node = nt.nodes.new("ShaderNodeTexImage")
            node.image = bpy.data.images.load(path)
            if non_color:
                node.image.colorspace_settings.name = "Non-Color"
            return node

        nt.links.new(tex(files["C"], False).outputs["Color"], bsdf.inputs["Base Color"])
        if "M" in files:
            nt.links.new(tex(files["M"], True).outputs["Color"], bsdf.inputs["Metallic"])
        if "R" in files:
            nt.links.new(tex(files["R"], True).outputs["Color"], bsdf.inputs["Roughness"])
        if "N" in files:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tex(files["N"], True).outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        obj.data.materials.clear()
        obj.data.materials.append(m)

    for item in spec.split(";"):
        n, src, kind, fit, mode, before = item.split("|")
        fit = float(fit)
        sc = None
        # after
        clear()
        cam = setup_scene()
        sc = bpy.context.scene
        if mode == "split":
            objs = [o for o in import_glb(os.path.join(work, n + "_split.glb")) if o.type == "MESH"]
        else:
            obj = load_src(src, kind, fit)
            root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(work))))
            d = os.path.join(root, "art", "ui", f"sa_{zone}")
            files = {t: os.path.join(d, f"{n}_{t}.png") for t in "CNMR" if os.path.isfile(os.path.join(d, f"{n}_{t}.png"))}
            with_maps(obj, files)
            objs = [obj]
        lo, hi = world_box(objs)
        # whole model (for the 2D | 3D pair)
        aim(cam, lo, hi, 1.5)
        render(os.path.join(shots, n + "_after_full.png"))
        # close-up at 1536 (100% crops are cut from this)
        sc.render.resolution_x = sc.render.resolution_y = 1536
        aim(cam, lo, hi)
        render(os.path.join(shots, n + "_after.png"))
        cam_mw = cam.matrix_world.copy()
        # tile-id pass (flat colour per tile mesh) to find tile seams in the close-up
        if len(objs) > 1:
            eng = sc.render.engine
            sc.render.engine = "BLENDER_WORKBENCH"
            sc.display.shading.light = "FLAT"
            sc.display.shading.color_type = "OBJECT"
            # exact flat colours: no colour management, dither or anti-aliasing (every pixel = its tile's colour)
            vt, dith = sc.view_settings.view_transform, sc.render.dither_intensity
            sc.view_settings.view_transform = "Standard"
            sc.render.dither_intensity = 0
            try:
                sc.display.render_aa = "OFF"
            except (TypeError, AttributeError):
                pass
            for i, o in enumerate(objs):
                o.color = (((i * 67) % 255) / 255, ((i * 131 + 40) % 255) / 255, ((i * 197 + 90) % 255) / 255, 1)
            sc.render.filepath = os.path.join(shots, n + "_tileid.png")
            bpy.ops.render.render(write_still=True)
            sc.render.engine = eng
            sc.view_settings.view_transform, sc.render.dither_intensity = vt, dith
        # before = the in-game look today
        clear()
        cam = setup_scene()
        obj = load_src(src, kind, fit)
        as_before(obj, before)
        cam.matrix_world = cam_mw
        bpy.context.scene.render.resolution_x = bpy.context.scene.render.resolution_y = 1536
        render(os.path.join(shots, n + "_before.png"))
        print(f"[shots] {n}", flush=True)
