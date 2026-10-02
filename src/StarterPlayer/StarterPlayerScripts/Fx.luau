-- Fx.luau : client-side effects for Halo & Horns (G11).
-- Plays every server "Fx" remote kind (TECH_SPEC §5), pooled damage numbers, class swing / release shapes, camera
-- shake, built-in sounds, the hurt edge flash, the own level-up "next unlock" announce (addendum A7-3) and the kill
-- combo counter. Everything here is local-only and purely cosmetic; the server never trusts anything from it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local LocalPlayer = Players.LocalPlayer

local Fx = {}

local C = nil -- client registry (set in Init)

----------------------------------------------------------------- constants
local VIS = Config.Visuals or {}
local CULL_DISTANCE = VIS.FxCullDistance or 150
local POPUP_COUNT = math.max(5, VIS.MaxDamagePopups or 25)
local HUGE_SCALE = VIS.HugeNumberScale or 2.5
local SHAKE_OWN = VIS.ShakeOwnRelease or 0.6
local SHAKE_NEAR = VIS.ShakeNearRelease or 0.25
local SHAKE_NEAR_DIST = VIS.ShakeNearDistance or 40

local COMBO_CFG = Config.Combo or {}
local COMBO_RESET = COMBO_CFG.ResetSeconds or 4
local COMBO_MILESTONES = COMBO_CFG.Milestones or {}
local COMBO_SHOW_AT = 5

local NUMBER_W, NUMBER_H = 140, 44
local NUMBER_RISE = 3
local NUMBER_LIFE = 0.8

-- addendum A9-2 hit feel (white flash on my hits, crit / my-release number pop, number merging)
local HIT_CFG = Config.HitFeel or {}
local FLASH_TIME = HIT_CFG.FlashTime or 0.06
local POP_SCALE = HIT_CFG.PopScale or 1.4
local POP_TIME = HIT_CFG.PopTime or 0.1
local MERGE_WINDOW = HIT_CFG.MergeWindow or 0.25
local MERGE_DIST = 3 -- studs: numbers spawned this close (and within MERGE_WINDOW) add into one label
local FLASH_DIST = 3 -- studs: monsters whose root is this close to one of my hit positions flash white

local WHITE = Color3.new(1, 1, 1)
local COLOR_CRIT = Color3.fromRGB(255, 225, 60)
local COLOR_PVP = Color3.fromRGB(255, 70, 70)
local COLOR_HURT = Color3.fromRGB(255, 55, 55)
local COLOR_GOLD = Color3.fromRGB(255, 210, 60)
local COLOR_XP = Color3.fromRGB(90, 170, 255)
local COLOR_PERFECT = Color3.fromRGB(255, 215, 70)
local COLOR_AUTO = Color3.fromRGB(215, 215, 225)
local COLOR_FALLBACK = Color3.fromRGB(175, 175, 185)
local COLOR_STOMP = Color3.fromRGB(255, 50, 40)
local COLOR_DUST = Color3.fromRGB(170, 150, 120)
local COLOR_SMOKE = Color3.fromRGB(35, 25, 40)
local COLOR_FIRE = Color3.fromRGB(255, 140, 50)
local COLOR_PILLAR = Color3.fromRGB(255, 240, 150)
local COLOR_HORNS_WIN = Color3.fromRGB(220, 50, 60)

local SOUND_MIN_GAP = 0.06 -- seconds between two plays of the same sound
local SOUND_VOLUME = { Swing = 0.35, Release = 0.6, Coin = 0.35, Click = 0.4 }

local SHAKE_BIND_NAME = "HaloHornsFxShake"
local MAX_SHAKE = 3

local FONT_NUMBER = Enum.Font.GothamBlack
local MIN_TEXT_SIZE = (Config.UI and Config.UI.MinTextSize) or 11 -- addendum M1

-- A7-3 level-up announce (private Korean strings; client-only feature).
-- "Unlocked" / "LevelUpNext" live in Config.Text (G1); the private copies below are fallbacks only.
local TXT_UNLOCK_AUTO = "자동 공격"
local TXT_UNLOCK_ZONE = "%s 입장"
local TXT_UNLOCK_REBIRTH = "환생"
local TXT_UNLOCKED_FALLBACK = "해금! %s"
local TXT_LEVELUP_NEXT_FALLBACK = "레벨 업! Lv %d · 다음 해금: Lv %d %s"
local TXT_NEXT_UNLOCK = "다음 해금: Lv %d %s"
local TXT_BANK = "금고 +%s"
local TXT_AUTO_RELEASE = "자동 발사"

----------------------------------------------------------------- small helpers
local rng = Random.new()

local lastWarnAt = -math.huge
local function warnThrottled(msg)
	local now = os.clock()
	if now - lastWarnAt < 10 then return end
	lastWarnAt = now
	Util.Warn("Fx", msg)
end

-- task.delay with the callback guarded (effects must never spam the Output)
local function later(seconds, fn)
	task.delay(seconds, function()
		local ok, err = pcall(fn)
		if not ok then warnThrottled("delayed effect failed: " .. tostring(err)) end
	end)
end

local function asVec(v)
	if typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z then return v end
	return nil
end

