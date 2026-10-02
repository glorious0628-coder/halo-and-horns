-- EventHUD.luau : event UI for Halo & Horns (G11).
-- Golden goose countdown chip / tug-of-war bar, kaiju chip + siren banner, screen-edge arrows (grudge sacks, kaiju,
-- revenge), the personal status line (sack / kaiju / revenge) and the Regular's Luck corner.
-- Reads only player attributes and GameState attributes; sends nothing to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LocalPlayer = Players.LocalPlayer

local EventHUD = {}

local C = nil -- client registry (set in Init)

----------------------------------------------------------------- layout (reference 1280x720 at UIScale 1)
local STRIP_Y = 72 -- event strip slot (spec: y 72-110 when the top HUD block starts at y 8)
local STRIP_W = 420
local BAR_H = 30
local SUB_H = 14
local GOOSE_CHIP_W = 240
local KAIJU_CHIP_W = 170
local LUCK_Y = 52
local LUCK_W, LUCK_H = 250, 52
local LUCK_RIGHT = 12
local UI_CFG = Config.UI or {}
local TOP_PAD = UI_CFG.TopInsetPad or 8 -- addendum H4: top blocks start at inset + 8...
local TOP_FALLBACK = UI_CFG.TopInsetFallback or 64 -- ...or at 64 px when the inset is unknown
local MIN_TEXT_SIZE = UI_CFG.MinTextSize or 11 -- addendum M1
local PERSONAL_W, PERSONAL_H = 560, 34
local SIREN_H = 64

local MAX_ARROWS = 10
local EDGE_MARGIN = 40 -- px from the screen edge (absolute pixels)
local LABEL_INSET = 40 -- px from an edge arrow toward the screen center
local ARROW_GLYPH_SIZE = 34
local ARROW_LABEL_W, ARROW_LABEL_H = 150, 20
local EDGE_GLYPH = "►" -- points to +X at Rotation 0
local MARKER_GLYPH = "▼"

local TICK = 0.2
local LAYOUT_EVERY = 2

----------------------------------------------------------------- colors / text
local WHITE = Color3.new(1, 1, 1)
local DEFAULT_BG = Color3.fromRGB(25, 25, 35)
local DEFAULT_BG_T = 0.25
local GOLD = Color3.fromRGB(255, 210, 60)
local HORNS_RED = Color3.fromRGB(220, 50, 60)
local KAIJU_RED = Color3.fromRGB(200, 30, 35)
local SIREN_RED = Color3.fromRGB(190, 20, 25)
local SACK_PURPLE = Color3.fromRGB(185, 105, 255) -- brighter than Config.Visuals.GrudgeSackColor for readability
local REVENGE_ORANGE = Color3.fromRGB(255, 150, 40)
local KAIJU_ARROW = Color3.fromRGB(255, 45, 45)
local SUBTEXT = Color3.fromRGB(200, 200, 210)

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
	ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ownGui.DisplayOrder = 10
	ownGui.Parent = pg
	return ownGui
end

local function insetY()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local y = (ok and typeof(topLeft) == "Vector2") and topLeft.Y or 0
	if y <= 0 then y = TOP_FALLBACK - TOP_PAD end
	return y
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

