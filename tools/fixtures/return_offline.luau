-- return_offline.luau : SPEC A23-79 다시 오게 만들기, the server's part (게임성 개발 3). tools/test_return.py binds
-- CONFIG_SOURCE, UTIL_SOURCE, RETURN_SOURCE, INVITE_SOURCE, DIARY_SOURCE and TITLE_SOURCE in front of dev2_kit.luau +
-- dev3_world.luau; this file follows. ReturnService, InviteService, DiaryService and TitleService run from source; the
-- rest are dev3_world doubles (QuestService.PinnedRow, the new story / war / king signals, BadgeService, ZoneService).

local NOON = 1789959600 -- 2026-09-22 12:00 KST (before the Halloween season's day 1; the season is on)

local function retWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c) -- A23-119: the shipped Config hides the Halloween season (Enabled = false); this suite tests the season's own rules, so it turns it on
		c.Halloween.Enabled = true
		if edit then edit(c) end
	end
	local w = dev3World(o)
	local Signal = w.Util.Signal
	w.Pinned = {} -- [Player] = the row QuestService.PinnedRow returns
	w.Reg.QuestService = { PinnedRow = function(p) return w.Pinned[p] end }
	w.Reg.TelemetryService = { ClientMetric = Signal.new() }
	w.Reg.ChoiceCard = { Picked = Signal.new() } -- A23-86: a repeated card pick refreshes My Way
	w.Badges, w.BadgeFail, w.BadgeAnswer, w.HasBadge, w.HasAsks = {}, false, true, {}, 0
	w.Services.BadgeService = {
		AwardBadge = function(_, uid, id)
			if w.OnAward then w.OnAward(uid, id) end -- what happens while the web call runs (e.g. the player leaves)
			if w.BadgeFail then error("offline badge failure") end
			if w.BadgeAnswer ~= true then return false end -- the badge is off / a wrong id (or already owned)
			table.insert(w.Badges, uid .. ":" .. id)
			return true
		end,
		UserHasBadgeAsync = function(_, uid, id)
			w.HasAsks += 1
			return w.HasBadge[uid .. ":" .. id] == true
		end,
	}
	w:Service("TitleService", TITLE_SOURCE)
	w:Service("ReturnService", RETURN_SOURCE)
	w:Service("InviteService", INVITE_SOURCE)
	w:Service("DiaryService", DIARY_SOURCE)
	w:InitStart({ "TitleService", "ReturnService", "InviteService", "DiaryService" })
	return w
end

local function hero(w, id, jo)
	jo = jo or {}
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 3, TutorialStep = 99, PlaytimeSeconds = 1200 }
	for k, v in jo.Data or {} do data[k] = v end
	jo.Data = data
	return w:Arrive(id, jo)
end

local function cards(w, p)
	local out = {}
	for _, f in w:FxOf("PauseCard", p) do table.insert(out, f.Data) end
	return out
end