local function asNum(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function asStr(v, default)
	if type(v) == "string" then return v end
	return default
end

local function isOwn(data)
	return LocalPlayer ~= nil and asNum(data.UserId, -1) == LocalPlayer.UserId
end

local function factionColor(factionId)
	local f = (type(factionId) == "string") and Config.Factions[factionId] or nil
	if type(f) == "table" and typeof(f.Color) == "Color3" then return f.Color end
	return COLOR_FALLBACK
end

local function getOwnRoot()
	local char = LocalPlayer and LocalPlayer.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

local function getPlayerRootPos(userId)
	if type(userId) ~= "number" then return nil end
	local p = Players:GetPlayerByUserId(userId)
	local char = p and p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root.Position end
	return nil
end

local function nearCamera(pos)
	local cam = workspace.CurrentCamera
	if not cam then return true end
	return (cam.CFrame.Position - pos).Magnitude <= CULL_DISTANCE
end

local function myAttr(name, default)
	if not LocalPlayer then return default end
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- calls C.UIKit.<name>(...) safely (UIKit is owned by G10)
local function uiCall(name, ...)
	local ui = C and C.UIKit
	local fn = ui and ui[name]
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warnThrottled("UIKit." .. name .. " failed: " .. tostring(err)) end
end

-- UIKit.Fmt with a local fallback (string.format(Config.Text[key], ...))
local function fmt(key, ...)
	local ui = C and C.UIKit
	if ui and type(ui.Fmt) == "function" then
		local ok, s = pcall(ui.Fmt, key, ...)
		if ok and type(s) == "string" then return s end
	end
	local template = Config.Text[key]
	if type(template) ~= "string" then return "" end
	local ok, s = pcall(string.format, template, ...)
	if ok then return s end
	return template
end

-- Config.Text[key] formatted (via fmt), or the private fallback template when the key is missing
local function textOr(key, fallback, ...)
	if type(Config.Text[key]) == "string" then
		local s = fmt(key, ...)
		if s ~= "" then return s end
	end
	local ok, s = pcall(string.format, fallback, ...)
	if ok then return s end
	return fallback
end

-- a display line that may contain "%%" escapes but no arguments
local function plainLine(s)
	if type(s) ~= "string" then return nil end
	local ok, out = pcall(string.format, s)
	if ok then return out end
	return s
end

----------------------------------------------------------------- local effect folder + parts
local fxFolder = nil

local function getFolder()
	local want = workspace.CurrentCamera or workspace
	if fxFolder and fxFolder.Parent == want then return fxFolder end
	if fxFolder then
		local ok = pcall(function()
			fxFolder.Parent = want
		end)
		if ok then return fxFolder end
	end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalFx"
	fxFolder.Parent = want
	return fxFolder
end

-- anchored, non-colliding, non-queryable local part (Neon by default)
local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Neon
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or getFolder()
	return p
end

local function tween(inst, time, props, style, direction, delayTime)
	local info = TweenInfo.new(
		math.max(0, time),
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out,
		0,
		false,
		delayTime or 0
	)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function addLight(part, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = part
	return l
end

----------------------------------------------------------------- ground height (rings sit on the floor)
-- addendum A11-R1: ground raycasts include ONLY Terrain, workspace.Map.Ground and the bridge models
-- (workspace.Map.Decor children named "Bridge_*"); zone floor parts are invisible and non-queryable.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local rayMap = nil
local rayCheckedAt = -math.huge

local function refreshRayFilter(map)
	local list = { workspace.Terrain }
	if map then
		local ground = map:FindFirstChild("Ground")
		if ground then table.insert(list, ground) end
		local decor = map:FindFirstChild("Decor")
		if decor then
			for _, d in decor:GetChildren() do
				if string.sub(d.Name, 1, 7) == "Bridge_" then table.insert(list, d) end
			end
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function groundY(pos)
	local map = workspace:FindFirstChild("Map")
	local now = os.clock()
	if map ~= rayMap or now - rayCheckedAt > 5 then
		rayMap = map
		rayCheckedAt = now
		refreshRayFilter(map)
	end
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), rayParams)
	if hit then return hit.Position.Y end
	return 0.05 -- terrain top is Y = 0 inside zones (A11)
end