----------------------------------------------------------------- build
local function readTheme()
	local kit = C and C.UIKit
	local theme = kit and kit.Theme
	if type(theme) ~= "table" then return end
	if typeof(theme.Font) == "EnumItem" then fontFace = theme.Font end
	if typeof(theme.Bg) == "Color3" then bgColor = theme.Bg end
	if type(theme.BgTransparency) == "number" then bgTransparency = theme.BgTransparency end
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

	-- event strip (top-center)
	ui.Strip = make("Frame", {
		Name = "EventStrip",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, STRIP_Y),
		Size = UDim2.fromOffset(STRIP_W, BAR_H + SUB_H),
		ZIndex = 3,
	}, root)

	ui.GooseChip = makePanel({
		Name = "GooseChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(GOOSE_CHIP_W, BAR_H),
		Visible = false,
		ZIndex = 3,
	}, ui.Strip)
	make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.3 }, ui.GooseChip)
	ui.GooseChipText = makeLabel({
		Name = "Text",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 1, -8),
		TextColor3 = GOLD,
		ZIndex = 4,
	}, 18, ui.GooseChip)

	ui.Tug = makePanel({
		Name = "GooseTug",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(STRIP_W, BAR_H),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 3,
	}, ui.Strip)
	make("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.4 }, ui.Tug)
	ui.TugLeft = make("Frame", {
		Name = "RescueFill",
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 3,
	}, ui.Tug)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, ui.TugLeft)
	ui.TugRight = make("Frame", {
		Name = "PoachFill",
		BackgroundColor3 = HORNS_RED,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 3,
	}, ui.Tug)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, ui.TugRight)
	ui.TugLeftText = makeLabel({
		Name = "RescueText",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(0, 96, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.2,
		ZIndex = 5,
	}, 16, ui.Tug)
	ui.TugRightText = makeLabel({
		Name = "PoachText",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 4),
		Size = UDim2.new(0, 96, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.2,
		ZIndex = 5,
	}, 16, ui.Tug)
	ui.TugCenterText = makeLabel({
		Name = "TitleText",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0, 200, 1, -8),
		TextStrokeTransparency = 0.1,
		ZIndex = 5,
	}, 16, ui.Tug)
	ui.TugSub = makeLabel({
		Name = "GooseSub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BAR_H),
		Size = UDim2.fromOffset(STRIP_W, SUB_H),
		TextColor3 = SUBTEXT,
		TextStrokeTransparency = 0.3,
		Visible = false,
		ZIndex = 3,
	}, 13, ui.Strip)

	ui.KaijuChip = makePanel({
		Name = "KaijuChip",
		BackgroundColor3 = KAIJU_RED,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(1, 8, 0, 0),
		Size = UDim2.fromOffset(KAIJU_CHIP_W, BAR_H),
		Visible = false,
		ZIndex = 3,
	}, ui.Strip)
	make("UIStroke", { Color = Color3.fromRGB(255, 120, 120), Thickness = 1.5, Transparency = 0.2 }, ui.KaijuChip)
	ui.KaijuChipText = makeLabel({
		Name = "Text",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		TextStrokeTransparency = 0.2,
		ZIndex = 4,
	}, 16, ui.KaijuChip)

	-- kaiju siren banner (full width at 18% screen height)
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
	ui.SirenText = makeLabel({
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -12),
		TextStrokeTransparency = 0.2,
		ZIndex = 7,
	}, 28, ui.Siren)

	-- personal line (bottom-center at 72% height)
	ui.Personal = makePanel({
		Name = "PersonalLine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(PERSONAL_W, PERSONAL_H),
		BackgroundTransparency = math.min(0.9, bgTransparency + 0.1),
		Visible = false,
		ZIndex = 3,
	}, root)
	ui.PersonalText = makeLabel({
		Name = "Text",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 1, -8),
		TextStrokeTransparency = 0.3,
		ZIndex = 4,
	}, 20, ui.Personal)

	-- Regular's Luck corner (top-right)
	ui.Luck = makePanel({
		Name = "LuckCorner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -LUCK_RIGHT, 0, LUCK_Y),
		Size = UDim2.fromOffset(LUCK_W, LUCK_H),
		ZIndex = 3,
	}, root)
	ui.LuckLine1 = makeLabel({
		Name = "Luck",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 4,
	}, 17, ui.Luck)
	ui.LuckLine2 = makeLabel({
		Name = "Cheer",
		Position = UDim2.fromOffset(10, 27),
		Size = UDim2.new(1, -20, 0, 21),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
		ZIndex = 4,
	}, 16, ui.Luck)

	built = true
end

-- H4: shift the spec's top slots below the Roblox top bar. Same convention as UIKit's toast stack:
-- logical offset = slot Y + realInset / UIScale (so the real-pixel top is always >= inset + TopInsetPad).
local function layout()
	if not built then return end
	if not guiScale or guiScale.Parent == nil then
		local root = ui.Strip and ui.Strip.Parent
		guiScale = root and root:FindFirstChildOfClass("UIScale") or nil
	end
	local inset = insetY()
	local s = currentScale()
	local stripY = math.floor(STRIP_Y + inset / s + 0.5)
	local luckY = math.floor(math.max(LUCK_Y, (inset + TOP_PAD) / s) + 0.5)
	local key = stripY .. ":" .. luckY
	if key == lastLayoutKey then return end
	lastLayoutKey = key
	ui.Strip.Position = UDim2.new(0.5, 0, 0, stripY)
	ui.Luck.Position = UDim2.new(1, -LUCK_RIGHT, 0, luckY)
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
		ui.TugLeft.Size = UDim2.fromScale(frac, 1)
		ui.TugRight.Size = UDim2.fromScale(1 - frac, 1)
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

local function kaijuName()
	local name = gsAttr("KaijuName", "")
	if type(name) ~= "string" or name == "" then return TXT.UnknownName end
	return name
end

