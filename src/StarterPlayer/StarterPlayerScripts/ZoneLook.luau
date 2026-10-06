-- ZoneLook.luau : A23-30 one mood per hunting ground, on the client. The war sky (WarService: Neutral / Dawn / Eclipse,
-- GameState "WarBlessing") picks the base light (A23-29 'B': bright toy world, docs/design/world_blend_2026-10-06.md);
-- the zone I stand in (player attribute "ZoneId") tints it: meadow = bright midday, goblin woods = green shade,
-- skeleton ruins = blue moonlight, pumpkin field = orange-purple dusk, faction towns = faction colour. Monsters always
-- keep sky light on them (EnvironmentDiffuseScale 1), so even the dark places show them clearly.
-- Local only: the client writes its own Lighting values (they never replicate) plus one client-made ColorCorrection
-- "ZoneTint" (WarService keeps its global "WarTint"). Changes ease over T.Tween s. The server's sky tween (round end)
-- writes the same Lighting properties: ZoneLook waits for it to settle (T.Settle s without server writes) and eases
-- back to its own target. ClockTime, fog, bloom, sun rays and the sky box stay the server's (the war sky's meaning).
-- No Atmosphere (A9-3 still bans it: it hides the FogColor war sky).
-- API: ZoneLook.Init(C), ZoneLook.Start(), ZoneLook.Preview(zoneId | nil) (tests: force a zone look, nil = follow me),
--      ZoneLook.Current() -> zone id, sky name. In Studio the LocalPlayer attribute "ZoneLookPreview" (set locally by
--      tools/zone_look_view.py) drives Preview, since a test runner's require() gets its own module copy.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local ZoneLook = {}
local LocalPlayer = Players.LocalPlayer

-- NightBright: under the Eclipse sky a zone may not dim the light below this factor (dark zones at night hid the
-- dark-armoured skeleton knights in the 2026-10-06 UiSandbox shots)
local T = { Tween = 1.5, Settle = 0.6, Retry = 0.25, NightBright = 0.95 }

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- base light per war sky (A23-29 B; Eclipse = the night proposal: blood-red mood, monsters still readable)
local SKY = {
	Neutral = { Brightness = 2.0, Ambient = rgb(110, 108, 106), Outdoor = rgb(128, 126, 124), Exposure = -0.2 },
	Dawn = { Brightness = 2.1, Ambient = rgb(128, 112, 92), Outdoor = rgb(150, 130, 104), Exposure = -0.15 },
	Eclipse = { Brightness = 1.4, Ambient = rgb(100, 62, 78), Outdoor = rgb(115, 76, 92), Exposure = 0.45 },
}
local BASE = { Diffuse = 1.0, Specular = 0.6, Softness = 0.5 }

-- per zone: Ambient / OutdoorAmbient channel factors, sun Brightness factor, exposure added, ZoneTint colour /
-- saturation / contrast / brightness, optional specular (wet moonlit stone). Unknown zones use Default.
local ZONE = {
	SlimeMeadow = { Amb = { 1, 1, 1 }, Bright = 1, Exp = 0, Tint = rgb(255, 255, 255), Sat = 0.1, Con = 0.05, CC = 0 },
	Crossroads = { Amb = { 1.03, 1, 0.97 }, Bright = 1, Exp = 0, Tint = rgb(255, 252, 246), Sat = 0.08, Con = 0.05, CC = 0 },
	GoblinWoods = { Amb = { 0.9, 1.08, 0.88 }, Bright = 0.78, Exp = 0.1, Tint = rgb(228, 246, 220), Sat = 0.12, Con = 0.08,
		CC = 0.02 },
	SkeletonRuins = { Amb = { 0.8, 0.95, 1.3 }, Bright = 0.65, Exp = 0.15, Tint = rgb(198, 212, 255), Sat = -0.12, Con = 0.1,
		CC = 0.02, Specular = 0.8 },
	-- orange low sun through the tint, purple shadows through the ambient
	PumpkinPatch = { Amb = { 1.15, 0.85, 1.25 }, Bright = 0.85, Exp = 0.08, Tint = rgb(255, 205, 170), Sat = 0.2,
		Con = 0.08, CC = 0 },
	-- pale limestone town: dimmer sun so the white tiles do not burn out
	HaloTown = { Amb = { 1.06, 1.04, 0.95 }, Bright = 0.88, Exp = -0.12, Tint = rgb(255, 246, 228), Sat = 0.06, Con = 0.05,
		CC = 0 },
	HornsTown = { Amb = { 1.12, 0.86, 0.9 }, Bright = 0.88, Exp = 0.08, Tint = rgb(255, 218, 214), Sat = 0.1, Con = 0.08,
		CC = 0 },
}
ZONE.Default = ZONE.SlimeMeadow
ZoneLook.Sky, ZoneLook.Zone = SKY, ZONE -- read by tests / the design table

local MANAGED = { "Brightness", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
	"ExposureCompensation", "ShadowSoftness" }

local S = {
	Started = false, Zone = nil, Sky = "Neutral", Preview = nil, Target = nil,
	Tweens = {}, TweenUntil = 0, LastServerWrite = 0, Pending = false, Tint = nil,
}

----------------------------------------------------------------- helpers
local function skyName()
	local gs = ReplicatedStorage:FindFirstChild("GameState")
	local winner = gs and gs:GetAttribute("WarBlessing")
	if winner == "Halo" then return "Dawn" end
	if winner == "Horns" then return "Eclipse" end
	return "Neutral"
