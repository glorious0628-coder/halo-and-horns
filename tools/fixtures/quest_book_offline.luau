-- quest_book_offline.luau : A23-81 quest window book (게임성 개발 3, 2026-10-08). tools/test_quest_book.py binds
-- CONFIG_SOURCE, UTIL_SOURCE and STORY_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows.
-- StoryQuestService runs from source (only Init: BookRows needs no loop); the save is the player's data table.

local NOON = 1789959600

local function bookWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	local env = w:Env()
	-- the goose-soon sub's visibility check looks for the GameState folder in the workspace first
	env.workspace = { GetServerTimeNow = function() return w.Time end, FindFirstChild = function()
		if o.VisibleError then error("offline workspace failure") end
		return w.GameState
	end }
	local story = execute("StoryQuestService", STORY_SOURCE, env)
	w.Reg.StoryQuestService = story
	story.Init(w.Reg)
	return w
end

local function hero(w, id, jo)
	jo = jo or {}
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 3, TutorialStep = 99 }
	for k, v in jo.Data or {} do data[k] = v end
	jo.Data = data
	return w:Arrive(id, jo)
end

local function storyOf(done, subs)
	local d = {}
	for _, id in done or {} do d[id] = true end
	return { Main = { Id = "" }, Subs = subs or {}, Done = d, Pick = {}, First = { Migrated = true } }
end

