-- next_goal_offline.luau : A23-86 F - the next-goal ladder (content_beyond_10min F, 게임성 개발 3, 2026-10-09).
-- tools/test_next_goal.py binds CONFIG_SOURCE, UTIL_SOURCE, QUEST_SOURCE and STORY_SOURCE in front of dev2_kit.luau +
-- dev3_world.luau; this file follows. QuestService (PinnedRow / tutorialEntry) and StoryQuestService (MainRow) run from
-- source in one world; the other services are the dev3_world doubles.

local NOON = 1789959600

local MAINS = { "M1_1", "M1_2", "M1_3", "M1_4", "M2_1", "M2_2", "M2_3", "M2_4", "M2_5", "M2_6", "M2_7",
	"M3_1", "M3_2", "M3_3", "M3_4", "M3_6", "M3_7", "M3_8" }

local function ladderWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local features = o.Features
	o.EditConfig = function(c)
		for k, v in features or {} do c.Features[k] = v end
	end
	local w = dev3World(o)
	local env = w:Env()
	env.workspace = { GetServerTimeNow = function() return w.Time end, FindFirstChild = function() return w.GameState end }
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	w.Reg.PlayerService.CharacterSpawned = w.Util.Signal.new()
	w.Reg.ProgressionService.LevelReset = w.Util.Signal.new()
	w.Reg.KaijuService = { KaijuEnded = w.Util.Signal.new() }
	w.Reg.FactionService.GetFaction = function(p) return p:GetAttribute("Faction") or "None" end
	w.Reg.PvPService = { IsRookie = function() return false end, PlayerKO = w.Util.Signal.new() }
	-- Codex B5: the field boss double (KingWait = seconds until the King Slime; 0 = here, nil = off)
	w.KingWait = 0
	w.Reg.FieldBossService = { SecondsUntil = function(key) return key == "SlimeKing" and w.KingWait or nil end }
	local story = execute("StoryQuestService", STORY_SOURCE, env)
	w.Reg.StoryQuestService = story
	local quest = execute("QuestService", QUEST_SOURCE, env)
	w.Reg.QuestService = quest
	story.Init(w.Reg)
	quest.Init(w.Reg)
	return w
end

local function storyDone(through)
	local d = {}
	for _, id in MAINS do
		d[id] = true
		if id == through then break end
	end
	return { Main = { Id = "" }, Subs = {}, Done = d, Pick = {}, First = { Migrated = true } }
end

