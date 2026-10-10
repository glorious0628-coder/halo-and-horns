-- UIKit.luau : the shared ScreenGui ("MainGui"), theme, widget factories, toasts, announce banner, confirm dialog
-- and attribute helpers used by every client module (TECH_SPEC §4.23, addendum A3-H4 / M1).
-- Everything here is presentation only; the server never trusts anything the client shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LocalPlayer = Players.LocalPlayer

local UIKit = {}

UIKit.Gui = nil -- ScreenGui "MainGui", created in Init

-- A23-48 (user 2026-10-06 "게임은 영어만": every text on the game screen is English): one font set, chosen here only.
-- A23-63 (user 2026-10-07 "폰트 이쁜 걸로", candidate 3 of art/review/font_en_candidates_2026-10-06.png): Head = titles,
-- buttons and numbers (TextStyles Title / Button / Number, ExtraBold text) = Denk One (one weight); Body = body text and
-- name tags = Montserrat (Regular / Bold). Was Fredoka One + Builder Sans. Montserrat runs ~15 % wider than Builder Sans
-- and Denk One ~11 % narrower than Fredoka One at the same size (UiSandbox TextService, 2026-10-07): sized-to-text
-- elements measure with UIKit.MeasureText, so they follow. No language choice and no device-language switch.
-- Shared state keeps large HUD / Fx chunks below the local limit.
local FONT = { UseTextImages = false, Faces = {}, States = setmetatable({}, { __mode = "k" }), MeasureCache = {}, CacheCount = 0,
	Lang = "en",
	Sets = {
		en = { Head = { Family = "rbxasset://fonts/families/DenkOne.json" },
			Body = { Family = "rbxasset://fonts/families/Montserrat.json" } },
	},
	Cache = {}, -- [lang .. role .. weight name] = Font
}
-- Config.Fonts (dev2 0f6de17, UI round 2 #7): the Head / Body families are set in one place (the server's name tags
-- read them too); the literals above stay as the fallback while it is missing
for role, family in (type(Config.Fonts) == "table" and Config.Fonts or {}) do
	if (role == "Head" or role == "Body") and type(family) == "string" and family ~= "" then
		FONT.Sets.en[role] = { Family = family }
	end
end
-- the face for a role ("Head" / "Body") and weight in the current language (GothamBold when a font fails to load)
function FONT.Face(role, weight)
	role = role == "Head" and "Head" or "Body"
	local key = FONT.Lang .. role .. weight.Name
	local face = FONT.Cache[key]
	if face then return face end
	local def = (FONT.Sets[FONT.Lang] or FONT.Sets.en)[role]
	local ok, f = pcall(function()
		if def.Id then return Font.fromId(def.Id, weight, Enum.FontStyle.Normal) end
		return Font.new(def.Family, weight, Enum.FontStyle.Normal)
	end)
	face = ok and f or Font.fromEnum(Enum.Font.GothamBold)
	FONT.Cache[key] = face
	return face
end
-- one of our faces (any language): a re-apply maps it to the current language instead of keeping it
function FONT.Ours(face)
	if typeof(face) ~= "Font" then return false end
	for _, set in FONT.Sets do
		for _, def in set do
			if (def.Family and face.Family == def.Family) or (def.Id and face.Family == "rbxassetid://" .. def.Id) then
				return true
			end
		end
	end
	return false
end
-- FONT.Faces[weight] = the body face of the current language (UIKit.Theme.FontFace, legacy callers)
function FONT.Refresh()
	for _, weight in { Enum.FontWeight.Regular, Enum.FontWeight.Bold, Enum.FontWeight.ExtraBold } do
		FONT.Faces[weight] = FONT.Face(weight == Enum.FontWeight.ExtraBold and "Head" or "Body", weight)
	end
end
FONT.Refresh()
-- faces load asynchronously: a label sized by AutomaticSize before its face arrived keeps the stand-in face's width
-- (UiSandbox 2026-10-06: 'Daily Quests (0/3)' was cut to 'Daily Quests...'). Once every face is loaded
-- (GetTextBoundsAsync waits for it) each styled label with AutomaticSize is measured again
function FONT.Preload()
	task.spawn(function()
		for _, role in { "Head", "Body" } do
			for _, weight in { Enum.FontWeight.Regular, Enum.FontWeight.Bold, Enum.FontWeight.ExtraBold } do
				pcall(function()
					local params = Instance.new("GetTextBoundsParams")
					params.Text = "Halo & Horns 0123"
					params.Font = FONT.Face(role, weight)
					params.Size = 14
					params.Width = 1000
					TextService:GetTextBoundsAsync(params)
					params:Destroy()
				end)
			end
		end
		for obj, state in FONT.States do
			if not state.Dead and obj.Parent and obj.AutomaticSize ~= Enum.AutomaticSize.None then
				local auto = obj.AutomaticSize
				obj.AutomaticSize = Enum.AutomaticSize.None
				obj.AutomaticSize = auto
			end
		end
	end)
end

-- faction colours always come from Config (addendum A9-1: Neutral is teal, read from Config, never a hard-coded grey)
local function configFactionColor(id, fallback)
	local def = Config.Factions[id]
	if type(def) == "table" and typeof(def.Color) == "Color3" then return def.Color end
	return fallback
end

UIKit.Theme = {
	Bg = Color3.fromRGB(25, 25, 35),
	BgTransparency = 0.25,
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(200, 200, 210),
	Good = Color3.fromRGB(80, 220, 120),
	Bad = Color3.fromRGB(255, 80, 80),
	Gold = Color3.fromRGB(255, 210, 60),
	XP = Color3.fromRGB(90, 170, 255),
	Halo = configFactionColor("Halo", Color3.fromRGB(255, 215, 90)),
	Horns = configFactionColor("Horns", Color3.fromRGB(220, 50, 60)),
	Neutral = configFactionColor("Neutral", Color3.fromRGB(40, 200, 190)), -- A9-1
	Sack = Config.Visuals.GrudgeSackColor,
	Revenge = Color3.fromRGB(255, 150, 40),
	Font = Enum.Font.GothamBold,
	FontFace = FONT.Faces[Enum.FontWeight.Bold],
}

local C = nil -- client registry

----------------------------------------------------------------- constants
local UI = Config.UI or {}
local SCALE_MIN = UI.ScaleMin or 0.75 -- addendum M1 (overrides the 0.6 lower bound of §4.23)
local SCALE_MAX = UI.ScaleMax or 1.25
local DESKTOP_MULT = UI.DesktopScaleMult or 0.8 -- non-touch devices get a smaller HUD
local DESKTOP_MIN = UI.DesktopScaleMin or 0.6
local DESKTOP_MAX = UI.DesktopScaleMax or 1.0
local REF_HEIGHT = 720
local MIN_TEXT_SIZE = UI.MinTextSize or 11 -- addendum M1
local TOP_PAD = UI.TopInsetPad or 8 -- addendum H4
local TOP_FALLBACK = UI.TopInsetFallback or 64

local TOAST_Y = 152 -- slot table: toast stack top-center from y 152 (shifted below the top bar inset)
local TOAST_WIDTH = 460
local MAX_TOASTS = 4
local TOAST_ICON = 34 -- item / monster art left of a toast's text (UIKit.Toast icon)
local ANNOUNCE_ICON = 64 -- the same left of the big banner's text (UIKit.Announce icon)
-- CR-L38: short (phone) viewports keep fewer toasts; the stack never takes more than WidthFrac of the screen width
local TOAST_PHONE = { Height = 500, Max = 2, WidthFrac = 0.45 }
local DEFAULT_TOAST_SECONDS = 3 -- 검수 10/09 (UI clutter review ②): one toast at a time, 3 s (NOTIFY.OneAtATime)
local DEFAULT_ANNOUNCE_SECONDS = 3.5
local MAX_ANNOUNCE_QUEUE = 3

local Z_ANNOUNCE = 90
local Z_TOASTS = 95
local Z_CONFIRM = 100 -- §4.23: UIKit.Confirm ZIndex 100

local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }
local DARK_TEXT = Color3.fromRGB(30, 25, 10)

----------------------------------------------------------------- private state
local uiScale = nil
local cameraConn = nil
local toastHolder = nil
local announceFrame, announceLabel, announcePop = nil, nil, nil
local confirmOverlay = nil

local toasts = {} -- oldest first: { Frame, Label, Stroke, Text, Token, Dead }
local toastCounter = 0
local toastMax = MAX_TOASTS -- CR-L38: TOAST_PHONE.Max on short viewports (set by applyScale)

local announceCurrent = nil -- { Text, Token }
local announceQueue = {} -- { { Text, Duration } }
local announceToken = 0

local lastWarnAt = -math.huge

-- A23-35 text styles (section "text styles" below). Declared here so applyScale can re-run the size floors.
local STYLE = {
	White = Color3.new(1, 1, 1),
	Cream = Color3.fromRGB(255, 236, 190), -- #FFECBE, bottom of the dark-plate gradient
	Navy = Color3.fromRGB(27, 33, 64), -- #1B2140: dark-plate rim and light-plate text
	-- UIStroke thickness by rendered text px: <= 16 -> 1.5, <= 28 -> 2, larger -> 3
	StrokeTiers = { { 16, 1.5 }, { 28, 2 }, { math.huge, 3 } }, -- 1.5: small text over the world needs more than 1 px
	States = setmetatable({}, { __mode = "k" }), -- styled label -> state
	RefreshAll = nil, -- assigned in the text styles section
}

