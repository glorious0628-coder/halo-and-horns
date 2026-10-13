"""2D | WorldKit day | night photos of placed Halo v2 props (이미지 생성 3, 10/13; A23-154 step 5 'Roblox material').

  STUDIO_NAME=WorldKit py tools/prop_ab_shots.py <out_dir> <PropId>=<2D png> [...] [--back] [--name sheet]

For each PropId (Workspace.HaloV2.Props, attribute PropId): the camera stands in front of the prop (its LookVector) at
3 x its height, a little above, C2c day then night (tools/halo_light_sim.luau), restored after. --back adds a shot from
behind (DoubleSided leaves / backs). Writes <out>/<PropId>_{day,night[,back]}.png and <out>/<name>.jpg (2D | day | night
[| back]). Needs the WorldKit viewport visible (not minimized, no big panel over it).
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from studio_mcp import Client  # noqa: E402

GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
REST = GUARD + open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
out = args[0]
pairs = [a.split("=", 1) for a in args[1:] if "=" in a]
back = "--back" in sys.argv
name = sys.argv[sys.argv.index("--name") + 1] if "--name" in sys.argv else "props_ab"
if name in [p[0] for p in pairs]:
    pairs = [p for p in pairs if p[0] != name]
os.makedirs(out, exist_ok=True)
c = Client()
c.start()


def luau(code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(tag, cam, look):
    if os.path.exists(CAPF):
        os.remove(CAPF)
    arg = os.path.join(os.environ.get("TEMP", ""), "ab_arg.json")
    json.dump({"capture_id": tag, "camera_position": cam, "look_at_position": look}, open(arg, "w"))
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "screen_capture", "@" + arg],
                   capture_output=True, text=True, encoding="utf-8", errors="replace", env=dict(os.environ), timeout=120)
    im = Image.open(CAPF).copy()
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


Q = GUARD + '''local id = "%s"
for _, d in workspace.HaloV2.Props:GetDescendants() do
  if d:GetAttribute("PropId") == id and d:IsA("PVInstance") then
    local pv = d:GetPivot(); local sz = d:IsA("Model") and select(2, d:GetBoundingBox()) or d.Size
    local l = Vector3.new(pv.LookVector.X, 0, pv.LookVector.Z).Unit
    return string.format("%%.3f,%%.3f,%%.3f,%%.4f,%%.4f,%%.3f,%%.3f", pv.X, pv.Y, pv.Z, l.X, l.Z, sz.Y, math.max(sz.X, sz.Z))
  end
end
return "none"'''
geo = {}
for pid, _ in pairs:
    r = luau(Q % pid)
    if r == "none":
        print("[ab] no prop", pid)
        continue
    x, y, z, lx, lz, h, w = [float(v) for v in r.split(",")]
    D = max(3.0 * h, 1.6 * w)
    geo[pid] = ([x + lx * D, y + h * 0.9, z + lz * D], [x - lx * D, y + h * 0.9, z - lz * D], [x, y + h * 0.5, z])
views = ["day", "night"] + (["back"] if back else [])
try:
    for ph in ("day", "night"):
        luau(SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "%s"' % ph))
        for pid, (cf, cb, look) in geo.items():
            grab(pid + ph, cf, look).save(os.path.join(out, "%s_%s.png" % (pid, ph)))
            if ph == "day" and back:
                grab(pid + "back", cb, look).save(os.path.join(out, "%s_back.png" % pid))
finally:
    luau(REST)
font = ImageFont.truetype("malgun.ttf", 16)
C = 300
rows = [p for p in pairs if p[0] in geo]
S = Image.new("RGB", (8 + (1 + len(views)) * (C + 8), 30 + len(rows) * (C + 26)), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((8, 6), "2D | WorldKit C2c " + " | ".join({"day": "낮", "night": "밤", "back": "뒤(낮)"}[v] for v in views), fill=(240, 240, 240), font=font)
for r, (pid, src) in enumerate(rows):
    y = 30 + r * (C + 26)
    d.text((8, y), pid + "  " + os.path.basename(src), fill=(255, 210, 120), font=font)
    for j, p in enumerate([os.path.join(ROOT, src)] + [os.path.join(out, "%s_%s.png" % (pid, v)) for v in views]):
        if os.path.isfile(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((C, C))
            S.paste(im, (8 + j * (C + 8), y + 22))
S.save(os.path.join(out, name + ".jpg"), quality=88)
print("[ab] ok", os.path.join(out, name + ".jpg"))
