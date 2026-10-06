-- 사용: crossroads_kit_place.luau(kit) 다음에 실행. __CURB_TURN__ = 0.
-- 교차로 2차 소품(거위 둥지·깃대·톱니·거래소 아치·게시판·광장 테두리). kp_kit 뒤에 실행. 같은 KitCrossroads 폴더 사용.
local SS = game:GetService("ServerStorage")
local kit = SS.KitStage
local map = workspace.Map
local L = map.Landmarks
local out = workspace:FindFirstChild("KitCrossroads")
local oldStore = SS.KitOld

local function hide(inst)
	if not inst or inst.Parent == oldStore then return end
	inst:SetAttribute("OrigParent", inst.Parent:GetFullName())
	inst.Parent = oldStore
end
local function fade(inst)
	if not inst then return end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, c in ipairs(list) do
		if c:IsA("BasePart") then
			if c:GetAttribute("PrevT") == nil then c:SetAttribute("PrevT", c.Transparency) end
			c.Transparency = 1
		end
	end
end

local function place(name, x, z, yaw, fit, y, newName, parent)
	local src = kit:FindFirstChild(name)
	if not src then return name .. " missing" end
	local m = src:Clone()
	m.Name = newName or name
	m.Parent = parent or out
	local _, size = m:GetBoundingBox()
	local s = 1
	if fit then
		local dim = fit[1] == "w" and size.X or fit[1] == "h" and size.Y or size.Z
		s = fit[2] / dim
	end
	if math.abs(s - 1) > 1e-3 then m:ScaleTo(m:GetScale() * s) end
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (Vector3.new(x, (y or 0) + sz.Y / 2, z) - cf.Position))
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local _, fin = m:GetBoundingBox()
	return string.format("%s -> %.1fx%.1fx%.1f", m.Name, fin.X, fin.Y, fin.Z), m
end

local log = {}
local function P(...) local s = place(...); table.insert(log, s) end

-- 거위 둥지: GoosePerch(계약 모델)는 투명하게, 키트 둥지를 그 자리에
fade(L:FindFirstChild("GoosePerch"))
P("K_Nest", -30, 30, 0, { "w", 12 })

-- 진영 깃대: 옛 막대·천 숨기고 키트 깃대 + 천(2:3 Banner_* 자리, 지금은 색만)
for _, d in ipairs(map.Decor:GetChildren()) do
	if d.Name == "HaloPole" or d.Name == "HaloFlag" or d.Name == "HornsPole" or d.Name == "HornsFlag" then hide(d) end
end
local function flag(poleName, x, z, color, yaw)
	local _, pole = place(poleName, x, z, yaw, { "h", 14 })
	if not pole then return end
	local cf, sz = pole:GetBoundingBox()
	local cloth = Instance.new("Part")
	cloth.Name = "BannerCloth"
	cloth.Anchored = true
	cloth.CanCollide = false
	cloth.Material = Enum.Material.Fabric
	cloth.Color = color
	cloth.Size = Vector3.new(5.3, 8, 0.2)
	-- 가로대 아래에 매달기(깃대 위쪽 15% 아래부터)
	local top = cf.Position.Y + sz.Y / 2
	cloth.CFrame = CFrame.new(x, top - sz.Y * 0.12 - 4, z) * CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.new(0, 0, 0.6)
	cloth.Parent = pole
	table.insert(log, poleName .. string.format(" + cloth at y %.1f", cloth.Position.Y))
end
for _, sx in ipairs({ -12, 12 }) do
	flag("K_PoleHalo", sx, -60, Color3.fromRGB(120, 175, 245), 0)
	flag("K_PoleHorns", sx, 60, Color3.fromRGB(150, 28, 40), 180)
end

-- 길드 톱니(앞면 위)
P("K_Gear", 44, 48.6, 0, { "w", 4.6 }, 9.6)

-- 거래소 입구 아치: 장터 쪽 큰길 입구, 광장을 보게
do
	local x, z = -27, -27
	P("K_MarketArch", x, z, math.deg(math.atan2(x, z)), { "w", 12 })
	fade(L:FindFirstChild("MarketSign"))
end

-- 현상수배 게시판: 판 앞면이 +X(광장)를 보게. MostWantedBoard(글자판)는 그대로 둠
do
	for _, c in ipairs(L.MostWantedBoard:GetChildren()) do
		if c:IsA("BasePart") then fade(c) end -- 옛 기둥
	end
	P("K_NoticeBoard2", -57.5, 0, -90, { "w", 16 })
	-- 미리보기: 글자판(MostWantedBoard)을 키트 판 가운데 크기로 (게임성 개발 1에 같은 값 전달)
	local b = L.MostWantedBoard
	if b:GetAttribute("PrevSize") == nil then b:SetAttribute("PrevSize", b.Size); b:SetAttribute("PrevCF", b.CFrame) end
	b.Size = Vector3.new(0.4, 9.6, 11.8)
	b.CFrame = CFrame.new(-55.0, 8.4, 0) * (b:GetAttribute("PrevCF") - b:GetAttribute("PrevCF").Position)
end

-- 이동 발판: 옛 네온 판은 투명하게(터치 판정은 그대로), 둘레 빛 조각은 키트 받침 위로
for _, pad in ipairs(map.Pads:GetChildren()) do
	if pad:IsA("BasePart") then
		if pad:GetAttribute("PrevT") == nil then pad:SetAttribute("PrevT", pad.Transparency) end
		pad.Transparency = 1
		for _, c in ipairs(pad:GetChildren()) do
			if c:IsA("BasePart") then
				if c:GetAttribute("PrevY") == nil then c:SetAttribute("PrevY", c.Position.Y) end
				c.Position = Vector3.new(c.Position.X, 2.0, c.Position.Z)
			end
		end
	end
end

-- 광장 테두리: 반지름 26.5, 길 입구(|x|<10 또는 |z|<10)는 비움
local ring = Instance.new("Folder")
ring.Name = "PlazaCurb"
ring.Parent = out
local R, n = 28.5, 30
local count = 0
for i = 0, n - 1 do
	local phi = (i + 0.5) / n * math.pi * 2
	local x, z = R * math.sin(phi), R * math.cos(phi)
	if math.abs(x) > 10 and math.abs(z) > 10 then
		place("K_Curb", x, z, math.deg(phi) + __CURB_TURN__, { "w", 6.2 }, 0, "Curb", ring)
		count += 1
	end
end
table.insert(log, "curbs " .. count)
return table.concat(log, "\n")
