-- boss_leap_offline.luau : A23-113 ① big landings (MonsterService LEAP, Config.BossLeap), offline. tools/test_boss_leap.py
-- puts the source bindings + dev2_kit.luau in front of this file. MonsterService's real LEAP section and its real
-- targetable() run on engine doubles (ground, towns, CombatService, the AI around it).

local oldIndex = vmt.__index
vmt.__index = function(v, key)
	if key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	return oldIndex(v, key)
end

local function near(a, b, eps)
	return typeofDouble(a) == "Vector3" and typeofDouble(b) == "Vector3" and math.abs(a.X - b.X) < (eps or 1e-6)
		and math.abs(a.Y - b.Y) < (eps or 1e-6) and math.abs(a.Z - b.Z) < (eps or 1e-6)
end

local function zoneCenter(C, id)
	local z = C.Zones[id]
	return vec(z.Center.X, 1, z.Center.Z)
end

-- a LEAP world: H = the section's upvalues (doubles), w.Leap = the real LEAP table. opts.Ground(x, z) -> point, noHit
local function leapWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	local C = w.Config
	w.Hits, w.Strikes, w.Town, w.Dead, w.RootOf, w.Pivots, w.Faces = {}, {}, {}, {}, {}, {}, {}
	w.DataOf = {}
	w.Ground = opts.Ground or function(x, z) return vec(x, 1, z), false end
	local util = setmetatable({
		IsAlive = function(p) return not w.Dead[p] end,
		GetRoot = function(p) return w.RootOf[p] end,
	}, { __index = w.Util })
	local records = {}
	w.Records = records
	local H = {
		records = records,
		FACE = { Active = w.Faces, Keep = 0.6 },
		S = { CombatService = { DamagePlayer = function(p, dmg, _, crit, kind)
			table.insert(w.Hits, { P = p, Dmg = dmg, Crit = crit, Kind = kind })
		end },
			-- A23-227: the saves the field King's shield reads (w.DataOf[p]; none = no story yet)
			PlayerService = { GetData = function(p) return w.DataOf[p] end } },
		Players = w.Players,
		isPlayerInTown = function(p) return w.Town[p] == true end,
		warnThrottled = function(_, msg) table.insert(w.Warnings, tostring(msg)) end,
		groundPoint = function(x, z, maxY)
			w.LastMaxY = maxY
			return w.Ground(x, z)
		end,
	}
	w.H = H
	local env = w:Env()
	w.Leap = execute("LEAP", LEAP_EXTRACT, env, C, util, H)
	-- a player standing at pos (root), Lv 10 with an hour played (past a boss's new-player rules)
	function w:Player(id, pos, attrs)
		local p = self:NewPlayer(id, attrs or { Level = 10, PlaytimeSeconds = 3600 })
		self.RootOf[p] = { Position = pos }
		return p
	end
	function w:Move(p, pos) self.RootOf[p].Position = pos end
	-- a monster record of `kind` standing on the ground at feet (root rootOffset studs up)
	function w:Rec(kind, feet, owner)
		local def = C.MonsterTypes[kind]
		local model = newInstance("Model", self)
		model.Parent = newInstance("Folder", self)
		rawset(model, "PivotTo", function(_, cf) table.insert(w.Pivots, cf) end)
		local rec = { Id = #records + 1, Kind = kind, Def = def, Alive = true, ZoneId = def.Zone, Model = model, Owner = owner,
			_rootOffset = 3, _nextAttackAt = 0, _moves = {} }
		rec.Root = { Position = feet + vec(0, 3, 0), Parent = model, CFrame = { LookVector = vec(0, 0, -1) } }
		rec.Humanoid = { MoveTo = function(_, p) table.insert(rec._moves, p) end }
		records[rec.Id] = rec
		return rec
	end
	function w:Info(p) return { Player = p, Pos = self.RootOf[p].Position } end
	-- the AI asks once: LEAP.Try(rec, info, d, now)
	function w:Try(rec, p)
		local info = self:Info(p)
		return self.Leap.Try(rec, info, self.Util.FlatDistance(rec.Root.Position, info.Pos), self.Clock)
	end
	function w:HitsOf(p)
		local n = 0
		for _, h in self.Hits do if h.P == p then n += 1 end end
		return n
	end
	return w
end

runGroup("config", function()
	local C = newWorld().Config
	local B, MC, LS, FK = C.BossLeap, C.Monsters, C.LandShadow, C.FirstKOKing
	check(type(B) == "table" and B.Enabled == true and B.Grace == 0.5 and B.YRange == 12 and B.RetryDelay == 0.5,
		"Config.BossLeap: on, Grace 0.5, YRange 12, RetryDelay 0.5", show(B))
	local K, L = B.Kinds.SlimeKing, B.Kinds.CaptainClatter
	check(K and K.Mode == "Leap" and K.Range == 14 and K.Warn == 1 and K.Height == 12 and K.Cycle == nil and K.Mult == nil,
		"the King Slime leaps (Range 14, Warn 1 s, Height 12; its cycle = the swing's)", show(K))
	check(L and L.Mode == "Slam" and L.Every == 3 and L.Warn == 1 and L.Mult == 2, "Captain Clatter: every 3rd attack a slam x2", show(L))
	check(K.Range > MC.AttackRange and K.Warn <= LS.MaxTime and L.Warn <= LS.MaxTime, "a leap reaches past a swing; warnings fit the client's MaxTime")
	check(LS.Radius.SlimeKing == 10 and LS.Radius.CaptainClatter == 12 and FK.LandRadius == LS.Radius.SlimeKing,
		"circles: King 10, Clatter 12 (the client's radii); the first King's drop = the same 10")
	check(B.Kinds.PumpkinKing == nil, "the hidden Pumpkin King has none (A23-119)")
	check(FK.LeapGrow == 6 and FK.LeapGrowMax == 18 and FK.FirstLeapAfter == 0.8, "first King: +6 per miss up to +18, first leap 0.8 s after the drop")
	-- the first King keeps hopping until it lands: its biggest circle cannot be left in one warning by any class
	local fastest = 0
	for _, c in C.Classes do fastest = math.max(fastest, (c.WalkSpeedMult or 1) * C.Player.WalkSpeed) end
	check(LS.Radius.SlimeKing + FK.LeapGrowMax - B.Grace > fastest * K.Warn and LS.Radius.SlimeKing + FK.LeapGrowMax <= LS.MaxRadius,
		"the grown circle (28) cannot be left in 1 s even at the fastest walk (" .. fastest .. ")", tostring(fastest))
	check(LS.Radius.SlimeKing - B.Grace < C.Player.WalkSpeed * K.Warn, "the normal circle (10) can be left in 1 s (the dodge is real)")
end)

runGroup("leap start", function()
	local w = leapWorld()
	local C = w.Config
	local m = zoneCenter(C, "SlimeMeadow")
	local king = w:Rec("SlimeKing", m)
	local p = w:Player(1, m + vec(8, 3, 0))
	w.Time = 5000
	check(w:Try(king, p) == true, "in Range and ready: a leap starts")
	local A = king.Model.Attrs
	local spot = vec(m.X + 8, 1, m.Z)
	check(type(king._leap) == "table" and king._windup == king._leap.Token, "rec._leap set; its token blocks swings (_windup)")
	check(near(A.DropPos, spot) and A.DropRadius == 10 and A.DropTime == 1 and A.DropHeight == 12 and near(A.DropFrom, m)
		and A.DropAt == 5000, "attributes: DropPos = the ground where the target stood, DropRadius 10, DropTime 1, DropHeight 12, DropFrom, DropAt = now",
		show(A))
	check(#w.Pivots == 1 and w.Pivots[1].Ctor == "lookAt" and near(w.Pivots[1].Args[1], spot + vec(0, 3, 0))
		and near(w.Pivots[1].Args[2] - w.Pivots[1].Args[1], vec(1, 0, 0)), "the body moves onto the spot at once, facing the way it leapt",
		show(w.Pivots[1]))
	check(king._nextAttackAt == w.Clock + C.Monsters.AttackCooldown and king._leap.Mult == 1,
		"the next leap one cycle (1.5 s = the swing's) after this one starts; x1 hit", show({ king._nextAttackAt - w.Clock, king._leap.Mult }))
	check(#w.Hits == 0, "nothing lands at once")
	w:Advance(0.99)
	check(#w.Hits == 0, "nothing before the warning ends")
	-- a second try during the warning never starts another
	local before = A.DropAt
	w.Time += 0.5
	w:Try(king, p)
	check(A.DropAt == before and #w.Pivots == 1, "one landing at a time")
	w:Advance(0.02)
	check(#w.Hits == 1 and w.Hits[1].P == p and w.Hits[1].Dmg == C.MonsterTypes.SlimeKing.Damage and w.Hits[1].Kind == "SlimeKing",
		"standing still: hit once, the plain hit (x1), the KO screen names the King", w.Hits[1] and tostring(w.Hits[1].Dmg))
	check(king._leap == nil and king._windup == nil, "landed: free again")
	check(A.AttackSeq == nil, "a leap bumps no AttackSeq (the drop's own thud plays)")
end)

runGroup("the circle", function()
	local C = leapWorld().Config
	local m = zoneCenter(C, "SlimeMeadow")
	local function landWith(where, attrs, setup)
		local w = leapWorld()
		local king = w:Rec("SlimeKing", m)
		local p = w:Player(1, m + vec(6, 3, 0), attrs)
		w:Try(king, p)
		w:Move(p, where)
		if setup then setup(w, p) end
		w:Advance(1.01)
		return w:HitsOf(p), w
	end
	local spot = vec(m.X + 6, 1, m.Z)
	check(landWith(spot + vec(9.4, 3, 0)) == 1, "9.4 studs from the spot: hit (inside 10 - 0.5)")
	check(landWith(spot + vec(9.6, 3, 0)) == 0, "9.6 studs: not hit (outside the circle = not hit)")
	check(landWith(spot + vec(0, 3, 6.6)) == 1 and landWith(spot + vec(6.7, 3, 6.7)) == 1 and landWith(spot + vec(6.8, 3, 6.8)) == 0,
		"flat distance in any direction (6.7, 6.7 = 9.48 in; 6.8, 6.8 = 9.62 out)")
	check(landWith(spot + vec(0, 11, 0)) == 1 and landWith(spot + vec(0, 13, 0)) == 0, "YRange: 11 up is hit, 13 up is not")
	check(landWith(spot + vec(1, 3, 0), nil, function(w, p) w.Dead[p] = true end) == 0, "a dead player: not hit")
	check(landWith(spot + vec(1, 3, 0), nil, function(w, p) w.Town[p] = true end) == 0, "in a town: not hit")
	check(landWith(vec(spot.X + 1, -4, spot.Z)) == 0, "in the water (below OUT_Y): not hit")
	check(landWith(spot + vec(1, 3, 0), { Level = 4, PlaytimeSeconds = 3600 }) == 0, "a boss leaves Lv < 5 alone")
	check(landWith(spot + vec(1, 3, 0), { Level = 10, PlaytimeSeconds = 100 }) == 0, "a boss leaves < 600 s played alone")
	-- everyone in it is hit once; the King's zone only
	local w = leapWorld()
	local king = w:Rec("SlimeKing", m)
	local a, b, c = w:Player(1, m + vec(6, 3, 0)), w:Player(2, m + vec(9, 3, 3)), w:Player(3, m + vec(20, 3, 0))
	w:Try(king, a)
	w:Advance(1.01)
	check(w:HitsOf(a) == 1 and w:HitsOf(b) == 1 and w:HitsOf(c) == 0, "every valid player in the circle is hit once; outside nobody")
end)

-- A23-227 (최종 검수 10/17, r6 play): the FIELD King never targets or hits a player below FirstKOKing.FieldSafeBelow (10) whose
-- story has not done FieldSafeUntil (M1_2, the King's Hop); a personal King is not the field King
runGroup("field king shield (A23-227)", function()
	local C = leapWorld().Config
	local F = C.FirstKOKing
	check(F.FieldSafeUntil == "M1_2" and F.FieldSafeBelow == 10 and F.Kind == "SlimeKing", "Config: FieldSafeUntil M1_2, FieldSafeBelow 10", show(F))
	local m = zoneCenter(C, "SlimeMeadow")
	local spot = vec(m.X + 6, 1, m.Z)
	local function landWith(level, done)
		local w = leapWorld()
		local king = w:Rec("SlimeKing", m)
		local p = w:Player(1, m + vec(6, 3, 0), { Level = level, PlaytimeSeconds = 3600 })
		if done ~= nil then w.DataOf[p] = { Story = { Done = { M1_2 = done or nil } } } end
		w:Try(king, p)
		w:Move(p, spot + vec(1, 3, 0))
		w:Advance(1.01)
		return w:HitsOf(p)
	end
	check(landWith(5, false) == 0, "Lv5 on the King's Hop (M1_2 not done): the field King's landing does not hit")
	check(landWith(5, nil) == 0, "Lv5 with no story yet: not hit either")
	check(landWith(9, false) == 0, "Lv9, M1_2 not done: not hit")
	check(landWith(5, true) == 1, "Lv5 with M1_2 done: hit as before")
	check(landWith(10, false) == 1, "Lv10 (FieldSafeBelow): hit even without the story (an old save is not shielded forever)")
	-- not even picked: the AI's targetable() says no (no chasing, no swings, no leaps aimed at them)
	local function picks(level, done, owner)
		local w = leapWorld()
		local p = w:Player(1, m + vec(6, 3, 0), { Level = level, PlaytimeSeconds = 3600 })
		if done ~= nil then w.DataOf[p] = { Story = { Done = { M1_2 = done or nil } } } end
		local king = w:Rec("SlimeKing", m, owner and p or nil)
		return w.Leap._targetable(king, { Player = p, Pos = m + vec(6, 3, 0), Town = false, Zone = "SlimeMeadow" })
	end
	check(picks(5, false) == false and picks(5, nil) == false and picks(9, false) == false,
		"the field King does not pick a Lv5-9 player before M1_2 is done", show({ picks(5, false), picks(5, nil), picks(9, false) }))
	check(picks(5, true) == true and picks(10, false) == true, "... M1_2 done, or Lv10: picked as before", show({ picks(5, true), picks(10, false) }))
	-- another boss in the meadow is not touched by this rule (FirstKOKing.Kind only)
	local w0 = leapWorld()
	local other
	for kind, def in C.MonsterTypes do
		if def.Boss == true and kind ~= F.Kind and def.Zone == "SlimeMeadow" then other = kind break end
	end
	if other then
		local p0 = w0:Player(1, m + vec(6, 3, 0), { Level = 5, PlaytimeSeconds = 3600 })
		local r0 = w0:Rec(other, m)
		check(w0.Leap._targetable(r0, { Player = p0, Pos = m + vec(6, 3, 0), Town = false, Zone = "SlimeMeadow" }) == true,
			"another meadow boss (" .. other .. ") still picks a Lv5 before M1_2")
	end
	-- a personal King (Owner set) is the player's own fight: struck through its own strike, shield or not
	local w = leapWorld()
	local p = w:Player(2, m + vec(6, 3, 0), { Level = 5, PlaytimeSeconds = 3600 })
	local mine = w:Rec("SlimeKing", m, p)
	mine._strike = function(rec, target, mult) table.insert(w.Strikes, { Rec = rec, T = target, Mult = mult }) end
	w:Try(mine, p)
	w:Advance(1.01)
	check(#w.Strikes == 1 and w.Strikes[1].T == p, "a personal King still lands on its Lv5 owner before M1_2 (the rematch itself)", tostring(#w.Strikes))
end)

-- r8 (최종 검수 10/17): a King with _leapCycle (SpawnPersonal opts.LeapCycle: the rematch King, 3 s) leaps that often
runGroup("leap cycle", function()
	local C = leapWorld().Config
	local m = zoneCenter(C, "SlimeMeadow")
	local w = leapWorld()
	local p = w:Player(1, m + vec(5, 3, 0), { Level = 2, PlaytimeSeconds = 30 })
	local king = w:Rec("SlimeKing", m, p)
	king._strike = function() end
	king._leapCycle = 3
	local t0 = w.Clock
	w:Try(king, p)
	check(math.abs(king._nextAttackAt - (t0 + 3)) < 1e-6, "_leapCycle 3: the next leap 3 s after this one", tostring(king._nextAttackAt - t0))
	local k2 = w:Rec("SlimeKing", m, p)
	k2._strike = function() end
	w:Try(k2, p)
	check(math.abs(k2._nextAttackAt - (w.Clock + C.Monsters.AttackCooldown)) < 1e-6, "no _leapCycle: the BossLeap cycle (AttackCooldown 1.5)",
		tostring(k2._nextAttackAt - w.Clock))
end)

runGroup("personal king", function()
	local C = leapWorld().Config
	local m = zoneCenter(C, "SlimeMeadow")
	local w = leapWorld()
	local owner = w:Player(1, m + vec(5, 3, 0), { Level = 2, PlaytimeSeconds = 30 })
	local other = w:Player(2, m + vec(5, 3, 1))
	local king = w:Rec("SlimeKing", m, owner)
	king._strike = function(rec, target, mult)
		table.insert(w.Strikes, { Rec = rec, T = target, Mult = mult })
	end
	king._leapGrow, king._leapGrowMax = 6, 18
	w:Try(king, owner)
	w:Advance(1.01)
	check(#w.Strikes == 1 and w.Strikes[1].T == owner and w.Strikes[1].Mult == 1 and #w.Hits == 0,
		"a personal King: only its owner (a new player too), through its service's strike(rec, player, mult)", w.Strikes[1] and tostring(w.Strikes[1].Mult))
	check(king._leapExtra == nil, "a hit does not grow the circle")
	-- misses grow the next circle: 16, 22, 28, then no more
	local radii = {}
	for _ = 1, 5 do
		w.Clock = math.max(w.Clock, king._nextAttackAt)
		w:Move(owner, king.Root.Position + vec(5, 0, 0))
		w:Try(king, owner)
		table.insert(radii, king.Model.Attrs.DropRadius)
		w:Move(owner, king.Model.Attrs.DropPos + vec(king.Model.Attrs.DropRadius + 1, 3, 0)) -- steps out
		w:Advance(1.01)
	end
	check(radii[1] == 10 and radii[2] == 16 and radii[3] == 22 and radii[4] == 28 and radii[5] == 28,
		"each miss grows the next circle by 6, up to +18 (10 / 16 / 22 / 28 / 28)", show(radii))
	check(#w.Strikes == 1, "stepped out every time: no more strikes")
	-- the owner in a town is never hit; another player never
	w.Clock = math.max(w.Clock, king._nextAttackAt)
	w:Move(owner, m + vec(5, 3, 0))
	w:Try(king, owner)
	w.Town[owner] = true
	w:Advance(1.01)
	check(#w.Strikes == 1 and w:HitsOf(other) == 0, "the owner in a town: not hit; the other player: never")
	-- a personal King leaps out of a zone too (it follows its owner); without a strike hook: the plain hit
	local w2 = leapWorld()
	local o2 = w2:Player(1, vec(0, 3, 0))
	local k2 = w2:Rec("SlimeKing", vec(-6, 1, 0), o2)
	check(w2:Try(k2, o2) == true, "a personal King leaps wherever its owner stands (no zone rule)")
	w2:Advance(1.01)
	check(#w2.Hits == 1 and w2.Hits[1].P == o2, "no strike hook: the plain hit")
end)

runGroup("range, cooldown, ground", function()
	local C = leapWorld().Config
	local m = zoneCenter(C, "SlimeMeadow")
	local w = leapWorld()
	local king = w:Rec("SlimeKing", m)
	local p = w:Player(1, m + vec(14.5, 3, 0))
	check(w:Try(king, p) == false and king._leap == nil, "past Range (14): no leap, the chase goes on")
	w:Move(p, m + vec(13.5, 3, 0))
	king._nextAttackAt = w.Clock + 1
	check(w:Try(king, p) == false and king._leap == nil, "in Range but between leaps, out of reach: false (it walks closer)")
	w:Move(p, m + vec(4, 3, 0))
	local moves = #king._moves
	check(w:Try(king, p) == true and king._leap == nil and #king._moves == moves + 1 and near(king._moves[#king._moves], king.Root.Position)
		and w.Faces[king] and w.Faces[king].Target == p, "between leaps in reach: it stands facing the target (never a swing)")
	-- no walkable ground where the target stands: no leap, a retry soon
	local w3 = leapWorld({ Ground = function() return nil, false end })
	local k3 = w3:Rec("SlimeKing", m)
	local p3 = w3:Player(1, m + vec(10, 3, 0))
	check(w3:Try(k3, p3) == false and k3._leap == nil and k3.Model.Attrs.DropAt == nil and #w3.Pivots == 0,
		"no ground there (water / a ridge): no leap, no circle")
	check(math.abs(k3._nextAttackAt - (w3.Clock + 0.5)) < 1e-9, "it tries again RetryDelay (0.5 s) later", tostring(k3._nextAttackAt - w3.Clock))
	-- a bare test place (nothing hit): flat ground at its own feet height
	local w4 = leapWorld({ Ground = function() return nil, true end })
	local k4 = w4:Rec("SlimeKing", m)
	local p4 = w4:Player(1, m + vec(10, 3, 0))
	check(w4:Try(k4, p4) == true and near(k4.Model.Attrs.DropPos, vec(m.X + 10, m.Y, m.Z)), "a bare test place: flat ground at its feet height")
	-- a zone King never leaps out of its zone
	local edge = C.Zones.SlimeMeadow
	local out = vec(edge.Center.X + edge.Size.X / 2 + 3, 1, edge.Center.Z)
	local w5 = leapWorld()
	local k5 = w5:Rec("SlimeKing", out - vec(8, 0, 0))
	local p5 = w5:Player(1, out + vec(0, 3, 0))
	check(C.ZoneAt(out).Id ~= "SlimeMeadow" and C.ZoneAt(out - vec(8, 0, 0)).Id == "SlimeMeadow", "setup: the zone edge")
	check(w5:Try(k5, p5) == false and k5._leap == nil, "a spot outside its zone: no leap")
end)

runGroup("slam", function()
	local C = leapWorld().Config
	local r = zoneCenter(C, "SkeletonRuins")
	local w = leapWorld()
	local cap = w:Rec("CaptainClatter", r)
	local p = w:Player(1, r + vec(4, 3, 0))
	local q = w:Player(2, r + vec(11.4, 3, 0))
	local far = w:Player(3, r + vec(11.6, 3, 0))
	check(w:Try(cap, p) == false and w:Try(cap, p) == false, "attacks 1 and 2: plain swings (false)")
	check(cap._slamCount == 2, "both counted", tostring(cap._slamCount))
	cap._nextAttackAt = w.Clock + 1
	check(w:Try(cap, p) == false and cap._slamCount == 2, "not ready: not counted")
	cap._nextAttackAt = 0
	w:Move(p, r + vec(6, 3, 0))
	check(w:Try(cap, p) == false and cap._slamCount == 2, "out of swing reach: not counted")
	w:Move(p, r + vec(4, 3, 0))
	check(w:Try(cap, p) == true and type(cap._leap) == "table" and cap._leap.Slam == true, "attack 3: the slam")
	local A = cap.Model.Attrs
	check(near(A.DropPos, r) and near(A.DropFrom, r) and A.DropHeight == 0 and A.DropRadius == 12 and #w.Pivots == 0,
		"around itself (DropPos = its feet), it does not move, radius 12", show(A))
	check(cap._nextAttackAt == w.Clock + C.Monsters.AttackCooldown, "the next attack a swing's cooldown later")
	w:Advance(1.01)
	local dmg = C.MonsterTypes.CaptainClatter.Damage * 2
	check(w:HitsOf(p) == 1 and w:HitsOf(q) == 1 and w:HitsOf(far) == 0 and w.Hits[1].Dmg == dmg,
		"everyone within 11.5 is hit for 2x his hit (" .. dmg .. "); 11.6 is not", tostring(#w.Hits))
	check(A.AttackSeq == 1, "the slam bumps AttackSeq (the swing clients play)")
end)

runGroup("gone before landing", function()
	local C = leapWorld().Config
	local m = zoneCenter(C, "SlimeMeadow")
	local function run(kill)
		local w = leapWorld()
		local king = w:Rec("SlimeKing", m)
		local p = w:Player(1, m + vec(5, 3, 0))
		w:Try(king, p)
		kill(w, king)
		w:Advance(1.01)
		return #w.Hits, king
	end
	check(run(function(_, k) k.Alive = false end) == 0, "killed during the warning: no hit")
	check(run(function(w, k) w.Records[k.Id] = nil end) == 0, "removed from the records: no hit")
	check(run(function(_, k) k.Model.Parent = nil end) == 0, "model gone: no hit")
	local n, king = run(function(_, k) k._leap = { Token = {} } end)
	check(n == 0 and king._leap ~= nil, "a newer landing replaced it: the old one does nothing")
end)

runGroup("switches and mult", function()
	local C0 = leapWorld().Config
	local m = zoneCenter(C0, "SlimeMeadow")
	local function tryWith(edit, kind)
		local w = leapWorld({ EditConfig = edit })
		local rec = w:Rec(kind or "SlimeKing", m)
		local p = w:Player(1, m + vec(3, 3, 0))
		return w:Try(rec, p), rec, w
	end
	check(tryWith(function(c) c.BossLeap.Enabled = false end) == false, "BossLeap.Enabled = false: plain swings")
	check(tryWith(function(c) c.BossLeap.Kinds.SlimeKing.Enabled = false end) == false, "a kind's Enabled = false: plain swings")
	check(tryWith(nil, "Slime") == false and tryWith(nil, "SkeletonKnight") == false, "other kinds: plain swings")
	local _, slow = tryWith(function(c) c.BossLeap.Kinds.SlimeKing.Cycle = 3 end)
	check(slow._leap.Mult == 2, "Cycle 3 s: x2 (3 / 1.5: standing still costs what the swings did)", tostring(slow._leap.Mult))
	local _, own = tryWith(function(c) c.BossLeap.Kinds.SlimeKing.Cycle = 3; c.BossLeap.Kinds.SlimeKing.Mult = 1.25 end)
	check(own._leap.Mult == 1.25, "an explicit Mult wins", tostring(own._leap.Mult))
	local _, short, ws = tryWith(function(c) c.BossLeap.Kinds.SlimeKing.Cycle = 0.2 end)
	check(math.abs(short._nextAttackAt - (ws.Clock + 1.1)) < 1e-9 and math.abs(short._leap.Mult - 1.1 / 1.5) < 1e-9,
		"a cycle never shorter than its warning + 0.1 (1.1 s, x1.1 / 1.5)", show({ short._nextAttackAt - ws.Clock, short._leap.Mult }))
	local _, big = tryWith(function(c) c.LandShadow.Radius.SlimeKing = 60 end)
	check(big.Model.Attrs.DropRadius == C0.LandShadow.MaxRadius, "the circle is clamped to the client's MaxRadius", tostring(big.Model.Attrs.DropRadius))
end)

finish()
