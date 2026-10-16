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
local RunService = game:GetService("RunService")
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
-- A23-212 (user 10/16 "처음부터 범인이 누구인지 밝히고"): shot 1 = the crown wobbles, Captain Clatter clamps it still, it
-- cracks, he jumps back and reaches out to hold it. 0-won stand-in (the opening is a placeholder): his codex copy
-- (ReplicatedStorage.CodexModels.CaptainClatter = the borrowed Skeleton Knight) + a part crown on a pedestal + a part
-- clamp, Up studs over the sky crown (the broken landmark stays below the frame). Times in s from the shot's start:
-- Wobble until ClampAt, the clamp moves in (ClampAt .. ClampIn) and shuts (Shut s), Crack at CrackAt, the halves drift
-- Gap studs apart over Drift s; Reach = his upper arms' turn (degrees, bone axes) when he reaches out
local SCENE = { Up = 140, CrownR = 3.2, Segs = 10, Wobble = 9, WobbleRate = 7, PedestalH = 5, ClatterH = 12, Stand = 7.5,
	ClampAt = 1.5, ClampIn = 2.2, Shut = 0.3, CrackAt = 3.0, Drift = 1.4, Gap = 5, Hop = 0.9, Back = 1.5, ReachIn = 0.35,
	Gold = Color3.fromRGB(255, 214, 90), Jewel = Color3.fromRGB(120, 200, 255), Steel = Color3.fromRGB(125, 130, 140),
	Stone = Color3.fromRGB(240, 232, 214), White = Color3.fromRGB(255, 250, 225), Model = "CaptainClatter",
	Reach = { L_Upperarm = Vector3.new(-75, 0, 0), R_Upperarm = Vector3.new(-75, 0, 0) }, Length = 6 }
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

-- the part crown: two halves (x < 0 / x >= 0), each a model pivoted on the ring's centre (at)
function SCENE.Crown(at)
	local halves = {}
	for i, name in { "CrownLeft", "CrownRight" } do
		local m = Instance.new("Model")
		m.Name = name
		local core = fxPart({ Name = "Core", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(at) })
		core.Parent = m
		m.PrimaryPart = core
		halves[i] = m
	end
	local r, n = SCENE.CrownR, SCENE.Segs
	local segW = 2 * math.pi * r / n + 0.15
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * 2 * math.pi
		local pos = at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local face = CFrame.lookAt(pos, Vector3.new(at.X, pos.Y, at.Z))
		local half = halves[math.cos(a) < 0 and 1 or 2]
		local band = fxPart({ Name = "Band", Size = Vector3.new(segW, 1.1, 0.35), Color = SCENE.Gold,
			Material = Enum.Material.SmoothPlastic, CFrame = face })
		band.Parent = half
		local tip = fxPart({ Name = "Point", Size = Vector3.new(0.7, 1.2, 0.3), Color = SCENE.Gold,
			Material = Enum.Material.SmoothPlastic, CFrame = face * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(45)) })
		tip.Parent = half
		if k % 2 == 0 then
			local gem = fxPart({ Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), Color = SCENE.Jewel,
				CFrame = face * CFrame.new(0, 0, -0.2) })
			gem.Parent = half
		end
	end
	for _, m in halves do m.Parent = state.Folder end
	return halves
end

-- his codex copy, ClatterH tall, feet on y = floor, at x / z of `at`, facing `toward` (nil when not there)
function SCENE.Clatter(at, floor, toward)
	local folder = ReplicatedStorage:FindFirstChild((Config.Codex and Config.Codex.ModelFolder) or "CodexModels")
	local src = folder and folder:FindFirstChild(SCENE.Model)
	if not src then return nil end
	local ok, m = pcall(function() return src:Clone() end)
	if not ok or not m or not m:IsA("Model") then return nil end
	m.Name = "IntroClatter"
	m.Parent = state.Folder
	pcall(function()
		local _, size = m:GetBoundingBox()
		if size.Y > 0.1 then m:ScaleTo(m:GetScale() * SCENE.ClatterH / size.Y) end
	end)
	local base = CFrame.lookAt(Vector3.new(at.X, floor, at.Z), Vector3.new(toward.X, floor, toward.Z))
	m:PivotTo(base)
	local cf, size = m:GetBoundingBox()
	m:PivotTo(base + Vector3.new(0, floor - (cf.Position.Y - size.Y / 2), 0)) -- feet on the floor
	return m
