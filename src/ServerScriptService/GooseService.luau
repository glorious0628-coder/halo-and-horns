-- GooseService.luau : golden goose tug-of-war ("황금 거위 줄다리기"), Regular's Luck rare rewards, cheer stars.
-- Owner: G9. Public surface (TECH_SPEC §4.16): GooseFinished, Init, Start, IsActive, GetPosition, RegisterHit, DebugStart.
-- SPEC_ADDENDUM A1: ServerStorage.CustomModels.GoldenGoose (Model or BasePart) replaces the procedural body visually.
-- SPEC_ADDENDUM A6: only Halo/Horns players add tug counts and receive tug rewards (Neutral/None count 0).
-- Review fixes: a reward needs >= MIN_MANUAL_HITS manual counts (auto-only AFK players still pull, never get paid), and a
-- faction switch mid-event forfeits that player's entry (no pulling for one side and collecting the other's win).
-- CR-L21: GetPosition follows the tug pivot; RegisterHit returns the count actually added (0 = rejected).
-- A23-14 "함께 구조" (co-op, replaces CR-L8's forced tie): if only one of Halo/Horns has ready players when the goose
-- lands, the event is co-op for that side (fixed for the whole event; "Pending" while nobody is eligible, fixed by the
-- first eligible player). Gauge target = Config.Goose.CoopPerPerson x that side's ready players at that moment (min 1).
-- Success pays Config.Goose.CoopWinShare of the winner reward, 0 war points; a gauge not filled takes the tie path.
-- A tug whose rival side left before the end is judged the same way (no 100% win, no war points without a rival).
-- GameState for the HUD: GooseMode ("Versus" | "Coop"), GooseCoopSide ("Halo" | "Horns" | "None"), GooseCoopTarget,
-- GooseCoopPeople. GooseFinished keeps (result, counts) and adds an optional 3rd arg { Mode, Side, Success, Target }.
-- A23-131 / A23-134 / A23-137 (Config.Goose.Mode "Eggs", the default): the golden egg hunt. GooseEggs.luau (required only
-- here) runs the rules every Egg.Tick s; this service keeps the schedule (fixed KST clock times, Schedule.Every), the goose
-- model (Act / ActUntil, walking where GooseEggs says), the co-op target (CoopPerPerson x ring entrants), overtime
-- (GameState GooseOvertimeUntil), the verdict ("a side never came" by ring presence), rewards (2 eggs or 20 points),
-- Honor / Infamy +5 once an hour, war +30. counts in GooseFinished = delivery points. RegisterHit returns 0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)
-- the egg hunt rules (nil if the module cannot load: Eggs mode then falls back to the tug, with a warning)
local okEggs, GooseEggs = pcall(function()
	return require(script.Parent:FindFirstChild("GooseEggs"))
end)
if not okEggs or type(GooseEggs) ~= "table" then GooseEggs = nil end
local EGG = Config.Goose.Egg or {}
-- A23-141: the Goose Square (GooseSquare.luau, required only here): Join / Leave, the space, the way back
local okSquare, GooseSquare = pcall(function()
	return require(script.Parent:FindFirstChild("GooseSquare"))
end)
if not okSquare or type(GooseSquare) ~= "table" then GooseSquare = nil end
local SQS = Config.Goose.SquareSpace or {}

local TAG = "GooseService"
local GOOSE_LABEL = Config.Goose.Text.Label -- billboard text (TECH_SPEC §4.16; English since A23-48)
local CUSTOM_FOLDER = (Config.CustomModels and Config.CustomModels.FolderName) or "CustomModels" -- A1
local CUSTOM_ID = (Config.CustomModels and Config.CustomModels.GooseId) or "GoldenGoose" -- A1
-- review fix (anti-AFK): rewards (and GooseFinished participation) need this many ACCEPTED manual counts this event;
-- auto-attack counts still move the tug but alone never pay.
local MIN_MANUAL_HITS = math.max(1, math.floor(tonumber(Config.Goose.MinManualHits) or 3))
local TXT = Config.Goose.Text or {} -- Korean goose texts (NeedManual + A23-14 co-op)
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
-- HealthService (2026-10-09): one paid player of a finished goose: (player, { Won, Rare, Gold, XP, Level, Mode = "Versus" | "Coop" })
GooseService.GooseRewarded = Util.Signal.new()

local S = nil
local gameState = nil

-- BB37: every server-wide line names players through AnnounceService.PublicName (hidden -> "<faction> 한 명")
local function publicName(p, honorific)
	local A = S.AnnounceService
	if A and A.PublicName then
		local ok, name = pcall(A.PublicName, p, honorific)
		if ok and type(name) == "string" then return name end
	end
	return Util.PlayerDisplayName(p) .. (honorific and Config.Announce.Text.Honorific or "")
end

