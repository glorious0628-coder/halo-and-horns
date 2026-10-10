-- 스튜디오 편집 모드 지도 빌더 — 세계 지도 v2 (SPEC A23-53) (Studio MCP execute_luau 로 실행: py tools/map_v2_apply.py).
-- MODE (러너가 아래 "__MODE__" 자리를 바꾼다. 그대로 실행하면 안전한 "terrain"):
--   "terrain" = 땅·물·길·산만 다시: Terrain(땅·모래 해변·물·지역 바닥·호박밭/유령 숲 흙·고갯길 산·바다 바위) +
--               Map.Zones(계약 파트) 크기·자리 맞춤 + Map.Walls 새 경계 + Decor 의 다리(Bridge_*)·길(Roads)·PvP 경계 다시 +
--               Map.Gates 를 새 자리로 옮김. 교차로 키트·성·마을 장식·랜드마크·NPC·조명·발판은 손대지 않는다.
--               바꾼 옛 다리·길·경계·벽은 ServerStorage.MapV1Backup 에 넣어 둔다(되돌리기).
--   "full"    = 빈 place 전용: workspace.Map 을 지우고 지형 + 기본 장식(v4 모양) + 기능 파트를 모두 새로 만든다.
--               실제 게임 place 에서는 쓰지 않는다(키트·성·장식이 모두 사라짐).
-- 구조는 TECH_SPEC 의 MapBuilder 계약: workspace.Map/{Ground,Zones,Walls,Gates,Pads,Landmarks,Decor}.
-- 숫자는 Config.Map / Config.Zones (지도 v2) 와 같다 — tools/test_map_v2.py 가 비교한다.
-- 그림 지도(art/review/worldmap/WorldMap_v2_A2_2.jpg)처럼 해안은 모래 해변(산 능선으로 둘러싸지 않음), 산은 숲과 유적
-- 사이 고갯길 띠에만. 규칙: Atmosphere 금지(A9-3), 재질은 SmoothPlastic 위주, Neon 은 강조에만, 작은 소품은 그림자/충돌 끔.

local MODE = "__MODE__"
if MODE ~= "full" then MODE = "terrain" end

local rng = Random.new(42)
local RGB = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

------------------------------------------------------------------ 지도 v2 숫자 (= Config)
local ZONES = {
	Crossroads = { Name = "Crossroads", Center = Vector3.new(0, 0, 0), Size = Vector3.new(300, 0, 300), MinLevel = 1, PvP = false,
		Color = RGB(190, 176, 150), Material = Enum.Material.Cobblestone, Spawn = Vector3.new(0, 0, -25) },
	HaloTown = { Name = "Halo Citadel", Center = Vector3.new(0, 0, -515), Size = Vector3.new(400, 0, 370), MinLevel = 1, PvP = false,
		Color = RGB(228, 218, 190), Material = Enum.Material.Marble, Spawn = Vector3.new(0, 0, -420) },
	HornsTown = { Name = "Horns Den", Center = Vector3.new(0, 0, 515), Size = Vector3.new(400, 0, 370), MinLevel = 1, PvP = false,
		Color = RGB(70, 40, 45), Material = Enum.Material.Slate, Spawn = Vector3.new(0, 0, 420) },
	SlimeMeadow = { Name = "Squishy Meadow", Center = Vector3.new(430, 0, 0), Size = Vector3.new(440, 0, 480), MinLevel = 1, PvP = false,
		Color = RGB(115, 195, 95), Material = Enum.Material.Grass, Spawn = Vector3.new(230, 0, 0) },
	PumpkinPatch = { Name = "Pumpkin Patch", Center = Vector3.new(535, 0, 335), Size = Vector3.new(230, 0, 190), MinLevel = 1, PvP = false,
		Color = RGB(150, 118, 72), Material = Enum.Material.Mud, Spawn = Vector3.new(535, 0, 255), Season = "Halloween" },
	HauntedHollow = { Name = "Haunted Hollow", Center = Vector3.new(320, 0, 342.5), Size = Vector3.new(200, 0, 175), MinLevel = 1, PvP = false,
		Color = RGB(118, 106, 150), Material = Enum.Material.Asphalt, Spawn = Vector3.new(400, 0, 340), Season = "Halloween" },
	GoblinWoods = { Name = "Goblin Woods", Center = Vector3.new(950, 0, 0), Size = Vector3.new(480, 0, 520), MinLevel = 10, PvP = true,
		Color = RGB(60, 125, 55), Material = Enum.Material.Grass, Spawn = Vector3.new(730, 0, 0) },
	SkeletonRuins = { Name = "Skeleton Ruins", Center = Vector3.new(1520, 0, 0), Size = Vector3.new(520, 0, 580), MinLevel = 25, PvP = true,
		Color = RGB(135, 125, 108), Material = Enum.Material.Slate, Spawn = Vector3.new(1280, 0, 0) },
}
local ZONE_ORDER = { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "PumpkinPatch", "HauntedHollow", "GoblinWoods", "SkeletonRuins" }
local BOUNDS = { MinX = -260, MaxX = 1840, MinZ = -720, MaxZ = 720 }
local WALL_HEIGHT = 80 -- Config.Map.WallHeight
local WATER_TOP = -1.2 -- Config.Map.WaterTop
-- land pieces (= Config.Map.Lands); Floor = the land's own ground material (zone floors paint over it below)
local LANDS = {
	{ Name = "LandCrossroads", MinX = -150, MaxX = 150, MinZ = -150, MaxZ = 150, Floor = Enum.Material.Grass },
	{ Name = "LandMeadow", MinX = 210, MaxX = 650, MinZ = -240, MaxZ = 240, Floor = Enum.Material.Grass },
	{ Name = "LandWoods", MinX = 710, MaxX = 1190, MinZ = -260, MaxZ = 260, Floor = Enum.Material.LeafyGrass },
	{ Name = "LandPass", MinX = 1190, MaxX = 1260, MinZ = -260, MaxZ = 260, Floor = Enum.Material.Rock },
	{ Name = "LandRuins", MinX = 1260, MaxX = 1780, MinZ = -290, MaxZ = 290, Floor = Enum.Material.Ground },
	{ Name = "IslandHalo", MinX = -200, MaxX = 200, MinZ = -700, MaxZ = -330, Floor = Enum.Material.Limestone },
	{ Name = "IslandHorns", MinX = -200, MaxX = 200, MinZ = 330, MaxZ = 700, Floor = Enum.Material.Basalt },
	{ Name = "LandPumpkinPatch", MinX = 420, MaxX = 650, MinZ = 240, MaxZ = 430, Floor = Enum.Material.Mud, Season = "Halloween" },
	{ Name = "LandHauntedHollow", MinX = 220, MaxX = 420, MinZ = 255, MaxZ = 430, Floor = Enum.Material.Asphalt, Season = "Halloween" },
}
local BRIDGES = { -- = Config.Map.Bridges
	{ Name = "Meadow", From = Vector3.new(150, 0, 0), To = Vector3.new(210, 0, 0), Width = 22, Style = "Wood" },
	{ Name = "Goblin", From = Vector3.new(650, 0, 0), To = Vector3.new(710, 0, 0), Width = 22, Style = "Goblin" },
	{ Name = "Halo", From = Vector3.new(0, 0, -150), To = Vector3.new(0, 0, -330), Width = 22, Style = "Halo" },
	{ Name = "Horns", From = Vector3.new(0, 0, 150), To = Vector3.new(0, 0, 330), Width = 22, Style = "Horns" },
}
local DIRT, PASS_ROCK, RUIN_STONE = RGB(235, 235, 235), RGB(110, 105, 100), RGB(160, 150, 130)
local ROADS = { -- = Config.Map.Roads (the Ground roads get the painted GE_DirtPath tile: near-white 235, never darkened twice)
	{ Name = "RoadCross", MinX = 13, MaxX = 150, MinZ = -9, MaxZ = 9, Color = DIRT, Material = Enum.Material.Ground },
	{ Name = "RoadWest", MinX = -43, MaxX = -13, MinZ = -9, MaxZ = 9, Color = RGB(160, 155, 145), Material = SP },
	{ Name = "RoadMeadow", MinX = 210, MaxX = 650, MinZ = -9, MaxZ = 9, Color = DIRT, Material = Enum.Material.Ground },
	{ Name = "RoadWoods", MinX = 710, MaxX = 1190, MinZ = -9, MaxZ = 9, Color = DIRT, Material = Enum.Material.Ground },
	{ Name = "RoadPass", MinX = 1190, MaxX = 1260, MinZ = -9, MaxZ = 9, Color = PASS_ROCK, Material = Enum.Material.Slate },
	{ Name = "RoadRuins", MinX = 1260, MaxX = 1684, MinZ = -9, MaxZ = 9, Color = RUIN_STONE, Material = Enum.Material.Slate },
	{ Name = "RoadNorth", MinX = -8, MaxX = 8, MinZ = -150, MaxZ = -10, Color = RGB(170, 150, 130), Material = Enum.Material.Slate },
	{ Name = "RoadNorthIsland", MinX = -8, MaxX = 8, MinZ = -600, MaxZ = -330, Color = RGB(170, 150, 130), Material = Enum.Material.Slate },
	{ Name = "RoadSouth", MinX = -8, MaxX = 8, MinZ = 10, MaxZ = 150, Color = RGB(150, 115, 105), Material = Enum.Material.Slate },
	{ Name = "RoadSouthIsland", MinX = -8, MaxX = 8, MinZ = 330, MaxZ = 600, Color = RGB(150, 115, 105), Material = Enum.Material.Slate },
	{ Name = "RoadMeadowLoop", MinX = 260, MaxX = 600, MinZ = -125, MaxZ = -115, Color = DIRT, Material = Enum.Material.Ground },
	{ Name = "RoadWoodsTrail", MinX = 760, MaxX = 1120, MinZ = -155, MaxZ = -145, Color = DIRT, Material = Enum.Material.Ground },
	{ Name = "RoadRuinsSouth", MinX = 1300, MaxX = 1700, MinZ = 145, MaxZ = 155, Color = RUIN_STONE, Material = Enum.Material.Slate },
	-- season roads: painted as pumpkin soil on the Terrain (no parts), so nothing floats there out of season
	{ Name = "RoadPumpkin", MinX = 529, MaxX = 541, MinZ = 9, MaxZ = 330, Season = "Halloween" },
	{ Name = "RoadHollow", MinX = 330, MaxX = 535, MinZ = 335, MaxZ = 345, Season = "Halloween" },
}
local GATES = { -- = Config.Map.Gates
	{ Zone = "SlimeMeadow", Position = Vector3.new(210, 0, 0), AlongX = true, Style = "Meadow" },
	{ Zone = "GoblinWoods", Position = Vector3.new(710, 0, 0), AlongX = true, Style = "Goblin" },
	{ Zone = "SkeletonRuins", Position = Vector3.new(1260, 0, 0), AlongX = true, Style = "Ruins" },
	{ Zone = "HaloTown", Position = Vector3.new(0, 0, -330), AlongX = false, Style = "Halo" },
	{ Zone = "HornsTown", Position = Vector3.new(0, 0, 330), AlongX = false, Style = "Horns" },
}
local PASS = { X = 1225, HalfZ = 70, MinX = 1190, MaxX = 1260, MinZ = -260, MaxZ = 260 } -- Config.Map.PassX / PassHalfZ / LandPass
local ALTAR = Vector3.new(0, 0, 45)
local BOARD = Vector3.new(-55, 0, 0)
local GOOSE_NEST = Vector3.new(-30, 0, 30)
local PADS = { -- Config.Map.Pads 와 같은 값 (CR-M22: 동쪽 큰길(|z| <= 9) 밖)
	{ Dest = "SlimeMeadow", Position = Vector3.new(52, 0, -24) },
	{ Dest = "GoblinWoods", Position = Vector3.new(52, 0, 24) },
	{ Dest = "SkeletonRuins", Position = Vector3.new(68, 0, 24) },
}
local HW = { PathX = 535, PatchGateZ = 240, HollowGate = Vector3.new(420, 0, 340) } -- Config.Map.Halloween
local DANGER = { Safe = RGB(80, 220, 120), PvP = RGB(255, 150, 40), Extreme = RGB(255, 60, 60) }
local function dangerOf(zoneId)
	if zoneId == "SkeletonRuins" then return DANGER.Extreme end
	if zoneId == "GoblinWoods" then return DANGER.PvP end
	return DANGER.Safe
