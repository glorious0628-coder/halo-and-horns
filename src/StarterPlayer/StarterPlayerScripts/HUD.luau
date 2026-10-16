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
--   meter column. HUD.QuestBlock = { X, Y, W, H } of the drawn quest tracker + 'Quests (n)' head line (a new table when
--   it moves, nil while hidden; QuestMarker avoids it).
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
HUD.QuestsChanged = Util.Signal.new() -- A23-81: fired after every quest list redraw (QuestBook listens)

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
	-- A23-40 icon tile row, left to right (검수 10/10, A23-113 ③: in the order they open - 가방 · 지도 first, then 영웅 (Lv 2) ·
	-- 스킬 (Lv 5) · 펫 · 순위, so an opened tile never moves).
	-- Window = the Panels window the tile opens (the tile shows once it is registered; Alt = an older window it opens
	-- until then), Map = the world map; Key = Keybinds action for the key badge; Keep = shown first when the row has
	-- fewer slots than tiles (phones: the rest fold out of [메뉴], in front of its own squares)
	Tiles = {
		{ Id = "Bag", Icon = "IconBag", Window = "Bag", Alt = "Items", Key = "Bag", Keep = 1 },
		{ Id = "Map", Icon = "GlyphMap", Map = true, Key = "Map", Keep = 1 },
		{ Id = "Character", Icon = "IconCharacter", Window = "Character", Key = "Character", Keep = 2 },
		{ Id = "Skills", Icon = "IconSkills", Window = "Skills", Key = "Skills", Keep = 4 },
		{ Id = "Pet", Icon = "IconPetBabySlime", Window = "Pet", Keep = 5 },
		{ Id = "Ranking", Icon = "IconRanking", Window = "Ranking", Key = "Ranking", Keep = 6 },
		-- A23-153 the Monster Codex (CodexUI.luau window "Codex"): open from the start - its silhouettes are the goal
		-- (the approved slime icon until a codex icon is drawn)
		{ Id = "Codex", Icon = "IconMonSlime", Window = "Codex", Keep = 7 },
	},
	-- A23-40 정정 (user 2026-10-06 "메뉴는 오른쪽 위에, 누르면 옆으로 좌르륵"; 검수: 새 소식 · 이동 · 도움말 · 설정): the
	-- squares [메뉴] folds out to its left, left to right. 직업 바꾸기 · 환생 · 오프닝 다시 보기 · 이름 숨기기 · 휴가 are
	-- 설정 rows and 닉네임 a 내 캐릭터 row (BB13); until 설정 is registered its square opens the old 메뉴 window (Alt),
	-- which still lists them. A square shows once its window is registered (no silent no-op)
	-- A23-75 (2026-10-08): the Robux shop (ShopUI) is the first square, left of 새 소식 (IconCoin until its icon is drawn)
	Fold = {
		{ Id = "Shop", Icon = "IconCoin", Window = "Shop" },
		-- A23-79 #3: [Invite a friend] while Invite.CanShow() (no KO, no failed scroll just now, not in the Shop)
		{ Id = "Invite", Icon = "IconInviteFriend", Invite = true },
		-- plan 10/13 §1-A #5: the attendance board (AttendanceUI.luau window "Attendance"; the approved weekly-box art)
		{ Id = "Attendance", Icon = "IconWeeklyBox", Window = "Attendance" },
		{ Id = "News", Icon = "IconNews", Window = "News" },
		-- A23-79: the King Diary (KingDiary.luau window "Diary"; the square shows once it is registered)
		{ Id = "Diary", Icon = "IconDiary", Window = "Diary" },
		{ Id = "Travel", Icon = "IconTravel", Window = "Travel" },
		{ Id = "Help", Icon = "IconHelp", Window = "Help", Key = "Help" },
		{ Id = "Settings", Icon = "IconSettings", Window = "Settings", Alt = "Menu" },
	},
	FoldTime = 0.2, -- s: the squares slide out of [메뉴] to the left (A23-38: 0.15-0.25 s), FoldStep apart
	FoldStep = 0.03, -- 검수 2026-10-06: one square after another, 0.03 s apart
	FoldBack = 0.15, -- s: folding back in
	FoldPad = 10, -- du above / below the squares inside the clipping frame (key badges, the glow)
	TileIcon = 0.6, -- icon side / tile side (the name sits under it inside the tile)
	BandAlpha = 0.6, -- the soft band's transparency where it is darkest (review 2026-10-06: 0.6-0.7)
	TileTint = 0.15, -- MenuTile ImageTransparency over the world (sheet a2338)
}

-- code-drawn fallback colours (IMG-R4) and ImageColor3 multipliers for the art parts
local COL = {
	BandInk = Color3.fromRGB(10, 14, 30), -- the soft dark band behind plate-less text (L.SoftBand)
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
-- kill rows use their monster head (IconMon<Unit>) when it exists; these are the fallbacks per row type. 28c6324 (High):
-- the golden monster, Halo's Hunt (Catch Wanted) and Horns' Plunder (Rob Knights) rows; gold = coin, skill hits = Skills
local QUEST_ICON = { tutorial = "IconMonSlime", Kill = "GlyphQuest", Golden = "IconGoldenMon", Goose = "IconGoose",
	Gold = "IconCoin", Release = "IconSkills", Hunt = "IconHunt", Plunder = "IconPlunder" }

local GUIDE_SECONDS = NEXT.GuideSeconds or 90
local GUIDE_ZONES = NEXT.GuideZones or { "GoblinWoods", "SkeletonRuins" }
local TUT_GUIDE_STEP = (type(TUT.Steps) == "table" and TUT.Steps.Guide) or 1
local TUT_GUIDE_ZONE = TUT.GuideZone or "SlimeMeadow"
local TUT_GUIDE_TEXT = TUT.GuideText or "This way!"
local TUT_QUEST_ID = TUT.QuestId or "tutorial"

-- HUD display strings (the literals of TECH_SPEC §4.23 HUD; game messages come from Config.Text)
-- A23-48 (user 2026-10-06: the game screen is English only): every HUD text, simple English, names from
-- docs/design/glossary_en_2026-10-06.md
local TXT = Config.ClientText.HUD -- the words: Config.ClientText.HUD (moved 10/14)

-- 최종 검수 10/14 (A23-179: Roblox's automatic translation matches whole drawn sentences, so a line with a number or a
-- name stayed English): a sentence with %-slots by its table key - UIKit.Tx -> UIKit.Tr (the localization table by key,
-- "HUD.TXT.<key>" / "Config...."; English exactly as before). Without UIKit (offline tests) or on an error: string.format;
-- a format that fails gives the words as they are (never nil)
function L.Tx(t, key, ...)
	local f = type(t) == "table" and t[key] or nil
	if type(f) ~= "string" then return "" end
	if type(UIKit) == "table" and type(UIKit.Tx) == "function" then
		local ok, out = pcall(UIKit.Tx, t, key, ...)
		if ok and type(out) == "string" then return out end
	end
	local ok, out = pcall(string.format, f, ...)
	return ok and out or f
end

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
local guide = nil -- { Tag, Part, From }
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
-- minPixels: the smallest real px the fit may pick (default 11). keepPx: the floor and ceiling stay real px on small PC
-- windows too (2026-10-08, main Studio 991x451 at UIScale 0.5: the HP / MP numbers shrank to ~6 px)
function L.FitText(label, pixels, bold, minPixels, keepPx)
	if not label then return label end
	ui.textFits = ui.textFits or setmetatable({}, { __mode = "k" })
	local fit = ui.textFits[label]
	if not fit then
		fit = { Truncate = label.TextTruncate, Connections = {} }
		ui.textFits[label] = fit
		fit.Apply = function()
			if not label.Parent then return end
			local s = currentScale()
			-- small PC windows: the real-px floor and ceiling shrink with the scale (UIKit.PxFloor, review 2026-10-07)
			local pf = (not fit.KeepPx and type(UIKit.PxFloor) == "function") and UIKit.PxFloor() or 1
			local mp = (fit.MinPixels or 11) * pf
			local minSize = fit.KeepPx and math.max(1, math.ceil(mp / s)) or math.max(1, math.min(mp, math.floor(mp / s)))
			local maxSize = math.max(minSize, math.floor(fit.Pixels * pf / s))
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
	fit.MinPixels = minPixels
	fit.KeepPx = keepPx == true
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
-- 검수 10/09 (main PC: the story line's words outside an empty wide plate): never inside a list / grid - the glow frame
-- would be one more list item and push the row's icon and words aside. Such a parent gets no glow (the caller passes
-- the line's plate instead)
local function makeGlow(parent, radius)
	if typeof(parent) ~= "Instance" or parent:FindFirstChildWhichIsA("UIGridStyleLayout") then return nil end
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

-- the shared press feel (UIKit.ButtonFeel / FeelPress, 검수 2026-10-06): keys and holds press the same way as a finger
local function pressScale(btn, down)
	if btn and type(UIKit.FeelPress) == "function" then UIKit.FeelPress(btn, down) end
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
L.PowerTap = 44 -- touch: the power line's tap area is at least this many real px tall (a finger)
-- A23-68 #3 (user 2026-10-07: "슬라임 5대 > 2대 이런 거는 됐고 그냥 전투력이 올라야지"): the first weapon (WeaponTier
-- 0 -> 1+, the M1_1 blacksmith's gift) gets one big moment: gold sparkles on me, the PowerUp sound, a big "Stronger!"
-- banner and a slow count-up of the Power number. Seen live only (a save loading with a weapon shows nothing).
L.First = { Tier = nil, Pop = false, Count = 1.6, Banner = 2.4, Wait = 1.2, Sparks = 36 }

function L.PowerValue()
	local v = tonumber(attr("CombatPower", nil))
	if v then return math.floor(v) end
	local lv = math.floor(num("Level", 1))
	local tier = math.clamp(math.floor(num("WeaponTier", 0)), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands
	return Config.CombatPower(lv, tier, num("WeaponEnhance", 0)) -- before the server's first set
end

function L.PowerText(n)
	local lv = L.LvShown() or math.floor(num("Level", 1))
	if L.Pow.Short then return L.Tx(TXT, "PowerLineShort", lv, Util.FormatInt(n)) end
	return L.Tx(TXT, "PowerLine", lv, TXT.PowerWord, Util.FormatInt(n))
end

function L.PowerOpen()
	-- 게임성 검수 10/12: the face / power line obeys the Hero tile's lock (before Lv 2 it only wiggles the tile)
	if L.TileLocked("Character") then
		L.TileWiggle("Character")
		return
	end
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
			-- 10/16 phone dump: the 16 px floor text in the 12 px row read 'cut'; the label's box now follows the text
			-- both ways (the row's UIListLayout centres it, so the drawn line stays where it was)
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(0, 0, 0, 0),
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
	-- 개발 1 10/14 (Korean client: '· Pouch 0' cut, words English): both lines come translated from L.Tx (UIKit.Tr, the
	-- words inside too); Roblox's own pass stays off so the box measures exactly what is drawn
	UIKit.NoTranslate(ui.power)
	UIKit.NoTranslate(ui.pouch)
	-- A23-35 / A23-40: no plate under the line (PC: over the ground) -> the dark text style's navy rim; gold stays gold
	-- (the white -> cream gradient multiplies the colour)
	if type(UIKit.StyleText) == "function" then
		UIKit.StyleText(ui.power, "Number")
		UIKit.StyleText(ui.pouch, "Number")
		ui.power.TextColor3 = ac("GoldText", Theme.Gold)
	end
	-- A23-160 ③ (phone first 10 minutes, 10/13): the tap area is the row's SIBLING, not its child - inside the row the
	-- UIListLayout laid the full-size button out as the first word and pushed 'Lv 1 · Power 0' past the row's right end
	-- (PC: right of the bars; phones: into the potion ring). L.LayoutPlate places it over the row (touch: down to the XP
	-- bar and >= L.PowerTap real px tall)
	ui.powerHit = L.PowerHit(parent)
	ui.powerHit.ZIndex = ui.powerRow.ZIndex + 2
	ui.powerHit.Size = UDim2.new() -- (API review 10/13) never the whole screen before the first L.LayoutPlate
	ui.power:GetPropertyChangedSignal("AbsoluteSize"):Connect(L.CheckPouch)
	ui.pouch:GetPropertyChangedSignal("AbsoluteSize"):Connect(L.CheckPouch)
end

-- the pouch rides the power line while both fit its rect (2du spare against flicker), else it hides. When the power
-- text alone runs past the row (the narrowest phone rows, 2026-10-07) the word 'Power' goes first ('Lv 25 · 249'); it
-- comes back once the row is wider than the full line's last measured width
function L.CheckPouch()
	local R = L.Rects
	if not R or not ui.power or not ui.pouch or not ui.powerRow then return end
	local s = currentScale()
	local P = L.Pow
	local pw = ui.power.AbsoluteSize.X / s
	if not P.Short and pw > R.power_line.W + 0.5 then
		P.Short, P.FullW = true, pw
		ui.power.Text = L.PowerText(P.Shown or L.PowerValue())
	elseif P.Short and P.FullW and P.FullW <= R.power_line.W - 2 then
		P.Short = false
		ui.power.Text = L.PowerText(P.Shown or L.PowerValue())
	end
	local gap = ui.powerRow.List.Padding.Offset
	local need = (ui.power.AbsoluteSize.X + ui.pouch.AbsoluteSize.X) / s + gap
	local fits = L.PouchOn == true and need <= R.power_line.W - (ui.pouch.Visible and 0 or 2)
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
	local count = L.Pow.Count
	if L.First.Pop then -- the first weapon: the big moment + a slower count-up
		L.First.Pop = false
		L.FirstWeapon()
		count = L.First.Count
	end
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
			local k = math.clamp((os.clock() - t0) / count, 0, 1)
			L.PowerSet(math.floor(from + (to - from) * k + 0.5))
			if k >= 1 then break end
			task.wait(1 / 30)
		end
	end)
end

-- 최종 검수 10/15 (feedback_audit #2, one moment; server Fx LevelUp From / PowerFrom / PowerTo): my level-up on the
-- HUD at the same moment as Fx's ring and stars - the level badge pops (bigger, then back with a little overshoot) and
-- the power number counts up with its "+N" (the settle after it stays quiet: no second "+N")
L.LevelPop = { Up = 1.6, In = 0.15, Out = 0.35, Step = 0.16, HoldMax = 20 }

-- A23-221 ③: while Fx holds my level-ups (a fight) the badge and the power line keep the level from before (Lv.Hold,
-- never longer than HoldMax s); LevelCount then ticks the badge From -> To, one short tick sound per level
L.Lv = { Hold = nil, At = 0, Seq = 0 }
function L.LvShown()
	local H = L.Lv
	if H.Hold == nil or os.clock() - H.At > L.LevelPop.HoldMax then return nil end
	return H.Hold
end

function HUD.LevelHold(from)
	from = tonumber(from)
	if not from then return end
	L.Lv.Hold, L.Lv.At = math.floor(from), os.clock()
	L.Lv.Seq += 1
	if ui.level then ui.level.Text = tostring(L.Lv.Hold) end
end

function HUD.LevelCount(from, to)
	from, to = math.floor(tonumber(from) or 0), math.floor(tonumber(to) or 0)
	L.Lv.Seq += 1
	local seq = L.Lv.Seq
	local function done()
		L.Lv.Hold = nil
		if ui.level then ui.level.Text = tostring(math.floor(num("Level", 1))) end
		if ui.power then ui.power.Text = L.PowerText(L.Pow.Shown or L.PowerValue()) end
	end
	if to - from <= 1 or UIKit.ReducedMotion() then
		done()
		return
	end
	task.spawn(function()
		for v = from + 1, to do
			if L.Lv.Seq ~= seq then return end
			L.Lv.Hold, L.Lv.At = v, os.clock()
			if ui.level then ui.level.Text = tostring(v) end
			if C and type(C.Audio) == "table" and type(C.Audio.Play) == "function" then pcall(C.Audio.Play, "CountTick") end
			task.wait(L.LevelPop.Step)
		end
		if L.Lv.Seq == seq then done() end
	end)
end

-- A23-221 ⑦: the '2x XP · N min' chip shines once, at the first XP of the session in the first minutes (a small pop +
-- a brighter rim for a moment; no words, no banner); it goes quietly when the minutes end (L.RefreshBoost)
function HUD.PulseBoost()
	if L.BoostPulsed or L.EarlyXPLeft() == nil then return false end
	local chip = ui.chip and ui.chip.Boost
	if not (chip and chip.Frame and chip.Frame.Visible) then return false end
	L.BoostPulsed = true
	if UIKit.ReducedMotion() then return true end
	local f = chip.Frame
	local sc = f:FindFirstChild("BoostPop") or Instance.new("UIScale")
	sc.Name, sc.Scale, sc.Parent = "BoostPop", 1, f
	local up = TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.18 })
	up.Completed:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	up:Play()
	if chip.Stroke then
		local th = chip.Stroke.Thickness
		chip.Stroke.Thickness = th + 2.5
		TweenService:Create(chip.Stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Thickness = th }):Play()
	end
	return true
end
function HUD.LevelUpMoment(d)
	if type(d) ~= "table" then return end
	local holder = ui.badgeHolder
	local reduced = type(UIKit.ReducedMotion) == "function" and UIKit.ReducedMotion()
	if holder and not reduced then
		local sc = holder:FindFirstChild("LevelPop")
		if not sc then
			sc = Instance.new("UIScale")
			sc.Name = "LevelPop"
			sc.Parent = holder
		end
		sc.Scale = 1
		local up = TweenService:Create(sc, TweenInfo.new(L.LevelPop.In, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = L.LevelPop.Up })
		up.Completed:Connect(function()
			TweenService:Create(sc, TweenInfo.new(L.LevelPop.Out, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
		up:Play()
	end
	local from, to = tonumber(d.PowerFrom), tonumber(d.PowerTo)
	if from and to and to > from then
		L.Pow.Base, L.Pow.LevelAt = to, os.clock()
		L.PowerPopup(L.Pow.Shown or from, to, to - from)
	end
	return true
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

-- WeaponTier 0 -> 1+ after the save loaded and the class was picked = the first weapon. The power popup that follows
-- (CombatPower rises in the same moment) shows the big moment; if no rise comes within First.Wait s it shows anyway.
function L.TierChanged()
	local F = L.First
	local tier = math.floor(num("WeaponTier", 0))
	if attr("DataLoaded", false) ~= true or attr("ClassChosen", false) ~= true then
		F.Tier = nil -- not live yet (the save is loading / no class): no moment
		return
	end
	if F.Tier == nil then F.Tier = tier return end -- the first live reading is the baseline
	if F.Tier <= 0 and tier >= 1 then
		F.Pop = true
		task.delay(F.Wait + L.Pow.Merge, function()
			if F.Pop then
				F.Pop = false
				L.FirstWeapon()
			end
		end)
	end
	F.Tier = tier
end

function L.FirstWeapon()
	local F = L.First
	if C and type(C.Audio) == "table" and type(C.Audio.Play) == "function" then pcall(C.Audio.Play, "PowerUp") end
	-- A23-221 ③: the new weapon rises over my head for a moment (Fx.HoldUp: a round glow, my cheer out of a fight)
	pcall(function()
		local key = Config.WeaponArtKey(num("WeaponTier", 1), attr("Class", nil), getFaction())
		if key and C and type(C.Fx) == "table" and type(C.Fx.HoldUp) == "function" then C.Fx.HoldUp(key) end
	end)
	-- A23-191: no "Stronger!" banner (the sparkles + the power count-up say it)
	-- gold sparkles bursting from me (Roblox's own sparkle texture; no new art)
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local att = Instance.new("Attachment")
		att.Name = "FirstWeaponSparks"
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 190, 60))
		e.LightEmission, e.Rate, e.SpreadAngle = 0.7, 0, Vector2.new(180, 180)
		e.Lifetime, e.Speed = NumberRange.new(0.6, 1.1), NumberRange.new(6, 12)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		e.Acceleration = Vector3.new(0, 6, 0)
		e.Parent = att
		att.Parent = root
		e:Emit(F.Sparks)
		task.delay(1.6, function() att:Destroy() end)
	end
	-- the Power number grows for a moment (no bounce with 'Screen shake' off)
	local label = ui.power
	local reduced = type(UIKit.ReducedMotion) == "function" and UIKit.ReducedMotion()
	if label and label.Parent and not reduced then
		local scale = label:FindFirstChild("FirstWeaponScale") or Instance.new("UIScale")
		scale.Name = "FirstWeaponScale"
		scale.Scale = 1
		scale.Parent = label
		local up = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.35 })
		up:Play()
		task.delay(F.Count, function()
			if scale.Parent then TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 1 }):Play() end
		end)
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
	-- the icon row re-centres when the potions first show / hide (L.LayoutTiles, Config.HudReveal)
	if ui.potions then
		ui.potions:GetPropertyChangedSignal("Visible"):Connect(function()
			if L.Rects and L.Rects.tiles then L.LayoutTiles(L.Rects.tiles) end
		end)
	end
	if not IS_TOUCH then L.BuildQuick(root) end
end

-- A23-109 (user 10/10 "1·2·3은 가로로"): PC quick slots 1 · 2 · 3 right of the icon tiles (HudLayout quick row). Slots 1
-- and 2 are VitalsUI's square potion slots (HP, MP) until 개발 1's quick slots take items; slot 3 starts empty. Every
-- slot: Icon, Count, Key ('1' / '2' / '3' top-left), Cooldown (fills up from the bottom), Status, the slot number as
-- attribute QuickSlot. HUD.QuickSlots() lists them; after HUD.OnQuickSlot(fn) every slot's click calls only fn(i) and
-- VitalsUI stops filling slots 1 / 2 (개발 1's QuickSlots.luau fills icons, counts, keys and cooldowns)
function L.BuildQuick(root)
	local btn = UIKit.ArtButton("MenuTile", {
		Name = "QuickSlot3",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(52, 52),
		ImageTransparency = L.TileTint,
		Parent = root,
	}, function()
		if L.QuickHandler then task.spawn(L.QuickHandler, 3) end
	end, { CornerRadius = UDim.new(0, 8), BackgroundTransparency = 0.25 })
	btn:SetAttribute("QuickSlot", 3)
	UIKit.Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = "", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.66, 0.66), ZIndex = 3, Parent = btn })
	local count = UIKit.LightText({ Name = "Count", Parent = btn, Text = "", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.82, 0.77), Size = UDim2.fromScale(0.5, 0.38), TextScaled = true, Number = true, AutoLocalize = false,
		MaxTextSize = 16, ZIndex = 5 })
	L.FitText(count, 14, true, 11, true)
	local key = UIKit.LightText({ Name = "Key", Parent = btn, Text = "3", TextSize = 11, ZIndex = 6,
		AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0.06, 0.04), Size = UDim2.fromOffset(15, 15),
		AutomaticSize = Enum.AutomaticSize.X })
	L.FitText(key, L.QuickKeyPx + 1, true, L.QuickKeyPx, true)
	C.VitalsUI.QuickCooldown(btn)
	UIKit.LightText({ Name = "Status", Parent = btn, Text = "", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.3), TextScaled = true, Title = true,
		MaxTextSize = 14, ZIndex = 6, Visible = false })
	ui.quick3 = btn
end

function HUD.QuickSlots()
	local out = {}
	for i, b in { ui.potions and ui.potions:FindFirstChild("HPPotion"), ui.potions and ui.potions:FindFirstChild("MPPotion"),
		ui.quick3 } do
		if b then
			out[i] = { Button = b, Icon = b:FindFirstChild("Icon"), Count = b:FindFirstChild("Count"), Key = b:FindFirstChild("Key"),
				Status = b:FindFirstChild("Status"), Cooldown = b:FindFirstChild("Cooldown") }
		end
	end
	return out
end

-- once fn is set every slot (1 and 2 too, VitalsUI) calls only fn(i); VitalsUI stops filling slots 1 / 2
function HUD.OnQuickSlot(fn)
	L.QuickHandler = type(fn) == "function" and fn or nil
end

