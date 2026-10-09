-- quest_text_offline.luau : saved quest texts rebuilt in English at load (게임성 개발 3, 2026-10-08). tools/test_quest_text.py
-- binds CONFIG_SOURCE, UTIL_SOURCE and QUEST_EXTRACT (QuestService's template table, num, getLevel, isValidQuest,
-- questText, ensureSlots; newQuest stubbed) in front of dev2_kit.luau; this file follows.

local function load()
	local w = newWorld({})
	local made = {}
	local stub = function(_, kind) table.insert(made, kind); return { Id = "Kill", Kind = kind, Target = 5, Progress = 0,
		RewardGold = 1, RewardXP = 1, Text = "Defeat Slime ×5", Unit = "Slime" } end
	local Q = execute("QuestExtract", QUEST_EXTRACT, w:Env(), w.Config, w.Util, {}, stub)
	return w, Q, made
end

local function template(C, id)
	for _, t in C.Quests.Templates do if t.Id == id then return t end end
	return nil
end

local function hasKorean(s) return type(s) == "string" and string.find(s, "[\234-\237][\128-\191][\128-\191]") ~= nil end

local function quest(id, kind, target, extra)
	local q = { Id = id, Kind = kind or "Daily", Target = target, Progress = 0, RewardGold = 50, RewardXP = 80, Text = "옛 글" }
	for k, v in extra or {} do q[k] = v end
	return q
end

runGroup("old Korean texts", function()
	local w, Q = load()
	local C = w.Config
	local slots = C.Quests.Slots
	check(slots == 3, "three slots", slots)
	local data = { Level = 3, Quests = {
		quest("Plunder", "Daily", 1, { Text = "빛의 기사단 1명 털기", Progress = 0 }),
		-- Lv3's zone monster is Slime: a saved King Slime must stay King Slime
		quest("Kill", "Daily", 12, { Text = "킹 슬라임 12마리 처치", Progress = 7, Unit = "BigSlime", Strict = true }),
		quest("Gold", "Extra", 3200, { Text = "골드 3,200 벌기", Progress = 1000.5 }),
	} }
	Q.ensureSlots({}, data)
	local q1, q2, q3 = data.Quests[1], data.Quests[2], data.Quests[3]
	local king = C.MonsterTypes.BigSlime
	check(q1.Text == C.Plural(string.format(template(C, "Plunder").Text, 1)), "the Korean 'rob 1 Knight' daily: English again",
		tostring(q1.Text))
	check(q2.Text == C.Plural(string.format(template(C, "Kill").Text, tostring(king.Short or king.Name), 12)),
		"a kill daily names its saved monster", tostring(q2.Text))
	check(q3.Text == C.Plural(string.format(template(C, "Gold").Text, "3200")), "gold: the exact number", tostring(q3.Text))
	for i, q in data.Quests do
		check(not hasKorean(q.Text), "no Korean left in any slot", i .. " " .. tostring(q.Text))
	end
	check(q2.Progress == 7 and q2.Target == 12 and q2.RewardGold == 50 and q2.Unit == "BigSlime" and q2.Strict == true
		and q3.Progress == 1000.5 and q3.Kind == "Extra", "progress, target, rewards, the unit and the kind are kept",
		show({ q2.Progress, q2.Unit, q3.Kind }))
end)

runGroup("units and old fields", function()
	local w, Q, made = load()
	local C = w.Config
	local goblin = C.MonsterTypes[C.ZoneMainMonster[C.QuestZoneForLevel(12)]]
	local data = { Level = 12, Quests = {
		quest("Kill", "Daily", 30, { Text = "몬스터 30마리" }), -- saved before Unit existed
		quest("Golden", "Daily", 1, { Text = "황금 몬스터", Unit = "Nope" }), -- a unit that no longer exists
		quest("Release", "Daily", 2, { Text = "스킬 2번", MinStacks = 3 }),
	} }
	Q.ensureSlots({}, data)
	check(data.Quests[1].Text == C.Plural(string.format(template(C, "Kill").Text, tostring(goblin.Short or goblin.Name), 30)),
		"no saved unit: the level zone's main monster (the same rule killWeight uses)", tostring(data.Quests[1].Text))
	check(data.Quests[2].Text == C.Plural(string.format(template(C, "Golden").Text, tostring(goblin.Short or goblin.Name), 1)),
		"an unknown unit: the zone's main monster too", tostring(data.Quests[2].Text))
	check(data.Quests[3].MinStacks == nil and data.Quests[3].Text == C.Plural(string.format(template(C, "Release").Text, 2)),
		"Release: MinStacks dropped, English text", tostring(data.Quests[3].Text))
	check(not string.find(data.Quests[3].Text, "1 times", 1, true), "plural fixed", data.Quests[3].Text)
	check(#made == 0, "valid saved quests are kept (not remade)", #made)
	-- an invalid entry (unknown template) is still replaced the old way
	local d2 = { Level = 3, Quests = { quest("Nope", "Daily", 3), quest("Kill", "Daily", 5, { Unit = "Slime" }), "x" } }
	Q.ensureSlots({}, d2)
	check(#made == 2 and d2.Quests[1].Id == "Kill" and d2.Quests[3].Id == "Kill", "invalid entries become fresh quests", #made)
end)

runGroup("questText = newQuest's text", function()
	local w, Q = load()
	local C = w.Config
	local slime = C.MonsterTypes.Slime
	check(Q.questText(template(C, "Goose"), 1, "Slime") == C.Plural(string.format(template(C, "Goose").Text, 1)),
		"one goose tug: the plural rule", Q.questText(template(C, "Goose"), 1, "Slime"))
	check(Q.questText(template(C, "Kill"), 3, "Slime") == C.Plural(string.format(template(C, "Kill").Text, tostring(slime.Short or slime.Name), 3)),
		"kill text = (monster short name, count)", Q.questText(template(C, "Kill"), 3, "Slime"))
end)

finish()
