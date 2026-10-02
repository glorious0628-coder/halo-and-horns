-- ClassPicker.luau : first class choice (faction-specific names) + one-time intro toasts.
-- Visible exactly when DataLoaded == true, Faction ~= "None", ClassChosen == false and the FactionPicker is closed.
-- Cards follow SPEC_ADDENDUM A7-4: faction name + "(전사/마법사/궁수)" + one action line; Warrior shows "처음이면 추천".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local ClassPicker = {}

local TAG = "ClassPicker"
local player = Players.LocalPlayer

local CLICK_LOCK = 2 -- seconds the choose buttons stay disabled after a click
local INTRO_STEP = 3 -- seconds between intro toasts
local INTRO_DURATION = 4
local POLL_INTERVAL = 0.5
local WARN_INTERVAL = 10
local ZINDEX = 60
local BODY_FONT = Enum.Font.GothamMedium
local RECOMMENDED = "Warrior"
local NEUTRAL_COLOR = Color3.fromRGB(40, 200, 190) -- A9-1 teal; fallback only (Config.Factions.Neutral.Color wins)

-- layout rules from Config.UI (addendum A3-H4 / M1)
local UI_CFG = type(Config.UI) == "table" and Config.UI or {}
local MIN_TEXT = type(UI_CFG.MinTextSize) == "number" and UI_CFG.MinTextSize or 11
local TOP_PAD = type(UI_CFG.TopInsetPad) == "number" and UI_CFG.TopInsetPad or 8
local TOP_FALLBACK = type(UI_CFG.TopInsetFallback) == "number" and UI_CFG.TopInsetFallback or 64

-- fallbacks (A6 / A7-4), used only if Config lacks the entries
local NEUTRAL_CLASS_NAMES = { Warrior = "대장장이", Mage = "연금술사", Archer = "사냥꾼" }
local PICK_LINES = {
	Warrior = "가까이 붙어서 주변을 한 번에 쾅",
	Mage = "조금 떨어져서 넓게 펑",
	Archer = "멀리서 하나씩 슝",
}
local CLASS_ICONS = { Warrior = "🗡️", Mage = "🔮", Archer = "🏹" }

local T = {
	Title = "어떤 직업으로 싸울까요?",
	Choose = "이 직업으로!",
	Wait = "잠깐만요...",
	Recommend = "처음이면 추천",
	StartWeaponF = "시작 무기: %s",
	Footer = "나중에 메뉴 > 직업 변경에서 바꿀 수 있어요 (무료: 레벨 1부터 / 변경권: 레벨 유지)",
}

local DEFAULT_THEME = {
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(200, 200, 210),
	Gold = Color3.fromRGB(255, 210, 60),
	Font = Enum.Font.GothamBold,
}
local CARD_BG = Color3.fromRGB(34, 36, 52)
local DIM_BG = Color3.fromRGB(8, 8, 14)
local DARK_TEXT = Color3.fromRGB(30, 26, 18)
local DISABLED = Color3.fromRGB(70, 70, 80)
local BUTTON_COLOR = Color3.fromRGB(44, 150, 82)

------------------------------------------------------------------ state
local C = nil
local UIKit = nil
local theme = table.clone(DEFAULT_THEME)

local fallbackGui = nil
local root, titleLabel, cardsRow, footerLabel = nil, nil, nil, nil
local cards = {} -- [classId] = { Card, Stroke, Icon, Name, Generic, Scroll, Weapon, Button }
local built = false
local visible = false
local lockedUntil = 0
local shownFaction = nil
local prevClassChosen = nil
local introPlayed = false
local lastWarnAt = -math.huge
local cameraConn = nil
local scaleConn = nil

------------------------------------------------------------------ helpers
-- Config.Text[key] when G1 provides it (addendum A7-4 keys), else the private fallback format
local function cfgFmt(key, fallback, ...)
	local s = Config.Text[key]
	if type(s) ~= "string" then s = fallback end
	local ok, out = pcall(string.format, s, ...)
	if ok then return out end
	local ok2, out2 = pcall(string.format, fallback, ...)
	return ok2 and out2 or fallback
