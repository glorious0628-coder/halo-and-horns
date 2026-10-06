-- 빛 마을·뿔 마을 '진짜 마을' 채우기(검수 2026-10-06 "마을치고 작다"): 길 따라 두 줄 거리 + 가운데 광장 + 성벽·큰 문 + 뒤 성채.
-- WorldKit 미리보기 전용. towns_kit_place.luau(kit) 다음에 실행. MODE = "kit" | "old"(이 파일이 만든 것만 지움).
-- 좌표: u = 관문에서 마을 안쪽으로 걷는 거리(빛: z = -320 - u, 뿔: z = 320 + u), x = 그대로. 마을 가운데 u = 80.
-- 길 가운데(|x| < 8)는 비운다. 스폰 (0, ±410) 반경 5도 비운다. 200x200 안(섬 땅 x ±110, u 0~180).
local MODE = "__MODE__"
local SS = game:GetService("ServerStorage")
local kit = SS.KitStage
local map = workspace.Map
local store = SS:FindFirstChild("KitOldTowns") or Instance.new("Folder")
store.Name = "KitOldTowns"; store.Parent = SS

local out = workspace:FindFirstChild("KitTownFill")
if out then out:Destroy() end
-- 이 파일이 숨긴 옛 영웅상 되돌리기
for _, d in ipairs(store:GetChildren()) do
	if d:GetAttribute("FillHidden") then
		d.Parent = map.Decor; d:SetAttribute("FillHidden", nil); d:SetAttribute("OrigParent", nil)
	end
end
if MODE == "old" then return "town fill removed" end
out = Instance.new("Folder"); out.Name = "KitTownFill"; out.Parent = workspace

local log = {}
local count = {}
local function place(name, x, z, yaw, fit, y, parent)
	local src = kit:FindFirstChild(name)
	if not src then count["missing " .. name] = true; return nil end
	local m = src:Clone()
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
	count[name] = (count[name] or 0) + 1
	return m
end

-- 모델 앞(-Z)이 (tx,tz)를 보게 하는 yaw
local function face(x, z, tx, tz) return math.deg(math.atan2(x - tx, z - tz)) end

local TOWNS = {
	{
		key = "Halo", sign = -1, gateZ = -320,
		houses = { "H_House_A", "H_House_B", "H_House_A", "H_Shop_Bakery", "H_House_B", "H_Shop_Potion" },
		ring = { "H_House_A", "H_House_B", "H_House_A", "H_House_B" },
		castle = "H_Castle", wall = "H_Wall", statue = "H_KnightStatue", pot = "H_FlowerPot", banner = "H_Banner",
		crates = "H_Crates", plazaCenter = "K_Fountain", bench = "K_Bench", lamp = "H_Lamp",
		hideDecor = { HeroStatue = true },
	},
	{
		key = "Horns", sign = 1, gateZ = 320,
		houses = { "R_House_A", "R_House_B", "R_Shop_Forge", "R_House_A", "R_Shop_Tavern", "R_House_B" },
		ring = { "R_House_A", "R_House_B", "R_House_A", "R_House_B" },
		castle = "R_Fortress", wall = "R_Wall", statue = "R_WarriorStatue", pot = "R_Planter", banner = "R_Banner",
		crates = "H_Crates", plazaCenter = "R_AltarBrazier", bench = "K_Bench", lamp = "K_Brazier",
		hideDecor = {},
	},
}

