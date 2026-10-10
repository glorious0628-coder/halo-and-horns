-- halo_terrain.luau (이미지 생성 1, 2026-10-09; 사용자 구역 순서 ① 빛 마을, 검수 A23-97, plan docs/design/halo_town_plan_2026-10-09.md)
-- Studio MCP execute_luau, MAIN place, Edit mode only (메인 반영 runs it; the runner replaces "__MODE__").
-- Sculpts the Halo Citadel island toward art/review/s2/place_HaloTown_sheet.jpg: a white limestone cliff island split by sea
-- canals into a SPINE (gate -> hero road -> three terraces up to the cathedral) and four pairs of wing terraces, every top flat
-- enough for buildings, the canals are sea level (water WaterTop) with arch-bridge spots across them, the outer cliffs drop to
-- the sea. Heights are "visual" studs (ground Y 0); a solid column is drawn Lift (2) above its voxels, water is not.
-- Contracts kept: the gate end z -330 and the spawn road stay at Y 0.2 (Bridge_Halo deck, Gate_HaloTown, Zones.HaloTown.Spawn
-- (0, 0, -420)); the spine is Y 0.2 up to z -444, then 5 / 11 / 19 (stair ramps on the axis, |x| <= 14, slope <= 21 deg).
-- Only the box x -208..208, z -708..-328 is written; columns outside the rect x +-200, z -700..-330 keep the baseline.
-- Two materials per column: the top voxel layer (Concrete = Halo tile paved / Grass rim / Sand canal bed) over a Limestone body, so the cliffs
-- show white rock under a paved or grassy top.
-- MODE: "apply" (default) = sculpt from the stored baseline (the first run stores the current flat island as baseline);
--       "plan" = compute only, return numbers; "restore" = write the baseline back; "rebase" = store the CURRENT terrain as
--       the new baseline (only on the flat island), then apply.
-- Deterministic (math.noise only). ServerStorage.HaloTerrainStore keeps the baseline (run-length text) and the spots for the
-- props tool (attributes below). Offline check: build/luau_cli_0_741/luau.exe tools/worldkit/halo_terrain.luau (synthetic flat
-- baseline, plan only); set DUMP = true to print one row per column ("C,x,z,V,W,mat,tag") for tools/terrain_dump_render.py.

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" and MODE ~= "rebase" then MODE = "apply" end
local DUMP = false
local STUDIO = game ~= nil
if not STUDIO then MODE = "plan" end
if STUDIO and game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end

------------------------------------------------------------------ numbers
local G = {
	R = 4, Lift = 2, WaterTop = -1.2,
	X0 = -208, X1 = 208, Z0 = -708, Z1 = -328, Y0 = -28, Y1 = 56, Chunk = 16,
	LandMinX = -200, LandMaxX = 200, LandMinZ = -700, LandMaxZ = -330,
	Bed = -6, -- visual Y of the canal / sea floor inside the rect
	TopLayer = 4, -- studs of the top material over the limestone body
}
G.NX, G.NZ, G.NY = (G.X1 - G.X0) / G.R, (G.Z1 - G.Z0) / G.R, (G.Y1 - G.Y0) / G.R
G.NCOL = G.NX * G.NZ
G.CX, G.CZ = math.ceil(G.NX / G.Chunk), math.ceil(G.NZ / G.Chunk)

