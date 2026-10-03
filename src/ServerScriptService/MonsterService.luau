-- MonsterService.luau : monster rigs (procedural or custom visual), spawn/respawn with zone density and spawn spread,
-- AI loop, monster HP, kill rewards (MonsterKilled) and personal (tutorial) monsters.
-- World is Terrain (A10/A11): spawn/wander points are raycast onto walkable ground; monsters stay inside their own zone
-- rect, never chase into water and are recovered home when knocked out / sunk (A10-V3-2); stuck detection (A11-R5).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local MonsterService = {}

-- fired once PER CONTRIBUTOR: (player, info)
MonsterService.MonsterKilled = Util.Signal.new()

------------------------------------------------------------------ constants
local TAG = "MonsterService"
local MC = Config.Monsters

-- A3-M2 / A5-C1 density (fallbacks keep the service working if a Config key is missing)
local DENSITY = Config.MonsterDensity or {}
local EXTRA_PER_PLAYER = DENSITY.ExtraPerPlayer or 2
local MAX_ZONE_MULT = DENSITY.MaxZoneMult or 2
local REEVAL_INTERVAL = DENSITY.ReevalInterval or 5
local MAX_SPAWNS_PER_KIND_PER_PASS = 8 -- smooths bursts when many players enter a zone at once

-- A7-1 spawn spread
local SPREAD = Config.SpawnSpread or {}
local SPREAD_ENABLED = SPREAD.Enabled ~= false
local SPREAD_THRESHOLD = SPREAD.StarvedThreshold or 2
local SPREAD_MIN = SPREAD.MinDist or 18
local SPREAD_MAX = SPREAD.MaxDist or 28
local SPREAD_TRIES = SPREAD.Tries or 6
local SPREAD_COUNT_RADIUS = 30

-- shared Config keys (G1) with fallbacks
local TUTORIAL = Config.Tutorial or {}
local CUSTOM = Config.CustomModels or {}
local CUSTOM_FOLDER = CUSTOM.FolderName or "CustomModels"
local GOLDEN_FILL_TRANSPARENCY = CUSTOM.GoldenFillTransparency or 0.5
local MIN_TEXT_SIZE = (Config.UI and Config.UI.MinTextSize) or 11
local NO_REAGGRO_SECONDS = MC.ReaggroDelay or 3 -- A3-M4
local PERSONAL_DISTANCE = TUTORIAL.SpawnDistance or 8 -- A4: ~8 studs in front of the player
local PERSONAL_LIFETIME = TUTORIAL.Lifetime or 120 -- A4: despawn after 120 s

-- AI tuning that is not in Config (private)
local RETURN_DONE_DIST = 6
local WANDER_RADIUS = 15
local WANDER_MIN, WANDER_MAX = 4, 8
local WANDER_TRIES = 4
local PERSONAL_FOLLOW_RADIUS = 80 -- A5-C3: a personal monster only tracks its owner when the owner is this close
local ZONE_MOVE_INSET = 6 -- A10-V3-2 (b): every MoveTo destination stays this far inside the monster's zone rect
local OUT_Y = -3 -- A10-V3-2 (c): root below this (water) -> walk home, no re-aggro
local DEEP_Y = -8 -- A10-V3-2 (c): root below this for more than DEEP_SECONDS -> PivotTo(Home)
local DEEP_SECONDS = 2
local MAX_SLOPE_ANGLE = 46 -- A11-R2: Terrain ridges (>= 50 deg) cannot be walked over
local STUCK_WINDOW = 1.5 -- A11-R5: moved < STUCK_MIN_MOVE in this many seconds while moving -> new destination
local STUCK_MIN_MOVE = 1
local ARRIVE_DIST = 3 -- "still trying to move" while the destination is farther than this
local DETOUR_MIN, DETOUR_MAX = 8, 14
local DETOUR_SECONDS = 2
local DETOUR_TRIES = 4
local CHASE_STUCK_GIVEUP = 2 -- stuck this many times on one target -> give up and go home

-- ground probing (A11-R1: Include only Terrain, Map.Ground and the Map.Decor "Bridge_*" models)
local GROUND_RAY_TOP = 150 -- above every ridge top
local GROUND_RAY_LENGTH = 320
local GROUND_MIN_Y, GROUND_MAX_Y = -2, 6 -- walkable valley floor (zone ground top is Y = 0); higher = ridge, lower = shore
local GROUND_PARAMS_REFRESH = 10
local SPAWN_TRIES = 8

-- visuals
local BAR_MAX_DISTANCE = 80
local DEATH_FADE = 0.3
local DEATH_DESTROY = 0.4
local DEATH_PARTICLES = 15
local BOB_PERIOD = 0.55
local BOB_FRACTION = 0.06 -- custom visual bob height as a fraction of the body height
-- every visible part is welded to VisualRoot, which hangs off the root by the Weld VisualJoint (C0 = C1 = identity).
-- Clients tween VisualJoint.C0 locally (Fx.luau attack lunge / hit recoil); the server never writes C0 after spawn.
local VISUAL_ROOT_NAME = "VisualRoot"
local VISUAL_JOINT_NAME = "VisualJoint"
local VISUAL_ROOT_SIZE = 0.2
local ATTACK_SEQ_ATTR = "AttackSeq" -- +1 on every monster hit on a player (clients play the attack lunge)
local FACE_TARGET_DOT = 0.85 -- attacking: turn to the target when it is more than ~30 deg off the look direction
local BAR_HIGH = Color3.fromRGB(80, 220, 120)
local BAR_LOW = Color3.fromRGB(255, 80, 80)
local EYE_COLOR = Color3.fromRGB(20, 20, 20)

local DISABLED_STATES = { -- A3-H2
	Enum.HumanoidStateType.Dead,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.PlatformStanding,
}

------------------------------------------------------------------ state
local S = nil
local records = {} -- [Id] = MonsterRecord (alive only)
local nextId = 0
local pending = {} -- [Kind] = respawns scheduled but not yet executed
local personal = {} -- [Player] = { [MonsterRecord] = true }
local monstersFolder = nil
local lastWarn = {} -- [key] = os.clock()
local groundParams, groundParamsAt = nil, -math.huge

