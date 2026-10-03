-- EventHUD.luau : event UI for Halo & Horns (G11).
-- Golden goose countdown chip / tug-of-war bar, kaiju chip + siren banner, screen-edge arrows (grudge sacks, kaiju,
-- revenge), the personal status line (sack / kaiju / revenge) and the Regular's Luck corner.
-- Reads only player attributes and GameState attributes; sends nothing to the server.
-- Look (A14-3, mockup art/out/UI_HUD_Final.png): parchment pills / panels and the navy BarTrack from UIKit's GPT
-- art parts; every part falls back to the code-drawn frame when its id is missing (IMG-R4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LocalPlayer = Players.LocalPlayer

local EventHUD = {}

local C = nil -- client registry (set in Init)

local IS_TOUCH = UserInputService.TouchEnabled -- same test as UIKit's scale / HUD's touch layout

----------------------------------------------------------------- layout (reference 1280x720 at UIScale 1)
local STRIP_Y = 64 -- event strip slot (just under HUD's 50 px war meter that starts at y 8; follows its real bottom)
local STRIP_W = 360 -- same width as the war meter
local BAR_H = 24
local SUB_H = 13
local GOOSE_CHIP_W = 196
local KAIJU_CHIP_W = IS_TOUCH and 200 or 150 -- touch: the 15 px minimum text needs the wider pill
local LUCK_Y = 52
local LUCK_W, LUCK_H = 210, 58
local LUCK_RIGHT = 12
local UI_CFG = Config.UI or {}
local TOP_PAD = UI_CFG.TopInsetPad or 8 -- addendum H4: top blocks start at inset + 8...
local TOP_FALLBACK = UI_CFG.TopInsetFallback or 64 -- ...or at 64 px when the inset is unknown
local MIN_TEXT_SIZE = UI_CFG.MinTextSize or 11 -- addendum M1
local PERSONAL_W, PERSONAL_H = 480, 30
local PERSONAL_Z = 6 -- CR-L37: above HUD's root frame (ZIndex 5), so quest rows / buttons never cover the sack timer
local SIREN_H = 64

local MAX_ARROWS = 10
local EDGE_MARGIN = 40 -- px from the screen edge (absolute pixels)
local LABEL_INSET = 40 -- px from an edge arrow toward the screen center
local ARROW_GLYPH_SIZE = 34
local ARROW_LABEL_W, ARROW_LABEL_H = 150, 20
local EDGE_GLYPH = "▶" -- points to +X at Rotation 0 (► is not in the fallback font)
local MARKER_GLYPH = "▼"

local TICK = 0.2
local LAYOUT_EVERY = 2

-- art layout (logical px at UIScale 1)
local L = {
	PillH = 28, -- goose countdown / kaiju pills
	IconW = 30, IconH = 34, -- goose icon sticking out of the pill's left end (mockup)
	StripGap = 6, -- gap under HUD's war meter
	SubHTouch = 15, -- tug hint line on touch (15 logical = 11 real px at UIScale 0.75)
	TugSide = 74, -- rescue / poach label width inside the tug bar (at the full STRIP_W; scales with the strip, CR-L36)
	StripMinW = 200, -- CR-L36: narrowest strip (HUD clamps its war meter to 200..WarW on narrow phones)
	Clover = 26,
	StarMax = 15, StarCap = 10,
	-- luck panel: fixed thin rim (PanelParchment rim = 19 / 24 image px at top / bottom -> 5.7 / 7.2 px) and the two
	-- line rows inside it
	LuckSlice = 0.3, LuckLine1Y = 9, LuckLine2Y = 29,
	KaijuNameMax = IS_TOUCH and 6 or 8, -- kaiju chip: longer names are cut ("Player..")
	TrimH = 3, -- siren gold trim
	ThumbW = 0.4, ThumbH = 0.45, -- U3: touch thumbstick zone = left 40% x bottom 45%
	ChipsY = 106, ChipsH = 32, -- HUD's status chip row (fallback while its frame is not found)
	MarkerLabelUp = 26, -- on-screen marker: its label's centre sits this far above the glyph's
}

----------------------------------------------------------------- colors / text
local WHITE = Color3.new(1, 1, 1)
local DEFAULT_BG = Color3.fromRGB(25, 25, 35)
local DEFAULT_BG_T = 0.25
local GOLD = Color3.fromRGB(255, 210, 60)
local KAIJU_RED = Color3.fromRGB(200, 30, 35)
local SIREN_RED = Color3.fromRGB(190, 20, 25)
local SACK_PURPLE = Color3.fromRGB(185, 105, 255) -- brighter than Config.Visuals.GrudgeSackColor for readability
local REVENGE_ORANGE = Color3.fromRGB(255, 150, 40)
local KAIJU_ARROW = Color3.fromRGB(255, 45, 45)

-- storybook palette: defaults, overwritten from UIKit.ArtColors (Config.UIArt.Colors) in readTheme
local AC = {
	Ink = Color3.fromRGB(66, 40, 18),
	InkSoft = Color3.fromRGB(122, 84, 46),
	LightSub = Color3.fromRGB(226, 222, 206),
	Gold = Color3.fromRGB(240, 190, 60),
	BadInk = Color3.fromRGB(190, 40, 40),
	WarHalo = Color3.fromRGB(252, 198, 52),
	WarHorns = Color3.fromRGB(243, 38, 44),
	-- not in ArtColors: ink versions of the status colours for text on parchment
	SackInk = (Config.Visuals and Config.Visuals.GrudgeSackColor) or Color3.fromRGB(110, 40, 150),
	RevengeInk = Color3.fromRGB(196, 92, 10),
	KaijuTint = Color3.fromRGB(255, 196, 186), -- ImageColor3 on the kaiju pill
}

-- private Korean strings (TECH_SPEC §4.23 EventHUD)
local TXT = {
	GooseNext = "황금 거위까지 %s",
	GooseTitle = "황금 거위 줄다리기! %s",
	Rescue = "구조 %d",
	Poach = "밀렵 %d",
	MyCount = "내 기여 %d",
	HintHalo = "거위를 때려 구조하세요!",
	HintHorns = "거위를 때려 밀렵하세요!",
	HintNeutral = "장인 길드는 줄다리기에 참여하지 않아요", -- addendum A6
	KaijuChip = "괴수 %s %s",
	SirenLeft = "%d초",
	Sack = "원한 자루 %s · %d초 (PvP 지역에서만 줄어요)",
	KaijuSelf = "괴수 변신 중! %s 버티면 전설의 악당",
	Revenge = "복수 대상: %s · %s",
	Luck = "단골 %d분 · 희귀 %s%%",
	Cheer = "응원별 %s (%d/%d)",
	CheerLabel = "응원별",
	CheerCount = "%d/%d",
	ArrowSack = "원한 자루 %s",
	ArrowKaiju = "괴수",
	ArrowRevenge = "복수",
	UnknownName = "???",
}

----------------------------------------------------------------- state
local ui = {}
local arrows = {}
local activeTargets = {}
local built = false
local loreShown = false
local gameState = nil
local lastLayoutKey = nil
local layoutTimer = 0
local fontFace = Enum.Font.GothamBold
local bgColor = DEFAULT_BG
local bgTransparency = DEFAULT_BG_T
local guiScale = nil -- UIScale under the gui (for clamping labels in absolute pixels)
local ownGui = nil
local textConstraints = {} -- { UITextSizeConstraint, baseMax } of every label (U5 touch minimum)
-- HUD frames the event UI lines up with: the strip sits under "WarMeter", the touch personal line under "StatusChips"
local hudRef = { WarMeter = { Conns = {} }, StatusChips = { Conns = {} } }
local layout -- forward declaration (assigned below)
-- CR-L43: top inset (real px) and raw GetGuiInset top-left cached by layout() for the per-frame arrow placement
local arrowGeo = { Inset = TOP_FALLBACK - TOP_PAD, TopLeft = nil }

----------------------------------------------------------------- helpers
local lastWarnAt = -math.huge
local function warnThrottled(msg)
	local now = os.clock()
	if now - lastWarnAt < 10 then return end
	lastWarnAt = now
	Util.Warn("EventHUD", msg)
end

local function num(v)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return 0
end

local function safeFormat(template, ...)
	if type(template) ~= "string" then return "" end
	local ok, s = pcall(string.format, template, ...)
	if ok then return s end
	return template
end

local function getGameState()
	if gameState and gameState.Parent then return gameState end
	gameState = ReplicatedStorage:FindFirstChild("GameState")
	return gameState
end

local function gsAttr(name, default)
	local gs = getGameState()
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

local function setText(label, text)
	if label.Text ~= text then label.Text = text end
end

local function setVisible(inst, visible)
	if inst and inst.Visible ~= visible then inst.Visible = visible end
end

local function uiToast(text, kind, duration)
	local kit = C and C.UIKit
	if not kit or type(kit.Toast) ~= "function" then return end
	local ok, err = pcall(kit.Toast, text, kind, duration)
	if not ok then warnThrottled("UIKit.Toast failed: " .. tostring(err)) end
end

local function pickersOpen()
	for _, name in { "FactionPicker", "ClassPicker" } do
		local m = C and C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			if ok and open == true then return true end
		end
	end
	return false
end

local function getRoot(player)
	if not player or player.Parent == nil then return nil end
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

local function getGuiRoot()
	local kit = C and C.UIKit
	local g = kit and kit.Gui
	if typeof(g) == "Instance" and g:IsA("LayerCollector") then return g end
	if ownGui and ownGui.Parent then return ownGui end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
	if not pg then return nil end
	ownGui = Instance.new("ScreenGui")
	ownGui.Name = "EventHUDGui"
	ownGui.ResetOnSpawn = false
	ownGui.IgnoreGuiInset = true
	pcall(function() -- CR-L34: keep the fallback layer inside the notch-safe area (set after IgnoreGuiInset)
		ownGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		ownGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	end)
	ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ownGui.DisplayOrder = 10
	ownGui.Parent = pg
	return ownGui
end

-- top inset in real px (fallback TopInsetFallback - TopInsetPad when unknown), plus the raw GetGuiInset top-left
-- (nil when unknown; CR-L43 maps viewport px onto the arrow layer with it)
local function insetY()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local raw = (ok and typeof(topLeft) == "Vector2") and topLeft or nil
	local y = raw and raw.Y or 0
	if y <= 0 then y = TOP_FALLBACK - TOP_PAD end
	return y, raw
end

local function currentScale()
	local s = (guiScale and guiScale.Parent and guiScale.Scale) or 1
	if s <= 0 then s = 1 end
	return s
end

----------------------------------------------------------------- instance factories (private)
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	if parent then inst.Parent = parent end
	return inst
end

local function makeLabel(props, maxText, parent)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = fontFace
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	for k, v in props do
		l[k] = v
	end
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = MIN_TEXT_SIZE
	c.MaxTextSize = math.max(MIN_TEXT_SIZE, maxText or 20)
	c.Parent = l
	table.insert(textConstraints, { c, c.MaxTextSize })
	if parent then l.Parent = parent end
	return l
end

local function makePanel(props, parent)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = bgColor
	f.BackgroundTransparency = bgTransparency
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	if parent then f.Parent = parent end
	return f
end

-- GPT art parts through UIKit (A14-3). Art.On = UIKit has the art API; each call is pcall'd and falls back to the
-- old dark panel / white label so the event UI never breaks.
local Art = { On = false }
local ART_ONLY_TEXT = { -- InkText / LightText keys that a plain TextLabel does not have
	MaxTextSize = true, Number = true, Title = true, Outline = true, OutlineTransparency = true,
	OutlineThickness = true, Color = true, TextColor = true,
}

-- 9-slice art frame (UIKit.ArtFrame: code-drawn parchment / navy frame when the id is missing)
function Art.frame(name, props, fallbackProps, parent)
	local kit = C and C.UIKit
	if Art.On then
		local ok, frame = pcall(kit.ArtFrame, name, props, fallbackProps)
		if ok and typeof(frame) == "Instance" then
			if parent then frame.Parent = parent end
			return frame
		end
		warnThrottled("ArtFrame " .. tostring(name) .. " failed: " .. tostring(frame))
	end
	local p = {}
	for k, v in props do
		if k ~= "SliceScale" then p[k] = v end -- image-only key; a plain Frame has no such property
	end
	return makePanel(p, parent)
end

-- icon / emblem ImageLabel, or nil when the part is missing (the caller lays out without it)
function Art.image(name, props, parent)
	local kit = C and C.UIKit
	if not Art.On then return nil end
	local ok, img = pcall(kit.ArtImage, name, props)
	if not ok or typeof(img) ~= "Instance" then return nil end
	if parent then img.Parent = parent end
	return img
end

-- uploaded id of a part (nil when missing)
function Art.id(name)
	local kit = C and C.UIKit
	if not Art.On or type(kit.ArtId) ~= "function" then return nil end
	local ok, id = pcall(kit.ArtId, name)
	if ok and type(id) == "string" and id ~= "" then return id end
	return nil
end

-- TextScaled label up to maxText: style "ink" (brown on parchment) or "light" (white, dark outline)
function Art.text(style, props, maxText, parent)
	local kit = C and C.UIKit
	local label = nil
	if Art.On then
		props.TextScaled = true
		props.MaxTextSize = maxText
		local fn = (style == "ink") and kit.InkText or kit.LightText
		local ok, l = pcall(fn, props)
		if ok and typeof(l) == "Instance" then
			label = l
			local c = l:FindFirstChildOfClass("UITextSizeConstraint")
			if c then table.insert(textConstraints, { c, math.max(MIN_TEXT_SIZE, maxText or c.MaxTextSize) }) end
		end
	end
	if not label then
		local p = {}
		for k, v in props do
			if not ART_ONLY_TEXT[k] and k ~= "TextScaled" then p[k] = v end
		end
		-- ink colours are unreadable on the old dark panel: keep white there
		local color = props.Color or props.TextColor
		if style ~= "ink" and typeof(color) == "Color3" then p.TextColor3 = color end
		label = makeLabel(p, maxText)
	end
	if parent then label.Parent = parent end
	return label
end

-- round capsule + glossy gradient on a bar fill
local function candyFill(fill)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
	}, fill)
