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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "GooseService"
local GOOSE_LABEL = "황금 거위" -- billboard text required verbatim by TECH_SPEC §4.16
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

local S = nil
local gameState = nil

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
	local per = tonumber(Config.Goose.CoopPerPerson) or 20
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
-- event (no mid-event flips). announce = NotifyAll the co-op start line when this call made it co-op.
local function fixMode(announce)
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
	if mode == "Coop" and announce then
		local msg = txt("CoopStart", coop.Side)
		if msg then pcall(Net.NotifyAll, msg) end
	end
end

local function start()
	if active then return end
	active = true
	endsAt = Util.Now() + Config.Goose.Duration
	rescue, poach = 0, 0
	counts = {}
	manualHits = {}
	sideOf = {}
	hitTimes = {}
	-- A23-14: mode first, so the HUD never shows an active goose with the previous event's mode
	mode = "Pending"
	coop = { Side = "None", People = 0, Target = 0, Full = false, Told = {} }
	fixMode(false)
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
	local startMsg = (mode == "Coop") and txt("CoopStart", coop.Side) or nil
	Net.NotifyAll(startMsg or string.format(Config.Story.GooseStart))
end

-- forget a player's entry for this event; what they already pulled stays in the side totals (like a leaver)
local function dropEntry(p)
	counts[p] = nil
	manualHits[p] = nil
	sideOf[p] = nil
	hitTimes[p] = nil
	if isPlayer(p) and p.Parent then
		p:SetAttribute("GooseCount", 0)
	end
end

-- f = the side the player's counts were made for, re-verified against the current faction by finish()
-- share = A23-14 co-op success multiplier (Config.Goose.CoopWinShare) or nil for the normal won/lost split
local function rewardPlayer(p, result, f, share)
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
	if gold > 0 then call("ProgressionService", "AddBankGold", p, gold, "Event") end
	if xp > 0 then call("ProgressionService", "AddXP", p, xp) end
	local msg = (share ~= nil) and txt("CoopReward", f, Util.FormatNumber(gold), Util.FormatNumber(xp)) or nil
	Net.Notify(p, msg or string.format(Config.Text.GooseReward, Util.FormatNumber(gold), Util.FormatNumber(xp)), "reward")

	if rare then
		Net.Fx(p, "Rare", { Gold = gold, XP = xp })
		Net.NotifyAll(string.format(Config.Text.RareAnnounce, Util.PlayerDisplayName(p)), "info")
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
					local ok, err = pcall(rewardPlayer, p, result, f, share)
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
	local okSend, sendErr = pcall(function()
		local msg = nil
		if judged == "Coop" and isTugFaction(side) then
			msg = success and txt("CoopResult", side) or txt("CoopFail")
			if msg and rivalLeft then msg = txt("RivalLeft", nil, msg) or msg end
		end
		Net.NotifyAll(msg or string.format(Config.Story.GooseResult[result]))
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
	if not active then
		if now >= nextAt then start() end
		return
	end
	if now >= endsAt then
		finish()
		return
	end
	if mode == "Pending" then fixMode(true) end -- e.g. the only player just picked a faction
	if mode == "Coop" then
		-- co-op: the goose slides toward the co-op side as the gauge fills (Halo = -X like a rescue lead)
		local fill = math.clamp(sideTotal(coop.Side) / math.max(1, coop.Target), 0, 1)
		sideTarget = ((coop.Side == "Halo") and -1 or 1) * fill * MAX_SIDE_OFFSET
		if not coop.Full and fill >= 1 then
			coop.Full = true -- totals never go down, so a full gauge stays a success until the timer ends
			local msg = txt("CoopFull", coop.Side, MIN_MANUAL_HITS)
			if msg then pcall(Net.NotifyAll, msg, "good") end
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
	end)
	-- review fix: switching sides mid-event (altar is next to the perch) forfeits this event's entry, so nobody can pull
	-- for one side and then collect the winner share of the other. Pulling again after the switch starts a new entry.
	local fs = S.FactionService
	if fs and fs.FactionChanged then
		fs.FactionChanged:Connect(function(player)
			if counts[player] ~= nil or hitTimes[player] ~= nil then
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

-- CR-L21: includes the tug pivot (sideOffset, +-MAX_SIDE_OFFSET) so swing range checks match the goose players see
function GooseService.GetPosition()
	if not active then return nil end
	return gooseCenter() + Vector3.new(sideOffset, 0, 0)
end

-- returns the tug count actually added (0 = rejected), so CombatService can show the real "+N" (CR-L21)
function GooseService.RegisterHit(player, isManual)
	if not active then return 0 end
	if not isReady(player) then return 0 end
	local f = factionOf(player)
	if not isTugFaction(f) then return 0 end -- A6: Neutral swings on the goose count 0
	if mode == "Pending" then fixMode(true) end -- first eligible hit before the next tick fixed the mode
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
