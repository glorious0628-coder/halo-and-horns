-- day_cycle_offline.luau : A23-105 the server day and weather (DayCycleService) on tools/fixtures/dev2_kit.luau, with the
-- REAL WarService for the crown-war sky hand-over. Doubles: Color3 (R / G / B 0..1, Lerp), Lighting (a property proxy that
-- logs every write), TweenService (tweens are recorded; w:FinishTweens applies the played, uncancelled ones), NumberValue
-- (Changed fires on Value), workspace.Terrain + Clouds, os.time / Util.Now (the kit's w.Time), Random (the kit's, seeds
-- recorded), SwitchService / FactionService / PlayerService / MonsterService / PvPService. Loops (task.spawn + task.wait)
-- are coroutines stepped by hand, one pass per w:Tick. Config.DayCycle.Enabled is false on the branch until ZoneLook C1 +
-- C2 land (the merge gate group reads the REAL Config); dayWorld turns the cycle on for the groups that test it running
-- (a group's Edit may turn it off again).

------------------------------------------------------------------ doubles
local C3 = {}
C3.__index = C3
local function col(r, g, b)
	return setmetatable({ R = r, G = g, B = b, __kind = "Color3" }, C3)
end
function C3.Lerp(a, b, t)
	return col(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
local Color3D = { new = col, fromRGB = function(r, g, b) return col(r / 255, g / 255, b / 255) end }

local function colorEnv()
	local e = nativeEnv()
	e.Color3 = Color3D
	e.typeof = typeofDouble
	return e
end

local T = {
	Oct = 1791601200, -- 2026-10-10 12:00 KST
	Nov30_2359 = 1796050740, Nov30_235959 = 1796050799, Dec1 = 1796050800, Nov30_2350 = 1796050200,
	Feb28_235959 = 1803826799, Mar1 = 1803826800, Feb28_2350 = 1803826200,
	Feb29_2028 = 1835406000, Feb29_2028_end = 1835449199, Mar1_2028 = 1835449200,
	Launch = 1797645600, Beta = 1793412000, Jan15 = 1799971200,
	UtcNov30_16 = 1796054400, -- 2026-11-30 16:00 UTC = Dec 1 01:00 KST (UTC still says November)
	UtcFeb28_16 = 1803830400, -- 2027-02-28 16:00 UTC = Mar 1 01:00 KST (UTC still says February)
}

local function dayWorld(o)
	o = o or {}
	local w = newWorld({ Time = o.Time or T.Oct, Clock = 1000 })
	local cfg = execute("Config", CONFIG_SOURCE, colorEnv())
	cfg.DayCycle.Enabled = true -- the running cycle (the branch keeps it off until the client half lands: the gate group)
	if o.Edit then o.Edit(cfg) end
	w.Cfg = cfg
	w.Seeds, w.Tweens, w.LightLog, w.Loops, w.LoopNames, w.Switch = {}, {}, {}, {}, {}, {}
	w.Counts = { 1, 1 }
	w.GameState.Log = {}
	local Signal = w.Util.Signal

	-- Lighting: a property proxy (instMeta methods + children), every write logged
	local props = { ClockTime = 14, Brightness = 2, Ambient = col(0.3, 0.3, 0.3), OutdoorAmbient = col(0.4, 0.4, 0.4),
		ExposureCompensation = 0, FogColor = col(0.6, 0.8, 0.9), FogStart = 0, FogEnd = 100000, EnvironmentSpecularScale = 1 }
	w.Props = props
	local lighting = { _children = {}, __kind = "Instance", ClassName = "Lighting", Name = "Lighting", Attrs = {}, Signals = {} }
	setmetatable(lighting, {
		__index = function(_, k)
			local m = instMeta.Methods[k]
			if m then return m end
			return props[k]
		end,
		__newindex = function(_, k, v)
			props[k] = v
			table.insert(w.LightLog, { Key = k, Value = v, At = w.Time })
		end,
	})
	w.Lighting = lighting
	local terrain = newInstance("Terrain", w)
	if o.Clouds ~= false then
		local clouds = newInstance("Clouds", w)
		clouds.Cover, clouds.Density, clouds.Color = 0.5, 0.3, col(1, 1, 1)
		clouds.Parent = terrain
		w.Clouds = clouds
	end

	local tweenService = {}
	function tweenService.Create(_, inst, info, goal)
		local tw = { Inst = inst, Info = info, Goal = goal, Played = false, Cancelled = false, Done = false, At = w.Time }
		function tw.Play(self) self.Played = true end
		function tw.Cancel(self) self.Cancelled = true end
		table.insert(w.Tweens, tw)
		return tw
	end
	function w:FinishTweens()
		for _, tw in self.Tweens do
			if tw.Played and not tw.Cancelled and not tw.Done then
				tw.Done = true
				for k, v in tw.Goal do tw.Inst[k] = v end
			end
		end
	end
	w.Services.Lighting = lighting
	w.Services.TweenService = tweenService

	local function numberValue()
		local changed = rbxSignal(w.Warnings)
		local data = { Value = 0 }
		return setmetatable({ __kind = "Instance", ClassName = "NumberValue", Name = "NumberValue", Changed = changed,
			_children = {}, Attrs = {}, Signals = {} }, {
			__index = function(_, k)
				local m = instMeta.Methods[k]
				if m then return m end
				return data[k]
			end,
			__newindex = function(self, k, v)
				if k == "Value" then
					data.Value = v
					changed:Fire(v)
				else
					rawset(self, k, v)
				end
			end,
		})
	end

	local env = w:Env()
	env.Color3 = Color3D
	env.workspace = { GetServerTimeNow = function() return w.Time end, Terrain = terrain }
	env.game = { JobId = o.JobId or "job-A", PlaceId = 81671223175574,
		GetService = function(_, n) return assert(w.Services[n], "service " .. tostring(n)) end }
	env.Instance = { new = function(cn)
		if cn == "NumberValue" then return numberValue() end
		return newInstance(cn, w)
	end }
	local kitRandom = env.Random
	env.Random = { new = function(seed)
		table.insert(w.Seeds, seed)
		return kitRandom.new(seed)
	end }
	env.require = function(name)
		if name == "Config" then return cfg end
		if name == "Util" then return w.Util end
		if name == "Net" then return w.Net end
		error("unexpected require " .. tostring(name))
	end
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	w.DayEnv = env

	-- the registry (doubles for what the two services touch)
	local reg = {}
	reg.SwitchService = { On = function(k) return w.Switch[k] ~= false end }
	reg.PlayerService = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new(),
		IsReady = function(p) return p.Parent ~= nil end, GetReadyPlayers = function() return {} end }
	reg.FactionService = { FactionChanged = Signal.new(), GetCounts = function() return w.Counts[1], w.Counts[2] end,
		GetFaction = function(p)
			local f = p:GetAttribute("Faction")
			return type(f) == "string" and f or "None"
		end }
	reg.MonsterService = { MonsterKilled = Signal.new() }
	reg.PvPService = { PlayerKO = Signal.new() }
	reg.ProgressionService = { AddBankGold = function() return 0 end }
	if o.FakeWar then
		reg.WarService = { GetBlessingFaction = function() return w.Blessing or "None" end }
	end
	w.Reg = reg

	function w:Load(name, source)
		local m = execute(name, source, env)
		self.Reg[name] = m
		return m
	end
	-- Init all, then Start each in order; the loops each Start spawns get its name
	function w:Boot(names)
		for _, n in names do self.Reg[n].Init(self.Reg) end
		for _, n in names do
			self.Reg[n].Start()
			local list = self.Spawned
			self.Spawned = {}
			for _, job in list do
				local co = coroutine.create(job[1])
				local ok, err = coroutine.resume(co, table.unpack(job, 2, job.n))
				assert(ok, err)
				table.insert(self.Loops, co)
				table.insert(self.LoopNames, n)
			end
		end
	end
	-- one pass of the named loops (all when nil)
	function w:RunLoops(only)
		for i, co in self.Loops do
			if (only == nil or only == self.LoopNames[i]) and coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				assert(ok, err)
			end
		end
	end
	function w:Tick(seconds, only)
		self:Advance(seconds or 1)
		self:RunLoops(only)
	end
	function w:Attr(k) return self.GameState:GetAttribute(k) end
	return w
end

------------------------------------------------------------------ helpers
local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end
local function sameColor(a, b, eps)
	return type(a) == "table" and type(b) == "table" and near(a.R, b.R, eps) and near(a.G, b.G, eps) and near(a.B, b.B, eps)
end
local function cstr(c)
	if type(c) ~= "table" or c.R == nil then return tostring(c) end
	return string.format("(%.0f,%.0f,%.0f)", c.R * 255, c.G * 255, c.B * 255)
end
local function lum(c) return c.R * 0.3 + c.G * 0.59 + c.B * 0.11 end
local function clockDelta(a, b) return ((b - a + 12) % 24) - 12 end
local function maxChan(a, b) return math.max(math.abs(a.R - b.R), math.abs(a.G - b.G), math.abs(a.B - b.B)) end
local function lightTweens(w, from)
	local out = {}
	for i = (from or 0) + 1, #w.Tweens do
		local tw = w.Tweens[i]
		if tw.Inst == w.Lighting and tw.Goal.Brightness ~= nil then table.insert(out, tw) end
	end
	return out
end
local function clockTweensSince(w, from)
	local out = {}
	for i = (from or 0) + 1, #w.Tweens do
		local tw = w.Tweens[i]
		if tw.Inst.ClassName == "NumberValue" then table.insert(out, tw) end
	end
	return out
end
local function quietWeather(cfg) cfg.Weather.Enabled = false end
local PHASES = { Dawn = true, Day = true, Dusk = true, Night = true }
local WEATHERS = { Clear = true, Rain = true, Snow = true }
-- the look a war sky covers (DayCycleService LOOK_KEYS; ClockTime is not in it)
local LOOK = { "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogColor", "FogStart", "FogEnd" }
local LOOK_SET = {}
for _, k in LOOK do LOOK_SET[k] = true end
-- every look key of `src` (Lighting, a tween goal, ValuesAt) equals `want`'s (a Config.Sky preset or ValuesAt)
local function lookMatches(src, want, eps)
	for _, k in LOOK do
		local a, b = src[k], want[k]
		if type(b) == "number" and not near(a, b, eps or 1e-6) then return false end
		if type(b) == "table" and not sameColor(a, b, eps or 1e-6) then return false end
	end
	return true
end
local function lookWritesSince(w, from)
	local n = 0
	for i = from + 1, #w.LightLog do
		if LOOK_SET[w.LightLog[i].Key] then n += 1 end
	end
	return n
end
local function keyWritesSince(w, from, key)
	local n = 0
	for i = from + 1, #w.LightLog do
		if w.LightLog[i].Key == key then n += 1 end
	end
	return n
end
-- NightLevel as published (2 decimals)
local function level(x) return math.floor(math.clamp(x, 0, 1) * 100 + 0.5) / 100 end
-- 검수 2026-10-10 lens review: GameState DayPhase / NightLevel = the phase / the night share of the time-of-day look of the
-- ClockTime SHOWN (Lighting), under every sky
local function followsClock(w, D)
	local c = w.Lighting.ClockTime
	return w:Attr("DayPhase") == D.PhaseOf(c) and near(w:Attr("NightLevel"), level(D.LookAt(c).Night), 1e-9)
end
local function published(w, D)
	local c = w.Lighting.ClockTime
	return show({ Clock = c, DayPhase = w:Attr("DayPhase"), NightLevel = w:Attr("NightLevel"), WantPhase = D.PhaseOf(c),
		WantNight = level(D.LookAt(c).Night) })
end

------------------------------------------------------------------ groups
runGroup("the day curve and its phases (pure)", function()
	local w = dayWorld()
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local cfg = w.Cfg
	check(D.CycleSeconds() == 1440, "one full day = 1440 s (about 24 min)", D.CycleSeconds())
	-- real seconds each published phase lasts (Pace = the speed, Phases = the names)
	local secs = { Dawn = 0, Day = 0, Dusk = 0, Night = 0 }
	for s = 0, 1439 do
		local ph = D.PhaseOf(D.ClockAt(s + 0.5))
		secs[ph] = (secs[ph] or 0) + 1
	end
	check(secs.Dawn == 60 and secs.Day == 960 and secs.Dusk == 120 and secs.Night == 300,
		"real time per phase: Dawn 60 s, Day 960 s, Dusk 120 s, Night 300 s", show(secs))
	check((secs.Day or 0) / D.CycleSeconds() >= 0.6, "the day is most of it (>= 60%)", show(secs))
	check((secs.Dusk or 99) <= 180 and (secs.Night or 999) <= 300 and (secs.Dawn or 99) <= 180,
		"dusk / night / dawn are short (<= 3 / 5 / 3 min)", show(secs))
	local edges = {
		{ 4.99, "Night" }, { 5, "Night" }, { 5.99, "Night" }, { 6, "Dawn" }, { 6.99, "Dawn" }, { 7, "Day" }, { 12, "Day" },
		{ 16.99, "Day" }, { 17, "Dusk" }, { 18.99, "Dusk" }, { 19, "Night" }, { 23.99, "Night" }, { 0, "Night" },
		{ 24, "Night" }, { 2.5, "Night" },
	}
	for _, e in edges do
		check(D.PhaseOf(e[1]) == e[2], "phases by ClockTime (Dawn 6-7, Day 7-17, Dusk 17-19, Night 19-6)",
			e[1] .. " -> " .. D.PhaseOf(e[1]) .. " (want " .. e[2] .. ")")
	end
	-- WeatherFx (main): lamps off at Dawn / Day, on at Dusk / Night - the published phase must match the light
	local dawnFrom, duskFrom = nil, nil
	for _, p in cfg.DayCycle.Phases do
		if p.Name == "Dawn" then dawnFrom = p.From end
		if p.Name == "Dusk" then duskFrom = p.From end
	end
	local nDawn, nDusk = D.LookAt(dawnFrom or 0).Night, D.LookAt(duskFrom or 0).Night
	check(nDawn <= 0.55 and D.LookAt((dawnFrom or 0) - 0.01).Night > 0.45 and nDusk < 0.5 and near(D.LookAt(19).Night, 1),
		"Dawn (lamps off) starts only when the light is half up, Dusk (lamps on) before it gets dark",
		show({ dawnFrom, nDawn, duskFrom, nDusk }))
	check(near(D.ClockAt(0), 5) and near(D.ClockAt(120), 7) and near(D.ClockAt(1080), 17) and near(D.ClockAt(1200), 19)
		and near(D.ClockAt(1440), 5) and near(D.ClockAt(-1440), 5),
		"the cycle starts at 5:00 and each Pace edge is its From hour",
		show({ D.ClockAt(0), D.ClockAt(120), D.ClockAt(1080), D.ClockAt(1200), D.ClockAt(1440) }))
	local worst = 0
	for h = 0, 239 do
		local c = h / 10
		worst = math.max(worst, math.abs(clockDelta(c, D.ClockAt(D.PosOf(c)))))
	end
	check(worst < 1e-6, "PosOf is ClockAt's inverse (every 0.1 h)", worst)
	local paceSecs = {}
	for _, p in cfg.DayCycle.Pace do
		paceSecs[p.From] = p.Seconds
		check(near(D.ClockAt(D.PosOf(p.From)), p.From % 24, 1e-6), "each Pace piece starts at its From hour", p.From)
	end
	check(near(D.PosOf(7) - D.PosOf(5), paceSecs[5]) and near(D.PosOf(17) - D.PosOf(7), paceSecs[7]),
		"real seconds per Pace piece = its Seconds", show(paceSecs))
	-- the day IS Config.Sky.Neutral (the approved afternoon)
	local n = cfg.Sky.Neutral
	for _, c in { 8, 12, 15.3, 16 } do
		local v = D.ValuesAt(c, nil)
		check(near(v.Brightness, n.Brightness) and sameColor(v.Ambient, n.Ambient) and sameColor(v.OutdoorAmbient, n.OutdoorAmbient)
			and near(v.ExposureCompensation, n.ExposureCompensation) and sameColor(v.FogColor, n.FogColor)
			and near(v.FogStart, n.FogStart) and near(v.FogEnd, n.FogEnd) and near(v.Night, 0),
			"8:00-16:00 is exactly Config.Sky.Neutral (the approved day)", c .. ": " .. v.Brightness .. " " .. cstr(v.OutdoorAmbient))
	end
	local night = D.LookAt(0)
	check(near(night.Night, 1) and near(D.LookAt(12).Night, 0) and D.LookAt(17.5).Night > 0 and D.LookAt(17.5).Night < 1,
		"NightLevel: 1 at night, 0 by day, in between at dusk", show({ night.Night, D.LookAt(17.5).Night }))
end)

runGroup("time flows smoothly (Config Tick, one whole day)", function()
	local w = dayWorld({ Edit = quietWeather })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	w:Boot({ "DayCycleService" })
	local n = w.Cfg.Sky.Neutral
	local L = w.Lighting
	check(near(L.ClockTime, w.Cfg.DayCycle.StartClock, 1e-6) and near(L.Brightness, n.Brightness) and sameColor(L.OutdoorAmbient, n.OutdoorAmbient)
		and sameColor(L.Ambient, n.Ambient) and near(L.ExposureCompensation, n.ExposureCompensation)
		and sameColor(L.FogColor, n.FogColor) and near(L.FogEnd, n.FogEnd),
		"a new server starts at StartClock (A23-221 ⑤: 9, the morning) in the approved day look (Neutral)", L.ClockTime .. " " .. tostring(L.Brightness))
	check(w.Cfg.DayCycle.StartClock == 9, "A23-221 ⑤: StartClock is 9 (a first play starts in the morning: night about 15 min later)", w.Cfg.DayCycle.StartClock)
	check(w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0 and w:Attr("Weather") == "Clear",
		"GameState DayPhase / NightLevel / Weather at Start", show({ w:Attr("DayPhase"), w:Attr("NightLevel"), w:Attr("Weather") }))
	local maxStep = w.Cfg.DayCycle.MaxStepHours
	local tick = w.Cfg.DayCycle.Tick
	check(type(tick) == "number" and tick > 0 and tick <= 0.5, "a write at least every 0.5 s (small low-sun shadow steps)", tick)
	local nTicks = math.floor(1440 / tick + 0.5)
	local prev = { Clock = L.ClockTime, B = L.Brightness, E = L.ExposureCompensation, A = L.Ambient, O = L.OutdoorAmbient,
		F = L.FogColor, FE = L.FogEnd }
	local total, back, bigStep, worst = 0, 0, 0, { B = 0, E = 0, C = 0, FE = 0 }
	local seen, perPhase, phaseBad, flatWrites, nightBad = {}, { Dawn = 0, Day = 0, Dusk = 0, Night = 0 }, 0, 0, 0
	for _ = 1, nTicks do
		local logFrom = #w.LightLog
		w:Tick(tick)
		local d = clockDelta(prev.Clock, L.ClockTime)
		total += d
		if d <= 0 then back += 1 end
		if d > maxStep then bigStep += 1 end
		worst.B = math.max(worst.B, math.abs(L.Brightness - prev.B))
		worst.E = math.max(worst.E, math.abs(L.ExposureCompensation - prev.E))
		worst.C = math.max(worst.C, maxChan(L.Ambient, prev.A), maxChan(L.OutdoorAmbient, prev.O), maxChan(L.FogColor, prev.F))
		worst.FE = math.max(worst.FE, math.abs(L.FogEnd - prev.FE))
		prev = { Clock = L.ClockTime, B = L.Brightness, E = L.ExposureCompensation, A = L.Ambient, O = L.OutdoorAmbient,
			F = L.FogColor, FE = L.FogEnd }
		local ph = w:Attr("DayPhase")
		seen[ph] = true
		perPhase[ph] = (perPhase[ph] or 0) + 1
		if ph ~= D.PhaseOf(L.ClockTime) then phaseBad += 1 end
		if not followsClock(w, D) then nightBad += 1 end
		if L.ClockTime > 8.2 and L.ClockTime < 15.8 then
			for i = logFrom + 1, #w.LightLog do
				if w.LightLog[i].Key ~= "ClockTime" then flatWrites += 1 end
			end
		end
	end
	check(back == 0, "the clock always moves forward, every tick", back .. " ticks did not move forward")
	check(bigStep == 0, "no tick moves the clock more than MaxStepHours (no visible jump)", bigStep)
	check(near(total, 24, 1e-6) and near(L.ClockTime, w.Cfg.DayCycle.StartClock, 1e-6), "one day of ticks (1440 s) = exactly 24 h, back at StartClock",
		total .. " / " .. L.ClockTime)
	check(worst.B <= 0.03 and worst.E <= 0.03 and worst.C <= 3.5 / 255 and worst.FE <= 12,
		"the light changes in small steps (Brightness / exposure <= 0.03, colour <= 3.5/255, FogEnd <= 12 per tick)", show(worst))
	check(seen.Dawn and seen.Day and seen.Dusk and seen.Night, "all four phases come round", show(seen))
	check(phaseBad == 0, "DayPhase = the phase of the clock shown, every tick", phaseBad)
	check(nightBad == 0, "NightLevel = the night share of the time-of-day look at the clock shown (2 decimals), every tick",
		nightBad)
	local wantSecs = { Dawn = 60, Day = 960, Dusk = 120, Night = 300 }
	for name, s in perPhase do
		check(math.abs(s * tick - wantSecs[name]) <= tick, "DayPhase lasts its real time (Dawn 60 / Day 960 / Dusk 120 / Night 300 s)",
			name .. " " .. s * tick)
	end
	check(flatWrites == 0, "between 8:00 and 16:00 only ClockTime is sent (an unchanged value is never written again)",
		flatWrites)
	-- NightLevel follows the light, every value published is valid
	local badAttr = 0
	for _, e in w.GameState.Log do
		if e.Key == "DayPhase" and not PHASES[e.Value] then badAttr += 1 end
		if e.Key == "NightLevel" and (type(e.Value) ~= "number" or e.Value < 0 or e.Value > 1) then badAttr += 1 end
	end
	check(badAttr == 0, "DayPhase in Dawn / Day / Dusk / Night, NightLevel in 0..1", badAttr)
	-- go to midnight: night look + NightLevel 1
	check(D.DebugSetClock(0) ~= nil and near(L.ClockTime, 0) and w:Attr("DayPhase") == "Night" and w:Attr("NightLevel") == 1,
		"at midnight: Night, NightLevel 1", show({ L.ClockTime, w:Attr("DayPhase"), w:Attr("NightLevel") }))
end)

runGroup("nights stay bright enough (floors)", function()
	local w = dayWorld()
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local n = w.Cfg.Sky.Neutral
	local night = D.ValuesAt(0, nil)
	check(night.Brightness < n.Brightness and night.ExposureCompensation > n.ExposureCompensation
		and lum(night.FogColor) < lum(n.FogColor) * 0.6,
		"the night is night (less sun, a lifted exposure, a dark fog)", show({ night.Brightness, night.ExposureCompensation, cstr(night.FogColor) }))
	-- kid-readable minimums, fixed here (not read from Config.DayCycle.Floor)
	local low = 0
	local firstLow = nil
	for q = 0, 95 do
		local c = q / 4
		for _, wet in { false, { Rain = 1 }, { Snow = 1 } } do
			local v = D.ValuesAt(c, wet or nil)
			local ok = v.Brightness >= 1.2 - 1e-9 and lum(v.OutdoorAmbient) >= 0.35 and lum(v.Ambient) >= 0.25
				and v.ExposureCompensation >= -0.3 - 1e-9 and v.FogStart < v.FogEnd
			if not ok then
				low += 1
				firstLow = firstLow or (c .. " " .. show(wet) .. " B" .. v.Brightness .. " O" .. cstr(v.OutdoorAmbient)
					.. " A" .. cstr(v.Ambient) .. " E" .. v.ExposureCompensation)
			end
		end
	end
	check(low == 0, "every hour, dry / rain / snow: Brightness >= 1.2, OutdoorAmbient luminance >= 0.35, Ambient >= 0.25, exposure >= -0.3",
		firstLow)
	for _, c in { 0, 6.5, 17.5 } do
		local raw = D.LookAt(c) -- before the floor: the looks themselves are readable, the floor is only a guard
		check(raw.Brightness >= 1.2 and lum(raw.OutdoorAmbient) >= 0.35 and lum(raw.Ambient) >= 0.25,
			"the night / dawn / dusk looks themselves are readable (the floor only guards)",
			c .. " B" .. raw.Brightness .. " O" .. cstr(raw.OutdoorAmbient) .. " A" .. cstr(raw.Ambient))
	end
	local rainNight = D.ValuesAt(0, { Rain = 1 })
	local rainWant = math.max(w.Cfg.DayCycle.Floor.Brightness, w.Cfg.DayCycle.Looks.Night.Brightness * 0.8) -- A23-221 ⑤: night 1.8 x 0.8 = 1.44
	check(near(rainNight.Brightness, rainWant), "rain at night: the night look x the rain, never below the floor", rainNight.Brightness)
	local f = w.Cfg.DayCycle.Floor
	local dark = dayWorld({ Edit = function(cfg) quietWeather(cfg); cfg.DayCycle.Looks.Night.Brightness = 0.9 end })
	local DD = dark:Load("DayCycleService", DAYCYCLE_SOURCE)
	check(near(DD.ValuesAt(0, { Rain = 1 }).Brightness, f.Brightness), "a darker night look is held at the floor (0.9 x 0.8 -> Floor)",
		DD.ValuesAt(0, { Rain = 1 }).Brightness)
	for _, c in { 0, 6, 12, 17.5, 20 } do
		local v = D.ValuesAt(c, { Rain = 1, Snow = 1 })
		check(v.OutdoorAmbient.R >= f.OutdoorAmbient.R - 1e-9 and v.OutdoorAmbient.G >= f.OutdoorAmbient.G - 1e-9
			and v.OutdoorAmbient.B >= f.OutdoorAmbient.B - 1e-9 and v.Ambient.B >= f.Ambient.B - 1e-9,
			"each colour channel >= Config.DayCycle.Floor", c .. " " .. cstr(v.OutdoorAmbient))
	end
end)

runGroup("weather state machine", function()
	local w = dayWorld({ Edit = function(cfg) cfg.Weather.BlendSeconds = 20 end })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	-- scripted Random: FirstClear 300 (0.0), shower roll 0.1 (< 0.45) + Rain 270 (0.5), Clear 600 (0.0),
	-- roll 0.9 (>= 0.45: another clear) + Clear 1200 (1.0)
	w.Script = { 0.0, 0.1, 0.5, 0.0, 0.9, 1.0 }
	w:Boot({ "DayCycleService" })
	local t0 = w.Time
	local L = w.Lighting
	local seen = {}
	local function at(k) return seen[k] end
	local wetSamples = {}
	for s = 1, 2360 do
		w:Tick(1)
		local wx = w:Attr("Weather")
		if not seen[wx] then seen[wx] = s end
		if s == 300 or s == 301 or s == 310 or s == 320 or s == 321 then
			wetSamples[s] = D.State().WetRain
		end
		if s == 360 then
			local dry = D.ValuesAt(L.ClockTime, nil)
			check(L.Brightness < dry.Brightness - 0.1 and L.FogEnd < dry.FogEnd - 50 and lum(L.FogColor) ~= lum(dry.FogColor),
				"rain darkens the sun and brings the fog in (on the Lighting the clients multiply)",
				show({ L.Brightness, dry.Brightness, L.FogEnd, dry.FogEnd }))
			check(w.Clouds.Cover > 0.8 and w.Clouds.Density > 0.5, "rain covers the sky (terrain clouds Cover / Density)",
				show({ w.Clouds.Cover, w.Clouds.Density }))
		end
		if s == 569 then check(w:Attr("Weather") == "Rain", "the shower lasts its Rain seconds (270)", w:Attr("Weather")) end
		if s == 570 then check(w:Attr("Weather") == "Clear", "then it clears", w:Attr("Weather")) end
		if s == 1169 then check(w:Attr("Weather") == "Clear", "a clear spell (600 s)", w:Attr("Weather")) end
		if s == 1171 then
			check(w:Attr("Weather") == "Clear", "a roll >= Chance gives another clear spell, not rain", w:Attr("Weather"))
		end
		if s == 900 then
			check(near(w.Clouds.Cover, 0.5) and near(w.Clouds.Density, 0.3), "after the rain the place's clouds come back",
				show({ w.Clouds.Cover, w.Clouds.Density }))
		end
	end
	check(at("Rain") == 300 and seen.Snow == nil, "a new server starts clear (FirstClear), then rain - never snow in October",
		show(seen))
	check(near(wetSamples[300], 1 / 20) and near(wetSamples[310], 11 / 20) and near(wetSamples[320], 1) and near(wetSamples[321], 1),
		"the wet look eases in over BlendSeconds (no jump)", show(wetSamples))
	local nLog = 0
	for _, e in w.GameState.Log do
		if e.Key == "Weather" then
			nLog += 1
			check(WEATHERS[e.Value] == true, "Weather is Clear / Rain / Snow", e.Value)
		end
	end
	check(nLog == 3, "Weather is published on each change only (Start, Rain, Clear)", nLog)
	check(t0 > 0, "time base", t0)

	-- off by Config / by the live switch
	local off = dayWorld({ Edit = function(cfg) cfg.Weather.Enabled = false end })
	off:Load("DayCycleService", DAYCYCLE_SOURCE)
	off.Script = { 0.0, 0.0, 0.0 }
	off:Boot({ "DayCycleService" })
	local anyWet = false
	for _ = 1, 1500 do
		off:Tick(1)
		if off:Attr("Weather") ~= "Clear" then anyWet = true end
	end
	check(not anyWet, "Config.Weather.Enabled = false: always Clear", tostring(anyWet))
	local sw = dayWorld()
	local SD = sw:Load("DayCycleService", DAYCYCLE_SOURCE)
	sw:Boot({ "DayCycleService" })
	check(string.find(SD.DebugWeather("Rain:600"), "Rain", 1, true) ~= nil and sw:Attr("Weather") == "Rain", "debug rain", sw:Attr("Weather"))
	sw.Switch.Weather = false
	sw:Tick(1)
	check(sw:Attr("Weather") == "Clear", "the live switch Weather off clears it at the next tick", sw:Attr("Weather"))
end)

runGroup("weather over three days (seeded Random)", function()
	local w = dayWorld()
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	w:Boot({ "DayCycleService" })
	local wet, total, showers, lens, cur = 0, 0, 0, {}, 0
	local last = "Clear"
	for _ = 1, 51840 do -- 72 h in 5 s steps
		w:Advance(5)
		D.Step()
		local wx = w:Attr("Weather")
		total += 1
		if wx ~= "Clear" then
			wet += 1
			cur += 5
		end
		if wx ~= "Clear" and last == "Clear" then showers += 1 end
		if wx == "Clear" and last ~= "Clear" then
			table.insert(lens, cur)
			cur = 0
		end
		check(wx ~= "Snow", "no snow in October", wx)
		last = wx
	end
	local share = wet / total
	check(share > 0.04 and share < 0.25, "mostly clear: rain 4-25% of the time (expected ~12%)", share)
	local okLen = #lens > 0
	for _, l in lens do
		if l < 180 or l > 365 then okLen = false end
	end
	check(okLen and showers >= 20, "every shower lasts 3-6 min (Config.Weather.Rain), many showers in 3 days",
		showers .. " showers, " .. show(lens))
end)

runGroup("KST winter: snow instead of rain", function()
	local w = dayWorld()
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local cases = {
		{ T.Oct, false, "Oct 10" }, { T.Beta, false, "beta Oct 31" }, { T.Nov30_2359, false, "Nov 30 23:59 KST" },
		{ T.Nov30_235959, false, "Nov 30 23:59:59 KST" }, { T.Dec1, true, "Dec 1 00:00 KST" }, { T.Launch, true, "launch Dec 19" },
		{ T.Jan15, true, "Jan 15" }, { T.Feb28_235959, true, "Feb 28 23:59:59 KST" }, { T.Mar1, false, "Mar 1 00:00 KST" },
		{ T.Feb29_2028, true, "Feb 29 2028 (leap)" }, { T.Feb29_2028_end, true, "Feb 29 2028 23:59:59 KST" },
		{ T.Mar1_2028, false, "Mar 1 2028 00:00 KST" },
		{ T.UtcNov30_16, true, "Nov 30 16:00 UTC = Dec 1 KST" }, { T.UtcFeb28_16, false, "Feb 28 16:00 UTC = Mar 1 KST" },
	}
	for _, c in cases do
		check(D.IsWinterKST(c[1]) == c[2], "winter = KST months 12 / 1 / 2 (boundaries by the Korean date)",
			c[3] .. " -> " .. tostring(D.IsWinterKST(c[1])))
		check(D.WeatherKindAt(c[1]) == (c[2] and "Snow" or "Rain"), "a shower is snow in winter, rain otherwise", c[3])
	end

	-- a shower across Nov 30 -> Dec 1 midnight KST: rain turns to snow, the look crosses over
	local x = dayWorld({ Time = T.Nov30_2350 })
	local XD = x:Load("DayCycleService", DAYCYCLE_SOURCE)
	x.Script = { 0.0, 0.1, 1.0 } -- FirstClear 300 s (23:55), shower, Rain 360 s (to 00:01)
	x:Boot({ "DayCycleService" })
	local kinds = {}
	local worstB = 0
	local prevB = x.Lighting.Brightness
	for _ = 1, 700 do
		x:Tick(1)
		local t = x.Time
		if t == T.Nov30_235959 then kinds.before = x:Attr("Weather") end
		if t == T.Dec1 then kinds.after = x:Attr("Weather") end
		if t == T.Dec1 + 10 then kinds.mid = { Rain = XD.State().WetRain, Snow = XD.State().WetSnow } end
		if t == T.Dec1 + 25 then kinds.done = { Rain = XD.State().WetRain, Snow = XD.State().WetSnow } end
		worstB = math.max(worstB, math.abs(x.Lighting.Brightness - prevB))
		prevB = x.Lighting.Brightness
	end
	check(kinds.before == "Rain" and kinds.after == "Snow", "Nov 30 23:59:59 KST rain -> Dec 1 00:00 KST snow (same shower)",
		show(kinds))
	check(kinds.mid and kinds.mid.Rain > 0 and kinds.mid.Snow > 0 and kinds.done and near(kinds.done.Rain, 0) and near(kinds.done.Snow, 1),
		"rain's look eases out while snow's eases in", show(kinds))
	check(worstB <= 0.03, "no jump in the light at the change", worstB)

	-- Feb 28 -> Mar 1: snow turns back to rain
	local y = dayWorld({ Time = T.Feb28_2350 })
	y:Load("DayCycleService", DAYCYCLE_SOURCE)
	y.Script = { 0.0, 0.1, 1.0 }
	y:Boot({ "DayCycleService" })
	local k2 = {}
	for _ = 1, 700 do
		y:Tick(1)
		if y.Time == T.Feb28_235959 then k2.before = y:Attr("Weather") end
		if y.Time == T.Mar1 then k2.after = y:Attr("Weather") end
	end
	check(k2.before == "Snow" and k2.after == "Rain", "Feb 28 23:59:59 KST snow -> Mar 1 00:00 KST rain", show(k2))

	-- winter uses WinterChance: a roll of 0.5 starts a shower in December (0.5 < 0.6), not in October (0.5 >= 0.45)
	local function firstShower(t)
		local z = dayWorld({ Time = t })
		z:Load("DayCycleService", DAYCYCLE_SOURCE)
		z.Script = { 0.0, 0.5, 0.5 }
		z:Boot({ "DayCycleService" })
		for _ = 1, 301 do z:Tick(1) end
		return z:Attr("Weather")
	end
	check(firstShower(T.Launch) == "Snow" and firstShower(T.Oct) == "Clear", "WinterChance in winter, Chance otherwise",
		show({ firstShower(T.Launch), firstShower(T.Oct) }))
end)

runGroup("a crown-war sky covers the look, the clock keeps turning (real WarService)", function()
	local w = dayWorld({ Edit = function(cfg) cfg.Weather.FirstClear = { 5000, 5000 } end })
	local War = w:Load("WarService", WAR_SOURCE)
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local L = w.Lighting
	local cfg = w.Cfg
	local tick, maxStep, tweenTime = cfg.DayCycle.Tick, cfg.DayCycle.MaxStepHours, cfg.Sky.TweenTime
	check(not D.Owns(), "the cycle owns nothing before its Start (WarService's Start runs first)", tostring(D.Owns()))
	w:Boot({ "WarService" })
	check(#lightTweens(w) == 0 and near(L.ClockTime, 15.3) and near(L.Brightness, cfg.Sky.Neutral.Brightness),
		"WarService's Start sets the Neutral afternoon itself (the cycle is not running yet)", #lightTweens(w) .. " " .. L.ClockTime)
	local startLog = #w.LightLog
	w:Boot({ "DayCycleService" })
	local changedAtStart = 0
	for i = startLog + 1, #w.LightLog do
		local e = w.LightLog[i]
		if e.Key == "Brightness" or e.Key == "OutdoorAmbient" or e.Key == "FogEnd" then
			changedAtStart += 1
		end
	end
	-- A23-221 ⑤: StartClock 9 (morning) differs from WarService's boot afternoon (15.3): the clock moves once at the server's
	-- start (before anyone plays), the day look stays (both are Day = Neutral)
	check(D.Owns() and changedAtStart == 0 and near(L.ClockTime, cfg.DayCycle.StartClock),
		"the cycle takes over in the same day light (StartClock in the Neutral day): no look re-sent", changedAtStart)
	local styleWrites = 0
	for _, e in w.LightLog do
		if e.Key == "LightingStyle" then styleWrites += 1 end
	end
	check(styleWrites == 0, "WarService never writes LightingStyle (a place setting, Soft)", styleWrites)
	check(w.Props.GlobalShadows == true and near(w.Props.ShadowSoftness, 0.15), "WarService still bootstraps its fixed light",
		show({ w.Props.GlobalShadows, w.Props.ShadowSoftness }))

	-- five rounds from 18:00 by the cycle, one frame = Config Tick: Halo (Dawn at 8:52) -> Horns (Eclipse at 15:07, war to
	-- war) -> draw (the look handed back at 6:00) -> Halo (Dawn at 12:37) -> draw (handed back at 21:30)
	D.DebugSetClock(18)
	local t0, p0 = w.Time, D.PosOf(18)
	local function clockAt(t) return D.ClockAt(p0 + (t - t0)) end
	local halo = w:NewPlayer(11, { Faction = "Halo" })
	local horns = w:NewPlayer(12, { Faction = "Horns" })
	local watch = { Prev = L.ClockTime, Back = 0, Big = 0, Off = 0, Steps = 0, Pub = 0 }
	-- the cycle's step of this frame, and the clock it leaves: the cycle's moving clock, forward, <= MaxStepHours; and
	-- DayPhase / NightLevel of that clock (never a war sky's)
	local function cycleFrame()
		w:RunLoops("DayCycleService")
		local d = clockDelta(watch.Prev, L.ClockTime)
		if d <= 0 then watch.Back += 1 end
		if d > maxStep + 1e-9 then watch.Big += 1 end
		if not near(L.ClockTime, clockAt(w.Time), 1e-6) then watch.Off += 1 end
		if not followsClock(w, D) then
			watch.Pub += 1
			watch.FirstPub = watch.FirstPub or published(w, D)
		end
		watch.Prev, watch.Steps = L.ClockTime, watch.Steps + 1
	end
	local function frame()
		w:Advance(tick)
		w:RunLoops("WarService")
		cycleFrame()
	end
	-- frames up to the round's end; the end frame runs WarService alone (what it does itself in that frame) and returns
	-- the log / tween marks from before it; each() checks every frame before it
	local round = 0
	local function untilRoundEnd(each)
		round += 1
		local endAt = t0 + 600 * round
		while w.Time + tick < endAt - 1e-6 do
			frame()
			if each then each() end
		end
		w:Advance(tick)
		local logFrom, nTw = #w.LightLog, #w.Tweens
		w:RunLoops("WarService")
		return logFrom, nTw
	end
	-- a whole war round: DayPhase / NightLevel follow the turning clock every frame (never a fixed war-sky value), its
	-- look stays on, the cycle writes no look key; the published phases in order and NightLevel's range / rises / falls
	local function warRound(sky, extra)
		local bad = { Phase = 0, Look = 0, Phases = {}, Order = {}, Frames = 0, NightMin = 1, NightMax = 0, Rise = 0, Fall = 0 }
		local from = #w.LightLog
		local prevNight = nil
		local function each()
			bad.Frames += 1
			local ph, nl = w:Attr("DayPhase"), w:Attr("NightLevel")
			if not followsClock(w, D) then
				bad.Phase += 1
				bad.First = bad.First or published(w, D)
			end
			if not lookMatches(L, cfg.Sky[sky]) then bad.Look += 1 end
			bad.Phases[ph] = true
			if bad.Order[#bad.Order] ~= ph then table.insert(bad.Order, ph) end
			if type(nl) == "number" then
				bad.NightMin, bad.NightMax = math.min(bad.NightMin, nl), math.max(bad.NightMax, nl)
				if prevNight and nl > prevNight then bad.Rise += 1 end
				if prevNight and nl < prevNight then bad.Fall += 1 end
				prevNight = nl
			end
			if extra then extra(bad.Frames) end
		end
		local logFrom, nTw = untilRoundEnd(each)
		bad.LookWrites = lookWritesSince(w, from) - lookWritesSince(w, logFrom)
		return bad, logFrom, nTw
	end
	-- a war sky came up in this end frame: WarService tweened its look only, never the clock
	local function warStartChecks(sky, logFrom, nTw, label)
		local tw = lightTweens(w, nTw)
		check(#tw == 1 and near(tw[1].Goal.Brightness, cfg.Sky[sky].Brightness) and tw[1].Goal.ClockTime == nil,
			"a war sky's look tween is WarService's, with no ClockTime in it", label .. " " .. #tw)
		local nClock, nWrites = #clockTweensSince(w, nTw), keyWritesSince(w, logFrom, "ClockTime")
		check(nClock == 0 and nWrites == 0,
			"WarService never tweens or writes the clock while the cycle owns the time (no preset clock 7.2 / 0.5)",
			label .. " " .. show({ nClock, nWrites }))
		local cycleFrom = #w.LightLog
		cycleFrame()
		check(lookWritesSince(w, cycleFrom) == 0 and keyWritesSince(w, cycleFrom, "ClockTime") == 1,
			"in the same frame the cycle writes only ClockTime: the clock turns on under the war sky", label)
		w:FinishTweens()
		check(lookMatches(L, cfg.Sky[sky]) and near(L.ClockTime, clockAt(w.Time), 1e-6),
			"the war sky's look is on and the sun stays where the day is", label .. " " .. L.ClockTime)
	end
	-- the war sky ended in this end frame: one look ease by the cycle toward the look of the time of day when it ends
	local function handBackChecks(logFrom, nTw, warStartClock, label)
		local st = D.State()
		check(w:Attr("WarBlessing") == "None" and st.WarSky == "None" and st.Blending,
			"a draw: WarService hands the look back in the same frame (Uncover)", label .. " " .. show(st))
		local back = lightTweens(w, nTw)
		local want = D.ValuesAt(clockAt(w.Time + tweenTime), nil)
		local warStart = D.ValuesAt(warStartClock, nil)
		check(#back == 1 and back[1].Goal.ClockTime == nil and lookMatches(back[1].Goal, want)
			and not near(back[1].Goal.Brightness, warStart.Brightness, 0.05),
			"one look ease (the cycle's, no ClockTime) aimed at the look of the time of day it ends at - not the look the war began at",
			label .. " " .. show({ #back, back[1] and back[1].Goal.Brightness, want.Brightness, warStart.Brightness }))
		check(back[1] and near(back[1].Info.Args[1], tweenTime), "over Config.Sky.TweenTime", label)
		local nClock, nWrites = #clockTweensSince(w, nTw), keyWritesSince(w, logFrom, "ClockTime")
		check(nClock == 0 and nWrites == 0, "no clock tween at the hand-back (the clock never stopped)",
			label .. " " .. show({ nClock, nWrites }))
		local easeFrom = #w.LightLog
		cycleFrame()
		check(followsClock(w, D), "the hand-back frame: DayPhase / NightLevel are the clock's (no step at the war sky's edge)",
			label .. " " .. published(w, D))
		local frames = math.floor(tweenTime / tick + 0.5)
		for _ = 2, frames do frame() end
		check(lookWritesSince(w, easeFrom) == 0 and keyWritesSince(w, easeFrom, "ClockTime") == frames,
			"during the ease the cycle writes no look but turns the clock every frame",
			label .. " " .. show({ lookWritesSince(w, easeFrom), keyWritesSince(w, easeFrom, "ClockTime"), frames }))
		w:Advance(tick) -- the ease ends
		w:FinishTweens()
		check(lookMatches(L, D.ValuesAt(clockAt(w.Time), nil)) and not D.State().Blending,
			"when the ease ends the look IS the look of the time of day then (ValuesAt(now))", label .. " " .. L.Brightness)
		local endFrom = #w.LightLog
		w:RunLoops("WarService")
		cycleFrame()
		check(lookWritesSince(w, endFrom) == 0, "the per-tick writes go on from there: nothing to re-send, no jump", label)
		local prevB, worstB = L.Brightness, 0
		for _ = 1, 20 do
			frame()
			worstB = math.max(worstB, math.abs(L.Brightness - prevB))
			prevB = L.Brightness
		end
		check(worstB <= 0.03, "then the look follows the time of day in small steps again", label .. " " .. worstB)
	end

	-- round 1: Halo -> the Dawn sky at 8:52
	War.AddPoints(halo, 50)
	local logFrom, nTw = untilRoundEnd()
	check(w:Attr("WarBlessing") == "Halo" and D.State().WarSky == "Dawn",
		"Halo: WarService covers the cycle's look with the Dawn sky in the same frame (Cover)",
		show({ w:Attr("WarBlessing"), D.State().WarSky }))
	check(followsClock(w, D) and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0,
		"Halo at 8:52: DayPhase / NightLevel are the clock's (Day / 0), never a value fixed by the war sky",
		published(w, D))
	check(near(clockAt(w.Time), 8.875, 1e-6), "round 1 ends at 8:52 by the cycle", clockAt(w.Time))
	warStartChecks("Dawn", logFrom, nTw, "Dawn 8:52")
	local warStart1 = L.ClockTime
	-- round 2 (under Dawn, a shower for a minute): Horns -> Eclipse, war to war
	D.DebugWeather("Rain:60")
	War.AddPoints(horns, 50)
	local cloudsMid = nil
	local war1
	war1, logFrom, nTw = warRound("Dawn", function(i)
		if i == 80 then cloudsMid = w.Clouds.Cover end
		if i == 200 then w.Switch.Weather = false end -- dry from here (the hand-backs compare the dry look)
	end)
	check(war1.Phase == 0 and war1.Look == 0 and war1.LookWrites == 0 and #war1.Order == 1 and war1.Order[1] == "Day"
		and war1.NightMax == 0,
		"10 minutes of daytime under the Dawn sky: DayPhase Day / NightLevel 0 (the clock's) every frame, its look on, not one look write by the cycle (rain included)",
		show(war1))
	check(type(cloudsMid) == "number" and cloudsMid > 0.8,
		"the shower's clouds come under the war sky too (Cover / Density are the weather's)", cloudsMid)
	check(w:Attr("WarBlessing") == "Horns" and D.State().WarSky == "Eclipse" and followsClock(w, D)
		and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0,
		"a Horns win at 15:07 (the Eclipse sky by daylight): DayPhase Day, NightLevel 0 - no lamps, no night lift under the sun",
		show({ w:Attr("WarBlessing"), D.State().WarSky, published(w, D) }))
	check(near(clockAt(w.Time), 7 + 780 / 96, 1e-6), "round 2 ends at 15:07 by the cycle", clockAt(w.Time))
	warStartChecks("Eclipse", logFrom, nTw, "Dawn -> Eclipse 15:07")
	-- round 3 (under Eclipse the clock runs through dusk and night to 6:00): a draw -> the look handed back
	local war2
	war2, logFrom, nTw = warRound("Eclipse")
	check(war2.Phase == 0 and war2.Look == 0 and war2.LookWrites == 0
		and table.concat(war2.Order, ">") == "Day>Dusk>Night" and war2.NightMin == 0 and war2.NightMax == 1,
		"under the Eclipse sky the clock runs on through Day, Dusk and Night and DayPhase / NightLevel follow it (Day > Dusk > Night, NightLevel 0 .. 1), its look stays",
		show(war2))
	check(near(clockAt(w.Time), 6, 1e-6), "round 3 ends at 6:00 by the cycle", clockAt(w.Time))
	handBackChecks(logFrom, nTw, warStart1, "6:00")
	-- round 4: Halo -> Dawn at 12:37; round 5 (the clock runs into dusk and night under it): a draw
	War.AddPoints(halo, 50)
	logFrom, nTw = untilRoundEnd()
	check(w:Attr("WarBlessing") == "Halo" and D.State().WarSky == "Dawn" and followsClock(w, D)
		and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0, "Halo again at 12:37: the Dawn sky covers the look, Day / 0",
		show({ D.State().WarSky, published(w, D) }))
	check(near(clockAt(w.Time), 7 + 540 / 96, 1e-6), "round 4 ends at 12:37 by the cycle", clockAt(w.Time))
	warStartChecks("Dawn", logFrom, nTw, "Dawn 12:37")
	local warStart2 = L.ClockTime
	local war3
	war3, logFrom, nTw = warRound("Dawn")
	check(war3.Phase == 0 and war3.Look == 0 and war3.LookWrites == 0
		and table.concat(war3.Order, ">") == "Day>Dusk>Night" and war3.Fall == 0 and war3.Rise > 0
		and war3.NightMin == 0 and war3.NightMax == 1,
		"under the Dawn sky the clock runs into Dusk and Night: DayPhase Day > Dusk > Night, NightLevel rising 0 -> 1, never falling (WeatherFx: lamps on all night under the Dawn sky)",
		show(war3))
	check(near(clockAt(w.Time), 21.5, 1e-6) and D.ValuesAt(21.5, nil).Night == 1,
		"round 5 ends at 21:30 by the cycle (the night look)", clockAt(w.Time))
	handBackChecks(logFrom, nTw, warStart2, "21:30")
	-- the whole run
	check(watch.Steps > 6000 and watch.Back == 0 and watch.Big == 0 and watch.Off == 0,
		"every frame through two Dawn skies, an Eclipse sky and all their edges: ClockTime = the cycle's moving clock, forward, <= MaxStepHours (never held, never a jump)",
		show(watch))
	check(watch.Steps > 6000 and watch.Pub == 0,
		"every cycle frame of the run (war skies, their edges, the hand-backs): DayPhase / NightLevel = the clock shown's",
		show({ watch.Pub, watch.FirstPub }))
	check(#clockTweensSince(w, 0) == 0, "no clock tween at all while the cycle owns the time", #clockTweensSince(w, 0))
end)

runGroup("a war sky drops a running hand-back look ease", function()
	local w = dayWorld({ FakeWar = true })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	w:Boot({ "DayCycleService" })
	D.Cover("Eclipse")
	D.Uncover(3)
	local tw = lightTweens(w)
	check(#tw == 1 and tw[1].Played and tw[1].Goal.ClockTime == nil, "Uncover plays one look ease (no ClockTime in it)", #tw)
	check(#clockTweensSince(w, 0) == 0, "and no clock tween (the clock was never stopped)", #clockTweensSince(w, 0))
	D.Cover("Dawn")
	check(tw[1] and tw[1].Cancelled, "Cover cancels it (a late frame never paints over the war sky)", tw[1] and tw[1].Cancelled)
	local logFrom = #w.LightLog
	w:FinishTweens()
	check(#w.LightLog == logFrom, "nothing is written by a cancelled ease", #w.LightLog - logFrom)
	D.Uncover(3)
	local n = #lightTweens(w)
	D.Uncover(3)
	check(#lightTweens(w) == n, "a second Uncover with no war sky up does nothing (a draw after a draw)", #lightTweens(w) - n)
end)

runGroup("a war sky never fixes DayPhase / NightLevel: they follow the turning clock", function()
	-- a Halo win at 17:30: the Dawn sky's look, but the clock runs on into Dusk and Night - the lamps on, NightLevel rising
	local w = dayWorld({ FakeWar = true, Edit = quietWeather })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local L = w.Lighting
	local tick = w.Cfg.DayCycle.Tick
	w:Boot({ "DayCycleService" })
	D.DebugSetClock(17.5)
	w.Blessing = "Halo"
	w:Tick(tick)
	check(D.State().WarSky == "Dawn" and followsClock(w, D) and w:Attr("DayPhase") == "Dusk" and w:Attr("NightLevel") > 0,
		"a Halo win at 17:30 (the Dawn sky): DayPhase Dusk and the dusk look's NightLevel at once - not Day / 0",
		show({ D.State().WarSky, published(w, D) }))
	local order, off, rise, fall = { w:Attr("DayPhase") }, 0, 0, 0
	local prev = w:Attr("NightLevel")
	local frames = math.ceil((D.PosOf(21) - D.PosOf(L.ClockTime)) / tick)
	for _ = 1, frames do
		w:Tick(tick)
		if not followsClock(w, D) then off += 1 end
		local ph, nl = w:Attr("DayPhase"), w:Attr("NightLevel")
		if order[#order] ~= ph then table.insert(order, ph) end
		if nl > prev then rise += 1 end
		if nl < prev then fall += 1 end
		prev = nl
	end
	check(D.State().WarSky == "Dawn" and off == 0, "every tick under the Dawn sky to 21:00: DayPhase / NightLevel = the clock shown's",
		show({ off, frames }))
	check(table.concat(order, ">") == "Dusk>Night" and rise > 0 and fall == 0 and w:Attr("NightLevel") == 1,
		"Dusk, then Night; NightLevel rises to 1 and never falls (WeatherFx: the lamps on through the night under the Dawn sky)",
		show({ order, rise, fall, w:Attr("NightLevel") }))

	-- a Horns win at noon: the Eclipse sky's look by daylight - Day / 0 (no lamps, no ZoneLook night lift under the sun)
	local x = dayWorld({ FakeWar = true, Edit = quietWeather })
	local XD = x:Load("DayCycleService", DAYCYCLE_SOURCE)
	x:Boot({ "DayCycleService" })
	XD.DebugSetClock(12)
	x.Blessing = "Horns"
	local bad = 0
	for _ = 1, 240 do -- two minutes of real time under the Eclipse sky
		x:Tick(tick)
		if not (followsClock(x, XD) and x:Attr("DayPhase") == "Day" and x:Attr("NightLevel") == 0) then bad += 1 end
	end
	check(XD.State().WarSky == "Eclipse" and bad == 0,
		"a Horns win at noon (the Eclipse sky): DayPhase Day / NightLevel 0 every tick - never Night / 1 under the noon sun",
		show({ XD.State().WarSky, bad, published(x, XD) }))
end)

runGroup("safety net: a missed Cover / Uncover is caught within one tick", function()
	local w = dayWorld({ FakeWar = true, Edit = quietWeather })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local L = w.Lighting
	w:Boot({ "DayCycleService" })
	w:Tick(1)
	w.Blessing = "Horns" -- the war sky changed but nobody called Cover
	w:Tick(1)
	check(D.State().WarSky == "Eclipse" and followsClock(w, D) and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0,
		"the next step covers the look for the Eclipse sky (DayPhase / NightLevel stay the afternoon clock's: Day / 0)",
		show({ D.State().WarSky, published(w, D) }))
	local logFrom = #w.LightLog
	local c0 = L.ClockTime
	for _ = 1, 30 do w:Tick(1) end
	local looks, clocks = lookWritesSince(w, logFrom), keyWritesSince(w, logFrom, "ClockTime")
	check(looks == 0 and clocks == 30 and clockDelta(c0, L.ClockTime) > 0,
		"then 30 ticks: 30 ClockTime writes (the clock turns on), not one look write", show({ looks, clocks }))
	-- Studio's Clock under the war sky: the clock jumps, the war look stays, DayPhase / NightLevel are the new clock's at once
	logFrom = #w.LightLog
	local r21 = D.Debug("Clock", 21)
	local at21 = { w:Attr("DayPhase"), w:Attr("NightLevel"), followsClock(w, D) }
	local r = D.Debug("Clock", 12)
	check(near(L.ClockTime, 12) and lookWritesSince(w, logFrom) == 0 and string.find(r, "Eclipse", 1, true) ~= nil
		and at21[1] == "Night" and at21[2] == 1 and at21[3] and followsClock(w, D) and w:Attr("DayPhase") == "Day"
		and w:Attr("NightLevel") == 0,
		"Studio's Clock under a war sky: only the clock jumps (the war look stays); DayPhase / NightLevel are the new clock's at once (21 = Night / 1, 12 = Day / 0)",
		show({ r21, r, at21, published(w, D) }))
	w.Blessing = "None"
	local nTw = #w.Tweens
	w:Tick(1)
	check(D.State().WarSky == "None" and D.State().Blending and #lightTweens(w, nTw) == 1,
		"None again: the next step hands the look back", show(D.State()))
end)

runGroup("the DayCycle switch freezes the day at StartClock", function()
	local w = dayWorld({ Edit = quietWeather })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	w:Boot({ "DayCycleService" })
	D.DebugSetClock(20)
	local L = w.Lighting
	w.Switch.DayCycle = false
	local nTw = #w.Tweens
	w:Tick(1)
	local ct = clockTweensSince(w, nTw)
	check(#ct == 1 and near(ct[1].Goal.Value % 24, w.Cfg.DayCycle.StartClock) and math.abs(ct[1].Goal.Value - 20) <= 11,
		"off: the clock eases to StartClock the short way (never a whole-day spin)", ct[1] and ct[1].Goal.Value)
	check(#lightTweens(w, nTw) == 1, "and the look with it", #lightTweens(w, nTw))
	-- during the clock ease the clock shown is Lighting's (still about 20 here: the double applies tweens when told), not
	-- the frozen StartClock the cycle aims at
	check(D.State().ClockEasing and followsClock(w, D) and w:Attr("DayPhase") == "Night" and w:Attr("NightLevel") == 1,
		"during the switch-off clock ease DayPhase / NightLevel follow the clock shown (Lighting.ClockTime), not StartClock",
		published(w, D))
	w:FinishTweens()
	for _ = 1, 10 do w:Tick(1) end
	check(near(L.ClockTime, w.Cfg.DayCycle.StartClock) and D.State().Frozen, "and stays there", L.ClockTime)
	check(followsClock(w, D) and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0,
		"after the ease: DayPhase / NightLevel of StartClock (Day / 0)", published(w, D))
	w.Switch.DayCycle = nil
	w:Tick(1)
	local d = clockDelta(w.Cfg.DayCycle.StartClock, L.ClockTime)
	check(d >= 0 and d <= w.Cfg.DayCycle.MaxStepHours, "back on: it goes on from StartClock (no jump)", L.ClockTime)

	-- off under a war sky: the clock still eases to StartClock, the war look stays; the hand-back is StartClock's look
	local x = dayWorld({ FakeWar = true, Edit = quietWeather })
	local XD = x:Load("DayCycleService", DAYCYCLE_SOURCE)
	x:Boot({ "DayCycleService" })
	XD.DebugSetClock(20)
	x.Blessing = "Horns"
	x:Tick(1)
	x.Switch.DayCycle = false
	nTw = #x.Tweens
	local logFrom = #x.LightLog
	x:Tick(1)
	local xct = clockTweensSince(x, nTw)
	check(XD.State().WarSky == "Eclipse" and #xct == 1 and near(xct[1].Goal.Value % 24, x.Cfg.DayCycle.StartClock) and #lightTweens(x, nTw) == 0,
		"off under a war sky: the clock eases to StartClock all the same, the war look stays (no look ease)",
		show({ #xct, #lightTweens(x, nTw) }))
	x:FinishTweens()
	for _ = 1, 10 do x:Tick(1) end
	check(near(x.Lighting.ClockTime, x.Cfg.DayCycle.StartClock) and lookWritesSince(x, logFrom) == 0, "and stays at StartClock under the war look",
		show({ x.Lighting.ClockTime, lookWritesSince(x, logFrom) }))
	x.Blessing = "None"
	nTw = #x.Tweens
	x:Tick(1)
	local back = lightTweens(x, nTw)
	check(#back == 1 and lookMatches(back[1].Goal, XD.ValuesAt(x.Cfg.DayCycle.StartClock, nil)) and #clockTweensSince(x, nTw) == 0,
		"after the war the look eases to StartClock's look", #back)
end)

runGroup("the cycle off in Config: WarService keeps the fixed afternoon and the preset war clocks", function()
	local w = dayWorld({ Edit = function(cfg) cfg.DayCycle.Enabled = false end })
	w:Load("WarService", WAR_SOURCE)
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	w:Boot({ "WarService", "DayCycleService" })
	check(not D.Owns() and near(w.Lighting.ClockTime, 15.3) and near(w.Lighting.Brightness, 2), "WarService wrote Neutral itself",
		w.Lighting.ClockTime)
	local logFrom = #w.LightLog
	for _ = 1, 120 do w:Tick(1) end
	local cycleWrites = 0
	for i = logFrom + 1, #w.LightLog do
		if w.LightLog[i].Key == "ClockTime" or w.LightLog[i].Key == "Brightness" then cycleWrites += 1 end
	end
	check(cycleWrites == 0, "no cycle writes", cycleWrites)
	check(followsClock(w, D) and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0,
		"DayPhase / NightLevel of the clock WarService shows: the fixed afternoon 15.3 = Day / 0", published(w, D))
	-- CR-L20 kept for the fixed presets: Neutral -> Dawn 7.2, then Halo -> Horns = Dawn 7.2 -> Eclipse 0.5 runs forward (17.3 h)
	local War = w.Reg.WarService
	local halo = w:NewPlayer(11, { Faction = "Halo" })
	local horns = w:NewPlayer(12, { Faction = "Horns" })
	War.AddPoints(halo, 50)
	local nTw0 = #w.Tweens
	for _ = 1, 480 do w:Tick(1) end
	local ct0 = clockTweensSince(w, nTw0)
	check(#ct0 == 1 and near(ct0[1].Goal.Value % 24, 7.2), "Halo: WarService tweens the clock to the Dawn preset 7.2",
		ct0[1] and ct0[1].Goal.Value)
	w:FinishTweens()
	w:Tick(1)
	check(near(w.Lighting.ClockTime, 7.2) and followsClock(w, D) and w:Attr("DayPhase") == D.PhaseOf(7.2),
		"after Halo wins (the Dawn preset 7.2 shown): DayPhase = PhaseOf(7.2), NightLevel = its look's night share",
		published(w, D))
	local fromDawn = w.Lighting.ClockTime
	War.AddPoints(horns, 80)
	local nTw = #w.Tweens
	for _ = 1, 600 do w:Tick(1) end
	local ct = clockTweensSince(w, nTw)
	local goal = ct[1] and ct[1].Goal.Value
	check(w:Attr("WarBlessing") == "Horns" and near(fromDawn, 7.2) and goal ~= nil and near(goal - fromDawn, 17.3, 1e-6),
		"every war-sky change between the fixed presets still runs forward (Dawn 7.2 -> Eclipse 0.5 = +17.3 h)",
		show({ fromDawn, goal }))
	-- while WarService's 3 s clock tween sweeps 7.2 -> 24.5 (through the day, dusk and night), the published phase is
	-- already its goal's: one change, no Dusk / Night flicker of the lamps on the way
	local phases = {}
	local lastPhase = nil
	for _, frac in { 0.1, 0.3, 0.5, 0.7, 0.9 } do
		w.Lighting.ClockTime = (fromDawn + 17.3 * frac) % 24
		w:Tick(0.25)
		if w:Attr("DayPhase") ~= lastPhase then
			lastPhase = w:Attr("DayPhase")
			table.insert(phases, lastPhase)
		end
	end
	check(#phases == 1 and phases[1] == "Night" and w:Attr("NightLevel") == 1,
		"cycle off: during the preset clock tween DayPhase / NightLevel are the goal's (Eclipse 0.5 = Night / 1) at once",
		show(phases))
	w:FinishTweens()
	w:Tick(1)
	check(near(w.Lighting.ClockTime, 0.5) and followsClock(w, D) and w:Attr("DayPhase") == "Night" and w:Attr("NightLevel") == 1,
		"after Horns wins (the Eclipse preset 0.5 shown): DayPhase Night, NightLevel 1 - the lamps on all Eclipse night",
		published(w, D))
	local nTw2 = #w.Tweens
	for _ = 1, 600 do w:Tick(1) end -- a draw: back to Neutral
	local back2 = clockTweensSince(w, nTw2)
	w:FinishTweens()
	w:Tick(1)
	check(w:Attr("WarBlessing") == "None" and #back2 == 1 and near(w.Lighting.ClockTime, 15.3) and followsClock(w, D)
		and w:Attr("DayPhase") == "Day" and w:Attr("NightLevel") == 0,
		"back to Neutral (the fixed afternoon 15.3 shown): Day / 0 again", show({ w:Attr("WarBlessing"), #back2, published(w, D) }))

	-- the first light with the cycle off publishes WarService's preset clock of the sky up then (here a Horns blessing:
	-- the Eclipse preset 0.5), not a fixed Day / 0
	local f = dayWorld({ Edit = function(cfg)
		cfg.DayCycle.Enabled = false
		quietWeather(cfg)
	end })
	local FW = f:Load("WarService", WAR_SOURCE)
	local FD = f:Load("DayCycleService", DAYCYCLE_SOURCE)
	f:Boot({ "WarService" })
	FW.GetBlessingFaction = function() return "Horns" end
	f.Lighting.ClockTime = 9 -- mid-tween: not the goal yet
	f:Boot({ "DayCycleService" })
	check(not FD.Owns() and f:Attr("DayPhase") == "Night" and f:Attr("NightLevel") == 1,
		"cycle off, its Start (before any step): DayPhase / NightLevel of the sky's preset clock (Eclipse 0.5 = Night / 1)",
		published(f, FD))

	-- ClockForwardMax still guards WarService's clock tween: a clock moved off the presets (a Studio edit at 8:00) never
	-- spins a whole day to Dawn 7.2 (23.2 h forward) - it goes 0.8 h back
	local g = dayWorld({ Edit = function(cfg)
		cfg.DayCycle.Enabled = false
		quietWeather(cfg)
	end })
	local GW = g:Load("WarService", WAR_SOURCE)
	g:Load("DayCycleService", DAYCYCLE_SOURCE)
	g:Boot({ "WarService", "DayCycleService" })
	g.Lighting.ClockTime = 8
	GW.AddPoints(g:NewPlayer(11, { Faction = "Halo" }), 50)
	g:NewPlayer(12, { Faction = "Horns" })
	local gn = #g.Tweens
	for _ = 1, 600 do g:Tick(1) end
	local gct = clockTweensSince(g, gn)
	local gg = gct[1] and gct[1].Goal.Value
	check(g:Attr("WarBlessing") == "Halo" and #gct == 1 and gg ~= nil and near(gg - 8, -0.8, 1e-6),
		"a clock off the presets goes the short way to the war clock (8:00 -> Dawn 7.2 = 0.8 h back, ClockForwardMax 18)",
		show({ #gct, gg }))
end)

runGroup("a cycle that never started: WarService keeps lighting Neutral", function()
	local w = dayWorld({ Edit = quietWeather })
	local War = w:Load("WarService", WAR_SOURCE)
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	D.Init(w.Reg) -- loaded and Init, but its Start never ran (failed / not reached)
	w:Boot({ "WarService" })
	local halo = w:NewPlayer(11, { Faction = "Halo" })
	War.AddPoints(halo, 50)
	for _ = 1, 600 do w:Tick(1) end
	w:FinishTweens()
	check(w:Attr("WarBlessing") == "Halo" and near(w.Lighting.ClockTime, 7.2), "a war sky as before", w.Lighting.ClockTime)
	local nTw = #w.Tweens
	for _ = 1, 600 do w:Tick(1) end
	local back = lightTweens(w, nTw)
	check(not D.Owns() and w:Attr("WarBlessing") == "None" and #back == 1
		and near(back[1].Goal.Brightness, w.Cfg.Sky.Neutral.Brightness),
		"Neutral comes back by WarService's own tween (never stuck on the war light)", show({ D.Owns(), #back }))
	w:FinishTweens()
	check(near(w.Lighting.ClockTime, 15.3), "and its fixed afternoon clock", w.Lighting.ClockTime)
end)

runGroup("debug, seed and the published contract", function()
	local w = dayWorld({ JobId = "job-A" })
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	w:Boot({ "DayCycleService" })
	local r = D.Debug("Clock", 22)
	check(near(w.Lighting.ClockTime, 22) and w:Attr("DayPhase") == "Night" and string.find(r, "Night", 1, true) ~= nil,
		"Debug Clock 22: the day jumps there", r)
	w:Tick(1)
	check(clockDelta(22, w.Lighting.ClockTime) > 0, "and goes on from there", w.Lighting.ClockTime)
	r = D.Debug("Weather", "Snow:60")
	check(w:Attr("Weather") == "Snow", "DebugWeather Snow works in any month (Studio photos)", r)
	for _ = 1, 61 do w:Tick(1) end
	check(w:Attr("Weather") == "Clear", "and ends after its seconds", w:Attr("Weather"))
	r = D.Debug("Weather", "Hail")
	check(w:Attr("Weather") == "Clear" and string.find(r, "Rain / Snow / Clear", 1, true) ~= nil, "a bad value changes nothing", r)
	check(D.DebugSetClock("x") == "Clock needs hours 0-24", "a bad clock changes nothing", D.DebugSetClock("x"))
	local s = D.State()
	check(type(s.Clock) == "number" and PHASES[s.Phase] and WEATHERS[s.Weather] and s.WarSky == "None", "State() for DayState", show(s))
	r = D.Debug("DayState")
	check(type(r) == "string" and string.find(r, "Weather Clear", 1, true) ~= nil and string.find(r, "WarSky None", 1, true) ~= nil,
		"Debug DayState reads the state", r)
	-- seeds: per server (JobId), pinned by Config.Weather.Seed
	local b = dayWorld({ JobId = "job-B" })
	b:Load("DayCycleService", DAYCYCLE_SOURCE)
	b:Boot({ "DayCycleService" })
	local pinned = dayWorld({ Edit = function(cfg) cfg.Weather.Seed = 7 end })
	pinned:Load("DayCycleService", DAYCYCLE_SOURCE)
	pinned:Boot({ "DayCycleService" })
	check(#w.Seeds == 1 and #b.Seeds == 1 and w.Seeds[1] ~= b.Seeds[1] and type(w.Seeds[1]) == "number",
		"one Random per server, seeded by os.time + JobId (two servers differ)", show({ w.Seeds[1], b.Seeds[1] }))
	check(pinned.Seeds[1] == 7, "Config.Weather.Seed pins it", show(pinned.Seeds))
	-- Net defaults, Main lists and debug keys
	check(has(NET_SOURCE, 'DayPhase = "Day", NightLevel = 0, Weather = "Clear",'), "Net.GameStateDefaults DayPhase / NightLevel / Weather")
	local function list(name)
		local a = string.find(MAIN_SOURCE, "local " .. name .. " = {", 1, true)
		local e = a and string.find(MAIN_SOURCE, "\n}", a, true)
		local out = {}
		if not (a and e) then return out end
		for item in string.gmatch(string.sub(MAIN_SOURCE, a, e), '"(%w+)"') do table.insert(out, item) end
		return out
	end
	local init, start = list("INIT_ORDER"), list("START_ORDER")
	local iw, id = table.find(init, "WarService"), table.find(init, "DayCycleService")
	local sw, sd, sp = table.find(start, "WarService"), table.find(start, "DayCycleService"), table.find(start, "PlayerService")
	check(iw ~= nil and id ~= nil and id > iw, "Main INIT_ORDER has DayCycleService (after WarService)", show({ iw, id }))
	check(sw ~= nil and sd ~= nil and sp ~= nil and sd > sw and sd < sp, "Main START_ORDER: WarService < DayCycleService < PlayerService",
		show({ sw, sd, sp }))
	local branch = string.find(MAIN_SOURCE, 'if key == "Clock" or key == "Weather" or key == "DayState" then', 1, true)
	local lookup = string.find(MAIN_SOURCE, "local player = game:GetService(\"Players\"):FindFirstChild(playerName)", 1, true)
	local taint = string.find(MAIN_SOURCE, "if tainted and not READ_ONLY[key] then tainted.DebugTainted = true end", 1, true)
	check(branch ~= nil and lookup ~= nil and taint ~= nil and branch < lookup and branch < taint
		and has(MAIN_SOURCE, "return S.DayCycleService.Debug(key, value)"),
		"Main DebugCommand Clock / Weather / DayState: before the player lookup (no player, never taints a save)", show({ branch, lookup }))
	check(has(MAIN_SOURCE, "local READ_ONLY = { Errors = true, Health = true, StoryDump = true, DataDump = true, LootRoll = true }"),
		"READ_ONLY is untouched (test_health's exact set)")
	local code = string.gsub(WAR_SOURCE, "%-%-[^\n]*", "")
	check(not has(code, "LightingStyle") and not has(code, "LIGHT_STYLE"), "WarService has no LightingStyle write left")
end)

------------------------------------------------------------------ the merge gate (검수 2026-10-10)
-- Config.DayCycle.Enabled may be true only once the client half is in: ZoneLook C1 (the night lift - NightExp - and the
-- NightBright floor scaled by GameState NightLevel instead of `sky == "Eclipse"`) and C2 (the haunted hollow's dusk clock
-- without the 11 h jump at base 6:00). Without them a running cycle shows HornsTown near black at its own night,
-- HornsTown overexposed under a daytime Eclipse, and the hollow's sun flipping once a day.
local GATE_STEP = 0.25 -- hours: the biggest step of the hollow's clock between two cycle ticks (the 6:00 jump is ~11 h)

local function replacePlain(text, old, new)
	local a, b = string.find(text, old, 1, true)
	if not a then return nil end
	return string.sub(text, 1, a - 1) .. new .. string.sub(text, b + 1)
end

-- C1 by ZoneLook's text (comments stripped): it reads GameState NightLevel, and no night-lift line (NightExp /
-- NightBright) nor factorsFor is keyed on the Eclipse sky
local function zoneLookC1(src)
	local code = string.gsub(src, "%-%-[^\n]*", "")
	local readsNight = has(code, '"NightLevel"')
	local keyed = {}
	for line in string.gmatch(code, "[^\n]+") do
		if (has(line, "NightExp") or has(line, "NightBright")) and has(line, '"Eclipse"') then
			table.insert(keyed, (string.gsub(line, "^%s+", "")))
		end
	end
	local a = string.find(code, "local function factorsFor(", 1, true)
	local e = a and string.find(code, "\nend\n", a, true)
	local ffEclipse = a ~= nil and e ~= nil and has(string.sub(code, a, e), 'sky == "Eclipse"')
	return readsNight and #keyed == 0 and not ffEclipse,
		show({ ReadsNightLevel = readsNight, EclipseKeyedNightLines = keyed, FactorsForKeyedOnEclipse = ffEclipse })
end

-- C2 by ZoneLook's real duskOver (weight 1) over the cycle's base clock, one value per Tick over a whole day: the
-- biggest step between two ticks. nil + why when ZoneLook's text could not be extracted or evaluated
local function hollowJump(chunk, why, D, tick)
	if chunk == "" then return nil, "ZoneLook's haunted hollow dusk could not be extracted: " .. tostring(why) end
	local ok, res = pcall(function()
		local dusk = execute("ZoneLookDusk", chunk, colorEnv(), col)
		local worst, at, prev = 0, nil, nil
		local n = math.floor(D.CycleSeconds() / tick + 0.5)
		for i = 0, n do
			local base = D.ClockAt(i * tick)
			local c = dusk(base)
			assert(type(c) == "number" and c == c, "duskOver gave no ClockTime for base " .. base)
			if prev then
				local d = math.abs(clockDelta(prev, c))
				if d > worst then worst, at = d, base end
			end
			prev = c
		end
		return { Worst = worst, At = at, Ticks = n }
	end)
	if not ok then
		return nil, "ZoneLook's duskOver could not be evaluated (its signature or helpers changed? update the extractor in "
			.. "tools/test_day_cycle.py): " .. tostring(res)
	end
	return res, nil
end

runGroup("merge gate: the cycle runs only with ZoneLook C1 + C2 (Config.DayCycle.Enabled)", function()
	local real = execute("Config", CONFIG_SOURCE, colorEnv()) -- the REAL Config (dayWorld turns the cycle on elsewhere)
	local enabled = real.DayCycle.Enabled
	check(type(enabled) == "boolean", "Config.DayCycle.Enabled is a plain true / false", tostring(enabled))
	local w = dayWorld()
	local D = w:Load("DayCycleService", DAYCYCLE_SOURCE)
	local tick = real.DayCycle.Tick
	local c1, c1Detail = zoneLookC1(ZONELOOK_SOURCE)
	local jump, jumpWhy = hollowJump(ZONELOOK_DUSK, ZONELOOK_DUSK_ERROR, D, tick)
	local c2 = jump ~= nil and jump.Worst <= GATE_STEP
	local c2Detail = jump and string.format("biggest hollow clock step %.2f h at base %.2f over %d ticks (limit %.2f h)",
		jump.Worst, jump.At or -1, jump.Ticks, GATE_STEP) or jumpWhy
	check(enabled ~= true or c1,
		"Enabled = true only with ZoneLook C1: the night lift and the NightBright floor by GameState NightLevel, not sky == \"Eclipse\"",
		c1Detail)
	check(enabled ~= true or c2,
		"Enabled = true only with ZoneLook C2: the haunted hollow's clock never jumps over a day of the cycle (<= 0.25 h a tick)",
		c2Detail)
	if enabled ~= true then
		finding("Config.DayCycle.Enabled = false (merge gate): ZoneLook C1 " .. (c1 and "in" or "missing") .. " " .. c1Detail
			.. "; C2 " .. (c2 and "in" or "missing") .. " - " .. tostring(c2Detail)
			.. ". The session that lands C1 + C2 sets Enabled = true; this group then requires both.")
	end

	-- the gate's own control: patched copies of the pre-C1 / pre-C2 ZoneLook text pass it, the unpatched text does not
	-- (only while ZoneLook still has that text; after C1 / C2 land the real text is what the gate checks)
	local zl1 = replacePlain(ZONELOOK_SOURCE, 'Bright = sky == "Eclipse" and math.max(z.Bright, T.NightBright) or z.Bright,',
		"Bright = lerp(z.Bright, math.max(z.Bright, T.NightBright), night),")
	zl1 = zl1 and replacePlain(zl1, 'Exp = z.Exp + (sky == "Eclipse" and (z.NightExp or 0) or 0),',
		"Exp = z.Exp + (z.NightExp or 0) * night,")
	if zl1 then
		zl1 ..= '\nlocal night = (gs and gs:GetAttribute("NightLevel")) or 0\n'
		local patched = zoneLookC1(zl1)
		check(patched and not c1, "gate self-test C1: the pre-C1 ZoneLook fails it, a NightLevel version of it passes",
			c1Detail .. " / patched " .. tostring(patched))
	else
		finding("gate self-test C1 skipped: ZoneLook no longer has the pre-C1 Eclipse-keyed night lift text")
	end
	local chunk2 = ZONELOOK_DUSK ~= "" and replacePlain(ZONELOOK_DUSK, "clock >= 6 and clock < d.Clock", "true") or nil
	if chunk2 and jump then
		local fixed, fixedWhy = hollowJump(chunk2, "", D, tick)
		check(fixed ~= nil and fixed.Worst <= GATE_STEP and jump.Worst > GATE_STEP,
			"gate self-test C2: the current hollow clock fails it (the 6:00 jump), an 'always the dusk clock' version passes",
			show({ current = jump.Worst, patched = fixed and fixed.Worst, why = fixedWhy }))
	else
		finding("gate self-test C2 skipped: ZoneLook's duskOver no longer has the pre-C2 '6:00 .. dusk' condition or could "
			.. "not be evaluated (" .. tostring(jumpWhy) .. ")")
	end
end)

finish()
