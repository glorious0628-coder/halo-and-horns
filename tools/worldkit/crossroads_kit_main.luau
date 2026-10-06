-- crossroads_kit_main.luau : the 21-model crossroads prop kit (art/models/worldkit/manifest.json, 52ca1db) placed in the
-- MAIN place, keeping every gameplay contract. Edit mode only, idempotent (rebuilds Map.Decor.CrossroadsKit each run).
-- Run by tools/apply_crossroads_kit.py, which first inserts the K_* models into ServerStorage.KitStage.
--   * pure decor (old lamps, stalls, benches, braziers, faction poles/flags, guild hall parts) moves to
--     ServerStorage.KitOld (kept, never deleted);
--   * contract parts stay where they are but invisible / non-colliding: Landmarks.Fountain (+PrimaryPart),
--     Landmarks.CrownShard (Beam / light keep working), Landmarks.Altar (+AltarPrompt), ArtisanGuild.Anvil (shop
--     distance, guide, map), Landmarks.GoosePerch, Landmarks.MarketSign (map spot, its floating text goes: A23-36),
--     the MostWantedBoard (shrunk onto the kit board face, its SurfaceGui stays), the old board posts;
--   * pads: the neon pad turns invisible and non-colliding on top of the kit base (TopY attribute for MapBuilder.placePad,
--     touch stays), its ring segments sit on the base;
--   * 4 of the 8 kit lamps and one brazier get the old PointLights (map budget 40).
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local SS = game:GetService("ServerStorage")
local kit = SS:FindFirstChild("KitStage")
if not kit then error("ServerStorage.KitStage가 없습니다 (apply_crossroads_kit.py로 먼저 넣기)") end
local map = workspace.Map
local L, D = map.Landmarks, map.Decor
local log = {}

local oldStore = SS:FindFirstChild("KitOld") or Instance.new("Folder")
oldStore.Name = "KitOld"
oldStore.Parent = SS

local function hide(inst)
	if not inst or inst.Parent == oldStore then return end
	inst:SetAttribute("OrigParent", inst.Parent:GetFullName())
	inst.Parent = oldStore
end

-- invisible + no collision, remembering the old values once (a re-run keeps the first remembered values)
local function ghost(inst, keepCollide)
	if not inst then return end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, c in list do
		if c:IsA("BasePart") then
			if c:GetAttribute("KitPrevT") == nil then
				c:SetAttribute("KitPrevT", c.Transparency)
				c:SetAttribute("KitPrevCollide", c.CanCollide)
			end
			c.Transparency = 1
			if not keepCollide then c.CanCollide = false end
		elseif c:IsA("Decal") or c:IsA("Texture") then
			c.Transparency = 1
		end
	end
end

local out = D:FindFirstChild("CrossroadsKit")
if out then out:Destroy() end
out = Instance.new("Model")
out.Name = "CrossroadsKit"
out.Parent = D

-- place(name, x, z, yaw, fit, y, opts) -> model ; fit = { "w" | "h" | "d", size }
local function place(name, x, z, yaw, fit, y, opts)
	opts = opts or {}
	local src = kit:FindFirstChild(name)
	if not src then table.insert(log, name .. " missing"); return nil end
	local m = src:Clone()
	m.Name = opts.Name or name
	m.Parent = opts.Parent or out
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
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if opts.NoCollide then d.CanCollide = false end
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy() -- A23-33 safety: kit models never carry scripts
		end
	end
	return m
end

local function face(x, z) return math.deg(math.atan2(x, z)) end -- model front (-Z) toward the plaza centre

local function copyLight(fromParts, toPart, y)
	local src
	for _, p in fromParts do
		src = p:FindFirstChildWhichIsA("PointLight", true)
		if src then break end
	end
	if not (src and toPart) then return false end
	local holder = Instance.new("Part")
	holder.Name = "KitLight"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency, holder.Size = 1, Vector3.new(0.4, 0.4, 0.4)
	local cf = toPart:GetBoundingBox()
	holder.Position = Vector3.new(cf.Position.X, y, cf.Position.Z)
	holder.Parent = toPart
	src:Clone().Parent = holder
	return true
end

