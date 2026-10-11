"""C2c day / night photos of the 15 houses with their decorations in WorldKit (이미지 생성 3, 10/12; A23-125 step 3 check
asked by 디자인 검수: every house next to its 2D, day 5 and 15 studs, night 15 studs, and the plain-gold 09 dome next to a
Tripo-painted dome).

  STUDIO_ID=<WorldKit window id> py tools/house_deco_shots.py <out_dir> [--only HaloDomeHouse_02,...]

Sets the main Halo-town light (tools/halo_light_sim.luau, C2c day / night), turns the skeleton LampLights on for the night
shots, photographs the SkeletonTest test rows (front row z 60, back row z 115, door side = -Z) with screen_capture, then
restores the light and the lamps. Writes <out>/<house>_{day5,day15,night15}.png, <out>/domes_09_vs_08_day.png and the
sheets <out>/houses_c2c_{a,b,c}.jpg (2D | day 5 | day 15 | night 15). Needs the WorldKit window visible (최종 검수 slot).
"""
import argparse
import base64
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from studio_mcp import Client  # noqa: E402

SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
LAMPS = GUARD + '''local on = %s
local n = 0
for _, d in workspace.SkeletonTest:GetDescendants() do
  if d:IsA("PointLight") and d.Parent and d.Parent:GetAttribute("LampLight") then d.Enabled = on; n += 1 end
end
return "lamps " .. n'''
FRONT = ["01", "02", "03", "04", "05", "06", "08", "09"]
BACK = ["10", "11", "12", "Bakery", "Flower", "Juice", "Potion"]
ROWS = {}
for i, h in enumerate(FRONT):
    ROWS["HaloDomeHouse_" + h] = (2940 + 36 * i, 60)
for i, h in enumerate(BACK):
    ROWS[("HaloDomeHouse_" + h) if h.isdigit() else ("HaloShop_" + h)] = (2940 + 36 * i, 115)

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--only", default="")
ap.add_argument("--front", action="store_true", help="bring the WorldKit window to the front while shooting (screen step)")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
names = [n for n in ROWS if not a.only or n in a.only.split(",")]


def sim(phase):
    return SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "' + phase + '"')


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")


def grab(c, tag, cam, look):
    if os.path.exists(CAPF):
        os.remove(CAPF)
    res = c.call("screen_capture", {"capture_id": "hd_" + tag, "camera_position": cam, "look_at_position": look})
    im = None
    for part in res.get("content", []):
        if part.get("type") == "image":
            im = Image.open(io.BytesIO(base64.b64decode(part["data"])))
    if im is None and os.path.exists(CAPF):         # some Studio builds only write the capture file
        im = Image.open(CAPF).copy()
    if im is None:
        raise RuntimeError("no image for %s: %s" % (tag, str(res)[:300]))
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


# --front (최종 검수 OK only, a screen step): the WorldKit window (title "...WorldKit.rbxlx - Roblox Studio", never the main
# game window) to the front while shooting - a covered Studio window does not draw its viewport - then the old one back
import ctypes  # noqa: E402
U32 = ctypes.windll.user32


def worldkit_hwnd():
    hs = []

    def cb(h, _):
        n = U32.GetWindowTextLengthW(h)
        if n:
            b = ctypes.create_unicode_buffer(n + 1)
            U32.GetWindowTextW(h, b, n + 1)
            t = b.value
            if "WorldKit.rbxlx" in t and "Roblox Studio" in t and "81671223175574" not in t and "GoodEvil" not in t:
                hs.append(h)
        return True
    U32.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(cb), 0)
    return hs[0] if len(hs) == 1 else None


def front_y(n):
    parts = json.load(open(os.path.join(ROOT, "build", "skel_rows", n + ".json")))
    return max(p["pos"][1] for p in parts if p["name"].startswith("front_")) + 0.4


