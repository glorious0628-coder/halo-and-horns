-- 스튜디오 편집 모드에서 게임 맵을 바로 세우는 미리보기 빌더 v4 (엘든 링 스타일: 지형 + 분지 + 하늘의 왕관) (Studio MCP execute_luau 로 실행).
-- 구조는 TECH_SPEC 의 MapBuilder 계약을 따른다: workspace.Map/{Ground,Zones,Walls,Gates,Pads,Landmarks,Decor}
-- 기능 파트(Altar+AltarPrompt, MostWantedBoard, Pad_*) 위치는 Config.Map 값 그대로. 디자인은 docs/ART_DIRECTION.md.
-- 규칙: Atmosphere 금지(A9-3), 재질은 SmoothPlastic 위주, Neon 은 강조에만, 작은 소품은 그림자/충돌 끔.

local rng = Random.new(42)
local RGB = Color3.fromRGB
local SP = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local ZONES = {
	Crossroads = { Name = "교차로 마을", Center = Vector3.new(0, 0, 0), Size = Vector3.new(160, 0, 160), MinLevel = 1, PvP = false,
		Color = RGB(190, 176, 150), Material = Enum.Material.Cobblestone, Spawn = Vector3.new(0, 0, -25) },
	HaloTown = { Name = "빛의 성채", Center = Vector3.new(0, 0, -400), Size = Vector3.new(160, 0, 160), MinLevel = 1, PvP = false,
		Color = RGB(228, 218, 190), Material = Enum.Material.Marble, Spawn = Vector3.new(0, 0, -410) },
	HornsTown = { Name = "뿔 소굴", Center = Vector3.new(0, 0, 400), Size = Vector3.new(160, 0, 160), MinLevel = 1, PvP = false,
		Color = RGB(70, 40, 45), Material = Enum.Material.Slate, Spawn = Vector3.new(0, 0, 410) },
	SlimeMeadow = { Name = "말랑 초원", Center = Vector3.new(330, 0, 0), Size = Vector3.new(260, 0, 260), MinLevel = 1, PvP = false,
		Color = RGB(115, 195, 95), Material = Enum.Material.Grass, Spawn = Vector3.new(220, 0, 0) },
	GoblinWoods = { Name = "고블린 숲", Center = Vector3.new(720, 0, 0), Size = Vector3.new(300, 0, 300), MinLevel = 10, PvP = true,
		Color = RGB(60, 125, 55), Material = Enum.Material.Grass, Spawn = Vector3.new(590, 0, 0) },
	SkeletonRuins = { Name = "해골 유적", Center = Vector3.new(1120, 0, 0), Size = Vector3.new(320, 0, 320), MinLevel = 25, PvP = true,
		Color = RGB(135, 125, 108), Material = Enum.Material.Slate, Spawn = Vector3.new(980, 0, 0) },
}
local ZONE_ORDER = { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "GoblinWoods", "SkeletonRuins" }
local BOUNDS = { MinX = -130, MaxX = 1320, MinZ = -520, MaxZ = 520 }
local LAND = { A = { -110, 115 }, B = { 155, 490 }, C = { 530, 1300 } } -- 대륙 조각 (사이가 강)
local ALTAR = Vector3.new(0, 0, 45)
local BOARD = Vector3.new(-55, 0, 0)
local GOOSE_NEST = Vector3.new(-30, 0, 30)
local PADS = {
	{ Dest = "SlimeMeadow", Position = Vector3.new(60, 0, -30) },
	{ Dest = "GoblinWoods", Position = Vector3.new(60, 0, 0) },
	{ Dest = "SkeletonRuins", Position = Vector3.new(60, 0, 30) },
}
local GATES = {
	{ Zone = "SlimeMeadow", Position = Vector3.new(200, 0, 0), AlongX = true, Style = "Meadow" },
	{ Zone = "GoblinWoods", Position = Vector3.new(570, 0, 0), AlongX = true, Style = "Goblin" },
	{ Zone = "SkeletonRuins", Position = Vector3.new(960, 0, 0), AlongX = true, Style = "Ruins" },
	{ Zone = "HaloTown", Position = Vector3.new(0, 0, -320), AlongX = false, Style = "Halo" },
	{ Zone = "HornsTown", Position = Vector3.new(0, 0, 320), AlongX = false, Style = "Horns" },
}
local DANGER = { Safe = RGB(80, 220, 120), PvP = RGB(255, 150, 40), Extreme = RGB(255, 60, 60) }
local function dangerOf(zoneId)
	if zoneId == "SkeletonRuins" then return DANGER.Extreme, "☠ PvP · 극한" end
	if zoneId == "GoblinWoods" then return DANGER.PvP, "⚔ PvP · 위험" end
	return DANGER.Safe, "🛡 안전 지역"
end

-- 장식 금지 지점 (스폰/발판/제단/게시판/관문/거위 둥지 주변 12칸 + 광장 반경 24)
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
	if math.abs(pos.Z) < 12 and pos.X > 60 then return false end -- 동서 큰길
	if math.abs(pos.X) < 12 and math.abs(pos.Z) < 520 then return false end -- 남북 큰길
	return true
end

local old = workspace:FindFirstChild("Map")
if old then old:Destroy() end
local map = Instance.new("Folder")
map.Name = "Map"
local folders = {}
for _, n in { "Ground", "Zones", "Walls", "Gates", "Pads", "Landmarks", "Decor" } do
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = map
	folders[n] = f
end
local count, lights = 0, 0

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

------------------------------------------------------------------ 지형 v4: 엘든 링 스타일 (진짜 지형 + 산으로 둘러싼 분지 + 하늘의 부서진 왕관)
-- 땅은 전부 Terrain. 존 바닥 파트는 계약용으로만 남기고 투명·비충돌.
-- 사냥터마다 산 능선으로 둘러싸서, 땅에서는 지금 지역 + 멀리 랜드마크만 보인다. 길/관문/다리 자리만 열려 있다.
local Terrain = workspace.Terrain
Terrain:Clear()
Terrain.WaterColor = RGB(35, 100, 130)
Terrain.WaterTransparency = 0.4
Terrain.WaterReflectance = 0.5
Terrain.WaterWaveSize = 0.12
Terrain.WaterWaveSpeed = 8
pcall(function()
	Terrain:SetMaterialColor(Enum.Material.Grass, RGB(106, 150, 72))
	Terrain:SetMaterialColor(Enum.Material.LeafyGrass, RGB(70, 110, 55))
	Terrain:SetMaterialColor(Enum.Material.Rock, RGB(110, 105, 100))
	Terrain:SetMaterialColor(Enum.Material.Cobblestone, RGB(170, 160, 140))
	Terrain:SetMaterialColor(Enum.Material.Limestone, RGB(225, 220, 200))
	Terrain:SetMaterialColor(Enum.Material.Basalt, RGB(48, 38, 40))
	Terrain:SetMaterialColor(Enum.Material.Ground, RGB(120, 100, 75))
end)
local WATER_TOP = -1.2
local bw, bd = BOUNDS.MaxX - BOUNDS.MinX, BOUNDS.MaxZ - BOUNDS.MinZ
local cx, cz = (BOUNDS.MinX + BOUNDS.MaxX) / 2, (BOUNDS.MinZ + BOUNDS.MaxZ) / 2
Terrain:FillBlock(CFrame.new(cx, -18, cz), Vector3.new(bw + 400, 4, bd + 400), Enum.Material.Sand)
Terrain:FillBlock(CFrame.new(cx, (WATER_TOP - 16) / 2, cz), Vector3.new(bw + 400, 16 + WATER_TOP, bd + 400), Enum.Material.Water)

