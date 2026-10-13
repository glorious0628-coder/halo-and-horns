"""C2c day photos of the Halo light castle C2 skeleton in WorldKit next to its 2D (이미지 생성 3, 10/12; A23-120).

  STUDIO_NAME=WorldKit py tools/castle_shots.py <out_dir> [--show] [--dry]

Test row 4 (Workspace.SkeletonTest.HaloCastle_C2_Skeleton, origin 3000,0,260, door side = -Z) from the 2D angles
(final 3/4, front, left = camera on +X, right = camera on -X, back) + the plan spot (Workspace.HaloV2.Buildings.Castle,
from the plaza in front of the door). Sets the main Halo-town light (tools/halo_light_sim.luau, C2c day), restores it after.
--show: ShowWindowAsync(9) on the WorldKit window before shooting and (6) after (a minimized Studio captures white; a
최종 검수 screen slot, no mouse / keyboard). --dry: print the camera table only.
Writes <out>/<shot>.png and the sheet <out>/castle_C2_wk_day.jpg (2D | Studio).
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
SIM0 = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
D2 = "art/out/s2/halo/castle6/HaloCastle_C2_%s.png"
# shot: (2D file, camera, look-at)
SHOTS = {
    "q34": (D2 % "final_src", [2925, 45, 190], [3000, 22, 257]),
    "front": (D2 % "front_HQ_src", [3000, 30, 188], [3000, 25, 257]),
    "left": (D2 % "left_src", [3085, 28, 257], [3000, 25, 257]),
    "right": (D2 % "right_HQ_src", [2915, 28, 257], [3000, 25, 257]),
    "back": (D2 % "back_src", [3000, 28, 342], [3000, 25, 257]),
}
# plan spot: door -162.3, 16.8, -536.4, door dir (0.342, 0, 0.94); body centre ~ -171.5, -561.8
PLAN = (D2 % "final_src", [-141.8, 46, -480.0], [-171.5, 36, -561.8])

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--show", action="store_true")
ap.add_argument("--dry", action="store_true")
ap.add_argument("--phase", default="day", choices=["day", "night"], help="C2c day or night light (halo_light_sim; the castle skeleton has no lamps yet)")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
allshots = dict(SHOTS, plan=PLAN)
SIM = SIM0.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "%s"' % a.phase)
if a.dry:
    for k, v in allshots.items():
        print(k, v)
    sys.exit(0)

CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(tag, cam, look):
    """one screen_capture per fresh CLI call (a long-lived client never got the image back, 10/12)"""
    if os.path.exists(CAPF):
        os.remove(CAPF)
    arg = os.path.join(os.environ.get("TEMP", ""), "castle_cap_arg.json")
    json.dump({"capture_id": "castle_" + tag, "camera_position": cam, "look_at_position": look}, open(arg, "w"))
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
    sys.exit("[castle] WorldKit window not found (or more than one)")
try:
    if wk:
        U32.ShowWindowAsync(wk, 9)
        time.sleep(2.0)
    print("[castle]", luau(c, SIM)[:90], flush=True)
    for k, (_, cam, look) in allshots.items():
        grab(k, cam, look).save(os.path.join(a.out, k + ("" if a.phase == "day" else "_night") + ".png"))
        print("[castle] shot", k, flush=True)
finally:
    print("[castle] restore", luau(c, GUARD + RESTORE)[:80], flush=True)
    if wk:
        U32.ShowWindowAsync(wk, 6)
        print("[castle] WorldKit minimized", flush=True)

try:
    font = ImageFont.truetype("malgun.ttf", 20)
except OSError:
    font = ImageFont.load_default()
CELL = 460
rows = list(allshots.items())
S = Image.new("RGB", (2 * (CELL + 10) + 10, 40 + len(rows) * (CELL + 34)), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((10, 8), "빛 성 C2 골격 — 2D | WorldKit C2c %s (plan = 계획 자리)" % ("낮" if a.phase == "day" else "밤"), fill=(240, 240, 240), font=font)
for r, (k, (src, _, _)) in enumerate(rows):
    y = 40 + r * (CELL + 34)
    d.text((10, y), k, fill=(255, 210, 120), font=font)
    for j, p in enumerate([os.path.join(ROOT, src), os.path.join(a.out, k + ("" if a.phase == "day" else "_night") + ".png")]):
        if os.path.isfile(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((CELL, CELL))
            S.paste(im, (10 + j * (CELL + 10), y + 28))
S.save(os.path.join(a.out, "castle_C2_wk_%s.jpg" % a.phase), quality=88)
print("[castle] ok", a.out, flush=True)
