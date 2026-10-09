-- zone_swap.luau (이미지 생성 1, 2026-10-09; 사용자 "재활용·자리표시 싹 다 새로 만들어", SPEC A23-96, docs/design/remake_list_2026-10-09.md P2)
-- Studio MCP execute_luau, MAIN place, Edit mode only (메인 반영 runs it; the runner replaces "__MODE__" and "__ZONE__").
-- Swaps the Parts / Models the map builder placed (HaloTower, HeroStatue, HornTower, Spike, BrokenArch, BrokenPillar, Tombstone,
-- TornPole, Pumpkin, GF_*) for our own Tripo models in ServerStorage.WorldKit3D, ONE ZONE PER RUN (RULES below, "__ZONE__" =
-- halo | horns | ruins | pumpkin | hollow):
--   * the old instance moves to ServerStorage.ZoneSwapOld (never destroyed; attribute ZoneSwapFrom = its parent path) and the new
--     clone takes its spot: same XZ centre, same bottom height, scaled so its HEIGHT is the old bounding box height x rule.H;
--   * yaw: "keep" = the old pivot's yaw; "face" = front (-Z) toward the axis x = rule.FaceX; arches / walls
--     (rule.Span) turn 90 deg when the old long horizontal side and the new one differ;
--   * a rule whose kit model is missing leaves the old instance where it is (the screen never goes blank) and is listed MISSING;
--   * rule.Remove = true only removes (stashes) the old instance (e.g. TornFlag next to the new banner);
--   * solid pieces (rule.Solid) are DecorPlayerOnly (players bump, monsters / pets walk through); small ones walk-through.
-- Output: Map.Decor.ZoneSwap_<zone> (Model), rebuilt on every run. MODE: "plan" = list what would be swapped, "apply" (default),
-- "restore" = remove the clones and put the old ones back. Idempotent: apply first restores this zone's stashed olds, then swaps.
local MODE = "__MODE__"
local ZONE = "__ZONE__"
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local SS = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit, "ServerStorage.WorldKit3D missing")
local map = workspace:FindFirstChild("Map")
assert(map, "workspace.Map missing")

-- name = old instance name (searched in Map.Decor and Map.Landmarks, direct children); new = kit model (string or { a, b } alternating);
-- H = new height / old bbox height; Min / Max clamp the scale; Solid = DecorPlayerOnly collision
local RULES = {
	halo = {
		{ name = "HaloTower", new = "Town_Halo_WallTower", H = 0.9, yaw = "keep", Solid = true },
		{ name = "HeroStatue", new = "Town_Halo_KnightStatue", H = 1.0, yaw = "face", FaceX = 0, Solid = true },
	},
	horns = {
		{ name = "HornTower", new = "Town_Horns_WallTower", H = 1.0, yaw = "keep", Solid = true },
		{ name = "Spike", new = "Town_Horns_SpikeRock", H = 0.8, yaw = "keep", Solid = true, Min = 0.6, Max = 1.6 },
	},
	ruins = {
		{ name = "BrokenArch", new = "R_Arch_A", H = 1.0, yaw = "keep", Span = true, Solid = false },
		{ name = "BrokenPillar", new = { "Kit_R_PillarA", "Kit_R_PillarB" }, H = 1.0, yaw = "random", Solid = true, Min = 0.5, Max = 2.2 },
		{ name = "Tombstone", new = "Kit_R_StoneMarker", H = 1.0, yaw = "keep", Solid = false },
		{ name = "TornPole", new = "Kit_R_Banner", H = 1.0, yaw = "keep", Solid = false },
		{ name = "TornFlag", Remove = true },
	},
	pumpkin = {
		-- every second pumpkin of the patch becomes one of our clusters; stems / leaves go only where a pumpkin was swapped
		{ name = "Pumpkin", new = "Kit_P_PumpkinCluster", H = 1.0, yaw = "random", Solid = false, Every = 2, Min = 0.4, Max = 1.6, Parent = "PumpkinPatch", Key = "pumpkin" },
		{ name = "Stem", Remove = true, Parent = "PumpkinPatch", Near = "pumpkin" },
		{ name = "Leaf", Remove = true, Parent = "PumpkinPatch", Near = "pumpkin" },
		{ name = "PumpkinPatchSign", new = "Kit_P_EntranceSign", H = 1.0, yaw = "keep", Solid = false, Lm = true },
	},
	hollow = {
		{ name = "GF_Tree", new = { "H_TreeTwisted", "H_TreeArch" }, H = 1.0, yaw = "keep", Solid = false, Parent = "HauntedHollow" },
		{ name = "GF_Willow", new = "H_Willow", H = 1.0, yaw = "keep", Solid = false, Parent = "HauntedHollow" },
		{ name = "GF_Arch", new = "H_TreeArch", H = 1.0, yaw = "keep", Span = true, Solid = false, Parent = "HauntedHollow" },
		{ name = "GF_Lantern", new = "Kit_H_LanternPost", H = 1.0, yaw = "keep", Solid = false, Parent = "HauntedHollow" },
		{ name = "GF_Mushrooms", new = "Kit_H_GlowShrooms", H = 1.0, yaw = "keep", Solid = false, Parent = "HauntedHollow" },
	},
}
-- extra props set on the ground (raycast on Terrain) inside a model's bounding box, clear of the pumpkins / earlier props
local ADDS = {
	pumpkin = {
		{ kit = "Kit_P_HayBales", n = 5, inside = "PumpkinPatch", margin = 16, apart = 40, clear = 9, sMin = 0.9, sMax = 1.2 },
		{ kit = "Kit_P_PumpkinCart", n = 2, inside = "PumpkinPatch", margin = 22, apart = 90, clear = 12, sMin = 1.0, sMax = 1.0 },
		{ kit = "Kit_P_Sunflowers", n = 9, inside = "PumpkinPatch", margin = 10, apart = 22, clear = 6, sMin = 0.9, sMax = 1.3 },
	},
}
local rules = RULES[ZONE]
assert(rules, "ZONE must be one of: halo horns ruins pumpkin hollow (got " .. tostring(ZONE) .. ")")

