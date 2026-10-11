-- spawn_clear_offline.luau : A23-129 (user 2026-10-11 "몹이 나무들을 뚫고 나오네"). A new monster's whole body (flat
-- radius SEP.RadiusOf, height Slime 3 x Scale / Humanoid 5 x Scale + Float, from 0.5 above the ground) never overlaps a
-- BasePart under workspace.Map: trees / bushes / rocks that are CanQuery = false meshes, non-collidable leaves, props in
-- any folder, parts inside parts, the rails / lamps of bridges and WalkGround models. Never counted: Map.Ground,
-- WalkGround-tagged floor parts, Map.Zones / Map.Pads, invisible non-collidable helpers, non-collidable ground cover and
-- effects named in Config.SpawnClear.Pass, flat parts under the 0.5 foot gap. A world-kit tree (one TrunkPost + a mesh
-- named in Config.SpawnClear.Trees) counts as a trunk-base disc up to the canopy bottom + its mesh box above (검수
-- 2026-10-11 spawnclear review). tools/test_spawn_clear.py binds CONFIG_SOURCE and the cuts of the CURRENT MonsterService
-- (GROUND_EXTRACT = getGroundParams .. groundPoint incl. CLEAR, SPAWN_EXTRACT = the real pickSpawnPoint, EVENT_EXTRACT =
-- SpawnEvent + PickSpawnPoint, SPOT_EXTRACT = MOB3.Spot, PERSONAL_EXTRACT = SpawnPersonal) in front of dev2_kit.luau.
-- The map, the vertical rays and Util are doubles. "No overlap" is judged by ORACLE below (points of the body inside a
-- part's box and the part's own points inside the body), never by CLEAR itself.

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local MT = C.MonsterTypes
local MEADOW, RUINS = C.Zones.SlimeMeadow, C.Zones.SkeletonRuins
local INSET = C.Monsters.SpawnInset
local FOOT = 0.5

------------------------------------------------------------------ map doubles
local function rotY(v, a)
	local c, s = math.cos(a), math.sin(a)
	return vec(c * v.X + s * v.Z, v.Y, -s * v.X + c * v.Z)
end
local function rotZ(v, b)
	local c, s = math.cos(b), math.sin(b)
	return vec(c * v.X - s * v.Y, s * v.X + c * v.Y, v.Z)
end
-- a CFrame double: yaw (degrees about Y) after roll (degrees about Z)
local function cframe(x, y, z, yaw, roll)
	local a, b = math.rad(yaw or 0), math.rad(roll or 0)
	local function R(v) return rotY(rotZ(v, b), a) end
	return { Position = vec(x, y, z), XVector = R(vec(1, 0, 0)), YVector = R(vec(0, 1, 0)), ZVector = R(vec(0, 0, 1)) }
end

local PART_CLASS = { Part = true, MeshPart = true, UnionOperation = true, WedgePart = true }
local function node(class, name, props)
	local o = { ClassName = class, Name = name, _children = {} }
	for k, v in props or {} do o[k] = v end
	function o:IsA(k) return k == "Instance" or k == self.ClassName or (k == "BasePart" and PART_CLASS[self.ClassName] == true) end
	function o:GetChildren()
		if self.Broken and self.Broken.On then error("offline map read failure") end
		return table.clone(self._children)
	end
	function o:FindFirstChild(n)
		for _, c in self._children do if c.Name == n then return c end end
		return nil
	end
	return o
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn)
		table.insert(self.Fns, fn)
		return { Disconnect = function() local i = table.find(s.Fns, fn); if i then table.remove(s.Fns, i) end end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self.Fns) do fn(...) end
	end
	return s
end
local CURRENT = nil -- the world being built (its map version bumps on every put)
local function underMap(inst)
	local p = inst
	while p do
		if CURRENT and p == CURRENT.Map then return true end
		p = p.Parent
	end
	return false
end
local function put(parent, child)
	if CURRENT then CURRENT.Version += 1 end
	child.Parent = parent
	table.insert(parent._children, child)
	if underMap(parent) and CURRENT.Map.DescendantAdded then CURRENT.Map.DescendantAdded:Fire(child) end
	return child
end
local function unput(child)
	local parent = child.Parent
	local i = table.find(parent._children, child)
	if i then table.remove(parent._children, i) end
	if CURRENT then CURRENT.Version += 1 end
	if underMap(parent) and CURRENT.Map.DescendantRemoving then CURRENT.Map.DescendantRemoving:Fire(child) end
	child.Parent = nil
end
-- o: x, y, z = box centre; sx, sy, sz; yaw / roll in degrees; col (default true), query (default true), tr, class
local function part(parent, name, o)
	return put(parent, node(o.class or "MeshPart", name, { CFrame = cframe(o.x, o.y, o.z, o.yaw, o.roll),
		Size = vec(o.sx, o.sy, o.sz), CanCollide = o.col ~= false, CanQuery = o.query ~= false, Transparency = o.tr or 0 }))
end
-- a prop standing on flat ground (y = 0 .. sy): a world-kit mesh by default (no collision, no queries)
local function prop(parent, name, x, z, sx, sy, sz, yaw, extra)
	local o = { x = x, y = sy / 2, z = z, sx = sx, sy = sy, sz = sz, yaw = yaw, col = false, query = false }
	for k, v in extra or {} do o[k] = v end
	return part(parent, name, o)
end

local function walkParts(inst, out)
	for _, c in inst._children do
		if c:IsA("BasePart") then table.insert(out, c) end
		walkParts(c, out)
	end
	return out
end
local function under(inst, roots)
	local p = inst
	while p do
		for _, r in roots do if r == p then return true end end
		p = p.Parent
	end
	return false
end
local function localOf(p, v) -- v relative to the part centre, in its local axes
	local cf = p.CFrame
	local d = v - cf.Position
	return d.X * cf.XVector.X + d.Y * cf.XVector.Y + d.Z * cf.XVector.Z,
		d.X * cf.YVector.X + d.Y * cf.YVector.Y + d.Z * cf.YVector.Z,
		d.X * cf.ZVector.X + d.Y * cf.ZVector.Y + d.Z * cf.ZVector.Z
end
local function inside(p, v, grow)
	local lx, ly, lz = localOf(p, v)
	local g = grow or 0
	return math.abs(lx) <= p.Size.X / 2 + g and math.abs(ly) <= p.Size.Y / 2 + g and math.abs(lz) <= p.Size.Z / 2 + g
end

