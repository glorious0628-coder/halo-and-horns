-- Panels.luau : modal panels — Menu, Travel, Rebirth (turncoat), Altar, Class, Shop (tickets), Vacation.
-- Client only. Reads player / GameState attributes, sends intents through RemoteEvents (the server re-validates
-- everything) and prompts Developer Product purchases. One panel at a time; irreversible choices go through
-- UIKit.Confirm. Factions handled: "Halo", "Horns", "Neutral" (playable) and "None" (not chosen yet).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local Panels = {}

local TAG = "Panels"
local player = Players.LocalPlayer

local FACTION_IDS = { "Halo", "Horns", "Neutral" }
local TICKET_ATTR = { Class = "ClassTickets", Faction = "FactionTickets" }
-- attribute changes that change a panel's STRUCTURE (rebuild); everything else is polled by the update loop
local REBUILD_ATTRS = { DataLoaded = true, Faction = true, Class = true, ClassChosen = true, VacationDays = true }
local UPDATE_INTERVAL = 0.25
local VACATION_DELAY = 2 -- seconds after both pickers are closed
local WINDOW_MAX_W, WINDOW_MAX_H = 780, 600
local ZINDEX = 50
local BODY_FONT = Enum.Font.GothamMedium
local WARN_INTERVAL = 10

-- layout rules from Config.UI (addendum A3-H4 / M1)
local UI_CFG = type(Config.UI) == "table" and Config.UI or {}
local MIN_TEXT = type(UI_CFG.MinTextSize) == "number" and UI_CFG.MinTextSize or 11
local TOP_PAD = type(UI_CFG.TopInsetPad) == "number" and UI_CFG.TopInsetPad or 8
local TOP_FALLBACK = type(UI_CFG.TopInsetFallback) == "number" and UI_CFG.TopInsetFallback or 64

-- Neutral faction fallbacks (SPEC_ADDENDUM A6 / A7-4 / A9-1 teal), used only if Config lacks the entries
local NEUTRAL_FALLBACK = {
	Id = "Neutral", Name = "장인 길드", Short = "장인", Emblem = "장", -- no ⚙ glyph in Gotham
	Color = Color3.fromRGB(40, 200, 190), Perks = {}, Pitch = "",
}
local NEUTRAL_LORE = "조각을 줍지 않고, 다듬기로 한 자들."
local NEUTRAL_NOTE = "싸움 버프 없음 · PvP 없음 · 제작 특화(곧 추가)"
local NEUTRAL_CLASS_NAMES = { Warrior = "대장장이", Mage = "연금술사", Archer = "사냥꾼" }
local PICK_LINES = {
	Warrior = "가까이 붙어서 주변을 한 번에 쾅",
	Mage = "조금 떨어져서 넓게 펑",
	Archer = "멀리서 하나씩 슝",
}

-- player-facing strings used only by these panels (Korean). Keys ending in F go through string.format.
local T = {
	Titles = {
		Menu = "메뉴", Travel = "이동", Rebirth = "전향 환생", Altar = "운명의 제단",
		Class = "직업 변경", Shop = "변경권 상점", Vacation = "휴가 보너스",
	},
	Back = "← 메뉴",
	Close = "X",
	-- menu
	MenuTravel = "이동",
	MenuRebirth = "환생",
	MenuRebirthReady = "환생 (가능!)",
	MenuClass = "직업 변경",
	MenuShop = "변경권 상점",
	MenuVacation = "휴가 보너스",
	MenuAltarHint = "진영 변경은 교차로 마을의 운명의 제단에서!",
	-- travel
	TravelGo = "이동",
	TravelNoGo = "못 가요",
	TravelBusy = "이동 중",
	TravelNeedLevelF = "Lv %d 필요",
	TravelInfoF = "Lv %d+ · %s",
	TravelHere = " · 지금 여기",
	TravelRecommendF = "  <font color=\"#FFD23C\">★ %s</font>",
	Recommended = "추천",
	Safe = "안전",
	PvP = "PvP",
	-- rebirth
	RebirthInfoF = "환생 %d회 · 필요 레벨 Lv %d (지금 Lv %d)",
	RebirthCountsF = "지금 서버: 빛 %d명 : 뿔 %d명",
	RebirthBonusF = "+%d%%",
	RebirthBonusUnderdogF = "+%d%%! (인원이 적은 편)",
	RebirthCurrent = "(지금 진영)",
	RebirthResets = "초기화: 레벨, 골드, 무기",
	RebirthKeeps = "유지: 직업, 명예·악명, 환생 보너스, 표식, 변경권",
	RebirthConfirmTitle = "전향 환생",
	RebirthConfirmBodyF = "%s(으)로 다시 태어날까요?\n초기화: 레벨, 골드, 무기\n유지: 직업, 명예·악명, 환생 보너스, 표식, 변경권",
	RebirthConfirmOk = "환생!",
	-- altar
	AltarCurrentF = "지금 진영: %s → 어느 편으로 갈까요?",
	AltarRules = "조건: 현상수배 별 0개 · 원한 자루 없음 · 괴수 아님 · 전투 중 아님",
	AltarCooldownRuleF = "진영 변경은 %d분에 한 번",
	AltarCooldownF = "%s 후 가능",
	AltarFar = "운명의 제단 가까이에서만 바꿀 수 있어요.",
	AltarConfirmTitle = "진영 변경",
	AltarConfirmFreeF = "%s(으)로 바꿀까요?\n무료: %s",
	AltarConfirmTicketF = "변경권 1장을 써서 %s(으)로 바꿀까요?\n명예·악명 모두 그대로예요.",
	Honor = "명예",
	Infamy = "악명",
	LossScoreF = "%s %s 초기화",
	BetrayalSuffix = " (배신의 대가)",
	-- shared change options (A7-4)
	Selected = "선택됨",
	FreeButton = "무료로 바꾸기",
	TicketButtonF = "티켓으로 바꾸기 (보유 %d장)",
	TicketKeepAll = "전부 유지",
	TicketBuyHint = "보유 0장 · 산 다음 한 번 더 눌러야 바뀌어요",
	LossNone = "잃는 것 없음",
	ConfirmChange = "바꾸기",
	-- class
	ClassPickFirst = "먼저 직업을 골라 주세요.",
	ClassHint = "바꿀 직업 카드를 눌러요.",
	ClassCurrent = "현재",
	ClassHeaderF = "%s(으)로 바꾸기",
	ClassLossLevelF = "Lv %d → Lv 1",
	ClassLossXPF = "경험치 %d 초기화",
	ClassKeeps = "골드·무기·환생 보너스는 그대로",
	ClassConfirmTitle = "직업 변경",
	ClassConfirmFreeF = "%s(으)로 바꿀까요?\n무료: %s",
	ClassConfirmTicketF = "변경권 1장을 써서 %s(으)로 바꿀까요?\n레벨 그대로 유지돼요.",
	-- shop
	ShopRowF = "%s — 보유 %d장",
	ShopNote = "변경권은 능력치가 아니에요. 진행도를 지키는 선택권이에요. 무료로도 언제든 바꿀 수 있어요!",
	ProductPending = "상품 준비 중",
	ProductBuyF = "로벅스로 구매 (%s R$)",
	-- vacation
	VacationHeaderF = "휴가 보너스! %d일 동안 못 왔지만 괜찮아요.",
	VacationRewardF = "+%s 골드 · +%s 경험치",
	VacationNoteF = "쉬어도 하루치 보상의 %d%%를 챙겨 줘요. 직접 하면 100%%!",
	VacationClaim = "받기",
	VacationNone = "받을 휴가 보너스가 없어요.",
}