function HUD.QuickHandler()
	return L.QuickHandler
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
		Number = true, AutoLocalize = false,
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
	if ui.powerHit then
		-- touch: from the power line down over the (not pressable) HP / MP / XP bars, grown upwards to a finger's height
		local top, bottom = pl.Y, pl.Y + pl.H
		if IS_TOUCH then
			bottom = math.max(bottom, xp.Y + xp.H)
			top = math.min(top, bottom - L.PowerTap / currentScale())
		end
		ui.powerHit.Position = UDim2.fromOffset(pl.X, top)
		ui.powerHit.Size = UDim2.fromOffset(pl.W, bottom - top)
	end
	L.CheckPouch()
end

----------------------------------------------------------------- building: war meter (top center)

-- a soft dark band behind plate-less text over the world (review 2026-10-06: the quest lines / the war line got lost over
-- bright ground and sky): BandInk at L.BandAlpha where darkest, fading out. side = "Right" (text starts at the left,
-- the band fades to the right like the reference game's quest text) or "Center" (fades both ways). ZIndex under the text
function L.SoftBand(parent, side)
	local a = L.BandAlpha
	local seq = side == "Center"
			and NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, a),
				NumberSequenceKeypoint.new(0.8, a), NumberSequenceKeypoint.new(1, 1) })
		or NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.55, a + 0.05),
			NumberSequenceKeypoint.new(1, 1) })
	return UIKit.Create("Frame", {
		Name = "Band",
		BackgroundColor3 = COL.BandInk,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(side == "Center" and -24 or -8, -2),
		Size = UDim2.new(1, side == "Center" and 48 or 64, 1, 4),
		ZIndex = 1,
		Parent = parent,
	}, {
		corner(UDim.new(0, 8)),
		UIKit.Create("UIGradient", { Transparency = seq }),
	})
end

-- gold 빛 fill from the left and crimson 뿔 fill from the right inside the BarTrack capsule, the faction badges (bundle 6)
-- over both ends, the crown riding the split, info pills under it. applyLayout sizes it from Rects.war_meter (L.LayoutWar).
-- 검수 2026-10-08: on a navy plate like a game's top bar, the badges big with the scores inside them (L.WarTop)
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
	local TB = L.WarTop
	local barY, barH = 8, 22
	-- the plate under everything (missing art: a navy rounded panel, the same idea)
	local plate, plateArt = UIKit.ArtFrame("PanelCard", {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1), -- L.LayoutWar: around the track only
		SliceScale = TB.PlateSlice,
		ZIndex = 0,
		Parent = w,
	}, { Color = ac("Navy", Theme.Bg), BackgroundTransparency = 0.1, CornerRadius = UDim.new(0, 14) })
	ui.warPlate, ui.warPlateArt = plate, plateArt
	-- Bar / Info follow the meter's width; L.LayoutWar fits them to its height
	local bar, barArt = UIKit.ArtFrame("BarTrack", {
		Name = "Bar",
		Position = UDim2.fromOffset(48, barY), -- L.LayoutWar places it
		Size = UDim2.new(1, -96, 0, barH),
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
		L.WarInnerSide = def.Inner.Min.X / def.Size.Y -- the capsule's end caps follow the track's height (L.LayoutWar)
		side = math.floor(L.WarInnerSide * barH + 0.5)
	end
	L.WarInnerTop = top -- the fills' inset from the track's top (a share of its height): the crown floats over it
	local inner = UIKit.Create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, side, top, 0),
		Size = UDim2.new(1, -2 * side, 1 - top - bottom, 0),
		Parent = bar,
	})
	ui.warInner = inner
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
	-- crown over the split (WarCrownPip, 그림체 #15). 최종 검수 10/14 상단 HUD 1안 ①: it floats ABOVE the track (its
	-- image rect L.WarTop.CrownGap clear of it), its x following the split (L.WarCrownFrac keeps it over the track)
	ui.warCrown = UIKit.ArtImage("WarCrownPip", {
		Name = "Crown",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(TB.Crown, TB.Crown), -- L.LayoutWar sizes it (px / UIScale)
		ZIndex = 3,
		Parent = inner,
	})
	-- the faction badges big over both ends; each side's score sits in its badge's centre (the part's Inner rect: dark
	-- words on Halo's ivory, light ones on Horns' plum). Missing badge art: the old "Halo 14" / "14 Horns" in the bar ends
	L.WarNumOnly = true
	for _, s in { { "LevelBadgeHalo", 0, "ShieldHalo", "haloNum", true }, { "LevelBadgeHorns", 1, "ShieldHorns", "hornsNum", false } } do
		local badge = UIKit.ArtImage(s[1], {
			Name = s[3],
			AnchorPoint = Vector2.new(s[2], 0.5),
			Position = UDim2.new(s[2], 0, 0, barY + barH / 2), -- L.LayoutWar: inside the ends
			Size = UDim2.fromOffset(TB.Badge, TB.Badge),
			ZIndex = 3,
			Parent = w,
		})
		ui[s[2] == 0 and "warBadgeHalo" or "warBadgeHorns"] = badge
		local def = badge and UIKit.ArtPart(s[1]) or nil
		local inner = def and typeof(def.Inner) == "Rect" and typeof(def.Size) == "Vector2" and def.Inner or nil
		if inner then
			ui[s[4]] = artLabel(s[5], {
				Name = s[2] == 0 and "HaloScore" or "HornsScore",
				Position = UDim2.fromScale(inner.Min.X / def.Size.X, inner.Min.Y / def.Size.Y),
				Size = UDim2.fromScale(inner.Width / def.Size.X, inner.Height / def.Size.Y),
				TextScaled = true,
				MaxTextSize = 22,
				Number = true, AutoLocalize = false,
				ZIndex = 4,
				Parent = badge,
			})
			-- 검수 10/10 (UiSandbox: the score was 11 px at 1280x720, 7 px at 991x451): real px ScoreMinPx..ScoreMaxPx
			L.FitText(ui[s[4]], TB.ScoreMaxPx, true, TB.ScoreMinPx, true)
		else
			L.WarNumOnly = false
			ui[s[4]] = artLabel(false, {
				Name = s[2] == 0 and "HaloScore" or "HornsScore",
				AnchorPoint = Vector2.new(s[2], 0),
				Position = UDim2.new(s[2], s[2] == 0 and 16 or -16, 0, 0),
				Size = UDim2.new(0.5, -20, 1, 0),
				TextSize = 15,
				Number = true, AutoLocalize = false,
				TextXAlignment = s[2] == 0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
				ZIndex = 2,
				Parent = bar,
			})
		end
	end
	ui.warBar = bar

	-- A23-130 / A23-184 (user 10/14: "막대 아래에 글 넣지 말라", then "저 9:25 뭐냐고!"): NO words and NO numbers on or
	-- under the bar but the two badge scores - the bar is the crown, the two scores and the gold / red fills. The round's
	-- time lives in the quest window's Event tab ("Crown War: next crown in 8:54"): a press on the bar opens it
	local open = UIKit.Create("TextButton", {
		Name = "Open",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = w,
	})
	open.Activated:Connect(function() pcall(L.OpenWarInfo) end)
end

-- A23-184 / 상단 HUD 1안 ①: a press on the bar opens the small war window (L.RegisterWarInfo: the round's time and
-- both scores); without it the quest window's Event tab ("Crown War: next crown in …")
function L.OpenWarInfo()
	if L.WarInfoOn and C.Panels and type(C.Panels.Open) == "function" then
		C.Panels.Open(L.WarInfoId)
		return
	end
	if not L.HasQuestBook() then return end
	C.QuestBook.Toggle(true)
	if type(C.QuestBook.ShowTab) == "function" then C.QuestBook.ShowTab(L.WarInfoTab) end
end
L.WarInfoTab, L.WarInfoId = "Event", "WarInfo"

-- (pure) 최종 검수 10/14 상단 HUD 1안 ① (Codex build/codex/hud_top_design.md): the war meter's pieces in du inside its
-- frame (w x h du, UIScale s; the sizes in L.WarTop are REAL px like Roblox's top bar, so / s), top to bottom: the crown
-- (Crown px, from Lift px over the frame's top), CrownGap px of air, the track (TrackH px) between the two badges (Badge
-- px, inside the frame's ends, centred on the track; the track BadgeGap px from them); the plate around the track only
-- (PlatePad px over / under it, never past the badges' bottom). -> { Crown = {Y, S}, Track = {X, Y, W, H}, Badge = {S, CY},
-- Plate = {Y, H}, Bottom = the lowest drawn du (the badges) }
function HUD.WarGeometry(w, h, s, touch)
	local TB = L.WarTop
	s = (type(s) == "number" and s > 0) and s or 1
	local function px(key) return (touch and TB[key .. "Touch"] or TB[key]) / s end
	local crown, badge, trackH = px("Crown"), px("Badge"), px("TrackH")
	local crownY = -px("Lift")
	local trackY = crownY + crown + px("CrownGap")
	local cy = trackY + trackH / 2
	local trackX = badge + px("BadgeGap")
	local pad = px("PlatePad")
	local plateY = trackY - pad
	local plateH = math.min(trackH + 2 * pad, cy + badge / 2 - plateY)
	return { Crown = { Y = crownY, S = crown }, Track = { X = trackX, Y = trackY, W = math.max(0, w - 2 * trackX), H = trackH },
		Badge = { S = badge, CY = cy }, Plate = { Y = plateY, H = plateH }, Bottom = cy + badge / 2, H = h }
end

-- the meter's pieces from HUD.WarGeometry (applyLayout: Rects.war_meter; the frame's width from it too)
function L.LayoutWar(h)
	L.WarH = h
	local wf = ui.war and ui.war.Size.X.Offset or 360
	local g = HUD.WarGeometry(wf, h, currentScale(), IS_TOUCH)
	L.WarGeo = g
	local t = g.Track
	if ui.warBar then
		ui.warBar.Position = UDim2.fromOffset(t.X, t.Y)
		ui.warBar.Size = UDim2.new(1, -2 * t.X, 0, t.H)
	end
	for i, b in { ui.warBadgeHalo, ui.warBadgeHorns } do
		if b then
			b.AnchorPoint = Vector2.new(i == 1 and 0 or 1, 0.5)
			b.Size = UDim2.fromOffset(g.Badge.S, g.Badge.S)
			b.Position = UDim2.new(i == 1 and 0 or 1, 0, 0, g.Badge.CY)
		end
	end
	if ui.warInner and L.WarInnerSide then
		local side = math.floor(L.WarInnerSide * t.H + 0.5)
		ui.warInner.Position = UDim2.new(0, side, ui.warInner.Position.Y.Scale, 0)
		ui.warInner.Size = UDim2.new(1, -2 * side, ui.warInner.Size.Y.Scale, 0)
	end
	if ui.warCrown then ui.warCrown.Size = UDim2.fromOffset(g.Crown.S, g.Crown.S) end
	if ui.warPlate then
		ui.warPlate.Position = UDim2.fromOffset(0, g.Plate.Y)
		ui.warPlate.Size = UDim2.new(1, 0, 0, g.Plate.H)
	end
	L.PlaceWarCrown()
end

-- the crown's bottom CrownGap over the track (inside the Inner frame, whose top sits L.WarInnerTop of the track down)
function L.PlaceWarCrown()
	local g, crown = L.WarGeo, ui.warCrown
	if not (g and crown) then return end
	local up = (g.Track.Y - (g.Crown.Y + g.Crown.S)) + (L.WarInnerTop or 0) * g.Track.H
	local pos = UDim2.new(L.WarCrownX or 0.5, 0, 0, -up)
	if crown.Position ~= pos then crown.Position = pos end
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
		Wraps = true, -- 상단 HUD 1안 ②: a second row only when the danger names need it (L.CheckChipFit drops the rest first)
		Parent = ui.chips,
	})
	ui.chips.AutomaticSize = Enum.AutomaticSize.Y
	ui.chipList = chipList
	chipList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() L.CheckChipFit() end)
	ui.chips:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() L.CheckChipFit() end)
	ui.chipPal = {
		Safe = { ac("ChipSafe", Theme.Good), ac("ChipSafeRim", Theme.Good), ac("ChipSafeText", COL.Dark) },
		Rookie = { ac("ChipRookie", Theme.XP), ac("ChipRookieRim", Theme.XP), ac("ChipRookieText", COL.Dark) },
	}
	-- A23-26 order: zone -> luck -> danger (bully, wanted, combat) -> rookie / protected -> blessing, size, kaiju queue.
	-- A23-192 (user 10/14): every chip shows with its words; a full row wraps (no '+N')
	local icons = { Blessing = "WarCrownPip", Zone = "IconSafe", Rookie = "IconSprout", Luck = "IconClover", Wanted = "Star",
		Boost = "IconExp", Private = "IconPrivateServer", Outlaw = "IconLock" } -- Outlaw: Auto Battle locked (IconLock)
	L.ChipIcons = icons
	ui.chip = {}
	-- A23-75: the 2x pass chip right after the danger chips (UiSandbox 2026-10-08: after the shields it always folded into
	-- '+N' in town, so a buyer never saw it). 최종 검수 10/14 (publish4 photos: the Outlaw chip hid in '+3' behind Safe
	-- Zone · 2x XP · the sprout): the danger chips (Bully, Outlaw, Wanted, Combat) come FIRST, so they always show
	L.ChipOrder = { "Bully", "Outlaw", "Wanted", "Combat", "Zone", "Luck", "Boost", "Private", "Rookie", "Protected", "Blessing",
		"Size", "Kaiju" }
	-- the danger chips first (their short words on a too-long row, L.CheckChipFit); ChipBuffs = the buff chips
	L.ChipDanger = { Bully = true, Outlaw = true, Wanted = true }
	L.ChipBuffs = { "Boost", "Luck", "Blessing", "Rookie", "Private", "Protected", "Size" }
	for i, key in L.ChipOrder do
		ui.chip[key] = makeChip(key, i, icons[key])
	end
	if ui.chip.Wanted and ui.chip.Wanted.Icon then ui.chip.Wanted.Icon.ImageColor3 = ac("StarGold", Theme.Gold) end
	L.ChipWantKey = ""
end

-- (pure) A23-192 (user 10/14 "이것도 그냥 이렇게 길게 해줘 +1 이렇게 하지마"): every chip that wants to show shows with
-- its words, in L.ChipOrder order (danger chips first); a full row wraps (no '+N', no icons-only fold). The other
-- arguments are kept for the callers: -> { Show = { { Key, Icon = false, Danger? } .. }, More = 0 }
function HUD.ChipPlan(keys, danger, _iconOK, _buffs, _open, _fit, _safeZone, zoneDanger)
	local show = {}
	for _, k in keys do
		table.insert(show, { Key = k, Icon = false, Danger = (danger[k] or (k == "Zone" and zoneDanger)) and true or nil })
	end
	return { Show = show, More = 0 }
end

