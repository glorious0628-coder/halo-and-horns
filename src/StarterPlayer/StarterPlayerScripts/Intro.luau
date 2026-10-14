-- Intro.luau : A23-9 first-time 3D opening (15-25 s) before the faction cards, replayable from the menu.
-- Close in-engine shots only (fog 120-650: no top-down view of the map), existing map + local parts / default
-- particles, a Scriptable camera tween, the three Config.Story.Premise lines as subtitles, an always-visible skip
-- button (Enter / pad A, ignored for the first 1.5 s so a held key cannot skip by accident). While open: HUD / pickers / potions treat the screen as covered (IsOpen), world
-- banners wait (UIKit.HeldBanners), movement is off. Ending, skipping or respawning restores CameraType Custom and
-- the Humanoid camera subject. Only the server writes IntroSeen (remote "IntroSeen", no arguments).
-- A23-74 (user 2026-10-07): full screen on PC and phone, no black letterbox bars.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local Intro = {}
local C, UIKit = nil, nil

-- A23-48 (user 2026-10-06): the game shows English only. The opening's own lines live here (Config.Story keeps the
-- old Korean premise for the story texts); short, easy English
local TXT = Config.ClientText.Intro -- the words: Config.ClientText.Intro (moved 10/14)
-- map anchors (A23-9): crown in the Crossroads sky, shard over the fountain, the two faction towns
local SPOT = {
	Crown = Vector3.new(15, 344, -18),
	Shard = Vector3.new(0, 22, 0),
	-- map v2: the town cores moved 10 studs outward with their gates (spawns (0, -+420))
	Halo = Vector3.new(0, 16, -410),
	Horns = Vector3.new(0, 16, 410),
	Gold = Color3.fromRGB(255, 214, 90),
	Red = Color3.fromRGB(235, 60, 60),
	White = Color3.fromRGB(255, 250, 225),
}
local state = { Open = false, Token = 0, Done = false, Replay = false, Gui = nil, Folder = nil, Controls = nil,
	CamTween = nil, OpenedAt = 0 }
-- shot 1 (검수 2026-10-07: seen from straight below the crown was only an orange ring): a front three-quarter view,
-- 25 deg below the crown and 30 deg to its left, pushing in slowly; the crown's front (-Z, the glowing crack) faces it
local CROWN_SHOT = { Down = math.rad(25), Side = math.rad(30), From = 330, To = 255 }
local SKIP_GRACE = 1.5 -- seconds after the start when skip input is ignored

local function needsFirstIntro()
	if player:GetAttribute("DataLoaded") ~= true then return false end
	local f = player:GetAttribute("Faction")
	return (f == nil or f == "None") and player:GetAttribute("IntroSeen") ~= true
end

-- FactionPicker waits while this is true: playing, or a brand-new player whose opening has not run yet
function Intro.Blocking()
	return state.Open or (not state.Done and needsFirstIntro())
end

-- "screen covered" for HUD / pickers / potions: also the second before a brand-new player's opening starts
function Intro.IsOpen()
	return Intro.Blocking()
end

local function controls()
	if state.Controls ~= nil then return state.Controls end
	local ok, mod = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
	end)
	state.Controls = ok and mod or false
	return state.Controls
end

local function setMovement(on)
	local ctl = controls()
	if ctl then pcall(function() if on then ctl:Enable() else ctl:Disable() end end) end
end

local function holdWorld(on)
	local fp = C and C.FactionPicker
	if type(fp) == "table" and type(fp.HoldWorld) == "function" then pcall(fp.HoldWorld, "intro", on) end
end

----------------------------------------------------------------- local effects (no new art)
local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in props do p[k] = v end
	p.Parent = state.Folder
	return p
end