-- event state
local active = false
local endsAt = 0
local nextAt = 0
local rescue = 0
local poach = 0
local counts = {} -- [Player] = number (faction-scaled tug counts this event)
local manualHits = {} -- [Player] = accepted MANUAL counts this event (reward eligibility)
local sideOf = {} -- [Player] = faction the player's counts were made for ("Halo" | "Horns")
local hitTimes = {} -- [Player] = { os.clock() } accepted counts within the rolling 1 s window
local publishedRescue = -1
local publishedPoach = -1
-- A23-14 event mode: "Idle" between events, "Pending" (active, nobody eligible yet), "Versus" or "Coop"
local mode = "Idle"
local coop = { Side = "None", People = 0, Target = 0, Full = false, Told = {} } -- Told[Player] = RivalWait sent

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

-- A23-131: the egg hunt runs (Mode "Eggs" and GooseEggs loaded)
local function eggsOn()
	return Config.Goose.Mode == "Eggs" and GooseEggs ~= nil
end

-- A23-141: the egg hunt is played in the Goose Square (Join only); off = the old ring at the Crossroads fountain
local function squareOn()
	return eggsOn() and GooseSquare ~= nil and SQS.Enabled == true
end

-- the egg rules' geometry for this round: the square's marks and members, or the Config ring
local function setEggGeometry()
	if not squareOn() then
		GooseEggs.SetGeometry(nil)
		return
	end
	local sp = GooseSquare.Ensure()
	GooseEggs.SetGeometry({ Center = sp.GooseSpot, Home = { Halo = sp.Nest, Horns = sp.Cart },
		Avoid = { sp.SpawnHalo, sp.SpawnHorns, sp.SpawnNeutral }, AvoidRadius = SQS.SpawnClear, Square = true,
		Members = GooseSquare.Members })
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

-- string.format(fmt, ...) of a Config.Goose.Text entry (fmt may be a { Halo, Horns } table keyed by side); nil if
-- the text is missing or the format fails, so a text typo never breaks the event
local function txt(key, side, ...)
	local fmt = TXT[key]
	if type(fmt) == "table" then fmt = fmt[side] end
	if type(fmt) ~= "string" then
		warnThrottled("txt." .. tostring(key), "missing Config.Goose.Text." .. tostring(key))
		return nil
	end
	local ok, s = pcall(string.format, fmt, ...)
	if not ok then
		warnThrottled("txtfmt." .. tostring(key), "bad Config.Goose.Text." .. tostring(key) .. ": " .. tostring(s))
		return nil
	end
	return s
end

-- ready Halo / Horns players (FactionService.GetCounts: ready, still in Players, not leaving; Neutral/None never count)
local function factionCounts()
	local fs = S and S.FactionService
	if fs and type(fs.GetCounts) == "function" then
		local ok, halo, horns = pcall(fs.GetCounts) -- called directly: the call helper only returns the first result
		if ok then
			return math.max(0, math.floor(tonumber(halo) or 0)), math.max(0, math.floor(tonumber(horns) or 0))
		end
		warnThrottled("counts", "FactionService.GetCounts failed: " .. tostring(halo))
	end
	local halo, horns = 0, 0
	local players = call("PlayerService", "GetReadyPlayers")
	if type(players) == "table" then
		for _, p in players do
			if isPlayer(p) and p.Parent then
				local f = factionOf(p)
				if f == "Halo" then
					halo += 1
				elseif f == "Horns" then
					horns += 1
				end
			end
		end
	end
	return halo, horns
end

-- this event's pull total of one side (the co-op gauge)
local function sideTotal(side)
	if side == "Halo" then return rescue end
	if side == "Horns" then return poach end
	return 0
end

local function coopTargetFor(people)
	local per = tonumber(eggsOn() and EGG.CoopPerPerson or Config.Goose.CoopPerPerson) or 20
	if per ~= per or per <= 0 then per = 20 end
	return math.max(1, math.floor(per * math.max(1, people) + 0.5))
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
	if eggsOn() then
		-- A23-137: fixed KST clock times (Every 14400 = 00/04/08/12/16/20 KST), the next one strictly after now
		local sch = Config.Goose.Schedule or {}
		local every = math.max(60, tonumber(sch.Every) or 14400)
		local tz = tonumber(sch.TzOffset) or 32400
		return (math.floor((now + tz) / every) + 1) * every - tz
	end
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
	local folder = ServerStorage:FindFirstChild(CUSTOM_FOLDER)
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

