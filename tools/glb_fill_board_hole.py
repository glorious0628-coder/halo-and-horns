"""
Fill the one see-through triangle on the woods job board (Tripo Kit_W_JobBoard, 2026-10-07), 0 credits.
Tripo's GLB splits vertices at UV seams, so the mesh looks full of "holes": merge duplicates first (remove_doubles),
then only true boundary loops remain (9 edges); fill the small loop on the board's front plane (normalised space as in
castle_window_dump.py: x 0.02..0.10, z 0.65..0.95), face it like its neighbours, and map it to a plain-wood spot.
  blender --background --factory-startup --python tools/glb_fill_board_hole.py -- <in.glb> <out.glb>
"""
import sys, bpy, bmesh
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
mw = obj.matrix_world
pts = [mw @ Vector(c) for c in obj.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
s = 2.0 / (hi.z - lo.z)
off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
def norm(co):  # same normalisation as castle_window_dump.py
    w = mw @ co
    return Vector(((w.x - off.x) * s, (w.y - off.y) * s, (w.z - off.z) * s))
bm = bmesh.new(); bm.from_mesh(obj.data)
uv = bm.loops.layers.uv.active
nv0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
print('[fill] merged verts', nv0, '->', len(bm.verts), 'boundary edges', sum(1 for e in bm.edges if e.is_boundary), flush=True)
b = [e for e in bm.edges if e.is_boundary]
seen, loops = set(), []
for e in b:
    if e in seen: continue
    stack, comp = [e], []
    while stack:
        x = stack.pop()
        if x in seen: continue
        seen.add(x); comp.append(x)
        for v in x.verts:
            for y in v.link_edges:
                if y.is_boundary and y not in seen: stack.append(y)
    loops.append(comp)
targets = []
for comp in loops:
    verts = {v for e in comp for v in e.verts}
    c = sum((norm(v.co) for v in verts), Vector()) / len(verts)
    if 0.02 < c.x < 0.10 and 0.0 < c.y < 0.8 and 0.65 < c.z < 0.95 and len(comp) <= 10:
        targets.append((comp, c))
print("[fill] candidate loops", [(len(c), tuple(round(v, 3) for v in cc)) for c, cc in targets], flush=True)
new_faces = []
for comp, c in targets:
    res = bmesh.ops.holes_fill(bm, edges=comp, sides=len(comp))
    new_faces += res["faces"]
bm.faces.ensure_lookup_table()
for f in new_faces:
    # outward like the neighbours
    nb = [lf for e in f.edges for lf in e.link_faces if lf is not f]
    if nb:
        avg = sum((x.normal for x in nb), Vector()) / len(nb)
        if f.normal.dot(avg) < 0:
            bmesh.ops.reverse_faces(bm, faces=[f])
    # map the whole new face onto a tiny spot in the middle of the biggest neighbouring plank face: plain wood,
    # no stretched streaks
    best = max(nb, key=lambda x: x.calc_area()) if nb else None
    if best is not None:
        cu = sum((l[uv].uv for l in best.loops), Vector((0, 0))) / len(best.loops)
        for i, loop in enumerate(f.loops):
            loop[uv].uv = cu + Vector(((i - 1) * 0.0015, (i % 2) * 0.0015))
bm.to_mesh(obj.data); bm.free(); obj.data.update()
bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True)
print("[fill] filled", len(new_faces), "faces ->", dst, flush=True)
