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
	-- C2c (검수 10/11, docs/design/halo_zonelook_values_2026-10-11.md): the new cream-marble town in a soft warm light
	HaloTown = { Amb = { 1.45, 1.36, 1.32 }, Bright = 1.0, Exp = 0.15, Tint = rgb(255, 248, 236), Sat = 0.08, Con = 0.04,
		CC = 0.02, Specular = 0.8 },
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

local S = { Night = 0, -- GameState NightLevel (A23-105 C1)

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

-- A23-221 (5): my screen in the first-day window (Config.FirstDay: the clock at noon-ish, no night lift)
local function firstDay()
	return type(Config.FirstDayFor) == "function" and Config.FirstDayFor(LocalPlayer:GetAttribute("PlaytimeSeconds")) == true
end

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

-- the zone's factors at a night level (A23-105 C1, dev2 contract: GameState NightLevel 0..1 of the clock shown - the
-- day cycle runs under every war sky): the night floor (NightBright) and the night lift (NightExp) scale with it, never
-- with the sky's name; Spec nil = the server's specular
local function factorsFor(zoneId, night)
	local z = ZONE[zoneId] or ZONE.Default
	local n = math.clamp(tonumber(night) or 0, 0, 1)
	return {
		Amb = { z.Amb[1], z.Amb[2], z.Amb[3] },
		Bright = z.Bright + (math.max(z.Bright, T.NightBright) - z.Bright) * n,
		Exp = z.Exp + (z.NightExp or 0) * n,
		Spec = z.Specular,
		Tint = z.Tint, Sat = z.Sat, Con = z.Con, CC = z.CC,
		W = z.Dusk and 1 or 0, Dusk = z.Dusk, -- dusk weight (eased like the factors) and its targets
	}
end

-- hours from a to b the shorter way round the clock (-12 .. 12)
local function clockDelta(a, b)
	return ((b - a + 12) % 24) - 12
end

-- the dusk part of a goal over a base: ClockTime / fog toward the zone's dusk by weight w. A23-105 C2: the hollow is
-- always at its dusk clock (night too - its light still follows the server's night + the C1 floor), so the running day
-- cycle never flips its sun at 6:00 (the old 'only 6:00 .. dusk' rule jumped 11 h once a day)
local function duskOver(base, w, d)
	if not d or w <= 0 then
		return { ClockTime = base.ClockTime, FogColor = base.FogColor, FogStart = base.FogStart, FogEnd = base.FogEnd }
	end
	local clock = base.ClockTime
	if type(clock) == "number" then
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
		ClockTime = (firstDay() and tonumber(Config.FirstDay.Clock)) or dusk.ClockTime,
		FogColor = dusk.FogColor, FogStart = dusk.FogStart, FogEnd = dusk.FogEnd,
	}, { TintColor = f.Tint, Saturation = f.Sat, Contrast = f.Con, Brightness = f.CC }
end

-- { Lighting goal, ZoneTint goal } for a zone over a base at a night level (0..1, GameState NightLevel)
function ZoneLook.TargetFor(zoneId, base, night)
	return compose(factorsFor(zoneId, night), base)
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
function ZoneLook.Blend(fromZone, toZone, t, base, night)
	return compose(mix(factorsFor(fromZone, night), factorsFor(toZone, night), math.clamp(t, 0, 1)), base)
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
	local goal = factorsFor(S.Preview or S.Zone, S.Night)
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

------------------------------------------------------------------ the PvP edge
-- 최종 검수 10/15 (the textbook, 'why does this not work?' + GPT 2B): a PvP place shows itself before I walk in - its
-- edge stands as a soft red curtain while I am outside it and within Near studs (Goblin Woods = the whole zone
-- PvP = true, the Crown Pit = SkeletonRuins.PvPArea). No words, no rays; the Artisan Guild (no PvP) sees nothing.
-- Client-only parts in workspace.PvPEdges (no collision, no query), built per edge piece on first approach, each piece
-- on the ground under it.
ZoneLook.EDGE = { Folder = "PvPEdges", Near = 45, Piece = 12, Height = 7, Thick = 0.3, Alpha = 0.62,
	Color = Color3.fromRGB(232, 64, 64), Every = 0.3 }

-- (pure) the PvP rectangles: { { Key, Center, Size } } from Config.Zones (PvP = true) and their PvPArea, season zones
-- only while the season is on
function ZoneLook.PvPRects()
	local out = {}
	for _, id in type(Config.ZoneOrder) == "table" and Config.ZoneOrder or {} do
		local z = Config.Zones[id]
		if type(z) == "table" and (z.Season == nil or (type(Config.SeasonOn) == "function" and Config.SeasonOn(z.Season))) then
			if z.PvP == true then table.insert(out, { Key = id, Center = z.Center, Size = z.Size }) end
			local a = z.PvPArea
			if type(a) == "table" and typeof(a.Center) == "Vector3" and typeof(a.Size) == "Vector3" then
				table.insert(out, { Key = id .. ":Area", Center = a.Center, Size = a.Size })
			end
		end
	end
	return out
end