-- 땅 (윗면 Y = 0) + 물가 모래
local function land(minX, maxX, minZ, maxZ, material)
	local c = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	Terrain:FillBlock(CFrame.new(c.X, -10, c.Z), Vector3.new(maxX - minX + 16, 8, maxZ - minZ + 16), Enum.Material.Sand)
	Terrain:FillBlock(CFrame.new(c.X, -6, c.Z), Vector3.new(maxX - minX, 12, maxZ - minZ), material)
end
land(LAND.A[1], LAND.A[2], -175, 175, Enum.Material.Grass)
land(LAND.B[1], LAND.B[2], -175, 175, Enum.Material.Grass)
land(LAND.C[1], LAND.C[2], -175, 175, Enum.Material.Grass)
land(-110, 110, -500, -300, Enum.Material.Grass)
land(-110, 110, 300, 500, Enum.Material.Basalt)

-- 존별 바닥 재질 (Terrain) + 계약용 투명 존 파트
local ZONE_MAT = {
	Crossroads = Enum.Material.Cobblestone, HaloTown = Enum.Material.Limestone, HornsTown = Enum.Material.Basalt,
	SlimeMeadow = Enum.Material.Grass, GoblinWoods = Enum.Material.LeafyGrass, SkeletonRuins = Enum.Material.Ground,
}
for _, id in ZONE_ORDER do
	local z = ZONES[id]
	Terrain:FillBlock(CFrame.new(z.Center.X, -2, z.Center.Z), Vector3.new(z.Size.X, 4, z.Size.Z), ZONE_MAT[id])
	local p = part({ Name = id, Size = Vector3.new(z.Size.X, 1, z.Size.Z), Position = Vector3.new(z.Center.X, -0.45, z.Center.Z),
		Color = z.Color, Material = z.Material, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, folders.Zones)
	p:SetAttribute("ZoneId", id)
end
-- 해골 유적 바닥에 돌판 섞기, 뿔 소굴에 용암 줄기
for _ = 1, 40 do
	local z = ZONES.SkeletonRuins
	Terrain:FillBlock(CFrame.new(z.Center.X + rng:NextNumber(-150, 150), -2, z.Center.Z + rng:NextNumber(-150, 150)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
		Vector3.new(rng:NextNumber(12, 30), 4, rng:NextNumber(12, 30)), Enum.Material.Slate)
end
for _ = 1, 10 do
	local z = ZONES.HornsTown
	Terrain:FillBlock(CFrame.new(z.Center.X + rng:NextNumber(-60, 60), -2, z.Center.Z + rng:NextNumber(-60, 60)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
		Vector3.new(rng:NextNumber(16, 30), 4, 4), Enum.Material.CrackedLava)
end

local wh = 120
for _, w in {
	{ Vector3.new(bw, wh, 2), Vector3.new(cx, wh / 2, BOUNDS.MinZ - 1) },
	{ Vector3.new(bw, wh, 2), Vector3.new(cx, wh / 2, BOUNDS.MaxZ + 1) },
	{ Vector3.new(2, wh, bd), Vector3.new(BOUNDS.MinX - 1, wh / 2, cz) },
	{ Vector3.new(2, wh, bd), Vector3.new(BOUNDS.MaxX + 1, wh / 2, cz) },
} do
	part({ Name = "Wall", Size = w[1], Position = w[2], Transparency = 1, CanCollide = true, CastShadow = false }, folders.Walls)
end

-- 산 능선: 시작점→끝점을 따라 바위 공을 늘어놓는다. gaps 안(길/관문/다리)은 비운다.
local GAPS = {
	{ Vector3.new(0, 0, 0), 0 }, -- 자리표시
}
local function inGap(p)
	for _, g in GAPS do
		if g[2] > 0 and (Vector3.new(p.X, 0, p.Z) - g[1]).Magnitude < g[2] then return true end
	end
	return false
end
local function ridge(x1, z1, x2, z2, rMin, rMax, mat, capMat)
	local a, b = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / 26))
	for i = 0, n do
		local p = a:Lerp(b, i / n) + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		if not inGap(p) then
			local r = rng:NextNumber(rMin, rMax)
			Terrain:FillBall(Vector3.new(p.X, -12 + r * 0.75, p.Z), r, mat)
			if capMat and rng:NextNumber() < 0.6 then
				Terrain:FillBall(Vector3.new(p.X + rng:NextNumber(-6, 6), -12 + r * 1.45, p.Z + rng:NextNumber(-6, 6)), r * 0.45, capMat)
			end
		end
	end
end
-- 길·관문·다리 입구는 비운다 (반경 30)
GAPS = {
	{ Vector3.new(LAND.A[2], 0, 0), 34 }, { Vector3.new(LAND.B[1], 0, 0), 34 }, -- 교차로↔초원 다리
	{ Vector3.new(LAND.B[2], 0, 0), 34 }, { Vector3.new(LAND.C[1], 0, 0), 34 }, -- 초원↔숲 다리
	{ Vector3.new(0, 0, -150), 34 }, { Vector3.new(0, 0, -175), 34 }, { Vector3.new(0, 0, -300), 34 }, { Vector3.new(0, 0, -320), 34 },
	{ Vector3.new(0, 0, 150), 34 }, { Vector3.new(0, 0, 175), 34 }, { Vector3.new(0, 0, 300), 34 }, { Vector3.new(0, 0, 320), 34 },
	{ Vector3.new(915, 0, 0), 26 }, -- 고갯길
}
local ROCK, SLATE = Enum.Material.Rock, Enum.Material.Slate
-- 교차로 분지 (사방 산, 동·북·남 길만 열림)
ridge(-100, -150, 100, -150, 26, 36, ROCK, SLATE)
ridge(-100, 150, 100, 150, 26, 36, ROCK, SLATE)
ridge(-100, -150, -100, 150, 26, 36, ROCK, SLATE)
ridge(105, -160, 105, 160, 24, 34, ROCK, SLATE)
-- 말랑 초원 분지 (부드러운 풀 언덕)
ridge(165, -160, 165, 160, 22, 30, Enum.Material.Grass, ROCK)
ridge(170, -165, 480, -165, 24, 34, Enum.Material.Grass, ROCK)
ridge(170, 165, 480, 165, 24, 34, Enum.Material.Grass, ROCK)
ridge(482, -160, 482, 160, 22, 30, Enum.Material.Grass, ROCK)
-- 고블린 숲 (어두운 바위 + 숲)
ridge(545, -165, 545, 165, 26, 36, ROCK, Enum.Material.LeafyGrass)
ridge(550, -168, 890, -168, 28, 40, ROCK, Enum.Material.LeafyGrass)
ridge(550, 168, 890, 168, 28, 40, ROCK, Enum.Material.LeafyGrass)
-- 고갯길 양옆 높은 산 (숲과 유적 사이)
ridge(915, -175, 915, -30, 36, 48, ROCK, SLATE)
ridge(915, 30, 915, 175, 36, 48, ROCK, SLATE)
-- 해골 유적 (창백한 절벽)
ridge(935, -172, 1295, -172, 30, 42, SLATE, Enum.Material.Limestone)
ridge(935, 172, 1295, 172, 30, 42, SLATE, Enum.Material.Limestone)
ridge(1292, -170, 1292, 170, 32, 46, SLATE, Enum.Material.Limestone)
-- 진영 섬 해안 절벽 (다리 쪽만 열림)
ridge(-105, -305, -105, -495, 22, 30, Enum.Material.Limestone, ROCK)
ridge(105, -305, 105, -495, 22, 30, Enum.Material.Limestone, ROCK)
ridge(-105, -497, 105, -497, 22, 30, Enum.Material.Limestone, ROCK)
ridge(-105, -303, -34, -303, 18, 24, Enum.Material.Limestone, nil)
ridge(34, -303, 105, -303, 18, 24, Enum.Material.Limestone, nil)
ridge(-105, 305, -105, 495, 24, 32, Enum.Material.Basalt, Enum.Material.CrackedLava)
ridge(105, 305, 105, 495, 24, 32, Enum.Material.Basalt, Enum.Material.CrackedLava)
ridge(-105, 497, 105, 497, 24, 32, Enum.Material.Basalt, Enum.Material.CrackedLava)
ridge(-105, 303, -34, 303, 18, 24, Enum.Material.Basalt, nil)
ridge(34, 303, 105, 303, 18, 24, Enum.Material.Basalt, nil)
local PASS_X = 915

-- 하늘의 부서진 균형의 왕관 (엘든 링의 황금 나무처럼 어디서나 보이는 랜드마크)
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
for k = 1, 5 do -- 떨어져 나간 파편
	local a = rng:NextNumber(0, math.pi * 2)
	local pos = CROWN_C + Vector3.new(math.cos(a) * (CROWN_R + rng:NextNumber(20, 60)), rng:NextNumber(-60, -15), math.sin(a) * (CROWN_R + rng:NextNumber(20, 60)))
	prop({ Name = "Fragment", Size = Vector3.new(rng:NextNumber(4, 7), rng:NextNumber(6, 10), rng:NextNumber(8, 14)),
		CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = GOLD, Material = Enum.Material.Metal }, crownSky)
end

-- 멀리서도 안개를 뚫고 보이는 왕관 (A12): 같은 왕관을 ViewportFrame 으로 그린 BillboardGui.
-- GUI 는 안개 영향을 받지 않는다. 가까이서는 진짜 3D 왕관과 겹치므로 클라이언트가 거리 500 이상일 때만 켠다.
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

-- 다리
local function bridge(name, from, to, style)
	local br = model("Bridge_" .. name, folders.Decor)
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
	part({ Name = "Deck", Size = Vector3.new(18, 1, len + 4), CFrame = cf * CFrame.new(0, -0.3, 0), Color = deck, Material = deckMat }, br)
	for _, s in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(0.8, 0.8, len + 4), CFrame = cf * CFrame.new(s * 8.6, 2.8, 0), Color = rail, Material = railMat }, br)
		local n = math.max(2, math.floor(len / 14))
		for i = 0, n do
			local zoff = -len / 2 + i * len / n
			prop({ Name = "Post", Size = Vector3.new(0.8, 3, 0.8), CFrame = cf * CFrame.new(s * 8.6, 1.3, zoff), Color = rail, Material = railMat }, br)
			if i % 2 == 0 then
				part({ Name = "Support", Size = Vector3.new(2, 16, 2), CFrame = cf * CFrame.new(s * 7, -8.5, zoff), Color = RGB(90, 80, 75), Material = Enum.Material.Slate }, br)
			end
			if (style == "Halo" or style == "Horns") and i % 2 == 1 then
				local bulb = prop({ Name = "Lamp", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = cf * CFrame.new(s * 8.6, 5, zoff),
					Color = style == "Halo" and RGB(255, 230, 150) or RGB(255, 90, 40), Material = NEON }, br)
				if i == 1 and s == 1 then light(bulb, bulb.Color, 16, 1.2) end
			end
		end
	end
	return br
