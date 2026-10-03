-- UIKit.luau : the shared ScreenGui ("MainGui"), theme, widget factories, toasts, announce banner, confirm dialog
-- and attribute helpers used by every client module (TECH_SPEC §4.23, addendum A3-H4 / M1).
-- Everything here is presentation only; the server never trusts anything the client shows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LocalPlayer = Players.LocalPlayer

local UIKit = {}

UIKit.Gui = nil -- ScreenGui "MainGui", created in Init

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
			else
				setProp(inst, key, value)
			end
		end
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

-- kinds: info / good / bad / reward (anything else = info); max 4 stacked, newest on top; default 2.5 s.
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
	while #toasts > MAX_TOASTS do
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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	UIKit.Gui = gui

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

function UIKit.Start()
	-- re-read the inset once the top bar has settled (it can be 0 during the first frames)
	task.delay(1, applyScale)

	-- the remote normally exists already; never block the other client modules' Start on it
	task.spawn(function()
		local remote = Net.Get("Notify")
		remote.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then return end
			local text = payload.Text
			if type(text) ~= "string" or text == "" then return end
			local duration = tonumber(payload.Duration)
			if payload.Kind == "announce" then
				UIKit.Announce(text, duration)
			else
				UIKit.Toast(text, payload.Kind, duration)
			end
		end)
	end)

	print("[UIKit] started")
end

return UIKit