local function lastCard(w, p)
	local list = cards(w, p)
	return list[#list]
end

------------------------------------------------------------------ #1 pause card
runGroup("pause card: chapter end", function()
	local w = retWorld()
	local p = hero(w, 1)
	w.Pinned[p] = { ShortName = "Crown points", Text = "Collect crown points 0/3", Story = { Guide = "Crossroads" } }
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M1_2")
	w:Advance(2)
	check(#cards(w, p) == 0, "a main quest in the middle of a chapter: no card", #cards(w, p))
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M1_4")
	w:Advance(1)
	check(#cards(w, p) == 0, "the card waits CardDelay (the next goal is pinned by then)", #cards(w, p))
	w:Advance(1)
	local c = lastCard(w, p)
	check(c and c.Why == "Chapter" and c.Next == "Crown points" and c.Zone == "Crossroads" and c.OptIn == nil,
		"chapter 1's last quest (M1_4): Saved card, Next = the pinned row's short name, Zone = its guide", show(c))
	check(w.Config.Return.MinGap == 120, "MinGap 120 s", w.Config.Return.MinGap)
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M2_7")
	w:Advance(2)
	check(#cards(w, p) == 1, "another card within MinGap: none", #cards(w, p))
	w:Advance(120)
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M3_8")
	w:Advance(2)
	check(#cards(w, p) == 2 and lastCard(w, p).Why == "Chapter", "chapter 3's last quest after the gap: a card", #cards(w, p))
	-- a fight: the card waits for it to end
	w:Advance(200)
	w.Reg.CombatService.InCombat[p] = true
	w.Reg.StoryQuestService.QuestDone:Fire(p, "M2_7")
	w:Advance(2)
	w:Advance(3)
	check(#cards(w, p) == 2, "in a fight: no card yet", #cards(w, p))
	w.Reg.CombatService.InCombat[p] = nil
	w:Advance(3)
	check(#cards(w, p) == 3, "the fight is over: the card comes", #cards(w, p))
end)

runGroup("pause card: the day's dailies", function()
	local w = retWorld()
	local p, d = hero(w, 1)
	w.Reg.DiaryService.TomorrowLine = function() return nil end -- no diary page waiting
	w.Pinned[p] = { ShortName = "King Slimes", Story = { Guide = "SlimeMeadow" } }
	p:SetAttribute("DailyClaims", 1)
	p:SetAttribute("DailyClaims", 2)
	w:Advance(2)
	check(#cards(w, p) == 0, "two dailies claimed: no card", #cards(w, p))
	p:SetAttribute("DailyClaims", 3)
	w:Advance(2)
	local c = lastCard(w, p)
	check(c and c.Why == "Daily" and c.Next == "King Slimes" and c.Zone == "SlimeMeadow" and c.Tomorrow == "New dailies",
		"the third daily claimed: the card with tomorrow's line", show(c))
	check(c and c.OptIn == true, "20 minutes played: the opt-in moment rides on the daily card", show(c))
	check(#w:FxOf("OptInMoment", p) == 0, "no separate opt-in Fx when the card carries it", #w:FxOf("OptInMoment", p))
	-- the client says the prompt was shown: never asked again
	w.Reg.TelemetryService.ClientMetric:Fire(p, "OptIn", "shown")
	check(d.Return.OptIn == "shown" and d.Return.OptInAt == w.Time, "shown -> saved", show(d.Return))
	w:RunSpawned()
	local store = w.Stores[w.Config.Notify.Store]
	check(store and store.Rows["1"] and store.Rows["1"].At == w.Time, "the asked list keeps the UserId for the launch day",
		show(store and store.Rows))
	-- the next day, again
	w:Advance(86400)
	p:SetAttribute("DailyClaims", 0)
	p:SetAttribute("DailyClaims", 3)
	w:Advance(2)
	c = lastCard(w, p)
	check(#cards(w, p) == 2 and c.OptIn == nil, "the next day: a card, no second opt-in", show(c))
	-- during the Halloween season the diary's page waits for tomorrow
	w.Reg.DiaryService.TomorrowLine = function() return "King Diary page 4" end
	w:Advance(200)
	p:SetAttribute("DailyClaims", 0)
	p:SetAttribute("DailyClaims", 3)
	w:Advance(2)
	check(lastCard(w, p).Tomorrow == "King Diary page 4", "the tomorrow line names the King Diary page", show(lastCard(w, p)))
end)

runGroup("pause card: crown war end", function()
	local w = retWorld()
	local p = hero(w, 1)
	local q = hero(w, 2)
	local r = hero(w, 3)
	w.Pinned[p] = { ShortName = "Crown points" }
	w:Advance(20 * 60) -- 20 minutes into the session
	local s = w:Arrive(4, { Data = { Faction = "Horns", ClassChosen = true, TutorialStep = 99 } }) -- just joined
	w.Reg.WarService.RoundEnded:Fire("Halo", "Contest", { [p] = 35, [q] = 0, [s] = 40 })
	w:Advance(2)
	check(#cards(w, p) == 1 and lastCard(w, p).Why == "War", "took part, 20 minutes in: the war card", show(lastCard(w, p)))
	check(#cards(w, q) == 0 and #cards(w, r) == 0, "no chest points (or not in the war): no card", #cards(w, q))
	check(w.Config.War.ChestMinPoints == 30, "a war card needs the chest points (30)", w.Config.War.ChestMinPoints)
	check(#cards(w, s) == 0, "just joined: no war card (a long session first)", #cards(w, s))
	w:Advance(600)
	w.Reg.WarService.RoundEnded:Fire("Horns", "Contest", { [p] = 35 })
	w:Advance(2)
	check(#cards(w, p) == 1, "the next round 10 minutes later: none (one war card in 30 minutes)", #cards(w, p))
	w:Advance(1800)
	w.Reg.WarService.RoundEnded:Fire("None", "Idle", { [p] = 35 })
	w:Advance(2)
	check(#cards(w, p) == 1, "an idle round (no war): none", #cards(w, p))
	w.Reg.WarService.RoundEnded:Fire("Horns", "Siege", { [p] = 31 })
	w:Advance(2)
	check(#cards(w, p) == 2, "30 minutes later: a war card again", #cards(w, p))
end)

runGroup("welcome back", function()
	local w = retWorld()
	local now = w.Time
	local p = hero(w, 1, { Data = { LastLogoutTime = now - 7 * 3600, Level = 12 } })
	w.Pinned[p] = { ShortName = "Goblin camps", Story = { Guide = "GoblinWoods" } }
	w:Advance(3)
	check(#w:FxOf("WelcomeBack", p) == 0, "not before WelcomeDelay", #w:FxOf("WelcomeBack", p))
	w:Advance(2)
	local f = w:FxOf("WelcomeBack", p)[1]
	check(f and f.Data.Next == "Goblin camps" and f.Data.Zone == "GoblinWoods", "7 hours away: Welcome back + Next + [Go] zone",
		show(f and f.Data))
	local seen = 0
	w.Reg.ReturnService.Welcomed:Connect(function() seen += 1 end)
	local q = hero(w, 2, { Data = { LastLogoutTime = w.Time - 5 * 3600 } })
	local r = hero(w, 3, { Data = { LastLogoutTime = 0 } })
	local s = hero(w, 4, { Data = { LastLogoutTime = w.Time - 9 * 3600, TutorialStep = 2 } })
	local t = hero(w, 5, { Data = { LastLogoutTime = w.Time - 9 * 3600 } })
	w:Advance(5)
	check(#w:FxOf("WelcomeBack", q) == 0 and #w:FxOf("WelcomeBack", r) == 0, "5 hours away / a brand-new save: none",
		#w:FxOf("WelcomeBack", q))
	check(#w:FxOf("WelcomeBack", s) == 0, "the first mission not done yet: the guide leads (no card)", #w:FxOf("WelcomeBack", s))
	check(#w:FxOf("WelcomeBack", t) == 1 and seen == 1, "9 hours: one card, Welcomed fires", seen)
	local tf = w:FxOf("WelcomeBack", t)[1]
	check(tf.Data.Next == "Hunt and get stronger!" and tf.Data.Zone == "SlimeMeadow",
		"nothing pinned: the hunting line, to the level's field", show(tf.Data))
end)

runGroup("next goal zones", function()
	local w = retWorld()
	local function zoneFor(row, jo)
		local p = hero(w, 100 + #w.PlayerList, jo)
		w.Pinned[p] = row
		w.Reg.StoryQuestService.QuestDone:Fire(p, "M1_4")
		w:Advance(2)
		local c = lastCard(w, p)
		return c and c.Zone, c and c.Next
	end
	check(zoneFor({ ShortName = "x", Story = { Guide = "Blacksmith" } }) == "Crossroads", "the Blacksmith -> Crossroads", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "SlimePond" } }) == "SlimeMeadow", "a landmark -> its zone (SlimePond)", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "WoodsGate" } }) == "SlimeMeadow",
		"the woods gate stands in the meadow (outside the PvP woods)", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "HeroStatue" } }) == "Home", "a spot in my own town -> Home", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "HeroStatue" } }, { Data = { Faction = "Horns" } }) == nil,
		"the other side's town: no [Go]", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "OwnTown" } }, { Data = { Faction = "Horns" } }) == "Home", "OwnTown -> Home", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "GoblinWoods" } }) == nil, "Lv3 and the Lv10 woods: no [Go]", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "GoblinWoods" } }, { Data = { Level = 10 } }) == "GoblinWoods",
		"Lv10: the woods", "")
	check(zoneFor({ ShortName = "x", Story = { Guide = "PumpkinPatch" } }) == "SlimeMeadow", "a seasonal field -> the meadow", "")
	check(zoneFor({ Text = "Lv10 · Goblin Woods opens", GoalKind = "Zone" }, { Data = { Level = 12 } }) == "GoblinWoods",
		"the next-goal row 'Zone' -> the woods", "")
	check(zoneFor({ Text = "Iron weapon 800 gold", GoalKind = "IronGold" }) == "Crossroads", "the iron weapon -> the Forge", "")
	local z, n = zoneFor({ Text = "Long text only" })
	check(n == "Long text only" and z == "SlimeMeadow", "no short name: the text; no guide: the hunting field", tostring(n))
end)

