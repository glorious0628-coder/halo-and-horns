-- rest_regen_offline.luau : A23-224 rest regen, final (user 10/17 "너무 빨리 차 … 빛 1초에 2%(원래 회복 그대로, 더하는 것 없음),
-- 뿔 1초에 1%"): in the SlimeMeadow, any level, the Horns get 1% of max HP a second once they took no damage for 5 s; damage
-- stops it. Halo keeps its own 2% (nothing added), the other sides their own. tools/test_rest_regen.py binds the
-- dev2_combat_world sources (the real CombatService regen loop, stepped by w:RegenTick).

local R0 = C0.Combat.RestRegen

local function restWorld()
	local w = bareWorld({})
	w.IsTown = {}
	w.Registry.ZoneService.IsTown = function(p) return w.IsTown[p] == true end
	return w
end

-- a player at `zone` with HP set to `hp` of 200
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
	local n, sides = 0, 0
	for _ in R0.Zones do n += 1 end
	for _ in R0.Wait do sides += 1 end
	check(type(R0) == "table" and R0.Zones.SlimeMeadow == true and n == 1 and R0.Wait.Horns == 5 and sides == 1 and R0.PerSec == 0.01
		and R0.Stack == false, "RestRegen: the meadow only, the Horns only (5 s), 1%/s, never added (Stack false)", show(R0))
	check(C0.Factions.Horns.RegenPerSec == 0 and C0.Factions.Halo.RegenPerSec == 0.02, "the sides' own regen unchanged (Horns 0, Halo 2%)", "")
end)

------------------------------------------------------------------ 2. Horns: 5 s, then 1% a second; a hit stops it
runGroup("horns", function()
	local w = restWorld()
	local p, hum = hurtPlayer(w, 101, "Horns", 5, "SlimeMeadow", 100)
	hit(w, p, 1) -- 99
	w:Advance(4.9)
	w:RegenTick()
	check(near(hum.Health, 99), "Horns 4.9 s after a hit: nothing yet", hum.Health)
	w:Advance(0.2)
	w:RegenTick()
	check(near(hum.Health, 99 + 2), "Horns 5.1 s after: +1% of max (2)", hum.Health)
	w:RegenTick()
	check(near(hum.Health, 99 + 4), "and again the next tick", hum.Health)
	hit(w, p, 1)
	local after = hum.Health
	w:RegenTick()
	check(near(hum.Health, after), "a hit stops it at once", hum.Health)
	w:Advance(5.1)
	w:RegenTick()
	check(near(hum.Health, after + 2), "5 s later it starts again", hum.Health)
	-- any level (user "레벨 없이!")
	local q, qh = hurtPlayer(w, 102, "Horns", 40, "SlimeMeadow", 50)
	w:Advance(6)
	w:RegenTick()
	check(near(qh.Health, 52), "Lv40 in the meadow too (no level gate)", qh.Health)
	-- never past max
	local r, rh = hurtPlayer(w, 103, "Horns", 5, "SlimeMeadow", 199.5)
	w:Advance(6)
	w:RegenTick()
	check(near(rh.Health, 200), "capped at max HP", rh.Health)
	local _ = { q, r }
end)

------------------------------------------------------------------ 3. Halo: its own 2%, nothing added
runGroup("halo", function()
	local w = restWorld()
	local p, hum = hurtPlayer(w, 201, "Halo", 3, "SlimeMeadow", 100)
	hit(w, p, 1) -- 99
	w:Advance(0.5)
	w:RegenTick()
	check(near(hum.Health, 99 + 4), "Halo just after a hit: its own 2% (4)", hum.Health)
	w:Advance(10)
	w:RegenTick()
	check(near(hum.Health, 103 + 4), "Halo 10 s later: still 2% only (no rest added, A23-224 final)", hum.Health)
end)

------------------------------------------------------------------ 4. where not
runGroup("elsewhere", function()
	local w = restWorld()
	local p, hum = hurtPlayer(w, 301, "Horns", 5, "GoblinWoods", 100)
	w:Advance(30)
	w:RegenTick()
	check(near(hum.Health, 100), "Horns outside the meadow: nothing (the side's 0)", hum.Health)
	local q, qh = hurtPlayer(w, 302, "Halo", 5, "GoblinWoods", 100)
	w:Advance(30)
	w:RegenTick()
	check(near(qh.Health, 104), "Halo outside the meadow: its own 2%", qh.Health)
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
	-- the guild: not listed = its own regen (0) in the meadow too
	local n, nh = hurtPlayer(w, 305, "Neutral", 5, "SlimeMeadow", 100)
	w:Advance(30)
	w:RegenTick()
	check(near(nh.Health, 100), "the guild in the meadow: its own (0), no rest (A23-224: 'the other sides as they are')", nh.Health)
	local _ = { p, q, n }
end)

finish()
