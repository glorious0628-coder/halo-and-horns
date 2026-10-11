-- halo_blockout.luau (이미지 생성 1, 2026-10-11, SPEC A23-121 3단계 '회색 상자'). WorldKit ONLY (Edit mode).
-- Built by tools/halo_blockout.py (py tools/halo_blockout.py --mode apply|remove|plan) -> build/wk/halo_blockout_apply.lua
-- apply : first time keeps the old Halo (Terrain region copy + the old Halo decor) in ServerStorage.HaloV1Hold, then clears
--         the Halo box and builds: Terrain land / roads / ramps / stairs (Slate) / stream + pools / sea, grey building
--         shells at real size with door holes (floors stay Terrain: the code only counts Terrain and Bridge_* as ground),
--         bridges (Workspace.HaloV2.Bridges.Bridge_B1..), fixed-point markers and avatar-size blocks. Re-run = rebuild.
-- remove: deletes Workspace.HaloV2, puts the old Terrain region and the old decor back.
-- plan  : counts only.
if string.find(game.Name, "GoodEvil") or game.PlaceId == 81671223175574 then error("main Studio: halo_blockout is WorldKit-only") end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local MODE = "__MODE__"
local D = game:GetService("HttpService"):JSONDecode([[__DATA__]])
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local OFF = Vector3.new(D.offset[1], 0, D.offset[2])
local BOX = { x0 = -214, x1 = 214, z0 = -322, z1 = -714, y0 = -24, y1 = 96 }
local MAT = {
	g = Enum.Material.Grass, d = Enum.Material.Ground, c = Enum.Material.Concrete, b = Enum.Material.Cobblestone,
	p = Enum.Material.Pavement, t = Enum.Material.Slate, w = Enum.Material.Mud, r = Enum.Material.Rock, n = Enum.Material.Sand,
}
local COL = {
	Gate = Color3.fromRGB(205, 195, 170), Tower = Color3.fromRGB(190, 190, 198), Shop = Color3.fromRGB(214, 200, 182),
	HouseA = Color3.fromRGB(200, 200, 204), HouseB = Color3.fromRGB(186, 190, 196), Castle = Color3.fromRGB(160, 168, 186),
	Cathedral = Color3.fromRGB(222, 218, 232), Armory = Color3.fromRGB(176, 166, 150),
}
local WATER_TOP = -1.2

local function region()
	local a = Vector3.new(BOX.x0, BOX.y0, BOX.z1) + OFF
	local b = Vector3.new(BOX.x1, BOX.y1, BOX.z0) + OFF
	-- Region3 needs a multiple of 4 and a grid alignment
	return Region3.new(a, b):ExpandToGrid(4)
end

local function cells16()
	local reg = region()
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
		local reg = region()
		T:FillBlock(reg.CFrame, reg.Size, Enum.Material.Air)
		local tr = hold:FindFirstChild("TerrainHalo")
		if tr then
			local _, corner = cells16()
			T:PasteRegion(tr, corner, true)
		end
		local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
		local back = 0
		for _, c in hold:GetChildren() do
			if c.Name ~= "TerrainHalo" then
				local dest = c:GetAttribute("From")
				if dest == "Workspace" then c.Parent = workspace elseif decor then c.Parent = decor end
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
	local r16 = cells16()
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
if root then root:Destroy() end
root = Instance.new("Folder")
root.Name = "HaloV2"
root:SetAttribute("Why", "A23-121 3단계 회색 상자: docs/design/halo_plan_v2_2026-10-11.json")
root.Parent = workspace

-- terrain: clear the box, sea everywhere, then land columns (row runs of equal height + material merged)
local reg = region()
T:FillBlock(reg.CFrame, reg.Size, Enum.Material.Air)
local seaY0 = -20
local function block(x0, x1, z, y0, y1, mat)
	if y1 - y0 < 0.05 then return end
	local cx, cz = (x0 + x1) / 2, z
	T:FillBlock(CFrame.new(Vector3.new(cx, (y0 + y1) / 2, cz) + OFF), Vector3.new(x1 - x0, y1 - y0, D.cell), mat)
end
local A = D.alph
local idx = {}
for i = 1, #A do idx[string.sub(A, i, i)] = i - 1 end
-- the sea floor + sea water under the whole box
T:FillBlock(CFrame.new(Vector3.new((BOX.x0 + BOX.x1) / 2, seaY0 - 2, (BOX.z0 + BOX.z1) / 2) + OFF),
	Vector3.new(BOX.x1 - BOX.x0, 4, BOX.z0 - BOX.z1), Enum.Material.Sand)
T:FillBlock(CFrame.new(Vector3.new((BOX.x0 + BOX.x1) / 2, (seaY0 + WATER_TOP) / 2, (BOX.z0 + BOX.z1) / 2) + OFF),
	Vector3.new(BOX.x1 - BOX.x0, WATER_TOP - seaY0, BOX.z0 - BOX.z1), Enum.Material.Water)
local cells, runs = 0, 0
for r = 1, D.rows do
	local hs, ms = D.h[r], D.m[r]
	local z = D.z0 - (r - 1) * D.cell - D.cell / 2
	local c = 1
	while c <= D.cols do
		local m = string.sub(ms, c, c)
		local hv = idx[string.sub(hs, c, c)]
		local e = c
		while e + 1 <= D.cols and string.sub(ms, e + 1, e + 1) == m and string.sub(hs, e + 1, e + 1) == string.sub(hs, c, c) do e += 1 end
		if m ~= "s" then
			local y = hv - D.hoff
			local x0 = D.x0 + (c - 1) * D.cell
			local x1 = D.x0 + e * D.cell
			-- rock body, then a 2-stud top of the cell's material, water on top of stream / pool beds
			block(x0, x1, z, seaY0, y - 2, Enum.Material.Rock)
			if m == "w" then
				block(x0, x1, z, y - 2, y, Enum.Material.Mud)
				block(x0, x1, z, y, y + 1.2, Enum.Material.Water)
			else
				block(x0, x1, z, y - 2, y, MAT[m] or Enum.Material.Grass)
			end
			cells += e - c + 1
			runs += 1
		end
		c = e + 1
	end
end

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
for _, b in D.buildings do
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
	local dir = roadDir(Vector3.new(br.at[1], 0, br.at[2]))
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
	if s.n ~= 1 then marker("First10_" .. s.n, s.at[1], s.at[2], Color3.fromRGB(255, 80, 160), s.n .. " " .. s.what) end
end
for _, pd in D.fixed.pads do
	local p = part(mk, pd.name, Vector3.new(8, 0.4, 8), CFrame.new(Vector3.new(pd.at[1], pd.at[2], pd.at[3]) + OFF), Color3.fromRGB(110, 220, 110))
	p.CanCollide = false
end
return string.format("halo_blockout applied: terrain cells %d (%d runs), buildings %d, bridges %d, markers %d", cells, runs, nb, #D.bridges,
	#mk:GetChildren())
