-- MiniMap.luau : the live minimap in the HUD's top-left slot (SPEC_ADDENDUM A23-26 "실시간 지도").
-- Only my surroundings are shown (the whole world stays in WorldMap, A12): north up, my arrow turns. Marks: me, other
-- players (faction colour dots), the quest target (★ inside the view, a ▲ chevron on the edge outside it), the potion
-- merchant and the blacksmith anvil, and nearby monsters (small dots). Presentation only: no buttons and every instance
-- is Active = false, so on phones the box (inside the thumbstick zone) never sinks a touch.
-- Drawing: Config lands / zones / roads / bridges as axis-aligned Frames on one big canvas (Scale positions, like
-- WorldMap) inside a clipping view; per tick only the canvas moves. The box is C.HUD.Layout.Rects.minimap (logical
-- MainGui units), read again by MiniMap.Relayout (HUD calls it after each layout pass; also on viewport changes and
-- once a second). Rates: one Heartbeat with accumulators (move 20 Hz, scan + visibility 5 Hz, landmarks + layout 1 Hz).
--
-- Public API: MiniMap.Init(C), MiniMap.Start(), MiniMap.Relayout(), MiniMap.IsShown()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local MiniMap = {}

local TAG = "MiniMap"
local C = nil -- client registry (set in Init)
local UIKit = nil -- C.UIKit (set in Start)

