-- monster_spacing_offline.luau : A23-74 (user 2026-10-07 "그리고 점점 합쳐지겠다 야"): monsters keep a natural distance
-- from each other and from players. No monster part collides (TECH_SPEC: CanCollide = false), so MonsterService spaces
-- them itself: chasers walk to their own slot on a ring around the target (spread so neighbours stand rA + rB apart; a
-- full ring moves out to AttackRange - 0.5, the rest wait on further rings outside reach; the ring is centred where a
-- walking player will be next tick), in reach they stand for a swing and step on to their slot between swings, and
-- after every AI tick the end points of the coming walks are pushed apart (bodies touching at rA + rB, out of player
-- bodies; 3 rounds) and played as slides (at most 8 studs/s, the smaller one moves more, a boss never; a walking
-- monster's MoveTo point moves along), and new monsters (bosses too) spawn clear of living ones.
-- tools/test_monster_spacing.py binds CONFIG_SOURCE, MONSTER_SOURCE (text checks of the AI wiring), SPACING_EXTRACT (the
-- real SEP table and functions cut from the CURRENT MonsterService), SPAWN_EXTRACT (the real pickSpawnPoint, as in
-- test_tutorial_spawn) and EVENT_EXTRACT (the real MonsterService.SpawnEvent) in front of dev2_kit.luau. Roots, the
-- ground ray, walls, Humanoids and Random are doubles; the contract numbers (radii, rings, Overlap 1, 8 studs/s, 3
-- rounds, lead 0.25 s, 1.5 spawn gap, cell 8) are written here on purpose. Review probe 2026-10-07: a player walking at
-- 3 / 5 / 8 studs/s with 4 Shard Slimes + 2 King Slimes: mean deepest overlap per AI tick < 0.3 studs.

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local MC = C.Monsters
local MEADOW = C.Zones.SlimeMeadow
local EPS = 1e-6
local TAU = 2 * math.pi

local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

-- a root: Position / CFrame (root.CFrame + Vector3 moves it), Parent, Anchored
local cfmt = {}
local function cf(pos) return setmetatable({ Position = pos, __kind = "CFrame" }, cfmt) end
cfmt.__add = function(c, v) return cf(c.Position + v) end
local rootmt = {
	__index = function(r, k)
		if k == "Position" then return rawget(r, "_pos") end
		if k == "CFrame" then return cf(rawget(r, "_pos")) end
		return nil
	end,
	__newindex = function(r, k, v)
		if k == "CFrame" then
			rawset(r, "_pos", v.Position)
		elseif k == "Position" then
			rawset(r, "_pos", v)
		else
			rawset(r, k, v)
		end
	end,
}
local function newRoot(pos) return setmetatable({ _pos = pos, Parent = true, Anchored = false }, rootmt) end
-- a Humanoid: MoveTo stores the point (Reached = false until the walk gets there), WalkSpeed, AutoRotate
local humMeta = { __index = { MoveTo = function(h, p) h.Goal, h.Reached = p, false end } }
local function newHumanoid(speed) return setmetatable({ WalkSpeed = speed or 0, Parent = true, AutoRotate = true }, humMeta) end

-- one SEP per scenario. opts.Water = z: the ground south of it (z >= Water) is water; opts.Wall = x: a wall along x
local function spacingWorld(opts)
	opts = opts or {}
	local w = { Rays = 0, Ground = 0, Water = opts.Water, Wall = opts.Wall, NextId = 0, Pairs = 0 }
	local U = { Random = randomDouble({}).new() }
	function U.FlatDistance(a, b) return flat(a, b) end
	local H = { records = {} }
	H.workspace = { Raycast = function(_, origin, dir)
		w.Rays += 1
		if w.Wall and (origin.X - w.Wall) * (origin.X + dir.X - w.Wall) <= 0 then return { Position = origin } end
		return nil
	end }
	H.groundPoint = function(x, z)
		w.Ground += 1
		if w.Water and z >= w.Water then return nil, false end
		return vec(x, 0, z), false
	end
	H.getShoveParams = function() return {} end
	w.H = H
	w.SEP = execute("MonsterSpacing", SPACING_EXTRACT, nativeEnv(), C, U, H)
	local pair = w.SEP.Pair
	w.SEP.Pair = function(...) -- counts the pair tests (the grid must keep them few)
		w.Pairs += 1
		return pair(...)
	end
	return w
end

local function mon(w, kind, x, z, more)
	w.NextId += 1
	local def = C.MonsterTypes[kind]
	local pos = vec(x, 3, z)
	local rec = { Id = w.NextId, Kind = kind, Def = def, ZoneId = C.ZoneAt(pos).Id, Alive = true, Root = newRoot(pos),
		_radius = w.SEP.RadiusOf(def) }
	for k, v in more or {} do rec[k] = v end
	w.H.records[rec.Id] = rec
	return rec
end

local function list(w)
	local out = {}
	for _, rec in w.H.records do table.insert(out, rec) end
	table.sort(out, function(a, b) return a.Id < b.Id end)
	return out
end

local function playerAt(name, x, z) return { Player = { Name = name }, Pos = vec(x, 3, z), Town = false, Zone = "SlimeMeadow" } end

local function slotPoint(info, slot)
	return vec(info.Pos.X + math.cos(slot.Angle) * slot.Ring, 0, info.Pos.Z + math.sin(slot.Angle) * slot.Ring)
end

-- the closest flat pair distance minus what the two bodies need ((rA + rB) x factor); >= 0 = no overlap
local function worstPair(recs, factor, posOf)
	local worst, at = math.huge, nil
	for i = 1, #recs do
		for j = i + 1, #recs do
			local a, b = recs[i], recs[j]
			local d = flat(posOf(a), posOf(b)) - (a._radius + b._radius) * factor
			if d < worst then worst, at = d, a.Kind .. "#" .. a.Id .. "/" .. b.Kind .. "#" .. b.Id end
		end
	end
	return worst, at
end

local CX, CZ = MEADOW.Center.X, MEADOW.Center.Z

------------------------------------------------------------------ contract
runGroup("contract numbers", function()
	local SEP = spacingWorld().SEP
	check(SEP.Radius.Slime == 1.5 and SEP.Radius.Humanoid == 1.25, "body radius: slime ball 1.5 x Scale, humanoid 1.25 x Scale",
		show(SEP.Radius))
	check(SEP.PlayerRadius == 1 and SEP.RingGap == 1 and SEP.RingInside == 0.5, "ring = r + 1 (player) + 1, <= AttackRange - 0.5",
		show({ SEP.PlayerRadius, SEP.RingGap, SEP.RingInside }))
	check(SEP.Overlap == 1 and SEP.Speed == 8 and SEP.MinPush == 0.05 and SEP.Passes == 3,
		"review 2026-10-07: bodies pushed apart where they touch (rA + rB), slides at most 8 studs/s, 3 push rounds",
		show({ SEP.Overlap, SEP.Speed, SEP.MinPush, SEP.Passes }))
	check(SEP.Settle == 0.5 and SEP.Lead == 0.25 and SEP.LeadMax == 4,
		"in reach it stands within 0.5 of its slot; rings 0.25 s (at most 4 studs) ahead of a walking player",
		show({ SEP.Settle, SEP.Lead, SEP.LeadMax }))
	check(SEP.SpawnGap == 1.5 and SEP.Cell == 8, "spawn gap 1.5 studs, grid cell 8 studs", show({ SEP.SpawnGap, SEP.Cell }))
	local want = { Slime = 1.5, BigSlime = 2.7, PumpkinSlime = 1.65, Goblin = 1.25, GoblinBrute = 1.875, PumpkinKing = 3.75 }
	for kind, r in want do
		check(math.abs(SEP.RadiusOf(C.MonsterTypes[kind]) - r) < EPS, "RadiusOf " .. kind .. " = " .. r,
			SEP.RadiusOf(C.MonsterTypes[kind]))
	end
	check(SEP.RadiusOf(nil) == 1.5, "RadiusOf without a def: a slime's 1.5", SEP.RadiusOf(nil))
	-- every kind: the grid sees every overlap, the ring stands outside the player body and in reach
	local bad, maxR = {}, 0
	for kind, def in C.MonsterTypes do
		local r = SEP.RadiusOf(def)
		maxR = math.max(maxR, r)
		local ring = SEP.Ring({ _radius = r })
		if ring < r + SEP.PlayerRadius - EPS or ring > MC.AttackRange - SEP.RingInside + EPS then
			table.insert(bad, kind .. "=" .. ring)
		end
	end
	check(#bad == 0, "every kind's ring is outside the player body (>= r + 1) and in reach (<= AttackRange - 0.5)", show(bad))
	check(2 * maxR * SEP.Overlap <= SEP.Cell and (maxR + SEP.PlayerRadius) * SEP.Overlap <= SEP.Cell,
		"the biggest pair / player overlap fits in one grid cell (neighbour cells see every overlap)", maxR)
	check(math.abs(SEP.Ring({ _radius = 1.5 }) - 3.5) < EPS and math.abs(SEP.Ring({ _radius = 2.7 }) - 4.7) < EPS
		and math.abs(SEP.Ring({ _radius = 3.75 }) - (MC.AttackRange - 0.5)) < EPS,
		"rings: Shard Slime 3.5, King Slime 4.7, Pumpkin King capped at AttackRange - 0.5",
		show({ SEP.Ring({ _radius = 1.5 }), SEP.Ring({ _radius = 2.7 }), SEP.Ring({ _radius = 3.75 }) }))
end)

------------------------------------------------------------------ chase slots
runGroup("chase slots", function()
	-- the screenshot: a Shard Slime, a King Slime and a Pumpkin Slime all coming from the same spot
	local w = spacingWorld()
	local info = playerAt("kid", CX, CZ)
	local a = mon(w, "Slime", CX, CZ - 12, { _target = info.Player })
	local b = mon(w, "BigSlime", CX, CZ - 12, { _target = info.Player })
	local c = mon(w, "PumpkinSlime", CX, CZ - 12, { _target = info.Player })
	w.SEP.Begin(list(w), { info })
	local S = w.SEP.Slots
	check(S[a] and S[b] and S[c] and S[a].Player == info.Player and S[b].Player == info.Player and S[c].Player == info.Player,
		"three chasers of one player get a slot each", show({ S[a] ~= nil, S[b] ~= nil, S[c] ~= nil }))
	if S[a] and S[b] and S[c] then
		local worst, at = worstPair({ a, b, c }, 1, function(r) return slotPoint(info, S[r]) end)
		check(worst >= -1e-3, "their slots stand rA + rB apart (no body touches another)", show({ worst, at }))
		local off = {}
		for _, r in { a, b, c } do
			local dp = flat(slotPoint(info, S[r]), info.Pos)
			if dp < r._radius + w.SEP.PlayerRadius - EPS or dp > MC.AttackRange + EPS then table.insert(off, r.Kind .. "=" .. dp) end
			local da = math.abs(((S[r].Angle - (-math.pi / 2)) + math.pi) % TAU - math.pi)
			if da > math.rad(100) then table.insert(off, r.Kind .. " turned " .. math.deg(da)) end
		end
		check(#off == 0, "every slot is outside the player body, in reach, on the monsters' own side (no lap around)", show(off))
		local g = w.SEP.Goal(a, info)
		check(flat(g, slotPoint(info, S[a])) < 1e-6 and g.Y == 0, "Goal = the slot point on the ground", show({ g.X, g.Z }))
		check(flat(w.SEP.Goal(a, info), info.Pos) > 3, "nobody walks into the player any more (old chase: the player's position)",
			flat(w.SEP.Goal(a, info), info.Pos))
	end

	-- monsters already apart keep their angles
	w = spacingWorld()
	local e = mon(w, "Slime", CX + 10, CZ, { _target = info.Player })
	local o = mon(w, "Slime", CX - 10, CZ, { _target = info.Player })
	w.SEP.Begin(list(w), { info })
	check(math.abs(w.SEP.Slots[e].Angle - 0) < 1e-6 and math.abs(math.abs(w.SEP.Slots[o].Angle) - math.pi) < 1e-6,
		"two slimes on opposite sides keep their own angles", show({ w.SEP.Slots[e].Angle, w.SEP.Slots[o].Angle }))

	-- no slot (a new target this tick): its own side at its ring; a slot on water: the old chase (the player's spot)
	w = spacingWorld()
	local fresh = mon(w, "Slime", CX + 15, CZ)
	w.SEP.Begin(list(w), { info })
	local g = w.SEP.Goal(fresh, info)
	check(w.SEP.Slots[fresh] == nil and math.abs(g.X - (CX + 3.5)) < 1e-6 and math.abs(g.Z - CZ) < 1e-6,
		"a monster without a slot walks to its own side at its ring distance", show({ g.X, g.Z }))
	w = spacingWorld({ Water = CZ + 2 })
	local south = mon(w, "Slime", CX, CZ + 12, { _target = info.Player })
	w.SEP.Begin(list(w), { info })
	g = w.SEP.Goal(south, info)
	check(flat(g, info.Pos) < 1e-6, "a slot over water falls back to the player's position (never into the water)", show({ g.X, g.Z }))

	-- who chases: personal monsters near their owner, not far ones; returning / dead / anchored ones never
	w = spacingWorld()
	local near = mon(w, "Slime", CX + 10, CZ, { Owner = info.Player })
	local far = mon(w, "Slime", CX + 100, CZ, { Owner = info.Player })
	local back = mon(w, "Slime", CX - 10, CZ, { _target = info.Player, _returning = true })
	local dead = mon(w, "Slime", CX, CZ + 10, { _target = info.Player, Alive = false })
	local stuck = mon(w, "Slime", CX, CZ - 10, { _target = info.Player })
	stuck.Root.Anchored = true
	w.SEP.Begin(list(w), { info })
	check(w.SEP.Slots[near] ~= nil, "a personal monster near its owner gets a slot")
	check(w.SEP.Slots[far] == nil, "a personal monster beyond its follow radius gets none (it stands)")
	check(w.SEP.Slots[back] == nil, "a monster walking home gets none")
	check(w.SEP.Slots[dead] == nil and w.SEP.Slots[stuck] == nil and #w.SEP.Live == 3,
		"a dead or anchored (dying) monster is left out", #w.SEP.Live)
	local other = playerAt("other", CX + 60, CZ)
	w = spacingWorld()
	local x1 = mon(w, "Slime", CX + 50, CZ, { _target = other.Player })
	w.SEP.Begin(list(w), { info })
	check(w.SEP.Slots[x1] == nil, "a target that is not in the player list gives no slot")
end)

runGroup("ring capacity", function()
	-- chasers coming from one side (closest first); the review 2026-10-07: the inner ring holds as many as fit IN REACH
	-- (moving out to AttackRange - 0.5 when they do not fit at r + 2), the rest wait on further rings outside reach, any
	-- number of them without overlap
	local info = playerAt("kid", CX, CZ)
	local wide = MC.AttackRange - 0.5
	local function ringOf(kinds)
		local w = spacingWorld()
		local all = {}
		for i, kind in kinds do
			table.insert(all, mon(w, kind, CX + (i % 3) * 0.3, CZ - 9 - i, { _target = info.Player }))
		end
		w.SEP.Begin(list(w), { info })
		local inner, outer = {}, {}
		for _, r in all do
			local s = w.SEP.Slots[r]
			if s and s.Ring <= MC.AttackRange then table.insert(inner, r) elseif s then table.insert(outer, r) end
		end
		return w, all, inner, outer
	end
	local function rep(kind, n, out)
		out = out or {}
		for _ = 1, n do table.insert(out, kind) end
		return out
	end
	local function ringsOf(w, recs)
		local rings = {}
		for _, r in recs do rings[w.SEP.Slots[r].Ring] = (rings[w.SEP.Slots[r].Ring] or 0) + 1 end
		return rings
	end
	-- 7 slimes fit on their own ring (2 asin(3/7) = 50.8 deg each): they keep it (3.5)
	local w, all, inner, outer = ringOf(rep("Slime", 7))
	local rings = ringsOf(w, all)
	check(#inner == 7 and #outer == 0 and rings[3.5] == 7, "7 slimes: all on their own ring r + 2 = 3.5", show(rings))
	-- 10 slimes do not fit at 3.5: the ring moves out to 5.0 and all ten attack (2 asin(3/10) = 34.9 deg each)
	w, all, inner, outer = ringOf(rep("Slime", 10))
	rings = ringsOf(w, all)
	check(#inner == 10 and #outer == 0 and rings[wide] == 10, "10 slimes: all ten in reach on the ring AttackRange - 0.5",
		show(rings))
	local posOf = function(r) return slotPoint(info, w.SEP.Slots[r]) end
	local worst, at = worstPair(all, 1, posOf)
	check(worst >= -1e-3, "the widened ring: every pair rA + rB apart", show({ worst, at }))
	-- 12 slimes: the 10 closest attack, 2 wait on the next ring just outside the inner bodies (5 + 1.5 + 1 + 1.5 = 9)
	w, all, inner, outer = ringOf(rep("Slime", 12))
	local closest = #inner == 10
	for i = 1, 10 do
		if not table.find(inner, all[i]) then closest = false end
	end
	rings = ringsOf(w, all)
	check(closest and #outer == 2 and rings[wide] == 10 and rings[9] == 2,
		"12 slimes: the 10 closest in reach, 2 waiting on the ring at 9 (outside reach)", show(rings))
	posOf = function(r) return slotPoint(info, w.SEP.Slots[r]) end
	worst, at = worstPair(all, 1, posOf)
	check(worst >= -1e-3, "12 slimes: no slot touches another (across rings too)", show({ worst, at }))
	-- mixed: 6 King Slimes closest (5 fit in reach: 2 asin(5.4/10) = 65.4 deg each), then 4 slimes: the next ring
	-- starts outside the King Slimes' bodies (5 + 2.7 + 1 = 8.7, slime centres at 10.2, the 6th King Slime at 11.4)
	w, all, inner, outer = ringOf(rep("Slime", 4, rep("BigSlime", 6)))
	local edgeOk, kingsIn = true, 0
	for _, r in all do
		local s = w.SEP.Slots[r]
		if s.Ring <= MC.AttackRange then
			if r.Kind == "BigSlime" then kingsIn += 1 end
		elseif math.abs(s.Ring - (wide + 2.7 + 1 + r._radius)) > 1e-6 then
			edgeOk = false
		end
	end
	check(kingsIn == 5 and #inner == 5 and edgeOk, "mixed: 5 King Slimes in reach, every waiting ring starts outside their bodies",
		show({ kingsIn, #inner, ringsOf(w, all) }))
	posOf = function(r) return slotPoint(info, w.SEP.Slots[r]) end
	worst, at = worstPair(all, 1, posOf)
	check(worst >= -1e-3, "mixed: no slot touches another", show({ worst, at }))
	-- 30 slimes on one player: 10 + 18 + 2 on rings 5, 9 and 13, none touching
	w, all, inner, outer = ringOf(rep("Slime", 30))
	rings = ringsOf(w, all)
	check(rings[wide] == 10 and rings[9] == 18 and rings[13] == 2, "30 slimes: rings of 10 (in reach), 18 and 2", show(rings))
	posOf = function(r) return slotPoint(info, w.SEP.Slots[r]) end
	worst, at = worstPair(all, 1, posOf)
	check(worst >= -1e-3, "30 slimes: no slot touches another", show({ worst, at }))
	local waitOk = true
	for _, r in outer do
		if w.SEP.Slots[r].Ring <= MC.AttackRange then waitOk = false end
	end
	check(waitOk and #outer == 20, "the waiting ones stand outside AttackRange (they do not attack until a place frees)", #outer)
end)

runGroup("ring packing", function()
	-- seeded random rings (mixed body sizes, piled-up and spread angles): whenever the ring has room (Need <= 2 pi) every
	-- pair of slots ends rA + rB apart, the order around the player never changes, and nobody laps the player
	local SEP = spacingWorld().SEP
	local seed = 20261007
	local function rnd()
		seed = (seed * 48271) % 2147483647
		return (seed - 1) / 2147483646
	end
	local sizes = { 1.5, 1.65, 2.7, 1.25, 1.875, 3.75 }
	local spots = { 0, 0.3, 3, -2 }
	local cases, bad, reordered, worst, firstBad = 0, 0, 0, math.huge, nil
	for _ = 1, 4000 do
		local n = 2 + math.floor(rnd() * 8)
		local ring = {}
		for i = 1, n do
			local rad = sizes[1 + math.floor(rnd() * #sizes)]
			local mode = rnd()
			local a
			if mode < 0.4 then
				a = spots[1 + math.floor(rnd() * #spots)] + (rnd() - 0.5) * 0.4
			elseif mode < 0.6 then
				a = 1 -- exact ties
			else
				a = (rnd() * 2 - 1) * math.pi
			end
			table.insert(ring, { Id = i, A = a, R = SEP.Ring({ _radius = rad }), Rad = rad })
		end
		if SEP.Need(ring) <= TAU then
			cases += 1
			local before = table.clone(ring)
			table.sort(before, SEP.Before)
			SEP.Spread(ring)
			local w = math.huge
			for i = 1, n do
				for j = i + 1, n do
					local a, b = ring[i], ring[j]
					local d = math.sqrt(a.R * a.R + b.R * b.R - 2 * a.R * b.R * math.cos(a.A - b.A))
					w = math.min(w, d - (a.Rad + b.Rad))
				end
			end
			worst = math.min(worst, w)
			if w < -1e-3 then
				bad += 1
				firstBad = firstBad or show(before)
			end
			-- cyclic order kept: walking the result by angle visits `before` as a rotation
			local after = table.clone(ring)
			table.sort(after, SEP.Before)
			local start = table.find(after, before[1])
			for k = 1, n do
				if after[(start + k - 2) % n + 1] ~= before[k] then
					reordered += 1
					break
				end
			end
		end
	end
	-- four monsters on one angle given in the order 3, 1, 4, 2: Need adds the gaps of the ring order Spread uses
	-- (ties by id: 1-2, 2-3, 3-4, 4-1), not of the order they came in
	local tie = {}
	for _, id in { 3, 1, 4, 2 } do
		local rad = (id % 2 == 1) and 1.5 or 3.75
		table.insert(tie, { Id = id, A = 0.5, R = SEP.Ring({ _radius = rad }), Rad = rad })
	end
	local byId = {}
	for _, e in tie do byId[e.Id] = e end
	local want = SEP.Gap(byId[1], byId[2]) + SEP.Gap(byId[2], byId[3]) + SEP.Gap(byId[3], byId[4]) + SEP.Gap(byId[4], byId[1])
	check(math.abs(SEP.Need(tie) - want) < 1e-9, "Need walks the same neighbours as Spread (ties by id)", show({ SEP.Need(tie), want }))
	check(cases > 1500, "enough feasible random rings", cases)
	check(bad == 0, "every feasible ring: all slots rA + rB apart", show({ bad, worst, firstBad }))
	check(reordered == 0, "the order around the player never changes", reordered)
end)

------------------------------------------------------------------ a walking player (review 2026-10-07)
runGroup("lead", function()
	local w = spacingWorld()
	local info = playerAt("kid", CX, CZ)
	local ax, az = w.SEP.Ahead(info)
	check(ax == CX and az == CZ, "no Vel: rings and the body push are centred on the player", show({ ax, az }))
	info.Vel = vec(8, 0, 0)
	ax, az = w.SEP.Ahead(info)
	check(math.abs(ax - (CX + 2)) < EPS and az == CZ, "walking 8 studs/s: centred 0.25 s (2 studs) ahead", show({ ax - CX, az - CZ }))
	info.Vel = vec(0, -50, 40)
	ax, az = w.SEP.Ahead(info)
	check(ax == CX and math.abs(az - (CZ + 4)) < EPS, "running 40 studs/s and falling: at most 4 studs ahead, height ignored",
		show({ ax - CX, az - CZ }))
	-- a chaser behind a player walking +x at 8 studs/s heads for its slot on the ring 2 studs ahead
	w = spacingWorld()
	info = playerAt("kid", CX, CZ)
	info.Vel = vec(8, 0, 0)
	local r = mon(w, "Slime", CX - 10, CZ, { _target = info.Player })
	w.SEP.Begin(list(w), { info })
	local g = w.SEP.Goal(r, info)
	check(math.abs(g.X - (CX + 2 - 3.5)) < 1e-6 and math.abs(g.Z - CZ) < 1e-6,
		"the chase slot moves with a walking player (ring centred where it will be)", show({ g.X - CX, g.Z - CZ }))
	-- the body push looks where the player will be: a slime standing 3 studs in front of a player walking at it at
	-- 8 studs/s (no overlap now) slides on 1.5 studs before the player gets there
	w = spacingWorld()
	local front = mon(w, "Slime", CX + 3, CZ)
	w.SEP.Begin(list(w), { info })
	w.SEP.Resolve({ info })
	local p = w.SEP.Push[front]
	check(p ~= nil and math.abs(p.Delta.X - 1.5) < 1e-6, "a slime in front of a walking player slides on before the player reaches it",
		p and p.Delta.X)
end)

runGroup("reach walk", function()
	-- in reach (attack()): stand for the swing, step on to the ring slot between swings, never into the player
	local w = spacingWorld()
	local SEP = w.SEP
	local info = playerAt("kid", CX, CZ)
	local r = mon(w, "Slime", CX - 5, CZ, { _nextAttackAt = 10 })
	local pos = r.Root.Position
	local slot = vec(CX, 0, CZ - 3.5)
	check(SEP.ReachGoal(r, 5, pos, slot, info) == slot, "between swings (cooldown running, no wind-up): it steps to its slot")
	r._windup = {}
	check(SEP.ReachGoal(r, 5, pos, slot, info) == nil, "while its wind-up is pending it stands")
	r._windup = nil
	check(SEP.ReachGoal(r, 10, pos, slot, info) == nil, "cooldown up (a wind-up starts this tick): it stands")
	check(SEP.ReachGoal(r, 5, slot + vec(0.4, 3, 0), slot, info) == nil, "within Settle (0.5) of its slot it stands")
	check(SEP.ReachGoal(r, 5, slot + vec(0.6, 3, 0), slot, info) == slot, "0.6 from its slot it still steps there")
	local inBody = vec(CX + 2.4, 0, CZ)
	check(SEP.ReachGoal(r, 5, pos, inBody, info) == nil, "a slot inside the player body (a water / zone-edge fallback): it stands")
	check(SEP.ReachGoal(r, 5, pos, vec(CX + 2.6, 0, CZ), info) ~= nil, "a slot just outside the player body is fine")
	check(SEP.ReachGoal(r, 5, pos, nil, info) == nil, "no slot: it stands")
	-- a player walking +x at 8 studs/s: a rear slot 1.5 studs behind where it stands now is 3.5 behind where it will be
	local walking = playerAt("kid", CX, CZ)
	walking.Vel = vec(8, 0, 0)
	local rear = vec(CX - 1.5, 0, CZ)
	check(SEP.ReachGoal(r, 5, pos, rear, walking) == rear, "a walking player's rear slot: it keeps stepping (the body is taken ahead)")
	check(SEP.ReachGoal(r, 5, pos, vec(CX + 2.5, 0, CZ), walking) == nil, "a slot inside where a walking player will be: it stands")
	-- AutoRotate: off only while in reach this tick (FACE turns the body, also while it steps sideways)
	local hum = newHumanoid(10)
	r.Humanoid = hum
	r._inReach = true
	SEP.Rotate(r)
	check(hum.AutoRotate == false and r._inReach == nil, "in reach: AutoRotate off, the mark used up", show({ hum.AutoRotate, r._inReach }))
	SEP.Rotate(r)
	check(hum.AutoRotate == true, "out of reach the next tick: AutoRotate back on (it faces where it walks)")
	r.Humanoid = nil
	r._inReach = true
	local ok = pcall(SEP.Rotate, r)
	check(ok and r._inReach == nil, "no Humanoid: nothing to turn, no error")
end)

runGroup("walk prediction", function()
	local w = spacingWorld()
	local r = mon(w, "Slime", CX, CZ)
	r.Humanoid = newHumanoid(10)
	w.SEP.Begin(list(w), {})
	local q = w.SEP.Walk(r)
	check(q.X == CX and q.Z == CZ, "no walk this tick: it ends where it stands")
	r._walkTo = vec(CX + 10, 0, CZ)
	q = w.SEP.Walk(r)
	check(math.abs(q.X - (CX + 2.5)) < 1e-9 and q.Z == CZ and q.Y == 3, "walking 10 studs/s: 2.5 studs on by the end of the tick",
		show({ q.X - CX, q.Y }))
	r._walkTo = vec(CX + 1, 0, CZ)
	q = w.SEP.Walk(r)
	check(math.abs(q.X - (CX + 1)) < 1e-9, "a MoveTo point closer than a tick's walk: it ends there", q.X - CX)
	w.SEP.Begin(list(w), {})
	check(r._walkTo == nil, "every tick starts standing (this tick's step sets its walk again)")
	-- a chaser walking into a slime that stands: 5 studs apart now, 2.5 at the end of the tick (need 3): both slide
	-- 0.25 apart now, and the walker's MoveTo point moves with it (a Humanoid would walk a slide back otherwise)
	w = spacingWorld()
	local stand = mon(w, "Slime", CX, CZ)
	local walker = mon(w, "Slime", CX - 5, CZ)
	w.SEP.Begin(list(w), {})
	walker.Humanoid = newHumanoid(10)
	walker._walkTo = vec(CX + 5, 0, CZ)
	walker.Humanoid:MoveTo(walker._walkTo)
	stand.Humanoid = newHumanoid(10)
	w.SEP.Resolve({})
	local pw, ps = w.SEP.Push[walker], w.SEP.Push[stand]
	check(pw and ps and math.abs(pw.Delta.X + 0.25) < 1e-9 and math.abs(ps.Delta.X - 0.25) < 1e-9,
		"a walker and the slime it walks into are held apart before the bodies meet",
		show({ pw and pw.Delta.X, ps and ps.Delta.X }))
	check(math.abs(walker._walkTo.X - (CX + 4.75)) < 1e-9 and walker.Humanoid.Goal == walker._walkTo,
		"the walker's MoveTo point moves along with its slide", show({ walker._walkTo.X - CX }))
	check(stand.Humanoid.Goal == nil, "a standing monster gets no MoveTo (it just slides)")
	-- a slide whose MoveTo point would leave the zone keeps the old point (the slide itself is checked from the body)
	w = spacingWorld({ Water = CZ + 10 })
	local a1 = mon(w, "Slime", CX, CZ + 4)
	local b1 = mon(w, "Slime", CX, CZ + 2)
	w.SEP.Begin(list(w), {})
	a1.Humanoid = newHumanoid(0)
	a1._walkTo = vec(CX, 0, CZ + 9.5)
	w.SEP.Resolve({})
	check(w.SEP.Push[a1] ~= nil and a1._walkTo.Z == CZ + 9.5, "a MoveTo point that would slide into the water stays put",
		show({ w.SEP.Push[a1] ~= nil, a1._walkTo.Z - CZ }))
	check(w.SEP.Push[b1] ~= nil, "(its partner slides too)")
	-- three in a row (each pair 2 apart, need 3): one push round leaves the first pair 0.75 inside each other, three
	-- rounds leave under 0.1
	w = spacingWorld()
	local x1 = mon(w, "Slime", CX, CZ)
	local x2 = mon(w, "Slime", CX + 2, CZ)
	local x3 = mon(w, "Slime", CX + 4, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	w.SEP.Step(MC.AIInterval)
	local worst = worstPair({ x1, x2, x3 }, 1, function(rr) return rr.Root.Position end)
	check(worst > -0.1, "three in a row: the push rounds clear the chain in one tick (< 0.1 left)", worst)
end)

runGroup("slide apart", function()
	local maxStep = 8 * MC.AIInterval
	-- two slimes 1 stud apart: each moves away from the other, the same amount, the whole overlap in one tick
	local w = spacingWorld()
	local a = mon(w, "Slime", CX, CZ)
	local b = mon(w, "Slime", CX + 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	local pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and math.abs(pa.Delta.X + 1) < 1e-9 and math.abs(pb.Delta.X - 1) < 1e-9,
		"two overlapping slimes slide apart, equally, the whole overlap (1 each) in one tick",
		show({ pa and pa.Delta.X, pb and pb.Delta.X }))
	-- a deep push is capped: a slime 1 stud from a boss needs 4.25 -> 8 studs/s x AIInterval = 2 per tick
	w = spacingWorld()
	local boss = mon(w, "PumpkinKing", CX, CZ, { ZoneId = "SlimeMeadow" })
	a = mon(w, "Slime", CX + 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	pa = w.SEP.Push[a]
	check(pa and math.abs(pa.Delta.X - maxStep) < 1e-9 and w.SEP.Push[boss] == nil, "a deep push slides at most 8 studs/s (2 per tick)",
		pa and pa.Delta.X)
	-- a small overlap is closed exactly (half each)
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ)
	b = mon(w, "Slime", CX + 2.8, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and math.abs(pa.Delta.X + 0.1) < 1e-9 and math.abs(pb.Delta.X - 0.1) < 1e-9,
		"2.8 studs apart (need 3): each slides 0.1", show({ pa and pa.Delta.X, pb and pb.Delta.X }))
	-- far enough: nothing
	w = spacingWorld()
	mon(w, "Slime", CX, CZ)
	mon(w, "Slime", CX + 3.1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(next(w.SEP.Push) == nil, "3.1 studs apart: no slide (only real overlaps move)")
	-- the smaller one moves more; a boss never moves
	w = spacingWorld()
	local s = mon(w, "Slime", CX, CZ)
	local k = mon(w, "BigSlime", CX + 3.6, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	local ps, pk = w.SEP.Push[s], w.SEP.Push[k]
	check(ps and pk and math.abs(ps.Delta.X / pk.Delta.X + 2.7 / 1.5) < 1e-6,
		"Shard Slime vs King Slime: the small one slides 2.7 / 1.5 times as far", show({ ps and ps.Delta.X, pk and pk.Delta.X }))
	w = spacingWorld()
	local king = mon(w, "PumpkinKing", CX, CZ, { ZoneId = "SlimeMeadow" })
	s = mon(w, "Slime", CX + 4, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(w.SEP.Push[king] == nil and w.SEP.Push[s] ~= nil and math.abs(w.SEP.Push[s].Delta.X - 1.25) < 1e-9,
		"a boss never slides; the slime next to it takes the whole slide", show({ w.SEP.Push[king] ~= nil, w.SEP.Push[s] ~= nil }))
	-- right on top of each other: still separated, the same way every time
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ)
	b = mon(w, "Slime", CX, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and math.abs(pa.Delta.X + pb.Delta.X) < 1e-9 and math.abs(pa.Delta.Z + pb.Delta.Z) < 1e-9
		and pa.Delta.Magnitude > 0.1, "two slimes on the same spot slide apart (a fixed direction per pair)",
		show({ pa and pa.Delta.Magnitude }))
	-- inside a player body: slides out; standing on its ring: stays
	w = spacingWorld()
	local info = playerAt("kid", CX, CZ)
	local inside = mon(w, "Slime", CX + 1, CZ)
	local ringed = mon(w, "Slime", CX - 3.5, CZ)
	w.SEP.Begin(list(w), { info })
	w.SEP.Resolve({ info })
	check(w.SEP.Push[inside] and math.abs(w.SEP.Push[inside].Delta.X - 1.5) < 1e-9,
		"a slime inside the player body slides out, away from the player (to r + 1)", w.SEP.Push[inside] and w.SEP.Push[inside].Delta.X)
	check(w.SEP.Push[ringed] == nil, "a slime on its ring is left alone")
	w = spacingWorld()
	king = mon(w, "PumpkinKing", CX + 1, CZ, { ZoneId = "SlimeMeadow" })
	w.SEP.Begin(list(w), { info })
	w.SEP.Resolve({ info })
	check(w.SEP.Push[king] == nil, "a boss is never slid by a player")
end)

runGroup("slide rules", function()
	local function pairAt(opts, x, z)
		local w = spacingWorld(opts)
		local a = mon(w, "Slime", x, z)
		local b = mon(w, "Slime", x - 1, z)
		w.SEP.Begin(list(w), {})
		return w, a, b
	end
	-- water: a slide that would end in the water is refused (a and b split along z; water south of z)
	local w = spacingWorld({ Water = CZ + 1 })
	local a = mon(w, "Slime", CX, CZ)
	local b = mon(w, "Slime", CX, CZ + 0.8)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(w.SEP.Push[a] ~= nil and w.SEP.Push[b] == nil, "no slide into the water (the dry one still moves)",
		show({ w.SEP.Push[a] ~= nil, w.SEP.Push[b] ~= nil }))
	-- the zone edge: a zone monster stays ZONE_MOVE_INSET inside its rect
	local edge = MEADOW.Center.X + MEADOW.Size.X / 2 - 6.2
	w, a, b = pairAt(nil, edge, CZ)
	w.SEP.Resolve({})
	check(w.SEP.Push[a] == nil and w.SEP.Push[b] ~= nil, "no slide past the zone's move inset",
		show({ w.SEP.Push[a] ~= nil, w.SEP.Push[b] ~= nil }))
	-- a wall right behind it
	w, a, b = pairAt({ Wall = CX + 0.3 }, CX, CZ)
	w.SEP.Resolve({})
	check(w.SEP.Push[a] == nil, "no slide through a wall / decor at body height", w.SEP.Push[a] ~= nil)
	-- the half step is tried when the full one is blocked
	w, a, b = pairAt({ Wall = CX + 1.2 }, CX, CZ) -- the full 1.0 (+0.5 probe) hits it, the half 0.5 does not
	w.SEP.Resolve({})
	check(w.SEP.Push[a] and math.abs(w.SEP.Push[a].Delta.X - 0.5) < 1e-9, "a blocked full slide falls back to half",
		w.SEP.Push[a] and w.SEP.Push[a].Delta.X)
	-- moved since the snapshot (pivotHome this tick): no slide from stale positions
	w, a, b = pairAt(nil, CX, CZ)
	a.Root.Position = vec(CX + 30, 3, CZ)
	w.SEP.Resolve({})
	check(w.SEP.Push[a] == nil, "a monster teleported during the tick is not slid")
	-- tiny overlaps do not jitter
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ)
	b = mon(w, "Slime", CX + 2.92, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(next(w.SEP.Push) == nil, "an overlap under MinPush (0.05) is ignored (no jitter)")
	-- personal monsters: any ground in the zone they stand in
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ, { Owner = { Name = "kid" }, ZoneId = "SlimeMeadow" })
	b = mon(w, "Slime", CX - 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(w.SEP.Push[a] ~= nil and w.SEP.Push[b] ~= nil, "a personal monster and a zone monster slide apart too")
end)

runGroup("smooth slide", function()
	local w = spacingWorld()
	local a = mon(w, "Slime", CX, CZ)
	local b = mon(w, "Slime", CX + 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	local dx = w.SEP.Push[a].Delta.X
	w.SEP.Step(MC.AIInterval / 2)
	check(math.abs(a.Root.Position.X - (CX + dx / 2)) < 1e-9, "half the tick: half the slide (smooth, not a snap)",
		a.Root.Position.X - CX)
	w.SEP.Step(MC.AIInterval)
	check(math.abs(a.Root.Position.X - (CX + dx)) < 1e-9 and w.SEP.Push[a] == nil,
		"the slide ends exactly at its Delta within one AI tick, then stops", a.Root.Position.X - CX)
	w.SEP.Step(1)
	check(math.abs(a.Root.Position.X - (CX + dx)) < 1e-9, "no further motion after it ended")
	-- a monster that died / got anchored mid-slide is dropped without moving
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ)
	b = mon(w, "Slime", CX + 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	a.Alive = false
	b.Root.Anchored = true
	w.SEP.Step(0.1)
	check(a.Root.Position.X == CX and b.Root.Position.X == CX + 1 and next(w.SEP.Push) == nil,
		"a dead / dying monster never slides")
end)

runGroup("grid cost", function()
	-- 100 monsters on a 10 x 10 lattice 9 studs apart: no overlaps, and only grid neighbours are tested (each pair once)
	local w = spacingWorld()
	for i = 0, 9 do
		for j = 0, 9 do
			mon(w, "Slime", CX - 45 + i * 9, CZ - 45 + j * 9)
		end
	end
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(next(w.SEP.Push) == nil, "a spread-out zone: nobody slides")
	check(w.Pairs <= 100 * 9 / 2, "pair tests stay near n x neighbours / 2 (never every pair, each pair once)", w.Pairs)
	check(w.Rays == 0 and w.Ground == 0, "no ray is cast when nothing overlaps", show({ w.Rays, w.Ground }))
	-- an overlap across a cell border is still found
	w = spacingWorld()
	local cell = w.SEP.Cell
	local bx = math.floor(CX / cell) * cell
	local a = mon(w, "Slime", bx - 0.5, CZ)
	local b = mon(w, "Slime", bx + 0.5, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(w.SEP.Push[a] ~= nil and w.SEP.Push[b] ~= nil, "two slimes on both sides of a cell border slide apart")
	local info = playerAt("kid", bx + 0.4, CZ + 0.2)
	w = spacingWorld()
	a = mon(w, "Slime", bx - 0.5, CZ)
	w.SEP.Begin(list(w), { info })
	w.SEP.Resolve({ info })
	check(w.SEP.Push[a] ~= nil and w.SEP.Push[a].Delta.X < 0, "a player across a cell border still pushes the slime out")
end)

------------------------------------------------------------------ simulation
-- A stand-in for the AI around the real SEP passes, one AI tick (AIInterval) at a time: SEP.Begin; per monster out of
-- reach -> walk to SEP.Goal (aiStep's chase); in reach -> attack()'s bookkeeping (a wind-up starts when the cooldown is
-- up and lasts MonsterWindup s; the hit clears it) and a walk to SEP.ReachGoal (nil = stand); each walk sets _walkTo and
-- NATURAL.Pace's WalkSpeed (Def.Speed x 0.45 from standing, +0.3 per walking tick) and calls Humanoid:MoveTo like
-- steer() / attack(); SEP.Resolve (it may move a MoveTo point along with a slide); then SUB physics frames: the player
-- walks info.Path, every monster walks to its MoveTo point at its WalkSpeed (like a Humanoid: from wherever the slide
-- put it, and not again once it got there) and SEP.Step plays the slides. opts.Old = the old in-reach rule (stand
-- still in AttackRange, no walk prediction); opts.Measure(now) runs at every AI tick before the passes.
local WINDUP = C.HitReact.MonsterWindup
local SUB = 8
local function simulate(w, info, recs, ticks, opts)
	opts = opts or {}
	local dt = MC.AIInterval
	for tick = 1, ticks do
		local now = (tick - 1) * dt
		if info.Path then -- aiTick's plist: Pos and Vel (the root's AssemblyLinearVelocity) at the tick
			info.Pos = info.Path(now)
			info.Vel = (info.Path(now + 0.01) - info.Pos) * 100
		end
		if opts.Measure then opts.Measure(now) end
		w.SEP.Begin(recs, { info })
		for _, r in recs do
			if r._windupEnd and now >= r._windupEnd then r._windup, r._windupEnd = nil, nil end
			local pos = r.Root.Position
			r._ramp = (r._walked or 0) < 0.5 * dt and 0 or (r._ramp or 0) + 1
			r._walked = 0
			r._target = info.Player
			local walk
			if flat(pos, info.Pos) <= MC.AttackRange then
				local slot = w.SEP.Goal(r, info)
				walk = (not opts.Old) and w.SEP.ReachGoal(r, now, pos, slot, info) or nil
				if r._windup == nil and now >= (r._nextAttackAt or 0) then
					r._nextAttackAt = now + MC.AttackCooldown
					r._windup, r._windupEnd = {}, now + WINDUP
					r._swings = (r._swings or 0) + 1
				end
				r._reachTicks = (r._reachTicks or 0) + 1
			else
				walk = w.SEP.Goal(r, info)
			end
			r.Humanoid = r.Humanoid or newHumanoid()
			r.Humanoid.WalkSpeed = r.Def.Speed * math.min(1, 0.45 + 0.3 * r._ramp)
			r._walkTo = (not opts.Old) and walk or nil
			r.Humanoid:MoveTo(walk or pos)
		end
		w.SEP.Resolve({ info })
		for k = 1, SUB do
			if info.Path then info.Pos = info.Path(now + k * dt / SUB) end
			for _, r in recs do
				local h = r.Humanoid
				if not h.Reached then -- a Humanoid stops once it reached its MoveTo point (a later slide stays)
					local pos = r.Root.Position
					local to = vec(h.Goal.X - pos.X, 0, h.Goal.Z - pos.Z)
					local m = to.Magnitude
					local step = math.min(m, h.WalkSpeed * dt / SUB)
					if m > 1e-9 then
						r.Root.Position = pos + to * (step / m)
						r._walked += step
					end
					h.Reached = m <= step + 1e-9
				end
			end
			w.SEP.Step(dt / SUB)
		end
	end
end

-- the deepest overlap right now (full bodies): max over monster pairs of rA + rB - d and over monsters of
-- r + PlayerRadius - (distance to the player); 0 = nobody touches
local function overlapNow(w, recs, info)
	local worst = 0
	for i = 1, #recs do
		local a = recs[i]
		local pa = a.Root.Position
		if info then worst = math.max(worst, a._radius + w.SEP.PlayerRadius - flat(pa, info.Pos)) end
		for j = i + 1, #recs do
			local b = recs[j]
			worst = math.max(worst, a._radius + b._radius - flat(pa, b.Root.Position))
		end
	end
	return worst
end

-- the review probe: a player walking straight along +x at `speed` studs/s (or opts.Path), and 4 Shard Slimes + 2 King
-- Slimes starting apart behind them; returns the mean and the worst of the per-tick deepest overlap after `Warm` s, and
-- the share of monster-ticks in reach
local PACK = { { "Slime", -12, -3 }, { "Slime", -12, 3 }, { "Slime", -17, -6 }, { "Slime", -17, 6 }, { "BigSlime", -21, 0 },
	{ "BigSlime", -26, 5 } }
local function walkingProbe(speed, opts)
	opts = opts or {}
	local w = spacingWorld()
	if opts.Setup then opts.Setup(w.SEP) end
	local x0 = CX - 90
	local info = playerAt("kid", x0, CZ)
	info.Path = opts.Path or function(t) return vec(x0 + speed * t, 3, CZ) end
	local start = info.Path(0)
	local recs = {}
	for _, m in PACK do
		table.insert(recs, mon(w, m[1], start.X + m[2], start.Z + m[3], { ZoneId = "SlimeMeadow", _nextAttackAt = 0 }))
	end
	local sum, n, worst = 0, 0, 0
	local ticks = math.floor((opts.Seconds or 25) / MC.AIInterval)
	simulate(w, info, recs, ticks, { Old = opts.Old, Measure = function(now)
		if now < (opts.Warm or 2) then return end
		local o = overlapNow(w, recs, info)
		sum += o
		n += 1
		worst = math.max(worst, o)
	end })
	local reach = 0
	for _, r in recs do reach += r._reachTicks or 0 end
	return sum / math.max(1, n), worst, reach / (#recs * ticks), w, recs, info
end

runGroup("chase simulation", function()
	local kinds = { "Slime", "BigSlime", "PumpkinSlime", "Slime", "Slime", "BigSlime" }
	local function crowd(oldChase)
		local w = spacingWorld()
		local info = playerAt("kid", CX, CZ)
		local recs = {}
		for i, kind in kinds do
			table.insert(recs, mon(w, kind, CX + (i - 3) * 0.7, CZ - 18 - (i % 2) * 2, { ZoneId = "SlimeMeadow", _nextAttackAt = 0 }))
		end
		if oldChase then -- the old chase: straight at the player's position, no slide
			for _ = 1, 80 do
				for _, r in recs do
					local pos = r.Root.Position
					if flat(pos, info.Pos) > MC.AttackRange then
						local to = vec(info.Pos.X - pos.X, 0, info.Pos.Z - pos.Z)
						local m = to.Magnitude
						r.Root.Position = pos + to * (math.min(m, r.Def.Speed * MC.AIInterval) / m)
					end
				end
			end
		else
			simulate(w, info, recs, 80)
		end
		return w, info, recs
	end
	local _, info, recs = crowd(true)
	local worstOld = worstPair(recs, 0.9, function(r) return r.Root.Position end)
	check(worstOld < -0.5, "control: the old chase (straight at the player, no slide) piles them up", worstOld)
	local w
	w, info, recs = crowd(false)
	local worst, at = worstPair(recs, 1, function(r) return r.Root.Position end)
	check(worst >= -0.05, "after 20 s of chasing from one spot: no two monsters overlap (rA + rB)", show({ worst, at }))
	local inside, reach = {}, 0
	for _, r in recs do
		local d = flat(r.Root.Position, info.Pos)
		if d < r._radius + w.SEP.PlayerRadius - 0.05 then table.insert(inside, r.Kind .. "=" .. d) end
		if d <= MC.AttackRange + 1e-6 then reach += 1 end
	end
	check(#inside == 0, "no monster stands inside the player", show(inside))
	check(reach == #recs, "a standing player: all six stand in reach (they surround it)", reach)
end)

runGroup("walking player", function()
	-- the review probe: the player keeps walking slower than the monsters; the mean of the deepest overlap per AI tick
	-- (full bodies, monster pairs and the player body) must stay under 0.3 studs at 3, 5 and 8 studs/s
	local means = {}
	for _, speed in { 3, 5, 8 } do
		local mean, worst, reach = walkingProbe(speed)
		means[speed] = mean
		check(mean < 0.3, "walking " .. speed .. " studs/s: mean deepest overlap < 0.3 studs", show({ mean = mean, worst = worst }))
		check(worst < 1, "walking " .. speed .. " studs/s: never a pile (worst < 1 stud)", worst)
		if speed < 8 then
			check(reach > 0.5, "walking " .. speed .. " studs/s: the monsters keep up and attack (in reach > 50% of ticks)", reach)
		end
	end
	finding(string.format("walking player, mean / review bar 0.3: 3 studs/s %.3f, 5 studs/s %.3f, 8 studs/s %.3f",
		means[3], means[5], means[8]))
	-- the same player walking a circle (the rear arc keeps turning)
	local mean, worst = walkingProbe(5, { Path = function(t)
		local a = t * 5 / 25
		return vec(CX + 25 * math.cos(a), 3, CZ + 25 * math.sin(a))
	end })
	check(mean < 0.3 and worst < 1, "walking a circle at 5 studs/s: mean < 0.3, worst < 1", show({ mean = mean, worst = worst }))
	-- control: the old rule (stand still once in reach, no lead, no walk prediction, one round, 0.9, 3 studs/s)
	local oldMean = walkingProbe(5, { Old = true, Setup = function(SEP)
		SEP.Speed, SEP.Lead, SEP.Passes, SEP.Overlap = 3, 0, 1, 0.9
	end })
	check(oldMean > 1, "control: the old rule piles them up behind a walking player (mean > 1 stud)", oldMean)
	finding(string.format("walking 5 studs/s with the old rule: mean deepest overlap %.3f", oldMean))
end)

runGroup("crowd of 30", function()
	-- 30 slimes from every side on one standing player: 10 in reach, the rest waiting on outer rings, nobody touching
	local w = spacingWorld()
	local info = playerAt("kid", CX, CZ)
	local recs = {}
	for i = 1, 30 do
		local a = i * 2.39996
		local d = 14 + (i % 5) * 3
		table.insert(recs, mon(w, "Slime", CX + math.cos(a) * d, CZ + math.sin(a) * d, { ZoneId = "SlimeMeadow", _nextAttackAt = 0 }))
	end
	local late, n = 0, 0
	simulate(w, info, recs, 100, { Measure = function(now)
		if now >= 20 then
			late = math.max(late, overlapNow(w, recs, info))
			n += 1
		end
	end })
	local final = overlapNow(w, recs, info)
	local inReach, slots = 0, 0
	for _, r in recs do
		if flat(r.Root.Position, info.Pos) <= MC.AttackRange then inReach += 1 end
		if w.SEP.Slots[r] then slots += 1 end
	end
	check(slots == 30, "all 30 chasers have a slot", slots)
	check(final < 0.05 and late < 0.1, "after 25 s: no two touch (deepest overlap < 0.05 now, < 0.1 over the last 5 s)",
		show({ final = final, late = late }))
	check(inReach == 10, "10 of them stand in reach (the widened ring), 20 wait outside", inReach)
end)

------------------------------------------------------------------ spawn points
runGroup("spawn clear", function()
	local w = spacingWorld()
	local SEP = w.SEP
	mon(w, "BigSlime", CX, CZ)
	check(SEP.Clear(vec(CX + 6, 0, CZ), 1.5) == true, "6 studs from a King Slime is clear for a slime (needs 1.5 + 2.7 + 1.5)")
	check(SEP.Clear(vec(CX + 5.6, 0, CZ), 1.5) == false, "5.6 studs from a King Slime is crowded")
	local dead = mon(w, "Slime", CX + 30, CZ, { Alive = false })
	check(SEP.Clear(dead.Root.Position, 1.5) == true, "a dead monster does not block a spawn")

	-- the real pickSpawnPoint: scripted draws put the first random point on a living slime, the second one is free
	local function spawnWorld(recs)
		local rng = { Script = {} }
		local U = { Random = randomDouble(rng).new() }
		function U.GetRoot() return nil end
		function U.IsAlive() return true end
		function U.FlatDistance(a, b) return flat(a, b) end
		function U.RandomPointInZone(zone, inset)
			inset = inset or 0
			local hx = math.max(1, zone.Size.X / 2 - inset)
			local hz = math.max(1, zone.Size.Z / 2 - inset)
			return vec(zone.Center.X + U.Random:NextNumber(-hx, hx), 0, zone.Center.Z + U.Random:NextNumber(-hz, hz))
		end
		local warnings = {}
		local H = { records = recs, pending = {},
			readyPlayers = function() return {} end,
			groundPoint = function(x, z) return vec(x, 0, z), false end,
			warnThrottled = function(_, msg) table.insert(warnings, msg) end }
		local MS = { CountInRadius = function() return 0 end }
		return execute("MonsterSpawn", SPAWN_EXTRACT, nativeEnv(), C, U, MS, H), rng, warnings
	end
	local blocker = { Id = 1, Alive = true, Root = newRoot(vec(CX, 3, CZ)), _radius = 1.5 }
	local M, rng = spawnWorld({ [1] = blocker })
	rng.Script = { 0.5, 0.5, 0.9, 0.9 } -- 1st try: the zone centre (on the slime), 2nd: a free corner
	local p = M.pickSpawnPoint(C.MonsterTypes.Slime, "Slime")
	check(p ~= nil and flat(p, blocker.Root.Position) >= 1.5 + 1.5 + 1.5 - EPS,
		"a new slime never spawns on a living one (the next try is used)", p and flat(p, blocker.Root.Position))
	-- everything crowded: the first crowded point is still used (density never starves)
	local crowdRecs = {}
	local hx = MEADOW.Size.X / 2 - MC.SpawnInset
	for i = 1, 8 do
		crowdRecs[i] = { Id = i, Alive = true, Root = newRoot(vec(MEADOW.Center.X + hx * (0.2 * i - 0.9), 3, CZ)), _radius = 1.5 }
	end
	M, rng = spawnWorld(crowdRecs)
	rng.Script = {}
	for i = 1, 8 do
		table.insert(rng.Script, 0.5 + 0.5 * (0.2 * i - 0.9)) -- x on the i-th slime
		table.insert(rng.Script, 0.5) -- z = centre
	end
	p = M.pickSpawnPoint(C.MonsterTypes.Slime, "Slime")
	check(p ~= nil and math.abs(p.X - crowdRecs[1].Root.Position.X) < 1e-6,
		"every try crowded: the first crowded ground point is used, no spawn is lost", p and p.X)
end)

runGroup("boss spawn", function()
	-- the real MonsterService.SpawnEvent (review 2026-10-07: a boss keeps the spawn clearance too) on the spacing world's
	-- records. A meadow test boss (Pumpkin King size, Boss = true) keeps the probe off the Halloween season dates.
	C.MonsterTypes.SepTestBoss = { Name = "Test Boss", Zone = "SlimeMeadow", Count = 0, Boss = true, HP = 100, Damage = 1, XP = 1,
		Gold = 1, Speed = 7, Shape = "Slime", Scale = 2.5 }
	local function eventWorld(w, script)
		local rng = { Script = script or {} }
		local U = { Random = randomDouble(rng).new() }
		function U.FlatDistance(a, b) return flat(a, b) end
		local f = { PickCalls = 0, Warn = {} }
		local H = { records = w.H.records,
			groundPoint = function(x, z) return vec(x, 0, z), false end,
			pickSpawnPoint = function()
				f.PickCalls += 1
				return nil
			end,
			spawnMonster = function(kind, o)
				return mon(w, kind, o.Position.X, o.Position.Z, { Event = o.Event, ZoneId = C.MonsterTypes[kind].Zone })
			end,
			warnThrottled = function(_, msg) table.insert(f.Warn, msg) end }
		local env = nativeEnv()
		env.typeof = typeofDouble
		return execute("MonsterEvent", EVENT_EXTRACT, env, C, U, {}, H), f
	end
	local need = 3.75 + 1.5 + 1.5
	-- a living slime right on the spot: the first try (the spot itself) is skipped, a clear point within Radius is used
	local w = spacingWorld()
	local slime = mon(w, "Slime", CX, CZ)
	local MS, f = eventWorld(w, { 0, 0.25, 0.9 }) -- try 1: the spot; try 2: 90 deg, 0.9 x 12 = 10.8 studs away
	local boss = MS.SpawnEvent("SepTestBoss", { Near = vec(CX, 0, CZ), Radius = 12 })
	local p = boss and boss.Root.Position
	check(boss ~= nil and boss.Event == true and flat(p, slime.Root.Position) >= need - EPS and flat(p, vec(CX, 0, CZ)) <= 12 + EPS,
		"a boss never spawns on a living monster: the next clear point within its spawn radius", p and flat(p, slime.Root.Position))
	check(f.PickCalls == 0 and #f.Warn == 0, "(no fallback to a zone spawn point, no warning)", show({ f.PickCalls, f.Warn }))
	-- every try crowded (radius 0): it still appears on its spot (never lost), and the slime under it is slid off
	-- within a few AI ticks (at most 8 studs/s) while the boss never moves
	w = spacingWorld()
	slime = mon(w, "Slime", CX, CZ)
	MS, f = eventWorld(w)
	boss = MS.SpawnEvent("SepTestBoss", { Near = vec(CX, 0, CZ), Radius = 0 })
	check(boss ~= nil and flat(boss.Root.Position, vec(CX, 0, CZ)) < EPS and f.PickCalls == 0,
		"every try crowded: the boss appears on its spot anyway (no lost spawn)", show({ boss ~= nil, f.PickCalls }))
	if boss then
		local ticks = 0
		for _ = 1, 8 do
			if flat(slime.Root.Position, boss.Root.Position) >= 3.75 + 1.5 - 1e-6 then break end
			w.SEP.Begin(list(w), {})
			w.SEP.Resolve({})
			w.SEP.Step(MC.AIInterval)
			ticks += 1
		end
		check(flat(slime.Root.Position, boss.Root.Position) >= 3.75 + 1.5 - 1e-6 and ticks <= 3,
			"the slime under a new boss is slid off within 3 AI ticks (0.75 s)", show({ ticks, flat(slime.Root.Position, boss.Root.Position) }))
		check(flat(boss.Root.Position, vec(CX, 0, CZ)) < EPS, "the boss itself never moves")
	end
	-- a dead monster on the spot does not block it
	w = spacingWorld()
	mon(w, "Slime", CX, CZ, { Alive = false })
	MS = eventWorld(w)
	boss = MS.SpawnEvent("SepTestBoss", { Near = vec(CX, 0, CZ), Radius = 12 })
	check(boss ~= nil and flat(boss.Root.Position, vec(CX, 0, CZ)) < EPS, "a dead monster on the spot does not block a boss")
	C.MonsterTypes.SepTestBoss = nil
end)

------------------------------------------------------------------ the AI wiring (source text of the bound MonsterService)
runGroup("ai wiring", function()
	local src = MONSTER_SOURCE
	local function block(start)
		local a = string.find(src, start, 1, true)
		local b = a and string.find(src, "\nend\n", a, true)
		return a and b and string.sub(src, a, b + 4) or ""
	end
	local ai = block("local function aiStep(")
	check(has(ai, "local goal = clampToZone(zone, SEP.Goal(rec, best))\n\t\t\tsteer(rec, goal, pos, now)")
		and not has(ai, "best.Pos)"), "aiStep: a chaser walks to its slot (clamped into the zone), never at the player's position")
	check(has(ai, "if Util.FlatDistance(pos, goal) <= 1 then\n\t\t\t\tFACE.Active[rec] = { Target = best.Player, Until = now + FACE.Keep }"),
		"aiStep: a monster waiting at its slot faces the player")
	check(has(ai, "attack(rec, best, now, clampToZone(zone, SEP.Goal(rec, best)))"),
		"aiStep: in reach, attack() gets its slot (clamped into the zone) for between swings")
	check(has(ai, "rec._walkTo = homeDest") and has(ai, "rec._walkTo = rec._goal"),
		"aiStep: the walk home and a wander still on its way tell SEP.Walk where they go")
	local atk = block("local function attack(")
	local rg = string.find(atk, "local walk = SEP.ReachGoal(rec, now, rec.Root.Position, slot, info)", 1, true)
	local wu = string.find(atk, "rec._nextAttackAt = now + MC.AttackCooldown", 1, true)
	check(rg ~= nil and wu ~= nil and rg < wu, "attack(): asks SEP.ReachGoal before a new wind-up starts", show({ rg, wu }))
	check(has(atk, "rec._walkTo = walk\n\t\trec.Humanoid:MoveTo(walk)") and has(atk, "rec.Humanoid:MoveTo(rec.Root.Position)")
		and has(atk, "rec._inReach = true") and has(atk, "rec._goal = nil"),
		"attack(): steps to its slot (SEP.Walk knows) or stands, marks itself in reach, never a stuck-check goal")
	local st = block("local function steer(")
	check(has(st, "rec._walkTo = dest"), "steer(): every walk tells SEP.Walk where it goes")
	local ps = block("local function personalStep(")
	check(has(ps, "attack(rec, info, now, SEP.Goal(rec, info))") and has(ps, "rec._walkTo = SEP.Goal(rec, info)")
		and has(ps, "rec.Humanoid:MoveTo(rec._walkTo)") and not has(ps, "MoveTo(info.Pos)"),
		"personalStep: a personal monster walks to its slot (also between swings), never into its owner")
	local tick = block("local function aiTick(")
	local b1 = string.find(tick, "pcall(SEP.Begin, list, plist)", 1, true)
	local s1 = string.find(tick, "pcall(aiStep, rec, plist, now)", 1, true)
	local ro = string.find(tick, "pcall(SEP.Rotate, rec)", 1, true)
	local r1 = string.find(tick, "pcall(SEP.Resolve, plist)", 1, true)
	check(b1 ~= nil and s1 ~= nil and ro ~= nil and r1 ~= nil and b1 < s1 and s1 < ro and ro < r1,
		"aiTick: SEP.Begin, then each step followed by SEP.Rotate, then SEP.Resolve", show({ b1, s1, ro, r1 }))
	check(has(tick, "Vel = root.AssemblyLinearVelocity"), "aiTick: every player entry carries its velocity (SEP.Ahead)")
	check(has(src, "local okSep, errSep = pcall(SEP.Step, dt) -- A23-74"), "every Heartbeat plays the slides (SEP.Step)")
	local spawn = block("local function spawnMonster(")
	check(has(spawn, "_radius = SEP.RadiusOf(def),"), "every monster record carries its body radius")
	local newPart = block("local function newPart(")
	check(has(newPart, "p.CanCollide = false"), "monster parts still never collide (players are not blocked physically)")
end)

finish()