end

------------------------------------------------------------------ Map 폴더 + 보관함
local SS = game:GetService("ServerStorage")
local map = workspace:FindFirstChild("Map")
if MODE == "full" and map then
	map:Destroy()
	map = nil
end
local fresh = map == nil
if fresh then
	map = Instance.new("Folder")
	map.Name = "Map"
end
local folders = {}
for _, n in { "Ground", "Zones", "Walls", "Gates", "Pads", "Landmarks", "Decor" } do
	local f = map:FindFirstChild(n)
	if not f then
		f = Instance.new("Folder")
		f.Name = n
		f.Parent = map
	end
	folders[n] = f
end
local backup = nil
local function stash(inst) -- terrain mode: the replaced old piece goes to ServerStorage.MapV1Backup/<folder>
	if not backup then
		backup = SS:FindFirstChild("MapV1Backup") or Instance.new("Folder")
		backup.Name = "MapV1Backup"
		backup.Parent = SS
	end
	local sub = backup:FindFirstChild(inst.Parent.Name) or Instance.new("Folder")
	sub.Name = inst.Parent.Name
	sub.Parent = backup
	inst.Parent = sub
end
local count, lights, report = 0, 0, {}
local function note(s) table.insert(report, s) end

local function part(props, parent, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.Locked = true
	p.Material = SP
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then p.Shape = props.Shape end
	for k, v in props do
		if k ~= "Shape" then p[k] = v end
	end
	local s = p.Size
	if math.max(s.X, s.Y, s.Z) < 4 or p.Material == NEON then p.CastShadow = false end
	p.Parent = parent
	count += 1
	return p
end
local function prop(props, parent, class) -- 작은 장식: 충돌·조회·터치 끔
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props, parent, class)
end
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function light(p, color, range, brightness)
	if lights >= 40 then return end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(range or 16, 40)
	l.Brightness = math.min(brightness or 1.5, 2)
	l.Shadows = false
	l.Parent = p
	lights += 1
end
local function billboard(adornee, text, offsetY, color, width, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 260, 46)
	bb.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = maxDist or 150
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.RichText = true
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Parent = t
	t.Parent = bb
	bb.Parent = adornee
	return bb
end
local function cyl(props, parent) -- 세로 원기둥: Size = (지름, 높이, 지름)
	local d, h = props.Size.X, props.Size.Y
	props.Size = Vector3.new(h, d, d)
	props.CFrame = CFrame.new(props.Position) * CFrame.Angles(0, 0, math.rad(90))
	props.Position = nil
	props.Shape = Enum.PartType.Cylinder
	return part(props, parent)
end
local function disc(pos, diameter, thickness, color, parent, material)
	return cyl({ Name = "Disc", Size = Vector3.new(diameter, thickness, diameter), Position = pos, Color = color, Material = material or SP, CanCollide = false }, parent)
end
local function ring(center, radius, n, size, color, parent, material) -- 수평 링 (블록 조각 n 개)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		prop({ Name = "RingSeg", Size = size, CFrame = CFrame.new(center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)) * CFrame.Angles(0, -a, 0),
			Color = color, Material = material or NEON }, parent)
	end
end

