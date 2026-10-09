-- forest_call_offline.luau : A23-86 "Call of the Woods" (content_beyond_10min A, 게임성 개발 3, 2026-10-09).
-- tools/test_forest_call.py binds CONFIG_SOURCE, UTIL_SOURCE and STORY_SOURCE in front of dev2_kit.luau + dev3_world.luau;
-- this file follows. StoryQuestService runs from source (Init + Start with hand-stepped loops); everything else is the
-- dev3_world doubles. Covers: M2_6 can be filled by Goblin Brutes in the Goblin Woods from Lv10 (Alt), the row text,
-- and the new bridge sub WB1 (the lantern card).

local NOON = 1789959600

local function storyWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	local env = w:Env()
	env.workspace = { GetServerTimeNow = function() return w.Time end, FindFirstChild = function() return w.GameState end }
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	local story = execute("StoryQuestService", STORY_SOURCE, env)
	w.Reg.StoryQuestService = story
	story.Init(w.Reg)
	story.Start()
	w:StartLoops()
	return w
end

local function hero(w, id, faction, level, story)
	local data = { Faction = faction, Class = "Warrior", ClassChosen = true, Level = level, TutorialStep = 99, Story = story }
	return w:Arrive(id, { Data = data })
end

local function storyOf(done, subs, main)
	local d = {}
	for _, id in done or {} do d[id] = true end
	return { Main = main or { Id = "" }, Subs = subs or {}, Done = d, Pick = {}, First = { Migrated = true } }
end

local function killEvent(kind, zone, extra)
	local info = { Kind = kind, ZoneId = zone, Position = vec(0, 0, 0) }
	for k, v in extra or {} do info[k] = v end
	return { Kind = "Kill", Info = info }
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local sq = C.StoryQuests
	local step = sq.Defs.M2_6.Steps[1]
	local alt = step.Obj.Alt
	check(type(alt) == "table" and alt.MinLevel == 10 and #alt.Pairs == 1 and alt.Pairs[1].Kind == "GoblinBrute"
		and alt.Pairs[1].Zone == "GoblinWoods", "M2_6: from Lv10 a Goblin Brute in the Goblin Woods counts too", show(alt))
	check(step.Obj.Kind == "BigSlime" and step.Obj.Zone == "SlimeMeadow" and step.Obj.Count == 2, "M2_6 still asks 2 Slime Princes in the meadow", show(step.Obj))
	check(step.Text == "Slime Princes %d/%d" and step.AltText == "Slime Princes or Goblin Brutes %d/%d", "the row texts", show({ step.Text, step.AltText }))
	check(C.Plural("Slime Princes or Goblin Brutes 1") ~= nil, "the row text passes Plural", C.Plural("Slime Princes or Goblin Brutes 1"))
	check(C.MonsterTypes.GoblinBrute.Zone == "GoblinWoods" and C.MonsterTypes.BigSlime.Zone == "SlimeMeadow", "the kinds live in those zones", "")
	local n = 0
	for _, id in sq.Subs do if id == "WB1" then n += 1 end end
	check(n == 1 and sq.Defs.WB1 ~= nil and sq.Defs.WB1.Kind == "Sub", "WB1 is a sub, listed once", n)
	local wb = sq.Defs.WB1
	check(wb.Requires.Level == 10 and wb.Requires.Done[1] == "M1_4" and wb.Factions.Neutral == true and wb.Factions.Halo == true
		and wb.Factions.Horns == true, "WB1: after M1_4, Lv10, every side", show({ wb.Requires, wb.Factions }))
	local s1, s2 = wb.Steps[1], wb.Steps[2]
	check(s1.Obj.Type == "Near" and s1.Obj.Spot == "WoodsGate" and sq.Landmarks.WoodsGate ~= nil, "step 1: the woods bridge (WoodsGate, outside the PvP woods)", show(s1.Obj))
	local o = s2.Obj
	check(s2.Panel == true and o.Type == "Choice" and o.Good.Points == 1 and o.Evil.Points == 1, "step 2: one card, 1 point each way", show(o))
	check(o.Good.Reward.Item == "Enh70" and o.Good.Reward.N == 1, "A: one 70% scroll", show(o.Good.Reward))
	local gold = C.HuntValue(10, 1)
	check(o.Evil.Reward.Potion == "HP" and o.Evil.Reward.N == 3 and o.Evil.Reward.Gold == gold and gold == 192,
		"B: 3 HP potions + 1 minute of Lv10 hunting gold (192) - the same worth", show({ o.Evil.Reward, gold }))
	check(o.Good.Label == "Hand it back" and o.Evil.Label == "Finders keepers!" and o.Neutral.A == "Hand it back" and o.Neutral.B == "Finders keepers!",
		"labels", show(o))
	check(not string.find(show(wb), "[\234-\237][\128-\191][\128-\191]"), "English only", "")
	check(#sq.Main + #sq.Subs <= C.QuestBook.DoneMax, "every main + sub still fits in the book's Done", #sq.Main + #sq.Subs)
	local seen = {}
	local dup = nil
	for _, id in sq.Subs do if seen[id] then dup = id end seen[id] = true end
	check(dup == nil, "no sub listed twice", tostring(dup))
end)

