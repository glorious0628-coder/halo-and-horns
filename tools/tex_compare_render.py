"""
질감·재질 비교 렌더(A23-73): GLB 하나를 compare_3d_render.py와 같은 조명으로 찍되, 텍스처 바꾸기·PBR 끄기·2D 시안과 같은 각도를 더한다.

  blender --background --factory-startup --python tools/tex_compare_render.py -- <in.glb> <out_dir> <label> [options]

options
  --tex <png>        base color 텍스처를 이 그림으로 바꿔서 찍기(④ 색 손보기, ③ 투영 굽기 결과 등)
  --no-pbr           노멀·금속/거칠기 맵을 빼고 색만(Roblox ColorMap만 쓴 것과 비슷하게)
  --views a,b,...    front34, back34, game, close, match (기본 front34,back34,game,close,match)
  --mr <png>         금속/거칠기 맵(glTF: G 거칠기, B 금속)을 이 그림으로 바꾸기(tex_mr_tune.py 결과)
  --sky              흰 하늘 대신 파란 하늘 그라데이션(금속·물에 하늘이 비침 — Roblox 하늘과 비슷하게)
  --front -y|+x|+y|-x  모델 앞이 Blender에서 어느 쪽인지(Tripo API = +x, 웹·우리 가져오기 GLB = +y/-y). 모든 시점을 그만큼 돌림
  views에 near = 문 앞에 다가간 플레이어 눈높이
  --cam <json>       match 시점 {"az":..,"el":..,"lens":..} (concept_cam_fit.py 결과). 없으면 match 안 찍음
  --res N            해상도(기본 768, match는 1024)
  --masks <dir>      시점 찾기용: 여러 az/el/lens로 흰 실루엣만 찍어 <dir>/m_<az>_<el>_<lens>.png 로 저장하고 끝
  --mask-grid "az0:az1:step,el0:el1:step,lens1/lens2/.."

- 크기를 높이 2로 맞추고 바닥 가운데에 세운다(compare_3d_render.py와 같은 정규화 → 같은 카메라 숫자가 통한다).
- 결과: <out_dir>/<label>_<view>.png, <out_dir>/<label>_stats.json
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
IN_GLB, OUT_DIR, LABEL = argv[0], os.path.abspath(argv[1]), argv[2]
opt = {"tex": None, "no_pbr": False, "views": "front34,back34,game,close,match", "cam": None, "res": 768,
       "masks": None, "mask_grid": "-30:30:5,5:45:5,35/50/85", "mr": None, "sky": False, "front": "-y"}
i = 3
while i < len(argv):
    k = argv[i]
    if k in ("--no-pbr", "--sky"):
        opt[k[2:].replace("-", "_")] = True
        i += 1
        continue
    opt[k[2:].replace("-", "_")] = argv[i + 1]
    i += 2
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


root = bpy.data.objects.new("Root", None)
bpy.context.scene.collection.objects.link(root)
for o in bpy.context.scene.objects:
    if o.parent is None and o is not root:
        o.parent = root
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
s = 2.0 / max(hi.z - lo.z, 1e-6)
root.scale = (s, s, s)
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
bpy.context.view_layer.update()
lo, hi = bbox(meshes)
centre = (lo + hi) / 2
radius = (hi - lo).length / 2

scene = bpy.context.scene
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def place(az, el, lens, zoom=1.0, aim=None):
    cam_data.lens = lens
    fov = 2 * math.atan(cam_data.sensor_width / 2 / lens)
    dist = radius / math.sin(fov / 2) * 1.05 * zoom
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    target = aim if aim is not None else centre
    cam.location = target + d * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]

# ---------- mode 1: silhouettes for camera fitting ----------
if opt["masks"]:
    md = os.path.abspath(opt["masks"])
    os.makedirs(md, exist_ok=True)
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "SINGLE"
    sh.single_color = (1, 1, 1)
    scene.display.render_aa = "OFF"
    scene.view_settings.view_transform = "Standard"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("W")
    world.color = (0, 0, 0)
    scene.world = world
    sh.background_type = "WORLD"
    scene.render.resolution_x = scene.render.resolution_y = 256
    ga, ge, gl = opt["mask_grid"].split(",")
    a0, a1, ast = (float(x) for x in ga.split(":"))
    e0, e1, est = (float(x) for x in ge.split(":"))
    lenses = [float(x) for x in gl.split("/")]
    n = 0
    az = a0
    while az <= a1 + 1e-6:
        el = e0
        while el <= e1 + 1e-6:
            for ln in lenses:
                place(az, el, ln)
                scene.render.filepath = os.path.join(md, f"m_{az:g}_{el:g}_{ln:g}.png")
                bpy.ops.render.render(write_still=True)
                n += 1
            el += est
        az += ast
    print("[tex_compare_render] masks", n, md, flush=True)
    sys.exit(0)

# ---------- mode 2: comparison renders ----------
mats = {m for o in meshes for m in o.data.materials if m}
swapped = []
for m in mats:
    nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        continue
    if opt["tex"]:
        link = bsdf.inputs["Base Color"].links
        if link:
            node = link[0].from_node
            while node.type != "TEX_IMAGE" and node.inputs and node.inputs[0].links:
                node = node.inputs[0].links[0].from_node
            if node.type == "TEX_IMAGE":
                img = bpy.data.images.load(os.path.abspath(opt["tex"]))
                img.colorspace_settings.name = "sRGB"
                node.image = img
                swapped.append(m.name)
    if opt["mr"]:
        for name in ("Metallic", "Roughness"):
            node = bsdf.inputs[name].links[0].from_node if bsdf.inputs[name].links else None
            while node is not None and node.type != "TEX_IMAGE":
                node = node.inputs[0].links[0].from_node if node.inputs and node.inputs[0].links else None
            if node is not None:
                img = bpy.data.images.load(os.path.abspath(opt["mr"]), check_existing=True)
                img.colorspace_settings.name = "Non-Color"
                node.image = img
                swapped.append(m.name + ":" + name)
    if opt["no_pbr"]:
        for name in ("Normal", "Metallic", "Roughness"):
            for l in list(bsdf.inputs[name].links):
                nt.links.remove(l)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.5

scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
bgn = world.node_tree.nodes["Background"]
bgn.inputs[0].default_value = (1, 1, 1, 1)
bgn.inputs[1].default_value = 0.9
if opt["sky"]:
    # ground grey -> pale horizon -> blue zenith, about as bright overall as the flat white sky
    wn, wl = world.node_tree.nodes, world.node_tree.links
    tc = wn.new("ShaderNodeTexCoord")
    sep = wn.new("ShaderNodeSeparateXYZ")
    mp = wn.new("ShaderNodeMapRange")
    mp.inputs["From Min"].default_value = -1.0
    ramp = wn.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.40, (0.42, 0.40, 0.36, 1)
    els[1].position, els[1].color = 1.0, (0.30, 0.55, 1.0, 1)
    e = els.new(0.5)
    e.color = (0.92, 0.95, 1.0, 1)
    wl.new(tc.outputs["Generated"], sep.inputs[0])
    wl.new(sep.outputs["Z"], mp.inputs["Value"])
    wl.new(mp.outputs["Result"], ramp.inputs["Fac"])
    wl.new(ramp.outputs["Color"], bgn.inputs[0])
    bgn.inputs[1].default_value = 1.0
scene.world = world
sun_d = bpy.data.lights.new("Sun", "SUN")
sun_d.energy = 2.2
sun_d.angle = math.radians(8)
sun = bpy.data.objects.new("Sun", sun_d)
scene.collection.objects.link(sun)
YAW = {"-y": 0, "+x": 90, "+y": 180, "-x": 270}[opt["front"]]  # which way the model's front faces in Blender
sun.rotation_euler = (math.radians(50), 0, math.radians(-35 + YAW))
scene.render.film_transparent = True

VIEWS = {"front34": (30, 12, 50, 1.0, None), "back34": (210, 12, 50, 1.0, None), "game": (20, 35, 50, 1.0, None),
         # a player walking up to the gate: low camera, close, looking at the lower third
         "near": (18, 6, 35, 0.34, Vector((centre.x, centre.y, lo.z + 0.3 * (hi.z - lo.z)))),
         # close-up on the upper tiers (crown, water, gold trim) for the texture/material row
         "close": (20, 22, 50, 0.48, Vector((centre.x, centre.y, lo.z + 0.62 * (hi.z - lo.z))))}
cam_fit = json.load(open(opt["cam"], encoding="utf-8")) if opt["cam"] else None
for v in opt["views"].split(","):
    if v == "match":
        if not cam_fit:
            continue
        place(cam_fit["az"], cam_fit["el"], cam_fit["lens"])
        scene.render.resolution_x = scene.render.resolution_y = 1024
    else:
        az, el, ln, zoom, aim = VIEWS[v]
        place(az + YAW, el, ln, zoom, aim)
        scene.render.resolution_x = scene.render.resolution_y = int(opt["res"])
    scene.render.filepath = os.path.join(OUT_DIR, f"{LABEL}_{v}.png")
    bpy.ops.render.render(write_still=True)

stats = {"label": LABEL, "file": IN_GLB.replace("\\", "/"), "tex": opt["tex"], "mr": opt["mr"], "sky": opt["sky"], "no_pbr": opt["no_pbr"],
         "swapped": swapped, "images": sorted({f"{im.size[0]}x{im.size[1]}" for im in bpy.data.images if im.size[0]})}
json.dump(stats, open(os.path.join(OUT_DIR, f"{LABEL}_stats.json"), "w"), indent=1)
print("[tex_compare_render] ok", json.dumps(stats), flush=True)
