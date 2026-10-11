-- halo_blockout.luau (이미지 생성 1, 2026-10-11, SPEC A23-121 3단계 '회색 상자'). WorldKit ONLY (Edit mode).
-- Built by tools/halo_blockout.py (py tools/halo_blockout.py --mode apply|remove|plan) -> build/wk/halo_blockout_apply.lua
-- apply : first time keeps the old Halo (Terrain region copy + the old Halo decor) in ServerStorage.HaloV1Hold, then clears
--         the Halo box and builds: Terrain land / roads / ramps / stairs (Slate) / stream + pools / sea, grey building
--         shells at real size with door holes (floors stay Terrain: the code only counts Terrain and Bridge_* as ground),
--         bridges (Workspace.HaloV2.Bridges.Bridge_B1..), fixed-point markers and avatar-size blocks. Re-run = rebuild.
-- remove: deletes Workspace.HaloV2, puts the old Terrain region and the old decor back.
-- terrain: rewrites only the Terrain of the box (keeps HaloV2: grey boxes, skeletons, Ground parts).
-- plan  : counts only.
if string.find(game.Name, "GoodEvil") or game.PlaceId == 81671223175574 then error("main Studio: halo_blockout is WorldKit-only") end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local MODE = "__MODE__"
local D = game:GetService("HttpService"):JSONDecode([[__DATA__]])
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local OFF = Vector3.new(D.offset[1], 0, D.offset[2])
-- the box follows the plan's land (③ 3차: the town grew 1.5x); OLD_BOX = where the first apply (10/11) copied the old Halo
local BOX = { x0 = D.box[1] - 2, x1 = D.box[2] + 2, z0 = D.box[3] + 2, z1 = D.box[4] - 2, y0 = -112, y1 = 96 }
local OLD_BOX = { x0 = -214, x1 = 214, z0 = -322, z1 = -714, y0 = -24 }
local MAT = {
	g = Enum.Material.Grass, d = Enum.Material.Ground, c = Enum.Material.Concrete, b = Enum.Material.Cobblestone,
	p = Enum.Material.Pavement, t = Enum.Material.Slate, w = Enum.Material.Mud, r = Enum.Material.Rock, n = Enum.Material.Sand, l = Enum.Material.Limestone,
}
local COL = {
	Gate = Color3.fromRGB(205, 195, 170), Tower = Color3.fromRGB(190, 190, 198), Shop = Color3.fromRGB(214, 200, 182),
	HouseA = Color3.fromRGB(200, 200, 204), HouseB = Color3.fromRGB(186, 190, 196), Castle = Color3.fromRGB(160, 168, 186),
	Cathedral = Color3.fromRGB(222, 218, 232), Armory = Color3.fromRGB(176, 166, 150),
}
local WATER_TOP = -1.2
-- 10/11: a wide sea round the box was tried and dropped (검수: the island floats like the other zones); apply still clears
-- what that try left (300 studs round the box, y -34..2)
local WIDE = 300
local function clearWideSea()
	local cx, cz = (BOX.x0 + BOX.x1) / 2, (BOX.z0 + BOX.z1) / 2
	T:FillBlock(CFrame.new(Vector3.new(cx, -16, cz) + OFF), Vector3.new(BOX.x1 - BOX.x0 + WIDE * 2, 36, BOX.z0 - BOX.z1 + WIDE * 2),
		Enum.Material.Air)
end

local function region(y0)
	local a = Vector3.new(BOX.x0, y0 or BOX.y0, BOX.z1) + OFF
	local b = Vector3.new(BOX.x1, BOX.y1, BOX.z0) + OFF
	-- Region3 needs a multiple of 4 and a grid alignment
	return Region3.new(a, b):ExpandToGrid(4)
end