----------------------------------------------------------------- tuning (du = logical MainGui units; studs)
local IS_TOUCH = UserInputService.TouchEnabled
local T = {
	Radius = IS_TOUCH and 80 or 110, -- studs from me to the view edge (px per stud = view width / (2 * Radius))
	Margin = 1.05, -- players / monsters inside the view box + 5% get a dot (the view clips the rest)
	MoveDt = 1 / 20, -- canvas, my arrow, quest marker
	ScanDt = 1 / 5, -- visibility, players, monsters, quest target
	SlowDt = 1, -- merchant / anvil, relayout
	MinMove = 0.25, -- du: smaller canvas / chevron moves are not written
	MinTurn = 1, -- degrees: smaller arrow turns are not written
	-- A23-40 layout B: a round map. Config.UIArt.Parts key MinimapRing (Firefly 83eaffb: navy ring + gold rims, the hole
	-- d386 of 512 at the centre); the view is a circle clipped by a CanvasGroup
	ArtKey = "MinimapRing",
	-- hole of the approved ring while the part has no Inner (63 .. 449 of 512)
	ArtInner = { 63 / 512, 63 / 512, 386 / 512, 386 / 512 },
	Bleed = 2, -- du the view reaches under the art rim (no seam along the hole's soft edge)
	Inset = IS_TOUCH and 4 or 6, -- view inset inside the code-drawn frame
	Corner = 12, -- code-drawn frame corner (like the other HUD panels)
	Arrow = IS_TOUCH and 16 or 18, -- >= 15 du on phones: MinTextSize 11 px at UIScale 0.75
	Star = IS_TOUCH and 15 or 16,
	Icon = IS_TOUCH and 14 or 16, -- potion merchant / anvil icons
	-- players vs monsters: Horns red is close to the monster red, so the size gap (and the players' outline) tells them apart
	PlayerDot = 9,
	MonsterDot = 5,
	BossDot = 10,
	MaxPlayers = 19,
	MaxMonsters = 30,
	WorldPad = 12, -- studs of sea around the drawn world (WorldMap WORLD_PAD)
	Shallow = 16, -- studs of lighter water around each land (WorldMap SHALLOW)
	PassCorridor = 20, -- road corridor |z| < 20 through the mountain pass (A10)
	ExtremeLevel = 25, -- PvP zones from this level use the extreme colour (WorldMap / MapBuilder)
	WarnEvery = 10, -- seconds between warnings
}

----------------------------------------------------------------- colours (WorldMap terrain palette, ART_DIRECTION 2.1 / 2.4)
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
	-- marks (Theme values copied in at build)
	Monster = Color3.fromRGB(255, 80, 80),
	Golden = Color3.fromRGB(255, 200, 30),
	Quest = Color3.fromRGB(255, 210, 60),
	Potion = Color3.fromRGB(80, 220, 120), -- dot only when the potion icon art is missing
	Smith = Color3.fromRGB(40, 200, 190), -- dot only when the sword icon art is missing (장인 길드 teal)
}

----------------------------------------------------------------- text (glyphs only; Util.GlyphSafe symbols)
local TXT = {
	Me = "▲", -- my arrow (points north at Rotation 0); always white, so it never looks like the gold quest chevron
	Quest = "★", -- quest target inside the view
	Edge = "▲", -- quest target outside: chevron on the view edge, turned toward it
}

----------------------------------------------------------------- state
-- drawn world rect (studs) and the Config pieces drawn on the canvas (prepareData)
local W = { MinX = -200, MaxX = 200, MinZ = -200, MaxZ = 200, Wd = 400, Ht = 400, Lands = {}, Zones = {}, Roads = {},
	Bridges = {}, PassX = nil }
local S = {
	built = false,
	shown = false,
	isArt = false,
	inner = nil, -- { x, y, w, h } scale of the art hole (UIKit.ArtInner)
	rectOk = false,
	rx = nil, ry = nil, side = nil, -- last applied box (du)
	lastTry = -math.huge, -- last relayout attempt while the rect was missing
	pps = 1, -- du per stud
	cx = 0, cy = 0, -- view centre (du, view space)
	halfX = 1, halfY = 1, -- half the visible hole (du)
	rangeX = 1, rangeZ = 1, -- studs from me that get a dot
	x = nil, z = nil, -- my last position
	ox = nil, oy = nil, -- last written canvas offset
	chevX = nil, chevY = nil, -- last written chevron offset
	questPos = nil,
	smithPos = nil, -- last seen anvil
	camConn = nil,
	lastWarnAt = -math.huge,
}
local ui = {} -- root, view, canvas, rim, me, star, chev, potion, smith
local pool = { players = {}, monsters = {} }
local acc = { Move = 0, Scan = 0, Slow = 0 }

----------------------------------------------------------------- helpers
local function warnThrottled(msg)
	local now = os.clock()
	if now - S.lastWarnAt < T.WarnEvery then return end
	S.lastWarnAt = now
	Util.Warn(TAG, msg)
end

local function guard(fn, what)
	local ok, err = pcall(fn)
	if not ok then warnThrottled(what .. " error: " .. tostring(err)) end
end

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function setVisible(inst, visible)
	if inst and inst.Visible ~= visible then inst.Visible = visible end
end

local function moduleOpen(name)
	local m = C and C[name]
	if type(m) ~= "table" or type(m.IsOpen) ~= "function" then return false end
	local ok, open = pcall(m.IsOpen)
	return ok and open == true
end

local function instPos(inst)
	if typeof(inst) ~= "Instance" then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		if inst.PrimaryPart then return inst.PrimaryPart.Position end
		local ok, cf = pcall(inst.GetPivot, inst)
		if ok and typeof(cf) == "CFrame" then return cf.Position end
	end
	return nil
end

-- canvas position of a world point (Scale, so a relayout only resizes the canvas)
local function toScale(pos)
	return UDim2.fromScale((pos.X - W.MinX) / W.Wd, (pos.Z - W.MinZ) / W.Ht)
end

local function factionColor(faction, none)
	local theme = UIKit and UIKit.Theme
	if type(theme) == "table" and (faction == "Halo" or faction == "Horns" or faction == "Neutral") then
		local c = theme[faction]
		if typeof(c) == "Color3" then return c end
	end
	return none
end

local function dangerColor(z)
	if not z.PvP then return COL.Safe end
	if z.MinLevel >= T.ExtremeLevel then return COL.Extreme end
	return COL.PvP
end

local function myPose()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp.Position, hrp.CFrame.LookVector end
	local cam = workspace.CurrentCamera
	if cam then return cam.Focus.Position, cam.CFrame.LookVector end
	return nil, nil
end

----------------------------------------------------------------- world data (Config -> drawable lists, WorldMap prepareData)
local function readRects(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for _, l in list do
		if type(l) == "table" then
			local a, b, c, d = num(l.MinX), num(l.MaxX), num(l.MinZ), num(l.MaxZ)
			if a and b and c and d and b > a and d > c then
				table.insert(out, { Name = tostring(l.Name or ""), MinX = a, MaxX = b, MinZ = c, MaxZ = d })
			end
		end
	end
	return out
end

local function prepareData()
	local map = type(Config.Map) == "table" and Config.Map or {}
	W.Lands = readRects(map.Lands)
	W.Roads = readRects(map.Roads) -- the strips preview_map builds as Decor.Roads (CR-L46)
	W.PassX = num(map.PassX)
	W.Bridges = {}
	for _, br in (type(map.Bridges) == "table" and map.Bridges or {}) do
		if type(br) == "table" and typeof(br.From) == "Vector3" and typeof(br.To) == "Vector3" then
			table.insert(W.Bridges, { Name = tostring(br.Name or ""), From = br.From, To = br.To,
				Width = math.max(4, num(br.Width, 18)) })
		end
	end
	W.Zones = {}
	local zones = type(Config.Zones) == "table" and Config.Zones or {}
	for _, id in (type(Config.ZoneOrder) == "table" and Config.ZoneOrder or {}) do
		local z = zones[id]
		if type(z) == "table" and typeof(z.Center) == "Vector3" and typeof(z.Size) == "Vector3" then
			table.insert(W.Zones, {
				Id = tostring(id),
				Center = z.Center,
				Size = z.Size,
				PvP = z.PvP == true,
				MinLevel = math.floor(num(z.MinLevel, 1)),
				FloorColor = typeof(z.FloorColor) == "Color3" and z.FloorColor or COL.Land,
			})
		end
	end

	-- drawn world = Bounds united with every land and zone, plus a little sea
	local b = type(map.Bounds) == "table" and map.Bounds or {}
	local minX, maxX = num(b.MinX, math.huge), num(b.MaxX, -math.huge)
	local minZ, maxZ = num(b.MinZ, math.huge), num(b.MaxZ, -math.huge)
	for _, l in W.Lands do
		minX, maxX = math.min(minX, l.MinX), math.max(maxX, l.MaxX)
		minZ, maxZ = math.min(minZ, l.MinZ), math.max(maxZ, l.MaxZ)
	end
	for _, z in W.Zones do
		minX, maxX = math.min(minX, z.Center.X - z.Size.X / 2), math.max(maxX, z.Center.X + z.Size.X / 2)
		minZ, maxZ = math.min(minZ, z.Center.Z - z.Size.Z / 2), math.max(maxZ, z.Center.Z + z.Size.Z / 2)
	end
	if not (maxX > minX and maxZ > minZ) then minX, maxX, minZ, maxZ = -200, 200, -200, 200 end
	W.MinX, W.MaxX = minX - T.WorldPad, maxX + T.WorldPad
	W.MinZ, W.MaxZ = minZ - T.WorldPad, maxZ + T.WorldPad
	W.Wd = math.max(1, W.MaxX - W.MinX)
	W.Ht = math.max(1, W.MaxZ - W.MinZ)
end

----------------------------------------------------------------- drawing (canvas children use Scale positions)
local function corner(scale, offset)
	return UIKit.Create("UICorner", { CornerRadius = UDim.new(scale or 0, offset or 0) })
end

local function stroke(color, thickness, transparency)
	return UIKit.Create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function rect(minX, maxX, minZ, maxZ, props, children)
	props.Position = UDim2.fromScale((minX - W.MinX) / W.Wd, (minZ - W.MinZ) / W.Ht)
	props.Size = UDim2.fromScale((maxX - minX) / W.Wd, (maxZ - minZ) / W.Ht)
	props.Active = false
	props.Parent = ui.canvas
	return UIKit.Create("Frame", props, children)
end

-- round dot (never a text glyph); outlined = dark rim for the player dots / icon stand-ins
local function newDot(name, size, color, zIndex, outlined)
	local kids = { corner(0.5, 0) }
	if outlined then table.insert(kids, stroke(BLACK, 1.5, 0.2)) end
	return UIKit.Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = zIndex,
		Active = false,
		Visible = false,
		Parent = ui.canvas,
	}, kids)
