-- WarService.luau : crown war meter ("왕관 쟁탈전") — 10-minute rounds, faction points, blessing, sky color, war chests.
--
-- Story: each round decides which side "holds the crown"; the sky turns the crown's color (Dawn gold / Eclipse blood).
-- Only Halo and Horns take part (addendum A6): Neutral and None never earn war points, never get a chest and never
-- hold the blessing; per-capita scores use FactionService.GetCounts (Halo vs Horns only).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local WarService = {}

local TAG = "WarService"
local WAR_FACTIONS = { Halo = true, Horns = true }
local WARN_INTERVAL = 10

-- docs/ART_DIRECTION.md 3.1: fixed lighting applied once in Start (this service owns Lighting; no Atmosphere, A9-3).
-- Values match the A11 Elden-Ring mood baked by tools/preview_map.lua (ShadowSoftness 0.2, Bloom 24/1.4, rays spread 0.4)
-- so the server start does not change the look the creator approved in Studio.
local LIGHTING_FIXED = {
	GlobalShadows = true, ShadowSoftness = 0.2, GeographicLatitude = 35,
	EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 0.3,
}
local TINT_FIXED = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.2 } -- only TintColor is tweened
local SKY_FIXED = { SunAngularSize = 14, MoonAngularSize = 18, StarCount = 3000 }
local BLOOM_FIXED = { Size = 24, Threshold = 1.4 }
local SUNRAYS_FIXED = { Spread = 0.4 }
-- ART_DIRECTION 3.2 per-sky values used only where Config.Sky[name] has no key of its own (Config.Sky stays the source
-- for everything it carries: FogStart / ExposureCompensation / BloomIntensity are read from the preset first).
-- Neutral = A11 (exposure -0.1, bloom 0.4) + preview sun rays 0.08.
local SKY_EXTRAS = {
	Neutral = { Exposure = -0.1, Bloom = 0.4, SunRays = 0.08, Clouds = Color3.fromRGB(255, 255, 255) },
	Dawn = { Exposure = 0.15, Bloom = 0.6, SunRays = 0.12, Clouds = Color3.fromRGB(255, 225, 190) },
	Eclipse = { Exposure = 0.35, Bloom = 0.7, SunRays = 0, Clouds = Color3.fromRGB(110, 40, 50) }, -- monsters stay visible at night
}

local S = nil
local points = { Halo = 0, Horns = 0 } -- faction pools of the current round
local personal = {} -- [Player] = personal points of the current round
local blessing = "None" -- faction holding the crown (decided at each round end, lasts one round)
local roundEndsAt = 0
local warTint = nil
local skyTweens = {}
local lastWarnAt = {}

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarnAt[key]
	if last and now - last < WARN_INTERVAL then return end
	lastWarnAt[key] = now
	Util.Warn(TAG, msg)
end

local function isPlayer(x)
	return typeof(x) == "Instance" and x:IsA("Player")
end

local function getFaction(player)
	if S and S.FactionService then
		local ok, f = pcall(S.FactionService.GetFaction, player)
		if ok and type(f) == "string" then return f end
	end
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function isValidAmount(n)
	return type(n) == "number" and n == n and n > 0 and n < math.huge
end

local function round1(x)
	return math.floor(x * 10 + 0.5) / 10
end

local function setPersonal(player, value)
	personal[player] = value
	if player.Parent then
		player:SetAttribute("WarPoints", value)
	end
end

------------------------------------------------------------------ sky
-- sets each property in its own pcall (newer Lighting properties may be missing on older engines)
local function setProps(inst, props)
	for k, v in props do
		local ok, err = pcall(function()
			inst[k] = v
		end)
		if not ok then
			warnThrottled("prop:" .. k, ("could not set %s.%s: %s"):format(inst.ClassName, k, tostring(err)))
		end
	end
end

local function findOrCreate(parent, className)
	local inst = parent:FindFirstChildOfClass(className)
	if not inst then
		inst = Instance.new(className)
		inst.Parent = parent
	end
	return inst
end

local function ensureTint()
	if warTint and warTint.Parent == Lighting then return warTint end
	local existing = Lighting:FindFirstChild("WarTint")
	if existing and existing:IsA("ColorCorrectionEffect") then
		warTint = existing
	else
		if existing then
			existing.Name = "WarTint_Old" -- something else took the contract name; keep it, but out of the way
		end
		warTint = Instance.new("ColorCorrectionEffect")
		warTint.Name = "WarTint"
		setProps(warTint, TINT_FIXED)
		warTint.Parent = Lighting
	end
	return warTint
end

