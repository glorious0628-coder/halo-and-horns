-- WorldMap.luau : full-screen world map (SPEC_ADDENDUM A12, owner G13).
-- Players never see the whole world from the ground; this panel is the only place it is shown. Everything is drawn
-- from Config (lands, sea + rivers, zones with name / level / danger colour, roads, bridges, mountain pass, faction
-- town icons, Crossroads landmarks, the sky crown) plus live markers: the local player's arrow (10x/s while open),
-- the golden goose while GameState says it is active, the active kaiju and, for Halo players only, grudge-sack
-- carriers (the same attributes EventHUD reads). Pan by drag, zoom with wheel / pinch / buttons (0.5x-3x), close with
-- X / the map key (Keybinds "Map", default M) / Escape / gamepad B. Presentation only: reads attributes, never sends
-- anything to the server.
--
-- Public API: WorldMap.Init(C), WorldMap.Start(), WorldMap.Open(), WorldMap.Close(), WorldMap.Toggle(), WorldMap.IsOpen()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local WorldMap = {}

local TAG = "WorldMap"
local C = nil -- client registry (set in Init)

----------------------------------------------------------------- tuning (logical px = reference 1280x720 at UIScale 1)
local UI_CFG = Config.UI or {}
local MIN_TEXT = UI_CFG.MinTextSize or 11 -- addendum M1
local TOP_PAD = UI_CFG.TopInsetPad or 8 -- addendum H4
local TOP_FALLBACK = UI_CFG.TopInsetFallback or 64

local Z_ROOT = 60 -- above Panels (50), below UIKit toasts (95) and UIKit.Confirm (100)
local TICK = 0.1 -- arrow / marker refresh while open (10x/s)
local ZOOM_MIN, ZOOM_MAX = 0.5, 3
local ZOOM_STEP = 1.2 -- per wheel notch / button press
local PAN_MARGIN = 80 -- real px of sea allowed past the map edge when zoomed in
local SIDE_PAD, BOTTOM_PAD = 12, 12
local WORLD_PAD = 12 -- studs of sea around the drawn world
local ROAD_HALF = 7 -- studs
local SHALLOW = 16 -- studs of lighter shallow water around each land
local PASS_CORRIDOR = 20 -- road corridor |z| < 20 through the mountain pass (A10)
local MAX_SACKS = 10
local ICON_PPS = 0.55 -- logical px per stud from which Crossroads landmark icons are shown
local LABEL_PPS = 1.1 -- ... and their labels
local HINT_MIN_WIDTH = 760 -- logical px; the hint line hides on narrow screens
local EXTREME_MIN_LEVEL = 25 -- PvP zones from this level use the "extreme" danger colour (same rule as MapBuilder)

local ACTION_TOGGLE = "WorldMapToggle"
local ACTION_CLOSE = "WorldMapClose"
local ACTION_WHEEL = "WorldMapWheel"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 10

----------------------------------------------------------------- v3 world fallback (SPEC_ADDENDUM A10)
-- Used only while Config has not been patched to v3: Lands / Bridges individually when missing; when Config.Map.Lands
-- is missing the zone centers, Bounds and PassX also come from here so the drawing matches the v3 world in Studio.
local V3 = {
	Bounds = { MinX = -130, MaxX = 1320, MinZ = -520, MaxZ = 520 },
	PassX = 915,
	Lands = {
		{ Name = "LandCrossroads", MinX = -110, MaxX = 115, MinZ = -175, MaxZ = 175 },
		{ Name = "LandMeadow", MinX = 155, MaxX = 490, MinZ = -175, MaxZ = 175 },
		{ Name = "LandWild", MinX = 530, MaxX = 1300, MinZ = -175, MaxZ = 175 },
		{ Name = "IslandHalo", MinX = -110, MaxX = 110, MinZ = -500, MaxZ = -300 },
		{ Name = "IslandHorns", MinX = -110, MaxX = 110, MinZ = 300, MaxZ = 500 },
	},
	Bridges = {
		{ Name = "Meadow", From = Vector3.new(113, 0, 0), To = Vector3.new(157, 0, 0), Width = 18 },
		{ Name = "Goblin", From = Vector3.new(488, 0, 0), To = Vector3.new(532, 0, 0), Width = 18 },
		{ Name = "Halo", From = Vector3.new(0, 0, -173), To = Vector3.new(0, 0, -302), Width = 18 },
		{ Name = "Horns", From = Vector3.new(0, 0, 173), To = Vector3.new(0, 0, 302), Width = 18 },
	},
	ZoneCenters = {
		Crossroads = Vector3.new(0, 0, 0),
		HaloTown = Vector3.new(0, 0, -400),
		HornsTown = Vector3.new(0, 0, 400),
		SlimeMeadow = Vector3.new(330, 0, 0),
		GoblinWoods = Vector3.new(720, 0, 0),
		SkeletonRuins = Vector3.new(1120, 0, 0),
	},
}
-- Crossroads landmarks without a Config position (tools/preview_map.lua); the live workspace.Map wins when present
local MARKET_FALLBACK = Vector3.new(-30, 0, -36)
local GUILD_FALLBACK = Vector3.new(44, 0, 58)

----------------------------------------------------------------- colours (ART_DIRECTION 2.1 / 2.2 / 2.4)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local COL = {
	SeaTop = Color3.fromRGB(52, 112, 158),
	SeaBottom = Color3.fromRGB(22, 56, 96),
	Shallow = Color3.fromRGB(110, 175, 205),
	Land = Color3.fromRGB(104, 142, 82),
	LandDark = Color3.fromRGB(78, 58, 60), -- Horns island basalt
	Coast = Color3.fromRGB(222, 204, 150),
	Road = Color3.fromRGB(226, 205, 150),
	Bridge = Color3.fromRGB(150, 108, 66),
	BridgeEdge = Color3.fromRGB(70, 48, 30),
	Rock = Color3.fromRGB(112, 100, 92),
	Safe = Color3.fromRGB(80, 220, 120),
	PvP = Color3.fromRGB(255, 150, 40),
	Extreme = Color3.fromRGB(255, 60, 60),
	HaloGold = Color3.fromRGB(255, 215, 90),
	HornsRed = Color3.fromRGB(220, 50, 60),
	Teal = Color3.fromRGB(40, 200, 190), -- Neutral / 장인 길드 (A9-1)
	Crown = Color3.fromRGB(255, 215, 90),
	Altar = Color3.fromRGB(205, 175, 255),
	Market = Color3.fromRGB(255, 240, 180),
	Nest = Color3.fromRGB(255, 225, 120),
	Pad = Color3.fromRGB(80, 200, 255),
	Goose = Color3.fromRGB(255, 210, 60),
	Kaiju = Color3.fromRGB(255, 45, 45),
	Sack = Color3.fromRGB(185, 105, 255), -- same as EventHUD's sack purple
	BadgeBg = Color3.fromRGB(20, 20, 28),
	Bg = Color3.fromRGB(25, 25, 35),
	Text = WHITE,
	SubText = Color3.fromRGB(200, 200, 210),
	Gold = Color3.fromRGB(255, 210, 60),
	Button = Color3.fromRGB(70, 75, 95),
}
local ZONE_TITLE = { -- ART_DIRECTION 2.2 "존 타이틀 글자색"
	Crossroads = Color3.fromRGB(255, 240, 200),
	HaloTown = Color3.fromRGB(255, 215, 90),
	HornsTown = Color3.fromRGB(255, 100, 90),
	SlimeMeadow = Color3.fromRGB(120, 230, 150),
	GoblinWoods = Color3.fromRGB(255, 150, 50),
	SkeletonRuins = Color3.fromRGB(180, 120, 255),
}

----------------------------------------------------------------- text (A23-48: English only, glossary names)
local TXT = {
	Title = "World Map",
	Here = "You are in: %s",
	Unknown = "Unknown",
	ZoneSub = "Lv %d+ · %s",
	Safe = "Safe",
	PvP = "PvP",
	Extreme = "PvP Extreme",
	LegendSafe = "● Safe",
	LegendPvP = "● PvP",
	LegendExtreme = "● Extreme",
	LegendMe = "▲ Me",
	Locate = "Find Me",
	ZoomIn = "+",
	ZoomOut = "−",
	CloseX = "X",
	HintMouse = "Drag: move · Wheel: zoom · {Map} / Esc: close", -- {Map}: the current map key (WorldMap.HintText)
	HintTouch = "Drag: move · Two fingers: zoom",
	Crown = "Crown of Balance",
	Altar = "Altar of Fate",
	Market = "Market",
	Nest = "Golden Goose Nest",
	Pads = "Travel Pads",
	Guild = "Artisan Guild",
	Forge = "Forge", -- the same spot while the artisan guild is out of the game (Config.Features.NeutralFaction)
	Pass = "Mountain Pass",
	Goose = "Golden Goose!",
	Kaiju = "Kaiju %s",
	Sack = "Grudge Sack %s",
}