local function updateKaiju(now)
	local phase = gsAttr("KaijuPhase", "None")
	local endsAt = num(gsAttr("KaijuEndsAt", 0))
	if phase == "Active" then
		setVisible(ui.KaijuChip, true)
		setText(ui.KaijuChipText, string.format(TXT.KaijuChip, kaijuName(), Util.FormatTime(endsAt - now)))
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
	local sack = num(myAttr("SackGold", 0))
	if sack > 0 then
		local secs = math.max(0, math.ceil(num(myAttr("SackSeconds", 0))))
		text = string.format(TXT.Sack, Util.FormatNumber(sack), secs)
		color = SACK_PURPLE
	elseif myAttr("KaijuState", "None") == "Active" then
		local endsAt = 0
		if num(gsAttr("KaijuUserId", 0)) == LocalPlayer.UserId then endsAt = num(gsAttr("KaijuEndsAt", 0)) end
		text = string.format(TXT.KaijuSelf, Util.FormatTime(endsAt - now))
		color = KAIJU_ARROW
	else
		local target, untilT = revengeTarget(now)
		if target then
			text = string.format(TXT.Revenge, target.DisplayName, Util.FormatTime(untilT - now))
			color = REVENGE_ORANGE
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

local function updateLuck()
	local minutes = math.max(0, math.floor(num(myAttr("RegularMinutes", 0))))
	setText(ui.LuckLine1, string.format(TXT.Luck, minutes, Util.FormatPercent(Config.RareChance(minutes))))
	local need = math.floor(num(Config.Goose and Config.Goose.CheerStarsForRare))
	if need <= 0 then need = 5 end
	local stars = math.max(0, math.floor(num(myAttr("CheerStars", 0))))
	local filled = math.min(stars, need)
	setText(ui.LuckLine2, string.format(TXT.Cheer, string.rep("★", filled) .. string.rep("☆", need - filled), stars, need))
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
	setVisible(ui.Luck, true)
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

local function clampLabel(x, y, vp)
	local s = currentScale()
	local halfW = ARROW_LABEL_W * s / 2 + 4
	local halfH = ARROW_LABEL_H * s / 2 + 4
	x = math.clamp(x, math.min(halfW, vp.X / 2), math.max(vp.X - halfW, vp.X / 2))
	y = math.clamp(y, math.min(halfH, vp.Y / 2), math.max(vp.Y - halfH, vp.Y / 2))
	return x, y
end

local function placeArrow(a, target, root, cam, vp)
	local scale = num(target.Player:GetAttribute("VisualScale"))
	if scale <= 0 then scale = 1 end
	local world = root.Position + Vector3.new(0, 4.2 * scale, 0)
	local sp, onScreen = cam:WorldToViewportPoint(world)
	a.Glyph.TextColor3 = target.Color
	a.Label.TextColor3 = target.Color
	if a.Label.Text ~= target.Label then a.Label.Text = target.Label end

	if onScreen and sp.Z > 0 then
		-- small marker above the target
		if a.Glyph.Text ~= MARKER_GLYPH then a.Glyph.Text = MARKER_GLYPH end
		a.Glyph.Rotation = 0
		a.Glyph.Position = UDim2.fromScale(sp.X / vp.X, sp.Y / vp.Y)
		a.Label.Position = UDim2.new(sp.X / vp.X, 0, sp.Y / vp.Y, -26)
	else
		-- clamp to the screen edge, rotated toward the target
		local center = vp / 2
		local dir
		if sp.Z > 0 then
			dir = Vector2.new(sp.X, sp.Y) - center
		else
			local rel = cam.CFrame:PointToObjectSpace(world)
			dir = Vector2.new(rel.X, -rel.Y)
		end
		if dir.Magnitude < 1e-3 then dir = Vector2.new(0, 1) end
		local halfW = math.max(1, center.X - EDGE_MARGIN)
		local halfH = math.max(1, center.Y - EDGE_MARGIN)
		local sx = math.abs(dir.X) > 1e-6 and halfW / math.abs(dir.X) or math.huge
		local sy = math.abs(dir.Y) > 1e-6 and halfH / math.abs(dir.Y) or math.huge
		local edge = center + dir * math.min(sx, sy)
		local inward = -dir.Unit * LABEL_INSET
		local lx, ly = clampLabel(edge.X + inward.X, edge.Y + inward.Y, vp)
		if a.Glyph.Text ~= EDGE_GLYPH then a.Glyph.Text = EDGE_GLYPH end
		a.Glyph.Rotation = math.deg(math.atan2(dir.Y, dir.X))
		a.Glyph.Position = UDim2.fromScale(edge.X / vp.X, edge.Y / vp.Y)
		a.Label.Position = UDim2.fromScale(lx / vp.X, ly / vp.Y)
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
			for _, t in activeTargets do
				if used >= MAX_ARROWS then break end
				local root = getRoot(t.Player)
				if root then
					used += 1
					placeArrow(arrows[used], t, root, cam, vp)
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
