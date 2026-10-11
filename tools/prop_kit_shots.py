"""Studio photos of the tools/prop_kit.py kits in WorldKit (이미지 생성 4, 10/11-12): one kit at a time on real town
ground (cobble + grass by the spawn, --spot; 디자인 검수 10/12: no more floating marble floor - it made the props look flat),
turned 25 deg so the C2c day sun rakes the front, main Halo-town light (tools/halo_light_sim.luau C2c day / night, restored
at the end by tools/halo_light_restore.luau), screen_capture from fixed angles round the kit's own front.

  STUDIO_NAME=WorldKit py tools/prop_kit_shots.py <out_dir> [Kit ...] [--views front,q34,back] [--night] [--keep]
          [--spot -24,0.2,-440]

Needs the WorldKit window visible (not minimized) - ask 검수 for the screen slot first (AGENTS.md rule 6).
Saves <out_dir>/<Kit>_<view>.png (square crop round the kit) and, with --night, <Kit>_night.png for kits with lamp glass.
"""
import argparse
import base64
import io
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image  # noqa: E402
from studio_mcp import Client  # noqa: E402

SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
BUILD = GUARD + r'''
local n, SX, SY, SZ = "%s", %s, %s, %s
local kits = game:GetService("ServerStorage"):FindFirstChild("HaloPropKits")
if not kits then return "no HaloPropKits" end
local old = workspace:FindFirstChild("PropKitShowcase"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "PropKitShowcase"; root.Parent = workspace
local k = kits:FindFirstChild(n)
if not k then return "no kit " .. n end
local m = k:Clone()
local pivot = CFrame.new(SX, SY, SZ) * CFrame.Angles(0, math.rad(25), 0)
m:PivotTo(pivot)
m.Parent = root
local cf, sz = m:GetBoundingBox()
return string.format('{"c":[%%.2f,%%.2f,%%.2f],"s":[%%.2f,%%.2f,%%.2f],"look":[%%.4f,%%.4f]}', cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z,
	pivot.LookVector.X, pivot.LookVector.Z)
'''
LIGHTS = GUARD + r'''
local on = %s
local root = workspace:FindFirstChild("PropKitShowcase")
local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("PointLight") and d.Name == "LampLight" then d.Enabled = on; n += 1 end
end
return n
'''
VIEWS = {"front": (0, 12), "q34": (35, 16), "back": (180, 12), "left": (90, 10), "right": (270, 10)}


def sim(phase):
    return SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "' + phase + '"')


def grab(c, name, cam, look):
    res = c.call("screen_capture", {"capture_id": "pk_" + name, "camera_position": cam, "look_at_position": look})
    for part in res.get("content", []):
        if part.get("type") == "image":
            return Image.open(io.BytesIO(base64.b64decode(part["data"])))
    raise RuntimeError("no image for %s: %s" % (name, str(res)[:300]))


def square(im):
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def cam_for(box, view, dist):
    """Camera round the kit's own front: az from the front towards the kit's left (-RightVector), el above."""
    cx, cy, cz = box["c"]
    lx, lz = box["look"]
    rx, rz = -lz, lx
    az, el = (math.radians(v) for v in VIEWS[view])
    dx = lx * math.cos(az) - rx * math.sin(az)
    dz = lz * math.cos(az) - rz * math.sin(az)
    return [cx + dx * dist * math.cos(el), cy + dist * math.sin(el), cz + dz * dist * math.cos(el)], [cx, cy, cz]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("kits", nargs="*")
    ap.add_argument("--views", default="front,q34,back")
    ap.add_argument("--night", action="store_true")
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--spot", default="-24,0.2,-440")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    names = a.kits or sorted(os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "build", "prop_kit"))
                             if f.endswith(".json") and not f.startswith("_"))
    sx, sy, sz = a.spot.split(",")
    c = Client()
    c.start()

    def place(n):
        txt = luau(c, BUILD % (n, sx, sy, sz))
        return json.loads(txt[txt.index("{"):txt.rindex("}") + 1])

    try:
        for phase in (("day", "night") if a.night else ("day",)):
            luau(c, sim(phase))
            for n in names:
                lamp = "Lantern" in n or "Lamp" in n
                if phase == "night" and not lamp:
                    continue
                box = place(n)
                luau(c, LIGHTS % ("true" if phase == "night" else "false"))
                dist = max(box["s"]) * 1.05 + 1.5
                views = ["q34"] if phase == "night" else a.views.split(",")
                grab(c, n + "_warm", *cam_for(box, views[0], dist))          # first frame after a move can be stale
                for v in views:
                    tag = "%s_%s" % (n, "night" if phase == "night" else v)
                    square(grab(c, tag, *cam_for(box, v, dist))).save(os.path.join(a.out, tag + ".png"))
                print("[shots]", phase, n, flush=True)
    finally:
        print(luau(c, RESTORE)[:200])
        if not a.keep:
            luau(c, GUARD + 'local r = workspace:FindFirstChild("PropKitShowcase"); if r then r:Destroy() end; return "removed"')


if __name__ == "__main__":
    main()
