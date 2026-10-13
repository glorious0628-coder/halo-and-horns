-- tripo_ivy_fit.luau (이미지 생성 3, 10/13): ivy kits on the Halo v2 houses, placed from the house front 2D (art/out/s2/halo/houses):
--   IvyWall    : climbs the viewer-left corner of the front facade (09 ref crop x 0.18-0.39, full height) - height 0.7 of the facade
--   IvyBalcony : hangs at both ends of the front balcony rail (06/08/10/12 2D: vines draped over the rail ends) - width 0.3 of the rail
-- Kit front = building front, back flat to the wall (pbr_final 묶음 b: Ivy DoubleSided, back = wall). Re-run safe (Slot attribute).
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local WALL = { "House_Cliff5", "Shop_Bakery", "Shop_Juice", "Shop_Potion" }
local BALC = { "House_Cliff3", "House_Cliff2", "House_Cliff1", "House_Garden1" }
local K = game:GetService("ServerStorage").HaloTripoKits
local B = workspace.HaloV2.Buildings
local out = {}
local function frame(b)
	local cf = b:GetBoundingBox()
	local sum, n, fr = Vector3.zero, 0, {}
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "front_" then sum += d.Position; n += 1; table.insert(fr, d) end
	end
	local v = n > 0 and (sum / n - cf.Position) or Vector3.new(0, 0, -1)
	local f = Vector3.new(v.X, 0, v.Z).Unit
	local right = (-f):Cross(Vector3.yAxis) -- viewer's right when facing the front
	return f, right, fr, cf.Position
end
local function slotDone(b, tag)
	local fd = b:FindFirstChild("TripoDeco")
	if not fd then return false end
	for _, m in fd:GetChildren() do if m:GetAttribute("Slot") == tag then return true end end
	return false
end
local function put(b, kname, pos, f, scale, tag)
	local m = K[kname]:Clone()
	m:ScaleTo(scale)
	m:PivotTo(CFrame.new(pos) * CFrame.lookAt(Vector3.zero, f).Rotation)
	m:SetAttribute("TripoDeco", kname); m:SetAttribute("Slot", tag)
	local fd = b:FindFirstChild("TripoDeco") or Instance.new("Folder"); fd.Name = "TripoDeco"; fd.Parent = b
	m.Parent = fd
	return m
end
local _, ivs = K.HaloChunk_IvyWall:GetBoundingBox()
local _, ibs = K.HaloChunk_IvyBalcony:GetBoundingBox()
for _, bn in WALL do
	local b = B:FindFirstChild(bn)
	if not b or slotDone(b, "IvyWall") then continue end
	local f, right, fr = frame(b)
	local lo, hi, fmax, ymin, ymax = math.huge, -math.huge, -math.huge, math.huge, -math.huge
	for _, p in fr do
		local r = p.Position:Dot(right)
		lo, hi = math.min(lo, r - p.Size.X / 2), math.max(hi, r + p.Size.X / 2)
		fmax = math.max(fmax, p.Position:Dot(f))
	end
	-- facade height = the skeleton walls (whole building box minus roof): use the building box bottom + front parts top
	local bcf, bs = b:GetBoundingBox()
	ymin = bcf.Position.Y - bs.Y / 2
	for _, p in fr do ymax = math.max(ymax, p.Position.Y + p.Size.Y / 2) end
	local h = (ymax - ymin) * 0.95
	local scale = h / ivs.Y
	local w = ivs.X * scale
	local r = lo - (hi - lo) * 0.08 + w / 2 -- just at the left edge of the window band (corner of the wall)
	local pos = right * r + f * (fmax + 0.15) + Vector3.new(0, ymin, 0)
	pos = Vector3.new(pos.X, ymin, pos.Z)
	local m = put(b, "HaloChunk_IvyWall", pos, f, scale, "IvyWall")
	table.insert(out, string.format("%s IvyWall h %.1f w %.1f", bn, h, w))
end
for _, bn in BALC do
	local b = B:FindFirstChild(bn)
	if not b then continue end
	local f, right = frame(b)
	-- the front balcony top rail(s): RailCap / RailBase parts whose name has 'front'
	local rails = {}
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "front") and (string.find(d.Name, "RailCap") or d.Name == "RailBase_front") then table.insert(rails, d) end
	end
	if #rails == 0 then table.insert(out, bn .. " no front rail"); continue end
	local lo, hi, top, fmax = math.huge, -math.huge, -math.huge, -math.huge
	for _, p in rails do
		local len = math.max(p.Size.X, p.Size.Z)
		local r = p.Position:Dot(right)
		lo, hi = math.min(lo, r - len / 2), math.max(hi, r + len / 2)
		top = math.max(top, p.Position.Y + p.Size.Y / 2)
		fmax = math.max(fmax, p.Position:Dot(f) + math.min(p.Size.X, p.Size.Z) / 2)
	end
	local w = (hi - lo) * 0.3
	local scale = w / ibs.X
	local hgt = ibs.Y * scale
	for side, r in { L = lo + w / 2, R = hi - w / 2 } do
		local tag = "IvyBalc" .. side
		if not slotDone(b, tag) then
			local p = right * r + f * (fmax + 0.1)
			put(b, "HaloChunk_IvyBalcony", Vector3.new(p.X, top - hgt * 0.85, p.Z), f, scale, tag)
			table.insert(out, string.format("%s IvyBalcony %s w %.1f h %.1f", bn, side, w, hgt))
		end
	end
end
return table.concat(out, "\n")
