-- WarService.luau : crown war meter ("왕관 쟁탈전") — 10-minute rounds, faction points, blessing, sky color, war chests.
--
-- Story: each round decides which side "holds the crown"; the sky turns the crown's color (Dawn gold / Eclipse blood).
-- Only Halo and Horns take part (addendum A6): Neutral and None never earn war points, never get a chest and never
-- hold the blessing; per-capita scores use FactionService.GetCounts (Halo vs Horns only), averaged over the round
-- (CR-M19). One monster kill adds its WarPoints to the faction pool once, split between contributors (CR-M18).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local WarService = {}
-- A23-79 (게임성 개발 3): a round ended: (winner, mode, { [Player] = round points }) - ReturnService's pause card
WarService.RoundEnded = Util.Signal.new()

local TAG = "WarService"
local WAR_FACTIONS = { Halo = true, Horns = true }
local WARN_INTERVAL = 10

-- docs/ART_DIRECTION.md 3.1: fixed lighting applied once in Start (this service owns Lighting; no Atmosphere, A9-3).
-- A23-29/30 (user pick 'E' = 'B' bright toy light + the new ground tiles, docs/design/world_blend_2026-10-06.md):
-- sky light reaches the monsters (EnvironmentDiffuse 1.0, Specular 0.6, ShadowSoftness 0.5), softer bloom and tint.
-- tools/preview_map.lua bakes the same Neutral values so Edit and the server start look alike.
-- 2026-10-08 (user: "입체적이지 않아", 검수 depth pass): sharper sun shadows (ShadowSoftness 0.15), half the sky's flat
-- diffuse fill so the shadow side reads, contrast +0.12 and saturation -0.05 (the neon green calmer).
-- Lighting.LightingStyle and Lighting.Technology are PLACE settings, set in Studio Edit and saved with the place; a script
-- cannot change them in a running game (A23-105, 메인 반영 1 2026-10-10: the old Realistic write here failed silently in
-- its pcall and Play kept Soft; Realistic itself broke Play visually, white screen). The place is Soft, the source of
-- truth, so this service never writes either; the Edit toggle Realistic -> Soft is what brought the sun shadows back.
local LIGHTING_FIXED = {
	GlobalShadows = true, ShadowSoftness = 0.15, GeographicLatitude = 35,
	EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.6,
}
local TINT_FIXED = { Brightness = 0, Contrast = 0.12, Saturation = -0.05 } -- only TintColor is tweened
local SKY_FIXED = { SunAngularSize = 14, MoonAngularSize = 18, StarCount = 3000 }
local BLOOM_FIXED = { Size = 24, Threshold = 2.2 }
-- A23-74 (검수 2026-10-07): no sun rays at all - rays fanning out of the sun break the no-ray-burst rule
local SUNRAYS_FIXED = { Spread = 0.4, Intensity = 0, Enabled = false }
-- ART_DIRECTION 3.2 per-sky values used only where Config.Sky[name] has no key of its own (Config.Sky stays the source
-- for everything it carries: FogStart / ExposureCompensation / BloomIntensity are read from the preset first).
-- Exposures = the client ZoneLook base light (SKY table there) so a war-sky change never flickers between the two.
local SKY_EXTRAS = {
	Neutral = { Exposure = -0.25, Bloom = 0.2, SunRays = 0, Clouds = Color3.fromRGB(255, 255, 255) },
	Dawn = { Exposure = -0.35, Bloom = 0.6, SunRays = 0, Clouds = Color3.fromRGB(255, 225, 190) },
	Eclipse = { Exposure = 0.35, Bloom = 0.5, SunRays = 0, Clouds = Color3.fromRGB(110, 40, 50) }, -- monsters stay visible at night
}

