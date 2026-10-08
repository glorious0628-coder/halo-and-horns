-- meadow_terrain.luau (검수 workflow 2026-10-08, SPEC A23-76 — user: "앞으로 모든 장소들 다 시안 기준이야. 그리고 납작한 길
-- 안 되고 이렇게 언덕도 있고, 그래야 돼! 폭포도 있고. 아름답게!")
-- Studio MCP execute_luau, MAIN place (GoodEvil), Edit mode only. Reshapes the Squishy Meadow terrain toward
-- art/review/concept/Concept_SlimeMeadow.jpg: gentle rolling grass with low mounds in the hunting ground, higher knolls and
-- a rock outcrop only at the edges / corners, the King Slime Hill as a rock-sided hill (top Y 14) whose front face is a
-- 22-degree grass ramp with a dirt path up from the loop road, a rock plateau in the NE corner (top Y 26..35) with a
-- WATERFALL (anchored non-colliding water parts, scrolling beams, soft mist) into a plunge pool, a river along the cliff
-- foot into the east channel, and the three meadow roads painted into the terrain so they rise and fall with the ground.
-- Run this BEFORE tools/worldkit/meadow_dress.luau (props are grounded by rays on this terrain; nothing here reads props).
-- For the props tool the store keeps the spots as attributes: HillTop, HillPathFoot, PlateauTop, FallsLip, FallsPool,
-- SecretNook (dry ledge behind the falling water), RiverMouth, RiverLine ("x,z;x,z;..."), PathSlot.
--
-- Contracts kept (Config / MonsterService / ZoneService / MapBuilder, checked 2026-10-08):
--  * flat Y 0 round the arrival (230, 0) (root spawn at absolute Y 4, MeadowArrival kill radius 40, J10 radius 14, job
--    board anchor (230, 3, 12)), the woods bridge end / woods edge (650 / 636, 0), the pond (290, 150) basin + rim
--    (pond quests radius 30 / 40), the PumpkinPatchSign (525, 226) (bottom fixed at Y 0) and the whole z 240 seam with
--    the Halloween fields (MapBuilder checks: (535, 240) top <= 3, (535, 124.5) = Mud)
--  * every hunting column stays inside MonsterService GROUND_MIN_Y..GROUND_MAX_Y (-2..6) and gentle (players and slimes
--    MaxSlopeAngle 46); only the edge knolls, the hill and the plateau rise above 6 (no spawns there, like a ridge)
--  * the roads keep the Config.Map.Roads footprints (minimap / world map / meadow_dress read those rects): RoadMeadow
--    x 210..650 |z| <= 9, RoadMeadowLoop x 260..600 z -125..-115, RoadPumpkin x 529..541 (Mud) — painted a little
--    narrower than the rect with a gentle bend inside it, levelled across, following the hills along. The old flat road
--    parts (Decor.Roads RoadMeadow / RoadMeadowLoop) and the KingSlimeHill ball part go to the store's Hidden folder.
--  * the river crosses no road, so no new bridge; water parts are anchored, CanCollide / CanQuery / CanTouch false (so
--    MonsterService occupied() never sees them), no ray bursts (soft round mist puffs only)
--  * only the box x 208..688, z -268..240 (the meadow + its coast + the east channel at the river mouth) is ever written;
--    no other zone is touched
--
-- MODE (the runner replaces "__MODE__"; anything else = "apply"):
--   "apply"   build the meadow shape from the stored baseline (the first run stores the current flat terrain as baseline)
--   "plan"    compute only (no writes), return the numbers
--   "restore" write the baseline back, put every hidden piece back, remove the waterfall and the path tile slot
--   "rebase"  store the CURRENT terrain as the new baseline (only after tools/preview_map.lua "terrain" made it flat
--             again), then apply
-- Idempotent and deterministic: math.noise only, no random seeds. ServerStorage.MeadowTerrainStore keeps the baseline
-- (per 4x4 column: solid top + top material + water top, from ReadVoxelChannels), the last written result and a hash per
-- 64x64 chunk; a re-run rewrites only chunks whose plan or terrain changed and refuses (lists them) when someone else
-- edited terrain inside the box since the last run (set FORCE = true to overwrite such hand edits).
-- Offline check: build/luau_cli_0_741/luau.exe tools/worldkit/meadow_terrain.luau runs the plan on a synthetic flat
-- meadow and prints the numbers plus one "C,x,z,V,W,mat,tag" row per column (for a top-down check picture).

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" and MODE ~= "rebase" then MODE = "apply" end
local FORCE = false
local STUDIO = game ~= nil
if STUDIO and game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end

------------------------------------------------------------------ numbers
local G = {
	R = 4, Lift = 2, WaterTop = -1.2, -- tools/preview_map.lua T.Res / T.Lift (solid surface draws 2 above the voxels) / Config.Map.WaterTop
	X0 = 208, X1 = 688, Z0 = -268, Z1 = 240, Y0 = -28, Y1 = 44, Chunk = 16,
	Zone = { MinX = 210, MaxX = 650, MinZ = -240, MaxZ = 240 }, -- Config.Zones.SlimeMeadow = LandMeadow
	Inset = 25, GroundMin = -2, GroundMax = 6, -- MonsterService SpawnInset, GROUND_MIN_Y / GROUND_MAX_Y
	RockSlope = 35, RockySlope = 28, -- degrees: steeper feature ground shows Rock (GE_Rock), the rest Grass
	ForeignMax = 40, -- columns edited by someone else since the last run before the run stops (FORCE = false)
	FlatTol = 1.2, -- capture check: the baseline meadow must be flat (preview_map: Y 0) at the feature centres
}
G.NX, G.NZ, G.NY = (G.X1 - G.X0) / G.R, (G.Z1 - G.Z0) / G.R, (G.Y1 - G.Y0) / G.R
G.NCOL = G.NX * G.NZ
G.CX, G.CZ = math.ceil(G.NX / G.Chunk), math.ceil(G.NZ / G.Chunk)

-- flat spots { x, z, flat radius, full-height radius }: the interior and the knolls fade to the baseline here
local PINS = {
	{ 230, 0, 34, 72 }, -- arrival / gate / job board / first-mission ring
	{ 650, 0, 30, 66 }, -- woods bridge quay + woods edge (636, 0)
	{ 290, 150, 30, 54 }, -- slime pond basin + sand rim (kept exactly as preview_map made it)
	{ 525, 226, 10, 24 }, -- PumpkinPatchSign (MapBuilder: bottom at Y 0)
}
local EDGE = { I0 = 8, I1 = 34, K0 = 3, K1 = 16 } -- interior / knoll fade from the zone edge (coasts + the z 240 seam)
local ROLL = { Amp = 4.0, Gain = 1.4, Cap = 5.5 } -- rolling ground 0..Amp, mounds added, soft cap (hunting ground <= 5.5)
local MOUNDS = { -- grass hummocks { x, z, height, radius } (the concept's bumps), centres off the road rects
	{ 318, 58, 5.0, 26 }, { 392, 112, 5.5, 30 }, { 468, 58, 4.6, 24 }, { 356, -56, 5.4, 28 }, { 462, -66, 5.0, 26 },
	{ 590, 56, 4.8, 24 }, { 450, 186, 4.2, 26 }, { 360, 192, 4.0, 24 }, { 518, -170, 5.0, 24 }, { 300, -150, 4.2, 22 },
	{ 570, 128, 4.4, 22 }, { 600, -40, 4.2, 22 }, { 284, 92, 4.0, 22 },
}
local KNOLLS = { -- edge / corner highlands (no hunting lawn of meadow_dress lies under a part higher than 6)
	{ X = 246, Z = -212, H = 11, R = 40 }, -- NW lookout (kit_meadow M_Watchtower corner)
	{ X = 345, Z = -224, H = 8.5, R = 24, Rocky = true }, -- north-coast rock outcrop
	{ X = 238, Z = 202, H = 7, R = 32 }, -- SW corner
	{ X = 628, Z = 178, H = 8, R = 36 }, -- SE corner, east of the pumpkin path
	{ X = 628, Z = 82, H = 6, R = 28, Rocky = true }, -- east-coast rocks south of the woods bridge
	{ X = 236, Z = -98, H = 6, R = 30 }, -- west coast north of the arrival
	{ X = 234, Z = 104, H = 5, R = 28 }, -- west coast south of the arrival
}
-- King Slime Hill (kit_meadow M_KingHill (430, -170)): a round grass top (r <= TopR at Top), a rock band down to
-- Foot at CoreR (lumpy outline) and a grass skirt to SkirtR on the back and sides; the FACE toward the loop road
-- (direction Dir, full within +-Full, fading over Fade) is the ramp: an even grass slope Run long (about 22 deg) with a
-- dirt path up its middle (HW half width, Bend = its S-curve) from the loop road to the top (the concept's front path).
-- The band stays under the slimes' MaxSlopeAngle 46 all round (CoreR 26, half linear profile: about 44 deg at most), so
-- a monster walking straight at a player on the top still gets there (no safe spot); Rock shows only above RockSlope.
-- PathOut = studs past the ramp's foot the path runs on, so it meets the loop road's painted strip
local HILL = { X = 430, Z = -170, Top = 14, TopR = 10, CoreR = 26, Foot = 3, SkirtR = 38, Lumps = 0.1,
	Face = { Dir = math.rad(113), Full = math.rad(28), Fade = math.rad(26), Run = 34, PathHW = 4, Bend = 4, PathOut = 7 } }
-- NE rock plateau (superellipse mesas): cliff band CliffIn..CliffOut studs round the outline, grass talus beyond.
-- PL = the high block with the waterfall; SHOULDER = a lower rock step on its SE side above the river (layered cliffs)
-- Tilt = extra height toward the north (sea) side, Dome = extra height at the middle: the top rolls up behind the falls
-- like the concept's back hills (the lip itself stays at Top)
local PL = { X = 616, Z = -188, AX = 34, AZ = 48, P = 2.6, Scale = 40, Top = 26, TopNoise = 2.0, Wobble = 5, Tilt = 4,
	Dome = 5, CliffIn = 6, CliffOut = 3, Talus = 14, TalusTop = 6 }
local SHOULDER = { X = 640, Z = -152, AX = 22, AZ = 14, P = 2.4, Scale = 18, Top = 13, TopNoise = 0.8, Wobble = 2.5, Tilt = 0,
	Dome = 1.5, CliffIn = 3, CliffOut = 2, Talus = 10, TalusTop = 5 }
-- the waterfall on the plateau's SW face (faces the arrival and the crown road): a water channel on the top, a sheer
-- lip, a dry sand ledge behind the falling water (the "behind the waterfall" secret spot), the plunge pool in front.
-- The ledge is a swim-only secret: two rock arms (Fin*: FinW thick, FinV0 high at the lip to FinV1 at FinEnd) run from
-- the cliff beside the notch out into the pool water, and the pool / river banks never lower them, so no dry way leads
-- in from the meadow (only open water cuts an arm)
local FALLS = { DirX = -0.72, DirZ = 0.69, Band = 5.5, Fade = 2.5, Ledge = 8, LedgeV = 1.4, SheetA = 9.5, Width = 12,
	PoolA = 18, PoolR = 10.5, PoolW = 0.4, PoolDepth = 3.4, ChanHalf = 6, ChanBack = 18, ChanDrop = 2.4, ChanW = 1.0,
	FinW = 7, FinEnd = 15, FinV0 = 20, FinV1 = 13,
	BeamSpeed = 1.1 } -- BeamSpeed: flip the sign if the streaks run upward in Studio
-- the falling water's look: the approved tileable flow texture (Config.UIArt Tex_WaterfallFlow, flows top -> bottom)
-- on both faces of the sheet and on the curls' tops, over half-clear water tinted from Terrain.WaterColor; the moving
-- streak beams stay (a Texture cannot scroll in Edit). Top-face textures put the image top toward the part's front, so
-- the curls look upstream: set CurlFlip = true if the curl texture runs backward in Studio
local FALLS_LOOK = { Tex = "rbxassetid://86909517913668", TileU = 12, TileV = 15, TexTransparency = 0.25,
	Transparency = 0.3, Tint = 0.35, FoamTransparency = 0.15, CurlFlip = false, BeamOut = 1.9 }
-- the river: plunge pool -> along the plateau's south foot -> the east channel (x 650..710) north of the woods bridge
local RIVER = { Ctrl = { { 590, -140 }, { 606, -133 }, { 628, -128 }, { 650, -122 }, { 672, -118 }, { 700, -116 } },
	HW0 = 6, HW1 = 8.5, Depth = 2.6, Sand = 2.5, Bank = 8, Levee = 1.0, LeveeFall = 0.15 }
-- painted roads (inside the Config.Map.Roads rects): HW = painted half width, Bend = centre-line bend amplitude,
-- From..To = the stretch along the road that is levelled / painted (square ends at the rect ends, no round caps)
local ROADS = {
	{ Name = "RoadMeadow", Mat = "Path", HW = 8, Bend = 1, From = 210, To = 650, Mid = 0, AlongX = true },
	{ Name = "RoadMeadowLoop", Mat = "Path", HW = 4.5, Bend = 0.4, From = 260, To = 600, Mid = -120, AlongX = true },
	{ Name = "RoadPumpkin", Mat = "Mud", HW = 6, Bend = 0.6, From = 7, To = 246, Mid = 535, AlongX = false },
}
local LEVEL = 5 -- studs past a road's painted edge over which its levelled cross-section blends into the ground
-- path tile: terrain Ground shows GE_Ground (grey ruins dirt); the roads' own tile GE_DirtPath is only a part variant.
-- Use = true puts the approved GE_DirtPath ColorMap on a free terrain slot (first of Slots no part uses) as a base
-- override named Name, so the painted roads look like today's road strips. false = paint with terrain Ground.
local PATH_TILE = { Use = true, Name = "GE_MeadowPath", Source = "GE_DirtPath", ConfigKey = "Tex_DirtPath",
	Slots = { "Pavement", "Salt", "Sandstone" }, StudsPerTile = 16 }
local HIDE = { { "Decor", "KingSlimeHill" }, { "Decor", "Roads", "RoadMeadow" }, { "Decor", "Roads", "RoadMeadowLoop" } }

------------------------------------------------------------------ helpers
local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end
local function smooth(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end
local function lerp(a, b, t) return a + (b - a) * t end
local function cr(a0, a1, a2, a3, t) -- Catmull-Rom
	local t2 = t * t
	return 0.5 * (2 * a1 + (-a0 + a2) * t + (2 * a0 - 5 * a1 + 4 * a2 - a3) * t2 + (-a0 + 3 * a1 - 3 * a2 + a3) * t2 * t)
end
local function spline(ctrl, step) -- dense smooth polyline through the control points
	local out, n = {}, #ctrl
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = ctrl[math.max(1, i - 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(n, i + 2)]
		local m = math.max(1, math.ceil(math.sqrt((p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2) / step))
		for s = 0, m - 1 do
			local t = s / m
			table.insert(out, { cr(p0[1], p1[1], p2[1], p3[1], t), cr(p0[2], p1[2], p2[2], p3[2], t) })
		end
	end
	table.insert(out, { ctrl[n][1], ctrl[n][2] })
	return out
end
local function polyline(pts)
	local P = { Pts = pts, Cum = { 0 }, MinX = math.huge, MaxX = -math.huge, MinZ = math.huge, MaxZ = -math.huge }
	for i, p in pts do
		P.MinX, P.MaxX = math.min(P.MinX, p[1]), math.max(P.MaxX, p[1])
		P.MinZ, P.MaxZ = math.min(P.MinZ, p[2]), math.max(P.MaxZ, p[2])
		if i > 1 then
			local q = pts[i - 1]
			P.Cum[i] = P.Cum[i - 1] + math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2)
		end
	end
	P.Total = P.Cum[#pts]
	return P
end
-- nearest point: distance, arc fraction u (0..1), point x, z (math.huge when farther than reach from the bbox)
local function nearest(P, x, z, reach)
	if x < P.MinX - reach or x > P.MaxX + reach or z < P.MinZ - reach or z > P.MaxZ + reach then return math.huge, 0, x, z end
	local best, bu, bx, bz = math.huge, 0, x, z
	local pts = P.Pts
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ex, ez = b[1] - a[1], b[2] - a[2]
		local l2 = ex * ex + ez * ez
		local t = l2 > 0 and clamp01(((x - a[1]) * ex + (z - a[2]) * ez) / l2) or 0
		local qx, qz = a[1] + ex * t, a[2] + ez * t
		local d = (x - qx) ^ 2 + (z - qz) ^ 2
		if d < best then best, bu, bx, bz = d, P.Cum[i] + (P.Cum[i + 1] - P.Cum[i]) * t, qx, qz end
	end
	return math.sqrt(best), bu / math.max(P.Total, 1e-6), bx, bz
end

------------------------------------------------------------------ shape pieces (pure math; visual heights V)
local function pinFactor(x, z)
	local f = 1
	for _, p in PINS do
		local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
		if d < p[4] then f *= smooth((d - p[3]) / (p[4] - p[3])) end
	end
	return f
end
local function edgeDist(x, z)
	return math.min(x - G.Zone.MinX, G.Zone.MaxX - x, z - G.Zone.MinZ, G.Zone.MaxZ - z)
end
local function softcap(v, cap)
	local k = cap - 1.5
	if v <= k then return v end
	return k + 1.5 * (1 - math.exp(-(v - k) / 1.5))
end
local function interior(x, z)
	local n = 0.65 * math.noise(x / 95, z / 95, 3.1) + 0.35 * math.noise(x / 43, z / 43, 7.7)
	local h = ROLL.Amp * smooth(0.5 + ROLL.Gain * n)
	for _, m in MOUNDS do
		local r2 = ((x - m[1]) ^ 2 + (z - m[2]) ^ 2) / (m[4] * m[4])
		if r2 < 1 then h += m[3] * (1 - r2) ^ 2 end
	end
	return softcap(h, ROLL.Cap)
end
local function knolls(x, z)
	local best, rocky = 0, false
	for _, k in KNOLLS do
		local r = math.sqrt((x - k.X) ^ 2 + (z - k.Z) ^ 2) / k.R
		if r < 1 then
			local h
			if k.Rocky then
				h = k.H * (1 - smooth((r - 0.3) / 0.7)) * (1 + 0.12 * math.noise(x / 9, z / 9, k.H))
			else
				h = k.H * (1 - r * r) ^ 2
			end
			if h > best then best, rocky = h, k.Rocky == true end
		end
	end
	return best, rocky
end

local function hillCore(r)
	if r <= HILL.TopR then return HILL.Top + 0.6 * (1 - (r / HILL.TopR) ^ 2) end
	if r <= HILL.CoreR then -- the band: half linear, half smoothstep (no steep middle)
		local t = (r - HILL.TopR) / (HILL.CoreR - HILL.TopR)
		return HILL.Top - (HILL.Top - HILL.Foot) * (0.5 * t + 0.5 * smooth(t))
	end
	if r <= HILL.SkirtR then return HILL.Foot * (1 - smooth((r - HILL.CoreR) / (HILL.SkirtR - HILL.CoreR))) end
	return 0
end
local function hillFace(r) -- the even ramp slope (half linear, half smoothstep: no steep middle)
	if r <= HILL.TopR then return hillCore(r) end
	local t = clamp01((r - HILL.TopR) / HILL.Face.Run)
	return HILL.Top * (1 - (0.5 * t + 0.5 * smooth(t)))
end
local function hill(x, z) -- visual height above the flat meadow (0 outside), on the hill path?
	local F = HILL.Face
	local dx, dz = x - HILL.X, z - HILL.Z
	local r = math.sqrt(dx * dx + dz * dz)
	if r > math.max(HILL.TopR + F.Run + F.PathOut, HILL.SkirtR / (1 - HILL.Lumps)) + 1 then return 0, false end
	local v = hillCore(r * (1 + HILL.Lumps * math.noise(x / 14, z / 14, 6.6)))
	local da = (math.atan2(dz, dx) - F.Dir + math.pi) % (2 * math.pi) - math.pi -- angle from the face centre
	local w = 1 - smooth((math.abs(da) - F.Full) / F.Fade)
	if w > 0 then v = lerp(v, math.max(v, hillFace(r)), w) end
	local reach = HILL.TopR + F.Run + F.PathOut
	if r >= HILL.TopR - 3 and r <= reach then
		local off = F.Bend * math.sin(2 * math.pi * (r - HILL.TopR) / (reach - HILL.TopR))
		if math.abs(r * math.sin(da) - off) < F.PathHW and math.abs(da) < math.pi / 2 then return v, true end
	end
	return v, false
end

local function mesaG(M, x, z) -- ~ studs outside a mesa outline (negative inside)
	local fx, fz = math.abs(x - M.X) / M.AX, math.abs(z - M.Z) / M.AZ
	return ((fx ^ M.P + fz ^ M.P) ^ (1 / M.P) - 1) * M.Scale
end
-- the waterfall frame: P0 = the lip (top edge) on the ray from the plateau centre along Dir; a = out, b = sideways
do
	local l = math.sqrt(FALLS.DirX ^ 2 + FALLS.DirZ ^ 2)
	FALLS.NX, FALLS.NZ = FALLS.DirX / l, FALLS.DirZ / l
	FALLS.SX, FALLS.SZ = -FALLS.NZ, FALLS.NX
	local t = 0
	while mesaG(PL, PL.X + FALLS.NX * t, PL.Z + FALLS.NZ * t) < -PL.CliffIn and t < 200 do t += 0.25 end
	FALLS.P0X, FALLS.P0Z = PL.X + FALLS.NX * t, PL.Z + FALLS.NZ * t
	FALLS.QX, FALLS.QZ = FALLS.P0X + FALLS.NX * FALLS.PoolA, FALLS.P0Z + FALLS.NZ * FALLS.PoolA
	FALLS.WTop = PL.Top - FALLS.ChanW
end
local function fallsLocal(x, z)
	local px, pz = x - FALLS.P0X, z - FALLS.P0Z
	return px * FALLS.NX + pz * FALLS.NZ, px * FALLS.SX + pz * FALLS.SZ
end
local function mesa(M, x, z, vb, uneven) -- visual height or nil (outside), on the top? (uneven 0 = even outline)
	local g = mesaG(M, x, z)
	if g > M.CliffOut + M.Talus + M.Wobble then return nil, false end
	g += M.Wobble * math.noise(x / 26, z / 26, 4.4 + M.Top) * uneven
	local inner = clamp01(-g / M.Scale) -- 0 at the outline, 1 at the middle
	local top = M.Top + (M.TopNoise * math.noise(x / 30, z / 30, 9.1 + M.Top) + M.Tilt * smooth((M.Z - z) / M.AZ)
		+ M.Dome * smooth(inner * 2.2)) * uneven
	if g <= -M.CliffIn then return top, true end
	if g <= M.CliffOut then
		return top - (top - M.TalusTop) * smooth((g + M.CliffIn) / (M.CliffIn + M.CliffOut)), false
	end
	if g >= M.CliffOut + M.Talus then return nil, false end
	return vb + (M.TalusTop - vb) * (1 - smooth((g - M.CliffOut) / M.Talus)), false
end
local function plateau(x, z, vb)
	local v1, t1 = mesa(PL, x, z, vb, smooth((math.sqrt((x - FALLS.P0X) ^ 2 + (z - FALLS.P0Z) ^ 2) - 18) / 12))
	local v2, t2 = mesa(SHOULDER, x, z, vb, 1)
	if v2 and (v1 == nil or v2 > v1) then return v2, t2 end
	return v1, t1
end
local function falls(x, z, v) -- the lip, the top channel, the ledge behind the water and its rock arms: v', water top or nil, tag
	local a, b = fallsLocal(x, z)
	local ab = math.abs(b)
	local edge = FALLS.Band + FALLS.Fade
	if ab >= edge + FALLS.FinW or a < -FALLS.ChanBack - 8 or a >= FALLS.FinEnd then return v, nil, nil end
	local wb = 1 - smooth((ab - FALLS.Band) / FALLS.Fade)
	if a < 0 then
		if ab >= edge then return v, nil, nil end
		if ab < FALLS.ChanHalf and a > -FALLS.ChanBack then return PL.Top - FALLS.ChanDrop, FALLS.WTop, "chan" end
		return lerp(v, PL.Top, wb * (1 - smooth((-a - FALLS.ChanBack) / 8))), nil, "top"
	end
	-- the arms: never lower than the cliff already is, tapering from FinV0 at the lip to FinV1 at their pool end
	local wall = math.max(v, lerp(FALLS.FinV0, FALLS.FinV1, a / FALLS.FinEnd))
	if ab >= edge then return wall, nil, "fin" end
	if a >= FALLS.Ledge then return v, nil, nil end -- in front of the ledge, between the arms: the pool and its sand
	local lv = lerp(wall, FALLS.LedgeV, wb)
	return lv, nil, (wb > 0.5 and lv < FALLS.LedgeV + 2.5) and "ledge" or "cliff" -- the steep flank stays rock, not sand
end

local RIVER_LINE
do
	local ctrl = { { FALLS.QX, FALLS.QZ } }
	for _, p in RIVER.Ctrl do table.insert(ctrl, p) end
	RIVER_LINE = polyline(spline(ctrl, 4))
end
local function carve(d, hw, depth, W, land) -- a water channel across distance d from its centre: v, tag (nil = outside)
	if d < hw then return math.min(land, W - 0.3 - (depth - 0.3) * (1 - (d / hw) ^ 2)), "bed" end
	if d < hw + RIVER.Sand then return math.min(land, lerp(W - 0.3, W + 0.6, smooth((d - hw) / RIVER.Sand))), "sand" end
	if d < hw + RIVER.Sand + RIVER.Bank then
		return lerp(math.min(W + 0.6, land), land, smooth((d - hw - RIVER.Sand) / RIVER.Bank)), "bank"
	end
	return land, nil
end
local function water(x, z, land, kb) -- pool + river: v, water top or nil, tag
	local zone = RIVER.Sand + RIVER.Bank
	local reach = zone + 12
	local dq = math.sqrt((x - FALLS.QX) ^ 2 + (z - FALLS.QZ) ^ 2)
	local dr, u = nearest(RIVER_LINE, x, z, RIVER.HW1 + reach)
	local hw = lerp(RIVER.HW0, RIVER.HW1, u)
	local wr = lerp(FALLS.PoolW, G.WaterTop, smooth(u / 0.85))
	if dq > FALLS.PoolR + reach and dr > hw + reach then return land, nil, nil end
	-- inland the banks stand at least Levee above the water (fading out past the bank), never on the beach / sea
	local function levee(d, r, W) return W + RIVER.Levee - math.max(0, d - r - zone) * RIVER.LeveeFall end
	local l2 = land
	if dq < FALLS.PoolR + reach then l2 = math.max(l2, land + kb * math.max(0, levee(dq, FALLS.PoolR, FALLS.PoolW) - land)) end
	if dr < hw + reach then l2 = math.max(l2, land + kb * math.max(0, levee(dr, hw, wr) - land)) end
	local v, w, tag = l2, nil, nil
	local pv, ptag = carve(dq, FALLS.PoolR, FALLS.PoolDepth, FALLS.PoolW, l2)
	if ptag then v, w, tag = pv, FALLS.PoolW, ptag end
	local rv, rtag = carve(dr, hw, RIVER.Depth, wr, l2)
	if rtag then
		if tag == nil or rtag == "bed" or (rtag == "sand" and tag == "bank") then tag = rtag end
		v, w = math.min(v, rv), math.max(w or -math.huge, wr)
	end
	return v, w, tag
end

local ROAD_LINES = {}
for _, rd in ROADS do
	local pts, span = {}, rd.To - rd.From
	for s = 0, math.ceil(span / 4) do
		local t = math.min(span, s * 4)
		local along = rd.From + t
		-- the bend fades in / out over 40 studs at both ends (quays, gate, sign stay on the rect's centre line)
		local env = smooth(t / 40) * smooth((span - t) / 40)
		local off = rd.Mid + rd.Bend * math.sin(2 * math.pi * t / 186.7) * env
		table.insert(pts, rd.AlongX and { along, off } or { off, along })
	end
	table.insert(ROAD_LINES, { Road = rd, Line = polyline(pts) })
end

------------------------------------------------------------------ the plan (baseline -> new columns)
local function colX(i) return G.X0 + (i - 0.5) * G.R end
local function colZ(k) return G.Z0 + (k - 0.5) * G.R end
local function colIdx(i, k) return (i - 1) * G.NZ + k end

local function plan(base)
	local function baseV(x, z)
		local i = math.clamp(math.floor((x - G.X0) / G.R) + 1, 1, G.NX)
		local k = math.clamp(math.floor((z - G.Z0) / G.R) + 1, 1, G.NZ)
		return base.S[colIdx(i, k)] + G.Lift
	end
	local function field(x, z) -- ground before roads: visual height, water top, tag, baseline height
		local vb = baseV(x, z)
		local kb = clamp01((vb + 1.2) / 1.2) -- 1 inland, 0 on the beach / sea
		local pin = pinFactor(x, z)
		local d = edgeDist(x, z)
		local h, tag = interior(x, z) * smooth((d - EDGE.I0) / EDGE.I1) * pin, nil
		local kh, rocky = knolls(x, z)
		kh *= smooth((d - EDGE.K0) / EDGE.K1) * pin
		if kh > h and kh > 0.3 then h, tag = kh, rocky and "rocky" or "knoll" end
		local hv, ramp = hill(x, z)
		if hv > h and hv > 0.05 then
			h, tag = hv, ramp and "ramp" or "hill"
		elseif ramp then
			tag = "ramp" -- the path's foot past the ramp (hill height ~0) still shows as path, down to the loop road
		end
		local v = vb + kb * h
		local pv, top = plateau(x, z, vb)
		if pv and pv > v then v, tag = pv, top and "top" or "cliff" end
		local w
		local fv, fw, ftag = falls(x, z, v)
		if ftag then v, w, tag = fv, fw, ftag end
		if ftag ~= "top" and ftag ~= "chan" then -- the pool's banks never cut the lip: the falls stay a sheer drop
			local cv, cw, ctag = water(x, z, v, kb)
			if cw and ftag == "fin" then
				-- the rock arms keep their height: only open water (a bed) cuts them, never a sand rim or bank
				if ctag == "bed" then v, w, tag = cv, cw, ctag end
			elseif cw then
				v, w = cv, cw
				if ctag and not (ftag == "ledge" and ctag == "bank") then tag = ctag end
			end
		end
		return v, w, tag, vb
	end

	local V, W, Tag, VB = table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL)
	for i = 1, G.NX do
		local x = colX(i)
		for k = 1, G.NZ do
			local z = colZ(k)
			local idx = colIdx(i, k)
			local v, w, tag, vb = field(x, z)
			-- roads level and paint land only (never the sea past a bridge quay) and only between their ends (no round
			-- caps); the ramp's foot is levelled into the loop road. Every road in reach levels the column, the first one
			-- that paints it wins (the crown road over the pumpkin path at their joint, which still joins up)
			if tag ~= "bed" and tag ~= "sand" and tag ~= "chan" and tag ~= "ledge" and tag ~= "fin" and vb > G.WaterTop then
				for _, rl in ROAD_LINES do
					local rd = rl.Road
					local along = rd.AlongX and x or z
					local hw = rd.HW
					local d, _, px, pz = math.huge, 0, x, z
					if along >= rd.From and along <= rd.To then d, _, px, pz = nearest(rl.Line, x, z, hw + LEVEL) end
					if d < hw + LEVEL then
						local vc = field(px, pz)
						v = lerp(v, vc, 1 - smooth((d - hw) / LEVEL))
						-- soft painted edge: 0..1 stud inside the half width (never outside the Config rect)
						if d < hw - 1 + clamp01(0.5 + math.noise(x / 7, z / 7, 2.2)) then
							tag = "road:" .. rd.Mat
							break
						end
					end
				end
			end
			V[idx], W[idx], Tag[idx], VB[idx] = v, w, tag, vb
		end
	end

	-- slopes (degrees) and materials
	local S, M, Slope = table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL)
	for i = 1, G.NX do
		for k = 1, G.NZ do
			local idx = colIdx(i, k)
			local ia, ib = math.max(1, i - 1), math.min(G.NX, i + 1)
			local ka, kb = math.max(1, k - 1), math.min(G.NZ, k + 1)
			local gx = (V[colIdx(ib, k)] - V[colIdx(ia, k)]) / ((ib - ia) * G.R)
			local gz = (V[colIdx(i, kb)] - V[colIdx(i, ka)]) / ((kb - ka) * G.R)
			local sl = math.deg(math.atan(math.sqrt(gx * gx + gz * gz)))
			Slope[idx] = sl
			local tag, mat = Tag[idx], base.M[idx]
			if mat == "Mud" and colZ(k) < G.Zone.MaxZ then mat = "Grass" end -- the old straight pumpkin strip
			if tag == "bed" or tag == "sand" or tag == "ledge" then
				mat = "Sand"
			elseif tag == "chan" then
				mat = "Rock"
			elseif tag and V[idx] < G.WaterTop - 0.3 then
				-- a feature's foot under the sea level (talus, banks): keep the sea floor, no green stripes under water
				if mat == "Grass" or mat == "Mud" then mat = "Sand" end
			elseif tag == "ramp" then
				mat = "Path"
			elseif tag and string.sub(tag, 1, 5) == "road:" then
				mat = string.sub(tag, 6)
			elseif tag then
				mat = sl > (tag == "rocky" and G.RockySlope or G.RockSlope) and "Rock" or "Grass"
			elseif V[idx] - VB[idx] > 0.3 and mat ~= "Sand" then
				mat = sl > G.RockSlope + 5 and "Rock" or "Grass"
			end
			S[idx], M[idx] = V[idx] - G.Lift, mat
		end
	end
	return { V = V, S = S, M = M, W = W, Tag = Tag, VB = VB, Slope = Slope }
end

------------------------------------------------------------------ numbers for the report
local function sampleAt(P, x, z)
	local i = math.clamp(math.floor((x - G.X0) / G.R) + 1, 1, G.NX)
	local k = math.clamp(math.floor((z - G.Z0) / G.R) + 1, 1, G.NZ)
	local idx = colIdx(i, k)
	return P.V[idx], P.M[idx], P.W[idx]
end
local function stats(P, base)
	local st = { Changed = 0, Cells = 0, Valid = 0, Inset = 0, Slopes = {}, RoadMax = 0, Water = 0 }
	for i = 1, G.NX do
		local x = colX(i)
		for k = 1, G.NZ do
			local z = colZ(k)
			local idx = colIdx(i, k)
			local dS = math.abs(P.S[idx] - base.S[idx])
			if dS > 0.05 or P.M[idx] ~= base.M[idx] or (P.W[idx] and P.W[idx] > P.S[idx] + G.Lift) then
				st.Changed += 1
				st.Cells += math.max(1, math.ceil(dS / G.R))
			end
			local v, w = P.V[idx], P.W[idx] or G.WaterTop
			if w > v then st.Water += 1 end
			if x > G.Zone.MinX + G.Inset and x < G.Zone.MaxX - G.Inset and z > G.Zone.MinZ + G.Inset and z < G.Zone.MaxZ - G.Inset then
				st.Inset += 1
				if v >= G.GroundMin and v <= G.GroundMax and w <= v then
					st.Valid += 1
					table.insert(st.Slopes, P.Slope[idx])
				end
			end
			local tag = P.Tag[idx]
			if tag and string.sub(tag, 1, 5) == "road:" then st.RoadMax = math.max(st.RoadMax, P.Slope[idx]) end
		end
	end
	table.sort(st.Slopes)
	local n = #st.Slopes
	st.SlopeMax = n > 0 and st.Slopes[n] or 0
	st.SlopeP95 = n > 0 and st.Slopes[math.max(1, math.floor(n * 0.95))] or 0
	st.SlopeP99 = n > 0 and st.Slopes[math.max(1, math.floor(n * 0.99))] or 0
	st.RampDeg = math.deg(math.atan(HILL.Top / HILL.Face.Run))
	local function at(x, z)
		local v, m = sampleAt(P, x, z)
		return string.format("%.1f%s", v, m == "Grass" and "" or ("/" .. tostring(m)))
	end
	st.Contract = string.format("arrival %s, board %s, woods quay %s / edge %s, pond rim %s, sign %s, patch seam %s, pumpkin check %s",
		at(230, 0), at(230, 12), at(648, 0), at(636, 0), at(290, 126), at(525, 226), at(535, 238), at(535, 124.5))
	return st
end
local function report(P, st, extra)
	return string.format("meadow terrain %s: %d columns changed (~%d voxels); hills: King %d (ramp %.0f deg) + plateau %d + %d knolls + %d mounds; "
		.. "river %.0f studs (%d water columns), falls %.0f studs high; hunting ground %.0f%% walkable (slope max %.0f, p99 %.0f, p95 %.0f deg), "
		.. "roads max %.0f deg; %s%s",
		MODE, st.Changed, st.Cells, HILL.Top, st.RampDeg, PL.Top, #KNOLLS, #MOUNDS, RIVER_LINE.Total, st.Water,
		FALLS.WTop - FALLS.PoolW, 100 * st.Valid / math.max(1, st.Inset), st.SlopeMax, st.SlopeP99, st.SlopeP95, st.RoadMax,
		st.Contract, extra or "")
end

------------------------------------------------------------------ offline (luau.exe): synthetic flat meadow, dump
if not STUDIO then
	local base = { S = table.create(G.NCOL), M = table.create(G.NCOL) }
	for i = 1, G.NX do
		local x = colX(i)
		for k = 1, G.NZ do
			local z = colZ(k)
			-- preview_map: land rect with 60-stud round corners (the z 240 side runs on into the fields), a noisy coast
			-- 2..23 studs out, a 12-stud beach, pinned quays (3 out, 2.5 beach) at the two bridge ends
			local qx = math.abs(x - 430) - (220 - 60)
			local qz = math.abs(z - 160) - (400 - 60)
			local din = -(math.sqrt(math.max(qx, 0) ^ 2 + math.max(qz, 0) ^ 2) + math.min(math.max(qx, qz), 0) - 60)
			local out = math.max(2, 9 + 14 * (math.noise(x / 110, z / 110, 1.7) + 0.45 * math.noise(x / 47, z / 47, 8.3)))
			local pinW = 1
			for _, e in { { 210, 0 }, { 650, 0 } } do
				pinW = math.min(pinW, smooth((math.sqrt((x - e[1]) ^ 2 + (z - e[2]) ^ 2) - 16) / 30))
			end
			out = 3 + (out - 3) * pinW
			local beach = 2.5 + 9.5 * pinW
			local inland = din + out
			local v, mat
			if inland >= beach then
				v, mat = 0, "Grass"
			elseif inland >= 0 then
				v, mat = -2.4 + 2.4 * smooth(inland / beach), inland < 11 and "Sand" or "Grass"
			else
				v, mat = math.max(-20, -2.4 + inland * 0.32), "Sand"
			end
			local r = math.sqrt((x - 290) ^ 2 + (z - 150) ^ 2)
			if r <= 18 then
				v, mat = -4.5 + 2.7 * (r / 18) ^ 2, "Sand"
			elseif r < 25 then
				v = math.min(v, -1.8 + 1.8 * smooth((r - 18) / 7))
				if r < 22.2 then mat = "Sand" end
			end
			if mat == "Grass" and x >= 529 and x <= 541 and z >= 9 then mat = "Mud" end
			base.S[colIdx(i, k)], base.M[colIdx(i, k)] = v - G.Lift, mat
		end
	end
	local P = plan(base)
	print(report(P, stats(P, base)))
	print(string.format("P0 %.1f %.1f Q %.1f %.1f", FALLS.P0X, FALLS.P0Z, FALLS.QX, FALLS.QZ))
	local rows = {}
	for i = 1, G.NX do
		for k = 1, G.NZ do
			local idx = colIdx(i, k)
			table.insert(rows, string.format("C,%g,%g,%.2f,%s,%s,%s", colX(i), colZ(k), P.V[idx],
				P.W[idx] and string.format("%.2f", P.W[idx]) or "-", P.M[idx], P.Tag[idx] or "-"))
		end
	end
	print(table.concat(rows, "\n"))
	return "offline plan"
end

------------------------------------------------------------------ Studio: store, read, write
local SS = game:GetService("ServerStorage")
local Terrain = workspace.Terrain
local AIR = Enum.Material.Air
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local DEC = {}
for p = 1, 64 do DEC[string.byte(B64, p)] = p - 1 end
local function enc2(q)
	q = math.clamp(math.floor(q + 0.5), 0, 4095)
	return string.sub(B64, q // 64 + 1, q // 64 + 1) .. string.sub(B64, q % 64 + 1, q % 64 + 1)
end
local function dec2(s, p) return DEC[string.byte(s, p)] * 64 + DEC[string.byte(s, p + 1)] end

-- a summary = per column S (solid top in voxel space), M (top material name), L (water top or false)
local function encode(sum)
	local palette, pIdx, parts = {}, {}, table.create(G.NCOL)
	for idx = 1, G.NCOL do
		local m = sum.M[idx]
		if not pIdx[m] then
			table.insert(palette, m)
			pIdx[m] = #palette - 1
		end
		local L = sum.L[idx]
		parts[idx] = enc2((sum.S[idx] - G.Y0) * 20) .. string.sub(B64, pIdx[m] + 1, pIdx[m] + 1)
			.. enc2(L and ((L - G.Y0) * 20 + 1) or 0)
	end
	assert(#palette <= 64, "too many materials in the meadow box")
	return table.concat(parts), table.concat(palette, ",")
end
local function decode(s, paletteText)
	local palette = string.split(paletteText, ",")
	local sum = { S = table.create(G.NCOL), M = table.create(G.NCOL), L = table.create(G.NCOL) }
	assert(#s == G.NCOL * 5, "stored terrain summary has the wrong size")
	for idx = 1, G.NCOL do
		local p = (idx - 1) * 5 + 1
		sum.S[idx] = dec2(s, p) / 20 + G.Y0
		sum.M[idx] = palette[DEC[string.byte(s, p + 2)] + 1]
		local lq = dec2(s, p + 3)
		sum.L[idx] = lq > 0 and ((lq - 1) / 20 + G.Y0) or false
	end
	return sum
end
local function sameCol(a, b, idx)
	if math.abs(a.S[idx] - b.S[idx]) > 0.15 or a.M[idx] ~= b.M[idx] then return false end
	local la, lb = a.L[idx], b.L[idx]
	if la == false or lb == false then return la == lb end
	return math.abs(la - lb) <= 0.3
end

local function readSummary()
	local region = Region3.new(Vector3.new(G.X0, G.Y0, G.Z0), Vector3.new(G.X1, G.Y1, G.Z1))
	local sm, so, lo
	local ok, ch = pcall(function()
		return Terrain:ReadVoxelChannels(region, G.R, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	end)
	if ok and type(ch) == "table" and ch.SolidOccupancy then
		sm, so, lo = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
	else
		sm, so = Terrain:ReadVoxels(region, G.R)
	end
	local sum = { S = table.create(G.NCOL), M = table.create(G.NCOL), L = table.create(G.NCOL) }
	for i = 1, G.NX do
		local smI, soI, loI = sm[i], so[i], lo and lo[i]
		for k = 1, G.NZ do
			local total, mHi, mLo, lt = 0, nil, nil, false
			for j = 1, G.NY do
				local mat, o = smI[j][k], soI[j][k]
				local l = loI and loI[j][k] or 0
				if mat == Enum.Material.Water then
					l, o = (loI and l or o), 0
				elseif mat == AIR then
					o = 0
				end
				total += o
				if o > 0.02 then mLo = mat end
				if o >= 0.25 then mHi = mat end
				if l > 0.02 then lt = G.Y0 + (j - 0.5) * G.R + G.R * (l - 0.5) end
			end
			local idx = colIdx(i, k)
			sum.S[idx] = G.Y0 + G.R * total
			sum.M[idx] = (mHi or mLo or AIR).Name
			sum.L[idx] = lt
		end
	end
	return sum
end

local MAT_CACHE = {}
local function matEnum(name)
	local m = MAT_CACHE[name]
	if not m then
		local ok, e = pcall(function() return Enum.Material[name] end)
		m = ok and e or Enum.Material.Grass
		MAT_CACHE[name] = m
	end
	return m
end
local useChannels = true
local function writeChunk(ci, ck, colFn) -- colFn(idx) -> S, material enum, water top
	local i0, k0 = (ci - 1) * G.Chunk + 1, (ck - 1) * G.Chunk + 1
	local i1, k1 = math.min(G.NX, i0 + G.Chunk - 1), math.min(G.NZ, k0 + G.Chunk - 1)
	local ni, nk = i1 - i0 + 1, k1 - k0 + 1
	local sm, so, lo = table.create(ni), table.create(ni), table.create(ni)
	for a = 1, ni do
		local mI, oI, lI = table.create(G.NY), table.create(G.NY), table.create(G.NY)
		for j = 1, G.NY do mI[j], oI[j], lI[j] = table.create(nk), table.create(nk), table.create(nk) end
		for c = 1, nk do
			local S, mat, W = colFn(colIdx(i0 + a - 1, k0 + c - 1))
			for j = 1, G.NY do
				local cy = G.Y0 + (j - 0.5) * G.R
				local occ = clamp01((S - cy) / G.R + 0.5)
				local lw = occ < 1 and clamp01((W - cy) / G.R + 0.5) or 0
				if useChannels then
					mI[j][c], oI[j][c], lI[j][c] = occ > 0 and mat or AIR, occ, lw
				elseif occ >= 0.5 or lw <= 0 then
					mI[j][c], oI[j][c] = occ > 0 and mat or AIR, occ
				else
					mI[j][c], oI[j][c] = Enum.Material.Water, lw
				end
			end
		end
		sm[a], so[a], lo[a] = mI, oI, lI
	end
	local region = Region3.new(Vector3.new(G.X0 + (i0 - 1) * G.R, G.Y0, G.Z0 + (k0 - 1) * G.R),
		Vector3.new(G.X0 + i1 * G.R, G.Y1, G.Z0 + k1 * G.R))
	if useChannels then
		local ok = pcall(function()
			Terrain:WriteVoxelChannels(region, G.R, { SolidMaterial = sm, SolidOccupancy = so, LiquidOccupancy = lo })
		end)
		if ok then return end
		useChannels = false -- this Studio has no channel API: the same chunk again as plain voxels
		writeChunk(ci, ck, colFn)
		return
	end
	Terrain:WriteVoxels(region, G.R, sm, so)
end
local function chunkOf(idx)
	local i, k = (idx - 1) // G.NZ + 1, (idx - 1) % G.NZ + 1
	return ((i - 1) // G.Chunk) * G.CZ + ((k - 1) // G.Chunk) + 1
end
local function chunkCR(c) return (c - 1) // G.CZ + 1, (c - 1) % G.CZ + 1 end

local store = SS:FindFirstChild("MeadowTerrainStore")
local function getStore()
	if not store then
		store = Instance.new("Folder")
		store.Name = "MeadowTerrainStore"
		store:SetAttribute("Box", string.format("%d,%d,%d,%d,%d,%d,%d", G.X0, G.X1, G.Z0, G.Z1, G.Y0, G.Y1, G.R))
		store.Parent = SS
	end
	return store
end
-- long texts are kept as StringValues name_1, name_2, ... of at most PIECE characters (StringValue length limit)
local PIECE = 40000
local function storeText(name)
	local n = store and store:GetAttribute(name .. "Pieces")
	if type(n) ~= "number" or n < 1 then return nil end
	local parts = {}
	for p = 1, n do
		local v = store:FindFirstChild(name .. "_" .. p)
		if not (v and v:IsA("StringValue")) then return nil end
		parts[p] = v.Value
	end
	return table.concat(parts)
end
local function setStoreText(name, text)
	local st = getStore()
	text = text or ""
	local n = math.ceil(#text / PIECE)
	for p = 1, n do
		local v = st:FindFirstChild(name .. "_" .. p)
		if not v then
			v = Instance.new("StringValue")
			v.Name = name .. "_" .. p
			v.Parent = st
		end
		v.Value = string.sub(text, (p - 1) * PIECE + 1, p * PIECE)
	end
	local old = st:GetAttribute(name .. "Pieces")
	for p = n + 1, (type(old) == "number" and old or 0) do
		local v = st:FindFirstChild(name .. "_" .. p)
		if v then v:Destroy() end
	end
	st:SetAttribute(name .. "Pieces", n)
end
local function saveSummary(name, sum)
	local text, palette = encode(sum)
	setStoreText(name, text)
	store:SetAttribute(name .. "Palette", palette)
end
local function loadSummary(name)
	local text = storeText(name)
	if not text then return nil end
	return decode(text, store:GetAttribute(name .. "Palette") or "")
end

if store then
	assert(store:GetAttribute("Box") == string.format("%d,%d,%d,%d,%d,%d,%d", G.X0, G.X1, G.Z0, G.Z1, G.Y0, G.Y1, G.R),
		"MeadowTerrainStore was made for another box: restore with the old script first, or delete the store after preview_map terrain")
end

local skipped = {}
local cur = readSummary()
local function flatCheck(sum)
	local bad = {}
	for _, p in { { 430, -170 }, { 616, -188 }, { 246, -212 }, { 400, 100 }, { 480, -60 }, { 628, 178 }, { 345, -224 }, { 598, -134 } } do
		local i = math.floor((p[1] - G.X0) / G.R) + 1
		local k = math.floor((p[2] - G.Z0) / G.R) + 1
		local v = sum.S[colIdx(i, k)] + G.Lift
		if math.abs(v) > G.FlatTol then table.insert(bad, string.format("(%d, %d) Y %.1f", p[1], p[2], v)) end
	end
	return bad
end

local base = loadSummary("Base")
if MODE == "rebase" or (base == nil and MODE ~= "restore") then
	local bad = flatCheck(cur)
	if #bad > 0 then
		error("meadow terrain is not the flat preview_map baseline (" .. table.concat(bad, ", ")
			.. "): run py tools/map_v2_apply.py terrain first (or MODE restore with the stored baseline)")
	end
	base = cur
	if MODE ~= "plan" then
		saveSummary("Base", base)
		setStoreText("Last", nil)
		store:SetAttribute("PlanHash", nil)
		store:SetAttribute("CapturedAt", DateTime.now():ToIsoDate())
	end
end
assert(base, "no stored baseline: nothing to restore")
local last = loadSummary("Last")

-- someone else's terrain edits inside the box since the last run (neither our last result nor the baseline)?
local foreign, foreignChunks = 0, {}
for idx = 1, G.NCOL do
	if not ((last and sameCol(cur, last, idx)) or sameCol(cur, base, idx)) then
		foreign += 1
		local c = chunkOf(idx)
		foreignChunks[c] = (foreignChunks[c] or 0) + 1
	end
end
if foreign > G.ForeignMax and not FORCE and MODE ~= "plan" then
	local list = {}
	for c, n in foreignChunks do
		local ci, ck = chunkCR(c)
		table.insert(list, string.format("x %d..%d z %d..%d: %d", G.X0 + (ci - 1) * G.Chunk * G.R, G.X0 + ci * G.Chunk * G.R,
			G.Z0 + (ck - 1) * G.Chunk * G.R, G.Z0 + ck * G.Chunk * G.R, n))
	end
	error(string.format("%d meadow columns were edited outside this tool since its last run (%s); nothing written. "
		.. "Set FORCE = true to overwrite them, or MODE rebase after preview_map terrain", foreign, table.concat(list, " | ")))
end
if foreign > 0 then table.insert(skipped, foreign .. " foreign columns " .. (FORCE and "overwritten" or "seen")) end

------------------------------------------------------------------ moved pieces (Hidden), path tile, waterfall, MeadowKit
local mapRoot = workspace:FindFirstChild("Map")
local function hiddenFolder()
	local h = getStore():FindFirstChild("Hidden")
	if not h then
		h = Instance.new("Folder")
		h.Name = "Hidden"
		h.Parent = store
	end
	return h
end
local function resolve(path, upto)
	local node = mapRoot
	for n = 1, upto do
		node = node and node:FindFirstChild(path[n])
	end
	return node
end
local function hidePieces()
	local moved = 0
	for _, path in HIDE do
		local live = resolve(path, #path)
		if live then
			local key = table.concat(path, "/")
			local kept = nil
			for _, h in hiddenFolder():GetChildren() do
				if h:GetAttribute("MT_From") == key then kept = h end
			end
			if kept then
				live:Destroy() -- a rebuilt copy (preview_map terrain) of a piece already kept here
			else
				live:SetAttribute("MT_From", key)
				live.Parent = hiddenFolder()
			end
			moved += 1
		end
	end
	return moved
end
local function unhidePieces()
	local back, left = 0, 0
	local h = store and store:FindFirstChild("Hidden")
	for _, inst in (h and h:GetChildren() or {}) do
		local key = inst:GetAttribute("MT_From")
		local path = type(key) == "string" and string.split(key, "/") or {}
		local parent = #path > 0 and resolve(path, #path - 1) or nil
		if parent and (inst:GetAttribute("MT_Multi") or not parent:FindFirstChild(inst.Name)) then
			inst:SetAttribute("MT_From", nil)
			inst:SetAttribute("MT_Multi", nil)
			local orig = inst:GetAttribute("MT_OrigPivot")
			inst.Parent = parent
			if typeof(orig) == "CFrame" then
				inst:PivotTo(orig)
				inst:SetAttribute("MT_OrigPivot", nil)
			end
			back += 1
		else
			left += 1
		end
	end
	return back, left
end

local function partsUse(mat)
	for _, root in { workspace, SS, game:GetService("ReplicatedStorage") } do
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.Material == mat then return true end
		end
	end
	return false
end
local function pathSlot()
	if not PATH_TILE.Use then return "Ground", "Ground (tile off)" end
	local MS = game:GetService("MaterialService")
	local src = MS:FindFirstChild(PATH_TILE.Source)
	local colorMap = (src and src:IsA("MaterialVariant")) and src.ColorMap or ""
	if colorMap == "" then
		local ok, Config = pcall(function() return require(game:GetService("ReplicatedStorage").Shared.Config) end)
		local p = ok and type(Config) == "table" and Config.UIArt and Config.UIArt.Parts and Config.UIArt.Parts[PATH_TILE.ConfigKey]
		colorMap = type(p) == "table" and type(p.Id) == "string" and p.Id or ""
	end
	if colorMap == "" then return "Ground", "Ground (no DirtPath tile)" end
	for _, name in PATH_TILE.Slots do
		local slot = Enum.Material[name]
		local current = MS:GetBaseMaterialOverride(slot)
		if current == PATH_TILE.Name or ((current == "" or current == nil) and not partsUse(slot)) then
			local v = MS:FindFirstChild(PATH_TILE.Name)
			if v and (not v:IsA("MaterialVariant") or v.BaseMaterial ~= slot) then
				v:Destroy()
				v = nil
			end
			if not v then
				v = Instance.new("MaterialVariant")
				v.Name = PATH_TILE.Name
				v.BaseMaterial = slot
				v.Parent = MS
			end
			v.ColorMap = colorMap
			v.StudsPerTile = PATH_TILE.StudsPerTile
			MS:SetBaseMaterialOverride(slot, PATH_TILE.Name)
			Terrain:SetMaterialColor(slot, Color3.fromRGB(235, 235, 235))
			getStore():SetAttribute("PathSlot", name)
			return name, name .. " = " .. PATH_TILE.Source .. " tile"
		end
	end
	return "Ground", "Ground (no free terrain slot)"
end
local function dropPathSlot()
	local name = store and store:GetAttribute("PathSlot")
	if type(name) ~= "string" then return end
	local MS = game:GetService("MaterialService")
	local slot = Enum.Material[name]
	if MS:GetBaseMaterialOverride(slot) == PATH_TILE.Name then MS:SetBaseMaterialOverride(slot, "") end
	local v = MS:FindFirstChild(PATH_TILE.Name)
	if v then v:Destroy() end
	store:SetAttribute("PathSlot", nil)
end

local FALLS_NAME = "MeadowWaterfall"
local function buildFalls()
	local decor = mapRoot and mapRoot:FindFirstChild("Decor")
	if not decor then
		table.insert(skipped, "waterfall (no Map.Decor)")
		return 0
	end
	local old = decor:FindFirstChild(FALLS_NAME)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = FALLS_NAME
	local n = Vector3.new(FALLS.NX, 0, FALLS.NZ)
	local s = Vector3.new(FALLS.SX, 0, FALLS.SZ)
	local p0 = Vector3.new(FALLS.P0X, 0, FALLS.P0Z)
	local function at(a, y, b) return p0 + n * a + s * b + Vector3.new(0, y, 0) end
	local count = 0
	local function piece(name, size, cf, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size, p.CFrame, p.Color = size, cf, color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		count += 1
		return p
	end
	-- half-clear water tinted from the terrain water (one look with the pool), white foam
	local okTint, terrainWater = pcall(function() return Terrain.WaterColor end)
	local WATER = (okTint and typeof(terrainWater) == "Color3" and terrainWater or Color3.fromRGB(8, 181, 214))
		:Lerp(Color3.new(1, 1, 1), FALLS_LOOK.Tint)
	local FOAM = Color3.fromRGB(245, 252, 255)
	local function flowTex(p, face) -- the tileable flow texture (image top = upstream), soft
		local t = Instance.new("Texture")
		t.Name = "Flow" .. face.Name
		t.Texture = FALLS_LOOK.Tex
		t.Face = face
		t.StudsPerTileU, t.StudsPerTileV = FALLS_LOOK.TileU, FALLS_LOOK.TileV
		t.Transparency = FALLS_LOOK.TexTransparency
		t.Parent = p
	end
	local wt, wp = FALLS.WTop, FALLS.PoolW
	-- the water curling over the lip (slabs from the top channel out to the sheet), texture on the top face
	local curl = { { -2.5, wt + 0.15 }, { 2.0, wt - 0.1 }, { 5.6, wt - 1.3 }, { 7.8, wt - 3.4 }, { FALLS.SheetA, wt - 5.5 } }
	for c = 1, #curl - 1 do
		local p, q = at(curl[c][1], curl[c][2], 0), at(curl[c + 1][1], curl[c + 1][2], 0)
		local slab = piece("FallsCurl" .. c, Vector3.new(FALLS.Width, 0.9, (q - p).Magnitude + 0.6),
			CFrame.lookAt((p + q) / 2, FALLS_LOOK.CurlFlip and q or p), WATER) -- front = upstream (same slab either way)
		slab.Transparency = FALLS_LOOK.Transparency
		flowTex(slab, Enum.NormalId.Top)
	end
	local top, bottom = wt - 5.5, wp - 0.4
	local mid = at(FALLS.SheetA, (top + bottom) / 2, 0)
	local sheet = piece("FallsSheet", Vector3.new(FALLS.Width, top - bottom, 0.9), CFrame.lookAt(mid, mid + n), WATER)
	sheet.Transparency = FALLS_LOOK.Transparency
	flowTex(sheet, Enum.NormalId.Front) -- toward the meadow
	flowTex(sheet, Enum.NormalId.Back) -- toward the secret ledge behind the water
	-- foam puffs where the water lands (flattened white spheres on the pool: a Ball part keeps equal axes, so a block
	-- with a sphere mesh)
	for f, spec in { { 0.3, -4.0, 5.0, 3.8 }, { 1.0, 0.2, 6.0, 4.4 }, { 0.1, 4.2, 4.8, 3.6 } } do
		local c = at(FALLS.SheetA + spec[1], wp + 0.05, spec[2])
		local foam = piece("FallsFoam" .. f, Vector3.new(spec[3], 1.1, spec[4]), CFrame.lookAt(c, c + n), FOAM)
		foam.Transparency = FALLS_LOOK.FoamTransparency
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = foam
	end
	-- moving streaks: camera-facing textured beams down the sheet (scrolling built-in smoke texture), BeamOut in front
	-- of the sheet's centre so a beam turned toward the camera (half width up to 1.4) never cuts into the sheet
	local anchor = piece("FallsAnchor", Vector3.new(1, 1, 1), CFrame.new(mid), WATER)
	anchor.Transparency = 1
	for bIdx = 1, 4 do
		local b = (FALLS.Width / 2 - 1.4) * (2 * (bIdx - 1) / 3 - 1)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "StreakTop" .. bIdx, "StreakBottom" .. bIdx
		a0.Parent, a1.Parent = anchor, anchor
		a0.WorldPosition = at(FALLS.SheetA + FALLS_LOOK.BeamOut, top - 0.3, b)
		a1.WorldPosition = at(FALLS.SheetA + FALLS_LOOK.BeamOut, bottom + 0.6, b)
		local beam = Instance.new("Beam")
		beam.Name = "Streak" .. bIdx
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 6 + bIdx
		beam.TextureSpeed = FALLS.BeamSpeed * (0.85 + 0.12 * bIdx)
		beam.Width0, beam.Width1 = 2.2, 2.8
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 245, 255))
		beam.Transparency = NumberSequence.new(0.3, 0.5)
		beam.LightEmission, beam.LightInfluence = 0.3, 0.5
		beam.ZOffset = 0.3
		beam.Parent = anchor
	end
	-- soft mist puffs rising from the splash + a few droplets (round sprites, no rays)
	local mist = piece("FallsMist", Vector3.new(FALLS.Width + 2, 1, 4), CFrame.lookAt(at(FALLS.SheetA + 0.5, wp + 0.4, 0),
		at(FALLS.SheetA + 1.5, wp + 0.4, 0)), WATER)
	mist.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Mist"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.8, 3)
	e.Rate = 9
	e.Speed = NumberRange.new(2, 4.5)
	e.SpreadAngle = Vector2.new(30, 30)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 0.8, 0)
	e.Drag = 0.8
	e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-15, 15)
	e.LightEmission, e.LightInfluence = 0.15, 0.6
	pcall(function()
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end)
	e.Parent = mist
	local d = Instance.new("ParticleEmitter")
	d.Name = "Droplets"
	d.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	d.Color = ColorSequence.new(Color3.fromRGB(225, 248, 255))
	d.Size = NumberSequence.new(0.35, 0.2)
	d.Transparency = NumberSequence.new(0.2, 1)
	d.Lifetime = NumberRange.new(0.5, 0.9)
	d.Rate = 5
	d.Speed = NumberRange.new(5, 8)
	d.SpreadAngle = Vector2.new(20, 20)
	d.EmissionDirection = Enum.NormalId.Top
	d.Acceleration = Vector3.new(0, -25, 0)
	d.LightEmission = 0.4
	d.Parent = mist
	m:SetAttribute("MeadowTerrain", true)
	m.PrimaryPart = anchor
	m.Parent = decor
	return count
end

-- MeadowKit pieces (60, 2026-10-07) were grounded on the old flat Y 0: bottom back on the new ground; a piece over
-- water, a cliff or a steep bank goes to Hidden, and so does a SOLID piece (trees) whose footprint core (the inner 60%
-- of its bounding box, 3 x 3 samples) touches a painted road or the hill path: no trunk or canopy blocks a way.
-- Kit pieces hidden by an earlier run come back first and are judged again on the current plan (re-runs follow the
-- plan both ways); restore puts every piece back at its original pivot
local function settleKit(P)
	local decor = mapRoot and mapRoot:FindFirstChild("Decor")
	local kit = decor and decor:FindFirstChild("MeadowKit")
	if not kit then return 0, 0 end
	local KIT_KEY = "Decor/MeadowKit/"
	local h = store and store:FindFirstChild("Hidden")
	for _, inst in (h and h:GetChildren() or {}) do
		local key = inst:GetAttribute("MT_From")
		if type(key) == "string" and string.sub(key, 1, #KIT_KEY) == KIT_KEY then
			inst:SetAttribute("MT_From", nil)
			inst:SetAttribute("MT_Multi", nil)
			inst.Parent = kit
		end
	end
	local function onWay(x, z) -- a painted road or the hill path column?
		local i = math.floor((x - G.X0) / G.R) + 1
		local k = math.floor((z - G.Z0) / G.R) + 1
		if i < 1 or i > G.NX or k < 1 or k > G.NZ then return false end
		local tag = P.Tag[colIdx(i, k)]
		return tag == "ramp" or (tag ~= nil and string.sub(tag, 1, 5) == "road:")
	end
	local function solid(piece)
		if piece:IsA("BasePart") then return piece.CanCollide end
		for _, d in piece:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then return true end
		end
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	params.IgnoreWater = false
	local function ground(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -220, 0), params)
		local planV = sampleAt(P, x, z)
		if not hit then return planV, false end
		local y = hit.Position.Y
		if math.abs(y - planV) > 2.5 then y = planV end -- terrain not refreshed yet: trust the plan
		return y, hit.Material == Enum.Material.Water
	end
	local settled, hidden = 0, 0
	for _, piece in kit:GetChildren() do
		if piece:IsA("Model") or piece:IsA("BasePart") then
			local orig = piece:GetAttribute("MT_OrigPivot")
			if typeof(orig) ~= "CFrame" then
				orig = piece:GetPivot()
				piece:SetAttribute("MT_OrigPivot", orig)
			end
			local x, z = orig.Position.X, orig.Position.Z
			local y, wet = ground(x, z)
			local hi, lo = y, y
			for _, o in { { 2.5, 0 }, { -2.5, 0 }, { 0, 2.5 }, { 0, -2.5 } } do
				local yy = ground(x + o[1], z + o[2])
				hi, lo = math.max(hi, yy), math.min(lo, yy)
			end
			local blocks = false
			if solid(piece) then
				local bcf, bsize
				if piece:IsA("Model") then
					bcf, bsize = piece:GetBoundingBox()
				else
					bcf, bsize = piece.CFrame, piece.Size
				end
				local shift = orig.Position - piece:GetPivot().Position -- judged at the original spot
				bcf += Vector3.new(shift.X, 0, shift.Z)
				for u = -1, 1 do
					for v = -1, 1 do
						local s = bcf:PointToWorldSpace(Vector3.new(0.4 * u * bsize.X, 0, 0.4 * v * bsize.Z))
						if onWay(s.X, s.Z) then blocks = true end
					end
				end
			end
			if wet or y > 12 or hi - lo > 3.5 or blocks then
				piece:SetAttribute("MT_From", KIT_KEY .. piece.Name)
				piece:SetAttribute("MT_Multi", true) -- kit names repeat: put back even when a sibling has the name
				piece.Parent = hiddenFolder()
				hidden += 1
			else
				local cf, size
				if piece:IsA("Model") then
					cf, size = piece:GetBoundingBox()
				else
					cf, size = piece.CFrame, piece.Size
				end
				piece:PivotTo(piece:GetPivot() + Vector3.new(0, y - 0.1 - (cf.Position.Y - size.Y / 2), 0))
				settled += 1
			end
		end
	end
	return settled, hidden
end
local function unsettleKit()
	local decor = mapRoot and mapRoot:FindFirstChild("Decor")
	local kit = decor and decor:FindFirstChild("MeadowKit")
	local n = 0
	for _, piece in (kit and kit:GetChildren() or {}) do
		local orig = piece:GetAttribute("MT_OrigPivot")
		if typeof(orig) == "CFrame" then
			piece:PivotTo(orig)
			piece:SetAttribute("MT_OrigPivot", nil)
			n += 1
		end
	end
	return n
end

local function writeInfo()
	local st = getStore()
	local function v3(x, y, z) return Vector3.new(math.floor(x * 10 + 0.5) / 10, y, math.floor(z * 10 + 0.5) / 10) end
	st:SetAttribute("HillTop", v3(HILL.X, HILL.Top + 0.6, HILL.Z))
	local foot = HILL.TopR + HILL.Face.Run + HILL.Face.PathOut
	st:SetAttribute("HillPathFoot", v3(HILL.X + math.cos(HILL.Face.Dir) * foot, 0, HILL.Z + math.sin(HILL.Face.Dir) * foot))
	st:SetAttribute("PlateauTop", v3(PL.X, PL.Top, PL.Z))
	st:SetAttribute("FallsLip", v3(FALLS.P0X, PL.Top, FALLS.P0Z))
	st:SetAttribute("FallsPool", v3(FALLS.QX, FALLS.PoolW, FALLS.QZ))
	local nookA = FALLS.Ledge * 0.45
	st:SetAttribute("SecretNook", v3(FALLS.P0X + FALLS.NX * nookA, FALLS.LedgeV, FALLS.P0Z + FALLS.NZ * nookA))
	local mouth = RIVER.Ctrl[#RIVER.Ctrl]
	st:SetAttribute("RiverMouth", v3(mouth[1], G.WaterTop, mouth[2]))
	local pts = {}
	for _, p in RIVER_LINE.Pts do table.insert(pts, string.format("%.0f,%.0f", p[1], p[2])) end
	st:SetAttribute("RiverLine", table.concat(pts, ";"))
end

------------------------------------------------------------------ run
if MODE == "restore" then
	local wrote = 0
	local need = {}
	for idx = 1, G.NCOL do
		if not sameCol(cur, base, idx) then need[chunkOf(idx)] = true end
	end
	for c in need do
		local ci, ck = chunkCR(c)
		writeChunk(ci, ck, function(idx)
			return base.S[idx], matEnum(base.M[idx]), G.WaterTop -- preview_map's one sea level
		end)
		wrote += 1
		task.wait()
	end
	local decor = mapRoot and mapRoot:FindFirstChild("Decor")
	local f = decor and decor:FindFirstChild(FALLS_NAME)
	if f then f:Destroy() end
	local kitBack = unsettleKit()
	local back, left = unhidePieces()
	dropPathSlot()
	setStoreText("Last", nil)
	store:SetAttribute("PlanHash", nil)
	return string.format("meadow terrain restore: %d chunks back to the baseline, waterfall removed, %d MeadowKit pivots + %d hidden pieces back%s%s",
		wrote, kitBack, back, left > 0 and (" (" .. left .. " left in the store: their folder is gone or taken)") or "",
		#skipped > 0 and ("; " .. table.concat(skipped, "; ")) or "")
end

local slotName, slotNote = "Ground", "plan"
if MODE ~= "plan" then slotName, slotNote = pathSlot() end
local P = plan(base)
for idx = 1, G.NCOL do
	if P.M[idx] == "Path" then P.M[idx] = slotName end
end
local st = stats(P, base)
if MODE == "plan" then return report(P, st, " | path tile: " .. slotNote) end

-- write a chunk when its plan changed since the last run or its terrain is not our last result any more (preview_map
-- terrain ran again, ...), and only if it differs from the baseline at all (plan or current terrain)
local hashes, planDiff, curDiff, curNotLast = {}, {}, {}, {}
for c = 1, G.CX * G.CZ do hashes[c] = 7 end
local palette, nPal = {}, 0
for idx = 1, G.NCOL do
	local m = P.M[idx]
	if not palette[m] then
		nPal += 1
		palette[m] = nPal
	end
	local c = chunkOf(idx)
	local w = P.W[idx] or G.WaterTop
	local q = math.floor((P.S[idx] - G.Y0) * 20 + 0.5) * 131 + palette[m] * 7 + math.floor((w - G.Y0) * 20 + 0.5)
	hashes[c] = (hashes[c] * 31 + q) % 16777213
	if math.abs(P.S[idx] - base.S[idx]) > 0.01 or m ~= base.M[idx] or math.abs(w - G.WaterTop) > 0.01 then planDiff[c] = true end
	if not sameCol(cur, base, idx) then curDiff[c] = true end
	if not (last and sameCol(cur, last, idx)) then curNotLast[c] = true end
end
local oldHashes = string.split(store:GetAttribute("PlanHash") or "", ",")
local wrote = 0
for c = 1, G.CX * G.CZ do
	local ci, ck = chunkCR(c)
	if (tostring(hashes[c]) ~= oldHashes[c] or curNotLast[c]) and (planDiff[c] or curDiff[c]) then
		writeChunk(ci, ck, function(idx)
			return P.S[idx], matEnum(P.M[idx]), P.W[idx] or G.WaterTop
		end)
		wrote += 1
		task.wait()
	end
end
local hashText = {}
for c = 1, G.CX * G.CZ do hashText[c] = tostring(hashes[c]) end
task.wait()
saveSummary("Last", readSummary())
store:SetAttribute("PlanHash", table.concat(hashText, ","))
store:SetAttribute("AppliedAt", DateTime.now():ToIsoDate())

local moved = hidePieces()
local fallsParts = buildFalls()
task.wait()
local settled, kitHidden = settleKit(P)
writeInfo()
return report(P, st, string.format(" | wrote %d/%d chunks (%s); path tile: %s; waterfall %d parts (6 flow textures, 4 beams, 2 emitters); "
	.. "hidden %d old pieces; MeadowKit settled %d, hidden %d%s", wrote, G.CX * G.CZ,
	useChannels and "WriteVoxelChannels" or "WriteVoxels", slotNote, fallsParts, moved, settled, kitHidden,
	#skipped > 0 and ("; " .. table.concat(skipped, "; ")) or ""))