-- ART_DIRECTION 3.1, once in Start
local function bootstrapLighting()
	pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Soft
	end)
	pcall(function()
		Lighting.PrioritizeLightingQuality = true
	end)
	setProps(Lighting, LIGHTING_FIXED)
	setProps(ensureTint(), TINT_FIXED)
	setProps(findOrCreate(Lighting, "Sky"), SKY_FIXED)
	setProps(findOrCreate(Lighting, "BloomEffect"), BLOOM_FIXED)
	setProps(findOrCreate(Lighting, "SunRaysEffect"), SUNRAYS_FIXED)
	if Lighting:FindFirstChildOfClass("Atmosphere") then
		Util.Warn(TAG, "Lighting has an Atmosphere: it hides the FogColor/FogEnd war sky (addendum A9-3). Remove it.")
	end
end

local function skyNameFor(winner)
	if winner == "Halo" then return "Dawn" end
	if winner == "Horns" then return "Eclipse" end
	return "Neutral"
end

local function num(v)
	return (type(v) == "number" and v == v) and v or nil
end

-- applies Config.Sky[name] to Lighting + WarTint (FogStart / ExposureCompensation / BloomIntensity when the preset has
-- them, addendum A9-4/A11/A12), plus the ART_DIRECTION extras for whatever the preset does not carry
local function applySky(name, animate)
	local preset = Config.Sky[name]
	if type(preset) ~= "table" then return end
	local extras = SKY_EXTRAS[name] or SKY_EXTRAS.Neutral
	for _, t in skyTweens do
		t:Cancel()
	end
	table.clear(skyTweens)

	local lightingGoal = {
		ClockTime = preset.ClockTime, Brightness = preset.Brightness, Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient, FogColor = preset.FogColor, FogEnd = preset.FogEnd,
		FogStart = num(preset.FogStart), -- nil (left as is) when the preset has none
		ExposureCompensation = num(preset.ExposureCompensation) or extras.Exposure,
	}
	local fogStart, fogEnd = lightingGoal.FogStart, num(preset.FogEnd)
	if fogStart and fogEnd and fogStart >= fogEnd then
		lightingGoal.FogStart = math.max(0, fogEnd - 1) -- FogStart must stay below FogEnd
	end
	local goals = { { Lighting, lightingGoal } }
	if preset.Tint then
		table.insert(goals, { ensureTint(), { TintColor = preset.Tint } })
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then table.insert(goals, { bloom, { Intensity = num(preset.BloomIntensity) or extras.Bloom } }) end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then table.insert(goals, { rays, { Intensity = extras.SunRays } }) end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then table.insert(goals, { clouds, { Color = extras.Clouds } }) end

	if animate then
		local info = TweenInfo.new(Config.Sky.TweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for _, g in goals do
			local ok, tweenOrErr = pcall(TweenService.Create, TweenService, g[1], info, g[2])
			if ok then
				table.insert(skyTweens, tweenOrErr)
				tweenOrErr:Play()
			else
				warnThrottled("tween", "sky tween failed: " .. tostring(tweenOrErr))
				setProps(g[1], g[2])
			end
		end
	else
		for _, g in goals do
			setProps(g[1], g[2])
		end
	end
end

------------------------------------------------------------------ round state
local function getCounts()
	if not (S and S.FactionService) then return 0, 0 end
	local ok, halo, horns = pcall(S.FactionService.GetCounts)
	if not ok then
		warnThrottled("counts", "GetCounts failed: " .. tostring(halo))
		return 0, 0
	end
	return tonumber(halo) or 0, tonumber(horns) or 0
end

local function modeFor(halo, horns)
	if halo == 0 and horns == 0 then return "Idle" end
	if halo == 0 or horns == 0 then return "Siege" end
	return "Normal"
end

-- writes the per-capita scores, mode and round end to GameState; returns (haloScore, hornsScore, mode)
local function publish(halo, horns)
	local haloScore = points.Halo / math.max(1, halo)
	local hornsScore = points.Horns / math.max(1, horns)
	local mode = modeFor(halo, horns)
	local gs = Net.GameState()
	gs:SetAttribute("WarHaloScore", round1(haloScore))
	gs:SetAttribute("WarHornsScore", round1(hornsScore))
	gs:SetAttribute("WarRoundEndsAt", roundEndsAt)
	gs:SetAttribute("WarMode", mode)
	return haloScore, hornsScore, mode
end

local function decideWinner(mode, haloScore, hornsScore, halo, horns)
	if mode == "Normal" then
		if haloScore > hornsScore then return "Halo" end
		if hornsScore > haloScore then return "Horns" end
		return "None"
	elseif mode == "Siege" then
		local present = (halo > 0) and "Halo" or "Horns"
		local score = (present == "Halo") and haloScore or hornsScore
		if score >= Config.War.SiegeTarget then return present end
		return "None"
	end
	return "None" -- Idle
end

local function payChests(winner, snapshot)
	for _, player in S.PlayerService.GetReadyPlayers() do
		local ok, err = pcall(function()
			local f = getFaction(player)
			if not WAR_FACTIONS[f] then return end
			if (snapshot[player] or 0) < Config.War.ChestMinPoints then return end
			local level = tonumber(player:GetAttribute("Level")) or 1
			local perLevel = (winner ~= "None" and f == winner) and Config.War.WinnerChestPerLevel or Config.War.LoserChestPerLevel
			local amount = math.floor(level * perLevel)
			if amount <= 0 then return end
			S.ProgressionService.AddBankGold(player, amount, "War")
			Net.Notify(player, string.format(Config.Text.WarChest, Util.FormatNumber(amount)), "reward")
		end)
		if not ok then
			warnThrottled("chest", "war chest error: " .. tostring(err))
		end
	end
end

local function endRound(mode, haloScore, hornsScore, halo, horns)
	-- advance + reset first so a failure below can never re-trigger the same round end every tick
	local snapshot = table.clone(personal)
	roundEndsAt = Util.Now() + Config.War.RoundSeconds
	points.Halo = 0
	points.Horns = 0
	for player in snapshot do
		setPersonal(player, 0)
	end

	local winner = decideWinner(mode, haloScore, hornsScore, halo, horns)
	blessing = winner
	Net.GameState():SetAttribute("WarBlessing", winner)
	applySky(skyNameFor(winner), true)

	payChests(winner, snapshot)

	if mode ~= "Idle" then
		if winner ~= "None" and Config.Story.WarWin[winner] then
			Net.NotifyAll(string.format(Config.Story.WarWin[winner]))
		else
			Net.NotifyAll(string.format(Config.Story.WarDraw))
		end
	end

	publish(halo, horns)
end

local function tick()
	local halo, horns = getCounts()
	local haloScore, hornsScore, mode = publish(halo, horns)
	if Util.Now() >= roundEndsAt then
		endRound(mode, haloScore, hornsScore, halo, horns)
	end
end

------------------------------------------------------------------ public API
-- personal + faction pool (monster kills, rewarded PvP KOs)
function WarService.AddPoints(player, n)
	if not isPlayer(player) or not isValidAmount(n) then return end
	if not (S and S.PlayerService.IsReady(player)) then return end
	local f = getFaction(player)
	if not WAR_FACTIONS[f] then return end -- None / Neutral never earn war points
	points[f] += n
	setPersonal(player, (personal[player] or 0) + n)
end

-- faction pool only (events: goose, kaiju)
function WarService.AddFactionPoints(factionId, n)
	if not WAR_FACTIONS[factionId] or not isValidAmount(n) then return end
	points[factionId] += n
end

-- blessing faction == player's faction (Halo/Horns only)
function WarService.HasBlessing(player)
	if not isPlayer(player) or blessing == "None" then return false end
	local f = getFaction(player)
	return WAR_FACTIONS[f] == true and f == blessing
end

function WarService.GetBlessingFaction()
	return blessing
end

function WarService.GetPersonalPoints(player)
	return personal[player] or 0
end

-- server time of the current round end; valid after Start
function WarService.GetRoundEndsAt()
	if roundEndsAt <= 0 then
		return Util.Now() + Config.War.RoundSeconds
	end
	return roundEndsAt
end

------------------------------------------------------------------ lifecycle
function WarService.Init(registry)
	S = registry
	ensureTint()

	if S.MonsterService and S.MonsterService.MonsterKilled then
		S.MonsterService.MonsterKilled:Connect(function(player, info)
			if type(info) == "table" then
				WarService.AddPoints(player, info.WarPoints)
			end
		end)
	else
		Util.Warn(TAG, "MonsterService.MonsterKilled missing; monster kills give no war points")
	end

	if S.PvPService and S.PvPService.PlayerKO then
		S.PvPService.PlayerKO:Connect(function(killer, _victim, info)
			if type(info) == "table" and info.Rewarded == true then
				local stars = tonumber(info.VictimStars) or 0
				WarService.AddPoints(killer, Config.War.PvPKOPoints + Config.War.PvPKOPerStar * stars)
			end
		end)
	else
		Util.Warn(TAG, "PvPService.PlayerKO missing; PvP KOs give no war points")
	end

	if S.FactionService and S.FactionService.FactionChanged then
		S.FactionService.FactionChanged:Connect(function(player)
			if isPlayer(player) then setPersonal(player, 0) end
		end)
	end

	S.PlayerService.PlayerReady:Connect(function(player)
		setPersonal(player, 0)
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		personal[player] = nil
	end)
end

function WarService.Start()
	bootstrapLighting()
	applySky("Neutral", false)
	roundEndsAt = Util.Now() + Config.War.RoundSeconds
	Net.GameState():SetAttribute("WarBlessing", blessing)
	local halo, horns = getCounts()
	publish(halo, horns)

	task.spawn(function()
		while true do
			task.wait(Config.War.Tick)
			local ok, err = pcall(tick)
			if not ok then
				warnThrottled("tick", "tick error: " .. tostring(err))
			end
		end
	end)

	print("[WarService] started")
end

return WarService