end

-- the whole set around the ring's centre `at` -> { Halves, Clatter, Home, Jaws, Bar, Mid, ... }
function SCENE.Build(at)
	local s = { At = at, Floor = at.Y - SCENE.PedestalH, Bones = {}, Cracked = false }
	fxPart({ Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 26, 26), Color = SCENE.Stone,
		Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(at.X - 3, s.Floor - 0.5, at.Z) * CFrame.Angles(0, 0, math.rad(90)) })
	fxPart({ Name = "Pedestal", Size = Vector3.new(3, SCENE.PedestalH - 0.55, 3), Color = SCENE.Stone,
		Material = Enum.Material.SmoothPlastic, Position = Vector3.new(at.X, s.Floor + (SCENE.PedestalH - 0.55) / 2, at.Z) })
	s.Halves = SCENE.Crown(at)
	s.Clatter = SCENE.Clatter(at - Vector3.new(SCENE.Stand, 0, 0), s.Floor, at)
	if s.Clatter then
		s.Home = s.Clatter:GetPivot()
		for _, d in s.Clatter:GetDescendants() do
			if d:IsA("Bone") and SCENE.Reach[d.Name] then s.Bones[d.Name] = d end
		end
	end
	-- the clamp: a bar from his hands to two steel jaws that close on the ring's near side
	s.Hold = at - Vector3.new(SCENE.Stand - 2.5, -0.3, 0)
	s.Grip = at - Vector3.new(SCENE.CrownR, 0, 0)
	s.Bar = fxPart({ Name = "ClampBar", Size = Vector3.new(2.4, 0.3, 0.3), Color = SCENE.Steel, Material = Enum.Material.Metal })
	s.Jaws = {
		fxPart({ Name = "Jaw", Size = Vector3.new(0.5, 0.35, 0.9), Color = SCENE.Steel, Material = Enum.Material.Metal }),
		fxPart({ Name = "Jaw", Size = Vector3.new(0.5, 0.35, 0.9), Color = SCENE.Steel, Material = Enum.Material.Metal }),
	}
	s.Mid = at + Vector3.new(-3.5, 1.5, 0)
	return s
end

-- the set at t s into the shot
function SCENE.Pose(s, t)
	local K = SCENE
	-- the crown wobbles (stronger at first), the clamp stills it
	local w = 0
	if t < K.ClampIn then
		w = K.Wobble * math.sin(t * K.WobbleRate) * math.min(1, t / 1.2)
	elseif t < K.ClampIn + K.Shut then
		w = K.Wobble * math.sin(K.ClampIn * K.WobbleRate) * (1 - (t - K.ClampIn) / K.Shut)
	end
	local drift = t >= K.CrackAt and math.clamp((t - K.CrackAt) / K.Drift, 0, 1) or 0
	for i, half in s.Halves do
		local side = i == 1 and -1 or 1
		half:PivotTo(CFrame.new(s.At + Vector3.new(side * drift * K.Gap / 2, -drift * 0.8, 0))
			* CFrame.Angles(0, 0, math.rad(w - side * drift * 14)))
	end
	-- the clamp: in his hands, then onto the ring, the jaws shut
	local move = math.clamp((t - K.ClampAt) / (K.ClampIn - K.ClampAt), 0, 1)
	local shut = math.clamp((t - K.ClampIn) / K.Shut, 0, 1)
	local jawAt = s.Hold:Lerp(s.Grip, move)
	if drift > 0 then jawAt += Vector3.new(-drift * K.Gap / 2, -drift * 0.8, 0) end
	local open = 0.65 - 0.45 * shut
	s.Jaws[1].CFrame = CFrame.new(jawAt + Vector3.new(0, open, 0))
	s.Jaws[2].CFrame = CFrame.new(jawAt - Vector3.new(0, open, 0))
	s.Bar.CFrame = CFrame.new(jawAt - Vector3.new(1.3, 0, 0))
	-- CRACK: the light flashes round, he hops back and reaches out to hold it
	if t >= K.CrackAt and not s.Cracked then
		s.Cracked = true
		burst(s.At, K.White, 40)
	end
	local m = s.Clatter
	if m and m.Parent and s.Home then
		local back = math.clamp((t - K.CrackAt - 0.1) / 0.35, 0, 1)
		local hop = math.sin(math.pi * back) * K.Hop
		m:PivotTo(s.Home * CFrame.new(0, hop, back * K.Back) * CFrame.Angles(math.rad(-6 * back), 0, 0))
		local reach = math.clamp((t - K.CrackAt - 0.15) / K.ReachIn, 0, 1)
		for name, bone in s.Bones do
			local a = K.Reach[name] * reach
			bone.Transform = CFrame.Angles(math.rad(a.X), math.rad(a.Y), math.rad(a.Z))
		end
	end
