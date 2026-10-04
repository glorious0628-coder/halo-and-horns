-- FactionPicker.luau : first-join faction choice with the crown-shard premise.
-- Visible exactly when DataLoaded == true and Faction == "None". Three cards: 빛의 기사단 / 뿔 군단 / 장인 길드
-- (SPEC_ADDENDUM A6). One tap on "이 편으로!" sends ChooseFaction; no confirm, no draw animation (A7-4).
-- Look = the user's selected centred A composition: title ribbon, a wide three-line premise strip, three cards
-- and the altar note beneath. The original text-free faction card images (Config.UIArt.Parts.Card<Faction>, regions in
-- Config.UIArt.CardLayout) holding the name, the one-line lore, the motto, four perk rows (Config.UIArt.FactionPerks)
-- and the baked "이 편으로!" button, then the altar note. A missing card id or layout draws the old code-styled card
-- instead (IMG-R4), so the picker never breaks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local FactionPicker = {}

local TAG = "FactionPicker"
local player = Players.LocalPlayer

local FACTION_IDS = { "Halo", "Horns", "Neutral" }
local CLICK_LOCK = 2 -- seconds the choose buttons stay disabled after a click
local OPEN_LOCK = 0.6 -- CR-M26: card input ignored this long after the picker opens (a fast 2nd tap)
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

-- GPT art (Config.UIArt, addendum A14-3), read directly so the cards still lay out when UIKit lacks the art helpers
local ART = type(Config.UIArt) == "table" and Config.UIArt or {}
local Art = {
	Enabled = ART.Enabled ~= false,
	Parts = type(ART.Parts) == "table" and ART.Parts or {},
	Layout = type(ART.CardLayout) == "table" and ART.CardLayout or {},
	Perks = type(ART.FactionPerks) == "table" and ART.FactionPerks or {},
	Colors = type(ART.Colors) == "table" and ART.Colors or {},
	Fonts = type(ART.Fonts) == "table" and ART.Fonts or {},
}

-- E owns its parts; shared CardHalo/TitleRibbon/PanelParchment are also used by other screens.
local E = {
	Config = type(ART.FactionE) == "table" and ART.FactionE or {},
	World = { Active = false, Records = {}, Connections = {}, LegacyChat = nil, CoreChat = nil },
	Warnings = {},
}
E.Enabled = Art.Enabled and E.Config.Enabled == true
E.Parts = type(E.Config.Parts) == "table" and E.Config.Parts or {}
E.Layout = type(E.Config.Layout) == "table" and E.Config.Layout or {}
E.Semantics = type(E.Config.SemanticText) == "table" and E.Config.SemanticText or {}
E.BakedText = E.Config.BakedText == true
E.Enabled = E.Enabled and E.BakedText
E.Keys = { Halo = "FactionCardHaloE", Horns = "FactionCardHornsE", Neutral = "FactionCardNeutralE",
	Title = "FactionTitleRibbonE", Premise = "FactionPremisePanelE", Footer = "FactionFooterPanelE" }
E.Rects = { Title = { 0.3258, 0.0282, 0.3460, 0.1007 }, Premise = { 0.1553, 0.1309, 0.6869, 0.1320 },
	Cards = { 0.1515, 0.2638, 0.6881, 0.6254 }, Footer = { 0.2071, 0.8892, 0.5808, 0.0806 } }

