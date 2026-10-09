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
-- 3 / 5 / 8 studs/s with 4 Shard Slimes + 2 King Slimes: mean deepest overlap per AI tick < 0.3 studs. Review
-- 2026-10-08: the zone edge (slides along the move line, rings cut by it) and two players side by side (target hold,
-- after it never kept out of reach while the other player is in reach; rings cut by the other player's body; a crowd
-- of 16 around them).

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
	w.SEP, w.Clamp = execute("MonsterSpacing", SPACING_EXTRACT, nativeEnv(), C, U, H)
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
	-- A23-92: a boss never walks to a ring slot (it never moves) and players reach its body's edge (HitPad), so only
	-- the regular kinds' rings are checked; a zone holds one boss at a time, so the biggest pair is two regular kinds
	-- or a boss + the biggest regular kind
	local bad, maxR, maxB = {}, 0, 0
	for kind, def in C.MonsterTypes do
		local r = SEP.RadiusOf(def)
		if def.Boss then
			maxB = math.max(maxB, r)
		else
			maxR = math.max(maxR, r)
			local ring = SEP.Ring({ _radius = r })
			if ring < r + SEP.PlayerRadius - EPS or ring > MC.AttackRange - SEP.RingInside + EPS then
				table.insert(bad, kind .. "=" .. ring)
			end
		end
	end
	check(#bad == 0, "every regular kind's ring is outside the player body (>= r + 1) and in reach (<= AttackRange - 0.5)", show(bad))
	check(2 * maxR * SEP.Overlap <= SEP.Cell and (maxB + maxR) * SEP.Overlap <= SEP.Cell
		and (math.max(maxR, maxB) + SEP.PlayerRadius) * SEP.Overlap <= SEP.Cell,
		"the biggest pair (two regular kinds / a boss + the biggest regular) and player overlap fit in one grid cell",
		show({ maxR, maxB }))
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
	-- the zone edge: a zone monster stays ZONE_MOVE_INSET inside its rect; review 2026-10-08: a push across that line
	-- slides up to it (0.2 here) and the other monster of the pair takes the rest (1.8), where the whole slide was refused
	local edge = MEADOW.Center.X + MEADOW.Size.X / 2 - 6.2
	w, a, b = pairAt(nil, edge, CZ)
	w.SEP.Resolve({})
	local pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and math.abs(pa.Delta.X - 0.2) < 1e-9 and math.abs(pb.Delta.X + 1.8) < 1e-9,
		"no slide past the zone's move inset: up to the line, the other one takes the rest",
		show({ pa and pa.Delta.X, pb and pb.Delta.X }))
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
-- still in AttackRange, no walk prediction); opts.Measure(now) runs at every AI tick before the passes. Review
-- 2026-10-08: goals are clamped into the zone like aiStep (the real clampToZone; a no-op away from the zone edge), and
-- with opts.Players (several players) each monster picks its target with the real SEP.Pick (opts.Nearest: the old rule,
-- the nearest one every tick), counting its target changes in r._switches, the changes to a player out of reach in
-- r._farSwitches and (review 2026-10-08) the ticks it chases a target out of reach while another player is in reach
-- (it swings at nobody: aiStep attacks only its target) in r._idleNear. Review 2026-10-08 (3rd round): also the
-- switches within 2 s (TargetHold) of taking its target in r._quick, the switches back to the target before
-- (A -> B -> A) in r._flips and its longest run of such idle ticks in r._idleMax.
local WINDUP = C.HitReact.MonsterWindup
local SUB = 8
local function nearestOf(plist, pos)
	local best, bestD = nil, nil
	for _, p in plist do
		local d = flat(pos, p.Pos)
		if d <= MC.AggroRadius and (bestD == nil or d < bestD) then best, bestD = p, d end
	end
	return best
end
local function simulate(w, info, recs, ticks, opts)
	opts = opts or {}
	local dt = MC.AIInterval
	local plist = opts.Players or { info }
	for tick = 1, ticks do
		local now = (tick - 1) * dt
		for _, p in plist do
			if p.Path then -- aiTick's plist: Pos and Vel (the root's AssemblyLinearVelocity) at the tick
				p.Pos = p.Path(now)
				p.Vel = (p.Path(now + 0.01) - p.Pos) * 100
			end
		end
		if opts.Measure then opts.Measure(now) end
		w.SEP.Begin(recs, plist)
		for _, r in recs do
			if r._windupEnd and now >= r._windupEnd then r._windup, r._windupEnd = nil, nil end
			local pos = r.Root.Position
			r._ramp = (r._walked or 0) < 0.5 * dt and 0 or (r._ramp or 0) + 1
			r._walked = 0
			local ti = info
			if opts.Players then
				ti = opts.Nearest and nearestOf(plist, pos) or w.SEP.Pick(r, plist, pos, now)
				if ti and ti.Player ~= r._target then
					if r._target ~= nil then
						if flat(pos, ti.Pos) > MC.AttackRange then r._farSwitches = (r._farSwitches or 0) + 1 end
						if now - (r._targetAt or -math.huge) < 2 then r._quick = (r._quick or 0) + 1 end
						if ti.Player == r._before then r._flips = (r._flips or 0) + 1 end
					end
					r._before = r._target
					r._target, r._targetAt = ti.Player, now
					r._switches = (r._switches or 0) + 1
				end
				local idle = false
				if ti and flat(pos, ti.Pos) > MC.AttackRange then
					for _, p in plist do
						if p ~= ti and flat(pos, p.Pos) <= MC.AttackRange then
							idle = true
							break
						end
					end
				end
				r._idleRun = idle and (r._idleRun or 0) + 1 or 0
				r._idleNear = (r._idleNear or 0) + (idle and 1 or 0)
				r._idleMax = math.max(r._idleMax or 0, r._idleRun)
			else
				r._target = info.Player
			end
			local zone = r.Owner == nil and C.Zones[r.ZoneId] or nil
			local walk
			if ti == nil then
				walk = nil
			elseif flat(pos, ti.Pos) <= MC.AttackRange then
				local slot = w.Clamp(zone, w.SEP.Goal(r, ti))
				walk = (not opts.Old) and w.SEP.ReachGoal(r, now, pos, slot, ti) or nil
				if r._windup == nil and now >= (r._nextAttackAt or 0) then
					r._nextAttackAt = now + MC.AttackCooldown
					r._windup, r._windupEnd = {}, now + WINDUP
					r._swings = (r._swings or 0) + 1
				end
				r._reachTicks = (r._reachTicks or 0) + 1
			else
				walk = w.Clamp(zone, w.SEP.Goal(r, ti))
			end
			r.Humanoid = r.Humanoid or newHumanoid()
			r.Humanoid.WalkSpeed = r.Def.Speed * math.min(1, 0.45 + 0.3 * r._ramp)
			r._walkTo = (not opts.Old) and walk or nil
			r.Humanoid:MoveTo(walk or pos)
		end
		w.SEP.Resolve(plist)
		for k = 1, SUB do
			for _, p in plist do
				if p.Path then p.Pos = p.Path(now + k * dt / SUB) end
			end
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
-- r + PlayerRadius - (distance to the player, or to each of a list of players); 0 = nobody touches
local function overlapNow(w, recs, info)
	local worst = 0
	local players = (info and info.Pos == nil) and info or { info }
	for i = 1, #recs do
		local a = recs[i]
		local pa = a.Root.Position
		for _, p in players do worst = math.max(worst, a._radius + w.SEP.PlayerRadius - flat(pa, p.Pos)) end
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