------------------------------------------------------------------ 지형 (두 모드 공통)
-- 지도 v2 지형 (A23-74 보강, 검수 2026-10-07 — 사용자: "기본 지형 덩어리라 우리 그림이랑 안 맞아 튄다"). 그림 지도
-- A2_2 처럼 만든다:
--   땅   = 둥근 모서리 + 천천히 출렁이는 해안. 같은 섬 묶음(초원+호박밭+유령 숲, 숲+고갯길+유적)은 매끈하게 이어지고,
--          다른 섬과는 물길이 T.Channel 이상 남는다. 윗면 Y = 0 평평(놀이 땅은 안 깎음: 해안은 땅 조각 밖으로만 나감).
--   해안 = 모래 띠가 물속으로 완만하게(얕은 물이 밝게 보임). 다리 끝은 부두처럼 Y = 0 그대로(길이 물에 안 빠짐).
--   산   = 고갯길 띠에만 둥근 원뿔(공 덩어리 없음). 길목 |z| < PASS.HalfZ 는 평평, 바다 쪽으로는 완만하게 내려감.
--   바다 바위 = 지형 공 대신 3D 바위(ServerStorage.WorldKit3D 의 W_Boulder_A/B; 없으면 건너뜀) → Decor.SeaRocks.
-- 칸 쓰기: Terrain:WriteVoxelChannels(땅과 물이 한 칸을 나눠 씀 = 매끈한 물가), 안 되면 WriteVoxels.
-- 색은 MaterialService 그림 타일(GE_*)이 가지므로 재질 색은 거의 흰색(235).
local bw, bd = BOUNDS.MaxX - BOUNDS.MinX, BOUNDS.MaxZ - BOUNDS.MinZ
local cx, cz = (BOUNDS.MinX + BOUNDS.MaxX) / 2, (BOUNDS.MinZ + BOUNDS.MaxZ) / 2
do
	local Terrain = workspace.Terrain
	local M = Enum.Material
	local T = {
		Res = 4, Margin = 1000, Floor = -20, Bottom = -28, DeepSea = 160,
		Base = 9, Amp = 14, MinOut = 2, Channel = 36, Corner = 60, Blend = 50,
		Beach = 12, Sand = 11, Dip = 2.4, Slope = 0.32,
		PinNear = 16, PinFar = 46, PinE = 3, PinBeach = 2.5,
		Shoulder = 36, SeaRocks = 26,
		-- measured in the main Studio (2026-10-07): a solid voxel column renders its surface 2 studs above the occupancy
		-- crossing (water does not), the same +2 the old block-fill notes found: solids are written 2 lower
		Lift = 2,
	}
	Terrain:Clear()
	-- water and grass from the A2_2 map (이미지 생성 1's table, 2026-10-07): the sand shows through the shallow ring;
	-- no realistic grass blades (they made the "default terrain" look; the art is smooth painted grass). Water colour
	-- 2026-10-08 (이미지 생성 1 style #3, 검수 applied in the main Edit): a deeper blue, less see-through, a little shine
	Terrain.WaterColor = RGB(38, 128, 176)
	Terrain.WaterTransparency = 0.4
	Terrain.WaterReflectance = 0.15
	Terrain.WaterWaveSize = 0.05
	Terrain.WaterWaveSpeed = 6
	pcall(function() Terrain.Decoration = false end)
	pcall(function()
		-- A23-29/30: every ground is a painted Firefly tile that carries its own colour, so the materials stay near white
		-- (tools/apply_surface_materials.lua sets the same PAINTED colour)
		for _, m in { M.Grass, M.LeafyGrass, M.Rock, M.Cobblestone, M.Limestone, M.Basalt, M.Ground, M.Slate, M.CrackedLava,
			M.Sand, M.Mud, M.Asphalt } do
			Terrain:SetMaterialColor(m, RGB(235, 235, 235))
		end
	end)

	-- islands: lands of one group melt together (smooth union); groups stay apart
	local GROUP = { LandCrossroads = 1, LandMeadow = 2, LandPumpkinPatch = 2, LandHauntedHollow = 2, LandWoods = 3, LandPass = 3,
		LandRuins = 3, IslandHalo = 4, IslandHorns = 5 }
	local EAST = 3
	local groups, radius = {}, {}
	for i, l in LANDS do
		local g = GROUP[l.Name] or (100 + i)
		groups[g] = groups[g] or {}
		table.insert(groups[g], l)
		radius[l] = math.min(T.Corner, 0.25 * math.min(l.MaxX - l.MinX, l.MaxZ - l.MinZ))
	end
	local function rrect(px, pz, l, r) -- signed distance to the land rect with rounded corners (negative inside)
		local qx = math.abs(px - (l.MinX + l.MaxX) / 2) - ((l.MaxX - l.MinX) / 2 - r)
		local qz = math.abs(pz - (l.MinZ + l.MaxZ) / 2) - ((l.MaxZ - l.MinZ) / 2 - r)
		local ox, oz = math.max(qx, 0), math.max(qz, 0)
		return math.sqrt(ox * ox + oz * oz) + math.min(math.max(qx, qz), 0) - r
	end
	local function nearest(x, z) -- own island distance, next island distance, own group
		local best, second, bestG = math.huge, math.huge, nil
		for g, list in groups do
			local d = nil
			for _, l in list do
				local s = rrect(x, z, l, radius[l])
				if d == nil then
					d = s
				else
					local h = math.max(T.Blend - math.abs(d - s), 0) / T.Blend
					d = math.min(d, s) - h * h * T.Blend * 0.25
				end
			end
			if d < best then
				second, best, bestG = best, d, g
			elseif d < second then
				second = d
			end
		end
		return best, second, bestG
	end

	-- bridge ends: the coast is pinned like a quay (flat to the rect edge, steep into the water)
	local ENDS = {}
	for _, b in BRIDGES do
		table.insert(ENDS, b.From)
		table.insert(ENDS, b.To)
	end
	local function smooth(t) return t * t * (3 - 2 * t) end
	local function pinWeight(x, z) -- 0 at a bridge end, 1 away from every end
		local m = math.huge
		for _, p in ENDS do
			local dx, dz = x - p.X, z - p.Z
			m = math.min(m, math.sqrt(dx * dx + dz * dz))
		end
		if m <= T.PinNear then return 0 end
		if m >= T.PinFar then return 1 end
		return smooth((m - T.PinNear) / (T.PinFar - T.PinNear))
	end
	local function nearBridge(x, z, r)
		for _, b in BRIDGES do
			local a, c = b.From, b.To
			local ab = c - a
			local t = math.clamp(((x - a.X) * ab.X + (z - a.Z) * ab.Z) / (ab.X * ab.X + ab.Z * ab.Z), 0, 1)
			if Vector3.new(x - (a.X + ab.X * t), 0, z - (a.Z + ab.Z * t)).Magnitude < r then return true end
		end
		return false
	end

	-- floor paints (one rule per column, no extra fills)
	local PATCHES, VEINS = {}, {}
	do
		local zr = ZONES.SkeletonRuins
		for _ = 1, 40 do -- slate slabs on the ruins floor
			table.insert(PATCHES, { X = zr.Center.X + rng:NextNumber(-240, 240), Z = zr.Center.Z + rng:NextNumber(-270, 270),
				A = rng:NextNumber(0, 3), HX = rng:NextNumber(6, 15), HZ = rng:NextNumber(6, 15) })
		end
		for _ = 1, 16 do -- lava veins on the Horns island (castle half)
			table.insert(VEINS, { X = rng:NextNumber(-170, 170), Z = rng:NextNumber(450, 680), A = rng:NextNumber(0, 3),
				HX = rng:NextNumber(8, 15), HZ = 2.2 })
		end
	end
	local function inBox(x, z, b)
		local dx, dz = x - b.X, z - b.Z
		local c, s = math.cos(b.A), math.sin(b.A)
		return math.abs(dx * c + dz * s) <= b.HX and math.abs(-dx * s + dz * c) <= b.HZ
	end
	local PUMPKIN = LANDS[8]
	local function floorAt(x, z)
		local land, best = nil, math.huge
		for _, l in LANDS do
			local d = rrect(x, z, l, 0)
			if d < best then land, best = l, d end
		end
		if not land then return M.Grass end
		for _, r in ROADS do -- season roads: pumpkin soil (MapBuilder PATCH.pathMissing then leaves them alone)
			if r.Season and x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then return M.Mud end
		end
		local name = land.Name
		if name == "LandCrossroads" then
			if rrect(x, z, { MinX = -100, MaxX = 100, MinZ = -100, MaxZ = 100 }, 24) <= 0 then return M.Cobblestone end
		elseif name == "LandRuins" then
			for _, p in PATCHES do
				if inBox(x, z, p) then return M.Slate end
			end
		elseif name == "IslandHorns" then
			for _, v in VEINS do
				if inBox(x, z, v) then return M.CrackedLava end
			end
		elseif name == "LandPass" then
			if math.abs(z) < PASS.HalfZ then return M.Ground end
		elseif land == PUMPKIN then
			-- leafy rows every 24 (the rows MapBuilder PATCH.fillLand makes: MinZ + 36, + 60, ...)
			local d = (z - (PUMPKIN.MinZ + 36)) % 24
			if x > PUMPKIN.MinX + 12 and x < PUMPKIN.MaxX - 12 and z < PUMPKIN.MaxZ - 10 and (d < 2 or d >= 22) then
				return M.LeafyGrass
			end
		end
		return land.Floor
	end

	-- pass mountains: round cones (a soft dome on top, no lumps), the corridor stays flat
	local PEAKS = {}
	for _, s in { -1, 1 } do
		local z0, z1 = PASS.HalfZ + 46, PASS.MaxZ + 10
		for i = 0, 3 do
			local h = rng:NextNumber(58, 86) * (i == 0 and 0.8 or 1)
			-- foot radius 1.4 x height: the slopes stay near 45 degrees or gentler (이미지 생성 1 sheet ⑦)
			table.insert(PEAKS, { X = PASS.X + rng:NextNumber(-10, 10), Z = s * (z0 + (z1 - z0) * (i + 0.5) / 4) + rng:NextNumber(-8, 8),
				H = h, R = h * 1.4 })
		end
		for _, side in { -1, 1 } do -- lower shoulders on the woods / ruins side
			for i = 0, 2 do
				local h = rng:NextNumber(28, 44)
				table.insert(PEAKS, { X = PASS.X + side * rng:NextNumber(38, 52),
					Z = s * (z0 + 10 + (z1 - z0 - 20) * (i + 0.5) / 3) + rng:NextNumber(-10, 10), H = h, R = h * 1.5 })
			end
		end
	end
	local function mountain(x, z)
		if x < PASS.MinX - 160 or x > PASS.MaxX + 160 then return 0 end
		local h = 0
		for _, p in PEAKS do
			local dx, dz = x - p.X, z - p.Z
			local r = math.sqrt(dx * dx + dz * dz)
			if r < p.R then h = math.max(h, p.H * (1 - (r / p.R) ^ 1.6) ^ 1.25) end
		end
		local az = math.abs(z)
		if az < PASS.HalfZ + T.Shoulder then h *= smooth(math.clamp((az - PASS.HalfZ) / T.Shoulder, 0, 1)) end
		return h
	end

	-- the slime pond (= Config.StoryQuests.Landmarks.SlimePond): a round basin the sea level fills (water edge about
	-- R + 3), a sand rim, Kit_M_JellyRock stones around it (sheet ⑬: no flat blue plate)
	local PONDS = { { X = 290, Z = 150, R = 18, Rim = 7, Bottom = -4.5 } }
	local function pondAt(x, z) -- basin top (nil = no pond here), sand rim?
		for _, p in PONDS do
			local dx, dz = x - p.X, z - p.Z
			local r = math.sqrt(dx * dx + dz * dz)
			if r <= p.R then return p.Bottom + (-1.8 - p.Bottom) * (r / p.R) ^ 2, true end
			if r < p.R + p.Rim then return -1.8 + 1.8 * smooth((r - p.R) / p.Rim), r < p.R + p.Rim * 0.6 end
		end
		return nil, false
	end

	-- one column: surface height and material
	local function columnAt(x, z)
		local own, other, g = nearest(x, z)
		if own > T.DeepSea then return T.Floor, M.Sand end
		local n = math.noise(x / 110, z / 110, 1.7) + 0.45 * math.noise(x / 47, z / 47, 8.3)
		local out = math.max(T.MinOut, T.Base + T.Amp * n)
		out = math.min(out, math.max(1, (own + other - T.Channel) / 2))
		local w = pinWeight(x, z)
		out = T.PinE + (out - T.PinE) * w
		local beach = T.PinBeach + (T.Beach - T.PinBeach) * w
		local inland = out - own
		local top, sandy
		if inland >= beach then
			top, sandy = 0, false
		elseif inland >= 0 then
			top, sandy = -T.Dip + T.Dip * smooth(inland / beach), inland < T.Sand
		else
			top, sandy = math.max(T.Floor, -T.Dip + inland * T.Slope), true
		end
		local mat = sandy and M.Sand or floorAt(x, z)
		local pt, rim = pondAt(x, z)
		if pt and pt < top then
			top = pt
			if rim then mat = M.Sand end
		end
		if g == EAST then
			local h = mountain(x, z)
			if h > 0.5 then
				h *= smooth(math.clamp((inland + 20) / 50, 0, 1))
				if h > 2 then mat = M.Rock end
				top += h
			end
		end
		return top, mat
	end

	-- write the voxels chunk by chunk (64 x 64 columns), each chunk only as tall as its highest column
	local R = T.Res
	local X0, X1 = math.floor((BOUNDS.MinX - T.Margin) / R) * R, math.ceil((BOUNDS.MaxX + T.Margin) / R) * R
	local Z0, Z1 = math.floor((BOUNDS.MinZ - T.Margin) / R) * R, math.ceil((BOUNDS.MaxZ + T.Margin) / R) * R
	local CH = 64 * R
	local useChannels, chunks = true, 0
	for zc = Z0, Z1 - 1, CH do
		for xc = X0, X1 - 1, CH do
			local nx, nz = math.min(CH, X1 - xc) / R, math.min(CH, Z1 - zc) / R
			local tops, mats, maxTop = {}, {}, T.Floor
			for i = 1, nx do
				local x = xc + (i - 0.5) * R
				for k = 1, nz do
					local top, mat = columnAt(x, zc + (k - 0.5) * R)
					local idx = (i - 1) * nz + k
					tops[idx], mats[idx] = top, mat
					if top > maxTop then maxTop = top end
				end
			end
			local y1 = math.max(R, math.ceil((maxTop + R) / R) * R)
			local ny = (y1 - T.Bottom) / R
			local sm, so, lo = table.create(nx), table.create(nx), table.create(nx)
			for i = 1, nx do
				local mI, oI, lI = table.create(ny), table.create(ny), table.create(ny)
				for j = 1, ny do
					local c = T.Bottom + (j - 0.5) * R
					local lw = math.clamp((WATER_TOP - c) / R + 0.5, 0, 1)
					local mJ, oJ, lJ = table.create(nz), table.create(nz), table.create(nz)
					for k = 1, nz do
						local idx = (i - 1) * nz + k
						local occ = math.clamp((tops[idx] - T.Lift - c) / R + 0.5, 0, 1)
						if useChannels then
							mJ[k], oJ[k], lJ[k] = occ > 0 and mats[idx] or M.Air, occ, occ < 1 and lw or 0
						elseif occ >= 0.5 or lw <= 0 then
							mJ[k], oJ[k] = occ > 0 and mats[idx] or M.Air, occ
						else
							mJ[k], oJ[k] = M.Water, lw
						end
					end
					mI[j], oI[j], lI[j] = mJ, oJ, lJ
				end
				sm[i], so[i], lo[i] = mI, oI, lI
			end
			local region = Region3.new(Vector3.new(xc, T.Bottom, zc), Vector3.new(xc + nx * R, y1, zc + nz * R))
			if useChannels then
				local ok = pcall(function()
					Terrain:WriteVoxelChannels(region, R, { SolidMaterial = sm, SolidOccupancy = so, LiquidOccupancy = lo })
				end)
				if not ok then
					useChannels = false
					for i = 1, nx do -- the same chunk as plain voxels (water where the solid is under half)
						for j = 1, ny do
							local c = T.Bottom + (j - 0.5) * R
							local lw = math.clamp((WATER_TOP - c) / R + 0.5, 0, 1)
							for k = 1, nz do
								if so[i][j][k] < 0.5 and lw > 0 then sm[i][j][k], so[i][j][k] = M.Water, lw end
							end
						end
					end
				end
			end
			if not useChannels then Terrain:WriteVoxels(region, R, sm, so) end
			chunks += 1
			task.wait()
		end
	end

	-- sea rocks: uploaded 3D boulders standing in the water around the islands (not on the bridge lanes)
	local kit = SS:FindFirstChild("WorldKit3D")
	local oldRocks = folders.Decor:FindFirstChild("SeaRocks")
	if oldRocks then stash(oldRocks) end
	local sea = model("SeaRocks", folders.Decor)
	local rocks = 0
	for _ = 1, 800 do
		if rocks >= T.SeaRocks or not kit then break end
		local x, z = rng:NextNumber(BOUNDS.MinX + 25, BOUNDS.MaxX - 25), rng:NextNumber(BOUNDS.MinZ + 25, BOUNDS.MaxZ - 25)
		local own = nearest(x, z)
		local src = kit:FindFirstChild(rng:NextNumber() < 0.5 and "W_Boulder_A" or "W_Boulder_B")
		if own > 34 and own < 95 and src and not nearBridge(x, z, 45) then
			local m = src:Clone()
			pcall(m.ScaleTo, m, m:GetScale() * rng:NextNumber(0.9, 2.1))
			local _, size = m:GetBoundingBox()
			local floorY = math.max(T.Floor, -T.Dip - math.max(0, own - 12) * T.Slope)
			m:PivotTo(CFrame.new(x, math.max(floorY - 1, WATER_TOP - size.Y * 0.55), z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CastShadow = true
				end
			end
			m.Parent = sea
			rocks += 1
		end
	end

	-- the pond: the old flat blue plate goes to the backup, jelly stones sit round the sand rim
	local plate = folders.Decor:FindFirstChild("SlimePond")
	if plate and plate:IsA("BasePart") then stash(plate) end
	local oldStones = folders.Decor:FindFirstChild("PondStones")
	if oldStones then stash(oldStones) end
	local stones = model("PondStones", folders.Decor)
	local ground = RaycastParams.new()
	ground.FilterType = Enum.RaycastFilterType.Include
	ground.FilterDescendantsInstances = { Terrain }
	local stoneSrc = kit and kit:FindFirstChild("Kit_M_JellyRock")
	for _, p in PONDS do
		for i = 1, (stoneSrc and 9 or 0) do
			local a = (i + rng:NextNumber(-0.3, 0.3)) / 9 * math.pi * 2
			local r = p.R + p.Rim * rng:NextNumber(0.55, 0.95)
			local x, z = p.X + math.cos(a) * r, p.Z + math.sin(a) * r
			local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), ground)
			local m = stoneSrc:Clone()
			pcall(m.ScaleTo, m, m:GetScale() * rng:NextNumber(0.9, 1.5))
			m:PivotTo(CFrame.new(x, (hit and hit.Position.Y or 0) - 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CastShadow = true
				end
			end
			m.Parent = stones
		end
	end
	note(string.format("terrain v2: %d lands, %d chunks (%s), %d peaks, %d sea rocks, %d pond stones%s", #LANDS, chunks,
		useChannels and "WriteVoxelChannels" or "WriteVoxels", #PEAKS, rocks, #stones:GetChildren(),
		kit and "" or " (no WorldKit3D)"))
end

------------------------------------------------------------------ 계약 조각 (두 모드 공통)
-- 구역 바닥 파트: 투명·비충돌 계약 파트(A11-R1), 크기·자리는 Config.Zones 그대로
for _, id in ZONE_ORDER do
	local z = ZONES[id]
	local p = folders.Zones:FindFirstChild(id)
	local size, pos = Vector3.new(z.Size.X, 1, z.Size.Z), Vector3.new(z.Center.X, -0.45, z.Center.Z)
	if not (p and p:IsA("BasePart")) then
		if p then stash(p) end
		p = part({ Name = id, Size = size, Position = pos, Color = z.Color, Material = z.Material }, folders.Zones)
	end
	p.Size, p.CFrame = size, CFrame.new(pos)
	p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = 1, false, false, false, false
	p:SetAttribute("ZoneId", id)
end

-- 경계벽 (MapBuilder 이름·크기: 위 Y = WallHeight, 바닥 = 수면 - 20, CR-L17)
for _, w in folders.Walls:GetChildren() do stash(w) end
do
	local t, bottom = 2, WATER_TOP - 20
	local sy, wy = WALL_HEIGHT - bottom, (WALL_HEIGHT + bottom) / 2
	local lenX, lenZ = bw + 2 * t, bd + 2 * t
	for name, w in {
		Wall_MinX = { Vector3.new(t, sy, lenZ), Vector3.new(BOUNDS.MinX - t / 2, wy, cz) },
		Wall_MaxX = { Vector3.new(t, sy, lenZ), Vector3.new(BOUNDS.MaxX + t / 2, wy, cz) },
		Wall_MinZ = { Vector3.new(lenX, sy, t), Vector3.new(cx, wy, BOUNDS.MinZ - t / 2) },
		Wall_MaxZ = { Vector3.new(lenX, sy, t), Vector3.new(cx, wy, BOUNDS.MaxZ + t / 2) },
	} do
		part({ Name = name, Size = w[1], Position = w[2], Transparency = 1, CanCollide = true, CastShadow = false }, folders.Walls)
	end
end

-- 다리 (갑판 위 Y = 0, 폭 22)
local function bridge(entry)
	local from, to, width, style = entry.From, entry.To, entry.Width, entry.Style
	local br = model("Bridge_" .. entry.Name, folders.Decor)
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(mid, to)
	local deck, deckMat, rail, railMat = RGB(150, 110, 70), Enum.Material.WoodPlanks, RGB(110, 80, 50), Enum.Material.Wood
	if style == "Halo" then
		deck, deckMat, rail, railMat = RGB(225, 220, 205), Enum.Material.Marble, RGB(212, 175, 55), SP
	elseif style == "Horns" then
		deck, deckMat, rail, railMat = RGB(50, 34, 38), Enum.Material.Basalt, RGB(130, 25, 30), SP
	elseif style == "Goblin" then
		deck, rail = RGB(100, 75, 50), RGB(80, 60, 40)
	end
	local railX = width / 2 - 0.4
	local d = part({ Name = "Deck", Size = Vector3.new(width, 1, len + 4), CFrame = cf * CFrame.new(0, -0.3, 0), Color = deck, Material = deckMat }, br)
	br.PrimaryPart = d
	for _, s in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(0.8, 0.8, len + 4), CFrame = cf * CFrame.new(s * railX, 2.8, 0), Color = rail, Material = railMat }, br)
		local n = math.max(2, math.floor(len / 14))
		for i = 0, n do
			local zoff = -len / 2 + i * len / n
			prop({ Name = "Post", Size = Vector3.new(0.8, 3, 0.8), CFrame = cf * CFrame.new(s * railX, 1.3, zoff), Color = rail, Material = railMat }, br)
			if i % 2 == 0 then
				part({ Name = "Support", Size = Vector3.new(2, 16, 2), CFrame = cf * CFrame.new(s * (railX - 1.6), -8.5, zoff), Color = RGB(90, 80, 75), Material = Enum.Material.Slate }, br)
			end
			if (style == "Halo" or style == "Horns") and i % 2 == 1 then
				local bulb = prop({ Name = "Lamp", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = cf * CFrame.new(s * railX, 5, zoff),
					Color = style == "Halo" and RGB(255, 230, 150) or RGB(255, 90, 40), Material = NEON }, br)
				if i == 1 and s == 1 then light(bulb, bulb.Color, 16, 1.2) end
			end
		end
	end
	return br
end
for _, b in BRIDGES do
	local old = folders.Decor:FindFirstChild("Bridge_" .. b.Name)
	while old do
		stash(old)
		old = folders.Decor:FindFirstChild("Bridge_" .. b.Name)
	end
	bridge(b)
end

-- 길 (지형 위 얇은 띠; 계절 길은 위에서 흙으로 칠함)
local oldRoads = folders.Decor:FindFirstChild("Roads")
if oldRoads then stash(oldRoads) end
local roads = model("Roads", folders.Decor)
local ROAD_PLAZA_R = 60 -- = Config.Map.RoadLook.PlazaRadius: the town roads stop at the Crossroads plaza edge (검수 10/09)
for _, r in ROADS do
	if not r.Season then
		local minZ, maxZ = r.MinZ, r.MaxZ
		if math.abs(r.MinX + r.MaxX) / 2 < ROAD_PLAZA_R then
			if minZ >= 0 and minZ < ROAD_PLAZA_R then minZ = ROAD_PLAZA_R end
			if maxZ <= 0 and maxZ > -ROAD_PLAZA_R then maxZ = -ROAD_PLAZA_R end
		end
		prop({ Name = r.Name, Size = Vector3.new(r.MaxX - r.MinX, 0.2, maxZ - minZ), Position = Vector3.new((r.MinX + r.MaxX) / 2, 0.08, (minZ + maxZ) / 2),
			Color = r.Color, Material = r.Material }, roads)
	end
end
-- (the gold / red edge stripes of the north / south roads are gone: not in the A2_2 map, 이미지 생성 1 sheet ⑫)

-- PvP 경계: 말뚝 + 띠 (숲 = 주황, 유적 = 빨강). 숲은 다리 끝 해안, 유적은 고갯길 출구(띠 = 길목 폭)
local function pvpBorder(x, tipColor, stripColor, stripMat, stripLen)
	local border = model("PvPBorder_" .. x, folders.Decor)
	for i = 0, 12 do
		local z = -60 + i * 10
		if math.abs(z) > 10 then
			local base = Vector3.new(x + 2, 0, z)
			prop({ Name = "Stake", Size = Vector3.new(1.2, 5, 1.2), CFrame = CFrame.new(base + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(-15)), Color = RGB(110, 80, 50), Material = Enum.Material.Wood }, border)
			prop({ Name = "StakeTip", Size = Vector3.new(1.2, 1, 1.2), CFrame = CFrame.new(base + Vector3.new(-1.3, 5.3, 0)) * CFrame.Angles(0, 0, math.rad(-15)), Color = tipColor, Material = NEON }, border)
		end
	end
	prop({ Name = "BorderStrip", Size = Vector3.new(3, 0.1, stripLen), Position = Vector3.new(x + 4, 0.06, 0), Color = stripColor, Material = stripMat }, border)
end
for _, d in folders.Decor:GetChildren() do
	if string.sub(d.Name, 1, 10) == "PvPBorder_" then stash(d) end
end
pvpBorder(710, DANGER.PvP, RGB(90, 70, 50), Enum.Material.Ground, 300)
pvpBorder(1260, DANGER.Extreme, RGB(90, 30, 30), Enum.Material.CrackedLava, PASS.HalfZ * 2)

-- 관문: 있으면 새 자리로 옮김(높이·방향 그대로, Lintel 기준), 없으면 v4 모양으로 새로
local function buildGate(g)
	local gate = model("Gate_" .. g.Zone, folders.Gates)
	local off = g.AlongX and Vector3.new(0, 0, 10) or Vector3.new(10, 0, 0)
	local lintelSize = g.AlongX and Vector3.new(3, 2.5, 23) or Vector3.new(23, 2.5, 3)
	local lintel
	if g.Style == "Halo" then
		for _, s in { -1, 1 } do
			cyl({ Name = "Tower", Size = Vector3.new(6, 22, 6), Position = g.Position + off * s + Vector3.new(0, 11, 0), Color = RGB(245, 242, 235) }, gate)
			part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(6.4, 6.4, 6.4), Position = g.Position + off * s + Vector3.new(0, 22, 0), Color = RGB(212, 175, 55) }, gate)
		end
		lintel = part({ Name = "Lintel", Size = lintelSize, Position = g.Position + Vector3.new(0, 19, 0), Color = RGB(245, 242, 235) }, gate)
		ring(g.Position + Vector3.new(0, 25, 0), 3.5, 8, Vector3.new(0.5, 0.5, 2.8), RGB(255, 225, 130), gate)
	elseif g.Style == "Horns" then
		for _, s in { -1, 1 } do
			part({ Name = "Pillar", Size = Vector3.new(4, 18, 4), Position = g.Position + off * s + Vector3.new(0, 9, 0), Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, gate)
		end
		lintel = part({ Name = "Lintel", Size = lintelSize, Position = g.Position + Vector3.new(0, 17, 0), Color = RGB(130, 25, 30), Material = Enum.Material.Fabric }, gate)
	else
		local col = ({ Meadow = RGB(140, 100, 65), Goblin = RGB(110, 80, 50), Ruins = RGB(225, 220, 200) })[g.Style]
		for _, s in { -1, 1 } do
			part({ Name = "Pillar", Size = Vector3.new(3, 18, 3), Position = g.Position + off * s + Vector3.new(0, 9, 0), Color = col, Material = g.Style == "Ruins" and SP or Enum.Material.Wood }, gate)
		end
		lintel = part({ Name = "Lintel", Size = lintelSize, Position = g.Position + Vector3.new(0, 18.5, 0), Color = col, Material = g.Style == "Ruins" and SP or Enum.Material.Wood }, gate)
	end
	gate.PrimaryPart = lintel
	return gate
end
for _, g in GATES do
	local gate = folders.Gates:FindFirstChild("Gate_" .. g.Zone)
	if gate and gate:IsA("Model") then
		local anchor = gate.PrimaryPart or gate:FindFirstChild("Lintel", true)
		local at = (anchor and anchor:IsA("BasePart")) and anchor.Position or gate:GetPivot().Position
		local delta = Vector3.new(g.Position.X - at.X, 0, g.Position.Z - at.Z)
		if delta.Magnitude > 0.5 then
			gate:PivotTo(gate:GetPivot() + delta)
			note(string.format("moved Gate_%s by (%.0f, %.0f)", g.Zone, delta.X, delta.Z))
		end
	else
		if gate then stash(gate) end
		buildGate(g)
		note("built Gate_" .. g.Zone)
	end
end

if MODE == "terrain" then
	if fresh then map.Parent = workspace end
	return string.format("map v2 terrain mode: parts %d, lights %d; %s%s", count, lights, table.concat(report, "; "),
		backup and "; old pieces in ServerStorage.MapV1Backup" or "")
end

------------------------------------------------------------------ 여기부터 "full" 전용: 빈 place 의 기본 장식 + 기능 파트
-- 장식 금지 지점 (스폰/발판/제단/게시판/관문/거위 둥지 주변 12칸 + 광장 반경 30 + 큰길·계절 길·둘레길)
local keepClear = { ALTAR, BOARD, GOOSE_NEST }
for _, z in ZONES do table.insert(keepClear, z.Spawn) end
for _, p in PADS do table.insert(keepClear, p.Position) end
for _, g in GATES do table.insert(keepClear, g.Position) end
local function clearAt(pos, r)
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, c in keepClear do
		if (flat - c).Magnitude < (r or 12) then return false end
	end
	if flat.Magnitude < 30 then return false end -- 광장
	if math.abs(pos.Z) < 13 and pos.X > 60 then return false end -- 왕관 큰길
	if math.abs(pos.X) < 12 and math.abs(pos.Z) < 700 then return false end -- 남북 큰길
	if math.abs(pos.X - HW.PathX) < 10 and pos.Z > 0 and pos.Z < 335 then return false end -- 호박 길
	if math.abs(pos.Z - HW.HollowGate.Z) < 10 and pos.X > 325 and pos.X < 540 then return false end -- 유령 숲 길
	for _, r in ROADS do -- 둘레길
		if pos.X > r.MinX - 4 and pos.X < r.MaxX + 4 and pos.Z > r.MinZ - 4 and pos.Z < r.MaxZ + 4 then return false end
	end
	return true
end

-- 하늘의 부서진 균형의 왕관 (어디서나 보이는 랜드마크)
local crownSky = model("CrownOfBalance", folders.Landmarks)
local CROWN_C, CROWN_R = Vector3.new(0, 350, 0), 80
local GOLD, GOLD_NEON = RGB(212, 175, 55), RGB(255, 205, 90)
local SEG = 28
for i = 0, SEG - 1 do
	if i ~= 5 and i ~= 6 and i ~= 19 then -- 부서진 틈
		local a = i / SEG * math.pi * 2
		local pos = CROWN_C + Vector3.new(math.cos(a) * CROWN_R, rng:NextNumber(-2, 2), math.sin(a) * CROWN_R)
		local cf = CFrame.new(pos) * CFrame.Angles(0, -a, 0) * CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, 0)
		part({ Name = "Band", Size = Vector3.new(7, 12, 19), CFrame = cf, Color = GOLD, Material = Enum.Material.Metal, CanCollide = false, CastShadow = false }, crownSky)
		prop({ Name = "Trim", Size = Vector3.new(7.4, 1.4, 19.2), CFrame = cf * CFrame.new(0, -6.5, 0), Color = GOLD_NEON, Material = NEON }, crownSky)
		if i % 4 == 0 and i ~= 20 then -- 왕관 뾰족 끝
			local h = (i % 8 == 0) and 46 or 32
			prop({ Name = "Point", Size = Vector3.new(6, h, 9), CFrame = cf * CFrame.new(0, 6 + h / 2, 0), Color = GOLD, Material = Enum.Material.Metal }, crownSky, "WedgePart")
			prop({ Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = cf * CFrame.new(0, 10, 0), Color = GOLD_NEON, Material = NEON }, crownSky)
		end
	end