end
bridge("Meadow", Vector3.new(LAND.A[2] - 2, 0, 0), Vector3.new(LAND.B[1] + 2, 0, 0), "Wood")
bridge("Goblin", Vector3.new(LAND.B[2] - 2, 0, 0), Vector3.new(LAND.C[1] + 2, 0, 0), "Goblin")
bridge("Halo", Vector3.new(0, 0, -173), Vector3.new(0, 0, -302), "Halo")
bridge("Horns", Vector3.new(0, 0, 173), Vector3.new(0, 0, 302), "Horns")

-- 길 (지형 위 얇은 띠)
local roads = model("Roads", folders.Decor)
local function road(name, x1, x2, z1, z2, color, material)
	return prop({ Name = name, Size = Vector3.new(math.abs(x2 - x1), 0.2, math.abs(z2 - z1)), Position = Vector3.new((x1 + x2) / 2, 0.08, (z1 + z2) / 2),
		Color = color, Material = material or Enum.Material.Ground }, roads)
end
road("RoadCross", 13, LAND.A[2], -8, 8, RGB(150, 125, 90))
road("RoadMeadow", LAND.B[1], LAND.B[2], -8, 8, RGB(190, 165, 115))
road("RoadWoods", LAND.C[1], PASS_X - 20, -8, 8, RGB(105, 82, 58))
road("RoadPass", PASS_X - 20, PASS_X + 20, -8, 8, RGB(110, 105, 100), Enum.Material.Slate)
road("RoadRuins", PASS_X + 20, LAND.C[2], -8, 8, RGB(160, 150, 130), Enum.Material.Slate)
road("RoadNorth", -8, 8, -175, -10, RGB(215, 205, 185), SP)
road("RoadNorthIsland", -8, 8, ZONES.HaloTown.Spawn.Z + 12, -300, RGB(215, 205, 185), SP)
road("RoadSouth", -8, 8, 10, 175, RGB(70, 45, 45), Enum.Material.Slate)
road("RoadSouthIsland", -8, 8, 300, ZONES.HornsTown.Spawn.Z - 12, RGB(70, 45, 45), Enum.Material.Slate)
for _, sx in { -7.2, 7.2 } do
	prop({ Name = "TrimGold", Size = Vector3.new(0.8, 0.22, 165), Position = Vector3.new(sx, 0.09, -92.5), Color = RGB(212, 175, 55) }, roads)
	prop({ Name = "TrimRed", Size = Vector3.new(0.8, 0.22, 165), Position = Vector3.new(sx, 0.09, 92.5), Color = RGB(200, 30, 40) }, roads)
