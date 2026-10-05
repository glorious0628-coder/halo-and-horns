-- HUD.luau : player card, war meter, status chips, quest tracker (claim / reroll / pinned tutorial), next-weapon card,
-- 자동 / 지도 / 메뉴 squares and the attack / release buttons with the charge ring, keyboard / mouse / touch / gamepad
-- input, travel bar and the guide beam (TECH_SPEC §4.23 HUD; addendum A3-H4/H5/M1, A4 step 1, A5-C6/N1, A6 Neutral,
-- A7-3 next goal, A14 compact HUD drawn with the GPT art parts of Config.UIArt through UIKit.Art*).
-- Client only: reads attributes / GameState / the Fx and Quests remotes, writes only client->server intents.
-- Published layout (logical MainGui units, updated by every layout pass; nil until the first one):
--   HUD.TopCenterX / HUD.TopCenterW : centre x and width of the war meter column (CR-L36, EventHUD's strip follows it)
--   HUD.Layout = { W, H, Scale, ClusterTop, ClusterLeft, TopCenterX, TopCenterW } : ClusterTop / ClusterLeft = top /
--   left edge of the bottom-right button cluster (CR-L37, EventHUD keeps its personal line above it)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LocalPlayer = Players.LocalPlayer

local HUD = {}

local C = nil -- client registry
local UIKit = nil
local Theme = nil

----------------------------------------------------------------- constants
local UI = Config.UI or {}
local NEXT = Config.NextGoal or {}
local TUT = Config.Tutorial or {}
local ART = type(Config.UIArt) == "table" and Config.UIArt or {} -- GPT art palette / fonts (addendum A14-3)

local TICK = 0.2
local TOP_PAD = UI.TopInsetPad or 8 -- addendum H4
local TOP_FALLBACK = UI.TopInsetFallback or 64
local JUMP_WAIT = UI.JumpButtonWait or 5 -- addendum H5
local ATTACK_FALLBACK = UI.AttackFallbackOffset or Vector2.new(-200, -170)

-- desktop (no touch) gets the compact A14-2 sizes; touch keeps thumb-sized targets (attack / release stay >= 44 real px
-- at UIScale 0.75) and the slim U5 layout. UI units (before MainGui's UIScale), grouped in one table because this chunk
-- is close to Luau's 200-locals limit.
local IS_TOUCH = UserInputService.TouchEnabled
local SHOW_KEYS = UserInputService.KeyboardEnabled and not IS_TOUCH -- U1: key badges for keyboards only
local L = {
	Attack = IS_TOUCH and 136 or 120,
	Release = IS_TOUCH and 102 or 90,
	Square = IS_TOUCH and 72 or 60, -- 자동 / 지도 / 메뉴 parchment squares
	UpgradeH = IS_TOUCH and 78 or 72, -- next-weapon card (as wide as the square row)
	BtnGap = IS_TOUCH and 12 or 10,
	RowGap = IS_TOUCH and 10 or 8, -- between the squares and above the row
	Edge = IS_TOUCH and 24 or 16,
	StatsW = IS_TOUCH and 212 or 280, -- player card
	StatsH = IS_TOUCH and 110 or 132,
	PotionH = IS_TOUCH and 64 or 50,
	StarsH = IS_TOUCH and 22 or 20, -- extra wanted-stars row (Horns)
	QuestW = IS_TOUCH and 260 or 270,
	QuestRowH = IS_TOUCH and 58 or 50,
	QuestGap = 4,
	QuestHeaderH = IS_TOUCH and 32 or 28,
	OverlayW = 340, -- touch quest overlay (CR-M25)
	WarW = 380,
	WarH = 56, -- bar row 34 + timer pills 20; EventHUD's strip follows the meter's real bottom
	StripBelow = 47, -- EventHUD's strip under the meter (gap 6 + bar 24 + sub line 13 + 4)
	ChipsY = 106, -- status chips slot, under EventHUD's strip
	ChipH = IS_TOUCH and 26 or 24,
	TouchText = 15, -- U5: 15 units = 11 real px at the 0.75 touch UIScale
	StickZoneX = 0.4, -- U3: on touch no HUD in the left 40% x bottom 45% (thumbstick)
	LuckY = 52, -- EventHUD's luck panel slot (y, height): fallback when its live "BottomY" is missing
	LuckH = 58,
	LuckW = 210, -- its width (desktop top-right), kept clear by the war meter (CR-L36)
	WarMinW = 200, -- CR-L36: narrowest war meter on small screens
	-- quest row metrics (badge / 교체 width, button and bar heights, text size)
	Row = IS_TOUCH and { Badge = 40, BadgeH = 20, Reroll = 56, BtnH = 22, Reward = 72, BarH = 18, Text = 15 }
		or { Badge = 30, BadgeH = 15, Reroll = 40, BtnH = 18, Reward = 58, BarH = 15, Text = 13 },
}

-- code-drawn fallback colours (IMG-R4) and ImageColor3 multipliers for the art parts
local COL = {
	Dark = Color3.fromRGB(30, 25, 10),
	Grey = Color3.fromRGB(150, 150, 160),
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
	AttackFill = Color3.fromRGB(215, 70, 60),
	ReleaseFill = Color3.fromRGB(28, 30, 48),
	WarFill = Color3.fromRGB(12, 12, 20),
	RingIdle = Color3.fromRGB(130, 140, 175),
	Charge = Color3.fromRGB(90, 200, 255),
	HotTint = Color3.new(0.5, 1, 0.72), -- parchment / ribbon -> green: claimable, 받기, 자동 ON
	RowHotTint = Color3.fromRGB(205, 255, 200),
	LockedTint = Color3.fromRGB(190, 186, 176),
	DimTint = Color3.fromRGB(170, 170, 170),
}

-- quest Id -> icon part (slime for monster kills, scroll otherwise)
local QUEST_ICON = { tutorial = "IconSlime", Kill = "IconSlime", Golden = "IconSlime", Goose = "IconGoose" }

local GUIDE_SECONDS = NEXT.GuideSeconds or 90
local GUIDE_ZONES = NEXT.GuideZones or { "GoblinWoods", "SkeletonRuins" }
local TUT_GUIDE_STEP = (type(TUT.Steps) == "table" and TUT.Steps.Guide) or 1
local TUT_GUIDE_ZONE = TUT.GuideZone or "SlimeMeadow"
local TUT_GUIDE_TEXT = TUT.GuideText or "여기로!"
local TUT_QUEST_ID = TUT.QuestId or "tutorial"

-- HUD display strings (the literals of TECH_SPEC §4.23 HUD; game messages come from Config.Text)
local TXT = {
	LevelTag = "Lv",
	Money = '<font color="#%s">%s</font> %s', -- RichText: grey tag + gold number
	BankTag = "금고",
	CarriedTag = "주머니",
	Bounty = " 현상금 %s",
	WarTime = "왕관 결정까지 %s",
	Siege = "몬스터 포위전: 1인당 %d점",
	MyWar = "내 점수 %s",
	Blessing = "%s 왕관 축복 +%d%%",
	Safe = "안전 지대",
	PvP = "PvP 지역",
	PvPNeutral = "PvP 지역 · 장인은 안전",
	Rookie = "새싹 보호중",
	RookieGrace = "새싹 졸업 · %d초 뒤 대결", -- A23-18 graduation grace (GraduateGraceUntil)
	Protected = "부활 보호",
	InCombat = "전투 중",
	Size = "덩치 저울 ×%.2f",
	Bully = "깡패 %d단계",
	KaijuQueued = "괴수 대기 중",
	QuestHeader = "오늘의 퀘스트 (%d/%d)",
	QuestAllDone = "오늘 일일 완료! 추가 퀘스트 진행 중",
	QuestClaimable = " · 받기 %d",
	QuestTouchClaim = "퀘스트 받기 %d개!",
	QuestTouchLine = "%s/%s %s", -- progress first: truncation only cuts the quest text
	QuestExpand = "▼",
	QuestCollapse = "▲",
	QuestClose = "닫기",
	BadgeDaily = "일일",
	BadgeExtra = "추가",
	BadgePinned = "안내",
	BadgeMain = "메인",
	BadgeSub = "선택",
	Claim = "받기",
	Reroll = "교체", -- Gotham has no ↻ glyph (rendered as tofu)
	RerollTitle = "퀘스트 바꾸기", -- CR-M25 confirm dialog
	RerollBody = "진행도가 사라져요. 바꿀까요?",
	RerollYes = "바꾸기",
	Attack = "공격",
	Release = "스킬",
	ReleaseCost = "MP%d",
	Perfect = "PERFECT!",
	AutoOn = "자동 켬",
	AutoOff = "자동 끔",
	UpgradeNext = "다음: %s",
	UpgradePrice = "%sG",
	UpgradeMax = "기본 무기 준비 완료",
	UpgradeNeedLevel = "Lv %d 필요",
	UpgradeNeedFaction = "진영 선택 필요",
	UpgradeReady = "대장간에서 구입 · 길 안내",
	Map = "지도",
	Menu = "메뉴",
	TravelLeft = "%s %.1f초",
	ZoneGuide = "%s!",
	Monster = "몬스터",
}

----------------------------------------------------------------- state
local ui = {}
local jumpButton = nil
local jumpConns = {}
local layoutPending = false

local holdSources = {} -- [source] = true; source = "mouse" | "keyF" | "padR2" | InputObject (button press)
local holdToken = 0
local lastAction = {}

local prevLevel = nil
local levelBaselineReady = false

local menuGlowOn = nil
local menuGlowTween = nil

local questRows = {}
local questExpanded = false -- collapsed list shows the header + one row
-- CR-M24: 교체 is ignored for ClaimLock s after a claim and a row for RowLock s after its quest changed;
-- CR-M25: touch opens the rows' overlay from the header (OverlayOpen);
-- CR-L50: Data = the last quest list from the "Quests" remote, Started = HUD.Start ran (rows may refresh)
-- B15: StoryKey = "id|St" of the story page Panels holds back (fight / other window), CallEntry = its quest entry,
-- Pulse = the gentle gold pulse on that row (touch: on the header line)
local questState = { ClaimAt = -math.huge, ClaimLock = 1.5, RowLock = 0.8, OverlayOpen = false, Data = nil,
	Started = false, StoryKey = "", CallEntry = nil, Pulse = { Target = nil, Stroke = nil, Tween = nil } }
local guide = nil -- { Tag, Part, Att0, Att1, Beam, Billboard, Tween }
local guideAnchors = {}

local tickCount = 0
local lastWarnAt = -math.huge

----------------------------------------------------------------- small helpers
local function warnThrottled(msg)
	local now = os.clock()
	if now - lastWarnAt < 10 then return end
	lastWarnAt = now
	Util.Warn("HUD", msg)
end

local function attr(name, default)
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function num(name, default)
	local v = tonumber(attr(name, default))
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return default end
	return v
end

local function getFaction()
	local f = attr("Faction", "None")
	if type(f) ~= "string" or f == "" then return "None" end
	return f
end

local function getClass()
	local c = attr("Class", "Warrior")
	if type(c) ~= "string" or not Config.Classes[c] then return "Warrior" end
	return c
end

local function factionDef(f)
	return Config.Factions[f] or Config.Factions.None
end

local function factionColor(f)
	local d = Config.Factions[f]
	if type(d) == "table" and typeof(d.Color) == "Color3" then return d.Color end
	if f == "Neutral" and typeof(Theme.Neutral) == "Color3" then return Theme.Neutral end -- A9-1: Config teal via UIKit.Theme
	return Theme.SubText
end

local function fmtNum(n)
	return Util.FormatNumber(n)
end

-- Config.Text[key] through string.format, with a private fallback template
local function textOr(key, fallback, ...)
	local template = Config.Text[key]
	if type(template) ~= "string" then template = fallback end
	local ok, out = pcall(string.format, template, ...)
	if ok then return out end
	return template
end

-- true = called again within `interval` (skip); false = allowed (and recorded)
local function throttled(key, interval)
	local now = os.clock()
	local last = lastAction[key]
	if last and now - last < interval then return true end
	lastAction[key] = now
	return false
end

local function remote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local r = folder and folder:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then return r end
	return nil
end

-- never yields (input handlers must not block)
local function fire(name, ...)
	local r = remote(name)
	if r then
		r:FireServer(...)
	else
		warnThrottled("remote missing: " .. tostring(name))
	end
end

local function playSound(name)
	local fx = C and C.Fx
	if fx and type(fx.PlaySound) == "function" then
		pcall(fx.PlaySound, name)
	end
end

local function pickersOpen()
	for _, name in { "Intro", "FactionPicker", "ClassPicker" } do
		local m = C and C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			if ok and open then return true end
		end
	end
	return false
end

local function currentScale()
	local gui = UIKit and UIKit.Gui
	local s = gui and gui:FindFirstChildOfClass("UIScale")
	local v = s and s.Scale or 1
	if v <= 0 then v = 1 end
	return v
end

-- top bar inset in real pixels; fallback keeps blocks at >= TopInsetFallback px (addendum H4)
local function insetY()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local y = (ok and typeof(topLeft) == "Vector2") and topLeft.Y or 0
	if y <= 0 then y = TOP_FALLBACK - TOP_PAD end
	return y
end

-- bottom (real px) of the TextChatService chat window + input bar when shown over the top-left block, else nil.
-- Everything is pcall'd: older clients lack the configurations' AbsolutePosition / AbsoluteSize.
local CHAT_CONFIGS = { "ChatWindowConfiguration", "ChatInputBarConfiguration" }
local function chatWindowBottom(inset, s, screenH)
	local active = true
	pcall(function()
		active = StarterGui:GetCore("ChatActive") ~= false
	end)
	if not active then return nil end
	local okVersion, isTcs = pcall(function()
		return TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
	end)
	if not okVersion or not isTcs then return nil end
	local top, bottom = nil, nil
	for _, className in CHAT_CONFIGS do
		local ok, t, b = pcall(function()
			local cfg = TextChatService:FindFirstChildOfClass(className)
			if not cfg or not cfg.Enabled then return nil, nil end
			local pos, size = cfg.AbsolutePosition, cfg.AbsoluteSize
			if size.X < 1 or size.Y < 1 then return nil, nil end
			if pos.X > (12 + math.max(L.StatsW, L.QuestW)) * s then return nil, nil end -- not on the left side
			return pos.Y, pos.Y + size.Y
		end)
		if ok and type(t) == "number" and type(b) == "number" then
			if top == nil or t < top then top = t end
			if bottom == nil or b > bottom then bottom = b end
		end
	end
	if not bottom or not top then return nil end
	if top < inset - 4 then bottom += inset end -- positions measured from below the top bar
	if bottom > screenH * 0.55 then return nil end -- chat moved / very tall: keep the HUD where it is
	return bottom
end

-- desktop: legacy chat sits top-left over the stats block; move its window to the bottom-left instead.
-- SetCore throws until the chat CoreScript has registered it, so retry for a while. TextChatService places
-- its own window through ChatWindowConfiguration (VerticalAlignment = Bottom in the place file).
local LEGACY_CHAT_POS = UDim2.new(0, 0, 0.6, 0)
local function placeLegacyChat()
	if IS_TOUCH then return end
	local okVersion, isLegacy = pcall(function()
		return TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
	end)
	if not okVersion or not isLegacy then return end
	for _ = 1, 20 do
		if pcall(StarterGui.SetCore, StarterGui, "ChatWindowPosition", LEGACY_CHAT_POS) then return end
		task.wait(0.5)
	end
end

-- Korean directional particle: "고블린 숲" -> "고블린 숲으로", "마을" -> "마을로"
local function withRo(word)
	local last = nil
	local ok = pcall(function()
		for _, cp in utf8.codes(word) do
			last = cp
		end
	end)
	if ok and last and last >= 0xAC00 and last <= 0xD7A3 then
		local jong = (last - 0xAC00) % 28
		if jong == 0 or jong == 8 then return word .. "로" end
		return word .. "으로"
	end
	return word .. "(으)로"
end

-- false when the text has a symbol Gotham / the Korean fallback font lacks (⚙ ⚔ ↻ render as tofu boxes);
-- CR-L44: the shared Util.GlyphSafe (missing = unsafe, so the emblem is just left out)
local function glyphSafe(text)
	return type(Util.GlyphSafe) == "function" and Util.GlyphSafe(text) == true
end

-- Config.UIArt.Colors[key] / Fonts[key] with a fallback (the art table may be missing)
local function ac(key, fallback)
	local c = type(ART.Colors) == "table" and ART.Colors[key] or nil
	if typeof(c) == "Color3" then return c end
	return fallback
end

local function af(key, fallback)
	local f = type(ART.Fonts) == "table" and ART.Fonts[key] or nil
	if typeof(f) == "EnumItem" then return f end
	return fallback
end

local function corner(radius)
	return UIKit.Create("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

-- U5: on touch every HUD text stays >= 11 real px = L.TouchText units at the 0.75 touch UIScale
local function touchFloor(label)
	if not IS_TOUCH or not label then return label end
	local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
	if tc then
		tc.MaxTextSize = math.max(tc.MaxTextSize, L.TouchText) -- raise the cap first: min must stay <= max
		tc.MinTextSize = L.TouchText
	end
	if label.TextSize < L.TouchText then label.TextSize = L.TouchText end
	return label
end

-- Keep approved HUD art and the active UIKit font family. Caps are physical pixels, so a large GUI scale
-- cannot turn small HUD captions into oversized letters. Table members avoid adding chunk locals (200 limit).
function L.FitText(label, pixels, bold)
	if not label then return label end
	ui.textFits = ui.textFits or setmetatable({}, { __mode = "k" })
	local fit = ui.textFits[label]
	if not fit then
		fit = { Truncate = label.TextTruncate, Connections = {} }
		ui.textFits[label] = fit
		fit.Apply = function()
			if not label.Parent then return end
			local s = currentScale()
			local minSize = math.max(1, math.min(11, math.floor(11 / s)))
			local maxSize = math.max(minSize, math.floor(fit.Pixels / s))
			if fit.Min == minSize and fit.Max == maxSize then return end
			fit.Min, fit.Max = minSize, maxSize
			local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
			if tc then tc.MaxTextSize = 100; tc.MinTextSize = minSize; tc.MaxTextSize = maxSize end
			if label.AutomaticSize == Enum.AutomaticSize.X or label.AutomaticSize == Enum.AutomaticSize.XY then
				-- Auto-width pills follow their text; fitting against their previous width would shrink every update.
				label.TextScaled = false
				label.TextSize = maxSize
			else
				UIKit.FitText(label, minSize, maxSize)
			end
			label.TextTruncate = fit.Truncate
		end
		table.insert(fit.Connections, label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit.Apply))
		table.insert(fit.Connections, label.Destroying:Connect(function()
			for _, connection in fit.Connections do connection:Disconnect() end
			ui.textFits[label] = nil
		end))
	end
	fit.Pixels = pixels or 12
	UIKit.ApplyFont(label, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
	label.TextWrapped = false
	label.TextStrokeTransparency = 1
	label:SetAttribute("PickerMeasureWhole", label.RichText ~= true)
	local outline = label:FindFirstChild("Outline")
	if outline and outline:IsA("UIStroke") then outline.Thickness = 0.4; outline.Transparency = 0.65 end
	label:SetAttribute("PickerOutlineThickness", 0.4)
	fit.Apply()
	return label
end
HUD.FitText = L.FitText

-- UIKit.InkText (brown ink on parchment) or UIKit.LightText (white / gold on navy, bars, round buttons) + touch floor
local function artLabel(ink, props)
	if IS_TOUCH then
		if type(props.TextSize) == "number" then props.TextSize = math.max(props.TextSize, L.TouchText) end
		if type(props.MaxTextSize) == "number" then props.MaxTextSize = math.max(props.MaxTextSize, L.TouchText) end
	end
	local label = nil
	if ink then
		label = UIKit.InkText(props)
	else
		label = UIKit.LightText(props)
	end
	UIKit.ApplyFont(label, props.Title and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
	local outline = label:FindFirstChild("Outline")
	if outline and outline:IsA("UIStroke") then outline.Thickness = 0.4; outline.Transparency = 0.65 end
	return L.FitText(touchFloor(label), props.Title and 13 or 12, props.Title)
end

local function isImage(obj)
	return typeof(obj) == "Instance" and (obj:IsA("ImageLabel") or obj:IsA("ImageButton"))
end

-- art parts tint through ImageColor3 (multiply); their code-drawn fallbacks (IMG-R4) take `fill` as background
local function paint(obj, tint, fill)
	if isImage(obj) then
		obj.ImageColor3 = tint
	elseif typeof(obj) == "Instance" and fill then
		obj.BackgroundColor3 = fill
	end
end

-- disabled / waiting look: faded art, or a more transparent fallback (normalT = its usual transparency)
local function setDim(obj, dim, normalT)
	if isImage(obj) then
		obj.ImageTransparency = dim and 0.4 or 0
	elseif typeof(obj) == "Instance" then
		obj.BackgroundTransparency = dim and 0.5 or (normalT or 0)
	end
end

-- gold ring just outside a button (affordable pulse / menu hint), hidden until used; returns its UIStroke
local function makeGlow(parent, radius)
	local frame = UIKit.Create("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 4, 1, 4),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = parent,
	}, {
		corner(radius),
		UIKit.Create("UIStroke", {
			Name = "GlowStroke",
			Color = ac("Gold", Theme.Gold),
			Thickness = 3,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	return frame:FindFirstChild("GlowStroke")
end

local function pressScale(btn, down)
	local sc = btn and btn:FindFirstChild("PressScale")
	if sc then
		TweenService:Create(sc, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = down and 0.92 or 1,
		}):Play()
	end
end

local function isPressInput(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

----------------------------------------------------------------- layout (forward-declared users)
local applyLayout -- assigned below
local refreshQuests -- assigned with the quest rows (the header toggle calls it)
local toggleQuests -- assigned with the quest rows (header / overlay close button)

local function requestLayout()
	if layoutPending then return end
	layoutPending = true
	task.defer(function()
		layoutPending = false
		local ok, err = pcall(applyLayout)
		if not ok then warnThrottled("layout error: " .. tostring(err)) end
	end)
end

----------------------------------------------------------------- building: player card (top-left)
-- money line: coin / pouch icon + "금고 1,250" (grey tag, gold number through RichText)
local function moneyLine(parent, name, icon, x, y, w)
	local h = IS_TOUCH and 20 or 18
	local img = UIKit.ArtImage(icon, {
		Name = name .. "Icon",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(h, h),
		Parent = parent,
	})
	local tx = img and (x + h + 3) or x
	return L.FitText(artLabel(false, {
		Name = name,
		RichText = true,
		Position = UDim2.fromOffset(tx, y),
		Size = UDim2.fromOffset(x + w - tx, h),
		TextScaled = true,
		MaxTextSize = IS_TOUCH and 16 or 14,
		Color = ac("GoldText", Theme.Gold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	}), 12)
end

-- PanelCard (gold rim, navy inside). Desktop: portrait ring + live-character 3D snapshot, level badge, title / class, XP
-- bar, 금고 / 주머니. Touch (U5): level badge + XP bar + 금고 only. Horns get a wanted-stars / bounty row on both.
local function buildStats(root)
	local W = L.StatsW
	local f = UIKit.ArtFrame("PanelCard", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12 + TOP_FALLBACK),
		Size = UDim2.fromOffset(W, L.StatsH),
		Parent = root,
	})
	ui.stats = f

	-- level badge: navy disc with a gold ring
	local bs = IS_TOUCH and 48 or 40
	local badge = UIKit.ArtFrame("LevelBadge", {
		Name = "LevelBadge",
		Position = UDim2.fromOffset(IS_TOUCH and 8 or 80, IS_TOUCH and 10 or 5),
		Size = UDim2.fromOffset(bs, bs),
		ZIndex = 3,
		Parent = f,
	}, { StrokeThickness = 2 })
	local facePos, faceSize = UIKit.ArtInner("LevelBadge")
	local face = UIKit.Create("Frame", {
		Name = "Face",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = facePos or UDim2.fromScale(0.17, 0.18),
		Size = faceSize or UDim2.fromScale(0.65, 0.61),
		Parent = badge,
	})
	ui.levelFace = face
	if IS_TOUCH then
		-- the number alone: a separate "Lv" would fall under the touch text floor inside the badge
		ui.level = artLabel(false, {
			Name = "Level",
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			MaxTextSize = 26,
			Number = true,
			Color = ac("GoldText", Theme.Gold),
			Text = "1",
			Parent = face,
		})
	else
		ui.levelTag = artLabel(false, {
			Name = "Tag",
			Position = UDim2.fromScale(0, 0.03),
			Size = UDim2.fromScale(1, 0.39),
			TextScaled = true,
			MaxTextSize = 11,
			Number = true,
			Text = TXT.LevelTag,
			Parent = face,
		})
		ui.level = artLabel(false, {
			Name = "Level",
			Position = UDim2.fromScale(0, 0.47),
			Size = UDim2.fromScale(1, 0.5),
			TextScaled = true,
			MaxTextSize = 20,
			Number = true,
			Color = ac("GoldText", Theme.Gold),
			Text = "1",
			Parent = face,
		})
	end
	L.FitText(ui.levelTag, 11)
	L.FitText(ui.level, IS_TOUCH and 16 or 14, true)

	local x0 = IS_TOUCH and 62 or 80 -- left edge of the XP bar / money column
	if not IS_TOUCH then
		-- The current character is rendered in this same ring; the account thumbnail only covers loading gaps.
		local holder = UIKit.Create("Frame", {
			Name = "Portrait",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(3, 5),
			Size = UDim2.fromOffset(74, 76),
			ZIndex = 2,
			Parent = f,
		})
		local holePos, holeSize = UIKit.ArtInner("PortraitRing")
		local head = UIKit.Create("ImageLabel", {
			Name = "Headshot",
			Image = UIKit.HeadshotImage(),
			ScaleType = Enum.ScaleType.Crop,
			BackgroundColor3 = ac("NavyDeep", Theme.Bg),
			Position = holePos or UDim2.fromScale(0.14, 0.2),
			Size = holeSize or UDim2.fromScale(0.72, 0.67),
			ZIndex = 1,
			Parent = holder,
		}, { corner(UDim.new(0.5, 0)) })
		ui.portraitHolder = holder
		ui.portraitHeadshot = head
		local ring = UIKit.ArtImage("PortraitRing", {
			Name = "Ring",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = holder,
		})
		if not ring then
			-- IMG-R4: gold ring drawn in code
			UIKit.Create("UIStroke", {
				Color = ac("Gold", Theme.Gold),
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = head,
			})
		end
		ui.title = artLabel(false, {
			Name = "Title",
			Position = UDim2.fromOffset(126, 10),
			Size = UDim2.fromOffset(W - 138, 18),
			TextSize = 16,
			Title = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = f,
		})
		ui.class = artLabel(false, {
			Name = "Class",
			Position = UDim2.fromOffset(126, 29),
			Size = UDim2.fromOffset(W - 138, 14),
			TextSize = 12,
			Color = ac("LightSub", Theme.SubText),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = f,
		})
		L.FitText(ui.title, 13, true)
		L.FitText(ui.class, 12)
	end

	-- XP bar on the BarTrack art (bright blue fill)
	local barW = W - x0 - (IS_TOUCH and 14 or 12)
	local xpFrame, setXP, xpText = UIKit.ArtBar({
		Name = "XPBar",
		Position = UDim2.fromOffset(x0, IS_TOUCH and 13 or 48),
		Size = UDim2.fromOffset(barW, IS_TOUCH and 20 or 16),
		Color = ac("XPBlue", Theme.XP),
		TextSize = IS_TOUCH and L.TouchText or 12,
		Parent = f,
	})
	ui.setXP = setXP
	ui.xpFrame = xpFrame
	ui.xpText = xpText
	L.FitText(ui.xpText, 11)

	if IS_TOUCH then
		ui.bank = moneyLine(f, "Bank", "IconCoin", x0, 78, barW)
	else
		local half = math.floor((barW - 6) / 2)
		ui.bank = moneyLine(f, "Bank", "IconCoin", x0, 104, half)
		ui.carried = moneyLine(f, "Carried", "IconPouch", x0 + half + 6, 104, barW - half - 6)
	end
	C.VitalsUI.BuildStats(f, x0, barW, IS_TOUCH)
	ui.potions = C.VitalsUI.BuildPotions(root, W, L.PotionH, IS_TOUCH)

	-- Horns: wanted stars (IconStar / IconStarEmpty; ★☆ text without the art) + bounty, under the card's rows
	local sh = L.StarsH - 4
	ui.stars = UIKit.Create("Frame", {
		Name = "Stars",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(IS_TOUCH and 12 or 14, L.StatsH - 12),
		Size = UDim2.fromOffset(W - 28, sh),
		Visible = false,
		Parent = f,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})
	ui.starImgs = {}
	local starId, emptyId = UIKit.ArtId("IconStar"), UIKit.ArtId("IconStarEmpty")
	if starId and emptyId then
		ui.starIds = { starId, emptyId }
		for i = 1, math.max(1, math.floor(tonumber(Config.PvP.MaxStars) or 5)) do
			ui.starImgs[i] = UIKit.Create("ImageLabel", {
				Name = "Star" .. i,
				LayoutOrder = i,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = emptyId,
				Size = UDim2.fromOffset(sh, sh),
				Parent = ui.stars,
			})
		end
	end
	ui.bounty = artLabel(false, {
		Name = "Bounty",
		LayoutOrder = 100,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextSize = 13,
		Color = Theme.Bad,
		Parent = ui.stars,
	})
	L.FitText(ui.bounty, 12)
end

function L.LayoutStats(s)
	local textH = math.ceil(12 / s)
	local barH = math.max(IS_TOUCH and 20 or 16, textH)
	local vitalH = math.max(IS_TOUCH and 18 or 16, textH)
	local xpY = IS_TOUCH and 13 or 48
	if ui.title then
		local titleH = math.max(18, math.ceil(14 / s))
		local classH = math.max(14, textH)
		local classY = math.max(29, 10 + titleH + 2)
		ui.title.Size = UDim2.fromOffset(L.StatsW - 138, titleH)
		ui.class.Position = UDim2.fromOffset(126, classY)
		ui.class.Size = UDim2.fromOffset(L.StatsW - 138, classH)
		xpY = math.max(xpY, classY + classH + 4)
	end
	if ui.levelTag then
		-- A tiny badge can hold one readable line. Its original touch fallback already shows just the number.
		local faceH = ui.levelFace.Size.Y.Scale * ui.levelFace.Parent.Size.Y.Offset * s
		local split = faceH >= 29.5
		ui.levelTag.Visible = split
		ui.level.Position = split and UDim2.fromScale(0, 0.47) or UDim2.fromScale(0, 0)
		ui.level.Size = split and UDim2.fromScale(1, 0.5) or UDim2.fromScale(1, 1)
	end
	ui.xpFrame.Position = UDim2.fromOffset(IS_TOUCH and 62 or 80, xpY)
	ui.xpFrame.Size = UDim2.fromOffset(ui.xpFrame.Size.X.Offset, barH)
	local hpY = xpY + barH + (IS_TOUCH and 3 or 2)
	C.VitalsUI.LayoutStats(hpY, vitalH, 2)
	local moneyY = hpY + vitalH * 2 + 6
	local moneyH = math.max(IS_TOUCH and 20 or 18, textH)
	for _, label in { ui.bank, ui.carried } do
		label.Position = UDim2.fromOffset(label.Position.X.Offset, moneyY)
		label.Size = UDim2.fromOffset(label.Size.X.Offset, moneyH)
	end
	for _, name in { "BankIcon", "CarriedIcon" } do
		local icon = ui.stats:FindFirstChild(name)
		if icon then icon.Position = UDim2.fromOffset(icon.Position.X.Offset, moneyY) end
	end
	ui.statsBaseH = math.max(L.StatsH, moneyY + moneyH + 10)
	ui.stats.Size = UDim2.fromOffset(L.StatsW, ui.statsBaseH + (getFaction() == "Horns" and L.StarsH or 0))
	ui.stars.Position = UDim2.fromOffset(IS_TOUCH and 12 or 14, ui.statsBaseH - 8)
end

----------------------------------------------------------------- building: war meter (top center)
-- round timer / siege / my-points pill (Pill art, ink text, sized to its text)
local function infoPill(name, order, parent, color)
	local pill = UIKit.ArtFrame("Pill", {
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		Parent = parent,
	}, { CornerRadius = UDim.new(0.5, 0) }, {
		UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	local props = {
		Name = "Text",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextSize = 14,
		Parent = pill,
	}
	if color then props.Color = color end
	return pill, artLabel(true, props)
end

-- gold 빛 fill from the left and crimson 뿔 fill from the right inside the BarTrack capsule, faction shields over both
-- ends, the crown riding the split, info pills under it. 56 units tall (EventHUD's strip sits under its real bottom).
local function buildWar(root)
	local W = L.WarW
	local w = UIKit.Create("Frame", {
		Name = "WarMeter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8 + TOP_FALLBACK),
		Size = UDim2.fromOffset(W, L.WarH),
		BackgroundTransparency = 1,
		Parent = root,
	})
	ui.war = w
	local shieldW, barY, barH = 30, 10, 22
	-- Bar / Info follow the meter's width: applyLayout narrows it on small screens (CR-L36)
	local bar, barArt = UIKit.ArtFrame("BarTrack", {
		Name = "Bar",
		Position = UDim2.fromOffset(shieldW - 10, barY),
		Size = UDim2.new(1, -2 * (shieldW - 10), 0, barH),
		Parent = w,
	}, {
		Color = COL.WarFill,
		BackgroundTransparency = 0.15,
		CornerRadius = UDim.new(0.5, 0),
		StrokeColor = COL.Black,
		StrokeTransparency = 0.4,
	})
	-- fills live in the capsule's navy interior (BarTrack Inner rect; its edges follow the height)
	local top, bottom, side = 0, 0, 0
	local def = barArt and UIKit.ArtPart("BarTrack") or nil
	if def and typeof(def.Inner) == "Rect" and typeof(def.Size) == "Vector2" and def.Size.Y > 0 then
		top = def.Inner.Min.Y / def.Size.Y
		bottom = (def.Size.Y - def.Inner.Max.Y) / def.Size.Y
		side = math.floor(def.Inner.Min.X / def.Size.Y * barH + 0.5)
	end
	local inner = UIKit.Create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, side, top, 0),
		Size = UDim2.new(1, -2 * side, 1 - top - bottom, 0),
		Parent = bar,
	})
	local function fill(name, color, fromRight)
		return UIKit.Create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(fromRight and 1 or 0, 0),
			Position = UDim2.fromScale(fromRight and 1 or 0, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundColor3 = color,
			Parent = inner,
		}, {
			corner(UDim.new(0.5, 0)),
			UIKit.Create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(COL.White, Color3.fromRGB(205, 205, 205)),
			}),
		})
	end
	ui.haloFill = fill("HaloFill", ac("WarHalo", Theme.Halo), false)
	ui.hornsFill = fill("HornsFill", ac("WarHorns", Theme.Horns), true)
	ui.warDivider = UIKit.Create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 3, 1, 4),
		BackgroundColor3 = Color3.fromRGB(255, 248, 225),
		ZIndex = 2,
		Parent = inner,
	}, { corner(UDim.new(0, 2)) })
	-- crown on the split, its base at the bar's middle
	ui.warCrown = UIKit.ArtImage("Crown", {
		Name = "Crown",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(27, 18),
		ZIndex = 3,
		Parent = inner,
	})
	ui.haloNum = artLabel(false, {
		Name = "HaloScore",
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0.5, -20, 1, 0),
		TextSize = 15,
		Number = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = bar,
	})
	ui.hornsNum = artLabel(false, {
		Name = "HornsScore",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0.5, -20, 1, 0),
		TextSize = 15,
		Number = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = bar,
	})
	-- faction shields over both ends of the bar
	for _, s in { { "ShieldHalo", 0 }, { "ShieldHorns", 1 } } do
		UIKit.ArtImage(s[1], {
			Name = s[1],
			AnchorPoint = Vector2.new(s[2], 0),
			Position = UDim2.new(s[2], 0, 0, 3),
			Size = UDim2.fromOffset(shieldW, shieldW + 1),
			ZIndex = 3,
			Parent = w,
		})
	end

	local row = UIKit.Create("Frame", {
		Name = "Info",
		Position = UDim2.fromOffset(0, barY + barH + 4),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = w,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	ui.warTimePill, ui.warTime = infoPill("Time", 1, row, nil)
	ui.warSiege, ui.warSiegeText = infoPill("Siege", 2, row, ac("BadInk", Theme.Revenge))
	ui.warSiege.Visible = false
	ui.warPoints, ui.warPointsText = infoPill("MyPoints", 3, row, nil)
end

----------------------------------------------------------------- building: status chips
-- candy pill (fill + inked rim + dark text) with an optional art icon (안전 지대 IconSafe, 새싹 IconSprout, 축복 Crown)
local function makeChip(name, order, icon)
	local frame = UIKit.Create("Frame", {
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, L.ChipH),
		BackgroundColor3 = Theme.Bg,
		Visible = false,
		Parent = ui.chips,
	}, {
		corner(UDim.new(0.5, 0)),
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		UIKit.Create("UIStroke", {
			Name = "Stroke",
			Thickness = 2,
			Color = Theme.SubText,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIKit.Create("UIGradient", { -- glossy candy shading
			Rotation = 90,
			Color = ColorSequence.new(COL.White, Color3.fromRGB(222, 222, 222)),
		}),
	})
	local chip = { Frame = frame, Stroke = frame:FindFirstChild("Stroke") }
	if icon then
		chip.Icon = UIKit.ArtImage(icon, {
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(L.ChipH - 2, L.ChipH - 2),
			Visible = false,
			Parent = frame,
		})
	end
	chip.Pad = UIKit.Create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = frame,
	})
	chip.Label = artLabel(true, {
		Name = "Text",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextSize = 13,
		Outline = false,
		Parent = frame,
	})
	return chip
end

-- palette = { fill, rim, text } (the art's chip colours) or nil = derived from `color` (bright = solid fill)
local function setChip(chip, visible, text, color, bright, palette, withIcon)
	if not chip then return end
	chip.Frame.Visible = visible == true
	if not visible then return end
	color = color or Theme.SubText
	local fill, rim, ink
	if palette then
		fill, rim, ink = palette[1], palette[2], palette[3]
	elseif bright then
		fill, rim, ink = color, color:Lerp(COL.Black, 0.45), COL.Dark
	else
		fill, rim, ink = color:Lerp(COL.White, 0.7), color:Lerp(COL.Black, 0.3), color:Lerp(COL.Black, 0.62)
	end
	chip.Frame.BackgroundColor3 = fill
	if chip.Stroke then chip.Stroke.Color = rim end
	chip.Label.TextColor3 = ink
	chip.Label.Text = text or ""
	local iconOn = withIcon == true and chip.Icon ~= nil
	if chip.Icon then chip.Icon.Visible = iconOn end
	chip.Pad.PaddingLeft = UDim.new(0, iconOn and 4 or 10)
end

local function buildChips(root)
	-- applyLayout sets the width (CR-L36: the war meter column); a full row wraps and the frame grows downwards
	ui.chips = UIKit.Create("Frame", {
		Name = "StatusChips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, L.ChipsY + TOP_FALLBACK),
		Size = UDim2.fromOffset(900, L.ChipH + 6),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	})
	local chipList = UIKit.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = ui.chips,
	})
	pcall(function()
		chipList.Wraps = true -- older clients lack it: the row just overflows sideways as before
	end)
	ui.chipPal = {
		Safe = { ac("ChipSafe", Theme.Good), ac("ChipSafeRim", Theme.Good), ac("ChipSafeText", COL.Dark) },
		Rookie = { ac("ChipRookie", Theme.XP), ac("ChipRookieRim", Theme.XP), ac("ChipRookieText", COL.Dark) },
	}
	local icons = { Blessing = "Crown", Zone = "IconSafe", Rookie = "IconSprout" }
	ui.chip = {}
	for i, key in { "Blessing", "Zone", "Rookie", "Protected", "Combat", "Size", "Bully", "Kaiju" } do
		ui.chip[key] = makeChip(key, i, icons[key])
	end