------------------------------------------------------------------ 1. old decor out, contract parts ghosted
local oldLamps, oldBraziers = {}, {}
for _, d in D:GetChildren() do
	local p = d:IsA("BasePart") and d.Position or (d:IsA("Model") and d:GetPivot().Position)
	if p and math.abs(p.X) <= 110 and math.abs(p.Z) <= 110 then
		local n = d.Name
		if n == "Lamp" then table.insert(oldLamps, d); hide(d)
		elseif n == "Brazier" then table.insert(oldBraziers, d); hide(d)
		elseif n == "MarketStall" or n == "Bench" or n == "BrazierStand" or n == "HaloPole" or n == "HaloFlag"
			or n == "HornsPole" or n == "HornsFlag" then
			hide(d)
		end
	end
end
-- lamps / braziers already moved by an earlier run: their lights are copied from the stored ones
for _, d in oldStore:GetChildren() do
	if d.Name == "Lamp" then table.insert(oldLamps, d) elseif d.Name == "Brazier" then table.insert(oldBraziers, d) end
end

local guild = L:FindFirstChild("ArtisanGuild")
if guild then
	for _, c in guild:GetChildren() do
		if c:IsA("BasePart") and c.Name ~= "Anvil" then hide(c) end
		if c:IsA("BillboardGui") then c.MaxDistance = math.min(c.MaxDistance, 50) end
	end
	ghost(guild:FindFirstChild("Anvil"))
end
ghost(L:FindFirstChild("Fountain"))
local shard = L:FindFirstChild("CrownShard")
if shard then
	-- the neon block goes invisible; Beam / PointLight / attachments under it keep working
	if shard:IsA("BasePart") then
		if shard:GetAttribute("KitPrevT") == nil then shard:SetAttribute("KitPrevT", shard.Transparency) end
		shard.Transparency = 1
		shard.CanCollide = false
	else
		ghost(shard)
	end
end
ghost(L:FindFirstChild("Altar"))
ghost(L:FindFirstChild("GoosePerch"))
local market = L:FindFirstChild("MarketSign")
if market then
	ghost(market)
	for _, d in market:GetDescendants() do
		if d:IsA("BillboardGui") then d:Destroy() end -- A23-36: the kit arch carries a blank board
	end
end

------------------------------------------------------------------ 2. kit
place("K_Fountain", 0, 0, 0, { "w", 21 })
place("K_CrownShard", 0, 0, 0, { "w", 7 }, 21, { NoCollide = true })
for _, xz in { { -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 } } do
	place("K_Bench", xz[1], xz[2], face(xz[1], xz[2]), { "w", 6.5 })
end
local lamps = {}
for _, xz in { { -12.2, -29.6 }, { -12.2, 29.6 }, { -29.6, -12.2 }, { -29.6, 12.2 }, { 12.2, -29.6 }, { 12.2, 29.6 },
	{ 29.6, -12.2 }, { 29.6, 12.2 } } do
	table.insert(lamps, place("K_Lamp", xz[1], xz[2], face(xz[1], xz[2]) + 180, { "h", 11 }))
end
local lit = 0
for i, lamp in lamps do
	if lamp and i % 2 == 1 and copyLight(oldLamps, lamp, 9.5) then lit += 1 end
end
for _, st in { { "K_StallRed", -12.2, -52.8 }, { "K_StallBlue", -22.4, -42.7 }, { "K_StallGreen", -36.6, -34.5 },
	{ "K_StallRed", -46.7, -20.3 } } do
	place(st[1], st[2], st[3], face(st[2], st[3]), { "w", 10 })
end
place("K_Potion", 12, -40, face(12, -40), { "h", 7.5 })
place("K_Guild2", 44, 60, 0, { "w", 24 })
place("K_Gear", 44, 48.6, 0, { "w", 4.6 }, 9.6, { NoCollide = true })
place("K_Anvil", 39, 45, 0, { "d", 4.5 })
place("K_Forge", 49, 45, 0, { "h", 6 })
place("K_Altar", 0, 45, 0, { "w", 9 })
local braziers = { place("K_Brazier", -15, 60, 0, { "h", 4 }), place("K_Brazier", 15, 60, 0, { "h", 4 }) }
if braziers[2] and copyLight(oldBraziers, braziers[2], 4.2) then lit += 1 end
place("K_Nest", -30, 30, 0, { "w", 12 })
place("K_MarketArch", -27, -27, face(-27, -27), { "w", 12 })