end
road("RoadWest", -43, -13, -8, 8, RGB(160, 155, 145), SP)

------------------------------------------------------------------ 관문
local function gateSign(lintel, zoneId)
	local z = ZONES[zoneId]
	local col, txt = dangerOf(zoneId)
	local hex = string.format("#%02X%02X%02X", math.floor(col.R * 255 + 0.5), math.floor(col.G * 255 + 0.5), math.floor(col.B * 255 + 0.5))
	billboard(lintel, string.format('%s  Lv %d+<br/><font color="%s">%s</font>', z.Name, z.MinLevel, hex, txt), 6, Color3.new(1, 1, 1), 300)
end
for _, g in GATES do
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
			for k = 1, 3 do
				prop({ Name = "Horn", Size = Vector3.new(2.4 - k * 0.5, 3, 2.4 - k * 0.5), CFrame = CFrame.new(g.Position + off * s * (1 - k * 0.12) + Vector3.new(0, 18 + k * 2.4, 0)) * CFrame.Angles(0, 0, math.rad(-15 * k * s)),
					Color = RGB(60, 40, 45), Material = Enum.Material.Basalt }, gate, "WedgePart")
			end
			prop({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Position = g.Position + off * s * 0.92 + Vector3.new(0, 16, 0), Color = RGB(255, 60, 40), Material = NEON }, gate)
		end
		lintel = part({ Name = "Lintel", Size = lintelSize, Position = g.Position + Vector3.new(0, 17, 0), Color = RGB(130, 25, 30), Material = Enum.Material.Fabric }, gate)
	else
		local col = ({ Meadow = RGB(140, 100, 65), Goblin = RGB(110, 80, 50), Ruins = RGB(225, 220, 200) })[g.Style]
		for _, s in { -1, 1 } do
			part({ Name = "Pillar", Size = Vector3.new(3, 18, 3), Position = g.Position + off * s + Vector3.new(0, 9, 0), Color = col, Material = g.Style == "Ruins" and SP or Enum.Material.Wood }, gate)
		end
		lintel = part({ Name = "Lintel", Size = lintelSize, Position = g.Position + Vector3.new(0, 18.5, 0), Color = col, Material = g.Style == "Ruins" and SP or Enum.Material.Wood }, gate)
		local top = g.Position + Vector3.new(0, 24, 0)
		if g.Style == "Meadow" then -- 슬라임 상
			part({ Name = "SlimeStatue", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = top, Color = RGB(120, 230, 150) }, gate)
			for _, ez in { -1.5, 1.5 } do
				prop({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = top + Vector3.new(-3.4, 1, ez), Color = RGB(30, 30, 30) }, gate)
			end
		elseif g.Style == "Goblin" then -- 고블린 토템 + 엇갈린 창
			part({ Name = "Totem", Size = Vector3.new(4, 7, 4), Position = top + Vector3.new(0, 0.5, 0), Color = RGB(80, 120, 50) }, gate)
			prop({ Name = "TotemEyes", Size = Vector3.new(0.4, 0.8, 2.6), Position = top + Vector3.new(-2.1, 2, 0), Color = RGB(255, 220, 60), Material = NEON }, gate)
			for _, a in { 35, -35 } do
				prop({ Name = "Spear", Size = Vector3.new(0.5, 12, 0.5), CFrame = CFrame.new(top + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(a), 0, 0), Color = RGB(120, 90, 55), Material = Enum.Material.Wood }, gate)
			end
		else -- 해골 아치
			part({ Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12), Position = top + Vector3.new(0, 2, 0), Color = RGB(225, 220, 200) }, gate)
			for _, ez in { -2.6, 2.6 } do
				local eye = prop({ Name = "SkullEye", Shape = Enum.PartType.Ball, Size = Vector3.new(2.5, 2.5, 2.5), Position = top + Vector3.new(-5.2, 3, ez), Color = RGB(150, 110, 255), Material = NEON }, gate)
				if ez < 0 then light(eye, RGB(150, 110, 255), 18, 1.5) end
			end
			prop({ Name = "Jaw", Size = Vector3.new(4, 2, 6), Position = top + Vector3.new(-3.5, -3.5, 0), Color = RGB(205, 200, 180) }, gate)
		end
	end
	gateSign(lintel, g.Zone)
end

-- PvP 경계: 말뚝 13개 + 띠
local function pvpBorder(x, tipColor, stripColor, stripMat)
	local border = model("PvPBorder_" .. x, folders.Decor)
	for i = 0, 12 do
		local z = -60 + i * 10
		if math.abs(z) > 10 then
			local base = Vector3.new(x, 0, z)
			prop({ Name = "Stake", Size = Vector3.new(1.2, 5, 1.2), CFrame = CFrame.new(base + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(-15)), Color = RGB(110, 80, 50), Material = Enum.Material.Wood }, border)
			prop({ Name = "StakeTip", Size = Vector3.new(1.2, 1, 1.2), CFrame = CFrame.new(base + Vector3.new(-1.3, 5.3, 0)) * CFrame.Angles(0, 0, math.rad(-15)), Color = tipColor, Material = NEON }, border)
		end
	end
	prop({ Name = "BorderStrip", Size = Vector3.new(3, 0.1, 300), Position = Vector3.new(x + 4, 0.06, 0), Color = stripColor, Material = stripMat }, border)