end
for _ = 1, 5 do -- 떨어져 나간 파편
	local a = rng:NextNumber(0, math.pi * 2)
	local pos = CROWN_C + Vector3.new(math.cos(a) * (CROWN_R + rng:NextNumber(20, 60)), rng:NextNumber(-60, -15), math.sin(a) * (CROWN_R + rng:NextNumber(20, 60)))
	prop({ Name = "Fragment", Size = Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(6, 10), rng:NextNumber(8, 14)),
		CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = GOLD, Material = Enum.Material.Metal }, crownSky)
end
-- 멀리서도 안개를 뚫고 보이는 왕관 (A12): 같은 왕관을 ViewportFrame 으로 그린 BillboardGui (클라이언트가 거리 500 이상일 때만 켬)
local skyAnchor = prop({ Name = "CrownSkyAnchor", Size = Vector3.new(1, 1, 1), Position = CROWN_C, Transparency = 1 }, folders.Landmarks)
local skyBB = Instance.new("BillboardGui")
skyBB.Name = "CrownSkyBillboard"
skyBB.Size = UDim2.new(420, 0, 240, 0)
skyBB.AlwaysOnTop = false
skyBB.LightInfluence = 0
skyBB.MaxDistance = 100000
skyBB.Enabled = false
local vpf = Instance.new("ViewportFrame")
vpf.Size = UDim2.fromScale(1, 1)
vpf.BackgroundTransparency = 1
vpf.Ambient = RGB(255, 225, 150)
vpf.LightColor = RGB(255, 240, 190)
vpf.LightDirection = Vector3.new(-0.3, -1, -0.4)
vpf.Parent = skyBB
local crownCopy = crownSky:Clone()
crownCopy:PivotTo(CFrame.new(0, 0, 0))
crownCopy.Parent = vpf
local vcam = Instance.new("Camera")
vcam.FieldOfView = 40
vcam.CFrame = CFrame.lookAt(Vector3.new(0, -70, 260), Vector3.new(0, 4, 0))
vcam.Parent = vpf
vpf.CurrentCamera = vcam
skyBB.Parent = skyAnchor