-- HUD v2 notify column (UIKit.PlaceNotify). Rect == nil = the old TOAST_Y stack + 30% banner (before the first call).
local NOTIFY = {
	-- 검수 2026-10-09 (user: "not too kind, not too unkind"; UI clutter review ②): one toast at a time for at most
	-- ShowSeconds; the next ones wait in Queue (newest kept, at most QueueMax: a burst never fills half a minute)
	OneAtATime = true,
	ShowSeconds = 3,
	QueueMax = 3,
	Queue = {}, -- { { Text, Kind, Duration, Icon } } oldest first
	Rect = nil, -- copy of HUD.Layout.Rects.notify { X, Y, W, H } (logical MainGui units, incl. the top bar)
	Y = nil, -- live top of the column = max(topY, Rect.Y)
	ToastGap = 6, -- the toast UIListLayout padding
	ToastEstimate = 36, -- height of a not-yet-laid-out toast (18 text + 7 + 7 padding, rounded up)
	BannerH = 50,
	BannerMinH = 28, -- a full column still gets a readable banner (same idea as "never below 1 toast")
	BannerMaxW = 880,
	BannerWidthMult = 1.25,
	BannerIcon = ANNOUNCE_ICON,
	-- 검수 2026-10-06 (English cut: "The Pumpkin King appeared in the"): the banner text wraps and the banner grows
	-- instead of shrinking the letters (TextScaled stopped at its floor and clipped the 2nd line on phones)
	BannerShownH = nil, -- the column's banner height (PlaceNotify): the least height; longer texts grow it
	BannerOldH = 84, -- the same before the first PlaceNotify (30% screen height path)
	BannerPx = 16, -- real px: the banner text is never smaller
	BannerTextMax = 28, -- logical units
	BannerTextOld = 28,
	BannerLines = 3, -- more than this ends in "..." (TextTruncate)
	BannerPadY = 6,
	ToastLines = 4,
	ToastPx = 12, -- real px: the toast text is never smaller (small desktop windows run the HUD at UIScale 0.6)
	WrapLineH = 1.1, -- line height / TextSize for the maxLines cap (Builder Sans / Fredoka measure 1.0)
	-- the measured height gets this much room per line: at small real sizes (10-12 px) the engine's rounded line
	-- height is taller than the measurement and the last line was dropped for "..." (UiSandbox 655x340, 2026-10-06)
	WrapSlack = 0.15,
	WrapSlackPx = 2.5, -- the least room per line in real px (UIKit.WrapHeight)
	WrapWidthSlackPx = 6, -- UIKit.WrapHeight measures this much narrower than the label (real px)
	TrimQueued = false,
	-- UI round 2 #4 (검수 2026-10-07: "창이 열려 있으면 알림은 창 위 한 줄로"): the open window's rect (MainGui du, its title
	-- ribbon included; UIKit.SetNotifyAvoid from Panels) - toasts then show one line, one at a time, just above the window
	-- (else just below it; else in the column as before) and big banners come as that one line
	Avoid = nil,
	WrapFits = setmetatable({}, { __mode = "k" }), -- [label] = its UIKit.WrapHeight fit (toasts: fit again on Avoid)
	-- A23-68 #4 / quality ⑨: the "NEW!" tag (UIKit.NewTag): the approved white Chip tinted gold, navy "Number" text
	NewTag = { Seconds = 6, H = 20, MinPx = 12, Text = "NEW!", Gold = Color3.fromRGB(255, 206, 72), WidthEm = 3.4,
		ThinK = 1.6, ThinDY = 4, -- a target up to ThinK tag heights tall wears it beside its right end (UIKit.NewTag)
		Gap = 0.4 }, -- s between one tag going and the next waiting one (NOTIFY.NewQ)
	-- 검수 10/10 (the war bar, its info line and the goose chip all wore NEW! at once): one tag at a time. Active = the
	-- tagged part until Until; Queue = { { Target, Text } } waiting their turn; Draining = a turn is scheduled
	NewQ = { Active = nil, Until = 0, Queue = {}, Draining = false },
	-- 창 꾸미기 ③ the reward popup (UIKit.RewardPopup), du: plate width, banner (BannerGold 512 x 178, text box
	-- 0.254 / 0.225 / 0.492 / 0.365), slots, the glow and sparkles, the count-up time
	-- 창 꾸미기: the parts the windows / popups use, loaded once at start (UIKit.Start) so the first confirm box or reward
	-- popup never shows an empty plate while its texture downloads (UiSandbox PC 2026-10-07: DialogBox still blank 1.2 s in)
	PreloadArt = { "DialogBox", "PanelCard", "RibbonHeader", "BtnRound", "GlyphClose", "GlyphBack", "BtnPrimary",
		"BtnSecondary", "BtnConfirm", "BannerGold", "SlotCommon", "IconCoin", "IconExp", "Chip", "BarkBubble",
		"RewardPanelHalo", "RewardPanelHorns", "RewardRibbonHalo", "RewardRibbonHorns", "RewardSlot", "RewardGlow",
		"RewardSparkle", "Toast", "BannerAlert", "GlyphCheck", "GlyphExclaim", "Star", "IconAnnounce" },
	-- handoff queue 3 (notice art): the approved Toast capsule (navy, gold rim, a gold ring socket on the left; 9-slice
	-- FitHeight, so the socket stays round and grows with the height) behind every toast once uploaded. The item / monster
	-- icon (or the kind's glyph) sits in the socket (centre DiscX x the height; GlyphK / IconK x the height), the words
	-- between the socket (CapL) and the round end (CapR); at least MinH / MinHIcon du, Lines lines at most ("..." after)
	-- The capsule may be WidthMult x the notify column (at most ScreenFrac of the screen; it stays centred on the column):
	-- phones have a narrow column and the socket + round end take room (UiSandbox 749x361: 2 lines cut a world toast)
	ToastArt = { Part = "Toast", MinH = 40, MinHIcon = 46, PadY = 7, DiscX = 49 / 102, GlyphK = 0.42, IconK = 0.5,
		CapL = 0.94, CapR = 0.42, Lines = 4, Slack = 10, -- Slack: du added to the measured words (rounding, the stroke)
		-- Lines 4 (검수 2026-10-08): on a narrow window a 2-part notice needs 4 lines; the reward words must not be cut
		WidthMult = 1.45, ScreenFrac = 0.62,
		Glyph = { good = { "GlyphCheck", Color3.fromRGB(80, 220, 120) }, bad = { "GlyphExclaim", Color3.fromRGB(255, 96, 86) },
			reward = { "Star", Color3.fromRGB(245, 197, 66) }, info = { "IconAnnounce" } } }, -- Star: white art, gold tint
	-- the big banner's red BannerAlert ribbon (world news: war, kaiju, bounty, the Pumpkin King). Its ends keep the size of
	-- the one-line banner (the column's banner height = "base"; SliceScale base / Base): more lines stretch only the 2 px
	-- middle band, so the words keep their room (FitHeight grew the tails with every line: UiSandbox phone 749x361 cut a
	-- 3-line banner to 10 letters a line). The tails take Side x base on each end, the red band is TextFrac x base around
	-- CenterY of the one-line art; white words with a dark red rim (approved note); the icon IconK x base (it may overlap
	-- the gold rims). The banner is WidthMult x the column, at most ScreenFrac of the screen
	AlertArt = { Part = "BannerAlert", Base = 133, Side = 0.6, CenterY = 0.445, TextFrac = 0.6, IconK = 0.9,
		WidthMult = 1.75, ScreenFrac = 0.62, Stroke = Color3.fromRGB(120, 10, 20) },
	AlertImg = nil, -- the banner's art ImageLabel (UIKit.Init) when BannerAlert is uploaded
	LaidH = nil, -- the banner height the words were last laid out for (the art's tails follow the height)
	-- Short screens (free height under CompactBelow du, phones): a wider plate, a smaller banner / slots / buttons and 16 du
	-- lines, so it fits without shrinking (a shrunk popup kept its words at the real-px floor and grew tall and narrow)
	Reward = { W = 440, BannerW = 340, BannerAspect = 512 / 178, TitleSize = 26, SlotSize = 76, SlotGap = 18,
		CompactBelow = 560, WideW = 620, BannerCompact = 270, SlotCompact = 58, ButtonHCompact = 48, LineSize = 18,
		LineCompact = 16, Count = 0.9,
		ButtonW = 230, ButtonH = 58, Panel = { Halo = "RewardPanelHalo", Horns = "RewardPanelHorns" },
		Banner = { Halo = "RewardRibbonHalo", Horns = "RewardRibbonHorns" }, Slot = "RewardSlot", Glow = "RewardGlow",
		Sparkle = "RewardSparkle",
		-- the faction parts (High, 1d58f6c; sheet art/review/s2/reward_hq_sheet.jpg): the curved ribbon is BannerOver x the
		-- plate (its wings / horns reach past the plate's sides), at most BannerArtW / BannerArtCompact du, with
		-- BannerArtAnchor of its height above the plate's top edge (the curls overlap the rim) and its title up to TitleArt /
		-- TitleArtCompact du in the part's TextRect. InnerPad: the body's margin inside the plate's Inner
		BannerOver = 1.16, BannerArtW = 520, BannerArtCompact = 380, BannerArtAnchor = 0.78, TitleArt = 36,
		TitleArtCompact = 26, InnerPad = 12,
		-- PC (검수 2026-10-07): the whole popup grows so the plate is PcFrac of the screen width (1280x720 ~490 px, 1080p
		-- the same share; body 16+ px, numbers / buttons 18+ px at 1280x720), at most GrowMax, and still fits under the top
		-- bar; touch screens (phones) keep the base size
		PcFrac = 0.38, GrowMax = 1.8,
		-- No rays (user 2026-10-07: the turning RewardRays looked like the Rising Sun flag; AGENTS: no ray bursts): a round
		-- soft glow (GlowOver x the banner, GlowAlpha) on the banner's centre, breathing between GlowPulse[1] and [2] in
		-- GlowPulse[3] s (still with ReducedMotion), in the faction tint (no faction: Tint.None), and the sparkles
		Tint = { Halo = Color3.fromRGB(255, 214, 96), Horns = Color3.fromRGB(255, 132, 60), None = Color3.fromRGB(255, 214, 96) },
		GlowOver = 1.25, GlowAlpha = 0.35, GlowPulse = { 0.94, 1.05, 1.6 },
		-- sparkles around the plate: { "B" (banner) | "P" (plate), x, y in that box's half sizes from its centre, du };
		-- each twinkles (grow + turn 45, shrink + turn 90) then rests SparkleRest s; still with ReducedMotion
		Sparkles = { { "B", -1.08, -0.4, 26 }, { "B", 1.1, 0.05, 20 }, { "B", -0.42, -1.3, 18 }, { "B", 0.52, -1.2, 24 },
			{ "B", -0.8, -1.15, 16 }, { "B", 0.05, -1.75, 22 }, { "B", 0.85, -0.95, 18 },
			{ "P", -1.12, 0.12, 22 }, { "P", 1.13, -0.32, 18 }, { "P", 1.1, 0.72, 26 }, { "P", -1.08, 0.88, 16 } },
		SparkleRest = { 0.5, 1.6 },
		SparkleTint = { Halo = Color3.fromRGB(255, 240, 180), Horns = Color3.fromRGB(255, 196, 140) } },
}

----------------------------------------------------------------- helpers
local function warnThrottled(msg)
	local now = os.clock()
	if now - lastWarnAt < 10 then return end
	lastWarnAt = now
	Util.Warn("UIKit", msg)
end

local function safeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warnThrottled("handler error: " .. tostring(err)) end
end

local function setProp(inst, key, value)
	local ok, err = pcall(function()
		inst[key] = value
	end)
	if not ok then
		warnThrottled("bad property " .. tostring(key) .. " on " .. inst.ClassName .. ": " .. tostring(err))
	end
end

local function sameFontFace(a, b)
	return typeof(a) == "Font" and typeof(b) == "Font"
		and a.Family == b.Family and a.Weight == b.Weight and a.Style == b.Style
end

-- Existing Enum.Font choices carry their body / title / number weight into the selected family. Returns the face and the
-- resolved weight (nil for a respected custom face). role: "Head" / "Body" (nil: ExtraBold = Head, else Body).
local function themeFontFace(weightOrEnum, role)
	if typeof(weightOrEnum) == "Font" then
		if not FONT.Ours(weightOrEnum) then return weightOrEnum, nil end
		weightOrEnum = weightOrEnum.Weight -- one of our faces: the same weight in the current language
	end
	local weight = Enum.FontWeight.Bold
	if typeof(weightOrEnum) == "EnumItem" then
		if weightOrEnum.EnumType == Enum.FontWeight then
			weight = weightOrEnum.Value >= Enum.FontWeight.ExtraBold.Value and Enum.FontWeight.ExtraBold
				or (weightOrEnum.Value >= Enum.FontWeight.SemiBold.Value and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
		elseif weightOrEnum.EnumType == Enum.Font and weightOrEnum ~= Enum.Font.Unknown then
			local name = weightOrEnum.Name
			if string.find(name, "Black", 1, true) or string.find(name, "Heavy", 1, true) then
				weight = Enum.FontWeight.ExtraBold
			elseif string.find(name, "Bold", 1, true) or name == "FredokaOne" then
				weight = Enum.FontWeight.Bold
			else
				weight = Enum.FontWeight.Regular
			end
		end
	elseif type(weightOrEnum) == "number" then
		weight = weightOrEnum >= 800 and Enum.FontWeight.ExtraBold
			or (weightOrEnum >= 600 and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
	elseif type(weightOrEnum) == "string" then
		weight = weightOrEnum == "ExtraBold" and Enum.FontWeight.ExtraBold
			or (weightOrEnum == "Regular" and Enum.FontWeight.Regular or Enum.FontWeight.Bold)
	end
	if role ~= "Head" and role ~= "Body" then role = weight == Enum.FontWeight.ExtraBold and "Head" or "Body" end
	return FONT.Face(role, weight), weight, role
end

-- role: "Head" (titles / buttons / numbers) or "Body"; nil keeps the text object's earlier role (ExtraBold = Head)
function UIKit.ApplyFont(textObj, weightOrEnum, role)
	if typeof(textObj) ~= "Instance" or not TEXT_CLASSES[textObj.ClassName] then return textObj end
	local state = FONT.States[textObj]
	if not state then
		state = { Connections = {}, Sequence = 0, Dead = false, Writing = false }
		FONT.States[textObj] = state
	end
	if state.Dead then return textObj end
	local source = weightOrEnum
	if source == nil then
		if textObj.Font ~= Enum.Font.Unknown then source = textObj.Font
		elseif textObj.FontFace.Family == UIKit.Theme.FontFace.Family then source = textObj.FontFace
		else source = UIKit.Theme.FontFace end
	end
	local face, weight, usedRole = themeFontFace(source, role or state.Role)
	state.Weight, state.Role = weight, usedRole -- nil weight = a respected custom face (a language switch skips it)
	state.Sequence += 1 -- invalidate an older deferred font request
	state.Writing = true
	local ok, err = pcall(function()
		if not sameFontFace(textObj.FontFace, face) then textObj.FontFace = face end
	end)
	state.Writing = false
	if ok then state.Written = face
	else warnThrottled("font failed: " .. tostring(err)) end
	return textObj
end

local function watchFont(textObj)
	if not TEXT_CLASSES[textObj.ClassName] then return end
	local state = FONT.States[textObj]
	if not state then
		-- Unknown identifies a directly assigned custom FontFace; respect it as an explicit choice.
		UIKit.ApplyFont(textObj, textObj.Font == Enum.Font.Unknown and textObj.FontFace or textObj.Font)
		state = FONT.States[textObj]
	end
	if state.Watched or state.Dead then return end
	state.Watched = true
	local function request()
		if state.Dead or state.Writing or sameFontFace(textObj.FontFace, state.Written) then return end
		state.Sequence += 1
		local sequence = state.Sequence
		task.defer(function()
			if state.Dead or state.Sequence ~= sequence or not textObj.Parent then return end
			if sameFontFace(textObj.FontFace, state.Written) then return end
			-- Our own FontFace writes report Font.Unknown. An external custom FontFace stays intact.
			local source = textObj.Font == Enum.Font.Unknown and textObj.FontFace or textObj.Font
			UIKit.ApplyFont(textObj, source)
		end)
	end
	for _, property in { "Font", "FontFace" } do
		table.insert(state.Connections, textObj:GetPropertyChangedSignal(property):Connect(request))
	end
	table.insert(state.Connections, textObj.Destroying:Connect(function()
		state.Dead = true
		state.Sequence += 1
		for _, connection in state.Connections do connection:Disconnect() end
		FONT.States[textObj] = nil
	end))
	request()
end

local function playClick()
	local fx = C and C.Fx
	if fx and type(fx.PlaySound) == "function" then
		pcall(fx.PlaySound, "Click")
	end
end

local function kindColor(kind)
	local T = UIKit.Theme
	if kind == "good" then return T.Good end
	if kind == "bad" then return T.Bad end
	if kind == "reward" then return T.Gold end
	return T.SubText
end

-- top bar inset in real pixels (addendum H4: fallback so blocks start at >= 64 px)
local function insetY()
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local y = (ok and typeof(topLeft) == "Vector2") and topLeft.Y or 0
	if y <= 0 then y = TOP_FALLBACK - TOP_PAD end
	return y
end

local function currentScale()
	local s = uiScale and uiScale.Scale or 1
	if s <= 0 then s = 1 end
	return s
end

-- review 2026-10-07: a mouse / keyboard PC in a short window keeps the desktop layout at a smaller UIScale; its real-px
-- text floors (readability rules made for phones) shrink with it below the 720p desktop scale (DESKTOP_MULT), so the
-- HUD stays one picture, only smaller - at UIScale 0.5 the floors had kept every word full size and they spilled out of
-- the halved HUD. Touch devices: 1 (the floors stand)
function UIKit.PxFloor()
	if UserInputService.TouchEnabled then return 1 end
	return math.min(1, currentScale() / DESKTOP_MULT)
end

local function applyScale()
	if not uiScale then return end
	local cam = workspace.CurrentCamera
	local vy = cam and cam.ViewportSize.Y or REF_HEIGHT
	if vy < 50 then vy = REF_HEIGHT end
	if UserInputService.TouchEnabled then
		uiScale.Scale = math.clamp(vy / REF_HEIGHT, SCALE_MIN, SCALE_MAX)
	else
		uiScale.Scale = math.clamp(vy / REF_HEIGHT * DESKTOP_MULT, DESKTOP_MIN, DESKTOP_MAX)
	end
	if toastHolder then
		-- CR-L38: on phones the stack covered the upgrade / release buttons
		local raw = cam and cam.ViewportSize or Vector2.zero
		toastMax = (raw.Y >= 50 and raw.Y < TOAST_PHONE.Height) and TOAST_PHONE.Max or MAX_TOASTS
		-- HUD v2: once UIKit.PlaceNotify has run, the HUD's notify column owns the stack's position and width
		if NOTIFY.Rect == nil then
			toastHolder.Position = UDim2.new(0.5, 0, 0, TOAST_Y + insetY() / currentScale())
			local w = TOAST_WIDTH
			if raw.X >= 50 then w = math.min(TOAST_WIDTH, raw.X / currentScale() * TOAST_PHONE.WidthFrac) end
			toastHolder.Size = UDim2.fromOffset(math.floor(w), 10)
		end
	end
	-- A23-35: style size floors are real px, so they follow the UI scale
	if STYLE.RefreshAll then STYLE.RefreshAll() end
end

local function bindCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		cameraConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	applyScale()
end

----------------------------------------------------------------- factories
-- Creates an instance, applies props (Parent last) and parents children (Instances, or { className, props, children }).
-- GuiObjects get BorderSizePixel 0; text objects get Theme.Font, white text and a UITextSizeConstraint
-- (MinTextSize = Config.UI.MinTextSize, addendum M1) unless the caller passes its own.
function UIKit.Create(className, props, children)
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		setProp(inst, "BorderSizePixel", 0)
	end
	local isText = TEXT_CLASSES[className] == true
	if isText then
		setProp(inst, "Font", UIKit.Theme.Font)
		setProp(inst, "TextColor3", UIKit.Theme.Text)
	end
	local parent = nil
	if type(props) == "table" then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif not (isText and key == "FontFace") then
				setProp(inst, key, value)
			end
		end
	end
	if isText then
		UIKit.ApplyFont(inst, type(props) == "table" and props.FontFace or inst.Font)
	end
	local hasSizeConstraint = false
	if type(children) == "table" then
		for _, child in children do
			local c = child
			if type(child) == "table" and type(child[1]) == "string" then
				c = UIKit.Create(child[1], child[2], child[3])
			end
			if typeof(c) == "Instance" then
				if c:IsA("UITextSizeConstraint") then hasSizeConstraint = true end
				c.Parent = inst
			end
		end
	end
	if isText and not hasSizeConstraint then
		local tc = Instance.new("UITextSizeConstraint")
		tc.MinTextSize = MIN_TEXT_SIZE
		tc.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(radius)
	return UIKit.Create("UICorner", { CornerRadius = radius or UDim.new(0, 12) })
end

----------------------------------------------------------------- motion: one button feel + window in / out
-- 검수 2026-10-06 (video lessons 9752093, docs/design/video_lessons_8pJGBz-J75w_2026-10-06.md): every button presses
-- the same way and every window opens the same way.
--   UIKit.ButtonFeel(button, opts): the child UIScale "PressScale" (made when missing; the button's own Size is never
--     touched) goes to Hover (mouse over, not on touch-only devices), Press while held, and springs back on release
--     (Back easing). opts.Fast = combat buttons: every step <= 0.08 s, no spring overshoot that delays the next press.
--   UIKit.FeelPress(button, down): the same press from code (keys, pad buttons, holds).
--   UIKit.ReducedMotion(): the 'Screen shake' setting off (Settings Shake = false) or Roblox's reduced motion: buttons
--     only dip to PressReduced and back at once (no grow, no spring), windows only fade (FadeOnly, no slide).
--   UIKit.WindowIn(frame) / UIKit.WindowOut(frame, onDone): fade + a short slide up (In / Out seconds); the fade walks
--     the window's descendants (their own transparency is the shown value, kept in MOTION.Bases); no CanvasGroup
--     (its text goes blurry). Panels / windows call these (게임성 개발 1 wires them).
local MOTION = {
	Hover = 1.08, Press = 0.94, PressReduced = 0.97,
	Down = 0.07, Up = 0.2, FastDown = 0.04, FastUp = 0.08, HoverTime = 0.12,
	In = 0.22, Out = 0.16, FadeOnly = 0.12, Slide = 12, -- seconds; Slide = px (logical) the window rises while it fades in
	States = setmetatable({}, { __mode = "k" }), -- [button] = { Hover, Down, Fast }
	Bases = setmetatable({}, { __mode = "k" }), -- [window] = { Token, Pos, List = { { inst, prop, base } } }
}

function UIKit.ReducedMotion()
	local settings = C and C.Settings
	if type(settings) == "table" and type(settings.Get) == "function" then
		local ok, shake = pcall(settings.Get, "Shake")
		if ok and shake == false then return true end
	end
	local ok, reduced = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and reduced == true
end

local function feelScale(btn)
	local sc = btn:FindFirstChild("PressScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "PressScale"
		sc.Parent = btn
	end
	return sc
end

-- moves the button's PressScale to where its state says (pressed > hovered > rest)
local function feelApply(btn)
	local st = MOTION.States[btn]
	if not st or not btn.Parent then return end
	local sc = feelScale(btn)
	if UIKit.ReducedMotion() then
		sc.Scale = st.Down and MOTION.PressReduced or 1
		return
	end
	local goal = st.Down and MOTION.Press or (st.Hover and MOTION.Hover or 1)
	local time, style = MOTION.HoverTime, Enum.EasingStyle.Quad
	if st.Down then
		time = st.Fast and MOTION.FastDown or MOTION.Down
	elseif st.WasDown then
		-- the release springs back (Back overshoot); combat buttons stay quick
		time, style = st.Fast and MOTION.FastUp or MOTION.Up, st.Fast and Enum.EasingStyle.Quad or Enum.EasingStyle.Back
	end
	st.WasDown = st.Down
	if st.Tween then st.Tween:Cancel() end
	st.Tween = TweenService:Create(sc, TweenInfo.new(time, style, Enum.EasingDirection.Out), { Scale = goal })
	st.Tween:Play()
end

function UIKit.FeelPress(btn, down)
	if typeof(btn) ~= "Instance" then return end
	local st = MOTION.States[btn]
	if not st then
		st = { Hover = false, Down = false, Fast = false }
		MOTION.States[btn] = st
	end
	down = down == true
	if st.Down == down then return end
	st.Down = down
	feelApply(btn)
end

function UIKit.ButtonFeel(btn, opts)
	if typeof(btn) ~= "Instance" or not btn:IsA("GuiObject") then return btn end
	opts = type(opts) == "table" and opts or {}
	local st = MOTION.States[btn]
	if st then
		st.Fast = opts.Fast == true or st.Fast
		return btn -- wired once
	end
	st = { Hover = false, Down = false, Fast = opts.Fast == true }
	MOTION.States[btn] = st
	feelScale(btn)
	local function usable()
		return btn.Active ~= false and btn:GetAttribute("Disabled") ~= true
	end
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and usable() then
			UIKit.FeelPress(btn, true)
		end
	end)
	btn.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then UIKit.FeelPress(btn, false) end
	end)
	-- hover grows only where a mouse points (touch-only devices fire MouseEnter on a tap)
	btn.MouseEnter:Connect(function()
		if not UserInputService.MouseEnabled or not usable() then return end
		st.Hover = true
		feelApply(btn)
	end)
	btn.MouseLeave:Connect(function()
		st.Hover = false
		if st.Down then
			UIKit.FeelPress(btn, false)
		else
			feelApply(btn)
		end
	end)
	return btn
end

-- fadeable properties under (and of) a window, with their shown values
local function windowFades(frame)
	local list = {}
	local function add(inst)
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			table.insert(list, { inst, "ImageTransparency", inst.ImageTransparency })
		end
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			table.insert(list, { inst, "TextTransparency", inst.TextTransparency })
		end
		if inst:IsA("UIStroke") then table.insert(list, { inst, "Transparency", inst.Transparency }) end
		if inst:IsA("GuiObject") and inst.BackgroundTransparency < 1 then
			table.insert(list, { inst, "BackgroundTransparency", inst.BackgroundTransparency })
		end
	end
	add(frame)
	for _, d in frame:GetDescendants() do add(d) end
	return list
end

local function windowTween(w, alpha, time, slideFrom, slideTo, onDone)
	w.Token += 1
	local token = w.Token
	local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, e in w.List do
		local inst, prop, base = e[1], e[2], e[3]
		if inst.Parent then
			TweenService:Create(inst, info, { [prop] = 1 - (1 - base) * alpha }):Play()
		end
	end
	if slideTo then
		if slideFrom then w.Frame.Position = slideFrom end
		TweenService:Create(w.Frame, info, { Position = slideTo }):Play()
	end
	task.delay(time, function()
		if w.Token ~= token then return end -- a newer in / out took over
		if onDone then onDone() end
	end)
end

function UIKit.WindowIn(frame)
	if typeof(frame) ~= "Instance" or not frame:IsA("GuiObject") then return end
	local w = MOTION.Bases[frame]
	if not w or not w.Busy then
		-- the window as built is the shown state
		w = { Frame = frame, Token = w and w.Token or 0, Pos = frame.Position, List = windowFades(frame) }
		MOTION.Bases[frame] = w
	end
	w.Busy = true
	frame.Visible = true
	for _, e in w.List do e[1][e[2]] = 1 end
	local reduced = UIKit.ReducedMotion()
	windowTween(w, 1, reduced and MOTION.FadeOnly or MOTION.In, (not reduced) and (w.Pos + UDim2.fromOffset(0, MOTION.Slide)) or nil,
		(not reduced) and w.Pos or nil, function()
			w.Busy = false
		end)
end

function UIKit.WindowOut(frame, onDone)
	if typeof(frame) ~= "Instance" or not frame:IsA("GuiObject") then
		if onDone then onDone() end
		return
	end
	local w = MOTION.Bases[frame]
	if not w or not w.Busy then
		w = { Frame = frame, Token = w and w.Token or 0, Pos = frame.Position, List = windowFades(frame) }
		MOTION.Bases[frame] = w
	end
	w.Busy = true
	local reduced = UIKit.ReducedMotion()
	windowTween(w, 0, reduced and MOTION.FadeOnly or MOTION.Out, nil,
		(not reduced) and (w.Pos + UDim2.fromOffset(0, MOTION.Slide / 2)) or nil, function()
			frame.Visible = false
			-- back to the shown values for the next open
			for _, e in w.List do
				if e[1].Parent then e[1][e[2]] = e[3] end
			end
			frame.Position = w.Pos
			w.Busy = false
			if onDone then onDone() end
		end)
end

-- quality ② (docs/design/quality_ideas_2026-10-06.md §1-②): a dialogue line appears letter by letter with the
-- speaker's blips (C.Audio.Talk(speaker), Config.Audio.Talk voices: the shard high and fast, the Horns guide low); a tap
-- (handle.Finish) shows the whole line at once. It reveals with MaxVisibleGraphemes, so the label keeps its final wrap
-- from the first frame (nothing jumps). Reduced motion (UIKit.ReducedMotion) = the whole line at once, one blip.
-- opts: Speed (letters / s, default UIKit.TypeSpeed.Default; a speaker's own in UIKit.TypeSpeed), Speaker, BlipEvery
-- (letters per blip, 2), OnDone(fn). A new call on the same label ends the old one. Returns a handle
-- { Finish(), Cancel(), Done() -> bool }. Panels wires it to the story lines (game dev 1).
UIKit.TypeSpeed = { Default = 38, Shard = 46 } -- letters per second
UIKit.Typing = setmetatable({}, { __mode = "k" }) -- [label] = its running handle
function UIKit.Typewriter(label, text, opts)
	opts = type(opts) == "table" and opts or {}
	if typeof(label) ~= "Instance" or not (label:IsA("TextLabel") or label:IsA("TextButton")) then return nil end
	local old = UIKit.Typing[label]
	if old then old.Cancel() end
	text = tostring(text or "")
	label.Text = text
	local total = utf8.len(text) or #text
	local speed = tonumber(opts.Speed) or UIKit.TypeSpeed[opts.Speaker] or UIKit.TypeSpeed.Default
	local blipEvery = math.max(1, math.floor(tonumber(opts.BlipEvery) or 2))
	local handle = { State = "typing" }
	local conn = nil
	local function blip()
		local audio = C and C.Audio
		if type(audio) == "table" and type(audio.Talk) == "function" then pcall(audio.Talk, opts.Speaker) end
	end
	local function stop(state)
		if handle.State ~= "typing" then return end
		handle.State = state
		if conn then conn:Disconnect() end
		conn = nil
		if UIKit.Typing[label] == handle then UIKit.Typing[label] = nil end
		label.MaxVisibleGraphemes = -1
		if state == "done" and type(opts.OnDone) == "function" then safeCall(opts.OnDone) end
	end
	handle.Finish = function() stop("done") end
	handle.Cancel = function() stop("cancelled") end
	handle.Done = function() return handle.State ~= "typing" end
	UIKit.Typing[label] = handle
	if total <= 0 or UIKit.ReducedMotion() then
		if total > 0 then blip() end
		stop("done")
		return handle
	end
	label.MaxVisibleGraphemes = 0
	local shown, nextBlip, started = 0, 1, os.clock()
	conn = game:GetService("RunService").Heartbeat:Connect(function()
		if not label.Parent then
			handle.Cancel()
			return
		end
		local n = math.min(total, math.floor((os.clock() - started) * speed))
		if n > shown then
			shown = n
			label.MaxVisibleGraphemes = n
			-- a blip every blipEvery letters, never on a space or punctuation
			if n >= nextBlip then
				local ok, ch = pcall(function() return string.sub(text, utf8.offset(text, n) or n, (utf8.offset(text, n + 1) or n + 1) - 1) end)
				if ok and type(ch) == "string" and string.match(ch, "[%w]") then blip() end
				nextBlip = n + blipEvery
			end
		end
		if shown >= total then stop("done") end
	end)
	return handle
end

-- the shared press feel (UIKit.ButtonFeel) + Click sound; onClick(button) runs on Activated unless the button has
-- Active == false or attribute Disabled == true (shared by UIKit.Button and UIKit.ArtButton). Attribute NoClick = true:
-- no Click (the button plays its own sound, e.g. the quest window's tabs QuestTab; game dev 1, sound_gaps 2026-10-10)
local function wirePress(btn, onClick)
	UIKit.ButtonFeel(btn)
	btn.Activated:Connect(function()
		if not btn.Active or btn:GetAttribute("Disabled") == true then return end
		if btn:GetAttribute("NoClick") ~= true then playClick() end
		if type(onClick) == "function" then
			safeCall(onClick, btn)
		end
	end)
end

-- props: Name, Text, Size, Position, AnchorPoint, Color, TextColor, TextSize, Parent (+ any TextButton property).
-- Adds UICorner, UIStroke ("Stroke"), a press-shrink UIScale ("PressScale") and the Click sound.
-- onClick(button) runs on Activated unless the button has Active == false or attribute Disabled == true.
function UIKit.Button(props, onClick)
	props = props or {}
	local p = {}
	local color, textColor = nil, nil
	for key, value in props do
		if key == "Color" then
			color = value
		elseif key == "TextColor" then
			textColor = value
		elseif key ~= "Parent" then
			p[key] = value
		end
	end
	if p.BackgroundColor3 == nil then p.BackgroundColor3 = color or Color3.fromRGB(60, 62, 85) end
	if p.TextColor3 == nil then p.TextColor3 = textColor or UIKit.Theme.Text end
	if p.TextSize == nil then p.TextSize = 18 end
	if p.AutoButtonColor == nil then p.AutoButtonColor = false end
	if p.Text == nil then p.Text = "" end

	local btn = UIKit.Create("TextButton", p, {
		corner(UDim.new(0, 12)),
		UIKit.Create("UIStroke", {
			Name = "Stroke",
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIKit.Create("UIScale", { Name = "PressScale" }),
	})
	wirePress(btn, onClick)

	if props.Parent then
		btn.Parent = props.Parent
	end
	return btn
end

-- transparent TextLabel in Theme.Font; TextColor (or Color) maps to TextColor3
function UIKit.Label(props)
	props = props or {}
	local p = { BackgroundTransparency = 1, TextSize = 18 }
	for key, value in props do
		if key == "TextColor" or key == "Color" then
			p.TextColor3 = value
		elseif key ~= "Parent" then
			p[key] = value
		end
	end
	if p.Text == nil then p.Text = "" end
	local label = UIKit.Create("TextLabel", p)
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- progress bar. props: Name, Size, Position, AnchorPoint, Parent, Color (fill), BgColor, Text, TextSize, ZIndex,
-- LayoutOrder, Visible. Returns (frame, setFraction(f, color?), textLabel).
function UIKit.Bar(props)
	props = props or {}
	local frameProps = {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.fromOffset(200, 16),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.BgColor or Color3.fromRGB(12, 12, 20),
		BackgroundTransparency = props.BgTransparency or 0.15,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
	}
	if props.ZIndex then frameProps.ZIndex = props.ZIndex end
	local frame = UIKit.Create("Frame", frameProps, { corner(UDim.new(0, 6)) })
	local fill = UIKit.Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or UIKit.Theme.Gold,
		Visible = false,
		Parent = frame,
	}, { corner(UDim.new(0, 6)) })
	local text = UIKit.Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "",
		TextSize = props.TextSize or 15,
		TextStrokeTransparency = 0.45,
		ZIndex = 2,
		Parent = frame,
	})
	local lastFraction = -1
	local function setFraction(f, color)
		f = tonumber(f) or 0
		if f ~= f then f = 0 end
		f = math.clamp(f, 0, 1)
		if color and typeof(color) == "Color3" then
			fill.BackgroundColor3 = color
		end
		if math.abs(f - lastFraction) < 0.0005 then return end
		lastFraction = f
		fill.Visible = f > 0.001
		fill.Size = UDim2.fromScale(f, 1)
	end
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame, setFraction, text
end

----------------------------------------------------------------- GPT art parts (Config.UIArt, addendum A14-3)
-- Every helper returns nil or the old code-drawn style when a part id is missing, so the HUD never breaks (IMG-R4).
local Art = {
	Cfg = type(Config.UIArt) == "table" and Config.UIArt or {},
	-- image-only properties, dropped when the code-drawn fallback is built instead
	OnlyKeys = {
		Image = true, ImageColor3 = true, ImageTransparency = true, ImageRectOffset = true, ImageRectSize = true,
		ScaleType = true, SliceCenter = true, SliceScale = true, TileSize = true, ResampleMode = true,
		HoverImage = true, PressedImage = true,
	},
	-- fallbackProps keys that style the fallback instead of being set as properties
	FallbackKeys = {
		Color = true, BackgroundColor3 = true, BackgroundTransparency = true, CornerRadius = true, Stroke = true,
		StrokeColor = true, StrokeThickness = true, StrokeTransparency = true,
	},
	-- ArtButton props that go to its "Label" child instead of the button
	LabelKeys = {
		Text = true, TextSize = true, TextColor = true, TextColor3 = true, Font = true, FontFace = true, TextStyle = true,
		MaxTextSize = true,
	},
}
Art.Parts = type(Art.Cfg.Parts) == "table" and Art.Cfg.Parts or {}
Art.Colors = type(Art.Cfg.Colors) == "table" and Art.Cfg.Colors or {}
Art.Fonts = type(Art.Cfg.Fonts) == "table" and Art.Cfg.Fonts or {}
Art.TextLabels = type(Art.Cfg.TextLabels) == "table" and Art.Cfg.TextLabels or {}
Art.TextBindings = {}
Art.TextFits = {}
Art.StyleFloor = setmetatable({}, { __mode = "k" }) -- label -> UIKit.StyleText minimum TextSize (logical units)

UIKit.ArtColors = Art.Colors -- Config.UIArt.Colors (Ink, Light, GoldText, Parchment, Navy, XPBlue, ...)
UIKit.ArtFonts = Art.Fonts -- Config.UIArt.Fonts (Title, Body, Number)

local function artColor(key, fallback)
	local c = Art.Colors[key]
	if typeof(c) == "Color3" then return c end
	return fallback
end

local function artFont(key, fallback)
	local f = Art.Fonts[key]
	if typeof(f) == "EnumItem" then return f end
	return fallback
end

-- part definition by short name ("PanelCard") or file name ("UIP_PanelCard"), even when its id is missing
local function rawPart(name)
	if type(name) ~= "string" then return nil end
	local def = Art.Parts[name]
	if def == nil and string.sub(name, 1, 4) == "UIP_" then
		def = Art.Parts[string.sub(name, 5)]
	end
	if type(def) ~= "table" then return nil end
	return def
end

local function validArtId(id)
	if type(id) ~= "string" then return false end
	local num = string.match(id, "^rbxassetid://(%d+)$")
	if num then return (tonumber(num) or 0) > 0 end
	return string.match(id, "^rbx%a+://.+") ~= nil
end

-- part definition only when it can be drawn (art enabled + uploaded id)
local function artPart(name)
	if Art.Cfg.Enabled == false then return nil end
	local def = rawPart(name)
	if def and validArtId(def.Id) then return def end
	return nil
end

local function toneColor(def)
	if def and type(def.Tone) == "string" then
		return artColor(def.Tone, nil)
	end
	return nil
end

local function addChildren(inst, children)
	if type(children) ~= "table" then return end
	for _, child in children do
		local c = child
		if type(child) == "table" and type(child[1]) == "string" then
			c = UIKit.Create(child[1], child[2], child[3])
		end
		if typeof(c) == "Instance" then
			c.Parent = inst
		end
	end
end

-- product of the UIScale objects on inst and its ancestors (MainGui has one)
local function inheritedScale(inst)
	local s = 1
	local node = inst
	for _ = 1, 60 do
		if node == nil or node == game then break end
		local sc = node:FindFirstChildOfClass("UIScale")
		if sc and sc.Scale > 0 then s *= sc.Scale end
		if node:IsA("LayerCollector") then break end
		node = node.Parent
	end
	return s
end

-- 9-slice edge scale that keeps the borders inside a w x h element (real px; scale = inherited UIScale).
-- min(real, real / scale) stays inside whether or not the engine applies UIScale to slice edges.
local function fitSliceScale(def, w, h, scale, base)
	local slice, size = def.Slice, def.Size
	if typeof(slice) ~= "Rect" or typeof(size) ~= "Vector2" then return base end
	if scale <= 0 then scale = 1 end
	local fw = math.min(w, w / scale)
	local fh = math.min(h, h / scale)
	local s = base
	if def.FitHeight == true and size.Y > 0 and fh > 0 then
		s = fh / size.Y -- capsule: edges follow the height
	end
	local bx = slice.Min.X + (size.X - slice.Max.X)
	local by = slice.Min.Y + (size.Y - slice.Max.Y)
	if bx > 0 and fw > 0 then s = math.min(s, fw / bx) end
	if by > 0 and fh > 0 then s = math.min(s, fh / by) end
	return math.max(s, 0.01)
end

-- Image / ScaleType / SliceCenter / SliceScale on an ImageLabel or ImageButton. Parts with Slice default to
-- ScaleType Slice, the rest to Fit. sliceScale = number fixes the edge scale; nil fits it now and on every resize.
local function applyArt(img, def, scaleType, sliceScale)
	img.Image = def.Id
	local sliced = typeof(def.Slice) == "Rect"
	if scaleType == nil then
		scaleType = sliced and Enum.ScaleType.Slice or Enum.ScaleType.Fit
	end
	img.ScaleType = scaleType
	if scaleType ~= Enum.ScaleType.Slice or not sliced then return end
	img.SliceCenter = def.Slice
	if type(sliceScale) == "number" then
		img.SliceScale = math.max(sliceScale, 0.01)
		return
	end
	local base = tonumber(def.SliceScale) or 0.5
	local function refit()
		local abs = img.AbsoluteSize
		local s
		if abs.X >= 1 and abs.Y >= 1 then
			s = fitSliceScale(def, abs.X, abs.Y, inheritedScale(img), base)
		else
			-- not laid out yet: estimate from the offset size (UI units)
			s = fitSliceScale(def, img.Size.X.Offset, img.Size.Y.Offset, 1, base)
		end
		if math.abs(img.SliceScale - s) > 0.002 then
			img.SliceScale = s
		end
	end
	refit()
	img:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
end

-- corner + inked rim for a code-drawn fallback (IMG-R4); reuses an existing UIStroke "Stroke" (UIKit.Button)
local function fallbackDecor(inst, fb, def)
	local radius = fb.CornerRadius
	if typeof(radius) ~= "UDim" then
		radius = (def and def.Round == true) and UDim.new(0.5, 0) or UDim.new(0, 12)
	end
	local c = inst:FindFirstChildOfClass("UICorner")
	if not c then
		c = UIKit.Create("UICorner", { Parent = inst })
	end
	c.CornerRadius = radius

	local stroke = inst:FindFirstChild("Stroke")
	if fb.Stroke == false then
		if stroke then stroke:Destroy() end
		return
	end
	local tone = def and def.Tone
	if not (stroke and stroke:IsA("UIStroke")) then
		stroke = UIKit.Create("UIStroke", {
			Name = "Stroke",
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
			Transparency = 0.4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = inst,
		})
	end
	-- toned parts get the storybook rim: gold around navy / red, inked brown around parchment / gold
	if tone == "Navy" or tone == "NavyDeep" or tone == "Red" then
		stroke.Color = artColor("Gold", UIKit.Theme.Gold)
		stroke.Transparency = 0
	elseif type(tone) == "string" then
		stroke.Color = artColor("Rim", Color3.fromRGB(110, 66, 24))
		stroke.Transparency = 0
	end
	if typeof(fb.StrokeColor) == "Color3" then stroke.Color = fb.StrokeColor end
	if tonumber(fb.StrokeThickness) then stroke.Thickness = tonumber(fb.StrokeThickness) end
	if tonumber(fb.StrokeTransparency) then stroke.Transparency = tonumber(fb.StrokeTransparency) end
end

-- shared body of InkText / LightText
local function artText(props, color, outlineColor, outlineTransparency, thickness)
	props = props or {}
	local p = { BackgroundTransparency = 1, TextSize = 16, Text = "", TextColor3 = color }
	local maxSize = nil
	for key, value in props do
		if key == "Color" or key == "TextColor" then
			p.TextColor3 = value
		elseif key == "MaxTextSize" then
			maxSize = tonumber(value)
		elseif key == "Outline" then
			outlineColor = value -- false = no outline, Color3 = custom colour
		elseif key == "OutlineTransparency" then
			outlineTransparency = tonumber(value) or outlineTransparency
		elseif key == "OutlineThickness" then
			thickness = tonumber(value) or thickness
		elseif key ~= "Parent" and key ~= "Number" and key ~= "Title" then
			p[key] = value
		end
	end
	if props.Font == nil then
		if props.Number then
			p.Font = artFont("Number", Enum.Font.FredokaOne)
		elseif props.Title then
			p.Font = artFont("Title", Enum.Font.GothamBlack)
		else
			p.Font = artFont("Body", UIKit.Theme.Font)
		end
	end
	p.Text = tostring(p.Text)
	if type(p.TextSize) == "number" and p.TextSize < MIN_TEXT_SIZE then
		p.TextSize = MIN_TEXT_SIZE
	end
	local children = {
		UIKit.Create("UITextSizeConstraint", {
			MinTextSize = MIN_TEXT_SIZE,
			MaxTextSize = math.max(maxSize or 100, MIN_TEXT_SIZE),
		}),
	}
	if typeof(outlineColor) == "Color3" then
		table.insert(children, UIKit.Create("UIStroke", {
			Name = "Outline",
			Color = outlineColor,
			Thickness = thickness,
			Transparency = outlineTransparency,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}))
	end
	local label = UIKit.Create("TextLabel", p, children)
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- brown ink text with a soft light outline, for parchment panels / pills / square buttons.
-- props: any TextLabel property (+ Parent) plus Color / TextColor, Number = true (FredokaOne), Title = true
-- (GothamBlack), MaxTextSize (cap for TextScaled), Outline (false or Color3), OutlineTransparency, OutlineThickness.
-- Always has a UITextSizeConstraint with MinTextSize = Config.UI.MinTextSize; TextSize is never below it.
function UIKit.InkText(props)
	return artText(props, artColor("Ink", Color3.fromRGB(66, 40, 18)),
		artColor("InkOutline", Color3.fromRGB(255, 247, 228)), 0.3, tonumber(Art.Cfg.OutlineInk) or 1)
end

-- white text with a dark outline, for the navy card, bars, ribbon and round buttons (Color = ArtColors.GoldText for
-- gold numbers). Same props as UIKit.InkText.
function UIKit.LightText(props)
	return artText(props, artColor("Light", Color3.new(1, 1, 1)),
		artColor("TextOutline", Color3.fromRGB(34, 20, 10)), 0, tonumber(Art.Cfg.OutlineLight) or 1.5)
end

-- "rbxassetid://..." of a part (short name or "UIP_" file name), or nil when missing / art disabled
function UIKit.ArtId(name)
	local def = artPart(name)
	return def and def.Id or nil
end

-- the Config.UIArt.Parts entry (Id, Size, Slice, ...) when the part can be drawn, else nil
function UIKit.ArtPart(name)
	return artPart(name)
end

-- image width / height of a part (1 when unknown); handy for UIAspectRatioConstraint
function UIKit.ArtAspect(name)
	local def = rawPart(name)
	if def and typeof(def.Size) == "Vector2" and def.Size.Y > 0 then
		return def.Size.X / def.Size.Y
	end
	return 1
end

-- A23-46 / A23-59 dialogue portraits (검수 2026-10-06): the PortraitFrame art (gold frame, its window an opaque sky
-- blue) with a character portrait (Config.UIArt.Parts "PTR_*") on that window - bottom-aligned, centred, clipped to the
-- window's rounded corners (a CanvasGroup with UICorner), as on art/review/s2/a2359_bright_girl_long_hair_frames.png.
-- Code fallbacks (IMG-R4): no frame art -> a navy plate with a gold rim and a sky window; no portrait art -> the
-- speaker's initial in the window. props: Name, Size, Position, AnchorPoint, ZIndex, Parent, Initial. Returns the
-- holder (it keeps the frame art's 512 : 498 shape; give it a Size, the width wins).
UIKit.PortraitWindow = { X = 0.107, Y = 0.116, W = 0.783, H = 0.759, Corner = 0.14 }
function UIKit.Portrait(key, props)
	props = type(props) == "table" and props or {}
	local z = tonumber(props.ZIndex) or 1
	local win = UIKit.PortraitWindow
	local holder = UIKit.Create("Frame", {
		Name = props.Name or "Portrait",
		Size = props.Size or UDim2.fromOffset(120, 117),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		ZIndex = z,
	}, { UIKit.Create("UIAspectRatioConstraint", { AspectRatio = 512 / 498 }) })
	local frame = UIKit.ArtImage("PortraitFrame", { Name = "Frame", Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = holder })
	if not frame then
		frame = UIKit.Create("Frame", {
			Name = "Frame", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(26, 40, 79), ZIndex = z,
			Parent = holder,
		}, {
			UIKit.Create("UICorner", { CornerRadius = UDim.new(0.16, 0) }),
			UIKit.Create("UIStroke", { Color = UIKit.Theme.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		UIKit.Create("Frame", {
			Name = "Sky", Position = UDim2.fromScale(win.X, win.Y), Size = UDim2.fromScale(win.W, win.H),
			BackgroundColor3 = Color3.fromRGB(150, 205, 250), ZIndex = z, Parent = frame,
		}, { UIKit.Create("UICorner", { CornerRadius = UDim.new(win.Corner, 0) }) })
	end
	-- the window clips the picture to its rounded corners; the frame's own sky shows behind a transparent portrait
	local window = UIKit.Create("CanvasGroup", {
		Name = "Window", Position = UDim2.fromScale(win.X, win.Y), Size = UDim2.fromScale(win.W, win.H),
		BackgroundTransparency = 1, ZIndex = z + 1, Parent = holder,
	}, { UIKit.Create("UICorner", { CornerRadius = UDim.new(win.Corner, 0) }) })
	local pic = type(key) == "string" and UIKit.ArtImage(key, {
		Name = "Picture", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = window,
	}) or nil
	if pic then
		-- fit inside the window, keeping the picture's shape; anchored at the bottom centre
		UIKit.Create("UIAspectRatioConstraint", { AspectRatio = UIKit.ArtAspect(key), Parent = pic })
	else
		local initial = props.Initial or (type(key) == "string" and string.match(key, "([A-Z])[a-z]*$")) or "?"
		UIKit.LightText({
			Name = "Picture", Text = initial, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6), TextScaled = true, ZIndex = z + 1, Parent = window,
		})
	end
	if props.Parent then holder.Parent = props.Parent end
	return holder
end

-- content area of a part (Inner rect: portrait hole, button face, badge centre, bar interior) as scale UDim2s
-- (position, size) relative to the part's box; exact when the box has the part's aspect (ArtAspect).
-- Works even when the id is missing (fallback layouts line up). nil when the part has no Inner.
function UIKit.ArtInner(name)
	local def = rawPart(name)
	if not def or typeof(def.Inner) ~= "Rect" or typeof(def.Size) ~= "Vector2" then return nil end
	local s, r = def.Size, def.Inner
	if s.X <= 0 or s.Y <= 0 then return nil end
	return UDim2.fromScale(r.Min.X / s.X, r.Min.Y / s.Y),
		UDim2.fromScale((r.Max.X - r.Min.X) / s.X, (r.Max.Y - r.Min.Y) / s.Y)
end

-- addendum U7: avatar headshot thumbnail id (no upload needed); userId defaults to the local player
function UIKit.HeadshotImage(userId)
	local id = tonumber(userId) or (LocalPlayer and LocalPlayer.UserId) or 0
	-- 검수 2026-10-08: the bust (head + shoulders) like the 3D portrait, not the face-filling head shot
	return "rbxthumb://type=AvatarBust&id=" .. tostring(math.floor(id)) .. "&w=150&h=150"
end

-- ImageLabel for a part, or nil when the part is missing (the caller falls back). Frames (parts with Slice) use
-- ScaleType Slice with an auto-fitted SliceScale (pass SliceScale = n to fix it); icons / round parts use Fit.
-- props: any ImageLabel property (+ Parent); BackgroundTransparency defaults to 1.
function UIKit.ArtImage(name, props)
	local def = artPart(name)
	if not def then return nil end
	props = props or {}
	local p = { BackgroundTransparency = 1 }
	for key, value in props do
		if key ~= "Parent" and key ~= "Image" and key ~= "ScaleType" and key ~= "SliceScale" then
			p[key] = value
		end
	end
	local img = UIKit.Create("ImageLabel", p)
	applyArt(img, def, props.ScaleType, props.SliceScale)
	if props.Parent then
		img.Parent = props.Parent
	end
	return img
end

-- "내 캐릭터" icon part (BB13 menu, …): attribute CharacterGender "F" -> IconCharacterF, else IconCharacter.
-- Falls back to IconCharacter while IconCharacterF has no id; nil when neither can be drawn (the caller falls back).
function UIKit.CharacterIconKey(player)
	local p = player or LocalPlayer
	if p and p:GetAttribute("CharacterGender") == "F" and artPart("IconCharacterF") then
		return "IconCharacterF"
	end
	return artPart("IconCharacter") and "IconCharacter" or nil
end

-- ArtImage of CharacterIconKey() for the local player that redraws when CharacterGender changes (props as
-- ArtImage); nil when neither icon can be drawn. The attribute connection ends with the label.
function UIKit.CharacterIcon(props)
	local key = UIKit.CharacterIconKey()
	local img = key and UIKit.ArtImage(key, props) or nil
	if not img or not LocalPlayer then return img end
	local conn = LocalPlayer:GetAttributeChangedSignal("CharacterGender"):Connect(function()
		local def = artPart(UIKit.CharacterIconKey() or "")
		if def then applyArt(img, def, props and props.ScaleType, props and props.SliceScale) end
	end)
	img.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return img
end

-- Item art (bag rows, drop notices, …). `id` is a Config.Loot.Items id (its Icon part, plus an optional IconBand part:
-- a tint mask on the same canvas, drawn over the body in the item's Color) or a plain Config.UIArt part key.
-- Returns the body ArtImage (the band is its child "Band", same box), or nil when the art is missing (caller falls back).
-- The band follows the body's ImageTransparency and ImageColor3 (a dim / locked tint multiplies the item colour).
function UIKit.ItemIcon(id, props)
	local items = type(Config.Loot) == "table" and Config.Loot.Items or nil
	local item = type(id) == "string" and type(items) == "table" and items[id] or nil
	local key = type(item) == "table" and item.Icon or id
	local img = type(key) == "string" and UIKit.ArtImage(key, props) or nil
	if not img or type(item) ~= "table" or type(item.IconBand) ~= "string" then return img end
	local band = UIKit.ArtImage(item.IconBand, { Name = "Band", Size = UDim2.fromScale(1, 1), ZIndex = img.ZIndex })
	if not band then return img end
	local tint = typeof(item.Color) == "Color3" and item.Color or Color3.new(1, 1, 1)
	local function follow()
		local c = img.ImageColor3
		band.ImageColor3 = Color3.new(tint.R * c.R, tint.G * c.G, tint.B * c.B)
		band.ImageTransparency = img.ImageTransparency
	end
	follow()
	img:GetPropertyChangedSignal("ImageColor3"):Connect(follow)
	img:GetPropertyChangedSignal("ImageTransparency"):Connect(follow)
	band.Parent = img
	return img
end

-- FontFace metrics include Hangul. Each yielding request owns its params; successful results are exact canvas
-- units and cached. Conservative glyph estimates are used only if the font-bound measurement fails.
function UIKit.MeasureText(text, size, fontOrFontFace, width)
	text = tostring(text or "")
	size = tonumber(size) or 18
	width = tonumber(width) or 10000
	if size ~= size or size <= 0 or size == math.huge then size = 18 end
	if width ~= width or width <= 0 or width == math.huge then width = 10000 end
	width = math.max(1, width)
	local face = themeFontFace(fontOrFontFace)
	local key = face.Family .. "/" .. face.Weight.Name .. "/" .. face.Style.Name
		.. "/" .. tostring(size) .. "/" .. tostring(width) .. "/" .. text
	local cached = FONT.MeasureCache[key]
	if cached then return cached.Y, cached.X, true end
	local params = nil
	local ok, measured = pcall(function()
		params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Size = size
		params.Font = face
		params.Width = width
		return TextService:GetTextBoundsAsync(params)
	end)
	if params then params:Destroy() end
	if ok and typeof(measured) == "Vector2" and measured.X >= 0 and measured.Y >= 0
		and measured.X < math.huge and measured.Y < math.huge then
		if FONT.CacheCount >= 512 then FONT.MeasureCache = {}; FONT.CacheCount = 0 end
		if FONT.MeasureCache[key] == nil then FONT.CacheCount += 1 end
		FONT.MeasureCache[key] = measured
		return measured.Y, measured.X, true
	end
	-- Unknown is the normal Enum.Font value of a custom FontFace; never send it to the legacy API.
	local legacyFont = UIKit.Theme.Font
	if typeof(fontOrFontFace) == "EnumItem" and fontOrFontFace.EnumType == Enum.Font
		and fontOrFontFace ~= Enum.Font.Unknown then legacyFont = fontOrFontFace end
	local legacyOk, legacyMeasured = pcall(function()
		return TextService:GetTextSize(text, size, legacyFont, Vector2.new(width, 10000))
	end)
	local line, widest, lines = 0, 0, 1
	local valid = pcall(function()
		for _, code in utf8.codes(text) do
			if code == 10 then
				widest, line, lines = math.max(widest, line), 0, lines + 1
			else
				local advance = size * (code == 32 and 0.35 or (code < 128 and 0.62 or 1.05))
				if line > 0 and line + advance > width then
					widest, line, lines = math.max(widest, line), 0, lines + 1
				end
				line += advance
			end
		end
	end)
	if not valid then line = math.min(width, #text * size); lines = math.max(1, math.ceil(#text * size / width)) end
	widest = math.max(widest, line)
	local height = lines * size * 1.25
	if legacyOk and typeof(legacyMeasured) == "Vector2" then
		return math.max(height, legacyMeasured.Y), math.max(widest, legacyMeasured.X), false
	end
	return height, widest, false
end

-- TextSize is a canvas size. The rendered picker never goes below the observed physical 11px floor.
-- Measure the complete text in those physical pixels before comparing it with AbsoluteSize / TextBounds.
function UIKit.MeasureRenderedText(text, size, fontOrFontFace, scale, width)
	size, scale = tonumber(size) or 18, tonumber(scale) or 1
	if scale ~= scale or scale <= 0 or scale == math.huge then scale = 1 end
	if size ~= size or size <= 0 or size == math.huge then size = 18 end
	local pixelSize = math.max(MIN_TEXT_SIZE, size * scale)
	local height, measuredWidth, exact = UIKit.MeasureText(text, pixelSize, fontOrFontFace, width)
	return height, measuredWidth, exact, pixelSize
end

-- UIKit.FitText passes: a label runs at most one pass a frame (Frame counts Heartbeats; a 2nd request in the same frame
-- waits for the next one) and at most BurstPasses follow-ups within BurstSeconds (the next real change starts a new
-- burst). Main Play 2026-10-08: 9x "Maximum re-entrancy depth (80) exceeded calling task.defer" - each pass changed
-- TextSize, whose deferred signals deferred the next pass from inside the last one, 80 deep in one frame
local FIT = { BurstPasses = 24, BurstSeconds = 1, Frame = 0 }
game:GetService("RunService").Heartbeat:Connect(function() FIT.Frame += 1 end)
function FIT.NextFrame(fn) task.delay(0, fn) end

-- Designated picker labels only. Start at the layout's maximum and shrink from rendered TextBounds. A label
-- may request whole FontFace metrics too: clipped/wrapped TextBounds can describe just the visible prefix.
-- Only successful font-service measurements participate; fallback estimates never pin a label to its minimum.
function UIKit.FitText(label, minSize, maxSize)
	local fit = Art.TextFits[label]
	if not fit then
		fit = { Connections = {}, Queued = false, Running = false, Pending = false, Reset = false, Dead = false, Version = 0,
			Burst = 0, BurstAt = -math.huge, Settle = false }
		Art.TextFits[label] = fit
		fit.Request = function(reset)
			if fit.Dead then return end
			fit.Reset = fit.Reset or reset == true
			if reset then fit.Version += 1 end
			if fit.Queued or fit.Running then fit.Pending = true; return end
			fit.Queued = true
			-- this frame's pass already ran: the next one waits a frame (task.delay 0) instead of deferring again
			local schedule = fit.PassFrame == FIT.Frame and FIT.NextFrame or task.defer
			schedule(function()
				fit.Queued = false
				if fit.Dead or not label.Parent then return end
				-- at most FIT.BurstPasses passes in FIT.BurstSeconds (whoever asks: a follow-up or a signal), then one more
				-- when the burst is over, so a label whose size and box keep changing each other cannot run every frame and
				-- is never left at a reset's maximum
				local now = os.clock()
				if now - fit.BurstAt > FIT.BurstSeconds then fit.BurstAt, fit.Burst = now, 0 end
				fit.Burst += 1
				if fit.Burst > FIT.BurstPasses then
					if not fit.Settle then
						fit.Settle = true
						task.delay(FIT.BurstSeconds, function()
							fit.Settle = false
							fit.Request(false)
						end)
					end
					return
				end
				fit.Running = true
				fit.PassFrame = FIT.Frame
				pcall(function()
					local box = label.AbsoluteSize
					if box.X <= 0 or box.Y <= 0 then return end
					local size = label.TextSize
					if fit.Reset then
						fit.Reset = false
						label.TextSize = fit.Max
						-- Measure after the renderer has seen the new maximum, including when it was unchanged.
						fit.Pending = true
						return
					end
					local bounds = label.TextBounds
					if label:GetAttribute("PickerMeasureWhole") == true then
						local text, face, wrapped, version = label.Text, label.FontFace, label.TextWrapped, fit.Version
						local measuredH, measuredW, exact, pixelSize = UIKit.MeasureRenderedText(text, size, face,
							inheritedScale(label), wrapped and math.max(1, box.X - 0.5) or 10000)
						-- Loading a font yields. Never apply an earlier text/layout/font measurement after a reset.
						if fit.Dead or not label.Parent or fit.Version ~= version or label.Text ~= text
							or label.FontFace.Family ~= face.Family or label.FontFace.Weight ~= face.Weight
							or label.FontFace.Style ~= face.Style or label.TextWrapped ~= wrapped
							or label.TextSize ~= size or label.AbsoluteSize ~= box then return end
						if exact then
							bounds = Vector2.new(math.max(bounds.X, measuredW), math.max(bounds.Y, measuredH))
							label:SetAttribute("PickerFullTextWidth", measuredW)
							label:SetAttribute("PickerFullTextHeight", measuredH)
							label:SetAttribute("PickerPhysicalTextSize", pixelSize)
						end
					end
					local padX = label:GetAttribute("PickerFitPaddingX") or 0.5
					local factor = math.min(1, math.max(1, box.X - padX) / math.max(1, bounds.X),
						math.max(1, box.Y - 0.25) / math.max(1, bounds.Y))
					if factor < 1 then size = math.clamp(math.floor(size * factor), fit.Min, fit.Max) end
					if size ~= label.TextSize then label.TextSize = size; fit.Pending = true end
					local outline = label:FindFirstChild("Outline")
					local limit = label:GetAttribute("PickerOutlineThickness")
					if outline and outline:IsA("UIStroke") and type(limit) == "number" then
						outline.Thickness = math.min(limit, math.max(0.6, size * (label:GetAttribute("PickerOutlineRatio") or 0.06)))
					end
				end)
				fit.Running = false
				-- the follow-up goes to the next frame (Request sees PassFrame == FIT.Frame)
				if not fit.Dead and (fit.Pending or fit.Reset) then fit.Pending = false; fit.Request(false) end
			end)
		end
		for _, property in { "Text", "AbsoluteSize", "TextWrapped", "FontFace" } do
			table.insert(fit.Connections, label:GetPropertyChangedSignal(property):Connect(function() fit.Request(true) end))
		end
		table.insert(fit.Connections, label:GetPropertyChangedSignal("TextBounds"):Connect(function() fit.Request(false) end))
		table.insert(fit.Connections, label.Destroying:Connect(function()
			fit.Dead = true
			for _, connection in fit.Connections do connection:Disconnect() end
			Art.TextFits[label] = nil
		end))
	end
	-- Picker layout minima include inverse UIScale for card geometry; do not reuse that as a raw font minimum.
	fit.BaseMin = math.max(1, math.min(math.floor(minSize), MIN_TEXT_SIZE))
	fit.BaseMax = math.max(fit.BaseMin, math.floor(maxSize))
	-- A23-35: a UIKit.StyleText floor wins over the picker minimum (unstyled labels: no floor, same as before)
	local styleFloor = Art.StyleFloor[label]
	fit.Min = math.max(fit.BaseMin, styleFloor or 0)
	fit.Max = math.max(fit.BaseMax, fit.Min)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint and styleFloor and constraint.MaxTextSize < fit.Min then constraint.MaxTextSize = fit.Max end
	if constraint then constraint.MinTextSize = fit.Min end
	label.TextScaled = false
	label.TextTruncate = Enum.TextTruncate.None
	label.ClipsDescendants = true
	fit.Request(true)
	return label
end

----------------------------------------------------------------- text styles (A23-35)
-- Self-check / contract (A23-35 + the same-day correction 143c50c: every letter stays a TextLabel, no image lettering):
--  * UIKit.TextStyles holds the only 5 styles: Title, Button, Body, Number, NameTag. Weight = a face of the game
--    font, Size = default logical TextSize (UIKit.StyledLabel only), MinPx = REAL pixel floor (UI rubric, item 2).
--  * UIKit.StyleText(label, name, onLight) restyles a TextLabel / TextButton / TextBox in place and returns it.
--    onLight ~= true (dark plate, bar, over the 3D world): white text + "StyleGradient" white -> cream #FFECBE
--    (top -> bottom) + "StyleStroke" navy #1B2140 (Round, Contextual), 1.5 / 2 / 3 px for <= 16 / <= 28 / larger
--    rendered text px. onLight == true (parchment, cream ribbon): navy #1B2140 text, gradient and stroke disabled.
--    Both modes switch off the legacy TextStroke shadow; another Contextual UIStroke ("Outline") becomes the style rim
--    (Roblox draws only one contextual rim, and a disabled older one would hide the style rim): one rim only.
--  * Re-applying reuses StyleStroke / StyleGradient (never stacks children) and keeps one watcher per label.
--  * The floor follows the screen UIScale: UITextSizeConstraint.MinTextSize = ceil(MinPx / scale) logical units; a
--    fixed TextSize is raised to it (the caller's own size comes back when the floor drops); a UIKit.FitText label
--    gets it as its picker minimum instead. Floor and stroke re-run on TextSize / AbsoluteSize / TextBounds /
--    TextScaled / parent changes and on every UIScale change (applyScale).
--  * Text is never touched. AutoLocalize is switched off game-wide by ClientMain (A23-48 English only: Roblox's
--    automatic translation would show the English text in the player's Roblox language).
--  * UIGradient also tints a visible background: style transparent labels. To fade a dark-style label, tween its
--    StyleStroke.Transparency with TextTransparency.
-- Families come from FONT.Sets (A23-48 English only, A23-63): Denk One (Face = "Head") + Montserrat (Face = "Body").
UIKit.TextStyles = {
	Title = { Weight = Enum.FontWeight.ExtraBold, Size = 28, MinPx = 16, Face = "Head" }, -- window / ribbon titles, big notices
	Button = { Weight = Enum.FontWeight.ExtraBold, Size = 20, MinPx = 16, Face = "Head" }, -- rubric: button text >= 16 px
	Body = { Weight = Enum.FontWeight.Regular, Size = 16, MinPx = 14, Face = "Body" }, -- rubric: phone body >= 14 px
	Number = { Weight = Enum.FontWeight.Bold, Size = 18, MinPx = 12, Face = "Head" }, -- bars, prices, counters (tight slots)
	NameTag = { Weight = Enum.FontWeight.Bold, Size = 14, MinPx = 12, Face = "Body" }, -- rubric: name tags >= 12 px
}

-- screen-wide UIScale above a label: MainGui's (also while unparented), else its own LayerCollector's.
-- Press / pop UIScales on buttons are ignored, so pressing never moves the floor.
function STYLE.Scale(label)
	local root = label:FindFirstAncestorWhichIsA("LayerCollector")
	if root == nil or root == UIKit.Gui then return currentScale() end
	local sc = root:FindFirstChildOfClass("UIScale")
	return (sc and sc.Scale > 0) and sc.Scale or 1
end

-- rendered text height in real px (TextScaled: the measured text, capped by its MaxTextSize)
function STYLE.TextPx(label, scale)
	if not label.TextScaled then return label.TextSize * scale end
	local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
	local h = label.TextBounds.Y
	if h <= 0 then h = label.AbsoluteSize.Y end
	return math.min(h, (tc and tc.MaxTextSize or 100) * scale)
end

function STYLE.Thickness(px)
	for _, tier in STYLE.StrokeTiers do
		if px <= tier[1] then return tier[2] end
	end
	return 3
end

-- min / max on a UITextSizeConstraint in a legal order (min never above max)
function STYLE.SetConstraint(st, tc, minSize, maxSize)
	minSize = math.clamp(minSize, 1, 100)
	maxSize = math.clamp(math.max(maxSize, minSize), 1, 100)
	st.WrittenMax = maxSize
	if minSize > tc.MaxTextSize then
		tc.MaxTextSize = maxSize
		tc.MinTextSize = minSize
	else
		if tc.MinTextSize ~= minSize then tc.MinTextSize = minSize end
		if tc.MaxTextSize ~= maxSize then tc.MaxTextSize = maxSize end
	end
end

-- the label's UITextSizeConstraint (created when missing); remembers the caller's MaxTextSize as BaseMax
function STYLE.Constraint(label, st)
	local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not tc then
		tc = UIKit.Create("UITextSizeConstraint", { MinTextSize = MIN_TEXT_SIZE, Parent = label })
	end
	if st.Constraint ~= tc then
		if st.MaxConn then st.MaxConn:Disconnect() end
		st.Constraint, st.BaseMax, st.WrittenMax = tc, tc.MaxTextSize, nil
		st.MaxConn = tc:GetPropertyChangedSignal("MaxTextSize"):Connect(function()
			if tc.MaxTextSize == st.WrittenMax then st.WrittenMax = nil else st.BaseMax = tc.MaxTextSize end
			st.Queue()
		end)
	end
	return tc
end

-- size floor + stroke tier for the current scale / text size (runs deferred and pcall'd through st.Queue)
function STYLE.Refresh(label)
	local st = STYLE.States[label]
	local def = st and UIKit.TextStyles[st.Style]
	if not def or st.Dead then return end
	local scale = STYLE.Scale(label)
	-- a label may lower its floor with the attribute StyleMinPx (A23-48: English icon tile names such as 'Settings'
	-- shrink inside the tile down to 10 px, 검수 2026-10-06)
	local minPx = (tonumber(label:GetAttribute("StyleMinPx")) or def.MinPx) * UIKit.PxFloor()
	-- ceil, not floor: floor(14 / 0.75) = 18 would render 13.5 px, under the rubric's 14
	local floorSize = math.clamp(math.ceil(minPx / scale - 0.001), 1, 100)
	-- UiSandbox 2026-10-08 (TextBounds at 991x451): Roblox applies UITextSizeConstraint in screen px - UIScale does not
	-- reach it - so this floor renders as floorSize real px (the approved PC 0.8 and phone 0.75 looks were judged that
	-- way). A PC window under the 0.8 desktop scale shrinks it once more with the window, so the words shrink with the
	-- halved boxes instead of spilling out of them (the quest line, notices, the Shop cards)
	if not UserInputService.TouchEnabled then
		floorSize = math.clamp(math.ceil(floorSize * UIKit.PxFloor() - 0.001), 1, 100)
	end
	Art.StyleFloor[label] = floorSize
	local tc = STYLE.Constraint(label, st)
	local fit = Art.TextFits[label]
	if fit and not fit.Dead and fit.BaseMin then
		-- UIKit.FitText owns TextSize: raise its picker minimum instead of writing TextSize (no tug of war)
		local newMin = math.max(fit.BaseMin, floorSize)
		local newMax = math.max(fit.BaseMax, newMin)
		if newMin ~= fit.Min or newMax ~= fit.Max or tc.MinTextSize ~= newMin then
			fit.Min, fit.Max = newMin, newMax
			STYLE.SetConstraint(st, tc, newMin, math.max(tc.MaxTextSize, newMin))
			fit.Request(true)
		end
	else
		STYLE.SetConstraint(st, tc, floorSize, math.max(st.BaseMax or 100, floorSize))
		if not label.TextScaled then
			local want = math.max(st.Base, floorSize)
			if label.TextSize ~= want then
				st.Written = want
				label.TextSize = want
			end
		end
	end
	local stroke = label:FindFirstChild("StyleStroke")
	if stroke and stroke:IsA("UIStroke") and stroke.Enabled then
		local thickness = STYLE.Thickness(STYLE.TextPx(label, scale))
		if stroke.Thickness ~= thickness then stroke.Thickness = thickness end
	end
end

-- one watcher per styled label; ends with the label
function STYLE.Track(label)
	local st = { Style = nil, OnLight = false, Connections = {}, Queued = false, Dead = false, Base = label.TextSize }
	STYLE.States[label] = st
	st.Queue = function()
		if st.Queued or st.Dead then return end
		st.Queued = true
		task.defer(function()
			st.Queued = false
			if st.Dead then return end
			local ok, err = pcall(STYLE.Refresh, label)
			if not ok then warnThrottled("text style refresh failed: " .. tostring(err)) end
		end)
	end
	table.insert(st.Connections, label:GetPropertyChangedSignal("TextSize"):Connect(function()
		-- our own floor write is not the caller's size; any other write is (it comes back when the floor drops)
		if label.TextSize == st.Written then st.Written = nil else st.Base = label.TextSize end
		st.Queue()
	end))
	for _, property in { "AbsoluteSize", "TextBounds", "TextScaled" } do
		table.insert(st.Connections, label:GetPropertyChangedSignal(property):Connect(st.Queue))
	end
	table.insert(st.Connections, label.AncestryChanged:Connect(st.Queue))
	table.insert(st.Connections, label.Destroying:Connect(function()
		st.Dead = true
		for _, connection in st.Connections do connection:Disconnect() end
		if st.MaxConn then st.MaxConn:Disconnect() end
		STYLE.States[label] = nil
		Art.StyleFloor[label] = nil
	end))
	return st
end

STYLE.RefreshAll = function()
	for _, st in STYLE.States do st.Queue() end
end

-- Applies one of UIKit.TextStyles to an existing text object (see the contract above). onLight = true on parchment /
-- cream plates. Unknown style or non-text object: returned unchanged. Safe to call again with another style / mode.
function UIKit.StyleText(label, styleName, onLight)
	if typeof(label) ~= "Instance" or not TEXT_CLASSES[label.ClassName] then return label end
	local def = UIKit.TextStyles[styleName]
	if type(def) ~= "table" then
		warnThrottled("unknown text style " .. tostring(styleName))
		return label
	end
	local light = onLight == true
	local st = STYLE.States[label] or STYLE.Track(label)
	if st.Dead then return label end
	st.Style, st.OnLight = styleName, light
	UIKit.ApplyFont(label, def.Weight, def.Face)
	setProp(label, "TextColor3", light and STYLE.Navy or STYLE.White)
	setProp(label, "TextStrokeTransparency", 1) -- never the white-with-shadow look, in either mode
	local stroke, gradient = nil, nil
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") and child.Name == "StyleStroke" and stroke == nil then
			stroke = child
		elseif child:IsA("UIGradient") and child.Name == "StyleGradient" and gradient == nil then
			gradient = child
		end
	end
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") and child ~= stroke and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			-- Roblox draws one contextual rim per text, and an older one (InkText / LightText "Outline") wins over the
			-- style's even while disabled (UiSandbox 2026-10-06: no rim at all) -> it becomes the style's rim instead
			if stroke == nil then
				child.Name = "StyleStroke"
				stroke = child
			else
				child:Destroy()
			end
		end
	end
	if light then
		if stroke then stroke.Enabled = false end
		if gradient then gradient.Enabled = false end
	else
		stroke = stroke or UIKit.Create("UIStroke", { Name = "StyleStroke", Parent = label })
		stroke.Color = STYLE.Navy
		stroke.Transparency = 0
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Thickness = STYLE.Thickness(STYLE.TextPx(label, STYLE.Scale(label)))
		stroke.Enabled = true
		gradient = gradient or UIKit.Create("UIGradient", { Name = "StyleGradient", Parent = label })
		gradient.Rotation = 90 -- keypoint 0 at the top
		gradient.Color = ColorSequence.new(STYLE.White, STYLE.Cream)
		gradient.Enabled = true
	end
	label:SetAttribute("UIKitTextStyle", light and (styleName .. "/Light") or styleName) -- for layout / review probes
	local ok, err = pcall(STYLE.Refresh, label)
	if not ok then warnThrottled("text style failed: " .. tostring(err)) end
	return label
end

-- New TextLabel through UIKit.Create, styled with UIKit.StyleText. props: any TextLabel property (+ Parent, set last);
-- BackgroundTransparency defaults to 1 and TextSize to the style's Size. Text colour / font come from the style.
function UIKit.StyledLabel(props, styleName, onLight)
	props = type(props) == "table" and props or {}
	local def = UIKit.TextStyles[styleName]
	local p = { BackgroundTransparency = 1, Text = "" }
	for key, value in props do
		if key ~= "Parent" then p[key] = value end
	end
	if p.TextSize == nil then p.TextSize = type(def) == "table" and def.Size or 16 end
	p.Text = tostring(p.Text)
	local label = UIKit.Create("TextLabel", p)
	UIKit.StyleText(label, styleName, onLight)
	if props.Parent then label.Parent = props.Parent end
	return label
end

-- Approved C lettering on a designated TextLabel / TextButton. Keep Text and its label intact: only a loaded
-- ArtImage may cover it. Empty IDs, 403s, pending images, numbers and unknown messages retain the normal text
-- (IMG-R4). Changing Text automatically selects the exact Config.UIArt.TextLabels match, including reverting
-- from "발사" to an unknown PERFECT message. Optional hint is a part key or its exact text; it never overrides
-- a different current message. Returns the original label, so callers can continue using .Text / .TextColor3.
function UIKit.BindArtText(label, partKeyOrText)
	-- Pre-rendered glyphs cannot follow a newly selected font. Keep the approved frame art and render its labels.
	if FONT.UseTextImages == false then return label end
	if typeof(label) ~= "Instance" or not (label:IsA("TextLabel") or label:IsA("TextButton")) then return label end
	if Art.TextBindings[label] then
		Art.TextBindings[label].Hint = partKeyOrText
		Art.TextBindings[label].Select()
		return label
	end
	local binding = { Hint = partKeyOrText, Connections = {}, Opacity = {}, Ready = false, Dead = false }
	Art.TextBindings[label] = binding

	local function draw()
		if binding.Dead then return end
		local image = binding.Image
		binding.Ready = image ~= nil and image.IsLoaded
		if image then image.Visible = false end -- never expose art and the fallback during a state change
		for _, record in binding.Opacity do
			if record.Target == label or record.Target.Parent == label then
				local value = binding.Ready and 1 or record.Base
				record.Written = value -- set before writing; property events may run now or later
				if math.abs(record.Target[record.Property] - value) > 0.00001 then
					record.Target[record.Property] = value
				end
			end
		end
		if image then
			image.ImageTransparency = binding.TextOpacity.Base
			image.Visible = binding.Ready
		end
	end

	local function watchOpacity(target, property)
		local record = { Target = target, Property = property, Base = target[property] }
		table.insert(binding.Opacity, record)
		table.insert(binding.Connections, target:GetPropertyChangedSignal(property):Connect(function()
			if binding.Dead then return end
			local value = target[property]
			-- Do not mistake our own hide/restore for a caller's fade; avoids a transparency signal loop.
			if record.Written ~= nil and math.abs(value - record.Written) <= 0.00001 then return end
			record.Base = value
			draw()
		end))
		return record
	end
	binding.TextOpacity = watchOpacity(label, "TextTransparency")
	watchOpacity(label, "TextStrokeTransparency")
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			watchOpacity(child, "Transparency")
		end
	end
	table.insert(binding.Connections, label.ChildAdded:Connect(function(child)
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			watchOpacity(child, "Transparency")
			draw()
		end
	end))

	local function layout()
		local image, def = binding.Image, binding.Definition
		if binding.Dead or not image or not def then return end
		local size = typeof(def.ImageRectSize) == "Vector2" and def.ImageRectSize or def.Size
		local aspect = typeof(size) == "Vector2" and size.Y > 0 and size.X / size.Y or 1
		local abs = label.AbsoluteSize
		local x = label.TextXAlignment == Enum.TextXAlignment.Left and 0
			or (label.TextXAlignment == Enum.TextXAlignment.Right and 1 or 0.5)
		local y = label.TextYAlignment == Enum.TextYAlignment.Top and 0
			or (label.TextYAlignment == Enum.TextYAlignment.Bottom and 1 or 0.5)
		image.AnchorPoint = Vector2.new(x, y)
		if abs.X > 0 and abs.Y > 0 then
			local left, right, top, bottom = 0, 0, 0, 0
			local padding = label:FindFirstChildOfClass("UIPadding")
			if padding then
				local scale = inheritedScale(label)
				left = padding.PaddingLeft.Scale * abs.X + padding.PaddingLeft.Offset * scale
				right = padding.PaddingRight.Scale * abs.X + padding.PaddingRight.Offset * scale
				top = padding.PaddingTop.Scale * abs.Y + padding.PaddingTop.Offset * scale
				bottom = padding.PaddingBottom.Scale * abs.Y + padding.PaddingBottom.Offset * scale
			end
			local width = math.max(0, abs.X - left - right)
			local height = math.min(math.max(0, abs.Y - top - bottom), width / aspect)
			local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
			local cap = not label.TextScaled and label.TextSize or (constraint and constraint.MaxTextSize)
			if cap then
				local capScale = Art.TextFits[label] and 1 or inheritedScale(label)
				height = math.min(height, cap * capScale)
			end
			image.Size = UDim2.fromScale(height * aspect / abs.X, height / abs.Y)
			image.Position = UDim2.fromScale((left + width * x) / abs.X,
				(top + math.max(0, abs.Y - top - bottom) * y) / abs.Y)
		else
			image.Size = UDim2.fromScale(1, 1)
			image.Position = UDim2.fromScale(x, y)
		end
		image.ZIndex = label.ZIndex + 1
	end
	local padding = label:FindFirstChildOfClass("UIPadding")
	if padding then
		for _, property in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
			table.insert(binding.Connections, padding:GetPropertyChangedSignal(property):Connect(layout))
		end
	end
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		table.insert(binding.Connections, constraint:GetPropertyChangedSignal("MaxTextSize"):Connect(layout))
	end

	binding.Select = function()
		if binding.Dead then return end
		local key = Art.TextLabels[label.Text]
		local hint = Art.TextLabels[binding.Hint] or binding.Hint
		if hint ~= key then hint = nil end -- exact match only; never discard dynamic suffixes or digits
		key = hint or key
		local def = key and artPart(key) or nil
		if def and binding.Key == key and binding.Image and binding.Image.Image == def.Id then
			layout()
			draw()
			return
		end
		if binding.LoadConnection then binding.LoadConnection:Disconnect(); binding.LoadConnection = nil end
		local previous = binding.Image
		if previous then previous.Visible = false end
		binding.Image, binding.Definition, binding.Key = nil, nil, key
		draw() -- restore the font before destroying an old image or starting a different request
		if previous then previous:Destroy() end
		if not def then return end
		local ok, image = pcall(UIKit.ArtImage, key, {
			Name = "ArtText", Size = UDim2.fromScale(1, 1), ZIndex = label.ZIndex + 1,
			ImageRectOffset = def.ImageRectOffset or Vector2.zero,
			ImageRectSize = def.ImageRectSize or Vector2.zero,
			Visible = false, Active = false, Parent = label,
		})
		if not ok or not image then return end
		binding.Image, binding.Definition = image, def
		binding.LoadConnection = image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			if binding.Image == image then draw() end
		end)
		layout()
		draw()
	end
	table.insert(binding.Connections, label:GetPropertyChangedSignal("Text"):Connect(binding.Select))
	for _, property in { "AbsoluteSize", "TextXAlignment", "TextYAlignment", "TextSize", "TextScaled", "ZIndex" } do
		table.insert(binding.Connections, label:GetPropertyChangedSignal(property):Connect(layout))
	end
	table.insert(binding.Connections, label.Destroying:Connect(function()
		binding.Dead = true
		if binding.LoadConnection then binding.LoadConnection:Disconnect() end
		for _, connection in binding.Connections do connection:Disconnect() end
		Art.TextBindings[label] = nil
	end))
	binding.Select()
	return label
end

-- art frame (an ImageLabel; children go inside it) or, when the part is missing, the code-drawn panel: Frame +
-- UICorner + UIStroke "Stroke" (IMG-R4). BackgroundColor3 / BackgroundTransparency in props are ignored; the fallback
-- look comes from fallbackProps (BackgroundColor3 or Color, BackgroundTransparency, CornerRadius, Stroke = false,
-- StrokeColor, StrokeThickness, StrokeTransparency + any Frame property), defaulting to the part's Tone colour with
-- a gold / inked rim (Theme.Bg panel when the part has no Tone).
-- children: Instances or { className, props, children } as in UIKit.Create. Returns (frame, isArt).
function UIKit.ArtFrame(name, props, fallbackProps, children)
	props = props or {}
	local p = {}
	for key, value in props do
		if key ~= "Parent" and key ~= "BackgroundColor3" and key ~= "BackgroundTransparency" then
			p[key] = value
		end
	end
	local frame = UIKit.ArtImage(name, p)
	local isArt = frame ~= nil
	if not frame then
		local fb = type(fallbackProps) == "table" and fallbackProps or {}
		local def = rawPart(name)
		local tone = toneColor(def)
		local fp = {}
		for key, value in p do
			if not Art.OnlyKeys[key] then fp[key] = value end
		end
		for key, value in fb do
			if not Art.FallbackKeys[key] then fp[key] = value end
		end
		fp.BackgroundColor3 = fb.BackgroundColor3 or fb.Color or tone or UIKit.Theme.Bg
		fp.BackgroundTransparency = fb.BackgroundTransparency or (tone and 0.04 or UIKit.Theme.BgTransparency)
		frame = UIKit.Create("Frame", fp)
		fallbackDecor(frame, fb, def)
	end
	addChildren(frame, children)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame, isArt
end

-- centred "Label" child of an art / fallback button (TextScaled up to TextSize)
local function artButtonLabel(btn, def, props)
	local style = props.TextStyle
	if style ~= "ink" and style ~= "light" then
		style = (def and def.Tone == "Parchment") and "ink" or "light"
	end
	local lp = {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -4),
		Text = tostring(props.Text),
		TextScaled = true,
		TextWrapped = true,
		MaxTextSize = tonumber(props.MaxTextSize) or tonumber(props.TextSize) or 18,
		Parent = btn,
	}
	if props.TextColor3 ~= nil then
		lp.Color = props.TextColor3
	elseif props.TextColor ~= nil then
		lp.Color = props.TextColor
	end
	if props.Font ~= nil then lp.Font = props.Font end
	if props.FontFace ~= nil then lp.FontFace = props.FontFace end
	if style == "ink" then
		return UIKit.InkText(lp)
	end
	return UIKit.LightText(lp)
end

-- ImageButton for a part with UIKit.Button's press-shrink ("PressScale") + Click sound; onClick(button) runs on
-- Activated unless Active == false or attribute Disabled == true. Round / icon parts use Fit, BtnSquare is 9-sliced.
-- props: any ImageButton property (+ Parent, SliceScale) plus label keys Text, TextSize (max for TextScaled),
-- MaxTextSize, TextColor / TextColor3, Font, TextStyle ("ink" / "light"; default ink on Parchment parts) that build
-- a child TextLabel "Label". Color is only used by the fallback.
-- Missing part (IMG-R4): a UIKit.Button TextButton styled by fallbackProps (BackgroundColor3 or Color, CornerRadius,
-- StrokeColor / StrokeThickness / StrokeTransparency, Stroke = false + any TextButton property), else props.Color,
-- else the part's Tone; round parts get a circle. It gets the same "Label" child.
-- Returns (button, label or nil, isArt).
function UIKit.ArtButton(name, props, onClick, fallbackProps)
	props = props or {}
	local def = artPart(name)
	local raw = rawPart(name)
	local btn
	if def then
		local p = { BackgroundTransparency = 1, AutoButtonColor = false }
		for key, value in props do
			if key ~= "Parent" and key ~= "Image" and key ~= "ScaleType" and key ~= "SliceScale" and key ~= "Color"
				and not Art.LabelKeys[key] then
				p[key] = value
			end
		end
		btn = UIKit.Create("ImageButton", p, { UIKit.Create("UIScale", { Name = "PressScale" }) })
		applyArt(btn, def, props.ScaleType, props.SliceScale)
		wirePress(btn, onClick)
	else
		local fb = type(fallbackProps) == "table" and fallbackProps or {}
		local p = {}
		for key, value in props do
			if key ~= "Parent" and key ~= "Color" and key ~= "BackgroundColor3" and key ~= "BackgroundTransparency"
				and not Art.OnlyKeys[key] and not Art.LabelKeys[key] then
				p[key] = value
			end
		end
		for key, value in fb do
			if not Art.FallbackKeys[key] then p[key] = value end
		end
		p.BackgroundColor3 = fb.BackgroundColor3 or fb.Color or props.Color or toneColor(raw)
		if fb.BackgroundTransparency ~= nil then p.BackgroundTransparency = fb.BackgroundTransparency end
		p.Text = ""
		btn = UIKit.Button(p, onClick) -- nil BackgroundColor3 = UIKit.Button's default grey
		fallbackDecor(btn, fb, raw)
	end
	local label = nil
	if props.Text ~= nil then
		label = artButtonLabel(btn, raw, props)
	end
	if props.Parent then
		btn.Parent = props.Parent
	end
	return btn, label, def ~= nil
end

-- 창 꾸미기 (검수 2026-10-07, user: the windows must look designed): a TextButton that wears an approved button part
-- (the 9-sliced capsules BtnPrimary gold / BtnSecondary blue / BtnConfirm green ...) with its words in a styled child
-- "Label" that mirrors the button's own Text and TextSize. The button keeps Text / TextSize / Activated, so callers that
-- rewrite btn.Text keep working; its own text is hidden. Gold / parchment parts get navy words, the others white with
-- the navy rim (UIKit text styles). Attribute Disabled = true dims the art and the words. UIKit.SetButtonArt swaps the
-- part (Panels repaints its buttons by colour). Missing part (IMG-R4): UIKit.Button(props, onClick), the coloured code
-- button, unchanged.
function UIKit.ArtTextButton(part, props, onClick)
	local def = artPart(part)
	if not def then return UIKit.Button(props, onClick) end
	props = props or {}
	local p = {}
	for key, value in props do
		if key ~= "Parent" and key ~= "Color" and key ~= "TextColor" then p[key] = value end
	end
	p.BackgroundTransparency = 1
	p.AutoButtonColor = false
	p.TextTransparency = 1
	p.TextStrokeTransparency = 1
	if p.Text == nil then p.Text = "" end
	if p.TextSize == nil then p.TextSize = 18 end
	local btn = UIKit.Create("TextButton", p, { UIKit.Create("UIScale", { Name = "PressScale" }) })
	local art = UIKit.ArtImage(part, {
		Name = "Art",
		Size = UDim2.fromScale(1, 1),
		ZIndex = btn.ZIndex,
		Active = false,
		Parent = btn,
	})
	local light = def.Tone == "Gold" or def.Tone == "Parchment"
	-- the words fit the capsule: TextScaled up to the button's TextSize, down to 12 px for long ones (UiSandbox
	-- 2026-10-07: 'My name in announcements and rankings: shown' was cut at the 16 px button floor)
	local cap = UIKit.Create("UITextSizeConstraint", { MaxTextSize = btn.TextSize, MinTextSize = 1 })
	local label = UIKit.Create("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.new(1, -20, 1, -8),
		BackgroundTransparency = 1,
		Text = btn.Text,
		TextSize = btn.TextSize,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = btn.ZIndex + 1,
	}, { cap })
	label:SetAttribute("StyleMinPx", 12)
	UIKit.StyleText(label, "Button", light)
	label.Parent = btn
	btn:SetAttribute("ArtButton", part)
	btn:GetPropertyChangedSignal("Text"):Connect(function() label.Text = btn.Text end)
	btn:GetPropertyChangedSignal("TextSize"):Connect(function() cap.MaxTextSize = btn.TextSize end)
	btn:GetPropertyChangedSignal("ZIndex"):Connect(function()
		art.ZIndex = btn.ZIndex
		label.ZIndex = btn.ZIndex + 1
	end)
	btn:GetAttributeChangedSignal("Disabled"):Connect(function() UIKit.ButtonArtState(btn) end)
	wirePress(btn, onClick)
	UIKit.ButtonArtState(btn)
	if props.Parent then btn.Parent = props.Parent end
	return btn
end

-- the art button's look for its Disabled attribute: dimmed art and faded words while disabled
function UIKit.ButtonArtState(btn)
	local art, label = btn:FindFirstChild("Art"), btn:FindFirstChild("Label")
	local off = btn:GetAttribute("Disabled") == true
	if art and art:IsA("ImageLabel") then
		art.ImageColor3 = off and Color3.fromRGB(150, 150, 160) or Color3.new(1, 1, 1)
		art.ImageTransparency = off and 0.15 or 0
	end
	if label and label:IsA("TextLabel") then label.TextTransparency = off and 0.4 or 0 end
end

-- swaps an art button's part (e.g. Panels' paintButton: green Free -> BtnConfirm, gold Buy -> BtnPrimary); the words
-- follow the new part's tone. A code button (no "Art" child) is left as it is. Returns true when it changed
function UIKit.SetButtonArt(btn, part)
	if typeof(btn) ~= "Instance" or btn:GetAttribute("ArtButton") == part then return false end
	local def = artPart(part)
	local art = btn:FindFirstChild("Art")
	if not (def and art and art:IsA("ImageLabel")) then return false end
	applyArt(art, def)
	btn:SetAttribute("ArtButton", part)
	local label = btn:FindFirstChild("Label")
	if label then UIKit.StyleText(label, "Button", def.Tone == "Gold" or def.Tone == "Parchment") end
	UIKit.ButtonArtState(btn)
	return true
end

-- progress bar on the BarTrack art (navy capsule with a gold rim). Same props and returns as UIKit.Bar:
-- (frame, setFraction(f, color?), textLabel); Color defaults to ArtColors.XPBlue, Track = another part name.
-- The fill (frame.Inner.Fill) sits in the navy interior; the text is LightText in the Number font.
-- Missing track art: UIKit.Bar(props) (IMG-R4).
function UIKit.ArtBar(props)
	props = props or {}
	local fillColor = props.Color or artColor("XPBlue", UIKit.Theme.XP)
	local trackName = props.Track or "BarTrack"
	local def = artPart(trackName)
	local frame = nil
	local size = props.Size or UDim2.fromOffset(200, 16)
	if def then
		local frameProps = {
			Name = props.Name or "Bar",
			Size = size,
			Position = props.Position or UDim2.new(),
			AnchorPoint = props.AnchorPoint or Vector2.zero,
			LayoutOrder = props.LayoutOrder or 0,
			Visible = props.Visible ~= false,
		}
		if props.ZIndex then frameProps.ZIndex = props.ZIndex end
		frame = UIKit.ArtImage(trackName, frameProps)
	end
	if not frame then
		local p = {}
		for key, value in props do
			if key ~= "Track" then p[key] = value end
		end
		p.Color = fillColor
		return UIKit.Bar(p)
	end

	-- navy interior from the Inner rect: vertical insets scale with the height (FitHeight edges), side insets are
	-- in height units (round caps)
	local top, bottom, side = 0.18, 0.19, 0.21
	local imgSize, inner = def.Size, def.Inner
	if typeof(inner) == "Rect" and typeof(imgSize) == "Vector2" and imgSize.Y > 0 then
		top = inner.Min.Y / imgSize.Y
		bottom = (imgSize.Y - inner.Max.Y) / imgSize.Y
		side = inner.Min.X / imgSize.Y
	end
	local sidePx = size.Y.Offset > 0 and math.floor(side * size.Y.Offset + 0.5) or 3
	local area = UIKit.Create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, sidePx, top, 0),
		Size = UDim2.new(1, -2 * sidePx, 1 - top - bottom, 0),
		Parent = frame,
	})
	local fill = UIKit.Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = fillColor,
		Visible = false,
		Parent = area,
	}, {
		corner(UDim.new(0.5, 0)),
		UIKit.Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		}),
		-- glossy candy highlight
		UIKit.Create("Frame", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.new(1, -6, 0.32, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
		}, { corner(UDim.new(0.5, 0)) }),
	})
	local textProps = {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "",
		TextSize = props.TextSize or 15,
		Number = true,
		ZIndex = 2,
		Parent = frame,
	}
	if props.ZIndex then textProps.ZIndex = props.ZIndex + 1 end
	local text = UIKit.LightText(textProps)

	local lastFraction = -1
	local function setFraction(f, color)
		f = tonumber(f) or 0
		if f ~= f then f = 0 end
		f = math.clamp(f, 0, 1)
		if color and typeof(color) == "Color3" then
			fill.BackgroundColor3 = color
		end
		if math.abs(f - lastFraction) < 0.0005 then return end
		lastFraction = f
		fill.Visible = f > 0.001
		fill.Size = UDim2.fromScale(f, 1)
	end
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame, setFraction, text
end

----------------------------------------------------------------- toasts
local function removeToast(t)
	local idx = table.find(toasts, t)
	if idx then table.remove(toasts, idx) end
	if t.Dead then return end
	t.Dead = true
	local info = TweenInfo.new(0.2)
	if t.Frame.Parent then
		if t.Art then
			TweenService:Create(t.Art, info, { ImageTransparency = 1 }):Play()
		else
			TweenService:Create(t.Frame, info, { BackgroundTransparency = 1 }):Play()
		end
		TweenService:Create(t.Label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		if t.Stroke then TweenService:Create(t.Stroke, info, { Transparency = 1 }):Play() end
		if t.Icon then TweenService:Create(t.Icon, info, { ImageTransparency = 1 }):Play() end
	end
	task.delay(0.22, function()
		t.Frame:Destroy()
	end)
	NOTIFY.ShowNext()
end

-- the next waiting toast once the column is empty (NOTIFY.OneAtATime)
function NOTIFY.ShowNext()
	if #toasts > 0 or #NOTIFY.Queue == 0 then return end
	local q = table.remove(NOTIFY.Queue, 1)
	task.defer(UIKit.Toast, q.Text, q.Kind, q.Duration, q.Icon)
end

-- HUD v2: how many toasts fit between NOTIFY.Y and the bottom of the notify column, counted from the newest (top)
-- with their real heights; never below 1 and never above the old cap (toastMax). Old path: toastMax.
-- 검수 2026-10-06 (English lines cut after one line in toasts / banners): AutomaticSize Y does not size wrapped text
-- reliably (UiSandbox Edit test: a 2-line toast label got a 1-line box, TextFits false, with and without the game
-- font). UIKit.WrapHeight measures the text with TextService at the label's real width and sets its height itself
-- (AutomaticSize off), again whenever the text, size, face or width changes. maxLines (optional) caps the height (the
-- label's TextTruncate shows "..."), minH (optional, logical units) keeps a least height, onSized(h) runs after a fit.
function UIKit.WrapHeight(label, maxLines, minH, onSized)
	if typeof(label) ~= "Instance" or not label:IsA("TextLabel") then return end
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextWrapped = true
	local state = { Token = 0, W = -1 }
	local function fit()
		state.Token += 1
		local token = state.Token
		task.spawn(function()
			-- measured in real px at the size the engine draws (TextSize x UIScale, rounded): on a small PC window (UIScale
			-- 0.5) the logical measure gave a 2-line toast 1 px too little and its 2nd line became "..." (UiSandbox 991x451
			-- 2026-10-08, after the window closed)
			local s = currentScale()
			local width = label.AbsoluteSize.X
			if width <= 1 or not label.Parent then return end
			local px = math.max(1, math.floor(label.TextSize * s + 0.5))
			local params = Instance.new("GetTextBoundsParams")
			params.Text = label.Text
			params.Font = label.FontFace
			params.Size = px
			-- a few px narrower than the box: the engine wraps a little earlier than TextService (991x451: TextService said
			-- 2 lines at 142 px, the label drew 3)
			params.Width = math.max(1, width - NOTIFY.WrapWidthSlackPx)
			local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
			params:Destroy()
			if token ~= state.Token or not ok or not label.Parent then return end
			local lines = math.max(1, math.floor(bounds.Y / px + 0.5))
			-- per line at least WrapSlackPx real px more: TextService gives a 9 px line 9 px, the engine draws it 11 px
			-- (UiSandbox 991x451 2026-10-08: two 9 px lines got 21 px and the 2nd became "...")
			local h = math.ceil((bounds.Y + lines * math.max(px * NOTIFY.WrapSlack, NOTIFY.WrapSlackPx)) / s)
			-- maxLines may be a function: a toast reads NOTIFY.Avoid again on every fit (one line only while a window is open)
			local cap = type(maxLines) == "function" and maxLines() or maxLines
			if cap then
				local lineH = math.max(label.TextSize * NOTIFY.WrapLineH, bounds.Y / lines / s)
				h = math.min(h, math.ceil((lineH + label.TextSize * NOTIFY.WrapSlack) * cap))
			end
			if minH then h = math.max(h, minH) end
			local size = label.Size
			if size.Y.Scale ~= 0 or size.Y.Offset ~= h then label.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, h) end
			if onSized then onSized(h) end
		end)
	end
	for _, property in { "Text", "TextSize", "FontFace" } do
		label:GetPropertyChangedSignal(property):Connect(fit)
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local w = math.floor(label.AbsoluteSize.X + 0.5)
		if w ~= state.W then
			state.W = w
			fit()
		end
	end)
	NOTIFY.WrapFits[label] = fit -- UIKit.SetNotifyAvoid fits the live toasts again when a window opens / closes
	fit()
	return label
end

-- 검수 2026-10-10 (user, the Vacation card: "균형이 안 맞아" - 'You were away for 1 day, and that's / okay.', one word
-- alone on the last line): UIKit.BalanceLines(label) keeps a centred wrapped label's lines about even. It counts lines
-- with the ENGINE: an invisible copy of the label (same font, size, stroke, size floor) in an off-screen ScreenGui under
-- the same UIScale, resized and read back (TextBounds) - TextService was a few % off the engine at these sizes and gave
-- one line too many or too few (UiSandbox 1280 / 991). It finds the narrowest width that still gives the label's n lines
-- (UIKit.BalanceWidth), keeps Margin over it and pads the label inside by the difference (a UIPadding "LineBalance",
-- left = right), so the text wraps there. The label's own size and place never change. One line, left / right aligned
-- text and a label with its own UIPadding are left alone; a pass whose text still does not fit drops the padding again.
-- Again whenever the text, size, face or width changes.
local BAL = { Steps = 7, Margin = 1.03, Fits = setmetatable({}, { __mode = "k" }), Gui = nil }
UIKit.LineBalance = BAL

-- the off-screen measuring ScreenGui (made once; its UIScale follows the HUD's)
function BAL.ProbeGui()
	if BAL.Gui and BAL.Gui.Parent then return BAL.Gui end
	local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local g = Instance.new("ScreenGui")
	g.Name = "LineBalanceProbe"
	g.ResetOnSpawn = false
	g.DisplayOrder = -100
	local sc = Instance.new("UIScale")
	sc.Name = "Scale"
	sc.Parent = g
	g.Parent = pg
	BAL.Gui = g
	return g
end

-- waits until the probe's TextBounds reflect its last change (a frame, at most a few)
function BAL.Settle(probe, before)
	local hb = game:GetService("RunService").Heartbeat
	for _ = 1, 4 do
		hb:Wait()
		if probe.TextBounds ~= before then return end
	end
end

-- pure: the narrowest width (real px) at which linesAt(width) still needs no more lines than at `full`, between
-- oneLine / n and full (linesAt never rises with the width); returns that width and n
function UIKit.BalanceWidth(linesAt, full, oneLine)
	local n = linesAt(full)
	if n <= 1 then return full, n end
	local lo, hi = math.max(1, oneLine / n), full
	for _ = 1, BAL.Steps do
		local mid = (lo + hi) / 2
		if linesAt(mid) <= n then hi = mid else lo = mid end
	end
	return math.min(full, math.ceil(hi)), n
end

function UIKit.BalanceLines(label)
	if typeof(label) ~= "Instance" or not label:IsA("TextLabel") then return label end
	if BAL.Fits[label] then
		BAL.Fits[label]()
		return label
	end
	local state = { Token = 0, W = -1 }
	local function balance(token)
		local pad = label:FindFirstChild("LineBalance")
		local own = label:FindFirstChildOfClass("UIPadding")
		if own and own ~= pad then return end -- the label's own padding: leave it alone
		local full = label.AbsoluteSize.X
		local function clear()
			if pad then pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 0), UDim.new(0, 0) end
		end
		if label.TextXAlignment ~= Enum.TextXAlignment.Center or not label.TextWrapped or label.Text == ""
			or full <= 1 or not label.Parent then
			clear()
			return
		end
		local s = math.max(0.05, currentScale())
		local gui = BAL.ProbeGui()
		if not gui then return end
		gui.Scale.Scale = s
		-- the copy: the label's own children (stroke, gradient, size floor) but no padding / size limits / scripts
		local probe = label:Clone()
		for _, ch in probe:GetChildren() do
			if ch:IsA("UIPadding") or ch:IsA("UISizeConstraint") or ch:IsA("UIAspectRatioConstraint")
				or ch:IsA("LuaSourceContainer") or ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		probe.Name = "Probe"
		probe.AutomaticSize = Enum.AutomaticSize.None
		probe.AnchorPoint = Vector2.zero
		-- on screen but drawn invisible (an off-screen copy kept stale TextBounds: UiSandbox 10/10 3rd after-shots)
		probe.Position = UDim2.fromOffset(0, 0)
		probe.Visible = true
		probe.TextTransparency = 1
		probe.TextStrokeTransparency = 1
		for _, ch in probe:GetChildren() do
			if ch:IsA("UIStroke") then ch.Transparency = 1 end
		end
		probe.TextWrapped = false
		probe.Size = UDim2.fromOffset(full / s, 4000)
		probe.Parent = gui
		BAL.Settle(probe, nil)
		local lineH, one = probe.TextBounds.Y, probe.TextBounds.X
		probe.TextWrapped = true
		local function linesAt(w)
			local before = probe.TextBounds
			probe.Size = UDim2.fromOffset(w / s, 4000)
			BAL.Settle(probe, before)
			return math.max(1, math.floor(probe.TextBounds.Y / math.max(1, lineH) + 0.5))
		end
		local ok, w, n = pcall(UIKit.BalanceWidth, linesAt, full, one)
		probe:Destroy()
		if not ok then error(w) end
		w = math.min(full, math.ceil(w * BAL.Margin))
		if token ~= state.Token or not label.Parent then return end
		local side = n > 1 and math.max(0, math.floor((full - w) / 2)) or 0
		if side <= 0 then
			clear()
			return
		end
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "LineBalance"
			pad.Parent = label
		end
		-- the label's own height at the full width first: the balance may never add a line to it
		clear()
		BAL.Settle(label, nil)
		local tall = label.TextBounds.Y
		local du = side / s
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, du), UDim.new(0, du)
		BAL.Settle(label, nil)
		-- a line more than before, or text that no longer fits: back to the full box
		if token == state.Token and label.Parent and (not label.TextFits or label.TextBounds.Y > tall + 1) then
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 0), UDim.new(0, 0)
		end
	end
	local function fit()
		state.Token += 1
		local token = state.Token
		task.spawn(function()
			local ok, err = pcall(balance, token)
			if not ok then warn("[UIKit] line balance: " .. tostring(err)) end
		end)
	end
	for _, property in { "Text", "TextSize", "FontFace", "TextXAlignment" } do
		label:GetPropertyChangedSignal(property):Connect(fit)
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local w = math.floor(label.AbsoluteSize.X + 0.5)
		if w ~= state.W then
			state.W = w
			fit()
		end
	end)
	BAL.Fits[label] = fit
	fit()
	return label
