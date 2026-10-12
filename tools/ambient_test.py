"""Shade-side light test in WorldKit (이미지 생성 3, 10/12; 최종 검수 after tools/latitude_test.py): GeographicLatitude
35 / 65 x OutdoorAmbient now (C2c day) / a warm brighter one, at the same 4 doors (castle, Bakery, Juice, Cliff6).

  STUDIO_NAME=WorldKit py tools/ambient_test.py <out_dir> [--show] [--target 190]

The warm value is found in the slot: OutdoorAmbient = C2c day value x k x warm tint (1.00, 0.96, 0.86 -> cream), k searched
(up to 4 photos of Cliff6, its door is in the shade at both latitudes) until the shade wall median (grey 0..255) is about
--target. Then 16 photos, wall medians measured (shade side and sun side), light restored. --show: ShowWindowAsync(9)
before, (6) after (최종 검수 screen slot, no mouse / keyboard).
Writes <out>/<building>_<lat>_<oa>.png, <out>/ambient_test.jpg (rows = buildings, columns = lat x OA) and <out>/result.json.
"""
import argparse
import ctypes
import json
import os
import statistics
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
PICK = {"Castle": (60, 30, 16), "Shop_Bakery": (22, 8, 6), "Shop_Juice": (22, 8, 6), "House_Cliff6": (22, 8, 6)}
# wall boxes (fractions of the square photo) for the median, picked on latitude_test photos
BOX = {"Castle": (0.30, 0.40, 0.45, 0.60), "Shop_Bakery": (0.05, 0.0, 0.45, 0.12), "Shop_Juice": (0.25, 0.08, 0.45, 0.22),
       "House_Cliff6": (0.15, 0.12, 0.40, 0.30)}
TINT = (1.00, 0.96, 0.86)
SET = GUARD + '''local L = game:GetService("Lighting")
L.GeographicLatitude = %s
if %s then L.OutdoorAmbient = Color3.fromRGB(%d, %d, %d) end
local c = L.OutdoorAmbient
return string.format("%%d,%%d,%%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))'''

ap = argparse.ArgumentParser()
ap.add_argument("out")
ap.add_argument("--show", action="store_true")
ap.add_argument("--target", type=float, default=190)
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)
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
    arg = os.path.join(os.environ.get("TEMP", ""), "oa_cap_arg.json")
    json.dump({"capture_id": "oa_" + tag, "camera_position": cpos, "look_at_position": look}, open(arg, "w"))
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "screen_capture", "@" + arg],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=dict(os.environ), timeout=120)
    if not os.path.exists(CAPF):
        raise RuntimeError("no image for %s: %s" % (tag, (r.stdout + r.stderr)[-300:]))
    im = Image.open(CAPF).copy()
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


def med(im, bid):
    w, h = im.size
    bx = BOX[bid]
    c = im.convert("L").crop((int(bx[0] * w), int(bx[1] * h), int(bx[2] * w), int(bx[3] * h))).resize((40, 40))
    return int(statistics.median(list(c.tobytes())))


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
    sys.exit("[oa] WorldKit window not found (or more than one)")
res = {"cols": [], "cells": {}, "search": []}
try:
    if wk:
        U32.ShowWindowAsync(wk, 9)
        time.sleep(2.5)
    print("[oa]", luau(c, SIM)[:60], flush=True)
    base = [int(v) for v in luau(c, SET % (35, "false", 0, 0, 0)).split(",")]
    print("[oa] C2c day OutdoorAmbient", base, flush=True)
    # search k on Cliff6 at latitude 35 (shade side): secant on the measured median
    pts = []
    k = 1.25
    warm = None
    for it in range(4):
        col = [min(255, round(base[i] * k * TINT[i])) for i in range(3)]
        luau(c, SET % (35, "true", *col))
        time.sleep(0.6)
        m = med(grab("search%d" % it, *cam("House_Cliff6")), "House_Cliff6")
        pts.append((k, m))
        res["search"].append({"k": k, "oa": col, "cliff6_median": m})
        print("[oa] search k %.2f oa %s -> %d" % (k, col, m), flush=True)
        warm = col
        if abs(m - a.target) <= 6:
            break
        if len(pts) >= 2 and pts[-1][1] != pts[-2][1]:
            (k1, m1), (k2, m2) = pts[-2], pts[-1]
            k = k2 + (a.target - m2) * (k2 - k1) / (m2 - m1)
        else:
            k = k * (1.25 if m < a.target else 0.85)
        k = max(0.8, min(2.2, k))
    cols = [(35, None), (35, warm), (65, None), (65, warm)]
    for lat, oa in cols:
        got = luau(c, SET % ((lat, "true", *oa) if oa else (lat, "false", 0, 0, 0)))
        tag = "lat%g_%s" % (lat, "warm" if oa else "now")
        res["cols"].append({"tag": tag, "lat": lat, "oa": got})
        time.sleep(0.6)
        for bid in PICK:
            im = grab("%s_%s" % (bid, tag), *cam(bid))
            im.save(os.path.join(a.out, "%s_%s.png" % (bid, tag)))
            res["cells"]["%s|%s" % (bid, tag)] = med(im, bid)
        print("[oa]", tag, got, {b: res["cells"]["%s|%s" % (b, tag)] for b in PICK}, flush=True)
finally:
    print("[oa] light", luau(c, GUARD + RESTORE)[:60], flush=True)
    if wk:
        U32.ShowWindowAsync(wk, 6)
        print("[oa] WorldKit minimized", flush=True)
json.dump(res, open(os.path.join(a.out, "result.json"), "w"), indent=1)

font = ImageFont.truetype("malgun.ttf", 18)
small = ImageFont.truetype("malgun.ttf", 14)
CELL = 330
S = Image.new("RGB", (150 + 4 * (CELL + 10), 96 + len(PICK) * (CELL + 10)), (24, 24, 28))
d = ImageDraw.Draw(S)
d.text((10, 8), "그늘 빛 시험 (C2c 낮) — 위도 × OutdoorAmbient, 칸 아래 = 벽 밝기 중앙값(0~255)", fill=(240, 240, 240), font=font)
for j, cc in enumerate(res["cols"]):
    x = 150 + j * (CELL + 10)
    d.text((x, 40), "lat %g · OA %s" % (cc["lat"], "지금" if cc["tag"].endswith("now") else "따뜻하게"), fill=(255, 210, 120), font=font)
    d.text((x, 66), "OutdoorAmbient %s" % cc["oa"], fill=(200, 200, 200), font=small)
for i, bid in enumerate(PICK):
    y = 96 + i * (CELL + 10)
    d.text((8, y + 8), bid, fill=(255, 210, 120), font=small)
    for j, cc in enumerate(res["cols"]):
        p = os.path.join(a.out, "%s_%s.png" % (bid, cc["tag"]))
        if os.path.isfile(p):
            im = Image.open(p).convert("RGB")
            im.thumbnail((CELL, CELL))
            S.paste(im, (150 + j * (CELL + 10), y))
            d.text((150 + j * (CELL + 10) + 6, y + CELL - 24), "벽 %d" % res["cells"]["%s|%s" % (bid, cc["tag"])],
                   fill=(255, 255, 255), font=small, stroke_width=2, stroke_fill=(0, 0, 0))
S.save(os.path.join(a.out, "ambient_test.jpg"), quality=88)
print("[oa] ok", a.out, flush=True)
