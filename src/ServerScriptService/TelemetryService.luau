-- TelemetryService.luau : P6 / BB38 (docs/design/beta_basics_2026-10-05.md BB38, mmorpg_painpoints §2, 검수 2026-10-07:
-- economy + friends, emergent_play_watch §2) Roblox AnalyticsService funnel / custom events, no personal data: no
-- names, UserIds, chat or free text in an event name or field (every name and field comes from a fixed list: Config,
-- zone / monster / window ids). Read-only observer: it only listens to signals / attributes and never changes game
-- state. Every call is pcall'd; a missing AnalyticsService (Studio, old engine) costs nothing. Config.Analytics.Debug
-- (default: Studio) prints every call.
--   Onboarding funnel (each step once per account, any order; data.Telemetry.Funnel = { [name] = true }):
--     Config.Analytics.Steps = IntroDone, Faction, Class, FirstMissionAccept, MeadowArrive, FirstHit, FirstKill,
--     FirstSkillHit, FirstMissionDone, ForgeArrive, FirstWeapon, AutoUnlocked, Level10 (A23-68 #5: the first 3 minutes)
--   Right away: FirstDeath_<By> (BB14 KO cause, once per account), AutoOn / AutoOff, Plunder_Kept / _Avenged /
--     _Returned, KeyRebind (actions changed), WindowOpen_<id> (UiMetric, once per session per window),
--     RookieFirstKillSeconds, HighLevelInMeadow, ServerPopulation, CrownTrialMiss, SameKindStreak, ReturnAct (the first
--     actions of a returning player: a zone entered or a window opened)
--   At leave (per session sums): SessionMinutes, AutoAwayMinutes (auto ON with no own action for AwayAfter s),
--     EnhanceFailLeave (left within EnhanceFailLeave s of a failed enhance), GoldIn / GoldOut (per source / sink),
--     FriendMinutes (a friend on the server), KillsTogether / KillsWithFriend, ZoneMinutes (per zone), RankingViews
--     (per board)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local TelemetryService = {}
local S = nil
local A = Config.Analytics or {}
local T = {
	Analytics = nil,
	Debug = nil,
	Steps = A.Steps or { "IntroDone", "Faction", "Class", "FirstMissionAccept", "MeadowArrive", "FirstHit", "FirstKill",
		"FirstSkillHit", "FirstMissionDone", "ForgeArrive", "FirstWeapon", "AutoUnlocked", "Level10" },
	FirstHit = {}, -- [Player] = true once FirstHit is logged (or passed): later hits skip the funnel lookup
	UiIds = {}, -- [window id] = true (Config.Analytics.UiIds)
	JoinedAt = {}, -- [Player] = os.clock()
	MeadowAt = {}, -- [Player] = os.clock() of the first SlimeMeadow entry this session (rookies only)
	EnhanceFailAt = {}, -- [Player] = os.clock() of the last failed enhance
	Throttle = {}, -- ["<userId>:<key>"] = os.clock()
	Conns = {}, -- [Player] = { RBXScriptConnection } (attribute watchers, dropped on leave)
	Session = {}, -- [Player] = per-session sums and once-flags (see newSession)
	Friend = {}, -- ["<lowId>:<highId>"] = true / false (IsFriendsWith, cached for the server's life)
}
for _, id in A.UiIds or {} do T.UiIds[id] = true end

local function num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v then return default or 0 end
	return v
end

local function analytics()
	if T.Analytics == nil then
		local ok, svc = pcall(game.GetService, game, "AnalyticsService")
		T.Analytics = ok and svc or false
	end
	return T.Analytics or nil
end

local function debugOn()
	if T.Debug == nil then
		if A.Debug ~= nil then
			T.Debug = A.Debug == true
		else
			local ok, studio = pcall(RunService.IsStudio, RunService)
			T.Debug = ok and studio == true
		end
	end
	return T.Debug
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
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	value = tonumber(value) or 1
	if debugOn() then
		print(string.format("[Metrics] %s = %s (%s, %s, %s)", tostring(name), tostring(value), tostring(a), tostring(b),
			tostring(c)))
	end
	local svc = analytics()
	if not svc then return end
	pcall(svc.LogCustomEvent, svc, player, name, value, fields(a, b, c))
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function telemetryOf(data)
	if type(data.Telemetry) ~= "table" then data.Telemetry = {} end
	return data.Telemetry
end

-- onboarding funnel step (a Config.Analytics.Steps name): each step at most once per account, whatever order they
-- happen in. The step number is its place in the list.
function TelemetryService.Step(player, name)
	local index = table.find(T.Steps, name)
	local data = index and getData(player)
	if not data then return end
	local tel = telemetryOf(data)
	if type(tel.Funnel) ~= "table" then tel.Funnel = {} end
	if tel.Funnel[name] then return end
	tel.Funnel[name] = true
	if debugOn() then print(string.format("[Metrics] step %d %s", index, name)) end
	local svc = analytics()
	if not svc then return end
	pcall(svc.LogOnboardingFunnelStepEvent, svc, player, index, name)
end

------------------------------------------------------------------ per-session state
local function newSession(player, data)
	local tel = telemetryOf(data)
	local before = math.floor(num(tel.Sessions))
	tel.Sessions = before + 1
	T.Session[player] = {
		Returning = before >= 1, -- emergent_play_watch §2: the first actions of a player who came back
		Acts = 0,
		Windows = {}, -- [window id] = true (WindowOpen once a session)
		AwayMin = 0,
		GoldIn = {}, -- [source] = gold
		GoldOut = {}, -- [sink] = gold
		FriendMin = 0,
		Together = 0,
		WithFriend = 0,
		ZoneMin = {}, -- [zone id] = minutes
		Rankings = {}, -- [board] = views
		Streak = { Kind = nil, N = 0, Logged = {} },
	}
end

local function session(player)
	return T.Session[player]
end

-- emergent_play_watch §2: a returning player's first Config.Analytics.ReturnActs actions (a zone entered, a window opened)
local function returnAct(player, kind, id)
	local s = session(player)
	if not s or not s.Returning or s.Acts >= math.floor(num(A.ReturnActs, 3)) then return end
	s.Acts += 1
	TelemetryService.Custom(player, "ReturnAct", s.Acts, kind, id)
end

------------------------------------------------------------------ friends (IsFriendsWith, cached per pair)
local function pairKey(a, b)
	local x, y = a.UserId, b.UserId
	if x > y then x, y = y, x end
	return tostring(x) .. ":" .. tostring(y)
end

local function isFriend(a, b)
	return T.Friend[pairKey(a, b)] == true
end

-- the new player against everyone already here (the later joiner checks the pair), at most FriendCheckMax web calls
local function checkFriends(player)
	local done = 0
	for _, other in S.PlayerService.GetReadyPlayers() do
		if done >= math.floor(num(A.FriendCheckMax, 12)) or player.Parent == nil then break end
		if other ~= player and other.Parent ~= nil and T.Friend[pairKey(player, other)] == nil then
			done += 1
			local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
			T.Friend[pairKey(player, other)] = ok and friends == true
		end
	end
end

------------------------------------------------------------------ join / leave
local function watch(player, attr, fn)
	T.Conns[player] = T.Conns[player] or {}
	table.insert(T.Conns[player], player:GetAttributeChangedSignal(attr):Connect(function()
		local ok, err = pcall(fn, player:GetAttribute(attr))
		if not ok then Util.Warn("TelemetryService", attr .. ": " .. tostring(err)) end
	end))
end

local function onReady(player, data)
	T.JoinedAt[player] = os.clock()
	newSession(player, data)
	-- catch up the steps a returning player already passed (never logs the same step twice)
	local Step = TelemetryService.Step
	if data.IntroSeen == true then Step(player, "IntroDone") end
	if data.Faction ~= "None" then Step(player, "Faction") end
	if data.ClassChosen == true then Step(player, "Class") end
	local tut = num(data.TutorialStep)
	if tut >= 1 then Step(player, "FirstMissionAccept") end
	if tut >= 2 then Step(player, "MeadowArrive") end -- 2 = arrived in the meadow, 99 = claimed
	if num(data.TotalKills) > 0 then
		Step(player, "FirstHit")
		Step(player, "FirstKill")
	end
	local done = type(data.Story) == "table" and type(data.Story.Done) == "table" and data.Story.Done or {}
	if done.M1_3 or done.S0 then Step(player, "FirstSkillHit") end -- both need a manual skill that hit a monster
	if tut == 99 then Step(player, "FirstMissionDone") end
	if data.BlacksmithVisited == true then Step(player, "ForgeArrive") end
	if num(data.WeaponOwnedMask) > 0 then Step(player, "FirstWeapon") end -- A23-34: any weapon owned
	if data.AutoCombatUnlocked == true then Step(player, "AutoUnlocked") end
	if num(data.Level, 1) >= 10 then Step(player, "Level10") end
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	T.Conns[player] = nil
	watch(player, "IntroSeen", function(v) if v == true then Step(player, "IntroDone") end end)
	watch(player, "ClassChosen", function(v) if v == true then Step(player, "Class") end end)
	watch(player, "TutorialStep", function(v)
		-- accepting the guide mission sets TutorialStep 1 (2 = arrived in the meadow, 99 = first mission claimed)
		if num(v) >= 1 then Step(player, "FirstMissionAccept") end
		if num(v) >= 2 then Step(player, "MeadowArrive") end
		if v == 99 then Step(player, "FirstMissionDone") end
	end)
	watch(player, "BlacksmithVisited", function(v) if v == true then Step(player, "ForgeArrive") end end)
	watch(player, "WeaponOwnedMask", function(v) if num(v) > 0 then Step(player, "FirstWeapon") end end)
	watch(player, "AutoCombatUnlocked", function(v) if v == true then Step(player, "AutoUnlocked") end end)
	watch(player, "Level", function(v) if num(v, 1) >= 10 then Step(player, "Level10") end end)
	watch(player, "AutoCombatEnabled", function(v)
		if not throttled(player, "auto", 10) then TelemetryService.Custom(player, v == true and "AutoOn" or "AutoOff", 1) end
	end)
	task.spawn(function()
		local ok, err = pcall(checkFriends, player)
		if not ok then Util.Warn("TelemetryService", "friends: " .. tostring(err)) end
	end)
end

local function bucketOf(minutes)
	return minutes < 5 and "0-5" or minutes < 15 and "5-15" or minutes < 30 and "15-30" or minutes < 60 and "30-60" or "60+"
end

local function onLeaving(player)
	local Custom = TelemetryService.Custom
	local joined = T.JoinedAt[player]
	if joined then
		local minutes = math.floor((os.clock() - joined) / 60)
		Custom(player, "SessionMinutes", minutes, bucketOf(minutes))
	end
	local failAt = T.EnhanceFailAt[player]
	if failAt and os.clock() - failAt <= num(A.EnhanceFailLeave, 300) then
		Custom(player, "EnhanceFailLeave", math.floor(os.clock() - failAt))
	end
	local s = session(player)
	if s then
		if s.AwayMin > 0 then Custom(player, "AutoAwayMinutes", s.AwayMin) end
		for source, gold in s.GoldIn do Custom(player, "GoldIn", gold, source) end
		for sink, gold in s.GoldOut do Custom(player, "GoldOut", gold, sink) end
		Custom(player, "FriendMinutes", s.FriendMin, s.FriendMin > 0 and "WithFriend" or "Solo")
		if s.Together > 0 then Custom(player, "KillsTogether", s.Together) end
		if s.WithFriend > 0 then Custom(player, "KillsWithFriend", s.WithFriend) end
		for zone, minutes in s.ZoneMin do Custom(player, "ZoneMinutes", minutes, zone) end
		for board, views in s.Rankings do Custom(player, "RankingViews", views, board) end
	end
	T.JoinedAt[player], T.MeadowAt[player], T.EnhanceFailAt[player], T.Session[player] = nil, nil, nil, nil
	T.FirstHit[player] = nil
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	T.Conns[player] = nil
	for k in T.Throttle do
		if string.sub(k, 1, #tostring(player.UserId) + 1) == tostring(player.UserId) .. ":" then T.Throttle[k] = nil end
	end
end

------------------------------------------------------------------ handlers
-- BB38: c->s "UiMetric"(id): a window the client opened (Config.Analytics.UiIds), once a session per window
local function onUiMetric(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or not T.UiIds[id] then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "UiMetric", num(Config.RateLimits.UiMetric, 2)) then return end
	local s = session(player)
	if not s or s.Windows[id] then return end
	s.Windows[id] = true
	TelemetryService.Custom(player, "WindowOpen_" .. id, 1)
	returnAct(player, "Window", id)
end

local function onKilled(player, info)
	if type(info) ~= "table" then return end
	TelemetryService.Step(player, "FirstKill") -- A23-68 #5
	local at = T.MeadowAt[player]
	if at and at > 0 then
		T.MeadowAt[player] = -1 -- once per session
		TelemetryService.Custom(player, "RookieFirstKillSeconds", math.floor(os.clock() - at), info.Kind)
	end
	local s = session(player)
	if s then
		-- 검수 2026-10-07 friends: a kill earned with others (MonsterService Party / Others)
		if num(info.Party, 1) >= 2 then s.Together += 1 end
		if type(info.Others) == "table" then
			for _, o in info.Others do
				if typeof(o) == "Instance" and isFriend(player, o) then
					s.WithFriend += 1
					break
				end
			end
		end
		-- emergent_play_watch §2: the same kind again and again (once a session per kind)
		local st = s.Streak
		if info.Kind == st.Kind then st.N += 1 else st.Kind, st.N = info.Kind, 1 end
		if st.N >= math.floor(num(A.SameKindStreak, 30)) and not st.Logged[st.Kind] then
			st.Logged[st.Kind] = true
			TelemetryService.Custom(player, "SameKindStreak", st.N, st.Kind)
		end
	end
	-- the crown-shard trial "3 slimes with basic attacks only" (S0 step 2) did not count this slime: a skill hit it
	local data = getData(player)
	local story = data and data.Story
	local s0 = type(story) == "table" and type(story.Subs) == "table" and story.Subs.S0
	-- only while trial "a" (basic-attack slimes) is still open; a skill kill during trial "b" is expected
	local trialA = 3
	pcall(function() trialA = Config.StoryQuests.Defs.S0.Steps[2].Obj.List[1].Count end)
	local doneA = type(s0) == "table" and type(s0.T) == "table" and tonumber(s0.T.a) or 0
	if type(s0) == "table" and s0.St == 2 and doneA < trialA
		and Config.QuestKind(info.Kind) == "Slime" -- review C-9: a pumpkin slime counts as a slime there too
		and info.SkillHit == true and not throttled(player, "trialmiss", 300) then
		TelemetryService.Custom(player, "CrownTrialMiss", 1, "SkillHit", info.Kind)
	end
end

-- every minute: auto combat while away, minutes with a friend here, minutes per zone
local function minuteTick()
	local ready = S.PlayerService.GetReadyPlayers()
	for _, p in ready do
		local s = session(p)
		if s and p.Parent then
			if p:GetAttribute("AutoCombatEnabled") == true then
				local own = math.max(num(S.PlayerService.GetLastOwnActive(p)), T.JoinedAt[p] or 0)
				if os.clock() - own >= num(A.AwayAfter, 300) then s.AwayMin += 1 end
			end
			for _, q in ready do
				if q ~= p and q.Parent and isFriend(p, q) then
					s.FriendMin += 1
					break
				end
			end
			local zone = p:GetAttribute("ZoneId")
			if type(zone) == "string" and Config.Zones[zone] then s.ZoneMin[zone] = (s.ZoneMin[zone] or 0) + 1 end
		end
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
	Net.Get("UiMetric").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onUiMetric, player, ...)
		if not ok then Util.Warn("TelemetryService", "UiMetric: " .. tostring(err)) end
	end)
	connect("PlayerService", "PlayerReady", onReady)
	connect("PlayerService", "PlayerLeaving", onLeaving)
	connect("FactionService", "FactionChanged", function(player, newFaction)
		if newFaction and newFaction ~= "None" then TelemetryService.Step(player, "Faction") end
	end)
	-- BB14: the KO screen's cause (Player / Kaiju / Monster / Fall / Other), the first KO of an account
	connect("CombatService", "KnockedOut", function(player, by)
		local data = getData(player)
		if not data then return end
		local tel = telemetryOf(data)
		if tel.FirstDeath then return end
		tel.FirstDeath = true
		TelemetryService.Custom(player, "FirstDeath_" .. tostring(by), 1, player:GetAttribute("ZoneId"))
	end)
	connect("GrudgeService", "SackResolved", function(thief, outcome, total)
		local name = ({ Paid = "Kept", Avenged = "Avenged", Returned = "Returned" })[outcome]
		if name then TelemetryService.Custom(thief, "Plunder_" .. name, num(total)) end
	end)
	connect("LootService", "Enhanced", function(player, _tier, _before, _after, success)
		if success == false then T.EnhanceFailAt[player] = os.clock() end
	end)
	connect("SettingsService", "KeysChanged", function(player, changed)
		TelemetryService.Custom(player, "KeyRebind", num(changed, 1))
	end)
	connect("RankingService", "Viewed", function(player, board)
		local s = session(player)
		if s and type(board) == "string" then s.Rankings[board] = (s.Rankings[board] or 0) + 1 end
	end)
	-- 검수 2026-10-07 economy: where gold comes from and where it goes (per session sums, logged at leave)
	connect("ProgressionService", "GoldEarned", function(player, amount, source)
		local s = session(player)
		if s and type(source) == "string" then s.GoldIn[source] = (s.GoldIn[source] or 0) + math.max(0, num(amount)) end
	end)
	connect("ProgressionService", "GoldSpent", function(player, amount, sink)
		local s = session(player)
		if s and type(sink) == "string" then s.GoldOut[sink] = (s.GoldOut[sink] or 0) + math.max(0, num(amount)) end
	end)
	-- A23-68 #5: the first hit that landed, the first manual skill that hit a monster
	connect("CombatService", "MonsterHit", function(player)
		if T.FirstHit[player] then return end
		T.FirstHit[player] = true
		TelemetryService.Step(player, "FirstHit")
	end)
	connect("CombatService", "Released", function(player, info)
		if type(info) == "table" and info.Auto ~= true and num(info.MonstersHit) >= 1 then
			TelemetryService.Step(player, "FirstSkillHit")
		end
	end)
	connect("ZoneService", "ZoneChanged", function(player, newZone)
		if newZone == "SlimeMeadow" then TelemetryService.Step(player, "MeadowArrive") end
		if newZone == "SlimeMeadow" and T.MeadowAt[player] == nil and num(player:GetAttribute("Level"), 1) < 10 then
			T.MeadowAt[player] = os.clock()
		end
		if type(newZone) == "string" and Config.Zones[newZone] then returnAct(player, "Zone", newZone) end
	end)
	connect("MonsterService", "MonsterKilled", onKilled)
	task.spawn(function()
		while true do
			task.wait(60)
			local ok, err = pcall(minuteTick)
			if not ok then Util.Warn("TelemetryService", "minute: " .. tostring(err)) end
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
					if p:GetAttribute("ZoneId") == "SlimeMeadow" and num(p:GetAttribute("Level"), 1) >= 20 then
						TelemetryService.Custom(p, "HighLevelInMeadow", num(p:GetAttribute("Level")))
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