-- the spine: tiers by z (north = more negative). Ramps (stairs) on the axis only; elsewhere the step is a wall.
local SPINE = {
	Z1 = -692, -- far end (cathedral terrace)
	Stair = 14, -- stair half-width (flat ramp, walkable)
	RampLen = 30, -- 2026-10-10: taller tiers (A23-76 보강: 땅이 납작하지 않게), ramps stay <= 24 deg
	-- { boundary z (a step down the road toward the cathedral), height after it, half-width after it }
	Tiers = { { 0, 0.2, 38 }, { -444, 9, 50 }, { -524, 20, 76 }, { -606, 33, 100 } },
	WidthBlend = 10,
}
-- wing terraces (mirrored): ax = |x|, rect in (ax, z), height, rounded corner radius, kind
local WINGS = {
	{ Name = "WA", ax0 = 60, ax1 = 188, z0 = -434, z1 = -336, H = 3, Rad = 28 },
	{ Name = "WB", ax0 = 74, ax1 = 188, z0 = -536, z1 = -450, H = 12, Rad = 26 },
	{ Name = "WC", ax0 = 100, ax1 = 190, z0 = -612, z1 = -552, H = 22, Rad = 22 },
	{ Name = "WD", ax0 = 124, ax1 = 190, z0 = -692, z1 = -628, H = 33, Rad = 20 },
}
-- arch-bridge spots across the canals (for the props tool: the bridge centre, its axis, the deck heights at both ends)
local BRIDGES = {
	{ "BA", 0, -385, "x", 0.2, 3 }, { "BB", 0, -492, "x", 9, 12 }, { "BC", 0, -582, "x", 20, 22 }, { "BD", 0, -662, "x", 33, 33 },
	{ "BAB", 130, -442, "z", 3, 12 }, { "BBC", 150, -544, "z", 12, 22 }, { "BCD", 150, -620, "z", 22, 33 },
}
local PAVE = { Rim = 8, Wing = 16, Mat = "Concrete" } -- grass rim width on the wing tops (2026-10-10: 16 so the wings are gardens round a paved forecourt; the spine road is PAVEHALF below); Mat = the paved top (Terrain has no Marble: tools/worldkit/halo_materials.luau gives Concrete the Halo tile)
-- 2026-10-10 (검수: the road was 76 wide and read as an empty beige slab): the PAVED part of the spine is narrow like the concept (road about
-- one house wide), the rest of the terrace is grass garden for the props tool (balustrade, planters, topiary rows). { boundary z (north of it), paved half-width }
local PAVEHALF = { { 0, 15 }, { -444, 19 }, { -524, 62 }, { -606, 46 } }
local function paveHalf(z)
	local h = PAVEHALF[1][2]
	for i = 2, #PAVEHALF do
		if z <= PAVEHALF[i][1] then h = PAVEHALF[i][2] end
	end
	return h
end
-- grass mounds in the gardens (2026-10-10, A23-76 보강 "언덕도 있고 해야지"): { |x|, z, radius, height }, mirrored east/west, only where the top is grass
-- (never on the paved road / plaza / forecourt); person-high or more so the town is not a flat slab
local MOUNDS = {
	{ 29, -376, 8, 3.4 }, { 31, -418, 9, 4.0 }, { 34, -350, 6, 3.0 },                    -- spine tier 1 gardens (x 15..38)
	{ 40, -470, 11, 5.0 }, { 36, -508, 9, 4.2 }, { 46, -492, 6, 3.2 },                   -- tier 2 (x 19..50)
	{ 73, -566, 5, 3.0 },                                           -- tier 3 beyond the plaza
	{ 66, -640, 10, 5.0 }, { 94, -652, 8, 5.5 }, { 64, -678, 8, 4.5 },                  -- tier 4 gardens (x 46..100)
	{ 170, -350, 12, 5.0 }, { 174, -420, 11, 5.5 }, { 150, -345, 9, 4.0 }, { 78, -425, 7, 3.2 }, -- wing WA
	{ 176, -466, 11, 5.5 }, { 178, -526, 11, 5.0 }, { 88, -462, 7, 3.4 },                  -- WB
	{ 180, -558, 6, 4.5 }, { 176, -604, 9, 5.0 }, { 112, -558, 8, 4.0 },                 -- WC
	{ 178, -642, 10, 6.0 }, { 176, -684, 9, 5.5 }, { 132, -686, 8, 4.5 },                 -- WD
}
local function moundHeight(ax, z)
	local add = 0
	for _, m in MOUNDS do
		local d = math.sqrt((ax - m[1]) ^ 2 + (z - m[2]) ^ 2)
		if d < m[3] then
			local t = 1 - d / m[3]
			add = math.max(add, m[4] * t * t * (3 - 2 * t))
		end
	end
	return add
