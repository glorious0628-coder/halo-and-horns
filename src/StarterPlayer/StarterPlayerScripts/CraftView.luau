-- CraftView.luau (게임성 개발 4, ③-2 망치질 고리 화면; SPEC A23-56 · A23-127 · A23-133 · A23-130 · A23-98, design
-- docs/design/hammer_minigame_2026-10-12.md, contract 게임성 검수 10/12 + 개발 3 CraftService origin/dev3-craft): the ring
-- minigame on screen. The numbers and the grading are Shared/CraftMini (the server grades with the same functions).
--   s->c CraftSession { Id, Recipe, Strikes, Ring, Rest, StartAt } opens it: a dimmed screen, the target circle in the
--   middle, a gold ring shrinking onto it on the fixed schedule (CraftMini.Appear / Target / Closes), five dots below for
--   the five strikes and a [Skip] button. A press (left click / tap anywhere on it, or Space) while a ring is live is that
--   ring's strike: its grade word pops (Perfect / Great / Good / Miss), the dot takes its colour and c->s
--   CraftStrike(Id, i, ms) goes out once per ring (ms = press - T_i on the server clock, + = late). A ring nobody pressed
--   turns Miss when it closes. After the last ring (or [Skip]) c->s CraftFinish(Id); s->c CraftResult { Id, Plus, Grades,
--   Kind, Tier?, Item? } shows one line ("+1 Iron Sword") and closes it.
--   While it is open the clicks are the overlay's (the HUD's attack ignores processed input) and Space is sunk (no jump).
-- Studio only: LocalPlayer attribute CraftPractice = true runs a local session (no server, graded here with CraftMini)
-- for the UiSandbox photos. No other text than the grade words, Skip and the result line (A23-130). PC first (A23-98).
-- Public API: CraftView.Init(C), CraftView.Start(), CraftView.IsOpen(), CraftView.Begin(session, practice),
-- CraftView.Press(t?), CraftView.Step(t?), CraftView.OnResult(payload), CraftView.Close()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))
local CraftMini = require(Shared:WaitForChild("CraftMini"))

local CraftView = {}
local C = nil
local TAG = "CraftView"
local LocalPlayer = Players.LocalPlayer

-- player text (A23-130: the grade words, Skip and one result line; A23-111: keys "CraftView.TXT.<field>")
local TXT = {
	Grades = { Perfect = "Perfect", Great = "Great", Good = "Good", Miss = "Miss" },
	Skip = "Skip",
	Result = "+%d %s",
	ResultPlain = "+%d",
}
L10n.Register("CraftView.TXT", TXT)

local V = {
	Target = 120, -- du: the target circle
	Grow = 1.6, -- the ring starts this much wider than the target (1 + Grow = its size at Appear)
	Past = 0.8, -- the ring keeps shrinking to this size until it closes
	Dot = 22, DotGap = 12, -- du: the five grade dots
	Word = 40, -- du: the grade word
	ResultSize = 30,
	SkipW = 160, SkipH = 48,
	Dim = 0.35, -- the backdrop's transparency
	ZIndex = 60,
	Hold = 1.6, -- s the result line stays
	ResultWait = 6, -- s to wait for CraftResult after Finish before closing quietly
	WordTime = 0.7, -- s a grade word stays
	Action = "HH_CraftStrike", Priority = 3000, -- ContextActionService: Space is a strike (and no jump) while open
	Colors = { Perfect = Color3.fromRGB(255, 200, 60), Great = Color3.fromRGB(110, 220, 120), Good = Color3.fromRGB(110, 170, 255),
		Miss = Color3.fromRGB(140, 140, 150), Ring = Color3.fromRGB(255, 205, 80), Target = Color3.fromRGB(255, 150, 60) },
	-- Config.Sounds keys (silent until 소리 만들기 adds them; Fx.PlaySound skips a missing id)
	Sounds = { Perfect = "HammerPerfect", Great = "HammerGreat", Good = "HammerGood", Miss = "HammerMiss", Done = "CraftDone" },
	Shake = { Perfect = 0.25 }, -- Fx.Shake magnitude for a Perfect (Fx honours Settings.Shake)
}

