"""WalkGround tags on the walkable parts of the house skeletons in WorldKit (이미지 생성 3, 10/12; 최종 검수 from 이미지 생성 1's
walking-ground check: the game's ground ray = Terrain + the WalkGround tag + kit pieces named Bridge / Stairs / Steps / Ramp).

  py tools/house_walk_tags.py   -> build/house_walk_tags.json, then
  STUDIO_ID=<WorldKit window id> py tools/studio_mcp.py call execute_luau @build/house_walk_tags.json

Roots: Workspace.SkeletonTest models named *_Skeleton (incl. House07_Skeleton) and every child of Workspace.HaloV2.Buildings
(the plan-spot clones, the 7 new-house blockouts, the castle). Tagged: StepLow*, StepTop*, Step<n>, FloorInside*,
FloorStorey*, RoofDeck*, Plinth* (the walkable top of the base ring), *_Slab (balconies), Floor* (blockout / castle floors).
Other sessions' props (lamps' Plinth etc.) are not under these roots and are left alone. Prints counts per pattern.
New skeletons get the tags from tools/skeleton_house.py / skeleton_house07.py themselves (10/12).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
code = r'''if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local CS = game:GetService("CollectionService")
local PATS = {"^StepLow", "^StepTop", "^Step%d", "^FloorInside", "^FloorStorey", "^RoofDeck", "^Plinth", "_Slab$", "^Floor"}
local roots = {}
for _, m in workspace.SkeletonTest:GetChildren() do
  if string.sub(m.Name, -9) == "_Skeleton" then table.insert(roots, m) end
end
local B = workspace:FindFirstChild("HaloV2") and workspace.HaloV2:FindFirstChild("Buildings")
if B then for _, m in B:GetChildren() do table.insert(roots, m) end end
local added, already, per = 0, 0, {}
for _, r in roots do
  for _, d in r:GetDescendants() do
    if d:IsA("BasePart") then
      for _, p in PATS do
        if string.match(d.Name, p) then
          if CS:HasTag(d, "WalkGround") then already += 1 else CS:AddTag(d, "WalkGround"); added += 1; per[p] = (per[p] or 0) + 1 end
          break
        end
      end
    end
  end
end
local out = {string.format("roots %d, added %d, already %d", #roots, added, already)}
for p, n in per do table.insert(out, p .. " +" .. n) end
return table.concat(out, " | ")'''
json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "house_walk_tags.json"), "w", encoding="utf-8"))
print("[walk] -> build/house_walk_tags.json")