end
local CLIFF = { Skirt = 5, Jag = 4.2, JagScale = 27, Jag2 = 1.6, Jag2Scale = 9 }
-- waterfalls (mirrored, one per side): a small spring basin on the wing top spills over its outer cliff into the sea
-- (art/review/s2/place_HaloTown_sheet.jpg, shot 5). Terrain water does not flow, so the sheet of water standing against the
-- cliff is the base; the props tool adds foam / mist on top. { wing, centre z }; Half = half width of the channel.
local FALLS = { { "WB", -493 }, { "WC", -582 }, { "WD", -660 } }
local FALL = { Half = 4, Basin = 9, Drop = 0.4, Dip = 1.5 }
-- sea stacks / rock pillars in the canals and off the coast (not walkable; give the sea silhouette rocks): { x, z, radius, top V }
local STACKS = {} -- none yet: the canals are only 12..22 studs wide (the far sea stacks are a backdrop prop, not terrain)

------------------------------------------------------------------ math helpers
local function clamp01(t) return t < 0 and 0 or (t > 1 and 1 or t) end
local function smooth(t) t = clamp01(t) return t * t * (3 - 2 * t) end
local function lerp(a, b, t) return a + (b - a) * t end

local function spineTier(z) -- index of the tier whose road starts north of z
	local n = 1
	for i = 2, #SPINE.Tiers do
		if z <= SPINE.Tiers[i][1] then n = i end
	end
	return n
end
local function spineWidth(z) -- half-width, blended over WidthBlend at every boundary
	local w = SPINE.Tiers[1][3]
	for i = 2, #SPINE.Tiers do
		local b = SPINE.Tiers[i][1]
		w = lerp(w, SPINE.Tiers[i][3], smooth((b - z) / SPINE.WidthBlend + 0.5))
	end
	return w
end
local function spineHeight(z, ax) -- V of the spine top at (ax, z); ramps only inside the stair width
	local n = spineTier(z)
	local h = SPINE.Tiers[n][2]
	if ax <= SPINE.Stair then
		-- linear ramp centred on each boundary: from RampLen/2 south of it to RampLen/2 north of it
		for i = 2, #SPINE.Tiers do
			local b = SPINE.Tiers[i][1]
			local t = (b + SPINE.RampLen / 2 - z) / SPINE.RampLen
			if t > 0 and t < 1 then return lerp(SPINE.Tiers[i - 1][2], SPINE.Tiers[i][2], t) - 1.4 * math.sin(math.pi * t) end -- 1.4 sunk in the middle so the stairs model's steps stand out of the ramp
			if t >= 1 then h = SPINE.Tiers[i][2] end
		end
	end
	return h
end

local function rrect(ax, z, x0, x1, z0, z1, r) -- signed distance to a rounded rect (negative inside)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local qx = math.abs(ax - cx) - ((x1 - x0) / 2 - r)
	local qz = math.abs(z - cz) - ((z1 - z0) / 2 - r)
	local ox, oz = math.max(qx, 0), math.max(qz, 0)
	return math.sqrt(ox * ox + oz * oz) + math.min(math.max(qx, qz), 0) - r
end

local function jag(x, z)
	return CLIFF.Jag * math.noise(x / CLIFF.JagScale + 0.37, z / CLIFF.JagScale + 0.81, 2.6)
		+ CLIFF.Jag2 * math.noise(x / CLIFF.Jag2Scale + 0.11, z / CLIFF.Jag2Scale + 0.53, 6.1)
end

-- the island piece that owns (x, z): returns top V, signed edge distance (negative inside), kind; nil = open sea / canal
local function pieces(x, z)
	local ax = math.abs(x)
	local jg = jag(x, z)
	local cand = {}
	-- spine: |x| <= hw(z), from the gate end to SPINE.Z1 (the gate end is open: flush with the bridge); rounded far corners
	local hw = spineWidth(z)
	local sdfS = math.max(ax - hw, SPINE.Z1 - z)
	if z < SPINE.Z1 + 16 then
		local qx, qz = ax - (hw - 16), (SPINE.Z1 + 16) - z
		if qx > 0 and qz > 0 then sdfS = math.sqrt(qx * qx + qz * qz) - 16 end
	end
	cand[1] = { sdfS + jg, spineHeight(z, ax), "spine" }
	for _, w in WINGS do
		table.insert(cand, { rrect(ax, z, w.ax0, w.ax1, w.z0, w.z1, w.Rad) + jg, w.H, "wing:" .. w.Name })
	end
	for _, st in STACKS do
		local d = math.sqrt((x - st[1]) ^ 2 + (z - st[2]) ^ 2) - st[3]
		table.insert(cand, { d + jg * 0.6, st[4], "stack" })
	end
	local best
	for _, c in cand do
		if c[1] < 0 then -- inside: the highest piece wins
			if not best or best[1] >= 0 or c[2] > best[2] then best = c end
		elseif c[1] < CLIFF.Skirt and (best == nil or (best[1] >= 0 and c[1] < best[1])) then
			best = c
		end
	end
	if not best then return nil end
	return best[2], best[1], best[3]
