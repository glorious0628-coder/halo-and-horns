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
-- 2026-10-10: own white-marble paving (Firefly High, art/out/s2/halo_floor/Marble_B_high.png: 2x2 slabs with gold inlay borders, seamless) replaces the
-- beige GE_HaloTiles look on the Halo paving; 16 studs per texture = 8-stud slabs. Empty PAVE_COLOR = keep the cloned GE_HaloTiles maps.
local PAVE_COLOR = "rbxassetid://90183036072881"
local PAVE_STUDS = 16
local old = MS:FindFirstChild(NAME)
if MODE == "restore" then
	pcall(function() MS:SetBaseMaterialOverride(Enum.Material.Concrete, "") end)
	if old then old:Destroy() end
	local c = Terrain:GetAttribute("ConcreteColorWas")
	if typeof(c) == "Color3" then Terrain:SetMaterialColor(Enum.Material.Concrete, c) end
	Terrain:SetAttribute("ConcreteColorWas", nil)
	local lc = Terrain:GetAttribute("LimestoneColorWas")
	if typeof(lc) == "Color3" then Terrain:SetMaterialColor(Enum.Material.Limestone, lc) end
	Terrain:SetAttribute("LimestoneColorWas", nil)
	return "halo materials restored"
end
local src = MS:FindFirstChild("GE_HaloTiles")
assert(src and src:IsA("MaterialVariant"), "MaterialService.GE_HaloTiles missing (import / apply_surface_materials first)")
if old then old:Destroy() end
local v = src:Clone()
v.Name = NAME
v.BaseMaterial = Enum.Material.Concrete
if PAVE_COLOR ~= "" then
	v.ColorMap = PAVE_COLOR
	v.NormalMap = ""
	v.RoughnessMap = ""
	v.MetalnessMap = ""
	v.StudsPerTile = PAVE_STUDS
end
v.Parent = MS
MS:SetBaseMaterialOverride(Enum.Material.Concrete, NAME)
if Terrain:GetAttribute("ConcreteColorWas") == nil then
	Terrain:SetAttribute("ConcreteColorWas", Terrain:GetMaterialColor(Enum.Material.Concrete))
end
Terrain:SetMaterialColor(Enum.Material.Concrete, Color3.fromRGB(250, 248, 244))
-- 2026-10-10: the cliffs read WHITE limestone in the concept (the default tan made the island look like a sand slab)
if Terrain:GetAttribute("LimestoneColorWas") == nil then
	Terrain:SetAttribute("LimestoneColorWas", Terrain:GetMaterialColor(Enum.Material.Limestone))
end
Terrain:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(244, 240, 230))
return string.format("halo materials: %s (Concrete) override = %s, studs per tile %s", NAME, tostring(MS:GetBaseMaterialOverride(Enum.Material.Concrete)), tostring(v.StudsPerTile))