local decor = map:FindFirstChild("Decor")
assert(decor, "Map.Decor missing")
local old = SS:FindFirstChild("ZoneSwapOld") or Instance.new("Folder")
old.Name = "ZoneSwapOld"
old.Parent = SS
local groupOk = false
pcall(function() groupOk = PhysicsService:IsCollisionGroupRegistered("DecorPlayerOnly") end)

local function bboxOf(inst)
	if inst:IsA("Model") then return inst:GetBoundingBox() end
	return inst.CFrame, inst.Size
end
local function pathOf(inst)
	local names, p = {}, inst.Parent
	while p and p ~= workspace do
		table.insert(names, 1, p.Name)
		p = p.Parent
	end
	return table.concat(names, "/")
end
local function resolve(path)
	local node = workspace
	for seg in string.gmatch(path, "[^/]+") do node = node and node:FindFirstChild(seg) end
	return node
end

-- 0. restore this zone's stashed olds (and drop its clones)
local swapFolderName = "ZoneSwap_" .. ZONE
local oldClones = decor:FindFirstChild(swapFolderName)
if oldClones then oldClones:Destroy() end
local back = 0
for _, s in old:GetChildren() do
	if s:GetAttribute("ZoneSwapZone") == ZONE then
		local dest = resolve(s:GetAttribute("ZoneSwapFrom") or "")
		if dest then
			s.Parent = dest
			s:SetAttribute("ZoneSwapZone", nil)
			s:SetAttribute("ZoneSwapFrom", nil)
			back += 1
		end
	end
end
if MODE == "restore" then return string.format("zone_swap %s restored: %d old pieces back", ZONE, back) end

-- 1. the swap
local root = Instance.new("Model")
root.Name = swapFolderName
root:SetAttribute("PlacedBy", "zone_swap.luau")
local rng = Random.new(20261009)
local counts, missing, stashed, listing, swappedAt = {}, {}, 0, {}, {}
local function kitModel(name) return kit:FindFirstChild(name) end
local function near(list, x, z, r)
	for _, q in list do
		if (q.X - x) ^ 2 + (q.Z - z) ^ 2 <= r * r then return true end
	end
	return false
end
local function setPhysics(m, solid, shadow)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = solid
			p.CanQuery = solid
			p.CanTouch = false
			p.CastShadow = shadow
			if solid and groupOk then p.CollisionGroup = "DecorPlayerOnly" end
		end
	end
	if solid then m:SetAttribute("DecorPlayerOnly", true) end
end
local function fresh(nm)
	local m = kitModel(nm):Clone()
	m.Name = nm
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	return m
end