local GLYPH = {
	Crown = "✦",
	Halo = "◯", -- 후광
	Horns = "▲", -- 뿔
	Guild = "G", -- CR-L44: "⚙" rendered as a tofu box; replaced by Config.Factions.Neutral.Emblem below
	Altar = "◆",
	Market = "$", -- CR-L44 (was "⚖")
	Nest = "◎",
	Pad = "▣",
	Goose = "✪",
	Kaiju = "K", -- CR-L44 (was "☠")
	Sack = "◈",
	Me = "▲",
}
do -- CR-L44: the guild badge shows the Neutral emblem when the fonts can draw it (Util.GlyphSafe)
	local fac = type(Config.Factions) == "table" and Config.Factions.Neutral or nil
	local emblem = type(fac) == "table" and fac.Emblem or nil
	if type(emblem) == "string" and emblem ~= "" and type(Util.GlyphSafe) == "function" and Util.GlyphSafe(emblem) then
		GLYPH.Guild = emblem
	end
end

----------------------------------------------------------------- state
local dataReady = false
local built = false
local isOpen = false
local loopToken = 0
local toggleBound = false
local openActionsBound = false
local inputConnected = false

local W = { MinX = 0, MaxX = 1, MinZ = 0, MaxZ = 1 } -- drawn world rect (studs)
local worldW, worldH = 1, 1
local landsData, bridgesData, zonesData, roadsData = {}, {}, {}, {}
local passX = nil

local fontFace = Enum.Font.GothamBold
local ownGui = nil
local root, viewport, canvas = nil, nil, nil
local hereLabel, hintLabel, legendMe = nil, nil, nil
local ctl = {} -- CR-L41: Close / Locate / ZoomOut / ZoomIn buttons + Controls row and its List layout (resized in layoutRoot)
local me, meGlyph, mePulse = nil, nil, nil
local pulseTween = nil
local gooseMarker, kaijuMarker = nil, nil
local sackMarkers = {}
local zoneLabels = {} -- { Frame, WidthStuds }
local detailIcons, detailLabels = {}, {}
local detailIconsOn, detailLabelsOn = nil, nil
local zoneLabelKey = nil
local movable = {} -- landmark key -> { Items = { { Inst, Offset } } } (repositioned from the live map on open)

-- view: canvas top-left offset (ox, oy) in real px inside the viewport; px per stud = fit * zoom
local zoom = 1
local fit = 0
local ox, oy = 0, 0
local viewReady = false
local lastVp = nil

-- pointers
local touches = {} -- [InputObject] = Vector2 (absolute px)
local touchOrder = {}
local mouseDrag = false
local lastMouse = nil

----------------------------------------------------------------- helpers
local lastWarnAt = -math.huge
local function warnThrottled(msg)
	local now = os.clock()
	if now - lastWarnAt < 10 then return end
	lastWarnAt = now
	Util.Warn(TAG, msg)
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function kit()
	local k = C and C.UIKit
	if type(k) == "table" then return k end
	return nil
end

local function callModule(name, fnName, ...)
	local m = C and C[name]
	if type(m) ~= "table" or type(m[fnName]) ~= "function" then return false, nil end
	return pcall(m[fnName], ...)
end

local function moduleOpen(name)
	local ok, res = callModule(name, "IsOpen")
	return ok and res == true
end

local function pickersOpen()
	return moduleOpen("Intro") or moduleOpen("FactionPicker") or moduleOpen("ClassPicker")
end

local function panelsOpen()
	return moduleOpen("Panels")
end

local function closePanels()
	if panelsOpen() then callModule("Panels", "Close") end
end

local function gsAttr(name, default)
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	if not gs then return default end
	local v = gs:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function myAttr(name, default)
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function setText(lbl, text)
	if lbl and lbl.Text ~= text then lbl.Text = text end
end

local function setVisible(inst, visible)
	if inst and inst.Visible ~= visible then inst.Visible = visible end
end

local function rootOf(player)
	if not player or player.Parent == nil then return nil end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	return nil
end

local function insetVec()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and typeof(topLeft) == "Vector2" then return topLeft end
	return Vector2.zero
end

local function uiScaleFactor()
	local g = root and root.Parent
	local s = g and g:FindFirstChildOfClass("UIScale")
	local v = s and s.Scale or 1
	if type(v) ~= "number" or v <= 0 then v = 1 end
	return v
end

local function isGreyish(c)
	local hi = math.max(c.R, c.G, c.B)
	local lo = math.min(c.R, c.G, c.B)
	return hi - lo < 0.12
end

-- arrow colour: Halo gold / Horns red / Neutral teal (A9-1; grey is reserved, so a not-yet-patched grey Config value
-- falls back to the teal) / None white
local function factionColor(f)
	local fac = Config.Factions and Config.Factions[f]
	local c = type(fac) == "table" and fac.Color or nil
	if f == "Neutral" then
		local k = kit()
		local theme = k and k.Theme
		local tc = type(theme) == "table" and theme.Neutral or nil
		if typeof(tc) == "Color3" and not isGreyish(tc) then return tc end
		if typeof(c) == "Color3" and not isGreyish(c) then return c end
		return COL.Teal
	end
	if (f == "Halo" or f == "Horns") and typeof(c) == "Color3" then return c end
	if f == "Halo" then return COL.HaloGold end
	if f == "Horns" then return COL.HornsRed end
	return COL.Text
end

local function danger(z)
	if not z.PvP then return COL.Safe, TXT.Safe end
	if (z.MinLevel or 0) >= EXTREME_MIN_LEVEL then return COL.Extreme, TXT.Extreme end
	return COL.PvP, TXT.PvP
end

local function readTheme()
	local k = kit()
	local theme = k and k.Theme
	if type(theme) ~= "table" then return end
	if typeof(theme.Font) == "EnumItem" then fontFace = theme.Font end
	if typeof(theme.Bg) == "Color3" then COL.Bg = theme.Bg end
	if typeof(theme.Text) == "Color3" then COL.Text = theme.Text end
	if typeof(theme.SubText) == "Color3" then COL.SubText = theme.SubText end
	if typeof(theme.Gold) == "Color3" then COL.Gold = theme.Gold end
end

