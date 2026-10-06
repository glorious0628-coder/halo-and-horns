-- HUD.luau : A23-40 HUD layout B ("보여 준 게임처럼"). PC: top-left round live minimap (MiniMap.luau) with two quest
-- lines under it (no plate: outlined text, progress / 받기; the full list folds out under them), top-centre war meter ->
-- zone / luck / status chips (3 + '+N') -> next event line (EventHUD) -> notify column (EventHUD + UIKit toasts), bottom-
-- centre round portrait (faction level badge) + 'Lv · 전투력 · 주머니' + HP | MP + thin XP + the icon tile row
-- [캐릭터][가방][스킬][지도][랭킹][펫][설정][메뉴] (a tile shows once its window exists), bottom-right combat cluster
-- (공격 · 스킬 Q · 자동 · 물약 1·2; the ghost hold is GrudgeGhost); the top-right stays empty (Tab list only). Phones
-- move the plate and the tile row top-right (the bottom centre is the thumbstick's and the cluster's). Keyboard / mouse
-- / touch / gamepad input and the guide beam (TECH_SPEC §4.23 HUD; addendum A3-H4/H5/M1, A4 step 1, A5-C6/N1, A6
-- Neutral, A7-3, A14 art parts through UIKit.Art*). Every rect comes from HudLayout.Compute
-- (docs/design/hud_layout_B_imgdev_2026-10-06.json). Client only: reads attributes / GameState / the Fx and Quests
-- remotes, writes only client->server intents.
-- Published layout (logical MainGui units, a NEW table on every layout pass; nil until the first one):
--   HUD.Layout = { W, H, Scale, Rects = HudLayout rects (event = the next-event line, tiles = the icon row), ChipsBottom,
--   ClusterTop, ClusterLeft, TopCenterX, TopCenterW, LeftX, RightX }. After each pass HUD calls EventHUD.Relayout,
--   MiniMap.Relayout and UIKit.PlaceNotify (pcall'd; any of them may be missing). HUD.TopCenterX / TopCenterW = the war
--   meter column.
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

-- build sizes (UI units before MainGui's UIScale; applyLayout sizes every block from its HudLayout rect), grouped in one
-- table because this chunk is close to Luau's 200-locals limit.
local IS_TOUCH = UserInputService.TouchEnabled
local L = {
	KeyDevice = UserInputService.KeyboardEnabled and not IS_TOUCH, -- U1: key badges for keyboards only (never touch)
	ShowKeys = UserInputService.KeyboardEnabled and not IS_TOUCH, -- BB1: KeyDevice and Settings.KeyBadges (L.RefreshKeys)
	Attack = IS_TOUCH and 136 or 120,
	Release = IS_TOUCH and 102 or 90,
	Square = IS_TOUCH and 72 or 60, -- rail squares / 자동
	QuestRowH = IS_TOUCH and 58 or 50,
	QuestGap = 4,
	QuestHeaderH = IS_TOUCH and 32 or 28,
	OverlayW = 340, -- touch quest overlay (CR-M25)
	ChipH = IS_TOUCH and 24 or 26, -- v2 chip row (18 px phone / 21 px PC)
	TouchText = 15, -- U5: 15 units = 11 real px at the 0.75 touch UIScale
	-- quest row metrics (badge / 교체 width, button and bar heights, text size)
	Row = IS_TOUCH and { Badge = 40, BadgeH = 20, Reroll = 56, BtnH = 22, Reward = 72, BarH = 18, Text = 15 }
		or { Badge = 30, BadgeH = 15, Reroll = 40, BtnH = 18, Reward = 58, BarH = 15, Text = 13 },
	-- A23-26 v2 / A23-40 B
	HL = nil, -- HudLayout (required in HUD.Init)
	Rects = nil, -- the last pass's rects
	PotionGap = 7.5, -- du between the HP and MP potion buttons (6 px at the PC UIScale 0.8)
	Badge = { Halo = "LevelBadgeHalo", Horns = "LevelBadgeHorns", Neutral = "LevelBadgeArtisan" }, -- else LevelBadge
	Glyph = { Warrior = "GlyphSword", Mage = "GlyphStaff", Archer = "GlyphBow" }, -- attack button (IconAttack fallback)
	-- A23-40 icon tile row, left to right: the windows opened often (A23-40 정정: 캐릭터 · 가방 · 스킬 · 지도 · 랭킹 · 펫).
	-- Window = the Panels window the tile opens (the tile shows once it is registered; Alt = an older window it opens
	-- until then), Map = the world map; Key = Keybinds action for the key badge; Keep = shown first when the row has
	-- fewer slots than tiles (phones: the rest fold out of [메뉴], in front of its own squares)
	Tiles = {
		{ Id = "Character", Icon = "IconCharacter", Window = "Character", Key = "Character", Keep = 2 },
		{ Id = "Bag", Icon = "IconBag", Window = "Bag", Alt = "Items", Key = "Bag", Keep = 1 },
		{ Id = "Skills", Icon = "IconSkills", Window = "Skills", Key = "Skills", Keep = 4 },
		{ Id = "Map", Icon = "IconMap", Map = true, Key = "Map", Keep = 1 },
		{ Id = "Ranking", Icon = "IconRanking", Window = "Ranking", Key = "Ranking", Keep = 5 },
		{ Id = "Pet", Icon = "IconPetBabySlime", Window = "Pet", Keep = 6 },
	},
	-- A23-40 정정 (user 2026-10-06 "메뉴는 오른쪽 위에, 누르면 옆으로 좌르륵"; 검수: 새 소식 · 이동 · 도움말 · 설정): the
	-- squares [메뉴] folds out to its left, left to right. 직업 바꾸기 · 환생 · 오프닝 다시 보기 · 이름 숨기기 · 휴가 are
	-- 설정 rows and 닉네임 a 내 캐릭터 row (BB13); until 설정 is registered its square opens the old 메뉴 window (Alt),
	-- which still lists them. A square shows once its window is registered (no silent no-op)
	Fold = {
		{ Id = "News", Icon = "IconNews", Window = "News" },
		{ Id = "Travel", Icon = "IconTravel", Window = "Travel" },
		{ Id = "Help", Icon = "IconHelp", Window = "Help", Key = "Help" },
		{ Id = "Settings", Icon = "IconSettings", Window = "Settings", Alt = "Menu" },
	},
	FoldTime = 0.2, -- s: the squares slide out of [메뉴] to the left (A23-38: 0.15-0.25 s), FoldStep apart
	FoldStep = 0.02,
	FoldBack = 0.15, -- s: folding back in
	FoldPad = 10, -- du above / below the squares inside the clipping frame (key badges, the glow)
	TileIcon = 0.6, -- icon side / tile side (the name sits under it inside the tile)
	TileTint = 0.15, -- MenuTile ImageTransparency over the world (sheet a2338)
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
-- kill rows use their monster head (IconMon<Unit>) when it exists; these are the fallbacks per row type
local QUEST_ICON = { tutorial = "IconMonSlime", Kill = "IconScroll", Golden = "IconScroll", Goose = "IconGoose" }

local GUIDE_SECONDS = NEXT.GuideSeconds or 90
local GUIDE_ZONES = NEXT.GuideZones or { "GoblinWoods", "SkeletonRuins" }
local TUT_GUIDE_STEP = (type(TUT.Steps) == "table" and TUT.Steps.Guide) or 1
local TUT_GUIDE_ZONE = TUT.GuideZone or "SlimeMeadow"
local TUT_GUIDE_TEXT = TUT.GuideText or "여기로!"
local TUT_QUEST_ID = TUT.QuestId or "tutorial"

-- HUD display strings (the literals of TECH_SPEC §4.23 HUD; game messages come from Config.Text)
local TXT = {
	LevelTag = "Lv",
	PowerLine = "Lv %d · %s %s", -- 'Lv 10 · 전투력 424' (A23-26)
	Pouch = "· %s %s", -- after the power line: '· 주머니 1.2K' (검수 2026-10-06: carried gold can be stolen)
	PouchLine = "%s %s", -- its own line under the XP bar when the power line is too narrow
	CarriedTag = "주머니",
	Wanted = "현상 %s", -- danger chip (Horns): the wanted stars
	WantedBounty = " · %s",
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
	BullyPenalty = "깡패 벌칙: 자동 전투 불가 · 경험치·드랍 절반 (%d분)", -- A23-22
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
	Map = "지도",
	Menu = "메뉴",
	Pet = "펫",
	Bag = "가방",
	Auto = "자동",
	-- A23-40 icon tiles (names under the icons)
	TileCharacter = "캐릭터",
	TileSkills = "스킬",
	TileRanking = "랭킹",
	TileSettings = "설정",
	TileNews = "새 소식",
	TileTravel = "이동",
	TileHelp = "도움말",
	-- A23-40 quest lines (no plate): "3/5" after the text, the claim chip, the fold-out list toggle
	QuestLineNums = "%s/%s",
	QuestLineSummary = "오늘의 퀘스트 %d/%d",
	QuestOpenList = "▼",
	QuestCloseList = "▲",
	MoreChips = "+%d",
	TravelLeft = "%s %.1f초",
	ZoneGuide = "%s!",
	Monster = "몬스터",
}

----------------------------------------------------------------- state
local ui = {}
local jumpButton = nil
local jumpConns = {}
local layoutPending = false

local holdSources = {} -- [source] = true; source = "mouse" | "key:<KeyCode>" | "pad:<KeyCode>" | InputObject (button press)
local holdToken = 0
local lastAction = {}

local prevLevel = nil
local levelBaselineReady = false


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

-- desktop: legacy chat sits top-left over the stats block; move its window to the bottom-left instead.
-- SetCore throws until the chat CoreScript has registered it, so retry for a while. TextChatService places
-- its own window through ChatWindowConfiguration (VerticalAlignment = Bottom in the place file).
local LEGACY_CHAT_POS = UDim2.new(0, 0, 0.6, 0)
-- TextChatService: close the chat window once at start (SetCore throws until the chat CoreScript registered it)
function L.CloseChatOnce()
	local okVersion, isTcs = pcall(function()
		return TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
	end)
	if not okVersion or not isTcs then return end
	for _ = 1, 20 do
		if pcall(StarterGui.SetCore, StarterGui, "ChatActive", false) then return end
		task.wait(0.5)
	end
end

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
local refreshChips -- assigned with the chips (refreshStats calls it for the wanted chip)
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
------------------------------------------------------------------ BB5 "전투력" (Config.CombatPower, server attribute)
-- Desktop: right half of the class row; touch: right half of the bank row. A rise floats a gold "+N" and counts the
-- number up (not when the level changed in the same moment: the level-up banner already celebrates). Drops are silent.
-- Changes within 0.4 s merge; while the opening / a picker is open one pending popup waits. Tap -> "Character" window.
L.Pow = { Shown = nil, Base = nil, Seq = 0, LevelAt = -10, MergeAt = 0, Pending = false, Merge = 0.4, Count = 0.6 }

function L.PowerValue()
	local v = tonumber(attr("CombatPower", nil))
	if v then return math.floor(v) end
	local lv = math.floor(num("Level", 1))
	local tier = math.clamp(math.floor(num("WeaponTier", 1)), 1, Config.MaxWeaponTier)
	return Config.CombatPower(lv, tier, num("WeaponEnhance", 0)) -- before the server's first set
end

function L.PowerText(n)
	return string.format(TXT.PowerLine, math.floor(num("Level", 1)), Config.Power.Text.Label, Util.FormatInt(n))
end

function L.PowerOpen()
	local P = C and C.Panels
	if type(P) == "table" and type(P.Has) == "function" and P.Has("Character") then pcall(P.Open, "Character") end
end

-- a transparent tap area (>= 44 real px tall where possible) over a label / portrait
function L.PowerHit(target)
	local hit = UIKit.Create("TextButton", {
		Name = "OpenCharacter",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = (target.ZIndex or 1) + 2,
		Parent = target,
	})
	hit.Activated:Connect(L.PowerOpen)
	return hit
end

-- 'Lv 10 · 전투력 424 · 주머니 1.2K' (A23-26, 검수 2026-10-06 (a)): one row on Rects.power_line; both labels follow their
-- text. Layout B has no line for the pouch under the XP bar (the tile row is there): when the pair does not fit the row
-- the pouch hides (L.CheckPouch); 내 캐릭터 still shows it
function L.PowerBuild(parent)
	ui.powerRow = UIKit.Create("Frame", {
		Name = "PowerLine",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(260, 20),
		ZIndex = 2,
		Parent = parent,
	}, {
		UIKit.Create("UIListLayout", {
			Name = "List",
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	local function line(name, order, color, bold, par)
		return L.FitText(artLabel(false, {
			Name = name,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextSize = 14,
			Number = true,
			Color = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = par,
		}), 13, bold)
	end
	ui.power = line("Power", 1, ac("GoldText", Theme.Gold), true, ui.powerRow)
	ui.power.Text = L.PowerText(L.PowerValue())
	ui.pouch = line("Pouch", 2, ac("LightSub", Theme.SubText), false, ui.powerRow)
	-- A23-35 / A23-40: no plate under the line (PC: over the ground) -> the dark text style's navy rim; gold stays gold
	-- (the white -> cream gradient multiplies the colour)
	if type(UIKit.StyleText) == "function" then
		UIKit.StyleText(ui.power, "Number")
		UIKit.StyleText(ui.pouch, "Number")
		ui.power.TextColor3 = ac("GoldText", Theme.Gold)
	end
	L.PowerHit(ui.powerRow)
	ui.power:GetPropertyChangedSignal("AbsoluteSize"):Connect(L.CheckPouch)
	ui.pouch:GetPropertyChangedSignal("AbsoluteSize"):Connect(L.CheckPouch)
end

-- the pouch rides the power line while both fit its rect (2du spare against flicker), else it hides
function L.CheckPouch()
	local R = L.Rects
	if not R or not ui.power or not ui.pouch or not ui.powerRow then return end
	local s = currentScale()
	local gap = ui.powerRow.List.Padding.Offset
	local need = (ui.power.AbsoluteSize.X + ui.pouch.AbsoluteSize.X) / s + gap
	local fits = need <= R.power_line.W - (ui.pouch.Visible and 0 or 2)
	if ui.pouch.Visible ~= fits then ui.pouch.Visible = fits end
end

function L.PowerSet(n)
	L.Pow.Shown = n
	if ui.power then ui.power.Text = L.PowerText(n) end
end

-- gold "+N" floating up from the end of the power number, and the number counting up to the new value. The popup sits on
-- the plate group just above the power label's right edge (never over the pouch: 검수 2026-10-06, BB5). delta = the real
-- rise (from is only where the count-up starts; it may be mid-way through an earlier count-up).
function L.PowerPopup(from, to, delta)
	local label = ui.power
	if not label or not label.Parent or not ui.stats then L.PowerSet(to) return end
	L.Pow.Seq += 1
	local seq = L.Pow.Seq
	local s = currentScale()
	local origin = ui.stats.AbsolutePosition
	local x = (label.AbsolutePosition.X + label.AbsoluteSize.X - origin.X) / s
	local y = (label.AbsolutePosition.Y - origin.Y) / s
	local pop = artLabel(false, {
		Name = "PowerUp",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(90, IS_TOUCH and 22 or 18),
		TextScaled = true,
		MaxTextSize = IS_TOUCH and 18 or 15,
		Number = true,
		Color = ac("GoldText", Theme.Gold),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "+" .. Util.FormatInt(delta or (to - from)), -- next to the number, so the bare "+N"
		ZIndex = 8,
		Parent = ui.stats,
	})
	TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(x, y - 22), TextTransparency = 1,
	}):Play()
	task.delay(1.2, function() pop:Destroy() end)
	task.spawn(function()
		local t0 = os.clock()
		while seq == L.Pow.Seq do
			local k = math.clamp((os.clock() - t0) / L.Pow.Count, 0, 1)
			L.PowerSet(math.floor(from + (to - from) * k + 0.5))
			if k >= 1 then break end
			task.wait(1 / 30)
		end
	end)
end

-- 0.4 s after the first change: compare with the value shown before it
function L.PowerSettle()
	local P = L.Pow
	if pickersOpen() then
		P.Pending = true -- one popup waits for the opening / picker to close (checked again by the next change / loop)
		task.delay(1, L.PowerSettle)
		return
	end
	P.Pending = false
	P.MergeAt = 0
	local n, base = L.PowerValue(), P.Base or L.PowerValue()
	P.Base = n
	if n > base and os.clock() - P.LevelAt > P.Merge + 0.3 then
		L.PowerPopup(P.Shown or base, n, n - base)
	else
		P.Seq += 1 -- stop a running count-up
		L.PowerSet(n)
	end
end

function L.PowerChanged()
	local P = L.Pow
	-- the baseline starts only after the save loaded and the class was picked (no popup for the first number)
	if attr("DataLoaded", false) ~= true or attr("ClassChosen", false) ~= true or P.Base == nil then
		if attr("DataLoaded", false) == true and attr("ClassChosen", false) == true then P.Base = L.PowerValue() end
		P.Seq += 1
		L.PowerSet(L.PowerValue())
		return
	end
	if P.MergeAt > 0 or P.Pending then return end -- already waiting: the settle reads the latest value
	P.MergeAt = os.clock()
	task.delay(P.Merge, L.PowerSettle)
end

-- A23-26 v2 top-left plate, no card: the round portrait (my live 3D head in the PortraitRing hole, the account headshot
-- while it loads) with the faction level badge on its lower-left, HP / MP bars beside it (VitalsUI), the power line under
-- them and a thin XP bar under the whole block. ui.stats is a transparent full-screen group; every piece is placed from
-- the HudLayout rects by L.LayoutPlate. Tapping the portrait or the power line opens 내 캐릭터 (L.PowerHit shows the
-- hit area only once Panels has the window: no silent no-op).
local function buildStats(root)
	local f = UIKit.Create("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	})
	ui.stats = f
	local holder = UIKit.Create("Frame", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(80, 80),
		ZIndex = 2,
		Parent = f,
	})
	local holePos, holeSize = UIKit.ArtInner("PortraitRing")
	local head = UIKit.Create("ImageLabel", {
		Name = "Headshot",
		Image = UIKit.HeadshotImage(),
		ScaleType = Enum.ScaleType.Crop,
		BackgroundColor3 = ac("NavyDeep", Theme.Bg),
		Position = holePos or UDim2.fromScale(0.17, 0.16),
		Size = holeSize or UDim2.fromScale(0.67, 0.67),
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
	ui.portraitHit = L.PowerHit(holder)
	-- faction-shaped level badge over the ring's lower-left (L.RefreshBadge builds the art + the number)
	ui.badgeHolder = UIKit.Create("Frame", {
		Name = "LevelBadge",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(-0.1, 1.1),
		Size = UDim2.fromScale(0.48, 0.48),
		ZIndex = 4,
		Parent = holder,
	})
	L.RefreshBadge()
	C.VitalsUI.BuildStats(f, IS_TOUCH)
	L.PowerBuild(f)
	-- thin XP bar (8 px PC / 6 px phone: no text inside)
	local xpFrame, setXP, xpText = UIKit.ArtBar({
		Name = "XPBar",
		Size = UDim2.fromOffset(300, IS_TOUCH and 8 or 10),
		Color = ac("XPBlue", Theme.XP),
		Parent = f,
	})
	ui.setXP = setXP
	ui.xpFrame = xpFrame
	ui.xpText = xpText
	xpText.Visible = false
	ui.potions = C.VitalsUI.BuildPotions(root, IS_TOUCH)
end

-- faction-shaped level badge (bundle 6): Halo ivory centre with a dark number, Horns / Artisan / none navy with light
function L.RefreshBadge()
	local key = L.Badge[getFaction()] or "LevelBadge"
	if ui.badgeKey == key and ui.level and ui.level.Parent then return end
	ui.badgeKey = key
	ui.badgeHolder:ClearAllChildren()
	UIKit.ArtFrame(key, {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = ui.badgeHolder,
	}, { StrokeThickness = 2 })
	local facePos, faceSize = UIKit.ArtInner(key)
	local face = UIKit.Create("Frame", {
		Name = "Face",
		BackgroundTransparency = 1,
		Position = facePos or UDim2.fromScale(0.17, 0.18),
		Size = faceSize or UDim2.fromScale(0.65, 0.62),
		ZIndex = 5,
		Parent = ui.badgeHolder,
	})
	local ink = key == "LevelBadgeHalo"
	ui.level = L.FitText(artLabel(ink, {
		Name = "Level",
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		MaxTextSize = 26,
		Number = true,
		Color = ink and ac("Ink", COL.Dark) or ac("Light", COL.White),
		Text = tostring(math.floor(num("Level", 1))),
		ZIndex = 6,
		Parent = face,
	}), 14, true)
end

-- places the plate from the HudLayout rects
function L.LayoutPlate(R)
	local p = R.portrait
	ui.portraitHolder.Position = UDim2.fromOffset(p.X, p.Y)
	ui.portraitHolder.Size = UDim2.fromOffset(p.W, p.H)
	C.VitalsUI.PlaceBars(R.hp_bar, R.mp_bar)
	local pl = R.power_line
	ui.powerRow.Position = UDim2.fromOffset(pl.X, pl.Y)
	ui.powerRow.Size = UDim2.fromOffset(pl.W, pl.H)
	local xp = R.xp_bar
	ui.xpFrame.Position = UDim2.fromOffset(xp.X, xp.Y)
	ui.xpFrame.Size = UDim2.fromOffset(xp.W, xp.H)
	L.CheckPouch()
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

-- gold 빛 fill from the left and crimson 뿔 fill from the right inside the BarTrack capsule, the faction badges (bundle 6)
-- over both ends, the crown riding the split, info pills under it. applyLayout sizes it from Rects.war_meter (L.LayoutWar).
local function buildWar(root)
	local W = 360
	local w = UIKit.Create("Frame", {
		Name = "WarMeter",
		Position = UDim2.new(0.5, -W / 2, 0, 8 + TOP_FALLBACK),
		Size = UDim2.fromOffset(W, 56),
		BackgroundTransparency = 1,
		Parent = root,
	})
	ui.war = w
	local shieldW, barY, barH = 30, 8, 22
	-- Bar / Info follow the meter's width; L.LayoutWar fits them to its height
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
	for _, s in { { "LevelBadgeHalo", 0, "ShieldHalo" }, { "LevelBadgeHorns", 1, "ShieldHorns" } } do
		UIKit.ArtImage(s[1], {
			Name = s[3],
			AnchorPoint = Vector2.new(s[2], 0.5),
			Position = UDim2.new(s[2], 0, 0, barY + barH / 2),
			Size = UDim2.fromOffset(shieldW + 4, shieldW + 4),
			ZIndex = 3,
			Parent = w,
		})
	end
	ui.warBar = bar

	local row = UIKit.Create("Frame", {
		Name = "Info",
		Position = UDim2.fromOffset(0, barY + barH + 3),
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
	ui.warInfo = row
end

-- the bar keeps 22du, the info pills take the rest of the meter's height (Rects.war_meter: 57.5du PC, 50.7du phone)
function L.LayoutWar(h)
	local info = math.clamp(h - 8 - 22 - 3, 14, 20)
	ui.warInfo.Position = UDim2.fromOffset(0, 8 + 22 + 3)
	ui.warInfo.Size = UDim2.new(1, 0, 0, info)
	for _, pill in { ui.warTimePill, ui.warSiege, ui.warPoints } do
		if pill then pill.Size = UDim2.fromOffset(0, info) end
	end
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
	-- applyLayout sets the width (CR-L36: the war meter column). A23-40: one row only (no wrapping); chips that do not
	-- fit fold into the '+N' chip (L.CheckChipFit)
	ui.chips = UIKit.Create("Frame", {
		Name = "StatusChips",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 106 + TOP_FALLBACK),
		Size = UDim2.fromOffset(900, L.ChipH + 6),
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
	ui.chipList = chipList
	chipList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() L.CheckChipFit() end)
	ui.chips:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() L.CheckChipFit() end)
	ui.chipPal = {
		Safe = { ac("ChipSafe", Theme.Good), ac("ChipSafeRim", Theme.Good), ac("ChipSafeText", COL.Dark) },
		Rookie = { ac("ChipRookie", Theme.XP), ac("ChipRookieRim", Theme.XP), ac("ChipRookieText", COL.Dark) },
	}
	-- A23-26 order: zone -> luck -> danger (bully, wanted, combat) -> rookie / protected -> blessing, size, kaiju queue.
	-- A23-40: the first L.MaxChips that show stay, the rest fold into one '+N' chip (refreshChips)
	local icons = { Blessing = "Crown", Zone = "IconSafe", Rookie = "IconSprout", Luck = "IconClover", Wanted = "IconStar" }
	ui.chip = {}
	L.ChipOrder = { "Zone", "Luck", "Bully", "Wanted", "Combat", "Rookie", "Protected", "Blessing", "Size", "Kaiju" }
	L.MaxChips = IS_TOUCH and 2 or 3 -- the phone row is 240 px wide
	for i, key in L.ChipOrder do
		ui.chip[key] = makeChip(key, i, icons[key])
	end
	ui.chipMore = makeChip("More", #L.ChipOrder + 1, nil)
	L.ChipFit, L.ChipWantKey = L.MaxChips, ""
end

-- A23-40: the row is too wide for its rect -> one chip fewer (the '+N' chip takes it); refreshChips starts again from
-- L.MaxChips whenever the set of chips that want to show changes
function L.CheckChipFit()
	if not ui.chips or not ui.chipList then return end
	local content, room = ui.chipList.AbsoluteContentSize.X, ui.chips.AbsoluteSize.X
	if room > 0 and content > room + 1 and L.ChipFit > 1 then
		L.ChipFit -= 1
		task.defer(function()
			local ok, err = pcall(refreshChips)
			if not ok then warnThrottled("chip fit failed: " .. tostring(err)) end
		end)
	end
end

----------------------------------------------------------------- building: quests
-- navy header plate (RibbonHeader = Firefly PanelHeader: star in its left disc, "오늘의 퀘스트 (1/3) · 받기 N", chevron)
-- over parchment rows, on Rects.quest (A23-26: top-right under the rail). Desktop: the header toggles the list
-- (collapsed = header + the 'now do' row + one more, 검수 2026-10-06 (b): the next-goal row always shows). Touch (U5 /
-- CR-M25): two lines in the header (line 1 = the 'now do' row, line 2 = story call / 받기 N / today's count); the rows
-- with 받기 / 교체 live in an overlay opened from the header.
local function buildQuests(root)
	ui.quests = UIKit.Create("Frame", {
		Name = "Quests",
		Position = UDim2.fromOffset(12, 200 + TOP_FALLBACK),
		Size = UDim2.fromOffset(300, 0),
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
		Size = UDim2.fromOffset(300, hh),
		Parent = ui.quests,
	}, function()
		-- B15: on touch the header line reads "…말을 걸어요 — 눌러서 보기" while a story waits: one tap opens it
		if IS_TOUCH and questState.CallEntry and L.PinnedTap then
			L.PinnedTap(questState.CallEntry)
			return
		end
		-- review 2026-10-06: the line reads "5/5 ... [받기]를 눌러요": one tap claims (no list first)
		local se = questState.ShownEntry
		if IS_TOUCH and se and L.PinnedTap and L.ClaimableMission(se) then
			L.PinnedTap(se)
			return
		end
		toggleQuests()
	end, { CornerRadius = UDim.new(0, 10) })
	-- the star sits in the plate's left disc; L.LayoutQuestHeader follows the header height
	ui.questHeaderIcon = UIKit.ArtImage("IconStar", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, hh * 0.47, 0.5, 0),
		Size = UDim2.fromOffset(hh * 0.6, hh * 0.6),
		ZIndex = 2,
		Parent = ui.questHeader,
	})
	ui.questHeaderText = artLabel(false, {
		Name = "Text",
		Position = UDim2.fromOffset(hh + 4, 4),
		Size = UDim2.new(1, -hh - 30, 1, -8),
		TextScaled = true,
		MaxTextSize = 14,
		Title = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
		Parent = ui.questHeader,
	})
	ui.questChevron = artLabel(false, {
		Name = "Chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(16, hh - 8),
		TextScaled = true,
		MaxTextSize = 14,
		Text = TXT.QuestExpand,
		ZIndex = 2,
		Parent = ui.questHeader,
	})
	L.FitText(ui.questHeaderText, 13, true)
	L.FitText(ui.questChevron, 11)
	if IS_TOUCH then
		-- line 2 (A23-26 phone quest line): story call / 받기 N / today's count
		ui.questHeaderSub = L.FitText(artLabel(false, {
			Name = "Sub",
			Size = UDim2.new(1, -hh - 30, 0.5, -2),
			TextScaled = true,
			MaxTextSize = 14,
			Color = ac("LightSub", Theme.SubText),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 2,
			Parent = ui.questHeader,
		}), 12)
	end

	local listParent = ui.quests
	ui.questRowW = 300 -- applyLayout: Rects.quest width (desktop)
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

----------------------------------------------------------------- building: quest lines (A23-40: no plate)
-- Two outlined text lines on Rects.quest (PC: under the minimap; phones: beside it, outside the thumbstick zone):
-- [icon] what to do ... 3/5 | [받기]. Line 1 = the 'now do' row (pinned guide / next goal / waiting story / first
-- claimable / first daily), line 2 = the next one (else today's count). PC: each line is its own button (a claimable line
-- claims, the pinned / story line runs its action, any other line folds the full list out under the lines, ▼/▲).
-- Phones: the block is one thumb-size button (line 1 claimable -> claim, a waiting story -> open it, else the list
-- overlay). Text: UIKit.StyleText dark mode (white -> cream, navy rim) so it reads over the world.
function L.BuildQuestLines(root)
	local block = UIKit.Create("TextButton", {
		Name = "QuestLines",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 60),
		Active = IS_TOUCH, -- PC: the lines are the buttons
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	block.Activated:Connect(function()
		if IS_TOUCH then L.QuestBlockTap() end
	end)
	ui.questLines = block
	ui.qline = {}
	-- phones: the 12 px name-tag floor (the block is 150 px wide); PC: body text
	local style = IS_TOUCH and "NameTag" or "Body"
	for i = 1, 2 do
		-- one row = [icon][text (fills the rest, cut with …)][3/5 | 받기][▼ on line 1, PC]: a horizontal list with a
		-- flexible text cell, so a line without numbers gives the text the whole width
		local row = UIKit.Create(IS_TOUCH and "Frame" or "TextButton", {
			Name = "Line" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0.5, 0),
			Position = UDim2.fromScale(0, (i - 1) * 0.5),
			ZIndex = 3,
			Parent = block,
		}, {
			UIKit.Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
		})
		if not IS_TOUCH then
			row.Text = ""
			row.AutoButtonColor = false
			row.Activated:Connect(function() L.QuestLineTap(i) end)
		end
		local icon = UIKit.ArtImage("IconScroll", {
			Name = "Icon",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(24, 24),
			ZIndex = 4,
			Parent = row,
		})
		local text = UIKit.StyledLabel({
			Name = "Text",
			LayoutOrder = 2,
			Size = UDim2.new(0, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			ZIndex = 4,
			Parent = row,
		}, style)
		UIKit.Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = text })
		local nums = UIKit.StyledLabel({
			Name = "Nums",
			LayoutOrder = 3,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
			Parent = row,
		}, "Number")
		-- 받기: the green candy pill (same art as the list rows' 받기), text on it
		local claim = UIKit.ArtFrame("Pill", {
			Name = "Claim",
			LayoutOrder = 4,
			ImageColor3 = COL.HotTint,
			Visible = false,
			ZIndex = 4,
			Parent = row,
		}, { Color = Theme.Good, CornerRadius = UDim.new(0.5, 0) })
		local claimText = UIKit.StyledLabel({
			Name = "Text",
			Size = UDim2.fromScale(1, 1),
			Text = TXT.Claim,
			ZIndex = 5,
			Parent = claim,
		}, "Number")
		ui.qline[i] = { Row = row, Icon = icon, Text = text, Nums = nums, Claim = claim, ClaimText = claimText, Entry = nil }
	end
	-- PC: ▼ / ▲ at the end of line 1 folds the full list (the parchment rows) out under the lines
	if not IS_TOUCH then
		ui.questFold = UIKit.StyledLabel({
			Name = "Fold",
			LayoutOrder = 5,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = TXT.QuestOpenList,
			ZIndex = 4,
			Parent = ui.qline[1].Row,
		}, "Number")
	end
end

-- line metrics follow the rect (logical units): icon about the line height, text size from it (the style floors keep
-- it readable), the 받기 pill a little shorter than the line
function L.LayoutQuestLines(q)
	local block = ui.questLines
	if not block then return end
	block.Position = UDim2.fromOffset(q.X, q.Y)
	block.Size = UDim2.fromOffset(q.W, q.H)
	local lh = q.H / 2
	local iconS = math.floor(lh * 0.9)
	local textSize = math.max(12, math.floor(lh * 0.6))
	for _, l in ui.qline do
		if l.Icon then l.Icon.Size = UDim2.fromOffset(iconS, iconS) end
		l.Text.TextSize = textSize
		l.Nums.TextSize = textSize
		l.Claim.Size = UDim2.fromOffset(math.floor(lh * 2.3), math.floor(lh * 0.86))
		l.ClaimText.TextSize = math.max(12, math.floor(lh * 0.5))
	end
	if ui.questFold then ui.questFold.TextSize = math.max(12, math.floor(lh * 0.55)) end
end

-- one line: icon (monster head / row type), text, progress or 받기 (CR-M27 / CR-L31 numbers)
function L.SetQuestLine(l, e, label, nums)
	l.Entry = e
	l.Row.Visible = label ~= nil
	if not label then return end
	l.Text.Text = label
	local claimable = e ~= nil and e.Progress >= e.Target and e.CanClaim
		and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub") -- the list rows' 받기 rule (refreshQuests)
	l.Claim.Visible = claimable
	l.Nums.Visible = not claimable and nums ~= nil
	l.Nums.Text = nums or ""
	if l.Icon then
		local head = e and e.Unit and UIKit.ArtId("IconMon" .. e.Unit)
		local key = e and (QUEST_ICON[e.Id] or "IconScroll") or "IconStar"
		l.Icon.Image = head or UIKit.ArtId(key) or UIKit.ArtId("IconScroll") or l.Icon.Image
	end
end

-- PC line press: claim / pinned or story action / fold the list
function L.QuestLineTap(i)
	local l = ui.qline and ui.qline[i]
	local e = l and l.Entry
	if not e then
		toggleQuests()
		return
	end
	local row = nil
	for _, r in questRows do
		if r.Entry == e then row = r break end
	end
	if e.Progress >= e.Target and e.CanClaim and row and row.Claim.Visible then
		L.OnClaim(row) -- assigned with onClaim below
	elseif (e.Pinned or e.Story) and L.PinnedTap then
		L.PinnedTap(e, row)
	else
		toggleQuests()
	end
end

-- phone block press: line 1 claimable -> claim; a waiting story or the pinned row -> its action; else the list overlay
function L.QuestBlockTap()
	if questState.CallEntry and L.PinnedTap then
		L.PinnedTap(questState.CallEntry)
		return
	end
	local l = ui.qline and ui.qline[1]
	local e = l and l.Entry
	if e and e.Progress >= e.Target and e.CanClaim then
		for _, r in questRows do
			if r.Entry == e and r.Claim.Visible then
				L.OnClaim(r)
				return
			end
		end
	end
	toggleQuests()
end

-- header plate pieces follow its height (the disc is about as wide as the plate is tall)
function L.LayoutQuestHeader(w, h)
	ui.questHeader.Size = UDim2.fromOffset(w, h)
	local disc = math.min(h, 40)
	if ui.questHeaderIcon then
		ui.questHeaderIcon.Position = UDim2.new(0, disc * 0.5, 0.5, 0)
		ui.questHeaderIcon.Size = UDim2.fromOffset(disc * 0.62, disc * 0.62)
	end
	local tx = disc + 4
	if ui.questHeaderSub then
		ui.questHeaderText.Position = UDim2.fromOffset(tx, 3)
		ui.questHeaderText.Size = UDim2.new(1, -tx - 26, 0.5, -3)
		ui.questHeaderSub.Position = UDim2.new(0, tx, 0.5, 0)
		ui.questHeaderSub.Size = UDim2.new(1, -tx - 26, 0.5, -3)
	else
		ui.questHeaderText.Position = UDim2.fromOffset(tx, 4)
		ui.questHeaderText.Size = UDim2.new(1, -tx - 26, 1, -8)
	end
	ui.questChevron.Size = UDim2.fromOffset(16, math.max(12, h - 8))
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

-- BB1: the action's current key label (Keybinds; "" before Keybinds exists)
function L.KeyText(action)
	local kb = C and C.Keybinds
	if type(kb) ~= "table" or type(kb.Label) ~= "function" then return "" end
	local ok, text = pcall(kb.Label, action)
	return ok and type(text) == "string" and text or ""
end

-- BB1: true when the action has a key right now (an unbound action shows no badge)
function L.KeyBound(action)
	local kb = C and C.Keybinds
	if type(kb) ~= "table" or type(kb.KeyName) ~= "function" then return false end
	local ok, key = pcall(kb.KeyName, action)
	return ok and type(key) == "string" and key ~= ""
end

-- BB1: badges follow Keybinds.Changed and Settings.KeyBadges (BB3 [기타] 키 표시)
function L.RefreshKeys()
	local st = C and C.Settings
	local badges = true
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, v = pcall(st.Get, "KeyBadges")
		badges = not ok or v ~= false
	end
	L.ShowKeys = L.KeyDevice and badges
	for _, h in ui.keyHints or {} do
		if h.Label.Parent then
			h.Label.Text = L.KeyText(h.Action)
			h.Label.Visible = L.ShowKeys and L.KeyBound(h.Action)
		end
	end
end

-- small key badge (U1: keyboards only, never on touch). BB1: `action` = Config.Keybinds action id; the badge shows its
-- current key (it widens for "Ctrl" / "Num1") and L.RefreshKeys redraws it.
local function keyHint(parent, action, position, anchor)
	if not L.KeyDevice then return end
	local label = L.FitText(UIKit.Create("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(18, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ac("KeyHintBg", COL.Black),
		TextColor3 = ac("KeyHintText", COL.White),
		Font = af("Number", Theme.Font),
		TextSize = 13,
		Text = L.KeyText(action),
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
		UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
	}), 11)
	if not label then return end
	ui.keyHints = ui.keyHints or {}
	table.insert(ui.keyHints, { Label = label, Action = action })
	label.Visible = L.ShowKeys and L.KeyBound(action)
end

local doUpgrade, openMenu, openMap, inputAllowed -- forward (defined with the input code)

-- A23-38 / A23-40 icon tile (MenuTile = Firefly 471686b: navy tile, thin gold trim, a little see-through over the world):
-- the icon on top, its short name under it inside the tile, the key badge in the top-right corner (keyboards only).
-- applyLayout sizes it (square, Rects.tiles.Size).
local function tileButton(def, onClick)
	local btn = UIKit.ArtButton("MenuTile", {
		Name = "Tile" .. def.Id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
		ImageTransparency = L.TileTint,
		Visible = false,
		Parent = ui.buttons,
	}, onClick, { CornerRadius = UDim.new(0, 10), BackgroundTransparency = 0.25 })
	local iconProps = {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.07),
		Size = UDim2.fromScale(L.TileIcon, L.TileIcon),
		ZIndex = 3,
		Parent = btn,
	}
	-- 내 캐릭터 follows CharacterGender (IconCharacterF) through UIKit.CharacterIcon
	local img = (def.Id == "Character" and type(UIKit.CharacterIcon) == "function") and UIKit.CharacterIcon(iconProps)
		or UIKit.ArtImage(def.Icon, iconProps)
	local label = artLabel(false, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -4, 0.3, 0),
		TextScaled = true,
		MaxTextSize = 14,
		Title = true,
		Text = def.Text or "",
		ZIndex = 4,
		Parent = btn,
	})
	L.FitText(label, 12, true)
	if type(UIKit.StyleText) == "function" then UIKit.StyleText(label, "NameTag") end -- A23-38: white name, navy rim
	if def.Key then keyHint(btn, def.Key, UDim2.new(1, -2, 0, 2), Vector2.new(1, 0)) end
	return btn, label, img
end

-- A23-40 정정: [메뉴] (its own square, top-right on PCs, the tile row's right end on phones) and its fold-out: a clipping
-- frame left of [메뉴] with one square per fold entry (the L.Fold squares + a copy of every row tile for the phone row's
-- overflow). L.LayoutMenu places them from Rects.menu / Rects.fold, L.SetFold slides them out / back in
function L.BuildMenu(names)
	local btn, label = tileButton({ Id = "Menu", Icon = "GlyphMenu", Key = "Menu", Text = names.Menu }, function()
		L.WindowKey("Menu")
	end)
	btn.Visible = true
	btn.ZIndex = 3
	ui.menu, ui.menuLabel = btn, label
	ui.menuGlow = makeGlow(btn, UDim.new(0, 10))
	ui.fold = UIKit.Create("Frame", {
		Name = "MenuFold",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 2,
		Parent = ui.buttons,
	})
	ui.foldTiles = {}
	local function add(def, row)
		local copy = table.clone(def)
		copy.Text = names[def.Id]
		local b = tileButton(copy, function()
			L.FoldTap(copy)
		end)
		b.Name = "Fold" .. def.Id
		b.Parent = ui.fold
		local entry = { Def = copy, Button = b, Row = row }
		if def.Id == "Settings" then ui.settingsGlow = makeGlow(b, UDim.new(0, 10)) end
		table.insert(ui.foldTiles, entry)
	end
	for _, def in L.Tiles do add(def, true) end
	for _, def in L.Fold do add(def, false) end
	-- the squares' art loads now, so the first fold-out slides in with its icons (not blank squares)
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ ui.fold, btn })
		end)
	end)
end

-- the fold squares to show, nearest [메뉴] first: 설정, 도움말, 이동, 새 소식 (the registered ones), then on phones the
-- row tiles that did not fit the row, so the fold reads 캐릭터 … 펫 새 소식 이동 도움말 설정 [메뉴] from the left
function L.FoldEntries()
	local inRow = {}
	for _, t in ui.shownTiles or {} do inRow[t.Def.Id] = true end
	local list = {}
	for i = #(ui.foldTiles or {}), 1, -1 do
		local f = ui.foldTiles[i]
		local def = f.Def
		if (def.Map or L.TileWindow(def) ~= nil) and not (f.Row and inRow[def.Id]) then table.insert(list, f) end
	end
	return list
end

-- [메뉴] on its rect; the fold frame spans every fold line (left of [메뉴], FoldPad above and below)
function L.LayoutMenu(R)
	local m, f = R.menu, R.fold
	if not ui.menu or not m or not f or type(f.Lines) ~= "table" then return end
	L.Place(ui.menu, m)
	local pad = L.FoldPad
	local g = { X = f.X, Y = f.Y - pad, W = m.X - f.X, H = f.H + pad * 2, Size = f.Size, Gap = f.Gap, Lines = f.Lines,
		Right = m.X - f.Gap }
	ui.foldGeom = g
	ui.fold.Position = UDim2.fromOffset(g.X, g.Y)
	ui.fold.Size = UDim2.fromOffset(g.W, g.H)
	if ui.foldOpen then L.PlaceFold(false) end
end

-- slot i of the shown squares (1 = next to [메뉴]; line by line, Rects.fold.Lines): its frame-relative centre and the
-- start of its slide (just right of the frame = under [메뉴]'s left edge), or nil when the fold has no room for it
function L.FoldSlot(i)
	local g = ui.foldGeom
	if not g then return nil end
	local n = i
	for _, ln in g.Lines do
		if n <= ln.Cols then
			local cy = ln.Y + g.Size / 2 - g.Y
			return UDim2.fromOffset(g.Right - (n - 1) * (g.Size + g.Gap) - g.Size / 2 - g.X, cy),
				UDim2.fromOffset(g.W + g.Size / 2, cy)
		end
		n -= ln.Cols
	end
	return nil
end

-- the shown squares on their slots: animate = slide out of [메뉴] one after another (A23-38 좌르륵), else jump there
-- (a re-layout while open)
function L.PlaceFold(animate)
	local list = L.FoldEntries()
	local shown = {}
	for i, f in list do
		local target, start = L.FoldSlot(i)
		local b = f.Button
		if f.Tween then
			f.Tween:Cancel()
			f.Tween = nil
		end
		if target then
			shown[f] = true
			b.Size = UDim2.fromOffset(ui.foldGeom.Size, ui.foldGeom.Size)
			if animate then
				b.Position = start
				f.Tween = TweenService:Create(b, TweenInfo.new(L.FoldTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
					0, false, (i - 1) * L.FoldStep), { Position = target })
				f.Tween:Play()
			else
				b.Position = target
			end
		end
		b.Visible = target ~= nil
	end
	for _, f in ui.foldTiles do
		if not shown[f] then f.Button.Visible = false end
	end
	ui.foldShown = list
end

-- opens / folds back the [메뉴] squares. Phones: the fold lies on the tile row, which hides while it is open
function L.SetFold(open)
	open = open == true and ui.fold ~= nil and ui.foldGeom ~= nil
	if open == (ui.foldOpen == true) then return end
	ui.foldOpen = open
	ui.foldToken = (ui.foldToken or 0) + 1
	local token = ui.foldToken
	if open then
		ui.fold.Visible = true
		L.PlaceFold(true)
	else
		for i, f in ui.foldShown or {} do
			if f.Tween then f.Tween:Cancel() end
			local _, start = L.FoldSlot(i)
			if start and f.Button.Visible then
				f.Tween = TweenService:Create(f.Button, TweenInfo.new(L.FoldBack, Enum.EasingStyle.Quad,
					Enum.EasingDirection.In), { Position = start })
				f.Tween:Play()
			end
		end
		task.delay(L.FoldBack + 0.02, function()
			if ui.foldToken ~= token then return end
			ui.fold.Visible = false
			for _, f in ui.foldTiles do f.Button.Visible = false end
		end)
	end
	if IS_TOUCH then
		ui.tileKey = nil -- L.PickTiles re-applies the row's visibility (hidden under an open fold)
		L.PickTiles()
	end
end

-- a fold square: fold back, then open its window like a row tile
function L.FoldTap(def)
	L.SetFold(false)
	L.TileTap(def)
end

-- A23-38: a press outside [메뉴] and its squares folds them back (the press still does its own thing); Esc opens
-- Roblox's menu (GuiService.MenuOpened, HUD.Start). The pad's B joins with the pad wiring (BB21: every key goes through
-- Keybinds). InputObject.Position and AbsolutePosition share the gui-inset-relative screen space
function L.FoldInput(input)
	if not ui.foldOpen then return end
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	local px, py = input.Position.X, input.Position.Y
	local function inside(gui)
		local a, z = gui.AbsolutePosition, gui.AbsoluteSize
		return gui.Visible and px >= a.X and px <= a.X + z.X and py >= a.Y and py <= a.Y + z.Y
	end
	if inside(ui.menu) then return end
	for _, f in ui.foldShown or {} do
		if inside(f.Button) then return end
	end
	L.SetFold(false)
end

-- the fold folds back when a window opens (any way) or the HUD hides (a picker, the loading screen)
function L.FoldWatch()
	local panels = C and C.Panels
	local open = type(panels) == "table" and type(panels.IsOpen) == "function" and panels.IsOpen()
	if open or not (ui.root and ui.root.Visible) then L.SetFold(false) end
end

local function buildButtons(root)
	ui.buttons = UIKit.Create("Frame", {
		Name = "Buttons",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})

	-- 공격 (one press = one swing): Firefly orange disc + my class glyph (L.RefreshAttackGlyph) + "공격"
	ui.attack = roundButton("Attack", L.Attack, "BtnAttack", COL.AttackFill)
	L.RefreshAttackGlyph()
	artLabel(false, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.fromScale(0.62, 0.2),
		TextScaled = true,
		MaxTextSize = math.floor(L.Attack * 0.2),
		Title = true,
		Text = TXT.Attack,
		ZIndex = 4,
		Parent = ui.attack,
	})
	L.FitText(ui.attack:FindFirstChild("Label"), 16, true)
	keyHint(ui.attack, "Attack", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- 스킬 Q: Firefly blue disc (BtnSpecial); only MP and cooldown decide readiness
	local rel, relArt = roundButton("Release", L.Release, "BtnSpecial", COL.ReleaseFill)
	ui.release, ui.releaseArt = rel, relArt
	ui.releaseIcon = UIKit.ArtImage("IconSpecial", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
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
	keyHint(rel, "SkillQ", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- A23-40 icon tile row (U1: the menu key is B by default; Esc belongs to Roblox and M opens the map). A window tile
	-- shows once Panels has its window (no silent no-op: L.RefreshWindows); the pet tile waits for the pet window
	local names = { Character = TXT.TileCharacter, Bag = TXT.Bag, Skills = TXT.TileSkills, Map = TXT.Map,
		Ranking = TXT.TileRanking, Pet = TXT.Pet, Settings = TXT.TileSettings, Menu = TXT.Menu, News = TXT.TileNews,
		Travel = TXT.TileTravel, Help = TXT.TileHelp }
	ui.tiles = {}
	for i, def in L.Tiles do
		def.Text = names[def.Id]
		local btn, label = tileButton(def, function()
			L.TileTap(def)
		end)
		ui.tiles[i] = { Def = def, Button = btn, Label = label }
		if def.Id == "Bag" then ui.bagGlow = makeGlow(btn, UDim.new(0, 10)) end -- B14 scroll hint
	end
	L.BuildMenu(names)
	-- A23-1 auto combat ON/OFF (round, Firefly BtnRound): hidden until the crown-shard quest unlocks it (no "unlocks at
	-- ..." teaser); ON = gold ring, OFF = dimmed disc
	ui.auto, ui.autoArt = roundButton("Auto", L.Square, "BtnRound", COL.ReleaseFill)
	UIKit.ArtImage("Crown", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.5, 0.34),
		ZIndex = 3,
		Parent = ui.auto,
	})
	ui.autoLabel = L.FitText(artLabel(false, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromScale(0.8, 0.26),
		TextScaled = true,
		MaxTextSize = 14,
		Title = true,
		Text = TXT.Auto,
		ZIndex = 4,
		Parent = ui.auto,
	}), 12, true)
	ui.autoGlow = makeGlow(ui.auto, UDim.new(0.5, 0))
	keyHint(ui.auto, "Auto", UDim2.fromScale(0.85, 0.85), Vector2.new(0.5, 0.5))
	ui.auto.Activated:Connect(function()
		if inputAllowed() then L.ToggleAuto() end
	end)
	ui.auto.Visible = false
end

-- the attack button's glyph follows my class (bundle 6: sword / staff; bow arrives with bundle 7, IconAttack until then)
function L.RefreshAttackGlyph()
	if not ui.attack then return end
	local key = L.Glyph[getClass()]
	if not (key and UIKit.ArtId(key)) then key = "IconAttack" end
	if ui.attackGlyphKey == key then return end
	ui.attackGlyphKey = key
	local old = ui.attack:FindFirstChild("Icon")
	if old then old:Destroy() end
	UIKit.ArtImage(key, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Parent = ui.attack,
	})
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
	local level = math.floor(num("Level", 1))
	L.RefreshBadge()
	if ui.level then ui.level.Text = tostring(level) end

	local xp = math.max(0, num("XP", 0))
	if level >= Config.Levels.MaxLevel then
		ui.setXP(1)
		ui.xpText.Text = "MAX"
	else
		local need = math.max(1, Config.XPToNext(level))
		ui.setXP(xp / need)
		ui.xpText.Text = fmtNum(xp) .. " / " .. fmtNum(need)
	end

	-- the power line carries the level; the pouch (carried gold, it can be stolen) turns sack-orange while > 0
	L.PowerSet(L.Pow.Shown or L.PowerValue())
	local carried = math.max(0, num("CarriedGold", 0))
	ui.pouch.Text = string.format(TXT.Pouch, TXT.CarriedTag, fmtNum(carried))
	ui.pouch.TextColor3 = carried > 0 and (Theme.Sack or ac("GoldText", Theme.Gold)) or ac("LightSub", Theme.SubText)
	L.CheckPouch()
	if ui.chip then refreshChips() end -- the wanted chip follows stars / bounty
end

----------------------------------------------------------------- refresh: status chips
-- EventHUD's luck line (A23-26 luck chip); phones get the short one ('희귀 10.75%')
function L.LuckText()
	local ev = C and C.EventHUD
	if type(ev) ~= "table" then return nil end
	local fn = ev.LuckShort -- A23-40: the short form everywhere ('희귀 10.75%' next to the clover)
	if type(fn) ~= "function" then fn = ev.LuckSummary end
	if type(fn) ~= "function" then return nil end
	local ok, line = pcall(fn)
	if not ok or type(line) ~= "string" or line == "" then return nil end
	if IS_TOUCH and fn == ev.LuckSummary then line = string.gsub(line, "^.-·%s*", "") end
	return line
end

refreshChips = function()
	local f = getFaction()
	local now = Util.Now()
	local pal = ui.chipPal

	local luck = L.LuckText()
	setChip(ui.chip.Luck, luck ~= nil, luck, Theme.Good, false, nil, true)
	-- Horns wanted stars + bounty: a danger chip (the old card row)
	local stars = f == "Horns" and math.floor(num("WantedStars", 0)) or 0
	local bounty = f == "Horns" and math.max(0, num("Bounty", 0)) or 0
	local wanted = string.format(TXT.Wanted, string.rep("★", math.clamp(stars, 0, 5)))
	if bounty > 0 then wanted ..= string.format(TXT.WantedBounty, fmtNum(bounty)) end
	setChip(ui.chip.Wanted, stars > 0 or bounty > 0, wanted, Theme.Bad, false, nil, stars > 0)

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
	if f == "Neutral" then graceLeft = 0 end -- Neutral never fights players (A6): no grace chip either
	setChip(ui.chip.Rookie, rookieOn or graceLeft > 0, (not rookieOn and graceLeft > 0)
		and string.format(TXT.RookieGrace, graceLeft) or TXT.Rookie, Theme.XP, false, pal.Rookie, true)
	setChip(ui.chip.Protected, attr("Protected", false) == true, TXT.Protected, Theme.XP)
	setChip(ui.chip.Combat, num("InCombatUntil", 0) > now, TXT.InCombat, Theme.Revenge)
	local size = num("SizeMult", 1)
	setChip(ui.chip.Size, size > 1.001, string.format(TXT.Size, size), Theme.Gold)
	local bully = math.floor(num("BullyStacks", 0))
	local bullyLeft = math.max(1, math.ceil((num("BullyEndsAt", 0) - now) / 60)) -- A23-22 penalty minutes
	setChip(ui.chip.Bully, bully > 0, string.format(TXT.BullyPenalty, bullyLeft), Theme.Bad)
	setChip(ui.chip.Kaiju, attr("KaijuState", "None") == "Queued", TXT.KaijuQueued, Theme.Bad)

	-- A23-40: at most L.MaxChips chips in their order (fewer when they do not fit the row, L.CheckChipFit); the rest fold
	-- into one '+N' chip (no stacked rows)
	local wantKey = ""
	for _, key in L.ChipOrder do
		local chip = ui.chip[key]
		if chip and chip.Frame.Visible then wantKey ..= key .. "," end
	end
	if wantKey ~= L.ChipWantKey then
		L.ChipWantKey = wantKey
		L.ChipFit = L.MaxChips
	end
	local shownChips, folded = 0, 0
	for _, key in L.ChipOrder do
		local chip = ui.chip[key]
		if chip and chip.Frame.Visible then
			shownChips += 1
			if shownChips > L.ChipFit then
				chip.Frame.Visible = false
				folded += 1
			end
		end
	end
	setChip(ui.chipMore, folded > 0, string.format(TXT.MoreChips, folded), Theme.SubText)
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

-- B14: Panels.ItemsHint = I hold a scroll and have not opened 메뉴 → 아이템 this session
function L.ItemsHint()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.ItemsHint) ~= "function" then return false end
	local ok, hint = pcall(panels.ItemsHint)
	return ok and hint == true
