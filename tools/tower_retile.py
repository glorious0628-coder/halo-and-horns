"""Tower body retexture with a tiling marble block texture (이미지 생성 1, 2026-10-10, 검수: "탑 몸통 = 대리석 블록 타일").

  blender --background --factory-startup --python tools/tower_retile.py -- <in_LOD.glb> <tile_color.png> <out.glb> <render_dir>
          [--height-studs 30] [--tile-studs 12] [--sat-max 0.22] [--val-min 0.58] [--flatten 0.1]

- The Tripo mesh (Z-up) is split per face by its Tripo colour: plain white/cream stone faces (saturation <= --sat-max, value
  >= --val-min) become <Name>_Stone; gold bands, window frames, dark openings stay <Name>_Trim with the Tripo texture.
  One pass of neighbour majority smooths single stray faces.
- Stone gets a tiling UV: round the tower axis u = arc length / tile, v = height / tile (side faces); top/bottom faces get a
  planar x/y UV. One tile = --tile-studs studs when the model is --height-studs studs tall. UVs go past 0..1 on purpose:
  Roblox repeats a MeshPart texture there, so the stone stays sharp at any distance.
- Writes <out.glb> (Stone + Trim, Stone material = the tile colour) and <render_dir>/<Name>_retile_{front,back,close}.png.
"""
import colorsys
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, TILE, OUT, RDIR = os.path.abspath(argv[0]), os.path.abspath(argv[1]), os.path.abspath(argv[2]), os.path.abspath(argv[3])
opt = {"height-studs": 30.0, "tile-studs": 12.0, "sat-max": 0.22, "val-min": 0.58, "flatten": 0.1}
i = 4
while i < len(argv):
    opt[argv[i][2:]] = float(argv[i + 1])
    i += 2
