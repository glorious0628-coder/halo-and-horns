-- pass_rocks_place.luau (게임성 개발 1, 2026-10-08; 검수 audit photo 'Pass': "회색 자갈 원뿔 → 둥근 바위 3D로 덮기")
-- Studio MCP execute_luau, main place, Edit mode, map v2. Covers the round terrain cones of the pass band (between the
-- Goblin Woods and the Skeleton Ruins, x around Config.Map.PassX) with the uploaded Tripo boulders W_Boulder_A / B
-- (ServerStorage.WorldKit3D): spots sampled on the mountain (terrain at least MinH above the floor), a seeded shuffle,
-- MinGap between boulders, each tilted to the slope and sunk Sink of its height, bigger near the tops. The flat
-- corridor (|z| < PassHalfZ + Corridor) and the land outside the band stay clear. Idempotent: an older
-- Map.Decor.PassRocks moves to ServerStorage.MapV1Backup.PassRocks first (nothing is destroyed).
local SS = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit and kit:FindFirstChild("W_Boulder_A") and kit:FindFirstChild("W_Boulder_B"), "WorldKit3D boulders missing")
local decor = workspace.Map.Decor

local PASS_X = tonumber(Config.Map.PassX) or 1225
local HALF_Z = tonumber(Config.Map.PassHalfZ) or 70
local T = {
	Seed = 20261008, Step = 10, MinX = PASS_X - 150, MaxX = PASS_X + 150, MaxZ = 300,
	Corridor = 14, MinH = 7, MinGap = 15, Max = 70, Sink = 0.35,
	Size = { 12, 30 }, -- boulder height in studs, low slopes -> the tops
}

local backup = SS:FindFirstChild("MapV1Backup") or Instance.new("Folder")
backup.Name = "MapV1Backup"
backup.Parent = SS
local old = decor:FindFirstChild("PassRocks")
if old then
	local sub = backup:FindFirstChild("PassRocks") or Instance.new("Folder")
	sub.Name = "PassRocks"
	sub.Parent = backup
	old.Parent = sub
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }

-- the mountain spots: terrain well above the floor, outside the corridor
local spots, top = {}, 0
for x = T.MinX, T.MaxX, T.Step do
	for z = -T.MaxZ, T.MaxZ, T.Step do
		if math.abs(z) > HALF_Z + T.Corridor then
			local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), params)
			if hit and hit.Position.Y >= T.MinH and hit.Material ~= Enum.Material.Water then
				table.insert(spots, { Pos = hit.Position, Normal = hit.Normal })
				top = math.max(top, hit.Position.Y)
			end
		end
	end
end
local rng = Random.new(T.Seed)
for i = #spots, 2, -1 do
	local j = rng:NextInteger(1, i)
	spots[i], spots[j] = spots[j], spots[i]
end

local group = Instance.new("Model")
group.Name = "PassRocks"
local placed = {}
for _, s in spots do
	if #placed >= T.Max then break end
	local far = true
	for _, q in placed do
		if (q - s.Pos).Magnitude < T.MinGap then
			far = false
			break
		end
	end
	if far then
		local src = kit:FindFirstChild(rng:NextNumber() < 0.5 and "W_Boulder_A" or "W_Boulder_B")
		local m = src:Clone()
		local share = top > 0 and math.clamp(s.Pos.Y / top, 0, 1) or 0
		local want = T.Size[1] + (T.Size[2] - T.Size[1]) * (0.35 + 0.65 * share) * rng:NextNumber(0.75, 1.1)
		local _, size = m:GetBoundingBox()
		if size.Y > 0 then pcall(m.ScaleTo, m, m:GetScale() * (want / size.Y)) end
		-- up = halfway between the world up and the slope normal; a random turn round it
		local up = (Vector3.yAxis + s.Normal).Unit
		local look = up:Cross(Vector3.xAxis)
		if look.Magnitude < 0.1 then look = up:Cross(Vector3.zAxis) end
		local base = CFrame.lookAt(s.Pos, s.Pos + look.Unit, up) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		m:PivotTo(base - up * (want * T.Sink))
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = true
				p.CastShadow = true
			end
		end
		m.Parent = group
		table.insert(placed, s.Pos)
	end
end
group.Parent = decor
return string.format("PassRocks: %d boulders on %d mountain spots (tops up to %.0f)", #placed, #spots, top)
