-- MapBuilder.luau : reuses (or minimally builds) workspace.Map: zone floors, walls, gates, pads, altar, board, goose perch.
--
-- Build() is also run from the Studio command bar in EDIT mode to pre-bake the map:
--     require(game.ServerScriptService.MapBuilder).Build()
-- so it never touches S, never yields and is idempotent: every named element is looked up first and only the missing
-- pieces are created; existing functional pieces get their functional bits re-applied (pad TravelTo, AltarPrompt,
-- BoardGui.BoardText, zone floor ZoneId + invisibility, the two-line gate signs, the pad position + sign text from
-- Config.Map.Pads (CR-M22), the bounds walls' bottom below the sea floor (CR-L17)).
--
-- The real world is the Studio-saved place built by tools/preview_map.lua (addendum A8/A10/A11: Terrain landscape,
-- sea, rivers, ridges, bridges, sky crown). A reused map is adopted as-is: the four "Wall" parts get the contract names
-- (matched by orientation/side), its gate billboards get the spec text, and NOTHING is added to its ground or decor
-- (A10-V3-1: never a ground plate over the Bounds; it would cover the sea/rivers and z-fight the Terrain land).
-- A11-R3: with no workspace.Map at all, Build() warns and builds only minimal flat ground (Config.Map.Lands plates +
-- bridge decks named "Bridge_*" in Decor) plus the functional pieces; no Terrain, no decorative set.
-- A11-R1: zone floor parts are contract markers only: invisible, CanCollide/CanQuery/CanTouch false (build and reuse).
-- Lighting is never touched here: WarService owns it (addendum A9-3: no Atmosphere, no per-zone ColorCorrection).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local MapBuilder = {}

local TAG = "MapBuilder"
local FOLDER_NAMES = { "Ground", "Zones", "Walls", "Gates", "Pads", "Landmarks", "Decor", "NPCs" }
local WALL_NAMES = { "Wall_MinX", "Wall_MaxX", "Wall_MinZ", "Wall_MaxZ" }
local WALL_THICKNESS = 2
local WALL_ADOPT_LENGTH = 100 -- a pre-baked part at least this long in the Walls folder is a bounds wall
-- CR-L17: walls reach 20 studs below the water surface (under the sea floor) so nobody swims under them
local WALL_BOTTOM = (Config.Map.WaterTop or 0) - 20
local GATE_HALF_SPAN = 10 -- pillar centers 20 apart (17-stud passage)
local EXTREME_MIN_LEVEL = 25 -- PvP zones from this level use the "extreme" danger color
local SIGN_MAX_DISTANCE = 150
-- A23-36 (user 2026-10-06): no big 3D place text; a pad keeps only a small label seen up close (like shop names)
local PAD_SIGN = { Width = 190, Height = 32, MaxDistance = 40, OffsetY = 3,
	-- the woods and ruins pads stand in one line seen from the Crossroads walk: the farther label rides higher so the
	-- two never overlap (검수 2026-10-07, play-view photos)
	Lift = { SkeletonRuins = 3.6 } }
local SHOP_SIGN_MAX_DISTANCE = 50 -- shop / landmark name labels (the sky crown image has no TextLabel and stays)
-- the goose nest label sits beside the Crossroads walk: small, low and only up close, so it never floats behind the
-- HUD quest rows (검수 2026-10-07, play-view photo)
local PERCH_SIGN = { Width = 190, Height = 32, MaxDistance = 30, OffsetY = 3 }
local MAX_LIGHTS = 40 -- whole map
local MAX_LIGHT_RANGE = 40
local MAX_LIGHT_BRIGHTNESS = 2
local PERCH_DIAMETER = 10
local PERCH_HEIGHT = 1
local GROUND_THICKNESS = 4 -- minimal ground plates: top at Y = 0
local BRIDGE_WIDTH = 18 -- default deck width when Config.Map.Bridges has no Width
local ALTAR_PROMPT_KEY = Enum.KeyCode.E -- Roblox-standard interact key; the skill is Q only (2026-10-06 playtest)

local RGB = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)

local DANGER = { Safe = RGB(80, 220, 120), PvP = RGB(255, 150, 40), Extreme = RGB(255, 60, 60) }
local GATE_STYLE = { SlimeMeadow = "Meadow", GoblinWoods = "Goblin", SkeletonRuins = "Ruins", HaloTown = "Halo", HornsTown = "Horns" }

local S = nil -- registry (stored by Init; Build/Rebuild never use it)

------------------------------------------------------------------ instance helpers
-- ctx = { parts = BaseParts created, pieces = missing named pieces built, lights = PointLights created }
local function newCtx()
	return { parts = 0, pieces = 0, lights = 0 }
end

-- every map part: anchored, locked, SmoothPlastic unless told otherwise, Shape applied before Size, parented last;
-- small (< 4 studs) and Neon parts cast no shadow
local function part(ctx, props, parent, className)
	local p = Instance.new(className or "Part")
	p.Anchored = true
	p.Locked = true
	p.Material = SP
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape ~= nil then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			p[k] = v
		end
	end
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) < 4 or p.Material == NEON then
		p.CastShadow = false
	end
	p.Parent = parent
	ctx.parts += 1
	return p
end

-- small decoration: no collision, no queries, no touches
local function prop(ctx, props, parent, className)
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(ctx, props, parent, className)
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	if parent then m.Parent = parent end
	return m
end

local function light(ctx, p, color, range, brightness)
	if ctx.lights >= MAX_LIGHTS then return nil end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(range or 16, MAX_LIGHT_RANGE)
	l.Brightness = math.min(brightness or 1.5, MAX_LIGHT_BRIGHTNESS)
	l.Shadows = false
	l.Parent = p
	ctx.lights += 1
	return l
end

local function billboard(adornee, name, text, offsetY, color, width, maxDist, height)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromOffset(width or 260, height or 46)
	bb.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = maxDist or SIGN_MAX_DISTANCE
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.RichText = true
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color or WHITE
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = t
	t.Parent = bb
	bb.Parent = adornee
	return bb
end

-- upright cylinder: props.Size = (diameter, height, diameter), props.Position = center
local function cyl(ctx, props, parent)
	local d, h = props.Size.X, props.Size.Y
	props.Size = Vector3.new(h, d, d)
	props.CFrame = CFrame.new(props.Position) * CFrame.Angles(0, 0, math.rad(90))
	props.Position = nil
	props.Shape = Enum.PartType.Cylinder
	return part(ctx, props, parent)
end

local function disc(ctx, pos, diameter, thickness, color, parent, material)
	return cyl(ctx, {
		Name = "Disc", Size = Vector3.new(diameter, thickness, diameter), Position = pos,
		Color = color, Material = material or SP, CanCollide = false,
	}, parent)
end

-- horizontal ring of n block segments
local function ring(ctx, center, radius, n, size, color, parent, material)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		prop(ctx, {
			Name = "RingSeg", Size = size,
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)) * CFrame.Angles(0, -a, 0),
			Color = color, Material = material or NEON,
		}, parent)
	end
end

local function getChildFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then return f, false end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f, true
end

