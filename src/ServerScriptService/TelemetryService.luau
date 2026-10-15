-- TelemetryService.luau : P6 / BB38 (docs/design/beta_basics_2026-10-05.md BB38, mmorpg_painpoints §2, 검수 2026-10-07:
-- economy + friends, emergent_play_watch §2) Roblox AnalyticsService funnel / custom events, no personal data: no
-- names, UserIds, chat or free text in an event name or field (every name and field comes from a fixed list: Config,
-- zone / monster / window ids). Read-only observer: it only listens to signals / attributes and never changes game
-- state. Every call is pcall'd; a missing AnalyticsService (Studio, old engine) costs nothing. Config.Analytics.Debug
-- (default: Studio) prints every call.
--   Onboarding funnel (each step once per account, any order; data.Telemetry.Funnel = { [name] = true }):
--     Config.Analytics.Steps = IntroDone, Faction, Class, FirstMissionAccept, ForgeArrive, FirstWeapon, MeadowArrive,
--     FirstHit, FirstKill, FirstMissionDone, FirstSkillHit, AutoUnlocked, Level10 (A23-68 #5: the first 3 minutes;
--     A23-71 S13: the first skill comes at Lv5, before Auto Battle opens; A23-74: the Forge and the first weapon come
--     right after the acceptance, before the meadow)
--   Right away: FirstDeath_<By> (BB14 KO cause, once per account), AutoOn / AutoOff, Plunder_Kept / _Avenged /
--     _Returned, KeyRebind (actions changed), WindowOpen_<id> (UiMetric, once per session per window),
--     RookieFirstKillSeconds, HighLevelInMeadow, ServerPopulation, CrownTrialMiss, SameKindStreak, ReturnAct (the first
--     actions of a returning player: a zone entered or a window opened)
--   At leave (per session sums): SessionMinutes, AutoAwayMinutes (auto ON with no own action for AwayAfter s),
--     EnhanceFailLeave (left within EnhanceFailLeave s of a failed enhance), GoldIn / GoldOut (per source / sink),
--     FriendMinutes (a friend on the server), KillsTogether / KillsWithFriend, ZoneMinutes (per zone), RankingViews
--     (per board)
--   A23-79 beta metrics (게임성 개발 3, 2026-10-08; docs/design/retention_round_2026-10-08.md "베타에서 잴 것", contract
--   docs/design/beta_metrics_server_2026-10-08.md): the funnels Config.Analytics.Funnels (LogFunnelStepEvent;
--   LongRoad / Social / KingDiary once per account in data.Telemetry.F, DailyVisit per KST day in data.Telemetry.Visit,
--   PassShop per shop visit), the events DaysPlayed / ReturnGap (join), PauseCard / WelcomeBack, Attendance,
--   FriendJoin / GoToFriend, DiaryPage / CandyTrade, NotifyOptIn, InviteSent / WelcomeBackGo (c->s "ClientMetric"),
--   PromptNearKO, and at leave KOLeave60 + LeaveContext. Gold goes to the economy dashboard too (LogEconomyEvent,
--   currency "Gold", the sums per source / sink every Config.Analytics.EconomyFlush s and at the leave).
--   A23-113 (게임성 개발 3, 2026-10-10; docs/design/player_reactions_research_2026-10-10.md): the FirstKO funnel (once per
--   account; the five steps of the King's Hop quest KO1 in order: KO, PotionBought, SlotSet, PotionUsed, KingWon - fed by
--   StoryQuestService.StepDone through Config.Analytics.QuestFunnels), MinutesToLv5 (minutes of play when Lv5 is reached, once per
--   account, field = faction) and PvPResult (every PvP KO: value = the winner side's size-scale multiplier, fields = winner
--   faction, loser faction, level bands "<winner>><loser>") and PvPKOedDay (the same player KO'd by other players this many
--   times in one KST day; logged when the count reaches a step of Config.Analytics.PvPKOedDay.Steps; fields = level band, zone)
--   Phone / PC performance (게임성 개발 3, 2026-10-09; docs/design/phone_perf_server_2026-10-09.md): c->s ClientMetric "Perf"
--   { D device, F average fps, W lowest second, M memory MB, Q quality } every Config.Analytics.Perf.Every s -> PerfFps /
--   PerfFpsLow (W under Perf.Low) / PerfMem with fields device, zone, Q<level>; its own limit (MinGap s), not the shared budget.
local HttpService = game:GetService("HttpService")
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
	Steps = A.Steps or { "IntroDone", "Faction", "Class", "FirstMissionAccept", "ForgeArrive", "FirstWeapon", "MeadowArrive",
		"FirstHit", "FirstKill", "FirstMissionDone", "FirstSkillHit", "AutoUnlocked", "Level10" },
	FirstHit = {}, -- [Player] = true once FirstHit is logged (or passed): later hits skip the funnel lookup
	UiIds = {}, -- [window id] = true (Config.Analytics.UiIds)
	JoinedAt = {}, -- [Player] = os.clock()
	MeadowAt = {}, -- [Player] = os.clock() of the first SlimeMeadow entry this session (rookies only)
	EnhanceFailAt = {}, -- [Player] = os.clock() of the last failed enhance
	Throttle = {}, -- ["<userId>:<key>"] = os.clock()
	Conns = {}, -- [Player] = { RBXScriptConnection } (attribute watchers, dropped on leave)
	Session = {}, -- [Player] = per-session sums and once-flags (see newSession)
	Friend = {}, -- ["<lowId>:<highId>"] = true / false (IsFriendsWith, cached for the server's life)
	-- A23-79 (게임성 개발 3)
	Funnels = A.Funnels or {}, -- Config.Analytics.Funnels
	Shop = {}, -- [Player] = { Id = PassShop funnel session id, Done = { [step] = true } } of the open shop visit
	KOAt = {}, -- [Player] = { At = os.clock(), Zone } of the last KO
	CardAt = {}, -- [Player] = os.clock() of the last pause card
	DailyDoneAt = {}, -- [Player] = os.clock() the day's last daily was claimed
	WindowAt = {}, -- [Player] = { Id, At } of the last window opened
	Econ = {}, -- [Player] = { In = { [source] = gold }, Out = { [sink] = gold } } since the last economy flush
	Day = {}, -- [Player] = the KST day of the DailyVisit funnel session in use
	ClientMetric = Util.Signal.new(), -- (player, id, arg) after validation (TelemetryService.ClientMetric)
}
TelemetryService.ClientMetric = T.ClientMetric
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

