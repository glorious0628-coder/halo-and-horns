"""Blender touch-up of a Tripo 4-view HD result for the Halo town props (SPEC A23-125 step 2; 이미지 생성 4, 10/12).

The Studio part kits (tools/prop_kit.py) make the exact bodies (pots, posts, stalls); Tripo gives the organic / ornate
part. This keeps only the part we need, makes it light, and bakes Tripo's own look onto a fresh UV layout:

  plant : the Tripo model of the whole 2D (pot + plant) minus everything inside / on the part-built body
          (--body build/prop_kit/<Kit>__Body.json): faces below the body top that sit within the body's footprint
          radius at their height go; leaves hanging outside the pot stay.
  goods : stalls / benches / gardens: faces on or inside the part-built body go (nearest body surface closer than
          --tol, or behind it), the goods sitting on the shelves stay
  head  : a whole lantern -> only what is above the kit's temporary head (parts named Head*, --body = the lantern kit)
  part  : a separate Tripo piece (wall-lamp head, bell) fitted into the box of the kit parts named --part* (height and
          bottom centre), those parts dropped from the preview
  ontop : a piece standing on the body (hedge on its trough): width = the body's x length x --fit w factor, feet on
          the body top
  whole : nothing cut, fit h / w (rocks, basket, watering can, bushes, scarecrow)

Steps: import (Tripo front +X -> kit front +y: --rotz 90) -> feet on z = 0, centred on the lower band -> scale to --fit
(h=<height> / w=<width>, the same world the kit bodies are built in, tools/halo_props_list.txt) -> cut -> drop dust
islands -> weld + decimate to --tris -> smart UV -> bake colour / normal (relief from the full Tripo surface) /
roughness / metalness at --px with tools/proj_bake.py -> GLB + PNGs + stats.

  blender --background --factory-startup --python tools/tripo_touchup.py -- <job> --kind plant|head|whole --fit h=3
          [--body build/prop_kit/<Kit>.json] [--tris 8000] [--px 1024] [--rotz 90] [--out art/models/tripo/touchup]
          [--preview]

In:  art/models/tripo/web/<job>_MV4_HD_src.glb.  Out: <out>/<job>/<job>_TU.glb, <job>_TU_{C,N,R,M,MR}.png,
<job>_TU.json (tris, size, cut numbers), with --preview <job>_TU_{front,left,back,right}.png (body kit drawn too).
Axes: kit frame (x, y = front, z up, studs); the GLB exporter turns it into Roblox axes (Y up, front -Z).
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import proj_bake as PB  # noqa: E402
from prop_kit_bl import bounds, build_kit  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("job")
ap.add_argument("--kind", required=True, choices=["plant", "goods", "head", "part", "ontop", "whole"])
ap.add_argument("--part", default="", help="kind part / head: name prefixes (comma list) of the kit parts it replaces (Head / Bell,Rope)")
ap.add_argument("--fit", default="h=1", help="h=<height> or w=<width> in studs (ontop: w=<factor of the body length>)")
ap.add_argument("--body", default="")
ap.add_argument("--tris", type=int, default=8000)
ap.add_argument("--px", type=int, default=1024)
ap.add_argument("--rotz", type=float, default=90.0)
ap.add_argument("--out", default=os.path.join(ROOT, "art", "models", "tripo", "touchup"))
ap.add_argument("--preview", action="store_true")
ap.add_argument("--outline", type=float, default=0.035, help="thin outline shell (SPEC A23-139) in studs, 0 = none; built on a voxel-remeshed copy so only the silhouette of a leaf mass gets a line, not every leaf")
ap.add_argument("--outline-voxel", type=float, default=0.0, help="voxel size for the outline base (0 = 1.5 %% of the size)")
ap.add_argument("--rim-frac", type=float, default=0.0, help="plant: where the pot rim sits in the 2D front (tools/rim_frac_2d.py); the whole Tripo model is scaled so that height x rim_frac = the body top (the plant keeps the 2D proportion to the pot)")
ap.add_argument("--calib", action="store_true", help="plant: try to match Tripo's gold rim to the body top (off: unreliable, 10/12)")
ap.add_argument("--below-all", action="store_true", help="plant: cut every face under the body top (no hanging leaves; Tripo pot wider than the body)")
ap.add_argument("--tol", type=float, default=0.06, help="studs kept clear round the body")
ap.add_argument("--tolz", type=float, default=0.05, help="plant: how far over the body top the cut reaches")
ap.add_argument("--dust", type=int, default=4, help="drop loose islands with fewer faces (specks; petals are bigger)")
a = ap.parse_args(argv)
OUT = os.path.join(os.path.abspath(a.out), a.job)
os.makedirs(OUT, exist_ok=True)
SRC = os.path.join(ROOT, "art", "models", "tripo", "web", a.job + "_MV4_HD_src.glb")
NAME = a.job + "_TU"
stats = {"job": a.job, "kind": a.kind, "fit": a.fit, "src": os.path.relpath(SRC, ROOT).replace("\\", "/")}


def log(*m):
    print("[touchup]", *m, flush=True)


def select_only(obs, active):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def body_rim_top(obs):
    """Top of the pot itself: the highest body object at least half as wide as the widest one (finial balls on the rim
    do not count - Topiary_E's rim balls made the hedge float, 10/12)."""
    spans = []
    for o in obs:
        W = np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])
        spans.append((W[:, 2].max(), max(np.ptp(W[:, 0]), np.ptp(W[:, 1]))))     # the object's own width
    wmax = max(w for _, w in spans)
    return max(z for z, w in spans if w >= 0.5 * wmax)