runGroup("alt kills (EventAmount)", function()
	local w = storyWorld()
	local S = w.Reg.StoryQuestService
	local obj = w.Config.StoryQuests.Defs.M2_6.Steps[1].Obj
	local lo, lod = hero(w, 1, "Halo", 9)
	local hi, hid = hero(w, 2, "Halo", 10)
	local function amount(p, kind, zone, extra) return S.EventAmount(p, obj, killEvent(kind, zone, extra)) end
	check(amount(lo, "BigSlime", "SlimeMeadow") == 1 and amount(hi, "BigSlime", "SlimeMeadow") == 1, "a Slime Prince in the meadow counts at Lv9 and Lv10", "")
	check(amount(lo, "GoblinBrute", "GoblinWoods") == 0, "Lv9: a Goblin Brute in the woods does not count", amount(lo, "GoblinBrute", "GoblinWoods"))
	check(amount(hi, "GoblinBrute", "GoblinWoods") == 1, "Lv10: a Goblin Brute in the woods counts", amount(hi, "GoblinBrute", "GoblinWoods"))
	check(amount(hi, "Goblin", "GoblinWoods") == 0, "Lv10: a plain goblin does not", amount(hi, "Goblin", "GoblinWoods"))
	check(amount(hi, "GoblinBrute", "SlimeMeadow") == 0, "a Goblin Brute in the wrong zone does not", amount(hi, "GoblinBrute", "SlimeMeadow"))
	check(amount(hi, "BigSlime", "GoblinWoods") == 0, "a Slime Prince in the woods does not (kind AND zone)", amount(hi, "BigSlime", "GoblinWoods"))
	check(amount(hi, "GoblinBrute", "GoblinWoods", { Personal = true }) == 0, "a personal monster never counts", "")
	hid.Level = 9
	check(amount(hi, "GoblinBrute", "GoblinWoods") == 0, "level drops under 10 (data): no more", "")
	hid.Level = 10
	-- the other Kill steps are untouched (no Alt)
	local m26 = w.Config.StoryQuests.Defs.M2_6.Steps[1].Obj
	local plain = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2 }
	check(S.EventAmount(hi, plain, killEvent("GoblinBrute", "GoblinWoods")) == 0, "a step without Alt never takes the woods", "")
	-- other objective types never read Alt
	local wrongType = { Type = "Level", Level = 5, Alt = m26.Alt }
	check(S.EventAmount(hi, wrongType, killEvent("GoblinBrute", "GoblinWoods")) == 0, "Alt only works on kill steps", "")
	-- a boss kill with the same shape still needs Near etc.
	local near = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 2, Near = "SlimePond", Radius = 5, Alt = m26.Alt }
	check(S.EventAmount(hi, near, killEvent("GoblinBrute", "GoblinWoods", { Position = vec(9999, 0, 9999) })) == 0,
		"Near still applies to the alternative", "")
end)

runGroup("the pinned row", function()
	local w = storyWorld()
	local S = w.Reg.StoryQuestService
	local main = { Id = "M2_6", St = 1, P = 0, T = {}, Claim = false }
	local lo, lod = hero(w, 3, "Halo", 9, storyOf({ "M2_5" }, {}, main))
	local row = S.MainRow(lo, lod)
	check(row and row.Text == "Slime Princes" and row.Target == 2, "Lv9: the row names the Slime Prince only", show(row and { row.Text, row.Target }))
	local main2 = { Id = "M2_6", St = 1, P = 1, T = {}, Claim = false }
	local hi, hid = hero(w, 4, "Halo", 10, storyOf({ "M2_5" }, {}, main2))
	local row2 = S.MainRow(hi, hid)
	check(row2 and row2.Text == "Slime Princes or Goblin Brutes" and row2.Progress == 1 and row2.Target == 2, "Lv10: the row names both, progress kept", show(row2 and { row2.Text, row2.Progress, row2.Target }))
end)

runGroup("the kill fills the step", function()
	local w = storyWorld()
	local main = { Id = "M2_6", St = 1, P = 0, T = {}, Claim = false }
	local hi, hid = hero(w, 5, "Halo", 10, storyOf({ "M2_5" }, {}, main))
	local function kill(kind, zone)
		w.Reg.MonsterService.MonsterKilled:Fire(hi, { Kind = kind, ZoneId = zone, Position = vec(0, 0, 0), Personal = false })
		w:RunSpawned()
	end
	kill("GoblinBrute", "GoblinWoods")
	check(math.floor(hid.Story.Main.P) == 1 and hid.Story.Main.St == 1, "one Goblin Brute: 1/2", show(hid.Story.Main))
	kill("BigSlime", "SlimeMeadow")
	check(hid.Story.Main.Id ~= "M2_6" or hid.Story.Main.Claim == true or hid.Story.Done.M2_6 == true, "then a Slime Prince finishes it (2/2)", show(hid.Story.Main))
end)