local function cells16(y0)
	local reg = region(y0)
	local lo = reg.CFrame.Position - reg.Size / 2
	local hi = reg.CFrame.Position + reg.Size / 2
	local a = Vector3int16.new(math.floor(lo.X / 4), math.floor(lo.Y / 4), math.floor(lo.Z / 4))
	local b = Vector3int16.new(math.floor(hi.X / 4) - 1, math.floor(hi.Y / 4) - 1, math.floor(hi.Z / 4) - 1)
	return Region3int16.new(a, b), a
end
local hold = SS:FindFirstChild("HaloV1Hold")
local root = workspace:FindFirstChild("HaloV2")

if MODE == "plan" then
	local n = 0
	for _ in D.buildings do n += 1 end
	return string.format("halo_blockout plan: grid %dx%d, buildings %d, bridges %d, hold %s, built %s", D.cols, D.rows, n, #D.bridges,
		tostring(hold ~= nil), tostring(root ~= nil))
end

if MODE == "remove" then
	if root then root:Destroy() end
	if hold then
		clearWideSea()
		local reg = region()
		T:FillBlock(reg.CFrame, reg.Size, Enum.Material.Air)
		local tr = hold:FindFirstChild("TerrainHalo")
		if tr then
			-- the copy's own corner (a hold made before the deep sea of 10/11 was copied with y0 = -24)
			local corner = hold:GetAttribute("Corner")
			if typeof(corner) == "Vector3" then
				corner = Vector3int16.new(corner.X, corner.Y, corner.Z)
			else
				local reg0 = Region3.new(Vector3.new(OLD_BOX.x0, OLD_BOX.y0, OLD_BOX.z1) + OFF, Vector3.new(OLD_BOX.x1, BOX.y1, OLD_BOX.z0) + OFF)
					:ExpandToGrid(4)
				local lo = reg0.CFrame.Position - reg0.Size / 2
				corner = Vector3int16.new(math.floor(lo.X / 4), math.floor(lo.Y / 4), math.floor(lo.Z / 4))
			end
			T:PasteRegion(tr, corner, true)
		end
		local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
		local back = 0
		for _, c in hold:GetChildren() do
			if c.Name ~= "TerrainHalo" then
				local dest = c:GetAttribute("From")
				local mf = workspace:FindFirstChild("Map")
				if dest == "Workspace" then
					c.Parent = workspace
				elseif typeof(dest) == "string" and string.sub(dest, 1, 4) == "Map." and mf and mf:FindFirstChild(string.sub(dest, 5)) then
					c.Parent = mf[string.sub(dest, 5)]
				elseif decor then
					c.Parent = decor
				end
				back += 1
			end
		end
		hold:Destroy()
		return "halo_blockout removed, old Halo back (" .. back .. " decor)"
	end
	return "halo_blockout removed"
end

-- ---------------------------------------------------------------- apply
if not hold then
	hold = Instance.new("Folder")
	hold.Name = "HaloV1Hold"
	hold:SetAttribute("Why", "A23-121: 옛 빛 마을(지형 복사본 + 장식). halo_blockout remove로 되돌림")
	hold.Parent = SS
	local r16, c16 = cells16()
	hold:SetAttribute("Corner", Vector3.new(c16.X, c16.Y, c16.Z))
	local ok, tr = pcall(function() return T:CopyRegion(r16) end)
	if ok and tr then tr.Name = "TerrainHalo" tr.Parent = hold end
	local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
	if decor then
		for _, c in decor:GetChildren() do
			local p
			if c:IsA("BasePart") then p = c.Position elseif c:IsA("Model") then p = c:GetPivot().Position end
			local whole = c.Name == "HaloProps" or c.Name == "HaloGold" or c.Name == "HaloWaterFx"
			local inBox = p and p.X > BOX.x0 and p.X < BOX.x1 and p.Z < BOX.z0 and p.Z > BOX.z1
			if whole or (inBox and not string.find(c.Name, "^Bridge_")) then
				c:SetAttribute("From", "Decor")
				c.Parent = hold
			end
		end
	end
	for _, n in { "HaloNPCTest", "ReviewV3" } do
		local f = workspace:FindFirstChild(n)
		if f then f:SetAttribute("From", "Workspace") f.Parent = hold end
	end