end

local function warnThrottled(msg)
	local t = os.clock()
	if t - lastWarnAt < WARN_INTERVAL then return end
	lastWarnAt = t
	Util.Warn(TAG, msg)
end

local function myFaction()
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function factionColor(id)
	local f = Config.Factions[id]
	if type(f) == "table" then
		if typeof(f.Color) == "Color3" then return f.Color end
		if typeof(f.TeamColor) == "BrickColor" then return f.TeamColor.Color end
	end
	if id == "Neutral" then return NEUTRAL_COLOR end
	return Color3.fromRGB(200, 200, 200)
end

local function className(classId, factionId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	if factionId == "Neutral" and (type(c.Names) ~= "table" or c.Names.Neutral == nil) then
		return NEUTRAL_CLASS_NAMES[classId] or Config.ClassName(classId, "None")
	end
	return Config.ClassName(classId, factionId)
end

local function genericClassName(classId)
	local c = Config.Classes[classId] or Config.Classes.Warrior
	return (type(c.Names) == "table" and c.Names.None) or classId
end

local function pickLine(classId)
	local c = Config.Classes[classId]
	if c and type(c.PickLine) == "string" and c.PickLine ~= "" then return c.PickLine end
	return PICK_LINES[classId] or ""
end

local function contrastText(c)
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return lum > 0.55 and DARK_TEXT or Color3.new(1, 1, 1)
end

local function loadTheme()
	local src = UIKit and UIKit.Theme
	if type(src) ~= "table" then return end
	for k, def in DEFAULT_THEME do
		local v = src[k]
		if v ~= nil and typeof(v) == typeof(def) then theme[k] = v end
	end
end

local function getGui()
	if UIKit and typeof(UIKit.Gui) == "Instance" then return UIKit.Gui end
	if fallbackGui and fallbackGui.Parent then return fallbackGui end
	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
	if not pg then return nil end
	fallbackGui = Instance.new("ScreenGui")
	fallbackGui.Name = "ClassPickerGui"
	fallbackGui.ResetOnSpawn = false
	fallbackGui.IgnoreGuiInset = true
	fallbackGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fallbackGui.DisplayOrder = 12
	fallbackGui.Parent = pg
	Util.Warn(TAG, "UIKit.Gui missing; using a fallback ScreenGui")
	return fallbackGui
end

-- virtual canvas (w, h) inside the UIScale'd gui and the first safe Y below the top bar (H4)
local function canvas(gui)
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 2 or vp.Y < 2 then vp = Vector2.new(1280, 720) end
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	local s = sc and sc.Scale or 1
	if type(s) ~= "number" or s < 0.05 then s = 1 end
	local insetY = 0
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and typeof(topLeft) == "Vector2" then insetY = topLeft.Y end
	local top = ((insetY > 0) and (insetY + TOP_PAD) or TOP_FALLBACK) / s
	return vp.X / s, vp.Y / s, top
end

local function constrainText(obj, maxSize)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = MIN_TEXT
	c.MaxTextSize = math.max(MIN_TEXT, maxSize or 64)
	c.Parent = obj
end

local function corner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = obj
end

local function newLabel(parent, props, maxText)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = BODY_FONT
	l.TextColor3 = theme.Text
	l.TextWrapped = true
	for k, v in props do
		l[k] = v
	end
	constrainText(l, maxText)
	l.Parent = parent
	return l
end

local function listText(parent, text, size, color, order, font)
	return newLabel(parent, {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextSize = size,
		TextColor3 = color or theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = font or BODY_FONT,
		LayoutOrder = order,
	})
end

local function makeButton(parent, text, color, textColor, onClick)
	local btn = nil
	local function handler()
		if not btn then return end
		local ok, err = pcall(onClick)
		if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
	end
	if UIKit and type(UIKit.Button) == "function" then
		local ok, b = pcall(UIKit.Button, {
			Name = "ChooseButton", Text = text, Size = UDim2.new(1, -24, 0, 50), Color = color,
			TextColor = textColor, TextSize = 22, Parent = parent,
		}, handler)
		if ok and typeof(b) == "Instance" and b:IsA("GuiButton") then btn = b end
	end
	if not btn then
		local b = Instance.new("TextButton")
		b.Font = theme.Font
		b.TextSize = 22
		b.BorderSizePixel = 0
		b.BackgroundColor3 = color
		b.TextColor3 = textColor
		corner(b, 12)
		b.Activated:Connect(function()
			local fx = C and C.Fx
			if fx and type(fx.PlaySound) == "function" then pcall(fx.PlaySound, "Click") end
			handler()
		end)
		btn = b
	end
	btn.Name = "ChooseButton"
	btn.Text = text
	btn.TextWrapped = true
	if not btn:FindFirstChildOfClass("UITextSizeConstraint") then constrainText(btn, 28) end
	btn.Parent = parent
	return btn
end

local function fire(remoteName, ...)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get(remoteName):FireServer(table.unpack(args, 1, args.n))
		end)
		if not ok then Util.Warn(TAG, "could not send " .. remoteName .. ": " .. tostring(err)) end
	end)
