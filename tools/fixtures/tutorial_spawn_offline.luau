-- tutorial_spawn_offline.luau : 3rd idea round #7 (ideas_first10 §3-#7, 검수 2026-10-07). A player on the first
-- mission's hunt (TutorialStep = Config.Tutorial.Steps.Quest, standing in Tutorial.GuideZone) is the spawn spread's
-- first choice for the tutorial monster: with fewer than SpawnSpread.Tutorial.StarvedThreshold (3) monsters near, the
-- slime comes 10-18 studs away on the half circle facing the zone middle (twice the tries); each hunter also raises the
-- meadow's slime target by Extra (3, never above Count x MaxZoneMult) so a lone sprout on a quiet server sees new slimes
-- at once. Among other starved players a Rookie goes first, then the lowest level, then the fewest monsters near.
-- tools/test_tutorial_spawn.py binds CONFIG_SOURCE and SPAWN_EXTRACT (the A7-1 spread constants, TUTORIAL / TUT_SPAWN,
-- GLOBAL_CAP, insideZone, tutorialHunter, playersPerZone, wantedTargets .. cappedTargets and pickSpawnPoint cut from the
-- CURRENT MonsterService) in front of dev2_kit.luau. Players, Util, the ground and the monster count near a player are
-- doubles; the contract numbers (10-18, Extra 3, threshold 3, regular 18-28) are written here on purpose.

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local TUT = C.Tutorial
local SLIME = C.MonsterTypes[TUT.Monster]
local MEADOW = C.Zones[TUT.GuideZone]
local RING_MIN, RING_MAX, EXTRA = 10, 18, 3 -- 검수 2026-10-07: SpawnSpread.Tutorial
local REG_MIN, REG_MAX = 18, 28 -- A7-1
local EPS = 1e-6

local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

-- one MonsterService cut per scenario: its own TUT_SPAWN, players and Random (w.Rng.Script = scripted NextNumber draws)
local function spawnWorld(players)
	local rng = { Script = {} }
	local U = { Random = randomDouble(rng).new() }
	function U.GetRoot(p) return p.Pos and { Position = p.Pos } or nil end
	function U.IsAlive(p) return p.Dead ~= true end
	function U.FlatDistance(a, b) return flat(a, b) end
	function U.RandomPointInZone(zone, inset) -- Util.RandomPointInZone
		inset = inset or 0
		local hx = math.max(1, zone.Size.X / 2 - inset)
		local hz = math.max(1, zone.Size.Z / 2 - inset)
		return vec(zone.Center.X + U.Random:NextNumber(-hx, hx), 0, zone.Center.Z + U.Random:NextNumber(-hz, hz))
	end
	local w = { Players = players or {}, Rng = rng, Radius = {}, Warnings = {} }
	local MS = { CountInRadius = function(_, radius, p)
		table.insert(w.Radius, radius)
		return p.Near or 0
	end }
	local H = { records = {}, pending = {},
		readyPlayers = function() return w.Players end,
		groundPoint = function(x, z) return vec(x, 0, z), false end,
		warnThrottled = function(_, msg) table.insert(w.Warnings, msg) end }
	w.M = execute("MonsterSpawn", SPAWN_EXTRACT, nativeEnv(), C, U, MS, H)
	return w
end

local function player(name, x, z, attrs, near)
	local p = { Name = name, Pos = vec(x, 0, z), Attrs = attrs or {}, Near = near or 0 }
	function p:GetAttribute(key) return self.Attrs[key] end
	return p
end
local function withAttrs(base, more)
	for k, v in more or {} do base[k] = v end
	return base
end
local function hunter(name, x, z, more, near)
	return player(name, x, z, withAttrs({ TutorialStep = TUT.Steps.Quest, Level = 1 }, more), near)
end
local function veteran(name, x, z, more, near) -- past the first mission (TutorialStep 99)
	return player(name, x, z, withAttrs({ TutorialStep = TUT.Steps.Done, Level = 2 }, more), near)
end