local function countParts(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

-- moves a wrong-class instance out of the way of a contract name (never destroys user content)
local function retire(inst, suffix)
	Util.Warn(TAG, inst:GetFullName() .. " has the wrong class (" .. inst.ClassName .. "); renamed and rebuilt")
	inst.Name = inst.Name .. suffix
end

------------------------------------------------------------------ text helpers
local function dangerColor(zone)
	if not zone.PvP then return DANGER.Safe end
	if zone.MinLevel >= EXTREME_MIN_LEVEL then return DANGER.Extreme end
	return DANGER.PvP
end

local function padLabel(zone)
	return "→ " .. zone.Name .. " (Lv " .. zone.MinLevel .. "+)"
end

------------------------------------------------------------------ ground / zones / walls
-- one flat plate, top at Y = 0
local function groundPlate(ctx, folder, name, minX, maxX, minZ, maxZ, color, material)
	if folder:FindFirstChild(name) or maxX <= minX or maxZ <= minZ then return end
	part(ctx, {
		Name = name,
		Size = Vector3.new(maxX - minX, GROUND_THICKNESS, maxZ - minZ),
		Position = Vector3.new((minX + maxX) / 2, -GROUND_THICKNESS / 2, (minZ + maxZ) / 2),
		Color = color, Material = material,
	}, folder)
	ctx.pieces += 1
end

-- deck (top at Y = 0.2, like tools/preview_map.lua) + two collidable rails, as Decor model "Bridge_<Name>"
-- (A11-R1: ground raycasts include workspace.Map.Decor children named "Bridge_*")
local function buildBridge(ctx, decor, entry)
	local name = "Bridge_" .. tostring(entry.Name)
	if decor:FindFirstChild(name) then return end
	local from, to = entry.From, entry.To
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
	from = Vector3.new(from.X, 0, from.Z)
	to = Vector3.new(to.X, 0, to.Z)
	local len = (to - from).Magnitude
	if len < 1 then return end
	local width = tonumber(entry.Width) or BRIDGE_WIDTH
	local cf = CFrame.lookAt((from + to) / 2, to)
	local br = model(name)
	local deck = part(ctx, {
		Name = "Deck", Size = Vector3.new(width, 1, len + 4), CFrame = cf * CFrame.new(0, -0.3, 0),
		Color = RGB(150, 110, 70), Material = Enum.Material.WoodPlanks,
	}, br)
	for _, side in { -1, 1 } do
		part(ctx, {
			Name = "Rail", Size = Vector3.new(0.8, 0.8, len + 4), CFrame = cf * CFrame.new(side * (width / 2 - 0.4), 2.8, 0),
			Color = RGB(110, 80, 50), Material = Enum.Material.Wood,
		}, br)
	end
	br.PrimaryPart = deck
	br.Parent = decor
	ctx.pieces += 1
end

local function terrainHasLand()
	local ok, cells = pcall(function()
		return workspace.Terrain:CountCells()
	end)
	return ok and type(cells) == "number" and cells > 0
end

-- A11-R3: only for a from-scratch build (no workspace.Map). Release builds come from the Studio-saved place (Terrain).
-- Config.Map.Lands plates + Config.Map.Bridges decks; an older Config without Lands gets one plate per zone rectangle.
-- Never one plate over the whole Bounds (A10-V3-1). When Terrain already exists (e.g. Rebuild() in the saved place)
-- the Terrain is the ground: no plates (they would z-fight its Y = 0 top), bridges only.
local function buildLandPlates(ctx, ground)
	local grass, grassColor = Enum.Material.Grass, RGB(106, 150, 72)
	local lands = Config.Map.Lands
	if type(lands) == "table" and #lands > 0 then
		for i, l in lands do
			local minX, maxX, minZ, maxZ = tonumber(l.MinX), tonumber(l.MaxX), tonumber(l.MinZ), tonumber(l.MaxZ)
			if minX and maxX and minZ and maxZ then
				groundPlate(ctx, ground, tostring(l.Name or ("Land" .. i)), minX, maxX, minZ, maxZ, grassColor, grass)
			end
		end
		return
	end
	for _, id in Config.ZoneOrder do
		local z = Config.Zones[id]
		if z then
			local hx, hz = z.Size.X / 2, z.Size.Z / 2
			groundPlate(ctx, ground, "Ground_" .. id, z.Center.X - hx, z.Center.X + hx, z.Center.Z - hz, z.Center.Z + hz,
				z.FloorColor or grassColor, z.FloorMaterial or grass)
		end
	end
end

local function buildMinimalGround(ctx, ground, decor)
	if not terrainHasLand() then
		buildLandPlates(ctx, ground)
	end
	if type(Config.Map.Bridges) == "table" then
		for _, entry in Config.Map.Bridges do
			if type(entry) == "table" then
				buildBridge(ctx, decor, entry)
			end
		end
	end
end

-- A11-R1: zone floors are contract markers only (players and monsters stand on Terrain / Map.Ground)
local function applyFloorMarker(floor)
	if not floor:IsA("BasePart") then return end
	floor.Transparency = 1
	floor.CanCollide = false
	floor.CanQuery = false
	floor.CanTouch = false
	floor.CastShadow = false
end

local function ensureZones(ctx, folder)
	for _, id in Config.ZoneOrder do
		local z = Config.Zones[id]
		if z then
			local floor = folder:FindFirstChild(id)
			local size = Vector3.new(z.Size.X, 1, z.Size.Z)
			local pos = Vector3.new(z.Center.X, -0.45, z.Center.Z) -- top at Y = 0.05
			if not floor then
				floor = part(ctx, {
					Name = id, Size = size, Position = pos, Color = z.FloorColor, Material = z.FloorMaterial,
				}, folder)
				ctx.pieces += 1
			elseif floor:IsA("BasePart") and ((floor.Size - size).Magnitude > 0.05 or (floor.Position - pos).Magnitude > 0.05) then
				-- map v2 (A23-53): a marker from an older layout follows the Config rectangle
				floor.Size, floor.CFrame = size, CFrame.new(pos)
			end
			applyFloorMarker(floor)
			floor:SetAttribute("ZoneId", id)
		end
	end
end

local function wallSpecs()
	local b = Config.Map.Bounds
	local h = Config.Map.WallHeight
	local t = WALL_THICKNESS
	local lenX = b.MaxX - b.MinX + 2 * t -- overlap the corners
	local lenZ = b.MaxZ - b.MinZ + 2 * t
	local cx, cz = (b.MinX + b.MaxX) / 2, (b.MinZ + b.MaxZ) / 2
	-- top at Y = WallHeight, bottom at WALL_BOTTOM (CR-L17)
	local sy, y = h - WALL_BOTTOM, (h + WALL_BOTTOM) / 2
	return {
		Wall_MinX = { Size = Vector3.new(t, sy, lenZ), Position = Vector3.new(b.MinX - t / 2, y, cz) },
		Wall_MaxX = { Size = Vector3.new(t, sy, lenZ), Position = Vector3.new(b.MaxX + t / 2, y, cz) },
		Wall_MinZ = { Size = Vector3.new(lenX, sy, t), Position = Vector3.new(cx, y, b.MinZ - t / 2) },
		Wall_MaxZ = { Size = Vector3.new(lenX, sy, t), Position = Vector3.new(cx, y, b.MaxZ + t / 2) },
	}
end

-- CR-L17: a reused upright wall whose bottom is above WALL_BOTTOM is stretched down to it (top, X/Z, rotation kept)
local function lowerWall(wall)
	if not wall:IsA("BasePart") then return end
	local cf, s = wall.CFrame, wall.Size
	if math.abs(cf.UpVector.Y) < 0.99 then return end -- tilted: Size.Y is not the height
	local top = cf.Position.Y + s.Y / 2
	local bottom = cf.Position.Y - s.Y / 2
	if bottom <= WALL_BOTTOM + 0.05 or top <= WALL_BOTTOM then return end
	wall.Size = Vector3.new(s.X, top - WALL_BOTTOM, s.Z)
	wall.CFrame = CFrame.new(cf.Position.X, (top + WALL_BOTTOM) / 2, cf.Position.Z) * cf.Rotation
end

-- which bounds edge a pre-baked wall stands on: long along X -> a Z edge, long along Z -> an X edge; side from the
-- map center. Works even when the pre-baked map uses different bounds than Config.
local function classifyWall(wall, center)
	local s = wall.Size
	if math.max(s.X, s.Z) < WALL_ADOPT_LENGTH then return nil end
	if s.X >= s.Z then
		return (wall.Position.Z < center.Z) and "Wall_MinZ" or "Wall_MaxZ"
	end
	return (wall.Position.X < center.X) and "Wall_MinX" or "Wall_MaxX"
end

-- map v2 (A23-53): a reused upright wall standing on older bounds moves onto the Config edge (X / Z place and length
-- from the spec, its own height kept; lowerWall then fixes the bottom). Returns true when it moved.
local function fitWall(wall, spec)
	if not wall:IsA("BasePart") or math.abs(wall.CFrame.UpVector.Y) < 0.99 then return false end
	local p, s = wall.Position, wall.Size
	local flat = Vector3.new(p.X - spec.Position.X, 0, p.Z - spec.Position.Z).Magnitude
	if flat < 0.5 and math.abs(s.X - spec.Size.X) < 0.5 and math.abs(s.Z - spec.Size.Z) < 0.5 then return false end
	wall.Size = Vector3.new(spec.Size.X, s.Y, spec.Size.Z)
	wall.CFrame = CFrame.new(spec.Position.X, p.Y, spec.Position.Z)
	return true
end

local function ensureWalls(ctx, folder)
	local specs = wallSpecs()
	local b = Config.Map.Bounds
	local center = Vector3.new((b.MinX + b.MaxX) / 2, 0, (b.MinZ + b.MaxZ) / 2)
	-- adopt pre-baked walls with other names (the preview script calls all four "Wall")
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and specs[child.Name] == nil then
			local name = classifyWall(child, center)
			if name and not folder:FindFirstChild(name) then
				child.Name = name
			end
		end
	end
	for _, name in WALL_NAMES do
		local wall = folder:FindFirstChild(name)
		if not wall then
			local spec = specs[name]
			part(ctx, {
				Name = name, Size = spec.Size, Position = spec.Position,
				Transparency = 1, CanCollide = true, CastShadow = false,
			}, folder)
			ctx.pieces += 1
		else
			if fitWall(wall, specs[name]) then Util.Log(TAG, "moved " .. name .. " onto Config.Map.Bounds") end
			lowerWall(wall) -- CR-L17
		end
	end
end

------------------------------------------------------------------ gates
-- A23-36 (user 2026-10-06): no big 3D place text on gates. Where I am = the HUD zone chip, where to go = the quest
-- marker, the level gate = ZoneService's own notice. Every billboard on a gate (the pre-baked preview_map sign or an
-- older "GateSign") is removed; the Lintel stays (HUD guide target). Returns 0 (nothing built).
local function clearGateSigns(gate)
	for _, d in gate:GetDescendants() do
		if d:IsA("BillboardGui") then d:Destroy() end
	end
	return 0