local function burst(pos, color, count)
	local holder = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local pe = Instance.new("ParticleEmitter") -- default Roblox sparkle texture
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	pe.Speed = NumberRange.new(12, 28)
	pe.Lifetime = NumberRange.new(0.6, 1.4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = holder
	pe:Emit(count or 60)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 24, 3
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
end

local function shard(color, from)
	local p = fxPart({ Size = Vector3.new(1.4, 2.4, 1.4), Color = color, Position = from,
		Orientation = Vector3.new(0, 45, 45) })
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 16, 2
	light.Parent = p
	return p
end

local function flyTo(part, to, seconds)
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = to, Orientation = part.Orientation + Vector3.new(0, 360, 0) }):Play()
end

----------------------------------------------------------------- screen (subtitle, skip)
-- A23-74 (user 2026-10-07: "프롤로그 3d 영상도 무슨 위아래 까만색"): no letterbox bars on PC or phone; the shots fill
-- the screen. Subtitle and skip stay in this device-safe ScreenGui (IgnoreGuiInset); the subtitle gets the UIKit
-- dark-world text rim so it reads over bright sky without a black strip behind it
local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroGui"
	gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the skip label (child) must draw over its ZIndex-5 button
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.BackgroundTransparency = 1
	-- the bottom 12 px above the Skip button (bottom-right, 48 tall, 12 from the edge): on phones the line ran behind it
	-- ("...broke." under Skip, user via review 2026-10-07)
	sub.AnchorPoint, sub.Position, sub.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -72), UDim2.new(0.86, 0, 0.12, 0)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled, sub.TextWrapped = true, true
	sub.TextColor3, sub.TextStrokeTransparency = Color3.new(1, 1, 1), 0.2
	sub.TextTransparency = 1
	sub.Text = ""
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize, cap.MinTextSize = 34, 16
	cap.Parent = sub
	sub.Parent = gui
	-- A23-74: navy rim + white-cream face (UIKit Title, A23-35) instead of the thin legacy shadow; kept as the fallback
	if UIKit and type(UIKit.StyleText) == "function" then pcall(UIKit.StyleText, sub, "Title") end
	local skip
	local function onSkip()
		if os.clock() - state.OpenedAt >= SKIP_GRACE then Intro.Finish() end
	end
	if UIKit and type(UIKit.ArtButton) == "function" then
		local ok, b = pcall(UIKit.ArtButton, "Chip", {
			Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -12),
			Size = UDim2.fromOffset(170, 48), Text = Intro.SkipText(), TextSize = 18,
			TextStyle = "ink", ZIndex = 5, Parent = gui,
		}, onSkip, { CornerRadius = UDim.new(0.5, 0) })
		if ok then skip = b end
	end
	if not skip then
		skip = Instance.new("TextButton")
		skip.Name = "Skip"
		skip.AnchorPoint, skip.Position, skip.Size = Vector2.new(1, 1), UDim2.new(1, -16, 1, -12), UDim2.fromOffset(170, 48)
		skip.BackgroundColor3, skip.TextColor3 = Color3.fromRGB(245, 232, 200), Color3.fromRGB(60, 40, 20)
		skip.Font, skip.TextSize, skip.Text = Enum.Font.GothamBold, 18, Intro.SkipText()
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = skip
		skip.Parent = gui
		skip.Activated:Connect(onSkip)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	state.Gui, state.Sub = gui, sub
end

local function say(text, big)
	local sub = state.Sub
	if not sub or not sub.Parent then return end
	sub.Text = tostring(text or "")
	sub.TextColor3 = big and SPOT.Gold or Color3.new(1, 1, 1)
	local cap = sub:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then cap.MaxTextSize = big and 52 or 34 end
	sub.TextTransparency = 1
	TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	-- the rim fades with the text (UIKit text style contract: tween StyleStroke with TextTransparency)
	local rim = sub:FindFirstChild("StyleStroke")
	if rim and rim:IsA("UIStroke") then
		rim.Transparency = 1
		TweenService:Create(rim, TweenInfo.new(0.4), { Transparency = 0 }):Play()
	end
end