runGroup("WB1: the lantern", function()
	local w = storyWorld()
	local function avail(p, d)
		local out = {}
		for _, e in w.Reg.StoryQuestService.BookRows(p, d).Available do table.insert(out, e.Id) end
		return table.concat(out, ",")
	end
	-- the book: before M1_4 nothing; after M1_4 it waits for Lv10; at Lv10 it is running
	local a, ad = hero(w, 6, "Halo", 10, storyOf({}))
	check(not string.find(avail(a, ad), "WB1", 1, true) and not (ad.Story.Subs.WB1), "before M1_4: not offered", avail(a, ad))
	local b, bd = hero(w, 7, "Halo", 9, storyOf({ "M1_4" }))
	check(not bd.Story.Subs.WB1, "Lv9: not started", show(bd.Story.Subs))
	local c, cd = hero(w, 8, "Halo", 10, storyOf({ "M1_4" }))
	w:Tick(2)
	check(cd.Story.Subs.WB1 ~= nil and cd.Story.Subs.WB1.St == 1, "Lv10 after M1_4: started at the bridge step", show(cd.Story.Subs))
	-- the pick: Halo takes A (Good)
	cd.Story.Subs.WB1 = { St = 2, P = 0, T = {} }
	w:Remote("StoryAction", c, "WB1", "Choose", "Good")
	check(cd.Items and cd.Items.Enh70 == 1 and cd.Story.Done.WB1 == true and cd.Story.Pick.WB1 == "Good", "Halo A: a 70% scroll, done, pick Good", show({ cd.Items, cd.Story.Pick, cd.Story.Done }))
	check(cd.Honor == 1, "Honor +1 (A23-58)", cd.Honor)
	-- Horns takes the same A: Infamy 0 stays 0, the scroll still comes
	local h, hd = hero(w, 9, "Horns", 10, storyOf({ "M1_4" }, { WB1 = { St = 2, P = 0, T = {} } }))
	w:Remote("StoryAction", h, "WB1", "Choose", "Good")
	check(hd.Items and hd.Items.Enh70 == 1 and (hd.Infamy or 0) == 0, "Horns A: the scroll, Infamy stays 0 (floor)", show({ hd.Items, hd.Infamy }))
	-- Horns takes B
	local h2, h2d = hero(w, 10, "Horns", 10, storyOf({ "M1_4" }, { WB1 = { St = 2, P = 0, T = {} } }))
	w:Remote("StoryAction", h2, "WB1", "Choose", "Evil")
	check((h2d.HPPotionCount or 0) == 3 and (h2d.BankGold or 0) >= 192 and h2d.Infamy == 1 and h2d.Story.Pick.WB1 == "Evil",
		"Horns B: 3 HP potions + 192 gold, Infamy +1, pick Evil", show({ h2d.HPPotionCount, h2d.BankGold, h2d.Infamy }))
	local src = {}
	for _, g in w.Gold do if g.P == h2 then table.insert(src, g.Src .. ":" .. g.N) end end
	check(table.concat(src, ",") == "Choice:192" or string.find(table.concat(src, ","), "Choice:192", 1, true) ~= nil, "the pick's gold is source 'Choice' (never 2x)", table.concat(src, ","))
	-- Neutral: A / B
	local n, nd = hero(w, 11, "Neutral", 10, storyOf({ "M1_4" }, { WB1 = { St = 2, P = 0, T = {} } }))
	w:Remote("StoryAction", n, "WB1", "Choose", "B")
	check((nd.HPPotionCount or 0) == 3 and (nd.Honor or 0) == 0 and (nd.Infamy or 0) == 0 and nd.Story.Pick.WB1 == "B", "Neutral B: the reward, no score", show({ nd.HPPotionCount, nd.Honor, nd.Infamy }))
	-- only once
	w:Remote("StoryAction", c, "WB1", "Choose", "Evil")
	check(cd.Items.Enh70 == 1 and (cd.HPPotionCount or 0) == 0, "a second pick pays nothing", show({ cd.Items, cd.HPPotionCount }))
	-- a wrong option is ignored and keeps the card
	local x, xd = hero(w, 12, "Halo", 10, storyOf({ "M1_4" }, { WB1 = { St = 2, P = 0, T = {} } }))
	w:Remote("StoryAction", x, "WB1", "Choose", "Neutral")
	w:Remote("StoryAction", x, "WB1", "Choose", "A")
	check(xd.Story.Subs.WB1 ~= nil and xd.Story.Subs.WB1.St == 2 and xd.Story.Done.WB1 == nil, "a wrong option for a Halo: ignored, the card stays", show(xd.Story.Subs))
end)

finish()