end

-- glyph mark (LightText: white-or-colour text with the dark HUD outline)
local function textMark(name, text, size, color, zIndex, parent)
	return UIKit.LightText({
		Name = name,
		Text = text,
		TextSize = size,
		Color = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = zIndex,
		Active = false,
		Visible = false,
		Parent = parent,
	})
end

-- approved item icon on the canvas, or a coloured dot while the art is missing (IMG-R4)
local function npcMark(name, artKey, color)
	local icon = UIKit.ArtImage(artKey, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(T.Icon, T.Icon),
		ZIndex = 6,
		Active = false,
		Visible = false,
		Parent = ui.canvas,
	})
	return icon or newDot(name, math.floor(T.Icon * 0.6), color, 6, true)
end

local function drawWorld()
	-- shallow water rings, then lands (rivers and sea are the gaps between them)
	for _, l in W.Lands do
		rect(l.MinX - T.Shallow, l.MaxX + T.Shallow, l.MinZ - T.Shallow, l.MaxZ + T.Shallow, {
			Name = "Shallow_" .. l.Name,
			BackgroundColor3 = COL.Shallow,
			BackgroundTransparency = 0.6,
			ZIndex = 1,
		}, { corner(0.14, 0) })
	end
	for _, l in W.Lands do
		local dark = string.find(l.Name, "Horns", 1, true) ~= nil
		rect(l.MinX, l.MaxX, l.MinZ, l.MaxZ, {
			Name = "Land_" .. l.Name,
			BackgroundColor3 = dark and COL.LandDark or COL.Land,
			ZIndex = 2,
		}, { corner(0.07, 0), stroke(COL.Coast, 1.5, 0.2) })
	end
	-- zones: floor colour + danger-colour border (ART_DIRECTION 2.4)
	for _, z in W.Zones do
		local hx, hz = z.Size.X / 2, z.Size.Z / 2
		rect(z.Center.X - hx, z.Center.X + hx, z.Center.Z - hz, z.Center.Z + hz, {
			Name = "Zone_" .. z.Id,
			BackgroundColor3 = z.FloorColor,
			BackgroundTransparency = 0.3,
			ZIndex = 3,
		}, { corner(0.08, 0), stroke(dangerColor(z), 2, 0.05) })
	end
	for i, r in W.Roads do
		rect(r.MinX, r.MaxX, r.MinZ, r.MaxZ, {
			Name = "Road" .. i,
			BackgroundColor3 = COL.Road,
			BackgroundTransparency = 0.15,
			ZIndex = 4,
		}, { corner(0.5, 0) })
	end
	-- mountain pass ridges (north and south of the road corridor)
	local px = W.PassX
	if px then
		for _, l in W.Lands do
			if px > l.MinX and px < l.MaxX and l.MinZ < -T.PassCorridor and l.MaxZ > T.PassCorridor then
				for _, span in { { l.MinZ + 6, -T.PassCorridor }, { T.PassCorridor, l.MaxZ - 6 } } do
					if span[2] - span[1] >= 4 then
						rect(px - 14, px + 14, span[1], span[2], {
							Name = "PassRidge",
							BackgroundColor3 = COL.Rock,
							ZIndex = 5,
						}, { corner(0.5, 0), stroke(BLACK, 1, 0.6) })
					end
				end
				break
			end
		end
	end
	-- bridges: axis-aligned only (a diagonal one would need a rotated Frame; none in Config v3)
	for i, br in W.Bridges do
		local f, t, w = br.From, br.To, br.Width
		local name = "Bridge_" .. (br.Name ~= "" and br.Name or tostring(i))
		local minX, maxX, minZ, maxZ = nil, nil, nil, nil
		if math.abs(t.Z - f.Z) < 0.5 then
			minX, maxX, minZ, maxZ = math.min(f.X, t.X), math.max(f.X, t.X), f.Z - w / 2, f.Z + w / 2
		elseif math.abs(t.X - f.X) < 0.5 then
			minX, maxX, minZ, maxZ = f.X - w / 2, f.X + w / 2, math.min(f.Z, t.Z), math.max(f.Z, t.Z)
		end
		if minX then
			rect(minX, maxX, minZ, maxZ, { Name = name, BackgroundColor3 = COL.Bridge, ZIndex = 5 },
				{ corner(0, 2), stroke(COL.BridgeEdge, 1, 0.1) })
		end
	end