end
pvpBorder(570, DANGER.PvP, RGB(90, 70, 50), Enum.Material.Ground)
pvpBorder(960, DANGER.Extreme, RGB(90, 30, 30), Enum.Material.CrackedLava)

------------------------------------------------------------------ 이동 발판
for _, pad in PADS do
	local z = ZONES[pad.Dest]
	local col = dangerOf(pad.Dest)
	local p = part({ Name = "Pad_" .. pad.Dest, Size = Vector3.new(10, 1, 10), Position = pad.Position,
		Color = RGB(80, 200, 255), Material = NEON, CanTouch = true }, folders.Pads)
	p:SetAttribute("TravelTo", pad.Dest)
	ring(pad.Position + Vector3.new(0, 0.55, 0), 6.2, 12, Vector3.new(0.6, 0.3, 3.4), col, p)
	billboard(p, "→ " .. z.Name .. " (Lv " .. z.MinLevel .. "+)", 4, RGB(200, 240, 255))
end

------------------------------------------------------------------ 교차로 마을
-- 광장 링 + 3단 분수 + 왕관 조각 수정 묶음 + 빛기둥
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
billboard(core, "균형의 왕관 조각", 7, RGB(255, 230, 140), 260, 220)
for _, bx in { -1, 1 } do -- 벤치 4개, 분수를 바라봄
	for _, bz in { -1, 1 } do
		local pos = Vector3.new(18 * bx, 1, 18 * bz)
		part({ Name = "Bench", Size = Vector3.new(6, 1, 2), CFrame = CFrame.lookAt(pos, Vector3.new(0, 1, 0)), Color = RGB(140, 100, 65), Material = Enum.Material.WoodPlanks }, folders.Decor)
	end
end
-- 가로등 8개 (반경 32, 길을 피한 각도)
for k = 0, 7 do
	local a = math.rad(22.5 + 45 * k)
	local pos = Vector3.new(math.cos(a) * 32, 0, math.sin(a) * 32)
	if clearAt(pos, 8) then
		local lamp = model("Lamp", folders.Decor)
		prop({ Name = "Post", Size = Vector3.new(0.8, 9, 0.8), Position = pos + Vector3.new(0, 4.5, 0), Color = RGB(140, 100, 65), Material = Enum.Material.Wood }, lamp)
		local bulb = prop({ Name = "Lantern", Size = Vector3.new(1.4, 1.8, 1.4), Position = pos + Vector3.new(0, 9.6, 0), Color = RGB(255, 215, 150), Material = NEON }, lamp)
		if k % 2 == 0 then light(bulb, RGB(255, 220, 150), 14, 1.2) end
	end
end

-- 운명의 제단 (위치는 Config.Map.AltarPosition)
local altar = part({ Name = "Altar", Size = Vector3.new(8, 4, 8), Position = ALTAR + Vector3.new(0, 2, 0), Color = RGB(110, 100, 130), Material = Enum.Material.Slate }, folders.Landmarks)
local topHalo = part({ Name = "AltarGlowHalo", Size = Vector3.new(6, 0.4, 3), Position = ALTAR + Vector3.new(0, 4.2, -1.5), Color = RGB(255, 215, 90), Material = NEON, CanCollide = false }, altar)
part({ Name = "AltarGlowHorns", Size = Vector3.new(6, 0.4, 3), Position = ALTAR + Vector3.new(0, 4.2, 1.5), Color = RGB(220, 50, 60), Material = NEON, CanCollide = false }, altar)
light(topHalo, RGB(255, 180, 160), 18, 1.5)
for _, cx in { -6, 6 } do
	for _, cz in { -6, 6 } do
		part({ Name = "AltarColumn", Size = Vector3.new(2, 10, 2), Position = ALTAR + Vector3.new(cx, 5, cz), Color = RGB(150, 140, 165), Material = Enum.Material.Slate }, altar)
	end
end
billboard(altar, "운명의 제단", 8, RGB(230, 210, 255))
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "AltarPrompt"
prompt.ActionText = "진영 바꾸기"
prompt.ObjectText = "운명의 제단"
prompt.HoldDuration = 0.5
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = altar

-- 현상수배 게시판 (위치는 Config.Map.BoardPosition, +X 를 봄)
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
bt.Text = "현상수배 게시판"
bt.Parent = sg
sg.Parent = board

