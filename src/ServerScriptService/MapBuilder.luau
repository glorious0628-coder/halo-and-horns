-- MapBuilder.luau : builds or reuses workspace.Map (floors, walls, towns, decor, gates, pads, altar, board, goose perch).
--
-- Build() is also run from the Studio command bar in EDIT mode to pre-bake the map:
--     require(game.ServerScriptService.MapBuilder).Build()
-- so it never touches S, never yields and is idempotent: every named element is looked up first and only the missing
-- pieces are created; existing functional pieces get their functional bits re-applied (pad TravelTo, AltarPrompt,
-- BoardGui.BoardText, zone floor ZoneId, the two-line gate signs).
--
-- Addendum A8: a map pre-built by tools/preview_map.lua is adopted as-is: an "Outskirts" ground part and the four
-- "Wall" parts get the contract names (walls are matched by orientation/side, so other bounds still work), a ground of
-- another shape (land masses over Terrain water) is never covered, its gate billboards get the spec text. A fresh build
-- reproduces the preview v2 look (same recipes, random seed and draw order; docs/ART_DIRECTION.md), with every position
-- derived from Config. Decorative landmarks are only built together with the Decor set, never added to a pre-baked map.
-- Lighting is never touched here: WarService owns it (addendum A9-3: no Atmosphere).
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
local DECOR_SEED = 42 -- same seed + draw order as tools/preview_map.lua -> same layout
local CLEAR_RADIUS = 12 -- no decor this close to spawns, pads, altar, board, gates or the goose perch
local PLAZA_RADIUS = 30 -- nothing tall around the fountain / crown
local ROAD_HALF_WIDTH = 12 -- keep the main roads free of decor
local GATE_HALF_SPAN = 10 -- pillar centers 20 apart (17-stud passage)
local EXTREME_MIN_LEVEL = 25 -- PvP zones from this level use the "extreme" danger color
local SIGN_MAX_DISTANCE = 150
local FAR_SIGN_MAX_DISTANCE = 220
local MAX_LIGHTS = 40 -- whole map
local MAX_LIGHT_RANGE = 40
local MAX_LIGHT_BRIGHTNESS = 2
local PERCH_DIAMETER = 10
local PERCH_HEIGHT = 1

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
local function ensureGround(ctx, folder)
	if folder:FindFirstChild("OutskirtsGround") then return end
	-- tools/preview_map.lua (v2) names the ground "Outskirts": adopt it under the contract name
	local legacy = folder:FindFirstChild("Outskirts")
	if legacy and legacy:IsA("BasePart") then
		legacy.Name = "OutskirtsGround"
		return
	end
	-- a pre-baked ground of another shape (e.g. land masses over Terrain water) is authoritative: never cover it
	if folder:FindFirstChildWhichIsA("BasePart", true) then return end
	local b = Config.Map.Bounds
	local z = Config.Zones.Outskirts
	part(ctx, {
		Name = "OutskirtsGround",
		Size = Vector3.new(b.MaxX - b.MinX, 4, b.MaxZ - b.MinZ),
		Position = Vector3.new((b.MinX + b.MaxX) / 2, -2, (b.MinZ + b.MaxZ) / 2), -- top at Y = 0
		Color = z.FloorColor, Material = z.FloorMaterial,
	}, folder)
	ctx.pieces += 1
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