end

function NOTIFY.ToastCap()
	if NOTIFY.Avoid then return 1 end -- a window is open: the newest line only
	local rect = NOTIFY.Rect
	if rect == nil then return toastMax end
	local avail = rect.Y + rect.H - (NOTIFY.Y or rect.Y) - NOTIFY.BannerOffset()
	local scale = currentScale()
	local used, count = 0, 0
	for i = #toasts, 1, -1 do
		local t = toasts[i]
		local h = t.Frame.AbsoluteSize.Y / scale
		if h <= 0 then h = t.MinH or (t.Icon and TOAST_ICON + 14 or NOTIFY.ToastEstimate) end -- not laid out yet
		local add = h + (count > 0 and NOTIFY.ToastGap or 0)
		if count > 0 and used + add > avail then break end
		used += add
		count += 1
	end
	return math.max(1, math.min(count, toastMax))
end

-- drops the oldest toasts beyond the cap (the newest always stays)
function NOTIFY.TrimToasts()
	local cap = NOTIFY.ToastCap()
	while #toasts > cap do
		removeToast(toasts[1])
	end
end

-- re-trim once a toast's real height is known (wrapped text); no-op before the first UIKit.PlaceNotify
function NOTIFY.QueueTrim()
	if NOTIFY.TrimQueued or NOTIFY.Rect == nil then return end
	NOTIFY.TrimQueued = true
	task.defer(function()
		NOTIFY.TrimQueued = false
		local ok, err = pcall(NOTIFY.TrimToasts)
		if not ok then warnThrottled("toast trim failed: " .. tostring(err)) end
	end)
