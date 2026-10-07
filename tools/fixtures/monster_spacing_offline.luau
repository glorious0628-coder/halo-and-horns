-- monster_spacing_offline.luau : A23-74 (user 2026-10-07 "그리고 점점 합쳐지겠다 야"): monsters keep a natural distance
-- from each other and from players. No monster part collides (TECH_SPEC: CanCollide = false), so MonsterService spaces
-- them itself: chasers walk to their own slot on a ring around the target (spread so neighbours stand rA + rB apart; the
-- farthest wait on an outer ring when the inner one is full), overlapping monsters / a monster inside a player body
-- slide apart lightly (at most Speed studs/s, the smaller one moves more, a boss never), and new monsters spawn clear
-- of living ones. tools/test_monster_spacing.py binds CONFIG_SOURCE, MONSTER_SOURCE (text checks of the AI wiring),
-- SPACING_EXTRACT (the real SEP table and functions cut from the CURRENT MonsterService) and SPAWN_EXTRACT (the real
-- pickSpawnPoint, as in test_tutorial_spawn) in front of dev2_kit.luau. Roots, the ground ray, walls and Random are
-- doubles; the contract numbers (radii, ring, 0.9, 3 studs/s, 1.5 spawn gap, cell 8) are written here on purpose.

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
	check(SEP.Overlap == 0.9 and SEP.Speed == 3 and SEP.MinPush == 0.05, "slide apart below (rA + rB) x 0.9, at most 3 studs/s",
		show({ SEP.Overlap, SEP.Speed, SEP.MinPush }))
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