-- 장터 (북서 반원, 분수를 바라봄) + 거래소 간판
local stallColors = { RGB(220, 80, 80), RGB(80, 160, 220), RGB(240, 190, 60), RGB(110, 190, 90) }
for i, pos in { Vector3.new(-22, 0, -42), Vector3.new(-36, 0, -34), Vector3.new(-46, 0, -20), Vector3.new(-12, 0, -52) } do
	local stall = model("MarketStall", folders.Decor)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	part({ Name = "Counter", Size = Vector3.new(10, 3, 4), CFrame = cf * CFrame.new(0, 1.5, 0), Color = RGB(140, 100, 65), Material = Enum.Material.WoodPlanks }, stall)
	for _, dx in { -4.5, 4.5 } do
		prop({ Name = "Post", Size = Vector3.new(0.6, 8, 0.6), CFrame = cf * CFrame.new(dx, 4, 1.5), Color = RGB(120, 85, 50), Material = Enum.Material.Wood }, stall)
	end
	part({ Name = "Roof", Size = Vector3.new(11, 0.6, 6), CFrame = cf * CFrame.new(0, 8.2, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = stallColors[i], Material = Enum.Material.Fabric }, stall)
end
local market = prop({ Name = "MarketSign", Size = Vector3.new(1, 1, 1), Position = Vector3.new(-30, 13, -36), Transparency = 1 }, folders.Landmarks)
billboard(market, "거래소 (준비 중)", 0, RGB(255, 240, 180))

-- 장인 길드 (+ 청록 톱니 엠블럼)
local guild = model("ArtisanGuild", folders.Landmarks)
local gpos = Vector3.new(44, 0, 58)
part({ Name = "Hall", Size = Vector3.new(22, 12, 16), Position = gpos + Vector3.new(0, 6, 0), Color = RGB(150, 150, 158) }, guild)
for _, cx in { -11, 11 } do
	for _, cz in { -8, 8 } do
		part({ Name = "Beam", Size = Vector3.new(0.8, 12, 0.8), Position = gpos + Vector3.new(cx, 6, cz), Color = RGB(140, 100, 65), Material = Enum.Material.Wood }, guild)
	end
end
part({ Name = "Roof", Size = Vector3.new(26, 1, 20), Position = gpos + Vector3.new(0, 12.5, 0), Color = RGB(90, 85, 80), Material = Enum.Material.Slate }, guild)
part({ Name = "Door", Size = Vector3.new(6, 9, 0.4), Position = gpos + Vector3.new(0, 4.5, -8.1), Color = RGB(110, 75, 45), Material = Enum.Material.WoodPlanks }, guild)
local gearCenter = gpos + Vector3.new(0, 20, 0)
local gear = cyl({ Name = "GearEmblem", Size = Vector3.new(10, 1.2, 10), Position = gearCenter, Color = RGB(205, 165, 85), Material = Enum.Material.Metal }, guild)
gear.CFrame = CFrame.new(gearCenter) * CFrame.Angles(0, math.rad(90), 0) -- 원판을 세워서 광장(-Z)을 보게
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	prop({ Name = "GearTooth", Size = Vector3.new(1.6, 1.6, 1.2), CFrame = CFrame.new(gearCenter + Vector3.new(math.cos(a) * 5.6, math.sin(a) * 5.6, 0)) * CFrame.Angles(0, 0, a),
		Color = RGB(40, 200, 190), Material = NEON }, guild)
end
part({ Name = "GearPost", Size = Vector3.new(1, 8, 1), Position = gpos + Vector3.new(0, 15, 0.8), Color = RGB(90, 85, 80), Material = Enum.Material.Metal }, guild)
local anvil = part({ Name = "Anvil", Size = Vector3.new(4, 3, 2), Position = gpos + Vector3.new(-5, 1.5, -13), Color = RGB(70, 70, 75), Material = Enum.Material.Metal }, guild)
local forge = prop({ Name = "Forge", Size = Vector3.new(3, 1, 3), Position = gpos + Vector3.new(5, 0.5, -13), Color = RGB(255, 140, 60), Material = NEON }, guild)
light(forge, RGB(255, 140, 60), 14, 1.5)
billboard(anvil, "⚙ 장인 길드", 6, RGB(120, 235, 225))

-- 황금 거위 둥지 (이벤트 무대)
local nest = model("GoosePerch", folders.Landmarks)
disc(GOOSE_NEST + Vector3.new(0, 0.08, 0), 22, 0.2, RGB(255, 240, 200), nest)
local nestCore = cyl({ Name = "Nest", Size = Vector3.new(8, 1.5, 8), Position = GOOSE_NEST + Vector3.new(0, 0.75, 0), Color = RGB(160, 120, 70), Material = Enum.Material.Wood }, nest)
nestCore.Name = "GoosePerch"
for k = 0, 3 do
	local a = k * math.pi / 2 + math.pi / 4
	part({ Name = "GoldPost", Size = Vector3.new(1, 6, 1), Position = GOOSE_NEST + Vector3.new(math.cos(a) * 10, 3, math.sin(a) * 10), Color = RGB(212, 175, 55) }, nest)
end
billboard(nestCore, "황금 거위 둥지", 5, RGB(255, 225, 120))

-- 진영 주머니 (북 = 빛, 남 = 뿔)
for _, sx in { -12, 12 } do
	local hp = Vector3.new(sx, 0, -60)
	prop({ Name = "HaloPole", Size = Vector3.new(0.6, 14, 0.6), Position = hp + Vector3.new(0, 7, 0), Color = RGB(212, 175, 55) }, folders.Decor)
	prop({ Name = "HaloFlag", Size = Vector3.new(0.2, 8, 4), Position = hp + Vector3.new(0, 9.5, 2.2), Color = RGB(140, 190, 255), Material = Enum.Material.Fabric }, folders.Decor)
	local rp = Vector3.new(sx, 0, 60)
	prop({ Name = "HornsPole", Size = Vector3.new(0.6, 14, 0.6), Position = rp + Vector3.new(0, 7, 0), Color = RGB(35, 25, 30) }, folders.Decor)
	prop({ Name = "HornsFlag", Size = Vector3.new(0.2, 9, 4), Position = rp + Vector3.new(0, 9, 2.2), Color = RGB(130, 20, 25), Material = Enum.Material.Fabric }, folders.Decor)
	local brazier = prop({ Name = "Brazier", Size = Vector3.new(1.6, 1.2, 1.6), Position = rp + Vector3.new(sx > 0 and 3 or -3, 3.6, 0), Color = RGB(255, 90, 40), Material = NEON }, folders.Decor)
	prop({ Name = "BrazierStand", Size = Vector3.new(1.5, 3, 1.5), Position = rp + Vector3.new(sx > 0 and 3 or -3, 1.5, 0), Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, folders.Decor)
	if sx > 0 then light(brazier, RGB(255, 90, 40), 14, 1.5) end
end

------------------------------------------------------------------ 빛의 성채
local hc = ZONES.HaloTown.Center
local function haloTower(base, h)
	local tower = model("HaloTower", folders.Decor)
	cyl({ Name = "Plinth", Size = Vector3.new(10, 2, 10), Position = base + Vector3.new(0, 1, 0), Color = RGB(212, 175, 55) }, tower)
	cyl({ Name = "Body", Size = Vector3.new(8, h, 8), Position = base + Vector3.new(0, h / 2 + 2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, tower)
	cyl({ Name = "Band", Size = Vector3.new(8.6, 0.8, 8.6), Position = base + Vector3.new(0, h + 1.6, 0), Color = RGB(212, 175, 55) }, tower)
	part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(8.5, 8.5, 8.5), Position = base + Vector3.new(0, h + 2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, tower)
	ring(base + Vector3.new(0, h + 9, 0), 4.2, 8, Vector3.new(0.6, 0.6, 3.4), RGB(255, 225, 130), tower)
end
for _, o in { Vector3.new(-58, 0, -58), Vector3.new(58, 0, -58), Vector3.new(-58, 0, 48), Vector3.new(58, 0, 48) } do
	haloTower(hc + o, 26)
end
-- 영웅의 길: 영웅상 3쌍
for _, z in { hc.Z + 60, hc.Z + 40, hc.Z + 20 } do
	for _, x in { -13, 13 } do
		local st = model("HeroStatue", folders.Decor)
		local b = Vector3.new(x, 0, z)
		part({ Name = "Base", Size = Vector3.new(4, 2, 4), Position = b + Vector3.new(0, 1, 0), Color = RGB(212, 175, 55) }, st)
		cyl({ Name = "Body", Size = Vector3.new(3, 7, 3), Position = b + Vector3.new(0, 5.5, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, st)
		part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Position = b + Vector3.new(0, 10.2, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, st)
		cyl({ Name = "Halo", Size = Vector3.new(3.2, 0.3, 3.2), Position = b + Vector3.new(0, 12, 0), Color = RGB(255, 225, 130), Material = NEON, CanCollide = false }, st)
	end
end
-- 대성당 (길 끝)
local cath = model("Cathedral", folders.Landmarks)
local cp = hc + Vector3.new(0, 0, -55)
cyl({ Name = "Drum", Size = Vector3.new(26, 12, 26), Position = cp + Vector3.new(0, 6, 0), Color = RGB(245, 242, 235), Material = Enum.Material.Marble }, cath)
part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(26, 26, 26), Position = cp + Vector3.new(0, 12, 0), Color = RGB(250, 248, 240), Material = Enum.Material.Marble }, cath)
cyl({ Name = "DomeBand", Size = Vector3.new(27, 1, 27), Position = cp + Vector3.new(0, 12, 0), Color = RGB(212, 175, 55) }, cath)
local spire = part({ Name = "Spire", Size = Vector3.new(2, 14, 2), Position = cp + Vector3.new(0, 31, 0), Color = RGB(212, 175, 55) }, cath)
ring(cp + Vector3.new(0, 36, 0), 4.2, 8, Vector3.new(0.6, 0.6, 3.4), RGB(255, 225, 130), cath)
light(spire, RGB(255, 230, 120), 30, 2)
part({ Name = "Door", Size = Vector3.new(8, 10, 1), Position = cp + Vector3.new(0, 5, 12.6), Color = RGB(212, 175, 55) }, cath)
-- 구름 공, 꽃
for i = 1, 6 do
	local pos = hc + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
	if clearAt(pos, 14) then
		local s = rng:NextNumber(10, 16)
		prop({ Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = pos + Vector3.new(0, s * 0.2, 0), Color = RGB(250, 250, 255) }, folders.Decor)
	end
end
for i = 1, 8 do
	local pos = hc + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
	if clearAt(pos, 10) then
		prop({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = pos + Vector3.new(0, 0.5, 0), Color = RGB(255, 170, 210) }, folders.Decor)
	end
end
local haloSign = prop({ Name = "HaloSign", Size = Vector3.new(1, 1, 1), Position = hc + Vector3.new(0, 22, 75), Transparency = 1 }, folders.Landmarks)
billboard(haloSign, "빛의 성채", 0, RGB(255, 215, 90), 300, 220)

------------------------------------------------------------------ 뿔 소굴
local rc = ZONES.HornsTown.Center
for i = 1, 14 do
	local a = (i / 14) * math.pi * 2
	local pos = rc + Vector3.new(math.cos(a) * 62, 0, math.sin(a) * 62)
	if clearAt(pos) then
		local h = rng:NextNumber(12, 22)
		part({ Name = "Spike", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), a, math.rad(rng:NextNumber(-12, 12))),
			Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, folders.Decor, "WedgePart")
	end
end
local function hornTower(base, h, tilt)
	local tw = model("HornTower", folders.Decor)
	local cf = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(tilt))
	part({ Name = "Body", Size = Vector3.new(7, h, 7), CFrame = cf * CFrame.new(0, h / 2, 0), Color = RGB(45, 30, 35), Material = Enum.Material.Basalt }, tw)
	for _, c in { Vector3.new(2.2, 0, 2.2), Vector3.new(-2.2, 0, 2.2), Vector3.new(2.2, 0, -2.2), Vector3.new(-2.2, 0, -2.2) } do
		prop({ Name = "Crown", Size = Vector3.new(2.5, 4, 2.5), CFrame = cf * CFrame.new(c + Vector3.new(0, h + 2, 0)) * CFrame.Angles(0, math.atan2(c.X, c.Z), 0), Color = RGB(60, 40, 45), Material = Enum.Material.Basalt }, tw, "CornerWedgePart")
	end
	for k = 1, 3 do
		prop({ Name = "Window", Size = Vector3.new(0.4, 2, 0.2), CFrame = cf * CFrame.new(0, h * k / 4, -3.6), Color = RGB(255, 90, 40), Material = NEON }, tw)
	end
end
hornTower(rc + Vector3.new(45, 0, 55), 30, 8)
hornTower(rc + Vector3.new(-50, 0, 40), 24, -7)
hornTower(rc + Vector3.new(-45, 0, -45), 22, 6)
-- 용암 수로 2줄
for _, x in { -48, 48 } do
	local lava = prop({ Name = "LavaChannel", Size = Vector3.new(3, 0.2, 130), Position = rc + Vector3.new(x, 0.08, 0), Color = RGB(255, 90, 40), Material = NEON }, folders.Decor)
	light(lava, RGB(255, 80, 30), 20, 1.5)
	prop({ Name = "ChannelRimL", Size = Vector3.new(1, 0.6, 130), Position = rc + Vector3.new(x - 2, 0.3, 0), Color = RGB(35, 25, 30), Material = Enum.Material.Basalt }, folders.Decor)
	prop({ Name = "ChannelRimR", Size = Vector3.new(1, 0.6, 130), Position = rc + Vector3.new(x + 2, 0.3, 0), Color = RGB(35, 25, 30), Material = Enum.Material.Basalt }, folders.Decor)
end
for i = 1, 4 do
	local pos = rc + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-50, 50))
	if clearAt(pos, 14) then
		prop({ Name = "LavaCrack", Size = Vector3.new(rng:NextNumber(8, 14), 0.2, 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = RGB(255, 80, 30), Material = NEON }, folders.Decor)
	end
end
local hornsSign = prop({ Name = "HornsSign", Size = Vector3.new(1, 1, 1), Position = rc + Vector3.new(0, 22, -75), Transparency = 1 }, folders.Landmarks)
billboard(hornsSign, "뿔 소굴", 0, RGB(255, 100, 90), 300, 220)

------------------------------------------------------------------ 사냥터
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
		local pos = Vector3.new(z.Center.X + rng:NextNumber(-z.Size.X / 2 + 8, z.Size.X / 2 - 8), 0, z.Center.Z + rng:NextNumber(-z.Size.Z / 2 + 8, z.Size.Z / 2 - 8))
		if clearAt(pos, r or 14) then fn(pos); placed += 1 end
	end
end

-- 말랑 초원: 둥글고 낮고 통통
scatter("SlimeMeadow", 16, function(pos)
	tree(pos, rng:NextNumber(0.8, 1.15), RGB(120, 210, 90), RGB(95, 185, 75), RGB(130, 90, 55))
end)
scatter("SlimeMeadow", 12, function(pos)
	prop({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 4.5, 4.5), Position = pos + Vector3.new(0, 1, 0), Color = RGB(95, 185, 75) }, folders.Decor)
end)
scatter("SlimeMeadow", 24, function(pos)
	prop({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = pos + Vector3.new(0, 0.6, 0),
		Color = ({ RGB(255, 140, 190), RGB(255, 230, 90), RGB(170, 140, 255) })[rng:NextInteger(1, 3)] }, folders.Decor)
end, 8)
prop({ Name = "SlimePond", Size = Vector3.new(36, 0.4, 24), Position = Vector3.new(280, 0.1, -45), Color = RGB(90, 170, 230) }, folders.Decor)
for k = 0, 7 do -- 버섯 고리
	local a = k / 8 * math.pi * 2
	local pos = Vector3.new(350, 0, 55) + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10)
	prop({ Name = "MushStem", Size = Vector3.new(0.8, 1.6, 0.8), Position = pos + Vector3.new(0, 0.8, 0), Color = RGB(255, 250, 240) }, folders.Decor)
	prop({ Name = "MushCap", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = pos + Vector3.new(0, 1.7, 0), Color = RGB(255, 110, 110) }, folders.Decor)
