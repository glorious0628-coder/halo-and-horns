-- ClassPicker.luau : first class choice (faction-specific names) + one-time intro toasts.
-- Visible exactly when DataLoaded == true, Faction ~= "None", ClassChosen == false and the FactionPicker is closed.
-- Look = GPT mockup art/out/UI_Class_A.png (addendum A14-3): faction shield + "직업을 골라요!" ribbon + 남|여 pill, three
-- text-free class card images (Config.UIArt.Parts.ClassCard<Faction>, regions in Config.UIArt.CardLayout) holding the
-- chibi character Char<Faction><Class><M|F>, the name ribbon, description, 체력 / 공격 / 속도 bars
-- (Config.Classes[id].DisplayStats) and the baked "이 직업으로!" button, then a parchment note.
-- A missing card id or layout draws the old code-styled cards instead (IMG-R4), so the picker never breaks.
-- Cards follow SPEC_ADDENDUM A7-4: faction name + generic class chip + description (the PickLine action line when the
-- description does not fit); Warrior shows "처음이면 추천".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local ClassPicker = {}

local TAG = "ClassPicker"
local player = Players.LocalPlayer

local CLICK_LOCK = 2 -- seconds the choose buttons stay disabled after a click
local OPEN_LOCK = 0.6 -- CR-M26: card input ignored this long after the picker opens (fast 2nd tap on "이 편으로!")
local INTRO_STEP = 3 -- seconds between intro toasts
local INTRO_DURATION = 4
local POLL_INTERVAL = 0.5
local WARN_INTERVAL = 10
local ZINDEX = 60
local BODY_FONT = Enum.Font.GothamMedium
local RECOMMENDED = "Warrior"
local NEUTRAL_COLOR = Color3.fromRGB(40, 200, 190) -- A9-1 teal; fallback only (Config.Factions.Neutral.Color wins)

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
	Colors = type(ART.Colors) == "table" and ART.Colors or {},
	Fonts = type(ART.Fonts) == "table" and ART.Fonts or {},
}

-- art layout tunables (canvas units = inside MainGui's UIScale)
local LAY = {
	Gutter = 16, -- side gutter
	HeadFrac = 0.1, HeadMin = 44, HeadMax = 86, -- header (shield + title ribbon) height = canvas height * HeadFrac
	CardMaxH = 640,
	CardMinH = 300, -- below this (or 20 x the min text size) the row scrolls sideways instead of shrinking further
	Lift = 0.035, -- room around the cards for the hover lift (fraction of the card height)
	TouchTarget = 44, -- real px of the invisible hit areas and the code-styled choose buttons (CR-L41)
	FixedTextMin = 15, -- CR-L40: min TextSize of non-scaled code-card text (>= 11 real px under a 0.75 UIScale)
	HoverScale = 1.03,
	PressScale = 0.95,
	Bob = 0.025, -- idle character bob (fraction of the portrait box)
	CharHip = 0.6, -- belt line of the 18 character PNGs (fraction of the image height); it sits on the name ribbon
	BobTime = 1.4, -- seconds per half bob
	BlurSize = 10, -- camera blur behind the picker (mockup background is blurred)
	TitleText = { 0.17, 0.08, 0.66, 0.6 }, -- text box inside UIP_TitleRibbon (fractions of the ribbon)
}

-- per-faction look of the class card art: text style ("ink" = brown on parchment, "light" = white with a dark outline)
-- and the colour of the unfilled stat segments
local CARD_STYLE = {
	Halo = {
		Name = "ink", Body = "ink", Button = "light", -- mockup: white button text with a dark outline on the gold button
		Empty = Color3.fromRGB(214, 203, 184), EmptyRim = Color3.fromRGB(168, 144, 108),
	},
	Horns = {
		Name = "light", Body = "light", Button = "light",
		Empty = Color3.fromRGB(84, 72, 66), EmptyRim = Color3.fromRGB(36, 26, 24),
	},
	Neutral = {
		Name = "light", Body = "ink", Button = "light",
		Empty = Color3.fromRGB(214, 203, 184), EmptyRim = Color3.fromRGB(150, 126, 92),
	},
}

-- stat rows on the card body (DisplayStats keys, 5 segments each); Alt = second icon part when the first is missing
local STAT_ROWS = {
	{ Key = "HP", Label = "체력", Icon = "IconHeart", Emoji = "❤", Fill = Color3.fromRGB(255, 196, 40) },
	{ Key = "Atk", Label = "공격", Icon = "IconAttack", Alt = "IconSword", Emoji = "⚔", Fill = Color3.fromRGB(246, 118, 32) },
	{ Key = "Spd", Label = "속도", Icon = "IconBoot", Emoji = "👟", Fill = Color3.fromRGB(52, 124, 236) },
}

-- fallbacks (A6 / A7-4), used only if Config lacks the entries
local NEUTRAL_CLASS_NAMES = { Warrior = "대장장이", Mage = "연금술사", Archer = "사냥꾼" }
local PICK_LINES = {
	Warrior = "가까이 붙어서 주변을 한 번에 쾅",
	Mage = "조금 떨어져서 넓게 펑",
	Archer = "멀리서 하나씩 슝",
}
local CLASS_ICONS = { Warrior = "🗡️", Mage = "🔮", Archer = "🏹" }

local T = {
	Title = "직업을 골라요!",
	Choose = "이 직업으로!",
	Wait = "잠깐만요...",
	Recommend = "처음이면 추천",
	StartWeaponF = "시작 무기: %s",
	Male = "남",
	Female = "여",
	-- same rule as ClassService.onChangeClass / Panels "직업 변경": free = back to Lv 1, ticket = level kept
	Footer = "직업은 나중에 메뉴 > 직업 변경에서 바꿀 수 있어요 (무료: Lv1부터 다시 / 변경권: 레벨 유지)",
}

local DEFAULT_THEME = {
	Text = Color3.new(1, 1, 1),
	SubText = Color3.fromRGB(200, 200, 210),
	Gold = Color3.fromRGB(255, 210, 60),
	Font = Enum.Font.GothamBold,
}
local CARD_BG = Color3.fromRGB(34, 36, 52)
local DIM_BG = Color3.fromRGB(40, 26, 14) -- light warm dim (mockup: bright blurred town behind the cards)
local DARK_TEXT = Color3.fromRGB(30, 26, 18)
local DISABLED = Color3.fromRGB(70, 70, 80)
local BUTTON_COLOR = Color3.fromRGB(44, 150, 82)

------------------------------------------------------------------ state
local C = nil
local UIKit = nil
local theme = table.clone(DEFAULT_THEME)

local fallbackGui = nil
local root, cardsRow = nil, nil
local head = {} -- header widgets: Shield, ShieldDisc, Ribbon, Title, Pill, Sel, M, F
local note = {} -- bottom note: Frame, Icon, Text
local cards = {} -- art cards: [classId] = { Card, Scale, Bg, Clip, Holder, Char, Emoji, Crop, Name, Desc, Rows, Shade, Label, Hit, ... }
local oldCards = {} -- code-styled cards (IMG-R4), built on demand: [classId] = { Card, Stroke, Icon, Name, ..., Button }
local classIds = {}
local mode = "art" -- "art", or "old" when the current faction's card art / layout is missing
local gender = "M" -- 남 / 여 portraits; cosmetic only, kept for the session
local built = false
local visible = false
local lockedUntil = 0
local shownFaction = nil
local prevClassChosen = nil
local introPlayed = false
local lastWarnAt = -math.huge
local cameraConn = nil
local scaleConn = nil
local blur = nil
local bobTweens = {}

------------------------------------------------------------------ helpers
-- Config.Text[key] when G1 provides it (addendum A7-4 keys), else the private fallback format
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

local function myFaction()
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function factionColor(id)
	local f = Config.Factions[id]
	if type(f) == "table" then
		if typeof(f.Color) == "Color3" then return f.Color end
		if typeof(f.TeamColor) == "BrickColor" then return f.TeamColor.Color end
	end
	if id == "Neutral" then return NEUTRAL_COLOR end
	return Color3.fromRGB(200, 200, 200)
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
	fallbackGui.Name = "ClassPickerGui"
	fallbackGui.ResetOnSpawn = false
	fallbackGui.IgnoreGuiInset = true
	fallbackGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fallbackGui.DisplayOrder = 12
	fallbackGui.Parent = pg
	Util.Warn(TAG, "UIKit.Gui missing; using a fallback ScreenGui")
	return fallbackGui
end

-- virtual canvas (w, h) inside the UIScale'd gui, the first safe Y below the top bar (H4) and the UIScale itself
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
	l.TextSize = math.max(l.TextSize, LAY.FixedTextMin) -- CR-L40 (the TextLabel default is 14)
	constrainText(l, maxText)
	l.Parent = parent
	return l
end

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

local function toast(text, kind, duration)
	if UIKit and type(UIKit.Toast) == "function" then
		local ok, err = pcall(UIKit.Toast, text, kind, duration)
		if not ok then warnThrottled("toast failed: " .. tostring(err)) end
	end
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
		return TextService:GetTextSize(text, size, font, Vector2.new(math.max(1, width), 10000))
	end)
	if ok and typeof(v) == "Vector2" then return v.Y, v.X end
	-- rough estimate: Korean glyphs are about 1 em wide
	local chars = utf8.len(text) or #text
	local perLine = math.max(1, math.floor(width / size))
	return math.ceil(chars / perLine) * size * 1.25, math.min(width, chars * size)
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

