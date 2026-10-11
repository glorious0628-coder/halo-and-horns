-- marble_smooth_test (이미지 개발 2026-10-11, 검수: smooth cream marble MV for small Halo-town props).
-- Run with Studio MCP execute_luau in an EDIT-mode PRACTICE Studio (UiSandbox; never the main Studio), then photograph with tools/marble_smooth_capture.py.
-- Replace "__MODE__" with build | clean. Makes the MaterialVariant HH_HaloMarbleSmooth_Cream (maps already uploaded, art/ui/asset_ids.json
-- Halo_MarbleSmoothCream_color / _rough; the flat normal 131597673772642 and the all-zero metal 87489921567476 are reused), then two
-- boards (SUN faces the sun, SHADE away) far above the map with three columns, left to right:
--   PLAIN  = Marble, no variant (what prop_kit.py uses now)       BLOCK = HH_HaloMarbleBlock_Cream (1.5-cell joints)       SMOOTH = HH_HaloMarbleSmooth_Cream
-- Each column: a back panel (14x14), a lamp post (cylinder 1.2 x 7), bench legs (box 1.4 x 2.2 x 1.4 + a seat slab) and a planter body (cylinder 3.4 x 2.2).
-- Part Color (255,244,222) like the props.
local MODE = "__MODE__"
local MS = game:GetService("MaterialService")
local ROOT_NAME = "MarbleSmoothTest"
local VAR = "HH_HaloMarbleSmooth_Cream"
local STUDS = 8

local old = workspace:FindFirstChild(ROOT_NAME)
if old then old:Destroy() end
if MODE == "clean" then
	local mv = MS:FindFirstChild(VAR)
	if mv then mv:Destroy() end
	print("marble smooth test removed (variant too)")
	return
end

local mv = MS:FindFirstChild(VAR)
if not (mv and mv:IsA("MaterialVariant")) then
	mv = Instance.new("MaterialVariant")
	mv.Name = VAR
end
mv.BaseMaterial = Enum.Material.Marble
mv.MaterialPattern = Enum.MaterialPattern.Regular
mv.StudsPerTile = STUDS
mv.ColorMap = "rbxassetid://140510838680155"
mv.NormalMap = "rbxassetid://131597673772642"
mv.RoughnessMap = "rbxassetid://76093268063395"
mv.MetalnessMap = "rbxassetid://87489921567476"
mv.Parent = MS

local COLS = {
	{ key = "PLAIN", label = "PLAIN (no variant, now)", variant = "" },
	{ key = "BLOCK", label = "BLOCK HH_HaloMarbleBlock_Cream", variant = "HH_HaloMarbleBlock_Cream" },
	{ key = "SMOOTH", label = "SMOOTH " .. VAR .. " (" .. STUDS .. " studs/tile)", variant = VAR },
}
local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = workspace
local sunDir = game:GetService("Lighting"):GetSunDirection()
local horiz = Vector3.new(sunDir.X, 0, sunDir.Z)
if horiz.Magnitude < 0.05 then horiz = Vector3.new(0, 0, -1) end
horiz = horiz.Unit
local BOARDS = {
	{ name = "SUN", origin = Vector3.new(0, 1500, 0), look = horiz },
	{ name = "SHADE", origin = Vector3.new(0, 1500, 300), look = -horiz },
}
local W = 16 * #COLS
local colW = W / #COLS
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
		p.Material = Enum.Material.Marble
		p.MaterialVariant = c and c.variant or ""
		p.Color = Color3.fromRGB(255, 244, 222)
		p.Parent = root
		return p
	end
	-- dark back wall so the stone stands out (plain colour, no variant)
	local wall = Instance.new("Part")
	wall.Name = b.name .. "_Wall"
	wall.Anchored = true
	wall.Size = Vector3.new(W, 24, 2)
	wall.CFrame = base
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = Color3.fromRGB(90, 110, 140)
	wall.Parent = root
	local cols = {}
	for i, c in ipairs(COLS) do
		local cx = -W / 2 + colW * (i - 0.5)
		put(c.key .. "_Panel", Enum.PartType.Block, Vector3.new(14, 14, 0.6), CFrame.new(cx, 3, -1.3), c)
		put(c.key .. "_Post", Enum.PartType.Cylinder, Vector3.new(7, 1.2, 1.2), CFrame.new(cx - 4.5, 0, -3) * CFrame.Angles(0, 0, math.rad(90)), c)
		put(c.key .. "_LegA", Enum.PartType.Block, Vector3.new(1.4, 2.2, 1.4), CFrame.new(cx - 0.2, -4.5, -3.5), c)
		put(c.key .. "_LegB", Enum.PartType.Block, Vector3.new(1.4, 2.2, 1.4), CFrame.new(cx + 3.6, -4.5, -3.5), c)
		put(c.key .. "_Seat", Enum.PartType.Block, Vector3.new(5.6, 0.7, 2.2), CFrame.new(cx + 1.7, -3.1, -3.5), c)
		put(c.key .. "_Planter", Enum.PartType.Cylinder, Vector3.new(2.2, 3.4, 3.4), CFrame.new(cx + 3.6, 0.2, -3.2) * CFrame.Angles(0, 0, math.rad(90)), c)
		local sg = wall:FindFirstChildOfClass("SurfaceGui")
		if not sg then
			sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Front
			sg.CanvasSize = Vector2.new(1024 * #COLS, 400)
			sg.Parent = wall
		end
		local tl = Instance.new("TextLabel")
		tl.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
		tl.TextColor3 = Color3.fromRGB(255, 255, 255)
		tl.Font = Enum.Font.GothamBold
		tl.TextScaled = true
		tl.Text = c.label
		tl.Size = UDim2.fromOffset(980, 90)
		tl.Position = UDim2.fromOffset(1024 * (i - 1) + 22, 10)
		tl.Parent = sg
		local camPos = (base * CFrame.new(cx, -1.5, -11)).Position
		local lookAt = (base * CFrame.new(cx, -1.5, 0)).Position
		table.insert(cols, { key = c.key, cam = { camPos.X, camPos.Y, camPos.Z }, look = { lookAt.X, lookAt.Y, lookAt.Z } })
	end
	info[b.name] = cols
end
print("marble smooth test built; sun dir", sunDir)
return game:GetService("HttpService"):JSONEncode(info)
