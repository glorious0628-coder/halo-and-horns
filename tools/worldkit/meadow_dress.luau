-- meadow_dress.luau (2026-10-08; user 10/08 "세계관 디자인 자체가 이상해, 너무 휑하지 않아?", SPEC A23-76)
-- PIPELINE ORDER (검수 2026-10-09, 메인 반영): after ANY run of this tool (MODE "kit") run, in this order:
--   1. tools/worldkit/meadow_bush_scale.luau   (bushes x1.6, kept off lawns / roads / other pieces)
--   2. tools/worldkit/decor_collision.luau     (solid / player-only collision)
--   3. tools/worldkit/decor_ground.luau        (re-ground on the terrain: py runner string "apply|Map.Decor.MeadowDress,Map.Decor.MeadowKit|all")
-- a new dress run rebuilds MeadowDress from scratch, so steps 1-3 are lost until they are run again.
-- Studio MCP execute_luau, MAIN place, Edit mode (검수 runs it, like tools/worldkit/woods_kit_place.luau).
-- Dresses the Slime Meadow (Config LandMeadow x 210..650, z -240..240; +X east, -Z north) toward the concept
-- art/review/concept/Concept_SlimeMeadow.jpg with the uploaded kit in ServerStorage.WorldKit3D (tools/build_kit_from_ids.py;
-- one Model per name, pivot = bottom centre, front = -Z): two mushroom fairy rings with stumps, a rock / bush rim round
-- the pond, a picnic, a flower-cart garden, a shard-crystal corner, a crown of rocks on the King Slime Hill, roadside
-- rest stops, fork sign posts, hedge islands between the hunting lawns, fences along the roads with flower gateposts and
-- bush clumps, tree groves framing every edge, flower front rows and small tufts in the lawns. The concept's blue
-- drop statue is IP-forbidden and is not built. No faces on props, no ray / fan layouts (rings and blobs only).
-- Output: Map.Decor.MeadowDress, destroyed and rebuilt on every run ("Big" = solid / large pieces; "Small" = the small
-- walk-through kinds in 64-stud Cell_x_z Models, ready for a client distance cull). Never touched: Map.Decor.MeadowKit
-- (its 60 pieces stay; new pieces keep their spacing from them), terrain, monsters, pads, zone floors, roads, landmarks,
-- the gate's name / position. Two reversible stashes into ServerStorage.MeadowDressBackup (MODE "old" puts them back):
-- Decor.PondStones (the pond rim vignette replaces those 9 jelly rocks; T.ReplacePondStones) and the two black "Eye"
-- balls on Gate_SlimeMeadow's slime statue (no faces on props; T.HideGateEyes).
-- Run it AFTER tools/worldkit/meadow_terrain.luau (A23-76 hills / plateau / waterfall / river): every piece is grounded
-- by a ray on the terrain as it is. Works on both states: the flat v2 meadow with the KingSlimeHill ball part, or the
-- sculpted one (ball hidden; the crown then sits on ServerStorage.MeadowTerrainStore's HillTop, its gap toward the dirt
-- ramp's top, NE; the crystal corner moves off the unreachable NE plateau to its NW foot). MeadowDress keeps the store's
-- PlanHash ("none" = flat meadow) it was grounded on; the summary warns when the dress in place was grounded on another
-- terrain plan (re-run MODE "kit" after every meadow_terrain apply / restore).
-- Placement rules (layout 2026-10-08): every piece is grounded by a ray on Terrain (+ Map.Ground; + the
-- KingSlimeHill part for the hill crown) and must land on dry Grass / LeafyGrass (rocks and crystals also on Rock; the
-- pond rim also on its sand), above Y -0.5 (beach), not on a slope steeper than about 37 degrees (hill pieces lean onto
-- the slope up to about 60); low / small kinds no higher than Y 8 (hill crown pieces excepted); on a slope every piece
-- sinks by its downhill rim's drop (up to 0.4 x its height) so no rim floats;
-- keep-clear areas (bridge quays, gate, spawn, arrival pocket, job board, roads, pumpkin path / sign / patch fence,
-- pond, hill, woods spot) and the nine hunting lawns (walk-through tufts only) stay clear; the arrival pocket and the
-- first-quest boxes get only flowers and pinwheels (no bush, rock or stump a slime could spawn hidden in), besides the
-- welcome vignette's hand-placed pieces;
-- spacing 0.8 x (r1 + r2) (bushes 0.55, low pieces 0.5), trunks 12+ apart, 6+ studs between solids (10+ in the pond
-- hunting ring). Fence runs go in whole (all segments + the run's bush) or not at all; gateposts only on built runs.
-- Collision: trees = non-colliding mesh + invisible TrunkPost collider (attribute Collider = true: ground rays such as
-- PetFollow's should skip it); boulders 4+ tall, benches, carts, sign posts =
-- solid; fences and BushA at scale 1.6+ = player-only when the "DecorPlayerOnly" collision group is registered (else
-- walk-through); everything else walk-through (CanCollide / CanQuery / CanTouch false). CastShadow only on pieces with a
-- longest side of 4+ (ART_DIRECTION 9). Scripts are stripped from every clone.
-- Budget: the layout's per-kind caps and a 560-piece (pass 1: 490) meadow total with MeadowKit's 60 pieces (and the
-- JobBoard) counted (T.CapScale scales them), a meadow triangle cap (T.TriCap, per-kind TRIS, MeadowKit + JobBoard
-- included; phone performance) and the whole-map part cap T.PartCap (2600, 검수 2026-10-08: Config.Map.MaxParts only
-- warns in MapBuilder; the world is being densified per SPEC A23-76). Pieces go in by priority (tiers: 1 vignettes + pond
-- lily pads, 2 road fences, 3 corner tree groups + edge tree groves, 4 road edges = gatepost flowers / bush clumps /
-- shade trees / the loop road, 5 bushes and flowers under the edge trees, 6 hedge bands, 7 road fill + edge front-row
-- flowers, 8 gap fill, 9 lawn tufts); tiers 1-2 may not use the last T.EdgeReserve of the
-- piece total, the part budget and the triangle cap (kept for the coast frame, tiers 3-5); the filler passes 5..8 may
-- each use only a share of what a cap has left. When a cap or a budget runs out, the lower tiers are the ones left out
-- (reported as cap / quota / reserve / budget / tris).
-- Pass 2 (2026-10-08, after the pass 1 photos art/review/world/meadow_pass1_2026-10-08.jpg: "flat, bushes small, pond
-- bare"): bushes at scale 1.8..2.6 in clumps of 3-5 touching bushes (pond rim, hedge islands, behind every fence run,
-- between the runs with 12+ stud walk-in gaps, along the loop road and the pumpkin path; none at the joins), a stone ring
-- at the pond's water edge + 8 lily pads (plain SmoothPlastic discs, a few with a white / pink flower, nothing
-- collides), tree groups in the four corners and denser coast groves, big shade trees by the road, flowers in front of
-- the clumps and round trees. The triangle cap is the real limit: the new clumps come in the higher tiers, the random
-- filler of tiers 6-9 gets what is left.
-- Deterministic: Random.new(20261008), fixed pass order. Missing kit names are skipped and listed, never an error.
-- MODE "dry" = read only, one-line count; "plan" = read only, rows "name,x,z,r,yaw,tier,coll" for a top-down check
-- picture; "kit" = (re)build MeadowDress + stashes; "old" = remove MeadowDress and put the stashed pieces back.
local MODE = "kit"
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
assert(MODE == "dry" or MODE == "plan" or MODE == "kit" or MODE == "old", "MODE must be dry, plan, kit or old")
local SS = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local okConfig, Config = pcall(function()
	return require(game:GetService("ReplicatedStorage").Shared.Config)
end)
if not okConfig or type(Config) ~= "table" then Config = {} end
local map = workspace:FindFirstChild("Map")
assert(map and map:FindFirstChild("Decor"), "workspace.Map.Decor missing")
local decor = map.Decor
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit, "ServerStorage.WorldKit3D missing: run tools/build_kit_from_ids.py first")
-- 검수 2026-10-08: repeated props use their LOD twin when the kit has one (phone budget; 이미지 생성 1 40d9c53, WorldKit
-- import 3_third D10). The clone keeps the plain name so other tools (decor_collision) read the kind as before.
local LOD_TRIS = { Kit_M_FlowersA = 596, Kit_M_FlowersB = 598 }
local function kitModel(name)
	return (LOD_TRIS[name] and kit:FindFirstChild(name .. "_LOD")) or kit:FindFirstChild(name)
end
local gate = map:FindFirstChild("Gates") and map.Gates:FindFirstChild("Gate_SlimeMeadow")

local T = {
	Seed = 20261008,
	PartCap = 2600, -- whole-map part cap (검수 2026-10-08; Config.Map.MaxParts 1600 only warns). nil = Config.Map.MaxParts
	TriCap = 1300000, -- meadow triangle cap (dress + MeadowKit + JobBoard, TRIS below); not scaled by CapScale
	TrisUnknown = 3000, -- triangles of a kind TRIS does not list
	EdgeReserve = 0.22, -- share of the piece total / part budget / triangle cap tiers 1-2 leave for tiers 3-5
	MaxYLow = 20, -- (4th meadow terrain tiers: was 8) low / small kinds stand no higher (no flowers on the plateau or the knoll tops), hill crown excepted
	SlopeSinkMax = 0.4, -- the slope sink stops at this share of the piece's height
	ReplacePondStones = true,
	HideGateEyes = true,
	PlayerOnlyGroup = "DecorPlayerOnly", -- used only when already registered (PlayerService); else fences never collide
	Land = { MinX = 210, MaxX = 650, MinZ = -240, MaxZ = 240 },
	Corner = 60, -- tools/preview_map.lua rounded land corners
	Coast = 13, -- the beach: filler keeps its centre this far inside the coast
	EdgeBack = 32, EdgeFront = 42, -- edge belt: back row 13..32 (tree groves), front row 32..42 (flowers)
	Grid = 15, Jitter = 4.5,
	Spacing = 0.8, BushSpacing = 0.55, LowSpacing = 0.5,
	SolidGap = 6, SparseGap = 10, TreeMin = 12,
	GroveGap = 36, GroveSizes = { 2, 2, 3, 3, 3 }, GroveEmpty = 0.1, -- pass 2: 50 / { 1, 2, 2, 3, 3 } / 0.2 -> denser frame
	ClumpTouch = 0.72, -- clump members stand this x (r1 + r2) from the lead bush (touching; BushSpacing allows 0.55)
	ClumpLen = 20, ClumpGap = 11, -- a road clump is about 20 long; walk-in gaps of 11+ (+ the fence end margin) stay open
	LilyPads = 8, LilyTris = 100, LilyFlowerEvery = 3, LilyY = -1.2, -- pond lily pads (Part cylinders, ~100 tris each)
	PostH = 12, PostMin = 8, -- trunk post height = max(PostH x scale, PostMin)
	Cell = 64,
	Total = 560, Posts = 115, TallBoulders = 20, JobBoard = 1, -- pass 2: 490 / 78 (the triangle cap binds first)
	CapScale = 1, -- every kind cap and the totals x this; layout Phase 2 (6 most-repeated meshes decimated): 1.25
	-- 검수 10/08 pass 3: meadow_terrain paints flower patches (Salt) and shade (Sandstone) on grass; props stand there too
	-- (Pavement = roads / hill path stays prop-free)
	Ground = { Grass = true, LeafyGrass = true, Salt = true, Sandstone = true },
	Rocky = { Rock = true, Slate = true, Basalt = true, Limestone = true }, -- never Ground: the hill ramp / path fallback
	-- MaxY: decor may stand on the sculpted edge knolls and the NE plateau (top 26); monsters never use ground above 6
	MinY = -0.5, MinYSand = -1.6, MaxY = 30, MaxYHill = 40,
	Steep = 0.8, SteepHill = 0.5, -- smallest ground-normal Y (about 37 / 60 degrees)
	RampTopDeg = -60, -- meadow_terrain.luau HILL.Ramp: A0 100 deg - Span 160 deg = where the dirt ramp reaches the top
	MaxFailed = 14,
}

-- kit kinds: Cap (per name) or Group (shared cap); Tree = trunk post at scale 1 (pivot space, measured 2026-10-08);
-- Open = may stand in the OpenOnly areas (arrival pocket, first-quest boxes)
local KIND = { -- pass 2 caps: trees A 18 / B 54 / C 6, bushes A 105 / B 60, jelly rocks 6 (the triangle cap binds first)
	W_Tree_A = { Cap = 28, Tree = { X = 0, Z = 0, D = 5.6 } },
	W_Tree_B = { Cap = 76, Tree = { X = 1.4, Z = 1.6, D = 7 } },
	W_Tree_C = { Cap = 12, Tree = { X = -0.4, Z = -0.8, D = 7 } },
	W_Boulder_A = { Group = "Boulder", Boulder = true, Rocky = true },
	W_Boulder_B = { Group = "Boulder", Boulder = true, Rocky = true },
	Kit_M_BushA = { Cap = 150, Bush = true },
	Kit_M_BushB = { Cap = 90, Bush = true, Small = true },
	Kit_M_FlowersA = { Group = "Flowers", Low = true, Small = true, Open = true },
	Kit_M_FlowersB = { Group = "Flowers", Low = true, Small = true, Open = true },
	Kit_M_Mushrooms = { Cap = 24, Low = true, Small = true },
	Kit_M_Stump = { Cap = 20, Low = true, Small = true },
	Kit_M_Fence = { Cap = 36, Fence = true },
	Kit_M_CrystalPile = { Cap = 10, Low = true, Small = true, Rocky = true },
	Kit_M_JellyRock = { Cap = 10, Small = true, Rocky = true },
	Kit_M_Pinwheel = { Cap = 10, Small = true, Open = true },
	Kit_M_LogBench = { Cap = 5, Solid = true },
	Kit_M_PicnicBasket = { Cap = 2, Low = true, Small = true },
	Kit_M_FlowerCart = { Cap = 2, Solid = true },
	Kit_M_SignPost = { Cap = 5, Solid = true },
	Kit_M_PuddleRim = { Cap = 4, Low = true, Small = true },
	Kit_W_StepStones = { Cap = 8, Low = true, Small = true }, -- pass 4 (검수 10/09): path stones in front of the scene spots
}
local GROUPCAP = { Boulder = 54, Flowers = 130 } -- pass 2: 36 / 85 (pond stone ring, flowers along the paths)
-- triangles per piece (검수 2026-10-08); W_Tree_* / W_Boulder_* 1450, other kinds T.TrisUnknown. Lower these after the
-- layout Phase 2 decimation, never raise T.TriCap for it
local TRIS = { Kit_M_BushA = 2800, Kit_M_BushB = 2800, Kit_M_FlowersA = 2800, Kit_M_FlowersB = 2800, Kit_M_Mushrooms = 2900,
	Kit_M_Stump = 2800, Kit_M_Fence = 2800 }
for n, t in LOD_TRIS do
	if kit:FindFirstChild(n .. "_LOD") then TRIS[n] = t end
end
local function trisOf(name)
	local n = TRIS[name]
	if n then return n end
	if string.sub(name, 1, 7) == "W_Tree_" or string.sub(name, 1, 10) == "W_Boulder_" then return 1450 end
	return T.TrisUnknown
end

------------------------------------------------------------------ MODE "old": remove the dress, put the stashes back
local function backupFolder(create)
	local b = SS:FindFirstChild("MeadowDressBackup")
	if not b and create then
		b = Instance.new("Folder")
		b.Name = "MeadowDressBackup"
		b.Parent = SS
	end
	return b
end
if MODE == "old" then
	local old = decor:FindFirstChild("MeadowDress")
	if old then old:Destroy() end
	local back, b = {}, backupFolder(false)
	if b then
		local stones = b:FindFirstChild("PondStones")
		if stones then
			if decor:FindFirstChild("PondStones") then
				table.insert(back, "PondStones left in backup (Decor already has one)")
			else
				stones.Parent = decor
				table.insert(back, "PondStones")
			end
		end
		for _, e in b:GetChildren() do
			if e.Name == "Eye" and e:IsA("BasePart") and gate then
				e.Parent = gate
				table.insert(back, "gate Eye")
			end
		end
	end
	return "MeadowDress removed | restored: " .. (#back > 0 and table.concat(back, ", ") or "nothing")
end

------------------------------------------------------------------ geometry
local LAND = T.Land
for _, l in (type(Config.Map) == "table" and Config.Map.Lands) or {} do
	if l.Name == "LandMeadow" then LAND = l end
end
local GEO = { CX = (LAND.MinX + LAND.MaxX) / 2, CZ = (LAND.MinZ + LAND.MaxZ) / 2 }
GEO.HX = (LAND.MaxX - LAND.MinX) / 2 - T.Corner
GEO.HZ = (LAND.MaxZ - LAND.MinZ) / 2 - T.Corner

-- distance inside the rounded-rect coast (negative = in the sea)
local function coastDist(x, z)
	local qx, qz = math.abs(x - GEO.CX) - GEO.HX, math.abs(z - GEO.CZ) - GEO.HZ
	local ox, oz = math.max(qx, 0), math.max(qz, 0)
	return T.Corner - math.sqrt(ox * ox + oz * oz) - math.min(math.max(qx, qz), 0)
end
-- unit direction away from the nearest coast
local function inland(x, z)
	local gx = coastDist(x + 1, z) - coastDist(x - 1, z)
	local gz = coastDist(x, z + 1) - coastDist(x, z - 1)
	local m = math.sqrt(gx * gx + gz * gz)
	if m < 1e-6 then
		gx, gz = GEO.CX - x, GEO.CZ - z
		m = math.max(math.sqrt(gx * gx + gz * gz), 1e-6)
	end
	return gx / m, gz / m
end
local function inBox(b, x, z, r) -- b = { minX, minZ, maxX, maxZ }
	return x + r > b[1] and x - r < b[3] and z + r > b[2] and z - r < b[4]
end
local function boxDist(b, x, z)
	local dx = math.max(b[1] - x, 0, x - b[3])
	local dz = math.max(b[2] - z, 0, z - b[4])
	return math.sqrt(dx * dx + dz * dz)
end
local function yawToward(x, z, tx, tz) -- yaw (deg) that turns a model's front (-Z) toward (tx, tz)
	local dx, dz = tx - x, tz - z
	if dx * dx + dz * dz < 1e-6 then return 0 end
	return math.deg(math.atan2(-dx, -dz))
end

-- road strips: { minX, minZ, maxX, maxZ } (Config.Map.Roads; the pumpkin path only on the meadow side)
local ROADS = {
	RoadMeadow = { 210, -9, 650, 9 },
	RoadMeadowLoop = { 260, -125, 600, -115 },
	RoadPumpkin = { 529, 9, 541, 246 },
}
for _, r in (type(Config.Map) == "table" and Config.Map.Roads) or {} do
	if r.Name == "RoadMeadow" or r.Name == "RoadMeadowLoop" then ROADS[r.Name] = { r.MinX, r.MinZ, r.MaxX, r.MaxZ } end
	if r.Name == "RoadPumpkin" then ROADS.RoadPumpkin = { r.MinX, r.MinZ, r.MaxX, math.min(r.MaxZ, 246) } end
end
local ROADLIST = { ROADS.RoadMeadow, ROADS.RoadMeadowLoop, ROADS.RoadPumpkin }

local SPOT = (type(Config.StoryQuests) == "table" and Config.StoryQuests.Landmarks) or {}
local function v2(v, x, z)
	if typeof(v) == "Vector3" then return Vector2.new(v.X, v.Z) end
	return Vector2.new(x, z)
end
local HW = (type(Config.Map) == "table" and Config.Map.Halloween) or {}
local PT = {
	Arrival = v2(SPOT.MeadowArrival, 230, 0),
	Pond = v2(SPOT.SlimePond, 290, 150),
	Board = v2(SPOT.MeadowBoard, 230, 12),
	Woods = v2(SPOT.WoodsGate, 636, 0),
	Hill = Vector2.new(430, -170),
	Sign = v2(HW.SignPos, 525, 226),
	PatchGate = Vector2.new(535, 240),
}
local hill = decor:FindFirstChild("KingSlimeHill")
if hill and not hill:IsA("BasePart") then hill = nil end
local HILL_R = 17 -- dome radius at the ground (ball 50 wide, centre Y -19 -> 16.2)
local terrainStore = SS:FindFirstChild("MeadowTerrainStore")
local hillTop = terrainStore and terrainStore:GetAttribute("HillTop")
local terrainHill = hill == nil and typeof(hillTop) == "Vector3" -- meadow_terrain.luau hid the ball, sculpted a hill
-- the terrain plan the pieces are grounded on: meadow_terrain sets PlanHash on apply and clears it on restore
local terrainPlan = terrainStore and terrainStore:GetAttribute("PlanHash")
if type(terrainPlan) ~= "string" or terrainPlan == "" then terrainPlan = nil end
local plateauTop = terrainPlan and terrainStore:GetAttribute("PlateauTop")
if typeof(plateauTop) ~= "Vector3" then plateauTop = nil end
if hill then
	PT.Hill = Vector2.new(hill.Position.X, hill.Position.Z)
	local R, cy = hill.Size.X / 2, hill.Position.Y
	HILL_R = (cy < 0 and R > -cy) and math.sqrt(R * R - cy * cy) or R
elseif terrainHill then
	PT.Hill = Vector2.new(hillTop.X, hillTop.Z)
	HILL_R = 36 -- meadow_terrain.luau HILL.SkirtR: the rock core, the dirt ramp and the grass skirt stay the hill's
end

-- keep-clear areas. "all" = no piece; "block" = no player-blocking piece (a player-only piece turns walk-through);
-- "solid" = no monster-blocking piece; "sparse" = solids need SparseGap between them; OpenOnly = only Open kinds
-- (flowers, pinwheels) with their whole footprint, besides the tier 1 vignette's hand-placed pieces: the first slimes
-- spawn there and must never be hidden in a walk-through bush or behind a rock.
-- Filler checks its whole footprint, the hand-placed vignette pieces only their centre (FillerOnly areas are skipped
-- for them).
local CLEAR = {
	{ Id = "bridgeQuay", Box = { 146, -13, 224, 13 }, Rule = "all" },
	{ Id = "gate", Box = { 204, -14, 216, 14 }, Rule = "all" },
	{ Id = "spawn", C = PT.Arrival, R = 16, Rule = "all" },
	{ Id = "arrivalPocket", Box = { 235, -40, 272, 40 }, Rule = "block", OpenOnly = true },
	{ Id = "firstQuestN", Box = { 240, -30, 300, -14 }, Rule = "solid", OpenOnly = true },
	{ Id = "firstQuestS", Box = { 240, 14, 300, 30 }, Rule = "solid", OpenOnly = true },
	{ Id = "jobBoard", Box = { PT.Board.X - 10, PT.Board.Y - 5, PT.Board.X + 10, PT.Board.Y + 10 }, Rule = "all" },
	{ Id = "pumpkinPath", Box = { 523, 9, 547, 250 }, Rule = "all", FillerOnly = true },
	{ Id = "pumpkinSign", C = PT.Sign, R = 10, Rule = "all" },
	{ Id = "patchGate", C = PT.PatchGate, R = 12, Rule = "all" },
	{ Id = "patchFence", Box = { 420, 236, 650, 250 }, Rule = "all" },
	{ Id = "pondWater", C = PT.Pond, R = 21, Rule = "all" },
	{ Id = "pondRim", C = PT.Pond, R = 25, Rule = "all", FillerOnly = true },
	{ Id = "pondRing", C = PT.Pond, R = 40, Rule = "sparse" },
	{ Id = "hill", C = PT.Hill, R = HILL_R + 1, Rule = "all", NotHill = true },
	{ Id = "woodsSpot", C = PT.Woods, R = 16, Rule = "all" },
	{ Id = "woodsQuay", Box = { 636, -13, 712, 13 }, Rule = "all" },
}
-- hunting lawns { minX, minZ, maxX, maxZ }: open fighting ground, walk-through tufts only
local LAWNS = {
	{ 250, -104, 328, -30 }, { 252, 30, 318, 110 }, { 348, -104, 500, -30 }, { 524, -104, 608, -30 },
	{ 352, 54, 512, 110 }, { 362, 126, 512, 200 }, { 555, 44, 608, 196 }, { 252, -200, 388, -140 },
	{ 476, -200, 580, -140 },
}
local function lawnAt(x, z)
	for _, L in LAWNS do
		if inBox(L, x, z, 0) then return L end
	end
	return nil
end
local function lawnDist(x, z)
	local best = math.huge
	for _, L in LAWNS do best = math.min(best, boxDist(L, x, z)) end
	return best
end
local function bandAt(x, z)
	local cd = coastDist(x, z)
	if cd < T.Coast then return "coast" end
	if lawnAt(x, z) then return "lawn" end
	if cd <= T.EdgeBack then return "edgeBack" end
	if cd <= T.EdgeFront then return "edgeFront" end
	local cr, lp = ROADS.RoadMeadow, ROADS.RoadMeadowLoop
	if z >= cr[2] - 25 and z <= cr[4] + 25 then return "road" end
	if x >= lp[1] - 10 and x <= lp[3] + 10 and z >= lp[2] - 15 and z <= lp[4] + 15 then return "road" end
	return "hedge"
end

------------------------------------------------------------------ ground
local function rayParams(list)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	local clean = {}
	for _, v in list do
		if v then table.insert(clean, v) end
	end
	p.FilterDescendantsInstances = clean
	p.IgnoreWater = false
	return p
end
local groundFolder = map:FindFirstChild("Ground")
local RAY = {
	Land = rayParams({ workspace.Terrain, groundFolder }),
	Hill = rayParams({ workspace.Terrain, groundFolder, hill }),
}
-- dry ground under (x, z): y, normal or nil, nil, reason. o.Hill = the hill (part, rock, up to MaxYHill) counts;
-- o.Sand = the pond's sand rim counts; o.Rocky = rock counts (boulders, crystals, jelly rocks)
local function ground(x, z, o)
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), (o and o.Hill) and RAY.Hill or RAY.Land)
	if not hit then return nil, nil, "none" end
	if hit.Material == Enum.Material.Water then return nil, nil, "water" end
	local y = hit.Position.Y
	local hilly = o ~= nil and o.Hill == true
	if y > (hilly and T.MaxYHill or T.MaxY) then return nil, nil, "high" end
	local sand = o ~= nil and o.Sand == true
	if y < (sand and T.MinYSand or T.MinY) then return nil, nil, "low" end
	local mat = hit.Material.Name
	local rocky = hilly or (o ~= nil and o.Rocky == true)
	if not (T.Ground[mat] or (sand and mat == "Sand") or (rocky and T.Rocky[mat])) then return nil, nil, mat end
	if hit.Normal.Y < ((hilly or (o ~= nil and o.Tilt ~= nil)) and T.SteepHill or T.Steep) then return nil, nil, "steep" end
	return y, hit.Normal, nil
