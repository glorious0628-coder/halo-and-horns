-- first_ko_offline.luau : A23-109 / A23-110 the King's Hop, the MAIN quest M1_2 since A23-222 (user 10/16: "킹 슬라임한테 한 방에
-- 죽고나서 물약 사기 퀘스트 나오고 물약 사면 킹 슬라임 잡을 수 있도록"): right after the Slime Prince (M1_1) the player meets the King
-- Slime on its hill (a lossless KO that game dev 2's personal King reports with StoryQuestService.Event "FirstKO"), buys a potion,
-- puts it in a quick slot, drinks it, uses the Prince's Enhance Scroll at Otto's anvil (A23-221 ②) and wins the rematch.
-- tools/test_first_ko.py binds the dev2_combat_world sources (the real StoryQuestService and LootService); the potion shop /
-- drink hooks are checked in tools/fixtures/potions_offline.luau.
-- The old sub KO1 is gone (a save on it: Story.Schema 6). The engine's sub rules it used (Requires MaxLevel / NoPotionYet /
-- KingOn, a step's TopUpGold, the Studio aid DebugSub) stay in StoryQuestService with no def shipping them: they are checked
-- here on a test-only sub "KOT" (the old KO1 shape), installed in the worlds that need it.

local SQ0 = C0.StoryQuests
local KO = SQ0.Defs.M1_2
local ID = "M1_2"

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
	-- the story NPC bodies (w.Bodies: tagged parts with NpcId; none = every NPC talk passes, like a world without bodies)
	w.Bodies = {}
	w.Services.CollectionService = { GetTagged = function(_, tag)
		if tag == w.Config.StoryQuests.NpcTag then return w.Bodies end
		return {}
	end }
	-- the test-only sub KOT (the old KO1 shape) for the engine rules no shipped def uses any more
	if o.TestSub then
		local def = deepCopy(w.Config.StoryQuests.Defs.M1_2)
		def.Kind, def.Chapter, def.Next, def.Type, def.Speaker = "Sub", nil, nil, nil, nil
		def.Requires = { Done = { "M1_2" }, MaxLevel = 8, NoPotionYet = true, KingOn = true }
		def.Steps[2].TopUpGold = 50
		w.Config.StoryQuests.Defs.KOT = def
		table.insert(w.Config.StoryQuests.Subs, "KOT")
	end
	w.Story.Start()
	-- every GrantItem the story service asks for (the scroll of the quest's reward, the anvil's scroll); loot drops of the
	-- kills go another way
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
	-- the track of quest id: the main track while it is the main quest, else the sub's
	function w:Track(d, id)
		local st = d.Story
		if not st then return nil end
		if st.Main and st.Main.Id == id then return st.Main end
		return st.Subs and st.Subs[id]
	end
	function w:NpcBody(id, pos)
		local part = newInstance("Part", self)
		part.Name, part.Position = "Npc" .. id, pos
		part.Attrs.NpcId = id
		table.insert(self.Bodies, part)
		return part
	end
	return w
end

-- a ready player who finished M1_1 (the Slime Prince), with no potions, at `o.Level`; a save of today (Story.Schema 6) unless
-- o.Schema says otherwise (o.Schema = false: no Schema field, an old save)
local function joinKO(w, userId, faction, o)
	o = o or {}
	local story = { Main = o.Main or { Id = "" }, Subs = o.Subs or {}, Done = o.Done or { M1_1 = true }, Pick = {},
		First = o.First or { Migrated = true } }
	if o.Schema ~= false then story.Schema = o.Schema or 6 end
	local data = { Story = story }
	for k, v in o.Data or {} do data[k] = v end
	local p, d = w:Join(userId, { Faction = faction, Class = "Warrior", Level = o.Level or 4, Carried = o.Carried, Bank = o.Bank, Data = data,
		Tier = o.Tier, Mask = o.Mask })
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end

-- the quest list row of quest id (the main row, else a sub row)
local function rowOf(w, p, d, id)
	local main = w.Story.MainRow(p, d)
	if main and main.Story and main.Story.Id == id then return main end
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

local function rootOf(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end

-- the four happenings that bring a fresh M1_2 track from row 1 to the anvil row (5)
local function toAnvil(w, p)
	w.Story.Event(p, "FirstKO")
	w.Story.Event(p, "PotionBought", { Kind = "HP", N = 1 })
	w.Story.Event(p, "QuickSlotSet", { Slot = 1, Kind = "HP" })
	w.Story.Event(p, "PotionUsed", { Kind = "HP" })
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
	check(KO ~= nil and KO.Kind == "Main" and KO.Chapter == 1 and KO.Title == "The King's Hop" and #KO.Steps == 6 and KO.Hidden == nil
		and KO.Requires == nil, "M1_2: the main 'The King's Hop' with six steps and no gate (no Lv / potion / King-on keep)",
		show(KO and { KO.Kind, #KO.Steps, KO.Requires }))
	local main = SQ0.Main
	local i1, i2, i3 = table.find(main, "M1_1"), table.find(main, "M1_2"), table.find(main, "M1_3")
	check(i1 ~= nil and i2 == i1 + 1 and i3 == i2 + 1, "the main chain: M1_1 -> M1_2 -> M1_3", show(main))
	local inSubs = false
	for _, id in SQ0.Subs do if id == "KO1" or id == "M1_2" then inSubs = true end end
	check(SQ0.Defs.KO1 == nil and not inSubs, "the old sub KO1 is gone (and M1_2 is no sub)", "")
	local M11 = SQ0.Defs.M1_1
	local nextOk = true
	for _, side in { "Halo", "Horns", "Neutral" } do
		if not (M11.Next[side] and M11.Next[side].Id == ID and M11.Next[side].Line == "His big dad is up on the hill!") then nextOk = false end
	end
	check(#M11.Steps == 1 and nextOk, "M1_1 is the Prince only and leads to M1_2 ('His big dad is up on the hill!')", show(M11.Next))
	check(KO.Next and KO.Next.Halo.Id == "H_Band" and KO.Next.Horns.Id == "R_Band" and KO.Next.Neutral.Id == "M1_3",
		"M1_2 leads on where M1_1 used to (H_Band / R_Band / M1_3)", show(KO.Next))
	local s = KO.Steps
	check(s[1].Text == "Defeat the King Slime" and s[1].Obj.Type == "Event" and s[1].Obj.Name == "FirstKO" and s[1].Obj.Past == nil
		and s[1].Guide == "KingHill", "step 1: Defeat the King Slime = the FirstKO happening (never skipped by an old one), guides to the King's hill",
		show(s[1]))
	check(s[2].Text == "Buy a potion" and s[2].Obj.Type == "Event" and s[2].Obj.Name == "PotionBought" and s[2].Obj.Past == true
		and s[2].TopUpGold == nil and s[2].Guide == "PotionShop",
		"step 2: Buy a potion = PotionBought (passes when seen before), no gold top-up (the first 1000 gold pays it), guides to the seller",
		show(s[2]))
	check(s[3].Text == "Put the potion in a quick slot" and s[3].Obj.Type == "Event" and s[3].Obj.Name == "QuickSlotSet" and s[3].Obj.Past == true
		and s[3].Obj.Held == "QuickSlots" and s[3].TopUpGold == nil and s[3].Guide == "QuickSlot",
		"step 3: Put the potion in a quick slot = QuickSlotSet (passes when seen before or a slot is already filled), guides to the bag's slots (QuickSlot)", show(s[3]))
	check(s[4].Text == "Drink it from your quick slot" and s[4].Obj.Type == "Event" and s[4].Obj.Name == "PotionUsed" and s[4].Obj.Past == true
		and s[4].TopUpGold == nil and s[4].Guide == "QuickSlot", "step 4: Drink it from your quick slot = PotionUsed (passes when seen before)", show(s[4]))
	check(s[5].Text == "Use the Enhance Scroll at Otto's anvil" and s[5].Obj.Type == "Event" and s[5].Obj.Name == "ScrollUsed"
		and s[5].Obj.Past == true and s[5].Anvil == true and s[5].Npc == "Otto" and s[5].Guide == "Blacksmith"
		and s[5].Find == "Two knots... two colors?" and type(s[5].Lines) == "table" and s[5].Lines.Halo ~= nil,
		"step 5 (A23-221 ②): the scroll at Otto's anvil = ScrollUsed (Past: a bag use first counts), the band's Find / Lines moved here",
		show(s[5]))
	check(s[6].Text == "Defeat the King Slime" and s[6].Obj.Type == "Kill" and s[6].Obj.Kind == "SlimeKing" and s[6].Obj.Personal == true
		and s[6].Obj.Count == 1 and s[6].Obj.Zone == "SlimeMeadow" and s[6].Guide == "KingHill",
		"step 6: the rematch = one personal King Slime kill in the meadow, guided to the King's hill (A23-227)", show(s[6]))
	check(KO.Reward.Gold == 2 and KO.Reward.XP == 2 and KO.Reward.Item == "Enh70" and KO.Reward.N == 1 and KO.Finish == nil
		and KO.Start == nil and KO.Pop == nil and KO.Claim == nil, "two minutes of hunting + one 70% scroll; no Start / Finish / Pop / Claim (A23-99: no popups, no toasts)", show(KO.Reward))
	for i, step in s do
		check(type(step.ShortName) == "string" and #step.ShortName <= 14 and step.Start == nil and step.Panel == nil,
			"step " .. i .. ": a phone short name (<= 14), no Start line, no panel", tostring(step.ShortName))
	end
	check(#KO.ShortName <= 14, "M1_2 has a short name for the phone row", tostring(KO.ShortName))
	local events = SQ0.Events
	check(events and events.FirstKO == true and events.PotionBought == true and events.QuickSlotSet == true and events.PotionUsed == true
		and events.ScrollUsed == true, "the happenings are listed in Config.StoryQuests.Events", show(events))
	for _, step in s do
		if step.Obj.Type == "Event" then
			check(events[step.Obj.Name] == true, "every Event step waits for a listed happening: " .. step.Obj.Name, "")
		end
	end
	local f = C0.FirstKO
	check(f and f.Quest == ID and f.Step == 1 and f.RematchStep == 6 and s[f.RematchStep].Obj.Type == "Kill" and s[f.Step].Obj.Name == "FirstKO",
		"Config.FirstKO tells game dev 2 the quest (M1_2), the KO step (1) and the rematch step (6)", show(f))
	check(f and f.SipAttr == "PotionSip", "Config.FirstKO.SipAttr = the attribute game dev 1's VitalsUI reads (PotionSip)", show(f))
	local hill = SQ0.Landmarks.KingHill
	check(hill ~= nil and hill.X == 400 and hill.Z == -118 and SQ0.Landmarks.MeadowArrival ~= nil,
		"the King's hill row's spot (Landmarks.KingHill) and the meadow's arrival spot exist", show({ hill, SQ0.Landmarks.MeadowArrival }))
	local A = C0.Analytics
	local fs = A.Funnels.FirstKO.Steps
	check(#fs == 6 and fs[1] == "KO" and fs[5] == "Enhanced" and fs[6] == "KingWon" and A.QuestFunnels.M1_2 == "FirstKO" and A.QuestFunnels.KO1 == nil,
		"the FirstKO funnel has the quest's six steps ('Enhanced' before 'KingWon'), fed by M1_2", show({ fs, A.QuestFunnels }))
	check(C0.PotionStockKey("HP") == "HPPotionCount" and C0.Text.PotionPractice ~= nil, "the potion stock keys and the practice-sip line exist", "")
	local Q = C0.QuickSlots
	check(Q and Q.Attr == "QuickSlots" and Q.Default[1] == "" and Q.Default[2] == "" and Q.Default[3] == "", "a new player's quick slots start empty (the Held field is data.QuickSlots)", show(Q and Q.Default))
end)

------------------------------------------------------------------ 2. who gets it, and quietly
runGroup("offered", function()
	local w = koWorld()
	local panels = panelsOf(w)
	local uid = 1100
	for _, faction in { "Halo", "Horns", "Neutral" } do
		uid += 1
		local before, n0 = #panels, #w.Notices
		local p, d = joinKO(w, uid, faction)
		local tr = w:Track(d, ID)
		local row = rowOf(w, p, d, ID)
		check(d.Story.Main.Id == ID and tr ~= nil and tr.St == 1 and #panels == before and noticeAbout(w, p, n0, { "king", "potion", "hop" }) == nil,
			faction .. ": after M1_1 the King's Hop is the main quest, just a row: no popup, no toast", show({ d.Story.Main, #panels - before, noticeAbout(w, p, n0, { "king", "potion", "hop" }) }))
		check(row ~= nil and row.Text == "Defeat the King Slime" and row.ShortName == "Defeat King" and row.Story.Guide == "KingHill"
			and row.Story.Panel == nil and row.CanClaim == false, faction .. ": row 1 reads 'Defeat the King Slime', guides to the King's hill", show(row))
		check(w.Story.CurrentStep(p, ID) == 1 and w.Story.Wants(p, "FirstKO") == true and w.Story.Wants(p, "PotionBought") == false,
			faction .. ": CurrentStep 1; the quest waits for FirstKO only", show({ w.Story.CurrentStep(p, ID), w.Story.Wants(p, "FirstKO") }))
	end
	-- no keeps any more: every save past M1_1 gets it (a step already done passes at once)
	local function offered(name, o, expect)
		uid += 1
		local _, d = joinKO(w, uid, "Halo", o)
		check((w:Track(d, ID) ~= nil) == expect, name .. (expect and ": M1_2 runs" or ": no M1_2"), show({ d.Story.Main, d.Story.Done }))
		return d
	end
	offered("Lv8", { Level = 8 }, true)
	offered("Lv9 (the old cap was 8)", { Level = 9 }, true)
	offered("Lv20", { Level = 20 }, true)
	offered("an HP potion in the bag", { Data = { HPPotionCount = 1 } }, true)
	offered("an MP potion in the bag", { Data = { MPPotionCount = 2 } }, true)
	offered("a potion bought once (and used)", { First = { Migrated = true, PotionBought = true, PotionUsed = true } }, true)
	offered("before M1_1", { Done = {} }, false)
	offered("already done", { Done = { M1_1 = true, M1_2 = true } }, false)
	-- the King off: still the main (no KingOn keep: the KO row is told, the rematch row passes by itself)
	w.Config.FirstKOKing = { Enabled = false }
	offered("the personal King switched off", {}, true)
	w.Config.FirstKOKing = nil
	-- the quest does not start twice and nothing restarts it
	uid += 1
	local p, d = joinKO(w, uid, "Halo")
	d.Story.Main.St = 3
	for _ = 1, 3 do w.Story.Refresh(p) end
	check(d.Story.Main.Id == ID and d.Story.Main.St == 3, "a started quest is never restarted by the 1 s loop", show(d.Story.Main))
	d.HPPotionCount = 3
	w.Story.Refresh(p)
	check(d.Story.Main.Id == ID and d.Story.Main.St == 3, "buying potions after the start never cancels the quest", show(d.Story.Main))
end)

------------------------------------------------------------------ 2b. Story.Schema 6 (A23-222): the old saves
runGroup("schema 6", function()
	local w = koWorld()
	local uid = 1150
	local function old(o)
		uid += 1
		if o.Schema == nil then o.Schema = false end
		return joinKO(w, uid, o.Faction or "Halo", o)
	end
	-- a save past M1_1 (before A23-222) skips the King's Hop
	local _, d1 = old({ Done = { M1_1 = true } })
	check(d1.Story.Done.M1_2 == true and d1.Story.Main.Id ~= ID and d1.Story.Schema == 6,
		"an old save with M1_1 done: M1_2 marked done (skipped), Schema 6", show({ d1.Story.Done, d1.Story.Main, d1.Story.Schema }))
	local _, d1b = old({ Done = { M1_1 = true }, Schema = 5 })
	check(d1b.Story.Done.M1_2 == true and d1b.Story.Schema == 6, "a Schema 5 save with M1_1 done: M1_2 skipped too", show(d1b.Story.Done))
	-- a save that finished the old sub KO1 (it is the same quest)
	local _, d2 = old({ Done = { M1_1 = true, KO1 = true } })
	check(d2.Story.Done.M1_2 == true and d2.Story.Done.KO1 == nil, "an old save with KO1 done: M1_2 done, the KO1 mark dropped", show(d2.Story.Done))
	local _, d2b = old({ Done = { KO1 = true } })
	check(d2b.Story.Done.M1_2 == true, "an old save with only KO1 marked done: M1_2 done too (the same quest)", show(d2b.Story.Done))
	-- a save on M1_1's old step 2 (the scroll from the bag): the Prince is beaten: M1_1 done, M1_2 starts at row 1
	local p3, d3 = old({ Done = {}, Main = { Id = "M1_1", St = 2, P = 0, T = {}, Claim = false } })
	check(d3.Story.Done.M1_1 == true and d3.Story.Done.M1_2 == nil and d3.Story.Main.Id == ID and d3.Story.Main.St == 1
		and w.Story.CurrentStep(p3, ID) == 1,
		"an old save on M1_1's scroll step: M1_1 done, M1_2 starts at row 1 on the refresh", show({ d3.Story.Done, d3.Story.Main }))
	-- the old subs leave: KO1 (any step), the lessons H_Basics / R_Basics
	local _, d4 = old({ Done = {}, Main = { Id = "M1_1", St = 1, P = 0, T = {}, Claim = false },
		Subs = { KO1 = { St = 3, P = 0, T = {}, Claim = false }, H_Basics = { St = 1, P = 0, T = {}, Claim = false },
			R_Basics = { St = 2, P = 0, T = {}, Claim = false } } })
	check(d4.Story.Subs.KO1 == nil and d4.Story.Subs.H_Basics == nil and d4.Story.Subs.R_Basics == nil and d4.Story.Done.M1_2 == nil,
		"an old save's KO1 / H_Basics / R_Basics tracks are dropped (not done)", show({ d4.Story.Subs, d4.Story.Done }))
	-- unaffected: a save on M1_1's step 1, a brand-new save (no story), a Schema 6 save
	check(d4.Story.Main.Id == "M1_1" and d4.Story.Main.St == 1 and d4.Story.Done.M1_1 == nil,
		"an old save still on the Prince (M1_1 step 1) keeps it", show(d4.Story.Main))
	uid += 1
	local p5, d5 = w:Join(uid, { Faction = "Horns", Level = 2 })
	w.Story.Refresh(p5)
	check(d5.Story and d5.Story.Schema == 6 and d5.Story.Main.Id == "M1_1" and d5.Story.Main.St == 1 and d5.Story.Done.M1_2 == nil,
		"a brand-new save: Schema 6, M1_1 at row 1, nothing marked done", show(d5.Story and { d5.Story.Main, d5.Story.Done, d5.Story.Schema }))
	uid += 1
	local p6, d6 = joinKO(w, uid, "Halo")
	check(d6.Story.Done.M1_2 == nil and d6.Story.Main.Id == ID and w.Story.CurrentStep(p6, ID) == 1,
		"a Schema 6 save past M1_1 is not touched: M1_2 runs", show({ d6.Story.Done, d6.Story.Main }))
	-- a migrated save stays migrated (a second join changes nothing)
	d3.Story.Main.St = 4
	w.PS.PlayerReady:Fire(p3, d3)
	w:Flush()
	check(d3.Story.Main.Id == ID and d3.Story.Main.St == 4 and d3.Story.Done.M1_2 == nil, "a second join: no second migration", show(d3.Story.Main))
end)

------------------------------------------------------------------ 3. the six steps, in order
runGroup("flow", function()
	local w = koWorld()
	local panels = panelsOf(w)
	local done = {}
	w.Story.QuestDone:Connect(function(_, id) table.insert(done, id) end)
	-- A23-113 #2: the funnel's steps come from StepDone, one per quest step, in order, before the next opens
	local stepLog = {}
	w.Story.StepDone:Connect(function(_, id, step) if id == ID then table.insert(stepLog, step) end end)
	local uid = 1200
	for _, faction in { "Halo", "Horns", "Neutral" } do
		uid += 1
		local p, d = joinKO(w, uid, faction, { Data = { QuickSlots = ",," } })
		local tr = w:Track(d, ID)
		local n0, panels0, gold0 = #w.Notices, #panels, #w.GoldGiven
		-- nothing a stranger says moves it
		check(w.Story.Event(p, "Nope") == false and w.Story.Event(p, nil) == false and w.Story.Event(p, 5) == false and w.Story.Event(nil, "FirstKO") == false
			and w.Story.Event("Halo", "FirstKO") == false and w.Story.Event({}, "FirstKO") == false and tr.St == 1 and d.Story.First.Nope == nil,
			faction .. ": unknown names / non-players do nothing", show(tr))
		w:Act(p, ID, "Talk")
		w:Act(p, ID, "Open")
		w:Act(p, ID, "Choose", "Good")
		check(tr.St == 1 and #panels == panels0, faction .. ": the client cannot move the quest (no Talk / Choose / Open on an Event step)", show(tr))
		-- 1. the KO
		check(w.Story.Event(p, "FirstKO", { Test = true }) == true and tr.St == 2 and d.Story.First.FirstKO == true
			and w.Story.CurrentStep(p, ID) == 2, faction .. ": FirstKO moves step 1 to 2 and is remembered", show({ tr, d.Story.First }))
		check(#w.GoldGiven == gold0 and (d.CarriedGold or 0) == 0 and d.Story.First.TopM1_22 == nil,
			faction .. ": no gold top-up at the shop row (A23-222: the first 1000 gold pays the potion)", show({ w.GoldGiven, d.CarriedGold }))
		local row = rowOf(w, p, d, ID)
		check(row.Text == "Buy a potion" and row.ShortName == "Buy a potion" and row.Story.Guide == "PotionShop" and row.Story.St == 2,
			faction .. ": row 2 reads 'Buy a potion' and guides to the seller", show(row))
		check(w.Story.Wants(p, "PotionBought") == true and w.Story.Wants(p, "FirstKO") == false and w.Story.Wants(p, "PotionUsed") == false
			and w.Story.Wants(p, "QuickSlotSet") == false, faction .. ": step 2 waits for PotionBought only", "")
		check(p:GetAttribute("PotionSip") == false, faction .. ": steps 1-2: the client may not use a full bar yet (PotionSip false)", tostring(p:GetAttribute("PotionSip")))
		check(w.Story.Event(p, "FirstKO") == false and tr.St == 2, faction .. ": a second KO moves nothing", show(tr))
		-- 2. the purchase
		check(w.Story.Event(p, "PotionBought", { Kind = "HP", N = 1 }) == true and tr.St == 3, faction .. ": PotionBought moves step 2 to 3", show(tr))
		row = rowOf(w, p, d, ID)
		check(row.Text == "Put the potion in a quick slot" and row.ShortName == "Quick slot" and row.Story.Guide == "QuickSlot" and row.Story.St == 3,
			faction .. ": row 3 reads 'Put the potion in a quick slot' (guide: the bag's slots)", show(row))
		check(w.Story.Wants(p, "QuickSlotSet") == true and w.Story.Wants(p, "PotionBought") == false and w.Story.Wants(p, "PotionUsed") == false,
			faction .. ": step 3 waits for QuickSlotSet only", "")
		check(p:GetAttribute("PotionSip") == false, faction .. ": step 3: no sip yet (the potion is not in a slot)", tostring(p:GetAttribute("PotionSip")))
		-- 3. the slot
		check(w.Story.Event(p, "QuickSlotSet", { Slot = 1, Kind = "HP" }) == true and tr.St == 4, faction .. ": QuickSlotSet moves step 3 to 4", show(tr))
		row = rowOf(w, p, d, ID)
		check(row.Text == "Drink it from your quick slot" and row.ShortName == "Drink potion" and row.Story.Guide == "QuickSlot" and row.Story.St == 4,
			faction .. ": row 4 reads 'Drink it from your quick slot'", show(row))
		check(w.Story.Wants(p, "PotionUsed") == true and w.Story.Wants(p, "QuickSlotSet") == false, faction .. ": step 4 waits for PotionUsed only", "")
		check(p:GetAttribute("PotionSip") == true, faction .. ": step 4: PotionSip is true at once (the client lets a full bar be used)", tostring(p:GetAttribute("PotionSip")))
		-- 4. the drink
		check(w.Story.Event(p, "PotionUsed", { Kind = "HP" }) == true and tr.St == 5 and w.Story.Wants(p, "PotionUsed") == false,
			faction .. ": PotionUsed moves step 4 to 5", show(tr))
		check(p:GetAttribute("PotionSip") == false, faction .. ": step 5: PotionSip false again", tostring(p:GetAttribute("PotionSip")))
		row = rowOf(w, p, d, ID)
		check(row.Text == "Use the Enhance Scroll at Otto's anvil" and row.ShortName == "Enhance" and row.Story.Guide == "Blacksmith"
			and row.Story.St == 5 and row.CanClaim == false, faction .. ": row 5 reads 'Use the Enhance Scroll at Otto's anvil'", show(row))
		check(w.Story.Wants(p, "ScrollUsed") == true and w.Story.Wants(p, "PotionUsed") == false, faction .. ": step 5 waits for ScrollUsed only", "")
		-- 5. the scroll (LootService's ScrollUsed, success or not)
		check(w.Story.Event(p, "ScrollUsed", { Tier = 1, Success = false }) == true and tr.St == 6, faction .. ": ScrollUsed moves step 5 to 6", show(tr))
		row = rowOf(w, p, d, ID)
		check(row.Text == "Defeat the King Slime" and row.Story.St == 6 and row.Story.Guide == "KingHill" and row.CanClaim == false,
			faction .. ": row 6 reads 'Defeat the King Slime' again (guide: the King's hill, A23-227)", show(row))
		-- 6. the rematch: only a personal King Slime kill in the meadow; the King on = never by itself
		for _ = 1, 3 do w.Story.Refresh(p) end
		w:Kill(p, "SlimeKing", { Personal = false })
		w:Kill(p, "SlimeKing", { Personal = false })
		w:Kill(p, "Slime", { Personal = true })
		w:Kill(p, "BigSlime", { Personal = true })
		w:Kill(p, "SlimeKing", { Personal = true, Zone = "Crossroads" })
		check(tr.St == 6 and w:Track(d, ID) == tr and d.Story.Done.M1_2 == nil,
			faction .. ": the 1 s loop (King on) and other kills (a shared King, another monster, another zone) never finish it", show(tr))
		local xp0, bank0, g0 = #w.XP, d.BankGold or 0, #w.Granted
		w:Kill(p, "SlimeKing", { Personal = true })
		check(d.Story.Done.M1_2 == true and w:Track(d, ID) == nil and done[#done] == ID and w.Story.CurrentStep(p, ID) == nil,
			faction .. ": the personal King's defeat finishes it: Done, QuestDone fires, no track left", show({ d.Story.Done.M1_2, done }))
		check((d.BankGold or 0) > bank0 and #w.XP == xp0 + 1 and w.XP[#w.XP].N > 0 and #w.Granted == g0 + 1
			and w.Granted[#w.Granted].Id == "Enh70" and w.Granted[#w.Granted].N == 1,
			faction .. ": paid two minutes of hunting gold + XP and one 70% scroll", show({ d.BankGold, w.XP[#w.XP], w.Granted }))
		check(noticeAbout(w, p, n0, { "the king's hop done" }) ~= nil, faction .. ": the usual 'done' line says the quest is over", show(w:NoticesFor(p, n0)))
		-- never again
		local count = 0
		for _, id in done do if id == ID then count += 1 end end
		w:Kill(p, "SlimeKing", { Personal = true })
		w.Story.Refresh(p)
		w.Story.Event(p, "FirstKO")
		check(count == uid - 1200 and w:Track(d, ID) == nil and #w.Granted == g0 + 1, faction .. ": never again (one payout)", tostring(count))
		local n = uid - 1200
		check(#stepLog == n * 6 and table.concat(stepLog, ",", (n - 1) * 6 + 1, n * 6) == "1,2,3,4,5,6",
			faction .. ": StepDone fired for steps 1-6 of M1_2, once each, in order (the FirstKO funnel's feed)", table.concat(stepLog, ","))
	end
end)

------------------------------------------------------------------ 3b. the anvil step (A23-221 ②): Otto's talk opens the Enhance window
runGroup("anvil", function()
	local w = koWorld()
	local panels = panelsOf(w)
	w:NpcBody("Otto", vec(39, 0, 49))
	local function enhancePanels(p, from)
		local out = {}
		for i = from + 1, #panels do
			if panels[i].P == p and panels[i].Kind == "Enhance" then table.insert(out, panels[i].Arg) end
		end
		return out
	end
	local function scrollsOf(d) return (type(d.Items) == "table" and d.Items.Enh70) or 0 end
	-- a player holding the Prince's scroll, at row 1
	local p, d = joinKO(w, 1251, "Halo", { Tier = 2, Mask = 3, Data = { Items = { Enh70 = 1 }, QuickSlots = ",," } })
	local tr = w:Track(d, ID)
	rootOf(p).Position = vec(39, 3, 60) -- 11 studs from Otto
	local f0 = #panels
	check(w.Story.TalkToNpc(p, "Otto") ~= ID and #enhancePanels(p, f0) == 0, "row 1: a talk to Otto opens no Enhance window", "")
	toAnvil(w, p)
	check(tr.St == 5, "the four happenings bring M1_2 to the anvil row (5)", show(tr))
	rootOf(p).Position = vec(39, 3, 90) -- 41 studs away
	f0 = #panels
	check(w.Story.TalkToNpc(p, "Otto") ~= ID and #enhancePanels(p, f0) == 0, "row 5 from 41 studs: nothing", "")
	rootOf(p).Position = vec(39, 3, 60)
	f0 = #panels
	local g0 = #w.Granted
	check(w.Story.TalkToNpc(p, "Bright") ~= ID and #enhancePanels(p, f0) == 0, "row 5: a talk to another NPC (Bright) opens no Enhance window", "")
	check(w.Story.TalkToNpc(p, "Otto") == ID, "row 5 beside Otto: the talk answers M1_2", "")
	local e = enhancePanels(p, f0)
	check(#e == 1 and e[1].Item == "Enh70" and e[1].Tier == 2 and #w.Granted == g0 and scrollsOf(d) == 1 and tr.St == 5,
		"OpenPanel 'Enhance' { Item = Enh70, Tier = the weapon in hand (2) }; nothing granted (a scroll is in the bag), the row waits",
		show({ e[1], #w.Granted - g0, scrollsOf(d) }))
	-- the pick: Enh70 first, then Enh30, then Enh10
	d.Items.Enh70, d.Items.Enh30, d.Items.Enh10 = 0, 2, 1
	f0 = #panels
	w.Story.TalkToNpc(p, "Otto")
	e = enhancePanels(p, f0)
	check(#e == 1 and e[1].Item == "Enh30" and #w.Granted == g0, "no 70% scroll: the 30% one is picked (nothing granted)", show(e[1]))
	-- the window's use (LootService UseItem -> Event ScrollUsed) moves the row to the rematch
	d.Items.Enh30, d.Items.Enh10 = 0, 0
	d.Items.Enh70 = 1
	w:Advance(1) -- RateLimits.UseItem
	w.Net.Get("UseItem").OnServerEvent:Fire(p, "Enh70", 2)
	w:Flush()
	check(tr.St == 6 and scrollsOf(d) == 0 and d.Story.First.ScrollUsed == true, "the scroll used on the weapon (LootService): row 6, the rematch",
		show({ tr, scrollsOf(d) }))
	f0 = #panels
	check(w.Story.TalkToNpc(p, "Otto") ~= ID and #enhancePanels(p, f0) == 0, "row 6: Otto's talk opens no Enhance window any more", "")
	-- an empty bag (the Prince's scroll sold / lost): one Enh70 granted ONCE, then the window
	local q, qd = joinKO(w, 1252, "Horns", { Tier = 1, Mask = 1, Data = { QuickSlots = ",," } })
	local qtr = w:Track(qd, ID)
	toAnvil(w, q)
	rootOf(q).Position = vec(40, 3, 52)
	f0, g0 = #panels, #w.Granted
	check(w.Story.TalkToNpc(q, "Otto") == ID, "empty bag beside Otto: the talk answers M1_2", "")
	e = enhancePanels(q, f0)
	check(#w.Granted == g0 + 1 and w.Granted[#w.Granted].Id == "Enh70" and w.Granted[#w.Granted].N == 1 and scrollsOf(qd) == 1
		and qd.Story.First.AnvilScroll == true and #e == 1 and e[1].Item == "Enh70" and e[1].Tier == 1 and qtr.St == 5,
		"no scroll in the bag: one Enh70 granted (Story.First.AnvilScroll), the window opens with it", show({ w.Granted[#w.Granted], e[1], qd.Story.First }))
	qd.Items.Enh70 = 0 -- sold again
	f0, g0 = #panels, #w.Granted
	w.Story.TalkToNpc(q, "Otto")
	e = enhancePanels(q, f0)
	check(#w.Granted == g0 and scrollsOf(qd) == 0 and #e == 1 and e[1].Item == nil and qtr.St == 5,
		"a second talk with an empty bag grants nothing more (the window opens with no scroll)", show({ #w.Granted - g0, e[1] }))
	-- Past: a scroll used from the bag before the anvil row passes row 5 at once
	local r, rd = joinKO(w, 1253, "Neutral", { Tier = 1, Mask = 1, Data = { Items = { Enh70 = 1 }, QuickSlots = ",," } })
	local rtr = w:Track(rd, ID)
	w:Advance(1)
	w.Net.Get("UseItem").OnServerEvent:Fire(r, "Enh70", 1)
	w:Flush()
	check(rtr.St == 1 and rd.Story.First.ScrollUsed == true, "a scroll used from the bag at row 1: remembered, the row stays", show(rtr))
	toAnvil(w, r)
	check(rtr.St == 6, "the drink then passes the anvil row at once (a scroll used before counts: Past) -> the rematch", show(rtr))
	-- the anvil's grant waits for the anvil row: no M1_2 here, Otto's talk never grants
	local s, sd = joinKO(w, 1254, "Halo", { Done = { M1_1 = true, M1_2 = true }, Data = { QuickSlots = ",," } })
	rootOf(s).Position = vec(40, 3, 52)
	g0 = #w.Granted
	w.Story.TalkToNpc(s, "Otto")
	check(#w.Granted == g0 and sd.Story.First.AnvilScroll == nil, "not on the anvil row: Otto's talk grants no scroll", "")
end)

------------------------------------------------------------------ 3b2. A23-225: the story's first enhance always succeeds (once a save)
runGroup("sure first enhance", function()
	local w = koWorld()
	local SF = w.Config.Loot.SureFirst
	check(type(SF) == "table" and SF.Quest == "M1_2" and SF.Item == "Enh70" and SF.Flag == "SureEnhance", "Config.Loot.SureFirst = M1_2 / Enh70 / SureEnhance", show(SF))
	local function use(p, item, tier)
		w:Advance(1) -- RateLimits.UseItem
		w.Net.Get("UseItem").OnServerEvent:Fire(p, item, tier)
		w:Flush()
	end
	-- on the anvil row: the first 70% scroll succeeds even on a roll that would fail
	local p, d = joinKO(w, 1271, "Halo", { Tier = 2, Mask = 3, Data = { Items = { Enh70 = 2 }, QuickSlots = ",," } })
	toAnvil(w, p)
	check(w:Track(d, ID).St == 5, "at the anvil row", "")
	w.Script = { 0.99 }
	use(p, "Enh70", 2)
	check(d.WeaponEnhance[2] == 1 and d.LootFlags.SureEnhance == true and w:Track(d, ID).St == 6,
		"the first 70% scroll on the anvil row: +0 -> +1 even on a 0.99 roll, the flag saved, on to the rematch", show({ d.WeaponEnhance[2], d.LootFlags }))
	-- the second one keeps its 70% and the fail rule (0.99 fails, 0.0 = the 50% drop)
	w.Script = { 0.99, 0.0 }
	use(p, "Enh70", 2)
	check(d.WeaponEnhance[2] == 0 and (d.Items.Enh70 or 0) == 0, "the next scroll: the usual 70% (a 0.99 roll fails and drops +1 -> +0)", show(d.WeaponEnhance))
	w.Script = {}
	-- not on the anvil row (row 1): the usual chance
	local q, qd = joinKO(w, 1272, "Horns", { Tier = 2, Mask = 3, Data = { Items = { Enh70 = 1 }, QuickSlots = ",," } })
	w.Script = { 0.99, 0.9 }
	use(q, "Enh70", 2)
	check(qd.WeaponEnhance[2] == 0 and qd.LootFlags.SureEnhance == nil, "row 1 (before the anvil row): no sure success, no flag", show(qd.WeaponEnhance))
	-- another scroll kind on the anvil row: its own chance
	local r, rd = joinKO(w, 1273, "Neutral", { Tier = 2, Mask = 3, Data = { Items = { Enh30 = 1 }, QuickSlots = ",," } })
	toAnvil(w, r)
	w.Script = { 0.99, 0.9 }
	use(r, "Enh30", 2)
	check(rd.WeaponEnhance[2] == 0 and rd.LootFlags.SureEnhance == nil, "a 30% scroll on the anvil row: its own chance (only the 70% one is sure)", show(rd.WeaponEnhance))
	-- an old save past M1_2: never
	local s, sd = joinKO(w, 1274, "Halo", { Tier = 2, Mask = 3, Done = { M1_1 = true, M1_2 = true }, Data = { Items = { Enh70 = 1 }, QuickSlots = ",," } })
	w.Script = { 0.99, 0.9 }
	use(s, "Enh70", 2)
	check(sd.WeaponEnhance[2] == 0 and sd.LootFlags.SureEnhance == nil, "a save past M1_2: the usual chance", show(sd.WeaponEnhance))
	-- once a save: a flag already set = the usual chance even on the anvil row
	local t, td = joinKO(w, 1275, "Halo", { Tier = 2, Mask = 3, Data = { Items = { Enh70 = 1 }, QuickSlots = ",,", LootFlags = { SureEnhance = true } } })
	toAnvil(w, t)
	w.Script = { 0.99, 0.9 }
	use(t, "Enh70", 2)
	check(td.WeaponEnhance[2] == 0, "the flag already set (used once before): the usual chance", show(td.WeaponEnhance))
	w.Script = {}
	local _ = { q, r, s, t }
end)

------------------------------------------------------------------ 3c. the personal King switched off (Config.FirstKOKing.Enabled = false)
-- the rematch row (6) can only be finished by the personal King: with the King off it passes by itself (the main never sticks);
-- the KO row is told by FirstKOService ("Tell": Event FirstKO, checked in tools/fixtures/first_ko_king_offline.luau)
runGroup("the King off", function()
	local w = koWorld()
	local done = {}
	w.Story.QuestDone:Connect(function(_, id) table.insert(done, id) end)
	w.Config.FirstKOKing = { Enabled = false }
	local p, d = joinKO(w, 1271, "Halo", { Data = { QuickSlots = ",," } })
	local tr = w:Track(d, ID)
	check(tr ~= nil and tr.St == 1, "King off: M1_2 still runs, row 1", show(d.Story.Main))
	for _ = 1, 3 do w.Story.Refresh(p) end
	check(tr.St == 1, "King off: row 1 (an Event row) does not pass by itself (it waits for the told FirstKO)", show(tr))
	check(w.Story.Event(p, "FirstKO", { Kind = "SlimeKing" }) == true and tr.St == 2, "the told KO (FirstKO) moves row 1", show(tr))
	toAnvil(w, p)
	w.Story.Event(p, "ScrollUsed", { Tier = 1, Success = true })
	check(d.Story.Done.M1_2 == true and done[#done] == ID and w:Track(d, ID) == nil,
		"King off: the rematch row passes by itself -> M1_2 done (paid, QuestDone)", show({ d.Story.Main, d.Story.Done.M1_2 }))
	-- a save waiting on the rematch row when the King goes off: the next refresh passes it
	w.Config.FirstKOKing = { Enabled = true }
	local q, qd = joinKO(w, 1272, "Horns", { Data = { QuickSlots = ",," } })
	local qtr = w:Track(qd, ID)
	toAnvil(w, q)
	w.Story.Event(q, "ScrollUsed", { Tier = 1, Success = true })
	for _ = 1, 3 do w.Story.Refresh(q) end
	check(qtr.St == 6 and qd.Story.Done.M1_2 == nil, "King on: the rematch row waits for the King", show(qtr))
	w.Config.FirstKOKing.Enabled = false
	w.Story.Refresh(q)
	check(qd.Story.Done.M1_2 == true, "the King switched off while the row waits: the next refresh passes it", show(qd.Story.Main))
	-- only a Personal kill row passes: another main's shared kill row (M1_1's Prince) still waits with the King off
	local r, rd = joinKO(w, 1273, "Neutral", { Done = {} })
	for _ = 1, 3 do w.Story.Refresh(r) end
	check(rd.Story.Main.Id == "M1_1" and rd.Story.Main.St == 1 and rd.Story.Done.M1_1 == nil,
		"King off: M1_1's shared Slime Prince row never passes by itself", show(rd.Story.Main))
	-- a table without Enabled = on
	w.Config.FirstKOKing = { Kind = "SlimeKing" }
	local s, sd = joinKO(w, 1274, "Halo", { Data = { QuickSlots = ",," } })
	toAnvil(w, s)
	w.Story.Event(s, "ScrollUsed", { Tier = 1, Success = true })
	w.Story.Refresh(s)
	check(w:Track(sd, ID) ~= nil and w:Track(sd, ID).St == 6, "a FirstKOKing table without Enabled: on (the rematch row waits)", show(sd.Story.Main))
end)

------------------------------------------------------------------ 4. no gold top-up any more (A23-222: a new save starts with 1000 gold)
-- (user 10/16 "그러면 돈이 모자라면 채워줄 필요 없자넝"): the engine no longer reads a step's TopUpGold; the test-only sub KOT
-- still carries TopUpGold = 50 on its step 2, so a top-up coming back shows here
runGroup("top-up", function()
	local w = koWorld({ TestSub = true })
	local uid = 1300
	local function done2() return { M1_1 = true, M1_2 = true } end
	local function arriveAt2(name, carried, bank)
		uid += 1
		local p, d = joinKO(w, uid, "Halo", { Carried = carried, Bank = bank, Done = done2() })
		local before = #w.GoldGiven
		w.Story.Event(p, "FirstKO")
		local given = #w.GoldGiven - before
		check(given == 0 and d.CarriedGold == carried and d.BankGold == bank and d.Story.Subs.KOT and d.Story.Subs.KOT.St == 2,
			name .. ": step 2 opens, no gold added (no top-up)", show({ given, d.CarriedGold, d.BankGold, d.Story.Subs.KOT }))
		check(d.Story.First.TopKOT2 == nil, name .. ": no top-up flag saved", show(d.Story.First))
		return p, d
	end
	arriveAt2("no gold", 0, 0)
	arriveAt2("30 carried", 30, 0)
	arriveAt2("49 gold", 0, 49)
	arriveAt2("500 gold", 500, 300)
	-- a step that passes at once (the potion was bought earlier) moves on, still no gold
	uid += 1
	local q, qd = joinKO(w, uid, "Horns", { Done = done2() })
	local g0 = #w.GoldGiven
	check(w.Story.Event(q, "PotionBought") == false, "a purchase before the KO moves nothing yet", show(qd.Story.Subs.KOT))
	w.Story.Event(q, "FirstKO")
	check(qd.Story.Subs.KOT.St == 3 and #w.GoldGiven == g0 and (qd.CarriedGold or 0) == 0, "step 2 passes at once (bought earlier), no gold", show({ qd.Story.Subs.KOT, #w.GoldGiven - g0 }))
	-- the engine's keeps on the test sub: Lv cap, no potion yet, after its Done
	local function offered(name, o, expect)
		uid += 1
		o.Done = o.Done or done2()
		local _, od = joinKO(w, uid, "Halo", o)
		check((od.Story.Subs.KOT ~= nil) == expect, "KOT " .. name .. (expect and ": offered" or ": not offered"), show(od.Story.Subs.KOT))
	end
	offered("Lv8 (MaxLevel 8)", { Level = 8 }, true)
	offered("Lv9", { Level = 9 }, false)
	offered("before its Done (M1_2)", { Done = { M1_1 = true } }, false)
	offered("an HP potion in the bag", { Data = { HPPotionCount = 1 } }, false)
	offered("an MP potion in the bag", { Data = { MPPotionCount = 2 } }, false)
	offered("a potion bought once", { First = { Migrated = true, PotionBought = true } }, false)
	offered("a potion drunk once", { First = { Migrated = true, PotionUsed = true } }, false)
end)

------------------------------------------------------------------ 5. running ahead is never a dead end
runGroup("ahead", function()
	local w = koWorld()
	local uid = 1400
	local function start(faction, slots)
		uid += 1
		local p, d = joinKO(w, uid, faction or "Halo", { Data = slots ~= nil and { QuickSlots = slots } or nil })
		return p, d, w:Track(d, ID)
	end
	-- a KO from before the quest started is not step 1 (the step is the quest's own KO)
	uid += 1
	local old, oldD = joinKO(w, uid, "Halo", { First = { Migrated = true, FirstKO = true } })
	check(w:Track(oldD, ID) ~= nil and w:Track(oldD, ID).St == 1 and w.Story.Wants(old, "FirstKO") == true,
		"an old KO does not pass step 1: the quest waits for its own KO", show(w:Track(oldD, ID)))
	-- bought, put in a slot and drunk before the KO: the KO goes straight to the anvil row
	local p, d, tr = start("Halo", ",,")
	w.Story.Event(p, "PotionBought")
	w.Story.Event(p, "QuickSlotSet", { Slot = 2, Kind = "MP" })
	w.Story.Event(p, "PotionUsed")
	check(tr.St == 1 and d.Story.First.PotionBought == true and d.Story.First.QuickSlotSet == true and d.Story.First.PotionUsed == true,
		"events seen early are remembered, the open step does not move", show(tr))
	w.Story.Event(p, "FirstKO")
	check(tr.St == 5 and w.Story.Wants(p, "PotionUsed") == false and w.Story.Wants(p, "ScrollUsed") == true and p:GetAttribute("PotionSip") == false,
		"the KO then passes steps 2, 3 and 4 at once (step 5 waits for the scroll; the sip flag never lit)", show(tr))
	-- ... and with the scroll used early too: straight to the rematch
	p, d, tr = start("Horns", ",,")
	for _, name in { "PotionBought", "QuickSlotSet", "PotionUsed", "ScrollUsed" } do w.Story.Event(p, name) end
	w.Story.Event(p, "FirstKO")
	check(tr.St == 6, "everything seen early: the KO goes straight to the rematch row (6)", show(tr))
	-- drunk before bought
	p, d, tr = start("Horns", ",,")
	w.Story.Event(p, "PotionUsed")
	w.Story.Event(p, "FirstKO")
	check(tr.St == 2, "a drink before the KO does not skip the purchase", show(tr))
	w.Story.Event(p, "PotionBought")
	check(tr.St == 3 and w.Story.Wants(p, "QuickSlotSet") == true, "the purchase does not skip the slot step", show(tr))
	w.Story.Event(p, "QuickSlotSet", { Slot = 1, Kind = "HP" })
	check(tr.St == 5, "the slot passes the drink step at once (already seen); the anvil row is next", show(tr))
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
	check(w.Story.Event(c, "FirstKO") == false and w.Story.Wants(c, "FirstKO") == false and w.Story.CurrentStep(c, ID) == nil, "no data: nothing", "")
	w.Ready[a] = false
	check(w.Story.Event(a, "PotionBought") == false and atr.St == 2 and ad.Story.First.PotionBought == nil, "a player who is not ready is ignored", show(atr))
	w.Ready[a] = true
	-- a finished or unknown quest has no step; a bad id / player is nil
	check(w.Story.CurrentStep(a, "Nope") == nil and w.Story.CurrentStep(a, nil) == nil and w.Story.CurrentStep("a", ID) == nil, "CurrentStep: bad arguments give nil", "")
	-- [Claim] state: a quest waiting for the claim is not 'at a step'
	atr.Claim = true
	check(w.Story.CurrentStep(a, ID) == nil and w.Story.Wants(a, "PotionBought") == false, "a quest waiting for [Claim] is at no step", "")
	atr.Claim = false
	local _ = b
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
	-- the existing quests are not changed by it: M1_1 (its Slime Prince step) ignores a personal BigSlime
	local q, qd = w:Join(1501, { Faction = "Halo", Level = 3, Data = { Story = { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = { Migrated = true } } } })
	w.Story.Refresh(q)
	local m = qd.Story.Main
	check(m.Id == "M1_1" and m.St == 1, "M1_1 is the main quest", show(m))
	w:Kill(q, "BigSlime", { Personal = true })
	check(m.St == 1 and m.P == 0 and qd.Story.Done.M1_1 == nil, "a personal Slime Prince does not count for M1_1", show(m))
	w:Kill(q, "BigSlime", { Personal = false })
	w.Story.Refresh(q)
	check(qd.Story.Done.M1_1 == true and qd.Story.Main.Id == ID and qd.Story.Main.St == 1,
		"a shared one does: M1_1 done (one step), the King's Hop starts at row 1 (next refresh)", show(qd.Story.Main))
end)

------------------------------------------------------------------ 7. Studio test aids (Main's DebugCommand StorySub / StoryDone)
runGroup("debug aids", function()
	local w = koWorld({ TestSub = true })
	local panels = panelsOf(w)
	local done = {}
	w.Story.QuestDone:Connect(function(_, id) table.insert(done, id) end)
	local function done2() return { M1_1 = true, M1_2 = true } end
	-- Lv9: the test sub KOT is never offered by itself, the aid starts it anyway at the step asked for
	local p, d = joinKO(w, 1601, "Halo", { Level = 9, Done = done2(), Data = { QuickSlots = ",," } })
	check(w:Track(d, "KOT") == nil, "Lv9: KOT is not offered by itself", "")
	local n0 = #w.Notices
	check(w.Story.DebugSub(p, "KOT", 3) == "ok" and w:Track(d, "KOT") ~= nil and w:Track(d, "KOT").St == 3 and w.Story.Wants(p, "QuickSlotSet") == true,
		"DebugSub KOT step 3: the quest starts at 'Put the potion in a quick slot'", show(w:Track(d, "KOT")))
	check(#w.Notices == n0 and #panels == 0 and #done == 0 and #w.XP == 0 and #w.Granted == 0, "... no notice, no popup, no QuestDone, no reward", "")
	check(w.Story.DebugSub(p, "KOT", 4) == "ok" and w:Track(d, "KOT").St == 4 and p:GetAttribute("PotionSip") == true,
		"DebugSub again: moves it to step 4 (the sip flag lit)", show(w:Track(d, "KOT")))
	-- A23-222: step 2 comes with no gold (the top-up is gone, like a real arrival)
	local q, qd = joinKO(w, 1602, "Horns", { Level = 9, Done = done2() })
	check(w.Story.DebugSub(q, "KOT", 2) == "ok" and (qd.CarriedGold or 0) == 0 and qd.Story.First.TopKOT2 == nil, "DebugSub KOT step 2: no gold top-up (A23-222)", show({ qd.CarriedGold, qd.Story.First }))
	check(w.Story.DebugSub(q, "KOT", 2) == "ok" and (qd.CarriedGold or 0) == 0, "... again: still none", show(qd.CarriedGold))
	-- a bare quest id = step 1; a fraction rounds down; a bad step / quest is refused and changes nothing
	local r, rd = joinKO(w, 1603, "Neutral", { Level = 9, Done = done2() })
	check(w.Story.DebugSub(r, "KOT") == "ok" and w:Track(rd, "KOT").St == 1, "no step given: step 1", show(w:Track(rd, "KOT")))
	check(w.Story.DebugSub(r, "KOT", 2.7) == "ok" and w:Track(rd, "KOT").St == 2, "2.7 -> step 2", show(w:Track(rd, "KOT")))
	for _, bad in { 0, -1, 7, 99 } do
		check(string.find(w.Story.DebugSub(r, "KOT", bad), "steps 1-6", 1, true) ~= nil and w:Track(rd, "KOT").St == 2, "step " .. tostring(bad) .. " is refused (steps 1-6)", show(w:Track(rd, "KOT")))
	end
	check(string.find(w.Story.DebugSub(r, "Nope", 1), "no such sub quest", 1, true) ~= nil and string.find(w.Story.DebugSub(r, ID, 1), "no such sub quest", 1, true) ~= nil
		and rd.Story.Subs.M1_2 == nil, "an unknown id / a main quest (M1_2) is not a sub quest", "")
	check(w.Story.DebugSub(w:NewPlayer(1699, {}), "KOT", 1) == "no data", "no save: refused", "")
	-- a finished quest can be started again
	rd.Story.Done.KOT = true
	rd.Story.Subs.KOT = nil
	check(w.Story.DebugSub(r, "KOT", 1) == "ok" and rd.Story.Done.KOT == nil and w:Track(rd, "KOT").St == 1, "a done quest starts again (its Done mark is cleared)", show(rd.Story.Done))
	-- StoryDone: no reward, no QuestDone, never restarts by itself
	local gold0 = #w.GoldGiven
	check(w.Story.DebugDone(r, "KOT") == "ok" and rd.Story.Done.KOT == true and w:Track(rd, "KOT") == nil, "DebugDone: marked done, the track is gone", show({ rd.Story.Done, w:Track(rd, "KOT") }))
	w.Story.Refresh(r)
	check(w:Track(rd, "KOT") == nil and #done == 0 and #w.XP == 0 and #w.Granted == 0 and #w.GoldGiven == gold0, "... never restarted, no QuestDone, no reward", "")
	-- a main quest done: the main slot is free (M1_2 = the King's Hop, the main after M1_1)
	local m, md = joinKO(w, 1604, "Halo", { Level = 5 })
	check(md.Story.Main.Id == ID, "M1_2 is the active main quest after M1_1 (it starts by itself)", show(md.Story.Main))
	check(w.Story.DebugDone(m, ID) == "ok" and md.Story.Done.M1_2 == true and md.Story.Main.Id ~= ID, "DebugDone on the active main quest: done, the slot is free", show(md.Story.Main))
	check(string.find(w.Story.DebugDone(m, "Nope"), "no such quest", 1, true) ~= nil and w.Story.DebugDone(w:NewPlayer(1698, {}), ID) == "no data", "unknown quest / no save: refused", "")
end)

------------------------------------------------------------------ 8. a brand-new Studio save, start to finish (검수 10/10 main apply: the slot step went by at once)
runGroup("a brand-new Studio save keeps the slot step", function()
	local rec = memoryRecord(1701)
	check(type(rec) == "table" and rec.QuickSlots == ",,", "DataService's memory-mode record starts with empty quick slots", show(rec and rec.QuickSlots))
	local w = koWorld({ Quick = true })
	local function player(uid, saved)
		local d = saved
		d.Class, d.Faction, d.ClassChosen, d.Level, d.TutorialStep = "Warrior", "Halo", true, 4, 99
		d.Story = { Main = { Id = "" }, Subs = {}, Done = { M1_1 = true }, Pick = {}, First = { Migrated = true }, Schema = 6 }
		local p = w:Join(uid, { Saved = d })
		w.Story.Refresh(p)
		w:Flush()
		return p, d
	end
	-- the real chain: record -> QuickSlotService at PlayerReady -> the story service
	local p, d = player(1701, rec)
	check(d.QuickSlots == ",," and p:GetAttribute("QuickSlots") == ",,", "ready: still three empty slots (no HP / MP given)", show({ d.QuickSlots, p:GetAttribute("QuickSlots") }))
	local tr = w:Track(d, ID)
	check(tr ~= nil and tr.St == 1, "the new player (M1_1 done, Lv4, no potions) is on the King's Hop", show(d.Story.Main))
	w.Story.Event(p, "FirstKO")
	check(tr.St == 2, "the King's KO: 'Buy a potion'", show({ tr.St, d.CarriedGold }))
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
	check(qd.QuickSlots == "HP,MP," and w:Track(qd, ID).St == 4, "a save from before the slots (no field) is given HP, MP: nothing to put, step 3 passes", show({ qd.QuickSlots, w:Track(qd, ID).St }))
end)

------------------------------------------------------------------ the engine's KingOn keep (test-only sub KOT; no shipped quest uses it since A23-222)
-- a sub whose rematch row only the personal King can finish: with the King off it is not offered, and a started one leaves
-- (it starts again, from its first row, when the King is back)
runGroup("the personal King switch", function()
	local w = koWorld({ TestSub = true })
	local function done2() return { M1_1 = true, M1_2 = true } end
	-- no FirstKOKing table at all (a tree without game dev 2's service) = on
	w.Config.FirstKOKing = nil
	local _, ad = joinKO(w, 1800, "Halo", { Done = done2() })
	check(w:Track(ad, "KOT") ~= nil and w:Track(ad, "KOT").St == 1, "no FirstKOKing table: KOT is offered", show(w:Track(ad, "KOT")))
	-- off: a new player is not offered it, with no row and no toast
	w.Config.FirstKOKing = { Enabled = false }
	local n0 = #w.Notices
	local b, bd = joinKO(w, 1801, "Horns", { Done = done2() })
	check(w:Track(bd, "KOT") == nil and rowOf(w, b, bd, "KOT") == nil and noticeAbout(w, b, n0, { "king", "potion", "hop" }) == nil,
		"King off: a new player is not offered KOT (no row, no toast)", show(w:Track(bd, "KOT")))
	w.Config.FirstKOKing.Enabled = true
	w.Story.Refresh(b)
	check(w:Track(bd, "KOT") ~= nil and w:Track(bd, "KOT").St == 1, "King on again: offered", show(w:Track(bd, "KOT")))
	check(w.Story.Event(b, "FirstKO") == true and w:Track(bd, "KOT").St == 2, "row 2 reached", show(w:Track(bd, "KOT")))
	w.Config.FirstKOKing.Enabled = false
	w.Story.Refresh(b)
	check(w:Track(bd, "KOT") == nil and bd.Story.Done.KOT == nil, "King off: the started sub leaves (it is not done, no reward)", show({ w:Track(bd, "KOT"), bd.Story.Done.KOT }))
	for _ = 1, 3 do w.Story.Refresh(b) end
	check(w:Track(bd, "KOT") == nil, "... and stays away while the King is off", "")
	w.Config.FirstKOKing.Enabled = true
	w.Story.Refresh(b)
	check(w:Track(bd, "KOT") ~= nil and w:Track(bd, "KOT").St == 1, "King on again: the sub starts again at row 1", show(w:Track(bd, "KOT")))
	w.Config.FirstKOKing = { Kind = "SlimeKing" }
	local _, cd = joinKO(w, 1802, "Neutral", { Done = done2() })
	check(w:Track(cd, "KOT") ~= nil, "a table without Enabled: on", show(w:Track(cd, "KOT")))
end)

finish()
