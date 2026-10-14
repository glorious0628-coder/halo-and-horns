"""Size / pivot / orientation ONLY for a raw Tripo HD weapon (무기 디자인, A23-187; no colour, shape or bake changes, A23-147/154).

- long axis -> Roblox +Y (tip / head up; Tripo's raw +Z is up), uniform scale so the whole weapon is <length> studs (1 GLB unit = 1 stud)
- front (the 2D front face, raw +X for the Tripo multi-view) -> Blender +Y = glTF -Z = Roblox -Z (front looks at the camera)
- origin = the grip point: kind "sword" = the middle of the narrow grip between the pommel and the guard (found from the
  width profile), or --grip <share> = that share of the length up from the bottom end
  blender --background --factory-startup --python tools/weapon_hd_fit.py -- <in.glb> <out.glb> <length> [--kind sword] [--grip 0.2]
  -> out.glb + out.json (before / after size, grip range, tris)
"""
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix

a = sys.argv[sys.argv.index("--") + 1:]
src, out, length = a[0], a[1], float(a[2])
kind = a[a.index("--kind") + 1] if "--kind" in a else "sword"
grip_share = float(a[a.index("--grip") + 1]) if "--grip" in a else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        o.select_set(False)
bpy.context.view_layer.objects.active = obs[0]
for o in obs:
    o.select_set(True)
if len(obs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
for o in list(bpy.context.scene.objects):
    if o is not ob:
        bpy.data.objects.remove(o)
ob.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
V = np.array([v.co[:] for v in ob.data.vertices])
before = np.ptp(V, 0)
assert np.argmax(before) == 2, f"long axis is not Z: {before}"
z0, z1 = V[:, 2].min(), V[:, 2].max()
s = length / (z1 - z0)
# grip point from the profile (raw units)
n = 200
zs = np.linspace(z0, z1, n + 1)
wid = np.zeros(n)
for i in range(n):
    m = (V[:, 2] >= zs[i]) & (V[:, 2] < zs[i + 1])
    wid[i] = max(np.ptp(V[m, 0]), np.ptp(V[m, 1])) if m.sum() > 2 else 0
info = {"kind": kind}
if grip_share is not None:
    gz = z0 + grip_share * (z1 - z0)
    info["grip_share"] = grip_share
else:
    low = wid[: n // 2]
    grip_w = np.median(low[int(n * 0.1): int(n * 0.2)])
    i = int(np.argmax(low[: int(n * 0.12)]))  # pommel bulge
    while i < len(low) and low[i] > grip_w * 1.15:
        i += 1
    lo_i = i
    while i < len(low) and low[i] < grip_w * 1.6:
        i += 1
    hi_i = i
    g0, g1 = zs[lo_i], zs[hi_i]
    gz = (g0 + g1) / 2
    info.update({"grip_from": round(float((g0 - z0) / (z1 - z0)), 3), "grip_to": round(float((g1 - z0) / (z1 - z0)), 3),
                 "grip_width_raw": round(float(grip_w), 4)})
cx, cy = (V[:, 0].min() + V[:, 0].max()) / 2, (V[:, 1].min() + V[:, 1].max()) / 2
T = Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -gz))
ob.data.transform(T)
ob.data.update()
V2 = np.array([v.co[:] for v in ob.data.vertices])
ob.data.calc_loop_triangles()
info.update({"src": src, "out": out, "length_studs": length, "scale": round(s, 4),
             "before_raw": before.round(4).tolist(), "after_studs_xyz_blender": np.ptp(V2, 0).round(3).tolist(),
             "grip_point_share": round(float((gz - z0) / (z1 - z0)), 3), "tris": len(ob.data.loop_triangles),
             "frame": "origin = grip point; Roblox +Y (glTF +Y) = tip; Roblox -Z = 2D front face"})
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_yup=True)
json.dump(info, open(out[:-4] + ".json", "w"), indent=1)
print("FIT", json.dumps(info))