end

------------------------------------------------------------------ the column
-- returns V (top, visual studs), W (water top or nil), top material, tag, e (distance inside the land rect) or nil outside the rect
local function column(x, z)
	if x < G.LandMinX or x > G.LandMaxX or z < G.LandMinZ or z > G.LandMaxZ then return nil end
	local e = math.min(x - G.LandMinX, G.LandMaxX - x, z - G.LandMinZ, G.LandMaxZ - z)
	local h, sdf, kind = pieces(x, z)
	if h == nil then return G.Bed, G.WaterTop, "Sand", "bed", e end
	local ax = math.abs(x)
	local wf
	if string.sub(kind, 1, 5) == "wing:" then
		for _, f in FALLS do
			if "wing:" .. f[1] == kind and math.abs(z - f[2]) <= FALL.Half then wf = f end
		end
	end
	if wf then
		if sdf > -2.5 and sdf < CLIFF.Skirt - 0.5 then -- the water sheet down the cliff to the sea
			return G.Bed, h - FALL.Drop, "Sand", "fall", e
		elseif sdf <= -2.5 and sdf >= -FALL.Basin then -- spring basin, a little below the rim
			return h - FALL.Dip, h - FALL.Drop, "Sand", "basin", e
		end
	end
	if sdf > 0 then -- cliff skirt: drops from the top to the bed over the skirt
		local t = smooth(sdf / CLIFF.Skirt)
		local v = lerp(h, G.Bed, t)
		return v, v < G.WaterTop and G.WaterTop or nil, "Limestone", "cliff", e
	end
	local tag, mat = "top", "Grass"
	local inner = -sdf -- studs inside the edge
	if kind == "spine" then
		local hw = spineWidth(z)
		if ax <= math.min(paveHalf(z), hw - PAVE.Rim) and inner >= 3 then mat, tag = PAVE.Mat, "plaza" end
		if ax <= SPINE.Stair and h > SPINE.Tiers[spineTier(z)][2] + 0.01 then tag = "stair" end
		if ax > SPINE.Stair and inner > 1 then
			-- the wall between two tiers: the column right at a boundary (a step down) shows limestone
			for i = 2, #SPINE.Tiers do
				if math.abs(z - SPINE.Tiers[i][1]) < 2 then mat, tag = "Limestone", "wall" end
			end
		end
	else
		if inner >= PAVE.Wing and inner >= 3 then mat, tag = PAVE.Mat, "plaza" end
	end
	if inner < 3 then mat = "Grass" end
	if tag == "top" and inner >= 4 then h += moundHeight(ax, z) end -- grass mounds
	return h, nil, mat, tag, e
end

------------------------------------------------------------------ the plan
local function colX(i) return G.X0 + (i - 0.5) * G.R end
local function colZ(k) return G.Z0 + (k - 0.5) * G.R end
local function colIdx(i, k) return (i - 1) * G.NZ + k end

