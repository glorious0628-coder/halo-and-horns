-- 이미지 생성 3 10/14: multi-material assembled Tripo HD kit (e.g. HaloVar4_Balustrade_C, Blender-assembled parts GLB, imported with
-- tools/glb_strip_mesh.py --part-names) -> ServerStorage.HaloTripoKits.<NAME>: every MeshPart <NAME>_tripo_pNN_mK gets the SurfaceAppearance
-- set of material K (art/ui/asset_ids.json SA_<NAME>_mK_C/N/M/R, tuned by tools/hd_mat_tune.py), uniform scale so the height = H studs,
-- pivot = bottom centre of the whole bounding box. Run in WorldKit (STUDIO_ID), Edit mode, after the user's 3D import (Workspace.<NAME>_TU).
-- The generator (tools/worldkit/tripo_parts_kit_gen.py) fills NAME / H / SA / TWO.
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local NAME = "@NAME@"
local H = @H@
local SA = @SA@          -- [materialIndex] = {C, N, M, R}
local TWO = @TWO@        -- [materialIndex] = true -> MeshPart.DoubleSided
local SS = game:GetService("ServerStorage")
local F = SS:FindFirstChild("HaloTripoKits") or Instance.new("Folder"); F.Name = "HaloTripoKits"; F.Parent = SS
local src = workspace:FindFirstChild(NAME .. "_TU")
if not src then return NAME .. "_TU MISSING in Workspace" end
local parts = {}
for _, d in src:GetDescendants() do if d:IsA("MeshPart") then table.insert(parts, d) end end
table.sort(parts, function(a, b) return a.Name < b.Name end)
local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
for _, p in parts do
  for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
    local c = (p.CFrame * CFrame.new(p.Size.X / 2 * sx, p.Size.Y / 2 * sy, p.Size.Z / 2 * sz)).Position
    lo = Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
    hi = Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
  end end end
end
local origin = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
local s = H / (hi.Y - lo.Y)
local old = F:FindFirstChild(NAME); if old then old:Destroy() end
local m = Instance.new("Model"); m.Name = NAME
local log = {}
for _, p in parts do
  local k = tonumber(string.match(p.Name, "_m(%d+)$"))
  local sa = k and SA[k]
  if not sa then table.insert(log, "NO MATERIAL " .. p.Name); continue end
  local c = p:Clone(); for _, ch in c:GetChildren() do ch:Destroy() end
  c.Name = string.match(p.Name, "_p(%d+_m%d+)$") or p.Name
  c.Anchored = true; c.TextureID = ""; c.CanCollide = false
  c.Size = p.Size * s
  c.CFrame = CFrame.new((p.Position - origin) * s) * (p.CFrame - p.CFrame.Position)
  local a = Instance.new("SurfaceAppearance")
  a.ColorMap = sa[1]; a.NormalMap = sa[2]; a.MetalnessMap = sa[3]; a.RoughnessMap = sa[4]; a.Parent = c
  if TWO[k] then pcall(function() c.DoubleSided = true end) end
  c.Parent = m
end
m.WorldPivot = CFrame.new(0, 0, 0)
m:SetAttribute("TripoKit", true); m:SetAttribute("Parts", #parts); m:SetAttribute("Scale", s)
m.Parent = F
return string.format("%s ok parts=%d scale=%.3f bbox=%.2f x %.2f x %.2f studs=%s", NAME, #parts, s, (hi.X - lo.X) * s, H, (hi.Z - lo.Z) * s, table.concat(log, ";"))