-- faction poles + cloth (2:3 Banner_* decal later, colour now)
local function flag(poleName, x, z, color, yaw)
	local pole = place(poleName, x, z, yaw, { "h", 14 })
	if not pole then return end
	local cf, sz = pole:GetBoundingBox()
	local cloth = Instance.new("Part")
	cloth.Name = "BannerCloth"
	cloth.Anchored, cloth.CanCollide = true, false
	cloth.Material, cloth.Color = Enum.Material.Fabric, color
	cloth.Size = Vector3.new(5.3, 8, 0.2)
	local top = cf.Position.Y + sz.Y / 2
	cloth.CFrame = CFrame.new(x, top - sz.Y * 0.12 - 4, z) * CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.new(0, 0, 0.6)
	cloth.Parent = pole
end
for _, sx in { -12, 12 } do
	flag("K_PoleHalo", sx, -60, Color3.fromRGB(120, 175, 245), 0)
	flag("K_PoleHorns", sx, 60, Color3.fromRGB(150, 28, 40), 180)
end

-- notice board: the kit board behind, the MostWantedBoard (its +X SurfaceGui) shrunk onto the board face
local board = L:FindFirstChild("MostWantedBoard")
if board then
	for _, c in board:GetChildren() do
		if c:IsA("BasePart") then ghost(c) end -- the old posts
	end
	place("K_NoticeBoard2", -57.5, 0, -90, { "w", 16 })
	if board:GetAttribute("KitPrevSize") == nil then
		board:SetAttribute("KitPrevSize", board.Size)
		board:SetAttribute("KitPrevCF", board.CFrame)
	end
	local rot = board:GetAttribute("KitPrevCF") - board:GetAttribute("KitPrevCF").Position
	board.Size = Vector3.new(0.4, 9.6, 11.8)
	board.CFrame = CFrame.new(-55.0, 8.4, 0) * rot
end

-- pads: kit base under each, the neon pad invisible + non-colliding on the base top (touch keeps working)
local pads = map:FindFirstChild("Pads")
local padN = 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
-- Config.Map.Pads positions (MapBuilder moves the pads there at runtime too: the Edit map may still hold old spots)
for name, xz in { Pad_SlimeMeadow = { 52, -24 }, Pad_GoblinWoods = { 52, 24 }, Pad_SkeletonRuins = { 68, 24 } } do
	local base = place("K_PadBase", xz[1], xz[2], 0, { "w", 12 })
	if base and pads then
		params.FilterDescendantsInstances = { base }
		local hit = workspace:Raycast(Vector3.new(xz[1], 40, xz[2]), Vector3.new(0, -80, 0), params)
		local topY = hit and hit.Position.Y or 3.1
		for _, pad in pads:GetChildren() do
			if pad:IsA("BasePart") and pad.Name == name then
				if pad:GetAttribute("KitPrevT") == nil then pad:SetAttribute("KitPrevT", pad.Transparency) end
				local delta = Vector3.new(xz[1] - pad.Position.X, (topY + 0.05) - (pad.Position.Y + pad.Size.Y / 2),
					xz[2] - pad.Position.Z)
				for _, c in pad:GetDescendants() do
					if c:IsA("BasePart") then c.CFrame = c.CFrame + delta end
				end
				pad.CFrame = pad.CFrame + delta
				pad.Transparency = 1
				pad.CanCollide = false
				pad.CanTouch = true
				pad:SetAttribute("TopY", topY + 0.05) -- MapBuilder.placePad keeps this height at runtime
				pad:SetAttribute("KitBase", true)
				padN += 1
			end
		end
	end
end

-- plaza curb ring (walk-through: CanCollide false)
local curbs = 0
local ring = Instance.new("Model")
ring.Name = "PlazaCurb"
ring.Parent = out
for i = 0, 29 do
	local phi = (i + 0.5) / 30 * math.pi * 2
	local x, z = 28.5 * math.sin(phi), 28.5 * math.cos(phi)
	if math.abs(x) > 10 and math.abs(z) > 10 then
		if place("K_Curb", x, z, math.deg(phi), { "w", 6.2 }, 0, { Name = "Curb", Parent = ring, NoCollide = true }) then
			curbs += 1
		end
	end
end

local parts, tris = 0, 0
for _, d in out:GetDescendants() do
	if d:IsA("BasePart") then parts += 1 end
end
table.insert(log, string.format("kit models %d, parts %d, lights %d, pads %d, curbs %d, old stored %d",
	#out:GetChildren(), parts, lit, padN, curbs, #oldStore:GetChildren()))
return table.concat(log, " | ")
