-- crown_shrine_place.luau (이미지 생성 1, 2026-10-09; 검수 order, SPEC A23-84)
-- Studio MCP execute_luau, MAIN place, Edit mode only (메인 반영 runs it; the runner replaces "__MODE__").
-- Puts the Crown Shrine (kit model Kit_M_CrownShrine, 16 x 16 x 10.4 studs, door = front = -Z) on the King Slime Hill top
-- (meadow_terrain's store attribute HillTop) with its door toward the dirt ramp, and marks the clearing in front of the
-- door where the King Slime boss appears: a hidden Part "KingSpawn" (attribute KingSpawn = true) 7 studs in front of the
-- door. Output: workspace.Map.Decor.CrownShrine (a Model: "Shrine" + "KingSpawn"), destroyed and rebuilt on every run, so
-- running it again gives the same result.
-- The old hill crown from meadow_dress (rock crown, crystal jewels inside the footprint) would clash with the shrine:
-- pieces of Decor.MeadowDress within CLEAR.R of the hill top are moved into ServerStorage.CrownShrineBackup (MODE
-- "restore" puts them back; a later meadow_dress run builds them again, run this tool after it).
-- Collision follows tools/worldkit/decor_collision.luau: the shrine is solid for PLAYERS only (collision group
-- "DecorPlayerOnly", CanQuery false, CanTouch false, hull collider), monsters and pets ignore it; the KingSpawn marker
-- never collides. The base disc sinks 0.15 into the grass.
-- MODE: "plan" = report only (no writes), "apply" (default), "restore" = remove the shrine + put the stashed pieces back.

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end

local SS = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")

local T = {
	KitName = "Kit_M_CrownShrine",
	Back = 3, -- the shrine centre sits this far behind the hill top centre (away from the ramp): room in front of the door
	DoorR = 6.3, -- door distance from the shrine centre (stone wall radius 0.387 of the model x 16.28)
	SpawnGap = 7, -- KingSpawn in front of the door (검수: 6~8 studs)
	Sink = 0.15,
	Group = "DecorPlayerOnly",
}
local CLEAR = { R = 13 } -- old meadow_dress pieces closer than this to the hill top go to the backup

local map = workspace:FindFirstChild("Map")
local decor = map and map:FindFirstChild("Decor")
assert(decor, "workspace.Map.Decor missing")
local store = SS:FindFirstChild("MeadowTerrainStore")
local top = store and store:GetAttribute("HillTop")
local foot = store and store:GetAttribute("HillPathFoot")
assert(typeof(top) == "Vector3" and typeof(foot) == "Vector3",
	"ServerStorage.MeadowTerrainStore HillTop / HillPathFoot missing: run tools/worldkit/meadow_terrain.luau first")

local function backupFolder(create)
	local b = SS:FindFirstChild("CrownShrineBackup")
	if not b and create then
		b = Instance.new("Folder")
		b.Name = "CrownShrineBackup"
		b.Parent = SS
	end
	return b
end

local function pathOf(inst)
	local names = {}
	local p = inst.Parent
	while p and p ~= workspace do
		table.insert(names, 1, p.Name)
		p = p.Parent
	end
	return table.concat(names, "/")
end

local function pieceXZ(inst)
	if inst:IsA("Model") then return inst:GetPivot().Position end
	if inst:IsA("BasePart") then return inst.Position end
	return nil
end

if MODE == "restore" then
	local old = decor:FindFirstChild("CrownShrine")
	if old then old:Destroy() end
	local back = backupFolder(false)
	local put, lost = 0, 0
	if back then
		for _, m in back:GetChildren() do
			local dest = workspace
			for name in string.gmatch(m:GetAttribute("CrownShrineFrom") or "", "[^/]+") do
				dest = dest and dest:FindFirstChild(name)
			end
			if dest and dest ~= workspace then
				m.Parent = dest
				put += 1
			else
				lost += 1
			end
		end
		if #back:GetChildren() == 0 then back:Destroy() end
	end
	return string.format("CrownShrine removed | restored %d old hill pieces%s", put, lost > 0 and (" (" .. lost .. " have no parent any more)") or "")
end

local kitFolder = SS:FindFirstChild("WorldKit3D")
local src = kitFolder and kitFolder:FindFirstChild(T.KitName)
assert(src and src:IsA("Model"), "ServerStorage.WorldKit3D." .. T.KitName .. " missing: import E5_CrownShrine.glb, then run tools/build_kit_from_ids.py")

-- geometry: ramp direction (flat), shrine centre, door front, spawn
local dirV = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)
assert(dirV.Magnitude > 1, "HillPathFoot is on the hill top")
dirV = dirV.Unit
local cx, cz = top.X - dirV.X * T.Back, top.Z - dirV.Z * T.Back
local sx = cx + dirV.X * (T.DoorR + T.SpawnGap)
local sz = cz + dirV.Z * (T.DoorR + T.SpawnGap)

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rp)
	return hit and hit.Position.Y or nil