end

local function buildGate(ctx, parent, entry, zone)
	local gate = model("Gate_" .. entry.Zone)
	local style = GATE_STYLE[entry.Zone] or (zone.PvP and "Goblin" or "Meadow")
	local pos = entry.Position
	-- the path runs from the gate toward the zone center; the pillars stand across it
	local alongX = math.abs(zone.Center.X - pos.X) >= math.abs(zone.Center.Z - pos.Z)
	local off = alongX and Vector3.new(0, 0, GATE_HALF_SPAN) or Vector3.new(GATE_HALF_SPAN, 0, 0)
	local span = GATE_HALF_SPAN * 2 + 3
	local lintelSize = alongX and Vector3.new(3, 2.5, span) or Vector3.new(span, 2.5, 3)
	-- statues face the incoming path (toward the side away from the zone center)
	local fx = (pos.X - zone.Center.X) >= 0 and 1 or -1
	local lintel

	if style == "Halo" then
		for _, s in { -1, 1 } do
			cyl(ctx, { Name = "Tower", Size = Vector3.new(6, 22, 6), Position = pos + off * s + Vector3.new(0, 11, 0), Color = RGB(245, 242, 235) }, gate)
			part(ctx, {
				Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(6.4, 6.4, 6.4),
				Position = pos + off * s + Vector3.new(0, 22, 0), Color = RGB(212, 175, 55),
			}, gate)
		end
		lintel = part(ctx, { Name = "Lintel", Size = lintelSize, Position = pos + Vector3.new(0, 19, 0), Color = RGB(245, 242, 235) }, gate)
		ring(ctx, pos + Vector3.new(0, 25, 0), 3.5, 8, Vector3.new(0.5, 0.5, 2.8), RGB(255, 225, 130), gate)
	elseif style == "Horns" then
		for _, s in { -1, 1 } do
			part(ctx, {
				Name = "Pillar", Size = Vector3.new(4, 18, 4), Position = pos + off * s + Vector3.new(0, 9, 0),
				Color = RGB(45, 30, 35), Material = Enum.Material.Basalt,
			}, gate)
			for k = 1, 3 do
				local tilt = alongX and CFrame.Angles(math.rad(15 * k * s), 0, 0) or CFrame.Angles(0, 0, math.rad(-15 * k * s))
				prop(ctx, {
					Name = "Horn", Size = Vector3.new(2.4 - k * 0.5, 3, 2.4 - k * 0.5),
					CFrame = CFrame.new(pos + off * s * (1 - k * 0.12) + Vector3.new(0, 18 + k * 2.4, 0)) * tilt,
					Color = RGB(60, 40, 45), Material = Enum.Material.Basalt,
				}, gate, "WedgePart")
			end
			prop(ctx, {
				Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8),
				Position = pos + off * s * 0.92 + Vector3.new(0, 16, 0), Color = RGB(255, 60, 40), Material = NEON,
			}, gate)
		end
		lintel = part(ctx, {
			Name = "Lintel", Size = lintelSize, Position = pos + Vector3.new(0, 17, 0),
			Color = RGB(130, 25, 30), Material = Enum.Material.Fabric,
		}, gate)
	else
		local col = ({ Meadow = RGB(140, 100, 65), Goblin = RGB(110, 80, 50), Ruins = RGB(225, 220, 200) })[style]
		local mat = (style == "Ruins") and SP or Enum.Material.Wood
		for _, s in { -1, 1 } do
			part(ctx, { Name = "Pillar", Size = Vector3.new(3, 18, 3), Position = pos + off * s + Vector3.new(0, 9, 0), Color = col, Material = mat }, gate)
		end
		lintel = part(ctx, { Name = "Lintel", Size = lintelSize, Position = pos + Vector3.new(0, 18.5, 0), Color = col, Material = mat }, gate)
		local top = pos + Vector3.new(0, 24, 0)
		if style == "Meadow" then -- slime statue
			part(ctx, { Name = "SlimeStatue", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = top, Color = RGB(120, 230, 150) }, gate)
			for _, ez in { -1.5, 1.5 } do
				prop(ctx, {
					Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
					Position = top + Vector3.new(3.4 * fx, 1, ez), Color = RGB(30, 30, 30),
				}, gate)
			end
		elseif style == "Goblin" then -- goblin totem + crossed spears
			part(ctx, { Name = "Totem", Size = Vector3.new(4, 7, 4), Position = top + Vector3.new(0, 0.5, 0), Color = RGB(80, 120, 50) }, gate)
			prop(ctx, {
				Name = "TotemEyes", Size = Vector3.new(0.4, 0.8, 2.6), Position = top + Vector3.new(2.1 * fx, 2, 0),
				Color = RGB(255, 220, 60), Material = NEON,
			}, gate)
			for _, a in { 35, -35 } do
				prop(ctx, {
					Name = "Spear", Size = Vector3.new(0.5, 12, 0.5),
					CFrame = CFrame.new(top + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(a), 0, 0),
					Color = RGB(120, 90, 55), Material = Enum.Material.Wood,
				}, gate)
			end
		else -- skull arch
			part(ctx, { Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12), Position = top + Vector3.new(0, 2, 0), Color = RGB(225, 220, 200) }, gate)
			for _, ez in { -2.6, 2.6 } do
				local eye = prop(ctx, {
					Name = "SkullEye", Shape = Enum.PartType.Ball, Size = Vector3.new(2.5, 2.5, 2.5),
					Position = top + Vector3.new(5.2 * fx, 3, ez), Color = RGB(150, 110, 255), Material = NEON,
				}, gate)
				if ez < 0 then light(ctx, eye, RGB(150, 110, 255), 18, 1.5) end
			end
			prop(ctx, { Name = "Jaw", Size = Vector3.new(4, 2, 6), Position = top + Vector3.new(3.5 * fx, -3.5, 0), Color = RGB(205, 200, 180) }, gate)
		end
	end

	gate.PrimaryPart = lintel
	gate.Parent = parent
	return gate
end

-- map v2 (A23-53): a reused gate (built here, by preview_map or a kit model keeping its "Lintel") slides on X / Z so its
-- lintel stands over the Config position; height and turn stay. Returns true when it moved.
local function placeGate(gate, pos)
	if not gate:IsA("Model") then return false end
	local anchor = gate.PrimaryPart or gate:FindFirstChild("Lintel", true)
	local at = (anchor and anchor:IsA("BasePart")) and anchor.Position or gate:GetPivot().Position
	local delta = Vector3.new(pos.X - at.X, 0, pos.Z - at.Z)
	if delta.Magnitude < 0.5 then return false end
	gate:PivotTo(gate:GetPivot() + delta)
	return true
end

local function ensureGates(ctx, folder)
	for _, entry in Config.Map.Gates do
		local zone = Config.Zones[entry.Zone]
		if zone then
			local gate = folder:FindFirstChild("Gate_" .. entry.Zone)
			if not gate then
				gate = buildGate(ctx, folder, entry, zone)
				ctx.pieces += 1
			elseif placeGate(gate, entry.Position) then
				Util.Log(TAG, ("moved Gate_%s to (%g, %g)"):format(entry.Zone, entry.Position.X, entry.Position.Z))
			end
			ctx.pieces += clearGateSigns(gate)
		end
	end
end

------------------------------------------------------------------ pads
-- CR-M22: a reused pad is moved to its Config position (top at Y = 0.5) with every part under it (ring, decor);
-- the billboard is adorned to the pad and follows. Returns true when it moved.
local function placePad(pad, pos)
	-- the crossroads kit (tools/worldkit/crossroads_kit_main.luau) sets TopY: the pad lies on its kit base top
	local top = tonumber(pad:GetAttribute("TopY")) or 0.5
	local want = Vector3.new(pos.X, top - pad.Size.Y / 2, pos.Z)
	local delta = want - pad.Position
	if delta.Magnitude < 0.05 then return false end
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + delta
		end
	end
	pad.CFrame = pad.CFrame + delta
	return true
end