------------------------------------------------------------------ #2 My Way
runGroup("My Way names", function()
	local w = retWorld()
	local M = w.Reg.ReturnService.MyWayOf
	check(M("Halo", { Lunch1 = "GiveBack", S0 = "Purify" }) == "TrueKnight", "Halo + good picks = True Knight", "")
	check(M("Halo", { Lunch1 = "Bite", S0 = "Devour" }) == "RebelAngel", "Halo + devil picks = Rebel Angel", "")
	check(M("Horns", { Lunch1 = "Bite", S0 = "Devour", SK2 = "Take" }) == "ProudRascal", "Horns + devil picks = Proud Rascal", "")
	check(M("Horns", { Lunch1 = "GiveBack", S0 = "Purify" }) == "SoftDevil", "Horns + good picks = Soft-Hearted Devil", "")
	check(M("Halo", { Lunch1 = "GiveBack", S0 = "Devour" }) == "BalanceWalker", "one each = Balance Walker", "")
	check(M("Halo", { Lunch1 = "GiveBack" }) == "", "one pick: no name yet", "")
	check(M("Neutral", { Lunch1 = "GiveBack", S0 = "Purify", SK2 = "Guard" }) == "", "the Artisan Guild: no My Way name", "")
	check(M("None", { Lunch1 = "GiveBack", S0 = "Purify" }) == "", "no side: no name", "")
	check(M("Halo", { M3_4 = "Good", M2_3 = "Good", Lunch1 = "Bite", S0 = "Purify", SK2 = "Take" }) == "BalanceWalker",
		"3 good / 2 devil of 5: within a fifth = Balance Walker", "")
	check(M("Halo", { M3_4 = "Good", M2_3 = "Good", Lunch1 = "GiveBack", S0 = "Purify", SK2 = "Take" }) == "TrueKnight",
		"4 good / 1 devil: True Knight", "")
	check(M("Halo", { Lunch1 = "A", S0 = "A" }) == "TrueKnight", "A / B picks count as the good / devil side", "")
	check(M("Halo", { Nope = "Good", Lunch1 = "GiveBack", S0 = "Weird" }) == "", "unknown quests / picks do not count", "")
	-- the Terms of Fate egg ('I agree' / 'Read it all' score 0 and are a joke): saved for its lines and title, never a My Way pick
	check(M("Halo", { Lunch1 = "GiveBack", EG01 = "Evil" }) == "", "one real pick + the joke pick = still no name", M("Halo", { Lunch1 = "GiveBack", EG01 = "Evil" }))
	check(M("Halo", { Lunch1 = "GiveBack", S0 = "Purify", EG01 = "Evil" }) == "TrueKnight", "2 good picks + 'I agree': still True Knight (the joke leans nothing)",
		M("Halo", { Lunch1 = "GiveBack", S0 = "Purify", EG01 = "Evil" }))
	check(M("Halo", { Lunch1 = "Bite", S0 = "Devour", EG01 = "Good" }) == "RebelAngel", "2 devil picks + 'Read it all': still Rebel Angel", M("Halo", { Lunch1 = "Bite", S0 = "Devour", EG01 = "Good" }))
	check(M("Halo", { Lunch1 = "GiveBack", EG01 = "B" }) == "", "a Neutral-era 'B' of the joke does not count either", M("Halo", { Lunch1 = "GiveBack", EG01 = "B" }))
	-- the attribute follows the picks and the faction
	local p, d = hero(w, 1, { Data = { Story = { Main = { Id = "" }, Subs = {}, Done = {}, First = {},
		Pick = { Lunch1 = "GiveBack", S0 = "Purify" } } } })
	check(p:GetAttribute("MyWay") == "True Knight", "the join sets MyWay to the display name", tostring(p:GetAttribute("MyWay")))
	d.Story.Pick.SK2 = "Take"
	d.Story.Pick.M3_4 = "Evil"
	w.Reg.StoryQuestService.Picked:Fire(p, "SK2", "Take")
	check(p:GetAttribute("MyWay") == "Balance Walker", "a new pick changes it at once", tostring(p:GetAttribute("MyWay")))
	d.Story.Pick.M2_3 = "Evil"
	d.Story.Pick.S3 = "Evil"
	d.Faction = "Horns"
	p:SetAttribute("Faction", "Horns")
	w.Reg.FactionService.FactionChanged:Fire(p, "Horns", "Halo", "Altar")
	check(p:GetAttribute("MyWay") == "Proud Rascal", "a faction change re-reads it", tostring(p:GetAttribute("MyWay")))
end)