end

------------------------------------------------------------------ kit sizes
local SIZE, PARTS, missing = {}, {}, {}
local function info(name)
	local s = SIZE[name]
	if s ~= nil then return s end
	local src = kitModel(name)
	if not (src and src:IsA("Model")) then
		missing[name] = true
		SIZE[name] = false
		return false
	end
	local _, size = src:GetBoundingBox()
	local n = 0
	for _, d in src:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	SIZE[name] = size
	PARTS[name] = math.max(n, 1)
	return size
end

------------------------------------------------------------------ spatial hash of placed + existing pieces
local placed, others = {}, {}
local HASH = {}
local function hkey(ix, iz) return ix * 100000 + iz end
local function hashAdd(e)
	local k = hkey(math.floor(e.X / 32), math.floor(e.Z / 32))
	local b = HASH[k]
	if not b then
		b = {}
		HASH[k] = b
	end
	table.insert(b, e)
end
local function near(x, z, fn) -- first truthy fn(e) among items within ~32 studs
	local ix, iz = math.floor(x / 32), math.floor(z / 32)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local b = HASH[hkey(ix + dx, iz + dz)]
			if b then
				for _, e in b do
					local r = fn(e)
					if r then return r end
				end
			end
		end
	end
	return nil
end
local function segDist(s, x, z)
	local vx, vz = s[3] - s[1], s[4] - s[2]
	local l2 = vx * vx + vz * vz
	local t = l2 > 0 and math.clamp(((x - s[1]) * vx + (z - s[2]) * vz) / l2, 0, 1) or 0
	local px, pz = s[1] + vx * t - x, s[2] + vz * t - z
	return math.sqrt(px * px + pz * pz)