-- art layout tunables (canvas units = inside MainGui's UIScale)
local LAY = {
	Gutter = 16, -- side gutter
	Gap = 12, -- between cards
	CardMaxH = 640,
	Lift = 0.04, -- room around the cards for the hover scale + glow (fraction of the card height)
	-- Only a narrow touch viewport uses larger cards and a sideways scroll; desktop A always shows all cards.
	NeedCardK = 26,
	PremiseMaxW = 1600, PremiseFrac = 0.66,
	TitleFrac = 0.10, TitleMin = 40, TitleMax = 140, -- compact ribbon on short viewports
	TextFrac = 0.021, TextMax = 16, -- physical caption target; preserve the three sentences above the cards
	LoreShort = { Halo = "후광을 얻은 자들.", Horns = "뿔을 얻은 자들.", Neutral = "조각을 다듬는 자들." },
	LoreTiny = { Horns = { "뿔을 얻었어요.", "뿔을얻었어요." }, Neutral = "조각장인들." },
	MottoShort = { Halo = "지키고, 치유해, 되찾아라!", Horns = "털고, 버텨, 괴수가 돼라!", Neutral = "줍지 말고 다듬어 만들어라!" },
	MottoTiny = { Halo = "지키고되찾아라!", Horns = "털고버텨괴수가돼라!", Neutral = "다듬고만들어라!" },
	PerkTiny = {
		Halo = { "경험치+30%", "체력+20%·회복", "동료치유", "골드자동지급" },
		Horns = { "골드+25%", { "공격+15%·흡혈", "공격+15% 흡혈", "공격+15%흡혈" }, { "발사게이지175", "발사175" }, "별5개괴수변신" },
		Neutral = { "싸움버프없음", "안전(PvP없음)", "약탈·수배없음", { "제작특화(준비중)", "제작특화준비중", "제작특화(준비)", "제작특화준비" } },
	},
	TitleText = { 0.17, 0.08, 0.66, 0.6 }, -- text box inside UIP_TitleRibbon (fractions of the ribbon)
	TouchTarget = 44, -- real px of the invisible hit areas and the code-styled choose buttons (CR-L41)
	FixedTextMin = 15, -- CR-L40: min TextSize of non-scaled code-card text (>= 11 real px under a 0.75 UIScale)
	HoverScale = 1.03,
	PressScale = 0.95,
	BlurSize = 10, -- camera blur behind the picker (mockup background is blurred)
	DimArt = 0.45, -- root dim over the world when the card art is drawn (the town shows through like the mockup)
	ScrollBar = 6,
	OldAspect = 0.62, -- width / height of a code-styled card
	LockTint = Color3.fromRGB(110, 110, 110), -- baked button tint while the choose buttons are locked
	PerkRows = 4,
	-- perk panel inset { x of card width, y of card height }: Halo's panel has gold corner flourishes
	PerkInset = { Halo = { 0.06, 0.03 }, Horns = { 0.015, 0.015 }, Neutral = { 0.015, 0.015 } },
	-- glow layers behind a hovered / chosen card { extra width, extra height, transparency } around the card body
	Glow = { { 0.04, 0.03, 0.45 }, { 0.08, 0.05, 0.75 } },
	GlowBody = { Art = { 0.56, 0.88 }, Old = { 0.5, 1 } }, -- { centre Y, height }: the art's emblem pokes out on top
	Regions = { "Title", "Desc", "Motto", "Perks", "Button" },
}

-- per-faction text style on the card art ("ink" = brown on parchment, "light" = white with a dark outline,
-- "gold" = gold with a dark outline like the "어느 편에 설래요?" title)
local CARD_STYLE = {
	Halo = { Title = "ink", Motto = "light", Perks = "ink", Button = "light" },
	Horns = { Title = "light", Motto = "light", Perks = "light", Button = "light" },
	Neutral = { Title = "ink", Motto = "light", Perks = "ink", Button = "light" },
}

-- Neutral fallbacks (A6 / A9-1 teal), used only if Config lacks the entries
local NEUTRAL_FALLBACK = {
	Id = "Neutral", Name = "장인 길드", Short = "장인", Emblem = "장",
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
local root, premiseFrame, cardsRow = nil, nil, nil
local premiseLabels = {}
local heading = {} -- title: Frame (ribbon image or plain frame), Text, Art, Aspect
local note = {} -- bottom altar note: Frame, Icon, Text
-- [factionId] = { Id, Slot, Body, Scale, Glow, Color, Aspect, Art, Hover, Down, Button, Badge,
--   art: Layout, NameLabel, Desc, Lore, Motto, Perks, Shade, Label, BadgeText / code: Emblem, Name, Scroll }
local cards = {}
local built = false
local visible = false
local lockedUntil = 0
local chosenId = nil -- card kept lit while the server answers a choice
local premiseToken = 0
local cameraConn = nil
local scaleConn = nil
local blur = nil
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

-- first sentence of the lore for the card's one-line description strip ("왕관 조각이 후광이 된 자들.")
local function shortLore(id)
	local lore = factionLore(id)
	return string.match(lore, "^(.-%.)%s") or lore
end

-- emblem glyph of the code-styled card; symbols like "⚙" show as tofu on some devices (CR-L44: Util.GlyphSafe), so an
-- unsafe or empty emblem falls back to "장" (Neutral) or the first letter of the faction name
local function emblemText(id, def)
	local e = tostring(def.Emblem or "")
	local safe = e ~= "" and e ~= "⚙"
	if safe and type(Util.GlyphSafe) == "function" then
		local ok, res = pcall(Util.GlyphSafe, e)
		safe = ok and res == true
	end
	if safe then return e end
	if id == "Neutral" then return "장" end
	local name = tostring(def.Short or def.Name or "")
	return string.match(name, utf8.charpattern) or "?"
end

-- perk rows { Icon, Text, Short } of a card: Config.UIArt.FactionPerks, else the first Config.Factions perk lines
local function perkRows(id)
	local rows = {}
	local list = Art.Perks[id]
	if type(list) == "table" then
		for _, p in list do
			if type(p) == "table" and type(p.Text) == "string" and #rows < LAY.PerkRows then
				local short = (type(p.Short) == "string" and p.Short ~= "") and p.Short or nil
				table.insert(rows, { Icon = p.Icon, Text = p.Text, Short = short })
			end
		end
	end
	if #rows == 0 then
		local perks = factionDef(id).Perks
		if type(perks) == "table" then
			for _, p in perks do
				if #rows < LAY.PerkRows then table.insert(rows, { Text = tostring(p) }) end
			end
		end
	end
	return rows
end

local function weakerText()
	local j = Config.Justice
	local gold = type(j) == "table" and tonumber(j.SignOnGold) or 0
	return string.format(T.WeakerF, math.floor(gold or 0))
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

-- virtual canvas (w, h) inside the UIScale'd gui, the first safe Y below the top bar (H4) and the UIScale
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
	return vp.X / s, vp.Y / s, top, s
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

local function applyFont(label, font)
	local title = font == Enum.Font.GothamBlack or font == Art.Fonts.Title
	local fonts = E.Enabled and E.Config.Fonts
	local explicit = type(fonts) == "table" and fonts[title and "Title" or "Body"]
	if UIKit and type(UIKit.ApplyFont) == "function" then
		pcall(UIKit.ApplyFont, label, typeof(explicit) == "Font" and explicit
			or (title and Enum.FontWeight.Bold or Enum.FontWeight.Regular))
	elseif typeof(explicit) == "Font" then
		pcall(function() label.FontFace = explicit end)
	end
	return label
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
	applyFont(l, l.Font)
	l.TextSize = math.max(l.TextSize, LAY.FixedTextMin) -- CR-L40 (the TextLabel default is 14)
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

local function playClick()
	local fx = C and C.Fx
	if fx and type(fx.PlaySound) == "function" then pcall(fx.PlaySound, "Click") end
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
			playClick()
			handler()
		end)
		btn = b
	end
	btn.Name = "ChooseButton"
	applyFont(btn, theme.Font)
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

------------------------------------------------------------------ art helpers
local function artColor(key, fallback)
	local c = Art.Colors[key]
	return typeof(c) == "Color3" and c or fallback
end

local function artFont(key, fallback)
	local f = Art.Fonts[key]
	return typeof(f) == "EnumItem" and f or fallback
end

-- image px size of a part (Config.UIArt.Parts[name].Size), nil when unknown
local function partSize(name)
	local d = Art.Parts[name]
	local s = type(d) == "table" and d.Size or nil
	if typeof(s) == "Vector2" and s.X > 0 and s.Y > 0 then return s end
	return nil
end

-- "rbxassetid://..." of a part, or nil when it is not uploaded / art is off (the caller draws its fallback)
local function artId(name)
	if UIKit and type(UIKit.ArtId) == "function" then
		local ok, id = pcall(UIKit.ArtId, name)
		if ok then return (type(id) == "string" and id ~= "") and id or nil end
	end
	if not Art.Enabled then return nil end
	local d = Art.Parts[name]
	local id = type(d) == "table" and d.Id or nil
	if type(id) == "string" and string.match(id, "^rbxassetid://[1-9]%d*$") then return id end
	return nil
end

-- smallest TextSize (canvas units) that stays >= Config.UI.MinTextSize real px after the UIScale (M1, CR-L40)
local function minTextFor(s)
	return math.clamp(math.ceil(MIN_TEXT / math.min(s, 1)), MIN_TEXT, 100)
end

-- wrapped text bounds (height, width) at a TextSize inside `width` canvas units
local function textBounds(text, size, font, width)
	if UIKit and type(UIKit.MeasureText) == "function" then return UIKit.MeasureText(text, size, font, width) end
	local ok, v = pcall(function()
		if typeof(font) == "Font" then
			local params = Instance.new("GetTextBoundsParams")
			params.Text, params.Size, params.Font, params.Width = text, size, font, math.max(1, width)
			local bounds = TextService:GetTextBoundsAsync(params)
			params:Destroy()
			return bounds
		end
		if font == Enum.Font.Unknown then error("FontFace가 필요합니다.") end
		return TextService:GetTextSize(text, size, font, Vector2.new(math.max(1, width), 10000))
	end)
	if ok and typeof(v) == "Vector2" then return v.Y, v.X end
	-- rough estimate: Korean glyphs are about 1 em wide
	local chars = utf8.len(text) or #text
	local perLine = math.max(1, math.floor(width / size))
	return math.ceil(chars / perLine) * size * 1.25, math.min(width, chars * size)
end

local function renderedBounds(text, size, font, scale, width)
	if UIKit and type(UIKit.MeasureRenderedText) == "function" then
		return UIKit.MeasureRenderedText(text, size, font, scale, width)
	end
	return textBounds(text, math.max(MIN_TEXT, size * scale), font, width)
end

local function place(obj, x, y, w, h)
	if obj.Parent and obj.Parent:GetAttribute("PickerTextClip") == true then obj = obj.Parent end
	obj.Position = UDim2.fromOffset(x, y)
	obj.Size = UDim2.fromOffset(math.max(0, w), math.max(0, h))
end

-- CardLayout region { x, y, w, h } (fractions of the card image) -> offsets inside a W x H card
local function region(r, W, H)
	if type(r) ~= "table" then return 0, 0, W, H end
	return (r[1] or 0) * W, (r[2] or 0) * H, (r[3] or 1) * W, (r[4] or 1) * H
end

function E.warn(key, message)
	if E.Warnings[key] then return end
	E.Warnings[key] = true
	Util.Warn(TAG, "E " .. tostring(message))
end

function E.key(role)
	local key = E.Parts[role]
	return type(key) == "string" and key ~= "" and key or E.Keys[role]
end

function E.sameLines(actual, expected)
	if type(actual) ~= "table" or type(expected) ~= "table" or #actual ~= #expected then return false end
	for i, line in actual do
		if type(line) ~= "string" or line ~= expected[i] then return false end
	end
	return true
end

function E.semantic(role, id)
	if not E.BakedText then return true end
	-- This is an approved Korean image, not an English localization implementation.
	if E.Config.Locale ~= "ko" then return false end
	local expected = E.Semantics[role]
	if role == "Title" then return expected == T.Title end
	if role == "Footer" then return expected == T.Footer end
	if role == "Premise" then return E.sameLines(Config.Story.Premise, expected) end
	local definitions = E.Semantics.Cards
	expected = type(definitions) == "table" and definitions[id]
	if type(expected) ~= "table" then return false end
	local def, perks = factionDef(id), {}
	for _, row in perkRows(id) do table.insert(perks, row.Text) end
	return expected.Name == def.Name and expected.Desc == LAY.LoreShort[id]
		and expected.Motto == def.Pitch and expected.Button == T.Choose
		and E.sameLines(perks, expected.Perks)
end

function E.part(role)
	local key = E.key(role)
	return key, partSize(key), artId(key)
end

-- Never hide readable fallback content before the full image is actually ready.
function E.watchImage(image, state, role, id, apply)
	state.Image = image
	state.Failed, state.Ready, state.CanDisplay, state.Preloaded = false, false, true, false
	state.Semantic = E.semantic(role, id)
	if not state.Semantic then E.warn(role .. tostring(id), "문구 스냅샷 불일치: " .. role .. tostring(id or "")) end
	state.Update = function()
		if not image.Parent then return end
		if image.IsLoaded and (not state.Preloaded or state.Failed) then
			-- A first fetch can time out while the renderer later finishes the same asset.
			local ok, status = pcall(ContentProvider.GetAssetFetchStatus, ContentProvider, image.Image)
			if ok and status == Enum.AssetFetchStatus.Success then
				state.Preloaded, state.Failed = true, false
				state.FetchStatus = tostring(status)
			end
		end
		local ready = state.Semantic and state.Preloaded and not state.Failed and state.CanDisplay and image.IsLoaded
		state.Ready = ready
		-- Invisible ImageLabels can remain disk-cached without becoming IsLoaded. Let the renderer
		-- prepare a nearly transparent image while the complete readable fallback stays above/below it.
		image.Visible = state.Semantic and not state.Failed and state.CanDisplay and image.Image ~= ""
		image.ImageTransparency = ready and 0 or 0.999
		image:SetAttribute("FactionEReady", ready)
		image:SetAttribute("FactionESemantic", state.Semantic)
		image:SetAttribute("FactionEPreloaded", state.Preloaded)
		image:SetAttribute("FactionEFetchFailed", state.Failed)
		image:SetAttribute("FactionECanDisplay", state.CanDisplay)
		image:SetAttribute("FactionEFetchStatus", state.FetchStatus or "Pending")
		apply(ready)
	end
	image:GetPropertyChangedSignal("IsLoaded"):Connect(state.Update)
	state.Update()
	if image.Image == "" then return end
	task.spawn(function()
		local failed = false
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync({ image }, function(_, status)
				state.FetchStatus = tostring(status)
				if status ~= Enum.AssetFetchStatus.Success then failed = true end
			end)
		end)
		if not image.Parent then return end
		state.Failed = not ok or failed
		state.Preloaded = not state.Failed
		if not ok then state.FetchStatus = tostring(err) end
		if state.Failed then E.warn("load" .. role .. tostring(id), "이미지 로드 실패, 글자 대체 표시: " .. role .. tostring(id or "")) end
		state.Update()
	end)
end