local DEFAULT_THEME = {
	Bg = Color3.fromRGB(25, 25, 35),
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(200, 200, 210),
	Good = Color3.fromRGB(80, 220, 120),
	Bad = Color3.fromRGB(255, 80, 80),
	Gold = Color3.fromRGB(255, 210, 60),
	XP = Color3.fromRGB(90, 170, 255),
	Font = Enum.Font.GothamBold,
}
local PALETTE = {
	Button = Color3.fromRGB(62, 66, 96),
	Card = Color3.fromRGB(42, 44, 62),
	CardSelected = Color3.fromRGB(80, 84, 128),
	Row = Color3.fromRGB(40, 42, 58),
	Free = Color3.fromRGB(44, 150, 82),
	Ticket = Color3.fromRGB(50, 112, 205),
	Buy = Color3.fromRGB(150, 78, 200),
	Close = Color3.fromRGB(190, 60, 60),
	Disabled = Color3.fromRGB(70, 70, 80),
	DarkText = Color3.fromRGB(30, 26, 18),
}

------------------------------------------------------------------ state
local C = nil
local UIKit = nil
local theme = table.clone(DEFAULT_THEME)

local fallbackGui = nil
local root, window, titleLabel, backButton, content = nil, nil, nil, nil, nil
local currentId = nil
local currentUpdate = nil
local openedFromMenu = false
local pendingFromMenu = false
local selectedClass = nil
local selectedTarget = nil
local rebuildQueued = false
local vacationShown = false
local pickersClosedSince = nil
local orderCounter = 0
local lastWarnAt = -math.huge
local cameraConn = nil
local scaleConn = nil

local disabledButtons = setmetatable({}, { __mode = "k" })
local baseColors = setmetatable({}, { __mode = "k" })
local textColors = setmetatable({}, { __mode = "k" })

------------------------------------------------------------------ attribute helpers
local function attr(name, default)
	local v = player:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function num(name)
	local v = player:GetAttribute(name)
	return type(v) == "number" and v or 0
end

local function gameAttr(name)
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	if not gs then return nil end
	return gs:GetAttribute(name)
end

local function gameNum(name)
	local v = gameAttr(name)
	return type(v) == "number" and v or 0
end

local function myFaction()
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function currentClass()
	local c = player:GetAttribute("Class")
	if type(c) == "string" and Config.Classes[c] then return c end
	return "Warrior"
end

local function kaijuState()
	local k = player:GetAttribute("KaijuState")
	return type(k) == "string" and k or "None"
end

local function inCombat()
	return num("InCombatUntil") > Util.Now()
end

local function fmtText(key, ...)
	local s = Config.Text[key]
	if type(s) ~= "string" then return tostring(key) end
	local ok, out = pcall(string.format, s, ...)
	return ok and out or s
end

-- Config.Text[key] when G1 provides it (addendum A7-3/A7-4 keys), else the private fallback format
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

------------------------------------------------------------------ faction / class display helpers
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

local function perksText(id)
	local def = factionDef(id)
	local lines = {}
	if type(def.Perks) == "table" then
		for _, p in def.Perks do
			table.insert(lines, "• " .. tostring(p))
		end
	end
	if id == "Neutral" and #lines == 0 then
		table.insert(lines, "• " .. ((type(def.Note) == "string" and def.Note) or NEUTRAL_NOTE))
	end
	return table.concat(lines, "\n")
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

local function markPreview(fromId, toId)
	if fromId == "Halo" and toId == "Horns" then return string.format(Config.Story.Fall) end
	if fromId == "Horns" and toId == "Halo" then return string.format(Config.Story.Redeem) end
	return nil
end

-- dark text on bright fills (Halo gold, Neutral teal A9-1), white on darker ones (Horns red, green)
local function contrastText(c)
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return lum > 0.55 and PALETTE.DarkText or Color3.new(1, 1, 1)
end

-- exact digits with thousands separators (A7-4: "show the exact loss as numbers", e.g. "명예 12,345 초기화")
local function exactNumber(n)
	n = math.floor(tonumber(n) or 0)
	local digits = tostring(math.abs(n))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then grouped = string.sub(grouped, 2) end
	return (n < 0 and "-" or "") .. grouped
end

------------------------------------------------------------------ UI infrastructure
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
	fallbackGui.Name = "PanelsGui"
	fallbackGui.ResetOnSpawn = false
	fallbackGui.IgnoreGuiInset = true
	fallbackGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fallbackGui.DisplayOrder = 11
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
	return c
end

local function nextOrder()
	orderCounter += 1
	return orderCounter
end

