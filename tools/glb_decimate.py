"""
Cut a heavy Tripo GLB down to a triangle budget and keep its textures (UVs stay, images are not resized).

  blender --background --factory-startup --python-exit-code 1 --python tools/glb_decimate.py -- <in.glb> <out.glb> <target_tris> [--weld 1e-5] [--rotz -90]

Why (2026-10-07): a Tripo web HD job ignored the 40k face setting and came out at 1,890,999 triangles (castle v4).
- --weld: merge vertices that sit on the same spot first (Tripo splits them along UV seams). UVs live on face corners in
  Blender, so welding keeps them; without it every UV seam is an open border that the collapse cannot remove.
- Collapse decimate, triangulated, one ratio per mesh so the whole model lands near <target_tris>.
- Export keeps the original materials and images (base colour, normal, ORM) at their full size.
- --rotz: turn the model around the up axis (degrees) and bake it in. The 4K "tripo_pbr_model_*_meshopt.glb" source of a
  web HD job faces +X in Blender (door of the Horns castle, 2026-10-07); --rotz -90 turns it to -Y, the front the
  tex_compare_render / tex_fix / split_uv_tiles (--kind web) defaults expect. 0 target change = plain re-save
  (also drops meshopt compression, which glb_replace_images.py cannot rewrite).
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
IN, OUT, TARGET = argv[0], argv[1], int(argv[2])
WELD = float(argv[argv.index("--weld") + 1]) if "--weld" in argv else 0.0
ROTZ = float(argv[argv.index("--rotz") + 1]) if "--rotz" in argv else 0.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


before = tris(meshes)
print(f"[decimate] in {before} tris, {len(meshes)} meshes", flush=True)
if WELD > 0:
    for o in meshes:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        n0 = len(bm.verts)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
        bm.to_mesh(o.data)
        print(f"[decimate] weld {o.name}: {n0} -> {len(bm.verts)} verts", flush=True)
        bm.free()
ratio = min(1.0, TARGET / max(before, 1))
for o in meshes:
    mod = o.modifiers.new("Dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
after = tris(meshes)
print(f"[decimate] ratio {ratio:.5f} -> {after} tris", flush=True)
if ROTZ:
    rot = Matrix.Rotation(math.radians(ROTZ), 4, "Z")
    for o in meshes:  # detach from glTF parent nodes, keep the world placement, then turn in world space
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = rot @ mw
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    print(f"[decimate] turned {ROTZ:g} deg around Z", flush=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="AUTO", export_apply=True)
print(f"[decimate] wrote {OUT}", flush=True)