end
local gy = groundY(cx, cz)
assert(gy, "no terrain under the shrine centre")
local lo, hi = gy, gy
for k = 0, 11 do -- footprint ring (r 7.5): how level is the top?
	local a = k * math.pi / 6
	local y = groundY(cx + 7.5 * math.cos(a), cz + 7.5 * math.sin(a))
	if y then lo, hi = math.min(lo, y), math.max(hi, y) end
end
local sy = groundY(sx, sz)
assert(sy, "no terrain under the KingSpawn marker")

-- old hill-crown pieces inside the footprint
local clash = {}
local dress = decor:FindFirstChild("MeadowDress")
if dress then
	for _, folder in dress:GetChildren() do
		for _, piece in folder:GetChildren() do
			local p = pieceXZ(piece)
			if p and math.sqrt((p.X - top.X) ^ 2 + (p.Z - top.Z) ^ 2) < CLEAR.R then table.insert(clash, piece) end
			if piece:IsA("Model") and piece.Name:match("^Cell_") then -- small kinds sit in 64-stud cells
				for _, small in piece:GetChildren() do
					local q = pieceXZ(small)
					if q and math.sqrt((q.X - top.X) ^ 2 + (q.Z - top.Z) ^ 2) < CLEAR.R then table.insert(clash, small) end
				end
			end
		end
	end
end

local report = string.format(
	"shrine centre (%.1f, %.1f) y %.2f | footprint ground y %.2f..%.2f | front dir (%.2f, %.2f) | KingSpawn (%.1f, %.2f, %.1f) | old pieces to stash: %d",
	cx, cz, gy, lo, hi, dirV.X, dirV.Z, sx, sy + 0.1, sz, #clash)
if MODE == "plan" then return "PLAN " .. report end

-- apply
local old = decor:FindFirstChild("CrownShrine")
if old then old:Destroy() end
if #clash > 0 then
	local back = backupFolder(true)
	for _, piece in clash do
		piece:SetAttribute("CrownShrineFrom", pathOf(piece))
		piece.Parent = back
	end
end

local group = false
pcall(function() group = PhysicsService:IsCollisionGroupRegistered(T.Group) end)
if not group then
	pcall(function()
		PhysicsService:RegisterCollisionGroup(T.Group)
		for _, g in PhysicsService:GetRegisteredCollisionGroups() do
			PhysicsService:CollisionGroupSetCollidable(T.Group, g.name, g.name == "Players")
		end
		group = true
	end)
end

local root = Instance.new("Model")
root.Name = "CrownShrine"
root:SetAttribute("HillTop", top)
root:SetAttribute("FrontDir", Vector3.new(dirV.X, 0, dirV.Z))
root:SetAttribute("PlacedBy", "crown_shrine_place.luau")

local m = src:Clone()
m.Name = "Shrine"
for _, d in m:GetDescendants() do
	if d:IsA("LuaSourceContainer") then d:Destroy() end -- kit models never carry scripts
end
local base = Vector3.new(cx, gy - T.Sink, cz)
m:PivotTo(CFrame.lookAt(base, base + dirV)) -- front (-Z) faces the ramp; the kit pivot is the bottom centre
for _, p in m:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		if p:IsA("MeshPart") then pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Hull end) end
		if group then p.CollisionGroup = T.Group end
	end
end
m:SetAttribute("DecorPlayerOnly", true)
m.Parent = root

local mark = Instance.new("Part")
mark.Name = "KingSpawn"
mark.Size = Vector3.new(2, 0.2, 2)
mark.Anchored = true
mark.CanCollide = false
mark.CanQuery = false
mark.CanTouch = false
mark.Transparency = 1
mark.CFrame = CFrame.lookAt(Vector3.new(sx, sy + 0.1, sz), Vector3.new(sx + dirV.X, sy + 0.1, sz + dirV.Z))
mark:SetAttribute("KingSpawn", true)
mark.Parent = root
root.Parent = decor

local _, size = m:GetBoundingBox()
return string.format("CrownShrine built | %s | shrine size %.1f x %.1f x %.1f | collision group %s | stashed %d old pieces to ServerStorage.CrownShrineBackup",
	report, size.X, size.Y, size.Z, group and T.Group or "NOT registered (solid for everyone)", #clash)