end

local function scheduleToast(t, duration)
	t.Token += 1
	local token = t.Token
	task.delay(duration, function()
		if t.Token == token and not t.Dead then
			removeToast(t)
		end
	end)
end

-- handoff queue 3: one toast on the approved Toast capsule (NOTIFY.ToastArt), or nil when the art is missing (the caller
-- builds the code look). The socket holds the item / monster icon, else the kind's glyph; the words sit between the
-- socket and the round end, 1-2 lines. The capsule is as wide as its words (measured off-thread, then it fades in), at
-- most the notify column. Returns the toast record { Frame, Label, Art, Icon, Text, Token, Dead, MinH }.
function NOTIFY.BuildArtToast(text, kind, icon, color)
	local ta = NOTIFY.ToastArt
	if not artPart(ta.Part) or not toastHolder then return nil end
	local T = UIKit.Theme
	local frame = UIKit.Create("Frame", {
		Name = "Toast",
		LayoutOrder = -toastCounter,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	local art = UIKit.ArtImage(ta.Part, { Name = "Art", Size = UDim2.fromScale(1, 1), ImageTransparency = 1, ZIndex = 1,
		Parent = frame })
	local pad = UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, ta.PadY), PaddingBottom = UDim.new(0, ta.PadY) })
	local body = UIKit.Create("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, ZIndex = 2, Parent = frame }, { pad })
	local hasIcon = type(icon) == "string" and icon ~= ""
	local img = hasIcon and UIKit.ItemIcon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
		ImageTransparency = 1, ZIndex = 3, Parent = frame }) or nil
	if not img then
		hasIcon = false
		local glyph = ta.Glyph[kind] or ta.Glyph.info
		img = UIKit.ArtImage(glyph[1], { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 1,
			ImageColor3 = glyph[2] or Color3.new(1, 1, 1), ZIndex = 3, Parent = frame })
	end
	local minH = hasIcon and ta.MinHIcon or ta.MinH
	local label = UIKit.Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, minH - 2 * ta.PadY),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = math.max(18, math.ceil(NOTIFY.ToastPx * UIKit.PxFloor() / currentScale() - 0.001)),
		Text = text,
		TextColor3 = (kind == "good" or kind == "bad" or kind == "reward") and color or T.Text,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 2,
		Parent = body,
	})
	-- the side room and the socket's icon follow the capsule's height (FitHeight: the socket grows with a 2nd line)
	local function layout(h)
		pad.PaddingLeft = UDim.new(0, math.floor(h * ta.CapL + 0.5))
		pad.PaddingRight = UDim.new(0, math.floor(h * ta.CapR + 0.5))
		if img then
			local d = math.floor(h * (hasIcon and ta.IconK or ta.GlyphK) + 0.5)
			img.Size = UDim2.fromOffset(d, d)
			img.Position = UDim2.new(0, math.floor(h * ta.DiscX + 0.5), 0.5, 0)
		end
	end
	layout(minH)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local h = frame.AbsoluteSize.Y / currentScale()
		if h > 1 then layout(h) end
	end)
	frame.Parent = toastHolder
	local t = { Frame = frame, Label = label, Art = art, Icon = img, Text = text, Token = 0, Dead = false, MinH = minH }
	UIKit.WrapHeight(label, function() return NOTIFY.Avoid and 1 or ta.Lines end, minH - 2 * ta.PadY)
	UIKit.BalanceLines(label) -- 검수 10/10: no word alone on a line (centred text only)
	task.spawn(function()
		local s = currentScale()
		local col = toastHolder.AbsoluteSize.X / s
		local screenW = UIKit.Gui and UIKit.Gui.AbsoluteSize.X / s or col
		col = math.max(col, math.min(col * ta.WidthMult, screenW * ta.ScreenFrac)) -- may pass the column, centred on it
		local room = col - minH * (ta.CapL + ta.CapR)
		-- review 2026-10-07: a long notice breaks at its " · " (one part a line) instead of a line starting with the dot
		if string.find(text, " · ", 1, true) then
			local ok, _, w = pcall(UIKit.MeasureText, text, label.TextSize, label.FontFace, 100000)
			if room > 0 and ok and type(w) == "number" and w > room then
				label.Text = (string.gsub(text, " · ", "\n"))
			end
		end
		local ok, _, w = pcall(UIKit.MeasureText, label.Text, label.TextSize, label.FontFace, 100000)
		if t.Dead or not frame.Parent then return end
		if ok and type(w) == "number" and col > 0 then
			-- split lines make the capsule taller and its socket / round end wider (FitHeight): count them in, or the
			-- first part wrapped once more on phones ("Daily quest done! +60 / gold")
			local _, breaks = string.gsub(label.Text, "\n", "")
			local hExp = math.max(minH, math.ceil((breaks + 1) * label.TextSize * (NOTIFY.WrapLineH + NOTIFY.WrapSlack)
				+ 2 * ta.PadY))
			local want = math.ceil(hExp * (ta.CapL + ta.CapR) + w + ta.Slack)
			frame.Size = UDim2.new(0, math.clamp(want, math.floor(minH * 3), math.floor(col)), 0, 0)
		end
		local info = TweenInfo.new(0.15)
		if art then TweenService:Create(art, info, { ImageTransparency = 0 }):Play() end
		TweenService:Create(label, info, { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
		if img then TweenService:Create(img, info, { ImageTransparency = 0 }):Play() end
	end)
	return t
end

-- kinds: info / good / bad / reward (anything else = info); max 4 stacked (2 on short phones, CR-L38), newest on
-- top; default 2.5 s. icon (optional) = a Config.Loot.Items id or a UIArt key (UIKit.ItemIcon), drawn left of the text.
-- A toast whose text is already on screen is refreshed instead of stacked twice.
function UIKit.Toast(text, kind, duration, icon)
	if text == nil then return end
	text = tostring(text)
	if text == "" or not toastHolder then return end
	duration = tonumber(duration) or DEFAULT_TOAST_SECONDS
	if duration <= 0 then duration = DEFAULT_TOAST_SECONDS end
	if NOTIFY.OneAtATime then duration = math.min(duration, NOTIFY.ShowSeconds) end

	for _, t in toasts do
		if t.Text == text and not t.Dead then
			scheduleToast(t, duration)
			return
		end
	end
	if NOTIFY.OneAtATime and #toasts > 0 then
		-- a toast is showing: wait in line (the same words already waiting: nothing new)
		for _, q in NOTIFY.Queue do
			if q.Text == text then return end
		end
		table.insert(NOTIFY.Queue, { Text = text, Kind = kind, Duration = duration, Icon = icon })
		while #NOTIFY.Queue > NOTIFY.QueueMax do table.remove(NOTIFY.Queue, 1) end
		return
	end

	toastCounter += 1
	local color = kindColor(kind)
	local T = UIKit.Theme
	-- the approved Toast capsule when uploaded (handoff queue 3), else the code look below
	local artToast = NOTIFY.BuildArtToast(text, kind, icon, color)
	if artToast then
		table.insert(toasts, artToast)
		NOTIFY.TrimToasts()
		artToast.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(NOTIFY.QueueTrim)
		scheduleToast(artToast, duration)
		return
	end
	local frame = UIKit.Create("Frame", {
		Name = "Toast",
		LayoutOrder = -toastCounter,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 1,
	}, {
		corner(UDim.new(0, 10)),
		UIKit.Create("UIPadding", {
			PaddingTop = UDim.new(0, 7),
			PaddingBottom = UDim.new(0, 7),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	})
	local stroke = UIKit.Create("UIStroke", {
		Color = color,
		Thickness = 2,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	local img = type(icon) == "string" and UIKit.ItemIcon(icon, {
		Name = "Icon",
		Size = UDim2.fromOffset(TOAST_ICON, TOAST_ICON),
		ImageTransparency = 1,
		Parent = frame,
	}) or nil
	local left = img and TOAST_ICON + 8 or 0
	local label = UIKit.Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, 0),
		-- grows with the wrapped text (UIKit.WrapHeight, up to NOTIFY.ToastLines lines), never below the icon
		Size = UDim2.new(1, -left, 0, img and TOAST_ICON or 22),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = math.max(18, math.ceil(NOTIFY.ToastPx * UIKit.PxFloor() / currentScale() - 0.001)),
		Text = text,
		TextColor3 = (kind == "good" or kind == "bad" or kind == "reward") and color or T.Text,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = frame,
	})
	frame.Parent = toastHolder
	-- review 2026-10-07: a notice that does not fit on one line breaks at its " · " (one part a line) instead of
	-- starting the second line with the dot ("... +60 gold / · Check the board ...")
	if string.find(text, " · ", 1, true) then
		local room = toastHolder.AbsoluteSize.X / currentScale() - 28 - left
		local ok, _, w = pcall(UIKit.MeasureText, text, label.TextSize, label.FontFace, 100000)
		if room > 0 and ok and type(w) == "number" and w > room then
			label.Text = (string.gsub(text, " · ", "\n"))
		end
	end
	UIKit.WrapHeight(label, function() return NOTIFY.Avoid and 1 or NOTIFY.ToastLines end, img and TOAST_ICON or nil)
	UIKit.BalanceLines(label) -- 검수 10/10: no word alone on a line (centred text only)

	local t = { Frame = frame, Label = label, Stroke = stroke, Icon = img, Text = text, Token = 0, Dead = false }
	table.insert(toasts, t)
	NOTIFY.TrimToasts() -- CR-L38 cap; HUD v2: what fits in the notify column
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(NOTIFY.QueueTrim)

	local info = TweenInfo.new(0.15)
	TweenService:Create(frame, info, { BackgroundTransparency = 0.12 }):Play()
	TweenService:Create(label, info, { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
	TweenService:Create(stroke, info, { Transparency = 0.1 }):Play()
	if img then TweenService:Create(img, info, { ImageTransparency = 0 }):Play() end
	scheduleToast(t, duration)
end

----------------------------------------------------------------- announce banner
local function related(a, b)
	return string.sub(b, 1, #a) == a or string.sub(a, 1, #b) == b
end

local showAnnounce -- forward

local function showNextAnnounce()
	if announceCurrent then return end
	local nxt = table.remove(announceQueue, 1)
	if nxt then
		showAnnounce(nxt.Text, nxt.Duration, nxt.Icon)
	end
end

local function hideAnnounce(token)
	if announceToken ~= token or not announceFrame then return end
	announceCurrent = nil
	local info = TweenInfo.new(0.25)
	NOTIFY.BannerFade(info, false)
	TweenService:Create(announceLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	local icon = announceFrame:FindFirstChild("Icon")
	if icon then TweenService:Create(icon, info, { ImageTransparency = 1 }):Play() end
	task.delay(0.28, function()
		if announceToken ~= token then return end
		announceFrame.Visible = false
		NOTIFY.PlaceToasts()
		showNextAnnounce()
	end)
end

local function armAnnounceTimer(duration)
	announceToken += 1
	local token = announceToken
	if announceCurrent then announceCurrent.Token = token end
	task.delay(duration, function()
		hideAnnounce(token)
	end)
end

-- the banner's look fades in / out: the BannerAlert art when uploaded (the frame's own fill stays off), else the frame
function NOTIFY.BannerFade(info, shown)
	local art = NOTIFY.AlertImg
	if art and art.Parent then
		announceFrame.BackgroundTransparency = 1
		TweenService:Create(art, info, { ImageTransparency = shown and 0 or 1 }):Play()
	else
		TweenService:Create(announceFrame, info, { BackgroundTransparency = shown and 0.3 or 1 }):Play()
	end
end

-- banner icon size + text box beside it (old path: ANNOUNCE_ICON; HUD v2: no taller than the shorter banner). With the
-- BannerAlert art the forked tails and the gold rims grow with the banner's height (FitHeight): the icon and the words
-- stay inside the red band (NOTIFY.AlertArt), laid out again whenever the height changes (NOTIFY.FitAnnounce)
function NOTIFY.LayoutAnnounceText(img)
	local a = (NOTIFY.AlertImg and NOTIFY.AlertImg.Parent) and NOTIFY.AlertArt or nil
	local h = announceFrame.Size.Y.Offset
	local base = (NOTIFY.Rect and NOTIFY.BannerShownH) or NOTIFY.BannerOldH -- the one-line banner's height
	local size = NOTIFY.Rect and NOTIFY.BannerIcon or ANNOUNCE_ICON
	local side, cy = 20, 0.5
	if a then
		NOTIFY.AlertImg.SliceScale = math.max(base / a.Base, 0.01) -- the ends keep the one-line size
		size = math.min(size, math.floor(base * a.IconK))
		side = math.floor(base * a.Side + 0.5)
		-- the red band's centre: CenterY of the one-line art, moved down by half the stretched middle
		cy = h > 0 and (a.CenterY * base + math.max(0, h - base) / 2) / h or a.CenterY
	end
	if img then
		img.Size = UDim2.fromOffset(size, size)
		img.Position = UDim2.new(0, a and side or 28, cy, 0)
	end
	local shift = img and size + (a and 10 or 16) or 0
	announceLabel.Position = UDim2.new(0.5, shift / 2, cy, 0)
	-- the height stays the measured one (UIKit.WrapHeight refits when the width changes)
	announceLabel.Size = UDim2.new(1, -2 * side - shift, 0, announceLabel.Size.Y.Offset)
	NOTIFY.LaidH = h
	NOTIFY.FitAnnounce()
end

-- the banner frame follows its wrapped text: never lower than the column's banner (or the old 84), padding above and
-- below the text (art: the words take TextFrac of the height, between the gold rims), at most BannerLines lines
-- (UIKit.WrapHeight caps the label; its TextTruncate shows "...")
function NOTIFY.FitAnnounce()
	if not announceFrame or not announceLabel then return end
	local a = (NOTIFY.AlertImg and NOTIFY.AlertImg.Parent) and NOTIFY.AlertArt or nil
	local textH = announceLabel.Size.Y.Offset
	local minH = (NOTIFY.Rect and NOTIFY.BannerShownH) or NOTIFY.BannerOldH
	-- art: the one-line banner (minH) holds TextFrac x minH of words; more lines add their height to the stretched middle
	local h = a and math.max(minH, math.ceil(minH + math.max(0, textH - a.TextFrac * minH)))
		or math.max(minH, math.ceil(textH + NOTIFY.BannerPadY * 2))
	local size = announceFrame.Size
	if size.Y.Scale ~= 0 or size.Y.Offset ~= h then
		announceFrame.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, h)
	end
	-- the art's tails follow the height: lay the icon and words out again for a new height (once per height)
	if a and NOTIFY.LaidH ~= h then
		task.defer(function()
			if not announceFrame then return end
			local icon = announceFrame:FindFirstChild("Icon")
			NOTIFY.LayoutAnnounceText(icon and icon:IsA("GuiObject") and icon or nil)
		end)
	end
	NOTIFY.PlaceToasts()
end

-- HUD v2: the banner and the toasts share the column top; while the banner shows, the toasts start under it (a taller
-- wrapped banner used to cover the newest toast)
function NOTIFY.BannerOffset()
	if not (NOTIFY.Rect and announceFrame and announceFrame.Visible and announceCurrent) then return 0 end
	return announceFrame.Size.Y.Offset + NOTIFY.ToastGap
end

function NOTIFY.PlaceToasts()
	if not (NOTIFY.Rect and toastHolder) then return end
	local av = NOTIFY.Avoid
	if av and UIKit.Gui then
		-- a window is open: one line just above it, else just below it (room for one line: NOTIFY.ToastEstimate)
		local s = currentScale()
		local top = insetY() / s + 4
		local screenH = UIKit.Gui.AbsoluteSize.Y / s
		local cx = math.floor(av.X + av.W / 2 + 0.5)
		if av.Y - 6 - top >= NOTIFY.ToastEstimate then
			toastHolder.AnchorPoint = Vector2.new(0.5, 1)
			toastHolder.Position = UDim2.fromOffset(cx, math.floor(av.Y - 6))
			NOTIFY.QueueTrim()
			return
		elseif screenH - (av.Y + av.H) - 6 >= NOTIFY.ToastEstimate then
			toastHolder.AnchorPoint = Vector2.new(0.5, 0)
			toastHolder.Position = UDim2.fromOffset(cx, math.floor(av.Y + av.H + 6))
			NOTIFY.QueueTrim()
			return
		end
		-- no room around it (phones, tall windows): the column as before, one line
	end
	local cx = math.floor(NOTIFY.Rect.X + NOTIFY.Rect.W / 2 + 0.5)
	local ty = math.floor((NOTIFY.Y or NOTIFY.Rect.Y) + NOTIFY.BannerOffset() + 0.5)
	toastHolder.AnchorPoint = Vector2.new(0.5, 0)
	toastHolder.Position = UDim2.fromOffset(cx, ty)
	NOTIFY.QueueTrim()
end

-- Panels tells where its open window is (nil = closed); the toasts move around it at once
function UIKit.SetNotifyAvoid(rect)
	local ok = type(rect) == "table" and NOTIFY.Num(rect.X) and NOTIFY.Num(rect.Y) and NOTIFY.Num(rect.W)
		and NOTIFY.Num(rect.H)
	local new = ok and { X = rect.X, Y = rect.Y, W = rect.W, H = rect.H } or nil
	local old = NOTIFY.Avoid
	if (old == nil) == (new == nil) and (new == nil or (math.abs(old.X - new.X) < 1 and math.abs(old.Y - new.Y) < 1
		and math.abs(old.W - new.W) < 1 and math.abs(old.H - new.H) < 1)) then return end
	NOTIFY.Avoid = new
	-- a toast made while a window was open keeps one line; when the window closes the live toasts get all their lines
	-- back (main Studio 2026-10-08: "First mission: Free the..." stayed cut after the forge window closed)
	for _, t in toasts do
		local fit = not t.Dead and NOTIFY.WrapFits[t.Label]
		if fit then fit() end
	end
	NOTIFY.PlaceToasts()
	NOTIFY.TrimToasts()
end

-- icon (optional, UIKit.ItemIcon): item / monster art left of the banner text
local function setAnnounceIcon(icon)
	local old = announceFrame:FindFirstChild("Icon")
	if old then old:Destroy() end
	local img = type(icon) == "string" and UIKit.ItemIcon(icon, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 28, 0.5, 0),
		Size = UDim2.fromOffset(ANNOUNCE_ICON, ANNOUNCE_ICON),
		ImageTransparency = 1,
		ZIndex = Z_ANNOUNCE + 1,
		Parent = announceFrame,
	}) or nil
	NOTIFY.LayoutAnnounceText(img)
	return img
end

showAnnounce = function(text, duration, icon)
	if not announceFrame then return end
	announceCurrent = { Text = text, Token = 0 }
	announceLabel.Text = text
	local img = setAnnounceIcon(icon)
	announceFrame.Visible = true
	NOTIFY.PlaceToasts()
	announceFrame.BackgroundTransparency = 1
	if NOTIFY.AlertImg then NOTIFY.AlertImg.ImageTransparency = 1 end
	announceLabel.TextTransparency = 1
	announceLabel.TextStrokeTransparency = 1
	announcePop.Scale = 0.85
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	NOTIFY.BannerFade(info, true)
	TweenService:Create(announceLabel, info, { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	if img then TweenService:Create(img, info, { ImageTransparency = 0 }):Play() end
	TweenService:Create(announcePop, info, { Scale = 1 }):Play()
	armAnnounceTimer(duration)
end

-- large banner at 30% screen height; default 3.5 s. Announcements queue (max 3 waiting); a text that extends the
-- one on screen (or queued), e.g. "레벨 업! Lv 10" -> "레벨 업! Lv 10 · 해금! ...", replaces it instead of queueing.
-- icon (optional) = a Config.Loot.Items id or a UIArt key drawn left of the text (UIKit.ItemIcon).
function UIKit.Announce(text, duration, icon)
	if text == nil then return end
	text = tostring(text)
	if text == "" or not announceFrame then return end
	duration = tonumber(duration) or DEFAULT_ANNOUNCE_SECONDS
	if duration <= 0 then duration = DEFAULT_ANNOUNCE_SECONDS end
	-- UI round 2 #4: a window is open - the big banner comes as the one line around it
	if NOTIFY.Avoid then
		UIKit.Toast(text, "reward", duration, icon)
		return
	end

	if announceCurrent and related(announceCurrent.Text, text) then
		if #text > #announceCurrent.Text then
			announceCurrent.Text = text
			announceLabel.Text = text
		end
		announceFrame.Visible = true
		if NOTIFY.AlertImg and NOTIFY.AlertImg.Parent then
			NOTIFY.AlertImg.ImageTransparency = 0
		else
			announceFrame.BackgroundTransparency = 0.3
		end
		announceLabel.TextTransparency = 0
		announceLabel.TextStrokeTransparency = 0.2
		armAnnounceTimer(math.max(duration, 1.5))
		return
	end
	for _, q in announceQueue do
		if related(q.Text, text) then
			if #text > #q.Text then q.Text = text end
			q.Duration = math.max(q.Duration, duration)
			return
		end
	end
	if announceCurrent then
		table.insert(announceQueue, { Text = text, Duration = duration, Icon = icon })
		while #announceQueue > MAX_ANNOUNCE_QUEUE do
			table.remove(announceQueue, 1)
		end
		return
	end
	showAnnounce(text, duration, icon)
end

----------------------------------------------------------------- HUD v2 notify column (A23-26)
-- Self-check / contract:
--  * HUD v2 calls pcall(UIKit.PlaceNotify, Layout.Rects.notify, topY) after every layout pass. rect = { X, Y, W, H }
--    in logical MainGui units incl. the top bar (copied: HUD rebuilds its tables); topY = live top of the free space
--    under EventHUD's stack (nil -> rect.Y). Column top y = max(topY, rect.Y).
--  * Toast stack: AnchorPoint (0.5, 0) at (rect.X + rect.W / 2, y), width rect.W; keeps only as many toasts as fit
--    above rect.Y + rect.H (real heights, newest first; oldest dropped; never below 1, never above the old cap).
--  * Announce banner: AnchorPoint (0.5, 0) at the same point, width min(rect.W * 1.25, 880), height 50 or the
--    remaining column if shorter (floor NOTIFY.BannerMinH so it stays readable); its icon shrinks to fit.
--  * After the first valid call applyScale no longer moves / resizes the toast stack (TOAST_Y is the old path only).
--    Fade, duplicate merge, queueing and held banners are unchanged. Invalid rect: nothing changes, returns false.

-- finite number or nil
function NOTIFY.Num(v)
	v = tonumber(v)
	if v == nil or v ~= v or math.abs(v) == math.huge then return nil end
	return v
end

function UIKit.PlaceNotify(rect, topY)
	if type(rect) ~= "table" then return false end
	local x, y, w, h = NOTIFY.Num(rect.X), NOTIFY.Num(rect.Y), NOTIFY.Num(rect.W), NOTIFY.Num(rect.H)
	if not (x and y and w and h) or w <= 0 or h <= 0 then return false end
	local top = math.max(NOTIFY.Num(topY) or y, y)
	NOTIFY.Rect = { X = x, Y = y, W = w, H = h }
	NOTIFY.Y = top
	local cx = math.floor(x + w / 2 + 0.5)
	local ty = math.floor(top + 0.5)
	if toastHolder then
		toastHolder.Size = UDim2.fromOffset(math.floor(w), 10)
		NOTIFY.PlaceToasts() -- the column top, or around an open window (NOTIFY.Avoid)
	end
	if announceFrame then
		local bannerH = math.max(math.min(NOTIFY.BannerH, y + h - top), NOTIFY.BannerMinH)
		NOTIFY.BannerIcon = math.min(ANNOUNCE_ICON, math.floor(bannerH))
		NOTIFY.BannerShownH = math.floor(bannerH)
		announceFrame.AnchorPoint = Vector2.new(0.5, 0)
		announceFrame.Position = UDim2.fromOffset(cx, ty)
		-- the art banner is wider (its tails take room; NOTIFY.AlertArt), never past ScreenFrac of the screen
		local a = NOTIFY.AlertImg and NOTIFY.AlertArt or nil
		local bw = math.min(w * NOTIFY.BannerWidthMult, NOTIFY.BannerMaxW)
		if a and UIKit.Gui then
			bw = math.max(bw, math.min(w * a.WidthMult, NOTIFY.BannerMaxW, UIKit.Gui.AbsoluteSize.X / currentScale() * a.ScreenFrac))
		end
		announceFrame.Size = UDim2.fromOffset(math.floor(bw), math.floor(bannerH))
		-- text: about 44% of the banner, never under BannerPx real px, at most BannerTextMax
		local floorDu = math.ceil(NOTIFY.BannerPx * UIKit.PxFloor() / currentScale() - 0.001)
		local textSize = math.clamp(math.floor(bannerH * 0.44 + 0.5), floorDu, math.max(floorDu, NOTIFY.BannerTextMax))
		announceLabel.TextSize = textSize -- UIKit.WrapHeight refits the lines
		local icon = announceFrame:FindFirstChild("Icon")
		NOTIFY.LayoutAnnounceText(icon and icon:IsA("GuiObject") and icon or nil)
	end
	NOTIFY.TrimToasts()
	return true
end

----------------------------------------------------------------- confirm dialog
-- modal dialog with [취소] and [confirmText]; onConfirm() runs only on confirm. Clicking the backdrop cancels.
function UIKit.Confirm(title, body, confirmText, onConfirm)
	if not UIKit.Gui then return end
	if confirmOverlay then
		confirmOverlay:Destroy()
		confirmOverlay = nil
	end
	local T = UIKit.Theme
	-- oversized and centred: the backdrop covers the whole screen however MainGui's UIScale (0.6-1.25) treats
	-- scale-sized top-level children; the dialog box sits at the overlay's centre = the screen centre
	local overlay = UIKit.Create("TextButton", {
		Name = "ConfirmDialog",
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(3, 3),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = Z_CONFIRM,
	})
	confirmOverlay = overlay
	local closed = false
	local function close()
		if closed then return end
		closed = true
		if confirmOverlay == overlay then confirmOverlay = nil end
		overlay:Destroy()
	end
	overlay.Activated:Connect(close)

	-- 창 꾸미기 (검수 2026-10-07): the cream DialogBox plate (navy words, UIKit text styles on light); missing art: the
	-- old dark box with its gold line
	local box, boxArt = UIKit.ArtFrame("DialogBox", {
		Name = "Box",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { BackgroundColor3 = T.Bg, BackgroundTransparency = 0.05, CornerRadius = UDim.new(0, 16), StrokeColor = T.Gold,
		StrokeThickness = 2, StrokeTransparency = 0.2 }, {
		UIKit.Create("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingBottom = UDim.new(0, 22),
			PaddingLeft = UDim.new(0, 26),
			PaddingRight = UDim.new(0, 26),
		}),
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})
	box.Parent = overlay
	UIKit.StyledLabel({
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 26,
		Text = tostring(title or ""),
		Parent = box,
	}, "Title", boxArt)
	if body ~= nil and tostring(body) ~= "" then
		local bodyLabel = UIKit.StyledLabel({
			Name = "Body",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 18,
			Text = tostring(body),
			Parent = box,
		}, "Body", boxArt)
		UIKit.BalanceLines(bodyLabel) -- 검수 10/10: no word alone on a line
	end
	local row = UIKit.Create("Frame", {
		Name = "Buttons",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = box,
	})
	UIKit.ArtTextButton("BtnSecondary", {
		Name = "Cancel",
		Text = "Cancel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -8, 0, 2),
		Size = UDim2.fromOffset(180, 52),
		Color = Color3.fromRGB(70, 72, 92),
		TextSize = 20,
		Parent = row,
	}, close)
	UIKit.ArtTextButton("BtnConfirm", {
		Name = "Confirm",
		Text = tostring(confirmText or "OK"),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 8, 0, 2),
		Size = UDim2.fromOffset(180, 52),
		Color = T.Good,
		TextColor = DARK_TEXT,
		TextSize = 20,
		Parent = row,
	}, function()
		close()
		if type(onConfirm) == "function" then
			task.spawn(function()
				local ok, err = pcall(onConfirm)
				if not ok then warnThrottled("confirm handler error: " .. tostring(err)) end
			end)
		end
	end)
	overlay.Parent = UIKit.Gui
end

----------------------------------------------------------------- text / attribute helpers
function UIKit.Fmt(key, ...)
	local template = Config.Text[key]
	if type(template) ~= "string" then
		warnThrottled("missing Config.Text." .. tostring(key))
		return tostring(key)
	end
	local ok, out = pcall(string.format, template, ...)
	if ok then return out end
	warnThrottled("format failed for Config.Text." .. tostring(key) .. ": " .. tostring(out))
	return template
end

function UIKit.Attr(name, default)
	if not LocalPlayer then return default end
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- connects LocalPlayer:GetAttributeChangedSignal for each name and calls fn() once now; returns the connections
function UIKit.OnAttr(names, fn)
	if type(names) == "string" then names = { names } end
	local conns = {}
	if type(fn) ~= "function" or not LocalPlayer then return conns end
	for _, name in names do
		table.insert(conns, LocalPlayer:GetAttributeChangedSignal(name):Connect(function()
			safeCall(fn)
		end))
	end
	safeCall(fn)
	return conns
end

local function gameState()
	return ReplicatedStorage:FindFirstChild("GameState")
end

function UIKit.GameAttr(name, default)
	local gs = gameState()
	if not gs then return default end
	local v = gs:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- same as OnAttr for ReplicatedStorage.GameState; never yields (binds later if GameState is not there yet)
function UIKit.OnGameAttr(names, fn)
	if type(names) == "string" then names = { names } end
	local conns = {}
	if type(fn) ~= "function" then return conns end
	local function bind(gs)
		for _, name in names do
			table.insert(conns, gs:GetAttributeChangedSignal(name):Connect(function()
				safeCall(fn)
			end))
		end
	end
	local gs = gameState()
	if gs then
		bind(gs)
	else
		local waitConn
		waitConn = ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "GameState" and child:IsA("Folder") then
				waitConn:Disconnect()
				bind(child)
				safeCall(fn)
			end
		end)
		table.insert(conns, waitConn)
	end
	safeCall(fn)
	return conns
end

----------------------------------------------------------------- language (A23-48: English only)
-- always "en" (kept for callers such as Keybinds' key labels)
function UIKit.Lang()
	return "en"
end

-- a player text from a central table: t[key .. "En"] when a table still keeps both, else t[key]; extra args format it
function UIKit.Tx(t, key, ...)
	if type(t) ~= "table" then return "" end
	local s = t[key .. "En"] or t[key]
	if type(s) ~= "string" then s = s == nil and "" or tostring(s) end
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return ok and out or s
	end
	return s
end

-- full-screen pickers (FactionPicker, ClassPicker; 검수 10/09, RELEASE_PLAN 10/07): MainGui keeps to DeviceSafeInsets, so
-- a dim on a picker's root left the phone's side edges undimmed. This moves the root's dim onto its own layer that
-- covers the whole screen (no insets), just under MainGui. Returns show(open) (nil when it could not be made: the root
-- keeps its own dim then).
function UIKit.FullScreenDim(root, name)
	if typeof(root) ~= "Instance" or not root:IsA("GuiObject") then return nil end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local ok, frame = pcall(function()
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		pcall(function() -- after IgnoreGuiInset (which rewrites ScreenInsets)
			g.ScreenInsets = Enum.ScreenInsets.None
			g.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
		end)
		g.DisplayOrder = (UIKit.Gui and UIKit.Gui.DisplayOrder or 10) - 1
		g.Enabled = false
		local f = Instance.new("Frame")
		f.Name = "Dim"
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = root.BackgroundColor3
		f.BackgroundTransparency = root.BackgroundTransparency
		f.Parent = g
		g.Parent = pg
		return f
	end)
	if not ok or not frame then return nil end
	root.BackgroundTransparency = 1
	return function(open)
		local g = frame.Parent
		if g and g:IsA("ScreenGui") then g.Enabled = open == true end
	end, frame
end

----------------------------------------------------------------- lifecycle
function UIKit.Init(registry)
	C = registry
	local T = UIKit.Theme
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MainGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- CR-L34: still under the top bar (H4 handles it), but clear of notches / rounded corners on landscape phones.
	-- Set after IgnoreGuiInset (which rewrites ScreenInsets); pcall'd for clients without these properties.
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
	pcall(function()
		gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	end)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	UIKit.Gui = gui
	-- Includes text created directly by HUD / panels / map modules after UIKit.Init.
	gui.DescendantAdded:Connect(watchFont)
	for _, descendant in gui:GetDescendants() do watchFont(descendant) end

	uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = gui

	-- toast stack (top-center, below the status chips)
	toastHolder = UIKit.Create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOAST_Y + TOP_FALLBACK),
		Size = UDim2.fromOffset(TOAST_WIDTH, 10),
		AutomaticSize = Enum.AutomaticSize.Y, -- its height = the toasts: anchored at the bottom it grows upward (Avoid)
		BackgroundTransparency = 1,
		ZIndex = Z_TOASTS,
		Parent = gui,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, NOTIFY.ToastGap), -- 6, also used by UIKit.PlaceNotify's fit count
		}),
	})
	-- Studio-only check hook (UiSandbox captures, 2026-10-08): the local attribute NotifyAvoidPreview = "x,y,w,h" (MainGui
	-- du) acts like an open window for the toasts, "" like its close (the same path as Panels' FRAME.TellNotify)
	if game:GetService("RunService"):IsStudio() and LocalPlayer then
		LocalPlayer:GetAttributeChangedSignal("NotifyAvoidPreview"):Connect(function()
			local v = LocalPlayer:GetAttribute("NotifyAvoidPreview")
			local x, y, w, h = string.match(type(v) == "string" and v or "", "^(%-?[%d%.]+),(%-?[%d%.]+),([%d%.]+),([%d%.]+)$")
			UIKit.SetNotifyAvoid(x and { X = tonumber(x), Y = tonumber(y), W = tonumber(w), H = tonumber(h) } or nil)
		end)
	end

	-- announce banner (30% screen height until UIKit.PlaceNotify moves it into the HUD v2 notify column)
	announceFrame = UIKit.Create("Frame", {
		Name = "Announce",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.9, 0, 0, 84),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = Z_ANNOUNCE,
		Parent = gui,
	}, {
		UIKit.Create("UISizeConstraint", { MaxSize = Vector2.new(880, 400) }), -- tall enough for BannerLines lines
		UIKit.Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0),
				NumberSequenceKeypoint.new(0.85, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	announcePop = UIKit.Create("UIScale", { Name = "Pop", Parent = announceFrame })
	-- the text wraps (never TextScaled: a long English line was clipped at its floor); UIKit.WrapHeight sizes it (up to
	-- NOTIFY.BannerLines lines) and the frame follows it (NOTIFY.FitAnnounce), never below the column's banner height
	announceLabel = UIKit.Create("TextLabel", {
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, NOTIFY.BannerTextOld),
		BackgroundTransparency = 1,
		TextScaled = false,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = NOTIFY.BannerTextOld,
		TextColor3 = T.Gold,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextTransparency = 1,
		Text = "",
		Parent = announceFrame,
	})
	-- handoff queue 3: the approved red BannerAlert ribbon behind the words once uploaded (NOTIFY.AlertArt; under the
	-- words and the icon): white words with a dark red rim (the approved note)
	NOTIFY.AlertImg = UIKit.ArtImage(NOTIFY.AlertArt.Part, { Name = "Art", Size = UDim2.fromScale(1, 1),
		ImageTransparency = 1, ZIndex = 0, SliceScale = NOTIFY.BannerH / NOTIFY.AlertArt.Base, Parent = announceFrame })
	if NOTIFY.AlertImg then
		announceLabel.TextColor3 = Color3.new(1, 1, 1)
		announceLabel.TextStrokeColor3 = NOTIFY.AlertArt.Stroke
	end
	UIKit.WrapHeight(announceLabel, NOTIFY.BannerLines, nil, NOTIFY.FitAnnounce)
	UIKit.BalanceLines(announceLabel) -- 검수 10/10: no word alone on a line

	gui.Parent = playerGui

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

function UIKit.ShouldHoldBanners()
	local me = game:GetService("Players").LocalPlayer
	-- A23-3 / A23-68 #4 (user 2026-10-07): world banners and event toasts wait until the first [Claim] (TutorialStep
	-- 0 / 1 / 2; claimTutorial writes 99 first), then FlushBanners shows the last two
	local step = me:GetAttribute("TutorialStep")
	local steps = type(Config.Tutorial) == "table" and Config.Tutorial.Steps or nil
	local done = type(steps) == "table" and tonumber(steps.Done) or 99
	if type(step) == "number" and step >= 0 and step < done then return true end
	local intro = C and C.Intro
	if type(intro) == "table" and type(intro.IsOpen) == "function" then
		local ok, open = pcall(intro.IsOpen)
		if ok and open then return true end
	end
	return false