local GLOBAL_CAP
do
	if type(DENSITY.GlobalCap) == "number" then
		GLOBAL_CAP = DENSITY.GlobalCap
	else
		local sum = 0
		for _, kind in Config.MonsterTypeOrder do
			local def = Config.MonsterTypes[kind]
			if def then sum += def.Count end
		end
		GLOBAL_CAP = math.floor(sum * 1.7 + 0.5)
	end
end

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarn[key]
	if last and now - last < 10 then return end
	lastWarn[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function getMonstersFolder()
	if monstersFolder and monstersFolder.Parent then return monstersFolder end
	monstersFolder = Util.GetFolder(workspace, "Monsters")
	return monstersFolder
end

local function readyPlayers()
	if not S or not S.PlayerService then return {} end
	local ok, list = pcall(S.PlayerService.GetReadyPlayers)
	if ok and type(list) == "table" then return list end
	return {}
end

local function isPlayerInTown(player, pos)
	if Config.ZoneAt(pos).Town == true then return true end
	if S and S.ZoneService then
		local ok, town = pcall(S.ZoneService.IsTown, player)
		if ok and town == true then return true end
	end
	return false
end

local function visibleTo(rec, forPlayer)
	return forPlayer == nil or rec.Owner == nil or rec.Owner == forPlayer
end

local function insideZone(zone, p, inset)
	return math.abs(p.X - zone.Center.X) <= zone.Size.X / 2 - inset
		and math.abs(p.Z - zone.Center.Z) <= zone.Size.Z / 2 - inset
end

-- A10-V3-2 (b): clamp a destination into the zone rect inset by ZONE_MOVE_INSET (keeps Y)
local function clampToZone(zone, p)
	if not zone then return p end
	local hx = math.max(0, zone.Size.X / 2 - ZONE_MOVE_INSET)
	local hz = math.max(0, zone.Size.Z / 2 - ZONE_MOVE_INSET)
	return Vector3.new(
		math.clamp(p.X, zone.Center.X - hx, zone.Center.X + hx),
		p.Y,
		math.clamp(p.Z, zone.Center.Z - hz, zone.Center.Z + hz)
	)
end

-- A11-R1: ground raycasts only see Terrain, workspace.Map.Ground and the bridge models (rebuilt every few seconds
-- so a late MapBuilder pass is picked up). Water is NOT ignored, so a hit on the sea/river reports Material Water.
local function getGroundParams()
	local now = os.clock()
	if groundParams and now - groundParamsAt < GROUND_PARAMS_REFRESH then return groundParams end
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		local ground = map:FindFirstChild("Ground")
		if ground then table.insert(list, ground) end
		local decor = map:FindFirstChild("Decor")
		if decor then
			for _, c in decor:GetChildren() do
				if string.sub(c.Name, 1, 7) == "Bridge_" then table.insert(list, c) end
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	params.IgnoreWater = false
	groundParams, groundParamsAt = params, now
	return params
end

-- ground under (x, z): returns (groundY, isWater), or nil when nothing was hit
local function probeGround(x, z)
	local hit = workspace:Raycast(Vector3.new(x, GROUND_RAY_TOP, z), Vector3.new(0, -GROUND_RAY_LENGTH, 0), getGroundParams())
	if not hit then return nil, false end
	return hit.Position.Y, hit.Material == Enum.Material.Water
end

-- walkable ground point at (x, z) or nil (water, ridge, shore). Second result: true when the ray hit nothing at all
-- (bare test place without Terrain / Map.Ground), so callers can fall back to the legacy flat Y = 0 behaviour.
local function groundPoint(x, z)
	local y, water = probeGround(x, z)
	if y == nil then return nil, true end
	if water or y < GROUND_MIN_Y or y > GROUND_MAX_Y then return nil, false end
	return Vector3.new(x, y, z), false
end

-- unanchored monster part
local function newPart(props)
	local p = Instance.new(props.ClassName or "Part")
	if props.Shape then p.Shape = props.Shape end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" and k ~= "Shape" then
			p[k] = v
		end
	end
	return p
end

local function getCustomTemplate(id)
	local folder = ServerStorage:FindFirstChild(CUSTOM_FOLDER)
	if not folder then return nil end
	local t = folder:FindFirstChild(id)
	if t and (t:IsA("Model") or t:IsA("BasePart")) then return t end
	return nil
end

------------------------------------------------------------------ counting (non-personal)
local function aliveCountOf(kind)
	local n = 0
	for _, rec in records do
		if rec.Alive and rec.Owner == nil and rec.Kind == kind then n += 1 end
	end
	return n
end

local function totalNonPersonal()
	local n = 0
	for _, rec in records do
		if rec.Alive and rec.Owner == nil then n += 1 end
	end
	for _, c in pending do n += c end
	return n
end

local function playersPerZone()
	local counts = {}
	for _, p in readyPlayers() do
		local root = Util.GetRoot(p)
		if root then
			local id = Config.ZoneAt(root.Position).Id
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end

local function targetCount(kind, zoneCounts)
	local def = Config.MonsterTypes[kind]
	if not def then return 0 end
	local n = (zoneCounts or playersPerZone())[def.Zone] or 0
	return math.min(def.Count + EXTRA_PER_PLAYER * math.max(0, n - 1), def.Count * MAX_ZONE_MULT)
end

------------------------------------------------------------------ public queries
function MonsterService.GetMonstersInRadius(position, radius, forPlayer)
	local out = {}
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return out end
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer) then
			local root = rec.Root
			if root and root.Parent and Util.FlatDistance(root.Position, position) <= radius then
				table.insert(out, rec)
			end
		end
	end
	return out
end