end
local function between(a, b)
	if a.Seg then return segDist(a.Seg, b.X, b.Z) end
	if b.Seg then return segDist(b.Seg, a.X, a.Z) end
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
local function hasNear(x, z, r)
	local probe = { X = x, Z = z }
	return near(x, z, function(e)
		if between(probe, e) < r then return true end
		return nil
	end) ~= nil
end

------------------------------------------------------------------ what is already there (read only)
local existing = {} -- kit name -> pieces already in the meadow (MeadowKit; PondStones when kept)
local SKIP = { MeadowKit = true, MeadowDress = true, PondStones = true, Roads = true, KingSlimeHill = true,
	PumpkinPatch = true, HauntedHollow = true, SeaRocks = true, SlimePond = true }
local function addOther(inst, count)
	local ok, cf, size = pcall(function()
		if inst:IsA("Model") then return inst:GetBoundingBox() end
		return inst.CFrame, inst.Size
	end)
	if not ok or not cf then return "out" end
	local x, z = cf.Position.X, cf.Position.Z
	if x < LAND.MinX - 15 or x > LAND.MaxX + 15 or z < LAND.MinZ - 15 or z > LAND.MaxZ + 15 then return "out" end
	local half = math.sqrt(size.X * size.Z) / 2
	if half > 24 then return "big" end
	local name = inst.Name
	local tree = (KIND[name] and KIND[name].Tree ~= nil) or string.find(name, "Tree") ~= nil
	local solid = false
	for _, p in (inst:IsA("BasePart") and { inst } or inst:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			solid = true
			break
		end
	end
	local e = { Name = name, X = x, Z = z, Other = true, Tree = tree, R = tree and 4 or math.max(half, 0.5),
		Low = size.Y < 3, Bush = string.find(name, "Bush") ~= nil }
	e.RS = solid and (tree and math.max(size.X, size.Z) * 0.22 or e.R) or 0
	table.insert(others, e)
	hashAdd(e)
	if count then existing[name] = (existing[name] or 0) + 1 end
	return "added"
end
local function scan(inst, depth)
	if inst:IsA("Folder") then
		if depth < 2 then
			for _, c in inst:GetChildren() do scan(c, depth + 1) end
		end
	elseif inst:IsA("Model") or inst:IsA("BasePart") then
		if addOther(inst, false) == "big" and inst:IsA("Model") and depth < 2 then
			for _, c in inst:GetChildren() do scan(c, depth + 1) end
		end
	end
end
local meadowKit = decor:FindFirstChild("MeadowKit")
if meadowKit then
	for _, m in meadowKit:GetChildren() do addOther(m, true) end
end
local pondStones = decor:FindFirstChild("PondStones")
if pondStones and not T.ReplacePondStones then
	for _, m in pondStones:GetChildren() do addOther(m, true) end
end
for _, d in decor:GetChildren() do
	if not SKIP[d.Name] and string.sub(d.Name, 1, 7) ~= "Bridge_" then scan(d, 0) end
end
for _, fname in { "Landmarks", "Gates", "Pads" } do
	local f = map:FindFirstChild(fname)
	if f then
		for _, d in f:GetChildren() do scan(d, 1) end
	end
end

------------------------------------------------------------------ caps and the part budget
local capLeft, CAPS = {}, {}
for name, k in KIND do
	if k.Cap then capLeft[name] = math.floor(k.Cap * T.CapScale + 0.5) - (existing[name] or 0) end
end
for g, n in GROUPCAP do capLeft[g] = math.floor(n * T.CapScale + 0.5) end
local existingTotal = 0
for name, n in existing do
	existingTotal += n
	local k = KIND[name]
	if k and k.Group then capLeft[k.Group] -= n end
end
CAPS.Total = math.floor(T.Total * T.CapScale + 0.5) - existingTotal - T.JobBoard
CAPS.Posts = math.floor(T.Posts * T.CapScale + 0.5)
local function countParts(inst)
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end
local eyes = {}
if gate and T.HideGateEyes then
	for _, e in gate:GetChildren() do
		if e.Name == "Eye" and e:IsA("BasePart") then table.insert(eyes, e) end
	end
end
local oldDress = decor:FindFirstChild("MeadowDress")
local oldPlan = oldDress and oldDress:GetAttribute("PlanHash") -- nil = built before the dress kept its terrain plan
local baseParts = countParts(map) - (oldDress and countParts(oldDress) or 0) - #eyes
	- ((pondStones and T.ReplacePondStones) and countParts(pondStones) or 0)
local partCap = T.PartCap or (type(Config.Map) == "table" and Config.Map.MaxParts) or 1600
local room = math.max(0, partCap - baseParts)
local function trisIn(folder)
	local n = 0
	if folder then
		for _, m in folder:GetChildren() do n += trisOf(m.Name) end
	end
	return n
end
local existingTris = trisIn(meadowKit) + ((pondStones and not T.ReplacePondStones) and trisIn(pondStones) or 0)
	+ T.JobBoard * trisOf("Kit_M_JobBoard")
CAPS.Tris = T.TriCap - existingTris
-- what tiers 1-2 must leave for the coast frame (tiers 3-5); released from tier 3 on
local HOLD = { Total = math.floor(math.max(CAPS.Total, 0) * T.EdgeReserve), Parts = math.floor(room * T.EdgeReserve),
	Tris = math.floor(math.max(CAPS.Tris, 0) * T.EdgeReserve) }
local used = { Total = 0, Parts = 0, Posts = 0, Tall = 0, Tris = 0 }
local stats = { Why = {}, Made = {}, Tier = {}, Failed = {} }
local rng = Random.new(T.Seed)

------------------------------------------------------------------ candidate checks
local function capKey(name)
	local k = KIND[name]
	return (k and k.Group) or name
end
local function costOf(c) return (PARTS[c.Name] or 1) + (c.Tree and 1 or 0) end

-- a candidate piece (not yet checked)
local function make(name, x, z, o, s, yaw)
	local k = KIND[name] or {}
	local size = SIZE[name]
	local sx, sy, sz = size.X * s, size.Y * s, size.Z * s
	local c = { Name = name, X = x, Z = z, S = s, Yaw = yaw, H = sy, Longest = math.max(sx, sy, sz),
		Tier = o.Tier or 9, Tag = o.Tag, Fixed = o.Fixed, Hill = o.Hill, Sand = o.Sand, Tilt = o.Tilt, Tuft = o.Tuft,
		NoGap = o.Hill, Small = k.Small, Low = k.Low, Bush = k.Bush, Fence = k.Fence, Rocky = k.Rocky, Open = k.Open, RS = 0 }
	c.Vignette = o.Fixed == true and c.Tier == 1 -- hand-placed in a tier 1 vignette
	c.Sink = o.Sink or (o.SinkFrac and o.SinkFrac * sy) or ((math.max(sx, sz) >= 6) and 0.3 or 0)
	if k.Tree then
		c.Tree, c.Coll = true, "tree"
		c.RS = k.Tree.D * s / 2
		c.R = c.RS + 1.5
		c.Canopy = math.sqrt(sx * sz) / 2
		return c
	end
	if k.Fence then -- a segment along the model's X (fences follow the road)
		local a = math.rad(yaw)
		local hl = math.max(sx / 2 - 0.3, 0.5)
		local ux, uz = math.cos(a), -math.sin(a)
		c.Seg = { x - ux * hl, z - uz * hl, x + ux * hl, z + uz * hl }
		c.R = sz / 2 + 0.1
	else
		c.R = math.sqrt(sx * sz) / 2
	end
	if o.Coll then
		c.Coll = o.Coll
	elseif k.Boulder then
		c.Coll = (sy - c.Sink >= 4) and "solid" or "none"
	elseif k.Solid then
		c.Coll = "solid"
	elseif k.Fence or (name == "Kit_M_BushA" and s >= 1.6) then
		c.Coll = "player"
	else
		c.Coll = "none"
	end
	if c.Coll == "solid" then c.RS = c.R end
	return c
end

local function inZone(zn, x, z, r)
	if zn.Box then return inBox(zn.Box, x, z, r) end
	local dx, dz = x - zn.C.X, z - zn.C.Y
	return math.sqrt(dx * dx + dz * dz) < zn.R + r
end
local function openOnlyAt(x, z, r) -- a piece of radius r here would reach into an OpenOnly area
	for _, zn in CLEAR do
		if zn.OpenOnly and inZone(zn, x, z, r) then return zn.Id end
	end
	return nil
end
local function zoneCheck(c)
	if not (c.Open or c.Vignette) then -- the whole footprint, also for Fixed pieces (the fence runs' bushes)
		local id = openOnlyAt(c.X, c.Z, c.R)
		if id then return "zone:" .. id end
	end
	local r = c.Fixed and 0 or c.R
	for _, zn in CLEAR do
		if not ((c.Fixed and zn.FillerOnly) or (c.Hill and zn.NotHill)) then
			if inZone(zn, c.X, c.Z, r) then
				local solid = c.Coll == "solid" or c.Coll == "tree"
				if zn.Rule == "all" then return "zone:" .. zn.Id end
				if zn.Rule == "solid" and solid then return "zone:" .. zn.Id end
				if zn.Rule == "block" then
					if solid then return "zone:" .. zn.Id end
					if c.Coll == "player" then c.Coll = "none" end
				end
				if zn.Rule == "sparse" and solid then c.Sparse = true end
			end
		end
	end
	return nil
end
local function roadCheck(c)
	for _, b in ROADLIST do
		local d = boxDist(b, c.X, c.Z)
		if c.Seg then d = math.min(d, boxDist(b, c.Seg[1], c.Seg[2]), boxDist(b, c.Seg[3], c.Seg[4])) end
		if d < 2 then return "road" end
		local need
		if c.Coll == "none" then
			need = c.Fixed and 0.5 or 2
		else
			need = (c.Coll == "player") and 2.5 or 4
		end
		if d - c.R < need then return "road" end
	end
	return nil
end
local function lawnCheck(c)
	local r = c.Fixed and 0 or c.R
	for _, L in LAWNS do
		if inBox(L, c.X, c.Z, r) then
			if c.Coll == "solid" or c.Coll == "tree" then return "lawn" end
			if c.Coll == "player" then c.Coll = "none" end
			if not c.Tuft and not c.Fixed and inBox(L, c.X, c.Z, 0) then return "lawn" end
		end
	end
	return nil
end
local function conflict(c)
	return near(c.X, c.Z, function(e)
		if (c.Fence and (e.Fence or e.Low)) or (e.Fence and c.Low) then return nil end
		local d = between(c, e)
		if c.Tree and e.Tree and d < T.TreeMin then return "trees" end
		if c.RS > 0 and e.RS > 0 and not (c.NoGap or e.NoGap) then
			local need = (c.Sparse or e.Sparse) and T.SparseGap or T.SolidGap
			if d - c.RS - e.RS < need then return "solidgap" end
		end
		local f = T.Spacing
		if c.Bush and e.Bush then
			f = T.BushSpacing
		elseif c.Low and e.Low then
			f = T.LowSpacing
		end
		if d < f * (c.R + e.R) then return "spacing" end
		return nil
	end)
end
local function check(c)
	if c.X < LAND.MinX or c.X > LAND.MaxX or c.Z < LAND.MinZ or c.Z > LAND.MaxZ then return "offMeadow" end
	if type(Config.ZoneAt) == "function" then
		local ok, zone = pcall(Config.ZoneAt, Vector3.new(c.X, 0, c.Z))
		if ok and type(zone) == "table" and zone.Id ~= "SlimeMeadow" then return "offMeadow" end
	end
	if not c.Fixed and coastDist(c.X, c.Z) < T.Coast then return "coast" end
	local why = zoneCheck(c) or roadCheck(c) or lawnCheck(c)
	if why then return why end
	local y, nrm, bad = ground(c.X, c.Z, c)
	if not y then return "ground:" .. bad end
	local pts = {}
	if c.Seg then
		pts = { { c.Seg[1], c.Seg[2] }, { c.Seg[3], c.Seg[4] } }
	elseif not c.Tree and c.R >= 3 then
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.4
			table.insert(pts, { c.X + math.cos(a) * c.R * 0.7, c.Z + math.sin(a) * c.R * 0.7 })
		end
	end
	local yc = y -- the centre's ground
	if (c.Low or c.Small) and not c.Hill and yc > T.MaxYLow then return "ground:high" end
	for _, p in pts do
		local y2, _, bad2 = ground(p[1], p[2], c)
		if not y2 then return "ground:" .. bad2 end
		if not c.Tilt then y = math.min(y, y2) end
	end
	c.Y, c.N = y, nrm
	if nrm and nrm.Y < 0.999 then
		if c.Tree then
			c.Sink += c.RS * math.sqrt(1 - nrm.Y * nrm.Y) / nrm.Y
		elseif not c.Seg then
			-- the downhill rim sits R x tan(slope) below the centre; sink by what the lowest sample has not covered yet
			-- (a Tilt piece: by the slope its lean leaves), never more than SlopeSinkMax x H in all
			local ny = nrm.Y
			if c.Tilt then ny = Vector3.yAxis:Lerp(nrm, c.Tilt).Unit:Dot(nrm) end
			if ny < 0.999 then
				local drop = c.R * math.sqrt(1 - ny * ny) / ny - (yc - y)
				if drop > 0 then c.Sink = math.max(c.Sink, math.min(c.Sink + drop, T.SlopeSinkMax * c.H)) end
			end
		end
	end
	return conflict(c)
end
local quota = {} -- per-pass share of what a cap has left, so a big filler pass never starves the later ones
local function setQuota(shares)
	table.clear(quota)
	for key, share in shares do quota[key] = math.floor((capLeft[key] or 0) * share + 0.5) end
end
local function capCheck(c)
	local key = capKey(c.Name)
	if (capLeft[key] or 0) <= 0 then return "cap:" .. key end
	if used.Total >= CAPS.Total then return "cap:total" end
	if c.Tree and used.Posts >= CAPS.Posts then return "cap:posts" end
	local parts, tris = costOf(c), trisOf(c.Name)
	if used.Parts + parts > room then return "budget" end
	if used.Tris + tris > CAPS.Tris then return "tris" end
	if c.Tier < 3 and (used.Total + 1 > CAPS.Total - HOLD.Total or used.Parts + parts > room - HOLD.Parts
		or used.Tris + tris > CAPS.Tris - HOLD.Tris) then return "reserve" end
	if quota[key] ~= nil and quota[key] <= 0 then return "quota:" .. key end
	return nil
end
local function accept(c)
	table.insert(placed, c)
	hashAdd(c)
	local key = capKey(c.Name)
	capLeft[key] -= 1
	if quota[key] ~= nil then quota[key] -= 1 end
	used.Total += 1
	used.Parts += costOf(c)
	used.Tris += trisOf(c.Name)
	if c.Tree then used.Posts += 1 end
	if KIND[c.Name] and KIND[c.Name].Boulder and c.H - c.Sink >= 4 then used.Tall += 1 end
	stats.Made[c.Name] = (stats.Made[c.Name] or 0) + 1
	stats.Tier[c.Tier] = (stats.Tier[c.Tier] or 0) + 1
end
local function unaccept(c) -- take a placed piece back (an all-or-nothing group that did not go in whole)
	local i = table.find(placed, c)
	if i then table.remove(placed, i) end
	local b = HASH[hkey(math.floor(c.X / 32), math.floor(c.Z / 32))]
	local j = b and table.find(b, c)
	if j then table.remove(b, j) end
	local key = capKey(c.Name)
	capLeft[key] += 1
	if quota[key] ~= nil then quota[key] += 1 end
	used.Total -= 1
	used.Parts -= costOf(c)
	used.Tris -= trisOf(c.Name)
	if c.Tree then used.Posts -= 1 end
	if KIND[c.Name] and KIND[c.Name].Boulder and c.H - c.Sink >= 4 then used.Tall -= 1 end
	stats.Made[c.Name] -= 1
	if stats.Made[c.Name] <= 0 then stats.Made[c.Name] = nil end
	stats.Tier[c.Tier] -= 1
	if stats.Tier[c.Tier] <= 0 then stats.Tier[c.Tier] = nil end
	stats.Why.takenBack = (stats.Why.takenBack or 0) + 1
end
local function group(fn) -- all or nothing: fn() places pieces with try() and returns false as soon as one fails
	local mark = #placed
	if fn() then return true end
	for i = #placed, mark + 1, -1 do unaccept(placed[i]) end
	return false
end
local function reject(why, name, x, z, o)
	stats.Why[why] = (stats.Why[why] or 0) + 1
	if o.Fixed and not o.Quiet and #stats.Failed < T.MaxFailed then -- Quiet: optional clump members, not listed
		table.insert(stats.Failed, string.format("%s %s(%.0f,%.0f) %s", o.Tag or "?", name, x, z, why))
	end
	return nil
end

-- vignette pieces that touch something already there slide up to 5 studs (12 fixed offsets, no randomness)
local NUDGE, NONE = {}, {}
for k = 0, 5 do
	local a = math.rad(k * 60)
	table.insert(NUDGE, { math.cos(a) * 2.5, math.sin(a) * 2.5 })
end
for k = 0, 5 do
	local a = math.rad(k * 60 + 30)
	table.insert(NUDGE, { math.cos(a) * 5, math.sin(a) * 5 })
end
-- try one piece: o = { S = scale | {lo, hi}, Yaw = deg | Vector2 target | nil (random), YawJitter, Tier, Tag, Fixed,
-- NoNudge, Quiet, Hill, Sand, Tilt (0..1 toward the ground normal), Sink, SinkFrac, Coll, MaxH, Tuft }
local function try(name, x, z, o)
	o = o or {}
	local size = info(name)
	if not size then return reject("missing", name, x, z, o) end
	local s = o.S or 1
	if type(s) == "table" then s = rng:NextNumber(s[1], s[2]) end
	if o.MaxH and size.Y * s > o.MaxH then s = o.MaxH / size.Y end
	if KIND[name] and KIND[name].Boulder and used.Tall >= T.TallBoulders and size.Y * s >= 4 then s = 3.9 / size.Y end
	local yaw = o.Yaw
	if typeof(yaw) == "Vector2" then
		yaw = yawToward(x, z, yaw.X, yaw.Y)
	elseif yaw == nil then
		yaw = rng:NextNumber(0, 360)
	end
	if o.YawJitter then yaw += rng:NextNumber(-o.YawJitter, o.YawJitter) end
	local tries = (o.Fixed and not o.NoNudge) and NUDGE or NONE
	local first = nil
	for i = 0, #tries do
		local dx, dz = 0, 0
		if i > 0 then dx, dz = tries[i][1], tries[i][2] end
		local c = make(name, x + dx, z + dz, o, s, yaw)
		local why = check(c)
		if not why then
			why = capCheck(c)
			if why then return reject(why, name, x, z, o) end
			accept(c)
			return c
		end
		first = first or why
		if not (why == "spacing" or why == "solidgap" or why == "trees") then break end
	end
	return reject(first, name, x, z, o)
end
local function mushOr(name) -- mushrooms are scarce while MeadowKit keeps its 8: another kind takes the spot when out
	return (capLeft.Kit_M_Mushrooms or 0) > 0 and "Kit_M_Mushrooms" or name
end
local function fixed(tag, tier)
	return function(name, x, z, o)
		o = o or {}
		o.Fixed, o.Tag, o.Tier = true, tag, o.Tier or tier or 1
		return try(name, x, z, o)
	end
end
-- a filler piece; kind.Name may be "Flowers" (a clump of A + B, kind.Three = 3, kind.One = one piece: flowers cost as
-- many triangles as a bush) or "Boulder" (A or B, 1 in 3 sunk 30%)
local function scatter(kind, x, z, tier, tag)
	local name = kind.Name
	if name == "Flowers" then
		local a = rng:NextNumber(0, math.pi * 2)
		local one = rng:NextNumber() < 0.5 and "Kit_M_FlowersA" or "Kit_M_FlowersB"
		local two = one == "Kit_M_FlowersA" and "Kit_M_FlowersB" or "Kit_M_FlowersA"
		local c = try(one, x, z, { S = kind.S, Tier = tier, Tag = tag })
		if c and not kind.One then
			try(two, c.X + math.cos(a) * 2.2, c.Z + math.sin(a) * 2.2, { S = kind.S, Tier = tier, Tag = tag })
			if kind.Three then
				try(one, c.X + math.cos(a + 2.1) * 2.3, c.Z + math.sin(a + 2.1) * 2.3, { S = kind.S, Tier = tier, Tag = tag })
			end
		end
		return c
	elseif name == "Boulder" then
		return try(rng:NextNumber() < 0.5 and "W_Boulder_A" or "W_Boulder_B", x, z,
			{ S = kind.S, SinkFrac = (rng:NextNumber() < 0.33) and 0.3 or nil, Tier = tier, Tag = tag })
	end
	return try(name, x, z, { S = kind.S, Tier = tier, Tag = tag })
end
local function pick(list, dl) -- weighted kind; trees / rocks keep off lawn edges, flowers face the lawns
	local total, w = 0, {}
	for i, e in list do
		local wt = e.W
		if (e.Name == "W_Tree_B" or e.Name == "Boulder") and dl < 12 then wt = 0 end
		if e.Name == "Flowers" then wt *= (dl < 8) and 2 or 0.6 end
		w[i] = wt
		total += wt
	end
	local r = rng:NextNumber() * total
	for i, e in list do
		r -= w[i]
		if r <= 0 then return e end
	end
	return list[#list]
end
-- clumps (pass 2; the concept's big round bushes stand in touching blobs of 3-5): grow() sets n - 1 bushes round a lead
-- piece already placed, ClumpTouch x (r1 + r2) from it; o.Along / o.Back = unit { x, z } along a road and away from it
-- (the clump stretches along the road and steps back from it, CLUMP_OFF), else evenly round; o.Walk = BushB only (always
-- walk-through: shoulders players cross); o.Fixed / o.Quiet as try(). clump() tries the lead (BushA, or BushB for Walk)
-- at (x, z) shifted along o.Along by each o.Shift in turn, then grows it. Both return the lead (or nil) and the count.
local CLUMP_OFF = { { 1, 0.12 }, { -1, 0.18 }, { 0.5, 0.92 }, { -0.55, 0.95 } } -- (along, back) x the touch distance
local function grow(lead, n, tier, tag, o)
	o = o or {}
	local made = 1
	local a0 = rng:NextNumber(0, math.pi * 2)
	for k = 1, n - 1 do
		local name = (o.Walk or k % 2 == 0) and "Kit_M_BushB" or "Kit_M_BushA"
		local size = info(name)
		if size then
			local s = rng:NextNumber(o.MS and o.MS[1] or 1.8, o.MS and o.MS[2] or 2.3)
			local d = (lead.R + math.sqrt(size.X * size.Z) * s / 2) * T.ClumpTouch
			local mx, mz
			if o.Along then
				local off = CLUMP_OFF[(k - 1) % #CLUMP_OFF + 1]
				mx = lead.X + (o.Along[1] * off[1] + o.Back[1] * off[2]) * d
				mz = lead.Z + (o.Along[2] * off[1] + o.Back[2] * off[2]) * d
			else
				local a = a0 + (k - 1) * 2 * math.pi / (n - 1) + rng:NextNumber(-0.35, 0.35)
				mx, mz = lead.X + math.cos(a) * d, lead.Z + math.sin(a) * d
			end
			if try(name, mx, mz, { S = s, Tier = tier, Tag = tag, Fixed = o.Fixed, Quiet = true }) then made += 1 end
		end
	end
	return lead, made
end
local function clump(x, z, n, tier, tag, o)
	o = o or {}
	local ux, uz = 1, 0
	if o.Along then ux, uz = o.Along[1], o.Along[2] end
	for _, dx in o.Shift or { 0 } do
		local lead = try(o.Walk and "Kit_M_BushB" or "Kit_M_BushA", x + ux * dx, z + uz * dx,
			{ S = o.S or { 2.2, 2.6 }, Tier = tier, Tag = tag, Fixed = o.Fixed, Quiet = o.Quiet })
		if lead then return grow(lead, n, tier, tag, o) end
	end
	return nil, 0
end
local function shuffle(list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end
local function gridPoints(step, jitter, want) -- jittered grid over the land, kept when want(x, z)
	local pts = {}
	for x = LAND.MinX, LAND.MaxX, step do
		for z = LAND.MinZ, LAND.MaxZ, step do
			local px, pz = x + rng:NextNumber(-jitter, jitter), z + rng:NextNumber(-jitter, jitter)
			if want(px, pz) then table.insert(pts, { px, pz }) end
		end
	end
	return shuffle(pts)
end
-- a centre for a ring vignette that no existing / placed piece overlaps (radius r); searches out to 18 studs
local function freeCentre(x, z, r)
	local function clear(px, pz)
		local probe = { X = px, Z = pz }
		return near(px, pz, function(e)
			if between(probe, e) < r + e.R then return true end
			return nil
		end) == nil
	end
	if clear(x, z) then return x, z end
	for _, d in { 6, 12, 18 } do
		for k = 0, 7 do
			local a = math.rad(k * 45 + d * 5)
			if clear(x + math.cos(a) * d, z + math.sin(a) * d) then return x + math.cos(a) * d, z + math.sin(a) * d end
		end
	end
	return x, z
end
local function at(cx, cz, deg, r) -- point at bearing deg (from +X toward +Z) and radius r
	local a = math.rad(deg)
	return cx + math.cos(a) * r, cz + math.sin(a) * r
end

------------------------------------------------------------------ 1. vignettes (layout order; tier 1)
do -- Welcome Green: the view from the bridge opens between two big canopies; the job board itself is MapBuilder's
	local put = fixed("welcome")
	put("W_Tree_B", 233, -42, { S = { 0.5, 0.55 } })
	put("W_Tree_B", 235, 46, { S = { 0.5, 0.55 } })
	for _, p in { { 220, -20 }, { 220, 23 }, { 228, 34 }, { 226, 45 } } do
		put("Kit_M_BushA", p[1], p[2], { S = { 2.0, 2.3 } })
	end
	for i, x in { 225, 228.5, 232, 235.5, 239 } do
		put(i % 2 == 1 and "Kit_M_FlowersA" or "Kit_M_FlowersB", x, i % 2 == 1 and 26 or 28, { S = { 1.3, 1.5 } })
	end
	for _, p in { { 217, 17 }, { 244, 17 }, { 285, -31 } } do
		put("Kit_M_Pinwheel", p[1], p[2], { S = { 1.1, 1.2 } })
	end
	-- 검수 10/08: cart and sign moved out of the first-quest / arrival boxes (verify: slimes could spawn hidden inside)
	put("Kit_M_FlowerCart", 306, -46, { S = 1.2, Yaw = Vector2.new(280, 0), Coll = "none" })
	-- pass 2: (232, -15) lay inside the spawn keep-clear circle (r 16 round (230, 0)) and was never built
	put("Kit_M_SignPost", 231, -18, { S = 1.0, Yaw = Vector2.new(210, 0), Coll = "none" })
end
do -- Mushroom fairy ring with stumps (main slime arena; pass 4 검수 10/09: 4 big mushrooms x2.5..3.5, big stumps between, a
	-- stone + bush ring outside with the road side (bearing 60..120 = south) left open; all walk-through at the ground)
	local put = fixed("fairyRing")
	local cx, cz = freeCentre(385, -64, 14) -- MeadowKit's W_Tree_A (393, -69) stands near the layout centre
	for k = 0, 3 do
		local x, z = at(cx, cz, k * 90 + 20, 13)
		put("Kit_M_Mushrooms", x, z, { S = { 2.5, 3.5 } })
		x, z = at(cx, cz, k * 90 + 65, 13.5)
		put("Kit_M_Stump", x, z, { S = { 1.7, 2.2 } })
	end
	for k = 0, 5 do
		local deg = k * 60 + 10
		if deg < 55 or deg > 125 then
			local x, z = at(cx, cz, deg, rng:NextNumber(21, 23))
			if k % 2 == 0 then
				put("W_Boulder_B", x, z, { S = { 0.28, 0.38 } })
			else
				local lead = put("Kit_M_BushA", x, z, { S = { 2.2, 2.6 } })
				if lead then grow(lead, 3, 1, "fairyRing", { Fixed = true }) end
			end
		end
	end
	for i, deg in { -135, -110, -50, 150 } do
		local x, z = at(cx, cz, deg, rng:NextNumber(17, 19))
		put(i == 2 and "Kit_M_FlowersB" or "Kit_M_FlowersA", x, z, { S = { 1.2, 1.4 } })
	end
end
do -- Mini fairy ring in the east lawn
	local put = fixed("miniRing")
	local cx, cz = freeCentre(583, 150, 10)
	local ring = { "Kit_M_Mushrooms", "Kit_M_Stump", "Kit_M_FlowersB", "Kit_M_Mushrooms", "Kit_M_Stump", "Kit_M_Mushrooms",
		"Kit_M_FlowersB", "Kit_M_Stump", "Kit_M_Mushrooms" }
	for k, name in ring do
		local x, z = at(cx, cz, (k - 1) * 40 + 10, 7)
		local sc = (name == "Kit_M_Mushrooms" and { 0.9, 1.3 }) or (name == "Kit_M_Stump" and { 0.9, 1.1 }) or 1.2
		put(name, x, z, { S = sc })
	end
end
do -- Picnic by the pond (NE of the water, outside the sand rim, looking in through the rim's NE opening)
	local put = fixed("picnic")
	local px, pz = PT.Pond.X, PT.Pond.Y
	put("Kit_M_LogBench", px + 28, pz - 26, { S = { 1.0, 1.1 }, Yaw = PT.Pond })
	put("Kit_M_LogBench", px + 39, pz - 15, { S = { 1.0, 1.1 }, Yaw = PT.Pond })
	put("Kit_M_PicnicBasket", px + 33, pz - 21, { S = 1.3 })
	put("W_Tree_B", px + 48, pz - 34, { S = 0.5 })
	put("Kit_M_Pinwheel", px + 23, pz - 18, { S = { 1.0, 1.2 } })
	put("Kit_M_BushA", px + 51, pz - 19, { S = 2.2 })
	put("Kit_M_FlowersA", px + 22, pz - 29, { S = { 1.2, 1.4 } })
	put("Kit_M_FlowersA", px + 44, pz - 10, { S = { 1.2, 1.4 } })
end
do -- pass 4 (검수 10/09): path stones in front of the scene spots (pond north opening, fairy ring road side, hill foot)
	local put = fixed("stepStones")
	local pc = PT.Pond
	for i, p in { { pc.X + 6, pc.Y - 46, 0 }, { pc.X + 9, pc.Y - 60, 8 }, { 385, -26, -6 }, { 388, -40, 10 }, { PT.Hill.X, -108, 0 },
		{ PT.Hill.X + 3, -98, 12 } } do
		put("Kit_W_StepStones", p[1], p[2], { S = { 0.9, 1.1 }, Yaw = Vector2.new(p[1] + math.sin(math.rad(p[3])) * 10, p[2] - 10) })
	end
end
local lily = {} -- pond lily pads { X, Z, Y = water top, D, Flower = { X, Z, D, Pink } | nil } (Parts, built in MODE kit)
do -- Pond rim (pass 2, concept: grey stones right at the water's edge, big round bushes behind them, lily pads), open
	-- to the N (road view) and NE (picnic view): bearings -105..-20 get no stone and no bush
	local put = fixed("pondRim")
	local px, pz = PT.Pond.X, PT.Pond.Y
	local function open(b) return b >= -105 and b <= -20 end
	-- the stone ring: one stone every 15 degrees on the first dry ground past the water (r 21.4..24.8; the water edge
	-- is about r 21, pondWater keeps 21 clear), every 4th a half-sunk jelly rock; all under 3.6 tall = walk-through
	local k = 0
	for b = -165, 180, 15 do
		if not open(b) then
			k += 1
			local deg = b + rng:NextNumber(-3, 3)
			local x, z
			for _, r in { 21.4, 22.2, 23, 23.8, 24.8 } do
				local tx, tz = at(px, pz, deg, r)
				if ground(tx, tz, { Sand = true, Rocky = true }) then
					x, z = tx, tz
					break
				end
			end
			if x and k % 4 == 2 and (capLeft.Kit_M_JellyRock or 0) > 0 then
				put("Kit_M_JellyRock", x, z, { S = { 0.95, 1.25 }, Sand = true, Sink = 0.35 })
			elseif x then
				put(rng:NextNumber() < 0.5 and "W_Boulder_A" or "W_Boulder_B", x, z, { S = { 0.25, 0.4 }, MaxH = 3.6, Sand = true,
					Sink = 0.4 })
			end
		end
	end
	-- the bush ring behind the stones (r 26.5..29.5): clumps of 2-4 big bushes, three one-slot walk-in gaps to the water
	local pattern = { "A", "B", "A", "_", "A", "A", "B", "_", "B", "A", "A", "_", "A", "B" }
	local i = 0
	for b = -170, 170, 20 do
		if not open(b) then
			i += 1
			local kind = pattern[(i - 1) % #pattern + 1]
			if kind ~= "_" then
				local x, z = at(px, pz, b + rng:NextNumber(-3, 3), rng:NextNumber(26.5, 29.5))
				if kind == "A" then
					put("Kit_M_BushA", x, z, { S = { 2.0, 2.6 }, Sand = true })
				else
					put("Kit_M_BushB", x, z, { S = { 2.2, 2.6 }, Sand = true })
				end
			end
		end
	end
	for _, deg in { 62, 98 } do -- white flowers between the stones at the S water edge
		local x, z = at(px, pz, deg, rng:NextNumber(24.5, 25.5))
		put(deg == 62 and "Kit_M_FlowersA" or "Kit_M_FlowersB", x, z, { S = { 1.2, 1.4 }, Sand = true, Quiet = true })
	end
	-- lily pads on the water (r <= 18), every LilyFlowerEvery-th with a white / pink flower; only where a ray finds
	-- water (the flat meadow without the pond basin gets none). They leave the edge reserve alone like tier 1 does.
	local tries = 0
	while #lily < T.LilyPads and tries < 60 do
		tries += 1
		local d = rng:NextNumber(3, 5)
		local r = math.sqrt(rng:NextNumber()) * (18 - d / 2)
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = px + math.cos(a) * r, pz + math.sin(a) * r
		local free = true
		for _, l in lily do
			if (l.X - x) ^ 2 + (l.Z - z) ^ 2 < ((l.D + d) / 2 + 0.8) ^ 2 then
				free = false
				break
			end
		end
		local hit = free and workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), RAY.Land)
		if hit and hit.Material == Enum.Material.Water then
			local flower = (#lily % T.LilyFlowerEvery == 0) and {} or nil
			local parts = flower and 3 or 1
			if used.Parts + parts > room - HOLD.Parts or used.Tris + parts * T.LilyTris > CAPS.Tris - HOLD.Tris then break end
			if flower then
				local fa, fr = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, d * 0.18)
				flower.X, flower.Z = x + math.cos(fa) * fr, z + math.sin(fa) * fr
				flower.D, flower.Pink = rng:NextNumber(1.2, 1.5), (#lily % (2 * T.LilyFlowerEvery)) ~= 0
			end
			local wy = hit.Position.Y -- the water top (Config.Map.WaterTop -1.2); a stray hit keeps the pad at -1.2
			table.insert(lily, { X = x, Z = z, Y = math.abs(wy - T.LilyY) < 0.6 and wy or T.LilyY, D = d, Flower = flower })
			used.Parts += parts
			used.Tris += parts * T.LilyTris
		end
	end
	for _, deg in { 120, 190 } do -- outside the bush ring (pass 1: r 31..33)
		local x, z = at(px, pz, deg, rng:NextNumber(33, 35))
		put("Kit_M_Mushrooms", x, z, { S = { 1.0, 1.3 }, Sand = true })
	end
	for i, deg in { 15, 65, 155, -145 } do
		local x, z = at(px, pz, deg, rng:NextNumber(33.5, 36))
		put(i % 2 == 1 and "Kit_M_FlowersA" or "Kit_M_FlowersB", x, z, { S = { 1.2, 1.5 }, Sand = true })
	end
	put("Kit_M_PuddleRim", px - 36, pz + 32, { S = { 1.0, 1.3 } })
	put("Kit_M_PuddleRim", px + 14, pz + 46, { S = { 1.0, 1.3 } })
	put("W_Tree_B", px - 40, pz - 15, { S = { 0.55, 0.6 } }) -- the far side: the road view sees water framed by trees
	put("W_Tree_B", px - 24, pz + 42, { S = { 0.55, 0.6 } })
end
do -- Flower-cart garden on the south road shoulder (its own fence; the road gets no fences at x 432..472)
	local put = fixed("cartGarden")
	put("Kit_M_FlowerCart", 452, 25, { S = 1.25, Yaw = Vector2.new(452, 0), YawJitter = 15 })
	for i, p in { { 441, 14 }, { 445, 17 }, { 448.5, 14.5 }, { 457, 16 }, { 461, 13.5 }, { 465, 17 } } do
		put(i % 2 == 1 and "Kit_M_FlowersA" or "Kit_M_FlowersB", p[1], p[2], { S = { 1.2, 1.6 } })
	end
	for _, p in { { 443, 29 }, { 447, 31 }, { 462, 30 } } do
		put("Kit_M_Pinwheel", p[1], p[2], { S = { 1.0, 1.3 } })
	end
	local fence = info("Kit_M_Fence")
	local seg = fence and fence.X * 1.15 or 6.9
	group(function() -- the garden fence goes in whole or not at all
		for k = 0, 2 do
			if not put("Kit_M_Fence", 441.5 + seg * (k + 0.5), 34, { S = 1.15, Yaw = (k % 2) * 180, YawJitter = 3, NoNudge = true }) then
				return false
			end
		end
		return true
	end)
	put("Kit_M_BushA", 435, 28, { S = 2.1 })
	put("Kit_M_BushA", 470, 28, { S = 2.1 })
	put("W_Tree_B", 458, 46, { S = 0.5 })
end
do -- Shard crystal corner (NE, toward the woods): the slimes ate shard dust here
	local put = fixed("crystalCorner")
	-- spots from the anchor { kind / dx, dz, scale, MaxH }. Flat meadow: the NE corner. Sculpted meadow: that corner is
	-- the 26..33-stud plateau nobody can climb, so the corner sits at the plateau's NW foot (flat grass Y 0..4 between
	-- hunting lawn I and the north beach; the cliff behind it to the east, rocks on its talus), the anchor 50 W / 26 N of
	-- the store's PlateauTop (meadow_terrain plan 2026-10-08: PL (616, -188), cliff foot x 578..586 there)
	local L = plateauTop and {
		At = { plateauTop.X - 50, plateauTop.Z - 26 },
		Rocks = { { "W_Boulder_A", 10, -4, { 0.45, 0.6 } }, { "W_Boulder_B", 6, -12, { 0.3, 0.4 }, 3.9 },
			{ "W_Boulder_A", 9, 10, { 0.45, 0.6 } } },
		Jelly = { { -10, 5 }, { 8, 1 }, { -2, 10 } },
		Bush = { { -14, -4 }, { 2, 13 }, { -8, -12 } },
		Flowers = { { -13, 10 }, { 2, 8 } },
		Trees = { { "W_Tree_A", -21, -10, { 0.45, 0.55 } }, { "W_Tree_A", 20, -15, { 0.45, 0.55 } }, { "W_Tree_C", -20, 6, 0.5 } },
	} or {
		At = { 598, -190 },
		Rocks = { { "W_Boulder_A", 8, -15, { 0.45, 0.6 } }, { "W_Boulder_B", 16, -4, { 0.45, 0.6 } },
			{ "W_Boulder_A", -8, -14, { 0.45, 0.6 } } },
		Jelly = { { -10, 4 }, { 10, 1 }, { 2, 12 } },
		Bush = { { -14, -8 }, { 18, 10 }, { -5, -24 } },
		Flowers = { { -13, 10 }, { 13, 15 } },
		Trees = { { "W_Tree_A", 22, -22, { 0.45, 0.55 } }, { "W_Tree_A", 32, 10, { 0.45, 0.55 } }, { "W_Tree_C", 7, -30, 0.5 } },
	}
	local ax, az = L.At[1], L.At[2]
	put("Kit_M_CrystalPile", ax, az, { S = 1.8 })
	for _, o in { { 5, 4 }, { -5, 2 }, { 3, -6 }, { -4, -5 } } do
		put("Kit_M_CrystalPile", ax + o[1], az + o[2], { S = { 0.9, 1.4 } })
	end
	for _, p in L.Rocks do
		put(p[1], ax + p[2], az + p[3], { S = p[4], MaxH = p[5] })
	end
	for _, p in L.Jelly do
		put("Kit_M_JellyRock", ax + p[1], az + p[2], { S = { 0.9, 1.3 } })
	end
	for _, p in L.Bush do
		put("Kit_M_BushB", ax + p[1], az + p[2], { S = 2.2 })
	end
	for _, p in L.Flowers do
		put("Kit_M_FlowersB", ax + p[1], az + p[2], { S = { 1.2, 1.4 } })
	end
	for _, p in L.Trees do
		put(p[1], ax + p[2], az + p[3], { S = p[4] })
	end
end
do -- King Slime Hill crown (the concept's hilltop ruin): a rock crown with one gap, crystal jewels, a bush ring
	local put = fixed("hillCrown")
	local hx, hz = PT.Hill.X, PT.Hill.Y
	-- the crown's gap faces the way up: south on the ball hill, the dirt ramp's top (NE) on the sculpted hill
	local gap = terrainHill and T.RampTopDeg or 90
	if hill or terrainHill then
		for k = 0, 4 do
			local x, z = at(hx, hz, gap + 40 + k * 70 + rng:NextNumber(-6, 6), rng:NextNumber(7, 9))
			put(k % 2 == 0 and "W_Boulder_A" or "W_Boulder_B", x, z, { S = { 0.3, 0.42 }, Hill = true, Tilt = 1, Sink = 0.4 })
		end
		for _, o in { { 0, 0 }, { 2.8, -1.6 }, { -2.4, 1.9 } } do
			put("Kit_M_CrystalPile", hx + o[1], hz + o[2], { S = { 1.5, 2.0 }, Hill = true, Tilt = 1, Sink = 0.2 })
		end
		for _, deg in { 20, 110, 200, 290 } do
			local r = terrainHill and rng:NextNumber(24, 30) or rng:NextNumber(10, 13) -- grass: the dome / the skirt
			local x, z = at(hx, hz, deg + rng:NextNumber(-10, 10), r)
			put(deg % 180 == 20 and "Kit_M_FlowersA" or "Kit_M_FlowersB", x, z, { S = { 1.2, 1.5 }, Hill = true, Tilt = 0.6, Sink = 0.2 })
		end
	end
	-- rock faces on the flank, sunk 30%: N / NE (layout); W / NW on the sculpted hill, whose dirt ramp climbs the E / NE
	for _, deg in (terrainHill and { -165, -135, -105 } or { -120, -75, -30 }) do
		local x, z = at(hx, hz, deg + rng:NextNumber(-8, 8), rng:NextNumber(22, 26))
		put("W_Boulder_B", x, z, { S = { 0.5, 0.6 }, SinkFrac = 0.3, Hill = true, Tilt = 0.5 })
	end
	for _, deg in { 140, 180, 220, 260, 300, 340 } do -- bush ring W / N / E, open to the S (loop road) and the SE
		local x, z = at(hx, hz, deg + rng:NextNumber(-6, 6), rng:NextNumber(31, 35))
		put("Kit_M_BushA", x, z, { S = { 2.0, 2.5 }, Hill = true, Tilt = 0.35 })
	end
	for _, deg in { 35, 55 } do -- mushrooms at the SE foot (beyond the skirt on the sculpted hill)
		local x, z = at(hx, hz, deg, terrainHill and rng:NextNumber(37, 39) or rng:NextNumber(18.5, 20))
		put("Kit_M_Mushrooms", x, z, { S = { 1.0, 1.4 }, Hill = true, Tilt = 0.35 })
	end
	put("W_Tree_B", hx - 25, hz - 44, { S = { 0.6, 0.7 } })
	put("W_Tree_B", hx + 2, hz - 49, { S = { 0.6, 0.7 } })
	put("W_Tree_A", hx + 26, hz - 44, { S = 0.5 })
end
do -- Roadside rest stops: a bench facing the road, a shade tree behind, a pinwheel and flowers at the ends
	local put = fixed("restStop")
	for _, b in { { 506, -22 }, { 592, 23 } } do
		local x, z = b[1], b[2]
		local away = z < 0 and -1 or 1
		put("Kit_M_LogBench", x, z, { S = { 1.0, 1.1 }, Yaw = Vector2.new(x, 0) })
		put("W_Tree_B", x + rng:NextNumber(-3, 3), z + away * rng:NextNumber(12, 14), { S = { 0.45, 0.5 } })
		put("Kit_M_Pinwheel", x - 4.6, z + away * 0.5, { S = { 1.0, 1.2 } })
		put("Kit_M_FlowersA", x + 4.6, z, { S = { 1.2, 1.4 } })
	end
end
do -- Fork sign posts (blank panels; an English SurfaceGui label can come later). (250, -15) is the welcome one
	local put = fixed("signs")
	local lp = ROADS.RoadMeadowLoop
	for _, s in { { 522, 15, 505, 0 }, { lp[1] - 4, lp[4] + 7, lp[1] - 4, -13 }, { lp[3] + 6, lp[4] + 7, lp[3] + 6, -13 },
		{ 620, -16, 590, 0 } } do
		put("Kit_M_SignPost", s[1], s[2], { S = { 1.0, 1.1 }, Yaw = Vector2.new(s[3], s[4]) })
	end
end
do -- Hedge islands between lawns: a tree, a clump of three big bushes on the lawn-facing sides (pass 2: + the BushB
	-- between them), flowers in front, a rock or a stump
	local put = fixed("islands")
	local function lawnDirs(x, z)
		local list = {}
		for _, L in LAWNS do
			local nx, nz = math.clamp(x, L[1], L[3]), math.clamp(z, L[2], L[4])
			local d = math.sqrt((nx - x) ^ 2 + (nz - z) ^ 2)
			if d > 0.01 then table.insert(list, { d, (nx - x) / d, (nz - z) / d }) end
		end
		table.sort(list, function(a, b) return a[1] < b[1] end)
		local a = list[1] or { 0, 1, 0 }
		local b = list[2]
		if not b or b[1] > 25 or (a[2] * b[2] + a[3] * b[3]) > 0.5 then
			local ang = math.atan2(a[3], a[2]) + math.rad(70)
			b = { 0, math.cos(ang), math.sin(ang) }
		end
		return a[2], a[3], b[2], b[3]
	end
	-- (517, 182): the layout's (492, 180) lies inside lawn D2 (x 362..512), so the island sits just east of it
	for i, a in { { 338, -70 }, { 512, -65 }, { 512, -95 }, { 335, 44 }, { 338, 96 }, { 400, 118 }, { 470, 118 }, { 517, 182 } } do
		local x, z = a[1], a[2]
		local d1x, d1z, d2x, d2z = lawnDirs(x, z)
		put("W_Tree_B", x, z, { S = { 0.45, 0.55 } })
		put("Kit_M_BushA", x + d1x * 5.5, z + d1z * 5.5, { S = { 1.9, 2.5 } })
		put("Kit_M_BushA", x + d2x * 5.5, z + d2z * 5.5, { S = { 1.9, 2.5 } })
		local bx, bz = d1x + d2x, d1z + d2z
		local bm = math.sqrt(bx * bx + bz * bz)
		if bm > 0.2 then
			put("Kit_M_BushB", x + bx / bm * 8.5, z + bz / bm * 8.5, { S = { 2.0, 2.4 }, Quiet = true })
		end
		put("Kit_M_FlowersA", x + d1x * 9.5 - d1z * 1.5, z + d1z * 9.5 + d1x * 1.5, { S = { 1.2, 1.5 } })
		if i % 2 == 0 then
			put("Kit_M_FlowersB", x + d2x * 9.5 + d2z * 1.5, z + d2z * 9.5 - d2x * 1.5, { S = { 1.2, 1.5 } })
		end
		if i % 3 == 0 then
			put(i % 2 == 0 and "W_Boulder_A" or "W_Boulder_B", x - d1x * 5, z - d1z * 5, { S = { 0.3, 0.4 }, MaxH = 3.9 })
		elseif i % 3 == 1 then
			put("Kit_M_Stump", x - d1x * 5, z - d1z * 5, { S = { 0.9, 1.2 } })
		end
	end
end
do -- East exit into the woods: pines and vine trees hint at the Goblin Woods ahead
	local put = fixed("eastExit")
	put("W_Tree_A", 624, -36, { S = { 0.45, 0.55 } })
	put("W_Tree_A", 622, 40, { S = { 0.45, 0.55 } })
	put("W_Tree_A", 612, -44, { S = { 0.45, 0.55 } })
	put("W_Tree_C", 610, -25, { S = { 0.45, 0.5 } })
	put("W_Tree_C", 634, 44, { S = { 0.45, 0.5 } })
	put("W_Boulder_A", 630, -24, { S = { 0.4, 0.5 } })
	put("W_Boulder_A", 628, 26, { S = { 0.4, 0.5 } })
	put("Kit_M_BushB", 617, -54, { S = { 2.2, 2.6 } })
	put("Kit_M_BushB", 614, 50, { S = { 2.2, 2.6 } })
end
do -- Pumpkin path hedges: a clump of three walk-through bushes (pass 2; was one) every 30 studs on alternating sides,
	-- 7..10 off the strip, stretched along the path, no fences; a stump / mushrooms or flowers beside each
	local put = fixed("pumpkinHedge")
	local pp = ROADS.RoadPumpkin
	for k = 0, 5 do
		local z = pp[2] + 26 + k * 30
		local west = k % 2 == 0
		local x = west and (pp[1] - rng:NextNumber(7, 10)) or (pp[3] + rng:NextNumber(7, 10))
		clump(x, z, 3, 1, "pumpkinHedge", { Walk = true, Fixed = true, S = { 2.2, 2.6 }, MS = { 1.9, 2.3 }, Along = { 0, 1 },
			Back = { west and -1 or 1, 0 } })
		put(west and mushOr("Kit_M_Stump") or "Kit_M_FlowersB", x + (west and -2.5 or 2.5), z + 9.5, { S = { 1.0, 1.4 } })
	end
end
do -- Slime puddles inside two lawns (low landmarks, walk-through)
	local put = fixed("puddles")
	put("Kit_M_PuddleRim", 430, 160, { S = { 1.2, 1.4 } })
	put("Kit_M_PuddleRim", 440, -90, { S = { 1.2, 1.4 } })
end
-- (Kit_M_Bridge: not placed; the meadow has no creek yet. Kit_M_JobBoard: MapBuilder's, counted, not placed here.)

------------------------------------------------------------------ 2. road fences (tier 2): runs along the roads, gaps of 13+
local runs, loopRuns = {}, {} -- main road runs { Side, X0, X1, Third, Ok, Bush }; loop road run starts (built)
do
	local fence = info("Kit_M_Fence")
	local seg = fence and fence.X * 1.15 or 6.9
	local len = seg * 3
	local cr = ROADS.RoadMeadow
	local lineZ = cr[4] + 3.5 -- |z| 12.5
	-- no fences: arrival / board (x < 290), the cart garden, the pumpkin fork, the woods exit, the two rest-stop benches
	local NO = { { 432, 472, 0 }, { 515, 556, 0 }, { 496, 516, -1 }, { 582, 602, 1 } }
	local function free(side, a, b)
		if a < 290 or b > 612 then return false end
		for _, e in NO do
			if (e[3] == 0 or e[3] == side) and b > e[1] and a < e[2] then return false end
		end
		return true
	end
	for _, side in { -1, 1 } do
		local last = -math.huge
		local x = 290 + (side > 0 and 33.7 or 0)
		while x < 612 do
			local x0 = nil
			for d = 0, 20, 2 do
				if free(side, x - d, x - d + len) and x - d >= last + 13 then
					x0 = x - d
					break
				end
				if free(side, x + d, x + d + len) and x + d >= last + 13 then
					x0 = x + d
					break
				end
			end
			if x0 then
				table.insert(runs, { Side = side, X0 = x0, X1 = x0 + len })
				last = x0 + len
			end
			x += 67.4
		end
	end
	table.sort(runs, function(a, b) return a.X0 < b.X0 end)
	-- all or nothing: a run's three segments and its bush go in together (r.Ok), or the run is left out whole (no orphan
	-- segment; the road clumps fill its stretch instead and it gets no gateposts)
	for i, r in runs do
		r.Third = i % 3 == 0
		r.Ok = group(function()
			for k = 0, 2 do
				local z = r.Side * lineZ
				local yaw = (k % 2) * 180 + rng:NextNumber(-3, 3) -- every other segment flipped: the post caps vary
				if r.Third and k == 2 then -- meander: the last segment turns away from the road and steps out
					z += r.Side * 1.5
					yaw += -r.Side * rng:NextNumber(12, 18)
				end
				if not try("Kit_M_Fence", r.X0 + seg * (k + 0.5), z, { S = 1.15, Yaw = yaw, Tier = 2, Tag = "fence", Fixed = true,
					NoNudge = true }) then
					return false
				end
			end
			-- the run's bush: its middle, or its far end when the middle reaches into a first-quest box (OpenOnly)
			local bz = r.Side * rng:NextNumber(17.5, 19)
			local bx = (r.X0 + r.X1) / 2
			if openOnlyAt(bx, bz, 4.5) then bx = r.X1 - 4.5 end
			r.Bush = try("Kit_M_BushA", bx, bz, { S = { 1.9, 2.3 }, Tier = 2, Tag = "fence", Fixed = true }) -- pass 2: 1.4..1.8
			return r.Bush ~= nil
		end)
	end
	-- loop road: 2-segment runs on the north (hill) side only, none along the hill's bush ring (also all or nothing)
	local lp = ROADS.RoadMeadowLoop
	local x = lp[1] + 2
	while x + seg * 2 <= lp[3] + 4 do
		if not (x + seg * 2 > 392 and x < 470) then
			local x0 = x
			local ok = group(function()
				for k = 0, 1 do
					if not try("Kit_M_Fence", x0 + seg * (k + 0.5), lp[2] - 4, { S = 1.15, Yaw = (k % 2) * 180, YawJitter = 3,
						Tier = 2, Tag = "loopFence", Fixed = true, NoNudge = true }) then
						return false
					end
				end
				return true
			end)
			if ok then table.insert(loopRuns, x0) end
		end
		x += 42
	end
	for _, ex in { lp[1] - 9, lp[3] + 9 } do -- mushroom clumps at both loop road ends
		try(mushOr("Kit_M_Stump"), ex, (lp[2] + lp[4]) / 2, { S = { 1.1, 1.4 }, Tier = 2, Tag = "loopEnd", Fixed = true })
	end
end

------------------------------------------------------------------ 3. edge belt trees: groves 13..32 from the coast (tier 3)
local edgeTrees = {} -- { x, z, inland x, inland z, along x, along z } for the bushes under them (pass 5)
do
	local function treeKind(x, z) -- vine trees toward the woods, pines in the north / east, round trees elsewhere
		if x > 590 and rng:NextNumber() < 0.3 then return "W_Tree_C", { 0.45, 0.55 } end
		if rng:NextNumber() < ((z < -150 or x > 560) and 0.45 or 0.12) then return "W_Tree_A", { 0.45, 0.6 } end
		return "W_Tree_B", { 0.55, 0.72 }
	end
	-- the four corners first (pass 2; concept: big tree groups frame every corner of the view): five trees along each
	-- rounded corner's arc 19..25 from the coast (12.5 apart), two more a row further in (36..40, the flower row)
	for _, cn in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local ccx, ccz = GEO.CX + cn[1] * GEO.HX, GEO.CZ + cn[2] * GEO.HZ -- the corner arc's centre
		local base = math.atan2(cn[2], cn[1]) -- the diagonal, outward
		for j, off in { -0.66, -0.33, 0, 0.33, 0.66, -0.25, 0.25 } do
			local rr = T.Corner - ((j > 5) and rng:NextNumber(36, 40) or rng:NextNumber(19, 25))
			local a = base + off + rng:NextNumber(-0.05, 0.05)
			local x, z = ccx + math.cos(a) * rr, ccz + math.sin(a) * rr
			local nx, nz = -math.cos(a), -math.sin(a) -- inland
			local name, sc = treeKind(x, z)
			local t = scatter({ Name = name, S = { sc[1] * 1.1, sc[2] * 1.1 } }, x, z, 3, "cornerTree")
			if t then
				table.insert(edgeTrees, { t.X, t.Z, nx, nz, -nz, nx })
				if j <= 5 then -- the frame: a big bush at the front tree's inland foot now (pass 5 adds more if room is left)
					local ba = a + math.pi + rng:NextNumber(-0.6, 0.6)
					local bd = rng:NextNumber(6, 7.5)
					scatter({ Name = "Kit_M_BushA", S = { 2.0, 2.5 } }, t.X + math.cos(ba) * bd, t.Z + math.sin(ba) * bd, 3, "cornerBush")
				end
			end
		end
	end
	local cand = {}
	for x = LAND.MinX + 12, LAND.MaxX - 12, 8 do
		for z = LAND.MinZ + 12, LAND.MaxZ - 12, 8 do
			local px, pz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
			local cd = coastDist(px, pz)
			if cd >= 17 and cd <= 27 then table.insert(cand, { px, pz }) end
		end
	end
	shuffle(cand)
	local centres = {}
	for _, p in cand do
		local open = true
		for _, q in centres do
			local dx, dz = p[1] - q[1], p[2] - q[2]
			if dx * dx + dz * dz < T.GroveGap * T.GroveGap then
				open = false
				break
			end
		end
		if open then table.insert(centres, p) end
	end
	for _, g in centres do
		if rng:NextNumber() >= T.GroveEmpty then -- a few grove slots stay empty (a glimpse of the sea)
			local nx, nz = inland(g[1], g[2])
			local tx, tz = -nz, nx -- along the coast
			local size = T.GroveSizes[rng:NextInteger(1, #T.GroveSizes)]
			local offs = (size == 1 and { 0 }) or (size == 2 and { -6.5, 6.5 }) or { -13, 0, 13 }
			for _, along in offs do
				local a, inl = along + rng:NextNumber(-2, 2), rng:NextNumber(-3, 3)
				local x, z = g[1] + tx * a + nx * inl, g[2] + tz * a + nz * inl
				local name, sc = treeKind(x, z)
				local t = scatter({ Name = name, S = sc }, x, z, 3, "edgeTree")
				if t then table.insert(edgeTrees, { t.X, t.Z, nx, nz, tx, tz }) end
			end
			if rng:NextNumber() < 0.1 then -- a rock at one end of the grove (pass 5, 검수 10/09: 0.3 -> 0.1, rocks only in meaningful clusters)
				local sg = rng:NextNumber() < 0.5 and -1 or 1
				local e = offs[sg < 0 and 1 or #offs] + sg * 11.5
				scatter({ Name = "Boulder", S = { 0.4, 0.65 } }, g[1] + tx * e + nx * 2, g[2] + tz * e + nz * 2, 3, "edgeRock")
			end
		end
	end
end

------------------------------------------------------------------ 4. road edges (tier 4): the view while walking
do
	local cr, lp = ROADS.RoadMeadow, ROADS.RoadMeadowLoop
	-- a flower gatepost at both ends of every fence run (one piece each: the flower cap is shared with MeadowKit's 24),
	-- a pinwheel pair at every third run; built runs only
	for _, r in runs do
		if r.Ok then
			for j, ex in { r.X0 - 1.5, r.X1 + 1.5 } do
				local z = r.Side * (cr[4] + rng:NextNumber(2.3, 3)) -- pass 2: 2..3 (a big flower at 2 touched the road rule)
				try(j == 1 and "Kit_M_FlowersA" or "Kit_M_FlowersB", ex, z, { S = { 1.3, 1.6 }, Tier = 4, Tag = "gatepost", Fixed = true })
			end
			if r.Third then
				try("Kit_M_Pinwheel", r.X1 + 3.5, r.Side * 15, { S = { 1.0, 1.3 }, Tier = 4, Tag = "gatepost", Fixed = true })
				try("Kit_M_Pinwheel", r.X1 + 5.5, r.Side * 16.8, { S = { 1.0, 1.3 }, Tier = 4, Tag = "gatepost", Fixed = true })
			end
		end
	end
	-- the joins stay open (pass 2): no clump, shade tree or flower patch at the arrival, the cart garden, the pumpkin fork,
	-- the two rest stops and the woods exit { from x, to x, side: 0 both, -1 north, 1 south }
	local JOINS = { { -math.huge, 296, 0 }, { 432, 474, 1 }, { 515, 558, 1 }, { 496, 516, -1 }, { 582, 602, 1 },
		{ 600, math.huge, 0 } }
	local function joinAt(side, x0, x1)
		for _, e in JOINS do
			if (e[3] == 0 or e[3] == side) and x1 > e[1] and x0 < e[2] then return true end
		end
		return false
	end
	local FLOWERS = { Name = "Flowers", S = { 1.2, 1.5 } }
	local FLOWER = { Name = "Flowers", S = { 1.3, 1.6 }, One = true }
	for _, side in { -1, 1 } do
		-- bush clumps (pass 2, was the one-piece "wave"; concept: big round bushes in blobs along the path): two more
		-- bushes beside every built fence run's bush (behind the fence: no way in is lost) and, in every free shoulder
		-- between the runs and the joins, one clump of 3-5 per ClumpLen + ClumpGap studs, centred so that walk-in gaps
		-- of ClumpGap+ stay open on both sides; a flower patch in front of each clump, toward the road
		for _, r in runs do
			if r.Ok and r.Side == side and r.Bush and math.abs(r.Bush.X - (r.X0 + r.X1) / 2) < 1 then
				grow(r.Bush, 3, 4, "runClump", { Along = { 1, 0 }, Back = { 0, side } })
			end
		end
		local cuts = {}
		for _, e in JOINS do
			if e[3] == 0 or e[3] == side then table.insert(cuts, { e[1], e[2] }) end
		end
		for _, r in runs do
			if r.Ok and r.Side == side then table.insert(cuts, { r.X0 - 1.5, r.X1 + 1.5 }) end
		end
		table.sort(cuts, function(p, q) return p[1] < q[1] end)
		local reach = cr[1]
		for _, c in cuts do
			local a, b = reach, c[1]
			if b - a >= T.ClumpLen + 2 * T.ClumpGap then
				local k = math.floor((b - a - T.ClumpGap) / (T.ClumpLen + T.ClumpGap))
				local g = (b - a - T.ClumpLen * k) / (k + 1)
				for i = 1, k do
					local cx = a + g * i + T.ClumpLen * (i - 0.5)
					local lead = clump(cx, side * rng:NextNumber(16.4, 17.6), rng:NextInteger(4, 5), 4, "roadClump",
						{ Along = { 1, 0 }, Back = { 0, side }, Shift = { 0, 4, -4 } })
					if lead then
						scatter(FLOWERS, lead.X + rng:NextNumber(-4, 4), side * rng:NextNumber(12.6, 13.4), 4, "roadFlowers")
					end
				end
			elseif b - a >= 16 then -- a short shoulder: a walk-through clump (BushB only, so no gap is needed)
				clump((a + b) / 2, side * rng:NextNumber(15.6, 16.6), 3, 4, "roadClump", { Walk = true, S = { 2.0, 2.4 },
					MS = { 1.8, 2.2 }, Along = { 1, 0 }, Back = { 0, side }, Shift = { 0, 3, -3 } })
			elseif b - a >= 8 then -- a very short one: a flower
				scatter(FLOWER, (a + b) / 2, side * rng:NextNumber(12.6, 14), 4, "roadFlowers")
			end
			reach = math.max(reach, c[2])
		end
		-- big shade trees by the road (pass 2; was one 0.42..0.5 tree per 70 at |z| 26..34): one 0.6..0.75 tree per ~56
		-- studs, behind the clumps where the shoulder is wide, else between them (|z| 19.5..24, short of the lawns), a
		-- flower patch at its road side
		for x0 = 302 + (side > 0 and 28 or 0), 596, 56 do
			local x = x0 + rng:NextNumber(-6, 6)
			if not joinAt(side, x - 8, x + 8) then
				local name = (x > 560 and rng:NextNumber() < 0.5) and "W_Tree_A" or "W_Tree_B"
				local kind = { Name = name, S = name == "W_Tree_A" and { 0.55, 0.65 } or { 0.6, 0.75 } }
				local t
				for _, p in { { 0, 28, 34 }, { 0, 19.5, 24 }, { 9, 19.5, 24 }, { -9, 19.5, 24 } } do
					t = scatter(kind, x + p[1], side * rng:NextNumber(p[2], p[3]), 4, "roadShade")
					if t then break end
				end
				if t then
					scatter(FLOWER, t.X + rng:NextNumber(-3, 3), side * rng:NextNumber(12.6, 13.6), 4, "roadFlowers")
					-- pass 4 (검수 10/09): the shade trees stand in pairs / threes (a grove by the road, not a lone tree)
					for _, dx in { 8.5, -8.5 } do
						if rng:NextNumber() < 0.7 then
							scatter(kind, t.X + dx + rng:NextNumber(-1.5, 1.5), t.Z + side * rng:NextNumber(-2.5, 2.5), 4, "roadShade")
						end
					end
				end
			end
		end
	end
	-- loop road (pass 2): a clump of three behind every other north fence run (toward the hill lawns); on the south (lawn)
	-- side one piece every 40 studs, every other one a clump of three (walk-through where it reaches into the lawn), the
	-- rest a flower
	for i, x0 in loopRuns do
		if i % 2 == 1 then
			clump(x0 + 6.9, lp[2] - rng:NextNumber(9.5, 10.5), 4, 4, "loopClump", { Along = { 1, 0 }, Back = { 0, -1 },
				Shift = { 0, 3, -3 } })
		end
	end
	local n = 0
	for x = lp[1] + 10, lp[3] - 10, 40 do
		n += 1
		local xx = x + rng:NextNumber(-3, 3)
		if n % 2 == 1 then
			clump(xx, lp[4] + rng:NextNumber(6.8, 7.4), 4, 4, "loopSouth", { Along = { 1, 0 }, Back = { 0, 1 },
				Shift = { 0, 4, -4 } })
		else
			scatter({ Name = "Flowers", S = { 1.3, 1.6 }, One = true }, xx, lp[4] + rng:NextNumber(4, 6), 4, "loopSouth")
		end
	end
end

------------------------------------------------------------------ 5. under the edge trees (tier 5): bushes on the inland side
setQuota({ Kit_M_BushA = 0.45, Kit_M_BushB = 0.4, Flowers = 0.35 })
for _, e in edgeTrees do -- layering: trees at the back, bushes in the middle, flowers in front (here and pass 7)
	local x, z, nx, nz, tx, tz = e[1], e[2], e[3], e[4], e[5], e[6]
	local ang = math.atan2(nz, nx) + math.rad(rng:NextNumber(-55, 55))
	local d = rng:NextNumber(5.5, 7.5)
	scatter({ Name = "Kit_M_BushA", S = { 1.9, 2.5 } }, x + math.cos(ang) * d, z + math.sin(ang) * d, 5, "edgeBush")
	if rng:NextNumber() < 0.4 then
		local sg = rng:NextNumber() < 0.5 and -1 or 1
		scatter({ Name = "Kit_M_BushB", S = { 2.2, 2.6 } }, x + tx * sg * 7 + nx * 2, z + tz * sg * 7 + nz * 2, 5, "edgeBush")
	end
	if rng:NextNumber() < 0.35 then -- pass 2: flowers round the tree's foot, in front of its bushes
		local fa = math.atan2(nz, nx) + math.rad(rng:NextNumber(-40, 40))
		local fd = rng:NextNumber(10, 12)
		scatter({ Name = "Flowers", S = { 1.3, 1.6 }, One = true }, x + math.cos(fa) * fd, z + math.sin(fa) * fd, 5, "edgeFlowers")
	end
end

------------------------------------------------------------------ 6. hedge columns and bands between lawns (tier 6)
setQuota({ Kit_M_BushA = 0.6, Kit_M_BushB = 0.5, Flowers = 0.45, W_Tree_B = 0.7, Kit_M_Stump = 0.6, Kit_M_Mushrooms = 0.5,
	Boulder = 0.7 })
do
	local HEDGE = {
		{ Name = "Kit_M_BushA", W = 10, S = { 1.9, 2.5 } }, -- pass 2: 1.6..2.2
		{ Name = "Kit_M_BushB", W = 6, S = { 1.9, 2.6 } },
		{ Name = "Flowers", W = 7, S = { 1.2, 1.6 } },
		{ Name = "W_Tree_B", W = 5, S = { 0.42, 0.55 } },
		{ Name = "Kit_M_Stump", W = 1.5, S = { 0.9, 1.3 } },
		{ Name = "Kit_M_Mushrooms", W = 1.5, S = { 1.0, 1.4 } },
		{ Name = "Boulder", W = 1.0, S = { 0.3, 0.6 } }, -- pass 5: 2.5 -> 1.0
	}
	for _, p in gridPoints(T.Grid, T.Jitter, function(x, z) return bandAt(x, z) == "hedge" end) do
		if rng:NextNumber() < 0.45 then -- pass 4 (검수 10/09): 0.85 -> 0.45, the budget goes to clumps along roads and scene spots
			scatter(pick(HEDGE, lawnDist(p[1], p[2])), p[1], p[2], 6, "hedge")
		end
	end
end

------------------------------------------------------------------ 7. road fill behind the wavy edge, edge front row 32..42 (tier 7)
setQuota({ Kit_M_BushA = 0.5, Kit_M_BushB = 0.5, Flowers = 0.5, Kit_M_Mushrooms = 0.5 })
do
	local cr = ROADS.RoadMeadow
	local FILL = {
		{ Name = "Kit_M_BushB", W = 3, S = { 1.9, 2.5 } }, -- pass 2: 1.8..2.4 / 1.6..2.0
		{ Name = "Kit_M_BushA", W = 3, S = { 1.9, 2.4 } },
		{ Name = "Flowers", W = 3, S = { 1.2, 1.5 } },
	}
	for _, p in gridPoints(T.Grid, T.Jitter, function(x, z)
		return bandAt(x, z) == "road" and (math.abs(z) >= 20 or z < cr[2] - 40)
	end) do
		if rng:NextNumber() < 0.6 then scatter(pick(FILL, lawnDist(p[1], p[2])), p[1], p[2], 7, "roadFill") end
	end
	for _, p in gridPoints(T.Grid, T.Jitter, function(x, z) return bandAt(x, z) == "edgeFront" end) do
		if rng:NextNumber() < 0.55 then
			if rng:NextNumber() < 0.85 then
				scatter({ Name = "Flowers", S = { 1.2, 1.6 }, Three = rng:NextNumber() < 0.4 }, p[1], p[2], 7, "edgeFront")
			else
				scatter({ Name = "Kit_M_Mushrooms", S = { 1.0, 1.4 } }, p[1], p[2], 7, "edgeFront")
			end
		end
	end
end

------------------------------------------------------------------ 8. gap fill: no r 9 circle in a dressed band left bare
local function dressedSample(x, z)
	local b = bandAt(x, z)
	if not (b == "edgeBack" or b == "edgeFront" or b == "hedge" or b == "road") then return false end
	for _, rd in ROADLIST do
		if boxDist(rd, x, z) < 4 then return false end
	end
	for _, zn in CLEAR do
		if zn.Rule == "all" then
			if zn.Box and inBox(zn.Box, x, z, 0) then return false end
			if zn.C and (Vector2.new(x, z) - zn.C).Magnitude < zn.R then return false end
		end
	end
	return ground(x, z) ~= nil
end
setQuota({ Kit_M_BushA = 0.7, Flowers = 0.6 })
do
	local gaps = {}
	for x = LAND.MinX + 4.5, LAND.MaxX, 9 do
		for z = LAND.MinZ + 4.5, LAND.MaxZ, 9 do
			if dressedSample(x, z) and not hasNear(x, z, 9) then table.insert(gaps, { x, z }) end
		end
	end
	shuffle(gaps)
	for _, p in gaps do
		if not hasNear(p[1], p[2], 9) and rng:NextNumber() < 0.5 then -- pass 4: half the gaps stay open
			if rng:NextNumber() < 0.6 then
				scatter({ Name = "Kit_M_BushA", S = { 1.8, 2.3 } }, p[1], p[2], 8, "gapFill") -- pass 2: 1.4..1.8
			else
				scatter({ Name = "Flowers", S = { 1.2, 1.5 } }, p[1], p[2], 8, "gapFill")
			end
		end
	end
end

------------------------------------------------------------------ 9. lawn tufts: one low walk-through piece per 36 x 36 cell
setQuota({})
do
	local tufts = {}
	for _, L in LAWNS do
		for x = L[1] + 18, L[3], 36 do
			for z = L[2] + 18, L[4], 36 do
				local px = math.clamp(x + rng:NextNumber(-8, 8), L[1] + 3, L[3] - 3)
				local pz = math.clamp(z + rng:NextNumber(-8, 8), L[2] + 3, L[4] - 3)
				local open = true
				for _, t in tufts do
					if (t[1] - px) ^ 2 + (t[2] - pz) ^ 2 < 900 then
						open = false
						break
					end
				end
				if open then
					local r = rng:NextNumber()
					local name = (r < 0.35 and "Kit_M_FlowersA") or (r < 0.7 and "Kit_M_FlowersB") or (r < 0.88 and "Kit_M_BushB")
						or "Kit_M_Stump"
					local sc = (name == "Kit_M_BushB" and { 1.4, 1.8 }) or (name == "Kit_M_Stump" and { 0.9, 1.2 }) or { 1.4, 1.7 }
					if try(name, px, pz, { S = sc, MaxH = 2.5, Tuft = true, Tier = 9, Tag = "tuft" }) then
						table.insert(tufts, { px, pz })
					end
				end
			end
		end
	end
end

------------------------------------------------------------------ report helpers
local function sorted(t, fmt)
	local keys = {}
	for k in t do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in keys do table.insert(out, string.format(fmt, tostring(k), t[k])) end
	return table.concat(out, ", ")
end
local function coverage()
	local n, hit = 0, 0
	for x = LAND.MinX + 4.5, LAND.MaxX, 9 do
		for z = LAND.MinZ + 4.5, LAND.MaxZ, 9 do
			if dressedSample(x, z) then
				n += 1
				if hasNear(x, z, 9) then hit += 1 end
			end
		end
	end
	return n > 0 and math.floor(hit / n * 100 + 0.5) or 0
end
local rejected = 0
for _, v in stats.Why do rejected += v end
local missingList = {}
for k in missing do table.insert(missingList, k) end
table.sort(missingList)
local groupOk = false
pcall(function() groupOk = PhysicsService:IsCollisionGroupRegistered(T.PlayerOnlyGroup) end)
local players = 0
for _, c in placed do
	if c.Coll == "player" then players += 1 end
end
local function shortHash(s) -- 6 hex digits of the long per-chunk PlanHash text, for the report
	local h = 7
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 16777213 end
	return string.format("%06x", h)
end
local planTag = terrainPlan or "none" -- stored on MeadowDress as PlanHash ("none" = the flat meadow)
local function terrainNote(built)
	local now = terrainPlan and ("terrain plan " .. shortHash(terrainPlan) .. (plateauTop and " (sculpted: crystal corner at the plateau foot)" or ""))
		or "terrain: flat (no MeadowTerrainStore PlanHash)"
	if not oldDress then return now end
	local fix = built and " -> rebuilt on this terrain now" or " -> re-run MODE kit"
	if type(oldPlan) ~= "string" then
		return now .. " | WARNING: the MeadowDress in place has no terrain record (built by an older run)" .. fix
	end
	if oldPlan ~= planTag then
		return now .. string.format(" | WARNING: the MeadowDress in place was grounded on terrain plan %s, not this one%s",
			oldPlan == "none" and "none (flat)" or shortHash(oldPlan), fix)
	end
	return now .. " (same as the dress in place)"
end
local lilyFlowers, lilyParts = 0, 0
for _, l in lily do
	lilyParts += l.Flower and 3 or 1
	if l.Flower then lilyFlowers += 1 end
end
local function summary(head, mapParts, built)
	return string.format("%s: %d pieces (%s) | trunk posts %d | by tier %s | player-only %d (%s) | rejected %d spots: %s"
		.. " | vignette misses: %s | missing kit: %s | caps: meadow total %d/%d (MeadowKit %d + JobBoard counted), tall boulders %d"
		.. " | meadow triangles %d / cap %d (MeadowKit + JobBoard %d) | edge reserve %d%% (tiers 1-2 stopped %d)"
		.. " | map parts %s / cap %d (room was %d, used %d) | lily pads %d (%d with a flower; %d parts) | dressed-band"
		.. " coverage r9 %d%% | lights added 0 | %s",
		head, #placed, sorted(stats.Made, "%s x%d"), used.Posts, sorted(stats.Tier, "%s:%d"), players,
		groupOk and "DecorPlayerOnly group" or "group not registered -> walk-through", rejected, sorted(stats.Why, "%s %d"),
		#stats.Failed > 0 and table.concat(stats.Failed, "; ") or "none",
		#missingList > 0 and table.concat(missingList, ",") or "none",
		used.Total + existingTotal + T.JobBoard, CAPS.Total + existingTotal + T.JobBoard, existingTotal, used.Tall,
		used.Tris + existingTris, T.TriCap, existingTris, math.floor(T.EdgeReserve * 100 + 0.5), stats.Why.reserve or 0,
		tostring(mapParts), partCap, room, used.Parts, #lily, lilyFlowers, lilyParts, coverage(), terrainNote(built))
		.. ((stats.Why.budget or 0) > 0 and string.format(" | NOTE: the map part cap left out %d spots (the lower tiers):"
			.. " for the full dress set T.PartCap to about %d", stats.Why.budget, baseParts + 600) or "")
		.. ((stats.Why.tris or 0) > 0 and string.format(" | NOTE: the meadow triangle cap left out %d spots (the lower tiers):"
			.. " decimate the most-repeated meshes (layout Phase 2) and lower their TRIS numbers", stats.Why.tris) or "")
end

------------------------------------------------------------------ plan / dry (read only)
if MODE == "plan" then
	local rows = {}
	for _, c in placed do
		table.insert(rows, string.format("%s,%.1f,%.1f,%.1f,%.0f,%d,%s", c.Name, c.X, c.Z, c.Canopy or c.R, c.Yaw, c.Tier, c.Coll))
	end
	for _, l in lily do
		table.insert(rows, string.format("LilyPad%s,%.1f,%.1f,%.1f,0,1,none", l.Flower and "Flower" or "", l.X, l.Z, l.D / 2))
	end
	return table.concat(rows, ";")
end
if MODE == "dry" then
	return summary("dry (nothing changed) MeadowDress would place", baseParts + used.Parts, false)
		.. string.format(" | would stash: PondStones %s, gate eyes %d", (pondStones and T.ReplacePondStones) and "yes" or "no", #eyes)
end

------------------------------------------------------------------ build (MODE "kit")
local backup = backupFolder(true)
local stashed = {}
if pondStones and T.ReplacePondStones then
	local prev = backup:FindFirstChild("PondStones")
	if prev then prev:Destroy() end -- an older copy (preview_map terrain mode makes a fresh ring each run)
	pondStones.Parent = backup
	table.insert(stashed, "PondStones")
end
for _, e in eyes do
	e:SetAttribute("MeadowDressFrom", gate:GetFullName())
	e.Parent = backup
end
if #eyes > 0 then table.insert(stashed, #eyes .. " gate eyes") end
if oldDress then oldDress:Destroy() end

local root = Instance.new("Model")
root.Name = "MeadowDress"
root:SetAttribute("PlanHash", planTag) -- the terrain plan every piece was grounded on (meadow_terrain's store)
local appliedAt = terrainStore and terrainStore:GetAttribute("AppliedAt")
if terrainPlan and type(appliedAt) == "string" then root:SetAttribute("TerrainAppliedAt", appliedAt) end
local big = Instance.new("Model")
big.Name = "Big"
big.Parent = root
local small = Instance.new("Model")
small.Name = "Small"
small.Parent = root
local cells = {}
local function sit(m, y) -- bottom on y
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, y - (cf.Position.Y - size.Y / 2), 0))
end
for _, c in placed do
	local m = kitModel(c.Name):Clone()
	m.Name = c.Name
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end -- A23-33: kit models never carry scripts
	end
	if math.abs(c.S - 1) > 1e-3 then pcall(m.ScaleTo, m, m:GetScale() * c.S) end
	m:PivotTo(CFrame.new(c.X, c.Y, c.Z) * CFrame.Angles(0, math.rad(c.Yaw), 0))
	sit(m, c.Y - 0.05 - c.Sink)
	if c.Tilt and c.N then -- lean onto the ground normal round the bottom centre (hill crown)
		local up = Vector3.yAxis
		local n = up:Lerp(c.N, c.Tilt).Unit
		local axis = up:Cross(n)
		if axis.Magnitude > 1e-4 then
			local rot = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(up:Dot(n), -1, 1)))
			local base = CFrame.new(c.X, c.Y - 0.05 - c.Sink, c.Z)
			m:PivotTo(base * rot * base:ToObjectSpace(m:GetPivot()))
		end
	end
	local playerOnly = c.Coll == "player" and groupOk
	local hard = c.Coll == "solid" or playerOnly
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = hard
			p.CanQuery = hard
			p.CanTouch = false
			p.CastShadow = c.Longest >= 4
			if playerOnly then p.CollisionGroup = T.PlayerOnlyGroup end
		end
	end
	if c.Coll == "player" then m:SetAttribute("DecorPlayerOnly", true) end
	m:SetAttribute("DressTier", c.Tier)
	if c.Tag then m:SetAttribute("DressTag", c.Tag) end
	if c.Tree then -- invisible trunk collider: players and monsters bump the trunk, never the leaves
		local t, s = KIND[c.Name].Tree, c.S
		local foot = m:GetPivot():PointToWorldSpace(Vector3.new(t.X * s, 0, t.Z * s))
		local h = math.max(T.PostH * s, T.PostMin)
		local post = Instance.new("Part")
		post.Name = "TrunkPost"
		post.Shape = Enum.PartType.Cylinder
		post.Size = Vector3.new(h, t.D * s, t.D * s)
		post.CFrame = CFrame.new(foot.X, c.Y + h / 2, foot.Z) * CFrame.Angles(0, 0, math.rad(90))
		post.Anchored, post.Transparency = true, 1
		post.CanCollide, post.CanQuery, post.CanTouch, post.CastShadow = true, true, false, false
		post.TopSurface, post.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		post:SetAttribute("Collider", true)
		post.Parent = m
	end
	if c.Small and c.Coll == "none" then
		local key = "Cell_" .. math.floor(c.X / T.Cell) .. "_" .. math.floor(c.Z / T.Cell)
		local cell = cells[key]
		if not cell then
			cell = Instance.new("Model")
			cell.Name = key
			cell.Parent = small
			cells[key] = cell
		end
		m.Parent = cell
	else
		m.Parent = big
	end
end
-- pond lily pads (pass 2): flat cylinders on the water, nothing collides / is queried / touched, no shadow
local function disc(name, x, y, z, d, h, rgb, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(h, d, d)
	p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)) -- the cylinder's axis (X) stands up
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
if #lily > 0 then
	local key = "Cell_" .. math.floor(PT.Pond.X / T.Cell) .. "_" .. math.floor(PT.Pond.Y / T.Cell)
	local cell = cells[key]
	if not cell then
		cell = Instance.new("Model")
		cell.Name = key
		cell.Parent = small
		cells[key] = cell
	end
	local pads = Instance.new("Model")
	pads.Name = "LilyPads"
	pads:SetAttribute("DressTier", 1)
	pads:SetAttribute("DressTag", "pondLily")
	for _, l in lily do -- bottom just under the water top, so the pad floats in the ripples
		disc("LilyPad", l.X, l.Y + 0.05, l.Z, l.D, 0.2, { 110, 190, 90 }, pads)
		local f = l.Flower
		if f then
			disc("LilyFlower", f.X, l.Y + 0.25, f.Z, f.D, 0.2, f.Pink and { 250, 170, 205 } or { 250, 250, 245 }, pads)
			disc("LilyFlowerHeart", f.X, l.Y + 0.3, f.Z, f.D * 0.35, 0.2, { 250, 215, 80 }, pads)
		end
	end
	pads.Parent = cell
end
root.Parent = decor
return summary("MeadowDress built", countParts(map), true)
	.. string.format(" | MeadowKit kept %d | stashed to ServerStorage.MeadowDressBackup: %s", meadowKit and #meadowKit:GetChildren() or 0,
		#stashed > 0 and table.concat(stashed, ", ") or "nothing")
