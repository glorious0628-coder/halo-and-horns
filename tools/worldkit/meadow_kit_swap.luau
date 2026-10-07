-- meadow_kit_swap.luau (검수 2026-10-07, A23-74 user: "나무 버섯 장식이 왜 저따위냐고 / 지금까지 그린 거 다 어디갔어")
-- Studio MCP execute_luau, main place, Edit mode. Swaps the SlimeMeadow primitive decor (MushCap/MushStem balls, Bush
-- balls, Flower dots, blob Tree models in Map.Decor) for the uploaded Tripo kit models in ServerStorage.WorldKit3D
-- (tools/build_kit_from_ids.py): Kit_M_Mushrooms, Kit_M_BushA/B, Kit_M_FlowersA/B, W_Tree_B / W_Tree_A. Each kit clone takes the
-- primitive's spot, a similar height and a varied yaw. The primitives move to ServerStorage.MeadowPrimitiveBackup
-- (nothing is destroyed). Idempotent: Map.Decor.MeadowKit is rebuilt from the backup spots on every run.
local SS = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit, "ServerStorage.WorldKit3D missing: run tools/build_kit_from_ids.py first")
local decor = workspace.Map.Decor

local backup = SS:FindFirstChild("MeadowPrimitiveBackup")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "MeadowPrimitiveBackup"
	backup.Parent = SS
end

local function inMeadow(pos)
	local ok, z = pcall(Config.ZoneAt, pos)
	return ok and z and z.Id == "SlimeMeadow"
end

-- move this run's primitives to the backup (first run); later runs read the spots from the backup
for _, d in decor:GetChildren() do
	local isPrim = (d:IsA("BasePart") and (d.Name == "MushCap" or d.Name == "MushStem" or d.Name == "Bush" or d.Name == "Flower"))
		or (d:IsA("Model") and d.Name == "Tree")
	if isPrim then
		local pos = d:IsA("Model") and d:GetPivot().Position or d.Position
		if inMeadow(pos) then d.Parent = backup end
	end
end

local old = decor:FindFirstChild("MeadowKit")
if old then old:Destroy() end
local root = Instance.new("Model")
root.Name = "MeadowKit"

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain, workspace.Map:FindFirstChild("Ground") }

local function groundY(x, z, fallback)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or fallback
end

local made, missing = {}, {}
local function place(name, x, z, height, yaw, solid, y0)
	local src = kit:FindFirstChild(name)
	if not src then
		missing[name] = true
		return
	end
	local m = src:Clone()
	local _, size = m:GetBoundingBox()
	if size.Y > 0 then pcall(m.ScaleTo, m, m:GetScale() * (height / size.Y)) end
	local y = groundY(x, z, y0)
	m:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0))
	local cf, bs = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, y - (cf.Position.Y - bs.Y / 2) - 0.05, 0)) -- bottom on the ground
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = solid
			p.CanQuery = solid
			p.CastShadow = true
		end
	end
	m.Parent = root
	made[name] = (made[name] or 0) + 1
end

local n = 0
for _, d in backup:GetChildren() do
	n += 1
	local yaw = (n * 137) % 360
	if d.Name == "MushCap" then
		place("Kit_M_Mushrooms", d.Position.X, d.Position.Z, 3.6, yaw, false, d.Position.Y - 1.7)
	elseif d.Name == "Bush" then
		place(n % 2 == 0 and "Kit_M_BushA" or "Kit_M_BushB", d.Position.X, d.Position.Z,
			math.clamp(d.Size.Y * 1.1, 3, 6), yaw, false, d.Position.Y - d.Size.Y / 2)
	elseif d.Name == "Flower" then
		place(n % 2 == 0 and "Kit_M_FlowersA" or "Kit_M_FlowersB", d.Position.X, d.Position.Z, 1.8, yaw, false,
			d.Position.Y - d.Size.Y / 2)
	elseif d:IsA("Model") and d.Name == "Tree" then
		local cf, bs = d:GetBoundingBox()
		-- meadow trees: the round leafy W_Tree_B, every third one the pine W_Tree_A (X_TreeA has a plaza planter: 검수 photo)
		place(n % 3 == 0 and "W_Tree_A" or "W_Tree_B", cf.Position.X, cf.Position.Z, math.clamp(bs.Y * 1.15, 11, 24), yaw, true,
			cf.Position.Y - bs.Y / 2)
	end
end
root.Parent = decor

local out = { "MeadowKit placed:" }
for k, v in made do table.insert(out, k .. " x" .. v) end
for k in missing do table.insert(out, "MISSING " .. k) end
table.insert(out, "backup primitives: " .. #backup:GetChildren())
return table.concat(out, " | ")