local function tween(obj, t, props, style, dir)
	if not obj or not obj.Parent then return end
	local ok, tw = pcall(function()
		return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
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
	l.Text = ""
	l.TextScaled = true
	l.TextWrapped = true
	l:SetAttribute("PickerFit", true)
	if clipped then l.Size = UDim2.fromScale(1, 1) end
	l.ZIndex = z or 1
	constrainText(l, 64)
	l.Parent = parent
	return l
end

local function bindArtText(label)
	if UIKit and type(UIKit.BindArtText) == "function" then pcall(UIKit.BindArtText, label) end
	return label
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

-- storybook text look (same colours as UIKit.InkText / LightText): "ink" or "light" + a UIStroke "Outline"
local function styleText(label, style, thickness)
	local ink = style ~= "light"
	label.TextColor3 = ink and artColor("Ink", Color3.fromRGB(66, 40, 18)) or artColor("Light", Color3.new(1, 1, 1))
	local st = label:FindFirstChild("Outline")
	if not (st and st:IsA("UIStroke")) then
		st = Instance.new("UIStroke")
		st.Name = "Outline"
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		st.Parent = label
	end
	st.Color = ink and artColor("InkOutline", Color3.fromRGB(255, 247, 228)) or artColor("TextOutline", Color3.fromRGB(34, 20, 10))
	st.Transparency = ink and 0.3 or 0
	st.Thickness = thickness or (ink and (tonumber(ART.OutlineInk) or 1) or (tonumber(ART.OutlineLight) or 1.5))
	label:SetAttribute("PickerOutlineThickness", st.Thickness)
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

-- Config.Classes[id].DisplayStats[key] on the 0..5 scale (3 when missing)
local function statValue(id, key)
	local def = Config.Classes[id]
	local ds = def and def.DisplayStats
	local v = type(ds) == "table" and tonumber(ds[key]) or 3
	return math.clamp(math.floor(v + 0.5), 0, 5)
end

------------------------------------------------------------------ intro toasts
local function playIntro()
	local lines = Config.Story.Intro
	-- CR-L29: 장인 길드 stays out of the war and PvP, so it gets the intro without the "help your side" call
	if myFaction() == "Neutral" and type(Config.Story.IntroNeutral) == "table" then lines = Config.Story.IntroNeutral end
	if type(lines) ~= "table" then return end
	task.spawn(function()
		for i, line in lines do
			if i > 1 then task.wait(INTRO_STEP) end
			if not player.Parent then return end
			toast(tostring(line), "info", INTRO_DURATION)
		end
	end)
end

-- ClassChosen flipping false -> true during this session, still at Lv 1 -> intro (once)
local function onClassChosenChanged()
	local now = player:GetAttribute("ClassChosen")
	if prevClassChosen == false and now == true and not introPlayed then
		local level = player:GetAttribute("Level")
		if (type(level) == "number" and level or 1) <= 1 then
			introPlayed = true
			playIntro()
		end
	end
	prevClassChosen = now
end

------------------------------------------------------------------ buttons / texts
-- hover lift / press-shrink / glow or lock shade of one art card
local function cardVisual(c)
	local now = os.clock()
	local disabled = now < lockedUntil
	local target = 1
	if not disabled then
		if c.Down then
			target = LAY.PressScale
		elseif c.Hover then
			target = LAY.HoverScale
		end
	end
	if now >= c.PopUntil then -- the open pop-in owns the scale until it ends
		tween(c.Scale, 0.08, { Scale = target })
	end
	if disabled then
		c.Shade.BackgroundColor3 = Color3.new(0, 0, 0)
		c.Shade.BackgroundTransparency = 0.6
	elseif c.Hover or c.Down then
		c.Shade.BackgroundColor3 = Color3.new(1, 1, 1)
		c.Shade.BackgroundTransparency = c.Down and 0.7 or 0.78
	else
		c.Shade.BackgroundTransparency = 1
	end
end

local function refreshButtons()
	local enabled = os.clock() >= lockedUntil
	for _, c in cards do
		c.Hit:SetAttribute("Disabled", not enabled)
		c.Label.Text = enabled and T.Choose or T.Wait
		c.Label.TextTransparency = enabled and 0 or 0.35
		if not enabled then c.Down = false end
		cardVisual(c)
	end
	for _, c in oldCards do
		local btn = c.Button
		btn.Text = enabled and T.Choose or T.Wait
		btn.AutoButtonColor = false
		btn:SetAttribute("Disabled", not enabled)
		btn.BackgroundColor3 = enabled and BUTTON_COLOR or BUTTON_COLOR:Lerp(DISABLED, 0.7)
		btn.TextTransparency = enabled and 0 or 0.4
	end
end

local function choose(id)
	if os.clock() < lockedUntil then return end
	if not ClassPicker.IsOpen() then return end
	lockedUntil = os.clock() + CLICK_LOCK
	refreshButtons()
	fire("ChooseClass", id, gender)
	task.delay(CLICK_LOCK + 0.05, function()
		if built then refreshButtons() end
	end)
end

-- character art for the chosen gender (the other gender when that one is missing; nil = class emoji)
local function refreshPortraits()
	local faction = shownFaction or myFaction()
	local other = gender == "M" and "F" or "M"
	for id, c in cards do
		local base = "Char" .. faction .. id
		local img = artId(base .. gender) or artId(base .. other)
		c.Char.Image = img or ""
		c.Char.Visible = img ~= nil
		c.Emoji.Visible = img == nil
	end
end

local function refreshGender()
	if not head.Pill then return end
	head.Sel.BackgroundColor3 = factionColor(shownFaction or myFaction())
	tween(head.Sel, 0.12, { Position = UDim2.fromScale(gender == "M" and 0.25 or 0.75, 0.5) })
	for g, b in { M = head.M, F = head.F } do
		local on = gender == g
		styleText(b, on and "light" or "ink", on and 1.5 or 1)
		b.TextTransparency = on and 0 or 0.35
	end
end

local function setGender(g)
	if g ~= "M" and g ~= "F" then return end
	gender = g
	refreshGender()
	refreshPortraits()
end

------------------------------------------------------------------ build: header / note
-- one half of the pill; the box grows outward (left for 남, right for 여) on layout and a UIPadding "HitPad" keeps the
-- text centred on its visible half, so the touch target can be bigger than the pill (CR-L41)
local function genderButton(pill, g, text)
	local b = Instance.new("TextButton")
	b.Name = g == "M" and "Male" or "Female"
	b.AnchorPoint = Vector2.new(g == "M" and 1 or 0, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.5)
	b.Size = UDim2.fromScale(0.5, 1)
	local pad = Instance.new("UIPadding")
	pad.Name = "HitPad"
	pad.Parent = b
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Font = artFont("Title", Enum.Font.GothamBlack)
	b.Text = text
	b.TextScaled = false
	b.TextSize = 16
	b.ZIndex = 3
	constrainText(b, 40)
	b.Parent = pill
	bindArtText(b)
	b.Activated:Connect(function()
		if gender == g then return end
		playClick()
		local ok, err = pcall(setGender, g)
		if not ok then warnThrottled("gender toggle error: " .. tostring(err)) end
	end)
	return b
end

local function buildHeader()
	-- faction shield (the art for the shown faction is set in applyFaction; a coloured disc without it)
	local shield = newImage(root, "Shield", 3)
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.78, 0.78)
	disc.BorderSizePixel = 0
	disc.Visible = false
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(0.5, 0)
	dc.Parent = disc
	local ds = Instance.new("UIStroke")
	ds.Color = artColor("Gold", theme.Gold)
	ds.Thickness = 3
	ds.Parent = disc
	disc.Parent = shield
	head.Shield, head.ShieldDisc = shield, disc

	-- "직업을 골라요!" on the empty title ribbon (code ribbon without the art)
	local ribbon = newImage(root, "TitleRibbon", 2)
	local ribbonId = artId("TitleRibbon")
	ribbon.Image = ribbonId or ""
	if not ribbonId then
		local plain = Instance.new("Frame")
		plain.Name = "Plain"
		plain.AnchorPoint = Vector2.new(0.5, 0.5)
		plain.Position = UDim2.fromScale(0.5, 0.42)
		plain.Size = UDim2.fromScale(1, 0.8)
		plain.BackgroundColor3 = artColor("Ribbon", Color3.fromRGB(241, 207, 132))
		plain.BorderSizePixel = 0
		corner(plain, 12)
		local st = Instance.new("UIStroke")
		st.Color = artColor("Rim", Color3.fromRGB(110, 66, 24))
		st.Thickness = 2
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = plain
		plain.Parent = ribbon
	end
	local title = artLabel(ribbon, "Title", 2, artFont("Title", Enum.Font.GothamBlack))
	title.Text = T.Title
	local tr = LAY.TitleText
	title.Position = UDim2.fromScale(tr[1], tr[2])
	title.Size = UDim2.fromScale(tr[3], tr[4])
	styleText(title, "ink", 2)
	bindArtText(title)
	head.Ribbon, head.Title = ribbon, title

	-- 남 | 여 pill (cosmetic: swaps the portraits)
	local pill = sliceFrame(root, "GenderPill", "Pill", 3)
	local sel = Instance.new("Frame")
	sel.Name = "Selected"
	sel.AnchorPoint = Vector2.new(0.5, 0.5)
	sel.Position = UDim2.fromScale(0.25, 0.5)
	sel.Size = UDim2.new(0.5, -6, 0.72, 0)
	sel.BorderSizePixel = 0
	sel.ZIndex = 2
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0.5, 0)
	sc.Parent = sel
	sel.Parent = pill
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.Position = UDim2.fromScale(0.5, 0.5)
	divider.Size = UDim2.new(0, 2, 0.5, 0)
	divider.BackgroundColor3 = artColor("Rim", Color3.fromRGB(110, 66, 24))
	divider.BackgroundTransparency = 0.4
	divider.BorderSizePixel = 0
	divider.ZIndex = 1
	divider.Parent = pill
	head.Pill, head.Sel = pill, sel
	head.M = genderButton(pill, "M", T.Male)
	head.F = genderButton(pill, "F", T.Female)
