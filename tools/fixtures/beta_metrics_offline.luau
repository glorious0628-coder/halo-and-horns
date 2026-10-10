-- beta_metrics_offline.luau : A23-79 beta metrics (게임성 개발 3; docs/design/retention_round_2026-10-08.md "베타에서 잴
-- 것"). tools/test_beta_metrics.py binds CONFIG_SOURCE, UTIL_SOURCE and TELEMETRY_SOURCE in front of dev2_kit.luau +
-- dev3_world.luau; this file follows. TelemetryService runs from source on the dev3_world doubles plus an
-- AnalyticsService double that records every funnel step, custom event and economy event; the new services it listens
-- to (Attendance / Return / Invite / Diary / Monetization / StoryQuest) are signal doubles. Its two loops are stepped by
-- hand (w:Minute, w:Five).

local NOON = 1789959600 -- 2026-09-22 12:00 KST

local function metricsWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	local Signal = w.Util.Signal
	w.Funnel, w.Custom, w.Econ, w.Onboard = {}, {}, {}, {}
	if not o.NoAnalytics then
		w.Services.AnalyticsService = {
			LogCustomEvent = function(_, p, name, value, f) table.insert(w.Custom, { P = p, Name = name, Value = value, F = f }) end,
			LogOnboardingFunnelStepEvent = function(_, p, n, name) table.insert(w.Onboard, { P = p, N = n, Name = name }) end,
			LogFunnelStepEvent = function(_, p, funnel, sid, n, name)
				table.insert(w.Funnel, { P = p, Funnel = funnel, Sid = sid, N = n, Name = name })
			end,
			LogEconomyEvent = function(_, p, flow, currency, amount, balance, kind, sku)
				table.insert(w.Econ, { P = p, Flow = flow, Currency = currency, Amount = amount, Balance = balance, Kind = kind, Sku = sku })
			end,
		}
	end
	w.Reg.AttendanceService = { Claimed = Signal.new() }
	w.Reg.QuestService = { ForgeReached = Signal.new() } -- A23-88 (walking to the Forge)
	w.Reg.ReturnService = { CardShown = Signal.new(), Welcomed = Signal.new() }
	w.Reg.InviteService = { InviteJoined = Signal.new(), PlayedTogether = Signal.new(), WentToFriend = Signal.new() }
	w.Reg.DiaryService = { PageOpened = Signal.new(), CandyTraded = Signal.new() }
	w.Reg.MonetizationService.PassBought = Signal.new()
	w.Reg.StoryQuestService.StepDone = Signal.new() -- A23-113 #2 (the steps of a funnel quest)
	w.Reg.PvPService = { PlayerKO = Signal.new() } -- A23-113 #5
	w.Reg.JusticeService = { GetFactionScale = function(f) return f == "Halo" and 1.3 or f == "Horns" and 1.05 or 1 end }
	local env = w:Env()
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	local keys = { CustomField01 = { Name = "CustomField01" }, CustomField02 = { Name = "CustomField02" },
		CustomField03 = { Name = "CustomField03" } }
	env.Enum = setmetatable({ AnalyticsCustomFieldKeys = keys,
		AnalyticsEconomyFlowType = { Source = "Flow.Source", Sink = "Flow.Sink" } }, { __index = env.Enum })
	local tel = execute("TelemetryService", TELEMETRY_SOURCE, env)
	w.Reg.TelemetryService = tel
	w.Tel = tel
	tel.Init(w.Reg)
	tel.Start()
	w:StartLoops() -- [1] = the minute loop, [2] = the 5-minute loop
	function w:Minute()
		self:Advance(60)
		assert(coroutine.resume(self.Loops[1]))
	end
	function w:Five()
		self:Advance(300)
		assert(coroutine.resume(self.Loops[2]))
	end
	function w:Steps(p, funnel)
		local out = {}
		for _, f in self.Funnel do
			if (p == nil or f.P == p) and (funnel == nil or f.Funnel == funnel) then table.insert(out, f.N .. ":" .. f.Name) end
		end
		return table.concat(out, ",")
	end
	function w:Named(name, p)
		local out = {}
		for _, c in self.Custom do
			if c.Name == name and (p == nil or c.P == p) then table.insert(out, c) end
		end
		return out
	end
	function w:Metric(p, ...) self:Remote("ClientMetric", p, ...) end
	return w
end

local function field(c, n) return c and c.F and c.F["CustomField0" .. n] end

local function hero(w, id, jo)
	jo = jo or {}
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 3, TutorialStep = 99,
		DailyDay = w.Config.DayIndex(w.Time) } -- today's dailies (QuestService's day check already ran)
	for k, v in jo.Data or {} do data[k] = v end
	jo.Data = data
	return w:Arrive(id, jo)
end

