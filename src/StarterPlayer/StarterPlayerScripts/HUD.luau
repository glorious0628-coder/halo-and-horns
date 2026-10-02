-- HUD.luau : stats block, war meter, status chips, quest rows (claim / reroll / pinned tutorial), the 5 big buttons
-- with the charge ring, keyboard / mouse / touch / gamepad input, travel bar and the guide beam
-- (TECH_SPEC §4.23 HUD; addendum A3-H4/H5/M1, A4 step 1, A5-C6/N1, A6 Neutral, A7-3 next goal).
-- Client only: reads attributes / GameState / the Fx remote, writes only client->server intents.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

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

local TICK = 0.2
local TOP_PAD = UI.TopInsetPad or 8 -- addendum H4
local TOP_FALLBACK = UI.TopInsetFallback or 64
local JUMP_WAIT = UI.JumpButtonWait or 5 -- addendum H5
local ATTACK_FALLBACK = UI.AttackFallbackOffset or Vector2.new(-200, -170)

local ATTACK_SIZE = 160
local RELEASE_SIZE = 120
local SMALL_W, SMALL_H = 100, 56
local UPGRADE_W, UPGRADE_H = 230, 70
local BTN_GAP = 14
local SCREEN_EDGE = 24
local STATS_W = 300
local STATS_H_FULL, STATS_H_SHORT = 122, 98
local QUEST_W, QUEST_ROW_H, QUEST_GAP, QUEST_HEADER_H = 300, 58, 4, 24
local WAR_W = 420

local REWARD_SAMPLES = NEXT.RewardSamples or 10
local MAX_KILLS_SHOWN = NEXT.MaxKillsShown or 99
local GUIDE_SECONDS = NEXT.GuideSeconds or 90
local GUIDE_ZONES = NEXT.GuideZones or { "GoblinWoods", "SkeletonRuins" }
local TUT_GUIDE_STEP = (type(TUT.Steps) == "table" and TUT.Steps.Guide) or 1
local TUT_GUIDE_ZONE = TUT.GuideZone or "SlimeMeadow"
local TUT_GUIDE_TEXT = TUT.GuideText or "여기로!"
local TUT_QUEST_ID = TUT.QuestId or "tutorial"

local DARK_TEXT = Color3.fromRGB(30, 25, 10)
local GREY = Color3.fromRGB(150, 150, 160)
local BTN_GREY = Color3.fromRGB(70, 72, 92)
local BTN_LOCKED = Color3.fromRGB(45, 45, 56)
local ATTACK_COLOR = Color3.fromRGB(215, 70, 60)
local RELEASE_BG = Color3.fromRGB(28, 30, 48)
local UPGRADE_BG = Color3.fromRGB(55, 60, 92)
local RING_IDLE = Color3.fromRGB(130, 140, 175)
local CHARGE_COLOR = Color3.fromRGB(90, 200, 255)
local WAR_BG = Color3.fromRGB(12, 12, 20)