end

local function build()
	UIKit = C and C.UIKit
	assert(type(UIKit) == "table" and UIKit.Gui, "UIKit is not initialized")
	local theme = UIKit.Theme
	local artCol = type(UIKit.ArtColors) == "table" and UIKit.ArtColors or {}
	if typeof(theme.Bad) == "Color3" then COL.Monster = theme.Bad end
	if typeof(theme.Gold) == "Color3" then COL.Quest = theme.Gold end
	if typeof(theme.Good) == "Color3" then COL.Potion = theme.Good end
	if typeof(theme.Neutral) == "Color3" then COL.Smith = theme.Neutral end
	local mc = type(Config.Monsters) == "table" and Config.Monsters or {}
	if typeof(mc.GoldenColor) == "Color3" then COL.Golden = mc.GoldenColor end

	-- frame: the approved MinimapRing art, else a navy disc with a gold rim (IMG-R4)
	local root, isArt = UIKit.ArtFrame(T.ArtKey, {
		Name = "MiniMap",
		Size = UDim2.fromOffset(100, 100), -- real box from Relayout
		ZIndex = 4,
		Active = false,
		Visible = false,
	}, {
		BackgroundColor3 = typeof(artCol.NavyDeep) == "Color3" and artCol.NavyDeep or theme.Bg,
		BackgroundTransparency = 0.04,
		CornerRadius = UDim.new(0.5, 0),
		StrokeColor = typeof(artCol.Gold) == "Color3" and artCol.Gold or theme.Gold,
		StrokeThickness = 2,
		StrokeTransparency = 0,
	})
	ui.root = root
	S.isArt = isArt == true
	if S.isArt then
		local ip, is = UIKit.ArtInner(T.ArtKey)
		if typeof(ip) == "UDim2" and typeof(is) == "UDim2" then
			S.inner = { ip.X.Scale, ip.Y.Scale, is.X.Scale, is.Y.Scale }
		end
	end
	pcall(function()
		root.Interactable = false -- never takes input (thumbstick zone on phones)
	end)

	-- view: a circle (CanvasGroup + UICorner clips the canvas round; a plain Frame would clip to its square) over the sea
	-- gradient (like WorldMap's map background; a gradient on the group itself would tint every mark, so it has its own
	-- frame)
	ui.view = UIKit.Create("CanvasGroup", {
		Name = "View",
		BackgroundTransparency = 1,
		ZIndex = 1,
		Active = false,
		Parent = root,
	}, {
		corner(0.5, 0),
	})
	UIKit.Create("Frame", {
		Name = "Sea",
		BackgroundColor3 = WHITE, -- tinted by the gradient
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Active = false,
		Parent = ui.view,
	}, {
		UIKit.Create("UIGradient", { Color = ColorSequence.new(COL.SeaTop, COL.SeaBottom), Rotation = 90 }),
	})
	ui.canvas = UIKit.Create("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		ZIndex = 1,
		Active = false,
		Parent = ui.view,
	})
	local okWorld, errWorld = pcall(drawWorld)
	if not okWorld then Util.Warn(TAG, "world drawing failed: " .. tostring(errWorld)) end

	-- art frame: the rim is drawn above the view (the holder image itself stays invisible, so the soft edge is not doubled)
	if S.isArt then
		root.ImageTransparency = 1
		ui.rim = UIKit.ArtImage(T.ArtKey, {
			Name = "Rim",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Active = false,
			Parent = root,
		})
		if not ui.rim then root.ImageTransparency = 0 end
	end

	-- marks: landmarks (6) < monsters (7) < players (8) < quest star (9) on the canvas; chevron and my arrow above it
	ui.potion = npcMark("PotionMerchant", "IconPotionHP", COL.Potion)
	ui.smith = npcMark("Blacksmith", "IconSword", COL.Smith)
	ui.star = textMark("Quest", TXT.Quest, T.Star, COL.Quest, 9, ui.canvas)
	ui.chev = textMark("QuestEdge", TXT.Edge, T.Star, COL.Quest, 2, ui.view)
	ui.me = textMark("Me", TXT.Me, T.Arrow, theme.Text, 3, ui.view)
	ui.me.Visible = true

	root.Parent = UIKit.Gui
	S.built = true
