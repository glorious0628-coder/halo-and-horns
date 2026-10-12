"""Night light comparison for the Halo town (이미지 개발 2026-10-12, 디자인 검수 request: the C2c night makes the cream marble + gold read like day).
  STUDIO_NAME=WorldKit py tools/night_light_compare.py <out_dir> [--houses HaloDomeHouse_08,HaloShop_Potion] [--dry]
Same camera as tools/house_deco_shots.py (night15). Rows = light variants, columns = lamps off | lamps on (the lamp as built) | lamps on (recommended PointLight):
  V0 now     : C2c night exactly (Exposure +0.50, Ambient (102,106,140), OutdoorAmbient (142,150,195), Brightness 1.4)
  V1 exp+0.2 : Exposure +0.20, Ambient / OutdoorAmbient x0.85
  V2 exp+0.0 : Exposure  0.00, Ambient / OutdoorAmbient x0.85
Recommended lamp light = colour (255,214,160), Brightness 0.5, Range 10 (디자인 검수). Needs the WorldKit window visible (최종 검수 slot); restores the
light (tools/halo_light_restore.luau) and every lamp (colour / brightness / range / enabled as found) at the end. --dry only reads the lamp values.
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from PIL import Image, ImageDraw  # noqa: E402
from studio_mcp import Client  # noqa: E402

SIM = open(os.path.join(ROOT, "tools", "halo_light_sim.luau"), encoding="utf-8").read()
RESTORE = open(os.path.join(ROOT, "tools", "halo_light_restore.luau"), encoding="utf-8").read()
GUARD = 'if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end\n'
FRONT = ["01", "02", "03", "04", "05", "06", "08", "09"]
BACK = ["10", "11", "12", "Bakery", "Flower", "Juice", "Potion"]
ROWS = {}
for i, h in enumerate(FRONT):
    ROWS["HaloDomeHouse_" + h] = (2940 + 36 * i, 60)
for i, h in enumerate(BACK):
    ROWS[("HaloDomeHouse_" + h) if h.isdigit() else ("HaloShop_" + h)] = (2940 + 36 * i, 115)

LAMP_READ = GUARD + """local out = {}
for _, d in workspace.SkeletonTest:GetDescendants() do
	if d:IsA("PointLight") and d.Parent and d.Parent:GetAttribute("LampLight") then
		if d:GetAttribute("OrigSaved") == nil then
			d:SetAttribute("OrigSaved", string.format("%d,%d,%d|%.3f|%.2f|%s", math.round(d.Color.R * 255), math.round(d.Color.G * 255), math.round(d.Color.B * 255), d.Brightness, d.Range, tostring(d.Enabled)))
		end
		table.insert(out, d:GetAttribute("OrigSaved"))
	end
end
return #out .. " lamps; first: " .. tostring(out[1])"""
LAMP_SET = GUARD + """local mode = "__MODE__"
local n = 0
for _, d in workspace.SkeletonTest:GetDescendants() do
	if d:IsA("PointLight") and d.Parent and d.Parent:GetAttribute("LampLight") then
		local o = d:GetAttribute("OrigSaved")
		if o then
			local r, g, b, br, rg = string.match(o, "(%d+),(%d+),(%d+)|([%d%.]+)|([%d%.]+)|")
			if mode == "rec" then
				d.Color = Color3.fromRGB(255, 214, 160)
				d.Brightness = 0.5
				d.Range = 10
				d.Enabled = true
			elseif mode == "cur" then
				d.Color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
				d.Brightness = tonumber(br)
				d.Range = tonumber(rg)
				d.Enabled = true
			else
				d.Enabled = false
			end
			n += 1
		end
	end
end
return mode .. " " .. n"""
LAMP_RESTORE = GUARD + """local n = 0
for _, d in workspace.SkeletonTest:GetDescendants() do
	if d:IsA("PointLight") and d:GetAttribute("OrigSaved") then
		local o = d:GetAttribute("OrigSaved")
		local r, g, b, br, rg, en = string.match(o, "(%d+),(%d+),(%d+)|([%d%.]+)|([%d%.]+)|(%a+)")
		d.Color = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
		d.Brightness = tonumber(br)
		d.Range = tonumber(rg)
		d.Enabled = (en == "true")
		d:SetAttribute("OrigSaved", nil)
		n += 1
	end
end
return "lamps restored " .. n"""
VARS = [("now", 0.5, 1.0), ("exp+0.2 x0.85", 0.2, 0.85), ("exp+0.0 x0.85", 0.0, 0.85)]
SETLIGHT = GUARD + """local L = game:GetService("Lighting")
local f = __F__
L.ExposureCompensation = __E__
local s = L:GetAttribute("NightBase")
if not s then
	L:SetAttribute("NightBase", string.format("%f,%f,%f|%f,%f,%f", L.Ambient.R, L.Ambient.G, L.Ambient.B, L.OutdoorAmbient.R, L.OutdoorAmbient.G, L.OutdoorAmbient.B))
	s = L:GetAttribute("NightBase")
end
local a1, a2, a3, o1, o2, o3 = string.match(s, "([%d%.]+),([%d%.]+),([%d%.]+)|([%d%.]+),([%d%.]+),([%d%.]+)")
L.Ambient = Color3.new(tonumber(a1) * f, tonumber(a2) * f, tonumber(a3) * f)
L.OutdoorAmbient = Color3.new(tonumber(o1) * f, tonumber(o2) * f, tonumber(o3) * f)
return string.format("exp %.2f amb x%.2f -> %s", L.ExposureCompensation, f, tostring(L.Ambient))"""
CAPF = os.path.join(os.environ.get("TEMP", ""), "studio_capture_0.jpeg")