------------------------------------------------------------------ 이동 발판
for _, pad in PADS do
	local z = ZONES[pad.Dest]
	local p = part({ Name = "Pad_" .. pad.Dest, Size = Vector3.new(10, 1, 10), Position = pad.Position,
		Color = RGB(80, 200, 255), Material = NEON, CanTouch = true }, folders.Pads)
	p:SetAttribute("TravelTo", pad.Dest)
	ring(pad.Position + Vector3.new(0, 0.55, 0), 6.2, 12, Vector3.new(0.6, 0.3, 3.4), dangerOf(pad.Dest), p)
	-- A23-36: 가까이서만 보이는 작은 이름표 (MapBuilder PAD_SIGN과 같은 크기)
	local bb = billboard(p, "→ " .. z.Name .. " (Lv " .. z.MinLevel .. "+)", 3, RGB(200, 240, 255), 190, 40)
	bb.Size = UDim2.fromOffset(190, 32)
end

------------------------------------------------------------------ 교차로 마을 (v1 자리 그대로)
disc(Vector3.new(0, 0.05, 0), 52, 0.2, RGB(200, 190, 165), folders.Decor)
local fountain = model("Fountain", folders.Landmarks)
cyl({ Name = "Tier1", Size = Vector3.new(26, 2, 26), Position = Vector3.new(0, 1, 0), Color = RGB(225, 225, 230), Material = Enum.Material.Marble }, fountain)
cyl({ Name = "Water1", Size = Vector3.new(23, 0.3, 23), Position = Vector3.new(0, 2.05, 0), Color = RGB(90, 180, 255), Transparency = 0.3, CanCollide = false }, fountain)
cyl({ Name = "Tier2", Size = Vector3.new(14, 3, 14), Position = Vector3.new(0, 3.5, 0), Color = RGB(225, 225, 230), Material = Enum.Material.Marble }, fountain)
cyl({ Name = "Water2", Size = Vector3.new(12, 0.3, 12), Position = Vector3.new(0, 5.05, 0), Color = RGB(90, 180, 255), Transparency = 0.3, CanCollide = false }, fountain)
cyl({ Name = "Tier3", Size = Vector3.new(6, 2, 6), Position = Vector3.new(0, 6, 0), Color = RGB(225, 225, 230), Material = Enum.Material.Marble }, fountain)
local crown = model("CrownShard", folders.Landmarks)
local core = part({ Name = "Core", Size = Vector3.new(4, 9, 4), CFrame = CFrame.new(0, 22, 0) * CFrame.Angles(0, math.rad(45), 0), Color = RGB(255, 215, 90), Material = NEON, CanCollide = false }, crown)
for i = 0, 3 do
	local a = i * math.pi / 2
	prop({ Name = "Shard", Size = Vector3.new(2, 5, 2), CFrame = CFrame.new(math.cos(a) * 3.2, 20, math.sin(a) * 3.2) * CFrame.Angles(math.sin(a) * math.rad(15), a, math.cos(a) * math.rad(15)),
		Color = RGB(255, 215, 90), Material = NEON }, crown)