end

-- a pulsing gold rim (makeGlow stroke) on / off; key = which one (L.Glows keeps its state and tween)
L.Glows = {}
function L.SetGlow(key, stroke, on)
	local g = L.Glows[key]
	if not g then
		g = {}
		L.Glows[key] = g
	end
	if g.On == on then return end
	g.On = on
	if g.Tween then
		g.Tween:Cancel()
		g.Tween = nil
	end
	if not stroke then return end
	if on then
		stroke.Transparency = 0
		stroke.Thickness = 3
		g.Tween = TweenService:Create(stroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 6 })
		g.Tween:Play()
	else
		stroke.Transparency = 1
		stroke.Thickness = 3
	end
end

-- 환생 ready / 휴가 days are 설정 rows now (A23-40 정정): [메뉴] and its 설정 square glow; the scroll hint (B14) glows 가방
local function refreshMenuGlow()
	local settings = num("Level", 1) >= Config.RebirthLevel(num("Rebirths", 0)) or num("VacationDays", 0) > 0
	L.SetGlow("menu", ui.menuGlow, settings)
	L.SetGlow("settings", ui.settingsGlow, settings)
	L.SetGlow("bag", ui.bagGlow, L.ItemsHint())
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
-- BB1 / A23-21: quest rows carry raw key tokens ('자동 전투 켜기 ({Auto})'; the server cannot know the device). Keyboards
-- show the current key (the "(…)" group goes while that action has no key), touch-only devices the button name
-- ('자동 버튼'). Rows are drawn again on Keybinds.Changed.
function L.QuestText(text)
	if type(text) ~= "string" or not string.find(text, "{", 1, true) then return text end
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.Fill) == "function" then
		-- keyOnly where keys are shown (Keybinds.ShowsKeys, review B5); without a keyboard Keybinds.Label gives the button
		local ok, out = pcall(kb.Fill, text, type(kb.ShowsKeys) == "function" and kb.ShowsKeys() == true)
		if ok and type(out) == "string" then return out end
	end
	return Config.FillKeys(text, (Config.KeyMap(nil, nil)))
