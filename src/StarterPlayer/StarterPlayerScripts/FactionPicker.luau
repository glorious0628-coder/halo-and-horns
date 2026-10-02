-- FactionPicker.luau : first-join faction choice with the crown-shard premise.
-- Visible exactly when DataLoaded == true and Faction == "None". Three cards: 빛의 기사단 / 뿔 군단 / 장인 길드
-- (SPEC_ADDENDUM A6). One tap on "이 편으로!" sends ChooseFaction; no confirm, no draw animation (A7-4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local FactionPicker = {}

local TAG = "FactionPicker"
local player = Players.LocalPlayer

local FACTION_IDS = { "Halo", "Horns", "Neutral" }
local CLICK_LOCK = 2 -- seconds the choose buttons stay disabled after a click
local PREMISE_STEP = 0.6 -- seconds between premise lines fading in
local PREMISE_FADE = 0.5
local POLL_INTERVAL = 0.5
local WARN_INTERVAL = 10
local ZINDEX = 60
local BODY_FONT = Enum.Font.GothamMedium

-- layout rules from Config.UI (addendum A3-H4 / M1)
local UI_CFG = type(Config.UI) == "table" and Config.UI or {}
local MIN_TEXT = type(UI_CFG.MinTextSize) == "number" and UI_CFG.MinTextSize or 11
local TOP_PAD = type(UI_CFG.TopInsetPad) == "number" and UI_CFG.TopInsetPad or 8
local TOP_FALLBACK = type(UI_CFG.TopInsetFallback) == "number" and UI_CFG.TopInsetFallback or 64

-- Neutral fallbacks (A6 / A9-1 teal), used only if Config lacks the entries
local NEUTRAL_FALLBACK = {
	Id = "Neutral", Name = "장인 길드", Short = "장인", Emblem = "⚙",
	Color = Color3.fromRGB(40, 200, 190), Perks = {}, Pitch = "",
}
local NEUTRAL_LORE = "조각을 줍지 않고, 다듬기로 한 자들."
local NEUTRAL_NOTE = "싸움 버프 없음 · PvP 없음 · 제작 특화(곧 추가)"

local T = {
	Title = "어느 편에 설래요?",
	Choose = "이 편으로!",
	Wait = "잠깐만요...",
	WeakerF = "약한 편 합류! 시작 골드 +%d · 덩치 저울로 더 커져요",
	Footer = "나중에 교차로 마을의 운명의 제단에서 바꿀 수 있어요 (무료 또는 변경권)",
}

local DEFAULT_THEME = {
	Bg = Color3.fromRGB(25, 25, 35),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(200, 200, 210),
	Gold = Color3.fromRGB(255, 210, 60),
	Font = Enum.Font.GothamBold,
}
local CARD_BG = Color3.fromRGB(34, 36, 52)
local DIM_BG = Color3.fromRGB(8, 8, 14)
local DARK_TEXT = Color3.fromRGB(30, 26, 18)
local DISABLED = Color3.fromRGB(70, 70, 80)

------------------------------------------------------------------ state
local C = nil
local UIKit = nil
local theme = table.clone(DEFAULT_THEME)

local fallbackGui = nil
local root, premiseFrame, titleLabel, cardsRow, footerLabel = nil, nil, nil, nil, nil
local premiseLabels = {}
local cards = {} -- [factionId] = { Button, Badge, Emblem, Name, Scroll, Color }
local built = false
local visible = false
local lockedUntil = 0
local premiseToken = 0
local cameraConn = nil
local scaleConn = nil
local lastWarnAt = -math.huge

------------------------------------------------------------------ helpers
local function warnThrottled(msg)
	local t = os.clock()
	if t - lastWarnAt < WARN_INTERVAL then return end
	lastWarnAt = t
	Util.Warn(TAG, msg)
end

local function factionDef(id)
	local f = Config.Factions[id]
	if type(f) == "table" then return f end
	if id == "Neutral" then return NEUTRAL_FALLBACK end
	return Config.Factions.None
end

local function factionColor(id)
	local f = factionDef(id)
	if typeof(f.Color) == "Color3" then return f.Color end
	if typeof(f.TeamColor) == "BrickColor" then return f.TeamColor.Color end
	return Color3.fromRGB(200, 200, 200)
end

local function factionLore(id)
	local lore = Config.Story.FactionLore and Config.Story.FactionLore[id]
	if type(lore) == "string" and lore ~= "" then return lore end
	if id == "Neutral" then return NEUTRAL_LORE end
	return ""
end

-- dark text on bright fills (Halo gold, Neutral teal A9-1), white on darker ones (Horns red)
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
	fallbackGui.Name = "FactionPickerGui"
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

-- wrapped, auto-height text inside a vertical list
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

------------------------------------------------------------------ buttons / badges
local function refreshButtons()
	local enabled = os.clock() >= lockedUntil
	for _, c in cards do
		local btn = c.Button
		btn.Text = enabled and T.Choose or T.Wait
		btn.AutoButtonColor = false
		btn:SetAttribute("Disabled", not enabled)
		btn.BackgroundColor3 = enabled and c.Color or c.Color:Lerp(DISABLED, 0.7)
		btn.TextTransparency = enabled and 0 or 0.4
	end
end

local function updateBadges()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local weaker = gs and gs:GetAttribute("WeakerFaction")
	for id, c in cards do
		-- the +300 sign-on bonus exists only between Halo and Horns (A6)
		c.Badge.Visible = (id == "Halo" or id == "Horns") and weaker == id
	end
end

local function choose(id)
	if os.clock() < lockedUntil then return end
	if not FactionPicker.IsOpen() then return end
	lockedUntil = os.clock() + CLICK_LOCK
	refreshButtons()
	fire("ChooseFaction", id)
	task.delay(CLICK_LOCK + 0.05, function()
		if built then refreshButtons() end
	end)
end

------------------------------------------------------------------ build / layout
local function buildCard(id, order)
	local def = factionDef(id)
	local color = factionColor(id)

	local card = Instance.new("Frame")
	card.Name = "Card_" .. id
	card.BackgroundColor3 = CARD_BG
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1 / #FACTION_IDS, -8, 1, 0)
	card.LayoutOrder = order
	corner(card, 14)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Thickness = 3
	st.Parent = card

	local emblem = newLabel(card, {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = tostring(def.Emblem or ""),
		TextScaled = true,
		TextColor3 = color,
		Font = theme.Font,
	}, 64)
	local name = newLabel(card, {
		Name = "FactionName",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = tostring(def.Name or id),
		TextScaled = true,
		TextColor3 = color,
		Font = theme.Font,
	}, 30)

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

	local badge = listText(scroll, string.format(T.WeakerF, math.floor(Config.Justice.SignOnGold)), 15, DARK_TEXT, 1, theme.Font)
	badge.Name = "WeakerBadge"
	badge.BackgroundColor3 = theme.Gold
	badge.BackgroundTransparency = 0
	corner(badge, 8)
	local badgePad = Instance.new("UIPadding")
	badgePad.PaddingTop = UDim.new(0, 4)
	badgePad.PaddingBottom = UDim.new(0, 4)
	badgePad.PaddingLeft = UDim.new(0, 6)
	badgePad.PaddingRight = UDim.new(0, 6)
	badgePad.Parent = badge
	badge.Visible = false

	local order2 = 2
	local lore = factionLore(id)
	if lore ~= "" then
		listText(scroll, lore, 16, theme.Text, order2)
		order2 += 1
	end
	if type(def.Pitch) == "string" and def.Pitch ~= "" then
		listText(scroll, def.Pitch, 18, color, order2, theme.Font)
		order2 += 1
	end
	if type(def.Perks) == "table" and #def.Perks > 0 then
		local lines = {}
		for _, p in def.Perks do
			table.insert(lines, "• " .. tostring(p))
		end
		local perks = listText(scroll, table.concat(lines, "\n"), 15, theme.SubText, order2)
		perks.TextXAlignment = Enum.TextXAlignment.Left
		order2 += 1
	end
	if id == "Neutral" then
		local note = (type(def.Note) == "string" and def.Note ~= "") and def.Note or NEUTRAL_NOTE
		listText(scroll, note, 15, theme.Gold, order2, theme.Font)
		order2 += 1
	end

	local btn = makeButton(card, T.Choose, color, contrastText(color), function()
		choose(id)
	end)
	btn.AnchorPoint = Vector2.new(0.5, 1)

	card.Parent = cardsRow
	cards[id] = { Button = btn, Badge = badge, Emblem = emblem, Name = name, Scroll = scroll, Color = color }
end

local function layoutCard(c, compact)
	local hh = compact and 62 or 96 -- header (emblem + name)
	local bh = compact and 44 or 54 -- choose button
	c.Emblem.Position = UDim2.new(0.5, 0, 0, 6)
	c.Emblem.Size = UDim2.new(1, -16, 0, math.floor(hh * 0.55))
	c.Name.Position = UDim2.new(0.5, 0, 0, 6 + math.floor(hh * 0.55))
	c.Name.Size = UDim2.new(1, -16, 0, math.floor(hh * 0.38))
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
	local lineH = compact and 20 or 26
	local contentW = math.min(w - 32, 1100)

	premiseFrame.Position = UDim2.fromOffset(w / 2, top)
	premiseFrame.Size = UDim2.fromOffset(contentW, lineH * #premiseLabels)
	for _, l in premiseLabels do
		l.Size = UDim2.new(1, 0, 0, lineH)
		l.TextSize = compact and 15 or 19
	end

	local titleY = top + lineH * #premiseLabels + 4
	local titleH = compact and 32 or 46
	titleLabel.Position = UDim2.fromOffset(w / 2, titleY)
	titleLabel.Size = UDim2.fromOffset(contentW, titleH)
	titleLabel.TextSize = compact and 24 or 34

	local footerH = compact and 22 or 28
	footerLabel.Position = UDim2.fromOffset(w / 2, h - 8)
	footerLabel.Size = UDim2.fromOffset(contentW, footerH)
	footerLabel.TextSize = compact and 14 or 17

	local cardsY = titleY + titleH + 6
	local cardsH = math.max(170, h - cardsY - footerH - 16)
	cardsRow.Position = UDim2.fromOffset(w / 2, cardsY)
	cardsRow.Size = UDim2.fromOffset(math.min(w - 24, 1100), math.min(cardsH, 540))
	for _, c in cards do
		layoutCard(c, compact)
	end
end

local function build()
	if built then return true end
	local gui = getGui()
	if not gui then return false end

	root = Instance.new("Frame")
	root.Name = "FactionPicker"
	root.BackgroundColor3 = DIM_BG
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Active = true
	root.ZIndex = ZINDEX
	root.Visible = false

	premiseFrame = Instance.new("Frame")
	premiseFrame.Name = "Premise"
	premiseFrame.AnchorPoint = Vector2.new(0.5, 0)
	premiseFrame.BackgroundTransparency = 1
	premiseFrame.BorderSizePixel = 0
	local plist = Instance.new("UIListLayout")
	plist.SortOrder = Enum.SortOrder.LayoutOrder
	plist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	plist.Parent = premiseFrame
	premiseFrame.Parent = root
	premiseLabels = {}
	local premise = Config.Story.Premise
	if type(premise) == "table" then
		for i, line in premise do
			local l = newLabel(premiseFrame, {
				Name = "PremiseLine" .. i,
				Text = tostring(line),
				TextSize = 19,
				TextColor3 = theme.SubText,
				TextTransparency = 1,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = i,
			}, 24)
			table.insert(premiseLabels, l)
		end
	end

	titleLabel = newLabel(root, {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = T.Title,
		TextSize = 34,
		TextColor3 = theme.Gold,
		Font = theme.Font,
	}, 40)

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
	for i, id in FACTION_IDS do
		buildCard(id, i)
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
	layout()
	return true
end

local function playPremise()
	premiseToken += 1
	local token = premiseToken
	for i, l in premiseLabels do
		l.TextTransparency = 1
		task.delay((i - 1) * PREMISE_STEP, function()
			if token ~= premiseToken or not l.Parent then return end
			TweenService:Create(l, TweenInfo.new(PREMISE_FADE), { TextTransparency = 0 }):Play()
		end)
	end
end

local function refresh()
	if not built and not build() then return end
	local open = FactionPicker.IsOpen()
	if open == visible then return end
	visible = open
	root.Visible = open
	if open then
		layout()
		updateBadges()
		refreshButtons()
		playPremise()
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
function FactionPicker.IsOpen()
	if player:GetAttribute("DataLoaded") ~= true then return false end
	local f = player:GetAttribute("Faction")
	return f == nil or f == "None"
end

function FactionPicker.Init(c)
	C = c
	UIKit = c and c.UIKit
	loadTheme()
	player.AttributeChanged:Connect(function(name)
		if name == "DataLoaded" or name == "Faction" then
			if built then
				local ok, err = pcall(refresh)
				if not ok then warnThrottled("refresh error: " .. tostring(err)) end
			end
		end
	end)
end

function FactionPicker.Start()
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

	task.spawn(function()
		local ok, err = pcall(function()
			local gs = Net.GameState()
			gs:GetAttributeChangedSignal("WeakerFaction"):Connect(function()
				if built then updateBadges() end
			end)
		end)
		if not ok then Util.Warn(TAG, "GameState hookup failed: " .. tostring(err)) end
		if built then updateBadges() end
	end)

	-- safety net: re-evaluate visibility periodically (attributes may arrive before any connection)
	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			local ok, err = pcall(refresh)
			if not ok then warnThrottled("refresh error: " .. tostring(err)) end
		end
	end)

	refresh()
	print("[FactionPicker] started")
end

return FactionPicker