----------------------------------------------------------------- instance factories (UIKit when available)
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function new(className, props, children)
	local k = kit()
	if k and type(k.Create) == "function" then
		local ok, inst = pcall(k.Create, className, props, children)
		if ok and typeof(inst) == "Instance" then return inst end
	end
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then inst.BorderSizePixel = 0 end
	local isText = TEXT_CLASSES[className] == true
	if isText then
		inst.Font = fontFace
		inst.TextColor3 = COL.Text
	end
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	local hasConstraint = false
	for _, child in children or {} do
		if typeof(child) == "Instance" then
			if child:IsA("UITextSizeConstraint") then hasConstraint = true end
			child.Parent = inst
		end
	end
	if isText and not hasConstraint then
		local tc = Instance.new("UITextSizeConstraint")
		tc.MinTextSize = MIN_TEXT
		tc.Parent = inst
	end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(scale, offset)
	return new("UICorner", { CornerRadius = UDim.new(scale or 0, offset or 0) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- scaled text with a dark outline; every label keeps MinTextSize (M1)
local function label(props, maxText)
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	if props.TextScaled == nil then props.TextScaled = true end
	if props.TextStrokeTransparency == nil then props.TextStrokeTransparency = 0.35 end
	if props.TextStrokeColor3 == nil then props.TextStrokeColor3 = BLACK end
	if props.Font == nil then props.Font = fontFace end
	if props.Text == nil then props.Text = "" end
	local textLabel = new("TextLabel", props, {
		new("UITextSizeConstraint", { MinTextSize = MIN_TEXT, MaxTextSize = math.max(MIN_TEXT, maxText or 18) }),
	})
	-- Approved GPT lettering only: unknown/dynamic text and unavailable images keep the original label.
	local k = kit()
	if k and type(k.BindArtText) == "function" then pcall(k.BindArtText, textLabel) end
	return textLabel
end

local function button(props, onClick)
	local k = kit()
	if k and type(k.Button) == "function" then
		local ok, btn = pcall(k.Button, props, onClick)
		if ok and typeof(btn) == "Instance" then return btn end
	end
	local p = {}
	for key, value in props do
		if key == "Color" then
			p.BackgroundColor3 = value
		elseif key == "TextColor" then
			p.TextColor3 = value
		else
			p[key] = value
		end
	end
	p.AutoButtonColor = false
	if p.TextSize == nil then p.TextSize = 18 end
	if p.BackgroundColor3 == nil then p.BackgroundColor3 = COL.Button end
	local btn = new("TextButton", p, { corner(0, 12), stroke(BLACK, 2, 0.45) })
	btn.Activated:Connect(function()
		if type(onClick) ~= "function" then return end
		local ok, err = pcall(onClick, btn)
		if not ok then warnThrottled("button handler error: " .. tostring(err)) end
	end)
	return btn
end

----------------------------------------------------------------- world data (Config -> drawable lists)
local function readLands(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for _, l in list do
		-- A23-45: a seasonal land (the Halloween fields) is drawn only while its season is on
		if type(l) == "table" and (l.Season == nil or Config.SeasonOn(l.Season)) then
			local a, b, c, d = num(l.MinX), num(l.MaxX), num(l.MinZ), num(l.MaxZ)
			if a and b and c and d and b > a and d > c then
				table.insert(out, { Name = tostring(l.Name or ""), MinX = a, MaxX = b, MinZ = c, MaxZ = d })
			end
		end
	end
	return out
end

local function readBridges(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for _, br in list do
		if type(br) == "table" and typeof(br.From) == "Vector3" and typeof(br.To) == "Vector3" then
			table.insert(out, {
				Name = tostring(br.Name or ""),
				From = br.From,
				To = br.To,
				Width = math.max(4, num(br.Width, 18)),
			})
		end
	end
	return out
end

-- road pieces = the road band clipped to every land (bridges cover the water in between)
local function addRoad(alongX, fixed, from, to)
	local a, b = math.min(from, to), math.max(from, to)
	for _, l in landsData do
		if alongX then
			if fixed - ROAD_HALF < l.MaxZ and fixed + ROAD_HALF > l.MinZ then
				local s, e = math.max(a, l.MinX), math.min(b, l.MaxX)
				if e - s > 1 then
					table.insert(roadsData, { MinX = s, MaxX = e, MinZ = fixed - ROAD_HALF, MaxZ = fixed + ROAD_HALF })
				end
			end
		else
			if fixed - ROAD_HALF < l.MaxX and fixed + ROAD_HALF > l.MinX then
				local s, e = math.max(a, l.MinZ), math.min(b, l.MaxZ)
				if e - s > 1 then
					table.insert(roadsData, { MinX = fixed - ROAD_HALF, MaxX = fixed + ROAD_HALF, MinZ = s, MaxZ = e })
				end
			end
		end
	end
end

local function prepareData()
	local map = type(Config.Map) == "table" and Config.Map or {}
	landsData = readLands(map.Lands)
	local legacy = #landsData == 0 -- Config not patched to v3 yet
	if legacy then landsData = readLands(V3.Lands) end
	bridgesData = readBridges(map.Bridges)
	if #bridgesData == 0 then bridgesData = readBridges(V3.Bridges) end
	passX = num(map.PassX) or (legacy and V3.PassX or nil)

	zonesData = {}
	local zones = type(Config.Zones) == "table" and Config.Zones or {}
	for _, id in Config.ZoneOrder or {} do
		local z = zones[id]
		-- A23-45 / 3rd review: a seasonal zone (PumpkinPatch, HauntedHollow) leaves the map when its season ends
		if type(z) == "table" and typeof(z.Size) == "Vector3" and (z.Season == nil or Config.SeasonOn(z.Season)) then
			local center = (legacy and V3.ZoneCenters[id]) or z.Center
			if typeof(center) == "Vector3" then
				table.insert(zonesData, {
					Id = id,
					Name = tostring(z.Name or id),
					Center = center,
					Size = z.Size,
					MinLevel = math.floor(num(z.MinLevel, 1)),
					PvP = z.PvP == true,
					Town = z.Town == true,
					Faction = z.Faction,
					FloorColor = typeof(z.FloorColor) == "Color3" and z.FloorColor or COL.Land,
				})
			end
		end
	end

	-- drawn world = Bounds united with every land and zone, plus a little sea
	local b = (not legacy and type(map.Bounds) == "table") and map.Bounds or V3.Bounds
	local minX, maxX = num(b.MinX, V3.Bounds.MinX), num(b.MaxX, V3.Bounds.MaxX)
	local minZ, maxZ = num(b.MinZ, V3.Bounds.MinZ), num(b.MaxZ, V3.Bounds.MaxZ)
	for _, l in landsData do
		minX, maxX = math.min(minX, l.MinX), math.max(maxX, l.MaxX)
		minZ, maxZ = math.min(minZ, l.MinZ), math.max(maxZ, l.MaxZ)
	end
	for _, z in zonesData do
		minX, maxX = math.min(minX, z.Center.X - z.Size.X / 2), math.max(maxX, z.Center.X + z.Size.X / 2)
		minZ, maxZ = math.min(minZ, z.Center.Z - z.Size.Z / 2), math.max(maxZ, z.Center.Z + z.Size.Z / 2)
	end
	W = { MinX = minX - WORLD_PAD, MaxX = maxX + WORLD_PAD, MinZ = minZ - WORLD_PAD, MaxZ = maxZ + WORLD_PAD }
	worldW = math.max(1, W.MaxX - W.MinX)
	worldH = math.max(1, W.MaxZ - W.MinZ)

	-- roads: Config.Map.Roads (the strips preview_map builds as Decor.Roads; CR-L46)
	roadsData = legacy and {} or readLands(map.Roads)
	if #roadsData == 0 then
		-- fallback (Config without Roads): east-west from the Crossroads center to the far end of the hunting zones,
		-- north-south between the towns
		local hub, halo, horns, eastEnd = nil, nil, nil, nil
		for _, z in zonesData do
			if z.Id == "Crossroads" then hub = z end
			if z.Faction == "Halo" then halo = z end
			if z.Faction == "Horns" then horns = z end
			if not z.Town then
				local e = z.Center.X + z.Size.X / 2 - 12
				if not eastEnd or e > eastEnd then eastEnd = e end
			end
		end
		if hub and eastEnd then addRoad(true, hub.Center.Z, hub.Center.X, eastEnd) end
		if halo and horns then addRoad(false, halo.Center.X, halo.Center.Z, horns.Center.Z) end
	end

	dataReady = true
end

local function toUV(x, z)
	return (x - W.MinX) / worldW, (z - W.MinZ) / worldH
end

local function at(pos)
	local u, v = toUV(pos.X, pos.Z)
	return UDim2.fromScale(u, v)
end

local function landmarkPos(name)
	local map = workspace:FindFirstChild("Map")
	local lm = map and map:FindFirstChild("Landmarks")
	local inst = lm and lm:FindFirstChild(name)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(inst.GetPivot, inst)
		if ok and typeof(cf) == "CFrame" then return cf.Position end
	end
	return nil
end

local function goosePosition()
	local effects = workspace:FindFirstChild("Effects")
	local g = effects and effects:FindFirstChild("GoldenGoose")
	if g then
		if g:IsA("Model") then
			if g.PrimaryPart then return g.PrimaryPart.Position end
			local ok, cf = pcall(g.GetPivot, g)
			if ok and typeof(cf) == "CFrame" then return cf.Position end
		elseif g:IsA("BasePart") then
			return g.Position
		end
	end
	local gp = type(Config.Goose) == "table" and Config.Goose.Position or nil
	if typeof(gp) == "Vector3" then return gp end
	return nil
end

----------------------------------------------------------------- drawing (all canvas children use Scale positions)
local function rect(minX, maxX, minZ, maxZ, props, children)
	props.Position = UDim2.fromScale((minX - W.MinX) / worldW, (minZ - W.MinZ) / worldH)
	props.Size = UDim2.fromScale((maxX - minX) / worldW, (maxZ - minZ) / worldH)
	props.Parent = canvas
	return new("Frame", props, children)
end

local function remember(key, inst, offset)
	local entry = movable[key]
	if not entry then
		entry = { Items = {} }
		movable[key] = entry
	end
	table.insert(entry.Items, { Inst = inst, Offset = offset or UDim2.new() })
end

local function placeMovable(key, pos)
	local entry = movable[key]
	if not entry or typeof(pos) ~= "Vector3" then return end
	local base = at(pos)
	for _, item in entry.Items do
		item.Inst.Position = base + item.Offset
	end
end

-- round dark badge with a glyph (town icons): always visible
local function badge(key, glyph, color, pos, size)
	local f = new("Frame", {
		Name = "Badge_" .. key,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(pos),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = COL.BadgeBg,
		BackgroundTransparency = 0.2,
		ZIndex = 7,
		Parent = canvas,
	}, { corner(0.5, 0), stroke(color, 2, 0.05) })
	label({
		Name = "Glyph",
		Text = glyph,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		TextStrokeTransparency = 0.6,
		ZIndex = 7,
		Parent = f,
	}, math.floor(size * 0.75))
	remember(key, f)
	return f
end

-- small landmark glyph (icon tier) + caption under it (label tier)
local function landmark(key, glyph, color, pos, text, size)
	size = size or 20
	local icon = label({
		Name = "Icon_" .. key,
		Text = glyph,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(pos),
		Size = UDim2.fromOffset(size, size),
		TextStrokeTransparency = 0.15,
		ZIndex = 7,
		Parent = canvas,
	}, size)
	table.insert(detailIcons, icon)
	remember(key, icon)
	if text then
		local offset = UDim2.fromOffset(0, math.floor(size / 2) + 1)
		local cap = label({
			Name = "Label_" .. key,
			Text = text,
			TextColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = at(pos) + offset,
			Size = UDim2.fromOffset(110, 16),
			TextStrokeTransparency = 0.2,
			ZIndex = 8,
			Parent = canvas,
		}, 13)
		table.insert(detailLabels, cap)
		remember(key, cap, offset)
	end
	return icon
end

local function makeMarker(name, glyph, color, size)
	local f = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
		Parent = canvas,
	})
	label({
		Name = "Glyph",
		Text = glyph,
		TextColor3 = color,
		Size = UDim2.fromScale(1, 1),
		TextStrokeTransparency = 0,
		ZIndex = 9,
		Parent = f,
	}, size)
	local text = label({
		Name = "Text",
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(140, 16),
		TextStrokeTransparency = 0.15,
		ZIndex = 9,
		Parent = f,
	}, 14)
	return { Frame = f, Text = text }
end

local function drawWorld()
	-- shallow water rings, then lands (rivers and sea are the gaps between them)
	for _, l in landsData do
		rect(l.MinX - SHALLOW, l.MaxX + SHALLOW, l.MinZ - SHALLOW, l.MaxZ + SHALLOW, {
			Name = "Shallow_" .. l.Name,
			BackgroundColor3 = COL.Shallow,
			BackgroundTransparency = 0.6,
			ZIndex = 1,
		}, { corner(0.14, 0) })
	end
	for _, l in landsData do
		local dark = string.find(l.Name, "Horns", 1, true) ~= nil
		rect(l.MinX, l.MaxX, l.MinZ, l.MaxZ, {
			Name = "Land_" .. l.Name,
			BackgroundColor3 = dark and COL.LandDark or COL.Land,
			ZIndex = 2,
		}, { corner(0.07, 0), stroke(COL.Coast, 2, 0.2) })
	end

	-- zones: floor colour fill + danger-colour border (ART_DIRECTION 2.4)
	for _, z in zonesData do
		local col = danger(z)
		rect(z.Center.X - z.Size.X / 2, z.Center.X + z.Size.X / 2, z.Center.Z - z.Size.Z / 2, z.Center.Z + z.Size.Z / 2, {
			Name = "Zone_" .. z.Id,
			BackgroundColor3 = z.FloorColor,
			BackgroundTransparency = 0.3,
			ZIndex = 3,
		}, { corner(0.08, 0), stroke(col, 2.5, 0.05) })
	end

	-- roads, mountain pass, bridges
	for i, r in roadsData do
		rect(r.MinX, r.MaxX, r.MinZ, r.MaxZ, {
			Name = "Road" .. i,
			BackgroundColor3 = COL.Road,
			BackgroundTransparency = 0.15,
			ZIndex = 4,
		}, { corner(0.5, 0) })
	end
	if passX then
		for _, l in landsData do
			if passX > l.MinX and passX < l.MaxX and l.MinZ < -PASS_CORRIDOR and l.MaxZ > PASS_CORRIDOR then
				local rock = function(minZ, maxZ, name)
					if maxZ - minZ < 4 then return end
					rect(passX - 14, passX + 14, minZ, maxZ, {
						Name = name,
						BackgroundColor3 = COL.Rock,
						ZIndex = 5,
					}, { corner(0.5, 0), stroke(BLACK, 1, 0.6) })
				end
				rock(l.MinZ + 6, -PASS_CORRIDOR, "PassRidgeNorth")
				rock(PASS_CORRIDOR, l.MaxZ - 6, "PassRidgeSouth")
				local passLabel = label({
					Name = "PassLabel",
					Text = TXT.Pass,
					TextColor3 = Color3.fromRGB(235, 225, 210),
					AnchorPoint = Vector2.new(0.5, 1),
					Position = at(Vector3.new(passX, 0, -PASS_CORRIDOR - 4)),
					Size = UDim2.fromOffset(60, 16),
					TextStrokeTransparency = 0.2,
					ZIndex = 8,
					Parent = canvas,
				}, 13)
				table.insert(detailIcons, passLabel)
				break
			end
		end
	end
	for i, br in bridgesData do
		local f, t, w = br.From, br.To, br.Width
		local dx, dz = t.X - f.X, t.Z - f.Z
		local props = {
			Name = "Bridge_" .. (br.Name ~= "" and br.Name or tostring(i)),
			BackgroundColor3 = COL.Bridge,
			ZIndex = 5,
		}
		local kids = { corner(0, 2), stroke(COL.BridgeEdge, 1.5, 0.1) }
		if math.abs(dz) < 0.5 then
			rect(math.min(f.X, t.X), math.max(f.X, t.X), f.Z - w / 2, f.Z + w / 2, props, kids)
		elseif math.abs(dx) < 0.5 then
			rect(f.X - w / 2, f.X + w / 2, math.min(f.Z, t.Z), math.max(f.Z, t.Z), props, kids)
		else
			-- diagonal bridge: rotated bar (px per stud is equal on both axes, so Scale sizes keep the aspect)
			local len = math.sqrt(dx * dx + dz * dz)
			props.AnchorPoint = Vector2.new(0.5, 0.5)
			props.Position = at((f + t) / 2)
			props.Size = UDim2.fromScale(len / worldW, w / worldH)
			props.Rotation = math.deg(math.atan2(dz, dx))
			props.Parent = canvas
			new("Frame", props, kids)
		end
	end

	-- Crossroads landmarks (icon / label tiers)
	local mapCfg = type(Config.Map) == "table" and Config.Map or {}
	local altarPos = typeof(mapCfg.AltarPosition) == "Vector3" and mapCfg.AltarPosition or Vector3.new(0, 0, 45)
	landmark("Altar", GLYPH.Altar, COL.Altar, altarPos, TXT.Altar, 18)
	local marketPos = typeof(mapCfg.MarketPosition) == "Vector3" and mapCfg.MarketPosition or MARKET_FALLBACK
	if Config.FeatureOn("Market") then -- not in the beta: no "Market" on the map until it opens
		landmark("Market", GLYPH.Market, COL.Market, marketPos, TXT.Market, 18)
	end
	local nestPos = type(Config.Goose) == "table" and Config.Goose.Position or nil
	if typeof(nestPos) ~= "Vector3" then nestPos = Vector3.new(-30, 0, 30) end
	landmark("Nest", GLYPH.Nest, COL.Nest, nestPos, TXT.Nest, 18)
	local pads = type(mapCfg.Pads) == "table" and mapCfg.Pads or {}
	local padCount, padSum = 0, Vector3.zero
	for i, pad in pads do
		if type(pad) == "table" and typeof(pad.Position) == "Vector3" then
			landmark("Pad" .. i, GLYPH.Pad, COL.Pad, pad.Position, nil, 15)
			padCount += 1
			padSum += pad.Position
		end
	end
	if padCount > 0 then
		local mid = padSum / padCount
		local cap = label({
			Name = "Label_Pads",
			Text = TXT.Pads,
			TextColor3 = COL.Pad,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = at(mid) + UDim2.fromOffset(12, 0),
			Size = UDim2.fromOffset(90, 16),
			TextStrokeTransparency = 0.2,
			ZIndex = 8,
			Parent = canvas,
		}, 13)
		table.insert(detailLabels, cap)
	end

	-- faction town icons (후광 / 뿔 / 장인 길드 emblem) and the sky crown: always visible
	for _, z in zonesData do
		if z.Faction == "Halo" then
			badge("TownHalo", GLYPH.Halo, factionColor("Halo"), z.Center, 32)
		elseif z.Faction == "Horns" then
			badge("TownHorns", GLYPH.Horns, factionColor("Horns"), z.Center, 32)
		elseif z.Town then
			local pos = (z.Id == "Crossroads") and GUILD_FALLBACK or z.Center
			local key = (z.Id == "Crossroads") and "Guild" or ("Town" .. z.Id)
			badge(key, GLYPH.Guild, COL.Teal, pos, 28)
			if z.Id == "Crossroads" then
				local offset = UDim2.fromOffset(0, 15)
				local cap = label({
					Name = "Label_Guild",
					Text = Config.FeatureOn("NeutralFaction") and TXT.Guild or TXT.Forge,
					TextColor3 = Color3.fromRGB(120, 235, 225),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = at(pos) + offset,
					Size = UDim2.fromOffset(90, 16),
					TextStrokeTransparency = 0.2,
					ZIndex = 8,
					Parent = canvas,
				}, 13)
				table.insert(detailLabels, cap)
				remember("Guild", cap, offset)
			end
		end
	end
	local crownPos = typeof(mapCfg.FountainPosition) == "Vector3" and mapCfg.FountainPosition or Vector3.zero
	new("Frame", {
		Name = "CrownGlow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(crownPos),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = COL.Crown,
		BackgroundTransparency = 0.75,
		ZIndex = 7,
		Parent = canvas,
	}, { corner(0.5, 0) })
	label({
		Name = "Crown",
		Text = GLYPH.Crown,
		TextColor3 = COL.Crown,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(crownPos),
		Size = UDim2.fromOffset(34, 34),
		TextStrokeTransparency = 0.1,
		ZIndex = 7,
		Parent = canvas,
	}, 34)
	local crownCap = label({
		Name = "Label_Crown",
		Text = TXT.Crown,
		TextColor3 = COL.Crown,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = at(crownPos) + UDim2.fromOffset(0, 17),
		Size = UDim2.fromOffset(100, 16),
		TextStrokeTransparency = 0.15,
		ZIndex = 8,
		Parent = canvas,
	}, 13)
	table.insert(detailIcons, crownCap)

	-- zone captions: name (title colour) + "Lv N+ · 안전/PvP/PvP 극한" (danger colour), at the top inside each zone
	for _, z in zonesData do
		local col, word = danger(z)
		local box = new("Frame", {
			Name = "ZoneLabel_" .. z.Id,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = at(Vector3.new(z.Center.X, 0, z.Center.Z - z.Size.Z / 2 + z.Size.Z * 0.06)),
			Size = UDim2.fromOffset(140, 38),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Parent = canvas,
		})
		label({
			Name = "Name",
			Text = z.Name,
			TextColor3 = ZONE_TITLE[z.Id] or COL.Text,
			Size = UDim2.new(1, 0, 0, 21),
			TextStrokeTransparency = 0.1,
			ZIndex = 8,
			Parent = box,
		}, 18)
		label({
			Name = "Info",
			Text = string.format(TXT.ZoneSub, z.MinLevel, word),
			TextColor3 = col,
			Position = UDim2.fromOffset(0, 21),
			Size = UDim2.new(1, 0, 0, 16),
			TextStrokeTransparency = 0.1,
			ZIndex = 8,
			Parent = box,
		}, 14)
		table.insert(zoneLabels, { Frame = box, WidthStuds = z.Size.X })
	end

	-- live markers
	gooseMarker = makeMarker("GooseMarker", GLYPH.Goose, COL.Goose, 28)
	kaijuMarker = makeMarker("KaijuMarker", GLYPH.Kaiju, COL.Kaiju, 30)
	for i = 1, MAX_SACKS do
		sackMarkers[i] = makeMarker("SackMarker" .. i, GLYPH.Sack, COL.Sack, 22)
	end

	-- the local player's arrow (rotated glyph on a dark disc + pulse ring)
	me = new("Frame", {
		Name = "Me",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = canvas,
	})
	mePulse = new("Frame", {
		Name = "Pulse",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.45,
		ZIndex = 1,
		Parent = me,
	}, { corner(0.5, 0) })
	new("Frame", {
		Name = "Disc",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = COL.BadgeBg,
		BackgroundTransparency = 0.1,
		ZIndex = 2,
		Parent = me,
	}, { corner(0.5, 0), stroke(WHITE, 2, 0) })
	-- A23-51: the same arrow art as the live minimap (white + navy rim, tinted with my faction colour); "▲" without it
	local k = kit()
	local art = k and type(k.ArtImage) == "function" and k.ArtImage("MapPlayerArrow", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 3,
		Parent = me,
	}) or nil
	meGlyph = art or label({
		Name = "Arrow",
		Text = GLYPH.Me,
		TextColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		TextStrokeTransparency = 0,
		ZIndex = 3,
		Parent = me,
	}, 20)
end

----------------------------------------------------------------- view (pan / zoom)
local function vpSize()
	local s = viewport and viewport.AbsoluteSize
	if not s or s.X < 4 or s.Y < 4 then return nil end
	return s
end

local function clampAxis(o, content, view)
	if content <= view then return math.clamp(o, 0, view - content) end
	return math.clamp(o, view - content - PAN_MARGIN, PAN_MARGIN)
end

-- CR-L45: on short screens fit is small, so the fixed thresholds were never reached even at ZOOM_MAX; cap them by the
-- largest reachable px per stud (labels from 90% of max zoom, icons from half of it)
local function updateDetail(ppsL, vpWidthL, fitL)
	local maxL = math.max(0, fitL or 0) * ZOOM_MAX
	local icons = ppsL >= math.min(ICON_PPS, maxL * 0.5)
	local labels = ppsL >= math.min(LABEL_PPS, maxL * 0.9)
	if icons ~= detailIconsOn then
		detailIconsOn = icons
		for _, g in detailIcons do g.Visible = icons end
	end
	if labels ~= detailLabelsOn then
		detailLabelsOn = labels
		for _, g in detailLabels do g.Visible = labels end
	end
	local key = math.floor(ppsL * 50)
	if key ~= zoneLabelKey then
		zoneLabelKey = key
		for _, zl in zoneLabels do
			local w = math.clamp(zl.WidthStuds * ppsL * 0.95, 84, 200)
			zl.Frame.Size = UDim2.fromOffset(math.floor(w), 38)
		end
	end
	if hintLabel then setVisible(hintLabel, vpWidthL >= HINT_MIN_WIDTH) end
end

local function applyView()
	local vp = vpSize()
	if not vp or not canvas then return end
	fit = math.min(vp.X / worldW, vp.Y / worldH)
	local pps = fit * zoom
	local cw, ch = worldW * pps, worldH * pps
	if not viewReady then
		ox, oy = (vp.X - cw) / 2, (vp.Y - ch) / 2
		viewReady = true
	end
	ox = clampAxis(ox, cw, vp.X)
	oy = clampAxis(oy, ch, vp.Y)
	canvas.Size = UDim2.fromScale(cw / vp.X, ch / vp.Y)
	canvas.Position = UDim2.fromScale(ox / vp.X, oy / vp.Y)
	lastVp = vp
	local s = uiScaleFactor()
	updateDetail(pps / s, vp.X / s, fit / s) -- CR-L45
end

-- keeps the world point at the viewport center when the viewport changed size (rotation, resize, re-open)
local function refreshView()
	local vp = vpSize()
	if not vp then return end
	if viewReady and lastVp and lastVp ~= vp and fit > 0 then
		local oldPps = fit * zoom
		local cu = (lastVp.X / 2 - ox) / oldPps
		local cv = (lastVp.Y / 2 - oy) / oldPps
		local newPps = math.min(vp.X / worldW, vp.Y / worldH) * zoom
		ox = vp.X / 2 - cu * newPps
		oy = vp.Y / 2 - cv * newPps
	end
	applyView()
end

local function zoomAt(px, py, newZoom)
	newZoom = math.clamp(newZoom, ZOOM_MIN, ZOOM_MAX)
	if fit <= 0 then applyView() end
	if fit <= 0 or math.abs(newZoom - zoom) < 1e-4 then return end
	local oldPps = fit * zoom
	local su = (px - ox) / oldPps
	local sv = (py - oy) / oldPps
	zoom = newZoom
	local newPps = fit * zoom
	ox = px - su * newPps
	oy = py - sv * newPps
	applyView()
end

-- CR-L48: viewport top-left in real screen px (the space of GetMouseLocation and inputAbs). AbsolutePosition is measured
-- in GUI space, which starts below the top-bar inset whatever the gui's IgnoreGuiInset / ScreenInsets say (an element
-- at the very top of an IgnoreGuiInset gui reads Y = -inset), so add the inset back. Also exact when DeviceSafeInsets
-- (CR-L34) moves the gui content away from a notch.
local function viewportScreenPos()
	return viewport.AbsolutePosition + insetVec()