----------------------------------------------------------------- camera shots
local function shot(token, fromCF, toCF, seconds)
	if state.Token ~= token then return false end
	local cam = workspace.CurrentCamera
	if not cam then return false end
	cam.CameraType = Enum.CameraType.Scriptable
	if state.CamTween then state.CamTween:Cancel() end
	cam.CFrame = fromCF
	state.CamTween = TweenService:Create(cam, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = toCF })
	state.CamTween:Play()
	return true
end

local function wait(token, seconds)
	task.wait(seconds)
	return state.Token == token
end

local function crownPos()
	local map = workspace:FindFirstChild("Map")
	local lm = map and map:FindFirstChild("Landmarks")
	local crown = lm and lm:FindFirstChild("CrownOfBalance")
	if crown and crown:IsA("Model") then
		local ok, cf = pcall(crown.GetPivot, crown)
		if ok then return cf.Position end
	end
	return SPOT.Crown
end

local function run(token)
	local look = CFrame.lookAt
	-- 1. the broken crown in the sky over the Crossroads, front three-quarter (0-6 s)
	local crown = crownPos()
	local c = CROWN_SHOT
	local dir = Vector3.new(-math.sin(c.Side) * math.cos(c.Down), -math.sin(c.Down), -math.cos(c.Side) * math.cos(c.Down))
	if not shot(token, look(crown + dir * c.From, crown + Vector3.new(0, -20, 0)), look(crown + dir * c.To, crown), 5.5) then return end
	if not wait(token, 0.4) then return end
	say(TXT.Lines[1])
	if not wait(token, 5.4) then return end
	-- 2. down into the shard's light column over the fountain (6-11 s)
	fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(90, 3, 3), Color = SPOT.Gold, Transparency = 0.45,
		CFrame = CFrame.new(SPOT.Shard + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	if not shot(token, look(Vector3.new(0, 52, -28), SPOT.Shard), look(Vector3.new(0, 25, -13), SPOT.Shard), 4.5) then return end
	burst(SPOT.Shard, SPOT.Gold, 50)
	if not wait(token, 4.8) then return end
	-- 3. shards fly to the castle of light and the horn den (11-17 s): close cuts only
	say(TXT.Lines[2])
	local gold = shard(SPOT.Gold, SPOT.Halo + Vector3.new(0, 55, 70))
	if not shot(token, look(SPOT.Halo + Vector3.new(18, 14, 95), SPOT.Halo), look(SPOT.Halo + Vector3.new(6, 10, 70), SPOT.Halo), 3) then return end
	flyTo(gold, SPOT.Halo + Vector3.new(0, 2, 4), 2.2)
	if not wait(token, 2.3) then return end
	burst(SPOT.Halo + Vector3.new(0, 2, 4), SPOT.Gold, 80)
	if not wait(token, 0.7) then return end
	local red = shard(SPOT.Red, SPOT.Horns + Vector3.new(0, 55, -70))
	if not shot(token, look(SPOT.Horns + Vector3.new(-18, 14, -95), SPOT.Horns), look(SPOT.Horns + Vector3.new(-6, 10, -70), SPOT.Horns), 3) then return end
	flyTo(red, SPOT.Horns + Vector3.new(0, 2, -4), 2.2)
	if not wait(token, 2.3) then return end
	burst(SPOT.Horns + Vector3.new(0, 2, -4), SPOT.Red, 80)
	if not wait(token, 0.7) then return end
	-- 4. a shard lands in front of my own avatar at the Crossroads (17-22.5 s)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local base = root and root.CFrame or CFrame.new(0, 3, -25)
	local front = base.LookVector * Vector3.new(1, 0, 1)
	front = front.Magnitude > 0.1 and front.Unit or Vector3.new(0, 0, 1)
	local me = base.Position
	local landAt = me + front * 5 + Vector3.new(0, -1.5, 0)
	say(TXT.Lines[3])
	local mine = shard(SPOT.White, landAt + Vector3.new(0, 45, 0))
	if not shot(token, look(me + front * 14 + Vector3.new(0, 5, 0), me + Vector3.new(0, 1, 0)),
		look(me + front * 10 + Vector3.new(3, 2.5, 0), me + Vector3.new(0, 1.5, 0)), 5) then return end
	flyTo(mine, landAt, 1.6)
	if not wait(token, 1.7) then return end
	burst(landAt, SPOT.White, 90)
	if not wait(token, 0.6) then return end
	say(TXT.Ask, true)
	if not wait(token, 2.6) then return end
	Intro.Finish()
end

----------------------------------------------------------------- open / close
function Intro.Finish()
	if not state.Open then return end
	state.Token += 1
	state.Open = false
	if state.CamTween then state.CamTween:Cancel() end -- a running tween would keep moving the restored camera
	state.CamTween = nil
	pcall(ContextActionService.UnbindAction, ContextActionService, "HHC_IntroSkip")
	if state.Gui then state.Gui:Destroy() end
	if state.Folder then state.Folder:Destroy() end
	state.Gui, state.Sub, state.Folder = nil, nil, nil
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	end
	setMovement(true)
	holdWorld(false)
	if not state.Replay and player:GetAttribute("IntroSeen") ~= true then
		pcall(function() Net.Get("IntroSeen"):FireServer() end)
	end
	state.Done = true
	local fp = C and C.FactionPicker
	if type(fp) == "table" and type(fp.Refresh) == "function" then pcall(fp.Refresh) end
	if UIKit and type(UIKit.FlushBanners) == "function" then pcall(UIKit.FlushBanners) end
end

-- replay = from the menu (no saved flag); the menu checks the safe-zone rule before calling
function Intro.Play(replay)
	if state.Open then return false end
	if player:GetAttribute("DataLoaded") ~= true then return false end
	state.Open, state.Replay = true, replay == true
	state.Token += 1
	local token = state.Token
	local folder = Instance.new("Folder")
	folder.Name = "HHC_Intro"
	folder.Parent = workspace.CurrentCamera or workspace
	state.Folder = folder
	local okGui, errGui = pcall(buildGui)
	if not okGui then Util.Warn("Intro", "gui failed: " .. tostring(errGui)) end
	state.OpenedAt = os.clock()
	ContextActionService:BindActionAtPriority("HHC_IntroSkip", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and os.clock() - state.OpenedAt >= SKIP_GRACE then Intro.Finish() end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA)
	setMovement(false)
	holdWorld(true)
	task.spawn(function()
		local ok, err = pcall(run, token)
		if not ok then
			Util.Warn("Intro", "opening failed: " .. tostring(err))
			if state.Token == token then Intro.Finish() end
		end
	end)
	return true
end

-- "Skip ▶ (Enter)" where keys are shown (Keybinds.ShowsKeys), else "Skip ▶"
function Intro.SkipText()
	local kb = C and C.Keybinds
	local shows = UserInputService.KeyboardEnabled == true
	if type(kb) == "table" and type(kb.ShowsKeys) == "function" then shows = kb.ShowsKeys() == true end
	return TXT.Skip .. " ▶" .. (shows and TXT.SkipKey or "")
end

function Intro.Init(c)
	C = c
	UIKit = c and c.UIKit
end

function Intro.Start()
	-- respawning mid-opening: give the camera back right away
	player.CharacterAdded:Connect(function()
		if state.Open then Intro.Finish() end
	end)
	task.spawn(function()
		local t0 = os.clock()
		while player:GetAttribute("DataLoaded") ~= true and os.clock() - t0 < 60 do task.wait(0.2) end
		if not needsFirstIntro() then state.Done = true; return end
		local waited = os.clock()
		while not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() - waited < 10 do
			task.wait(0.2)
		end
		task.wait(0.5)
		if not needsFirstIntro() or not Intro.Play(false) then state.Done = true end
	end)
	print("[Intro] started")
end

return Intro