# ---------------------------------------------------------------- 1. load, turn, place, scale
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        o.select_set(False)
select_only(meshes, meshes[0])
if len(meshes) > 1:
    bpy.ops.object.join()
src = bpy.context.view_layer.objects.active
mw = src.matrix_world.copy()
src.parent = None
src.matrix_world = mw
src.name = "TripoSrc"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o is not src:
        bpy.data.objects.remove(o)
me = src.data
me.transform(Matrix.Rotation(math.radians(a.rotz), 4, "Z"))
V = np.array([v.co[:] for v in me.vertices])
z0, z1 = V[:, 2].min(), V[:, 2].max()
low = V[V[:, 2] < z0 + 0.2 * (z1 - z0)]
# plants / goods / lanterns: centre on the foot (the pot or post under the leaves); loose pieces: on their box
cx, cy = ((low[:, 0].min() + low[:, 0].max()) / 2, (low[:, 1].min() + low[:, 1].max()) / 2) if a.kind in ("plant", "goods", "head") else \
    ((V[:, 0].min() + V[:, 0].max()) / 2, (V[:, 1].min() + V[:, 1].max()) / 2)
me.transform(Matrix.Translation((-cx, -cy, -z0)))
# ---------------------------------------------------------------- 2. the body (plant / head)
body_obs = []
if a.body:
    K = json.load(open(os.path.join(ROOT, a.body) if not os.path.isabs(a.body) else a.body))
    coll = bpy.data.collections.new("body")
    bpy.context.scene.collection.children.link(coll)
    body_obs = build_kit(K, coll)
    if a.kind == "head":
        pre = a.part.split(",") if a.part else ["Head"]       # Lantern_B: Globe,Core,Equator,Meridian,TopCap,TopBall
        heads = [o for o in body_obs if any(o.name.startswith(q) for q in pre)]
        if not heads:
            raise SystemExit("no kit parts named %s in %s" % (pre, a.body))
        hmn, _ = bounds(heads)
        stats["head_cut_z"] = round(hmn.z, 3)
        body_obs = [o for o in body_obs if o not in heads]
        for o in heads:                                 # the temporary part head is replaced by the Tripo one
            bpy.data.objects.remove(o)

# ---------------------------------------------------------------- scale (and place for part / ontop)
key, val = a.fit.split("=")
val = float(val)
V = np.array([v.co[:] for v in me.vertices])
size0 = V.max(0) - V.min(0)
if a.kind == "part":
    tgt = [o for o in body_obs if any(o.name.startswith(q) for q in a.part.split(","))]
    pmn, pmx = bounds(tgt)
    s = (pmx.z - pmn.z) / size0[2]
    me.transform(Matrix.Scale(s, 4))
    me.transform(Matrix.Translation(((pmn.x + pmx.x) / 2, (pmn.y + pmx.y) / 2, pmn.z)))
    stats["part_box"] = [round(v, 3) for v in (*pmn, *pmx)]
    body_obs = [o for o in body_obs if o not in tgt]
    for o in tgt:
        bpy.data.objects.remove(o)
elif a.kind == "ontop":
    bmn, bmx = bounds(body_obs)
    s = (bmx.x - bmn.x) * val / size0[0]
    me.transform(Matrix.Scale(s, 4))
    me.transform(Matrix.Translation((0, 0, bmx.z - 0.05)))
    stats["body_top"] = round(bmx.z, 3)