def luau(c, code):
    r = c.call("execute_luau", {"code": code, "datamodel_type": "Edit"})
    return "".join(p.get("text", "") for p in r.get("content", []) if p.get("type") == "text")


def grab(tag, cam, look):
    if os.path.exists(CAPF):
        os.remove(CAPF)
    arg = os.path.join(os.environ.get("TEMP", ""), "nl_cap_arg.json")
    json.dump({"capture_id": "nl_" + tag, "camera_position": cam, "look_at_position": look}, open(arg, "w"))
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "screen_capture", "@" + arg],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", env=dict(os.environ), timeout=120)
    if not os.path.exists(CAPF):
        raise RuntimeError("no image for %s: %s" % (tag, (r.stdout + r.stderr)[-300:]))
    im = Image.open(CAPF).copy()
    w, h = im.size
    s = min(w, h)
    return im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


def front_y(n):
    parts = json.load(open(os.path.join(ROOT, "build", "skel_rows", n + ".json")))
    return max(p["pos"][1] for p in parts if p["name"].startswith("front_")) + 0.4


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--houses", default="HaloDomeHouse_08,HaloShop_Potion")
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    c = Client()
    c.start()
    try:
        print("[lamps]", luau(c, LAMP_READ))
        if a.dry:
            return
        print("[light]", luau(c, SIM.replace('local CAND, PHASE = "%s", "%s"', 'local CAND, PHASE = "C2c", "night"'))[:90])
        for hn in a.houses.split(","):
            ox, oz = ROWS[hn]
            fz = oz - front_y(hn)
            cam, look = [ox + 6.0, 10.0, fz - 15], [ox, 8.0, fz]
            cells = {}
            for vi, (vn, exp, f) in enumerate(VARS):
                print("[light]", vn, luau(c, SETLIGHT.replace("__F__", repr(f)).replace("__E__", repr(exp))))
                for mode in ("off", "cur", "rec"):
                    luau(c, LAMP_SET.replace("__MODE__", mode))
                    cells[(vi, mode)] = grab("%s_%d_%s" % (hn, vi, mode), cam, look)
            S = cells[(0, "off")].width // 2
            sh = Image.new("RGB", (S * 3, (S + 14) * 3 + 14), (20, 20, 20))
            d = ImageDraw.Draw(sh)
            d.text((4, 1), "%s night | off | lamps on (as built) | lamps on (255,214,160 / 0.5 / 10)" % hn, fill=(255, 255, 255))
            for vi, (vn, exp, f) in enumerate(VARS):
                for mi, mode in enumerate(("off", "cur", "rec")):
                    y = 14 + vi * (S + 14)
                    sh.paste(cells[(vi, mode)].resize((S, S)), (mi * S, y + 14))
                    cells[(vi, mode)].save(os.path.join(a.out, "%s_v%d_%s.png" % (hn, vi, mode)))
                    if mi == 0:
                        d.text((4, y + 1), vn, fill=(255, 255, 0))
            sh.save(os.path.join(a.out, "night_compare_%s.jpg" % hn), quality=90)
    finally:
        if not a.dry:
            print("[restore]", luau(c, GUARD + RESTORE)[:80])
            print("[restore]", luau(c, GUARD + 'game:GetService("Lighting"):SetAttribute("NightBase", nil) return 1'))
        print("[restore]", luau(c, LAMP_RESTORE))
        c.close()


if __name__ == "__main__":
    main()