-- a save past the early goals: iron weapon owned, three skills, the first mission and the forge visit done
local function veteran(w, id, faction, level, extra)
	local data = { Faction = faction, Class = "Warrior", ClassChosen = true, Level = level, TutorialStep = 99, BlacksmithVisited = true,
		WeaponTier = 3, WeaponOwnedMask = 7, SkillSlots = 3, Rebirths = 0, Story = storyDone("M3_8"), CarriedGold = 5000 }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local T = C.Tutorial
	local ladder = T.Ladder
	check(#ladder.Hooks == 3 and ladder.Hooks[1].Kind == "Commission" and ladder.Hooks[2].Kind == "Clatter" and ladder.Hooks[3].Kind == "Crystal",
		"hooks in order: golden weapon, Captain Clatter, crystal weapon", show(ladder.Hooks))
	for _, h in ladder.Hooks do
		check(not C.FeatureOn(h.Feature), h.Kind .. ": switched off until its feature exists", tostring(C.Features[h.Feature]))
		check(type(T.ShortNames[h.Kind]) == "string" and #T.ShortNames[h.Kind] <= 14, h.Kind .. ": a short name <= 14", tostring(T.ShortNames[h.Kind]))
	end
	check(ladder.Rebirth.Warn == 5, "the rebirth line starts 5 levels before", show(ladder.Rebirth))
	check(T.Text.NextRebirth == "Next goal · Lv%d: Rebirth and start again (now Lv%d)" and T.Text.NextRebirthReady == "Next goal · Rebirth is open! Choose your side again",
		"rebirth lines", show({ T.Text.NextRebirth, T.Text.NextRebirthReady }))
	check(T.Text.RebirthNoteHalo == "Stay a knight, or not?" and T.Text.RebirthNoteHorns == "Stay a rascal, or not?", "the side questions", "")
	check(T.ShortNames.Rebirth == "Rebirth Lv %d" and T.ShortNames.RebirthReady == "Rebirth ready" and #string.format(T.ShortNames.Rebirth, 100) <= 14, "rebirth short names", "")
	check(C.Return.GoalZones.Rebirth == "Crossroads" and C.Return.GoalZones.RebirthReady == "Crossroads", "the pause card leads a rebirth goal to the Crossroads", show(C.Return.GoalZones))
	check(C.StoryQuests.Defs.M3_8.Finish == "Chapter 4 is coming!", "M3_8 closes with 'Chapter 4 is coming!'", tostring(C.StoryQuests.Defs.M3_8.Finish))
	local all = ""
	for _, v in T.Text do all ..= tostring(v) .. "|" end
	check(not string.find(T.Text.NextRebirth, "min", 1, true) and not string.find(T.Text.NextRebirthReady, ":", 1, true), "no clock or minute in the rebirth lines", "")
	check(not string.find(show(ladder), "[\234-\237][\128-\191][\128-\191]"), "English only", "")
end)

runGroup("the rebirth rung", function()
	local w = ladderWorld()
	local Q = w.Reg.QuestService
	local C = w.Config
	local p, d = veteran(w, 1, "Halo", 47)
	local row = Q.PinnedRow(p)
	check(row and row.Text == "Next goal · Lv50: Rebirth and start again (now Lv47)" and row.GoalKind == "Rebirth" and row.NextGoal == true,
		"Lv47 (Halo): the rebirth goal with the level", show(row and { row.Text, row.GoalKind }))
	check(row and row.ShortName == "Rebirth Lv 50" and row.GoalNote == "Stay a knight, or not?", "short name + the knight question", show(row and { row.ShortName, row.GoalNote }))
	check(row and row.Pinned == true and row.CanClaim == false and row.RewardGold == 0 and row.RewardXP == 0, "no reward, no claim", show(row))
	d.Level = 50
	local ready = Q.PinnedRow(p)
	check(ready and ready.GoalKind == "RebirthReady" and ready.Text == "Next goal · Rebirth is open! Choose your side again" and ready.ShortName == "Rebirth ready",
		"Lv50: 'Rebirth is open' (short: Rebirth ready)", show(ready and { ready.Text, ready.GoalKind, ready.ShortName }))
	d.Level = 99
	check(Q.PinnedRow(p) and Q.PinnedRow(p).GoalKind == "RebirthReady", "and it stays open above Lv50", "")
	d.Level = 44
	check(Q.PinnedRow(p) == nil, "Lv44: nothing yet (five levels before)", show(Q.PinnedRow(p)))
	d.Level = 45
	check(Q.PinnedRow(p) and Q.PinnedRow(p).GoalKind == "Rebirth", "Lv45: the line starts", "")
	-- Horns
	local h, hd = veteran(w, 2, "Horns", 48)
	local hr = Q.PinnedRow(h)
	check(hr and hr.GoalNote == "Stay a rascal, or not?", "Horns: the rascal question", show(hr and hr.GoalNote))
	-- Neutral: the row without a question
	local n, nd = veteran(w, 3, "Neutral", 48)
	local nr = Q.PinnedRow(n)
	check(nr and nr.GoalKind == "Rebirth" and nr.GoalNote == nil, "Neutral: the goal, no side question", show(nr and { nr.GoalKind, nr.GoalNote }))
	-- after a rebirth the level asked goes up by 5 (Config.RebirthLevel)
	local r, rd = veteran(w, 4, "Halo", 52, { Rebirths = 1 })
	local rr = Q.PinnedRow(r)
	check(rr and rr.GoalKind == "Rebirth" and string.find(rr.Text, "Lv" .. C.RebirthLevel(1) .. ":", 1, true) ~= nil, "second rebirth: Lv55 asked", show(rr and rr.Text))
	local capped, cd = veteran(w, 5, "Halo", 99, { Rebirths = 20 })
	check(Q.PinnedRow(capped) and Q.PinnedRow(capped).GoalKind == "Rebirth" and string.find(Q.PinnedRow(capped).Text, "Lv100:", 1, true) ~= nil,
		"a high rebirth count: the level cap (100) applies", show(Q.PinnedRow(capped) and Q.PinnedRow(capped).Text))
end)

runGroup("which levels show what", function()
	local w = ladderWorld()
	local Q = w.Reg.QuestService
	local p, d = veteran(w, 6, "Halo", 1)
	local blank, shown = {}, {}
	for level = 1, 100 do
		d.Level = level
		local row = Q.PinnedRow(p)
		if level >= 25 or level <= 9 then -- Lv10-24 cannot hold a save that finished every chapter (M3_8 asks Lv25)
			if row == nil then table.insert(blank, level) else shown[level] = row.GoalKind or row.Id end
		end
	end
	-- Lv1..9: the woods goal does not apply to a finished story save? (the early goals come from the save, not the story)
	local gaps = {}
	local run0
	for i, lv in blank do
		if i == 1 or lv ~= blank[i - 1] + 1 then
			run0 = { lv, lv }
			table.insert(gaps, run0)
		else
			run0[2] = lv
		end
	end
	local text = {}
	for _, g in gaps do table.insert(text, g[1] .. "-" .. g[2]) end
	check(#gaps == 1 and gaps[1][1] == 25 and gaps[1][2] == 44,
		"Lv25-44 is the blank stretch of a veteran with all chapters done (the Commission / Clatter / Crystal rows fill it when built)", table.concat(text, ","))
	local early = {}
	for lv = 1, 9 do if shown[lv] == nil then table.insert(early, lv) end end
	check(#early == 0, "Lv1-9 always shows a goal (the woods row)", table.concat(early, ","))
end)

runGroup("feature hooks", function()
	local w = ladderWorld({ Features = { Commission = true, Clatter = true, Crystal = true } })
	local Q = w.Reg.QuestService
	local p, d = veteran(w, 7, "Halo", 30)
	check(Q.PinnedRow(p) == nil, "switches on, no service yet: nothing", show(Q.PinnedRow(p)))
	w.Reg.CrystalService = { NextGoal = function() return "Next goal · Crystal weapon: Knight Crests 4/12" end }
	check(Q.PinnedRow(p) and Q.PinnedRow(p).GoalKind == "Crystal" and Q.PinnedRow(p).ShortName == "Crystal weapon", "a crystal service answers", show(Q.PinnedRow(p)))
	w.Reg.ClatterService = { NextGoal = function() return "Next goal · Captain Clatter: a Badge is waiting" end }
	check(Q.PinnedRow(p).GoalKind == "Clatter", "Clatter comes before the crystal weapon", show(Q.PinnedRow(p).GoalKind))
	w.Reg.CommissionService = { NextGoal = function() return "Next goal · Golden weapon: Brute Horns 6/10" end }
	check(Q.PinnedRow(p).GoalKind == "Commission" and Q.PinnedRow(p).ShortName == "Weapon order", "the golden weapon comes first", show(Q.PinnedRow(p).GoalKind))
	w.Reg.CommissionService.NextGoal = function() return nil end
	check(Q.PinnedRow(p).GoalKind == "Clatter", "a service with nothing to say is skipped", "")
	w.Reg.ClatterService.NextGoal = function() error("offline service failure") end
	check(Q.PinnedRow(p).GoalKind == "Crystal", "a service that errors is skipped", "")
	w.Reg.CrystalService.NextGoal = function() return "" end
	check(Q.PinnedRow(p) == nil, "an empty line is skipped", show(Q.PinnedRow(p)))
	d.Level = 48
	check(Q.PinnedRow(p) and Q.PinnedRow(p).GoalKind == "Rebirth", "and the rebirth line comes last", "")
	-- switches off again
	local w2 = ladderWorld({ Features = { Clatter = false } })
	w2.Reg.ClatterService = { NextGoal = function() return "Next goal · Captain Clatter: a Badge is waiting" end }
	local q, qd = veteran(w2, 8, "Halo", 30)
	check(w2.Reg.QuestService.PinnedRow(q) == nil, "the switch off: the hook is never asked", "")
end)

runGroup("the early goals and the story keep their place", function()
	local w = ladderWorld({ Features = { Clatter = true } })
	local Q = w.Reg.QuestService
	w.Reg.ClatterService = { NextGoal = function() return "Next goal · Captain Clatter: a Badge is waiting" end }
	-- no iron weapon yet: the iron rows first. Gameplay plan 2026-10-13 1-A #2: the Forge sells no weapon (Buy = false), so
	-- the iron goal is the drop line (Tutorial.Text.NextIronDrop, 게임성 개발 1's text: set here when this branch has none);
	-- with no such line there is no iron row (never the gold one); Buy = true = the old gold row
	local TT = w.Config.Tutorial.Text
	local dropText = TT.NextIronDrop
	TT.NextIronDrop = dropText or "Next goal · Beat a King Slime for an Iron weapon"
	local a, ad = veteran(w, 9, "Halo", 20, { WeaponTier = 1, WeaponOwnedMask = 1, CarriedGold = 10 })
	check(w.Config.WeaponShop.Buy == false and Q.PinnedRow(a).GoalKind == "IronDrop" and Q.PinnedRow(a).Text == TT.NextIronDrop,
		"no iron weapon: the iron goal first (the drop line)", show(Q.PinnedRow(a).GoalKind))
	-- Codex B5 (최종 검수 10/14): no King for more than KingSoon (120 s), or none at all: another goal comes first
	w.KingWait = 121
	check(Q.PinnedRow(a).GoalKind ~= "IronDrop", "the King 121 s away: no King line", show(Q.PinnedRow(a).GoalKind))
	w.KingWait = nil
	check(Q.PinnedRow(a).GoalKind ~= "IronDrop", "no King on this server: no King line", show(Q.PinnedRow(a).GoalKind))
	w.KingWait = 120
	check(Q.PinnedRow(a).GoalKind == "IronDrop" and w.Config.Tutorial.KingSoon == 120, "the King 120 s away: the line again", show(Q.PinnedRow(a).GoalKind))
	w.KingWait = 0
	TT.NextIronDrop = nil
	check(Q.PinnedRow(a).GoalKind ~= "IronGold" and Q.PinnedRow(a).GoalKind ~= "IronDrop", "no drop line: no iron row, never the gold one",
		show(Q.PinnedRow(a).GoalKind))
	w.Config.WeaponShop.Buy = true
	check(Q.PinnedRow(a).GoalKind == "IronGold", "Buy switched back on: the gold row", show(Q.PinnedRow(a).GoalKind))
	w.Config.WeaponShop.Buy = false
	TT.NextIronDrop = dropText or "Next goal · Beat a King Slime for an Iron weapon"
	-- a pending skill
	local b, bd = veteran(w, 10, "Halo", 3, { SkillSlots = 0 })
	check(Q.PinnedRow(b).GoalKind == "Skill", "a pending skill is before the ladder", show(Q.PinnedRow(b).GoalKind))
	-- the zone goal at low level
	local c, cd = veteran(w, 11, "Halo", 5)
	check(Q.PinnedRow(c).GoalKind ~= "Clatter", "the woods goal is before the ladder", show(Q.PinnedRow(c).GoalKind))
	-- a story row is pinned instead of the ladder
	local m, md = veteran(w, 12, "Halo", 47, { Story = { Main = { Id = "M3_7", St = 1, P = 0, T = {}, Claim = false }, Subs = {}, Done = storyDone("M3_6").Done, Pick = {}, First = { Migrated = true } } })
	local mr = Q.PinnedRow(m)
	check(mr and mr.Pinned == true and mr.NextGoal ~= true and mr.Id == "story:M3_7", "a story main row wins over the ladder", show(mr and { mr.Id, mr.NextGoal }))
	-- not yet past the forge visit: the forge row
	local f, fd = veteran(w, 13, "Halo", 47, { BlacksmithVisited = false })
	check(Q.PinnedRow(f).NextGoal ~= true or Q.PinnedRow(f).GoalKind == nil, "before the forge visit: the forge row, not the ladder", show(Q.PinnedRow(f).Text))
end)

finish()
