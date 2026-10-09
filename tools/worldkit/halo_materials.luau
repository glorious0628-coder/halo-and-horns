-- halo_materials.luau (이미지 생성 1, 2026-10-09, SPEC A23-97 빛 마을): gives the Halo plaza its own terrain material.
-- Studio MCP execute_luau, Edit mode, any place that has MaterialService.GE_HaloTiles (the runner replaces "__MODE__").
-- Terrain has no Marble, so the Halo island's paved tops (tools/worldkit/halo_terrain.luau: PAVE) use Concrete:
--   apply   : clone GE_HaloTiles as GE_HaloPave (BaseMaterial Concrete), override Concrete -> GE_HaloPave, Terrain colour of Concrete
--             235 grey (the painted tile carries its own colour, like the other ground materials)
--   restore : clear the override, remove GE_HaloPave, put the old Concrete colour back
-- Idempotent. Returns what it did.
local MODE = "__MODE__"
if MODE ~= "restore" then MODE = "apply" end
local MS = game:GetService("MaterialService")
local Terrain = workspace.Terrain
local NAME = "GE_HaloPave"
local old = MS:FindFirstChild(NAME)
if MODE == "restore" then
	pcall(function() MS:SetBaseMaterialOverride(Enum.Material.Concrete, "") end)
	if old then old:Destroy() end
	local c = Terrain:GetAttribute("ConcreteColorWas")
	if typeof(c) == "Color3" then Terrain:SetMaterialColor(Enum.Material.Concrete, c) end
	Terrain:SetAttribute("ConcreteColorWas", nil)
	return "halo materials restored"
end
local src = MS:FindFirstChild("GE_HaloTiles")
assert(src and src:IsA("MaterialVariant"), "MaterialService.GE_HaloTiles missing (import / apply_surface_materials first)")
if old then old:Destroy() end
local v = src:Clone()
v.Name = NAME
v.BaseMaterial = Enum.Material.Concrete
v.Parent = MS
MS:SetBaseMaterialOverride(Enum.Material.Concrete, NAME)
if Terrain:GetAttribute("ConcreteColorWas") == nil then
	Terrain:SetAttribute("ConcreteColorWas", Terrain:GetMaterialColor(Enum.Material.Concrete))
end
Terrain:SetMaterialColor(Enum.Material.Concrete, Color3.fromRGB(235, 235, 235))
return string.format("halo materials: %s (Concrete) override = %s, studs per tile %s", NAME, tostring(MS:GetBaseMaterialOverride(Enum.Material.Concrete)), tostring(v.StudsPerTile))