end

local function toast(text, kind, duration)
	if UIKit and type(UIKit.Toast) == "function" then
		local ok, err = pcall(UIKit.Toast, text, kind, duration)
		if not ok then warnThrottled("toast failed: " .. tostring(err)) end
	end
end

------------------------------------------------------------------ intro toasts
local function playIntro()
	local lines = Config.Story.Intro
	if type(lines) ~= "table" then return end
	task.spawn(function()
		for i, line in lines do
			if i > 1 then task.wait(INTRO_STEP) end
			if not player.Parent then return end
			toast(tostring(line), "info", INTRO_DURATION)
		end
	end)
end

-- ClassChosen flipping false -> true during this session, still at Lv 1 -> intro (once)
local function onClassChosenChanged()
	local now = player:GetAttribute("ClassChosen")
	if prevClassChosen == false and now == true and not introPlayed then
		local level = player:GetAttribute("Level")
		if (type(level) == "number" and level or 1) <= 1 then
			introPlayed = true
			playIntro()
		end
	end
	prevClassChosen = now
end

------------------------------------------------------------------ buttons / texts
local function refreshButtons()
	local enabled = os.clock() >= lockedUntil
	for _, c in cards do
		local btn = c.Button
		btn.Text = enabled and T.Choose or T.Wait
		btn.AutoButtonColor = false
		btn:SetAttribute("Disabled", not enabled)
		btn.BackgroundColor3 = enabled and BUTTON_COLOR or BUTTON_COLOR:Lerp(DISABLED, 0.7)
		btn.TextTransparency = enabled and 0 or 0.4
	end
end

-- faction-dependent texts (names, weapon, accent)
local function fillTexts()
	local faction = myFaction()
	shownFaction = faction
	local accent = factionColor(faction)
	for id, c in cards do
		c.Name.Text = className(id, faction)
		c.Weapon.Text = string.format(T.StartWeaponF, Config.WeaponName(1, id, faction))
		c.Stroke.Color = accent
	end
end

local function choose(id)
	if os.clock() < lockedUntil then return end
	if not ClassPicker.IsOpen() then return end
	lockedUntil = os.clock() + CLICK_LOCK
	refreshButtons()
	fire("ChooseClass", id)
	task.delay(CLICK_LOCK + 0.05, function()
		if built then refreshButtons() end
	end)
end