end

-- 검수 10/10 (user photo: the war bar + its info line + the goose chip wore NEW! at once): one NEW! at a time. A part
-- inside or around the part that wears the tag (or waits for it) is the same thing and gets none; a different part waits
-- its turn (NOTIFY.NewQ) and gets its tag when the one before goes (+ Gap s; a part gone or hidden by then is skipped).
-- The same part again restarts its tag. Returns the tag, or nil (queued / the same thing / not a GuiObject)
function UIKit.NewTag(target, text)
	if typeof(target) ~= "Instance" or not target:IsA("GuiObject") then return nil end
	local q, cfg = NOTIFY.NewQ, NOTIFY.NewTag
	local function same(a, b) return a == b or a:IsDescendantOf(b) or b:IsDescendantOf(a) end
	local now = os.clock()
	local act = q.Active
	local busy = act ~= nil and act.Parent ~= nil and now < q.Until
	if busy and act ~= target and same(act, target) then return nil end
	for _, w in q.Queue do
		if same(w.Target, target) then return nil end
	end
	if busy and act ~= target then
		table.insert(q.Queue, { Target = target, Text = text })
		if not q.Draining then
			q.Draining = true
			task.delay(math.max(0, q.Until - now), UIKit.NextNewTag)
		end
		return nil
	end
	q.Active, q.Until = target, now + (tonumber(cfg.Seconds) or 6) + (tonumber(cfg.Gap) or 0.4)
	return UIKit.ShowNewTag(target, text)
