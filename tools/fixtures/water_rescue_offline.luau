-- water_rescue_offline.luau : zone_check_halo_2026-10-10 #11 / #62 / #63 (게임성 개발 2, 검수 2026-10-10).
-- tools/test_water_rescue.py binds CONFIG_SOURCE, UTIL_SOURCE and ZONE_WATER_SOURCE (the CURRENT ZoneService.luau plus one
-- appended line that hands this test updateZone / cleanup / water / waterProbe / move / nearTown) in front of dev2_kit.luau.
-- The WHOLE ZoneService runs (zone loop body, gates, CR-H2 track, A10, teleport, spawn CFrames); only the engine is doubled:
-- the rule groups swap waterProbe for a fake world (w.Map(x, z) -> a column), the probe groups run the real waterProbe on a
-- fake workspace / Terrain / Raycast / GetPartBoundsInBox.

local TICK = 0.2 -- Config.Travel.ZoneTick
local WATER = -1.2 -- Config.Map.WaterTop = halo_terrain G.WaterTop

local function zoneWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	w.Kaiju, w.Ready, w.List, w.ParamsMade, w.OverlapMade = {}, {}, {}, 0, 0
	w.Groups = { Players = true } -- PlayerService registers Config.Player.CollisionGroup at start
	w.Services.PhysicsService = { IsCollisionGroupRegistered = function(_, n) return w.Groups[n] == true end }
	local Signal = w.Util.Signal
	local ps = { PlayerReady = Signal.new(), CharacterSpawned = Signal.new(), PlayerLeaving = Signal.new() }
	function ps.IsReady(p) return w.Ready[p] == true end
	function ps.GetReadyPlayers()
		local out = {}
		for _, p in w.List do
			if w.Ready[p] then table.insert(out, p) end
		end
		return out
	end
	function ps.MarkActive() end
	local reg = { PlayerService = ps, KaijuService = { GetState = function(p) return w.Kaiju[p] or "None" end } }
	local ws = newInstance("Workspace", w)
	ws.Name = "Workspace"
	ws.GetServerTimeNow = function() return w.Time end
	local terrain = newInstance("Terrain", w)
	terrain.Name = "Terrain"
	terrain.Parent = ws
	ws.Terrain = terrain
	local env = w:Env()
	env.workspace = ws
	env.Region3 = { new = function(a, b) return { __kind = "Region3", Min = a, Max = b } end }
	env.RaycastParams = { new = function() w.ParamsMade += 1; return { __kind = "RaycastParams" } end }
	env.OverlapParams = { new = function() w.OverlapMade += 1; return { __kind = "OverlapParams" } end }
	local Z = execute("ZoneService", ZONE_WATER_SOURCE, env)
	Z.Init(reg)
	w.Z, w.T, w.PS, w.WS, w.Terrain = Z, Z.__WaterTest, ps, ws, terrain
	local P = w.T.waterProbe
	w.Real = { Surface = P.Surface, Ground = P.Ground, Clear = P.Clear }
	w.Calls = { Surface = 0, Ground = 0, Clear = 0 }
	return w
end

-- the rule groups: waterProbe answers from map(x, z) -> nil (nothing) or a column { Water = surface Y | nil, Floor = Y,
-- Walkable = false | nil, NormalY, Material, Blocked }. Water above the floor answers as a Water hit (the rays do not
-- ignore water).
local function fakeProbes(w, map)
	w.Map = map
	local P = w.T.waterProbe
	P.Surface = function(pos)
		w.Calls.Surface += 1
		local c = w.Map(pos.X, pos.Z)
		return c and c.Water or nil
	end
	P.Ground = function(origin, length)
		w.Calls.Ground += 1
		local c = w.Map(origin.X, origin.Z)
		if not c then return nil end
		local wet = c.Water ~= nil and c.Water > c.Floor
		local y = wet and c.Water or c.Floor
		if origin.Y - length > y then return nil end
		return { Position = vec(origin.X, y, origin.Z), NormalY = c.NormalY or 1,
			Material = wet and "Material.Water" or (c.Material or "Material.Limestone"), Walkable = c.Walkable ~= false }
	end
	P.Clear = function(center, size)
		w.Calls.Clear += 1
		w.LastBox = { Center = center, Size = size }
		local c = w.Map(center.X, center.Z)
		return not (c and c.Blocked)
	end
end

local function sea() return { Water = WATER, Floor = -6, Material = "Material.Sand" } end
local function land(y, extra)
	local c = { Floor = y, Material = "Material.Concrete" }
	for k, v in extra or {} do c[k] = v end
	return c
end
-- a Halo canal at x in (-20, 20): a low terrace west (x <= -20, Y 0.2 like spine tier 1), a high one east (Y 7 like WB)
local function canal(x, _z)
	if x <= -20 then return land(0.2) end
	if x >= 20 then return land(7) end
	return sea()
