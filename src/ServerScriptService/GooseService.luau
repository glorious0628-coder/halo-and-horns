-- GooseService.luau : golden goose tug-of-war ("황금 거위 줄다리기"), Regular's Luck rare rewards, cheer stars.
-- Owner: G9. Public surface (TECH_SPEC §4.16): GooseFinished, Init, Start, IsActive, GetPosition, RegisterHit, DebugStart.
-- SPEC_ADDENDUM A1: ServerStorage.CustomModels.GoldenGoose (Model or BasePart) replaces the procedural body visually.
-- SPEC_ADDENDUM A6: only Halo/Horns players add tug counts and receive tug rewards (Neutral/None count 0).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "GooseService"
local GOOSE_LABEL = "황금 거위" -- billboard text required verbatim by TECH_SPEC §4.16
local CUSTOM_ID = "GoldenGoose" -- SPEC_ADDENDUM A1 id
local MAX_SIDE_OFFSET = 6 -- studs; tug pivot clamp (§4.16)
local VISUAL_BOTTOM = -2.0 -- procedural body bottom relative to the goose center
local VISUAL_HEIGHT = 6.9 -- procedural body height (body bottom -> crown-shard tip)
local BOB_AMPLITUDE = 0.35
local BOB_SPEED = 2.4
local SWAY_ANGLE = math.rad(12)
local SWAY_SPEED = 0.8
local SIDE_LERP = 2.5 -- per second
local WARN_INTERVAL = 10

local COLOR_GOLD = Color3.fromRGB(255, 200, 40)
local COLOR_GOLD_DARK = Color3.fromRGB(225, 160, 25)
local COLOR_BEAK = Color3.fromRGB(255, 135, 30)
local COLOR_EYE = Color3.fromRGB(20, 20, 20)
local COLOR_SHARD = Color3.fromRGB(255, 245, 170)
local COLOR_LIGHT = Color3.fromRGB(255, 215, 110)
local COLOR_LABEL_STROKE = Color3.fromRGB(90, 55, 0)