end

----------------------------------------------------------------- building: quests
-- ribbon header (star + "오늘의 퀘스트 (1/3)" + 받기 N + chevron) over parchment rows. Desktop: the header toggles the
-- list (collapsed = header + one row, A14-2). Touch (U5 / CR-M25): one line only; the rows with 받기 / 교체 live in an
-- overlay opened from the header, placed right of the thumbstick zone.
local function buildQuests(root)
	ui.quests = UIKit.Create("Frame", {
		Name = "Quests",
		Position = UDim2.fromOffset(12, 200 + TOP_FALLBACK),
		Size = UDim2.fromOffset(L.QuestW, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, L.QuestGap),
		}),
	})
	local hh = L.QuestHeaderH
	ui.questHeader = UIKit.ArtButton("RibbonHeader", {
		Name = "Header",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(L.QuestW, hh),
		Parent = ui.quests,
	}, function()
		-- B15: on touch the header line reads "…말을 걸어요 — 눌러서 보기" while a story waits: one tap opens it
		if IS_TOUCH and questState.CallEntry and L.PinnedTap then
			L.PinnedTap(questState.CallEntry)
			return
		end
		toggleQuests()
	end, { CornerRadius = UDim.new(0, 10) })
	local is = hh - 8
	local star = UIKit.ArtImage("IconStar", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(is, is),
		Parent = ui.questHeader,
	})
	local tx = star and (is + 13) or 10
	ui.questHeaderText = artLabel(true, {
		Name = "Text",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, tx, 0.5, 0),
		Size = UDim2.new(1, -tx - 26, 1, -8),
		TextScaled = true,
		MaxTextSize = 14,
		Title = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = ui.questHeader,
	})
	ui.questChevron = artLabel(true, {
		Name = "Chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(16, is),
		TextScaled = true,
		MaxTextSize = 14,
		Text = TXT.QuestExpand,
		Parent = ui.questHeader,
	})
	L.FitText(ui.questHeaderText, 13, true)
	L.FitText(ui.questChevron, 11)

	local listParent = ui.quests
	ui.questRowW = L.QuestW
	if IS_TOUCH then
		local pad = 10
		ui.questRowW = L.OverlayW - 2 * pad
		ui.questOverlay = UIKit.ArtFrame("PanelParchment", {
			Name = "QuestOverlay",
			Size = UDim2.fromOffset(L.OverlayW, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 20,
			Parent = root,
		}, nil, {
			UIKit.Create("UIPadding", {
				PaddingLeft = UDim.new(0, pad),
				PaddingRight = UDim.new(0, pad),
				PaddingTop = UDim.new(0, pad),
				PaddingBottom = UDim.new(0, pad + 2),
			}),
			UIKit.Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		})
		local top = UIKit.Create("Frame", {
			Name = "Top",
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Parent = ui.questOverlay,
		})
		ui.questOverlayTitle = artLabel(true, {
			Name = "Title",
			Size = UDim2.new(1, -80, 1, 0),
			TextScaled = true,
			MaxTextSize = 17,
			Title = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = top,
		})
		local _, closeLabel = UIKit.ArtButton("Pill", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(72, 30),
			Text = TXT.QuestClose,
			TextSize = 16,
			Parent = top,
		}, function()
			toggleQuests(false)
		end, { CornerRadius = UDim.new(0.5, 0) })
		L.FitText(ui.questOverlayTitle, 13, true)
		L.FitText(closeLabel, 12)
		listParent = ui.questOverlay
	end
	ui.questList = UIKit.Create("Frame", {
		Name = "Rows",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(ui.questRowW, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = listParent,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, L.QuestGap),
		}),
	})