function E.refreshImages()
	if not E.Enabled or not root or not root.Visible then return end
	-- Scrolling an offscreen image into view can finish rendering without an IsLoaded signal.
	-- The existing visibility poll reconciles all six images; no additional timer is needed.
	for _, state in E.Panels or {} do
		if state.Update then state.Update() end
	end
	for _, card in cards do
		if card.E and card.E.Update then card.E.Update() end
	end
end

local function tween(obj, t, props)
	if not obj or not obj.Parent then return end
	local ok, tw = pcall(function()
		return TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	end)
	if ok and tw then tw:Play() end
end

local function newImage(parent, name, z)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = ""
	img.ZIndex = z or 1
	img.Parent = parent
	return img
end

-- transparent, wrapped, TextScaled label with a UITextSizeConstraint (range set by setTextRange on layout)
local function artLabel(parent, name, z, font, clipped)
	if clipped then
		local clip = Instance.new("Frame")
		clip.Name = name .. "Clip"
		clip.BackgroundTransparency = 1
		clip.BorderSizePixel = 0
		clip.Size = UDim2.fromScale(1, 1)
		clip.ClipsDescendants = true
		clip.ZIndex = z or 1
		clip:SetAttribute("PickerTextClip", true)
		clip.Parent = parent
		parent = clip
	end
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = font or artFont("Body", Enum.Font.GothamBold)
	applyFont(l, l.Font)
	l.Text = ""
	l.TextScaled = true
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	l.TextXAlignment = Enum.TextXAlignment.Center
	l:SetAttribute("PickerFit", true)
	l:SetAttribute("PickerMeasureWhole", true)
	if clipped then l.Size = UDim2.fromScale(1, 1) end
	l.ZIndex = z or 1
	constrainText(l, 64)
	l.Parent = parent
	return l
end

-- min / max text size (canvas units); TextSize = max for labels that are not TextScaled
local function setTextRange(label, minT, maxT)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c.Parent = label
	end
	local lo = math.clamp(math.floor(label:GetAttribute("PickerFit") and MIN_TEXT or minT), 1, 100)
	local hi = math.clamp(math.floor(maxT), lo, 100)
	c.MaxTextSize = 100 -- widen first so Min never exceeds Max mid-update
	c.MinTextSize = lo
	c.MaxTextSize = hi
	label.TextSize = hi
	if label:GetAttribute("PickerFit") and UIKit and type(UIKit.FitText) == "function" then
		UIKit.FitText(label, lo, hi)
	end
end

-- storybook text look (same colours as UIKit.InkText / LightText): "ink", "light" or "gold" + a UIStroke "Outline"
local function styleText(label, style, thickness)
	local ink = style == "ink"
	if ink then
		label.TextColor3 = artColor("Ink", Color3.fromRGB(66, 40, 18))
	elseif style == "gold" then
		label.TextColor3 = artColor("GoldText", Color3.fromRGB(255, 228, 100))
	else
		label.TextColor3 = artColor("Light", Color3.new(1, 1, 1))
	end
	local st = label:FindFirstChild("Outline")
	if not (st and st:IsA("UIStroke")) then
		st = Instance.new("UIStroke")
		st.Name = "Outline"
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		st.Parent = label
	end
	st.Color = ink and artColor("InkOutline", Color3.fromRGB(255, 247, 228)) or artColor("TextOutline", Color3.fromRGB(34, 20, 10))
	st.Thickness = ink and 0 or math.min(thickness or 0.5, 0.6)
	st.Transparency = st.Thickness == 0 and 1 or 0.45
	label:SetAttribute("PickerOutlineThickness", st.Thickness)
end

-- Keep the native Nanum letters filled and the selected art visible; large text uses only a thin outline.
local function boldOutline(label, size)
	if label:GetAttribute("PickerOutlineThickness") == 0 then return end
	local st = label:FindFirstChild("Outline")
	if st and st:IsA("UIStroke") then st.Thickness = math.clamp(size * 0.02, 0.3, 0.6) end
	label:SetAttribute("PickerOutlineThickness", 0.6)
	label:SetAttribute("PickerOutlineRatio", 0.02)
end

-- 9-slice art panel (UIKit.ArtImage fits the slice edges) or a code-drawn parchment panel when the part is missing
local function sliceFrame(parent, name, part, z)
	local f = nil
	if UIKit and type(UIKit.ArtImage) == "function" then
		local ok, img = pcall(UIKit.ArtImage, part, { Name = name, ZIndex = z or 1 })
		if ok and typeof(img) == "Instance" then f = img end
	end
	if not f then
		f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = artColor("Parchment", Color3.fromRGB(242, 221, 178))
		f.BorderSizePixel = 0
		f.ZIndex = z or 1
		corner(f, 10)
		local st = Instance.new("UIStroke")
		st.Name = "Stroke"
		st.Color = artColor("Rim", Color3.fromRGB(110, 66, 24))
		st.Thickness = 2
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = f
	end
	f.Parent = parent
	return f
end

------------------------------------------------------------------ buttons / badges / highlight
-- scale + glow of one card: pressed < normal < hovered / chosen (mockup: the lit 빛 card); grey baked button while locked
local function cardVisual(c)
	local disabled = os.clock() < lockedUntil
	local lit = c.Hover or c.Id == chosenId
	local target = 1
	if c.Down and not disabled then
		target = LAY.PressScale
	elseif lit then
		target = LAY.HoverScale
	end
	tween(c.Scale, 0.08, { Scale = target })
	for _, g in c.Glow do
		tween(g.Frame, 0.15, { BackgroundTransparency = lit and g.Transparency or 1 })
	end
	c.Slot.ZIndex = lit and 2 or 1 -- a grown card draws over its neighbours
	if c.Shade then c.Shade.ImageTransparency = disabled and 0 or 1 end
end

local function refreshButtons()
	local enabled = os.clock() >= lockedUntil
	for _, c in cards do
		local btn = c.Button
		btn:SetAttribute("Disabled", not enabled)
		if c.E then
			c.E.FallbackButton:SetAttribute("Disabled", not enabled)
			c.E.FallbackButton.Text = enabled and T.Choose or T.Wait
			c.E.FallbackButton.BackgroundColor3 = enabled and c.Color or c.Color:Lerp(DISABLED, 0.7)
			c.E.FallbackButton.TextTransparency = enabled and 0 or 0.4
			c.E.FallbackButton.AutoButtonColor = false
			if not enabled then c.Down = false end
		elseif c.Art then
			c.Label.Text = enabled and T.Choose or T.Wait
			c.Label.TextTransparency = enabled and 0 or 0.35
			if not enabled then c.Down = false end
		else
			btn.Text = enabled and T.Choose or T.Wait
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = enabled and c.Color or c.Color:Lerp(DISABLED, 0.7)
			btn.TextTransparency = enabled and 0 or 0.4
		end
		cardVisual(c)
	end
end

local function updateBadges()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local weaker = gs and gs:GetAttribute("WeakerFaction")
	for id, c in cards do
		-- the +300 sign-on bonus exists only between Halo and Horns (A6)
		c.Badge.Visible = (id == "Halo" or id == "Horns") and weaker == id
		if c.E then c.E.FallbackBadge.Visible = false end
	end
end

local function choose(id)
	if os.clock() < lockedUntil then return end
	if not FactionPicker.IsOpen() then return end
	lockedUntil = os.clock() + CLICK_LOCK
	chosenId = id
	refreshButtons()
	fire("ChooseFaction", id)
	task.delay(CLICK_LOCK + 0.05, function()
		if not built then return end
		if chosenId == id then chosenId = nil end
		refreshButtons()
	end)
end

------------------------------------------------------------------ build: art cards
-- hover (mouse) / gamepad selection lights the whole card; touch has no hover
local function wireHover(c)
	c.Slot.MouseEnter:Connect(function()
		if not UserInputService.MouseEnabled then return end
		c.Hover = true
		cardVisual(c)
	end)
	c.Slot.MouseLeave:Connect(function()
		c.Hover = false
		c.Down = false
		cardVisual(c)
	end)
	c.Button.SelectionGained:Connect(function()
		c.Hover = true
		cardVisual(c)
	end)
	c.Button.SelectionLost:Connect(function()
		c.Hover = false
		cardVisual(c)
	end)
end

-- invisible hit button over the baked art button: press-shrink on the card, Click sound, choose(id)
local function wirePress(c, id)
	local hit = c.Button
	local function isPress(input)
		local t = input.UserInputType
		return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
	end
	hit.InputBegan:Connect(function(input)
		if isPress(input) and hit:GetAttribute("Disabled") ~= true then
			c.Down = true
			cardVisual(c)
		end
	end)
	hit.InputEnded:Connect(function(input)
		if not isPress(input) then return end
		c.Down = false
		if input.UserInputType == Enum.UserInputType.Touch then c.Hover = false end
		cardVisual(c)
	end)
	hit.MouseLeave:Connect(function()
		if not c.Down then return end
		c.Down = false
		cardVisual(c)
	end)
	hit.Activated:Connect(function()
		if hit:GetAttribute("Disabled") == true or os.clock() < lockedUntil then return end
		playClick()
		local ok, err = pcall(choose, id)
		if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
	end)
end

-- soft faction-coloured glow layers behind the card (hidden until hovered / chosen)
local function buildGlow(c)
	local body = c.Art and LAY.GlowBody.Art or LAY.GlowBody.Old
	local color = c.Color:Lerp(Color3.new(1, 1, 1), 0.3)
	for i, g in LAY.Glow do
		local f = Instance.new("Frame")
		f.Name = "Glow" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, body[1])
		f.Size = UDim2.fromScale(1 + g[1], body[2] + g[2])
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = 1
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.08, 0)
		cr.Parent = f
		f.Parent = c.Body
		table.insert(c.Glow, { Frame = f, Transparency = g[3] })
	end
