"""Top-down map tiles for the real-world minimap (검수 A23-95, 2026-10-09; 메인 반영 owns the main Edit).

  py tools/minimap_capture.py trial [--set NAME]                 4 trial tiles (crossroads, meadow arrival, woods camp, pond)
  py tools/minimap_capture.py grid --x0 -300 --x1 1400 --z0 -500 --z1 500 [--set NAME] [--tile 160] [--overlap 12]
  py tools/minimap_capture.py at X Z [X Z ...] [--set NAME]      the tiles centred on these world points

Edit mode only, MCP only (no clicks, no Play, no window handling): the Studio Edit camera is put straight down very high
with a narrow field of view (default 15 degrees, nearly flat), one capture per tile, the centre square of the viewport is
cropped. For the shot, Lighting is fixed to day (ClockTime 14.2, fog off, Atmosphere / Clouds / bloom / depth of field /
sun rays / colour correction off) and the selection is cleared; every value is saved first and put back at the end (also
after an error). Edit has no players, monsters or game UI.

Output art/minimap/<set>/tile_<col>_<row>.png (square, native pixels) + tiles.json:
  { "tileStuds", "overlapStuds", "strideStuds", "fovDeg", "camHeight", "px", "axes": "image right = +X (east), image up = -Z (north)",
    "tiles": [ { "id", "col", "row", "cx", "cz", "x0", "x1", "z0", "z1", "file" } ] }
The tile covers x0..x1, z0..z1 of the ground plane Y 0 (terrain that is higher shows slightly larger: 30 studs high = about 4%
at the default height, the overlap covers it). World -> pixel inside a tile: u = (x - x0) / tileStuds * px, v = (z - z0) / tileStuds * px.
"""

import base64
import io
import json
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SETUP = r'''
local HttpService = game:GetService("HttpService")
local L = game:GetService("Lighting")
local cam = workspace.CurrentCamera
local prev = { ClockTime = L.ClockTime, FogEnd = L.FogEnd, FogStart = L.FogStart, Brightness = L.Brightness,
	FOV = cam.FieldOfView, CF = { cam.CFrame:GetComponents() }, Fx = {} }
for _, e in L:GetChildren() do
	if e:IsA("PostEffect") or e:IsA("SunRaysEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
		prev.Fx[e.Name] = e.Enabled
		e.Enabled = false
	elseif e:IsA("Atmosphere") then
		prev.Atm = { e.Density, e.Haze }
		e.Density, e.Haze = 0, 0
	end
end
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
if clouds then prev.Clouds = clouds.Enabled clouds.Enabled = false end
L.ClockTime, L.FogEnd, L.FogStart = 14.2, 1e6, 1e6 - 1
workspace:SetAttribute("MinimapCapPrev", HttpService:JSONEncode(prev))
pcall(function() game:GetService("Selection"):Set({}) end)
-- sky objects (the broken crown over the Crossroads, bottom Y 285) would cover the ground from straight above: hidden
-- while shooting (bottom higher than SKY_Y), Transparency kept in an attribute
local hid = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d ~= workspace.Terrain and d.Transparency < 1 and d.Position.Y - d.Size.Y / 2 > %f then
		d:SetAttribute("MapCapT", d.Transparency)
		d.Transparency = 1
		hid += 1
	end
end
cam.FieldOfView = %f
return "setup ok, hid " .. hid .. " sky parts"
'''
RESTORE = r'''
local HttpService = game:GetService("HttpService")
local raw = workspace:GetAttribute("MinimapCapPrev")
if not raw then return "nothing to restore" end
local prev = HttpService:JSONDecode(raw)
local L = game:GetService("Lighting")
local cam = workspace.CurrentCamera
L.ClockTime, L.FogEnd, L.FogStart, L.Brightness = prev.ClockTime, prev.FogEnd, prev.FogStart, prev.Brightness
for _, e in L:GetChildren() do
	if prev.Fx[e.Name] ~= nil then e.Enabled = prev.Fx[e.Name] end
	if e:IsA("Atmosphere") and prev.Atm then e.Density, e.Haze = prev.Atm[1], prev.Atm[2] end
end
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
if clouds and prev.Clouds ~= nil then clouds.Enabled = prev.Clouds end
for _, d in workspace:GetDescendants() do
	local t = d:GetAttribute("MapCapT")
	if t ~= nil and d:IsA("BasePart") then d.Transparency = t d:SetAttribute("MapCapT", nil) end
end
cam.FieldOfView = prev.FOV
cam.CFrame = CFrame.new(table.unpack(prev.CF))
workspace:SetAttribute("MinimapCapPrev", nil)
return "restored"
'''
CAM = r'''
local cam = workspace.CurrentCamera
local p = Vector3.new(%f, %f, %f)
cam.CFrame = CFrame.fromMatrix(p, Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
cam.Focus = CFrame.new(p.X, 0, p.Z) -- the Studio edit camera orbits its Focus
return "cam"
'''

