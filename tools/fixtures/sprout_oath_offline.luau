-- sprout_oath_offline.luau : A23-86 Sprout Oath + graduation side line (content_beyond_10min G, 게임성 개발 3, 2026-10-09).
-- tools/test_sprout_oath.py binds CONFIG_SOURCE, UTIL_SOURCE and STORY_SOURCE in front of dev2_kit.luau + dev3_world.luau;
-- this file follows. StoryQuestService runs from source (Init + Start, hand-stepped loops); PvPService.IsRookie and
-- TitleService.Grant are small doubles here.

local NOON = 1789959600

local function oathWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	w.NotRookie = {} -- [UserId] = true once the Sprout Shield is over
	w.Titles = {}
	w.Reg.PvPService = { IsRookie = function(p) return w.NotRookie[p.UserId] ~= true end }
	w.Reg.TitleService = { Grant = function(p, id)
		table.insert(w.Titles, { P = p, Id = id })
		return true
	end }
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

local function hero(w, id, faction, level, story, extra)
	local data = { Faction = faction, Class = "Warrior", ClassChosen = true, Level = level, TutorialStep = 99, Story = story }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function storyOf(done, subs, main)
	local d = {}
	for _, id in done or {} do d[id] = true end
	return { Main = main or { Id = "" }, Subs = subs or {}, Done = d, Pick = {}, First = { Migrated = true } }
end

local function done(list, ...)
	local out = {}
	for _, id in list do table.insert(out, id) end
	for _, id in { ... } do table.insert(out, id) end
	return out
end

