"""2D | WorldKit day | night photos of Halo v2 buildings (plan spots) after decoration (이미지 생성 3, 10/13).

  STUDIO_NAME=WorldKit py tools/building_ab_shots.py <out_dir> <Building>=<2D png>[@dist] [...] [--name sheet] [--close]

Camera in front of the building (its pivot LookVector = front, -Z of the house frame) at `dist` studs (default 34), height
10, looking at the door height; --close adds a 12-stud shot of the door. C2c day / night light, restored after.
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from studio_mcp import Client  # noqa: E402
from shot_hide import HIDE, SHOW  # noqa: E402

GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
REST = GUARD + open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
out = args[0]
name = sys.argv[sys.argv.index("--name") + 1] if "--name" in sys.argv else "buildings_ab"
close = "--close" in sys.argv
items = []
for a in args[1:]:
    if "=" not in a or a == name:
        continue
    bn, rest = a.split("=", 1)
    src, _, dist = rest.partition("@")
    items.append((bn, src, float(dist) if dist else 34.0))
os.makedirs(out, exist_ok=True)
c = Client()
c.start()


def luau(code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(tag, cam, look):
    if os.path.exists(CAPF):
        os.remove(CAPF)
    arg = os.path.join(os.environ.get("TEMP", ""), "bab_arg.json")
    json.dump({"capture_id": tag, "camera_position": cam, "look_at_position": look}, open(arg, "w"))
    for k in range(2):   # 10/13: the first capture moves the camera, terrain there is drawn only after a moment
        if k:
            time.sleep(2.5)
            if os.path.exists(CAPF):
                os.remove(CAPF)
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "screen_capture", "@" + arg],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=dict(os.environ), timeout=120)
    im = Image.open(CAPF).copy()
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


Q = '''local b = workspace.HaloV2.Buildings:FindFirstChild("%s"); if not b then return "none" end
local f = b:GetPivot(); local d = nil
for _, x in b:GetDescendants() do if x:IsA("Attachment") and x.Name == "DoorFront" then d = x.WorldPosition end end
local p = d or f.Position
local l = f.LookVector
return string.format("%%.3f,%%.3f,%%.3f,%%.4f,%%.4f", p.X, p.Y, p.Z, l.X, l.Z)'''
luau(HIDE)   # before the camera rays, so stand-in boxes do not block them
geo = {}
for bn, src, dist in items:
    r = luau(Q % bn)
    if r == "none":
        print("[bab] no building", bn)
        continue
    x, y, z, lx, lz = [float(v) for v in r.split(",")]
    geo[bn] = ([x + lx * dist, y + 10, z + lz * dist], [x, y + 7, z], [x + lx * 12, y + 5, z + lz * 12], [x, y + 4.5, z])
views = ["day", "night"] + (["close"] if close else [])
try:
    luau(HIDE)
    for ph in ("day", "night"):
        luau(SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "%s"' % ph))
        for bn, g in geo.items():
            grab(bn + ph, g[0], g[1]).save(os.path.join(out, "%s_%s.png" % (bn, ph)))
            if ph == "day" and close:
                grab(bn + "close", g[2], g[3]).save(os.path.join(out, "%s_close.png" % bn))
finally:
    luau(REST)
    luau(SHOW)
font = ImageFont.truetype("malgun.ttf", 16)
C = 320
rows = [i for i in items if i[0] in geo]
S = Image.new("RGB", (8 + (1 + len(views)) * (C + 8), 30 + len(rows) * (C + 26)), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((8, 6), "2D | WorldKit C2c " + " | ".join({"day": "낮", "night": "밤", "close": "문 가까이(낮)"}[v] for v in views), fill=(240, 240, 240), font=font)
for r, (bn, src, _) in enumerate(rows):
    y = 30 + r * (C + 26)
    d.text((8, y), bn + "  " + os.path.basename(src), fill=(255, 210, 120), font=font)
    for j, p in enumerate([os.path.join(ROOT, src)] + [os.path.join(out, "%s_%s.png" % (bn, v)) for v in views]):
        if os.path.isfile(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((C, C))
            S.paste(im, (8 + j * (C + 8), y + 22))
S.save(os.path.join(out, name + ".jpg"), quality=88)
print("[bab] ok", os.path.join(out, name + ".jpg"))