------------------------------------------------------------------ the zone edge (review 2026-10-08)
-- 검수 2026-10-08: monsters crowded on a zone's move line (ZONE_MOVE_INSET inside the zone edge: every MoveTo point
-- and slide stays inside it) never came apart, because SEP.CanSlide refused a whole slide whose end crossed the line,
-- also the part along it. The meadow's east move line:
local HI = MEADOW.Center.X + MEADOW.Size.X / 2 - 6

runGroup("zone edge slides", function()
	local w = spacingWorld()
	local SEP = w.SEP
	local on = mon(w, "Slime", HI, CZ)
	local d = SEP.Fit(on, on.Root.Position, vec(0.6, 0, 0.8))
	check(d ~= nil and d.X == 0 and math.abs(d.Z - 0.8) < 1e-9, "on the move line: a push across it keeps its part along the line",
		show(d and { d.X, d.Z }))
	local past = mon(w, "Slime", HI + 0.01, CZ + 10)
	d = SEP.Fit(past, past.Root.Position, vec(0, 0, 1))
	check(d ~= nil and d.X == 0 and d.Z == 1,
		"a hair past the line (a Humanoid stops a little off its MoveTo point): it still slides along the line (old: refused)",
		show(d and { d.X, d.Z }))
	check(SEP.Fit(past, past.Root.Position, vec(0.5, 0, 0)) == nil, "never further out")
	d = SEP.Fit(past, past.Root.Position, vec(-1, 0, 0.5))
	check(d ~= nil and d.X == -1 and d.Z == 0.5, "back in: freely", show(d and { d.X, d.Z }))
	local pet = mon(w, "Slime", HI, CZ - 10, { Owner = { Name = "kid" } })
	d = SEP.Fit(pet, pet.Root.Position, vec(1, 0, 0))
	check(d ~= nil and d.X == 1, "a personal monster has no move line (it follows its owner anywhere in the zone)", d and d.X)
	local box = SEP.Box(on)
	check(box ~= nil and box.X1 == HI and SEP.Box(pet) == nil and SEP.Box(past, past.Root.Position).X1 == HI + 0.01,
		"the box: the zone rect inset 6 (grown to take in the body when given); none for a personal monster",
		show(box))
	local stray = mon(w, "Slime", CX, CZ + 20, { ZoneId = "GoblinWoods" })
	check(SEP.Fit(stray, stray.Root.Position, vec(1, 0, 0)) == nil,
		"a zone monster standing outside its own zone never slides (aiStep walks it home)")

	-- walking toward the line: a push out toward it may take the body only up to the line at the END of its walk
	-- (the slide is checked from where it stands, where its walk ends and at its MoveTo point)
	w = spacingWorld()
	local walker = mon(w, "Slime", HI - 2, CZ)
	local beside = mon(w, "Slime", HI - 1.5, CZ)
	w.SEP.Begin(list(w), {})
	walker.Humanoid = newHumanoid(6) -- 1.5 studs this tick: its walk ends at its MoveTo point, 0.5 inside the line
	walker._walkTo = vec(HI - 0.5, 0, CZ)
	walker.Humanoid:MoveTo(walker._walkTo)
	w.SEP.Resolve({})
	local pw, pb = w.SEP.Push[walker], w.SEP.Push[beside]
	check(pw and pb and math.abs(pw.Delta.X - 0.5) < 1e-9 and math.abs(pb.Delta.X + 1.5) < 1e-9,
		"walking toward the line: pushed out only up to the line at its walk's end (0.5), the other takes the rest",
		show({ pw and pw.Delta.X, pb and pb.Delta.X }))
	-- a walk ending past the line (the game clamps every MoveTo point inside, so only a stray point): the slide never
	-- pushes it further out, nor drags it back in
	w = spacingWorld()
	walker = mon(w, "Slime", HI - 1, CZ)
	beside = mon(w, "Slime", HI + 1.5, CZ + 2)
	w.SEP.Begin(list(w), {})
	walker.Humanoid = newHumanoid(10)
	walker._walkTo = vec(HI + 3, 0, CZ)
	walker.Humanoid:MoveTo(walker._walkTo)
	w.SEP.Resolve({})
	pw = w.SEP.Push[walker]
	check(pw and pw.Delta.X == 0 and math.abs(pw.Delta.Z + 0.5) < 1e-9, "a walk ending past the line: pushed along it only",
		show(pw and { pw.Delta.X, pw.Delta.Z }))

	-- two slimes on the line (a hair past it), 1 stud apart along it: they slide apart along it (old: both refused)
	w = spacingWorld()
	local a = mon(w, "Slime", HI + 0.02, CZ)
	local b = mon(w, "Slime", HI + 0.02, CZ + 1)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	local pa, pb = w.SEP.Push[a], w.SEP.Push[b]
	check(pa and pb and pa.Delta.X == 0 and pb.Delta.X == 0 and math.abs(pa.Delta.Z + 1) < 1e-9 and math.abs(pb.Delta.Z - 1) < 1e-9,
		"two slimes on the line slide apart along it", show({ pa and pa.Delta.Z, pb and pb.Delta.Z }))
	w.SEP.Step(MC.AIInterval)
	check(flat(a.Root.Position, b.Root.Position) >= 3 - 1e-9 and a.Root.Position.X == HI + 0.02 and b.Root.Position.X == HI + 0.02,
		"one tick later: apart, and not further out", flat(a.Root.Position, b.Root.Position))

	-- stacked across the line: the one pinned on it cannot move out, so the inner one takes the whole push
	w = spacingWorld()
	local outer = mon(w, "Slime", HI, CZ)
	local inner = mon(w, "Slime", HI - 1, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	local po, pi = w.SEP.Push[outer], w.SEP.Push[inner]
	check(po == nil and pi ~= nil and math.abs(pi.Delta.X + 2) < 1e-9 and pi.Delta.Z == 0,
		"pinned on the line: the other one takes the whole push (2 studs, not its half)", show({ po ~= nil, pi and pi.Delta.X }))
	w.SEP.Step(MC.AIInterval)
	check(flat(outer.Root.Position, inner.Root.Position) >= 3 - 1e-9, "one tick: apart (old: 1 stud still inside each other)",
		flat(outer.Root.Position, inner.Root.Position))
	-- the same with the pinned one second in the pair (its part goes back to the first)
	w = spacingWorld()
	inner = mon(w, "Slime", HI - 1, CZ)
	outer = mon(w, "Slime", HI, CZ)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	po, pi = w.SEP.Push[outer], w.SEP.Push[inner]
	check(po == nil and pi ~= nil and math.abs(pi.Delta.X + 2) < 1e-9, "pinned second in the pair: the first one takes the whole push",
		show({ po ~= nil, pi and pi.Delta.X }))

	-- a walker whose MoveTo point is on the line (review 2026-10-08, 2nd look: a walk that got there early stopped there
	-- and the rest of a slide out carried the body past the line): no slide out toward the line, the other monster takes
	-- the push; the MoveTo point never passes the line
	w = spacingWorld()
	local walker = mon(w, "Slime", HI - 2, CZ)
	local other = mon(w, "Slime", HI - 2.6, CZ + 2.3)
	w.SEP.Begin(list(w), {})
	walker.Humanoid = newHumanoid(10)
	walker._walkTo = vec(HI, 0, CZ + 5)
	walker.Humanoid:MoveTo(walker._walkTo)
	other.Humanoid = newHumanoid(10)
	w.SEP.Resolve({})
	local pw, po2 = w.SEP.Push[walker], w.SEP.Push[other]
	check((pw == nil or pw.Delta.X <= 1e-9) and po2 ~= nil and po2.Delta.X < -0.5 and walker._walkTo.X <= HI + 1e-9,
		"a walk ending on the line: no slide out toward it, the other one takes the push, the MoveTo point stays inside",
		show({ pw and pw.Delta.X, po2 and po2.Delta.X, walker._walkTo.X - HI }))
	-- the same played out: a walk reaching its point on the line early, a slide still going; the body never passes it
	w = spacingWorld()
	walker = mon(w, "Slime", HI - 1, CZ)
	other = mon(w, "Slime", HI - 2, CZ + 0.5)
	local farthest = -math.huge
	for _ = 1, 8 do
		w.SEP.Begin(list(w), {})
		walker.Humanoid = walker.Humanoid or newHumanoid(10)
		walker._walkTo = vec(HI - 0.6, 0, CZ + 0.2)
		walker.Humanoid:MoveTo(walker._walkTo)
		other.Humanoid = other.Humanoid or newHumanoid(0)
		w.SEP.Resolve({})
		for _ = 1, 8 do
			local h = walker.Humanoid
			if not h.Reached then
				local pos = walker.Root.Position
				local to = vec(h.Goal.X - pos.X, 0, h.Goal.Z - pos.Z)
				local m = to.Magnitude
				local step = math.min(m, h.WalkSpeed * MC.AIInterval / 8)
				if m > 1e-9 then walker.Root.Position = pos + to * (step / m) end
				h.Reached = m <= step + 1e-9
			end
			w.SEP.Step(MC.AIInterval / 8)
			farthest = math.max(farthest, walker.Root.Position.X - HI)
		end
	end
	check(farthest <= 1e-9, "a walk reaching its point near the line while a slide plays: never past the line", farthest)

	-- a player standing 1 stud inside the line: a slime pinned on the line inside its body leaves along the line
	w = spacingWorld()
	local info = playerAt("kid", HI - 1, CZ)
	local s = mon(w, "Slime", HI, CZ + 0.3)
	w.SEP.Begin(list(w), { info })
	w.SEP.Resolve({ info })
	local ps = w.SEP.Push[s]
	check(ps ~= nil and ps.Delta.X == 0 and ps.Delta.Z > 1.5, "inside a player body, pinned on the line: it slides along the line",
		show(ps and { ps.Delta.X, ps.Delta.Z }))
	w.SEP.Step(MC.AIInterval)
	check(flat(s.Root.Position, info.Pos) >= 2.5 - 1e-6 and s.Root.Position.X <= HI, "one tick: out of the body (r + 1), still inside the line",
		flat(s.Root.Position, info.Pos))
	-- right in line with the player: it still leaves (to a side by id), within two ticks (8 studs/s)
	w = spacingWorld()
	s = mon(w, "Slime", HI, CZ)
	for _ = 1, 2 do
		w.SEP.Begin(list(w), { info })
		w.SEP.Resolve({ info })
		w.SEP.Step(MC.AIInterval)
	end
	check(flat(s.Root.Position, info.Pos) >= 2.5 - 1e-6 and s.Root.Position.X <= HI,
		"right in line with the player on the line: out of the body within two ticks", flat(s.Root.Position, info.Pos))

	-- the north move line (z) the same way: stacked across it, the inner one takes the whole push; pinned on it inside a
	-- player body, out along the line (x)
	local ZHI = MEADOW.Center.Z + MEADOW.Size.Z / 2 - 6
	w = spacingWorld()
	outer = mon(w, "Slime", CX, ZHI)
	inner = mon(w, "Slime", CX, ZHI - 1)
	w.SEP.Begin(list(w), {})
	w.SEP.Resolve({})
	po, pi = w.SEP.Push[outer], w.SEP.Push[inner]
	check(po == nil and pi ~= nil and math.abs(pi.Delta.Z + 2) < 1e-9 and pi.Delta.X == 0,
		"the north line: pinned on it, the other one takes the whole push", show({ po ~= nil, pi and pi.Delta.Z }))
	w = spacingWorld()
	local zinfo = playerAt("kid", CX, ZHI - 1)
	s = mon(w, "Slime", CX + 0.3, ZHI)
	w.SEP.Begin(list(w), { zinfo })
	w.SEP.Resolve({ zinfo })
	w.SEP.Step(MC.AIInterval)
	check(flat(s.Root.Position, zinfo.Pos) >= 2.5 - 1e-6 and s.Root.Position.Z <= ZHI,
		"the north line: pinned on it inside a player body, out along it (x) in one tick", flat(s.Root.Position, zinfo.Pos))
	-- straight SEP.Body: pinned on the east line, its own side partly blocked by the north line (0.3 of room): that part
	-- is taken back and it leaves to the other side, exactly to the body's edge
	w = spacingWorld()
	local unit = mon(w, "Slime", HI, ZHI - 0.3)
	w.SEP.Begin(list(w), {})
	local here = unit.Root.Position
	unit._sepAt, unit._sepFrom, unit._sepBox = here, here, w.SEP.Box(unit, here)
	w.SEP.Body(unit, HI - 1, ZHI - 0.4, here.Y)
	local out = math.sqrt((unit._sepAt.X - (HI - 1)) ^ 2 + (unit._sepAt.Z - (ZHI - 0.4)) ^ 2)
	check(math.abs(out - 2.5) < 1e-6 and unit._sepAt.Z < ZHI - 0.4 and unit._sepAt.X <= HI,
		"pinned, its own side blocked part way: back and out the other side, exactly r + 1 from the player",
		show({ out, unit._sepAt.Z - ZHI }))
	-- a corner (pinned on both lines), the player diagonally inside: out along one line, away from the corner
	for _, spot in { { -1, -1 }, { -0.5, -1.5 }, { -1.5, -0.5 } } do
		w = spacingWorld()
		local cinfo = playerAt("kid", HI + spot[1], ZHI + spot[2])
		s = mon(w, "Slime", HI, ZHI)
		for _ = 1, 2 do
			w.SEP.Begin(list(w), { cinfo })
			w.SEP.Resolve({ cinfo })
			w.SEP.Step(MC.AIInterval)
		end
		check(flat(s.Root.Position, cinfo.Pos) >= 2.5 - 1e-6 and s.Root.Position.X <= HI and s.Root.Position.Z <= ZHI,
			"in the corner of both lines, the player at (" .. spot[1] .. ", " .. spot[2] .. "): out of the body within two ticks",
			show({ flat(s.Root.Position, cinfo.Pos), s.Root.Position.X - HI, s.Root.Position.Z - ZHI }))
	end
end)

runGroup("zone edge arcs", function()
	local SEP = spacingWorld().SEP
	local box = { X0 = CX - 200, X1 = HI, Z0 = CZ - 200, Z1 = CZ + 200 }
	local function wrap(a) return (a + math.pi) % TAU - math.pi end
	check(SEP.Arc(CX, CZ, 5, box) == nil and SEP.Arc(HI - 5, CZ, 5, box) == nil and SEP.Arc(CX, CZ, 5, nil) == nil,
		"a ring inside the move rect (touching the line at most): no cut")
	-- a player 3 studs past the line: only the arc facing inside, half width acos(3 / r)
	local arc = SEP.Arc(HI + 3, CZ, 3.5, box)
	check(arc and math.abs(wrap((arc.A0 + arc.A1) / 2 - math.pi)) < 1e-9 and math.abs(arc.A1 - arc.A0 - 2 * math.acos(3 / 3.5)) < 1e-9,
		"3 studs past the line, ring 3.5: the 62 deg facing inside", show(arc))
	check(SEP.Arc(HI + 3, CZ, 2.5, box) == false and SEP.Arc(HI + 3, CZ, 3, box) == false,
		"a ring that does not reach the line: no room at all")
	-- 2 studs inside the line: everything but the arc around the outward direction
	arc = SEP.Arc(HI - 2, CZ, 3.5, box)
	check(arc and math.abs(wrap((arc.A0 + arc.A1) / 2 - math.pi)) < 1e-9 and math.abs(arc.A1 - arc.A0 - (TAU - 2 * math.acos(2 / 3.5))) < 1e-9,
		"2 studs inside the line: the ring minus the 110 deg past it", show(arc))
	-- a corner (1 stud inside both lines): the piece facing the inside diagonal
	local corner = { X0 = CX - 200, X1 = HI, Z0 = CZ - 200, Z1 = CZ + 10 }
	arc = SEP.Arc(HI - 1, CZ + 9, 3.5, corner)
	local want = TAU - math.pi / 2 - 2 * math.acos(1 / 3.5) -- the two cuts overlap: 90 deg + 2 x 73 deg out
	check(arc and math.abs(wrap((arc.A0 + arc.A1) / 2 + 3 * math.pi / 4)) < 1e-9 and math.abs(arc.A1 - arc.A0 - want) < 1e-9,
		"a corner: one piece, facing the inside diagonal, both cuts taken out", show(arc))
	-- a cut that wraps past 0 over a small one (0.6 past the x line, 3.49 from the z line): the small cut inside the big
	-- one adds nothing
	arc = SEP.Arc(HI + 0.6, CZ + 200 - 3.5 * math.cos(math.rad(5)), 3.5, box)
	local big = math.acos(-0.6 / 3.5)
	check(arc and math.abs(arc.A1 - arc.A0 - (TAU - 2 * big)) < 1e-9 and math.abs(wrap((arc.A0 + arc.A1) / 2 - math.pi)) < 1e-9,
		"a small cut inside a big one (across 0): only the big one counts", show(arc))
	-- a strip narrower than the ring: two pieces, the longer one is used
	local strip = { X0 = CX - 2, X1 = CX + 2.5, Z0 = CZ - 200, Z1 = CZ + 200 }
	arc = SEP.Arc(CX, CZ, 3.5, strip)
	check(arc and math.abs(arc.A1 - arc.A0 - (math.pi - math.acos(2 / 3.5) - math.acos(2.5 / 3.5))) < 1e-9,
		"a strip cutting the ring twice: one of its two pieces", show(arc))
	-- every member's room: the overlap of their arcs
	local ring = { { R = 3.5 }, { R = 4.7 } }
	arc = SEP.RingArc(ring, HI + 3, CZ, box)
	check(arc and math.abs(arc.A1 - arc.A0 - 2 * math.acos(3 / 3.5)) < 1e-9, "a ring of mixed radii: the overlap of their arcs", show(arc))
	check(SEP.RingArc({ { R = 2.5 }, { R = 4.7 } }, HI + 3, CZ, box) == false, "one member with no room: no room")
	check(SEP.RingArc(ring, CX, CZ, box) == nil and SEP.RingArc(ring, HI + 3, CZ, nil) == nil, "inside or no box: the whole ring")

	-- seeded random arcs (any side, mixed bodies): when SEP.Fits, SEP.SpreadArc keeps every slot inside the arc, every
	-- pair rA + rB apart and the order; it fits less than the whole ring
	local seed = 20261008
	local function rnd()
		seed = (seed * 48271) % 2147483647
		return (seed - 1) / 2147483646
	end
	local sizes = { 1.5, 1.65, 2.7, 1.25, 1.875 }
	local cases, bad, outside, reordered, firstBad = 0, 0, 0, 0, nil
	for _ = 1, 3000 do
		local mid = (rnd() * 2 - 1) * math.pi
		local half = 0.2 + rnd() * 2.6
		local a = { A0 = mid - half, A1 = mid + half }
		local n = 1 + math.floor(rnd() * 6)
		local list = {}
		for i = 1, n do
			local rad = sizes[1 + math.floor(rnd() * #sizes)]
			local ang = rnd() < 0.3 and mid + (rnd() - 0.5) * 0.2 or (rnd() * 2 - 1) * math.pi
			table.insert(list, { Id = i, A = ang, R = SEP.Ring({ _radius = rad }), Rad = rad })
		end
		if SEP.Fits(list, a) then
			cases += 1
			local was, order = {}, {}
			for _, e in list do table.insert(was, { Id = e.Id, A = e.A, R = e.R }) end
			for k, e in (SEP.Run(list, a, true)) do order[k] = e.Id end
			SEP.SpreadArc(list, a)
			local w = math.huge
			for i = 1, n do
				local e = list[i]
				if math.abs(wrap(e.A - mid)) > half + 1e-9 then outside += 1 end
				for j = i + 1, n do
					local f = list[j]
					local d = math.sqrt(e.R * e.R + f.R * f.R - 2 * e.R * f.R * math.cos(e.A - f.A))
					w = math.min(w, d - (e.Rad + f.Rad))
				end
			end
			if w < -1e-3 then
				bad += 1
				firstBad = firstBad or show({ before = was, arc = a })
			end
			for k, e in (SEP.Run(list, a, true)) do
				if e.Id ~= order[k] then
					reordered += 1
					break
				end
			end
		end
	end
	check(cases > 1000, "enough fitting random arcs", cases)
	check(bad == 0 and outside == 0, "every fitting arc: all slots inside it, all pairs rA + rB apart", show({ bad, outside, firstBad }))
	check(reordered == 0, "the order along the arc never changes", reordered)
	check(SEP.Fits({ { Id = 1, A = 0, R = 3.5, Rad = 1.5 }, { Id = 2, A = 0.1, R = 3.5, Rad = 1.5 } }, { A0 = -0.3, A1 = 0.3 }) == false
		and SEP.Fits({ { Id = 1, A = 0, R = 3.5, Rad = 1.5 } }, false) == false,
		"two slimes need 51 deg: not in a 34 deg arc; nobody fits where there is no room")
end)

runGroup("zone edge slots", function()
	-- six chasers coming from inside to a player at x = px; slots with the real rules, and the old ones (no box: the
	-- whole ring, then aiStep's clamp onto the line)
	local function edgeRing(px, noBox)
		local w = spacingWorld()
		if noBox then w.SEP.Box = function() return nil end end
		local info = playerAt("kid", px, CZ)
		local recs = {}
		for i, kind in { "Slime", "BigSlime", "Slime", "Slime", "BigSlime", "Slime" } do
			local a = math.pi + (i - 3.5) * 0.45
			table.insert(recs, mon(w, kind, px + math.cos(a) * 12, CZ + math.sin(a) * 12, { _target = info.Player }))
		end
		w.SEP.Begin(list(w), { info })
		local goals, raw = {}, {}
		for _, r in recs do
			raw[r] = w.SEP.Goal(r, info)
			goals[r] = w.Clamp(MEADOW, raw[r])
		end
		return w, info, recs, goals, raw
	end
	-- a player 3 studs past the meadow's east move line (still inside the meadow)
	local _, _, oldRecs, oldGoals = edgeRing(HI + 3, true)
	local worstOld, atOld = worstPair(oldRecs, 1, function(r) return oldGoals[r] end)
	check(worstOld < -1, "control: the whole ring clamped onto the line piles the slots up", show({ worstOld, atOld }))
	local w, info, recs, goals, raw = edgeRing(HI + 3)
	local worst, at = worstPair(recs, 1, function(r) return goals[r] end)
	check(worst >= -1e-6, "3 studs past the line: no two slots closer than rA + rB", show({ worst, at }))
	local bad, reach, rings = {}, 0, {}
	for _, r in recs do
		local g = raw[r]
		if g.X > HI + 1e-9 then table.insert(bad, r.Id .. " past the line") end
		if flat(g, info.Pos) < r._radius + 1 - 1e-6 then table.insert(bad, r.Id .. " in the body") end
		if flat(g, info.Pos) <= MC.AttackRange then reach += 1 end
		rings[w.SEP.Slots[r].Ring] = (rings[w.SEP.Slots[r].Ring] or 0) + 1
	end
	check(#bad == 0, "every slot inside the line (no clamp needed) and outside the player body", show(bad))
	check(reach >= 3, "the closest still attack from inside the line, the rest wait on outer rings", show({ reach, rings }))
	finding(string.format("player 3 studs past the move line, 6 chasers: old slots clamped onto the line worst %.2f studs, now %.3f; %d in reach",
		worstOld, worst, reach))
	-- away from the edge: the same slots as before
	local a1, i1, r1 = edgeRing(CX)
	local a2, _, r2 = edgeRing(CX, true)
	local same = true
	for k = 1, #r1 do
		local s1, s2 = a1.SEP.Slots[r1[k]], a2.SEP.Slots[r2[k]]
		if s1.Angle ~= s2.Angle or s1.Ring ~= s2.Ring then same = false end
	end
	check(same and i1 ~= nil, "away from the zone edge: exactly the slots of before")
	-- 2 studs inside the line (the ring crosses it): slots inside, apart
	w, info, recs, goals, raw = edgeRing(HI - 2)
	worst, at = worstPair(recs, 1, function(r) return goals[r] end)
	local pastAny = false
	for _, r in recs do
		if raw[r].X > HI + 1e-9 or flat(raw[r], info.Pos) < r._radius + 1 - 1e-6 then pastAny = true end
	end
	check(worst >= -1e-6 and not pastAny, "a player 2 studs inside the line: slots apart, none past it or in the body",
		show({ worst, at }))
	-- a player walking at the line (1 inside, 8 studs/s outward): the rings are cut where the player will be (SEP.Ahead,
	-- 2 studs past the line), like the slots SEP.Goal places there
	w = spacingWorld()
	info = playerAt("kid", HI - 1, CZ)
	info.Vel = vec(8, 0, 0)
	recs = {}
	for i = 1, 5 do
		local a = math.pi + (i - 3) * 0.5
		table.insert(recs, mon(w, "Slime", HI - 1 + math.cos(a) * 10, CZ + math.sin(a) * 10, { _target = info.Player }))
	end
	w.SEP.Begin(list(w), { info })
	local pastWalk = {}
	for _, r in recs do
		local g = w.SEP.Goal(r, info)
		if g.X > HI + 1e-9 then table.insert(pastWalk, r.Id .. "=" .. (g.X - HI)) end
	end
	check(#pastWalk == 0, "a player walking out over the line: every slot inside it (rings cut where it will be)", show(pastWalk))
	-- 5.5 studs past the line (nothing reaches it): waiting rings inside the line, the closest one clamped onto it
	w, info, recs, goals = edgeRing(HI + 5.5)
	worst, at = worstPair(recs, 1, function(r) return goals[r] end)
	check(worst >= -1e-6, "5.5 studs past the line: still no two slots touch", show({ worst, at }))
	-- review 2026-10-08 (2nd look): the closest one of a ring with no room is clamped onto the line, at a corner up to
	-- 6 x sqrt 2 from the ring centre and ahead of a running player farther still; the next ring starts outside that spot
	local ZHI = MEADOW.Center.Z + MEADOW.Size.Z / 2 - 6
	local function cornerRing(px, pz, vel)
		local cw = spacingWorld()
		local ci = playerAt("kid", px, pz)
		ci.Vel = vel
		local crecs = {}
		for i, kind in { "Slime", "Slime", "BigSlime", "Slime", "Slime", "BigSlime" } do
			local a = -3 * math.pi / 4 + (i - 3.5) * 0.2 -- all from inside the meadow (a player's chasers share its zone)
			table.insert(crecs, mon(cw, kind, px + math.cos(a) * 14, pz + math.sin(a) * 14,
				{ _target = ci.Player, ZoneId = "SlimeMeadow" }))
		end
		cw.SEP.Begin(list(cw), { ci })
		local cg = {}
		for _, r in crecs do cg[r] = cw.Clamp(MEADOW, cw.SEP.Goal(r, ci)) end
		return worstPair(crecs, 1, function(r) return cg[r] end)
	end
	worst, at = cornerRing(HI + 5.5, ZHI + 5.5)
	check(worst >= -1e-6, "a player at the zone's corner (5.5 past both lines): no two slots touch", show({ worst, at }))
	worst, at = cornerRing(HI + 3, CZ, vec(20, 0, 0))
	check(worst >= -1e-6, "a player 3 past the line running out at 20 studs/s (rings 4 studs ahead): no two slots touch",
		show({ worst, at }))
	-- the south / north line too (z): a player 3 studs past the north move line
	worst, at = cornerRing(CX, ZHI + 3)
	local zw = spacingWorld()
	local zi = playerAt("kid", CX, ZHI + 3)
	local zrecs = {}
	for i = 1, 6 do
		local a = -math.pi / 2 + (i - 3.5) * 0.45
		table.insert(zrecs, mon(zw, i % 3 == 0 and "BigSlime" or "Slime", CX + math.cos(a) * 12, ZHI + 3 + math.sin(a) * 12,
			{ _target = zi.Player }))
	end
	zw.SEP.Begin(list(zw), { zi })
	local zg, zpast = {}, 0
	for _, r in zrecs do
		zg[r] = zw.SEP.Goal(r, zi)
		zpast = math.max(zpast, zg[r].Z - ZHI)
	end
	local zworst = worstPair(zrecs, 1, function(r) return zg[r] end)
	check(worst >= -1e-6 and zworst >= -1e-6 and zpast <= 1e-9, "the north move line too: slots inside it, none touching",
		show({ worst, zworst, zpast }))
	-- a personal monster follows its owner anywhere: with one among a player's chasers the rings stay whole
	local pw = spacingWorld()
	local owner = playerAt("kid", HI + 4, CZ)
	local pet = mon(pw, "Slime", HI + 5, CZ - 2, { Owner = owner.Player })
	local zm = mon(pw, "Slime", HI - 8, CZ, { _target = owner.Player })
	pw.SEP.Begin(list(pw), { owner })
	local petGoal = pw.SEP.Goal(pet, owner)
	check(pw.SEP.Slots[pet] and pw.SEP.Slots[pet].Ring <= MC.AttackRange and pw.SEP.Slots[zm] ~= nil and petGoal.X > HI,
		"a personal monster among the chasers: whole rings (it stays in reach past the line beside its owner)",
		show({ pw.SEP.Slots[pet], petGoal.X - HI }))
end)

runGroup("zone edge crowd", function()
	-- 검수's case in motion: a player standing at the meadow's east edge (3 studs past the move line), 4 Shard + 2 King
	-- Slimes come from inside. Over the last 10 s of 25: nobody overlaps, nobody crosses the line, and they stand at their
	-- spots instead of walking against the slides. opts.Old = the old rules (whole slide refused at the line, no spread).
	local function edgeCrowd(old, path)
		local w = spacingWorld()
		if old then
				w.SEP.Box = function() return nil end
			local inset = MEADOW.Size.X / 2 - 6
			w.SEP.Fit = function(_, pos, delta) -- the old SEP.CanSlide: the end must stay inside the line
				local dest = pos + delta
				if math.abs(dest.X - MEADOW.Center.X) > inset or math.abs(dest.Z - MEADOW.Center.Z) > MEADOW.Size.Z / 2 - 6 then
					return nil
				end
				return delta
			end
		end
		local info = playerAt("kid", HI + 3, CZ)
		info.Path = path
		local start = path and path(0) or info.Pos
		local recs = {}
		for _, m in PACK do
			table.insert(recs, mon(w, m[1], start.X + m[2], start.Z + m[3], { ZoneId = "SlimeMeadow", _nextAttackAt = 0 }))
		end
		local sum, n, worst, walked, past = 0, 0, 0, 0, -math.huge
		simulate(w, info, recs, 100, { Measure = function(now)
			for _, r in recs do past = math.max(past, r.Root.Position.X - HI) end
			if now < 15 then return end
			local o = overlapNow(w, recs, info)
			sum += o
			n += 1
			worst = math.max(worst, o)
			for _, r in recs do walked += r._walked or 0 end
		end })
		return sum / n, worst, walked / #recs, past
	end
	local mean, worst, walked, past = edgeCrowd(false)
	check(mean < 0.05 and worst < 0.3, "at the edge: no overlap over the last 10 s (mean < 0.05, worst < 0.3)",
		show({ mean = mean, worst = worst }))
	check(past <= 1e-9, "nobody ever crosses the move line", past)
	check(walked < 2, "they stand at their spots (walked < 2 studs each over the last 10 s, no walking against the slides)", walked)
	local oldMean, oldWorst, oldWalked = edgeCrowd(true)
	check(oldMean > 0.3, "control: the old rules leave them inside each other at the line", show({ mean = oldMean, worst = oldWorst }))
	finding(string.format("edge crowd, last 10 s: mean deepest overlap %.3f (old %.3f), walked per monster %.2f (old %.2f) studs",
		mean, oldMean, walked, oldWalked))
	-- a player walking along the edge (2 studs past the line, 5 studs/s): the review bar still holds
	local alongPath = function(t) return vec(HI + 2, 3, CZ - 60 + 5 * t) end
	mean, worst, walked, past = edgeCrowd(false, alongPath)
	check(mean < 0.3 and worst < 1 and past <= 1e-9, "walking along the edge at 5 studs/s: mean < 0.3, worst < 1, nobody past the line",
		show({ mean = mean, worst = worst, past = past }))
	oldMean = edgeCrowd(true, alongPath)
	finding(string.format("walking along the edge 5 studs/s: mean deepest overlap %.3f (old rules %.3f)", mean, oldMean))
end)

------------------------------------------------------------------ two players side by side (review 2026-10-08)
-- 검수 2026-10-08: with two players standing 2 studs apart, a monster between them switched target every 0.5-0.75 s
-- (always the nearest one), so its ring slot jumped from one player to the other and its pushes moved its neighbours.
runGroup("target hold", function()
	local w = spacingWorld()
	local SEP = w.SEP
	check(SEP.TargetHold == 2 and SEP.TargetMargin == 3, "a target is kept 2 s, then given up only for a player 3 studs closer",
		show({ SEP.TargetHold, SEP.TargetMargin }))
	local A, B = playerAt("a", CX - 1, CZ), playerAt("b", CX + 1, CZ)
	local r = mon(w, "BigSlime", CX + 1, CZ - 4.7, { _target = A.Player, _targetAt = 0 })
	local function pick(now, plist) return SEP.Pick(r, plist or { A, B }, r.Root.Position, now) end
	check(pick(10) == A, "the other player 0.4 studs closer: it keeps its target", pick(10) and pick(10).Player.Name)
	r._target = nil
	check(pick(10) == B, "no target yet: the nearest one")
	r._target = B.Player
	r.Root.Position = vec(CX, 3, CZ - 5)
	check(pick(10) == B, "both as close: it keeps the one it has")
	-- players 6 apart, both out of reach (AttackRange 5.5): B 5.69 away, 3.27 studs closer than A
	A, B = playerAt("a", CX - 3, CZ), playerAt("b", CX + 3, CZ)
	r.Root.Position = vec(CX + 4, 3, CZ - 5.6)
	r._target, r._targetAt = A.Player, 0
	check(pick(10) == B, "another player more than 3 studs closer, target held 10 s: it switches")
	r._targetAt = 9
	check(pick(10) == A, "... but not within 2 s of taking its target (both out of reach)")
	-- review 2026-10-08: after the hold a target out of reach never beats a player in reach (else it stood in that
	-- player's reach and swung at nobody; with players under 3 studs apart the margin can never be met: |dA - dB| <= |AB|).
	-- Review 2026-10-08 (3rd round): within the hold it keeps its target anyway (taking the one in reach at once, a monster
	-- shoved across the reach edge in a crowd went A -> B -> A every 0.5 s); it idles at most those 2 s
	r.Root.Position = vec(CX + 3, 3, CZ - 4)
	check(MC.AttackRange == 5.5 and pick(10) == A, "within 2 s, its target 7.2 away and another player 4 away (in reach): "
		.. "it keeps its target (the hold comes first)", pick(10) and pick(10).Player.Name)
	local nearA, nearB = playerAt("a", CX, CZ), playerAt("b", CX + 2, CZ)
	r.Root.Position = vec(CX - 3.69, 3, CZ)
	r._target, r._targetAt = nearB.Player, 0
	check(pick(10, { nearA, nearB }) == nearA, "players 2 apart, its target 5.69 away (out of reach), the other 3.69, "
		.. "target held 10 s: it switches to the one in reach although only 2 studs closer")
	r._targetAt = 8.5
	check(pick(10, { nearA, nearB }) == nearB, "... but not within 2 s of taking its target")
	r._targetAt = 0
	r.Root.Position = vec(CX - 3.4, 3, CZ)
	check(pick(10, { nearA, nearB }) == nearB, "... and not with its target back in reach (5.4): it keeps it")
	r.Root.Position = vec(CX - 6, 3, CZ)
	check(pick(10, { nearA, nearB }) == nearB, "both out of reach (6 / 8), the other only 2 studs closer, held 10 s: it keeps "
		.. "its target")
	r.Root.Position = vec(CX + 4, 3, CZ - 5.6)
	r._target, r._targetAt = A.Player, 9
	check(pick(10, { B }) == B, "its target gone from the list: the nearest one at once")
	A.Town = true
	check(pick(10) == B, "its target in a town (not targetable): the nearest one at once")
	A.Town = false
	A.Pos = vec(CX - 40, 3, CZ)
	check(pick(10) == B, "its target beyond AggroRadius: the nearest one at once")
	A.Zone = "GoblinWoods"
	B.Zone = "GoblinWoods"
	check(pick(10) == nil, "nobody it may chase: none")
	-- a taunt that just ran out (SKL-3): a free pick, the nearest one at once (as main had it), not a hold on the taunter
	A.Zone, B.Zone = "SlimeMeadow", "SlimeMeadow"
	A.Pos = vec(CX - 3, 3, CZ)
	r._target, r._targetAt = A.Player, 9.5
	check(pick(10) == A and SEP.Pick(r, { A, B }, r.Root.Position, 10, true) == B,
		"after a taunt (free pick): the nearest one at once, no hold on the taunter")
	-- the wiring: aiStep picks with SEP.Pick (free right after a taunt) and stamps only a new target
	local ai = string.sub(MONSTER_SOURCE, string.find(MONSTER_SOURCE, "local function aiStep(", 1, true) or 1)
	local _, stamps = string.gsub(ai, "rec%._targetAt = now", "")
	check(has(ai, "best, bestD = SEP.Pick(rec, plist, pos, now, free)") and stamps == 1
		and has(ai, "if rec._target ~= best.Player then\n\t\t\trec._chaseStuck = 0\n\t\t\trec._targetAt = now")
		and has(ai, "local free = rec._tauntUntil ~= nil and now >= rec._tauntUntil and rec._target == rec._tauntBy")
		and has(ai, "if free then rec._tauntUntil, rec._tauntBy = nil, nil end")
		and not has(ai, "if d <= MC.AggroRadius and (bestD == nil or d < bestD) then"),
		"aiStep: the target comes from SEP.Pick (free when a taunt ran out), only a new one is stamped (rec._targetAt)",
		stamps)
end)

runGroup("two players", function()
	-- two players side by side (`apart` studs, standing or walking +x together at `speed`), 4 Shard + 2 King Slimes
	-- coming from behind: the old rule (the nearest one every tick) vs SEP.Pick. Target switches after each monster's
	-- first pick (Switches; Quick: within 2 s of taking its target, review 2026-10-08 3rd round; Far: to a player out of
	-- reach), the longest run of ticks a monster chased a target out of reach while the other player was in reach
	-- (IdleMax, review 2026-10-08), all swings, and the mean deepest overlap over the last 20 s of 25 (bodies, both players)
	local FROM = { { "BigSlime", -14, 0 }, { "Slime", -13, -6 }, { "Slime", -13, 6 }, { "Slime", -18, -3 }, { "Slime", -18, 3 },
		{ "BigSlime", -22, 0.3 } }
	local function pairProbe(nearest, apart, speed)
		local w = spacingWorld()
		local x0 = CX - (speed > 0 and 60 or 0)
		local A, B = playerAt("a", x0, CZ - apart / 2), playerAt("b", x0, CZ + apart / 2)
		A.Path = function(t) return vec(x0 + speed * t, 3, CZ - apart / 2) end
		B.Path = function(t) return vec(x0 + speed * t, 3, CZ + apart / 2) end
		local recs = {}
		for _, m in FROM do
			table.insert(recs, mon(w, m[1], x0 + m[2], CZ + m[3], { ZoneId = "SlimeMeadow", _nextAttackAt = 0 }))
		end
		local sum, n = 0, 0
		simulate(w, nil, recs, 100, { Players = { A, B }, Nearest = nearest, Measure = function(now)
			if now < 5 then return end
			sum += overlapNow(w, recs, { A, B })
			n += 1
		end })
		local p = { Switches = 0, Quick = 0, Far = 0, IdleMax = 0, Swings = 0, Mean = sum / n }
		for _, r in recs do
			p.Switches += math.max(0, (r._switches or 0) - 1) -- the first pick is no switch
			p.Quick += r._quick or 0
			p.Far += r._farSwitches or 0
			p.IdleMax = math.max(p.IdleMax, r._idleMax or 0)
			p.Swings += r._swings or 0
		end
		return p
	end
	local oldStand, stand = pairProbe(true, 2, 0), pairProbe(false, 2, 0)
	check(oldStand.Switches >= 4,
		"control: standing 2 studs apart, the nearest-every-tick rule makes them swap back and forth", oldStand.Switches)
	check(stand.Switches * 2 <= oldStand.Switches and stand.Quick == 0 and stand.Far == 0 and stand.Mean < 0.1,
		"standing 2 studs apart: no back and forth (never again within 2 s, only to a player in reach), no overlap",
		show(stand))
	local oldWalk, walk = pairProbe(true, 2, 5), pairProbe(false, 2, 5)
	check(oldWalk.Switches >= 10, "control: walking side by side, the old rule keeps switching", oldWalk.Switches)
	check(walk.Switches * 2 <= oldWalk.Switches and walk.Quick == 0 and walk.Far == 0 and walk.Mean < 0.3,
		"walking side by side at 5 studs/s: no back and forth, the review bar (mean < 0.3) holds", show(walk))
	finding(string.format("two players 2 studs apart, 6 monsters, 25 s: target switches standing %d (old rule %d), walking 5 studs/s " ..
		"%d (old %d); mean deepest overlap standing %.3f (old %.3f), walking %.3f (old %.3f)", stand.Switches, oldStand.Switches,
		walk.Switches, oldWalk.Switches, stand.Mean, oldStand.Mean, walk.Mean, oldWalk.Mean))
	local oldS4, s4 = pairProbe(true, 4, 0), pairProbe(false, 4, 0)
	local oldW4, w4 = pairProbe(true, 4, 5), pairProbe(false, 4, 5)
	check(s4.Quick == 0 and w4.Quick == 0 and s4.Far == 0 and w4.Far == 0 and s4.Mean < 0.1 and w4.Mean < 0.3,
		"4 studs apart (standing / walking): no back and forth either, no pile", show({ s4, w4 }))
	-- review 2026-10-08: a held target out of reach keeps a monster idle in the other player's reach at most the 2 s hold
	-- (8 AI ticks; before, a King Slime stood 22 s in B's reach chasing A), so they swing about as often as under the
	-- old rule
	local idle, swings, oldSwings = 0, {}, {}
	for k, pair in { { stand, oldStand }, { walk, oldWalk }, { s4, oldS4 }, { w4, oldW4 } } do
		idle = math.max(idle, pair[1].IdleMax)
		swings[k], oldSwings[k] = pair[1].Swings, pair[2].Swings
	end
	local swingsOk = true
	for k in swings do swingsOk = swingsOk and swings[k] >= 0.9 * oldSwings[k] end
	check(idle <= 2 / MC.AIInterval and swingsOk, "2 / 4 studs apart, standing / walking: nobody chases a target out of "
		.. "reach for longer than the 2 s hold while the other player is in reach, swings >= 90% of the old rule's",
		show({ idleMax = idle, swings = swings, old = oldSwings }))
	finding(string.format("two players, swings standing / walking: 2 apart %d / %d (old rule %d / %d), " ..
		"4 apart %d / %d (old %d / %d); longest idle in the other player's reach %d ticks", swings[1], swings[2], oldSwings[1],
		oldSwings[2], swings[3], swings[4], oldSwings[3], oldSwings[4], idle))
end)

runGroup("two players crowd", function()
	-- review 2026-10-08 (3rd round): the 6-monster pack above is too small to show it. The meadow mix (12 Shard + 4 King
	-- Slimes from spots 8-20 studs around, a fixed pseudo-random draw per seed) around two players 2 / 4 studs apart, side
	-- by side or in line, standing or walking 5 studs/s together, 40 s, seeds 12345 / 4242 (16 runs): SEP.Pick vs the old
	-- rule (the nearest one every tick). With the reach rule ahead of the hold (2nd round) a monster shoved across the reach
	-- edge (mostly off a slot inside the other player's body) went A -> B -> A every 0.5 s, its slot jumping each time.
	local function crowd(nearest, seed, apart, speed, inline)
		local w = spacingWorld()
		local x0 = CX - (speed > 0 and 60 or 0)
		local ax, az, bx, bz = x0, CZ - apart / 2, x0, CZ + apart / 2
		if inline then ax, az, bx, bz = x0 - apart / 2, CZ, x0 + apart / 2, CZ end
		local A, B = playerAt("a", ax, az), playerAt("b", bx, bz)
		A.Path = function(t) return vec(ax + speed * t, 3, az) end
		B.Path = function(t) return vec(bx + speed * t, 3, bz) end
		local recs = {}
		for i = 1, 16 do
			seed = (seed * 1103515245 + 12345) % 2147483648
			local ang = TAU * seed / 2147483648
			seed = (seed * 1103515245 + 12345) % 2147483648
			local rr = 8 + 12 * seed / 2147483648
			table.insert(recs, mon(w, i <= 12 and "Slime" or "BigSlime", x0 + math.cos(ang) * rr, CZ + math.sin(ang) * rr,
				{ ZoneId = "SlimeMeadow", _nextAttackAt = 0 }))
		end
		local sum, n = 0, 0
		simulate(w, nil, recs, 160, { Players = { A, B }, Nearest = nearest, Measure = function(now)
			if now < 5 then return end
			sum += overlapNow(w, recs, { A, B })
			n += 1
		end })
		local p = { Switches = 0, Quick = 0, Flips = 0, IdleMax = 0, Swings = 0, Mean = sum / n }
		for _, r in recs do
			p.Switches += math.max(0, (r._switches or 0) - 1)
			p.Quick += r._quick or 0
			p.Flips += r._flips or 0
			p.IdleMax = math.max(p.IdleMax, r._idleMax or 0)
			p.Swings += r._swings or 0
		end
		return p
	end
	local new = { Switches = 0, Quick = 0, Flips = 0, IdleMax = 0, Swings = 0, Mean = 0, Worst = 0 }
	local old = table.clone(new)
	for _, seed in { 12345, 4242 } do
		for _, apart in { 2, 4 } do
			for _, speed in { 0, 5 } do
				for _, inline in { false, true } do
					for t, p in { [new] = crowd(false, seed, apart, speed, inline), [old] = crowd(true, seed, apart, speed, inline) } do
						for _, k in { "Switches", "Quick", "Flips", "Swings", "Mean" } do t[k] += p[k] end
						t.IdleMax = math.max(t.IdleMax, p.IdleMax)
						t.Worst = math.max(t.Worst, p.Mean)
					end
				end
			end
		end
	end
	check(old.Flips >= 1000, "control: the old rule flips them A -> B -> A all the time", show(old))
	check(new.Quick == 0, "nobody switches target again within 2 s of taking one (the hold comes first)", show(new))
	check(new.Flips * 5 <= old.Flips, "back to the target before (A -> B -> A) at most 20% as often as the old rule "
		.. "(and never within 2 s)", show({ new = new.Flips, old = old.Flips }))
	check(new.IdleMax <= 2 / MC.AIInterval, "nobody chases a target out of reach for longer than the 2 s hold while the "
		.. "other player is in reach", new.IdleMax)
	check(new.Swings >= 0.9 * old.Swings, "they swing at least 90% as often as under the old rule",
		show({ new = new.Swings, old = old.Swings }))
	check(new.Mean <= 1.25 * old.Mean and new.Worst < 1, "about the old rule's pile (the runs' mean deepest overlap at most "
		.. "1.25x its, every run < 1 stud)", show({ new = new.Mean, old = old.Mean, worst = new.Worst }))
	finding(string.format("crowd of 12 + 4 around two players 2 / 4 apart, 16 runs of 40 s: target switches %d (old rule %d), "
		.. "within 2 s %d (old %d), A -> B -> A %d (old %d), longest idle in the other player's reach %d ticks, swings %d (old %d), "
		.. "mean deepest overlap %.3f (old %.3f) per run", new.Switches, old.Switches, new.Quick, old.Quick, new.Flips, old.Flips,
		new.IdleMax, new.Swings, old.Swings, new.Mean / 16, old.Mean / 16))
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
	check(has(ai, "rec._walkTo = homeDest") and has(ai, "rec._walkTo = rec._goal -- A23-74: SEP.Walk (still on its way)"),
		"aiStep: the walk home and a wander still on its way tell SEP.Walk where they go")
	-- review 2026-10-08: the last few studs of a wander too (the Humanoid still walks there; a push near the move line
	-- carried the body past it when SEP.Add did not know that point)
	local lastBit = string.find(ai, "if rec._goal then rec._walkTo = rec._goal end\n\t\tNATURAL.Idle(rec, pos, plist, now)", 1, true)
	check(lastBit ~= nil, "aiStep: a wander's last few studs (the idle branch) also tell SEP.Walk its MoveTo point")
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
