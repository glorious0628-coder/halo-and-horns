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

-- User-selected replacement from the Creator Store. Shared state keeps large HUD / Fx chunks below the local limit.
local FONT = { Id = 12187370747, UseTextImages = false, Faces = {}, States = setmetatable({}, { __mode = "k" }), MeasureCache = {}, CacheCount = 0 }
for _, weight in { Enum.FontWeight.Regular, Enum.FontWeight.Bold, Enum.FontWeight.ExtraBold } do
	local ok, face = pcall(Font.fromId, FONT.Id, weight, Enum.FontStyle.Normal)
	FONT.Faces[weight] = ok and face or Font.fromEnum(Enum.Font.GothamBold)
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
-- CR-L38: short (phone) viewports keep fewer toasts; the stack never takes more than WidthFrac of the screen width
local TOAST_PHONE = { Height = 500, Max = 2, WidthFrac = 0.45 }
local DEFAULT_TOAST_SECONDS = 2.5
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

-- Existing Enum.Font choices carry their body / title / number weight into the selected family.
local function themeFontFace(weightOrEnum)
	if typeof(weightOrEnum) == "Font" then return weightOrEnum end
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
	return FONT.Faces[weight]
end

function UIKit.ApplyFont(textObj, weightOrEnum)
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
	local face = themeFontFace(source)
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
		toastHolder.Position = UDim2.new(0.5, 0, 0, TOAST_Y + insetY() / currentScale())
		-- CR-L38: on phones the stack covered the upgrade / release buttons
		local raw = cam and cam.ViewportSize or Vector2.zero
		toastMax = (raw.Y >= 50 and raw.Y < TOAST_PHONE.Height) and TOAST_PHONE.Max or MAX_TOASTS
		local w = TOAST_WIDTH
		if raw.X >= 50 then w = math.min(TOAST_WIDTH, raw.X / currentScale() * TOAST_PHONE.WidthFrac) end
		toastHolder.Size = UDim2.fromOffset(math.floor(w), 10)
	end
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

local function pressTween(scaleObj, down)
	if not scaleObj or not scaleObj.Parent then return end
	TweenService:Create(scaleObj, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = down and 0.92 or 1,
	}):Play()
end