-- (pure) how far pos is outside a rectangle (studs, on the ground plane; 0 or less = inside)
function ZoneLook.OutsideBy(rect, pos)
	local dx = math.abs(pos.X - rect.Center.X) - rect.Size.X / 2
	local dz = math.abs(pos.Z - rect.Center.Z) - rect.Size.Z / 2
	if dx <= 0 and dz <= 0 then return math.max(dx, dz) end
	return math.sqrt(math.max(dx, 0) ^ 2 + math.max(dz, 0) ^ 2)
end

-- (pure) the rectangles whose edge shows for me now: outside, within Near, a side that fights (not the Guild)
function ZoneLook.EdgesFor(pos, faction, rects)
	local out = {}
	if typeof(pos) ~= "Vector3" or faction == "Neutral" or faction == nil or faction == "" then return out end
	for _, r in type(rects) == "table" and rects or {} do
		local d = ZoneLook.OutsideBy(r, pos)
		if d > 0 and d <= ZoneLook.EDGE.Near then out[r.Key] = true end
	end
	return out
end

local function groundY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local f = workspace:FindFirstChild(ZoneLook.EDGE.Folder)
	if f then table.insert(ignore, f) end
	if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	return hit and hit.Position.Y or 0
end

-- one rectangle's curtain: pieces along its four sides, each standing on the ground under it
local function buildEdge(rect, folder)
	local E = ZoneLook.EDGE
	local m = Instance.new("Model")
	m.Name = "Edge_" .. rect.Key
	local hx, hz = rect.Size.X / 2, rect.Size.Z / 2
	local sides = {
		{ A = Vector3.new(-hx, 0, -hz), B = Vector3.new(hx, 0, -hz) }, { A = Vector3.new(hx, 0, -hz), B = Vector3.new(hx, 0, hz) },
		{ A = Vector3.new(hx, 0, hz), B = Vector3.new(-hx, 0, hz) }, { A = Vector3.new(-hx, 0, hz), B = Vector3.new(-hx, 0, -hz) },
	}
	for _, s in sides do
		local len = (s.B - s.A).Magnitude
		local n = math.max(1, math.ceil(len / E.Piece))
		local dir = (s.B - s.A).Unit
		for i = 1, n do
			local mid = rect.Center + s.A + dir * ((i - 0.5) * len / n)
			local p = Instance.new("Part")
			p.Name = "Piece"
			-- the piece's length runs along the side (its Z axis = dir), its foot half a stud into the ground
			local at = Vector3.new(mid.X, groundY(mid.X, mid.Z) + E.Height / 2 - 0.5, mid.Z)
			p.Size = Vector3.new(E.Thick, E.Height, len / n + 0.05)
			p.CFrame = CFrame.lookAt(at, at + dir)
			p.Color, p.Material, p.Transparency = E.Color, Enum.Material.Neon, 1
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Parent = m
		end
	end
	m.Parent = folder
	return m
end

-- one pass: the curtains I am near show (soft), the others hide
function ZoneLook.RefreshEdges()
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local rects = ZoneLook.PvPRects()
	local want = ZoneLook.EdgesFor(root and root.Position, LocalPlayer:GetAttribute("Faction"), rects)
	local folder = workspace:FindFirstChild(ZoneLook.EDGE.Folder)
	if next(want) == nil and not folder then return 0 end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ZoneLook.EDGE.Folder
		folder.Parent = workspace
	end
	local shown = 0
	for _, r in rects do
		local m = folder:FindFirstChild("Edge_" .. r.Key)
		if want[r.Key] and not m then m = buildEdge(r, folder) end
		if m then
			local alpha = want[r.Key] and ZoneLook.EDGE.Alpha or 1
			for _, p in m:GetChildren() do
				if p:IsA("BasePart") and p.Transparency ~= alpha then p.Transparency = alpha end
			end
			if want[r.Key] then shown += 1 end
		end
	end
	return shown
end

------------------------------------------------------------------ the invisible walls
-- 최종 검수 10/15 #2 ('why does this not work?'): an invisible wall (the map's border walls, the Goose Square's walls)
-- shows itself when I walk up to it - one soft pale panel on its face at the spot nearest me, clearer the closer I am,
-- gone past Near studs. No words, no rays. Client-only parts in workspace.WallEdges (no collision, no query).
ZoneLook.WALL = { Folder = "WallEdges", Near = 12, Piece = 14, Height = 8, Thick = 0.2, Alpha = 0.7,
	Color = Color3.fromRGB(245, 240, 225), Rescan = 5 }

-- (pure) where my position meets a standing wall (cf, size): nil when farther than near from its face (or past its
-- ends), else { Thin = "X" | "Z" (its thin local axis), Side = 1 | -1 (my side), Along = local offset along its length,
-- Y = local height of me (clamped), Dist = studs from its face }
function ZoneLook.WallSpot(cf, size, pos, near)
	if typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" or typeof(pos) ~= "Vector3" then return nil end
	local lp = cf:PointToObjectSpace(pos)
	local thin = size.X <= size.Z and "X" or "Z"
	local long = thin == "X" and "Z" or "X"
	local half = size / 2
	local d = math.abs(lp[thin]) - half[thin]
	if d < 0 or d > near or math.abs(lp[long]) > half[long] + near then return nil end
	return { Thin = thin, Side = lp[thin] >= 0 and 1 or -1, Along = math.clamp(lp[long], -half[long], half[long]),
		Y = math.clamp(lp.Y, -half.Y, half.Y), Dist = d }