end

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
				Text = L.QuestText(tostring(e.Text or "")),
				Progress = math.max(0, finite(e.Progress, 0)),
				Target = math.max(1, finite(e.Target, 1)),
				RewardGold = math.max(0, finite(e.RewardGold, 0)),
				Pinned = isPinned,
				CanClaim = e.CanClaim ~= false,
				ShowProgress = e.ShowProgress ~= false,
				TutorialStep = finite(e.TutorialStep, -1),
				NextGoal = e.NextGoal == true,
				Story = type(e.Story) == "table" and e.Story or nil, -- story rows: { Id, St, Panel, Guide }
				Unit = type(e.Unit) == "string" and e.Unit or nil, -- Kill/Golden quests: the monster kind (icon)
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

L.OnClaim = onClaim -- the quest lines (built above) claim through the list rows

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
		if r.Entry and (r.Entry.Pinned or r.Entry.Story) and L.PinnedTap then L.PinnedTap(r.Entry, r) end
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
	-- A23-40: the two quest lines always show; the parchment list (header + rows) folds out under them on PC only
	-- (phones open the overlay from the lines)
	ui.quests.Visible = #entries > 0 and not IS_TOUCH and questExpanded
	if ui.questLines then ui.questLines.Visible = #entries > 0 end
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
	-- 'now do' row: the pinned guide / next-goal row when there is one (검수 2026-10-06 (b): it always shows, phones too),
	-- else the waiting story, the first claimable, the first unfinished daily. Desktop shows one more row under it.
	local shown, second = nil, nil
	if entries[1] and entries[1].Pinned then
		shown = 1
		second = callIndex or firstClaim or firstDaily
		if second == 1 then second = nil end
	elseif callIndex then
		shown = callIndex -- B15: the collapsed list shows the story that is waiting
	else
		shown = firstClaim or firstDaily or 1
	end

	-- header: progress, claimable count (turns green so claiming stays 1-2 clicks), expand chevron
	local head = (claims >= slots) and TXT.QuestAllDone or string.format(TXT.QuestHeader, claims, slots)
	if claimable > 0 then head ..= string.format(TXT.QuestClaimable, claimable) end
	local hot = claimable > 0
	if IS_TOUCH then
		-- U5 + A23-26: line 1 = what to do now (the pinned / next-goal row first), line 2 = the waiting story (one tap
		-- opens it: the header handler), else 받기 N, else today's count; tapping opens the overlay with the rows
		local se = entries[shown]
		questState.ShownEntry = se
		local line = head
		if se then
			local p, t = questNums(se) -- CR-M27 / CR-L31
			line = se.ShowProgress and string.format(TXT.QuestTouchLine, p, t, se.Text) or se.Text
		end
		local sub = head
		if callIndex and entries[shown] ~= entries[callIndex] then
			sub = call.Label
		elseif callIndex then
			line = call.Label
		elseif hot and not (se and se.Pinned and se.CanClaim and se.Progress >= se.Target) then
			sub = string.format(TXT.QuestTouchClaim, claimable)
		end
		ui.questHeaderText.Text = line
		if ui.questHeaderSub then
			ui.questHeaderSub.Text = sub
			ui.questHeaderSub.TextColor3 = (sub ~= head) and ac("GoldText", Theme.Gold) or ac("LightSub", Theme.SubText)
		end
		ui.questChevron.Text = questState.OverlayOpen and TXT.QuestCollapse or TXT.QuestExpand
		if ui.questOverlayTitle then ui.questOverlayTitle.Text = head end
	else
		ui.questHeaderText.Text = head
		ui.questChevron.Visible = #entries > 1
		ui.questChevron.Text = questExpanded and TXT.QuestCollapse or TXT.QuestExpand
	end
	paint(ui.questHeader, hot and COL.HotTint or COL.White, hot and Theme.Good or ac("Navy", Theme.Bg))

	-- A23-40 quest lines: line 1 = the 'now do' row, line 2 = the next one (the waiting story, a claimable, a daily),
	-- else today's count with 받기 N
	if ui.qline then
		if not second and entries[shown] then
			local alt = callIndex or firstClaim or firstDaily
			if alt and alt ~= shown then second = alt end
		end
		local function lineFor(i)
			local e = i and entries[i]
			if not e then return nil, nil, nil end
			local label = (i == callIndex and call) and call.Label or e.Text
			local nums = nil
			if e.ShowProgress then
				local p, t = questNums(e) -- CR-M27 / CR-L31
				nums = string.format(TXT.QuestLineNums, p, t)
			end
			return e, label, nums
		end
		local e1, l1, n1 = lineFor(shown)
		L.SetQuestLine(ui.qline[1], e1, l1 or head, n1)
		local e2, l2, n2 = lineFor(second)
		L.SetQuestLine(ui.qline[2], e2, l2 or head, n2)
		if ui.questFold then ui.questFold.Text = questExpanded and TXT.QuestCloseList or TXT.QuestOpenList end
		questState.ShownEntry = e1
	end

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
		r.Frame.Visible = IS_TOUCH or questExpanded -- touch: every row, in the overlay; PC: the folded-out list
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
			-- a kill quest shows its monster's head (IconMon<Kind>) when that art exists, else the row type's icon
			local head = e.Unit and UIKit.ArtId("IconMon" .. e.Unit)
			r.Icon.Image = head or UIKit.ArtId(QUEST_ICON[e.Id] or "IconScroll") or UIKit.ArtId("IconSlime") or r.Icon.Image
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
	-- A23-40: the pulse sits on the quest line that shows the waiting story (phones: the whole block), else on its list row
	local callTarget = nil
	if callIndex then
		callTarget = IS_TOUCH and ui.questLines or nil
		for _, l in ui.qline or {} do
			if not IS_TOUCH and l.Entry == entries[callIndex] and l.Row.Visible then callTarget = l.Row end
		end
		if not callTarget then callTarget = callRow and callRow.Frame or nil end
	end
	L.SetStoryPulse(callTarget)
	questState.Rows = entries -- HUD.QuestTarget (QuestMarker) reads the 'now do' row
	questState.Shown = shown
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
inputAllowed = function()
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
	paint(ui.autoArt, on and COL.White or COL.DimTint, on and COL.ReleaseFill or COL.Grey)
