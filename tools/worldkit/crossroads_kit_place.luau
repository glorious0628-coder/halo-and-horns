-- 사용: __MODE__ = "kit"(키트 보이기) / "old"(옛 모습), __BENCH_TURN__·__STALL_TURN__ = 0, __GUILD__ = "K_Guild2", 44, 60, 0, fit = { "w", 24 }. ServerStorage.KitStage에 art/models/worldkit/manifest.json의 K_* 이름으로 애셋을 먼저 넣는다(Studio MCP insert_asset). WorldKit 미리보기용 — 메인 배치는 게임성 개발 1이 계약(이름·PrimaryPart·프롬프트)을 지켜 옮긴다.
-- 교차로: 옛 소품 숨기기(ServerStorage.KitOld로 옮김, 자리 기록) + 키트 모델 제자리 배치 (WorldKit 미리보기 전용)
local SS = game:GetService("ServerStorage")
local kit = SS.KitStage
local map = workspace.Map
local MODE = "__MODE__" -- "kit" = 키트 보이기, "old" = 옛 모습 되돌리기

local oldStore = SS:FindFirstChild("KitOld") or Instance.new("Folder")
oldStore.Name = "KitOld"
oldStore.Parent = SS

local function hide(inst)
	if MODE ~= "kit" then return end
	if not inst or inst.Parent == oldStore then return end
	inst:SetAttribute("OrigParent", inst.Parent:GetFullName())
	inst.Parent = oldStore
end

local function restoreAll()
	for _, d in ipairs(oldStore:GetChildren()) do
		local path = d:GetAttribute("OrigParent")
		local parent = game
		for seg in string.gmatch(path or "", "[^%.]+") do
			if seg ~= "game" then parent = parent and parent:FindFirstChild(seg) end
		end
		d.Parent = parent or workspace
	end
	for _, d in ipairs(workspace.Map:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("PrevT") ~= nil then
			d.Transparency = d:GetAttribute("PrevT")
			d:SetAttribute("PrevT", nil)
		end
		if d:IsA("BasePart") and d:GetAttribute("PrevSize") ~= nil then
			d.Size = d:GetAttribute("PrevSize")
			d.CFrame = d:GetAttribute("PrevCF")
			d:SetAttribute("PrevSize", nil)
			d:SetAttribute("PrevCF", nil)
		end
		if d:IsA("BasePart") and d:GetAttribute("PrevY") ~= nil then
			d.Position = Vector3.new(d.Position.X, d:GetAttribute("PrevY"), d.Position.Z)
			d:SetAttribute("PrevY", nil)
		end
	end
end

local function fade(inst)
	if MODE ~= "kit" or not inst then return end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, c in ipairs(list) do
		if c:IsA("BasePart") then
			if c:GetAttribute("PrevT") == nil then c:SetAttribute("PrevT", c.Transparency) end
			c.Transparency = 1
		end
	end
end

local out = workspace:FindFirstChild("KitCrossroads")
if out then out:Destroy() end
restoreAll()
out = Instance.new("Folder")
out.Name = "KitCrossroads"
out.Parent = workspace

-- spec: {kit, x, z, yaw(deg) or "face", fit = {"w"|"h"|"d"|"s", value}, y = ground}
local function place(spec)
	local src = kit:FindFirstChild(spec[1])
	if not src then return spec[1] .. " missing" end
	local m = src:Clone()
	m.Name = spec.name or spec[1]
	m.Parent = out
	local _, size = m:GetBoundingBox()
	local f = spec.fit
	local s = 1
	if f then
		if f[1] == "w" then s = f[2] / size.X
		elseif f[1] == "h" then s = f[2] / size.Y
		elseif f[1] == "d" then s = f[2] / size.Z
		elseif f[1] == "s" then s = f[2] end
	end
	if math.abs(s - 1) > 1e-3 then m:ScaleTo(m:GetScale() * s) end
	local yaw = spec[4]
	local x, z = spec[2], spec[3]
	if yaw == "face" then
		-- 모델 앞(-Z)이 광장 가운데를 보게 (+ spec.turn 보정)
		yaw = math.deg(math.atan2(x, z)) + (spec.turn or 0)
	end
	local rot = CFrame.Angles(0, math.rad(yaw or 0), 0)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * rot)
	local cf, sz = m:GetBoundingBox()
	local pv = m:GetPivot()
	local groundY = spec.y or 0
	local delta = Vector3.new(x, groundY + sz.Y / 2, z) - cf.Position
	m:PivotTo(pv + delta)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local _, fin = m:GetBoundingBox()
	return string.format("%s s=%.2f -> %.1fx%.1fx%.1f", m.Name, s, fin.X, fin.Y, fin.Z)
