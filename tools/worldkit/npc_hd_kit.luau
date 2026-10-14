-- 이미지 생성 3 10/14: HD people kits (NPC_*_TU imported as 2 MeshParts: body + the mesh's own halo ring) -> ServerStorage.HaloTripoKits.<name>
-- body = SurfaceAppearance (C N M R from art/ui/asset_ids.json), height = H studs (player height, uniform scale only),
-- the mesh's own halo piece is hidden (Transparency 1, kept as 'MeshHalo') and the game's shared halo (Config.Visuals.MarkModels
-- Acc_HaloR1 mesh + texture) is placed on the same centre, same ring diameter. Run in WorldKit (STUDIO_ID), Edit mode.
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local H = 5.2
local HALO_MESH, HALO_TEX = "rbxassetid://105104382701229", "rbxassetid://81330577883668"  -- Acc_HaloR1 (1.34 x 0.086 x 1.34)
local K = {
  {"NPC_HaloBakerGranny", "rbxassetid://76162798431469", "rbxassetid://97784888585774", "rbxassetid://138160427790831", "rbxassetid://90365588083568"},
  {"NPC_HaloBellElder", "rbxassetid://87114508249904", "rbxassetid://120993807011227", "rbxassetid://131260653500960", "rbxassetid://115891570079755"},
}
local SS = game:GetService("ServerStorage")
local F = SS:FindFirstChild("HaloTripoKits") or Instance.new("Folder"); F.Name = "HaloTripoKits"; F.Parent = SS
local out = {}
for _, k in K do
  local name, cm, nm, mm, rm = k[1], k[2], k[3], k[4], k[5]
  local src = workspace:FindFirstChild(name .. "_TU")
  if not src then table.insert(out, name .. " MISSING _TU"); continue end
  local parts = {}
  for _, d in src:GetDescendants() do if d:IsA("MeshPart") then table.insert(parts, d) end end
  if #parts ~= 2 then table.insert(out, name .. " parts " .. #parts); continue end
  table.sort(parts, function(a, b) return a.Size.Magnitude > b.Size.Magnitude end)
  local body, ring = parts[1], parts[2]
  local R0 = body.CFrame - body.CFrame.Position
  local origin = Vector3.new(body.Position.X, body.Position.Y - body.Size.Y / 2, body.Position.Z)
  local s = H / body.Size.Y
  local old = F:FindFirstChild(name); if old then old:Destroy() end
  local m = Instance.new("Model"); m.Name = name
  local function clone(p, nm2)
    local c = p:Clone(); for _, ch in c:GetChildren() do ch:Destroy() end
    c.Name = nm2; c.Anchored = true; c.TextureID = ""; c.CanCollide = false
    c.Size = p.Size * s
    c.CFrame = CFrame.new((p.Position - origin) * s + Vector3.new(0, 0, 0)) * R0
    c.Parent = m
    return c
  end
  local b = clone(body, name .. "_Body")
  local sa = Instance.new("SurfaceAppearance")
  sa.ColorMap = cm; sa.NormalMap = nm; sa.MetalnessMap = mm; sa.RoughnessMap = rm; sa.Parent = b
  local r = clone(ring, "MeshHalo"); r.Transparency = 1; r.CanQuery = false; r.CanTouch = false
  -- the game's shared halo ring, same centre, ring diameter = the mesh ring's longest horizontal side
  local ringSize = r.Size
  local diam = math.max(ringSize.X, ringSize.Z, 0.2)
  if ringSize.Y > math.max(ringSize.X, ringSize.Z) then diam = math.max(ringSize.X, ringSize.Z) end
  local hl = Instance.new("MeshPart"); hl.Name = "GameHalo"
  hl.MeshId = HALO_MESH; hl.TextureID = HALO_TEX
  hl.Anchored = true; hl.CanCollide = false; hl.CanQuery = false; hl.CanTouch = false; hl.CastShadow = false
  local f = diam / 1.34
  hl.Size = Vector3.new(1.34, 0.086, 1.34) * f
  hl.CFrame = CFrame.new(r.Position)
  hl.Parent = m
  m.WorldPivot = CFrame.new(0, 0, 0)
  m:SetAttribute("TripoKit", true); m:SetAttribute("HDNpc", true); m:SetAttribute("Scale", s)
  m.Parent = F
  table.insert(out, string.format("%s ok scale %.3f body %s ring %s halo diam %.2f", name, s, tostring(b.Size), tostring(r.Size), diam))
end
return table.concat(out, "\n")