function MonsterService.GetNearest(position, radius, maxCount, forPlayer)
	local out = {}
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return out end
	local found = {}
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer) then
			local root = rec.Root
			if root and root.Parent then
				local d = Util.FlatDistance(root.Position, position)
				if d <= radius then
					table.insert(found, { Rec = rec, D = d })
				end
			end
		end
	end
	table.sort(found, function(a, b) return a.D < b.D end)
	local limit = (type(maxCount) == "number" and maxCount >= 0) and math.floor(maxCount) or #found
	for i = 1, math.min(limit, #found) do
		out[i] = found[i].Rec
	end
	return out
end

function MonsterService.CountInRadius(position, radius, forPlayer)
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return 0 end
	local n = 0
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer) then
			local root = rec.Root
			if root and root.Parent and Util.FlatDistance(root.Position, position) <= radius then
				n += 1
			end
		end
	end
	return n
end

------------------------------------------------------------------ spawn point (A7-1, grounded on Terrain per A10/A11)
-- Returns a point ON the ground (Y = ground height) inside def.Zone, or nil when every try landed on water / a ridge
-- (the density pass retries a few seconds later).
local function pickSpawnPoint(def)
	local zone = Config.Zones[def.Zone]
	if not zone then return nil end
	local inset = MC.SpawnInset
	local anyHit = false
	local function try(pt)
		local g, noHit = groundPoint(pt.X, pt.Z)
		if not noHit then anyHit = true end
		if g and Config.ZoneAt(g).Id == def.Zone then return g end
		return nil
	end
	if SPREAD_ENABLED then
		local bestPos, bestCount = nil, nil
		for _, p in readyPlayers() do
			if Util.IsAlive(p) then
				local root = Util.GetRoot(p)
				if root then
					local pos = root.Position
					local z = Config.ZoneAt(pos)
					if z.Id == def.Zone and not z.Town then
						local c = MonsterService.CountInRadius(pos, SPREAD_COUNT_RADIUS, p)
						if bestCount == nil or c < bestCount then
							bestPos, bestCount = pos, c
						end
					end
				end
			end
		end
		if bestPos and bestCount < SPREAD_THRESHOLD then
			for _ = 1, SPREAD_TRIES do
				local a = Util.Random:NextNumber(0, math.pi * 2)
				local d = Util.Random:NextNumber(SPREAD_MIN, SPREAD_MAX)
				local pt = Vector3.new(bestPos.X + math.cos(a) * d, 0, bestPos.Z + math.sin(a) * d)
				if insideZone(zone, pt, inset) then
					local g = try(pt)
					if g then return g end
				end
			end
		end
	end
	for _ = 1, SPAWN_TRIES do
		local g = try(Util.RandomPointInZone(zone, inset))
		if g then return g end
	end
	if not anyHit then
		-- no Terrain / Map.Ground under the zone at all (bare test place): legacy flat ground at Y = 0
		return Util.RandomPointInZone(zone, inset)
	end
	warnThrottled("spawnpoint_" .. def.Zone, "no walkable ground found in " .. def.Zone .. " this pass (water/ridge); retrying later")
	return nil
end

------------------------------------------------------------------ rig construction
local function makeBar(root, text, golden, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Name = "MonsterBar"
	bb.Size = UDim2.fromOffset(150, 34)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = BAR_MAX_DISTANCE
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false

	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.Text = text
	name.TextColor3 = golden and MC.GoldenColor or Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.TextScaled = true
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 16
	tsc.MinTextSize = MIN_TEXT_SIZE
	tsc.Parent = name
	name.Parent = bb

	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.Position = UDim2.new(0.1, 0, 0, 23)
	back.Size = UDim2.new(0.8, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(0, 4)
	c1.Parent = back
	back.Parent = bb

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_HIGH
	fill.BorderSizePixel = 0
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 4)
	c2.Parent = fill
	fill.Parent = back

	bb.Parent = root
	return fill
end

local function updateBar(rec)
	local fill = rec._fill
	if not fill or not fill.Parent then return end
	local r = (rec.MaxHP > 0) and math.clamp(rec.HP / rec.MaxHP, 0, 1) or 0
	fill.Size = UDim2.fromScale(r, 1)
	fill.BackgroundColor3 = BAR_LOW:Lerp(BAR_HIGH, r)
end

-- A1: clone a custom visual, scale it to the procedural body height, sit it on the floor facing the root.
-- Returns (visualModel, parts) or nil when the template is unusable.
local function buildCustomVisual(template, rootCF, bodyHeight, floorY)
	local clone = template:Clone()
	local visual
	if clone:IsA("BasePart") then
		visual = Instance.new("Model")
		clone.Parent = visual
		visual.PrimaryPart = clone
	else
		visual = clone
	end
	visual.Name = "CustomVisual"

	for _, d in visual:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end

	local parts = {}
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		visual:Destroy()
		return nil
	end

	-- face the root's look direction (the template's pivot orientation is treated as its "front")
	visual:PivotTo(CFrame.new(visual:GetPivot().Position) * rootCF.Rotation)

	-- scale so the bounding-box height matches the procedural body height
	local _, size = visual:GetBoundingBox()
	if size.Y > 0.01 then
		local factor = bodyHeight / size.Y
		local okScale, cur = pcall(visual.GetScale, visual)
		if not okScale or type(cur) ~= "number" or cur <= 0 then cur = 1 end
		pcall(visual.ScaleTo, visual, cur * factor)
	end

	-- bottom on the floor, centered under the root
	local bbCF, bbSize = visual:GetBoundingBox()
	local rootPos = rootCF.Position
	local delta = Vector3.new(
		rootPos.X - bbCF.Position.X,
		(floorY + bbSize.Y / 2) - bbCF.Position.Y,
		rootPos.Z - bbCF.Position.Z
	)
	visual:PivotTo(visual:GetPivot() + delta)
	return visual, parts
end