local function ensurePads(ctx, folder)
	local size = Config.Map.PadSize
	for _, entry in Config.Map.Pads do
		local zone = Config.Zones[entry.Dest]
		local name = "Pad_" .. entry.Dest
		local pad = folder:FindFirstChild(name)
		if not pad then
			local center = Vector3.new(entry.Position.X, 0.5 - size.Y / 2, entry.Position.Z) -- top at Y = 0.5
			pad = part(ctx, { Name = name, Size = size, Position = center, Color = RGB(80, 200, 255), Material = NEON }, folder)
			if zone then
				ring(ctx, Vector3.new(center.X, 0.55, center.Z), 6.2, 12, Vector3.new(0.6, 0.3, 3.4), dangerColor(zone), pad)
			end
			ctx.pieces += 1
		end
		-- functional bits (re-applied on reuse)
		pad:SetAttribute("TravelTo", entry.Dest)
		if pad:IsA("BasePart") then
			pad.CanTouch = true
			pad.CanCollide = pad:GetAttribute("KitBase") ~= true -- a kit base is the floor; the invisible pad only senses
			if placePad(pad, entry.Position) then -- CR-M22: an older map had pads on the east road
				Util.Log(TAG, ("moved %s to (%g, %g)"):format(name, entry.Position.X, entry.Position.Z))
			end
		end
		if zone then
			local sign = pad:FindFirstChildWhichIsA("BillboardGui")
			if not sign then
				sign = billboard(pad, "PadSign", padLabel(zone), PAD_SIGN.OffsetY + (PAD_SIGN.Lift[zone.Id] or 0), RGB(200, 240, 255), PAD_SIGN.Width,
					PAD_SIGN.MaxDistance, PAD_SIGN.Height)
				ctx.pieces += 1
			else
				-- CR-M22: the reused sign text follows Config (zone name / level)
				local label = sign:FindFirstChildWhichIsA("TextLabel", true)
				if label then label.Text = padLabel(zone) end
			end
			-- A23-36: a pre-baked (big, far) pad sign becomes the small near-only label
			sign.Size = UDim2.fromOffset(PAD_SIGN.Width, PAD_SIGN.Height)
			sign.MaxDistance = PAD_SIGN.MaxDistance
			sign.StudsOffset = Vector3.new(0, PAD_SIGN.OffsetY + (PAD_SIGN.Lift[zone.Id] or 0), 0)
		end
	end
end

------------------------------------------------------------------ landmarks (contract)
local function buildFountain(ctx, parent)
	local f = Config.Map.FountainPosition
	local m = model("Fountain")
	local marble = Enum.Material.Marble
	local stone, water = RGB(225, 225, 230), RGB(90, 180, 255)
	local base = cyl(ctx, { Name = "Tier1", Size = Vector3.new(26, 2, 26), Position = f + Vector3.new(0, 1, 0), Color = stone, Material = marble }, m)
	cyl(ctx, { Name = "Water1", Size = Vector3.new(23, 0.3, 23), Position = f + Vector3.new(0, 2.05, 0), Color = water, Transparency = 0.3, CanCollide = false }, m)
	cyl(ctx, { Name = "Tier2", Size = Vector3.new(14, 3, 14), Position = f + Vector3.new(0, 3.5, 0), Color = stone, Material = marble }, m)
	cyl(ctx, { Name = "Water2", Size = Vector3.new(12, 0.3, 12), Position = f + Vector3.new(0, 5.05, 0), Color = water, Transparency = 0.3, CanCollide = false }, m)
	cyl(ctx, { Name = "Tier3", Size = Vector3.new(6, 2, 6), Position = f + Vector3.new(0, 6, 0), Color = stone, Material = marble }, m)
	m.PrimaryPart = base
	m.Parent = parent
	return m
end

local function buildAltar(ctx, parent)
	local pos = Config.Map.AltarPosition
	local altar = part(ctx, {
		Name = "Altar", Size = Vector3.new(8, 4, 8), Position = pos + Vector3.new(0, 2, 0), -- bottom on the ground
		Color = RGB(110, 100, 130), Material = Enum.Material.Slate,
	}, parent)
	-- the top glows half gold (Halo) and half red (Horns)
	local topHalo = part(ctx, {
		Name = "AltarGlowHalo", Size = Vector3.new(6, 0.4, 3), Position = pos + Vector3.new(0, 4.2, -1.5),
		Color = RGB(255, 215, 90), Material = NEON, CanCollide = false,
	}, altar)
	part(ctx, {
		Name = "AltarGlowHorns", Size = Vector3.new(6, 0.4, 3), Position = pos + Vector3.new(0, 4.2, 1.5),
		Color = RGB(220, 50, 60), Material = NEON, CanCollide = false,
	}, altar)
	light(ctx, topHalo, RGB(255, 180, 160), 18, 1.5)
	for _, cx in { -6, 6 } do
		for _, cz in { -6, 6 } do
			part(ctx, {
				Name = "AltarColumn", Size = Vector3.new(2, 10, 2), Position = pos + Vector3.new(cx, 5, cz),
				Color = RGB(150, 140, 165), Material = Enum.Material.Slate,
			}, altar)
		end
	end
	billboard(altar, "AltarSign", "Altar of Fate", 8, RGB(230, 210, 255))
	return altar
end

-- returns 1 when the prompt had to be created
local function ensureAltarPrompt(altar)
	local built = 0
	local prompt = altar:FindFirstChild("AltarPrompt")
	if prompt and not prompt:IsA("ProximityPrompt") then
		retire(prompt, "_Old")
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "AltarPrompt"
		built = 1
	end
	prompt.ActionText = "Switch side"
	prompt.ObjectText = "Altar of Fate"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = ALTAR_PROMPT_KEY
	prompt.Enabled = true
	prompt.Parent = altar
	return built
end

local function buildBoard(ctx, parent)
	local pos = Config.Map.BoardPosition
	local board = part(ctx, {
		Name = "MostWantedBoard", Size = Vector3.new(1, 12, 20), Position = pos + Vector3.new(0, 6, 0),
		Color = RGB(90, 60, 40), Material = Enum.Material.WoodPlanks,
	}, parent)
	for _, dz in { -10.5, 10.5 } do
		part(ctx, {
			Name = "BoardPost", Size = Vector3.new(1.2, 14, 1.2), Position = pos + Vector3.new(0, 7, dz),
			Color = RGB(70, 45, 30), Material = Enum.Material.Wood,
		}, board)
	end
	return board
end

-- SurfaceGui "BoardGui" on the +X face with TextLabel "BoardText". Returns the number of pieces created.
local function ensureBoardGui(board)
	local built = 0
	local gui = board:FindFirstChild("BoardGui")
	if gui and not gui:IsA("SurfaceGui") then
		retire(gui, "_Old")
		gui = nil
	end
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(400, 240)
		built += 1
	end
	gui.Face = Enum.NormalId.Right -- faces +X
	gui.LightInfluence = 0 -- readable under every sky
	gui.Parent = board
	local text = gui:FindFirstChild("BoardText")
	if text and not text:IsA("TextLabel") then
		retire(text, "_Old")
		text = nil
	end
	if not text then
		text = Instance.new("TextLabel")
		text.Name = "BoardText"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = RGB(30, 25, 25)
		text.BackgroundTransparency = 0
		text.TextColor3 = WHITE
		text.Font = Enum.Font.GothamBold
		text.Text = "Wanted Board"
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = text
		text.Parent = gui
		built += 1
	end
	text.TextScaled = true
	text.TextWrapped = true
	return built
end

-- round gold platform (Cylinder Ø10 × 1, top at Y = 1, Marble) + the event-stage ring and gold posts
local function buildGoosePerch(ctx, parent)
	local gp = Config.Goose.Position
	local perch = cyl(ctx, {
		Name = "GoosePerch", Size = Vector3.new(PERCH_DIAMETER, PERCH_HEIGHT, PERCH_DIAMETER),
		Position = Vector3.new(gp.X, PERCH_HEIGHT / 2, gp.Z), Color = RGB(255, 200, 60), Material = Enum.Material.Marble,
	}, parent)
	disc(ctx, Vector3.new(gp.X, 0.08, gp.Z), 22, 0.2, RGB(255, 240, 200), perch)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		part(ctx, {
			Name = "GoldPost", Size = Vector3.new(1, 6, 1),
			Position = Vector3.new(gp.X + math.cos(a) * 10, 3, gp.Z + math.sin(a) * 10), Color = RGB(212, 175, 55),
		}, perch)
	end
	billboard(perch, "PerchSign", "Golden Goose Nest", PERCH_SIGN.OffsetY, RGB(255, 225, 120), PERCH_SIGN.Width,
		PERCH_SIGN.MaxDistance, PERCH_SIGN.Height)
	return perch
end