end

-- card art key, CardLayout entry, image px size and id, or nil when anything is missing (IMG-R4)
local function cardArt(id)
	local key = "Card" .. id
	local lay = Art.Layout[key]
	if type(lay) ~= "table" then return nil end
	for _, name in LAY.Regions do
		local r = lay[name]
		if type(r) ~= "table" then return nil end
		for j = 1, 4 do
			if type(r[j]) ~= "number" then return nil end
		end
	end
	local img = partSize(key)
	local imageId = artId(key)
	if not img or not imageId then return nil end
	return key, lay, img, imageId
end

local function buildArtCard(c, id, lay, img, imageId)
	local def = factionDef(id)
	local style = CARD_STYLE[id] or CARD_STYLE.Halo
	local body = c.Body
	local titleFont = artFont("Title", Enum.Font.GothamBlack)

	-- card background (the box keeps the image aspect, so Stretch is exact)
	local bg = newImage(body, "Art", 2)
	bg.ScaleType = Enum.ScaleType.Stretch
	bg.Size = UDim2.fromScale(1, 1)
	bg.Image = imageId

	-- name ribbon, one-line lore strip, motto ribbon
	local name = artLabel(body, "FactionName", 3, titleFont)
	name.Text = tostring(def.Name or id)
	name.TextWrapped = false
	styleText(name, style.Title, 0)
	local desc = artLabel(body, "Desc", 3, nil, true)
	desc.Text = shortLore(id)
	desc.TextScaled = false -- sized by layoutDesc: one small line, two only when one cannot fit
	desc.TextWrapped = false
	styleText(desc, "ink")
	local motto = artLabel(body, "Motto", 3, nil, true)
	motto.Text = tostring(def.Pitch or "")
	motto.TextWrapped = false
	styleText(motto, style.Motto, 1.5)

	-- perk panel: icon + one line per perk
	local perks = {}
	for i, p in perkRows(id) do
		local row = Instance.new("Frame")
		row.Name = "Perk" .. i
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.ClipsDescendants = true
		row.ZIndex = 3
		row.Parent = body
		local icon = newImage(row, "Icon", 1)
		icon.Image = (type(p.Icon) == "string" and artId(p.Icon)) or ""
		local dot = artLabel(row, "Dot", 1)
		dot.Text = "•"
		dot.Visible = icon.Image == ""
		styleText(dot, style.Perks)
		local text = artLabel(row, "Text", 2, nil, true)
		text.Text = p.Text
		text.TextWrapped = false
		text.TextXAlignment = Enum.TextXAlignment.Center
		styleText(text, style.Perks)
		perks[i] = { Frame = row, Icon = icon, Dot = dot, Text = text, Full = p.Text, Short = p.Short }
		text:GetPropertyChangedSignal("TextBounds"):Connect(function()
			local metrics = perks[i].Layout
			if not metrics then return end
			local inkW = math.min(metrics.TextW, text.TextBounds.X / metrics.Scale)
			local ix = math.max(0, (metrics.TextW - inkW) / 2)
			icon.Position = UDim2.fromOffset(ix, metrics.IconY)
			dot.Position = UDim2.fromOffset(ix, metrics.IconY)
		end)
	end

	-- the baked button cropped from the card art, greyed while locked; its label and the invisible hit area
	local r = lay.Button
	local shade = newImage(body, "ButtonShade", 4)
	shade.ScaleType = Enum.ScaleType.Stretch
	shade.Image = imageId
	shade.ImageRectOffset = Vector2.new(r[1] * img.X, r[2] * img.Y)
	shade.ImageRectSize = Vector2.new(r[3] * img.X, r[4] * img.Y)
	shade.ImageColor3 = LAY.LockTint
	shade.ImageTransparency = 1
	local label = artLabel(body, "ChooseLabel", 5, titleFont)
	label.Text = T.Choose
	label.TextWrapped = false
	styleText(label, style.Button, 2)
	local hit = Instance.new("ImageButton")
	hit.Name = "ChooseButton"
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.AutoButtonColor = false
	hit.Image = ""
	hit.ZIndex = 6
	hit.Parent = body

	-- weaker-faction sign-on badge: a parchment pill over the top ornament
	local badge = sliceFrame(body, "WeakerBadge", "Pill", 7)
	badge.Visible = false
	local badgeText = artLabel(badge, "Text", 1)
	badgeText.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeText.Position = UDim2.fromScale(0.5, 0.5)
	badgeText.Size = UDim2.fromScale(0.86, 0.8)
	badgeText.Text = weakerText()
	styleText(badgeText, "ink")

	c.Layout, c.NameLabel, c.Desc, c.Lore, c.Motto, c.Perks = lay, name, desc, desc.Text, motto, perks
	c.FullMotto = motto.Text
	c.Shade, c.Label, c.Button, c.Badge, c.BadgeText = shade, label, hit, badge, badgeText
	c.Aspect = img.X / img.Y
	wirePress(c, id)
	c.Art = true
end