local function ids(list)
	local out = {}
	for _, e in list do table.insert(out, type(e) == "table" and e.Id or e) end
	return table.concat(out, ",")
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	check(C.QuestBook.DoneMax == 80 and C.QuestBook.AvailableMax == 10 and C.QuestBook.Text.OpensAt == "%s · Opens at Lv %d",
		"DoneMax 80, AvailableMax 10, 'Opens at Lv' text", show(C.QuestBook))
	check(#C.StoryQuests.Main + #C.StoryQuests.Subs <= C.QuestBook.DoneMax,
		"every main + every sub fits in Done (a finished save loses none)", tostring(#C.StoryQuests.Main + #C.StoryQuests.Subs))
end)

runGroup("done", function()
	local w = bookWorld()
	local B = w.Reg.StoryQuestService.BookRows
	local p, d = hero(w, 1, { Data = { Story = storyOf({ "M1_1", "M1_3", "S0", "Lunch1" }) } })
	local b = B(p, d)
	check(ids(b.Done) == "story:M1_3,story:M1_1,story:Lunch1,story:S0",
		"Done: finished mains newest first, then finished subs newest first, as 'story:<id>'", ids(b.Done))
	local all = {}
	for _, id in w.Config.StoryQuests.Main do table.insert(all, id) end
	for _, id in w.Config.StoryQuests.Subs do table.insert(all, id) end
	local q, dq = hero(w, 2, { Data = { Level = 30, Story = storyOf(all) } })
	local b2 = B(q, dq)
	check(#b2.Done == #all and b2.Done[1] == "story:M3_8" and b2.Done[#b2.Done] == "story:" .. w.Config.StoryQuests.Subs[1],
		"a finished save: every quest listed, the first sub too", tostring(#b2.Done) .. " " .. tostring(b2.Done[#b2.Done]))
	local wCap = bookWorld({ EditConfig = function(c) c.QuestBook.DoneMax = 5 end })
	local c, dc = hero(wCap, 9, { Data = { Level = 30, Story = storyOf(all) } })
	local bc = wCap.Reg.StoryQuestService.BookRows(c, dc)
	check(#bc.Done == 5 and bc.Done[1] == "story:M3_8", "DoneMax caps the list (the newest first)", tostring(#bc.Done))
	local r, dr = hero(w, 3, { Data = { Story = storyOf({ "M1_1", "Nope" }) } })
	check(ids(B(r, dr).Done) == "story:M1_1", "an unknown id in the save is not listed", ids(B(r, dr).Done))
end)

runGroup("available", function()
	local w = bookWorld()
	local B = w.Reg.StoryQuestService.BookRows
	-- after chapter 1 at Lv3 (Halo): S6 / XR1 (Lv5) and H2 (Lv8, Halo) wait for a level; S3 (no level) is ready; N1 (the
	-- artisan guild's) and R5 (Horns) are not this player's
	local p, d = hero(w, 1, { Data = { Level = 3, Story = storyOf({ "M1_1", "M1_3", "M1_4", "S0" }) } })
	local b = B(p, d)
	local byId = {}
	for _, e in b.Available do byId[e.Id] = e end
	check(byId["story:S6"] and byId["story:S6"].Level == 5 and byId["story:S6"].Kind == "Sub"
		and byId["story:S6"].Text == string.format("%s · Opens at Lv %d", w.Config.StoryQuests.Defs.S6.Title, 5),
		"a sub waiting for Lv5: Level 5 + 'Title · Opens at Lv 5'", show(byId["story:S6"]))
	check(byId["story:N1"] == nil and byId["story:R5"] == nil, "another side's sub (artisan N1, Horns R5): not listed", ids(b.Available))
	check(byId["story:H2"] and byId["story:H2"].Level == 8, "a sub waiting for Lv8", show(byId["story:H2"]))
	check(byId["story:S3"] and byId["story:S3"].Level == nil and byId["story:S3"].Text == nil,
		"a ready sub that has not started yet: listed without a level", show(byId["story:S3"]))
	check(byId["story:GW1"] == nil, "a sub that needs a quest not done yet (M2_7): not listed", "")
	check(byId["story:M2_1"] == nil, "no main is listed (the chain has no level gate)", "")
	check(b.Available[1].Level == nil or b.Available[1].Level <= (b.Available[#b.Available].Level or 0),
		"lowest level first", ids(b.Available))
	-- started or done subs are not available
	local q, dq = hero(w, 2, { Data = { Level = 3, Story = storyOf({ "M1_1", "M1_3", "M1_4", "S0", "S3" },
		{ S6 = { St = 1, P = 0, T = {}, Claim = false } }) } })
	local b2 = B(q, dq)
	local seen = {}
	for _, e in b2.Available do seen[e.Id] = true end
	check(not seen["story:S3"] and not seen["story:S6"], "done (S3) or started (S6): not listed", ids(b2.Available))
	-- Lv30 after chapter 2: only the subs above Lv30 wait (none) - the ready ones are listed until they start
	local r, dr = hero(w, 3, { Data = { Level = 30, Story = storyOf({ "M2_7" }) } })
	for _, e in B(r, dr).Available do
		check(e.Level == nil, "Lv30: nothing waits for a level any more", e.Id)
	end
	-- the read-only level view never changes the save
	check(dr.Level == 30 and d.Level == 3, "BookRows leaves the save's level alone", tostring(d.Level))
	-- AvailableMax
	local w2 = bookWorld({ EditConfig = function(c) c.QuestBook.AvailableMax = 2 end })
	local s, ds = hero(w2, 4, { Data = { Level = 3, Story = storyOf({ "M1_1", "M1_3", "M1_4", "S0" }) } })
	check(#w2.Reg.StoryQuestService.BookRows(s, ds).Available == 2, "at most AvailableMax", "")
	-- a hidden sub (found only by doing it) is never listed, even when ready
	local w3 = bookWorld({ EditConfig = function(c) c.StoryQuests.Defs.S3.Hidden = true end })
	local h, dh = hero(w3, 5, { Data = { Level = 3, Story = storyOf({ "M1_1", "M1_3", "M1_4", "S0" }) } })
	local seenH = {}
	for _, e in w3.Reg.StoryQuestService.BookRows(h, dh).Available do seenH[e.Id] = true end
	check(not seenH["story:S3"] and seenH["story:S6"], "a hidden ready sub stays hidden (the others still show)", "")
end)

runGroup("a failing visibility check", function()
	local w = bookWorld({ VisibleError = true })
	local p, d = hero(w, 1, { Data = { Level = 3, Story = storyOf({ "M1_1", "M1_3", "M1_4", "S0" }) } })
	local b = w.Reg.StoryQuestService.BookRows(p, d)
	local seen = {}
	for _, e in b.Available do seen[e.Id] = true end
	check(not seen["story:S1"] and seen["story:S6"] and seen["story:S3"],
		"the goose sub's check errors: that sub is left out, the book still lists the others", ids(b.Available))
end)

runGroup("faction and hidden", function()
	local w = bookWorld()
	local B = w.Reg.StoryQuestService.BookRows
	local defs = w.Config.StoryQuests.Defs
	local hidden, factional = {}, {}
	for _, id in w.Config.StoryQuests.Subs do
		if defs[id].Hidden then table.insert(hidden, id) end
		if defs[id].Factions then table.insert(factional, id) end
	end
	local all = { "M1_1", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7", "M3_4", "S0" }
	for _, side in { "Halo", "Horns" } do
		local p, d = hero(w, side == "Halo" and 1 or 2, { Data = { Faction = side, Level = 1, Story = storyOf(all) } })
		for _, e in B(p, d).Available do
			local id = string.sub(e.Id, 7)
			check(not table.find(hidden, id), "a hidden sub is never listed before it is found", e.Id)
			local f = defs[id].Factions
			check(f == nil or f[side] == true, "a faction-only sub is listed for its own side only", side .. " " .. e.Id)
		end
	end
end)

finish()
