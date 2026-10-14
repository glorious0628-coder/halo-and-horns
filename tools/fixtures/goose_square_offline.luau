-- goose_square_offline.luau : A23-141 the Goose Square (게임성 개발 2, 2026-10-12) - GooseSquare.luau's space (the place's
-- model / the stand-in, marks + offsets), Join gates, the remote, auto combat pause / restore, every leave path, the way
-- back, ReturnAll, the tick (falls, GooseJoinBlock) and Inside. tools/test_goose_square.py binds CONFIG_SOURCE,
-- UTIL_SOURCE and SQUARE_SOURCE; dev2_kit.luau comes first. GooseSquare.World is replaced by the doubles below.

-- a translation-only CFrame double (GooseSquare only needs .Position, PointToObjectSpace and lookAt / new)
local cfmt = {}
cfmt.__index = function(c, key)
	if key == "Position" then return c.P end
	if key == "PointToObjectSpace" then return function(self, v) return v - self.P end end
	return nil
end
local function cf(p) return setmetatable({ P = p, __kind = "CFrame" }, cfmt) end
local CF = {
	new = function(x, y, z)
		if type(x) == "table" then return cf(x) end
		return cf(vec(x or 0, y or 0, z or 0))
	end,
	lookAt = function(a) return cf(a) end,
}

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function flatDist(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

-- a player double: attributes, a Parent, a root CFrame (nil = dead)
local function newPlayer(name, opts)
	opts = opts or {}
	local p = { Name = name, Parent = true, Attrs = {}, Faction = opts.Faction or "Halo", Ready = opts.Ready ~= false,
		Root = opts.Root ~= nil and opts.Root or cf(vec(0, 3, -25)), KaijuState = opts.KaijuState or "None", Sack = opts.Sack == true,
		InCombat = opts.InCombat == true, Stars = opts.Stars or 0, Zone = opts.Zone or "Crossroads", SavedAuto = opts.SavedAuto == true }
	function p:GetAttribute(k) return self.Attrs[k] end
	function p:SetAttribute(k, v) self.Attrs[k] = v end
	if opts.Auto ~= nil then p.Attrs.AutoCombatEnabled = opts.Auto end
	return p
end

-- a model double for workspace.GooseSquare: attributes <Mark>Pos, parts by name (a part = { Position, IsA })
local function newModel(attrs, parts)
	local m = { Attrs = attrs or {}, Parts = parts or {} }
	function m:GetAttribute(k) return self.Attrs[k] end
	function m:FindFirstChild(name) return self.Parts[name] end
	return m
end
local function part(pos, size, see)
	local pt = { Position = pos, Size = size, CFrame = cf(pos), CanCollide = true, Transparency = see and 1 or 0 }
	function pt:IsA(c) return c == "BasePart" end
	return pt
end

-- a fresh GooseSquare with its doubles; opts.Active (default true), opts.Model (a model double, nil = none yet)
local function square(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	w.Services.CollectionService = { AddTag = function() end }
	local env = w:Env()
	env.CFrame = CF
	local GS = execute("GooseSquare", SQUARE_SOURCE, env)
	local G = { World = w, GS = GS, C = w.Config, Pivots = {}, Builds = 0, Leaves = {}, Model = opts.Model, Players = {},
		Clock = 1000, Active = opts.Active ~= false, Town = {} }
	local GW = GS.World
	function GW.Clock() return G.Clock end
	function GW.Random() return 0.5 end
	function GW.Ready(p) return p.Ready end
	function GW.Players() return G.Players end
	function GW.Alive(p) return p.Root ~= nil end
	function GW.Faction(p) return p.Faction end
	function GW.KaijuState(p) return p.KaijuState end
	function GW.Sack(p) return p.Sack end
	function GW.InCombat(p) return p.InCombat end
	function GW.Stars(p) return p.Stars end
	function GW.CrossroadsCF() G.Crossroads = (G.Crossroads or 0) + 1 return cf(vec(0, 4, -25)) end
	function GW.RootCF(p) return p.Root end
	function GW.Pivot(p, c)
		table.insert(G.Pivots, { P = p, CF = c })
		p.Root = c
		return true
	end
	function GW.ZoneId(p) return p.Zone end
	function GW.KillY() return -500 end
	function GW.TownCF(p)
		local c = cf(vec(0, 4, p.Faction == "Horns" and 515 or -515))
		table.insert(G.Town, p)
		return c
	end
	function GW.SavedAuto(p) return p.SavedAuto end
	function GW.Model() return G.Model end
	function GW.Build(into)
		G.Builds += 1
		G.BuiltInto = into
		if into then
			into.Parts.StandInFloor = part(G.C.Goose.SquareSpace.Center, G.C.Goose.SquareSpace.Size)
			into.Parts.Floor = into.Parts.Floor or into.Parts.StandInFloor
			return into
		end
		local c, size = G.C.Goose.SquareSpace.Center, G.C.Goose.SquareSpace.Size
		local attrs = {}
		for name, off in G.C.Goose.SquareSpace.Offsets do attrs[name .. "Pos"] = c + off end
		G.Model = newModel(attrs, { Floor = part(c - vec(0, size.Y / 2, 0), size) })
		return G.Model
	end
	GS.Init({}, {
		IsActive = function() return G.Active end,
		OnLeave = function(p, reason) table.insert(G.Leaves, { P = p, Reason = reason }) end,
	})
	function G.Add(p) table.insert(G.Players, p) return p end
	return G
end

------------------------------------------------------------------ the space
runGroup("space", function()
	local G = square()
	local SP = G.C.Goose.SquareSpace
	check(SP.Enabled == true and near(SP.Center.X, 6000) and near(SP.Center.Y, 200) and near(SP.Center.Z, 6000)
		and SP.ReturnAfter == 4 and G.C.PvP.NoTravelStars == 3, "Config.Goose.SquareSpace: on, centre (6000, 200, 6000), back after 4 s",
		show({ SP.Center.X, SP.Center.Y, SP.Center.Z, SP.ReturnAfter }))
	check(G.C.RateLimits.GooseSquare == 1, "RateLimits.GooseSquare = 1", "")
	local s = G.GS.Ensure()
	check(G.Builds == 1 and G.Model ~= nil, "no model in the place: the stand-in is built once", G.Builds)
	check(near(s.Nest.Z, SP.Center.Z - 37) and near(s.Cart.Z, SP.Center.Z + 37) and near(s.SpawnHalo.Z, SP.Center.Z - 24)
		and near(s.SpawnHorns.Z, SP.Center.Z + 24) and near(s.SpawnNeutral.X, SP.Center.X - 22),
		"the stand-in marks: nest north (-37), cart south (+37), spawns +-24, Neutral west", show({ s.Nest.Z, s.Cart.Z }))
	G.GS.Ensure()
	check(G.Builds == 1, "a second Ensure reads the built model (never a second build)", G.Builds)

	-- the place's model wins: attributes first, a part by name next, a missing mark = GooseSpot + its offset
	local spot = vec(100, 50, 100)
	local H = square({ Model = newModel({ GooseSpotPos = spot, NestPos = vec(100, 50, 70), SpawnHaloPos = vec(100, 50, 80) },
		{ Cart = part(vec(100, 51, 133)), SpawnHorns = part(vec(100, 50, 120)), Floor = part(vec(100, 48, 100), vec(110, 4, 90)) }) })
	local t = H.GS.Ensure()
	check(H.Builds == 0 and near(t.GooseSpot.X, 100) and near(t.Nest.Z, 70) and near(t.Cart.Z, 133) and near(t.SpawnHorns.Z, 120),
		"a model in the place: its attributes / parts are the marks, nothing is built", show({ H.Builds, t.Nest.Z, t.Cart.Z }))
	check(near(t.SpawnNeutral.X, 100 - 22) and near(t.SpawnNeutral.Z, 100), "a missing mark = GooseSpot + its Config offset (SpawnNeutral)",
		show({ t.SpawnNeutral.X, t.SpawnNeutral.Z }))
	check(near(t.AreaSize.X, 110) and near(t.AreaCF.Position.Y, 48), "the Floor part is the area", "")

	-- a model without a floor you can see / stand on (an unfinished skeleton) gets the stand-in floor, keeps its marks
	local skel = newModel({ GooseSpotPos = spot, NestPos = vec(100, 50, 70) }, { Floor = part(vec(100, 48, 100), vec(110, 4, 90), true) })
	local K = square({ Model = skel })
	local u = K.GS.Ensure()
	check(K.Builds == 1 and K.BuiltInto == skel and skel.Parts.StandInFloor ~= nil and near(u.Nest.Z, 70),
		"a see-through Floor: the stand-in floor goes into that model, its marks stay", show({ K.Builds, u.Nest.Z }))
	K.GS.Ensure()
	check(K.Builds == 1, "once it has the floor, no second build", K.Builds)
	local bare = square({ Model = newModel({ GooseSpotPos = spot }, {}) })
	bare.GS.Ensure()
	check(bare.Builds == 1 and bare.BuiltInto ~= nil, "a model with no Floor at all gets the stand-in floor", bare.Builds)
	local HF = G.GS.World.HasFloor
	local fm = { IsA = function(_, c) return c == "Model" end }
	function fm:GetDescendants() return { part(vec(0, 0, 0), vec(4, 1, 4), true), part(vec(0, 0, 0), vec(4, 1, 4)) } end
	local holder = newModel({}, { Floor = fm })
	check(HF(holder) == true and HF(nil) == false, "a Floor model with one solid, visible part is a floor; no model = none", "")
	local ghost = part(vec(0, 0, 0), vec(4, 1, 4))
	ghost.CanCollide = false
	check(HF(newModel({}, { Floor = ghost })) == false, "a Floor you fall through is no floor", "")

	-- the square went after the start (or was never built): Join builds it before moving the player there
	local J = square()
	J.GS.Ensure()
	J.Model = nil
	local pj = J.Add(newPlayer("J"))
	local okJ = J.GS.Join(pj)
	check(okJ == true and J.Builds == 2 and J.Model ~= nil and #J.Pivots == 1, "Join with the square gone: built again, then moved",
		show({ okJ, J.Builds, #J.Pivots }))
end)

------------------------------------------------------------------ Inside
runGroup("inside", function()
	local G = square()
	local SP = G.C.Goose.SquareSpace
	local c = SP.Center
	G.GS.Ensure()
	check(G.GS.Inside(c + vec(0, 3, 0)) and G.GS.Inside(c + vec(55 + SP.Margin - 1, 3, 0)), "on the floor (and Margin off its edge) = inside", "")
	check(not G.GS.Inside(c + vec(55 + SP.Margin + 1, 3, 0)) and not G.GS.Inside(c + vec(0, 3, 45 + SP.Margin + 1)),
		"past the edge + Margin = outside", "")
	check(not G.GS.Inside(c + vec(0, -SP.FallBelow - 1, 0)) and G.GS.Inside(c + vec(0, -SP.FallBelow + 1, 0)),
		"FallBelow under the floor top = outside", "")
	check(not G.GS.Inside(nil) and not G.GS.Inside(vec(0, 3, 0)), "the Crossroads / nil = outside", "")
end)

------------------------------------------------------------------ Join gates
runGroup("join", function()
	local G = square()
	local SP = G.C.Goose.SquareSpace
	local s = G.GS.Ensure()
	local p = G.Add(newPlayer("halo"))
	G.Active = false
	local ok, key = G.GS.Join(p)
	check(ok == false and key == "Closed" and p.Attrs.InGooseSquare == nil, "no goose: Join refused (Closed)", show({ ok, key }))
	G.Active = true
	local dead = G.Add(newPlayer("dead", { Root = false }))
	dead.Root = nil
	check(select(2, G.GS.Join(dead)) == "Dead", "dead: Dead", "")
	for _, st in { "Queued", "Siren", "Active" } do
		check(select(2, G.GS.Join(G.Add(newPlayer("kaiju" .. st, { KaijuState = st })))) == "Monster", "the kaiju (" .. st .. "): Monster", st)
	end
	check(select(2, G.GS.Join(G.Add(newPlayer("sack", { Sack = true })))) == "Grudge", "a grudge sack: Grudge", "")
	check(select(2, G.GS.Join(G.Add(newPlayer("fight", { InCombat = true })))) == "PvP", "the PvP combat tag (IsInCombat, Travel's rule): PvP", "")
	check(select(2, G.GS.Join(G.Add(newPlayer("wanted3", { Stars = 3 })))) == "PvP", "3 wanted stars (NoTravelStars): PvP", "")
	local f11 = G.Add(newPlayer("stars2", { Stars = 2 }))
	check(G.GS.Join(f11) == true, "2 stars, no combat tag: in", "")
	local none = G.Add(newPlayer("none", { Faction = "None" }))
	check(G.GS.Join(none) == false and select(2, G.GS.Join(none)) == nil, "no side yet: refused without a line", "")
	local notReady = G.Add(newPlayer("loading", { Ready = false }))
	check(G.GS.Join(notReady) == false, "not ready: refused", "")
	-- the join itself
	G.Pivots = {}
	check(G.GS.Join(p) == true and p.Attrs.InGooseSquare == true and G.GS.IsIn(p), "a Halo player joins: InGooseSquare", "")
	local to = G.Pivots[1] and G.Pivots[1].CF.Position
	check(#G.Pivots == 1 and to and flatDist(to, s.SpawnHalo) <= SP.SpawnSpread + 1e-6 and near(to.Y, s.SpawnHalo.Y + 3.5),
		"moved to the Halo spawn (within SpawnSpread, 3.5 up)", show(to and { to.X, to.Y, to.Z }))
	check(G.GS.Join(p) == false, "already in: refused", "")
	local horns = G.Add(newPlayer("horns", { Faction = "Horns" }))
	G.GS.Join(horns)
	check(flatDist(horns.Root.Position, s.SpawnHorns) <= SP.SpawnSpread + 1e-6, "Horns -> the Horns spawn", "")
	local artisan = G.Add(newPlayer("artisan", { Faction = "Neutral" }))
	check(G.GS.Join(artisan) == true and flatDist(artisan.Root.Position, s.SpawnNeutral) <= SP.SpawnSpread + 1e-6,
		"the artisan guild joins too (the Neutral spawn)", "")
	check(#G.GS.Members() == 4 and G.GS.TakeJoins() == 4 and G.GS.TakeJoins() == 0, "Members / TakeJoins count the joins", #G.GS.Members())
end)

------------------------------------------------------------------ the remote
runGroup("remote", function()
	local G = square({ EditConfig = function(c)
		c.Goose.Square = { Remote = "GooseSquare", Attr = "InGooseSquare", Block = "GooseJoinBlock",
			Text = { Closed = "The goose is gone.", PvP = "You can't join during a fight." } }
	end })
	G.GS.Ensure()
	local p = G.Add(newPlayer("p"))
	G.GS.OnRemote(p)
	G.GS.OnRemote(p, "Join", "extra")
	G.GS.OnRemote(p, 5)
	G.GS.OnRemote(p, "join")
	check(p.Attrs.InGooseSquare == nil and #G.World.Notices == 0, "bad arguments are ignored (0 / 2 args, a number, 'join')", "")
	G.Clock, G.World.Clock = 1000, 1000
	G.GS.OnRemote(p, "Join")
	check(p.Attrs.InGooseSquare == true, "'Join' joins", "")
	check(G.GS.CountIn("Halo") == 1 and G.GS.CountIn("Horns") == 0, "③ CountIn: one Knight in the square, no Legion", show({ G.GS.CountIn("Halo"), G.GS.CountIn("Horns") }))
	G.GS.OnRemote(p, "Leave")
	check(p.Attrs.InGooseSquare == true, "a second call within RateLimits.GooseSquare is ignored", "")
	G.World.Clock = 1002
	G.GS.OnRemote(p, "Leave")
	check(p.Attrs.InGooseSquare == false, "'Leave' leaves", "")
	G.Active = false
	G.World.Clock = 1004
	G.GS.OnRemote(p, "Join")
	-- A23-191 (최종 검수 10/14): a refusal says nothing (the Join button is dimmed by GooseJoinBlock)
	check(#G.World.Notices == 0 and p.Attrs.InGooseSquare == false, "a refusal says nothing (no toast)", #G.World.Notices)
	-- no client table (game dev 1's Config.Goose.Square taken away): no line, never an error
	local H = square({ EditConfig = function(c) c.Goose.Square = nil end })
	H.Active = false
	local q = H.Add(newPlayer("q"))
	H.GS.OnRemote(q, "Join")
	check(#H.World.Notices == 0 and q.Attrs.InGooseSquare == nil, "no Config.Goose.Square yet: a refusal says nothing", "")
end)

------------------------------------------------------------------ auto combat
runGroup("auto combat", function()
	local G = square()
	G.GS.Ensure()
	local p = G.Add(newPlayer("auto", { Auto = true, SavedAuto = true }))
	G.GS.Join(p)
	check(p.Attrs.AutoCombatEnabled == false, "joining pauses auto combat (the attribute)", "")
	G.GS.Leave(p, "Button")
	check(p.Attrs.AutoCombatEnabled == true, "leaving restores it from the save", "")
	local q = G.Add(newPlayer("manual", { Auto = false, SavedAuto = false }))
	G.GS.Join(q)
	G.GS.Leave(q, "Button")
	check(q.Attrs.AutoCombatEnabled == false, "auto combat off stays off", "")
	local r = G.Add(newPlayer("toggled", { Auto = true, SavedAuto = true }))
	G.GS.Join(r)
	r.SavedAuto = false -- the player turned it off in the save meanwhile
	G.GS.Leave(r, "Button")
	check(r.Attrs.AutoCombatEnabled == false, "the restore follows the save (the player's latest choice)", "")
end)

------------------------------------------------------------------ leave paths + the way back
runGroup("leave", function()
	local G = square()
	G.GS.Ensure()
	local spot = cf(vec(10, 3, -40)) -- the Crossroads (a town, no PvP)
	local p = G.Add(newPlayer("p", { Root = spot }))
	G.GS.Join(p)
	G.Pivots = {}
	check(G.GS.Leave(p, "Button") == true and p.Attrs.InGooseSquare == false and not G.GS.IsIn(p), "Leave: out, InGooseSquare false", "")
	check(#G.Leaves == 1 and G.Leaves[1].Reason == "Button", "the carried eggs go back first (OnLeave with the reason)", show(G.Leaves[1]))
	check(#G.Pivots == 1 and G.Pivots[1].CF == spot, "moved back to the spot Join was pressed at", "")
	check(G.GS.Leave(p, "Button") == false and #G.Leaves == 1, "leaving twice does nothing", "")
	for _, reason in { "Death", "Left", "Travel", "Moved" } do
		local q = G.Add(newPlayer(reason, { Root = cf(vec(5, 3, -40)) }))
		G.GS.Join(q)
		G.Pivots = {}
		G.GS.Leave(q, reason)
		check(#G.Pivots == 0 and q.Attrs.InGooseSquare == false, reason .. ": out without a move (already going elsewhere)", "")
	end
	local f = G.Add(newPlayer("faction", { Root = cf(vec(5, 3, -40)) }))
	G.GS.Join(f)
	G.Pivots = {}
	G.GS.Leave(f, "Faction")
	check(#G.Pivots == 1, "a faction change: moved back", "")
	-- the way back's rules
	local function wayBackOf(root, zone, opts)
		local H = square()
		H.GS.Ensure()
		local q = H.Add(newPlayer("q", { Root = root, Zone = zone, Faction = opts and opts.Faction }))
		H.GS.Join(q)
		H.Pivots = {}
		H.GS.Leave(q, "Button")
		return H.Pivots[1] and H.Pivots[1].CF, #H.Town
	end
	local back, town = wayBackOf(cf(vec(950, 3, 0)), "GoblinWoods")
	check(town == 1 and near(back.Position.Z, -515), "a PvP spot (Goblin Woods) -> the Halo town start", show(back.Position.Z))
	back, town = wayBackOf(cf(vec(10, -460, -40)), "Crossroads")
	check(town == 1, "under the kill height + pad -> the town start", "")
	back, town = wayBackOf(cf(vec(10, 3, -40)), "HaloTown")
	check(town == 1, "the zone is not the one Join was pressed in (gone / changed) -> the town start", "")
	back, town = wayBackOf(cf(vec(6000, 203, 6000)), "Outskirts")
	check(town == 1, "a spot inside the square -> the town start", "")
	back, town = wayBackOf(cf(vec(430, 3, 0)), "SlimeMeadow", { Faction = "Horns" })
	check(town == 0 and near(back.Position.X, 430), "a hunting spot without PvP is kept (the meadow)", "")
	back, town = wayBackOf(cf(vec(950, 3, 0)), "GoblinWoods", { Faction = "Horns" })
	check(town == 1 and near(back.Position.Z, 515), "Horns -> the Horns town start", "")
	-- a wanted player (stars gained before NoTravelStars: none inside) never gets a free trip home: back to the spot
	local W3 = square()
	W3.GS.Ensure()
	local wq = W3.Add(newPlayer("wanted", { Root = cf(vec(950, 3, 0)), Zone = "GoblinWoods", Stars = 1 }))
	W3.GS.Join(wq)
	wq.Stars = 3
	W3.Pivots = {}
	W3.GS.Leave(wq, "Button")
	check(#W3.Town == 0 and W3.Pivots[1] and near(W3.Pivots[1].CF.Position.X, 950), "3 stars: back to the PvP spot itself, never the town",
		show(W3.Pivots[1] and W3.Pivots[1].CF.Position.X))
end)

------------------------------------------------------------------ the round's end
runGroup("return all", function()
	local G = square()
	G.GS.Ensure()
	local a = G.Add(newPlayer("a", { Root = cf(vec(1, 3, -30)) }))
	local b = G.Add(newPlayer("b", { Faction = "Horns", Root = cf(vec(2, 3, 30)) }))
	local c = G.Add(newPlayer("c", { Root = cf(vec(3, 3, -20)) }))
	G.GS.Join(a)
	G.GS.Join(b)
	G.Pivots, G.Leaves = {}, {}
	check(G.GS.ReturnAll("End") == 2 and #G.Pivots == 2 and #G.GS.Members() == 0, "ReturnAll: everyone inside goes back", #G.Pivots)
	check(G.Leaves[1].Reason == "End" and a.Attrs.InGooseSquare == false and b.Attrs.InGooseSquare == false and c.Attrs.InGooseSquare == nil,
		"reason End; a player who never joined is untouched", "")
end)

------------------------------------------------------------------ the tick
runGroup("tick", function()
	local G = square()
	local SP = G.C.Goose.SquareSpace
	local s = G.GS.Ensure()
	local p = G.Add(newPlayer("p", { Root = cf(vec(1, 3, -30)) }))
	G.GS.Join(p)
	p.Root = cf(s.GooseSpot + vec(0, -SP.FallBelow - 5, 0))
	G.Pivots, G.Leaves = {}, {}
	G.GS.Tick(0)
	check(not G.GS.IsIn(p) and G.Leaves[1] and G.Leaves[1].Reason == "Fall" and #G.Pivots == 1, "fell off the floor: leaves (Fall) and is moved back", "")
	local q = G.Add(newPlayer("q", { Root = cf(vec(1, 3, -30)) }))
	G.GS.Join(q)
	q.Root = cf(vec(0, 3, -515)) -- carried far away by something else (a respawn / another teleport)
	G.Pivots, G.Leaves = {}, {}
	G.GS.Tick(0)
	check(not G.GS.IsIn(q) and G.Leaves[1] and G.Leaves[1].Reason == "Moved" and #G.Pivots == 0, "far away: leaves (Moved) without a move", "")
	local r = G.Add(newPlayer("r", { Root = cf(vec(1, 3, -30)) }))
	G.GS.Join(r)
	r.Parent = nil
	G.Leaves = {}
	G.GS.Tick(0)
	check(not G.GS.IsIn(r) and G.Leaves[1] and G.Leaves[1].Reason == "Left", "a player gone from the server leaves (Left)", "")
	local k = G.Add(newPlayer("k", { Root = cf(vec(1, 3, -30)) }))
	G.GS.Join(k)
	k.KaijuState = "Active"
	G.Pivots, G.Leaves = {}, {}
	G.GS.Tick(0)
	check(not G.GS.IsIn(k) and G.Leaves[1] and G.Leaves[1].Reason == "Moved" and #G.Pivots == 0, "a member who became the Active kaiju leaves (Moved)", "")
	-- the safety net: no goose on and someone still inside (the round's end return failed) -> out after ReturnAfter + 3 s
	local SN = square()
	SN.GS.Ensure()
	local s1 = SN.Add(newPlayer("s1", { Root = cf(vec(1, 3, -30)) }))
	SN.GS.Join(s1)
	SN.Active = false
	SN.Clock = 2000
	SN.GS.Tick(0)
	SN.Clock = 2000 + SP.ReturnAfter + 2
	SN.GS.Tick(0)
	check(SN.GS.IsIn(s1), "the safety net waits ReturnAfter + 3 s (the normal return comes first)", "")
	SN.Clock = 2000 + SP.ReturnAfter + 3.5
	SN.GS.Tick(0)
	check(not SN.GS.IsIn(s1) and s1.Attrs.InGooseSquare == false, "no goose on: everyone goes back after ReturnAfter + 3 s", "")
	-- GooseJoinBlock: every ready player, on a change only, "" inside, throttled by BlockEvery
	local H = square()
	H.GS.Ensure()
	local fighter = H.Add(newPlayer("fighter", { InCombat = true }))
	local fine = H.Add(newPlayer("fine"))
	local inside = H.Add(newPlayer("inside"))
	H.GS.Join(inside)
	H.Clock = 1000
	H.GS.Tick(0)
	check(fighter.Attrs.GooseJoinBlock == "PvP" and fine.Attrs.GooseJoinBlock == "" and inside.Attrs.GooseJoinBlock == "",
		"GooseJoinBlock: PvP for a fighter, '' for others and for a member", show({ fighter.Attrs.GooseJoinBlock, fine.Attrs.GooseJoinBlock }))
	fighter.InCombat = false
	H.Clock = 1000 + SP.BlockEvery / 2
	H.GS.Tick(0)
	check(fighter.Attrs.GooseJoinBlock == "PvP", "no refresh before BlockEvery", "")
	H.Clock = 1000 + SP.BlockEvery + 0.01
	H.GS.Tick(0)
	check(fighter.Attrs.GooseJoinBlock == "", "after BlockEvery the block clears", "")
	local writes = 0
	local old = fine.SetAttribute
	fine.SetAttribute = function(self, k, v)
		if k == "GooseJoinBlock" then writes += 1 end
		old(self, k, v)
	end
	H.Clock += SP.BlockEvery + 0.01
	H.GS.Tick(0)
	check(writes == 0, "an unchanged block is not written again", writes)
	inside.Root = nil -- a member who died (the death hook not run yet): still inside, the block stays ''
	H.Clock += SP.BlockEvery + 0.01
	H.GS.Tick(0)
	check(H.GS.IsIn(inside) and inside.Attrs.GooseJoinBlock == "", "a member's block stays '' (never Dead / PvP inside)", show(inside.Attrs.GooseJoinBlock))
	fine.Root = nil
	H.Clock += SP.BlockEvery + 0.01
	H.GS.Tick(0)
	check(fine.Attrs.GooseJoinBlock == "Dead" and writes == 1, "a death shows Dead", "")
end)

finish()