------------------------------------------------------------------ A23-79 funnels (게임성 개발 3)
local function today()
	return Config.DayIndex(os.time())
end

-- the DailyVisit session of `data` for `day` (a new day starts a new step set)
local function visitOf(data, day)
	local tel = telemetryOf(data)
	if type(tel.Visit) ~= "table" or tel.Visit.D ~= day then tel.Visit = { D = day, S = {} } end
	if type(tel.Visit.S) ~= "table" then tel.Visit.S = {} end
	return tel.Visit
end

-- one step of a Config.Analytics.Funnels funnel, at most once per funnel session: Once funnels = one session per account
-- (data.Telemetry.F), DailyVisit = the KST day now (data.Telemetry.Visit), PassShop = the open shop visit (T.Shop, see
-- shopStep). Roblox completes the earlier steps of a later one, so every funnel holds only steps that always come in
-- order (review 2026-10-08: optional moments such as the attendance claim or the story's end are custom events).
-- Returns true when it was logged now.
function TelemetryService.Funnel(player, funnel, name)
	local def = T.Funnels[funnel]
	local index = type(def) == "table" and type(def.Steps) == "table" and table.find(def.Steps, name) or nil
	if not index then return false end
	local data = getData(player)
	if not data then return false end
	local sessionId, done
	if def.Once then
		local tel = telemetryOf(data)
		if type(tel.F) ~= "table" then tel.F = {} end
		if type(tel.F[funnel]) ~= "table" then tel.F[funnel] = {} end
		sessionId, done = "once", tel.F[funnel]
	elseif funnel == "DailyVisit" then
		local day = today()
		local visit = visitOf(data, day)
		sessionId, done = tostring(day), visit.S
	elseif funnel == "PassShop" then
		local shop = T.Shop[player]
		if not shop then return false end -- PassShop steps belong to an open shop visit
		sessionId, done = shop.Id, shop.Done
	else
		return false
	end
	if done[name] then return false end
	done[name] = true
	if debugOn() then print(string.format("[Metrics] %s %s step %d %s", funnel, sessionId, index, name)) end
	local svc = analytics()
	if svc then pcall(svc.LogFunnelStepEvent, svc, player, funnel, sessionId, index, name) end
	return true
end

local function funnel(player, name, step)
	return TelemetryService.Funnel(player, name, step)
end

-- PassShop (review 2026-10-08: the client reports a window once a session, so a visit starts from the shop open OR the
-- first pass card / buy window when no fresh visit is open). A shop open within ShopVisitGap s of the last start keeps
-- that visit (no new session per click); a visit older than ShopVisitMax s is over. Bought only counts in an open visit.
local function shopStep(player, name)
	local now = os.clock()
	local v = T.Shop[player]
	local open = v ~= nil and now - v.At < num(A.ShopVisitMax, 600)
	if name == "Bought" then
		if open then funnel(player, "PassShop", "Bought") end
		return
	end
	if not open or (name == "ShopOpen" and now - v.At >= num(A.ShopVisitGap, 30)) then
		local okId, sid = pcall(HttpService.GenerateGUID, HttpService, false)
		T.Shop[player] = { Id = okId and sid or tostring(os.time()), Done = {}, At = now }
		funnel(player, "PassShop", "ShopOpen")
	end
	if name ~= "ShopOpen" then funnel(player, "PassShop", name) end
end

local function bandOf(level)
	level = math.floor(num(level, 1))
	return level < 10 and "1-9" or level < 25 and "10-24" or level < 50 and "25-49" or "50+"
end

-- DaysPlayed (the first visit of a KST day: lifetime days played, the level band, the faction) and the day's
-- DailyVisit Join step; also for a player still online when the day turns
local function dayStart(player, data)
	local day = today()
	T.Day[player] = day
	local tel = telemetryOf(data)
	if math.floor(num(tel.LastDay)) ~= day then
		tel.LastDay = day
		tel.Days = math.floor(num(tel.Days)) + 1
		TelemetryService.Custom(player, "DaysPlayed", tel.Days, bandOf(data.Level), tostring(data.Faction))
	end
	funnel(player, "DailyVisit", "Join")
end

local function gapBucket(seconds)
	local h = seconds / 3600
	return h < 6 and "<6h" or h < 24 and "6-24h" or h < 72 and "1-3d" or "3d+"
end

-- LongRoad steps the save already passed (an old save catches up). Only the level path (always in order) is a funnel;
-- the story's chapter ends and the first ruins daily are the custom events ChapterEnd / RuinsDaily.
local ROAD_LEVELS = { 15, 25, 30, 40, 50 }
local QUEST_FUNNELS = A.QuestFunnels or {} -- Config.Analytics.QuestFunnels (A23-113: KO1 = FirstKO)
local function roadCatchUp(player, data)
	local level = math.floor(num(data.Level, 1))
	for _, at in ROAD_LEVELS do
		if level >= at then funnel(player, "LongRoad", "Level" .. at) end
	end
	if num(data.Rebirths) >= 1 then funnel(player, "LongRoad", "Rebirth1") end
end

-- the last main quest of each chapter (Config.StoryQuests.Main order + Defs[id].Chapter) -> ChapterEnd
local CHAPTER_END = {}
do
	local SQ = Config.StoryQuests or {}
	local last = {}
	for _, id in SQ.Main or {} do
		local def = SQ.Defs and SQ.Defs[id]
		local ch = def and math.floor(num(def.Chapter))
		if ch and ch > 0 then last[ch] = id end
	end
	for ch, id in last do CHAPTER_END[id] = ch end
end

local function diaryCatchUp(player, pages)
	pages = math.floor(num(pages))
	if pages >= 1 then funnel(player, "KingDiary", "Page1") end
	if pages >= 3 then funnel(player, "KingDiary", "Page3") end
	if pages >= 6 then funnel(player, "KingDiary", "Page6") end
	if pages >= 9 then funnel(player, "KingDiary", "Page9") end
end

-- DailyVisit: Daily1 (a daily claimed), Daily3 (all of the day's dailies done, claimed or not), SetChest (all claimed:
-- the chest). Only while the dailies are today's (data.DailyDay = today): right after 00:00 KST, before QuestService
-- made the new day's set, the counts are still yesterday's (review 2026-10-08)
local function dailyCheck(player)
	local data = getData(player)
	if not data or math.floor(num(data.DailyDay)) ~= today() then return end
	local slots = math.floor(num(Config.Quests and Config.Quests.Slots, 3))
	local claims = math.floor(num(data.DailyClaims))
	local complete = 0
	for _, q in type(data.Quests) == "table" and data.Quests or {} do
		if type(q) == "table" and q.Kind == "Daily" and num(q.Target) > 0 and num(q.Progress) >= num(q.Target) then
			complete += 1
		end
	end
	if claims >= 1 then funnel(player, "DailyVisit", "Daily1") end
	if claims + complete >= slots then funnel(player, "DailyVisit", "Daily3") end
	if claims >= slots then funnel(player, "DailyVisit", "SetChest") end
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
		Once = {}, -- A23-79: [ClientMetric id] = true (Config.Analytics.ClientMetricOnce: once a session)
		Budget = { Start = -math.huge, N = 0 }, -- A23-79: accepted ClientMetric calls this minute
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
	-- TutorialStep: 1 = accepted, 3 = accepted and at the Forge step (A23-74: the first weapon before the meadow),
	-- 2 = arrived in the meadow, 99 = claimed
	local tutSteps = Config.Tutorial.Steps
	local function pastMeadow(v) return v == tutSteps.Quest or v == tutSteps.Done end
	local tut = num(data.TutorialStep)
	if tut >= 1 then Step(player, "FirstMissionAccept") end
	-- A23-74: caught up in the funnel's order, the Forge and the first weapon before the meadow
	if data.BlacksmithVisited == true then Step(player, "ForgeArrive") end
	if num(data.WeaponOwnedMask) > 0 then Step(player, "FirstWeapon") end -- A23-34: any weapon owned
	if pastMeadow(tut) then Step(player, "MeadowArrive") end
	if num(data.TotalKills) > 0 then
		Step(player, "FirstHit")
		Step(player, "FirstKill")
	end
	if tut == 99 then Step(player, "FirstMissionDone") end
	local done = type(data.Story) == "table" and type(data.Story.Done) == "table" and data.Story.Done or {}
	if done.M1_3 or done.S0 then Step(player, "FirstSkillHit") end -- both need a manual skill that hit a monster
	if data.AutoCombatUnlocked == true then Step(player, "AutoUnlocked") end
	if num(data.Level, 1) >= 10 then Step(player, "Level10") end
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	T.Conns[player] = nil
	watch(player, "IntroSeen", function(v) if v == true then Step(player, "IntroDone") end end)
	watch(player, "ClassChosen", function(v) if v == true then Step(player, "Class") end end)
	watch(player, "TutorialStep", function(v)
		-- accepting the guide mission sets TutorialStep 3 (the Forge; 1 for a save that owns the first weapon)
		if num(v) >= 1 then Step(player, "FirstMissionAccept") end
		if pastMeadow(v) then Step(player, "MeadowArrive") end
		if v == 99 then Step(player, "FirstMissionDone") end
	end)
	watch(player, "BlacksmithVisited", function(v) if v == true then Step(player, "ForgeArrive") end end)
	watch(player, "WeaponOwnedMask", function(v) if num(v) > 0 then Step(player, "FirstWeapon") end end)
	watch(player, "AutoCombatUnlocked", function(v) if v == true then Step(player, "AutoUnlocked") end end)
	watch(player, "Level", function(v) if num(v, 1) >= 10 then Step(player, "Level10") end end)
	watch(player, "AutoCombatEnabled", function(v)
		if not throttled(player, "auto", 10) then TelemetryService.Custom(player, v == true and "AutoOn" or "AutoOff", 1) end
	end)
	-- A23-79 (게임성 개발 3): the day, the gap since the last visit, the long road, the diary, the dailies
	dayStart(player, data)
	local last = num(data.LastLogoutTime)
	if last > 0 then TelemetryService.Custom(player, "ReturnGap", 1, gapBucket(math.max(0, os.time() - last))) end
	roadCatchUp(player, data)
	diaryCatchUp(player, type(data.Diary) == "table" and data.Diary.Pages or 0)
	watch(player, "Level", function(v)
		v = num(v, 1)
		for _, at in ROAD_LEVELS do
			if v >= at then funnel(player, "LongRoad", "Level" .. at) end
		end
	end)
	watch(player, "Rebirths", function(v) if num(v) >= 1 then funnel(player, "LongRoad", "Rebirth1") end end)
	watch(player, "DailyClaims", function(v)
		v = num(v)
		-- RuinsDaily: the first daily claimed at Lv25+ (once per account; Lv25 is LongRoad's Level25)
		local d = getData(player)
		local tel = d and telemetryOf(d)
		if tel and not tel.RuinsDaily and v >= 1 and num(player:GetAttribute("Level"), 1) >= 25 then
			tel.RuinsDaily = true
			TelemetryService.Custom(player, "RuinsDaily", 1)
		end
		if v >= num(Config.Quests and Config.Quests.Slots, 3) then T.DailyDoneAt[player] = os.clock() end
		dailyCheck(player)
	end)
	dailyCheck(player)
	task.spawn(function()
		local ok, err = pcall(checkFriends, player)
		if not ok then Util.Warn("TelemetryService", "friends: " .. tostring(err)) end
	end)
end

------------------------------------------------------------------ A23-79 economy + leave context (게임성 개발 3)
local function econOf(player)
	local e = T.Econ[player]
	if not e then
		e = { In = {}, Out = {} }
		T.Econ[player] = e
	end
	return e
end

-- the gold sums since the last flush -> LogEconomyEvent (currency "Gold", item SKU = the ProgressionService tag,
-- transaction type Config.Analytics.EconomySources / EconomySinks or Gameplay; ending balance = carried + bank now)
local function flushEconomy(player)
	local e = T.Econ[player]
	if not e or (next(e.In) == nil and next(e.Out) == nil) then return end
	T.Econ[player] = { In = {}, Out = {} }
	local balance = 0
	pcall(function() balance = math.max(0, math.floor(num(S.ProgressionService.GetTotalGold(player)))) end)
	local svc = analytics()
	local flows = { { e.In, "Source", A.EconomySources or {} }, { e.Out, "Sink", A.EconomySinks or {} } }
	for _, f in flows do
		for tag, gold in f[1] do
			local kind = f[3][tag] or "Gameplay"
			if debugOn() then print(string.format("[Metrics] economy %s %s %d (%s, balance %d)", f[2], tag, gold, kind, balance)) end
			if svc then
				pcall(function()
					svc:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType[f[2]], "Gold", gold, balance, kind, tag)
				end)
			end
		end
	end
end

-- where the player was when they left (one of a fixed list; '어디서 그만두는지')
local function leaveContext(player)
	local now = os.clock()
	local recent = num(A.LeaveRecent, 120)
	local ko = T.KOAt[player]
	if ko and now - ko.At <= num(A.KOLeave, 60) then return "KO" end
	if T.CardAt[player] and now - T.CardAt[player] <= recent then return "StopCard" end
	if T.DailyDoneAt[player] and now - T.DailyDoneAt[player] <= recent then return "DailyDone" end
	local combat = S.CombatService
	if type(combat) == "table" and type(combat.IsInCombat) == "function" then
		local ok, res = pcall(combat.IsInCombat, player)
		if ok and res == true then return "Combat" end
	end
	local win = T.WindowAt[player]
	if win and now - win.At <= 60 then return win.Id == "Shop" and "Shop" or "Menu" end
	local okOwn, own = pcall(S.PlayerService.GetLastOwnActive, player)
	if now - math.max(okOwn and num(own) or 0, T.JoinedAt[player] or 0) >= num(A.IdleAfter, 120) then return "Idle" end
	return "Play"
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
	-- A23-79: the context of the leave and a leave right after a KO (not when the server itself closes: every player
	-- "leaves" then), the last gold sums
	local okClose, closing = pcall(S.PlayerService.IsShuttingDown)
	if not (okClose and closing == true) then
		if joined then
			local minutes = math.floor((os.clock() - joined) / 60)
			Custom(player, "LeaveContext", 1, leaveContext(player), bucketOf(minutes))
		end
		local ko = T.KOAt[player]
		if ko and os.clock() - ko.At <= num(A.KOLeave, 60) then Custom(player, "KOLeave60", 1, tostring(ko.Zone)) end
	end
	flushEconomy(player)
	for _, t in { T.Shop, T.KOAt, T.CardAt, T.DailyDoneAt, T.WindowAt, T.Econ, T.Day } do t[player] = nil end
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
	-- A23-79: every open (not only the first of a session): the leave context; the Shop may start a PassShop visit
	T.WindowAt[player] = { Id = id, At = os.clock() }
	if id == "Shop" then shopStep(player, "ShopOpen") end
	local s = session(player)
	if not s or s.Windows[id] then return end
	s.Windows[id] = true
	TelemetryService.Custom(player, "WindowOpen_" .. id, 1)
	returnAct(player, "Window", id)
end

-- A23-79: c->s "ClientMetric"(id, arg?) = what only the client sees (Config.Analytics.ClientMetrics: the id and the
-- rule for its one argument). Ready, rate limited per id; anything off the list is ignored.
-- ClientMetric "Perf" (Config.Analytics.Perf): exactly { D, F, W, M, Q } (a missing key fails its range check, an extra
-- one the key list), whole numbers in range, D from PerfDevices and the lowest second never above the average. Anything
-- else is not a frame sample (a tampered or half-built table is dropped).
local PERF_KEYS = { D = true, F = true, W = true, M = true, Q = true }
local function whole(v, lo, hi)
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function perfOk(arg)
	if type(arg) ~= "table" then return false end
	local P = A.Perf or {}
	for k in arg do
		if not PERF_KEYS[k] then return false end -- an extra key (or an array slot) is no frame sample
	end
	return type(arg.D) == "string" and table.find(A.PerfDevices or {}, arg.D) ~= nil
		and whole(arg.F, 0, num(P.MaxFps, 240)) and whole(arg.W, 0, arg.F)
		and whole(arg.M, 0, num(P.MaxMem, 16384)) and whole(arg.Q, 0, num(P.MaxQuality, 10))
end

local function argOk(rule, arg)
	if rule == "None" then return arg == nil end
	if rule == "Count" then return type(arg) == "number" and arg == math.floor(arg) and arg >= 1 and arg <= 50 end
	if rule == "Source" then return type(arg) == "string" and table.find(A.InviteSources or {}, arg) ~= nil end
	if rule == "Pass" then
		return type(arg) == "string" and #arg <= 32 and (table.find(A.PassIds or {}, arg) ~= nil
			or (type(Config.GamePasses) == "table" and Config.GamePasses[arg] ~= nil)
			or (type(Config.Looks) == "table" and Config.Looks[arg] ~= nil))
	end
	if rule == "Perf" then return perfOk(arg) end
	if type(rule) == "table" then return type(arg) == "string" and table.find(rule, arg) ~= nil end
	return false