-- HUD display strings (the literals of TECH_SPEC §4.23 HUD; game messages come from Config.Text)
local TXT = {
	Level = "Lv %d",
	Bank = "금고 %s",
	Carried = "주머니 %s",
	Bounty = "  현상금 %s",
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
	BadgeDaily = "일일",
	BadgeExtra = "추가",
	BadgePinned = "안내",
	Claim = "받기",
	Reroll = "↻",
	Attack = "공격",
	Release = "발사",
	Perfect = "PERFECT!",
	AutoOn = "자동 ON",
	AutoOff = "자동 OFF",
	AutoLocked = "Lv%d 해금",
	UpgradeNext = "다음: %s (%sG)",
	UpgradeMax = "최고 등급",
	UpgradeNeedLevel = "Lv %d 필요",
	UpgradeNeedFaction = "진영 선택 필요",
	UpgradeReady = "구매 가능!",
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

local function corner(radius)
	return UIKit.Create("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

local function panel(props)
	if props.BackgroundColor3 == nil then props.BackgroundColor3 = Theme.Bg end
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = Theme.BgTransparency end
	return UIKit.Create("Frame", props, { corner(UDim.new(0, 12)) })
end

local function scaledLabel(props, maxSize)
	props.BackgroundTransparency = 1
	props.TextScaled = true
	if props.Text == nil then props.Text = "" end
	return UIKit.Create("TextLabel", props, {
		UIKit.Create("UITextSizeConstraint", { MinTextSize = UI.MinTextSize or 11, MaxTextSize = maxSize }),
	})
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

local function requestLayout()
	if layoutPending then return end
	layoutPending = true
	task.defer(function()
		layoutPending = false
		local ok, err = pcall(applyLayout)
		if not ok then warnThrottled("layout error: " .. tostring(err)) end
	end)
end

----------------------------------------------------------------- building: stats block
local function buildStats(root)
	local f = panel({
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12 + TOP_FALLBACK),
		Size = UDim2.fromOffset(STATS_W, STATS_H_SHORT),
		Parent = root,
	})
	ui.stats = f
	ui.level = UIKit.Create("TextLabel", {
		Name = "Level",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(76, 36),
		BackgroundColor3 = Theme.Gold,
		TextColor3 = DARK_TEXT,
		TextSize = 21,
		Text = "Lv 1",
		Parent = f,
	}, { corner(UDim.new(0, 10)) })
	ui.title = UIKit.Label({
		Name = "Title",
		Position = UDim2.fromOffset(92, 6),
		Size = UDim2.fromOffset(STATS_W - 100, 20),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = f,
	})
	ui.class = UIKit.Label({
		Name = "Class",
		Position = UDim2.fromOffset(92, 26),
		Size = UDim2.fromOffset(STATS_W - 100, 18),
		TextSize = 15,
		TextColor = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = f,
	})
	UIKit.Label({
		Name = "XPTag",
		Position = UDim2.fromOffset(4, 50),
		Size = UDim2.fromOffset(28, 18),
		TextSize = 15,
		TextColor = Theme.XP,
		Text = "XP",
		Parent = f,
	})
	local _, setXP, xpText = UIKit.Bar({
		Name = "XPBar",
		Position = UDim2.fromOffset(32, 51),
		Size = UDim2.fromOffset(260, 16),
		Color = Theme.XP,
		Parent = f,
	})
	ui.setXP = setXP
	ui.xpText = xpText
	ui.bank = UIKit.Label({
		Name = "Bank",
		Position = UDim2.fromOffset(8, 72),
		Size = UDim2.fromOffset(140, 22),
		TextSize = 17,
		TextColor = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = f,
	})
	ui.carried = UIKit.Label({
		Name = "Carried",
		Position = UDim2.fromOffset(152, 72),
		Size = UDim2.fromOffset(140, 22),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = f,
	})
	ui.stars = UIKit.Label({
		Name = "Stars",
		Position = UDim2.fromOffset(8, 96),
		Size = UDim2.fromOffset(STATS_W - 16, 20),
		TextSize = 16,
		TextColor = Theme.Bad,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = f,
	})
end

----------------------------------------------------------------- building: war meter
local function buildWar(root)
	local w = UIKit.Create("Frame", {
		Name = "WarMeter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8 + TOP_FALLBACK),
		Size = UDim2.fromOffset(WAR_W, 58),
		BackgroundTransparency = 1,
		Parent = root,
	})
	ui.war = w
	local bar = UIKit.Create("Frame", {
		Name = "Bar",
		Size = UDim2.fromOffset(WAR_W, 26),
		BackgroundColor3 = WAR_BG,
		BackgroundTransparency = 0.15,
		Parent = w,
	}, {
		corner(UDim.new(0, 8)),
		UIKit.Create("UIStroke", {
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
			Transparency = 0.4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	ui.haloFill = UIKit.Create("Frame", {
		Name = "HaloFill",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Theme.Halo,
		Parent = bar,
	}, { corner(UDim.new(0, 8)) })
	ui.hornsFill = UIKit.Create("Frame", {
		Name = "HornsFill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Theme.Horns,
		Parent = bar,
	}, { corner(UDim.new(0, 8)) })
	ui.warDivider = UIKit.Create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 4, 1, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = bar,
	}, { corner(UDim.new(0, 2)) })
	ui.haloNum = UIKit.Label({
		Name = "HaloScore",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.5, -10, 1, 0),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Parent = bar,
	})
	ui.hornsNum = UIKit.Label({
		Name = "HornsScore",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0.5, -10, 1, 0),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Parent = bar,
	})
	local row = UIKit.Create("Frame", {
		Name = "Info",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(WAR_W, 22),
		BackgroundTransparency = 1,
		Parent = w,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})
	local function info(name, order, color)
		return UIKit.Label({
			Name = name,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextSize = 15,
			TextColor = color,
			TextStrokeTransparency = 0.5,
			Parent = row,
		})
	end
	ui.warTime = info("Time", 1, Theme.Text)
	ui.warSiege = info("Siege", 2, Theme.Revenge)
	ui.warSiege.Visible = false
	ui.warPoints = info("MyPoints", 3, Theme.Gold)
end

----------------------------------------------------------------- building: status chips
local function makeChip(name, order)
	return UIKit.Create("TextLabel", {
		Name = name,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2,
		TextSize = 15,
		Text = "",
		Visible = false,
		Parent = ui.chips,
	}, {
		corner(UDim.new(0, 13)),
		UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		UIKit.Create("UIStroke", {
			Name = "Stroke",
			Thickness = 1.5,
			Color = Theme.SubText,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function setChip(chip, visible, text, color, bright)
	if not chip then return end
	chip.Visible = visible == true
	if not visible then return end
	color = color or Theme.SubText
	chip.Text = text or ""
	if bright then
		chip.BackgroundColor3 = color
		chip.BackgroundTransparency = 0.05
		chip.TextColor3 = DARK_TEXT
	else
		chip.BackgroundColor3 = Theme.Bg
		chip.BackgroundTransparency = 0.2
		chip.TextColor3 = color
	end
	local stroke = chip:FindFirstChild("Stroke")
	if stroke then stroke.Color = color end
end

local function buildChips(root)
	ui.chips = UIKit.Create("Frame", {
		Name = "StatusChips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 116 + TOP_FALLBACK),
		Size = UDim2.fromOffset(900, 30),
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
	ui.chip = {}
	for i, key in { "Blessing", "Zone", "Rookie", "Protected", "Combat", "Size", "Bully", "Kaiju" } do
		ui.chip[key] = makeChip(key, i)
	end
end

----------------------------------------------------------------- building: quests
local function buildQuests(root)
	ui.quests = UIKit.Create("Frame", {
		Name = "Quests",
		Position = UDim2.fromOffset(12, 200 + TOP_FALLBACK),
		Size = UDim2.fromOffset(QUEST_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, QUEST_GAP),
		}),
	})
	ui.questHeader = UIKit.Create("TextLabel", {
		Name = "Header",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(QUEST_W, QUEST_HEADER_H),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.35,
		TextSize = 16,
		TextColor3 = Theme.Gold,
		Text = "",
		Parent = ui.quests,
	}, { corner(UDim.new(0, 8)) })
end

----------------------------------------------------------------- building: travel bar
local function buildTravel(root)
	ui.travel = panel({
		Name = "Travel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(340, 60),
		Visible = false,
		Parent = root,
	})
	ui.travelLabel = UIKit.Label({
		Name = "Label",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 19,
		Parent = ui.travel,
	})
	local _, setTravel = UIKit.Bar({
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(310, 14),
		Color = Theme.XP,
		Parent = ui.travel,
	})
	ui.setTravel = setTravel
end

----------------------------------------------------------------- building: buttons
local function roundButton(name, size, color)
	return UIKit.Create("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.08,
		Parent = ui.buttons,
	}, {
		corner(UDim.new(0.5, 0)),
		UIKit.Create("UIStroke", {
			Name = "Ring",
			Thickness = 4,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.35,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIKit.Create("UIScale", { Name = "PressScale" }),
	})
end

-- small key badge (desktop keyboards only)
local function keyHint(parent, text, position, anchor)
	if not UserInputService.KeyboardEnabled then return end
	UIKit.Create("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(24, 22),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		TextSize = 15,
		Text = text,
		ZIndex = 4,
		Parent = parent,
	}, { corner(UDim.new(0, 6)) })
end

local toggleAuto, doUpgrade, openMenu -- forward (defined with the input code)

local function buildButtons(root)
	ui.buttons = UIKit.Create("Frame", {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})

	-- 공격 (press = one swing, hold = repeat)
	ui.attack = roundButton("Attack", ATTACK_SIZE, ATTACK_COLOR)
	UIKit.Label({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		Text = TXT.Attack,
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
		Parent = ui.attack,
	})
	keyHint(ui.attack, "F", UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1))

	-- 발사 + charge ring
	ui.release = roundButton("Release", RELEASE_SIZE, RELEASE_BG)
	ui.ring = ui.release:FindFirstChild("Ring")
	ui.chargeFill = UIKit.Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CHARGE_COLOR,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = ui.release,
	}, {
		corner(UDim.new(0.5, 0)),
		UIKit.Create("UIGradient", { Name = "Level", Rotation = -90 }),
	})
	ui.chargeGradient = ui.chargeFill:FindFirstChild("Level")
	ui.chargeNum = UIKit.Label({
		Name = "Count",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 36,
		Text = "0",
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Parent = ui.release,
	})
	ui.chargeSub = UIKit.Label({
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -10, 0, 20),
		TextSize = 16,
		Text = TXT.Release,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Parent = ui.release,
	})
	ui.chargeTimer = UIKit.Label({
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, -10, 0, 20),
		TextSize = 16,
		TextColor = Theme.Gold,
		TextStrokeTransparency = 0.3,
		Visible = false,
		ZIndex = 3,
		Parent = ui.release,
	})
	keyHint(ui.release, "Q", UDim2.fromScale(1, 0), Vector2.new(1, 0))

	-- 자동
	ui.auto = UIKit.Button({
		Name = "Auto",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(SMALL_W, SMALL_H),
		TextSize = 17,
		Text = TXT.AutoOff,
		Color = BTN_GREY,
		Parent = ui.buttons,
	}, function()
		toggleAuto()
	end)
	keyHint(ui.auto, "R", UDim2.fromOffset(-6, -6), Vector2.new(0, 0))

	-- 업그레이드 (line 1: next weapon + price, line 2: progress bar / next-goal text)
	ui.upgrade = UIKit.Button({
		Name = "Upgrade",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(UPGRADE_W, UPGRADE_H),
		Text = "",
		Color = UPGRADE_BG,
		Parent = ui.buttons,
	}, function()
		doUpgrade()
	end)
	ui.upgradeTitle = scaledLabel({
		Name = "Title",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 24),
		ZIndex = 2,
		Parent = ui.upgrade,
	}, 17)
	local _, setUpgrade, upgradeText = UIKit.Bar({
		Name = "Progress",
		Position = UDim2.fromOffset(8, 36),
		Size = UDim2.new(1, -16, 0, 24),
		Color = Theme.Gold,
		Parent = ui.upgrade,
	})
	upgradeText.TextScaled = true
	local tc = upgradeText:FindFirstChildOfClass("UITextSizeConstraint")
	if tc then tc.MaxTextSize = 15 end
	ui.setUpgrade = setUpgrade
	ui.upgradeText = upgradeText
	keyHint(ui.upgrade, "U", UDim2.fromOffset(-6, -6), Vector2.new(0, 0))

	-- 메뉴
	ui.menu = UIKit.Button({
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(SMALL_W, SMALL_H),
		TextSize = 20,
		Text = TXT.Menu,
		Color = BTN_GREY,
		Parent = ui.buttons,
	}, function()
		openMenu()
	end)
	keyHint(ui.menu, "M", UDim2.fromOffset(-6, -6), Vector2.new(0, 0))