end

----------------------------------------------------------------- building: travel bar
local function buildTravel(root)
	ui.travel = UIKit.ArtFrame("PanelParchment", {
		Name = "Travel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, IS_TOUCH and 0.42 or 0.6), -- U3: touch stays above the thumbstick zone
		Size = UDim2.fromOffset(340, 64),
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	ui.travelLabel = artLabel(true, {
		Name = "Label",
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 18,
		Title = true,
		Parent = ui.travel,
	})
	local _, setTravel = UIKit.ArtBar({
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 35),
		Size = UDim2.fromOffset(300, 18),
		Color = ac("XPBlue", Theme.XP),
		Parent = ui.travel,
	})
	ui.setTravel = setTravel
end

----------------------------------------------------------------- building: buttons
-- round hit target (transparent TextButton + PressScale) holding the art disc "Art" (IMG-R4: code-drawn circle)
local function roundButton(name, size, part, fallbackColor)
	local btn = UIKit.Create("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = ui.buttons,
	}, { UIKit.Create("UIScale", { Name = "PressScale" }) })
	local art = UIKit.ArtFrame(part, {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = btn,
	}, {
		Color = fallbackColor,
		BackgroundTransparency = 0.08,
		CornerRadius = UDim.new(0.5, 0),
		StrokeColor = COL.White,
		StrokeThickness = 4,
		StrokeTransparency = 0.35,
	})
	return btn, art
end

-- small key badge (U1: keyboards only, never on touch)
local function keyHint(parent, text, position, anchor)
	if not SHOW_KEYS then return end
	L.FitText(UIKit.Create("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = ac("KeyHintBg", COL.Black),
		TextColor3 = ac("KeyHintText", COL.White),
		Font = af("Number", Theme.Font),
		TextSize = 13,
		Text = text,
		ZIndex = 8,
		Parent = parent,
	}, {
		corner(UDim.new(0, 5)),
		UIKit.Create("UIStroke", {
			Color = COL.White,
			Thickness = 1.5,
			Transparency = 0.15,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}), 11)
end

local doUpgrade, openMenu, openMap -- forward (defined with the input code)

-- parchment square (BtnSquare art): icon over a short ink label, key badge on the corner
local function squareButton(name, icon, text, key, onClick)
	local btn = UIKit.ArtButton("BtnSquare", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(L.Square, L.Square),
		Parent = ui.buttons,
	}, onClick, { CornerRadius = UDim.new(0, 12) })
	local img = UIKit.ArtImage(icon, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.5, 0.42),
		Parent = btn,
	})
	local label = artLabel(true, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, img and 0.53 or 0.28),
		Size = UDim2.new(1, -8, img and 0.25 or 0.4, 0),
		TextScaled = true,
		MaxTextSize = 14,
		Text = text,
		Parent = btn,
	})
	keyHint(btn, key, UDim2.new(1, 3, 1, 3), Vector2.new(1, 1))
	L.FitText(label, 12)
	return btn, label, img
end

