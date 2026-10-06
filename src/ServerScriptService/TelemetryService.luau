-- TelemetryService.luau : P6 (mmorpg_painpoints §2) Roblox AnalyticsService funnel / custom events, no personal data
-- (no names, no chat; AnalyticsService ties events to the player by itself). Read-only observer: it only listens to
-- existing signals / attributes and never changes game state. Every call is pcall'd and throttled; a missing
-- AnalyticsService (Studio, old engine) costs nothing.
--   Onboarding funnel (each step once per player, in any order; saved in data.Telemetry.Steps = { [n] = true }): 1 Joined, 2 OpeningDone, 3 FactionChosen,
--     4 ClassChosen, 5 FirstMissionAccepted, 6 FirstMissionDone, 7 FirstWeaponOwned, 8 AutoCombatUnlocked
--   Custom events: FirstDeath (cause Monster/PvP), AutoToggle (1/0), SackOutcome (Paid/Avenged/Returned),
--     SessionMinutes (+ bucket), LeftAfterEnhanceDrop, RookieFirstKillSeconds (meadow entry -> first kill),
--     HighLevelInMeadow, ServerPopulation (+ Halo/Horns counts), CrownTrialMiss (reason)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local TelemetryService = {}
local S = nil
local T = {
	Analytics = nil,
	JoinedAt = {}, -- [Player] = os.clock()
	MeadowAt = {}, -- [Player] = os.clock() of the first SlimeMeadow entry this session (rookies only)
	EnhanceDropAt = {}, -- [Player] = os.clock() of the last enhance failure that lost a level
	Throttle = {}, -- ["<userId>:<key>"] = os.clock()
	Conns = {}, -- [Player] = { RBXScriptConnection } (attribute watchers, dropped on leave)
	Steps = { "Joined", "OpeningDone", "FactionChosen", "ClassChosen", "FirstMissionAccepted", "FirstMissionDone",
		"FirstWeaponOwned", "AutoCombatUnlocked" },
}

local function analytics()
	if T.Analytics == nil then
		local ok, svc = pcall(game.GetService, game, "AnalyticsService")
		T.Analytics = ok and svc or false
	end
	return T.Analytics or nil
end

local function fields(a, b, c)
	local f = {}
	local keys = Enum.AnalyticsCustomFieldKeys
	if a ~= nil then f[keys.CustomField01.Name] = tostring(a) end
	if b ~= nil then f[keys.CustomField02.Name] = tostring(b) end
	if c ~= nil then f[keys.CustomField03.Name] = tostring(c) end
	return f
end

local function throttled(player, key, seconds)
	local k = tostring(player.UserId) .. ":" .. key
	local now = os.clock()
	if T.Throttle[k] and now - T.Throttle[k] < seconds then return true end
	T.Throttle[k] = now
	return false
end

-- review: no Parent check — leave-time events (session length, sack returned) fire while the Player is being removed
function TelemetryService.Custom(player, name, value, a, b, c)
	local svc = analytics()
	if not svc or typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	pcall(svc.LogCustomEvent, svc, player, name, tonumber(value) or 1, fields(a, b, c))
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