-- A23-131: the walking goose (Eggs mode) glides to where GooseEggs puts it, facing where it goes; feet on the ground
local function startEggMotion()
	if motionConn then motionConn:Disconnect() end
	motionConn = RunService.Heartbeat:Connect(function(dt)
		local root = gooseRoot
		local target = GooseEggs and GooseEggs.GoosePos()
		if not root or not root.Parent or not target then return end
		local want = target + Vector3.new(0, -VISUAL_BOTTOM, 0)
		local cur = root.Position
		local pos = cur:Lerp(want, math.min(1, dt * 8))
		local look = Vector3.new(want.X - cur.X, 0, want.Z - cur.Z)
		if look.Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(pos, pos + look)
		else
			root.CFrame = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
		end
	end)
end

local function spawnModel()
	destroyModel()
	local effects = Util.GetFolder(workspace, "Effects")
	local old = effects:FindFirstChild("GoldenGoose")
	if old then old:Destroy() end

	local eggs = eggsOn() and GooseEggs.GoosePos() or nil
	local rot = baseRotation()
	local rootCF = CFrame.new(eggs and (eggs + Vector3.new(0, -VISUAL_BOTTOM, 0)) or gooseCenter()) * rot

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

	if eggs then -- contract §6: no "Golden Goose" name tag over the walking goose; Act / ActUntil for the client
		model:SetAttribute("Act", "Walk")
		model:SetAttribute("ActUntil", 0)
		model.Parent = effects
		gooseModel = model
		gooseRoot = root
		sideOffset, sideTarget = 0, 0
		startEggMotion()
		return
	end

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

-- GameState mirror of the event mode for EventHUD (anything but a fixed co-op shows as the normal tug)
local function publishMode()
	local isCoop = (mode == "Coop")
	setGame("GooseMode", isCoop and "Coop" or "Versus")
	setGame("GooseCoopSide", isCoop and coop.Side or "None")
	setGame("GooseCoopTarget", isCoop and coop.Target or 0)
	setGame("GooseCoopPeople", isCoop and coop.People or 0)
end

-- A23-14: fix a "Pending" event's mode from who is on the server right now: both tug factions -> Versus, exactly one
-- -> Coop for it (target from its ready headcount now), nobody -> stays Pending. Once fixed it never changes for this
-- event (no mid-event flips). A23-130: no line of its own (the start line was the only one; the top gauge shows the mode).
local function fixMode()
	if mode ~= "Pending" then return end
	local halo, horns = factionCounts()
	if halo > 0 and horns > 0 then
		mode = "Versus"
	elseif halo > 0 or horns > 0 then
		mode = "Coop"
		coop.Side = (halo > 0) and "Halo" or "Horns"
		coop.People = (halo > 0) and halo or horns
		coop.Target = coopTargetFor(coop.People)
		coop.Full = false
	else
		return
	end
	publishMode()
end

local function start()
	if active then return end
	active = true
	endsAt = Util.Now() + (eggsOn() and (tonumber(EGG.Duration) or 60) or Config.Goose.Duration)
	rescue, poach = 0, 0
	counts = {}
	manualHits = {}
	sideOf = {}
	hitTimes = {}
	-- A23-14: mode first, so the HUD never shows an active goose with the previous event's mode
	mode = "Pending"
	coop = { Side = "None", People = 0, Target = 0, Full = false, Told = {} }
	fixMode()
	if eggsOn() then
		-- A23-131: the co-op target grows with the side's ring entrants (none yet = 1 person)
		if mode == "Coop" then coop.People, coop.Target = 0, coopTargetFor(0) end
		setGame("GooseOvertimeUntil", 0)
		local okG, errG = pcall(setEggGeometry)
		if not okG then warnThrottled("eggGeometry", "egg geometry failed: " .. tostring(errG)) end
		local okB, errB = pcall(GooseEggs.Begin, Util.Now(), mode, coop.Side)
		if not okB then warnThrottled("eggBegin", "egg hunt start failed: " .. tostring(errB)) end
	end
	publishMode()
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
	-- A23-130: one short line for 2 s, the same in every mode
	local line = txt("Start")
	if line then pcall(Net.NotifyAll, line, "announce", math.max(0.5, tonumber(Config.Goose.StartSeconds) or 2)) end
end

-- forget a player's entry for this event; what they already pulled stays in the side totals (like a leaver)
local function dropEntry(p)
	counts[p] = nil
	manualHits[p] = nil
	sideOf[p] = nil
	hitTimes[p] = nil
	if eggsOn() then pcall(GooseEggs.DropEntry, p) end -- A23-131: carried eggs go back, a fresh entry
	if isPlayer(p) and p.Parent then
		p:SetAttribute("GooseCount", 0)
	end
end