-- a world: the map (Ground / Decor / Landmarks / Zones / Pads / Gates), flat terrain at TerrainY (default 0), vertical
-- rays against the Include list (Terrain, parts whose top is under the ray; upright parts only), Util and task doubles
local function newWorld()
	local w = { Clock = 1000, Tick = 0, Warnings = {}, Spawned = {}, Waits = 0, Tagged = {}, Records = {}, Players = {},
		Broken = { On = false }, MapShown = true, Rays = 0, RayMemo = {}, Version = 0 }
	CURRENT = w
	local map = node("Folder", "Map", { Broken = w.Broken, DescendantAdded = signal(), DescendantRemoving = signal() })
	w.Map = map
	for _, n in { "Ground", "Zones", "Pads", "Decor", "Landmarks", "Gates" } do w[n] = put(map, node("Folder", n)) end
	w.Terrain = node("Terrain", "Terrain")
	w.TerrainY = function() return 0 end
	local ws = { Terrain = w.Terrain }
	map.Parent = ws
	function ws.FindFirstChild(_, n)
		if n == "Map" and w.MapShown then return map end
		return nil
	end
	function ws.Raycast(_, origin, dir, params)
		w.Rays += 1
		assert(math.abs(dir.X) < 1e-9 and math.abs(dir.Z) < 1e-9 and dir.Y < 0, "vertical rays only")
		local top, bottom = origin.Y, origin.Y + dir.Y
		local roots = params.FilterDescendantsInstances or {}
		local best = nil
		local function take(y, mat)
			if y <= top and y >= bottom and (best == nil or y > best.Position.Y) then
				best = { Position = vec(origin.X, y, origin.Z), Material = mat }
			end
		end
		if table.find(roots, w.Terrain) then
			local y = w.TerrainY(origin.X, origin.Z)
			if y then take(y, (w.WaterAt and w.WaterAt(origin.X, origin.Z)) and enum.Material.Water or enum.Material.Grass) end
		end
		local memo = w.RayMemo[params]
		if not memo or memo.Version ~= w.Version then
			memo = { Version = w.Version, Cells = {} }
			for _, p in walkParts(map, {}) do
				if p.CanQuery ~= false and (not params.RespectCanCollide or p.CanCollide) and under(p, roots)
					and math.abs(p.CFrame.YVector.Y) > 0.999 then
					local c, s = p.CFrame.Position, p.Size
					local reach = math.sqrt(s.X * s.X + s.Z * s.Z) / 2
					for cx = math.floor((c.X - reach) / 16), math.floor((c.X + reach) / 16) do
						for cz = math.floor((c.Z - reach) / 16), math.floor((c.Z + reach) / 16) do
							local k = cx * 65536 + cz
							memo.Cells[k] = memo.Cells[k] or {}
							table.insert(memo.Cells[k], p)
						end
					end
				end
			end
			w.RayMemo[params] = memo
		end
		for _, p in memo.Cells[math.floor(origin.X / 16) * 65536 + math.floor(origin.Z / 16)] or {} do
			do
				local lx, _, lz = localOf(p, vec(origin.X, p.CFrame.Position.Y, origin.Z))
				if math.abs(lx) <= p.Size.X / 2 and math.abs(lz) <= p.Size.Z / 2 then
					take(p.CFrame.Position.Y + p.Size.Y / 2, enum.Material.Plastic)
				end
			end
		end
		return best
	end
	w.Workspace = ws

	local rng = { Script = {} }
	local U = { Random = randomDouble(rng).new() }
	function U.GetRoot(p) return p.Root end
	function U.IsAlive(p) return p.Dead ~= true end
	function U.FlatDistance(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
	function U.RandomPointInZone(zone, inset)
		inset = inset or 0
		local hx, hz = math.max(1, zone.Size.X / 2 - inset), math.max(1, zone.Size.Z / 2 - inset)
		return vec(zone.Center.X + U.Random:NextNumber(-hx, hx), 0, zone.Center.Z + U.Random:NextNumber(-hz, hz))
	end
	function U.Tagged(tag) return tag == "WalkGround" and table.clone(w.Tagged) or {} end
	w.U = U

	local env = nativeEnv()
	env.workspace = ws
	env.typeof = typeofDouble
	env.RaycastParams = { new = function() return { FilterDescendantsInstances = {} } end }
	-- w.Tick: every os.clock() call moves the clock a little (a long rebuild then yields on its time budget)
	env.os = { clock = function() w.Clock += w.Tick; return w.Clock end, time = os.time }
	env.task = {
		wait = function() w.Waits += 1 end,
		spawn = function(fn, ...) table.insert(w.Spawned, table.pack(fn, ...)) end,
		delay = function() end,
	}
	local function warnThrottled(_, msg) table.insert(w.Warnings, tostring(msg)) end
	w.G = execute("Ground", GROUND_EXTRACT, env, C, U, warnThrottled, w.Records)
	local H = { records = w.Records, pending = {}, readyPlayers = function() return w.Players end,
		groundPoint = w.G.groundPoint, warnThrottled = warnThrottled }
	local MS = { CountInRadius = function() return 0 end }
	w.S = execute("Spawn", SPAWN_EXTRACT, nativeEnv(), C, U, MS, H)
	w.Made = {}
	local E = { records = w.Records, groundPoint = w.G.groundPoint, pickSpawnPoint = w.S.pickSpawnPoint,
		warnThrottled = warnThrottled, getGroundParams = w.G.getGroundParams,
		spawnMonster = function(kind, opts)
			local rec = { Kind = kind, Position = opts.Position, Alive = true, Model = { Name = kind } }
			table.insert(w.Made, rec)
			return rec
		end }
	local eenv = nativeEnv()
	eenv.typeof = typeofDouble
	w.E = execute("Event", EVENT_EXTRACT, eenv, C, U, E)
	w.Spot = execute("Spot", SPOT_EXTRACT, eenv, C, U, E)
	local penv = nativeEnv()
	penv.typeof = typeofDouble
	penv.task = env.task
	penv.os = env.os
	w.Personal = {}
	w.P = execute("Personal", PERSONAL_EXTRACT, penv, C, U, w.Personal, 8, 120, w.G.groundPoint, w.G.probeGround,
		E.spawnMonster, function() end, warnThrottled)
	function w:RunSpawned()
		local n = 0
		while #self.Spawned > 0 do
			local job = table.remove(self.Spawned, 1)
			n += 1
			job[1](table.unpack(job, 2, job.n))
		end
		return n
	end
	return w
end

------------------------------------------------------------------ the oracle
-- the props a world should block with (the fixture's own list, not CLEAR's): every part under Map minus Ground / Zones /
-- Pads, the walking ground roots incl. what stands in them, invisible non-collidable helpers
local SCF = C.SpawnClear
local function hasWord(name, list)
	for _, k in list do
		if string.find(name, k, 1, true) then return true end
	end
	return false
end
-- ground cover / effects (Config.SpawnClear.Pass): non-collidable, a Pass word, no NotPass word
local function passes(p)
	return SCF.PassRule ~= false and not p.CanCollide and hasWord(p.Name, SCF.Pass) and not hasWord(p.Name, SCF.NotPass)
end
-- the tree share of a mesh whose parent holds exactly one TrunkPost and it as the one known tree mesh (upright), or nil
local function treeOf(p)
	if SCF.TreeRule == false or p.ClassName ~= "MeshPart" or type(SCF.Trees[p.Name]) ~= "table" then return nil end
	local posts, meshes, post = 0, 0, nil
	for _, c in p.Parent._children do
		if c:IsA("BasePart") and c.Name == "TrunkPost" then posts += 1; post = c end
		if c.ClassName == "MeshPart" and type(SCF.Trees[c.Name]) == "table" then meshes += 1 end
	end
	if posts ~= 1 or meshes ~= 1 or math.abs(p.CFrame.YVector.Y) < 0.999 then return nil end
	return SCF.Trees[p.Name], post
end
local function propsOf(w)
	local skip = { w.Ground, w.Zones, w.Pads }
	for _, t in w.Tagged do
		if t:IsA("BasePart") then table.insert(skip, t) end
	end
	local out = {}
	for _, p in walkParts(w.Map, {}) do
		if not under(p, skip) and not (p.Transparency >= 0.95 and not p.CanCollide) and not passes(p) then
			local s = p.Size
			local share, post = treeOf(p)
			if share then
				-- the trunk-base disc up to the canopy bottom + the mesh box above it
				local lo = p.CFrame.Position.Y - s.Y / 2
				local cut = lo + share.Canopy * s.Y
				local c = post.CFrame.Position
				table.insert(out, { P = p, Disc = { X = c.X, Z = c.Z, R = share.Base * math.max(s.X, s.Z), Lo = lo, Hi = cut } })
				local cf = p.CFrame
				local top = { Name = p.Name, Size = vec(s.X, lo + s.Y - cut, s.Z), CFrame = { Position = vec(cf.Position.X,
					(cut + lo + s.Y) / 2, cf.Position.Z), XVector = cf.XVector, YVector = cf.YVector, ZVector = cf.ZVector } }
				table.insert(out, { P = top, Reach = math.sqrt(s.X * s.X + s.Y * s.Y + s.Z * s.Z) / 2 })
			else
				table.insert(out, { P = p, Reach = math.sqrt(s.X * s.X + s.Y * s.Y + s.Z * s.Z) / 2 })
			end
		end
	end
	return out
end
local function bodyOf(def)
	local s = def.Scale or 1
	local r = (def.Shape == "Slime" and 1.5 or 1.25) * s
	return r, (def.Shape == "Slime" and 3 or 5) * s + (def.Float or 0)
end
-- the first part the body of def standing on g overlaps (sampled), or nil
local function ORACLE(props, g, def)
	local r, h = bodyOf(def)
	local lo, hi = g.Y + FOOT, g.Y + h
	for _, pr in props do
		local d = pr.Disc
		if d then
			-- a tree's trunk base: the body circle (97%) reaches into the disc within its height
			if hi > d.Lo and lo < d.Hi and math.sqrt((g.X - d.X) ^ 2 + (g.Z - d.Z) ^ 2) < d.R + r * 0.97 then return pr.P end
			continue
		end
		local c = pr.P.CFrame.Position
		if math.abs(c.X - g.X) <= pr.Reach + r and math.abs(c.Z - g.Z) <= pr.Reach + r then
			-- the body's points inside the part
			for _, y in { lo + 0.02, (lo + hi) / 2, hi - 0.02 } do
				for _, rr in { 0, r * 0.5, r * 0.97 } do
					for k = 0, (rr == 0 and 0 or 15) do
						local a = k * math.pi / 8
						if inside(pr.P, vec(g.X + math.cos(a) * rr, y, g.Z + math.sin(a) * rr)) then return pr.P end
					end
				end
			end
			-- the part's own points (centre, corners) inside the body
			local p, s = pr.P, pr.P.Size
			for _, ox in { -1, 0, 1 } do
				for _, oy in { -1, 0, 1 } do
					for _, oz in { -1, 0, 1 } do
						local cf = p.CFrame
						local v = cf.Position + cf.XVector * (ox * s.X / 2 * 0.98) + cf.YVector * (oy * s.Y / 2 * 0.98)
							+ cf.ZVector * (oz * s.Z / 2 * 0.98)
						if v.Y > lo and v.Y < hi and math.sqrt((v.X - g.X) ^ 2 + (v.Z - g.Z) ^ 2) < r then return p end
					end
				end
			end
		end
	end
	return nil
end

local SLIME, PRINCE, KING, GOBLIN, BRUTE, MINION = "Slime", "BigSlime", "SlimeKing", "Goblin", "GoblinBrute", "GhostMinion"
-- props added since the last look: a fresh index and fresh ray lists (11 s on, past GROUND_PARAMS_REFRESH), as a
-- new server would see them; the index group turns this off (w.Auto = false) to test the real rebuilds
local function sync(w)
	if w.Auto ~= false and w.Seen ~= w.Version then
		w.G.CLEAR.Grid = nil
		w.Clock += 11
		w.Seen = w.Version
	end
end
-- no warnings but the allowed ones
local function quiet(w, allow)
	local left = {}
	for _, t in w.Warnings do
		if not (allow and string.find(t, allow, 1, true)) then table.insert(left, t) end
	end
	check(#left == 0, "no warnings", left[1])
end

local function fits(w, x, z, kind)
	sync(w)
	local g = w.G.groundPoint(x, z, nil, MT[kind or SLIME])
	return g ~= nil, g
end

------------------------------------------------------------------ groups
runGroup("body sizes", function()
	local w = newWorld()
	local C2 = w.G.CLEAR
	local function same(kind, r, h)
		local gr, gh = C2.Body(MT[kind])
		check(math.abs(gr - r) < 1e-6 and math.abs(gh - h) < 1e-6, kind .. " body = r " .. r .. ", h " .. h, show({ gr, gh }))
	end
	same(SLIME, 1.5, 3)
	same(PRINCE, 2.7, 5.4)
	same(KING, 4.8, 9.6)
	same(GOBLIN, 1.25, 5)
	same(BRUTE, 1.875, 7.5)
	same(MINION, 0.75, 4.2)
	check(C2.FOOT == FOOT, "the body starts 0.5 above the ground", C2.FOOT)
end)

runGroup("one prop: edges, corners, rotation", function()
	local w = newWorld()
	-- a meadow tree: one CanQuery = false mesh 20 x 24 x 15, turned 30 degrees (place file W_Tree_B)
	local tree = prop(w.Decor, "W_Tree_B", 400, 0, 20, 24, 15, 30)
	local cf = tree.CFrame
	local function at(lx, lz) -- a ground point at local (lx, lz) of the tree
		local v = cf.Position + cf.XVector * lx + cf.ZVector * lz
		return v.X, v.Z
	end
	local hx, hz, r = 10, 7.5, 1.5
	check(not fits(w, at(0, 0)), "the tree centre: blocked (the old centre ray never saw this mesh)")
	local og = w.G.groundPoint(at(0, 0))
	check(og ~= nil, "the same spot without a body (walks): still walkable ground", og)
	check(not fits(w, at(hx + r - 0.05, 0)), "the body edge 0.05 inside the trunk box side: blocked")
	check(fits(w, at(hx + r + 0.05, 0)), "the body edge 0.05 outside: free")
	check(not fits(w, at(0, -(hz + r - 0.05))), "the other side, 0.05 inside: blocked")
	check(fits(w, at(0, -(hz + r + 0.05))), "the other side, 0.05 outside: free")
	-- the corner: 1.2 / 1.2 out on both axes = 1.70 from the corner (> 1.5): free; 1.0 / 1.0 = 1.41: blocked
	check(fits(w, at(hx + 1.2, hz + 1.2)), "1.70 studs off the box corner: free (the round body, not its box)")
	check(not fits(w, at(hx + 1.0, hz + 1.0)), "1.41 studs off the box corner: blocked")
	-- rotation: a spot inside the turned box but outside the same box unturned
	local x, z = at(hx - 0.5, hz - 0.5)
	check(math.abs(x - 400) > hx + r or math.abs(z) > hz + r, "test spot is outside the unturned box", show({ x, z }))
	check(not fits(w, x, z), "inside the turned footprint: blocked")
	local x2, z2 = 409, 6.5 -- inside the unturned box, outside the turned one (local 4.54 / 10.13)
	local lx, _, lz = localOf(tree, vec(x2, 12, z2))
	check(math.abs(x2 - 400) < hx and math.abs(z2) < hz, "test spot is inside the unturned box")
	check(math.abs(lx) > hx + r or math.abs(lz) > hz + r, "test spot is outside the turned box", show({ lx, lz }))
	check(fits(w, x2, z2), "outside the turned footprint: free")
	quiet(w)
end)

runGroup("height: canopies, floating, flat parts", function()
	local w = newWorld()
	-- a canopy with its bottom 6 above the ground (6 .. 14)
	part(w.Decor, "Leaves", { x = 500, y = 10, z = 100, sx = 12, sy = 8, sz = 12, col = false, query = false })
	check(fits(w, 500, 100, SLIME), "under a canopy at 6: a Shard Slime (3 tall) fits")
	check(fits(w, 500, 100, PRINCE), "under a canopy at 6: a Slime Prince (5.4) fits")
	check(not fits(w, 500, 100, KING), "under a canopy at 6: the King Slime (9.6) does not")
	check(not fits(w, 500, 100, BRUTE), "under a canopy at 6: a Goblin Brute (7.5) does not")
	-- a low branch at 4.0 .. 5.0: a floating Ghost Minion (3 + Float 1.2) reaches it, a Shard Slime (3) does not
	part(w.Landmarks, "Branch", { x = 520, y = 4.5, z = -80, sx = 6, sy = 1, sz = 6, col = false, query = false })
	check(not fits(w, 520, -80, MINION), "a floating Ghost Minion (to 4.2) touches a branch at 4.0")
	check(fits(w, 520, -80, SLIME), "a Shard Slime (to 3) passes under it")
	-- flat parts: a road 0.2 thick, a rug 0.45 above the ground
	part(w.Decor, "RoadCross", { x = 300, y = 0.1, z = 200, sx = 137, sy = 0.2, sz = 18, col = false, query = false, class = "Part" })
	part(w.Decor, "Rug", { x = 330, y = 0.225, z = -200, sx = 6, sy = 0.45, sz = 6, col = false, query = false, class = "Part" })
	check(fits(w, 300, 200, KING), "on a road (top 0.2): free")
	check(fits(w, 330, -200, SLIME), "on a rug (top 0.45, under the 0.5 foot gap): free")
	-- a tilted log: 12 long, turned 30 degrees up; under its raised end it is above a slime, its middle is not
	part(w.Decor, "Kit_W_FallenLog", { x = 600, y = 3, z = 0, sx = 12, sy = 2, sz = 2, roll = 30, col = false, query = false })
	check(not fits(w, 600, 0, SLIME), "a tilted log's middle: blocked")
	check(fits(w, 600 + 5.2, 0, SLIME), "under its raised end (log bottom ~4.8): free (not its bounding box)")
	check(fits(w, 600, 4, SLIME), "4 studs beside the log: free")
	-- an invisible collidable post with its long axis up (TrunkPost: X axis vertical)
	part(w.Decor, "TrunkPost", { x = 650, y = 4, z = -100, sx = 8, sy = 3.8, sz = 3.8, roll = 90, tr = 1, col = true, query = false, class = "Part" })
	check(not fits(w, 650, -100, SLIME), "an invisible collidable post: blocked")
	check(fits(w, 650 + 1.9 + 1.5 + 0.05, -100, SLIME), "just beside the post: free")
	check(not fits(w, 650 + 1.9 + 1.5 - 0.05, -100, SLIME), "just touching the post: blocked")
	quiet(w)
end)

runGroup("what counts", function()
	local w = newWorld()
	-- invisible non-collidable helpers (a zone box, an anchor, mist): never
	part(w.Decor, "HelperVolume", { x = 450, y = 25, z = 150, sx = 50, sy = 50, sz = 50, tr = 1, col = false, query = false, class = "Part" })
	check(fits(w, 450, 150, KING), "inside an invisible non-collidable helper: free")
	part(w.Zones, "SlimeMeadow", { x = 430, y = 10, z = 0, sx = 440, sy = 20, sz = 480, tr = 0.5, col = false, query = false, class = "Part" })
	check(fits(w, 470, -150, KING), "inside a Map.Zones box (even half see-through): free")
	part(w.Pads, "Pad_SlimeMeadow", { x = 520, y = 0.5, z = -50, sx = 12, sy = 1, sz = 12, class = "Part" })
	check(fits(w, 520, -50, SLIME), "on a Map.Pads pad (1 tall): free")
	-- a bridge: the deck is ground (top 2) and never blocks; 검수 2026-10-11: its rails do (the model is walked)
	local bridge = put(w.Decor, node("Model", "Bridge_Test"))
	part(bridge, "Deck", { x = 350, y = 1.5, z = 150, sx = 10, sy = 1, sz = 30, class = "Part" })
	part(bridge, "RailE", { x = 355.5, y = 3.5, z = 150, sx = 1, sy = 2, sz = 30, col = false, query = false, class = "Part" })
	local ok, g = fits(w, 350, 150, SLIME)
	check(ok and g and math.abs(g.Y - 2) < 1e-6, "in the middle of a bridge deck: free, standing on the deck (y 2)", g)
	check(not fits(w, 354.5, 150, SLIME), "on the deck with the body in its rail: blocked (rails are props)")
	-- a WalkGround-tagged stage model: its floor is ground, the lantern standing in it blocks
	local stage = put(w.Decor, node("Model", "Stage"))
	part(stage, "Floor", { x = 380, y = 1.5, z = -150, sx = 20, sy = 3, sz = 20, class = "Part" })
	part(stage, "Lantern", { x = 382, y = 5, z = -150, sx = 1, sy = 4, sz = 1, col = false, query = false })
	table.insert(w.Tagged, stage)
	local ok2, g2 = fits(w, 376, -150, SLIME)
	check(ok2 and g2 and math.abs(g2.Y - 3) < 1e-6, "on a WalkGround stage away from its lantern: free (on the floor, y 3)", g2)
	check(not fits(w, 381, -150, SLIME), "on the stage by its lantern: blocked (a tagged model is walked)")
	-- a WalkGround-tagged floor PART is skipped: a body on the ground beside a raised tagged platform
	local plat = part(w.Decor, "Platform", { x = 420, y = 1.5, z = -150, sx = 10, sy = 3, sz = 10, class = "Part" })
	table.insert(w.Tagged, plat)
	check(fits(w, 426, -150, SLIME), "the body over the edge of a tagged floor part: free (walking floors never block)")
	-- other folders, nesting
	prop(w.Gates, "GateRock", 560, 150, 6, 5, 6, 0)
	check(not fits(w, 560, 150, SLIME), "a rock in Map.Gates: blocked")
	local big = put(put(put(w.Decor, node("Folder", "MeadowDress")), node("Model", "Big")), node("Model", "W_Tree_A"))
	prop(big, "W_Tree_A", 300, -100, 14, 20, 14, 0)
	check(not fits(w, 300, -100, SLIME), "a tree 3 folders deep: blocked")
	local host = prop(w.Landmarks, "Statue", 250, 100, 2, 2, 2, 0, { col = true, query = true })
	part(host, "Wing", { x = 255, y = 2, z = 100, sx = 3, sy = 2, sz = 3, col = false, query = false })
	check(not fits(w, 255, 100, SLIME), "a part inside a part: blocked")
	-- the old CR-L14 rule still holds for the walks: a collidable queryable rock under Decor
	prop(w.Decor, "SolidRock", 620, 150, 6, 6, 6, 0, { col = true, query = true })
	sync(w)
	check(w.G.groundPoint(620, 150) == nil, "CR-L14 kept: a solid decor rock still blocks the plain ground point")
	quiet(w)
end)

runGroup("the grid", function()
	local w = newWorld()
	-- a wall 100 long: its far end is many cells from its centre cell
	part(w.Decor, "LongWall", { x = 400, y = 3, z = 180, sx = 100, sy = 6, sz = 2, col = false, query = false, class = "Part" })
	check(not fits(w, 449, 180, SLIME), "the far end of a long wall: blocked")
	check(not fits(w, 351, 181.5, SLIME), "the other end, body over its side: blocked")
	-- a small post just across a cell line from the body centre (cells of 16)
	part(w.Decor, "Post", { x = 16 * 25 + 1, y = 2, z = 16 * 3 + 8, sx = 1, sy = 4, sz = 1, col = false, query = false, class = "Part" })
	check(not fits(w, 16 * 25 - 0.2, 16 * 3 + 8, SLIME), "a post in the next cell, 0.7 from the body edge inside: blocked")
	check(fits(w, 16 * 25 - 1.2, 16 * 3 + 8, SLIME), "1 stud farther: free")
	quiet(w)
end)

-- a dense meadow: trees, bushes, logs, canopies, posts (props of every kind) at seeded random spots
local function forest(w, zone, n)
	local seed = 7
	local function rnd(a, b)
		seed = (seed * 48271) % 2147483647
		return a + (b - a) * ((seed - 1) / 2147483646)
	end
	local hx, hz = zone.Size.X / 2, zone.Size.Z / 2
	local dress = put(w.Decor, node("Folder", "TestDress"))
	for i = 1, n do
		local x, z = zone.Center.X + rnd(-hx, hx), zone.Center.Z + rnd(-hz, hz)
		local kind = i % 5
		if kind == 0 then
			prop(dress, "Tree", x, z, rnd(16, 22), rnd(20, 26), rnd(12, 16), rnd(0, 90))
		elseif kind == 1 then
			prop(dress, "Bush", x, z, rnd(6, 12), rnd(4, 9), rnd(6, 12), rnd(0, 90), { col = true, query = true })
		elseif kind == 2 then
			part(dress, "Log", { x = x, y = 1.5, z = z, sx = rnd(6, 12), sy = 2, sz = 2, yaw = rnd(0, 180), roll = rnd(5, 25),
				col = false, query = false })
		elseif kind == 3 then
			part(dress, "Canopy", { x = x, y = rnd(4, 9), z = z, sx = rnd(8, 14), sy = 3, sz = rnd(8, 14), yaw = rnd(0, 90),
				col = false, query = false })
		else
			part(dress, "Post", { x = x, y = 4, z = z, sx = 8, sy = 3, sz = 3, roll = 90, tr = 1, col = true, query = false,
				class = "Part" })
		end
	end
end

runGroup("pickSpawnPoint in a forest", function()
	local w = newWorld()
	forest(w, MEADOW, 1400)
	sync(w)
	local props = propsOf(w)
	-- the old way (the ground point, the CR-L14 centre ray, no body): many picks inside props
	local oldIn, oldN = 0, 0
	for _ = 1, 300 do
		local pt = w.U.RandomPointInZone(MEADOW, INSET)
		local g = w.G.groundPoint(pt.X, pt.Z)
		if g then
			oldN += 1
			if ORACLE(props, g, MT[SLIME]) then oldIn += 1 end
		end
	end
	finding(string.format("forest of %d props: the old rule left %d of %d ground picks inside a prop", #props, oldIn, oldN))
	check(oldIn >= oldN * 0.25, "the test forest is dense (old rule: >= 25% of picks inside props)", show({ oldIn, oldN }))
	-- the real pickSpawnPoint, every kind of the meadow and the King
	local bad, none, got = {}, 0, 0
	for _, kind in { SLIME, SLIME, SLIME, PRINCE, KING } do
		for _ = 1, 80 do
			local g = w.S.pickSpawnPoint(MT[kind], kind)
			if g then
				got += 1
				local hit = ORACLE(props, g, MT[kind])
				if hit then table.insert(bad, kind .. " in " .. hit.Name .. " at " .. show({ g.X, g.Y, g.Z })) end
				check(C.ZoneAt(g).Id == "SlimeMeadow", "every pick inside the meadow", show(g))
			else
				none += 1
			end
		end
	end
	finding(string.format("pickSpawnPoint: %d picks, %d none this pass, %d inside a prop", got, none, #bad))
	check(#bad == 0, "no pick has a prop inside its body (sampling oracle)", bad[1])
	check(got >= 300, "the forest still leaves room: >= 300 of 400 passes found a spot", got)
	-- the public probe (MonsterService.PickSpawnPoint) is the same rule
	local pbad = 0
	for _ = 1, 60 do
		local g = w.E.PickSpawnPoint(KING)
		if g and ORACLE(props, g, MT[KING]) then pbad += 1 end
	end
	check(pbad == 0, "MonsterService.PickSpawnPoint(King): no prop inside", pbad)
	check(w.E.PickSpawnPoint(nil) == nil and w.E.PickSpawnPoint("NoSuchKind") == nil and w.E.PickSpawnPoint(5) == nil,
		"PickSpawnPoint: nil for a missing / unknown kind")
	quiet(w, "no walkable ground found in SlimeMeadow")
end)

runGroup("every try blocked", function()
	local w = newWorld()
	-- a cover over the whole meadow (one see-through-free mesh from the ground up)
	prop(w.Decor, "Cover", MEADOW.Center.X, MEADOW.Center.Z, MEADOW.Size.X + 40, 4, MEADOW.Size.Z + 40, 0)
	sync(w)
	local any = 0
	for _ = 1, 20 do
		if w.S.pickSpawnPoint(MT[SLIME], SLIME) ~= nil then any += 1 end
	end
	check(any == 0, "no spawn this pass (never a random point inside the cover)", any)
	local said = false
	for _, t in w.Warnings do
		if string.find(t, "no walkable ground found in SlimeMeadow", 1, true) and string.find(t, "props", 1, true) then said = true end
	end
	check(said, "the throttled warning names props", w.Warnings[1])
end)

runGroup("bosses (SpawnEvent)", function()
	local w = newWorld()
	-- the King's hill shrine just behind its marked spot (the place file: 4.3 studs, the King's radius is 4.8)
	prop(w.Decor, "Kit_M_CrownShrine", 431.2, -172.8, 16, 10.4, 16, 0, { col = true, query = false })
	local near = vec(426, 0, -160.5)
	check(not fits(w, near.X, near.Z, KING), "the marked spot itself: the King's body reaches the shrine")
	local props = propsOf(w)
	for i = 1, 30 do
		w.Made = {}
		local rec = w.E.SpawnEvent(KING, { Near = near, Radius = 2, MaxY = 40 })
		check(rec ~= nil, "the King still appears", i)
		if rec then
			check(ORACLE(props, rec.Position, MT[KING]) == nil, "the King never stands in the shrine", show(rec.Position))
			check(C.ZoneAt(rec.Position).Id == "SlimeMeadow", "in its zone", show(rec.Position))
		end
	end
	-- the marked spot closer to the shrine (every try within Radius 2 blocked): a ring farther out, still by the shrine
	local w2 = newWorld()
	prop(w2.Decor, "Kit_M_CrownShrine", 431.2, -172.8, 16, 10.4, 16, 0, { col = true, query = false })
	sync(w2)
	local near2 = vec(431.2, 0, -162)
	local props2a = propsOf(w2)
	for i = 1, 10 do
		local rec = w2.E.SpawnEvent(KING, { Near = near2, Radius = 2, MaxY = 40 })
		local d = rec and math.sqrt((rec.Position.X - near2.X) ^ 2 + (rec.Position.Z - near2.Z) ^ 2) or -1
		check(rec ~= nil and d >= 4.9 and d <= 11.1 and ORACLE(props2a, rec.Position, MT[KING]) == nil,
			"a fully blocked mark: the King on a ring 5-11 studs out, outside the shrine", show({ i, d }))
	end
	-- a spot fully inside a big rock: the zone's normal free spot instead
	prop(w.Decor, "BigRock", 700, 100, 30, 12, 30, 0)
	sync(w)
	local props2 = propsOf(w)
	for _ = 1, 10 do
		local rec = w.E.SpawnEvent(KING, { Near = vec(700, 0, 100), Radius = 3 })
		check(rec ~= nil and ORACLE(props2, rec.Position, MT[KING]) == nil and C.ZoneAt(rec.Position).Id == "SlimeMeadow",
			"a spot inside a rock: a free spot of the meadow", rec and show(rec.Position))
	end
	-- MaxY still reaches a hill top (30) with nothing on it
	w.TerrainY = function(x, z) if math.abs(x - 500) < 20 and math.abs(z - 150) < 20 then return 30 end return 0 end
	local rec = w.E.SpawnEvent(KING, { Near = vec(500, 0, 150), Radius = 2, MaxY = 40 })
	check(rec ~= nil and math.abs(rec.Position.Y - 30) < 1e-6, "MaxY: the hill-top spot (30) still works", rec and show(rec.Position))
	quiet(w, "no walkable ground found in SlimeMeadow")
end)

runGroup("partners (MOB3.Spot)", function()
	local w = newWorld()
	local kind = "SkeletonArcher"
	local def = MT[kind]
	check(def and def.PartnerOf == "SkeletonKnight", "Skeleton Archer spawns beside a Skeleton Knight", def and def.PartnerOf)
	-- a Knight in a ring of tomb stones / pillars 4-8 studs around it, one gap
	local kx, kz = 1500, 50
	table.insert(w.Records, { Alive = true, Kind = "SkeletonKnight", Root = { Parent = true, Position = vec(kx, 0, kz) } })
	for k = 0, 10 do
		local a = k * math.pi * 2 / 12
		prop(w.Decor, "Tombstone", kx + math.cos(a) * 6, kz + math.sin(a) * 6, 3.5, 4, 3.5, math.deg(a))
	end
	sync(w)
	local props = propsOf(w)
	local got, bad = 0, 0
	for _ = 1, 200 do
		local g = w.Spot(def, kind)
		if g then
			got += 1
			if ORACLE(props, g, def) then bad += 1 end
		end
	end
	finding(string.format("partner spots in a ring of 11 stones: %d found, %d inside a stone", got, bad))
	check(bad == 0, "a partner never stands in a stone", bad)
	check(got > 0, "the gap is still used", got)
	quiet(w)
end)

runGroup("personal monsters (SpawnPersonal)", function()
	local w = newWorld()
	local function player(x, z, look)
		local p = { __kind = "Instance", Name = "P", Attrs = { Faction = "Halo" },
			Root = { Position = vec(x, 3, z), CFrame = { LookVector = look } } }
		function p:IsA(k) return k == "Player" end
		function p:GetAttribute(k) return self.Attrs[k] end
		p.Parent = true
		return p
	end
	-- facing -Z: the front spot (6 ahead) is inside a bush, the right side is free
	prop(w.Decor, "Bush", 400, -6, 8, 6, 8, 0)
	sync(w)
	local p = player(400, 0, vec(0, 0, -1))
	w.Made = {}
	local _, rec = w.P.SpawnPersonal(p, KING, { Distance = 6, Near = true })
	local props = propsOf(w)
	check(rec ~= nil and ORACLE(props, rec.Position, MT[KING]) == nil, "front blocked: a free side instead", rec and show(rec.Position))
	-- every side blocked (a ring of bushes): Near = nil (the caller tries again), never inside a bush
	for _, d in { { 6, 0 }, { -6, 0 }, { 0, 6 } } do prop(w.Decor, "Bush", 400 + d[1], d[2], 8, 6, 8, 0) end
	sync(w)
	w.Personal[p] = nil
	local p2 = player(400, 0, vec(0, 0, -1))
	w.Made = {}
	local m2 = w.P.SpawnPersonal(p2, KING, { Distance = 6, Near = true })
	check(m2 == nil and #w.Made == 0, "every side blocked + Near: nothing spawned", #w.Made)
	-- without Near: the home town spot (a town has no props here)
	local p3 = player(400, 0, vec(0, 0, -1))
	w.Made = {}
	local _, rec3 = w.P.SpawnPersonal(p3, KING, { Distance = 6 })
	check(rec3 ~= nil and C.ZoneAt(rec3.Position).Id == "HaloTown", "every side blocked, no Near: the home-town spot",
		rec3 and show(rec3.Position))
end)

runGroup("personal monsters: 12 directions, two rings (검수 2026-10-11)", function()
	local w = newWorld()
	local function player(x, z, look, root)
		local p = { __kind = "Instance", Name = "P", Attrs = { Faction = "Halo" },
			Root = root ~= false and { Position = vec(x, 3, z), CFrame = { LookVector = look } } or nil }
		function p:IsA(k) return k == "Player" end
		function p:GetAttribute(k) return self.Attrs[k] end
		p.Parent = true
		return p
	end
	-- thin posts on the four sides at 6 studs: the first diagonal (+30 degrees, front first) at 6 is free
	for _, d in { { 0, -6 }, { 6, 0 }, { -6, 0 }, { 0, 6 } } do
		part(w.Decor, "Post", { x = 600 + d[1], y = 2, z = d[2], sx = 1, sy = 4, sz = 1, col = false, query = false, class = "Part" })
	end
	sync(w)
	local p = player(600, 0, vec(0, 0, -1))
	local _, rec = w.P.SpawnPersonal(p, SLIME, { Distance = 6, Near = true })
	local props = propsOf(w)
	local want = vec(600 + 6 * math.sin(math.rad(30)), 0, -6 * math.cos(math.rad(30)))
	check(rec ~= nil and math.abs(rec.Position.X - want.X) < 1e-6 and math.abs(rec.Position.Z - want.Z) < 1e-6,
		"four sides blocked: the +30 degree spot at 6 studs (front first)", rec and show(rec.Position))
	check(rec ~= nil and ORACLE(props, rec.Position, MT[SLIME]) == nil, "never inside a post", rec and show(rec.Position))
	-- a ring of posts all round at 6 studs (every 10 degrees): the second ring (9 studs) is used
	local w2 = newWorld()
	for k = 0, 35 do
		local a = math.rad(k * 10)
		part(w2.Decor, "Post", { x = 700 + math.cos(a) * 6, y = 2, z = math.sin(a) * 6, sx = 1, sy = 4, sz = 1, col = false,
			query = false, class = "Part" })
	end
	sync(w2)
	local p2 = player(700, 0, vec(0, 0, -1))
	local _, rec2 = w2.P.SpawnPersonal(p2, SLIME, { Distance = 6, Near = true })
	local d2 = rec2 and math.sqrt((rec2.Position.X - 700) ^ 2 + rec2.Position.Z ^ 2) or -1
	check(rec2 ~= nil and math.abs(d2 - 9) < 1e-6 and ORACLE(propsOf(w2), rec2.Position, MT[SLIME]) == nil,
		"every spot at 6 blocked: one at 9 studs (1.5 x the distance)", show({ d2 }))
	-- the home-town spot with a rock on it: nothing (never inside the rock)
	local w3 = newWorld()
	local zone = C.Zones[C.HomeZoneId("Halo")]
	prop(w3.Decor, "TownRock", zone.Spawn.X, zone.Spawn.Z - 8, 8, 6, 8, 0)
	sync(w3)
	local m3 = w3.P.SpawnPersonal(player(0, 0, vec(0, 0, -1), false), KING, {})
	check(m3 == nil and #w3.Made == 0, "no root, the town spot blocked: nothing spawned", #w3.Made)
	local w4 = newWorld()
	sync(w4)
	local _, rec4 = w4.P.SpawnPersonal(player(0, 0, vec(0, 0, -1), false), KING, {})
	check(rec4 ~= nil and C.ZoneAt(rec4.Position).Id == "HaloTown", "no root, a free town spot: spawned there",
		rec4 and show(rec4.Position))
end)

local function indexWarnings(w)
	local n = 0
	for _, t in w.Warnings do if string.find(t, "spawn clearance index", 1, true) then n += 1 end end
	return n
end

runGroup("the index: first build, rebuilds when the Map changes", function()
	local w = newWorld()
	w.Auto = false
	w.Tick = 0.0001 -- a rebuild of 500 props takes more than one time budget (0.002 s = 20 clock reads)
	forest(w, RUINS, 500)
	local CL = w.G.CLEAR
	check(CL.Grid == nil, "nothing built before the first spawn")
	fits(w, 0, 0, SLIME)
	check(CL.Grid ~= nil and w.Waits == 0 and #w.Spawned == 0, "the first spawn builds it at once (no yield, no job)",
		show({ w.Waits, #w.Spawned }))
	check(CL.Watched == true and CL.Map == w.Map and CL.Dirty == false, "the Map is watched, the index clean")
	-- nothing changed: no rebuild, however long
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	check(#w.Spawned == 0, "the Map unchanged: no rebuild job after 2 minutes", #w.Spawned)
	-- a new rock: the Map's DescendantAdded marks the index dirty, the next check rebuilds it in the background
	prop(w.Decor, "NewRock", 300, 150, 6, 5, 6, 0)
	check(CL.Dirty == true, "a part added under the Map marks the index dirty")
	check(fits(w, 300, 150, SLIME), "the job is queued, the old index serves meanwhile")
	check(#w.Spawned == 1, "one background job", #w.Spawned)
	fits(w, 0, 0, SLIME)
	check(#w.Spawned == 1, "no second job while one runs", #w.Spawned)
	local waits = w.Waits
	w:RunSpawned()
	check(w.Waits > waits, "the background rebuild yields on its time budget", w.Waits - waits)
	check(not fits(w, 300, 150, SLIME), "after the job: the new rock blocks")
	-- the next change waits for the next check (REFRESH 60 s after the last start)
	local rock2 = prop(w.Decor, "NewRock2", 320, -150, 6, 5, 6, 0)
	fits(w, 0, 0, SLIME)
	check(#w.Spawned == 0, "a change right after a rebuild: no job before 60 s", #w.Spawned)
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w:RunSpawned()
	check(not fits(w, 320, -150, SLIME), "60 s later the next rock is picked up")
	-- a removed part marks it dirty too
	unput(rock2)
	check(CL.Dirty == true, "a part removed from the Map marks the index dirty")
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w:RunSpawned()
	check(fits(w, 320, -150, SLIME), "the removed rock no longer blocks after the rebuild")
	-- a failed rebuild keeps the old index, says so, and is tried again at the next check
	prop(w.Decor, "NewRock3", 340, 150, 6, 5, 6, 0)
	w.Broken.On = true
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w:RunSpawned()
	w.Broken.On = false
	check(fits(w, 340, 150, SLIME) and not fits(w, 300, 150, SLIME), "a failed rebuild keeps the old index")
	check(indexWarnings(w) == 1 and CL.Dirty == true, "a failed rebuild is warned and stays dirty", indexWarnings(w))
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w:RunSpawned()
	check(not fits(w, 340, 150, SLIME), "the next check rebuilds it")
	-- a Map taken out of the workspace: rebuilt, but never swapped in (the old index stays)
	prop(w.Decor, "NewRock4", 360, -150, 6, 5, 6, 0)
	w.Map.Parent = nil
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	check(#w.Spawned == 1, "a Map out of the workspace: a job", #w.Spawned)
	w:RunSpawned()
	check(fits(w, 360, -150, SLIME) and not fits(w, 340, 150, SLIME), "its index is not swapped in (the old one serves)")
	w.Map.Parent = w.Workspace
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w:RunSpawned()
	check(not fits(w, 360, -150, SLIME), "back in the workspace: swapped in at the next check")
end)

runGroup("the index: a failed first build, an unwatched Map", function()
	local w = newWorld()
	w.Auto = false
	prop(w.Decor, "Rock", 300, 150, 6, 5, 6, 0)
	w.Broken.On = true
	fits(w, 0, 0, SLIME)
	check(w.G.CLEAR.Grid ~= nil and next(w.G.CLEAR.Grid) == nil and indexWarnings(w) == 1,
		"a failed first build: an empty index and one warning", indexWarnings(w))
	for _ = 1, 5 do fits(w, 0, 0, SLIME) end
	check(indexWarnings(w) == 1 and #w.Spawned == 0, "the next spawn tries do not build again at once (no build storm)",
		indexWarnings(w))
	w.Broken.On = false
	w.Clock += 61
	fits(w, 0, 0, SLIME)
	w:RunSpawned()
	check(not fits(w, 300, 150, SLIME), "the background rebuild 60 s later fills it")
	-- a Map without the change signals: rebuilt at every check (never trusted to be clean)
	local w2 = newWorld()
	w2.Auto = false
	w2.Map.DescendantAdded, w2.Map.DescendantRemoving = nil, nil
	fits(w2, 0, 0, SLIME)
	check(w2.G.CLEAR.Watched == false, "no signals: not watched")
	w2.Clock += 61
	fits(w2, 0, 0, SLIME)
	check(#w2.Spawned == 1, "unwatched: a rebuild job at every check, changed or not", #w2.Spawned)
	w2:RunSpawned()
end)

runGroup("the index: no Map yet", function()
	local w = newWorld()
	w.Auto = false
	prop(w.Decor, "Rock", 300, 150, 6, 5, 6, 0)
	w.MapShown = false
	fits(w, 300, 150, SLIME)
	check(w.G.CLEAR.Grid == nil, "no Map: nothing built, tried again next time")
	w.MapShown = true
	w.Clock += 1
	check(not fits(w, 300, 150, SLIME), "the Map appears: built at the next spawn (no 60 s wait)")
	quiet(w)
end)

-- a world-kit tree as the place builds it: Model W_Tree_* = the mesh (upright, yaw) + an invisible collidable TrunkPost
-- (cylinder, X axis up, 8 tall) near the mesh centre
local TREES = { -- mesh size and TrunkPost diameter as in the place (72a5f19b)
	W_Tree_A = { 14.5, 23.5, 13.5, 2.64 },
	W_Tree_B = { 19.8, 24.2, 14.9, 3.85 },
	W_Tree_C = { 18.8, 24.0, 12.0, 3.5 },
	W_GiantTree = { 62.2, 80.0, 46.3, 8.33 },
}
local function kitTree(parent, name, x, z, yaw, extraPost)
	local t = TREES[name]
	local model = put(parent, node("Model", name))
	prop(model, name, x, z, t[1], t[2], t[3], yaw or 0)
	part(model, "TrunkPost", { x = x + 0.5, y = 4, z = z - 0.3, sx = 8, sy = t[4], sz = t[4], roll = 90, tr = 1, col = true,
		query = false, class = "Part" })
	if extraPost then
		part(model, "TrunkPost", { x = x - 3, y = 4, z = z, sx = 8, sy = 2, sz = 2, roll = 90, tr = 1, col = true, query = false,
			class = "Part" })
	end
	return model
end

runGroup("trees: trunk base + canopy (검수 2026-10-11)", function()
	local w = newWorld()
	check(SCF.TreeRule == true and SCF.Trees.W_Tree_B.Base == 0.36 and SCF.Trees.W_Tree_B.Canopy == 0.36
		and SCF.Trees.W_Tree_A.Base == 0.26 and SCF.Trees.W_Tree_C.Canopy == 0.46 and SCF.Trees.W_GiantTree == nil,
		"Config.SpawnClear.Trees: A 0.26 / 0.26, B 0.36 / 0.36, C 0.34 / 0.46; the giant tree is not listed", show(SCF.Trees))
	kitTree(w.Decor, "W_Tree_B", 400, 0, 30)
	local R = 0.36 * 19.8 -- 7.13
	local px, pz = 400.5, -0.3 -- the TrunkPost centre (the disc centre)
	check(not fits(w, px, pz, SLIME), "at the trunk: blocked")
	check(not fits(w, px + R + 1.5 - 0.05, pz, SLIME), "a slime's body 0.05 inside the trunk-base disc: blocked")
	check(fits(w, px + R + 1.5 + 0.05, pz, SLIME), "0.05 outside the disc, under the canopy: free (the full box closed it)")
	check(fits(w, px + R + 1.25 + 0.05, pz, GOBLIN), "a Goblin (5 tall) under the canopy (bottom 8.7): free")
	check(fits(w, px + R + 1.875 + 0.05, pz, BRUTE), "a Goblin Brute (7.5) under it: free")
	check(not fits(w, px + R + 4.8 + 0.05, pz, KING), "the King Slime (9.6) reaches the canopy (8.7): blocked")
	-- MonsterService.GroundAt(x, z, kind) (the Studio probe): the same body rule, no kind = the plain ground
	sync(w)
	check(w.E.GroundAt(px, pz) ~= nil and w.E.GroundAt(px, pz, SLIME) == nil and w.E.GroundAt(px + R + 2, pz, SLIME) ~= nil,
		"GroundAt(x, z, kind): blocked at the trunk with a kind, ground without one, free outside the disc")
	-- the trees the rule never relaxes: the giant tree, a model with two posts, a mesh without its post, the switch off
	local w2 = newWorld()
	kitTree(w2.Decor, "W_GiantTree", 1000, 0, 0)
	check(not fits(w2, 1000 + 10, 0, SLIME), "the giant tree (not listed): its full box blocks under the canopy")
	kitTree(w2.Decor, "W_Tree_B", 1100, 0, 0, true)
	check(not fits(w2, 1100 + 0.5 + R + 2, -0.3, SLIME), "a tree model with two TrunkPosts: its full box (fail-safe)")
	local bare = put(w2.Decor, node("Model", "W_Tree_C"))
	prop(bare, "W_Tree_C", 1200, 0, 18.8, 24, 12, 0)
	check(not fits(w2, 1200 + 0.34 * 18.8 + 2, 0, SLIME), "a tree mesh without a TrunkPost: its full box")
	local w3 = newWorld()
	kitTree(w3.Decor, "W_Tree_B", 400, 0, 30)
	SCF.TreeRule = false
	local blocked = not fits(w3, px + R + 2, pz, SLIME)
	SCF.TreeRule = true
	check(blocked, "Config.SpawnClear.TreeRule = false: the full box again")
	-- the oracle agrees with every pick around a tree
	local w4 = newWorld()
	for i = 0, 8 do kitTree(w4.Decor, ({ "W_Tree_A", "W_Tree_B", "W_Tree_C" })[i % 3 + 1], 300 + (i % 3) * 30, -60 + i // 3 * 30, i * 37) end
	sync(w4)
	local props, bad, free = propsOf(w4), 0, 0
	for x = 280, 370, 1.5 do
		for z = -80, 20, 1.5 do
			for _, kind in { SLIME, GOBLIN, BRUTE, KING } do
				local g = w4.G.groundPoint(x, z, nil, MT[kind])
				if g then
					free += 1
					if ORACLE(props, g, MT[kind]) then bad += 1 end
				end
			end
		end
	end
	check(bad == 0 and free > 0, "a 3 x 3 grove on a 1.5-stud grid: no free point has a trunk / canopy inside the body (oracle)",
		show({ bad, free }))
	quiet(w)
end)

runGroup("ground cover and effects never block (검수 2026-10-11)", function()
	local w = newWorld()
	check(SCF.PassRule == true and table.find(SCF.Pass, "Flower") and table.find(SCF.Pass, "StepStone")
		and table.find(SCF.Pass, "Falls") and table.find(SCF.Pass, "Wisp") and table.find(SCF.NotPass, "Cart"),
		"Config.SpawnClear: PassRule on, Pass has Flower / StepStone / Falls / Wisp, NotPass has Cart")
	local flowers = put(w.Decor, node("Model", "Kit_M_FlowersA"))
	prop(flowers, "Kit_M_FlowersA", 400, 0, 2.9, 2.9, 2.9, 0)
	check(fits(w, 400, 0, PRINCE), "knee-high flowers (non-collidable): free")
	prop(w.Decor, "Kit_W_StepStones", 420, 0, 8.4, 0.6, 3, 0)
	check(fits(w, 420, 0, SLIME), "step stones (0.6 tall, over the foot gap): free")
	part(w.Decor, "FallsSheet", { x = 440, y = 9.75, z = 0, sx = 12, sy = 19.5, sz = 0.9, tr = 0.3, col = false, query = false, class = "Part" })
	check(fits(w, 440, 0, SLIME), "a waterfall sheet: free")
	part(w.Decor, "SoulWisp", { x = 460, y = 2, z = 0, sx = 1.5, sy = 1.5, sz = 1.5, col = false, query = false, class = "Part" })
	check(fits(w, 460, 0, SLIME), "a soul wisp: free")
	local cart = put(w.Decor, node("Model", "Kit_M_FlowerCart"))
	prop(cart, "Kit_M_FlowerCart", 480, 0, 6, 4.6, 4, 0, { col = true })
	check(not fits(w, 480, 0, SLIME), "a flower cart (NotPass, collidable): blocked")
	prop(w.Decor, "FlowerBedWall", 500, 0, 6, 2, 2, 0, { col = true })
	check(not fits(w, 500, 0, SLIME), "a collidable part named Flower...: blocked (only non-collidable ones pass)")
	prop(w.Decor, "Kit_M_PotFlowers", 520, 0, 3, 3, 3, 0)
	check(not fits(w, 520, 0, SLIME), "flowers in a pot (NotPass 'Pot'): blocked")
	-- 최종 검수 2026-10-12: a puddle passes, its stone rim (non-collidable, 8.2 x 2.5 x 8.2 in the meadow) blocks
	part(w.Decor, "Puddle", { x = 540, y = 0.05, z = 0, sx = 6, sy = 0.1, sz = 6, col = false, query = false, class = "Part" })
	check(fits(w, 540, 0, SLIME), "a puddle: free")
	prop(w.Decor, "Kit_M_PuddleRim", 560, 0, 8.2, 2.5, 8.2, 0)
	check(not fits(w, 560, 0, SLIME), "a puddle's stone rim (NotPass 'Rim', non-collidable): blocked")
	SCF.PassRule = false
	w.G.CLEAR.Grid = nil
	local off = not fits(w, 400, 0, PRINCE)
	SCF.PassRule = true
	w.G.CLEAR.Grid = nil
	check(off, "Config.SpawnClear.PassRule = false: the flowers block again")
	quiet(w)
end)

-- the woods as the place dresses them: kit trees on a jittered grid (22 studs), a share of each kind
local function grove(w, cx, cz, half, spacing)
	local seed = 11
	local function rnd(a, b)
		seed = (seed * 48271) % 2147483647
		return a + (b - a) * ((seed - 1) / 2147483646)
	end
	local dress = put(w.Decor, node("Folder", "WoodsDress"))
	local n = 0
	for x = cx - half, cx + half, spacing do
		for z = cz - half, cz + half, spacing do
			n += 1
			kitTree(dress, ({ "W_Tree_A", "W_Tree_B", "W_Tree_C" })[n % 3 + 1], x + rnd(-6, 6), z + rnd(-6, 6), rnd(0, 360))
		end
	end
	return n
end

runGroup("woods spawn area: the tree rule vs the full box (검수 2026-10-11)", function()
	local w = newWorld()
	local cx, cz, half = 950, 0, 110
	local trees = grove(w, cx, cz, half, 22)
	sync(w)
	local CELLS = 40
	local function measure(kind)
		local free, total, cells = 0, 0, {}
		for x = cx - half, cx + half, 2 do
			for z = cz - half, cz + half, 2 do
				total += 1
				local k = math.floor((x - cx + half) / CELLS) * 100 + math.floor((z - cz + half) / CELLS)
				cells[k] = cells[k] or { 0, 0 }
				cells[k][2] += 1
				if w.G.groundPoint(x, z, nil, MT[kind]) then
					free += 1
					cells[k][1] += 1
				end
			end
		end
		local starved, n = 0, 0
		for _, c in cells do
			n += 1
			if c[1] < c[2] * 0.25 then starved += 1 end
		end
		return free / total, starved, n
	end
	local res = {}
	for _, kind in { GOBLIN, BRUTE } do
		SCF.TreeRule = false
		w.G.CLEAR.Grid = nil
		local fullShare, fullStarved, n = measure(kind)
		SCF.TreeRule = true
		w.G.CLEAR.Grid = nil
		local treeShare, treeStarved = measure(kind)
		res[kind] = { fullShare, treeShare, fullStarved, treeStarved, n }
		finding(string.format("%d kit trees, %s: free %.1f%% (full box) -> %.1f%% (tree rule); 40-stud cells under 25%% free: %d -> %d of %d",
			trees, kind, fullShare * 100, treeShare * 100, fullStarved, treeStarved, n))
		check(treeShare >= fullShare * 1.25, kind .. ": the tree rule leaves at least 25% more spawn area than the full box",
			show(res[kind]))
		check(treeStarved <= fullStarved and treeStarved * 4 <= n, kind .. ": no more starved cells, and at most a quarter of them",
			show(res[kind]))
	end
	check(res[GOBLIN][2] >= res[BRUTE][2], "a Goblin finds at least as much room as a Brute", show({ res[GOBLIN][2], res[BRUTE][2] }))
	quiet(w)
end)

runGroup("walks keep the old rule", function()
	local w = newWorld()
	prop(w.Decor, "W_Tree_C", 400, 0, 20, 24, 15, 0)
	check(w.G.groundPoint(400, 0) ~= nil, "a walk target under a tree mesh: still ground (only new monsters are kept out)")
	check(w.G.groundPoint(400, 0, nil, nil) ~= nil, "def nil = no body check")
end)

finish()
