"""
Fill a part that Tripo made hollow (e.g. the jelly cube on the meadow sign post came out as an empty frame), 0 credits.
Finds the faces of one colour in the top part of the model, puts a solid rounded box inside their bounding box and
gives it that colour (UVs point at one texel of the same texture, so the model keeps one material).

  blender --background --factory-startup --python tools/glb_fill_hollow.py -- <in.glb> <out.glb> --rgb r0,r1,g0,g1,b0,b1 [--zmin 0.7] [--shrink 0.9] [--bevel 0.2] [--trim 0.03] [--tone 0.5]

- --rgb: colour range (sRGB 0..1) of the hollow part's texture, e.g. lime green 0.4,0.9,0.7,1,0,0.45
- --zmin: only faces above this fraction of the model height
- --shrink: box size = bounding box * shrink (the frame bars stay a little proud, like soft jelly edges)
- --bevel: rounded edge size as a fraction of the smallest box side
"""
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], os.path.abspath(argv[1])


def opt(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


R0, R1, G0, G1, B0, B1 = (float(v) for v in opt("--rgb", "0.4,0.9,0.7,1,0,0.45").split(","))
ZMIN = float(opt("--zmin", "0.7"))
SHRINK = float(opt("--shrink", "0.9"))
BEVEL = float(opt("--bevel", "0.2"))
TRIM = float(opt("--trim", "0.03"))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = obj.data
img = [n.image for m in me.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image][0]
tw, th = img.size
px = img.pixels[:]


def colour(u, v):
    x = min(tw - 1, max(0, int(u * tw)))
    y = min(th - 1, max(0, int(v * th)))
    i = (y * tw + x) * 4
    return px[i], px[i + 1], px[i + 2]


uvl = me.uv_layers.active.data
zs = [v.co.z for v in me.vertices]
z_lo, z_hi = min(zs), max(zs)
zcut = z_lo + (z_hi - z_lo) * ZMIN
picked, uvs = [], []
for p in me.polygons:
    if p.center.z < zcut:
        continue
    u = sum(uvl[li].uv[0] for li in p.loop_indices) / p.loop_total
    v = sum(uvl[li].uv[1] for li in p.loop_indices) / p.loop_total
    r, g, b = colour(u, v)
    if R0 <= r <= R1 and G0 <= g <= G1 and B0 <= b <= B1:
        picked.append(p.index)
        uvs.append((u, v, r, g, b))
if not picked:
    sys.exit("[glb_fill_hollow] no faces in that colour range")
pts = [me.vertices[vi].co for pi in picked for vi in me.polygons[pi].vertices]


def trimmed(axis):
    # a few faces elsewhere sample the same colour through texture bleed: drop the outer TRIM on each side
    vals = sorted(p[axis] for p in pts)
    k = int(len(vals) * TRIM)
    return vals[k], vals[len(vals) - 1 - k]


lo = Vector([trimmed(a)[0] for a in range(3)])
hi = Vector([trimmed(a)[1] for a in range(3)])
centre, dims = (lo + hi) / 2, (hi - lo) * SHRINK
# the texel at the --tone brightness percentile of the part (0.5 = middle tone, higher = the lit side)
TONE = float(opt("--tone", "0.5"))
by_l = sorted(uvs, key=lambda c: 0.3 * c[2] + 0.59 * c[3] + 0.11 * c[4])
best = by_l[min(len(by_l) - 1, int(TONE * (len(by_l) - 1)))]
med = best[2:5]

bm = bmesh.new()
bm.from_mesh(me)
before = set(bm.faces)
res = bmesh.ops.create_cube(bm, size=1.0)
verts = res["verts"]
for v in verts:
    v.co = Vector((centre.x + v.co.x * dims.x, centre.y + v.co.y * dims.y, centre.z + v.co.z * dims.z))
edges = list({e for v in verts for e in v.link_edges})
bmesh.ops.bevel(bm, geom=verts + edges, offset=BEVEL * min(dims), segments=3, profile=0.5, affect="EDGES")
uv_layer = bm.loops.layers.uv.active
new_faces = [f for f in bm.faces if f not in before]
for f in new_faces:
    f.material_index = 0
    f.smooth = True
    for loop in f.loops:
        loop[uv_layer].uv = (best[0], best[1])
bm.to_mesh(me)
bm.free()
tris = sum(len(p.vertices) - 2 for p in me.polygons)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="AUTO")
print(f"[glb_fill_hollow] faces picked {len(picked)}, box {tuple(round(d, 3) for d in dims)}, colour {tuple(round(c, 2) for c in med)}, "
      f"new faces {len(new_faces)}, tris {tris} -> {OUT}", flush=True)
