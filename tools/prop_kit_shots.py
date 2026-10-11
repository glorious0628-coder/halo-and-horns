"""Studio photos of the tools/prop_kit.py kits in WorldKit (이미지 생성 4, 10/11): one clone of each kit on a floating
floor (Workspace.PropKitShowcase, 300 studs up, away from HaloV2), main Halo-town light (tools/halo_light_sim.luau C2c
day / night, restored at the end by tools/halo_light_restore.luau), screen_capture from fixed angles.

  STUDIO_NAME=WorldKit py tools/prop_kit_shots.py <out_dir> [Kit ...] [--views front,q34,back] [--night] [--keep]

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
local names = %s
local kits = game:GetService("ServerStorage"):FindFirstChild("HaloPropKits")
if not kits then return "no HaloPropKits" end
local old = workspace:FindFirstChild("PropKitShowcase"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "PropKitShowcase"; root.Parent = workspace
local Y, X0, Z0 = 300, 4000, 0
local out, x = {}, X0
for _, n in names do
	local k = kits:FindFirstChild(n)
	if k then
		local m = k:Clone()
		local _, s = m:GetBoundingBox()
		local w = math.max(s.X, s.Z)
		x += w / 2 + 3
		m:PivotTo(CFrame.new(x, Y, Z0))
		m.Parent = root
		local cf, sz = m:GetBoundingBox()
		table.insert(out, string.format('"%%s":[%%.2f,%%.2f,%%.2f,%%.2f,%%.2f,%%.2f]', n, cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z))
		x += w / 2 + 3
	end
end
local floor = Instance.new("Part"); floor.Name = "Floor"; floor.Anchored = true
floor.Size = Vector3.new(x - X0 + 20, 1, 40); floor.CFrame = CFrame.new((X0 + x) / 2, Y - 0.5, Z0)
floor.Material = Enum.Material.Concrete; floor.Color = Color3.fromRGB(200, 196, 186); floor.Parent = root
return "{" .. table.concat(out, ",") .. "}"
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("kits", nargs="*")
    ap.add_argument("--views", default="front,q34,back")
    ap.add_argument("--night", action="store_true")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    names = a.kits or sorted(os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "build", "prop_kit"))
                             if f.endswith(".json") and not f.startswith("_"))
    c = Client()
    c.start()
    txt = luau(c, BUILD % ("{" + ", ".join('"%s"' % n for n in names) + "}"))
    boxes = json.loads(txt[txt.index("{"):txt.rindex("}") + 1])
    try:
        luau(c, sim("day"))
        for n, (cx, cy, cz, sx, sy, sz) in boxes.items():
            size = max(sx, sy, sz)
            dist = size * 1.9 + 3
            look = [cx, cy, cz]
            for v in a.views.split(","):
                az, el = VIEWS[v]
                # the kit looks along -Z (its LookVector): "front" camera sits at -Z
                d = (-math.sin(math.radians(az)), math.sin(math.radians(el)), -math.cos(math.radians(az)))
                cam = [cx + d[0] * dist * math.cos(math.radians(el)), cy + d[1] * dist, cz + d[2] * dist * math.cos(math.radians(el))]
                square(grab(c, "%s_%s" % (n, v), cam, look)).save(os.path.join(a.out, "%s_%s.png" % (n, v)))
            print("[shots] day", n)
        if a.night:
            luau(c, sim("night"))
            luau(c, LIGHTS % "true")
            for n, (cx, cy, cz, sx, sy, sz) in boxes.items():
                if "Lantern" not in n and "Lamp" not in n:
                    continue
                size = max(sx, sy, sz)
                dist = size * 1.9 + 3
                d = (-math.sin(math.radians(35)), math.sin(math.radians(14)), -math.cos(math.radians(35)))
                cam = [cx + d[0] * dist, cy + d[1] * dist, cz + d[2] * dist]
                square(grab(c, n + "_night", cam, [cx, cy, cz])).save(os.path.join(a.out, "%s_night.png" % n))
                print("[shots] night", n)
            luau(c, LIGHTS % "false")
    finally:
        print(luau(c, RESTORE)[:200])
        if not a.keep:
            luau(c, GUARD + 'local r = workspace:FindFirstChild("PropKitShowcase"); if r then r:Destroy() end; return "removed"')


if __name__ == "__main__":
    main()
