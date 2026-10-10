-- swing_hint_offline.luau : A23-91 server target hint (dev2 2026-10-10). The client sends its pick (HUD.PickTarget: the
-- monster Model) as argument 1 of Swing and Release; CombatService now takes it for MANUAL attacks when it is the Model
-- of a monster the attack's own filter (monstersNear: alive, mine or nobody's, the zone level gate) finds within Range +
-- HINT.Slack (2) and not a hidden ambusher. Valid: the attack aims at it unless it is within HINT.KeepDeg (10) of the
-- facing - through a facing for the hit math only, the real root is NEVER written (review 2026-10-10 B: a server write
-- from the stale position snaps a walking player back); it hits monsters only only when the pick is outside the
-- attack's own AimCone of the real facing (review A: inside it players and the goose keep today's real front half).
-- Splash centres on it, Multi hits it first, Around hits it even at Range + Slack (nobody else gets the slack), the skill
-- Q (a Target-centred class) centres on it. Anything else: exactly the swing of today (A23-61, whose own turn still
-- writes the root). tools/test_swing_hint.py binds the CURRENT sources of tools/test_unarmed_start.py plus DamageWindow
-- / SkillService (dev2_kit.luau and dev2_combat_world.luau come first). Players face -Z at the origin; H.At(deg, dist):
-- 0 deg = straight ahead, 90 = right, 180 = right behind.

local H = {}

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

