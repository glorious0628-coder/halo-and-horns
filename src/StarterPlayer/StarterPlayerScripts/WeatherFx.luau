-- WeatherFx.luau : A23-105 rain, snow and the evening lamps, on the client (이미지 개발 2026-10-10, 검수: "비·눈·밤 등불").
--   state : ReplicatedStorage.GameState attributes DayPhase = "Dawn" / "Day" / "Dusk" / "Night" and Weather = "Clear" /
--           "Rain" / "Snow" (the server's, 게임성 개발 2; snow only in the northern winter). Until the server writes them
--           nothing changes: no weather, and the lamps are left as the place has them.
--   rain / snow : ONE anchored part (no collision, queries or touch) under workspace.CurrentCamera - so only this client
--           has it - follows the camera T.Above studs over it, a little ahead; its ParticleEmitter drops rain streaks (or
--           slow flakes) over a T.Area box around me. Nothing falls far away, and live particles = Rate x Lifetime stay
--           small (phones: T.TouchK of the rate). Under a roof (a ray up from the camera hits a part within T.RoofRay
--           studs, checked every T.RoofDt s) the rate drops to T.RoofK of it.
--   wet look : a client-made ColorCorrection "WeatherTint" (a little greyer, cooler, darker in rain; a touch brighter in
--           snow) eased in and out over T.Ease s. Never an Atmosphere and never a Lighting property: ZoneLook owns those
--           (A9-3 / A23-30 ban an Atmosphere over the war sky's fog).
--   lamps : at Dusk / Night every Light (PointLight / SpotLight / SurfaceLight) tagged "LampLight" (CollectionService),
--           or inside a part / model tagged so or carrying the attribute LampLight = true, is switched on; at Dawn / Day
--           off (이미지 생성 1 marks the kit's lamps). A light without the mark is never touched.
--   off   : WeatherFx.SetEnabled(false) (Settings 'Weather effects', 게임성 개발 1) stops the rain / snow and the tint; the
--           lamps still follow the time of day (a light, not an effect).
--   Drops and flakes only - no rays (AGENTS). Textures: our own (TEX), not borrowed store assets.
-- API: WeatherFx.Init(C), WeatherFx.Start(), WeatherFx.SetEnabled(on), WeatherFx.IsEnabled(), WeatherFx.Refresh(),
--      WeatherFx.State() -> { Weather, Phase, Enabled, Covered, Plan },
--      pure (the offline test): WeatherFx.Plan(weather, phase, enabled, covered, touch) -> { Rain, Snow, Tint, Lamps },
--      WeatherFx.LampsOn(phase) -> true / false / nil (nil = no phase yet: leave the lamps alone).
-- Studio check hook (UiSandbox photos): the LocalPlayer attributes WeatherPreview / DayPhasePreview stand in for the
-- GameState values; never read outside Studio.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local WeatherFx = {}
local TAG = "WeatherFx"
local C = nil

local T = {
	Above = 32, -- studs over the camera
	Ahead = 14, -- studs ahead of the camera (flat), so the drops fall where I look
	Area = 90, -- the emitter's box side (studs)
	TouchK = 0.55, -- phones: this share of the rate
	RoofRay = 70, -- studs: a part over the camera within this = under a roof
	RoofDt = 0.5, -- seconds between roof checks
	RoofK = 0.12, -- under a roof: this share of the rate
	Ease = 3, -- seconds the tint eases in / out
	LampTag = "LampLight",
	Step = "WeatherFx", -- BindToRenderStep name (after the camera)
	WarnEvery = 10,
	-- sizes: a streak as long as Size studs (UiSandbox 10/10: 1.6 with a tall texture was not seen), flakes Size studs
	Rain = { Rate = 420, Life = 0.75, Speed = 85, Size = 2.4 },
	Snow = { Rate = 110, Life = 7, Speed = 7, Size = 0.85 },
	Tint = {
		-- rain: a wet, grey-blue day; snow: cold and a little brighter
		Rain = { TintColor = Color3.fromRGB(226, 234, 246), Saturation = -0.16, Contrast = -0.04, Brightness = -0.03 },
		Snow = { TintColor = Color3.fromRGB(238, 244, 255), Saturation = -0.08, Contrast = -0.02, Brightness = 0.03 },
		Clear = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0, Contrast = 0, Brightness = 0 },
	},
}
WeatherFx.T = T
-- our own textures (검수 10/10, A23-96: not borrowed - a taken-down store asset would leave empty particles), made with
-- PIL: art/ui/Fx_RainStreak.png (128 square - particles are square - thin white line, soft sides, fading tail), art/ui/Fx_SnowFlake.png (128 soft dot)
local TEX = {
	Rain = "rbxassetid://77226041980480",
	Snow = "rbxassetid://117774040305599",
}
-- rain by day / night (UiSandbox 10/10: pale streaks vanished on the bright day sky and clouds; at night they read well):
-- a darker blue-grey by day, the pale glowing streak at Dusk / Night (light emission per phase too)
local COL = {
	Rain = Color3.fromRGB(196, 214, 236),
	RainDay = Color3.fromRGB(104, 122, 156), -- UiSandbox 10/10 5th: (128,146,176) at 35% see-through was still faint
	Snow = Color3.fromRGB(255, 255, 255),
	RainGlow = { Day = 0, Night = 0.2 },
	RainSeeNight = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.2),
		NumberSequenceKeypoint.new(1, 0.35) }),
	RainSeeDay = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.05),
		NumberSequenceKeypoint.new(1, 0.15) }),
}