end

local function zoomAtAbs(abs, newZoom)
	if not viewport then return end
	local rel = abs - viewportScreenPos() -- CR-L48
	zoomAt(rel.X, rel.Y, newZoom)
end

local function zoomCenter(factor)
	local vp = vpSize()
	if not vp then return end
	zoomAt(vp.X / 2, vp.Y / 2, zoom * factor)
end

local function panBy(d)
	ox += d.X
	oy += d.Y
	applyView()
end

local function centerOn(pos, minZoom)
	local vp = vpSize()
	if not vp then return end
	fit = math.min(vp.X / worldW, vp.Y / worldH)
	zoom = math.clamp(math.max(zoom, minZoom or zoom), ZOOM_MIN, ZOOM_MAX)
	local pps = fit * zoom
	ox = vp.X / 2 - (pos.X - W.MinX) * pps
	oy = vp.Y / 2 - (pos.Z - W.MinZ) * pps
	viewReady = true
	applyView()
end

local function uvVisible(u, v)
	local vp = lastVp
	if not vp or fit <= 0 then return true end
	local pps = fit * zoom
	local px, py = ox + u * worldW * pps, oy + v * worldH * pps
	return px >= -4 and px <= vp.X + 4 and py >= -4 and py <= vp.Y + 4
end

local function pointInViewport(abs)
	if not viewport then return false end
	local p, s = viewportScreenPos(), viewport.AbsoluteSize -- CR-L48
	return abs.X >= p.X and abs.X <= p.X + s.X and abs.Y >= p.Y and abs.Y <= p.Y + s.Y
