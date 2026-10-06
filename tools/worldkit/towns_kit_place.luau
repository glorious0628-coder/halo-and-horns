-- 빛 마을·뿔 마을 키트 미리보기(WorldKit 전용). MODE = "kit" | "old".
-- ServerStorage.KitStage에 art/models/worldkit/manifest.json의 H_*/R_*/K_Brazier 이름으로 애셋을 먼저 넣는다.
-- 옛 소품은 ServerStorage.KitOldTowns로 옮기거나(숨김) 투명하게(계약 파트) 하고, MODE="old"로 되돌린다.
local MODE = "__MODE__"
local SS = game:GetService("ServerStorage")
local kit = SS.KitStage
local map = workspace.Map
local store = SS:FindFirstChild("KitOldTowns") or Instance.new("Folder")
store.Name = "KitOldTowns"
store.Parent = SS

local function restore()
	for _, d in ipairs(store:GetChildren()) do
		local parent = game
		for seg in string.gmatch(d:GetAttribute("OrigParent") or "", "[^%.]+") do
			if seg ~= "game" and parent then parent = parent:FindFirstChild(seg) end
		end
		d.Parent = parent or workspace
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("PrevTT") ~= nil then
			d.Transparency = d:GetAttribute("PrevTT")
			d:SetAttribute("PrevTT", nil)
		end
	end
end
local function hide(inst)
	if not inst or inst.Parent == store then return end
	inst:SetAttribute("OrigParent", inst.Parent:GetFullName())
	inst.Parent = store
end
local function fade(inst)
	if not inst then return end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, c in ipairs(list) do
		if c:IsA("BasePart") then
			if c:GetAttribute("PrevTT") == nil then c:SetAttribute("PrevTT", c.Transparency) end
			c.Transparency = 1
		end
	end
end

local out = workspace:FindFirstChild("KitTowns")
if out then out:Destroy() end
restore()
if MODE == "old" then return "restored towns" end
out = Instance.new("Folder")
out.Name = "KitTowns"
out.Parent = workspace

local log = {}
local function place(name, x, z, yaw, fit, y, parent)
	local src = kit:FindFirstChild(name)
	if not src then table.insert(log, name .. " missing"); return nil end
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
	return m
end
local function faceYaw(x, z, cx, cz) return math.deg(math.atan2(x - cx, z - cz)) end

local decor = map.Decor
local function each(name, fn)
	local list = {}
	for _, d in ipairs(decor:GetChildren()) do
		if d.Name == name then table.insert(list, d) end
	end
	for _, d in ipairs(list) do
		local p = d:IsA("BasePart") and d.Position or d:GetPivot().Position
		fn(d, p)
	end
	return #list
end