local S = {
	Started = false, Enabled = true, Weather = "Clear", Phase = nil, Covered = false, RoofAt = 0,
	Part = nil, Rain = nil, Snow = nil, Tint = nil, TintFrom = nil, TintGoal = nil, TintT0 = 0,
	Lamps = {}, -- [Light] = true: the marked lights found so far
	LampsState = nil, -- the on / off last written (nil = never)
	Bound = false, Plan = nil,
}

----------------------------------------------------------------- pure (the offline test runs these)
-- the lamps for a time of day: on at Dusk / Night, off at Dawn / Day, nil when the phase is unknown (leave them)
function WeatherFx.LampsOn(phase)
	if phase == "Dusk" or phase == "Night" then return true end
	if phase == "Dawn" or phase == "Day" then return false end
	return nil
end

-- what to show: particle rates (per second), the tint name, the lamps
function WeatherFx.Plan(weather, phase, enabled, covered, touch)
	local plan = { Rain = 0, Snow = 0, Tint = "Clear", Lamps = WeatherFx.LampsOn(phase) }
	if enabled ~= true then return plan end
	local k = (covered and T.RoofK or 1) * (touch and T.TouchK or 1)
	if weather == "Rain" then
		plan.Rain, plan.Tint = math.floor(T.Rain.Rate * k + 0.5), "Rain"
	elseif weather == "Snow" then
		plan.Snow, plan.Tint = math.floor(T.Snow.Rate * k + 0.5), "Snow"
	end
	return plan
end

----------------------------------------------------------------- helpers
-- a failing step warns at most once every T.WarnEvery s (it runs every frame)
local function warnOnce(msg)
	local now = os.clock()
	if now - (S.WarnAt or -math.huge) < T.WarnEvery then return end
	S.WarnAt = now
	warn("[" .. TAG .. "] " .. tostring(msg))
end

local function gameState()
	return ReplicatedStorage:FindFirstChild("GameState")
end

local function readState()
	local gs = gameState()
	local weather = gs and gs:GetAttribute("Weather")
	local phase = gs and gs:GetAttribute("DayPhase")
	if RunService:IsStudio() then
		local lp = Players.LocalPlayer
		local w, p = lp and lp:GetAttribute("WeatherPreview"), lp and lp:GetAttribute("DayPhasePreview")
		if type(w) == "string" and w ~= "" then weather = w end
		if type(p) == "string" and p ~= "" then phase = p end
	end
	return (type(weather) == "string" and weather or "Clear"), (type(phase) == "string" and phase or nil)
end

local function emitter(name, def, tex, col, slow)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = tex
	e.Color = ColorSequence.new(col)
	e.Rate = 0
	e.Enabled = false
	e.Lifetime = NumberRange.new(def.Life * 0.85, def.Life)
	e.Speed = NumberRange.new(def.Speed * 0.9, def.Speed * 1.1)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.LightInfluence = 1 -- lit like the world: darker at night
	e.LightEmission = slow and 0.1 or 0.2
	if slow then
		-- flakes: drift and turn a little, fade in and out
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, def.Size * 0.7), NumberSequenceKeypoint.new(1, def.Size) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.SpreadAngle = Vector2.new(18, 18)
		e.Acceleration = Vector3.new(1.2, 0, 0.6)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Rotation = NumberRange.new(0, 360)
		e.Orientation = Enum.ParticleOrientation.FacingCamera
	else
		-- rain: upright streaks (FacingCameraWorldUp keeps the texture's up = world up; UiSandbox 10/10: VelocityParallel
		-- laid the vertical streak along the fall's sideways axis - short horizontal dashes), a little see-through
		e.Size = NumberSequence.new(def.Size)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.2),
			NumberSequenceKeypoint.new(1, 0.35) })
		e.SpreadAngle = Vector2.new(4, 4)
		e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	end
	e.Parent = S.Part
	return e