end

local function scale(c, f)
	return Color3.new(math.clamp(c.R * f[1], 0, 1), math.clamp(c.G * f[2], 0, 1), math.clamp(c.B * f[3], 0, 1))
end

local function tint()
	if S.Tint and S.Tint.Parent == Lighting then return S.Tint end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZoneTint"
	cc.Parent = Lighting
	S.Tint = cc
	return cc
end

-- { Lighting goal, ZoneTint goal } for the current sky + zone
function ZoneLook.TargetFor(zoneId, sky)
	local base = SKY[sky] or SKY.Neutral
	local z = ZONE[zoneId] or ZONE.Default
	local bright = sky == "Eclipse" and math.max(z.Bright, T.NightBright) or z.Bright
	return {
		Brightness = base.Brightness * bright,
		Ambient = scale(base.Ambient, z.Amb),
		OutdoorAmbient = scale(base.Outdoor, z.Amb),
		EnvironmentDiffuseScale = BASE.Diffuse,
		EnvironmentSpecularScale = z.Specular or BASE.Specular,
		ExposureCompensation = base.Exposure + z.Exp,
		ShadowSoftness = BASE.Softness,
	}, { TintColor = z.Tint, Saturation = z.Sat, Contrast = z.Con, Brightness = z.CC }
end

local function cancelTweens()
	for _, t in S.Tweens do t:Cancel() end
	table.clear(S.Tweens)
end

-- eases Lighting + ZoneTint to the target (seconds = 0: set at once)
local function apply(seconds)
	local zoneId = S.Preview or S.Zone
	S.Sky = skyName()
	local light, cc = ZoneLook.TargetFor(zoneId, S.Sky)
	S.Target = light
	cancelTweens()
	local tintFx = tint()
	if seconds <= 0 then
		for k, v in light do pcall(function() Lighting[k] = v end) end
		for k, v in cc do pcall(function() tintFx[k] = v end) end
		S.TweenUntil = os.clock() + 0.1
		return
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, pair in { { Lighting, light }, { tintFx, cc } } do
		local ok, tw = pcall(TweenService.Create, TweenService, pair[1], info, pair[2])
		if ok then
			table.insert(S.Tweens, tw)
			tw:Play()
		else
			for k, v in pair[2] do pcall(function() pair[1][k] = v end) end
		end
	end
	S.TweenUntil = os.clock() + seconds + 0.1
end

local function differs(name)
	local want = S.Target and S.Target[name]
	if want == nil then return false end
	local have = Lighting[name]
	if typeof(want) == "Color3" then
		return math.abs(have.R - want.R) + math.abs(have.G - want.G) + math.abs(have.B - want.B) > 0.01
	end
	return math.abs(have - want) > 0.01
end

-- one pending re-apply: waits until the server's writes stopped for T.Settle s, then eases to the zone target
local function schedule()
	if S.Pending then return end
	S.Pending = true
	task.spawn(function()
		while os.clock() - S.LastServerWrite < T.Settle do task.wait(T.Retry) end
		S.Pending = false
		local ok, err = pcall(apply, T.Tween)
		if not ok then Util.Warn("ZoneLook", tostring(err)) end
	end)
end

-- a server write (sky tween at round end) landed on a property ZoneLook manages
local function onServerWrite(name)
	if os.clock() < S.TweenUntil or not differs(name) then return end
	S.LastServerWrite = math.max(S.LastServerWrite, os.clock())
	schedule()
end

local function onZone()
	local z = LocalPlayer:GetAttribute("ZoneId")
	z = type(z) == "string" and z or nil
	if z == S.Zone then return end
	S.Zone = z
	if not S.Preview then
		local ok, err = pcall(apply, T.Tween)
		if not ok then Util.Warn("ZoneLook", tostring(err)) end
	end
end

----------------------------------------------------------------- public
function ZoneLook.Preview(zoneId)
	S.Preview = (type(zoneId) == "string" and zoneId ~= "") and zoneId or nil
	local ok, err = pcall(apply, T.Tween)
	if not ok then Util.Warn("ZoneLook", tostring(err)) end
end

function ZoneLook.Current()
	return S.Preview or S.Zone, S.Sky
end

function ZoneLook.Init() end

function ZoneLook.Start()
	if S.Started then return end
	S.Started = true
	S.Zone = LocalPlayer:GetAttribute("ZoneId")
	pcall(apply, 0)
	LocalPlayer:GetAttributeChangedSignal("ZoneId"):Connect(onZone)
	for _, name in MANAGED do
		Lighting:GetPropertyChangedSignal(name):Connect(function() onServerWrite(name) end)
	end
	if RunService:IsStudio() then
		LocalPlayer:GetAttributeChangedSignal("ZoneLookPreview"):Connect(function()
			ZoneLook.Preview(LocalPlayer:GetAttribute("ZoneLookPreview"))
		end)
	end
	-- the war sky changes at a round end; the server's own tween follows (onServerWrite) but the base changes now
	task.spawn(function()
		local gs = ReplicatedStorage:WaitForChild("GameState", 30)
		if not gs then return end
		gs:GetAttributeChangedSignal("WarBlessing"):Connect(function()
			S.LastServerWrite = os.clock() + (tonumber(Config.Sky and Config.Sky.TweenTime) or 3)
			schedule()
		end)
		pcall(apply, T.Tween)
	end)
	print("[ZoneLook] started")
end

return ZoneLook