local function titlesOf(w, p)
	local out = {}
	for _, t in w.Titles do if t.P == p then table.insert(out, t.Id) end end
	return table.concat(out, ",")
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local sq = C.StoryQuests
	local main = table.concat(sq.Main, ",")
	check(not string.find(main, "M3_5", 1, true) and string.find(main, "M3_4,M3_6", 1, true) ~= nil,
		"the main chain goes M3_4 -> M3_6 (M3_5 is a side line)", main)
	local g = sq.Defs.M3_5
	check(g.Kind == "Sub" and g.Requires.Done[1] == "M3_4" and g.Steps[1].Obj.Key == "Graduated" and g.Steps[2].Obj.Type == "Talk",
		"M3_5 is a sub: wait for Graduated, then the Guide's talk (the same two steps)", show(g.Requires))
	check(g.Steps[1].Text == "Sprout Shield on · ends at Lv15 + 1 hour of play", "its row text", g.Steps[1].Text)
	check(not string.find(g.Steps[1].Text, "min", 1, true) and not string.find(g.Steps[1].Text, ":", 1, true) and not string.find(g.Steps[1].Text, "%%d"), "no minute count or clock in the shield row", g.Steps[1].Text)
	local count = { M3_5 = 0, OathH = 0, OathR = 0 }
	for _, id in sq.Subs do if count[id] then count[id] += 1 end end
	check(count.M3_5 == 1 and count.OathH == 1 and count.OathR == 1, "M3_5 / OathH / OathR listed once each", show(count))
	check(sq.SkipChapters[2].Level == 25 and sq.SkipChapters[2].Subs[1] == "M3_5", "an old Lv25+ save skips M3_5 too", show(sq.SkipChapters))
	for _, id in { "OathH", "OathR" } do
		local d = sq.Defs[id]
		check(d.Kind == "Sub" and d.Requires.Done[1] == "M3_4" and d.Requires.Level == 15 and d.Requires.Sprout == true,
			id .. ": after M3_4, Lv15, while a sprout", show(d.Requires))
		local last = d.Steps[#d.Steps]
		check(last.Panel == true and last.Obj.Type == "Choice" and last.Obj.Good.Points == 2 and last.Obj.Evil.Points == 2
			and last.Obj.Good.Label == "I'll guard the small ones" and last.Obj.Evil.Label == "Rascals bow to no one!",
			id .. ": ends with the oath card, 2 points each way", show(last.Obj))
		check(d.Reward.TitleBy.Good == "GuardianCadet" and d.Reward.TitleBy.Evil == "RascalCadet" and d.Reward.GoldN == 120
			and d.Reward.XPBar == 0.5, id .. ": stat-free titles by the pick, the town-sub reward size", show(d.Reward))
		check(d.Finish == "Oath sworn! Your Sprout Shield ends after 1 hour of play.", id .. ": the closing line", d.Finish)
		check(not string.find(show(d), "[\234-\237][\128-\191][\128-\191]"), id .. ": English only", "")
	end
	local h, r = sq.Defs.OathH, sq.Defs.OathR
	check(h.Factions.Halo == true and h.Factions.Horns == nil and r.Factions.Horns == true and r.Factions.Halo == nil,
		"one oath per side", show({ h.Factions, r.Factions }))
	check(h.Steps[1].Npc == "Bright" and h.Steps[4].Npc == "Bright" and r.Steps[1].Npc == "Smokey" and r.Steps[5].Npc == "Smokey",
		"Bright (Halo) / Smokey (Horns) open and close it", "")
	check(h.Steps[2].Obj.Spot == "WoodsGate" and h.Steps[2].Obj.Stay == 15 and h.Steps[3].Obj.Kind == "GoblinBrute" and h.Steps[3].Obj.Count == 1,
		"Halo: guard the woods bridge 15 s, one Goblin Brute", show({ h.Steps[2].Obj, h.Steps[3].Obj }))
	check(r.Steps[2].Obj.Spot == "GoblinCamp1" and r.Steps[3].Obj.Spot == "GoblinCamp2" and r.Steps[4].Obj.Type == "BasicKill"
		and r.Steps[4].Obj.Kind == "GoblinBrute" and r.Steps[4].Obj.Count == 1, "Horns: two goblin camps, one Goblin Brute with basic hits",
		show({ r.Steps[2].Obj, r.Steps[3].Obj, r.Steps[4].Obj }))
	check(sq.Landmarks.GoblinCamp1 ~= nil and sq.Landmarks.GoblinCamp2 ~= nil and sq.Landmarks.WoodsGate ~= nil, "the landmarks exist", "")
	for _, t in { "GuardianCadet", "RascalCadet" } do
		check(C.TitleDefs[t] ~= nil and table.find(C.TitleOrder, t) ~= nil, "title " .. t .. " defined and pickable", show(C.TitleOrder))
	end
	check(C.TitleDefs.GuardianCadet.Name == "Guardian Cadet" and C.TitleDefs.RascalCadet.Name == "Rascal Cadet", "title names", "")
	check(table.find(C.TitleOrder, "BetaPioneer") == 1, "older titles keep their place", show(C.TitleOrder))
	check(#sq.Main + #sq.Subs <= C.QuestBook.DoneMax, "every main + sub still fits in the book's Done", #sq.Main + #sq.Subs)
end)

runGroup("the main chain skips M3_5", function()
	local w = oathWorld()
	local p, d = hero(w, 1, "Halo", 14, storyOf({ "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7", "M3_1", "M3_2", "M3_3", "M3_4" }))
	w:Tick(2)
	check(d.Story.Main.Id == "M3_6", "after M3_4 the main quest is M3_6", show(d.Story.Main))
	check(d.Story.Subs.M3_5 ~= nil and d.Story.Subs.M3_5.St == 1, "and the graduation line runs beside it (step 1)", show(d.Story.Subs))
	check(d.Story.Subs.OathH == nil, "no oath below Lv15", show(d.Story.Subs))
end)

runGroup("graduation as a side line", function()
	local w = oathWorld()
	local pre = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7", "M3_1", "M3_2", "M3_3", "M3_4" }
	local p, d = hero(w, 2, "Horns", 16, storyOf(pre))
	w:Tick(2)
	check(d.Story.Subs.M3_5 and d.Story.Subs.M3_5.St == 1, "waits while the shield is on", show(d.Story.Subs.M3_5))
	w.NotRookie[p.UserId] = true
	w:Tick(2)
	check(d.Story.Subs.M3_5 and d.Story.Subs.M3_5.St == 2, "graduated: step 2 (the Guide's talk)", show(d.Story.Subs.M3_5))
	w:Remote("StoryAction", p, "M3_5", "Talk")
	check(d.Story.Done.M3_5 == true and d.Story.Subs.M3_5 == nil, "the talk finishes it", show({ d.Story.Done, d.Story.Subs }))
	-- the main quest never waited for it
	check(d.Story.Main.Id == "M3_6", "meanwhile M3_6 ran", show(d.Story.Main))
	-- migration: an in-progress saved main M3_5
	local old = storyOf(pre, {}, { Id = "M3_5", St = 2, P = 0, T = {}, Claim = false })
	local q, qd = hero(w, 3, "Halo", 20, old)
	w:Tick(2)
	check(qd.Story.Subs.M3_5 and qd.Story.Subs.M3_5.St == 2 and qd.Story.Main.Id == "M3_6", "a saved main M3_5 (step 2) moves to the side lines and M3_6 starts", show({ qd.Story.Subs, qd.Story.Main }))
	local old1 = storyOf(pre, {}, { Id = "M3_5", St = 1, P = 0, T = {}, Claim = false })
	local q1, q1d = hero(w, 4, "Halo", 16, old1)
	w:Tick(2)
	check(q1d.Story.Subs.M3_5 and q1d.Story.Subs.M3_5.St == 1, "step 1 moves too (still waiting)", show(q1d.Story.Subs))
	-- both a saved main M3_5 and a sub M3_5 (a half-migrated save): the sub that is already there wins
	local both = storyOf(pre, { M3_5 = { St = 1, P = 0, T = {}, Claim = false } }, { Id = "M3_5", St = 2, P = 0, T = {}, Claim = false })
	local b, bd = hero(w, 8, "Halo", 16, both)
	w:Tick(2)
	check(bd.Story.Subs.M3_5 and bd.Story.Subs.M3_5.St == 1 and bd.Story.Main.Id == "M3_6", "a sub that exists is not overwritten by the old main", show(bd.Story.Subs.M3_5))
	-- a saved M3_5 that is already Done as a main
	local fin = storyOf(done(pre, "M3_5", "M3_6"))
	local f, fd = hero(w, 5, "Halo", 30, fin)
	w:Tick(2)
	check(fd.Story.Done.M3_5 == true and fd.Story.Subs.M3_5 == nil, "an old finished M3_5 stays finished", show(fd.Story.Subs))
	-- an old save with nothing yet at Lv25+: the skip covers M3_5; Lv10-24: only chapters 1-2
	local s25, s25d = hero(w, 6, "Halo", 26, { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = {} })
	w:Tick(2)
	check(s25d.Story.Done.M3_5 == true and s25d.Story.Done.M3_4 == true, "Lv26 old save: chapters 1-3 and M3_5 skipped", show(s25d.Story.Done))
	check(s25d.Story.Subs.M3_5 == nil, "no graduation line starts for it", show(s25d.Story.Subs))
	local s12, s12d = hero(w, 7, "Halo", 12, { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = {} })
	w:Tick(2)
	check(s12d.Story.Done.M3_5 ~= true and s12d.Story.Done.M2_7 == true, "Lv12 old save: chapter 3 and M3_5 are still ahead", show(s12d.Story.Done))
end)

runGroup("who gets an oath", function()
	local w = oathWorld()
	local pre = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7", "M3_1", "M3_2", "M3_3", "M3_4" }
	local function sub(p, d, id) w:Tick(2) return d.Story.Subs[id] end
	local h, hd = hero(w, 10, "Halo", 15, storyOf(pre))
	check(sub(h, hd, "OathH") and sub(h, hd, "OathH").St == 1 and not sub(h, hd, "OathR"), "Halo Lv15 sprout: OathH only", show(hd.Story.Subs))
	local r, rd = hero(w, 11, "Horns", 15, storyOf(pre))
	check(sub(r, rd, "OathR") and sub(r, rd, "OathR").St == 1 and not sub(r, rd, "OathH"), "Horns Lv15 sprout: OathR only", show(rd.Story.Subs))
	local lo, lod = hero(w, 12, "Halo", 14, storyOf(pre))
	check(not sub(lo, lod, "OathH"), "Lv14: no oath yet", "")
	lod.Level = 15
	lo:SetAttribute("Level", 15)
	check(sub(lo, lod, "OathH") ~= nil, "at Lv15 it starts", show(lod.Story.Subs))
	local early, ed = hero(w, 13, "Halo", 15, storyOf({ "M1_1", "M1_2", "M1_3", "M1_4" }))
	check(not sub(early, ed, "OathH"), "without M3_4: no oath", "")
	w.NotRookie[14] = true
	local grad, gd = hero(w, 14, "Halo", 20, storyOf(pre))
	check(not sub(grad, gd, "OathH") and gd.Story.Subs.OathH == nil, "already graduated: no oath", show(gd.Story.Subs))
	local n, nd = hero(w, 15, "Neutral", 15, storyOf(pre))
	check(not sub(n, nd, "OathH") and nd.Story.Subs.OathR == nil, "Neutral: no oath (the guild has its own graduation lines)", show(nd.Story.Subs))
	-- the oath keeps running when the shield ends meanwhile
	hd.Story.Subs.OathH.St = 3
	w.NotRookie[h.UserId] = true
	w:Tick(2)
	check(hd.Story.Subs.OathH ~= nil and hd.Story.Subs.OathH.St == 3, "a running oath is not cancelled by graduating", show(hd.Story.Subs.OathH))
	-- once: done is not started again
	local dn, dnd = hero(w, 16, "Halo", 15, storyOf(done(pre, "OathH")))
	check(not sub(dn, dnd, "OathH"), "a finished oath never restarts", "")
end)

runGroup("OathH: kill, then the oath", function()
	local w = oathWorld()
	local pre = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7", "M3_1", "M3_2", "M3_3", "M3_4" }
	local p, d = hero(w, 20, "Halo", 15, storyOf(pre, { OathH = { St = 3, P = 0, T = {}, Claim = false } }), { Honor = 5 })
	local function kill(kind, zone, extra)
		local info = { Kind = kind, ZoneId = zone, Position = vec(0, 0, 0), Personal = false }
		for k, v in extra or {} do info[k] = v end
		w.Reg.MonsterService.MonsterKilled:Fire(p, info)
		w:RunSpawned()
	end
	kill("Goblin", "GoblinWoods")
	kill("GoblinBrute", "SlimeMeadow")
	check(d.Story.Subs.OathH.St == 3, "a plain goblin or a brute in the wrong zone: no", show(d.Story.Subs.OathH))
	kill("GoblinBrute", "GoblinWoods")
	check(d.Story.Subs.OathH.St == 4, "a Goblin Brute in the woods: on to the oath", show(d.Story.Subs.OathH))
	w:Remote("StoryAction", p, "OathH", "Choose", "Good")
	check(d.Story.Done.OathH == true and d.Honor == 7 and d.Story.Pick.OathH == "Good", "oath A: Honor +2, done", show({ d.Honor, d.Story.Done }))
	check(titlesOf(w, p) == "GuardianCadet", "title Guardian Cadet", titlesOf(w, p))
	check((d.BankGold or 0) > 0, "the town-sub gold is paid", d.BankGold)
	-- the other pick
	local q, qd = hero(w, 21, "Halo", 15, storyOf(pre, { OathH = { St = 4, P = 0, T = {}, Claim = false } }), { Honor = 5 })
	w:Remote("StoryAction", q, "OathH", "Choose", "Evil")
	check(qd.Honor == 3 and titlesOf(w, q) == "RascalCadet" and qd.Story.Pick.OathH == "Evil", "oath B for a Halo: Honor -2 (A23-58), Rascal Cadet", show({ qd.Honor, titlesOf(w, q) }))
	local z, zd = hero(w, 22, "Halo", 15, storyOf(pre, { OathH = { St = 4, P = 0, T = {}, Claim = false } }), { Honor = 1 })
	w:Remote("StoryAction", z, "OathH", "Choose", "Evil")
	check(zd.Honor == 0, "oath B at Honor 1: floor 0", zd.Honor)
end)

runGroup("OathR: basic hits, then the oath", function()
	local w = oathWorld()
	local pre = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7", "M3_1", "M3_2", "M3_3", "M3_4" }
	local p, d = hero(w, 30, "Horns", 15, storyOf(pre, { OathR = { St = 4, P = 0, T = {}, Claim = false } }), { Infamy = 3 })
	local function kill(extra)
		local info = { Kind = "GoblinBrute", ZoneId = "GoblinWoods", Position = vec(0, 0, 0), Personal = false }
		for k, v in extra or {} do info[k] = v end
		w.Reg.MonsterService.MonsterKilled:Fire(p, info)
		w:RunSpawned()
	end
	kill({ SkillHit = true })
	check(d.Story.Subs.OathR.St == 4, "a kill with a skill does not count", show(d.Story.Subs.OathR))
	kill({})
	check(d.Story.Subs.OathR.St == 5, "a basic-hit kill: on to the oath", show(d.Story.Subs.OathR))
	w:Remote("StoryAction", p, "OathR", "Choose", "Evil")
	check(d.Story.Done.OathR == true and d.Infamy == 5 and titlesOf(w, p) == "RascalCadet", "oath B: Infamy +2, Rascal Cadet", show({ d.Infamy, titlesOf(w, p) }))
	local q, qd = hero(w, 31, "Horns", 15, storyOf(pre, { OathR = { St = 5, P = 0, T = {}, Claim = false } }), { Infamy = 6 })
	w:Remote("StoryAction", q, "OathR", "Choose", "Good")
	check(qd.Infamy == 4 and titlesOf(w, q) == "GuardianCadet", "oath A for a Horn: Infamy -2 (A23-58), Guardian Cadet", show({ qd.Infamy, titlesOf(w, q) }))
end)

finish()