-- f = the side the player's counts were made for, re-verified against the current faction by finish()
-- share = A23-14 co-op success multiplier (Config.Goose.CoopWinShare) or nil for the normal won/lost split
-- judged = "Versus" | "Coop" (what the round was judged as: a failed co-op has no share but is still Coop)
local function rewardPlayer(p, result, f, share, judged)
	if not isTugFaction(f) then return end -- A6: Neutral (and None) get no tug rewards
	local won = (result == f)

	local rare
	if getNum(p, "CheerStars") >= Config.Goose.CheerStarsForRare then
		rare = true
		call("PlayerService", "AddStat", p, "CheerStars", -Config.Goose.CheerStarsForRare)
	else
		local events = tonumber(call("PlayerService", "GetLuckEvents", p)) or 0 -- A23-18 오늘의 운
		rare = Util.Random:NextNumber() < Config.RareChance(events)
	end

	local level = math.max(1, math.floor(getNum(p, "Level")))
	local gold, xp = Config.GooseReward(level, f, won, rare, share)
	-- A23-75: what was really added (the 2x passes) is what the lines below show
	if gold > 0 then gold = tonumber(call("ProgressionService", "AddBankGold", p, gold, "Event")) or gold end
	-- A23-90: a private server halves the goose's XP too (its gold: ProgressionService.AddBankGold "Event")
	local prog = S and S.ProgressionService
	xp = math.floor(xp * (prog and type(prog.PrivateMult) == "function" and tonumber(prog.PrivateMult()) or 1))
	if xp > 0 then xp = tonumber(call("ProgressionService", "AddXP", p, xp)) or xp end
	local msg = (share ~= nil) and txt("CoopReward", f, Util.FormatNumber(gold), Util.FormatNumber(xp)) or nil
	msg = msg or string.format(Config.Text.GooseReward, Util.FormatNumber(gold), Util.FormatNumber(xp))

	if not won then -- loss or tie: +1 cheer star (A23-130: said on the reward line, one toast)
		local cheer = getNum(p, "CheerStars")
		if cheer < Config.Goose.CheerStarsForRare then
			local newCount = call("PlayerService", "AddStat", p, "CheerStars", 1)
			cheer = tonumber(newCount) or (cheer + 1)
		end
		msg ..= " · " .. string.format(Config.Text.GooseCheer, math.floor(cheer))
	end
	Net.Notify(p, msg, "reward", nil, "GoldPickup")

	if rare then -- A23-130: the winner's Rare Fx only, no server-wide brag line (RareAnnounce)
		Net.Fx(p, "Rare", { Gold = gold, XP = xp })
	end
	GooseService.GooseRewarded:Fire(p, { Won = won, Rare = rare == true, Gold = gold, XP = xp, Level = level,
		Mode = judged == "Coop" and "Coop" or "Versus" })
end

-- A23-134: Honor (Halo) / Infamy (Horns) +HonorPoints at most once per HonorEvery s per player (save EggHonorAt).
-- AddStat only: like every story / goose point it never reaches a ranking board (D1)
local function eggHonor(p, f)
	local data = call("PlayerService", "GetData", p)
	if type(data) ~= "table" or not isTugFaction(f) then return end
	local now = os.time()
	local at = Config.SanitizeEggHonorAt(data.EggHonorAt, now)
	if now - at < (tonumber(EGG.HonorEvery) or 3600) then return end
	local pts = tonumber(EGG.HonorPoints) or 5
	-- A23-134 "(주간 상한 안)": the same path as PvP / the grudge sack - the stat + the weekly board within WeekCap
	call("PlayerService", "GrantFame", p, f == "Halo" and "Honor" or "Infamy", pts, { RankPoints = pts })
	call("PlayerService", "SetStat", p, "EggHonorAt", now)
	local T = type(Config.StoryQuests) == "table" and Config.StoryQuests.Text or {}
	local fmt = f == "Halo" and T.GooseFirstHalo or T.GooseFirstHorns
	if type(fmt) == "string" then pcall(Net.Notify, p, string.format(fmt, pts), "good") end
end

-- A23-131: a paid side player delivered MinDelivered eggs or MinPoints points (MinCrowd eggs once P reached CrowdFrom)
local function eggPaid(delivered, points, peakP)
	local need = (peakP or 0) >= (tonumber(EGG.CrowdFrom) or 16) and (tonumber(EGG.MinCrowd) or 1) or (tonumber(EGG.MinDelivered) or 2)
	return (delivered or 0) >= need or (points or 0) >= (tonumber(EGG.MinPoints) or 20)
end

