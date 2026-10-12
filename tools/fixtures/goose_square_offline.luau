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
		Root = opts.Root ~= nil and opts.Root or cf(vec(0, 3, -25)), Kaiju = opts.Kaiju == true, Sack = opts.Sack == true,
		PvPAt = opts.PvPAt, Zone = opts.Zone or "Crossroads", SavedAuto = opts.SavedAuto == true }
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
local function part(pos, size)
	local pt = { Position = pos, Size = size, CFrame = cf(pos) }
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
	function GW.Kaiju(p) return p.Kaiju end
	function GW.Sack(p) return p.Sack end
	function GW.LastPvP(p) return p.PvPAt end
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
	function GW.Build()
		G.Builds += 1
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
		and SP.ReturnAfter == 4 and SP.FightSeconds == 10, "Config.Goose.SquareSpace: on, centre (6000, 200, 6000), back after 4 s, fights 10 s",
		show({ SP.Center.X, SP.Center.Y, SP.Center.Z, SP.ReturnAfter, SP.FightSeconds }))
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
	check(select(2, G.GS.Join(G.Add(newPlayer("kaiju", { Kaiju = true })))) == "Monster", "the kaiju: Monster", "")
	check(select(2, G.GS.Join(G.Add(newPlayer("sack", { Sack = true })))) == "Grudge", "a grudge sack: Grudge", "")
	G.Clock = 1000
	local f9 = G.Add(newPlayer("fight9", { PvPAt = 1000 - 9 }))
	check(select(2, G.GS.Join(f9)) == "PvP", "a PvP hit 9 s ago: PvP", "")
	local f11 = G.Add(newPlayer("fight11", { PvPAt = 1000 - 11 }))
	check(G.GS.Join(f11) == true, "a PvP hit 11 s ago: in (FightSeconds 10)", "")
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
	G.GS.OnRemote(p, "Leave")
	check(p.Attrs.InGooseSquare == true, "a second call within RateLimits.GooseSquare is ignored", "")
	G.World.Clock = 1002
	G.GS.OnRemote(p, "Leave")
	check(p.Attrs.InGooseSquare == false, "'Leave' leaves", "")
	G.Active = false
	G.World.Clock = 1004
	G.GS.OnRemote(p, "Join")
	local n = G.World.Notices[#G.World.Notices]
	check(n and n.Player == p and n.Text == "The goose is gone." and p.Attrs.InGooseSquare == false, "a refusal = the client table's Text line once",
		show(n and n.Text))
	-- no client table yet: no line, never an error
	local H = square()
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
	-- GooseJoinBlock: every ready player, on a change only, "" inside, throttled by BlockEvery
	local H = square()
	H.GS.Ensure()
	local fighter = H.Add(newPlayer("fighter", { PvPAt = 995 }))
	local fine = H.Add(newPlayer("fine"))
	local inside = H.Add(newPlayer("inside"))
	H.GS.Join(inside)
	H.Clock = 1000
	H.GS.Tick(0)
	check(fighter.Attrs.GooseJoinBlock == "PvP" and fine.Attrs.GooseJoinBlock == "" and inside.Attrs.GooseJoinBlock == "",
		"GooseJoinBlock: PvP for a fighter, '' for others and for a member", show({ fighter.Attrs.GooseJoinBlock, fine.Attrs.GooseJoinBlock }))
	fighter.PvPAt = nil
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