local function plan(base)
	local V, W, Top, Body, Tag, E = table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL), table.create(G.NCOL)
	for i = 1, G.NX do
		for k = 1, G.NZ do
			local idx = colIdx(i, k)
			local x, z = colX(i), colZ(k)
			local v, w, mat, tag, e = column(x, z)
			if v == nil then
				V[idx], Top[idx], Body[idx] = base.S[idx] + G.Lift, base.M[idx], base.M[idx]
			else
				if tag == "bed" then v = math.min(v, base.S[idx] + G.Lift) end -- never shallower than the baseline's coast
				V[idx], W[idx], Top[idx], Tag[idx], E[idx] = v, w, mat, tag, e
				Body[idx] = (tag == "bed" or tag == "fall") and "Sand" or "Limestone"
			end
		end
	end
	local S, Slope = table.create(G.NCOL), table.create(G.NCOL)
	for i = 1, G.NX do
		for k = 1, G.NZ do
			local idx = colIdx(i, k)
			local v = V[idx]
			local gx = ((V[colIdx(math.min(G.NX, i + 1), k)] or v) - (V[colIdx(math.max(1, i - 1), k)] or v)) / (G.R * (i > 1 and i < G.NX and 2 or 1))
			local gz = ((V[colIdx(i, math.min(G.NZ, k + 1))] or v) - (V[colIdx(i, math.max(1, k - 1))] or v)) / (G.R * (k > 1 and k < G.NZ and 2 or 1))
			Slope[idx] = math.deg(math.atan(math.sqrt(gx * gx + gz * gz)))
			S[idx] = v - G.Lift
		end
	end
	return { V = V, S = S, Top = Top, Body = Body, W = W, Tag = Tag, E = E, Slope = Slope }
end