for ri, rule in rules do
	local targets = {}
	local function collect(folder)
		if not folder then return end
		for _, c in folder:GetChildren() do
			if c.Name == rule.name and (c:IsA("Model") or c:IsA("BasePart")) then table.insert(targets, c) end
		end
	end
	if rule.Lm then
		collect(map:FindFirstChild("Landmarks"))
	elseif rule.Parent then
		collect(decor:FindFirstChild(rule.Parent))
	else
		collect(decor)
		collect(map:FindFirstChild("Landmarks"))
	end
	local names = type(rule.new) == "table" and rule.new or { rule.new }
	if not rule.Remove and not (rule.new ~= nil and kitModel(names[1]) ~= nil) then
		missing[names[1] or rule.name] = true
		continue
	end
	for ti, inst in targets do
		local cf, size = bboxOf(inst)
		local pos = cf.Position
		local skip = (rule.Every and ti % rule.Every ~= 0) or (rule.Near and not near(swappedAt[rule.Near] or {}, pos.X, pos.Z, 3.5))
		if skip then continue end
		listing[#listing + 1] = string.format("%s(%.0f,%.0f)", rule.name, pos.X, pos.Z)
		if rule.Key then
			swappedAt[rule.Key] = swappedAt[rule.Key] or {}
			table.insert(swappedAt[rule.Key], pos)
		end
		if MODE == "plan" then continue end
		if not rule.Remove then
			local nm = names[((ti - 1) % #names) + 1]
			if not kitModel(nm) then
				missing[nm] = true
				continue
			end
			local m = fresh(nm)
			local _, ns = m:GetBoundingBox()
			local sc = math.clamp(size.Y * (rule.H or 1) / math.max(ns.Y, 0.01), rule.Min or 0.3, rule.Max or 3)
			pcall(m.ScaleTo, m, m:GetScale() * sc)
			local yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z) -- the old pivot's yaw
			if rule.yaw == "random" then
				yaw = rng:NextNumber(0, math.pi * 2)
			elseif rule.yaw == "face" then -- front (-Z) toward the axis x = FaceX
				yaw = math.atan2(-((rule.FaceX or 0) - pos.X), 0.001)
			end
			if rule.Span then -- turn 90 deg when the long horizontal sides differ (old bbox vs the new model)
				local _, ns2 = m:GetBoundingBox()
				if (size.X >= size.Z) ~= (ns2.X >= ns2.Z) then yaw += math.rad(90) end
			end
			m:PivotTo(CFrame.new(pos.X, pos.Y - size.Y / 2, pos.Z) * CFrame.Angles(0, yaw, 0))
			setPhysics(m, rule.Solid == true, size.Y >= 4)
			m:SetAttribute("ZoneSwapRule", ri)
			m.Parent = root
			counts[rule.name] = (counts[rule.name] or 0) + 1
		end
		-- stash the old one
		inst:SetAttribute("ZoneSwapFrom", pathOf(inst))
		inst:SetAttribute("ZoneSwapZone", ZONE)
		inst.Parent = old
		stashed += 1
	end
end

-- 2. extra props on the ground
local added = 0
local adds = MODE ~= "plan" and ADDS[ZONE] or nil
if adds then
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	for _, ad in adds do
		local area = decor:FindFirstChild(ad.inside)
		if not area or not kitModel(ad.kit) then
			missing[ad.kit] = true
			continue
		end
		local acf, asz = area:GetBoundingBox()
		local avoid = {}
		for _, c in area:GetChildren() do
			if c.Name == "Pumpkin" then table.insert(avoid, c.Position) end
		end
		for _, c in root:GetChildren() do table.insert(avoid, c:GetPivot().Position) end
		local mine = {}
		for _ = 1, 600 do
			if #mine >= ad.n then break end
			local x = acf.Position.X + rng:NextNumber(-asz.X / 2 + ad.margin, asz.X / 2 - ad.margin)
			local z = acf.Position.Z + rng:NextNumber(-asz.Z / 2 + ad.margin, asz.Z / 2 - ad.margin)
			if near(avoid, x, z, ad.clear) or near(mine, x, z, ad.apart) then continue end
			local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp)
			if not hit or hit.Position.Y < 0.3 or hit.Normal.Y < 0.94 then continue end
			local m = fresh(ad.kit)
			pcall(m.ScaleTo, m, m:GetScale() * rng:NextNumber(ad.sMin, ad.sMax))
			m:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			setPhysics(m, false, false)
			m:SetAttribute("ZoneSwapAdd", true)
			m.Parent = root
			table.insert(mine, Vector3.new(x, 0, z))
			table.insert(avoid, Vector3.new(x, 0, z))
			added += 1
		end
	end
end

local function keys(t)
	local out = {}
	for k in t do out[#out + 1] = k end
	table.sort(out)
	return #out > 0 and table.concat(out, ",") or "none"
end
if MODE == "plan" then
	root:Destroy()
	return string.format("zone_swap %s PLAN: %d to swap/remove: %s | missing kit: %s", ZONE, #listing, table.concat(listing, ", "), keys(missing))
end
root.Parent = decor
local c = {}
for k, v in counts do c[#c + 1] = k .. " x" .. v end
return string.format("zone_swap %s applied: %d new (%s) + %d extra props, %d old stashed in ServerStorage.ZoneSwapOld, restored-then-redone %d | missing kit: %s",
	ZONE, #root:GetChildren() - added, table.concat(c, ", "), added, stashed, back, keys(missing))
