-- first_ko_offline.luau : A23-109 / A23-110 the King's Hop (KO1): a new player with no potions meets the King Slime (a lossless
-- KO that game dev 2's personal King reports with StoryQuestService.Event "FirstKO"), buys a potion, drinks it from the quick
-- slot and wins the rematch. tools/test_first_ko.py binds the dev2_combat_world sources (the real StoryQuestService and
-- LootService); the potion shop / drink hooks are checked in tools/fixtures/potions_offline.luau.

local SQ0 = C0.StoryQuests
local KO = SQ0.Defs.KO1

-- a started story world: the 1 s loop is never run (Refresh is called by hand), XP / gold are recorded
local function koWorld(o)
	o = o or {}
	local w = bareWorld({})
	local reg = w.Registry
	local Signal = w.Util.Signal
	reg.ZoneService.ZoneChanged = Signal.new()
	reg.ZoneService.GetZoneId = function(p) return (w.ZoneOf and w.ZoneOf[p]) or "SlimeMeadow" end
	reg.GooseService.GooseFinished = Signal.new()
	w.XP, w.ZoneOf, w.GoldGiven = {}, {}, {}
	reg.RankingService = setmetatable({}, { __index = function() return function() end end })
	local ws = w:Env().workspace
	ws.FindFirstChild = function() return nil end
	local rs = w.Services.ReplicatedStorage
	if not rs.FindFirstChild then rs.FindFirstChild = function() return nil end end
	local pg = reg.ProgressionService
	pg.AddXP = function(_, n) table.insert(w.XP, { N = n }) end
	function pg.GetTotalGold(p)
		local d = w.Data[p]
		return d and ((d.CarriedGold or 0) + (d.BankGold or 0)) or 0
	end
	local addCarried = pg.AddCarriedGold
	function pg.AddCarriedGold(p, n, source)
		table.insert(w.GoldGiven, { N = n, Source = source })
		return addCarried(p, n)
	end
	w.Services.CollectionService = { GetTagged = function() return {} end }
	w.Story.Start()
	-- every GrantItem the story service asks for (the scroll of KO1's reward); loot drops of the kills go another way
	w.Granted = {}
	local loot = reg.LootService
	local grant = loot.GrantItem
	loot.GrantItem = function(p, id, n)
		table.insert(w.Granted, { Id = id, N = n })
		return grant(p, id, n)
	end
	w.Net.Get("OpenPanel")
	-- the real QuickSlotService (it tells the story service when a potion goes into a slot)
	if o.Quick then
		local quick = w:Load("QuickSlotService", QUICK_SOURCE)
		reg.QuickSlotService = quick
		quick.Init(reg)
		quick.Start()
		w.Quick = quick
	end
	function w:Act(p, id, action, option)
		self:Advance(1) -- RateLimits.StoryAction
		self.Net.Get("StoryAction").OnServerEvent:Fire(p, id, action, option)
		self:Flush()
	end
	function w:Kill(p, kind, o)
		o = o or {}
		reg.MonsterService.MonsterKilled:Fire(p, { Kind = kind, ZoneId = o.Zone or "SlimeMeadow", Golden = false, Personal = o.Personal == true,
			Position = vec(0, 0, 0), WarPoints = 0 })
		self:Flush()
	end
	function w:Track(d, id) return d.Story and d.Story.Subs and d.Story.Subs[id] end
	return w
end

-- a ready player who finished M1_1 and M1_2 (the Slime Princes), with no potions, at `o.Level`
local function joinKO(w, userId, faction, o)
	o = o or {}
	local story = { Main = { Id = "" }, Subs = {}, Done = o.Done or { M1_1 = true, M1_2 = true }, Pick = {},
		First = o.First or { Migrated = true } }
	local data = { Story = story }
	for k, v in o.Data or {} do data[k] = v end
	local p, d = w:Join(userId, { Faction = faction, Class = "Warrior", Level = o.Level or 4, Carried = o.Carried, Bank = o.Bank, Data = data })
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end

local function rowOf(w, p, d, id)
	w.Config.StoryQuests.MaxSubs = 20
	for _, r in w.Story.SubRows(p, d) do
		if r.Story and r.Story.Id == id then return r end
	end
	return nil
end

-- a line mentioning any of the words (lowercase) among the notices a player got since `from`
local function noticeAbout(w, p, from, words)
	for _, t in w:NoticesFor(p, from) do
		local low = string.lower(t)
		for _, word in words do
			if string.find(low, word, 1, true) then return t end
		end
	end
	return nil
end

local function panelsOf(w)
	local out = {}
	local op = w.Net.Get("OpenPanel")
	local base = op.FireClient
	op.FireClient = function(self, p, kind, arg)
		table.insert(out, { P = p, Kind = kind, Arg = arg })
		return base(self, p, kind, arg)
	end
	return out
end

-- the record DataService really builds for a brand-new player in Studio (memory mode: ServerStorage StudioFreshSave, or a Studio
-- without DataStore access), run for real in its own world
local function memoryRecord(userId)
	local w = newWorld({ Studio = true })
	w.AllowWarn = { "StudioFreshSave", "had type" }
	w.Services.ServerStorage = { GetAttribute = function(_, key) return key == "StudioFreshSave" and true or nil end }
	local env = w:Env()
	env.task = table.clone(env.task)
	env.task.wait = function(t)
		coroutine.yield(tonumber(t) or 0)
		return t
	end
	local ds = execute("DataService", DATA_SOURCE, env)
	ds.Init({})
	ds.Start()
	local probe = table.remove(w.Spawned, 1)
	w.Spawned = {}
	probe[1](table.unpack(probe, 2, probe.n))
	local co = coroutine.create(ds.Load)
	local out = table.pack(coroutine.resume(co, w:NewPlayer(userId)))
	local n = 0
	while coroutine.status(co) ~= "dead" do
		assert(out[1], out[2])
		n += 1
		assert(n < 200, "runaway waits")
		out = table.pack(coroutine.resume(co))
	end
	assert(out[1], out[2])
	return out[2]
end

------------------------------------------------------------------ 1. the definition
runGroup("config", function()
	check(KO ~= nil and KO.Kind == "Sub" and KO.Title == "The King's Hop" and #KO.Steps == 5 and KO.Hidden == nil,
		"KO1: a visible sub 'The King's Hop' with five steps", show(KO and #KO.Steps))
	local subs, count = SQ0.Subs, 0
	for _, id in subs do if id == "KO1" then count += 1 end end
	check(count == 1, "KO1 is in StoryQuests.Subs exactly once", tostring(count))
	local req = KO.Requires
	check(type(req) == "table" and #req.Done == 1 and req.Done[1] == "M1_2" and req.MaxLevel == 8 and req.NoPotionYet == true,
		"opens after M1_2, up to Lv8, only with no potion yet", show(req))
	local s = KO.Steps
	check(s[1].Text == "Defeat the King Slime" and s[1].Obj.Type == "Event" and s[1].Obj.Name == "FirstKO" and s[1].Obj.Past == nil
		and s[1].Guide == "SlimeMeadow", "step 1: Defeat the King Slime = the FirstKO happening (never skipped by an old one)", show(s[1].Obj))
	check(s[2].Text == "Buy a potion" and s[2].Obj.Type == "Event" and s[2].Obj.Name == "PotionBought" and s[2].Obj.Past == true
		and s[2].TopUpGold == 50 and s[2].Guide == "PotionShop", "step 2: Buy a potion = PotionBought (passes when seen before), tops up to 50 gold, guides to the seller (PotionShop)",
		show(s[2]))
	check(s[3].Text == "Put the potion in a quick slot" and s[3].Obj.Type == "Event" and s[3].Obj.Name == "QuickSlotSet" and s[3].Obj.Past == true
		and s[3].Obj.Held == "QuickSlots" and s[3].TopUpGold == nil and s[3].Guide == "QuickSlot",
		"step 3: Put the potion in a quick slot = QuickSlotSet (passes when seen before or a slot is already filled), guides to the bag's slots (QuickSlot)", show(s[3]))
	check(s[4].Text == "Drink it from your quick slot" and s[4].Obj.Type == "Event" and s[4].Obj.Name == "PotionUsed" and s[4].Obj.Past == true
		and s[4].TopUpGold == nil and s[4].Guide == "QuickSlot", "step 4: Drink it from your quick slot = PotionUsed (passes when seen before)", show(s[4]))
	check(s[5].Text == "Defeat the King Slime" and s[5].Obj.Type == "Kill" and s[5].Obj.Kind == "SlimeKing" and s[5].Obj.Personal == true
		and s[5].Obj.Count == 1 and s[5].Obj.Zone == "SlimeMeadow" and s[5].Guide == "SlimeMeadow",
		"step 5: the rematch = one personal King Slime kill in the meadow", show(s[5].Obj))
	check(KO.Reward.Gold == 2 and KO.Reward.XP == 2 and KO.Reward.Item == "Enh70" and KO.Reward.N == 1 and KO.Finish == nil
		and KO.Start == nil and KO.Pop == nil and KO.Claim == nil, "two minutes of hunting + one 70% scroll; no Start / Finish / Pop / Claim (A23-99: no popups, no toasts)", show(KO.Reward))
	for i, step in s do
		check(type(step.ShortName) == "string" and #step.ShortName <= 14 and step.Start == nil and step.Panel == nil,
			"step " .. i .. ": a phone short name (<= 14), no Start line, no panel", tostring(step.ShortName))
	end
	check(#KO.ShortName <= 14, "KO1 has a short name for the phone row", tostring(KO.ShortName))
	local events = SQ0.Events
	check(events and events.FirstKO == true and events.PotionBought == true and events.QuickSlotSet == true and events.PotionUsed == true,
		"the happenings are listed in Config.StoryQuests.Events", show(events))
	for _, step in s do
		if step.Obj.Type == "Event" then
			check(events[step.Obj.Name] == true, "every Event step waits for a listed happening: " .. step.Obj.Name, "")
		end
	end
	local f = C0.FirstKO
	check(f and f.Quest == "KO1" and f.Step == 1 and f.RematchStep == 5 and s[f.RematchStep].Obj.Type == "Kill" and s[f.Step].Obj.Name == "FirstKO",
		"Config.FirstKO tells game dev 2 the quest, the KO step (1) and the rematch step (5)", show(f))
	check(f and f.SipAttr == "PotionSip", "Config.FirstKO.SipAttr = the attribute game dev 1's VitalsUI reads (PotionSip)", show(f))
	check(C0.PotionStockKey("HP") == "HPPotionCount" and C0.Text.PotionPractice ~= nil, "the potion stock keys and the practice-sip line exist", "")
	local Q = C0.QuickSlots
	check(Q and Q.Attr == "QuickSlots" and Q.Default[1] == "" and Q.Default[2] == "" and Q.Default[3] == "", "a new player's quick slots start empty (the Held field is data.QuickSlots)", show(Q and Q.Default))
end)

------------------------------------------------------------------ 2. who is offered it, and quietly
runGroup("offered", function()
	local w = koWorld()
	local panels = panelsOf(w)
	local uid = 1100
	for _, faction in { "Halo", "Horns", "Neutral" } do
		uid += 1
		local before, n0 = #panels, #w.Notices
		local p, d = joinKO(w, uid, faction)
		local tr = w:Track(d, "KO1")
		local row = rowOf(w, p, d, "KO1")
		check(tr ~= nil and tr.St == 1 and #panels == before and noticeAbout(w, p, n0, { "king", "potion", "hop" }) == nil,
			faction .. ": after M1_2 the quest is just a row: no popup, no toast", show({ tr, #panels - before, noticeAbout(w, p, n0, { "king", "potion", "hop" }) }))
		check(row ~= nil and row.Text == "Defeat the King Slime" and row.ShortName == "Defeat King" and row.Story.Guide == "SlimeMeadow"
			and row.Story.Panel == nil and row.CanClaim == false and row.Kind == "Sub", faction .. ": row 1 reads 'Defeat the King Slime', guides to the meadow", show(row))
		check(w.Story.CurrentStep(p, "KO1") == 1 and w.Story.Wants(p, "FirstKO") == true and w.Story.Wants(p, "PotionBought") == false,
			faction .. ": CurrentStep 1; the quest waits for FirstKO only", show({ w.Story.CurrentStep(p, "KO1"), w.Story.Wants(p, "FirstKO") }))
	end
	-- the boundary of the level and the other keeps
	local function offered(name, o, expect)
		uid += 1
		local _, d = joinKO(w, uid, "Halo", o)
		check((w:Track(d, "KO1") ~= nil) == expect, name .. (expect and ": offered" or ": not offered"), show(w:Track(d, "KO1")))
		return d
	end
	offered("Lv8 (the last level)", { Level = 8 }, true)
	offered("Lv9", { Level = 9 }, false)
	offered("before M1_2", { Done = { M1_1 = true } }, false)
	offered("an HP potion in the bag", { Data = { HPPotionCount = 1 } }, false)
	offered("an MP potion in the bag", { Data = { MPPotionCount = 2 } }, false)
	offered("a potion bought once (and used)", { First = { Migrated = true, PotionBought = true } }, false)
	offered("a potion drunk once", { First = { Migrated = true, PotionUsed = true } }, false)
	offered("already done", { Done = { M1_1 = true, M1_2 = true, KO1 = true } }, false)
	-- the quest does not start twice and nothing restarts it
	local p, d = joinKO(w, uid + 1, "Halo")
	uid += 1
	d.Story.Subs.KO1.St = 3
	for _ = 1, 3 do w.Story.Refresh(p) end
	check(d.Story.Subs.KO1.St == 3, "a started quest is never restarted by the 1 s loop", show(d.Story.Subs.KO1))
	-- a player who has the potion bag after the quest started keeps it (the check is only for the start)
	d.HPPotionCount = 3
	w.Story.Refresh(p)
	check(d.Story.Subs.KO1 ~= nil and d.Story.Subs.KO1.St == 3, "buying potions after the start never cancels the quest", show(d.Story.Subs.KO1))
end)

------------------------------------------------------------------ 3. the five steps, in order
runGroup("flow", function()
	local w = koWorld()
	local panels = panelsOf(w)
	local done = {}
	w.Story.QuestDone:Connect(function(_, id) table.insert(done, id) end)
	-- A23-113 #2: the funnel's steps come from StepDone, one per quest step, in order, before the next opens
	local stepLog = {}
	w.Story.StepDone:Connect(function(_, id, step) if id == "KO1" then table.insert(stepLog, step) end end)
	local uid = 1200
	for _, faction in { "Halo", "Horns", "Neutral" } do
		uid += 1
		local p, d = joinKO(w, uid, faction, { Data = { QuickSlots = ",," } })
		local tr = w:Track(d, "KO1")
		local n0, panels0, gold0 = #w.Notices, #panels, #w.GoldGiven
		-- nothing a stranger says moves it
		check(w.Story.Event(p, "Nope") == false and w.Story.Event(p, nil) == false and w.Story.Event(p, 5) == false and w.Story.Event(nil, "FirstKO") == false
			and w.Story.Event("Halo", "FirstKO") == false and w.Story.Event({}, "FirstKO") == false and tr.St == 1 and d.Story.First.Nope == nil,
			faction .. ": unknown names / non-players do nothing", show(tr))
		w:Act(p, "KO1", "Talk")
		w:Act(p, "KO1", "Open")
		w:Act(p, "KO1", "Choose", "Good")
		check(tr.St == 1 and #panels == panels0, faction .. ": the client cannot move the quest (no Talk / Choose / Open on an Event step)", show(tr))
		-- 1. the KO
		check(w.Story.Event(p, "FirstKO", { Test = true }) == true and tr.St == 2 and d.Story.First.FirstKO == true
			and w.Story.CurrentStep(p, "KO1") == 2, faction .. ": FirstKO moves step 1 to 2 and is remembered", show({ tr, d.Story.First }))
		check(#w.GoldGiven == gold0 + 1 and w.GoldGiven[#w.GoldGiven].N == 50 and w.GoldGiven[#w.GoldGiven].Source == "Choice"
			and d.CarriedGold == 50 and d.Story.First.TopKO12 == true, faction .. ": a player with no gold gets 50 carried gold (source 'Choice', never doubled), saved once",
			show({ w.GoldGiven[#w.GoldGiven], d.CarriedGold, d.Story.First }))
		local row = rowOf(w, p, d, "KO1")
		check(row.Text == "Buy a potion" and row.ShortName == "Buy a potion" and row.Story.Guide == "PotionShop" and row.Story.St == 2,
			faction .. ": row 2 reads 'Buy a potion' and guides to the seller", show(row))
		check(w.Story.Wants(p, "PotionBought") == true and w.Story.Wants(p, "FirstKO") == false and w.Story.Wants(p, "PotionUsed") == false
			and w.Story.Wants(p, "QuickSlotSet") == false, faction .. ": step 2 waits for PotionBought only", "")
		check(p:GetAttribute("PotionSip") == false, faction .. ": steps 1-2: the client may not use a full bar yet (PotionSip false)", tostring(p:GetAttribute("PotionSip")))
		-- the KO does not repeat the step
		check(w.Story.Event(p, "FirstKO") == false and tr.St == 2, faction .. ": a second KO moves nothing", show(tr))
		-- 2. the purchase
		check(w.Story.Event(p, "PotionBought", { Kind = "HP", N = 1 }) == true and tr.St == 3, faction .. ": PotionBought moves step 2 to 3", show(tr))
		row = rowOf(w, p, d, "KO1")
		check(row.Text == "Put the potion in a quick slot" and row.ShortName == "Quick slot" and row.Story.Guide == "QuickSlot" and row.Story.St == 3,
			faction .. ": row 3 reads 'Put the potion in a quick slot' (guide: the bag's slots)", show(row))
		check(w.Story.Wants(p, "QuickSlotSet") == true and w.Story.Wants(p, "PotionBought") == false and w.Story.Wants(p, "PotionUsed") == false,
			faction .. ": step 3 waits for QuickSlotSet only", "")
		check(p:GetAttribute("PotionSip") == false, faction .. ": step 3: no sip yet (the potion is not in a slot)", tostring(p:GetAttribute("PotionSip")))
		check(#w.GoldGiven == gold0 + 1, faction .. ": no second top-up", show(w.GoldGiven))
		-- 3. the slot
		check(w.Story.Event(p, "QuickSlotSet", { Slot = 1, Kind = "HP" }) == true and tr.St == 4, faction .. ": QuickSlotSet moves step 3 to 4", show(tr))
		row = rowOf(w, p, d, "KO1")
		check(row.Text == "Drink it from your quick slot" and row.ShortName == "Drink potion" and row.Story.Guide == "QuickSlot" and row.Story.St == 4,
			faction .. ": row 4 reads 'Drink it from your quick slot'", show(row))
		check(w.Story.Wants(p, "PotionUsed") == true and w.Story.Wants(p, "QuickSlotSet") == false, faction .. ": step 4 waits for PotionUsed only", "")
		check(p:GetAttribute("PotionSip") == true, faction .. ": step 4: PotionSip is true at once (the client lets a full bar be used)", tostring(p:GetAttribute("PotionSip")))
		-- 4. the drink
		check(w.Story.Event(p, "PotionUsed", { Kind = "HP" }) == true and tr.St == 5 and w.Story.Wants(p, "PotionUsed") == false,
			faction .. ": PotionUsed moves step 4 to 5", show(tr))
		check(p:GetAttribute("PotionSip") == false, faction .. ": step 5: PotionSip false again", tostring(p:GetAttribute("PotionSip")))
		row = rowOf(w, p, d, "KO1")
		check(row.Text == "Defeat the King Slime" and row.Story.St == 5 and row.Story.Guide == "SlimeMeadow" and row.CanClaim == false,
			faction .. ": row 5 reads 'Defeat the King Slime' again", show(row))
		-- 5. the rematch: only a personal King Slime kill in the meadow
		w:Kill(p, "SlimeKing", { Personal = false })
		w:Kill(p, "SlimeKing", { Personal = false })
		w:Kill(p, "Slime", { Personal = true })
		w:Kill(p, "BigSlime", { Personal = true })
		w:Kill(p, "SlimeKing", { Personal = true, Zone = "Crossroads" })
		check(tr.St == 5 and w:Track(d, "KO1") == tr and d.Story.Done.KO1 == nil, faction .. ": other kills (a shared King, another monster, another zone) never finish it", show(tr))
		local xp0, bank0, g0 = #w.XP, d.BankGold or 0, #w.Granted
		w:Kill(p, "SlimeKing", { Personal = true })
		check(d.Story.Done.KO1 == true and w:Track(d, "KO1") == nil and done[#done] == "KO1" and w.Story.CurrentStep(p, "KO1") == nil,
			faction .. ": the personal King's defeat finishes it: Done, QuestDone fires, no track left", show({ d.Story.Done.KO1, done }))
		check((d.BankGold or 0) > bank0 and #w.XP == xp0 + 1 and w.XP[#w.XP].N > 0 and #w.Granted == g0 + 1
			and w.Granted[#w.Granted].Id == "Enh70" and w.Granted[#w.Granted].N == 1,
			faction .. ": paid two minutes of hunting gold + XP and one 70% scroll", show({ d.BankGold, w.XP[#w.XP], w.Granted }))
		check(noticeAbout(w, p, n0, { "the king's hop done" }) ~= nil, faction .. ": the usual 'done' line says the quest is over", show(w:NoticesFor(p, n0)))
		-- never again
		local count = 0
		for _, id in done do if id == "KO1" then count += 1 end end
		w:Kill(p, "SlimeKing", { Personal = true })
		w.Story.Refresh(p)
		w.Story.Event(p, "FirstKO")
		check(count == uid - 1200 and w:Track(d, "KO1") == nil and #w.Granted == g0 + 1, faction .. ": never again (one payout)", tostring(count))
		local n = uid - 1200
		check(#stepLog == n * 5 and table.concat(stepLog, ",", (n - 1) * 5 + 1, n * 5) == "1,2,3,4,5", faction .. ": StepDone fired for steps 1-5 of KO1, once each, in order (the FirstKO funnel's feed)", table.concat(stepLog, ","))
	end
end)

------------------------------------------------------------------ 4. the gold top-up
runGroup("top-up", function()
	local w = koWorld()
	local uid = 1300
	local function arriveAt2(name, carried, bank, wantN)
		uid += 1
		local p, d = joinKO(w, uid, "Halo", { Carried = carried, Bank = bank })
		local before = #w.GoldGiven
		w.Story.Event(p, "FirstKO")
		local total = (d.CarriedGold or 0) + (d.BankGold or 0)
		local given = #w.GoldGiven - before
		if wantN > 0 then
			check(given == 1 and w.GoldGiven[#w.GoldGiven].N == wantN and total == 50 and d.BankGold == bank and d.CarriedGold == carried + wantN,
				name .. ": tops up to 50 in total (+" .. wantN .. " carried), the bank is untouched", show({ given, d.CarriedGold, d.BankGold }))
		else
			check(given == 0 and d.CarriedGold == carried and d.BankGold == bank, name .. ": already has 50 or more: nothing added", show({ given, d.CarriedGold, d.BankGold }))
		end
		check(d.Story.First.TopKO12 == true and d.Story.Subs.KO1.St == 2, name .. ": the one-time flag is saved", show(d.Story.First))
		return p, d
	end
	arriveAt2("no gold", 0, 0, 50)
	arriveAt2("30 carried", 30, 0, 20)
	arriveAt2("10 carried + 20 in the bank", 10, 20, 20)
	arriveAt2("49 gold", 0, 49, 1)
	arriveAt2("exactly 50", 50, 0, 0)
	arriveAt2("50 in the bank", 0, 50, 0)
	arriveAt2("500 gold", 500, 300, 0)
	-- the flag keeps a second entry from paying again (a track put back by hand)
	local p, d = arriveAt2("again", 0, 0, 50)
	local gold = #w.GoldGiven
	d.CarriedGold = 0
	d.Story.Subs.KO1.St = 1
	w.Story.Event(p, "FirstKO")
	check(d.Story.Subs.KO1.St == 2 and #w.GoldGiven == gold and d.CarriedGold == 0, "the top-up is paid once per step, never twice", show({ d.CarriedGold, #w.GoldGiven - gold }))
	-- a step that passes at once (the potion was bought earlier) gets no top-up
	uid += 1
	local q, qd = joinKO(w, uid, "Horns")
	local g0 = #w.GoldGiven
	check(w.Story.Event(q, "PotionBought") == false, "a purchase before the KO moves nothing yet", show(qd.Story.Subs.KO1))
	w.Story.Event(q, "FirstKO")
	check(qd.Story.Subs.KO1.St == 3 and #w.GoldGiven == g0 and (qd.CarriedGold or 0) == 0, "step 2 passes at once (bought earlier), no top-up", show({ qd.Story.Subs.KO1, #w.GoldGiven - g0 }))
end)

------------------------------------------------------------------ 5. running ahead is never a dead end
runGroup("ahead", function()
	local w = koWorld()
	local uid = 1400
	local function start(faction, slots)
		uid += 1
		local p, d = joinKO(w, uid, faction or "Halo", { Data = slots ~= nil and { QuickSlots = slots } or nil })
		return p, d, w:Track(d, "KO1")
	end
	-- a KO from before the quest started is not step 1 (the step is the quest's own KO)
	uid += 1
	local old, oldD = joinKO(w, uid, "Halo", { First = { Migrated = true, FirstKO = true } })
	check(w:Track(oldD, "KO1") ~= nil and w:Track(oldD, "KO1").St == 1 and w.Story.Wants(old, "FirstKO") == true,
		"an old KO does not pass step 1: the quest waits for its own KO", show(w:Track(oldD, "KO1")))
	-- bought, put in a slot and drunk before the KO: the KO opens the rematch straight away
	local p, d, tr = start("Halo", ",,")
	w.Story.Event(p, "PotionBought")
	w.Story.Event(p, "QuickSlotSet", { Slot = 2, Kind = "MP" })
	w.Story.Event(p, "PotionUsed")
	check(tr.St == 1 and d.Story.First.PotionBought == true and d.Story.First.QuickSlotSet == true and d.Story.First.PotionUsed == true,
		"events seen early are remembered, the open step does not move", show(tr))
	w.Story.Event(p, "FirstKO")
	check(tr.St == 5 and w.Story.Wants(p, "PotionUsed") == false and p:GetAttribute("PotionSip") == false,
		"the KO then passes steps 2, 3 and 4 at once (step 5 waits for the rematch; the sip flag never lit)", show(tr))
	-- drunk before bought
	p, d, tr = start("Horns", ",,")
	w.Story.Event(p, "PotionUsed")
	w.Story.Event(p, "FirstKO")
	check(tr.St == 2, "a drink before the KO does not skip the purchase", show(tr))
	w.Story.Event(p, "PotionBought")
	check(tr.St == 3 and w.Story.Wants(p, "QuickSlotSet") == true, "the purchase does not skip the slot step", show(tr))
	w.Story.Event(p, "QuickSlotSet", { Slot = 1, Kind = "HP" })
	check(tr.St == 5, "the slot passes the drink step at once (already seen)", show(tr))
	-- a potion put in a slot before it was bought
	p, d, tr = start("Neutral", ",,")
	w.Story.Event(p, "QuickSlotSet", { Slot = 3, Kind = "HP" })
	w.Story.Event(p, "FirstKO")
	w.Story.Event(p, "PotionBought")
	check(tr.St == 4 and w.Story.Wants(p, "PotionUsed") == true and p:GetAttribute("PotionSip") == true,
		"a slot filled early passes the slot step; the drink step is next (sip flag lit)", show(tr))
	-- an old save: its HP / MP are already in the slots (the field holds a potion): the slot step passes at once
	p, d, tr = start("Halo", "HP,MP,")
	w.Story.Event(p, "FirstKO")
	check(tr.St == 2, "an old save at step 2 waits for the purchase", show(tr))
	w.Story.Event(p, "PotionBought")
	check(tr.St == 4 and w.Story.Wants(p, "QuickSlotSet") == false and w.Story.Wants(p, "PotionUsed") == true,
		"an old save's filled slots pass step 3 at once (no 'put it' to do)", show(tr))
	-- what counts as a filled slot: any letter in the saved text; empty / missing / not text never
	for _, case in { { ",MP,", true }, { ",,HP", true }, { "HP,,", true }, { ",,", false }, { "", false }, { ", ,", false } } do
		p, d, tr = start("Halo", case[1])
		w.Story.Event(p, "FirstKO")
		w.Story.Event(p, "PotionBought")
		check((tr.St == 4) == case[2] and (tr.St == 3) == (not case[2]), "slots text '" .. case[1] .. "' " .. (case[2] and "is filled: step 3 passes" or "is empty: step 3 waits"), show(tr))
	end
	p, d, tr = start("Halo")
	d.QuickSlots = nil
	w.Story.Event(p, "FirstKO")
	w.Story.Event(p, "PotionBought")
	check(tr.St == 3, "no saved slots field at all: step 3 waits (nothing is held)", show(tr))
	p, d, tr = start("Halo")
	d.QuickSlots = 5
	w.Story.Event(p, "FirstKO")
	w.Story.Event(p, "PotionBought")
	check(tr.St == 3, "a slots field that is not text: step 3 waits", show(tr))
	-- a step waits only for its own name
	p, d, tr = start("Neutral", ",,")
	w.Story.Event(p, "FirstKO")
	w.Story.Event(p, "PotionBought")
	check(tr.St == 3, "buying moves on to the slot step", show(tr))
	check(w.Story.Event(p, "PotionBought") == false and tr.St == 3, "a second purchase moves nothing", show(tr))
	-- two players never share a quest
	local a, ad, atr = start()
	local b, bd, btr = start()
	w.Story.Event(a, "FirstKO")
	check(atr.St == 2 and btr.St == 1 and bd.Story.First.FirstKO == nil, "an event is one player's own", show({ atr.St, btr.St }))
	-- a player not ready / without data: nothing
	local c = w:NewPlayer(1499, {})
	check(w.Story.Event(c, "FirstKO") == false and w.Story.Wants(c, "FirstKO") == false and w.Story.CurrentStep(c, "KO1") == nil, "no data: nothing", "")
	w.Ready[a] = false
	check(w.Story.Event(a, "PotionBought") == false and atr.St == 2 and ad.Story.First.PotionBought == nil, "a player who is not ready is ignored", show(atr))
	w.Ready[a] = true
	-- a finished or unknown quest has no step; a bad id / player is nil
	check(w.Story.CurrentStep(a, "Nope") == nil and w.Story.CurrentStep(a, nil) == nil and w.Story.CurrentStep("a", "KO1") == nil, "CurrentStep: bad arguments give nil", "")
	-- [Claim] state: a quest waiting for the claim is not 'at a step'
	atr.Claim = true
	check(w.Story.CurrentStep(a, "KO1") == nil and w.Story.Wants(a, "PotionBought") == false, "a quest waiting for [Claim] is at no step", "")
	atr.Claim = false
end)

------------------------------------------------------------------ 6. personal kills (the rematch must stay the player's own)
runGroup("personal", function()
	local w = koWorld()
	local p = joinKO(w, 1500, "Halo")
	local kill = { Type = "Kill", Kind = "SlimeKing" }
	local mine = { Type = "Kill", Kind = "SlimeKing", Personal = true }
	local function amount(obj, personal)
		return w.Story.EventAmount(p, obj, { Kind = "Kill", Info = { Kind = "SlimeKing", ZoneId = "SlimeMeadow", Personal = personal, Golden = false } })
	end
	check(amount(kill, false) == 1 and amount(kill, true) == 0, "a normal kill step counts shared kills only (as before)", show({ amount(kill, false), amount(kill, true) }))
	check(amount(mine, true) == 1 and amount(mine, false) == 0, "a Personal step counts personal kills only", show({ amount(mine, true), amount(mine, false) }))
	check(w.Story.EventAmount(p, { Type = "WarPoints", Personal = nil }, { Kind = "Kill", Info = { Kind = "Slime", Personal = true, WarPoints = 5 } }) == 0,
		"war points never come from a personal monster", "")
	-- the existing quests are not changed by it: M1_2 (Slime Princes) ignores a personal BigSlime
	local q, qd = w:Join(1501, { Faction = "Halo", Level = 3, Data = { Story = { Main = { Id = "" }, Subs = {}, Done = { M1_1 = true }, Pick = {}, First = { Migrated = true } } } })
	w.Story.Refresh(q)
	local m = qd.Story.Main
	check(m.Id == "M1_2" and m.St == 1, "M1_2 is the main quest", show(m))
	w:Kill(q, "BigSlime", { Personal = true })
	check(m.P == 0, "a personal Slime Prince does not count for M1_2", show(m))
	w:Kill(q, "BigSlime", { Personal = false })
	check(m.P == 1, "a shared one does", show(m))
end)

------------------------------------------------------------------ 7. Studio test aids (Main's DebugCommand StorySub / StoryDone)
runGroup("debug aids", function()
	local w = koWorld()
	local panels = panelsOf(w)
	local done = {}
	w.Story.QuestDone:Connect(function(_, id) table.insert(done, id) end)
	-- Lv9: KO1 is never offered by itself, the aid starts it anyway at the step asked for
	local p, d = joinKO(w, 1601, "Halo", { Level = 9, Data = { QuickSlots = ",," } })
	check(w:Track(d, "KO1") == nil, "Lv9: KO1 is not offered by itself", "")
	local n0 = #w.Notices
	check(w.Story.DebugSub(p, "KO1", 3) == "ok" and w:Track(d, "KO1") ~= nil and w:Track(d, "KO1").St == 3 and w.Story.Wants(p, "QuickSlotSet") == true,
		"DebugSub KO1 step 3: the quest starts at 'Put the potion in a quick slot'", show(w:Track(d, "KO1")))
	check(#w.Notices == n0 and #panels == 0 and #done == 0 and #w.XP == 0 and #w.Granted == 0, "... no notice, no popup, no QuestDone, no reward", "")
	check(w.Story.DebugSub(p, "KO1", 4) == "ok" and w:Track(d, "KO1").St == 4 and p:GetAttribute("PotionSip") == true,
		"DebugSub again: moves it to step 4 (the sip flag lit)", show(w:Track(d, "KO1")))
	-- step 2 comes with its gold like a real arrival
	local q, qd = joinKO(w, 1602, "Horns", { Level = 9 })
	check(w.Story.DebugSub(q, "KO1", 2) == "ok" and qd.CarriedGold == 50 and qd.Story.First.TopKO12 == true, "DebugSub KO1 step 2: the 50 gold top-up like a real step 2", show({ qd.CarriedGold, qd.Story.First }))
	check(w.Story.DebugSub(q, "KO1", 2) == "ok" and qd.CarriedGold == 50, "... once", show(qd.CarriedGold))
	-- a bare quest id = step 1; a fraction rounds down; a bad step / quest is refused and changes nothing
	local r, rd = joinKO(w, 1603, "Neutral", { Level = 9 })
	check(w.Story.DebugSub(r, "KO1") == "ok" and w:Track(rd, "KO1").St == 1, "no step given: step 1", show(w:Track(rd, "KO1")))
	check(w.Story.DebugSub(r, "KO1", 2.7) == "ok" and w:Track(rd, "KO1").St == 2, "2.7 -> step 2", show(w:Track(rd, "KO1")))
	for _, bad in { 0, -1, 6, 99 } do
		check(string.find(w.Story.DebugSub(r, "KO1", bad), "steps 1-5", 1, true) ~= nil and w:Track(rd, "KO1").St == 2, "step " .. tostring(bad) .. " is refused (steps 1-5)", show(w:Track(rd, "KO1")))
	end
	check(string.find(w.Story.DebugSub(r, "Nope", 1), "no such sub quest", 1, true) ~= nil and string.find(w.Story.DebugSub(r, "M1_2", 1), "no such sub quest", 1, true) ~= nil
		and w:Track(rd, "M1_2") == nil and rd.Story.Subs.M1_2 == nil, "an unknown id / a main quest is not a sub quest", "")
	check(w.Story.DebugSub(w:NewPlayer(1699, {}), "KO1", 1) == "no data", "no save: refused", "")
	-- a finished quest can be started again
	rd.Story.Done.KO1 = true
	rd.Story.Subs.KO1 = nil
	check(w.Story.DebugSub(r, "KO1", 1) == "ok" and rd.Story.Done.KO1 == nil and w:Track(rd, "KO1").St == 1, "a done quest starts again (its Done mark is cleared)", show(rd.Story.Done))
	-- StoryDone: no reward, no QuestDone, never restarts by itself
	local gold0 = #w.GoldGiven
	check(w.Story.DebugDone(r, "KO1") == "ok" and rd.Story.Done.KO1 == true and w:Track(rd, "KO1") == nil, "DebugDone: marked done, the track is gone", show({ rd.Story.Done, w:Track(rd, "KO1") }))
	w.Story.Refresh(r)
	check(w:Track(rd, "KO1") == nil and #done == 0 and #w.XP == 0 and #w.Granted == 0 and #w.GoldGiven == gold0, "... never restarted, no QuestDone, no reward", "")
	-- a main quest done: the main slot is free
	local m, md = joinKO(w, 1604, "Halo", { Level = 3, Done = { M1_1 = true } })
	check(md.Story.Main.Id == "M1_2", "M1_2 is the active main quest", show(md.Story.Main))
	check(w.Story.DebugDone(m, "M1_2") == "ok" and md.Story.Done.M1_2 == true and md.Story.Main.Id ~= "M1_2", "DebugDone on the active main quest: done, the slot is free", show(md.Story.Main))
	check(string.find(w.Story.DebugDone(m, "Nope"), "no such quest", 1, true) ~= nil and w.Story.DebugDone(w:NewPlayer(1698, {}), "KO1") == "no data", "unknown quest / no save: refused", "")
end)

------------------------------------------------------------------ 8. a brand-new Studio save, start to finish (검수 10/10 main apply: the slot step went by at once)
runGroup("a brand-new Studio save keeps the slot step", function()
	local rec = memoryRecord(1701)
	check(type(rec) == "table" and rec.QuickSlots == ",,", "DataService's memory-mode record starts with empty quick slots", show(rec and rec.QuickSlots))
	local w = koWorld({ Quick = true })
	local function player(uid, saved)
		local d = saved
		d.Class, d.Faction, d.ClassChosen, d.Level, d.TutorialStep = "Warrior", "Halo", true, 4, 99
		d.Story = { Main = { Id = "" }, Subs = {}, Done = { M1_1 = true, M1_2 = true }, Pick = {}, First = { Migrated = true } }
		local p = w:Join(uid, { Saved = d })
		w.Story.Refresh(p)
		w:Flush()
		return p, d
	end
	-- the real chain: record -> QuickSlotService at PlayerReady -> the story service
	local p, d = player(1701, rec)
	check(d.QuickSlots == ",," and p:GetAttribute("QuickSlots") == ",,", "ready: still three empty slots (no HP / MP given)", show({ d.QuickSlots, p:GetAttribute("QuickSlots") }))
	local tr = w:Track(d, "KO1")
	check(tr ~= nil and tr.St == 1, "the new player (M1_2 done, Lv4, no potions) gets KO1", show(tr))
	w.Story.Event(p, "FirstKO")
	check(tr.St == 2 and d.CarriedGold == 50, "the King's KO: 'Buy a potion' with its 50 gold", show({ tr.St, d.CarriedGold }))
	w.Story.Event(p, "PotionBought", { Kind = "HP", N = 1 })
	check(tr.St == 3 and w.Story.Wants(p, "QuickSlotSet") == true and p:GetAttribute("QuickSlots") == ",,",
		"after the purchase the new player STAYS at 'Put the potion in a quick slot' (slots still empty)", show({ tr.St, p:GetAttribute("QuickSlots") }))
	for _ = 1, 3 do w.Story.Refresh(p) end
	check(tr.St == 3, "... and the 1 s loop does not pass it either", show(tr))
	-- putting the potion in a slot goes through the real QuickSlotService -> Event QuickSlotSet -> step 4
	w:Advance(1)
	w.Remotes.SetQuickSlot.OnServerEvent:Fire(p, 1, "HP")
	check(p:GetAttribute("QuickSlots") == "HP,," and tr.St == 4 and w.Story.Wants(p, "PotionUsed") == true,
		"the slot press (SetQuickSlot 1 'HP') -> QuickSlotSet -> 'Drink it from your quick slot'", show({ p:GetAttribute("QuickSlots"), tr.St }))
	-- the other way round (the rule the old saves live by): a save from before the slots has no field -> HP, MP, step 3 passes
	local old = memoryRecord(1702)
	old.QuickSlots = nil
	local q, qd = player(1702, old)
	w.Story.Event(q, "FirstKO")
	w.Story.Event(q, "PotionBought")
	check(qd.QuickSlots == "HP,MP," and w:Track(qd, "KO1").St == 4, "a save from before the slots (no field) is given HP, MP: nothing to put, step 3 passes", show({ qd.QuickSlots, w:Track(qd, "KO1").St }))
end)

finish()