-- Part = true: a BasePart contract (other services read .Position / children)
local CONTRACT_LANDMARKS = {
	{ Name = "Fountain", Build = buildFountain },
	{ Name = "Altar", Build = buildAltar, Part = true },
	{ Name = "MostWantedBoard", Build = buildBoard, Part = true },
	{ Name = "GoosePerch", Build = buildGoosePerch },
}

local function ensureLandmarks(ctx, folder)
	for _, def in CONTRACT_LANDMARKS do
		local inst = folder:FindFirstChild(def.Name)
		if inst and def.Part and not inst:IsA("BasePart") then
			retire(inst, "_Decor")
			inst = nil
		end
		if not inst then
			def.Build(ctx, folder)
			ctx.pieces += 1
		end
	end
	local altar = folder:FindFirstChild("Altar")
	if altar then
		ctx.pieces += ensureAltarPrompt(altar)
	end
	local board = folder:FindFirstChild("MostWantedBoard")
	if board then
		ctx.pieces += ensureBoardGui(board)
	end
end

-- E11 job boards (Config.Board; image dev's BoardPanel opens the window with BoardAction(id, "Open")): at each board's
-- spot (Config.StoryQuests.Landmarks[<Spot>]) the host part of "JobBoard_<id>" (the placed 3D board model of that name,
-- else an invisible anchor) carries the ProximityPrompt "BoardPrompt" with the attribute Board = <id>. While
-- Config.Board.Enabled is false the prompt is there but switched off.
local function ensureJobBoards(ctx, folder)
	local B = Config.Board
	if type(B) ~= "table" or type(B.Boards) ~= "table" then return end
	local spots = type(Config.StoryQuests) == "table" and type(Config.StoryQuests.Landmarks) == "table"
		and Config.StoryQuests.Landmarks or {}
	for id, def in B.Boards do
		local spot = type(def) == "table" and spots[def.Spot] or nil
		if typeof(spot) == "Vector3" then
			local name = "JobBoard_" .. tostring(id)
			local holder = folder:FindFirstChild(name)
			local host = nil
			if holder and holder:IsA("Model") then
				host = holder.PrimaryPart or holder:FindFirstChildWhichIsA("BasePart", true)
			elseif holder and holder:IsA("BasePart") then
				host = holder
			end
			if not host then
				host = part(ctx, {
					Name = name, Size = Vector3.new(4, 6, 1), Position = spot + Vector3.new(0, 3, 0),
					Transparency = 1, CanCollide = false, CanTouch = false,
				}, folder)
				ctx.pieces += 1
			end
			local prompt = host:FindFirstChild("BoardPrompt")
			if prompt and not prompt:IsA("ProximityPrompt") then retire(prompt, "_Old"); prompt = nil end
			if not prompt then prompt = Instance.new("ProximityPrompt"); prompt.Name = "BoardPrompt" end
			prompt.ActionText, prompt.ObjectText = "Look at jobs", "Job Board"
			prompt.KeyboardKeyCode = Enum.KeyCode.E -- the standard interact key (the skill is Q)
			prompt.HoldDuration, prompt.MaxActivationDistance = 0, math.min(12, tonumber(B.Range) or 14)
			prompt.RequiresLineOfSight = false
			prompt.Enabled = B.Enabled == true
			prompt:SetAttribute("Board", tostring(id))
			prompt.Parent = host
		end
	end
end

-- invisible, non-colliding SpawnLocation (PlayerService places characters; this only avoids spawning at the origin)
local function buildPreviewSpawn(ctx, landmarks)
	if landmarks:FindFirstChild("PreviewSpawn") then return end
	local spawn = part(ctx, {
		Name = "PreviewSpawn", Size = Vector3.new(8, 1, 8), Position = Config.Zones.Crossroads.Spawn + Vector3.new(0, 0.1, 0),
		Color = RGB(200, 200, 200), Transparency = 1, CanCollide = false,
	}, landmarks, "SpawnLocation")
	spawn.Neutral = true
	spawn.Duration = 0 -- spawn protection is PvPService's ForceField, not the SpawnLocation's
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then decal:Destroy() end
end

-- The potion shop NPC: prompt on its root. The shop stays absent/disabled until Config.Vitals.MerchantEnabled.
local function ensureMerchantPrompt(merchant, tune)
	local root = merchant.PrimaryPart
	if not root or not root:IsA("BasePart") or not root:IsDescendantOf(merchant) then return false end
	local prompt = root:FindFirstChild(tune.PotionMerchantPrompt)
	if prompt and not prompt:IsA("ProximityPrompt") then retire(prompt, "_Old"); prompt = nil end
	if not prompt then prompt = Instance.new("ProximityPrompt"); prompt.Name = tune.PotionMerchantPrompt end
	prompt.ActionText, prompt.ObjectText = "Buy potions", tune.PotionMerchantLabel or "Potion Seller" -- ⑪ Fizzby
	prompt.KeyboardKeyCode = Enum.KeyCode.E -- standard interact key; the skill is Q only
	prompt.HoldDuration, prompt.MaxActivationDistance = 0, tune.PotionMerchantDistance -- a shop opens on a tap
	prompt.RequiresLineOfSight, prompt.Enabled = false, true
	prompt:SetAttribute("Conversation", true) -- verified NPC interaction
	prompt.Parent = root
	CollectionService:AddTag(merchant, "NPC")
	return true
end

local function ensurePotionMerchant(ctx, folder)
	local tune = Config.Vitals
	local merchant = folder:FindFirstChild(tune.PotionMerchantName)
	local function disableExisting()
		local part = merchant and merchant:IsA("Model") and merchant.PrimaryPart
		local prompt = part and part:FindFirstChild(tune.PotionMerchantPrompt)
		if prompt and prompt:IsA("ProximityPrompt") then prompt.Enabled = false end
	end
	if tune.MerchantEnabled ~= true then disableExisting(); return end
	if merchant and (not merchant:IsA("Model") or merchant:GetAttribute("HHC_PotionMerchant") ~= true) then
		Util.Warn(TAG, "PotionMerchant name is occupied by unrelated content; skipped")
		return
	end
	if merchant then
		ensureMerchantPrompt(merchant, tune)
		return
	end
	local offset = tune.PotionMerchantOffset
	if type(offset) ~= "table" or type(offset.X) ~= "number" or type(offset.Z) ~= "number"
		or offset.X ~= offset.X or offset.Z ~= offset.Z or math.abs(offset.X) > 30 or math.abs(offset.Z) > 30 then return end
	ctx.pieces += 1
	-- A23-6: a temporary default Roblox-style NPC built from a HumanoidDescription (no costume rig, no new art).
	-- Building the body loads Roblox's default meshes (yields), so it runs after Build returns (Build never yields).
	task.spawn(function()
		local colors = tune.PotionMerchantColors or {}
		local made, npc = pcall(function()
			local desc = Instance.new("HumanoidDescription")
			desc.HeadColor = colors.Head or Color3.fromRGB(234, 184, 146)
			desc.LeftArmColor, desc.RightArmColor = desc.HeadColor, desc.HeadColor
			desc.TorsoColor = colors.Torso or Color3.fromRGB(46, 120, 92)
			desc.LeftLegColor = colors.Legs or Color3.fromRGB(70, 55, 45)
			desc.RightLegColor = desc.LeftLegColor
			return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not made or not npc then Util.Warn(TAG, "PotionMerchant NPC build failed: " .. tostring(npc)); return end
		if folder:FindFirstChild(tune.PotionMerchantName) then npc:Destroy(); return end -- built meanwhile
		local prepared, why = pcall(function()
			npc.Name = tune.PotionMerchantName
			for _, child in npc:GetDescendants() do
				if child:IsA("LuaSourceContainer") then
					child:Destroy()
				elseif child:IsA("BasePart") then
					child.Anchored = true
					child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
				end
			end
			local humanoid = npc:FindFirstChildOfClass("Humanoid")
			local root = npc:FindFirstChild("HumanoidRootPart")
			assert(humanoid and root and root:IsA("BasePart"), "default NPC has no root/humanoid")
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, false
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			npc.PrimaryPart = root
			local pivot = npc:GetPivot()
			local bounds, size = npc:GetBoundingBox()
			local target = Config.Zones.Crossroads.Spawn + Vector3.new(offset.X, 0, offset.Z)
			npc:PivotTo(pivot + Vector3.new(target.X - pivot.Position.X,
				target.Y - (bounds.Position.Y - size.Y * 0.5), target.Z - pivot.Position.Z))
			npc:SetAttribute("HHC_PotionMerchant", true)
			npc:SetAttribute("HHC_MerchantLook", "DefaultNPC") -- final look: Firefly redraw (A23-6)
			assert(ensureMerchantPrompt(npc, tune), "default NPC root is invalid")
			npc.Parent = folder
		end)
		if not prepared then npc:Destroy(); Util.Warn(TAG, "PotionMerchant preparation failed: " .. tostring(why)) end
	end)
end

------------------------------------------------------------------ public API
-- ENSURE: reuse workspace.Map if present, create only what is missing. No S, no yields, idempotent.
-- A reused map never gets ground or decor (its world is Terrain); a fresh one gets the A11-R3 minimal ground.
------------------------------------------------------------------ A23-30 PumpkinPatch (Halloween field)
-- Terrain land joined to the meadow's south shore (Config.Map.Lands "LandPumpkinPatch"; filled only while that spot is
-- still sea), a dirt path from the meadow road, furrows, pumpkins and a fence (plain parts, no new art) in
-- Map.Decor.PumpkinPatch, and the one road sign Map.Landmarks.PumpkinPatchSign (HalloweenService hides it out of
-- season). Idempotent: every piece is looked up by name first. Map v2 (A23-53): the path, gates and sign come from
-- Config.Map.Halloween; the coast is an open beach (no ridge), so the fence is the field's edge.
local HW = type(Config.Map.Halloween) == "table" and Config.Map.Halloween or {}
local PATCH = {
	Land = "LandPumpkinPatch",
	Pumpkin = RGB(235, 128, 34), Stem = RGB(92, 112, 44), Wood = RGB(128, 92, 58),
	Soil = Enum.Material.Mud, -- the Tex_PumpkinSoil slot (Config.Zones.PumpkinPatch.FloorMaterial); Ground = ruins soil
	PathX = tonumber(HW.PathX) or 535, PathHalfW = 6, PathFromZ = 9, -- from the meadow road (|z| <= 9) south into the patch
	-- a pass is cut only if something still stands on the path between the meadow and the patch (the v1 ridge)
	PassHalfW = 9, PassReach = 30, -- the cut runs PassReach studs either side of the patch's north edge
	FurrowStep = 24, PostStep = 16, Gate = 10, -- a 4-stud furrow every 24 studs; fence post every 16; gate half-width
	FenceInset = 2, -- the north fence 2 studs inside the land edge; pumpkins from 9 studs past it
	PumpkinStepX = 34,
	WestGateZ = (typeof(HW.HollowGate) == "Vector3" and HW.HollowGate.Z) or 340, -- A23-45: the gap into the HauntedHollow
	-- no pumpkins on the giant pumpkin house (world_map_v2 landmark, a later kit) or the hollow road
	Keep = { { Vector3.new(585, 0, 370), 34 } },
	SignPos = typeof(HW.SignPos) == "Vector3" and HW.SignPos or Vector3.new(525, 0, 226), -- west of the path; A23-36: no text
}

function PATCH.rect()
	for _, l in (type(Config.Map.Lands) == "table" and Config.Map.Lands or {}) do
		if type(l) == "table" and l.Name == PATCH.Land then return l end
	end
	return nil
end

function PATCH.northZ(l)
	return l.MinZ + PATCH.FenceInset
end

function PATCH.terrainHit(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	return workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), params)
end