end

local function myPosition()
	local hrp = rootOf(LocalPlayer)
	if hrp then return hrp.Position, hrp.CFrame.LookVector end
	local cam = workspace.CurrentCamera
	if cam then return cam.Focus.Position, cam.CFrame.LookVector end
	return nil, nil
end

----------------------------------------------------------------- layout of the panel (top inset H4, UIScale aware)
local function layoutRoot()
	if not viewport then return end
	local s = uiScaleFactor()
	local topReal = math.max(TOP_FALLBACK, insetVec().Y + TOP_PAD)
	local top = math.floor(topReal / s + 0.5)
	viewport.Position = UDim2.fromOffset(SIDE_PAD, top)
	viewport.Size = UDim2.new(1, -2 * SIDE_PAD, 1, -(top + BOTTOM_PAD))

	-- CR-L41: on touch devices the buttons stay >= 44 real px (52 logical minimum) and keep a real gap between them
	local touch = UserInputService.TouchEnabled
	local btn = touch and math.max(52, math.ceil(44 / s)) or 52
	local gap = touch and math.max(8, math.ceil(8 / s)) or 8
	if ctl.Close then ctl.Close.Size = UDim2.fromOffset(btn, btn) end
	if ctl.Locate then ctl.Locate.Size = UDim2.fromOffset(112, btn) end
	if ctl.ZoomOut then ctl.ZoomOut.Size = UDim2.fromOffset(btn, btn) end
	if ctl.ZoomIn then ctl.ZoomIn.Size = UDim2.fromOffset(btn, btn) end
	if ctl.List then ctl.List.Padding = UDim.new(0, gap) end
	if ctl.Controls then ctl.Controls.Size = UDim2.fromOffset(112 + 2 * btn + 2 * gap, btn) end
