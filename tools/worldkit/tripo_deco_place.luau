-- 이미지 생성 3 10/13 (A23-154 gate 1 passed by 최종 검수): put the Tripo PBR decoration kits (ServerStorage.HaloTripoKits)
-- on the Halo v2 houses + castle in WorldKit. Old pieces are moved (absolute CFrames kept) to
-- ServerStorage.Parked_PreTripoDeco.<building> - nothing is deleted. Run with the door-type table prepended as DOORS = {...}.
--   doors   : Door_Back (opening) of every house -> DoorSingle / DoorDouble, height = opening, centred, in front of the back panel;
--             old Deco *_Leaf* / *_Knob* / *Knocker* parked
--   lamps   : every lamp group (LampCap<i>, LampPost<i>_*, LampArm<i>, ...) -> LampArm kit fitted to the group's box; LampGlass /
--             LampCore stay (Studio glass + night light, 큐 메모), the other lamp parts parked
--   domes   : old Deco <sk>_Dome on 02 / 06 / 08 / Potion -> DomeRibbed fitted to its width, bottom kept; old dome parked
--   wboxes  : every WBox<i>_<side>_* group -> WindowBoxA fitted to the group width, facing out of its wall; group parked
--   castle  : wings at the ornament slots (h 30), rose at the rose slot (D 6.9) + RoseGlass -> deep blue 34,90,180 disc
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local SS = game:GetService("ServerStorage")
local K = SS.HaloTripoKits
local PARK = SS:FindFirstChild("Parked_PreTripoDeco") or Instance.new("Folder"); PARK.Name = "Parked_PreTripoDeco"; PARK.Parent = SS
local B = workspace.HaloV2.Buildings
local cnt = {door = 0, lamp = 0, dome = 0, wbox = 0, castle = 0}

local function parkTo(b, inst)
	local f = PARK:FindFirstChild(b.Name) or Instance.new("Folder"); f.Name = b.Name; f.Parent = PARK
	inst.Parent = f
end
local function kitSize(name)
	local _, s = K[name]:GetBoundingBox(); return s
end
local function place(b, name, cf, scale, tag)
	local m = K[name]:Clone()
	m:ScaleTo(scale)
	m:PivotTo(cf)
	m:SetAttribute("TripoDeco", tag)
	local f = b:FindFirstChild("TripoDeco") or Instance.new("Folder"); f.Name = "TripoDeco"; f.Parent = b
	m.Parent = f
	return m
end
-- local-frame box of a set of parts (in the frame `fr`)
local function box(parts, fr)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local h = p.Size / 2
		for _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
			local w = p.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
			local l = fr:PointToObjectSpace(w)
			lo = Vector3.new(math.min(lo.X, l.X), math.min(lo.Y, l.Y), math.min(lo.Z, l.Z))
			hi = Vector3.new(math.max(hi.X, l.X), math.max(hi.Y, l.Y), math.max(hi.Z, l.Z))
		end end end
	end
	return lo, hi
end