-- true while the patch centre is still sea (or nothing): then the land is filled once
function PATCH.landMissing(cx, cz)
	local hit = PATCH.terrainHit(cx, cz)
	return hit == nil or hit.Material == Enum.Material.Water
end

function PATCH.fillLand(l)
	local T = workspace.Terrain
	local w, d = l.MaxX - l.MinX, l.MaxZ - l.MinZ
	local cx, cz = (l.MinX + l.MaxX) / 2, (l.MinZ + l.MaxZ) / 2
	-- tools/preview_map.lua land(): FillBlock tops land 2 cells above the asked top, so every fill sits 2 lower
	T:FillBlock(CFrame.new(cx, -12, cz), Vector3.new(w + 16, 8, d + 16), Enum.Material.Sand)
	-- pumpkin soil (Mud = the Tex_PumpkinSoil slot) with leafy rows between the furrows
	T:FillBlock(CFrame.new(cx, -8, cz), Vector3.new(w, 12, d), PATCH.Soil)
	for z = l.MinZ + PATCH.FurrowStep + 12, l.MaxZ - 12, PATCH.FurrowStep do
		T:FillBlock(CFrame.new(cx, -4, z), Vector3.new(w - 24, 4, 4), Enum.Material.LeafyGrass)
	end
end

-- true while something higher than a step stands on the path where it crosses into the patch
function PATCH.passBlocked(l)
	local hit = PATCH.terrainHit(PATCH.PathX, l.MinZ)
	return hit ~= nil and hit.Position.Y > 3
end

-- the soil path from the meadow road to the north gate is missing (an older place, or a fresh Terrain)
function PATCH.pathMissing(l)
	local hit = PATCH.terrainHit(PATCH.PathX, (PATCH.PathFromZ + l.MinZ) / 2)
	return hit == nil or (hit.Material ~= PATCH.Soil and hit.Material ~= Enum.Material.Water)
end

-- the pass (cleared above the floor, floor at Y = 0) where the path enters the patch
function PATCH.cutPass(l)
	local T = workspace.Terrain
	local fromZ, toZ = l.MinZ - PATCH.PassReach, l.MinZ + PATCH.PassReach
	local midZ, w = (fromZ + toZ) / 2, PATCH.PassHalfW * 2
	T:FillBlock(CFrame.new(PATCH.PathX, 50, midZ), Vector3.new(w, 100, toZ - fromZ), Enum.Material.Air)
	T:FillBlock(CFrame.new(PATCH.PathX, -8, midZ), Vector3.new(w, 12, toZ - fromZ), Enum.Material.Grass)
end

-- the dirt path from the meadow road (|z| <= 9) to the north gate (a soil strip on the meadow grass)
function PATCH.paintPath(l)
	local fromZ, toZ = PATCH.PathFromZ, PATCH.northZ(l) + 4
	workspace.Terrain:FillBlock(CFrame.new(PATCH.PathX, -4, (fromZ + toZ) / 2), Vector3.new(PATCH.PathHalfW * 2, 4, toZ - fromZ),
		PATCH.Soil)
end

function PATCH.keepClear(px, pz)
	for _, k in PATCH.Keep do
		if Vector3.new(px - k[1].X, 0, pz - k[1].Z).Magnitude < k[2] then return false end
	end
	-- the hollow road (Config.Map.Roads RoadHollow: the west gate -> the path, z WestGateZ +- 5)
	if math.abs(pz - PATCH.WestGateZ) < 9 and px < PATCH.PathX + 6 then return false end
	return math.abs(px - PATCH.PathX) > 8
end