runGroup("My Way: repeated cards (A23-86)", function()
	local w = retWorld()
	local M = w.Reg.ReturnService.MyWayOf
	local good2 = { Lunch1 = "GiveBack", S0 = "Purify" }
	local evil2 = { Lunch1 = "Bite", S0 = "Devour" }
	check(M("Halo", good2, { Lost = { Evil = 4 } }) == "TrueKnight", "4 repeated picks are not enough for a story pick", "")
	check(M("Halo", good2, { Lost = { Evil = 5 } }) == "TrueKnight", "5 repeated = 1 story pick (2 good + 1 devil of 3: still True Knight)", M("Halo", good2, { Lost = { Evil = 5 } }))
	check(M("Halo", good2, { Lost = { Evil = 10 } }) == "BalanceWalker", "10 repeated devil picks = 2 story picks: 2 / 2 = Balance Walker", M("Halo", good2, { Lost = { Evil = 10 } }))
	check(M("Halo", good2, { Lost = { Evil = 100 } }) == "BalanceWalker", "100 repeated picks never weigh more than the 2 story picks together", M("Halo", good2, { Lost = { Evil = 100 } }))
	check(M("Halo", evil2, { Kind = 10 }) == "BalanceWalker", "the job board's Kind count is a good deed (10 = 2 story picks)", M("Halo", evil2, { Kind = 10 }))
	check(M("Halo", evil2, { Sneaky = 10 }) == "RebelAngel", "the board's Sneaky count is a devil deed", M("Halo", evil2, { Sneaky = 10 }))
	check(M("Halo", good2, { Sneaky = 10 }) == "BalanceWalker", "10 board Sneaky jobs against 2 good picks = Balance Walker", M("Halo", good2, { Sneaky = 10 }))
	check(M("Halo", good2, { Kind = -50 }) == "TrueKnight" and M("Halo", good2, { Lost = { Good = -50, Evil = -50 } }) == "TrueKnight", "negative counts weigh nothing", "")
	check(M("Halo", {}, { Lost = { Good = 100 } }) == "", "repeated picks alone name nobody (2 story picks come first)", "")
	check(M("Halo", { Lunch1 = "GiveBack" }, { Lost = { Good = 100 } }) == "", "one story pick is still not enough", "")
	check(M("Horns", good2, { Lost = { Evil = 100 }, Other = { Evil = 100 } }) == "BalanceWalker", "several kinds add up, then the cap", M("Horns", good2, { Lost = { Evil = 100 }, Other = { Evil = 100 } }))
	check(M("Halo", good2, { Kind = "x", Sneaky = -50, Lost = "oops", Other = { Good = -9, Evil = "y" } }) == "TrueKnight", "broken counts are ignored", "")
	check(M("Halo", good2, nil) == "TrueKnight" and M("Halo", good2, "oops") == "TrueKnight", "no / broken repeated table", "")
	check(M("Neutral", good2, { Kind = 100 }) == "", "Neutral still has no name", "")
	-- the attribute follows a card pick and a board job at once
	local p, d = hero(w, 1, { Data = { Story = { Main = { Id = "" }, Subs = {}, Done = {}, First = {}, Pick = good2 } } })
	check(p:GetAttribute("MyWay") == "True Knight", "start: True Knight", tostring(p:GetAttribute("MyWay")))
	d.Story.N = { Lost = { Evil = 10 } }
	w.Reg.ChoiceCard.Picked:Fire(p, "Lost", "Evil", {})
	check(p:GetAttribute("MyWay") == "Balance Walker", "a card pick refreshes it", tostring(p:GetAttribute("MyWay")))
	d.Story.N = { Lost = { Evil = 10 }, Kind = 10 }
	w.Reg.ReturnService.RefreshMyWay(p)
	check(p:GetAttribute("MyWay") == "True Knight", "RefreshMyWay (called by the job board) re-reads it", tostring(p:GetAttribute("MyWay")))
	w.Reg.ReturnService.RefreshMyWay(nil)
	w.Reg.ReturnService.RefreshMyWay("oops")
end)

------------------------------------------------------------------ #2 badges
local BADGE_IDS = { ChoseSide = 101, FirstSlime = 102, LostLunchbox = 103, Stronger = 104, FirstSkill = 105, ShardChoice = 106,
	Rank2 = 107, Halloween2026 = 108 }
local function withBadges(c)
	for k, v in BADGE_IDS do c.Badges.Ids[k] = v end
end

