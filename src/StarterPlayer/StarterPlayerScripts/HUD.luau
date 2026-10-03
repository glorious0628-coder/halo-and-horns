-- HUD.luau : player card, war meter, status chips, quest tracker (claim / reroll / pinned tutorial), next-weapon card,
-- 자동 / 지도 / 메뉴 squares and the attack / release buttons with the charge ring, keyboard / mouse / touch / gamepad
-- input, travel bar and the guide beam (TECH_SPEC §4.23 HUD; addendum A3-H4/H5/M1, A4 step 1, A5-C6/N1, A6 Neutral,
-- A7-3 next goal, A14 compact HUD drawn with the GPT art parts of Config.UIArt through UIKit.Art*).
-- Client only: reads attributes / GameState / the Fx remote, writes only client->server intents.
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
	StatsH = IS_TOUCH and 68 or 100,
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

local REWARD_SAMPLES = NEXT.RewardSamples or 10
local MAX_KILLS_SHOWN = NEXT.MaxKillsShown or 99
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
	Claim = "받기",
	Reroll = "교체", -- Gotham has no ↻ glyph (rendered as tofu)
	RerollTitle = "퀘스트 바꾸기", -- CR-M25 confirm dialog
	RerollBody = "진행도가 사라져요. 바꿀까요?",
	RerollYes = "바꾸기",
	Attack = "공격",
	Release = "발사",
	Perfect = "PERFECT!",
	AutoOn = "자동 ON",
	AutoOff = "자동 OFF",
	AutoLocked = "Lv%d 해금",
	UpgradeNext = "다음: %s",
	UpgradePrice = "%sG",
	UpgradeMax = "최고 등급",
	UpgradeNeedLevel = "Lv %d 필요",
	UpgradeNeedFaction = "진영 선택 필요",
	UpgradeReady = "구매 가능!",
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

local recentGold = {} -- gold of the last REWARD_SAMPLES kill rewards (Fx "Reward")
local prevLevel = nil
local levelBaselineReady = false

local perfectOn = false
local perfectTween = nil
local menuGlowOn = nil
local menuGlowTween = nil
local afford = { Baseline = false, Was = false, Streak = 0, Notified = {} }

local questRows = {}
local questExpanded = false -- collapsed list shows the header + one row
-- CR-M24: 교체 is ignored for ClaimLock s after a claim and a row for RowLock s after its quest changed;
-- CR-M25: touch opens the rows' overlay from the header (OverlayOpen)
local questState = { ClaimAt = -math.huge, ClaimLock = 1.5, RowLock = 0.8, OverlayOpen = false }
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
	for _, name in { "FactionPicker", "ClassPicker" } do
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

-- false when the text has a symbol Gotham / the Korean fallback font lacks (⚙ ⚔ ↻ render as tofu boxes)
local SAFE_SYMBOLS = { [0x2190] = true, [0x2192] = true, [0x25B2] = true, [0x25B6] = true, [0x25BC] = true,
	[0x2605] = true, [0x2606] = true }
local function glyphSafe(text)
	local ok, safe = pcall(function()
		for _, cp in utf8.codes(text) do
			if cp >= 0x2190 and cp <= 0x2BFF and not SAFE_SYMBOLS[cp] then return false end
		end
		return true
	end)
	return ok and safe == true
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
	return touchFloor(label)
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
	return artLabel(false, {
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
	})
end

