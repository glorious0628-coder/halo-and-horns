"""Castle C2 marble look test + top view of the castle plaza props in WorldKit (이미지 생성 3, 10/12; 최종 검수: the skeleton
marble looks greyer than the 2D white marble -> one test with the existing Halo marble MaterialVariants only, no new MV).

  STUDIO_NAME=WorldKit py tools/castle_marble_test.py <out_dir> [--show]

C2c day light (tools/halo_light_sim.luau). The test row castle (SkeletonTest.HaloCastle_C2_Skeleton) marble walls
(Material Marble + HH_HaloMarbleBlock_Cream, colour 255,244,222; the floor parts 238,226,205 stay) are switched through the
variants below, one front photo each, then put back as they were. Plus one top view of the plan-spot castle and the moved
plaza props. --show: ShowWindowAsync(9) before, (6) after (최종 검수 screen slot, no mouse / keyboard).
Writes <out>/<variant>.png, <out>/top_plan.png and the sheet <out>/castle_marble_test.jpg (2D front | variants).
"""
import argparse
import ctypes
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from studio_mcp import Client  # noqa: E402

GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read().replace(
    'local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "day"')
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
# name: (MaterialVariant, colour)
VARS = {
    "A_now_BlockCream_255_244_222": ("HH_HaloMarbleBlock_Cream", (255, 244, 222)),
    "B_BlockCream_255_252_244": ("HH_HaloMarbleBlock_Cream", (255, 252, 244)),
    "C_SmoothCream_255_250_238": ("HH_HaloMarbleSmooth_Cream", (255, 250, 238)),
    "D_Block_255_250_240": ("HH_HaloMarbleBlock", (255, 250, 240)),
}
SET = GUARD + '''local mv, r, g, b = "%s", %d, %d, %d
local n = 0
for _, p in workspace.SkeletonTest.HaloCastle_C2_Skeleton:GetDescendants() do
  if p:IsA("BasePart") and p.Material == Enum.Material.Marble then
    if p:GetAttribute("MarbleTestOrig") == nil then
      p:SetAttribute("MarbleTestOrig", string.format("%%s|%%d,%%d,%%d", p.MaterialVariant, math.round(p.Color.R * 255), math.round(p.Color.G * 255), math.round(p.Color.B * 255)))
    end
    local o = string.split(p:GetAttribute("MarbleTestOrig"), "|")
    if o[2] == "255,244,222" then p.MaterialVariant = mv; p.Color = Color3.fromRGB(r, g, b); n += 1 end
  end
end
return "walls " .. n'''
BACK = GUARD + '''local n = 0
for _, p in workspace.SkeletonTest.HaloCastle_C2_Skeleton:GetDescendants() do
  local o = p:GetAttribute("MarbleTestOrig")
  if o then
    local s = string.split(o, "|"); local c = string.split(s[2], ",")
    p.MaterialVariant = s[1]; p.Color = Color3.fromRGB(tonumber(c[1]), tonumber(c[2]), tonumber(c[3])); p:SetAttribute("MarbleTestOrig", nil); n += 1
  end
end
return "restored " .. n'''
FRONT = ([3000, 30, 188], [3000, 25, 257])
TOP = ([-160, 150, -515], [-160, 16, -532])

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--show", action="store_true")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(tag, cam, look):
    if os.path.exists(CAPF):
        os.remove(CAPF)
    arg = os.path.join(os.environ.get("TEMP", ""), "marble_cap_arg.json")
    json.dump({"capture_id": "marble_" + tag, "camera_position": cam, "look_at_position": look}, open(arg, "w"))
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "screen_capture", "@" + arg],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=dict(os.environ), timeout=120)
    if not os.path.exists(CAPF):
        raise RuntimeError("no image for %s: %s" % (tag, (r.stdout + r.stderr)[-300:]))
    im = Image.open(CAPF).copy()
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


U32 = ctypes.windll.user32


def worldkit_hwnd():
    hs = []

    def cb(h, _):
        n = U32.GetWindowTextLengthW(h)
        if n:
            b = ctypes.create_unicode_buffer(n + 1)
            U32.GetWindowTextW(h, b, n + 1)
            t = b.value
            if "WorldKit.rbxlx" in t and "Roblox Studio" in t and "GoodEvil" not in t:
                hs.append(h)
        return True
    U32.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(cb), 0)
    return hs[0] if len(hs) == 1 else None


c = Client()
c.start()
wk = worldkit_hwnd() if a.show else None
if a.show and not wk:
    sys.exit("[marble] WorldKit window not found (or more than one)")
try:
    if wk:
        U32.ShowWindowAsync(wk, 9)
        time.sleep(2.5)
    print("[marble]", luau(c, SIM)[:60], flush=True)
    for k, (mv, col) in VARS.items():
        print("[marble]", k, luau(c, SET % ((mv,) + col)), flush=True)
        time.sleep(0.8)
        grab(k, *FRONT).save(os.path.join(a.out, k + ".png"))
    print("[marble]", luau(c, BACK), flush=True)
    grab("top", *TOP).save(os.path.join(a.out, "top_plan.png"))
finally:
    print("[marble] back", luau(c, BACK), "| light", luau(c, GUARD + RESTORE)[:50], flush=True)
    if wk:
        U32.ShowWindowAsync(wk, 6)
        print("[marble] WorldKit minimized", flush=True)

try:
    font = ImageFont.truetype("malgun.ttf", 20)
except OSError:
    font = ImageFont.load_default()
CELL = 420
cells = [("2D front", os.path.join(ROOT, "art/out/s2/halo/castle6/HaloCastle_C2_front_HQ_src.png"))] + \
    [(k, os.path.join(a.out, k + ".png")) for k in VARS]
S = Image.new("RGB", (len(cells) * (CELL + 10) + 10, CELL + 80), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((10, 8), "빛 성 C2 대리석 시험 (C2c 낮, 있는 빛 마을 대리석 MV만)", fill=(240, 240, 240), font=font)
for j, (lab, p) in enumerate(cells):
    x = 10 + j * (CELL + 10)
    d.text((x, 40), lab, fill=(255, 210, 120), font=ImageFont.truetype("malgun.ttf", 14) if font else font)
    if os.path.isfile(p):
        im = Image.open(p).convert("RGB")
        im.thumbnail((CELL, CELL))
        S.paste(im, (x, 64))
S.save(os.path.join(a.out, "castle_marble_test.jpg"), quality=90)
print("[marble] ok", a.out, flush=True)
