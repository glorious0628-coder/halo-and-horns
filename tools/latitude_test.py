"""Sun side test in WorldKit (이미지 생성 3, 10/12; 최종 검수): which Lighting.GeographicLatitude lights the Halo-town
building fronts better at the C2c day time. The castle door looks +Z (plan yaw 20), the houses look every way.

  STUDIO_NAME=WorldKit py tools/latitude_test.py <out_dir> [--show] [--lats 35,-41.7,65]

C2c day light (tools/halo_light_sim.luau, latitude 35, ClockTime 15.3), then for every latitude: GeographicLatitude set,
one photo in front of each building door on its plan spot (Workspace.HaloV2.Buildings, door_at / door_dir from
docs/design/halo_plan_v2_2026-10-11.json) + the sun direction and door . sun. Light restored after. --show:
ShowWindowAsync(9) before, (6) after (최종 검수 screen slot, no mouse / keyboard).
Writes <out>/<building>_lat<v>.png, <out>/latitude_test.jpg (rows = buildings, columns = latitudes) and <out>/sun.json.
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
# building id: (camera distance out of the door, camera height over the door, look-at height)
PICK = {"Castle": (60, 30, 16), "Shop_Bakery": (22, 8, 6), "Shop_Juice": (22, 8, 6), "House_Cliff6": (22, 8, 6)}
LAT = GUARD + '''local L = game:GetService("Lighting")
L.GeographicLatitude = %s
local s = L:GetSunDirection()
return string.format("%%.3f,%%.3f,%%.3f", s.X, s.Y, s.Z)'''

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--show", action="store_true")
ap.add_argument("--lats", default="35,-41.7,65")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
lats = [float(v) for v in a.lats.split(",")]
plan = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
B = {b["id"]: b for b in plan["buildings"]}
CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")


def cam(bid):
    b = B[bid]
    (x, z), (dx, dz), y = b["door_at"], b["door_dir"], b["ground_y"]
    D, h, lh = PICK[bid]
    return [x + dx * D, y + h, z + dz * D], [x, y + lh, z]


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(tag, cpos, look):
    if os.path.exists(CAPF):
        os.remove(CAPF)
    arg = os.path.join(os.environ.get("TEMP", ""), "lat_cap_arg.json")
    json.dump({"capture_id": "lat_" + tag, "camera_position": cpos, "look_at_position": look}, open(arg, "w"))
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
    sys.exit("[lat] WorldKit window not found (or more than one)")
sun = {}
try:
    if wk:
        U32.ShowWindowAsync(wk, 9)
        time.sleep(2.5)
    print("[lat]", luau(c, SIM)[:60], flush=True)
    for lat in lats:
        sd = [float(v) for v in luau(c, LAT % lat).split(",")]
        sun[str(lat)] = {"sun": sd, "door_dot_sun": {k: round(B[k]["door_dir"][0] * sd[0] + B[k]["door_dir"][1] * sd[2], 2) for k in PICK}}
        print("[lat]", lat, sun[str(lat)], flush=True)
        time.sleep(0.8)
        for bid in PICK:
            grab("%s_%s" % (bid, lat), *cam(bid)).save(os.path.join(a.out, "%s_lat%s.png" % (bid, lat)))
finally:
    print("[lat] light", luau(c, GUARD + RESTORE)[:60], flush=True)
    if wk:
        U32.ShowWindowAsync(wk, 6)
        print("[lat] WorldKit minimized", flush=True)
json.dump(sun, open(os.path.join(a.out, "sun.json"), "w"), indent=1)

font = ImageFont.truetype("malgun.ttf", 18)
small = ImageFont.truetype("malgun.ttf", 14)
CELL = 380
S = Image.new("RGB", (150 + len(lats) * (CELL + 10), 70 + len(PICK) * (CELL + 10)), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((10, 8), "해 방향 시험 (C2c 낮 15.3시, GeographicLatitude) — 칸 아래 숫자 = 문·해 (1 정면 해, 0 옆, -1 등짐)", fill=(240, 240, 240), font=font)
for j, lat in enumerate(lats):
    d.text((150 + j * (CELL + 10), 40), "lat %g" % lat, fill=(255, 210, 120), font=font)
for i, bid in enumerate(PICK):
    y = 70 + i * (CELL + 10)
    d.text((8, y + 8), bid, fill=(255, 210, 120), font=small)
    for j, lat in enumerate(lats):
        p = os.path.join(a.out, "%s_lat%s.png" % (bid, lat))
        if os.path.isfile(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((CELL, CELL))
            S.paste(im, (150 + j * (CELL + 10), y))
        d.text((150 + j * (CELL + 10) + 6, y + CELL - 24), "문·해 %+.2f" % sun[str(lat)]["door_dot_sun"][bid],
               fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(0, 0, 0))
S.save(os.path.join(a.out, "latitude_test.jpg"), quality=88)
print("[lat] ok", a.out, flush=True)