end
local function allSea() return sea() end
local function allLand() return land(0.2) end
-- bands around a centre: band(d, dx, dz) -> column, d = flat distance from (cx, cz)
local function rings(cx, cz, band)
	return function(x, z) return band(math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2), x - cx, z - cz) end
end

local function swimmer(w, id, pos, attrs)
	local a = { Faction = "Halo", Level = 5 }
	for k, v in attrs or {} do a[k] = v end
	local p = w:NewPlayer(id, a)
	local s = { P = p }
	function s:Body(at)
		local char = newInstance("Model", w)
		char.Name = "Char" .. id
		local hum = newInstance("Humanoid", w)
		hum.Health, hum.WalkSpeed, hum.HipHeight = 100, 16, 2
		hum.Parent = char
		local root = newInstance("Part", w)
		root.Name = "HumanoidRootPart"
		root.Position, root.Size, root.AssemblyLinearVelocity = at, vec(2, 2, 1), vec(0, -3, 0)
		root.Parent = char
		char.Pivots = {}
		char.PivotTo = function(_, cf)
			table.insert(char.Pivots, cf)
			root.Position = cf.Args[1]
		end
		char.Parent = w.WS
		self.Char, self.Root, self.Hum = char, root, hum
		p.Character = char
	end
	s:Body(pos)
	w.Ready[p] = true
	table.insert(w.List, p)
	w.PS.PlayerReady:Fire(p)
	return s
end

-- the zone loop: every TICK s one updateZone per ready player (like ZoneService.Start's loop)
local function tick(w, seconds)
	for _ = 1, math.max(1, math.floor(seconds / TICK + 0.5)) do
		w.Clock += TICK
		for _, p in w.List do
			if w.Ready[p] then w.T.updateZone(p) end
		end
	end
end

-- an 8 s count that is already over: the next sample rescues (the landing rules without the timing)
local function rescueNow(w, list)
	for _, s in list do
		w.T.water[s.P] = { Char = s.Char, Since = w.Clock - 100, NextAt = 0 }
	end
	tick(w, TICK)
end

local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-6) end
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
local function lines(w, s, from)
	local out = {}
	for _, t in w:NoticesFor(s.P, from) do
		if t == w.Config.Text.WaterRescue then table.insert(out, t) end
	end
	return out
end

------------------------------------------------------------------ config
runGroup("config", function()
	local w = zoneWorld()
	local C = w.Config
	local WR = C.WaterRescue
	check(type(WR) == "table" and WR.Enabled == true, "Config.WaterRescue exists and is on", show(WR and WR.Enabled))
	check(WR.Seconds == 8 and WR.Margin == 40, "8 s in water, 40 studs around a town rect (검수 10/10)", show({ WR.Seconds, WR.Margin }))
	check(type(WR.CheckEvery) == "number" and WR.CheckEvery > 0 and WR.CheckEvery <= 1
		and WR.DryReset >= 1 and WR.DryReset < WR.Seconds,
		"a sample every <= 1 s; a dry spell under DryReset (a swim jump) keeps the count", show({ WR.CheckEvery, WR.DryReset }))
	check(WR.MaxSlope < 46, "landing slope below the players' MaxSlopeAngle 46", tostring(WR.MaxSlope))
	check(WR.MaxRise >= 40 and WR.RayTop > WR.MaxRise, "a bank beside the Halo top tier / wings (Y 33 + 1.2 + mounds) is in reach",
		show({ WR.MaxRise, WR.RayTop }))
	check(table.find(WR.AvoidMaterials, "CrackedLava") ~= nil, "Horns lava strips are never a landing spot", show(WR.AvoidMaterials))
	local ok = #WR.Rings >= 4 and WR.Rings[1] <= 8 and WR.Rings[#WR.Rings] >= 60
	for i = 2, #WR.Rings do
		if WR.Rings[i] <= WR.Rings[i - 1] then ok = false end
	end
	check(ok, "rings nearest first, from <= 8 to >= 60 studs", show(WR.Rings))
	local line = C.Text.WaterRescue
	local words = 0
	for _ in string.gmatch(line or "", "%S+") do words += 1 end
	check(type(line) == "string" and words >= 2 and words <= 12 and not string.find(line, "[\128-\255]"),
		"Text.WaterRescue: easy English, <= 12 words, ASCII", tostring(line))
	check(C.Map.WaterTop == WATER, "the sea / canal surface is Y -1.2 (Config.Map.WaterTop)", tostring(C.Map.WaterTop))
end)

