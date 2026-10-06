-- apply_world_look.lua : Studio-only world look that lives in the place, not in src/ (Edit mode only, idempotent).
-- Run by tools/apply_studio_state.py after tools/apply_surface_materials.lua (or alone via execute_luau).
--   1. A23-29/30 (user pick 'E'): tree leaves x1.35 under the neutral GE_TreeLeaves tile (meadow capped so G stays 255
--      with the same hue), the Ground roads with the painted GE_DirtPath tile at 235, and the Neutral 'B' lighting
--      (= Config.Sky.Neutral / WarService / tools/preview_map.lua).
--   2. world_kit_2026-10-06.md placement notes: meadow props standing on the pumpkin-field dirt path (x 352-368,
--      z 0-200) move 22 studs west (the mushroom ring centre becomes (338, 55) like preview_map.lua).
--   3. A23-36 (user 2026-10-06): no big 3D place text. Baked billboards on gates, the faction town signs and the crown
--      shard are removed; pad labels stay as small near-only labels (MapBuilder keeps the same rule at runtime).
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local RGB = Color3.fromRGB
local out = {}
local map = workspace:FindFirstChild("Map")
if not map then error("workspace.Map이 없습니다.") end
local decor, landmarks = map:FindFirstChild("Decor"), map:FindFirstChild("Landmarks")

-- 1a. leaves
local function key(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local LEAF = {
	["120,210,90"] = RGB(146, 255, 109), ["95,185,75"] = RGB(128, 250, 101), -- meadow
	["40,90,45"] = RGB(54, 121, 61), ["55,110,50"] = RGB(74, 149, 68), -- goblin woods
}
local leaves = 0
for _, m in (decor and decor:GetChildren() or {}) do
	if m:IsA("Model") and m.Name == "Tree" then
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "Leaves" or p.Name == "Leaves2") and LEAF[key(p.Color)] then
				p.Color = LEAF[key(p.Color)]
				leaves += 1
			end
		end
	end
end
table.insert(out, "leaves " .. leaves)

-- 1b. Ground roads under the painted dirt-path tile
local roads = decor and decor:FindFirstChild("Roads")
local roadN = 0
for _, p in (roads and roads:GetChildren() or {}) do
	if p:IsA("BasePart") and p.Material == Enum.Material.Ground and p.Color ~= RGB(235, 235, 235) then
		p.Color = RGB(235, 235, 235)
		roadN += 1
	end
end
table.insert(out, "roads " .. roadN)

-- 1c. Neutral 'B' lighting (the server re-applies the war sky at start; this keeps Edit and Play alike)
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14.2
Lighting.Brightness = 2.0
Lighting.Ambient = RGB(110, 108, 106)
Lighting.OutdoorAmbient = RGB(128, 126, 124)
Lighting.FogColor = RGB(205, 215, 230)
Lighting.FogStart = 250
Lighting.FogEnd = 1100
Lighting.GlobalShadows = true
pcall(function() Lighting.EnvironmentDiffuseScale = 1.0 end)
pcall(function() Lighting.EnvironmentSpecularScale = 0.6 end)
pcall(function() Lighting.ShadowSoftness = 0.5 end)
pcall(function() Lighting.ExposureCompensation = -0.2 end)
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then bloom.Intensity, bloom.Size, bloom.Threshold = 0.2, 24, 2.2 end
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
if rays then rays.Intensity, rays.Spread = 0.04, 0.4 end
table.insert(out, "lighting B")

-- 2. meadow props off the pumpkin-field path
local PATH = { MinX = 352, MaxX = 368, MinZ = 0, MaxZ = 200, Shift = Vector3.new(-22, 0, 0) }
local MEADOW_PROPS = { MushStem = true, MushCap = true, Bush = true, Flower = true }
local moved = 0
for _, p in (decor and decor:GetChildren() or {}) do
	if p:IsA("BasePart") and MEADOW_PROPS[p.Name] then
		local pos = p.Position
		if pos.X >= PATH.MinX and pos.X <= PATH.MaxX and pos.Z >= PATH.MinZ and pos.Z <= PATH.MaxZ then
			p.CFrame = p.CFrame + PATH.Shift
			moved += 1
		end
	end
end
-- the whole mushroom ring follows its moved pieces so it stays a ring: pieces still east of x 348 in the ring area
for _, p in (decor and decor:GetChildren() or {}) do
	if p:IsA("BasePart") and (p.Name == "MushStem" or p.Name == "MushCap") then
		local pos = p.Position
		if pos.X > 340 and pos.X < PATH.MinX and math.abs(pos.Z - 55) <= 11 then
			p.CFrame = p.CFrame + Vector3.new(-12, 0, 0)
			moved += 1
		end
	end
end
table.insert(out, "props moved " .. moved)

-- 3. big 3D place text (A23-36)
local removed = 0
local gates = map:FindFirstChild("Gates")
for _, d in (gates and gates:GetDescendants() or {}) do
	if d:IsA("BillboardGui") then d:Destroy(); removed += 1 end
end
for _, name in { "HaloSign", "HornsSign" } do
	local s = landmarks and landmarks:FindFirstChild(name)
	for _, d in (s and s:GetDescendants() or {}) do
		if d:IsA("BillboardGui") then d:Destroy(); removed += 1 end
	end
end
for _, d in map:GetDescendants() do
	if d:IsA("BillboardGui") then
		local label = d:FindFirstChildWhichIsA("TextLabel", true)
		if label and string.find(label.Text, "균형의 왕관 조각", 1, true) then d:Destroy(); removed += 1 end
	end
end
local pads = map:FindFirstChild("Pads")
local padN = 0
for _, pad in (pads and pads:GetChildren() or {}) do
	local bb = pad:FindFirstChildWhichIsA("BillboardGui")
	if bb then
		bb.Size = UDim2.fromOffset(190, 32)
		bb.MaxDistance = 40
		bb.StudsOffset = Vector3.new(0, 3, 0)
		padN += 1
	end
end
-- shop / landmark name labels stay but only up close (the sky crown image billboard has no TextLabel)
local shopN = 0
for _, d in (landmarks and landmarks:GetDescendants() or {}) do
	if d:IsA("BillboardGui") and d.MaxDistance > 50 and d:FindFirstChildWhichIsA("TextLabel", true) then
		d.MaxDistance = 50
		shopN += 1
	end
end
table.insert(out, "signs removed " .. removed .. ", pad labels small " .. padN .. ", shop labels near " .. shopN)
return table.concat(out, " | ")