end

-- U3: on touch, slide an edge arrow / label (screen px, centre) out of the thumbstick zone
local function outOfThumbZone(x, y, vp, padX, padY)
	if not IS_TOUCH then return x, y end
	local zx = vp.X * L.ThumbW + padX
	local zy = vp.Y * (1 - L.ThumbH) - padY
	if x >= zx or y <= zy then return x, y end
	if y - zy < zx - x then return x, zy end
	return zx, y
end

----------------------------------------------------------------- build
local function readTheme()
	local kit = C and C.UIKit
	if type(kit) ~= "table" then return end
	local theme = kit.Theme
	if type(theme) == "table" then
		if typeof(theme.Font) == "EnumItem" then fontFace = theme.Font end
		if typeof(theme.Bg) == "Color3" then bgColor = theme.Bg end
		if type(theme.BgTransparency) == "number" then bgTransparency = theme.BgTransparency end
	end
	Art.On = type(kit.ArtFrame) == "function" and type(kit.ArtImage) == "function"
		and type(kit.InkText) == "function" and type(kit.LightText) == "function"
	local colors = kit.ArtColors
	if type(colors) == "table" then
		for key in AC do
			if typeof(colors[key]) == "Color3" then AC[key] = colors[key] end
		end
	end
end

local function build()
	local root = getGuiRoot()
	if not root then
		Util.Warn("EventHUD", "no ScreenGui available; event UI not built")
		return
	end
	readTheme()
	guiScale = root:FindFirstChildOfClass("UIScale")

	-- screen-edge arrows: full-screen layer, ZIndex 1, pooled
	ui.Arrows = make("Frame", {
		Name = "EventArrows",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Active = false,
	}, root)
	for i = 1, MAX_ARROWS do
		local glyph = makeLabel({
			Name = "ArrowGlyph" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(ARROW_GLYPH_SIZE, ARROW_GLYPH_SIZE),
			Text = EDGE_GLYPH,
			TextStrokeTransparency = 0.15,
			Visible = false,
			ZIndex = 1,
		}, ARROW_GLYPH_SIZE, ui.Arrows)
		local label = makeLabel({
			Name = "ArrowLabel" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(ARROW_LABEL_W, ARROW_LABEL_H),
			TextStrokeTransparency = 0.25,
			Visible = false,
			ZIndex = 1,
		}, 16, ui.Arrows)
		arrows[i] = { Glyph = glyph, Label = label }
	end

	-- event strip (top-center, right under HUD's war meter: war bar > war timer > goose pill > HUD's status chips)
	local subH = IS_TOUCH and L.SubHTouch or SUB_H
	ui.Strip = make("Frame", {
		Name = "EventStrip",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, STRIP_Y),
		Size = UDim2.fromOffset(STRIP_W, math.max(L.PillH, BAR_H + subH)),
		ZIndex = 3,
	}, root)

	-- goose countdown: parchment pill + goose icon + ink text ("황금 거위까지 3:24")
	ui.GooseChip = Art.frame("Pill", {
		Name = "GooseChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(GOOSE_CHIP_W, L.PillH),
		Visible = false,
		ZIndex = 3,
	}, { CornerRadius = UDim.new(0.5, 0) }, ui.Strip)
	local gooseIcon = Art.image("IconGoose", {
		Name = "GooseIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -6, 0.5, -1),
		Size = UDim2.fromOffset(L.IconW, L.IconH),
		ZIndex = 5,
	}, ui.GooseChip)
	local chipTextX = gooseIcon and 28 or 12
	ui.GooseChipText = Art.text("ink", {
		Name = "Text",
		Position = UDim2.fromOffset(chipTextX, 4),
		Size = UDim2.new(1, -chipTextX - 12, 1, -8),
		ZIndex = 4,
	}, 16, ui.GooseChip)
	if not Art.On then ui.GooseChipText.TextColor3 = GOLD end

	-- goose tug-of-war: navy BarTrack capsule, gold rescue fill over the red poach fill. As wide as the strip, which
	-- layout() narrows on small phones (CR-L36), so every piece inside is sized in scale.
	ui.Tug = Art.frame("BarTrack", {
		Name = "GooseTug",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, BAR_H),
		Visible = false,
		ZIndex = 3,
	}, { CornerRadius = UDim.new(0.5, 0) }, ui.Strip)
	-- navy interior from the BarTrack Inner rect (vertical insets scale with the height, side insets in height units)
	local insetTop, insetBottom, insetSide = 0.18, 0.19, 0.21
	local parts = type(Config.UIArt) == "table" and Config.UIArt.Parts or nil
	local track = type(parts) == "table" and parts.BarTrack or nil
	if type(track) == "table" and typeof(track.Inner) == "Rect" and typeof(track.Size) == "Vector2" and track.Size.Y > 0 then
		insetTop = track.Inner.Min.Y / track.Size.Y
		insetBottom = (track.Size.Y - track.Inner.Max.Y) / track.Size.Y
		insetSide = track.Inner.Min.X / track.Size.Y
	end
	local sidePx = math.floor(insetSide * BAR_H + 0.5)
	ui.TugInner = make("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, sidePx, insetTop, 0),
		Size = UDim2.new(1, -2 * sidePx, 1 - insetTop - insetBottom, 0),
		ZIndex = 3,
	}, ui.Tug)
	ui.TugRight = make("Frame", {
		Name = "PoachFill",
		BackgroundColor3 = AC.WarHorns,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, ui.TugInner)
	candyFill(ui.TugRight)
	ui.TugLeft = make("Frame", {
		Name = "RescueFill",
		BackgroundColor3 = AC.WarHalo,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 4,
	}, ui.TugInner)
	candyFill(ui.TugLeft)
	local shine = make("Frame", {
		Name = "Shine",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(1, -6, 0.3, 0),
		ZIndex = 5,
	}, ui.TugInner)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	local tugIcon = Art.image("IconGoose", {
		Name = "GooseIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 2, 0.5, -1),
		Size = UDim2.fromOffset(L.IconW - 4, L.IconH - 4),
		ZIndex = 7,
	}, ui.Tug)
	local tugLeftX = tugIcon and 18 or 10
	-- CR-L36: side labels take the same share of any strip width (TugSide at the full STRIP_W); the title fills the
	-- middle with 2 px gaps: from tugLeftX + side + 2 to W - 10 - side - 2
	local sideK = L.TugSide / STRIP_W
	ui.TugLeftText = Art.text("light", {
		Name = "RescueText",
		Position = UDim2.fromOffset(tugLeftX, 2),
		Size = UDim2.new(sideK, 0, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	}, 14, ui.Tug)
	ui.TugRightText = Art.text("light", {
		Name = "PoachText",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 2),
		Size = UDim2.new(sideK, 0, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 6,
	}, 14, ui.Tug)
	ui.TugCenterText = Art.text("light", {
		Name = "TitleText",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (tugLeftX - 10) / 2, 0, 2),
		Size = UDim2.new(1 - 2 * sideK, -(tugLeftX + 10 + 4), 1, -4),
		ZIndex = 6,
	}, 14, ui.Tug)
	ui.TugSub = Art.text("light", {
		Name = "GooseSub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BAR_H),
		Size = UDim2.new(1, 0, 0, subH),
		Color = AC.LightSub,
		Visible = false,
		ZIndex = 3,
	}, 13, ui.Strip)

	-- kaiju chip (right of the strip): red-tinted parchment pill with red ink
	ui.KaijuChip = Art.frame("Pill", {
		Name = "KaijuChip",
		Position = UDim2.new(1, 8, 0, 0),
		Size = UDim2.fromOffset(KAIJU_CHIP_W, L.PillH),
		Visible = false,
		ZIndex = 3,
	}, { CornerRadius = UDim.new(0.5, 0), StrokeColor = KAIJU_RED }, ui.Strip)
	if ui.KaijuChip:IsA("ImageLabel") then
		ui.KaijuChip.ImageColor3 = AC.KaijuTint
	elseif not Art.On then
		ui.KaijuChip.BackgroundColor3 = KAIJU_RED -- old look without the art API
		ui.KaijuChip.BackgroundTransparency = 0.1
	end
	ui.KaijuChipText = Art.text("ink", {
		Name = "Text",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 1, -8),
		Color = AC.BadInk,
		ZIndex = 4,
	}, 15, ui.KaijuChip)

	-- kaiju siren banner (full width at 18% screen height): red band with gold trim
	ui.Siren = make("Frame", {
		Name = "KaijuSiren",
		BackgroundColor3 = SIREN_RED,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.18),
		Size = UDim2.new(1, 0, 0, SIREN_H),
		Visible = false,
		ZIndex = 6,
	}, root)
	for _, edge in { 0, 1 } do
		make("Frame", {
			Name = edge == 0 and "TrimTop" or "TrimBottom",
			BackgroundColor3 = AC.Gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, edge),
			Position = UDim2.fromScale(0, edge),
			Size = UDim2.new(1, 0, 0, L.TrimH),
			ZIndex = 7,
		}, ui.Siren)
	end
	ui.SirenText = Art.text("light", {
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -14),
		Title = true,
		ZIndex = 7,
	}, 28, ui.Siren)

	-- personal line: parchment pill with coloured ink (bottom-center at 72%, above HUD's bottom button cluster; touch:
	-- top-centre under HUD's status chips, clear of the thumbstick zone (U3) and the right-hand button column; layout()
	-- sets the y and the width). CR-L37: drawn above HUD's root frame (PERSONAL_Z) so nothing covers the sack seconds.
	ui.Personal = Art.frame("Pill", {
		Name = "PersonalLine",
		AnchorPoint = IS_TOUCH and Vector2.new(0.5, 0) or Vector2.new(0.5, 0.5),
		Position = IS_TOUCH and UDim2.new(0.5, 0, 0, L.ChipsY + TOP_FALLBACK + L.ChipsH + L.StripGap)
			or UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(PERSONAL_W, PERSONAL_H),
		Visible = false,
		ZIndex = PERSONAL_Z,
	}, { CornerRadius = UDim.new(0.5, 0) }, root)
	ui.PersonalText = Art.text("ink", {
		Name = "Text",
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.new(1, -32, 1, -8),
		ZIndex = PERSONAL_Z + 1,
	}, 17, ui.Personal)
	-- ink on parchment; the old bright colours only on the old dark panel
	if Art.On then
		ui.PersonalInk = { Sack = AC.SackInk, Kaiju = AC.BadInk, Revenge = AC.RevengeInk }
	else
		ui.PersonalInk = { Sack = SACK_PURPLE, Kaiju = KAIJU_ARROW, Revenge = REVENGE_ORANGE }
	end

	-- Regular's Luck corner (top-right): parchment panel, clover, ink lines, cheer stars. Hidden on touch (U5; the
	-- menu can show EventHUD.LuckSummary instead). Fixed thin rim so both lines sit on the parchment (mockup).
	ui.Luck = Art.frame("PanelParchment", {
		Name = "LuckCorner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -LUCK_RIGHT, 0, LUCK_Y),
		Size = UDim2.fromOffset(LUCK_W, LUCK_H),
		SliceScale = L.LuckSlice,
		Visible = not IS_TOUCH,
		ZIndex = 3,
	}, nil, root)
	local clover = Art.image("IconClover", {
		Name = "Clover",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(L.Clover, L.Clover),
		ZIndex = 4,
	}, ui.Luck)
	local luckX = clover and (12 + L.Clover) or 10
	local lineY = L.LuckLine2Y
	ui.LuckLine1 = Art.text("ink", {
		Name = "Luck",
		Position = UDim2.fromOffset(luckX, L.LuckLine1Y),
		Size = UDim2.new(1, -luckX - 9, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	}, 15, ui.Luck)
	ui.StarFull, ui.StarEmpty = Art.id("IconStar"), Art.id("IconStarEmpty")
	if ui.StarFull and ui.StarEmpty then
		-- "응원별" + star icons + "2/5" (mockup)
		local labelW, countW = 42, 30
		Art.text("ink", {
			Name = "CheerLabel",
			Text = TXT.CheerLabel,
			Position = UDim2.fromOffset(luckX, lineY),
			Size = UDim2.fromOffset(labelW, 17),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		}, 14, ui.Luck)
		ui.StarsW = LUCK_W - luckX - labelW - countW - 15
		ui.CheerStars = make("Frame", {
			Name = "CheerStars",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(luckX + labelW + 2, lineY),
			Size = UDim2.fromOffset(ui.StarsW, 17),
			ZIndex = 4,
		}, ui.Luck)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
		}, ui.CheerStars)
		ui.StarPool = {}
		ui.CheerCount = Art.text("ink", {
			Name = "CheerCount",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -9, 0, lineY),
			Size = UDim2.fromOffset(countW, 17),
			TextXAlignment = Enum.TextXAlignment.Right,
			Color = AC.InkSoft,
			Number = true,
			ZIndex = 4,
		}, 14, ui.Luck)
	else
		-- no star icons: the old text line ("응원별 ★★☆☆☆ (2/5)")
		ui.LuckLine2 = Art.text("ink", {
			Name = "Cheer",
			Position = UDim2.fromOffset(luckX, lineY),
			Size = UDim2.new(1, -luckX - 9, 0, 17),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 4,
		}, 14, ui.Luck)
		if not Art.On then ui.LuckLine2.TextColor3 = GOLD end
	end

	built = true