-- the Warrior scene every "ignored hint" case uses: a slime in front (30 deg, 4 studs: today's target) and the bad
-- candidate behind (160 deg, 8 studs). `bad(w, p, behind)` turns the behind one into the bad case and returns the hint
-- to send; the outcome: { front dealt, behind dealt, root written, the facing's Z, warnings }
function H.Scene(bad)
	local w, p = H.World()
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	local hint = bad and bad(w, p, behind) or nil
	local wrote = H.Swing(w, p, hint)
	return show({ Front = w:Dealt(front), Behind = w:Dealt(behind), Wrote = wrote,
		LookZ = math.floor(H.Cf(p).LookVector.Z * 100 + 0.5), Warn = #w.Warnings })
end

------------------------------------------------------------------ the pick wins
runGroup("warrior: the pick wins", function()
	-- today: a slime in front is hit, the one behind is not; with the behind one as my pick: it is hit, the front one
	-- (130 deg off the pick) is not; the real root is never written
	local w, p = H.World()
	local front = H.Mob(w, 30, 4)
	local behind = H.Mob(w, 160, 8)
	local wrote = H.Swing(w, p, behind.Model)
	check(w:Dealt(behind) > 0 and w:Dealt(front) == 0, "a pick behind me: it is hit, the nearer front slime is not",
		show({ w:Dealt(behind), w:Dealt(front) }))
	check(not wrote and H.Cf(p).LookVector.Z < -0.99, "review B: the real root is not written (it still faces -Z)",
		show({ wrote, H.Cf(p).LookVector.Z }))
	local w0, p0 = H.World()
	local front0 = H.Mob(w0, 30, 4)
	local behind0 = H.Mob(w0, 160, 8)
	H.Swing(w0, p0)
	check(w0:Dealt(front0) > 0 and w0:Dealt(behind0) == 0, "control: no pick = today's rule (the front slime)",
		show({ w0:Dealt(front0), w0:Dealt(behind0) }))
	-- within KeepDeg (5 deg): the aim stays my facing - a slime at -87 deg (inside my front half, 92 deg off the pick)
	-- is still hit, and so is an enemy at -40
	local w2, p2 = H.World()
	local pick = H.Mob(w2, 5, 6)
	local other = H.Mob(w2, 40, 6)
	local edge = H.Mob(w2, -87, 6)
	local v = H.Enemy(w2, 2, -40, 5)
	local wrote2 = H.Swing(w2, p2, pick.Model)
	check(w2:Dealt(pick) > 0 and w2:Dealt(other) > 0 and w2:Dealt(edge) > 0 and H.Hp(v) < 100 and not wrote2,
		"a pick 5 deg off my facing: the aim stays (the -87 deg slime is hit), the enemy is hit, no root write",
		show({ w2:Dealt(pick), w2:Dealt(other), w2:Dealt(edge), H.Hp(v), wrote2 }))
	check(H.Hits(w2, pick) == 1 and H.Hits(w2, other) == 1, "the pick is hit once (no second copy), the other slime once",
		show({ H.Hits(w2, pick), H.Hits(w2, other) }))
	-- KeepDeg bracket (20 deg): the aim follows the pick - a slime at -80 deg (100 deg off the pick) is not hit, one at
	-- 105 deg (behind my facing, 85 deg off the pick) is
	local w3, p3 = H.World()
	local pick3 = H.Mob(w3, 20, 6)
	local left = H.Mob(w3, -80, 6)
	local right = H.Mob(w3, 105, 6)
	local wrote3 = H.Swing(w3, p3, pick3.Model)
	check(w3:Dealt(pick3) > 0 and w3:Dealt(left) == 0 and w3:Dealt(right) > 0 and not wrote3,
		"a pick 20 deg off: the monster sweep is the pick's front half (-80 deg out, 105 deg in), no root write",
		show({ w3:Dealt(pick3), w3:Dealt(left), w3:Dealt(right), wrote3 }))
end)

runGroup("review A: inside the attack's cone players stay", function()
	-- Warrior: an enemy 4 studs straight ahead and a slime at 30 deg as the pick: both are hit
	local w, p = H.World()
	local v = H.Enemy(w, 2, 0, 4)
	local pick = H.Mob(w, 30, 5)
	H.Swing(w, p, pick.Model)
	check(H.Hp(v) < 100 and w:Dealt(pick) > 0, "Warrior: a pick at 30 deg, an enemy straight ahead: both are hit", show({ H.Hp(v), w:Dealt(pick) }))
	-- players are judged in my real front half, not the pick's: a pick at 80 deg, an enemy at -60 deg (in my half, 140 deg
	-- off the pick) is hit
	local w2, p2 = H.World()
	local v2 = H.Enemy(w2, 2, -60, 5)
	local pick2 = H.Mob(w2, 80, 6)
	H.Swing(w2, p2, pick2.Model)
	check(H.Hp(v2) < 100 and w2:Dealt(pick2) > 0, "Warrior: a pick at 80 deg, an enemy at -60 deg (my front half): hit",
		show({ H.Hp(v2), w2:Dealt(pick2) }))
	-- outside the cone (120 deg): monsters only - the enemy straight ahead is not hit
	local w3, p3 = H.World()
	local v3 = H.Enemy(w3, 2, 0, 4)
	local pick3 = H.Mob(w3, 120, 5)
	local wrote3 = H.Swing(w3, p3, pick3.Model)
	check(H.Hp(v3) == 100 and w3:Dealt(pick3) > 0 and not wrote3, "a pick at 120 deg (outside the cone): monsters only, no root write",
		show({ H.Hp(v3), w3:Dealt(pick3), wrote3 }))
	-- the goose: counted with a pick inside the cone, not with one outside it
	local w4, p4 = H.World({ Goose = vec(0, 0, -4) })
	local pick4 = H.Mob(w4, 45, 5)
	H.Swing(w4, p4, pick4.Model)
	check(#w4.Tugs == 1 and w4:Dealt(pick4) > 0, "a pick at 45 deg and the goose in front: the goose is tugged as today", show({ #w4.Tugs, w4:Dealt(pick4) }))
	local w5, p5 = H.World({ Goose = vec(0, 0, -4) })
	local pick5 = H.Mob(w5, 150, 5)
	H.Swing(w5, p5, pick5.Model)
	check(#w5.Tugs == 0 and w5:Dealt(pick5) > 0, "a pick at 150 deg and the goose in front: monsters only, no tug", show({ #w5.Tugs, w5:Dealt(pick5) }))
	-- Mage Splash: a pick at 30 deg and an enemy beside it: both in the blast (inside the cone)
	local w6, p6 = H.World({ Class = "Mage" })
	local pick6 = H.Mob(w6, 30, 20)
	local v6 = H.Enemy(w6, 2, 30, 22)
	H.Swing(w6, p6, pick6.Model)
	check(w6:Dealt(pick6) > 0 and H.Hp(v6) < 100, "Mage: a pick at 30 deg and an enemy beside it: both in the blast", show({ w6:Dealt(pick6), H.Hp(v6) }))
end)

runGroup("the slack is the pick's only", function()
	local w, p = H.World()
	local range = w.Range
	-- range + 1 behind: accepted (hit); range + 3: ignored (nothing in Range: no hit)
	local near = H.Mob(w, 180, range + 1)
	H.Swing(w, p, near.Model)
	check(w:Dealt(near) > 0, "a pick at Range + 1 (behind): accepted, it is hit", w:Dealt(near))
	local w2, p2 = H.World()
	local far = H.Mob(w2, 180, range + 3)
	local wrote2 = H.Swing(w2, p2, far.Model)
	check(w2:Dealt(far) == 0 and not wrote2, "a pick at Range + 3: ignored (no hit, no turn)", show({ w2:Dealt(far), wrote2 }))
	-- Around with a pick at Range + 1 ahead: the pick is hit, another slime at Range + 1 is not, one inside Range is
	local w3, p3 = H.World()
	local pick = H.Mob(w3, 0, range + 1)
	local edge = H.Mob(w3, 20, range + 1)
	local inside = H.Mob(w3, 20, range - 2)
	H.Swing(w3, p3, pick.Model)
	check(w3:Dealt(pick) > 0 and w3:Dealt(edge) == 0 and w3:Dealt(inside) > 0,
		"Around: the pick at Range + 1 is hit, another slime at Range + 1 is not, one inside Range is",
		show({ w3:Dealt(pick), w3:Dealt(edge), w3:Dealt(inside) }))
	-- a pick at Range + 1 behind: a slime beside it also at Range + 1 is not hit
	local w4, p4 = H.World()
	local pick4 = H.Mob(w4, 180, range + 1)
	local edge4 = H.Mob(w4, 170, range + 1)
	H.Swing(w4, p4, pick4.Model)
	check(w4:Dealt(pick4) > 0 and w4:Dealt(edge4) == 0, "behind: only the pick gets the slack (its neighbour at Range + 1 is not hit)",
		show({ w4:Dealt(pick4), w4:Dealt(edge4) }))
	-- Multi (Archer) and Splash (Mage) at Range + 1 straight ahead
	local w5, p5 = H.World({ Class = "Archer" })
	local pick5 = H.Mob(w5, 0, w5.Range + 1)
	H.Swing(w5, p5, pick5.Model)
	check(w5:Dealt(pick5) > 0, "Archer: a pick at Range + 1 straight ahead is shot", w5:Dealt(pick5))
	local w6, p6 = H.World({ Class = "Mage" })
	local pick6 = H.Mob(w6, 0, w6.Range + 1)
	H.Swing(w6, p6, pick6.Model)
	check(w6:Dealt(pick6) > 0, "Mage: a lone pick at Range + 1 straight ahead is the orb's centre", w6:Dealt(pick6))
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
		check(got == base, case[1] .. ": ignored (the same swing as with no pick)", show({ got, base }))
	end
	-- an ignored pick still lets today's A23-61 rule turn to the nearest monster behind - and that turn still writes the
	-- root (review B: only the pick path never writes it)
	local w, p = H.World()
	local behind = H.Mob(w, 170, 5)
	behind._hidden = true
	local wrote = H.Swing(w, p, behind.Model)
	check(wrote and w:Dealt(behind) > 0, "an ignored pick: the A23-61 rule still turns (writes the root) to the nearest monster behind",
		show({ wrote, w:Dealt(behind) }))
	-- more arguments than the pick: the press still swings, without the pick
	local w2, p2 = H.World()
	local front2 = H.Mob(w2, 30, 4)
	local behind2 = H.Mob(w2, 160, 8)
	H.Swing(w2, p2, behind2.Model, "extra")
	check(w2:Dealt(front2) > 0 and w2:Dealt(behind2) == 0, "Swing(pick, extra): the swing goes as with no pick",
		show({ w2:Dealt(front2), w2:Dealt(behind2) }))
end)

------------------------------------------------------------------ patterns
runGroup("mage splash", function()
	-- outside the cone: the orb goes to the pick behind me; the slime 3 studs past it is in the blast, the nearer front
	-- one is not, the enemy beside the pick is not hit (monsters only)
	local w, p = H.World({ Class = "Mage" })
	local front = H.Mob(w, 0, 10)
	local pick = H.Mob(w, 150, 20)
	local past = H.Mob(w, 150, 23)
	local v = H.Enemy(w, 2, 150, 18)
	local wrote = H.Swing(w, p, pick.Model)
	check(w:Dealt(pick) > 0 and w:Dealt(past) > 0 and w:Dealt(front) == 0 and H.Hp(v) == 100 and not wrote,
		"Splash (pick behind): centre = the pick, its neighbour hit, the front slime and the enemy not, no root write",
		show({ w:Dealt(pick), w:Dealt(past), w:Dealt(front), H.Hp(v), wrote }))
	local fx = w:FxOf("Swing")
	check(#fx > 0 and H.Near(fx[#fx].Data.Pos, pick.Root.Position), "the orb Fx lands on the pick", fx[#fx] and show(fx[#fx].Data.Pos))
	-- straight ahead, farther than a front slime: centre = the pick; the enemy beside it is hit (as today)
	local w2, p2 = H.World({ Class = "Mage" })
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 0, 25)
	local v2 = H.Enemy(w2, 2, 3, 26)
	H.Swing(w2, p2, pick2.Model)
	check(w2:Dealt(pick2) > 0 and w2:Dealt(near2) == 0 and H.Hp(v2) < 100,
		"Splash (ahead): centre = the pick (not the nearer slime), the enemy beside it is hit as today",
		show({ w2:Dealt(pick2), w2:Dealt(near2), H.Hp(v2) }))
	-- the pick beats a nearer goose and a nearer enemy (they are not the centre and not in the blast)
	local w3, p3 = H.World({ Class = "Mage", Goose = vec(0, 0, -5) })
	local pick3 = H.Mob(w3, 0, 25)
	H.Swing(w3, p3, pick3.Model)
	check(w3:Dealt(pick3) > 0 and #w3.Tugs == 0, "Splash: the pick beats a nearer goose (no tug, the pick is hit)", show({ w3:Dealt(pick3), #w3.Tugs }))
	local w4, p4 = H.World({ Class = "Mage" })
	local pick4 = H.Mob(w4, 0, 25)
	local v4 = H.Enemy(w4, 2, 5, 8)
	H.Swing(w4, p4, pick4.Model)
	check(w4:Dealt(pick4) > 0 and H.Hp(v4) == 100, "Splash: the pick beats a nearer enemy (the enemy is not hit)", show({ w4:Dealt(pick4), H.Hp(v4) }))
end)

runGroup("archer multi and bare hands", function()
	-- the pick first, then the nearest (Targets 2): pick + the 10-stud slime, not the 15-stud one
	local w, p = H.World({ Class = "Archer" })
	local m1 = H.Mob(w, 30, 10)
	local m2 = H.Mob(w, -30, 15)
	local pick = H.Mob(w, 0, 25)
	H.Swing(w, p, pick.Model)
	check(w:Dealt(pick) > 0 and w:Dealt(m1) > 0 and w:Dealt(m2) == 0, "Multi: the pick first, then the nearest (Targets 2)",
		show({ w:Dealt(pick), w:Dealt(m1), w:Dealt(m2) }))
	-- the pick is also the nearest: hit once, the next one is the second arrow
	local w2, p2 = H.World({ Class = "Archer" })
	local pick2 = H.Mob(w2, 0, 8)
	local m3 = H.Mob(w2, 30, 10)
	H.Swing(w2, p2, pick2.Model)
	check(H.Hits(w2, pick2) == 1 and H.Hits(w2, m3) == 1, "Multi: the pick is never shot twice (the second arrow goes to the next)",
		show({ H.Hits(w2, pick2), H.Hits(w2, m3) }))
	-- inside KeepDeg the second arrow may still go to an enemy, the goose still counts
	local w3, p3 = H.World({ Class = "Archer" })
	local pick3 = H.Mob(w3, 0, 25)
	local v3 = H.Enemy(w3, 2, 10, 8)
	H.Swing(w3, p3, pick3.Model)
	check(w3:Dealt(pick3) > 0 and H.Hp(v3) < 100, "Multi: the pick, then the nearer enemy (second arrow)", show({ w3:Dealt(pick3), H.Hp(v3) }))
	local w4, p4 = H.World({ Class = "Archer", Goose = vec(0, 0, -8) })
	local pick4 = H.Mob(w4, 0, 25)
	H.Swing(w4, p4, pick4.Model)
	check(w4:Dealt(pick4) > 0 and #w4.Tugs == 1, "Multi: the pick, then the goose (second arrow, one tug)", show({ w4:Dealt(pick4), #w4.Tugs }))
	-- a pick behind (outside the cone): monsters only - no arrow for the enemy or the goose in front
	local w5, p5 = H.World({ Class = "Archer", Goose = vec(0, 0, -8) })
	local pick5 = H.Mob(w5, 180, 15)
	local v5 = H.Enemy(w5, 2, 0, 8)
	local wrote5 = H.Swing(w5, p5, pick5.Model)
	check(w5:Dealt(pick5) > 0 and H.Hp(v5) == 100 and #w5.Tugs == 0 and not wrote5,
		"Multi with a pick behind: the pick, no player, no goose, no root write", show({ w5:Dealt(pick5), H.Hp(v5), #w5.Tugs, wrote5 }))
	-- bare hands (one punch, Range 7): the pick behind-right, not the nearer slime in front
	local w6, p6 = H.World({ Bare = true })
	local front6 = H.Mob(w6, 20, 3)
	local pick6 = H.Mob(w6, 170, 5)
	H.Swing(w6, p6, pick6.Model)
	check(w6:Dealt(pick6) > 0 and w6:Dealt(front6) == 0, "bare hands: the punch goes to the pick, the nearer front slime is not hit",
		show({ w6:Dealt(pick6), w6:Dealt(front6) }))
end)

runGroup("not turned: the goose as today", function()
	local w, p = H.World({ Goose = vec(0, 0, -4) })
	local pick = H.Mob(w, 0, 5)
	H.Swing(w, p, pick.Model)
	check(w:Dealt(pick) > 0 and #w.Tugs == 1, "a pick straight ahead: the goose in front is tugged as today", show({ w:Dealt(pick), #w.Tugs }))
	-- Around with a pick behind me: an enemy and the goose behind me (beside the pick) are not hit / counted
	local w2, p2 = H.World({ Goose = vec(0, 0, 4) })
	local pick2 = H.Mob(w2, 180, 5)
	local v2 = H.Enemy(w2, 2, 170, 4)
	H.Swing(w2, p2, pick2.Model)
	check(w2:Dealt(pick2) > 0 and H.Hp(v2) == 100 and #w2.Tugs == 0, "Around, pick behind: the enemy and the goose beside it are not hit",
		show({ w2:Dealt(pick2), H.Hp(v2), #w2.Tugs }))
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
	-- auto skill Q (Mage, Target): the centre stays the nearest aimed slime
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

------------------------------------------------------------------ the skill Q
runGroup("skill Q takes the pick", function()
	-- Mage (Target centre), through the old Release remote and SkillService: the blast on the pick, not the nearer slime;
	-- the enemy beside the pick is hit (inside the cone, manual: as today)
	local w, p = H.World({ Class = "Mage" })
	local near = H.Mob(w, 0, 10)
	local pick = H.Mob(w, 0, 30)
	local v = H.Enemy(w, 2, 2, 31)
	local wrote = H.Release(w, p, pick.Model)
	local info = H.Last(w)
	check(info ~= nil and not wrote and H.Near(info.Center, pick.Root.Position) and w:Dealt(pick) > 0 and w:Dealt(near) == 0 and H.Hp(v) < 100,
		"Q (Mage) through SkillService: centre = the pick, the nearer slime is not hit, the enemy beside it is",
		info and show({ info.Center, wrote, w:Dealt(pick), w:Dealt(near), H.Hp(v) }))
	local w0, p0 = H.World({ Class = "Mage" })
	local near0 = H.Mob(w0, 0, 10)
	local pick0 = H.Mob(w0, 0, 30)
	H.Release(w0, p0)
	local info0 = H.Last(w0)
	check(info0 ~= nil and H.Near(info0.Center, near0.Root.Position) and w0:Dealt(pick0) == 0, "control: Q with no pick = the nearest aimed slime",
		info0 and show(info0.Center))
	-- review A: a pick at 30 deg (inside the cone) with an enemy beside it: the enemy is hit
	local w1, p1 = H.World({ Class = "Mage" })
	local pick1 = H.Mob(w1, 30, 20)
	local v1 = H.Enemy(w1, 2, 30, 22)
	H.Release(w1, p1, pick1.Model)
	local info1 = H.Last(w1)
	check(info1 ~= nil and H.Near(info1.Center, pick1.Root.Position) and H.Hp(v1) < 100, "Q at a pick at 30 deg: the enemy beside it is hit",
		info1 and show({ info1.Center, H.Hp(v1) }))
	-- a pick behind me (outside the cone): the blast there, monsters only, no root write
	local w2, p2 = H.World({ Class = "Mage" })
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 160, 20)
	local v2 = H.Enemy(w2, 2, 160, 22)
	local wrote2 = H.Release(w2, p2, pick2.Model)
	local info2 = H.Last(w2)
	check(info2 ~= nil and not wrote2 and H.Near(info2.Center, pick2.Root.Position) and w2:Dealt(near2) == 0 and H.Hp(v2) == 100,
		"Q at a pick behind: the blast there, the enemy beside it is not hit, no root write",
		info2 and show({ info2.Center, wrote2, w2:Dealt(near2), H.Hp(v2) }))
	-- the pick beats a nearer enemy in front
	local w3, p3 = H.World({ Class = "Mage" })
	local pick3 = H.Mob(w3, 0, 30)
	local v3 = H.Enemy(w3, 2, 5, 8)
	H.Release(w3, p3, pick3.Model)
	local info3 = H.Last(w3)
	check(info3 ~= nil and H.Near(info3.Center, pick3.Root.Position) and H.Hp(v3) == 100, "Q: the pick beats a nearer enemy (not hit)",
		info3 and show({ info3.Center, H.Hp(v3) }))
	-- Range + 1 is the centre (Archer); a lone pick at Range + 3 is not (Mage: the blast stays on me, the pick unhit)
	local w4, p4 = H.World({ Class = "Archer" })
	local pick4 = H.Mob(w4, 0, w4.Range + 1)
	H.Release(w4, p4, pick4.Model)
	local info4 = H.Last(w4)
	check(info4 ~= nil and H.Near(info4.Center, pick4.Root.Position), "Q (Archer): a pick at Range + 1 is the centre", info4 and show(info4.Center))
	local w5, p5 = H.World({ Class = "Mage" })
	local pick5 = H.Mob(w5, 0, w5.Range + 3)
	H.Release(w5, p5, pick5.Model)
	local info5 = H.Last(w5)
	check(info5 ~= nil and H.Near(info5.Center, vec(0, 0, 0)) and w5:Dealt(pick5) == 0, "Q (Mage): a lone pick at Range + 3 is ignored",
		info5 and show({ info5.Center, w5:Dealt(pick5) }))
	-- a bad pick (hidden): Q as with none
	local w6, p6 = H.World({ Class = "Mage" })
	local near6 = H.Mob(w6, 0, 10)
	local pick6 = H.Mob(w6, 0, 30)
	pick6._hidden = true
	H.Release(w6, p6, pick6.Model)
	local info6 = H.Last(w6)
	check(info6 ~= nil and H.Near(info6.Center, near6.Root.Position), "Q with a hidden pick: ignored (the nearest aimed slime)", info6 and show(info6.Center))
	-- Warrior (the blast is centred on me): the pick changes nothing, no root write
	local w7, p7 = H.World()
	H.Mob(w7, 30, 4)
	local pick7 = H.Mob(w7, 160, 6)
	local wrote7 = H.Release(w7, p7, pick7.Model)
	local info7 = H.Last(w7)
	check(info7 ~= nil and not wrote7 and H.Near(info7.Center, vec(0, 0, 0)), "Q (Warrior, centred on me): the pick changes nothing",
		info7 and show({ info7.Center, wrote7 }))
	-- more arguments than the pick: Q still goes, without the pick
	local w8, p8 = H.World({ Class = "Mage" })
	local near8 = H.Mob(w8, 0, 10)
	local pick8 = H.Mob(w8, 0, 30)
	H.Release(w8, p8, pick8.Model, 1)
	local info8 = H.Last(w8)
	check(info8 ~= nil and H.Near(info8.Center, near8.Root.Position), "Release(pick, extra): Q goes as with no pick", info8 and show(info8.Center))
	-- review B: with no pick, Q's own A23-61 turn (a lone slime behind) still writes the root
	local w9, p9 = H.World({ Class = "Mage" })
	local back9 = H.Mob(w9, 180, 10)
	local wrote9 = H.Release(w9, p9)
	local info9 = H.Last(w9)
	check(info9 ~= nil and wrote9 and H.Near(info9.Center, back9.Root.Position), "Q with no pick: the A23-61 turn still writes the root",
		info9 and show({ info9.Center, wrote9 }))
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
	-- the Release remote without SkillService (CombatService's own fallback) passes the pick too
	local w2, p2 = H.World({ Class = "Mage" })
	w2.Registry.SkillService = nil
	local near2 = H.Mob(w2, 0, 10)
	local pick2 = H.Mob(w2, 0, 30)
	H.Release(w2, p2, pick2.Model)
	local info2 = H.Last(w2)
	check(info2 ~= nil and H.Near(info2.Center, pick2.Root.Position) and w2:Dealt(near2) == 0,
		"Release without SkillService: the pick is the centre", info2 and show(info2.Center))
end)

finish()