end
light(core, RGB(255, 220, 120), 28, 0.9)
local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0, 0); a0.Parent = core
local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 320, 0); a1.Parent = core
local beam = Instance.new("Beam")
beam.Attachment0, beam.Attachment1 = a0, a1
beam.Width0, beam.Width1 = 3, 1.5
beam.LightEmission = 1
beam.FaceCamera = true
beam.Color = ColorSequence.new(RGB(255, 225, 130))
beam.Transparency = NumberSequence.new(0.25, 0.6)
beam.Parent = core
for _, bx in { -1, 1 } do -- 벤치 4개, 분수를 바라봄
	for _, bz in { -1, 1 } do
		local pos = Vector3.new(18 * bx, 1, 18 * bz)
		part({ Name = "Bench", Size = Vector3.new(6, 1, 2), CFrame = CFrame.lookAt(pos, Vector3.new(0, 1, 0)), Color = RGB(140, 100, 65), Material = Enum.Material.WoodPlanks }, folders.Decor)
	end
end
for k = 0, 7 do -- 가로등 8개 (반경 32, 길을 피한 각도)
	local a = math.rad(22.5 + 45 * k)
	local pos = Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
	if clearAt(pos, 8) then
		local lamp = model("Lamp", folders.Decor)
		prop({ Name = "Post", Size = Vector3.new(0.8, 9, 0.8), Position = pos + Vector3.new(0, 4.5, 0), Color = RGB(140, 100, 65), Material = Enum.Material.Wood }, lamp)
		local bulb = prop({ Name = "Lantern", Size = Vector3.new(1.4, 1.8, 1.4), Position = pos + Vector3.new(0, 9.6, 0), Color = RGB(255, 215, 150), Material = NEON }, lamp)
		if k % 2 == 0 then light(bulb, RGB(255, 220, 150), 14, 1.2) end
	end
