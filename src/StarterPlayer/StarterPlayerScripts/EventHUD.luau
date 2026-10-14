-- EventHUD.luau : event UI for Halo & Horns (G11).
-- Golden goose countdown chip / tug-of-war bar, kaiju chip + siren banner, screen-edge arrows (grudge sacks, kaiju,
-- revenge), the personal status line (sack / kaiju / revenge) and the Regular's Luck corner.
-- Reads only player attributes and GameState attributes; sends nothing to the server (the Join / Leave press goes through
-- EggFx.SquarePress, A23-141: the one remote there, GooseSquare).
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
	IconW = 30, IconH = 34, -- the tug bar's goose icon (sticking out of its left end, mockup)
	-- 최종 검수 10/14 (user: "오리가 낑김" - the chip's goose was cut by its left rim): the goose chip's icon INSIDE the chip,
	-- Left / Right inner padding, the icon = the chip's height x IconK, Gap before the words, the chip PlusH taller than a
	-- pill, as wide as its whole line needs (never narrower than GOOSE_CHIP_W) - SQ.FitGoose / SQ.GooseNeed
	GooseChip = { Left = 10, Right = 12, Gap = 6, IconK = 0.65, PlusH = 4 }, -- 1안 ③: a 26 px goose in the 40 px chip
	StripGap = 6, -- gap under HUD's war meter
	SubHTouch = 15, -- tug hint line on touch (15 logical = 11 real px at UIScale 0.75)
	TugSide = 74, -- rescue / poach label width inside the tug bar (at the full STRIP_W; scales with the strip, CR-L36)
	StripMinW = 200, -- CR-L36: narrowest strip (HUD clamps its war meter to 200..WarW on narrow phones)
	Clover = 26,
	StarMax = 15, StarCap = 10,
	-- luck panel (ListRow: its rim follows the 58 du height, ~7 du at top / bottom): the two line rows inside it
	LuckLine1Y = 9, LuckLine2Y = 29,
	KaijuNameMax = IS_TOUCH and 6 or 8, -- kaiju chip: longer names are cut ("Player..")
	TrimH = 3, -- siren gold trim
	-- U3 / HUD v2 spec: Roblox's real DynamicThumbstick area = left 40% x bottom two thirds (x < 0.4W, y > H/3);
	-- ThumbH is the zone's height share measured from the bottom edge (outOfThumbZone)
	ThumbW = 0.4, ThumbH = 2 / 3,
	ChipsY = 106, ChipsH = 32, -- HUD's status chip row (fallback while its frame is not found)
	MarkerLabelUp = 26, -- on-screen marker: its label's centre sits this far above the glyph's
	-- Halloween Pumpkin King pill: left of the strip (the kaiju pill sits on the right); narrower room left of the strip
	-- shrinks it down to KingMinW, below that it goes under the strip
	KingW = 210, KingMinW = 130, KingGap = 8,
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
	KaijuTint = Color3.fromRGB(255, 196, 186), -- ImageColor3 on the kaiju chip
	StarGold = Color3.fromRGB(245, 197, 66), -- the white 'Star' part tinted: a filled / an empty cheer star
	StarEmpty = Color3.fromRGB(70, 78, 110),
}

-- private strings (TECH_SPEC §4.23 EventHUD; A23-48: English only, names from docs/design/glossary_en_2026-10-06.md)
local TXT = {
	GooseNext = "Golden Goose %s", -- the phone's next-event line is 150 px
	GooseNextShort = "Goose %s", -- A23-145: a chip too narrow for the whole line (SQ.chipLine), then the time alone
	GooseTitle = "Golden Goose Tug! %s",
	EggScore = "%d", -- A23-131 황금 알 (Eggs mode): a side's points on the bar
	EggCoop = "%d / %d", -- ... co-op: our points / the goal
	Rescue = "Rescue %d",
	Poach = "Poach %d",
	MyCount = "My hits %d",
	HintHalo = "Hit the goose to rescue it!",
	HintHorns = "Hit the goose to poach it!",
	HintNeutral = "The Artisan Guild sits out the tug", -- addendum A6
	KaijuChip = "Kaiju %s %s",
	SirenLeft = "%ds",
	Sack = "Grudge Sack %s · %ds", -- A23-130: the "(shrinks only in PvP zones)" explanation is gone
	KaijuSelf = "You're the Kaiju! Last %s", -- A23-130: shorter (was "... to become a legend")
	Revenge = "Revenge: %s · %s",
	Luck = "Today's Luck · Rare %s%%", -- A23-18 (events taken part in today, KST day)
	-- 검수 10/09 (UI clutter review: 'Rare 5%' meant nothing to kids): the chip says the bonus over the base rare chance
	-- and shows only when there is one (EventHUD.LuckShort)
	LuckShort = "Lucky +%s%%",
	Cheer = "Cheer Stars %s (%d/%d)",
	CheerLabel = "Cheer Stars",
	CheerCount = "%d/%d",
	ArrowSack = "Grudge Sack %s",
	ArrowKaiju = "Kaiju",
	ArrowRevenge = "Revenge",
	UnknownName = "???",
}

-- 최종 검수 10/14 (A23-179: Roblox's automatic translation matches whole drawn sentences, so a line with a number or a
-- name stayed English): a sentence with %-slots by its table key (UIKit.Tx -> UIKit.Tr: the localization table by key;
-- English exactly as before); without UIKit (offline tests) string.format; a failed format = the words as they are
function L.Tx(t, key, ...)
	local f = type(t) == "table" and (t[key .. "En"] or t[key]) or nil
	if type(f) ~= "string" then return nil end
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Tx) == "function" then
		local ok, out = pcall(kit.Tx, t, key, ...)
		if ok and type(out) == "string" then return out end
	end
	local ok, out = pcall(string.format, f, ...)
	return ok and out or f
end

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
-- Halloween Pumpkin King pill (functions below KING.update); Below = it sits in the row under HUD's status chips
-- (narrow screens), so layout() moves the touch personal line one row lower
local KING = { Below = false }
-- A23-141 Goose Square: the Join / Leave button on the goose chip (EggFx.SquareButton / SquarePress; functions below
-- KING). Out = the chip shows the goose time + Join this tick (outside the square while the event runs). 최종 검수 10/13
-- (main photo goose_square4/03, PC 1920: "Leav"): the button is as wide as its word (SQ.need) - MinW..MaxW logical px,
-- H high, Pad = the label's 8 inset + the capsule's round ends; Fit = the last { Key, W }
local SQ = { Out = false, MinW = 64, MaxW = 160, H = 26, Pad = 20, Size = 15, Fit = nil }
-- HUD v2 (A23-26): while C.HUD.Layout.Rects.notify exists, the strip contents, the personal line and the siren stack in
-- that notify column (functions in the "HUD v2 notify column" section). Active = the v2 placement is applied; Key =
-- geometry cache key; Col = column numbers; Want = what the per-tick updates asked to show; Saved = build-time props
local V2 = { Active = false, Key = nil, Col = nil, Want = {}, Saved = nil, Gap = 4, ChipsGap = 4 }

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
	for _, name in { "Intro", "FactionPicker", "ClassPicker" } do
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