end

local function relayout()
	lastLayoutKey = nil
	local ok, err = pcall(layout)
	if not ok then warnThrottled("layout failed: " .. tostring(err)) end
end

-- logical y of the bottom of a HUD frame ("WarMeter" = war bar + timer, "StatusChips"), or nil while HUD has not
-- built it. Read from the live frame so the event UI stays under it whatever size HUD gives it (mockup order).
local function hudBottom(name, s)
	local ref = hudRef[name]
	local frame = ref.Frame
	if not (frame and frame.Parent) then
		frame = nil
		local root = ui.Strip and ui.Strip.Parent
		local found = root and root:FindFirstChild(name, true)
		if found and found:IsA("GuiObject") then frame = found end
		for _, c in ref.Conns do
			c:Disconnect()
		end
		table.clear(ref.Conns)
		ref.Frame = frame
		if frame then
			table.insert(ref.Conns, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))
			table.insert(ref.Conns, frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(relayout))
		end
	end
	if not frame or frame.AbsoluteSize.Y < 1 then return nil end
	local gui = frame:FindFirstAncestorWhichIsA("LayerCollector")
	local top = (gui and gui:IsA("GuiBase2d")) and gui.AbsolutePosition.Y or 0
	return (frame.AbsolutePosition.Y + frame.AbsoluteSize.Y - top) / s