runGroup("badges", function()
	local w0 = retWorld()
	local p0 = hero(w0, 1, { Data = { TotalKills = 5 } })
	check(#w0.Badges == 0, "ids 0 (badges not made yet): BadgeService is never asked", show(w0.Badges))
	local _ = p0
	local w = retWorld({ EditConfig = withBadges })
	local p, d = w:Arrive(1, { Data = { Faction = "None" } })
	check(#w.Badges == 0, "a brand-new player: nothing yet", show(w.Badges))
	d.Faction = "Halo"
	p:SetAttribute("Faction", "Halo")
	w.Reg.FactionService.FactionChanged:Fire(p, "Halo", "None", "Choose")
	w:RunSpawned()
	check(table.concat(w.Badges, ",") == "1:101" and d.Return.Badges.ChoseSide.Id == 101 and d.Return.Badges.ChoseSide.At == w.Time,
		"Chose a Side once the side is picked (saved with its badge id)",
		table.concat(w.Badges, ","))
	w.Reg.FactionService.FactionChanged:Fire(p, "Halo", "None", "Choose")
	w:RunSpawned()
	check(#w.Badges == 1, "never asked twice", #w.Badges)
	d.TotalKills = 1
	p:SetAttribute("TotalKills", 1)
	w:RunSpawned()
	check(table.find(w.Badges, "1:102") ~= nil, "the first slime (the first kill)", table.concat(w.Badges, ","))
	d.WeaponOwnedMask = 1
	p:SetAttribute("WeaponOwnedMask", 1)
	w:RunSpawned()
	check(table.find(w.Badges, "1:104") == nil, "the first (free) weapon is not 'Stronger!'", table.concat(w.Badges, ","))
	d.WeaponOwnedMask = 3
	p:SetAttribute("WeaponOwnedMask", 3)
	w:RunSpawned()
	check(table.find(w.Badges, "1:104") ~= nil, "a tier-2 weapon: Stronger!", table.concat(w.Badges, ","))
	d.SkillSlots = 1
	p:SetAttribute("SkillSlots", 1)
	w:RunSpawned()
	check(table.find(w.Badges, "1:105") ~= nil, "the first skill learned", table.concat(w.Badges, ","))
	d.Story.Done.Lunch1 = true
	w.Reg.StoryQuestService.QuestDone:Fire(p, "Lunch1")
	d.Story.Done.S0 = true
	w.Reg.StoryQuestService.QuestDone:Fire(p, "S0")
	w:RunSpawned()
	check(table.find(w.Badges, "1:103") ~= nil and table.find(w.Badges, "1:106") ~= nil, "Lost Lunchbox and Shard Choice",
		table.concat(w.Badges, ","))
	local thresholds = w.Config.Titles.Thresholds
	d.Honor = thresholds[2]
	p:SetAttribute("Honor", thresholds[2])
	w:RunSpawned()
	check(table.find(w.Badges, "1:107") ~= nil, "faction rank 2", table.concat(w.Badges, ","))
	w.Reg.LootService.ItemsGranted:Fire(p, { { Id = "Candy", N = 2 } })
	w:RunSpawned()
	check(table.find(w.Badges, "1:108") ~= nil, "candy during the 2026 season: Halloween 2026", table.concat(w.Badges, ","))
	check(#w.Badges == 8, "all 8, each once", #w.Badges)
	-- an old save gets every badge it already earned at the join; a failure is tried again later
	local w2 = retWorld({ EditConfig = withBadges })
	w2.BadgeFail = true
	w2.AllowWarn = "badge"
	local q, dq = hero(w2, 2, { Data = { TotalKills = 9, WeaponOwnedMask = 7, SkillSlots = 1, Honor = 0,
		Story = { Main = { Id = "" }, Subs = {}, Done = { Lunch1 = true, S0 = true }, Pick = {}, First = {} } } })
	check(#w2.Badges == 0 and next(dq.Return.Badges) == nil, "a failing BadgeService: nothing saved", show(dq.Return.Badges))
	w2.BadgeFail = false
	dq.TotalKills = 10
	q:SetAttribute("TotalKills", 10)
	w2:RunSpawned()
	check(#w2.Badges == 0, "no retry within RetrySeconds", #w2.Badges)
	w2:Advance(301)
	dq.TotalKills = 11
	q:SetAttribute("TotalKills", 11)
	w2:RunSpawned()
	check(#w2.Badges == 6, "after RetrySeconds: the 6 earned ones (side, slime, lunchbox, stronger, skill, shard)",
		table.concat(w2.Badges, ","))
	-- AwardBadge answers false (the badge is off / a wrong id): not saved, tried again later; false for a badge the
	-- player already has: UserHasBadgeAsync says so and it is saved
	local w4 = retWorld({ EditConfig = withBadges })
	w4.BadgeAnswer = false
	w4.AllowWarn = "badge"
	local s4, ds4 = hero(w4, 4, { Data = { TotalKills = 3 } })
	check(next(ds4.Return.Badges) == nil and w4.HasAsks >= 1, "false from AwardBadge: nothing saved (UserHasBadgeAsync asked)",
		show(ds4.Return.Badges))
	check(#w4.Warnings >= 1, "a not-awarded badge is warned like an error", tostring(w4.Warnings[1]))
	w4.HasBadge["4:101"] = true
	w4:Advance(301)
	ds4.TotalKills = 4
	s4:SetAttribute("TotalKills", 4)
	w4:RunSpawned()
	check(ds4.Return.Badges.ChoseSide and ds4.Return.Badges.ChoseSide.Id == 101 and ds4.Return.Badges.FirstSlime == nil,
		"after RetrySeconds: the one the player already has is saved, the others wait", show(ds4.Return.Badges))
	-- a corrected Config id (the user fixed a wrong id): the old record does not count, the new badge is given
	local w5 = retWorld({ EditConfig = function(c) withBadges(c); c.Badges.Ids.ChoseSide = 201 end })
	local s5, ds5 = hero(w5, 5, { Data = { Return = { Badges = { ChoseSide = { Id = 101, At = 1 } }, OptIn = "", OptInAt = 0 } } })
	check(table.find(w5.Badges, "5:201") ~= nil and ds5.Return.Badges.ChoseSide.Id == 201,
		"a record under another id is not the badge: awarded again with the new id", table.concat(w5.Badges, ","))
	local _45 = { s5 }
	-- AwardBadge throws for a badge the player already has (seen on live servers): UserHasBadgeAsync says so, it is saved
	local w6 = retWorld({ EditConfig = withBadges })
	w6.BadgeFail = true
	w6.HasBadge["6:101"] = true
	w6.AllowWarn = "badge"
	local s6, ds6 = hero(w6, 6)
	check(ds6.Return.Badges.ChoseSide and ds6.Return.Badges.ChoseSide.Id == 101, "an error for an owned badge: saved after the check",
		show(ds6.Return.Badges))
	local warned = false
	for _, text in w6.Warnings do if string.find(text, "ChoseSide", 1, true) then warned = true end end
	check(not warned, "no warning for the owned badge (it would repeat every 5 minutes)", show(w6.Warnings))
	-- the player leaves while the badge call runs: no retry entry is kept for the gone Player
	local w7 = retWorld({ EditConfig = withBadges })
	w7.BadgeAnswer = false
	w7.AllowWarn = "badge"
	w7.OnAward = function(uid)
		local gone = uid == 7 and w7.Players:GetPlayerByUserId(7) or nil
		if gone then w7:Leave(gone) end
	end
	local s7 = hero(w7, 7) -- the join's badge check calls AwardBadge, and the player leaves during that call
	check(s7.Parent == nil and w7.Reg.ReturnService.DebugRetryCount() == 0, "a player who left during the call keeps no retry entry",
		tostring(w7.Reg.ReturnService.DebugRetryCount()))
	local stay = hero(w7, 8)
	check(w7.Reg.ReturnService.DebugRetryCount() >= 1, "a player still here does get the retry entry", tostring(w7.Reg.ReturnService.DebugRetryCount()))
	local _67 = { s6, stay }
	-- after the season: candy no longer opens Halloween 2026
	local w3 = retWorld({ EditConfig = withBadges, Time = w.Config.Halloween.EndsAt + 100 })
	local r = hero(w3, 3)
	w3.Reg.LootService.ItemsGranted:Fire(r, { { Id = "Candy", N = 1 } })
	w3:RunSpawned()
	check(table.find(w3.Badges, "3:108") == nil, "after the season: no Halloween 2026 from new candy", table.concat(w3.Badges, ","))
end)

------------------------------------------------------------------ #5 opt-in
runGroup("opt-in moment", function()
	local w = retWorld()
	local OptIn = w.Reg.ReturnService.OptInMoment
	local p1, d1 = hero(w, 1, { Data = { PlaytimeSeconds = 300 } })
	check(OptIn(p1, "Diary") == false and #w:FxOf("OptInMoment", p1) == 0, "the first 10 minutes: never", "")
	local p2, d2 = hero(w, 2)
	check(OptIn(p2, "Diary") == true and w:FxOf("OptInMoment", p2)[1].Data.Why == "Diary", "20 minutes played: Fx OptInMoment",
		show(w:FxOf("OptInMoment", p2)[1] and w:FxOf("OptInMoment", p2)[1].Data))
	check(OptIn(p2, "Diary") == false, "one a session", "")
	local p3 = hero(w, 3)
	w.Reg.CombatService.KnockedOut:Fire(p3, "Monster")
	check(OptIn(p3, "Daily") == false, "right after a KO: no", "")
	w:Advance(61)
	check(OptIn(p3, "Daily") == true, "a minute later: yes", "")
	local p4 = hero(w, 4)
	w.Reg.LootService.Enhanced:Fire(p4, 2, 3, 2, false, "Enh30")
	check(OptIn(p4, "Daily") == false, "right after a failed scroll: no", "")
	local p5 = hero(w, 5)
	w.Reg.TelemetryService.ClientMetric:Fire(p5, "PurchasePrompt", "VIP")
	check(OptIn(p5, "Daily") == false, "right after a purchase prompt: no", "")
	-- "cannot" (under 13 / already decided): asked again only after 30 days
	w.Reg.TelemetryService.ClientMetric:Fire(p2, "OptIn", "cannot")
	check(d2.Return.OptIn == "cannot", "cannot saved", show(d2.Return))
	w:Leave(p2)
	local w2 = retWorld({ Time = w.Time + 86400 })
	local q = hero(w2, 2, { Data = { Return = deepCopy(d2.Return) } })
	check(w2.Reg.ReturnService.OptInMoment(q, "Daily") == false, "cannot: not again the next day", "")
	local w3 = retWorld({ Time = w.Time + 31 * 86400 })
	local r = hero(w3, 2, { Data = { Return = deepCopy(d2.Return) } })
	check(w3.Reg.ReturnService.OptInMoment(r, "Daily") == true, "cannot: again after 30 days", "")
	-- shown: never again, also in a later session (another server, a year later)
	local w4 = retWorld({ Time = w.Time + 365 * 86400 })
	local s4 = hero(w4, 9, { Data = { Return = { Badges = {}, OptIn = "shown", OptInAt = w.Time } } })
	check(w4.Reg.ReturnService.OptInMoment(s4, "Daily") == false, "shown once: never asked again", "")
	w.Reg.TelemetryService.ClientMetric:Fire(p1, "OptIn", "yes please")
	check(d1.Return.OptIn == "", "an unknown result is ignored", show(d1.Return))
end)

runGroup("broken saves are repaired", function()
	local w = retWorld()
	local p, d = hero(w, 1, { Data = { Return = "x", Diary = 5 } })
	check(type(d.Return) == "table" and type(d.Return.Badges) == "table" and d.Return.OptIn == "" and d.Return.OptInAt == 0,
		"a non-table Return starts fresh", show(d.Return))
	local q, dq = hero(w, 2, { Data = { Return = { Badges = { Nope = { Id = 1, At = 1 }, ChoseSide = "x", Stronger = 7,
		FirstSlime = { Id = 102, At = 5 }, Rank2 = { Id = 0, At = 5 } }, OptIn = "maybe", OptInAt = -3 } } })
	check(dq.Return.Badges.Nope == nil and dq.Return.Badges.ChoseSide == nil and dq.Return.Badges.Stronger == nil
		and dq.Return.Badges.Rank2 == nil and dq.Return.Badges.FirstSlime.Id == 102 and dq.Return.Badges.FirstSlime.At == 5
		and dq.Return.OptIn == "" and dq.Return.OptInAt == 0, "unknown badges / bad values dropped, { Id, At } kept, OptIn reset",
		show(dq.Return))
	check(type(d.Diary) == "table" and d.Diary.Pages == 0, "a broken Diary starts at page 0", show(d.Diary))
	local _ = { p, q }
end)

------------------------------------------------------------------ #3 invites / Go to friend
runGroup("invite join", function()
	local w = retWorld({ Friends = { ["1:2"] = true } })
	local got = {}
	w.Reg.InviteService.InviteJoined:Connect(function(invitee, by, inviter)
		table.insert(got, invitee.UserId .. "<" .. by .. ":" .. tostring(inviter and inviter.UserId))
	end)
	local inviter = hero(w, 1)
	local p, d = hero(w, 2, { Join = { LaunchData = "1" } })
	check(table.concat(got, ",") == "2<1:1" and d.Invite.By == 1, "LaunchData '1': an invite join, the inviter is here",
		table.concat(got, ","))
	local q, dq = hero(w, 3, { Join = { LaunchData = "777" } })
	check(got[2] == "3<777:nil" and dq.Invite.By == 777, "an inviter on another server", tostring(got[2]))
	local r, dr = hero(w, 4, { Join = { LaunchData = "4" } })
	local s, ds = hero(w, 5, { Join = { LaunchData = "12abc" } })
	local t, dt = hero(w, 6, { Join = { LaunchData = "1.5" } })
	local u, du = hero(w, 7, { Join = { LaunchData = string.rep("9", 30) } })
	local x, dx = hero(w, 9, { Join = { LaunchData = "0x1" } }) -- tonumber("0x1") = 1: only plain digits count
	local y, dy = hero(w, 10, { Join = { LaunchData = " 1" } })
	check(#got == 2 and next(dr.Invite) == nil and next(ds.Invite) == nil and next(dt.Invite) == nil and next(du.Invite) == nil
		and next(dx.Invite) == nil and next(dy.Invite) == nil,
		"my own id / text / a fraction / too long / hex / a space: not an invite", tostring(#got))
	local _xy = { x, y }
	local v, dv = hero(w, 8, { Join = { LaunchData = "1" }, Data = { Invite = { By = 99, At = 5 } } })
	check(dv.Invite.By == 99, "the first invite that brought a player is kept", show(dv.Invite))
	-- 10 minutes together -> PlayedTogether once
	local pairs = {}
	w.Reg.InviteService.PlayedTogether:Connect(function(a, b) table.insert(pairs, a.UserId .. "+" .. b.UserId) end)
	for _ = 1, 9 do w:Tick(60) end
	check(#pairs == 0, "9 minutes: not yet", #pairs)
	w:Tick(60)
	table.sort(pairs)
	check(table.concat(pairs, ",") == "1+2,1+8", "10 minutes on one server: PlayedTogether(inviter, invitee) once each",
		table.concat(pairs, ","))
	w:Tick(60)
	check(#pairs == 2, "never again", #pairs)
	local _ = { inviter, p, q, r, s, t, u, v }
end)

runGroup("Go to friend", function()
	local w = retWorld({ Friends = { ["1:2"] = true, ["1:3"] = true, ["1:4"] = true } })
	w.Gap = 3.1 -- GoToFriend is 3 s
	local me = hero(w, 1, { Data = { Level = 8 }, Attrs = { ZoneId = "Crossroads" } })
	local meadowFriend = hero(w, 2, { Attrs = { ZoneId = "SlimeMeadow" } })
	local woodsFriend = hero(w, 3, { Data = { Level = 20 }, Attrs = { ZoneId = "GoblinWoods" } })
	local hornsFriend = hero(w, 4, { Data = { Faction = "Horns" }, Attrs = { ZoneId = "HornsTown" } })
	local stranger = hero(w, 5, { Attrs = { ZoneId = "SlimeMeadow" } })
	local Z = w.Reg.ZoneService
	local function go(target, ...)
		local before = #Z.Travels
		if select("#", ...) > 0 then w:Remote("GoToFriend", me, ...) else w:Remote("GoToFriend", me, target.UserId) end
		return Z.Travels[before + 1]
	end
	local trip = go(meadowFriend)
	check(trip and trip.Dest == "SlimeMeadow" and trip.Instant == false, "a friend in the meadow: ZoneService.Travel there (the "
		.. "normal channel and its rules)", show(trip and { trip.Dest, trip.Instant }))
	check(go(stranger) == nil, "not a Roblox friend: nothing", "")
	local n = #w:NoticesFor(me)
	check(go(woodsFriend) == nil and w:NoticesFor(me)[n + 1] == "Your friend is in a PvP zone. Come at Lv 15!",
		"a sprout and a friend in the PvP woods: never sent there", tostring(w:NoticesFor(me)[n + 1]))
	n = #w:NoticesFor(me)
	check(go(hornsFriend) == nil and w:NoticesFor(me)[n + 1] == "Your friend is in the other side's town.",
		"the other side's town: a line, no trip", tostring(w:NoticesFor(me)[n + 1]))
	check(go(meadowFriend, "2") == nil and go(meadowFriend, 2, "x") == nil and go(meadowFriend, 2.5) == nil and go(me, 1) == nil,
		"a string / two arguments / a fraction / myself: ignored", "")
	-- a Lv20 me: the woods are fine; the travel rules answer through ZoneService
	local w2 = retWorld({ Friends = { ["1:3"] = true } })
	w2.Gap = 3.1
	local me2 = hero(w2, 1, { Data = { Level = 20 }, Attrs = { ZoneId = "Crossroads" } })
	local wf = hero(w2, 3, { Data = { Level = 20 }, Attrs = { ZoneId = "GoblinWoods" } })
	w2:Remote("GoToFriend", me2, 3)
	check(w2.Reg.ZoneService.Travels[1] and w2.Reg.ZoneService.Travels[1].Dest == "GoblinWoods", "Lv20: to the woods", "")
	w2.TravelAnswer = { false, "Can't travel while fighting!" }
	w2:Remote("GoToFriend", me2, 3)
	check(w2:NoticesFor(me2)[#w2:NoticesFor(me2)] == "Can't travel while fighting!", "ZoneService's no is said as it is",
		show(w2:NoticesFor(me2)))
	w2.TravelAnswer = nil
	w2.Gap = 1
	w2:Remote("GoToFriend", me2, 3)
	check(#w2.Reg.ZoneService.Travels == 2, "GoToFriend is rate limited (3 s)", #w2.Reg.ZoneService.Travels)
	-- same zone, seasonal field, my own town, a friend who left
	local w3 = retWorld({ Friends = { ["1:2"] = true, ["1:3"] = true, ["1:4"] = true } })
	local me3 = hero(w3, 1, { Attrs = { ZoneId = "SlimeMeadow" } })
	local f2 = hero(w3, 2, { Attrs = { ZoneId = "SlimeMeadow" } })
	local f3 = hero(w3, 3, { Attrs = { ZoneId = "PumpkinPatch" } })
	local f4 = hero(w3, 4, { Attrs = { ZoneId = "HaloTown" } })
	w3:Remote("GoToFriend", me3, 2)
	check(#w3.Reg.ZoneService.Travels == 0 and w3:NoticesFor(me3)[1] == "You're already there!", "already in that zone", "")
	w3.Gap = 3.1
	w3:Remote("GoToFriend", me3, 4)
	check(w3.Reg.ZoneService.Travels[1] and w3.Reg.ZoneService.Travels[1].Dest == "Home", "a friend in my own town: Home", "")
	me3:SetAttribute("ZoneId", "Crossroads")
	w3:Remote("GoToFriend", me3, 3)
	check(w3.Reg.ZoneService.Travels[2] and w3.Reg.ZoneService.Travels[2].Dest == "SlimeMeadow",
		"a friend in a seasonal field: its entrance field", "")
	w3:Leave(f2)
	w3:Remote("GoToFriend", me3, 2)
	check(w3:NoticesFor(me3)[#w3:NoticesFor(me3)] == "Your friend is not on this server.", "a friend who left: one line", "")
	local went = {}
	w3.Reg.InviteService.WentToFriend:Connect(function(p, z) table.insert(went, p.UserId .. ">" .. z) end)
	w3:Remote("GoToFriend", me3, 4)
	check(table.concat(went, ",") == "1>HaloTown", "WentToFriend(player, the friend's zone) for the metrics", table.concat(went, ","))
	-- an invite pair counts as friends (an invite only goes to friends anyway)
	local w4 = retWorld()
	local a = hero(w4, 1, { Attrs = { ZoneId = "Crossroads" } })
	local b = hero(w4, 2, { Join = { LaunchData = "1" }, Attrs = { ZoneId = "SlimeMeadow" } })
	w4:Remote("GoToFriend", a, 2)
	check(w4.Reg.ZoneService.Travels[1] and w4.Reg.ZoneService.Travels[1].Dest == "SlimeMeadow" and w4.FriendCalls == 0,
		"my invitee: no friend web call needed", tostring(w4.FriendCalls))
	local _ = { wf, f3, b }
end)

------------------------------------------------------------------ #4 King Diary / candy jar
local DAY1 = 1793372400 -- 2026-10-31 00:00 KST (Banter.DayOneStart)

runGroup("King Diary", function()
	local w = retWorld({ Time = DAY1 + 12 * 3600 }) -- season day 1
	local p, d = hero(w, 1)
	local q = hero(w, 2)
	local K = w.Reg.HalloweenService.KingDefeated
	local opened = {}
	w.Reg.DiaryService.PageOpened:Connect(function(pl, page, late) table.insert(opened, pl.UserId .. ":" .. page .. ":" .. tostring(late)) end)
	K:Fire("PumpkinKing", "PumpkinKing", { 1 })
	check(d.Diary.Pages == 1 and p:GetAttribute("DiaryPages") == 1 and w:FxOf("DiaryPage", p)[1].Data.Page == 1,
		"day 1: a king beaten together opens page 1", show(d.Diary))
	K:Fire("GhostKing", "GhostKing", { 1, 2 })
	check(d.Diary.Pages == 1, "day 1: page 1 is today's last page (no more before tomorrow)", show(d.Diary))
	check(q:GetAttribute("DiaryPages") == 1, "the other contributor gets their page 1", tostring(q:GetAttribute("DiaryPages")))
	check(#w:FxOf("OptInMoment", p) == 1, "after the first page the opt-in moment may come", #w:FxOf("OptInMoment", p))
	-- day 5: catch up one page per king, never past page 5
	w:Advance(4 * 86400)
	for _ = 1, 6 do K:Fire("PumpkinKing", "PumpkinKing", { 1 }) end
	check(d.Diary.Pages == 5, "day 5: caught up to page 5 (one per king), not past it", show(d.Diary))
	check(opened[2] == "2:1:false" and opened[3] == "1:2:true" and opened[6] == "1:5:false",
		"PageOpened(player, page, late): late while catching up", table.concat(opened, ","))
	check(w.Reg.DiaryService.TomorrowLine(q) == "King Diary page 2" and w.Reg.DiaryService.TomorrowLine(p) == "King Diary page 6",
		"the pause card line: the next page", tostring(w.Reg.DiaryService.TomorrowLine(q)))
	-- day 9: the last page -> the title + confetti once
	w:Advance(4 * 86400)
	for _ = 1, 6 do K:Fire("PumpkinKing", "PumpkinKing", { 1 }) end
	check(d.Diary.Pages == 9 and d.Diary.Done == true and d.Titles.PartyGuest2026 ~= nil and #w:FxOf("DiaryDone", p) == 1,
		"page 9: 'Party Guest 2026' + Fx DiaryDone once", show(d.Diary))
	-- not a contributor: nothing
	local r, dr = hero(w, 3)
	K:Fire("PumpkinKing", "PumpkinKing", { 1, 2 })
	check(dr.Diary.Pages == 0, "a player the kill did not pay: no page", show(dr.Diary))
	-- the tomorrow line on the last day: none (a full book; the season ends tonight)
	check(w.Reg.DiaryService.TomorrowLine(p) == nil and w.Reg.DiaryService.TomorrowLine(q) == nil,
		"day 9: no tomorrow line (a full book / no day 10)", tostring(w.Reg.DiaryService.TomorrowLine(q)))
	-- after the season: no pages
	w:Advance(86400)
	local s, ds = hero(w, 4)
	K:Fire("PumpkinKing", "PumpkinKing", { 4 })
	check(ds.Diary.Pages == 0 and w.Reg.DiaryService.TomorrowLine(s) == nil, "after 11/09: no new pages, no line", show(ds.Diary))
	local _ = r
end)

runGroup("candy jar", function()
	local w = retWorld()
	local p, d = hero(w, 1, { Data = { Items = { Candy = 120 } } })
	local traded = {}
	w.Reg.DiaryService.CandyTraded:Connect(function(pl, id, n) table.insert(traded, pl.UserId .. ":" .. id .. ":" .. n) end)
	w:Remote("CandyTrade", p, "PumpkinPal")
	check(d.Items.Candy == 70 and d.Titles.PumpkinPal ~= nil and traded[1] == "1:PumpkinPal:50",
		"50 candy -> 'Pumpkin Pal'", show(d.Items))
	w:Remote("CandyTrade", p, "PumpkinPal")
	check(d.Items.Candy == 70 and #traded == 1, "a title owned: no candy taken (enough candy for it again)", show(d.Items))
	w:Remote("CandyTrade", p, "CandyKeeper")
	check(d.Items.Candy == 70 and d.Titles.CandyKeeper == nil and w:NoticesFor(p)[#w:NoticesFor(p)] == "You need 200 candy.",
		"not enough candy: nothing taken, one line", show(d.Items))
	d.Items.Candy = 250
	w:Remote("CandyTrade", p, "Nope")
	w:Remote("CandyTrade", p, "CandyKeeper", "x")
	w:Remote("CandyTrade", p, 5)
	check(#traded == 1 and d.Items.Candy == 250 and d.Titles.CandyKeeper == nil,
		"unknown id / two arguments / a number: ignored (even with candy for it)", #traded)
	w:Remote("CandyTrade", p, "CandyKeeper")
	check(d.Items.Candy == 50 and d.Titles.CandyKeeper ~= nil and #traded == 2, "200 candy -> 'Candy Keeper'", show(d.Items))
	-- after the season the jar stays open
	local w2 = retWorld({ Time = w.Config.Halloween.EndsAt + 86400 })
	local q, dq = hero(w2, 2, { Data = { Items = { Candy = 250 } } })
	w2:Remote("CandyTrade", q, "CandyKeeper")
	check(dq.Items.Candy == 50 and dq.Titles.CandyKeeper ~= nil, "after 11/09: still open", show(dq.Items))
end)

finish()
