-- swing_hint_offline.luau : A23-91 server target hint (dev2 2026-10-10). The client sends its pick (HUD.PickTarget: the
-- monster Model) as argument 1 of Swing and Release; CombatService now takes it for MANUAL attacks when it is the Model
-- of a monster the attack's own filter (monstersNear: alive, mine or nobody's, the zone level gate) finds within Range +
-- HINT.Slack (2) and not a hidden ambusher. Valid: the root turns to it unless it is within HINT.KeepDeg (10) of the
-- facing (a turned attack hits monsters only), Splash centres on it, Multi hits it first, Around hits it even at Range +
-- Slack (nobody else gets the slack), the skill Q (a Target-centred class) centres on it. Anything else: exactly the
-- swing of today (A23-61). tools/test_swing_hint.py binds the CURRENT sources of tools/test_unarmed_start.py plus
-- DamageWindow / SkillService (dev2_kit.luau and dev2_combat_world.luau come first). Players face -Z at the origin;
-- H.At(deg, dist): 0 deg = straight ahead, 180 = right behind.

local H = {}

-- true when the server turned the root since the last look (the combat world's CFrame.lookAt double marks Turned)
function H.Settle(p)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local cf = root and root.CFrame
	if type(cf) == "table" and cf.Turned then
		cf.Turned = nil
		return true
	end
	return false
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

-- a world; o.Mage / o.Archer / o.Bare pick the attacker, o.Auto = auto combat ON, o.Goose = the goose at that position
function H.World(o)
	o = o or {}
	local w = bareWorld({ Hit = true })
	w.Tugs = {}
	if o.Goose then
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
	return w, p
end

function H.Enemy(w, id, deg, dist)
	local v = w:Join(id, { Class = "Warrior", Faction = "Horns", Level = 5, Tier = 1, Mask = 1, Pos = H.Pos(deg, dist) })
	return v
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

-- one manual swing through the Swing remote (past every swing interval / the rate limit); returns "turned"
function H.Swing(w, p, ...)
	w:Advance(1.2)
	w.Net.Get("Swing").OnServerEvent:Fire(p, ...)
	w:Flush()
	return H.Settle(p)
end

-- one skill Q press through the old Release remote (past the Q cooldown); returns "turned"
function H.Release(w, p, ...)
	w:Advance(3.5)
	w.Net.Get("Release").OnServerEvent:Fire(p, ...)
	w:Flush()
	return H.Settle(p)
end

function H.Look(p)
	return p.Character:FindFirstChild("HumanoidRootPart").CFrame.LookVector
end

function H.Near(a, b)
	return a ~= nil and b ~= nil and math.abs(a.X - b.X) < 0.01 and math.abs(a.Z - b.Z) < 0.01
end

-- the Warrior scene every "ignored hint" case uses: a slime in front (30 deg, 4 studs: today's target) and the bad
-- candidate behind (160 deg, 8 studs). `bad(w, p, behind)` turns the behind one into the bad case and returns the hint
-- to send; the outcome: { front dealt, behind dealt, turned, the facing's Z, warnings }
function H.Scene(bad)
	local w, p = H.World()
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	local hint = bad and bad(w, p, behind) or nil
	local t = H.Swing(w, p, hint)
	return show({ Front = w:Dealt(front), Behind = w:Dealt(behind), Turned = t, LookZ = math.floor(H.Look(p).Z * 100 + 0.5),
		Warn = #w.Warnings })
end

------------------------------------------------------------------ the pick wins
runGroup("warrior: the pick wins", function()
	-- today: a slime in front is hit, the one behind is not; with the behind one as my pick: it is hit, the root turns,
	-- and the front one (now 130 deg off the new facing) is not
	local w, p = H.World()
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	local t = H.Swing(w, p, behind.Model)
	check(w:Dealt(behind) > 0 and w:Dealt(front) == 0 and t, "a pick behind me: it is hit, the root turns, the nearer front slime is not",
		show({ w:Dealt(behind), w:Dealt(front), t }))
	local look = H.Look(p)
	local want = H.Pos(160, 1)
	check(math.abs(look.X - want.X) < 0.01 and math.abs(look.Z - want.Z) < 0.01, "the root now faces the pick", show({ look.X, look.Z }))
	local w0, p0 = H.World()
	local front0 = H.Mob(w0, 30, 4)
	local behind0 = H.Mob(w0, 160, 8)
	local t0 = H.Swing(w0, p0)
	check(w0:Dealt(front0) > 0 and w0:Dealt(behind0) == 0 and not t0, "control: no pick = today's rule (the front slime, no turn)",
		show({ w0:Dealt(front0), w0:Dealt(behind0), t0 }))
	-- within KeepDeg (5 deg): no turn, the swing is today's front half (an enemy in front is still hit)
	local w2, p2 = H.World()
	local pick = H.Mob(w2, 5, 6)
	local other = H.Mob(w2, 40, 6)
	local v = H.Enemy(w2, 2, -40, 5)
	local t2 = H.Swing(w2, p2, pick.Model)
	check(not t2 and w2:Dealt(pick) > 0 and w2:Dealt(other) > 0 and H.Hp(v) < 100,
		"a pick 5 deg off my facing: no turn; the front half is hit as today (two slimes and an enemy)",
		show({ t2, w2:Dealt(pick), w2:Dealt(other), H.Hp(v) }))
	check(H.Hits(w2, pick) == 1 and H.Hits(w2, other) == 1, "the pick is hit once (no second copy), the other slime once",
		show({ H.Hits(w2, pick), H.Hits(w2, other) }))
	-- 45 deg: inside the front half but past KeepDeg -> the root turns, and a turned swing hits monsters only
	local w3, p3 = H.World()
	local pick3 = H.Mob(w3, 45, 6)
	local v3 = H.Enemy(w3, 2, 20, 5)
	local t3 = H.Swing(w3, p3, pick3.Model)
	check(t3 and w3:Dealt(pick3) > 0 and H.Hp(v3) == 100, "a pick at 45 deg: the root turns to it, the enemy beside it is not hit (monsters only)",
		show({ t3, w3:Dealt(pick3), H.Hp(v3) }))
end)

runGroup("the slack is the pick's only", function()
	local range = nil
	-- range + 1 behind: accepted (turned, hit); range + 3: ignored (nothing in Range: no hit, no turn)
	local w, p = H.World()
	range = w.Range
	local near = H.Mob(w, 180, range + 1)
	local t = H.Swing(w, p, near.Model)
	check(w:Dealt(near) > 0 and t, "a pick at Range + 1 (behind): accepted, the root turns, it is hit", show({ w:Dealt(near), t }))
	local w2, p2 = H.World()
	local far = H.Mob(w2, 180, range + 3)
	local t2 = H.Swing(w2, p2, far.Model)
	check(w2:Dealt(far) == 0 and not t2, "a pick at Range + 3: ignored (no hit, no turn)", show({ w2:Dealt(far), t2 }))
	-- Around with a pick at Range + 1 ahead: the pick is hit, another slime at Range + 1 is not, one inside Range is
	local w3, p3 = H.World()
	local pick = H.Mob(w3, 0, range + 1)
	local edge = H.Mob(w3, 20, range + 1)
	local inside = H.Mob(w3, 20, range - 2)
	local t3 = H.Swing(w3, p3, pick.Model)
	check(not t3 and w3:Dealt(pick) > 0 and w3:Dealt(edge) == 0 and w3:Dealt(inside) > 0,
		"Around: the pick at Range + 1 is hit, another slime at Range + 1 is not, one inside Range is",
		show({ t3, w3:Dealt(pick), w3:Dealt(edge), w3:Dealt(inside) }))
	-- turned to a pick at Range + 1 behind: a slime beside it also at Range + 1 is not hit
	local w4, p4 = H.World()
	local pick4 = H.Mob(w4, 180, range + 1)
	local edge4 = H.Mob(w4, 170, range + 1)
	local t4 = H.Swing(w4, p4, pick4.Model)
	check(t4 and w4:Dealt(pick4) > 0 and w4:Dealt(edge4) == 0, "turned: only the pick gets the slack (its neighbour at Range + 1 is not hit)",
		show({ t4, w4:Dealt(pick4), w4:Dealt(edge4) }))
	-- Multi (Archer) at Range + 1: the arrow goes to the pick
	local w5, p5 = H.World({ Class = "Archer" })
	local pick5 = H.Mob(w5, 0, w5.Range + 1)
	local t5 = H.Swing(w5, p5, pick5.Model)
	check(w5:Dealt(pick5) > 0 and not t5, "Archer: a pick at Range + 1 straight ahead is shot", show({ w5:Dealt(pick5), t5 }))
end)

------------------------------------------------------------------ ignored hints: exactly today's swing
runGroup("bad hints are ignored", function()
	local base = H.Scene(nil)
	check(string.find(base, "Behind=0,", 1, true) ~= nil and string.find(base, "Front=0,", 1, true) == nil,
		"setup: with no pick the scene hits the front slime only", base)
	local accepted = H.Scene(function(_, _, behind) return behind.Model end)
	check(accepted ~= base, "setup: a valid pick changes the scene's outcome", show({ base, accepted }))
	local cases = {
		{ "a hidden ambusher (MonsterService _hidden)", function(_, _, b) b._hidden = true return b.Model end },
		{ "a monster model marked Hidden", function(_, _, b) b.Model:SetAttribute("Hidden", true) return b.Model end },
		{ "another player's personal monster", function(w, _, b)
			b.Owner = H.Enemy(w, 7, 90, 30)
			return b.Model
		end },
		{ "a dead monster", function(_, _, b) b.Alive = false return b.Model end },
		{ "a player's character (an enemy behind me)", function(w) return H.Enemy(w, 8, 160, 6).Character end },
		{ "a part (the monster's root)", function(_, _, b) return b.Root end },
		{ "a model that is no monster", function(w) return newInstance("Model", w) end },
		{ "a string", function() return "Slime" end },
		{ "a number", function() return 3 end },
		{ "a table", function(_, _, b) return { Model = b.Model } end },
		{ "true", function() return true end },
	}
	-- the zone level gate: a monster of a zone above my level
	local w0 = H.World()
	local gated = nil
	for id, z in w0.Config.Zones do
		if type(z) == "table" and (tonumber(z.MinLevel) or 1) > 5 then gated = id break end
	end
	if gated then
		table.insert(cases, { "a monster of a zone above my level (" .. gated .. ")", function(_, _, b)
			b.ZoneId = gated
			return b.Model
		end })
	else
		finding("no zone above Lv5 in Config.Zones: the zone-gate hint case was skipped")
	end
	for _, case in cases do
		local got = H.Scene(case[2])
		-- the enemy players some cases add stand far from the swing (or behind it): the outcome still equals no hint
		check(got == base, case[1] .. ": ignored (the same swing as with no pick)", show({ got, base }))
	end
	-- an ignored pick still lets today's A23-61 rule turn to the nearest monster behind
	local w, p = H.World()
	local behind = H.Mob(w, 170, 5)
	behind._hidden = true
	local t = H.Swing(w, p, behind.Model)
	check(t and w:Dealt(behind) > 0, "an ignored pick: the A23-61 rule still turns to the nearest monster behind", show({ t, w:Dealt(behind) }))
	-- more arguments than the pick: the press still swings, without the pick
	local w2, p2 = H.World()
	local front2 = H.Mob(w2, 30, 4)
	local behind2 = H.Mob(w2, 160, 8)
	local t2 = H.Swing(w2, p2, behind2.Model, "extra")
	check(w2:Dealt(front2) > 0 and w2:Dealt(behind2) == 0 and not t2, "Swing(pick, extra): the swing goes as with no pick",
		show({ w2:Dealt(front2), w2:Dealt(behind2), t2 }))
end)

------------------------------------------------------------------ patterns
runGroup("mage splash", function()
	-- turned: the orb goes to the pick behind me; the slime 3 studs past it is in the blast, the nearer front one is not,
	-- the enemy beside the pick is not hit (turned: monsters only)
	local w, p = H.World({ Class = "Mage" })
	local front = H.Mob(w, 0, 10)
	local pick = H.Mob(w, 150, 20)
	local past = H.Mob(w, 150, 23)
	local v = H.Enemy(w, 2, 150, 18)
	local t = H.Swing(w, p, pick.Model)
	check(t and w:Dealt(pick) > 0 and w:Dealt(past) > 0 and w:Dealt(front) == 0 and H.Hp(v) == 100,
		"Splash (turned): centre = the pick, its neighbour hit, the front slime and the enemy not",
		show({ t, w:Dealt(pick), w:Dealt(past), w:Dealt(front), H.Hp(v) }))
	local fx = w:FxOf("Swing")
	check(#fx > 0 and H.Near(fx[#fx].Data.Pos, pick.Root.Position), "the orb Fx lands on the pick", fx[#fx] and show(fx[#fx].Data.Pos))
	-- not turned (straight ahead, farther than a front slime): centre = the pick; the enemy beside it is hit (manual, not
	-- turned: as today)
	local w2, p2 = H.World({ Class = "Mage" })
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 0, 25)
	local v2 = H.Enemy(w2, 2, 3, 26)
	local t2 = H.Swing(w2, p2, pick2.Model)
	check(not t2 and w2:Dealt(pick2) > 0 and w2:Dealt(near2) == 0 and H.Hp(v2) < 100,
		"Splash (no turn): centre = the pick (not the nearer slime), the enemy beside it is hit as today",
		show({ t2, w2:Dealt(pick2), w2:Dealt(near2), H.Hp(v2) }))
end)

runGroup("archer multi and bare hands", function()
	-- the pick first, then the nearest (Targets 2): pick + the 10-stud slime, not the 15-stud one
	local w, p = H.World({ Class = "Archer" })
	local m1 = H.Mob(w, 30, 10)
	local m2 = H.Mob(w, -30, 15)
	local pick = H.Mob(w, 0, 25)
	local t = H.Swing(w, p, pick.Model)
	check(not t and w:Dealt(pick) > 0 and w:Dealt(m1) > 0 and w:Dealt(m2) == 0, "Multi: the pick first, then the nearest (Targets 2)",
		show({ t, w:Dealt(pick), w:Dealt(m1), w:Dealt(m2) }))
	-- the pick is also the nearest: hit once, the next one is the second arrow
	local w2, p2 = H.World({ Class = "Archer" })
	local pick2 = H.Mob(w2, 0, 8)
	local m3 = H.Mob(w2, 30, 10)
	H.Swing(w2, p2, pick2.Model)
	check(H.Hits(w2, pick2) == 1 and H.Hits(w2, m3) == 1, "Multi: the pick is never shot twice (the second arrow goes to the next)",
		show({ H.Hits(w2, pick2), H.Hits(w2, m3) }))
	-- turned Multi: no player, no goose
	local w3, p3 = H.World({ Class = "Archer", Goose = vec(0, 0, 12) })
	local pick3 = H.Mob(w3, 180, 15)
	local v3 = H.Enemy(w3, 2, 175, 10)
	local t3 = H.Swing(w3, p3, pick3.Model)
	check(t3 and w3:Dealt(pick3) > 0 and H.Hp(v3) == 100 and #w3.Tugs == 0, "Multi turned to a pick behind: the pick, no player, no goose tug",
		show({ t3, w3:Dealt(pick3), H.Hp(v3), #w3.Tugs }))
	-- bare hands (one punch, Range 7): the pick behind-right, not the nearer slime in front
	local w4, p4 = H.World({ Bare = true })
	local front4 = H.Mob(w4, 20, 3)
	local pick4 = H.Mob(w4, 170, 5)
	local t4 = H.Swing(w4, p4, pick4.Model)
	check(t4 and w4:Dealt(pick4) > 0 and w4:Dealt(front4) == 0, "bare hands: the punch turns to the pick, the nearer front slime is not hit",
		show({ t4, w4:Dealt(pick4), w4:Dealt(front4) }))
end)

runGroup("turned swings: monsters only", function()
	-- Around turned to a pick behind me: an enemy and the goose in the new front half are not hit / counted
	local w, p = H.World({ Goose = vec(0, 0, 4) })
	local pick = H.Mob(w, 180, 5)
	local v = H.Enemy(w, 2, 170, 4)
	local t = H.Swing(w, p, pick.Model)
	check(t and w:Dealt(pick) > 0 and H.Hp(v) == 100 and #w.Tugs == 0, "Around turned: the pick is hit, the enemy and the goose beside it are not",
		show({ t, w:Dealt(pick), H.Hp(v), #w.Tugs }))
	-- not turned: the goose in front counts as today
	local w2, p2 = H.World({ Goose = vec(0, 0, -4) })
	local pick2 = H.Mob(w2, 0, 5)
	local t2 = H.Swing(w2, p2, pick2.Model)
	check(not t2 and w2:Dealt(pick2) > 0 and #w2.Tugs == 1, "not turned: the goose in front is tugged as today", show({ t2, w2:Dealt(pick2), #w2.Tugs }))
end)

------------------------------------------------------------------ auto, the queue
runGroup("auto never takes a pick", function()
	local w, p = H.World({ Auto = true })
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	w:Advance(1.2)
	w.Combat.Swing(p, false, behind.Model)
	w:Flush()
	local t = H.Settle(p)
	check(w:Dealt(front) > 0 and w:Dealt(behind) == 0 and not t, "an auto swing with a pick: the pick is ignored (today's rule)",
		show({ w:Dealt(front), w:Dealt(behind), t }))
	-- auto skill Q (Mage, Target): the centre stays the nearest aimed slime
	local w2, p2 = H.World({ Class = "Mage", Auto = true })
	local near = H.Mob(w2, 0, 10)
	local pick = H.Mob(w2, 0, 30)
	w2:Advance(3.5)
	w2.Combat.Release(p2, true, pick.Model)
	w2:Flush()
	local info = w2.Rel[#w2.Rel] and w2.Rel[#w2.Rel].Info
	check(info ~= nil and info.Auto == true and H.Near(info.Center, near.Root.Position) and w2:Dealt(pick) == 0,
		"an auto Q with a pick: the pick is ignored (centre = the nearest aimed slime)", info and show({ info.Center, w2:Dealt(pick) }))
	-- the auto-combat loop itself sends none (it swings at the front slime; no MP, so no auto Q blast around me)
	local w3, p3 = H.World({ Auto = true, Mana = 0 })
	local front3 = H.Mob(w3, 30, 4)
	local behind3 = H.Mob(w3, 160, 8)
	w3:Advance(1.2)
	w3:AutoTick()
	check(w3:Dealt(front3) > 0 and w3:Dealt(behind3) == 0 and not H.Settle(p3), "the auto loop: today's rule", show({ w3:Dealt(front3), w3:Dealt(behind3) }))
end)

runGroup("the queued swing keeps its pick", function()
	local w, p = H.World()
	H.Swing(w, p) -- a whiff: the swing cooldown starts
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	local interval = w.Config.Classes.Warrior.SwingInterval
	w:Advance(interval - 0.1) -- inside MANUAL_GRACE: the press is queued
	w.Net.Get("Swing").OnServerEvent:Fire(p, behind.Model)
	w:Flush()
	check(w:Dealt(front) == 0 and w:Dealt(behind) == 0, "setup: the early press is queued (nothing yet)", show({ w:Dealt(front), w:Dealt(behind) }))
	w:Advance(0.2)
	local t = H.Settle(p)
	check(w:Dealt(behind) > 0 and w:Dealt(front) == 0 and t, "the queued swing goes to its pick (turned)", show({ w:Dealt(behind), w:Dealt(front), t }))
end)

------------------------------------------------------------------ the skill Q
runGroup("skill Q takes the pick", function()
	-- Mage (Target centre), through the old Release remote and SkillService: the blast on the pick, not the nearer slime;
	-- the enemy beside the pick is hit (not turned, manual: as today)
	local w, p = H.World({ Class = "Mage" })
	local near = H.Mob(w, 0, 10)
	local pick = H.Mob(w, 0, 30)
	local v = H.Enemy(w, 2, 2, 31)
	local t = H.Release(w, p, pick.Model)
	local info = w.Rel[#w.Rel] and w.Rel[#w.Rel].Info
	check(info ~= nil and not t and H.Near(info.Center, pick.Root.Position) and w:Dealt(pick) > 0 and w:Dealt(near) == 0 and H.Hp(v) < 100,
		"Q (Mage) through SkillService: centre = the pick, the nearer slime is not hit, the enemy beside it is",
		info and show({ info.Center, t, w:Dealt(pick), w:Dealt(near), H.Hp(v) }))
	local w0, p0 = H.World({ Class = "Mage" })
	local near0 = H.Mob(w0, 0, 10)
	local pick0 = H.Mob(w0, 0, 30)
	H.Release(w0, p0)
	local info0 = w0.Rel[#w0.Rel] and w0.Rel[#w0.Rel].Info
	check(info0 ~= nil and H.Near(info0.Center, near0.Root.Position) and w0:Dealt(pick0) == 0, "control: Q with no pick = the nearest aimed slime",
		info0 and show(info0.Center))
	-- turned: the pick behind me; the enemy beside it is not hit
	local w2, p2 = H.World({ Class = "Mage" })
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 160, 20)
	local v2 = H.Enemy(w2, 2, 160, 22)
	local t2 = H.Release(w2, p2, pick2.Model)
	local info2 = w2.Rel[#w2.Rel] and w2.Rel[#w2.Rel].Info
	check(info2 ~= nil and t2 and H.Near(info2.Center, pick2.Root.Position) and w2:Dealt(near2) == 0 and H.Hp(v2) == 100,
		"Q turned to a pick behind: the blast there, the root turns, the enemy beside it is not hit",
		info2 and show({ info2.Center, t2, w2:Dealt(near2), H.Hp(v2) }))
	-- Archer (Target centre) at Range + 1
	local w3, p3 = H.World({ Class = "Archer" })
	local pick3 = H.Mob(w3, 0, w3.Range + 1)
	H.Release(w3, p3, pick3.Model)
	local info3 = w3.Rel[#w3.Rel] and w3.Rel[#w3.Rel].Info
	check(info3 ~= nil and H.Near(info3.Center, pick3.Root.Position), "Q (Archer): a pick at Range + 1 is the centre", info3 and show(info3.Center))
	-- a bad pick (hidden): Q as with none
	local w4, p4 = H.World({ Class = "Mage" })
	local near4 = H.Mob(w4, 0, 10)
	local pick4 = H.Mob(w4, 0, 30)
	pick4._hidden = true
	H.Release(w4, p4, pick4.Model)
	local info4 = w4.Rel[#w4.Rel] and w4.Rel[#w4.Rel].Info
	check(info4 ~= nil and H.Near(info4.Center, near4.Root.Position), "Q with a hidden pick: ignored (the nearest aimed slime)", info4 and show(info4.Center))
	-- Warrior (the blast is centred on me): the pick changes nothing, no turn
	local w5, p5 = H.World()
	H.Mob(w5, 30, 4)
	local pick5 = H.Mob(w5, 160, 6)
	local t5 = H.Release(w5, p5, pick5.Model)
	local info5 = w5.Rel[#w5.Rel] and w5.Rel[#w5.Rel].Info
	check(info5 ~= nil and not t5 and H.Near(info5.Center, vec(0, 0, 0)), "Q (Warrior, centred on me): the pick changes nothing, no turn",
		info5 and show({ info5.Center, t5 }))
	-- more arguments than the pick: Q still goes, without the pick
	local w6, p6 = H.World({ Class = "Mage" })
	local near6 = H.Mob(w6, 0, 10)
	local pick6 = H.Mob(w6, 0, 30)
	H.Release(w6, p6, pick6.Model, 1)
	local info6 = w6.Rel[#w6.Rel] and w6.Rel[#w6.Rel].Info
	check(info6 ~= nil and H.Near(info6.Center, near6.Root.Position), "Release(pick, extra): Q goes as with no pick", info6 and show(info6.Center))
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
	local info = w.Rel[#w.Rel] and w.Rel[#w.Rel].Info
	check(#w.Rel == n + 1 and H.Near(info.Center, pick.Root.Position) and w:Dealt(near) > 0,
		"the queued Q goes off on its pick", info and show({ #w.Rel - n, info.Center }))
	-- the Release remote without SkillService (CombatService's own fallback) passes the pick too
	local w2, p2 = H.World({ Class = "Mage" })
	w2.Registry.SkillService = nil
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 0, 30)
	H.Release(w2, p2, pick2.Model)
	local info2 = w2.Rel[#w2.Rel] and w2.Rel[#w2.Rel].Info
	check(info2 ~= nil and H.Near(info2.Center, pick2.Root.Position) and w2:Dealt(near2) == 0,
		"Release without SkillService: the pick is the centre", info2 and show(info2.Center))
end)

finish()