NAME = os.path.basename(IN).split("_HD_")[0]
os.makedirs(RDIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
ob.name = NAME + "_Trim"
me = ob.data

# Tripo colour per face
src_img = None
for n in me.materials[0].node_tree.nodes:
    if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
        src_img = n.image
W, H = src_img.size
px = list(src_img.pixels)
uvl = me.uv_layers[0]


def sample(u, v):
    x = min(W - 1, max(0, int((u % 1.0) * W)))
    y = min(H - 1, max(0, int((v % 1.0) * H)))
    k = (y * W + x) * 4
    return px[k], px[k + 1], px[k + 2]


def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


stone = []
for poly in me.polygons:
    pts = [uvl.data[li].uv for li in poly.loop_indices]
    cu = sum(p[0] for p in pts) / len(pts)
    cv = sum(p[1] for p in pts) / len(pts)
    samples = [sample(cu, cv)] + [sample((p[0] + cu) / 2, (p[1] + cv) / 2) for p in pts]
    hs = [colorsys.rgb_to_hsv(*[lin2srgb(c) for c in s]) for s in samples]
    s_ = sorted(h[1] for h in hs)[len(hs) // 2]
    v_ = sorted(h[2] for h in hs)[len(hs) // 2]
    stone.append(s_ <= opt["sat-max"] and v_ >= opt["val-min"])

# one pass of neighbour majority (edge neighbours)
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
sm = list(stone)
for f in bm.faces:
    nb = {g.index for e in f.edges for g in e.link_faces if g.index != f.index}
    if len(nb) >= 2:
        k = sum(1 for g in nb if stone[g])
        if stone[f.index] and k == 0:
            sm[f.index] = False
        elif not stone[f.index] and k == len(nb):
            sm[f.index] = True
stone = sm
bm.free()
print("[retile] stone faces %d of %d" % (sum(stone), len(stone)), flush=True)

# split
bpy.ops.object.mode_set(mode="EDIT")
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
for f in bm.faces:
    f.select = stone[f.index]
bmesh.update_edit_mesh(me)
bpy.ops.mesh.separate(type="SELECTED")
bpy.ops.object.mode_set(mode="OBJECT")
st = [o for o in bpy.context.scene.objects if o.type == "MESH" and o != ob][0]
st.name = NAME + "_Stone"

# tiling UV on the stone
pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box] + [st.matrix_world @ Vector(c) for c in st.bound_box]
z0, z1 = min(p.z for p in pts), max(p.z for p in pts)
cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
tile = opt["tile-studs"] / opt["height-studs"] * (z1 - z0)  # one tile in model units
sme = st.data
# flatten the Tripo block relief: it never lines up with the texture's blocks (a doubled "ghost block" pattern). Side-face
# vertices within --flatten of their height band's median radius move onto that radius; ledges/rings outside it stay.
import statistics
bins = {}
side_v = set()
for poly in sme.polygons:
    if abs(poly.normal.z) <= 0.8:
        side_v.update(poly.vertices)
binh = tile / 4
for vi in side_v:
    c = sme.vertices[vi].co
    bins.setdefault(int((c.z - z0) / binh), []).append(math.hypot(c.x - cx, c.y - cy))
rmed = {k: statistics.median(v) for k, v in bins.items()}
moved = 0
for vi in side_v:
    c = sme.vertices[vi].co
    r = math.hypot(c.x - cx, c.y - cy)
    R = rmed[int((c.z - z0) / binh)]
    if r > 1e-4 and abs(r - R) < opt["flatten"] * R:
        c.x = cx + (c.x - cx) * R / r
        c.y = cy + (c.y - cy) * R / r
        moved += 1
sme.update()
# the glTF custom normals still describe the old relief -> shading blotches; recompute them (smooth by angle 35)
bpy.ops.object.select_all(action="DESELECT")
st.select_set(True)
bpy.context.view_layer.objects.active = st
if sme.has_custom_normals:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
R_all = statistics.median(rmed.values())
print("[retile] flattened %d of %d side vertices" % (moved, len(side_v)), flush=True)
for l in list(sme.uv_layers):
    sme.uv_layers.remove(l)
suv = sme.uv_layers.new(name="UVMap")
for poly in sme.polygons:
    nrm = poly.normal
    cos_ = [st.matrix_world @ sme.vertices[sme.loops[li].vertex_index].co for li in poly.loop_indices]
    if abs(nrm.z) > 0.8:  # tops / ledges: planar
        uvs = [((c.x - cx) / tile, (c.y - cy) / tile) for c in cos_]
    else:
        # u = angle x one fixed radius, so neighbouring bands share the same block columns
        r = R_all  # one radius for the whole tower: the block columns run straight through the rings
        ang = [math.atan2(c.x - cx, -(c.y - cy)) for c in cos_]  # 0 at the front (-Y)
        if max(ang) - min(ang) > math.pi:  # across the seam at the back
            ang = [a + 2 * math.pi if a < 0 else a for a in ang]
        uvs = [(a * r / tile, (c.z - z0) / tile) for a, c in zip(ang, cos_)]
    for li, uv in zip(poly.loop_indices, uvs):
        suv.data[li].uv = uv

mat = bpy.data.materials.new(NAME + "_Marble")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tn = mat.node_tree.nodes.new("ShaderNodeTexImage")
tn.image = bpy.data.images.load(TILE)
mat.node_tree.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.62
sme.materials.clear()
sme.materials.append(mat)

# check renders
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 900
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
scene.collection.objects.link(cam)
scene.camera = cam
hgt = z1 - z0
for nm, yaw, cz, scale in (("front", 0, (z0 + z1) / 2, hgt * 1.1), ("back", 180, (z0 + z1) / 2, hgt * 1.1),
                           ("close", 20, z0 + hgt * 0.45, hgt * 0.35)):
    a = math.radians(yaw)
    cam.data.ortho_scale = scale
    cam.location = (cx + 10 * math.sin(a), cy - 10 * math.cos(a), cz)
    cam.rotation_euler = (math.radians(90), 0, a)
    scene.render.filepath = os.path.join(RDIR, NAME + "_retile_" + nm + ".png")
    bpy.ops.render.render(write_still=True)

bpy.ops.object.select_all(action="DESELECT")
for o in (ob, st):
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False)
print("[retile] ok", OUT, "tile %.4f model units" % tile, flush=True)
