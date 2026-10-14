"""Blender (background) script: build a clean 'structure first' flower-bush base mesh — a dome of rounded leaf puffs
plus flower blobs — sized from a 2D front view's silhouette, and export a GLB for a retexture step (Meshy retexture
with our 4 shadow-free views; A23-167 test 4, user 10/13: "구조를 먼저 한 다음에 입히기").

  blender --background --factory-startup --python tools/bush_base.py -- <out.glb> [width height depth] [puffs] [flowers]

Units = Blender metres (1 = 1 stud later in Studio; sized in Blender step 5 anyway). Default 1.9 x 0.9 x 1.3 (NEW_FlowerBush).
Output: one joined mesh, triangles ~6-9k, smooth shaded, no materials (the retexture gives them).
"""
import math
import random
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "build/bush_base.glb"
w = float(args[1]) if len(args) > 1 else 1.9
h = float(args[2]) if len(args) > 2 else 0.9
d = float(args[3]) if len(args) > 3 else 1.3
n_puffs = int(args[4]) if len(args) > 4 else 14
n_flowers = int(args[5]) if len(args) > 5 else 9

bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(7)
objs = []

def puff(x, y, z, r, seg=24, ring=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = (1.0, 1.0, 0.75)  # leaf puffs are a little flattened
    objs.append(o)
    return o

# base dome body: a squashed sphere so the silhouette is a dome
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=1.0, location=(0, 0, h * 0.32))
body = bpy.context.active_object
body.scale = (w * 0.46, d * 0.46, h * 0.5)
objs.append(body)

# leaf puffs: three bands around the dome + a top cluster, dense enough to hide the body
bands = [(0.30, 1.0, int(n_puffs * 0.45)), (0.60, 0.85, int(n_puffs * 0.35)), (0.85, 0.55, max(3, n_puffs - int(n_puffs * 0.45) - int(n_puffs * 0.35)))]
for t, rad, cnt in bands:
    for i in range(cnt):
        a = (i / cnt) * 2 * math.pi + random.uniform(-0.15, 0.15)
        x = math.cos(a) * w * 0.46 * rad
        y = math.sin(a) * d * 0.46 * rad
        z = h * t + random.uniform(-0.04, 0.04)
        r = random.uniform(0.15, 0.21) * (w / 1.9)
        puff(x, y, z, r)
puff(0, 0, h * 0.98, 0.2 * (w / 1.9))

# flowers: flat discs lying ON the surface (normal = direction from the dome centre), mostly on the front half
for i in range(n_flowers):
    a = random.uniform(-0.95, 0.95) * math.pi + math.pi * 1.5
    t = random.uniform(0.45, 0.9)
    rad = math.sqrt(max(0.05, 1 - ((t - 0.3) / 0.7) ** 2))
    x = math.cos(a) * w * 0.49 * rad
    y = math.sin(a) * d * 0.49 * rad
    z = h * t
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.12 * (w / 1.9), location=(x, y, z))
    f = bpy.context.active_object
    f.scale = (1.0, 1.0, 0.3)
    # point the disc's local Z along the outward direction from the dome centre
    import mathutils
    nrm = mathutils.Vector((x / max(w, 0.1), y / max(d, 0.1), (z - h * 0.3) / max(h, 0.1))).normalized()
    f.rotation_euler = nrm.to_track_quat("Z", "Y").to_euler()
    objs.append(f)

for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()
bush = bpy.context.active_object
bush.name = "BushBase"
bpy.ops.object.shade_smooth()
# merge overlaps into one shell (voxel remesh keeps it watertight for the texture step)
mod = bush.modifiers.new("Remesh", "REMESH")
mod.mode = "VOXEL"
mod.voxel_size = 0.03 * (w / 1.9)
bpy.ops.object.modifier_apply(modifier="Remesh")
dec = bush.modifiers.new("Dec", "DECIMATE")
dec.ratio = 0.25
bpy.ops.object.modifier_apply(modifier="Dec")
bpy.ops.object.shade_smooth()
# pivot: bottom centre
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
mn = min(v.co.z for v in bush.data.vertices)
for v in bush.data.vertices:
    v.co.z -= mn
bush.location = (0, 0, 0)
tris = sum(len(p.vertices) - 2 for p in bush.data.polygons)
print("BUSH tris", tris, "dims", [round(x, 3) for x in bush.dimensions])
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True)
print("saved", out)
