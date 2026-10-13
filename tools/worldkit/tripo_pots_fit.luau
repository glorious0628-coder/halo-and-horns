-- tripo_pots_fit.luau (이미지 생성 3, 10/13): the planter pots beside the house doors (skeleton Pot<i> + Pot<i>_Soil / _Rim / _Gold*):
--   CONE houses : HaloChunk_ConeTree stands on each Pot<i>_Soil (width 0.6 of the soil, front = building front), pot kept
--   BUSH houses : the whole Pot<i> group -> HaloChunk_FlowerBushPot (pot + bush in one Tripo model; width = pot width, back to the wall)
-- Old pot parts (BUSH only) go to ServerStorage.Parked_PreTripoDeco.<building>. Re-run safe (skips pots that already got a kit).
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local CONE = { "House_Cliff4", "House_Cliff3", "House_Cliff2", "House_Cliff1", "House_Hill2", "House_Garden1", "Shop_Bakery", "Shop_Flower", "Shop_Juice", "Shop_Potion" }
local BUSH = { "House_Hill3", "House_Garden2" }
local SS = game:GetService("ServerStorage")
local K = SS.HaloTripoKits
local PARK = SS:FindFirstChild("Parked_PreTripoDeco") or Instance.new("Folder"); PARK.Name = "Parked_PreTripoDeco"; PARK.Parent = SS
local B = workspace.HaloV2.Buildings
local out = {}
local function frontOf(b)
	local cf = b:GetBoundingBox()
	local sum, n = Vector3.zero, 0
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "front_" then sum += d.Position; n += 1 end
	end
	local v = n > 0 and (sum / n - cf.Position) or Vector3.new(0, 0, -1)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 0.01 and v.Unit or Vector3.new(0, 0, -1)
end
local function pots(b)
	local list = {}
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") then
			local i = string.match(d.Name, "^Pot(%d+)$")
			if i then list[i] = list[i] or {}; list[i].pot = d end
			local j = string.match(d.Name, "^Pot(%d+)_")
			if j then list[j] = list[j] or {}; list[j].parts = list[j].parts or {}; table.insert(list[j].parts, d)
				if string.match(d.Name, "_Soil$") then list[j].soil = d end end
		end
	end
	return list
end
local function place(b, kname, cf, scale, tag)
	local m = K[kname]:Clone()
	m:ScaleTo(scale)
	m:PivotTo(cf)
	m:SetAttribute("TripoDeco", kname); m:SetAttribute("Slot", tag)
	local f = b:FindFirstChild("TripoDeco") or Instance.new("Folder"); f.Name = "TripoDeco"; f.Parent = b
	m.Parent = f
	return m
end
local function done(b, tag)
	local f = b:FindFirstChild("TripoDeco")
	if not f then return false end
	for _, m in f:GetChildren() do if m:GetAttribute("Slot") == tag then return true end end
	return false
end
local _, coneSize = K.HaloChunk_ConeTree:GetBoundingBox()
local _, bushSize = K.HaloChunk_FlowerBushPot:GetBoundingBox()
for _, bn in CONE do
	local b = B:FindFirstChild(bn)
	if not b then table.insert(out, bn .. " MISSING"); continue end
	local rot = CFrame.lookAt(Vector3.zero, frontOf(b)).Rotation
	for i, p in pots(b) do
		local tag = "ConePot" .. i
		if p.soil and not done(b, tag) then
			local s = p.soil
			-- world-aligned box (soil discs are Cylinder parts lying on their side: Size.X is the thickness)
			local c = s.CFrame
			local ex = math.abs(c.RightVector.X) * s.Size.X + math.abs(c.UpVector.X) * s.Size.Y + math.abs(c.LookVector.X) * s.Size.Z
			local ey = math.abs(c.RightVector.Y) * s.Size.X + math.abs(c.UpVector.Y) * s.Size.Y + math.abs(c.LookVector.Y) * s.Size.Z
			local ez = math.abs(c.RightVector.Z) * s.Size.X + math.abs(c.UpVector.Z) * s.Size.Y + math.abs(c.LookVector.Z) * s.Size.Z
			local w = math.min(ex, ez)
			local top = s.Position.Y + ey / 2
			local m = place(b, "HaloChunk_ConeTree", CFrame.new(s.Position.X, top - 0.05, s.Position.Z) * rot, w * 0.6 / math.max(coneSize.X, coneSize.Z), tag)
			local _, ms = m:GetBoundingBox()
			table.insert(out, string.format("%s cone on Pot%s w %.2f h %.2f", bn, i, w * 0.6, ms.Y))
		end
	end
end
for _, bn in BUSH do
	local b = B:FindFirstChild(bn)
	if not b then table.insert(out, bn .. " MISSING"); continue end
	local rot = CFrame.lookAt(Vector3.zero, frontOf(b)).Rotation
	local pk = PARK:FindFirstChild(bn) or Instance.new("Folder"); pk.Name = bn; pk.Parent = PARK
	for i, p in pots(b) do
		local tag = "BushPot" .. i
		if p.pot and not done(b, tag) then
			local pt = p.pot
			local w = math.max(pt.Size.X, pt.Size.Z)
			local bottom = pt.Position.Y - pt.Size.Y / 2
			local m = place(b, "HaloChunk_FlowerBushPot", CFrame.new(pt.Position.X, bottom, pt.Position.Z) * rot, w / math.max(bushSize.X, bushSize.Z), tag)
			pt.Parent = pk
			for _, q in p.parts or {} do q.Parent = pk end
			local _, ms = m:GetBoundingBox()
			table.insert(out, string.format("%s bushpot for Pot%s w %.2f h %.2f (old pot h %.2f)", bn, i, w, ms.Y, pt.Size.Y))
		end
	end
end
return table.concat(out, "\n")
