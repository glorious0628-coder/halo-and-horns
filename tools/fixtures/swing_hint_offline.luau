-- swing_hint_offline.luau : A23-91 server target hint (dev2 2026-10-10). The client sends its pick (HUD.PickTarget: the
-- monster Model) as argument 1 of Swing and Release; CombatService takes it for MANUAL attacks when it is the Model of a
-- monster the attack's own filter (monstersNear: alive, mine or nobody's, the zone level gate) finds within Range +
-- HINT.Slack (2) and not a hidden ambusher. Lead decision 2026-10-10: a pick may only change which MONSTERS a press hits,
-- never which enemy players or the goose - so the pick is ignored whenever the same press without it would hit an enemy
-- or the goose (R1: one in the real front half; Splash / Q: one in the blast at today's centre), and a press that uses it
-- hits monsters only (R2 outside the cone and R3 in the slack zone fall out of that). With the pick: the aim follows it
-- unless it is within HINT.KeepDeg (10) of the facing, through a facing for the hit math only - the real root is NEVER
-- written (review B; today's A23-61 turn still writes it); Splash centres on it, Multi hits it first, Around hits it even
-- at Range + Slack (nobody else gets the slack), Q (a Target-centred class) centres on it. Ends with a seeded
-- differential check: random scenes run with and without the pick give the same enemy HP and goose tugs.
-- tools/test_swing_hint.py binds the CURRENT sources of tools/test_unarmed_start.py plus DamageWindow / SkillService
-- (dev2_kit.luau and dev2_combat_world.luau come first). Players face -Z at the origin; H.At(deg, dist): 0 deg = straight
-- ahead, 90 = right, 180 = right behind.

local H = {}

-- speed (this suite builds ~900 worlds): the kit's execute() compiles every module source again for each world; the
-- same source string always compiles to the same function, so keep one per source (execute still gives each world its
-- own fresh environment with setfenv and runs the module again: separate module state, as before)
do
	local compile, compiled = loadstring, {}
	loadstring = function(source, chunk)
		local key = tostring(chunk) .. "\0" .. source
		local fn = compiled[key]
		if not fn then
			local err
			fn, err = compile(source, chunk)
			if not fn then return fn, err end
			compiled[key] = fn
		end
		return fn
	end
end

-- true when anything wrote the real root's CFrame since `cf0` (a write always puts a new CFrame value there)
function H.Wrote(p, cf0)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local cf = root and root.CFrame
	if type(cf) == "table" then cf.Turned = nil end
	return not rawequal(cf, cf0)
end

function H.Cf(p)
	return p.Character:FindFirstChild("HumanoidRootPart").CFrame
end

function H.At(deg, dist)
	local r = math.rad(deg)
	return dist * math.sin(r), dist * math.cos(r) -- dx, dz (dz > 0 = in front, -Z)
end

function H.Pos(deg, dist)
	local dx, dz = H.At(deg, dist)
	return vec(dx, 0, -dz)
end

-- a monster record with its Model (what the client sends) `dist` studs away at `deg`
function H.Mob(w, deg, dist, o)
	o = o or {}
	local dx, dz = H.At(deg, dist)
	local rec = w:Monster(o.Kind or "Slime", dz, dx, o.HP or 99999)
	local model = newInstance("Model", w)
	model.Name = rec.Kind
	rec.Model = model
	return rec
end

-- a world; o.Class / o.Bare pick the attacker, o.Auto = auto combat ON, o.Goose = the goose at that position, o.Mana
function H.World(o)
	o = o or {}
	local w = bareWorld({ Hit = true })
	w.Tugs = {}
	if o.Goose then
		w.Config.Goose.Mode = "Tug" -- A23-131: only the old tug's goose is a swing target
		w.Registry.GooseService.GetPosition = function() return o.Goose end
		w.Registry.GooseService.RegisterHit = function(pl) table.insert(w.Tugs, pl) return 1 end
	end
	w.Rel = {}
	w.Combat.Released:Connect(function(p, info) table.insert(w.Rel, { P = p, Info = info }) end)
	local class = o.Class or "Warrior"
	local attrs = { Mana = o.Mana or 100 }
	if o.Auto then attrs.AutoCombatUnlocked, attrs.AutoCombatEnabled = true, true end
	local p = w:Join(1, { Class = class, Faction = "Halo", Level = 5, Tier = o.Bare and 0 or 1, Mask = o.Bare and 0 or 1,
		Attrs = attrs })
	w.Me = p
	w.Range = o.Bare and w.Config.Combat.Unarmed.Range or w.Config.Classes[class].Range
	w.QRange = w.Config.Classes[class].Range
	return w, p
end

function H.Enemy(w, id, deg, dist)
	return w:Join(id, { Class = "Warrior", Faction = "Horns", Level = 5, Tier = 1, Mask = 1, Pos = H.Pos(deg, dist) })
end

function H.Hp(v)
	return v.Character:FindFirstChild("Humanoid").Health
end

-- the number of hits a record took
function H.Hits(w, rec)
	local n = 0
	for _, d in w.Damage do if d.Rec == rec then n += 1 end end
	return n
end

-- one manual swing through the Swing remote (past every swing interval / the rate limit); returns "the root was written"
function H.Swing(w, p, ...)
	w:Advance(1.2)
	local cf0 = H.Cf(p)
	w.Net.Get("Swing").OnServerEvent:Fire(p, ...)
	w:Flush()
	return H.Wrote(p, cf0)
end

-- one skill Q press through the old Release remote (past the Q cooldown); returns "the root was written"
function H.Release(w, p, ...)
	w:Advance(3.5)
	local cf0 = H.Cf(p)
	w.Net.Get("Release").OnServerEvent:Fire(p, ...)
	w:Flush()
	return H.Wrote(p, cf0)
end

-- the last Released info (Q)
function H.Last(w)
	return w.Rel[#w.Rel] and w.Rel[#w.Rel].Info
end

function H.Near(a, b)
	return a ~= nil and b ~= nil and math.abs(a.X - b.X) < 0.01 and math.abs(a.Z - b.Z) < 0.01
end

-- a scene `{ Class, Bare, Q, Goose = {deg, dist}, Mobs = {{deg, dist}}, Enemies = {{deg, dist}}, Pick = {deg, dist} }`
-- built on a fresh world and pressed once, with the pick (useHint) or without it. Returns { E = enemy HPs, T = goose
-- tugs, M = the dealt of each monster (the pick last), P = the pick's dealt, W = the root written, C = Q's centre }
function H.Run(s, useHint)
	local goose = s.Goose and H.Pos(s.Goose[1], s.Goose[2]) or nil
	local w, p = H.World({ Class = s.Class, Bare = s.Bare, Goose = goose })
	local mobs = {}
	for i, m in s.Mobs or {} do mobs[i] = H.Mob(w, m[1], m[2]) end
	local enemies = {}
	for i, e in s.Enemies or {} do enemies[i] = H.Enemy(w, 1 + i, e[1], e[2]) end
	local pick = s.Pick and H.Mob(w, s.Pick[1], s.Pick[2]) or nil
	if pick and s.Bad then s.Bad(pick) end
	local hint = nil
	if useHint then hint = s.Hint and s.Hint(w, pick, enemies) or (pick and pick.Model) end
	local wrote
	if s.Q then wrote = H.Release(w, p, hint) else wrote = H.Swing(w, p, hint) end
	local out = { E = {}, M = {}, T = #w.Tugs, W = wrote, P = pick and w:Dealt(pick) or 0, Warn = #w.Warnings }
	for i, v in enemies do out.E[i] = H.Hp(v) end
	for i, m in mobs do out.M[i] = w:Dealt(m) end
	local info = s.Q and H.Last(w) or nil
	out.C = info and info.Center or nil
	return out
end

-- the same scene with and without the pick: enemy HP and goose tugs must be equal (lead 2026-10-10)
function H.Same(a, b)
	return show(a.E) == show(b.E) and a.T == b.T
end

------------------------------------------------------------------ the pick wins (no enemy, no goose)
runGroup("warrior: the pick wins", function()
	-- today: a slime in front is hit, the one behind is not; with the behind one as my pick: it is hit, the front one
	-- (130 deg off the pick) is not; the real root is never written
	local a = H.Run({ Mobs = { { 30, 4 } }, Pick = { 160, 8 } }, true)
	check(a.P > 0 and a.M[1] == 0, "a pick behind me: it is hit, the nearer front slime is not", show({ a.P, a.M[1] }))
	check(not a.W, "review B: the real root is not written", a.W)
	local b = H.Run({ Mobs = { { 30, 4 } }, Pick = { 160, 8 } }, false)
	check(b.P == 0 and b.M[1] > 0, "control: no pick = today's rule (the front slime)", show({ b.P, b.M[1] }))
	-- within KeepDeg (5 deg): the aim stays my facing - a slime at -87 deg (inside my front half, 92 deg off the pick)
	-- is still hit
	local w2, p2 = H.World()
	local pick = H.Mob(w2, 5, 6)
	local other = H.Mob(w2, 40, 6)
	local edge = H.Mob(w2, -87, 6)
	local wrote2 = H.Swing(w2, p2, pick.Model)
	check(w2:Dealt(pick) > 0 and w2:Dealt(other) > 0 and w2:Dealt(edge) > 0 and not wrote2,
		"a pick 5 deg off my facing: the aim stays (the -87 deg slime is hit), no root write",
		show({ w2:Dealt(pick), w2:Dealt(other), w2:Dealt(edge), wrote2 }))
	check(H.Hits(w2, pick) == 1 and H.Hits(w2, other) == 1, "the pick is hit once (no second copy), the other slime once",
		show({ H.Hits(w2, pick), H.Hits(w2, other) }))
	-- KeepDeg bracket (20 deg): the aim follows the pick - a slime at -80 deg (100 deg off the pick) is not hit, one at
	-- 105 deg (behind my facing, 85 deg off the pick) is
	local c = H.Run({ Mobs = { { -80, 6 }, { 105, 6 } }, Pick = { 20, 6 } }, true)
	check(c.P > 0 and c.M[1] == 0 and c.M[2] > 0 and not c.W,
		"a pick 20 deg off: the monster sweep is the pick's front half (-80 deg out, 105 deg in), no root write",
		show({ c.P, c.M[1], c.M[2], c.W }))
end)

------------------------------------------------------------------ R1: an enemy / the goose in front: the pick is ignored
runGroup("R1: an enemy or the goose in front, the pick is ignored", function()
	-- each case: the press with the pick = the press without it (enemy HP, tugs, monsters)
	local cases = {
		{ "Warrior: enemy 0/5, pick 170/6: the enemy is hit, the pick is not", { Enemies = { { 0, 5 } }, Pick = { 170, 6 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "Mage swing: enemy 0/8, pick 160/20: the enemy is hit", { Class = "Mage", Enemies = { { 0, 8 } }, Pick = { 160, 20 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "Mage Q: enemy 0/8, pick 160/20: the blast on the enemy", { Class = "Mage", Q = true, Enemies = { { 0, 8 } }, Pick = { 160, 20 } },
			function(a) return a.E[1] < 100 and a.P == 0 and H.Near(a.C, H.Pos(0, 8)) end },
		{ "Warrior: the goose 4 ahead, pick 170/6: one tug, the pick is not hit", { Goose = { 0, 4 }, Pick = { 170, 6 } },
			function(a) return a.T == 1 and a.P == 0 end },
		{ "Archer Q: pick 95/12, enemy 0/6: the enemy is hit", { Class = "Archer", Q = true, Enemies = { { 0, 6 } }, Pick = { 95, 12 } },
			function(a) return a.E[1] < 100 and H.Near(a.C, H.Pos(0, 6)) end },
		{ "Mage swing: enemy 0/5, pick 0/30: the nearer enemy is the centre", { Class = "Mage", Enemies = { { 0, 5 } }, Pick = { 0, 30 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "Mage Q: enemy 0/5, pick 0/30: the blast on the nearer enemy", { Class = "Mage", Q = true, Enemies = { { 0, 5 } }, Pick = { 0, 30 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "bare hands: enemy 0/3, pick 5/6: the punch goes to the enemy", { Bare = true, Enemies = { { 0, 3 } }, Pick = { 5, 6 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "Archer: pick 60/20, slime 140/5, enemy 0/8: the enemy and the pick (as without it)",
			{ Class = "Archer", Mobs = { { 140, 5 } }, Enemies = { { 0, 8 } }, Pick = { 60, 20 } },
			function(a) return a.E[1] < 100 and a.P > 0 and a.M[1] == 0 end },
		{ "Archer: pick 60/20, slimes -60/3 and -50/4, enemy 0/8: the two slimes (as without it)",
			{ Class = "Archer", Mobs = { { -60, 3 }, { -50, 4 } }, Enemies = { { 0, 8 } }, Pick = { 60, 20 } },
			function(a) return a.E[1] == 100 and a.P == 0 and a.M[1] > 0 and a.M[2] > 0 end },
		{ "Warrior: pick 30/5, enemy straight ahead: both hit", { Enemies = { { 0, 4 } }, Pick = { 30, 5 } },
			function(a) return a.E[1] < 100 and a.P > 0 end },
		{ "Warrior: pick 120/5, enemy straight ahead: the enemy is hit, the pick is not", { Enemies = { { 0, 4 } }, Pick = { 120, 5 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "Warrior: pick 150/5, the goose in front: one tug, the pick is not hit", { Goose = { 0, 4 }, Pick = { 150, 5 } },
			function(a) return a.T == 1 and a.P == 0 end },
		{ "Mage: pick 30/20, an enemy beside it: both in the blast", { Class = "Mage", Enemies = { { 30, 22 } }, Pick = { 30, 20 } },
			function(a) return a.E[1] < 100 and a.P > 0 end },
		{ "Mage Q: pick 30/20, an enemy beside it: both in the blast", { Class = "Mage", Q = true, Enemies = { { 30, 22 } }, Pick = { 30, 20 } },
			function(a) return a.E[1] < 100 and a.P > 0 end },
		{ "Archer: pick 0/25, enemy 10/8: the enemy and the pick", { Class = "Archer", Enemies = { { 10, 8 } }, Pick = { 0, 25 } },
			function(a) return a.E[1] < 100 and a.P > 0 end },
		{ "Archer: pick 0/25, the goose 8 ahead: one tug and the pick", { Class = "Archer", Goose = { 0, 8 }, Pick = { 0, 25 } },
			function(a) return a.T == 1 and a.P > 0 end },
		{ "Archer: pick 180/15, an enemy and the goose ahead: those two, not the pick",
			{ Class = "Archer", Goose = { 0, 8 }, Enemies = { { 0, 8 } }, Pick = { 180, 15 } },
			function(a) return a.E[1] < 100 and a.T == 1 and a.P == 0 end },
		{ "Mage: pick 0/25, the goose 5 ahead: the goose is the centre (one tug), the pick is not hit",
			{ Class = "Mage", Goose = { 0, 5 }, Pick = { 0, 25 } }, function(a) return a.T == 1 and a.P == 0 end },
		{ "Warrior: pick 0/5, the goose 4 ahead: the slime and one tug", { Goose = { 0, 4 }, Pick = { 0, 5 } },
			function(a) return a.T == 1 and a.P > 0 end },
		-- Splash / Q: one in the blast at today's centre (the nearest front monster), beyond my Range: still today's result
		{ "Mage: an enemy just past the nearest front slime (beyond Range), pick 160/20: the enemy is hit",
			{ Class = "Mage", Mobs = { { 0, 30 } }, Enemies = { { 0, 36 } }, Pick = { 160, 20 } },
			function(a) return a.E[1] < 100 and a.P == 0 and a.M[1] > 0 end },
		{ "Mage: the goose just past the nearest front slime (beyond reach), pick 160/20: one tug",
			{ Class = "Mage", Mobs = { { 0, 32 } }, Goose = { 0, 41 }, Pick = { 160, 20 } },
			function(a) return a.T == 1 and a.P == 0 end },
		{ "Mage Q: an enemy just past the nearest front slime (beyond Range), pick 160/20: the enemy is hit",
			{ Class = "Mage", Q = true, Mobs = { { 0, 30 } }, Enemies = { { 0, 37 } }, Pick = { 160, 20 } },
			function(a) return a.E[1] < 100 and a.P == 0 end },
		{ "Mage Q: only a pick in the slack zone, an enemy behind me: today's blast on me hits the enemy",
			{ Class = "Mage", Q = true, Enemies = { { 180, 5 } }, Pick = { 0, 36 } },
			function(a) return a.E[1] < 100 and a.P == 0 and H.Near(a.C, vec(0, 0, 0)) end },
	}
	for _, case in cases do
		local a = H.Run(case[2], true)
		local b = H.Run(case[2], false)
		check(H.Same(a, b) and show(a.M) == show(b.M) and a.P == b.P and case[3](a) and a.Warn == 0, case[1],
			show({ With = { a.E, a.T, a.P, a.M }, Without = { b.E, b.T, b.P, b.M } }))
	end
end)

------------------------------------------------------------------ monsters only (R2 / R3)
runGroup("a press on the pick hits monsters only", function()
	-- R3: a pick in the slack zone; an enemy / the goose beyond today's reach but inside the blast at the pick: not hit
	local range = H.World({ Class = "Mage" }).Range
	local cases = {
		{ "Mage swing: pick at Range + 1.9, an enemy at 43.8 beside it: not hit", { Class = "Mage", Enemies = { { 0, 43.8 } },
			Pick = { 0, range + 1.9 } }, function(a) return a.E[1] == 100 and a.P > 0 end },
		{ "Mage swing: pick at Range + 1.9, the goose at 47.8 beside it: no tug", { Class = "Mage", Goose = { 0, 47.8 },
			Pick = { 0, range + 1.9 } }, function(a) return a.T == 0 and a.P > 0 end },
		{ "Mage Q: pick at Range + 1.9, an enemy at 45.8 beside it: not hit", { Class = "Mage", Q = true, Enemies = { { 0, 45.8 } },
			Pick = { 0, range + 1.9 } }, function(a) return a.E[1] == 100 and a.P > 0 and H.Near(a.C, H.Pos(0, range + 1.9)) end },
		{ "Archer Q: pick at 31.9, an enemy at 40.8 beside it: not hit", { Class = "Archer", Q = true, Enemies = { { 0, 40.8 } },
			Pick = { 0, 31.9 } }, function(a) return a.E[1] == 100 and a.P > 0 end },
		-- R2: a pick behind me, an enemy beside it (nothing in front would reach them today): the pick, not the enemy
		{ "Mage swing: pick behind (150/20), an enemy beside it: the pick and its neighbour, not the enemy",
			{ Class = "Mage", Mobs = { { 0, 10 }, { 150, 23 } }, Enemies = { { 150, 18 } }, Pick = { 150, 20 } },
			function(a) return a.E[1] == 100 and a.P > 0 and a.M[1] == 0 and a.M[2] > 0 and not a.W end },
		{ "Mage Q: pick behind (160/20), an enemy beside it: the blast there, not the enemy",
			{ Class = "Mage", Q = true, Mobs = { { 0, 10 } }, Enemies = { { 160, 22 } }, Pick = { 160, 20 } },
			function(a) return a.E[1] == 100 and a.M[1] == 0 and H.Near(a.C, H.Pos(160, 20)) and not a.W end },
		{ "Warrior: pick behind (180/5), an enemy and the goose behind me: the pick only",
			{ Goose = { 180, 4 }, Enemies = { { 170, 4 } }, Pick = { 180, 5 } },
			function(a) return a.E[1] == 100 and a.T == 0 and a.P > 0 and not a.W end },
		{ "Archer: pick behind (180/15) alone: the pick, no root write", { Class = "Archer", Pick = { 180, 15 } },
			function(a) return a.P > 0 and not a.W end },
	}
	for _, case in cases do
		local a = H.Run(case[2], true)
		local b = H.Run(case[2], false)
		check(H.Same(a, b) and case[3](a) and a.Warn == 0, case[1], show({ With = { a.E, a.T, a.P, a.M, a.W }, Without = { b.E, b.T, b.P } }))
	end
end)

runGroup("the slack is the pick's only", function()
	local w0 = H.World()
	local range = w0.Range
	local a = H.Run({ Pick = { 180, range + 1 } }, true)
	check(a.P > 0, "a pick at Range + 1 (behind): accepted, it is hit", a.P)
	local b = H.Run({ Pick = { 180, range + 3 } }, true)
	check(b.P == 0 and not b.W, "a pick at Range + 3: ignored (no hit, no turn)", show({ b.P, b.W }))
	local c = H.Run({ Mobs = { { 20, range + 1 }, { 20, range - 2 } }, Pick = { 0, range + 1 } }, true)
	check(c.P > 0 and c.M[1] == 0 and c.M[2] > 0, "Around: the pick at Range + 1 is hit, another slime at Range + 1 is not, one inside Range is",
		show({ c.P, c.M }))
	local d = H.Run({ Mobs = { { 170, range + 1 } }, Pick = { 180, range + 1 } }, true)
	check(d.P > 0 and d.M[1] == 0, "behind: only the pick gets the slack (its neighbour at Range + 1 is not hit)", show({ d.P, d.M }))
	local e = H.Run({ Class = "Archer", Pick = { 0, 31 } }, true)
	check(e.P > 0, "Archer: a pick at Range + 1 straight ahead is shot", e.P)
	local f = H.Run({ Class = "Mage", Pick = { 0, 36 } }, true)
	check(f.P > 0, "Mage: a lone pick at Range + 1 straight ahead is the orb's centre", f.P)
end)

------------------------------------------------------------------ ignored hints: exactly today's swing
runGroup("bad hints are ignored", function()
	local scene = { Mobs = { { 30, 4 } }, Pick = { 160, 8 } }
	local base = H.Run(scene, false)
	local function sig(o) return show({ o.E, o.T, o.M, o.P, o.W, o.Warn }) end
	check(base.M[1] > 0 and base.P == 0, "setup: with no pick the scene hits the front slime only", sig(base))
	local accepted = H.Run(scene, true)
	check(sig(accepted) ~= sig(base), "setup: a valid pick changes the scene's outcome", show({ sig(base), sig(accepted) }))
	local bad = {
		{ "a hidden ambusher (MonsterService _hidden)", function(b) b._hidden = true end },
		{ "a monster model marked Hidden", function(b) b.Model:SetAttribute("Hidden", true) end },
		{ "a dead monster", function(b) b.Alive = false end },
	}
	local hints = {
		{ "a part (the monster's root)", function(_, pick) return pick.Root end },
		{ "a model that is no monster", function(w) return newInstance("Model", w) end },
		{ "a string", function() return "Slime" end },
		{ "a number", function() return 3 end },
		{ "a table", function(_, pick) return { Model = pick.Model } end },
		{ "true", function() return true end },
	}
	for _, case in bad do
		local s = { Mobs = scene.Mobs, Pick = scene.Pick, Bad = case[2] }
		check(sig(H.Run(s, true)) == sig(H.Run(s, false)) and sig(H.Run(s, false)) == sig(base), case[1] .. ": ignored (the same swing as with no pick)",
			show({ sig(H.Run(s, true)), sig(base) }))
	end
	for _, case in hints do
		local s = { Mobs = scene.Mobs, Pick = scene.Pick, Hint = case[2] }
		check(sig(H.Run(s, true)) == sig(base), case[1] .. ": ignored (the same swing as with no pick)", show({ sig(H.Run(s, true)), sig(base) }))
	end
	-- another player's personal monster, a player's character, the zone level gate (outcome = no pick)
	local function own(w, pick)
		pick.Owner = H.Enemy(w, 7, 90, 30)
		return pick.Model
	end
	local s1 = { Mobs = scene.Mobs, Pick = scene.Pick, Hint = own }
	local o1, o0 = H.Run(s1, true), H.Run(s1, false)
	check(show({ o1.M, o1.P, o1.W }) == show({ o0.M, o0.P, o0.W }), "another player's personal monster: ignored", show({ sig(o1), sig(o0) }))
	local s2 = { Mobs = scene.Mobs, Pick = scene.Pick, Enemies = { { 160, 6 } }, Hint = function(_, _, enemies) return enemies[1].Character end }
	local o2, o3 = H.Run(s2, true), H.Run(s2, false)
	check(sig(o2) == sig(o3), "a player's character (an enemy behind me): ignored", show({ sig(o2), sig(o3) }))
	local w0 = H.World()
	local gated = nil
	for id, z in w0.Config.Zones do
		if type(z) == "table" and (tonumber(z.MinLevel) or 1) > 5 then gated = id break end
	end
	if gated then
		local s3 = { Mobs = scene.Mobs, Pick = scene.Pick, Bad = function(b) b.ZoneId = gated end }
		check(sig(H.Run(s3, true)) == sig(H.Run(s3, false)), "a monster of a zone above my level (" .. gated .. "): ignored",
			show({ sig(H.Run(s3, true)), sig(H.Run(s3, false)) }))
	else
		finding("no zone above Lv5 in Config.Zones: the zone-gate hint case was skipped")
	end
	-- an ignored pick still lets today's A23-61 rule turn to the nearest monster behind - and that turn still writes the
	-- root (review B: only the pick path never writes it)
	local s4 = { Pick = { 170, 5 }, Bad = function(b) b._hidden = true end }
	local o4 = H.Run(s4, true)
	check(o4.W and o4.P > 0, "an ignored pick: the A23-61 rule still turns (writes the root) to the nearest monster behind", show({ o4.W, o4.P }))
	-- more arguments than the pick: the press still swings, without the pick
	local w2, p2 = H.World()
	local front2 = H.Mob(w2, 30, 4)
	local behind2 = H.Mob(w2, 160, 8)
	H.Swing(w2, p2, behind2.Model, "extra")
	check(w2:Dealt(front2) > 0 and w2:Dealt(behind2) == 0, "Swing(pick, extra): the swing goes as with no pick",
		show({ w2:Dealt(front2), w2:Dealt(behind2) }))
end)

------------------------------------------------------------------ patterns (no enemy, no goose)
runGroup("mage splash", function()
	local w, p = H.World({ Class = "Mage" })
	local front = H.Mob(w, 0, 10)
	local pick = H.Mob(w, 150, 20)
	local past = H.Mob(w, 150, 23)
	local wrote = H.Swing(w, p, pick.Model)
	check(w:Dealt(pick) > 0 and w:Dealt(past) > 0 and w:Dealt(front) == 0 and not wrote,
		"Splash (pick behind): centre = the pick, its neighbour hit, the front slime not, no root write",
		show({ w:Dealt(pick), w:Dealt(past), w:Dealt(front), wrote }))
	local fx = w:FxOf("Swing")
	check(#fx > 0 and H.Near(fx[#fx].Data.Pos, pick.Root.Position), "the orb Fx lands on the pick", fx[#fx] and show(fx[#fx].Data.Pos))
	local a = H.Run({ Class = "Mage", Mobs = { { 0, 10 } }, Pick = { 0, 25 } }, true)
	check(a.P > 0 and a.M[1] == 0, "Splash (ahead): centre = the pick, not the nearer slime", show({ a.P, a.M }))
end)

runGroup("archer multi and bare hands", function()
	local a = H.Run({ Class = "Archer", Mobs = { { 30, 10 }, { -30, 15 } }, Pick = { 0, 25 } }, true)
	check(a.P > 0 and a.M[1] > 0 and a.M[2] == 0, "Multi: the pick first, then the nearest (Targets 2)", show({ a.P, a.M }))
	local w2, p2 = H.World({ Class = "Archer" })
	local pick2 = H.Mob(w2, 0, 8)
	local m3 = H.Mob(w2, 30, 10)
	H.Swing(w2, p2, pick2.Model)
	check(H.Hits(w2, pick2) == 1 and H.Hits(w2, m3) == 1, "Multi: the pick is never shot twice (the second arrow goes to the next)",
		show({ H.Hits(w2, pick2), H.Hits(w2, m3) }))
	local b = H.Run({ Bare = true, Mobs = { { 20, 3 } }, Pick = { 170, 5 } }, true)
	check(b.P > 0 and b.M[1] == 0 and not b.W, "bare hands: the punch goes to the pick, the nearer front slime is not hit", show({ b.P, b.M, b.W }))
end)

------------------------------------------------------------------ auto, the queue
runGroup("auto never takes a pick", function()
	local w, p = H.World({ Auto = true })
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	w:Advance(1.2)
	w.Combat.Swing(p, false, behind.Model)
	w:Flush()
	check(w:Dealt(front) > 0 and w:Dealt(behind) == 0, "an auto swing with a pick: the pick is ignored (today's rule)",
		show({ w:Dealt(front), w:Dealt(behind) }))
	local w2, p2 = H.World({ Class = "Mage", Auto = true })
	local near = H.Mob(w2, 0, 10)
	local pick = H.Mob(w2, 0, 30)
	w2:Advance(3.5)
	w2.Combat.Release(p2, true, pick.Model)
	w2:Flush()
	local info = H.Last(w2)
	check(info ~= nil and info.Auto == true and H.Near(info.Center, near.Root.Position) and w2:Dealt(pick) == 0,
		"an auto Q with a pick: the pick is ignored (centre = the nearest aimed slime)", info and show({ info.Center, w2:Dealt(pick) }))
	-- the auto-combat loop itself sends none (it swings at the front slime; no MP, so no auto Q blast around me)
	local w3, p3 = H.World({ Auto = true, Mana = 0 })
	local front3 = H.Mob(w3, 30, 4)
	local behind3 = H.Mob(w3, 160, 8)
	w3:Advance(1.2)
	w3:AutoTick()
	check(w3:Dealt(front3) > 0 and w3:Dealt(behind3) == 0, "the auto loop: today's rule", show({ w3:Dealt(front3), w3:Dealt(behind3) }))
end)

runGroup("the queued swing keeps its pick", function()
	local w, p = H.World()
	H.Swing(w, p) -- a whiff: the swing cooldown starts
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	local interval = w.Config.Classes.Warrior.SwingInterval
	w:Advance(interval - 0.1) -- inside MANUAL_GRACE: the press is queued
	local cf0 = H.Cf(p)
	w.Net.Get("Swing").OnServerEvent:Fire(p, behind.Model)
	w:Flush()
	check(w:Dealt(front) == 0 and w:Dealt(behind) == 0, "setup: the early press is queued (nothing yet)", show({ w:Dealt(front), w:Dealt(behind) }))
	w:Advance(0.2)
	local wrote = H.Wrote(p, cf0)
	check(w:Dealt(behind) > 0 and w:Dealt(front) == 0 and not wrote, "the queued swing goes to its pick (no root write)",
		show({ w:Dealt(behind), w:Dealt(front), wrote }))
end)

------------------------------------------------------------------ the skill Q (no enemy)
runGroup("skill Q takes the pick", function()
	local a = H.Run({ Class = "Mage", Q = true, Mobs = { { 0, 10 } }, Pick = { 0, 30 } }, true)
	check(a.C ~= nil and not a.W and H.Near(a.C, H.Pos(0, 30)) and a.P > 0 and a.M[1] == 0,
		"Q (Mage) through SkillService: centre = the pick, the nearer slime is not hit", show({ a.C, a.W, a.P, a.M }))
	local b = H.Run({ Class = "Mage", Q = true, Mobs = { { 0, 10 } }, Pick = { 0, 30 } }, false)
	check(b.C ~= nil and H.Near(b.C, H.Pos(0, 10)) and b.P == 0, "control: Q with no pick = the nearest aimed slime", show(b.C))
	local c = H.Run({ Class = "Archer", Q = true, Pick = { 0, 31 } }, true)
	check(c.C ~= nil and H.Near(c.C, H.Pos(0, 31)), "Q (Archer): a pick at Range + 1 is the centre", show(c.C))
	local d = H.Run({ Class = "Mage", Q = true, Pick = { 0, 38 } }, true)
	check(d.C ~= nil and H.Near(d.C, vec(0, 0, 0)) and d.P == 0, "Q (Mage): a lone pick at Range + 3 is ignored", show({ d.C, d.P }))
	local e = H.Run({ Class = "Mage", Q = true, Mobs = { { 0, 10 } }, Pick = { 0, 30 }, Bad = function(r) r._hidden = true end }, true)
	check(e.C ~= nil and H.Near(e.C, H.Pos(0, 10)), "Q with a hidden pick: ignored (the nearest aimed slime)", show(e.C))
	local f = H.Run({ Q = true, Mobs = { { 30, 4 } }, Pick = { 160, 6 } }, true)
	check(f.C ~= nil and not f.W and H.Near(f.C, vec(0, 0, 0)), "Q (Warrior, centred on me): the pick changes nothing", show({ f.C, f.W }))
	local w8, p8 = H.World({ Class = "Mage" })
	local near8 = H.Mob(w8, 0, 10)
	local pick8 = H.Mob(w8, 0, 30)
	H.Release(w8, p8, pick8.Model, 1)
	local info8 = H.Last(w8)
	check(info8 ~= nil and H.Near(info8.Center, near8.Root.Position), "Release(pick, extra): Q goes as with no pick", info8 and show(info8.Center))
	-- review B: with no pick, Q's own A23-61 turn (a lone slime behind) still writes the root
	local g = H.Run({ Class = "Mage", Q = true, Pick = { 180, 10 } }, false)
	check(g.W and H.Near(g.C, H.Pos(180, 10)), "Q with no pick: the A23-61 turn still writes the root", show({ g.C, g.W }))
end)

runGroup("skill Q: the queued press and no SkillService", function()
	-- a press inside the shared 0.5 s gap is queued and fires with its pick (Q's own cooldown set short for this check)
	local w, p = H.World({ Class = "Mage" })
	w.Config.BasicSkill.Cooldown = 0.25
	local near = H.Mob(w, 0, 10)
	local pick = H.Mob(w, 0, 30)
	w:Advance(3.5)
	check(w.Skills.Cast(p, "Q", false) == true, "setup: a first Q goes off", #w.Rel)
	w:Advance(0.3)
	local n = #w.Rel
	w.Net.Get("Release").OnServerEvent:Fire(p, pick.Model)
	w:Flush()
	check(#w.Rel == n, "setup: the press inside the gap is queued", #w.Rel - n)
	w:Advance(0.3)
	local info = H.Last(w)
	check(#w.Rel == n + 1 and H.Near(info.Center, pick.Root.Position) and w:Dealt(near) > 0,
		"the queued Q goes off on its pick", info and show({ #w.Rel - n, info.Center }))
	local w2, p2 = H.World({ Class = "Mage" })
	w2.Registry.SkillService = nil
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 0, 30)
	H.Release(w2, p2, pick2.Model)
	local info2 = H.Last(w2)
	check(info2 ~= nil and H.Near(info2.Center, pick2.Root.Position) and w2:Dealt(near2) == 0,
		"Release without SkillService: the pick is the centre", info2 and show(info2.Center))
end)

------------------------------------------------------------------ the differential property (lead 2026-10-10)
-- DIFF.N seeded random scenes (every class + bare hands, swing and Q, 0-2 enemies, maybe the goose, 0-4 monsters, a
-- valid / invalid pick at a random angle and distance): with the pick and without it (fresh worlds) the enemies' HP and
-- the goose tugs are the same; with no enemy and no goose a valid pick is hit (Warrior Q, centred on me, excepted)
local DIFF = { N = 800, Seed = 20261010 }
function DIFF.Rnd()
	DIFF.Seed = (DIFF.Seed * 1103515245 + 12345) % 2147483648
	return DIFF.Seed / 2147483648
end
function DIFF.Scene()
	local R = DIFF.Rnd
	local kinds = { "Warrior", "Mage", "Archer", "Bare" }
	local kind = kinds[1 + math.floor(R() * 4)]
	local s = { Class = kind ~= "Bare" and kind or nil, Bare = kind == "Bare" }
	s.Q = kind ~= "Bare" and R() < 0.4
	local cfg = C0.Classes[s.Class or "Warrior"]
	local range = s.Q and cfg.Range or (s.Bare and C0.Combat.Unarmed.Range or cfg.Range)
	s.Range = range
	local pve = R() < 0.3 -- a third of the scenes: no enemy, no goose (the pick must be hit)
	s.Mobs = {}
	for i = 1, math.floor(R() * 5) do -- a quarter of them near the edge of Range (boundary bias)
		s.Mobs[i] = { R() * 360, R() < 0.25 and range - 4 + R() * 4 or 0.5 + R() * (range + 6) }
	end
	local hk = ({ "valid", "valid", "valid", "valid", "far", "dead", "hidden", "enemyChar", "string", "none" })[1 + math.floor(R() * 10)]
	-- an enemy / the goose: anywhere out to Range + 12, or (half of them) within 10 studs of me (twice as likely), a
	-- monster or the pick - the blasts at today's centre and at the pick
	local pickAt = (hk == "valid" or hk == "far" or hk == "dead" or hk == "hidden") and { R() * 360, 0 } or nil
	local function spot()
		local anchors = { { 0, 0 }, { 0, 0 } }
		for _, m in s.Mobs do table.insert(anchors, m) end
		if pickAt then table.insert(anchors, pickAt) end
		if R() < 0.5 then return { R() * 360, 0.5 + R() * (range + 12) } end
		local a = anchors[1 + math.floor(R() * #anchors)]
		local ax, az = H.At(a[1], a[2])
		local ox, oz = H.At(R() * 360, R() * 10)
		local x, z = ax + ox, az + oz
		return { math.deg(math.atan2(x, z)), math.max(0.5, math.sqrt(x * x + z * z)) }
	end
	if pickAt then -- the pick's distance first (spot() may anchor on it)
		if hk == "valid" then -- up to Range + 1.9 (the slack is 2); a quarter of them at the edge / in the slack zone
			pickAt[2] = R() < 0.25 and range - 0.5 + R() * 2.4 or 0.5 + R() * (range + 1.4)
		elseif hk == "far" then
			pickAt[2] = range + 2.5 + R() * 8
		else
			pickAt[2] = 0.5 + R() * range
		end
	end
	if not pve and R() < 0.4 then s.Goose = spot() end
	s.Enemies = {}
	for i = 1, pve and 0 or math.floor(R() * 3) do s.Enemies[i] = spot() end
	s.Kind = hk
	s.Pick = pickAt
	if hk == "dead" or hk == "hidden" then
		s.Bad = hk == "dead" and function(r) r.Alive = false end or function(r) r._hidden = true end
	elseif hk == "enemyChar" then
		s.Hint = function(_, _, enemies) return enemies[1] and enemies[1].Character or nil end
	elseif hk == "string" then
		s.Hint = function() return "Slime" end
	elseif hk == "none" then
		s.Hint = function() return nil end -- no pick monster either: nil is sent
	end
	return s -- "valid" / "far" / "dead" / "hidden": the pick monster's Model is sent
end

runGroup("differential: a pick never changes who else is hit", function()
	local counts = { Pvp = 0, PvpHit = 0, Pve = 0 }
	for i = 1, DIFF.N do
		local s = DIFF.Scene()
		local a = H.Run(s, true)
		local b = H.Run(s, false)
		local label = string.format("#%d %s%s pick=%s goose=%s enemies=%d", i, s.Bare and "Bare" or s.Class or "Warrior",
			s.Q and " Q" or "", s.Kind, tostring(s.Goose ~= nil), #s.Enemies)
		check(H.Same(a, b) and a.Warn == 0 and b.Warn == 0, "enemy HP and goose tugs: with the pick = without it",
			label .. " " .. show({ With = { a.E, a.T }, Without = { b.E, b.T } }))
		if #s.Enemies > 0 or s.Goose then
			counts.Pvp += 1
			local hitSomeone = b.T > 0
			for _, hp in b.E do if hp < 100 then hitSomeone = true end end
			if hitSomeone then counts.PvpHit += 1 end
		elseif s.Kind == "valid" and not (s.Q and (s.Class or "Warrior") == "Warrior") then
			counts.Pve += 1
			check(a.P > 0, "no enemy, no goose: a valid pick is hit", label .. " " .. show({ a.P, s.Pick }))
		end
	end
	finding(string.format("differential: %d scenes, %d with an enemy / the goose (%d of them hit someone without the pick), %d pure-PvE valid picks",
		DIFF.N, counts.Pvp, counts.PvpHit, counts.Pve))
	check(counts.PvpHit >= 30 and counts.Pve >= 30, "the random scenes cover both properties (>= 30 each)", show(counts))
end)

finish()