-- S.Session = { Id, StartAt, Practice } while open; Grades[i] = the grade shown (nil until pressed / closed); Sent[i] = the
-- strike went out; Finished = CraftFinish sent (or the practice ended) at os.clock(); Result = the line shown
local S = { Session = nil, Grades = {}, Sent = {}, Finished = nil, ResultAt = nil, Remotes = {}, Started = false }
local UI = {} -- Root, Ring, RingStroke, Target, Dots = { [i] = Frame }, Word, WordAt, Result, Skip, Conn

local function tx(t, key, ...)
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.Tx) == "function" then
		local ok, s = pcall(ui.Tx, t, key, ...)
		if ok and type(s) == "string" then return s end
	end
	local s = t[key]
	if type(s) ~= "string" then return "" end
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return ok and out or s
	end
	return s
end

local function now()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or Util.Now()
end

local function remote(name)
	local r = S.Remotes[name]
	if r and r.Parent then return r end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	r = folder and folder:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		S.Remotes[name] = r
		return r
	end
	return nil
end

local function fire(name, ...)
	local r = remote(name)
	if r then pcall(r.FireServer, r, ...) end
end

local function fx(name, ...)
	local f = C and C.Fx
	if type(f) == "table" and type(f[name]) == "function" then pcall(f[name], ...) end
end

---------------------------------------------------------------------------------------------------- drawing
local function round(frame)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = frame
end

local function label(parent, name, size, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(420, size + 8)
	l.TextSize = size
	l.TextColor3 = color
	l.Text = ""
	l.ZIndex = V.ZIndex + 4
	l.Parent = parent
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.StyleText) == "function" then
		pcall(ui.StyleText, l, "Title")
		l.TextColor3 = color
	end
	return l
end

local function build()
	local ui = C and C.UIKit
	local gui = type(ui) == "table" and ui.Gui or nil
	if not gui then return false end
	-- the whole screen: dims the world, takes every click / tap (a strike), never lets one through to the HUD
	local root = Instance.new("TextButton")
	root.Name = "CraftRing"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = V.Dim
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = V.ZIndex
	root.Activated:Connect(function() CraftView.Press() end)
	UI.Root = root
	local target = Instance.new("Frame")
	target.Name = "Target"
	target.AnchorPoint = Vector2.new(0.5, 0.5)
	target.Position = UDim2.fromScale(0.5, 0.45)
	target.Size = UDim2.fromOffset(V.Target, V.Target)
	target.BackgroundColor3 = Color3.fromRGB(40, 22, 14)
	target.BackgroundTransparency = 0.15
	target.ZIndex = V.ZIndex + 1
	round(target)
	local ts = Instance.new("UIStroke")
	ts.Color = V.Colors.Target
	ts.Thickness = 3
	ts.Parent = target
	target.Parent = root
	UI.Target = target
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = target.Position
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.ZIndex = V.ZIndex + 2
	round(ring)
	local rs = Instance.new("UIStroke")
	rs.Color = V.Colors.Ring
	rs.Thickness = 5
	rs.Parent = ring
	ring.Parent = root
	UI.Ring, UI.RingStroke = ring, rs
	UI.Dots = {}
	local n = CraftMini.T.Strikes
	local rowW = n * V.Dot + (n - 1) * V.DotGap
	for i = 1, n do
		local d = Instance.new("Frame")
		d.Name = "Dot" .. i
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = UDim2.new(0.5, -rowW / 2 + V.Dot / 2 + (i - 1) * (V.Dot + V.DotGap), 0.45, V.Target / 2 + 34)
		d.Size = UDim2.fromOffset(V.Dot, V.Dot)
		d.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		d.BackgroundTransparency = 0.2
		d.ZIndex = V.ZIndex + 1
		round(d)
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(200, 200, 210)
		st.Thickness = 2
		st.Parent = d
		d.Parent = root
		UI.Dots[i] = d
	end
	local word = label(root, "Grade", V.Word, V.Colors.Perfect)
	word.Position = UDim2.new(0.5, 0, 0.45, -(V.Target / 2 + 40))
	UI.Word, UI.WordAt = word, -math.huge
	local result = label(root, "Result", V.ResultSize, V.Colors.Perfect)
	result.Position = UDim2.new(0.5, 0, 0.45, V.Target / 2 + 80)
	UI.Result = result
	-- [Skip]: done now at +0 (게임성 검수 10/12; an approved capsule, the coloured code button without it)
	local skip
	if type(ui.ArtTextButton) == "function" then
		local ok, b = pcall(ui.ArtTextButton, "BtnSecondary", { Name = "Skip", Text = tx(TXT, "Skip"), TextSize = 22,
			Size = UDim2.fromOffset(V.SkipW, V.SkipH) }, function() CraftView.Skip() end)
		if ok and typeof(b) == "Instance" then skip = b end
	end
	if not skip then
		skip = Instance.new("TextButton")
		skip.Name = "Skip"
		skip.Text = tx(TXT, "Skip")
		skip.Size = UDim2.fromOffset(V.SkipW, V.SkipH)
		skip.Activated:Connect(function() CraftView.Skip() end)
	end
	skip.AnchorPoint = Vector2.new(0.5, 1)
	skip.Position = UDim2.new(0.5, 0, 1, -40)
	skip.ZIndex = V.ZIndex + 3
	skip.Parent = root
	UI.Skip = skip
	root.Parent = gui
	return true