------------------------------------------------------------------ build / layout
local function buildCard(id, order, count)
	local def = Config.Classes[id]
	local card = Instance.new("Frame")
	card.Name = "Card_" .. id
	card.BackgroundColor3 = CARD_BG
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1 / count, -8, 1, 0)
	card.LayoutOrder = order
	corner(card, 14)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = theme.Gold
	st.Thickness = (id == RECOMMENDED) and 4 or 2
	st.Parent = card

	local icon = newLabel(card, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = CLASS_ICONS[id] or "",
		TextScaled = true,
		Font = theme.Font,
	}, 56)
	local name = newLabel(card, {
		Name = "ClassName",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
		TextScaled = true,
		TextColor3 = theme.Gold,
		Font = theme.Font,
	}, 30)
	local generic = newLabel(card, {
		Name = "Generic",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "(" .. genericClassName(id) .. ")",
		TextScaled = true,
		TextColor3 = theme.SubText,
	}, 18)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Details"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = theme.SubText
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = scroll
	scroll.Parent = card

	if id == RECOMMENDED then
		local badge = listText(scroll, cfgFmt("FirstTimeRecommend", T.Recommend), 15, DARK_TEXT, 1, theme.Font)
		badge.Name = "RecommendBadge"
		badge.BackgroundColor3 = theme.Gold
		badge.BackgroundTransparency = 0
		corner(badge, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = badge
	end
	listText(scroll, pickLine(id), 19, theme.Gold, 2, theme.Font)
	listText(scroll, def.Desc or "", 15, theme.Text, 3)
	if type(def.Stats) == "table" then
		local lines = {}
		for _, s in def.Stats do
			table.insert(lines, "• " .. tostring(s))
		end
		listText(scroll, table.concat(lines, "\n"), 14, theme.SubText, 4)
	end
	local weapon = listText(scroll, "", 14, theme.SubText, 5)

	local btn = makeButton(card, T.Choose, BUTTON_COLOR, contrastText(BUTTON_COLOR), function()
		choose(id)
	end)
	btn.AnchorPoint = Vector2.new(0.5, 1)

	card.Parent = cardsRow
	cards[id] = {
		Card = card, Stroke = st, Icon = icon, Name = name, Generic = generic,
		Scroll = scroll, Weapon = weapon, Button = btn,
	}
end

local function layoutCard(c, compact)
	local hh = compact and 70 or 104 -- header: icon + name + generic
	local bh = compact and 44 or 54
	local iconH = math.floor(hh * 0.42)
	local nameH = math.floor(hh * 0.33)
	local genH = math.floor(hh * 0.2)
	c.Icon.Position = UDim2.new(0.5, 0, 0, 6)
	c.Icon.Size = UDim2.new(1, -16, 0, iconH)
	c.Name.Position = UDim2.new(0.5, 0, 0, 6 + iconH)
	c.Name.Size = UDim2.new(1, -16, 0, nameH)
	c.Generic.Position = UDim2.new(0.5, 0, 0, 6 + iconH + nameH)
	c.Generic.Size = UDim2.new(1, -16, 0, genH)
	c.Scroll.Position = UDim2.new(0, 10, 0, hh + 10)
	c.Scroll.Size = UDim2.new(1, -20, 1, -(hh + 10 + bh + 20))
	c.Button.Position = UDim2.new(0.5, 0, 1, -10)
	c.Button.Size = UDim2.new(1, -24, 0, bh)
end

local function layout()
	if not root then return end
	local w, h, top = canvas(root.Parent)
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(w, h)
	local compact = h < 600
	local contentW = math.min(w - 32, 1100)

	local titleH = compact and 36 or 50
	titleLabel.Position = UDim2.fromOffset(w / 2, top)
	titleLabel.Size = UDim2.fromOffset(contentW, titleH)
	titleLabel.TextSize = compact and 26 or 36

	local footerH = compact and 22 or 28
	footerLabel.Position = UDim2.fromOffset(w / 2, h - 8)
	footerLabel.Size = UDim2.fromOffset(contentW, footerH)
	footerLabel.TextSize = compact and 14 or 17

	local cardsY = top + titleH + 8
	local cardsH = math.max(180, h - cardsY - footerH - 16)
	cardsRow.Position = UDim2.fromOffset(w / 2, cardsY)
	cardsRow.Size = UDim2.fromOffset(math.min(w - 24, 1100), math.min(cardsH, 560))
	for _, c in cards do
		layoutCard(c, compact)
	end
end

local function build()
	if built then return true end
	local gui = getGui()
	if not gui then return false end

	root = Instance.new("Frame")
	root.Name = "ClassPicker"
	root.BackgroundColor3 = DIM_BG
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Active = true
	root.ZIndex = ZINDEX
	root.Visible = false

	titleLabel = newLabel(root, {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = T.Title,
		TextSize = 36,
		TextColor3 = theme.Gold,
		Font = theme.Font,
	}, 42)

	cardsRow = Instance.new("Frame")
	cardsRow.Name = "Cards"
	cardsRow.AnchorPoint = Vector2.new(0.5, 0)
	cardsRow.BackgroundTransparency = 1
	cardsRow.BorderSizePixel = 0
	local clist = Instance.new("UIListLayout")
	clist.FillDirection = Enum.FillDirection.Horizontal
	clist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	clist.SortOrder = Enum.SortOrder.LayoutOrder
	clist.Padding = UDim.new(0, 12)
	clist.Parent = cardsRow
	cardsRow.Parent = root

	local ids = {}
	for _, id in Config.ClassOrder do
		if Config.Classes[id] then table.insert(ids, id) end
	end
	for i, id in ids do
		buildCard(id, i, #ids)
	end

	footerLabel = newLabel(root, {
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Text = T.Footer,
		TextSize = 17,
		TextColor3 = theme.SubText,
	}, 20)

	root.Parent = gui
	built = true
	fillTexts()
	layout()
	return true
end

local function refresh()
	if not built and not build() then return end
	local open = ClassPicker.IsOpen()
	if open and shownFaction ~= myFaction() then fillTexts() end
	if open == visible then return end
	visible = open
	root.Visible = open
	if open then
		fillTexts()
		layout()
		refreshButtons()
		local panels = C and C.Panels
		if panels and type(panels.Close) == "function" then pcall(panels.Close) end
	end
end

local function hookCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cameraConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if built then layout() end
		end)
	end
end

------------------------------------------------------------------ public
function ClassPicker.IsOpen()
	if player:GetAttribute("DataLoaded") ~= true then return false end
	local f = player:GetAttribute("Faction")
	if type(f) ~= "string" or f == "None" then return false end
	if player:GetAttribute("ClassChosen") ~= false then return false end
	local fp = C and C.FactionPicker
	if type(fp) == "table" and type(fp.IsOpen) == "function" then
		local ok, open = pcall(fp.IsOpen)
		if ok and open then return false end
	end
	return true
end

function ClassPicker.Init(c)
	C = c
	UIKit = c and c.UIKit
	loadTheme()
	prevClassChosen = player:GetAttribute("ClassChosen")
	player.AttributeChanged:Connect(function(name)
		if name == "ClassChosen" then
			local ok, err = pcall(onClassChosenChanged)
			if not ok then warnThrottled("intro error: " .. tostring(err)) end
		end
		if name == "DataLoaded" or name == "Faction" or name == "ClassChosen" then
			if built then
				local ok, err = pcall(refresh)
				if not ok then warnThrottled("refresh error: " .. tostring(err)) end
			end
		end
	end)
end

function ClassPicker.Start()
	loadTheme()
	build()
	hookCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
	local gui = root and root.Parent
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	if sc then
		scaleConn = sc:GetPropertyChangedSignal("Scale"):Connect(function()
			if built then layout() end
		end)
	end

	-- safety net: re-evaluate visibility periodically (also follows the FactionPicker closing)
	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			local ok, err = pcall(refresh)
			if not ok then warnThrottled("refresh error: " .. tostring(err)) end
		end
	end)

	refresh()
	print("[ClassPicker] started")
end

return ClassPicker