for _, b in B:GetChildren() do
	local skn = b:GetAttribute("HouseSkeleton")
	local sk = skn and b:FindFirstChild(skn)
	if not sk or b:FindFirstChild("TripoDeco") then continue end
	local fr = b:GetPivot()                   -- house frame: front = -Z (LookVector)
	local deco = b:FindFirstChild((skn:gsub("_Skeleton", "_Deco")))
	-- doors
	local back = sk:FindFirstChild("Door_Back", true)
	local dk = DOORS[skn]
	if back and dk and skn ~= "HaloCastle_C2_Skeleton" then
		local lo, hi = box({back}, fr)
		local h = hi.Y - lo.Y
		local ks = kitSize(dk)
		local s = h / ks.Y
		local cx = (lo.X + hi.X) / 2
		local zf = lo.Z - ks.Z * s / 2 - 0.02    -- in front of the back panel (front = -Z)
		place(b, dk, fr * CFrame.new(cx, lo.Y, zf), s, "door")
		cnt.door += 1
		if deco then for _, c in deco:GetChildren() do if string.find(c.Name, "_Leaf") or string.find(c.Name, "_Knob") or string.find(c.Name, "Knocker") then parkTo(b, c) end end end
	end
	-- lamps
	local groups = {}
	for _, p in sk:GetDescendants() do
		if p:IsA("BasePart") then
			local i = string.match(p.Name, "^Lamp%a+(%d+)")
			if i then groups[i] = groups[i] or {}; table.insert(groups[i], p) end
		end
	end
	for i, parts in groups do
		local frame = {}
		for _, p in parts do if not string.find(p.Name, "^LampGlass") and not string.find(p.Name, "^LampCore") then table.insert(frame, p) end end
		if #frame == 0 then continue end
		local lo, hi = box(parts, fr)
		local h = hi.Y - lo.Y
		local s = h / kitSize("HaloChunk_LampArm").Y
		place(b, "HaloChunk_LampArm", fr * CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2), s, "lamp")
		for _, p in frame do parkTo(b, p) end
		cnt.lamp += 1
	end
	-- main ribbed domes
	if deco then
		for _, nm in {"HaloDomeHouse_02_Dome", "HaloDomeHouse_06_Dome", "HaloDomeHouse_08_Dome", "HaloShop_Potion_Dome"} do
			local d = deco:FindFirstChild(nm)
			if d then
				local lo, hi = box({d}, fr)
				local w = math.max(hi.X - lo.X, hi.Z - lo.Z)
				local ks = kitSize("HaloChunk_DomeRibbed")
				place(b, "HaloChunk_DomeRibbed", fr * CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2), w / math.max(ks.X, ks.Z), "dome")
				parkTo(b, d)
				cnt.dome += 1
			end
		end
	end
	-- window boxes
	local wb = {}
	for _, p in sk:GetDescendants() do
		local key = p:IsA("BasePart") and string.match(p.Name, "^(WBox%d+_%a+)_")
		if key then wb[key] = wb[key] or {}; table.insert(wb[key], p) end
	end
	for key, parts in wb do
		local side = string.match(key, "_(%a+)$")
		local lo, hi = box(parts, fr)
		local c = (lo + hi) / 2
		local dir
		if side == "front" then dir = Vector3.new(0, 0, -1) elseif side == "back" then dir = Vector3.new(0, 0, 1)
		else dir = Vector3.new(c.X >= 0 and 1 or -1, 0, 0) end
		local width = (side == "front" or side == "back") and (hi.X - lo.X) or (hi.Z - lo.Z)
		local s = width / kitSize("HaloChunk_WindowBoxA").X
		local base = Vector3.new(c.X, lo.Y, c.Z)
		place(b, "HaloChunk_WindowBoxA", fr * CFrame.lookAt(base, base + dir), s, "wbox")
		for _, p in parts do parkTo(b, p) end
		cnt.wbox += 1
	end
	-- castle wings + rose
	if skn == "HaloCastle_C2_Skeleton" then
		for _, w in {{"HaloChunk_CastleWingL", 9.8}, {"HaloChunk_CastleWingR", -9.8}} do
			local s = 30 / kitSize(w[1]).Y
			place(b, w[1], fr * CFrame.new(w[2], 24.0 - 15.0, -26.5), s, "wing")
			cnt.castle += 1
		end
		local s = 6.9 / kitSize("HaloChunk_CastleRose").Y
		place(b, "HaloChunk_CastleRose", fr * CFrame.new(0, 22.4 - 3.45, -25.95), s, "rose")
		for _, p in sk:GetDescendants() do
			if p.Name == "RoseRingOuter" or p.Name == "RoseRingInner" then parkTo(b, p) end
			if p.Name == "RoseGlass" then p.Material = Enum.Material.SmoothPlastic; p.Color = Color3.fromRGB(34, 90, 180); p.Transparency = 0 end
		end
		cnt.castle += 1
	end
end
return string.format("doors %d lamps %d domes %d wboxes %d castle %d", cnt.door, cnt.lamp, cnt.dome, cnt.wbox, cnt.castle)