runGroup("config and hunters", function()
	local base, TS = C.SpawnSpread, C.SpawnSpread.Tutorial
	check(type(TS) == "table" and TS.StarvedThreshold == 3 and TS.MinDist == RING_MIN and TS.MaxDist == RING_MAX
		and TS.Extra == EXTRA, "Config.SpawnSpread.Tutorial = { StarvedThreshold 3, 10-18, Extra 3 }", show(TS))
	check(base.StarvedThreshold == 2 and base.MinDist == REG_MIN and base.MaxDist == REG_MAX and base.Tries == 6,
		"the A7-1 spread stays { 2, 18-28, 6 tries }", show(base))
	check(TUT.Steps.Quest == 2 and TUT.Monster == "Slime" and TUT.GuideZone == "SlimeMeadow" and SLIME.Zone == TUT.GuideZone,
		"the first mission hunts Slimes in the SlimeMeadow (step 2)", show({ TUT.Steps.Quest, TUT.Monster, TUT.GuideZone }))
	local th = spawnWorld().M.tutorialHunter
	check(th(hunter("a", 330, 0), "SlimeMeadow") == true, "TutorialStep 2 in the meadow: a hunter")
	check(th(veteran("b", 330, 0), "SlimeMeadow") == false, "past the first mission (99): not a hunter")
	check(th(player("c", 330, 0, { TutorialStep = TUT.Steps.Guide }), "SlimeMeadow") == false, "step 1 (on the way): not a hunter")
	check(th(player("d", 330, 0, {}), "SlimeMeadow") == false, "no TutorialStep: not a hunter")
	check(th(hunter("e", 720, 0), "GoblinWoods") == false, "step 2 outside the meadow: not a hunter")
end)