end

-- the first mission is done (5/5) and waits for [받기]
function L.ClaimableMission(e)
	local questStep = (type(TUT.Steps) == "table" and TUT.Steps.Quest) or 2
	return type(e) == "table" and not e.Story and e.Pinned == true and e.TutorialStep == questStep and e.CanClaim == true
		and e.Progress >= e.Target
end

-- tapping the pinned guide row: step 0 guide dialogue, step 1/2 travel to the meadow, blacksmith step and the
-- iron-weapon goal -> the existing doUpgrade path, level goals -> the existing beam to the hunting ground.
-- r = the quest row that was tapped (nil from the touch header)
function L.PinnedTap(e, r)
	if throttled("pinnedTap", 0.5) then return end
	-- F10-4 (review 2026-10-06): a finished first mission (5/5) claims on a tap of its line, the same path as [받기]
	-- (ClaimQuest, ClaimAt, 1.5 s lock); the travel window and the meadow beam are only for a mission with kills left
	if L.ClaimableMission(e) then
		local row = r
		if not row then
			for _, qr in questRows do
				if qr.Entry == e then row = qr break end
			end
		end
		if row then onClaim(row) end
		return
	end
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

-- U1 menu key / the [메뉴] square (A23-40 정정): an open window closes first, else the [메뉴] squares fold out to the
-- left (or back in)
openMenu = function()
	if throttled("menu", 0.2) then return end
	local panels = C and C.Panels
	if type(panels) == "table" and type(panels.IsOpen) == "function" and type(panels.Close) == "function" then
		local ok, open = pcall(panels.IsOpen)
		if ok and open then
			L.SetFold(false)
			pcall(panels.Close, true)
			return
		end
	end
	L.SetFold(not ui.foldOpen)
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