end

-- U5: on touch every label renders at >= MinTextSize real px (logical min = MinTextSize / UIScale)
local function applyMinText(minSize)
	for _, entry in textConstraints do
		local c = entry[1]
		if c.Parent then
			local maxSize = math.max(entry[2], minSize)
			if minSize > c.MaxTextSize then
				c.MaxTextSize = maxSize
				c.MinTextSize = minSize
			else
				c.MinTextSize = minSize
				c.MaxTextSize = maxSize
			end
		end
	end
end

-- CR-L36: centre x and width (logical px) of HUD's top-centre column, i.e. the war meter that HUD narrows / shifts
-- between the stats card and the right-hand blocks on narrow phones: HUD.TopCenterX / TopCenterW when published,
-- else the live WarMeter frame (call after hudBottom("WarMeter")), else nil (strip stays at the screen centre)
local function hudTopCenter(s)
	local hud = C and C.HUD
	if type(hud) == "table" then
		local x, w = num(hud.TopCenterX), num(hud.TopCenterW)
		if x > 0 and w > 0 then return x, w end
	end
	local frame = hudRef.WarMeter.Frame
	if frame and frame.Parent and frame.AbsoluteSize.X >= 1 then
		local gui = frame:FindFirstAncestorWhichIsA("LayerCollector")
		local left = (gui and gui:IsA("GuiBase2d")) and gui.AbsolutePosition.X or 0
		return (frame.AbsolutePosition.X + frame.AbsoluteSize.X / 2 - left) / s, frame.AbsoluteSize.X / s
	end
	return nil, nil