runGroup("targets", function()
	local function wanted(players)
		local w = spawnWorld(players)
		local zc = w.M.playersPerZone()
		return w, zc, w.M.wantedTargets(zc), C.MonsterTargets(zc)
	end
	-- a lone sprout
	local w, zc, got, base = wanted({ hunter("a", 330, 0) })
	check(zc.SlimeMeadow == 1 and w.M.TUT_SPAWN.Hunters.SlimeMeadow == 1, "playersPerZone counts the hunter",
		show({ zc, w.M.TUT_SPAWN.Hunters }))
	check(got.Slime == base.Slime + EXTRA, "one hunter: the meadow wants 3 more slimes", show({ got.Slime, base.Slime }))
	local others = {}
	for kind, n in base do
		if kind ~= TUT.Monster and got[kind] ~= n then table.insert(others, kind) end
	end
	for kind in got do
		if base[kind] == nil then table.insert(others, kind) end
	end
	check(#others == 0, "every other kind keeps Config.MonsterTargets (King Slimes too)", show(others))
	check(w.M.targetCount("Slime", zc) == base.Slime + EXTRA, "targetCount sees the bonus", w.M.targetCount("Slime", zc))
	local capped = w.M.cappedTargets(zc)
	check(capped.Slime == base.Slime + EXTRA, "cappedTargets keeps it (room under the GlobalCap)",
		show({ capped.Slime, w.M.GLOBAL_CAP }))
	check(capped.Slime > C.EffectiveMonsterCounts().Slime,
		"a lone sprout on a quiet server: more slimes wanted than the 12 alive, so new ones spawn now",
		show({ capped.Slime, C.EffectiveMonsterCounts().Slime }))
	-- two hunters, a hunter + a veteran, a veteran alone, step 2 elsewhere
	w, zc, got, base = wanted({ hunter("a", 330, 0), hunter("a2", 300, 60) })
	check(got.Slime == base.Slime + 2 * EXTRA, "two hunters: +2 x 3", show({ got.Slime, base.Slime }))
	w, zc, got, base = wanted({ hunter("a", 330, 0), veteran("b", 300, 60) })
	check(zc.SlimeMeadow == 2 and got.Slime == base.Slime + EXTRA, "a hunter + a veteran: one bonus",
		show({ zc.SlimeMeadow, got.Slime, base.Slime }))
	w, zc, got, base = wanted({ veteran("b", 330, 0) })
	check(got.Slime == base.Slime and w.M.TUT_SPAWN.Hunters.SlimeMeadow == nil, "a veteran alone: no bonus",
		show({ got.Slime, base.Slime }))
	w, zc, got, base = wanted({ hunter("e", 720, 0) })
	check(got.Slime == base.Slime, "step 2 outside the meadow: no bonus", show({ got.Slime, base.Slime }))
	-- the bonus ends with the hunt (every playersPerZone refreshes the hunters)
	local a = hunter("a", 330, 0)
	w = spawnWorld({ a })
	zc = w.M.playersPerZone()
	local before = w.M.wantedTargets(zc).Slime
	a.Attrs.TutorialStep = TUT.Steps.Done
	zc = w.M.playersPerZone()
	local after = w.M.wantedTargets(zc).Slime
	check(before == C.MonsterTargets(zc).Slime + EXTRA and after == C.MonsterTargets(zc).Slime,
		"after the first [Claim] the bonus is gone", show({ before, after }))
	-- never above Count x MaxZoneMult
	local five = {}
	for i = 1, 5 do table.insert(five, hunter("h" .. i, 250 + i * 20, 0)) end
	w, zc, got, base = wanted(five)
	local cap = SLIME.Count * C.MonsterDensity.MaxZoneMult
	check(got.Slime == cap and base.Slime + 5 * EXTRA > cap, "five hunters: capped at Count x MaxZoneMult (24)",
		show({ got.Slime, cap, base.Slime }))
end)

runGroup("the ring near the hunter", function()
	-- off the middle: 60 slimes, all 10-18 away and on the half circle facing the meadow middle
	local a = hunter("a", 300, 40)
	local w = spawnWorld({ a })
	local bad, minD, back = {}, math.huge, 0
	local midX, midZ = MEADOW.Center.X - a.Pos.X, MEADOW.Center.Z - a.Pos.Z
	for i = 1, 60 do
		local g = w.M.pickSpawnPoint(SLIME, "Slime")
		if not g then
			table.insert(bad, i .. ":nil")
		else
			local d = flat(g, a.Pos)
			minD = math.min(minD, d)
			if d < RING_MIN - EPS or d > RING_MAX + EPS or C.ZoneAt(g).Id ~= TUT.GuideZone then table.insert(bad, i .. ":" .. d) end
			if (g.X - a.Pos.X) * midX + (g.Z - a.Pos.Z) * midZ < -EPS then back += 1 end
		end
	end
	check(#bad == 0, "60 slimes for a starved hunter: all 10-18 studs away, inside the meadow", show(bad))
	check(minD < 14, "closer than the old 18-28 ring", minD)
	check(back == 0, "all on the half circle facing the meadow middle", back)
	check(w.Radius[1] == 30, "starved = monsters within 30 studs (A7-1)", w.Radius[1])
	-- two near is still starved for a hunter (threshold 3)
	a.Near = 2
	local g = w.M.pickSpawnPoint(SLIME, "Slime")
	local d = g and flat(g, a.Pos) or -1
	check(d >= RING_MIN - EPS and d <= RING_MAX + EPS, "2 slimes near: still the hunter ring", d)
	-- three near: not starved; a starved veteran elsewhere gets the regular ring
	a.Near = 3
	local b = veteran("b", 330, -80)
	w.Players = { a, b }
	g = w.M.pickSpawnPoint(SLIME, "Slime")
	d = g and flat(g, b.Pos) or -1
	check(d >= REG_MIN - EPS and d <= REG_MAX + EPS, "3 slimes near the hunter: a starved veteran gets the 18-28 ring", d)
	-- the meadow entrance (the trip lands at Spawn facing the middle, on the spawn-inset edge): never a far fallback
	local e = hunter("e", MEADOW.Spawn.X, MEADOW.Spawn.Z)
	w = spawnWorld({ e })
	local far = 0
	for _ = 1, 100 do
		local p = w.M.pickSpawnPoint(SLIME, "Slime")
		local pd = p and flat(p, e.Pos) or -1
		if pd < RING_MIN - EPS or pd > RING_MAX + EPS then far += 1 end
	end
	check(far == 0, "at the meadow entrance: 100 / 100 slimes within 10-18", far)
	-- scripted draws (angle, distance): 0.5 / 0 = straight at the middle, 10 studs
	local ahead = vec(e.Pos.X + RING_MIN, 0, e.Pos.Z)
	w.Rng.Script = { 0.5, 0 }
	g = w.M.pickSpawnPoint(SLIME, "Slime")
	check(g and flat(g, ahead) < EPS, "draw 0.5 = straight toward the meadow middle", g and show({ g.X, g.Z }))
	-- six tries along the inset edge miss (angle -90 deg), the seventh lands: twice the tries
	local script = {}
	for _ = 1, 6 do
		table.insert(script, 0)
		table.insert(script, 0)
	end
	table.insert(script, 0.5)
	table.insert(script, 0)
	w.Rng.Script = script
	g = w.M.pickSpawnPoint(SLIME, "Slime")
	check(g and flat(g, ahead) < EPS, "6 misses on the inset edge: the 7th try still lands near", g and show({ g.X, g.Z }))
	check(#w.Warnings == 0, "no 'no walkable ground' warnings", w.Warnings[1])
end)

runGroup("who goes first", function()
	-- which player the new monster lands near (spots 180+ studs apart: a ring point is never near both)
	local function nearOf(players, kind)
		local w = spawnWorld(players)
		local g = w.M.pickSpawnPoint(C.MonsterTypes[kind], kind)
		local best, bestD = nil, math.huge
		for _, p in players do
			local d = g and flat(g, p.Pos) or math.huge
			if d < bestD then best, bestD = p, d end
		end
		return best and best.Name, bestD
	end
	local function both(label, a, b, kind, want, lo, hi)
		local seen = {}
		for _, list in { { a, b }, { b, a } } do
			local name, d = nearOf(list, kind)
			table.insert(seen, { name, d })
			if not (name == want and d >= lo - EPS and d <= hi + EPS) then
				check(false, label, show(seen))
				return
			end
		end
		check(true, label)
	end
	local P, Q = { 260, -60 }, { 400, 60 }
	both("the hunter beats a Rookie with fewer slimes near (both orders)",
		hunter("hunt", P[1], P[2], { Level = 3 }, 2), veteran("rook", Q[1], Q[2], { Rookie = true, Level = 1 }, 0),
		"Slime", "hunt", RING_MIN, RING_MAX)
	local name, d = nearOf({ hunter("hunt", P[1], P[2]) }, "BigSlime")
	check(name == "hunt" and d >= REG_MIN - EPS and d <= REG_MAX + EPS, "a King Slime keeps the regular 18-28 ring", d)
	both("a King Slime: a hunter with 2 near is not starved (threshold 2), the Rookie is",
		hunter("hunt", P[1], P[2], {}, 2), veteran("rook", Q[1], Q[2], { Rookie = true }, 0),
		"BigSlime", "rook", REG_MIN, REG_MAX)
	both("no hunters: a Rookie first, even with more slimes near and a higher level",
		veteran("rook", P[1], P[2], { Rookie = true, Level = 5 }, 1), veteran("vet", Q[1], Q[2], { Level = 1 }, 0),
		"Slime", "rook", REG_MIN, REG_MAX)
	both("then the lower level", veteran("lv3", P[1], P[2], { Level = 3 }, 0), veteran("lv2", Q[1], Q[2], { Level = 2 }, 1),
		"Slime", "lv2", REG_MIN, REG_MAX)
	both("then the fewest slimes near", veteran("one", P[1], P[2], { Level = 2 }, 1), veteran("zero", Q[1], Q[2], { Level = 2 }, 0),
		"Slime", "zero", REG_MIN, REG_MAX)
	local dead = hunter("dead", P[1], P[2])
	dead.Dead = true
	both("a dead hunter pulls no slimes", dead, veteran("vet", Q[1], Q[2], {}, 0), "Slime", "vet", REG_MIN, REG_MAX)
end)

finish()