-- A23-40 tiles: the window a tile opens right now (its own once registered, else its Alt), or nil (the tile hides)
function L.TileWindow(def)
	local panels = C and C.Panels
	local has = type(panels) == "table" and type(panels.Has) == "function" and panels.Has or nil
	if not has then return nil end
	if def.Window and has(def.Window) == true then return def.Window end
	if def.Alt and has(def.Alt) == true then return def.Alt end
	return nil
end

-- a tile press: 지도 = the world map toggle, window tiles open their window (the same tile closes it; another window
-- switches)
function L.TileTap(def)
	if def.Map then
		local wm = C and C.WorldMap
		local mapOpen = type(wm) == "table" and type(wm.IsOpen) == "function" and wm.IsOpen()
		if mapOpen or inputAllowed() then openMap() end
		return
	end
	local panels = C and C.Panels
	local target = L.TileWindow(def)
	if not target or type(panels) ~= "table" then return end
	local open = type(panels.IsOpen) == "function" and panels.IsOpen()
	if not (open or inputAllowed()) or throttled("tile", 0.25) then return end
	local ok, err
	if type(panels.CurrentId) == "function" and panels.CurrentId() == target then
		ok, err = pcall(panels.Close, true)
	else
		ok, err = pcall(panels.Open, target)
	end
	if not ok then warnThrottled("tile window failed: " .. tostring(err)) end
