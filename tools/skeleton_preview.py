"""Blender preview of a Studio skeleton (+ kept Tripo pieces) with the tile materials, or of a Tripo model with the same
cameras, for side-by-side checks (이미지 생성 3, 10/11, SPEC A23-120).

  blender --background --factory-startup --python tools/skeleton_preview.py -- <out_dir> [--parts parts.json]
          [--glb a.glb ...] [--cx -0.25] [--px 1400] [--skip-names WinPane,Glass] [--cams <out>_cams.json]
          [--marble block|cream]

--parts: tools/skeleton_house07.py json (Blender frame). Marble = art/ui/halo_tile/Halo_TowerMarbleBlock_* box-mapped at
9 studs a tile (HH_HaloMarbleBlock), gold = Halo_GoldTrim_* tinted (255,168,36) at 4 studs (HH_HaloGoldTrim), glass
see-through. Only parts of group "house" are drawn. --glb: models drawn with their own materials.
Renders front / q34 / side / back (ortho, 24 studs across) and three perspective close-ups (door, window, base corner).
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--parts")
ap.add_argument("--glb", nargs="*", default=[])
ap.add_argument("--cx", type=float, default=-0.25)
ap.add_argument("--px", type=int, default=1400)
ap.add_argument("--skip-names", default="")
ap.add_argument("--cams", help="close-up cameras json from the skeleton generator (<out>_cams.json)")
ap.add_argument("--marble", default="block", choices=["block", "cream"])
ap.add_argument("--ortho", type=float, default=24.0, help="ortho width of the four whole views (studs)")
ap.add_argument("--cz", type=float, default=9.8, help="height the whole views look at")
ap.add_argument("--cloth", default="250,205,72;255,243,212", help="awning stripe colours (skeleton_house cloth0;cloth1)")
ap.add_argument("--views", default="front,q34,side,back",
                help="whole views: front, q34, side (camera at +x = the viewer's left, as the 2D *_left.png), side_r (-x, "
                     "the viewer's right = 2D *_right.png), back, top")
a = ap.parse_args(argv)
ROOT = os.environ.get("HH_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # HH_ROOT: run a private copy of tools/
TILE = os.path.join(ROOT, "art", "ui", "halo_tile")
bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(a.out, exist_ok=True)


def tex_mat(name, color_png, rough_png, studs, tint=(1, 1, 1), metal=0.0, bump=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / studs, 1 / studs, 1 / studs)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    ci = nt.nodes.new("ShaderNodeTexImage")
    ci.image = bpy.data.images.load(color_png)
    ci.projection = "BOX"
    ci.projection_blend = 0.2
    nt.links.new(mp.outputs["Vector"], ci.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(ci.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = (*tint, 1)
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    ri = nt.nodes.new("ShaderNodeTexImage")
    ri.image = bpy.data.images.load(rough_png)
    ri.image.colorspace_settings.name = "Non-Color"
    ri.projection = "BOX"
    ri.projection_blend = 0.2
    nt.links.new(mp.outputs["Vector"], ri.inputs["Vector"])
    nt.links.new(ri.outputs["Color"], b.inputs["Roughness"])
    b.inputs["Metallic"].default_value = metal
    if bump:
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.05
        nt.links.new(ci.outputs["Color"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def flat_mat(name, col, metal=0.0, rough=0.6, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if name == "lamp":
        b.inputs["Emission Color"].default_value = (1.0, 0.72, 0.3, 1)
        b.inputs["Emission Strength"].default_value = 1.5
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    return m


def s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


GOLD = tuple(s2l(c / 255) for c in (255, 168, 36))
MB, MS = {"block": ("Halo_TowerMarbleBlock", 9), "cream": ("Halo_TowerMarbleBlockCream", 12)}[a.marble]
MATS = {
    "marble": tex_mat("marble", os.path.join(TILE, MB + "_color.png"), os.path.join(TILE, MB + "_rough.png"), MS, bump=0.4),
    "floor": tex_mat("floor", os.path.join(TILE, MB + "_color.png"), os.path.join(TILE, MB + "_rough.png"), MS, (0.85, 0.82, 0.78), bump=0.4),
    "gold": tex_mat("gold", os.path.join(TILE, "Halo_GoldTrim_color.png"), os.path.join(TILE, "Halo_GoldTrim_rough.png"), 4, GOLD, 1.0),
    "soil": flat_mat("soil", tuple(s2l(c / 255) for c in (140, 100, 62)), 0, 0.95),
    "sky": flat_mat("sky", tuple(s2l(c / 255) for c in (150, 200, 240)), 0, 0.4),
    "wood": flat_mat("wood", tuple(s2l(c / 255) for c in (176, 118, 68)), 0, 0.8),
    "lamp": flat_mat("lamp", (1.0, 0.75, 0.35), 0, 0.3),
    "neon": flat_mat("neon", (1.0, 0.62, 0.2), 0, 0.3),
    "fabricY": flat_mat("fabricY", tuple(s2l(c / 255) for c in (250, 205, 72)), 0, 0.9),
    "cloth0": flat_mat("cloth0", tuple(s2l(c / 255) for c in (250, 205, 72)), 0, 0.6),
    "cloth1": flat_mat("cloth1", tuple(s2l(c / 255) for c in (255, 243, 212)), 0, 0.6),
    "fabricC": flat_mat("fabricC", tuple(s2l(c / 255) for c in (255, 243, 212)), 0, 0.9),
    "glass": flat_mat("glass", tuple(s2l(c / 255) for c in (170, 215, 245)), 0, 0.05, 0.45),
    "shopglass": flat_mat("shopglass", tuple(s2l(c / 255) for c in (190, 225, 248)), 0, 0.05, 0.2),
    "slate": flat_mat("slate", tuple(s2l(c / 255) for c in (90, 140, 210)), 0, 0.5),
}

CL = [tuple(s2l(int(c) / 255) for c in part.split(",")) for part in a.cloth.split(";")]
MATS["cloth0"] = flat_mat("cloth0b", CL[0], 0, 0.6)
MATS["cloth1"] = flat_mat("cloth1b", CL[1], 0, 0.6)
if a.parts:
    bms = {}
    for p in json.load(open(a.parts)):
        if p["grp"] != "house":
            continue
        X, Y = Vector(p["X"]), Vector(p["Y"])
        Z = X.cross(Y)
        R = Matrix((X, Y, Z)).transposed().to_4x4()
        M = Matrix.Translation(Vector(p["pos"])) @ R @ Matrix.Diagonal((*p["size"], 1))
        bm = bms.setdefault(p["mat"], bmesh.new())
        if p["shape"] == "Block":
            geom = bmesh.ops.create_cube(bm, size=1.0)
        elif p["shape"] == "Cylinder":   # axis = part X
            geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=0.5, radius2=0.5, depth=1.0,
                                         matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))
        else:
            geom = bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.5)
        bmesh.ops.transform(bm, matrix=M, verts=geom["verts"])
    for mat, bm in bms.items():
        me = bpy.data.meshes.new("skel_" + mat)
        bm.to_mesh(me)
        bm.free()
        for f in me.polygons:
            f.use_smooth = False
        o = bpy.data.objects.new("skel_" + mat, me)
        o.data.materials.append(MATS[mat])
        bpy.context.scene.collection.objects.link(o)
skip = [s for s in a.skip_names.split(",") if s]
for g in a.glb:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=g)
    for o in [o for o in bpy.data.objects if o not in before]:
        if any(o.name.split(".")[0].endswith("_" + s) for s in skip):
            bpy.data.objects.remove(o, do_unlink=True)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = a.px
scene.render.film_transparent = False
w = bpy.data.worlds.new("w")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(52), 0, math.radians(205))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam


def shot(name, loc, look, ortho=None, lens=35):
    cam.data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam.data.ortho_scale = ortho
    else:
        cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(a.out, name + ".png")
    bpy.ops.render.render(write_still=True)


C = a.cx
YAW = {"front": 0, "q34": 35, "side": 90, "back": 180, "side_r": 270}
for nm in a.views.split(","):
    if nm == "top":                                       # straight down, front at the bottom of the picture
        shot(nm, (C, -0.001, a.cz + 80), (C, 0, 0), ortho=a.ortho)
        continue
    t = math.radians(YAW[nm])
    shot(nm, (C + 80 * math.sin(t), 80 * math.cos(t), a.cz), (C, 0, a.cz), ortho=a.ortho)
if a.cams:
    for nm, (loc, look, lens) in json.load(open(a.cams)).items():
        shot(nm, tuple(loc), tuple(look), lens=lens)
else:   # skeleton v3 cameras
    shot("close_door", (C + 1.5, 17.0, 6.0), (C, 5.5, 5.4), lens=40)
    shot("close_window", (C - 9.5, 9.0, 8.0), (C - 6.0, 3.8, 7.6), lens=45)
    shot("close_base", (C - 10.5, 11.0, 3.0), (C - 6.0, 4.5, 1.5), lens=40)
print("[preview] ok", a.out, flush=True)