end
part({ Name = "KingSlimeHill", Shape = Enum.PartType.Ball, Size = Vector3.new(50, 50, 50), Position = Vector3.new(420, -19, -45), Color = RGB(105, 185, 85), Material = Enum.Material.Grass }, folders.Decor)

-- 고블린 숲: 크고 어둡고 거칠게
scatter("GoblinWoods", 30, function(pos)
	tree(pos, rng:NextNumber(1.3, 1.8), RGB(40, 90, 45), RGB(55, 110, 50), RGB(70, 50, 35))
end, 13)
for _, cp2 in { Vector3.new(660, 0, -60), Vector3.new(750, 0, 50), Vector3.new(820, 0, -40) } do
	local camp = model("GoblinCamp", folders.Decor)
	part({ Name = "Tent", Size = Vector3.new(10, 7, 10), CFrame = CFrame.new(cp2 + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Color = RGB(140, 110, 70), Material = Enum.Material.Fabric }, camp, "WedgePart")
	local fire = prop({ Name = "Campfire", Size = Vector3.new(2, 1, 2), Position = cp2 + Vector3.new(8, 0.5, 0), Color = RGB(255, 140, 40), Material = NEON }, camp)
	light(fire, RGB(255, 140, 40), 16, 1.5)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		prop({ Name = "Palisade", Size = Vector3.new(1, 5, 1), CFrame = CFrame.new(cp2 + Vector3.new(math.cos(a) * 14, 2.5, math.sin(a) * 14)) * CFrame.Angles(math.rad(10), a, 0),
			Color = RGB(110, 80, 50), Material = Enum.Material.Wood }, camp)
	end
end
scatter("GoblinWoods", 6, function(pos) -- 덤불 속 빨간 눈
	prop({ Name = "DarkBush", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), Position = pos + Vector3.new(0, 1.5, 0), Color = RGB(30, 70, 35) }, folders.Decor)
	for _, ez in { -0.7, 0.7 } do
		prop({ Name = "RedEye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Position = pos + Vector3.new(-2.9, 2, ez), Color = RGB(255, 40, 40), Material = NEON }, folders.Decor)
	end
end)

-- 해골 유적: 부서지고 창백하게
scatter("SkeletonRuins", 18, function(pos)
	local h = rng:NextNumber(5, 18)
	part({ Name = "BrokenPillar", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))),
		Color = ({ RGB(225, 220, 200), RGB(175, 170, 160) })[rng:NextInteger(1, 2)] }, folders.Decor)