end

local function buildNote()
	local f = sliceFrame(root, "Note", "PanelParchment", 2)
	local icon = newImage(f, "Icon", 1)
	icon.Image = artId("IconScroll") or ""
	local text = artLabel(f, "Text", 1)
	text.TextScaled = false
	text.Text = T.Footer
	styleText(text, "ink")
	note.Frame, note.Icon, note.Text = f, icon, text
end

------------------------------------------------------------------ build: art cards
local function buildStatRow(parent, def)
	local row = Instance.new("Frame")
	row.Name = "Stat_" .. def.Key
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = true
	row.ZIndex = 4
	row.Parent = parent
	local icon = newImage(row, "Icon", 1)
	icon.Image = artId(def.Icon) or (def.Alt and artId(def.Alt)) or ""
	local emoji = artLabel(row, "Emoji", 1, theme.Font)
	emoji.Text = def.Emoji
	emoji.Visible = icon.Image == ""
	local label = artLabel(row, "Label", 1, nil, true)
	label.TextScaled = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = def.Label
	local segs = {}
	for k = 1, 5 do
		local seg = Instance.new("Frame")
		seg.Name = "Seg" .. k
		seg.BorderSizePixel = 0
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.4, 0)
		cr.Parent = seg
		local st = Instance.new("UIStroke")
		st.Name = "Rim"
		st.Thickness = 1
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = seg
		local gr = Instance.new("UIGradient") -- soft top-lit shading like the mockup's glossy segments
		gr.Rotation = 90
		gr.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))
		gr.Parent = seg
		seg.Parent = row
		segs[k] = seg
	end
	return { Frame = row, Icon = icon, Emoji = emoji, Label = label, Segs = segs, Def = def }
