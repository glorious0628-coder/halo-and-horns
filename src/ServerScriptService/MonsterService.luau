-- MonsterService.luau : monster rigs (procedural or custom visual), spawn/respawn with zone density and spawn spread,
-- AI loop, monster HP, kill rewards (MonsterKilled) and personal (tutorial) monsters.
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

-- AI tuning that is not in Config (private)
local NO_REAGGRO_SECONDS = 3 -- A3-M4
local RETURN_DONE_DIST = 6
local WANDER_RADIUS = 15
local WANDER_MIN, WANDER_MAX = 4, 8
local PERSONAL_DISTANCE = 8 -- A4: ~8 studs in front of the player
local PERSONAL_LIFETIME = 120 -- A4: despawn after 120 s
local PERSONAL_FOLLOW_RADIUS = 80 -- A5-C3: a personal monster only tracks its owner when the owner is this close

-- visuals
local BAR_MAX_DISTANCE = 80
local DEATH_FADE = 0.3
local DEATH_DESTROY = 0.4
local DEATH_PARTICLES = 15
local BOB_PERIOD = 0.55
local BOB_FRACTION = 0.06 -- custom visual bob height as a fraction of the body height
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
	local folder = ServerStorage:FindFirstChild("CustomModels")
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

------------------------------------------------------------------ spawn point (A7-1)
local function pickSpawnPoint(def)
	local zone = Config.Zones[def.Zone]
	local inset = MC.SpawnInset
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
					return pt
				end
			end
		end
	end
	return Util.RandomPointInZone(zone, inset)
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
	tsc.MinTextSize = 11
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

-- builds the model (not parented yet). Returns a table with Model, Root, Humanoid, Fill, Parts, VisualParts, BodyHeight, Hip.
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
				h.FillTransparency = 0.5
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

	return {
		Model = model,
		Root = root,
		Humanoid = hum,
		Fill = fill,
		Parts = parts,
		VisualParts = visualParts,
		BodyHeight = bodyHeight,
		Hip = hip,
		Scale = s,
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

	local point = opts.Position or pickSpawnPoint(def)
	point = Vector3.new(point.X, 0, point.Z) -- ground top is Y = 0 everywhere
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

	-- parent, weld, network owner, humanoid states
	rig.Model.Parent = getMonstersFolder()
	for _, p in rig.Parts do
		Util.Weld(rig.Root, p)
	end
	if rig.VisualParts then
		for _, p in rig.VisualParts do
			Util.Weld(rig.Root, p)
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
		_contributors = {},
		_nextAttackAt = 0,
		_nextWanderAt = os.clock() + Util.Random:NextNumber(1, WANDER_MAX),
		_noAggroUntil = 0,
		_returning = false,
		_target = nil,
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
			if d ~= root then
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

	local pos, faceTo
	local root = Util.GetRoot(player)
	if root then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		local p = root.Position + flat * PERSONAL_DISTANCE
		pos = Vector3.new(p.X, 0, p.Z)
		faceTo = root.Position
	else
		local faction = player:GetAttribute("Faction")
		local zone = Config.Zones[Config.HomeZoneId(type(faction) == "string" and faction or "None")] or Config.Zones.Crossroads
		pos = zone.Spawn + Vector3.new(0, 0, -PERSONAL_DISTANCE)
		faceTo = zone.Spawn
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

local function attack(rec, info, now)
	rec.Humanoid:MoveTo(rec.Root.Position)
	if now >= rec._nextAttackAt then
		rec._nextAttackAt = now + MC.AttackCooldown
		if S and S.CombatService then
			S.CombatService.DamagePlayer(info.Player, rec.Def.Damage, nil)
		end
	end
end

local function personalStep(rec, plist, now, pos)
	local owner = rec.Owner
	if owner.Parent == nil then
		despawn(rec, false)
		return
	end
	local info = findInfo(plist, owner)
	if not info or info.Town then
		rec.Humanoid:MoveTo(pos) -- sandbag: stand still
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

	if rec.Owner then
		personalStep(rec, plist, now, pos)
		return
	end

	-- leash / town: go home and do not re-aggro for a moment (anti-jitter)
	local homeDist = Util.FlatDistance(pos, rec.Home)
	if homeDist > MC.LeashRadius or Config.ZoneAt(pos).Town then
		rec._returning = true
		rec._target = nil
		rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
	end

	-- A3-M4: the current target stepped into a town -> return home, no re-aggro for 3 s
	if rec._target then
		local tinfo = findInfo(plist, rec._target)
		if tinfo and tinfo.Town then
			rec._target = nil
			rec._returning = true
			rec._noAggroUntil = now + NO_REAGGRO_SECONDS
		elseif not tinfo then
			rec._target = nil
		end
	end

	if rec._returning then
		if homeDist <= RETURN_DONE_DIST or (now >= rec._noAggroUntil and homeDist <= MC.LeashRadius * 0.75) then
			rec._returning = false
		else
			hum:MoveTo(rec.Home)
			return
		end
	end

	-- target = nearest alive player within AggroRadius that is not in a town
	local best, bestD = nil, nil
	if now >= rec._noAggroUntil then
		for _, info in plist do
			if not info.Town then
				local d = Util.FlatDistance(pos, info.Pos)
				if d <= MC.AggroRadius and (bestD == nil or d < bestD) then
					best, bestD = info, d
				end
			end
		end
	end

	if best then
		rec._target = best.Player
		if bestD <= MC.AttackRange then
			attack(rec, best, now)
		else
			hum:MoveTo(best.Pos)
		end
		return
	end

	rec._target = nil
	if now >= rec._nextWanderAt then
		rec._nextWanderAt = now + Util.Random:NextNumber(WANDER_MIN, WANDER_MAX)
		local a = Util.Random:NextNumber(0, math.pi * 2)
		local r = Util.Random:NextNumber(0, WANDER_RADIUS)
		hum:MoveTo(rec.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
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
				table.insert(plist, { Player = p, Pos = pos, Town = isPlayerInTown(p, pos) })
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
	Util.GetFolder(ServerStorage, "CustomModels") -- A1: may stay empty
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
