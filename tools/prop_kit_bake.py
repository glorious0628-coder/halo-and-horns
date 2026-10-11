"""Comparison test C / D2 for the tools/prop_kit.py kits (이미지 생성 4, 10/11, 디자인 검수 request "선이 없어 보여"):

C  = (--tag C, default values = 디자인 검수 spec) the kit's flat-coloured parts (marble, blue, slate, dark, paint, candle) joined into ONE mesh with one baked colour map:
     base colour x faint grain x AO (all parts occlude, distance = --ao x kit height, warm grey-brown, lowest ~0.78)
     x concave -11 % (AO in creases) x convex +5 % (inside-AO on edges), multiplied in linear, saved sRGB.
     Gold / wood / cloth / leaf / soil / lamp parts stay normal Studio parts (gold keeps HH_HaloGoldTrim).
D2 = inverted hull (--hull): every solid part joined, pushed out --hull-t studs along the normals (even thickness),
     faces flipped, one dark-brown colour: Roblox draws only its back side = an outline round the silhouette.

  blender --background --factory-startup --python tools/prop_kit_bake.py -- <out_dir> <kit.json> [...]
          [--px 1024] [--samples 128] [--ao 0.05] [--warm 0.78] [--cav 0.11] [--cvx 0.05] [--tag C]
          [--hull] [--hull-t 0.035] [--hull-only] [--preview]

Writes <out_dir>/<Kit>_C_mesh.obj, <Kit>_C_color.png, [<Kit>_D2_hull.obj], <Kit>_bake.json (tris, part counts, where the
mesh centre sits in Roblox coordinates: MeshPart CFrame = kit pivot * CFrame.new(centre)), and with --preview Blender
renders <Kit>_prev_{A,C[,D2]}.png. Axes: OBJ is Roblox-ready (Y up, front -Z = tools/prop_kit.py r3).
Nothing is uploaded here: uploads go through 최종 검수 approval (이미지 개발 uploads).
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prop_kit_bl import bounds, build_kit, s2l  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("kits", nargs="+")
ap.add_argument("--px", type=int, default=1024)
ap.add_argument("--samples", type=int, default=128)
ap.add_argument("--ao", type=float, default=0.05)
ap.add_argument("--warm", type=float, default=0.78, help="mean multiplier at full AO occlusion")
ap.add_argument("--cav", type=float, default=0.11, help="darkening in creases")
ap.add_argument("--cvx", type=float, default=0.05, help="lightening on edges")
ap.add_argument("--tag", default="C", help="output tag (C = 디자인 검수 values, e.g. Cs = stronger try)")
ap.add_argument("--hull", action="store_true")
ap.add_argument("--hull-t", type=float, default=0.035)
ap.add_argument("--hull-only", action="store_true", help="only the D2 hull (<Kit>_D2_<t*1000>.obj), no colour bake")
ap.add_argument("--hull-min", type=float, default=0.0, help="hull only round parts whose smallest size >= this (디자인 검수 10/12: 0.12 = no seams / thin bands / window frames)")
ap.add_argument("--hull-big", type=float, default=0.0, help="... and whose largest size >= this (0.3)")
ap.add_argument("--preview", action="store_true")
a = ap.parse_args(argv)
a.out = os.path.abspath(a.out)
os.makedirs(a.out, exist_ok=True)

BAKE = {"marble", "mblock", "stone", "blue", "slate", "dark", "paint", "candle", "pcream", "groove"}
NO_HULL = {"lamp", "neon", "glass", "water"}
# marble under HH_HaloMarbleSmooth_Cream reads about this cream; SurfaceAppearance ignores the MaterialVariant
BASE = {"marble": (237, 231, 220), "mblock": (237, 231, 220), "stone": (232, 226, 212)}
WARM = tuple(c - 0.7833 + a.warm for c in (0.82, 0.78, 0.75))   # full occlusion multiplier (warm grey-brown, not black)
HULL_RGB = (74, 50, 36)


def lin(rgb):
    return tuple(s2l(c / 255) for c in rgb)


def select_only(obs, active):
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        if o is not None:                     # removed objects can linger as None until the layer refreshes
            o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def join(obs, name):
    select_only(obs, obs[0])
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    select_only([ob], ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def bake_material(src, img, height):
    """Copy of src whose emission = base x grain x AO x concave x convex, with img as the active bake target."""
    m = src.copy()
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    N = nt.nodes.new
    out = N("ShaderNodeOutputMaterial")
    emit = N("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    key = src.name.split("_")[0]
    base_rgb = BASE.get(key)
    if base_rgb is None:
        r, g, b = [int(x) for x in src.name.split("_")[1:4]]
        base_rgb = (r, g, b)
    base = N("ShaderNodeRGB")
    base.outputs[0].default_value = (*lin(base_rgb), 1)
    # faint grain (marble only)
    tex = N("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 1.6
    tex.inputs["Detail"].default_value = 4.0
    grain = N("ShaderNodeMapRange")
    grain.inputs["To Min"].default_value = 0.985 if key in BASE else 1.0
    grain.inputs["To Max"].default_value = 1.015 if key in BASE else 1.0
    nt.links.new(tex.outputs["Fac"], grain.inputs["Value"])
    # big AO -> warm multiplier
    ao = N("ShaderNodeAmbientOcclusion")
    ao.samples = 32
    ao.inputs["Distance"].default_value = a.ao * height
    warm = N("ShaderNodeRGB")
    warm.outputs[0].default_value = (*WARM, 1)
    occl = N("ShaderNodeMix")
    occl.data_type = "RGBA"
    nt.links.new(ao.outputs["AO"], occl.inputs[0])
    nt.links.new(warm.outputs[0], occl.inputs[6])
    occl.inputs[7].default_value = (1, 1, 1, 1)
    # concave: small AO in creases
    cav = N("ShaderNodeAmbientOcclusion")
    cav.samples = 24
    cav.inputs["Distance"].default_value = 0.06
    cavf = N("ShaderNodeMapRange")            # AO 1 -> 1.0, AO <= 0.6 -> 1 - cav
    cavf.inputs["From Min"].default_value = 0.6
    cavf.inputs["From Max"].default_value = 1.0
    cavf.inputs["To Min"].default_value = 1.0 - a.cav
    cavf.inputs["To Max"].default_value = 1.0
    nt.links.new(cav.outputs["AO"], cavf.inputs["Value"])
    # convex: inside-AO on edges
    cvx = N("ShaderNodeAmbientOcclusion")
    cvx.samples = 24
    cvx.inside = True
    cvx.only_local = True
    cvx.inputs["Distance"].default_value = 0.04
    cvxf = N("ShaderNodeMapRange")            # AO 1 -> 1.0, AO <= 0.6 -> 1 + cvx
    cvxf.inputs["From Min"].default_value = 0.6
    cvxf.inputs["From Max"].default_value = 1.0
    cvxf.inputs["To Min"].default_value = 1.0 + a.cvx
    cvxf.inputs["To Max"].default_value = 1.0
    nt.links.new(cvx.outputs["AO"], cvxf.inputs["Value"])
    # base x grain x occl x cav x cvx (all linear)
    cur = base.outputs[0]
    for f in (grain.outputs[0], occl.outputs[2], cavf.outputs[0], cvxf.outputs[0]):
        mul = N("ShaderNodeVectorMath")
        mul.operation = "MULTIPLY"
        nt.links.new(cur, mul.inputs[0])
        if f.type == "VALUE":
            comb = N("ShaderNodeCombineXYZ")
            for i in range(3):
                nt.links.new(f, comb.inputs[i])
            nt.links.new(comb.outputs[0], mul.inputs[1])
        else:
            nt.links.new(f, mul.inputs[1])
        cur = mul.outputs[0]
    nt.links.new(cur, emit.inputs["Color"])
    it = N("ShaderNodeTexImage")
    it.image = img
    nt.nodes.active = it
    return m


def baked_material(img):
    m = bpy.data.materials.new("Baked")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    it = m.node_tree.nodes.new("ShaderNodeTexImage")
    it.image = img
    m.node_tree.links.new(it.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6
    return m


def make_hull(K, t):
    coll = bpy.data.collections.new("hull_src")
    bpy.context.scene.collection.children.link(coll)
    obs = build_kit(K, coll, segments=24)
    size = {t["n"]: t["size"] for t in K["parts"]}

    def big(o):
        n = o.name
        if len(n) > 4 and n[-4] == "." and n[-3:].isdigit():   # Blender's .001 on repeated part names
            n = n[:-4]
        sz = size.get(n)
        if sz is None:                       # CSG-renamed objects keep the part name; unknown = keep
            return True
        return min(sz) >= a.hull_min and max(sz) >= a.hull_big
    floor = bounds(obs)[0].z
    keep = [o for o in obs if o.get("pk_mat") not in NO_HULL and big(o)]
    for o in obs:
        if o not in keep:
            bpy.data.objects.remove(o)
    h = join(keep, "D2_Hull")
    bm = bmesh.new()
    bm.from_mesh(h.data)
    bm.normal_update()
    # 디자인 검수 10/12: no hull under the kit - faces on the ground (facing down, near the floor) are dropped so the bottom
    # corners are not pushed down / out into a thick black band, and nothing is left below the floor
    down = [f for f in bm.faces if f.normal.z < -0.7 and max(v.co.z for v in f.verts) < floor + 0.06]
    bmesh.ops.delete(bm, geom=down, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * t * min(v.calc_shell_factor(), 3.0)
        if v.co.z < floor - 0.01:
            v.co.z = floor - 0.01
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(h.data)
    bm.free()
    h.data.materials.clear()
    m = bpy.data.materials.new("Hull")
    m.use_nodes = True
    nt = m.node_tree
    pb = nt.nodes["Principled BSDF"]
    pb.inputs["Base Color"].default_value = (*lin(HULL_RGB), 1)
    pb.inputs["Roughness"].default_value = 0.9
    m.use_backface_culling = True
    # preview only: Cycles draws both sides, Roblox culls back faces -> show the hull only where it faces the camera
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(pb.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    h.data.materials.append(m)
    # preview only: seen from inside the hull is all front faces -> keep it out of shadow / bounce rays
    h.visible_shadow = h.visible_diffuse = h.visible_glossy = h.visible_transmission = h.visible_volume_scatter = False
    return h


def export_obj(ob, path):
    select_only([ob], ob)
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y",
                          export_materials=False, export_uv=True, export_normals=True, apply_modifiers=True,
                          export_triangulated_mesh=True)


def r3(v):
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def setup_render(sc, px, samples):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 3
    sc.render.resolution_x = sc.render.resolution_y = px
    sc.render.film_transparent = False


def preview(sc, obs, label, path, mn, mx):
    size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    ctr = (mn + mx) / 2
    if "pv_cam" not in bpy.data.objects:
        w = bpy.data.worlds.new("w")
        sc.world = w
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.72, 1)
        w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
        sun = bpy.data.objects.new("pv_sun", bpy.data.lights.new("pv_sun", "SUN"))
        sun.data.energy = 3.2
        sun.data.angle = math.radians(3)
        sun.rotation_euler = (math.radians(48), 0, math.radians(215))
        sc.collection.objects.link(sun)
        me = bpy.data.meshes.new("pv_ground")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size * 3)
        bm.to_mesh(me)
        bm.free()
        g = bpy.data.objects.new("pv_ground", me)
        g.location = (ctr.x, ctr.y, mn.z - 0.001)
        gm = bpy.data.materials.new("pv_ground")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*lin((196, 188, 172)), 1)
        me.materials.append(gm)
        sc.collection.objects.link(g)
        cam = bpy.data.objects.new("pv_cam", bpy.data.cameras.new("pv_cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.lens = 50
        # the kit faces +y (tools/prop_kit.py frame): front 3/4 like the Studio "q34" photo
        d = Vector((-math.sin(math.radians(35)), math.cos(math.radians(35)), math.tan(math.radians(14))))
        d.normalize()
        cam.location = ctr + d * (size * 2.6)
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    for o in bpy.data.objects:
        if o.type == "MESH" and not o.name.startswith("pv_"):
            o.hide_render = o not in obs
    sc.render.filepath = path
    print("[bake] preview", label, flush=True)
    bpy.ops.render.render(write_still=True)


def do_kit(path):
    K = json.load(open(path))
    name = K["name"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    print("[bake] build", name, len(K["parts"]), flush=True)
    obs = build_kit(K, sc.collection)
    mn, mx = bounds(obs)
    height = mx.z - mn.z
    stats = {"kit": name, "tag": a.tag, "warm": [round(c, 3) for c in WARM], "cav": a.cav, "cvx": a.cvx,
             "parts": len(obs), "height": round(height, 3), "ao_distance": round(a.ao * height, 3)}
    if a.preview:
        setup_render(sc, 640, 32)
        preview(sc, obs, "A", os.path.join(a.out, name + "_prev_A.png"), mn, mx)
    if a.hull_only:
        tag = "D2_%03d" % round(a.hull_t * 1000)
        h = make_hull(K, a.hull_t)
        hmn, hmx = bounds([h])
        stats.update({"tag": tag, "D2_tris": tris(h), "D2_thickness": a.hull_t, "hull_min": a.hull_min, "hull_big": a.hull_big, "D2_center_roblox": r3((hmn + hmx) / 2),
                      "D2_size_roblox": [round(hmx.x - hmn.x, 4), round(hmx.z - hmn.z, 4), round(hmx.y - hmn.y, 4)]})
        export_obj(h, os.path.join(a.out, "%s_%s.obj" % (name, tag)))
        if a.preview:
            setup_render(sc, 640, 32)
            preview(sc, obs + [h], tag, os.path.join(a.out, "%s_prev_%s.png" % (name, tag)), mn, mx)
        json.dump(stats, open(os.path.join(a.out, "%s_%s.json" % (name, tag)), "w"), indent=1)
        print("[bake] done", json.dumps(stats), flush=True)
        return
    bake_obs = [o for o in obs if o.get("pk_mat") in BAKE]
    if not bake_obs:
        print("[bake] nothing to bake in", name)
        return
    rest = [o for o in obs if o not in bake_obs]
    stats["bake_parts"] = len(bake_obs)
    stats["parts_left"] = len(rest)
    stats["parts_left_by_mat"] = {}
    for o in rest:
        stats["parts_left_by_mat"][o["pk_mat"]] = stats["parts_left_by_mat"].get(o["pk_mat"], 0) + 1
    bm_ob = join(bake_obs, "C_Mesh")
    # UVs
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.012)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new(name + "_" + a.tag + "_color", a.px, a.px, alpha=False)
    mats = [bake_material(s.material, img, height) for s in bm_ob.material_slots]
    for i, m in enumerate(mats):
        bm_ob.material_slots[i].material = m
    setup_render(sc, a.px, a.samples)
    sc.render.bake.margin = 8
    sc.render.bake.margin_type = "EXTEND"
    select_only([bm_ob], bm_ob)
    print("[bake] baking", name, "tris", tris(bm_ob), flush=True)
    bpy.ops.object.bake(type="EMIT", margin=8, use_clear=True)
    img.filepath_raw = os.path.join(a.out, name + "_" + a.tag + "_color.png")
    img.file_format = "PNG"
    img.save()
    stats["C_tris"] = tris(bm_ob)
    cmn, cmx = bounds([bm_ob])
    stats["C_center_roblox"] = r3((cmn + cmx) / 2)
    stats["C_size_roblox"] = [round(cmx.x - cmn.x, 4), round(cmx.z - cmn.z, 4), round(cmx.y - cmn.y, 4)]
    export_obj(bm_ob, os.path.join(a.out, name + "_" + a.tag + "_mesh.obj"))
    bm_ob.data.materials.clear()
    bm_ob.data.materials.append(baked_material(img))
    if a.preview:
        setup_render(sc, 640, 32)
        preview(sc, [bm_ob] + rest, a.tag, os.path.join(a.out, name + "_prev_" + a.tag + ".png"), mn, mx)
    if a.hull:
        h = make_hull(K, a.hull_t)
        stats["D2_tris"] = tris(h)
        stats["D2_thickness"] = a.hull_t
        hmn, hmx = bounds([h])
        stats["D2_center_roblox"] = r3((hmn + hmx) / 2)
        stats["D2_size_roblox"] = [round(hmx.x - hmn.x, 4), round(hmx.z - hmn.z, 4), round(hmx.y - hmn.y, 4)]
        export_obj(h, os.path.join(a.out, name + "_D2_hull.obj"))
        if a.preview:
            setup_render(sc, 640, 32)
            preview(sc, [bm_ob, h] + rest, "D2", os.path.join(a.out, name + "_prev_D2.png"), mn, mx)
    json.dump(stats, open(os.path.join(a.out, name + "_" + a.tag + "_bake.json"), "w"), indent=1)
    print("[bake] done", json.dumps(stats), flush=True)


for k in a.kits:
    do_kit(k)