-- auto-height wrapped text in a list layout
local function addText(parent, text, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.Name = opts.Name or "Text"
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Size = opts.Width or UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = opts.Font or BODY_FONT
	l.TextSize = opts.Size or 18
	l.TextColor3 = opts.Color or theme.Text
	l.TextWrapped = true
	l.RichText = opts.Rich == true
	l.TextXAlignment = opts.Align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text or ""
	l.LayoutOrder = nextOrder()
	constrainText(l)
	l.Parent = parent
	return l
end

-- absolutely positioned single-line label
local function placeLabel(parent, text, size, color, pos, dim, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Position = pos
	l.Size = dim
	l.Font = theme.Font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text or ""
	constrainText(l)
	l.Parent = parent
	return l
end

local function addRow(parent, height, padding)
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, height or 0)
	if not height or height <= 0 then f.AutomaticSize = Enum.AutomaticSize.Y end
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, padding or 10)
	list.Parent = f
	f.Parent = parent
	return f
end

local function addColumn(parent, scaleX, offsetX, padding)
	local f = Instance.new("Frame")
	f.Name = "Column"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(scaleX, offsetX, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, padding or 6)
	list.Parent = f
	f.Parent = parent
	return f
end

local function applyButtonState(btn)
	local enabled = not disabledButtons[btn]
	local base = baseColors[btn] or PALETTE.Button
	btn.BackgroundColor3 = enabled and base or base:Lerp(PALETTE.Disabled, 0.75)
	btn.TextColor3 = textColors[btn] or theme.Text
	btn.TextTransparency = enabled and 0 or 0.4
	btn.AutoButtonColor = false -- UIKit's press-shrink is the feedback
	btn:SetAttribute("Disabled", not enabled) -- UIKit.Button skips its click sound / tween while disabled
end

local function paintButton(btn, color, textColor)
	local tc = textColor or theme.Text
	if baseColors[btn] == color and textColors[btn] == tc then return end
	baseColors[btn] = color
	textColors[btn] = tc
	applyButtonState(btn)
end

local function setEnabled(btn, enabled)
	local wasDisabled = disabledButtons[btn] == true
	if wasDisabled == not enabled then return end
	disabledButtons[btn] = (not enabled) or nil
	applyButtonState(btn)
end

local function playClick()
	local fx = C and C.Fx
	if fx and type(fx.PlaySound) == "function" then
		pcall(fx.PlaySound, "Click")
	end
end

-- UIKit.Button (click sound, press tween) with a local fallback; clicks are ignored while disabled
local function makeButton(parent, text, color, size, onClick, textColor)
	local btn = nil
	local function handler()
		if not btn or disabledButtons[btn] then return end
		local ok, err = pcall(onClick)
		if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
	end
	if UIKit and type(UIKit.Button) == "function" then
		local ok, b = pcall(UIKit.Button, {
			Name = "Button", Text = text, Size = size, Color = color,
			TextColor = textColor or theme.Text, TextSize = 20, Parent = parent,
		}, handler)
		if ok and typeof(b) == "Instance" and b:IsA("GuiButton") then btn = b end
	end
	if not btn then
		local b = Instance.new("TextButton")
		b.Size = size
		b.Font = theme.Font
		b.TextSize = 20
		b.BorderSizePixel = 0
		corner(b, 10)
		b.Activated:Connect(function()
			playClick()
			handler()
		end)
		btn = b
	end
	btn.Name = "Button"
	btn.Text = text
	btn.TextWrapped = true
	btn.LayoutOrder = nextOrder()
	if not btn:FindFirstChildOfClass("UITextSizeConstraint") then constrainText(btn, 28) end
	baseColors[btn] = nil
	paintButton(btn, color, textColor)
	btn.Parent = parent
	return btn
end

-- selectable card (own TextButton so the border stroke is fully controlled)
local function makeCard(parent, size, accent, onClick)
	local card = Instance.new("TextButton")
	card.Name = "Card"
	card.Text = ""
	card.AutoButtonColor = true
	card.BackgroundColor3 = PALETTE.Card
	card.BorderSizePixel = 0
	card.Size = size
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = nextOrder()
	constrainText(card)
	corner(card, 12)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = accent
	st.Thickness = 2
	st.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = card
	card.Activated:Connect(function()
		playClick()
		local ok, err = pcall(onClick)
		if not ok then Util.Warn(TAG, "card handler error: " .. tostring(err)) end
	end)
	card.Parent = parent
	return card, st
end

local function toast(text, kind, duration)
	if UIKit and type(UIKit.Toast) == "function" then
		pcall(UIKit.Toast, text, kind, duration)
	end
end

local function confirm(title, body, okText, onConfirm)
	if UIKit and type(UIKit.Confirm) == "function" then
		local ok, err = pcall(UIKit.Confirm, title, body, okText, onConfirm)
		if not ok then Util.Warn(TAG, "UIKit.Confirm failed: " .. tostring(err)) end
	else
		Util.Warn(TAG, "UIKit.Confirm is unavailable")
	end
end

-- fire a client -> server intent without ever blocking the caller
local function fire(remoteName, ...)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get(remoteName):FireServer(table.unpack(args, 1, args.n))
		end)
		if not ok then Util.Warn(TAG, "could not send " .. remoteName .. ": " .. tostring(err)) end
	end)
end

local function productLabel(kind)
	local p = Config.ProductByKind(kind)
	if not p or p.Id == 0 then return T.ProductPending end
	return string.format(T.ProductBuyF, tostring(p.PriceHint))
end

-- never consumes a ticket: buying only adds one (the server toast confirms); the player must click again to use it
local function buy(kind)
	local p = Config.ProductByKind(kind)
	if p and p.Id ~= 0 then
		local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, p.Id)
		if not ok then Util.Warn(TAG, "PromptProductPurchase failed: " .. tostring(err)) end
	else
		toast(fmtText("ProductNotReady"), "info")
	end
end

