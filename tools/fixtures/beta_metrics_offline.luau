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
	w.Reg.ReturnService = { CardShown = Signal.new(), Welcomed = Signal.new() }
	w.Reg.InviteService = { InviteJoined = Signal.new(), PlayedTogether = Signal.new(), WentToFriend = Signal.new() }
	w.Reg.DiaryService = { PageOpened = Signal.new(), CandyTraded = Signal.new() }
	w.Reg.MonetizationService.PassBought = Signal.new()
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
	check(table.concat(names, ",") == "DailyVisit,KingDiary,LongRoad,PassShop,Social" and #names + 1 <= 10,
		"5 funnels + the onboarding one (Roblox: at most 10)", table.concat(names, ","))
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
	check(#w:Named("NotifyOptIn", p) == 1 and #w:Named("WelcomeBackGo", p) == 1 and #seen == 2,
		"OptIn / WelcomeBackGo count once a session", #w:Named("WelcomeBackGo", p))
	w.Gap = 0.2
	w:Metric(p, "InviteSeen", "Menu")
	w:Metric(p, "InviteSeen", "Menu")
	check(#seen == 3, "rate limited per id (0.5 s)", #seen)
	-- one client cannot flood the budget: at most ClientMetricPerMinute accepted calls a minute
	w.Gap = 0.6
	local q = hero(w, 2)
	local before = #seen
	for _ = 1, 20 do w:Metric(q, "InviteSent", 2) end
	check(#seen - before == 10 and #w:Named("InviteSent", q) == 10, "20 calls in 12 s: 10 accepted (the per-minute budget)",
		#seen - before)
	w:Advance(61)
	w:Metric(q, "InviteSent", 2)
	check(#w:Named("InviteSent", q) == 11, "a new minute: accepted again", #w:Named("InviteSent", q))
	w.Gap = 1.1
	w.Ready[p] = nil
	w:Metric(p, "InviteSeen", "Menu")
	check(#seen - before == 11, "not ready: ignored", "")
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

runGroup("no AnalyticsService (Studio)", function()
	local w = metricsWorld({ NoAnalytics = true })
	local p = hero(w, 1)
	w.Reg.AttendanceService.Claimed:Fire(p, 1, 1)
	w.Reg.ProgressionService.GoldEarned:Fire(p, 9, "Monster")
	w:Five()
	w:Leave(p)
	check(#w.Funnel == 0 and #w.Econ == 0, "nothing logged, nothing breaks", "")
end)

finish()
