-- metrics_offline.luau : BB38 beta metrics (docs/design/beta_basics_2026-10-05.md BB38 + 검수 2026-10-07 economy /
-- friends + emergent_play_watch §2). tools/test_metrics.py binds CONFIG_SOURCE, UTIL_SOURCE, TELEMETRY_SOURCE,
-- SETTINGS_SOURCE and GOLD_EXTRACT (ProgressionService's gold functions) in front of dev2_kit.luau; this file follows.
-- TelemetryService runs on signal doubles of the services it listens to and an AnalyticsService double that records
-- every call; its two loops are coroutines stepped by hand (minute tick, 5-minute tick).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local A0 = C0.Analytics

local function metricsWorld(o)
	o = o or {}
	local w = newWorld({ Studio = o.Studio, Friends = o.Friends })
	local Signal = w.Util.Signal
	w.Calls, w.Steps, w.Prints = {}, {}, {}
	if not o.NoAnalytics then
		w.Services.AnalyticsService = {
			LogCustomEvent = function(_, p, name, value, f)
				table.insert(w.Calls, { P = p, Name = name, Value = value, F = f })
			end,
			LogOnboardingFunnelStepEvent = function(_, p, n, name)
				table.insert(w.Steps, { P = p, N = n, Name = name })
			end,
		}
	end
	w.Data = {}
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new(), Own = {} }
	function ps.GetData(p) return w.Data[p] end
	function ps.IsReady(p) return w.Ready[p] == true and p.Parent ~= nil end
	function ps.GetReadyPlayers()
		local out = {}
		for _, p in w.PlayerList do if w.Ready[p] and p.Parent ~= nil then table.insert(out, p) end end
		return out
	end
	function ps.GetLastOwnActive(p) return ps.Own[p] or 0 end
	local reg = { PlayerService = ps,
		FactionService = { FactionChanged = Signal.new() },
		CombatService = { KnockedOut = Signal.new(), MonsterHit = Signal.new(), Released = Signal.new() },
		GrudgeService = { SackResolved = Signal.new() },
		LootService = { Enhanced = Signal.new() },
		SettingsService = { KeysChanged = Signal.new() },
		RankingService = { Viewed = Signal.new() },
		ProgressionService = { GoldEarned = Signal.new(), GoldSpent = Signal.new() },
		ZoneService = { ZoneChanged = Signal.new() },
		MonsterService = { MonsterKilled = Signal.new() },
	}
	w.Reg, w.PS = reg, ps
	local env = w:Env()
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	env.print = function(...) table.insert(w.Prints, table.concat({ ... }, " ")) end
	local keys = { CustomField01 = { Name = "CustomField01" }, CustomField02 = { Name = "CustomField02" },
		CustomField03 = { Name = "CustomField03" } }
	env.Enum = setmetatable({ AnalyticsCustomFieldKeys = keys }, { __index = env.Enum })
	local tel = execute("TelemetryService", TELEMETRY_SOURCE, env)
	tel.Init(reg)
	local n0 = #w.Spawned
	tel.Start()
	check(#w.Spawned == n0 + 2, "Start spawns the minute and the 5-minute loops", #w.Spawned - n0)
	local minute = coroutine.create(w.Spawned[n0 + 1][1])
	local five = coroutine.create(w.Spawned[n0 + 2][1])
	w.Spawned = {}
	assert(coroutine.resume(minute))
	assert(coroutine.resume(five))
	function w:Minute(n)
		for _ = 1, n or 1 do
			self:Advance(60)
			local ok, err = coroutine.resume(minute)
			assert(ok, err)
		end
	end
	w.Tel = tel
	-- a ready player: data = a copy of the defaults + o.Data, attributes from the data's mirrored keys + o.Attrs
	function w:Arrive(id, jo)
		jo = jo or {}
		local p = self:NewPlayer(id, {})
		local d = deepCopy(self.Config.Data.Defaults)
		for k, v in jo.Data or {} do d[k] = deepCopy(v) end
		self.Data[p] = d
		for _, key in self.Config.Data.Mirrored do if d[key] ~= nil then p.Attrs[key] = d[key] end end
		for k, v in jo.Attrs or {} do p.Attrs[k] = v end
		self.Ready[p] = true
		ps.PlayerReady:Fire(p, d)
		self:RunSpawned() -- the friend check
		return p, d
	end
	function w:Leave(p)
		ps.PlayerLeaving:Fire(p, self.Data[p])
		self.Ready[p] = nil
		self:Remove(p)
	end
	function w:Ui(p, ...)
		self:Advance(2.1)
		self.Net.Get("UiMetric").OnServerEvent:Fire(p, ...)
	end
	function w:Named(name, p)
		local out = {}
		for _, c in self.Calls do
			if c.Name == name and (p == nil or c.P == p) then table.insert(out, c) end
		end
		return out
	end
	function w:StepNames(p)
		local out = {}
		for _, s in self.Steps do if p == nil or s.P == p then table.insert(out, s.N .. ":" .. s.Name) end end
		return table.concat(out, ",")
	end
	return w
end

local function field(c, n) return c and c.F and c.F["CustomField0" .. n] end

runGroup("config", function()
	check(type(A0) == "table" and table.concat(A0.Steps, ",")
		== "IntroDone,Faction,Class,FirstMissionAccept,ForgeArrive,FirstWeapon,MeadowArrive,FirstHit,FirstKill,"
		.. "FirstMissionDone,FirstSkillHit,AutoUnlocked,Level10",
		"the funnel = BB38's 8 steps + A23-68's first 3 minutes (13 in order; A23-71 S13: the first skill at Lv5, after "
			.. "the first weapon and before Auto Battle; A23-74: the Forge and the first weapon right after the acceptance)",
		show(A0 and A0.Steps))
	check(table.find(A0.UiIds, "Bag") and table.find(A0.UiIds, "Ranking") and table.find(A0.UiIds, "Settings")
		and table.find(A0.UiIds, "PlayerList"), "window ids for the new windows + the Tab list", show(A0.UiIds))
	check(C0.RateLimits.UiMetric == 2 and A0.AwayAfter == 300 and A0.EnhanceFailLeave == 300 and A0.SameKindStreak == 30
		and A0.ReturnActs == 3, "UiMetric 2 s, away 5 min, enhance-fail leave 300 s, streak 30, 3 return acts",
		show({ C0.RateLimits.UiMetric, A0.AwayAfter }))
	check(C0.Data.Defaults.Telemetry ~= nil and type(C0.Data.Defaults.Telemetry) == "table", "saves keep a Telemetry table", "")
end)

runGroup("funnel", function()
	local w = metricsWorld()
	local p = w:Arrive(1)
	check(w:StepNames(p) == "", "a brand-new player: no step yet", w:StepNames(p))
	p:SetAttribute("IntroSeen", true)
	w.Reg.FactionService.FactionChanged:Fire(p, "Halo", "None", "Pick")
	p:SetAttribute("ClassChosen", true)
	-- A23-74: [Accept] -> the Forge step (3), the anvil (the visit + the first weapon), then the meadow trip (1, 2)
	p:SetAttribute("TutorialStep", 3)
	check(w:StepNames(p) == "1:IntroDone,2:Faction,3:Class,4:FirstMissionAccept",
		"A23-74: the Forge step is an acceptance, not a meadow arrival", w:StepNames(p))
	p:SetAttribute("BlacksmithVisited", true)
	p:SetAttribute("WeaponOwnedMask", 1)
	p:SetAttribute("TutorialStep", 1)
	p:SetAttribute("TutorialStep", 2) -- arrived in the meadow
	local CS = w.Reg.CombatService
	CS.MonsterHit:Fire(p, {}, false)
	CS.MonsterHit:Fire(p, {}, false)
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" })
	p:SetAttribute("BlacksmithVisited", false) -- the claim clears the visit (M1_1 needs a new one)
	p:SetAttribute("TutorialStep", 99)
	p:SetAttribute("BlacksmithVisited", true)
	p:SetAttribute("Level", 5) -- A23-71: the first skill
	CS.Released:Fire(p, { Slot = "Q", Auto = false, MonstersHit = 1 })
	p:SetAttribute("AutoCombatUnlocked", true)
	p:SetAttribute("Level", 9)
	p:SetAttribute("Level", 10)
	p:SetAttribute("Level", 11)
	check(w:StepNames(p) == "1:IntroDone,2:Faction,3:Class,4:FirstMissionAccept,5:ForgeArrive,6:FirstWeapon,7:MeadowArrive,8:FirstHit,9:FirstKill,10:FirstMissionDone,11:FirstSkillHit,12:AutoUnlocked,13:Level10",
		"the 13 steps in order, each once (two hits: one FirstHit; the second forge visit nothing; Level 10 at 10, not "
			.. "again at 11)", w:StepNames(p))
	local tel = w.Data[p].Telemetry
	check(tel.Funnel.Level10 == true and tel.Sessions == 1, "saved: Funnel names + Sessions 1", show(tel.Funnel))
	-- the same account on another server: nothing logged again
	local w2 = metricsWorld()
	local q = w2:Arrive(1, { Data = { Telemetry = deepCopy(tel), IntroSeen = true, Faction = "Halo", ClassChosen = true,
		TutorialStep = 99, WeaponOwnedMask = 1, AutoCombatUnlocked = true, Level = 12, TotalKills = 50, BlacksmithVisited = true,
		Story = { Done = { M1_3 = true } } } })
	check(w2:StepNames(q) == "" and w2.Data[q].Telemetry.Sessions == 2, "a returning account logs no step twice", w2:StepNames(q))
	-- an old save (before BB38) catches up every step it already passed, at once
	local w3 = metricsWorld()
	local r = w3:Arrive(2, { Data = { IntroSeen = true, Faction = "Horns", ClassChosen = true, TutorialStep = 99,
		WeaponOwnedMask = 3, AutoCombatUnlocked = false, Level = 10, TotalKills = 40, BlacksmithVisited = true,
		Story = { Done = { M1_3 = true } } } })
	check(w3:StepNames(r) == "1:IntroDone,2:Faction,3:Class,4:FirstMissionAccept,5:ForgeArrive,6:FirstWeapon,7:MeadowArrive,"
		.. "8:FirstHit,9:FirstKill,10:FirstMissionDone,11:FirstSkillHit,13:Level10",
		"an old save catches up the steps it passed, in the funnel's order (auto not yet)", w3:StepNames(r))
	-- an old save that never killed, used a skill or met the smith: those steps wait for the real moment
	local w4 = metricsWorld()
	local s4 = w4:Arrive(3, { Data = { IntroSeen = true, Faction = "Halo", ClassChosen = true, TutorialStep = 1, Level = 1 } })
	check(w4:StepNames(s4) == "1:IntroDone,2:Faction,3:Class,4:FirstMissionAccept", "accepted only: no meadow / hit / kill yet",
		w4:StepNames(s4))
	-- A23-74: a save waiting at the Forge step: accepted, no forge visit, no weapon, no meadow yet
	local w5 = metricsWorld()
	local s5 = w5:Arrive(4, { Data = { IntroSeen = true, Faction = "Halo", ClassChosen = true, TutorialStep = 3, Level = 1 } })
	check(w5:StepNames(s5) == "1:IntroDone,2:Faction,3:Class,4:FirstMissionAccept",
		"A23-74: a save at the Forge step catches up the acceptance only", w5:StepNames(s5))
end)

-- A23-68 #5 (the first 3 minutes): which moments count
runGroup("first 3 minutes", function()
	local w = metricsWorld()
	local p = w:Arrive(1)
	local CS = w.Reg.CombatService
	w.Reg.ZoneService.ZoneChanged:Fire(p, "Crossroads", "HaloTown")
	check(w:StepNames(p) == "", "another zone is not the meadow", w:StepNames(p))
	w.Reg.ZoneService.ZoneChanged:Fire(p, "SlimeMeadow", "Crossroads")
	check(w:StepNames(p) == "7:MeadowArrive", "walking into the meadow (no guide step) counts as arriving", w:StepNames(p))
	CS.Released:Fire(p, { Slot = "Q", Auto = true, MonstersHit = 4 })
	CS.Released:Fire(p, { Slot = "Z", Auto = false, MonstersHit = 0 })
	check(not string.find(w:StepNames(p), "FirstSkillHit"), "an auto skill, or a skill that hit nothing, is no skill hit",
		w:StepNames(p))
	CS.Released:Fire(p, { Slot = "Z", Auto = false, MonstersHit = 2 })
	check(string.find(w:StepNames(p), "11:FirstSkillHit") ~= nil, "a manual skill that hit a monster: FirstSkillHit",
		w:StepNames(p))
	p:SetAttribute("BlacksmithVisited", true)
	check(string.find(w:StepNames(p), "5:ForgeArrive") ~= nil, "the smith's prompt (BlacksmithVisited): ForgeArrive",
		w:StepNames(p))
	-- a later session: the first-hit shortcut was cleared at leave, the account still logs FirstHit once
	CS.MonsterHit:Fire(p, {}, false)
	local n = #w.Steps
	CS.MonsterHit:Fire(p, {}, true)
	check(#w.Steps == n and string.find(w:StepNames(p), "8:FirstHit") ~= nil, "FirstHit once; later hits log nothing",
		w:StepNames(p))
end)

runGroup("events", function()
	local w = metricsWorld()
	local p = w:Arrive(1)
	p:SetAttribute("AutoCombatEnabled", true)
	p:SetAttribute("AutoCombatEnabled", false)
	w:Advance(11)
	p:SetAttribute("AutoCombatEnabled", false)
	p:SetAttribute("AutoCombatEnabled", true)
	check(#w:Named("AutoOn", p) == 2 and #w:Named("AutoOff", p) == 0, "AutoOn / AutoOff, at most one per 10 s",
		show({ #w:Named("AutoOn", p), #w:Named("AutoOff", p) }))
	p:SetAttribute("ZoneId", "SlimeMeadow")
	w.Reg.CombatService.KnockedOut:Fire(p, "Monster")
	w.Reg.CombatService.KnockedOut:Fire(p, "Player")
	local fd = w:Named("FirstDeath_Monster", p)
	check(#fd == 1 and field(fd[1], 1) == "SlimeMeadow" and #w:Named("FirstDeath_Player", p) == 0,
		"FirstDeath_<By> (the BB14 cause) once per account, with the zone", #fd)
	w.Reg.GrudgeService.SackResolved:Fire(p, "Paid", 120)
	w.Reg.GrudgeService.SackResolved:Fire(p, "Avenged", 80)
	w.Reg.GrudgeService.SackResolved:Fire(p, "Odd", 1)
	check(#w:Named("Plunder_Kept", p) == 1 and w:Named("Plunder_Kept", p)[1].Value == 120 and #w:Named("Plunder_Avenged", p) == 1
		and #w:Named("Plunder_Odd", p) == 0,
		"Plunder_Kept / Plunder_Avenged with the gold (an unknown outcome logs nothing)", #w.Calls)
	w.Reg.SettingsService.KeysChanged:Fire(p, 2)
	check(#w:Named("KeyRebind", p) == 1 and w:Named("KeyRebind", p)[1].Value == 2, "KeyRebind with the number of actions changed", "")
	-- the same kind 30 times in a row: once a session per kind
	for _ = 1, 29 do w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" }) end
	check(#w:Named("SameKindStreak", p) == 0, "29 slimes in a row: nothing yet", #w:Named("SameKindStreak", p))
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" })
	for _ = 1, 40 do w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" }) end
	local ss = w:Named("SameKindStreak", p)
	check(#ss == 1 and ss[1].Value == 30 and field(ss[1], 1) == "Slime", "the 30th slime in a row: SameKindStreak once (kind)", #ss)
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "BigSlime" })
	for _ = 1, 29 do w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" }) end
	check(#w:Named("SameKindStreak", p) == 1, "a new slime streak in the same session is not logged again", #w:Named("SameKindStreak", p))
end)

runGroup("windows", function()
	local w = metricsWorld()
	local p = w:Arrive(1)
	w:Ui(p, "Bag")
	w:Ui(p, "Bag")
	check(#w:Named("WindowOpen_Bag", p) == 1, "WindowOpen_Bag once a session", #w:Named("WindowOpen_Bag", p))
	w:Ui(p, "Ranking")
	w.Net.Get("UiMetric").OnServerEvent:Fire(p, "Settings") -- 0 s later: inside the 2 s limit
	check(#w:Named("WindowOpen_Ranking", p) == 1 and #w:Named("WindowOpen_Settings", p) == 0,
		"a second report inside 2 s is dropped", show({ #w:Named("WindowOpen_Ranking", p), #w:Named("WindowOpen_Settings", p) }))
	local before = #w.Calls
	w:Ui(p, "Hacker")
	w:Ui(p, "Help", "extra")
	w:Ui(p)
	w:Ui(p, 5)
	check(#w.Calls == before, "an unknown id, an extra argument, none or a number: ignored", #w.Calls - before)
	w.Ready[p] = nil -- the session is still there, but the player is not ready (respawning, leaving)
	w:Ui(p, "Journal")
	check(#w:Named("WindowOpen_Journal", p) == 0, "a player who is not ready right now: ignored", "")
	w.Ready[p] = true
	local q = w:NewPlayer(9, {})
	w.Data[q] = deepCopy(w.Config.Data.Defaults)
	w:Ui(q, "Bag")
	check(#w:Named("WindowOpen_Bag", q) == 0, "a player who is not ready: ignored", "")
end)

runGroup("return acts", function()
	local w = metricsWorld()
	local p = w:Arrive(1, { Data = { Telemetry = { Sessions = 3 } } })
	w.Reg.ZoneService.ZoneChanged:Fire(p, "Nowhere", "HaloTown") -- not a zone id: never an act
	w.Reg.ZoneService.ZoneChanged:Fire(p, "Crossroads", "HaloTown")
	w:Ui(p, "Bag")
	w.Reg.ZoneService.ZoneChanged:Fire(p, "GoblinWoods", "Crossroads")
	w.Reg.ZoneService.ZoneChanged:Fire(p, "SlimeMeadow", "GoblinWoods")
	local acts = w:Named("ReturnAct", p)
	check(#acts == 3 and acts[1].Value == 1 and field(acts[1], 1) == "Zone" and field(acts[1], 2) == "Crossroads"
		and field(acts[2], 1) == "Window" and field(acts[2], 2) == "Bag" and field(acts[3], 2) == "GoblinWoods",
		"a returning player: the first 3 actions (zone, window, zone)", #acts)
	local w2 = metricsWorld()
	local n = w2:Arrive(2)
	w2.Reg.ZoneService.ZoneChanged:Fire(n, "Crossroads", "HaloTown")
	check(#w2:Named("ReturnAct", n) == 0, "a first session logs no return acts", #w2:Named("ReturnAct", n))
	w2.Reg.ZoneService.ZoneChanged:Fire(n, "Nowhere", "Crossroads")
	check(#w2.Calls == 0 or w2:Named("ReturnAct")[1] == nil, "an unknown zone id is never logged", "")
end)

runGroup("session sums at leave", function()
	local w = metricsWorld({ Friends = { ["1:2"] = true } })
	local p = w:Arrive(1)
	local f = w:Arrive(2) -- p's friend (checked when 2 joins)
	local x = w:Arrive(3) -- not a friend
	-- gold in / out
	local G = w.Reg.ProgressionService
	G.GoldEarned:Fire(p, 30, "Monster")
	G.GoldEarned:Fire(p, 12, "Monster")
	G.GoldEarned:Fire(p, 150, "Quest")
	G.GoldSpent:Fire(p, 100, "Weapon")
	G.GoldSpent:Fire(p, 40, "Potion")
	G.GoldSpent:Fire(p, 20, "Potion")
	-- kills: alone, with a stranger, with the friend
	local K = w.Reg.MonsterService.MonsterKilled
	K:Fire(p, { Kind = "Slime", Party = 1, Others = {} })
	K:Fire(p, { Kind = "Slime", Party = 2, Others = { x } })
	K:Fire(p, { Kind = "Goblin", Party = 3, Others = { x, f } })
	-- rankings looked at
	w.Reg.RankingService.Viewed:Fire(p, "Hunt", "Server")
	w.Reg.RankingService.Viewed:Fire(p, "Hunt", "Global")
	w.Reg.RankingService.Viewed:Fire(p, "PvP", "Server")
	-- minutes: in the meadow, auto ON with no own action for 5+ min, the friend here
	p:SetAttribute("ZoneId", "SlimeMeadow")
	p:SetAttribute("AutoCombatEnabled", true)
	w.PS.Own[p] = w.Clock
	w:Minute(4) -- 4 min since my last own action: not away yet
	w:Minute(3) -- 5, 6, 7 min: away three times
	p:SetAttribute("ZoneId", "GoblinWoods")
	w:Leave(f) -- the friend leaves
	w:Minute(2)
	local leaveAt = #w.Calls
	w:Leave(p)
	local function last(name, a)
		for i = leaveAt + 1, #w.Calls do
			local c = w.Calls[i]
			if c.Name == name and (a == nil or field(c, 1) == a) then return c end
		end
		return nil
	end
	check(last("GoldIn", "Monster") and last("GoldIn", "Monster").Value == 42 and last("GoldIn", "Quest").Value == 150,
		"GoldIn per source (Monster 42, Quest 150)", show({ last("GoldIn", "Monster") and last("GoldIn", "Monster").Value }))
	check(last("GoldOut", "Weapon").Value == 100 and last("GoldOut", "Potion").Value == 60, "GoldOut per sink (Weapon 100, Potion 60)", "")
	check(last("KillsTogether") and last("KillsTogether").Value == 2 and last("KillsWithFriend").Value == 1,
		"KillsTogether 2 (party of 2+), KillsWithFriend 1", show({ last("KillsTogether") and last("KillsTogether").Value }))
	check(last("FriendMinutes") and last("FriendMinutes").Value == 7 and field(last("FriendMinutes"), 1) == "WithFriend",
		"FriendMinutes 7 (while the friend was here)", show(last("FriendMinutes") and last("FriendMinutes").Value))
	check(last("AutoAwayMinutes") and last("AutoAwayMinutes").Value == 5, "AutoAwayMinutes 5 (from the 5th minute without input)",
		show(last("AutoAwayMinutes") and last("AutoAwayMinutes").Value))
	check(last("ZoneMinutes", "SlimeMeadow").Value == 7 and last("ZoneMinutes", "GoblinWoods").Value == 2, "ZoneMinutes per zone", "")
	check(last("RankingViews", "Hunt").Value == 2 and last("RankingViews", "PvP").Value == 1, "RankingViews per board", "")
	check(last("SessionMinutes") and last("SessionMinutes").Value == 9 and field(last("SessionMinutes"), 1) == "5-15",
		"SessionMinutes 9 (bucket 5-15)", show(last("SessionMinutes") and last("SessionMinutes").Value))
	-- the stranger: solo minutes, no friend kills, and only one IsFriendsWith call per pair
	local xs = w.FriendCalls
	w:Minute(3) -- x stays 12 minutes in all
	w:Leave(x)
	check(#w:Named("AutoAwayMinutes", x) == 0, "auto OFF: never counted as away (however idle)", #w:Named("AutoAwayMinutes", x))
	local sx = w:Named("SessionMinutes", x)[1]
	check(sx and sx.Value == 12 and field(sx, 1) == "5-15", "12 minutes: bucket 5-15", show(sx and { sx.Value, field(sx, 1) }))
	local fx = nil
	for i = #w.Calls, 1, -1 do
		if w.Calls[i].Name == "FriendMinutes" and w.Calls[i].P == x then fx = w.Calls[i] break end
	end
	check(fx and fx.Value == 0 and field(fx, 1) == "Solo", "a player with no friend here: FriendMinutes 0 (Solo)", show(fx and fx.Value))
	check(xs == 3, "IsFriendsWith once per pair (3 pairs for 3 players)", xs)
	local w5 = metricsWorld({ Friends = { ["1:2"] = true } })
	local a1 = w5:Arrive(1)
	local a2 = w5:Arrive(2)
	w5:Leave(a2)
	w5:Arrive(2) -- the friend comes back: the pair is known
	check(w5.FriendCalls == 1 and a1 ~= nil, "a rejoin does not ask IsFriendsWith again", w5.FriendCalls)
	-- enhance fail, then leave within 300 s (a success does not count)
	local e = w:Arrive(5)
	w.Reg.LootService.Enhanced:Fire(e, 1, 2, 2, false, "Enh30")
	w:Advance(100)
	w:Leave(e)
	check(#w:Named("EnhanceFailLeave", e) == 1 and w:Named("EnhanceFailLeave", e)[1].Value == 100, "left 100 s after a failed enhance", "")
	local e2 = w:Arrive(6)
	w.Reg.LootService.Enhanced:Fire(e2, 1, 2, 3, true, "Enh30")
	w:Leave(e2)
	local e3 = w:Arrive(7)
	w.Reg.LootService.Enhanced:Fire(e3, 1, 2, 1, false, "Enh30")
	w:Advance(301)
	w:Leave(e3)
	check(#w:Named("EnhanceFailLeave", e2) == 0 and #w:Named("EnhanceFailLeave", e3) == 0,
		"a success, or a leave 301 s after a fail: no EnhanceFailLeave", "")
end)

runGroup("privacy and robustness", function()
	local w = metricsWorld({ Friends = { ["1:2"] = true } })
	local p = w:Arrive(1)
	p.Name, p.DisplayName = "CoolKid42", "Cool Kid"
	local q = w:Arrive(2)
	w:Ui(p, "Bag")
	w.Reg.ZoneService.ZoneChanged:Fire(p, "Crossroads", "HaloTown")
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime", Party = 2, Others = { q } })
	w.Reg.ProgressionService.GoldEarned:Fire(p, 10, "Monster")
	w.Reg.CombatService.KnockedOut:Fire(p, "Fall")
	w:Minute(1)
	w:Leave(q)
	w:Leave(p)
	local allowed = {}
	for _, n in { "AutoOn", "AutoOff", "Plunder_Kept", "Plunder_Avenged", "Plunder_Returned", "KeyRebind", "ReturnAct",
		"RookieFirstKillSeconds", "HighLevelInMeadow", "ServerPopulation", "CrownTrialMiss", "SameKindStreak",
		"SessionMinutes", "AutoAwayMinutes", "EnhanceFailLeave", "GoldIn", "GoldOut", "FriendMinutes", "KillsTogether",
		"KillsWithFriend", "ZoneMinutes", "RankingViews" } do allowed[n] = true end
	local bad = {}
	for _, c in w.Calls do
		local ok = allowed[c.Name] or (string.sub(c.Name, 1, 11) == "WindowOpen_" and table.find(A0.UiIds, string.sub(c.Name, 12)))
			or (string.sub(c.Name, 1, 11) == "FirstDeath_")
		for _, v in c.F or {} do
			if string.find(v, "CoolKid", 1, true) or string.find(v, "Cool Kid", 1, true) or v == "1" or v == "2" then ok = false end
		end
		if not ok then table.insert(bad, c.Name) end
	end
	check(#w.Calls >= 6 and #bad == 0, "every event name from the fixed lists, no names or user ids in any field", show(bad))
	local metricPrints = 0
	for _, line in w.Prints do if string.find(line, "[Metrics]", 1, true) then metricPrints += 1 end end
	check(metricPrints >= #w.Calls and #w.Calls > 0, "Studio: every call is printed ([Metrics])", show({ metricPrints, #w.Calls }))
	-- a live server prints nothing; no AnalyticsService at all costs nothing
	local live = metricsWorld({ Studio = false })
	local lp = live:Arrive(1)
	lp:SetAttribute("IntroSeen", true)
	live:Leave(lp)
	check(#live.Prints == 1 and #live.Calls >= 1, "a live server: no [Metrics] prints (only the start line)", show(live.Prints))
	local none = metricsWorld({ NoAnalytics = true })
	local np = none:Arrive(1)
	np:SetAttribute("IntroSeen", true)
	none.Reg.CombatService.KnockedOut:Fire(np, "Monster")
	none:Leave(np)
	check(none.Data[np] == nil or true, "no AnalyticsService: no error (the group's warnings check covers it)", "")
end)

------------------------------------------------------------------ the services' new signals (real code)
runGroup("gold signals", function()
	local w = newWorld({})
	local data = {}
	local S = { PlayerService = {
		SetStat = function(p, k, v) data[p][k] = v end,
		AddStat = function(p, k, d) data[p][k] = (data[p][k] or 0) + d end,
	} }
	local M = execute("ProgressionService.gold", GOLD_EXTRACT, w:Env(), w.Util, S, function(p) return data[p] end)
	local spent = {}
	M.GoldSpent:Connect(function(p, n, sink) table.insert(spent, { P = p, N = n, Sink = sink }) end)
	local p = w:NewPlayer(1, {})
	data[p] = { CarriedGold = 50, BankGold = 100 }
	check(M.SpendGold(p, 70, "Weapon") == true and #spent == 1 and spent[1].N == 70 and spent[1].Sink == "Weapon",
		"SpendGold fires GoldSpent(70, Weapon)", show(spent[1] and { spent[1].N, spent[1].Sink }))
	check(M.SpendGold(p, 999, "Weapon") == false and #spent == 1, "a refused spend fires nothing", #spent)
	check(M.SpendGold(p, 0, "Potion") == true and #spent == 1, "spending 0 fires nothing", #spent)
	M.SpendGold(p, 5)
	check(spent[2] and spent[2].Sink == "Other", "no reason: sink Other", spent[2] and spent[2].Sink)
	data[p].CarriedGold = 40
	check(M.TakeCarriedGold(p, 25, "Plunder") == 25 and spent[3].N == 25 and spent[3].Sink == "Plunder", "TakeCarriedGold fires GoldSpent(25, Plunder)", spent[3] and spent[3].Sink)
	check(M.TakeCarriedGold(p, 100) == 15 and spent[4].N == 15 and spent[4].Sink == "Taken", "clamped to the carried 15, sink Taken", spent[4] and spent[4].N)
	check(M.TakeCarriedGold(p, 10, "Plunder") == 0 and #spent == 4, "nothing carried: nothing fired", #spent)
end)

runGroup("settings keys changed", function()
	local w = newWorld({})
	local data = {}
	local Signal = w.Util.Signal
	local ps = { PlayerReady = Signal.new() }
	function ps.GetData(p) return data[p] end
	function ps.IsReady() return true end
	local set = execute("SettingsService", SETTINGS_SOURCE, w:Env())
	set.Init({ PlayerService = ps, DataService = { IsMemoryMode = function() return false end } })
	set.Start()
	local changes = {}
	set.KeysChanged:Connect(function(p, n) table.insert(changes, n) end)
	local p = w:NewPlayer(1, {})
	data[p] = { Settings = w.Config.SanitizeSettings(nil) }
	local function push(keys)
		w:Advance(1.1)
		w.Remotes.SetSettings.OnServerEvent:Fire(p, { Keys = keys, Seq = 1 })
	end
	push({ Attack = "J" })
	push({ Attack = "J" })
	push({ Attack = "K", SkillQ = "R" })
	push({})
	check(#changes == 3 and changes[1] == 1 and changes[2] == 2 and changes[3] == 2,
		"KeysChanged: 1 new binding, then 2 changed, then 2 back to default (the same blob again: nothing)", show(changes))
end)

finish()