end

----------------------------------------------------------------- pointer input (drag to pan, wheel / pinch to zoom)
local function resetPointers()
	table.clear(touches)
	table.clear(touchOrder)
	mouseDrag = false
	lastMouse = nil
end

local function removeTouch(input)
	if touches[input] == nil then return end
	touches[input] = nil
	local i = table.find(touchOrder, input)
	if i then table.remove(touchOrder, i) end
end

-- InputObject.Position is in GUI space (below the top-bar inset); add the inset for real screen px like
-- GetMouseLocation, then compare with viewportScreenPos() (CR-L48)
local function inputAbs(input)
	local p = input.Position
	return Vector2.new(p.X, p.Y) + insetVec()
end

local function onViewportInputBegan(input)
	if not isOpen then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		mouseDrag = true
		lastMouse = UserInputService:GetMouseLocation()
	elseif t == Enum.UserInputType.Touch then
		if touches[input] == nil then
			touches[input] = inputAbs(input)
			table.insert(touchOrder, input)
		end
	end
end

local function onViewportInputChanged(input)
	if not isOpen or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	local d = input.Position.Z
	if d == 0 then return end
	zoomAtAbs(UserInputService:GetMouseLocation(), zoom * (d > 0 and ZOOM_STEP or 1 / ZOOM_STEP))
end

local function onInputChanged(input)
	if not isOpen then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement then
		if mouseDrag and lastMouse then
			local p = UserInputService:GetMouseLocation()
			local d = p - lastMouse
			lastMouse = p
			if d.X ~= 0 or d.Y ~= 0 then panBy(d) end
		end
	elseif t == Enum.UserInputType.Touch then
		local old = touches[input]
		if not old then return end
		local newP = inputAbs(input)
		local a, b = touchOrder[1], touchOrder[2]
		if b then
			if input == a or input == b then
				local other = (input == a) and b or a
				local o = touches[other]
				if o then
					local oldMid, newMid = (old + o) / 2, (newP + o) / 2
					local oldDist, newDist = (old - o).Magnitude, (newP - o).Magnitude
					panBy(newMid - oldMid)
					if oldDist > 10 and newDist > 10 then
						zoomAtAbs(newMid, zoom * newDist / oldDist)
					end
				end
			end
		else
			panBy(newP - old)
		end
		touches[input] = newP
	end
end