else:
    s = val / (size0[2] if key == "h" else max(size0[0], size0[1]))
    if a.kind == "plant" and body_obs and a.rim_frac > 0:
        zt = body_rim_top(body_obs)
        s = zt / a.rim_frac / size0[2]
        stats["rim_frac"] = {"frac": a.rim_frac, "body_top": round(zt, 3), "height": round(zt / a.rim_frac, 3)}
    me.transform(Matrix.Scale(s, 4))
    if a.kind == "plant" and body_obs and a.calib:
        # match Tripo's pot to the part body: the top of Tripo's gold rim (outermost gold faces in the lower part)
        # goes to the body top, so the two rims do not show double (PotFlowers_D, Topiary_E 10/12)
        me.update()
        hsv = PB.Source([src]).tri_hsv()
        me.calc_loop_triangles()
        P = np.array([t.center[:] for t in me.loop_triangles])
        H = P[:, 2].max()
        rad = np.hypot(P[:, 0], P[:, 1])
        low = P[:, 2] < 0.75 * H
        gold = (hsv[:, 0] > 28) & (hsv[:, 0] < 58) & (hsv[:, 1] > 0.4) & (hsv[:, 2] > 0.4) & low
        if gold.sum() > 30:
            outer = gold & (rad > 0.7 * rad[low].max())
            if outer.sum() > 10:
                rim = np.percentile(P[outer, 2], 97)
                _, bmx = bounds(body_obs)
                k = bmx.z / rim
                if 0.6 < k < 1.6:
                    me.transform(Matrix.Scale(k, 4))
                    s *= k
                    stats["rim_calib"] = {"tripo_rim": round(float(rim), 3), "body_top": round(bmx.z, 3), "k": round(k, 3)}
                    log("rim calib k %.3f (tripo rim %.2f -> body top %.2f)" % (k, rim, bmx.z))
me.update()
stats["scale"] = round(s, 4)
stats["src_tris"] = tris(src)
log("loaded", a.job, "tris", stats["src_tris"], "scale %.3f" % s)

work = src.copy()
work.data = src.data.copy()
work.name = NAME
bpy.context.scene.collection.objects.link(work)

# ---------------------------------------------------------------- 3. cut
bm = bmesh.new()
bm.from_mesh(work.data)
bm.faces.ensure_lookup_table()
kill = []
if a.kind == "plant":
    # footprint radius of the body at a height = widest vertex of every body object spanning that height
    spans = []
    for o in body_obs:
        W = np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])
        spans.append((W[:, 2].min(), W[:, 2].max(), np.sqrt(W[:, 0] ** 2 + W[:, 1] ** 2).max()))
    ztop = body_rim_top(body_obs)
    stats["body_top"] = round(ztop, 3)

    def r_at(z):
        r = [sp[2] for sp in spans if sp[0] - a.tol <= z <= sp[1] + a.tol]
        return max(r) if r else -1.0
    for f in bm.faces:
        c = f.calc_center_median()
        if c.z < ztop + a.tolz and (a.below_all or math.hypot(c.x, c.y) < r_at(c.z) + a.tol):
            kill.append(f)
elif a.kind == "goods":
    from mathutils.bvhtree import BVHTree
    bv, bt, off = [], [], 0
    for o in body_obs:
        bv += [o.matrix_world @ v.co for v in o.data.vertices]
        bt += [[off + i for i in p.vertices] for p in o.data.polygons]
        off += len(o.data.vertices)
    tree = BVHTree.FromPolygons(bv, bt)
    for f in bm.faces:
        c = f.calc_center_median()
        hit, nrm, _, dist = tree.find_nearest(c)
        if hit is not None and (dist < a.tol or ((c - hit).dot(nrm) < 0 and dist < 0.6)):
            kill.append(f)
elif a.kind == "head":
    zc = stats["head_cut_z"] - 0.02
    kill = [f for f in bm.faces if f.calc_center_median().z < zc]
stats["faces_cut"] = len(kill)
bmesh.ops.delete(bm, geom=kill, context="FACES")
# dust: loose islands of a handful of faces
bm.faces.index_update()
islands, seen = [], set()
for f in bm.faces:
    if f.index in seen:
        continue
    stack, isl = [f], []
    seen.add(f.index)
    while stack:
        g = stack.pop()
        isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    islands.append(isl)