local function buildButtons(root)
	ui.buttons = UIKit.Create("Frame", {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})

	-- 공격 (press = one swing, hold = repeat): red disc, silver sword, "공격"
	ui.attack = roundButton("Attack", L.Attack, "BtnAttack", COL.AttackFill)
	local sword = UIKit.ArtImage("IconAttack", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.46, 0.46),
		ZIndex = 3,
		Parent = ui.attack,
	})
	artLabel(false, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, sword and 0.74 or 0.5),
		Size = UDim2.fromScale(0.7, 0.22),
		TextScaled = true,
		MaxTextSize = math.floor(L.Attack * 0.2),
		Title = true,
		Text = TXT.Attack,
		ZIndex = 4,
		Parent = ui.attack,
	})
	L.FitText(ui.attack:FindFirstChild("Label"), 16, true)
	keyHint(ui.attack, "F", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- Keep the approved skill button artwork; only MP and cooldown determine readiness.
	local rel, relArt = roundButton("Release", L.Release, "BtnSpecial", COL.ReleaseFill)
	ui.release, ui.releaseArt = rel, relArt
	ui.releaseIcon = UIKit.ArtImage("IconSpecial", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.56, 0.34),
		ZIndex = 3,
		Parent = rel,
	})
	ui.skillLabel = artLabel(false, {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromScale(0.76, 0.22),
		TextScaled = true,
		MaxTextSize = math.max(14, math.floor(L.Release * 0.18)),
		Title = true,
		Text = TXT.Release,
		ZIndex = 4,
		Parent = rel,
	})
	L.FitText(ui.skillLabel, 14, true)
	ui.skillTimer = artLabel(false, {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.6, 0.3),
		TextScaled = true,
		MaxTextSize = 26,
		Number = true,
		Color = Theme.Gold,
		Visible = false,
		ZIndex = 4,
		Parent = rel,
	})
	L.FitText(ui.skillTimer, 16)
	keyHint(rel, "Q", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- 자동 / 지도 / 메뉴 (U1: the menu key is B; Esc belongs to Roblox and M opens the map)
	ui.map = squareButton("Map", "IconMap", TXT.Map, "M", function()
		openMap()
	end)
	ui.menu, ui.menuLabel = squareButton("Menu", "IconGear", TXT.Menu, "B", function()
		openMenu()
	end)
	ui.menuGlow = makeGlow(ui.menu, UDim.new(0, 12))
	-- A23-1 auto combat ON/OFF: hidden until the crown-shard quest unlocks it (no "unlocks at ..." teaser)
	ui.auto, ui.autoLabel = squareButton("Auto", "Crown", TXT.AutoOff, "R", function()
		L.ToggleAuto()
	end)
	ui.autoGlow = makeGlow(ui.auto, UDim.new(0, 12))
	local autoKey = ui.auto:FindFirstChild("KeyHint")
	if autoKey then -- the longer "자동 끔" label needs the bottom-right corner
		autoKey.AnchorPoint, autoKey.Position = Vector2.new(1, 0), UDim2.new(1, 3, 0, -3)
	end
	ui.auto.Visible = false

	-- next-weapon card: sword + "다음: 나무 검" + coin price, progress bar / A7-3 "N마리 더!" line
	local upW, upH = 3 * L.Square + 2 * L.RowGap, L.UpgradeH
	ui.upgrade = UIKit.ArtButton("PanelParchment", {
		Name = "Upgrade",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(upW, upH),
		Visible = not IS_TOUCH,
		Parent = ui.buttons,
	}, function()
		doUpgrade()
	end, { CornerRadius = UDim.new(0, 12) })
	ui.upgradeGlow = makeGlow(ui.upgrade, UDim.new(0, 12))
	local iconS = upH - 34
	local wood = UIKit.ArtImage("IconSword", {
		Name = "Icon",
		Position = UDim2.fromOffset(9, 7),
		Size = UDim2.fromOffset(iconS, iconS),
		Parent = ui.upgrade,
	})
	ui.upgradeIcon = wood
	ui.upgradeIconKey = wood and "IconSword" or nil
	local tx = wood and (iconS + 15) or 10
	ui.upgradeTitle = artLabel(true, {
		Name = "Title",
		Position = UDim2.fromOffset(tx, 8),
		Size = UDim2.new(1, -tx - 10, 0, 18),
		TextScaled = true,
		MaxTextSize = 15,
		Title = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = ui.upgrade,
	})
	ui.upgradeCoin = UIKit.ArtImage("IconCoin", {
		Name = "Coin",
		Position = UDim2.fromOffset(tx, 28),
		Size = UDim2.fromOffset(16, 16),
		Parent = ui.upgrade,
	})
	local px = ui.upgradeCoin and (tx + 20) or tx
	ui.upgradePrice = artLabel(true, {
		Name = "Price",
		Position = UDim2.fromOffset(px, 27),
		Size = UDim2.new(1, -px - 10, 0, 18),
		TextScaled = true,
		MaxTextSize = 15,
		Number = true,
		Color = ac("GoldInk", Theme.Gold),
		Outline = ac("TextOutline", COL.Dark),
		OutlineTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = ui.upgrade,
	})
	local _, setUpgrade, upgradeText = UIKit.ArtBar({
		Name = "Progress",
		Position = UDim2.fromOffset(8, upH - 26),
		Size = UDim2.new(1, -16, 0, 18),
		Color = ac("UpgradeGold", Theme.Gold),
		Parent = ui.upgrade,
	})
	upgradeText.TextScaled = true
	local tc = upgradeText:FindFirstChildOfClass("UITextSizeConstraint")
	if tc then tc.MaxTextSize = 13 end
	touchFloor(upgradeText)
	ui.setUpgrade = setUpgrade
	ui.upgradeText = upgradeText
	L.FitText(ui.upgradeTitle, 13, true)
	L.FitText(ui.upgradePrice, 12)
	L.FitText(ui.upgradeText, 11)
	keyHint(ui.upgrade, "U", UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
end

----------------------------------------------------------------- refresh: stats
function L.PortraitDisconnect(connections)
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

function L.PortraitClear()
	local state = ui.portrait
	if not state then return end
	L.PortraitDisconnect(state.AppearanceConnections)
	if state.Clone then state.Clone:Destroy(); state.Clone = nil end
	state.View.ImageTransparency = 1
	state.View.BackgroundTransparency = 1
	ui.portraitHeadshot.Visible = true
end

-- Match duplicate-named children by class/name/occurrence without changing the source character.
function L.PortraitPairs(source, copy, pairs)
	pairs[source] = copy
	local children, used = {}, {}
	for _, child in copy:GetChildren() do
		local key = child.ClassName .. "/" .. child.Name
		children[key] = children[key] or {}
		table.insert(children[key], child)
	end
	for _, child in source:GetChildren() do
		local key = child.ClassName .. "/" .. child.Name
		used[key] = (used[key] or 0) + 1
		local target = children[key] and children[key][used[key]]
		if target then L.PortraitPairs(child, target, pairs) end
	end
end

function L.PortraitAppearance(object)
	return object:IsA("BasePart") or object:IsA("DataModelMesh") or object:IsA("Decal")
		or object:IsA("SurfaceAppearance") or object:IsA("BodyColors") or object:IsA("Clothing")
		or object:IsA("ShirtGraphic") or object:IsA("Accessory") or object:IsA("CharacterMesh")
		or object:IsA("Bone") or object:IsA("JointInstance") or object:IsA("WeldConstraint")
end

function L.PortraitLoad(state, copy, revision)
	state.LoadRevision = (state.LoadRevision or 0) + 1
	local loadRevision = state.LoadRevision
	state.View.ImageTransparency = 1
	state.View.BackgroundTransparency = 1
	ui.portraitHeadshot.Visible = true
	local head = copy:FindFirstChild("Head")
	local required, seen = {}, {}
	local function include(object)
		if object and object:IsDescendantOf(copy) and not seen[object] then
			seen[object] = true
			table.insert(required, object)
		end
	end
	include(head)
	for _, object in copy:GetDescendants() do
		if object:IsA("BasePart") and (object.Name == "HeadBase" or object.Name == "FaceExpression") then
			include(object)
		elseif object:IsA("Weld") or object:IsA("WeldConstraint") then
			-- Hair, hats and face accessories can be separate parts welded to the real head.
			if object.Part0 == head then include(object.Part1)
			elseif object.Part1 == head then include(object.Part0) end
		end
	end
	local hasAsset = false
	for _, object in required do
		local objects = object:GetDescendants()
		table.insert(objects, object)
		for _, child in objects do
			if child:IsA("MeshPart") and (child.MeshId ~= "" or child.TextureID ~= "")
				or child:IsA("SpecialMesh") and (child.MeshId ~= "" or child.TextureId ~= "")
				or child:IsA("Decal") and child.Texture ~= ""
				or child:IsA("SurfaceAppearance") and (child.ColorMap ~= "" or child.MetalnessMap ~= ""
					or child.NormalMap ~= "" or child.RoughnessMap ~= "") then hasAsset = true end
		end
	end
	state.View:SetAttribute("PreloadComplete", false)
	state.View:SetAttribute("PreloadRequiredObjects", #required)
	task.spawn(function()
		local successes, failures = 0, 0
		local ok = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(required, function(_, status)
				if status == Enum.AssetFetchStatus.Success then successes += 1 else failures += 1 end
			end)
		end)
		if state.Clone ~= copy or state.Revision ~= revision or state.LoadRevision ~= loadRevision
			or state.Character ~= LocalPlayer.Character then return end
		local loaded = ok and failures == 0 and (not hasAsset or successes > 0)
		state.View:SetAttribute("PreloadSuccess", successes)
		state.View:SetAttribute("PreloadFailures", failures)
		state.View:SetAttribute("PreloadComplete", loaded)
		if loaded then
			state.View.ImageTransparency = 0
			state.View.BackgroundTransparency = 0
			ui.portraitHeadshot.Visible = false
		end
	end)
end

function L.PortraitRebuild(state, revision)
	if ui.portrait ~= state or state.Revision ~= revision then return end
	L.PortraitClear()
	local character = state.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character ~= LocalPlayer.Character or not character or not character.Parent
		or not head or not head:IsA("BasePart") or not root or not root:IsA("BasePart") then return end
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = archivable
	if not ok or not copy then return end
	copy.Name = "PortraitCharacter"
	local pairs = {}
	L.PortraitPairs(character, copy, pairs)
	if not pairs[head] or not pairs[root] then copy:Destroy(); return end
	-- The clone remains unparented until all executable/UI/physics effects have been removed.
	for source, target in pairs do
		if target:IsA("LuaSourceContainer") or target:IsA("LayerCollector") or target:IsA("GuiObject")
			or target:IsA("Tool") or (target:IsA("Model") and target.Name == "WeaponModel")
			or target:IsA("ParticleEmitter") or target:IsA("Trail") or target:IsA("Beam")
			or target:IsA("Fire") or target:IsA("Smoke") or target:IsA("Sparkles")
			or target:IsA("Sound") or target:IsA("Light") or target:IsA("Highlight")
			or target:IsA("BodyMover") or target:IsA("Animator") or target:IsA("AnimationController")
			or (target:IsA("Constraint") and not target:IsA("WeldConstraint")) then
			target:Destroy()
		elseif target:IsA("BasePart") then
			target.Anchored = true
			target.CanCollide = false
			target.CanTouch = false
			target.CanQuery = false
			target.AssemblyLinearVelocity = Vector3.zero
			target.AssemblyAngularVelocity = Vector3.zero
			target.LocalTransparencyModifier = 0
			target.CFrame = source.CFrame
		elseif target:IsA("Bone") or target:IsA("Motor6D") then
			target.Transform = source.Transform -- snapshot the real skin pose; keep its internal bone/weld graph
		elseif target:IsA("Humanoid") then
			target.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			target.AutoRotate = false
		end
	end
	-- Only external references are cleared; shared-bone ObjectValues and internal welds must survive.
	for _, object in copy:GetDescendants() do
		if object:IsA("ObjectValue") and object.Value and not object.Value:IsDescendantOf(copy) then object.Value = nil end
	end
	state.Clone = copy
	copy.Parent = state.World
	state.View:SetAttribute("CharacterName", character.Name)
	local up = root.CFrame.UpVector
	local focus = head.Position - up * head.Size.Y * 0.04
	local span = math.max(head.Size.X, head.Size.Y) * 0.85
	local distance = span / (2 * math.tan(math.rad(state.Camera.FieldOfView / 2))) + head.Size.Z * 0.5
	state.Camera.CFrame = CFrame.lookAt(focus + root.CFrame.LookVector * distance, focus, up)
	state.Camera.Focus = CFrame.new(focus)
	state.View:SetAttribute("CameraSpan", span)
	for source, target in pairs do
		if target:IsDescendantOf(copy) then
			local properties = nil
			if source:IsA("MeshPart") then properties = { "TextureID" }
			elseif source:IsA("Decal") then properties = { "Texture" }
			elseif source:IsA("SurfaceAppearance") then properties = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" }
			end
			if properties then
				for _, property in properties do
					table.insert(state.AppearanceConnections, source:GetPropertyChangedSignal(property):Connect(function()
						if state.Clone ~= copy or not target.Parent then return end
						pcall(function() target[property] = source[property] end)
						L.PortraitLoad(state, copy, revision)
					end))
				end
			end
			if source:IsA("BasePart") then
				for _, property in { "Size", "Color", "Transparency" } do
					table.insert(state.AppearanceConnections, source:GetPropertyChangedSignal(property):Connect(L.RefreshPortrait))
				end
			elseif source:IsA("BodyColors") or source:IsA("Clothing") or source:IsA("ShirtGraphic")
				or source:IsA("CharacterMesh") or source:IsA("DataModelMesh") then
				table.insert(state.AppearanceConnections, source.Changed:Connect(L.RefreshPortrait))
			end
		end
	end
	L.PortraitLoad(state, copy, revision)
end

function L.RefreshPortrait()
	local headshot = ui.portraitHeadshot
	if not headshot then return end -- the compact touch layout has no portrait
	if not ui.portrait then
		local view = UIKit.Create("ViewportFrame", {
			Name = "AvatarPortrait3D", Position = headshot.Position, Size = headshot.Size,
			BackgroundColor3 = headshot.BackgroundColor3, BackgroundTransparency = 1,
			ImageTransparency = 1, ZIndex = headshot.ZIndex, Parent = ui.portraitHolder,
		})
		corner(UDim.new(0.5, 0)).Parent = view
		local stroke = headshot:FindFirstChildOfClass("UIStroke")
		if stroke then stroke:Clone().Parent = view end
		local camera = UIKit.Create("Camera", { Name = "PortraitCamera", FieldOfView = 32, Parent = view })
		view.CurrentCamera = camera
		ui.portrait = { View = view, Camera = camera, World = UIKit.Create("WorldModel", { Parent = view }),
			CharacterConnections = {}, AppearanceConnections = {}, Revision = 0 }
	end
	local state = ui.portrait
	local character = LocalPlayer.Character
	if state.Character ~= character then
		L.PortraitDisconnect(state.CharacterConnections)
		L.PortraitClear()
		state.Character = character
		if character then
			for _, signal in { character.DescendantAdded, character.DescendantRemoving } do
				table.insert(state.CharacterConnections, signal:Connect(function(object)
					if L.PortraitAppearance(object) then L.RefreshPortrait() end
				end))
			end
		end
	end
	state.Revision += 1
	local revision = state.Revision
	task.delay(0.2, function()
		if state.Revision ~= revision then return end
		local ok, err = pcall(L.PortraitRebuild, state, revision)
		if not ok then L.PortraitClear(); warnThrottled("portrait error: " .. tostring(err)) end
	end)
end

function L.PortraitRemoving(character)
	local state = ui.portrait
	if not state or state.Character ~= character then return end
	state.Revision += 1
	L.PortraitDisconnect(state.CharacterConnections)
	L.PortraitClear()
	state.Character = nil
end

local function refreshStats()
	local f = getFaction()
	local level = math.floor(num("Level", 1))
	ui.level.Text = tostring(level)

	if ui.title then
		local title = Config.DisplayTitle(f, num("Honor", 0), num("Infamy", 0), num("FallMarks", 0),
			num("RedeemMarks", 0), attr("SessionTitle", ""))
		local prefix = ""
		if f == "Neutral" then
			local emblem = factionDef(f).Emblem
			if type(emblem) == "string" and emblem ~= "" and glyphSafe(emblem) then prefix = emblem .. " " end
		end
		ui.title.Text = prefix .. tostring(title or "")
		ui.title.TextColor3 = factionColor(f)
		ui.class.Text = Config.ClassName(getClass(), f)
	end

	local xp = math.max(0, num("XP", 0))
	if level >= Config.Levels.MaxLevel then
		ui.setXP(1)
		ui.xpText.Text = "MAX"
	else
		local need = math.max(1, Config.XPToNext(level))
		ui.setXP(xp / need)
		ui.xpText.Text = fmtNum(xp) .. " / " .. fmtNum(need)
	end

	local tagHex = ac("LightSub", Theme.SubText):ToHex()
	ui.bank.Text = string.format(TXT.Money, tagHex, TXT.BankTag, fmtNum(num("BankGold", 0)))
	if ui.carried then
		ui.carried.Text = string.format(TXT.Money, tagHex, TXT.CarriedTag, fmtNum(num("CarriedGold", 0)))
	end

	local horns = f == "Horns"
	ui.stars.Visible = horns
	if horns then
		local maxStars = Config.PvP.MaxStars or 5
		local stars = math.clamp(math.floor(num("WantedStars", 0)), 0, maxStars)
		local bounty = string.format(TXT.Bounty, fmtNum(num("Bounty", 0)))
		if ui.starIds then
			for i, img in ui.starImgs do
				img.Visible = i <= maxStars
				img.Image = (i <= stars) and ui.starIds[1] or ui.starIds[2]
			end
			ui.bounty.Text = bounty
		else
			ui.bounty.Text = string.rep("★", stars) .. string.rep("☆", maxStars - stars) .. " " .. bounty
		end
	end
	local h = (ui.statsBaseH or L.StatsH) + (horns and L.StarsH or 0)
	if ui.stats.Size.Y.Offset ~= h then
		ui.stats.Size = UDim2.fromOffset(L.StatsW, h)
		requestLayout()
	end
end

----------------------------------------------------------------- refresh: status chips
local function refreshChips()
	local f = getFaction()
	local now = Util.Now()
	local pal = ui.chipPal

	local blessing = UIKit.GameAttr("WarBlessing", "None")
	local bdef = (blessing == "Halo" or blessing == "Horns") and Config.Factions[blessing] or nil
	if bdef then
		local pct = math.floor((Config.War.BlessingGold or 0.25) * 100 + 0.5)
		setChip(ui.chip.Blessing, true, string.format(TXT.Blessing, bdef.Name, pct), factionColor(blessing),
			blessing == f, nil, true)
	else
		setChip(ui.chip.Blessing, false)
	end

	if attr("ZoneTown", false) == true then
		setChip(ui.chip.Zone, true, TXT.Safe, Theme.Good, false, pal.Safe, true)
	elseif attr("ZonePvP", false) == true then
		if f == "Neutral" then
			setChip(ui.chip.Zone, true, TXT.PvPNeutral, factionColor("Neutral")) -- A6: Neutral is PvP-immune (A9-1 teal)
		else
			setChip(ui.chip.Zone, true, TXT.PvP, Theme.Bad)
		end
	else
		setChip(ui.chip.Zone, false)
	end

	local graceLeft = math.ceil(num("GraduateGraceUntil", 0) - now) -- A23-18: the shield's 60 s afterglow
	local rookieOn = attr("Rookie", false) == true and f ~= "Neutral"
	setChip(ui.chip.Rookie, rookieOn or graceLeft > 0, (not rookieOn and graceLeft > 0)
		and string.format(TXT.RookieGrace, graceLeft) or TXT.Rookie, Theme.XP, false, pal.Rookie, true)
	setChip(ui.chip.Protected, attr("Protected", false) == true, TXT.Protected, Theme.XP)
	setChip(ui.chip.Combat, num("InCombatUntil", 0) > now, TXT.InCombat, Theme.Revenge)
	local size = num("SizeMult", 1)
	setChip(ui.chip.Size, size > 1.001, string.format(TXT.Size, size), Theme.Gold)
	local bully = math.floor(num("BullyStacks", 0))
	setChip(ui.chip.Bully, bully > 0, string.format(TXT.Bully, bully), Theme.Bad)
	setChip(ui.chip.Kaiju, attr("KaijuState", "None") == "Queued", TXT.KaijuQueued, Theme.Bad)
end

----------------------------------------------------------------- refresh: war meter
local function fmtScore(v)
	if v >= 1000 then return fmtNum(v) end
	return string.format("%g", math.floor(v * 10 + 0.5) / 10)
end

local function refreshWarTime()
	local endsAt = tonumber(UIKit.GameAttr("WarRoundEndsAt", 0)) or 0
	if endsAt <= 0 then
		ui.warTime.Text = string.format(TXT.WarTime, "-:--")
	else
		ui.warTime.Text = string.format(TXT.WarTime, Util.FormatTime(endsAt - Util.Now()))
	end
end

local function refreshWar()
	local h = math.max(0, tonumber(UIKit.GameAttr("WarHaloScore", 0)) or 0)
	local r = math.max(0, tonumber(UIKit.GameAttr("WarHornsScore", 0)) or 0)
	local frac = (h + r > 0) and (h / (h + r)) or 0.5
	ui.haloFill.Size = UDim2.fromScale(frac, 1)
	ui.hornsFill.Size = UDim2.fromScale(1 - frac, 1)
	ui.haloFill.Visible = frac > 0.001
	ui.hornsFill.Visible = frac < 0.999
	ui.warDivider.Position = UDim2.fromScale(frac, 0.5)
	if ui.warCrown then ui.warCrown.Position = UDim2.fromScale(frac, 0.5) end
	ui.haloNum.Text = tostring(Config.Factions.Halo.Emblem) .. " " .. fmtScore(h)
	ui.hornsNum.Text = fmtScore(r) .. " " .. tostring(Config.Factions.Horns.Emblem)

	local mode = UIKit.GameAttr("WarMode", "Idle")
	ui.warSiege.Visible = mode == "Siege"
	ui.warSiegeText.Text = string.format(TXT.Siege, Config.War.SiegeTarget or 150)

	local f = getFaction()
	local fighting = f == "Halo" or f == "Horns" -- A6: Neutral / None earn no war points
	ui.warPoints.Visible = fighting
	if fighting then
		ui.warPointsText.Text = string.format(TXT.MyWar, fmtNum(num("WarPoints", 0)))
	end
	refreshWarTime()
	refreshChips()
end

----------------------------------------------------------------- refresh: MP skill
local function refreshSkill()
	local remaining = math.max(0, num("SkillReadyAt", 0) - Util.Now())
	local ready = remaining <= 0 and num("Mana", 0) >= Config.BasicSkill.ManaCost
	-- the MP price on the button itself ("스킬 MP20"), so an MP shortage is never a surprise
	ui.skillLabel.Text = string.format(TXT.ReleaseCost, Config.BasicSkill.ManaCost)
	ui.skillTimer.Visible = remaining > 0
	ui.skillTimer.Text = string.format("%.1f", remaining)
	if ui.releaseIcon then ui.releaseIcon.Visible = remaining <= 0 end
	if isImage(ui.releaseArt) then
		ui.releaseArt.ImageColor3 = ready and COL.White or COL.DimTint
	elseif ui.releaseArt then
		ui.releaseArt.BackgroundTransparency = ready and 0.05 or 0.35
	end
end

local function refreshUpgrade()
	local iconKey = "IconSword"
	if type(Config.WeaponArtKey) == "function" then
		local weaponKey = Config.WeaponArtKey(math.floor(num("WeaponTier", 1)), getClass(), getFaction())
		if UIKit.ArtId(weaponKey) then iconKey = weaponKey end
	end
	if not UIKit.ArtId(iconKey) then iconKey = nil end
	if ui.upgradeIconKey ~= iconKey then
		if ui.upgradeIcon then ui.upgradeIcon:Destroy() end
		local iconS = L.UpgradeH - 34
		ui.upgradeIcon = iconKey and UIKit.ArtImage(iconKey, {
			Name = "Icon",
			Position = UDim2.fromOffset(9, 7),
			Size = UDim2.fromOffset(iconS, iconS),
			Parent = ui.upgrade,
		}) or nil
		ui.upgradeIconKey = iconKey
		local tx = ui.upgradeIcon and (iconS + 15) or 10
		ui.upgradeTitle.Position = UDim2.fromOffset(tx, 8)
		ui.upgradeTitle.Size = UDim2.new(1, -tx - 10, 0, 18)
		if ui.upgradeCoin then ui.upgradeCoin.Position = UDim2.fromOffset(tx, 28) end
		local px = ui.upgradeCoin and (tx + 20) or tx
		ui.upgradePrice.Position = UDim2.fromOffset(px, 27)
		ui.upgradePrice.Size = UDim2.new(1, -px - 10, 0, 18)
	end
	ui.upgradeTitle.Text = "대장간" -- one name everywhere: HUD card, panel title, world sign ("대장간 · 장인 길드")
	ui.upgradePrice.Text = "무기 선택 · 구매 · 판매"
	ui.upgradeText.Text = "교차로 마을"
	ui.setUpgrade(1, ac("UpgradeGold", Theme.Gold))
	if ui.upgradeCoin then ui.upgradeCoin.Visible = false end
	-- The shop is a choice, not a prescribed next-tier purchase.
	if not ui.upgrade.Visible then
		ui.upgrade.Visible = true
		requestLayout()
	end
end

-- B14: Panels.ItemsHint = I hold a scroll and have not opened 메뉴 → 아이템 this session
function L.ItemsHint()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.ItemsHint) ~= "function" then return false end
	local ok, hint = pcall(panels.ItemsHint)
	return ok and hint == true
end

local function refreshMenuGlow()
	local glow = num("Level", 1) >= Config.RebirthLevel(num("Rebirths", 0)) or num("VacationDays", 0) > 0
		or L.ItemsHint()
	if glow == menuGlowOn then return end
	menuGlowOn = glow
	if menuGlowTween then
		menuGlowTween:Cancel()
		menuGlowTween = nil
	end
	local stroke = ui.menuGlow
	if not stroke then return end
	if glow then
		stroke.Transparency = 0
		stroke.Thickness = 3
		menuGlowTween = TweenService:Create(stroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 6 })
		menuGlowTween:Play()
	else
		stroke.Transparency = 1
		stroke.Thickness = 3
	end
