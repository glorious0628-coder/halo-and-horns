-- woods_kit_place.luau (게임성 개발 1, 2026-10-08; docs/design/kit_woods.md)
-- Studio MCP execute_luau, main place, Edit mode, map v2 (Config.Map.Lands LandWoods x 710..1190, z -260..260).
-- Puts the Tripo woods kit (ServerStorage.WorldKit3D) into Map.Decor.WoodsKit:
--   * the fixed pieces first: W_GiantTree (960, -90) with its tree houses toward the crown road; the three goblin camps
--     (Config.StoryQuests.Landmarks GoblinCamp1-3: tent at the back facing the fire, fence arcs on both sides, the open
--     side toward the road, crates, loot sacks, stump seats round a temporary fire = Roblox Fire + 1 PointLight until a
--     Kit_W_Campfire is in the kit; the old primitive camps had one light each); the boss clearing (1110, 120: empty
--     middle, a stump ring, a wide stump table and two plain cloth banners on the deep side, no orange = PvP border
--     colour); a totem by the gate; lantern posts along the crown road; sign posts; fallen logs, boulders, stumps
--   * then trees W_Tree_A/B/C in groves (검수 2026-10-08: 2-4 together with open glades between, not a checkerboard):
--     grove centres on a jittered grid, 1-4 trees each (trunks 12+ apart = 4+ studs of gap for a big goblin), about
--     one centre in five left empty; only on woods grass, never on the roads, in the camps, the clearing, the arrival or
--     on another piece. Monsters have no fixed spawn spots in the woods (MonsterService pickSpawnPoint: random ground
--     25+ inside the zone or 18-28 from a starved player, never on solid decor; leash 60, stuck -> detour), so the
--     fighting room is the open ground between the groves (MODE "dry" measures it). The mesh never collides, an
--     invisible trunk post at the measured trunk
--     (EditableMesh, 2026-10-08) does, so players and monsters bump the trunk, not the leaves (MonsterService
--     CR-L14 treats it as solid decor: no monster spawns inside a trunk)
-- The old primitive woods decor (Decor "Tree" and "GoblinCamp" inside LandWoods) moves to
-- ServerStorage.WoodsPrimitiveBackup; nothing is destroyed. The red-eye bushes (DarkBush / RedEye) stay.
-- MODE "dry" = read only: count what "kit" would place; "plan" = read only: every piece as name,x,z,radius,yaw (for a
-- top-down check picture); "kit" = (re)build WoodsKit (idempotent; also lifts the red-eye bush the v2 settle sank 26
-- studs under the ground back onto it); "old" = remove WoodsKit and put the primitives back.
local MODE = "__MODE__"
local SS = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local map = workspace:FindFirstChild("Map")
assert(map and map:FindFirstChild("Decor"), "workspace.Map.Decor missing")
local decor = map.Decor
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit, "ServerStorage.WorldKit3D missing")

local LAND = { MinX = 710, MaxX = 1190, MinZ = -260, MaxZ = 260 }
for _, l in (Config.Map and Config.Map.Lands) or {} do
	if l.Name == "LandWoods" then LAND = l end
end
local SPOTS = (Config.StoryQuests and Config.StoryQuests.Landmarks) or {}
local CAMPS = { -- Road = the open side (toward the crown road / the trail)
	{ Pos = SPOTS.GoblinCamp1 or Vector3.new(840, 0, 95), Road = Vector3.new(0, 0, -1), Tent = "W_Tent_A" },
	{ Pos = SPOTS.GoblinCamp2 or Vector3.new(1010, 0, 130), Road = Vector3.new(0, 0, -1), Tent = "W_Tent_B" },
	{ Pos = SPOTS.GoblinCamp3 or Vector3.new(1090, 0, -150), Road = Vector3.new(-1, 0, 0), Tent = "W_Tent_A" }, -- trail end
}
local GIANT = Vector3.new(960, 0, -90)
local BOSS = Vector3.new(1110, 0, 120)
local ARRIVAL = (Config.Zones.GoblinWoods and Config.Zones.GoblinWoods.Spawn) or Vector3.new(730, 0, 0)
local T = {
	Seed = 20261008, Inset = 12,
	Grove = { Spacing = 54, Jitter = 12, Empty = 0.2, Ring = { 10, 16 }, Sizes = { 1, 2, 2, 3, 3, 3, 4, 4 } },
	TreeMin = 12, -- trunk centre to trunk centre
	RoadHalf = 18, TrailZ = -150, TrailHalf = 11, TrailMinX = 748, TrailMaxX = 1132,
	CampClear = 30, GiantClear = 42, BossClear = 31, ArrivalClear = 26, GateMaxX = 738, Gap = 2,
	TreeScale = { 0.8, 1.1 }, -- the giant tree (80) stays the tallest
	-- trunk post per tree, model pivot space at scale 1 (pivot = bottom centre), measured from the mesh 2026-10-08
	Trees = {
		W_Tree_A = { X = 0, Z = 0, D = 5.6 },
		W_Tree_B = { X = 1.4, Z = 1.6, D = 7 },
		W_Tree_C = { X = -0.4, Z = -0.8, D = 7 },
	},
	TreeNames = { "W_Tree_A", "W_Tree_B", "W_Tree_C" },
	PostH = 12,
	TreeGround = { LeafyGrass = true, Grass = true, Mud = true }, -- by name (EnumItem table keys missed in Studio)
	Wood = Color3.fromRGB(92, 64, 42), Cloth = Color3.fromRGB(78, 104, 70), Patch = Color3.fromRGB(122, 98, 70),
}