end

local function run(token)
	local look = CFrame.lookAt
	-- 1. Captain Clatter clamps the wobbling crown still - CRACK (A23-212, 0-6 s); the old sky-crown shot when the set
	-- cannot be built
	local crown = crownPos()
	local okSet, set = pcall(SCENE.Build, crown + Vector3.new(0, SCENE.Up, 0))
	if okSet and set then
		local mid = set.Mid
		if not shot(token, look(mid + Vector3.new(7, 4, 30), mid), look(mid + Vector3.new(4, 2.5, 21), mid), SCENE.Length) then return end
		local t0 = os.clock()
		local said = false
		while os.clock() - t0 < SCENE.Length do
			if state.Token ~= token then return end
			local t = os.clock() - t0
			if not said and t >= 0.4 then
				said = true
				say(TXT.Lines[1])
			end
			local okP, errP = pcall(SCENE.Pose, set, t)
			if not okP then
				Util.Warn("Intro", "clatter scene: " .. tostring(errP))
				break
			end
			RunService.RenderStepped:Wait()
		end
		if not wait(token, math.max(0, SCENE.Length - (os.clock() - t0))) then return end
	else
		local c = CROWN_SHOT
		local dir = Vector3.new(-math.sin(c.Side) * math.cos(c.Down), -math.sin(c.Down), -math.cos(c.Side) * math.cos(c.Down))
		if not shot(token, look(crown + dir * c.From, crown + Vector3.new(0, -20, 0)), look(crown + dir * c.To, crown), 5.5) then return end
		if not wait(token, 0.4) then return end
		say(TXT.Lines[1])
		if not wait(token, 5.4) then return end
	end
	-- 2. down into the shard's light column over the fountain (6-11 s)
	fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(90, 3, 3), Color = SPOT.Gold, Transparency = 0.45,
		CFrame = CFrame.new(SPOT.Shard + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	if not shot(token, look(Vector3.new(0, 52, -28), SPOT.Shard), look(Vector3.new(0, 25, -13), SPOT.Shard), 4.5) then return end
	burst(SPOT.Shard, SPOT.Gold, 50)
	if not wait(token, 4.8) then return end
	-- 3. shards fly to the castle of light and the horn den (11-17 s): close cuts only
	say(TXT.Lines[2])
	local gold = shard(SPOT.Gold, SPOT.Halo + Vector3.new(0, 55, 70))
	-- 10/16: the old (18,14,95) -> (6,10,70) path ended inside the Halo gate mesh (z -361..-330, 48 tall) = a blurred
	-- white close-up; the camera now stays inside the gate, on the town side
	if not shot(token, look(SPOT.Halo + Vector3.new(14, 12, 44), SPOT.Halo), look(SPOT.Halo + Vector3.new(5, 6, 28), SPOT.Halo), 3) then return end
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