end

----------------------------------------------------------------- refresh: travel
local function refreshTravel()
	local untilT = num("TravelingUntil", 0)
	local remaining = untilT - Util.Now()
	if untilT <= 0 or remaining <= 0 then
		ui.travel.Visible = false
		return
	end
	ui.travel.Visible = true
	local total = math.max(0.1, Config.Travel.ChannelSeconds or 3)
	ui.setTravel(1 - remaining / total)
	ui.travelLabel.Text = string.format(TXT.TravelLeft, textOr("Traveling", "이동 중..."), remaining)
end

----------------------------------------------------------------- quests
local function parseQuests()
	local data = questState.Data -- CR-L50: last "Quests" remote payload (array of entries)
	if type(data) ~= "table" then return {} end
	-- remote tables can carry NaN / inf (JSON could not): treat them as missing
	local function finite(v, default)
		v = tonumber(v)
		if v == nil or v ~= v or v == math.huge or v == -math.huge then return default end
		return v
	end
	local pinned, normal = {}, {}
	for _, e in ipairs(data) do
		if type(e) == "table" then
			local isPinned = e.Pinned == true or (e.Slot == nil and e.Id == TUT_QUEST_ID)
			local slot = finite(e.Slot, nil)
			local entry = {
				Id = tostring(e.Id or ""),
				Kind = tostring(e.Kind or "Extra"),
				Text = tostring(e.Text or ""),
				Progress = math.max(0, finite(e.Progress, 0)),
				Target = math.max(1, finite(e.Target, 1)),
				RewardGold = math.max(0, finite(e.RewardGold, 0)),
				Pinned = isPinned,
				CanClaim = e.CanClaim ~= false,
				ShowProgress = e.ShowProgress ~= false,
				TutorialStep = finite(e.TutorialStep, -1),
				NextGoal = e.NextGoal == true,
				Story = type(e.Story) == "table" and e.Story or nil, -- story rows: { Id, St, Panel, Guide }
				Slot = (not isPinned) and slot or nil, -- N1: the client only ever sends Slot or "tutorial"
			}
			table.insert(isPinned and pinned or normal, entry)
		end
	end
	-- A23-3: before the first mission is accepted (step 0) dailies keep progressing on the server but stay folded
	local folded = pinned[1] ~= nil and pinned[1].TutorialStep == 0
	if questState.Folded == true and not folded and pinned[1] ~= nil and pinned[1].TutorialStep > 0 and #normal > 0 then
		UIKit.Toast((type(TUT.Text) == "table" and TUT.Text.DailiesOpened) or "일일 임무가 열렸어요!", "good", 4)
	end
	questState.Folded = folded
	if folded then
		for _, e in normal do
			if e.Kind == "Sub" then table.insert(pinned, e) end -- S0 shows even before the first mission (A23-2)
		end
		return pinned
	end
	for _, e in normal do
		table.insert(pinned, e)
	end
	return pinned
end

-- CR-L50: the owner's quest list arrives on the "Quests" remote (fired only when it changes) instead of the
-- QuestsJson attribute that replicated to every player. Takes the array itself or its JSON string.
local function onQuests(payload)
	local data = payload
	if type(payload) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(payload)
		end)
		data = ok and decoded or nil
	elseif type(payload) == "table" and type(payload.Quests) == "table" then
		data = payload.Quests
	end
	if type(data) ~= "table" then return end
	questState.Data = data
	if questState.Started then refreshQuests() end
end

-- CR-M27 / CR-L31: "progress/target" strings. Kill / Golden progress can be fractional (unit-XP share, floored to
-- 0.1 by the server) and shows one decimal instead of looking stuck; targets under 10,000 show the plain integer
-- (FormatNumber made 3,199 of 3,200 read "3.2K/3.2K" while unfinished).
local function questNums(e)
	local function count(v)
		v = math.clamp(v, 0, e.Target)
		if e.Target < 10000 then
			local tenths = math.floor(v * 10 + 1e-6) / 10 -- floor: 0.96 of 1 reads "0.9", never "1.0"
			if tenths == math.floor(tenths) then return tostring(math.floor(tenths)) end
			return string.format("%.1f", tenths)
		end
		return fmtNum(v)
	end
	local p, t = count(e.Progress), count(e.Target)
	if e.Progress < e.Target and p == t then
		p, t = tostring(math.floor(e.Progress)), tostring(math.floor(e.Target)) -- never "12.5K/12.5K" unfinished
	end
	return p, t
end

local function onClaim(r)
	local e = r.Entry
	if not e or not e.CanClaim or e.Progress < e.Target or throttled("claim", 0.35) then return end
	if os.clock() < (r.LockUntil or 0) then return end -- CR-M24: the row just changed under the finger
	local arg = nil
	if e.Story then
		arg = e.Id -- "story:<id>"
	elseif e.Pinned then
		arg = TUT_QUEST_ID
	else
		arg = e.Slot
	end
	if arg == nil then return end
	fire("ClaimQuest", arg)
	questState.ClaimAt = os.clock() -- CR-M24: 교체 ignores taps for ClaimLock seconds after a claim
	r.Claim:SetAttribute("Disabled", true)
	setDim(r.Claim, true)
	task.delay(1.5, function()
		if r.Claim.Parent then
			r.Claim:SetAttribute("Disabled", false)
			setDim(r.Claim, false)
		end
	end)
end

local function onReroll(r)
	local e = r.Entry
	if not e or e.Pinned or e.Slot == nil then return end
	local now = os.clock()
	if now - questState.ClaimAt < questState.ClaimLock then return end -- CR-M24
	if now < (r.LockUntil or 0) then return end
	if Util.Now() < num("RerollReadyAt", 0) then return end
	if throttled("reroll", 0.6) then return end
	local slot, key = e.Slot, r.Key
	-- CR-M25: rerolling throws the progress away, so it always asks first (every device)
	UIKit.Confirm(TXT.RerollTitle, TXT.RerollBody, TXT.RerollYes, function()
		if r.Key ~= key then return end -- the row changed while the dialog was open
		fire("RerollQuest", slot)
	end)
end

-- parchment row: quest icon (slime / scroll), kind badge + text, progress bar + coin reward.
-- 교체 sits top-right and 받기 bottom-right, so the two never share a spot (CR-M24).
function L.QuestMetrics(s)
	local r = table.clone(L.Row)
	r.Badge = math.max(r.Badge, math.ceil(26 / s))
	r.BadgeH = math.max(r.BadgeH, math.ceil(12 / s))
	r.Reroll = math.max(r.Reroll, math.ceil(30 / s))
	r.BtnH = math.max(r.BtnH, math.ceil(16 / s))
	r.Reward = math.max(r.Reward, math.ceil(50 / s))
	r.BarH = math.max(r.BarH, math.ceil(12 / s))
	r.Height = math.max(L.QuestRowH, math.ceil(40 / s), r.BtnH + r.BarH + 14)
	return r
end

function L.LayoutQuestRow(r, s)
	local W, R = ui.questRowW, L.QuestMetrics(s)
	local H, iconS = R.Height, L.QuestRowH - 20
	r.Frame.Size = UDim2.fromOffset(W, H)
	local x0 = r.Icon and (iconS + 14) or 8
	r.Badge.Position = UDim2.fromOffset(x0, 7)
	r.Badge.Size = UDim2.fromOffset(R.Badge, R.BadgeH)
	local textX = x0 + R.Badge + 5
	r.TextLong = W - textX - 10
	r.TextShort = W - textX - R.Reroll - 14
	r.Text.Position = UDim2.fromOffset(textX, 5)
	r.Text.Size = UDim2.fromOffset(r.Reroll.Visible and r.TextShort or r.TextLong, R.BtnH + 1)
	if r.Entry and not r.Entry.ShowProgress then
		r.Text.Size = UDim2.fromOffset(r.TextLong, H - 10)
	end
	local barY, rx = H - R.BarH - 9, W - R.Reward - 8
	r.Bar.Position = UDim2.fromOffset(x0, barY)
	r.Bar.Size = UDim2.fromOffset(W - x0 - R.Reward - 14, R.BarH)
	local cs = R.BarH + 3
	if r.Coin then
		r.Coin.Position = UDim2.fromOffset(rx, barY + math.floor((R.BarH - cs) / 2))
		r.Coin.Size = UDim2.fromOffset(cs, cs)
	end
	local tx = r.Coin and (rx + cs + 3) or rx
	r.Reward.Position = UDim2.fromOffset(tx, barY - 2)
	r.Reward.Size = UDim2.fromOffset(W - 8 - tx, R.BarH + 4)
	local claimH = R.BtnH + 4
	r.Claim.Position = UDim2.fromOffset(rx - 6, H - claimH - 4)
	r.Claim.Size = UDim2.fromOffset(R.Reward + 10, claimH)
	r.Reroll.Position = UDim2.fromOffset(W - R.Reroll - 8, 4)
	r.Reroll.Size = UDim2.fromOffset(R.Reroll, R.BtnH)
end