local S = nil
local points = { Halo = 0, Horns = 0 } -- faction pools of the current round
local personal = {} -- [Player] = personal points of the current round
local blessing = "None" -- faction holding the crown (decided at each round end, lasts one round)
local roundEndsAt = 0
local warTint = nil
local skyTweens = {}
local lastWarnAt = {}
-- CR-M19: head counts summed every tick of the current round; the per-capita divisor is the round AVERAGE, so a
-- last-second exodus cannot flip the result
local presence = { Halo = 0, Horns = 0, Ticks = 0 }
-- CR-L20: ClockTime is tweened through this NumberValue (forward, wrapping at 24; A23-105: at most ClockForwardMax h) -
-- only while no day cycle runs (a running DayCycleService owns the clock under every sky)
local clock = { Value = nil, Conn = nil }

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
		Lighting.PrioritizeLightingQuality = true
	end)
	setProps(Lighting, LIGHTING_FIXED)
	setProps(ensureTint(), TINT_FIXED)
	local sky = findOrCreate(Lighting, "Sky")
	setProps(sky, SKY_FIXED)
	-- the painted day sky's six faces (Config.Sky.Faces, 이미지 생성 1); a face left empty keeps what the place has. Only
	-- here: the war skies (applySky) change light, fog and tint, never these faces
	local faces = type(Config.Sky.Faces) == "table" and Config.Sky.Faces or {}
	for _, side in { "Ft", "Bk", "Lf", "Rt", "Up", "Dn" } do
		local id = faces[side]
		if type(id) == "string" and id ~= "" then setProps(sky, { ["Skybox" .. side] = id }) end
	end
	setProps(findOrCreate(Lighting, "BloomEffect"), BLOOM_FIXED)
	setProps(findOrCreate(Lighting, "SunRaysEffect"), SUNRAYS_FIXED)
	if Lighting:FindFirstChildOfClass("Atmosphere") then
		Util.Warn(TAG, "Lighting has an Atmosphere: it hides the FogColor/FogEnd war sky (addendum A9-3). Remove it.")
	end
end

-- A23-105: DayCycleService, once it runs (Owns(): Config.DayCycle.Enabled and its Start done), owns Lighting.ClockTime
-- under EVERY sky (검수 2026-10-10, the user's choice (b): the clock keeps turning through a crown-war sky, the sun and the
-- shadows move) and the Neutral sky's look - Brightness, Ambient, OutdoorAmbient, ExposureCompensation, FogColor /
-- FogStart / FogEnd - which it turns through the day. A war sky (Dawn / Eclipse) covers only the look (Cover: this
-- service still tweens its light values, tint, bloom, rays and cloud colour, never the clock); going back to Neutral
-- hands the look back (Uncover, the same tween time: the cycle eases from the war look to the look of the time of day
-- it is then). nil = no running cycle (off, not started yet - this Start runs first - or its Start failed): this
-- service applies every sky itself, preset clocks included (the fixed afternoon, as before).
local function dayCycle()
	local dc = S and S.DayCycleService
	if type(dc) ~= "table" or type(dc.Owns) ~= "function" then return nil end
	local ok, owns = pcall(dc.Owns)
	return (ok and owns == true) and dc or nil
end

local function skyNameFor(winner)
	if winner == "Halo" then return "Dawn" end
	if winner == "Horns" then return "Eclipse" end
	return "Neutral"
end

local function num(v)
	return (type(v) == "number" and v == v) and v or nil
end

