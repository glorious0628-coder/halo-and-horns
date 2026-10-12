-- goose_square.luau (이미지 개발 2026-10-12, SPEC A23-141, 디자인 검수 계약 docs/design/goose_square_contract_2026-10-12.md)
-- Builds workspace.GooseSquare: the space skeleton of the Goose Square (a plaza far outside the map where only players who press
-- Join stand during the golden-egg round). Skeleton only: no trees / flags / lights (those come with the Crossroads dressing).
-- Run with Studio MCP execute_luau in an EDIT-mode place (UiSandbox for tests; the main Studio only through 메인 반영 1 with ALLOW_MAIN = true).
-- Generated/driven by tools/goose_square.py (py tools/goose_square.py --mode apply|remove|survey [--center x,y,z]); __MODE__ / __CX__ __CY__ __CZ__ are replaced there.
--
-- Layout (local x = east, z = south; north = -z; floor top = CENTER.y):
--   Floor        rounded rectangle 110 x 90 (corner radius 16), 4 thick, SmoothPlastic cream, tag WalkGround (Config.Ground.Tag)
--   Rim          low cream stone border (3 high, 3 wide) round the floor (a ledge to sit on)
--   Wall_*       4 invisible walls 30 high just outside the rim (CanCollide, Transparency 1) + SafetyPlate under the floor
--   GooseSpot    round low dais, diameter 16, in the middle (+ GooseSpotRing gold ring under it)
--   Nest         north end (z = -37): Halo light nest spot (simple cup + blue floor ring NestRing)
--   Cart         south end (z = +37): Horns cart spot (simple cart + red floor ring CartRing)
--   SpawnHalo / SpawnHorns   faction arrival circles radius 6 in front of Nest / Cart (z = -24 / +24), nothing standing in them
--   SpawnNeutral   Artisan (Neutral) arrival circle radius 6, west of the goose spot (x = -22, z = 0)
-- Colours: floor cream (240,232,215), gold band (255,168,36) (HH_HaloGoldTrim variant when the place has it), no rays / stripes from the centre.
-- Model attributes (for the map / quest markers): NestPos, CartPos, GooseSpotPos, SpawnHaloPos, SpawnHornsPos (Vector3, world), Skeleton = true.
local MODE = "__MODE__"
local ALLOW_MAIN = false -- 메인 반영 1: true only when running in the main place
if (game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil")) and not ALLOW_MAIN then
	error("WRONG STUDIO: main (ALLOW_MAIN is false)")
end
if game:GetService("RunService"):IsRunning() then error("Edit mode only") end

local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local CENTER = Vector3.new(__CX__, __CY__, __CZ__) -- plaza middle at floor-top height
local NAME = "GooseSquare"
local W, D, R = 110, 90, 16 -- floor width (x), depth (z), corner radius
local FLOOR_T = 4
local RIM_H, RIM_W = 3, 3
local WALL_H, WALL_T = 30, 2
local CREAM = Color3.fromRGB(240, 232, 215)
local RIM_COL = Color3.fromRGB(232, 222, 204)
local GOLD = Color3.fromRGB(255, 168, 36)
local HALO_BLUE = Color3.fromRGB(104, 170, 240)
local HORNS_RED = Color3.fromRGB(186, 52, 62)
local TAG = "WalkGround"

local old = workspace:FindFirstChild(NAME)
if MODE == "remove" or MODE == "apply" then
	if old then old:Destroy() end
	if MODE == "remove" then return "GooseSquare removed" end
elseif MODE == "survey" then
	if not old then return "no workspace.GooseSquare" end
	local n, tagged, names = 0, 0, {}
	for _, d in old:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			if CS:HasTag(d, TAG) then tagged += 1 end
			table.insert(names, d.Name)
		end
	end
	return string.format("GooseSquare: %d parts, %d with tag %s, floor at %s", n, tagged, TAG, tostring(old:GetPivot().Position)) .. "\n" .. table.concat(names, ", ")
end

local model = Instance.new("Model")
model.Name = NAME
model:SetAttribute("Skeleton", true)
model:SetAttribute("Maker", "이미지 개발 2026-10-12 tools/worldkit/goose_square.luau")
model.Parent = workspace -- CSG (UnionAsync / SubtractAsync) needs the parts inside the DataModel

local function part(name, shape, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Color = color
	p.Parent = model
	return p
end
local BLOCK, CYL = Enum.PartType.Block, Enum.PartType.Cylinder
-- a vertical cylinder (Roblox cylinders lie along x) of diameter dia and height h, centre c
local function disc(name, dia, h, c, color, mat)
	return part(name, CYL, Vector3.new(h, dia, dia), CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2), color, mat)
end
local function goldify(p)
	if MS:FindFirstChild("HH_HaloGoldTrim") then
		p.Material = Enum.Material.Metal
		p.MaterialVariant = "HH_HaloGoldTrim"
	end
	p.Color = GOLD
end

-- rounded rectangle slab (width w, depth d, corner radius r, height h, top at y) as one CSG union (no coplanar overlaps left)
local function slab(name, w, d, r, h, topY, color)
	local cy = topY - h / 2
	local parts = {}
	local function add(p) table.insert(parts, p) end
	local a = part(name .. "_a", BLOCK, Vector3.new(w - 2 * r, h, d), CFrame.new(CENTER.X, cy, CENTER.Z), color)
	local b = part(name .. "_b", BLOCK, Vector3.new(w, h, d - 2 * r), CFrame.new(CENTER.X, cy, CENTER.Z), color)
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			add(disc(name .. "_c", 2 * r, h, Vector3.new(CENTER.X + sx * (w / 2 - r), cy, CENTER.Z + sz * (d / 2 - r)), color))
		end
	end
	local ok, u = pcall(function() return a:UnionAsync({ b, table.unpack(parts) }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic) end)
	for _, p in parts do p:Destroy() end
	b:Destroy()
	a:Destroy()
	if ok and u then
		u.Name = name
		u.Anchored = true
		u.Material = Enum.Material.SmoothPlastic
		u.Color = color
		u.UsePartColor = true
		u.Parent = model
		return u
	end
	warn("goose_square: union failed (" .. tostring(u) .. "): plain block used for " .. name)
	return part(name, BLOCK, Vector3.new(w, h, d), CFrame.new(CENTER.X, cy, CENTER.Z), color)
end

-- floor (walkable) -----------------------------------------------------------------------------------------------------------
local floor = slab("Floor", W, D, R, FLOOR_T, CENTER.Y, CREAM)
CS:AddTag(floor, TAG)
model.PrimaryPart = floor

-- rim = outer slab minus inner slab (a ledge), sits on the floor edge
do
	local outer = slab("Rim", W, D, R, RIM_H, CENTER.Y + RIM_H, RIM_COL)
	local inner = slab("RimHole", W - 2 * RIM_W, D - 2 * RIM_W, math.max(R - RIM_W, 1), RIM_H + 2, CENTER.Y + RIM_H + 1, RIM_COL)
	local ok, r = pcall(function() return outer:SubtractAsync({ inner }, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic) end)
	inner:Destroy()
	if ok and r then
		r.Name = "Rim"
		r.Anchored = true
		r.Material = Enum.Material.SmoothPlastic
		r.Color = RIM_COL
		r.UsePartColor = true
		r.Parent = model
		outer:Destroy()
	else
		warn("goose_square: rim subtract failed (" .. tostring(r) .. "): the rim stays a solid slab")
		outer.Name = "Rim"
	end
end
-- thin gold band on the rim top (4 straight pieces on the long edges + ends; the rounded corners keep plain cream)
do
	local y = CENTER.Y + RIM_H + 0.05
	local t = 0.6
	local straightX = W - 2 * R
	local straightZ = D - 2 * R
	for sz = -1, 1, 2 do
		goldify(part("GoldBand_Z" .. (sz < 0 and "N" or "S"), BLOCK, Vector3.new(straightX, 0.1, t), CFrame.new(CENTER.X, y, CENTER.Z + sz * (D / 2 - RIM_W / 2)), GOLD))
	end
	for sx = -1, 1, 2 do
		goldify(part("GoldBand_X" .. (sx < 0 and "W" or "E"), BLOCK, Vector3.new(t, 0.1, straightZ), CFrame.new(CENTER.X + sx * (W / 2 - RIM_W / 2), y, CENTER.Z), GOLD))
	end
end

-- invisible walls (outside the rim) + safety plate under the floor ------------------------------------------------------------
do
	local midY = CENTER.Y - FLOOR_T + (WALL_H + FLOOR_T) / 2
	local hh = WALL_H + FLOOR_T
	local function wall(name, size, c)
		local p = part(name, BLOCK, size, CFrame.new(c), Color3.new(1, 1, 1))
		p.Transparency = 1
		p.CanCollide = true
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
	end
	local ox, oz = W / 2 + WALL_T / 2, D / 2 + WALL_T / 2
	wall("Wall_E", Vector3.new(WALL_T, hh, D + 2 * WALL_T), Vector3.new(CENTER.X + ox, midY, CENTER.Z))
	wall("Wall_W", Vector3.new(WALL_T, hh, D + 2 * WALL_T), Vector3.new(CENTER.X - ox, midY, CENTER.Z))
	wall("Wall_N", Vector3.new(W, hh, WALL_T), Vector3.new(CENTER.X, midY, CENTER.Z - oz))
	wall("Wall_S", Vector3.new(W, hh, WALL_T), Vector3.new(CENTER.X, midY, CENTER.Z + oz))
	local sp = part("SafetyPlate", BLOCK, Vector3.new(W + 20, 2, D + 20), CFrame.new(CENTER.X, CENTER.Y - FLOOR_T - 10, CENTER.Z), Color3.new(1, 1, 1))
	sp.Transparency = 1
	sp.CanQuery = false
	sp.CastShadow = false
end

-- goose spot (middle): gold ring under a low cream dais ------------------------------------------------------------------------
local gs = disc("GooseSpot", 16, 0.8, Vector3.new(CENTER.X, CENTER.Y + 0.4, CENTER.Z), CREAM)
CS:AddTag(gs, TAG)
goldify(disc("GooseSpotRing", 18, 0.3, Vector3.new(CENTER.X, CENTER.Y + 0.15, CENTER.Z), GOLD))

-- Nest (north end, Halo) and Cart (south end, Horns): simple marker shapes + a floor ring each -----------------------------------
local NEST_Z, CART_Z = -37, 37
local nestC = Vector3.new(CENTER.X, CENTER.Y, CENTER.Z + NEST_Z)
local cartC = Vector3.new(CENTER.X, CENTER.Y, CENTER.Z + CART_Z)
do
	local ring = disc("NestRing", 14, 0.12, nestC + Vector3.new(0, 0.06, 0), HALO_BLUE)
	ring.CanCollide = false
	local base = disc("Nest", 6, 1.2, nestC + Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 244, 222))
	local top = disc("NestCup", 3.6, 0.5, nestC + Vector3.new(0, 1.45, 0), GOLD)
	goldify(top)
	local ring2 = disc("CartRing", 14, 0.12, cartC + Vector3.new(0, 0.06, 0), HORNS_RED)
	ring2.CanCollide = false
	-- Horns cart: a low dark body on two wheels
	local body = part("Cart", BLOCK, Vector3.new(6, 2, 4), CFrame.new(cartC + Vector3.new(0, 1.9, 0)), Color3.fromRGB(110, 50, 54))
	for sx = -1, 1, 2 do
		local wheel = disc("CartWheel", 2.4, 0.5, Vector3.new(0, 0, 0), Color3.fromRGB(58, 40, 40))
		wheel.CFrame = CFrame.new(cartC + Vector3.new(sx * 3.3, 1.2, 0)) * CFrame.Angles(0, 0, 0)
		wheel.Size = Vector3.new(0.5, 2.4, 2.4) -- axis along x (the Roblox cylinder axis) = a wheel seen from the front
		wheel.CanCollide = false
	end
	body.CanCollide = true