dust = [g for isl in islands if len(isl) < a.dust for g in isl]
stats["dust_faces"] = len(dust)
bmesh.ops.delete(bm, geom=dust, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bm.to_mesh(work.data)
bm.free()
log("cut", stats["faces_cut"], "dust", stats["dust_faces"], "islands", len(islands))

# ---------------------------------------------------------------- 4. decimate + UV
select_only([work], work)
cur = tris(work)
if cur > a.tris:
    mod = work.modifiers.new("dec", "DECIMATE")
    mod.ratio = a.tris / cur
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
tri = work.modifiers.new("tri", "TRIANGULATE")
bpy.ops.object.modifier_apply(modifier=tri.name)
for p in work.data.polygons:
    p.use_smooth = True
stats["tris"] = tris(work)
while work.data.uv_layers:
    work.data.uv_layers.remove(work.data.uv_layers[0])
work.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
log("decimated", cur, "->", stats["tris"])

# ---------------------------------------------------------------- 5. bake Tripo's look onto the new UVs
source = PB.Source([src])
maps = PB.bake(work, source, size=a.px, ray=None, relief=True)
mat = PB.save_maps(maps, OUT, NAME)
work.data.materials.clear()
work.data.materials.append(mat)
mn, mx = bounds([work])
stats["size"] = [round(v, 3) for v in (mx - mn)]
stats["min"] = [round(v, 3) for v in mn]
stats["maps"] = ["%s_%s.png" % (NAME, t) for t in ("C", "N", "R", "M")]
stats["px"] = a.px

# ---------------------------------------------------------------- 5b. outline shell (inverted hull)
outline = None
if a.outline > 0:
    outline = work.copy()
    outline.data = work.data.copy()
    outline.name = NAME + "_Outline"
    bpy.context.scene.collection.objects.link(outline)
    outline.data.materials.clear()
    vox = a.outline_voxel or max(0.03, 0.015 * max(mx - mn))
    select_only([outline], outline)
    rm = outline.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = vox
    bpy.ops.object.modifier_apply(modifier=rm.name)
    if tris(outline) > 4000:
        dm = outline.modifiers.new("dec", "DECIMATE")
        dm.ratio = 4000 / max(tris(outline), 1)
        bpy.ops.object.modifier_apply(modifier=dm.name)
    tm = outline.modifiers.new("tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tm.name)
    ob_bm = bmesh.new()
    ob_bm.from_mesh(outline.data)
    ob_bm.normal_update()
    # 디자인 검수 10/12 (same rule as the part kits): no shell under the mesh - faces facing down at its foot (ground / the
    # part body it sits on) are dropped, nothing goes more than 0.01 below the foot
    zf = min(v.co.z for v in ob_bm.verts)
    down = [f for f in ob_bm.faces if f.normal.z < -0.7 and max(v.co.z for v in f.verts) < zf + 0.06]
    bmesh.ops.delete(ob_bm, geom=down, context="FACES")
    bmesh.ops.delete(ob_bm, geom=[v for v in ob_bm.verts if not v.link_faces], context="VERTS")
    ob_bm.normal_update()
    for v in ob_bm.verts:
        v.co += v.normal * a.outline * min(v.calc_shell_factor(), 3.0)
        if v.co.z < zf - 0.01:
            v.co.z = zf - 0.01
    bmesh.ops.reverse_faces(ob_bm, faces=ob_bm.faces)
    ob_bm.to_mesh(outline.data)
    ob_bm.free()
    while outline.data.uv_layers:
        outline.data.uv_layers.remove(outline.data.uv_layers[0])
    om = bpy.data.materials.new("Outline")
    om.use_nodes = True
    nt = om.node_tree
    pb = nt.nodes["Principled BSDF"]
    pb.inputs["Base Color"].default_value = (0.069, 0.031, 0.017, 1)          # (74, 50, 36) in linear
    pb.inputs["Roughness"].default_value = 0.9
    om.use_backface_culling = True
    geo = nt.nodes.new("ShaderNodeNewGeometry")                                 # preview only: Cycles draws both sides
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(pb.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    outline.data.materials.append(om)
    outline.visible_shadow = outline.visible_diffuse = outline.visible_glossy = outline.visible_transmission = False
    stats["outline"] = {"thickness": a.outline, "voxel": round(vox, 3), "tris": tris(outline)}

# ---------------------------------------------------------------- 6. export (the plant / head and its outline as two meshes)
select_only([work] + ([outline] if outline else []), work)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + ".glb"), export_format="GLB", use_selection=True,
                          export_apply=True)
json.dump(stats, open(os.path.join(OUT, NAME + ".json"), "w"), indent=1)
log("done", json.dumps(stats))

# ---------------------------------------------------------------- 7. preview with the body
if a.preview:
    bpy.data.objects.remove(src)
    sc = bpy.context.scene
    obs = [work] + body_obs
    bmn, bmx = bounds(obs)
    if outline:
        obs.append(outline)
    ctr = (bmn + bmx) / 2
    size = max(bmx - bmn)
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 3
    sc.render.resolution_x = sc.render.resolution_y = 480
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.13, 0.135, 0.145, 1)
    for nm, en, rot in (("sun", 3.0, (50, 0, 200)), ("fill", 1.0, (60, 0, 20))):
        L = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
        L.data.energy = en
        L.rotation_euler = tuple(math.radians(v) for v in rot)
        sc.collection.objects.link(L)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.18
    el = math.radians(14)
    for view, az in (("front", 0), ("left", 90), ("back", 180), ("right", 270)):
        d = Vector((math.sin(math.radians(az)), math.cos(math.radians(az)), 0)) * math.cos(el) + Vector((0, 0, math.sin(el)))
        cam.location = ctr + d * (size * 3)
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (NAME, view))
        bpy.ops.render.render(write_still=True)
    log("preview done")