local function withPasses(c)
	c.GamePasses = { XP2 = { Id = 0 }, Gold2 = { Id = 0 }, VIP = { Id = 0 } }
	c.Looks = { HaloIce = { Faction = "Halo", PassId = 0 } }
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local A = C.Analytics
	local names = {}
	for name in A.Funnels do table.insert(names, name) end
	table.sort(names)
	check(table.concat(names, ",") == "DailyVisit,FirstKO,KingDiary,LongRoad,PassShop,Social" and #names + 1 <= 10,
		"6 funnels + the onboarding one (Roblox: at most 10)", table.concat(names, ","))
	check(table.concat(A.Funnels.FirstKO.Steps, ",") == "KO,PotionBought,SlotSet,PotionUsed,KingWon" and A.Funnels.FirstKO.Once == true
		and A.QuestFunnels.KO1 == "FirstKO" and #A.Funnels.FirstKO.Steps == #C.StoryQuests.Defs.KO1.Steps,
		"FirstKO: the five steps of KO1 in order, once per account (A23-113 #2)", show(A.Funnels.FirstKO))
	check(A.TimeToLevel.Level == 5 and A.TimeToLevel.Event == "MinutesToLv5" and A.PvPResultGap >= 1, "MinutesToLv5 at Lv5; PvPResult at most once a second per killer", show(A.TimeToLevel))
	-- review 2026-10-08: Roblox completes the earlier steps of a later one, so only steps that always come in order
	check(table.concat(A.Funnels.LongRoad.Steps, ",") == "Level15,Level25,Level30,Level40,Level50,Rebirth1"
		and A.Funnels.LongRoad.Once == true, "LongRoad: the level path (6 steps), once per account", show(A.Funnels.LongRoad))
	check(table.concat(A.Funnels.DailyVisit.Steps, ",") == "Join,Daily1,Daily3,SetChest,StopCardSeen"
		and not A.Funnels.DailyVisit.Once, "DailyVisit: 5 steps, a session per KST day (attendance = an event)",
		show(A.Funnels.DailyVisit))
	check(table.concat(A.Funnels.Social.Steps, ",") == "InviteSeen,InvitePrompt,InviteSent,InviteeJoined,PlayedTogether10m",
		"Social: 5 steps", show(A.Funnels.Social))
	check(table.concat(A.Funnels.KingDiary.Steps, ",") == "Page1,Page3,Page6,Page9", "KingDiary: 4 steps", "")
	check(table.concat(A.Funnels.PassShop.Steps, ",") == "ShopOpen,PassView,PurchasePrompt,Bought" and not A.Funnels.PassShop.Once,
		"PassShop: 4 steps, a session per shop visit", "")
	check(table.find(A.UiIds, "Shop") ~= nil, "the Shop window is a UiMetric id (it opens a PassShop visit)", "")
	check(table.find(A.UiIds, "Pet") ~= nil and table.find(A.UiIds, "Diary") ~= nil, "the Pet and Diary windows are UiMetric ids", show(A.UiIds))
	check(C.RateLimits.ClientMetric == 0.5 and A.KOLeave == 60 and A.PromptNearKO == 30, "limits: 0.5 s, 60 s, 30 s", "")
end)

runGroup("DailyVisit + DaysPlayed", function()
	local w = metricsWorld()
	local C = w.Config
	local p, d = hero(w, 1)
	local day = tostring(C.DayIndex(w.Time))
	check(w:Steps(p, "DailyVisit") == "1:Join" and w.Funnel[1].Sid == day, "the join: DailyVisit Join, session = the KST day",
		w:Steps(p, "DailyVisit") .. " " .. tostring(w.Funnel[1] and w.Funnel[1].Sid))
	local dp = w:Named("DaysPlayed", p)
	check(#dp == 1 and dp[1].Value == 1 and field(dp[1], 1) == "1-9" and field(dp[1], 2) == "Halo",
		"DaysPlayed: lifetime day 1, level band, faction", show(dp[1] and dp[1].F))
	w.Reg.AttendanceService.Claimed:Fire(p, 3, 8)
	check(w:Steps(p, "DailyVisit") == "1:Join", "the attendance claim is no funnel step (optional)", w:Steps(p, "DailyVisit"))
	local att = w:Named("Attendance", p)[1]
	check(att and att.Value == 8 and field(att, 1) == "3", "Attendance event: days collected, the slot", show(att and att.F))
	w.PS.SetStat(p, "DailyClaims", 1)
	check(w:Steps(p, "DailyVisit") == "1:Join,2:Daily1", "the first daily claimed", w:Steps(p, "DailyVisit"))
	-- two more dailies done (not claimed yet): Daily3 at the next minute
	d.Quests = { { Kind = "Daily", Progress = 5, Target = 5 }, { Kind = "Daily", Progress = 3, Target = 3 }, { Kind = "Extra" } }
	w:Minute()
	check(w:Steps(p, "DailyVisit") == "1:Join,2:Daily1,3:Daily3", "1 claimed + 2 done = all 3 done: Daily3", w:Steps(p, "DailyVisit"))
	w.Reg.ReturnService.CardShown:Fire(p, "Chapter")
	check(w:Steps(p, "DailyVisit") == "1:Join,2:Daily1,3:Daily3", "a chapter card is no StopCardSeen (it would fill SetChest)",
		w:Steps(p, "DailyVisit"))
	w.PS.SetStat(p, "DailyClaims", 3)
	w.Reg.ReturnService.CardShown:Fire(p, "Daily")
	check(w:Steps(p, "DailyVisit") == "1:Join,2:Daily1,3:Daily3,4:SetChest,5:StopCardSeen",
		"all claimed (the chest) + the daily card: the whole day's funnel", w:Steps(p, "DailyVisit"))
	check(field(w:Named("PauseCard", p)[1], 1) == "Chapter" and field(w:Named("PauseCard", p)[2], 1) == "Daily",
		"PauseCard events with Why (every card)", "")
	w.PS.SetStat(p, "DailyClaims", 2)
	w.PS.SetStat(p, "DailyClaims", 3)
	w.Reg.ReturnService.CardShown:Fire(p, "Daily")
	check(#w:Named("DaysPlayed", p) == 1 and select(2, string.gsub(w:Steps(p, "DailyVisit"), "SetChest", "")) == 1,
		"each step once a day", w:Steps(p, "DailyVisit"))
	-- the same day on another server: nothing again
	w:Leave(p)
	local w2 = metricsWorld({ Time = w.Time + 60 })
	local q, dq = hero(w2, 1, { Data = { Telemetry = deepCopy(d.Telemetry), DailyClaims = 3 } })
	check(w2:Steps(q, "DailyVisit") == "" and #w2:Named("DaysPlayed", q) == 0, "the same KST day again: no Join, no DaysPlayed",
		w2:Steps(q, "DailyVisit"))
	-- online across 00:00 KST: a new play day at the next minute tick; yesterday's claims (QuestService has not made the
	-- new day's dailies yet: DailyDay is yesterday) are not today's steps
	w2:ToDay(1, 10)
	w2:Minute()
	local dp2 = w2:Named("DaysPlayed", q)
	check(#dp2 == 1 and dp2[1].Value == 2 and w2:Steps(q, "DailyVisit") == "1:Join"
		and w2.Funnel[1].Sid == tostring(C.DayIndex(w2.Time)), "a day that turns while playing: DaysPlayed 2 + the new day's Join only",
		w2:Steps(q, "DailyVisit"))
	-- QuestService's day check: today's set, 0 claimed; a claim now is today's Daily1
	dq.DailyDay = C.DayIndex(w2.Time)
	w2.PS.SetStat(q, "DailyClaims", 0)
	w2.PS.SetStat(q, "DailyClaims", 1)
	check(w2:Steps(q, "DailyVisit") == "1:Join,2:Daily1", "after the day check: the new day's steps", w2:Steps(q, "DailyVisit"))
end)