end

-- review 2026-10-08: one client must never flood the game's analytics budget (Roblox: 120 + 20 x CCU events a minute
-- for the whole game). The budget only limits LOGGING (ClientMetricPerMinute logged calls a minute; the once-ids are
-- logged once a session, marked only when one was logged); the ClientMetric signal (ReturnService's state: OptIn,
-- PurchasePrompt) fires for every accepted call (검수 review: a full budget must not hide an opt-in or a buy window).
local function clientBudget(s, id)
	if s.Once[id] then return false end
	local now = os.clock()
	local b = s.Budget
	if now - b.Start >= 60 then b.Start, b.N = now, 0 end
	if b.N >= num(A.ClientMetricPerMinute, 10) then return false end
	b.N += 1
	if table.find(A.ClientMetricOnce or {}, id) then s.Once[id] = true end
	return true
end

-- the funnel steps / custom events of one accepted ClientMetric call (within the budget)
local function logClientMetric(player, s, id, arg)
	local Custom = TelemetryService.Custom
	if id == "InviteSeen" or id == "InvitePrompt" then
		funnel(player, "Social", id)
	elseif id == "InviteSent" then
		funnel(player, "Social", "InviteSent")
		Custom(player, "InviteSent", arg)
	elseif id == "ShopOpen" or id == "PassView" then
		shopStep(player, id)
	elseif id == "PurchasePrompt" then
		shopStep(player, "PurchasePrompt")
		-- A23-79 rule watch: a buy window right after a KO or a failed scroll must never happen (0 expected); one event per
		-- KO / failed scroll at most
		local near = num(A.PromptNearKO, 30)
		local ko, fail = T.KOAt[player], T.EnhanceFailAt[player]
		if ko and not ko.Prompted and os.clock() - ko.At <= near then
			ko.Prompted = true
			Custom(player, "PromptNearKO", 1, "KO", arg)
		elseif fail and s.FailPrompted ~= fail and os.clock() - fail <= near then
			s.FailPrompted = fail
			Custom(player, "PromptNearKO", 1, "EnhanceFail", arg)
		end
	elseif id == "OptIn" then
		Custom(player, "NotifyOptIn", 1, arg)
	elseif id == "WelcomeBackGo" then
		Custom(player, "WelcomeBackGo", 1)
	end
