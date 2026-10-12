"""halo_newhouse_boxes.py (이미지 생성 1, 2026-10-12, 최종 검수 5단계): the grey boxes of the 7 new homes (Hill4, Cliff6-8,
Garden5-7) rebuilt at their plan skeleton body (docs/design/halo_plan_v2_2026-10-11.json buildings[].skeleton: PROVISIONAL sizes of
이미지 생성 3's house families, tools/halo_plan_v2.py SKELETONS) - door face on the plan door_at, body W x D, BOX_H high, upper floor
slab tagged WalkGround. Replaces Workspace.HaloV2.Buildings.<id> in WorldKit (Edit mode, no window).
usage: STUDIO_ID=<WorldKit id> py tools/worldkit/halo_newhouse_boxes.py [--dry]"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLAN = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
IDS = ["House_Hill4", "House_Cliff6", "House_Cliff7", "House_Cliff8", "House_Garden5", "House_Garden6", "House_Garden7"]
BOX_H = 20  # 이미지 생성 3's two-storey skeletons stand 18..21 high

rows = []
for b in PLAN["buildings"]:
    if b["id"] in IDS:
        sk = b.get("skeleton")
        if not sk:
            raise SystemExit("%s has no skeleton in the plan: run py tools/halo_plan_v2.py" % b["id"])
        rows.append('{id="%s",x=%g,z=%g,y=%g,yaw=%g,w=%g,d=%g,side=%g,dw=%g,dh=%g,floors=%d,fh=%g,kind="%s",house="%s"}' % (
            b["id"], sk["origin"][0], sk["origin"][1], b["ground_y"], b["yaw"], sk["body_w"], sk["body_d"], sk["door_side"],
            b["door_size"][0], b["door_size"][1], b["floors"], b["floor_h"], b["kind"], sk["house"]))
if len(rows) != len(IDS):
    raise SystemExit("plan has %d of the %d new homes" % (len(rows), len(IDS)))

LUAU = r'''
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
if game:GetService("RunService"):IsRunning() then error("Edit mode only") end
local CS = game:GetService("CollectionService")
local bf = workspace.HaloV2.Buildings
local B = { __ROWS__ }
local H = __H__
local out = {}
local function part(m, name, size, cf, col)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Size, p.CFrame, p.Color = name, true, size, cf, col
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end
for _, b in B do
	local old = bf:FindFirstChild(b.id)
	local col = Color3.fromRGB(200, 200, 200)
	local attrs = {}
	if old then
		local p = old:FindFirstChildWhichIsA("BasePart", true)
		if p then col = p.Color end
		attrs = old:GetAttributes()
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = b.id
	for k, v in attrs do m:SetAttribute(k, v) end
	m:SetAttribute("Provisional", "body " .. b.w .. "x" .. b.d .. " (" .. b.house .. "): replace with 이미지 생성 3's skeleton")
	local yaw = math.rad(b.yaw)
	-- local -Z = the door side (as tools/worldkit/halo_blockout.luau); local +X = left seen from the front
	local base = CFrame.new(b.x, b.y, b.z) * CFrame.Angles(0, yaw + math.pi, 0)
	local w, d, th, dw, dh = b.w, b.d, 1, b.dw, b.dh
	local dx = -b.side
	part(m, "WallBack", Vector3.new(w, H, th), base * CFrame.new(0, H / 2, d / 2 - th / 2), col)
	part(m, "WallL", Vector3.new(th, H, d), base * CFrame.new(-w / 2 + th / 2, H / 2, 0), col)
	part(m, "WallR", Vector3.new(th, H, d), base * CFrame.new(w / 2 - th / 2, H / 2, 0), col)
	local l = (w / 2 + dx) - dw / 2
	local r = (w / 2 - dx) - dw / 2
	part(m, "FrontL", Vector3.new(l, H, th), base * CFrame.new(-w / 2 + l / 2, H / 2, -d / 2 + th / 2), col)
	part(m, "FrontR", Vector3.new(r, H, th), base * CFrame.new(w / 2 - r / 2, H / 2, -d / 2 + th / 2), col)
	part(m, "FrontTop", Vector3.new(dw, H - dh, th), base * CFrame.new(dx, dh + (H - dh) / 2, -d / 2 + th / 2), col)
	local door = part(m, "DoorHole", Vector3.new(dw, dh, 0.2), base * CFrame.new(dx, dh / 2, -d / 2 - 0.2), Color3.fromRGB(200, 40, 40))
	door.Transparency, door.CanCollide = 0.7, false
	for f = 1, b.floors - 1 do
		local y = f * b.fh
		local s1 = part(m, "Floor" .. f .. "a", Vector3.new(w - 2, 0.6, d - 7), base * CFrame.new(0, y, -3.5), col:Lerp(Color3.new(1, 1, 1), 0.2))
		local s2 = part(m, "Floor" .. f .. "b", Vector3.new(w - 7, 0.6, 5), base * CFrame.new(2.5, y, d / 2 - 3.5), col:Lerp(Color3.new(1, 1, 1), 0.2))
		CS:AddTag(s1, "WalkGround")
		CS:AddTag(s2, "WalkGround")
	end
	part(m, "Roof", Vector3.new(w, 0.6, d), base * CFrame.new(0, H - 0.3, 0), col:Lerp(Color3.new(0, 0, 0), 0.1))
	m.PrimaryPart = m:FindFirstChild("WallBack")
	m.Parent = bf
	table.insert(out, string.format("%s %gx%g at %.1f,%.1f", b.id, w, d, b.x, b.z))
end
return "new home boxes: " .. table.concat(out, " | ")
'''
src = LUAU.replace("__ROWS__", ",\n".join(rows)).replace("__H__", str(BOX_H))
if "--dry" in sys.argv:
    print(src)
    sys.exit(0)
jp = os.path.join(os.environ["TEMP"], "halo_newhouse_boxes.json")
json.dump({"code": src, "datamodel_type": "Edit"}, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "studio_mcp.py"), "call", "execute_luau", "@" + jp],
                   env=dict(os.environ, STUDIO_NAME=os.environ.get("STUDIO_NAME", "WorldKit")), capture_output=True, text=True,
                   encoding="utf-8", cwd=ROOT)
print(r.stdout.strip()[-1500:] or r.stderr.strip()[-800:])
