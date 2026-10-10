-- DayCycleService.luau : A23-105 the server's day and weather (게임성 개발 2, 2026-10-10; user "해가 지고 떴으면 좋겠고,
-- 비, 눈 이런 게 왔으면 좋겠어 ... 눈 같은 건 북반구 기준으로 ... 해 방향에 따라서 그림자 달라지면 좋겠어").
--   day     : Lighting.ClockTime turns once per Config.DayCycle day (Pace's Seconds summed, 1440 s = 24 min: the clock
--             runs slowly by day and through sunrise / sunset, fast at night), written every Tick s by a small step, so the
--             sun and the shadows move. The Neutral sky's light follows the time of day (Config.DayCycle.Looks by
--             ClockTime; Day = Config.Sky.Neutral) and never drops below Config.DayCycle.Floor (kids still see the way).
--   owner   : once Start has run (Owns() true) this service owns Lighting.ClockTime under EVERY sky, and the Neutral
--             sky's look - Brightness / Ambient / OutdoorAmbient / ExposureCompensation / FogColor / FogStart / FogEnd
--             (while Owns() is true WarService never writes the clock and leaves the Neutral look alone; before it - or if
--             Start failed - WarService keeps the fixed Neutral afternoon and its preset war clocks). A crown-war sky
--             (WarService: Dawn / Eclipse) covers only the LOOK (검수 2026-10-10, the user's choice (b)): Cover(sky) stops
--             the look writes while ClockTime keeps turning every tick (the sun and the shadows move under the war light);
--             when it ends, Uncover(seconds) eases the look in one tween over Config.Sky.TweenTime from the war look to the
--             look of the time of day it is THEN (not the one the war started at) and the per-tick writes go on from
--             there. The clock never jumps at either edge. Step also covers / uncovers from
--             WarService.GetBlessingFaction (a safety net for a missed call). The terrain clouds' Cover / Density are the
--             weather's under every sky (Color stays WarService's), bloom / tint / sky faces stay WarService's.
--   weather : one server state, Clear / Rain / Snow (Config.Weather; snow only in the KST winter months, then instead of
--             rain), eased into the light (the wet look) and published.
--   publish : ReplicatedStorage.GameState DayPhase = "Dawn" / "Day" / "Dusk" / "Night" and NightLevel = 0..1 ALWAYS follow
--             the ClockTime shown, under every sky (검수 2026-10-10 lens review): DayPhase = PhaseOf(clock)
--             (Config.DayCycle.Phases; Dawn from sunrise, when the light is half up - WeatherFx turns the lamps off then),
--             NightLevel = LookAt(clock).Night (the night share of the time-of-day look at that clock, 2 decimals). A war
--             sky never fixes them: the clock keeps turning under it, so a Halo win at 17:30 runs into Dusk and Night
--             (lamps on, NightLevel rising) and a Horns win at noon is Day / 0 (no night lift under the sun). The clock
--             shown is the cycle's; Lighting.ClockTime itself while the switch-off clock ease runs, and whenever the cycle
--             does not own the clock (Enabled false / Start not done: WarService's fixed afternoon 15.3 = Day / 0, its
--             Eclipse preset 0.5 = Night / 1) - every tick, only changes written. Weather = "Clear" / "Rain" / "Snow".
--             Clients: ZoneLook keeps multiplying the replicated Lighting as its base; WeatherFx draws rain / snow and the
--             lamps from the attributes.
--   switches: SwitchService "DayCycle" off = the clock eases the short way to StartClock and stays (the look with it,
--             unless a war sky covers it); "Weather" off = always Clear (live once Config.Switches.Defs lists them -
--             SwitchService.On says true for an unlisted key).
-- API: Init / Start, Owns(), Cover(skyName), Uncover(seconds), Step(), State(),
--      pure: CycleSeconds(), ClockAt(pos), PosOf(clock), PhaseOf(clock), LookAt(clock), ValuesAt(clock, wet),
--      IsWinterKST(osTime), WeatherKindAt(osTime); Studio (Main DebugCommand): Debug("Clock" | "Weather" | "DayState",
--      value), DebugSetClock(hours), DebugWeather("Rain[:seconds]").
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local DayCycleService = {}