end

----------------------------------------------------------------- layout (C.HUD.Layout.Rects.minimap)
local function readRect()
	local hud = C and C.HUD
	local layout = type(hud) == "table" and hud.Layout or nil -- a new table every HUD layout pass: never cached
	local rects = type(layout) == "table" and layout.Rects or nil
	local r = type(rects) == "table" and rects.minimap or nil
	if type(r) ~= "table" then return nil end
	local x, y, w, h = num(r.X), num(r.Y), num(r.W), num(r.H)
	if not (x and y and w and h) or w < 16 or h < 16 then return nil end
	return x, y, w, h
end

local function relayout()
	if not ui.root then return end
	local x, y, w, h = readRect()
	if not (x and y and w and h) then
		S.rectOk, S.rx = false, nil
		S.shown = false
		setVisible(ui.root, false)
		return
	end
	S.rectOk = true
	local side = math.floor(math.min(w, h) + 0.5) -- square: the art frame is drawn with Fit
	x, y = math.floor(x + 0.5), math.floor(y + 0.5)
	if x == S.rx and y == S.ry and side == S.side then return end
	S.rx, S.ry, S.side = x, y, side
	ui.root.Position = UDim2.fromOffset(x, y)
	ui.root.Size = UDim2.fromOffset(side, side)

	-- the visible hole (du, root space); the art view bleeds a little under the rim
	local hx, hy, hw, hh
	if S.isArt then
		local r = S.inner or T.ArtInner
		hx, hy, hw, hh = r[1] * side, r[2] * side, r[3] * side, r[4] * side
	else
		hx, hy, hw, hh = T.Inset, T.Inset, side - 2 * T.Inset, side - 2 * T.Inset
	end
	hw, hh = math.max(4, hw), math.max(4, hh)
	local bleed = S.isArt and T.Bleed or 0
	ui.view.Position = UDim2.fromOffset(hx - bleed, hy - bleed)
	ui.view.Size = UDim2.fromOffset(hw + 2 * bleed, hh + 2 * bleed)
	S.cx, S.cy = hw / 2 + bleed, hh / 2 + bleed
	S.halfX, S.halfY = hw / 2, hh / 2
	S.pps = math.max(0.01, math.min(hw, hh) / (2 * T.Radius))
	S.rangeX, S.rangeZ = S.halfX / S.pps * T.Margin, S.halfY / S.pps * T.Margin
	ui.canvas.Size = UDim2.fromOffset(W.Wd * S.pps, W.Ht * S.pps)
	S.ox, S.chevX = nil, nil -- the next move tick writes the canvas / chevron again