end
-- the old marble gate / sign / landmarks inside the box stand in the way of the grey gate: keep them too (every run, so a
-- hold made before this rule also gets them)
local mapf = workspace:FindFirstChild("Map")
for _, fname in { "Gates", "Landmarks" } do
	local f = mapf and mapf:FindFirstChild(fname)
	if f then
		for _, c in f:GetChildren() do
			local p
			if c:IsA("BasePart") then p = c.Position elseif c:IsA("Model") then p = c:GetPivot().Position end
			if p and p.X > BOX.x0 and p.X < BOX.x1 and p.Z < BOX.z0 + 8 and p.Z > BOX.z1 then
				c:SetAttribute("From", "Map." .. fname)
				c.Parent = hold
			end
		end
	end
end
-- terrain: rewrite only the Terrain (sea ring / rim / underside); HaloV2 (grey boxes, skeletons, Ground parts) stays
if MODE ~= "terrain" then
	if root then root:Destroy() end
	root = Instance.new("Folder")
	root.Name = "HaloV2"
	root:SetAttribute("Why", "A23-121 3단계 회색 상자: docs/design/halo_plan_v2_2026-10-11.json")
	root.Parent = workspace
end

-- terrain: clear the box, sea everywhere, then every land column written voxel by voxel (WriteVoxels on the 4-stud grid).
-- FillBlock with 2-stud layers inside 4-stud voxels left the surface 2 studs off (y=0 land sank to -2.3 under the sea,
-- y=10 came out 12; 10/11 photos), so each voxel gets an exact occupancy: land up to the cell's height (the voxel holding
-- the surface is partial), the top 4 studs in the cell's material, rock below; stream / pool beds sit on the voxel line
-- under their height with water up to height + 1.2; the sea is sand at -20 with water up to WATER_TOP.
local reg = region()
T:FillBlock(reg.CFrame, reg.Size, Enum.Material.Air)
clearWideSea()
local seaY0 = -24 -- the deep sea floor (dark basalt)
-- sea tiers from halo_blockout.py: 0 deep, 1 sand shelf off the north beach, 2 cliff foot, 3 the ring's rock rim (dry, just
-- above the water), 4 nothing (outside the ring the islands float: no water, no base)
local SEA_FLOOR = { [0] = { -24, Enum.Material.Basalt }, [1] = { -6, Enum.Material.Sand }, [2] = { -14, Enum.Material.Basalt },
	[3] = { 1.6, Enum.Material.Rock } }