end

local function build()
	local cam = workspace.CurrentCamera
	if not cam then return false end
	if S.Part and S.Part.Parent == cam then return true end
	local p = Instance.new("Part")
	p.Name = "WeatherFxEmitter"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(T.Area, 1, T.Area)
	S.Part = p
	S.Rain = emitter("Rain", T.Rain, TEX.Rain, COL.Rain, false)
	S.Snow = emitter("Snow", T.Snow, TEX.Snow, COL.Snow, true)
	p.Parent = cam
	return true
end

local function tint()
	if S.Tint and S.Tint.Parent == Lighting then return S.Tint end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "WeatherTint"
	local clear = T.Tint.Clear -- starts neutral; easeTint moves it
	cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = clear.TintColor, clear.Saturation, clear.Contrast, clear.Brightness
	cc.Enabled = true
	cc.Parent = Lighting
	S.Tint = cc
	return cc
end

local function tintValues(name)
	local v = T.Tint[name] or T.Tint.Clear
	return { TintColor = v.TintColor, Saturation = v.Saturation, Contrast = v.Contrast, Brightness = v.Brightness }
end

local function easeTint(name)
	local cc = tint()
	S.TintFrom = { TintColor = cc.TintColor, Saturation = cc.Saturation, Contrast = cc.Contrast, Brightness = cc.Brightness }
	S.TintGoal, S.TintT0 = tintValues(name), os.clock()
end

local function stepTint()
	local goal, from = S.TintGoal, S.TintFrom
	if not (goal and from and S.Tint) then return end
	local t = math.clamp((os.clock() - S.TintT0) / T.Ease, 0, 1)
	local k = 0.5 - math.cos(t * math.pi) / 2
	S.Tint.TintColor = from.TintColor:Lerp(goal.TintColor, k)
	S.Tint.Saturation = from.Saturation + (goal.Saturation - from.Saturation) * k
	S.Tint.Contrast = from.Contrast + (goal.Contrast - from.Contrast) * k
	S.Tint.Brightness = from.Brightness + (goal.Brightness - from.Brightness) * k
	if t >= 1 then S.TintFrom, S.TintGoal = nil, nil end
end

-- a part over the camera within T.RoofRay studs (my character and the emitter left out)
local function underRoof(cam)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { cam }
	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	if char then table.insert(skip, char) end
	params.FilterDescendantsInstances = skip
	params.IgnoreWater = true
	local hit = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, T.RoofRay, 0), params)
	return hit ~= nil and hit.Instance ~= nil and hit.Instance.Transparency < 0.9
end

----------------------------------------------------------------- lamps
local function addLight(light)
	if light:IsA("Light") then S.Lamps[light] = true end
end

-- a marked instance: a Light itself, or every Light inside a marked part / model
local function addMarked(inst)
	if inst:IsA("Light") then
		addLight(inst)
		return
	end
	for _, d in inst:GetDescendants() do addLight(d) end
end

local function isMarked(inst)
	return CollectionService:HasTag(inst, T.LampTag) or inst:GetAttribute(T.LampTag) == true
end

local function scanLamps()
	for _, inst in CollectionService:GetTagged(T.LampTag) do addMarked(inst) end
	for _, d in workspace:GetDescendants() do
		if d:GetAttribute(T.LampTag) == true then addMarked(d) end
	end
end

-- a light added later inside a marked part / model, or a newly marked instance
local function onAdded(d)
	if isMarked(d) then
		addMarked(d)
		if S.LampsState ~= nil then
			for light in S.Lamps do
				if light.Parent then light.Enabled = S.LampsState end
			end
		end
		return
	end
	if d:IsA("Light") then
		local p = d.Parent
		while p and p ~= workspace do
			if isMarked(p) then
				S.Lamps[d] = true
				if S.LampsState ~= nil then d.Enabled = S.LampsState end
				return
			end
			p = p.Parent
		end
	end
end

