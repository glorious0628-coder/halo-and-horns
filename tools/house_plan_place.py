"""Put the house / shop skeletons on their plan v2 spots in WorldKit (이미지 생성 3, 10/11; plan skeleton fields by 이미지 생성 1).

  py tools/house_plan_place.py            -> build/house_plan_place.json, then
  STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @build/house_plan_place.json

Clones Workspace.SkeletonTest.<house>_Skeleton (test rows: front z 60 x 2940 + 36 i = 01 02 03 04 05 06 08 09, back z 115 =
10 11 12 Bakery Flower Juice Potion; house 07 = House07_Skeleton + House07_Fixed, body centre (-0.25, -0.125) off its origin)
into Workspace.HaloV2.Buildings.<plan id> and PivotTo(plan skeleton.origin, ground_y, yaw + 180 deg: the skeletons' doors
face -Z). The gray blockout of that id goes to ServerStorage.HaloV2_GrayBoxes (kept). Prints the door check: DoorFront -
door_dir x 5 vs door_at (house 07's DoorFront is 3.4 out, so it shows ~1.6). Back up afterwards:
  py tools/worldkit/wk_backup.py save --only Workspace.HaloV2,ServerStorage.HaloV2_GrayBoxes --no-terrain
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
plan = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
FRONT = ["01", "02", "03", "04", "05", "06", "08", "09"]
BACK = ["10", "11", "12", "Bakery", "Flower", "Juice", "Potion"]
SRC = {}
for i, h in enumerate(FRONT):
    SRC[h] = (["HaloDomeHouse_%s_Skeleton" % h], (2940 + 36 * i, 0, 60))
for i, h in enumerate(BACK):
    nm = ("HaloDomeHouse_%s" % h) if h.isdigit() else ("HaloShop_%s" % h)
    SRC[h] = ([nm + "_Skeleton"], (2940 + 36 * i, 0, 115))
SRC["07"] = (["House07_Skeleton", "House07_Fixed"], (2999.75, 0, 0.125))   # house 07 body centre = (CX, CY) = (-0.25, -0.125)
rows = []
for b in plan["buildings"]:
    sk = b.get("skeleton")
    if not sk or sk["house"] not in SRC:
        continue
    names, o = SRC[sk["house"]]
    rows.append('{id="%s", src={%s}, ox=%g, oy=%g, oz=%g, x=%g, y=%g, z=%g, yaw=%g, dx=%g, dz=%g, dax=%g, daz=%g}' % (
        b["id"], ", ".join('"%s"' % n for n in names), o[0], o[1], o[2], sk["origin"][0], b["ground_y"], sk["origin"][1], b["yaw"],
        b["door_dir"][0], b["door_dir"][1], b["door_at"][0], b["door_at"][1]))
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
  local m = Instance.new("Model"); m.Name = r.id
  for _, n in r.src do
    local s = ST:FindFirstChild(n)
    if s then local c = s:Clone(); c.Parent = m else table.insert(out, r.id .. " MISSING " .. n) end
  end
  m:SetAttribute("HouseSkeleton", r.src[1]); m:SetAttribute("PlanYaw", r.yaw)
  m.WorldPivot = CFrame.new(r.ox, r.oy, r.oz)
  m.Parent = B
  m:PivotTo(CFrame.new(r.x, r.y, r.z) * CFrame.Angles(0, math.rad(r.yaw + 180), 0))
  local df = nil
  for _, d in m:GetDescendants() do if d:IsA("Attachment") and d.Name == "DoorFront" then df = d end end
  if df then
    local p = df.WorldPosition
    local ex, ez = r.dax + r.dx * 5, r.daz + r.dz * 5
    table.insert(out, string.format("%%s door err %%.2f (front pt %%.1f,%%.1f vs %%.1f,%%.1f) y %%.1f", r.id, math.sqrt((p.X - ex)^2 + (p.Z - ez)^2), p.X, p.Z, ex, ez, p.Y))
  else
    table.insert(out, r.id .. " placed (no DoorFront)")
  end
end
return table.concat(out, " | ")''' % ",\n".join(rows)
json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "house_plan_place.json"), "w", encoding="utf-8"))
print(len(rows), "buildings")