-- procedural body, offsets relative to the goose center (local -Z = forward / the goose's LookVector)
local PROCEDURAL_PARTS = {
	{ Name = "Body", Class = "Part", Size = Vector3.new(4, 4, 4), At = CFrame.new(0, 0, 0.2), Color = COLOR_GOLD, Ball = true, Shiny = true },
	{ Name = "Chest", Class = "Part", Size = Vector3.new(3, 3, 3), At = CFrame.new(0, 0.5, -1.1), Color = COLOR_GOLD, Ball = true, Shiny = true },
	{ Name = "Tail", Class = "WedgePart", Size = Vector3.new(1.6, 1.2, 1.6), At = CFrame.new(0, 0.9, 2.3) * CFrame.Angles(0, math.pi, 0), Color = COLOR_GOLD_DARK },
	{ Name = "Neck", Class = "Part", Size = Vector3.new(0.9, 2.4, 0.9), At = CFrame.new(0, 2.0, -1.8), Color = COLOR_GOLD, Shiny = true },
	{ Name = "Head", Class = "Part", Size = Vector3.new(1.6, 1.6, 1.6), At = CFrame.new(0, 3.4, -1.9), Color = COLOR_GOLD, Ball = true, Shiny = true },
	{ Name = "Beak", Class = "WedgePart", Size = Vector3.new(0.55, 0.45, 1.0), At = CFrame.new(0, 3.25, -3.0), Color = COLOR_BEAK },
	{ Name = "EyeL", Class = "Part", Size = Vector3.new(0.32, 0.32, 0.32), At = CFrame.new(-0.6, 3.6, -2.45), Color = COLOR_EYE, Ball = true },
	{ Name = "EyeR", Class = "Part", Size = Vector3.new(0.32, 0.32, 0.32), At = CFrame.new(0.6, 3.6, -2.45), Color = COLOR_EYE, Ball = true },
	{ Name = "WingL", Class = "Part", Size = Vector3.new(0.35, 1.6, 2.8), At = CFrame.new(-2.0, 0.35, 0.3) * CFrame.Angles(0, 0, math.rad(25)), Color = COLOR_GOLD_DARK },
	{ Name = "WingR", Class = "Part", Size = Vector3.new(0.35, 1.6, 2.8), At = CFrame.new(2.0, 0.35, 0.3) * CFrame.Angles(0, 0, math.rad(-25)), Color = COLOR_GOLD_DARK },
	{ Name = "CrownShard", Class = "WedgePart", Size = Vector3.new(0.35, 0.9, 0.7), At = CFrame.new(0, 4.45, -1.9) * CFrame.Angles(0, math.rad(90), math.rad(12)), Color = COLOR_SHARD, Neon = true },
}

local GooseService = {}
GooseService.GooseFinished = Util.Signal.new() -- (result: "Halo" | "Horns" | "Tie", counts: { [Player]: number })

local S = nil
local gameState = nil

-- event state
local active = false
local endsAt = 0
local nextAt = 0
local rescue = 0
local poach = 0
local counts = {} -- [Player] = number (faction-scaled tug counts this event)
local hitTimes = {} -- [Player] = { os.clock() } accepted counts within the rolling 1 s window
local publishedRescue = -1
local publishedPoach = -1

-- model state
local gooseModel = nil
local gooseRoot = nil
local motionConn = nil
local sideOffset = 0
local sideTarget = 0

local lastWarnAt = {}

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (lastWarnAt[key] or -math.huge) >= WARN_INTERVAL then
		lastWarnAt[key] = now
		Util.Warn(TAG, tostring(msg))
	end
end

-- pcall-protected call into another service; returns its FIRST result, or nil (and warns, throttled) on failure
local function call(serviceName, fnName, ...)
	local svc = S and S[serviceName]
	local fn = svc and svc[fnName]
	if type(fn) ~= "function" then
		warnThrottled(serviceName .. "." .. fnName, "missing " .. serviceName .. "." .. fnName)
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warnThrottled(serviceName .. "." .. fnName, serviceName .. "." .. fnName .. " failed: " .. tostring(result))
		return nil
	end
	return result
end

local function getGameState()
	if gameState and gameState.Parent then return gameState end
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gameState = gs end
	return gameState
end

local function setGame(key, value)
	local gs = getGameState()
	if gs then gs:SetAttribute(key, value) end
end

local function isPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player")
end

local function isReady(p)
	return isPlayer(p) and p.Parent ~= nil and call("PlayerService", "IsReady", p) == true
end

local function factionOf(p)
	local f = call("FactionService", "GetFaction", p)
	if type(f) ~= "string" then return "None" end
	return f
end

local function isTugFaction(f)
	return f == "Halo" or f == "Horns"
end

-- persisted numeric stat: live data table first, mirrored attribute as fallback
local function getNum(p, key)
	local data = call("PlayerService", "GetData", p)
	local v = (type(data) == "table") and data[key] or nil
	if type(v) ~= "number" then v = p:GetAttribute(key) end
	return tonumber(v) or 0
end

local function round1(x)
	return math.floor(x * 10 + 0.5) / 10
end

local function gooseCenter()
	return Config.Goose.Position + Vector3.new(0, Config.Goose.HoverHeight, 0)
end

-- the goose faces the Crossroads fountain
local function baseRotation()
	local c = gooseCenter()
	local f = Config.Map.FountainPosition
	local look = Vector3.new(f.X, c.Y, f.Z)
	if (look - c).Magnitude < 0.1 then return CFrame.new() end
	local cf = CFrame.lookAt(c, look)
	return cf - cf.Position
end

-- next goose start: aligned to WarService's round end minus OffsetFromWarEnd, advanced by Interval past `now`
local function computeNextAt(now, fallback)
	local base = fallback
	local roundEnd = call("WarService", "GetRoundEndsAt")
	if type(roundEnd) == "number" and roundEnd == roundEnd and roundEnd > now - 86400 then
		base = roundEnd - Config.Goose.OffsetFromWarEnd
	end
	if type(base) ~= "number" or base ~= base or base < now - 86400 then
		base = now + Config.Goose.OffsetFromWarEnd
	end
	local interval = math.max(1, Config.Goose.Interval)
	if base <= now then
		base += (math.floor((now - base) / interval) + 1) * interval
	end
	return base
end

------------------------------------------------------------------ goose model
local function prepVisualPart(p)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
end

local function getCustomTemplate()
	local folder = ServerStorage:FindFirstChild("CustomModels")
	if not folder then return nil end
	local t = folder:FindFirstChild(CUSTOM_ID)
	if t and (t:IsA("Model") or t:IsA("BasePart")) then return t end
	return nil
end

-- world-space vertical extent of a set of parts (exact for box-shaped parts)
local function worldYRange(parts)
	local minY, maxY = math.huge, -math.huge
	for _, p in parts do
		local cf, s = p.CFrame, p.Size
		local half = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
		minY = math.min(minY, cf.Position.Y - half)
		maxY = math.max(maxY, cf.Position.Y + half)
	end
	return minY, maxY
end

local function buildProcedural(model, root, rootCF)
	for _, def in PROCEDURAL_PARTS do
		local p = Util.MakePart({
			ClassName = def.Class,
			Name = def.Name,
			Size = def.Size,
			CFrame = rootCF * def.At,
			Color = def.Color,
			Material = def.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			Reflectance = def.Shiny and 0.15 or 0,
		})
		if def.Ball and p:IsA("Part") then p.Shape = Enum.PartType.Ball end
		prepVisualPart(p)
		p.Parent = model
		Util.Weld(root, p)
	end
end

-- A1: clone the custom visual, scale it to the procedural height, put its bottom where the procedural body's is,
-- face the root's LookVector and weld every part to the root. Returns true on success.
local function buildCustom(model, root, rootCF, template)
	local clone = template:Clone()
	local rot = rootCF - rootCF.Position
	local targetBottom = rootCF.Position.Y + VISUAL_BOTTOM
	local parts = {}
	if clone:IsA("BasePart") then
		prepVisualPart(clone)
		local h = clone.Size.Y
		if h > 0.01 then clone.Size = clone.Size * (VISUAL_HEIGHT / h) end
		clone.CFrame = CFrame.new(rootCF.Position.X, targetBottom + clone.Size.Y / 2, rootCF.Position.Z) * rot
		table.insert(parts, clone)
	else
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				prepVisualPart(d)
				table.insert(parts, d)
			elseif d:IsA("BaseScript") then
				d:Destroy() -- a purely cosmetic visual never runs code
			end
		end
		if #parts == 0 then
			clone:Destroy()
			return false
		end
		clone:PivotTo(CFrame.new(rootCF.Position) * rot)
		local minY, maxY = worldYRange(parts)
		local height = maxY - minY
		if height > 0.01 then
			local okScale = pcall(function()
				clone:ScaleTo(clone:GetScale() * (VISUAL_HEIGHT / height))
			end)
			if not okScale then warnThrottled("customScale", "custom GoldenGoose could not be scaled; using its own size") end
		end
		minY = worldYRange(parts)
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, targetBottom - minY, 0))
	end
	clone.Name = "Visual"
	clone.Parent = model
	for _, p in parts do
		Util.Weld(root, p)
	end
	return true