function PATCH.decor(ctx, l, decor)
	if decor:FindFirstChild("PumpkinPatch") then return end
	local m = model("PumpkinPatch")
	local rng = Random.new(1031) -- the same field every build
	local north = PATCH.northZ(l)
	-- pumpkins on the furrows: an orange ball, a stem and one leaf
	for z = math.max(l.MinZ + PATCH.FurrowStep, north + 9), l.MaxZ - 10, PATCH.FurrowStep do
		for x = l.MinX + 18, l.MaxX - 18, PATCH.PumpkinStepX do
			local px, pz = x + rng:NextNumber(-6, 6), z + rng:NextNumber(-1.5, 1.5)
			if PATCH.keepClear(px, pz) then
				local size = rng:NextNumber(2.2, 3.8)
				prop(ctx, { Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size),
					Position = Vector3.new(px, size * 0.42, pz), Color = PATCH.Pumpkin }, m)
				prop(ctx, { Name = "Stem", Size = Vector3.new(0.35, size * 0.3, 0.35),
					Position = Vector3.new(px, size * 0.92, pz), Color = PATCH.Stem }, m)
				prop(ctx, { Name = "Leaf", Size = Vector3.new(size * 0.45, 0.1, size * 0.3),
					CFrame = CFrame.new(px + size * 0.3, size * 0.2, pz + size * 0.25) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
					Color = PATCH.Stem }, m)
			end
		end
	end
	-- a low fence around the field with a gate in the north side (the path) and one in the west side (the hollow)
	local function post(x, z)
		prop(ctx, { Name = "FencePost", Size = Vector3.new(0.8, 3.2, 0.8), Position = Vector3.new(x, 1.6, z),
			Color = PATCH.Wood, Material = Enum.Material.WoodPlanks }, m)
	end
	local function rail(a, b)
		local mid, len = (a + b) / 2, (b - a).Magnitude
		prop(ctx, { Name = "FenceRail", Size = Vector3.new(0.4, 0.45, len),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 2.2, 0), b + Vector3.new(0, 2.2, 0)),
			Color = PATCH.Wood, Material = Enum.Material.WoodPlanks }, m)
	end
	local corners = { Vector3.new(l.MinX, 0, north), Vector3.new(l.MaxX, 0, north), Vector3.new(l.MaxX, 0, l.MaxZ),
		Vector3.new(l.MinX, 0, l.MaxZ) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local n = math.max(1, math.floor((b - a).Magnitude / PATCH.PostStep + 0.5))
		for k = 0, n - 1 do
			local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
			local gate = (i == 1 and math.abs((p0.X + p1.X) / 2 - PATCH.PathX) < PATCH.Gate)
				or (i == 4 and math.abs((p0.Z + p1.Z) / 2 - PATCH.WestGateZ) < PATCH.Gate)
			-- no post in the middle of a gate gap (the north one stood on the dirt path)
			local midGate = (i == 1 and math.abs(p0.X - PATCH.PathX) < PATCH.Gate - 1)
				or (i == 4 and math.abs(p0.Z - PATCH.WestGateZ) < PATCH.Gate - 1)
			if not midGate then post(p0.X, p0.Z) end
			if not gate then rail(p0, p1) end
		end
	end
	m.Parent = decor
	ctx.pieces += 1
end

-- the road sign at the path's meadow end: a post and a blank pumpkin-orange board (HalloweenService shows it only in
-- season). A23-36: no billboard text on it any more (an older "SignGui" is removed); the quest marker points into the
-- field. Map v2: a sign left on the old spot moves to PATCH.SignPos.
function PATCH.sign(ctx, landmarks)
	local sign = landmarks:FindFirstChild("PumpkinPatchSign")
	local p = PATCH.SignPos
	if not sign then
		sign = model("PumpkinPatchSign")
		local postPart = part(ctx, { Name = "Post", Size = Vector3.new(0.8, 6, 0.8), Position = p + Vector3.new(0, 3, 0),
			Color = PATCH.Wood, Material = Enum.Material.WoodPlanks }, sign)
		postPart:SetAttribute("ShownTransparency", 0)
		postPart:SetAttribute("ShownCollide", true)
		local board = part(ctx, { Name = "Board", Size = Vector3.new(6, 2.2, 0.4), Position = p + Vector3.new(0, 5.2, 0),
			Color = PATCH.Pumpkin, Material = Enum.Material.WoodPlanks, CanCollide = false }, sign)
		board:SetAttribute("ShownTransparency", 0)
		board:SetAttribute("ShownCollide", false)
		sign.PrimaryPart = postPart
		sign.Parent = landmarks
		ctx.pieces += 1
	elseif sign:IsA("Model") then
		local postPart = sign:FindFirstChild("Post")
		local at = (postPart and postPart:IsA("BasePart")) and postPart.Position or sign:GetPivot().Position
		local delta = Vector3.new(p.X - at.X, 0, p.Z - at.Z)
		if delta.Magnitude > 0.5 then sign:PivotTo(sign:GetPivot() + delta) end
	end
	for _, d in sign:GetDescendants() do
		if d:IsA("BillboardGui") then d:Destroy() end
	end
end

-- also used by MapBuilder.EnsurePumpkinPatch (Studio command bar / checks)
function PATCH.ensure(ctx, folders)
	local l = PATCH.rect()
	if not l then return end
	if PATCH.landMissing((l.MinX + l.MaxX) / 2, (l.MinZ + l.MaxZ) / 2) then
		local ok, err = pcall(PATCH.fillLand, l)
		if ok then ctx.pieces += 1 else Util.Warn(TAG, "PumpkinPatch land: " .. tostring(err)) end
	end
	if PATCH.passBlocked(l) then
		local ok, err = pcall(PATCH.cutPass, l)
		if ok then ctx.pieces += 1 else Util.Warn(TAG, "PumpkinPatch pass: " .. tostring(err)) end
	end
	if PATCH.pathMissing(l) then
		local ok, err = pcall(PATCH.paintPath, l)
		if ok then ctx.pieces += 1 else Util.Warn(TAG, "PumpkinPatch path: " .. tostring(err)) end
	end
	PATCH.decor(ctx, l, folders.Decor)
	PATCH.sign(ctx, folders.Landmarks)
end

------------------------------------------------------------------ A23-45 HauntedHollow (the ghost family's field)
-- Terrain land joined to the PumpkinPatch's west edge (Config.Map.Lands "LandHauntedHollow", filled only while that
-- spot is still sea) and Map.Decor.HauntedHollow: the free generated GF_* props of image session 1 (art/models/worldkit/
-- manifest.json ghost_forest, inserted into ServerStorage.KitStage by tools/apply_crossroads_kit.py) or plain-part
-- stand-ins without them. Blue lantern lights within the map light budget, no fog (A23-30 / A23-45 mood: ZoneLook).
-- Map v2: every prop sits at the same share of the land rectangle as in image session 1's v1 layout (U, V from the
-- west / north edge), the entrance arch just inside the patch's west gate.
local HOLLOW = {
	Land = "LandHauntedHollow",
	Soil = Enum.Material.Asphalt, -- the Tex_HauntedFloor slot (GE_HauntedFloor, tools/apply_surface_materials.lua)
	LanternLight = Color3.fromRGB(150, 200, 255),
	ArchInset = 7, -- the arch stands this far inside the west gate (its front faces the gate, +X)
	-- { kit, U, V, size along fit, fit ("h" | "w"), yaw, solid, lit }
	Props = {
		{ "GF_Tree", 0.125, 0.136, 17, "h", 20, true }, { "GF_Tree", 0.1, 0.545, 16, "h", 140, true },
		{ "GF_Tree", 0.183, 0.9, 18, "h", 250, true }, { "GF_Tree", 0.542, 0.964, 15, "h", 80, true },
		{ "GF_Tree", 0.85, 0.936, 16, "h", 310, true }, { "GF_Tree", 0.817, 0.127, 17, "h", 200, true },
		{ "GF_Tree", 0.433, 0.109, 15, "h", 0, true },
		{ "GF_Willow", 0.317, 0.736, 14, "h", 30, true }, { "GF_Willow", 0.7, 0.245, 14, "h", 160, true },
		{ "GF_Lantern", 0.6, 0.564, 9, "h", 0, true, true }, { "GF_Lantern", 0.267, 0.373, 9, "h", 90, true, true },
		{ "GF_Lantern", 0.783, 0.755, 9, "h", 200, true, true },
		{ "GF_Mushrooms", 0.417, 0.482, 2.5, "h", 0, false }, { "GF_Mushrooms", 0.167, 0.264, 2.5, "h", 70, false },
		{ "GF_Mushrooms", 0.75, 0.627, 2.5, "h", 140, false }, { "GF_Mushrooms", 0.533, 0.827, 2.5, "h", 210, false },
		{ "GF_Rock", 0.25, 0.609, 2.5, "h", 0, true }, { "GF_Rock", 0.883, 0.373, 2.5, "h", 60, true },
		{ "GF_Rock", 0.467, 0.264, 2.5, "h", 120, true },
	},
}

function HOLLOW.rect()
	for _, l in (type(Config.Map.Lands) == "table" and Config.Map.Lands or {}) do
		if type(l) == "table" and l.Name == HOLLOW.Land then return l end
	end
	return nil
end

-- a prop's world X / Z from its share of the rectangle
function HOLLOW.at(l, u, v)
	return l.MinX + u * (l.MaxX - l.MinX), l.MinZ + v * (l.MaxZ - l.MinZ)
end

function HOLLOW.fillLand(l)
	local T = workspace.Terrain
	local w, d = l.MaxX - l.MinX, l.MaxZ - l.MinZ
	local cx, cz = (l.MinX + l.MaxX) / 2, (l.MinZ + l.MaxZ) / 2
	-- same layering as PATCH.fillLand (FillBlock tops land 2 cells above the asked top)
	T:FillBlock(CFrame.new(cx, -12, cz), Vector3.new(w + 16, 8, d + 16), Enum.Material.Sand)
	T:FillBlock(CFrame.new(cx, -8, cz), Vector3.new(w, 12, d), HOLLOW.Soil)
end

-- a GF_* kit model clone sized / turned / grounded at (x, z), or nil when the kit model is missing
function HOLLOW.kitProp(name, x, z, size, fit, yaw)
	local stage = ServerStorage:FindFirstChild("KitStage")
	local src = stage and stage:FindFirstChild(name)
	if not (src and src:IsA("Model")) then return nil end
	local m = src:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end -- A23-33: kit models never carry scripts
	end
	local _, sz = m:GetBoundingBox()
	local dim = fit == "w" and sz.X or sz.Y
	if dim > 0 then pcall(m.ScaleTo, m, m:GetScale() * (size / dim)) end
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local cf, bs = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (Vector3.new(x, bs.Y / 2, z) - cf.Position))
	return m
end

