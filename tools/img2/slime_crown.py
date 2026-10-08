"""King Slime crown (style drift #25: the King Slime 3D is only a bigger blue cube; the icon wears a gold crown). Builds a
chunky gold crown around the crystal tuft on top of the slime cube mesh, as its own GLB in the slime's coordinates
(so it can be welded on at the same pivot), plus a combined preview GLB. Blender, 0 credits.

  blender --background --factory-startup --python tools/img2/slime_crown.py -- <slime.glb> <crown_out.glb> <preview_out.glb>
          [--points 5] [--pad 1.18] [--height 0.22]

The crystal tuft = vertices above 78 % of the height; the crown ring sits on the body top around them (ring radius =
tuft radius * pad), 5 rounded points with a small ball on each, gold base colour, no texture.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SLIME, OUTC, OUTP = argv[:3]


def opt(n, d):
    return float(argv[argv.index(n) + 1]) if n in argv else d


NP, PAD, HF = int(opt("--points", 5)), opt("--pad", 1.18), opt("--height", 0.22)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SLIME)
slime = [o for o in bpy.context.scene.objects if o.type == "MESH"]
vs = [o.matrix_world @ v.co for o in slime for v in o.data.vertices]
zmin, zmax = min(v.z for v in vs), max(v.z for v in vs)
H = zmax - zmin
tuft = [v for v in vs if v.z > zmin + 0.78 * H]
cx = sum(v.x for v in tuft) / len(tuft)
cy = sum(v.y for v in tuft) / len(tuft)
rt = max(math.hypot(v.x - cx, v.y - cy) for v in tuft)
# body top under the tuft: highest body vertex within 1.6 tuft radii that is not part of the tuft column
ring_pts = [v for v in vs if rt * 1.0 < math.hypot(v.x - cx, v.y - cy) < rt * 1.6]
ztop = max(v.z for v in ring_pts) if ring_pts else zmin + 0.78 * H
R = rt * PAD
band = HF * H * 0.6
hpt = HF * H
print("[crown] tuft r", round(rt, 4), "centre", round(cx, 4), round(cy, 4), "body top", round(ztop, 4), flush=True)

me = bpy.data.meshes.new("KingCrown")
bm = bmesh.new()
N = 60
z0 = ztop - band * 0.35
thick = R * 0.17
outer, inner = [], []
for i in range(N):
    a = 2 * math.pi * i / N
    # top edge: band + points (smooth cosine bumps, NP of them)
    ph = (a * NP / (2 * math.pi)) % 1.0
    bump = max(0.0, math.cos((ph - 0.5) * 2 * math.pi)) ** 1.6
    top = z0 + band + hpt * bump * 0.85
    for r, store in ((R, outer), (R - thick, inner)):
        b = bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), z0))
        t = bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), top))
        store.append((b, t))
for i in range(N):
    j = (i + 1) % N
    ob, ot = outer[i]
    ob2, ot2 = outer[j]
    ib, it = inner[i]
    ib2, it2 = inner[j]
    bm.faces.new((ob, ob2, ot2, ot))       # outside
    bm.faces.new((ib2, ib, it, it2))       # inside
    bm.faces.new((ot, ot2, it2, it))       # top rim
    bm.faces.new((ob2, ob, ib, ib2))       # bottom rim
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me)
bm.free()
crown = bpy.data.objects.new("KingCrown", me)
bpy.context.scene.collection.objects.link(crown)
for p in crown.data.polygons:
    p.use_smooth = True
mat = bpy.data.materials.new("CrownGold")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (1.0, 0.6, 0.06, 1)
bsdf.inputs["Metallic"].default_value = 0.6
bsdf.inputs["Roughness"].default_value = 0.3
crown.data.materials.append(mat)
# a ball on each point tip
balls = []
for k in range(NP):
    a = 2 * math.pi * (k + 0.5) / NP
    bpy.ops.mesh.primitive_uv_sphere_add(radius=thick * 1.0, location=(cx + (R - thick / 2) * math.cos(a), cy + (R - thick / 2) * math.sin(a), z0 + band + hpt * 0.85 + thick * 0.6), segments=16, ring_count=8)
    b = bpy.context.active_object
    b.data.materials.append(mat)
    for p in b.data.polygons:
        p.use_smooth = True
    balls.append(b)
bpy.ops.object.select_all(action="DESELECT")
for o in [crown] + balls:
    o.select_set(True)
bpy.context.view_layer.objects.active = crown
bpy.ops.object.join()
crown = bpy.context.active_object
# crown alone
bpy.ops.object.select_all(action="DESELECT")
crown.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUTC, export_format="GLB", use_selection=True)
# preview: slime + crown
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUTP, export_format="GLB", use_selection=True)
print("[crown] ok", OUTC, OUTP, flush=True)