end

----------------------------------------------------------------- refresh: stats
local function refreshStats()
	local f = getFaction()
	local level = math.floor(num("Level", 1))
	ui.level.Text = string.format(TXT.Level, level)

	local title = Config.DisplayTitle(f, num("Honor", 0), num("Infamy", 0), num("FallMarks", 0), num("RedeemMarks", 0),
		attr("SessionTitle", ""))
	local prefix = ""
	if f == "Neutral" then
		local emblem = factionDef(f).Emblem
		if type(emblem) == "string" and emblem ~= "" then prefix = emblem .. " " end
	end
	ui.title.Text = prefix .. tostring(title or "")
	ui.title.TextColor3 = factionColor(f)
	ui.class.Text = Config.ClassName(getClass(), f)

	local xp = math.max(0, num("XP", 0))
	if level >= Config.Levels.MaxLevel then
		ui.setXP(1)
		ui.xpText.Text = "MAX"
	else
		local need = math.max(1, Config.XPToNext(level))
		ui.setXP(xp / need)
		ui.xpText.Text = fmtNum(xp) .. " / " .. fmtNum(need)
	end

	ui.bank.Text = string.format(TXT.Bank, fmtNum(num("BankGold", 0)))
	ui.carried.Text = string.format(TXT.Carried, fmtNum(num("CarriedGold", 0)))

	local horns = f == "Horns"
	ui.stars.Visible = horns
	if horns then
		local maxStars = Config.PvP.MaxStars or 5
		local stars = math.clamp(math.floor(num("WantedStars", 0)), 0, maxStars)
		ui.stars.Text = string.rep("★", stars) .. string.rep("☆", maxStars - stars)
			.. string.format(TXT.Bounty, fmtNum(num("Bounty", 0)))
	end
	local h = horns and STATS_H_FULL or STATS_H_SHORT
	if ui.stats.Size.Y.Offset ~= h then
		ui.stats.Size = UDim2.fromOffset(STATS_W, h)
		requestLayout()
	end