end)
scatter("SkeletonRuins", 16, function(pos)
	prop({ Name = "Tombstone", Size = Vector3.new(3, 4, 1), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, math.pi), 0),
		Color = RGB(110, 110, 120), Material = Enum.Material.Slate }, folders.Decor)
end, 10)
scatter("SkeletonRuins", 6, function(pos)
	local glow = prop({ Name = "SoulWisp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = pos + Vector3.new(0, 4, 0), Color = RGB(150, 110, 255), Material = NEON }, folders.Decor)
	light(glow, RGB(150, 110, 255), 14, 1.5)
end)
for _, ap in { Vector3.new(1080, 0, -70), Vector3.new(1160, 0, 80), Vector3.new(1220, 0, -60) } do -- 부서진 아치
	local arch = model("BrokenArch", folders.Decor)
	part({ Name = "L", Size = Vector3.new(3, 14, 3), Position = ap + Vector3.new(0, 7, -6), Color = RGB(225, 220, 200) }, arch)
	part({ Name = "R", Size = Vector3.new(3, 9, 3), Position = ap + Vector3.new(0, 4.5, 6), Color = RGB(225, 220, 200) }, arch)
	part({ Name = "Top", Size = Vector3.new(3, 2.5, 9), CFrame = CFrame.new(ap + Vector3.new(0, 14, -2)) * CFrame.Angles(math.rad(-10), 0, 0), Color = RGB(205, 200, 180) }, arch)
end
for i = 1, 4 do -- 찢긴 깃발
	local pos = Vector3.new(1020 + i * 55, 0, (i % 2 == 0) and 40 or -40)
	prop({ Name = "TornPole", Size = Vector3.new(0.6, 12, 0.6), Position = pos + Vector3.new(0, 6, 0), Color = RGB(60, 55, 55) }, folders.Decor)
	prop({ Name = "TornFlag", Size = Vector3.new(0.2, 6, 3.5), Position = pos + Vector3.new(0, 8.5, 2), Color = RGB(90, 70, 120), Material = Enum.Material.Fabric }, folders.Decor)
end

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
-- A11: 엘든 링 풍 황금 노을 + 안개 (Atmosphere 는 쓰지 않는다: A9-3)
Lighting.ClockTime = 16.8
Lighting.Brightness = 1.8
Lighting.Ambient = RGB(70, 60, 55)
Lighting.OutdoorAmbient = RGB(120, 105, 90)
Lighting.FogColor = RGB(190, 170, 140)
Lighting.FogStart = 120
Lighting.FogEnd = 650 -- A12: 멀리 있는 지역은 안개 속으로
pcall(function() Lighting.EnvironmentDiffuseScale = 0.3 end)
pcall(function() Lighting.EnvironmentSpecularScale = 0.3 end)
pcall(function() Lighting.LightingStyle = Enum.LightingStyle.Soft end)
pcall(function() Lighting.PrioritizeLightingQuality = true end)
Lighting.GlobalShadows = true
pcall(function() Lighting.ShadowSoftness = 0.2 end)
pcall(function() Lighting.GeographicLatitude = 35 end)
pcall(function() Lighting.ExposureCompensation = -0.1 end)
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 24, 1.4
bloom.Parent = Lighting
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
rays.Intensity, rays.Spread = 0.08, 0.4
rays.Parent = Lighting
local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
pcall(function() sky.SunAngularSize = 14; sky.MoonAngularSize = 18; sky.StarCount = 3000 end)
sky.Parent = Lighting

return string.format("map parts: %d, lights: %d", count, lights)