-- U3: on touch, slide an edge arrow / label (screen px, centre) out of the thumbstick zone (x < ThumbW * W and
-- y > (1 - ThumbH) * H, i.e. the left 40% below the top third)
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

	-- goose countdown: white chip + goose icon + ink text ("황금 거위까지 3:24")
	ui.GooseChip = Art.frame("Chip", {
		Name = "GooseChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(GOOSE_CHIP_W, L.PillH + L.GooseChip.PlusH),
		Visible = false,
		ZIndex = 3,
	}, { CornerRadius = UDim.new(0.5, 0) }, ui.Strip)
	ui.GooseIcon = Art.image("IconGoose", {
		Name = "GooseIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.GooseChip.Left, 0.5, 0),
		Size = UDim2.fromOffset(L.IconW, L.IconW),
		ZIndex = 5,
	}, ui.GooseChip)
	ui.GooseChipText = Art.text("ink", {
		Name = "Text",
		Position = UDim2.fromOffset(L.GooseChip.Left, 1),
		Size = UDim2.new(1, -L.GooseChip.Left - L.GooseChip.Right, 1, -2), -- the line's whole height
		ZIndex = 4,
	}, 16, ui.GooseChip)
	SQ.FitGoose(L.PillH + L.GooseChip.PlusH)
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
	ui.TugCenterInk = ui.TugCenterText.TextColor3 -- A23-131: the clock goes gold in the crown egg's overtime, then back
	-- A23-131: the approved crown (Config.UIArt.Parts.Crown) left of the clock in the overtime; nil = the gold clock alone
	ui.TugCrown = Art.image("Crown", {
		Name = "OvertimeCrown",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.5, -22, 0.5, 0),
		Size = UDim2.fromOffset(22, 15),
		Visible = false,
		ZIndex = 7,
	}, ui.Tug)
	ui.TugSub = Art.text("light", {
		Name = "GooseSub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BAR_H),
		Size = UDim2.new(1, 0, 0, subH),
		Color = AC.LightSub,
		Visible = false,
		ZIndex = 3,
	}, 13, ui.Strip)
	SQ.build()

	-- kaiju chip (right of the strip): red-tinted chip with red ink
	ui.KaijuChip = Art.frame("Chip", {
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
	ui.KaijuChipText.TextWrapped = false -- one line (V2.KaijuNeed keeps the chip as wide as it needs)

	-- Halloween Pumpkin King countdown / time left (Config.Halloween; KING.update places and fills it): white chip
	-- with orange-brown ink, same look as the goose / kaiju pills
	ui.KingChip = Art.frame("Chip", {
		Name = "PumpkinKingChip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, -L.KingGap, 0, 0),
		Size = UDim2.fromOffset(L.KingW, L.PillH),
		Visible = false,
		ZIndex = 3,
	}, { CornerRadius = UDim.new(0.5, 0), StrokeColor = AC.RevengeInk }, ui.Strip)
	ui.KingChipText = Art.text("ink", {
		Name = "Text",
		Position = UDim2.fromOffset(12, 1),
		Size = UDim2.new(1, -24, 1, -2), -- the line's whole height (see the goose pill)
		Color = AC.RevengeInk,
		ZIndex = 4,
	}, 15, ui.KingChip)
	if not Art.On then ui.KingChipText.TextColor3 = REVENGE_ORANGE end
	ui.KingChipText.TextWrapped = false -- one line: KING.place keeps the pill as wide as the line needs

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

	-- personal line: white chip with coloured ink (bottom-center at 72%, above HUD's bottom button cluster; touch:
	-- top-centre under HUD's status chips, clear of the thumbstick zone (U3) and the right-hand button column; layout()
	-- sets the y and the width). CR-L37: drawn above HUD's root frame (PERSONAL_Z) so nothing covers the sack seconds.
	ui.Personal = Art.frame("Chip", {
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

	-- Regular's Luck corner (top-right): cream ListRow plate (그림체 #10; its rim follows the height, ~7 du), clover, ink
	-- lines, cheer stars. Hidden on touch (U5; the menu can show EventHUD.LuckSummary instead).
	ui.Luck = Art.frame("ListRow", {
		Name = "LuckCorner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -LUCK_RIGHT, 0, LUCK_Y),
		Size = UDim2.fromOffset(LUCK_W, LUCK_H),
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
	ui.StarFull, ui.StarEmpty = Art.id("Star"), Art.id("Star") -- one white star, tinted by setStars
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
	V2.Key = nil
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
	-- HUD v2: the notify column (V2.layout); the code below is the legacy layout (no Rects published yet)
	if V2.rects() then V2.layout() return end
	if V2.Active then V2.leave() end
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
		if KING.Below then personalY += L.PillH + L.StripGap end -- the Pumpkin King pill row (KING.place)
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
	local key = table.concat({ stripY, tostring(stripX), stripW, luckY, personalY, personalW, minText,
		tostring(KING.Below) }, ":")
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

----------------------------------------------------------------- Goose Square button (A23-141)
local function eggFxOf()
	local e = C and C.EggFx
	return type(e) == "table" and e or nil
end

-- the Join / Leave words from Config.Goose.Square.Text (UIKit.Tx, the central-text path)
function SQ.word(key)
	local sq = type(Config.Goose) == "table" and type(Config.Goose.Square) == "table" and Config.Goose.Square or {}
	local t = type(sq.Text) == "table" and sq.Text or {}
	local kit = C and C.UIKit
	if type(kit) == "table" and type(kit.Tx) == "function" then
		local ok, s = pcall(kit.Tx, t, key)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return type(t[key]) == "string" and t[key] or ""
end

function SQ.press()
	local e = eggFxOf()
	if not e or type(e.SquarePress) ~= "function" or not SQ.Word then return end
	local ok, err = pcall(e.SquarePress, SQ.Word)
	if not ok then warnThrottled("SquarePress failed: " .. tostring(err)) end
end

-- an approved Chip art button (UIKit.ArtButton: its code fallback when the part has no id), else a plain TextButton; sits
-- right of the bar / the chip (a child of whichever shows: SQ.update moves it), hidden until SQ.update asks for it
function SQ.build()
	local props = {
		Name = "GooseSquareButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 6, 0.5, 0),
		Size = UDim2.fromOffset(SQ.MinW, SQ.H),
		Text = "",
		TextSize = SQ.Size,
		TextStyle = "ink",
		Visible = false,
		ZIndex = 8,
	}
	local kit = C and C.UIKit
	local btn, label = nil, nil
	if type(kit) == "table" and type(kit.ArtButton) == "function" then
		local ok, b, l = pcall(kit.ArtButton, "Chip", props, SQ.press, { CornerRadius = UDim.new(0.5, 0) })
		if ok and typeof(b) == "Instance" then btn, label = b, l end
	end
	if not btn then
		btn = make("TextButton", {
			Name = props.Name,
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = props.Size,
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
			AutoButtonColor = false,
			Font = fontFace,
			Text = "",
			TextColor3 = GOLD,
			TextScaled = true,
			Visible = false,
			ZIndex = props.ZIndex,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, btn)
		local c = make("UITextSizeConstraint", { MinTextSize = MIN_TEXT_SIZE, MaxTextSize = 15 }, btn)
		table.insert(textConstraints, { c, 15 })
		btn.Activated:Connect(function()
			if btn:GetAttribute("Disabled") == true then return end
			SQ.press()
		end)
	elseif label then
		local c = label:FindFirstChildOfClass("UITextSizeConstraint")
		if c then table.insert(textConstraints, { c, 15 }) end
	end
	SQ.Btn, SQ.Label = btn, label or btn
	SQ.Base = btn:IsA("GuiButton") and btn.BackgroundTransparency or 0 -- the code button's own look (dimmed = fainter)
	btn.Parent = ui.GooseChip
end

-- the button's width (logical px) for a word: the word measured at the size it is drawn - the label's screen-px floor
-- (its UITextSizeConstraint minimum, real px: under UIScale s it draws MinTextSize / s logical) or its drawn line, never
-- under SQ.Size - in the label's own font (UIKit.MeasureText), else ~0.62 em a letter; + SQ.Pad, clamped MinW..MaxW
function SQ.need(word, label, kit, s)
	s = (type(s) == "number" and s > 0) and s or 1
	local size = SQ.Size
	if label then
		local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
		if tc then size = math.max(size, tc.MinTextSize / s) end
		local drawn = label.TextBounds.Y / s
		if drawn > size and drawn < size * 3 then size = drawn end
	end
	local text = tostring(word or "")
	local w = nil
	if label and type(kit) == "table" and type(kit.MeasureText) == "function" then
		local ok, _, mw = pcall(kit.MeasureText, text, math.ceil(size), label.FontFace, 100000)
		if ok and type(mw) == "number" and mw > 0 then w = mw end
	end
	w = w or (utf8.len(text) or #text) * size * 0.62
	return math.clamp(math.ceil(w + SQ.Pad), SQ.MinW, SQ.MaxW)
end

-- every tick: the button from EggFx.SquareButton (nil = hidden). Inside = Leave on the bar, else Join on the chip; dimmed =
-- Disabled (no press, no click sound) + faded art / words, never any text
function SQ.update()
	local btn, e = SQ.Btn, eggFxOf()
	if not btn then return end
	local want = nil
	if e and type(e.SquareButton) == "function" and type(e.SquareCtx) == "function" then
		local ok, b = pcall(function() return e.SquareButton(e.SquareCtx()) end)
		if ok and type(b) == "table" then want = b end
	end
	SQ.Word = want and want.Word or nil
	if not want then
		setVisible(btn, false)
		return
	end
	-- Leave sits on the egg bar while it shows; after the round (no bar) it sits on the chip, which updateGoose keeps shown
	local home = (want.Word == "Leave" and ui.Tug.Visible) and ui.Tug or ui.GooseChip
	if btn.Parent ~= home then btn.Parent = home end
	local word = SQ.word(want.Word)
	setText(SQ.Label, word)
	-- as wide as the word (re-measured when the word, the scale or the drawn line changes)
	local s = currentScale()
	local key = word .. "|" .. s .. "|" .. SQ.Label.TextBounds.Y
	if not SQ.Fit or SQ.Fit.Key ~= key then SQ.Fit = { Key = key, W = SQ.need(word, SQ.Label, C and C.UIKit, s) } end
	if btn.Size.X.Offset ~= SQ.Fit.W then btn.Size = UDim2.fromOffset(SQ.Fit.W, SQ.H) end
	local dim = want.Dim == true
	if btn:GetAttribute("Disabled") ~= dim then btn:SetAttribute("Disabled", dim) end
	if btn:IsA("ImageButton") then
		local a = dim and 0.55 or 0
		if btn.ImageTransparency ~= a then btn.ImageTransparency = a end
	else
		local a = dim and math.max(0.6, SQ.Base) or SQ.Base
		if btn.BackgroundTransparency ~= a then btn.BackgroundTransparency = a end
	end
	local t = dim and 0.5 or 0
	if SQ.Label:IsA("TextLabel") or SQ.Label:IsA("TextButton") then
		if SQ.Label.TextTransparency ~= t then SQ.Label.TextTransparency = t end
	end
	setVisible(btn, true)
end

-- the goose chip's insides for its height h (du): icon h x IconK at Left, the words after it + Gap up to Right.
-- -> the room the chip keeps around its words (du)
function SQ.FitGoose(h)
	local G = L.GooseChip
	local icon, label = ui.GooseIcon, ui.GooseChipText
	local iw = icon and math.max(8, math.floor((tonumber(h) or L.PillH) * G.IconK + 0.5)) or 0
	if icon then
		local size, pos = UDim2.fromOffset(iw, iw), UDim2.new(0, G.Left, 0.5, 0)
		if icon.Size ~= size then icon.Size = size end
		if icon.Position ~= pos then icon.Position = pos end
	end
	-- 최종 검수 10/15 (publish7 PC: '7:29' alone): the icon steps aside before the words go (SQ.IconOff, SQ.chipLine)
	if icon and icon.Visible == (SQ.IconOff == true) then icon.Visible = SQ.IconOff ~= true end
	local x = G.Left + ((icon and SQ.IconOff ~= true) and (iw + G.Gap) or 0)
	if label then
		local right = G.Right + ((SQ.NewRes or 0) > 0 and (SQ.NewRes - G.Right) or 0) -- 1안 ③: the NEW! room
		local pos, size = UDim2.fromOffset(x, 1), UDim2.new(1, -(x + right), 1, -2)
		if label.Position ~= pos then label.Position = pos end
		if label.Size ~= size then label.Size = size end
	end
	return x + G.Right
end

-- the goose chip's width (du) for its whole line ("Golden Goose 3:43") at height h: never narrower than GOOSE_CHIP_W
function SQ.GooseNeed(h)
	local G = L.GooseChip
	local room = G.Left + (ui.GooseIcon and (math.max(8, math.floor((tonumber(h) or L.PillH) * G.IconK + 0.5)) + G.Gap) or 0) + G.Right
	local label, kit = ui.GooseChipText, C and C.UIKit
	local text = SQ.FullLine or (label and label.Text) or ""
	if not (label and text ~= "" and type(kit) == "table" and type(kit.MeasureText) == "function") then return GOOSE_CHIP_W end
	-- 최종 검수 10/14 (publish4: PC showed "Goose 3:35" with room to spare): SQ.chipLine fits the line at the text
	-- floor in SCREEN px (UITextSizeConstraint ignores UIScale), so the chip asks for that width back in du (/ scale);
	-- measured in du before, a PC at UIScale 0.8 got a chip 20% too narrow and always the short line
	local s = currentScale()
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	local size = math.max(label.TextSize * s, c and c.MinTextSize or 0)
	local ok, _, w = pcall(kit.MeasureText, (string.gsub(text, "%d", "0")), size, label.FontFace, 100000)
	if not (ok and type(w) == "number" and w > 0) then return GOOSE_CHIP_W end
	return math.max(GOOSE_CHIP_W, math.ceil(room + w / s + 2))
end

-- A23-145 (phone photos 10/13): "Golden Goose 117:23" lost its time on a phone (the text floor is bigger than the
-- chip): the longest line that fits the chip at its smallest text size - "Golden Goose 1:57:23" -> "Goose 1:57:23" ->
-- "1:57:23" (the goose icon says what)
function SQ.chipLine(seconds)
	local t = Util.FormatTime(seconds)
	local lines = { L.Tx(TXT, "GooseNext", t), L.Tx(TXT, "GooseNextShort", t), t }
	SQ.FullLine = lines[1] -- the chip's width asks for the whole line (SQ.GooseNeed)
	local label, kit = ui.GooseChipText, C and C.UIKit
	if not (label and type(kit) == "table" and type(kit.MeasureText) == "function") then return lines[1] end
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	local size = c and c.MinTextSize or label.TextSize
	local w = label.AbsoluteSize.X
	if w <= 0 or size <= 0 then return lines[1] end
	-- 최종 검수 10/15 (publish7 PC: '7:29' alone - 'Goose 7:29' was 89 px for an 85 px words box at the 18 px floor):
	-- 'Golden Goose t' -> 'Goose t' -> 'Goose t' with the icon's room given to the words -> the time alone (last)
	local icon = ui.GooseIcon
	local room = icon and (icon.Size.X.Offset + L.GooseChip.Gap) * currentScale() or 0
	local withIcon = SQ.IconOff == true and w - room or w
	local function fits(line, width)
		-- every digit as a 0: one measure per length (the time changes every second; MeasureText caches)
		local ok, _, lw = pcall(kit.MeasureText, (string.gsub(line, "%d", "0")), size, label.FontFace, 100000)
		return ok and type(lw) == "number" and lw <= width + 1
	end
	local off = nil
	local pick = t
	if fits(lines[1], withIcon) then
		off, pick = false, lines[1]
	elseif fits(lines[2], withIcon) then
		off, pick = false, lines[2]
	elseif room > 0 and fits(lines[2], withIcon + room) then
		off, pick = true, lines[2]
	else
		off = false
	end
	if (SQ.IconOff == true) ~= off then
		SQ.IconOff = off
		if ui.GooseChip then SQ.FitGoose(ui.GooseChip.Size.Y.Offset) end
	end
	return pick
end

----------------------------------------------------------------- per-tick updates
local function updateGoose(now)
	SQ.Out = false
	if gsAttr("GooseActive", false) == true then
		-- A23-141: Eggs mode outside the Goose Square - the chip shows only the goose time (+ the Join button, SQ.update),
		-- no egg bar; inside the square the bar below shows as before
		local eggFx = C and C.EggFx
		local eggMode = type(eggFx) == "table" and type(eggFx.On) == "function" and eggFx.On()
		if eggMode and type(eggFx.Here) == "function" and not eggFx.Here() then
			SQ.Out = true
			setVisible(ui.Tug, false)
			setVisible(ui.TugSub, false)
			if ui.TugCrown then setVisible(ui.TugCrown, false) end
			local endAt = eggFx.TickEnd(gsAttr("GooseEndsAt", 0), gsAttr("GooseOvertimeUntil", 0), now)
			setVisible(ui.GooseChip, true)
			setText(ui.GooseChipText, SQ.chipLine(math.max(0, num(endAt) - now)))
			return
		end
		setVisible(ui.GooseChip, false)
		setVisible(ui.Tug, true)
		-- A23-130: the bar alone (Config.Nudges.GooseSub = false hides the "My points …" line under it)
		setVisible(ui.TugSub, not (type(Config.Nudges) == "table" and Config.Nudges.GooseSub == false))
		local rescue = math.max(0, num(gsAttr("GooseRescue", 0)))
		local poach = math.max(0, num(gsAttr("GoosePoach", 0)))
		local timeLeft = Util.FormatTime(num(gsAttr("GooseEndsAt", 0)) - now)
		local faction = myAttr("Faction", "None")
		local mine = math.floor(math.max(0, num(myAttr("GooseCount", 0))))
		-- A23-131 황금 알 줍기 (Config.Goose.Mode "Eggs", EggFx.Bar; contract golden_egg_contract §5): the bar alone - the
		-- Knights' points left (gold fill), the Horn Legion's right, the time in the middle; co-op = "50 / 160" in that
		-- side's colour; the crown egg's overtime = the crown icon and a gold clock. No line under it (A23-130).
		if eggMode then
			setVisible(ui.TugSub, false)
			local b = eggFx.Bar({ Rescue = rescue, Poach = poach, EndsAt = gsAttr("GooseEndsAt", 0),
				OvertimeUntil = gsAttr("GooseOvertimeUntil", 0), Mode = gsAttr("GooseMode", "Versus"),
				CoopSide = gsAttr("GooseCoopSide", "None"), CoopTarget = gsAttr("GooseCoopTarget", 0) }, now)
			if not b then -- outside the Goose Square (EggFx.Bar is nil there): no egg bar
				setVisible(ui.Tug, false)
				return
			end
			local col = (b.Coop and b.Side == "Horns") and AC.WarHorns or AC.WarHalo
			if ui.TugLeft.BackgroundColor3 ~= col then ui.TugLeft.BackgroundColor3 = col end
			setVisible(ui.TugRight, not b.Coop)
			ui.TugLeft.Size = UDim2.fromScale(b.Fill, 1)
			setVisible(ui.TugLeft, b.Fill > 0.001)
			setText(ui.TugLeftText, b.Coop and L.Tx(TXT, "EggCoop", b.Left, b.Right) or L.Tx(TXT, "EggScore", b.Left))
			setText(ui.TugRightText, b.Coop and "" or L.Tx(TXT, "EggScore", b.Right))
			setText(ui.TugCenterText, Util.FormatTime(b.Seconds))
			local clock = b.Overtime and GOLD or ui.TugCenterInk
			if clock and ui.TugCenterText.TextColor3 ~= clock then ui.TugCenterText.TextColor3 = clock end
			if ui.TugCrown then setVisible(ui.TugCrown, b.Overtime) end
			return
		end
		if ui.TugCrown then setVisible(ui.TugCrown, false) end
		-- A23-14 "함께 구조 / 함께 밀렵": only one tug side is on the server, so its own total fills toward
		-- GooseCoopTarget in that side's colour (no rival bar, no "줄다리기" title). Texts: Config.Goose.Text.Hud*.
		local gt = Config.Goose and Config.Goose.Text
		local side = gsAttr("GooseCoopSide", "None")
		if gsAttr("GooseMode", "Versus") == "Coop" and (side == "Halo" or side == "Horns")
			and type(gt) == "table" and type(gt.HudTitle) == "table" then
			local total = (side == "Halo") and rescue or poach
			local target = math.max(1, math.floor(num(gsAttr("GooseCoopTarget", 0))))
			local fill = math.clamp(total / target, 0, 1)
			local col = (side == "Halo") and AC.WarHalo or AC.WarHorns
			if ui.TugLeft.BackgroundColor3 ~= col then ui.TugLeft.BackgroundColor3 = col end
			setVisible(ui.TugRight, false)
			ui.TugLeft.Size = UDim2.fromScale(fill, 1)
			setVisible(ui.TugLeft, fill > 0.001)
			setText(ui.TugLeftText, safeFormat(gt.HudProgress, math.floor(total), target))
			setText(ui.TugRightText, safeFormat(gt.HudPeople, math.floor(num(gsAttr("GooseCoopPeople", 0)))))
			setText(ui.TugCenterText, safeFormat(gt.HudTitle[side], timeLeft))
			local coopSub
			if faction == side then
				if total < target then
					coopSub = safeFormat(type(gt.HudSub) == "table" and gt.HudSub[side] or nil, mine)
				else
					coopSub = Config.Plural(safeFormat(type(gt.HudFull) == "table" and gt.HudFull[side] or nil, mine,
						math.floor(num(Config.Goose.MinManualHits)))) -- "Hit it 1 time"
				end
			elseif faction == "Halo" or faction == "Horns" then
				coopSub = type(gt.HudOther) == "table" and gt.HudOther[side] or ""
			elseif faction == "Neutral" then
				coopSub = TXT.HintNeutral
			else
				coopSub = L.Tx(TXT, "MyCount", mine)
			end
			setText(ui.TugSub, coopSub)
			return
		end
		-- tug (Versus): restore the pieces the co-op view changed
		if ui.TugLeft.BackgroundColor3 ~= AC.WarHalo then ui.TugLeft.BackgroundColor3 = AC.WarHalo end
		setVisible(ui.TugRight, true)
		local total = rescue + poach
		local frac = 0.5
		if total > 0 then frac = math.clamp(rescue / total, 0, 1) end
		-- rescue (gold) grows from the left over the full-width poach (red) capsule
		ui.TugLeft.Size = UDim2.fromScale(frac, 1)
		setVisible(ui.TugLeft, frac > 0.001)
		setText(ui.TugLeftText, L.Tx(TXT, "Rescue", math.floor(rescue)))
		setText(ui.TugRightText, L.Tx(TXT, "Poach", math.floor(poach)))
		setText(ui.TugCenterText, L.Tx(TXT, "GooseTitle", timeLeft))
		local sub
		if faction == "Halo" then
			sub = L.Tx(TXT, "MyCount", mine) .. " · " .. TXT.HintHalo
		elseif faction == "Horns" then
			sub = L.Tx(TXT, "MyCount", mine) .. " · " .. TXT.HintHorns
		elseif faction == "Neutral" then
			sub = TXT.HintNeutral
		else
			sub = L.Tx(TXT, "MyCount", mine)
		end
		setText(ui.TugSub, sub)
	else
		setVisible(ui.Tug, false)
		setVisible(ui.TugSub, false)
		local nextAt = num(gsAttr("GooseNextAt", 0))
		-- 개발 2 10/13: still in the Goose Square after the round = the chip stays for the Leave button (SQ.update)
		local eggFx = C and C.EggFx
		local inside = type(eggFx) == "table" and type(eggFx.Inside) == "function" and eggFx.Inside() == true
		if nextAt > 0 then
			setVisible(ui.GooseChip, true)
			setText(ui.GooseChipText, SQ.chipLine(nextAt - now))
		elseif inside then
			setVisible(ui.GooseChip, true)
			setText(ui.GooseChipText, "")
		else
			setVisible(ui.GooseChip, false)
		end
	end
end

-- Halloween Pumpkin King line (GameState PumpkinKing*, texts Config.Halloween.Text with English twins); only while
-- the season is on. Before it appears: "호박 대왕까지 m:ss"; while it is here: "호박 대왕 출현! 남은 시간 m:ss".

function KING.english()
	local st = C and C.Settings
	if type(st) ~= "table" or type(st.Get) ~= "function" then return false end
	local ok, lang = pcall(st.Get, "Lang")
	return ok and lang == "en"
end

-- the width (logical px) the pill's words take as drawn now (TextBounds: real px at the size the text floors left them),
-- + the side insets; 0 before the label exists. The measured / estimated need can be smaller than the drawn words
-- when a style floor raised the size (phones: 14 px body floor, 2026-10-07 'Pumpkin King is here!' spilled out)
function KING.drawn()
	local label = ui.KingChipText
	if not label or label.Text == "" then return 0 end
	local s = currentScale()
	if s <= 0 then s = 1 end
	return math.ceil(label.TextBounds.X / s + 26)
end

-- the pill's slot (logical px, never on HUD's player card / quest column, its bottom-right cluster or the kaiju pill):
-- 1. left of the strip, between HUD.Layout.LeftX (right edge of the card + quest column) and the strip, shrinking
--    down to L.KingMinW; 2. right of the strip (after the kaiju pill while it shows) up to HUD.Layout.RightX (desktop:
--    left of the luck panel) when that stays clear of the cluster; 3. else centred in a row under HUD's status chips,
--    and the touch personal line moves one row lower (KING.Below)
-- width (logical px) the current line needs at a readable size: the pill never gets narrower (review of 1614575: at
-- KingMinW the scaled text broke into two lines on phones / in English). Measured in the label's own font (UIKit
-- TextService cache; A23-63 Montserrat is wider than the old estimate assumed), else Hangul / CJK ~1 em, the rest ~0.56 em.
function KING.need(text)
	local kit = C and C.UIKit
	local label = ui.KingChipText
	if label and type(kit) == "table" and type(kit.MeasureText) == "function" then
		local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
		local size = math.max(15, tc and tc.MinTextSize or 0)
		-- 검수 10/09 (the quest lines' 'To the F…', e0f9836f): under UIScale the screen-px floor draws the words bigger than
		-- the logical size - measure at the size actually drawn (one-line TextBounds height, back in logical units)
		local drawn = label.TextBounds.Y / currentScale()
		if drawn > size and drawn < size * 3 then size = math.ceil(drawn) end
		local ok, _, w = pcall(kit.MeasureText, tostring(text or ""), size, label.FontFace, 100000)
		if ok and type(w) == "number" and w > 0 then return math.ceil(w + 26) end
	end
	local em, w = 14, 0
	for _, cp in utf8.codes(tostring(text or "")) do
		w += (cp >= 0x2E80 and em or em * 0.56)
	end
	return math.ceil(w + 26)
end

function KING.place(chip)
	local strip = ui.Strip
	local root = strip and strip.Parent
	if not root or not root:IsA("GuiBase2d") then return end
	local s = currentScale()
	local hl = C and type(C.HUD) == "table" and type(C.HUD.Layout) == "table" and C.HUD.Layout or {}
	local gap = L.KingGap
	local need = math.max(KING.need(ui.KingChipText and ui.KingChipText.Text), KING.drawn())
	local minW, maxW = math.max(L.KingMinW, need), math.max(L.KingW, need)
	local W = num(hl.W) > 0 and hl.W or root.AbsoluteSize.X / s
	local x0 = (strip.AbsolutePosition.X - root.AbsolutePosition.X) / s
	local x1 = x0 + strip.AbsoluteSize.X / s
	local y0 = (strip.AbsolutePosition.Y - root.AbsolutePosition.Y) / s
	local below = false
	local room = x0 - gap - math.max(gap, num(hl.LeftX))
	if room >= minW then
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(0, -gap, 0, 0)
		chip.Size = UDim2.fromOffset(math.floor(math.min(room, maxW)), L.PillH)
	else
		local kaiju = (ui.KaijuChip and ui.KaijuChip.Visible) and (KAIJU_CHIP_W + gap) or 0
		local left = x1 + gap + kaiju
		room = (num(hl.RightX) > 0 and hl.RightX or W - gap) - left
		local w = math.floor(math.min(room, maxW))
		local clusterTop = num(hl.ClusterTop)
		local blocked = clusterTop > 0 and y0 + L.PillH > clusterTop - gap and left + w > num(hl.ClusterLeft) - gap
		if room >= minW and not blocked then
			chip.AnchorPoint = Vector2.new(0, 0)
			chip.Position = UDim2.new(1, gap + kaiju, 0, 0)
			chip.Size = UDim2.fromOffset(w, L.PillH)
		else
			below = true
			local cb = hudBottom("StatusChips", s)
			if not cb then cb = y0 + strip.Size.Y.Offset + L.StripGap + L.ChipsH end
			chip.AnchorPoint = Vector2.new(0.5, 0)
			chip.Position = UDim2.new(0.5, 0, 0, math.floor(cb + L.StripGap - y0 + 0.5))
			chip.Size = UDim2.fromOffset(math.floor(math.min(maxW, W - 24)), L.PillH)
		end
	end
	KING.setBelow(below)
end

-- the touch personal line follows the pill row (layout() reads KING.Below)
function KING.setBelow(below)
	if KING.Below == below then return end
	KING.Below = below
	relayout()
end

-- A23-45: the minibosses of Config.Halloween.Bosses (GameState <Key>Active / <Key>EndsAt / <Key>NextAt): the live one
-- ending soonest wins, else the next one to appear. Returns key, active, seconds (nil when none is scheduled)
KING.TEXT = { PumpkinKing = { "HudNext", "HudActive" }, GhostKing = { "GhostHudNext", "GhostHudActive" } }
function KING.pick(now)
	local H = Config.Halloween
	local list = type(H) == "table" and type(H.Bosses) == "table" and H.Bosses or { { Key = "PumpkinKing" } }
	local best, bestActive, bestT = nil, false, math.huge
	for _, b in list do
		local key = type(b) == "table" and b.Key or nil
		if type(key) == "string" then
			if gsAttr(key .. "Active", false) == true then
				local t = num(gsAttr(key .. "EndsAt", 0)) - now
				if not bestActive or t < bestT then best, bestActive, bestT = key, true, t end
			elseif not bestActive then
				local nextAt = num(gsAttr(key .. "NextAt", 0))
				if nextAt > 0 and nextAt - now < bestT then best, bestT = key, nextAt - now end
			end
		end
	end
	return best, bestActive, best and bestT or nil
end

-- A23-63 (2026-10-07): the live line in a narrower form when the full one cannot fit the next-event line (phones with
-- notch insets: the centre column is 240 du = 180 px and the phone text floor is 14 px)
KING.SHORT = { HudActive = "Pumpkin King! %s left", GhostHudActive = "Ghost King! %s left" }

-- full or short: the full line measured at the drawn line height against the event line's width minus the pill insets
-- (real px like TextBounds), so a short line never sticks once the room is back
function KING.fit(full, short)
	local label = ui.KingChipText
	local rects = V2.rects()
	local ev = type(rects) == "table" and rects.event or nil
	local kit = C and C.UIKit
	if not (label and type(ev) == "table" and num(ev.W) > 0 and type(kit) == "table"
		and type(kit.MeasureText) == "function") then
		return full
	end
	local h = label.TextBounds.Y
	if h <= 0 then return full end
	local ok, _, w = pcall(kit.MeasureText, full, h, label.FontFace, 100000)
	if not ok or type(w) ~= "number" then return full end
	return (w > (num(ev.W) - 24) * currentScale() + 1) and short or full
end

function KING.update(now)
	local chip = ui.KingChip
	if not chip then return end
	local H = Config.Halloween
	local text = type(H) == "table" and H.Enabled == true and type(H.Text) == "table" and H.Text or nil
	local line = nil
	if text then
		local en = KING.english()
		local key, active, t = KING.pick(now)
		local keys = key and (KING.TEXT[key] or KING.TEXT.PumpkinKing)
		if keys then
			local k = active and keys[2] or keys[1]
			line = safeFormat((en and text[k .. "En"]) or text[k], Util.FormatTime(t))
			if KING.SHORT[k] then line = KING.fit(line, string.format(KING.SHORT[k], Util.FormatTime(t))) end
		end
	end
	setVisible(chip, line ~= nil and line ~= "")
	if line and line ~= "" then
		setText(ui.KingChipText, line)
		KING.place(chip)
	else
		KING.setBelow(false)
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
		setText(ui.KaijuChipText, L.Tx(TXT, "KaijuChip", kaijuName(L.KaijuNameMax), Util.FormatTime(endsAt - now)))
	else
		setVisible(ui.KaijuChip, false)
	end
	if phase == "Siren" then
		local left = math.max(0, math.ceil(endsAt - now))
		local text = safeFormat(Config.Story.KaijuSiren, kaijuName()) .. "  " .. L.Tx(TXT, "SirenLeft", left)
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
		text = L.Tx(TXT, "Sack", Util.FormatNumber(sack), secs)
		color = ink.Sack
	elseif myAttr("KaijuState", "None") == "Active" then
		local endsAt = 0
		if num(gsAttr("KaijuUserId", 0)) == LocalPlayer.UserId then endsAt = num(gsAttr("KaijuEndsAt", 0)) end
		text = L.Tx(TXT, "KaijuSelf", Util.FormatTime(endsAt - now))
		color = ink.Kaiju
	else
		local target, untilT = revengeTarget(now)
		if target then
			text = L.Tx(TXT, "Revenge", Util.PlayerDisplayName(target), Util.FormatTime(untilT - now))
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
			star = Art.image("Star", { Name = "Star" .. i, LayoutOrder = i, Size = sz, ZIndex = 4 }, ui.CheerStars)
			if not star then break end
			pool[i] = star
		end
		if star then
			setVisible(star, i <= shown)
			if i <= shown then
				local id = (i <= filled) and ui.StarFull or ui.StarEmpty
				if star.Image ~= id then star.Image = id end
				local tint = (i <= filled) and AC.StarGold or AC.StarEmpty
				if star.ImageColor3 ~= tint then star.ImageColor3 = tint end
				if star.Size ~= sz then star.Size = sz end
			end
		end
	end
end

-- luck numbers: line 1 text ("오늘의 운 · 희귀 5.25%"), cheer stars, stars needed, filled stars, the bare percent ("5.25")
local function luckData()
	local events = math.max(0, math.floor(num(myAttr("LuckEvents", 0))))
	local pct = Util.FormatPercent(Config.RareChance(events))
	local line1 = L.Tx(TXT, "Luck", pct)
	local need = math.floor(num(Config.Goose and Config.Goose.CheerStarsForRare))
	if need <= 0 then need = 5 end
	local stars = math.max(0, math.floor(num(myAttr("CheerStars", 0))))
	return line1, stars, need, math.min(stars, need), pct
end

-- "응원별 ★★☆☆☆ (2/5)"
local function cheerText(stars, need, filled)
	return L.Tx(TXT, "Cheer", string.rep("★", filled) .. string.rep("☆", need - filled), stars, need)
end

local function updateLuck()
	local line1, stars, need, filled = luckData()
	setText(ui.LuckLine1, line1)
	if ui.CheerStars then
		setStars(filled, need)
		setText(ui.CheerCount, L.Tx(TXT, "CheerCount", stars, need))
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
					local text = L.Tx(TXT, "ArrowSack", Util.FormatNumber(sackGold))
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
	if sawSack and isHalo and not loreShown and (Config.Nudges or {}).SackLore ~= false then
		loreShown = true
		uiToast(safeFormat(Config.Story.SackLore), "info", 4)
	end
end

----------------------------------------------------------------- HUD v2 notify column (A23-26)
-- The column is C.HUD.Layout.Rects.notify (logical MainGui units, the top bar already included). Top-down priority:
-- personal line > kaiju siren > goose tug (+ its hint line) > kaiju pill > Pumpkin King pill (live, else its
-- countdown) > goose countdown pill. Every row is centred on the column, min(natural width, column width) wide; a row
-- that would pass the column's bottom is hidden (a later HUD step may fold those into chips). The per-tick updates
-- still decide what wants to show (Visible); V2.tick reads that right after them and places / hides the rows in the
-- same resumption, so an overflowing row never flashes. Without Rects the legacy layout() path runs unchanged.

-- C.HUD.Layout.Rects (+ the layout table) while HUD v2 publishes a usable notify rect, else nil. Read lazily: HUD
-- rebuilds the layout table on every pass.
function V2.rects()
	local hud = C and C.HUD
	local hl = type(hud) == "table" and hud.Layout or nil
	local rects = type(hl) == "table" and hl.Rects or nil
	local n = type(rects) == "table" and rects.notify or nil
	if type(n) == "table" and num(n.W) > 0 and num(n.H) > 0 then return rects, hl end
	return nil
end

-- 최종 검수 10/14 (user photo: the goose chip half over the 'Crown War · 9:38' line): the next-event chip never starts
-- above the drawn bottom of the top-centre HUD (HUD.TopBottom: the war meter with its info line / plate, the chips row)
-- plus Gap - one column, top to bottom, on PCs and phones. Pure (tools/test_hud_top_overlap.py)
V2.TopGap = 6
-- 최종 검수 10/14 상단 HUD 1안 ③ / ④ (real px): the event chip H tall (phone HTouch = the touch target), its words at
-- least TextPx, the NEW! tag INSIDE its right end (NewW wide, NewGap from the words, NewRight from the end; dropped
-- first when the chip cannot widen for it), shown NewSeconds
L.EventTop = { H = 40, HTouch = 44, TextPx = 18, TextPxTouch = 19, NewW = 58, NewWTouch = 62, NewGap = 8, NewRight = 10,
	NewSeconds = 6 }

-- (pure) 1안 ③: ONE event chip - cands = { { Inst, Class, In } }: Class 2 = a danger on me now (the kaiju), 3 = an event
-- I can join now (the live king, the open goose), 4 = the nearest coming one (In = seconds); the lowest class wins, then
-- the soonest; a tie (same class; class 4: the same second) keeps the chip shown now (`current`: no swapping each tick)
function V2.PickEvent(cands, current)
	local best = nil
	for _, c in cands do
		if not best or c.Class < best.Class or (c.Class == best.Class and num(c.In) < num(best.In)) then best = c end
	end
	if not best then return nil end
	for _, c in cands do
		if c.Inst == current and c.Class == best.Class and (c.Class < 4 or math.abs(num(c.In) - num(best.In)) < 1) then
			return current
		end
	end
	return best.Inst
end

-- the event chips' words at least L.EventTop.TextPx real px (their UITextSizeConstraints are screen px)
function V2.EventMinText()
	local px = IS_TOUCH and L.EventTop.TextPxTouch or L.EventTop.TextPx
	for _, label in { ui.GooseChipText, ui.KingChipText, ui.KaijuChipText } do
		local c = label and label:FindFirstChildOfClass("UITextSizeConstraint")
		if c then
			if c.MaxTextSize < px then c.MaxTextSize = px end
			c.MinTextSize = px
		end
	end
end

-- the kaiju chip's width (du) for its whole line at the event words' floor (test Studio photo 10/14: 'Kaiju Big Slim..
-- 4:36' wrapped to 'Kaiju' in a 65 px chip): measured like the goose line (screen px / UIScale) + its side insets
function V2.KaijuNeed(s)
	local label, kit = ui.KaijuChipText, C and C.UIKit
	if not (label and label.Text ~= "" and type(kit) == "table" and type(kit.MeasureText) == "function") then return KAIJU_CHIP_W end
	local px = IS_TOUCH and L.EventTop.TextPxTouch or L.EventTop.TextPx
	local ok, _, w = pcall(kit.MeasureText, (string.gsub(label.Text, "%d", "0")), px, label.FontFace, 100000)
	if not (ok and type(w) == "number" and w > 0) then return KAIJU_CHIP_W end
	return math.max(KAIJU_CHIP_W, math.ceil(w / math.max(0.1, s) + 26))
end

-- the NEW! room (du) the shown event chip keeps on its right while its tag shows, else 0
function V2.NewRoom(inst)
	if not (inst and V2.NewOn == inst and os.clock() < (V2.NewUntil or 0)) then return 0 end
	local E = L.EventTop
	return ((IS_TOUCH and E.NewWTouch or E.NewW) + E.NewGap + E.NewRight) / currentScale()
end

function V2.EventTop(evY, hudBottom, gap)
	evY = num(evY)
	if type(hudBottom) == "number" and hudBottom == hudBottom then
		return math.max(evY, hudBottom + (tonumber(gap) or V2.TopGap))
	end
	return evY
end

function V2.hudBottom()
	local hud = C and C.HUD
	if type(hud) ~= "table" or type(hud.TopBottom) ~= "function" then return nil end
	local ok, b = pcall(hud.TopBottom)
	return ok and type(b) == "number" and b or nil
end

-- the next-event line's top (du): its own row (Rects.event), or the status chip row's when that row is empty (user
-- 10/13 first look: out of town the goose pill floated a whole empty row under the war meter). chipsShown = HUD's answer
-- (nil = unknown -> its own row). Pure (tools/test_event_lift.py)
function V2.eventY(rects, chipsShown)
	local ev = type(rects) == "table" and rects.event or nil
	if type(ev) ~= "table" then return nil end
	local chips = rects.chips
	if chipsShown == false and type(chips) == "table" and type(chips.Y) == "number" and chips.Y < num(ev.Y) then
		return chips.Y
	end
	return num(ev.Y)
end

-- the drawn bottom (du) of the next-event chip while the column places it (QuestMarker keeps the marker under it)
function EventHUD.TopBottom()
	return V2.Active and V2.EventBottom or nil
end

function V2.chipsShown()
	local hud = C and C.HUD
	if type(hud) ~= "table" or type(hud.ChipsShown) ~= "function" then return nil end
	local ok, shown = pcall(hud.ChipsShown)
	if not ok then return nil end
	return shown == true
end

function V2.put(inst, anchor, pos, size)
	if inst.AnchorPoint ~= anchor then inst.AnchorPoint = anchor end
	if inst.Position ~= pos then inst.Position = pos end
	if inst.Size ~= size then inst.Size = size end
	if inst == ui.GooseChip then SQ.FitGoose(size.Y.Offset) end -- the icon and the words follow the chip's height
	-- 1안 ③: the king / kaiju words keep clear of the NEW! room inside the right end
	local words = inst == ui.KingChip and ui.KingChipText or inst == ui.KaijuChip and ui.KaijuChipText or nil
	if words then
		local res = V2.NewRoom(inst)
		local want = UDim2.new(1, -(24 + (res > 0 and res - 12 or 0)), words.Size.Y.Scale, words.Size.Y.Offset)
		if words.Size ~= want then words.Size = want end
	end
end

-- switch to the column: remember the build-time / legacy spot of every moved element (V2.leave puts them back)
function V2.enter()
	if V2.Active then return end
	local subH = IS_TOUCH and L.SubHTouch or SUB_H
	-- W = natural width, H = height; Strip = child of the event strip (else of the gui root); Flex = as tall as the
	-- room left, up to H (at least a pill); Tail = a line under the row, dropped first when the column is full
	V2.Rows = {
		{ Inst = ui.Personal, W = PERSONAL_W, H = PERSONAL_H },
		{ Inst = ui.Siren, W = math.huge, H = SIREN_H, Flex = true },
		{ Inst = ui.Tug, W = STRIP_W, H = BAR_H, Strip = true, Tail = ui.TugSub, TailH = subH },
		{ Inst = ui.KaijuChip, W = KAIJU_CHIP_W, H = L.PillH, Strip = true },
		{ Inst = ui.KingChip, W = L.KingW, H = L.PillH, Strip = true, King = true },
		{ Inst = ui.GooseChip, W = GOOSE_CHIP_W, H = L.PillH + L.GooseChip.PlusH, Strip = true, Goose = true },
	}
	V2.Saved = {}
	for _, inst in { ui.Strip, ui.Personal, ui.Siren, ui.SirenText, ui.Tug, ui.TugSub, ui.KaijuChip, ui.KingChip,
		ui.GooseChip } do
		table.insert(V2.Saved, { inst, inst.AnchorPoint, inst.Position, inst.Size, inst.ZIndex })
	end
	V2.Active = true
	KING.Below = false -- legacy only (the touch personal line row under HUD's chips)
	ui.Strip.ZIndex = PERSONAL_Z -- CR-L37: the whole column draws above HUD's root frame (ZIndex 5)
	ui.SirenText.Size = UDim2.new(1, -16, 1, -(2 * L.TrimH + 4)) -- the column band is narrower than the screen
	setVisible(ui.Luck, false) -- HUD v2 draws a luck chip (EventHUD.LuckSummary / LuckShort)
end

-- back to the legacy layout (HUD stopped publishing Rects): restore the remembered spots
function V2.leave()
	if not V2.Active then return end
	V2.Active = false
	V2.Key, V2.Col = nil, nil
	for _, saved in V2.Saved or {} do
		local inst = saved[1]
		inst.AnchorPoint = saved[2]
		inst.Position = saved[3]
		inst.Size = saved[4]
		inst.ZIndex = saved[5]
	end
	V2.Saved = nil
	table.clear(V2.Want)
	lastLayoutKey = nil
end

-- geometry pass, cached on the notify rect numbers + HUD.Layout.ChipsBottom + the touch minimum text size
function V2.layout()
	local rects, hl = V2.rects()
	if not rects then return end
	local root = ui.Strip and ui.Strip.Parent
	if not root then return end
	if not guiScale or guiScale.Parent == nil then
		guiScale = root:FindFirstChildOfClass("UIScale")
	end
	local inset, rawInset = insetY()
	arrowGeo.Inset = inset -- CR-L43: the edge arrows keep below the top bar in v2 too
	arrowGeo.TopLeft = rawInset
	local s = currentScale()
	local minText = MIN_TEXT_SIZE
	if IS_TOUCH then minText = math.max(MIN_TEXT_SIZE, math.ceil(MIN_TEXT_SIZE / s - 0.01)) end
	local n = rects.notify
	local nx, ny, nw, nh = num(n.X), num(n.Y), num(n.W), num(n.H)
	local chipsBottom = (type(hl.ChipsBottom) == "number" and hl.ChipsBottom == hl.ChipsBottom) and hl.ChipsBottom or ny
	local key = table.concat({ nx, ny, nw, nh, chipsBottom, minText }, ":")
	if V2.Active and key == V2.Key then return end
	V2.enter()
	V2.Key = key
	-- logical units already (the rect includes the top bar): no inset / scale added again
	V2.Col = {
		CX = math.floor(nx + nw / 2 + 0.5),
		W = math.floor(nw),
		Top = math.floor(math.max(ny, chipsBottom + V2.ChipsGap) + 0.5),
		Bottom = ny + nh,
	}
	applyMinText(minText)
	V2.EventMinText()
	V2.stack()
end

-- places the wanted rows top-down, hides what passes the column bottom, publishes the stack bottom ("BottomY")
function V2.stack()
	local col = V2.Col
	if V2.Busy or not (V2.Active and col and V2.Rows) then return end
	local want, gap = V2.Want, V2.Gap
	local cx, top, bottom = col.CX, col.Top, col.Bottom
	local anchor = Vector2.new(0.5, 0)
	V2.put(ui.Strip, anchor, UDim2.new(0, cx, 0, top), UDim2.fromOffset(col.W, math.max(0, math.floor(bottom - top))))
	-- A23-40 layout B: one 'next event' line (Rects.event, above this column): the Pumpkin King pill (live counts as
	-- now) or the goose countdown, whichever comes first; the other one does not show. Without Rects.event both stack
	-- in the column as before.
	local rects = V2.rects()
	local ev = type(rects) == "table" and rects.event or nil
	local eventInst = nil
	if type(ev) == "table" and num(ev.W) > 0 and num(ev.H) > 0 then
		-- 1안 ③ (최종 검수 10/14): one event chip - the kaiju on me now > the live king / open goose > the nearest one
		local cands = {}
		if want[ui.KaijuChip] == true then table.insert(cands, { Inst = ui.KaijuChip, Class = 2, In = 0 }) end
		if want[ui.KingChip] == true then
			table.insert(cands, { Inst = ui.KingChip, Class = num(V2.KingIn) <= 0 and 3 or 4, In = num(V2.KingIn) })
		end
		if want[ui.GooseChip] == true then
			table.insert(cands, { Inst = ui.GooseChip, Class = SQ.Out and 3 or 4, In = num(V2.GooseIn) })
		end
		eventInst = V2.PickEvent(cands, V2.EventCur)
		V2.EventCur = eventInst
		local s = currentScale()
		local E = L.EventTop
		local evH = math.max(num(ev.H) + (eventInst == ui.GooseChip and L.GooseChip.PlusH or 0), (IS_TOUCH and E.HTouch or E.H) / s)
		local natural
		if eventInst == ui.KingChip then
			natural = math.max(L.KingW, KING.need(ui.KingChipText and ui.KingChipText.Text), KING.drawn())
		elseif eventInst == ui.KaijuChip then
			natural = V2.KaijuNeed(s)
		else
			natural = SQ.GooseNeed(evH)
		end
		-- the NEW! room inside the right end: only when the chip can widen for it (else the tag goes, never the words)
		local res = V2.NewRoom(eventInst)
		if res > 0 and natural + res > num(ev.W) then
			V2.NewOn, res = nil, 0
			local tag = eventInst and eventInst:FindFirstChild("NewTag")
			if tag then tag:Destroy() end
		end
		SQ.NewRes = eventInst == ui.GooseChip and res or 0
		V2.EventBottom = nil
		if eventInst then
			local evY = V2.EventTop(V2.eventY(rects, V2.chipsShown()) or ev.Y, V2.hudBottom(), V2.TopGap)
			V2.put(eventInst, anchor, UDim2.new(0.5, 0, 0, math.floor(evY - top + 0.5)),
				UDim2.fromOffset(math.floor(math.min(natural + res, ev.W) + 0.5), math.floor(evH + 0.5)))
			V2.EventBottom = evY + evH
		end
		setVisible(ui.KingChip, eventInst == ui.KingChip)
		setVisible(ui.GooseChip, eventInst == ui.GooseChip)
		setVisible(ui.KaijuChip, eventInst == ui.KaijuChip)
	end
	-- 1안 ⑤: the notify rows start under the event chip's drawn bottom (its rows grew to 40 / 44 px)
	local y, last = math.max(top, V2.EventBottom and math.ceil(V2.EventBottom + gap) or top), nil
	for _, row in V2.Rows do
		local inst, tail = row.Inst, row.Tail
		if ev and (inst == ui.KingChip or inst == ui.GooseChip or inst == ui.KaijuChip) then continue end -- the event line owns them
		local w = row.W
		if row.King then w = math.max(L.KingW, KING.need(ui.KingChipText and ui.KingChipText.Text)) end
		if row.Goose then w = SQ.GooseNeed(row.H) end
		w = math.floor(math.min(w, col.W) + 0.5)
		local h = row.H
		if row.Flex then h = math.floor(math.min(row.H, bottom - y)) end
		local fits = want[inst] == true and h >= (row.Flex and L.PillH or h) and y + h <= bottom + 0.5
		local tailFits = fits and tail ~= nil and want[tail] == true and y + h + row.TailH <= bottom + 0.5
		if fits then
			if row.Strip then
				V2.put(inst, anchor, UDim2.new(0.5, 0, 0, y - top), UDim2.fromOffset(w, h))
				if tailFits then
					V2.put(tail, anchor, UDim2.new(0.5, 0, 0, y - top + h), UDim2.fromOffset(w, row.TailH))
				end
			else
				V2.put(inst, anchor, UDim2.new(0, cx, 0, y), UDim2.fromOffset(w, h))
			end
			last = y + h + (tailFits and row.TailH or 0)
			y = last + gap
		end
		setVisible(inst, fits)
		if tail then setVisible(tail, tailFits) end
	end
	local stackBottom = last or top
	if ui.Strip:GetAttribute("BottomY") ~= stackBottom then ui.Strip:SetAttribute("BottomY", stackBottom) end
end

-- end of every update() tick: read what the updates asked to show, then the (cached) geometry pass and the stack
function V2.tick()
	V2.Busy = false
	if not V2.rects() then
		if V2.Active then
			V2.leave()
			relayout()
		end
		return
	end
	V2.WantList = V2.WantList or { ui.Personal, ui.Siren, ui.Tug, ui.TugSub, ui.KaijuChip, ui.KingChip, ui.GooseChip }
	for _, inst in V2.WantList do
		V2.Want[inst] = inst.Visible
	end
	-- seconds until each countdown (the live Pumpkin King counts as 0) for the layout-B event line
	local now = Util.Now()
	local kingKey, kingActive, kingT = KING.pick(now) -- A23-45: the pumpkin king or the ghost king, whichever is sooner
	V2.KingIn = kingKey and (kingActive and 0 or math.max(0, kingT)) or 0
	V2.GooseIn = SQ.Out and 0 or math.max(0, num(gsAttr("GooseNextAt", 0)) - now) -- the open event's chip (Join) goes first
	V2.layout() -- cheap key check: HUD's numbers / the UIScale changed (or HUD v2 just appeared)
	V2.stack()
end

-- the column places the Pumpkin King pill in v2 (V2.stack); KING.place stays the legacy slot finder (left / right of
-- the strip, else under the chips)
V2.LegacyKingPlace = KING.place
function KING.place(chip)
	if V2.rects() then return end
	return V2.LegacyKingPlace(chip)
end

-- A23-68 #4 (user 2026-10-07 "한 번에 목표 하나"): until the first [Claim] (HUD.RookieFold) the next-event line, the
-- siren, the arrows and the status lines wait; the first [Claim] brings the event line in with a NEW! tag
function V2.Fold()
	local hud = C and C.HUD
	if type(hud) ~= "table" or type(hud.RookieFold) ~= "function" then return false end
	local ok, fold = pcall(hud.RookieFold)
	return ok and fold == true
end

-- 최종 검수 10/12 (main photos goose_square: a new player inside the Goose Square saw no Leave and no egg bar): am I
-- inside the Goose Square (EggFx.Inside)? Then the A23-68 fold never hides the strip - its Leave is the way out
function V2.InSquare()
	local e = C and C.EggFx
	if type(e) ~= "table" or type(e.Inside) ~= "function" then return false end
	local ok, inside = pcall(e.Inside)
	return ok and inside == true
end

-- 1안 ③: the NEW! tag sits INSIDE the shown event chip's right end (UIKit.NewTag reads NewTagInside / NewTagRight, du);
-- the chip widens for it first (V2.stack drops the tag when it cannot)
function V2.NewTag()
	local kit = C and C.UIKit
	if type(kit) ~= "table" or type(kit.NewTag) ~= "function" then return end
	local chip = V2.EventCur
	if not (chip and chip.Visible and chip.AbsoluteSize.X > 4) then return end
	local E = L.EventTop
	local s = currentScale()
	chip:SetAttribute("NewTagInside", (IS_TOUCH and E.NewWTouch or E.NewW) / s)
	chip:SetAttribute("NewTagRight", E.NewRight / s)
	-- the room only while the tag really shows (test Studio photo 10/14: a queued tag left an empty room on the chip)
	local ok, tag = pcall(kit.NewTag, chip)
	if not (ok and tag) then return end
	V2.NewOn, V2.NewUntil = chip, os.clock() + E.NewSeconds
	V2.stack() -- widens the chip for it, or drops the tag when it cannot
end

local function update()
	if not built then return end
	local folded = V2.Fold() and not V2.InSquare()
	if folded then V2.WasFolded = true end
	if pickersOpen() or folded then
		setVisible(ui.Arrows, false)
		setVisible(ui.Strip, false)
		setVisible(ui.Luck, false)
		setVisible(ui.Siren, false)
		setVisible(ui.Personal, false)
		activeTargets = {}
		return
	end
	if V2.WasFolded then
		V2.WasFolded = false
		task.delay(0.5, V2.NewTag) -- after this update showed the line
	end
	V2.Busy = true -- no v2 stack pass mid-update (a relayout would hide rows before V2.tick reads the wants)
	setVisible(ui.Arrows, true)
	setVisible(ui.Strip, true)
	-- U5: phones get the slim HUD (the menu shows EventHUD.LuckSummary); HUD v2 draws a luck chip instead everywhere
	setVisible(ui.Luck, not IS_TOUCH and V2.rects() == nil)
	local now = Util.Now()
	updateGoose(now)
	SQ.update()
	updateKaiju(now)
	KING.update(now) -- after the kaiju pill: the king pill sits after it while both show
	updatePersonal(now)
	updateLuck()
	gatherTargets(now)
	V2.tick() -- HUD v2: stack what the updates above asked to show (same resumption, so no one-frame flash)
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
	pcall(function() C.UIKit.L10n.Register("EventHUD.TXT", TXT) end) -- 10/14: the words' keys "EventHUD.TXT.<key>" (trx)
end

-- logical y (MainGui UIScale units) of the event strip's bottom, or nil before the first layout. HUD's status chips
-- go under it (also published as the EventStrip "BottomY" attribute). HUD v2: the bottom of the notify column's
-- shown rows (the column top while none shows); UIKit toasts start under it.
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

-- HUD v2 phone luck chip: the short form of LuckSummary's first line, "희귀 10.75%" (nil on error)
function EventHUD.LuckShort()
	local ok, bonus = pcall(function()
		local events = math.max(0, math.floor(num(myAttr("LuckEvents", 0))))
		return Config.RareChance(events) - ((Config.Luck and Config.Luck.BaseRare) or 0)
	end)
	if not ok or type(bonus) ~= "number" or bonus <= 1e-9 then return nil end -- no bonus today: no chip
	return safeFormat(TXT.LuckShort, Util.FormatPercent(bonus))
end

-- HUD calls this right after each layout pass (HUD v2: re-reads C.HUD.Layout.Rects.notify; legacy: the old layout)
EventHUD.Relayout = relayout

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
			V2.Busy = false -- also when update() stopped before V2.tick
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