-- 2차 10/11 (검수: from the side the sea ring hung as a blue water wall): the rim is 4 cells wide (2 showed LOD holes), stands 1.8..4.8 above the
-- water (uneven per cell) and its rock goes down past the sea floor into the underside, so the water ends inside rock
local RIM_DOWN = seaY0 - 6
local A = D.alph
local idx = {}
for i = 1, #A do idx[string.sub(A, i, i)] = i - 1 end
local VY0, VY1 = -232, 96 -- -232: the deepest underside spike (ground ~ 0, depth <= 216, 2차 10/11) stays inside
local NY = (VY1 - VY0) / 4
local NX, NZ = D.cols, D.rows
local zMin = D.z0 - NZ * D.cell
local vreg = Region3.new(Vector3.new(D.x0, VY0, zMin) + OFF, Vector3.new(D.x0 + NX * D.cell, VY1, D.z0) + OFF)
-- measured 10/11 (ReadVoxels + raycast): the drawn surface sits 2 studs above the fill level (a full voxel 8..12 under air
-- reads 14, a half voxel 8..10 reads 12, the same for FillBlock), so every fill level here is the wanted height - SURF
local SURF = 2
local mats, occs = {}, {}
local cells = 0
local Air, Water, Rock, Mud, Sand = Enum.Material.Air, Enum.Material.Water, Enum.Material.Rock, Enum.Material.Mud, Enum.Material.Sand
local Basalt = Enum.Material.Basalt
for ix = 1, NX do
	local mx, ox = {}, {}
	mats[ix], occs[ix] = mx, ox
	for iy = 1, NY do
		mx[iy], ox[iy] = {}, {}
	end
	for iz = 1, NZ do
		local r = NZ - iz + 1 -- row 1 = the north edge (z0)
		local m = string.sub(D.m[r], ix, ix)
		local land, top, wtop
		-- rock hanging under the ground / ring floor (halo_blockout.py: D.und, chars of D.und_unit studs); at least the 4-stud
		-- top layer stays so edge cells (depth 0..3) are not paper thin
		local und = idx[string.sub(D.und[r], ix, ix)] * D.und_unit
		if m == "s" then
			local k = idx[string.sub(D.h[r], ix, ix)]
			local tier = SEA_FLOOR[k]
			if not tier then
				land, top, wtop = VY0 - 8, Rock, nil -- nothing
				und = 0
			else
				land, top, wtop = tier[1] - SURF, tier[2], (k ~= 3) and WATER_TOP or nil
				if k == 3 then land += ((ix * 7 + iz * 13) % 4) * 1.0 end -- uneven rocky top
				und = land - RIM_DOWN + und -- every ring cell (water floor or rim) goes down past the sea floor
			end
		else
			local y = idx[string.sub(D.h[r], ix, ix)] - D.hoff
			cells += 1
			if m == "w" then
				land, top, wtop = math.floor((y - 3) / 4) * 4, Mud, y + 1.2 -- bed on a voxel line, drawn 1..5 under y
			else
				land, top, wtop = y - SURF, MAT[m] or Enum.Material.Grass, nil
			end
			if land + SURF < WATER_TOP then wtop = math.max(wtop or WATER_TOP, WATER_TOP) end -- low shore cells stay under the sea
		end
		-- solid from `bottom` up to `land`: the SURF rule is not applied to the underside (hidden, <= 2 studs off is fine)
		local bottom = math.max(land - math.max(und, 4), VY0)
		for iy = 1, NY do
			local yb = VY0 + (iy - 1) * 4
			local lo = math.clamp((math.min(yb + 4, land) - math.max(yb, bottom)) / 4, 0, 1)
			if lo > 0 then
				if yb + 4 > land - 3 then
					mx[iy][iz] = top
				elseif yb < bottom + 4 then
					mx[iy][iz] = Basalt -- the lowest 1-2 voxels
				else
					mx[iy][iz] = Rock
				end
				ox[iy][iz] = lo
			elseif wtop and yb >= land and wtop - SURF > yb then -- water only above the ground, never under the hanging rock
				mx[iy][iz] = Water
				ox[iy][iz] = math.clamp((wtop - SURF - yb) / 4, 0, 1)
			else
				mx[iy][iz] = Air
				ox[iy][iz] = 0
			end
		end
	end
end
T:WriteVoxels(vreg, 4, mats, occs)
if MODE == "terrain" then return "halo_blockout terrain only: " .. cells .. " land cells, VY0 " .. VY0 end
local runs = NX * NZ