-- onboarding funnel step: each step at most once per player, whatever order they happen in (S0 can finish before the
-- first mission; review of 5493770). The first build saved only the highest step (Onb = n): read as steps 1..n.
function TelemetryService.Step(player, step)
	local data = getData(player)
	if not data then return end
	if type(data.Telemetry) ~= "table" then data.Telemetry = {} end
	local tel = data.Telemetry
	if type(tel.Steps) ~= "table" then
		tel.Steps = {}
		for n = 1, math.clamp(math.floor(tonumber(tel.Onb) or 0), 0, #T.Steps) do tel.Steps[tostring(n)] = true end
		tel.Onb = nil
	end
	if tel.Steps[tostring(step)] then return end
	tel.Steps[tostring(step)] = true
	local svc = analytics()
	if not svc then return end
	pcall(svc.LogOnboardingFunnelStepEvent, svc, player, step, T.Steps[step] or tostring(step))
end

local function watch(player, attr, fn)
	T.Conns[player] = T.Conns[player] or {}
	table.insert(T.Conns[player], player:GetAttributeChangedSignal(attr):Connect(function()
		local ok, err = pcall(fn, player:GetAttribute(attr))
		if not ok then Util.Warn("TelemetryService", attr .. ": " .. tostring(err)) end
	end))
end

local function onReady(player, data)
	T.JoinedAt[player] = os.clock()
	TelemetryService.Step(player, 1)
	-- catch up the steps a returning player already passed (never logs the same step twice)
	if data.IntroSeen == true then TelemetryService.Step(player, 2) end
	if data.Faction ~= "None" then TelemetryService.Step(player, 3) end
	if data.ClassChosen == true then TelemetryService.Step(player, 4) end
	local tut = tonumber(data.TutorialStep) or 0
	if tut >= 1 then TelemetryService.Step(player, 5) end
	if tut == 99 then TelemetryService.Step(player, 6) end
	if (tonumber(data.WeaponOwnedMask) or 1) > 1 then TelemetryService.Step(player, 7) end
	if data.AutoCombatUnlocked == true then TelemetryService.Step(player, 8) end
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	T.Conns[player] = nil
	watch(player, "IntroSeen", function(v) if v == true then TelemetryService.Step(player, 2) end end)
	watch(player, "ClassChosen", function(v) if v == true then TelemetryService.Step(player, 4) end end)
	watch(player, "TutorialStep", function(v)
		-- accepting the guide mission sets TutorialStep 1 (2 = arrived in the meadow, 99 = first mission claimed)
		if (tonumber(v) or 0) >= 1 then TelemetryService.Step(player, 5) end
		if v == 99 then TelemetryService.Step(player, 6) end
	end)
	watch(player, "WeaponOwnedMask", function(v)
		if (tonumber(v) or 1) > 1 then TelemetryService.Step(player, 7) end
	end)
	watch(player, "AutoCombatUnlocked", function(v) if v == true then TelemetryService.Step(player, 8) end end)
	watch(player, "AutoCombatEnabled", function(v)
		if not throttled(player, "auto", 10) then TelemetryService.Custom(player, "AutoToggle", v == true and 1 or 0) end
	end)
end

local function onLeaving(player)
	local joined = T.JoinedAt[player]
	if joined then
		local minutes = math.floor((os.clock() - joined) / 60)
		local bucket = minutes < 5 and "0-5" or minutes < 15 and "5-15" or minutes < 30 and "15-30"
			or minutes < 60 and "30-60" or "60+"
		TelemetryService.Custom(player, "SessionMinutes", minutes, bucket)
	end
	local drop = T.EnhanceDropAt[player]
	if drop and os.clock() - drop <= 60 then
		TelemetryService.Custom(player, "LeftAfterEnhanceDrop", math.floor(os.clock() - drop))
	end
	T.JoinedAt[player], T.MeadowAt[player], T.EnhanceDropAt[player] = nil, nil, nil
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	T.Conns[player] = nil
	for k in T.Throttle do
		if string.sub(k, 1, #tostring(player.UserId) + 1) == tostring(player.UserId) .. ":" then T.Throttle[k] = nil end
	end
end

local function connect(service, signal, fn)
	local svc = S[service]
	local sig = svc and svc[signal]
	if type(sig) == "table" and type(sig.Connect) == "function" then
		sig:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn("TelemetryService", service .. "." .. signal .. ": " .. tostring(err)) end
		end)
	end
end

function TelemetryService.Init(registry)
	S = registry
end

function TelemetryService.Start()
	connect("PlayerService", "PlayerReady", onReady)
	connect("PlayerService", "PlayerLeaving", onLeaving)
	connect("FactionService", "FactionChanged", function(player, newFaction)
		if newFaction and newFaction ~= "None" then TelemetryService.Step(player, 3) end
	end)
	connect("PlayerService", "CharacterDied", function(player)
		local data = getData(player)
		if not data then return end
		if type(data.Telemetry) ~= "table" then data.Telemetry = {} end
		if data.Telemetry.FirstDeath then return end
		data.Telemetry.FirstDeath = true
		-- PvP = a player hit me within the combat tag; Monster = any damage in the last 3 s (DamagePlayer); else a fall,
		-- a reset or the void ("Other"). BB14 will provide the real By.
		local cause = "Other"
		local ok, attacker = pcall(S.CombatService.GetLastPvPAttacker, player)
		local okHit, hitAt = pcall(S.CombatService.GetLastDamagedAt, player)
		if ok and typeof(attacker) == "Instance" then
			cause = "PvP"
		elseif okHit and os.clock() - (tonumber(hitAt) or 0) <= 3 then
			cause = "Monster"
		end
		TelemetryService.Custom(player, "FirstDeath", 1, cause, player:GetAttribute("ZoneId"))
	end)
	connect("GrudgeService", "SackResolved", function(thief, outcome, total)
		TelemetryService.Custom(thief, "SackOutcome", tonumber(total) or 0, outcome)
	end)
	connect("LootService", "Enhanced", function(player, _tier, before, after)
		if tonumber(after) and tonumber(before) and after < before then T.EnhanceDropAt[player] = os.clock() end
	end)
	connect("ZoneService", "ZoneChanged", function(player, newZone)
		if newZone == "SlimeMeadow" and T.MeadowAt[player] == nil and (tonumber(player:GetAttribute("Level")) or 1) < 10 then
			T.MeadowAt[player] = os.clock()
		end
	end)
	connect("MonsterService", "MonsterKilled", function(player, info)
		local at = T.MeadowAt[player]
		if at and at > 0 then
			T.MeadowAt[player] = -1 -- once per session
			TelemetryService.Custom(player, "RookieFirstKillSeconds", math.floor(os.clock() - at), info and info.Kind)
		end
		-- the crown-shard trial "3 slimes with basic attacks only" (S0 step 2) did not count this slime: a skill hit it
		local data = getData(player)
		local st = data and data.Story
		local s0 = type(st) == "table" and type(st.Subs) == "table" and st.Subs.S0
		-- only while trial "a" (basic-attack slimes) is still open; a skill kill during trial "b" is expected
		local trialA = 3
		pcall(function() trialA = Config.StoryQuests.Defs.S0.Steps[2].Obj.List[1].Count end)
		local doneA = type(s0) == "table" and type(s0.T) == "table" and tonumber(s0.T.a) or 0
		if type(s0) == "table" and s0.St == 2 and doneA < trialA and type(info) == "table"
			and Config.QuestKind(info.Kind) == "Slime" -- review C-9: a pumpkin slime counts as a slime there too
			and info.SkillHit == true and not throttled(player, "trialmiss", 300) then
			TelemetryService.Custom(player, "CrownTrialMiss", 1, "SkillHit", info.Kind)
		end
	end)
	-- every 5 minutes: high levels farming the meadow, and the server's population / faction balance
	task.spawn(function()
		while true do
			task.wait(300)
			local ok, err = pcall(function()
				local ready = S.PlayerService.GetReadyPlayers()
				local halo, horns = 0, 0
				for _, p in ready do
					local f = p:GetAttribute("Faction")
					if f == "Halo" then halo += 1 elseif f == "Horns" then horns += 1 end
					if p:GetAttribute("ZoneId") == "SlimeMeadow" and (tonumber(p:GetAttribute("Level")) or 1) >= 20 then
						TelemetryService.Custom(p, "HighLevelInMeadow", tonumber(p:GetAttribute("Level")) or 0)
					end
				end
				if ready[1] then TelemetryService.Custom(ready[1], "ServerPopulation", #ready, halo, horns) end
			end)
			if not ok then Util.Warn("TelemetryService", "population: " .. tostring(err)) end
		end
	end)
	print("[TelemetryService] started")
end

return TelemetryService
