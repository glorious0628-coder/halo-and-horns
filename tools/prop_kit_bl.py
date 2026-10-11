"""Shared Blender builder for tools/prop_kit.py kits (이미지 생성 4, 10/11): turns a build/prop_kit/<Kit>.json part list
(with its CSG ops) into Blender objects. Used by tools/prop_kit_preview.py and tools/prop_kit_bake.py (run inside Blender).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

COL = {"marble": (255, 244, 222), "gold": (255, 168, 36)}
MCACHE = {}


def s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(key, rgb):
    k = (key, tuple(rgb))
    if k in MCACHE:
        return MCACHE[k]
    m = bpy.data.materials.new("%s_%d_%d_%d" % (key, *rgb))
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple(s2l(c / 255) for c in rgb)
    b.inputs["Base Color"].default_value = (*lin, 1)
    rough, metal = 0.55, 0.0
    if key == "gold":
        rough, metal = 0.3, 0.85
    elif key == "ironblue":
        rough, metal = 0.45, 0.6
    elif key in ("marble", "mblock", "stone"):
        rough = 0.35
    elif key in ("glass", "water"):
        rough = 0.05
        b.inputs["Alpha"].default_value = 0.5
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    elif key in ("lamp", "neon"):
        b.inputs["Emission Color"].default_value = (1.0, 0.72, 0.3, 1)
        b.inputs["Emission Strength"].default_value = 2.0 if key == "neon" else 1.0
    elif key in ("wood", "woodcream", "wooddk", "cloth", "rope", "leaf", "soil"):
        rough = 0.8
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    MCACHE[k] = m
    return m


def make_obj(t, coll, segments=48):
    me = bpy.data.meshes.new(t["n"])
    bm = bmesh.new()
    s = t["s"]
    if s == "Block":
        bmesh.ops.create_cube(bm, size=1.0)
    elif s == "Cylinder":
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=0.5, radius2=0.5, depth=1.0)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))   # axis z -> x
    elif s == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=max(12, segments * 5 // 6), v_segments=max(6, segments * 5 // 12), radius=0.5)
    elif s == "Wedge":
        # Roblox wedge, local frame (X, Y up, Z back): low at -Z, high at +Z
        v = [bm.verts.new(p) for p in ((-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5))]
        for f in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)):
            bm.faces.new([v[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = s in ("Cylinder", "Ball")
    ob = bpy.data.objects.new(t["n"], me)
    X, Y = Vector(t["X"]), Vector(t["Y"])
    Z = X.cross(Y)
    # Roblox local Z = X x Y; our Blender frame keeps the same handedness (tools/prop_kit.py r3 is a rotation)
    R = Matrix((X, Y, Z)).transposed().to_4x4()
    ob.matrix_world = Matrix.Translation(Vector(t["p"])) @ R @ Matrix.Diagonal((*t["size"], 1))
    rgb = t["c"] or COL.get(t["m"], (200, 200, 200))
    me.materials.append(material(t["m"], rgb))
    ob["pk_mat"] = t["m"]
    coll.objects.link(ob)
    return ob


def apply_ops(ob, t, coll, segments=48):
    for kind, lst in t.get("ops", []):
        for c in lst:
            co = make_obj(c, coll, segments)
            if c.get("ops"):
                apply_ops(co, c, coll, segments)
            mod = ob.modifiers.new("b", "BOOLEAN")
            mod.operation = "DIFFERENCE" if kind == "minus" else "INTERSECT"
            mod.object = co
            mod.solver = "EXACT"
            bpy.context.view_layer.objects.active = ob
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            ev = ob.evaluated_get(dg)
            nm = bpy.data.meshes.new_from_object(ev)
            ob.modifiers.clear()
            old = ob.data
            ob.data = nm
            bpy.data.meshes.remove(old)
            bpy.data.objects.remove(co)


def build_kit(K, coll, segments=48):
    """All parts of kit dict K as objects in coll (CSG applied). Returns the list of objects."""
    MCACHE.clear()
    COL.update({k: tuple(v) for k, v in K.get("colors", {}).items()})
    obs = []
    for t in K["parts"]:
        ob = make_obj(t, coll, segments)
        if t.get("ops"):
            apply_ops(ob, t, coll, segments)
        obs.append(ob)
    return obs


def bounds(obs):
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for ob in obs:
        for v in ob.bound_box:
            w = ob.matrix_world @ Vector(v)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    return mn, mx