end

-- invisible hit button over the baked art button: press-shrink + hover glow on the card, Click sound, choose(id)
local function wireCard(c, id)
	local hit = c.Hit
	local function isPress(input)
		local t = input.UserInputType
		return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
	end
	hit.MouseEnter:Connect(function()
		c.Hover = true
		cardVisual(c)
	end)
	hit.MouseLeave:Connect(function()
		c.Hover = false
		c.Down = false
		cardVisual(c)
	end)
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
	hit.Activated:Connect(function()
		if hit:GetAttribute("Disabled") == true or os.clock() < lockedUntil then return end
		playClick()
		local ok, err = pcall(choose, id)
		if not ok then Util.Warn(TAG, "button handler error: " .. tostring(err)) end
	end)
end

-- small parchment chip (Pill art) with ink text; tint = gold badge
local function buildChip(parent, name, text, tint)
	local chip = sliceFrame(parent, name, "Pill", 5)
	if tint then
		if chip:IsA("ImageLabel") then
			chip.ImageColor3 = tint
		else
			chip.BackgroundColor3 = tint
		end
	end
	local label = artLabel(chip, "Text", 1, artFont("Title", Enum.Font.GothamBlack))
	label.TextScaled = false
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	styleText(label, "ink")
	return chip, label
end

local function buildArtCard(id)
	local def = Config.Classes[id]
	local card = Instance.new("Frame")
	card.Name = "Card_" .. id
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	local scale = Instance.new("UIScale")
	scale.Name = "CardScale"
	scale.Parent = card

	-- card background (the box keeps the image aspect, so Stretch is exact)
	local bg = newImage(card, "Bg", 1)
	bg.ScaleType = Enum.ScaleType.Stretch
	bg.Size = UDim2.fromScale(1, 1)

	-- character in the alcove, waist-up like the mockup (bobs while open); emoji when the art is missing.
	-- The clip ends inside the name ribbon, so the legs never draw over the body panel
	local clip = Instance.new("Frame")
	clip.Name = "PortraitClip"
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.ZIndex = 2
	clip.Parent = card
	local holder = Instance.new("Frame")
	holder.Name = "Portrait"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ZIndex = 2
	holder.Parent = clip
	local char = newImage(holder, "Character", 1)
	char.AnchorPoint = Vector2.new(0.5, 1)
	char.Position = UDim2.fromScale(0.5, 1)
	char.Size = UDim2.fromScale(1, 1)
	local emoji = artLabel(holder, "Emoji", 1, theme.Font)
	emoji.AnchorPoint = Vector2.new(0.5, 0.5)
	emoji.Position = UDim2.fromScale(0.5, 0.5)
	emoji.Size = UDim2.fromScale(1, 0.7)
	emoji.Text = CLASS_ICONS[id] or ""
	emoji.Visible = false

	-- the card's own name ribbon drawn again in front of the character's feet (same image, ImageRect = Name region)
	local crop = newImage(card, "RibbonFront", 3)
	crop.ScaleType = Enum.ScaleType.Stretch

	local name = artLabel(card, "ClassName", 4, artFont("Title", Enum.Font.GothamBlack))
	bindArtText(name)
	local desc = artLabel(card, "Desc", 4, nil, true)
	local rows = {}
	for i, rowDef in STAT_ROWS do
		rows[i] = buildStatRow(card, rowDef)
	end

	-- hover glow / lock shade over the baked button, its label and the invisible hit area
	local shade = Instance.new("Frame")
	shade.Name = "ButtonGlow"
	shade.BackgroundColor3 = Color3.new(1, 1, 1)
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.ZIndex = 4
	local shc = Instance.new("UICorner")
	shc.CornerRadius = UDim.new(0.5, 0)
	shc.Parent = shade
	shade.Parent = card
	local label = artLabel(card, "ChooseLabel", 5, artFont("Title", Enum.Font.GothamBlack))
	label.Text = T.Choose
	bindArtText(label)
	local hit = Instance.new("TextButton")
	hit.Name = "ChooseButton"
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.AutoButtonColor = false
	hit.Text = ""
	hit.ZIndex = 6
	constrainText(hit, 15) -- empty, but every TextButton carries the M1 constraint
	hit.Parent = card

	-- A7-4: generic class chip ("전사") and the Warrior's "처음이면 추천" badge
	local chip, chipText = buildChip(card, "GenericChip", genericClassName(id), nil)
	local badge, badgeText = nil, nil
	if id == RECOMMENDED then
		badge, badgeText = buildChip(card, "RecommendBadge", cfgFmt("FirstTimeRecommend", T.Recommend),
			Color3.fromRGB(255, 214, 92))
	end

	local c = {
		Card = card, Scale = scale, Bg = bg, Clip = clip, Holder = holder, Char = char, Emoji = emoji, Crop = crop,
		Name = name, Desc = desc, Rows = rows, Shade = shade, Label = label, Hit = hit,
		Chip = chip, ChipText = chipText, Badge = badge, BadgeText = badgeText,
		DescFull = (def and type(def.Desc) == "string" and def.Desc ~= "") and def.Desc or pickLine(id),
		DescShort = pickLine(id),
		Hover = false, Down = false, PopUntil = 0,
	}
	wireCard(c, id)
	card.Parent = cardsRow
	cards[id] = c