end

----------------------------------------------------------------- live updates
local function questTarget()
	local hud = C and C.HUD
	if type(hud) ~= "table" or type(hud.GuideTarget) ~= "function" then return nil end
	local ok, p = pcall(hud.GuideTarget)
	if not ok then return nil end
	if typeof(p) == "Vector3" then return p end
	if typeof(p) == "CFrame" then return p.Position end
	return instPos(p)
end

local function merchantPos()
	local vit = type(Config.Vitals) == "table" and Config.Vitals or {}
	if vit.MerchantEnabled ~= true then return nil end -- MapBuilder builds the NPC only then
	local map = workspace:FindFirstChild("Map")
	local npcs = map and map:FindFirstChild("NPCs")
	local name = vit.PotionMerchantName
	local p = instPos(npcs and type(name) == "string" and npcs:FindFirstChild(name) or nil)
	if p then return p end
	-- the NPC is built after MapBuilder.Build returns: same spot as MapBuilder (Crossroads spawn + offset)
	local off = vit.PotionMerchantOffset
	local cross = type(Config.Zones) == "table" and Config.Zones.Crossroads or nil
	if type(off) == "table" and num(off.X) and num(off.Z) and type(cross) == "table" and typeof(cross.Spawn) == "Vector3" then
		return cross.Spawn + Vector3.new(off.X, 0, off.Z)
	end
	return nil
end

local function anvilPos()
	local map = workspace:FindFirstChild("Map")
	local lm = map and map:FindFirstChild("Landmarks")
	local guild = lm and lm:FindFirstChild("ArtisanGuild")
	local anvil = guild and guild:FindFirstChild("Anvil")
	if anvil and anvil:IsA("BasePart") then return anvil.Position end
	return nil
end

local function placeDot(dot, pos, color, size)
	dot.Position = toScale(pos)
	if dot.BackgroundColor3 ~= color then dot.BackgroundColor3 = color end
	if dot.Size.X.Offset ~= size then dot.Size = UDim2.fromOffset(size, size) end
	if not dot.Visible then dot.Visible = true end
end

local function hideRest(list, used)
	for i = used + 1, #list do
		setVisible(list[i], false)
	end
end

