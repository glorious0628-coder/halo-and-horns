"""Clean a Tripo NPC face without 2D decals (Blender 손보기, 10/12; SPEC A23-147, role 15_blender.md rule 4).

The mesh, body, clothes and the Tripo 4096 maps stay as they are. Only the front of the head is split off as its own part
(<Name>_Face) with one planar front UV island and its own SIZE x SIZE maps, baked from the Tripo maps (colour + ORM by
EMIT, normal by NORMAL bake), so the face looks the same as the Tripo original; then tools/face_clean_2d.py cleans the
smeared eyes / mouth / teeth / tongue / brows in that one flat image, and `apply` puts it back.

Front = Blender +x (Tripo GLB import), up = +z. The face window is a square of side --scale around (y=--cy, z=--cz).

  blender --background --factory-startup --python tools/face_clean_bl.py -- probe <in.glb> <work_dir> --cz 0.215 --scale 0.17 [--cy 0]
      -> front.png (flat texture render, 1600) + ray.npz (per pixel depth / polygon index, 800)
  py tools/face_clean_2d.py region <work_dir>                       -> region.png + face_polys.json
  blender ... -- split <in.glb> <work_dir> [--size 2048]            -> face_color.png / face_orm.png / face_normal.png + split.blend
  py tools/face_clean_2d.py clean <work_dir>                        -> face_color_clean.png + face_cmp.png
  blender ... -- apply <work_dir> <out.glb> [--tex face_color_clean.png]
  blender ... -- shots <glb> <out_prefix>                           -> full front / side / back + face close-up (flat texture)
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
MODE = a[0]


def opt(name, default):
    return type(default)(a[a.index(name) + 1]) if name in a else default


def load(glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(glb))
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def camera(px):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "TEXTURE"
    sc.view_settings.view_transform = "Standard"
    sc.display.shading.background_type = "VIEWPORT"
    sc.display.shading.background_color = (0.5, 0.5, 0.5)
    sc.render.resolution_x = sc.render.resolution_y = px
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    return cam


def shoot(cam, path, d, ctr, scale):
    d = Vector(d).normalized()
    cam.location = Vector(ctr) + d * 3
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scale
    bpy.context.scene.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)


def win(work):
    return json.load(open(os.path.join(work, "window.json")))


if MODE == "probe":
    glb, work = a[1], os.path.abspath(a[2])
    os.makedirs(work, exist_ok=True)
    W = {"cy": opt("--cy", 0.0), "cz": opt("--cz", 0.0), "scale": opt("--scale", 0.17), "glb": os.path.abspath(glb)}
    json.dump(W, open(os.path.join(work, "window.json"), "w"), indent=1)
    obs = load(glb)
    o = obs[0]
    cam = camera(1600)
    shoot(cam, os.path.join(work, "front.png"), (1, 0, 0), (0, W["cy"], W["cz"]), W["scale"])
    bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    mw, mwi = o.matrix_world, o.matrix_world.inverted()
    R = 800
    D = np.full((R, R), np.nan, np.float32)
    P = np.full((R, R), -1, np.int32)
    dl = (mwi.to_3x3() @ Vector((-1, 0, 0))).normalized()
    for j in range(R):
        z = W["cz"] - (j + 0.5 - R / 2) / R * W["scale"]
        for i in range(R):
            y = W["cy"] + (i + 0.5 - R / 2) / R * W["scale"]
            loc, n, idx, dist = bvh.ray_cast(mwi @ Vector((5, y, z)), dl)
            if loc is not None:
                D[j, i] = (mw @ loc).x
                P[j, i] = idx
    np.savez(os.path.join(work, "ray.npz"), D=D, P=P)
    print("PROBE ok", work)

elif MODE == "split":
    glb, work = a[1], os.path.abspath(a[2])
    size = opt("--size", 2048)
    W = win(work)
    polys = set(json.load(open(os.path.join(work, "face_polys.json")))["polys"])
    o = load(glb)[0]
    base = o.name
    me = o.data
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    import bmesh
    bm = bmesh.from_edit_mesh(me)
    bm.select_mode = {"FACE"}
    for v in bm.verts:
        v.select = False
    for e in bm.edges:
        e.select = False
    bm.faces.ensure_lookup_table()
    # thin walls of the sculpted eyes / mouth / brows are missed by the rays (seen edge-on): take every face whose
    # corners all fall inside the face region and that is not behind the face surface there
    ray = np.load(os.path.join(work, "ray.npz"))
    Dm = ray["D"]
    R = Dm.shape[0]
    rim = bpy.data.images.load(os.path.join(work, "region.png"))
    rp = np.array(rim.pixels[:], np.float32).reshape(rim.size[1], rim.size[0], -1)[::-1, :, 0]
    mwb = o.matrix_world

    def pix(w):
        i = int(((w.y - W["cy"]) / W["scale"] + 0.5) * R)
        j = int((0.5 - (w.z - W["cz"]) / W["scale"]) * R)
        return (j, i) if 0 <= i < R and 0 <= j < R else None

    extra = 0
    for f in bm.faces:
        if f.index in polys:
            f.select = True
            continue
        ok = True
        for v in f.verts:
            w = mwb @ v.co
            p = pix(w)
            if p is None or rp[int(p[0] * rp.shape[0] / R), int(p[1] * rp.shape[1] / R)] < 0.5 or not (w.x > Dm[p] - 0.012):
                ok = False
                break
        f.select = ok
        extra += ok
    print("SPLIT extra wall faces", extra)
    # holes: unselected patches enclosed by the face (nose underside, eye / mouth walls) kept the old smeared Tripo
    # paint -> any unselected connected patch that never reaches past the head front is taken in too
    zy, zz0, zz1 = 0.40 * W["scale"], W["cz"] - 0.36 * W["scale"], W["cz"] + 0.40 * W["scale"]
    seen = set()
    holes = 0
    for f0 in bm.faces:
        if f0.select or f0.index in seen:
            continue
        comp, stack, leak = [], [f0], False
        seen.add(f0.index)
        while stack:
            f = stack.pop()
            comp.append(f)
            c = mwb @ f.calc_center_median()
            if abs(c.y - W["cy"]) > zy or not (zz0 < c.z < zz1) or c.x < 0 or len(comp) > 150:
                leak = True
            for e in f.edges:
                for g in e.link_faces:
                    if not g.select and g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        if not leak:
            for f in comp:
                f.select = True
            holes += len(comp)
    print("SPLIT hole faces", holes)
    bmesh.update_edit_mesh(me)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    face = [x for x in bpy.context.scene.objects if x.type == "MESH" and x is not o][0]
    o.name, face.name = "Body", "Face"
    # the face part gets its own copy of the material (the body keeps the Tripo one untouched)
    face.data = face.data.copy()
    face.data.materials[0] = face.data.materials[0].copy()
    mat = face.data.materials[0]
    mw = face.matrix_world
    # denser face (Tripo's face triangles are big, smooth shading showed their facets): each edge cut once
    # (4 x the faces, ~2.5k); the rim midpoints lie on the old rim edges, so no gap to the body
    subd = opt("--subdiv", 0)
    if subd > 0:
        import bmesh as _bm
        if face.data.has_custom_normals:
            bpy.context.view_layer.objects.active = face
            bpy.ops.object.select_all(action="DESELECT")
            face.select_set(True)
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        sb = _bm.new()
        sb.from_mesh(face.data)
        for _ in range(subd):
            _bm.ops.subdivide_edges(sb, edges=sb.edges[:], cuts=1, use_grid_fill=True)
        _bm.ops.triangulate(sb, faces=sb.faces[:])
        sb.to_mesh(face.data)
        sb.free()
        face.data.update()
        print("SUBDIV faces", len(face.data.polygons))
    uvf = face.data.uv_layers.new(name="FaceUV")
    for lp in face.data.loops:
        w = mw @ face.data.vertices[lp.vertex_index].co
        uvf.data[lp.index].uv = ((w.y - W["cy"]) / W["scale"] + 0.5, (w.z - W["cz"]) / W["scale"] + 0.5)
    face.data.uv_layers.active = uvf
    # smooth printed face like the 2D (user 10/12 "입이 이상하잖아", "매끈해야 하지 않아?"): Tripo embossed the eyes /
    # mouth / teeth / brows a few mm and the face triangles are lumpy, so the 2D-placed paint sat on the wrong bumps.
    # Every vertex of the face part except the nose (region step: nose.png) and the part's rim (shared with the body)
    # is relaxed along the face normal (+x) toward its neighbours' average (Laplacian, many rounds): bumps go, the
    # overall curve and the bevels' rim stay. Then the Tripo custom normals are dropped and the face is shaded smooth.
    if opt("--smooth", 1) > 0:
        import bmesh as _bm
        fb = _bm.new()
        fb.from_mesh(face.data)
        rimv = np.array(sorted({v.index for e in fb.edges if len(e.link_faces) < 2 for v in e.verts}), int)
        fb.free()
        P = np.array([(mw @ v.co)[:] for v in face.data.vertices])
        nimg = bpy.data.images.load(os.path.join(work, "nose.png"))
        npx = np.array(nimg.pixels[:], np.float32).reshape(nimg.size[1], nimg.size[0], -1)[::-1, :, 0]
        Rn = npx.shape[0]
        ii = np.clip(((P[:, 1] - W["cy"]) / W["scale"] + 0.5) * Rn, 0, Rn - 1).astype(int)
        jj = np.clip((0.5 - (P[:, 2] - W["cz"]) / W["scale"]) * Rn, 0, Rn - 1).astype(int)
        nose = npx[jj, ii] > 0.5
        # weight: 1 inside the feature zone, easing to 0 over 0.12 x window toward the panel bevels; 0 on nose / rim
        dy = np.abs(P[:, 1] - W["cy"]) / W["scale"]
        dz_lo = (P[:, 2] - (W["cz"] - 0.36 * W["scale"])) / W["scale"]
        dz_hi = ((W["cz"] + 0.40 * W["scale"]) - P[:, 2]) / W["scale"]
        edge = np.minimum(np.minimum(0.40 - dy, dz_lo), dz_hi)
        t = np.clip(edge / 0.12 + 0.0, 0, 1)
        wgt = t * t * (3 - 2 * t)
        # keep the nose and its base exactly: weight eases in from the nose edge too
        nose_d = np.zeros(len(P))
        if nose.any():
            NP = P[nose][:, 1:]
            from mathutils.kdtree import KDTree
            kd = KDTree(len(NP))
            for k, q in enumerate(NP):
                kd.insert((q[0], q[1], 0), k)
            kd.balance()
            nose_d = np.array([kd.find((q[1], q[2], 0))[2] for q in P])
        tn = np.clip((nose_d - 0.002) / 0.008, 0, 1)
        wgt *= tn * tn * (3 - 2 * tn)
        wgt[nose] = 0
        wgt[rimv] = 0
        # the face skin surface: quadratic x = f(y, z) through the face points that are not nose (robust fit)
        fit = (wgt > 0) | ((edge > 0) & ~nose)
        def basis(y, z):
            return np.c_[np.ones_like(y), y, z, y * y, y * z, z * z]
        use = fit.copy()
        for _ in range(6):
            cf, *_ = np.linalg.lstsq(basis(P[use, 1], P[use, 2]), P[use, 0], rcond=None)
            res = P[:, 0] - basis(P[:, 1], P[:, 2]) @ cf
            use = fit & (np.abs(res) < max(0.0015, 2.0 * np.median(np.abs(res[use]))))
        Xs = basis(P[:, 1], P[:, 2]) @ cf
        Xn = P[:, 0] * (1 - wgt) + Xs * wgt
        # vertex normals: Tripo's own normal where the weight is 0, the surface normal where it is 1
        loopn = {}
        face.data.calc_normals_split() if hasattr(face.data, "calc_normals_split") else None
        for lp in face.data.loops:
            loopn.setdefault(lp.vertex_index, []).append(np.array(lp.normal[:]))
        on = np.array([np.mean(loopn[i], axis=0) if i in loopn else np.array([1.0, 0, 0]) for i in range(len(P))])
        on = on / np.maximum(np.linalg.norm(on, axis=1, keepdims=True), 1e-9)
        gy = cf[1] + 2 * cf[3] * P[:, 1] + cf[4] * P[:, 2]
        gz = cf[2] + cf[4] * P[:, 1] + 2 * cf[5] * P[:, 2]
        sn = np.c_[np.ones(len(P)), -gy, -gz]
        sn /= np.linalg.norm(sn, axis=1, keepdims=True)
        nn = on * (1 - wgt[:, None]) + sn * wgt[:, None]
        nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
        mwi = mw.inverted()
        for i in np.nonzero(wgt > 0)[0]:
            w = Vector(P[i])
            w.x = Xn[i]
            face.data.vertices[i].co = mwi @ w
        face.data.update()
        for p_ in face.data.polygons:
            p_.use_smooth = True
        rot = mwi.to_3x3()
        face.data.normals_split_custom_set_from_vertices([tuple((rot @ Vector(n)).normalized()) for n in nn])
        print("SMOOTH surface: moved", int((wgt > 0).sum()), "of", len(P), "nose", int(nose.sum()), "max shift", round(float(np.abs(Xn - P[:, 0]).max()), 4))
    nt = mat.node_tree
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    texs = {}
    for n in nt.nodes:
        if n.type == "TEX_IMAGE":
            nt.links.new(uvn.outputs[0], n.inputs[0])
            nm = n.image.name.split("_")[0]
            texs[nm] = n
        elif n.type == "NORMAL_MAP":
            n.uv_map = "UVMap"  # decode the Tripo normals in their own tangent space; the bake re-encodes in FaceUV's
    bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
    out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.margin = 16
    bpy.ops.object.select_all(action="DESELECT")
    face.select_set(True)
    bpy.context.view_layer.objects.active = face
    tgt = nt.nodes.new("ShaderNodeTexImage")
    nt.nodes.active = tgt

    def bake(kind, src_socket, name, colorspace):
        img = bpy.data.images.new(name, size, size, alpha=False)
        img.colorspace_settings.name = colorspace
        tgt.image = img
        surf = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        if kind == "EMIT":
            em = nt.nodes.new("ShaderNodeEmission")
            nt.links.new(src_socket, em.inputs["Color"])
            nt.links.new(em.outputs[0], out.inputs["Surface"])
            bpy.ops.object.bake(type="EMIT")
            nt.links.new(surf, out.inputs["Surface"])
            nt.nodes.remove(em)
        else:
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
        img.filepath_raw = os.path.join(work, name + ".png")
        img.file_format = "PNG"
        img.save()
        print("BAKED", name)

    bake("EMIT", texs["Color"].outputs["Color"], "face_color", "sRGB")
    bake("EMIT", texs["ORM"].outputs["Color"], "face_orm", "Non-Color")
    bake("NORMAL", None, "face_normal", "Non-Color")
    nt.nodes.remove(tgt)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, "split.blend"))
    print("SPLIT ok faces", len(face.data.polygons), "body", len(o.data.polygons))

elif MODE == "apply":
    work, out_glb = os.path.abspath(a[1]), os.path.abspath(a[2])
    tex = opt("--tex", "face_color_clean.png")
    bpy.ops.wm.open_mainfile(filepath=os.path.join(work, "split.blend"))
    face = bpy.data.objects["Face"]
    me = face.data
    me.uv_layers.remove(me.uv_layers["UVMap"])
    mat = me.materials[0]
    mat.name = "FaceMat"
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type in ("UVMAP",):
            nt.nodes.remove(n)
    for n in nt.nodes:
        if n.type == "TEX_IMAGE":
            kind = n.image.name.split("_")[0]
            f = {"Color": tex, "ORM": "face_orm.png", "NormalGL": "face_normal.png"}[kind]
            img = bpy.data.images.load(os.path.join(work, f))
            img.colorspace_settings.name = "sRGB" if kind == "Color" else "Non-Color"
            if kind != "Color":
                # the face is flat now (printed like the 2D): no Tripo bump detail, one even skin roughness
                px = np.array(img.pixels[:], np.float32).reshape(-1, 4)
                if kind == "NormalGL":
                    val = np.array([0.5, 0.5, 1.0, 1.0], np.float32)
                else:
                    lit = px[px[:, :3].sum(1) > 0.02]
                    val = np.median(lit, axis=0) if len(lit) else px.mean(0)
                    val[3] = 1.0
                flat = bpy.data.images.new("Face" + kind, 256, 256, alpha=False)
                flat.colorspace_settings.name = "Non-Color"
                flat.pixels[:] = np.tile(val, 256 * 256).tolist()
                flat.filepath_raw = os.path.join(work, "face_" + kind.lower() + "_flat.png")
                flat.file_format = "PNG"
                flat.save()
                img = flat
                print("FLAT", kind, [round(float(x), 3) for x in val])
            n.image = img
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", export_image_format="AUTO", export_yup=True)
    print("APPLY ok", out_glb)

elif MODE == "shots":
    glb, pre = a[1], a[2]
    obs = load(glb)
    W = np.array([(o.matrix_world @ v.co)[:] for o in obs for v in o.data.vertices])
    ctr = (W.min(0) + W.max(0)) / 2
    size = float(np.ptp(W, axis=0).max()) * 1.05
    cam = camera(900)
    for nm, d in (("front", (1, 0, 0)), ("side", (0, 1, 0)), ("back", (-1, 0, 0)), ("q34", (0.75, 0.6, 0.25))):
        shoot(cam, pre + "_" + nm + ".png", d, ctr, size)
    wj = opt("--window", "")
    if wj:
        Wd = json.load(open(wj))
        bpy.context.scene.render.resolution_x = bpy.context.scene.render.resolution_y = 1600
        shoot(cam, pre + "_face.png", (1, 0, 0), (0, Wd["cy"], Wd["cz"]), Wd["scale"])
        shoot(cam, pre + "_face34.png", (0.8, 0.6, 0), (0, Wd["cy"], Wd["cz"]), Wd["scale"] * 1.15)