-- CR-L20: a tween of ClockTime toward `target` that runs FORWARD (to < from -> to + 24, written back as v % 24); a plain
-- number tween ran the sun backwards (16.8 -> 0.5). Used only while no day cycle runs (applySky). A23-105: more than
-- Config.Sky.ClockForwardMax hours forward (a clock moved off the presets, e.g. 8:00 -> Dawn 7.2 = 23.2 h, a whole day
-- spun in 3 s) goes the short way back instead; 18 keeps every war-sky change between the fixed presets forward exactly
-- as before (the longest, Dawn 7.2 -> Eclipse 0.5, is 17.3 h). nil when there is nothing to tween or it failed.
local function clockTween(target, info)
	local from = Lighting.ClockTime
	local to = target
	if to < from then
		to += 24
	end
	if to - from > (num(Config.Sky.ClockForwardMax) or 18) then
		to -= 24
	end
	if math.abs(to - from) < 1e-3 then return nil end
	if not clock.Value then
		local nv = Instance.new("NumberValue")
		nv.Name = "WarClock"
		clock.Value = nv
		clock.Conn = nv.Changed:Connect(function(v)
			Lighting.ClockTime = v % 24
		end)
	end
	clock.Value.Value = from
	local ok, tweenOrErr = pcall(TweenService.Create, TweenService, clock.Value, info, { Value = to })
	if not ok then
		warnThrottled("clock", "clock tween failed: " .. tostring(tweenOrErr))
		setProps(Lighting, { ClockTime = target })
		return nil
	end
	return tweenOrErr
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
	-- A23-105: a running day cycle owns the clock under every sky; a war sky covers only its look (its light wins),
	-- Neutral's look is the cycle's (handed back below)
	local cycle = dayCycle()
	local cycleLook = cycle ~= nil and name == "Neutral"
	if cycle and not cycleLook then
		local ok, err = pcall(cycle.Cover, name)
		if not ok then warnThrottled("cover", "day cycle cover failed: " .. tostring(err)) end
	end

	-- ClockTime is not in the goal: it is tweened forward on its own (CR-L20), only while no day cycle runs
	local lightingGoal = {
		Brightness = preset.Brightness, Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient, FogColor = preset.FogColor, FogEnd = preset.FogEnd,
		FogStart = num(preset.FogStart), -- nil (left as is) when the preset has none
		ExposureCompensation = num(preset.ExposureCompensation) or extras.Exposure,
	}
	local fogStart, fogEnd = lightingGoal.FogStart, num(preset.FogEnd)
	if fogStart and fogEnd and fogStart >= fogEnd then
		lightingGoal.FogStart = math.max(0, fogEnd - 1) -- FogStart must stay below FogEnd
	end
	local goals = { { Lighting, lightingGoal } }
	if cycleLook then table.clear(goals) end -- the day cycle has the Neutral sky's look (A23-105)
	if preset.Tint then
		table.insert(goals, { ensureTint(), { TintColor = preset.Tint } })
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then table.insert(goals, { bloom, { Intensity = num(preset.BloomIntensity) or extras.Bloom } }) end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then table.insert(goals, { rays, { Intensity = extras.SunRays } }) end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then table.insert(goals, { clouds, { Color = extras.Clouds } }) end
	local clockTarget = (cycle == nil) and num(preset.ClockTime) or nil -- the preset clocks: only without a running cycle

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
		local clockT = clockTarget and clockTween(clockTarget, info)
		if clockT then
			table.insert(skyTweens, clockT)
			clockT:Play()
		end
	else
		for _, g in goals do
			setProps(g[1], g[2])
		end
		if clockTarget then
			setProps(Lighting, { ClockTime = clockTarget }) -- no animation: set at once (CR-L20)
		end
	end
	if cycleLook then
		local ok, err = pcall(cycle.Uncover, animate and Config.Sky.TweenTime or 0)
		if not ok then warnThrottled("uncover", "day cycle uncover failed: " .. tostring(err)) end
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

-- CR-M19: adds this tick's head counts to the round sums; returns the round-average counts (an average below 0.5 -
-- a side that was barely online this round - counts as 0)
local function averageCounts(halo, horns)
	presence.Halo += halo
	presence.Horns += horns
	presence.Ticks += 1
	local aH = presence.Halo / presence.Ticks
	local aR = presence.Horns / presence.Ticks
	if aH < 0.5 then aH = 0 end
	if aR < 0.5 then aR = 0 end
	return aH, aR
end

local function modeFor(halo, horns)
	if halo == 0 and horns == 0 then return "Idle" end
	if halo == 0 or horns == 0 then return "Siege" end
	return "Normal"
end

-- writes the per-capita scores, mode and round end to GameState; returns (haloScore, hornsScore, mode).
-- halo / horns = head counts (the round averages during a round, CR-M19; may be fractional)
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
			amount = S.ProgressionService.AddBankGold(player, amount, "War") or amount -- A23-75: as added (2x Gold)
			Net.Notify(player, string.format(Config.Text.WarChest, Util.FormatNumber(amount)), "reward", nil, "GoldPickup")
		end)
		if not ok then
			warnThrottled("chest", "war chest error: " .. tostring(err))
		end
	end
end