local TAG = "DayCycleService"
local WARN_INTERVAL = 10
-- the Lighting properties the cycle owns besides ClockTime (all in ZoneLook's MANAGED list: it multiplies them)
local LOOK_KEYS = { "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "FogColor", "FogStart", "FogEnd" }
local WAR_SKY = { Halo = "Dawn", Horns = "Eclipse" } -- WarService skyNameFor (None = Neutral = the cycle)
local WET_KINDS = { "Rain", "Snow" }
local COLOR_KEYS = { "Ambient", "OutdoorAmbient" } -- the floor per colour channel

local S = nil
local st = {
	Started = false, Running = false, -- Running: Start finished its setup (Owns() needs it)
	Epoch = 0, -- server time (Util.Now) at cycle position 0 (the start of the first Pace piece)
	War = nil, WarSince = 0, -- the war sky covering the look ("Dawn" / "Eclipse"; nil = the cycle's look) and since when
	Frozen = false, -- the DayCycle switch is off: the day stays at StartClock
	LookTween = nil, LookUntil = 0, -- the look's hand-back ease (no per-tick look writes until LookUntil)
	ClockTween = nil, ClockUntil = 0, ClockValue = nil, -- the switch-off clock ease (no per-tick clock writes until ClockUntil)
	Phase = nil, Night = nil, LastStep = nil,
	Weather = "Clear", Spell = "Clear", SpellEndsAt = 0, Force = nil, -- Force: a Studio debug kind for this spell
	Wet = { Rain = 0, Snow = 0 }, -- the eased wet look per kind (0..1)
	Rng = nil, Clouds = nil, CloudBase = nil, WarnAt = {},
}

------------------------------------------------------------------ helpers
local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function warnThrottled(key, msg)
	local now = os.clock()
	local last = st.WarnAt[key]
	if last and now - last < WARN_INTERVAL then return end
	st.WarnAt[key] = now
	Util.Warn(TAG, msg)
end

local function dc()
	return type(Config.DayCycle) == "table" and Config.DayCycle or {}
end

local function wc()
	return type(Config.Weather) == "table" and Config.Weather or {}
end

local function neutral()
	local sky = type(Config.Sky) == "table" and Config.Sky or {}
	return type(sky.Neutral) == "table" and sky.Neutral or {}
end

local function startClock()
	return num(dc().StartClock, num(neutral().ClockTime, 15.3)) % 24
end

local function handBackSeconds()
	return math.max(0, num(type(Config.Sky) == "table" and Config.Sky.TweenTime, 3))
end

-- SwitchService.On(key); no switchboard (or a failing one) = on
local function switchOn(key)
	local sw = S and S.SwitchService
	if type(sw) ~= "table" or type(sw.On) ~= "function" then return true end
	local ok, on = pcall(sw.On, key)
	return not ok or on ~= false
end

local function setGame(key, value)
	local ok, err = pcall(function()
		Net.GameState():SetAttribute(key, value)
	end)
	if not ok then warnThrottled("gs:" .. key, "GameState " .. key .. ": " .. tostring(err)) end
end

------------------------------------------------------------------ the day (pure)
local function listOf(key)
	local list = dc()[key]
	return type(list) == "table" and list or {}
end

-- the hours entry i of a From list spans: its From up to the next entry's From (the last one wraps to the first + 24)
local function spanOf(list, i)
	local a = num(list[i].From)
	local b = i < #list and num(list[i + 1].From) or num(list[1].From) + 24
	while b <= a do
		b += 24
	end
	return a, b
end

-- the index of the entry whose span holds the clock (nil for an empty list)
local function entryAt(list, clock)
	local c0 = num(clock) % 24
	for i in list do
		local a, b = spanOf(list, i)
		local c = c0
		while c < a do
			c += 24
		end
		if c < b then return i, c, a, b end
	end
	return nil
end

function DayCycleService.CycleSeconds()
	local total = 0
	for _, p in listOf("Pace") do
		total += math.max(0, num(p.Seconds))
	end
	return total
end

-- the ClockTime at a cycle position (seconds; any number, wrapped): linear inside each Pace piece, so the clock runs at the
-- piece's own speed and never jumps at an edge
function DayCycleService.ClockAt(pos)
	local list = listOf("Pace")
	local total = DayCycleService.CycleSeconds()
	if #list == 0 or total <= 0 then return startClock() end
	local left = num(pos) % total
	for i, p in list do
		local secs = math.max(0, num(p.Seconds))
		if left < secs or i == #list then
			local a, b = spanOf(list, i)
			local t = secs > 0 and math.clamp(left / secs, 0, 1) or 0
			return (a + (b - a) * t) % 24
		end
		left -= secs
	end
	return startClock()
end

-- the cycle position of a ClockTime (ClockAt's inverse)
function DayCycleService.PosOf(clock)
	local list = listOf("Pace")
	local i, c, a, b = entryAt(list, clock)
	if not i then return 0 end
	local acc = 0
	for j = 1, i - 1 do
		acc += math.max(0, num(list[j].Seconds))
	end
	return acc + (c - a) / (b - a) * math.max(0, num(list[i].Seconds))
end

-- the published phase of a ClockTime (Config.DayCycle.Phases: names by From hour, not the clock's speed)
function DayCycleService.PhaseOf(clock)
	local list = listOf("Phases")
	local i = entryAt(list, clock)
	return i and tostring(list[i].Name) or "Day"
end

-- one value of a look; what the look leaves out comes from Config.Sky.Neutral (Night: 0)
local function lookValue(name, key)
	local looks = dc().Looks
	local look = type(looks) == "table" and looks[name] or nil
	if type(look) == "table" and look[key] ~= nil then return look[key] end
	if key == "Night" then return 0 end
	return neutral()[key]
end

local function mix(a, b, t)
	if type(a) == "number" and type(b) == "number" then return a + (b - a) * t end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then return a:Lerp(b, t) end
	if t < 0.5 then return a end
	return b
end

-- the light of a time of day (no weather, no floor): LOOK_KEYS + Night, eased (smoothstep) between the two Keys around it
function DayCycleService.LookAt(clock)
	local keys = dc().Keys
	local c0 = num(clock) % 24
	local fromName, toName, s = "Day", "Day", 0
	if type(keys) == "table" and #keys > 0 then
		for i, k in keys do
			local h0 = num(k.Hour)
			local nextKey = keys[i + 1] or keys[1]
			local h1 = num(nextKey.Hour) + (keys[i + 1] and 0 or 24)
			local c = c0
			while c < h0 do
				c += 24
			end
			if c < h1 then
				local t = h1 > h0 and (c - h0) / (h1 - h0) or 0
				fromName, toName, s = k.Look, nextKey.Look, t * t * (3 - 2 * t)
				break
			end
		end
	end
	local out = {}
	for _, key in LOOK_KEYS do
		out[key] = mix(lookValue(fromName, key), lookValue(toName, key), s)
	end
	out.Night = mix(num(lookValue(fromName, "Night")), num(lookValue(toName, "Night")), s)
	return out
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

-- the wet look of one weather kind at weight w (0..1) on the values v (in place)
local function wetLight(v, kind, w)
	local looks = wc().Looks
	local look = type(looks) == "table" and looks[kind] or nil
	if w <= 0 or type(look) ~= "table" then return end
	local function k(name)
		return 1 + (num(look[name], 1) - 1) * w
	end
	if type(v.Brightness) == "number" then v.Brightness *= k("BrightK") end
	if type(v.ExposureCompensation) == "number" then v.ExposureCompensation += num(look.ExpAdd) * w end
	if typeof(v.FogColor) == "Color3" then
		local f = v.FogColor
		local g = f.R * 0.3 + f.G * 0.59 + f.B * 0.11
		local c = f:Lerp(Color3.new(g, g, g), clamp01(num(look.Desat) * w))
		local m = k("FogK")
		v.FogColor = Color3.new(clamp01(c.R * m), clamp01(c.G * m), clamp01(c.B * m))
	end
	local e = k("FogEndK")
	if type(v.FogEnd) == "number" then v.FogEnd *= e end
	if type(v.FogStart) == "number" then v.FogStart *= e end
end

-- the least the cycle may write (Config.DayCycle.Floor; each colour channel)
local function floored(v)
	local f = dc().Floor
	if type(f) ~= "table" then return end
	if type(f.Brightness) == "number" and type(v.Brightness) == "number" then
		v.Brightness = math.max(v.Brightness, f.Brightness)
	end
	if type(f.ExposureCompensation) == "number" and type(v.ExposureCompensation) == "number" then
		v.ExposureCompensation = math.max(v.ExposureCompensation, f.ExposureCompensation)
	end
	for _, key in COLOR_KEYS do
		local lo, c = f[key], v[key]
		if typeof(lo) == "Color3" and typeof(c) == "Color3" then
			v[key] = Color3.new(math.max(c.R, lo.R), math.max(c.G, lo.G), math.max(c.B, lo.B))
		end
	end
end

-- everything the cycle writes for a ClockTime and the wet weights ({ Rain = 0..1, Snow = 0..1 }, or nil = dry)
function DayCycleService.ValuesAt(clock, wet)
	local v = DayCycleService.LookAt(clock)
	v.ClockTime = num(clock) % 24
	for _, kind in WET_KINDS do
		wetLight(v, kind, clamp01(num(type(wet) == "table" and wet[kind] or 0)))
	end
	floored(v)
	if type(v.FogStart) == "number" and type(v.FogEnd) == "number" and v.FogStart >= v.FogEnd then
		v.FogStart = math.max(0, v.FogEnd - 1) -- FogStart stays below FogEnd
	end
	return v
end

------------------------------------------------------------------ the weather (pure)
-- true in the northern winter by the Korean date: KST = UTC + UtcOffsetHours (Korea keeps no summer time), month in
-- SnowMonths
function DayCycleService.IsWinterKST(t)
	local w = wc()
	local offset = math.floor(num(w.UtcOffsetHours, 9) * 3600)
	local ok, d = pcall(os.date, "!*t", math.floor(num(t)) + offset)
	if not ok or type(d) ~= "table" then return false end
	local months = type(w.SnowMonths) == "table" and w.SnowMonths or {}
	return months[d.month] == true
end

-- the kind of a shower at that os.time(): snow instead of rain in the KST winter
function DayCycleService.WeatherKindAt(t)
	return DayCycleService.IsWinterKST(t) and "Snow" or "Rain"
end

------------------------------------------------------------------ light writes
local function differs(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) > 1e-4 end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) > 1e-4
	end
	return a ~= b
end

-- one property, only when it changed (an unchanged value is never sent to the clients again)
local function setProp(inst, key, value)
	if value == nil or inst == nil then return end
	local okRead, cur = pcall(function()
		return inst[key]
	end)
	if okRead and not differs(cur, value) then return end
	local ok, err = pcall(function()
		inst[key] = value
	end)
	if not ok then warnThrottled("set:" .. key, ("could not set %s: %s"):format(key, tostring(err))) end
end

local function clouds()
	local c = st.Clouds
	if c and c.Parent then return c end
	return nil
end

-- the place's clouds (read at Start) toward each weather kind's Cover / Density by its wet weight
local function cloudGoal()
	local base = st.CloudBase
	if not base or not clouds() then return nil end
	local looks = wc().Looks
	local goal = { Cover = base.Cover, Density = base.Density }
	for _, kind in WET_KINDS do
		local look = type(looks) == "table" and looks[kind] or nil
		local w = st.Wet[kind] or 0
		if type(look) == "table" and w > 0 then
			goal.Cover = mix(goal.Cover, num(look.Cover, goal.Cover), w)
			goal.Density = mix(goal.Density, num(look.Density, goal.Density), w)
		end
	end
	return goal
end

-- the look (LOOK_KEYS; never under a war sky)
local function writeLook(v)
	for _, key in LOOK_KEYS do
		setProp(Lighting, key, v[key])
	end
end

-- the clouds' Cover / Density: the weather's under every sky
local function writeClouds()
	local goal = cloudGoal()
	if goal then
		setProp(clouds(), "Cover", goal.Cover)
		setProp(clouds(), "Density", goal.Density)
	end
end

-- DayPhase / NightLevel (only changes are written)
local function publish(phase, night)
	if phase ~= st.Phase then
		st.Phase = phase
		setGame("DayPhase", phase)
	end
	local n = math.floor(clamp01(num(night)) * 100 + 0.5) / 100
	if n ~= st.Night then
		st.Night = n
		setGame("NightLevel", n)
	end
end

-- DayPhase / NightLevel of the ClockTime shown, under every sky (a war sky covers only the look, never these): its phase
-- and the night share of the time-of-day look at it (the same Night ValuesAt carries for that clock)
local function publishClock(clock)
	local c = num(clock) % 24
	publish(DayCycleService.PhaseOf(c), DayCycleService.LookAt(c).Night)
end

-- the ClockTime on screen as Lighting holds it (the switch-off ease's, or WarService's when the cycle does not own it)
local function lightingClock(default)
	local ok, c = pcall(function()
		return Lighting.ClockTime
	end)
	return num(ok and c or nil, default) % 24
end

local function cycleClock(now)
	if st.Frozen then return startClock() end
	return DayCycleService.ClockAt(now - st.Epoch)
end

local function valuesFor(now)
	return DayCycleService.ValuesAt(cycleClock(now), st.Wet)
end

------------------------------------------------------------------ the eases (look hand-back, switch-off clock)
local function cancelTween(field)
	local t = st[field]
	st[field] = nil
	if t then
		pcall(function()
			t:Cancel()
		end)
	end
end

local function cancelLook()
	cancelTween("LookTween")
	st.LookUntil = 0
end

local function cancelClock()
	cancelTween("ClockTween")
	st.ClockUntil = 0
end

local function playTween(inst, info, goal)
	local ok, t = pcall(TweenService.Create, TweenService, inst, info, goal)
	if not ok then
		warnThrottled("tween", "tween failed: " .. tostring(t))
		return nil
	end
	t:Play()
	return t
end

local function easeInfo(seconds)
	return TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

-- the look from what is on now (the war look at a hand-back) to the cycle's look `seconds` later - that moment's time of
-- day and weather - in one eased Lighting tween (0 = at once). ClockTime is never in it: the steps keep turning the clock
-- meanwhile. The steps write the look again when it ends, from where it ends (no jump). It publishes nothing: DayPhase /
-- NightLevel follow the clock shown, which an ease of the look never moves (each step publishes them)
local function easeLook(seconds)
	local now = Util.Now()
	cancelLook()
	local target = valuesFor(now + seconds)
	if seconds > 0 then
		local goal = {}
		for _, key in LOOK_KEYS do
			goal[key] = target[key]
		end
		st.LookTween = playTween(Lighting, easeInfo(seconds), goal)
	end
	if st.LookTween then
		st.LookUntil = now + seconds
	else
		writeLook(target)
	end
end

local function clockValue()
	if st.ClockValue then return st.ClockValue end
	local nv = Instance.new("NumberValue")
	nv.Name = "DayClock"
	nv.Changed:Connect(function(v)
		if type(v) ~= "number" then return end
		pcall(function()
			Lighting.ClockTime = v % 24
		end)
	end)
	st.ClockValue = nv
	return nv
end

-- the DayCycle switch went off: the clock eases to StartClock over `seconds` the short way round (at most 12 h, never a
-- whole day spun) in one NumberValue tween; the steps write it again when it ends
local function easeClock(seconds)
	local now = Util.Now()
	cancelClock()
	local to = startClock()
	local okRead, from = pcall(function()
		return Lighting.ClockTime
	end)
	from = okRead and num(from, to) or to
	local span = ((to - from + 12) % 24) - 12
	if seconds > 0 and math.abs(span) > 1e-3 then
		local nv = clockValue()
		nv.Value = from
		st.ClockTween = playTween(nv, easeInfo(seconds), { Value = from + span })
	end
	if st.ClockTween then
		st.ClockUntil = now + seconds
	else
		setProp(Lighting, "ClockTime", to)
	end
end

-- everything at once for the time now (the first light, Studio's Clock): the clock, the clouds and DayPhase / NightLevel
-- of that clock (under every sky); the look unless a war sky covers it
local function jumpNow()
	cancelClock()
	local v = valuesFor(Util.Now())
	setProp(Lighting, "ClockTime", v.ClockTime)
	writeClouds()
	publishClock(v.ClockTime)
	if st.War then return end
	cancelLook()
	writeLook(v)
end

------------------------------------------------------------------ public: ownership
-- true when the cycle runs: it owns ClockTime under every sky and the Neutral sky's look (WarService then leaves them
-- alone). False before Start has set it up (or when Start failed): WarService keeps the fixed Neutral afternoon and its
-- preset war clocks itself, as before A23-105
function DayCycleService.Owns()
	return dc().Enabled == true and st.Running == true
end

-- a crown-war sky is up (WarService: Dawn / Eclipse): its look wins - the look writes stop and a running hand-back look
-- ease is dropped; ClockTime keeps turning every tick (검수 2026-10-10, user (b)) and DayPhase / NightLevel go on following
-- it (nothing to publish here: the clock did not move)
function DayCycleService.Cover(sky)
	if type(sky) ~= "string" or sky == "Neutral" then return end
	cancelLook()
	if not st.War then st.WarSince = Util.Now() end
	st.War = sky
end

-- the war sky ended (WarService applies Neutral): the look eases over `seconds` from the war look to the look of the time
-- of day it is then (the clock was never stopped); nothing to do when no war sky covered it
function DayCycleService.Uncover(seconds)
	local was = st.War
	st.War = nil
	if not was or not DayCycleService.Owns() then return end
	easeLook(math.max(0, num(seconds)))
end

------------------------------------------------------------------ the weather state machine
local function rangeOf(r, default)
	if type(r) ~= "table" then return default end
	local a = math.max(1, num(r[1], default))
	local b = math.max(a, num(r[2], a))
	return a + (b - a) * (st.Rng and st.Rng:NextNumber() or 0.5)
end

-- a new spell: "Clear" for Clear s, or "Wet" (a shower) for Rain / Snow s by the season now
local function newSpell(now, kind)
	local w = wc()
	st.Spell = kind
	if kind == "Clear" then
		st.SpellEndsAt = now + rangeOf(w.Clear, 900)
	else
		local winter = DayCycleService.IsWinterKST(os.time())
		st.SpellEndsAt = now + rangeOf(winter and w.Snow or w.Rain, 300)
	end
end

local function stepWeather(now, dt)
	local w = wc()
	if w.Enabled ~= true or not switchOn("Weather") then
		if st.Spell ~= "Clear" or st.Force then
			st.Force = nil
			newSpell(now, "Clear")
		end
	elseif now >= st.SpellEndsAt then
		st.Force = nil
		if st.Spell == "Clear" then
			local chance = DayCycleService.IsWinterKST(os.time()) and num(w.WinterChance, num(w.Chance)) or num(w.Chance)
			local roll = st.Rng and st.Rng:NextNumber() or 1
			newSpell(now, roll < chance and "Wet" or "Clear")
		else
			newSpell(now, "Clear")
		end
	end
	local weather = "Clear"
	if st.Spell == "Wet" then weather = st.Force or DayCycleService.WeatherKindAt(os.time()) end
	-- each kind's wet look eases toward 1 while it falls, toward 0 otherwise (rain -> snow at midnight crosses over)
	local step = dt / math.max(1, num(w.BlendSeconds, 20))
	for _, kind in WET_KINDS do
		local goal = (weather == kind) and 1 or 0
		local cur = st.Wet[kind] or 0
		st.Wet[kind] = cur < goal and math.min(goal, cur + step) or math.max(goal, cur - step)
	end
	if weather ~= st.Weather then
		st.Weather = weather
		setGame("Weather", weather)
	end
end

------------------------------------------------------------------ the step
local function warBlessing()
	local war = S and S.WarService
	if type(war) ~= "table" or type(war.GetBlessingFaction) ~= "function" then return "None" end
	local ok, b = pcall(war.GetBlessingFaction)
	return (ok and type(b) == "string") and b or "None"
end

-- the clock WarService holds when the cycle does not own it: the current sky's Config.Sky preset (the goal of its 3 s
-- clock tween, so a sweep through the night between two presets never flips the lamps); Lighting's clock when that sky
-- has no preset clock
local function presetClock()
	local sky = WAR_SKY[warBlessing()] or "Neutral"
	local preset = type(Config.Sky) == "table" and Config.Sky[sky] or nil
	local c = type(preset) == "table" and tonumber(preset.ClockTime) or nil
	if c and c == c and c ~= math.huge and c ~= -math.huge then return c % 24 end
	return lightingClock(num(neutral().ClockTime, 15.3))
end

-- one tick: weather, switch, war-sky safety net, then the writes: ClockTime every tick under every sky (except while
-- the switch-off clock ease runs), the clouds, DayPhase / NightLevel of the clock shown (under every sky), and the look
-- unless a war sky covers it or the look's hand-back ease runs. Not owning the clock (Enabled false / Start not done):
-- only the weather and DayPhase / NightLevel of WarService's shown clock (the fixed afternoon, its preset war clocks)
function DayCycleService.Step()
	if not st.Started then return end
	local now = Util.Now()
	local dt = st.LastStep and math.clamp(now - st.LastStep, 0, 10) or 0
	st.LastStep = now
	stepWeather(now, dt)
	if not DayCycleService.Owns() then
		publishClock(presetClock()) -- e.g. the Eclipse preset 0.5 = Night / 1: its lamps on
		return
	end
	local frozen = not switchOn("DayCycle")
	if frozen ~= st.Frozen then
		st.Frozen = frozen
		if not frozen then
			st.Epoch = now - DayCycleService.PosOf(startClock()) -- back on: the day goes on from where it stood
		else
			easeClock(handBackSeconds()) -- off: the clock eases to StartClock
			if not st.War then easeLook(handBackSeconds()) end -- and the look with it (a war sky keeps its own)
		end
	end
	local sky = WAR_SKY[warBlessing()]
	if sky and st.War ~= sky then
		DayCycleService.Cover(sky)
	elseif not sky and st.War then
		DayCycleService.Uncover(handBackSeconds())
	end
	local v = valuesFor(now)
	local clockEasing = now < st.ClockUntil
	if not clockEasing then setProp(Lighting, "ClockTime", v.ClockTime) end
	writeClouds()
	publishClock(clockEasing and lightingClock(v.ClockTime) or v.ClockTime) -- the clock shown, under every sky
	if st.War or now < st.LookUntil then return end
	writeLook(v)
end

function DayCycleService.State()
	local now = Util.Now()
	return {
		Clock = cycleClock(now), Phase = st.Phase, NightLevel = st.Night, Weather = st.Weather, WarSky = st.War or "None",
		WarFor = st.War and math.max(0, math.floor(now - st.WarSince)) or 0, Frozen = st.Frozen,
		Blending = now < st.LookUntil, ClockEasing = now < st.ClockUntil, WetRain = st.Wet.Rain, WetSnow = st.Wet.Snow,
		Spell = st.Spell, SpellLeft = math.max(0, math.floor(st.SpellEndsAt - now)), Owns = DayCycleService.Owns(),
	}
end

------------------------------------------------------------------ Studio test aids (Main DebugCommand)
-- the day jumps to that ClockTime now (the cycle goes on from there); under a war sky only the clock jumps (the war look
-- stays; DayPhase / NightLevel are the new clock's, as always)
function DayCycleService.DebugSetClock(hours)
	local h = tonumber(hours)
	if not h or h ~= h or h == math.huge or h == -math.huge then return "Clock needs hours 0-24" end
	h %= 24
	st.Epoch = Util.Now() - DayCycleService.PosOf(h)
	if not DayCycleService.Owns() then return "the day cycle is not running (Config.DayCycle.Enabled)" end
	if st.Frozen then return "the DayCycle switch is off" end
	jumpNow()
	if st.War then
		return ("ClockTime %.2f (%s) under the %s sky (its look stays)"):format(h, DayCycleService.PhaseOf(h), st.War)
	end
	return ("ClockTime %.2f (%s)"):format(h, DayCycleService.PhaseOf(h))
end

-- "Rain" / "Snow" / "Clear" [":seconds"] now (any month here: photos of snow in October)
function DayCycleService.DebugWeather(value)
	local kind, secs = string.match(tostring(value), "^(%a+):?(%d*)$")
	if kind ~= "Rain" and kind ~= "Snow" and kind ~= "Clear" then return "Weather needs Rain / Snow / Clear[:seconds]" end
	local now = Util.Now()
	st.Spell = kind == "Clear" and "Clear" or "Wet"
	st.Force = kind ~= "Clear" and kind or nil
	st.SpellEndsAt = now + math.max(10, tonumber(secs) or 300)
	stepWeather(now, 0)
	return ("Weather %s for %d s"):format(st.Weather, math.floor(st.SpellEndsAt - now))
end

-- Main DebugCommand (Studio only; no player needed, nothing saved): "Clock" hours / "Weather" "Rain[:s]" / "DayState"
function DayCycleService.Debug(key, value)
	if key == "Clock" then return DayCycleService.DebugSetClock(value) end
	if key == "Weather" then return DayCycleService.DebugWeather(value) end
	local s = DayCycleService.State()
	return ("Clock %.2f %s NightLevel %s Weather %s (rain %.2f snow %.2f, %s %d s) WarSky %s (%d s) Frozen %s Blending %s Owns %s")
		:format(s.Clock, tostring(s.Phase), tostring(s.NightLevel), s.Weather, s.WetRain, s.WetSnow, s.Spell, s.SpellLeft,
			s.WarSky, s.WarFor, tostring(s.Frozen), tostring(s.Blending), tostring(s.Owns))
end

------------------------------------------------------------------ lifecycle
-- one Random per server: os.time() + the JobId (two servers started the same second differ); Config.Weather.Seed pins it
local function seedOf()
	local s = wc().Seed
	if type(s) == "number" then return s end
	local h = 0
	local id = tostring(game.JobId)
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 2147483647
	end
	return (os.time() + h) % 2147483647
end

-- the first light: the cycle takes over from WarService's Neutral afternoon at StartClock (same values: no jump; a war
-- sky already up keeps its look). Cycle off: DayPhase / NightLevel of the clock WarService shows (its fixed afternoon)
local function firstLight()
	if not DayCycleService.Owns() then
		publishClock(presetClock()) -- the cycle is off: WarService's preset clock
		return
	end
	local sky = WAR_SKY[warBlessing()]
	if sky then DayCycleService.Cover(sky) end
	jumpNow()
end

function DayCycleService.Init(registry)
	S = registry
end

function DayCycleService.Start()
	if st.Started then return end
	st.Started = true
	-- the loop first: the weather (and a later retry of the light) runs even if the setup below fails
	task.spawn(function()
		while true do
			task.wait(math.max(0.25, num(dc().Tick, 0.5)))
			local ok, err = pcall(DayCycleService.Step)
			if not ok then warnThrottled("step", "step error: " .. tostring(err)) end
		end
	end)
	local now = Util.Now()
	st.Epoch = now - DayCycleService.PosOf(startClock())
	st.LastStep = now
	st.Rng = Random.new(seedOf())
	local okC, c = pcall(function()
		return workspace.Terrain:FindFirstChildOfClass("Clouds")
	end)
	if okC and c then
		st.Clouds = c
		st.CloudBase = { Cover = num(c.Cover, 0.5), Density = num(c.Density, 0.5) }
	end
	st.Spell, st.Weather = "Clear", "Clear"
	st.SpellEndsAt = now + rangeOf(wc().FirstClear, 450) -- a new server starts clear
	setGame("Weather", "Clear")
	st.Frozen = not switchOn("DayCycle")
	st.Running = true
	local ok, err = pcall(firstLight)
	if not ok then warnThrottled("start", "first light failed (the next step writes it): " .. tostring(err)) end

	print("[DayCycleService] started")
end

return DayCycleService