-- the egg hunt's end (finish() calls it in Eggs mode)
local function finishEggs()
	active = false
	if squareOn() then
		-- A23-141: the result shows for ReturnAfter s, then everyone still in the square goes back (scheduled first, so
		-- an error below can never leave anyone in the square; GooseSquare.Tick has a safety net too)
		task.delay(math.max(0, tonumber(SQS.ReturnAfter) or 4), function()
			local okR, errR = pcall(GooseSquare.ReturnAll, "End")
			if not okR then warnThrottled("squareReturn", "square return failed: " .. tostring(errR)) end
		end)
	end
	endsAt = 0
	nextAt = computeNextAt(Util.Now(), nextAt)
	setGame("GooseNextAt", nextAt)
	local okF, sum = pcall(GooseEggs.Finish, Util.Now())
	if not okF or type(sum) ~= "table" then
		warnThrottled("eggFinish", "egg hunt finish failed: " .. tostring(sum))
		sum = { Points = {}, Delivered = {}, Side = {}, Rescue = rescue, Poach = poach, Entrants = { Halo = 0, Horns = 0 }, PeakP = 0 }
	end
	pcall(GooseEggs.Cleanup)
	rescue, poach = math.floor(tonumber(sum.Rescue) or 0), math.floor(tonumber(sum.Poach) or 0)
	local entr = type(sum.Entrants) == "table" and sum.Entrants or { Halo = 0, Horns = 0 }
	-- verdict: a versus side that never came into the ring (or has nobody left) = the co-op rule for the other side
	local judged, side, target, rivalLeft, neverCame = mode, coop.Side, coop.Target, false, nil
	local result = "Tie"
	if judged ~= "Coop" then
		local halo, horns = factionCounts()
		local goneH = (entr.Halo or 0) <= 0 or halo <= 0
		local goneR = (entr.Horns or 0) <= 0 or horns <= 0
		if goneH and goneR then
			judged = "Pending"
		elseif goneH or goneR then
			judged = "Coop"
			side = goneH and "Horns" or "Halo"
			rivalLeft = true
			neverCame = (entr[goneH and "Halo" or "Horns"] or 0) <= 0 and (goneH and "Halo" or "Horns") or nil
		else
			judged = "Versus"
			result = (rescue > poach) and "Halo" or ((poach > rescue) and "Horns" or "Tie")
		end
	end
	local success = false
	if judged == "Coop" then
		target = coopTargetFor(entr[side] or 0)
		success = isTugFaction(side) and sideTotal(side) >= target
		result = success and side or "Tie"
	end
	local share = (judged == "Coop" and success) and (tonumber(Config.Goose.CoopWinShare) or 0.7) or nil
	local fxPos = (gooseRoot and gooseRoot.Parent) and gooseRoot.Position or (EGG.Center or gooseCenter())
	mode = "Idle"
	coop = { Side = "None", People = 0, Target = 0, Full = false, Told = {} }

	local rewarded = {}
	for p, pts in sum.Points do
		local f = sum.Side[p]
		if isReady(p) and factionOf(p) == f and (judged ~= "Coop" or f == side) then
			local delivered = sum.Delivered[p] or 0
			if eggPaid(delivered, pts, sum.PeakP) then
				rewarded[p] = pts
				local ok, err = pcall(rewardPlayer, p, result, f, share, judged)
				if not ok then warnThrottled("reward", "goose reward failed for " .. p.Name .. ": " .. tostring(err)) end
				local okH, errH = pcall(eggHonor, p, f)
				if not okH then warnThrottled("honor", "egg honor failed: " .. tostring(errH)) end
			elseif delivered >= 1 then
				local msg = txt("BringTwo") -- the one fail fact (A23-99)
				if msg then pcall(Net.Notify, p, msg, "info") end
			end
		end
	end
	if judged == "Versus" and result ~= "Tie" then -- co-op / a side that never came: no war points
		call("WarService", "AddFactionPoints", result, Config.Goose.WinWarPoints)
	end
	local okSend, sendErr = pcall(function()
		Net.Fx(nil, "GooseEnd", { Pos = fxPos, Winner = result, Coop = (judged == "Coop") })
	end)
	if not okSend then warnThrottled("send", "goose result broadcast failed: " .. tostring(sendErr)) end

	destroyModel()
	for p in sum.Points do
		if isPlayer(p) and p.Parent then p:SetAttribute("GooseCount", 0) end
	end
	local finalR, finalP = rescue, poach
	rescue, poach = 0, 0
	publishTotals(true)
	setGame("GooseActive", false)
	setGame("GooseEndsAt", 0)
	setGame("GooseOvertimeUntil", 0)
	publishMode()

	local info = { Mode = judged, Delivered = tonumber(sum.DeliveredTotal) or 0, H = sum.H,
		CrownFlip = sum.CrownFlip ~= nil and sum.CrownFlip == result, ScoreGap = math.abs(finalR - finalP),
		Rescue = finalR, Poach = finalP, DropFails = tonumber(sum.DropFails) or 0, CheatLogs = tonumber(sum.CheatLogs) or 0,
		Returns = sum.Returns, NeverCame = neverCame }
	if judged == "Coop" then
		info.Side = side
		info.Success = success
		info.Target = target
		info.RivalLeft = rivalLeft
	end
	if squareOn() then info.Joins = GooseSquare.TakeJoins() end
	GooseService.GooseFinished:Fire(result, rewarded, info)
end