------------------------------------------------------------------ landmarks (decorative; only with a fresh Decor set)
local function buildCrownShard(ctx, parent)
	local f = Config.Map.FountainPosition
	local crown = model("CrownShard")
	local core = part(ctx, {
		Name = "Core", Size = Vector3.new(4, 9, 4), CFrame = CFrame.new(f + Vector3.new(0, 22, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = RGB(255, 215, 90), Material = NEON, CanCollide = false,
	}, crown)
	for i = 0, 3 do
		local a = i * math.pi / 2
		prop(ctx, {
			Name = "Shard", Size = Vector3.new(2, 5, 2),
			CFrame = CFrame.new(f + Vector3.new(math.cos(a) * 3.2, 20, math.sin(a) * 3.2))
				* CFrame.Angles(math.sin(a) * math.rad(15), a, math.cos(a) * math.rad(15)),
			Color = RGB(255, 215, 90), Material = NEON,
		}, crown)
	end
	light(ctx, core, RGB(255, 220, 120), 40, 2)
	-- light pillar seen from every zone
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.zero
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 118, 0)
	a1.Parent = core
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 3
	beam.Width1 = 0.5
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(RGB(255, 225, 130))
	beam.Transparency = NumberSequence.new(0.3, 1)
	beam.Parent = core
	billboard(core, "ShardSign", "균형의 왕관 조각", 7, RGB(255, 230, 140), 260, FAR_SIGN_MAX_DISTANCE)
	crown.PrimaryPart = core
	crown.Parent = parent
	return crown
end

local function buildArtisanGuild(ctx, parent)
	local guild = model("ArtisanGuild")
	local gpos = Config.Zones.Crossroads.Center + Vector3.new(44, 0, 58)
	local hall = part(ctx, { Name = "Hall", Size = Vector3.new(22, 12, 16), Position = gpos + Vector3.new(0, 6, 0), Color = RGB(150, 150, 158) }, guild)
	for _, cx in { -11, 11 } do
		for _, cz in { -8, 8 } do
			part(ctx, {
				Name = "Beam", Size = Vector3.new(0.8, 12, 0.8), Position = gpos + Vector3.new(cx, 6, cz),
				Color = RGB(140, 100, 65), Material = Enum.Material.Wood,
			}, guild)
		end
	end
	part(ctx, { Name = "Roof", Size = Vector3.new(26, 1, 20), Position = gpos + Vector3.new(0, 12.5, 0), Color = RGB(90, 85, 80), Material = Enum.Material.Slate }, guild)
	part(ctx, { Name = "Door", Size = Vector3.new(6, 9, 0.4), Position = gpos + Vector3.new(0, 4.5, -8.1), Color = RGB(110, 75, 45), Material = Enum.Material.WoodPlanks }, guild)
	-- upright gear emblem facing the plaza (-Z)
	local gearCenter = gpos + Vector3.new(0, 20, 0)
	local gear = cyl(ctx, { Name = "GearEmblem", Size = Vector3.new(10, 1.2, 10), Position = gearCenter, Color = RGB(205, 165, 85), Material = Enum.Material.Metal }, guild)
	gear.CFrame = CFrame.new(gearCenter) * CFrame.Angles(0, math.rad(90), 0)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		prop(ctx, {
			Name = "GearTooth", Size = Vector3.new(1.6, 1.6, 1.2),
			CFrame = CFrame.new(gearCenter + Vector3.new(math.cos(a) * 5.6, math.sin(a) * 5.6, 0)) * CFrame.Angles(0, 0, a),
			Color = RGB(40, 200, 190), Material = NEON,
		}, guild)
	end
	part(ctx, { Name = "GearPost", Size = Vector3.new(1, 8, 1), Position = gpos + Vector3.new(0, 15, 0.8), Color = RGB(90, 85, 80), Material = Enum.Material.Metal }, guild)
	local anvil = part(ctx, { Name = "Anvil", Size = Vector3.new(4, 3, 2), Position = gpos + Vector3.new(-5, 1.5, -13), Color = RGB(70, 70, 75), Material = Enum.Material.Metal }, guild)
	local forge = prop(ctx, { Name = "Forge", Size = Vector3.new(3, 1, 3), Position = gpos + Vector3.new(5, 0.5, -13), Color = RGB(255, 140, 60), Material = NEON }, guild)
	light(ctx, forge, RGB(255, 140, 60), 14, 1.5)
	billboard(anvil, "GuildSign", "⚙ 장인 길드", 6, RGB(120, 235, 225))
	guild.PrimaryPart = hall
	guild.Parent = parent
	return guild
end

local function buildCathedral(ctx, parent)
	local cath = model("Cathedral")
	local cp = Config.Zones.HaloTown.Center + Vector3.new(0, 0, -55)
	local drum = cyl(ctx, { Name = "Drum", Size = Vector3.new(26, 12, 26), Position = cp + Vector3.new(0, 6, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, cath)
	part(ctx, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(26, 26, 26), Position = cp + Vector3.new(0, 12, 0), Color = RGB(250, 248, 240), Material = Enum.Material.Marble }, cath)
	cyl(ctx, { Name = "DomeBand", Size = Vector3.new(27, 1, 27), Position = cp + Vector3.new(0, 12, 0), Color = RGB(212, 175, 55) }, cath)
	local spire = part(ctx, { Name = "Spire", Size = Vector3.new(2, 14, 2), Position = cp + Vector3.new(0, 31, 0), Color = RGB(212, 175, 55) }, cath)
	ring(ctx, cp + Vector3.new(0, 36, 0), 4.2, 8, Vector3.new(0.6, 0.6, 3.4), RGB(255, 225, 130), cath)
	light(ctx, spire, RGB(255, 230, 120), 30, 2)
	part(ctx, { Name = "Door", Size = Vector3.new(8, 10, 1), Position = cp + Vector3.new(0, 5, 12.6), Color = RGB(212, 175, 55) }, cath)
	cath.PrimaryPart = drum
	cath.Parent = parent
	return cath
end

local function signAnchor(ctx, name, position, parent)
	return prop(ctx, { Name = name, Size = Vector3.new(1, 1, 1), Position = position, Transparency = 1 }, parent)
end

local function buildMarketSign(ctx, parent)
	local a = signAnchor(ctx, "MarketSign", Config.Zones.Crossroads.Center + Vector3.new(-30, 13, -36), parent)
	billboard(a, "Sign", "거래소 (준비 중)", 0, RGB(255, 240, 180))
	return a
end

local function buildHaloSign(ctx, parent)
	local a = signAnchor(ctx, "HaloSign", Config.Zones.HaloTown.Center + Vector3.new(0, 22, 75), parent)
	billboard(a, "Sign", Config.Zones.HaloTown.Name, 0, RGB(255, 215, 90), 300, FAR_SIGN_MAX_DISTANCE)
	return a
end

local function buildHornsSign(ctx, parent)
	local a = signAnchor(ctx, "HornsSign", Config.Zones.HornsTown.Center + Vector3.new(0, 22, -75), parent)
	billboard(a, "Sign", Config.Zones.HornsTown.Name, 0, RGB(255, 100, 90), 300, FAR_SIGN_MAX_DISTANCE)
	return a
end

-- Part = true: a BasePart contract (other services read .Position / children)
local CONTRACT_LANDMARKS = {
	{ Name = "Fountain", Build = buildFountain },
	{ Name = "Altar", Build = buildAltar, Part = true },
	{ Name = "MostWantedBoard", Build = buildBoard, Part = true },
	{ Name = "GoosePerch", Build = buildGoosePerch },
}
local DECOR_LANDMARKS = {
	{ Name = "CrownShard", Build = buildCrownShard },
	{ Name = "ArtisanGuild", Build = buildArtisanGuild },
	{ Name = "Cathedral", Build = buildCathedral },
	{ Name = "MarketSign", Build = buildMarketSign },
	{ Name = "HaloSign", Build = buildHaloSign },
	{ Name = "HornsSign", Build = buildHornsSign },
}

local function ensureLandmarks(ctx, folder, withDecor)
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
	if withDecor then
		for _, def in DECOR_LANDMARKS do
			if not folder:FindFirstChild(def.Name) then
				def.Build(ctx, folder)
			end
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

------------------------------------------------------------------ decor (only when the Decor folder is empty)
local function makeClearAt()
	local keep = { Config.Map.AltarPosition, Config.Map.BoardPosition, Config.Goose.Position }
	for _, z in Config.Zones do
		table.insert(keep, z.Spawn)
	end
	for _, p in Config.Map.Pads do
		table.insert(keep, p.Position)
	end
	for _, g in Config.Map.Gates do
		table.insert(keep, g.Position)
	end
	local fountain = Config.Map.FountainPosition
	local cc = Config.Zones.Crossroads.Center
	local b = Config.Map.Bounds
	local halfDepth = math.max(math.abs(b.MinZ - cc.Z), math.abs(b.MaxZ - cc.Z))
	return function(pos, r)
		r = r or CLEAR_RADIUS
		for _, c in keep do
			if Util.FlatDistance(pos, c) < r then return false end
		end
		if Util.FlatDistance(pos, fountain) < PLAZA_RADIUS then return false end
		if math.abs(pos.Z - cc.Z) < ROAD_HALF_WIDTH and pos.X > cc.X + 60 then return false end -- east-west road
		if math.abs(pos.X - cc.X) < ROAD_HALF_WIDTH and math.abs(pos.Z - cc.Z) < halfDepth then return false end -- north-south road
		return true
	end
end

-- roads follow Config.Zones (east road one color per hunting zone; north = Halo, south = Horns)
local function buildRoads(ctx, decor)
	local roads = model("Roads", decor)
	local function road(name, fromV, toV, color, material)
		local size = Vector3.new(math.max(16, math.abs(toV.X - fromV.X)), 0.2, math.max(16, math.abs(toV.Z - fromV.Z)))
		return prop(ctx, {
			Name = name, Size = size, Position = (fromV + toV) / 2 + Vector3.new(0, 0.05, 0),
			Color = color, Material = material or Enum.Material.Ground,
		}, roads)
	end
	local cross = Config.Zones.Crossroads
	local cc = cross.Center
	local crossEast = cc.X + cross.Size.X / 2
	road("RoadCross", Vector3.new(cc.X + 12, 0, cc.Z), Vector3.new(crossEast, 0, cc.Z), RGB(176, 150, 110))
	local east = {
		{ "RoadMeadow", "SlimeMeadow", RGB(225, 200, 145), Enum.Material.Ground },
		{ "RoadWoods", "GoblinWoods", RGB(120, 95, 65), Enum.Material.Ground },
		{ "RoadRuins", "SkeletonRuins", RGB(185, 175, 150), Enum.Material.Slate },
	}
	for i, r in east do
		local z = Config.Zones[r[2]]
		if z then
			local minX = z.Center.X - z.Size.X / 2
			local maxX = (i == #east) and Config.Map.Bounds.MaxX or (z.Center.X + z.Size.X / 2)
			road(r[1], Vector3.new(minX, 0, cc.Z), Vector3.new(maxX, 0, cc.Z), r[3], r[4])
		end
	end
	local halo, horns = Config.Zones.HaloTown, Config.Zones.HornsTown
	local northEnd = halo.Center.Z - halo.Size.Z / 2
	local southEnd = horns.Center.Z + horns.Size.Z / 2
	local north = road("RoadNorth", Vector3.new(cc.X, 0, northEnd), Vector3.new(cc.X, 0, cc.Z - 10), RGB(240, 235, 220), SP)
	local south = road("RoadSouth", Vector3.new(cc.X, 0, cc.Z + 10), Vector3.new(cc.X, 0, southEnd), RGB(70, 45, 45), Enum.Material.Slate)
	for _, sx in { -7.2, 7.2 } do
		prop(ctx, {
			Name = "TrimGold", Size = Vector3.new(0.8, 0.22, north.Size.Z), Position = Vector3.new(cc.X + sx, 0.06, north.Position.Z),
			Color = RGB(212, 175, 55),
		}, roads)
		prop(ctx, {
			Name = "TrimRed", Size = Vector3.new(0.8, 0.22, south.Size.Z), Position = Vector3.new(cc.X + sx, 0.06, south.Position.Z),
			Color = RGB(200, 30, 40),
		}, roads)
	end
	road("RoadWest", Vector3.new(cc.X - 43, 0, cc.Z), Vector3.new(cc.X - 13, 0, cc.Z), RGB(175, 170, 160), SP) -- toward the market
end

-- stakes (danger-colored Neon tips) + a ground strip on the border of every PvP zone gate that crosses the east road
local function buildPvPBorders(ctx, decor)
	for _, entry in Config.Map.Gates do
		local zone = Config.Zones[entry.Zone]
		local alongX = zone and math.abs(zone.Center.X - entry.Position.X) >= math.abs(zone.Center.Z - entry.Position.Z)
		if zone and zone.PvP and alongX then
			local x = entry.Position.X
			local extreme = zone.MinLevel >= EXTREME_MIN_LEVEL
			local border = model("PvPBorder_" .. x, decor)
			for i = 0, 12 do
				local z = -60 + i * 10
				if math.abs(z) > 10 then
					local base = Vector3.new(x, 0, z)
					prop(ctx, {
						Name = "Stake", Size = Vector3.new(1.2, 5, 1.2),
						CFrame = CFrame.new(base + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(-15)),
						Color = RGB(110, 80, 50), Material = Enum.Material.Wood,
					}, border)
					prop(ctx, {
						Name = "StakeTip", Size = Vector3.new(1.2, 1, 1.2),
						CFrame = CFrame.new(base + Vector3.new(-1.3, 5.3, 0)) * CFrame.Angles(0, 0, math.rad(-15)),
						Color = dangerColor(zone), Material = NEON,
					}, border)
				end
			end
			prop(ctx, {
				Name = "BorderStrip", Size = Vector3.new(3, 0.1, 300), Position = Vector3.new(x + 4, 0.06, 0),
				Color = extreme and RGB(90, 30, 30) or RGB(90, 70, 50),
				Material = extreme and Enum.Material.CrackedLava or Enum.Material.Ground,
			}, border)
		end
	end
end

local function buildCrossroadsDecor(ctx, decor, clearAt)
	local cc = Config.Zones.Crossroads.Center
	local f = Config.Map.FountainPosition
	disc(ctx, f + Vector3.new(0, 0.05, 0), 52, 0.2, RGB(222, 214, 192), decor) -- plaza ring
	for _, bx in { -1, 1 } do -- 4 benches facing the fountain
		for _, bz in { -1, 1 } do
			local pos = f + Vector3.new(18 * bx, 1, 18 * bz)
			part(ctx, {
				Name = "Bench", Size = Vector3.new(6, 1, 2), CFrame = CFrame.lookAt(pos, f + Vector3.new(0, 1, 0)),
				Color = RGB(140, 100, 65), Material = Enum.Material.WoodPlanks,
			}, decor)
		end
	end
	for k = 0, 7 do -- 8 lamps on radius 32, angles that avoid the roads
		local a = math.rad(22.5 + 45 * k)
		local pos = f + Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
		if clearAt(pos, 8) then
			local lamp = model("Lamp", decor)
			prop(ctx, { Name = "Post", Size = Vector3.new(0.8, 9, 0.8), Position = pos + Vector3.new(0, 4.5, 0), Color = RGB(140, 100, 65), Material = Enum.Material.Wood }, lamp)
			local bulb = prop(ctx, { Name = "Lantern", Size = Vector3.new(1.4, 1.8, 1.4), Position = pos + Vector3.new(0, 9.6, 0), Color = RGB(255, 215, 150), Material = NEON }, lamp)
			if k % 2 == 0 then light(ctx, bulb, RGB(255, 220, 150), 14, 1.2) end
		end
	end
	-- market (north-west half circle facing the fountain)
	local stallColors = { RGB(220, 80, 80), RGB(80, 160, 220), RGB(240, 190, 60), RGB(110, 190, 90) }
	for i, o in { Vector3.new(-22, 0, -42), Vector3.new(-36, 0, -34), Vector3.new(-46, 0, -20), Vector3.new(-12, 0, -52) } do
		local pos = cc + o
		local stall = model("MarketStall", decor)
		local cf = CFrame.lookAt(pos, Vector3.new(f.X, pos.Y, f.Z))
		part(ctx, { Name = "Counter", Size = Vector3.new(10, 3, 4), CFrame = cf * CFrame.new(0, 1.5, 0), Color = RGB(140, 100, 65), Material = Enum.Material.WoodPlanks }, stall)
		for _, dx in { -4.5, 4.5 } do
			prop(ctx, { Name = "Post", Size = Vector3.new(0.6, 8, 0.6), CFrame = cf * CFrame.new(dx, 4, 1.5), Color = RGB(120, 85, 50), Material = Enum.Material.Wood }, stall)
		end
		part(ctx, {
			Name = "Roof", Size = Vector3.new(11, 0.6, 6), CFrame = cf * CFrame.new(0, 8.2, 0.5) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = stallColors[i], Material = Enum.Material.Fabric,
		}, stall)
	end
	-- faction pockets (north = Halo, south = Horns)
	for _, sx in { -12, 12 } do
		local hp = cc + Vector3.new(sx, 0, -60)
		prop(ctx, { Name = "HaloPole", Size = Vector3.new(0.6, 14, 0.6), Position = hp + Vector3.new(0, 7, 0), Color = RGB(212, 175, 55) }, decor)
		prop(ctx, { Name = "HaloFlag", Size = Vector3.new(0.2, 8, 4), Position = hp + Vector3.new(0, 9.5, 2.2), Color = RGB(140, 190, 255), Material = Enum.Material.Fabric }, decor)
		local rp = cc + Vector3.new(sx, 0, 60)
		prop(ctx, { Name = "HornsPole", Size = Vector3.new(0.6, 14, 0.6), Position = rp + Vector3.new(0, 7, 0), Color = RGB(35, 25, 30) }, decor)
		prop(ctx, { Name = "HornsFlag", Size = Vector3.new(0.2, 9, 4), Position = rp + Vector3.new(0, 9, 2.2), Color = RGB(130, 20, 25), Material = Enum.Material.Fabric }, decor)
		local side = sx > 0 and 3 or -3
		local brazier = prop(ctx, { Name = "Brazier", Size = Vector3.new(1.6, 1.2, 1.6), Position = rp + Vector3.new(side, 3.6, 0), Color = RGB(255, 90, 40), Material = NEON }, decor)
		prop(ctx, { Name = "BrazierStand", Size = Vector3.new(1.5, 3, 1.5), Position = rp + Vector3.new(side, 1.5, 0), Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, decor)
		if sx > 0 then light(ctx, brazier, RGB(255, 90, 40), 14, 1.5) end
	end
end

local function buildHaloTownDecor(ctx, decor, clearAt, rng)
	local hc = Config.Zones.HaloTown.Center
	local function haloTower(base, h)
		local tower = model("HaloTower", decor)
		cyl(ctx, { Name = "Plinth", Size = Vector3.new(10, 2, 10), Position = base + Vector3.new(0, 1, 0), Color = RGB(212, 175, 55) }, tower)
		cyl(ctx, { Name = "Body", Size = Vector3.new(8, h, 8), Position = base + Vector3.new(0, h / 2 + 2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, tower)
		cyl(ctx, { Name = "Band", Size = Vector3.new(8.6, 0.8, 8.6), Position = base + Vector3.new(0, h + 1.6, 0), Color = RGB(212, 175, 55) }, tower)
		part(ctx, {
			Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(8.5, 8.5, 8.5), Position = base + Vector3.new(0, h + 2, 0),
			Color = RGB(245, 242, 235), Material = Enum.Material.Marble,
		}, tower)
		ring(ctx, base + Vector3.new(0, h + 9, 0), 4.2, 8, Vector3.new(0.6, 0.6, 3.4), RGB(255, 225, 130), tower)
	end
	for _, o in { Vector3.new(-58, 0, -58), Vector3.new(58, 0, -58), Vector3.new(-58, 0, 48), Vector3.new(58, 0, 48) } do
		haloTower(hc + o, 26)
	end
	-- hero road: 3 pairs of statues between the gate and the spawn
	local roadX = Config.Zones.Crossroads.Center.X
	for _, dz in { 60, 40, 20 } do
		for _, x in { -13, 13 } do
			local st = model("HeroStatue", decor)
			local b = Vector3.new(roadX + x, 0, hc.Z + dz)
			part(ctx, { Name = "Base", Size = Vector3.new(4, 2, 4), Position = b + Vector3.new(0, 1, 0), Color = RGB(212, 175, 55) }, st)
			cyl(ctx, { Name = "Body", Size = Vector3.new(3, 7, 3), Position = b + Vector3.new(0, 5.5, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, st)
			part(ctx, {
				Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = b + Vector3.new(0, 10.2, 0),
				Color = RGB(245, 242, 235), Material = Enum.Material.Marble,
			}, st)
			cyl(ctx, { Name = "Halo", Size = Vector3.new(3.2, 0.3, 3.2), Position = b + Vector3.new(0, 12, 0), Color = RGB(255, 225, 130), Material = NEON, CanCollide = false }, st)
		end
	end
	-- cloud balls, flowers
	for _ = 1, 6 do
		local pos = hc + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
		if clearAt(pos, 14) then
			local s = rng:NextNumber(10, 16)
			prop(ctx, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = pos + Vector3.new(0, s * 0.2, 0), Color = RGB(250, 250, 255) }, decor)
		end
	end
	for _ = 1, 8 do
		local pos = hc + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
		if clearAt(pos, 10) then
			prop(ctx, { Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = pos + Vector3.new(0, 0.5, 0), Color = RGB(255, 170, 210) }, decor)
		end
	end
end

local function buildHornsTownDecor(ctx, decor, clearAt, rng)
	local rc = Config.Zones.HornsTown.Center
	for i = 1, 14 do -- ring of dark spikes
		local a = (i / 14) * math.pi * 2
		local pos = rc + Vector3.new(math.cos(a) * 62, 0, math.sin(a) * 62)
		if clearAt(pos) then
			local h = rng:NextNumber(12, 22)
			part(ctx, {
				Name = "Spike", Size = Vector3.new(4, h, 4),
				CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), a, math.rad(rng:NextNumber(-12, 12))),
				Color = RGB(45, 30, 35), Material = Enum.Material.Basalt,
			}, decor, "WedgePart")
		end
	end
	local function hornTower(base, h, tilt)
		local tw = model("HornTower", decor)
		local cf = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(tilt))
		part(ctx, { Name = "Body", Size = Vector3.new(7, h, 7), CFrame = cf * CFrame.new(0, h / 2, 0), Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, tw)
		for _, c in { Vector3.new(2.2, 0, 2.2), Vector3.new(-2.2, 0, 2.2), Vector3.new(2.2, 0, -2.2), Vector3.new(-2.2, 0, -2.2) } do
			prop(ctx, {
				Name = "Crown", Size = Vector3.new(2.5, 4, 2.5),
				CFrame = cf * CFrame.new(c + Vector3.new(0, h + 2, 0)) * CFrame.Angles(0, math.atan2(c.X, c.Z), 0),
				Color = RGB(60, 40, 45), Material = Enum.Material.Basalt,
			}, tw, "CornerWedgePart")
		end
		for k = 1, 3 do
			prop(ctx, { Name = "Window", Size = Vector3.new(0.4, 2, 0.2), CFrame = cf * CFrame.new(0, h * k / 4, -3.6), Color = RGB(255, 90, 40), Material = NEON }, tw)
		end
	end
	hornTower(rc + Vector3.new(45, 0, 55), 30, 8)
	hornTower(rc + Vector3.new(-50, 0, 40), 24, -7)
	hornTower(rc + Vector3.new(-45, 0, -45), 22, 6)
	for _, x in { -48, 48 } do -- two lava channels
		local lava = prop(ctx, { Name = "LavaChannel", Size = Vector3.new(3, 0.2, 130), Position = rc + Vector3.new(x, 0.08, 0), Color = RGB(255, 90, 40), Material = NEON }, decor)
		light(ctx, lava, RGB(255, 80, 30), 20, 1.5)
		prop(ctx, { Name = "ChannelRimL", Size = Vector3.new(1, 0.6, 130), Position = rc + Vector3.new(x - 2, 0.3, 0), Color = RGB(35, 25, 30), Material = Enum.Material.Basalt }, decor)
		prop(ctx, { Name = "ChannelRimR", Size = Vector3.new(1, 0.6, 130), Position = rc + Vector3.new(x + 2, 0.3, 0), Color = RGB(35, 25, 30), Material = Enum.Material.Basalt }, decor)
	end
	for _ = 1, 4 do
		local pos = rc + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-50, 50))
		if clearAt(pos, 14) then
			prop(ctx, {
				Name = "LavaCrack", Size = Vector3.new(rng:NextNumber(8, 14), 0.2, 2),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Color = RGB(255, 80, 30), Material = NEON,
			}, decor)
		end
	end
end

local function buildHuntingDecor(ctx, decor, clearAt, rng)
	local function tree(pos, scale, leaf1, leaf2, trunk)
		local t = model("Tree", decor)
		local h = 10 * scale
		part(ctx, { Name = "Trunk", Size = Vector3.new(2 * scale, h, 2 * scale), Position = pos + Vector3.new(0, h / 2, 0), Color = trunk, Material = Enum.Material.Wood }, t)
		prop(ctx, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9) * scale, Position = pos + Vector3.new(0, h + 1.5 * scale, 0), Color = leaf1 }, t)
		prop(ctx, {
			Name = "Leaves2", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6) * scale,
			Position = pos + Vector3.new(1.5 * scale, h + 5 * scale, 1 * scale), Color = leaf2,
		}, t)
	end
	local function scatter(zoneId, n, fn, r)
		local z = Config.Zones[zoneId]
		if not z then return end
		local placed = 0
		for _ = 1, n * 5 do
			if placed >= n then break end
			local pos = Vector3.new(
				z.Center.X + rng:NextNumber(-z.Size.X / 2 + 8, z.Size.X / 2 - 8),
				0,
				z.Center.Z + rng:NextNumber(-z.Size.Z / 2 + 8, z.Size.Z / 2 - 8)
			)
			if clearAt(pos, r or 14) then
				fn(pos)
				placed += 1
			end
		end
	end

	-- slime meadow: round, low, plump
	scatter("SlimeMeadow", 16, function(pos)
		tree(pos, rng:NextNumber(0.8, 1.15), RGB(120, 210, 90), RGB(95, 185, 75), RGB(130, 90, 55))
	end)
	scatter("SlimeMeadow", 12, function(pos)
		prop(ctx, { Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 4.5, 4.5), Position = pos + Vector3.new(0, 1, 0), Color = RGB(95, 185, 75) }, decor)
	end)
	local flowerColors = { RGB(255, 140, 190), RGB(255, 230, 90), RGB(170, 140, 255) }
	scatter("SlimeMeadow", 24, function(pos)
		prop(ctx, {
			Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = pos + Vector3.new(0, 0.6, 0),
			Color = flowerColors[rng:NextInteger(1, 3)],
		}, decor)
	end, 8)
	local meadow = Config.Zones.SlimeMeadow.Center
	prop(ctx, { Name = "SlimePond", Size = Vector3.new(36, 0.4, 24), Position = meadow + Vector3.new(-50, 0.1, -45), Color = RGB(90, 170, 230) }, decor)
	for k = 0, 7 do -- mushroom ring
		local a = k / 8 * math.pi * 2
		local pos = meadow + Vector3.new(20, 0, 55) + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10)
		prop(ctx, { Name = "MushStem", Size = Vector3.new(0.8, 1.6, 0.8), Position = pos + Vector3.new(0, 0.8, 0), Color = RGB(255, 250, 240) }, decor)
		prop(ctx, { Name = "MushCap", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = pos + Vector3.new(0, 1.7, 0), Color = RGB(255, 110, 110) }, decor)
	end
	part(ctx, {
		Name = "KingSlimeHill", Shape = Enum.PartType.Ball, Size = Vector3.new(50, 50, 50), Position = meadow + Vector3.new(90, -19, -45),
		Color = RGB(105, 185, 85), Material = Enum.Material.Grass,
	}, decor)

	-- goblin woods: big, dark, rough
	scatter("GoblinWoods", 30, function(pos)
		tree(pos, rng:NextNumber(1.3, 1.8), RGB(40, 90, 45), RGB(55, 110, 50), RGB(70, 50, 35))
	end, 13)
	local woods = Config.Zones.GoblinWoods.Center
	for _, o in { Vector3.new(-60, 0, -60), Vector3.new(30, 0, 50), Vector3.new(100, 0, -40) } do
		local cp = woods + o
		local camp = model("GoblinCamp", decor)
		part(ctx, {
			Name = "Tent", Size = Vector3.new(10, 7, 10), CFrame = CFrame.new(cp + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = RGB(140, 110, 70), Material = Enum.Material.Fabric,
		}, camp, "WedgePart")
		local fire = prop(ctx, { Name = "Campfire", Size = Vector3.new(2, 1, 2), Position = cp + Vector3.new(8, 0.5, 0), Color = RGB(255, 140, 40), Material = NEON }, camp)
		light(ctx, fire, RGB(255, 140, 40), 16, 1.5)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			prop(ctx, {
				Name = "Palisade", Size = Vector3.new(1, 5, 1),
				CFrame = CFrame.new(cp + Vector3.new(math.cos(a) * 14, 2.5, math.sin(a) * 14)) * CFrame.Angles(math.rad(10), a, 0),
				Color = RGB(110, 80, 50), Material = Enum.Material.Wood,
			}, camp)
		end
	end
	scatter("GoblinWoods", 6, function(pos) -- red eyes in the bushes
		prop(ctx, { Name = "DarkBush", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), Position = pos + Vector3.new(0, 1.5, 0), Color = RGB(30, 70, 35) }, decor)
		for _, ez in { -0.7, 0.7 } do
			prop(ctx, {
				Name = "RedEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Position = pos + Vector3.new(-2.9, 2, ez),
				Color = RGB(255, 40, 40), Material = NEON,
			}, decor)
		end
	end)

	-- skeleton ruins: broken and pale
	local pillarColors = { RGB(225, 220, 200), RGB(175, 170, 160) }
	scatter("SkeletonRuins", 18, function(pos)
		local h = rng:NextNumber(5, 18)
		part(ctx, {
			Name = "BrokenPillar", Size = Vector3.new(4, h, 4),
			CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))),
			Color = pillarColors[rng:NextInteger(1, 2)],
		}, decor)
	end)
	scatter("SkeletonRuins", 16, function(pos)
		prop(ctx, {
			Name = "Tombstone", Size = Vector3.new(3, 4, 1),
			CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, math.pi), 0),
			Color = RGB(110, 110, 120), Material = Enum.Material.Slate,
		}, decor)
	end, 10)
	scatter("SkeletonRuins", 6, function(pos)
		local wisp = prop(ctx, {
			Name = "SoulWisp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = pos + Vector3.new(0, 4, 0),
			Color = RGB(150, 110, 255), Material = NEON,
		}, decor)
		light(ctx, wisp, RGB(150, 110, 255), 14, 1.5)
	end)
	local ruins = Config.Zones.SkeletonRuins.Center
	for _, o in { Vector3.new(-40, 0, -70), Vector3.new(40, 0, 80), Vector3.new(100, 0, -60) } do -- broken arches
		local ap = ruins + o
		local arch = model("BrokenArch", decor)
		part(ctx, { Name = "L", Size = Vector3.new(3, 14, 3), Position = ap + Vector3.new(0, 7, -6), Color = RGB(225, 220, 200) }, arch)
		part(ctx, { Name = "R", Size = Vector3.new(3, 9, 3), Position = ap + Vector3.new(0, 4.5, 6), Color = RGB(225, 220, 200) }, arch)
		part(ctx, {
			Name = "Top", Size = Vector3.new(3, 2.5, 9), CFrame = CFrame.new(ap + Vector3.new(0, 14, -2)) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = RGB(205, 200, 180),
		}, arch)
	end
	for i = 1, 4 do -- torn flags
		local pos = ruins + Vector3.new(-100 + i * 55, 0, (i % 2 == 0) and 40 or -40)
		prop(ctx, { Name = "TornPole", Size = Vector3.new(0.6, 12, 0.6), Position = pos + Vector3.new(0, 6, 0), Color = RGB(60, 55, 55) }, decor)
		prop(ctx, { Name = "TornFlag", Size = Vector3.new(0.2, 6, 3.5), Position = pos + Vector3.new(0, 8.5, 2), Color = RGB(90, 70, 120), Material = Enum.Material.Fabric }, decor)
	end
