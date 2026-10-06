-- Root가 그림 검토/업로드/Config 동기화 후 GoodEvil Edit 모드에서만 실행한다.
-- 공식 API: https://create.roblox.com/docs/reference/engine/classes/MaterialService
-- 공식 API: https://create.roblox.com/docs/reference/engine/classes/MaterialVariant
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local HttpService = game:GetService("HttpService")
local MaterialService = game:GetService("MaterialService")
local source = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
source = source and source:FindFirstChild("Config")
if not source or not source:IsA("ModuleScript") then error("Shared.Config가 없습니다.") end
-- Edit-mode require cache must not retain IDs from before the upload.
local fresh = source:Clone()
local okConfig, Config = pcall(require, fresh)
fresh:Destroy()
if not okConfig or type(Config) ~= "table" then error("Config를 읽지 못했습니다.") end
-- Fresh = the variant is rebuilt as a new instance holding only this ColorMap (A23-30 E tiles, Firefly 2026-10-06):
-- the painted tile carries its own colour, so its terrain material colour goes to TerrainColor (near white; the old
-- dark tints would darken it twice) and StudsPerTile is the size checked in docs/design/world_blend_2026-10-06.md.
local PAINTED = Color3.fromRGB(235, 235, 235)
local definitions = {
	{ Key = "Tex_Grass", Name = "GE_Grass", Material = Enum.Material.Grass, Override = true, Fresh = true,
		StudsPerTile = 16, TerrainColor = PAINTED },
	{ Key = "Tex_LeafyGrass", Name = "GE_LeafyGrass", Material = Enum.Material.LeafyGrass, Override = true, Fresh = true,
		StudsPerTile = 16, TerrainColor = PAINTED },
	{ Key = "Tex_HaloTiles", Name = "GE_HaloTiles", Material = Enum.Material.Limestone },
	{ Key = "Tex_Ground", Name = "GE_Ground", Material = Enum.Material.Ground, Override = true, Fresh = true,
		StudsPerTile = 16, TerrainColor = PAINTED },
	{ Key = "Tex_DirtPath", Name = "GE_DirtPath", Material = Enum.Material.Ground, Fresh = true, StudsPerTile = 16 },
	{ Key = "Tex_CrownShardGround", Name = "GE_CrownShardGround", Material = Enum.Material.Ground },
	{ Key = "Tex_CrackedLava", Name = "GE_CrackedLava", Material = Enum.Material.CrackedLava, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	{ Key = "Tex_Cobblestone", Name = "GE_Cobblestone", Material = Enum.Material.Cobblestone, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	{ Key = "Tex_Basalt", Name = "GE_Basalt", Material = Enum.Material.Basalt, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	{ Key = "Tex_WoodPlanks", Name = "GE_WoodPlanks", Material = Enum.Material.WoodPlanks, Override = true, Fresh = true,
		StudsPerTile = 10 },
	{ Key = "Tex_Slate", Name = "GE_Slate", Material = Enum.Material.Slate, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	{ Key = "Tex_Sand", Name = "GE_Sand", Material = Enum.Material.Sand, Override = true, Fresh = true,
		StudsPerTile = 16, TerrainColor = PAINTED },
	{ Key = "Tex_Rock", Name = "GE_Rock", Material = Enum.Material.Rock, Override = true, Fresh = true,
		StudsPerTile = 16, TerrainColor = PAINTED },
	{ Key = "Tex_Marble", Name = "GE_Marble", Material = Enum.Material.Marble, Override = true, Fresh = true,
		StudsPerTile = 10 },
	{ Key = "Tex_Limestone", Name = "GE_Limestone", Material = Enum.Material.Limestone, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	-- A23-30 pumpkin field soil: Mud was an empty slot (no other terrain or part uses it)
	{ Key = "Tex_PumpkinSoil", Name = "GE_PumpkinSoil", Material = Enum.Material.Mud, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	-- A23-45 HauntedHollow floor: Asphalt was an empty slot (MapBuilder fills the hollow's land with it)
	{ Key = "Tex_HauntedFloor", Name = "GE_HauntedFloor", Material = Enum.Material.Asphalt, Override = true, Fresh = true,
		StudsPerTile = 14, TerrainColor = PAINTED },
	-- trees: named variants on the Map.Decor Tree parts only (no base override: Wood / SmoothPlastic are on ~300 other
	-- parts); the neutral tiles take the part Color as the leaf / bark colour
	{ Key = "Tex_TreeLeaves", Name = "GE_TreeLeaves", Material = Enum.Material.SmoothPlastic, Fresh = true, StudsPerTile = 9,
		Parts = { Model = "Tree", Names = { Leaves = true, Leaves2 = true } } },
	{ Key = "Tex_TreeBark", Name = "GE_TreeBark", Material = Enum.Material.Wood, Fresh = true, StudsPerTile = 8,
		Parts = { Model = "Tree", Names = { Trunk = true } } },
}
-- A Fresh row's variant carries the Id it was built for. Never clone the old variant: a clone can retain its
-- inaccessible compiled TexturePack even after the visible maps are cleared. ("GE_ColorOnlyFresh" was the 2026-10-03
-- grass-only marker; a variant whose freshMarker is not its Id is rebuilt.)
local freshMarker = "GE_FreshColorMap"
local preservedProperties = { "Name", "BaseMaterial", "AlphaMode", "StudsPerTile", "MaterialPattern", "CustomPhysicalProperties" }
local mapProperties = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" }
local before = { Variants = {}, Overrides = {}, Roads = {}, RoadInstances = {}, TerrainColors = {} }
local roadStates = {}
local function backupValue(value)
	local kind = typeof(value)
	if value == nil then return false end
	if kind == "boolean" or kind == "number" or kind == "string" then return value end
	if kind == "EnumItem" then return { Type = kind, Value = tostring(value) } end
	if kind == "PhysicalProperties" then
		local data = { Density = value.Density, Friction = value.Friction, Elasticity = value.Elasticity,
			FrictionWeight = value.FrictionWeight, ElasticityWeight = value.ElasticityWeight }
		-- Older Studio versions do not expose the optional sixth constructor component.
		pcall(function() data.AcousticAbsorption = value.AcousticAbsorption end)
		return { Type = kind, Value = data }
	elseif kind == "Color3" then return { Type = kind, Value = { value.R, value.G, value.B } }
	elseif kind == "BrickColor" then return { Type = kind, Value = value.Number }
	elseif kind == "Vector2" then return { Type = kind, Value = { value.X, value.Y } }
	elseif kind == "Vector3" then return { Type = kind, Value = { value.X, value.Y, value.Z } }
	elseif kind == "CFrame" then return { Type = kind, Value = { value:GetComponents() } }
	elseif kind == "UDim" then return { Type = kind, Value = { value.Scale, value.Offset } }
	elseif kind == "UDim2" then return { Type = kind, Value = { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } }
	elseif kind == "Rect" then return { Type = kind, Value = { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y } }
	elseif kind == "NumberRange" then return { Type = kind, Value = { value.Min, value.Max } }
	elseif kind == "NumberSequence" or kind == "ColorSequence" then
		local keys = {}
		for _, key in value.Keypoints do
			table.insert(keys, { Time = key.Time, Value = backupValue(key.Value), Envelope = kind == "NumberSequence" and key.Envelope or nil })
		end
		return { Type = kind, Value = keys }
	end
	error("백업할 수 없는 속성 형식입니다: " .. kind)
end
local function captureVariant(variant)
	local raw = { Parent = variant.Parent, Attributes = variant:GetAttributes(), Properties = {} }
	local saved = { Attributes = {} }
	for _, property in preservedProperties do
		local value = variant[property]
		raw.Properties[property] = value
		saved[property] = backupValue(value)
	end
	for _, property in mapProperties do
		local value = variant[property]
		raw.Properties[property] = value
		saved[property] = value -- All old PBR maps remain in the JSON backup, even for fresh color-only grass.
	end
	for name, value in raw.Attributes do saved.Attributes[name] = backupValue(value) end
	return raw, saved
end
local roads = workspace:FindFirstChild("Map")
roads = roads and roads:FindFirstChild("Decor")
roads = roads and roads:FindFirstChild("Roads")
-- Validate every image and every existing variant before writing anything.
for _, row in definitions do
	local part = Config.UIArt and Config.UIArt.Parts and Config.UIArt.Parts[row.Key]
	local id = type(part) == "table" and part.Id
	if type(id) ~= "string" or not string.match(id, "^rbxassetid://[1-9]%d*$") then
		error("새 계정 업로드 ID가 없습니다: " .. row.Key)
	end
	row.Id = id
	local matches = 0
	for _, child in MaterialService:GetChildren() do
		if child.Name == row.Name then matches += 1 end
	end
	if matches > 1 then error("같은 이름의 재질이 여러 개입니다: " .. row.Name) end
	local variant = MaterialService:FindFirstChild(row.Name)
	if variant and (not variant:IsA("MaterialVariant") or variant.BaseMaterial ~= row.Material) then
		error("기존 이름 또는 기본 재질이 다릅니다: " .. row.Name)
	end
	row.Original = variant -- Exact original instance, including any hidden cache, survives until the whole apply succeeds.
	if variant then
		local raw, saved = captureVariant(variant)
		row.Prior = raw
		before.Variants[row.Name] = saved
	else before.Variants[row.Name] = false end
	if row.Override then before.Overrides[row.Material.Name] = MaterialService:GetBaseMaterialOverride(row.Material) end
	if row.TerrainColor then
		row.PriorColor = workspace.Terrain:GetMaterialColor(row.Material)
		before.TerrainColors[row.Material.Name] = backupValue(row.PriorColor)
	end
end
if roads then
	for _, part in roads:GetDescendants() do
		if part:IsA("BasePart") and part.Material == Enum.Material.Ground then
			before.Roads[part.Name] = part.MaterialVariant
			table.insert(before.RoadInstances, { Path = part:GetFullName(), MaterialVariant = part.MaterialVariant })
			table.insert(roadStates, { Part = part, MaterialVariant = part.MaterialVariant })
		end
	end
end
-- rows with Parts: the named variant goes on those parts of every <Model> under Map.Decor (base material must match)
local partStates = {}
local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
for _, row in definitions do
	if row.Parts and decor then
		for _, model in decor:GetDescendants() do
			if model:IsA("Model") and model.Name == row.Parts.Model then
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") and row.Parts.Names[part.Name] and part.Material == row.Material then
						table.insert(partStates, { Part = part, MaterialVariant = part.MaterialVariant, Name = row.Name })
					end
				end
			end
		end
	end
end
before.NamedParts = #partStates
local backupName = "GE_SurfaceBackup_20261006"
if MaterialService:GetAttribute(backupName) == nil then
	MaterialService:SetAttribute(backupName, HttpService:JSONEncode(before))
end
local result = { Updated = {}, Overrides = {}, Roads = 0, NamedParts = 0, Rebuilt = {}, TerrainColors = {},
	RegisteredOnly = { "GE_HaloTiles", "GE_CrownShardGround" } }
local encodedResult
local ok, err = pcall(function()
	local grass = definitions[1].Original
	local tileSize = grass and grass.StudsPerTile
	for _, row in definitions do
		local variant = row.Original
		local rebuild = row.Fresh == true and variant ~= nil and variant:GetAttribute(freshMarker) ~= row.Id
		if not variant or rebuild then
			variant = Instance.new("MaterialVariant")
			row.Applied = variant -- Track it before any property write can throw.
			variant.Name = row.Name
			variant.BaseMaterial = row.Material
			if rebuild then
				for _, property in preservedProperties do variant[property] = row.Prior.Properties[property] end
				for name, value in row.Prior.Attributes do variant:SetAttribute(name, value) end
				variant:SetAttribute("GE_ColorOnlyFresh", nil)
			else
				-- Reuse the place's existing grass tile scale; otherwise keep Roblox's default.
				if type(tileSize) == "number" and tileSize > 0 and tileSize < math.huge then variant.StudsPerTile = tileSize end
			end
			variant.ColorMap = row.Id -- Never assign any old map to the fresh instance, even temporarily.
			if rebuild then row.Original.Parent = nil end -- Keep it intact and rollback-capable off the service.
			variant.Parent = MaterialService
			if rebuild then table.insert(result.Rebuilt, row.Name) end
		else
			row.Applied = variant
		end
		variant.ColorMap = row.Id
		-- A Fresh tile is a color texture only; retain no inaccessible maps from the old account.
		if row.Fresh then
			variant.NormalMap = ""
			variant.MetalnessMap = ""
			variant.RoughnessMap = ""
			variant:SetAttribute(freshMarker, row.Id)
			if row.StudsPerTile then variant.StudsPerTile = row.StudsPerTile end
		end
		table.insert(result.Updated, row.Name)
		if row.Override then
			MaterialService:SetBaseMaterialOverride(row.Material, row.Name)
			table.insert(result.Overrides, row.Material.Name)
		end
	end
	for _, state in roadStates do
		state.Part.MaterialVariant = "GE_DirtPath"
		result.Roads += 1
	end
	for _, state in partStates do
		state.Part.MaterialVariant = state.Name
		result.NamedParts += 1
	end
	for _, row in definitions do
		if row.TerrainColor then
			workspace.Terrain:SetMaterialColor(row.Material, row.TerrainColor)
			result.TerrainColors[row.Material.Name] = row.TerrainColor:ToHex()
		end
	end
	for _, row in definitions do
		local variant = row.Applied
		assert(variant.Parent == MaterialService and variant.Name == row.Name and variant.BaseMaterial == row.Material,
			"재질 등록 검증 실패: " .. row.Name)
		assert(variant.ColorMap == row.Id, "새 ColorMap 검증 실패: " .. row.Name)
		if row.Fresh then
			assert(variant.NormalMap == "" and variant.MetalnessMap == "" and variant.RoughnessMap == "",
				"PBR 비우기 검증 실패: " .. row.Name)
			assert(variant:GetAttribute(freshMarker) == row.Id, "새 재질 표시 검증 실패: " .. row.Name)
			assert(not row.StudsPerTile or variant.StudsPerTile == row.StudsPerTile, "타일 크기 검증 실패: " .. row.Name)
		end
		if row.TerrainColor then
			assert(workspace.Terrain:GetMaterialColor(row.Material) == row.TerrainColor, "지형 색 검증 실패: " .. row.Name)
		end
		if row.Override then
			assert(MaterialService:GetBaseMaterialOverride(row.Material) == row.Name, "기본 재질 override 검증 실패: " .. row.Name)
		end
	end
	encodedResult = HttpService:JSONEncode(result) -- Also retain the original through serialization failures.
end)
if not ok then
	local failures = {}
	local function restore(label, fn)
		local restored, restoreErr = pcall(fn)
		if not restored then table.insert(failures, label .. ": " .. tostring(restoreErr)) end
	end
	for _, row in definitions do
		if row.Applied and row.Applied ~= row.Original then
			restore(row.Name .. ".NewParent", function() row.Applied.Parent = nil end)
			restore(row.Name .. ".NewDestroy", function() row.Applied:Destroy() end)
		end
		if row.Applied and row.Original and row.Prior then
			-- A detached legacy grass was never edited: only reparent that same instance, without dirtying its cache.
			if row.Applied == row.Original then
				for _, property in mapProperties do
					restore(row.Name .. "." .. property, function() row.Original[property] = row.Prior.Properties[property] end)
				end
			end
			restore(row.Name .. ".Parent", function() row.Original.Parent = row.Prior.Parent end)
		end
		if row.Override then
			restore(row.Material.Name .. ".Override", function()
				MaterialService:SetBaseMaterialOverride(row.Material, before.Overrides[row.Material.Name])
			end)
		end
	end
	for _, state in roadStates do
		restore("Road." .. state.Part.Name, function() state.Part.MaterialVariant = state.MaterialVariant end)
	end
	for _, state in partStates do
		restore("Part." .. state.Part.Name, function() state.Part.MaterialVariant = state.MaterialVariant end)
	end
	for _, row in definitions do
		if row.PriorColor then
			restore(row.Material.Name .. ".TerrainColor", function()
				workspace.Terrain:SetMaterialColor(row.Material, row.PriorColor)
			end)
		end
	end
	local detail = #failures > 0 and ("; 복원 오류: " .. table.concat(failures, " | ")) or "; 기존 인스턴스 복원 완료"
	error("재질 연결 실패: " .. tostring(err) .. detail)
end
-- Commit point: all variants, overrides, roads and the response are valid. Only now discard the legacy instance.
for _, row in definitions do
	if row.Original and row.Applied ~= row.Original then row.Original:Destroy() end
end
return encodedResult