local function finish()
	if not active then return end
	if eggsOn() then return finishEggs() end
	active = false
	-- schedule the next goose FIRST so a failure below can never re-trigger an event every tick
	endsAt = 0
	nextAt = computeNextAt(Util.Now(), nextAt)
	setGame("GooseNextAt", nextAt)

	-- A23-14 judgment. judged = "Versus" | "Coop" | "Pending" (nobody eligible ever pulled -> plain tie)
	local judged, side, target, rivalLeft = mode, coop.Side, coop.Target, false
	local result = "Tie"
	if judged == "Versus" then
		result = (rescue > poach) and "Halo" or ((poach > rescue) and "Horns" or "Tie")
		-- CR-L8 kept in spirit: a tug side with nobody left at the end gives no 100% win and no war points. The side
		-- still here is judged like co-op against its current headcount instead of a forced tie.
		local halo, horns = factionCounts()
		if halo <= 0 or horns <= 0 then
			rivalLeft = true
			judged = "Coop"
			side = (halo > 0) and "Halo" or ((horns > 0) and "Horns" or "None")
			target = coopTargetFor((side == "Halo") and halo or horns)
		end
	end
	local success = false
	if judged == "Coop" then
		success = isTugFaction(side) and sideTotal(side) >= target
		result = success and side or "Tie"
	end
	local share = (judged == "Coop" and success) and (tonumber(Config.Goose.CoopWinShare) or 0.7) or nil
	local fxPos = (gooseRoot and gooseRoot.Parent) and gooseRoot.Position or gooseCenter()
	local finalCounts, finalManual, finalSide = counts, manualHits, sideOf
	counts = {}
	manualHits = {}
	sideOf = {}
	hitTimes = {}
	mode = "Idle"
	coop = { Side = "None", People = 0, Target = 0, Full = false, Told = {} }

	-- paid participants: counts > 0, still on the side they pulled for, and enough MANUAL hits (auto-only = AFK)
	local rewarded = {}
	for p, n in finalCounts do
		if type(n) == "number" and n > 0 and isReady(p) then
			local f = factionOf(p)
			-- co-op pays only the co-op side (a rival never pulls in co-op; this also covers odd leftovers)
			if isTugFaction(f) and finalSide[p] == f and (judged ~= "Coop" or f == side) then
				if (finalManual[p] or 0) >= MIN_MANUAL_HITS then
					rewarded[p] = n
					local ok, err = pcall(rewardPlayer, p, result, f, share, judged)
					if not ok then warnThrottled("reward", "goose reward failed for " .. p.Name .. ": " .. tostring(err)) end
				else
					local msg = txt("NeedManual", nil, MIN_MANUAL_HITS)
					if msg then pcall(Net.Notify, p, msg, "info") end
				end
			end
		end
	end

	if judged == "Versus" and result ~= "Tie" then -- A23-14: co-op never gives war points
		call("WarService", "AddFactionPoints", result, Config.Goose.WinWarPoints)
	end
	-- A23-130: no result banner (the top bar and the reward lines say it); GooseEnd = the end visual + the big sound
	local okSend, sendErr = pcall(function()
		Net.Fx(nil, "GooseEnd", { Pos = fxPos, Winner = result, Coop = (judged == "Coop") })
	end)
	if not okSend then warnThrottled("send", "goose result broadcast failed: " .. tostring(sendErr)) end

	destroyModel()
	for p in finalCounts do
		if isPlayer(p) and p.Parent then p:SetAttribute("GooseCount", 0) end
	end
	publishTotals(true)
	setGame("GooseActive", false)
	setGame("GooseEndsAt", 0)
	publishMode() -- back to Versus / None / 0 between events

	-- same shape as the spec's counts ({ [Player]: number }), limited to the players who were actually paid,
	-- so quest progress never goes to AFK auto-swingers or side-switchers. Co-op participants are in it on success
	-- and on failure (like tug losers), so a co-op goose counts for StoryQuestService/QuestService. The optional 3rd
	-- arg tells listeners how the event was judged (Mode "Versus" | "Coop" | "Pending" = nobody eligible).
	local info = { Mode = judged }
	if judged == "Coop" then
		info.Side = side
		info.Success = success
		info.Target = target
		info.RivalLeft = rivalLeft
	end
	GooseService.GooseFinished:Fire(result, rewarded, info)
end