-- plain-part stand-in (no kit model): a dark trunk + lavender ball for trees, a post + blue glass for lanterns, ...
function HOLLOW.standIn(ctx, name, x, z, size, parent)
	local m = model(name)
	if name == "GF_Tree" or name == "GF_Willow" then
		part(ctx, { Name = "Trunk", Size = Vector3.new(2, size * 0.55, 2), Position = Vector3.new(x, size * 0.275, z),
			Color = RGB(70, 50, 90), Material = Enum.Material.Wood }, m)
		prop(ctx, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(size * 0.6, size * 0.6, size * 0.6),
			Position = Vector3.new(x, size * 0.7, z), Color = RGB(160, 140, 220) }, m)
	elseif name == "GF_Lantern" then
		part(ctx, { Name = "Post", Size = Vector3.new(0.8, size, 0.8), Position = Vector3.new(x, size / 2, z),
			Color = RGB(80, 60, 70), Material = Enum.Material.Wood }, m)
		prop(ctx, { Name = "Glass", Size = Vector3.new(1.6, 1.8, 1.6), Position = Vector3.new(x, size + 0.6, z),
			Color = RGB(150, 200, 255), Material = NEON }, m)
	elseif name == "GF_Arch" then
		for _, dz in { -8, 8 } do
			part(ctx, { Name = "Pillar", Size = Vector3.new(2, 14, 2), Position = Vector3.new(x, 7, z + dz),
				Color = RGB(70, 50, 90), Material = Enum.Material.Wood }, m)
		end
	else -- mushrooms / rocks: one small ball
		prop(ctx, { Name = "Blob", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size),
			Position = Vector3.new(x, size * 0.4, z), Color = name == "GF_Rock" and RGB(110, 105, 125) or RGB(120, 190, 255) }, m)
	end
	m.Parent = parent
	return m
end

function HOLLOW.place(ctx, root, name, x, z, size, fit, yaw, solid, lit)
	local m = HOLLOW.kitProp(name, x, z, size, fit, yaw)
	if m then
		m.Parent = root
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				if not solid then d.CanCollide = false end
			end
		end
	else
		m = HOLLOW.standIn(ctx, name, x, z, size, root)
	end
	if lit then
		local holder = part(ctx, { Name = "LanternLight", Size = Vector3.new(0.4, 0.4, 0.4),
			Position = Vector3.new(x, size * 0.95, z), Transparency = 1, CanCollide = false }, m)
		light(ctx, holder, HOLLOW.LanternLight, 16, 1.4)
	end
end

function HOLLOW.decor(ctx, l, decor)
	if decor:FindFirstChild("HauntedHollow") then return end
	local root = model("HauntedHollow")
	-- the entrance from the pumpkin field's west gate (front -> +X)
	HOLLOW.place(ctx, root, "GF_Arch", l.MaxX - HOLLOW.ArchInset, PATCH.WestGateZ, 18, "w", -90, false)
	for _, e in HOLLOW.Props do
		local x, z = HOLLOW.at(l, e[2], e[3])
		HOLLOW.place(ctx, root, e[1], x, z, e[4], e[5], e[6], e[7], e[8])
	end
	root.Parent = decor
	ctx.pieces += 1
end

function HOLLOW.ensure(ctx, folders)
	local l = HOLLOW.rect()
	if not l then return end
	if PATCH.landMissing((l.MinX + l.MaxX) / 2, (l.MinZ + l.MaxZ) / 2) then
		local ok, err = pcall(HOLLOW.fillLand, l)
		if ok then ctx.pieces += 1 else Util.Warn(TAG, "HauntedHollow land: " .. tostring(err)) end
	end
	HOLLOW.decor(ctx, l, folders.Decor)
end

function MapBuilder.Build()
	local ctx = newCtx()
	local map = workspace:FindFirstChild("Map")
	local fresh = map == nil
	if fresh then
		Util.Warn(TAG, "no pre-built map: building minimal ground")
		map = Instance.new("Folder")
		map.Name = "Map" -- parented at the end: nobody sees (or touches) a half-built map
	end

	local folders = {}
	for _, name in FOLDER_NAMES do
		local folder, created = getChildFolder(map, name)
		folders[name] = folder
		if created and not fresh then ctx.pieces += 1 end
	end

	if fresh then
		buildMinimalGround(ctx, folders.Ground, folders.Decor)
	end
	ensureZones(ctx, folders.Zones)
	ensureWalls(ctx, folders.Walls)
	ensureGates(ctx, folders.Gates)
	ensurePads(ctx, folders.Pads)
	ensureLandmarks(ctx, folders.Landmarks)
	ensureJobBoards(ctx, folders.Landmarks)
	ensurePotionMerchant(ctx, folders.NPCs)
	local okPatch, errPatch = pcall(PATCH.ensure, ctx, folders) -- A23-30
	if not okPatch then Util.Warn(TAG, "PumpkinPatch: " .. tostring(errPatch)) end
	local okHollow, errHollow = pcall(HOLLOW.ensure, ctx, folders) -- A23-45
	if not okHollow then Util.Warn(TAG, "HauntedHollow: " .. tostring(errHollow)) end
	-- A23-36: shop / landmark name labels (altar, goose nest, market, anvil) stay, seen only up close
	for _, d in folders.Landmarks:GetDescendants() do
		if d:IsA("BillboardGui") and d.MaxDistance > SHOP_SIGN_MAX_DISTANCE and d:FindFirstChildWhichIsA("TextLabel", true) then
			d.MaxDistance = SHOP_SIGN_MAX_DISTANCE
		end
		if d:IsA("BillboardGui") and d.Name == "PerchSign" then -- a nest label already saved in the place
			d.Size = UDim2.fromOffset(PERCH_SIGN.Width, PERCH_SIGN.Height)
			d.StudsOffset = Vector3.new(0, PERCH_SIGN.OffsetY, 0)
			d.MaxDistance = PERCH_SIGN.MaxDistance
		end
	end

	if fresh then
		buildPreviewSpawn(ctx, folders.Landmarks)
		map.Parent = workspace
	end

	-- shared runtime folders + the custom-model drop folder (addendum A1)
	Util.GetFolder(workspace, "Monsters")
	Util.GetFolder(workspace, "Effects")
	Util.GetFolder(ServerStorage, "CustomModels")

	if fresh then
		local total = countParts(map)
		if total > Config.Map.MaxParts then
			Util.Warn(TAG, ("built %d map parts; Config.Map.MaxParts is %d"):format(total, Config.Map.MaxParts))
		end
		print(("[MapBuilder] built workspace.Map (%d parts)"):format(total))
	else
		print(("[MapBuilder] reused workspace.Map (+%d missing pieces built)"):format(ctx.pieces))
	end
	return map
end

-- A23-30: only the PumpkinPatch pieces (land, pass, path, decor, sign); returns { land, pass, path } = what it had to make
function MapBuilder.EnsurePumpkinPatch()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	local folders = {}
	for _, name in FOLDER_NAMES do folders[name] = getChildFolder(map, name) end
	local l = PATCH.rect()
	local made = { land = l ~= nil and PATCH.landMissing((l.MinX + l.MaxX) / 2, (l.MinZ + l.MaxZ) / 2),
		pass = l ~= nil and PATCH.passBlocked(l), path = l ~= nil and PATCH.pathMissing(l) }
	PATCH.ensure(newCtx(), folders)
	return made
end

-- destroy workspace.Map, then Build() (Studio command bar helper)
function MapBuilder.Rebuild()
	local old = workspace:FindFirstChild("Map")
	if old then old:Destroy() end
	return MapBuilder.Build()
end

local function findLandmark(name)
	local map = workspace:FindFirstChild("Map")
	local landmarks = map and map:FindFirstChild("Landmarks")
	return landmarks and landmarks:FindFirstChild(name)
end

local function findAltar()
	local altar = findLandmark("Altar")
	if altar and altar:IsA("BasePart") and altar:FindFirstChild("AltarPrompt") then return altar end
	return nil
end

local function findBoardLabel()
	local board = findLandmark("MostWantedBoard")
	local gui = board and board:FindFirstChild("BoardGui")
	local label = gui and gui:FindFirstChild("BoardText")
	if label and label:IsA("TextLabel") then return label end
	return nil
end

-- workspace.Map.Landmarks.Altar (child ProximityPrompt "AltarPrompt"); rebuilt on demand if it went missing
function MapBuilder.GetAltar()
	local altar = findAltar()
	if not altar then
		MapBuilder.Build()
		altar = findAltar()
	end
	return altar
end

-- workspace.Map.Landmarks.MostWantedBoard.BoardGui.BoardText; rebuilt on demand if it went missing
function MapBuilder.GetBoardLabel()
	local label = findBoardLabel()
	if not label then
		MapBuilder.Build()
		label = findBoardLabel()
	end
	return label
end

function MapBuilder.Init(registry)
	S = registry
end

function MapBuilder.Start()
	MapBuilder.Build() -- synchronous
	print("[MapBuilder] started")
end

return MapBuilder
