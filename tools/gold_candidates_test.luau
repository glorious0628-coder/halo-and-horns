-- Gold trim candidates side by side (이미지 개발 2026-10-11, 검수: HH_HaloGoldTrim read as a dull mustard; 2D house-07 gold = bright yellow
-- with white glints). Run with Studio MCP execute_luau in an EDIT-mode test place (UiSandbox; never the main Studio), then photograph.
-- Replace "__MODE__" with build | clean. Uses only ALREADY UPLOADED maps (no upload needed):
--   colour/normal  HaloTile_Halo_GoldTrim_color 94913368757526 / _normal 131597673772642
--   metal 1.0  91394364117916 (old), metal 0.7  139091750772198
--   rough 0.25 82910627301523 (old), rough 0.15 109029776386025, rough 0.35 128833041727597
-- Columns (left to right): BASE = the current look (metal 0.7 / rough 0.35 / 255,175,25) ; A = metal 1 / rough 0.25 / 255,195,40 ;
-- B = metal 1 / rough 0.15 / 255,205,50 ; C = metal 0.7 / rough 0.15 / 255,205,40. Rows = disc, sphere, bar (like the first gold test).
-- Wall = HH_HaloMarbleBlock_Cream with wall Color (255,244,222), the same wall as house 07.
local MODE = "__MODE__"
local MS = game:GetService("MaterialService")
local ROOT_NAME = "GoldCandTest"

local old = workspace:FindFirstChild(ROOT_NAME)
if old then old:Destroy() end
for _, mv in ipairs(MS:GetChildren()) do
	if mv:IsA("MaterialVariant") and string.sub(mv.Name, 1, 12) == "HH_GoldCand_" then mv:Destroy() end
end
if MODE == "clean" then
	print("gold candidates removed")
	return
end

local COLOR = "rbxassetid://94913368757526"
local NORMAL = "rbxassetid://131597673772642"
local CANDS = {
	{ key = "BASE", label = "BASE metal 0.7 / rough 0.35 / 255,175,25", metal = "rbxassetid://139091750772198", rough = "rbxassetid://128833041727597", col = Color3.fromRGB(255, 175, 25) },
	{ key = "A", label = "A metal 1 / rough 0.25 / 255,195,40", metal = "rbxassetid://91394364117916", rough = "rbxassetid://82910627301523", col = Color3.fromRGB(255, 195, 40) },
	{ key = "B", label = "B metal 1 / rough 0.15 / 255,205,50", metal = "rbxassetid://91394364117916", rough = "rbxassetid://109029776386025", col = Color3.fromRGB(255, 205, 50) },
	{ key = "C", label = "C metal 0.7 / rough 0.15 / 255,205,40", metal = "rbxassetid://139091750772198", rough = "rbxassetid://109029776386025", col = Color3.fromRGB(255, 205, 40) },
}

for _, c in ipairs(CANDS) do
	local mv = Instance.new("MaterialVariant")
	mv.Name = "HH_GoldCand_" .. c.key
	mv.BaseMaterial = Enum.Material.Metal
	mv.StudsPerTile = 4
	mv.ColorMap = COLOR
	mv.NormalMap = NORMAL
	mv.MetalnessMap = c.metal
	mv.RoughnessMap = c.rough
	mv.Parent = MS
end

local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = workspace

local ORIGIN = Vector3.new(0, 300, 0) -- high above the map so nothing else is in the shot
local W, H = 64, 24
local wall = Instance.new("Part")
wall.Name = "Wall"
wall.Anchored = true
wall.Size = Vector3.new(W, H, 2)
wall.Position = ORIGIN
wall.Material = Enum.Material.Marble
wall.MaterialVariant = "HH_HaloMarbleBlock_Cream"
wall.Color = Color3.fromRGB(255, 244, 222)
wall.Parent = root

-- the wall faces -Z (front surface at ORIGIN.Z - 1); items sit on it, camera looks along +Z from z = ORIGIN.Z - 40
local frontZ = ORIGIN.Z - 1
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.Adornee = wall
sg.CanvasSize = Vector2.new(1024 * #CANDS, 400)
sg.Parent = wall
local colW = W / #CANDS
for i, c in ipairs(CANDS) do
	local cx = ORIGIN.X - W / 2 + colW * (i - 0.5)
	local function mk(name, shape, size, pos)
		local p = Instance.new("Part")
		p.Name = c.key .. "_" .. name
		p.Anchored = true
		p.Shape = shape
		p.Size = size
		p.CFrame = pos
		p.Material = Enum.Material.Metal
		p.MaterialVariant = "HH_GoldCand_" .. c.key
		p.Color = c.col
		p.CastShadow = true
		p.Parent = root
		return p
	end
	-- disc (cylinder lying on the wall: axis along Z)
	mk("Disc", Enum.PartType.Cylinder, Vector3.new(1, 6, 6), CFrame.new(cx - 3, ORIGIN.Y + 5, frontZ - 0.5) * CFrame.Angles(0, math.rad(90), 0))
	mk("Ball", Enum.PartType.Ball, Vector3.new(4, 4, 4), CFrame.new(cx + 3, ORIGIN.Y + 5, frontZ - 2))
	mk("Bar", Enum.PartType.Block, Vector3.new(12, 1.4, 1), CFrame.new(cx, ORIGIN.Y - 1.5, frontZ - 0.5))
	-- a taller vertical trim piece (like the gold edge bands of house 07)
	mk("Post", Enum.PartType.Block, Vector3.new(1.4, 8, 1), CFrame.new(cx + 5.5, ORIGIN.Y - 6, frontZ - 0.5))
	local tl = Instance.new("TextLabel")
	tl.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
	tl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.Text = c.label
	tl.Size = UDim2.fromOffset(980, 90)
	tl.Position = UDim2.fromOffset(1024 * (i - 1) + 22, 10)
	tl.Parent = sg
end
print("gold candidates built at", ORIGIN, "camera: look at", ORIGIN, "from", ORIGIN + Vector3.new(0, 0, -45))
