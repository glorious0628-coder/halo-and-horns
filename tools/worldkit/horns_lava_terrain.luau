-- horns_lava_terrain.luau (게임성 개발 1, 2026-10-08; 검수 queue + image gen 1 docs/design/towns_primitive_props_2026-10-08.md #1)
-- Studio MCP execute_luau, main place, Edit mode. The Horns town's old neon lava strips (Map.Decor LavaChannel x2 +
-- ChannelRimL / ChannelRimR, 130 long at x = +-48) and the LavaCrack plates (x4, 11 x 2) become terrain CrackedLava
-- painted into the ground under them (0 points: no new art). Every solid voxel of the footprint (+ Pad) from Depth
-- below to Above over the ground turns CrackedLava; the occupancy stays, so the ground keeps its shape. The parts move
-- to ServerStorage.MapV1Backup.HornsLava (nothing is destroyed; OrigParent attribute). Idempotent: a second run finds
-- no parts. The story spot Config.StoryQuests.Landmarks.LavaCrack (48, 0, 410, "Warm up at the lava") stays on the
-- painted x = 48 strip. MODE = "survey" only reports what is under each part (terrain material / a floor part).
local MODE = "apply"
local SS = game:GetService("ServerStorage")
local terrain = workspace.Terrain
local map = workspace:FindFirstChild("Map")
local decor = map and map:FindFirstChild("Decor")
assert(decor, "workspace.Map.Decor missing")

local T = {
	Box = { MinX = -200, MaxX = 200, MinZ = 300, MaxZ = 700 }, -- Horns Den (map v2: town centre (0, 515), 400 x 370)
	Names = { LavaChannel = true, ChannelRimL = true, ChannelRimR = true, LavaCrack = true },
	Paint = { LavaChannel = true, LavaCrack = true }, -- the rims go with their channel (the terrain edge reads as the rim)
	Pad = 0.5, -- studs around a footprint
	Depth = 6, Above = 3, -- studs below / above the ground that are painted
	Res = 4,
}

local function inBox(p)
	return p.X >= T.Box.MinX and p.X <= T.Box.MaxX and p.Z >= T.Box.MinZ and p.Z <= T.Box.MaxZ
end

local parts = {}
for _, d in decor:GetDescendants() do
	if d:IsA("BasePart") and T.Names[d.Name] and inBox(d.Position) then table.insert(parts, d) end
end
table.sort(parts, function(a, b)
	if a.Name ~= b.Name then return a.Name < b.Name end
	return a.Position.Z < b.Position.Z
end)

local onlyTerrain = RaycastParams.new()
onlyTerrain.FilterType = Enum.RaycastFilterType.Include
onlyTerrain.FilterDescendantsInstances = { terrain }
local notLava = RaycastParams.new()
notLava.FilterType = Enum.RaycastFilterType.Exclude
notLava.FilterDescendantsInstances = parts

local log = {}
local function note(s) table.insert(log, s) end

-- the axis-aligned footprint of a part (any yaw) on the XZ plane
local function footprint(p)
	local cf, s = p.CFrame, p.Size
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, sx in { -0.5, 0.5 } do
		for _, sz in { -0.5, 0.5 } do
			local w = cf:PointToWorldSpace(Vector3.new(s.X * sx, 0, s.Z * sz))
			minX, maxX = math.min(minX, w.X), math.max(maxX, w.X)
			minZ, maxZ = math.min(minZ, w.Z), math.max(maxZ, w.Z)
		end
	end
	return minX - T.Pad, maxX + T.Pad, minZ - T.Pad, maxZ + T.Pad
end

local painted, materials = 0, {}
for _, p in parts do
	local pos = p.Position
	local below = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), notLava)
	local ground = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), onlyTerrain)
	local under = below and (below.Instance == terrain and ("Terrain " .. below.Material.Name) or below.Instance:GetFullName()) or "nothing"
	note(string.format("%s (%.0f, %.1f, %.0f) %.1fx%.1f -> under: %s, terrain at %s", p.Name, pos.X, pos.Y, pos.Z, p.Size.X, p.Size.Z,
		under, ground and string.format("%.1f", ground.Position.Y) or "none"))
	if MODE == "apply" and T.Paint[p.Name] and ground then
		local minX, maxX, minZ, maxZ = footprint(p)
		local gy = ground.Position.Y
		local region = Region3.new(Vector3.new(minX, gy - T.Depth, minZ), Vector3.new(maxX, gy + T.Above, maxZ)):ExpandToGrid(T.Res)
		local mats, occ = terrain:ReadVoxels(region, T.Res)
		local size = mats.Size
		for x = 1, size.X do
			for y = 1, size.Y do
				for z = 1, size.Z do
					local m = mats[x][y][z]
					if occ[x][y][z] > 0 and m ~= Enum.Material.Air and m ~= Enum.Material.Water and m ~= Enum.Material.CrackedLava then
						materials[m.Name] = (materials[m.Name] or 0) + 1
						mats[x][y][z] = Enum.Material.CrackedLava
						painted += 1
					end
				end
			end
		end
		terrain:WriteVoxels(region, T.Res, mats, occ)
	end
end

if MODE == "apply" and #parts > 0 then
	local backup = SS:FindFirstChild("MapV1Backup") or Instance.new("Folder")
	backup.Name = "MapV1Backup"
	backup.Parent = SS
	local store = backup:FindFirstChild("HornsLava") or Instance.new("Folder")
	store.Name = "HornsLava"
	store.Parent = backup
	for _, p in parts do
		p:SetAttribute("OrigParent", p.Parent:GetFullName())
		p.Parent = store
	end
end

local mlist = {}
for name, n in materials do table.insert(mlist, name .. " " .. n) end
table.sort(mlist)
note(string.format("%s: %d parts, %d voxels painted CrackedLava (was: %s)", MODE, #parts, painted,
	#mlist > 0 and table.concat(mlist, ", ") or "-"))
return table.concat(log, "\n")