end

local function destroyModel()
	if motionConn then
		motionConn:Disconnect()
		motionConn = nil
	end
	if gooseModel then
		gooseModel:Destroy()
	end
	gooseModel = nil
	gooseRoot = nil
end

local function startMotion(rot)
	if motionConn then motionConn:Disconnect() end
	local t0 = os.clock()
	motionConn = RunService.Heartbeat:Connect(function(dt)
		local root = gooseRoot
		if not root or not root.Parent then return end
		sideOffset += (sideTarget - sideOffset) * math.min(1, dt * SIDE_LERP)
		local t = os.clock() - t0
		local bob = math.sin(t * BOB_SPEED) * BOB_AMPLITUDE
		local sway = math.sin(t * SWAY_SPEED) * SWAY_ANGLE
		root.CFrame = CFrame.new(gooseCenter() + Vector3.new(sideOffset, bob, 0)) * rot * CFrame.Angles(0, sway, 0)
	end)
end

local function spawnModel()
	destroyModel()
	local effects = Util.GetFolder(workspace, "Effects")
	local old = effects:FindFirstChild("GoldenGoose")
	if old then old:Destroy() end

	local rot = baseRotation()
	local rootCF = CFrame.new(gooseCenter()) * rot

	local model = Instance.new("Model")
	model.Name = "GoldenGoose"

	-- invisible anchored root: one CFrame write moves the whole goose (bob + tug pivot)
	local root = Util.MakePart({
		Name = "Root",
		Size = Vector3.new(3, 3, 3),
		CFrame = rootCF,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	root.Parent = model
	model.PrimaryPart = root

	local template = getCustomTemplate()
	local built = false
	if template then
		local ok, res = pcall(buildCustom, model, root, rootCF, template)
		built = ok and res == true
		if not built then
			warnThrottled("custom", "custom GoldenGoose failed, using the procedural goose: " .. tostring(res))
			local partial = model:FindFirstChild("Visual")
			if partial then partial:Destroy() end
		end
	end
	if not built then
		buildProcedural(model, root, rootCF)
	end

	local light = Instance.new("PointLight")
	light.Color = COLOR_LIGHT
	light.Brightness = 2
	light.Range = 16
	light.Shadows = false
	light.Parent = root

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Color = ColorSequence.new(COLOR_SHARD)
	sparkles.LightEmission = 1
	sparkles.Rate = 12
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1.5, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Parent = root

	local gui = Instance.new("BillboardGui")
	gui.Name = "GooseLabel"
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffset = Vector3.new(0, 6.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Adornee = root
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = COLOR_GOLD
	label.TextStrokeColor3 = COLOR_LABEL_STROKE
	label.TextStrokeTransparency = 0.2
	label.Text = GOOSE_LABEL
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = 11
	sizeLimit.MaxTextSize = 36
	sizeLimit.Parent = label
	label.Parent = gui
	gui.Parent = root

	model.Parent = effects
	gooseModel = model
	gooseRoot = root
	sideOffset, sideTarget = 0, 0
	startMotion(rot)
end

------------------------------------------------------------------ event flow
local function publishTotals(force)
	local r, p = round1(rescue), round1(poach)
	if force or r ~= publishedRescue then
		publishedRescue = r
		setGame("GooseRescue", r)
	end
	if force or p ~= publishedPoach then
		publishedPoach = p
		setGame("GoosePoach", p)
	end
end

local function start()
	if active then return end
	active = true
	endsAt = Util.Now() + Config.Goose.Duration
	rescue, poach = 0, 0
	counts = {}
	hitTimes = {}
	publishTotals(true)
	setGame("GooseEndsAt", endsAt)
	setGame("GooseActive", true)

	local players = call("PlayerService", "GetReadyPlayers")
	if type(players) == "table" then
		for _, p in players do
			if p.Parent then p:SetAttribute("GooseCount", 0) end
		end
	end

	local ok, err = pcall(spawnModel)
	if not ok then
		warnThrottled("spawn", "goose model failed: " .. tostring(err))
	end
	Net.NotifyAll(string.format(Config.Story.GooseStart))
end

local function rewardPlayer(p, result)
	local f = factionOf(p)
	if not isTugFaction(f) then return end -- A6: Neutral (and None) get no tug rewards
	local won = (result == f)

	local rare
	if getNum(p, "CheerStars") >= Config.Goose.CheerStarsForRare then
		rare = true
		call("PlayerService", "AddStat", p, "CheerStars", -Config.Goose.CheerStarsForRare)
	else
		local minutes = tonumber(call("PlayerService", "GetRegularMinutes", p)) or 0
		rare = Util.Random:NextNumber() < Config.RareChance(minutes)
	end

	local level = math.max(1, math.floor(getNum(p, "Level")))
	local gold, xp = Config.GooseReward(level, f, won, rare)
	if gold > 0 then call("ProgressionService", "AddBankGold", p, gold, "Event") end
	if xp > 0 then call("ProgressionService", "AddXP", p, xp) end
	Net.Notify(p, string.format(Config.Text.GooseReward, Util.FormatNumber(gold), Util.FormatNumber(xp)), "reward")

	if rare then
		Net.Fx(p, "Rare", { Gold = gold, XP = xp })
		Net.NotifyAll(string.format(Config.Text.RareAnnounce, p.DisplayName), "info")
	end

	if not won then -- loss or tie: +1 cheer star
		local cheer = getNum(p, "CheerStars")
		if cheer < Config.Goose.CheerStarsForRare then
			local newCount = call("PlayerService", "AddStat", p, "CheerStars", 1)
			cheer = tonumber(newCount) or (cheer + 1)
		end
		Net.Notify(p, string.format(Config.Text.GooseCheer, math.floor(cheer)), "info")
	end
end

local function finish()
	if not active then return end
	active = false
	-- schedule the next goose FIRST so a failure below can never re-trigger an event every tick
	endsAt = 0
	nextAt = computeNextAt(Util.Now(), nextAt)
	setGame("GooseNextAt", nextAt)

	local result = (rescue > poach) and "Halo" or ((poach > rescue) and "Horns" or "Tie")
	local fxPos = (gooseRoot and gooseRoot.Parent) and gooseRoot.Position or gooseCenter()
	local finalCounts = counts
	counts = {}
	hitTimes = {}

	for p, n in finalCounts do
		if type(n) == "number" and n > 0 and isReady(p) then
			local ok, err = pcall(rewardPlayer, p, result)
			if not ok then warnThrottled("reward", "goose reward failed for " .. p.Name .. ": " .. tostring(err)) end
		end
	end

	if result ~= "Tie" then
		call("WarService", "AddFactionPoints", result, Config.Goose.WinWarPoints)
	end
	local okSend, sendErr = pcall(function()
		Net.NotifyAll(string.format(Config.Story.GooseResult[result]))
		Net.Fx(nil, "GooseEnd", { Pos = fxPos, Winner = result })
	end)
	if not okSend then warnThrottled("send", "goose result broadcast failed: " .. tostring(sendErr)) end

	destroyModel()
	for p in finalCounts do
		if isPlayer(p) and p.Parent then p:SetAttribute("GooseCount", 0) end
	end
	publishTotals(true)
	setGame("GooseActive", false)
	setGame("GooseEndsAt", 0)

	GooseService.GooseFinished:Fire(result, finalCounts)
end

local function tick()
	local now = Util.Now()
	if not active then
		if now >= nextAt then start() end
		return
	end
	if now >= endsAt then
		finish()
		return
	end
	local total = rescue + poach
	sideTarget = math.clamp((poach - rescue) / math.max(1, total) * MAX_SIDE_OFFSET, -MAX_SIDE_OFFSET, MAX_SIDE_OFFSET)
	publishTotals(false)
end

------------------------------------------------------------------ public API
function GooseService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(function(player)
		if isPlayer(player) and player.Parent then
			player:SetAttribute("GooseCount", 0)
		end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		-- the leaver's contribution stays in the side totals
		counts[player] = nil
		hitTimes[player] = nil
	end)
end

function GooseService.Start()
	getGameState()
	nextAt = computeNextAt(Util.Now(), nil)
	setGame("GooseNextAt", nextAt)
	setGame("GooseActive", false)
	setGame("GooseEndsAt", 0)
	publishTotals(true)

	task.spawn(function()
		while true do
			task.wait(Config.Goose.Tick)
			local ok, err = pcall(tick)
			if not ok then warnThrottled("loop", "tick error: " .. tostring(err)) end
		end
	end)

	print("[GooseService] custom model for " .. CUSTOM_ID .. ": " .. (getCustomTemplate() and "yes" or "no"))
	print("[GooseService] started")
end

function GooseService.IsActive()
	return active
end

function GooseService.GetPosition()
	if not active then return nil end
	return gooseCenter()
end

function GooseService.RegisterHit(player, isManual)
	if not active then return end
	if not isReady(player) then return end
	local f = factionOf(player)
	if not isTugFaction(f) then return end -- A6: Neutral swings on the goose count 0

	-- rolling 1 s window: at most MaxCountsPerSecond accepted counts per player
	local now = os.clock()
	local list = hitTimes[player]
	if not list then
		list = {}
		hitTimes[player] = list
	end
	while list[1] and now - list[1] >= 1 do
		table.remove(list, 1)
	end
	if #list >= Config.Goose.MaxCountsPerSecond then return end
	table.insert(list, now)

	local scale = tonumber(call("JusticeService", "GetFactionScale", f)) or 1
	if scale ~= scale or scale <= 0 then scale = 1 end
	local amount = ((isManual == true) and Config.Goose.ManualCount or Config.Goose.AutoCount) * scale
	counts[player] = (counts[player] or 0) + amount
	if f == "Halo" then
		rescue += amount
	else
		poach += amount
	end
	player:SetAttribute("GooseCount", math.floor(counts[player]))
end

function GooseService.DebugStart()
	if active then return end
	local ok, err = pcall(start)
	if not ok then warnThrottled("debug", "DebugStart failed: " .. tostring(err)) end
end

return GooseService
