-- DialogBox.luau (게임성 개발 1, SPEC A23-229; plan docs/design/dialog_box_plan_2026-10-18.md; user 10/18 with a
-- MapleStory dialogue photo: "npc랑 하는 대화는 이미지처럼 왼쪽에 npc 얼굴 있고 대사 이런 식으로"): the talks you start by
-- talking to someone - the story card, a request, the guide's welcome (Panels "Story" / "Offer" / "Welcome") - show in
-- one box at the bottom of the screen, no dark cover (the world stays visible, I can still walk):
--   left : the speaker's face (UIKit.Portrait: the approved portrait art, else the speaker's initial) with the name under it
--   right: the line (typing in, a tap shows it whole), a small italic situation line over it (Offer / Welcome), the
--          reward row and the choice hint on the last line
--   bottom right: [Next] while lines are left; on the last line the final buttons (Got it / the two choices / Sure! + Not
--          now / I'm In!); bottom left: [Bye] = close without an answer
-- A card with several speakers ("Bright: ..." then "Hallie: ...") switches the face and the name line by line (a known
-- speaker's name before ':' only; the words keep the rest). Presses / taps only (BB1: no fixed key outside Keybinds; G
-- would talk to the NPC again). Walking more than L.Far studs from the speaker's body (when it has one) is [Bye].
-- Panels keeps every rule around it (the busy queue, the HUD row pulse, currentId, the remotes); it builds the spec and
-- calls DialogBox.Show; Panels.Close calls DialogBox.Hide. Approved parts only (DialogBox plate, PortraitFrame, the
-- Panels buttons), UIKit fallbacks; the words are the existing Config texts + Config.ClientText.DialogBox.Bye.
-- Public API: DialogBox.Init(C), DialogBox.Start(), DialogBox.Show(spec) -> bool, DialogBox.Hide(), DialogBox.IsOpen(),
-- DialogBox.SetFinal(i, { Text?, Enabled? }), DialogBox.Press(which); pure: DialogBox.Speaker(line, voice, name),
-- DialogBox.VoiceOf(nameOrId), DialogBox.Plan(spec, page).
-- spec = { Key, Voice, Name, Lines = { ... }, Before?, Hint?, Reward? = { List, Look }, Final = { { Text, Style = "Free" |
-- "Button" | "Good" | "Evil", Name, OnPress } }, FinalAlways? (the final buttons on every line), OnBye, Body? (BasePart) }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer
local DialogBox = {}
local C = nil
local TAG = "DialogBox"

-- layout (du = MainGui units) and rules
local L = {
	MaxW = 900, H = 214, Side = 16, Bottom = 14, Pad = 16, -- the box: at most MaxW wide, Side du from the screen edges
	Face = 128, FaceGap = 14, NameH = 26, -- the portrait column
	LineSize = 22, BeforeSize = 17, HintSize = 16, BtnH = 46, BtnW = 140, ByeW = 96, Gap = 8,
	Z = 70, -- over the HUD (the KO screen is 60), under the pickers
	Far = 15, -- studs from the speaker's body: [Bye]
	Ink = Color3.fromRGB(66, 40, 18), Sub = Color3.fromRGB(118, 88, 60), Gold = Color3.fromRGB(176, 120, 20),
	Plate = Color3.fromRGB(250, 238, 210), -- the code plate when the DialogBox art is missing
}
local TXT = Config.ClientText.DialogBox -- the words: Config.ClientText.DialogBox
local S = { Spec = nil, Page = 1, Typing = nil, View = nil, Conn = nil, Final = {} }

local function sq() return type(Config.StoryQuests) == "table" and Config.StoryQuests or {} end

---------------------------------------------------------------------------------------------------- pure
-- a speaker name or id -> the voice key of Config.StoryQuests.Portraits / Audio.Talk ("Otto" -> "Smith", "Hallie" ->
-- "Halo", "Kit" -> "Guild"); nil = not a known speaker
function DialogBox.VoiceOf(who)
	if type(who) ~= "string" or who == "" then return nil end
	local speakers = type(sq().Speakers) == "table" and sq().Speakers or {}
	local portraits = type(sq().Portraits) == "table" and sq().Portraits or {}
	if speakers[who] ~= nil or portraits[who] ~= nil then return who end
	for key, name in speakers do
		if name == who then return key end
	end
	local welcome = type(Config.Tutorial) == "table" and type(Config.Tutorial.Welcome) == "table" and Config.Tutorial.Welcome or {}
	for side, w in welcome do
		if type(w) == "table" and w.Name == who then return side == "Neutral" and "Guild" or side end
	end
	return nil
end

-- the shown name of a voice key (Speakers / the guide's name), else the key itself
local function nameOf(voice)
	local speakers = type(sq().Speakers) == "table" and sq().Speakers or {}
	if type(speakers[voice]) == "string" then return speakers[voice] end
	local welcome = type(Config.Tutorial) == "table" and type(Config.Tutorial.Welcome) == "table" and Config.Tutorial.Welcome or {}
	local side = voice == "Guild" and "Neutral" or voice
	if type(welcome[side]) == "table" and type(welcome[side].Name) == "string" then return welcome[side].Name end
	return tostring(voice or "")
end
DialogBox.NameOf = nameOf

-- one line -> its speaker and words: "Bright: Hi!" with a known speaker = { Voice = "Bright", Name = "Bright",
-- Text = "Hi!" }; anything else = the card's own speaker and the whole line
function DialogBox.Speaker(line, voice, name)
	line = tostring(line or "")
	local who, rest = string.match(line, "^([%a][%w '&%.]-):%s+(.+)$")
	local v = who and DialogBox.VoiceOf(who) or nil
	if v then return { Voice = v, Name = who, Text = rest } end
	return { Voice = voice, Name = name or nameOf(voice), Text = line }
end

-- what page `page` shows: { Voice, Name, Text, Last, Next (the [Next] button), Final (the final buttons) }
function DialogBox.Plan(spec, page)
	local lines = type(spec) == "table" and type(spec.Lines) == "table" and spec.Lines or {}
	local n = math.max(1, #lines)
	page = math.clamp(math.floor(tonumber(page) or 1), 1, n)
	local s = DialogBox.Speaker(lines[page] or "", spec.Voice, spec.Name)
	s.Page, s.Last = page, page >= n
	s.Next = not s.Last
	s.Final = s.Last or spec.FinalAlways == true
	return s
end

---------------------------------------------------------------------------------------------------- drawing
local function kit() return C and C.UIKit end

local function ink(parent, name, size, color, props)
	local ui = kit()
	local l = nil
	if type(ui) == "table" and type(ui.InkText) == "function" then
		local p = { Name = name, Text = "", TextSize = size, TextColor = color, Parent = parent, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, BackgroundTransparency = 1,
			ZIndex = L.Z + 2 }
		for k, v in props or {} do p[k] = v end
		local ok, made = pcall(ui.InkText, p)
		if ok and typeof(made) == "Instance" then l = made end
	end
	if not l then
		l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.TextSize = size
		l.TextColor3 = color
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.ZIndex = L.Z + 2
		for k, v in props or {} do pcall(function() l[k] = v end) end
		l.Parent = parent
	end
	return l
end

-- the face: the speaker's approved portrait art, else the initial (UIKit.Portrait's own fallback)
local function drawFace(v)
	local view = S.View
	if not view or view.FaceVoice == v.Voice then return end
	view.FaceVoice = v.Voice
	if view.Face then view.Face:Destroy() end
	view.Face = nil
	local ui = kit()
	local portraits = type(sq().Portraits) == "table" and sq().Portraits or {}
	local key = type(v.Voice) == "string" and portraits[v.Voice] or nil
	if key and type(ui.ArtPart) == "function" and not ui.ArtPart(key) then key = nil end
	if type(ui) == "table" and type(ui.Portrait) == "function" then
		local ok, holder = pcall(ui.Portrait, key, { Name = "Face", Size = UDim2.fromOffset(L.Face, math.floor(L.Face * 498 / 512)),
			Initial = string.sub(tostring(v.Name or "?"), 1, 1), ZIndex = L.Z + 2, Parent = view.Left })
		if ok and typeof(holder) == "Instance" then view.Face = holder end
	end
end

local function finalButtons()
	local view, spec = S.View, S.Spec
	for _, b in S.Final do pcall(function() b:Destroy() end) end
	S.Final = {}
	local panels = C and C.Panels
	local k = type(panels) == "table" and type(panels.DialogKit) == "function" and panels.DialogKit() or nil
	if not (view and spec and k) then return end
	for i, f in type(spec.Final) == "table" and spec.Final or {} do
		local size = UDim2.fromOffset(L.BtnW, L.BtnH)
		local press = function() DialogBox.Press(i) end
		local b
		if f.Style == "Good" or f.Style == "Evil" then
			b = k.ChoiceButton(view.Buttons, f.Style, tostring(f.Text or ""), UDim2.fromOffset(L.BtnW + 40, L.BtnH), press)
		else
			b = k.Button(view.Buttons, tostring(f.Text or ""), f.Style == "Free" and k.Palette.Free or k.Palette.Button, size, press)
		end
		if typeof(b) == "Instance" then
			b.Name = f.Name or ("Final" .. i)
			b.LayoutOrder = 10 + i
			S.Final[i] = b
		end
	end
end

local function paint()
	local view, spec = S.View, S.Spec
	if not (view and spec) then return end
	local v = DialogBox.Plan(spec, S.Page)
	drawFace(v)
	view.Name.Text = tostring(v.Name or "")
	local ui = kit()
	local h = nil
	if type(ui) == "table" and type(ui.Typewriter) == "function" then
		local ok, made = pcall(ui.Typewriter, view.Line, v.Text, { Speaker = v.Voice })
		if ok then h = made end
	end
	if not h then view.Line.Text = v.Text end
	S.Typing = h
	view.Next.Visible = v.Next
	for _, b in S.Final do b.Visible = v.Final end
	if view.Hint then view.Hint.Visible = v.Last end
	if view.Reward then view.Reward.Visible = v.Last end
end

-- true when the line was still typing (the press only showed it whole)
local function finishTyping()
	local h = S.Typing
	if type(h) == "table" and type(h.Done) == "function" and not h.Done() then
		pcall(h.Finish)
		return true
	end
	return false
end

-- a press: "Next", "Bye" or a final button's index
function DialogBox.Press(which)
	local spec = S.Spec
	if not spec then return false end
	if which == "Bye" then
		local fn = spec.OnBye
		DialogBox.Hide()
		if type(fn) == "function" then pcall(fn) end
		return true
	end
	if finishTyping() then return true end
	local v = DialogBox.Plan(spec, S.Page)
	if which == "Next" then
		if not v.Next then return false end
		S.Page += 1
		paint()
		return true
	end
	local f = type(spec.Final) == "table" and spec.Final[which] or nil
	local b = S.Final[which]
	if not (f and v.Final and b and b.Visible) or b:GetAttribute("Disabled") == true then return false end
	if type(f.OnPress) == "function" then
		local ok, err = pcall(f.OnPress)
		if not ok then Util.Warn(TAG, "final button: " .. tostring(err)) end
	end
	return true
end

function DialogBox.Hide()
	if S.Conn then pcall(function() S.Conn:Disconnect() end) end
	S.Conn = nil
	if S.View and S.View.Root then S.View.Root:Destroy() end
	S.View, S.Spec, S.Typing, S.Final = nil, nil, nil, {}
end

function DialogBox.IsOpen()
	return S.Spec ~= nil
end

-- a final button's words / state (Welcome's 'Joining…')
function DialogBox.SetFinal(i, opts)
	local b = S.Final[i]
	if not b or type(opts) ~= "table" then return end
	if opts.Text ~= nil then b.Text = tostring(opts.Text) end
	if opts.Enabled ~= nil then
		local panels = C and C.Panels
		local k = type(panels) == "table" and type(panels.DialogKit) == "function" and panels.DialogKit() or nil
		if k and type(k.SetEnabled) == "function" then pcall(k.SetEnabled, b, opts.Enabled == true) end
	end
end

function DialogBox.Show(spec)
	local ui = kit()
	local gui = type(ui) == "table" and ui.Gui or nil
	if type(spec) ~= "table" or typeof(gui) ~= "Instance" then return false end
	-- the same talk again (a refresh) keeps its page
	if S.Spec and S.View and S.Spec.Key ~= nil and S.Spec.Key == spec.Key then
		S.Spec = spec
		finalButtons()
		paint()
		return true
	end
	DialogBox.Hide()
	S.Spec, S.Page = spec, 1
	local root = Instance.new("Frame")
	root.Name = "DialogBox"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -L.Bottom)
	root.Size = UDim2.new(1, -2 * L.Side, 0, L.H)
	root.ZIndex = L.Z
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(L.MaxW, L.H)
	cap.Parent = root
	local plate = nil
	if type(ui.ArtFrame) == "function" then
		local ok, made = pcall(ui.ArtFrame, "DialogBox", { Name = "Plate", Size = UDim2.fromScale(1, 1), ZIndex = L.Z, Parent = root },
			{ BackgroundColor3 = L.Plate, CornerRadius = UDim.new(0, 14), StrokeColor = L.Sub, StrokeThickness = 2 })
		if ok and typeof(made) == "Instance" then plate = made end
	end
	if not plate then
		plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.BackgroundColor3 = L.Plate
		plate.Size = UDim2.fromScale(1, 1)
		plate.ZIndex = L.Z
		plate.Parent = root
	end
	-- left: the face and the name under it
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(L.Pad, L.Pad)
	left.Size = UDim2.new(0, L.Face, 1, -2 * L.Pad)
	left.ZIndex = L.Z + 1
	left.Parent = root
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.Padding = UDim.new(0, 4)
	ll.Parent = left
	local name = ink(left, "SpeakerName", 18, L.Ink, { Size = UDim2.new(1, 0, 0, L.NameH), LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Title = true })
	-- right: the words over the buttons
	local x = L.Pad + L.Face + L.FaceGap
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(x, L.Pad)
	right.Size = UDim2.new(1, -(x + L.Pad), 1, -(2 * L.Pad + L.BtnH + L.Gap))
	right.ZIndex = L.Z + 1
	right.Parent = root
	local rl = Instance.new("UIListLayout")
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Padding = UDim.new(0, 4)
	rl.Parent = right
	if type(spec.Before) == "string" and spec.Before ~= "" then
		local b = ink(right, "Before", L.BeforeSize, L.Sub, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1, Text = spec.Before })
		pcall(function()
			local ff = b.FontFace
			b.FontFace = Font.new(ff.Family, ff.Weight, Enum.FontStyle.Italic)
		end)
	end
	local line = ink(right, "Line", L.LineSize, L.Ink, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2 })
	local tap = Instance.new("TextButton")
	tap.Name = "TypeTap"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.AutoButtonColor = false
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = L.Z + 3
	tap.Parent = line
	tap.Activated:Connect(finishTyping)
	local hint = nil
	if type(spec.Hint) == "string" and spec.Hint ~= "" then
		hint = ink(right, "Hint", L.HintSize, L.Gold, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3, Text = spec.Hint })
	end
	-- bottom: [Bye] on the left, [Next] / the final buttons on the right
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, x, 1, -L.Pad)
	bar.Size = UDim2.new(1, -(x + L.Pad), 0, L.BtnH)
	bar.ZIndex = L.Z + 1
	bar.Parent = root
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.fromScale(1, 1)
	buttons.ZIndex = L.Z + 1
	buttons.Parent = bar
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, L.Gap)
	bl.Parent = buttons
	S.View = { Root = root, Left = left, Name = name, Right = right, Line = line, Hint = hint, Buttons = buttons }
	local panels = C and C.Panels
	local k = type(panels) == "table" and type(panels.DialogKit) == "function" and panels.DialogKit() or nil
	if k then
		local nextBtn = k.Button(buttons, tostring(sq().Text and sq().Text.Next or "Next"), k.Palette.Button,
			UDim2.fromOffset(L.BtnW, L.BtnH), function() DialogBox.Press("Next") end)
		nextBtn.Name = "DialogNext"
		nextBtn.LayoutOrder = 1
		S.View.Next = nextBtn
		local bye = k.Button(bar, tostring(TXT.Bye), k.Palette.Button, UDim2.fromOffset(L.ByeW, L.BtnH), function()
			DialogBox.Press("Bye")
		end)
		bye.Name = "DialogBye"
		bye.AnchorPoint = Vector2.new(0, 0.5)
		bye.Position = UDim2.fromScale(0, 0.5)
		S.View.Bye = bye
		-- the reward row (Offer) on the last line: Panels' own icons + numbers
		if type(spec.Reward) == "table" and type(spec.Reward.List) == "table" and #spec.Reward.List > 0
			and type(k.RewardRow) == "function" then
			local ok, row = pcall(k.RewardRow, right, spec.Reward.List, spec.Reward.Look)
			if ok and typeof(row) == "Instance" then
				row.LayoutOrder = 4
				S.View.Reward = row
			end
		end
	end
	if not S.View.Next then
		S.View.Next = Instance.new("TextButton") -- no Panels kit (offline): an unseen stand-in
	end
	finalButtons()
	root.Parent = gui
	paint()
	-- walking away from the speaker = [Bye]
	local body = spec.Body
	if typeof(body) == "Instance" and body:IsA("BasePart") then
		S.Conn = RunService.Heartbeat:Connect(function()
			local char = LocalPlayer and LocalPlayer.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if r and body.Parent and (r.Position - body.Position).Magnitude > L.Far then DialogBox.Press("Bye") end
		end)
	end
	return true
end

function DialogBox.Init(registry)
	C = registry
end

function DialogBox.Start() end

-- offline tests
DialogBox._T = { L = L, S = S }

return DialogBox