------------------------------------------------------------------ where the rule applies
runGroup("town area", function()
	local w = zoneWorld()
	local function id(x, z)
		local t = w.T.nearTown(vec(x, 0, z))
		return t and t.Id or "-"
	end
	check(id(0, -500) == "HaloTown", "inside the Halo rect (a canal)", id(0, -500))
	check(id(239, -500) == "HaloTown" and id(-239, -600) == "HaloTown", "39 studs outside the Halo rect (east / west sea)",
		id(239, -500) .. " " .. id(-239, -600))
	check(id(241, -500) == "-" and id(-241, -600) == "-", "41 studs outside: no town area", id(241, -500))
	check(id(0, -739) == "HaloTown" and id(0, -741) == "-", "the far end: z -700 - 40", id(0, -739) .. " " .. id(0, -741))
	check(id(0, -292) == "HaloTown", "the strait 38 studs off the Halo gate end", id(0, -292))
	check(id(0, -240) == "-", "mid strait (z -240) lies between the Crossroads and Halo margins", id(0, -240))
	check(id(185, 0) == "Crossroads" and id(185, 60) == "Crossroads", "the Crossroads river by the meadow bridge", id(185, 60))
	check(id(0, 515) == "HornsTown" and id(0, 735) == "HornsTown", "Horns Den and its far sea", id(0, 735))
	check(id(430, 0) == "-" and id(680, 100) == "-" and id(1520, 0) == "-", "meadow, goblin river, ruins: no town area",
		id(430, 0) .. id(680, 100) .. id(1520, 0))
end)