end

local function paintDot(i, grade)
	local d = UI.Dots and UI.Dots[i]
	if d then
		d.BackgroundColor3 = V.Colors[grade] or V.Colors.Miss
		d.BackgroundTransparency = 0
	end
end

local function showWord(grade)
	if not UI.Word then return end
	UI.Word.Text = tx(TXT.Grades, grade)
	UI.Word.TextColor3 = V.Colors[grade] or V.Colors.Miss
	UI.WordAt = os.clock()
end

---------------------------------------------------------------------------------------------------- the session
function CraftView.IsOpen()
	return S.Session ~= nil
end

local function bindKeys(on)
	if on then
		pcall(function()
			ContextActionService:BindActionAtPriority(V.Action, function(_, state)
				if state == Enum.UserInputState.Begin then CraftView.Press() end
				return Enum.ContextActionResult.Sink -- no jump, no other Space action while the ring is open
			end, false, V.Priority, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		end)
	else
		pcall(function() ContextActionService:UnbindAction(V.Action) end)
	end
end

function CraftView.Close()
	S.Session, S.Finished, S.ResultAt = nil, nil, nil
	bindKeys(false)
	if UI.Conn then
		pcall(function() UI.Conn:Disconnect() end)
	end
	if UI.Root then pcall(function() UI.Root:Destroy() end) end
	UI = {}
end

-- the strike of the live ring at server time t (default now); once per ring, only while a ring is live
function CraftView.Press(t)
	local s = S.Session
	if not s or S.Finished then return nil end
	t = t or now()
	local i = CraftMini.Live(s.StartAt, t)
	if not i or S.Grades[i] then return nil end
	local ms = (t - CraftMini.Target(s.StartAt, i)) * 1000
	local grade = CraftMini.Grade(ms)
	S.Grades[i] = grade
	paintDot(i, grade)
	showWord(grade)
	fx("PlaySound", V.Sounds[grade])
	if V.Shake[grade] then fx("Shake", V.Shake[grade], 0.15) end
	if not s.Practice and not S.Sent[i] then
		S.Sent[i] = true
		fire("CraftStrike", s.Id, i, math.floor(ms + 0.5))
	end
	return grade
end

local function finish()
	local s = S.Session
	if not s or S.Finished then return end
	S.Finished = os.clock()
	if s.Practice then
		local _, plus = CraftMini.Score(S.Grades)
		CraftView.OnResult({ Id = s.Id, Plus = plus, Practice = true })
	else
		fire("CraftFinish", s.Id)
	end
end

function CraftView.Skip()
	local s = S.Session
	if not s then return end
	if s.Practice then
		CraftView.Close()
		return
	end
	finish()
end

-- one frame at server time t: the ring's size, the rings nobody pressed turning Miss, the end of the session
function CraftView.Step(t)
	local s = S.Session
	if not s then return end
	t = t or now()
	local T = CraftMini.T
	for i = 1, T.Strikes do
		if not S.Grades[i] and t >= CraftMini.Closes(s.StartAt, i) then
			S.Grades[i] = "Miss"
			paintDot(i, "Miss")
		end
	end
	local i, f = CraftMini.Live(s.StartAt, t)
	if UI.Ring then
		local live = i ~= nil and not S.Grades[i] and not S.Finished
		UI.Ring.Visible = live
		if live then
			local scale = f <= 1 and (1 + V.Grow * (1 - f)) or math.max(V.Past, 1 - (f - 1) * 2)
			UI.Ring.Size = UDim2.fromOffset(V.Target * scale, V.Target * scale)
		end
	end
	if UI.Word and os.clock() - UI.WordAt > V.WordTime and UI.Word.Text ~= "" then UI.Word.Text = "" end
	if not S.Finished and t >= CraftMini.Ends(s.StartAt) then finish() end
	if S.ResultAt and os.clock() - S.ResultAt >= V.Hold then
		CraftView.Close()
	elseif S.Finished and not S.ResultAt and os.clock() - S.Finished >= V.ResultWait then
		CraftView.Close() -- no answer: the server finishes it anyway (+0 at worst, kept in the bag)
	end
end

-- s->c CraftResult (or the practice's own): the one result line, then the screen closes
function CraftView.OnResult(payload)
	if type(payload) ~= "table" then return end
	local s = S.Session
	if not s or (payload.Id ~= s.Id and not payload.Practice) then return end
	local plus = math.max(0, math.floor(tonumber(payload.Plus) or 0))
	local name = nil
	if payload.Kind == "Weapon" and tonumber(payload.Tier) then
		local class, faction = LocalPlayer:GetAttribute("Class"), LocalPlayer:GetAttribute("Faction")
		local ok, n = pcall(Config.WeaponName, math.floor(tonumber(payload.Tier)), class, faction)
		name = ok and n or nil
	elseif type(payload.Item) == "string" and Config.Loot.Items[payload.Item] then
		name = tx(Config.Loot.Items[payload.Item], "Name")
	end
	if UI.Result then
		UI.Result.Text = name and tx(TXT, "Result", plus, name) or tx(TXT, "ResultPlain", plus)
	end
	if UI.Ring then UI.Ring.Visible = false end
	if UI.Skip then UI.Skip.Visible = false end
	S.Finished = S.Finished or os.clock()
	S.ResultAt = os.clock()
	fx("PlaySound", V.Sounds.Done)
end

-- a session from the server (or the Studio practice): the screen opens on it
function CraftView.Begin(session, practice)
	if type(session) ~= "table" then return false end
	local startAt = tonumber(session.StartAt)
	if not startAt or startAt ~= startAt then return false end
	if S.Session then CraftView.Close() end
	S.Session = { Id = session.Id, StartAt = startAt, Practice = practice == true }
	S.Grades, S.Sent, S.Finished, S.ResultAt = {}, {}, nil, nil
	if not build() then
		S.Session = nil
		return false
	end
	bindKeys(true)
	UI.Conn = RunService.RenderStepped:Connect(function()
		local ok, err = pcall(CraftView.Step)
		if not ok then Util.Warn(TAG, "step: " .. tostring(err)) end
	end)
	return true
end

local function hook(name, fn)
	local function on(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(fn, payload)
			if not ok then Util.Warn(TAG, name .. ": " .. tostring(err)) end
		end)
	end
	local r = remote(name)
	if r then
		on(r)
		return
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Remotes", 60)
		local rr = folder and folder:WaitForChild(name, 60)
		if rr and rr:IsA("RemoteEvent") then on(rr) end -- no remote = crafting is off on this server
	end)
end

function CraftView.Init(registry)
	C = registry
	hook("CraftSession", function(p) CraftView.Begin(p, false) end)
	hook("CraftResult", CraftView.OnResult)
end

function CraftView.Start()
	if S.Started then return end
	S.Started = true
	-- Studio only: the practice session for the photos (no server, nothing saved)
	local ok, studio = pcall(function() return RunService:IsStudio() end)
	if ok and studio and LocalPlayer then
		LocalPlayer:GetAttributeChangedSignal("CraftPractice"):Connect(function()
			if LocalPlayer:GetAttribute("CraftPractice") == true then
				LocalPlayer:SetAttribute("CraftPractice", nil)
				CraftView.Begin({ Id = 0, StartAt = now() + CraftMini.T.Lead }, true)
			end
		end)
	end
end

-- offline tests
CraftView._T = { S = S, UI = function() return UI end, V = V, TXT = TXT }

return CraftView