-- refreshChips' last step: the plan on the chips (setChip already set their words / colours / visibility)
function L.ApplyChipFold()
	local keys, iconOK = {}, {}
	for _, key in L.ChipOrder do
		local chip = ui.chip[key]
		if chip and chip.Frame.Visible then
			table.insert(keys, key)
			if chip.Icon then iconOK[key] = true end
		end
	end
	local town, pvp = attr("ZoneTown", false) == true, attr("ZonePvP", false) == true and getFaction() ~= "Neutral"
	local plan = HUD.ChipPlan(keys, L.ChipDanger, iconOK, L.ChipBuffs, true, #keys, town, pvp)
	L.ChipShown = plan
	local on = {}
	for _, row in plan.Show do on[row.Key] = row end
	local s = currentScale()
	local iconPx = (IS_TOUCH and L.ChipTop.IconTouch or L.ChipTop.Icon) / s
	for _, key in L.ChipOrder do
		local chip = ui.chip[key]
		local row = chip and on[key]
		if chip then
			chip.Frame.Visible = row ~= nil
			if row then
				chip.Label.Visible = not row.Icon
				if chip.Icon then
					if row.Icon then chip.Icon.Visible = true end
					chip.Icon.Size = UDim2.fromOffset(iconPx, iconPx)
				end
				local pad = row.Icon and math.max(2, ((L.ChipRowH or L.ChipH) - iconPx) / 2) or nil
				if pad then
					chip.Pad.PaddingLeft, chip.Pad.PaddingRight = UDim.new(0, pad), UDim.new(0, pad)
				else
					chip.Pad.PaddingRight = UDim.new(0, 10)
				end
			end
		end
	end
end

-- A23-40 / A23-192: the row needs a second line -> first the danger chips' short words (the Outlaw line); still two
-- lines -> the row wraps (nothing hidden; the event line moves down: HUD.TopBottom measures the row). refreshChips starts again with the full words when the chip set changes
function L.CheckChipFit()
	if not ui.chips or not ui.chipList then return end
	local s = math.max(0.1, currentScale())
	local rowPx = (L.ChipRowH or L.ChipH) * s
	local over = ui.chipList.AbsoluteContentSize.Y > rowPx + 2 or ui.chipList.AbsoluteContentSize.X > ui.chips.AbsoluteSize.X + 1
	-- (test Studio photo 10/14: dropping the icons first left 'Outlaw +3' - the short danger words come first)
	-- A23-192: nothing is folded any more - a too-long row only takes the danger chips' short words, then wraps
	if ui.chips.AbsoluteSize.X > 0 and over and not L.ChipShort then
		L.ChipShort = true
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
	ui.questHeaderIcon = UIKit.ArtImage("Star", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, hh * 0.47, 0.5, 0),
		Size = UDim2.fromOffset(hh * 0.6, hh * 0.6),
		ImageColor3 = ac("StarGold", Theme.Gold),
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
		local pad = 14 -- PanelMain's navy rim is ~12 du at its 0.35 slice scale
		ui.questRowW = L.OverlayW - 2 * pad
		ui.questOverlay = UIKit.ArtFrame("PanelMain", {
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
		local _, closeLabel = UIKit.ArtButton("Chip", {
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

----------------------------------------------------------------- A23-81 quest lines / window helpers
-- how many quest lines the HUD shows on the left (Config.QuestTabs.HudLines; 2 before A23-81)
function L.QuestLines()
	local qt = Config.QuestTabs
	return math.clamp(math.floor(tonumber(type(qt) == "table" and qt.HudLines) or 2), 1, 5)
end

-- the quest window module is there (it registered Panels "Journal")
function L.HasQuestBook()
	local qb = C and C.QuestBook
	return type(qb) == "table" and type(qb.Toggle) == "function" and type(qb.IsReady) == "function" and qb.IsReady() == true
end

-- 검수 10/08 (the user's own save showed "빛의 기사단 1명 털기 0/1"): a daily / extra slot keeps the text it was made with,
-- so a save from before A23-48 still holds Korean. The screen never trusts saved words: those rows are written again
-- from Config's English template the way QuestService.newQuest writes them (Gold: the plain number; Kill / Golden: the
-- monster's short name and the count; others: the count; then Config.Plural). Other rows keep the server's text.
function L.QuestTemplate(id)
	local q = Config.Quests
	for _, t in type(q) == "table" and type(q.Templates) == "table" and q.Templates or {} do
		if t.Id == id then return t end
	end
	return nil
end

function L.EnglishQuestText(e, text)
	if type(e) ~= "table" or (e.Kind ~= "Daily" and e.Kind ~= "Extra") then return text end
	local t = L.QuestTemplate(e.Id)
	local target = tonumber(e.Target)
	if not t or type(t.Text) ~= "string" or not target then return text end
	local ok, out
	if e.Id == "Gold" then
		ok, out = pcall(string.format, t.Text, tostring(math.floor(target)))
	elseif e.Id == "Kill" or e.Id == "Golden" then
		local def = type(Config.MonsterTypes) == "table" and Config.MonsterTypes[e.Unit] or nil
		local name = type(def) == "table" and (def.Short or def.Name) or nil
		if type(name) ~= "string" then return text end
		ok, out = pcall(string.format, t.Text, name, math.floor(target))
	else
		ok, out = pcall(string.format, t.Text, math.floor(target))
	end
	if not ok or type(out) ~= "string" then return text end
	if type(Config.Plural) == "function" then
		local okP, plural = pcall(Config.Plural, out)
		if okP and type(plural) == "string" then out = plural end
	end
	return out
end

-- the short name of a row: a daily / extra slot's template's English one, else the server's
function L.EnglishShortName(e)
	if type(e) == "table" and (e.Kind == "Daily" or e.Kind == "Extra") then
		local t = L.QuestTemplate(e.Id)
		if t and type(t.ShortName) == "string" and t.ShortName ~= "" then return t.ShortName end
	end
	return (type(e) == "table" and type(e.ShortName) == "string" and e.ShortName ~= "") and e.ShortName or nil
end

-- 검수 10/08 (the user's photo: a finished line showed only its icon and [Claim], the name was gone): a finished line keeps
-- its name and says Done!; the Claim pill shows only where a press claims it (PC: every line; phones: line 1 - the block's
-- tap claims line 1). Returns claimable, pill.
function L.LineFinish(e, li)
	local claimable = type(e) == "table" and type(e.Progress) == "number" and type(e.Target) == "number"
		and e.Progress >= e.Target and e.CanClaim == true
		and (e.Pinned == true or e.Kind == "Daily" or e.Kind == "Sub") -- the list rows' 받기 rule (refreshQuests)
	return claimable, claimable and (not IS_TOUCH or li == 1)
end

-- the line icon's art keys, first found wins: the quest's tab icon (Config.QuestTabs, 이미지 생성 2's QuestTabIcon<tab>:
-- the kind at a glance), then the monster head of a kill quest, the row type's icon, the scroll; no quest -> the star
function L.LineIconKeys(e)
	if type(e) ~= "table" then return { "IconStar" } end
	local keys = {}
	local ok, tab = pcall(Config.QuestTab, e.Id, e.Kind)
	if ok and type(tab) == "string" then table.insert(keys, "QuestTabIcon" .. tab) end
	if e.Unit then table.insert(keys, "IconMon" .. tostring(e.Unit)) end
	table.insert(keys, QUEST_ICON[e.Id] or "IconScroll")
	table.insert(keys, "IconScroll")
	return keys
end

-- one quest's identity across redraws (a daily slot gets a new template id when it is claimed)
function L.EntryKey(e)
	return tostring(e.Id) .. "|" .. tostring(e.Slot)
end

-- the lines' order: `first`, then the preferred indexes (skipping repeats / missing), then the rest in order
function L.QuestLineOrder(entries, first, prefer)
	local order, seen = {}, {}
	local function add(i)
		if type(i) == "number" and entries[i] and not seen[i] then
			seen[i] = true
			table.insert(order, i)
		end
	end
	add(first)
	for k = 1, 5 do add(prefer[k]) end
	for i = 1, #entries do add(i) end
	return order
end

-- A23-81: a quest that left the list after it was ready to claim = finished (the window's 'Done' this session)
function L.TrackDone(old, new)
	if type(old) ~= "table" or type(new) ~= "table" then return end
	local now = {}
	for _, e in new do now[L.EntryKey(e)] = true end
	questState.DoneSession = questState.DoneSession or {}
	for _, e in old do
		if e.Progress >= e.Target and e.CanClaim and not now[L.EntryKey(e)] and not e.NextGoal then
			local dup = false
			for _, d in questState.DoneSession do
				if d.Id == e.Id and d.Text == e.Text then dup = true break end
			end
			if not dup then
				table.insert(questState.DoneSession, { Id = e.Id, Text = e.Text, ShortName = e.ShortName, Kind = e.Kind })
				if #questState.DoneSession > 40 then table.remove(questState.DoneSession, 1) end
			end
		end
	end
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
	-- 검수 2026-10-08: each line on the cream ListRow plate (L.QuestPlate), its words navy (light-plate text)
	-- 검수 10/09 (user on the cream plates: "이거 왜 이래"): back to the soft dark band + white outlined words; the plate
	-- path stays behind L.QuestPlate.On
	local onPlate = L.QuestPlate.On == true and UIKit.ArtId("ListRow") ~= nil
	ui.questOnPlate = onPlate
	local n = L.QuestLines() -- A23-81: up to Config.QuestTabs.HudLines lines
	for i = 1, n do
		-- one row = [icon][text][3/5 | 받기][▼ on line 1, PC]: a horizontal list; the text keeps its own width (shrinks and
		-- cuts with … only when the row is full), so the numbers / 받기 / ▼ sit right after it, never at the far edge
		-- (review 2026-10-06 devlog 15: '101/800' floated apart at the block's right end)
		local row = UIKit.Create(IS_TOUCH and "Frame" or "TextButton", {
			Name = "Line" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1 / n, 0),
			Position = UDim2.fromScale(0, (i - 1) / n),
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
		local icon = UIKit.ArtImage("GlyphQuest", {
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
		}, style, onPlate)
		text.AutomaticSize = Enum.AutomaticSize.X
		-- phones: the game's 11 px floor (Config.UI.MinTextSize) instead of the 12 px name-tag floor - the 150 px block
		-- beside the minimap fits "Free the supply road" only at 11 px (A23-63 Montserrat, 2026-10-07)
		if IS_TOUCH then
			text:SetAttribute("StyleMinPx", 11)
			-- regular weight: bold "Free the supply road" ran 4 px past the room at 11 px
			if type(UIKit.ApplyFont) == "function" then UIKit.ApplyFont(text, Enum.FontWeight.Regular, "Body") end
		end
		-- cut inside a word when it must ('AtEnd' drops whole words: "Free the…" left half the row empty). No flex shrink:
		-- L.FitQuestLine gives the words their width (검수 10/08: shrink squeezed a finished line's name to nothing)
		text.TextTruncate = Enum.TextTruncate.SplitWord
		-- 검수 10/09 (main: 'To the F…'): a width measured before the font loaded is too small -> measure again when the
		-- words stop fitting (FitQuestLine only changes Size, so this settles after one pass)
		text:GetPropertyChangedSignal("TextFits"):Connect(function()
			if not text.TextFits and ui.qline[i] then task.defer(L.FitQuestLine, ui.qline[i]) end
		end)
		local nums = UIKit.StyledLabel({
			Name = "Nums",
			LayoutOrder = 3,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
			Parent = row,
		}, "Number", onPlate)
		-- 받기: the green candy pill (same art as the list rows' 받기), text on it
		local claim = UIKit.ArtFrame("Chip", {
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
		-- the soft band sits beside the row in the block (a band inside the row would be a list item), under its text;
		-- on the plate (L.QuestPlate) the line needs no band: the plate is laid out by L.LayoutQuestLines
		local band, plate = nil, nil
		if onPlate then
			plate = UIKit.ArtFrame("ListRow", { Name = "Plate" .. i, ZIndex = 2, Visible = false, Parent = block }) -- under the row (Z 3)
			UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, L.QuestPlate.PadL), Parent = row })
		else
			band = L.SoftBand(block, "Right")
			band.Name = "Band" .. i
			band.Size = UDim2.new(1, 64, 1 / n, 2)
			band.Position = UDim2.new(0, -8, (i - 1) / n, -1)
			band.Visible = false
		end
		ui.qline[i] = { Row = row, Icon = icon, Text = text, Nums = nums, Claim = claim, ClaimText = claimText, Entry = nil,
			Band = band, Plate = plate }
	end
	if L.Tracker.On then L.BuildTracker(root) end
end

----------------------------------------------------------------- building: quest tracker (A23-94)
-- user 10/09 (a reference shot from another game): the 'now do' quest big at the left middle, no plate - line 1 = the
-- kind icon + the quest's name (bold, outlined, a soft dark band behind it), line 2 = one goal sentence, line 3 =
-- (p/t) in red-orange, green Done! + [Claim] when it can be claimed. It draws HUD line 1's entry (L.SetQuestLine li 1,
-- 개발 1 picks it); the head line 'Quests (n) ▼' sits under it and opens the quest window. Lines 2-3 are not drawn.
function L.BuildTracker(root)
	local T = L.Tracker
	local frame = UIKit.Create("TextButton", {
		Name = "QuestTracker",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(300, 0),
		Visible = false,
		ZIndex = 3,
		Parent = root,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, T.Gap),
		}),
	})
	frame.Activated:Connect(function()
		if IS_TOUCH then L.QuestBlockTap() else L.QuestLineTap(1) end
	end)
	-- line 1: the band (behind) + a horizontal row of icon and name
	local head = UIKit.Create("Frame", { Name = "Head", LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, T.TitleH), ZIndex = 3, Parent = frame })
	local band = L.SoftBand(head, "Right")
	band.Size = UDim2.new(1, 64, 1, 4)
	band.Position = UDim2.new(0, -8, 0, -2)
	local row = UIKit.Create("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
		Parent = head }, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local icon = UIKit.ArtImage("GlyphQuest", { Name = "Icon", LayoutOrder = 1, Size = UDim2.fromOffset(T.TitleH, T.TitleH),
		ZIndex = 5, Parent = row })
	local title = UIKit.StyledLabel({ Name = "Title", LayoutOrder = 2, Size = UDim2.new(1, -T.TitleH - 6, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = row }, "Title")
	-- line 2: the goal sentence (wraps)
	local goal = UIKit.StyledLabel({ Name = "Goal", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
		Parent = frame }, "Body")
	for _, prop in { "TextFits", "TextBounds" } do -- A23-179: a longer translation shrinks it (L.GoalGuard)
		goal:GetPropertyChangedSignal(prop):Connect(function() task.defer(L.GoalGuard) end)
	end
	-- line 3: (p/t) + the Claim pill
	local prog = UIKit.Create("Frame", { Name = "Progress", LayoutOrder = 3, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, T.ProgH), ZIndex = 4, Parent = frame }, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local nums = UIKit.StyledLabel({ Name = "Nums", LayoutOrder = 1, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = prog }, "Number")
	local claim = UIKit.ArtFrame("Chip", { Name = "Claim", LayoutOrder = 2, ImageColor3 = COL.HotTint, Visible = false,
		ZIndex = 5, Parent = prog }, { Color = Theme.Good, CornerRadius = UDim.new(0.5, 0) })
	local claimText = UIKit.StyledLabel({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = TXT.Claim, ZIndex = 6,
		Parent = claim }, "Number")
	if IS_TOUCH then -- phones: the game's 11 px floor for the sentence and the numbers (the block sits beside the minimap)
		goal:SetAttribute("StyleMinPx", 11)
		nums:SetAttribute("StyleMinPx", 11)
		title:SetAttribute("StyleMinPx", 13)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() L.PlaceTrackerHead() end)
	-- showing / hiding changes no size: HUD.QuestBlock still has to follow it (이미지 개발 10/09)
	frame:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(L.PlaceTrackerHead) end)
	-- 퀘스트 바이블 §15 P1 ③ (최종 검수 10/15): on a PC the quests I pinned in the quest window, one small line each under
	-- the main line (none by default - the user's "안 나와도 돼"); a press guides there (the one guide = the line I pick)
	local pins = {}
	if not IS_TOUCH then
		for i = 1, L.PinMax do
			local b = UIKit.StyledLabel({ Name = "Pin" .. i, LayoutOrder = 10 + i, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
				Visible = false, ZIndex = 4, Parent = frame }, "Body")
			local hit = Instance.new("TextButton")
			hit.Name = "PinHit"
			hit.BackgroundTransparency, hit.Text, hit.AutoButtonColor = 1, "", false
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 5
			hit.Parent = b
			hit.Activated:Connect(function()
				local e = pins[i] and pins[i].Entry
				if e then HUD.QuestGo(e) end
			end)
			pins[i] = { Label = b, Entry = nil }
		end
	end
	ui.tracker = { Frame = frame, Band = band, Icon = icon, Title = title, Goal = goal, Nums = nums, Claim = claim,
		ClaimText = claimText, Pins = pins }
end

-- §15 P1 ③: the pins (row keys, Settings "Pins", at most L.PinMax) and their rows among entries (pure on its arguments)
L.PinMax = 2
function HUD.PinKey(e)
	return type(e) == "table" and L.EntryKey(e) or nil
end

function HUD.Pins()
	local st = C and C.Settings
	local ok, list = false, nil
	if type(st) == "table" and type(st.Get) == "function" then ok, list = pcall(st.Get, "Pins") end
	return (ok and type(list) == "table") and list or {}
end

-- the entries' indexes of my pins, in pin order (a pin whose quest left the list is skipped)
function HUD.PinIndexes(entries, pins)
	local out = {}
	for _, key in type(pins) == "table" and pins or {} do
		for i, e in type(entries) == "table" and entries or {} do
			if L.EntryKey(e) == key then table.insert(out, i) break end
		end
	end
	return out
end

-- pin / unpin a row from the quest window: true = pinned now, false = unpinned, nil = full (the press refuses)
function HUD.TogglePin(e)
	local key = HUD.PinKey(e)
	if not key then return nil end
	local list = HUD.Pins()
	local at = table.find(list, key)
	if at then
		table.remove(list, at)
	elseif #list >= L.PinMax then
		return nil
	else
		table.insert(list, key)
	end
	local st = C and C.Settings
	if type(st) == "table" and type(st.Set) == "function" then pcall(st.Set, "Pins", list) end
	if refreshQuests then task.defer(refreshQuests) end
	return at == nil
end

function HUD.IsPinned(e)
	local key = HUD.PinKey(e)
	return key ~= nil and table.find(HUD.Pins(), key) ~= nil
end

-- 최종 검수 10/15 (user photo: "이런 내용들 안 나와도 돼. 굳이 다음 퀘스트 뭔지"): the goal chips' tiers 2 'Next' and
-- 3 'Big goal' under the quest line are gone on PC and phones (A23-167 ① removed, no switch back - A23-191)

-- line 1's entry -> the tracker (called from L.SetQuestLine)
function L.SetTracker(e, label, nums)
	local t = ui.tracker
	if not t then return end
	t.Frame.Visible = label ~= nil
	if not label then return end
	local title = (type(e) == "table" and type(e.ShortName) == "string" and e.ShortName ~= "") and e.ShortName or label
	local goal = (type(e) == "table" and type(e.Goal) == "string" and e.Goal ~= "") and e.Goal
		or (type(e) == "table" and type(e.Text) == "string" and e.Text ~= "" and e.Text) or label
	t.Title.Text = title
	t.Goal.Text = goal
	t.Goal.Visible = goal ~= title
	L.FitGoal() -- a new sentence may need a smaller size to stay within two lines
	local claimable, pill = L.LineFinish(e, 1)
	t.Claim.Visible = pill
	t.Nums.Visible = claimable or nums ~= nil
	t.Nums.Text = claimable and TXT.QuestDone or ("(" .. tostring(nums or "") .. ")")
	t.Nums.TextColor3 = claimable and Theme.Good or L.Tracker.ProgColor
	if t.Icon then
		local img = nil
		for _, key in L.LineIconKeys(e) do
			img = UIKit.ArtId(key)
			if img then break end
		end
		t.Icon.Image = img or t.Icon.Image
	end
	task.defer(L.PlaceTrackerHead)
end

-- the tracker at the quest rect (PC: the left middle; phones: beside the minimap), text sizes from the rect's line height
function L.LayoutTracker(q)
	local t = ui.tracker
	if not t then return end
	local T = L.Tracker
	local lh = q.H / 2
	local titleSize = math.max(14, math.floor(lh * T.TitleK))
	local bodySize = math.max(12, math.floor(lh * T.BodyK))
	if IS_TOUCH then bodySize = math.max(12, math.ceil(11 / currentScale())) end
	-- small PC windows: the tracker (taller than the rect: up to two goal lines) moves up so it ends
	-- above the bottom group (portrait / power line), never above the minimap's bottom
	local y = q.Y
	local R = L.Rects
	if not IS_TOUCH and R and R.power_line and R.minimap then
		local need = math.ceil(titleSize * 1.25) + math.ceil(bodySize * 1.2) * 2 + math.ceil(bodySize * 1.35) + T.Gap * 4
			+ 8
			+ #HUD.Pins() * (math.ceil(bodySize * 1.2) + T.Gap) -- §15 P1 ③: a line per pin
		local floorY = math.min(R.power_line.Y, (R.portrait and R.portrait.Y) or R.power_line.Y) - 6
		y = math.max(R.minimap.Y + R.minimap.H + 6, math.min(q.Y, floorY - need))
	end
	q = { X = q.X, Y = y, W = q.W, H = q.H }
	t.Frame.Position = UDim2.fromOffset(q.X, q.Y)
	t.Frame.Size = UDim2.fromOffset(q.W, 0)
	local iconS = math.ceil(titleSize * 1.15)
	local head = t.Title.Parent and t.Title.Parent.Parent
	if head then head.Size = UDim2.new(1, 0, 0, math.ceil(titleSize * 1.25)) end
	if t.Icon then t.Icon.Size = UDim2.fromOffset(iconS, iconS) end
	t.Title.Size = UDim2.new(1, -iconS - 6, 1, 0)
	t.Title.TextSize = titleSize
	T.GoalMax = bodySize
	T.GoalMin = math.min(bodySize, IS_TOUCH and bodySize or math.max(12, math.floor(lh * T.BodyMinK)))
	t.Nums.TextSize = bodySize
	local prog = t.Nums.Parent
	if prog then prog.Size = UDim2.new(1, 0, 0, math.ceil(bodySize * 1.35)) end
	t.Claim.Size = UDim2.fromOffset(math.floor(bodySize * 4.2), math.ceil(bodySize * 1.3))
	t.ClaimText.TextSize = math.max(12, math.floor(bodySize * 0.85))
	for _, pin in t.Pins or {} do pin.Label.TextSize = math.max(12, math.floor(bodySize * 0.85)) end
	T.Rect = q
	L.FitGoal()
	task.defer(L.PlaceTrackerHead)
end

-- the goal sentence at GoalMax du, or the largest size down to GoalMin that keeps it within GoalLines lines of the
-- tracker's width (measured by L.TextLines). The box gets the measured lines' height itself: 이미지 개발 10/10 (main
-- Studio 991x451, UIScale 0.5: AutomaticSize gave the box one line while the words wrapped to two - "...in the" and the
-- rest cut off). A size under the style's real-px floor is measured at the floor (that is what renders); while a size is
-- being measured the line keeps AutomaticSize
-- 최종 검수 10/14 (A23-179 translation overflow): Roblox's automatic translation changes only what is DRAWN - goal.Text
-- stays English, so FitGoal (TextService on goal.Text) sized the box for the English sentence. The engine's TextFits is
-- computed on the drawn (translated) text: while it is false the size steps down by 1 (pure L.GuardStep) to the least of
-- GoalMin and the style floor; FitGoal starts over at the next text / layout change.
function L.GuardStep(fits, size, least)
	if fits == false and type(size) == "number" and type(least) == "number" and size > least then return size - 1 end
	return size
end

function L.GoalGuard()
	local t, T = ui.tracker, L.Tracker
	local goal = t and t.Goal
	if not (goal and T.GoalMin) or goal.AutomaticSize ~= Enum.AutomaticSize.None then return end
	local tc = goal:FindFirstChildOfClass("UITextSizeConstraint")
	local floorDu = tc and math.ceil(tc.MinTextSize / math.max(0.05, currentScale())) or 0
	local size = L.GuardStep(goal.TextFits, goal.TextSize, math.max(T.GoalMin, floorDu))
	if size ~= goal.TextSize then goal.TextSize = size end
end

function L.FitGoal()
	local t, T = ui.tracker, L.Tracker
	if not (t and T.Rect and T.GoalMax) then return end
	local goal = t.Goal
	local text, font, width = goal.Text, goal.FontFace, T.Rect.W - 2 -- 2 du spare: never wrap later than the render
	local tc = goal:FindFirstChildOfClass("UITextSizeConstraint")
	local floorDu = tc and math.ceil(tc.MinTextSize / math.max(0.05, currentScale())) or 0
	local size, lines, lineH, pending = T.GoalMax, nil, nil, false
	while true do
		local n, h = L.TextLines(text, font, math.max(size, floorDu), width)
		if n == nil then
			pending = true
			break
		end
		lines, lineH = n, h
		if n <= T.GoalLines or size <= T.GoalMin then break end
		size -= 1
	end
	if pending then
		if goal.TextSize > T.GoalMax or goal.TextSize < T.GoalMin then goal.TextSize = T.GoalMax end
		if goal.AutomaticSize ~= Enum.AutomaticSize.Y then goal.AutomaticSize = Enum.AutomaticSize.Y end
		return
	end
	if goal.TextSize ~= size then goal.TextSize = size end
	local boxH = math.ceil(lines * lineH) + 2
	if goal.AutomaticSize ~= Enum.AutomaticSize.None then goal.AutomaticSize = Enum.AutomaticSize.None end
	if goal.Size.Y.Offset ~= boxH or goal.Size.X.Scale ~= 1 then goal.Size = UDim2.new(1, 0, 0, boxH) end
end

-- lines `text` wraps to at `size` du in `width` du and one line's height in du (TextService, cached); nil while it is
-- measured (L.FitGoal runs again when the answer comes)
function L.TextLines(text, font, size, width)
	if text == "" then return 1, size end
	local cache = L.LineCache
	local key = string.format("%s|%d|%d|%s|%s", text, size, math.floor(width), tostring(font.Family), tostring(font.Weight))
	local v = cache.Lines[key]
	if v ~= nil then
		if v then return v[1], v[2] end
		return nil
	end
	cache.N += 1
	if cache.N > 300 then cache.Lines, cache.N = {}, 1 end
	cache.Lines[key] = false
	task.spawn(function()
		local ok, res = pcall(function()
			local ts = game:GetService("TextService")
			local p = Instance.new("GetTextBoundsParams")
			p.Text, p.Font, p.Size, p.Width = text, font, size, width
			local wrapped = ts:GetTextBoundsAsync(p)
			p.Width = 100000
			local one = ts:GetTextBoundsAsync(p)
			local h = math.max(1, one.Y)
			return { math.max(1, math.floor(wrapped.Y / h + 0.5)), h }
		end)
		if not ok then warnThrottled("goal lines failed: " .. tostring(res)) end
		cache.Lines[key] = ok and res or { 1, size }
		local fine, err = pcall(L.FitGoal)
		if not fine then warnThrottled("goal fit failed: " .. tostring(err)) end
	end)
	return nil
end

-- L.QuestBottom = where the list / overlay start: right under the tracker (A23-99: no head line over the lines)
function L.PlaceTrackerHead()
	local t, q = ui.tracker, L.Tracker.Rect
	if not (t and q) then return end
	local s = currentScale()
	local th = t.Frame.Visible and (t.Frame.AbsoluteSize.Y / s) or 0
	local y = q.Y + (th > 0 and th + L.Tracker.Gap * 2 or 0)
	L.QuestBottom = y
	if ui.quests then ui.quests.Position = UDim2.fromOffset(q.X, L.QuestBottom + 4) end
	if ui.questOverlay and ui.questOverlay.Position.Y.Offset ~= L.QuestBottom + 4 then
		ui.questOverlay.Position = UDim2.fromOffset(ui.questOverlay.Position.X.Offset, L.QuestBottom + 4)
	end
	-- 이미지 개발 10/09: Rects.quest is only the sheet's two lines, the tracker runs lower - publish the drawn block (a NEW
	-- table when it changes, nil while nothing shows) so QuestMarker keeps its indicator off it
	local top = th > 0 and q.Y or y
	local bottom = th > 0 and q.Y + th or top
	local old = HUD.QuestBlock
	if bottom - top < 1 then
		HUD.QuestBlock = nil
	elseif not (old and old.X == q.X - 8 and old.Y == top and old.W == q.W + 8 and old.H == bottom - top) then
		HUD.QuestBlock = { X = q.X - 8, Y = top, W = q.W + 8, H = bottom - top }
	end
end

-- line metrics follow the rect (logical units): icon about the line height, text size from it (the style floors keep
-- it readable), the 받기 pill a little shorter than the line
function L.LayoutQuestLines(q)
	local block = ui.questLines
	if not block then return end
	local lh = q.H / 2 -- the layout's quest rect holds two lines; a third one hangs under it (A23-81)
	block.Position = UDim2.fromOffset(q.X, q.Y)
	block.Size = UDim2.fromOffset(q.W, lh * L.QuestLines())
	local iconS = math.floor(lh * 0.9)
	local textSize = math.max(12, math.floor(lh * 0.6))
	if IS_TOUCH then
		-- phones: a smaller icon and the 11 px text (the room goes to the words)
		local s = currentScale()
		iconS = math.floor(lh * 0.7)
		textSize = math.max(12, math.ceil(11 / s))
	end
	for _, l in ui.qline do
		if l.Icon then l.Icon.Size = UDim2.fromOffset(iconS, iconS) end
		l.Text.TextSize = textSize
		l.Nums.TextSize = textSize
		l.Claim.Size = UDim2.fromOffset(math.floor(lh * 2.3), math.floor(lh * 0.86))
		l.ClaimText.TextSize = math.max(12, math.floor(lh * 0.5))
	end
	for _, l in ui.qline do task.defer(L.FitQuestLine, l) end
	task.defer(L.LayoutQuestPlates)
	if ui.tracker then L.LayoutTracker(q) end
end

-- each line's plate: as wide as the line's content (+ L.QuestPlate pads), its height the line minus the gap, hidden with
-- an empty line
function L.LayoutQuestPlates()
	if not ui.qline then return end
	local s = currentScale()
	local P = L.QuestPlate
	for _, l in ui.qline do
		local plate = l.Plate
		if plate then
			local list = l.Row:FindFirstChildOfClass("UIListLayout")
			local w = list and list.AbsoluteContentSize.X / s or 0
			local shown = l.Row.Visible and w > 1
			if shown then
				local h = l.Row.AbsoluteSize.Y / s
				plate.Position = UDim2.new(l.Row.Position.X.Scale, l.Row.Position.X.Offset, l.Row.Position.Y.Scale,
					l.Row.Position.Y.Offset + P.Gap / 2)
				plate.Size = UDim2.fromOffset(math.ceil(w + P.PadL + P.PadR), math.max(1, h - P.Gap))
			end
			if plate.Visible ~= shown then plate.Visible = shown end
		end
	end
end

-- A23-63 (2026-10-07): a line wider than its row first drops its " · ..." tail (the count says it: "Free the supply road
-- · 5 slimes" -> "Free the supply road  1/5"); only what still does not fit is cut with "…" (phones: the block beside
-- the minimap is 150 px and stays out of the thumbstick zone, so it cannot grow; before this it read "Fre…")
function L.FitQuestLine(l)
	local full = l and l.FullText
	if type(full) ~= "string" or not l.Row.Visible then return end
	local s = currentScale()
	local rowW = l.Row.AbsoluteSize.X / s
	local pad = l.Row:FindFirstChildOfClass("UIPadding") -- the plate's left pad (L.QuestPlate.PadL)
	if pad then rowW -= pad.PaddingLeft.Offset + pad.PaddingRight.Offset end
	if rowW <= 1 then return end
	local used = (l.Icon and l.Icon.Visible) and (l.Icon.AbsoluteSize.X / s + 4) or 0
	if l.Nums.Visible then used += l.Nums.AbsoluteSize.X / s + 4 end
	if l.Claim.Visible then used += l.Claim.AbsoluteSize.X / s + 4 end
	local tc = l.Text:FindFirstChildOfClass("UITextSizeConstraint")
	local size = math.max(l.Text.TextSize, tc and tc.MinTextSize or 0)
	-- UiSandbox 10/09 ('Meet H…' / main 'To the F…'): the screen-px floor draws the words bigger than TextSize under
	-- UIScale - measure at the size actually drawn (the one-line TextBounds height, back in logical units)
	local drawn = l.Text.TextBounds.Y / s
	if drawn > size and drawn < size * 3 then size = math.ceil(drawn) end
	local text = full
	local short = string.match(full, "^(.-)%s+·%s")
	local avail = math.max(10, rowW - used)
	local w = nil
	if type(UIKit.MeasureText) == "function" then
		local ok, _, mw = pcall(UIKit.MeasureText, full, size, l.Text.FontFace, 100000)
		if ok and type(mw) == "number" then
			w = mw
			if short and short ~= "" and mw > avail then
				text = short
				local ok2, _, sw = pcall(UIKit.MeasureText, short, size, l.Text.FontFace, 100000)
				w = (ok2 and type(sw) == "number") and sw or mw
			end
		end
	end
	if l.Text.Text ~= text then l.Text.Text = text end
	-- 검수 10/08: the words' own width = what they need, at most what the row has left (SplitWord cuts the rest); never
	-- squeezed to nothing by the numbers / Done! / the pill
	if w then
		l.Text.AutomaticSize = Enum.AutomaticSize.None
		l.Text.Size = UDim2.new(0, math.max(1, math.min(math.ceil(w) + 2, math.floor(avail))), 1, 0)
	end
	-- 검수 10/09 (the user's PC capture: wide plates with the words cut): a re-fit (the TextFits signal, a font that loaded
	-- late) changes the words' width after the plates were laid out - lay them out again on the next frame
	if not L.PlatesQueued then
		L.PlatesQueued = true
		task.delay(0, function()
			L.PlatesQueued = false
			L.LayoutQuestPlates()
		end)
	end
end

-- one line: icon (monster head / row type), text, progress or 받기 (CR-M27 / CR-L31 numbers)
function L.SetQuestLine(l, e, label, nums)
	l.Entry = e
	l.Row.Visible = label ~= nil
	if l.Band then l.Band.Visible = label ~= nil end
	if not label and ui.tracker and l == ui.qline[1] then L.SetTracker(e, nil, nil) end
	if not label then return end
	-- A23-81 (user 2026-10-08 "잘리지 않게"): the quest's short name when the server gives one ("Supply road"), on every
	-- device; a story's 'talks to you' line keeps its own words
	if e and e.ShortName and label == e.Text then label = e.ShortName end
	l.FullText = label
	l.Text.Text = label
	local li = table.find(ui.qline, l) or 0
	local claimable, pill = L.LineFinish(e, li)
	l.Claim.Visible = pill
	l.Nums.Visible = claimable or nums ~= nil
	l.Nums.Text = claimable and TXT.QuestDone or (nums or "")
	if l.Icon then
		local img = nil
		for _, key in L.LineIconKeys(e) do
			img = UIKit.ArtId(key)
			if img then break end
		end
		l.Icon.Image = img or l.Icon.Image
		l.Icon.ImageColor3 = COL.White -- the art keys are colored (the old "Star" key needed a gold tint)
	end
	task.defer(L.FitQuestLine, l) -- after the row's list layout placed the numbers / 받기
	if ui.tracker and li == 1 then L.SetTracker(e, label, nums) end
	task.delay(0, L.LayoutQuestPlates) -- next frame: after the fit and the list layout
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
	elseif HUD.QuestGo then
		HUD.QuestGo(e) -- A23-81: the marker leads to this quest
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
	-- round 3 #3 (ideas_first10 §3): 'Tap here: first quest from Hallie' opens the guide in one tap, even after [Later]
	if e and e.Pinned and e.TutorialStep == 0 and L.PinnedTap then
		L.PinnedTap(e)
		return
	end
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
		-- the two phone lines stay in the plate's navy body (PanelHeader rows 22..96 of 121 = 0.19h..0.79h): they used to
		-- start 3 du from the edges and ran over the gold rims (user 2026-10-07: "Dailies 0/3" over the bottom rim)
		local top, mid, bot = math.floor(h * 0.19 + 0.5), math.floor(h * 0.49 + 0.5), math.floor(h * 0.79 + 0.5)
		ui.questHeaderText.Position = UDim2.fromOffset(tx, top)
		ui.questHeaderText.Size = UDim2.new(1, -tx - 26, 0, mid - top)
		ui.questHeaderSub.Position = UDim2.fromOffset(tx, mid)
		ui.questHeaderSub.Size = UDim2.new(1, -tx - 26, 0, bot - mid)
	else
		ui.questHeaderText.Position = UDim2.fromOffset(tx, 4)
		ui.questHeaderText.Size = UDim2.new(1, -tx - 26, 1, -8)
	end
	ui.questChevron.Size = UDim2.fromOffset(16, math.max(12, h - 8))
end

----------------------------------------------------------------- building: travel bar
local function buildTravel(root)
	ui.travel = UIKit.ArtFrame("ListRow", {
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
	-- combat buttons: the shared feel, quick (<= 0.08 s, no spring that delays the next press)
	if type(UIKit.ButtonFeel) == "function" then UIKit.ButtonFeel(btn, { Fast = true }) end
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
	-- 검수 2026-10-08 (user: 'Settings' / 'Ranking' ran out of their buttons): the name stays inside the tile's gold rim
	-- (L.TileNameInset du in all) and shrinks down to L.TileNamePx real px - 'Settings' needs ~8.5 px in the 44 px top
	-- bar squares; under L.TileLabelMinPx px tiles show icons only (L.LayoutTiles). It was 1.08 x the tile at >= 10 px
	local label = artLabel(false, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -L.TileNameInset, 0.3, 0),
		TextScaled = true,
		MaxTextSize = 14,
		Title = true,
		Text = def.Text or "",
		ZIndex = 4,
		Parent = btn,
	})
	label:SetAttribute("StyleMinPx", L.TileNamePx)
	-- A23-109: PC names keep >= L.TileNamePxPC real px on small windows too (991x451 showed 7 px names)
	-- 10/14 (최종 검수 photo: 'Monsters' touched the rim, 'Settings' filled the square - UIKit's 11px floor held them):
	-- PC names fit L.TileNamePadPC real px narrower than their box (a margin inside the rim) and may go under that floor
	-- down to L.TileNamePxPC (UIKit.FitText attribute FitMinPx)
	if IS_TOUCH then
		L.FitText(label, 12, true, L.TileNamePx)
	else
		label:SetAttribute("FitMinPx", L.TileNamePxPC)
		label:SetAttribute("PickerFitPaddingX", L.TileNamePadPC)
		local fit = ui.textFits and ui.textFits[label]
		if fit then fit.Min = nil end -- artLabel's first fit ran without that floor: L.FitText re-applies it
		L.FitText(label, 13, true, L.TileNamePxPC, true)
	end
	if type(UIKit.StyleText) == "function" then UIKit.StyleText(label, "NameTag") end -- A23-38: white name, navy rim
	if def.Key then keyHint(btn, def.Key, UDim2.new(1, -2, 0, 2), Vector2.new(1, 0)) end
	return btn, label, img
end

-- A23-40 정정 + 보강: [메뉴] (its own square in the Roblox top bar's right end, HudLayout TB) and its fold-out: a clipping
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
		local b, lbl, icon = tileButton(copy, function()
			if copy.Id == "Travel" then L.TravelSeen = true end -- A23-88: the Travel pulse is done
			L.FoldTap(copy)
		end)
		b.Name = "Fold" .. def.Id
		b.Parent = ui.fold
		local entry = { Def = copy, Button = b, Row = row }
		-- A23-113 ③: a row tile's fold copy (phones) locks like the tile itself (L.RefreshLocks)
		if row and type(UIKit.TileLock) == "function" and Config.HudReveal.Tiles[def.Id] then
			local ok, lock = pcall(UIKit.TileLock, b, icon, lbl)
			if ok then entry.Lock = lock end
		end
		if def.Id == "Settings" then ui.settingsGlow = makeGlow(b, UDim.new(0, 10)) end
		if def.Id == "Travel" and not row then ui.travelGlow = makeGlow(b, UDim.new(0, 10)) end -- A23-88
		if def.Id == "Attendance" then ui.attendGlow = makeGlow(b, UDim.new(0, 10)) end -- a claim is open (L.AttendGlow)
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
		-- row tiles always count (A23-40's six; a window still to come answers TileSoon), fold squares need their window;
		-- A23-113 ③: a row tile that has not come yet is in neither the row nor the fold
		if (def.Map or f.Row or L.TileWindow(def) ~= nil or (def.Invite and L.InviteOk()))
			and not (f.Row and (inRow[def.Id] or not (ui.tileCame or {})[def.Id])) then table.insert(list, f) end
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
		Right = m.X - f.Gap, BaseSize = f.Size, BaseLines = f.Lines } -- Base*: L.PlaceFold may shrink to one line
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
-- user 10/14: on PCs the row holds Monsters too (HudLayout, 7 tiles) and the war meter steps left so the 8 L.Fold
-- squares sit beside [메뉴] in one line; this shrink is the fallback where the meter cannot step (Roblox's menu open wide)
-- user 10/13 first look (PC: the 9th square, the row's overflow tile, fell to a second line alone): when the squares
-- need more than the first line, they shrink to fit that one line down to L.FoldMinFrac of [메뉴]'s size, centred on the
-- same line; still too many = the lines as before. Pure: lines = Rects.fold.Lines, size / gap / right (du), n squares;
-- returns the new size and one line, or nil (tools/test_first_look.py)
L.FoldMinFrac = 0.85
function L.FitFold(lines, size, gap, right, n)
	local first = type(lines) == "table" and lines[1] or nil
	if not first or type(n) ~= "number" or n <= first.Cols or first.Cols < 1 then return nil end
	local width = first.Cols * (size + gap) - gap
	local s = (width + gap) / n - gap
	if s < size * L.FoldMinFrac then return nil end
	return s, { { X = right - n * (s + gap) + gap, Y = first.Y + (size - s) / 2, Cols = n } }
end

function L.PlaceFold(animate)
	local list = L.FoldEntries()
	local g = ui.foldGeom
	if g then
		g.Size, g.Lines = g.BaseSize or g.Size, g.BaseLines or g.Lines
		if not IS_TOUCH then
			local s, lines = L.FitFold(g.Lines, g.Size, g.Gap, g.Right, #list)
			if s then g.Size, g.Lines = s, lines end
		end
	end
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
	if L.RefreshMenuGlow then pcall(L.RefreshMenuGlow) end -- open: the square inside glows, not [Menu] too
	ui.foldToken = (ui.foldToken or 0) + 1
	local token = ui.foldToken
	-- 'Screen shake' off / Roblox reduced motion: the squares appear and go at once (no slide)
	local reduced = type(UIKit.ReducedMotion) == "function" and UIKit.ReducedMotion()
	if open then
		ui.fold.Visible = true
		L.PlaceFold(not reduced)
		local panels = C and C.Panels
		if type(panels) == "table" and type(panels.Metric) == "function" then pcall(panels.Metric, "Menu") end -- BB38
		-- A23-79 metrics: the [Invite] square showed
		for _, f in ui.foldShown or {} do
			if f.Def and f.Def.Invite then
				local inv = C and C.Invite
				if type(inv) == "table" and type(inv.Seen) == "function" then pcall(inv.Seen, "Menu") end
			end
		end
	elseif reduced then
		ui.fold.Visible = false
		for _, f in ui.foldTiles do
			if f.Tween then f.Tween:Cancel() end
			f.Button.Visible = false
		end
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
	if L.TileLocked(def.Id) then -- A23-113 ③: a locked square only wiggles (the fold stays open)
		L.TileWiggle(def.Id)
		return
	end
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

	-- 공격 (one press = one swing): Firefly orange disc + my class glyph (L.RefreshAttackGlyph)
	ui.attack = roundButton("Attack", L.Attack, "BtnAttack", COL.AttackFill)
	L.RefreshAttackGlyph()
	-- A23-191 (user 10/14 "표시만 봐도 아니까"): no "Attack" word under the glyph - the icon only
	keyHint(ui.attack, "Attack", UDim2.fromScale(0.86, 0.86), Vector2.new(0.5, 0.5))

	-- 스킬 Q: Firefly blue disc (BtnSpecial); only MP and cooldown decide readiness
	local rel, relArt = roundButton("Release", L.Release, "BtnSpecial", COL.ReleaseFill)
	ui.release, ui.releaseArt = rel, relArt
	L.RefreshSkillIcon() -- my class's Q skill icon (bundle 14), IconSpecial until a class is chosen
	-- A23-191: no "Skill" word under the icon
	ui.skillTimer = artLabel(false, {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.3),
		TextScaled = true,
		MaxTextSize = 26,
		Number = true, AutoLocalize = false,
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
		Ranking = TXT.TileRanking, Codex = TXT.TileCodex, Pet = TXT.Pet, Settings = TXT.TileSettings, Menu = TXT.Menu, News = TXT.TileNews, Diary = TXT.TileDiary,
		Travel = TXT.TileTravel, Help = TXT.TileHelp, Shop = TXT.TileShop, Invite = TXT.TileInvite,
		Attendance = type(Config.Attendance) == "table" and type(Config.Attendance.Text) == "table" and Config.Attendance.Text.Tile or nil }
	ui.tiles = {}
	for i, def in L.Tiles do
		def.Text = names[def.Id]
		local btn, label, icon = tileButton(def, function()
			L.TileTap(def)
		end)
		ui.tiles[i] = { Def = def, Button = btn, Label = label, Icon = icon }
		-- A23-113 ③: the lock look (이미지 개발 UIKit.TileLock); L.RefreshLocks decides when
		if type(UIKit.TileLock) == "function" and Config.HudReveal.Tiles[def.Id] then
			local ok, lock = pcall(UIKit.TileLock, btn, icon, label)
			if ok then ui.tiles[i].Lock = lock end
		end
		if def.Id == "Bag" then ui.bagGlow = makeGlow(btn, UDim.new(0, 10)) end -- B14 scroll hint
		-- 최종 검수 10/13 (ref_rpg_ui #7): a small dot when I own a stronger weapon I can wear (CharacterUI.BetterWeapon)
		if def.Id == "Character" or def.Id == "Bag" then
			ui.betterDots = ui.betterDots or {}
			ui.betterDots[def.Id] = UIKit.ArtImage("BadgeDot", { Name = "BetterDot", AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(14, 14), ZIndex = 8, Visible = false, Parent = btn })
		end
	end
	L.BuildMenu(names)
	-- A23-1 auto combat ON/OFF (round, Firefly BtnRound): hidden until the crown-shard quest unlocks it (no "unlocks at
	-- ..." teaser); ON = gold ring, OFF = dimmed disc
	ui.auto, ui.autoArt = roundButton("Auto", L.Square, "BtnRound", COL.ReleaseFill)
	UIKit.ArtImage("GlyphAuto", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.52, 0.52),
		ZIndex = 3,
		Parent = ui.auto,
	})
	-- A23-191: no "Auto ON / OFF" word - the gold ring (ON) / the dimmed disc (OFF) say it
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
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		ZIndex = 3,
		Parent = ui.attack,
	})
end

-- the Q button's icon: my class's skill art (bundle 14 Skill_<Class>_Q, a square icon), else the Warrior's Q icon before a
-- class is chosen / for a class without its own art (the Artisan pet tamer's 펫 돌진 waits for its icon, A23-39;
-- 그림체 #15: it was the old winged IconSpecial)
function L.RefreshSkillIcon()
	local rel = ui.release
	if not rel then return end
	local class = attr("ClassChosen", false) == true and getClass() or nil
	local key = (class and not (class == "Archer" and getFaction() == "Neutral")) and ("Skill_" .. class .. "_Q") or nil
	-- skills18 (10/10): the class's own Q icon per faction first (Skill_<Class>_Q_<Faction>)
	local own = class and ("Skill_" .. class .. "_Q_" .. tostring(getFaction())) or nil
	if own and UIKit.ArtId(own) then key = own end
	if not (key and UIKit.ArtId(key)) then key = "Skill_Warrior_Q" end
	if ui.releaseIconKey == key and ui.releaseIcon and ui.releaseIcon.Parent then return end
	ui.releaseIconKey = key
	local visible = not ui.releaseIcon or ui.releaseIcon.Visible
	if ui.releaseIcon then ui.releaseIcon:Destroy() end
	ui.releaseIcon = UIKit.ArtImage(key, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		Visible = visible,
		ZIndex = 3,
		Parent = rel,
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
	-- A23-150 7 (최종 검수 10/13): the weapon Tool never shows in the portrait (L.RefreshPortrait drops it) - nothing in it
	-- (the archers' BowGrip switched on / off every shot, a swapped weapon) nor the engine's RightGrip asks for a new copy
	if object.Name == "WeaponModel" or object:FindFirstAncestor("WeaponModel")
		or (object.Name == "RightGrip" and object:IsA("JointInstance")) then
		return false
	end
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
	-- 검수 2026-10-08 (user: the face filled the whole ring): a bust - the head and the shoulders. The frame's centre
	-- drops PortraitDrop head heights below the head's middle and it spans PortraitSpan head heights
	local focus = head.Position - up * head.Size.Y * L.PortraitDrop
	local span = math.max(head.Size.X, head.Size.Y) * L.PortraitSpan
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
	if ui.level then ui.level.Text = tostring(L.LvShown() or level) end

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
	ui.pouch.Text = L.Tx(TXT, "Pouch", TXT.CarriedTag, fmtNum(carried))
	-- 검수 10/09 (UI clutter review ④): the pouch line once I carry gold (or from Config.HudReveal.Level), then for good
	L.PouchOn = L.PouchOn or Config.HudReveal.Shows("Pouch", { Level = num("Level", 0), Carried = carried })
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

-- A23-167: whole minutes left of the first Config.EarlyXP.Seconds of play (2x XP on the server, ProgressionService
-- XPBoost) from the PlaytimeSeconds attribute; nil when it is off, over or not known yet
function L.EarlyXPLeft()
	local e = Config.EarlyXP
	if type(e) ~= "table" or e.Enabled ~= true then return nil end
	local left = (tonumber(e.Seconds) or 0) - num("PlaytimeSeconds", math.huge)
	return left > 0 and math.ceil(left / 60) or nil
end

-- pure (tools/test_comeback_client.py): the boost chip's words - the passes (xp / gold owned), else the first minutes'
-- 2x XP with its minutes left (early); nil = no chip. The 2x XP pass already says 2x XP (the server never stacks them)
function L.BoostText(xp, gold, early)
	local first = type(early) == "number" and early > 0
	if gold then return (xp or first) and TXT.BoostBoth or TXT.BoostGold end
	if xp then return TXT.BoostXP end
	return first and L.Tx(TXT, "EarlyXP", early) or nil
end

-- A23-75: one gold chip while a 2x pass is owned (attribute names from Config.GamePasses, 게임성 개발 2); its icon is
-- the XP star, or the gold pile for 2x Gold alone. A23-167: the first minutes' 2x XP shows on it too (L.BoostText)
function L.RefreshBoost()
	local chip = ui.chip.Boost
	if not chip then return end
	local passes = type(Config.GamePasses) == "table" and Config.GamePasses or {}
	local function owns(kind, default)
		local def = type(passes[kind]) == "table" and passes[kind] or {}
		return attr(type(def.Attr) == "string" and def.Attr or default, false) == true
	end
	local xp, gold = owns("XP2", "PassXP2"), owns("Gold2", "PassGold2")
	local early = L.EarlyXPLeft()
	local words = L.BoostText(xp, gold, early)
	setChip(chip, words ~= nil, words, Theme.Gold, true, nil, true)
	local key = (gold and not xp and not early) and "IconGoldPile" or "IconExp"
	if chip.Icon and chip.IconKey ~= key then
		local id = UIKit.ArtId(key)
		if id then chip.Icon.Image, chip.IconKey = id, key end
	end
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
	local wanted = L.Tx(TXT, "Wanted", string.rep("★", math.clamp(stars, 0, 5)))
	if bounty > 0 then wanted ..= L.Tx(TXT, "WantedBounty", fmtNum(bounty)) end
	setChip(ui.chip.Wanted, stars > 0 or bounty > 0, wanted, Theme.Bad, false, nil, stars > 0)

	local blessing = UIKit.GameAttr("WarBlessing", "None")
	local bdef = (blessing == "Halo" or blessing == "Horns") and Config.Factions[blessing] or nil
	if bdef then
		local pct = math.floor((Config.War.BlessingGold or 0.25) * 100 + 0.5)
		setChip(ui.chip.Blessing, true, L.Tx(TXT, "Blessing", bdef.Name, pct), factionColor(blessing),
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
		and L.Tx(TXT, "RookieGrace", graceLeft) or TXT.Rookie, Theme.XP, false, pal.Rookie, true)
	setChip(ui.chip.Protected, attr("Protected", false) == true, TXT.Protected, Theme.XP)
	setChip(ui.chip.Combat, num("InCombatUntil", 0) > now, TXT.InCombat, Theme.Revenge)
	local size = num("SizeMult", 1)
	setChip(ui.chip.Size, size > 1.001, L.Tx(TXT, "Size", size), Theme.Gold)
	local bully = math.floor(num("BullyStacks", 0))
	local bullyLeft = math.max(1, math.ceil((num("BullyEndsAt", 0) - now) / 60)) -- A23-22 penalty minutes
	setChip(ui.chip.Bully, bully > 0, L.Tx(TXT, "BullyPenalty", bullyLeft), Theme.Bad)
	-- 2-C #9 (A23-23): this week's outlaw (RankingService attribute Outlaw) - the danger chip with the ranking's own line
	local rk = type(Config.Ranking) == "table" and type(Config.Ranking.Text) == "table" and Config.Ranking.Text or {}
	-- phones (and a PC row too narrow for the whole line, L.ChipShort): the icon + the short word (Config OutlawChipShort)
	local outlaw = (IS_TOUCH or L.ChipShort) and type(rk.OutlawChipShort) == "string" and rk.OutlawChipShort or rk.OutlawChip
	setChip(ui.chip.Outlaw, attr("Outlaw", false) == true and type(outlaw) == "string", outlaw, Theme.Bad)
	setChip(ui.chip.Kaiju, attr("KaijuState", "None") == "Queued", TXT.KaijuQueued, Theme.Bad)
	setChip(ui.chip.Private, UIKit.GameAttr("PrivateServer", false) == true, TXT.PrivateHalf, Theme.SubText, false, nil, true)
	L.RefreshBoost()

	-- A23-192: all of them, in their order (a new set starts again with the full danger words)
	local wantKey = ""
	for _, key in L.ChipOrder do
		local chip = ui.chip[key]
		if chip and chip.Frame.Visible then wantKey ..= key .. "," end
	end
	if wantKey ~= L.ChipWantKey then
		L.ChipWantKey = wantKey
		L.ChipShort = false
	end
	L.ApplyChipFold()
end

-- the chips' "what changed" key (pure): the chip set without In Combat, the zone kind, the luck words
function HUD.ChipFoldSig(wantKey, town, pvp, luck)
	local keys = string.gsub(tostring(wantKey or ""), "Combat,", "")
	return keys .. "|" .. (town and "T" or (pvp and "P" or "W")) .. "|" .. tostring(luck or "")
end
L.ChipFoldSig = HUD.ChipFoldSig

-- the status chip row shows at least one chip (user 10/13 first look: out of town the row is empty and EventHUD's
-- next-event line floated a whole row under the war meter; EventHUD lifts it into the empty row)
-- 최종 검수 10/14 (user photo while playing: 'Crown War · 9:38', the quest marker and 'Golden Goose 3:43' piled up at the
-- top centre): the DRAWN bottom (du, MainGui units incl. the top bar) of the top-centre HUD - the war meter with its plate
-- and info line (they reach below Rects.war_meter) and the status chips row while it shows. nil = nothing there.
-- EventHUD puts the next-event chip under it, QuestMarker keeps the quest marker under it.
-- (pure) the lowest drawn bottom of `list` (GuiObjects: AbsolutePosition / AbsoluteSize in px) in du
function L.DrawnBottom(list, rootY, s)
	local b = nil
	s = (type(s) == "number" and s > 0) and s or 1
	for _, g in list do
		local h = g.AbsoluteSize.Y
		if h > 0 then
			local y = (g.AbsolutePosition.Y + h - rootY) / s
			if not b or y > b then b = y end
		end
	end
	return b
end

function HUD.TopBottom()
	local root = UIKit and UIKit.Gui
	if not root then return nil end
	local list = {}
	if ui.war and ui.war.Visible then -- the meter's drawn pieces only (its frame is taller than the bar now)
		for _, g in { ui.warPlate, ui.warBar, ui.warBadgeHalo, ui.warBadgeHorns } do
			if typeof(g) == "Instance" and g:IsA("GuiObject") and g.Visible then table.insert(list, g) end
		end
	end
	if HUD.ChipsShown() then table.insert(list, ui.chips) end
	if #list == 0 then return nil end
	local ok, b = pcall(L.DrawnBottom, list, root.AbsolutePosition.Y, currentScale())
	return ok and b or nil
end

function HUD.ChipsShown()
	if not (ui.chips and ui.chips.Visible) then return false end
	for _, c in ui.chips:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then return true end
	end
	return false
end

----------------------------------------------------------------- refresh: war meter
-- A23-198 (user 10/15: '0.02' cut in the bar's circle, "이것도 글자 씹힌다"): whole numbers only (the bar shows the
-- share), at most 4 characters so the circle never cuts them - 999, 1.2K, 12K, 1.2M (HUD.ScoreText, pure)
function HUD.ScoreText(v)
	v = math.max(0, math.floor(tonumber(v) or 0))
	if v < 1000 then return tostring(v) end
	local function short(n, unit)
		if n < 10 then
			local t = string.format("%.1f", math.floor(n * 10) / 10)
			return (string.gsub(t, "%.0$", "")) .. unit
		end
		return tostring(math.floor(n)) .. unit
	end
	if v < 1000000 then return short(v / 1000, "K") end
	return short(v / 1000000, "M")
end
local function fmtScore(v) return HUD.ScoreText(v) end


-- 검수 10/09: near 0 : all or all : 0 the crown ran past the bar's end; 상단 HUD 1안 ①: its image stays over the track
-- (half its width in from each end; the split line itself still shows the true share)
function L.WarCrownFrac(frac)
	local crown = ui.warCrown
	local bar = crown and crown.Parent
	if not bar or bar.AbsoluteSize.X < 1 then return frac end
	local half = crown.AbsoluteSize.X / 2 / bar.AbsoluteSize.X
	if half >= 0.5 then return 0.5 end
	return math.clamp(frac, half, 1 - half)
end
-- (pure) the war window's lines (Config.WarInfo.Text): the round's time left (or NoRound), "Halo 12 : 9 Horns" and
-- (최종 검수 10/15 #11, mine = my personal points this round, attribute WarPoints) "My points: 3" - only real whole points
function HUD.WarInfoLines(endsAt, now, halo, horns, mine)
	local W = type(Config.WarInfo) == "table" and Config.WarInfo.Text or {}
	local function side(f)
		local def = type(Config.Factions) == "table" and Config.Factions[f] or nil
		return type(def) == "table" and tostring(def.Name or f) or f
	end
	endsAt, now = tonumber(endsAt) or 0, tonumber(now) or 0
	local time = endsAt > now and L.Tx(W, "Time", Util.FormatTime(endsAt - now)) or W.NoRound or ""
	return time, L.Tx(W, "Score", side("Halo"), fmtScore(math.max(0, tonumber(halo) or 0)),
		fmtScore(math.max(0, tonumber(horns) or 0)), side("Horns")),
		L.Tx(W, "Mine", math.floor(math.max(0, tonumber(mine) or 0)))
end

-- 최종 검수 10/15 #11 (my small hunting share was not readable): Fx CrownPoint { N, Total } = whole personal points the
-- server really added (never a "+1" per monster) -> my side's badge on the war bar pops once (no number, no banner;
-- none with ReducedMotion)
function L.CrownPop(data)
	if type(data) ~= "table" or (tonumber(data.N) or 0) < 1 then return false end
	local f = getFaction()
	local badge = (f == "Halo" and ui.warBadgeHalo) or (f == "Horns" and ui.warBadgeHorns) or nil
	return L.BadgePop(badge)
end

-- one war-bar badge pops once (no number, no banner; none with ReducedMotion)
function L.BadgePop(badge)
	if not (badge and badge.Parent and ui.war and ui.war.Visible) or UIKit.ReducedMotion() then return false end
	local s = badge:FindFirstChild("CrownPop") or Instance.new("UIScale")
	s.Name = "CrownPop"
	s.Parent = badge
	local P = L.CrownPopCfg
	local up = TweenService:Create(s, TweenInfo.new(P.Up, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = P.Scale })
	up.Completed:Connect(function()
		TweenService:Create(s, TweenInfo.new(P.Down, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	up:Play()
	return true
end
L.CrownPopCfg = { Scale = 1.22, Up = 0.16, Down = 0.35 }

-- 상단 HUD 1안 ① (최종 검수 10/14: "막대 누르면 전쟁 창(시간·점수)"): the small war window - Panels' own parts and texts,
-- the words in Config.WarInfo; it redraws every second while open
function L.RegisterWarInfo()
	local P = C and C.Panels
	local W = Config.WarInfo
	if type(P) ~= "table" or type(P.Register) ~= "function" or type(W) ~= "table" or type(W.Text) ~= "table" then return false end
	L.WarInfoOn = P.Register(L.WarInfoId, {
		Title = function() return W.Text.Title end,
		Width = W.Width,
		Build = function(parent, k)
			local time = k.Text(parent, "", { Name = "Time", Size = 22, Align = Enum.TextXAlignment.Center, Color = k.Theme.Gold })
			local score = k.Text(parent, "", { Name = "Score", Size = 20, Align = Enum.TextXAlignment.Center })
			local mine = k.Text(parent, "", { Name = "Mine", Size = 18, Align = Enum.TextXAlignment.Center })
			local function draw()
				time.Text, score.Text, mine.Text = HUD.WarInfoLines(UIKit.GameAttr("WarRoundEndsAt", 0), Util.Now(),
					UIKit.GameAttr("WarHaloScore", 0), UIKit.GameAttr("WarHornsScore", 0), num("WarPoints", 0))
				mine.Visible = getFaction() == "Halo" or getFaction() == "Horns" -- the Guild never earns war points
			end
			draw()
			task.spawn(function()
				while time.Parent do
					task.wait(1)
					pcall(draw)
				end
			end)
		end,
	}) == true
	return L.WarInfoOn
end

-- the bar's two fills, split line and crown at a Halo share
function L.WarDraw(frac)
	ui.haloFill.Size = UDim2.fromScale(frac, 1)
	ui.hornsFill.Size = UDim2.fromScale(1 - frac, 1)
	ui.haloFill.Visible = frac > 0.001
	ui.hornsFill.Visible = frac < 0.999
	ui.warDivider.Position = UDim2.fromScale(frac, 0.5)
	L.WarCrownX = L.WarCrownFrac(frac)
	L.PlaceWarCrown()
end

-- A23-216 ⑤ (user 10/16, "진 쪽도 웃는 왕관전"): a round ended (the server's new WarRoundEndsAt after a round that was
-- played, WarMode not Idle) -> the bar slides from where the round left it back to balance (Back s), both sides' badges
-- pop once together, then the next round's short bell (Bell s after the end, after the winner's crown sound). No words,
-- no banner, nobody's screen darkens (A23-191). Captain Clatter's salute in the losing town waits for his town body.
L.RoundEnd = { Back = 0.9, Bell = 2.0, Sound = "WarNext" }

-- (pure) did a round end between two looks at the game state? old / new = { Ends, Mode }
function HUD.WarRoundEnded(old, new)
	if type(old) ~= "table" or type(new) ~= "table" then return false end
	local a, b = tonumber(old.Ends) or 0, tonumber(new.Ends) or 0
	return a > 0 and b > a + 1 and old.Mode ~= nil and old.Mode ~= "Idle"
end

function L.WarRoundEnd(fromFrac)
	local P = L.RoundEnd
	L.WarSliding = true
	local still = UIKit.ReducedMotion() or not (ui.war and ui.war.Visible)
	if not still then
		local v = Instance.new("NumberValue")
		v.Value = math.clamp(tonumber(fromFrac) or 0.5, 0, 1)
		v.Changed:Connect(function(f) pcall(L.WarDraw, f) end)
		local tw = TweenService:Create(v, TweenInfo.new(P.Back, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = 0.5 })
		tw.Completed:Connect(function() v:Destroy() end)
		tw:Play()
	end
	task.delay(still and 0 or P.Back, function()
		L.WarSliding = false
		pcall(L.WarDraw, 0.5)
		pcall(L.BadgePop, ui.warBadgeHalo)
		pcall(L.BadgePop, ui.warBadgeHorns)
	end)
	task.delay(P.Bell, function()
		if C and type(C.Audio) == "table" and type(C.Audio.Play) == "function" then pcall(C.Audio.Play, P.Sound) end
	end)
	return true
end

local function refreshWar()
	local h = math.max(0, tonumber(UIKit.GameAttr("WarHaloScore", 0)) or 0)
	local r = math.max(0, tonumber(UIKit.GameAttr("WarHornsScore", 0)) or 0)
	local frac = (h + r > 0) and (h / (h + r)) or 0.5
	local now = { Ends = UIKit.GameAttr("WarRoundEndsAt", 0), Mode = UIKit.GameAttr("WarMode", nil) }
	if HUD.WarRoundEnded(L.WarSeen, now) then
		L.WarRoundEnd(L.WarFracSeen or 0.5)
		L.WarFracSeen = nil
	elseif not L.WarSliding then
		L.WarDraw(frac)
	end
	L.WarSeen = now
	-- the share the round is ending at = the last one with points (the new round's 0 : 0 may arrive before its time)
	if h + r > 0 and not L.WarSliding then L.WarFracSeen = frac end
	ui.haloNum.Text = L.WarNumOnly and fmtScore(h) or L.Tx(TXT, "WarHalo", fmtScore(h))
	ui.hornsNum.Text = L.WarNumOnly and fmtScore(r) or L.Tx(TXT, "WarHorns", fmtScore(r))
	refreshChips()
end

----------------------------------------------------------------- refresh: MP skill
local function refreshSkill()
	local remaining = math.max(0, num("SkillReadyAt", 0) - Util.Now())
	local ready = remaining <= 0 and num("Mana", 0) >= Config.BasicSkill.ManaCost
	-- A23-60 (user 2026-10-06): no MP number on the button (the skill description says it); the button only dims
	ui.skillTimer.Visible = remaining > 0
	ui.skillTimer.Text = string.format("%.1f", remaining)
	if ui.releaseIcon then ui.releaseIcon.Visible = remaining <= 0 end
	if isImage(ui.releaseArt) then
		ui.releaseArt.ImageColor3 = ready and COL.White or COL.DimTint
	elseif ui.releaseArt then
		ui.releaseArt.BackgroundTransparency = ready and 0.05 or 0.35
	end
end

-- 최종 검수 10/13 (ref_rpg_ui #7): the Hero / Bag tiles' dot = an owned weapon I can wear that raises my power (never on
-- a locked tile)
function L.RefreshBetterDots()
	local cu = C and C.CharacterUI
	local better = false
	if type(cu) == "table" and type(cu.BetterWeapon) == "function" then
		local ok, b = pcall(cu.BetterWeapon)
		better = ok and b == true
	end
	for id, dot in ui.betterDots or {} do
		local on = better and not L.TileLocked(id)
		if dot.Visible ~= on then dot.Visible = on end
	end
end

-- plan 10/13 §1-A #5: [Menu] and its Gifts square glow while today's attendance gift waits (AttendanceUI.Ready: its
-- window is registered and AttendReady), after the first mission (the first steps keep the screen quiet)
function L.AttendGlow()
	local au = C and C.AttendanceUI
	if type(au) ~= "table" or type(au.Ready) ~= "function" then return false end
	if num("TutorialStep", 99) ~= ((type(TUT.Steps) == "table" and TUT.Steps.Done) or 99) then return false end
	local ok, on = pcall(au.Ready)
	return ok and on == true
end

-- B14: Panels.ItemsHint = I hold a scroll and have not opened 메뉴 → 아이템 this session
function L.ItemsHint()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.ItemsHint) ~= "function" then return false end
	local ok, hint = pcall(panels.ItemsHint)
	return ok and hint == true
end

-- A23-127 (게임성 개발 2, M1_1's scroll step): a quest row whose story step says Guide = "Bag" -> the Bag tile glows
-- until the step is done; its row tap opens the bag on L.BagGuideScroll (the scroll Otto gives at that step)
L.BagGuideScroll = "Enh70"
function L.BagGuide()
	for _, e in type(questState.Data) == "table" and questState.Data or {} do
		if type(e) == "table" and type(e.Story) == "table" and e.Story.Guide == "Bag" then return true end
	end
	return false
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

----------------------------------------------------------------- A23-68 the first minutes (user 2026-10-07)
-- #4 one goal at a time: until the first [Claim] (TutorialStep 0 / 3 Forge / 1 / 2, A23-74; QuestService.claimTutorial
-- writes 99 first)
-- the quest lines show the first mission only (parseQuests), the war bar's time number is hidden
-- (quality ⑨ minimum; the bar itself stays), EventHUD keeps its next-event line and the world banners wait
-- (UIKit.ShouldHoldBanners). The first [Claim] brings them in with a NEW! tag (UIKit.NewTag)
function L.RookieFold()
	local step = attr("TutorialStep", nil)
	local done = type(TUT.Steps) == "table" and tonumber(TUT.Steps.Done) or 99
	return type(step) == "number" and step >= 0 and step < done
end
HUD.RookieFold = L.RookieFold -- EventHUD reads the same rule

-- 검수 2026-10-09 (UI clutter review ③, "show it when it is needed"): the crown war bar first shows after the Forge
-- visit - hidden while the first mission is at its first fight or on the way to the Forge (TutorialStep Kill / Forge,
-- A23-74 order Kill -> Forge -> Guide -> Quest -> Done); no step yet (not loaded) or any later step = shown, so it
-- stays for good once it came. Pure: the offline test runs it.
function HUD.WarHidden(step, steps)
	if type(step) ~= "number" or type(steps) ~= "table" then return false end
	return step == tonumber(steps.Kill) or step == tonumber(steps.Forge)
end

-- changed = the TutorialStep attribute just changed (a fold that ends in this session pops the parts in)
function L.ApplyFold(changed)
	local hideWar = HUD.WarHidden(attr("TutorialStep", nil), TUT.Steps)
	if ui.war and ui.war.Visible == hideWar then
		ui.war.Visible = not hideWar
		-- A23-191 (user 10/14): no "Crown War" intro toast when it comes in
	end
	local fold = L.RookieFold()
	if changed and L.WasFolded == true and not fold and type(UIKit.NewTag) == "function" then
		-- 1안: no NEW! on the war bar (it stuck out over the Horns shield); the quest lines keep theirs
		task.delay(0.6, function() -- after the quest lines were rebuilt with the unfolded rows
			if ui.questLines and ui.questLines.Visible then pcall(UIKit.NewTag, ui.questLines) end
		end)
	end
	L.WasFolded = fold
end

-- A23-71: true while SkillBar keeps the slot's button off screen (before its unlock level); the layout then leaves it
-- out of its room checks (the potions keep their place on the thumb ring). A change of that button's Visible lays the
-- HUD out again (connected once)
function L.SkillHidden(slot)
	local bar = C and C.SkillBar
	if type(bar) ~= "table" or type(bar.Button) ~= "function" then return false end
	local ok, b = pcall(bar.Button, slot)
	if not ok or typeof(b) ~= "Instance" then return false end
	L.SkillWatch = L.SkillWatch or {}
	if not L.SkillWatch[slot] then
		L.SkillWatch[slot] = b:GetPropertyChangedSignal("Visible"):Connect(requestLayout)
	end
	return not b.Visible
end

-- 환생 ready / 휴가 days are 설정 rows now (A23-40 정정): [메뉴] and its 설정 square glow; the scroll hint (B14) glows 가방
-- A23-88 (검수 10/09): after the first weapon (the meadow step) [Menu] + Travel pulse until Travel was opened once
function HUD.TravelPulse(step, seen, on)
	return on ~= false and seen ~= true and step == TUT_GUIDE_STEP
end

local function refreshMenuGlow()
	local settings = num("Level", 1) >= Config.RebirthLevel(num("Rebirths", 0)) or num("VacationDays", 0) > 0
	local travel = HUD.TravelPulse(num("TutorialStep", 99), L.TravelSeen, (Config.Nudges or {}).TravelPulse)
	local attend = L.AttendGlow()
	-- user 10/13 first look (Gifts and [Menu] both ringed): [Menu] glows only while its fold is shut (it says "something
	-- inside"); once open, the square inside (Gifts / Travel / Settings) glows alone
	L.SetGlow("menu", ui.menuGlow, (settings or travel or attend) and ui.foldOpen ~= true)
	L.SetGlow("travel", ui.travelGlow, travel)
	L.SetGlow("attend", ui.attendGlow, attend)
	L.SetGlow("settings", ui.settingsGlow, settings)
	L.SetGlow("bag", ui.bagGlow, L.ItemsHint() or L.BagGuide())
	L.RefreshBetterDots()
end
L.RefreshMenuGlow = refreshMenuGlow -- L.SetFold (built earlier) redraws it on open / close

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
	ui.travelLabel.Text = L.Tx(TXT, "TravelLeft", textOr("Traveling", TXT.Traveling), remaining)
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

-- A23-94 (user 2026-10-09: one quest big at the left middle; 이미지 개발 draws it from line 1): the goal as one easy
-- sentence - the server's Goal when it sends one, else the row's words without their " · ..." tail, ending with a
-- full stop. Pure: tools/test_now_quest.py runs it
function HUD.QuestGoal(text, serverGoal)
	if type(serverGoal) == "string" and serverGoal ~= "" then return serverGoal end
	if type(text) ~= "string" or text == "" then return nil end
	local main = string.match(text, "^(.-)%s+·%s") or text
	main = string.gsub(main, "%s+$", "")
	if main == "" then return nil end
	-- 최종 검수 10/14 (Korean client: 'Go to Otto's Forge in the Crossroads.' stayed English): the table's Source is the
	-- sentence without the full stop - translate it first (UIKit.TrWord, by its English text), then add the stop
	if type(UIKit) == "table" and type(UIKit.TrWord) == "function" then
		local ok, out = pcall(UIKit.TrWord, main)
		if ok and type(out) == "string" and out ~= "" then main = out end
	end
	if not string.find(main, "[%.!%?。]$") then main ..= "." end
	return main
end

-- A23-94: which row is "the quest now" (line 1) when no row is pinned: the waiting story, else the main story, else a
-- row ready to [Claim], else the unfinished row closest to done (the larger share; the earlier row on a tie).
-- rows = { Progress, Target, CanClaim, Pinned, Kind, Story }; claimRule(e) = the 받기 rule. Pure (the offline test)
function HUD.NowQuestIndex(rows, callIndex, claimRule)
	if type(rows) ~= "table" or #rows == 0 then return nil end
	if rows[1].Pinned then return 1 end
	if callIndex and rows[callIndex] then return callIndex end
	for i, e in rows do
		local main = e.Kind == "Main" or (type(e.Story) == "table" and e.Story.Kind == "Main")
		if main and (e.Progress < e.Target or claimRule(e)) then return i end
	end
	for i, e in rows do
		if claimRule(e) then return i end
	end
	local best, bestShare = nil, -1
	for i, e in rows do
		if e.Progress < e.Target then
			local share = e.Progress / math.max(1, e.Target)
			if share > bestShare then best, bestShare = i, share end
		end
	end
	return best or 1
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
				Text = L.QuestText(L.EnglishQuestText(e, tostring(e.Text or ""))),
				Progress = math.max(0, finite(e.Progress, 0)),
				Target = math.max(1, finite(e.Target, 1)),
				RewardGold = math.max(0, finite(e.RewardGold, 0)),
				Pinned = isPinned,
				CanClaim = e.CanClaim ~= false,
				ShowProgress = e.ShowProgress ~= false,
				TutorialStep = finite(e.TutorialStep, -1),
				NextGoal = e.NextGoal == true,
				GoalKind = type(e.GoalKind) == "string" and e.GoalKind or nil, -- A23-48: which next goal (QuestTarget.IronGold)
				-- quest P1 ②: the first mission's guide / teacher (its NpcId): the row walks there, the talk opens the lines
				GuideNpc = (type(e.GuideNpc) == "string" and e.GuideNpc ~= "") and e.GuideNpc or nil,
				-- A23-221 ① (dev2-first12): the first mission's practice step = its dummy's Landmarks key (StoryNpcs draws the
				-- dummy there, QuestTarget points at it)
				GuideSpot = (type(e.GuideSpot) == "string" and e.GuideSpot ~= "") and e.GuideSpot or nil,
				Practice = e.Practice == true,
				Story = type(e.Story) == "table" and e.Story or nil, -- story rows: { Id, St, Panel, Guide }
				Unit = type(e.Unit) == "string" and e.Unit or nil, -- Kill/Golden quests: the monster kind (icon)
				-- review 2026-10-07: the server's short name (English, <= 14 letters, game dev 2) for the phone lines
				ShortName = L.EnglishShortName(e),
				-- dev2 2c5e84e: ShowProgress rows carry no "%d/%d" in Text; a seconds row says ProgressUnit = "s"
				ProgressUnit = (type(e.ProgressUnit) == "string" and #e.ProgressUnit > 0 and #e.ProgressUnit <= 3)
					and e.ProgressUnit or nil,
				Folded = e.Folded == true, -- A23-68 #4: the server folds every row but the first mission (dev2)
				-- 빛 마을 점검 #19 (dev3, Config.StoryQuests.SendAllSubs): a sub past MaxSubs - the quest window only
				More = e.More == true,
				Slot = (not isPinned) and slot or nil, -- N1: the client only ever sends Slot or "tutorial"
			}
			entry.Goal = HUD.QuestGoal(entry.Text, type(e.Goal) == "string" and L.QuestText(e.Goal) or nil) -- A23-94
			table.insert(isPinned and pinned or normal, entry)
		end
	end
	-- A23-68 #4 (user 2026-10-07 "한 번에 목표 하나"; replaces A23-3's step-0 fold and A23-2's early S0 line): until the
	-- first [Claim] only the first mission shows. The other rows (S0, dailies) keep progressing on the server, folded.
	-- One rule only (dev2 324055a): with Config.Tutorial.FoldOthers set the server's Folded flag on each row decides
	-- (false = no folding at all); without it (older servers) L.RookieFold (TutorialStep 0 / 3 / 1 / 2) decides here
	local fold = TUT.FoldOthers == nil and L.RookieFold()
	local shown = {}
	local now = Util.Now()
	for _, e in normal do
		if not (fold or e.Folded or L.NotNow(e, UIKit.GameAttr, now)) then table.insert(shown, e) end
	end
	local folded = #shown < #normal
	questState.Folded = folded
	for _, e in shown do
		table.insert(pinned, e)
	end
	return pinned
end

-- 최종 검수 10/14 (pure; tools/test_quest_not_now.py): a row you cannot do now (Config.QuestNotNow) - true = fold it.
-- gs(name, default) reads a GameState attribute (UIKit.GameAttr), now = the server clock
function L.NotNow(e, gs, now)
	local R = Config.QuestNotNow
	if type(R) ~= "table" or R.Enabled ~= true or type(e) ~= "table" or type(gs) ~= "function" then return false end
	local story = type(e.Story) == "table" and e.Story or nil
	if not story then return false end
	local window = tonumber(R.Window) or 3600
	now = tonumber(now) or 0
	if story.Guide == R.GooseGuide then
		if gs("GooseActive", false) == true then return false end
		local nextAt = tonumber(gs("GooseNextAt", 0)) or 0
		return not (nextAt > 0 and nextAt - now <= window)
	end
	if type(R.WarRows) == "table" and R.WarRows[story.Id] then
		if gs("WarMode", "Idle") == "Idle" then return true end
		local ends = tonumber(gs("WarRoundEndsAt", 0)) or 0
		return not (ends > 0 and ends - now <= window)
	end
	return false
end

-- the rows folded by L.NotNow right now ("" = none): the HUD redraws its lines when this changes (the clock passing)
function L.NotNowSig()
	local data = questState.Data
	if type(data) ~= "table" then return "" end
	local now, out = Util.Now(), {}
	for _, e in ipairs(data) do
		if type(e) == "table" and L.NotNow(e, UIKit.GameAttr, now) then table.insert(out, tostring(e.Id)) end
	end
	return table.concat(out, ",")
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
		payload = data -- a JSON payload is read like a table payload below
	end
	if type(payload) == "table" and type(payload.Quests) == "table" then
		-- { Quests = rows, Book = { Available, Done } } (A23-81: the quest window's lists, 게임성 개발 3), as a table or JSON
		if type(payload.Book) == "table" then questState.Book = payload.Book end
		questState.DailyLocked = payload.DailyLocked == true -- A23-104 (dev3): the daily jobs are not open yet
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
	if e.ProgressUnit then t = t .. " " .. e.ProgressUnit end -- '5/10 s'
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
	local row, isArt = UIKit.ArtFrame("ListRow", {
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
	r.Icon = UIKit.ArtImage("GlyphQuest", {
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
	local claim, claimLabel = UIKit.ArtButton("Chip", {
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
	-- 교체: small white chip (top-right)
	local reroll, rerollLabel = UIKit.ArtButton("Chip", {
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

-- the frame a quest line's glow goes round: its plate (the whole line), else its soft band - never the row itself
-- (a horizontal list: a glow inside it is one more item, 검수 10/09)
function L.LineGlowTarget(l)
	if type(l) ~= "table" then return nil end
	return l.Plate or l.Band
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
	local all = parseQuests()
	L.TrackDone(questState.All or questState.Rows, all) -- A23-81: the quest window's 'Done' this session
	-- 빛 마을 점검 #19: rows marked More (the subs past Config.StoryQuests.MaxSubs) are for the quest window only; the
	-- HUD lines and the list draw the rest (questState.All keeps every row for HUD.QuestEntries)
	-- B15: a story page waiting for a calm moment turns its row into "…말을 걸어요 — 눌러서 보기" (pulsing); 검수 10/10:
	-- its row stays on the HUD even when it is a More row (else nothing to tap / pulse)
	local call = L.StoryPending()
	local entries = {}
	for _, e in all do
		local waiting = call ~= nil and e.Story ~= nil and e.Story.Panel and e.Story.Id == call.Id
		if not e.More or waiting then table.insert(entries, e) end
	end
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
	if ui.questLines then ui.questLines.Visible = #entries > 0 and not ui.tracker end
	if ui.tracker and #entries == 0 then ui.tracker.Frame.Visible = false end
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
			if not firstClaim then firstClaim = i end
		elseif not done and e.Kind == "Daily" and not firstDaily then
			firstDaily = i
		end
	end
	-- 검수 10/10: the counts cover every row (the quest window's More rows too), so they match the window's tabs
	for _, e in all do
		if e.Progress >= e.Target and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub") then claimable += 1 end
	end
	-- 'now do' row: the pinned guide / next-goal row when there is one (검수 2026-10-06 (b): it always shows, phones too),
	-- else the waiting story, the first claimable, the first unfinished daily. Desktop shows one more row under it.
	-- round 3 #1 (ideas_first10 §3): after them the S0 shard story (it leads to auto combat) before the first daily,
	-- until auto combat is unlocked
	local s0 = nil
	if attr("AutoCombatUnlocked", false) ~= true then
		for i, e in entries do
			if e.Story and e.Story.Id == "S0" and e.Progress < e.Target then s0 = i break end
		end
	end
	local shown, second = nil, nil
	local pinAt = HUD.PinIndexes(entries, HUD.Pins()) -- §15 P1 ③
	if IS_TOUCH and pinAt[1] and not (entries[1] and entries[1].Pinned and entries[1].TutorialStep == 0) then
		shown = pinAt[1] -- a phone shows one line: my pin first
	elseif entries[1] and entries[1].Pinned then
		shown = 1
		second = callIndex or firstClaim or s0 or firstDaily
		if second == 1 then second = nil end
	elseif callIndex then
		shown = callIndex -- B15: the collapsed list shows the story that is waiting
	else
		-- A23-94: pinned > the waiting story > main > ready to claim > the unfinished row closest to done
		shown = HUD.NowQuestIndex(entries, nil, function(e)
			return e.Progress >= e.Target and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub")
		end) or 1
	end

	-- §15 P1 ③ (PC): my pins under the main line, never the line already shown, none without pins
	local tp = ui.tracker and ui.tracker.Pins
	if tp then
		local k = 0
		for _, i in pinAt do
			if i ~= shown and k < L.PinMax then
				k += 1
				local e = entries[i]
				local p, t = questNums(e)
				local words = (e.ShortName and e.ShortName ~= "") and e.ShortName or e.Text
				tp[k].Entry = e
				tp[k].Label.Text = e.ShowProgress and L.Tx(TXT, "QuestPinLine", words, p, t) or words
				tp[k].Label.Visible = true
			end
		end
		for j = k + 1, #tp do
			tp[j].Entry = nil
			tp[j].Label.Visible = false
		end
	end

	-- header: progress, claimable count (turns green so claiming stays 1-2 clicks), expand chevron
	local head = (claims >= slots) and TXT.QuestAllDone or L.Tx(TXT, IS_TOUCH and "QuestHeaderTouch" or "QuestHeader", claims, slots)
	if claimable > 0 then head ..= L.Tx(TXT, "QuestClaimable", claimable) end
	local hot = claimable > 0
	if IS_TOUCH then
		-- 검수 10/10 (API review ①): the phone's 'Claim N quests!' line and its gold count only the rows this block can
		-- show (entries); the quest window's More rows are claimed there
		local ready = 0
		for _, e in entries do
			if e.Progress >= e.Target and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub") then ready += 1 end
		end
		claimable, hot = ready, ready > 0
		-- U5 + A23-26: line 1 = what to do now (the pinned / next-goal row first), line 2 = the waiting story (one tap
		-- opens it: the header handler), else 받기 N, else today's count; tapping opens the overlay with the rows
		local se = entries[shown]
		questState.ShownEntry = se
		local line = head
		if se then
			local p, t = questNums(se) -- CR-M27 / CR-L31
			line = se.ShowProgress and L.Tx(TXT, "QuestTouchLine", p, t, se.Text) or se.Text
		end
		local sub = head
		if callIndex and entries[shown] ~= entries[callIndex] then
			sub = call.Label
		elseif callIndex then
			line = call.Label
		elseif hot and not (se and se.Pinned and se.CanClaim and se.Progress >= se.Target) then
			sub = Config.Plural(L.Tx(TXT, "QuestTouchClaim", claimable)) -- "1 quests" -> "1 quest"
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
		-- round 3 #1: before the first mission is accepted (step 0) the list has no daily header
		ui.questHeader.Visible = not (entries[1] and entries[1].Pinned and entries[1].TutorialStep == 0)
		ui.questChevron.Visible = #entries > 1
		ui.questChevron.Text = questExpanded and TXT.QuestCollapse or TXT.QuestExpand
	end
	paint(ui.questHeader, hot and COL.HotTint or COL.White, hot and Theme.Good or ac("Navy", Theme.Bg))

	-- A23-40 quest lines: line 1 = the 'now do' row, line 2 = the next one (the waiting story, a claimable, a daily),
	-- else today's count with 받기 N
	if ui.qline then
		-- A23-81 (user 2026-10-08 "진행 중인 것만, 최대 3줄, 메인 먼저"): line 1 = the 'now do' row, then the waiting
		-- story, a claimable, S0, the first daily, then the rest in the server's order (main, stories, jobs, dailies); a
		-- line with nothing in progress stays empty (no 'Daily Quests 0/3' filler; A23-68 #4: the first steps keep one goal)
		local order = L.QuestLineOrder(entries, shown, { callIndex, second, firstClaim, s0, firstDaily })
		for li, l in ui.qline do
			local i = order[li]
			local e = i and entries[i] or nil
			local label = e and ((i == callIndex and call) and call.Label or e.Text) or nil
			local nums = nil
			if e and e.ShowProgress then
				local p, t = questNums(e) -- CR-M27 / CR-L31
				nums = L.Tx(TXT, "QuestLineNums", p, t)
			end
			if li == 1 and not label then label = head end
			L.SetQuestLine(l, e, label, nums)
		end
		questState.ShownEntry = entries[shown]
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
			r.Icon.Image = head or UIKit.ArtId(QUEST_ICON[e.Id] or "GlyphQuest") or UIKit.ArtId("IconSlime") or r.Icon.Image
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
			if not IS_TOUCH and l.Entry == entries[callIndex] and l.Row.Visible then callTarget = L.LineGlowTarget(l) end
		end
		if not callTarget then callTarget = callRow and callRow.Frame or nil end
	end
	L.SetStoryPulse(callTarget)
	questState.Rows = entries -- HUD.QuestTarget (QuestMarker) reads the 'now do' row
	questState.All = all -- + the More rows (HUD.QuestEntries: the quest window)
	questState.Shown = shown
	refreshRerollTimers()
	pcall(function() HUD.QuestsChanged:Fire() end) -- A23-81: the quest window redraws
	-- CR-L36: the block's visibility also moves the war meter column's left edge
	if visibleBefore ~= visibleNow or blockWasVisible ~= ui.quests.Visible then
		requestLayout()
	end
end

-- desktop: expand / collapse the list; touch: open / close the overlay (open = nil toggles)
toggleQuests = function(open)
	-- A23-81: with the quest window (QuestBook, Panels "Journal") the list IS that window: Q, the ▼ button and a phone
	-- tap open / close it; without it the old fold-out list / overlay
	if L.HasQuestBook() then
		local ok = pcall(C.QuestBook.Toggle, open)
		if ok then return end
	end
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
	-- 빛 마을 점검 #52: a pad in the town I stand in that goes there (QuestTarget.TownPad) comes first
	local here = attr("ZoneId", "")
	local qt = C and C.QuestTarget
	if here ~= "Crossroads" and type(qt) == "table" and type(qt.TownPad) == "function" then
		local ok, townPad = pcall(qt.TownPad, here, zoneId)
		if ok and townPad then return townPad end
	end
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

function HUD.ClearGuide()
	guide = nil
end

local function showGuide(target, text, tag, seconds)
	local part = resolvePart(target)
	if not part then return false end
	HUD.ClearGuide()

	local g = { Tag = tag, Part = part }
	guide = g
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

-- 빛 마을 점검 #16 (2026-10-10): the Forge step's guide. From a zone that walks to the forge (QuestTarget K.SmithWalk:
-- the Crossroads, both towns, the outskirts) the anvil itself, else a trip to the Crossroads. Returns the target and
-- the guide's From key (one key for every walk zone: crossing a bridge keeps the same guide, no flicker)
L.ForgeWalk = { Crossroads = true, HaloTown = true, HornsTown = true, Outskirts = true }
function L.ForgeTarget(zone)
	local anvil = L.ForgeWalk[zone] and L.BlacksmithTarget() or nil
	if anvil then return anvil, "walk" end
	return findTravelTarget("Crossroads"), zone
end

-- the meadow beam from a faction town first points at that island's bridge (a straight line crossed the water);
-- from the Crossroads it points at the meadow pad
local HOME_BRIDGE = { HaloTown = "Bridge_Halo", HornsTown = "Bridge_Horns" }
function L.MeadowTarget(zone)
	local townPad = L.PadIn(zone)
	if townPad then return townPad end -- 빛 마을 점검 #52: the town's own meadow pad first
	local bridge = HOME_BRIDGE[zone]
	local map = workspace:FindFirstChild("Map")
	local decor = map and map:FindFirstChild("Decor")
	local part = bridge and decor and resolvePart(decor:FindFirstChild(bridge))
	return part or findTravelTarget(TUT_GUIDE_ZONE)
end

-- A23-88 (검수 10/09, user: no lines, no words): after the first weapon (TutorialStep Guide) the meadow travel pad in
-- the Crossroads glows softly by itself (a local Highlight on the pad, a slow breath); gone at the next step / away
function HUD.PadGlowOn(step, zone, on)
	return on ~= false and step == TUT_GUIDE_STEP and (zone == "Crossroads" or zone == "HaloTown" or zone == "HornsTown")
end

-- the meadow pad that glows in `zone`: the Crossroads' Pad_<meadow>, or (빛 마을 점검 #52) the town's own pad to the
-- meadow (QuestTarget.TownPad; none until the world tool places it)
function L.PadIn(zone)
	if zone == "Crossroads" then
		local map = workspace:FindFirstChild("Map")
		local pads = map and map:FindFirstChild("Pads")
		return resolvePart(pads and pads:FindFirstChild("Pad_" .. TUT_GUIDE_ZONE))
	end
	local qt = C and C.QuestTarget
	if type(qt) ~= "table" or type(qt.TownPad) ~= "function" then return nil end
	local ok, pad = pcall(qt.TownPad, zone, TUT_GUIDE_ZONE)
	return ok and pad or nil
end

L.PadGlowState = { Pad = nil, Light = nil, Tween = nil }
function L.PadGlow(on, zone)
	local st = L.PadGlowState
	local pad = on and L.PadIn(zone or "Crossroads") or nil
	if st.Pad == pad and (pad == nil or (st.Light and st.Light.Parent)) then return end
	if st.Tween then st.Tween:Cancel() end
	if st.Light then st.Light:Destroy() end
	st.Pad, st.Light, st.Tween = pad, nil, nil
	if not pad then return end
	local h = Instance.new("Highlight")
	h.Name = "HUDPadGlow"
	h.Adornee = pad
	h.FillColor = ac("Gold", Theme.Gold)
	h.FillTransparency = 0.85
	h.OutlineColor = ac("Gold", Theme.Gold)
	h.OutlineTransparency = 0.7
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = pad
	st.Light = h
	st.Tween = TweenService:Create(h, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ FillTransparency = 0.65, OutlineTransparency = 0.45 })
	st.Tween:Play()
end

-- step 1, or step 2 with kills left (e.g. died mid-mission and respawned in town): guide back to the meadow
function L.NeedsMeadowGuide(step)
	if step == TUT_GUIDE_STEP then return true end
	local quest = (type(TUT.Steps) == "table" and TUT.Steps.Quest) or 2
	return step == quest and num("TutorialKills", 0) < (tonumber(TUT.QuestKills) or 5)
end

-- A23-74 weapon first (dev2 dev2-weapon): after [Accept] the first goal is the Forge (TutorialStep Forge = 3), where
-- Otto hands over the first weapon at the anvil; then the meadow
L.ForgeStep = (type(TUT.Steps) == "table" and tonumber(TUT.Steps.Forge)) or 3

-- tutorial step 1: guide to the SlimeMeadow pad; cleared when the step changes or the player enters the zone.
-- The Forge step: the anvil inside the Crossroads, the Crossroads from anywhere else - decided by the step, never by
-- BlacksmithVisited (a visit before [Accept] already set it). Zone guides (Lv 10 / Lv 25) are cleared when the player
-- enters that zone.
local function refreshGuides()
	if attr("DataLoaded", false) ~= true then return end
	local step = num("TutorialStep", 99)
	local zone = attr("ZoneId", "")
	L.PadGlow(HUD.PadGlowOn(step, zone, (Config.Nudges or {}).PadGlow), zone)
	local forge = step == L.ForgeStep
	if guide then
		if guide.Tag == "forge" and (not forge or guide.From ~= select(2, L.ForgeTarget(zone))) then
			HUD.ClearGuide()
		elseif guide.Tag == "tutorial" and (not L.NeedsMeadowGuide(step) or zone == TUT_GUIDE_ZONE or guide.From ~= zone) then
			HUD.ClearGuide()
		elseif isZoneGuide(guide.Tag) and zone == string.sub(guide.Tag, 6) then
			HUD.ClearGuide()
		elseif guide.Tag == "blacksmith" and (attr("BlacksmithVisited", false) == true or zone ~= "Crossroads") then
			HUD.ClearGuide()
		elseif guide.Tag == "smith:manual" and zone ~= "Crossroads" then
			HUD.ClearGuide()
		end
	end
	if forge then
		if not (guide and guide.Tag == "forge") then
			local target, from = L.ForgeTarget(zone)
			if showGuide(target, TXT.ForgeGuide, "forge", nil) and guide then guide.From = from end
		end
	elseif L.NeedsMeadowGuide(step) and zone ~= TUT_GUIDE_ZONE and not (guide and guide.Tag == "tutorial") then
		if showGuide(L.MeadowTarget(zone), TUT_GUIDE_TEXT, "tutorial", nil) and guide then guide.From = zone end
	elseif step == 99 and attr("BlacksmithVisited", false) ~= true and zone == "Crossroads"
		and not (guide and guide.Tag == "blacksmith") then
		showGuide(L.BlacksmithTarget(), TXT.SmithGuide, "blacksmith", nil)
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
		showGuide(findTravelTarget(targetZone), L.Tx(TXT, "ZoneGuide", name), "zone:" .. targetZone, GUIDE_SECONDS)
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
	L.SwingFaced()
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
		-- 최종 검수 10/15 (feedback_audit #1; A23-180 no shake, no sound at a skill gate): the MP bar flashes red - the why
		if not throttled("skillMana", 1.5) then
			UIKit.Refuse(ui.stats and ui.stats:FindFirstChild("MPBar", true) or nil, { Shake = false, Sound = false })
		end
		return
	end
	local turned, target = L.FaceTarget("Release") -- the skill waits for the turn (TurnTime)
	if turned then
		task.delay(tonumber(Config.AutoFace and Config.AutoFace.TurnTime) or 0.08, function() fire("Release", target) end)
	else
		fire("Release", target)
	end
end

-- A23-34 (검수 2026-10-06): the forge window opens only through the server's anvil prompt, which records the visit
-- (M1_1) and hands the first weapon over before the shop shows. Near the anvil the prompt is pressed for me; farther
-- away the guide beam shows the way (no shop).
L.Smith = { Prompt = "HHC_BlacksmithPrompt", Reach = 12,
	Travel = "The Forge is in the Crossroads.", Guide = "Forge", -- A23-130: shorter
	Walk = "Walk to the Forge anvil." }

function L.PressAnvil()
	local anvil = L.BlacksmithTarget()
	local guild = anvil and anvil.Parent
	local prompt = guild and guild:FindFirstChild(L.Smith.Prompt, true)
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
	local holder = prompt.Parent
	local pos = holder and ((holder:IsA("BasePart") and holder.Position) or (holder:IsA("Attachment") and holder.WorldPosition))
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not pos or not root then return false end
	if (root.Position - pos).Magnitude > math.min(L.Smith.Reach, prompt.MaxActivationDistance) then return false end
	local ok = pcall(function() prompt:InputHoldBegin() end)
	task.delay(0.05, function() pcall(function() prompt:InputHoldEnd() end) end)
	return ok
end

doUpgrade = function()
	if throttled("upgrade", 0.35) then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return end
	if attr("ZoneId", "") ~= "Crossroads" then
		panels.Open("Travel") -- A23-191: no toast
		return
	end
	if L.PressAnvil() then return end
	showGuide(L.BlacksmithTarget(), L.Smith.Guide, "smith:manual", 30) -- A23-191: no toast
end

-- A23-91 보강 (user 2026-10-09 "공격할 때 몬스터 쪽으로 몸 돌리기 … 조금 더 세세하게"; numbers Config.AutoFace):
-- which monster my attack turns me to. cands = { { Key, D (flat studs), Range, Front (inside the attack's AimCone), Dot
-- (my look . dir), CamDot (camera look . dir), Attacker (bool) } }; current = the kept target's Key, keep = my last
-- attack was within KeepFor s. cfg.Score false = the server's own aim (CombatService.Swing, A23-61): the nearest inside
-- the front half, else the nearest within Range, so the turn, the ring and the hit agree. cfg.Score true
-- (Config.AutoFace.ServerHint: the server takes my pick): the kept target while it lives within Range, else the best
-- score among those within Inside x Range that are not behind me farther than BackNear. Pure: tools/test_auto_face.py
-- runs it. Returns the Key or nil
function HUD.PickTarget(cands, current, keep, cfg)
	if not cfg.Score then
		local front, frontD, near, nearD = nil, math.huge, nil, math.huge
		for _, c in cands do
			if c.D <= c.Range then
				if c.Front and c.D < frontD then front, frontD = c.Key, c.D end
				if c.D < nearD then near, nearD = c.Key, c.D end
			end
		end
		return front or near
	end
	if keep and current ~= nil then
		for _, c in cands do
			if c.Key == current and c.D <= c.Range then return current end -- the same target while I keep attacking
		end
	end
	local best, bestScore = nil, -math.huge
	for _, c in cands do
		if c.D <= c.Range * cfg.Inside and not (c.Dot < cfg.BackDot and c.D > cfg.BackNear) then
			local score = cfg.WDist * (1 - c.D / math.max(1, c.Range)) + cfg.WFront * math.max(0, c.Dot)
				+ cfg.WScreen * math.max(0, c.CamDot) + (c.Attacker and cfg.WAttacker or 0)
			if score > bestScore then best, bestScore = c.Key, score end
		end
	end
	return best
end

L.AIM = { Target = nil, LastAttack = -math.huge, Turn = nil, Hold = nil, Ring = nil, RingConn = nil, RingFor = nil }

-- 최종 검수 10/15 #1 (why it failed, at the spot): my attack had nothing in reach - the nearest monster just out of reach
-- (within FarK x the range) gets a soft outline for FarShow s (once per FarGap s); no words, no sound
function L.AIM.TooFar(model)
	local A = Config.AutoFace or {}
	if typeof(model) ~= "Instance" or os.clock() - (L.AIM.FarAt or -math.huge) < (tonumber(A.FarGap) or 0.8) then return false end
	L.AIM.FarAt = os.clock()
	local h = model:FindFirstChild("HH_TooFar")
	if not h then
		h = Instance.new("Highlight")
		h.Name = "HH_TooFar"
		h.FillTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	end
	h.OutlineColor = A.RingColor or Color3.fromRGB(255, 236, 170)
	h.OutlineTransparency = 0.1
	h.Enabled = true
	local at = L.AIM.FarAt
	task.delay(tonumber(A.FarShow) or 0.7, function()
		if L.AIM.FarAt == at and h.Parent then h.Enabled = false end
	end)
	return true
end

-- the small ring under my target while I attack: the approved soft round FxShockRing art tinted RingColor (no rays;
-- code fallback a flat disc), RingPad x the body's width within RingSize..RingMax studs, on the floor (RootHeight).
-- Hidden when the target dies or hides (an ambusher), or RingShow s after my last attack
function L.AIM.ShowRing()
	local A = Config.AutoFace or {}
	local ring = L.AIM.Ring
	if not ring then
		ring = Instance.new("Part")
		ring.Name = "HUDTargetRing"
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material = Enum.Material.SmoothPlastic
		ring.Color = typeof(A.RingColor) == "Color3" and A.RingColor or Color3.new(1, 1, 1)
		local okArt, art = pcall(UIKit.ArtId, "FxShockRing")
		if okArt and type(art) == "string" and art ~= "" then
			ring.Transparency = 1
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Top
			sg.LightInfluence = 0
			sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			sg.CanvasSize = Vector2.new(256, 256)
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = art
			img.ImageColor3 = ring.Color
			img.ImageTransparency = tonumber(A.RingTransparency) or 0.2
			img.Parent = sg
			sg.Parent = ring
		else
			ring.Shape = Enum.PartType.Cylinder
			ring.Transparency = math.max(0.45, tonumber(A.RingTransparency) or 0.2)
		end
		L.AIM.Ring = ring
	end
	ring.Parent = workspace
	if L.AIM.RingConn then return end
	L.AIM.RingConn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = L.AIM.Target
		local m = t and t.Parent
		local mh = m and m:FindFirstChildOfClass("Humanoid")
		if not m or (mh and mh.Health <= 0) or m:GetAttribute("Hidden") == true
			or os.clock() - L.AIM.LastAttack >= (tonumber(A.RingShow) or 1.5) then
			ring.Parent = nil
			L.AIM.RingFor = nil
			L.AIM.RingConn:Disconnect()
			L.AIM.RingConn = nil
			return
		end
		if L.AIM.RingFor ~= t then -- a new target: size to its body
			L.AIM.RingFor = t
			local okSize, ext = pcall(function() return m:GetExtentsSize() end)
			local width = okSize and math.max(ext.X, ext.Z) or t.Size.X
			local d = math.clamp(width * (tonumber(A.RingPad) or 1.1), tonumber(A.RingSize) or 3.2, tonumber(A.RingMax) or 12)
			ring.Size = ring.Shape == Enum.PartType.Cylinder and Vector3.new(0.12, d, d) or Vector3.new(d, 0.05, d)
		end
		local up = tonumber(m:GetAttribute("RootHeight")) or (t.Size.Y / 2 + (mh and mh.HipHeight or 0))
		local at = CFrame.new(t.Position.X, t.Position.Y - up + 0.1, t.Position.Z)
		ring.CFrame = ring.Shape == Enum.PartType.Cylinder and at * CFrame.Angles(0, 0, math.pi / 2) or at
	end)
end

-- turn my body to `pos` over TurnTime s with an ease-out (skipped within SkipDeg of where I face); while I walk the
-- Humanoid's AutoRotate waits TurnTime + SwingHold s (the body stays on the target, then walks on). True = it turns
function L.AIM.TurnTo(root, hum, pos)
	local A = Config.AutoFace or {}
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local dir = (pos - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1 or look.Magnitude < 0.01 then return false end
	local from = math.atan2(-look.X, -look.Z)
	local to = math.atan2(-dir.X, -dir.Z)
	local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
	if math.abs(delta) < math.rad(tonumber(A.SkipDeg) or 10) then return false end
	if L.AIM.Turn then L.AIM.Turn:Disconnect() end
	local dur = math.max(0.01, tonumber(A.TurnTime) or 0.08)
	if hum.MoveDirection.Magnitude > 0.1 then
		hum.AutoRotate = false
		local token = {}
		L.AIM.Hold = token
		task.delay(dur + (tonumber(A.SwingHold) or 0.35), function()
			if L.AIM.Hold == token and hum.Parent then hum.AutoRotate = true end
		end)
	end
	local start = os.clock()
	L.AIM.Turn = game:GetService("RunService").RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - start) / dur, 0, 1)
		k = 1 - (1 - k) * (1 - k) -- ease out
		if root.Parent then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, from + delta * k, 0)
		end
		if k >= 1 then
			L.AIM.Turn:Disconnect()
			L.AIM.Turn = nil
		end
	end)
	return true
end

-- my attack: pick the monster (HUD.PickTarget) and turn to it smoothly. Returns (turned, the monster Model or nil); the
-- Model goes to the server with the Swing / Release (ignored until CombatService takes it - Config.AutoFace.ServerHint).
-- Monsters only: never another player; skips hidden ambushers and monsters that belong to someone else. Shift lock keeps
-- its own facing (the camera turns the body). A23-34: the basic attack ("Swing") uses Config.AttackProfile (its Range
-- and AimCone, bare hands = 7 studs); skill Q ("Release") keeps the class row. which = nil: the auto-combat facing while
-- I stand (always the server's aim, no ring; it waits while my own attacks keep a target)
function L.FaceTarget(which)
	local def = which == "Swing" and Config.AttackProfile(getClass(), math.floor(num("WeaponTier", 0)), getFaction())
		or Config.Classes[getClass()]
	if type(def) ~= "table" or type(def.AimCone) ~= "number" then return false end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return false end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local folder = workspace:FindFirstChild("Monsters")
	if not root or not hum or hum.Health <= 0 or not folder then return false end
	local A = Config.AutoFace or {}
	local manual = which ~= nil
	local now = os.clock()
	local keep = now - L.AIM.LastAttack < (tonumber(A.KeepFor) or 1.5)
	if not manual and keep then return false end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local cam = workspace.CurrentCamera
	local camLook = cam and cam.CFrame.LookVector * Vector3.new(1, 0, 1) or look
	camLook = camLook.Magnitude > 0.01 and camLook.Unit or look
	local range = tonumber(def.Range) or 30
	local frontDot = def.AimCone >= 180 and -2 or math.cos(math.rad(def.AimCone)) -- CombatService.inAim
	local serverNow, me = Util.Now(), LocalPlayer.UserId
	local attackerFor, attackerReach = tonumber(A.AttackerFor) or 2, tonumber(A.AttackerReach) or 9
	local cands = {}
	local far, farD = nil, range * (tonumber(A.FarK) or 2) -- 최종 검수 10/15 #1: the nearest one just out of reach
	for _, m in folder:GetChildren() do
		local r = m:FindFirstChild("HumanoidRootPart")
		local mh = m:FindFirstChildOfClass("Humanoid")
		local owner = m:GetAttribute("OwnerUserId")
		if r and r:IsA("BasePart") and not r.Anchored and (not mh or mh.Health > 0) and m:GetAttribute("Hidden") ~= true
			and (owner == nil or owner == me) then
			local dir = (r.Position - root.Position) * Vector3.new(1, 0, 1)
			local d = dir.Magnitude
			if d <= range then
				local u = d > 0.01 and dir.Unit or look
				local dot = look:Dot(u)
				local windup = tonumber(m:GetAttribute("WindupAt")) or -math.huge
				table.insert(cands, { Key = r, D = d, Range = range, Front = d < 1 or dot >= frontDot, Dot = dot,
					CamDot = camLook:Dot(u), Attacker = serverNow - windup < attackerFor and d <= attackerReach })
			elseif d < farD then
				far, farD = m, d
			end
		end
	end
	local cfg = { Score = manual and A.ServerHint == true, Inside = tonumber(A.Inside) or 0.95,
		BackDot = tonumber(A.BackDot) or -0.2, BackNear = tonumber(A.BackNear) or 6, WDist = tonumber(A.WDist) or 1,
		WFront = tonumber(A.WFront) or 0.8, WScreen = tonumber(A.WScreen) or 0.5, WAttacker = tonumber(A.WAttacker) or 1.5 }
	local best = HUD.PickTarget(cands, L.AIM.Target, keep, cfg)
	if manual then
		L.AIM.LastAttack = now
		L.AIM.Target = best
		if best then L.AIM.ShowRing() elseif far then L.AIM.TooFar(far) end
	end
	if not best then return false end
	return L.AIM.TurnTo(root, hum, best.Position), best.Parent
end

-- one Swing for one press (F key, attack button or a world click, A23-51; review 2026-10-06: the click skipped this):
-- turn to my target (L.FaceTarget) and swing at once with it: the server aims the same way itself (dev2 bd3d6bd: no
-- target in the front half -> the nearest monster in Range, and it turns my root), so it never waits for my turn to
-- replicate (0.27-0.43 s in Studio, measured 2026-10-07)
function L.SwingFaced()
	local _, target = L.FaceTarget("Swing")
	-- 손맛 ① (최종 검수 10/16): my body starts the swing now (Fx.PredictSwing; the server's Fx does not restart it)
	local fx = C and C.Fx
	if type(fx) == "table" and type(fx.PredictSwing) == "function" then pcall(fx.PredictSwing) end
	fire("Swing", target)
end

-- story rows: a talk / choice step reopens its dialogue; otherwise travel + the guide beam to where it happens
-- = Config.StoryQuests.Landmarks.SlimePond, 3 studs up (QuestTarget pondSpot; tools/test_map_v2.py keeps them equal)
local STORY_SPOT = { SlimePond = Vector3.new(290, 3, 150) }
-- the way to a story NPC's body (QuestTarget.StoryNpc): from another zone the Travel window + the zone guide, a walk away
-- the guide to the NPC itself; false = no body in the world
function L.NpcWalk(id, zone, panels)
	local qt = C and C.QuestTarget
	local npc = type(id) == "string" and type(qt) == "table" and type(qt.StoryNpc) == "function" and qt.StoryNpc(id) or nil
	if not npc then return false end
	local npcZone = Config.ZoneAt(npc.Position).Id
	local name = Config.StoryQuests.Speakers and Config.StoryQuests.Speakers[id] or id
	if npcZone ~= zone and not (L.ForgeWalk[zone] and L.ForgeWalk[npcZone]) then
		if panels and panels.Open then panels.Open("Travel") end
		showGuide(findTravelTarget(npcZone), tostring(name), "zone:" .. npcZone, 30)
	else
		showGuide(npc, tostring(name), "story", 30)
	end
	return true
end

-- A23-221 ①: a row whose place is a spot (the practice dummy): QuestTarget.ForEntry's place (a trip from another zone
-- opens Travel); false = no place
function L.SpotWalk(e, zone, panels)
	local qt = C and C.QuestTarget
	if type(qt) ~= "table" or type(qt.ForEntry) ~= "function" then return false end
	local ok, r = pcall(qt.ForEntry, e, zone)
	if not ok or type(r) ~= "table" then return false end
	if r.Travel and panels and panels.Open then panels.Open("Travel") end
	local target = r.Part or localAnchor(tostring(r.Tag), r.Position)
	return showGuide(target, tostring(r.Label or ""), tostring(r.Tag), 30)
end

function L.StoryTap(st, zone, panels)
	-- 개발 2 dev2-offer-row: "Talk to <asker>" (Story.Offer) = the way to her; her prompt opens the request
	if st.Offer == true then
		L.NpcWalk(st.Npc, zone, panels)
		return
	end
	if st.Panel then
		-- 빛 마을 점검 #1 / #30: a talk through a town NPC that stands in the world: far from her the tap guides there
		-- (the Travel window + the guide from another zone, the guide to her a walk away); near (Config.StoryQuests
		-- NpcRange) the page opens as before
		local qt = C and C.QuestTarget
		local npc = type(st.Npc) == "string" and type(qt) == "table" and type(qt.StoryNpc) == "function" and qt.StoryNpc(st.Npc) or nil
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if npc and root and Util.FlatDistance(root.Position, npc.Position) > (tonumber(Config.StoryQuests.NpcRange) or 16) then
			L.NpcWalk(st.Npc, zone, panels)
			return
		end
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
	-- A23-110 (dev3 KO1): "Buy a potion" -> the way to the potion seller; the quick slot steps -> the bag (its Quick slots)
	-- A23-127 (게임성 개발 2, M1_1 "Use the Enhance Scroll on your weapon"): Guide "Bag" -> the bag straight on the scroll's
	-- step for the weapon in my hand (BagUI drops back to the list when I hold no such scroll)
	if g == "PotionShop" or g == "QuickSlot" or g == "Bag" then
		local vitals = C and C.VitalsUI
		if g == "Bag" then
			if panels and panels.Open then
				panels.Open("Bag", { Use = L.BagGuideScroll, Tier = math.floor(num("WeaponTier", 1)) })
			end
		elseif g == "QuickSlot" then
			-- H-1: the bag on its Use tab (the potion picked, its quick slot buttons right there); the old list until then
			local bag = panels and type(panels.Has) == "function" and panels.Has("Bag")
			if panels and panels.Open then panels.Open(bag and "Bag" or "Items", bag and { Tab = "Use" } or nil) end
		elseif type(vitals) == "table" and type(vitals.ShowShopWay) == "function" then
			pcall(vitals.ShowShopWay)
		end
		return
	end
	-- 개발 2 ④ 10/14: the goose plays in the Goose Square (A23-141), never in the Crossroads - the goose chip with its Join
	-- button glows round instead of a trip (nothing when the chip is not on the screen)
	if g == "Goose" then
		local ev = C and C.EventHUD
		if type(ev) == "table" and type(ev.PulseGooseChip) == "function" then pcall(ev.PulseGooseChip) end
		return
	end
	local target = g
	if g == "OwnTown" then target = Config.HomeZoneId(getFaction()) end
	if g == "SlimePond" then target = "SlimeMeadow" end
	if g == "Fountain" then target = "Crossroads" end
	-- 빛 마을 점검 #17 / #21 / #29: a Config.StoryQuests.Landmarks spot (HeroStatue, WoodsGate, GoblinCamp1, ...): its
	-- zone (Config.ZoneAt), then the spot itself (QuestTarget.Story does the same for the marker)
	local lms = Config.StoryQuests and Config.StoryQuests.Landmarks
	-- (dev2-halo / 검수 10/10: the server's rule - a StoryLandmark-tagged Spot wins over the Config spot)
	local spot = not Config.Zones[target] and type(lms) == "table" and type(g) == "string"
		and (Util.TaggedSpot(Config.StoryQuests.LandmarkTag, g) or lms[g]) or nil
	if typeof(spot) ~= "Vector3" then spot = nil end
	if spot then target = Config.ZoneAt(spot).Id end
	-- 검수 10/10: a landmark a walk away (both zones walk to each other: L.ForgeWalk) -> straight to the spot, no trip
	local walkTo = spot ~= nil and L.ForgeWalk[zone] == true and L.ForgeWalk[target] == true
	if Config.Zones[target] and zone ~= target and not walkTo then
		if panels and panels.Open then panels.Open("Travel") end
		if target == TUT_GUIDE_ZONE then
			if showGuide(L.MeadowTarget(zone), TUT_GUIDE_TEXT, "zone:" .. target, 30) and guide then guide.From = zone end
		else
			showGuide(findTravelTarget(target), tostring(Config.Zones[target].Name), "zone:" .. target, 30)
		end
		return
	end
	if spot then
		local a = Instance.new("Part")
		a.Name, a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = "HUDStoryAnchor", true, false, false, false, 1
		a.Size, a.Position, a.Parent = Vector3.new(1, 1, 1), spot + Vector3.new(0, 3, 0), workspace
		game:GetService("Debris"):AddItem(a, 35)
		showGuide(a, tostring(Config.Zones[target] and Config.Zones[target].Name or g), "story", 30)
		return
	end
	if g == "SlimePond" then
		local a = Instance.new("Part")
		a.Name, a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = "HUDStoryAnchor", true, false, false, false, 1
		a.Size, a.Position, a.Parent = Vector3.new(1, 1, 1), STORY_SPOT.SlimePond, workspace
		game:GetService("Debris"):AddItem(a, 35)
		showGuide(a, TXT.Pond, "story", 30)
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
		if part then showGuide(part, type(name) == "string" and name or TXT.Fountain, "story", 30) end
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
	if ui.autoGlow then ui.autoGlow.Transparency = on and 0 or 1 end
	paint(ui.autoArt, on and COL.White or COL.DimTint, on and COL.ReleaseFill or COL.Grey)
end

-- the first mission is done (5/5) and waits for [받기]
function L.ClaimableMission(e)
	local questStep = (type(TUT.Steps) == "table" and TUT.Steps.Quest) or 2
	return type(e) == "table" and not e.Story and e.Pinned == true and e.TutorialStep == questStep and e.CanClaim == true
		and e.Progress >= e.Target
end

-- tapping the pinned guide row: step 0 guide dialogue, the Forge step (A23-74) back to the anvil, step 1/2 travel to the
-- meadow, blacksmith step and the iron-weapon goal -> the existing doUpgrade path, level goals -> the existing beam to
-- the hunting ground.
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
	-- A23-221 ①: "Hit the practice dummy" - the tap shows the way to the dummy (QuestTarget's place)
	if e.Practice and e.GuideSpot and L.SpotWalk(e, zone, panels) then return end
	-- quest P1 ②: "Talk to Hallie" / "Meet Sir Gleam at the town gate" - the tap only shows the way (the talk opens it)
	if e.GuideNpc and L.NpcWalk(e.GuideNpc, zone, panels) then return end
	-- quest P1 ⑤ / A23-193: "Take Sir Gleam's test" / "Learn a skill" -> the way to my side's teacher
	if step == 99 and e.NextGoal and (e.GoalKind == "SkillTest" or e.GoalKind == "SkillLearn")
		and L.NpcWalk(attr("SkillTeacher", ""), zone, panels) then
		return
	end
	if step == 0 then
		fire("RequestTutorial")
	elseif step == L.ForgeStep then
		-- 빛 마을 점검 #20 (2026-10-10): since A23-88 I walk to the forge myself (the server ignores a tutorial request after
		-- the welcome, so none is sent): the guide comes back and the quest marker pops once over the forge - the tap
		-- shows where to go without a word
		HUD.ClearGuide()
		refreshGuides()
		local qm = C and C.QuestMarker
		if type(qm) == "table" and type(qm.Pulse) == "function" then pcall(qm.Pulse) end
	elseif step == 1 or step == 2 then
		if zone ~= TUT_GUIDE_ZONE then
			if panels and panels.Open then panels.Open("Travel") end
			if showGuide(L.MeadowTarget(zone), TUT_GUIDE_TEXT, "tutorial", nil) and guide then guide.From = zone end
		end
	elseif step == 99 then
		local level = math.floor(num("Level", 1))
		-- the iron-weapon gold goal goes to the anvil (QuestTarget.IronGold: never while the Forge sells no weapon,
		-- A23-127 - the drop goal travels to the meadow like a level goal)
		local qt = C and C.QuestTarget
		local ironGold = type(qt) == "table" and type(qt.IronGold) == "function" and qt.IronGold(e, level) == true
		if not e.NextGoal or ironGold then
			doUpgrade()
		elseif zone ~= TUT_GUIDE_ZONE then
			showGuide(findTravelTarget(TUT_GUIDE_ZONE), TUT_GUIDE_TEXT, "zone:" .. TUT_GUIDE_ZONE, 30)
		else
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
-- A23-79 #3: the [Invite] square shows while Invite.CanShow() says so
function L.InviteOk()
	local inv = C and C.Invite
	if type(inv) ~= "table" or type(inv.CanShow) ~= "function" then return false end
	local ok, can = pcall(inv.CanShow)
	return ok and can == true
end

function L.TileWindow(def)
	local panels = C and C.Panels
	local has = type(panels) == "table" and type(panels.Has) == "function" and panels.Has or nil
	if not has then return nil end
	-- A23-182: the Travel square only for a Fast Travel subscriber (Panels.TravelOn: SubFastTravel)
	if def.Window == "Travel" and not (type(panels.TravelOn) == "function" and panels.TravelOn() == true) then return nil end
	if def.Window and has(def.Window) == true then return def.Window end
	if def.Alt and has(def.Alt) == true then return def.Alt end
	return nil
end

-- a tile press: 지도 = the world map toggle, window tiles open their window (the same tile closes it; another window
-- switches)
function L.TileTap(def)
	if L.TileLocked(def.Id) then
		L.TileWiggle(def.Id) -- A23-113 ③: locked = a small wiggle only (no window, no notice)
		return
	end
	if def.Invite then
		local inv = C and C.Invite
		if type(inv) == "table" and type(inv.Prompt) == "function" then task.spawn(inv.Prompt, "Menu") end
		return
	end
	if def.Map then
		local wm = C and C.WorldMap
		local mapOpen = type(wm) == "table" and type(wm.IsOpen) == "function" and wm.IsOpen()
		if mapOpen or inputAllowed() then openMap() end
		return
	end
	local panels = C and C.Panels
	local target = L.TileWindow(def)
	if not target then
		-- a row tile whose window is not built yet: 랭킹 opens the ranking list (the Tab list), the rest say it is coming
		if throttled("tileSoon", 0.6) then return end
		local list = C and C.PlayerListUI
		if def.Id == "Ranking" and type(list) == "table" and type(list.Toggle) == "function" then
			local ok, err = pcall(list.Toggle)
			if not ok then warnThrottled("ranking list failed: " .. tostring(err)) end
		else
		end
		return
	end
	if type(panels) ~= "table" then return end
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
-- (not registered in Panels) answers like its tile (L.WindowSoon). The menu key keeps U1: it closes any open window,
-- else opens the menu.
-- Returns true when the action was one of these keys.
-- User 2026-10-08 (MMO keys): a window key whose window is not built yet answers like its HUD tile (Hero / Skills:
-- 'coming soon', Ranking: the ranking list); the quest list key folds the HUD quest rows out until a journal exists
function L.WindowSoon(action)
	if action == "Journal" then
		if inputAllowed() and not throttled("questKey", 0.25) then toggleQuests() end
		return
	end
	for _, def in L.Tiles do
		if def.Key == action then
			L.TileTap(def)
			return
		end
	end
end

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
	if type(panels.Has) ~= "function" or not panels.Has(target) then
		L.WindowSoon(action)
		return true
	end
	-- A23-113 ③: a key whose menu tile is still locked (K before the first skill) only wiggles that tile, like a press
	for _, def in L.Tiles do
		if def.Key == action and L.TileLocked(def.Id) then
			L.TileWiggle(def.Id)
			return true
		end
	end
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
	elseif action == "SkillQ" or action == "SkillZ" or action == "SkillX" then
		-- E stays the Roblox interact key (blacksmith / altar / merchant prompts). A23-49: SkillBar owns Q · Z · X
		local bar = C and C.SkillBar
		local slot = string.sub(action, -1)
		if type(bar) == "table" and type(bar.Owns) == "function" and bar.Owns(slot) then
			bar.Use(slot)
		elseif action == "SkillQ" then
			doRelease()
		end
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

-- 최종 검수 10/15 (the textbook: "폰 버튼 터치 범위 넓게"): a phone thumb that lands just off the attack disc still
-- attacks - within Slack x its radius of its centre, on no other button (the touch reached the world: gameProcessed
-- false), so the ring buttons around it keep their own taps
L.NearMiss = { Slack = 1.3 }

-- (pure) is a screen point within slack x the radius of a round button (its absolute rect)?
function HUD.NearMiss(absPos, absSize, point, slack)
	if typeof(absPos) ~= "Vector2" or typeof(absSize) ~= "Vector2" or typeof(point) ~= "Vector2" and typeof(point) ~= "Vector3" then
		return false
	end
	local r = math.min(absSize.X, absSize.Y) / 2
	if r <= 0 then return false end
	local cx, cy = absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2
	return math.sqrt((point.X - cx) ^ 2 + (point.Y - cy) ^ 2) <= r * (tonumber(slack) or 1)
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
	UserInputService.TouchStarted:Connect(function(input, gameProcessed)
		if gameProcessed or not ui.attack or not ui.attack.Visible or not inputAllowed() then return end
		if not HUD.NearMiss(ui.attack.AbsolutePosition, ui.attack.AbsoluteSize, input.Position, L.NearMiss.Slack) then return end
		startHold(input) -- its end: onInputEnded (Touch -> stopHold(input))
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

-- A23-40 보강: the free part of the Roblox top bar (GuiService.TopbarInset: screen px from the top-left, right of
-- Roblox's own buttons) in MainGui logical units, for HudLayout's top bar row ([메뉴] + the war meter); nil when Roblox
-- reports none (HudLayout then assumes Roblox's usual buttons)
function L.TopbarRect(gui, s)
	local ok, tb = pcall(function()
		return GuiService.TopbarInset
	end)
	if not ok or typeof(tb) ~= "Rect" or tb.Width <= 0 or tb.Height <= 0 then return nil end
	-- AbsolutePosition is measured below the top bar (GetGuiInset); TopbarInset from the screen's very top
	local origin = gui.AbsolutePosition
	local ox, oy = origin.X, origin.Y + insetY()
	return { X0 = (tb.Min.X - ox) / s, Y0 = (tb.Min.Y - oy) / s, X1 = (tb.Max.X - ox) / s, Y1 = (tb.Max.Y - oy) / s }
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
	-- 검수 2026-10-07 (user: "이렇게 하라고" with the reference row): A23-40's six tiles are always on the row; a window
	-- that is not built yet answers on press (L.TileTap); only the row's room (Count) decides what overflows to [메뉴]
	-- A23-113 ③ 고침 (user 10/10 "처음부터 다 보이고, 그 자물쇠 해놓자"): every tile is on the row from the start; one not
	-- open yet is locked (L.RefreshLocks), never hidden
	L.RefreshLocks()
	local want = table.clone(ui.tiles)
	local came, cameKey = {}, "|"
	for _, t in want do
		came[t.Def.Id] = true
		cameKey ..= t.Def.Id .. ","
	end
	ui.tileCame = came
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
	key ..= cameKey
	if key == ui.tileKey then return false end
	ui.tileKey = key
	ui.shownTiles = want
	local shown = {}
	for _, t in want do shown[t] = true end
	local underFold = IS_TOUCH and ui.foldOpen == true
	for _, t in ui.tiles do t.Button.Visible = shown[t] == true and not underFold end
	return true
end

-- A23-113 ③: tile id -> true once open (stays open this session), false = locked at the first check (its opening pops)
L.TileSeen = {}

-- 게임성 검수 10/13 (A23-99 less hand-holding: the Hero tile only said "Coming soon!"): a tile has something to open
-- now - its window (Panels), the ranking list, the map or the invite; one that has not (Hero until its window, BB8)
-- stays locked like the others, its own name under the lock, a press only wiggles
function L.TileOpens(def)
	if def.Map or def.Invite or def.Id == "Ranking" then return true end
	return L.TileWindow(def) ~= nil
end

-- lock / unlock each tile by the rule (Config.HudReveal.TileShows); the lock pops away when one opens in play
function L.RefreshLocks()
	if not ui.tiles then return end
	local ready = L.RevealReady() -- every check (even one that changes nothing) so the join timer starts with my data
	local st = L.RevealState()
	for _, t in ui.tiles do
		local id = t.Def.Id
		local was = L.TileSeen[id]
		local open = was == true or Config.HudReveal.TileShows(id, st)
		local opens = L.TileOpens(t.Def)
		if open then
			if was == false and ready and opens then L.TilePop(t.Button) end -- opened in play (not at the join)
			L.TileSeen[id] = true
		elseif was == nil then
			L.TileSeen[id] = false
		end
		local locked = not (open and opens)
		local word = (open and not opens) and t.Def.Text or Config.HudReveal.TileWord(id, st) -- (nothing to open: its name)
		if t.Lock and (t.Lock.Locked ~= locked or (locked and t.LockWord ~= word)) then
			pcall(t.Lock.Set, locked, word)
			t.LockWord = word
		end
	end
	for _, f in ui.foldTiles or {} do -- the phones' fold copies follow their tile
		local open = L.TileSeen[f.Def.Id] ~= false
		local opens = L.TileOpens(f.Def)
		local locked = not (open and opens)
		local word = (open and not opens) and f.Def.Text or Config.HudReveal.TileWord(f.Def.Id, st)
		if f.Lock and (f.Lock.Locked ~= locked or (locked and f.LockWord ~= word)) then
			pcall(f.Lock.Set, locked, word)
			f.LockWord = word
		end
	end
end

-- is this tile locked right now (no lock look = never locked)
function L.TileLocked(id)
	for _, t in ui.tiles or {} do
		if t.Def.Id == id then return t.Lock ~= nil and t.Lock.Locked == true end
	end
	return false
end

-- a locked tile's press: a quick small wiggle (nothing with reduced motion)
function L.TileWiggle(id)
	if UIKit.ReducedMotion() then return end
	local list = table.clone(ui.tiles or {})
	for _, f in ui.foldTiles or {} do
		if f.Row then table.insert(list, f) end
	end
	for _, t in list do
		if t.Def.Id == id and not t.Wiggling then
			t.Wiggling = true
			local btn = t.Button
			task.spawn(function()
				for _, r in { 7, -6, 4, -2, 0 } do
					local tw = TweenService:Create(btn, TweenInfo.new(0.05, Enum.EasingStyle.Sine), { Rotation = r })
					tw:Play()
					tw.Completed:Wait()
				end
				btn.Rotation = 0
				t.Wiggling = false
			end)
		end
	end
end

-- pops only a few seconds after my data loaded (the quest book and the pet list come in just after the join)
function L.RevealReady()
	if attr("DataLoaded", false) ~= true then L.RevealAt = nil return false end
	L.RevealAt = L.RevealAt or os.clock()
	return os.clock() - L.RevealAt > 3
end

-- what the tile rule reads: my level, skill slots, a pet (one following, or any in my pet list), the first chapter done
function L.RevealState()
	local hasPet = (attr("EquippedPet", "") or "") ~= ""
	local pw = C and C.PetWindow
	if not hasPet and type(pw) == "table" and type(pw.Lists) == "function" then
		local ok, list = pcall(pw.Lists)
		hasPet = ok and type(list) == "table" and type(list.List) == "table" and #list.List > 0 or false
	end
	local last = "story:" .. tostring(Config.HudReveal.FirstChapterLast or "M1_4")
	local done = false
	local book = questState.Book
	for _, id in type(book) == "table" and type(book.Done) == "table" and book.Done or {} do
		if id == last then done = true break end
	end
	for _, e in questState.All or questState.Rows or {} do -- a later chapter's main row = the first chapter is done
		local ch = type(e) == "table" and type(e.Id) == "string" and tonumber(string.match(e.Id, "^story:M(%d+)_")) or nil
		if ch and ch >= 2 then done = true end
	end
	return { Level = num("Level", 1), SkillSlots = num("SkillSlots", 0), LearnReady = num("SkillLearnReady", 0), HasPet = hasPet,
		ChapterDone = done }
end

-- a tile coming in: a short pop (none with reduced motion)
function L.TilePop(btn)
	if not btn or UIKit.ReducedMotion() then return end
	local sc = btn:FindFirstChild("RevealPop") or Instance.new("UIScale")
	sc.Name = "RevealPop"
	sc.Scale = 0.4
	sc.Parent = btn
	local tw = TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	tw.Completed:Connect(function() sc:Destroy() end)
	tw:Play()
end

-- the shown tiles on Rects.tiles: squares of Size, Gap apart; PC centred on the row (the screen centre), phones flush
-- right (under the plate)
function L.LayoutTiles(tr)
	local shown = ui.shownTiles or {}
	local n = #shown
	if n == 0 then return end
	local size, gap = tr.Size or tr.H, tr.Gap or 4
	local total = n * size + (n - 1) * gap
	-- A23-109 (PC): HudLayout centres tiles + quick slots as one row under the bars, so the tiles fill their own box
	-- from its left end (were centred under the bars while the potions were hidden, 검수 10/09)
	local x0 = IS_TOUCH and (tr.X + tr.W - total) or tr.X
	-- small windows (main Studio 2026-10-08: 991x451 -> UIScale 0.5, 33 px tiles): a name no longer fits under its icon
	-- and ran under the next tile ("Map?ankin("); below L.TileLabelMinPx real px the tiles show their icons only. PCs:
	-- A23-109 (user 10/10 "왜 네모 안에 글씨 사라졌냐") - HudLayout keeps PC tiles >= 40-46 real px, so names show
	local named = size * currentScale() >= (IS_TOUCH and L.TileLabelMinPx or L.TileLabelMinPxPC)
	for i, t in shown do
		t.Button.Size = UDim2.fromOffset(size, size)
		t.Button.Position = UDim2.fromOffset(x0 + (i - 1) * (size + gap) + size / 2, tr.Y + size / 2)
		if t.Label and t.Label.Visible ~= named then t.Label.Visible = named end
	end
end
L.TileLabelMinPx = 40
L.TileLabelMinPxPC = 34 -- A23-109: PC tiles are >= 40 px (HudLayout floors); a tiny window may still go under
-- the quest lines' plates (검수 2026-10-08): du of plate left / right of a line's content, the gap between two lines
L.QuestPlate = { On = false, PadL = 6, PadR = 10, Gap = 4 }
-- A23-94 quest tracker (L.BuildTracker): On = the big left-middle 'now do' quest instead of the lines; du gap between its
-- lines, build heights, title / body size per quest-rect line height, the in-progress (p/t) colour
-- 검수 10/09 (user: "the goal line is too small"): on PCs the goal sentence and (p/t) are about 72% of the title
-- (BodyK); a goal longer than GoalLines lines steps down to BodyMinK (the old size) to fit, never cut with '...'
-- (L.FitGoal; GoalMax / GoalMin = its du range from L.LayoutTracker)
L.Tracker = { On = true, Gap = 2, TitleH = 30, ProgH = 22, TitleK = IS_TOUCH and 1.05 or 1.45, BodyK = IS_TOUCH and 0.66 or 1.05,
	BodyMinK = IS_TOUCH and 0.66 or 0.8, GoalLines = 2, GoalMax = nil, GoalMin = nil,
	ProgColor = Color3.fromRGB(255, 96, 72), Rect = nil }
L.LineCache = { Lines = {}, N = 0 } -- L.TextLines: "text|size|width|font" -> lines (false = measuring)
-- 1안 ② / ④ (real px): the status row Row tall (phone RowTouch = the 44 px touch target), Gap under the war meter, the
-- words at least TextPx (phone 19), an icon chip's art Icon px
L.ChipTop = { Row = 36, RowTouch = 44, Gap = 8, TextPx = 18, TextPxTouch = 19, Icon = 24, IconTouch = 24, Side = 12 }
-- tile names inside the rim (tileButton): the inset du in all (the rim is ~4 px a side; phones keep their 11 px floor,
-- so their names may touch the rim's inner edge: 'Settings' is 41 px at 11 px in a 45 px square)
L.TileNameInset, L.TileNamePx = IS_TOUCH and 4 or 6, 8
-- A23-109: PC tile names in real px (tiles >= 40-46 px fit 'Ranking' at 10 px). 10/14 (최종 검수 photos; Montserrat Bold
-- measured in Studio: 'Monsters' 33.5 / 38 / 45.5 px wide at 8 / 9 / 11 px, 'Settings' 30.5 / 34.5 / 41): floor 8 px
-- (UIKit.FitText FitMinPx, under its 11px one) and PadPC real px of margin, so in the 44 px top bar squares 'Settings'
-- sits at 9 px and 'Monsters' in the 46 px row tile at 8 px, clear of the rim; shorter names stay bigger
L.TileNamePxPC, L.TileNamePadPC = 8, 6
L.QuickKeyPx = 12 -- A23-109: the quick slot numbers 1 · 2 · 3 in real px
-- 검수 2026-10-08 (user: "위쪽이 너무 심심해"): the war meter as a game top bar (buildWar), du inside Rects.war_meter:
-- the PanelCard plate PlateUp / PlateDown past the meter's top / bottom (inside Roblox's 58 px bar), the badges Badge du
-- (their centres BadgeOut du outside the meter's ends... negative = inside), the bar and the info line BarIn du in from
-- each end, the crown Crown du; DesignH = the meter height those sizes are for (PC 0.8), KMax = how much they may grow
-- on a taller meter (small PC windows, L.LayoutWar)
-- 최종 검수 10/14 상단 HUD 1안 ①: REAL px (Roblox's top bar does not follow our UIScale; HUD.WarGeometry divides by
-- it): crown 24 (phone 22) Lift px over the meter's top, CrownGap 6 (4) of air, track TrackH 14, badges 40 (36) inside the
-- ends with BadgeGap 8 to the track, the plate PlatePad around the track only
L.WarTop = { PlateSlice = 0.3, ScoreMinPx = 12, ScoreMaxPx = 18, -- the badge scores in real px (검수 10/10: >= 12)
	Crown = 24, CrownTouch = 22, Lift = 9, LiftTouch = 8, CrownGap = 6, CrownGapTouch = 4, TrackH = 14, TrackHTouch = 14,
	Badge = 40, BadgeTouch = 36, BadgeGap = 8, BadgeGapTouch = 8, PlatePad = 7, PlatePadTouch = 6 }
L.PortraitDrop, L.PortraitSpan = 0.5, 2.3 -- the Lv ring's bust (head + shoulders), L.PortraitRebuild

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
		Topbar = L.TopbarRect(gui, s), Hidden = { auto = not (ui.auto and ui.auto.Visible), q = L.SkillHidden("Q") } })
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
	ui.quests.Position = UDim2.fromOffset(q.X, (ui.tracker and L.QuestBottom or (q.Y + q.H)) + 4)
	ui.quests.Size = UDim2.fromOffset(q.W, 0)
	if IS_TOUCH then
		L.LayoutQuestHeader(q.W, q.H)
		-- the rows' overlay opens under the quest lines, kept on screen (CR-M25)
		if ui.questOverlay then
			ui.questOverlay.Position = UDim2.fromOffset(math.clamp(q.X, 8, math.max(8, W - L.OverlayW - 8)),
				(ui.tracker and L.QuestBottom or (q.Y + q.H)) + 4)
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
	-- 1안 ② / ⑤ (최종 검수 10/14): the status row starts ChipTop.Gap px under the war meter's DRAWN bottom (its badges),
	-- ChipTop.Row px tall (phones: the 44 px touch target), the words >= TextPx real px
	local CT = L.ChipTop
	local rowH = math.max(ch.H, (IS_TOUCH and CT.RowTouch or CT.Row) / s)
	L.ChipRowH = rowH
	local warBottom = (ui.war.Visible and L.WarGeo) and (wm.Y + L.WarGeo.Bottom + CT.Gap / s) or ch.Y
	local chipsY = math.max(ch.Y, warBottom)
	-- A23-192 (user 10/14 photo: the chips stood in a column over the middle of the screen): one wide row under the war
	-- meter, centred on it, as wide as the room between the minimap and the menu button allows (never narrower than the
	-- layout's column); it wraps only when even that is full
	local cx = ch.X + ch.W / 2
	local leftEdge = (R.minimap and (R.minimap.X + R.minimap.W) or 0) + L.ChipTop.Side
	local rightEdge = (R.menu and R.menu.X or W) - L.ChipTop.Side
	local rowW = math.max(ch.W, 2 * math.min(cx - leftEdge, rightEdge - cx))
	ui.chips.Position = UDim2.fromOffset(cx, chipsY)
	ui.chips.Size = UDim2.fromOffset(rowW, rowH)
	ui.chipList.Padding = UDim.new(0, 6 / s)
	local textDu = math.ceil((IS_TOUCH and CT.TextPxTouch or CT.TextPx) / s)
	for _, chip in ui.chip do
		chip.Frame.Size = UDim2.fromOffset(0, rowH)
		if chip.Label then chip.Label.TextSize = textDu end
	end
	local chipsBottom = chipsY + math.max(rowH, ui.chips.AbsoluteSize.Y / s)
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
	if ui.quick3 and R.quick and R.quick.Cells then
		local c = R.quick.Cells[3]
		ui.quick3.Position = UDim2.fromOffset(c.X + c.W / 2, c.Y + c.H / 2)
		ui.quick3.Size = UDim2.fromOffset(c.W, c.H)
		local key = ui.quick3:FindFirstChild("Key")
		if key then
			local keyH = math.max(15, math.ceil((L.QuickKeyPx + 3) / math.max(0.1, currentScale())))
			key.Size = UDim2.fromOffset(keyH, keyH)
		end
	end
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

	-- CR-L37: top / left edge of the cluster (EventHUD's legacy personal line keeps above ClusterTop). PCs: the potions
	-- sit by the icon row (HudLayout bottom-centre group), not in the corner cluster
	local clusterTop, clusterLeft = math.huge, math.huge
	for _, id in (IS_TOUCH and { "attack", "q", "potions", "auto" } or { "attack", "q", "auto" }) do
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
	for _, name in { "EventHUD", "MiniMap", "SkillBar", "BuffBar" } do
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
	for _, hit in { ui.portraitHit, ui.powerHit } do
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

local function onCharacterAdded(_character)
	clearHolds()
end

local function tick()
	tickCount += 1
	local visible = refreshVisibility()
	if ui.foldOpen then L.FoldWatch() end
	if not visible then return end
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

-- A23-49: SkillBar's Q goes through the same path as HUD's own Q (throttle, cooldown, MP toast, face the target)
function HUD.Release()
	doRelease()
end

-- the HUD takes input now (no picker / opening / dead state): SkillBar's buttons follow it
function HUD.InputAllowed()
	return inputAllowed()
end

-- SkillBar has drawn Q · Z · X (it starts after HUD in ClientMain ORDER): HUD's own Q stays built (its refreshers keep
-- working) but hidden, so there is one Q button
function HUD.SkillBarReady()
	if ui.release then ui.release.Visible = false end
end

-- A23-36: where the 'now do' quest row happens (QuestTarget.ForEntry) or nil; QuestMarker draws it
function HUD.QuestTarget()
	local qt = C and C.QuestTarget
	local rows = questState.Rows
	if type(qt) ~= "table" or type(qt.ForEntry) ~= "function" or type(rows) ~= "table" then return nil end
	-- A23-81: a quest pressed in the quest window (HUD.QuestGo) leads while it is still in the list
	local e = nil
	if questState.GuideKey then
		for _, r in rows do
			if L.EntryKey(r) == questState.GuideKey then e = r break end
		end
		if not e then questState.GuideKey = nil end
	end
	e = e or rows[questState.Shown or 1]
	if not e then return nil end
	local ok, target = pcall(qt.ForEntry, e, attr("ZoneId", ""), getFaction())
	return ok and target or nil
end

----------------------------------------------------------------- the quest window's side (A23-81, QuestBook)
-- the HUD's quest rows as the window reads them (the same tables, so a press finds its row)
function HUD.QuestEntries()
	local out = {}
	for i, e in questState.All or questState.Rows or {} do out[i] = e end
	return out
end

-- the server's quest book ({ Available = {...}, Done = {...} }) when it sends one, else nil
-- A23-104: true while the server says the daily jobs are not open yet (the quest window hides its Daily tab)
function HUD.DailyLocked()
	return questState.DailyLocked == true
end

function HUD.QuestBook()
	return questState.Book
end

-- quests that left the list after their [Claim] this session (newest last): { Id, Text, ShortName, Kind }
function HUD.QuestDoneSession()
	return table.clone(questState.DoneSession or {})
end

-- the rows' [Claim] / [New] rules (refreshQuests)
function HUD.QuestCanClaim(e)
	return type(e) == "table" and e.Progress >= e.Target and e.CanClaim == true
		and (e.Pinned == true or e.Kind == "Daily" or e.Kind == "Sub")
end

function HUD.QuestCanReroll(e)
	return type(e) == "table" and e.Progress < e.Target and not e.Pinned and e.Slot ~= nil
end

-- [Claim] / [New] from the window: through the HUD's own row (its locks, the reroll question)
function HUD.QuestClaim(e)
	if not HUD.QuestCanClaim(e) then return false end
	for _, r in questRows do
		if r.Entry == e then
			onClaim(r)
			return true
		end
	end
	-- 빛 마을 점검 #19: a More row (a sub past MaxSubs) has no HUD row: the window claims it directly ("story:<id>")
	if e.More and e.Story and type(e.Id) == "string" and not throttled("claim", 0.35) then
		fire("ClaimQuest", e.Id)
		questState.ClaimAt = os.clock()
		return true
	end
	return false
end

function HUD.QuestReroll(e)
	if not HUD.QuestCanReroll(e) then return false end
	for _, r in questRows do
		if r.Entry == e then
			onReroll(r)
			return true
		end
	end
	return false
end

-- a quest pressed (window row, or a HUD line that is no guide / story row): the guide and story rows run their
-- action as on the HUD (L.PinnedTap: the travel window, the beam, the story page); any other quest becomes the
-- one the marker leads to (HUD.QuestTarget) until it leaves the list
function HUD.QuestGo(e)
	if type(e) ~= "table" then return false end
	if (e.Pinned or e.Story) and L.PinnedTap then
		L.PinnedTap(e)
		return true
	end
	questState.GuideKey = L.EntryKey(e)
	pcall(refreshGuides)
	return true
end

----------------------------------------------------------------- lifecycle
function HUD.Init(registry)
	C = registry
	UIKit = C and C.UIKit
	pcall(function() UIKit.L10n.Register("HUD.TXT", TXT) end) -- 10/14: the words' keys "HUD.TXT.<key>" (L.Tx / UIKit.Tr)
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
	pcall(L.RegisterWarInfo) -- 상단 HUD 1안 ①: the war bar's window (Panels is ready: every Init ran)
	pcall(function() -- 최종 검수 10/15 #11: a real whole crown point of mine pops my side's badge
		Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
			if kind == "CrownPoint" then pcall(L.CrownPop, data) end
		end)
	end)

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
	-- 개발 1 10/14: the translator comes a moment after the HUD - the power / pouch line (words drawn by UIKit.Tr) again
	if UIKit.LangChanged then UIKit.LangChanged:Connect(function() pcall(refreshStats) end) end
	UIKit.OnAttr({ "Faction", "Class", "ClassChosen", "CharacterGender", "SizeMult" }, L.RefreshPortrait)
	UIKit.OnAttr({ "Level" }, function() L.Pow.LevelAt = os.clock() end) -- BB5: no "+N" next to a level-up banner
	UIKit.OnAttr({ "CombatPower", "DataLoaded", "ClassChosen" }, L.PowerChanged)
	UIKit.OnAttr({ "WeaponTier", "DataLoaded", "ClassChosen" }, L.TierChanged) -- A23-68 #3
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
	UIKit.OnAttr({ "Class", "ClassChosen", "Faction" }, L.RefreshSkillIcon)
	UIKit.OnAttr({ "Level", "Rebirths", "VacationDays", "AttendReady" }, refreshMenuGlow)
	UIKit.OnAttr({ "SubFastTravel" }, function() if ui.foldOpen then L.PlaceFold(false) end end) -- A23-182: the Travel square
	questState.Started = true -- CR-L50: "Quests" remote payloads refresh the rows from now on
	UIKit.OnAttr({ "DailyClaims", "RerollReadyAt" }, refreshQuests) -- the list itself comes from onQuests
	-- 10/14 (Config.QuestNotNow): a goose / war row folds or comes back as the next hunt / the round gets near
	L.NotNowLast = L.NotNowSig()
	local function notNowCheck()
		local sig = L.NotNowSig()
		if sig ~= L.NotNowLast then
			L.NotNowLast = sig
			refreshQuests()
		end
	end
	UIKit.OnGameAttr({ "GooseActive", "GooseNextAt", "WarMode", "WarRoundEndsAt" }, notNowCheck)
	task.spawn(function()
		while true do
			task.wait(tonumber((Config.QuestNotNow or {}).Check) or 15)
			pcall(notNowCheck)
		end
	end)
	UIKit.OnAttr({ "ZoneTown", "ZonePvP", "Rookie", "Protected", "InCombatUntil", "SizeMult", "BullyStacks",
		"KaijuState", "Faction", "Outlaw" }, refreshChips)
	UIKit.OnAttr({ "WarPoints", "Faction" }, refreshWar)
	UIKit.OnGameAttr({ "WarHaloScore", "WarHornsScore", "WarMode", "WarBlessing", "WarRoundEndsAt" }, refreshWar)
	UIKit.OnAttr({ "TravelingUntil" }, refreshTravel)
	UIKit.OnAttr({ "TutorialStep", "ZoneId", "BlacksmithVisited", "TutorialKills" }, refreshGuides)
	UIKit.OnAttr({ "Level" }, onLevelChanged)
	-- A23-68 #4: the first [Claim] unfolds the quest lines and the war meter's info line (NEW! tags)
	UIKit.OnAttr({ "TutorialStep" }, function()
		L.ApplyFold(true)
		refreshQuests()
	end)
	L.ApplyFold(false)
	-- A23-113 ③: a level up, a new skill or a pet unlocks its menu tile at once (the 1 s refresh also catches it)
	for _, name in { "Level", "SkillSlots", "SkillLearnReady", "EquippedPet" } do
		LocalPlayer:GetAttributeChangedSignal(name):Connect(L.RefreshLocks)
	end
	-- Studio-only check hooks (A23-191: the hint preview went with the hints)
	if game:GetService("RunService"):IsStudio() then
	end

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
	if type(C.Settings) == "table" and type(C.Settings.Changed) == "table" then
		C.Settings.Changed:Connect(L.RefreshKeys)
		C.Settings.Changed:Connect(function() if refreshQuests then pcall(refreshQuests) end end) -- §15 P1 ③: the pins
	end
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
	-- A23-40 보강: Roblox's top bar buttons grow / shrink (its menu opened, chat on / off): the bar row follows
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(requestLayout)
	end)
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

	-- A23-51: a left press on the world attacks once (holding or dragging never repeats); the camera turns with the
	-- right mouse drag only (Roblox's default camera).
	C.CameraFollow.PrimaryClick:Connect(function()
		if inputAllowed() then L.SwingFaced() end
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
