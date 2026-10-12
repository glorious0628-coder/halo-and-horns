"""Gold dome / cap check renders from four sides (이미지 생성 3, 10/12, 디자인 검수 '멍든 돔': the backs were never shown).

  blender --background --factory-startup --python tools/house_dome_sheet.py -- <out_dir> <house> [<house> ...]

For each art/models/tripo/house_deco/<house>/<house>_deco.glb: only the gold roof pieces (Dome, DomeRibs, CupolaDome,
TowerDome*, Finial*, PorchDome) with the skeleton frame (x, y = front, z up), Workbench studio light, material colour,
cameras front / right / back / left at 25 degrees up + back_top (behind, 50 degrees up) -> <out_dir>/<house>_<view>.png; then
py tools/house_dome_sheet.py --sheet <out_dir> makes <out_dir>/domes_sheet.jpg (one row a house).
"""
import math
import os
import sys

KEYS = ("_Dome", "_CupolaDome", "_TowerDome", "_Finial", "_PorchDome")
# (name, camera azimuth deg (0 = +x), elevation deg); front = +y, the viewer's right = -x; back_top = behind and above
# (디자인 검수 10/12: every dome sheet shows the back from above, not only the front)
VIEWS = (("front", 90, 25), ("right", 180, 25), ("back", -90, 25), ("left", 0, 25), ("back_top", -135, 50))

if "--sheet" in sys.argv:
    from PIL import Image, ImageDraw, ImageFont
    d = sys.argv[sys.argv.index("--sheet") + 1]
    hs = sorted({f[:-len("_%s.png" % v)] for f in os.listdir(d) for v, _, _ in VIEWS
                 if f.endswith("_%s.png" % v) and not (v == "back" and f.endswith("_back_top.png"))})
    W = 300
    S = Image.new("RGB", (len(VIEWS) * W + 160, len(hs) * W), (32, 32, 36))
    dr = ImageDraw.Draw(S)
    try:
        font = ImageFont.truetype("malgun.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for r, h in enumerate(hs):
        dr.text((6, r * W + 8), h.replace("HaloDomeHouse_", "집 ").replace("HaloShop_", ""), fill=(255, 215, 120), font=font)
        for i, (v, _, _) in enumerate(VIEWS):
            p = os.path.join(d, "%s_%s.png" % (h, v))
            if os.path.isfile(p):
                im = Image.open(p).convert("RGB")
                im.thumbnail((W, W))
                S.paste(im, (160 + i * W, r * W))
    for i, (v, _, _) in enumerate(VIEWS):
        dr.text((160 + i * W + 6, 4), {"front": "앞", "right": "오른쪽", "back": "뒤", "left": "왼쪽", "back_top": "뒤·위 3/4"}[v], fill=(230, 230, 230), font=font)
    S.save(os.path.join(d, "domes_sheet.jpg"), quality=88)
    print("[domes] sheet", os.path.join(d, "domes_sheet.jpg"))
    sys.exit(0)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

a = sys.argv[sys.argv.index("--") + 1:]
OUT, HOUSES = os.path.abspath(a[0]), a[1:]                  # absolute: Blender would put a relative render path elsewhere
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(OUT, exist_ok=True)
for h in HOUSES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "tripo", "house_deco", h, h + "_deco.glb"))
    keep = []
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and any(k in o.name for k in KEYS):
            keep.append(o)
        elif o.type == "MESH":
            bpy.data.objects.remove(o)
    if not keep:
        print("[domes] nothing in", h)
        continue
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for o in keep:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    cen, size = (mn + mx) / 2, max(mx - mn)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_specular_highlight = True
    sc.display.shading.show_cavity = True
    sc.render.resolution_x = sc.render.resolution_y = 600
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.16, 0.18, 0.22)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.12
    for v, az, el_ in VIEWS:
        el = math.radians(el_)
        dvec = Vector((math.cos(math.radians(az)) * math.cos(el), math.sin(math.radians(az)) * math.cos(el), math.sin(el)))
        cam.location = cen + dvec * size * 3
        cam.rotation_euler = (-dvec).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (h, v))
        bpy.ops.render.render(write_still=True)
    print("[domes]", h, len(keep), "pieces:", ", ".join(sorted(o.name for o in keep)), flush=True)