-- grey building shells: walls 1 thick, a door hole on the door face, floor slabs for upper floors (with a stair hole),
-- a roof slab; the ground floor is the Terrain (never a part)
local bf = Instance.new("Folder")
bf.Name = "Buildings"
bf.Parent = root
local function part(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function label(parent, adornee, text, h)
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(160, 36)
	bg.StudsOffsetWorldSpace = Vector3.new(0, h or 4, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 400
	bg.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 0.35
	t.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(30, 30, 40)
	t.Text = text
	t.Parent = bg
	bg.Parent = parent
end
local nb = 0
-- 10/11 stage 4: a skeleton master (tools/skeleton_civic.py, ServerStorage.HaloSkeletons) replaces the grey box when its plan pose
-- (x, z, yaw, ground_y) still matches the plan and the apply is not offset; otherwise the grey box is built
local skMasters = SS:FindFirstChild("HaloSkeletons")
for _, b in D.buildings do
	local sk = skMasters and OFF.Magnitude == 0 and skMasters:FindFirstChild(b.id)
	if sk and sk:GetAttribute("PlanPose") == string.format("%g,%g,%g,%g", b.x, b.z, b.yaw, b.ground_y) then
		sk:Clone().Parent = bf
		nb += 1
		continue
	end
	local m = Instance.new("Model")
	m.Name = b.id
	for k, v in { Kind = b.kind, District = b.district, Floors = b.floors, FloorH = b.floor_h, Note = b.note } do m:SetAttribute(k, v) end
	m:SetAttribute("DoorFront", Vector3.new(b.door_dir[1], 0, b.door_dir[2]))
	m:SetAttribute("DoorSize", Vector2.new(b.door_size[1], b.door_size[2]))
	local yaw = math.rad(b.yaw)
	local base = CFrame.new(Vector3.new(b.x, b.ground_y, b.z) + OFF) * CFrame.Angles(0, yaw + math.pi, 0)
	-- local frame: -Z = the door side (CFrame.Angles(0, yaw + pi) turns local -Z to the door direction (sin yaw, cos yaw))
	local w, d, h = b.w, b.d, b.h
	local col = COL[b.kind] or Color3.fromRGB(200, 200, 200)
	local th = 1
	local dw, dh = b.door_size[1], b.door_size[2]
	if b.kind == "Gate" then
		local pw = (w - dw) / 2
		part(m, "PillarL", Vector3.new(pw, h, d), base * CFrame.new(-(dw / 2 + pw / 2), h / 2, 0), col)
		part(m, "PillarR", Vector3.new(pw, h, d), base * CFrame.new(dw / 2 + pw / 2, h / 2, 0), col)
		part(m, "Lintel", Vector3.new(dw, h - dh, d), base * CFrame.new(0, dh + (h - dh) / 2, 0), col)
	else
		part(m, "WallBack", Vector3.new(w, h, th), base * CFrame.new(0, h / 2, d / 2 - th / 2), col)
		part(m, "WallL", Vector3.new(th, h, d), base * CFrame.new(-w / 2 + th / 2, h / 2, 0), col)
		part(m, "WallR", Vector3.new(th, h, d), base * CFrame.new(w / 2 - th / 2, h / 2, 0), col)
		local side = (w - dw) / 2
		part(m, "FrontL", Vector3.new(side, h, th), base * CFrame.new(-(dw / 2 + side / 2), h / 2, -d / 2 + th / 2), col)
		part(m, "FrontR", Vector3.new(side, h, th), base * CFrame.new(dw / 2 + side / 2, h / 2, -d / 2 + th / 2), col)
		part(m, "FrontTop", Vector3.new(dw, h - dh, th), base * CFrame.new(0, dh + (h - dh) / 2, -d / 2 + th / 2), col)
		local door = part(m, "DoorHole", Vector3.new(dw, dh, 0.2), base * CFrame.new(0, dh / 2, -d / 2 - 0.2), Color3.fromRGB(200, 40, 40))
		door.Transparency = 0.7
		door.CanCollide = false
		for f = 1, b.floors - 1 do
			local y = f * b.floor_h
			if y < h - 2 then
				-- a slab with a 6 x 6 stair hole in the back-left corner: two pieces
				part(m, "Floor" .. f .. "a", Vector3.new(w - 2, 0.6, d - 8), base * CFrame.new(0, y, -4), col:Lerp(Color3.new(1, 1, 1), 0.2))
				part(m, "Floor" .. f .. "b", Vector3.new(w - 8, 0.6, 6), base * CFrame.new(3, y, d / 2 - 4), col:Lerp(Color3.new(1, 1, 1), 0.2))
			end
		end
		part(m, "Roof", Vector3.new(w, 0.8, d), base * CFrame.new(0, h + 0.4, 0), col:Lerp(Color3.new(0, 0, 0), 0.08))
	end
	m.PrimaryPart = m:FindFirstChild("WallBack") or m:FindFirstChild("Lintel")
	label(m, m.PrimaryPart, b.id .. "  " .. b.w .. "x" .. b.d .. " " .. b.floors .. "F", m.PrimaryPart.Size.Y / 2 + 3)
	m.Parent = bf
	nb += 1
end

-- bridges: decks across the stream along the road there (Bridge_* = ground for the code)
local brf = Instance.new("Folder")
brf.Name = "Bridges"
brf.Parent = root
local function roadDir(at)
	local best, dir = math.huge, Vector3.new(1, 0, 0)
	for _, rd in D.roads do
		for i = 1, #rd.pts - 1 do
			local a = Vector3.new(rd.pts[i][1], 0, rd.pts[i][2])
			local b2 = Vector3.new(rd.pts[i + 1][1], 0, rd.pts[i + 1][2])
			local ab = b2 - a
			local t = math.clamp((at - a):Dot(ab) / ab:Dot(ab), 0, 1)
			local dd = (a + ab * t - at).Magnitude
			if dd < best then best, dir = dd, ab.Unit end
		end
	end
	return dir
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
rp.IgnoreWater = true
for _, br in D.bridges do
	local at = Vector3.new(br.at[1], 0, br.at[2]) + OFF
	local dir = br.dir and Vector3.new(br.dir[1], 0, br.dir[2]) or roadDir(Vector3.new(br.at[1], 0, br.at[2])) -- plan: its own road
	local y = 0
	for _, s in { -1, 1 } do
		local hit = workspace:Raycast(at + dir * s * (br.len / 2 + 1) + Vector3.new(0, 120, 0), Vector3.new(0, -200, 0), rp)
		if hit then y = math.max(y, hit.Position.Y) end
	end
	local p = part(brf, "Bridge_" .. br.id, Vector3.new(10, 1, br.len + 4), CFrame.lookAt(at + Vector3.new(0, y + 0.1, 0), at + Vector3.new(0, y + 0.1, 0) + dir),
		Color3.fromRGB(150, 115, 80))
	p:SetAttribute("Kind", br.kind)
	label(brf, p, br.id .. " " .. br.kind, 3)
end

-- fixed points + the first 10 minutes + avatar-size blocks
local mk = Instance.new("Folder")
mk.Name = "Markers"
mk.Parent = root
local function marker(name, x, z, color, text)
	local top = workspace:Raycast(Vector3.new(x, 150, z) + OFF, Vector3.new(0, -300, 0), rp)
	local y = top and top.Position.Y or 0
	local p = part(mk, name, Vector3.new(2, 5, 1), CFrame.new(Vector3.new(x, y + 2.5, z) + OFF), color) -- avatar-size block
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	label(mk, p, text, 4)
end
marker("Spawn", 0, -420, Color3.fromRGB(255, 80, 160), "1 Spawn")
for _, k in D.fixed.keep do
	if k.at and k.name ~= "스폰 + 보는 쪽" then marker("Keep_" .. k.name, k.at[1], k.at[2], Color3.fromRGB(60, 60, 60), k.name) end
end
for _, mv in D.fixed.move do
	if mv.new_xyz then marker("Move_" .. mv.name, mv.new_xyz[1], mv.new_xyz[3], Color3.fromRGB(40, 150, 255), mv.name) end
end
for _, s in D.first10 do
	if s.n ~= 1 and s.at then marker("First10_" .. s.n, s.at[1], s.at[2], Color3.fromRGB(255, 80, 160), s.n .. " " .. s.what) end
end
for _, pd in D.fixed.pads do
	local p = part(mk, pd.name, Vector3.new(8, 0.4, 8), CFrame.new(Vector3.new(pd.at[1], pd.at[2], pd.at[3]) + OFF), Color3.fromRGB(110, 220, 110))
	p.CanCollide = false
end
return string.format("halo_blockout applied: terrain cells %d (%d columns, voxels), buildings %d, bridges %d, markers %d", cells, runs, nb, #D.bridges,
	#mk:GetChildren())
