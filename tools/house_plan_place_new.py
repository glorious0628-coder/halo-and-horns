"""Put the 7 new Halo houses' skeletons (SkeletonTest row 3, z 170) on their plan v2 spots in WorldKit (이미지 생성 3, 10/12).

  py tools/house_plan_place_new.py -> build/house_plan_place_new.json, then
  STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @build/house_plan_place_new.json

Like tools/house_plan_place.py (clone into Workspace.HaloV2.Buildings.<plan id>, gray box -> ServerStorage.HaloV2_GrayBoxes,
PivotTo(ground_y, yaw + 180)), but the plan's skeleton origin was made for a 20 x 12.4 'newB' body: the model is placed at
door_at - door_dir x D/2 and then slid in XZ so its DoorFront (5 studs out of the door) lands on door_at + door_dir x 5 (any
off-centre door included). Prints the door error after the slide (should be ~0).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
plan = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
ROW = {"Cliff6": 3000, "Garden6": 3036, "Garden7": 3072, "Hill4": 3108, "Cliff7": 3144, "Garden5": 3180, "Cliff8": 3216}
rows = []
for b in plan["buildings"]:
    h = b["id"].replace("House_", "")
    if h not in ROW:
        continue
    spec = json.load(open(os.path.join(ROOT, "tools", "house_specs", "HaloNewHouse_%s.json" % h), encoding="utf-8"))
    D = spec["plan"]["D"]
    (dax, daz), (dx, dz) = b["door_at"], b["door_dir"]
    rows.append('{id="%s", src="HaloNewHouse_%s_Skeleton", ox=%g, x=%g, y=%g, z=%g, yaw=%g, ex=%g, ez=%g}' % (
        b["id"], h, ROW[h], dax - dx * D / 2, b["ground_y"], daz - dz * D / 2, b["yaw"], dax + dx * 5, daz + dz * 5))
code = '''if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local ST = workspace.SkeletonTest
local B = workspace.HaloV2.Buildings
local SS = game:GetService("ServerStorage")
local hold = SS:FindFirstChild("HaloV2_GrayBoxes") or Instance.new("Folder")
hold.Name = "HaloV2_GrayBoxes"; hold.Parent = SS
local L = {%s}
local out = {}
for _, r in L do
  local box = B:FindFirstChild(r.id)
  if box and not box:GetAttribute("HouseSkeleton") then box.Parent = hold end
  local old = B:FindFirstChild(r.id)
  if old and old:GetAttribute("HouseSkeleton") then old:Destroy() end
  local s = ST:FindFirstChild(r.src)
  if not s then table.insert(out, r.id .. " MISSING " .. r.src) continue end
  local m = Instance.new("Model"); m.Name = r.id
  s:Clone().Parent = m
  m:SetAttribute("HouseSkeleton", r.src); m:SetAttribute("PlanYaw", r.yaw)
  m.WorldPivot = CFrame.new(r.ox, 0, 170)
  m.Parent = B
  m:PivotTo(CFrame.new(r.x, r.y, r.z) * CFrame.Angles(0, math.rad(r.yaw + 180), 0))
  local df = nil
  for _, d in m:GetDescendants() do if d:IsA("Attachment") and d.Name == "DoorFront" then df = d end end
  if df then
    local p = df.WorldPosition
    m:PivotTo(m:GetPivot() + Vector3.new(r.ex - p.X, 0, r.ez - p.Z))
    p = df.WorldPosition
    table.insert(out, string.format("%%s door err %%.3f y %%.1f", r.id, math.sqrt((p.X - r.ex)^2 + (p.Z - r.ez)^2), p.Y))
  else
    table.insert(out, r.id .. " placed (no DoorFront)")
  end
end
return table.concat(out, " | ")''' % ",\n".join(rows)
json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "house_plan_place_new.json"), "w", encoding="utf-8"))
print(len(rows), "buildings")