end
-- 운명의 제단 (Config.Map.AltarPosition)
local altar = part({ Name = "Altar", Size = Vector3.new(8, 4, 8), Position = ALTAR + Vector3.new(0, 2, 0), Color = RGB(110, 100, 130), Material = Enum.Material.Slate }, folders.Landmarks)
local topHalo = part({ Name = "AltarGlowHalo", Size = Vector3.new(6, 0.4, 3), Position = ALTAR + Vector3.new(0, 4.2, -1.5), Color = RGB(255, 215, 90), Material = NEON, CanCollide = false }, altar)
part({ Name = "AltarGlowHorns", Size = Vector3.new(6, 0.4, 3), Position = ALTAR + Vector3.new(0, 4.2, 1.5), Color = RGB(220, 50, 60), Material = NEON, CanCollide = false }, altar)
light(topHalo, RGB(255, 180, 160), 18, 1.5)
for _, ax in { -6, 6 } do
	for _, az in { -6, 6 } do
		part({ Name = "AltarColumn", Size = Vector3.new(2, 10, 2), Position = ALTAR + Vector3.new(ax, 5, az), Color = RGB(150, 140, 165), Material = Enum.Material.Slate }, altar)
	end
end
billboard(altar, "Altar of Fate", 8, RGB(230, 210, 255))
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "AltarPrompt"
prompt.ActionText = "Switch sides"
prompt.ObjectText = "Altar of Fate"
prompt.HoldDuration = 0.5
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = altar
-- 현상수배 게시판 (Config.Map.BoardPosition, +X 를 봄)
local board = part({ Name = "MostWantedBoard", Size = Vector3.new(1, 12, 20), Position = BOARD + Vector3.new(0, 6, 0), Color = RGB(90, 60, 40), Material = Enum.Material.WoodPlanks }, folders.Landmarks)
for _, dz in { -10.5, 10.5 } do
	part({ Name = "BoardPost", Size = Vector3.new(1.2, 14, 1.2), Position = BOARD + Vector3.new(0, 7, dz), Color = RGB(70, 45, 30), Material = Enum.Material.Wood }, board)
