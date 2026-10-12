"""Put the Halo light castle C2 skeleton (SkeletonTest row 4, origin 3000, 0, 260) on its plan v2 spot in WorldKit
(이미지 생성 3, 10/12; plan id "Castle").

  py tools/castle_plan_place.py -> build/castle_plan_place.json, then
  STUDIO_NAME=WorldKit py tools/studio_mcp.py call execute_luau @build/castle_plan_place.json

Like tools/house_plan_place_new.py: the gray box of the id goes to ServerStorage.HaloV2_GrayBoxes (kept), the skeleton is
cloned into Workspace.HaloV2.Buildings.Castle, PivotTo(ground_y, yaw + 180), then slid in XZ so its DoorFront (5 studs in
front of the facade) lands on door_at + door_dir x 5. Prints the door error after the slide (~0).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
plan = json.load(open(os.path.join(ROOT, "docs", "design", "halo_plan_v2_2026-10-11.json"), encoding="utf-8"))
b = next(x for x in plan["buildings"] if x["id"] == "Castle")
(dax, daz), (dx, dz) = b["door_at"], b["door_dir"]
D2 = 30.0                                   # facade front (YF 25) + 5 = DoorFront, platform centre ~ 30 studs behind it
code = '''if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local ST = workspace.SkeletonTest
local B = workspace.HaloV2.Buildings
local SS = game:GetService("ServerStorage")
local hold = SS:FindFirstChild("HaloV2_GrayBoxes") or Instance.new("Folder")
hold.Name = "HaloV2_GrayBoxes"; hold.Parent = SS
local box = B:FindFirstChild("Castle")
if box and not box:GetAttribute("HouseSkeleton") then box.Parent = hold end
local old = B:FindFirstChild("Castle")
if old and old:GetAttribute("HouseSkeleton") then old:Destroy() end
local s = ST:FindFirstChild("HaloCastle_C2_Skeleton")
if not s then return "MISSING HaloCastle_C2_Skeleton" end
local m = Instance.new("Model"); m.Name = "Castle"
s:Clone().Parent = m
m:SetAttribute("HouseSkeleton", "HaloCastle_C2_Skeleton"); m:SetAttribute("PlanYaw", %g)
m.WorldPivot = CFrame.new(3000, 0, 260)
m.Parent = B
m:PivotTo(CFrame.new(%g, %g, %g) * CFrame.Angles(0, math.rad(%g + 180), 0))
local df = nil
for _, d in m:GetDescendants() do if d:IsA("Attachment") and d.Name == "DoorFront" then df = d end end
if not df then return "Castle placed (no DoorFront)" end
local p = df.WorldPosition
m:PivotTo(m:GetPivot() + Vector3.new(%g - p.X, 0, %g - p.Z))
p = df.WorldPosition
return string.format("Castle door err %%.3f y %%.1f", math.sqrt((p.X - %g)^2 + (p.Z - %g)^2), p.Y)''' % (
    b["yaw"], dax - dx * D2, b["ground_y"], daz - dz * D2, b["yaw"], dax + dx * 5, daz + dz * 5, dax + dx * 5, daz + dz * 5)
json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "castle_plan_place.json"), "w", encoding="utf-8"))
print("[castle] plan spot", b["id"], "door_at", b["door_at"], "yaw", b["yaw"], "-> build/castle_plan_place.json")