local function tick()
	local now = Util.Now()
	if squareOn() then
		local okQ, errQ = pcall(GooseSquare.Tick, now) -- falls out of the square, GooseJoinBlock
		if not okQ then warnThrottled("squareTick", "square tick failed: " .. tostring(errQ)) end
	end
	if not active then
		if now >= nextAt then
			local sw = S and S.SwitchService
			if type(sw) == "table" and type(sw.On) == "function" and not sw.On("Goose") then
				nextAt = now + 30 -- the live switchboard: no new goose while it is off
				setGame("GooseNextAt", nextAt)
			else
				start()
			end
		end
		return
	end
	if eggsOn() then
		if mode == "Pending" then
			fixMode()
			if mode == "Coop" then coop.People, coop.Target = 0, coopTargetFor(0) end
			if mode ~= "Pending" then GooseEggs.SetMode(mode, coop.Side) end
		end
		-- the walk's centre leans toward the losing side (+Z = the Horns cart), MAX_SIDE_OFFSET at most; none in co-op
		local r0, p0 = GooseEggs.Totals()
		local total = r0 + p0
		sideTarget = (mode == "Coop") and 0
			or math.clamp((r0 - p0) / math.max(1, total) * MAX_SIDE_OFFSET, -MAX_SIDE_OFFSET, MAX_SIDE_OFFSET)
		sideOffset += (sideTarget - sideOffset) * math.min(1, (tonumber(EGG.Tick) or 0.1) * SIDE_LERP)
		local res = GooseEggs.Step(now, { Tilt = sideOffset })
		rescue, poach = GooseEggs.Totals()
		if mode == "Coop" and isTugFaction(coop.Side) then
			local people = GooseEggs.Entrants(coop.Side)
			if people ~= coop.People then
				coop.People, coop.Target = people, coopTargetFor(people)
				publishMode()
			end
		end
		setGame("GooseOvertimeUntil", GooseEggs.OvertimeUntil())
		if gooseModel and gooseModel.Parent then
			local act, untilAt = GooseEggs.Act()
			gooseModel:SetAttribute("Act", act)
			gooseModel:SetAttribute("ActUntil", untilAt)
		end
		publishTotals(false)
		-- "Done" from the rules; a stuck round ends anyway well after the longest overtime
		if res == "Done" or now >= endsAt + (tonumber(EGG.Crown and EGG.Crown.Overtime) or 8) + 5 then finish() end
		return
	end
	if now >= endsAt then
		finish()
		return
	end
	if mode == "Pending" then fixMode() end -- e.g. the only player just picked a faction
	if mode == "Coop" then
		-- co-op: the goose slides toward the co-op side as the gauge fills (Halo = -X like a rescue lead)
		local fill = math.clamp(sideTotal(coop.Side) / math.max(1, coop.Target), 0, 1)
		sideTarget = ((coop.Side == "Halo") and -1 or 1) * fill * MAX_SIDE_OFFSET
		if not coop.Full and fill >= 1 then
			coop.Full = true -- totals never go down, so a full gauge stays a success until the timer ends
			-- A23-130: no "Gauge full!" line, the top bar shows it
		end
	else
		local total = rescue + poach
		sideTarget = math.clamp((poach - rescue) / math.max(1, total) * MAX_SIDE_OFFSET, -MAX_SIDE_OFFSET, MAX_SIDE_OFFSET)
	end
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
		-- the leaver's contribution stays in the side totals (and in a co-op gauge)
		counts[player] = nil
		manualHits[player] = nil
		sideOf[player] = nil
		hitTimes[player] = nil
		coop.Told[player] = nil
		if GooseSquare then
			pcall(GooseSquare.Leave, player, "Left") -- A23-141 (the eggs go back through OnLeave)
			pcall(GooseSquare.Forget, player)
		end
		if eggsOn() then pcall(GooseEggs.Leave, player) end -- A23-131: carried eggs fly back
	end)
	if GooseSquare then
		-- A23-141: Join only while a goose is on; leaving the square returns the carried eggs first
		GooseSquare.Init(S, {
			IsActive = function() return active == true and squareOn() end,
			OnLeave = function(p, reason)
				if eggsOn() then GooseEggs.ReturnEggs(p, reason == "Death" and "Death" or "Leave") end
			end,
		})
	end
	if GooseEggs then
		GooseEggs.Init(S)
		-- A23-131: dying returns the carried eggs at once (the next check would too: no living root)
		if S.PlayerService.CharacterDied then
			S.PlayerService.CharacterDied:Connect(function(player)
				if GooseSquare then pcall(GooseSquare.Leave, player, "Death") end -- A23-141: a death leaves the square
				if eggsOn() then pcall(GooseEggs.ReturnEggs, player, "Death") end
			end)
		end
	elseif Config.Goose.Mode == "Eggs" then
		warnThrottled("eggsMissing", "GooseEggs missing: the goose runs the old tug")
	end
	-- review fix: switching sides mid-event (altar is next to the perch) forfeits this event's entry, so nobody can pull
	-- for one side and then collect the winner share of the other. Pulling again after the switch starts a new entry.
	local fs = S.FactionService
	if fs and fs.FactionChanged then
		fs.FactionChanged:Connect(function(player)
			if GooseSquare then pcall(GooseSquare.Leave, player, "Faction") end -- A23-141: a new side starts outside
			if counts[player] ~= nil or hitTimes[player] ~= nil or (active and eggsOn()) then
				dropEntry(player)
			end
		end)
	else
		warnThrottled("factionChanged", "FactionService.FactionChanged missing; side switches are caught at finish only")
	end
