-- rest_regen_offline.luau : A23-224 rest regen (user 10/17: SlimeMeadow, any level, Horns 5 s / Halo 1 s after the last damage,
-- then 2% of max HP a second; damage stops it). tools/test_rest_regen.py binds the dev2_combat_world sources (the real
-- CombatService regen loop, stepped by w:RegenTick).

local R0 = C0.Combat.RestRegen

local function restWorld(o)
	o = o or {}
	local w = bareWorld({})
	w.IsTown = {}
	w.Registry.ZoneService.IsTown = function(p) return w.IsTown[p] == true end
	return w
end

-- a player at `zone` with HP set to `hp` of max
local function hurtPlayer(w, id, faction, level, zone, hp)
	local p = w:Join(id, { Faction = faction, Class = "Warrior", Level = level })
	w.ZoneOf[p] = zone
	local hum = p.Character:FindFirstChild("Humanoid")
	hum.MaxHealth = 200
	hum.Health = hp
	return p, hum
end

local function hit(w, p, n)
	w.Combat.DamagePlayer(p, n or 1, nil, false, "Slime")
	w:Flush()
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

------------------------------------------------------------------ 1. Config
runGroup("config", function()
	check(type(R0) == "table" and R0.Zones.SlimeMeadow == true and R0.Wait.Horns == 5 and R0.Wait.Halo == 1 and R0.PerSec == 0.02
		and R0.Stack == true and R0.Wait.Default == 5, "RestRegen: SlimeMeadow, Horns 5 s / Halo 1 s / else 5 s, 2%/s, Stack on", show(R0))
	local n = 0
	for _ in R0.Zones do n += 1 end
	check(n == 1, "only the meadow", n)
	check(C0.Factions.Horns.RegenPerSec == 0 and C0.Factions.Halo.RegenPerSec == 0.02, "the sides' own regen unchanged (Horns 0, Halo 2%)", "")
end)

------------------------------------------------------------------ 2. Horns: 5 s, then 2% a second; a hit stops it
runGroup("horns", function()
	local w = restWorld()
	local p, hum = hurtPlayer(w, 101, "Horns", 5, "SlimeMeadow", 100)
	hit(w, p, 1) -- 99
	w:Advance(4.9)
	w:RegenTick()
	check(near(hum.Health, 99), "Horns 4.9 s after a hit: nothing yet", hum.Health)
	w:Advance(0.2)
	w:RegenTick()
	check(near(hum.Health, 99 + 200 * 0.02), "Horns 5.1 s after: +2% of max (4)", hum.Health)
	w:RegenTick()
	check(near(hum.Health, 99 + 8), "and again the next tick", hum.Health)
	hit(w, p, 1)
	local after = hum.Health
	w:RegenTick()
	check(near(hum.Health, after), "a hit stops it at once", hum.Health)
	w:Advance(5.1)
	w:RegenTick()
	check(near(hum.Health, after + 4), "5 s later it starts again", hum.Health)
	-- any level (user "레벨 없이!")
	local q, qh = hurtPlayer(w, 102, "Horns", 40, "SlimeMeadow", 50)
	w:Advance(6)
	w:RegenTick()
	check(near(qh.Health, 54), "Lv40 in the meadow too (no level gate)", qh.Health)
	-- never past max
	local r, rh = hurtPlayer(w, 103, "Horns", 5, "SlimeMeadow", 199)
	w:Advance(6)
	w:RegenTick()
	check(near(rh.Health, 200), "capped at max HP", rh.Health)
	local _ = { q, r }
end)

------------------------------------------------------------------ 3. Halo: 1 s, stacked on the side's own 2%
runGroup("halo", function()
	local w = restWorld()
	local p, hum = hurtPlayer(w, 201, "Halo", 3, "SlimeMeadow", 100)
	hit(w, p, 1) -- 99
	w:Advance(0.5)
	w:RegenTick()
	check(near(hum.Health, 99 + 4), "Halo 0.5 s after a hit: its own 2% only (4)", hum.Health)
	w:Advance(0.6)
	w:RegenTick()
	check(near(hum.Health, 103 + 8), "Halo 1.1 s after: own 2% + rest 2% (Stack) = 8", hum.Health)
	-- Stack off: the bigger one only
	w.Config.Combat.RestRegen.Stack = false
	w:RegenTick()
	check(near(hum.Health, 111 + 4), "Stack false: max(2%, 2%) = 4", hum.Health)
	w.Config.Combat.RestRegen.Stack = true
end)

------------------------------------------------------------------ 4. where not
runGroup("elsewhere", function()
	local w = restWorld()
	local p, hum = hurtPlayer(w, 301, "Horns", 5, "GoblinWoods", 100)
	w:Advance(30)
	w:RegenTick()
	check(near(hum.Health, 100), "Horns outside the meadow: nothing (side's 0)", hum.Health)
	local q, qh = hurtPlayer(w, 302, "Halo", 5, "GoblinWoods", 100)
	w:Advance(30)
	w:RegenTick()
	check(near(qh.Health, 104), "Halo outside the meadow: its own 2% only", qh.Health)
	-- a town keeps the town regen (10%), no rest on top
	local t, th = hurtPlayer(w, 303, "Horns", 5, "SlimeMeadow", 100)
	w.IsTown[t] = true
	w:Advance(30)
	w:RegenTick()
	check(near(th.Health, 120), "a town: the town's 10% only", th.Health)
	-- an Active kaiju: no rest regen
	local k, kh = hurtPlayer(w, 304, "Horns", 5, "SlimeMeadow", 100)
	w.KaijuOf[k] = "Active"
	w:Advance(30)
	w:RegenTick()
	check(near(kh.Health, 100), "an Active kaiju: no rest regen", kh.Health)
	-- a Neutral player: the Default wait (5 s)
	local n, nh = hurtPlayer(w, 305, "Neutral", 5, "SlimeMeadow", 100)
	hit(w, n, 1)
	w:Advance(4)
	w:RegenTick()
	local mid = nh.Health
	w:Advance(1.5)
	w:RegenTick()
	check(near(mid, 99) and near(nh.Health, 103), "Neutral: the Default 5 s, then 2%", show({ mid, nh.Health }))
	local _ = { p, q }
end)

finish()
