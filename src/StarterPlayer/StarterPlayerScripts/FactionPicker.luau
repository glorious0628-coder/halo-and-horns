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

-- A23-57 (beta): Halo and Horns only; Config.Features.NeutralFaction (game dev 2) brings the Artisan Guild card back
local FACTION_IDS = (type(Config.Features) == "table" and Config.Features.NeutralFaction == true)
	and { "Halo", "Horns", "Neutral" } or { "Halo", "Horns" }
-- A23-114 (beta): while the Artisan Guild is off, a third locked "Artisan Guild - Coming soon" card stands beside Halo /
-- Horns (grey, a little smaller; a press only shakes it, no server request). ROW_IDS = the cards the row lays out, in
-- order: the neutral guild BETWEEN the two sides (검수 10/10: [Halo] [Artisan] [Horns], the mascots at the ends)
local SOON_ID = "Soon"
local ROW_IDS = table.clone(FACTION_IDS)
if not table.find(FACTION_IDS, "Neutral") then table.insert(ROW_IDS, math.min(2, #ROW_IDS + 1), SOON_ID) end
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

-- art layout tunables (canvas units = inside MainGui's UIScale)
local LAY = {
	Gutter = 16, -- side gutter
	Gap = 12, -- between cards
	CardMaxH = 640,
	Lift = 0.04, -- room around the cards for the hover scale + glow (fraction of the card height)
	-- Only a narrow touch viewport uses larger cards and a sideways scroll; desktop A always shows all cards.
	NeedCardK = 26,
	-- the A23-57 cards carry less text (name, four perks, the button): this many min-text sizes of card height keep them
	-- readable (UiSandbox phone 749x361, 2026-10-06: at 26 the two cards ran off the bottom)
	NeedCardKNew = 18,
	-- the title words must fit the ribbon's text band (TextRect) at the readable size: about this many em per letter
	TitleEm = 0.58,
	PremiseMaxW = 1600, PremiseFrac = 0.66,
	TitleFrac = 0.10, TitleMin = 40, TitleMax = 140, -- compact ribbon on short viewports
	TitleFracArt = 0.2, TitleMaxArt = 220, -- bundle 2 FactionTitle (crown + halo + horn over the scroll)
	ButtonWord = 0.043, -- 'Join this side!' size / card height: half the bundle 2 buttons' ~8.5%
	TextFrac = 0.021, TextMax = 16, -- physical caption target; preserve the three sentences above the cards
	-- A23-48: English only (glossary names); Short / Tiny = the fallbacks for narrow cards
	LoreShort = { Halo = "Those who took the Halo.", Horns = "Those who took the Horns.", Neutral = "Those who shape the shards." },
	LoreTiny = { Horns = { "They took the Horns.", "Took the Horns." }, Neutral = "Shard crafters." },
	-- the Pitch line's shorter wordings for narrow cards (Config.Factions.*.Pitch, 개발 1 8475c8de)
	MottoShort = { Halo = "Heal & catch thieves!", Horns = "Tricks & PvP gold!", Neutral = "Don't grab it, craft it!" },
	MottoTiny = { Halo = "Heal & catch!", Horns = "PvP gold!", Neutral = "Craft it!" },
	MascotH = 0.95, MascotMinFit = 0.6, -- the mascots: height / the card row's, the least share of that size still shown
	PitchFrac = 0.36, -- the A23-57 cards: the Pitch line's share of the perk panel (up to two lines)
	PerkTiny = {
		Halo = { "XP +30%", "HP +20% · Regen", "Heal allies", "Auto gold" },
		Horns = { "Gold +25%", { "ATK +15% · Lifesteal", "ATK +15% Lifesteal", "ATK+15% Lifesteal" }, "Keep looted gold", "5★ = Kaiju" },
		-- A23-179 stale text: the crafting row's words come from Config.UIArt.FactionPerks.Neutral (Text / Short) only
		Neutral = { "No fight buffs", "Safe (no PvP)", "No loot or Wanted" },
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
	PerkInsetNew = { 0.03, 0.02 }, -- the A23-57 cards' Panel region is already the inner panel
	-- glow layers behind a hovered / chosen card { extra width, extra height, transparency } around the card body
	Glow = { { 0.04, 0.03, 0.45 }, { 0.08, 0.05, 0.75 } },
	GlowBody = { Art = { 0.56, 0.88 }, Old = { 0.5, 1 } }, -- { centre Y, height }: the art's emblem pokes out on top
	Regions = { "Title", "Desc", "Motto", "Perks", "Button" },
	-- A23-114 locked card: its size against the faction cards, the press shake (x offsets, step seconds), the grey look
	-- of the code card (until the FactionPickSoon art; text regions { x, y, w, h } of the card)
	SoonScale = 0.9,
	SoonShake = { 7, -7, 5, -5, 2, 0 },
	SoonStep = 0.045,
	SoonBg = Color3.fromRGB(70, 72, 82),
	SoonRim = Color3.fromRGB(128, 130, 140),
	SoonInk = Color3.fromRGB(196, 198, 206),
	SoonDim = Color3.fromRGB(150, 152, 162),
	SoonRegions = { Title = { 0.06, 0.07, 0.88, 0.11 }, Soon = { 0.08, 0.64, 0.84, 0.1 }, Sub = { 0.1, 0.76, 0.8, 0.065 } },
	-- A23-167 ④: the 'what this pick changes' lines under each side's card (Config.FactionChanges): text size = the
	-- readable floor x ChangesK, line height = size x ChangesLineK, ChangesGap du between the card and the lines
	ChangesK = 1.15, ChangesLineK = 1.3, ChangesGap = 4,
}

-- per-faction text style on the card art ("ink" = brown on parchment, "light" = white with a dark outline,
-- "gold" = gold with a dark outline like the "Choose your side!" title)
-- bundle 2 cards: white names on the coloured ribbons, ink on the cream strips and perk panels, white button words
local CARD_STYLE = {
	-- A23-57 redraw (FactionPick*): Halo's cream panel takes dark words, Horns' charcoal panel light ones
	New = {
		Halo = { Title = "light", Motto = "ink", Perks = "ink", Button = "light" },
		Horns = { Title = "light", Motto = "light", Perks = "light", Button = "light" },
	},
	Halo = { Title = "light", Motto = "ink", Perks = "ink", Button = "light" },
	Horns = { Title = "light", Motto = "ink", Perks = "ink", Button = "light" },
	Neutral = { Title = "light", Motto = "ink", Perks = "ink", Button = "light" },
}
-- bundle 2 screen parts (navy premise / footer: white text); the older parchment parts when they are missing
local PANEL = { Title = "FactionTitle", Premise = "FactionPremise", Footer = "FactionFooter" }

-- Neutral fallbacks (A6 / A9-1 teal), used only if Config lacks the entries
local NEUTRAL_FALLBACK = {
	Id = "Neutral", Name = "Artisan Guild", Short = "Artisan", Emblem = "A",
	Color = Color3.fromRGB(40, 200, 190), Perks = {}, Pitch = "",
}
local NEUTRAL_LORE = "Those who shape the shards instead of grabbing them."
local NEUTRAL_NOTE = "" -- A23-179 stale text: the note is Config.Factions.Neutral.Note only (no copy in code)

local T = Config.ClientText.FactionPicker -- the words: Config.ClientText.FactionPicker (moved 10/14)

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
-- unsafe or empty emblem falls back to "A" (Neutral, Artisan) or the first letter of the faction name
local function emblemText(id, def)
	local e = tostring(def.Emblem or "")
	local safe = e ~= "" and e ~= "⚙"
	if safe and type(Util.GlyphSafe) == "function" then
		local ok, res = pcall(Util.GlyphSafe, e)
		safe = ok and res == true
	end
	if safe then return e end
	if id == "Neutral" then return "A" end
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
	if UIKit and type(UIKit.ApplyFont) == "function" then
		pcall(UIKit.ApplyFont, label, title and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
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
		if font == Enum.Font.Unknown then error("FontFace is required.") end
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
		if c.Art then
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
-- the A23-57 redraw (FactionPick<id>: Title / Perks / Button, no Desc / Motto strips) when uploaded, else bundle 2
-- (Card<id>, every region); nil = the code-styled card (IMG-R4)
local function cardArt(id)
	for _, key in { "FactionPick" .. id, "Card" .. id } do
		local lay = Art.Layout[key]
		local img = partSize(key)
		local imageId = artId(key)
		local ok = type(lay) == "table" and img ~= nil and imageId ~= nil
		if ok then
			for _, name in LAY.Regions do
				local r = lay[name]
				if type(r) == "table" then
					for j = 1, 4 do
						if type(r[j]) ~= "number" then ok = false end
					end
				elseif not (key ~= "Card" .. id and (name == "Desc" or name == "Motto")) then
					ok = false
				end
			end
		end
		if ok then return key, lay, img, imageId end
	end
	return nil
end

local function buildArtCard(c, id, lay, img, imageId)
	local def = factionDef(id)
	c.NewArt = lay.Desc == nil -- the A23-57 cards (no lore / motto strips)
	local style = (c.NewArt and CARD_STYLE.New[id]) or CARD_STYLE[id] or CARD_STYLE.Halo
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
	-- 검수 10/09 (system review ①): the A23-57 cards show the faction's one easy line (def.Pitch) big at the top of the perk
	-- panel, the number lines smaller under it (layoutPerks)
	desc.Visible, motto.Visible = lay.Desc ~= nil, lay.Motto ~= nil or (lay.Desc == nil and motto.Text ~= "")

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
	local badge = sliceFrame(body, "WeakerBadge", "Chip", 7)
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
		if noteText ~= "" then listText(scroll, noteText, 15, theme.Gold, order2, theme.Font) end
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

-- one card slot in the row: Body (scaled on hover / press) holding the art card or the code-styled card + glow
-- A23-167 ④ (pure): the 'what this pick changes' lines of a side (Config.FactionChanges[id], strings only, up to 3)
function FactionPicker.ChangeLines(id)
	local all = Config.FactionChanges
	local list = type(all) == "table" and all[id] or nil
	local out = {}
	for _, line in type(list) == "table" and list or {} do
		if type(line) == "string" and line ~= "" and #out < 3 then table.insert(out, line) end
	end
	return out
end

-- the lines under a card: one light outlined label each, in the card row (placeCards lays them out under the card)
local function buildChanges(c, id)
	local lines = FactionPicker.ChangeLines(id)
	if #lines == 0 then return end
	local frame = Instance.new("Frame")
	frame.Name = "Changes_" .. id
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = cardsRow
	c.Changes = { Frame = frame, Labels = {} }
	for i, line in lines do
		local l = artLabel(frame, "Line" .. i, 3)
		l.TextScaled = false
		l.TextWrapped = false
		l.Text = line
		styleText(l, "light", 1)
		table.insert(c.Changes.Labels, l)
	end
end

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
	if key then
		local ok, err = pcall(buildArtCard, c, id, lay, img, imageId)
		if not ok then
			Util.Warn(TAG, "art card " .. key .. " failed, drawing the code card: " .. tostring(err))
			for _, child in body:GetChildren() do
				if child ~= scale then child:Destroy() end
			end
			c.Art, c.Shade, c.Layout, c.Perks = false, nil, nil, nil
		end
	end
	if not c.Art then buildOldCard(c, id) end
	buildChanges(c, id)
	buildGlow(c)
	wireHover(c)
	cards[id] = c
end

-- A23-114: a press shakes the locked card sideways a little (no sound, no remote); one shake at a time
local function shakeSoon(c)
	if c.Shaking then return end
	c.Shaking = true
	c.Slot:SetAttribute("Shakes", (tonumber(c.Slot:GetAttribute("Shakes")) or 0) + 1) -- read by the photo checks
	task.spawn(function()
		for _, dx in LAY.SoonShake do
			tween(c.Body, LAY.SoonStep, { Position = UDim2.new(0.5, dx, 0.5, 0) })
			task.wait(LAY.SoonStep)
		end
		if c.Body.Parent then c.Body.Position = UDim2.fromScale(0.5, 0.5) end
		c.Shaking = false
	end)
end

-- the locked Artisan Guild card: the FactionPickSoon art when uploaded (words in its Layout regions), else a grey code
-- card with a padlock (IMG-R4). Not in `cards`: choose / buttons / badges / glow never see it.
local function buildSoonCard(order)
	local slot = Instance.new("Frame")
	slot.Name = "Card_" .. SOON_ID
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
	body.Parent = slot
	local scale = Instance.new("UIScale")
	scale.Name = "CardScale"
	scale.Scale = LAY.SoonScale
	scale.Parent = body
	local c = { Id = SOON_ID, Slot = slot, Body = body, Scale = scale, Soon = true, Art = false, Aspect = LAY.OldAspect }

	local imageId, size = artId("FactionPickSoon"), partSize("FactionPickSoon")
	local lay = (imageId and size and type(Art.Layout.FactionPickSoon) == "table") and Art.Layout.FactionPickSoon or LAY.SoonRegions
	local ink, dim = LAY.SoonInk, LAY.SoonDim
	if imageId and size then
		c.ArtAspect = size.X / size.Y
		c.Aspect = c.ArtAspect
		local bg = newImage(body, "Art", 2)
		bg.ScaleType = Enum.ScaleType.Stretch
		bg.Size = UDim2.fromScale(1, 1)
		bg.Image = imageId
	else
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.BackgroundColor3 = LAY.SoonBg
		panel.BackgroundTransparency = 0.08
		panel.BorderSizePixel = 0
		panel.Size = UDim2.fromScale(1, 1)
		panel.ZIndex = 2
		corner(panel, 14)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Color = LAY.SoonRim
		st.Thickness = 3
		st.Parent = panel
		panel.Parent = body
		-- padlock: a ring (the shackle) over a rounded block with a keyhole
		local lock = Instance.new("Frame")
		lock.Name = "Lock"
		lock.AnchorPoint = Vector2.new(0.5, 0)
		lock.Position = UDim2.fromScale(0.5, 0.25)
		lock.Size = UDim2.fromScale(0.4, 0.34)
		lock.BackgroundTransparency = 1
		lock.ZIndex = 3
		lock.Parent = panel
		local ring = Instance.new("Frame")
		ring.Name = "Shackle"
		ring.AnchorPoint = Vector2.new(0.5, 0)
		ring.Position = UDim2.fromScale(0.5, 0)
		ring.Size = UDim2.fromScale(0.62, 0.62)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 3
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0.5, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.Color = LAY.SoonRim
		rs.Thickness = 9
		rs.Parent = ring
		ring.Parent = lock
		local block = Instance.new("Frame")
		block.Name = "Block"
		block.AnchorPoint = Vector2.new(0.5, 1)
		block.Position = UDim2.fromScale(0.5, 1)
		block.Size = UDim2.fromScale(1, 0.6)
		block.BackgroundColor3 = LAY.SoonRim
		block.BorderSizePixel = 0
		block.ZIndex = 4
		corner(block, 10)
		block.Parent = lock
		local hole = Instance.new("Frame")
		hole.Name = "Keyhole"
		hole.AnchorPoint = Vector2.new(0.5, 0.5)
		hole.Position = UDim2.fromScale(0.5, 0.45)
		hole.Size = UDim2.fromScale(0.14, 0.3)
		hole.BackgroundColor3 = LAY.SoonBg
		hole.BorderSizePixel = 0
		hole.ZIndex = 5
		corner(hole, 6)
		hole.Parent = block
	end
	local words = {
		{ "FactionName", T.SoonName, lay.Title or LAY.SoonRegions.Title, ink, artFont("Title", Enum.Font.GothamBlack), 40, "light" },
		{ "Soon", T.Soon, lay.Soon or LAY.SoonRegions.Soon, ink, artFont("Title", Enum.Font.GothamBlack), 34, "ink" },
		{ "Sub", T.SoonSub, lay.Sub or LAY.SoonRegions.Sub, dim, theme.Font, 22, lay.SubStyle or "light" },
	}
	for _, w in words do
		local r = w[3]
		local l = newLabel(body, {
			Name = w[1],
			Position = UDim2.fromScale(r[1], r[2]),
			Size = UDim2.fromScale(r[3], r[4]),
			Text = w[2],
			TextScaled = true,
			TextWrapped = false,
			TextColor3 = w[4],
			Font = w[5],
			ZIndex = 6,
		}, w[6])
		-- on the FactionPickSoon art: white on the brass ribbon, ink on the parchment (CardLayout SubStyle)
		if c.ArtAspect then styleText(l, w[7], 1) end
	end
	-- the whole card is the hit area (a press = the shake); not selectable, so a gamepad skips it
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Selectable = false
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 7
	hit.Parent = body
	hit.Activated:Connect(function()
		shakeSoon(c)
	end)
	c.Button = hit
	LAY.SoonCard = c
end

-- a card of the row by id (the locked one lives apart from `cards`)
local function rowCard(id)
	if id == SOON_ID then return LAY.SoonCard end
	return cards[id]
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
	local button = c.Button
	button.Position = UDim2.new(0.5, 0, 1, -10)
	button.Size = UDim2.new(1, -24, 0, bh)
end

-- A full sentence can shrink until the real 11px floor. If it still cannot fit, try every approved compact
-- equivalent too; returning an unchecked Short was the cause of clipped labels in the default 991px view.
-- atSize: the size the text must fit at (default MIN_TEXT): perk rows pass their common size, so a long line takes its
-- shorter wording instead of a smaller font (검수 2026-10-06: every perk line the same size)
local function cardText(label, full, short, tiny, width, height, scale, atSize)
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
			th, tw, exact = UIKit.MeasureRenderedText(text, atSize or MIN_TEXT, label.FontFace, scale, 10000)
		else
			th, tw = textBounds(text, math.max(MIN_TEXT, (atSize or MIN_TEXT) * scale), label.FontFace, 10000)
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
	local inset = (c.NewArt and LAY.PerkInsetNew) or LAY.PerkInset[c.Id] or LAY.PerkInset.Horns
	px, pw = px + W * inset[1], pw - W * inset[1] * 2
	-- A23-57 cards: the Pitch line on top of the panel (big, wraps to two lines; shorter wording when even two lines
	-- at the floor cannot hold it), the perk rows share the rest
	if c.NewArt and c.Motto and c.Motto.Visible then
		local pitchH = ph * LAY.PitchFrac
		local lines = 2
		-- English dump 10/15 (phone: the perk rows were 10 px for an 11 px line, cut): when the rows under a two-line
		-- pitch would be shorter than a real 11 px line + 3, the pitch takes one line (its shorter wording)
		if (ph - pitchH) / math.max(LAY.PerkRows, #c.Perks) * scale < MIN_TEXT + 3 then pitchH, lines = pitchH / 2, 1 end
		local lineH = pitchH / lines
		c.Motto.Text = cardText(c.Motto, c.FullMotto, LAY.MottoShort[c.Id], LAY.MottoTiny[c.Id], pw * lines * scale * 0.9,
			lineH * scale, scale)
		c.Motto.TextWrapped = lines == 2
		c.Motto.TextXAlignment = Enum.TextXAlignment.Center
		place(c.Motto, px, py + ph * 0.02, pw, pitchH)
		setTextRange(c.Motto, minT, math.max(minT, lineH * 0.82))
		py, ph = py + pitchH, ph - pitchH
	end
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
	-- 검수 2026-10-06: every perk line of a card at ONE size: the largest at which each row fits with its shortest
	-- wording (placeCards then gives the three cards the smallest of their sizes)
	local compact = LAY.PerkTiny[c.Id]
	for i, row in c.Perks do
		local shortest = row.Full
		local tiny = compact and compact[i]
		if type(tiny) == "table" then shortest = tiny[#tiny] or shortest
		elseif type(tiny) == "string" and tiny ~= "" then shortest = tiny
		elseif type(row.Short) == "string" and row.Short ~= "" then shortest = row.Short end
		local tw = nil
		if UIKit and type(UIKit.MeasureRenderedText) == "function" then
			local _, w, exact = UIKit.MeasureRenderedText(shortest, size, row.Text.FontFace, scale, 10000)
			if exact then tw = w end
		end
		if tw and tw > textW * scale - 1 then
			size = math.max(MIN_TEXT, math.floor(size * (textW * scale - 1) / tw))
		end
	end
	c.PerkSize = math.min(size, LAY.PerkShared or size)
	size = c.PerkSize
	for i, row in c.Perks do
		row.Text.Text = cardText(row.Text, row.Full, row.Short, compact and compact[i], textW * scale, rowH * scale, scale,
			size)
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
		-- the card's one size (never fitted per row) for our English; A23-179: a longer translation may shrink to MIN_TEXT
		-- (TextScaled draws the translated words) instead of being cut by the row's clip
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

	if lay.Desc then layoutDesc(c, W, H, minT, s) end

	-- motto: one line; the box may spill onto the ribbon tails (the A23-57 cards have no motto strip)
	if lay.Motto then
		local mx, my, mw, mh = region(lay.Motto, W, H)
		local motW = math.min(W * 0.9, mw * 1.3)
		local mottoSize = math.max(MIN_TEXT, math.floor(mh * 0.72))
		c.Motto.Text = cardText(c.Motto, c.FullMotto, LAY.MottoShort[c.Id], LAY.MottoTiny[c.Id], motW * s, mh * 0.96 * s, s)
		c.Motto.TextWrapped = false
		place(c.Motto, mx + mw / 2 - motW / 2, my + mh * 0.02, motW, mh * 0.96)
		setTextRange(c.Motto, minT, mottoSize)
	end

	layoutPerks(c, W, H, minT, s)

	-- button: lock shade, label, and a hit area at least TouchTarget real px tall, kept inside the card
	local kx, ky, kw, kh = region(lay.Button, W, H)
	place(c.Shade, kx, ky, kw, kh)
	-- 검수 2026-10-06: the words are about half the drawn button's height (the bundle 2 buttons are ~8.5% of the card;
	-- the measured regions are their inner glossy bands) and the same on the three cards
	local wordMax = math.max(minT, H * LAY.ButtonWord)
	local boxH = math.max(kh * 0.7, wordMax * 1.3)
	place(c.Label, kx + kw * 0.05, ky + kh / 2 - boxH / 2, kw * 0.9, boxH)
	setTextRange(c.Label, minT, wordMax)
	boldOutline(c.Label, wordMax)
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
	local framePart = Art.Parts[PANEL.Premise]
	if premiseFrame.Name == "Premise" and typeof(framePart) == "table" and typeof(framePart.Slice) == "Rect"
		and artId(PANEL.Premise) then
		-- bundle 2 navy panel: keep the lines off its gold frame (the slice border at the panel's SliceScale)
		local edge = framePart.Slice.Min.Y * (tonumber(framePart.SliceScale) or 0.5)
		padX = math.max(padX, math.ceil(edge * 1.1))
		padY = math.max(padY, math.ceil(edge * 0.8))
	end
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

-- Match the three original bitmap widths and their baked button centres without stretching any card.
local function prepareCardBalance()
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
	-- A23-114: the locked card takes the faction cards' width (its own art's aspect when drawn), centred on their height
	local soon = LAY.SoonCard
	if soon then
		if not soon.ArtAspect then soon.Aspect = aspect end
		soon.HeightFactor = aspect / soon.Aspect
		LAY.BalancedHeight = math.max(LAY.BalancedHeight, soon.HeightFactor)
		soon.YFactor = (LAY.BalancedHeight - soon.HeightFactor) / 2
	end
end

local function fittedCardHeight(areaW, areaH, sumAspect, gaps, balancedHeight, s)
	return math.min(math.max(1, areaH - 4) / (balancedHeight + 2 * LAY.Lift),
		LAY.CardMaxH / s, math.max(1, areaW - gaps - 4) / (sumAspect + 2 * LAY.Lift))
end

-- Desktop cards fit their slot.
local function placeCards(x, y, areaW, areaH, needH, minT, s)
	prepareCardBalance()
	local n, sumA = 0, 0
	for _, id in ROW_IDS do
		local c = rowCard(id)
		if c then
			n += 1
			sumA += LAY.CardAspect
		end
	end
	if n == 0 then return end
	local phone = UserInputService.TouchEnabled and areaW * s < 700
	-- A23-167 ④: room under the cards for the 'what this pick changes' lines (the most lines of a card). English dump
	-- 10/15 (phone: the 3 lines took a third of the height, so the cards' words were 11 px and cut): none on a phone
	local chLines = 0
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c and c.Changes then
			c.Changes.Frame.Visible = not phone
			if not phone then chLines = math.max(chLines, #c.Changes.Labels) end
		end
	end
	local chSize = math.ceil(minT * LAY.ChangesK)
	local chLineH = math.ceil(chSize * LAY.ChangesLineK)
	local chH = chLines > 0 and (LAY.ChangesGap + chLines * chLineH) or 0
	areaH = math.max(1, areaH - chH)
	LAY.ChangesH = chH -- placeMascots: the mascots stand on the cards, not on the lines
	local gaps = LAY.Gap * (n - 1)
	local cardH = fittedCardHeight(areaW, areaH, sumA, gaps, LAY.BalancedHeight, s)
	if phone then cardH = math.max(needH, cardH) end
	cardH = math.max(1, math.floor(cardH))
	local lift = math.ceil(cardH * LAY.Lift)
	local canvasW = gaps + 2 * lift
	for _, id in ROW_IDS do
		local c = rowCard(id)
		if c then canvasW += math.floor(cardH * LAY.CardAspect) end
	end
	local canvasH = math.ceil(cardH * LAY.BalancedHeight) + 2 * lift + chH
	local frameH, frameW = math.min(areaH + chH, canvasH), math.min(areaW, canvasW)
	local scrollX, scrollY = phone and canvasW > frameW, phone and canvasH > frameH
	local scroll = scrollX or scrollY
	place(cardsRow, x + (areaW - frameW) / 2, y + math.max(0, (areaH + chH - frameH) / 2), frameW, frameH)
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
	for _, id in ROW_IDS do
		local c = rowCard(id)
		if c then
			local cw = math.floor(cardH * LAY.CardAspect)
			local ch = cw / c.Aspect
			place(c.Slot, cx, lift + (cw / LAY.CardAspect) * c.YFactor, cw, ch)
			if c.Soon then
				-- words and padlock scale with the card (TextScaled, fractions)
			elseif c.Art then
				layoutArtCard(c, cw, ch, minT, s)
			else
				layoutOldCard(c, ch < 420, s)
			end
			c.LayoutArgs = { cw, ch }
			if c.Changes and not phone then -- A23-167 ④: under the card row's common bottom, one line each, centred on the card
				local y0 = lift + math.ceil(cardH * LAY.BalancedHeight) + lift + LAY.ChangesGap
				place(c.Changes.Frame, cx, y0, cw, chH - LAY.ChangesGap)
				for i, l in c.Changes.Labels do
					place(l, 0, (i - 1) * chLineH, cw, chLineH)
					setTextRange(l, minT, chSize)
				end
			end
			cx += cw + LAY.Gap
		end
	end
	-- the three cards' perk lines share the smallest card size: lay the bigger ones out again at it
	local shared = nil
	for _, id in FACTION_IDS do
		local c = cards[id]
		if c and c.Art and c.PerkSize then shared = math.min(shared or c.PerkSize, c.PerkSize) end
	end
	LAY.PerkShared = shared
	if shared then
		for _, id in FACTION_IDS do
			local c = cards[id]
			if c and c.Art and c.PerkSize and c.PerkSize > shared and c.LayoutArgs then
				layoutPerks(c, c.LayoutArgs[1], c.LayoutArgs[2], minT, s)
			end
		end
	end
	LAY.PerkShared = nil
end

-- the two mascots left / right of the card row, feet on the cards' bottom, about the cards' height; hidden where the
-- side room is too narrow for most of a mascot (phones: the cards take the width)
local function placeMascots(w)
	local list = LAY.Mascots
	if not list or #list == 0 then return end
	local cx, cy = cardsRow.Position.X.Offset, cardsRow.Position.Y.Offset
	local cw, ch = cardsRow.Size.X.Offset, math.max(1, cardsRow.Size.Y.Offset - (LAY.ChangesH or 0))
	local h = math.floor(ch * LAY.MascotH)
	-- 검수 10/10 (fair to both sides): one scale for both mascots - the smaller room decides; both hide together
	local scale = 1
	for i, m in list do
		local mw = math.floor(h * m.Aspect)
		local room = i == 1 and (cx - 8) or (w - (cx + cw) - 8)
		scale = math.min(scale, room / math.max(1, mw))
	end
	local fits = scale >= LAY.MascotMinFit
	for i, m in list do
		m.Image.Visible = fits
		if fits then
			local hh, ww = math.floor(h * scale), math.floor(h * m.Aspect * scale)
			local x = i == 1 and (cx - ww - 4) or (cx + cw + 4)
			place(m.Image, x, cy + ch - hh, ww, hh)
		end
	end
end

local function layoutNow()
	if not root then return end
	local w, h, top, s = canvas(root.Parent)
	place(root, 0, 0, w, h)
	local minT = minTextFor(s)
	local physicalCaption = math.clamp(math.floor(h * s * LAY.TextFrac), 12, LAY.TextMax)
	local size = math.ceil(physicalCaption / math.min(s, 1))
	local compact = h * s < 560
	-- the A23-57 cards (no lore / motto strips) need less height; on phones the premise strip gives its room to them
	local newArt = false
	for _, id in FACTION_IDS do
		if cards[id] and cards[id].NewArt then newArt = true end
	end
	local needH = (newArt and LAY.NeedCardKNew or LAY.NeedCardK) * minT
	local g = LAY.Gutter
	local bottom = h - 8

	if newArt and compact then
		-- short screens (phones, short PC windows) with the A23-57 cards. User 10/09 (title on top, not at the side): the title
		-- ribbon centred ABOVE the cards, the altar note one line centred UNDER them (they sat in side columns, 2026-10-06/07).
		-- The ribbon goes up into the Roblox top bar row when its centre span clears the Roblox buttons there
		-- (GuiService.TopbarInset); the cards take the rest of the height.
		premiseFrame.Visible = false
		local part = Art.Parts.FactionPickTitle
		local band = (type(part) == "table" and type(part.TextRect) == "table") and part.TextRect[3] or 0.7
		local _, wordsW = textBounds(T.Title, minT, heading.Text.FontFace, 100000)
		local titleW = math.min(w - g * 2, (wordsW + minT * 1.5) / band) -- the ribbon width its words need at minT
		local tH = math.floor(titleW / heading.Aspect)
		local barH = top - TOP_PAD / s -- the Roblox top bar row (canvas units)
		local okI, free = pcall(function() return GuiService.TopbarInset end)
		local freeL = (okI and typeof(free) == "Rect" and free.Width > 0) and free.Min.X / s or w * 0.4
		local titleY = top
		-- in the bar row its bottom sits on the old card top (top + 2), so the cards keep the height they had beside it
		if (w - titleW) / 2 >= freeL + 6 and barH >= tH * 0.5 then titleY = math.max(2, top + 2 - tH) end
		tH = placeTitle(w / 2, titleY, titleW, tH, minT)
		local noteH = 0 -- A23-191: no altar note
		-- the cards' empty glow room above and below them (LAY.Lift) may run under the ribbon's tail and the note
		local slack = math.floor((bottom - top) * LAY.Lift)
		local cardsTop = math.max(0, titleY + tH - slack)
		local cardsBottom = bottom - noteH + slack
		placeCards(g, cardsTop, w - g * 2, math.max(1, cardsBottom - cardsTop), 0, minT, s)
		placeMascots(w)
		return
	end
	-- Selected A composition: title / wide compact premise / centred cards / centred altar note.
	local y = top
	local usableH = math.max(80, bottom - top)
	-- short (phone) screens keep the room for the cards
	local tall = (heading.Key == PANEL.Title or heading.Key == "FactionPickTitle") and not compact
	local titleH = math.clamp(math.floor(usableH * (tall and LAY.TitleFracArt or LAY.TitleFrac)), LAY.TitleMin,
		tall and LAY.TitleMaxArt or LAY.TitleMax)
	if heading.Key == "FactionPickTitle" then
		-- the words fit the ribbon's text band (0.704 wide) at the readable size ('oose your sid' on a phone before)
		local part = Art.Parts.FactionPickTitle
		local band = (type(part) == "table" and type(part.TextRect) == "table") and part.TextRect[3] or 0.7
		local needW = (#T.Title * LAY.TitleEm + 1) * minT / band
		titleH = math.max(titleH, math.ceil(needW / heading.Aspect))
	end
	y += placeTitle(w / 2, y, w - g * 2, titleH, minT) + 4
	local premiseW = math.min(w - g * 2, LAY.PremiseMaxW, math.max(300, w * LAY.PremiseFrac))
	local hidePremise = newArt and compact
	premiseFrame.Visible = not hidePremise
	if not hidePremise then y += placePremise(w / 2, y, premiseW, size, s, compact) + 8 end
	local noteH = 0 -- A23-191: no altar note under the cards
	local areaH = bottom - noteH - 6 - y
	placeCards(g, y, w - g * 2, math.max(areaH, 1), needH, minT, s)
	placeMascots(w)
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

	-- premise lines on the navy premise panel (bundle 2; parchment before it); they fade in one by one (playPremise)
	local navyPremise = artId(PANEL.Premise) ~= nil
	premiseFrame = sliceFrame(root, "Premise", navyPremise and PANEL.Premise or "PanelMain", 2)
	premiseFrame.ClipsDescendants = true
	premiseLabels = {}
	local premise = Config.Story.Premise
	if type(premise) == "table" then
		for i, line in premise do
			local l = artLabel(premiseFrame, "PremiseLine" .. i, 1)
			l.TextScaled = false
			l.Text = tostring(line)
			if navyPremise then styleText(l, "light", 1) else l.TextColor3 = artColor("Ink", DARK_TEXT) end
			l.TextTransparency = 1
			table.insert(premiseLabels, l)
		end
	end

	-- "어느 편에 설래요?" on the GPT title ribbon; plain gold text when the ribbon art is missing
	-- the A23-57 title ribbon first (FactionPickTitle), then bundle 2's, then the old empty ribbon
	local ribbonKey = (artId("FactionPickTitle") and "FactionPickTitle") or (artId(PANEL.Title) and PANEL.Title)
		or "TitleRibbon"
	local ribbonId = artId(ribbonKey)
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
		local part = Art.Parts[ribbonKey]
		local b = (type(part) == "table" and type(part.TextRect) == "table") and part.TextRect or LAY.TitleText
		titleText.Position = UDim2.fromScale(b[1], b[2])
		titleText.Size = UDim2.fromScale(b[3], b[4])
		styleText(titleText, "ink", ribbonKey ~= "TitleRibbon" and 1 or 0) -- dark words, a thin cream rim on the scroll
	else
		titleText.Size = UDim2.fromScale(1, 1)
		titleText.TextColor3 = artColor("Ink", Color3.fromRGB(66, 40, 18))
		titleText.Font = theme.Font
		applyFont(titleText, Enum.Font.GothamBlack)
	end
	local rs = partSize(ribbonKey)
	heading.Frame, heading.Text, heading.Art = titleFrame, titleText, ribbonId ~= nil
	heading.Key = ribbonId and ribbonKey or nil
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
	for _, id in FACTION_IDS do
		buildCard(id, table.find(ROW_IDS, id) or 0)
		if cards[id] and cards[id].Art then anyArt = true end
	end
	if table.find(ROW_IDS, SOON_ID) then buildSoonCard(table.find(ROW_IDS, SOON_ID)) end
	if anyArt then root.BackgroundTransparency = LAY.DimArt end
	-- the dim over the whole screen, phone side edges included (UIKit.FullScreenDim)
	if type(UIKit.FullScreenDim) == "function" then
		local dim = nil
		LAY.ShowDim, dim = UIKit.FullScreenDim(root, "FactionPickerDim")
		-- review 10/09: the faction sky over the whole screen on that layer (cropped to fill), the mascots beside the cards
		local bg = artId("FactionBgA")
		if bg and dim then
			local sky = Instance.new("ImageLabel")
			sky.Name = "Sky"
			sky.BackgroundTransparency = 1
			sky.Image = bg
			sky.ScaleType = Enum.ScaleType.Crop
			sky.Size = UDim2.fromScale(1, 1)
			sky.ZIndex = 2
			sky.Parent = dim
		end
	end
	LAY.Mascots = {}
	for _, key in { "FacMascotHaloA", "FacMascotHornsA" } do
		local id = artId(key)
		if id then
			local img = newImage(root, key, 1)
			img.Image = id
			img.ScaleType = Enum.ScaleType.Fit
			img.Visible = false
			table.insert(LAY.Mascots, { Image = img, Aspect = (function()
				local sz = partSize(key)
				return (typeof(sz) == "Vector2" and sz.Y > 0) and sz.X / sz.Y or 0.62
			end)() })
		end
	end

	root.Parent = gui
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

local function playPremise()
	premiseToken += 1
	local token = premiseToken
	for i, l in premiseLabels do
		l.TextTransparency = 1
		-- the white lines' dark rim fades in with them (never a rim without its letters)
		local st = l:FindFirstChild("Outline")
		local rim = (st and st:IsA("UIStroke") and st.Thickness > 0) and st or nil
		local rimTo = rim and (rim:GetAttribute("FadeTo") or rim.Transparency) or nil
		if rim then
			rim:SetAttribute("FadeTo", rimTo)
			rim.Transparency = 1
		end
		task.delay((i - 1) * PREMISE_STEP, function()
			if token ~= premiseToken or not l.Parent then return end
			TweenService:Create(l, TweenInfo.new(PREMISE_FADE), { TextTransparency = 0 }):Play()
			if rim then TweenService:Create(rim, TweenInfo.new(PREMISE_FADE), { Transparency = rimTo }):Play() end
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
	if LAY.ShowDim then LAY.ShowDim(open) end
	-- user 10/09: no thumbstick / jump button over the cards (put back as they were when the picker closes)
	if open then
		local ok, was = pcall(function() return GuiService.TouchControlsEnabled end)
		if ok and was == true then
			LAY.TouchWas = true
			pcall(function() GuiService.TouchControlsEnabled = false end)
		end
	elseif LAY.TouchWas then
		LAY.TouchWas = nil
		pcall(function() GuiService.TouchControlsEnabled = true end)
	end
	FactionPicker.HoldWorld("faction", open)
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
		-- UiSandbox 10/09 (phone 749: 'Knights of Ligh'): the first pass can measure before the card fonts loaded; lay
		-- out once more when they have
		task.delay(1, function()
			if built and visible then layout() end
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
-- Full-screen pickers / the opening call this to hold "hide chat + world text". It only ever ran with the Korean
-- baked-text cards (E, off since A23-48, removed 2026-10-08), so it stays a no-op that keeps the API (ClassPicker, Intro)
function FactionPicker.HoldWorld(_key, _on) end

function FactionPicker.IsOpen()
	if player:GetAttribute("DataLoaded") ~= true then return false end
	local f = player:GetAttribute("Faction")
	if not (f == nil or f == "None") then return false end
	-- A23-9: the first-time opening plays before the cards
	local intro = C and C.Intro
	if type(intro) == "table" and type(intro.Blocking) == "function" then
		local ok, blocking = pcall(intro.Blocking)
		if ok and blocking then return false end
	end
	return true
end

-- the opening calls this when it ends (the cards then appear without waiting for an attribute)
function FactionPicker.Refresh()
	if built then pcall(refresh) end
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
			local ok, err = pcall(function()
				refresh()
			end)
			if not ok then warnThrottled("refresh error: " .. tostring(err)) end
		end
	end)

	refresh()
	print("[FactionPicker] started")
end

return FactionPicker