local function makeQuestRow(index)
	local W, R = ui.questRowW, L.QuestMetrics(currentScale())
	local H = R.Height
	local row, isArt = UIKit.ArtFrame("PanelParchment", {
		Name = "Quest" .. index,
		LayoutOrder = index,
		Size = UDim2.fromOffset(W, H),
		Parent = ui.questList,
	})
	local r = { Frame = row, IsArt = isArt, Entry = nil, Key = nil, LockUntil = 0 }
	-- tapping the pinned guide row opens its action (claim / reroll sit above it at ZIndex 3)
	r.Tap = UIKit.Create("TextButton", {
		Name = "Tap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 2,
		Visible = false,
		Parent = row,
	})
	r.Tap.Activated:Connect(function()
		if r.Entry and (r.Entry.Pinned or r.Entry.Story) and L.PinnedTap then L.PinnedTap(r.Entry) end
	end)
	local iconS = L.QuestRowH - 20
	r.Icon = UIKit.ArtImage("IconScroll", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(iconS, iconS),
		Parent = row,
	})
	local x0 = r.Icon and (iconS + 14) or 8
	r.Badge = touchFloor(UIKit.Create("TextLabel", {
		Name = "Badge",
		Position = UDim2.fromOffset(x0, 7),
		Size = UDim2.fromOffset(R.Badge, R.BadgeH),
		BackgroundColor3 = Theme.Gold,
		TextColor3 = COL.Dark,
		TextSize = R.Text - 2,
		Text = "",
		Parent = row,
	}, {
		corner(UDim.new(0, 5)),
		UIKit.Create("UIStroke", {
			Color = ac("Rim", COL.Dark),
			Thickness = 1,
			Transparency = 0.3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}))
	local textX = x0 + R.Badge + 5
	r.TextLong = W - textX - 10
	r.TextShort = W - textX - R.Reroll - 14
	r.Text = artLabel(true, {
		Name = "Text",
		Position = UDim2.fromOffset(textX, 5),
		Size = UDim2.fromOffset(r.TextShort, R.BtnH + 1),
		TextScaled = true,
		MaxTextSize = R.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	local barY = H - R.BarH - 9
	local bar, setBar, barText = UIKit.ArtBar({
		Name = "Progress",
		Position = UDim2.fromOffset(x0, barY),
		Size = UDim2.fromOffset(W - x0 - R.Reward - 14, R.BarH),
		Color = ac("QuestBlue", Theme.Good),
		TextSize = IS_TOUCH and L.TouchText or 11,
		Parent = row,
	})
	r.SetBar = setBar
	r.Bar = bar
	r.BarText = barText
	-- reward: coin + "+120"
	local rx = W - R.Reward - 8
	local cs = R.BarH + 3
	r.Coin = UIKit.ArtImage("IconCoin", {
		Name = "Coin",
		Position = UDim2.fromOffset(rx, barY + math.floor((R.BarH - cs) / 2)),
		Size = UDim2.fromOffset(cs, cs),
		Parent = row,
	})
	local tx = r.Coin and (rx + cs + 3) or rx
	r.Reward = artLabel(true, {
		Name = "Reward",
		Position = UDim2.fromOffset(tx, barY - 2),
		Size = UDim2.fromOffset(W - 8 - tx, R.BarH + 4),
		TextScaled = true,
		MaxTextSize = R.Text,
		Number = true,
		Color = ac("GoldInk", Theme.Gold),
		Outline = ac("TextOutline", COL.Dark),
		OutlineTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	-- 받기: green candy pill over the reward (bottom-right)
	local claimH = R.BtnH + 4
	local claim, claimLabel = UIKit.ArtButton("Pill", {
		Name = "Claim",
		Position = UDim2.fromOffset(rx - 6, H - claimH - 4),
		Size = UDim2.fromOffset(R.Reward + 10, claimH),
		ImageColor3 = COL.HotTint,
		Text = TXT.Claim,
		TextSize = R.Text + 1,
		TextStyle = "light",
		Visible = false,
		ZIndex = 3,
		Parent = row,
	}, function()
		onClaim(r)
	end, { Color = Theme.Good, CornerRadius = UDim.new(0.5, 0) })
	r.Claim = claim
	L.FitText(claimLabel, 12)
	-- 교체: small parchment pill (top-right)
	local reroll, rerollLabel = UIKit.ArtButton("Pill", {
		Name = "Reroll",
		Position = UDim2.fromOffset(W - R.Reroll - 8, 4),
		Size = UDim2.fromOffset(R.Reroll, R.BtnH),
		Text = TXT.Reroll,
		TextSize = R.Text,
		TextStyle = "ink",
		Visible = false,
		ZIndex = 3,
		Parent = row,
	}, function()
		onReroll(r)
	end, { CornerRadius = UDim.new(0.5, 0) })
	r.Reroll = reroll
	r.RerollLabel = L.FitText(rerollLabel, 11)
	L.FitText(r.Badge, 11)
	L.FitText(r.Text, 12)
	L.FitText(r.BarText, 11)
	L.FitText(r.Reward, 11)
	return r
end

local function refreshRerollTimers()
	local remaining = num("RerollReadyAt", 0) - Util.Now()
	for _, r in questRows do
		if r.Frame.Visible and r.Reroll.Visible then
			local waiting = remaining > 0
			if r.RerollLabel then
				r.RerollLabel.Text = waiting and tostring(math.ceil(remaining)) or TXT.Reroll
			end
			setDim(r.Reroll, waiting)
			r.Reroll:SetAttribute("Disabled", waiting)
		end
	end
end

-- B15: the story page Panels holds back ({ Id, St, Label }) or nil
function L.StoryPending()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.StoryPending) ~= "function" then return nil end
	local ok, p = pcall(panels.StoryPending)
	if ok and type(p) == "table" and type(p.Id) == "string" and type(p.Label) == "string" then return p end
	return nil
end

-- B15: one gentle gold pulse (a glow stroke) on `target` (a quest row, or the touch header line); nil stops it
function L.SetStoryPulse(target)
	local p = questState.Pulse
	if p.Target == target then return end
	if p.Tween then
		p.Tween:Cancel()
		p.Tween = nil
	end
	if p.Stroke and p.Stroke.Parent then
		p.Stroke.Transparency, p.Stroke.Thickness = 1, 3
	end
	p.Target, p.Stroke = target, nil
	if typeof(target) ~= "Instance" or not target.Parent then return end
	local holder = target:FindFirstChild("StoryGlow")
	local stroke = holder and holder:FindFirstChild("GlowStroke")
	if not stroke then
		stroke = makeGlow(target, UDim.new(0, 10))
		if stroke and stroke.Parent then stroke.Parent.Name = "StoryGlow" end
	end
	if not stroke then return end
	p.Stroke = stroke
	stroke.Transparency, stroke.Thickness = 0.6, 2
	p.Tween = TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0, Thickness = 4 })
	p.Tween:Play()
end

refreshQuests = function()
	if not ui.quests then return end -- Init stopped before buildQuests (CR-L50 binds the remote earlier)
	local entries = parseQuests()
	-- B15: a story page waiting for a calm moment turns its row into "…말을 걸어요 — 눌러서 보기" (pulsing)
	local call = L.StoryPending()
	questState.StoryKey = call and (call.Id .. "|" .. tostring(call.St)) or ""
	local callIndex = nil
	if call then
		for i, e in entries do
			if e.Story and e.Story.Panel and e.Story.Id == call.Id then
				callIndex = i
				break
			end
		end
	end
	questState.CallEntry = callIndex and entries[callIndex] or nil
	local blockWasVisible = ui.quests.Visible
	ui.quests.Visible = #entries > 0
	if #entries == 0 and ui.questOverlay then
		questState.OverlayOpen = false
		ui.questOverlay.Visible = false
	end
	local slots = Config.Quests.Slots
	local claims = math.floor(num("DailyClaims", 0))

	-- collapsed: the tutorial row if present, else the first claimable, else the first unfinished daily
	local claimable, firstClaim, firstDaily = 0, nil, nil
	for i, e in entries do
		local done = e.Progress >= e.Target
		if done and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub") then
			claimable += 1
			if not firstClaim then firstClaim = i end
		elseif not done and e.Kind == "Daily" and not firstDaily then
			firstDaily = i
		end
	end
	local shown = nil
	if callIndex then
		shown = callIndex -- B15: the collapsed list shows the story that is waiting
	elseif entries[1] and entries[1].Pinned then
		shown = 1
	else
		shown = firstClaim or firstDaily or 1
	end

	-- header: progress, claimable count (turns green so claiming stays 1-2 clicks), expand chevron
	local head = (claims >= slots) and TXT.QuestAllDone or string.format(TXT.QuestHeader, claims, slots)
	if claimable > 0 then head ..= string.format(TXT.QuestClaimable, claimable) end
	local hot = claimable > 0
	if IS_TOUCH then
		-- U5: one line (what to do now); tapping it opens the overlay with the rows
		local line = head
		local se = entries[shown]
		local mission = se and se.Pinned and se.TutorialStep >= 0 and se.TutorialStep < 99
		if callIndex then
			line = call.Label -- B15: one tap on the header opens it (the header handler)
		elseif hot and not mission and not (se and se.Pinned and se.CanClaim and se.Progress >= se.Target) then
			line = string.format(TXT.QuestTouchClaim, claimable)
		elseif se then
			local p, t = questNums(se) -- CR-M27 / CR-L31
			line = se.ShowProgress and string.format(TXT.QuestTouchLine, p, t, se.Text) or se.Text
		end
		ui.questHeaderText.Text = line
		ui.questChevron.Text = questState.OverlayOpen and TXT.QuestCollapse or TXT.QuestExpand
		if ui.questOverlayTitle then ui.questOverlayTitle.Text = head end
	else
		ui.questHeaderText.Text = head
		ui.questChevron.Visible = #entries > 1
		ui.questChevron.Text = questExpanded and TXT.QuestCollapse or TXT.QuestExpand
	end
	paint(ui.questHeader, hot and COL.HotTint or COL.White, hot and Theme.Good or ac("Ribbon", Theme.Gold))

	local visibleBefore = 0
	for _, r in questRows do
		if r.Frame.Visible then visibleBefore += 1 end
	end

	local visibleNow = 0
	for i, e in entries do
		local r = questRows[i]
		if not r then
			r = makeQuestRow(i)
			questRows[i] = r
		end
		-- CR-M24: a row whose quest just changed ignores taps for RowLock seconds
		local key = e.Id .. "|" .. tostring(e.Slot) .. "|" .. e.Kind .. "|" .. tostring(e.TutorialStep) .. "|" .. e.Text
		if r.Key ~= key then
			r.Key = key
			r.LockUntil = os.clock() + questState.RowLock
		end
		r.Entry = e
		r.Tap.Visible = e.Pinned or e.Story ~= nil
		r.Frame.Visible = IS_TOUCH or questExpanded or i == shown -- touch: every row, inside the overlay
		if r.Frame.Visible then visibleNow += 1 end
		if e.Story then
			r.Badge.Text = e.Kind == "Main" and TXT.BadgeMain or TXT.BadgeSub
			r.Badge.BackgroundColor3 = e.Kind == "Main" and Theme.XP or COL.Grey
		elseif e.Pinned then
			r.Badge.Text = TXT.BadgePinned
			r.Badge.BackgroundColor3 = Theme.XP
		elseif e.Kind == "Daily" then
			r.Badge.Text = TXT.BadgeDaily
			r.Badge.BackgroundColor3 = Theme.Gold
		else
			r.Badge.Text = TXT.BadgeExtra
			r.Badge.BackgroundColor3 = COL.Grey
		end
		if r.Icon then
			r.Icon.Image = UIKit.ArtId(QUEST_ICON[e.Id] or "IconScroll") or r.Icon.Image
		end
		r.Text.Text = (i == callIndex) and call.Label or e.Text
		r.Text.TextWrapped = not e.ShowProgress
		r.Text.TextTruncate = e.ShowProgress and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
		r.Bar.Visible = e.ShowProgress
		local done = e.Progress >= e.Target
		r.SetBar(e.Progress / e.Target, done and ac("UpgradeGold", Theme.Gold) or ac("QuestBlue", Theme.Good))
		local p, t = questNums(e) -- CR-M27 / CR-L31
		r.BarText.Text = p .. "/" .. t
		local canClaim = done and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub")
		local canReroll = (not done) and (not e.Pinned) and e.Slot ~= nil
		r.Reward.Text = e.RewardGold > 0 and ("+" .. fmtNum(e.RewardGold)) or ""
		r.Reward.Visible = not canClaim -- 받기 covers the reward slot
		if r.Coin then r.Coin.Visible = e.RewardGold > 0 and not canClaim end
		r.Claim.Visible = canClaim
		r.Reroll.Visible = canReroll
		r.Text.Size = UDim2.fromOffset(canReroll and r.TextShort or r.TextLong, r.Text.Size.Y.Offset)
		L.LayoutQuestRow(r, currentScale())
		-- claimable rows turn green (art tint, or the fallback's rim)
		if r.IsArt then
			r.Frame.ImageColor3 = canClaim and COL.RowHotTint or COL.White
		else
			local stroke = r.Frame:FindFirstChild("Stroke")
			if stroke then
				stroke.Color = canClaim and Theme.Good or ac("Rim", COL.Dark)
				stroke.Thickness = canClaim and 3 or 2
			end
		end
	end
	for i = #entries + 1, #questRows do
		local r = questRows[i]
		r.Entry = nil
		r.Frame.Visible = false
	end
	local callRow = callIndex and questRows[callIndex]
	L.SetStoryPulse(callIndex and (IS_TOUCH and ui.questHeader or (callRow and callRow.Frame)) or nil)
	refreshRerollTimers()
	-- CR-L36: the block's visibility also moves the war meter column's left edge
	if visibleBefore ~= visibleNow or blockWasVisible ~= ui.quests.Visible then
		requestLayout()
	end
end

-- desktop: expand / collapse the list; touch: open / close the overlay (open = nil toggles)
toggleQuests = function(open)
	if IS_TOUCH then
		if open == nil then open = not questState.OverlayOpen end
		questState.OverlayOpen = open == true
		if ui.questOverlay then ui.questOverlay.Visible = questState.OverlayOpen end
		requestLayout()
	else
		questExpanded = not questExpanded
	end
	refreshQuests()
end

----------------------------------------------------------------- guide beam (A4 step 1, A7-3 reuse)
local function resolvePart(target)
	if typeof(target) ~= "Instance" then return nil end
	if target:IsA("BasePart") then return target end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	if target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
		return target.Parent
	end
	return target:FindFirstChildWhichIsA("BasePart", true)
end

-- local-only invisible anchor (used when the map has neither the pad nor the gate)
local function localAnchor(zoneId, position)
	local a = guideAnchors[zoneId]
	if a and a.Parent then return a end
	a = Instance.new("Part")
	a.Name = "HUDGuideAnchor_" .. zoneId
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1)
	a.Position = position
	a.Parent = workspace
	guideAnchors[zoneId] = a
	return a
end

-- Crossroads travel pad of the zone, else its gate, else a local anchor at the zone spawn
local function findTravelTarget(zoneId)
	local map = workspace:FindFirstChild("Map")
	local pads = map and map:FindFirstChild("Pads")
	local part = resolvePart(pads and pads:FindFirstChild("Pad_" .. zoneId))
	if part then return part end
	local gates = map and map:FindFirstChild("Gates")
	part = resolvePart(gates and gates:FindFirstChild("Gate_" .. zoneId))
	if part then return part end
	local z = Config.Zones[zoneId]
	if not z then return nil end
	return localAnchor(zoneId, z.Spawn + Vector3.new(0, 3, 0))
end

local function destroyGuide(g)
	if g.Tween then g.Tween:Cancel() end
	for _, inst in { g.Beam, g.Att0, g.Att1, g.Billboard } do
		if inst then inst:Destroy() end
	end
end

function HUD.ClearGuide()
	local g = guide
	guide = nil
	if g then destroyGuide(g) end
end

local function attachGuideToCharacter()
	local g = guide
	if not g or not g.Beam then return end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	if g.Att0 and g.Att0.Parent == root then return end
	if g.Att0 then g.Att0:Destroy() end
	local a0 = Instance.new("Attachment")
	a0.Name = "HUDGuideFrom"
	a0.Parent = root
	g.Att0 = a0
	g.Beam.Attachment0 = a0
end

local function showGuide(target, text, tag, seconds)
	local part = resolvePart(target)
	if not part then return false end
	HUD.ClearGuide()

	local g = { Tag = tag, Part = part }
	local a1 = Instance.new("Attachment")
	a1.Name = "HUDGuideTo"
	a1.Position = Vector3.new(0, part.Size.Y / 2 + 1, 0)
	a1.Parent = part
	g.Att1 = a1

	local beam = Instance.new("Beam") -- no texture asset: the default renders a solid band
	beam.Name = "HUDGuideBeam"
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Theme.Gold)
	beam.Transparency = NumberSequence.new(0.2)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Parent = part
	g.Beam = beam

	local bb = Instance.new("BillboardGui")
	bb.Name = "HUDGuideLabel"
	bb.Adornee = part
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 100000
	bb.Size = UDim2.fromOffset(220, 64)
	bb.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 5, 0)
	UIKit.Create("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = tostring(text or TUT_GUIDE_TEXT),
		TextColor3 = Theme.Gold,
		TextStrokeTransparency = 0,
		Parent = bb,
	})
	bb.Parent = part
	g.Billboard = bb
	g.Tween = TweenService:Create(bb, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		StudsOffset = bb.StudsOffset + Vector3.new(0, 1.5, 0),
	})
	g.Tween:Play()

	guide = g
	attachGuideToCharacter()
	if seconds and seconds > 0 then
		task.delay(seconds, function()
			if guide == g then HUD.ClearGuide() end
		end)
	end
	return true
end