end

-- the next waiting NEW! (its part still there and shown), then the one after it when that one goes
function UIKit.NextNewTag()
	local q, cfg = NOTIFY.NewQ, NOTIFY.NewTag
	q.Draining = false
	while #q.Queue > 0 do
		local w = table.remove(q.Queue, 1)
		local t = w.Target
		if t.Parent ~= nil and t.Visible then
			q.Active, q.Until = t, os.clock() + (tonumber(cfg.Seconds) or 6) + (tonumber(cfg.Gap) or 0.4)
			UIKit.ShowNewTag(t, w.Text)
			break
		end
	end
	if #q.Queue > 0 then
		q.Draining = true
		task.delay(math.max(0, q.Until - os.clock()), UIKit.NextNewTag)
	end
end

-- A23-68 #4 / quality ⑨ (user 2026-10-07): a HUD part that shows for the first time (the first [Claim] unfolds the quest
-- lines, the war meter's info line and the next-event line) pops in and wears a small gold "NEW!" tag on its top-right
-- corner for NOTIFY.NewTag.Seconds. No pop with ReducedMotion, nor on a part that already has its own UIScale (a press /
-- pop scale of its own). Calling it again restarts the tag. Returns the tag (callers go through UIKit.NewTag: one at a time)
function UIKit.ShowNewTag(target, text)
	if typeof(target) ~= "Instance" or not target:IsA("GuiObject") then return nil end
	local cfg = NOTIFY.NewTag
	local old = target:FindFirstChild("NewTag")
	if old then old:Destroy() end
	text = (type(text) == "string" and text ~= "") and text or cfg.Text
	local s = currentScale()
	local h = math.max(cfg.H, math.ceil(cfg.MinPx * UIKit.PxFloor() / s) + 6)
	local size = h - 6
	-- a thin target (a one-line row, a chip) wears it beside its right end, ThinDY below its middle: on the top-right
	-- corner it climbed onto the row above (검수 2026-10-07: on phones it covered the war bar's Horns end; centred it still
	-- touched the Horns shield hanging over the row by 2 px); taller ones (the quest lines) keep the corner
	local thin = target.AbsoluteSize.Y / s <= h * cfg.ThinK
	local tag = UIKit.ArtFrame("Chip", {
		Name = "NewTag",
		AnchorPoint = thin and Vector2.new(0, 0.5) or Vector2.new(1, 0.5),
		Position = thin and UDim2.new(1, 4, 0.5, cfg.ThinDY) or UDim2.new(1, 6, 0, 0),
		Size = UDim2.fromOffset(math.ceil(size * cfg.WidthEm), h),
		ImageColor3 = cfg.Gold,
		ZIndex = target.ZIndex + 6,
		Active = false,
	}, { Color = cfg.Gold, CornerRadius = UDim.new(0.5, 0), StrokeColor = STYLE.Navy, StrokeThickness = 2 })
	local label = UIKit.StyledLabel({
		Name = "Text",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -4),
		TextSize = size,
		ZIndex = tag.ZIndex + 1,
		Parent = tag,
	}, "Number", true)
	local pop = UIKit.Create("UIScale", { Name = "Pop", Scale = 1, Parent = tag })
	tag.Parent = target
	if not UIKit.ReducedMotion() then
		pop.Scale = 0.2
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if target:FindFirstChildOfClass("UIScale") == nil then
			local grow = UIKit.Create("UIScale", { Name = "NewPop", Scale = 0.6, Parent = target })
			local tw = TweenService:Create(grow, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 })
			tw.Completed:Connect(function() grow:Destroy() end)
			tw:Play()
		end
	end
	task.delay(cfg.Seconds, function()
		if not tag.Parent then return end
		local info = TweenInfo.new(0.3)
		if tag:IsA("ImageLabel") then TweenService:Create(tag, info, { ImageTransparency = 1 }):Play() end
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		task.delay(0.32, function() tag:Destroy() end)
	end)
	return tag
