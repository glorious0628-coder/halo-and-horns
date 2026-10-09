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


CC, CR = (0.03, 0.15), 0.21 # the crystal cluster centre / the radius cleared on the body top (the top is flat, 0.24-0.27)
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
    d2c = (c.x - CC[0]) ** 2 + (c.y - CC[1]) ** 2
    if c.z > TOP or (d2c < CR * CR and c.z > 0.19) or (d2c < (CR * 1.5) ** 2 and c.z > 0.19 and amber(col(u, v))):
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
# a UV: the texel of the body top just OUTSIDE the cleared circle that is closest to the median colour there (the texture has baked
# jelly shading: one texel must match the surrounding top or the patch shows)
cand = []
for f in bm.faces:
    c = f.calc_center_median()
    d2 = (c.x - CC[0]) ** 2 + (c.y - CC[1]) ** 2
    if 0.17 < c.z < 0.285 and (CR * 1.05) ** 2 < d2 < (CR * 1.5) ** 2:
        u_ = sum(l[uv].uv.x for l in f.loops) / len(f.loops)
        v_ = sum(l[uv].uv.y for l in f.loops) / len(f.loops)
        cand.append((u_, v_))
cols = [col(u_, v_) for u_, v_ in cand]
med = [sorted(c[i] for c in cols)[len(cols) // 2] for i in range(3)]
best = min(range(len(cand)), key=lambda i: sum((cols[i][k] - med[k]) ** 2 for k in range(3)))
U, V = cand[best]
print("top texels", len(cand), "median", med)
print("fill uv", U, V, col(U, V))
res = bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
newf = res["faces"]
print("fill faces", len(newf))
for f in newf:
    for l in f.loops:
        l[uv].uv = (U, V)
tri = bmesh.ops.triangulate(bm, faces=newf)
# the fill is a big flat n-gon (the cleared circle covers most of the top): cut it into small triangles and relax the inside
# (Laplacian, boundary fixed) so the top is the smooth surface between the body's own rim heights, plus a soft dome
bvs = set(v for e in boundary if e.is_valid for v in e.verts)
fill_edges = list(set(e for f in tri["faces"] if f.is_valid for e in f.edges))
bmesh.ops.subdivide_edges(bm, edges=fill_edges, cuts=5, use_grid_fill=False)
bm.verts.ensure_lookup_table()
ifv = set()
for f in bm.faces:
    if all((v in bvs) or (not any(len(le.link_faces) == 1 and le.is_valid and (le.other_vert(v) in bvs) for le in v.link_edges)) for v in f.verts):
        pass
# interior fill vertices = vertices that did not exist before the fill and are not on the boundary
inner = [v for v in bm.verts if v not in bvs and all(f.verts for f in v.link_faces) and v.co.z > zmin + (zmax - zmin) * 0.6 and (v.co.x - CC[0]) ** 2 + (v.co.y - CC[1]) ** 2 <= (CR * 1.02) ** 2 and len(v.link_faces) > 0]
for _ in range(60):
    bmesh.ops.smooth_vert(bm, verts=inner, factor=0.6, use_axis_x=False, use_axis_y=False, use_axis_z=True)
for v in inner:
    r2 = ((v.co.x - CC[0]) ** 2 + (v.co.y - CC[1]) ** 2) / (CR * CR)
    v.co.z += 0.015 * max(0.0, 1.0 - r2)
ringv = set(v for v in inner)
for _ in range(2):
    ring2 = set(ringv)
    for v in ringv:
        for e in v.link_edges:
            ring2.add(e.other_vert(v))
    ringv = ring2
for _ in range(3):
    bmesh.ops.smooth_vert(bm, verts=list(ringv), factor=0.4, use_axis_x=False, use_axis_y=False, use_axis_z=True)
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