end

----------------------------------------------------------------- refresh: status chips
local function refreshChips()
	local f = getFaction()
	local now = Util.Now()

	local blessing = UIKit.GameAttr("WarBlessing", "None")
	local bdef = (blessing == "Halo" or blessing == "Horns") and Config.Factions[blessing] or nil
	if bdef then
		local pct = math.floor((Config.War.BlessingGold or 0.25) * 100 + 0.5)
		setChip(ui.chip.Blessing, true, string.format(TXT.Blessing, bdef.Name, pct), factionColor(blessing), blessing == f)
	else
		setChip(ui.chip.Blessing, false)
	end

	if attr("ZoneTown", false) == true then
		setChip(ui.chip.Zone, true, TXT.Safe, Theme.Good)
	elseif attr("ZonePvP", false) == true then
		if f == "Neutral" then
			setChip(ui.chip.Zone, true, TXT.PvPNeutral, factionColor("Neutral")) -- A6: Neutral is PvP-immune (A9-1 teal)
		else
			setChip(ui.chip.Zone, true, TXT.PvP, Theme.Bad)
		end
	else
		setChip(ui.chip.Zone, false)
	end

	setChip(ui.chip.Rookie, attr("Rookie", false) == true and f ~= "Neutral", TXT.Rookie, Theme.Good)
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
	ui.haloNum.Text = tostring(Config.Factions.Halo.Emblem) .. " " .. fmtScore(h)
	ui.hornsNum.Text = fmtScore(r) .. " " .. tostring(Config.Factions.Horns.Emblem)

	local mode = UIKit.GameAttr("WarMode", "Idle")
	ui.warSiege.Visible = mode == "Siege"
	ui.warSiege.Text = string.format(TXT.Siege, Config.War.SiegeTarget or 150)

	local f = getFaction()
	local fighting = f == "Halo" or f == "Horns" -- A6: Neutral / None earn no war points
	ui.warPoints.Visible = fighting
	if fighting then
		ui.warPoints.Text = string.format(TXT.MyWar, fmtNum(num("WarPoints", 0)))
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
	ui.chargeNum.TextColor3 = ready and Theme.Text or GREY
	ui.release.BackgroundTransparency = ready and 0.05 or 0.35
	if not perfectOn then
		ui.chargeFill.BackgroundColor3 = (charge >= cap) and Theme.Gold or CHARGE_COLOR
		ui.chargeFill.BackgroundTransparency = ready and 0.15 or 0.45
		ui.ring.Color = ready and Theme.Gold or RING_IDLE
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
	if num("Level", 1) < unlock then
		ui.auto.Text = string.format(TXT.AutoLocked, unlock)
		ui.auto.BackgroundColor3 = BTN_LOCKED
		ui.auto.TextColor3 = GREY
	elseif attr("AutoAttack", false) == true then
		ui.auto.Text = TXT.AutoOn
		ui.auto.BackgroundColor3 = Theme.Good
		ui.auto.TextColor3 = DARK_TEXT
	else
		ui.auto.Text = TXT.AutoOff
		ui.auto.BackgroundColor3 = BTN_GREY
		ui.auto.TextColor3 = Theme.Text
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
	if info.Max then
		ui.upgradeTitle.Text = TXT.UpgradeMax
		ui.setUpgrade(1, Theme.Gold)
		ui.upgradeText.Text = ""
		return
	end
	ui.upgradeTitle.Text = string.format(TXT.UpgradeNext, tostring(info.Name), fmtNum(info.Price))
	local frac = info.Price > 0 and (info.Total / info.Price) or 1
	if info.LevelShort then
		ui.setUpgrade(frac, GREY)
		ui.upgradeText.Text = string.format(TXT.UpgradeNeedLevel, info.MinLevel)
	elseif info.NeedFaction then
		ui.setUpgrade(frac, GREY)
		ui.upgradeText.Text = TXT.UpgradeNeedFaction
	elseif info.Total >= info.Price then
		ui.setUpgrade(1, Theme.Good)
		ui.upgradeText.Text = TXT.UpgradeReady
	else
		ui.setUpgrade(frac, Theme.Gold)
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