end

-- 창 꾸미기 ③ (검수 2026-10-07; user on the 'Vacation Bonus' window: "이런 화면도 멋있게"): ONE reward popup for the vacation
-- bonus, the daily chest, event rewards and level ups. A dark backdrop; behind the plate the faction-tinted round
-- RewardGlow breathing and RewardSparkle twinkles (no rays: user 2026-10-07); the plate (the faction plate
-- RewardPanelHalo / Horns, else the navy PanelCard) with the body inside its Inner; the faction ribbon RewardRibbonHalo /
-- Horns (else BannerGold) over its top edge with the title in its TextRect; the lines (navy on the cream Halo plate); one
-- row of reward slots (RewardSlot, else SlotCommon) with the icon and the amount counting up from 0; a big Claim capsule
-- (BtnConfirm) and an optional blue second button. No pop / breathing / twinkle with ReducedMotion.
-- opts = { Title, Lines = { string } | string, Rewards = { { Icon = UIArt key or Config.Loot item id, Amount = number,
--   Label = string? } }, Button = "Claim!", OnClaim = fn?, Second = string?, OnSecond = fn?, Faction = "Halo" | "Horns"? }
-- Returns { Close = fn(), Frame = the overlay }. The popup closes itself after either button.
function UIKit.RewardPopup(opts)
	if not UIKit.Gui then return nil end
	opts = type(opts) == "table" and opts or {}
	local cfg = NOTIFY.Reward
	local reduced = UIKit.ReducedMotion()
	local faction = opts.Faction == "Halo" and "Halo" or (opts.Faction == "Horns" and "Horns" or nil)
	local overlay = UIKit.Create("TextButton", {
		Name = "RewardPopup",
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(3, 3),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = Z_CONFIRM - 2,
	})
	local handle = { Frame = overlay }
	local closed = false
	-- the room under the top bar decides the size class (du)
	local sc = currentScale()
	local gsize = UIKit.Gui.AbsoluteSize
	local compact = gsize.Y > 0 and (gsize.Y - insetY() - 16) / sc < cfg.CompactBelow
	local plateW = compact and math.min(cfg.WideW, gsize.X / sc - 40) or cfg.W
	local slotSize = compact and cfg.SlotCompact or cfg.SlotSize
	local buttonH = compact and cfg.ButtonHCompact or cfg.ButtonH
	-- PC: the whole popup (plate, ribbon, slots, words) grows to PcFrac of the screen width; touch screens keep 1
	local grow = 1
	if not compact and not UserInputService.TouchEnabled and gsize.X > 0 and sc > 0 then
		grow = math.clamp(gsize.X * cfg.PcFrac / sc / plateW, 1, cfg.GrowMax)
	end
	-- the faction parts once uploaded (each falls back on its own: PanelCard / BannerGold / SlotCommon)
	local panelKey = faction and artPart(cfg.Panel[faction]) and cfg.Panel[faction] or "PanelCard"
	local bannerKey = faction and artPart(cfg.Banner[faction]) and cfg.Banner[faction] or "BannerGold"
	local panelDef, bannerDef = rawPart(panelKey), rawPart(bannerKey)
	local artBanner = bannerKey ~= "BannerGold" -- a faction ribbon: wider than the plate, its title in the TextRect
	local bannerW = compact and cfg.BannerCompact or cfg.BannerW
	local anchorY, titleMax = 0.62, cfg.TitleSize
	if artBanner then
		bannerW = math.floor(math.min(plateW * cfg.BannerOver, compact and cfg.BannerArtCompact or cfg.BannerArtW))
		anchorY, titleMax = cfg.BannerArtAnchor, compact and cfg.TitleArtCompact or cfg.TitleArt
	end
	local aspect = cfg.BannerAspect
	if bannerDef and typeof(bannerDef.Size) == "Vector2" and bannerDef.Size.Y > 0 then
		aspect = bannerDef.Size.X / bannerDef.Size.Y
	end
	local bannerH = bannerW / aspect
	local tint = faction and cfg.Tint[faction] or cfg.Tint.None
	-- the body stays inside the faction plate's Inner (cream / plum) at the plate's slice scale, off the rim
	local pad = { L = 26, R = 26, T = 0, B = 24 }
	if panelKey ~= "PanelCard" and panelDef and typeof(panelDef.Inner) == "Rect" and typeof(panelDef.Size) == "Vector2" then
		local k, r = tonumber(panelDef.SliceScale) or 0.5, panelDef.Inner
		pad.L = math.ceil(r.Min.X * k) + cfg.InnerPad
		pad.R = math.ceil((panelDef.Size.X - r.Max.X) * k) + cfg.InnerPad
		pad.T = math.ceil(r.Min.Y * k)
		pad.B = math.ceil((panelDef.Size.Y - r.Max.Y) * k) + cfg.InnerPad
	end
	local plateLight = panelKey ~= "PanelCard" and panelDef ~= nil and panelDef.Tone == "Parchment" -- navy words

	-- behind the plate, in one holder on the plate's centre (placed and scaled with it after the first frame): the round
	-- glow and the sparkles
	local deco = UIKit.Create("Frame", { Name = "Deco", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false,
		ZIndex = overlay.ZIndex + 1, Parent = overlay })
	local decoFit = UIKit.Create("UIScale", { Name = "Fit", Scale = 1, Parent = deco })
	local glowSize = math.floor(bannerW * cfg.GlowOver)
	local glow = UIKit.ArtImage(cfg.Glow, { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(glowSize, glowSize), ImageColor3 = tint, ImageTransparency = cfg.GlowAlpha, ZIndex = 1,
		Active = false, Parent = deco })
	if glow and not reduced then -- breathes: a UIScale between GlowPulse[1] and [2], back and forth
		local breath = UIKit.Create("UIScale", { Name = "Breath", Scale = cfg.GlowPulse[1], Parent = glow })
		local tw = TweenService:Create(breath, TweenInfo.new(cfg.GlowPulse[3], Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut, -1, true), { Scale = cfg.GlowPulse[2] })
		tw:Play()
		overlay.Destroying:Connect(function() tw:Cancel() end)
	end
	local sparkles = {}
	local sparkTint = faction and cfg.SparkleTint[faction] or cfg.SparkleTint.Halo
	for i, spec in cfg.Sparkles do
		local size = reduced and spec[4] or 0 -- they grow in when they twinkle
		local img = UIKit.ArtImage(cfg.Sparkle, { Name = "Sparkle" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size), ImageColor3 = sparkTint, ZIndex = 3, Active = false, Parent = deco })
		if not img then break end
		table.insert(sparkles, { Img = img, Spec = spec })
	end

	-- the plate: its height follows the body (AutomaticSize Y)
	local panel = UIKit.ArtFrame(panelKey, {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(plateW, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = overlay.ZIndex + 2,
		Active = true,
	}, { BackgroundColor3 = UIKit.Theme.Bg, BackgroundTransparency = 0.04, CornerRadius = UDim.new(0, 18),
		StrokeColor = UIKit.Theme.Gold, StrokeThickness = 2 })
	local pop = UIKit.Create("UIScale", { Name = "Pop", Scale = 1, Parent = panel })
	panel.Parent = overlay

	-- the banner over the plate's top edge, the title in its text box (the part's TextRect; BannerGold's own box)
	local banner = UIKit.ArtImage(bannerKey, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, anchorY),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(bannerW, bannerH),
		ZIndex = panel.ZIndex + 3,
		Active = false,
		Parent = panel,
	})
	local titleParent = banner or panel
	local textRect = bannerDef and bannerDef.TextRect
	local titlePos, titleSize = UDim2.fromScale(0.22, 0.2), UDim2.fromScale(0.56, 0.42)
	if type(textRect) == "table" and #textRect == 4 then
		titlePos, titleSize = UDim2.fromScale(textRect[1], textRect[2]), UDim2.fromScale(textRect[3], textRect[4])
	end
	local title = UIKit.Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = tostring(opts.Title or ""),
		Position = banner and titlePos or UDim2.fromOffset(0, -cfg.TitleSize - 10),
		Size = banner and titleSize or UDim2.new(1, 0, 0, cfg.TitleSize + 6),
		TextScaled = true,
		TextWrapped = false, -- one line that shrinks (phones showed "Vacation" with "Bonus" wrapped away)
		ZIndex = panel.ZIndex + 4,
	}, { UIKit.Create("UITextSizeConstraint", { MaxTextSize = banner and titleMax or cfg.TitleSize, MinTextSize = 1 }) })
	-- the banner's text box is narrow: a long title ("Vacation Bonus" on phones) shrinks down to 12 px instead of losing words
	title:SetAttribute("StyleMinPx", 12)
	-- navy on the gold BannerGold; white with the navy rim on the faction ribbons (the sheet's look)
	UIKit.StyleText(title, "Title", banner ~= nil and not artBanner)
	title.Parent = titleParent

	-- the body: lines, the reward slots, the buttons
	local body = UIKit.Create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = panel.ZIndex + 1,
		Parent = panel,
	}, {
		-- under the banner's overlap (BannerGold: 0.42 of its height) and inside the plate's Inner
		UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, math.max(math.floor(bannerH * (1.04 - anchorY)), pad.T) + 10),
			PaddingBottom = UDim.new(0, pad.B), PaddingLeft = UDim.new(0, pad.L), PaddingRight = UDim.new(0, pad.R) }),
		UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14) }),
	})
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local lines = opts.Lines
	if type(lines) == "string" then lines = { lines } end
	lines = type(lines) == "table" and lines or {}
	if compact then -- short screens: the first line(s) only, so the popup fits without shrinking
		lines = table.move(lines, 1, math.min(#lines, math.max(1, tonumber(opts.CompactLines) or 1)), 1, {})
	end
	for _, line in lines do
		local label = UIKit.StyledLabel({ Name = "Line", Text = tostring(line), Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = compact and cfg.LineCompact or cfg.LineSize,
			LayoutOrder = nextOrder(),
			ZIndex = body.ZIndex + 1, Parent = body }, "Body", plateLight)
		UIKit.BalanceLines(label) -- 검수 10/10 (the Vacation card: one word alone on the 2nd line): even lines
	end
	local counters = {}
	local rewards = type(opts.Rewards) == "table" and opts.Rewards or {}
	if #rewards > 0 then
		local row = UIKit.Create("Frame", { Name = "Rewards", Size = UDim2.new(1, 0, 0, slotSize + 26),
			BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = body.ZIndex + 1, Parent = body }, {
			UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, cfg.SlotGap) }),
		})
		local slotKey = artPart(cfg.Slot) and cfg.Slot or "SlotCommon"
		for i, r in rewards do
			if i > 3 then break end
			local cell = UIKit.Create("Frame", { Name = "Reward" .. i, Size = UDim2.fromOffset(slotSize, slotSize + 26),
				BackgroundTransparency = 1, LayoutOrder = i, ZIndex = row.ZIndex + 1, Parent = row })
			local slot = UIKit.ArtFrame(slotKey, { Name = "Slot", Size = UDim2.fromOffset(slotSize, slotSize),
				ZIndex = cell.ZIndex + 1 }, { BackgroundColor3 = UIKit.Theme.Bg, CornerRadius = UDim.new(0, 12),
				StrokeColor = UIKit.Theme.Gold, StrokeThickness = 2 })
			slot.Parent = cell
			UIKit.ItemIcon(tostring(r.Icon or "IconCoin"), { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = slot.ZIndex + 1,
				Parent = slot })
			local amount = UIKit.StyledLabel({ Name = "Amount", Text = "+0", AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 24, 0, 24), TextScaled = true,
				ZIndex = cell.ZIndex + 2, Parent = cell }, "Number")
			table.insert(counters, { Label = amount, Amount = math.max(0, math.floor(tonumber(r.Amount) or 0)) })
		end
	end
	local buttons = UIKit.Create("Frame", { Name = "Buttons", Size = UDim2.new(1, 0, 0, buttonH + 4),
		BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = body.ZIndex + 1, Parent = body }, {
		UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14) }),
	})

	function handle.Close()
		if closed then return end
		closed = true
		if reduced then
			overlay:Destroy()
			return
		end
		local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(pop, info, { Scale = 0.85 * (handle.Fit or 1) }):Play()
		TweenService:Create(overlay, info, { BackgroundTransparency = 1 }):Play()
		task.delay(0.17, function() overlay:Destroy() end)
	end
	local function press(fn)
		return function()
			if closed then return end
			if type(fn) == "function" then
				local ok, err = pcall(fn)
				if not ok then warnThrottled("reward popup handler: " .. tostring(err)) end
			end
			handle.Close()
		end
	end
	-- both buttons inside the body (the faction plates' rims are thicker: PC 230 + 161 + 14 ran onto the gold line)
	local second = type(opts.Second) == "string" and opts.Second ~= ""
	local room = plateW - pad.L - pad.R
	local claimW = math.floor(math.min(cfg.ButtonW, second and (room - 14) / 1.7 or room))
	UIKit.ArtTextButton("BtnConfirm", { Name = "Claim", Text = tostring(opts.Button or "Claim!"), LayoutOrder = 2,
		Size = UDim2.fromOffset(claimW, buttonH), TextSize = 24, ZIndex = buttons.ZIndex + 1, Parent = buttons,
		Color = UIKit.Theme.Good }, press(opts.OnClaim))
	if second then
		UIKit.ArtTextButton("BtnSecondary", { Name = "Second", Text = opts.Second, LayoutOrder = 1,
			Size = UDim2.fromOffset(math.floor(claimW * 0.7), buttonH), TextSize = 20,
			ZIndex = buttons.ZIndex + 1, Parent = buttons }, press(opts.OnSecond))
	end

	overlay.Parent = UIKit.Gui
	-- the entrance: the plate pops (to the PC size, or the scale that fits the screen), then the amounts count up one after
	-- the other. Fit (UiSandbox phone 749x361 2026-10-07: the banner hung above the screen): the plate + the banner's
	-- overhang stay inside the space under the top bar, with a small margin
	handle.Fit = grow
	pop.Scale = reduced and grow or 0.6 * grow
	-- the plate's height in plate units (du before the pop / fit scale)
	local function plateH()
		return panel.AbsoluteSize.Y / math.max(pop.Scale, 0.01) / currentScale()
	end
	-- the glow on the banner's centre, the sparkles around the banner and the plate
	local function placeDeco()
		local h = plateH()
		deco.Position = panel.Position
		decoFit.Scale = handle.Fit
		local by = -h / 2 - bannerH * (anchorY - 0.5)
		if glow then glow.Position = UDim2.fromOffset(0, math.floor(by)) end
		for _, sp in sparkles do
			local spec = sp.Spec
			local x, y = spec[2] * plateW / 2, spec[3] * h / 2
			if spec[1] == "B" then x, y = spec[2] * bannerW / 2, by + spec[3] * bannerH / 2 end
			sp.Img.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		end
		deco.Visible = true
	end
	-- one sparkle: grows and turns 45, shrinks and turns 90 (the same star again), rests, again until the popup closes
	local function twinkle(img, size, first)
		task.spawn(function()
			task.wait(first)
			while not closed and img.Parent do
				img.Rotation = 0
				TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = UDim2.fromOffset(size, size), Rotation = 45 }):Play()
				task.wait(0.5)
				if closed or not img.Parent then break end
				TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Size = UDim2.fromOffset(0, 0), Rotation = 90 }):Play()
				local rest = cfg.SparkleRest
				task.wait(0.3 + rest[1] + math.random() * (rest[2] - rest[1]))
			end
		end)
	end
	task.spawn(function()
		task.wait() -- one frame: the plate's AutomaticSize has run
		if closed or not panel.Parent then return end
		local s = currentScale()
		local free = (UIKit.Gui.AbsoluteSize.Y - insetY() - 16) / s -- du under the top bar
		local need = plateH() + bannerH * anchorY + 8
		handle.Fit = (free > 0 and need * grow > free) and math.max(0.5, free / need) or grow
		-- centred under the top bar (the banner's overhang counted)
		panel.Position = UDim2.new(0.5, 0, 0.5, math.floor((insetY() / s + bannerH * anchorY * handle.Fit) / 2))
		placeDeco()
		-- the body can still grow after the pop (fonts settling): the decoration follows the plate's top
		local popping = not reduced
		panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if not popping and not closed then placeDeco() end
		end)
		if reduced then
			pop.Scale = handle.Fit
			return
		end
		local tw = TweenService:Create(pop, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = handle.Fit })
		tw.Completed:Connect(function()
			popping = false
			if not closed and panel.Parent then placeDeco() end
		end)
		tw:Play()
		for i, sp in sparkles do
			twinkle(sp.Img, sp.Spec[4], 0.15 + (i - 1) * 0.22)
		end
	end)
	for i, c in counters do
		task.delay(reduced and 0 or 0.25 + (i - 1) * 0.15, function()
			if closed or not c.Label.Parent then return end
			if reduced or c.Amount <= 0 then
				c.Label.Text = "+" .. Util.FormatNumber(c.Amount)
				return
			end
			local v = Instance.new("NumberValue")
			v.Changed:Connect(function(x) c.Label.Text = "+" .. Util.FormatNumber(math.floor(x + 0.5)) end)
			local tw = TweenService:Create(v, TweenInfo.new(cfg.Count, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Value = c.Amount })
			tw.Completed:Connect(function() v:Destroy() end)
			tw:Play()
		end)
	end
	return handle