-- public (addendum A7-3): beam from the character to `part` + a floating label; replaces any current guide
function HUD.ShowGuide(part, text)
	local label = (type(text) == "string" and text ~= "") and text or TUT_GUIDE_TEXT
	showGuide(part, label, "custom", nil)
end

local function isZoneGuide(tag)
	return type(tag) == "string" and string.sub(tag, 1, 5) == "zone:"
end

function L.BlacksmithTarget()
	local map = workspace:FindFirstChild("Map")
	local landmarks = map and map:FindFirstChild("Landmarks")
	local guild = landmarks and landmarks:FindFirstChild("ArtisanGuild")
	local anvil = guild and guild:FindFirstChild("Anvil")
	return anvil and anvil:IsA("BasePart") and anvil or nil
end

-- the meadow beam from a faction town first points at that island's bridge (a straight line crossed the water);
-- from the Crossroads it points at the meadow pad
local HOME_BRIDGE = { HaloTown = "Bridge_Halo", HornsTown = "Bridge_Horns" }
function L.MeadowTarget(zone)
	local bridge = HOME_BRIDGE[zone]
	local map = workspace:FindFirstChild("Map")
	local decor = map and map:FindFirstChild("Decor")
	local part = bridge and decor and resolvePart(decor:FindFirstChild(bridge))
	return part or findTravelTarget(TUT_GUIDE_ZONE)
end

-- step 1, or step 2 with kills left (e.g. died mid-mission and respawned in town): guide back to the meadow
function L.NeedsMeadowGuide(step)
	if step == TUT_GUIDE_STEP then return true end
	local quest = (type(TUT.Steps) == "table" and TUT.Steps.Quest) or 2
	return step == quest and num("TutorialKills", 0) < (tonumber(TUT.QuestKills) or 5)
end

-- tutorial step 1: guide to the SlimeMeadow pad; cleared when the step changes or the player enters the zone.
-- Zone guides (Lv 10 / Lv 25) are cleared when the player enters that zone.
local function refreshGuides()
	if attr("DataLoaded", false) ~= true then return end
	local step = num("TutorialStep", 99)
	local zone = attr("ZoneId", "")
	if guide then
		if guide.Tag == "tutorial" and (not L.NeedsMeadowGuide(step) or zone == TUT_GUIDE_ZONE or guide.From ~= zone) then
			HUD.ClearGuide()
		elseif isZoneGuide(guide.Tag) and zone == string.sub(guide.Tag, 6) then
			HUD.ClearGuide()
		elseif guide.Tag == "blacksmith" and (attr("BlacksmithVisited", false) == true or zone ~= "Crossroads") then
			HUD.ClearGuide()
		elseif guide.Tag == "smith:manual" and zone ~= "Crossroads" then
			HUD.ClearGuide()
		end
	end
	if L.NeedsMeadowGuide(step) and zone ~= TUT_GUIDE_ZONE and not (guide and guide.Tag == "tutorial") then
		if showGuide(L.MeadowTarget(zone), TUT_GUIDE_TEXT, "tutorial", nil) and guide then guide.From = zone end
	elseif step == 99 and attr("BlacksmithVisited", false) ~= true and zone == "Crossroads"
		and not (guide and guide.Tag == "blacksmith") then
		showGuide(L.BlacksmithTarget(), "대장간 · 모루와 상호작용", "blacksmith", nil)
	end
end

-- A7-3 reuse: reaching a GuideZones zone's MinLevel during this session -> guide there for GuideSeconds
local function onLevelChanged()
	local level = math.floor(num("Level", 1))
	local prev = prevLevel
	prevLevel = level
	if not levelBaselineReady or prev == nil or level <= prev then return end
	if guide and guide.Tag == "tutorial" then return end
	local zone = attr("ZoneId", "")
	local targetZone = nil
	for _, zoneId in GUIDE_ZONES do
		local z = Config.Zones[zoneId]
		if z and type(z.MinLevel) == "number" and z.MinLevel > prev and z.MinLevel <= level and zone ~= zoneId then
			targetZone = zoneId
		end
	end
	if targetZone then
		local name = tostring(Config.Zones[targetZone].Name)
		showGuide(findTravelTarget(targetZone), string.format(TXT.ZoneGuide, withRo(name)), "zone:" .. targetZone, GUIDE_SECONDS)
	end
end

----------------------------------------------------------------- input
local function inputAllowed()
	if not ui.root or not ui.root.Visible then return false end
	if C and C.Panels and C.Panels.IsOpen() then return false end
	if C and C.WorldMap and C.WorldMap.IsOpen() then return false end
	return true
end

local function swingInterval()
	local def = Config.Classes[getClass()] or Config.Classes.Warrior
	return math.max(0.1, tonumber(def.SwingInterval) or 1)
end

local function clearHolds()
	if next(holdSources) == nil then return end
	table.clear(holdSources)
	holdToken += 1
	pressScale(ui.attack, false)
end

-- One deliberate press sends one Swing; holding no longer attacks repeatedly.
local function startHold(source)
	if source == nil then return end
	local wasHeld = next(holdSources) ~= nil
	holdSources[source] = true
	if wasHeld then return end
	holdToken += 1
	local token = holdToken
	pressScale(ui.attack, true)
	-- ranged classes turn to the nearest monster first; the server only hits what I face (Config AimCone)
	if L.FaceTarget() then
		task.delay(0.08, function() fire("Swing") end) -- let the new facing replicate before the swing
	else
		fire("Swing")
	end

end

local function stopHold(source)
	if source == nil or holdSources[source] == nil then return end
	holdSources[source] = nil
	if next(holdSources) == nil then
		holdToken += 1
		pressScale(ui.attack, false)
	end
end

local function doRelease()
	if throttled("release", 0.2) then return end
	if num("SkillReadyAt", 0) > Util.Now() then return end
	if num("Mana", 0) < Config.BasicSkill.ManaCost then
		if not throttled("skillMana", 1.5) then UIKit.Toast("MP가 부족해요.", "bad", 1.5) end
		return
	end
	if L.FaceTarget() then
		task.delay(0.08, function() fire("Release") end)
	else
		fire("Release")
	end
end

doUpgrade = function()
	if throttled("upgrade", 0.35) then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return end
	if attr("ZoneId", "") ~= "Crossroads" then
		panels.Open("Travel")
		UIKit.Toast("교차로 마을로 이동한 뒤 대장간 모루를 찾아요.", "info", 4)
		return
	end
	showGuide(L.BlacksmithTarget(), "대장간 · 모루와 상호작용", "smith:manual", 30)
	panels.Open("WeaponShop")
end

-- ranged classes (AimCone): face the nearest living monster in range unless one is already in front of me.
-- Returns true when the character was turned. Shift lock keeps its own facing (the camera turns the body).
function L.FaceTarget()
	local def = Config.Classes[getClass()]
	if type(def) ~= "table" or type(def.AimCone) ~= "number" then return false end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return false end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local folder = workspace:FindFirstChild("Monsters")
	if not root or not hum or hum.Health <= 0 or not folder then return false end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local cosCone = math.cos(math.rad(def.AimCone))
	local best, bestDist = nil, (def.Range or 30)
	for _, m in folder:GetChildren() do
		local r = m:FindFirstChild("HumanoidRootPart")
		local mh = m:FindFirstChildOfClass("Humanoid")
		if r and r:IsA("BasePart") and not r.Anchored and (not mh or mh.Health > 0) then
			local dir = (r.Position - root.Position) * Vector3.new(1, 0, 1)
			local d = dir.Magnitude
			if d <= (def.Range or 30) then
				if d > 1 and look.Magnitude > 0.01 and look.Unit:Dot(dir.Unit) >= cosCone then return false end
				if d < bestDist then best, bestDist = r, d end
			end
		end
	end
	if not best or bestDist < 1 then return false end
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(best.Position.X, root.Position.Y, best.Position.Z))
	return true
end

-- story rows: a talk / choice step reopens its dialogue; otherwise travel + the guide beam to where it happens
local STORY_SPOT = { SlimePond = Vector3.new(280, 3, -45) }
function L.StoryTap(st, zone, panels)
	if st.Panel then
		-- B15: my own tap: the server's reply opens the page even mid-fight (auto opens wait for a calm moment)
		if panels and type(panels.ExpectStory) == "function" then pcall(panels.ExpectStory, st.Id) end
		fire("StoryAction", st.Id, "Open")
		return
	end
	local g = st.Guide
	if g == nil then return end
	if g == "Blacksmith" then
		doUpgrade()
		return
	end
	local target = g
	if g == "OwnTown" then target = Config.HomeZoneId(getFaction()) end
	if g == "SlimePond" then target = "SlimeMeadow" end
	if g == "Fountain" or g == "Goose" then target = "Crossroads" end
	if Config.Zones[target] and zone ~= target then
		if panels and panels.Open then panels.Open("Travel") end
		if target == TUT_GUIDE_ZONE then
			if showGuide(L.MeadowTarget(zone), TUT_GUIDE_TEXT, "zone:" .. target, 30) and guide then guide.From = zone end
		else
			showGuide(findTravelTarget(target), tostring(Config.Zones[target].Name), "zone:" .. target, 30)
		end
		return
	end
	if g == "SlimePond" then
		local a = Instance.new("Part")
		a.Name, a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = "HUDStoryAnchor", true, false, false, false, 1
		a.Size, a.Position, a.Parent = Vector3.new(1, 1, 1), STORY_SPOT.SlimePond, workspace
		game:GetService("Debris"):AddItem(a, 35)
		showGuide(a, "연못", "story", 30)
	elseif g == "Fountain" then
		-- the shard in the fountain; MapBuilder only builds Landmarks.Fountain, so fall back to that model and then to a
		-- temporary anchor at Config.StoryQuests.Landmarks.Fountain (the beam must always point somewhere)
		local map = workspace:FindFirstChild("Map")
		local lm = map and map:FindFirstChild("Landmarks")
		local shard = lm and lm:FindFirstChild("CrownShard")
		local part = shard and (shard:IsA("BasePart") and shard or shard:FindFirstChildWhichIsA("BasePart", true))
		local fountain = not part and lm and lm:FindFirstChild("Fountain")
		if fountain then
			part = (fountain:IsA("BasePart") and fountain)
				or (fountain:IsA("Model") and fountain.PrimaryPart) or fountain:FindFirstChildWhichIsA("BasePart", true)
		end
		if not part then
			local spot = Config.StoryQuests and Config.StoryQuests.Landmarks and Config.StoryQuests.Landmarks.Fountain
			if typeof(spot) == "Vector3" then
				part = Instance.new("Part")
				part.Name, part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.Transparency =
					"HUDStoryAnchor", true, false, false, false, 1
				part.Size, part.Position, part.Parent = Vector3.new(1, 1, 1), spot + Vector3.new(0, 4, 0), workspace
				game:GetService("Debris"):AddItem(part, 35)
			end
		end
		local name = Config.StoryQuests and Config.StoryQuests.Speakers and Config.StoryQuests.Speakers.Fountain
		if part then showGuide(part, type(name) == "string" and name or "분수", "story", 30) end
	end
end

-- A23-1: the saved ON/OFF lives on the server; the button only asks to flip it
function L.ToggleAuto()
	if attr("AutoCombatUnlocked", false) ~= true or throttled("autoToggle", 0.4) then return end
	fire("SetAutoAttack", attr("AutoCombatEnabled", false) ~= true)
end

function L.RefreshAuto()
	if not ui.auto then return end
	local unlocked = attr("AutoCombatUnlocked", false) == true and attr("ClassChosen", false) == true
	local on = unlocked and attr("AutoCombatEnabled", false) == true
	ui.auto.Visible = unlocked
	if ui.autoLabel then ui.autoLabel.Text = on and TXT.AutoOn or TXT.AutoOff end
	if ui.autoGlow then ui.autoGlow.Transparency = on and 0 or 1 end
end

-- tapping the pinned guide row: step 0 guide dialogue, step 1/2 travel to the meadow, blacksmith step and the
-- iron-weapon goal -> the existing doUpgrade path, level goals -> the existing beam to the hunting ground.
function L.PinnedTap(e)
	if throttled("pinnedTap", 0.5) then return end
	if IS_TOUCH and questState.OverlayOpen and toggleQuests then toggleQuests(false) end
	local step, zone = e.TutorialStep, attr("ZoneId", "")
	local panels = C and C.Panels
	if e.Story then
		L.StoryTap(e.Story, zone, panels)
		return
	end
	if step == 0 then
		fire("RequestTutorial")
	elseif step == 1 or step == 2 then
		if zone ~= TUT_GUIDE_ZONE then
			if panels and panels.Open then panels.Open("Travel") end
			if showGuide(L.MeadowTarget(zone), TUT_GUIDE_TEXT, "tutorial", nil) and guide then guide.From = zone end
		end
	elseif step == 99 then
		local level = math.floor(num("Level", 1))
		local iron = Config.Weapons[3]
		if not e.NextGoal or (iron and level >= iron.MinLevel and string.find(e.Text, "골드", 1, true)) then
			doUpgrade()
		elseif zone ~= TUT_GUIDE_ZONE then
			showGuide(findTravelTarget(TUT_GUIDE_ZONE), TUT_GUIDE_TEXT, "zone:" .. TUT_GUIDE_ZONE, 30)
		else
			UIKit.Toast("슬라임과 큰 슬라임을 사냥해 경험치를 모아요.", "info", 3)
		end
	end
end

openMenu = function()
	if throttled("menu", 0.25) then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" then return end
	if type(panels.IsOpen) == "function" and type(panels.Close) == "function" then
		local ok, open = pcall(panels.IsOpen)
		if ok and open then
			pcall(panels.Close, true)
			return
		end
	end
	if type(panels.Open) == "function" then
		local ok, err = pcall(panels.Open, "Menu")
		if not ok then warnThrottled("Panels.Open failed: " .. tostring(err)) end
	end
end

