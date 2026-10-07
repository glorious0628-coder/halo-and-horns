-- ZoneLook.luau : A23-30 one mood per hunting ground, on the client. The war sky (WarService applies Config.Sky
-- Neutral / Dawn / Eclipse from GameState "WarBlessing") is the base light; the zone I stand in (player attribute "ZoneId")
-- tints it: meadow = bright midday, goblin woods = green shade, skeleton ruins = blue moonlight, pumpkin field =
-- orange-purple dusk, faction towns = faction colour. Monsters always keep sky light on them (the server's
-- EnvironmentDiffuseScale is never touched), so even the dark places show them clearly.
-- Base light (3rd review 2026-10-06): nothing is hard-coded here. The base is what the server writes to Lighting
-- (= Config.Sky[sky], WarService's exposure fallback included); before Start it is Config.Sky[sky] itself. Lighting =
-- base x the zone's factors, written LIVE: every server write (also each frame of its 3 s sky tween at a round end)
-- becomes the new base and is multiplied at once, so a round change never shows the raw sky for seconds. A zone change
-- eases the FACTORS (T.Tween s on Heartbeat), never a TweenService tween on Lighting, so the two can never fight.
-- Local only: the client writes its own Lighting values (they never replicate) plus one client-made ColorCorrection
-- "ZoneTint" (WarService keeps its global "WarTint"). Bloom, sun rays and the sky box stay the server's. ClockTime, the
-- classic fog and the terrain clouds stay the server's too (the war sky's meaning) EXCEPT in a zone with a Dusk entry
-- (the haunted hollow, review 2026-10-06 "유령 숲이 낮처럼 밝아요"): there they are blended toward its dusk (ClockTime
-- on the shorter way round the clock, a daytime base only; a purple-navy fog that greys out the far hills; dark
-- clouds) by the same eased weight, and leaving blends them back. Never an Atmosphere (A9-3 / A23-30 keep banning it:
-- it hides the FogColor war sky).
-- API: ZoneLook.Init(C), ZoneLook.Start(), ZoneLook.Preview(zoneId | nil) (tests: force a zone look, nil = follow me),
--      ZoneLook.Current() -> zone id, sky name, ZoneLook.TargetFor(zoneId, base[, sky]) -> Lighting goal, ZoneTint goal,
--      ZoneLook.Blend(fromZone, toZone, t, base[, sky]) -> the same mid-way through a zone change.
--      In Studio the LocalPlayer attribute "ZoneLookPreview" (set locally by tools/zone_look_view.py) drives Preview,
--      since a test runner's require() gets its own module copy.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local ZoneLook = {}
local LocalPlayer = Players.LocalPlayer

-- NightBright: under the Eclipse sky a zone may not dim the light below this factor (dark zones at night hid the
-- dark-armoured skeleton knights in the 2026-10-06 UiSandbox shots)
local T = { Tween = 1.5, NightBright = 0.95 }

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- per zone: Ambient / OutdoorAmbient channel factors, sun Brightness factor, exposure added, ZoneTint colour /
-- saturation / contrast / brightness, optional specular (wet moonlit stone), optional NightExp (exposure added on top
-- under the Eclipse night sky only; 0 elsewhere). Unknown zones use Default.
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
	-- A23-45 유령 숲 (이미지 생성 1 959a9af + review 2026-10-06 devlog 15 "still daylight"): dusk over the hollow only:
	-- a low sun (ClockTime 18.9), the sun at ~0.45 (2.0 -> 0.9), blue ambient so ghosts and paths stay readable,
	-- a purple-navy classic fog from 60 to 340 studs (the green hills beyond fade; the 104 x 90 hollow stays clear)
	HauntedHollow = { Amb = { 0.95, 1, 1.45 }, Bright = 0.45, Exp = 0.2, Tint = rgb(214, 206, 255), Sat = 0.05,
		Con = 0.08, CC = 0.02,
		Dusk = { Clock = 18.9, Fog = rgb(66, 58, 108), FogStart = 60, FogEnd = 340, Clouds = rgb(118, 100, 168) } },
	-- pale limestone town: dimmer sun so the white tiles do not burn out
	HaloTown = { Amb = { 1.06, 1.04, 0.95 }, Bright = 0.88, Exp = -0.12, Tint = rgb(255, 246, 228), Sat = 0.06, Con = 0.05,
		CC = 0 },
	-- quality 7 (이미지 생성 1 cdaaeaa, 2026-10-07): the dark basalt den read near black on phones (day mean 0.17, night
	-- ~0.03): warmer, brighter light by day and a night lift (NightExp 1.6, 검수 2026-10-07 from real captures: 1.9 made
	-- the night as bright and red as the day; 1.6 keeps it near the meadow night)
	HornsTown = { Amb = { 1.18, 0.98, 1.0 }, Bright = 1.0, Exp = 0.25, Tint = rgb(255, 236, 230), Sat = 0.1, Con = 0.03,
		CC = 0.03, NightExp = 1.6 },
}
ZONE.Default = ZONE.SlimeMeadow
ZoneLook.Zone = ZONE -- read by tests / the design table