end

-- show the held world banners (called when the first mission is accepted / the opening ends)
function UIKit.FlushBanners()
	if type(UIKit.HeldBanners) ~= "table" or #UIKit.HeldBanners == 0 or UIKit.ShouldHoldBanners() then return end
	local held = UIKit.HeldBanners
	UIKit.HeldBanners = {}
	task.delay(3, function()
		for _, b in held do
			if b[3] == "toast" then
				UIKit.Toast(b[1], "reward", b[2], b[4]) -- held server-wide Epic toast (A23-15); b[4] = optional icon
			else
				UIKit.Announce(b[1], b[2], b[4])
			end
			task.wait(3)
		end
	end)
end

function UIKit.Start()
	-- re-read the inset once the top bar has settled (it can be 0 during the first frames)
	task.delay(1, applyScale)
	FONT.Preload()
	task.spawn(function()
		local ids = {}
		for _, key in NOTIFY.PreloadArt do
			local def = artPart(key)
			if def then table.insert(ids, def.Id) end
		end
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
	end)


	UIKit.HeldBanners = {}
	local me = game:GetService("Players").LocalPlayer
	me:GetAttributeChangedSignal("TutorialStep"):Connect(function() UIKit.FlushBanners() end)

	-- the remote normally exists already; never block the other client modules' Start on it
	task.spawn(function()
		local remote = Net.Get("Notify")
		remote.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then return end
			local text = payload.Text
			if type(text) ~= "string" or text == "" then return end
			local duration = tonumber(payload.Duration)
			if payload.Kind == "announce" then
				-- A23-3 / A23-9: world banners (goose / war / kaiju / bounty) wait until the first mission is
				-- accepted and while the opening plays
				if UIKit.ShouldHoldBanners() then
					table.insert(UIKit.HeldBanners, { text, duration })
					if #UIKit.HeldBanners > 2 then table.remove(UIKit.HeldBanners, 1) end
					return
				end
				UIKit.Announce(text, duration)
			else
				UIKit.Toast(text, payload.Kind, duration)
			end
		end)
	end)

	print("[UIKit] started")
end

return UIKit