------------------------------------------------------------------ old primitives <-> backup
local backup = SS:FindFirstChild("WoodsPrimitiveBackup")
local function inLand(p, inset)
	inset = inset or 0
	return p.X >= LAND.MinX + inset and p.X <= LAND.MaxX - inset and p.Z >= LAND.MinZ + inset and p.Z <= LAND.MaxZ - inset
end
local function posOf(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if not inst:IsA("PVInstance") then return nil end
	local ok, cf = pcall(inst.GetPivot, inst)
	return ok and cf.Position or nil
end

if MODE == "old" then
	local old = decor:FindFirstChild("WoodsKit")
	if old then old:Destroy() end
	local back = 0
	if backup then
		for _, d in backup:GetChildren() do d.Parent = decor; back += 1 end
	end
	return "WoodsKit removed, primitives back: " .. back
end
assert(MODE == "dry" or MODE == "plan" or MODE == "kit", "MODE must be dry, plan, kit or old")

------------------------------------------------------------------ ground
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain, map:FindFirstChild("Ground") }
params.IgnoreWater = false
-- ground height + material on dry, flat-ish woods land, or nil (water, the mountain foot, outside)
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	if not hit or hit.Material == Enum.Material.Water then return nil end
	local y = hit.Position.Y
	if y < -0.8 or y > 6 then return nil end
	return y, hit.Material
end