end
local sg = Instance.new("SurfaceGui")
sg.Name = "BoardGui"
sg.Face = Enum.NormalId.Right
sg.CanvasSize = Vector2.new(400, 240)
sg.LightInfluence = 0
local bt = Instance.new("TextLabel")
bt.Name = "BoardText"
bt.Size = UDim2.fromScale(1, 1)
bt.BackgroundColor3 = RGB(30, 25, 25)
bt.TextColor3 = Color3.new(1, 1, 1)
bt.TextScaled = true
bt.Font = Enum.Font.GothamBold
bt.Text = "Wanted Board"
bt.Parent = sg
sg.Parent = board
-- 장터 (북서 반원) + 장인 길드 + 황금 거위 둥지 + 진영 깃발
local stallColors = { RGB(220, 80, 80), RGB(80, 160, 220), RGB(240, 190, 60), RGB(110, 190, 90) }
for i, pos in { Vector3.new(-22, 0, -42), Vector3.new(-36, 0, -34), Vector3.new(-46, 0, -20), Vector3.new(-12, 0, -52) } do
	local stall = model("MarketStall", folders.Decor)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	part({ Name = "Counter", Size = Vector3.new(10, 3, 4), CFrame = cf * CFrame.new(0, 1.5, 0), Color = RGB(140, 100, 65), Material = Enum.Material.WoodPlanks }, stall)
	part({ Name = "Roof", Size = Vector3.new(11, 0.6, 6), CFrame = cf * CFrame.new(0, 8.2, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = stallColors[i], Material = Enum.Material.Fabric }, stall)
end
local guild = model("ArtisanGuild", folders.Landmarks)
local gpos = Vector3.new(44, 0, 58)
part({ Name = "Hall", Size = Vector3.new(22, 12, 16), Position = gpos + Vector3.new(0, 6, 0), Color = RGB(150, 150, 158) }, guild)
part({ Name = "Roof", Size = Vector3.new(26, 1, 20), Position = gpos + Vector3.new(0, 12.5, 0), Color = RGB(90, 85, 80), Material = Enum.Material.Slate }, guild)
local anvil = part({ Name = "Anvil", Size = Vector3.new(4, 3, 2), Position = gpos + Vector3.new(-5, 1.5, -13), Color = RGB(70, 70, 75), Material = Enum.Material.Metal }, guild)
local forge = prop({ Name = "Forge", Size = Vector3.new(3, 1, 3), Position = gpos + Vector3.new(5, 0.5, -13), Color = RGB(255, 140, 60), Material = NEON }, guild)
light(forge, RGB(255, 140, 60), 14, 1.5)
billboard(anvil, "Forge", 6, RGB(120, 235, 225))
local nest = model("GoosePerch", folders.Landmarks)
disc(GOOSE_NEST + Vector3.new(0, 0.08, 0), 22, 0.2, RGB(255, 240, 200), nest)
local nestCore = cyl({ Name = "Nest", Size = Vector3.new(8, 1.5, 8), Position = GOOSE_NEST + Vector3.new(0, 0.75, 0), Color = RGB(160, 120, 70), Material = Enum.Material.Wood }, nest)
nestCore.Name = "GoosePerch"
billboard(nestCore, "Golden Goose Nest", 5, RGB(255, 225, 120))
for _, sx in { -12, 12 } do
	prop({ Name = "HaloPole", Size = Vector3.new(0.6, 14, 0.6), Position = Vector3.new(sx, 7, -60), Color = RGB(212, 175, 55) }, folders.Decor)
	prop({ Name = "HaloFlag", Size = Vector3.new(0.2, 8, 4), Position = Vector3.new(sx, 9.5, -57.8), Color = RGB(140, 190, 255), Material = Enum.Material.Fabric }, folders.Decor)
	prop({ Name = "HornsPole", Size = Vector3.new(0.6, 14, 0.6), Position = Vector3.new(sx, 7, 60), Color = RGB(35, 25, 30) }, folders.Decor)
	prop({ Name = "HornsFlag", Size = Vector3.new(0.2, 9, 4), Position = Vector3.new(sx, 9, 62.2), Color = RGB(130, 20, 25), Material = Enum.Material.Fabric }, folders.Decor)
end

------------------------------------------------------------------ 빛의 성채 · 뿔 소굴 (마을 가운데 = v1 자리 + 10 바깥, 성은 섬 끝)
local hc = Vector3.new(0, 0, -410)
local function haloTower(base, h)
	local tower = model("HaloTower", folders.Decor)
	cyl({ Name = "Plinth", Size = Vector3.new(10, 2, 10), Position = base + Vector3.new(0, 1, 0), Color = RGB(212, 175, 55) }, tower)
	cyl({ Name = "Body", Size = Vector3.new(8, h, 8), Position = base + Vector3.new(0, h / 2 + 2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, tower)
	part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(8.5, 8.5, 8.5), Position = base + Vector3.new(0, h + 2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, tower)
	ring(base + Vector3.new(0, h + 9, 0), 4.2, 8, Vector3.new(0.6, 0.6, 3.4), RGB(255, 225, 130), tower)
end
for _, o in { Vector3.new(-58, 0, -58), Vector3.new(58, 0, -58), Vector3.new(-58, 0, 48), Vector3.new(58, 0, 48) } do
	haloTower(hc + o, 26)
end
for _, z in { hc.Z + 60, hc.Z + 40, hc.Z + 20 } do -- 영웅의 길
	for _, x in { -13, 13 } do
		local st = model("HeroStatue", folders.Decor)
		local b = Vector3.new(x, 0, z)
		part({ Name = "Base", Size = Vector3.new(4, 2, 4), Position = b + Vector3.new(0, 1, 0), Color = RGB(212, 175, 55) }, st)
		cyl({ Name = "Body", Size = Vector3.new(3, 7, 3), Position = b + Vector3.new(0, 5.5, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, st)
		part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = b + Vector3.new(0, 10.2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, st)
	end
end
local cath = model("Cathedral", folders.Landmarks) -- 성 자리 (지도 v2 랜드마크 (0, -630))
local cp = Vector3.new(0, 0, -630)
cyl({ Name = "Drum", Size = Vector3.new(26, 12, 26), Position = cp + Vector3.new(0, 6, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, cath)
part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(26, 26, 26), Position = cp + Vector3.new(0, 12, 0), Color = RGB(250, 248, 240), Material = Enum.Material.Marble }, cath)
local spire = part({ Name = "Spire", Size = Vector3.new(2, 14, 2), Position = cp + Vector3.new(0, 31, 0), Color = RGB(212, 175, 55) }, cath)
ring(cp + Vector3.new(0, 36, 0), 4.2, 8, Vector3.new(0.6, 0.6, 3.4), RGB(255, 225, 130), cath)
light(spire, RGB(255, 230, 120), 30, 2)
local rc = Vector3.new(0, 0, 410)
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2
	local pos = rc + Vector3.new(math.cos(a) * 62, 0, math.sin(a) * 62)
	if clearAt(pos) then
		local h = rng:NextNumber(12, 22)
		part({ Name = "Spike", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), a, math.rad(rng:NextNumber(-12, 12))),
			Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, folders.Decor, "WedgePart")
	end
end
for _, x in { -48, 48 } do -- 용암 수로 2줄
	local lava = prop({ Name = "LavaChannel", Size = Vector3.new(3, 0.2, 130), Position = rc + Vector3.new(x, 0.08, 0), Color = RGB(255, 90, 40), Material = NEON }, folders.Decor)
	light(lava, RGB(255, 80, 30), 20, 1.5)
end
local fort = model("HornsFortress", folders.Landmarks) -- 요새 자리 (지도 v2 랜드마크 (0, 630))
part({ Name = "Keep", Size = Vector3.new(30, 24, 22), Position = Vector3.new(0, 12, 630), Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, fort)

------------------------------------------------------------------ 사냥터 (구역 v2 안에 흩뿌림)
local function tree(pos, scale, leaf1, leaf2, trunk)
	local t = model("Tree", folders.Decor)
	local h = 10 * scale
	part({ Name = "Trunk", Size = Vector3.new(2 * scale, h, 2 * scale), Position = pos + Vector3.new(0, h / 2, 0), Color = trunk, Material = Enum.Material.Wood }, t)
	prop({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9) * scale, Position = pos + Vector3.new(0, h + 1.5 * scale, 0), Color = leaf1 }, t)
	prop({ Name = "Leaves2", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6) * scale, Position = pos + Vector3.new(1.5 * scale, h + 5 * scale, 1 * scale), Color = leaf2 }, t)
end
local function scatter(zoneId, n, fn, r)
	local z = ZONES[zoneId]
	local placed = 0
	for _ = 1, n * 5 do
		if placed >= n then break end
		local pos = Vector3.new(z.Center.X + rng:NextNumber(-z.Size.X / 2 + 10, z.Size.X / 2 - 10), 0, z.Center.Z + rng:NextNumber(-z.Size.Z / 2 + 10, z.Size.Z / 2 - 10))
		if clearAt(pos, r or 14) then fn(pos); placed += 1 end
	end
end
scatter("SlimeMeadow", 30, function(pos)
	tree(pos, rng:NextNumber(0.8, 1.15), RGB(146, 255, 109), RGB(128, 250, 101), RGB(130, 90, 55))
end)
scatter("SlimeMeadow", 24, function(pos)
	prop({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 4.5, 4.5), Position = pos + Vector3.new(0, 1, 0), Color = RGB(95, 185, 75) }, folders.Decor)
end)
disc(Vector3.new(290, 0.1, 150), 50, 0.4, RGB(90, 170, 230), folders.Decor).Name = "SlimePond" -- kit_meadow M_Pond
part({ Name = "KingSlimeHill", Shape = Enum.PartType.Ball, Size = Vector3.new(60, 60, 60), Position = Vector3.new(430, -24, -170), Color = RGB(105, 185, 85), Material = Enum.Material.Grass }, folders.Decor)
scatter("GoblinWoods", 50, function(pos)
	tree(pos, rng:NextNumber(1.3, 1.8), RGB(54, 121, 61), RGB(74, 149, 68), RGB(70, 50, 35))
end, 13)
for _, cp2 in { Vector3.new(840, 0, 95), Vector3.new(1010, 0, 130), Vector3.new(1090, 0, -150) } do -- Config GoblinCamp1-3
	local camp = model("GoblinCamp", folders.Decor)
	part({ Name = "Tent", Size = Vector3.new(10, 7, 10), CFrame = CFrame.new(cp2 + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = RGB(140, 110, 70), Material = Enum.Material.Fabric }, camp, "WedgePart")
	local fire = prop({ Name = "Campfire", Size = Vector3.new(2, 1, 2), Position = cp2 + Vector3.new(8, 0.5, 0), Color = RGB(255, 140, 40), Material = NEON }, camp)
	light(fire, RGB(255, 140, 40), 16, 1.5)
end
scatter("SkeletonRuins", 26, function(pos)
	local h = rng:NextNumber(5, 18)
	part({ Name = "BrokenPillar", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))),
		Color = ({ RGB(225, 220, 200), RGB(175, 170, 160) })[rng:NextInteger(1, 2)] }, folders.Decor)
end)
scatter("SkeletonRuins", 6, function(pos)
	local glow = prop({ Name = "SoulWisp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = pos + Vector3.new(0, 4, 0), Color = RGB(150, 110, 255), Material = NEON }, folders.Decor)
	light(glow, RGB(150, 110, 255), 14, 1.5)
end)

------------------------------------------------------------------ 미리보기 스폰 + 조명
local spawn = part({ Name = "PreviewSpawn", Size = Vector3.new(8, 1, 8), Position = ZONES.Crossroads.Spawn + Vector3.new(0, 0.1, 0),
	Color = RGB(200, 200, 200), Transparency = 1, CanCollide = false }, folders.Landmarks, "SpawnLocation")
spawn.Neutral = true
spawn.Duration = 0
local dec = spawn:FindFirstChildOfClass("Decal")
if dec then dec:Destroy() end

map.Parent = workspace

local Lighting = game:GetService("Lighting")
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if atm then atm:Destroy() end -- A9-3
-- Config.Sky.Neutral·WarService와 같은 값(2026-10-08 깊이: 낮은 해, 어두운 그늘, 가까운 안개, 또렷한 그림자)
Lighting.ClockTime = 15.3
Lighting.Brightness = 2
Lighting.Ambient = RGB(72, 76, 86)
Lighting.OutdoorAmbient = RGB(95, 104, 118)
Lighting.FogColor = RGB(150, 205, 228)
Lighting.FogStart = 150
Lighting.FogEnd = 950
Lighting.ExposureCompensation = -0.25
pcall(function() Lighting.EnvironmentDiffuseScale = 0.5 end)
pcall(function() Lighting.EnvironmentSpecularScale = 0.6 end)
pcall(function() Lighting.ShadowSoftness = 0.15 end)
-- A23-105: the place's lighting style is Soft (Realistic broke Play: white screen; the Realistic -> Soft toggle brought
-- the shadows back). Edit bakes Soft so a map rebuild never saves Realistic into the place.
pcall(function() Lighting.LightingStyle = Enum.LightingStyle.Soft end)
Lighting.GlobalShadows = true

return string.format("map v2 full mode: parts %d, lights %d; %s", count, lights, table.concat(report, "; "))
