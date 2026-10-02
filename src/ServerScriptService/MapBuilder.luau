-- MapBuilder.luau : reuses (or minimally builds) workspace.Map: zone floors, walls, gates, pads, altar, board, goose perch.
--
-- Build() is also run from the Studio command bar in EDIT mode to pre-bake the map:
--     require(game.ServerScriptService.MapBuilder).Build()
-- so it never touches S, never yields and is idempotent: every named element is looked up first and only the missing
-- pieces are created; existing functional pieces get their functional bits re-applied (pad TravelTo, AltarPrompt,
-- BoardGui.BoardText, zone floor ZoneId + invisibility, the two-line gate signs).
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

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local MapBuilder = {}

local TAG = "MapBuilder"
local FOLDER_NAMES = { "Ground", "Zones", "Walls", "Gates", "Pads", "Landmarks", "Decor" }
local WALL_NAMES = { "Wall_MinX", "Wall_MaxX", "Wall_MinZ", "Wall_MaxZ" }
local WALL_THICKNESS = 2
local WALL_ADOPT_LENGTH = 100 -- a pre-baked part at least this long in the Walls folder is a bounds wall
local GATE_HALF_SPAN = 10 -- pillar centers 20 apart (17-stud passage)
local EXTREME_MIN_LEVEL = 25 -- PvP zones from this level use the "extreme" danger color
local SIGN_MAX_DISTANCE = 150
local MAX_LIGHTS = 40 -- whole map
local MAX_LIGHT_RANGE = 40
local MAX_LIGHT_BRIGHTNESS = 2
local PERCH_DIAMETER = 10
local PERCH_HEIGHT = 1
local GROUND_THICKNESS = 4 -- minimal ground plates: top at Y = 0
local BRIDGE_WIDTH = 18 -- default deck width when Config.Map.Bridges has no Width
local ALTAR_PROMPT_KEY = Enum.KeyCode.G -- not E: HUD binds Q/E to Release (would spend stacks while holding the prompt)

local RGB = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)

local DANGER = { Safe = RGB(80, 220, 120), PvP = RGB(255, 150, 40), Extreme = RGB(255, 60, 60) }
local LORE_COLOR = RGB(235, 225, 195)
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

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function escapeRich(s)
	return (string.gsub(tostring(s), "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function gateLore(zoneId)
	local lore = Config.Story and Config.Story.ZoneLore
	return (lore and lore[zoneId]) or ""
end

-- line 1 = zone.Name .. "  Lv " .. MinLevel .. "+  " .. ("PvP 지역" | "안전 지역") (safety word in the danger color),
-- line 2 = Config.Story.ZoneLore[zoneId]
local function gateSignText(zoneId, zone)
	local line1 = string.format('%s  Lv %d+  <font color="%s">%s</font>', escapeRich(zone.Name), zone.MinLevel,
		hex(dangerColor(zone)), zone.PvP and "PvP 지역" or "안전 지역")
	local lore = gateLore(zoneId)
	if lore == "" then return line1 end
	return line1 .. string.format('<br/><font color="%s">%s</font>', hex(LORE_COLOR), escapeRich(lore))
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
			if not floor then
				floor = part(ctx, {
					Name = id,
					Size = Vector3.new(z.Size.X, 1, z.Size.Z),
					Position = Vector3.new(z.Center.X, -0.45, z.Center.Z), -- top at Y = 0.05
					Color = z.FloorColor, Material = z.FloorMaterial,
				}, folder)
				ctx.pieces += 1
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
	return {
		Wall_MinX = { Size = Vector3.new(t, h, lenZ), Position = Vector3.new(b.MinX - t / 2, h / 2, cz) },
		Wall_MaxX = { Size = Vector3.new(t, h, lenZ), Position = Vector3.new(b.MaxX + t / 2, h / 2, cz) },
		Wall_MinZ = { Size = Vector3.new(lenX, h, t), Position = Vector3.new(cx, h / 2, b.MinZ - t / 2) },
		Wall_MaxZ = { Size = Vector3.new(lenX, h, t), Position = Vector3.new(cx, h / 2, b.MaxZ + t / 2) },
	}
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
		if not folder:FindFirstChild(name) then
			local spec = specs[name]
			part(ctx, {
				Name = name, Size = spec.Size, Position = spec.Position,
				Transparency = 1, CanCollide = true, CastShadow = false,
			}, folder)
			ctx.pieces += 1
		end
	end
end

------------------------------------------------------------------ gates
-- the two-line sign; a pre-baked billboard is adopted (renamed "GateSign", its style kept). Returns 1 if created.
local function ensureGateSign(gate, zoneId, zone)
	local built = 0
	local sign = gate:FindFirstChild("GateSign", true)
	if not (sign and sign:IsA("BillboardGui")) then
		sign = gate:FindFirstChildWhichIsA("BillboardGui", true)
		if sign then
			sign.Name = "GateSign"
			if sign.Size.Y.Offset < 56 then
				sign.Size = UDim2.fromOffset(math.max(sign.Size.X.Offset, 300), 60)
			end
		else
			local anchor = gate:FindFirstChild("Lintel", true)
			if not (anchor and anchor:IsA("BasePart")) then
				anchor = gate:IsA("BasePart") and gate or gate:FindFirstChildWhichIsA("BasePart", true)
			end
			if not anchor then return 0 end
			sign = billboard(anchor, "GateSign", "", 6, WHITE, 320, SIGN_MAX_DISTANCE, 60)
			built = 1
		end
	end
	local label = sign:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.Parent = sign
	end
	label.RichText = true
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = gateSignText(zoneId, zone)
	return built
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

local function ensureGates(ctx, folder)
	for _, entry in Config.Map.Gates do
		local zone = Config.Zones[entry.Zone]
		if zone then
			local gate = folder:FindFirstChild("Gate_" .. entry.Zone)
			if not gate then
				gate = buildGate(ctx, folder, entry, zone)
				ctx.pieces += 1
			end
			ctx.pieces += ensureGateSign(gate, entry.Zone, zone)
		end
	end
end

------------------------------------------------------------------ pads
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
			pad.CanCollide = true
		end
		if zone and not pad:FindFirstChildWhichIsA("BillboardGui") then
			billboard(pad, "PadSign", padLabel(zone), 4, RGB(200, 240, 255))
			ctx.pieces += 1
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
	billboard(altar, "AltarSign", "운명의 제단", 8, RGB(230, 210, 255))
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
	prompt.ActionText = "진영 바꾸기"
	prompt.ObjectText = "운명의 제단"
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
		text.Text = "현상수배 게시판"
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
	billboard(perch, "PerchSign", "황금 거위 둥지", 5, RGB(255, 225, 120))
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

------------------------------------------------------------------ public API
-- ENSURE: reuse workspace.Map if present, create only what is missing. No S, no yields, idempotent.
-- A reused map never gets ground or decor (its world is Terrain); a fresh one gets the A11-R3 minimal ground.
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