end

-- BB1: hold source of a key / pad button press ("key:F", "pad:ButtonR2"); the release of that same key ends the hold
-- even when the binding changed in between
function L.HoldSource(input)
	return (input.UserInputType == Enum.UserInputType.Keyboard and "key:" or "pad:") .. input.KeyCode.Name
end

-- BB1: the window keys (Keybinds group "Window") and the menu key run before inputAllowed() (a window covers the
-- screen). The same key closes its window, another window's key switches to it, a window that does not exist yet
-- (not registered in Panels) does nothing. The menu key keeps U1: it closes any open window, else opens the menu.
-- Returns true when the action was one of these keys.
function L.WindowKey(action)
	local kb, panels = C and C.Keybinds, C and C.Panels
	local target = kb and kb.WindowFor(action)
	if action ~= "Menu" and not target then return false end
	if action ~= "Menu" then L.SetFold(false) end
	if type(panels) ~= "table" then return true end
	local open = type(panels.IsOpen) == "function" and panels.IsOpen()
	if action == "Menu" then
		if open or inputAllowed() then openMenu() end
		return true
	end
	if type(panels.Has) ~= "function" or not panels.Has(target) then return true end
	if not (open or inputAllowed()) or throttled("windowKey", 0.25) then return true end
	local ok, err
	if type(panels.CurrentId) == "function" and panels.CurrentId() == target then
		ok, err = pcall(panels.Close, true)
	else
		ok, err = pcall(panels.Open, target)
	end
	if not ok then warnThrottled("window key failed: " .. tostring(err)) end
	return true