-- builds the model (not parented yet). Returns a table with Model, Root, VisualRoot, Humanoid, Fill, Parts, VisualParts,
-- BodyHeight, Hip.
local function buildRig(kind, def, golden, groundPos, faceTo)
	local s = def.Scale or 1
	local isSlime = def.Shape == "Slime"
	local rootSize, hip, bodyHeight, topAboveRoot
	if isSlime then
		rootSize = Vector3.new(2 * s, 2 * s, 2 * s)
		hip = 0.5 * s
		bodyHeight = 3 * s -- ball diameter; root center sits 1.5s above the floor
		topAboveRoot = 1.5 * s -- ball top
	else
		rootSize = Vector3.new(2 * s, 2 * s, 1 * s)
		hip = 2 * s
		bodyHeight = 5 * s -- legs bottom at the floor, head top 5s above it
		topAboveRoot = 2 * s -- head top
	end

	local floorY = groundPos.Y
	local rootY = floorY + hip + rootSize.Y / 2
	local rootPos = Vector3.new(groundPos.X, rootY, groundPos.Z)
	local rootCF
	if typeof(faceTo) == "Vector3" and Util.FlatDistance(faceTo, rootPos) > 0.1 then
		rootCF = CFrame.lookAt(rootPos, Vector3.new(faceTo.X, rootY, faceTo.Z))
	else
		rootCF = CFrame.new(rootPos) * CFrame.Angles(0, Util.Random:NextNumber(0, math.pi * 2), 0)
	end

	local model = Instance.new("Model")
	model.Name = kind

	local root = newPart({
		Name = "HumanoidRootPart",
		Size = rootSize,
		CFrame = rootCF,
		Transparency = 1,
		Massless = false,
	})
	root.Parent = model
	model.PrimaryPart = root

	-- invisible anchor for every visible part (see VISUAL_ROOT_NAME); starts exactly on the root
	local visualRoot = newPart({
		Name = VISUAL_ROOT_NAME,
		Size = Vector3.new(VISUAL_ROOT_SIZE, VISUAL_ROOT_SIZE, VISUAL_ROOT_SIZE),
		CFrame = rootCF,
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
	})
	visualRoot.Parent = model
	local joint = Instance.new("Weld")
	joint.Name = VISUAL_JOINT_NAME
	joint.Part0 = root
	joint.Part1 = visualRoot
	joint.C0 = CFrame.identity
	joint.C1 = CFrame.identity
	joint.Parent = visualRoot

	local bodyColor = golden and MC.GoldenColor or def.Color
	local darkColor = golden and MC.GoldenColor or def.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	local parts = {}
	local function add(props, offset)
		props.CFrame = rootCF * offset
		local p = newPart(props)
		p.Parent = model
		table.insert(parts, p)
		return p
	end

	if isSlime then
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(3 * s, 3 * s, 3 * s), Color = bodyColor, Transparency = 0.1 },
			CFrame.new())
		for side = -1, 1, 2 do
			add({ Name = side < 0 and "EyeL" or "EyeR", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45 * s, 0.45 * s, 0.45 * s), Color = EYE_COLOR },
				CFrame.new(side * 0.5 * s, 0.35 * s, -1.33 * s))
		end
	else
		add({ Name = "Torso", Size = Vector3.new(2 * s, 2 * s, 1 * s), Color = darkColor }, CFrame.new())
		add({ Name = "Head", Size = Vector3.new(2 * s, 1 * s, 1 * s), Color = bodyColor }, CFrame.new(0, 1.5 * s, 0))
		add({ Name = "Left Arm", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = bodyColor }, CFrame.new(-1.5 * s, 0, 0))
		add({ Name = "Right Arm", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = bodyColor }, CFrame.new(1.5 * s, 0, 0))
		add({ Name = "Left Leg", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = darkColor }, CFrame.new(-0.5 * s, -2 * s, 0))
		add({ Name = "Right Leg", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = darkColor }, CFrame.new(0.5 * s, -2 * s, 0))
		for side = -1, 1, 2 do
			add({ Name = side < 0 and "EyeL" or "EyeR", Size = Vector3.new(0.3 * s, 0.3 * s, 0.05 * s), Color = EYE_COLOR },
				CFrame.new(side * 0.45 * s, 1.6 * s, -0.52 * s))
		end
	end

	-- A1 custom visual (procedural parts stay as an invisible hitbox)
	local visualParts = nil
	local template = getCustomTemplate(kind)
	if template then
		local ok, visual, vparts = pcall(buildCustomVisual, template, rootCF, bodyHeight, floorY)
		if ok and visual then
			for _, p in parts do p.Transparency = 1 end
			visual.Parent = model
			visualParts = vparts
			if golden then
				local h = Instance.new("Highlight")
				h.Name = "GoldenTint"
				h.FillColor = MC.GoldenColor
				h.FillTransparency = GOLDEN_FILL_TRANSPARENCY
				h.OutlineColor = MC.GoldenColor
				h.OutlineTransparency = 0.3
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = visual
			end
		elseif not ok then
			warnThrottled("custom_" .. kind, "custom model for " .. kind .. " failed: " .. tostring(visual))
		end
	end

	if golden then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "GoldenSparkle"
		pe.Color = ColorSequence.new(MC.GoldenColor)
		pe.Rate = 8
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(1, 3)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 0.8
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * s), NumberSequenceKeypoint.new(1, 0) })
		pe.Parent = root
		local light = Instance.new("PointLight")
		light.Name = "GoldenLight"
		light.Color = MC.GoldenColor
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = root
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = hip
	hum.WalkSpeed = def.Speed
	hum.AutoJumpEnabled = false
	hum.MaxSlopeAngle = MAX_SLOPE_ANGLE -- A11-R2
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.MaxHealth = 100
	hum.Health = 100
	hum.Parent = model

	local label = golden and ("황금 " .. def.Name) or def.Name
	local fill = makeBar(root, label, golden, topAboveRoot + 1.6)

	model:SetAttribute("MonsterKind", kind)
	model:SetAttribute("Golden", golden)
	-- body size for the client attack motion (lunge distance, lean pivot at the floor)
	model:SetAttribute("BodyHeight", bodyHeight)
	model:SetAttribute("RootHeight", rootY - floorY)

	return {
		Model = model,
		Root = root,
		VisualRoot = visualRoot,
		Humanoid = hum,
		Fill = fill,
		Parts = parts,
		VisualParts = visualParts,
		BodyHeight = bodyHeight,
		Hip = hip,
		Scale = s,
		RootOffset = rootY - floorY, -- root center height above the floor (used by PivotTo(Home))
	}