-- halo / horns = round-average head counts (decide the winner); curHalo / curHorns = counts now (next round's publish)
local function endRound(mode, haloScore, hornsScore, halo, horns, curHalo, curHorns)
	-- advance + reset first so a failure below can never re-trigger the same round end every tick
	local snapshot = table.clone(personal)
	roundEndsAt = Util.Now() + Config.War.RoundSeconds
	points.Halo = 0
	points.Horns = 0
	presence.Halo = 0 -- CR-M19
	presence.Horns = 0
	presence.Ticks = 0
	for player in snapshot do
		setPersonal(player, 0)
	end

	local winner = decideWinner(mode, haloScore, hornsScore, halo, horns)
	blessing = winner
	Net.GameState():SetAttribute("WarBlessing", winner)
	applySky(skyNameFor(winner), true)

	payChests(winner, snapshot)

	if mode ~= "Idle" then
		-- sound_gaps B6: the crown goes to a side = CrownHalo / CrownHorns for everyone (the client holds the war-chest
		-- coins 1.5 s); a draw has no sound
		if winner ~= "None" and Config.Story.WarWin[winner] then
			Net.NotifyAll(string.format(Config.Story.WarWin[winner]), nil, nil, winner == "Halo" and "CrownHalo" or "CrownHorns")
		else
			Net.NotifyAll(string.format(Config.Story.WarDraw), nil, nil, "None")
		end
	end

	publish(curHalo or halo, curHorns or horns) -- new round: no averages yet
	WarService.RoundEnded:Fire(winner, mode, snapshot)
end

-- the live switchboard (SwitchService "CrownWar" off): no points, no rounds
local function warOff()
	local sw = S and S.SwitchService
	return type(sw) == "table" and type(sw.On) == "function" and not sw.On("CrownWar")
end

local function tick()
	local halo, horns = getCounts()
	local aH, aR = averageCounts(halo, horns) -- CR-M19
	local haloScore, hornsScore, mode = publish(aH, aR)
	if warOff() then
		roundEndsAt = Util.Now() + Config.War.RoundSeconds -- the round never ends while the switch is off
		return
	end
	if Util.Now() >= roundEndsAt then
		endRound(mode, haloScore, hornsScore, aH, aR, halo, horns)
	end
end

------------------------------------------------------------------ public API
-- personal + faction pool (monster kills, rewarded PvP KOs). poolN (optional, CR-M18) = this player's share of the
-- pool: one monster killed by k same-faction contributors adds WarPoints / k each (WarShare), so the pool gets
-- WarPoints once while every contributor still gets n personal points. Invalid / missing poolN -> n (capped at n).
function WarService.AddPoints(player, n, poolN)
	if not isPlayer(player) or not isValidAmount(n) or warOff() then return end
	if not (S and S.PlayerService.IsReady(player)) then return end
	local f = getFaction(player)
	if not WAR_FACTIONS[f] then return end -- None / Neutral never earn war points
	points[f] += isValidAmount(poolN) and math.min(poolN, n) or n
	setPersonal(player, (personal[player] or 0) + n)
end

-- faction pool only (events: goose, kaiju)
function WarService.AddFactionPoints(factionId, n)
	if not WAR_FACTIONS[factionId] or not isValidAmount(n) or warOff() then return end
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
				WarService.AddPoints(player, info.WarPoints, info.WarShare) -- CR-M18: pool share per contributor
			end
		end)
	else
		Util.Warn(TAG, "MonsterService.MonsterKilled missing; monster kills give no war points")
	end

	if S.PvPService and S.PvPService.PlayerKO then
		S.PvPService.PlayerKO:Connect(function(killer, _victim, info)
			if type(info) == "table" and info.Rewarded == true then
				local stars = tonumber(info.VictimStars) or 0
				local points = Config.War.PvPKOPoints + Config.War.PvPKOPerStar * stars
				local bold = tonumber(info.BoldMult) -- A23-18 boldness (x2 strong victim / x0.5 weak victim)
				if bold and bold > 0 and bold ~= 1 and S.PvPService.ScalePoints then
					points = S.PvPService.ScalePoints(points, bold)
				end
				if points > 0 then WarService.AddPoints(killer, points) end
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