local function setLamps(on)
	if on == nil or on == S.LampsState then return end
	S.LampsState = on
	for light in S.Lamps do
		if light.Parent then
			light.Enabled = on
		else
			S.Lamps[light] = nil
		end
	end
end

----------------------------------------------------------------- apply
local function apply()
	local plan = WeatherFx.Plan(S.Weather, S.Phase, S.Enabled, S.Covered, UserInputService.TouchEnabled)
	local old = S.Plan
	S.Plan = plan
	setLamps(plan.Lamps)
	if not build() then return end
	S.Rain.Rate, S.Rain.Enabled = plan.Rain, plan.Rain > 0
	local night = plan.Lamps == true -- Dusk / Night
	S.Rain.Color = ColorSequence.new(night and COL.Rain or COL.RainDay)
	S.Rain.LightEmission = night and COL.RainGlow.Night or COL.RainGlow.Day
	-- by day the streak is less see-through, a little longer and only half lit (the sun washed it out)
	S.Rain.LightInfluence = night and 1 or 0.5
	S.Rain.Transparency = night and COL.RainSeeNight or COL.RainSeeDay
	S.Rain.Size = NumberSequence.new(night and T.Rain.Size or T.Rain.Size * 1.25)
	S.Snow.Rate, S.Snow.Enabled = plan.Snow, plan.Snow > 0
	if not old or old.Tint ~= plan.Tint then easeTint(plan.Tint) end
end

local function onRender()
	local cam = workspace.CurrentCamera
	stepTint()
	local plan = S.Plan
	if not (cam and plan) or (plan.Rain <= 0 and plan.Snow <= 0) then return end -- nothing falls: nothing to move
	if S.Part and S.Part.Parent ~= cam then
		S.Part = nil
		apply()
	end
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.zero
	if S.Part then S.Part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, T.Above, 0) + look * T.Ahead) end
	local now = os.clock()
	if now - S.RoofAt >= T.RoofDt then
		S.RoofAt = now
		local covered = underRoof(cam)
		if covered ~= S.Covered then
			S.Covered = covered
			apply()
		end
	end
end

local function refresh()
	S.Weather, S.Phase = readState()
	apply()
end

----------------------------------------------------------------- public
function WeatherFx.SetEnabled(on)
	S.Enabled = on ~= false
	if S.Started then
		local ok, err = pcall(apply)
		if not ok then warnOnce(err) end
	end
end

function WeatherFx.IsEnabled()
	return S.Enabled
end

function WeatherFx.Refresh()
	local ok, err = pcall(refresh)
	if not ok then warnOnce(err) end
end

function WeatherFx.State()
	return { Weather = S.Weather, Phase = S.Phase, Enabled = S.Enabled, Covered = S.Covered, Plan = S.Plan }
end

function WeatherFx.Init(registry)
	C = registry
end

function WeatherFx.Start()
	if S.Started then return end
	S.Started = true
	-- the marked lamps already in the world (one pass, off the start path), then every one added later
	task.spawn(function()
		local ok, err = pcall(scanLamps)
		if not ok then warnOnce(err) end
		if S.Plan then
			S.LampsState = nil -- the scan found new lamps: write them all again
			setLamps(S.Plan.Lamps)
		end
	end)
	workspace.DescendantAdded:Connect(function(d)
		local fine, e = pcall(onAdded, d)
		if not fine then warnOnce(e) end
	end)
	CollectionService:GetInstanceAddedSignal(T.LampTag):Connect(function(inst)
		local fine, e = pcall(onAdded, inst)
		if not fine then warnOnce(e) end
	end)
	WeatherFx.Refresh()
	task.spawn(function()
		local gs = ReplicatedStorage:WaitForChild("GameState", 30)
		if not gs then return end
		for _, a in { "Weather", "DayPhase" } do
			gs:GetAttributeChangedSignal(a):Connect(WeatherFx.Refresh)
		end
		WeatherFx.Refresh()
	end)
	if RunService:IsStudio() and Players.LocalPlayer then
		for _, a in { "WeatherPreview", "DayPhasePreview" } do
			Players.LocalPlayer:GetAttributeChangedSignal(a):Connect(WeatherFx.Refresh)
		end
	end
	RunService:BindToRenderStep(T.Step, Enum.RenderPriority.Camera.Value + 2, function()
		local fine, e = pcall(onRender)
		if not fine then warnOnce(e) end
	end)
	S.Bound = true
end

return WeatherFx