end
local function spawnCircle(name, z, tint, dx)
	local p = disc(name, 12, 0.1, Vector3.new(CENTER.X + (dx or 0), CENTER.Y + 0.05, CENTER.Z + z), tint)
	p.Transparency = 0.7
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end
spawnCircle("SpawnHalo", NEST_Z + 13, HALO_BLUE)
spawnCircle("SpawnHorns", CART_Z - 13, HORNS_RED)
spawnCircle("SpawnNeutral", 0, Color3.fromRGB(235, 200, 120), -22) -- Artisan (Neutral) arrival: west of the goose spot, radius 6 free

model:SetAttribute("NestPos", nestC)
model:SetAttribute("CartPos", cartC)
model:SetAttribute("GooseSpotPos", Vector3.new(CENTER.X, CENTER.Y, CENTER.Z))
model:SetAttribute("SpawnHaloPos", Vector3.new(CENTER.X, CENTER.Y, CENTER.Z + NEST_Z + 13))
model:SetAttribute("SpawnHornsPos", Vector3.new(CENTER.X, CENTER.Y, CENTER.Z + CART_Z - 13))
model:SetAttribute("SpawnNeutralPos", Vector3.new(CENTER.X - 22, CENTER.Y, CENTER.Z))
model.Parent = workspace

local n, tagged = 0, 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
		if CS:HasTag(d, TAG) then tagged += 1 end
	end
end
return string.format("GooseSquare built at %s: %d parts, %d walkable (tag %s)", tostring(CENTER), n, tagged, TAG)