------------------------------------------------------------------ rules mirrored from the server (display only)
local function travelBlock(destId, zone, level, faction)
	if num("TravelingUntil") > Util.Now() then return fmtText("Traveling"), T.TravelBusy end
	if destId == "Home" and faction == "None" then return fmtText("NeedFaction"), T.TravelNoGo end
	if level < zone.MinLevel then
		return fmtText("NeedLevel", math.floor(zone.MinLevel)), string.format(T.TravelNeedLevelF, math.floor(zone.MinLevel))
	end
	local k = kaijuState()
	if k == "Siren" or k == "Active" then return fmtText("TravelBlockedKaiju"), T.TravelNoGo end
	if num("SackGold") > 0 then return fmtText("TravelBlockedSack"), T.TravelNoGo end
	if num("WantedStars") >= Config.PvP.NoTravelStars then return fmtText("TravelBlockedStars"), T.TravelNoGo end
	if inCombat() then return fmtText("TravelBlockedCombat"), T.TravelNoGo end
	return nil, nil
end

local function rebirthBlock(level, req)
	if level < req then return fmtText("RebirthNeed", math.floor(req)) end
	if num("WantedStars") > 0 then return fmtText("BlockedStars") end
	if num("SackGold") > 0 then return fmtText("BlockedSack") end
	if kaijuState() ~= "None" then return fmtText("BlockedKaiju") end
	if inCombat() then return fmtText("TravelBlockedCombat") end
	return nil
end

-- underdog ratio counts Halo vs Horns only (A6); Neutral always gets the normal bonus
local function rebirthBonus(targetId, othersHalo, othersHorns)
	if targetId == "Halo" then return Config.RebirthBonusFor(othersHalo, othersHalo + othersHorns) end
	if targetId == "Horns" then return Config.RebirthBonusFor(othersHorns, othersHalo + othersHorns) end
	return Config.Rebirth.BonusNormal
end

local function altarDistance()
	local map = workspace:FindFirstChild("Map")
	local landmarks = map and map:FindFirstChild("Landmarks")
	local altar = landmarks and landmarks:FindFirstChild("Altar")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (altar and altar:IsA("BasePart") and hrp and hrp:IsA("BasePart")) then return nil end
	return Util.FlatDistance(altar.Position, hrp.Position)
end

-- returns (reasonText?, shortCooldownText?)
local function altarBlock()
	local d = altarDistance()
	if d and d > Config.Switch.AltarRange then return T.AltarFar, nil end
	if num("SackGold") > 0 then return fmtText("BlockedSack"), nil end
	if kaijuState() ~= "None" then return fmtText("BlockedKaiju"), nil end
	if num("WantedStars") > 0 then return fmtText("BlockedStars"), nil end
	if inCombat() then return fmtText("TravelBlockedCombat"), nil end
	local last = num("LastSwitchTime")
	local remaining = last + Config.Switch.Cooldown - Util.Now()
	if last > 0 and remaining > 0 then
		local t = Util.FormatTime(math.ceil(remaining))
		return fmtText("SwitchCooldown", t), string.format(T.AltarCooldownF, t)
	end
	return nil, nil
end

-- the score of the faction being LEFT on a free switch ("배신의 대가"); Neutral has none (A6)
local function leftScore(fromId)
	if fromId == "Halo" then return T.Honor, math.floor(num("Honor")) end
	if fromId == "Horns" then return T.Infamy, math.floor(num("Infamy")) end
	return nil, 0
end

local function altarLossText(fromId)
	local scoreName, amount = leftScore(fromId)
	if scoreName and amount > 0 then
		return cfgFmt("LossScore", T.LossScoreF, scoreName, exactNumber(amount)) .. T.BetrayalSuffix, true
	end
	return T.LossNone, false
end

-- same checks and order as ClassService.onChangeClass (PvP zone, sack, kaiju, combat tag)
local function classBlock()
	if player:GetAttribute("ZonePvP") == true then return fmtText("ClassNeedSafe") end
	if num("SackGold") > 0 then return fmtText("BlockedSack") end
	if kaijuState() ~= "None" then return fmtText("BlockedKaiju") end
	if inCombat() then return fmtText("TravelBlockedCombat") end
	return nil
end

local function classLossText()
	local level, xp = math.floor(num("Level")), math.floor(num("XP"))
	if level > 1 then return cfgFmt("LossLevel", T.ClassLossLevelF, level), true end
	if xp > 0 then return string.format(T.ClassLossXPF, xp), true end
	return T.LossNone, false
end

local function pickerOpen()
	if not C then return false end
	for _, name in { "FactionPicker", "ClassPicker" } do
		local m = C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			if ok and open then return true end
		end
	end
	return false
end

------------------------------------------------------------------ modal root
local function layoutRoot()
	if not root or not window then return end
	local w, h, top = canvas(root.Parent)
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(w, h)
	local availH = math.max(220, h - top - 12)
	local winW = math.max(280, math.min(WINDOW_MAX_W, w - 24))
	local winH = math.min(WINDOW_MAX_H, availH)
	window.Size = UDim2.fromOffset(winW, winH)
	window.Position = UDim2.fromOffset(w / 2, top + availH / 2)
end

local function ensureRoot()
	if root and root.Parent then return true end
	local gui = getGui()
	if not gui then return false end
	if root then root:Destroy() end

	root = Instance.new("Frame")
	root.Name = "PanelsModal"
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 0.45
	root.BorderSizePixel = 0
	root.Active = true -- sinks clicks so the HUD's attack input ignores them
	root.ZIndex = ZINDEX
	root.Visible = false

	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = theme.Bg
	window.BackgroundTransparency = 0.04
	window.BorderSizePixel = 0
	window.Active = true
	corner(window, 16)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = theme.Gold
	st.Thickness = 2
	st.Transparency = 0.3
	st.Parent = window
	window.Parent = root

	titleLabel = placeLabel(window, "", 26, theme.Gold, UDim2.fromOffset(18, 10), UDim2.new(1, -220, 0, 44))

	local closeButton = makeButton(window, T.Close, PALETTE.Close, UDim2.fromOffset(52, 44), function()
		Panels.Close()
	end)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 10)

	backButton = makeButton(window, T.Back, PALETTE.Button, UDim2.fromOffset(112, 44), function()
		Panels.Open("Menu")
	end)
	backButton.AnchorPoint = Vector2.new(1, 0)
	backButton.Position = UDim2.new(1, -74, 0, 10)
	backButton.Visible = false

	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(14, 64)
	content.Size = UDim2.new(1, -28, 1, -76)
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = theme.SubText
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = content
	content.Parent = window

	root.Parent = gui
	layoutRoot()
	return true