local function pulseUpgrade()
	local stroke = ui.upgrade:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = Theme.Gold
		stroke.Transparency = 0
		stroke.Thickness = 2
		local t = TweenService:Create(stroke,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), { Thickness = 7 })
		t.Completed:Once(function()
			if stroke.Parent then
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Transparency = 0.45
				stroke.Thickness = 2
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
	local stroke = ui.menu:FindFirstChild("Stroke")
	if glow then
		ui.menu.TextColor3 = Theme.Gold
		if stroke then
			stroke.Color = Theme.Gold
			stroke.Transparency = 0
			stroke.Thickness = 3
			menuGlowTween = TweenService:Create(stroke,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 6 })
			menuGlowTween:Play()
		end
	else
		ui.menu.TextColor3 = Theme.Text
		if stroke then
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Transparency = 0.45
			stroke.Thickness = 2
		end
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
	local arg = nil
	if e.Pinned then
		arg = TUT_QUEST_ID
	else
		arg = e.Slot
	end
	if arg == nil then return end
	fire("ClaimQuest", arg)
	r.Claim:SetAttribute("Disabled", true)
	r.Claim.BackgroundTransparency = 0.5
	task.delay(1.5, function()
		if r.Claim.Parent then
			r.Claim:SetAttribute("Disabled", false)
			r.Claim.BackgroundTransparency = 0
		end
	end)