------------------------------------------------------------------ the 8 s rule
runGroup("8 s in a row in a canal", function()
	local w = zoneWorld()
	fakeProbes(w, canal)
	local s = swimmer(w, 1, vec(0, -0.5, -500))
	tick(w, TICK) -- the first wet sample
	tick(w, 7.6)
	check(#s.Char.Pivots == 0 and s.Root.Position.Y == -0.5, "still swimming 7.6 s after the first wet sample", show(s.Root.Position))
	local before = #w.Notices
	tick(w, 1.0)
	local at = s.Root.Position
	check(#s.Char.Pivots == 1, "moved once by 8.6 s", #s.Char.Pivots)
	check(at.X < -19.5 and at.X > -25 and near(at.Y, 0.2 + 4),
		"onto the LOW terrace (Y 0.2 + Lift 4), not the Y 7 one across the canal", show(at))
	local cf = s.Char.Pivots[1]
	check(cf and cf.Ctor == "lookAt" and cf.Args[2].X < cf.Args[1].X and near(cf.Args[2].Y, cf.Args[1].Y),
		"facing inland (away from the water), level", show(cf and cf.Args))
	local g = w.T.move.lastGood[s.P]
	check(w.Z.IsTeleportGrace(s.P) == true and (g == nil or flat(g.Pos, at) < 1e-6),
		"CR-H2: teleport grace on, the movement track restarts at the shore", show(g and g.Pos))
	local v = s.Root.AssemblyLinearVelocity
	check(v.X == 0 and v.Y == 0 and v.Z == 0, "velocity cleared", show(v))
	local box = w.LastBox
	check(box and near(box.Center.Y, 0.2 + 0.5 + 3) and box.Size.X == 3 and box.Size.Y == 6,
		"room check: a 3 x 6 x 3 body box from 0.5 above the landing spot", show(box))
	local said = w:NoticesFor(s.P, before)
	check(#said == 1 and said[1] == w.Config.Text.WaterRescue, "one line: Text.WaterRescue", show(said))
	check(w:SoundsFor(s.P, before)[1] == "None", "no sound with it (happens to me)", show(w:SoundsFor(s.P, before)))
	check(w.T.water[s.P] ~= nil and w.T.water[s.P].Since == nil, "the count restarts after the rescue", "")
	tick(w, 10) -- on the shore: no second move, no CR-H2 suspicious-move log (the group's warning check)
	check(#s.Char.Pivots == 1, "on the shore: no second move", #s.Char.Pivots)
	check(s.P:GetAttribute("ZoneId") == "HaloTown", "the zone loop goes on (ZoneId HaloTown)", tostring(s.P:GetAttribute("ZoneId")))
end)

runGroup("Toast off", function()
	local w = zoneWorld({ EditConfig = function(c) c.WaterRescue.Toast = false end })
	fakeProbes(w, canal)
	local s = swimmer(w, 1, vec(0, -0.5, -500))
	rescueNow(w, { s })
	check(#s.Char.Pivots == 1 and #lines(w, s) == 0, "Toast = false: moved without a line", show(w:NoticesFor(s.P)))
end)

runGroup("dry spells", function()
	local w = zoneWorld()
	fakeProbes(w, canal)
	local jump = swimmer(w, 1, vec(-5, -0.5, -520))
	local leave = swimmer(w, 2, vec(5, -0.5, -560))
	tick(w, TICK) -- t1: both wet
	tick(w, 4)
	jump.Root.Position = vec(-5, 2.5, -520) -- a swim jump at the wall: the root 3.7 above the water for 1 s
	leave.Root.Position = vec(5, 2.5, -560) -- out of the water for 2 s
	tick(w, 1.0)
	jump.Root.Position = vec(-5, -0.5, -520)
	tick(w, 1.0)
	leave.Root.Position = vec(5, -0.5, -560)
	tick(w, 2.6) -- t1 + 8.6
	check(#jump.Char.Pivots == 1, "a 1 s swim jump keeps the count: rescued 8.6 s after the first wet sample", #jump.Char.Pivots)
	check(#leave.Char.Pivots == 0, "2 s out of the water restarts the count", #leave.Char.Pivots)
	tick(w, 6.6) -- t1 + 15.2: about 8.4 s after getting back in
	check(#leave.Char.Pivots == 1, "... and 8 s after getting back in it is rescued", #leave.Char.Pivots)
end)

runGroup("shallow water", function()
	local w = zoneWorld()
	-- a spring basin on a Y 7 terrace east of x 40 (floor 5.5, water 6.6: halo_terrain FALL Dip 1.5 / Drop 0.4); sea elsewhere
	fakeProbes(w, function(x, _z)
		if x > 40 then return { Water = 6.6, Floor = 5.5 } end
		return sea()
	end)
	local wader = swimmer(w, 1, vec(60, 8.5, -500)) -- standing in the basin: root 3 above its floor, 1.9 above the water
	local floating = swimmer(w, 2, vec(0, -0.25, -520)) -- root 0.95 above the surface: a swimmer
	local above = swimmer(w, 3, vec(10, -0.15, -540)) -- root 1.05 above the surface: not in water
	tick(w, 12)
	check(#wader.Char.Pivots == 0, "a foot-deep spring basin is not 'in water' (surface 1.9 under the root)", #wader.Char.Pivots)
	check(#floating.Char.Pivots == 1, "a root 0.95 above the surface counts (RootSlack 1)", #floating.Char.Pivots)
	check(#above.Char.Pivots == 0, "a root 1.05 above the surface does not", #above.Char.Pivots)
end)

runGroup("away from the towns", function()
	local w = zoneWorld()
	fakeProbes(w, allSea)
	local river = swimmer(w, 1, vec(680, -0.5, 100)) -- the goblin river (Outskirts)
	local strait = swimmer(w, 2, vec(0, -0.5, -240)) -- mid strait between the Crossroads and Halo margins
	tick(w, 20)
	check(#river.Char.Pivots == 0 and #strait.Char.Pivots == 0, "no rescue away from the towns (outside every margin)", "")
	check(w.Calls.Surface == 0, "... and no Terrain read there", w.Calls.Surface)
end)

runGroup("sample rate", function()
	local w = zoneWorld()
	fakeProbes(w, allLand)
	swimmer(w, 1, vec(0, 3.2, -450)) -- dry in town: sampled, never moved
	tick(w, 12) -- 60 zone ticks
	check(w.Calls.Surface >= 15 and w.Calls.Surface <= 26, "one Terrain read per CheckEvery (0.5 s), not per zone tick (0.2 s)",
		w.Calls.Surface)
end)

------------------------------------------------------------------ where it lands
local function ringWorld(band, attrs)
	local w = zoneWorld()
	fakeProbes(w, rings(0, -500, band))
	local s = swimmer(w, 1, vec(0, -0.5, -500), attrs)
	rescueNow(w, { s })
	return w, s, s.Root.Position, flat(s.Root.Position, vec(0, 0, -500))
end
-- d < 5: water; ring 6 (5 <= d < 8): the trap; ring 10 (8 <= d < 12): a good shore Y 1.2; farther: water
local function trapped(trap)
	return function(d)
		if d >= 5 and d < 8 then return trap end
		if d >= 8 and d < 12 then return land(1.2) end
		return sea()
	end
end

runGroup("landing rules", function()
	for _, case in {
		{ "a roof (not Terrain / Ground / bridge)", land(3, { Walkable = false }) },
		{ "a puddle on a ledge (the ray meets water first)", { Water = 1.8, Floor = 1.2 } },
		{ "a ledge only 0.2 above the water (DryAbove 0.5)", land(-1.0) },
		{ "too steep (60 deg, MaxSlope 40)", land(2, { NormalY = 0.5 }) },
		{ "too high (43 above the water, MaxRise 42)", land(42) },
		{ "a lava strip (AvoidMaterials)", land(1.2, { Material = "Material.CrackedLava" }) },
		{ "no room (a prop in the body box)", land(1.2, { Blocked = true }) },
	} do
		local _, _, at, d = ringWorld(trapped(case[2]))
		check(d > 9 and d < 11 and near(at.Y, 1.2 + 4), case[1] .. ": skipped, the shore 10 studs away is taken", show(at))
	end
	-- the lowest climb inside one ring: high (Y 7) from angle 0 to 90 deg (found first), low (Y 1.2) on the -x half
	local _, _, at = ringWorld(function(d, dx)
		if d < 5 then return sea() end
		return dx > -0.5 and land(7) or land(1.2)
	end)
	check(at.X < 0 and near(at.Y, 1.2 + 4), "inside a ring the lowest climb wins", show(at))
	-- the nearest ring wins over a lower shore farther away
	local _, _, at2, d2 = ringWorld(function(d)
		if d < 5 then return sea() end
		if d < 8 then return land(7) end
		return land(0.2)
	end)
	check(d2 > 5 and d2 < 7 and near(at2.Y, 7 + 4), "the nearest ring wins over a lower shore farther away", show(at2))
	-- a gentle slope (30 deg) is fine
	local _, _, at3, d3 = ringWorld(function(d)
		if d < 5 then return sea() end
		return land(1.2, { NormalY = math.cos(math.rad(30)) })
	end)
	check(d3 > 5 and d3 < 7 and near(at3.Y, 5.2), "a 30 deg shore is a landing spot", show(at3))
	-- nothing dry within 80 studs: the A10 home spawn
	local w4 = zoneWorld()
	fakeProbes(w4, allSea)
	local s4 = swimmer(w4, 4, vec(0, -0.5, -500))
	rescueNow(w4, { s4 })
	local p4 = s4.Root.Position
	check(#s4.Char.Pivots == 1 and near(p4.Y, 4) and math.abs(p4.X) <= 6 and math.abs(p4.Z + 420) <= 6,
		"nothing dry within 80 studs: the Halo home spawn (0, 4, -420) +-6", show(p4))
	check(w4.Z.IsTeleportGrace(s4.P) == true and #lines(w4, s4) == 1, "... with the CR-H2 grace and the line", "")
end)

runGroup("enemy town and kaiju", function()
	-- the sea 25 studs east of the Halo rect (Outskirts, inside the 40-stud margin); the only land is Halo island (x <= 195)
	local w = zoneWorld()
	fakeProbes(w, function(x, _z)
		if x <= 195 then return land(0.2) end
		return sea()
	end)
	local halo = swimmer(w, 1, vec(225, -0.5, -500), { Faction = "Halo" })
	local horns = swimmer(w, 2, vec(225, -0.5, -560), { Faction = "Horns" })
	local kaiju = swimmer(w, 3, vec(225, -0.5, -620), { Faction = "Halo" })
	w.Kaiju[kaiju.P] = "Active"
	rescueNow(w, { halo, horns, kaiju })
	local a, b, c = halo.Root.Position, horns.Root.Position, kaiju.Root.Position
	check(a.X <= 195 and near(a.Y, 4.2), "a Halo player lands on the Halo shore", show(a))
	check(near(b.Y, 4) and math.abs(b.X) <= 6 and math.abs(b.Z + 25) <= 6,
		"a Horns player is never put into the Halo town: the Crossroads spawn (0, 4, -25), no free trip home", show(b))
	check(near(c.Y, 4) and math.abs(c.X) <= 6 and math.abs(c.Z + 25) <= 6,
		"an Active kaiju (no faction town, not even its own): the Crossroads spawn", show(c))
	tick(w, 1)
	check(horns.P:GetAttribute("ZoneId") == "Crossroads" and #w:NoticesFor(horns.P) == 1,
		"no enemy-town bounce afterwards (only the rescue line)", show(w:NoticesFor(horns.P)))
	-- an Active kaiju in the Crossroads river: the Crossroads shore is fine for it (normal rules)
	local w2 = zoneWorld()
	fakeProbes(w2, function(x, _z)
		if x <= 150 then return land(0.2) end
		return sea()
	end)
	local k2 = swimmer(w2, 4, vec(175, -0.5, 60), { Faction = "Horns" })
	w2.Kaiju[k2.P] = "Active"
	rescueNow(w2, { k2 })
	check(k2.Root.Position.X <= 150 and near(k2.Root.Position.Y, 4.2), "an Active kaiju in the Crossroads river lands on the Crossroads shore",
		show(k2.Root.Position))
	-- nothing dry near the Crossroads: its spawn, not the Halo home far away
	local w3 = zoneWorld()
	fakeProbes(w3, allSea)
	local h3 = swimmer(w3, 5, vec(175, -0.5, 60), { Faction = "Halo" })
	rescueNow(w3, { h3 })
	local p3 = h3.Root.Position
	check(near(p3.Y, 4) and math.abs(p3.X) <= 6 and math.abs(p3.Z + 25) <= 6,
		"nothing dry near the Crossroads: its spawn (0, 4, -25), not the far home town", show(p3))
	-- an R6 body: HipHeight 0, the legs carry the root (stand = 0 + 1 + 2 = 3: a 6-tall body box, the root 4 up)
	local w4 = zoneWorld()
	fakeProbes(w4, canal)
	local r6 = swimmer(w4, 6, vec(0, -0.5, -500))
	r6.Hum.HipHeight, r6.Hum.RigType = 0, "HumanoidRigType.R6"
	local leg = newInstance("BasePart", w4)
	leg.Name, leg.Size = "Left Leg", vec(1, 2, 1)
	leg.Parent = r6.Char
	rescueNow(w4, { r6 })
	check(#r6.Char.Pivots == 1 and w4.LastBox ~= nil and near(w4.LastBox.Size.Y, 6) and near(r6.Root.Position.Y, 4.2),
		"an R6 body gets an R6-tall body box (6) and stands on the shore", show(w4.LastBox and w4.LastBox.Size))
end)

------------------------------------------------------------------ lifecycle
runGroup("dead, not ready, a new character", function()
	local w = zoneWorld()
	fakeProbes(w, canal)
	local dead = swimmer(w, 1, vec(0, -0.5, -500))
	dead.Hum.Health = 0
	local idle = swimmer(w, 2, vec(5, -0.5, -540))
	w.Ready[idle.P] = false
	tick(w, 12)
	check(#dead.Char.Pivots == 0 and #idle.Char.Pivots == 0, "a dead or not-ready player is never moved", "")
	check(w.Calls.Surface == 0, "... and costs no Terrain read", w.Calls.Surface)
	local s = swimmer(w, 3, vec(-5, -0.5, -560))
	tick(w, TICK)
	tick(w, 6)
	local old = s.Char
	s:Body(vec(-5, -0.5, -560)) -- a respawn (a new character) in the same water
	tick(w, 6)
	check(#old.Pivots == 0 and #s.Char.Pivots == 0, "a new character starts its own 8 s", #s.Char.Pivots)
	tick(w, 3)
	check(#s.Char.Pivots == 1, "... and is rescued 8 s after its own first wet sample", #s.Char.Pivots)
end)

runGroup("leave", function()
	local w = zoneWorld()
	fakeProbes(w, canal)
	local s = swimmer(w, 1, vec(0, -0.5, -500))
	tick(w, 2)
	check(w.T.water[s.P] ~= nil, "a water state while in town", "")
	w.PS.PlayerLeaving:Fire(s.P)
	w:Flush()
	check(w.T.water[s.P] == nil, "PlayerLeaving -> cleanup forgets it", "")
end)

runGroup("A10 first", function()
	local w = zoneWorld()
	fakeProbes(w, allSea)
	local s = swimmer(w, 1, vec(0, -25, -500))
	tick(w, TICK)
	check(#s.Char.Pivots == 1 and near(s.Root.Position.Y, 4) and w.Calls.Surface == 0,
		"below Y -20 the A10 rescue runs (home spawn) and the water tick is not reached", show(s.Root.Position))
end)

runGroup("a probe error is contained", function()
	local w = zoneWorld()
	fakeProbes(w, canal)
	w.AllowWarn = "water rescue error"
	w.T.waterProbe.Surface = function() error("terrain read failed") end
	local s = swimmer(w, 1, vec(0, -0.5, -500))
	local ok = pcall(tick, w, 2)
	check(ok, "updateZone never throws for a water probe error", "")
	check(s.P:GetAttribute("ZoneId") == "HaloTown", "the zone bookkeeping before it still ran", tostring(s.P:GetAttribute("ZoneId")))
	local n = 0
	for _, t in w.Warnings do
		if string.find(t, "water rescue error", 1, true) then n += 1 end
	end
	check(n == 1, "one throttled warning", n)
end)

------------------------------------------------------------------ the real probes on engine doubles
runGroup("Terrain water probe", function()
	local w = zoneWorld()
	local reads = {}
	-- liquid occupancy of the voxel whose bottom is y (sea level -1.2 by default)
	w.Liquid = function(y) return math.clamp((WATER - y) / 4, 0, 1) end
	-- shorelines on: water in LiquidOccupancy; w.SolidWater: shorelines off, water as SolidMaterial Water + SolidOccupancy
	w.Terrain.ReadVoxelChannels = function(_, region, res, channels)
		table.insert(reads, { Region = region, Res = res, Channels = channels })
		if w.ChannelsFail then error("no channels") end
		local liq, mat, occ = {}, {}, {}
		for j = 1, 3 do
			local o = w.Liquid(region.Min.Y + (j - 1) * res)
			if w.SolidWater then
				liq[j], mat[j], occ[j] = { 0 }, { o > 0 and "Material.Water" or "Material.Air" }, { o }
			else
				liq[j], mat[j], occ[j] = { o }, { "Material.Air" }, { 0 }
			end
		end
		return { LiquidOccupancy = { liq }, SolidMaterial = { mat }, SolidOccupancy = { occ } }
	end
	local S = w.Real.Surface
	local y = S(vec(10.5, -0.5, -501.3))
	local r = reads[1]
	check(y ~= nil and near(y, WATER), "sea level read back as -1.2 (voxel bottom + 4 x 0.7)", tostring(y))
	check(r ~= nil and r.Res == 4 and r.Region.Min.X == 8 and r.Region.Min.Y == -8 and r.Region.Min.Z == -504
		and r.Region.Max.X == 12 and r.Region.Max.Y == 4 and r.Region.Max.Z == -500,
		"a grid-aligned 1 x 3 x 1 column of 4-stud voxels: one below the root's voxel, the root's, one above",
		show(r and { r.Region.Min, r.Region.Max }))
	check(r ~= nil and table.find(r.Channels, "LiquidOccupancy") ~= nil and table.find(r.Channels, "SolidMaterial") ~= nil
		and table.find(r.Channels, "SolidOccupancy") ~= nil, "reads LiquidOccupancy + SolidMaterial / SolidOccupancy", show(r and r.Channels))
	w.SolidWater = true
	check(near(S(vec(10.5, -0.5, -501.3)) or -99, WATER), "shorelines off (SolidMaterial Water + SolidOccupancy): the same -1.2",
		tostring(S(vec(10.5, -0.5, -501.3))))
	w.SolidWater = false
	check(near(S(vec(0, -9, -500)) or -99, -4), "a diver: the column is full, the top of the last voxel", tostring(S(vec(0, -9, -500))))
	w.Liquid = function(y0) return (y0 == 4) and (6.6 - 4) / 4 or 0 end -- a spring basin: water 4..6.6
	check(near(S(vec(60, 8.5, -500)) or -99, 6.6), "a spring basin: its own surface (6.6)", tostring(S(vec(60, 8.5, -500))))
	w.Liquid = function(y0) if y0 == -8 then return 1 elseif y0 == -4 then return 0.5 end return 0 end
	check(near(S(vec(0, -0.5, -500)) or -99, -2), "the highest wet voxel decides (full below, half in the root's)", tostring(S(vec(0, -0.5, -500))))
	w.Liquid = function() return 0.01 end
	check(S(vec(0, -0.5, -500)) == nil, "a film (<= 0.02) is no water", "")
	w.Liquid = function() return 0 end
	check(S(vec(0, 3, -450)) == nil, "dry: nil", "")
	-- fallback: ReadVoxels (Material Water)
	w.ChannelsFail = true
	w.Liquid = function(y0) return math.clamp((WATER - y0) / 4, 0, 1) end
	w.Terrain.ReadVoxels = function(_, region, res)
		local m, o = { {} }, { {} }
		for j = 1, 3 do
			local occ = w.Liquid(region.Min.Y + (j - 1) * res)
			m[1][j] = { occ > 0 and "Material.Water" or "Material.Air" }
			o[1][j] = { occ }
		end
		return m, o
	end
	check(near(S(vec(10.5, -0.5, -501.3)) or -99, WATER), "ReadVoxelChannels missing: ReadVoxels gives the same surface", "")
	w.Terrain.ReadVoxels = function() error("no voxels") end
	local ok, v = pcall(S, vec(0, -0.5, -500))
	check(ok and v == nil, "both reads fail: nil, never thrown", tostring(v))
end)

runGroup("ground and room probes", function()
	local w = zoneWorld()
	local function inst(class, name, parent)
		local i = newInstance(class, w)
		i.Name = name
		i.Parent = parent
		return i
	end
	local map = inst("Folder", "Map", w.WS)
	local ground = inst("Folder", "Ground", map)
	local decor = inst("Folder", "Decor", map)
	local deck = inst("Part", "Deck", inst("Model", "Bridge_Halo", decor))
	local roof = inst("Part", "Roof", inst("Model", "Cell_0_-512", inst("Folder", "HaloProps", decor)))
	local pad = inst("Part", "Pad_Meadow", inst("Folder", "Pads", map))
	local fakeGround = inst("Part", "Slab", inst("Model", "Ground", decor))
	local plate = inst("Part", "Plate", ground)
	local casts = {}
	w.WS.Raycast = function(_, origin, dir, params)
		table.insert(casts, { Origin = origin, Dir = dir, Params = params })
		if w.RayFail then error("ray failed") end
		return w.NextHit
	end
	local G = w.Real.Ground
	local function hitOn(i, mat)
		w.NextHit = { Position = vec(1, 2, 3), Normal = vec(0, 0.9, 0.1), Material = mat or "Material.Concrete", Instance = i }
		return G(vec(1, 62, 3), 70)
	end
	local h = hitOn(w.Terrain)
	check(h ~= nil and h.Walkable == true and h.NormalY == 0.9 and h.Position.Y == 2 and h.Material == "Material.Concrete",
		"Terrain: walkable; position / normal / material passed on", show(h))
	local c = casts[1]
	check(c.Dir.X == 0 and c.Dir.Y == -70 and c.Dir.Z == 0 and c.Origin.Y == 62, "straight down, the asked length", show(c.Dir))
	local p = c.Params
	check(p.FilterType == "RaycastFilterType.Include" and p.IgnoreWater == false and p.RespectCanCollide == true,
		"Terrain + Map only, water NOT ignored, non-colliding parts ignored",
		show({ p.FilterType, tostring(p.IgnoreWater), tostring(p.RespectCanCollide) }))
	check(p.CollisionGroup == "Players", "rays query as a player (Players group: A23-81 player-only decor is seen)",
		tostring(p.CollisionGroup))
	check(#p.FilterDescendantsInstances == 2 and p.FilterDescendantsInstances[1] == w.Terrain and p.FilterDescendantsInstances[2] == map,
		"the list is { Terrain, workspace.Map } (characters, monsters, pets are never hit)", "")
	check(hitOn(plate).Walkable == true, "a part under Map.Ground is walkable", "")
	check(hitOn(deck).Walkable == true, "a Map.Decor Bridge_* deck is walkable", "")
	check(hitOn(roof).Walkable == false, "a Halo prop (Map.Decor.HaloProps) is no landing spot", "")
	check(hitOn(pad).Walkable == false, "a travel pad is no landing spot", "")
	check(hitOn(fakeGround).Walkable == false, "a model named Ground inside Decor is not the map ground", "")
	check(hitOn(nil).Walkable == false, "no instance: not walkable", "")
	w.NextHit = nil
	check(G(vec(0, 60, 0), 70) == nil, "nothing hit: nil", "")
	w.RayFail = true
	local ok, v = pcall(G, vec(0, 60, 0), 70)
	check(ok and v == nil, "an engine error: nil, never thrown", tostring(v))
	w.RayFail = false
	check(w.ParamsMade == 1, "the ray params are built once ...", w.ParamsMade)
	map.Parent = nil -- MapBuilder.Rebuild(): a new workspace.Map
	local map2 = inst("Folder", "Map", w.WS)
	w.Clock += 6
	hitOn(w.Terrain)
	check(w.ParamsMade == 2 and casts[#casts].Params.FilterDescendantsInstances[2] == map2, "... and rebuilt after 5 s (the new Map)",
		w.ParamsMade)
	local boxes = {}
	w.WS.GetPartBoundsInBox = function(_, cf, size, params)
		table.insert(boxes, { CF = cf, Size = size, Params = params })
		if w.BoxFail then error("overlap failed") end
		return w.BoxParts or {}
	end
	local Cl = w.Real.Clear
	check(Cl(vec(1, 5, 3), vec(3, 6, 3)) == true, "an empty body box: room", "")
	local b = boxes[1]
	check(b.CF.Ctor == "new" and b.CF.Args[1].Y == 5 and b.Size.Y == 6, "the box is centred where asked, the asked size", show(b.Size))
	check(b.Params.FilterType == "RaycastFilterType.Include" and b.Params.FilterDescendantsInstances[1] == map2
		and b.Params.RespectCanCollide == true, "only collidable Map parts count",
		show({ b.Params.FilterType, tostring(b.Params.RespectCanCollide) }))
	check(b.Params.CollisionGroup == "Players", "the body box queries as a player too", tostring(b.Params.CollisionGroup))
	w.BoxParts = { roof }
	check(Cl(vec(1, 5, 3), vec(3, 6, 3)) == false, "a prop in the box: no room", "")
	w.BoxParts, w.BoxFail = nil, true
	local ok2, v2 = pcall(Cl, vec(1, 5, 3), vec(3, 6, 3))
	check(ok2 and v2 == false, "an engine error: no room (another spot, or the home spawn)", tostring(v2))
	w.Groups.Players, w.BoxFail = nil, false -- the players' group failed to register: keep the default group
	w.Clock += 6
	Cl(vec(1, 5, 3), vec(3, 6, 3))
	check(boxes[#boxes].Params.CollisionGroup == nil, "no players' group registered: the default group",
		tostring(boxes[#boxes].Params.CollisionGroup))
end)

runGroup("end to end on the engine doubles", function()
	local w = zoneWorld()
	local map = newInstance("Folder", w)
	map.Name = "Map"
	map.Parent = w.WS
	-- a canal |x| < 20 (water -1.2): Terrain land Y 0.2 west, Y 7 east
	local function floorAt(x)
		if x <= -20 then return 0.2 end
		if x >= 20 then return 7 end
		return nil
	end
	w.Terrain.ReadVoxelChannels = function(_, region, res)
		local wet = floorAt(region.Min.X + 2) == nil
		local col = {}
		for j = 1, 3 do
			col[j] = { wet and math.clamp((WATER - (region.Min.Y + (j - 1) * res)) / res, 0, 1) or 0 }
		end
		return { LiquidOccupancy = { col } }
	end
	w.WS.Raycast = function(_, origin)
		local f = floorAt(origin.X)
		if f then
			return { Position = vec(origin.X, f, origin.Z), Normal = vec(0, 1, 0), Material = "Material.Concrete", Instance = w.Terrain }
		end
		return { Position = vec(origin.X, WATER, origin.Z), Normal = vec(0, 1, 0), Material = "Material.Water", Instance = w.Terrain }
	end
	w.WS.GetPartBoundsInBox = function() return {} end
	local s = swimmer(w, 1, vec(1, -0.5, -500))
	tick(w, TICK)
	tick(w, 9)
	check(#s.Char.Pivots == 1 and s.Root.Position.X <= -20 and near(s.Root.Position.Y, 4.2),
		"Terrain read + rays + room check: out of the canal onto the low side", show(s.Root.Position))
end)

finish()