-- press-shrink on the child UIScale "PressScale" + Click sound; onClick(button) runs on Activated unless the button
-- has Active == false or attribute Disabled == true (shared by UIKit.Button and UIKit.ArtButton)
local function wirePress(btn, onClick)
	local pressScale = btn:FindFirstChild("PressScale")

	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			if btn.Active and btn:GetAttribute("Disabled") ~= true then
				pressTween(pressScale, true)
			end
		end
	end)
	btn.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressTween(pressScale, false)
		end
	end)
	btn.MouseLeave:Connect(function()
		pressTween(pressScale, false)
	end)
	btn.Activated:Connect(function()
		if not btn.Active or btn:GetAttribute("Disabled") == true then return end
		playClick()
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
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(math.floor(id)) .. "&w=150&h=150"
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
function UIKit.ItemIcon(id, props)
	local items = type(Config.Loot) == "table" and Config.Loot.Items or nil
	local item = type(id) == "string" and type(items) == "table" and items[id] or nil
	local key = type(item) == "table" and item.Icon or id
	local img = type(key) == "string" and UIKit.ArtImage(key, props) or nil
	if not img or type(item) ~= "table" or type(item.IconBand) ~= "string" then return img end
	local band = UIKit.ArtImage(item.IconBand, {
		Name = "Band",
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = typeof(item.Color) == "Color3" and item.Color or Color3.new(1, 1, 1),
		ZIndex = img.ZIndex,
	})
	if band then band.Parent = img end
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

-- Designated picker labels only. Start at the layout's maximum and shrink from rendered TextBounds. A label
-- may request whole FontFace metrics too: clipped/wrapped TextBounds can describe just the visible prefix.
-- Only successful font-service measurements participate; fallback estimates never pin a label to its minimum.
function UIKit.FitText(label, minSize, maxSize)
	local fit = Art.TextFits[label]
	if not fit then
		fit = { Connections = {}, Queued = false, Running = false, Pending = false, Reset = false, Dead = false, Version = 0 }
		Art.TextFits[label] = fit
		fit.Request = function(reset)
			if fit.Dead then return end
			fit.Reset = fit.Reset or reset == true
			if reset then fit.Version += 1 end
			if fit.Queued or fit.Running then fit.Pending = true; return end
			fit.Queued = true
			task.defer(function()
				fit.Queued = false
				if fit.Dead or not label.Parent then return end
				fit.Running = true
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
	fit.Min = math.max(1, math.min(math.floor(minSize), MIN_TEXT_SIZE))
	fit.Max = math.max(fit.Min, math.floor(maxSize))
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then constraint.MinTextSize = fit.Min end
	label.TextScaled = false
	label.TextTruncate = Enum.TextTruncate.None
	label.ClipsDescendants = true
	fit.Request(true)
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
		TweenService:Create(t.Frame, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(t.Label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(t.Stroke, info, { Transparency = 1 }):Play()
	end
	task.delay(0.22, function()
		t.Frame:Destroy()
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

-- kinds: info / good / bad / reward (anything else = info); max 4 stacked (2 on short phones, CR-L38), newest on
-- top; default 2.5 s.
-- A toast whose text is already on screen is refreshed instead of stacked twice.
function UIKit.Toast(text, kind, duration)
	if text == nil then return end
	text = tostring(text)
	if text == "" or not toastHolder then return end
	duration = tonumber(duration) or DEFAULT_TOAST_SECONDS
	if duration <= 0 then duration = DEFAULT_TOAST_SECONDS end

	for _, t in toasts do
		if t.Text == text and not t.Dead then
			scheduleToast(t, duration)
			return
		end
	end

	toastCounter += 1
	local color = kindColor(kind)
	local T = UIKit.Theme
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
	local label = UIKit.Create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 18,
		Text = text,
		TextColor3 = (kind == "good" or kind == "bad" or kind == "reward") and color or T.Text,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = frame,
	})
	frame.Parent = toastHolder

	local t = { Frame = frame, Label = label, Stroke = stroke, Text = text, Token = 0, Dead = false }
	table.insert(toasts, t)
	while #toasts > toastMax do -- CR-L38
		removeToast(toasts[1])
	end

	local info = TweenInfo.new(0.15)
	TweenService:Create(frame, info, { BackgroundTransparency = 0.12 }):Play()
	TweenService:Create(label, info, { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
	TweenService:Create(stroke, info, { Transparency = 0.1 }):Play()
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
		showAnnounce(nxt.Text, nxt.Duration)
	end
end

local function hideAnnounce(token)
	if announceToken ~= token or not announceFrame then return end
	announceCurrent = nil
	local info = TweenInfo.new(0.25)
	TweenService:Create(announceFrame, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(announceLabel, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.28, function()
		if announceToken ~= token then return end
		announceFrame.Visible = false
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

showAnnounce = function(text, duration)
	if not announceFrame then return end
	announceCurrent = { Text = text, Token = 0 }
	announceLabel.Text = text
	announceFrame.Visible = true
	announceFrame.BackgroundTransparency = 1
	announceLabel.TextTransparency = 1
	announceLabel.TextStrokeTransparency = 1
	announcePop.Scale = 0.85
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(announceFrame, info, { BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(announceLabel, info, { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	TweenService:Create(announcePop, info, { Scale = 1 }):Play()
	armAnnounceTimer(duration)
end

-- large banner at 30% screen height; default 3.5 s. Announcements queue (max 3 waiting); a text that extends the
-- one on screen (or queued), e.g. "레벨 업! Lv 10" -> "레벨 업! Lv 10 · 해금! ...", replaces it instead of queueing.
function UIKit.Announce(text, duration)
	if text == nil then return end
	text = tostring(text)
	if text == "" or not announceFrame then return end
	duration = tonumber(duration) or DEFAULT_ANNOUNCE_SECONDS
	if duration <= 0 then duration = DEFAULT_ANNOUNCE_SECONDS end

	if announceCurrent and related(announceCurrent.Text, text) then
		if #text > #announceCurrent.Text then
			announceCurrent.Text = text
			announceLabel.Text = text
		end
		announceFrame.Visible = true
		announceFrame.BackgroundTransparency = 0.3
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
		table.insert(announceQueue, { Text = text, Duration = duration })
		while #announceQueue > MAX_ANNOUNCE_QUEUE do
			table.remove(announceQueue, 1)
		end
		return
	end
	showAnnounce(text, duration)
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

	local box = UIKit.Create("Frame", {
		Name = "Box",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Parent = overlay,
	}, {
		corner(UDim.new(0, 16)),
		UIKit.Create("UIStroke", { Color = T.Gold, Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		UIKit.Create("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})
	UIKit.Label({
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 26,
		TextColor = T.Gold,
		Text = tostring(title or ""),
		Parent = box,
	})
	if body ~= nil and tostring(body) ~= "" then
		UIKit.Label({
			Name = "Body",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 18,
			TextColor = T.SubText,
			Text = tostring(body),
			Parent = box,
		})
	end
	local row = UIKit.Create("Frame", {
		Name = "Buttons",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = box,
	})
	UIKit.Button({
		Name = "Cancel",
		Text = "취소",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -8, 0, 2),
		Size = UDim2.fromOffset(180, 52),
		Color = Color3.fromRGB(70, 72, 92),
		TextSize = 20,
		Parent = row,
	}, close)
	UIKit.Button({
		Name = "Confirm",
		Text = tostring(confirmText or "확인"),
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
		BackgroundTransparency = 1,
		ZIndex = Z_TOASTS,
		Parent = gui,
	}, {
		UIKit.Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	-- announce banner (30% screen height)
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
		UIKit.Create("UISizeConstraint", { MaxSize = Vector2.new(880, 84) }),
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
	announceLabel = UIKit.Create("TextLabel", {
		Name = "Text",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 1, -12),
		BackgroundTransparency = 1,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = T.Gold,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		TextTransparency = 1,
		Text = "",
		Parent = announceFrame,
	}, {
		UIKit.Create("UITextSizeConstraint", { MinTextSize = math.max(MIN_TEXT_SIZE, 14), MaxTextSize = 34 }),
	})

	gui.Parent = playerGui

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

function UIKit.ShouldHoldBanners()
	local me = game:GetService("Players").LocalPlayer
	if me:GetAttribute("TutorialStep") == 0 then return true end
	local intro = C and C.Intro
	if type(intro) == "table" and type(intro.IsOpen) == "function" then
		local ok, open = pcall(intro.IsOpen)
		if ok and open then return true end
	end
	return false
end

-- show the held world banners (called when the first mission is accepted / the opening ends)
function UIKit.FlushBanners()
	if type(UIKit.HeldBanners) ~= "table" or #UIKit.HeldBanners == 0 or UIKit.ShouldHoldBanners() then return end
	local held = UIKit.HeldBanners
	UIKit.HeldBanners = {}
	task.delay(3, function()
		for _, b in held do
			if b[3] == "toast" then
				UIKit.Toast(b[1], "reward", b[2]) -- held server-wide Epic toast (A23-15)
			else
				UIKit.Announce(b[1], b[2])
			end
			task.wait(3)
		end
	end)
end

function UIKit.Start()
	-- re-read the inset once the top bar has settled (it can be 0 during the first frames)
	task.delay(1, applyScale)

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
