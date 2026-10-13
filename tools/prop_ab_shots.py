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


Q = GUARD + '''local id = "%s"
local m
for _, d in workspace.HaloV2.Props:GetDescendants() do if d:GetAttribute("PropId") == id and d:IsA("PVInstance") then m = d end end
if not m then return "none" end
local pv = m:GetPivot(); local sz = m:IsA("Model") and select(2, m:GetBoundingBox()) or m.Size
local h, w = sz.Y, math.max(sz.X, sz.Z)
local look = Vector3.new(pv.X, pv.Y + h * 0.5, pv.Z)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {m}
local D = math.max(3.0 * h, 1.6 * w)
local function cam(dir)
  -- from the prop outwards: stop before walls, keep the camera above the ground there
  local d = Vector3.new(dir.X, 0, dir.Z).Unit
  local want = look + d * D + Vector3.new(0, h * 0.4, 0)
  local hit = workspace:Raycast(look, want - look, rp)
  local p = hit and (look + (hit.Position - look) * 0.85) or want
  local g = workspace:Raycast(Vector3.new(p.X, p.Y + 50, p.Z), Vector3.new(0, -100, 0), rp)
  if g and p.Y < g.Position.Y + 1.5 then p = Vector3.new(p.X, g.Position.Y + 1.5, p.Z) end
  return p, (p - look).Magnitude
end
local L = pv.LookVector
local f, fd = cam(L)
local b, bd = cam(-L)
if bd < h * 1.2 then for _, a in {60, -60, 120, -120} do local r = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(-L); local p2, d2 = cam(r); if d2 > bd then b, bd = p2, d2 end end end
return string.format("%%.3f,%%.3f,%%.3f,%%.3f,%%.3f,%%.3f,%%.3f,%%.3f,%%.3f", f.X, f.Y, f.Z, b.X, b.Y, b.Z, look.X, look.Y, look.Z)'''
luau(HIDE)   # before the camera rays, so stand-in boxes do not block them
geo = {}
for pid, _ in pairs:
    r = luau(Q % pid)
    if r == "none":
        print("[ab] no prop", pid)
        continue
    v = [float(x) for x in r.split(",")]
    geo[pid] = (v[0:3], v[3:6], v[6:9])
views = ["day", "night"] + (["back"] if back else [])
try:
    luau(HIDE)
    for ph in ("day", "night"):
        luau(SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "%s"' % ph))
        for pid, (cf, cb, look) in geo.items():
            grab(pid + ph, cf, look).save(os.path.join(out, "%s_%s.png" % (pid, ph)))
            if ph == "day" and back:
                grab(pid + "back", cb, look).save(os.path.join(out, "%s_back.png" % pid))
finally:
    luau(REST)
    luau(SHOW)
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