c = Client()
c.start()
prev_fg = None
wk = None
if a.front:
    wk = worldkit_hwnd()
    if not wk:
        sys.exit("[shots] WorldKit window not found (or more than one)")
    prev_fg = U32.GetForegroundWindow()
    was_min = U32.IsIconic(wk)
    U32.ShowWindow(wk, 9 if was_min else 5)
    # above every other window without taking the focus (TOPMOST, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE), and if Windows
    # allows it the real foreground too: attach to the foreground thread's input first (no key presses)
    U32.SetWindowPos(wk, -1, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010)
    k32 = ctypes.windll.kernel32
    ft = U32.GetWindowThreadProcessId(prev_fg, None)
    me = k32.GetCurrentThreadId()
    if ft and ft != me:
        U32.AttachThreadInput(me, ft, True)
        U32.SetForegroundWindow(wk)
        U32.AttachThreadInput(me, ft, False)
    import time
    time.sleep(1.5)
    print("[shots] WorldKit on top", wk, "foreground now", U32.GetForegroundWindow() == wk, flush=True)
try:
    shots = {}
    for phase in ("day", "night"):
        print("[shots]", phase, luau(c, sim(phase))[:80], luau(c, LAMPS % ("true" if phase == "night" else "false")), flush=True)
        for n in names:
            ox, oz = ROWS[n]
            fz = oz - front_y(n)                       # the facade plane (Roblox z), the camera stands at smaller z
            if phase == "day":
                shots[(n, "day5")] = grab(c, n + "_d5", [ox + 1.5, 5.5, fz - 5], [ox, 5.0, fz])
                shots[(n, "day15")] = grab(c, n + "_d15", [ox + 6.0, 10.0, fz - 15], [ox, 8.0, fz])
            else:
                shots[(n, "night15")] = grab(c, n + "_n15", [ox + 6.0, 10.0, fz - 15], [ox, 8.0, fz])
        if phase == "day" and "HaloDomeHouse_09" in names:
            dm = grab(c, "domes", [3174, 32, 60 - 34], [3174, 21, 60])
            dm.save(os.path.join(a.out, "domes_09_vs_08_day.png"))
    for (n, v), im in shots.items():
        im.save(os.path.join(a.out, "%s_%s.png" % (n, v)))
finally:
    print("[shots] restore", luau(c, GUARD + RESTORE)[:80], luau(c, LAMPS % "false"), flush=True)
    if a.front and wk:
        U32.SetWindowPos(wk, -2, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010)     # not topmost any more
        if prev_fg and prev_fg != wk:
            k32 = ctypes.windll.kernel32
            ft = U32.GetWindowThreadProcessId(U32.GetForegroundWindow(), None)
            me = k32.GetCurrentThreadId()
            if ft and ft != me:
                U32.AttachThreadInput(me, ft, True)
            U32.SetForegroundWindow(prev_fg)
            if ft and ft != me:
                U32.AttachThreadInput(me, ft, False)
        print("[shots] WorldKit not topmost, the old front window back:", U32.GetForegroundWindow() == prev_fg, flush=True)

# sheets: 2D | day 5 | day 15 | night 15, five houses a sheet
try:
    font = ImageFont.truetype("malgun.ttf", 18)
except OSError:
    font = ImageFont.load_default()
CELL = 400
groups = [names[i:i + 5] for i in range(0, len(names), 5)]
for gi, grp in enumerate(groups):
    S = Image.new("RGB", (4 * (CELL + 8) + 8, 34 + len(grp) * (CELL + 30)), (24, 24, 28))
    d = ImageDraw.Draw(S)
    d.text((8, 6), "집 장식 Studio C2c — 2D | 낮 5칸 | 낮 15칸 | 밤 15칸", fill=(240, 240, 240), font=font)
    for r, n in enumerate(grp):
        y = 34 + r * (CELL + 30)
        d.text((8, y), n, fill=(255, 210, 120), font=font)
        spec = json.load(open(os.path.join(ROOT, "tools", "house_specs", n + ".json"), encoding="utf-8"))
        cells = [os.path.join(ROOT, spec["src2d"])] + [os.path.join(a.out, "%s_%s.png" % (n, v)) for v in ("day5", "day15", "night15")]
        for k, p in enumerate(cells):
            if os.path.isfile(p):
                im = Image.open(p).convert("RGB")
                im.thumbnail((CELL, CELL))
                S.paste(im, (8 + k * (CELL + 8), y + 24))
    S.save(os.path.join(a.out, "houses_c2c_%s.jpg" % "abc"[gi]), quality=88)
print("[shots] ok", a.out, flush=True)