TRIAL = [("crossroads", 0, 0), ("meadow_arrival", 260, 0), ("woods_camp", 840, 106), ("pond", 290, 150)]


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def arg(name, default=None, cast=float):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv):
            return cast(sys.argv[i + 1])
    return default


def capture(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            return Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB")
    return None


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    mode = sys.argv[1]
    tile = arg("--tile", 160.0)
    overlap = arg("--overlap", 12.0)
    fov = arg("--fov", 15.0)
    sky_y = arg("--sky", 150.0)  # parts whose bottom is higher than this are hidden for the shot
    name = arg("--set", "trial" if mode == "trial" else "grid", cast=str)
    stride = tile - overlap
    cam_h = (tile / 2) / math.tan(math.radians(fov / 2))
    centres = []
    if mode == "trial":
        centres = [(n, x, z) for n, x, z in TRIAL]
    elif mode == "at":
        nums = [float(a) for a in sys.argv[2:] if not a.startswith("--") and a.replace("-", "").replace(".", "").isdigit()]
        centres = [(f"p{i}", nums[2 * i], nums[2 * i + 1]) for i in range(len(nums) // 2)]
    elif mode == "grid":
        x0, x1, z0, z1 = arg("--x0"), arg("--x1"), arg("--z0"), arg("--z1")
        if None in (x0, x1, z0, z1):
            sys.exit("grid needs --x0 --x1 --z0 --z1")
        cols = int(math.ceil((x1 - x0) / stride))
        rows = int(math.ceil((z1 - z0) / stride))
        for r in range(rows):
            for k in range(cols):
                centres.append((f"{k}_{r}", x0 + tile / 2 + k * stride, z0 + tile / 2 + r * stride))
    else:
        sys.exit(__doc__)
    out_dir = os.path.join(ROOT, "art", "minimap", name)
    os.makedirs(out_dir, exist_ok=True)
    c = Client()
    c.start()
    meta = {"tileStuds": tile, "overlapStuds": overlap, "strideStuds": stride, "fovDeg": fov, "camHeight": cam_h,
            "axes": "image right = +X (east), image up = -Z (north)", "tiles": []}
    try:
        state = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in state:
            sys.exit("not in Edit: " + state)
        print(text_of(c.call("execute_luau", {"code": SETUP % (sky_y, fov), "datamodel_type": "Edit"})))
        for i, (tid, cx, cz) in enumerate(centres):
            c.call("execute_luau", {"code": CAM % (cx, cam_h, cz), "datamodel_type": "Edit"})
            time.sleep(1.8)
            img = capture(c, f"minimap_{name}_{tid}")
            if img is None:
                print("capture failed", tid)
                continue
            w, h = img.size
            side = min(w, h)
            left = (w - side) // 2
            sq = img.crop((left, (h - side) // 2, left + side, (h - side) // 2 + side))
            fn = f"tile_{tid}.png"
            sq.save(os.path.join(out_dir, fn))
            meta["px"] = side
            meta["tiles"].append({"id": tid, "cx": cx, "cz": cz, "x0": cx - tile / 2, "x1": cx + tile / 2,
                                  "z0": cz - tile / 2, "z1": cz + tile / 2, "file": fn})
            print(f"[{i + 1}/{len(centres)}] {fn} centre ({cx:.0f},{cz:.0f}) {side}px")
    finally:
        try:
            print(text_of(c.call("execute_luau", {"code": RESTORE, "datamodel_type": "Edit"})))
        except Exception as e:  # noqa: BLE001
            print("restore failed:", e)
        with open(os.path.join(out_dir, "tiles.json"), "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=1)
        c.close()
    print("saved", out_dir)


if __name__ == "__main__":
    main()