end

function GooseService.Start()
	getGameState()
	nextAt = computeNextAt(Util.Now(), nil)
	setGame("GooseNextAt", nextAt)
	setGame("GooseActive", false)
	setGame("GooseEndsAt", 0)
	publishMode()
	publishTotals(true)
	-- A23-131: a crashed earlier run may have left eggs / slowed players: clean at start too
	if GooseEggs then pcall(GooseEggs.Cleanup) end
	-- A23-141: the square (the place's model, or the plain stand-in built now) and its remote
	if squareOn() then
		local okE, errE = pcall(GooseSquare.Ensure)
		if not okE then warnThrottled("squareEnsure", "Goose Square failed: " .. tostring(errE)) end
	end
	if GooseSquare then
		local remote = type(Config.Goose.Square) == "table" and Config.Goose.Square.Remote or "GooseSquare"
		local okR, errR = pcall(function()
			Net.Get(remote).OnServerEvent:Connect(function(player, ...)
				if squareOn() then GooseSquare.OnRemote(player, ...) end
			end)
		end)
		if not okR then warnThrottled("squareRemote", "GooseSquare remote missing: " .. tostring(errR)) end
	end
	setGame("GooseOvertimeUntil", 0)

	task.spawn(function()
		while true do
			task.wait(eggsOn() and (tonumber(EGG.Tick) or 0.1) or Config.Goose.Tick)
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

-- CR-L21: includes the tug pivot (sideOffset, +-MAX_SIDE_OFFSET) so swing range checks match the goose players see
-- Eggs mode: nil (the goose is no swing target any more; CombatService's goose stage is Tug-only)
function GooseService.GetPosition()
	if not active or eggsOn() then return nil end
	return gooseCenter() + Vector3.new(sideOffset, 0, 0)
end

-- A23-131: a carrier's eggs go back now (ZoneService pads / Travel / any server teleport). Safe any time
-- A23-141: Travel / a pad / any other teleport: out of the square first (no move back: the caller moves them), then
-- the carried eggs (the old ring) go back
function GooseService.LeaveSquare(player, reason)
	if GooseSquare then pcall(GooseSquare.Leave, player, reason or "Travel") end
	if active and eggsOn() then pcall(GooseEggs.ReturnEggs, player, reason or "Travel") end
end

function GooseService.InSquare(player)
	return GooseSquare ~= nil and GooseSquare.IsIn(player)
end

function GooseService.ReturnEggs(player, reason)
	if active and eggsOn() then GooseEggs.ReturnEggs(player, reason or "Travel") end
end

-- returns the tug count actually added (0 = rejected), so CombatService can show the real "+N" (CR-L21)
function GooseService.RegisterHit(player, isManual)
	if not active or eggsOn() then return 0 end -- A23-131: hitting the goose does nothing in the egg hunt
	if not isReady(player) then return 0 end
	local f = factionOf(player)
	if not isTugFaction(f) then return 0 end -- A6: Neutral swings on the goose count 0
	if mode == "Pending" then fixMode() end -- first eligible hit before the next tick fixed the mode
	if mode == "Coop" and f ~= coop.Side then
		-- A23-14: the rival side arrived after this goose became co-op -> no pull this time, told once per event
		if not coop.Told[player] then
			coop.Told[player] = true
			local msg = txt("RivalWait", coop.Side)
			if msg then pcall(Net.Notify, player, msg, "info") end
		end
		return 0
	end
	if sideOf[player] ~= nil and sideOf[player] ~= f then
		dropEntry(player) -- defensive: faction changed without a FactionChanged signal -> fresh entry for the new side
	end

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
	if #list >= Config.Goose.MaxCountsPerSecond then return 0 end
	table.insert(list, now)

	local scale = tonumber(call("JusticeService", "GetFactionScale", f)) or 1
	if scale ~= scale or scale <= 0 then scale = 1 end
	local amount = ((isManual == true) and Config.Goose.ManualCount or Config.Goose.AutoCount) * scale
	counts[player] = (counts[player] or 0) + amount
	sideOf[player] = f
	if isManual == true then
		manualHits[player] = (manualHits[player] or 0) + 1
	end
	if f == "Halo" then
		rescue += amount
	else
		poach += amount
	end
	player:SetAttribute("GooseCount", math.floor(counts[player]))
	return amount
end

function GooseService.DebugStart()
	if active then return end
	local ok, err = pcall(start)
	if not ok then warnThrottled("debug", "DebugStart failed: " .. tostring(err)) end
end

return GooseService