end

-- (pure) the panel's alpha at a distance: Alpha at the face, fully clear at near
function ZoneLook.WallAlpha(dist, near)
	local W = ZoneLook.WALL
	return W.Alpha + (1 - W.Alpha) * math.clamp(dist / math.max(near, 1), 0, 1)
end

-- the invisible standing walls: Map.Walls' clear parts with collision + the Goose Square's Wall_* (rescanned now and then)
function ZoneLook.Walls()
	local now = os.clock()
	if ZoneLook.WallList and now - (ZoneLook.WallAt or 0) < ZoneLook.WALL.Rescan then return ZoneLook.WallList end
	local out = {}
	local map = workspace:FindFirstChild("Map")
	local walls = map and map:FindFirstChild("Walls")
	for _, p in walls and walls:GetChildren() or {} do
		if p:IsA("BasePart") and p.Transparency >= 0.95 and p.CanCollide then table.insert(out, p) end
	end
	local sq = workspace:FindFirstChild("GooseSquare")
	for _, p in sq and sq:GetChildren() or {} do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 5) == "Wall_" and p.Transparency >= 0.95 and p.CanCollide then
			table.insert(out, p)
		end
	end
	ZoneLook.WallList, ZoneLook.WallAt = out, now
	return out
end

-- one pass: a panel on each wall I am near (one per wall, moved to the spot nearest me), the others hidden
function ZoneLook.RefreshWalls()
	local W = ZoneLook.WALL
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position
	local folder = workspace:FindFirstChild(W.Folder)
	local shown = 0
	for i, wall in ZoneLook.Walls() do
		local s = pos and ZoneLook.WallSpot(wall.CFrame, wall.Size, pos, W.Near)
		local panel = folder and folder:FindFirstChild("Wall" .. i)
		if s then
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = W.Folder
				folder.Parent = workspace
			end
			if not panel then
				panel = Instance.new("Part")
				panel.Name = "Wall" .. i
				panel.Color, panel.Material = W.Color, Enum.Material.Neon
				panel.Anchored, panel.CanCollide, panel.CanQuery, panel.CanTouch, panel.CastShadow = true, false, false, false, false
				panel.Parent = folder
			end
			local half = wall.Size / 2
			local h = math.min(W.Height, wall.Size.Y)
			local y = math.clamp(s.Y + h / 2 - 2.5, -half.Y + h / 2, half.Y - h / 2) -- from my feet up
			local face = s.Side * (half[s.Thin] + W.Thick / 2 + 0.05)
			local width = math.min(W.Piece, wall.Size[s.Thin == "X" and "Z" or "X"])
			panel.Size = s.Thin == "X" and Vector3.new(W.Thick, h, width) or Vector3.new(width, h, W.Thick)
			panel.CFrame = wall.CFrame * CFrame.new(s.Thin == "X" and face or s.Along, y, s.Thin == "X" and s.Along or face)
			panel.Transparency = ZoneLook.WallAlpha(s.Dist, W.Near)
			shown += 1
		elseif panel and panel.Transparency ~= 1 then
			panel.Transparency = 1
		end
	end
	return shown
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
		-- A23-105 C1: the night level of the clock shown (every 0.5 s while it changes, dusk / dawn ~4 min): an ease
		-- running takes the new goal, else one write (never a new 1.5 s ease each step)
		local function onNight()
			local v = tonumber(gs:GetAttribute("NightLevel"))
			S.Night = (v and v == v and not firstDay()) and math.clamp(v, 0, 1) or 0
			local goal = factorsFor(S.Preview or S.Zone, S.Night)
			if S.Easing then
				S.Goal = goal
			else
				S.F = goal
				write(nil)
			end
		end
		gs:GetAttributeChangedSignal("NightLevel"):Connect(function()
			local ok, err = pcall(onNight)
			if not ok then Util.Warn("ZoneLook", tostring(err)) end
		end)
		-- A23-221 (5): leaving the first-day window brings the server's clock and night back (one write)
		local was = firstDay()
		LocalPlayer:GetAttributeChangedSignal("PlaytimeSeconds"):Connect(function()
			local now = firstDay()
			if now == was then return end
			was = now
			local ok, err = pcall(onNight)
			if not ok then Util.Warn("ZoneLook", tostring(err)) end
		end)
		pcall(onNight)
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(ZoneLook.RefreshEdges)
			if not ok then Util.Warn("ZoneLook", "edges: " .. tostring(err)) end
			ok, err = pcall(ZoneLook.RefreshWalls)
			if not ok then Util.Warn("ZoneLook", "walls: " .. tostring(err)) end
			task.wait(ZoneLook.EDGE.Every)
		end
	end)
	print("[ZoneLook] started")
end

return ZoneLook