local npcSpots = {}
for _, T in ipairs(TOWNS) do
	local folder = Instance.new("Folder"); folder.Name = T.key .. "Fill"; folder.Parent = out
	local function Z(u) return T.gateZ + T.sign * u end
	-- 옛 소품 숨기기(영웅상은 광장 석상으로 바뀜)
	for _, d in ipairs(map.Decor:GetChildren()) do
		if T.hideDecor[d.Name] then
			d:SetAttribute("OrigParent", d.Parent:GetFullName()); d:SetAttribute("FillHidden", true); d.Parent = store
		end
	end
	-- 거리·광장 자리에 걸치는 키트 가시(R_Spikes, towns_kit_place가 놓은 복제본)는 지움 — 되돌릴 땐 towns_kit_place를 다시 실행
	local kt = workspace:FindFirstChild("KitTowns")
	if kt then
		for _, d in ipairs(kt:GetChildren()) do
			if d.Name == "R_Spikes" and d:IsA("Model") then
				local p = d:GetPivot().Position
				local u = (p.Z - T.gateZ) * T.sign
				if math.abs(p.X) < 44 and u > 0 and u < 104 then d:Destroy() end
			end
		end
	end
	-- ① 거리: 길 양쪽 두 줄(집 앞면이 길을 봄), u 16~64
	local us = { 18, 36, 54 }
	local hi = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, u in ipairs(us) do
			hi += 1
			local x = side * 22
			local name = T.houses[((hi - 1) % #T.houses) + 1]
			place(name, x, Z(u), face(x, Z(u), 0, Z(u)), { "w", 12 }, 0, folder)
			-- 문 앞 화분·상자
			place(T.pot, side * 14.5, Z(u) + 4, 0, { "w", 2.4 }, 0, folder)
			if hi % 2 == 0 then place(T.crates, side * 15, Z(u) - 4.5, side * 30, { "w", 3.6 }, 0, folder) end
		end
		-- 깃발: 집 사이
		for _, u in ipairs({ 27, 45 }) do place(T.banner, side * 13, Z(u), face(side * 13, Z(u), 0, Z(u)), { "h", 10 }, 0, folder) end
	end
	-- ② 광장(u 72~96): 가운데 큰 장식, 양옆 석상 2, 벤치 4, 둘레 집 4
	local cz = Z(84)
	place(T.plazaCenter, 0, Z(76), 0, T.key == "Halo" and { "w", 11 } or { "w", 8 }, 0, folder)
	place(T.statue, -12, Z(80), face(-12, Z(80), 0, Z(80) + 10 * -T.sign) , { "h", 9 }, 0, folder)
	place(T.statue, 12, Z(80), face(12, Z(80), 0, Z(80) + 10 * -T.sign), { "h", 9 }, 0, folder)
	for _, p in ipairs({ { -9, 70 }, { 9, 70 }, { -16, 90 }, { 16, 90 } }) do
		place(T.bench, p[1], Z(p[2]), face(p[1], Z(p[2]), 0, Z(80)), { "w", 5.5 }, 0, folder)
	end
	for i, p in ipairs({ { -34, 74 }, { 34, 74 }, { -34, 98 }, { 34, 98 } }) do
		place(T.ring[i], p[1], Z(p[2]), face(p[1], Z(p[2]), 0, Z(86)), { "w", 12 }, 0, folder)
	end
	-- ③ 성벽: 관문 양옆(앞줄) + 양 옆줄, 문 자리(|x| < 16) 비움
	local wf = Instance.new("Folder"); wf.Name = "Walls"; wf.Parent = folder
	for _, x in ipairs({ -88, -70, -52, -34, 34, 52, 70, 88 }) do
		place(T.wall, x, Z(3), 0, { "w", 18 }, 0, wf)
	end
	for _, side in ipairs({ -1, 1 }) do
		for u = 14, 158, 18 do
			place(T.wall, side * 97, Z(u), 90, { "w", 18 }, 0, wf)
		end
	end
	-- ④ 뒤 성채(배경): 섬 끝 쪽 u ~170, 대성당 뒤로 살짝 옆
	place(T.castle, 0, Z(168), T.sign < 0 and 0 or 180, { "w", 70 }, 0, folder)
	-- 퀘스트 NPC(A23-46): 광장 입구 가장자리, 거리에서 걸어 들어오면 정면으로 보이는 자리. 미리보기용 표시만(진짜 NPC는 게임성 개발 1)
	local qx = T.key == "Halo" and -15 or 15
	local qz = Z(68)
	local qname = T.key == "Halo" and "Bright" or "Smokey"
	local mk = Instance.new("Part")
	mk.Name = "NPC_" .. qname; mk.Anchored = true; mk.CanCollide = false; mk.Shape = Enum.PartType.Cylinder
	mk.Size = Vector3.new(0.2, 3, 3); mk.CFrame = CFrame.new(qx, 0.15, qz) * CFrame.Angles(0, 0, math.rad(90))
	mk.Color = Color3.fromRGB(255, 210, 60); mk.Material = Enum.Material.Neon; mk.Parent = folder
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(60, 60); bb.StudsOffset = Vector3.new(0, 6, 0); bb.AlwaysOnTop = true; bb.Parent = mk
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = "!"; tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 220, 60); tl.TextStrokeTransparency = 0; tl.Font = Enum.Font.GothamBlack; tl.Parent = bb
	-- 마을 사람 NPC 자리·동선(게임성 개발 1이 배치)
	table.insert(npcSpots, string.format("%s 퀘스트 NPC %s: (%.0f, %.0f) 광장 입구 가장자리, 거리 쪽(관문 방향)을 봄",
		T.key, qname, qx, qz))
	table.insert(npcSpots, string.format("%s 마을 사람: 서 있기 (%.0f,%.0f) 가게 앞 · (%.0f,%.0f) 집 앞 · (%.0f,%.0f) 광장 벤치 옆 / 걷기 ① 관문(0,%.0f)→광장(0,%.0f) 길 가장자리 x=%d로 왕복 ② 광장 둘레 원(반지름 16, 중심 0,%.0f)",
		T.key, -16, Z(54), 16, Z(18), 9, Z(66), Z(8), Z(70), T.key == "Halo" and 6 or -6, Z(80)))
end
local t = {}
for k, v in pairs(count) do table.insert(t, k .. "=" .. tostring(v)) end
table.sort(t)
table.insert(log, table.concat(t, ", "))
for _, s in ipairs(npcSpots) do table.insert(log, s) end
return table.concat(log, "\n")