end

-- every key goes through Keybinds (BB1); nothing reacts while a key is being captured or a TextBox has focus
local function onInputBegan(input, gameProcessed)
	local kb = C and C.Keybinds
	if gameProcessed or type(kb) ~= "table" or kb.IsCapturing() or UserInputService:GetFocusedTextBox() then return end
	local action = kb.ActionFor(input)
	if not action or L.WindowKey(action) or not inputAllowed() then return end
	if action == "Attack" then
		startHold(L.HoldSource(input))
	elseif action == "SkillQ" then -- E stays the Roblox interact key (blacksmith / altar / merchant prompts)
		doRelease()
	elseif action == "Upgrade" then
		doUpgrade()
	elseif action == "Auto" then
		L.ToggleAuto()
	end -- Map: WorldMap's binding (A12); potions: VitalsUI; GhostHold: GrudgeGhost; Interact: the prompts (Keybinds)
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
	elseif t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Gamepad1 then
		stopHold(L.HoldSource(input))
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

-- places a centred (AnchorPoint 0.5) button on its rect
function L.Place(btn, r)
	if not btn or not r then return end
	btn.Size = UDim2.fromOffset(r.W, r.H)
	btn.Position = UDim2.fromOffset(r.X + r.W / 2, r.Y + r.H / 2)
end

-- A23-40 icon tiles: which tiles show (a window tile once its window exists; 지도 always), trimmed to the row's Count by
-- Keep (phones: the rest fold out of [메뉴], L.FoldEntries). Returns true when the shown set changed.
function L.PickTiles()
	if not ui.tiles then return false end
	local want = {}
	for _, t in ui.tiles do
		local def = t.Def
		if def.Map or L.TileWindow(def) then table.insert(want, t) end
	end
	local count = (L.Rects and L.Rects.tiles and L.Rects.tiles.Count) or #want
	if #want > count then
		local sorted = table.clone(want)
		table.sort(sorted, function(a, b) return a.Def.Keep < b.Def.Keep end)
		local keep = {}
		for i = 1, count do keep[sorted[i]] = true end
		local kept = {}
		for _, t in want do
			if keep[t] then table.insert(kept, t) end
		end
		want = kept
	end
	local key = ""
	for _, t in want do key ..= t.Def.Id .. "," end
	if key == ui.tileKey then return false end
	ui.tileKey = key
	ui.shownTiles = want
	local shown = {}
	for _, t in want do shown[t] = true end
	local underFold = IS_TOUCH and ui.foldOpen == true
	for _, t in ui.tiles do t.Button.Visible = shown[t] == true and not underFold end
	return true
end

-- the shown tiles on Rects.tiles: squares of Size, Gap apart; PC centred on the row (the screen centre), phones flush
-- right (under the plate)
function L.LayoutTiles(tr)
	local shown = ui.shownTiles or {}
	local n = #shown
	if n == 0 then return end
	local size, gap = tr.Size or tr.H, tr.Gap or 4
	local total = n * size + (n - 1) * gap
	local x0 = IS_TOUCH and (tr.X + tr.W - total) or (tr.X + (tr.W - total) / 2)
	for i, t in shown do
		t.Button.Size = UDim2.fromOffset(size, size)
		t.Button.Position = UDim2.fromOffset(x0 + (i - 1) * (size + gap) + size / 2, tr.Y + size / 2)
	end
end

