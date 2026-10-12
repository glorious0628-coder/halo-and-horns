"""Swap rebuilt house skeletons into WorldKit everywhere they are used (이미지 생성 3, 10/12).

  py tools/house_skeleton_swap.py <house> [...]   (build/skel_rows/<house>.luau must be generated at the test-row origin)
  -> build/house_skeleton_swap_<i>.json, run each with
  STUDIO_ID=<WorldKit window id> py tools/studio_mcp.py call execute_luau @build/house_skeleton_swap_<i>.json

For each house: the row luau rebuilds Workspace.SkeletonTest.<house>_Skeleton (with WalkGround tags); then every
HaloV2.Buildings clone holding that skeleton (attribute HouseSkeleton) gets the new one: the old child is replaced by a
clone moved with the same row -> plan map the building used (building.WorldPivot * CFrame(row origin):Inverse()).
Lamp glass: each LampGlass is refit to the rebuilt lantern next to it (attribute LanternScaled = f on the lantern: glass
centre pulled to the wall by f, 1.05 tall, width from the old glass), marked GlassFit.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRONT = ["01", "02", "03", "04", "05", "06", "08", "09"]
BACK = ["10", "11", "12", "Bakery", "Flower", "Juice", "Potion"]
ROWS = {}
for i, h in enumerate(FRONT):
    ROWS["HaloDomeHouse_" + h] = (2940 + 36 * i, 60)
for i, h in enumerate(BACK):
    ROWS[("HaloDomeHouse_" + h) if h.isdigit() else ("HaloShop_" + h)] = (2940 + 36 * i, 115)
FIX = r'''
local ST = workspace.SkeletonTest
local name, ox, oz = "%s", %g, %g
local new = ST:FindFirstChild(name .. "_Skeleton")
if not new then return name .. ": rebuilt skeleton missing" end
local function refit(skel, deco)
  if not (skel and deco) then return 0 end
  local lam = {}
  for _, l in deco:GetChildren() do if l:IsA("BasePart") and l:GetAttribute("LanternScaled") then table.insert(lam, l) end end
  local n = 0
  for _, g in skel:GetDescendants() do
    if g:IsA("BasePart") and string.match(g.Name, "^LampGlass%%d") and not g:GetAttribute("GlassFit") then
      local best, bd = nil, 1e9
      for _, l in lam do local d = (l.Position - g.Position).Magnitude; if d < bd then best, bd = l, d end end
      if best and bd < 4 then
        local f = best:GetAttribute("LanternScaled")
        local pw = g.CFrame:PointToWorldSpace(Vector3.new(0, 0, 0.75))
        local gc = pw + (g.Position - pw) * f
        local idx = string.match(g.Name, "%%d+")
        local core = skel:FindFirstChild("LampCore" .. idx, true)
        local gw = math.clamp(g.Size.X * f, 0.3, 0.7)
        g.CFrame = g.CFrame - g.Position + gc
        g.Size = Vector3.new(gw, 1.05, gw)
        g:SetAttribute("GlassFit", true)
        if core then core.CFrame = core.CFrame - core.Position + gc; core.Size = Vector3.new(gw * 0.5, 0.5, gw * 0.5) end
        n += 1
      end
    end
  end
  return n
end
local out = {name .. ": rows glass " .. refit(new, ST:FindFirstChild(name .. "_Deco"))}
local B = workspace:FindFirstChild("HaloV2") and workspace.HaloV2:FindFirstChild("Buildings")
if B then
  for _, b in B:GetChildren() do
    local old = b:FindFirstChild(name .. "_Skeleton")
    if old and b:GetAttribute("HouseSkeleton") == name .. "_Skeleton" then
      local M = b.WorldPivot * CFrame.new(ox, 0, oz):Inverse()
      old:Destroy()
      local c = new:Clone()
      for _, g in c:GetDescendants() do if g:IsA("BasePart") then g:SetAttribute("GlassFit", nil) end end
      c.Parent = b
      for _, p in c:GetDescendants() do if p:IsA("BasePart") then p.CFrame = M * p.CFrame end end
      table.insert(out, b.Name .. " swapped, glass " .. refit(c, b:FindFirstChild(name .. "_Deco")))
    end
  end
end
return table.concat(out, " | ")'''
for i, n in enumerate(sys.argv[1:]):
    ox, oz = ROWS[n]
    code = open(os.path.join(ROOT, "build", "skel_rows", n + ".luau"), encoding="utf-8").read()
    # the row luau ends with a return: run it as a function, then the swap
    code = "local built = (function()\n" + code + "\nend)()\n" + (FIX % (n, ox, oz)).replace("return table.concat(out, \" | \")", "return built .. \" | \" .. table.concat(out, \" | \")")
    json.dump({"code": code, "datamodel_type": "Edit"}, open(os.path.join(ROOT, "build", "house_skeleton_swap_%d.json" % i), "w", encoding="utf-8"))
    print("[swap]", n, "-> build/house_skeleton_swap_%d.json" % i)