local function scanPlayers(x, z)
	local used = 0
	for _, p in Players:GetPlayers() do
		if used >= T.MaxPlayers then break end
		if p ~= LocalPlayer then
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and hrp and hrp:IsA("BasePart") then
				local pos = hrp.Position
				if math.abs(pos.X - x) <= S.rangeX and math.abs(pos.Z - z) <= S.rangeZ then
					used += 1
					local dot = pool.players[used]
					if not dot then
						dot = newDot("Player" .. used, T.PlayerDot, COL.Quest, 8, true)
						pool.players[used] = dot
					end
					placeDot(dot, pos, factionColor(p:GetAttribute("Faction"), UIKit.Theme.SubText), T.PlayerDot)
				end
			end
		end
	end
	hideRest(pool.players, used)
end

local function byDistance(a, b)
	return a[2] < b[2]
end

local function scanMonsters(x, z)
	local folder = workspace:FindFirstChild("Monsters")
	local list = {}
	if folder then
		local me = LocalPlayer.UserId
		local types = type(Config.MonsterTypes) == "table" and Config.MonsterTypes or {}
		for _, m in folder:GetChildren() do
			if m:IsA("Model") then
				local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
				-- anchored root = dying / leaving (MonsterService deathPop); owned spawns of other players stay hidden
				if root and root:IsA("BasePart") and not root.Anchored and m:GetAttribute("Leaving") ~= true then
					local owner = m:GetAttribute("OwnerUserId")
					if owner == nil or owner == me then
						local pos = root.Position
						local dx, dz = pos.X - x, pos.Z - z
						if math.abs(dx) <= S.rangeX and math.abs(dz) <= S.rangeZ then
							local def = types[m:GetAttribute("MonsterKind")]
							table.insert(list, { pos, dx * dx + dz * dz, m:GetAttribute("Golden") == true,
								type(def) == "table" and def.Boss == true })
						end
					end
				end
			end
		end
	end
	if #list > T.MaxMonsters then table.sort(list, byDistance) end
	local used = math.min(#list, T.MaxMonsters)
	for i = 1, used do
		local e = list[i]
		local dot = pool.monsters[i]
		if not dot then
			dot = newDot("Monster" .. i, T.MonsterDot, COL.Monster, 7, false)
			pool.monsters[i] = dot
		end
		placeDot(dot, e[1], e[3] and COL.Golden or COL.Monster, e[4] and T.BossDot or T.MonsterDot)
	end
	hideRest(pool.monsters, used)
end

-- 5 Hz: quest target (HUD.GuideTarget), other players, monsters
local function scan()
	local x, z = S.x, S.z
	if not x then return end
	local tp = questTarget()
	if tp then
		if not S.questPos or (tp - S.questPos).Magnitude > 0.5 then
			S.questPos = tp
			ui.star.Position = toScale(tp)
		end
	else
		S.questPos = nil
	end
	scanPlayers(x, z)
	scanMonsters(x, z)
end

-- quest target: ★ at its spot inside the view, else a ▲ chevron on the view edge turned toward it
local function placeQuest(x, z)
	local tp = S.questPos
	if not tp then
		setVisible(ui.star, false)
		setVisible(ui.chev, false)
		return
	end
	local vx, vy = (tp.X - x) * S.pps, (tp.Z - z) * S.pps
	local m = T.Star / 2 + 1
	-- the round view: inside the circle -> the star, else the chevron on the circle toward it
	local r = math.max(1, math.min(S.halfX, S.halfY) - m)
	local d = math.sqrt(vx * vx + vy * vy)
	if d <= r then
		setVisible(ui.chev, false)
		setVisible(ui.star, true)
		return
	end
	setVisible(ui.star, false)
	local t = r / math.max(d, 1e-3)
	local px, py = S.cx + vx * t, S.cy + vy * t
	if not S.chevX or math.abs(px - S.chevX) >= T.MinMove or math.abs(py - S.chevY) >= T.MinMove then
		S.chevX, S.chevY = px, py
		ui.chev.Position = UDim2.fromOffset(px, py)
	end
	local rot = math.deg(math.atan2(vx, -vy))
	if math.abs(rot - ui.chev.Rotation) >= T.MinTurn then ui.chev.Rotation = rot end
	setVisible(ui.chev, true)
end

-- 20 Hz: canvas under my position, my arrow, quest marker
local function moveStep()
	local pos, look = myPose()
	if not pos then return end
	S.x, S.z = pos.X, pos.Z
	local ox = S.cx - (pos.X - W.MinX) * S.pps
	local oy = S.cy - (pos.Z - W.MinZ) * S.pps
	if not S.ox or math.abs(ox - S.ox) >= T.MinMove or math.abs(oy - S.oy) >= T.MinMove then
		S.ox, S.oy = ox, oy
		ui.canvas.Position = UDim2.fromOffset(ox, oy)
	end
	if look and (look.X * look.X + look.Z * look.Z) > 1e-6 then
		-- "▲" points to -Z (map up) at Rotation 0; GUI rotation is clockwise (WorldMap updateArrow)
		local rot = math.deg(math.atan2(look.X, -look.Z))
		if math.abs(rot - ui.me.Rotation) >= T.MinTurn then ui.me.Rotation = rot end
	end
	placeQuest(pos.X, pos.Z)
end

-- 1 Hz: box, potion merchant, anvil
local function slowStep()
	relayout()
	if not S.rectOk then return end
	local mp = merchantPos()
	if mp then ui.potion.Position = toScale(mp) end
	setVisible(ui.potion, mp ~= nil)
	local sp = anvilPos()
	if sp then S.smithPos = sp end
	if S.smithPos then ui.smith.Position = toScale(S.smithPos) end
	setVisible(ui.smith, S.smithPos ~= nil)
end

-- HUD showing (HUD.IsVisible; without it: HUD has published Rects), world map closed, no panel over a phone screen
local function hudShowing()
	local hud = C and C.HUD
	if type(hud) ~= "table" then return false end
	if type(hud.IsVisible) == "function" then
		local ok, visible = pcall(hud.IsVisible)
		return ok and visible == true
	end
	local layout = hud.Layout
	return type(layout) == "table" and type(layout.Rects) == "table"
end

local function refreshVisibility()
	if not ui.root then return end
	local want = hudShowing() and not moduleOpen("WorldMap")
		and not (UserInputService.TouchEnabled and moduleOpen("Panels"))
	if want and not S.rectOk then
		local now = os.clock()
		if now - S.lastTry >= T.SlowDt then
			S.lastTry = now
			relayout()
		end
	end
	local show = want and S.rectOk
	if show == S.shown then return end
	S.shown = show
	ui.root.Visible = show
	if show then
		-- first frame after showing: box, landmarks and position at once (the scan follows in the same Heartbeat)
		S.ox, S.chevX = nil, nil
		acc.Move, acc.Slow = 0, 0
		slowStep()
		moveStep()
	end
end

local function onHeartbeat(dt)
	acc.Scan += dt
	if acc.Scan >= T.ScanDt then
		acc.Scan = 0
		guard(refreshVisibility, "visibility")
		if S.shown then guard(scan, "scan") end
	end
	if not S.shown then return end -- hidden: no work besides the visibility check
	acc.Slow += dt
	if acc.Slow >= T.SlowDt then
		acc.Slow = 0
		guard(slowStep, "landmark")
	end
	acc.Move += dt
	if acc.Move >= T.MoveDt then
		acc.Move = math.min(acc.Move - T.MoveDt, T.MoveDt)
		guard(moveStep, "move")
	end
end

local function bindCamera()
	if S.camConn then
		S.camConn:Disconnect()
		S.camConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		S.camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(MiniMap.Relayout) -- after HUD's own pass when it runs first; the 1 Hz step catches the rest
		end)
	end
end

----------------------------------------------------------------- public API
function MiniMap.Init(registry)
	C = registry
	local ok, err = pcall(prepareData)
	if not ok then Util.Warn(TAG, "map data failed: " .. tostring(err)) end
end

function MiniMap.Start()
	local ok, err = pcall(build)
	if not ok or not S.built then
		Util.Warn(TAG, "build failed: " .. tostring(err))
		return
	end
	RunService.Heartbeat:Connect(onHeartbeat)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
	MiniMap.Relayout()
	print("[MiniMap] started")
end

-- re-reads C.HUD.Layout.Rects.minimap (HUD calls this right after each layout pass); no rect = hidden
function MiniMap.Relayout()
	if not S.built then return end
	guard(relayout, "relayout")
end

function MiniMap.IsShown()
	return S.shown == true
end

return MiniMap