runGroup("full ring", function()
	-- ten slimes from one side: 7 fit around a player (2 asin(3/7) = 50.8 deg each), the 3 farthest wait outside reach
	local w = spacingWorld()
	local info = playerAt("kid", CX, CZ)
	local all = {}
	for i = 1, 10 do
		table.insert(all, mon(w, "Slime", CX + (i % 3) * 0.3, CZ - 9 - i, { _target = info.Player }))
	end
	w.SEP.Begin(list(w), { info })
	local inner, outer = {}, {}
	for _, r in all do
		local s = w.SEP.Slots[r]
		if s and s.Ring <= MC.AttackRange then table.insert(inner, r) elseif s then table.insert(outer, r) end
	end
	check(#inner == 7 and #outer == 3, "7 on the ring in reach, 3 waiting outside", show({ #inner, #outer }))
	local closest = true
	for i = 1, 7 do
		if not table.find(inner, all[i]) then closest = false end
	end
	check(closest, "the 7 closest keep the inner ring")
	local posOf = function(r) return slotPoint(info, w.SEP.Slots[r]) end
	local worst, at = worstPair(inner, 1, posOf)
	check(worst >= -1e-3, "the full inner ring: every pair rA + rB apart", show({ worst, at }))
	worst, at = worstPair(outer, 1, posOf)
	check(worst >= -1e-3, "the waiting ring: every pair rA + rB apart", show({ worst, at }))
	worst, at = worstPair(all, 1, posOf)
	check(worst >= -1e-3, "no waiting slime stands on a ring slime", show({ worst, at }))
	local outerOk = true
	for _, r in outer do
		if w.SEP.Slots[r].Ring <= MC.AttackRange then outerOk = false end
	end
	check(outerOk, "the waiting ones stand outside AttackRange (they do not attack until a place frees)")
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

------------------------------------------------------------------ slide apart
runGroup("slide apart", function()
	local maxStep = 3 * MC.AIInterval
	-- two slimes 1 stud apart: each moves away from the other, the same amount, capped
	local w = spacingWorld()
	local a = mon(w, "Slime", CX, CZ)
	local b = mon(w, "Slime", CX + 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	local pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and pa.Delta.X < 0 and pb.Delta.X > 0 and math.abs(pa.Delta.X + pb.Delta.X) < 1e-9,
		"two overlapping slimes slide apart, equally, in opposite directions", show({ pa and pa.Delta.X, pb and pb.Delta.X }))
	check(pa and math.abs(math.abs(pa.Delta.X) - maxStep) < 1e-9, "a slide is capped at 3 studs/s x AIInterval",
		pa and pa.Delta.X)
	-- a small overlap is closed exactly (half each)
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ)
	b = mon(w, "Slime", CX + 2.5, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and math.abs(pa.Delta.X + 0.1) < 1e-9 and math.abs(pb.Delta.X - 0.1) < 1e-9,
		"2.5 studs apart (need 2.7): each slides 0.1 (the pair is counted once)", show({ pa and pa.Delta.X, pb and pb.Delta.X }))
	-- far enough: nothing
	w = spacingWorld()
	mon(w, "Slime", CX, CZ)
	mon(w, "Slime", CX + 2.8, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(next(w.SEP.Push) == nil, "2.8 studs apart: no slide (only real overlaps move)")
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
	check(w.SEP.Push[king] == nil and w.SEP.Push[s] ~= nil and w.SEP.Push[s].Delta.X > 0,
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
	check(w.SEP.Push[inside] and w.SEP.Push[inside].Delta.X > 0, "a slime inside the player body slides out, away from the player",
		w.SEP.Push[inside] and w.SEP.Push[inside].Delta.X)
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
	-- water: a slide that would end in the water is refused (a and b split along x; water south of z)
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
	w, a, b = pairAt({ Wall = CX + 1 }, CX, CZ) -- the full 0.75 (+0.5 probe) hits it, the half 0.375 does not
	w.SEP.Resolve({})
	check(w.SEP.Push[a] and math.abs(w.SEP.Push[a].Delta.X - 0.375) < 1e-9, "a blocked full slide falls back to half",
		w.SEP.Push[a] and w.SEP.Push[a].Delta.X)
	-- moved since the snapshot (pivotHome this tick): no slide from stale positions
	w, a, b = pairAt(nil, CX, CZ)
	a.Root.Position = vec(CX + 30, 3, CZ)
	w.SEP.Resolve({})
	check(w.SEP.Push[a] == nil, "a monster teleported during the tick is not slid")
	-- tiny overlaps do not jitter
	w = spacingWorld()
	a = mon(w, "Slime", CX, CZ)
	b = mon(w, "Slime", CX + 2.66, CZ)
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
	-- 100 monsters on a 10 x 10 lattice 9 studs apart: no overlaps, and only grid neighbours are tested
	local w = spacingWorld()
	for i = 0, 9 do
		for j = 0, 9 do
			mon(w, "Slime", CX - 45 + i * 9, CZ - 45 + j * 9)
		end
	end
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	check(next(w.SEP.Push) == nil, "a spread-out zone: nobody slides")
	check(w.Pairs <= 100 * 9 and w.Pairs < 100 * 99 / 2 / 4, "pair tests stay near n x neighbours (never every pair)", w.Pairs)
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

------------------------------------------------------------------ simulation (the screenshot case)
-- a stand-in for aiStep's chase (target = the player, walk at Def.Speed toward the goal, stand once in AttackRange)
-- plus the real SEP.Begin / Goal / Resolve / Step every AI tick
local function simulate(w, info, recs, ticks, oldChase)
	local dt = MC.AIInterval
	for _ = 1, ticks do
		if not oldChase then w.SEP.Begin(recs, { info }) end
		for _, r in recs do
			local pos = r.Root.Position
			if flat(pos, info.Pos) > MC.AttackRange then
				local goal = oldChase and info.Pos or w.SEP.Goal(r, info)
				local to = vec(goal.X - pos.X, 0, goal.Z - pos.Z)
				local m = to.Magnitude
				local step = math.min(m, r.Def.Speed * dt)
				if m > 1e-9 then r.Root.Position = pos + to * (step / m) end
			end
			r._target = info.Player
		end
		if not oldChase then
			w.SEP.Resolve({ info })
			w.SEP.Step(dt)
		end
	end
end

runGroup("chase simulation", function()
	local kinds = { "Slime", "BigSlime", "PumpkinSlime", "Slime", "Slime", "BigSlime" }
	local function crowd(oldChase)
		local w = spacingWorld()
		local info = playerAt("kid", CX, CZ)
		local recs = {}
		for i, kind in kinds do
			table.insert(recs, mon(w, kind, CX + (i - 3) * 0.7, CZ - 18 - (i % 2) * 2, { ZoneId = "SlimeMeadow" }))
		end
		simulate(w, info, recs, 80, oldChase)
		return w, info, recs
	end
	local _, info, recs = crowd(true)
	local worstOld = worstPair(recs, 0.9, function(r) return r.Root.Position end)
	check(worstOld < -0.5, "control: the old chase (straight at the player, no slide) piles them up", worstOld)
	local w
	w, info, recs = crowd(false)
	local worst, at = worstPair(recs, 0.9, function(r) return r.Root.Position end)
	check(worst >= -0.05, "after 20 s of chasing: no two monsters closer than (rA + rB) x 0.9", show({ worst, at }))
	local inside, reach = {}, 0
	for _, r in recs do
		local d = flat(r.Root.Position, info.Pos)
		if d < (r._radius + w.SEP.PlayerRadius) * 0.9 - 0.05 then table.insert(inside, r.Kind .. "=" .. d) end
		if d <= MC.AttackRange + 1e-6 then reach += 1 end
	end
	check(#inside == 0, "no monster stands inside the player", show(inside))
	check(reach >= 4, "most of them still reach the player (they surround it)", reach)
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
	local ps = block("local function personalStep(")
	check(has(ps, "rec.Humanoid:MoveTo(SEP.Goal(rec, info))") and not has(ps, "MoveTo(info.Pos)"),
		"personalStep: a personal monster walks to its slot, never into its owner")
	local tick = block("local function aiTick(")
	local b1 = string.find(tick, "pcall(SEP.Begin, list, plist)", 1, true)
	local st = string.find(tick, "pcall(aiStep, rec, plist, now)", 1, true)
	local r1 = string.find(tick, "pcall(SEP.Resolve, plist)", 1, true)
	check(b1 ~= nil and st ~= nil and r1 ~= nil and b1 < st and st < r1, "aiTick: SEP.Begin before the steps, SEP.Resolve after",
		show({ b1, st, r1 }))
	check(has(src, "local okSep, errSep = pcall(SEP.Step, dt) -- A23-74"), "every Heartbeat plays the slides (SEP.Step)")
	local spawn = block("local function spawnMonster(")
	check(has(spawn, "_radius = SEP.RadiusOf(def),"), "every monster record carries its body radius")
	local newPart = block("local function newPart(")
	check(has(newPart, "p.CanCollide = false"), "monster parts still never collide (players are not blocked physically)")
end)

finish()