end

local function buildDecor(ctx, decor)
	local rng = Random.new(DECOR_SEED)
	local clearAt = makeClearAt()
	-- random draws happen in the same order as tools/preview_map.lua (Halo -> Horns -> hunting grounds)
	buildRoads(ctx, decor)
	buildPvPBorders(ctx, decor)
	buildCrossroadsDecor(ctx, decor, clearAt)
	buildHaloTownDecor(ctx, decor, clearAt, rng)
	buildHornsTownDecor(ctx, decor, clearAt, rng)
	buildHuntingDecor(ctx, decor, clearAt, rng)
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
function MapBuilder.Build()
	local ctx = newCtx()
	local map = workspace:FindFirstChild("Map")
	local fresh = map == nil
	if fresh then
		map = Instance.new("Folder")
		map.Name = "Map" -- parented at the end: nobody sees (or touches) a half-built map
	end

	local folders = {}
	for _, name in FOLDER_NAMES do
		local folder, created = getChildFolder(map, name)
		folders[name] = folder
		if created and not fresh then ctx.pieces += 1 end
	end
	local decorEmpty = #folders.Decor:GetChildren() == 0

	ensureGround(ctx, folders.Ground)
	ensureZones(ctx, folders.Zones)
	ensureWalls(ctx, folders.Walls)
	ensureGates(ctx, folders.Gates)
	ensurePads(ctx, folders.Pads)
	ensureLandmarks(ctx, folders.Landmarks, decorEmpty)
	if decorEmpty then
		buildDecor(ctx, folders.Decor)
		if not fresh then ctx.pieces += 1 end
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