runGroup("ReturnGap", function()
	local w = metricsWorld()
	local now = w.Time
	local cases = { { 0, nil }, { 3600, "<6h" }, { 7 * 3600, "6-24h" }, { 30 * 3600, "1-3d" }, { 2 * 86400, "1-3d" },
		{ 5 * 86400, "3d+" } }
	for i, c in cases do
		local p = hero(w, 10 + i, { Data = { LastLogoutTime = c[1] > 0 and now - c[1] or 0 } })
		local g = w:Named("ReturnGap", p)
		if c[2] == nil then
			check(#g == 0, "a brand-new save: no ReturnGap", #g)
		else
			check(#g == 1 and field(g[1], 1) == c[2], "ReturnGap bucket " .. c[2], show(g[1] and g[1].F))
		end
	end
end)

runGroup("LongRoad", function()
	local w = metricsWorld()
	local p = hero(w, 1, { Data = { Level = 14 } })
	check(w:Steps(p, "LongRoad") == "", "Lv14: nothing yet", w:Steps(p, "LongRoad"))
	p:SetAttribute("Level", 15)
	p:SetAttribute("Level", 16)
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M3_7")
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M1_4")
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M3_8")
	local ends = w:Named("ChapterEnd", p)
	check(#ends == 2 and ends[1].Value == 1 and ends[2].Value == 3, "ChapterEnd events for each chapter's last quest (no step)",
		tostring(#ends))
	w.PS.SetStat(p, "DailyClaims", 1)
	check(#w:Named("RuinsDaily", p) == 0, "a daily at Lv16: no RuinsDaily", "")
	p:SetAttribute("Level", 25)
	w.PS.SetStat(p, "DailyClaims", 2)
	w.PS.SetStat(p, "DailyClaims", 3)
	check(#w:Named("RuinsDaily", p) == 1, "the first daily at Lv25+: RuinsDaily once", #w:Named("RuinsDaily", p))
	p:SetAttribute("Level", 30)
	p:SetAttribute("Level", 41)
	p:SetAttribute("Level", 50)
	p:SetAttribute("Rebirths", 1)
	check(w:Steps(p, "LongRoad") == "1:Level15,2:Level25,3:Level30,4:Level40,5:Level50,6:Rebirth1",
		"the level path in order, each once (a skipped level counts: 41 >= 40)", w:Steps(p, "LongRoad"))
	check(w.Funnel[#w.Funnel].Sid == "once", "one session per account", tostring(w.Funnel[#w.Funnel].Sid))
	local w2 = metricsWorld()
	local q = hero(w2, 2, { Data = { Level = 45 } })
	check(w2:Steps(q, "LongRoad") == "1:Level15,2:Level25,3:Level30,4:Level40", "an old save catches up what it passed",
		w2:Steps(q, "LongRoad"))
	local w3 = metricsWorld()
	local r = hero(w3, 3, { Data = { Level = 45, Telemetry = deepCopy(w2.Data[q].Telemetry) } })
	check(w3:Steps(r, "LongRoad") == "", "the next visit logs nothing again", w3:Steps(r, "LongRoad"))
	local s = hero(w3, 4, { Data = { Level = 30, Telemetry = { RuinsDaily = true } } })
	w3.PS.SetStat(s, "DailyClaims", 1)
	check(#w3:Named("RuinsDaily", s) == 0, "RuinsDaily once per account (saved)", "")
end)

runGroup("Social + invites", function()
	local w = metricsWorld()
	local p = hero(w, 1)
	local q = hero(w, 2)
	w:Metric(p, "InviteSeen", "Nope")
	w:Metric(p, "InviteSeen")
	check(w:Steps(p, "Social") == "", "InviteSeen needs a known source", w:Steps(p, "Social"))
	w:Metric(p, "InviteSeen", "Menu")
	w:Metric(p, "InvitePrompt", "PlayerList")
	w:Metric(p, "InviteSent", 3)
	check(w:Steps(p, "Social") == "1:InviteSeen,2:InvitePrompt,3:InviteSent" and w:Named("InviteSent", p)[1].Value == 3,
		"seen, prompt, sent (InviteSent event value = friends picked)", w:Steps(p, "Social"))
	w.Reg.InviteService.InviteJoined:Fire(q, 1, p)
	check(field(w:Named("FriendJoin", q)[1], 1) == "InviterHere" and string.find(w:Steps(p, "Social"), "4:InviteeJoined") ~= nil,
		"the invitee: FriendJoin; the inviter here: InviteeJoined", w:Steps(p, "Social"))
	local r = hero(w, 3)
	w.Reg.InviteService.InviteJoined:Fire(r, 777, nil)
	check(field(w:Named("FriendJoin", r)[1], 1) == "InviterAway", "an inviter on another server: InviterAway", "")
	w.Reg.InviteService.PlayedTogether:Fire(p, q)
	check(string.find(w:Steps(p, "Social"), "5:PlayedTogether10m") ~= nil, "10 minutes together", w:Steps(p, "Social"))
	w.Reg.InviteService.WentToFriend:Fire(q, "SlimeMeadow")
	check(field(w:Named("GoToFriend", q)[1], 1) == "SlimeMeadow", "GoToFriend event with the zone", "")
	-- A23-88: the walk to the Forge: the seconds from [I'm In!] to the anvil
	w.Reg.QuestService.ForgeReached:Fire(p, 31.7)
	check(#w:Named("ForgeWalk", p) == 1 and w:Named("ForgeWalk", p)[1].Value == 31, "ForgeWalk = the whole seconds of the walk (31.7 -> 31)", "")
	for _, c in w.Custom do
		for i = 1, 3 do
			local v = field(c, i)
			check(v == nil or not string.find(v, "^%d%d%d+$"), "no UserId in any field", c.Name .. " " .. tostring(v))
		end
	end
end)

runGroup("KingDiary", function()
	local w = metricsWorld()
	local p = hero(w, 1)
	w.Reg.DiaryService.PageOpened:Fire(p, 1, false)
	w.Reg.DiaryService.PageOpened:Fire(p, 2, true)
	check(w:Steps(p, "KingDiary") == "1:Page1", "page 2: still only Page1", w:Steps(p, "KingDiary"))
	w.Reg.DiaryService.PageOpened:Fire(p, 3, true)
	check(w:Steps(p, "KingDiary") == "1:Page1,2:Page3", "pages 1 and 3 (2 is no step)", w:Steps(p, "KingDiary"))
	local pages = w:Named("DiaryPage", p)
	check(#pages == 3 and pages[1].Value == 1 and field(pages[1], 1) == "OnTime" and field(pages[3], 1) == "Late",
		"DiaryPage events: the page, late or on time", show(pages[3] and pages[3].F))
	local q = hero(w, 2, { Data = { Diary = { Pages = 7, Done = false } } })
	check(w:Steps(q, "KingDiary") == "1:Page1,2:Page3,3:Page6", "a save with 7 pages catches up at join", w:Steps(q, "KingDiary"))
	w.Reg.DiaryService.CandyTraded:Fire(q, "PumpkinPal", 50)
	local t = w:Named("CandyTrade", q)[1]
	check(t and t.Value == 50 and field(t, 1) == "PumpkinPal", "CandyTrade: candy, the jar id", show(t and t.F))
end)

runGroup("PassShop", function()
	local w = metricsWorld({ EditConfig = withPasses })
	local p = hero(w, 1)
	local function shop()
		local out = {}
		for _, f in w.Funnel do if f.Funnel == "PassShop" then table.insert(out, f) end end
		return out
	end
	w:Remote("UiMetric", p, "Shop")
	check(w:Steps(p, "PassShop") == "1:ShopOpen", "the Shop window opens a visit", w:Steps(p, "PassShop"))
	w:Metric(p, "PassView", "VIP")
	w:Metric(p, "PassView", "Gold2")
	w:Metric(p, "PurchasePrompt", "VIP")
	w.Reg.MonetizationService.PassBought:Fire(p, "VIP")
	check(w:Steps(p, "PassShop") == "1:ShopOpen,2:PassView,3:PurchasePrompt,4:Bought", "one visit: the 4 steps once each",
		w:Steps(p, "PassShop"))
	local sid1 = shop()[1].Sid
	w:Advance(5)
	w:Metric(p, "ShopOpen")
	check(#shop() == 4, "the shop again within ShopVisitGap (30 s): the same visit", tostring(#shop()))
	w:Advance(31)
	w:Metric(p, "ShopOpen")
	w:Metric(p, "PassView", "HaloIce")
	local list = shop()
	check(#list == 6 and list[5].Name == "ShopOpen" and list[5].Sid ~= sid1 and list[6].Sid == list[5].Sid,
		"a shop open 30 s later = a new visit (a new session id)", tostring(#list))
	w:Metric(p, "PassView", "Robux!")
	w:Metric(p, "PassView", 5)
	check(#shop() == 6, "an unknown pass id is ignored", tostring(#shop()))
	-- a pass card first (the client's window report comes later or not at all): the visit starts there
	local q = hero(w, 2)
	w:Metric(q, "PassView", "XP2")
	check(w:Steps(q, "PassShop") == "1:ShopOpen,2:PassView", "a pass card with no visit open starts one", w:Steps(q, "PassShop"))
	w:Advance(601)
	w.Reg.MonetizationService.PassBought:Fire(q, "XP2")
	check(w:Steps(q, "PassShop") == "1:ShopOpen,2:PassView", "a visit 10 minutes old is over: Bought outside it is not counted",
		w:Steps(q, "PassShop"))
	-- PromptNearKO (must stay 0): a buy window within 30 s of a KO / a failed scroll, once per moment
	w.Reg.CombatService.KnockedOut:Fire(p, "Monster")
	w:Advance(10)
	w:Metric(p, "PurchasePrompt", "VIP")
	w:Metric(p, "PurchasePrompt", "Gold2")
	local near = w:Named("PromptNearKO", p)
	check(#near == 1 and field(near[1], 1) == "KO" and field(near[1], 2) == "VIP", "buy windows 10 s after a KO: PromptNearKO once",
		show(near[1] and near[1].F))
	w:Advance(40)
	w.Reg.CombatService.KnockedOut:Fire(p, "Monster")
	w:Advance(35)
	w:Metric(p, "PurchasePrompt", "VIP")
	check(#w:Named("PromptNearKO", p) == 1, "a buy window 35 s after a KO: not counted", #w:Named("PromptNearKO", p))
	w.Reg.LootService.Enhanced:Fire(p, 2, 3, 2, false, "Enh30")
	w:Metric(p, "PurchasePrompt", "Gold2")
	check(field(w:Named("PromptNearKO", p)[2], 1) == "EnhanceFail", "right after a failed scroll: EnhanceFail", "")
end)

runGroup("ClientMetric rules", function()
	local w = metricsWorld()
	local p = hero(w, 1)
	local seen = {}
	w.Tel.ClientMetric:Connect(function(pl, id, arg) table.insert(seen, id .. ":" .. tostring(arg)) end)
	w:Metric(p, "Nope")
	w:Metric(p, "OptIn", "maybe")
	w:Metric(p, "OptIn", "shown", "extra")
	w:Metric(p, "InviteSent", 0)
	w:Metric(p, "InviteSent", 51)
	w:Metric(p, "InviteSent", 1.5)
	w:Metric(p, "InviteSent", "3")
	w:Metric(p, "WelcomeBackGo", "x")
	w:Metric(p, 5)
	w:Metric(p, "PassView", "Robux!")
	w:Metric(p, "PurchasePrompt", string.rep("A", 40))
	w:Metric(p, "ShopOpen", "x")
	check(#seen == 0 and #w.Custom == #w:Named("DaysPlayed") + #w:Named("ReturnGap"), "every bad call is ignored", show(seen))
	w:Metric(p, "OptIn", "shown")
	w:Metric(p, "WelcomeBackGo")
	check(table.concat(seen, ",") == "OptIn:shown,WelcomeBackGo:nil", "good calls pass on (ReturnService listens)", table.concat(seen, ","))
	check(field(w:Named("NotifyOptIn", p)[1], 1) == "shown" and #w:Named("WelcomeBackGo", p) == 1, "NotifyOptIn / WelcomeBackGo events", "")
	w:Metric(p, "OptIn", "cannot")
	w:Metric(p, "WelcomeBackGo")
	check(#w:Named("NotifyOptIn", p) == 1 and #w:Named("WelcomeBackGo", p) == 1,
		"OptIn / WelcomeBackGo are logged once a session", #w:Named("WelcomeBackGo", p))
	check(#seen == 4 and seen[3] == "OptIn:cannot", "the signal still fires for every accepted call (ReturnService's state)",
		table.concat(seen, ","))
	w.Gap = 0.2
	w:Metric(p, "InviteSeen", "Menu")
	w:Metric(p, "InviteSeen", "Menu")
	check(#seen == 5, "rate limited per id (0.5 s): no signal either", #seen)
	-- one client cannot flood the budget: at most ClientMetricPerMinute logged calls a minute; the signal is not limited
	w.Gap = 0.6
	local q = hero(w, 2)
	local before = #seen
	for _ = 1, 20 do w:Metric(q, "InviteSent", 2) end
	check(#w:Named("InviteSent", q) == 10, "20 calls in 12 s: 10 logged (the per-minute budget)", #w:Named("InviteSent", q))
	check(#seen - before == 20, "all 20 still reach the ClientMetric signal", #seen - before)
	-- a once-id refused by the full budget is not marked: the next minute it is logged
	w:Metric(q, "OptIn", "shown")
	check(#w:Named("NotifyOptIn", q) == 0 and seen[#seen] == "OptIn:shown",
		"a full budget: the opt-in is not logged, but ReturnService still hears it", tostring(seen[#seen]))
	w:Advance(61)
	w:Metric(q, "OptIn", "shown")
	check(#w:Named("NotifyOptIn", q) == 1, "the next minute: logged (Once was not used up by the refused call)",
		#w:Named("NotifyOptIn", q))
	w:Metric(q, "InviteSent", 2)
	check(#w:Named("InviteSent", q) == 11, "a new minute: logged again", #w:Named("InviteSent", q))
	w.Gap = 1.1
	local n0 = #seen
	w.Ready[p] = nil
	w:Metric(p, "InviteSeen", "Menu")
	check(#seen == n0, "not ready: ignored (no signal)", "")
end)

runGroup("leave: context + KOLeave60", function()
	local w = metricsWorld()
	local function leave(setup, wait)
		local p = hero(w, 100 + #w.PlayerList)
		w:Advance(5)
		w.PS.MarkActive(p)
		setup(p)
		w:Advance(wait or 5)
		w:Leave(p)
		local lc = w:Named("LeaveContext", p)[1]
		return field(lc, 1), field(lc, 2), w:Named("KOLeave60", p)[1], p
	end
	local ctx, bucket, ko = leave(function(p)
		p:SetAttribute("ZoneId", "GoblinWoods")
		w.Reg.CombatService.KnockedOut:Fire(p, "Player")
	end)
	check(ctx == "KO" and bucket == "0-5" and ko and field(ko, 1) == "GoblinWoods", "a leave 5 s after a KO: KO + KOLeave60 (zone)",
		tostring(ctx) .. " " .. show(ko and ko.F))
	ctx, _, ko = leave(function(p) w.Reg.CombatService.KnockedOut:Fire(p, "Monster") end, 70)
	check(ko == nil and ctx ~= "KO", "70 s after a KO: not a KO leave", tostring(ctx))
	ctx = leave(function(p) w.Reg.ReturnService.CardShown:Fire(p, "Chapter") end)
	check(ctx == "StopCard", "after a pause card: StopCard", tostring(ctx))
	ctx = leave(function(p) w.PS.SetStat(p, "DailyClaims", 3) end)
	check(ctx == "DailyDone", "after the day's last daily: DailyDone", tostring(ctx))
	ctx = leave(function(p) w.Reg.CombatService.InCombat[p] = true end)
	check(ctx == "Combat", "in a fight: Combat", tostring(ctx))
	ctx = leave(function(p) w:Remote("UiMetric", p, "Shop") end)
	check(ctx == "Shop", "in the Shop: Shop", tostring(ctx))
	ctx = leave(function(p) w:Remote("UiMetric", p, "Bag") end)
	check(ctx == "Menu", "in another window: Menu", tostring(ctx))
	ctx = leave(function() end, 130)
	check(ctx == "Idle", "no own action for 2 minutes: Idle", tostring(ctx))
	ctx = leave(function() end)
	check(ctx == "Play", "otherwise: Play", tostring(ctx))
	-- a server that closes: every player "leaves" at once; that is no leave context
	w.Closing = true
	local c2, _, ko2, pc = leave(function(p) w.Reg.CombatService.KnockedOut:Fire(p, "Monster") end)
	check(c2 == nil and ko2 == nil and #w:Named("SessionMinutes", pc) == 1, "a shutdown: no LeaveContext / KOLeave60 (the session sums stay)",
		tostring(c2))
end)

runGroup("economy dashboard", function()
	local w = metricsWorld()
	local p, d = hero(w, 1, { Data = { CarriedGold = 40, BankGold = 100 } })
	local G = w.Reg.ProgressionService
	G.GoldEarned:Fire(p, 10, "Monster")
	G.GoldEarned:Fire(p, 20, "Monster")
	G.GoldEarned:Fire(p, 30, "Attendance")
	G.GoldEarned:Fire(p, 0, "Quest")
	G.GoldSpent:Fire(p, 15, "Weapon")
	G.GoldSpent:Fire(p, 7, "Plunder")
	check(#w.Econ == 0, "nothing logged per coin", #w.Econ)
	w:Five()
	local by = {}
	for _, e in w.Econ do by[e.Flow .. ":" .. e.Sku] = e end
	check(#w.Econ == 4, "one event per source / sink", #w.Econ)
	local m, a, wpn, pl = by["Flow.Source:Monster"], by["Flow.Source:Attendance"], by["Flow.Sink:Weapon"], by["Flow.Sink:Plunder"]
	check(m and m.Amount == 30 and m.Kind == "Gameplay" and m.Currency == "Gold" and m.Balance == 140,
		"Monster 10 + 20 = 30, Gameplay, balance = carried + bank", show(m and { m.Amount, m.Kind, m.Balance }))
	check(a and a.Amount == 30 and a.Kind == "TimedReward", "Attendance = TimedReward", show(a and a.Kind))
	check(wpn and wpn.Amount == 15 and wpn.Kind == "Shop" and pl and pl.Kind == "Gameplay", "Weapon = Shop sink, Plunder = Gameplay",
		show(wpn and wpn.Kind))
	w:Five()
	check(#w.Econ == 4, "nothing new: nothing logged", #w.Econ)
	G.GoldEarned:Fire(p, 5, "Quest")
	w:Leave(p)
	check(#w.Econ == 5 and w.Econ[5].Sku == "Quest" and w.Econ[5].Amount == 5, "the leave flushes the rest", show(w.Econ[5] and w.Econ[5].Sku))
	local _ = d
end)

runGroup("phone performance (ClientMetric Perf)", function()
	local w = metricsWorld()
	local C = w.Config
	local A = C.Analytics
	check(A.ClientMetrics.Perf == "Perf" and table.concat(A.PerfDevices, ",") == "Phone,Tablet,Desktop,Console"
		and A.Perf.Every == 120 and A.Perf.MinGap == 60 and A.Perf.Low == 20 and A.Perf.MaxFps == 240 and A.Perf.MaxMem == 16384
		and A.Perf.MaxQuality == 10, "config: Perf rule, 4 devices, every 120 s / gap 60 s / low 20 / 240 fps / 16384 MB / Q10", "")
	local p = hero(w, 1)
	local seen = {}
	w.Tel.ClientMetric:Connect(function(pl, id, arg) if id == "Perf" then table.insert(seen, arg) end end)
	local function good(o)
		local t = { D = "Phone", F = 42, W = 31, M = 900, Q = 5 }
		for k, v in o or {} do t[k] = v end
		return t
	end
	local function perf(pl) return #w:Named("PerfFps", pl) + #w:Named("PerfFpsLow", pl) + #w:Named("PerfMem", pl) end
	w.Gap = 61
	p:SetAttribute("ZoneId", "SlimeMeadow")
	local sent = good()
	w:Metric(p, "Perf", sent)
	local fps, mem = w:Named("PerfFps", p)[1], w:Named("PerfMem", p)[1]
	check(fps and fps.Value == 42 and field(fps, 1) == "Phone" and field(fps, 2) == "SlimeMeadow" and field(fps, 3) == "Q5",
		"PerfFps: value = the average, fields = device, zone, Q<quality>", show(fps and { fps.Value, fps.F }))
	check(mem and mem.Value == 900 and field(mem, 1) == "Phone" and field(mem, 2) == "SlimeMeadow" and field(mem, 3) == "Q5",
		"PerfMem: value = MB, the same fields", show(mem and { mem.Value, mem.F }))
	check(#w:Named("PerfFpsLow", p) == 0, "the lowest second is fine (31 >= 20): no PerfFpsLow", "")
	check(#seen == 1 and seen[1] ~= sent and seen[1].F == 42 and seen[1].D == "Phone" and seen[1].M == 900,
		"the ClientMetric signal gets a clean copy of the sample", show(seen[1]))
	-- the lowest second under Low: PerfFpsLow (value W); exactly Low is fine
	w:Metric(p, "Perf", good({ F = 25, W = 8, M = 1500, Q = 0, D = "Tablet" }))
	local low = w:Named("PerfFpsLow", p)[1]
	check(low and low.Value == 8 and field(low, 1) == "Tablet" and field(low, 3) == "Q0" and #w:Named("PerfFps", p) == 2,
		"W 8 < 20: PerfFpsLow (value W) next to PerfFps", show(low and { low.Value, low.F }))
	w:Metric(p, "Perf", good({ W = 20 }))
	check(#w:Named("PerfFpsLow", p) == 1 and #w:Named("PerfFps", p) == 3, "W = 20 is not low", #w:Named("PerfFpsLow", p))
	w:Metric(p, "Perf", good({ W = 19 }))
	check(#w:Named("PerfFpsLow", p) == 2, "W = 19 is low", #w:Named("PerfFpsLow", p))
	-- the zone: unknown / unset -> Other (a fixed list only: nothing the client or the world makes up goes into a field)
	p:SetAttribute("ZoneId", "Nowhere")
	w:Metric(p, "Perf", good())
	check(field(w:Named("PerfFps", p)[5], 2) == "Other", "an unknown zone id: Other", show(w:Named("PerfFps", p)[5] and w:Named("PerfFps", p)[5].F))
	p:SetAttribute("ZoneId", nil)
	w:Metric(p, "Perf", good())
	check(field(w:Named("PerfFps", p)[6], 2) == "Other", "no zone: Other", "")
	-- the range edges are fine
	local n0 = #w:Named("PerfFps", p)
	w:Metric(p, "Perf", { D = "Console", F = 0, W = 0, M = 0, Q = 0 })
	w:Metric(p, "Perf", { D = "Desktop", F = 240, W = 240, M = 16384, Q = 10 })
	check(#w:Named("PerfFps", p) == n0 + 2, "0 and the maxima are accepted", #w:Named("PerfFps", p) - n0)
	-- every bad call is ignored: nothing logged, no signal, whatever the spacing
	local before, sigBefore = perf(p), #seen
	local bad = {
		{ "a missing key", { D = "Phone", F = 42, W = 31, M = 900 } },
		{ "an extra key", good({ X = 1 }) },
		{ "an unknown device", good({ D = "Toaster" }) },
		{ "a device that is no string", good({ D = 5 }) },
		{ "a negative fps", good({ F = -1 }) },
		{ "an fps over 240", good({ F = 241 }) },
		{ "a fractional fps", good({ F = 40.5 }) },
		{ "an fps as text", good({ F = "40" }) },
		{ "a NaN fps", good({ F = 0 / 0 }) },
		{ "an infinite fps", good({ F = math.huge }) },
		{ "a lowest second above the average", good({ F = 30, W = 31 }) },
		{ "a negative lowest second", good({ W = -1 }) },
		{ "memory over 16384", good({ M = 16385 }) },
		{ "negative memory", good({ M = -1 }) },
		{ "fractional memory", good({ M = 900.5 }) },
		{ "quality 11", good({ Q = 11 }) },
		{ "fractional quality", good({ Q = 1.5 }) },
		{ "a nested value", good({ D = { "Phone" } }) },
		{ "an array", { 1, 2, 3, 4, 5 } },
		{ "an empty table", {} },
		{ "a string", "Phone" },
		{ "a number", 60 },
	}
	for _, b in bad do
		w:Metric(p, "Perf", b[2])
		check(perf(p) == before and #seen == sigBefore, "ignored: " .. b[1], show({ perf(p), before }))
	end
	w:Metric(p, "Perf")
	w:Metric(p, "Perf", good(), "extra")
	check(perf(p) == before and #seen == sigBefore, "ignored: no argument / a second argument", "")
	-- one sample a minute: a faster one is dropped (the other ids keep their 0.5 s)
	local q = hero(w, 2)
	w.Gap = 30
	w:Metric(q, "Perf", good())
	w:Metric(q, "Perf", good())
	check(#w:Named("PerfFps", q) == 1, "30 s later: dropped (one sample a minute)", #w:Named("PerfFps", q))
	w:Metric(q, "Perf", good())
	check(#w:Named("PerfFps", q) == 2, "60 s after the logged one: accepted", #w:Named("PerfFps", q))
	-- a bad table does not use the minute up (the next good sample goes through)
	local r = hero(w, 3)
	w.Gap = 61
	w:Metric(r, "Perf", good({ D = "Toaster" }))
	w:Metric(r, "Perf", good())
	check(#w:Named("PerfFps", r) == 1, "a refused sample does not start the minute", #w:Named("PerfFps", r))
	-- the shared minute budget is neither used by Perf nor needed by it
	local t = hero(w, 4)
	w.Gap = 0.6
	for _ = 1, 10 do w:Metric(t, "InviteSent", 2) end
	w:Metric(t, "Perf", good())
	check(#w:Named("InviteSent", t) == 10 and #w:Named("PerfFps", t) == 1,
		"a full minute budget does not hold Perf back", show({ #w:Named("InviteSent", t), #w:Named("PerfFps", t) }))
	local u = hero(w, 5)
	w:Metric(u, "Perf", good())
	for _ = 1, 10 do w:Metric(u, "InviteSent", 2) end
	check(#w:Named("InviteSent", u) == 10, "Perf does not use the shared budget up (10 other metrics still logged)",
		#w:Named("InviteSent", u))
	-- not ready: ignored
	local v = hero(w, 6)
	w.Ready[v] = nil
	w.Gap = 61
	w:Metric(v, "Perf", good())
	check(perf(v) == 0, "not ready: ignored", perf(v))
	-- no AnalyticsService: nothing logged, nothing breaks, the signal still fires
	local w2 = metricsWorld({ NoAnalytics = true })
	local x = hero(w2, 1)
	local got = 0
	w2.Tel.ClientMetric:Connect(function(_, id) if id == "Perf" then got += 1 end end)
	w2.Gap = 61
	w2:Metric(x, "Perf", good())
	check(got == 1 and #w2.Custom == 0, "no AnalyticsService: the signal fires, nothing is logged, nothing breaks", got)
	-- no UserId, name or free text in any field of a Perf event
	local clean = true
	for _, c in w.Custom do
		if string.sub(c.Name, 1, 4) == "Perf" then
			for _, f in c.F or {} do
				if f ~= "Phone" and f ~= "Tablet" and f ~= "Desktop" and f ~= "Console" and f ~= "Other" and not C.Zones[f]
					and not string.match(f, "^Q%d+$") then clean = false end
			end
		end
	end
	check(clean, "Perf fields: a device, a zone from the list (or Other) and Q<number> only", "")
end)

runGroup("no AnalyticsService (Studio)", function()
	local w = metricsWorld({ NoAnalytics = true })
	local p = hero(w, 1)
	w.Reg.AttendanceService.Claimed:Fire(p, 1, 1)
	w.Reg.ProgressionService.GoldEarned:Fire(p, 9, "Monster")
	w:Five()
	w:Leave(p)
	check(#w.Funnel == 0 and #w.Econ == 0, "nothing logged, nothing breaks", "")
end)

------------------------------------------------------------------ A23-113 (사용자 "마감 전 넣자"): FirstKO funnel, minutes to Lv5, PvP result
runGroup("FirstKO funnel (A23-113 #2)", function()
	local w = metricsWorld()
	local p = hero(w, 31, { Data = { Level = 4 } })
	local sd = w.Reg.StoryQuestService.StepDone
	sd:Fire(p, "KO1", 1)
	check(w:Steps(p, "FirstKO") == "1:KO", "the King's hit (step 1 done) = KO", w:Steps(p, "FirstKO"))
	sd:Fire(p, "KO1", 1)
	check(w:Steps(p, "FirstKO") == "1:KO", "a step logs once per account", w:Steps(p, "FirstKO"))
	for step = 2, 5 do sd:Fire(p, "KO1", step) end
	check(w:Steps(p, "FirstKO") == "1:KO,2:PotionBought,3:SlotSet,4:PotionUsed,5:KingWon", "the five steps, in order: KO, PotionBought, SlotSet, PotionUsed, KingWon", w:Steps(p, "FirstKO"))
	check(w.Data[p].Telemetry.F.FirstKO.KO == true, "saved in data.Telemetry.F (once per account)", show(w.Data[p].Telemetry))
	-- other quests, a step past the end, a bad quest id: nothing
	local q = hero(w, 32, { Data = { Level = 4 } })
	sd:Fire(q, "M1_2", 1)
	sd:Fire(q, "KO1", 6)
	sd:Fire(q, "KO1", 0)
	sd:Fire(q, nil, 1)
	sd:Fire(q, "KO1", nil)
	check(w:Steps(q, "FirstKO") == "", "another quest / a step outside 1-5 / bad arguments log nothing", w:Steps(q, "FirstKO"))
	-- a step passed out of order by the quest (Past) still logs in the quest's order, one at a time
	sd:Fire(q, "KO1", 3)
	check(w:Steps(q, "FirstKO") == "3:SlotSet", "the funnel step index is the step's own number", w:Steps(q, "FirstKO"))
	-- the other players' funnels stay apart
	check(w:Steps(p, "FirstKO") == "1:KO,2:PotionBought,3:SlotSet,4:PotionUsed,5:KingWon", "players never share a funnel", w:Steps(p, "FirstKO"))
end)

local function brief(list) -- a readable line of logged events (never the player: it points back at the world)
	local out = {}
	for _, e in list do table.insert(out, tostring(e.Value) .. "|" .. tostring(e.F and e.F.CustomField01) .. "|" .. tostring(e.F and e.F.CustomField02) .. "|" .. tostring(e.F and e.F.CustomField03)) end
	return table.concat(out, ";")
end

runGroup("minutes to Lv5 (A23-113 #2)", function()
	local w = metricsWorld()
	local p = hero(w, 41, { Data = { Level = 4, PlaytimeSeconds = 752, Faction = "Horns" } })
	local up = w.Reg.ProgressionService.LeveledUp
	up:Fire(p, 4)
	check(#w:Named("MinutesToLv5", p) == 0, "Lv4: nothing", "")
	up:Fire(p, 5)
	local ev = w:Named("MinutesToLv5", p)
	check(#ev == 1 and ev[1].Value == 13 and field(ev[1], 1) == "Horns", "reaching Lv5: the minutes of play (752 s = 13 min) and the faction", brief(ev))
	up:Fire(p, 5)
	up:Fire(p, 6)
	check(#w:Named("MinutesToLv5", p) == 1 and w.Data[p].Telemetry.TimeToLevel == true, "once per account", tostring(#w:Named("MinutesToLv5", p)))
	-- a very fast start is at least 1 minute; nothing for a bad level
	local q = hero(w, 42, { Data = { Level = 4, PlaytimeSeconds = 5 } })
	up:Fire(q, 5)
	check(#w:Named("MinutesToLv5", q) == 1 and w:Named("MinutesToLv5", q)[1].Value == 1, "under half a minute still counts 1", brief(w:Named("MinutesToLv5", q)))
	local r = hero(w, 43, { Data = { Level = 4, PlaytimeSeconds = 900 } })
	up:Fire(r, nil)
	up:Fire(r, "5")
	up:Fire(r, 0 / 0)
	check(#w:Named("MinutesToLv5", r) == 0, "a bad level logs nothing", "")
end)

runGroup("PvP result line (A23-113 #5)", function()
	local w = metricsWorld()
	local a = hero(w, 51, { Data = { Level = 12, Faction = "Halo" }, Attrs = { Faction = "Halo", Level = 12 } })
	local b = hero(w, 52, { Data = { Level = 5, Faction = "Horns" }, Attrs = { Faction = "Horns", Level = 5 } })
	local ko = w.Reg.PvPService.PlayerKO
	ko:Fire(a, b, { Kind = "Bully" })
	local ev = w:Named("PvPResult", a)
	check(#ev == 1 and ev[1].Value == 1.3 and field(ev[1], 1) == "Halo" and field(ev[1], 2) == "Horns" and field(ev[1], 3) == "10-24>1-9",
		"the winner's faction + scale (Halo 1.3), the loser's faction, both level bands", brief(ev))
	check(#w:Named("PvPResult", b) == 0, "logged once, under the winner", "")
	ko:Fire(a, b, {})
	check(#w:Named("PvPResult", a) == 1, "a second KO inside the same second is not logged again (per killer)", tostring(#w:Named("PvPResult", a)))
	w:Advance(2)
	ko:Fire(b, a, {})
	local back = w:Named("PvPResult", b)
	check(#back == 1 and back[1].Value == 1.05 and field(back[1], 1) == "Horns" and field(back[1], 2) == "Halo" and field(back[1], 3) == "1-9>10-24",
		"the other way: Horns wins (1.05 scale, 1-9 over 10-24)", brief(back))
	-- Neutral / unknown side: scale 1; no Justice double: scale 1
	local n = hero(w, 53, { Data = { Level = 30, Faction = "Neutral" }, Attrs = { Faction = "Neutral", Level = 30 } })
	w:Advance(2)
	ko:Fire(n, a, {})
	local nn = w:Named("PvPResult", n)
	check(#nn == 1 and nn[1].Value == 1 and field(nn[1], 1) == "Neutral" and field(nn[1], 3) == "25-49>10-24", "Neutral: scale 1", brief(nn))
	-- bad arguments never throw
	ko:Fire(nil, nil, nil)
	ko:Fire("a", "b", {})
	check(#w:Named("PvPResult") == 3, "bad killer / victim arguments log nothing", tostring(#w:Named("PvPResult")))
end)

finish()