local function stats(P)
	local n, slopes, byTag, vmax = 0, {}, {}, -1e9
	for i = 1, G.NX do
		for k = 1, G.NZ do
			local idx = colIdx(i, k)
			local tag = P.Tag[idx]
			if tag then
				byTag[tag] = (byTag[tag] or 0) + 1
				if tag == "plaza" or tag == "stair" then
					n += 1
					table.insert(slopes, P.Slope[idx])
					vmax = math.max(vmax, P.V[idx])
				end
			end
		end
	end
	table.sort(slopes)
	local function q(t) return slopes[math.max(1, math.floor(#slopes * t))] or 0 end
	local tags = {}
	for t, c in byTag do table.insert(tags, t .. "=" .. c) end
	table.sort(tags)
	return string.format("walkable (plaza + stair) %d columns, top Y max %.1f, slope p50 %.1f p95 %.1f max %.1f deg | %s", n, vmax, q(0.5), q(0.95), slopes[#slopes] or 0, table.concat(tags, " "))
end

------------------------------------------------------------------ offline: synthetic flat baseline, plan only
if not STUDIO then
	local base = { S = table.create(G.NCOL), M = table.create(G.NCOL), L = table.create(G.NCOL) }
	for idx = 1, G.NCOL do base.S[idx], base.M[idx], base.L[idx] = -G.Lift, "Limestone", false end
	local P = plan(base)
	print(stats(P))
	if DUMP then
		for i = 1, G.NX do
			for k = 1, G.NZ do
				local idx = colIdx(i, k)
				print(string.format("C,%d,%d,%.2f,%s,%s,%s", colX(i), colZ(k), P.V[idx], P.W[idx] and string.format("%.1f", P.W[idx]) or "-", P.Top[idx], tostring(P.Tag[idx])))
			end
		end
	end
	return
end

------------------------------------------------------------------ Studio: baseline, write, restore
local SS = game:GetService("ServerStorage")
local Terrain = workspace.Terrain
local AIR = Enum.Material.Air

local function readSummary()
	local region = Region3.new(Vector3.new(G.X0, G.Y0, G.Z0), Vector3.new(G.X1, G.Y1, G.Z1))
	local ch = Terrain:ReadVoxelChannels(region, G.R, { "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" })
	local sm, so, lo = ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
	local sum = { S = table.create(G.NCOL), M = table.create(G.NCOL), L = table.create(G.NCOL) }
	for i = 1, G.NX do
		for k = 1, G.NZ do
			local total, mHi, mLo, lt = 0, nil, nil, false
			for j = 1, G.NY do
				local mat, o = sm[i][j][k], so[i][j][k]
				local l = lo and lo[i][j][k] or 0
				if mat == Enum.Material.Water then l, o = (lo and l or o), 0 elseif mat == AIR then o = 0 end
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
		m = ok and e or Enum.Material.Limestone
		MAT_CACHE[name] = m
	end
	return m
end
-- colFn(idx) -> S (solid top, voxel studs), top material, body material, water top
local function writeChunk(ci, ck, colFn)
	local i0, k0 = (ci - 1) * G.Chunk + 1, (ck - 1) * G.Chunk + 1
	local i1, k1 = math.min(G.NX, i0 + G.Chunk - 1), math.min(G.NZ, k0 + G.Chunk - 1)
	local ni, nk = i1 - i0 + 1, k1 - k0 + 1
	local sm, so, lo = table.create(ni), table.create(ni), table.create(ni)
	for a = 1, ni do
		local mI, oI, lI = table.create(G.NY), table.create(G.NY), table.create(G.NY)
		for j = 1, G.NY do mI[j], oI[j], lI[j] = table.create(nk), table.create(nk), table.create(nk) end
		for c = 1, nk do
			local S, top, body, W = colFn(colIdx(i0 + a - 1, k0 + c - 1))
			for j = 1, G.NY do
				local cy = G.Y0 + (j - 0.5) * G.R
				local occ = clamp01((S - cy) / G.R + 0.5)
				local lw = occ < 1 and clamp01((W - cy) / G.R + 0.5) or 0
				local mat = AIR
				if occ > 0 then mat = (cy > S - G.TopLayer) and top or body end
				mI[j][c], oI[j][c], lI[j][c] = mat, occ, lw
			end
		end
		sm[a], so[a], lo[a] = mI, oI, lI
	end
	local region = Region3.new(Vector3.new(G.X0 + (i0 - 1) * G.R, G.Y0, G.Z0 + (k0 - 1) * G.R),
		Vector3.new(G.X0 + i1 * G.R, G.Y1, G.Z0 + k1 * G.R))
	Terrain:WriteVoxelChannels(region, G.R, { SolidMaterial = sm, SolidOccupancy = so, LiquidOccupancy = lo })
end
local function chunkOf(idx)
	local i, k = (idx - 1) // G.NZ + 1, (idx - 1) % G.NZ + 1
	return ((i - 1) // G.Chunk) * G.CZ + ((k - 1) // G.Chunk) + 1
end
local function chunkCR(c) return (c - 1) // G.CZ + 1, (c - 1) % G.CZ + 1 end

-- store: baseline text (run-length) + spots for the props tool
local store = SS:FindFirstChild("HaloTerrainStore")
local BOX = string.format("%d,%d,%d,%d,%d,%d,%d", G.X0, G.X1, G.Z0, G.Z1, G.Y0, G.Y1, G.R)
local function getStore()
	if not store then
		store = Instance.new("Folder")
		store.Name = "HaloTerrainStore"
		store:SetAttribute("Box", BOX)
		store.Parent = SS
	end
	return store
end
local function encode(sum)
	local out, prev, n = {}, nil, 0
	for idx = 1, G.NCOL do
		local key = string.format("%.2f,%s,%s", sum.S[idx], sum.M[idx], sum.L[idx] and string.format("%.2f", sum.L[idx]) or "-")
		if key == prev then
			n += 1
		else
			if prev then table.insert(out, n .. "*" .. prev .. ";") end
			prev, n = key, 1
		end
	end
	table.insert(out, n .. "*" .. prev .. ";")
	return table.concat(out)
end
local function decode(text)
	local sum = { S = table.create(G.NCOL), M = table.create(G.NCOL), L = table.create(G.NCOL) }
	local idx = 0
	for n, s, m, l in string.gmatch(text, "(%d+)%*([^,]+),([^,]+),([^;]+);") do
		local lv = l ~= "-" and tonumber(l) or false
		for _ = 1, tonumber(n) do
			idx += 1
			sum.S[idx], sum.M[idx], sum.L[idx] = tonumber(s), m, lv
		end
	end
	assert(idx == G.NCOL, "stored baseline has " .. idx .. " columns, expected " .. G.NCOL)
	return sum
end
local PIECE = 40000
local function saveBase(sum)
	local st = getStore()
	local text = encode(sum)
	local n = math.ceil(#text / PIECE)
	for p = 1, n do
		local v = st:FindFirstChild("Base_" .. p) or Instance.new("StringValue")
		v.Name = "Base_" .. p
		v.Value = string.sub(text, (p - 1) * PIECE + 1, p * PIECE)
		v.Parent = st
	end
	for p = n + 1, (st:GetAttribute("BasePieces") or 0) do
		local v = st:FindFirstChild("Base_" .. p)
		if v then v:Destroy() end
	end
	st:SetAttribute("BasePieces", n)
end
local function loadBase()
	local n = store and store:GetAttribute("BasePieces")
	if type(n) ~= "number" or n < 1 then return nil end
	local parts = {}
	for p = 1, n do
		local v = store:FindFirstChild("Base_" .. p)
		if not (v and v:IsA("StringValue")) then return nil end
		parts[p] = v.Value
	end
	return decode(table.concat(parts))
end
if store then
	assert(store:GetAttribute("Box") == BOX, "HaloTerrainStore was made for another box: restore with the old script first")
end

------------------------------------------------------------------ run
local cur = readSummary()
local base = loadBase()
local function flatCheck(sum)
	local bad = {}
	for _, p in { { 0, -400 }, { 0, -520 }, { 0, -640 }, { -120, -450 }, { 120, -600 } } do
		local i = math.floor((p[1] - G.X0) / G.R) + 1
		local k = math.floor((p[2] - G.Z0) / G.R) + 1
		local v = sum.S[colIdx(i, k)] + G.Lift
		if math.abs(v) > 1.5 then table.insert(bad, string.format("(%d, %d) Y %.1f", p[1], p[2], v)) end
	end
	return bad
end
if MODE == "rebase" or (base == nil and MODE ~= "restore") then
	local bad = flatCheck(cur)
	if #bad > 0 then
		error("Halo island is not flat (" .. table.concat(bad, ", ") .. "): restore with the old script first, or rebuild the island")
	end
	base = cur
	if MODE ~= "plan" then
		saveBase(base)
		base = loadBase()
		getStore():SetAttribute("CapturedAt", DateTime.now():ToIsoDate())
	end
end
assert(base, "no stored baseline: nothing to restore")

if MODE == "restore" then
	local need = {}
	for idx = 1, G.NCOL do
		if math.abs(cur.S[idx] - base.S[idx]) > 0.15 or cur.M[idx] ~= base.M[idx] then need[chunkOf(idx)] = true end
	end
	local wrote = 0
	for c in need do
		local ci, ck = chunkCR(c)
		writeChunk(ci, ck, function(idx) return base.S[idx], matEnum(base.M[idx]), matEnum(base.M[idx]), G.WaterTop end)
		wrote += 1
		task.wait()
	end
	if store then
		for _, a in { "Bridges", "Waterfalls", "AppliedAt", "Tiers" } do store:SetAttribute(a, nil) end
	end
	return string.format("halo terrain restore: %d chunks back to the baseline", wrote)
end

local P = plan(base)
local report = stats(P)
if MODE == "plan" then return "PLAN " .. report end

local planDiff = {}
for idx = 1, G.NCOL do
	if math.abs(P.S[idx] - cur.S[idx]) > 0.15 or P.Top[idx] ~= cur.M[idx] then planDiff[chunkOf(idx)] = true end
end
local wrote = 0
for c = 1, G.CX * G.CZ do
	if planDiff[c] then
		local ci, ck = chunkCR(c)
		writeChunk(ci, ck, function(idx) return P.S[idx], matEnum(P.Top[idx]), matEnum(P.Body[idx]), P.W[idx] or G.WaterTop end)
		wrote += 1
		task.wait()
	end
end
local st = getStore()
local spots = {}
for _, b in BRIDGES do
	table.insert(spots, string.format("%s,%d,%d,%s,%.1f,%.1f", b[1], b[2], b[3], b[4], b[5], b[6]))
end
st:SetAttribute("Bridges", table.concat(spots, ";"))
local falls = {}
for _, f in FALLS do
	for _, sgn in { -1, 1 } do
		local w
		for _, ww in WINGS do if ww.Name == f[1] then w = ww end end
		table.insert(falls, string.format("%s%s,%d,%d,%.1f", f[1], sgn < 0 and "W" or "E", sgn * w.ax1, f[2], w.H))
	end
end
st:SetAttribute("Waterfalls", table.concat(falls, ";")) -- name, x of the wing outer edge, z, top Y
local tiers = {}
for _, t in SPINE.Tiers do table.insert(tiers, string.format("%d,%.1f,%d", t[1], t[2], t[3])) end
st:SetAttribute("Tiers", table.concat(tiers, ";"))
st:SetAttribute("AppliedAt", DateTime.now():ToIsoDate())
return string.format("halo terrain applied: %d chunks written | %s", wrote, report)