---------------- 빛 마을 (중심 0,-400) ----------------
do
	local g = map.Gates:FindFirstChild("Gate_HaloTown")
	if g then
		for _, c in ipairs(g:GetChildren()) do
			if c:IsA("BasePart") then fade(c) end -- Lintel 등 계약 파트는 지우지 않고 투명하게
		end
	end
	place("H_Gate", 0, -320, 180 + __HGATE_TURN__, { "w", 30 })
	local cat = map.Landmarks:FindFirstChild("Cathedral")
	fade(cat)
	place("H_Cathedral", 0, -458, 180 + __HCAT_TURN__, { "w", 40 })
	local n = each("HaloTower", function(d, p)
		hide(d)
		place(__HTOWER__, p.X, p.Z, faceYaw(p.X, p.Z, 0, -400), { "h", 34 })
	end)
	table.insert(log, "halo towers " .. n)
	n = each("Cloud", function(d, p)
		if p.Z < -300 then
			hide(d)
			place("H_Cloud", p.X, p.Z, (p.X * 7) % 360, { "w", 11 }, 2.5)
		end
	end)
	n = each("Flower", function(d, p)
		if p.Z < -300 then
			hide(d)
			place("H_Flowers", p.X, p.Z, (p.Z * 13) % 360, { "w", 3.2 })
		end
	end)
	-- 다리: 상판(Deck)·받침은 두고 난간·기둥·등불만 바꿈
	local br = decor:FindFirstChild("Bridge_Halo")
	if br then
		local lamps = {}
		for _, c in ipairs(br:GetChildren()) do
			if c.Name == "Rail" or c.Name == "Post" then fade(c) end
			if c.Name == "Lamp" then fade(c); table.insert(lamps, c.Position) end
		end
		local deck = br:FindFirstChild("Deck")
		local z0, z1 = deck.Position.Z + deck.Size.Z / 2, deck.Position.Z - deck.Size.Z / 2
		local seg = 12
		local folder = Instance.new("Folder"); folder.Name = "HaloBridgeKit"; folder.Parent = out
		local count = 0
		for _, sx in ipairs({ -8.6, 8.6 }) do
			local z = z0 - seg / 2 - 1.5
			while z - seg / 2 > z1 + 1.5 do
				place("H_BridgeRail", sx, z, 90, { "w", seg }, 0.2, folder)
				count += 1
				z -= seg
			end
			place("H_BridgePost", sx, z0 - 0.8, 0, { "h", 6 }, 0.2, folder)
			place("H_BridgePost", sx, z1 + 0.8, 0, { "h", 6 }, 0.2, folder)
		end
		for _, p in ipairs(lamps) do
			place("H_Lamp", p.X > 0 and 9.6 or -9.6, p.Z, 0, { "h", 8 }, 0.2, folder)
		end
		table.insert(log, "halo bridge rails " .. count .. " lamps " .. #lamps)
	end
end

---------------- 뿔 마을 (중심 0,400) ----------------
do
	local g = map.Gates:FindFirstChild("Gate_HornsTown")
	if g then
		for _, c in ipairs(g:GetChildren()) do
			if c:IsA("BasePart") then fade(c) end
		end
	end
	place("R_Gate", 0, 320, 0 + __RGATE_TURN__, { "w", 30 })
	local n = each("HornTower", function(d, p)
		hide(d)
		place("R_Watchtower", p.X, p.Z, faceYaw(p.X, p.Z, 0, 400), { "h", 28 })
	end)
	table.insert(log, "horn towers " .. n)
	n = each("Spike", function(d, p)
		if p.Z > 300 then
			hide(d)
			place("R_Spikes", p.X, p.Z, faceYaw(p.X, p.Z, 0, 400), { "h", 9 })
		end
	end)
	table.insert(log, "spikes " .. n)
	-- 용암 수로: 옛 네온 띠·테두리 숨기고 마디를 이어 붙임(길이 방향 = z)
	for _, nm in ipairs({ "LavaChannel", "ChannelRimL", "ChannelRimR" }) do
		each(nm, function(d) hide(d) end)
	end
	local lc = Instance.new("Folder"); lc.Name = "LavaKit"; lc.Parent = out
	-- R_LavaChannel 원본은 길이 방향이 z(1.6 x 2 x 2.6)라 yaw 0, 길이 6으로 맞추고 아래 60%는 땅에 묻는다
	for _, sx in ipairs({ -48, 48 }) do
		for z = 338, 462, 5.9 do
			local m = place("R_LavaChannel", sx, z, 0, { "d", 6 }, 0, lc)
			if m then
				local _, sz = m:GetBoundingBox()
				m:PivotTo(m:GetPivot() - Vector3.new(0, sz.Y * 0.6, 0))
			end
		end
	end
	local br = decor:FindFirstChild("Bridge_Horns")
	if br then
		local lamps = {}
		for _, c in ipairs(br:GetChildren()) do
			if c.Name == "Rail" or c.Name == "Post" then fade(c) end
			if c.Name == "Lamp" then fade(c); table.insert(lamps, c.Position) end
		end
		local deck = br:FindFirstChild("Deck")
		local z0, z1 = deck.Position.Z - deck.Size.Z / 2, deck.Position.Z + deck.Size.Z / 2
		local seg = 12
		local folder = Instance.new("Folder"); folder.Name = "HornsBridgeKit"; folder.Parent = out
		local count = 0
		for _, sx in ipairs({ -8.6, 8.6 }) do
			local z = z0 + seg / 2 + 1.5
			while z + seg / 2 < z1 - 1.5 do
				place("R_BridgeRail", sx, z, 90, { "w", seg }, 0.2, folder)
				count += 1
				z += seg
			end
		end
		for _, p in ipairs(lamps) do
			place("K_Brazier", p.X > 0 and 9.6 or -9.6, p.Z, 0, { "h", 3.6 }, 0.2, folder)
		end
		table.insert(log, "horns bridge rails " .. count .. " braziers " .. #lamps)
	end
end
---------------- 다듬기: 텅 빈 마을 길에 등불(빛 마을)·화로(뿔 마을) 추가 — 진짜 빛(PointLight)은 넣지 않음 ----------------
do
	local ex = Instance.new("Folder"); ex.Name = "TownExtras"; ex.Parent = out
	local n = 0
	for z = -330, -390, -20 do -- 영웅상(z -340·-360·-380) 사이
		for _, sx in ipairs({ -10.5, 10.5 }) do
			place("H_Lamp", sx, z, 0, { "h", 8 }, 0, ex); n += 1
		end
	end
	for z = 335, 395, 20 do
		for _, sx in ipairs({ -10.5, 10.5 }) do
			place("K_Brazier", sx, z, 0, { "h", 3.6 }, 0, ex); n += 1
		end
	end
	table.insert(log, "town road extras " .. n)
end
return table.concat(log, "\n")
