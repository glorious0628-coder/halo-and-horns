"""Remove the amber ore crystals from the slime cube mesh, fill the top smooth (0 credits). Slime Prince = crown, not ore (2026-10-09).

  blender --background --factory-startup --python tools/blender_slime_noore.py -- <in.glb> <out.glb> [--save-sheet prefix]

Faces whose base-colour texel is amber (r high, b low) and that sit above the body top are deleted; the hole is filled and
smoothed, the filling gets the UV of a body-green texel next to it (texture untouched). Size and origin stay the same: a
micro triangle (0.002 units) at the old top keeps the bounding box, so MeshPart:ApplyMesh / the importer keep the body size and
centre.
"""
import sys
import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
img = None
for m in me.materials:
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            img = n.image
w, h = img.size
px = list(img.pixels)
uvl = me.uv_layers.active
zs = [v.co.z for v in me.vertices]
zmin, zmax = min(zs), max(zs)
print("bbox z", zmin, zmax, "faces", len(me.polygons))


def col(u, v):
    x = min(w - 1, max(0, int(u * w)))
    y = min(h - 1, max(0, int(v * h)))
    i = (y * w + x) * 4
    return px[i], px[i + 1], px[i + 2]


def amber(c):
    r, g, b = c
    return r > 0.5 and r - b > 0.28 and g > 0.35 and r - g > 0.02 and b < 0.55


CC, CR = (0.03, 0.15), 0.30 # the crystal cluster centre / the radius cleared on the body top (the top is flat, 0.24-0.27)
TOP = 0.285
bm = bmesh.new()
bm.from_mesh(me)
uv = bm.loops.layers.uv.active
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6) # UV seams split vertices: weld so the hole boundary closes (UVs stay per loop)
bm.faces.ensure_lookup_table()
kill = []
for f in bm.faces:
    u = sum(l[uv].uv.x for l in f.loops) / len(f.loops)
    v = sum(l[uv].uv.y for l in f.loops) / len(f.loops)
    c = f.calc_center_median()
    # the crystals stand in a small cluster (x -0.15..0.15, y -0.05..0.35 in the raw mesh) over a body top at z ~0.23-0.25:
    # everything above TOP (0.285, the body top peaks at 0.273), plus every face of the top inside the cleared circle (their sunk bases)
    if c.z > TOP or (((c.x - CC[0]) ** 2 + (c.y - CC[1]) ** 2) < CR * CR and c.z > 0.19):
        kill.append(f)
print("ore faces", len(kill))
# grow by one ring of faces that touch only ore vertices (rims of the crystals share vertices with the body)
kv = set(v for f in kill for v in f.verts)
extra = [f for f in bm.faces if f not in kill and all(v in kv for v in f.verts)]
kill += extra
bmesh.ops.delete(bm, geom=kill, context="FACES")
loose = [e for e in bm.edges if not e.link_faces]
bmesh.ops.delete(bm, geom=loose, context="EDGES")
loose_v = [v for v in bm.verts if not v.link_edges]
bmesh.ops.delete(bm, geom=loose_v, context="VERTS")
bm.edges.ensure_lookup_table()
# the mesh has UV-seam boundaries everywhere (split vertices): only the edges the deletion opened (both ends were ore vertices)
boundary = [e for e in bm.edges if len(e.link_faces) == 1 and all(v in kv and v.is_valid for v in e.verts)]
print("boundary edges", len(boundary))
# a UV: the average of the boundary loops' UVs (body green around the crystal base)
us, vs = [], []
for e in boundary:
    for l in e.link_loops:
        us.append(l[uv].uv.x)
        vs.append(l[uv].uv.y)
U, V = sum(us) / len(us), sum(vs) / len(vs)
print("fill uv", U, V, col(U, V))
res = bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
newf = res["faces"]
print("fill faces", len(newf))
for f in newf:
    for l in f.loops:
        l[uv].uv = (U, V)
tri = bmesh.ops.triangulate(bm, faces=newf)
ringv = set(v for f in newf for v in f.verts)
for _ in range(3):
    ring2 = set(ringv)
    for v in ringv:
        for e in v.link_edges:
            ring2.add(e.other_vert(v))
    ringv = ring2
for _ in range(4):
    bmesh.ops.smooth_vert(bm, verts=list(ringv), factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
# keep the body's own normals (recalculating flipped parts of this multi-shell mesh); only the fill faces face outward
cen = Vector((0, 0, 0))
for f in bm.faces:
    pass
for f in [f for f in bm.faces if all(v in ringv for v in f.verts) and f not in kill]:
    pass
for f in newf + [x for x in tri.get("faces", [])]:
    if f.is_valid:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
# micro triangle at the old top so the bounding box (size, centre) stays the same
top = max((v.co.z for v in bm.verts if v.co.z < zmax - 0.01))
print("body top z", top, "old top", zmax)
cx = sum(v.co.x for v in bm.verts) / len(bm.verts)
cy = sum(v.co.y for v in bm.verts) / len(bm.verts)
a = bm.verts.new((cx, cy, zmax))
b = bm.verts.new((cx + 0.002, cy, zmax - 0.002))
c = bm.verts.new((cx, cy + 0.002, zmax - 0.002))
mf = bm.faces.new((a, b, c))
for l in mf.loops:
    l[uv].uv = (U, V)
bm.to_mesh(me)
bm.free()
me.update()
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="AUTO", export_apply=True)
pts = [v.co for v in me.vertices]
print("out bbox z", min(p.z for p in pts), max(p.z for p in pts), "wrote", OUT)