local function onInputEnded(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		mouseDrag = false
		lastMouse = nil
	elseif t == Enum.UserInputType.Touch then
		removeTouch(input)
	end
end

----------------------------------------------------------------- ContextActionService bindings
local function onToggleAction(_, state, _input)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	local kb = C and C.Keybinds -- BB1: a key being captured in the settings is not a map press
	if type(kb) == "table" and type(kb.IsCapturing) == "function" and kb.IsCapturing() then return Enum.ContextActionResult.Pass end
	if not isOpen and pickersOpen() then return Enum.ContextActionResult.Pass end
	WorldMap.Toggle()
	return Enum.ContextActionResult.Sink
end

local function onCloseAction(_, state, _input)
	if isOpen and state == Enum.UserInputState.Begin then
		WorldMap.Close()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

-- while open, the wheel over the map zooms the map instead of the camera
local function onWheelAction(_, _state, input)
	if isOpen and input and input.UserInputType == Enum.UserInputType.MouseWheel
		and pointInViewport(UserInputService:GetMouseLocation()) then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function bindOpenActions()
	if openActionsBound then return end
	openActionsBound = true
	pcall(function()
		ContextActionService:BindActionAtPriority(ACTION_CLOSE, onCloseAction, false, ACTION_PRIORITY, Enum.KeyCode.ButtonB)
	end)
	pcall(function()
		ContextActionService:BindActionAtPriority(ACTION_WHEEL, onWheelAction, false, ACTION_PRIORITY, Enum.UserInputType.MouseWheel)
	end)
end

local function unbindOpenActions()
	if not openActionsBound then return end
	openActionsBound = false
	pcall(function()
		ContextActionService:UnbindAction(ACTION_CLOSE)
	end)
	pcall(function()
		ContextActionService:UnbindAction(ACTION_WHEEL)
	end)
end

----------------------------------------------------------------- build
local function getGuiRoot()
	local k = kit()
	local g = k and k.Gui
	if typeof(g) == "Instance" and g:IsA("LayerCollector") and g.Parent then return g end
	if ownGui and ownGui.Parent then return ownGui end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	ownGui = Instance.new("ScreenGui")
	ownGui.Name = "WorldMapGui"
	ownGui.ResetOnSpawn = false
	ownGui.IgnoreGuiInset = true
	-- CR-L34: keep the content inside the device safe area (phone notches); no full-screen extension past it
	pcall(function()
		ownGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	pcall(function()
		ownGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	end)
	ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ownGui.DisplayOrder = 12
	ownGui.Parent = pg
	return ownGui
end

local function connectInput()
	if inputConnected then return end
	inputConnected = true
	UserInputService.InputChanged:Connect(function(input)
		local ok, err = pcall(onInputChanged, input)
		if not ok then warnThrottled("input error: " .. tostring(err)) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		pcall(onInputEnded, input)
	end)
	-- Escape may be eaten by the Roblox menu (gameProcessed); close either way, and on MenuOpened below
	UserInputService.InputBegan:Connect(function(input)
		if isOpen and input.KeyCode == Enum.KeyCode.Escape then WorldMap.Close() end
	end)
	pcall(function()
		GuiService.MenuOpened:Connect(function()
			if isOpen then WorldMap.Close() end
		end)
	end)
	local function hookCamera(cam)
		if not cam then return end
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			-- UIKit updates its UIScale on the same signal; read it after that
			task.defer(function()
				if not isOpen then return end
				pcall(layoutRoot)
				pcall(refreshView)
			end)
		end)
	end
	hookCamera(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hookCamera(workspace.CurrentCamera)
	end)
end

local function build()
	if built then return true end
	if not dataReady then prepareData() end
	local gui = getGuiRoot()
	if not gui then return false end
	readTheme()

	root = new("TextButton", {
		Name = "WorldMap",
		Text = "",
		AutoButtonColor = false,
		Modal = true, -- frees the mouse (shift-lock) while the map is up
		Selectable = false,
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Z_ROOT,
		Visible = false,
	})

	viewport = new("TextButton", {
		Name = "Viewport",
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = WHITE, -- tinted by the sea gradient
		ClipsDescendants = true,
		Position = UDim2.fromOffset(SIDE_PAD, TOP_FALLBACK),
		Size = UDim2.new(1, -2 * SIDE_PAD, 1, -(TOP_FALLBACK + BOTTOM_PAD)),
		ZIndex = 1,
		Parent = root,
	}, {
		corner(0, 14),
		stroke(COL.Gold, 2, 0.25),
		new("UIGradient", { Color = ColorSequence.new(COL.SeaTop, COL.SeaBottom), Rotation = 90 }),
	})

	do
		local k = kit()
		if k and type(k.ArtImage) == "function" then
			pcall(k.ArtImage, "MapParchment", {
				Name = "Parchment",
				Size = UDim2.fromScale(1, 1),
				ScaleType = Enum.ScaleType.Crop,
				Active = false,
				ZIndex = 0,
				Parent = viewport,
			})
		end
	end

	canvas = new("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = viewport,
	})
	drawWorld()

	-- title pill (top-left): "세계 지도" + current location
	local titlePill = new("Frame", {
		Name = "TitlePill",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(270, 54),
		BackgroundColor3 = COL.Bg,
		BackgroundTransparency = 0.15,
		ZIndex = 5,
		Parent = viewport,
	}, { corner(0, 12), stroke(COL.Gold, 1.5, 0.35) })
	label({
		Name = "Title",
		Text = TXT.Title,
		TextColor3 = COL.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.new(1, -24, 0, 24),
		TextStrokeTransparency = 0.5,
		ZIndex = 5,
		Parent = titlePill,
	}, 22)
	hereLabel = label({
		Name = "Here",
		Text = string.format(TXT.Here, TXT.Unknown),
		TextColor3 = COL.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 18),
		TextStrokeTransparency = 0.6,
		ZIndex = 5,
		Parent = titlePill,
	}, 15)

	-- control hint (top-center)
	hintLabel = label({
		Name = "Hint",
		Text = WorldMap.HintText(),
		TextColor3 = COL.SubText,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(380, 20),
		TextStrokeTransparency = 0.3,
		ZIndex = 5,
		Parent = viewport,
	}, 15)

	-- close (top-right; sized for touch in layoutRoot, CR-L41)
	ctl.Close = button({
		Name = "Close",
		Text = TXT.CloseX,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(52, 52),
		Color = COL.Button,
		TextColor = COL.Text,
		TextSize = 26,
		ZIndex = 6,
		Parent = viewport,
	}, function()
		WorldMap.Close()
	end)

	-- legend (bottom-left)
	local legend = new("Frame", {
		Name = "Legend",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = COL.Bg,
		BackgroundTransparency = 0.15,
		ZIndex = 5,
		Parent = viewport,
	}, {
		corner(0, 10),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local legendItems = {
		{ TXT.LegendSafe, COL.Safe },
		{ TXT.LegendPvP, COL.PvP },
		{ TXT.LegendExtreme, COL.Extreme },
		{ TXT.LegendMe, factionColor(myAttr("Faction", "None")) },
	}
	for i, item in legendItems do
		local l = label({
			Name = "Legend" .. i,
			Text = item[1],
			TextColor3 = item[2],
			LayoutOrder = i,
			Size = UDim2.fromOffset(i == 4 and 54 or 68, 24),
			TextStrokeTransparency = 0.4,
			ZIndex = 5,
			Parent = legend,
		}, 16)
		if i == 4 then legendMe = l end
	end

	-- zoom / locate (bottom-right; row, gap and buttons are resized for touch in layoutRoot, CR-L41)
	ctl.List = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	local controls = new("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(240, 52),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = viewport,
	}, { ctl.List })
	ctl.Controls = controls
	ctl.Locate = button({
		Name = "Locate",
		Text = TXT.Locate,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(112, 52),
		Color = COL.Button,
		TextColor = COL.Text,
		TextSize = 18,
		ZIndex = 6,
		Parent = controls,
	}, function()
		local p = myPosition()
		if p then centerOn(p, 2) end
	end)
	ctl.ZoomOut = button({
		Name = "ZoomOut",
		Text = TXT.ZoomOut,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(52, 52),
		Color = COL.Button,
		TextColor = COL.Text,
		TextSize = 28,
		ZIndex = 6,
		Parent = controls,
	}, function()
		zoomCenter(1 / ZOOM_STEP)
	end)
	ctl.ZoomIn = button({
		Name = "ZoomIn",
		Text = TXT.ZoomIn,
		LayoutOrder = 3,
		Size = UDim2.fromOffset(52, 52),
		Color = COL.Button,
		TextColor = COL.Text,
		TextSize = 28,
		ZIndex = 6,
		Parent = controls,
	}, function()
		zoomCenter(ZOOM_STEP)
	end)

	viewport.InputBegan:Connect(function(input)
		pcall(onViewportInputBegan, input)
	end)
	viewport.InputChanged:Connect(function(input)
		local ok, err = pcall(onViewportInputChanged, input)
		if not ok then warnThrottled("wheel error: " .. tostring(err)) end
	end)
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if isOpen then pcall(refreshView) end
	end)

	root.Parent = gui
	connectInput()
	built = true
	return true
end

----------------------------------------------------------------- live updates (10x/s while open)
local function refreshLandmarks()
	placeMovable("Market", landmarkPos("MarketSign"))
	placeMovable("Guild", landmarkPos("ArtisanGuild"))
end

local function placeMarker(m, pos, text)
	local u, v = toUV(pos.X, pos.Z)
	m.Frame.Position = UDim2.fromScale(math.clamp(u, 0, 1), math.clamp(v, 0, 1))
	setText(m.Text, text)
	setVisible(m.Frame, true)
end

local function hideMarker(m)
	if m then setVisible(m.Frame, false) end
end

local function updateHeader()
	local zoneId = myAttr("ZoneId", nil)
	local z = type(zoneId) == "string" and type(Config.Zones) == "table" and Config.Zones[zoneId] or nil
	local name = (type(z) == "table" and type(z.Name) == "string") and z.Name or TXT.Unknown
	setText(hereLabel, string.format(TXT.Here, name))
end