----------------------------------------------------------------- effect primitives
-- flat Neon disc on the ground growing to `radius` then fading
local function ring(pos, radius, color, opts)
	opts = opts or {}
	local y = groundY(pos) + 0.12
	local d1 = math.max(0.5, radius * 2)
	local d0 = math.min(d1, opts.StartDiameter or 1)
	local grow = opts.Grow or 0.15
	local fade = opts.Fade or 0.3
	local thick = opts.Thickness or 0.2
	local p = makePart({
		Name = "FxRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thick, d0, d0),
		CFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = opts.Transparency or 0.45,
	})
	tween(p, grow, { Size = Vector3.new(thick, d1, d1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(p, fade, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, grow * 0.6)
	Debris:AddItem(p, grow + fade + 0.2)
	return p
end

-- one-shot particle burst (default texture)
local function burst(pos, color, count, opts)
	opts = opts or {}
	local p = makePart({
		Name = "FxBurst",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(pos),
		Transparency = 1,
	})
	local lifeMax = opts.LifeMax or 1.0
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
	e.LightEmission = opts.LightEmission or 0.7
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.Size or 0.8),
		NumberSequenceKeypoint.new(1, opts.EndSize or 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.StartTransparency or 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(opts.LifeMin or 0.5, lifeMax)
	e.Speed = NumberRange.new(opts.SpeedMin or 8, opts.SpeedMax or 18)
	e.SpreadAngle = opts.Spread or Vector2.new(180, 180)
	e.Acceleration = opts.Acceleration or Vector3.new(0, -10, 0)
	e.Drag = opts.Drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Parent = p
	e:Emit(math.clamp(math.floor(count), 1, 200))
	Debris:AddItem(p, lifeMax + 0.5)
	return p
end

-- vertical Neon light pillar standing on the ground at pos, fading out
local function pillar(pos, height, diameter, color, fadeTime, transparency)
	local gy = groundY(pos)
	local p = makePart({
		Name = "FxPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(pos.X, gy + height / 2, pos.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = transparency or 0.25,
	})
	addLight(p, color, 3, math.clamp(diameter * 5, 12, 40))
	tween(p, fadeTime, {
		Transparency = 1,
		Size = Vector3.new(height, diameter * 0.25, diameter * 0.25),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, fadeTime + 0.1)
	return p
end

-- thin arrow bolt flying from -> to
local function arrowBolt(from, to, time, color, linger)
	local dir = to - from
	if dir.Magnitude < 0.05 then return end
	local unit = dir.Unit
	local p = makePart({
		Name = "FxArrow",
		Size = Vector3.new(0.18, 0.18, 2.4),
		CFrame = CFrame.lookAt(from, from + unit),
		Color = color,
		Transparency = 0.05,
	})
	tween(p, time, { CFrame = CFrame.lookAt(to, to + unit) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	if linger and linger > 0 then
		tween(p, linger, { Transparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, time)
	end
	Debris:AddItem(p, time + (linger or 0) + 0.05)
end

-- glowing orb flying from -> to
local function orb(from, to, time, color)
	local p = makePart({
		Name = "FxOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(from),
		Color = color,
	})
	addLight(p, color, 2, 10)
	tween(p, time, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	Debris:AddItem(p, time + 0.05)
end

-- meteor falling from 60 studs above center to the ground
local function meteor(center, radius, color, fallTime)
	local gy = groundY(center)
	local landing = Vector3.new(center.X, gy + 1, center.Z)
	local start = landing + Vector3.new(0, 60, 0)
	local d = math.clamp(2 + radius * 0.12, 2, 7)
	local ball = makePart({
		Name = "FxMeteor",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(d, d, d),
		CFrame = CFrame.new(start),
		Color = color,
		Transparency = 0.05,
	})
	addLight(ball, color, 4, 24)
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(COLOR_FIRE, color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, d * 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = NumberRange.new(0.25, 0.45)
	trail.Speed = NumberRange.new(1, 3)
	trail.Rate = 80
	trail.Parent = ball
	tween(ball, fallTime, { CFrame = CFrame.new(landing) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(ball, fallTime + 0.05)
end

-- ~12 arrows raining inside the radius over `duration`
local function arrowRain(center, radius, color, duration)
	local count = 12
	local gy = groundY(center)
	for i = 1, count do
		later((i - 1) * (duration / count), function()
			local r = radius * math.sqrt(rng:NextNumber())
			local a = rng:NextNumber(0, math.pi * 2)
			local landing = Vector3.new(center.X + math.cos(a) * r, gy + 0.6, center.Z + math.sin(a) * r)
			local top = landing + Vector3.new(rng:NextNumber(-3, 3), 30, rng:NextNumber(-3, 3))
			arrowBolt(top, landing, 0.2, color, 0.3)
		end)
	end
end

-- falling "feathers" (golden goose result)
local function feathers(pos, color, count)
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(4, 10)
		local p = makePart({
			Name = "FxFeather",
			Size = Vector3.new(0.12, 0.5, 1.1),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.1,
		})
		local target = pos + Vector3.new(math.cos(angle) * dist, rng:NextNumber(-2, 4), math.sin(angle) * dist)
		tween(p, 1.2, {
			CFrame = CFrame.new(target) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
			Transparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(p, 1.3)
	end
end

local function featherPop(pos)
	burst(pos, ColorSequence.new(COLOR_GOLD, WHITE), 6, {
		Size = 0.5,
		SpeedMin = 6,
		SpeedMax = 12,
		LifeMin = 0.4,
		LifeMax = 0.8,
		Acceleration = Vector3.new(0, -8, 0),
	})
end

----------------------------------------------------------------- damage numbers (pooled BillboardGuis)
local pool = {}
local poolCursor = 0
local poolFolderRef = nil

local function buildPool()
	local folder = getFolder()
	for _, e in pool do
		pcall(function()
			e.Part:Destroy()
		end)
	end
	table.clear(pool)
	for i = 1, POPUP_COUNT do
		local part = makePart({
			Name = "FxNumber" .. i,
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
			CFrame = CFrame.new(0, -500, 0),
			Parent = folder,
		})
		local gui = Instance.new("BillboardGui")
		gui.Name = "Number"
		gui.Adornee = part
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.MaxDistance = CULL_DISTANCE
		gui.Size = UDim2.fromOffset(NUMBER_W, NUMBER_H)
		gui.Enabled = false
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = FONT_NUMBER
		label.TextScaled = true
		label.TextColor3 = WHITE
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.25
		label.Text = ""
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = MIN_TEXT_SIZE
		constraint.MaxTextSize = 100
		constraint.Parent = label
		label.Parent = gui
		gui.Parent = part
		pool[i] = { Part = part, Gui = gui, Label = label, Token = 0, Tweens = {} }
	end
	poolFolderRef = folder
	poolCursor = 0
end

local function ensurePool()
	local folder = getFolder()
	if poolFolderRef ~= folder or #pool == 0 or pool[1].Part.Parent ~= folder then
		buildPool()
	end
end

----------------------------------------------------------------- camera shake
local shakeMag, shakeStart, shakeDur = 0, 0, 0
local shakeBound = false

local function stopShake()
	if not shakeBound then return end
	shakeBound = false
	pcall(function()
		RunService:UnbindFromRenderStep(SHAKE_BIND_NAME)
	end)
end

-- runs right after the camera scripts; translation only, so the camera never drifts
local function shakeStep()
	local t = os.clock() - shakeStart
	if t >= shakeDur then
		stopShake()
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local k = shakeMag * (1 - t / shakeDur)
	local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * k
	cam.CFrame = cam.CFrame * CFrame.new(offset)
end

----------------------------------------------------------------- screen GUI bits (hurt flash, combo)
local ownGui = nil
local flashFrames = {}
local flashTweens = {}
local comboLabel = nil
local comboScale = nil
local milestoneLabel = nil
local milestoneToken = 0
local milestoneTween = nil
local combo = 0
local comboToken = 0

local function getGuiRoot()
	local ui = C and C.UIKit
	local g = ui and ui.Gui
	if typeof(g) == "Instance" and g:IsA("LayerCollector") then return g end
	if ownGui and ownGui.Parent then return ownGui end
	local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	ownGui = Instance.new("ScreenGui")
	ownGui.Name = "FxGui"
	ownGui.ResetOnSpawn = false
	ownGui.IgnoreGuiInset = true
	ownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ownGui.DisplayOrder = 11
	ownGui.Parent = pg
	return ownGui
end

local function addTextConstraint(label, maxSize)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = MIN_TEXT_SIZE
	c.MaxTextSize = maxSize or 48
	c.Parent = label
end

local function buildScreenFx()
	local root = getGuiRoot()
	if not root then return end

	-- red screen-edge flash (4 gradient strips, invisible until Hurt)
	local holder = Instance.new("Frame")
	holder.Name = "FxHurtFlash"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 40
	holder.Active = false
	holder.Parent = root
	local function edge(name, size, position, anchor, rotation)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = COLOR_HURT
		f.BackgroundTransparency = 1
		f.Size = size
		f.Position = position
		f.AnchorPoint = anchor
		f.ZIndex = 40
		f.Active = false
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = holder
		table.insert(flashFrames, f)
	end
	edge("Top", UDim2.new(1, 0, 0.14, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90)
	edge("Bottom", UDim2.new(1, 0, 0.14, 0), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90)
	edge("Left", UDim2.new(0.1, 0, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0)
	edge("Right", UDim2.new(0.1, 0, 1, 0), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180)

	-- combo counter at right-center
	comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "FxCombo"
	comboLabel.BackgroundTransparency = 1
	comboLabel.AnchorPoint = Vector2.new(1, 0.5)
	comboLabel.Position = UDim2.new(1, -24, 0.42, 0)
	comboLabel.Size = UDim2.fromOffset(150, 56)
	comboLabel.Font = FONT_NUMBER
	comboLabel.TextScaled = true
	comboLabel.TextXAlignment = Enum.TextXAlignment.Right
	comboLabel.TextColor3 = COLOR_GOLD
	comboLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	comboLabel.TextStrokeTransparency = 0.2
	comboLabel.Text = ""
	comboLabel.Visible = false
	comboLabel.ZIndex = 5
	addTextConstraint(comboLabel, 56)
	comboScale = Instance.new("UIScale")
	comboScale.Scale = 1
	comboScale.Parent = comboLabel
	comboLabel.Parent = root

	-- milestone text ("좋아요! x10"), shown big for 1 s above the counter
	milestoneLabel = Instance.new("TextLabel")
	milestoneLabel.Name = "FxComboMilestone"
	milestoneLabel.BackgroundTransparency = 1
	milestoneLabel.AnchorPoint = Vector2.new(1, 0.5)
	milestoneLabel.Position = UDim2.new(1, -24, 0.42, -62)
	milestoneLabel.Size = UDim2.fromOffset(420, 64)
	milestoneLabel.Font = FONT_NUMBER
	milestoneLabel.TextScaled = true
	milestoneLabel.TextXAlignment = Enum.TextXAlignment.Right
	milestoneLabel.TextColor3 = COLOR_PERFECT
	milestoneLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	milestoneLabel.TextStrokeTransparency = 0.1
	milestoneLabel.Text = ""
	milestoneLabel.Visible = false
	milestoneLabel.ZIndex = 5
	addTextConstraint(milestoneLabel, 64)
	milestoneLabel.Parent = root
end

local function flashEdges(color)
	if #flashFrames == 0 then return end
	for _, t in flashTweens do
		t:Cancel()
	end
	table.clear(flashTweens)
	for _, f in flashFrames do
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 0.3
		table.insert(flashTweens, tween(f, 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
	end
end

local function updateComboLabel(pop)
	if not comboLabel then return end
	if combo >= COMBO_SHOW_AT then
		comboLabel.Text = "x" .. combo
		comboLabel.Visible = true
		if pop and comboScale then
			comboScale.Scale = 1.25
			tween(comboScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	else
		comboLabel.Visible = false
	end
end

local function showMilestone(text)
	if not milestoneLabel or type(text) ~= "string" then return end
	milestoneToken += 1
	local token = milestoneToken
	if milestoneTween then milestoneTween:Cancel() end
	milestoneLabel.Text = text
	milestoneLabel.TextTransparency = 0
	milestoneLabel.TextStrokeTransparency = 0.1
	milestoneLabel.Visible = true
	milestoneTween = tween(milestoneLabel, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0.7)
	task.delay(1, function()
		if milestoneToken == token and milestoneLabel then
			milestoneLabel.Visible = false
		end
	end)
end

local function bumpCombo()
	combo += 1
	comboToken += 1
	local token = comboToken
	task.delay(COMBO_RESET, function()
		if comboToken == token then
			combo = 0
			updateComboLabel(false)
		end
	end)
	updateComboLabel(true)
	for _, m in COMBO_MILESTONES do
		if type(m) == "table" and m[1] == combo then
			showMilestone(m[2])
		end
	end
end

----------------------------------------------------------------- own level-up announce (A7-3)
local lastLevelSeen = nil

-- { [level] = { text, ... } }, { [level] = { zoneId, ... } } derived from Config only
local function buildUnlocks()
	local list = {}
	local zonesAt = {}
	local function add(level, text)
		if type(level) ~= "number" or level <= 1 or type(text) ~= "string" then return end
		local entry = list[level]
		if entry then
			table.insert(entry, text)
		else
			list[level] = { text }
		end
	end
	add(Config.Combat.AutoUnlockLevel, TXT_UNLOCK_AUTO)
	for _, zoneId in Config.ZoneOrder do
		local z = Config.Zones[zoneId]
		if type(z) == "table" and z.Town ~= true and type(z.MinLevel) == "number" and z.MinLevel > 1 then
			add(z.MinLevel, string.format(TXT_UNLOCK_ZONE, tostring(z.Name)))
			zonesAt[z.MinLevel] = zonesAt[z.MinLevel] or {}
			table.insert(zonesAt[z.MinLevel], zoneId)
		end
	end
	local tier = asNum(myAttr("WeaponTier", 1), 1)
	local classId = asStr(myAttr("Class", "Warrior"), "Warrior")
	local factionId = asStr(myAttr("Faction", "None"), "None")
	for t, w in Config.Weapons do
		if t > tier and type(w) == "table" then
			add(w.MinLevel, Config.WeaponName(t, classId, factionId))
		end
	end
	add(Config.RebirthLevel(asNum(myAttr("Rebirths", 0), 0)), TXT_UNLOCK_REBIRTH)
	return list, zonesAt
end

local function announceLevelUp(level)
	level = math.floor(level)
	local prev = lastLevelSeen
	if type(prev) ~= "number" or prev >= level then prev = level - 1 end
	prev = math.max(prev, level - 200)
	lastLevelSeen = level

	local unlocks, zonesAt = buildUnlocks()
	local reached, reachedZones = {}, {}
	for lvl = prev + 1, level do
		local u = unlocks[lvl]
		if u then
			for _, text in u do table.insert(reached, text) end
		end
		local z = zonesAt[lvl]
		if z then
			for _, zoneId in z do table.insert(reachedZones, zoneId) end
		end
	end
	local nextLevel = nil
	for lvl in unlocks do
		if lvl > level and (nextLevel == nil or lvl < nextLevel) then nextLevel = lvl end
	end
	local nextText = nil
	if nextLevel then
		nextText = string.format(TXT_NEXT_UNLOCK, nextLevel, table.concat(unlocks[nextLevel], ", "))
	end

	local base = fmt("LevelUp", level)
	if #reached > 0 then
		uiCall("Announce", base .. " · " .. string.format(TXT_UNLOCKED, table.concat(reached, ", ")))
		if nextText then
			uiCall("Toast", nextText, "info", 4)
		end
		-- crown-shard story one-liners, only at zone unlocks and only before the first rebirth
		local lines = Config.StoryLines
		if type(lines) == "table" and asNum(myAttr("Rebirths", 0), 0) == 0 then
			local delayT = 1.2
			for _, zoneId in reachedZones do
				local line = plainLine(lines[zoneId])
				if line and line ~= "" then
					later(delayT, function()
						uiCall("Toast", line, "info", 5)
					end)
					delayT += 1.5
				end
			end
		end
	elseif nextText then
		uiCall("Announce", base .. " · " .. nextText)
	else
		uiCall("Announce", base)
	end
end

----------------------------------------------------------------- hit numbers
local function showHits(hits, own)
	if type(hits) ~= "table" then return end
	local scaleMult = own and 1 or 0.85
	local shown = 0
	for _, h in hits do
		if shown >= POPUP_COUNT then break end
		if type(h) == "table" then
			local p = asVec(h.P)
			local a = asNum(h.A, 0)
			if p then
				shown += 1
				local jitter = Vector3.new(rng:NextNumber(-0.8, 0.8), 2 + rng:NextNumber(0, 0.6), rng:NextNumber(-0.8, 0.8))
				local kind = h.K
				if kind == "P" then
					Fx.ShowNumber(p + jitter, Util.FormatNumber(a), COLOR_PVP, 1.15 * scaleMult)
				elseif kind == "G" then
					Fx.ShowNumber(p + jitter, "+" .. Util.FormatNumber(a), COLOR_GOLD, 0.8)
					featherPop(p)
				elseif h.C == true then
					Fx.ShowNumber(p + jitter, Util.FormatNumber(a) .. "!", COLOR_CRIT, 1.45 * scaleMult)
				else
					Fx.ShowNumber(p + jitter, Util.FormatNumber(a), WHITE, scaleMult)
				end
			end
		end
	end
end

local function validTargets(list)
	local out = {}
	if type(list) ~= "table" then return out end
	for _, v in list do
		local p = asVec(v)
		if p then
			table.insert(out, p)
			if #out >= 8 then break end
		end
	end
	return out
end

----------------------------------------------------------------- kind handlers
local handlers = {}

handlers.Swing = function(data)
	local own = isOwn(data)
	if own then Fx.PlaySound("Swing") end
	local pos = asVec(data.Pos)
	local from = asVec(data.From) or pos
	if not pos then return end
	if not nearCamera(pos) and not (from and nearCamera(from)) then return end
	local classId = asStr(data.Class, "Warrior")
	local color = factionColor(data.Faction)
	local radius = math.clamp(asNum(data.Radius, 0), 0, 60)
	local targets = validTargets(data.Targets)
	local hits = data.Hits

	if classId == "Mage" then
		local target = targets[1]
		if target and from and (target - from).Magnitude > 0.5 then
			orb(from, target, 0.2, color)
			later(0.2, function()
				ring(target, math.max(radius, 2), color, { Grow = 0.15, Fade = 0.3, Transparency = own and 0.4 or 0.6 })
				showHits(hits, own)
			end)
		else
			-- whiff: a small fizzle at the caster
			ring(from or pos, 2, color, { Grow = 0.1, Fade = 0.2, Transparency = 0.6 })
			showHits(hits, own)
		end
	elseif classId == "Archer" then
		local any = false
		if from then
			for _, target in targets do
				if (target - from).Magnitude > 0.5 then
					arrowBolt(from, target, 0.15, color, 0)
					any = true
				end
			end
		end
		if any then
			later(0.15, function()
				showHits(hits, own)
			end)
		else
			showHits(hits, own)
		end
	else
		ring(pos, math.max(radius, 1), color, { Grow = 0.15, Fade = 0.25, Transparency = own and 0.45 or 0.65 })
		showHits(hits, own)
	end
end

handlers.Release = function(data)
	local own = isOwn(data)
	local pos = asVec(data.Pos)
	if not pos then
		if own then
			Fx.PlaySound("Release")
			Fx.Shake(SHAKE_OWN, 0.35)
		end
		return
	end
	local classId = asStr(data.Class, "Warrior")
	local radius = math.clamp(asNum(data.Radius, 8), 1, 200)
	local perfect = data.Perfect == true
	local auto = data.Auto == true
	local color = perfect and COLOR_PERFECT or factionColor(data.Faction)
	local visible = nearCamera(pos)
	local impactDelay = 0
	if classId == "Mage" then
		impactDelay = 0.35
		if visible then meteor(pos, radius, color, impactDelay) end
	elseif classId == "Archer" then
		impactDelay = 0.4
		if visible then arrowRain(pos, radius, color, impactDelay) end
	end

	local function impact()
		if visible then
			-- shockwave ring always sized exactly to Radius
			ring(pos, radius, color, { Grow = 0.25, Fade = 0.45, Transparency = 0.3, Thickness = 0.3, StartDiameter = 2 })
			local gpos = Vector3.new(pos.X, groundY(pos) + 0.5, pos.Z)
			if classId == "Mage" then
				burst(gpos, ColorSequence.new(COLOR_FIRE, color), 40, {
					Size = 1.4, SpeedMin = 14, SpeedMax = 26, LifeMin = 0.4, LifeMax = 0.8, LightEmission = 1,
					Spread = Vector2.new(90, 90), Acceleration = Vector3.new(0, -6, 0), Drag = 3,
				})
			elseif classId == "Archer" then
				burst(gpos, color, 20, {
					Size = 0.6, SpeedMin = 8, SpeedMax = 16, LifeMin = 0.3, LifeMax = 0.6,
					Spread = Vector2.new(90, 90), Acceleration = Vector3.new(0, -10, 0),
				})
			else
				burst(gpos, COLOR_DUST, 45, {
					Size = 1.6, EndSize = 2.4, SpeedMin = 20, SpeedMax = 34, LifeMin = 0.5, LifeMax = 0.9,
					LightEmission = 0, StartTransparency = 0.3, Spread = Vector2.new(90, 90),
					Acceleration = Vector3.new(0, -4, 0), Drag = 3,
				})
			end
			showHits(data.Hits, own)
			local total = asNum(data.Total, 0)
			local top = pos + Vector3.new(0, 6, 0)
			if total > 0 then
				Fx.ShowNumber(top, Util.FormatNumber(total), own and COLOR_GOLD or WHITE, HUGE_SCALE)
			end
			if perfect then
				Fx.ShowNumber(top + Vector3.new(0, 3.5, 0), "PERFECT!", COLOR_PERFECT, 1.8)
			elseif auto then
				Fx.ShowNumber(top + Vector3.new(0, 3, 0), TXT_AUTO_RELEASE, COLOR_AUTO, 1.0)
			end
		end
		if own then
			Fx.Shake(SHAKE_OWN, 0.35)
			Fx.PlaySound("Release")
		else
			local root = getOwnRoot()
			if root and (root.Position - pos).Magnitude <= SHAKE_NEAR_DIST then
				Fx.Shake(SHAKE_NEAR, 0.3)
				Fx.PlaySound("Release")
			end
		end
	end

	if impactDelay > 0 then
		later(impactDelay, impact)
	else
		impact()
	end
end

handlers.Hurt = function(data)
	local amount = asNum(data.Amount, 0)
	local char = LocalPlayer and LocalPlayer.Character
	local head = char and char:FindFirstChild("Head")
	local at = nil
	if head and head:IsA("BasePart") then
		at = head.Position + Vector3.new(0, 1.5, 0)
	else
		local p = asVec(data.Pos)
		if p then at = p + Vector3.new(0, 3, 0) end
	end
	if at and amount > 0 then
		local jitter = Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		Fx.ShowNumber(at + jitter, "-" .. Util.FormatNumber(Util.RoundDamage(amount)), COLOR_HURT, 1.1)
	end
	flashEdges(COLOR_HURT)
end

handlers.Reward = function(data)
	bumpCombo()
	Fx.PlaySound("Coin")
	local pos = asVec(data.Pos)
	if not pos or not nearCamera(pos) then return end
	local gold = asNum(data.Gold, 0)
	local xp = asNum(data.XP, 0)
	local golden = data.Golden == true
	local rx, rz = rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)
	if gold > 0 then
		Fx.ShowNumber(pos + Vector3.new(rx, 3.2, rz), "+" .. Util.FormatNumber(gold) .. " G", COLOR_GOLD, golden and 1.6 or 1)
	end
	if xp > 0 then
		Fx.ShowNumber(pos + Vector3.new(rx, 2.0, rz), "+" .. Util.FormatNumber(xp) .. " XP", COLOR_XP, golden and 1.2 or 0.85)
	end
	if golden then
		burst(pos + Vector3.new(0, 1.5, 0), COLOR_GOLD, 40, {
			Size = 0.9, SpeedMin = 10, SpeedMax = 22, LifeMin = 0.6, LifeMax = 1.2, LightEmission = 1,
		})
		ring(pos, 6, COLOR_GOLD, { Grow = 0.2, Fade = 0.4, Transparency = 0.35 })
	end
end

-- a payload position, or the player's live root when the sender had none (it then sends Vector3.zero)
local function eventPos(data)
	local p = asVec(data.Pos)
	if p and p.Magnitude > 0.01 then return p end
	return getPlayerRootPos(data.UserId) or p
end

handlers.LevelUp = function(data)
	local own = isOwn(data)
	local pos = eventPos(data)
	if pos and nearCamera(pos) then
		pillar(pos, 40, 4, COLOR_PILLAR, 1.0)
		burst(pos, COLOR_PILLAR, 25, { Size = 0.7, SpeedMin = 6, SpeedMax = 14, Acceleration = Vector3.new(0, 8, 0), LightEmission = 1 })
	end
	local level = asNum(data.Level, nil)
	if own and level then
		announceLevelUp(level)
	end
end

handlers.Plunder = function(data)
	local from, to = asVec(data.From), asVec(data.To)
	if not from or not to then return end
	if not nearCamera(from) and not nearCamera(to) then return end
	local lift = Vector3.new(0, 1.5, 0)
	for i = 1, 8 do
		later((i - 1) * 0.05, function()
			local mid = (from + to) / 2 + Vector3.new(rng:NextNumber(-2, 2), 5 + rng:NextNumber(0, 3), rng:NextNumber(-2, 2))
			local b = makePart({
				Name = "FxCoin",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = CFrame.new(from + lift),
				Color = COLOR_GOLD,
			})
			tween(b, 0.3, { CFrame = CFrame.new(mid) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tween(b, 0.3, { CFrame = CFrame.new(to + lift) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
			Debris:AddItem(b, 0.65)
		end)
	end
	local amount = asNum(data.Amount, 0)
	if amount > 0 then
		later(0.65, function()
			Fx.ShowNumber(to + Vector3.new(0, 3, 0), Util.FormatNumber(amount) .. " G", COLOR_GOLD, 1)
		end)
	end
end

handlers.Bank = function(data)
	local amount = asNum(data.Amount, 0)
	if amount <= 0 then return end
	uiCall("Toast", string.format(TXT_BANK, Util.FormatNumber(amount)), "reward")
	Fx.PlaySound("Coin")
end

handlers.Upgrade = function(_data)
	Fx.PlaySound("Coin")
	local root = getOwnRoot()
	if not root then return end
	local pos = root.Position
	burst(pos, ColorSequence.new(COLOR_GOLD, WHITE), 40, {
		Size = 0.7, SpeedMin = 6, SpeedMax = 14, LifeMin = 0.6, LifeMax = 1.2, LightEmission = 1,
		Acceleration = Vector3.new(0, 6, 0),
	})
	ring(pos, 5, COLOR_GOLD, { Grow = 0.2, Fade = 0.4, Transparency = 0.35 })
end

handlers.Rebirth = function(data)
	local own = isOwn(data)
	local pos = eventPos(data)
	local mark = asStr(data.Mark, "None")
	if pos and nearCamera(pos) then
		local color = COLOR_PILLAR
		if mark == "Fall" then
			color = Color3.fromRGB(70, 25, 85)
		elseif mark == "Redeem" then
			color = WHITE
		end
		pillar(pos, 80, 8, color, 1.6, 0.2)
		ring(pos, 14, color, { Grow = 0.3, Fade = 0.6, Transparency = 0.3, Thickness = 0.3 })
		if mark == "Fall" then
			burst(pos, COLOR_SMOKE, 50, {
				Size = 3.5, EndSize = 5, SpeedMin = 3, SpeedMax = 8, LifeMin = 1.2, LifeMax = 2.2, LightEmission = 0,
				StartTransparency = 0.2, Acceleration = Vector3.new(0, 4, 0), Spread = Vector2.new(60, 60), Drag = 1,
			})
		elseif mark == "Redeem" then
			burst(pos, WHITE, 60, {
				Size = 1.2, SpeedMin = 10, SpeedMax = 22, LifeMin = 0.8, LifeMax = 1.6, LightEmission = 1,
				Acceleration = Vector3.new(0, 6, 0),
			})
		else
			burst(pos, COLOR_GOLD, 50, {
				Size = 1, SpeedMin = 10, SpeedMax = 22, LifeMin = 0.8, LifeMax = 1.6, LightEmission = 1,
				Acceleration = Vector3.new(0, 6, 0),
			})
		end
	end
	if own then
		Fx.Shake(SHAKE_NEAR, 0.4)
		Fx.PlaySound("Release")
	end
end

handlers.Stomp = function(data)
	local pos = asVec(data.Pos)
	if not pos then return end
	local radius = math.clamp(asNum(data.Radius, 15), 1, 100)
	if nearCamera(pos) then
		ring(pos, radius, COLOR_STOMP, { Grow = 0.2, Fade = 0.5, Transparency = 0.3, Thickness = 0.3, StartDiameter = 2 })
		burst(Vector3.new(pos.X, groundY(pos) + 0.5, pos.Z), COLOR_DUST, 35, {
			Size = 1.8, EndSize = 2.6, SpeedMin = 18, SpeedMax = 30, LifeMin = 0.5, LifeMax = 0.9, LightEmission = 0,
			StartTransparency = 0.3, Spread = Vector2.new(90, 90), Acceleration = Vector3.new(0, -4, 0), Drag = 3,
		})
	end
	local root = getOwnRoot()
	if root and Util.FlatDistance(root.Position, pos) <= radius then
		Fx.Shake(SHAKE_OWN, 0.3)
	end
end

handlers.Rare = function(_data)
	Fx.PlaySound("Coin")
	local root = getOwnRoot()
	if root then
		local pos = root.Position
		burst(pos, ColorSequence.new(COLOR_GOLD, WHITE), 80, {
			Size = 1.1, SpeedMin = 12, SpeedMax = 28, LifeMin = 0.8, LifeMax = 1.6, LightEmission = 1,
			Acceleration = Vector3.new(0, 4, 0),
		})
		ring(pos, 10, COLOR_GOLD, { Grow = 0.3, Fade = 0.6, Transparency = 0.3 })
		pillar(pos, 30, 3, COLOR_GOLD, 1.2)
	end
	uiCall("Announce", fmt("RareToast"))
end

handlers.GooseEnd = function(data)
	local pos = asVec(data.Pos)
	if not pos or not nearCamera(pos) then return end
	local winner = asStr(data.Winner, "Tie")
	local color = WHITE
	if winner == "Halo" then
		color = COLOR_GOLD
	elseif winner == "Horns" then
		color = COLOR_HORNS_WIN
	end
	burst(pos, color, 80, {
		Size = 0.7, SpeedMin = 10, SpeedMax = 25, LifeMin = 1, LifeMax = 2, LightEmission = 0.6,
		Acceleration = Vector3.new(0, -6, 0),
	})
	feathers(pos, color, 12)
end

----------------------------------------------------------------- public API
function Fx.Init(registry)
	C = registry
end

function Fx.Play(kind, data)
	if type(kind) ~= "string" then return end
	local handler = handlers[kind]
	if not handler then return end -- unknown kinds are ignored
	if type(data) ~= "table" then data = {} end
	local ok, err = pcall(handler, data)
	if not ok then warnThrottled(kind .. " failed: " .. tostring(err)) end
end

local soundCache = {}
local soundLast = {}

function Fx.PlaySound(name)
	if type(name) ~= "string" then return end
	local sounds = Config.Sounds
	local id = type(sounds) == "table" and sounds[name] or nil
	if type(id) ~= "string" or id == "" then return end
	local now = os.clock()
	local last = soundLast[name]
	if last and now - last < SOUND_MIN_GAP then return end
	soundLast[name] = now
	pcall(function()
		local s = soundCache[name]
		if not s or not s.Parent then
			s = Instance.new("Sound")
			s.Name = "Fx_" .. name
			s.SoundId = id
			s.Volume = SOUND_VOLUME[name] or 0.5
			s.Parent = SoundService
			soundCache[name] = s
		end
		SoundService:PlayLocalSound(s)
	end)
end

function Fx.ShowNumber(worldPos, text, color, scale)
	if typeof(worldPos) ~= "Vector3" then return end
	if not nearCamera(worldPos) then return end
	local ok, err = pcall(function()
		ensurePool()
		if #pool == 0 then return end
		poolCursor = poolCursor % #pool + 1 -- round robin = the oldest popup is reused first
		local e = pool[poolCursor]
		e.Token += 1
		local token = e.Token
		for _, t in e.Tweens do
			t:Cancel()
		end
		table.clear(e.Tweens)
		local s = math.clamp(asNum(scale, 1), 0.3, 4)
		local w, h = NUMBER_W * s, NUMBER_H * s
		e.Part.CFrame = CFrame.new(worldPos)
		e.Gui.Size = UDim2.fromOffset(w * 1.35, h * 1.35)
		e.Label.Text = tostring(text or "")
		e.Label.TextColor3 = typeof(color) == "Color3" and color or WHITE
		e.Label.TextTransparency = 0
		e.Label.TextStrokeTransparency = 0.25
		e.Gui.Enabled = true
		table.insert(e.Tweens, tween(e.Gui, 0.12, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		table.insert(e.Tweens, tween(e.Part, NUMBER_LIFE, { CFrame = CFrame.new(worldPos + Vector3.new(0, NUMBER_RISE, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		table.insert(e.Tweens, tween(e.Label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Linear, Enum.EasingDirection.In, NUMBER_LIFE - 0.35))
		task.delay(NUMBER_LIFE + 0.02, function()
			if e.Token == token then
				e.Gui.Enabled = false
			end
		end)
	end)
	if not ok then warnThrottled("ShowNumber failed: " .. tostring(err)) end
end

function Fx.Shake(magnitude, duration)
	magnitude = math.min(asNum(magnitude, 0), MAX_SHAKE)
	duration = math.min(asNum(duration, 0), MAX_SHAKE)
	if magnitude <= 0 or duration <= 0 then return end
	local now = os.clock()
	local remaining = 0
	if shakeBound then
		local t = now - shakeStart
		if t < shakeDur then remaining = shakeMag * (1 - t / shakeDur) end
	end
	if magnitude >= remaining then
		shakeMag = magnitude
		shakeStart = now
		shakeDur = duration
	end
	if not shakeBound then
		shakeBound = true
		local ok = pcall(function()
			RunService:BindToRenderStep(SHAKE_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, shakeStep)
		end)
		if not ok then shakeBound = false end
	end
end

function Fx.Start()
	local ok, err = pcall(buildScreenFx)
	if not ok then Util.Warn("Fx", "screen effects not built: " .. tostring(err)) end

	-- level tracking for the A7-3 unlock announce (only decreases are taken from the attribute: rebirth / class reset)
	if LocalPlayer then
		local lvl = LocalPlayer:GetAttribute("Level")
		if type(lvl) == "number" then lastLevelSeen = lvl end
		LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
			local v = LocalPlayer:GetAttribute("Level")
			if type(v) == "number" and (lastLevelSeen == nil or v < lastLevelSeen) then
				lastLevelSeen = v
			end
		end)
	end

	-- the remote normally exists already; never block the other client modules' Start on it
	task.spawn(function()
		local remote = Net.Get("Fx")
		remote.OnClientEvent:Connect(function(kind, data)
			Fx.Play(kind, data)
		end)
	end)

	print("[Fx] started")
end

return Fx