-- the Lighting properties ZoneLook multiplies (the server writes all of them: Config.Sky per war sky, LIGHTING_FIXED)
-- and those a Dusk zone blends (ClockTime: WarService's forward tween; the fog: Config.Sky)
local MANAGED = { "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "EnvironmentSpecularScale",
	"ClockTime", "FogColor", "FogStart", "FogEnd" }

local S = {
	Started = false, Zone = nil, Sky = "Neutral", Preview = nil,
	Base = {}, -- [property] = the server's latest value (never one of ZoneLook's own writes)
	F = nil, From = nil, Goal = nil, T0 = 0, Dur = 1.5, Easing = false, -- current / start / goal factors, the ease clock
	Writing = false, Tint = nil, Conn = nil,
	Clouds = nil, CloudBase = nil, -- workspace.Terrain's Clouds (WarService colours them per sky) and its server colour
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

local function lerp(a, b, t) return a + (b - a) * t end

local function tint()
	if S.Tint and S.Tint.Parent == Lighting then return S.Tint end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ZoneTint"
	cc.Parent = Lighting
	S.Tint = cc
	return cc
end

-- the base before a server value is read: Config.Sky[sky] (WarService's source); the live Lighting value for what the
-- preset does not carry (exposure on Dawn / Eclipse: WarService's fallback, specular: its LIGHTING_FIXED)
local function configBase(sky)
	local p = type(Config.Sky) == "table" and Config.Sky[sky] or nil
	local base = {}
	for _, name in MANAGED do base[name] = Lighting[name] end
	if type(p) == "table" then
		if type(p.Brightness) == "number" then base.Brightness = p.Brightness end
		if typeof(p.Ambient) == "Color3" then base.Ambient = p.Ambient end
		if typeof(p.OutdoorAmbient) == "Color3" then base.OutdoorAmbient = p.OutdoorAmbient end
		if type(p.ExposureCompensation) == "number" then base.ExposureCompensation = p.ExposureCompensation end
		if type(p.ClockTime) == "number" then base.ClockTime = p.ClockTime end
		if typeof(p.FogColor) == "Color3" then base.FogColor = p.FogColor end
		if type(p.FogStart) == "number" then base.FogStart = p.FogStart end
		if type(p.FogEnd) == "number" then base.FogEnd = p.FogEnd end
	end
	return base
end

-- the zone's factors for the sky (the Eclipse night floor keeps the light up); Spec nil = the server's specular
local function factorsFor(zoneId, sky)
	local z = ZONE[zoneId] or ZONE.Default
	return {
		Amb = { z.Amb[1], z.Amb[2], z.Amb[3] },
		Bright = sky == "Eclipse" and math.max(z.Bright, T.NightBright) or z.Bright,
		Exp = z.Exp + (sky == "Eclipse" and (z.NightExp or 0) or 0),
		Spec = z.Specular,
		Tint = z.Tint, Sat = z.Sat, Con = z.Con, CC = z.CC,
		W = z.Dusk and 1 or 0, Dusk = z.Dusk, -- dusk weight (eased like the factors) and its targets
	}
end

-- hours from a to b the shorter way round the clock (-12 .. 12)
local function clockDelta(a, b)
	return ((b - a + 12) % 24) - 12
end

-- the dusk part of a goal over a base: ClockTime / fog toward the zone's dusk by weight w (a night base keeps its clock)
local function duskOver(base, w, d)
	if not d or w <= 0 then
		return { ClockTime = base.ClockTime, FogColor = base.FogColor, FogStart = base.FogStart, FogEnd = base.FogEnd }
	end
	local clock = base.ClockTime
	if type(clock) == "number" and clock >= 6 and clock < d.Clock then
		clock = (clock + clockDelta(clock, d.Clock) * w) % 24
	end
	return {
		ClockTime = clock,
		FogColor = typeof(base.FogColor) == "Color3" and base.FogColor:Lerp(d.Fog, w) or base.FogColor,
		FogStart = type(base.FogStart) == "number" and lerp(base.FogStart, math.min(base.FogStart, d.FogStart), w)
			or base.FogStart,
		FogEnd = type(base.FogEnd) == "number" and lerp(base.FogEnd, math.min(base.FogEnd, d.FogEnd), w) or base.FogEnd,
	}
end

-- Lighting goal + ZoneTint goal for factors over a base ({ property = server value })
local function compose(f, base)
	local dusk = duskOver(base, f.W or 0, f.Dusk)
	return {
		Brightness = base.Brightness * f.Bright,
		Ambient = scale(base.Ambient, f.Amb),
		OutdoorAmbient = scale(base.OutdoorAmbient, f.Amb),
		ExposureCompensation = base.ExposureCompensation + f.Exp,
		EnvironmentSpecularScale = f.Spec or base.EnvironmentSpecularScale,
		ClockTime = dusk.ClockTime, FogColor = dusk.FogColor, FogStart = dusk.FogStart, FogEnd = dusk.FogEnd,
	}, { TintColor = f.Tint, Saturation = f.Sat, Contrast = f.Con, Brightness = f.CC }
end

-- { Lighting goal, ZoneTint goal } for a zone over a base; sky only picks the night floor
function ZoneLook.TargetFor(zoneId, base, sky)
	return compose(factorsFor(zoneId, sky), base)
end

-- factors part of the way from a to b (Spec: the server's value stands for a missing one)
local function mix(a, b, t)
	local specA = a.Spec or S.Base.EnvironmentSpecularScale or 0.6
	local specB = b.Spec or S.Base.EnvironmentSpecularScale or 0.6
	return {
		Amb = { lerp(a.Amb[1], b.Amb[1], t), lerp(a.Amb[2], b.Amb[2], t), lerp(a.Amb[3], b.Amb[3], t) },
		Bright = lerp(a.Bright, b.Bright, t),
		Exp = lerp(a.Exp, b.Exp, t),
		Spec = (a.Spec == nil and b.Spec == nil) and nil or lerp(specA, specB, t),
		Tint = a.Tint:Lerp(b.Tint, t), Sat = lerp(a.Sat, b.Sat, t), Con = lerp(a.Con, b.Con, t), CC = lerp(a.CC, b.CC, t),
		W = lerp(a.W or 0, b.W or 0, t), Dusk = b.Dusk or a.Dusk, -- whichever side has dusk targets (only W changes)
	}
end

-- the goal part of the way (t 0..1) from one zone's look to another's over a base: what a zone change shows mid-ease
-- (tests / previews; the live ease runs the same mix on Heartbeat)
function ZoneLook.Blend(fromZone, toZone, t, base, sky)
	return compose(mix(factorsFor(fromZone, sky), factorsFor(toZone, sky), math.clamp(t, 0, 1)), base)
end

-- writes base x current factors: every managed property (name = nil) or one; ZoneTint with the full write
local function write(name)
	if not S.F then return end
	local light, cc = compose(S.F, S.Base)
	S.Writing = true
	if name then
		local v = light[name]
		if v ~= nil then pcall(function() Lighting[name] = v end) end
	else
		for k, v in light do pcall(function() Lighting[k] = v end) end
	end
	S.Writing = false
	if not name then
		local fx = tint()
		for k, v in cc do pcall(function() fx[k] = v end) end
	end
	local clouds = S.Clouds
	if clouds and clouds.Parent and typeof(S.CloudBase) == "Color3" and (name == nil or name == "Clouds") then
		local d, w = S.F.Dusk, S.F.W or 0
		local goal = (d and d.Clouds and w > 0) and S.CloudBase:Lerp(d.Clouds, w) or S.CloudBase
		S.Writing = true
		pcall(function() clouds.Color = goal end)
		S.Writing = false
	end
end

-- start easing the factors to the current zone / sky (seconds <= 0: jump)
local function retarget(seconds)
	S.Sky = skyName()
	local goal = factorsFor(S.Preview or S.Zone, S.Sky)
	if not S.F or seconds <= 0 then
		S.F, S.Easing = goal, false
		write(nil)
		return
	end
	S.From, S.Goal, S.T0, S.Dur, S.Easing = S.F, goal, os.clock(), math.max(0.05, seconds), true
end

local function onHeartbeat()
	if not S.Easing then return end
	local t = math.clamp((os.clock() - S.T0) / S.Dur, 0, 1)
	local eased = 0.5 - math.cos(t * math.pi) / 2 -- sine in-out
	S.F = mix(S.From, S.Goal, eased)
	if t >= 1 then
		S.F, S.Easing = S.Goal, false
	end
	write(nil)
end

-- a write ZoneLook did not make (the server: a sky change, its 3 s tween, LIGHTING_FIXED) is the new base, multiplied
-- at once (never a frame of the raw sky)
local function onWrite(name)
	if S.Writing then return end
	S.Base[name] = Lighting[name]
	write(name)
end

local function onZone()
	local z = LocalPlayer:GetAttribute("ZoneId")
	z = type(z) == "string" and z or nil
	if z == S.Zone then return end
	S.Zone = z
	if not S.Preview then retarget(T.Tween) end
end

----------------------------------------------------------------- public
function ZoneLook.Preview(zoneId)
	S.Preview = (type(zoneId) == "string" and zoneId ~= "") and zoneId or nil
	local ok, err = pcall(retarget, T.Tween)
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
	-- the server's values are already here (Lighting replicates before client scripts run); Config.Sky fills the gaps
	S.Base = configBase(skyName())
	for _, name in MANAGED do
		local v = Lighting[name]
		if v ~= nil then S.Base[name] = v end
	end
	-- the terrain clouds (when the place has them): WarService tweens their colour per sky -> the base, like Lighting
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		S.Clouds, S.CloudBase = clouds, clouds.Color
		clouds:GetPropertyChangedSignal("Color"):Connect(function()
			if S.Writing then return end
			S.CloudBase = clouds.Color
			local ok, err = pcall(write, "Clouds")
			if not ok then Util.Warn("ZoneLook", tostring(err)) end
		end)
	end
	pcall(retarget, 0)
	LocalPlayer:GetAttributeChangedSignal("ZoneId"):Connect(onZone)
	for _, name in MANAGED do
		Lighting:GetPropertyChangedSignal(name):Connect(function()
			local ok, err = pcall(onWrite, name)
			if not ok then Util.Warn("ZoneLook", tostring(err)) end
		end)
	end
	S.Conn = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(onHeartbeat)
		if not ok then
			S.Easing = false
			Util.Warn("ZoneLook", tostring(err))
		end
	end)
	if RunService:IsStudio() then
		LocalPlayer:GetAttributeChangedSignal("ZoneLookPreview"):Connect(function()
			ZoneLook.Preview(LocalPlayer:GetAttribute("ZoneLookPreview"))
		end)
	end
	-- the war sky changes at a round end: the night floor (Eclipse) may change the factors; the base follows the
	-- server's own writes (onWrite)
	task.spawn(function()
		local gs = ReplicatedStorage:WaitForChild("GameState", 30)
		if not gs then return end
		gs:GetAttributeChangedSignal("WarBlessing"):Connect(function()
			local ok, err = pcall(retarget, tonumber(Config.Sky and Config.Sky.TweenTime) or T.Tween)
			if not ok then Util.Warn("ZoneLook", tostring(err)) end
		end)
	end)
	print("[ZoneLook] started")
end

return ZoneLook