end

------------------------------------------------------------------ spawn / despawn
local function spawnMonster(kind, opts)
	local def = Config.MonsterTypes[kind]
	if not def then return nil end
	opts = opts or {}
	local owner = opts.Owner

	local golden
	if owner ~= nil or opts.Golden ~= nil then
		golden = opts.Golden == true
	else
		golden = Util.Random:NextNumber() < MC.GoldenChance
	end

	-- point is ON the ground (its Y = ground height); never assume a flat Part floor (A10/A11 Terrain world)
	local point = opts.Position
	if typeof(point) ~= "Vector3" then
		point = pickSpawnPoint(def)
		if not point then return nil end
	end
	local rig = buildRig(kind, def, golden, point, opts.FaceTo)

	local maxHP
	if type(opts.HP) == "number" and opts.HP > 0 and opts.HP == opts.HP then
		maxHP = opts.HP
	else
		maxHP = def.HP * (golden and MC.GoldenHPMult or 1)
	end

	if owner then
		rig.Model:SetAttribute("OwnerUserId", owner.UserId)
	end

	-- parent, weld (visible parts to VisualRoot, which is jointed to the root), network owner, humanoid states.
	-- Gameplay (hits, AI, knockback) only uses the root; parts follow it through the joints.
	rig.Model.Parent = getMonstersFolder()
	local anchor = rig.VisualRoot or rig.Root
	for _, p in rig.Parts do
		Util.Weld(anchor, p)
	end
	if rig.VisualParts then
		for _, p in rig.VisualParts do
			Util.Weld(anchor, p)
		end
	end
	pcall(rig.Root.SetNetworkOwner, rig.Root, nil)
	for _, st in DISABLED_STATES do
		pcall(rig.Humanoid.SetStateEnabled, rig.Humanoid, st, false)
	end

	-- A1: simple "alive" bob for custom visuals (moves the whole rig a little via HipHeight)
	local bob = nil
	if rig.VisualParts then
		local ok, tw = pcall(function()
			return TweenService:Create(
				rig.Humanoid,
				TweenInfo.new(BOB_PERIOD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ HipHeight = rig.Hip + rig.BodyHeight * BOB_FRACTION }
			)
		end)
		if ok and tw then
			bob = tw
			tw:Play()
		end
	end

	nextId += 1
	local rec = {
		Id = nextId,
		Kind = kind,
		Def = def,
		ZoneId = def.Zone,
		Model = rig.Model,
		Root = rig.Root,
		Humanoid = rig.Humanoid,
		HP = maxHP,
		MaxHP = maxHP,
		Golden = golden,
		Home = point,
		Alive = true,
		Owner = owner,
		-- private
		_fill = rig.Fill,
		_bob = bob,
		_scale = rig.Scale,
		_rootOffset = rig.RootOffset,
		_contributors = {},
		_nextAttackAt = 0,
		_nextWanderAt = os.clock() + Util.Random:NextNumber(1, WANDER_MAX),
		_noAggroUntil = 0,
		_returning = false,
		_target = nil,
		_goal = nil, -- last MoveTo destination (stuck detection, A11-R5)
		_stuckAt = nil,
		_stuckPos = nil,
		_chaseStuck = 0,
		_detour = nil,
		_detourUntil = 0,
		_deepSince = nil, -- A10-V3-2 (c): when the root first went below DEEP_Y
	}
	records[rec.Id] = rec
	return rec
end

local function emitDeathParticles(pos, color, scale)
	local fx = Instance.new("Part")
	fx.Name = "MonsterPop"
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.Transparency = 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = CFrame.new(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -25, 0)
	pe.LightEmission = 0.4
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 * scale), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = fx
	fx.Parent = Util.GetFolder(workspace, "Effects")
	pe:Emit(DEATH_PARTICLES)
	Debris:AddItem(fx, 1.5)
end