end

local function onReroll(r)
	local e = r.Entry
	if not e or e.Pinned or e.Slot == nil then return end
	if Util.Now() < num("RerollReadyAt", 0) then return end
	if throttled("reroll", 0.6) then return end
	fire("RerollQuest", e.Slot)
end

local function makeQuestRow(index)
	local row = UIKit.Create("Frame", {
		Name = "Quest" .. index,
		LayoutOrder = index,
		Size = UDim2.fromOffset(QUEST_W, QUEST_ROW_H),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = Theme.BgTransparency,
		Parent = ui.quests,
	}, {
		corner(UDim.new(0, 10)),
		UIKit.Create("UIStroke", {
			Name = "Stroke",
			Color = Theme.Good,
			Thickness = 2,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	local r = { Frame = row, Entry = nil }
	r.Badge = UIKit.Create("TextLabel", {
		Name = "Badge",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(44, 22),
		BackgroundColor3 = Theme.Gold,
		TextColor3 = DARK_TEXT,
		TextSize = 15,
		Text = "",
		Parent = row,
	}, { corner(UDim.new(0, 6)) })
	r.Text = UIKit.Label({
		Name = "Text",
		Position = UDim2.fromOffset(56, 2),
		Size = UDim2.fromOffset(190, 34),
		TextSize = 15,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	local _, setBar, barText = UIKit.Bar({
		Name = "Progress",
		Position = UDim2.fromOffset(6, 38),
		Size = UDim2.fromOffset(190, 16),
		Color = Theme.Good,
		Parent = row,
	})
	r.SetBar = setBar
	r.BarText = barText
	r.Reward = UIKit.Label({
		Name = "Reward",
		Position = UDim2.fromOffset(198, 36),
		Size = UDim2.fromOffset(50, 20),
		TextSize = 15,
		TextColor = Theme.Gold,
		Parent = row,
	})
	r.Claim = UIKit.Button({
		Name = "Claim",
		Text = TXT.Claim,
		Position = UDim2.fromOffset(250, 6),
		Size = UDim2.fromOffset(46, 46),
		Color = Theme.Good,
		TextColor = DARK_TEXT,
		TextSize = 16,
		Visible = false,
		Parent = row,
	}, function()
		onClaim(r)
	end)
	r.Reroll = UIKit.Button({
		Name = "Reroll",
		Text = TXT.Reroll,
		Position = UDim2.fromOffset(250, 6),
		Size = UDim2.fromOffset(46, 46),
		Color = BTN_GREY,
		TextSize = 22,
		Visible = false,
		Parent = row,
	}, function()
		onReroll(r)
	end)
	return r
end

local function refreshRerollTimers()
	local remaining = num("RerollReadyAt", 0) - Util.Now()
	for _, r in questRows do
		if r.Frame.Visible and r.Reroll.Visible then
			if remaining > 0 then
				r.Reroll.Text = tostring(math.ceil(remaining))
				r.Reroll.TextSize = 16
				r.Reroll.BackgroundTransparency = 0.55
				r.Reroll:SetAttribute("Disabled", true)
			else
				r.Reroll.Text = TXT.Reroll
				r.Reroll.TextSize = 22
				r.Reroll.BackgroundTransparency = 0
				r.Reroll:SetAttribute("Disabled", false)
			end
		end
	end
end

local function refreshQuests()
	local entries = parseQuests()
	ui.quests.Visible = #entries > 0
	local slots = Config.Quests.Slots
	local claims = math.floor(num("DailyClaims", 0))
	if claims >= slots then
		ui.questHeader.Text = TXT.QuestAllDone
	else
		ui.questHeader.Text = string.format(TXT.QuestHeader, claims, slots)
	end

	local visibleBefore = 0
	for _, r in questRows do
		if r.Frame.Visible then visibleBefore += 1 end
	end

	for i, e in entries do
		local r = questRows[i]
		if not r then
			r = makeQuestRow(i)
			questRows[i] = r
		end
		r.Entry = e
		r.Frame.Visible = true
		if e.Pinned then
			r.Badge.Text = TXT.BadgePinned
			r.Badge.BackgroundColor3 = Theme.XP
		elseif e.Kind == "Daily" then
			r.Badge.Text = TXT.BadgeDaily
			r.Badge.BackgroundColor3 = Theme.Gold
		else
			r.Badge.Text = TXT.BadgeExtra
			r.Badge.BackgroundColor3 = GREY
		end
		r.Text.Text = e.Text
		local done = e.Progress >= e.Target
		r.SetBar(e.Progress / e.Target, done and Theme.Gold or Theme.Good)
		r.BarText.Text = fmtNum(math.min(e.Progress, e.Target)) .. "/" .. fmtNum(e.Target)
		r.Reward.Text = e.RewardGold > 0 and ("+" .. fmtNum(e.RewardGold)) or ""
		local claimable = done and (e.Pinned or e.Kind == "Daily")
		r.Claim.Visible = claimable
		r.Reroll.Visible = (not done) and (not e.Pinned) and e.Slot ~= nil
		local stroke = r.Frame:FindFirstChild("Stroke")
		if stroke then stroke.Transparency = claimable and 0 or 1 end
	end
	for i = #entries + 1, #questRows do
		local r = questRows[i]
		r.Entry = nil
		r.Frame.Visible = false
	end
	refreshRerollTimers()
	if visibleBefore ~= #entries then
		requestLayout()
	end
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
		elseif k == Enum.KeyCode.M then
			openMenu()
		end
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
	local minTop = (inset + TOP_PAD) / s -- H4: never above inset + 8 real px

	-- top-anchored blocks
	local statsY = math.max(12 + shift, minTop)
	ui.stats.Position = UDim2.fromOffset(12, statsY)
	ui.war.Position = UDim2.new(0.5, 0, 0, math.max(8 + shift, minTop))
	ui.chips.Position = UDim2.new(0.5, 0, 0, math.max(116 + shift, minTop))

	-- quests (left-middle); pulled up on short screens so the last row stays visible
	local rows = 0
	for _, r in questRows do
		if r.Frame.Visible then rows += 1 end
	end
	local needed = QUEST_HEADER_H + rows * (QUEST_ROW_H + QUEST_GAP)
	local statsBottom = statsY + ui.stats.Size.Y.Offset
	local qy = 200 + shift
	if qy + needed > H - 8 then
		qy = math.max(statsBottom + 8, H - 8 - needed)
	end
	ui.quests.Position = UDim2.fromOffset(12, qy)

	-- big buttons: attack up-left of the touch jump button (H5), else bottom-right corner
	local AR, RR = ATTACK_SIZE / 2, RELEASE_SIZE / 2
	local ax, ay
	local jb = jumpButton
	if jb and jb.Parent and jb.AbsoluteSize.X > 0 then
		local rel = jb.AbsolutePosition - gui.AbsolutePosition
		ax = rel.X / s - BTN_GAP - AR
		ay = rel.Y / s + (jb.AbsoluteSize.Y / s) * 0.2
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		ax, ay = W + ATTACK_FALLBACK.X, H + ATTACK_FALLBACK.Y
	else
		ax, ay = W - SCREEN_EDGE - AR, H - SCREEN_EDGE - AR
	end
	local axMax = W - AR - 8
	local ayMax = H - AR - 8
	ax = math.clamp(ax, math.min(axMax, AR + 2 * RR + BTN_GAP + 8), axMax)
	ay = math.clamp(ay, math.min(ayMax, AR + UPGRADE_H + BTN_GAP + 8), ayMax)
	ui.attack.Position = UDim2.fromOffset(ax, ay)
	ui.release.Position = UDim2.fromOffset(ax - AR - BTN_GAP - RR, math.min(ay + 20, H - RR - 8))

	local rowY = ay - AR - BTN_GAP - UPGRADE_H / 2
	local autoX = ax
	local menuX = autoX + SMALL_W + 12
	local overflow = menuX + SMALL_W / 2 - (W - 12)
	if overflow > 0 then
		autoX -= overflow
		menuX -= overflow
	end
	local upX = autoX - SMALL_W / 2 - 12 - UPGRADE_W / 2
	ui.auto.Position = UDim2.fromOffset(autoX, rowY)
	ui.menu.Position = UDim2.fromOffset(menuX, rowY)
	ui.upgrade.Position = UDim2.fromOffset(upX, rowY)
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