local function updateArrow(faction)
	local pos, look = myPosition()
	if not pos then
		setVisible(me, false)
		return
	end
	local u, v = toUV(pos.X, pos.Z)
	u, v = math.clamp(u, 0, 1), math.clamp(v, 0, 1)
	me.Position = UDim2.fromScale(u, v)
	-- user 2026-10-06 ("시선에 따라서 꼭짓점이 변화해야지"): the arrow's tip shows where my CHARACTER faces (the root's
	-- LookVector) on this north-up map, the same rule as the live minimap's arrow
	if look and (look.X * look.X + look.Z * look.Z) > 1e-6 then
		-- "▲" points to -Z (map up) at Rotation 0; GUI rotation is clockwise
		meGlyph.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
	local col = factionColor(faction)
	if meGlyph:IsA("ImageLabel") then
		if meGlyph.ImageColor3 ~= col then meGlyph.ImageColor3 = col end
	elseif meGlyph.TextColor3 ~= col then
		meGlyph.TextColor3 = col
	end
	if mePulse.BackgroundColor3 ~= col then mePulse.BackgroundColor3 = col end
	if legendMe and legendMe.TextColor3 ~= col then legendMe.TextColor3 = col end
	setVisible(me, uvVisible(u, v))
end

local function updateMarkers(faction)
	-- golden goose (GameState GooseActive; position of workspace.Effects.GoldenGoose, else its nest)
	local gooseShown = false
	if gsAttr("GooseActive", false) == true then
		local p = goosePosition()
		if p then
			placeMarker(gooseMarker, p, TXT.Goose)
			gooseShown = true
		end
	end
	if not gooseShown then hideMarker(gooseMarker) end

	-- active kaiju (GameState KaijuPhase / KaijuUserId / KaijuName)
	local kaijuShown = false
	if gsAttr("KaijuPhase", "None") == "Active" then
		local id = num(gsAttr("KaijuUserId", 0), 0)
		local pl = id ~= 0 and Players:GetPlayerByUserId(id) or nil
		local r = rootOf(pl)
		if r then
			local name = gsAttr("KaijuName", "")
			if type(name) ~= "string" or name == "" then name = Util.PlayerDisplayName(pl) end
			placeMarker(kaijuMarker, r.Position, string.format(TXT.Kaiju, name))
			kaijuShown = true
		end
	end
	if not kaijuShown then hideMarker(kaijuMarker) end

	-- grudge-sack carriers: Halo only (player attribute SackGold > 0)
	local used = 0
	if faction == "Halo" then
		for _, p in Players:GetPlayers() do
			if used >= MAX_SACKS then break end
			if p ~= LocalPlayer then
				local gold = num(p:GetAttribute("SackGold"), 0)
				if gold > 0 then
					local r = rootOf(p)
					if r then
						used += 1
						placeMarker(sackMarkers[used], r.Position, string.format(TXT.Sack, Util.FormatNumber(gold)))
					end
				end
			end
		end
	end
	for i = used + 1, MAX_SACKS do
		hideMarker(sackMarkers[i])
	end
end

local function tick()
	if pickersOpen() then
		WorldMap.Close()
		return
	end
	-- CR-L47: a panel opened while the map is up (altar prompt, vacation popup) always wins. HUD no longer binds M,
	-- so the old KEY_GUARD only closed panels that had just opened on purpose.
	if panelsOpen() then
		WorldMap.Close()
		return
	end
	local faction = myAttr("Faction", "None")
	updateHeader()
	updateArrow(faction)
	updateMarkers(faction)
end

local function startLoop()
	loopToken += 1
	local token = loopToken
	task.spawn(function()
		while isOpen and loopToken == token do
			local ok, err = pcall(tick)
			if not ok then warnThrottled("update error: " .. tostring(err)) end
			task.wait(TICK)
		end
	end)
end

local function stopPulse()
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end
end

local function startPulse()
	stopPulse()
	if not mePulse then return end
	mePulse.Size = UDim2.fromOffset(26, 26)
	mePulse.BackgroundTransparency = 0.45
	pulseTween = TweenService:Create(mePulse, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), {
		Size = UDim2.fromOffset(58, 58),
		BackgroundTransparency = 1,
	})
	pulseTween:Play()
end

----------------------------------------------------------------- public API
function WorldMap.Init(registry)
	C = registry
	local ok, err = pcall(prepareData)
	if not ok then Util.Warn(TAG, "map data failed: " .. tostring(err)) end
end

function WorldMap.Start()
	local ok, err = pcall(build)
	if not ok then Util.Warn(TAG, "build failed: " .. tostring(err)) end

	-- the map key toggles the map (A12). Bound through ContextActionService so the key press reaches UserInputService
	-- listeners as gameProcessed. Ignored while typing in a TextBox. BB1: the key comes from Keybinds and is bound
	-- again whenever it changes.
	if not toggleBound then WorldMap.BindKey() end
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.Changed) == "table" then
		kb.Changed:Connect(function()
			local ok, err = pcall(WorldMap.BindKey)
			if not ok then Util.Warn(TAG, "map key rebind failed: " .. tostring(err)) end
		end)
	end

	print("[WorldMap] started")
end

-- BB1: (re)binds the toggle to Keybinds.Get("Map"); an unbound map key leaves only the button / X / Esc / pad B
function WorldMap.BindKey()
	local kb = C and C.Keybinds
	local code = (type(kb) == "table" and type(kb.Get) == "function") and kb.Get("Map") or nil
	if toggleBound and code == WorldMap.BoundKey then return end
	pcall(function()
		ContextActionService:UnbindAction(ACTION_TOGGLE)
	end)
	toggleBound, WorldMap.BoundKey = false, nil
	if code ~= nil then
		local okBind, errBind = pcall(function()
			ContextActionService:BindActionAtPriority(ACTION_TOGGLE, onToggleAction, false, ACTION_PRIORITY, code)
		end)
		toggleBound = okBind
		WorldMap.BoundKey = okBind and code or nil
		if not okBind then Util.Warn(TAG, "map key bind failed: " .. tostring(errBind)) end
	end
	if hintLabel and WorldMap.ShowsKeys() then
		hintLabel.Text = WorldMap.HintText()
	end
end

-- review B5: the one key-hint rule (Keybinds.ShowsKeys); before Keybinds is up, a keyboard is the test
function WorldMap.ShowsKeys()
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.ShowsKeys) == "function" then return kb.ShowsKeys() == true end
	return UserInputService.KeyboardEnabled == true
end

-- "{Map} / Esc: 닫기" with the current map key; without a map key only "Esc: 닫기"
function WorldMap.HintText()
	local kb = C and C.Keybinds
	if type(kb) ~= "table" or type(kb.Fill) ~= "function" or kb.KeyName("Map") == "" then
		return (string.gsub(TXT.HintMouse, "{Map} / ", ""))
	end
	return kb.Fill(TXT.HintMouse)
end

function WorldMap.Open()
	if isOpen then return end
	if pickersOpen() then return end -- the full-screen pickers own the screen
	if not built then
		local ok, err = pcall(build)
		if not ok then warnThrottled("build failed: " .. tostring(err)) end
		if not built then return end
	end
	closePanels() -- one modal at a time (also covers opening from the Menu panel)
	isOpen = true
	local panels = C and C.Panels
	if type(panels) == "table" and type(panels.Metric) == "function" then pcall(panels.Metric, "WorldMap") end -- BB38
	resetPointers()
	pcall(refreshLandmarks)
	pcall(layoutRoot)
	if hintLabel then
		hintLabel.Text = WorldMap.ShowsKeys() and WorldMap.HintText() or TXT.HintTouch
	end
	root.Visible = true
	pcall(refreshView)
	-- re-centre on the player when an earlier pan left them off-screen
	local p = myPosition()
	if p and viewReady and zoom > 1.001 then
		local u, v = toUV(p.X, p.Z)
		if not uvVisible(u, v) then pcall(centerOn, p) end
	end
	task.defer(function()
		if isOpen then pcall(refreshView) end -- AbsoluteSize settles after the first layout pass
	end)
	bindOpenActions()
	startPulse()
	startLoop()
end

function WorldMap.Close()
	if not isOpen then return end
	isOpen = false
	loopToken += 1
	resetPointers()
	unbindOpenActions()
	stopPulse()
	if root then root.Visible = false end
end

function WorldMap.Toggle()
	if isOpen then
		WorldMap.Close()
	else
		WorldMap.Open()
	end
end

function WorldMap.IsOpen()
	return isOpen
end

return WorldMap