end

-- CR-L37: (W, H, ClusterTop, ClusterLeft) in logical px from HUD.Layout = { W, H, ClusterTop, ClusterLeft, ... }
-- (top / left edge of HUD's bottom-right button cluster); W / H fall back to the gui's own size, the cluster to nil
local function hudLayoutNums(root, s)
	local W, H = root.AbsoluteSize.X / s, root.AbsoluteSize.Y / s
	local hl = C and type(C.HUD) == "table" and C.HUD.Layout or nil
	local clusterTop, clusterLeft = nil, nil
	if type(hl) == "table" then
		if num(hl.W) > 0 then W = hl.W end
		if num(hl.H) > 0 then H = hl.H end
		if num(hl.ClusterTop) > 0 then clusterTop = hl.ClusterTop end
		if num(hl.ClusterLeft) > 0 then clusterLeft = hl.ClusterLeft end
	end
	return W, H, clusterTop, clusterLeft
end

-- H4: shift the spec's top slots below the Roblox top bar. Same convention as UIKit's toast stack:
-- logical offset = slot Y + realInset / UIScale (so the real-pixel top is always >= inset + TopInsetPad).
layout = function()
	if not built then return end
	local root = ui.Strip and ui.Strip.Parent
	if not root then return end
	if not guiScale or guiScale.Parent == nil then
		guiScale = root:FindFirstChildOfClass("UIScale")
	end
	local inset, rawInset = insetY()
	arrowGeo.Inset = inset -- CR-L43: placeArrow keeps the edge arrows below the top bar
	arrowGeo.TopLeft = rawInset
	local s = currentScale()
	local stripY = STRIP_Y + inset / s
	local wb = hudBottom("WarMeter", s)
	if wb then stripY = math.max(stripY, wb + L.StripGap) end
	stripY = math.floor(stripY + 0.5)
	-- CR-L36: the strip follows HUD's top-centre column (x and width), never wider than STRIP_W
	local stripX, stripW = nil, STRIP_W
	local cx, cw = hudTopCenter(s)
	if cx and cw then
		stripX = math.floor(cx + 0.5)
		stripW = math.floor(math.clamp(cw, L.StripMinW, STRIP_W) + 0.5)
	end
	-- strip bottom with its tallest content (tug bar + hint line): HUD puts its status chips under it (mockup order
	-- war bar > timer > goose pill > chips), via the EventStrip "BottomY" attribute / EventHUD.StripBottom()
	local stripBottom = stripY + ui.Strip.Size.Y.Offset
	local luckY = math.floor(math.max(LUCK_Y, (inset + TOP_PAD) / s) + 0.5)
	-- CR-L37: personal line width fits the screen; desktop y = 72% or just above HUD's bottom-right button cluster
	local W, H, clusterTop, clusterLeft = hudLayoutNums(root, s)
	local personalW = math.max(120, math.min(PERSONAL_W, W - 24))
	-- the centred line reaches the cluster's x range only when its right end passes ClusterLeft - 8
	local reachesCluster = clusterTop ~= nil and (clusterLeft == nil or W / 2 + personalW / 2 > clusterLeft - 8)
	local personalY
	if IS_TOUCH then
		-- touch: top-centre under HUD's status chips (U3: clear of the thumbstick zone and the button column)
		local cb = hudBottom("StatusChips", s)
		if not cb then cb = math.max(L.ChipsY + inset / s, stripBottom + L.StripGap) + L.ChipsH end
		personalY = math.floor(math.max(cb, stripBottom) + L.StripGap + 0.5)
		-- a tall touch cluster (square row + next-weapon card) can reach up to that line: narrow it to end left of it
		if reachesCluster and clusterLeft and personalY + PERSONAL_H > clusterTop - 8 then
			personalW = math.max(200, math.min(personalW, 2 * (clusterLeft - 8 - W / 2)))
		end
	else
		local y = 0.72 * H
		-- only a cluster in the lower half can cover the line (never pull the line above the screen middle)
		if reachesCluster and clusterTop > H * 0.5 then
			y = math.max(math.min(y, clusterTop - 8 - PERSONAL_H / 2), H * 0.5)
		end
		personalY = math.floor(y + 0.5)
	end
	personalW = math.floor(personalW + 0.5)
	local sized = W >= 10 and H >= 10 -- the gui is laid out (else the build-time spot stays until the next pass)
	if not sized then personalY = -1 end
	local minText = MIN_TEXT_SIZE
	if IS_TOUCH then minText = math.max(MIN_TEXT_SIZE, math.ceil(MIN_TEXT_SIZE / s - 0.01)) end
	local key = table.concat({ stripY, tostring(stripX), stripW, luckY, personalY, personalW, minText }, ":")
	if key == lastLayoutKey then return end
	lastLayoutKey = key
	ui.Strip.Position = stripX and UDim2.new(0, stripX, 0, stripY) or UDim2.new(0.5, 0, 0, stripY)
	ui.Strip.Size = UDim2.fromOffset(stripW, ui.Strip.Size.Y.Offset)
	ui.Strip:SetAttribute("BottomY", stripBottom)
	ui.Luck.Position = UDim2.new(1, -LUCK_RIGHT, 0, luckY)
	ui.Luck:SetAttribute("BottomY", luckY + LUCK_H) -- HUD's top-right blocks go below the luck panel
	if sized then
		ui.Personal.Position = UDim2.new(0.5, 0, 0, personalY)
		ui.Personal.Size = UDim2.fromOffset(personalW, PERSONAL_H)
	end
	applyMinText(minText)
end

----------------------------------------------------------------- per-tick updates
local function updateGoose(now)
	if gsAttr("GooseActive", false) == true then
		setVisible(ui.GooseChip, false)
		setVisible(ui.Tug, true)
		setVisible(ui.TugSub, true)
		local rescue = math.max(0, num(gsAttr("GooseRescue", 0)))
		local poach = math.max(0, num(gsAttr("GoosePoach", 0)))
		local total = rescue + poach
		local frac = 0.5
		if total > 0 then frac = math.clamp(rescue / total, 0, 1) end
		-- rescue (gold) grows from the left over the full-width poach (red) capsule
		ui.TugLeft.Size = UDim2.fromScale(frac, 1)
		setVisible(ui.TugLeft, frac > 0.001)
		setText(ui.TugLeftText, string.format(TXT.Rescue, math.floor(rescue)))
		setText(ui.TugRightText, string.format(TXT.Poach, math.floor(poach)))
		setText(ui.TugCenterText, string.format(TXT.GooseTitle, Util.FormatTime(num(gsAttr("GooseEndsAt", 0)) - now)))
		local faction = myAttr("Faction", "None")
		local mine = math.floor(math.max(0, num(myAttr("GooseCount", 0))))
		local sub
		if faction == "Halo" then
			sub = string.format(TXT.MyCount, mine) .. " · " .. TXT.HintHalo
		elseif faction == "Horns" then
			sub = string.format(TXT.MyCount, mine) .. " · " .. TXT.HintHorns
		elseif faction == "Neutral" then
			sub = TXT.HintNeutral
		else
			sub = string.format(TXT.MyCount, mine)
		end
		setText(ui.TugSub, sub)
	else
		setVisible(ui.Tug, false)
		setVisible(ui.TugSub, false)
		local nextAt = num(gsAttr("GooseNextAt", 0))
		if nextAt > 0 then
			setVisible(ui.GooseChip, true)
			setText(ui.GooseChipText, string.format(TXT.GooseNext, Util.FormatTime(nextAt - now)))
		else
			setVisible(ui.GooseChip, false)
		end
	end
end

-- maxChars: cut longer names for the narrow chip ("Player..")
local function kaijuName(maxChars)
	local name = gsAttr("KaijuName", "")
	if type(name) ~= "string" or name == "" then return TXT.UnknownName end
	local n = maxChars and utf8.len(name)
	if n and n > maxChars then
		local cut = utf8.offset(name, maxChars + 1)
		if cut then name = string.sub(name, 1, cut - 1) .. ".." end
	end
	return name
end

local function updateKaiju(now)
	local phase = gsAttr("KaijuPhase", "None")
	local endsAt = num(gsAttr("KaijuEndsAt", 0))
	if phase == "Active" then
		setVisible(ui.KaijuChip, true)
		setText(ui.KaijuChipText, string.format(TXT.KaijuChip, kaijuName(L.KaijuNameMax), Util.FormatTime(endsAt - now)))
	else
		setVisible(ui.KaijuChip, false)
	end
	if phase == "Siren" then
		local left = math.max(0, math.ceil(endsAt - now))
		local text = safeFormat(Config.Story.KaijuSiren, kaijuName()) .. "  " .. string.format(TXT.SirenLeft, left)
		setText(ui.SirenText, text)
		setVisible(ui.Siren, true)
	else
		setVisible(ui.Siren, false)
	end
end

local function revengeTarget(now)
	local id = num(myAttr("RevengeTargetId", 0))
	local untilT = num(myAttr("RevengeUntil", 0))
	if id ~= 0 and untilT > now then
		local p = Players:GetPlayerByUserId(id)
		if p and p ~= LocalPlayer then return p, untilT end
	end
	return nil, 0
end

local function updatePersonal(now)
	local text, color = nil, WHITE
	local ink = ui.PersonalInk
	local sack = num(myAttr("SackGold", 0))
	if sack > 0 then
		local secs = math.max(0, math.ceil(num(myAttr("SackSeconds", 0))))
		text = string.format(TXT.Sack, Util.FormatNumber(sack), secs)
		color = ink.Sack
	elseif myAttr("KaijuState", "None") == "Active" then
		local endsAt = 0
		if num(gsAttr("KaijuUserId", 0)) == LocalPlayer.UserId then endsAt = num(gsAttr("KaijuEndsAt", 0)) end
		text = string.format(TXT.KaijuSelf, Util.FormatTime(endsAt - now))
		color = ink.Kaiju
	else
		local target, untilT = revengeTarget(now)
		if target then
			text = string.format(TXT.Revenge, Util.PlayerDisplayName(target), Util.FormatTime(untilT - now))
			color = ink.Revenge
		end
	end
	if text then
		setText(ui.PersonalText, text)
		if ui.PersonalText.TextColor3 ~= color then ui.PersonalText.TextColor3 = color end
		setVisible(ui.Personal, true)
	else
		setVisible(ui.Personal, false)
	end
end

-- star icons for the cheer line (pooled; size shrinks when more stars are needed)
local function setStars(filled, need)
	local pool = ui.StarPool
	local shown = math.min(need, L.StarCap)
	local size = math.clamp(math.floor(ui.StarsW / math.max(shown, 1)) - 1, 8, L.StarMax)
	local sz = UDim2.fromOffset(size, size)
	for i = 1, math.max(#pool, shown) do
		local star = pool[i]
		if not star and i <= shown then
			star = Art.image("IconStar", { Name = "Star" .. i, LayoutOrder = i, Size = sz, ZIndex = 4 }, ui.CheerStars)
			if not star then break end
			pool[i] = star
		end
		if star then
			setVisible(star, i <= shown)
			if i <= shown then
				local id = (i <= filled) and ui.StarFull or ui.StarEmpty
				if star.Image ~= id then star.Image = id end
				if star.Size ~= sz then star.Size = sz end
			end
		end
	end
end

-- luck numbers: line 1 text ("단골 12분 · 희귀 5.25%"), cheer stars, stars needed, filled stars
local function luckData()
	local minutes = math.max(0, math.floor(num(myAttr("RegularMinutes", 0))))
	local line1 = string.format(TXT.Luck, minutes, Util.FormatPercent(Config.RareChance(minutes)))
	local need = math.floor(num(Config.Goose and Config.Goose.CheerStarsForRare))
	if need <= 0 then need = 5 end
	local stars = math.max(0, math.floor(num(myAttr("CheerStars", 0))))
	return line1, stars, need, math.min(stars, need)
end

-- "응원별 ★★☆☆☆ (2/5)"
local function cheerText(stars, need, filled)
	return string.format(TXT.Cheer, string.rep("★", filled) .. string.rep("☆", need - filled), stars, need)
end

local function updateLuck()
	local line1, stars, need, filled = luckData()
	setText(ui.LuckLine1, line1)
	if ui.CheerStars then
		setStars(filled, need)
		setText(ui.CheerCount, string.format(TXT.CheerCount, stars, need))
	else
		setText(ui.LuckLine2, cheerText(stars, need, filled))
	end
end

-- builds the arrow target list (kaiju > revenge > grudge sacks, nearest first), at most MAX_ARROWS
local function gatherTargets(now)
	local list = {}
	local byPlayer = {}
	local myRoot = getRoot(LocalPlayer)
	local myPos = myRoot and myRoot.Position
	local function add(player, color, text, priority)
		if not player or player == LocalPlayer or player.Parent == nil then return end
		local existing = byPlayer[player]
		if existing then
			existing.Label = existing.Label .. " · " .. text
			return
		end
		local dist = math.huge
		local root = getRoot(player)
		if root and myPos then dist = (root.Position - myPos).Magnitude end
		local t = { Player = player, Color = color, Label = text, Priority = priority, Dist = dist, IsSack = false }
		byPlayer[player] = t
		table.insert(list, t)
		return t
	end

	local isHalo = myAttr("Faction", "None") == "Halo"
	if isHalo and gsAttr("KaijuPhase", "None") == "Active" then
		local id = num(gsAttr("KaijuUserId", 0))
		if id ~= 0 then add(Players:GetPlayerByUserId(id), KAIJU_ARROW, TXT.ArrowKaiju, 1) end
	end
	local revenge = revengeTarget(now)
	if revenge then add(revenge, REVENGE_ORANGE, TXT.ArrowRevenge, 2) end
	if isHalo then
		for _, p in Players:GetPlayers() do
			if p ~= LocalPlayer then
				local sackGold = num(p:GetAttribute("SackGold"))
				if sackGold > 0 then
					local text = string.format(TXT.ArrowSack, Util.FormatNumber(sackGold))
					local existing = byPlayer[p]
					if existing then
						existing.Label = existing.Label .. " · " .. text
						existing.IsSack = true
					else
						local t = add(p, SACK_PURPLE, text, 3)
						if t then t.IsSack = true end
					end
				end
			end
		end
	end

	table.sort(list, function(a, b)
		if a.Priority ~= b.Priority then return a.Priority < b.Priority end
		return a.Dist < b.Dist
	end)
	local out = {}
	local sawSack = false
	for i = 1, math.min(#list, MAX_ARROWS) do
		out[i] = list[i]
		if list[i].IsSack then sawSack = true end
	end
	activeTargets = out

	-- lore hint: the first time this session a sack-carrier arrow appears for a Halo player
	if sawSack and isHalo and not loreShown then
		loreShown = true
		uiToast(safeFormat(Config.Story.SackLore), "info", 4)
	end
end

local function update()
	if not built then return end
	if pickersOpen() then
		setVisible(ui.Arrows, false)
		setVisible(ui.Strip, false)
		setVisible(ui.Luck, false)
		setVisible(ui.Siren, false)
		setVisible(ui.Personal, false)
		activeTargets = {}
		return
	end
	setVisible(ui.Arrows, true)
	setVisible(ui.Strip, true)
	setVisible(ui.Luck, not IS_TOUCH) -- U5: phones get the slim HUD (the menu shows EventHUD.LuckSummary)
	local now = Util.Now()
	updateGoose(now)
	updateKaiju(now)
	updatePersonal(now)
	updateLuck()
	gatherTargets(now)
end

----------------------------------------------------------------- arrows (RenderStepped)
local function hideArrow(a)
	if a.Glyph.Visible then a.Glyph.Visible = false end
	if a.Label.Visible then a.Label.Visible = false end
end

-- the arrow layer's rect in viewport px (origin, size). UIKit's gui keeps to the device safe area (CR-L34), so the
-- layer can be narrower than the viewport on notched phones; AbsolutePosition is measured from the GUI inset origin
-- (viewport px = AbsolutePosition + GetGuiInset top-left). Anything implausible falls back to the whole viewport.
local function layerRect(vp)
	local size = ui.Arrows.AbsoluteSize
	local topLeft = arrowGeo.TopLeft
	if topLeft and size.X >= 2 and size.Y >= 2 then
		local origin = ui.Arrows.AbsolutePosition + topLeft
		if origin.X >= -1 and origin.Y >= -1 and origin.X + size.X <= vp.X + 1 and origin.Y + size.Y <= vp.Y + 1 then
			return origin, size
		end
	end
	return Vector2.new(0, 0), vp
end

-- viewport px -> Position on the arrow layer (yOffset: logical px)
local function onLayer(x, y, origin, size, yOffset)
	return UDim2.new((x - origin.X) / size.X, 0, (y - origin.Y) / size.Y, yOffset or 0)
end

local function clampLabel(x, y, origin, size)
	local s = currentScale()
	local halfW = ARROW_LABEL_W * s / 2 + 4
	local halfH = ARROW_LABEL_H * s / 2 + 4
	local midX, midY = origin.X + size.X / 2, origin.Y + size.Y / 2
	x = math.clamp(x, math.min(origin.X + halfW, midX), math.max(origin.X + size.X - halfW, midX))
	y = math.clamp(y, math.min(origin.Y + halfH, midY), math.max(origin.Y + size.Y - halfH, midY))
	return x, y
end

local function placeArrow(a, target, root, cam, vp, origin, size)
	local scale = num(target.Player:GetAttribute("VisualScale"))
	if scale <= 0 then scale = 1 end
	local world = root.Position + Vector3.new(0, 4.2 * scale, 0)
	local sp, onScreen = cam:WorldToViewportPoint(world)
	a.Glyph.TextColor3 = target.Color
	a.Label.TextColor3 = target.Color
	if a.Label.Text ~= target.Label then a.Label.Text = target.Label end

	if onScreen and sp.Z > 0 then
		-- small marker above the target. CR-L43 (H4): a head near the top of the view (kaiju, high ground) would put the
		-- pair in the Roblox top bar, so it moves down until the label's top (the pair's highest point) is at
		-- inset + TopInsetPad or lower
		local s = currentScale()
		local my = math.max(sp.Y, arrowGeo.Inset + TOP_PAD + (L.MarkerLabelUp + ARROW_LABEL_H / 2) * s)
		if a.Glyph.Text ~= MARKER_GLYPH then a.Glyph.Text = MARKER_GLYPH end
		a.Glyph.Rotation = 0
		a.Glyph.Position = onLayer(sp.X, my, origin, size)
		a.Label.Position = onLayer(sp.X, my, origin, size, -L.MarkerLabelUp)
	else
		-- clamp to the layer's edge, rotated toward the target
		local center = origin + size / 2
		local dir
		if sp.Z > 0 then
			dir = Vector2.new(sp.X, sp.Y) - center
		else
			local rel = cam.CFrame:PointToObjectSpace(world)
			dir = Vector2.new(rel.X, -rel.Y)
		end
		if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
		local halfW = math.max(1, size.X / 2 - EDGE_MARGIN)
		local halfH = math.max(1, size.Y / 2 - EDGE_MARGIN)
		local sx = math.abs(dir.X) > 1e-6 and halfW / math.abs(dir.X) or math.huge
		local sy = math.abs(dir.Y) > 1e-6 and halfH / math.abs(dir.Y) or math.huge
		local edge = center + dir * math.min(sx, sy)
		local s = currentScale()
		local glyphHalf = ARROW_GLYPH_SIZE * s / 2
		local gx, gy = outOfThumbZone(edge.X, edge.Y, vp, glyphHalf, glyphHalf)
		-- CR-L43 (H4): never in the Roblox top bar; the glyph's top stays at inset + TopInsetPad or lower
		local topMin = math.max(origin.Y + EDGE_MARGIN, arrowGeo.Inset + TOP_PAD + glyphHalf)
		if gy < topMin then gy = topMin end
		edge = Vector2.new(gx, gy)
		local inward = -dir.Unit * LABEL_INSET
		local lx, ly = clampLabel(edge.X + inward.X, edge.Y + inward.Y, origin, size)
		lx, ly = outOfThumbZone(lx, ly, vp, ARROW_LABEL_W * s / 2, ARROW_LABEL_H * s / 2)
		ly = math.max(ly, arrowGeo.Inset + TOP_PAD + ARROW_LABEL_H * s / 2) -- ... and so does its label (CR-L43)
		if a.Glyph.Text ~= EDGE_GLYPH then a.Glyph.Text = EDGE_GLYPH end
		a.Glyph.Rotation = math.deg(math.atan2(dir.Y, dir.X))
		a.Glyph.Position = onLayer(edge.X, edge.Y, origin, size)
		a.Label.Position = onLayer(lx, ly, origin, size)
	end
	if not a.Glyph.Visible then a.Glyph.Visible = true end
	if not a.Label.Visible then a.Label.Visible = true end
end

local function onRender()
	if not built then return end
	if ui.Siren.Visible then
		ui.Siren.BackgroundTransparency = 0.05 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 12))
	end
	local used = 0
	local cam = workspace.CurrentCamera
	if cam and ui.Arrows.Visible and #activeTargets > 0 then
		local vp = cam.ViewportSize
		if vp.X >= 2 and vp.Y >= 2 then
			local origin, size = layerRect(vp)
			for _, t in activeTargets do
				if used >= MAX_ARROWS then break end
				local root = getRoot(t.Player)
				if root then
					used += 1
					placeArrow(arrows[used], t, root, cam, vp, origin, size)
				end
			end
		end
	end
	for i = used + 1, MAX_ARROWS do
		hideArrow(arrows[i])
	end