end

local function clearContent()
	if not content then return end
	for _, ch in content:GetChildren() do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
end

local function openSub(id)
	pendingFromMenu = true
	Panels.Open(id)
end

------------------------------------------------------------------ panel builders: build(parent) -> update()?
local BUILDERS = {}

BUILDERS.Menu = function(parent)
	local entries = {
		{ Text = T.MenuTravel, Id = "Travel" },
		{ Text = T.MenuRebirth, Id = "Rebirth" },
		{ Text = T.MenuClass, Id = "Class" },
		{ Text = T.MenuShop, Id = "Shop" },
		{ Text = "지도", Id = "Map" },
	}
	if num("VacationDays") > 0 then
		table.insert(entries, { Text = T.MenuVacation, Id = "Vacation" })
	end
	local rows = math.ceil(#entries / 2)
	local grid = Instance.new("Frame")
	grid.Name = "MenuGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 0, rows * 70 + (rows - 1) * 14)
	grid.LayoutOrder = nextOrder()
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(200, 70)
	gl.CellPadding = UDim2.fromOffset(14, 14)
	gl.FillDirection = Enum.FillDirection.Horizontal
	gl.FillDirectionMaxCells = 2
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	grid.Parent = parent

	local rebirthBtn = nil
	for _, e in entries do
		local id = e.Id
		local color = (id == "Vacation") and PALETTE.Free or PALETTE.Button
		local b = makeButton(grid, e.Text, color, UDim2.fromOffset(200, 70), function()
			if id == "Map" then
				local wm = C and C.WorldMap
				if wm and wm.Open then wm.Open() end
			else
				openSub(id)
			end
		end)
		b.TextSize = 22
		if id == "Rebirth" then rebirthBtn = b end
	end

	addText(parent, T.MenuAltarHint, { Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	addText(parent, Config.Story.MarkLore, { Color = theme.SubText, Size = 16, Align = Enum.TextXAlignment.Center })

	return function()
		if not rebirthBtn then return end
		local ready = num("Level") >= Config.RebirthLevel(num("Rebirths"))
		rebirthBtn.Text = ready and T.MenuRebirthReady or T.MenuRebirth
		if ready then
			paintButton(rebirthBtn, theme.Gold, PALETTE.DarkText)
		else
			paintButton(rebirthBtn, PALETTE.Button, theme.Text)
		end
	end
end

BUILDERS.Travel = function(parent)
	local faction = myFaction()
	local rows = {}
	for _, dest in Config.Travel.Destinations do
		local destId = dest.Id
		local zoneId = (destId == "Home") and Config.HomeZoneId(faction) or destId
		local zone = Config.Zones[zoneId]
		if zone then
			local row = Instance.new("Frame")
			row.Name = "Row_" .. destId
			row.BackgroundColor3 = PALETTE.Row
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, 68)
			row.LayoutOrder = nextOrder()
			corner(row, 10)
			row.Parent = parent

			local title = dest.Name
			if destId == "Home" and faction ~= "None" then title = dest.Name .. " (" .. zone.Name .. ")" end
			local nameLabel = placeLabel(row, title, 20, theme.Text, UDim2.fromOffset(14, 6), UDim2.new(1, -184, 0, 30))
			nameLabel.RichText = true
			local infoLabel = placeLabel(row, "", 15, theme.SubText, UDim2.fromOffset(14, 38), UDim2.new(1, -184, 0, 24))
			infoLabel.Font = BODY_FONT

			local btn = makeButton(row, T.TravelGo, PALETTE.Ticket, UDim2.fromOffset(156, 48), function()
				fire("Travel", destId)
				Panels.Close()
			end)
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, -10, 0.5, 0)

			table.insert(rows, {
				DestId = destId, ZoneId = zoneId, Zone = zone, Title = title,
				Name = nameLabel, Info = infoLabel, Button = btn,
			})
		end
	end

	return function()
		local level = num("Level")
		local recommended = Config.QuestZoneForLevel(math.max(1, level))
		local here = attr("ZoneId", "")
		for _, r in rows do
			local base = string.format(T.TravelInfoF, math.floor(r.Zone.MinLevel), r.Zone.PvP and T.PvP or T.Safe)
			if here == r.ZoneId then base ..= T.TravelHere end
			local reason, short = travelBlock(r.DestId, r.Zone, level, faction)
			r.Info.Text = reason or base
			r.Info.TextColor3 = reason and theme.Bad or theme.SubText
			r.Button.Text = short or T.TravelGo
			setEnabled(r.Button, reason == nil)
			local isRec = r.DestId ~= "Home" and r.ZoneId == recommended
			local badge = string.format(T.TravelRecommendF, cfgFmt("Recommended", T.Recommended))
			r.Name.Text = isRec and (r.Title .. badge) or r.Title
		end
	end
end

local function confirmRebirth(targetId)
	local reason = rebirthBlock(num("Level"), Config.RebirthLevel(num("Rebirths")))
	if reason then
		toast(reason, "bad")
		return
	end
	local body = string.format(T.RebirthConfirmBodyF, factionDef(targetId).Name)
	local mark = markPreview(myFaction(), targetId)
	if mark then body = body .. "\n" .. mark end
	confirm(T.RebirthConfirmTitle, body, T.RebirthConfirmOk, function()
		fire("Rebirth", targetId)
		Panels.Close()
	end)
end

BUILDERS.Rebirth = function(parent)
	local mine = myFaction()
	addText(parent, string.format(Config.Story.RebirthIntro), { Size = 19, Font = theme.Font })
	local infoLabel = addText(parent, "", { Color = theme.SubText, Size = 17 })
	local countLabel = addText(parent, "", { Color = theme.SubText, Size = 17 })

	local row = addRow(parent, 0, 10)
	local cols = {}
	for _, id in FACTION_IDS do
		local def = factionDef(id)
		local color = factionColor(id)
		local col = addColumn(row, 1 / #FACTION_IDS, -7, 4)
		local btn = makeButton(col, def.Name, color, UDim2.new(1, 0, 0, 64), function()
			confirmRebirth(id)
		end, contrastText(color))
		local bonus = addText(col, "", { Size = 17, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
		if id == mine then
			addText(col, T.RebirthCurrent, { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		end
		local mark = markPreview(mine, id)
		if mark then
			addText(col, mark, { Size = 14, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		end
		cols[id] = { Button = btn, Bonus = bonus }
	end

	addText(parent, T.RebirthResets, { Size = 16 })
	addText(parent, T.RebirthKeeps, { Size = 16 })
	local reasonLabel = addText(parent, "", { Color = theme.Bad, Size = 17, Font = theme.Font })

	return function()
		local level, reb = num("Level"), num("Rebirths")
		local req = Config.RebirthLevel(reb)
		infoLabel.Text = string.format(T.RebirthInfoF, math.floor(reb), math.floor(req), math.floor(level))

		local halo, horns = math.floor(gameNum("HaloCount")), math.floor(gameNum("HornsCount"))
		countLabel.Text = string.format(T.RebirthCountsF, halo, horns) -- Halo vs Horns only (A6)

		-- "others" = server counts minus me (only Halo/Horns are counted)
		local oHalo, oHorns = halo, horns
		if mine == "Halo" then
			oHalo = math.max(0, oHalo - 1)
		elseif mine == "Horns" then
			oHorns = math.max(0, oHorns - 1)
		end
		for id, col in cols do
			local bonus = rebirthBonus(id, oHalo, oHorns)
			local pct = math.floor(bonus * 100 + 0.5)
			if bonus > Config.Rebirth.BonusNormal + 1e-6 then
				col.Bonus.Text = string.format(T.RebirthBonusUnderdogF, pct)
			else
				col.Bonus.Text = string.format(T.RebirthBonusF, pct)
			end
		end

		local reason = rebirthBlock(level, req)
		reasonLabel.Text = reason or ""
		reasonLabel.Visible = reason ~= nil
		for _, col in cols do
			setEnabled(col.Button, reason == nil)
		end
	end
end

local function altarFree()
	local target = selectedTarget
	if not target then return end
	local reason = altarBlock()
	if reason then
		toast(reason, "bad")
		return
	end
	local lossText = altarLossText(myFaction())
	confirm(T.AltarConfirmTitle, string.format(T.AltarConfirmFreeF, factionDef(target).Name, lossText), T.ConfirmChange, function()
		fire("SwitchFaction", false, target)
		Panels.Close()
	end)
end

local function altarTicket()
	if num("FactionTickets") <= 0 then
		buy("Faction")
		return
	end
	local target = selectedTarget
	if not target then return end
	local reason = altarBlock()
	if reason then
		toast(reason, "bad")
		return
	end
	confirm(T.AltarConfirmTitle, string.format(T.AltarConfirmTicketF, factionDef(target).Name), T.ConfirmChange, function()
		fire("SwitchFaction", true, target)
		Panels.Close()
	end)
end

BUILDERS.Altar = function(parent)
	local cur = myFaction()
	if cur == "None" then
		addText(parent, fmtText("NeedFaction"), { Color = theme.Bad })
		return nil
	end
	local targets = {}
	for _, id in FACTION_IDS do
		if id ~= cur then table.insert(targets, id) end
	end
	if not selectedTarget or not table.find(targets, selectedTarget) then selectedTarget = targets[1] end

	addText(parent, string.format(T.AltarCurrentF, factionDef(cur).Name), { Size = 20, Font = theme.Font })

	local cardRow = addRow(parent, 0, 12)
	local cards = {}
	for _, id in targets do
		local def = factionDef(id)
		local color = factionColor(id)
		local card, st = makeCard(cardRow, UDim2.new(1 / #targets, -6, 0, 0), color, function()
			selectedTarget = id
			if currentUpdate then currentUpdate() end
		end)
		addText(card, def.Name, { Size = 22, Color = color, Align = Enum.TextXAlignment.Center, Font = theme.Font })
		if type(def.Pitch) == "string" and def.Pitch ~= "" then
			addText(card, def.Pitch, { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		end
		local sel = addText(card, T.Selected, { Size = 15, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
		cards[id] = { Card = card, Stroke = st, Selected = sel }
	end

	local loreLabel = addText(parent, "", { Color = theme.SubText, Size = 16 })
	local perksLabel = addText(parent, "", { Size = 16 })
	addText(parent, T.AltarRules, { Size = 15, Color = theme.SubText })
	addText(parent, string.format(T.AltarCooldownRuleF, math.max(1, math.floor(Config.Switch.Cooldown / 60 + 0.5))),
		{ Size = 15, Color = theme.SubText })
	local reasonLabel = addText(parent, "", { Color = theme.Bad, Size = 17, Font = theme.Font })

	local optRow = addRow(parent, 0, 14)
	local freeCol = addColumn(optRow, 0.5, -7, 4)
	local freeBtn = makeButton(freeCol, cfgFmt("ChangeFree", T.FreeButton), PALETTE.Free, UDim2.new(1, 0, 0, 58), altarFree)
	local freeSub = addText(freeCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })
	local ticketCol = addColumn(optRow, 0.5, -7, 4)
	local ticketBtn = makeButton(ticketCol, "", PALETTE.Ticket, UDim2.new(1, 0, 0, 58), altarTicket)
	local ticketSub = addText(ticketCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })

	return function()
		for id, c in cards do
			local isSel = id == selectedTarget
			c.Card.BackgroundColor3 = isSel and PALETTE.CardSelected or PALETTE.Card
			c.Stroke.Thickness = isSel and 4 or 2
			c.Selected.Visible = isSel
		end
		local target = selectedTarget
		local lore = factionLore(target)
		loreLabel.Text = lore
		loreLabel.Visible = lore ~= ""
		local perks = perksText(target)
		perksLabel.Text = perks
		perksLabel.Visible = perks ~= ""

		local lossText, loses = altarLossText(cur)
		freeSub.Text = lossText
		ticketCol.Visible = loses -- A7-4: free path loses nothing -> no ticket button

		local tickets = math.floor(num("FactionTickets"))
		if tickets > 0 then
			ticketBtn.Text = cfgFmt("ChangeTicket", T.TicketButtonF, tickets)
			ticketSub.Text = cfgFmt("KeepAll", T.TicketKeepAll)
			paintButton(ticketBtn, PALETTE.Ticket)
		else
			ticketBtn.Text = productLabel("Faction")
			ticketSub.Text = T.TicketBuyHint
			paintButton(ticketBtn, PALETTE.Buy)
		end

		local reason, short = altarBlock()
		reasonLabel.Text = reason or ""
		reasonLabel.Visible = reason ~= nil
		freeBtn.Text = short or cfgFmt("ChangeFree", T.FreeButton)
		setEnabled(freeBtn, reason == nil)
		setEnabled(ticketBtn, tickets <= 0 or reason == nil) -- buying stays possible; using follows the same rules
	end
end

local function classFree()
	local target = selectedClass
	if not target or target == currentClass() then return end
	local reason = classBlock()
	if reason then
		toast(reason, "bad")
		return
	end
	local lossText = classLossText()
	confirm(T.ClassConfirmTitle, string.format(T.ClassConfirmFreeF, className(target, myFaction()), lossText), T.ConfirmChange, function()
		fire("ChangeClass", target, false)
		Panels.Close()
	end)
end

local function classTicket()
	if num("ClassTickets") <= 0 then
		buy("Class")
		return
	end
	local target = selectedClass
	if not target or target == currentClass() then return end
	local reason = classBlock()
	if reason then
		toast(reason, "bad")
		return
	end
	confirm(T.ClassConfirmTitle, string.format(T.ClassConfirmTicketF, className(target, myFaction())), T.ConfirmChange, function()
		fire("ChangeClass", target, true)
		Panels.Close()
	end)
end

BUILDERS.Class = function(parent)
	if player:GetAttribute("ClassChosen") ~= true then
		addText(parent, T.ClassPickFirst, { Color = theme.SubText })
		return nil
	end
	local faction = myFaction()
	local cur = currentClass()
	if selectedClass == cur or (selectedClass ~= nil and Config.Classes[selectedClass] == nil) then selectedClass = nil end
	local accent = factionColor(faction)

	local cardRow = addRow(parent, 0, 10)
	local cards = {}
	local count = #Config.ClassOrder
	for _, id in Config.ClassOrder do
		local def = Config.Classes[id]
		if def then
			local card, st = makeCard(cardRow, UDim2.new(1 / count, -7, 0, 0), accent, function()
				if id == currentClass() then return end
				selectedClass = id
				if currentUpdate then currentUpdate() end
			end)
			addText(card, className(id, faction), { Size = 21, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
			addText(card, "(" .. genericClassName(id) .. ")", { Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
			addText(card, pickLine(id), { Size = 16, Align = Enum.TextXAlignment.Center, Font = theme.Font })
			addText(card, def.Desc or "", { Size = 14, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
			if type(def.Stats) == "table" then
				addText(card, table.concat(def.Stats, "\n"), { Size = 14, Align = Enum.TextXAlignment.Center })
			end
			local badge = addText(card, "", { Size = 16, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
			cards[id] = { Card = card, Stroke = st, Badge = badge }
		end
	end

	local hint = addText(parent, T.ClassHint, { Color = theme.SubText, Align = Enum.TextXAlignment.Center })
	local options = addColumn(parent, 1, 0, 8)
	local header = addText(options, "", { Size = 19, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local reasonLabel = addText(options, "", { Color = theme.Bad, Size = 17, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local optRow = addRow(options, 0, 14)
	local freeCol = addColumn(optRow, 0.5, -7, 4)
	local freeBtn = makeButton(freeCol, cfgFmt("ChangeFree", T.FreeButton), PALETTE.Free, UDim2.new(1, 0, 0, 58), classFree)
	local freeSub = addText(freeCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })
	local ticketCol = addColumn(optRow, 0.5, -7, 4)
	local ticketBtn = makeButton(ticketCol, "", PALETTE.Ticket, UDim2.new(1, 0, 0, 58), classTicket)
	local ticketSub = addText(ticketCol, "", { Size = 15, Align = Enum.TextXAlignment.Center })

	return function()
		local curNow = currentClass()
		if selectedClass == curNow then selectedClass = nil end
		for id, c in cards do
			local isCur = id == curNow
			local isSel = id == selectedClass
			c.Badge.Text = isCur and T.ClassCurrent or T.Selected
			c.Badge.Visible = isCur or isSel
			c.Card.BackgroundColor3 = isSel and PALETTE.CardSelected or PALETTE.Card
			c.Stroke.Thickness = isSel and 4 or 2
		end
		local sel = selectedClass
		hint.Visible = sel == nil
		options.Visible = sel ~= nil
		if not sel then return end

		header.Text = string.format(T.ClassHeaderF, className(sel, faction))
		local lossText, loses = classLossText()
		freeSub.Text = loses and (lossText .. "\n" .. T.ClassKeeps) or lossText
		ticketCol.Visible = loses -- A7-4: free path loses nothing -> no ticket button

		local tickets = math.floor(num("ClassTickets"))
		if tickets > 0 then
			ticketBtn.Text = cfgFmt("ChangeTicket", T.TicketButtonF, tickets)
			ticketSub.Text = cfgFmt("KeepAll", T.TicketKeepAll)
			paintButton(ticketBtn, PALETTE.Ticket)
		else
			ticketBtn.Text = productLabel("Class")
			ticketSub.Text = T.TicketBuyHint
			paintButton(ticketBtn, PALETTE.Buy)
		end

		local reason = classBlock()
		reasonLabel.Text = reason or ""
		reasonLabel.Visible = reason ~= nil
		setEnabled(freeBtn, reason == nil)
		setEnabled(ticketBtn, tickets <= 0 or reason == nil)
	end
end

BUILDERS.Shop = function(parent)
	local rows = {}
	for _, kind in { "Class", "Faction" } do
		local p = Config.ProductByKind(kind)
		local row = Instance.new("Frame")
		row.Name = "Row_" .. kind
		row.BackgroundColor3 = PALETTE.Row
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 72)
		row.LayoutOrder = nextOrder()
		corner(row, 10)
		row.Parent = parent
		local label = placeLabel(row, "", 20, theme.Text, UDim2.fromOffset(14, 0), UDim2.new(1, -270, 1, 0))
		local btn = makeButton(row, productLabel(kind), PALETTE.Buy, UDim2.fromOffset(240, 52), function()
			buy(kind)
		end)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		table.insert(rows, { Kind = kind, Label = label, Name = (p and p.Name) or kind })
	end
	addText(parent, T.ShopNote, { Color = theme.SubText, Size = 16 })

	return function()
		for _, r in rows do
			r.Label.Text = string.format(T.ShopRowF, r.Name, math.floor(num(TICKET_ATTR[r.Kind])))
		end
	end
end

BUILDERS.Vacation = function(parent)
	local days = math.floor(num("VacationDays"))
	if days <= 0 then
		addText(parent, T.VacationNone, { Color = theme.SubText, Align = Enum.TextXAlignment.Center })
		return nil
	end
	vacationShown = true -- seen this session (manual open counts too)
	addText(parent, string.format(T.VacationHeaderF, days), { Size = 24, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	local reward = addText(parent, "", { Size = 22, Color = theme.Gold, Align = Enum.TextXAlignment.Center, Font = theme.Font })
	addText(parent, string.format(T.VacationNoteF, math.floor(Config.Daily.VacationRate * 100 + 0.5)),
		{ Size = 15, Color = theme.SubText, Align = Enum.TextXAlignment.Center })
	local row = addRow(parent, 64, 0)
	makeButton(row, T.VacationClaim, PALETTE.Free, UDim2.fromOffset(240, 60), function()
		fire("ClaimVacation")
		Panels.Close()
	end)

	return function()
		reward.Text = string.format(T.VacationRewardF, Util.FormatNumber(num("VacationGold")), Util.FormatNumber(num("VacationXP")))
	end
end

------------------------------------------------------------------ render / open / close
local function render()
	if not currentId or not ensureRoot() then return end
	layoutRoot()
	clearContent()
	orderCounter = 0
	currentUpdate = nil
	titleLabel.Text = T.Titles[currentId] or ""
	backButton.Visible = openedFromMenu and currentId ~= "Menu"
	local ok, result = pcall(BUILDERS[currentId], content)
	if not ok then
		Util.Warn(TAG, "failed to build " .. tostring(currentId) .. ": " .. tostring(result))
		return
	end
	if type(result) == "function" then
		currentUpdate = result
		local ok2, err = pcall(result)
		if not ok2 then Util.Warn(TAG, "update error in " .. tostring(currentId) .. ": " .. tostring(err)) end
	end
	content.CanvasPosition = Vector2.new(0, 0)
end

local function queueRebuild()
	if rebuildQueued then return end
	rebuildQueued = true
	task.defer(function()
		rebuildQueued = false
		if not currentId then return end
		if pickerOpen() then
			Panels.Close()
			return
		end
		render()
	end)
end

function Panels.Open(id)
	local fromMenu = pendingFromMenu
	pendingFromMenu = false
	if type(id) ~= "string" or BUILDERS[id] == nil then
		Util.Warn(TAG, "unknown panel id: " .. tostring(id))
		return
	end
	if pickerOpen() then return end -- the full-screen pickers own the screen
	if not ensureRoot() then return end
	if id ~= currentId then
		selectedClass = nil
		selectedTarget = nil
	end
	openedFromMenu = fromMenu
	currentId = id
	root.Visible = true
	render()
end

function Panels.Close()
	currentId = nil
	currentUpdate = nil
	openedFromMenu = false
	selectedClass = nil
	selectedTarget = nil
	if root then root.Visible = false end
	clearContent()
end

function Panels.IsOpen()
	return currentId ~= nil
end

------------------------------------------------------------------ loops / wiring
local function checkVacationAuto()
	if vacationShown then return end
	if player:GetAttribute("DataLoaded") ~= true or pickerOpen() then
		pickersClosedSince = nil
		return
	end
	local t = os.clock()
	if not pickersClosedSince then
		pickersClosedSince = t
		return
	end
	if t - pickersClosedSince >= VACATION_DELAY and num("VacationDays") > 0 and currentId == nil then
		vacationShown = true
		Panels.Open("Vacation")
	end
end

local function relayoutIfVisible()
	if root and root.Visible then layoutRoot() end
end

local function hookCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cameraConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(relayoutIfVisible)
	end
end

local function hookScale()
	if scaleConn then
		scaleConn:Disconnect()
		scaleConn = nil
	end
	local gui = root and root.Parent
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	if sc then
		scaleConn = sc:GetPropertyChangedSignal("Scale"):Connect(relayoutIfVisible)
	end
end

function Panels.Init(c)
	C = c
	UIKit = c and c.UIKit
	loadTheme()
end

function Panels.Start()
	loadTheme()
	ensureRoot()
	hookCamera()
	hookScale()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

	player.AttributeChanged:Connect(function(name)
		if currentId and REBUILD_ATTRS[name] then queueRebuild() end
	end)

	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("OpenPanel").OnClientEvent:Connect(function(panelId)
				if type(panelId) == "string" then Panels.Open(panelId) end
			end)
		end)
		if not ok then Util.Warn(TAG, "OpenPanel hookup failed: " .. tostring(err)) end
	end)

	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			if currentId and currentUpdate then
				local ok, err = pcall(currentUpdate)
				if not ok then warnThrottled("update error in " .. tostring(currentId) .. ": " .. tostring(err)) end
			end
			local ok, err = pcall(checkVacationAuto)
			if not ok then warnThrottled("vacation check error: " .. tostring(err)) end
		end
	end)

	print("[Panels] started")
end

return Panels