------------------------------------------------------------------ plan: the fixed pieces, then the trees round them
local plan = {} -- { Kind, Name, Pos, Yaw, Scale, Solid }
local reserved = {} -- { Pos, R } circles trees keep out of
local rng = Random.new(T.Seed)
local function flat(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end
local function yawToward(from, to) -- yaw that turns a model's front (-Z) toward `to`
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if d.Magnitude < 1e-3 then return 0 end
	return math.deg(math.atan2(-d.X, -d.Z))
end
local function radiusOf(name, scale)
	local src = kit:FindFirstChild(name)
	if not src then return 3 end
	local size = src:IsA("Model") and select(2, src:GetBoundingBox()) or src.Size
	return math.max(size.X, size.Z) / 2 * (scale or 1)
end
local function add(kind, name, pos, yaw, scale, solid, r)
	table.insert(plan, { Kind = kind, Name = name, Pos = pos, Yaw = yaw or 0, Scale = scale or 1, Solid = solid })
	table.insert(reserved, { Pos = pos, R = r or radiusOf(name, scale) })
end

-- the giant tree: tree houses toward the crown road
add("kit", "W_GiantTree", GIANT, yawToward(GIANT, Vector3.new(GIANT.X, 0, 0)), 1, true)

-- camps (local frame: back = away from the road, side = across)
for i, c in CAMPS do
	local road = c.Road
	local back = -road
	local side = Vector3.new(-road.Z, 0, road.X)
	local function at(b, s) return c.Pos + back * b + side * s end
	local tentPos = at(11, 0)
	add("kit", c.Tent, tentPos, yawToward(tentPos, c.Pos), 1, true)
	for _, deg in { 50, 75, 100 } do -- fence arcs on both sides (radius 16), the tent closes the back
		for _, s in { 1, -1 } do
			local a = math.rad(deg)
			local p = at(math.cos(a) * 16, s * math.sin(a) * 16)
			add("kit", "Kit_W_CampFence", p, yawToward(p, c.Pos), 1, true) -- front toward the fire = along the arc
		end
	end
	for _, s in { 1, -1 } do
		local p = at(7, s * 9)
		add("kit", "Kit_W_Crates", p, yawToward(p, c.Pos) + s * 20, s > 0 and 1 or 0.85, true)
		local sack = at(4.5, s * 6.5)
		add("kit", "Kit_W_LootSack", sack, yawToward(sack, sack + road), 1, false) -- coins toward the road
	end
	for _, deg in { 60, 180, 300 } do -- stump seats round the fire
		local a = math.rad(deg)
		add("kit", "Kit_W_Stump", at(math.cos(a) * 4.5, math.sin(a) * 4.5), deg, 0.5, false)
	end
	add("fire", "CampfireTemp", c.Pos, i * 40, 1, false, 3)
	for _, s in { 1, -1 } do
		local p = at(8, s * 23)
		add("kit", s > 0 and "W_Boulder_A" or "W_Boulder_B", p, yawToward(p, c.Pos), 0.6, true)
	end
end

-- boss clearing: a stump ring (every third one big), the table and two banners on the deep side (away from the road)
local deeper = Vector3.new(0, 0, BOSS.Z >= 0 and 1 or -1)
for k = 0, 13 do
	local a = math.rad(k * (360 / 14) + 6)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	if dir:Dot(deeper) < 0.72 then -- the table side stays open
		local big = k % 3 == 0
		add("kit", "Kit_W_Stump", BOSS + dir * 17, k * 53, big and 1 or 0.6, big)
	end
end
local tablePos = BOSS + deeper * 23
add("kit", "Kit_W_Stump", tablePos, 15, 2.2, true)
for _, s in { 1, -1 } do
	local p = tablePos + Vector3.new(7.5 * s, 0, 1.5)
	add("banner", "BossBanner", p, yawToward(p, BOSS), 1, true, 3)
end

-- the totem just inside the gate, beside the road
local totemPos = Vector3.new(LAND.MinX + 16, 0, 15)
add("kit", "W_Totem", totemPos, yawToward(totemPos, Vector3.new(totemPos.X, 0, 0)), 1, true)

-- lantern posts along the crown road, alternating sides
local n = 0
for x = LAND.MinX + 40, LAND.MaxX - 30, 48 do
	n += 1
	local p = Vector3.new(x, 0, n % 2 == 0 and 13 or -13)
	add("kit", "Kit_W_LanternPost", p, yawToward(p, Vector3.new(x, 0, 0)), 1, true)
end

-- sign posts: by the arrival (toward the trail), toward camp 1, toward the giant tree, before the pass
for _, s in { { 770, -14 }, { 840, 14 }, { 960, -14 }, { 1160, 14 } } do
	local p = Vector3.new(s[1], 0, s[2])
	add("kit", "Kit_W_SignPost", p, yawToward(p, Vector3.new(s[1], 0, 0)), 1, true)
end

-- fallen logs, boulders and stumps at the edges and between the trees
for _, s in { { 745, 205 }, { 905, 238 }, { 1135, 175 }, { 760, -232 }, { 1000, -240 }, { 1095, -215 } } do
	add("kit", "Kit_W_FallenLog", Vector3.new(s[1], 0, s[2]), rng:NextNumber(0, 180), 1, true)
end
for k, s in { { 732, 120 }, { 880, -210 }, { 1060, 230 }, { 1175, 60 }, { 790, 180 }, { 1140, -40 } } do
	local p = Vector3.new(s[1], 0, s[2])
	add("kit", k % 2 == 0 and "W_Boulder_A" or "W_Boulder_B", p, rng:NextNumber(0, 360), rng:NextNumber(0.7, 1), true)
end
for _, s in { { 790, 60 }, { 900, 170 }, { 1045, -60 }, { 1120, 210 }, { 880, -120 }, { 1135, -105 }, { 760, -80 }, { 1000, 60 } } do
	add("kit", "Kit_W_Stump", Vector3.new(s[1], 0, s[2]), rng:NextNumber(0, 360), rng:NextNumber(0.7, 1.0), false)
end

-- the red-eye bushes stay where they are: trees keep clear of them
for _, d in decor:GetChildren() do
	if d.Name == "DarkBush" then
		local p = posOf(d)
		if p and inLand(p, -10) then table.insert(reserved, { Pos = p, R = 4 }) end
	end
end

-- trees in groves (see the header)
local why = { road = 0, trail = 0, gate = 0, area = 0, piece = 0, ground = 0, crowd = 0 }
local grounds = {}
local trees = {} -- { Pos, R } placed trunks
local function treeSpot(p, r)
	if not inLand(p, T.Inset) then return "ground" end
	if math.abs(p.Z) < T.RoadHalf then return "road" end
	if p.X > T.TrailMinX and p.X < T.TrailMaxX and math.abs(p.Z - T.TrailZ) < T.TrailHalf then return "trail" end
	if p.X < T.GateMaxX then return "gate" end
	if flat(p, GIANT) < T.GiantClear or flat(p, BOSS) < T.BossClear or flat(p, ARRIVAL) < T.ArrivalClear then return "area" end
	for _, c in CAMPS do if flat(p, c.Pos) < T.CampClear then return "area" end end
	for _, q in reserved do if flat(p, q.Pos) < q.R + r + T.Gap then return "piece" end end
	for _, q in trees do if flat(p, q.Pos) < T.TreeMin then return "crowd" end end
	local _, mat = ground(p.X, p.Z)
	grounds[tostring(mat)] = (grounds[tostring(mat)] or 0) + 1
	if not mat or not T.TreeGround[mat.Name] then return "ground" end
	return nil
end
local G = T.Grove
local groves = 0
for gx = LAND.MinX + T.Inset, LAND.MaxX - T.Inset, G.Spacing do
	for gz = LAND.MinZ + T.Inset, LAND.MaxZ - T.Inset, G.Spacing do
		local c = Vector3.new(gx + rng:NextNumber(-G.Jitter, G.Jitter), 0, gz + rng:NextNumber(-G.Jitter, G.Jitter))
		local size = rng:NextNumber() < G.Empty and 0 or G.Sizes[rng:NextInteger(1, #G.Sizes)]
		local turn = rng:NextNumber(0, math.pi * 2)
		local placed = 0
		for k = 1, size do
			local p = c + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			if k > 1 then -- round the grove centre, spread evenly with a wobble
				local a = turn + (k - 1) * (math.pi * 2 / math.max(size - 1, 1)) + rng:NextNumber(-0.5, 0.5)
				local d = rng:NextNumber(G.Ring[1], G.Ring[2])
				p = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			end
			local name = T.TreeNames[rng:NextInteger(1, #T.TreeNames)]
			local scale = rng:NextNumber(T.TreeScale[1], T.TreeScale[2])
			local yaw = rng:NextNumber(0, 360)
			local r = T.Trees[name].D / 2 * scale
			local bad = treeSpot(p, r)
			if bad then
				why[bad] += 1
			else
				table.insert(plan, { Kind = "tree", Name = name, Pos = p, Yaw = yaw, Scale = scale, Solid = false })
				table.insert(trees, { Pos = p, R = r })
				placed += 1
			end
		end
		if placed > 0 then groves += 1 end
	end
end

-- fighting room (read only report): on the ground monsters spawn on (25+ inside the zone), how far is the nearest
-- trunk / solid piece edge? share of 6-stud samples with 6+ (a 12-wide free circle) and 10+ studs of room; the smallest
-- trunk-to-trunk gap
local function roomReport()
	local zone = Config.Zones.GoblinWoods
	local inset = (Config.Monsters and Config.Monsters.SpawnInset) or 25
	local solid = {}
	for _, q in trees do table.insert(solid, q) end
	for _, e in plan do
		if e.Solid and e.Kind ~= "tree" then
			table.insert(solid, { Pos = e.Pos, R = (e.Kind == "kit") and radiusOf(e.Name, e.Scale) or 1 })
		end
	end
	local n, six, ten = 0, 0, 0
	for x = zone.Center.X - zone.Size.X / 2 + inset, zone.Center.X + zone.Size.X / 2 - inset, 6 do
		for z = zone.Center.Z - zone.Size.Z / 2 + inset, zone.Center.Z + zone.Size.Z / 2 - inset, 6 do
			if ground(x, z) then
				local p, room = Vector3.new(x, 0, z), math.huge
				for _, q in solid do room = math.min(room, flat(p, q.Pos) - q.R) end
				if room > 0 then
					n += 1
					if room >= 6 then six += 1 end
					if room >= 10 then ten += 1 end
				end
			end
		end
	end
	local gap = math.huge
	for i, a in trees do
		for j = i + 1, #trees do
			local b = trees[j]
			gap = math.min(gap, flat(a.Pos, b.Pos) - a.R - b.R)
		end
	end
	return string.format("fighting room: %d samples, %.0f%% with 6+ studs, %.0f%% with 10+; smallest trunk gap %.1f; groves %d",
		n, n > 0 and six / n * 100 or 0, n > 0 and ten / n * 100 or 0, gap, groves)
end

------------------------------------------------------------------ plan / dry run (read only)
if MODE == "plan" then
	local rows = {}
	for _, e in plan do
		local r = e.Kind == "tree" and T.Trees[e.Name].D / 2 * e.Scale or radiusOf(e.Name, e.Scale)
		if e.Kind ~= "kit" and e.Kind ~= "tree" then r = 3 end
		table.insert(rows, string.format("%s,%.1f,%.1f,%.1f,%.0f,%d", e.Name, e.Pos.X, e.Pos.Z, r, e.Yaw, ground(e.Pos.X, e.Pos.Z) and 1 or 0))
	end
	return table.concat(rows, ";")
end
local function counts(list)
	local c, names = {}, {}
	for _, e in list do
		if not c[e.Name] then table.insert(names, e.Name) end
		c[e.Name] = (c[e.Name] or 0) + 1
	end
	table.sort(names)
	local out = {}
	for _, k in names do table.insert(out, k .. " x" .. c[k]) end
	return table.concat(out, ", ")
end
if MODE == "dry" then
	local off, missing = {}, {}
	for _, e in plan do
		if not ground(e.Pos.X, e.Pos.Z) then table.insert(off, string.format("%s(%.0f,%.0f)", e.Name, e.Pos.X, e.Pos.Z)) end
		if (e.Kind == "kit" or e.Kind == "tree") and not kit:FindFirstChild(e.Name) then missing[e.Name] = true end
	end
	local miss, w, g = {}, {}, {}
	for k in missing do table.insert(miss, k) end
	for k, v in why do table.insert(w, k .. " " .. v) end
	for k, v in grounds do table.insert(g, k:gsub("Enum.Material.", "") .. " " .. v) end
	local sunk = {}
	for _, d in decor:GetChildren() do
		local p = (d.Name == "DarkBush" or d.Name == "RedEye") and posOf(d)
		if p and inLand(p, -10) and p.Y < -3 then
			local y, mat = ground(p.X, p.Z)
			table.insert(sunk, string.format("%s(%.0f,%.1f,%.0f) ground %s %s", d.Name, p.X, p.Y, p.Z, tostring(y), tostring(mat)))
		end
	end
	return string.format("dry: %d pieces | %s\nnot on dry ground (skipped): %s\nmissing kit: %s\ntree spots refused: %s\n" ..
		"ground under tree candidates: %s\nsunk bushes: %s\n%s", #plan, counts(plan), #off > 0 and table.concat(off, " ") or "none",
		#miss > 0 and table.concat(miss, ",") or "none", table.concat(w, ", "), table.concat(g, ", "),
		#sunk > 0 and table.concat(sunk, "; ") or "none", roomReport())
end

------------------------------------------------------------------ build
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "WoodsPrimitiveBackup"
	backup.Parent = SS
end
local moved = 0
for _, d in decor:GetChildren() do
	if (d.Name == "Tree" or d.Name == "GoblinCamp") and (d:IsA("Model") or d:IsA("BasePart")) then
		local p = posOf(d)
		if p and inLand(p, -10) then d.Parent = backup; moved += 1 end
	end
end
-- the red-eye bush the v2 settle sank under the ground: bush ball 1.5 and eyes 2.0 above the ground (like the others)
local lifted = 0
for _, d in decor:GetChildren() do
	if d.Name == "DarkBush" and d:IsA("BasePart") and inLand(d.Position, -10) and d.Position.Y < -3 then
		local gy = ground(d.Position.X, d.Position.Z)
		if gy then
			for _, e in decor:GetChildren() do
				if e.Name == "RedEye" and e:IsA("BasePart") and e.Position.Y < -3 and flat(e.Position, d.Position) < 6 then
					e.Position = Vector3.new(e.Position.X, gy + 2, e.Position.Z)
					lifted += 1
				end
			end
			d.Position = Vector3.new(d.Position.X, gy + 1.5, d.Position.Z)
			lifted += 1
		end
	end
end
local old = decor:FindFirstChild("WoodsKit")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "WoodsKit"

local function finish(m, solid)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = solid
			p.CanQuery = solid
			p.CanTouch = false
			p.CastShadow = true
		end
	end
end
local function sit(m, y) -- bottom on the ground
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, y - (cf.Position.Y - size.Y / 2) - 0.05, 0))
end
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = parent
	return p
end

local made, skipped, missing = {}, 0, {}
for _, e in plan do
	local y = ground(e.Pos.X, e.Pos.Z)
	if not y then
		skipped += 1
		continue
	end
	local base = CFrame.new(e.Pos.X, y, e.Pos.Z) * CFrame.Angles(0, math.rad(e.Yaw), 0)
	if e.Kind == "tree" or e.Kind == "kit" then
		local src = kit:FindFirstChild(e.Name)
		if not src then
			missing[e.Name] = true
			continue
		end
		local m = src:Clone()
		if e.Scale ~= 1 then pcall(m.ScaleTo, m, m:GetScale() * e.Scale) end
		m:PivotTo(base)
		sit(m, y)
		finish(m, e.Solid)
		if e.Kind == "tree" then
			local t, s = T.Trees[e.Name], e.Scale
			local at = m:GetPivot():PointToWorldSpace(Vector3.new(t.X * s, 0, t.Z * s))
			local post = part({ Name = "TrunkPost", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(T.PostH * s, t.D * s, t.D * s),
				CFrame = CFrame.new(at.X, y + T.PostH * s / 2, at.Z) * CFrame.Angles(0, 0, math.rad(90)),
				Transparency = 1, CanCollide = true, CanQuery = true, CanTouch = false, CastShadow = false }, m)
			post:SetAttribute("Collider", true)
		end
		m.Parent = root
	elseif e.Kind == "fire" then -- temporary camp fire: crossed logs, embers, a Roblox Fire and one warm light
		local m = Instance.new("Model")
		m.Name = e.Name
		for k = 0, 1 do
			part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 0.7, 0.7), Color = T.Wood,
				Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, CanTouch = false,
				CFrame = base * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, math.rad(k * 90 + 20), 0) }, m)
		end
		local core = part({ Name = "Embers", Size = Vector3.new(1.4, 0.3, 1.4), Color = Color3.fromRGB(255, 160, 70),
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false,
			CFrame = base * CFrame.new(0, 0.5, 0) }, m)
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 4, 7
		fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 90, 30)
		fire.Parent = core
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 160, 80), 16, 1.5
		light.Parent = core
		m.PrimaryPart = core
		m.Parent = root
	elseif e.Kind == "banner" then -- plain cloth banner: pole + cloth + two patches (no pattern, no orange)
		local m = Instance.new("Model")
		m.Name = e.Name
		local pole = part({ Name = "Pole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.5, 0.6, 0.6), Color = T.Wood,
			Material = Enum.Material.Wood, CFrame = base * CFrame.new(0, 4.25, 0) * CFrame.Angles(0, 0, math.rad(90)) }, m)
		part({ Name = "Cloth", Size = Vector3.new(3, 4.2, 0.2), Color = T.Cloth, Material = Enum.Material.Fabric,
			CanCollide = false, CanQuery = false, CanTouch = false, CFrame = base * CFrame.new(1.7, 5.6, 0) }, m)
		for k, off in { Vector3.new(1.2, 6.5, -0.12), Vector3.new(2.2, 4.6, -0.12) } do
			part({ Name = "Patch" .. k, Size = Vector3.new(0.9, 0.8, 0.05), Color = T.Patch, Material = Enum.Material.Fabric,
				CanCollide = false, CanQuery = false, CanTouch = false, CFrame = base * CFrame.new(off) }, m)
		end
		m.PrimaryPart = pole
		m.Parent = root
	end
	made[e.Name] = (made[e.Name] or 0) + 1
end
root.Parent = decor

local names, out = {}, {}
for k in made do table.insert(names, k) end
table.sort(names)
for _, k in names do table.insert(out, k .. " x" .. made[k]) end
local miss = {}
for k in missing do table.insert(miss, k) end
local parts, lights = 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Light") then lights += 1 end
end
return string.format("WoodsKit: %s | skipped (no dry ground) %d | missing kit: %s | primitives to backup: %d (backup now %d)" ..
	" | bush parts lifted %d | map parts %d (budget %d), lights %d", table.concat(out, ", "), skipped,
	#miss > 0 and table.concat(miss, ",") or "none", moved, #backup:GetChildren(), lifted, parts, Config.Map.MaxParts, lights)