end

----------------------------------------------------------------- public API
function EventHUD.Init(registry)
	C = registry
end

-- logical y (MainGui UIScale units) of the event strip's bottom, or nil before the first layout. HUD's status chips
-- go under it (also published as the EventStrip "BottomY" attribute).
function EventHUD.StripBottom()
	local strip = ui.Strip
	local y = strip and strip:GetAttribute("BottomY")
	if type(y) == "number" then return y end
	return nil
end

-- U5: touch hides the luck corner, so the menu shows these two lines instead:
-- "단골 12분 · 희귀 5.25%", "응원별 ★★☆☆☆ (2/5)" (nil, nil on error)
function EventHUD.LuckSummary()
	local ok, line1, stars, need, filled = pcall(luckData)
	if not ok then return nil, nil end
	return line1, cheerText(stars, need, filled)
end

function EventHUD.Start()
	local ok, err = pcall(build)
	if not ok then
		Util.Warn("EventHUD", "build failed: " .. tostring(err))
		built = false
	end
	pcall(layout)

	-- GameState normally exists already; never block the other client modules' Start on it
	task.spawn(function()
		local gs = Net.GameState()
		if gs then gameState = gs end
	end)

	local function hookCamera(cam)
		if not cam then return end
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			lastLayoutKey = nil
			pcall(layout)
		end)
	end
	hookCamera(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hookCamera(workspace.CurrentCamera)
	end)
	if guiScale then
		guiScale:GetPropertyChangedSignal("Scale"):Connect(function()
			lastLayoutKey = nil
			pcall(layout)
		end)
	end

	task.spawn(function()
		while true do
			local okTick, errTick = pcall(update)
			if not okTick then warnThrottled(tostring(errTick)) end
			layoutTimer += TICK
			if layoutTimer >= LAYOUT_EVERY then
				layoutTimer = 0
				pcall(layout)
			end
			task.wait(TICK)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local okRender, errRender = pcall(onRender)
		if not okRender then warnThrottled(tostring(errRender)) end
	end)

	print("[EventHUD] started")
end

return EventHUD