end

local log = {}
local function P(spec) table.insert(log, place(spec)) end

-- 옛 소품 숨기기
local L = map.Landmarks
hide(L:FindFirstChild("Fountain"))
for _, d in ipairs(map.Decor:GetChildren()) do
	local p = d:IsA("BasePart") and d.Position or (d:IsA("Model") and d:GetPivot().Position)
	if p and math.abs(p.X) <= 110 and math.abs(p.Z) <= 110 then
		if d.Name == "Lamp" or d.Name == "MarketStall" or d.Name == "Bench" or d.Name == "Brazier" or d.Name == "BrazierStand" then
			hide(d)
		end
	end
end
local guild = L:FindFirstChild("ArtisanGuild")
if guild then
	for _, c in ipairs(guild:GetChildren()) do
		if c:IsA("BasePart") and c.Name ~= "Anvil" then hide(c) end
	end
	-- 모루는 계약 파트라 지우지 않고 투명하게(미리보기)
	fade(guild:FindFirstChild("Anvil"))
end
local altar = L:FindFirstChild("Altar")
fade(altar)
local shard = L:FindFirstChild("CrownShard")
fade(shard)

-- 발판은 Config 자리로(MapBuilder가 실행 때 하는 것과 같게)
local PADPOS = { Pad_SlimeMeadow = Vector3.new(52, 0, -24), Pad_GoblinWoods = Vector3.new(52, 0, 24), Pad_SkeletonRuins = Vector3.new(68, 0, 24) }
for name, pos in pairs(PADPOS) do
	local pad = map.Pads:FindFirstChild(name)
	if pad then
		if pad:GetAttribute("PreviewOrigin") == nil then pad:SetAttribute("PreviewOrigin", pad.Position) end
		local origin = pad:GetAttribute("PreviewOrigin")
		local target = (MODE == "kit") and Vector3.new(pos.X, origin.Y + 1.4, pos.Z) or origin
		local d = target - pad.Position
		for _, c in ipairs(pad:GetDescendants()) do if c:IsA("BasePart") then c.Position += d end end
		pad.Position += d
	end
end

if MODE == "old" then out:Destroy() return "restored old crossroads" end

-- 키트 놓기
P({ "K_Fountain", 0, 0, 0, fit = { "w", 21 } })
P({ "K_CrownShard", 0, 0, 0, fit = { "w", 7 }, y = 21 })
for _, xz in ipairs({ { -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 } }) do
	P({ "K_Bench", xz[1], xz[2], "face", fit = { "w", 6.5 }, turn = __BENCH_TURN__ })
end
for _, xz in ipairs({ { -12.2, -29.6 }, { -12.2, 29.6 }, { -29.6, -12.2 }, { -29.6, 12.2 }, { 12.2, -29.6 }, { 12.2, 29.6 }, { 29.6, -12.2 }, { 29.6, 12.2 } }) do
	P({ "K_Lamp", xz[1], xz[2], "face", fit = { "h", 11 }, turn = 180 })
end
local stalls = { { "K_StallRed", -12.2, -52.8 }, { "K_StallBlue", -22.4, -42.7 }, { "K_StallGreen", -36.6, -34.5 }, { "K_StallRed", -46.7, -20.3 } }
for _, st in ipairs(stalls) do
	P({ st[1], st[2], st[3], "face", fit = { "w", 10 }, turn = __STALL_TURN__ })
end
P({ "K_Potion", 12, -40, "face", fit = { "h", 7.5 }, turn = __STALL_TURN__ })
P({ __GUILD__ })
P({ "K_Anvil", 39, 45, 0, fit = { "d", 4.5 } })
P({ "K_Forge", 49, 45, 0, fit = { "h", 6 } })
P({ "K_Altar", 0, 45, 0, fit = { "w", 9 } })
P({ "K_Brazier", -15, 60, 0, fit = { "h", 4 } })
P({ "K_Brazier", 15, 60, 0, fit = { "h", 4 } })
for _, xz in ipairs({ { 52, -24 }, { 52, 24 }, { 68, 24 } }) do
	P({ "K_PadBase", xz[1], xz[2], 0, fit = { "w", 12 } })
end
return table.concat(log, "\n")