------------------------------------------------------------------ build: code-styled cards (IMG-R4 fallback)
local function buildOldCard(c, id)
	local def = factionDef(id)
	local color = c.Color

	local card = Instance.new("Frame")
	card.Name = "Panel"
	card.BackgroundColor3 = CARD_BG
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 1)
	card.ZIndex = 2
	corner(card, 14)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = color
	st.Thickness = 3
	st.Parent = card

	local emblem = newLabel(card, {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = emblemText(id, def),
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

	local badge = listText(scroll, weakerText(), 15, DARK_TEXT, 1, theme.Font)
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
		local noteText = (type(def.Note) == "string" and def.Note ~= "") and def.Note or NEUTRAL_NOTE
		listText(scroll, noteText, 15, theme.Gold, order2, theme.Font)
		order2 += 1
	end

	local btn = makeButton(card, T.Choose, color, contrastText(color), function()
		choose(id)
	end)
	btn.AnchorPoint = Vector2.new(0.5, 1)

	card.Parent = c.Body
	c.Button, c.Badge, c.Emblem, c.Name, c.Scroll = btn, badge, emblem, name, scroll
	c.Aspect = LAY.OldAspect
end

function E.aspect()
	local configured = E.Config.CardAspect
	if type(configured) == "number" and configured > 0.1 and configured < 2 then return configured end
	local size = partSize(E.key("Halo"))
	return size and size.X / size.Y or 360 / 640
end

function E.buttonRect(id)
	local cardLayout = Art.Layout[E.key(id)]
	local supplied = E.Config.ButtonRects
	local r = type(supplied) == "table" and supplied[id]
	if type(r) ~= "table" then r = type(cardLayout) == "table" and cardLayout.Button end
	if type(r) == "table" and #r == 4 then
		local valid = true
		for _, value in r do
			if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then valid = false end
		end
		if valid and r[3] > 0 and r[4] > 0 and r[1] + r[3] <= 1 and r[2] + r[4] <= 1 then return r end
	end
	E.warn("button" .. id, "선택 버튼 영역 없음: " .. id)
	return { 0.12, 0.82, 0.76, 0.12 }
end

function E.buildCard(c, id)
	-- The complete old code card remains readable while the E asset is missing or rejected.
	buildOldCard(c, id)
	local fallbackPanel = c.Body:FindFirstChild("Panel")
	local oldButton, oldBadge = c.Button, c.Badge
	local key, size, imageId = E.part(id)
	local bg = newImage(c.Body, "FactionEArt", 3)
	bg.Size = UDim2.fromScale(1, 1)
	bg.ScaleType = Enum.ScaleType.Fit
	bg.Image = imageId or ""
	bg.Visible = false
	local hit = Instance.new("ImageButton")
	hit.Name = "ChooseButtonE"
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.AutoButtonColor = false
	hit.Image = ""
	hit.Visible = false
	hit.ZIndex = 6
	hit.Parent = c.Body
	local rect = E.buttonRect(id)
	local shade = newImage(c.Body, "ButtonShadeE", 4)
	shade.ScaleType = Enum.ScaleType.Stretch
	shade.Image = imageId or ""
	shade.ImageColor3 = LAY.LockTint
	shade.ImageTransparency = 1
	shade.Visible = false
	if size then
		shade.ImageRectOffset = Vector2.new(rect[1] * size.X, rect[2] * size.Y)
		shade.ImageRectSize = Vector2.new(rect[3] * size.X, rect[4] * size.Y)
	end
	local badge = sliceFrame(c.Body, "WeakerBadgeE", "Pill", 7)
	badge.Visible = false
	local badgeText = artLabel(badge, "Text", 1)
	badgeText.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeText.Position = UDim2.fromScale(0.5, 0.5)
	badgeText.Size = UDim2.fromScale(0.86, 0.8)
	badgeText.Text = weakerText()
	styleText(badgeText, "ink")
	c.E = { Key = key, FallbackPanel = fallbackPanel, FallbackButton = oldButton,
		FallbackBadge = oldBadge, ButtonRect = rect, Background = bg }
	local hitTops = E.Config.ButtonHitTop
	c.E.ButtonHitTop = type(hitTops) == "table" and math.clamp(tonumber(hitTops[id]) or 0, 0, 1) or 0
	c.Button, c.Shade, c.Badge, c.BadgeText = hit, shade, badge, badgeText
	c.Aspect = E.aspect()
	wirePress(c, id)
	oldButton.SelectionGained:Connect(function() c.Hover = true; cardVisual(c) end)
	oldButton.SelectionLost:Connect(function() c.Hover = false; cardVisual(c) end)
	E.watchImage(bg, c.E, "Card", id, function(ready)
		fallbackPanel.Visible = not ready
		oldBadge.Visible = false
		hit.Visible = ready
		shade.Visible = ready
		c.Body:SetAttribute("FactionERenderMode", ready and "BakedKorean" or "LiveFallback")
	end)
	if size and math.abs(size.X / size.Y - c.Aspect) > 0.002 then
		c.E.Semantic = false
		E.warn("aspect" .. id, "공통 카드 비율 불일치: " .. id)
		c.E.Update()
	end
end

-- one card slot in the row: Body (scaled on hover / press) holding the art card or the code-styled card + glow
local function buildCard(id, order)
	local slot = Instance.new("Frame")
	slot.Name = "Card_" .. id
	slot.BackgroundTransparency = 1
	slot.BorderSizePixel = 0
	slot.LayoutOrder = order
	slot.Parent = cardsRow
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ClipsDescendants = true
	body.Parent = slot
	local scale = Instance.new("UIScale")
	scale.Name = "CardScale"
	scale.Parent = body

	local c = {
		Id = id, Slot = slot, Body = body, Scale = scale, Glow = {}, Color = factionColor(id),
		Aspect = LAY.OldAspect, Art = false, Hover = false, Down = false,
	}
	local key, lay, img, imageId = cardArt(id)
	if E.Enabled then
		local ok, err = pcall(E.buildCard, c, id)
		if not ok then
			E.warn("build" .. id, "카드 생성 실패, 대체 표시: " .. id .. " " .. tostring(err))
			for _, child in body:GetChildren() do
				if child ~= scale then child:Destroy() end
			end
			c.E, c.Art, c.Shade = nil, false, nil
		end
	elseif key then
		local ok, err = pcall(buildArtCard, c, id, lay, img, imageId)
		if not ok then
			Util.Warn(TAG, "art card " .. key .. " failed, drawing the code card: " .. tostring(err))
			for _, child in body:GetChildren() do
				if child ~= scale then child:Destroy() end
			end
			c.Art, c.Shade, c.Layout, c.Perks = false, nil, nil, nil
		end
	end
	if not c.Art and not c.E then buildOldCard(c, id) end
	buildGlow(c)
	wireHover(c)
	cards[id] = c
end

------------------------------------------------------------------ layout
local function layoutOldCard(c, compact, s)
	local hh = compact and 62 or 96 -- header (emblem + name)
	-- choose button, at least TouchTarget real px tall after the UIScale (CR-L41)
	local bh = math.max(compact and 44 or 54, math.ceil(LAY.TouchTarget / math.max(s or 1, 0.05)))
	c.Emblem.Position = UDim2.new(0.5, 0, 0, 6)
	c.Emblem.Size = UDim2.new(1, -16, 0, math.floor(hh * 0.55))
	c.Name.Position = UDim2.new(0.5, 0, 0, 6 + math.floor(hh * 0.55))
	c.Name.Size = UDim2.new(1, -16, 0, math.floor(hh * 0.38))
	c.Scroll.Position = UDim2.new(0, 10, 0, hh + 10)
	c.Scroll.Size = UDim2.new(1, -20, 1, -(hh + 10 + bh + 20))
	local button = c.E and c.E.FallbackButton or c.Button
	button.Position = UDim2.new(0.5, 0, 1, -10)
	button.Size = UDim2.new(1, -24, 0, bh)
end

function E.layoutCard(c, W, H, minT, s)
	layoutOldCard(c, H < 420, s)
	if not c.E then return end
	local x, y, w, h = region(c.E.ButtonRect, W, H)
	place(c.Shade, x, y, w, h)
	-- Offsets are raster-rounded after UIScale, and the pressed card scales down by 0.95.
	local minHit = math.ceil((LAY.TouchTarget + 1) / (s * LAY.PressScale))
	local hitH = math.min(H, math.max(h, minHit))
	local hitW = math.min(W, math.max(w, minHit))
	local hitY = math.max(y + h / 2 - hitH / 2, H * (c.E.ButtonHitTop or 0))
	place(c.Button, math.clamp(x + w / 2 - hitW / 2, 0, math.max(0, W - hitW)),
		math.clamp(hitY, 0, math.max(0, H - hitH)), hitW, hitH)
	local badgeH = math.max(minT * 2.7, H * 0.085)
	place(c.Badge, W * 0.03, H * 0.008, W * 0.94, badgeH)
	setTextRange(c.BadgeText, minT, math.max(minT, badgeH * 0.34))
	c.Body:SetAttribute("FactionECardHeight", H * s)
	c.Body:SetAttribute("FactionEButtonCenterY", (y + h / 2) * s)
	c.E.DisplayHeight = H * s
end

-- A full sentence can shrink until the real 11px floor. If it still cannot fit, try every approved compact
-- equivalent too; returning an unchecked Short was the cause of clipped labels in the default 991px view.
local function cardText(label, full, short, tiny, width, height, scale)
	local candidates = { full }
	if type(short) == "string" and short ~= "" then table.insert(candidates, short) end
	if type(tiny) == "table" then
		for _, text in tiny do table.insert(candidates, text) end
	elseif type(tiny) == "string" and tiny ~= "" then
		table.insert(candidates, tiny)
	end
	for _, text in candidates do
		local th, tw, exact
		if UIKit and type(UIKit.MeasureRenderedText) == "function" then
			th, tw, exact = UIKit.MeasureRenderedText(text, MIN_TEXT, label.FontFace, scale, 10000)
		else
			th, tw = textBounds(text, math.max(MIN_TEXT, MIN_TEXT * scale), label.FontFace, 10000)
		end
		-- Font-loading failure uses the shortest wording immediately; conservative estimates do not grant a fit.
		if not exact then return candidates[#candidates] end
		if tw <= width - 0.5 and th <= height - 0.25 then return text end
	end
	return candidates[#candidates]
end

-- Perk rows remain centred groups of an icon and a complete one-line label.
local function layoutPerks(c, W, H, minT, scale)
	local px, py, pw, ph = region(c.Layout.Perks, W, H)
	local inset = LAY.PerkInset[c.Id] or LAY.PerkInset.Horns
	px, pw = px + W * inset[1], pw - W * inset[1] * 2
	local count = math.max(LAY.PerkRows, #c.Perks)
	-- Reduce only the empty inset, staying inside the original bitmap perk panel. Keep a real 11px line
	-- plus rounding/stroke room; a 9.6px clipping frame cannot display even the shortest text.
	local insetY = math.min(H * inset[2], math.max(0, (ph - count * (MIN_TEXT + 0.75) / scale) / 2))
	py, ph = py + insetY, ph - insetY * 2
	local rowH = ph / count
	local icon = math.min(rowH * 0.82, pw * 0.16)
	local gap = rowH * 0.25
	local textW = math.max(10, pw - icon - gap)
	local size = math.max(MIN_TEXT, math.floor(rowH * 0.68))
	for i, row in c.Perks do
		local compact = LAY.PerkTiny[c.Id]
		row.Text.Text = cardText(row.Text, row.Full, row.Short, compact and compact[i], textW * scale, rowH * scale, scale)
		row.Text.TextWrapped = false
		row.Text.TextXAlignment = Enum.TextXAlignment.Center
	end
	for i, row in c.Perks do
		place(row.Frame, px, py + (i - 1) * rowH, pw, rowH)
		place(row.Icon, 0, (rowH - icon) / 2, icon, icon)
		place(row.Dot, 0, (rowH - icon) / 2, icon, icon)
		setTextRange(row.Dot, minT, icon)
		place(row.Text, icon + gap, 0, textW, rowH)
		row.Layout = { TextW = textW, Scale = scale, IconY = (rowH - icon) / 2 }
		local inkW = math.min(textW, row.Text.TextBounds.X / scale)
		local ix = math.max(0, (textW - inkW) / 2)
		row.Icon.Position = UDim2.fromOffset(ix, row.Layout.IconY)
		row.Dot.Position = UDim2.fromOffset(ix, row.Layout.IconY)
		setTextRange(row.Text, MIN_TEXT, size)
	end
end

-- The original lore stays in Config/Story. An approved short summary fits the card's original narrow strip.
local function layoutDesc(c, W, H, minT, scale)
	local dx, dy, dw, dh = region(c.Layout.Desc, W, H)
	local size = math.max(MIN_TEXT, math.floor(dh * 0.8))
	c.Desc.Text = cardText(c.Desc, LAY.LoreShort[c.Id] or c.Lore, nil, LAY.LoreTiny[c.Id], dw * scale, dh * scale, scale)
	c.Desc.TextWrapped = false
	place(c.Desc, dx, dy, dw, dh)
	setTextRange(c.Desc, MIN_TEXT, size)
end

-- one art card: everything sits in the measured CardLayout regions of the card image
local function layoutArtCard(c, W, H, minT, s)
	local lay = c.Layout
	local tx, ty, tw, th = region(lay.Title, W, H)
	place(c.NameLabel, tx + tw * 0.06, ty + th * 0.1, tw * 0.88, th * 0.8)
	setTextRange(c.NameLabel, minT, th * 0.66)
	boldOutline(c.NameLabel, th * 0.66)

	layoutDesc(c, W, H, minT, s)

	-- motto: one line; the box may spill onto the ribbon tails
	local mx, my, mw, mh = region(lay.Motto, W, H)
	local motW = math.min(W * 0.9, mw * 1.3)
	local mottoSize = math.max(MIN_TEXT, math.floor(mh * 0.72))
	c.Motto.Text = cardText(c.Motto, c.FullMotto, LAY.MottoShort[c.Id], LAY.MottoTiny[c.Id], motW * s, mh * 0.96 * s, s)
	c.Motto.TextWrapped = false
	place(c.Motto, mx + mw / 2 - motW / 2, my + mh * 0.02, motW, mh * 0.96)
	setTextRange(c.Motto, minT, mottoSize)

	layoutPerks(c, W, H, minT, s)

	-- button: lock shade, label, and a hit area at least TouchTarget real px tall, kept inside the card
	local kx, ky, kw, kh = region(lay.Button, W, H)
	place(c.Shade, kx, ky, kw, kh)
	place(c.Label, kx + kw * 0.1, ky + kh * 0.12, kw * 0.8, kh * 0.7)
	setTextRange(c.Label, minT, kh * 0.55)
	boldOutline(c.Label, kh * 0.55)
	local hitH = math.min(math.max(kh * 1.2, LAY.TouchTarget / s), H * 0.2)
	local hitW = math.min(W, kw * 1.08)
	local hitY = math.min(ky + kh / 2 - hitH / 2, H - hitH)
	place(c.Button, kx + kw / 2 - hitW / 2, hitY, hitW, hitH)

	-- weaker badge over the top ornament (two lines)
	local bh = math.max(minT * 2.7, H * 0.085)
	place(c.Badge, W * 0.03, H * 0.008, W * 0.94, bh)
	setTextRange(c.BadgeText, minT, math.max(minT, bh * 0.34))
end

-- The selected A composition has a wide, compact three-line premise, centred above the cards.
local function placePremise(cx, y, maxW, size, scale, compact)
	if #premiseLabels == 0 then
		premiseFrame.Visible = false
		return 0
	end
	premiseFrame.Visible = true
	local padX = math.ceil(size * 1.1)
	local padY = compact and math.ceil(3 / scale) or math.ceil(size * 0.55)
	local innerW = math.max(40, maxW - padX * 2)
	local widest = 0
	for _, l in premiseLabels do
		local _, lw
		if compact then _, lw = renderedBounds(l.Text, size, l.FontFace, scale, 10000)
		else _, lw = textBounds(l.Text, size, l.FontFace, 10000) end
		widest = math.max(widest, lw)
	end
	if widest > innerW * scale - 2 then
		size = math.max(MIN_TEXT, math.floor(size * math.max(1, innerW * scale - 2) / widest))
	end
	local yy = padY
	for _, l in premiseLabels do
		local lh
		if compact then lh = renderedBounds(l.Text, size, l.FontFace, scale, 10000)
		else lh = textBounds(l.Text, size, l.FontFace, 10000) end
		lh = math.ceil((lh + (compact and 4 or 3)) / scale)
		l.TextWrapped = false
		place(l, padX, yy, innerW, lh)
		setTextRange(l, size, size)
		yy += lh
	end
	local width = innerW + padX * 2
	local height = yy + padY
	place(premiseFrame, cx - width / 2, y, width, height)
	return height
end

-- title ribbon centred at cx from y, at most maxW wide and height tall (ribbon keeps its aspect); returns its height
local function placeTitle(cx, y, maxW, height, minT)
	local hh, ww = height, maxW
	if heading.Art then
		hh = math.floor(math.min(height, maxW / heading.Aspect))
		ww = math.floor(hh * heading.Aspect)
	end
	place(heading.Frame, cx - ww / 2, y, ww, hh)
	setTextRange(heading.Text, minT, hh * (heading.Art and 0.46 or 0.8))
	return hh
end

-- altar note centred at cx with its bottom at `bottom`, at most maxW wide; returns its height
local function placeFooter(cx, bottom, maxW, size, scale, compact)
	local iconW = note.Icon.Visible and math.floor(size * 1.7) or 0
	local gapW = iconW > 0 and 6 or 0
	local padX = math.floor(size * 0.8)
	local maxTextW = math.max(40, maxW - iconW - gapW - padX * 2)
	local th, tw = textBounds(T.Footer, size, note.Text.FontFace, maxTextW * scale)
	-- Preserve the selected footer's width; only remove the unused height on short viewports.
	if compact then th = renderedBounds(T.Footer, size, note.Text.FontFace, scale, maxTextW * scale) end
	th, tw = th / scale, tw / scale
	local textW = math.min(maxTextW, tw + size) -- one glyph of slack so the measured line never re-wraps
	local noteH = math.ceil(math.max(th, iconW) + (compact and 4 / scale or size * 0.9))
	local noteW = padX * 2 + iconW + gapW + textW
	place(note.Frame, cx - noteW / 2, bottom - noteH, noteW, noteH)
	place(note.Icon, padX, (noteH - iconW) / 2, iconW, iconW)
	place(note.Text, padX + iconW + gapW, 0, textW, noteH)
	setTextRange(note.Text, size, size)
	return noteH
end

-- Match the three original bitmap widths and their baked button centres without stretching any card.
local function prepareCardBalance()
	if E.Enabled then
		LAY.CardAspect, LAY.BalancedHeight = E.aspect(), 1
		for _, c in cards do c.HeightFactor, c.YFactor = 1, 0 end
		return
	end
	local aspect, baseline = math.huge, 0
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c then aspect = math.min(aspect, c.Aspect) end
	end
	if aspect == math.huge then aspect = LAY.OldAspect end
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c then
			c.HeightFactor = aspect / c.Aspect
			c.ButtonY = c.Art and (c.Layout.Button[2] + c.Layout.Button[4] / 2) or 0.9
			baseline = math.max(baseline, c.HeightFactor * c.ButtonY)
		end
	end
	LAY.CardAspect, LAY.BalancedHeight = aspect, 1
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c then
			c.YFactor = baseline - c.HeightFactor * c.ButtonY
			LAY.BalancedHeight = math.max(LAY.BalancedHeight, c.YFactor + c.HeightFactor)
		end
	end
end

local function fittedCardHeight(areaW, areaH, sumAspect, gaps, balancedHeight, s)
	return math.min(math.max(1, areaH - 4) / (balancedHeight + 2 * LAY.Lift),
		LAY.CardMaxH / s, math.max(1, areaW - gaps - 4) / (sumAspect + 2 * LAY.Lift))
end

-- Desktop cards fit their slot; E switches to the whole-page flow before they become unreadable.
local function placeCards(x, y, areaW, areaH, needH, minT, s)
	prepareCardBalance()
	local n, sumA = 0, 0
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c then
			n += 1
			sumA += LAY.CardAspect
		end
	end
	if n == 0 then return end
	local gaps = LAY.Gap * (n - 1)
	local phone = (UserInputService.TouchEnabled and areaW * s < 700) or (E.Enabled and needH > 0)
	local cardH = fittedCardHeight(areaW, areaH, sumA, gaps, LAY.BalancedHeight, s)
	if phone then cardH = math.max(needH, cardH) end
	cardH = math.max(1, math.floor(cardH))
	local lift = math.ceil(cardH * LAY.Lift)
	local canvasW = gaps + 2 * lift
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c then canvasW += math.floor(cardH * LAY.CardAspect) end
	end
	local canvasH = math.ceil(cardH * LAY.BalancedHeight) + 2 * lift
	local frameH, frameW = math.min(areaH, canvasH), math.min(areaW, canvasW)
	local scrollX, scrollY = phone and canvasW > frameW, phone and canvasH > frameH
	local scroll = scrollX or scrollY
	place(cardsRow, x + (areaW - frameW) / 2, y + math.max(0, (areaH - frameH) / 2), frameW, frameH)
	cardsRow.CanvasSize = UDim2.fromOffset(canvasW, canvasH)
	cardsRow.ScrollingDirection = scrollY and Enum.ScrollingDirection.XY or Enum.ScrollingDirection.X
	cardsRow.ScrollingEnabled = scroll
	cardsRow.ScrollBarThickness = scroll and LAY.ScrollBar or 0
	if not scroll then cardsRow.CanvasPosition = Vector2.zero
	else
		cardsRow.CanvasPosition = Vector2.new(math.clamp(cardsRow.CanvasPosition.X, 0, math.max(0, canvasW - frameW)),
			math.clamp(cardsRow.CanvasPosition.Y, 0, math.max(0, canvasH - frameH)))
	end
	local cx = lift
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c then
			local cw = math.floor(cardH * LAY.CardAspect)
			local ch = E.Enabled and cw / LAY.CardAspect or cw / c.Aspect
			place(c.Slot, cx, lift + (cw / LAY.CardAspect) * c.YFactor, cw, ch)
			if E.Enabled then
				E.layoutCard(c, cw, ch, minT, s)
			elseif c.Art then
				layoutArtCard(c, cw, ch, minT, s)
			else
				layoutOldCard(c, ch < 420, s)
			end
			cx += cw + LAY.Gap
		end
	end
end

function E.buildPanels()
	E.Panels = {}
	for role, fallback in { Title = heading.Frame, Premise = premiseFrame, Footer = note.Frame } do
		local key, size, imageId = E.part(role)
		local image = newImage(root, "FactionE" .. role, 3)
		image.Image = imageId or ""
		image.ScaleType = Enum.ScaleType.Fit
		image.Visible = false
		local state = { Key = key, Size = size, Fallback = fallback }
		E.Panels[role] = state
		E.watchImage(image, state, role, nil, function(ready) fallback.Visible = not ready end)
	end
	-- One outer vertical canvas owns the entire small-screen choice, including its buttons.
	-- The card row may scroll sideways, but never gets a short independent vertical window.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "FactionEContent"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollingEnabled = false
	scroll.ScrollBarThickness = 0
	scroll.ScrollBarImageColor3 = artColor("Gold", theme.Gold)
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Active = true
	scroll.ZIndex = 2
	scroll.Parent = root
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = scroll
	for _, state in E.Panels do
		state.Image.Parent = content
		state.Fallback.Parent = content
	end
	cardsRow.Parent = content
	E.Scroll, E.Content = scroll, content
end

function E.rect(role)
	local rect = E.Layout[role]
	if type(rect) == "table" and #rect == 4 then
		local valid = true
		for _, value in rect do
			if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then valid = false end
		end
		if valid and rect[3] > 0 and rect[4] > 0 then return rect end
	end
	return E.Rects[role]
end

function E.placePanel(role, x, y, w, h, s, minT, compact)
	local state = E.Panels and E.Panels[role]
	if not state then return end
	place(state.Image, x, y, w, h)
	place(state.Fallback, x, y, w, h)
	local minimums = type(E.Config.MinBakedWidth) == "table" and E.Config.MinBakedWidth or {}
	local defaultMinimum = role == "Premise" and 480 or (role == "Footer" and 380 or 200)
	state.CanDisplay = w * s >= (tonumber(minimums[role]) or defaultMinimum)
	if role == "Title" then
		setTextRange(heading.Text, minT, h * 0.46)
	elseif role == "Premise" then
		local pad = math.max(4 / s, h * 0.08)
		local rowH = math.max(1, (h - pad * 2) / math.max(1, #premiseLabels))
		for i, label in premiseLabels do
			label.TextWrapped = compact
			place(label, pad * 2, pad + (i - 1) * rowH, w - pad * 4, rowH)
			setTextRange(label, minT, math.max(minT, math.min(rowH * 0.7, (compact and 13 or 16) / s)))
		end
	else
		local iconW = math.min(h * 0.65, 30 / s)
		local pad = math.max(6 / s, h * 0.10)
		place(note.Icon, pad, (h - iconW) / 2, iconW, iconW)
		place(note.Text, pad * 2 + iconW, pad, math.max(1, w - pad * 3 - iconW), h - pad * 2)
		note.Text.TextWrapped = compact
		setTextRange(note.Text, minT, math.max(minT, math.min(h * 0.4, (compact and 12 or 16) / s)))
	end
	state.Update()
end

function E.layoutScreen(w, h, top, s, minT)
	local reference = E.Layout.ReferenceSize
	if typeof(reference) ~= "Vector2" or reference.X <= 0 or reference.Y <= 0 then reference = Vector2.new(1584, 993) end
	local fit = math.min(w / reference.X, h / reference.Y)
	local W, H = reference.X * fit, reference.Y * fit
	local _, _, areaW, areaH = region(E.rect("Cards"), W, H)
	local count = 0
	for _, id in FACTION_IDS do if cards[id] then count += 1 end end
	local aspect = E.aspect()
	local fitH = fittedCardHeight(areaW, areaH, count * aspect, LAY.Gap * math.max(0, count - 1), 1, s)
	-- Match both raster-rounding steps in placeCards so a changed reference layout cannot select
	-- the desktop path and then drop its artwork for a sub-minimum-height code card.
	local desktopCardH = math.floor(math.max(1, math.floor(fitH)) * aspect) / aspect * s
	local narrow = w * s < 700 or h * s < 420 or (UserInputService.TouchEnabled and h * s < 460)
		or desktopCardH < (tonumber(E.Config.MinBakedCardHeight) or 240)
	local scroll, content = E.Scroll, E.Content
	if E.Narrow ~= narrow then
		scroll.CanvasPosition = Vector2.zero
		cardsRow.CanvasPosition = Vector2.zero
	end
	E.Narrow = narrow
	if narrow then
		-- Keep complete cards in the page. Only the whole page scrolls vertically on short screens.
		local gutter, gap = 8 / s, 6 / s
		local innerW = math.max(1, w - gutter * 2)
		local usableH = math.max(1, h - top - gutter)
		place(scroll, 0, top, w, usableH)
		local titleH = math.min(56 / s, innerW / 4, math.max(28 / s, usableH * 0.12))
		local titleSize = E.Panels and E.Panels.Title and E.Panels.Title.Size
		local titleAspect = typeof(titleSize) == "Vector2" and titleSize.X / math.max(1, titleSize.Y) or 5.4
		local minimums = type(E.Config.MinBakedWidth) == "table" and E.Config.MinBakedWidth or {}
		-- Keep the approved title legible on a short landscape viewport too; retain its source ratio.
		local minimumTitleW = ((tonumber(minimums.Title) or 200) + 2) / s
		titleH = math.min(innerW / titleAspect, math.max(titleH, minimumTitleW / titleAspect))
		local titleW = titleH * titleAspect
		local y = 0
		E.placePanel("Title", (w - titleW) / 2, y, titleW, titleH, s, minT, true)
		y += titleH + gap
		local premiseSize = E.Panels.Premise.Size
		local premiseAspect = typeof(premiseSize) == "Vector2" and premiseSize.X / math.max(1, premiseSize.Y) or 8
		local premiseH = math.max(84 / s, innerW / premiseAspect)
		E.placePanel("Premise", gutter, y, innerW, premiseH, s, minT, true)
		y += premiseH + gap
		-- Fit the entire ornamented row in one page viewport, including hover and raster rounding.
		local cardH = math.max(1, math.min(300 / s, (usableH - 4 / s) / (1 + 2 * LAY.Lift)))
		local areaH = math.min(usableH, math.ceil(cardH * (1 + 2 * LAY.Lift)) + 4 / s)
		placeCards(gutter, y, innerW, areaH, cardH, minT, s)
		-- No child Y scrolling: its full canvas height stays inside this outer page.
		cardsRow.ScrollingDirection = Enum.ScrollingDirection.X
		cardsRow.CanvasPosition = Vector2.new(cardsRow.CanvasPosition.X, 0)
		y += areaH + gap
		local footerSize = E.Panels.Footer.Size
		local footerAspect = typeof(footerSize) == "Vector2" and footerSize.X / math.max(1, footerSize.Y) or 11
		local footerH = math.max(48 / s, innerW / footerAspect)
		E.placePanel("Footer", gutter, y, innerW, footerH, s, minT, true)
		local contentH = y + footerH + gutter
		place(content, 0, 0, w, contentH)
		scroll.CanvasSize = UDim2.fromOffset(w, math.ceil(contentH))
		scroll.ScrollingEnabled = contentH > usableH
		scroll.ScrollBarThickness = scroll.ScrollingEnabled and LAY.ScrollBar or 0
		scroll.CanvasPosition = Vector2.new(0, math.clamp(scroll.CanvasPosition.Y, 0, math.max(0, contentH - usableH)))
	else
		place(scroll, 0, 0, w, h)
		place(content, 0, 0, w, h)
		scroll.CanvasSize = UDim2.fromOffset(w, h)
		scroll.ScrollingEnabled = false
		scroll.ScrollBarThickness = 0
		scroll.CanvasPosition = Vector2.zero
		local left, upper = (w - W) / 2, (h - H) / 2
		for _, role in { "Title", "Premise", "Footer" } do
			local x, y, rw, rh = region(E.rect(role), W, H)
			E.placePanel(role, left + x, upper + y, rw, rh, s, minT, false)
		end
		local x, y, rw, rh = region(E.rect("Cards"), W, H)
		placeCards(left + x, upper + y, rw, rh, 0, minT, s)
	end
	root:SetAttribute("FactionEPageScroll", scroll.ScrollingEnabled)
	root:SetAttribute("FactionEPageHeight", content.Size.Y.Offset * s)
	root:SetAttribute("FactionEPageViewportHeight", scroll.Size.Y.Offset * s)
	for _, c in cards do
		if c.E then
			c.E.CanDisplay = (c.E.DisplayHeight or 0) >= (tonumber(E.Config.MinBakedCardHeight) or 240)
			c.E.Update()
		end
	end
end

local function layoutNow()
	if not root then return end
	local w, h, top, s = canvas(root.Parent)
	place(root, 0, 0, w, h)
	local minT = minTextFor(s)
	if E.Enabled then
		E.layoutScreen(w, h, top, s, minT)
		return
	end
	local physicalCaption = math.clamp(math.floor(h * s * LAY.TextFrac), 12, LAY.TextMax)
	local size = math.ceil(physicalCaption / math.min(s, 1))
	local compact = h * s < 560
	local needH = LAY.NeedCardK * minT
	local g = LAY.Gutter
	local bottom = h - 8

	-- Selected A composition: title / wide compact premise / centred cards / centred altar note.
	local y = top
	local usableH = math.max(80, bottom - top)
	local titleH = math.clamp(math.floor(usableH * LAY.TitleFrac), LAY.TitleMin, LAY.TitleMax)
	y += placeTitle(w / 2, y, w - g * 2, titleH, minT) + 4
	local premiseW = math.min(w - g * 2, LAY.PremiseMaxW, math.max(300, w * LAY.PremiseFrac))
	y += placePremise(w / 2, y, premiseW, size, s, compact) + 8
	local noteH = placeFooter(w / 2, bottom, w - g * 2, size, s, compact)
	local areaH = bottom - noteH - 6 - y
	placeCards(g, y, w - g * 2, math.max(areaH, 1), needH, minT, s)
end

-- FontFace bounds can yield while loading. Serialize layout passes so a resize never lets an older pass win.
local function layout()
	if LAY.LayoutRunning then LAY.LayoutAgain = true; return end
	LAY.LayoutRunning = true
	local ok, err = pcall(layoutNow)
	LAY.LayoutRunning = false
	if LAY.LayoutAgain then
		LAY.LayoutAgain = false
		task.defer(layout)
	end
	if not ok then warnThrottled("layout error: " .. tostring(err)) end
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

	-- premise lines on a parchment strip; they fade in one by one (playPremise)
	premiseFrame = sliceFrame(root, "Premise", "PanelParchment", 2)
	premiseFrame.ClipsDescendants = true
	premiseLabels = {}
	local premise = Config.Story.Premise
	if type(premise) == "table" then
		for i, line in premise do
			local l = artLabel(premiseFrame, "PremiseLine" .. i, 1)
			l.TextScaled = false
			l.Text = tostring(line)
			l.TextColor3 = artColor("Ink", DARK_TEXT)
			l.TextTransparency = 1
			table.insert(premiseLabels, l)
		end
	end

	-- "어느 편에 설래요?" on the GPT title ribbon; plain gold text when the ribbon art is missing
	local ribbonId = artId("TitleRibbon")
	local titleFrame
	if ribbonId then
		titleFrame = newImage(root, "Title", 2)
		titleFrame.ScaleType = Enum.ScaleType.Stretch -- placeTitle keeps the image aspect
		titleFrame.Image = ribbonId
	else
		titleFrame = Instance.new("Frame")
		titleFrame.Name = "Title"
		titleFrame.BackgroundTransparency = 1
		titleFrame.BorderSizePixel = 0
		titleFrame.ZIndex = 2
		titleFrame.Parent = root
	end
	local titleText = artLabel(titleFrame, "Text", 1, artFont("Title", Enum.Font.GothamBlack))
	titleText.Text = T.Title
	titleText:SetAttribute("PickerFitPaddingX", 8)
	titleText.TextWrapped = false
	if ribbonId then
		local b = LAY.TitleText
		titleText.Position = UDim2.fromScale(b[1], b[2])
		titleText.Size = UDim2.fromScale(b[3], b[4])
		styleText(titleText, "ink", 0)
	else
		titleText.Size = UDim2.fromScale(1, 1)
		titleText.TextColor3 = artColor("Ink", Color3.fromRGB(66, 40, 18))
		titleText.Font = theme.Font
		applyFont(titleText, Enum.Font.GothamBlack)
	end
	local rs = partSize("TitleRibbon")
	heading.Frame, heading.Text, heading.Art = titleFrame, titleText, ribbonId ~= nil
	heading.Aspect = rs and rs.X / rs.Y or 4

	-- the three cards (a sideways ScrollingFrame only when they cannot fit, see placeCards)
	cardsRow = Instance.new("ScrollingFrame")
	cardsRow.Name = "Cards"
	cardsRow.BackgroundTransparency = 1
	cardsRow.BorderSizePixel = 0
	cardsRow.ScrollingDirection = Enum.ScrollingDirection.X
	cardsRow.ScrollingEnabled = false
	cardsRow.ScrollBarThickness = 0
	cardsRow.ScrollBarImageColor3 = artColor("Gold", theme.Gold)
	cardsRow.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	cardsRow.CanvasSize = UDim2.fromOffset(0, 0)
	cardsRow.Parent = root
	local anyArt = false
	for i, id in FACTION_IDS do
		buildCard(id, i)
		if cards[id] and (cards[id].Art or cards[id].E) then anyArt = true end
	end
	if anyArt then root.BackgroundTransparency = LAY.DimArt end

	-- altar note at the bottom
	local nf = sliceFrame(root, "Footer", "PanelParchment", 2)
	local icon = newImage(nf, "Icon", 1)
	icon.Image = artId("IconAltar") or ""
	icon.Visible = icon.Image ~= ""
	local text = artLabel(nf, "Text", 1)
	text.TextScaled = false
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.Text = T.Footer
	styleText(text, "ink")
	note.Frame, note.Icon, note.Text = nf, icon, text

	root.Parent = gui
	if E.Enabled then E.buildPanels() end
	built = true
	layout()
	return true
end

------------------------------------------------------------------ open / close effects
local function setBlur(on)
	if on then
		local cam = workspace.CurrentCamera
		if not cam then return end
		if blur and blur.Parent == cam then return end
		if blur then blur:Destroy() end
		blur = Instance.new("BlurEffect")
		blur.Name = "FactionPickerBlur"
		blur.Size = LAY.BlurSize
		blur.Parent = cam -- camera post effects are local to this client
	elseif blur then
		blur:Destroy()
		blur = nil
	end
end

function E.holdBackground(instance)
	local world = E.World
	if not world.Active or world.Records[instance] then return end
	local ok, enabled = pcall(function() return instance.Enabled end)
	if not ok or type(enabled) ~= "boolean" then return end
	local record = { Value = enabled, Connection = nil }
	world.Records[instance] = record
	pcall(function() instance.Enabled = false end)
	-- Newly replicated state must not re-expose world text while this picker is open.
	pcall(function()
		record.Connection = instance:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not world.Active then return end
			pcall(function() if instance.Enabled then instance.Enabled = false end end)
		end)
	end)
end

function E.backgroundAdded(instance)
	if instance:IsA("BillboardGui") or instance:IsA("SurfaceGui")
		or (instance:IsA("ScreenGui") and instance.Name == "TouchGui") then E.holdBackground(instance) end
end

function E.hideLegacyChat()
	local world = E.World
	if not world.Active then return end
	-- Studio may still show legacy help text while TextChatService is selected. Hide only Chat;
	-- leave Roblox/Menu untouched, and retry the protected call as CoreGui finishes starting.
	if world.CoreChat == nil then
		local got, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat)
		if got and type(enabled) == "boolean" then world.CoreChat = enabled end
	end
	if world.CoreChat ~= nil then
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, false)
	end
	if world.LegacyChat ~= nil then return end
	local ok, legacy = pcall(function() return TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService end)
	if not ok or not legacy then return end
	local got, active = pcall(StarterGui.GetCore, StarterGui, "ChatActive")
	if got and type(active) == "boolean" then
		world.LegacyChat = active
		pcall(StarterGui.SetCore, StarterGui, "ChatActive", false)
	end
end

function E.background(on)
	if not E.Enabled then return end
	local world = E.World
	if on == world.Active then return end
	world.Active = on
	if on then
		world.Records, world.Connections, world.LegacyChat, world.CoreChat = {}, {}, nil, nil
		local pg = player:FindFirstChildOfClass("PlayerGui")
		for _, scope in { workspace, pg } do
			if scope then
				table.insert(world.Connections, scope.DescendantAdded:Connect(E.backgroundAdded))
				for _, instance in scope:GetDescendants() do E.backgroundAdded(instance) end
			end
		end
		local classes = { ChatWindowConfiguration = true, ChatInputBarConfiguration = true,
			ChannelTabsConfiguration = true, BubbleChatConfiguration = true }
		local function chatAdded(instance)
			if classes[instance.ClassName] then E.holdBackground(instance) end
		end
		table.insert(world.Connections, TextChatService.ChildAdded:Connect(chatAdded))
		for _, child in TextChatService:GetChildren() do chatAdded(child) end
		E.hideLegacyChat()
	else
		for _, connection in world.Connections do connection:Disconnect() end
		world.Connections = {}
		for instance, record in world.Records do
			if record.Connection then record.Connection:Disconnect() end
			pcall(function() instance.Enabled = record.Value end)
		end
		world.Records = {}
		if world.LegacyChat ~= nil then pcall(StarterGui.SetCore, StarterGui, "ChatActive", world.LegacyChat) end
		world.LegacyChat = nil
		if world.CoreChat ~= nil then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, world.CoreChat)
		end
		world.CoreChat = nil
	end
	if root then root:SetAttribute("FactionEBackgroundHidden", on) end
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
	setBlur(open)
	E.background(open)
	chosenId = nil
	for _, c in cards do
		c.Hover, c.Down = false, false
	end
	if open then
		-- CR-M26: a fast second tap must not land on a card the moment the picker opens
		lockedUntil = math.max(lockedUntil, os.clock() + OPEN_LOCK)
		layout()
		updateBadges()
		refreshButtons()
		playPremise()
		task.delay(OPEN_LOCK + 0.05, function()
			if built and visible then refreshButtons() end
		end)
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
	if visible then -- the blur lives in the camera
		setBlur(false)
		setBlur(true)
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
	if root and E.Enabled then
		root.Destroying:Connect(function()
			E.background(false)
			setBlur(false)
		end)
	end
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
			if E.World.Active then E.hideLegacyChat() end
			local ok, err = pcall(function()
				refresh()
				E.refreshImages()
			end)
			if not ok then warnThrottled("refresh error: " .. tostring(err)) end
		end
	end)

	refresh()
	print("[FactionPicker] started")
end

return FactionPicker