end

------------------------------------------------------------------ build: code-styled cards (IMG-R4 fallback)
local function buildOldCard(id, order)
	local def = Config.Classes[id]
	local card = Instance.new("Frame")
	card.Name = "OldCard_" .. id
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = CARD_BG
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	corner(card, 14)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = theme.Gold
	st.Thickness = (id == RECOMMENDED) and 4 or 2
	st.Parent = card

	local icon = newLabel(card, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = CLASS_ICONS[id] or "",
		TextScaled = true,
		Font = theme.Font,
	}, 56)
	local name = newLabel(card, {
		Name = "ClassName",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
		TextScaled = true,
		TextColor3 = theme.Gold,
		Font = theme.Font,
	}, 30)
	bindArtText(name)
	local generic = newLabel(card, {
		Name = "Generic",
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "(" .. genericClassName(id) .. ")",
		TextScaled = true,
		TextColor3 = theme.SubText,
	}, 18)

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

	if id == RECOMMENDED then
		local badge = listText(scroll, cfgFmt("FirstTimeRecommend", T.Recommend), 15, DARK_TEXT, 1, theme.Font)
		badge.Name = "RecommendBadge"
		badge.BackgroundColor3 = theme.Gold
		badge.BackgroundTransparency = 0
		corner(badge, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = badge
	end
	listText(scroll, pickLine(id), 19, theme.Gold, 2, theme.Font)
	listText(scroll, def.Desc or "", 15, theme.Text, 3)
	if type(def.Stats) == "table" then
		local lines = {}
		for _, s in def.Stats do
			table.insert(lines, "• " .. tostring(s))
		end
		listText(scroll, table.concat(lines, "\n"), 15, theme.SubText, 4)
	end
	local weapon = listText(scroll, "", 15, theme.SubText, 5)

	local btn = makeButton(card, T.Choose, BUTTON_COLOR, contrastText(BUTTON_COLOR), function()
		choose(id)
	end)
	btn.AnchorPoint = Vector2.new(0.5, 1)
	bindArtText(btn)

	card.Parent = cardsRow
	oldCards[id] = {
		Card = card, Stroke = st, Icon = icon, Name = name, Generic = generic,
		Scroll = scroll, Weapon = weapon, Button = btn,
	}
end

local function layoutOldCard(c, compact, s)
	local hh = compact and 70 or 104 -- header: icon + name + generic
	-- choose button, at least TouchTarget real px tall after the UIScale (CR-L41)
	local bh = math.max(compact and 44 or 54, math.ceil(LAY.TouchTarget / math.max(s or 1, 0.05)))
	local iconH = math.floor(hh * 0.42)
	local nameH = math.floor(hh * 0.33)
	local genH = math.floor(hh * 0.2)
	c.Icon.Position = UDim2.new(0.5, 0, 0, 6)
	c.Icon.Size = UDim2.new(1, -16, 0, iconH)
	c.Name.Position = UDim2.new(0.5, 0, 0, 6 + iconH)
	c.Name.Size = UDim2.new(1, -16, 0, nameH)
	c.Generic.Position = UDim2.new(0.5, 0, 0, 6 + iconH + nameH)
	c.Generic.Size = UDim2.new(1, -16, 0, genH)
	c.Scroll.Position = UDim2.new(0, 10, 0, hh + 10)
	c.Scroll.Size = UDim2.new(1, -20, 1, -(hh + 10 + bh + 20))
	c.Button.Position = UDim2.new(0.5, 0, 1, -10)
	c.Button.Size = UDim2.new(1, -24, 0, bh)
end

------------------------------------------------------------------ faction-dependent look
-- faction texts on the code-styled cards (names, weapon, accent)
local function fillOldTexts(faction)
	local accent = factionColor(faction)
	for id, c in oldCards do
		c.Name.Text = className(id, faction)
		c.Weapon.Text = string.format(T.StartWeaponF, Config.WeaponName(1, id, faction))
		c.Stroke.Color = accent
	end
end

-- card art, shield, names, text styles and segment colours for the player's faction (art or IMG-R4 cards)
local function applyFaction()
	local faction = myFaction()
	shownFaction = faction
	local key = "ClassCard" .. faction
	local cardId = artId(key)
	-- IMG-R4: art cards only with the image AND every measured region (a missing Name region would crop nothing and
	-- draw the whole card image over the character)
	local L = Art.Layout[key]
	local complete = type(L) == "table"
	if complete then
		for _, r in { "Portrait", "Name", "Body", "Button" } do
			if type(L[r]) ~= "table" then complete = false end
		end
	end
	mode = (cardId ~= nil and complete) and "art" or "old"

	local shieldId = artId("Shield" .. faction)
	head.Shield.Image = shieldId or ""
	head.ShieldDisc.Visible = shieldId == nil
	head.ShieldDisc.BackgroundColor3 = factionColor(faction)
	refreshGender()

	if mode == "art" then
		local style = CARD_STYLE[faction] or CARD_STYLE.Halo
		for id, c in cards do
			c.Card.Visible = true
			c.Bg.Image = cardId
			c.Crop.Image = cardId
			c.Name.Text = className(id, faction)
			styleText(c.Name, style.Name)
			styleText(c.Desc, style.Body)
			styleText(c.Label, style.Button, 2)
			for _, row in c.Rows do
				styleText(row.Label, style.Body)
				local value = statValue(id, row.Def.Key)
				for k, seg in row.Segs do
					local filled = k <= value
					seg.BackgroundColor3 = filled and row.Def.Fill or style.Empty
					seg.Rim.Color = filled and row.Def.Fill:Lerp(Color3.new(0, 0, 0), 0.4) or style.EmptyRim
				end
			end
		end
		for _, c in oldCards do
			c.Card.Visible = false
		end
	else
		for i, id in classIds do
			if not oldCards[id] then buildOldCard(id, i) end
		end
		fillOldTexts(faction)
		for _, c in oldCards do
			c.Card.Visible = true
		end
		for _, c in cards do
			c.Card.Visible = false
		end
	end
	refreshPortraits()
end

------------------------------------------------------------------ layout
-- [shield][title ribbon][남|여] centred under the top bar; returns nothing
local function layoutHeader(w, top, headH, minT, s)
	local rs = partSize("TitleRibbon")
	local ribbonAspect = rs and rs.X / rs.Y or 4
	local ss = partSize("Shield" .. (shownFaction or "Halo"))
	local shieldAspect = ss and ss.X / ss.Y or 1
	local shieldH = headH
	local shieldW = shieldH * shieldAspect
	local overlap = shieldW * 0.35 -- the shield sits on the ribbon's left tail like the mockup
	local pillH = math.max(minT + 10, math.floor(headH * 0.56))
	local pillW = math.floor(pillH * 2.4)
	local gap = 10
	local ribbonH = headH * 0.92
	local ribbonW = ribbonH * ribbonAspect
	local avail = w - 2 * LAY.Gutter
	if shieldW - overlap + ribbonW + gap + pillW > avail then
		ribbonW = math.max(120, avail - (shieldW - overlap) - gap - pillW)
		ribbonH = math.min(ribbonH, ribbonW / ribbonAspect)
	end
	local total = shieldW - overlap + ribbonW + gap + pillW
	local x0 = (w - total) / 2
	local cy = top + headH / 2
	place(head.Shield, x0, cy - shieldH / 2, shieldW, shieldH)
	local rx = x0 + shieldW - overlap
	place(head.Ribbon, rx, cy - ribbonH / 2, ribbonW, ribbonH)
	setTextRange(head.Title, minT, ribbonH * 0.44)
	place(head.Pill, rx + ribbonW + gap, cy - pillH / 2, pillW, pillH)
	-- hit areas taller / wider than the pill so a thumb can hit them (CR-L41); they grow outward, never across the middle
	local target = math.ceil(LAY.TouchTarget / s)
	local hitH = math.max(pillH, target)
	local extraW = math.max(0, target - pillW / 2)
	local textSize = math.max(minT, math.floor(pillH * 0.52))
	head.M.Size = UDim2.new(0.5, extraW, 0, hitH)
	head.M.HitPad.PaddingLeft = UDim.new(0, extraW)
	head.F.Size = UDim2.new(0.5, extraW, 0, hitH)
	head.F.HitPad.PaddingRight = UDim.new(0, extraW)
	for _, b in { head.M, head.F } do
		setTextRange(b, minT, textSize)
	end
end

-- parchment note at the bottom; returns its top Y
local function layoutNote(w, h, minT)
	local size = math.clamp(math.floor(h * 0.026), minT, math.max(minT, 20))
	local iconW = math.floor(size * 1.7)
	local padX = math.floor(size * 0.8)
	local maxTextW = w - 2 * LAY.Gutter - iconW - padX * 2 - 6
	local th, tw = textBounds(T.Footer, size, note.Text.Font, maxTextW)
	local textW = math.min(maxTextW, tw + size) -- one glyph of slack so the measured line never re-wraps
	local noteH = math.ceil(th + size * 0.9)
	local noteW = padX * 2 + iconW + 6 + textW
	local y = h - 10 - noteH
	place(note.Frame, (w - noteW) / 2, y, noteW, noteH)
	place(note.Icon, padX, (noteH - iconW) / 2, iconW, iconW)
	note.Icon.Visible = note.Icon.Image ~= ""
	local tx = note.Icon.Visible and (padX + iconW + 6) or padX
	place(note.Text, tx, 0, textW, noteH)
	setTextRange(note.Text, minT, size)
	return y
end

-- one art card: everything sits in the measured CardLayout regions of the card image
local function layoutArtCard(c, L, img, W, H, minT, s)
	local px, py, pw, ph = region(L.Portrait, W, H)
	local nx, ny, nw, nh = region(L.Name, W, H)
	local bx, by, bw, bh = region(L.Body, W, H)
	local kx, ky, kw, kh = region(L.Button, W, H)

	-- character from just under the arch top, its belt line (LAY.CharHip) on the ribbon: the clip ends inside the ribbon
	-- and the ribbon crop covers the cut, so only the upper body shows (mockup UI_Class_A: waist-up hero shot)
	local top = py + ph * 0.02
	local hip = ny + nh * 0.3
	local hh = math.max(H * 0.2, (hip - top) / LAY.CharHip)
	place(c.Clip, 0, 0, W, ny + nh * 0.45)
	c.Holder.Position = UDim2.fromOffset(px + pw / 2, top + hh)
	c.Holder.Size = UDim2.fromOffset(math.max(W, hh), hh) -- wider than any figure (aspect <= 1): Fit keeps the feet at the bottom
	c.Emoji.Position = UDim2.fromScale(0.5, LAY.CharHip / 2)
	c.Emoji.Size = UDim2.fromScale(1, LAY.CharHip * 0.8)
	setTextRange(c.Emoji, minT, hh * LAY.CharHip * 0.6)
	local r = L.Name
	if type(r) == "table" then
		c.Crop.ImageRectOffset = Vector2.new((r[1] or 0) * img.X, (r[2] or 0) * img.Y)
		c.Crop.ImageRectSize = Vector2.new((r[3] or 1) * img.X, (r[4] or 1) * img.Y)
	end
	place(c.Crop, nx, ny, nw, nh)

	-- name ribbon (nearly the whole measured band: "그림자 사냥꾼" must stay on one line on a phone)
	place(c.Name, nx + nw * 0.02, ny + nh * 0.07, nw * 0.96, nh * 0.86)
	setTextRange(c.Name, minT, nh * 0.74)

	-- body: description (PickLine when the description cannot fit at the min size) + 3 stat rows
	local ix, iw = bx + bw * 0.07, bw * 0.86
	local descH = bh * 0.42
	local descW = bw * 0.94 -- wider than the rows: on a phone the Horns panel only fits 2 lines this way
	place(c.Desc, bx + bw * 0.03, by + bh * 0.03, descW, descH)
	local text = c.DescFull
	if c.DescShort ~= "" and textBounds(text, minT, c.Desc.Font, descW) > descH then text = c.DescShort end
	c.Desc.Text = text
	setTextRange(c.Desc, minT, math.clamp(math.floor(H * 0.046), minT, math.max(minT, 24)))

	local rowH = (bh * 0.5) / math.max(1, #c.Rows)
	local labelSize = math.clamp(math.floor(rowH * 0.66), minT, math.max(minT, 22))
	for i, row in c.Rows do
		place(row.Frame, ix, by + bh * 0.48 + (i - 1) * rowH, iw, rowH)
		local icon = math.min(rowH * 0.92, iw * 0.14)
		place(row.Icon, 0, (rowH - icon) / 2, icon, icon)
		place(row.Emoji, 0, (rowH - icon) / 2, icon, icon)
		setTextRange(row.Emoji, minT, icon)
		local lx = icon + rowH * 0.2
		local lw = labelSize * 2.3
		place(row.Label, lx, 0, lw, rowH)
		setTextRange(row.Label, minT, labelSize)
		local sx = lx + lw + rowH * 0.1
		local sw = math.max(10, iw - sx)
		local sgap = math.max(2, sw * 0.035)
		local segW = (sw - sgap * 4) / 5
		local segH = math.max(6, rowH * 0.56)
		for k, seg in row.Segs do
			place(seg, sx + (k - 1) * (segW + sgap), (rowH - segH) / 2, segW, segH)
		end
	end

	-- button: glow, label, and a hit area at least TouchTarget real px tall, kept inside the card
	place(c.Shade, kx + kw * 0.03, ky + kh * 0.08, kw * 0.94, kh * 0.84)
	place(c.Label, kx + kw * 0.1, ky + kh * 0.12, kw * 0.8, kh * 0.72)
	setTextRange(c.Label, minT, kh * 0.62)
	local hitH = math.min(math.max(kh * 1.2, LAY.TouchTarget / s), H * 0.2)
	local hitW = math.min(W, kw * 1.08)
	local hitY = math.min(ky + kh / 2 - hitH / 2, H - hitH)
	place(c.Hit, kx + kw / 2 - hitW / 2, hitY, hitW, hitH)

	-- chips: generic class at the alcove's bottom-left (resting on the ribbon, clear of the shield / orb / bow that the
	-- characters hold on the right), badge over the top ornament
	local chipT = math.max(minT, math.floor(nh * 0.48))
	local chipH = math.floor(chipT * 1.5)
	local function chipW(label)
		return (utf8.len(label.Text) or #label.Text) * chipT * 1.02 + chipH * 0.9
	end
	local gw = math.min(chipW(c.ChipText), pw * 0.6)
	place(c.Chip, px + pw * 0.03, ny - chipH * 0.85, gw, chipH)
	setTextRange(c.ChipText, minT, chipT)
	if c.Badge then
		local bw2 = math.min(chipW(c.BadgeText), W * 0.9)
		place(c.Badge, (W - bw2) / 2, H * 0.012, bw2, chipH)
		setTextRange(c.BadgeText, minT, chipT)
	end
end

-- three art cards in a row; scaled to fit, or a sideways ScrollingFrame when they would get too small
local function layoutArtCards(w, cardsTop, cardsBottom, minT, s)
	local key = "ClassCard" .. (shownFaction or "Halo")
	local L = type(Art.Layout[key]) == "table" and Art.Layout[key] or {} -- {} = whole-card regions (never nil-indexed)
	local img = partSize(key) or Vector2.new(640, 1024)
	local aspect = img.X / img.Y
	local n = math.max(1, #classIds)
	local availW = w - 2 * LAY.Gutter
	local availH = math.max(120, cardsBottom - cardsTop)
	local gap = math.clamp(math.floor(w * 0.015), 10, 28)
	local cardH = math.min(availH / (1 + 2 * LAY.Lift), LAY.CardMaxH)
	local scroll = false
	if n * cardH * aspect + (n - 1) * gap + 2 * cardH * LAY.Lift > availW then
		local fitH = (availW - (n - 1) * gap) / (n * aspect + 2 * LAY.Lift)
		local minH = math.max(LAY.CardMinH, 20 * minT)
		if fitH >= minH then
			cardH = fitH
		else
			cardH = math.min(cardH, minH)
			scroll = true
		end
	end
	cardH = math.floor(cardH)
	local cardW = math.floor(cardH * aspect)
	local lift = math.ceil(cardH * LAY.Lift)
	local canvasW = n * cardW + (n - 1) * gap + 2 * lift
	local frameH = cardH + 2 * lift
	cardsRow.Position = UDim2.fromOffset(w / 2, cardsTop + math.max(0, (availH - frameH) / 2))
	cardsRow.Size = UDim2.fromOffset(scroll and availW or canvasW, frameH)
	cardsRow.CanvasSize = UDim2.fromOffset(canvasW, frameH)
	cardsRow.ScrollingEnabled = scroll
	cardsRow.ScrollBarThickness = scroll and 6 or 0
	if not scroll then cardsRow.CanvasPosition = Vector2.zero end
	for i, id in classIds do
		local c = cards[id]
		if c then
			c.Card.Position = UDim2.fromOffset(lift + (i - 1) * (cardW + gap) + cardW / 2, lift + cardH / 2)
			c.Card.Size = UDim2.fromOffset(cardW, cardH)
			layoutArtCard(c, L, img, cardW, cardH, minT, s)
		end
	end
end

-- code-styled cards (IMG-R4): same sizes as before the art pass
local function layoutOldCards(w, h, cardsTop, cardsBottom, s)
	local n = math.max(1, #classIds)
	local compact = h < 600
	local rowW = math.min(w - 24, 1100)
	local cardH = math.min(math.max(180, cardsBottom - cardsTop), 560)
	local gap = 12
	local cardW = (rowW - (n - 1) * gap) / n
	cardsRow.Position = UDim2.fromOffset(w / 2, cardsTop)
	cardsRow.Size = UDim2.fromOffset(rowW, cardH)
	cardsRow.CanvasSize = UDim2.fromOffset(rowW, cardH)
	cardsRow.ScrollingEnabled = false
	cardsRow.ScrollBarThickness = 0
	cardsRow.CanvasPosition = Vector2.zero
	for i, id in classIds do
		local c = oldCards[id]
		if c then
			c.Card.Position = UDim2.fromOffset((i - 1) * (cardW + gap) + cardW / 2, cardH / 2)
			c.Card.Size = UDim2.fromOffset(cardW, cardH)
			layoutOldCard(c, compact, s)
		end
	end
end

local function layout()
	if not root then return end
	local w, h, top, s = canvas(root.Parent)
	root.Position = UDim2.fromOffset(0, 0)
	root.Size = UDim2.fromOffset(w, h)
	local minT = minTextFor(s)
	local headH = math.clamp(math.floor(h * LAY.HeadFrac), LAY.HeadMin, LAY.HeadMax)
	layoutHeader(w, top, headH, minT, s)
	local noteTop = layoutNote(w, h, minT)
	local cardsTop = top + headH + 6
	local cardsBottom = noteTop - 6
	if mode == "art" then
		layoutArtCards(w, cardsTop, cardsBottom, minT, s)
	else
		layoutOldCards(w, h, cardsTop, cardsBottom, s)
	end
end

local function build()
	if built then return true end
	local gui = getGui()
	if not gui then return false end

	root = Instance.new("Frame")
	root.Name = "ClassPicker"
	root.BackgroundColor3 = DIM_BG
	root.BackgroundTransparency = 0.8 -- the camera blur separates the cards from the world, the dim stays light
	root.BorderSizePixel = 0
	root.Active = true
	root.ZIndex = ZINDEX
	root.Visible = false

	cardsRow = Instance.new("ScrollingFrame")
	cardsRow.Name = "Cards"
	cardsRow.AnchorPoint = Vector2.new(0.5, 0)
	cardsRow.BackgroundTransparency = 1
	cardsRow.BorderSizePixel = 0
	cardsRow.ScrollingDirection = Enum.ScrollingDirection.X
	cardsRow.ScrollBarThickness = 0
	cardsRow.ScrollBarImageColor3 = artColor("Rim", Color3.fromRGB(110, 66, 24))
	cardsRow.ScrollingEnabled = false
	cardsRow.ZIndex = 1
	cardsRow.Parent = root

	buildHeader()
	buildNote()
	table.clear(classIds)
	for _, id in Config.ClassOrder do
		if Config.Classes[id] then table.insert(classIds, id) end
	end
	for _, id in classIds do
		buildArtCard(id)
	end

	root.Parent = gui
	built = true
	if myFaction() ~= "None" then applyFaction() end -- otherwise refresh applies it when the picker opens
	layout()
	refreshButtons()
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
		blur.Name = "ClassPickerBlur"
		blur.Size = LAY.BlurSize
		blur.Parent = cam -- camera post effects are local to this client
	elseif blur then
		blur:Destroy()
		blur = nil
	end
end

local function stopBob()
	for _, tw in bobTweens do
		pcall(function()
			tw:Cancel()
		end)
	end
	table.clear(bobTweens)
end

-- idle bob of the characters + pop-in of the cards (art mode only)
local function animateOpen()
	stopBob()
	if mode ~= "art" then return end
	for i, id in classIds do
		local c = cards[id]
		if c then
			c.Char.Position = UDim2.fromScale(0.5, 1)
			local ok, tw = pcall(function()
				return TweenService:Create(c.Char, TweenInfo.new(LAY.BobTime, Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut, -1, true, (i - 1) * 0.35), { Position = UDim2.fromScale(0.5, 1 - LAY.Bob) })
			end)
			if ok and tw then
				tw:Play()
				table.insert(bobTweens, tw)
			end
			local popDelay = (i - 1) * 0.06
			c.PopUntil = os.clock() + popDelay + 0.3
			tween(c.Scale, 0.01, { Scale = 0.86 }) -- also cancels a running hover / press tween
			task.delay(popDelay + 0.02, function()
				tween(c.Scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
end

local function refresh()
	if not built and not build() then return end
	local open = ClassPicker.IsOpen()
	if open and visible and shownFaction ~= myFaction() then
		applyFaction()
		layout()
		animateOpen()
	end
	if open == visible then return end
	visible = open
	root.Visible = open
	setBlur(open)
	if open then
		applyFaction()
		layout()
		animateOpen()
		-- CR-M26: a fast second tap on the FactionPicker's "이 편으로!" lands here; ignore card input for a moment
		lockedUntil = math.max(lockedUntil, os.clock() + OPEN_LOCK)
		refreshButtons()
		task.delay(OPEN_LOCK + 0.05, function()
			if built then refreshButtons() end
		end)
		local panels = C and C.Panels
		if panels and type(panels.Close) == "function" then pcall(panels.Close) end
	else
		stopBob()
		for _, c in cards do
			c.Hover, c.Down = false, false
		end
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
	if visible then
		setBlur(false)
		setBlur(true)
	end
end

------------------------------------------------------------------ public
function ClassPicker.IsOpen()
	if player:GetAttribute("DataLoaded") ~= true then return false end
	local f = player:GetAttribute("Faction")
	if type(f) ~= "string" or f == "None" then return false end
	if player:GetAttribute("ClassChosen") ~= false then return false end
	local fp = C and C.FactionPicker
	if type(fp) == "table" and type(fp.IsOpen) == "function" then
		local ok, open = pcall(fp.IsOpen)
		if ok and open then return false end
	end
	return true
end

-- "M" / "F": the portrait gender picked on the 남|여 pill (cosmetic, this session only)
function ClassPicker.GetGender()
	return gender
end

function ClassPicker.Init(c)
	C = c
	UIKit = c and c.UIKit
	loadTheme()
	gender = player:GetAttribute("CharacterGender") == "F" and "F" or "M"
	prevClassChosen = player:GetAttribute("ClassChosen")
	player.AttributeChanged:Connect(function(name)
		if name == "CharacterGender" then
			local ok, err = pcall(setGender, player:GetAttribute("CharacterGender") == "F" and "F" or "M")
			if not ok then warnThrottled("gender error: " .. tostring(err)) end
		end
		if name == "ClassChosen" then
			local ok, err = pcall(onClassChosenChanged)
			if not ok then warnThrottled("intro error: " .. tostring(err)) end
		end
		if name == "DataLoaded" or name == "Faction" or name == "ClassChosen" then
			if built then
				local ok, err = pcall(refresh)
				if not ok then warnThrottled("refresh error: " .. tostring(err)) end
			end
		end
	end)
end

function ClassPicker.Start()
	loadTheme()
	local okBuild, errBuild = pcall(build)
	if not okBuild then warnThrottled("build error: " .. tostring(errBuild)) end
	hookCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
	local gui = root and root.Parent
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	if sc then
		scaleConn = sc:GetPropertyChangedSignal("Scale"):Connect(function()
			if built then layout() end
		end)
	end

	-- safety net: re-evaluate visibility periodically (also follows the FactionPicker closing)
	task.spawn(function()
		while true do
			task.wait(POLL_INTERVAL)
			local ok, err = pcall(refresh)
			if not ok then warnThrottled("refresh error: " .. tostring(err)) end
		end
	end)

	local ok, err = pcall(refresh)
	if not ok then warnThrottled("refresh error: " .. tostring(err)) end
	print("[ClassPicker] started")
end

return ClassPicker
