-- tripo_deco_fit.luau (이미지 생성 3, 10/13): put Tripo decoration kits (ServerStorage.HaloTripoKits) on the Halo v2 buildings in
-- place of the old Studio/Tripo deco pieces. For every JOBS row {building, old-piece name pattern, kit}: each matching old piece
-- (BasePart or Model) -> the kit scaled so its widest horizontal side = the old piece's widest horizontal side, same centre XZ,
-- same bottom Y, kit front (-Z) = the building front (from its skeleton centre toward the parts named front_*). Old pieces go to
-- ServerStorage.Parked_PreTripoDeco.<building> (nothing deleted). Prepend `local JOBS = {{"Shop_Bakery", "_Sign$", "HaloChunk_ShopSign"}, ...}`.
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local SS = game:GetService("ServerStorage")
local K = SS.HaloTripoKits
local PARK = SS:FindFirstChild("Parked_PreTripoDeco") or Instance.new("Folder"); PARK.Name = "Parked_PreTripoDeco"; PARK.Parent = SS
local B = workspace.HaloV2.Buildings
local out = {}

local function frontOf(b)
	local cf, _ = b:GetBoundingBox()
	local sum, n = Vector3.zero, 0
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "front_" then sum += d.Position; n += 1 end
	end
	if n == 0 then return Vector3.new(0, 0, -1) end
	local v = sum / n - cf.Position
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 0.01 and v.Unit or Vector3.new(0, 0, -1)
end
local function box(o)
	if o:IsA("BasePart") then
		local cf, s = o.CFrame, o.Size
		-- world-aligned extents of a rotated part
		local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
		local ey = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
		local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
		return cf.Position, Vector3.new(ex, ey, ez)
	end
	local cf, s = o:GetBoundingBox()
	return cf.Position, s
end

for _, j in JOBS do
	local bname, pat, kname = j[1], j[2], j[3]
	local b = B:FindFirstChild(bname)
	local kit = K:FindFirstChild(kname)
	if not b or not kit then table.insert(out, bname .. "/" .. kname .. " MISSING"); continue end
	local fdir = frontOf(b)
	local rot = CFrame.lookAt(Vector3.zero, fdir).Rotation -- kit front = -Z = LookVector -> along the building front
	local found = {}
	for _, d in b:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Model")) and string.find(d.Name, pat) and not d:GetAttribute("TripoDeco")
			and not d:FindFirstAncestorWhichIsA("Model"):GetAttribute("TripoDeco") then
			-- skip pieces inside an already matched model
			local inside = false
			for _, f in found do if d:IsDescendantOf(f) then inside = true end end
			if not inside then table.insert(found, d) end
		end
	end
	local f = b:FindFirstChild("TripoDeco") or Instance.new("Folder"); f.Name = "TripoDeco"; f.Parent = b
	local pk = PARK:FindFirstChild(bname) or Instance.new("Folder"); pk.Name = bname; pk.Parent = PARK
	for _, o in found do
		local c, s = box(o)
		local m = kit:Clone()
		local _, ks = m:GetBoundingBox()
		local w = math.max(s.X, s.Z)
		local kw = math.max(ks.X, ks.Z)
		m:ScaleTo(w / kw)
		m:PivotTo(CFrame.new(c.X, c.Y - s.Y / 2, c.Z) * rot)
		m:SetAttribute("TripoDeco", kname); m:SetAttribute("Replaced", o:GetFullName())
		m.Parent = f
		o.Parent = pk
		local _, ms = m:GetBoundingBox()
		table.insert(out, string.format("%s %s -> %s w %.2f h %.2f (old h %.2f)", bname, o.Name, kname, w, ms.Y, s.Y))
	end
	if #found == 0 then table.insert(out, bname .. " " .. pat .. " none") end
end
return table.concat(out, "\n")