end

-- one accepted Perf sample: PerfFps (the average), PerfFpsLow (the lowest second, only under Config.Analytics.Perf.Low),
-- PerfMem (MB); fields = device, the zone now, "Q<quality>". Its own limit (MinGap s per player), not the shared minute
-- budget: a phone sampled every Every s costs 3 events per sample, far under Roblox's 20 per player per minute.
local function perfSample(player, arg)
	local P = A.Perf or {}
	if not Util.RateLimit(player, "Perf", num(P.MinGap, 60)) then return end
	local zone = player:GetAttribute("ZoneId")
	if type(zone) ~= "string" or not Config.Zones[zone] then zone = "Other" end
	local quality = "Q" .. arg.Q
	local Custom = TelemetryService.Custom
	Custom(player, "PerfFps", arg.F, arg.D, zone, quality)
	if arg.W < num(P.Low, 20) then Custom(player, "PerfFpsLow", arg.W, arg.D, zone, quality) end
	Custom(player, "PerfMem", arg.M, arg.D, zone, quality)
	T.ClientMetric:Fire(player, "Perf", { D = arg.D, F = arg.F, W = arg.W, M = arg.M, Q = arg.Q })
end

local function onClientMetric(player, ...)
	local n = select("#", ...)
	if n < 1 or n > 2 then return end
	local id, arg = ...
	if type(id) ~= "string" then return end
	local rule = (A.ClientMetrics or {})[id]
	if rule == nil or not argOk(rule, arg) then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "ClientMetric:" .. id, num(Config.RateLimits.ClientMetric, 0.5)) then return end
	if id == "Perf" then
		local okPerf, errPerf = pcall(perfSample, player, arg)
		if not okPerf then Util.Warn("TelemetryService", "Perf: " .. tostring(errPerf)) end
		return
	end
	local s = session(player)
	if s and clientBudget(s, id) then
		local okLog, errLog = pcall(logClientMetric, player, s, id, arg)
		if not okLog then Util.Warn("TelemetryService", "ClientMetric log: " .. tostring(errLog)) end
	end
	T.ClientMetric:Fire(player, id, arg) -- every accepted call (the state of ReturnService), budget or not
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
			-- A23-79: a KST day that turned while playing is a new play day; the dailies' progress (Daily3)
			local data = getData(p)
			if data and T.Day[p] ~= today() then dayStart(p, data) end
			dailyCheck(p)
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
		-- A23-79: the economy dashboard sums (flushed every EconomyFlush s and at the leave)
		if s and type(source) == "string" and num(amount) > 0 then
			local e = econOf(player).In
			e[source] = (e[source] or 0) + math.floor(num(amount))
		end
	end)
	connect("ProgressionService", "GoldSpent", function(player, amount, sink)
		local s = session(player)
		if s and type(sink) == "string" then s.GoldOut[sink] = (s.GoldOut[sink] or 0) + math.max(0, num(amount)) end
		if s and type(sink) == "string" and num(amount) > 0 then
			local e = econOf(player).Out
			e[sink] = (e[sink] or 0) + math.floor(num(amount))
		end
	end)
	-- A23-79 (게임성 개발 3): the new services' moments
	Net.Get("ClientMetric").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onClientMetric, player, ...)
		if not ok then Util.Warn("TelemetryService", "ClientMetric: " .. tostring(err)) end
	end)
	connect("CombatService", "KnockedOut", function(player)
		T.KOAt[player] = { At = os.clock(), Zone = player:GetAttribute("ZoneId") }
	end)
	connect("AttendanceService", "Claimed", function(player, slot, days)
		TelemetryService.Custom(player, "Attendance", num(days), tostring(slot)) -- an optional moment: no funnel step
	end)
	connect("ReturnService", "CardShown", function(player, why)
		T.CardAt[player] = os.clock()
		-- only the daily card ends the day's funnel (it comes right after SetChest; a chapter / war card would complete
		-- the earlier steps by Roblox's skip rule)
		if why == "Daily" then funnel(player, "DailyVisit", "StopCardSeen") end
		TelemetryService.Custom(player, "PauseCard", 1, tostring(why))
	end)
	connect("ReturnService", "Welcomed", function(player)
		TelemetryService.Custom(player, "WelcomeBack", 1)
	end)
	-- A23-88 (walking to the Forge): the seconds from [I'm In!] to the first time the walker stands at Otto's anvil
	connect("QuestService", "ForgeReached", function(player, seconds)
		TelemetryService.Custom(player, "ForgeWalk", math.floor(num(seconds)))
	end)
	connect("InviteService", "InviteJoined", function(invitee, _by, inviter)
		TelemetryService.Custom(invitee, "FriendJoin", 1, inviter and "InviterHere" or "InviterAway")
		if typeof(inviter) == "Instance" then funnel(inviter, "Social", "InviteeJoined") end
	end)
	connect("InviteService", "PlayedTogether", function(inviter)
		funnel(inviter, "Social", "PlayedTogether10m")
	end)
	connect("InviteService", "WentToFriend", function(player, zone)
		TelemetryService.Custom(player, "GoToFriend", 1, tostring(zone))
	end)
	connect("DiaryService", "PageOpened", function(player, page, late)
		diaryCatchUp(player, page)
		TelemetryService.Custom(player, "DiaryPage", num(page), late and "Late" or "OnTime")
	end)
	connect("DiaryService", "CandyTraded", function(player, id, candy)
		TelemetryService.Custom(player, "CandyTrade", num(candy), tostring(id))
	end)
	-- A23-113 #2: the steps of a quest that is a funnel (KO1 = FirstKO), logged as the quest passes them, so they stay in order
	connect("StoryQuestService", "StepDone", function(player, quest, step)
		local name = type(quest) == "string" and QUEST_FUNNELS[quest] or nil
		local def = name and T.Funnels[name]
		local stepName = def and type(def.Steps) == "table" and def.Steps[math.floor(num(step))] or nil
		if stepName then funnel(player, name, stepName) end
	end)
	-- quest P1 ⑨: the first 30 minutes (Config.Analytics.QuestTimes): accept minutes, declines, Match / Timing misses, and the
	-- minutes of play to the first skill (once per account, saved first)
	local QT = type(A.QuestTimes) == "table" and A.QuestTimes or {}
	local function playMinutes(data) return math.max(0, math.floor(num(data.PlaytimeSeconds) / 60 + 0.5)) end
	connect("StoryQuestService", "Accepted", function(player, quest)
		local data = getData(player)
		if not data or type(QT.Accept) ~= "table" or QT.Accept[quest] ~= true then return end
		TelemetryService.Custom(player, "QuestAccept", playMinutes(data), tostring(quest), tostring(data.Faction))
	end)
	connect("StoryQuestService", "Declined", function(player, quest)
		if type(QT.Accept) == "table" and QT.Accept[quest] == true then TelemetryService.Custom(player, "QuestDecline", 1, tostring(quest)) end
	end)
	connect("StoryQuestService", "MiniMiss", function(player, quest, kind)
		TelemetryService.Custom(player, "QuestMiniMiss", 1, tostring(kind), tostring(quest))
	end)
	connect("StoryQuestService", "StepDone", function(player, quest, step)
		local rule = QT.FirstSkill
		if type(rule) ~= "table" or quest ~= rule.Quest or math.floor(num(step)) ~= math.floor(num(rule.Step)) then return end
		local data = getData(player)
		if not data then return end
		local tel = telemetryOf(data)
		if tel.FirstSkill then return end
		tel.FirstSkill = true -- saved first: once per account
		TelemetryService.Custom(player, tostring(rule.Event or "MinutesToFirstSkill"), math.max(1, playMinutes(data)), tostring(data.Faction))
	end)
	-- A23-113 #2: how many minutes of play it took to reach Lv5 (once per account, when the level is reached)
	connect("ProgressionService", "LeveledUp", function(player, level)
		local rule = A.TimeToLevel
		if type(rule) ~= "table" or type(level) ~= "number" or math.floor(num(level)) ~= math.floor(num(rule.Level)) then return end
		local data = getData(player)
		if not data then return end
		local tel = telemetryOf(data)
		if tel.TimeToLevel then return end
		tel.TimeToLevel = true -- saved first: once per account
		local minutes = math.max(1, math.floor(num(data.PlaytimeSeconds) / 60 + 0.5))
		TelemetryService.Custom(player, tostring(rule.Event or "MinutesToLv5"), minutes, tostring(data.Faction))
	end)
	-- A23-113 #5: every PvP KO, the winner's and the loser's side and level band (who wins, between which levels, how much the
	-- size scale helped); never a name or an id
	-- A23-113 (검수 2026-10-10): how many times the same player is KO'd by other players in one KST day (the Lv15-20 sprouts the
	-- woods hit again and again are the worry of the 10/17 test). The day's count lives in data.Telemetry.PvPKO = { D = day, N = n }
	-- (saved: several sessions of one day add up); the custom event fires when it reaches a step of Config.Analytics.PvPKOedDay.Steps
	-- (value = n, fields = the victim's level band and zone), so the dashboard shows how many players were hit 3, 5, 10 ... times
	local function victimDay(victim)
		local rule = A.PvPKOedDay
		if type(rule) ~= "table" or type(rule.Steps) ~= "table" then return end
		local data = getData(victim)
		if not data then return end
		local tel, day = telemetryOf(data), today()
		local rec = tel.PvPKO
		if type(rec) ~= "table" or rec.D ~= day then
			rec = { D = day, N = 0 }
			tel.PvPKO = rec
		end
		rec.N = math.floor(num(rec.N)) + 1
		if table.find(rule.Steps, rec.N) then
			TelemetryService.Custom(victim, tostring(rule.Event or "PvPKOedDay"), rec.N, bandOf(victim:GetAttribute("Level")),
				tostring(victim:GetAttribute("ZoneId")))
		end
	end
	connect("PvPService", "PlayerKO", function(killer, victim)
		if typeof(killer) ~= "Instance" or typeof(victim) ~= "Instance" then return end
		victimDay(victim)
		if throttled(killer, "pvpresult", num(A.PvPResultGap, 1)) then return end
		local kf, vf = tostring(killer:GetAttribute("Faction")), tostring(victim:GetAttribute("Faction"))
		local scale = 1
		local justice = S.JusticeService
		if type(justice) == "table" and type(justice.GetFactionScale) == "function" then
			local ok, v = pcall(justice.GetFactionScale, kf)
			if ok then scale = math.floor(num(v, 1) * 100 + 0.5) / 100 end
		end
		TelemetryService.Custom(killer, "PvPResult", scale, kf, vf, bandOf(killer:GetAttribute("Level")) .. ">" .. bandOf(victim:GetAttribute("Level")))
	end)
	connect("StoryQuestService", "QuestDone", function(player, id)
		local ch = CHAPTER_END[id]
		if ch then TelemetryService.Custom(player, "ChapterEnd", ch) end -- the story's chapter ends (3 = the tombs, Lv25)
	end)
	-- A23-75 (게임성 개발 2's MonetizationService, when it fires it): a pass bought during the open shop visit
	connect("MonetizationService", "PassBought", function(player)
		shopStep(player, "Bought")
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
				-- A23-79: the economy dashboard (Config.Analytics.EconomyFlush = this loop's 300 s)
				for _, p in ready do flushEconomy(p) end
			end)
			if not ok then Util.Warn("TelemetryService", "population: " .. tostring(err)) end
		end
	end)
	print("[TelemetryService] started")
end

return TelemetryService
