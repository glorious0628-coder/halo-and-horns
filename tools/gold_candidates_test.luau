-- Gold trim candidates side by side (이미지 개발 2026-10-11, 검수: HH_HaloGoldTrim read as a dull mustard; 2D house-07 gold = bright yellow
-- with white glints). Run with Studio MCP execute_luau in an EDIT-mode test place (UiSandbox; never the main Studio), then photograph.
-- Replace "__MODE__" with build | clean. Uses only ALREADY UPLOADED maps (no upload needed):
--   colour/normal  HaloTile_Halo_GoldTrim_color 94913368757526 / _normal 131597673772642
--   metal 1.0  91394364117916 (old), metal 0.7  139091750772198
--   rough 0.25 82910627301523 (old), rough 0.15 109029776386025, rough 0.35 128833041727597
-- Columns (left to right): BASE = the current look (metal 0.7 / rough 0.35 / 255,175,25) ; A = metal 1 / rough 0.25 / 255,195,40 ;
-- B = metal 1 / rough 0.15 / 255,205,50 ; C = metal 0.7 / rough 0.15 / 255,205,40. Rows = disc, sphere, bar (like the first gold test).
-- Two boards (SUN faces the sun, SHADE away). Wall = HH_HaloMarbleBlock_Cream with wall Color (255,244,222), the same wall as house 07.
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
-- Round 2 (검수 10/11): D/E/F/G/H. G (metal 0.3) needs a flat 0.3 metal map that is NOT uploaded yet -> left out until 검수 OKs the upload.
-- plastic = true: SmoothPlastic with the plain part colour (the "painted yellow" baseline, no variant).
local MET50 = "rbxassetid://137160255192059"
local MET70 = "rbxassetid://139091750772198"
local R15 = "rbxassetid://109029776386025"
local R35 = "rbxassetid://128833041727597"
local CANDS = {
	{ key = "BASE", label = "BASE metal 0.7 / rough 0.35 / 255,175,25", metal = MET70, rough = R35, col = Color3.fromRGB(255, 175, 25) },
	{ key = "D", label = "D metal 0.5 / rough 0.15 / 255,205,50", metal = MET50, rough = R15, col = Color3.fromRGB(255, 205, 50) },
	{ key = "E", label = "E metal 0.5 / rough 0.15 / 255,215,70", metal = MET50, rough = R15, col = Color3.fromRGB(255, 215, 70) },
	{ key = "F", label = "F metal 0.7 / rough 0.15 / 255,215,70", metal = MET70, rough = R15, col = Color3.fromRGB(255, 215, 70) },
	{ key = "H", label = "H plastic / 255,205,60", plastic = true, col = Color3.fromRGB(255, 205, 60) },
}

for _, c in ipairs(CANDS) do
	if c.plastic then continue end
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

-- two boards far above the map: SUN faces the sun (horizontal sun direction), SHADE faces away. Front = local -Z.
local sunDir = game:GetService("Lighting"):GetSunDirection()
local horiz = Vector3.new(sunDir.X, 0, sunDir.Z)
if horiz.Magnitude < 0.05 then horiz = Vector3.new(0, 0, -1) end
horiz = horiz.Unit
local BOARDS = {
	{ name = "SUN", origin = Vector3.new(0, 1500, 0), look = horiz },
	{ name = "SHADE", origin = Vector3.new(0, 1500, 300), look = -horiz },
}
local W, H = 16 * #CANDS, 24
local colW = W / #CANDS
local info = {}
for _, b in ipairs(BOARDS) do
	local base = CFrame.lookAt(b.origin, b.origin + b.look)
	local function put(name, shape, size, localCf, c)
		local p = Instance.new("Part")
		p.Name = b.name .. "_" .. name
		p.Anchored = true
		p.Shape = shape
		p.Size = size
		p.CFrame = base * localCf
		if c then
			if c.plastic then
				p.Material = Enum.Material.SmoothPlastic
			else
				p.Material = Enum.Material.Metal
				p.MaterialVariant = "HH_GoldCand_" .. c.key
			end
			p.Color = c.col
		else
			p.Material = Enum.Material.Marble
			p.MaterialVariant = "HH_HaloMarbleBlock_Cream"
			p.Color = Color3.fromRGB(255, 244, 222)
		end
		p.Parent = root
		return p
	end
	local wall = put("Wall", Enum.PartType.Block, Vector3.new(W, H, 2), CFrame.new(), nil)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(1024 * #CANDS, 400)
	sg.Parent = wall
	local cols = {}
	for i, c in ipairs(CANDS) do
		local cx = -W / 2 + colW * (i - 0.5)
		-- items stand out of the wall front (local z -1 .. -3)
		put(c.key .. "_Disc", Enum.PartType.Cylinder, Vector3.new(1, 6, 6), CFrame.new(cx - 3, 2, -1.5) * CFrame.Angles(0, math.rad(90), 0), c)
		put(c.key .. "_Ball", Enum.PartType.Ball, Vector3.new(4, 4, 4), CFrame.new(cx + 3.2, 2, -3), c)
		put(c.key .. "_Bar", Enum.PartType.Block, Vector3.new(12, 1.4, 1), CFrame.new(cx, -3.5, -1.5), c)
		put(c.key .. "_Post", Enum.PartType.Block, Vector3.new(1.4, 8, 1), CFrame.new(cx + 5.5, -8, -1.5), c)
		local tl = Instance.new("TextLabel")
		tl.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
		tl.TextColor3 = Color3.fromRGB(255, 255, 255)
		tl.Font = Enum.Font.GothamBold
		tl.TextScaled = true
		tl.Text = c.label
		tl.Size = UDim2.fromOffset(980, 90)
		tl.Position = UDim2.fromOffset(1024 * (i - 1) + 22, 10)
		tl.Parent = sg
		local camPos = (base * CFrame.new(cx, -2, -16)).Position
		local lookAt = (base * CFrame.new(cx, -2, 0)).Position
		table.insert(cols, { key = c.key, cam = { camPos.X, camPos.Y, camPos.Z }, look = { lookAt.X, lookAt.Y, lookAt.Z } })
	end
	info[b.name] = cols
end
print("gold candidates built; sun dir", sunDir)
return game:GetService("HttpService"):JSONEncode(info)