-- A23-40: every block from HudLayout.Compute (H4 top inset, H5 live jump button, M1 UIScale, phone safe area)
applyLayout = function()
	local gui = UIKit and UIKit.Gui
	if not gui or not ui.root or not L.HL then return end
	local s = currentScale()
	local abs = gui.AbsoluteSize
	if abs.X < 10 or abs.Y < 10 then return end
	local W, H = abs.X / s, abs.Y / s
	local jump = nil
	local jb = jumpButton
	if jb and jb.Parent and jb.Visible and jb.AbsoluteSize.X > 0 then
		local rel = jb.AbsolutePosition - gui.AbsolutePosition
		jump = { X = rel.X / s, Y = rel.Y / s, W = jb.AbsoluteSize.X / s, H = jb.AbsoluteSize.Y / s }
	end
	local R = L.HL.Compute({ W = W, H = H, Scale = s, Inset = insetY(), Touch = IS_TOUCH, Jump = jump,
		Hidden = { auto = not (ui.auto and ui.auto.Visible) } })
	L.Rects = R
	L.LayoutPlate(R)
	for label in ui.textFits or {} do
		if label.Name == "KeyHint" then
			local keyH = math.max(18, math.ceil(12 / s))
			label.Size = UDim2.fromOffset(keyH, keyH)
		end
	end

	-- icon tile row (PC bottom-centre under the bars, phones top-right under the plate) and [메뉴] (PC top-right corner,
	-- phones the row's right end) with its fold-out room
	L.PickTiles()
	L.LayoutTiles(R.tiles)
	L.LayoutMenu(R)

	-- quest lines (no plate) + the fold-out list under them (PC) / the overlay beside them (phones)
	local q = R.quest
	L.LayoutQuestLines(q)
	ui.quests.Position = UDim2.fromOffset(q.X, q.Y + q.H + 4)
	ui.quests.Size = UDim2.fromOffset(q.W, 0)
	if IS_TOUCH then
		L.LayoutQuestHeader(q.W, q.H)
		-- the rows' overlay opens under the quest lines, kept on screen (CR-M25)
		if ui.questOverlay then
			ui.questOverlay.Position = UDim2.fromOffset(math.clamp(q.X, 8, math.max(8, W - L.OverlayW - 8)), q.Y + q.H + 4)
		end
	else
		ui.questRowW = q.W
		ui.questList.Size = UDim2.fromOffset(q.W, 0)
		L.LayoutQuestHeader(q.W, math.max(L.QuestHeaderH, math.ceil(20 / s)))
	end
	for _, row in questRows do L.LayoutQuestRow(row, s) end

	-- top-centre column: war meter -> chips (zone / luck / status) -> notify (EventHUD's stack, then UIKit toasts)
	local wm = R.war_meter
	ui.war.Position = UDim2.fromOffset(wm.X, wm.Y)
	ui.war.Size = UDim2.fromOffset(wm.W, wm.H)
	L.LayoutWar(wm.H)
	HUD.TopCenterX, HUD.TopCenterW = math.floor(wm.X + wm.W / 2 + 0.5), wm.W
	local ch = R.chips
	ui.chips.Position = UDim2.fromOffset(ch.X + ch.W / 2, ch.Y)
	ui.chips.Size = UDim2.fromOffset(ch.W, ch.H)
	for _, chip in ui.chip do
		chip.Frame.Size = UDim2.fromOffset(0, ch.H)
		if chip.Icon then chip.Icon.Size = UDim2.fromOffset(ch.H - 2, ch.H - 2) end
	end
	if ui.chipMore then ui.chipMore.Frame.Size = UDim2.fromOffset(0, ch.H) end
	local chipsBottom = ch.Y + math.max(ch.H, ui.chips.AbsoluteSize.Y / s)
	local nt = R.notify
	-- travel (3 s channel) rides the top of the notify column
	ui.travel.AnchorPoint = Vector2.new(0.5, 0)
	ui.travel.Position = UDim2.fromOffset(nt.X + nt.W / 2, math.max(nt.Y, chipsBottom + 4))
	ui.travel.Size = UDim2.fromOffset(math.min(340, nt.W), 58)

	-- bottom-right combat cluster (공격 · Q · 자동 · 물약; the ghost hold is GrudgeGhost on Rects.ghost)
	L.Place(ui.attack, R.attack)
	L.Place(ui.release, R.q)
	L.Place(ui.auto, R.auto)
	C.VitalsUI.PlacePotions(R.potions)
	-- combo line + milestone (Fx builds them in MainGui; it never moves them after build)
	local combo = gui:FindFirstChild("FxCombo")
	if combo and combo:IsA("GuiObject") then
		combo.Position = UDim2.fromOffset(R.combo.X + R.combo.W / 2, R.combo.Y + R.combo.H / 2)
		combo.Size = UDim2.fromOffset(R.combo.W, R.combo.H)
	end
	local milestone = gui:FindFirstChild("FxComboMilestone")
	if milestone and milestone:IsA("GuiObject") then
		milestone.Position = UDim2.fromOffset(R.combo.X + R.combo.W / 2, R.combo.Y - 9 - 32)
		milestone.Size = UDim2.fromOffset(math.min(nt.W, 420), 64)
	end

	-- CR-L37: top / left edge of the cluster (EventHUD's legacy personal line keeps above ClusterTop)
	local clusterTop, clusterLeft = math.huge, math.huge
	for _, id in { "attack", "q", "potions", "auto" } do
		local r = R[id]
		if r and (id ~= "auto" or ui.auto.Visible) then
			clusterTop = math.min(clusterTop, r.Y)
			clusterLeft = math.min(clusterLeft, r.X)
		end
	end
	HUD.Layout = {
		W = W,
		H = H,
		Scale = s,
		Rects = R,
		ChipsBottom = chipsBottom,
		ClusterTop = math.floor(clusterTop),
		ClusterLeft = math.floor(clusterLeft),
		TopCenterX = HUD.TopCenterX,
		TopCenterW = HUD.TopCenterW,
		LeftX = ch.X,
		RightX = ch.X + ch.W,
	}
	for _, name in { "EventHUD", "MiniMap" } do
		local m = C and C[name]
		if type(m) == "table" and type(m.Relayout) == "function" then pcall(m.Relayout) end
	end
	if type(UIKit.PlaceNotify) == "function" then
		local ev = C and C.EventHUD
		local top = (type(ev) == "table" and type(ev.StripBottom) == "function") and ev.StripBottom() or nil
		pcall(UIKit.PlaceNotify, nt, type(top) == "number" and math.max(top + 4, chipsBottom + 4) or chipsBottom + 4)
	end
end

-- 가방 shows once Panels has 'Bag' (BB7) and the portrait / power taps once it has 'Character' (BB8): no silent no-op
function L.RefreshWindows()
	local panels = C and C.Panels
	local has = type(panels) == "table" and type(panels.Has) == "function" and panels.Has or nil
	local character = has and has("Character") == true or false
	for _, hit in { ui.portraitHit, ui.powerRow and ui.powerRow:FindFirstChild("OpenCharacter") } do
		if hit then hit.Visible = character end
	end
	-- A23-40: a window registered later (BB7 bag, BB8 character, BB13 …) brings its tile in
	if L.PickTiles() then requestLayout() end
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
	local visible = refreshVisibility()
	if ui.foldOpen then L.FoldWatch() end
	if not visible then return end
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
		L.RefreshWindows()
		if UserInputService.TouchEnabled then
			local jb = findJumpButton()
			if jb ~= jumpButton then hookJumpButton(jb) end
		end
		applyLayout()
		refreshGuides()
	end
end

-- the HUD root shows (data loaded, no picker open): MiniMap / QuestMarker follow it
function HUD.IsVisible()
	return ui.root ~= nil and ui.root.Visible == true
end

-- the guide beam's current target (position, tag) or nil (MiniMap's quest star)
function HUD.GuideTarget()
	local g = guide
	local p = g and g.Part
	if p and p.Parent then return p.Position, g.Tag end
	return nil
end

-- A23-36: where the 'now do' quest row happens (QuestTarget.ForEntry) or nil; QuestMarker draws it
function HUD.QuestTarget()
	local qt = C and C.QuestTarget
	local rows = questState.Rows
	if type(qt) ~= "table" or type(qt.ForEntry) ~= "function" or type(rows) ~= "table" then return nil end
	local e = rows[questState.Shown or 1]
	if not e then return nil end
	local ok, target = pcall(qt.ForEntry, e, attr("ZoneId", ""), getFaction())
	return ok and target or nil
end

----------------------------------------------------------------- lifecycle
function HUD.Init(registry)
	C = registry
	UIKit = C and C.UIKit
	if type(UIKit) ~= "table" or not UIKit.Gui then
		error("UIKit is not initialized")
	end
	-- review of 27246d1: the key-badge rule comes from Keybinds (keyboard present, touch laptops included)
	local kb = C and C.Keybinds
	if type(kb) == "table" and type(kb.ShowsKeys) == "function" then
		local ok, shows = pcall(kb.ShowsKeys)
		if ok then L.KeyDevice, L.ShowKeys = shows == true, shows == true end
	end
	Theme = UIKit.Theme
	L.HL = require(script.Parent:WaitForChild("HudLayout")) -- A23-26 v2 rects (pure module, not in ClientMain ORDER)

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
	L.BuildQuestLines(ui.root)
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
	UIKit.OnAttr({ "Level", "XP", "Faction", "Class", "Honor", "Infamy", "FallMarks", "RedeemMarks", "SessionTitle", "TitleSel",
		"BankGold", "CarriedGold", "WantedStars", "Bounty" }, refreshStats)
	UIKit.OnAttr({ "Faction", "Class", "ClassChosen", "CharacterGender", "SizeMult" }, L.RefreshPortrait)
	UIKit.OnAttr({ "Level" }, function() L.Pow.LevelAt = os.clock() end) -- BB5: no "+N" next to a level-up banner
	UIKit.OnAttr({ "CombatPower", "DataLoaded", "ClassChosen" }, L.PowerChanged)
	UIKit.OnAttr({ "AutoCombatUnlocked", "AutoCombatEnabled", "ClassChosen" }, L.RefreshAuto)
	-- user 2026-10-06 (A23-26 update): TextChatService chat keeps Roblox's own place and size (top-left, opened with the
	-- top-bar chat bubble or '/'); this code no longer moves ChatWindowConfiguration. It starts closed on desktop too,
	-- so it never covers the top-left status plate until the player opens it, and the plate never has to move out of
	-- its way (review rubric 5: nothing gets pushed by motion). Touch already starts closed.
	if not IS_TOUCH then task.spawn(L.CloseChatOnce) end
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
	UIKit.OnAttr({ "Class", "ClassChosen" }, L.RefreshAttackGlyph)
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
	-- BB1: Keybinds forwards every UserInputService press / release (plus its Dispatch test inputs)
	local kb = C.Keybinds
	if type(kb) == "table" and type(kb.Began) == "table" then
		kb.Began:Connect(onInputBegan)
		kb.Ended:Connect(onInputEnded)
		kb.Changed:Connect(L.RefreshKeys)
		kb.Changed:Connect(function() -- quest rows show the new key (L.QuestText)
			if questState.Started then refreshQuests() end
		end)
	else
		UserInputService.InputBegan:Connect(onInputBegan)
		UserInputService.InputEnded:Connect(onInputEnded)
	end
	if type(C.Settings) == "table" and type(C.Settings.Changed) == "table" then C.Settings.Changed:Connect(L.RefreshKeys) end
	L.RefreshKeys()
	UserInputService.WindowFocusReleased:Connect(clearHolds)
	-- A23-38: Esc opens Roblox's menu and folds the [메뉴] squares back; so does any press outside them (L.FoldInput)
	GuiService.MenuOpened:Connect(function()
		L.SetFold(false)
	end)
	UserInputService.InputBegan:Connect(L.FoldInput)

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