-- shrink/fade 0.3 s, particle burst, destroy after 0.4 s
local function deathPop(rec, withParticles)
	local model, root, hum = rec.Model, rec.Root, rec.Humanoid
	if rec._bob then
		pcall(function() rec._bob:Cancel() end)
		rec._bob = nil
	end
	if not model then return end
	if hum and hum.Parent then
		hum.WalkSpeed = 0
	end
	if root and root.Parent then
		root.Anchored = true
		local bar = root:FindFirstChild("MonsterBar")
		if bar then bar.Enabled = false end
		if withParticles then
			emitDeathParticles(root.Position, rec.Golden and MC.GoldenColor or rec.Def.Color, rec._scale or 1)
		end
	end
	local info = TweenInfo.new(DEATH_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d ~= root and d.Name ~= VISUAL_ROOT_NAME then -- the invisible joint anchor keeps its size
				TweenService:Create(d, info, { Size = d.Size * 0.2, Transparency = 1 }):Play()
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then
			d.Enabled = false
		end
	end
	task.delay(DEATH_DESTROY, function()
		if model then model:Destroy() end
	end)
end

local function removePersonalRef(rec)
	local owner = rec.Owner
	if not owner then return end
	local set = personal[owner]
	if set then
		set[rec] = nil
		if next(set) == nil then personal[owner] = nil end
	end
end

local scheduleRespawn -- forward

-- removes a record without rewards (timeout, owner left, model lost)
local function despawn(rec, fade)
	if not rec.Alive then return end
	rec.Alive = false
	records[rec.Id] = nil
	removePersonalRef(rec)
	if fade then
		deathPop(rec, false)
	elseif rec.Model then
		rec.Model:Destroy()
	end
end

scheduleRespawn = function(kind)
	pending[kind] = (pending[kind] or 0) + 1
	task.delay(MC.RespawnDelay, function()
		pending[kind] = math.max(0, (pending[kind] or 0) - 1)
		local ok, err = pcall(function()
			if aliveCountOf(kind) < targetCount(kind) and totalNonPersonal() < GLOBAL_CAP then
				spawnMonster(kind)
			end
		end)
		if not ok then warnThrottled("respawn", err) end
	end)
end

------------------------------------------------------------------ damage / death
local function killRecord(rec)
	rec.Alive = false
	rec.HP = 0
	records[rec.Id] = nil
	updateBar(rec)

	local def = rec.Def
	local pos = (rec.Root and rec.Root.Parent) and rec.Root.Position or rec.Home
	local isPersonal = rec.Owner ~= nil
	local warPoints = 0
	if not isPersonal then
		warPoints = rec.Golden and Config.War.GoldenPoints or Config.War.MonsterPoints
	end
	local info = {
		Kind = rec.Kind,
		ZoneId = rec.ZoneId,
		Golden = rec.Golden,
		Position = pos,
		XP = def.XP * (rec.Golden and MC.GoldenXPMult or 1),
		Gold = def.Gold * (rec.Golden and MC.GoldenGoldMult or 1),
		WarPoints = warPoints,
		Personal = isPersonal,
	}

	local now = os.clock()
	for p, t in rec._contributors do
		if p.Parent and now - t <= MC.ContributorWindow then
			MonsterService.MonsterKilled:Fire(p, table.clone(info))
		end
	end
	rec._contributors = {}

	deathPop(rec, true)
	if isPersonal then
		removePersonalRef(rec)
	else
		scheduleRespawn(rec.Kind)
	end
end

function MonsterService.DamageMonster(record, amount, player)
	if type(record) ~= "table" or not record.Alive then return false end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then return false end
	if record.Owner and record.Owner ~= player then return false end -- A5-C2
	if player then
		record._contributors[player] = os.clock()
	end
	record.HP -= amount
	if record.HP > 0 then
		updateBar(record)
		return false
	end
	killRecord(record)
	return true
end

function MonsterService.ApplyKnockback(record, fromPosition, power)
	if type(record) ~= "table" or not record.Alive then return end
	if typeof(fromPosition) ~= "Vector3" or type(power) ~= "number" then return end
	local root = record.Root
	if not root or not root.Parent or root.Anchored then return end
	local d = root.Position - fromPosition
	local flat = Vector3.new(d.X, 0, d.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
	root.AssemblyLinearVelocity = dir * power + Vector3.new(0, 25, 0)
end

------------------------------------------------------------------ personal monsters (A4 / A5-C2..C4)
function MonsterService.SpawnPersonal(player, monsterId, opts)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then return nil end
	if type(monsterId) ~= "string" or Config.MonsterTypes[monsterId] == nil then return nil end
	if type(opts) ~= "table" then opts = {} end

	-- one living personal monster of a kind per player: reuse it
	local set = personal[player]
	if set then
		for rec in set do
			if rec.Alive and rec.Kind == monsterId and rec.Model and rec.Model.Parent then
				return rec.Model
			end
		end
	end

	-- ~8 studs in front of the player on walkable ground (then the sides / behind); fallback: the home-zone spawn
	local pos, faceTo
	local root = Util.GetRoot(player)
	if root then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		local base = root.Position
		for _, ang in { 0, math.pi / 2, -math.pi / 2, math.pi } do
			local c, s = math.cos(ang), math.sin(ang)
			local dir = Vector3.new(flat.X * c - flat.Z * s, 0, flat.X * s + flat.Z * c)
			local p = base + dir * PERSONAL_DISTANCE
			local g, noHit = groundPoint(p.X, p.Z)
			if g then
				pos = g
			elseif noHit then
				pos = Vector3.new(p.X, 0, p.Z) -- bare test place: legacy flat ground
			end
			if pos then break end
		end
		faceTo = base
	end
	if not pos then
		local faction = player:GetAttribute("Faction")
		local zone = Config.Zones[Config.HomeZoneId(type(faction) == "string" and faction or "None")] or Config.Zones.Crossroads
		local p = zone.Spawn + Vector3.new(0, 0, -PERSONAL_DISTANCE)
		local y, water = probeGround(p.X, p.Z)
		pos = Vector3.new(p.X, (y and not water) and y or 0, p.Z)
		faceTo = faceTo or zone.Spawn
	end

	local ok, rec = pcall(spawnMonster, monsterId, {
		Owner = player,
		Golden = opts.Golden == true,
		HP = tonumber(opts.HP),
		Position = pos,
		FaceTo = faceTo,
	})
	if not ok then
		warnThrottled("personal", rec)
		return nil
	end
	if not rec then return nil end

	personal[player] = personal[player] or {}
	personal[player][rec] = true

	task.delay(PERSONAL_LIFETIME, function()
		if rec.Alive then despawn(rec, true) end
	end)
	return rec.Model
end

local function onOwnerLeaving(player)
	local set = personal[player]
	if not set then return end
	personal[player] = nil
	for rec in set do
		if rec.Alive then
			rec.Alive = false
			records[rec.Id] = nil
			if rec.Model then rec.Model:Destroy() end
		end
	end
end

------------------------------------------------------------------ AI
local function findInfo(plist, player)
	for _, info in plist do
		if info.Player == player then return info end
	end
	return nil
end

-- A10-V3-2 (a) + A3-M4: a player this (non-personal) monster may chase: in the monster's own zone, not in a town,
-- not in the water
local function targetable(rec, info)
	return not info.Town and info.Zone == rec.ZoneId and info.Pos.Y >= OUT_Y
end

-- turns the root (whole assembly) toward the target on the floor plane when it is far off the look direction
local function faceTarget(rec, targetPos)
	local root = rec.Root
	if root.Anchored then return end
	local pos = root.Position
	local flat = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	if flat.Magnitude < 0.1 then return end
	local dir = flat.Unit
	if root.CFrame.LookVector:Dot(dir) >= FACE_TARGET_DOT then return end
	root.CFrame = CFrame.lookAt(pos, pos + dir)
end

local function attack(rec, info, now)
	rec._goal = nil
	rec.Humanoid:MoveTo(rec.Root.Position)
	if now >= rec._nextAttackAt then
		rec._nextAttackAt = now + MC.AttackCooldown
		-- the client lunge goes along the look direction, so face the target first
		local okFace, errFace = pcall(faceTarget, rec, info.Pos)
		if not okFace then warnThrottled("face", errFace) end
		local model = rec.Model
		if model then
			local seq = model:GetAttribute(ATTACK_SEQ_ATTR)
			model:SetAttribute(ATTACK_SEQ_ATTR, (type(seq) == "number" and seq or 0) + 1)
		end
		if S and S.CombatService then
			S.CombatService.DamagePlayer(info.Player, rec.Def.Damage, nil)
		end
	end
end

-- A10-V3-2 (c): put the monster back on its home point (sunk in water / cannot walk back)
local function pivotHome(rec)
	local root = rec.Root
	local p = rec.Home + Vector3.new(0, rec._rootOffset or 3, 0)
	local lv = root.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	rec.Model:PivotTo(CFrame.lookAt(p, p + flat.Unit))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	rec.Humanoid:MoveTo(p)
	rec._goal = nil
	rec._stuckAt = nil
	rec._detour = nil
	rec._deepSince = nil
end

-- A10-V3-2 (c): below DEEP_Y for more than DEEP_SECONDS -> PivotTo(Home). Returns true when it teleported.
local function deepRecovery(rec, pos, now)
	if pos.Y >= DEEP_Y then
		rec._deepSince = nil
		return false
	end
	if rec._deepSince == nil then
		rec._deepSince = now
		return false
	end
	if now - rec._deepSince > DEEP_SECONDS then
		pivotHome(rec)
		return true
	end
	return false
end

-- A11-R5: true when the monster moved < STUCK_MIN_MOVE during the last STUCK_WINDOW s while trying to move
local function isStuck(rec, pos, now, trying)
	if not trying then
		rec._stuckAt = nil
		return false
	end
	if rec._stuckAt == nil then
		rec._stuckAt, rec._stuckPos = now, pos
		return false
	end
	if now - rec._stuckAt < STUCK_WINDOW then return false end
	local moved = Util.FlatDistance(pos, rec._stuckPos)
	rec._stuckAt, rec._stuckPos = now, pos
	return moved < STUCK_MIN_MOVE
end

-- A11-R5: a short sideways detour (8-14 studs, 60-150 deg off the blocked direction) on walkable ground in the zone
local function startDetour(rec, zone, pos, goal, now)
	local to = goal and Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z) or Vector3.zero
	local baseAng = to.Magnitude > 0.01 and math.atan2(to.Z, to.X) or Util.Random:NextNumber(0, math.pi * 2)
	for _ = 1, DETOUR_TRIES do
		local side = Util.Random:NextNumber() < 0.5 and -1 or 1
		local a = baseAng + side * Util.Random:NextNumber(math.rad(60), math.rad(150))
		local r = Util.Random:NextNumber(DETOUR_MIN, DETOUR_MAX)
		local p = clampToZone(zone, Vector3.new(pos.X + math.cos(a) * r, pos.Y, pos.Z + math.sin(a) * r))
		local g, noHit = groundPoint(p.X, p.Z)
		if noHit then g = p end
		if g and Util.FlatDistance(g, pos) > ARRIVE_DIST then
			rec._detour = g
			rec._detourUntil = now + DETOUR_SECONDS
			return
		end
	end
	rec._detour = nil
end

-- every non-personal MoveTo goes through here; `dest` is already clamped into the zone (A10-V3-2 b)
local function steer(rec, dest, pos, now)
	local d = rec._detour
	if d then
		if now < rec._detourUntil and Util.FlatDistance(pos, d) > ARRIVE_DIST then
			dest = d
		else
			rec._detour = nil
		end
	end
	rec._goal = dest
	rec.Humanoid:MoveTo(dest)
end

-- wander point within WANDER_RADIUS of Home, clamped into the zone and on walkable ground (never water / ridge)
local function pickWanderPoint(rec, zone)
	for _ = 1, WANDER_TRIES do
		local a = Util.Random:NextNumber(0, math.pi * 2)
		local r = Util.Random:NextNumber(0, WANDER_RADIUS)
		local p = clampToZone(zone, rec.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local g, noHit = groundPoint(p.X, p.Z)
		if g then return g end
		if noHit then return p end -- bare test place without Terrain / Map.Ground: legacy flat behaviour
	end
	return nil
end

local function personalStep(rec, plist, now, pos)
	local owner = rec.Owner
	if owner.Parent == nil then
		despawn(rec, false)
		return
	end
	local info = findInfo(plist, owner)
	if not info or info.Town or info.Pos.Y < OUT_Y then
		rec.Humanoid:MoveTo(pos) -- sandbag: stand still (also never follow the owner into the water)
		return
	end
	local d = Util.FlatDistance(pos, info.Pos)
	if d > PERSONAL_FOLLOW_RADIUS then
		rec.Humanoid:MoveTo(pos)
	elseif d <= MC.AttackRange then
		attack(rec, info, now)
	else
		rec.Humanoid:MoveTo(info.Pos)
	end
end

local function aiStep(rec, plist, now)
	local root, hum = rec.Root, rec.Humanoid
	if not root or not root.Parent or not hum or not hum.Parent or not rec.Model or not rec.Model.Parent then
		-- model lost (destroyed externally / fell out of the world)
		local kind, wasPersonal = rec.Kind, rec.Owner ~= nil
		despawn(rec, false)
		if not wasPersonal then scheduleRespawn(kind) end
		return
	end
	local pos = root.Position

	-- A10-V3-2 (c): sunk deep (water, knocked off a cliff) for > 2 s -> back home. Also for personal monsters.
	if deepRecovery(rec, pos, now) then return end

	if rec.Owner then
		personalStep(rec, plist, now, pos)
		return
	end

	local zone = Config.Zones[rec.ZoneId]
	local homeDist = Util.FlatDistance(pos, rec.Home)

	-- A10-V3-2 (c): out of its own zone (knockback, slid off) or in the water -> walk home, no re-aggro for 3 s.
	-- If it makes no progress (river bank, cliff) it is put back home.
	if Config.ZoneAt(pos).Id ~= rec.ZoneId or pos.Y < OUT_Y then
		rec._target = nil
		rec._returning = true
		rec._detour = nil
		rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
		if isStuck(rec, pos, now, homeDist > ARRIVE_DIST) then
			pivotHome(rec)
			return
		end
		local homeDest = clampToZone(zone, rec.Home)
		rec._goal = homeDest
		hum:MoveTo(homeDest)
		return
	end

	-- leash: go home and do not re-aggro for a moment (anti-jitter). (A monster standing in a town is out of its zone
	-- and already handled above.)
	if homeDist > MC.LeashRadius then
		rec._returning = true
		rec._target = nil
		rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
	end

	-- A3-M4 / A10-V3-2 (a): the current target stepped into a town, left this zone or went into the water
	-- -> return home, no re-aggro for 3 s
	if rec._target then
		local tinfo = findInfo(plist, rec._target)
		if not tinfo then
			rec._target = nil
		elseif not targetable(rec, tinfo) then
			rec._target = nil
			rec._returning = true
			rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
		end
	end

	-- A11-R5: stuck on terrain while moving -> pick a different destination
	local trying = rec._goal ~= nil and Util.FlatDistance(pos, rec._goal) > ARRIVE_DIST
	if isStuck(rec, pos, now, trying) then
		if rec._returning then
			startDetour(rec, zone, pos, rec.Home, now)
		elseif rec._target then
			rec._chaseStuck += 1
			if rec._chaseStuck >= CHASE_STUCK_GIVEUP then
				-- the target is unreachable (ridge slope etc.): give up, go home, no re-aggro for a moment
				rec._chaseStuck = 0
				rec._target = nil
				rec._returning = true
				rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
			else
				startDetour(rec, zone, pos, rec._goal, now)
			end
		else
			rec._goal = nil
			rec._detour = nil
			rec._nextWanderAt = now -- wander somewhere else right away
		end
	end

	if rec._returning then
		if homeDist <= RETURN_DONE_DIST or (now >= rec._noAggroUntil and homeDist <= MC.LeashRadius * 0.75) then
			rec._returning = false
		else
			steer(rec, clampToZone(zone, rec.Home), pos, now)
			return
		end
	end

	-- target = nearest alive player within AggroRadius standing in THIS zone, outside towns and water (A10-V3-2 a)
	local best, bestD = nil, nil
	if now >= rec._noAggroUntil then
		for _, info in plist do
			if targetable(rec, info) then
				local d = Util.FlatDistance(pos, info.Pos)
				if d <= MC.AggroRadius and (bestD == nil or d < bestD) then
					best, bestD = info, d
				end
			end
		end
	end

	if best then
		if rec._target ~= best.Player then rec._chaseStuck = 0 end
		rec._target = best.Player
		if bestD <= MC.AttackRange then
			rec._chaseStuck = 0
			attack(rec, best, now)
		else
			steer(rec, clampToZone(zone, best.Pos), pos, now) -- A10-V3-2 (b)
		end
		return
	end

	rec._target = nil
	if now >= rec._nextWanderAt then
		rec._nextWanderAt = now + Util.Random:NextNumber(WANDER_MIN, WANDER_MAX)
		local dest = pickWanderPoint(rec, zone)
		if dest then
			rec._detour = nil
			steer(rec, dest, pos, now)
		end
	end
end

local function aiTick()
	local now = os.clock()
	local plist = {}
	for _, p in readyPlayers() do
		if p.Parent and Util.IsAlive(p) then
			local root = Util.GetRoot(p)
			if root then
				local pos = root.Position
				table.insert(plist, { Player = p, Pos = pos, Town = isPlayerInTown(p, pos), Zone = Config.ZoneAt(pos).Id })
			end
		end
	end
	local list = {}
	for _, rec in records do
		table.insert(list, rec)
	end
	for _, rec in list do
		if rec.Alive then
			local ok, err = pcall(aiStep, rec, plist, now)
			if not ok then warnThrottled("ai", err) end
		end
	end
end

------------------------------------------------------------------ density (A3-M2 / A5-C1)
local function reevaluate()
	local zoneCounts = playersPerZone()
	local total = totalNonPersonal()
	for _, kind in Config.MonsterTypeOrder do
		if total >= GLOBAL_CAP then break end
		local target = targetCount(kind, zoneCounts)
		local have = aliveCountOf(kind) + (pending[kind] or 0)
		local spawned = 0
		while have < target and total < GLOBAL_CAP and spawned < MAX_SPAWNS_PER_KIND_PER_PASS do
			local rec = spawnMonster(kind)
			if not rec then break end
			have += 1
			total += 1
			spawned += 1
		end
	end
end

------------------------------------------------------------------ lifecycle
function MonsterService.Init(registry)
	S = registry
	getMonstersFolder()
	Util.GetFolder(workspace, "Effects")
	Util.GetFolder(ServerStorage, CUSTOM_FOLDER) -- A1: may stay empty
	if S.PlayerService and S.PlayerService.PlayerLeaving then
		S.PlayerService.PlayerLeaving:Connect(function(player)
			onOwnerLeaving(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		onOwnerLeaving(player)
	end)
end

function MonsterService.Start()
	for _, id in Config.MonsterTypeOrder do
		print(("[MonsterService] custom model for %s: %s"):format(id, getCustomTemplate(id) and "yes" or "no"))
	end

	local total = 0
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if def then
			for _ = 1, def.Count do
				if total >= GLOBAL_CAP then break end
				local ok, rec = pcall(spawnMonster, kind)
				if ok and rec then
					total += 1
				elseif not ok then
					warnThrottled("spawn_" .. kind, rec)
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(MC.AIInterval)
			local ok, err = pcall(aiTick)
			if not ok then warnThrottled("aiLoop", err) end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(REEVAL_INTERVAL)
			local ok, err = pcall(reevaluate)
			if not ok then warnThrottled("density", err) end
		end
	end)

	print("[MonsterService] started")
end

return MonsterService