-- 지도 square (same toggle as WorldMap's M key)
openMap = function()
	if throttled("map", 0.25) then return end
	local wm = C and C.WorldMap
	if type(wm) == "table" and type(wm.Toggle) == "function" then
		local ok, err = pcall(wm.Toggle)
		if not ok then warnThrottled("WorldMap.Toggle failed: " .. tostring(err)) end
	end
end

local function onInputBegan(input, gameProcessed)
	-- B also closes an open panel (inputAllowed is false while a panel covers the screen)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.B and C and C.Panels
		and type(C.Panels.IsOpen) == "function" and C.Panels.IsOpen() then
		openMenu()
		return
	end
	if gameProcessed or not inputAllowed() then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.Keyboard then
		local k = input.KeyCode
		if k == Enum.KeyCode.F then
			startHold("keyF")
		elseif k == Enum.KeyCode.Q then -- E is the Roblox-standard interact key (blacksmith / altar / merchant prompts)
			doRelease()
		elseif k == Enum.KeyCode.U then
			doUpgrade()
		elseif k == Enum.KeyCode.R then
			L.ToggleAuto()
		elseif k == Enum.KeyCode.B then
			openMenu() -- U1: Esc belongs to Roblox
		end -- M is bound by WorldMap (A12)
	elseif t == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			startHold("padR2")
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			doRelease()
		end
	end
end

-- releases are handled even when gameProcessed (e.g. the mouse is let go over a button)
local function onInputEnded(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		stopHold("mouse")
		for src in holdSources do
			if typeof(src) == "Instance" and src:IsA("InputObject") and src.UserInputType == Enum.UserInputType.MouseButton1 then
				stopHold(src)
			end
		end
	elseif t == Enum.UserInputType.Touch then
		stopHold(input)
	elseif t == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.F then stopHold("keyF") end
	elseif t == Enum.UserInputType.Gamepad1 then
		if input.KeyCode == Enum.KeyCode.ButtonR2 then stopHold("padR2") end
	end
end

local function bindButtonInput()
	ui.attack.InputBegan:Connect(function(input)
		if not isPressInput(input) or input.UserInputState ~= Enum.UserInputState.Begin then return end
		if not inputAllowed() then return end
		startHold(input)
		local conn
		conn = input.Changed:Connect(function(prop)
			if prop ~= "UserInputState" then return end
			local s = input.UserInputState
			if s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
				conn:Disconnect()
				stopHold(input)
			end
		end)
	end)
	ui.release.InputBegan:Connect(function(input)
		if not isPressInput(input) or input.UserInputState ~= Enum.UserInputState.Begin then return end
		if not inputAllowed() then return end
		pressScale(ui.release, true)
		doRelease()
	end)
	ui.release.InputEnded:Connect(function(input)
		if isPressInput(input) then pressScale(ui.release, false) end
	end)
	ui.release.MouseLeave:Connect(function()
		pressScale(ui.release, false)
	end)
end

----------------------------------------------------------------- layout (H4 top inset, H5 jump button, M1 scale)
local function findJumpButton()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local tg = pg and pg:FindFirstChild("TouchGui")
	if not tg then return nil end
	if tg:IsA("ScreenGui") and not tg.Enabled then return nil end
	local frame = tg:FindFirstChild("TouchControlFrame")
	local jb = frame and frame:FindFirstChild("JumpButton")
	if jb and jb:IsA("GuiObject") then return jb end
	return nil
end

local function hookJumpButton(jb)
	if jumpButton == jb then return end
	for _, c in jumpConns do
		c:Disconnect()
	end
	table.clear(jumpConns)
	jumpButton = jb
	if jb then
		table.insert(jumpConns, jb:GetPropertyChangedSignal("AbsolutePosition"):Connect(requestLayout))
		table.insert(jumpConns, jb:GetPropertyChangedSignal("AbsoluteSize"):Connect(requestLayout))
	end
	requestLayout()
end

applyLayout = function()
	local gui = UIKit and UIKit.Gui
	if not gui or not ui.root then return end
	local s = currentScale()
	local abs = gui.AbsoluteSize
	if abs.X < 10 or abs.Y < 10 then return end
	local W, H = abs.X / s, abs.Y / s
	L.LayoutStats(s)
	ui.questHeader.Size = UDim2.fromOffset(L.QuestW, math.max(L.QuestHeaderH, math.ceil(20 / s)))
	for _, row in questRows do L.LayoutQuestRow(row, s) end
	for label in ui.textFits or {} do
		if label.Name == "KeyHint" then
			local keyH = math.max(18, math.ceil(12 / s))
			label.Size = UDim2.fromOffset(keyH, keyH)
		end
	end
	local inset = insetY()
	local shift = inset / s -- slot-table y values are measured from below the top bar
	local minTop = (inset + TOP_PAD) / s -- H4 / U4: never above inset + 8 real px

	-- top-anchored blocks
	local statsY = math.max(12 + shift, minTop)
	-- desktop: the Roblox chat window sits top-left too, so start the card below it
	local chatBottom = (not IS_TOUCH) and chatWindowBottom(inset, s, abs.Y) or nil
	if chatBottom then statsY = math.max(statsY, chatBottom / s + 8) end
	ui.stats.Position = UDim2.fromOffset(12, statsY)
	local warY = math.max(8 + shift, minTop)
	-- CR-L36: the war meter column (EventHUD's strip and the chips follow it) fits between the player card and the
	-- desktop luck panel: narrow screens shrink it to >= WarMinW and slide its centre off the card. The quest block
	-- under the card counts too (touch: header 260 wide vs card 212, level with the strip / chips rows)
	local leftBlockW = ui.stats.Size.X.Offset
	if ui.quests and ui.quests.Visible then leftBlockW = math.max(leftBlockW, ui.quests.Size.X.Offset) end
	local leftX = 12 + leftBlockW + 8
	local rightX = W - 12
	if not IS_TOUCH then
		local luck = gui:FindFirstChild("LuckCorner")
		local luckW = (luck and luck:IsA("GuiObject") and luck.Size.X.Offset > 0) and luck.Size.X.Offset or L.LuckW
		rightX -= luckW + 8
	end
	local warW = math.floor(math.clamp(rightX - leftX, L.WarMinW, L.WarW))
	local cx = math.clamp(W / 2, leftX + warW / 2, math.max(leftX + warW / 2, rightX - warW / 2))
	cx = math.floor(cx + 0.5)
	-- set before the frames move, so EventHUD's relayout (on the meter's size / position signals) reads the new values
	HUD.TopCenterX, HUD.TopCenterW = cx, warW
	if ui.war.Size.X.Offset ~= warW then ui.war.Size = UDim2.fromOffset(warW, L.WarH) end
	ui.war.Position = UDim2.new(0, cx, 0, warY)
	-- chips under EventHUD's strip, which itself follows the war meter's bottom; centred on the same column, as wide
	-- as fits symmetrically between the card and the right edge (wrapping to a second row only when that is full)
	local chipsW = math.floor(math.max(warW, 2 * math.min(cx - leftX, rightX - cx)))
	if ui.chips.Size.X.Offset ~= chipsW then ui.chips.Size = UDim2.fromOffset(chipsW, L.ChipH + 6) end
	ui.chips.Position = UDim2.new(0, cx, 0, math.max(L.ChipsY + shift, minTop, warY + L.WarH + L.StripBelow))

	-- quests right under the card (collapsed by default, so the list stays short)
	local statsBottom = statsY + ui.stats.Size.Y.Offset
	ui.potions.Position = UDim2.fromOffset(12, statsBottom + 4)
	ui.quests.Position = UDim2.fromOffset(12, statsBottom + L.PotionH + 10)

	-- touch quest overlay (CR-M25): top band, right of the thumbstick zone's x range (U3)
	if ui.questOverlay then
		local ow = L.OverlayW
		local ox = math.max(W * L.StickZoneX + 8, (W - ow) / 2)
		ox = math.max(12, math.min(ox, W - 12 - ow))
		ui.questOverlay.Position = UDim2.fromOffset(ox, minTop)
	end

	-- big buttons: attack up-left of the touch jump button (H5 / U2); no jump button on a mouse device: 발사 in the
	-- bottom-right corner with 공격 to its left (mockup order)
	local AR, RR = L.Attack / 2, L.Release / 2
	local SQ, GAP, RG = L.Square, L.BtnGap, L.RowGap
	local ax, ay
	local cornerRelease = false
	local jb = jumpButton
	if jb and jb.Parent and jb.AbsoluteSize.X > 0 then
		local rel = jb.AbsolutePosition - gui.AbsolutePosition
		ax = rel.X / s - GAP - AR
		ay = rel.Y / s + (jb.AbsoluteSize.Y / s) * 0.2
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		ax, ay = W + ATTACK_FALLBACK.X, H + ATTACK_FALLBACK.Y
	else
		cornerRelease = true
		ax, ay = W - L.Edge - 2 * RR - GAP - AR, H - L.Edge - AR
	end
	-- top of the square row + next-weapon card column: desktop puts it right under EventHUD's luck panel (mockup);
	-- touch (luck panel hidden) stacks it above the attack button, so it only needs room below the top inset
	local colTop = minTop
	if not IS_TOUCH then
		local luck = gui:FindFirstChild("LuckCorner")
		local luckBottom = luck and luck:GetAttribute("BottomY")
		if type(luckBottom) ~= "number" or luckBottom ~= luckBottom then
			luckBottom = math.max(L.LuckY, minTop) + L.LuckH
		end
		colTop = luckBottom + RG
	end
	-- keep the attack button below that column
	local column = SQ + RG + L.UpgradeH + GAP
	local axMax = cornerRelease and (W - AR - GAP - 2 * RR - 8) or (W - AR - 8)
	local axMin = cornerRelease and (AR + 8) or (AR + 2 * RR + GAP + 8)
	local ayMax = H - AR - 8
	ax = math.clamp(ax, math.min(axMax, axMin), axMax)
	ay = math.clamp(ay, math.min(ayMax, colTop + column + AR + 8), ayMax)
	ui.attack.Position = UDim2.fromOffset(ax, ay)
	local rx, ry
	if cornerRelease then
		-- bottoms level with 공격's
		rx, ry = ax + AR + GAP + RR, math.min(ay + AR - RR, H - RR - 8)
	else
		rx, ry = ax - AR - GAP - RR, math.min(ay + AR * 0.25, H - RR - 8)
	end
	ui.release.Position = UDim2.fromOffset(rx, ry)

	-- 자동 / 지도 / 메뉴 right-aligned with the next-weapon card above them (mockup order). Desktop: a top-right column
	-- under the luck panel; touch: above the attack button
	local right = W - 12
	local rowW = 3 * SQ + 2 * RG
	local rowY
	if IS_TOUCH then
		rowY = ay - AR - GAP - SQ / 2
	else
		rowY = colTop + L.UpgradeH + RG + SQ / 2
	end
	ui.menu.Position = UDim2.fromOffset(right - SQ / 2, rowY)
	ui.map.Position = UDim2.fromOffset(right - SQ * 1.5 - RG, rowY)
	if ui.auto then ui.auto.Position = UDim2.fromOffset(right - SQ * 2.5 - RG * 2, rowY) end
	ui.upgrade.Position = UDim2.fromOffset(right - rowW / 2, rowY - SQ / 2 - RG - L.UpgradeH / 2)

	-- CR-L37: top / left edge of the bottom-right button cluster (공격 + 발사; on touch also the square row and, while
	-- it shows, the next-weapon card above it). EventHUD keeps its personal line above ClusterTop.
	local clusterTop = math.min(ay - AR, ry - RR)
	local clusterLeft = math.min(ax - AR, rx - RR)
	if IS_TOUCH then
		clusterTop = math.min(clusterTop, rowY - SQ / 2)
		clusterLeft = math.min(clusterLeft, right - rowW)
		if ui.upgrade.Visible then clusterTop = math.min(clusterTop, rowY - SQ / 2 - RG - L.UpgradeH) end
	end
	HUD.Layout = {
		W = W,
		H = H,
		Scale = s,
		ClusterTop = math.floor(clusterTop),
		ClusterLeft = math.floor(clusterLeft),
		TopCenterX = cx,
		TopCenterW = warW,
	}
end

----------------------------------------------------------------- visibility + timer loop
local function refreshVisibility()
	local visible = attr("DataLoaded", false) == true and not pickersOpen()
	if ui.root.Visible ~= visible then
		ui.root.Visible = visible
		if not visible then clearHolds() end
	end
	return visible
end

local function onCharacterAdded(character)
	clearHolds()
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and guide then attachGuideToCharacter() end
	end)
end

local function tick()
	tickCount += 1
	if not refreshVisibility() then return end
	refreshWarTime()
	refreshChips()
	refreshSkill()
	refreshTravel()
	refreshRerollTimers()
	-- B15: Panels holding back / releasing a story page re-draws the quest rows (label + pulse)
	local call = L.StoryPending()
	if (call and (call.Id .. "|" .. tostring(call.St)) or "") ~= questState.StoryKey then refreshQuests() end
	if tickCount % 5 == 0 then
		refreshMenuGlow() -- B14: the item hint (a scroll, item list not opened yet) has no attribute of its own
		if UserInputService.TouchEnabled then
			local jb = findJumpButton()
			if jb ~= jumpButton then hookJumpButton(jb) end
		end
		applyLayout()
		refreshGuides()
	end
end

----------------------------------------------------------------- lifecycle
function HUD.Init(registry)
	C = registry
	UIKit = C and C.UIKit
	if type(UIKit) ~= "table" or not UIKit.Gui then
		error("UIKit is not initialized")
	end
	Theme = UIKit.Theme

	ui.root = UIKit.Create("Frame", {
		Name = "HUD",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = UIKit.Gui,
	})

	-- CR-L50: listen to the quest list remote inside Init (synchronously, before any Start) so the first list is
	-- never missed. Bound before the build* steps: if one of them throws, Start still runs (ui.root exists) and the
	-- list must still arrive (onQuests only stores it until Start). Never yields here: a missing remote (old server)
	-- is bound later from a background wait.
	local function bindQuests(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(onQuests, payload)
			if not ok then warnThrottled("Quests handler error: " .. tostring(err)) end
		end)
	end
	local questsRemote = remote("Quests")
	if questsRemote then
		bindQuests(questsRemote)
	else
		task.spawn(function()
			local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
			local r = folder and folder:WaitForChild("Quests", 30)
			if r and r:IsA("RemoteEvent") then
				bindQuests(r)
			else
				warnThrottled("remote missing: Quests")
			end
		end)
	end

	buildStats(ui.root)
	buildWar(ui.root)
	buildChips(ui.root)
	buildQuests(ui.root)
	buildTravel(ui.root)
	buildButtons(ui.root)
end

function HUD.Start()
	if not ui.root then
		Util.Warn("HUD", "HUD was not built (Init failed); HUD disabled")
		return
	end

	-- visibility itself is owned by the 0.2 s loop: the pickers start after HUD, so checking IsOpen() here could
	-- flash the HUD for a frame before the faction picker opens
	UIKit.OnAttr({ "DataLoaded" }, function()
		if attr("DataLoaded", false) == true and not levelBaselineReady then
			levelBaselineReady = true
			prevLevel = math.floor(num("Level", 1))
		end
		refreshGuides()
	end)
	UIKit.OnAttr({ "Level", "XP", "Faction", "Class", "Honor", "Infamy", "FallMarks", "RedeemMarks", "SessionTitle",
		"BankGold", "CarriedGold", "WantedStars", "Bounty" }, refreshStats)
	UIKit.OnAttr({ "Faction", "Class", "ClassChosen", "CharacterGender", "SizeMult" }, L.RefreshPortrait)
	UIKit.OnAttr({ "AutoCombatUnlocked", "AutoCombatEnabled", "ClassChosen" }, L.RefreshAuto)
	-- 2026-10-06 playtest: on a short desktop window the bottom-left chat window + input bar sat on top of the quest
	-- rows and swallowed the [받기] click (CoreGui wins). Desktop chat goes to the bottom middle, which the HUD leaves free.
	if not IS_TOUCH then
		pcall(function()
			local cw = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
			if cw then
				cw.HorizontalAlignment = Enum.HorizontalAlignment.Center
				cw.VerticalAlignment = Enum.VerticalAlignment.Bottom
				cw.WidthScale = math.min(cw.WidthScale, 0.7)
				cw.HeightScale = math.min(cw.HeightScale, 0.7)
			end
		end)
	end
	-- auto combat + ranged class: while I stand still, keep facing the nearest monster so the server's aim cone fits
	task.spawn(function()
		while true do
			task.wait(0.25)
			if attr("AutoCombatEnabled", false) == true then
				local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.MoveDirection.Magnitude < 0.1 then pcall(L.FaceTarget) end
			end
		end
	end)
	UIKit.OnAttr({ "Mana", "SkillReadyAt" }, refreshSkill)
	UIKit.OnAttr({ "WeaponTier", "Level", "Class", "Faction", "BankGold", "CarriedGold", "ZoneId" }, refreshUpgrade)
	UIKit.OnAttr({ "Level", "Rebirths", "VacationDays" }, refreshMenuGlow)
	questState.Started = true -- CR-L50: "Quests" remote payloads refresh the rows from now on
	UIKit.OnAttr({ "DailyClaims", "RerollReadyAt" }, refreshQuests) -- the list itself comes from onQuests
	UIKit.OnAttr({ "ZoneTown", "ZonePvP", "Rookie", "Protected", "InCombatUntil", "SizeMult", "BullyStacks",
		"KaijuState", "Faction" }, refreshChips)
	UIKit.OnAttr({ "WarPoints", "Faction" }, refreshWar)
	UIKit.OnGameAttr({ "WarHaloScore", "WarHornsScore", "WarMode", "WarBlessing", "WarRoundEndsAt" }, refreshWar)
	UIKit.OnAttr({ "TravelingUntil" }, refreshTravel)
	UIKit.OnAttr({ "TutorialStep", "ZoneId", "BlacksmithVisited", "TutorialKills" }, refreshGuides)
	UIKit.OnAttr({ "Level" }, onLevelChanged)

	bindButtonInput()
	task.spawn(placeLegacyChat)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.WindowFocusReleased:Connect(clearHolds)

	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
	LocalPlayer.CharacterAdded:Connect(L.RefreshPortrait)
	LocalPlayer.CharacterRemoving:Connect(L.PortraitRemoving)
	LocalPlayer.CharacterAppearanceLoaded:Connect(L.RefreshPortrait)

	-- layout follows viewport / UIScale / top-bar changes
	UIKit.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(requestLayout)
	local scale = UIKit.Gui:FindFirstChildOfClass("UIScale")
	if scale then
		scale:GetPropertyChangedSignal("Scale"):Connect(requestLayout)
	end

	-- H5: touch devices wait (bounded) for the jump button, then lay the buttons out around it
	if UserInputService.TouchEnabled then
		task.spawn(function()
			local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local tg = pg and pg:WaitForChild("TouchGui", JUMP_WAIT)
			local frame = tg and tg:WaitForChild("TouchControlFrame", JUMP_WAIT)
			local jb = frame and frame:WaitForChild("JumpButton", JUMP_WAIT)
			if jb and jb:IsA("GuiObject") then
				hookJumpButton(jb)
			end
		end)
	end

	-- A world click attacks only after release; a left drag belongs to camera rotation.
	C.CameraFollow.PrimaryClick:Connect(function()
		if inputAllowed() then fire("Swing") end
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick)
			if not ok then warnThrottled("tick error: " .. tostring(err)) end
		end
	end)

	requestLayout()
	task.delay(1, requestLayout)

	print("[HUD] started")
end

return HUD