-- PanelCard (gold rim, navy inside). Desktop: portrait ring + avatar headshot (U7), level badge, title / class, XP
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
		Position = facePos or UDim2.fromScale(0.17, 0.18),
		Size = faceSize or UDim2.fromScale(0.65, 0.61),
		Parent = badge,
	})
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
		artLabel(false, {
			Name = "Tag",
			Position = UDim2.fromScale(0, -0.06),
			Size = UDim2.fromScale(1, 0.42),
			TextScaled = true,
			MaxTextSize = 11,
			Number = true,
			Text = TXT.LevelTag,
			Parent = face,
		})
		ui.level = artLabel(false, {
			Name = "Level",
			Position = UDim2.fromScale(0, 0.32),
			Size = UDim2.fromScale(1, 0.7),
			TextScaled = true,
			MaxTextSize = 20,
			Number = true,
			Color = ac("GoldText", Theme.Gold),
			Text = "1",
			Parent = face,
		})
	end

	local x0 = IS_TOUCH and 62 or 80 -- left edge of the XP bar / money column
	if not IS_TOUCH then
		-- portrait: avatar headshot (rbxthumb, no upload) inside the gold PortraitRing (U7)
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
	end

	-- XP bar on the BarTrack art (bright blue fill)
	local barW = W - x0 - (IS_TOUCH and 14 or 12)
	local _, setXP, xpText = UIKit.ArtBar({
		Name = "XPBar",
		Position = UDim2.fromOffset(x0, IS_TOUCH and 13 or 48),
		Size = UDim2.fromOffset(barW, IS_TOUCH and 20 or 16),
		Color = ac("XPBlue", Theme.XP),
		TextSize = IS_TOUCH and L.TouchText or 12,
		Parent = f,
	})
	ui.setXP = setXP
	ui.xpText = xpText

	if IS_TOUCH then
		ui.bank = moneyLine(f, "Bank", "IconCoin", x0, 36, barW)
	else
		local half = math.floor((barW - 6) / 2)
		ui.bank = moneyLine(f, "Bank", "IconCoin", x0, 68, half)
		ui.carried = moneyLine(f, "Carried", "IconPouch", x0 + half + 6, 68, barW - half - 6)
	end

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
	local bar, barArt = UIKit.ArtFrame("BarTrack", {
		Name = "Bar",
		Position = UDim2.fromOffset(shieldW - 10, barY),
		Size = UDim2.fromOffset(W - 2 * (shieldW - 10), barH),
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
		Size = UDim2.fromOffset(W, 20),
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
	ui.chips = UIKit.Create("Frame", {
		Name = "StatusChips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, L.ChipsY + TOP_FALLBACK),
		Size = UDim2.fromOffset(900, L.ChipH + 6),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
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
		touchFloor(closeLabel)
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
	UIKit.Create("TextLabel", {
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
	})
end

local toggleAuto, doUpgrade, openMenu, openMap -- forward (defined with the input code)

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
	keyHint(ui.attack, "F", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- 발사: gold disc + winged star, charge count badge on the top edge, the charge ring around it
	local rel, relArt = roundButton("Release", L.Release, "BtnSpecial", COL.ReleaseFill)
	ui.release, ui.releaseArt = rel, relArt
	-- charge gauge: a disc behind the button filling bottom-up (UIGradient "Level"), visible as a ring around it
	local gauge = UIKit.Create("Frame", {
		Name = "Gauge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.16, 1.16),
		BackgroundColor3 = ac("NavyDeep", COL.ReleaseFill),
		BackgroundTransparency = 0.2,
		ZIndex = 1,
		Parent = rel,
	}, {
		corner(UDim.new(0.5, 0)),
		UIKit.Create("UIStroke", {
			Name = "Ring",
			Thickness = 4,
			Color = COL.RingIdle,
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	ui.ring = gauge:FindFirstChild("Ring")
	ui.chargeFill = UIKit.Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COL.Charge,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gauge,
	}, {
		corner(UDim.new(0.5, 0)),
		UIKit.Create("UIGradient", { Name = "Level", Rotation = -90 }),
	})
	ui.chargeGradient = ui.chargeFill:FindFirstChild("Level")
	ui.releaseIcon = UIKit.ArtImage("IconSpecial", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.56, 0.34),
		ZIndex = 3,
		Parent = rel,
	})
	ui.chargeSub = artLabel(false, {
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
	ui.chargeTimer = artLabel(false, {
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
	local countBadge = UIKit.ArtFrame("LevelBadge", {
		Name = "CountBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.44, 0.44),
		ZIndex = 5,
		Parent = rel,
	}, { StrokeThickness = 2 })
	local facePos, faceSize = UIKit.ArtInner("LevelBadge")
	ui.chargeNum = artLabel(false, {
		Name = "Count",
		Position = facePos or UDim2.fromScale(0.17, 0.18),
		Size = faceSize or UDim2.fromScale(0.65, 0.61),
		TextScaled = true,
		MaxTextSize = 22,
		Number = true,
		Text = "0",
		Parent = countBadge,
	})
	keyHint(rel, "Q", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- 자동 / 지도 / 메뉴 (U1: the menu key is B; Esc belongs to Roblox and M opens the map)
	ui.auto, ui.autoLabel, ui.autoIcon = squareButton("Auto", "IconLock", TXT.AutoOff, "R", function()
		toggleAuto()
	end)
	ui.map = squareButton("Map", "IconMap", TXT.Map, "M", function()
		openMap()
	end)
	ui.menu, ui.menuLabel = squareButton("Menu", "IconGear", TXT.Menu, "B", function()
		openMenu()
	end)
	ui.menuGlow = makeGlow(ui.menu, UDim.new(0, 12))

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
	keyHint(ui.upgrade, "U", UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
end

----------------------------------------------------------------- refresh: stats
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
	local h = L.StatsH + (horns and L.StarsH or 0)
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

	setChip(ui.chip.Rookie, attr("Rookie", false) == true and f ~= "Neutral", TXT.Rookie, Theme.XP, false, pal.Rookie, true)
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

----------------------------------------------------------------- refresh: charge ring / release
local function setChargeFill(f)
	f = math.clamp(f, 0, 1)
	if f <= 0.002 then
		ui.chargeFill.Visible = false
		return
	end
	ui.chargeFill.Visible = true
	if f >= 0.995 then
		ui.chargeGradient.Transparency = NumberSequence.new(0)
	else
		ui.chargeGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(f, 0),
			NumberSequenceKeypoint.new(math.min(f + 0.004, 0.999), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function refreshCharge()
	local charge = math.max(0, num("Charge", 0))
	local cap = num("ChargeCap", 0)
	if cap <= 0 then cap = factionDef(getFaction()).ChargeCap or 150 end
	local n = math.floor(charge)
	ui.chargeNum.Text = tostring(n)
	setChargeFill(charge / cap)
	local ready = n >= Config.Charge.MinRelease
	ui.chargeNum.TextColor3 = ready and Theme.Text or COL.Grey
	if isImage(ui.releaseArt) then
		ui.releaseArt.ImageColor3 = ready and COL.White or COL.DimTint
	elseif ui.releaseArt then
		ui.releaseArt.BackgroundTransparency = ready and 0.05 or 0.35
	end
	if not perfectOn then
		ui.chargeFill.BackgroundColor3 = (charge >= cap) and Theme.Gold or COL.Charge
		ui.chargeFill.BackgroundTransparency = ready and 0.15 or 0.45
		ui.ring.Color = ready and Theme.Gold or COL.RingIdle
		ui.ring.Transparency = ready and 0.15 or 0.35
	end
end

local function setPerfect(on)
	if on == perfectOn then return end
	perfectOn = on
	if perfectTween then
		perfectTween:Cancel()
		perfectTween = nil
	end
	if ui.releaseIcon then ui.releaseIcon.Visible = not on end -- the countdown takes the icon's spot
	if on then
		ui.ring.Color = Theme.Gold
		ui.ring.Transparency = 0
		ui.ring.Thickness = 6
		perfectTween = TweenService:Create(ui.ring,
			TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 12 })
		perfectTween:Play()
		ui.chargeSub.Text = TXT.Perfect
		ui.chargeSub.TextColor3 = Theme.Gold
		ui.chargeTimer.Visible = true
		ui.chargeFill.BackgroundColor3 = Theme.Gold
		ui.chargeFill.BackgroundTransparency = 0.05
	else
		ui.ring.Thickness = 4
		ui.chargeSub.Text = TXT.Release
		ui.chargeSub.TextColor3 = Theme.Text
		ui.chargeTimer.Visible = false
		refreshCharge()
	end
end

local function refreshPerfect()
	local untilT = num("PerfectUntil", 0)
	local remaining = untilT - Util.Now()
	setPerfect(untilT > 0 and remaining > 0)
	if perfectOn then
		ui.chargeTimer.Text = string.format("%.1f", math.max(0, remaining))
	end
end

----------------------------------------------------------------- refresh: auto / upgrade / menu
local function refreshAuto()
	local unlock = Config.Combat.AutoUnlockLevel
	local locked = num("Level", 1) < unlock
	local on = (not locked) and attr("AutoAttack", false) == true
	if locked then
		ui.autoLabel.Text = string.format(TXT.AutoLocked, unlock)
	else
		ui.autoLabel.Text = on and TXT.AutoOn or TXT.AutoOff
	end
	ui.autoLabel.TextColor3 = locked and ac("InkSoft", COL.Grey) or ac("Ink", COL.Dark)
	if locked then
		paint(ui.auto, COL.LockedTint, ac("ParchmentDark", COL.Grey))
	elseif on then
		paint(ui.auto, COL.HotTint, Theme.Good)
	else
		paint(ui.auto, COL.White, ac("Parchment", Theme.SubText))
	end
	if ui.autoIcon then
		ui.autoIcon.Image = UIKit.ArtId(locked and "IconLock" or "IconAttack") or ui.autoIcon.Image
	end
end

local function upgradeInfo()
	local tier = math.floor(num("WeaponTier", 1))
	local level = math.floor(num("Level", 1))
	local f = getFaction()
	local total = math.max(0, num("BankGold", 0)) + math.max(0, num("CarriedGold", 0))
	local nextDef = Config.Weapons[tier + 1]
	if tier >= Config.MaxWeaponTier or not nextDef then
		return { Max = true, Total = total, Level = level }
	end
	return {
		Max = false,
		Tier = tier + 1,
		Name = Config.WeaponName(tier + 1, getClass(), f),
		Price = nextDef.Price or 0,
		MinLevel = nextDef.MinLevel or 1,
		LevelShort = level < (nextDef.MinLevel or 1),
		NeedFaction = nextDef.RequiresFaction == true and f == "None",
		Total = total,
		Level = level,
	}
end

local function avgRecentGold()
	if #recentGold == 0 then return 0 end
	local sum = 0
	for _, g in recentGold do
		sum += g
	end
	return sum / #recentGold
end

-- the monster the player is (most likely) farming: current zone's main monster, else the level's quest zone
local function farmMonsterName(level)
	local zoneId = attr("ZoneId", "")
	local id = Config.ZoneMainMonster[zoneId] or Config.ZoneMainMonster[Config.QuestZoneForLevel(level)]
	local def = id and Config.MonsterTypes[id]
	return def and def.Name or TXT.Monster
end

local function refreshUpgrade()
	local info = upgradeInfo()
	local canBuy = false
	if info.Max then
		ui.upgradeTitle.Text = TXT.UpgradeMax
		ui.upgradePrice.Text = ""
		ui.setUpgrade(1, ac("UpgradeGold", Theme.Gold))
		ui.upgradeText.Text = ""
	else
		ui.upgradeTitle.Text = string.format(TXT.UpgradeNext, tostring(info.Name))
		ui.upgradePrice.Text = string.format(TXT.UpgradePrice, fmtNum(info.Price))
		local frac = info.Price > 0 and (info.Total / info.Price) or 1
		if info.LevelShort then
			ui.setUpgrade(frac, COL.Grey)
			ui.upgradeText.Text = string.format(TXT.UpgradeNeedLevel, info.MinLevel)
		elseif info.NeedFaction then
			ui.setUpgrade(frac, COL.Grey)
			ui.upgradeText.Text = TXT.UpgradeNeedFaction
		elseif info.Total >= info.Price then
			canBuy = true
			ui.setUpgrade(1, Theme.Good)
			ui.upgradeText.Text = TXT.UpgradeReady
		else
			ui.setUpgrade(frac, ac("UpgradeGold", Theme.Gold))
			local text = fmtNum(info.Total) .. " / " .. fmtNum(info.Price)
			-- A7-3: "<몬스터> N마리 더!" from the average of the last kill rewards
			local avg = avgRecentGold()
			if avg > 0 then
				local n = math.ceil((info.Price - info.Total) / avg)
				if n >= 1 and n <= MAX_KILLS_SHOWN then
					text = textOr("KillsToAfford", "%s %d마리 더!", farmMonsterName(info.Level), n)
				end
			end
			ui.upgradeText.Text = text
		end
	end
	if ui.upgradeCoin then ui.upgradeCoin.Visible = not info.Max end
	-- U5 slim touch layout: the card shows only while the next weapon can be bought, so phones can still buy it
	local show = (not IS_TOUCH) or canBuy
	if ui.upgrade.Visible ~= show then ui.upgrade.Visible = show end
end

local function pulseUpgrade()
	local stroke = ui.upgradeGlow
	if stroke then
		stroke.Transparency = 0
		stroke.Thickness = 2
		local t = TweenService:Create(stroke,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), { Thickness = 7 })
		t.Completed:Once(function()
			if stroke.Parent then
				stroke.Transparency = 1
				stroke.Thickness = 3
			end
		end)
		t:Play()
	end
	local sc = ui.upgrade:FindFirstChild("PressScale")
	if sc then
		TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 2, true), {
			Scale = 1.08,
		}):Play()
	end
end

-- A7-3 (lowest priority): first moment the next weapon becomes affordable, once per tier per session.
-- Requires two consecutive ticks so the BankGold/CarriedGold pair of an auto-bank never fakes a moment.
local function checkAffordable()
	if attr("DataLoaded", false) ~= true then return end
	local info = upgradeInfo()
	local ok = (not info.Max) and (not info.LevelShort) and (not info.NeedFaction) and info.Total >= info.Price
	if not afford.Baseline then
		afford.Baseline = true
		afford.Was = ok
		return
	end
	if not ok then
		afford.Was = false
		afford.Streak = 0
		return
	end
	afford.Streak += 1
	if afford.Was or afford.Streak < 2 then return end
	afford.Was = true
	if afford.Notified[info.Tier] then return end
	afford.Notified[info.Tier] = true
	playSound("Coin")
	UIKit.Toast(textOr("CanAfford", "%s 살 수 있어요!", tostring(info.Name)), "reward", 3)
	pulseUpgrade()
end

local function refreshMenuGlow()
	local glow = num("Level", 1) >= Config.RebirthLevel(num("Rebirths", 0)) or num("VacationDays", 0) > 0
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
	local json = attr("QuestsJson", "")
	if type(json) ~= "string" or json == "" then return {} end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then return {} end
	local pinned, normal = {}, {}
	for _, e in ipairs(data) do
		if type(e) == "table" then
			local isPinned = e.Pinned == true or (e.Slot == nil and e.Id == TUT_QUEST_ID)
			local slot = tonumber(e.Slot)
			local entry = {
				Id = tostring(e.Id or ""),
				Kind = tostring(e.Kind or "Extra"),
				Text = tostring(e.Text or ""),
				Progress = math.max(0, tonumber(e.Progress) or 0),
				Target = math.max(1, tonumber(e.Target) or 1),
				RewardGold = math.max(0, tonumber(e.RewardGold) or 0),
				Pinned = isPinned,
				Slot = (not isPinned) and slot or nil, -- N1: the client only ever sends Slot or "tutorial"
			}
			table.insert(isPinned and pinned or normal, entry)
		end
	end
	for _, e in normal do
		table.insert(pinned, e)
	end
	return pinned
end

local function onClaim(r)
	local e = r.Entry
	if not e or throttled("claim", 0.35) then return end
	if os.clock() < (r.LockUntil or 0) then return end -- CR-M24: the row just changed under the finger
	local arg = nil
	if e.Pinned then
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
local function makeQuestRow(index)
	local W, H, R = ui.questRowW, L.QuestRowH, L.Row
	local row, isArt = UIKit.ArtFrame("PanelParchment", {
		Name = "Quest" .. index,
		LayoutOrder = index,
		Size = UDim2.fromOffset(W, H),
		Parent = ui.questList,
	})
	local r = { Frame = row, IsArt = isArt, Entry = nil, Key = nil, LockUntil = 0 }
	local iconS = H - 20
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
	local _, setBar, barText = UIKit.ArtBar({
		Name = "Progress",
		Position = UDim2.fromOffset(x0, barY),
		Size = UDim2.fromOffset(W - x0 - R.Reward - 14, R.BarH),
		Color = ac("QuestBlue", Theme.Good),
		TextSize = IS_TOUCH and L.TouchText or 11,
		Parent = row,
	})
	r.SetBar = setBar
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
	touchFloor(claimLabel)
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
	r.RerollLabel = touchFloor(rerollLabel)
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

refreshQuests = function()
	local entries = parseQuests()
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
		if done and (e.Pinned or e.Kind == "Daily") then
			claimable += 1
			if not firstClaim then firstClaim = i end
		elseif not done and e.Kind == "Daily" and not firstDaily then
			firstDaily = i
		end
	end
	local shown = nil
	if entries[1] and entries[1].Pinned then
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
		if hot then
			line = string.format(TXT.QuestTouchClaim, claimable)
		elseif se then
			line = string.format(TXT.QuestTouchLine, fmtNum(math.min(se.Progress, se.Target)), fmtNum(se.Target), se.Text)
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
		local key = e.Id .. "|" .. tostring(e.Slot) .. "|" .. e.Kind
		if r.Key ~= key then
			r.Key = key
			r.LockUntil = os.clock() + questState.RowLock
		end
		r.Entry = e
		r.Frame.Visible = IS_TOUCH or questExpanded or i == shown -- touch: every row, inside the overlay
		if r.Frame.Visible then visibleNow += 1 end
		if e.Pinned then
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
		r.Text.Text = e.Text
		local done = e.Progress >= e.Target
		r.SetBar(e.Progress / e.Target, done and ac("UpgradeGold", Theme.Gold) or ac("QuestBlue", Theme.Good))
		r.BarText.Text = fmtNum(math.min(e.Progress, e.Target)) .. "/" .. fmtNum(e.Target)
		local canClaim = done and (e.Pinned or e.Kind == "Daily")
		local canReroll = (not done) and (not e.Pinned) and e.Slot ~= nil
		r.Reward.Text = e.RewardGold > 0 and ("+" .. fmtNum(e.RewardGold)) or ""
		r.Reward.Visible = not canClaim -- 받기 covers the reward slot
		if r.Coin then r.Coin.Visible = e.RewardGold > 0 and not canClaim end
		r.Claim.Visible = canClaim
		r.Reroll.Visible = canReroll
		r.Text.Size = UDim2.fromOffset(canReroll and r.TextShort or r.TextLong, r.Text.Size.Y.Offset)
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
	refreshRerollTimers()
	if visibleBefore ~= visibleNow then
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

-- tutorial step 1: guide to the SlimeMeadow pad; cleared when the step changes or the player enters the zone.
-- Zone guides (Lv 10 / Lv 25) are cleared when the player enters that zone.
local function refreshGuides()
	if attr("DataLoaded", false) ~= true then return end
	local step = num("TutorialStep", 99)
	local zone = attr("ZoneId", "")
	if guide then
		if guide.Tag == "tutorial" and (step ~= TUT_GUIDE_STEP or zone == TUT_GUIDE_ZONE) then
			HUD.ClearGuide()
		elseif isZoneGuide(guide.Tag) and zone == string.sub(guide.Tag, 6) then
			HUD.ClearGuide()
		end
	end
	if step == TUT_GUIDE_STEP and zone ~= TUT_GUIDE_ZONE and not (guide and guide.Tag == "tutorial") then
		showGuide(findTravelTarget(TUT_GUIDE_ZONE), TUT_GUIDE_TEXT, "tutorial", nil)
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
	return ui.root ~= nil and ui.root.Visible
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

-- press = one Swing now; hold = repeat every class SwingInterval (the server queues jitter-early requests)
local function startHold(source)
	if source == nil then return end
	local wasHeld = next(holdSources) ~= nil
	holdSources[source] = true
	if wasHeld then return end
	holdToken += 1
	local token = holdToken
	pressScale(ui.attack, true)
	fire("Swing")
	task.spawn(function()
		while true do
			task.wait(swingInterval())
			if holdToken ~= token or next(holdSources) == nil then break end
			if not inputAllowed() then
				clearHolds()
				break
			end
			fire("Swing")
		end
	end)
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
	local n = math.floor(num("Charge", 0))
	if n < Config.Charge.MinRelease then
		if not throttled("releaseNeed", 1.5) then
			UIKit.Toast(UIKit.Fmt("ReleaseNeed", Config.Charge.MinRelease), "bad", 1.5)
		end
		return
	end
	fire("Release")
end

toggleAuto = function()
	if throttled("auto", 0.3) then return end
	local unlock = Config.Combat.AutoUnlockLevel
	local on = attr("AutoAttack", false) == true
	if not on and num("Level", 1) < unlock then
		UIKit.Toast(UIKit.Fmt("AutoLocked", unlock), "bad")
		return
	end
	fire("SetAutoAttack", not on)
end

doUpgrade = function()
	if throttled("upgrade", 0.35) then return end
	fire("UpgradeWeapon")
end

openMenu = function()
	if throttled("menu", 0.25) then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" then return end
	if type(panels.IsOpen) == "function" and type(panels.Close) == "function" then
		local ok, open = pcall(panels.IsOpen)
		if ok and open then
			pcall(panels.Close)
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
	if gameProcessed or not inputAllowed() then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		startHold("mouse")
	elseif t == Enum.UserInputType.Keyboard then
		local k = input.KeyCode
		if k == Enum.KeyCode.F then
			startHold("keyF")
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.E then
			doRelease()
		elseif k == Enum.KeyCode.R then
			toggleAuto()
		elseif k == Enum.KeyCode.U then
			doUpgrade()
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
	ui.war.Position = UDim2.new(0.5, 0, 0, warY)
	-- chips under EventHUD's strip, which itself follows the war meter's bottom
	ui.chips.Position = UDim2.new(0.5, 0, 0, math.max(L.ChipsY + shift, minTop, warY + L.WarH + L.StripBelow))

	-- quests right under the card (collapsed by default, so the list stays short)
	local statsBottom = statsY + ui.stats.Size.Y.Offset
	ui.quests.Position = UDim2.fromOffset(12, statsBottom + 8)

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
	if cornerRelease then
		-- bottoms level with 공격's
		ui.release.Position = UDim2.fromOffset(ax + AR + GAP + RR, math.min(ay + AR - RR, H - RR - 8))
	else
		ui.release.Position = UDim2.fromOffset(ax - AR - GAP - RR, math.min(ay + AR * 0.25, H - RR - 8))
	end

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
	ui.auto.Position = UDim2.fromOffset(right - SQ * 2.5 - 2 * RG, rowY)
	ui.upgrade.Position = UDim2.fromOffset(right - rowW / 2, rowY - SQ / 2 - RG - L.UpgradeH / 2)
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

local function onFx(kind, data)
	if kind ~= "Reward" or type(data) ~= "table" then return end
	local g = tonumber(data.Gold)
	if not g or g ~= g or g <= 0 or g == math.huge then return end
	table.insert(recentGold, g)
	while #recentGold > REWARD_SAMPLES do
		table.remove(recentGold, 1)
	end
	refreshUpgrade()
end

local function tick()
	tickCount += 1
	if not refreshVisibility() then return end
	refreshWarTime()
	refreshChips()
	refreshPerfect()
	refreshTravel()
	refreshRerollTimers()
	checkAffordable()
	if tickCount % 5 == 0 then
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
	UIKit.OnAttr({ "Charge", "ChargeCap", "Faction" }, refreshCharge)
	UIKit.OnAttr({ "PerfectUntil" }, refreshPerfect)
	UIKit.OnAttr({ "AutoAttack", "Level" }, refreshAuto)
	UIKit.OnAttr({ "WeaponTier", "Level", "Class", "Faction", "BankGold", "CarriedGold", "ZoneId" }, refreshUpgrade)
	UIKit.OnAttr({ "Level", "Rebirths", "VacationDays" }, refreshMenuGlow)
	UIKit.OnAttr({ "QuestsJson", "DailyClaims", "RerollReadyAt" }, refreshQuests)
	UIKit.OnAttr({ "ZoneTown", "ZonePvP", "Rookie", "Protected", "InCombatUntil", "SizeMult", "BullyStacks",
		"KaijuState", "Faction" }, refreshChips)
	UIKit.OnAttr({ "WarPoints", "Faction" }, refreshWar)
	UIKit.OnGameAttr({ "WarHaloScore", "WarHornsScore", "WarMode", "WarBlessing", "WarRoundEndsAt" }, refreshWar)
	UIKit.OnAttr({ "TravelingUntil" }, refreshTravel)
	UIKit.OnAttr({ "TutorialStep", "ZoneId" }, refreshGuides)
	UIKit.OnAttr({ "Level" }, onLevelChanged)

	bindButtonInput()
	task.spawn(placeLegacyChat)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.WindowFocusReleased:Connect(clearHolds)

	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

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

	-- kill rewards feed the "N마리 더!" estimate (A7-3); never block Start on the remote
	task.spawn(function()
		local fx = Net.Get("Fx")
		fx.OnClientEvent:Connect(function(kind, data)
			local ok, err = pcall(onFx, kind, data)
			if not ok then warnThrottled("Fx handler error: " .. tostring(err)) end
		end)
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
