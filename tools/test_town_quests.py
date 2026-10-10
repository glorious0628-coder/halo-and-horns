"""A23-46 town people sub quests H1 / R1 / N3 + A23-57 artisan guild switch, offline.

Runs the CURRENT StoryQuestService, LootService, CombatService (+ the sources tools/test_unarmed_start.py binds) on
tools/fixtures/dev2_combat_world.luau with tools/fixtures/town_quests_offline.luau, plus extracts of FactionService
(picker / altar validation) and ProgressionService.TryRebirth, with the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_town_quests.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_dev2_town_quests_2026-10-06.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SSS, Suite, function_block, read, run
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
FILES["FACTION_SOURCE"] = SSS / "FactionService.luau"
FILES["PROGRESSION_SOURCE"] = SSS / "ProgressionService.luau"
C, ST, L, F, PR = "CONFIG_SOURCE", "STORY_SOURCE", "LOOT_SOURCE", "FACTION_SOURCE", "PROGRESSION_SOURCE"
U = "UTIL_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    faction = sources[F]
    out["FACTION_EXTRACT"] = (
        "local Config, Util, S, FactionService, nearAltar = ...\nlocal TAG = \"FactionService\"\n"
        "local WARN_THROTTLE = 10\nlocal lastWarnAt = {}\nlocal Net = { Notify = function() end }\n"
        + function_block(faction, "local function warnThrottled(")
        + function_block(faction, "local function isPlayable(")
        + function_block(faction, "local function logNeutralRefused(")
        + function_block(faction, "local function notify(")
        + function_block(faction, "local function parseSwitchArgs(")
        + function_block(faction, "local function onChooseFaction(")
        + function_block(faction, "local function onSwitchFaction(")
        + "\nreturn { Choose = onChooseFaction, Switch = onSwitchFaction }\n")
    prog = sources[PR]
    targets = re.search(r"^local REBIRTH_TARGETS = .*$", prog, re.M)
    if not targets:
        raise ValueError("ProgressionService REBIRTH_TARGETS boundary changed; update the test extractor.")
    out["REBIRTH_EXTRACT"] = (
        "local Config, Util, S, getData = ...\nlocal TAG = \"ProgressionService\"\n" + targets.group() + "\nlocal M = {}\n"
        + function_block(prog, "local function num(")
        + function_block(prog, "function M.TryRebirth(")
        + "\nreturn M\n")
    return out


MUTATIONS = [
    # SKL-3 the practice subs SK1 / SK2
    ("SKL-3: SkillHit ignores the Slot", ST,
     "\t\tif obj.Slot and ev.Info.Slot ~= obj.Slot then return 0 end -- SKL-3: only that skill's casts (SK1 Z, SK2 X)\n", ""),
    ("SKL-3: Requires.Skill ignores the switch", ST, "local on = req.Skill == \"Q\" or skills[req.Skill .. \"Enabled\"] == true",
     "local on = true"),
    ("SKL-3: Requires.Skill ignores the slot", ST, "if not index or not on or num(data.SkillSlots) < index then return false end",
     "if not index or not on then return false end"),
    ("SKL-3: SK2 forgotten in the sub list", C, "\t\t\"SK1\", \"SK2\", -- SKL-3: the practice subs of a new skill",
     "\t\t\"SK1\", -- SKL-3: the practice subs of a new skill"),
    # 검수 2026-10-07: SK2's picks have their side
    ("SK2 'Guard' has no side (no change of mind)", ST, "B = \"Evil\", Guard = \"Good\",", "B = \"Evil\","),
    # A23-71 the first skill at Lv5
    ("A23-71: no 'Skills come' tail", ST,
     "\tif not track.Claim and needsSkill(obj, track) and not Config.SkillLearned(data.SkillSlots, data.Level, data.Rebirths) then\n",
     "\tif false then\n"),
    ("A23-71: the tail stays after the skill trial", ST,
     "if sub.Type == \"SkillHit\" and num(type(track.T) == \"table\" and track.T[sub.Key]) < num(sub.Count, 1) then return true end",
     "if sub.Type == \"SkillHit\" then return true end"),
    ("A23-71: M1_3 skill hits from Lv1", C,
     "Start = \"Grow to Lv5 to learn your first skill!\", Obj = { Type = \"Level\", Level = 5, Skill = true } },",
     "Start = \"Grow to Lv5 to learn your first skill!\", Obj = { Type = \"Level\", Level = 1, Skill = true } },"),
    ("A23-71: M1_3's Lv5 step ignores a kept Q", C,
     "Start = \"Grow to Lv5 to learn your first skill!\", Obj = { Type = \"Level\", Level = 5, Skill = true } },",
     "Start = \"Grow to Lv5 to learn your first skill!\", Obj = { Type = \"Level\", Level = 5 } },"),
    ("A23-71: a kept Q never passes a Lv5 step", ST,
     "\treturn obj.Skill == true and Config.SkillLearned(data.SkillSlots, data.Level, data.Rebirths)\n", "\treturn false\n"),
    # A23-71 S8: a Level step's own Start only while that level is ahead
    ("S8: a Level step's Start never said", ST,
     "\tif first and first.Start and type(obj) == \"table\" and obj.Type == \"Level\" and not levelReached(data, obj) then\n",
     "\tif false then\n"),
    ("S8: a Level step's Start said past its level", ST,
     "obj.Type == \"Level\" and not levelReached(data, obj) then", "obj.Type == \"Level\" then"),
    ("S8: M1_3 keeps its old quest Start", C,
     "\t\t\tKind = \"Main\", Chapter = 1, Title = \"Boom, All at Once!\", ShortName = \"Skill boom\",\n",
     "\t\t\tKind = \"Main\", Chapter = 1, Title = \"Boom, All at Once!\", ShortName = \"Skill boom\",\n"
     "\t\t\tStart = \"Dusty slimes move in groups. Skills use MP!\",\n"),
    ("A23-71: N1 at any level", C, 'Requires = { Done = { "M1_4" }, Level = 5 }, -- A23-71: a skill quest',
     'Requires = { Done = { "M1_4" } },'),
    # A23-70 the lost lunchbox
    ("the lunchbox before the first claim", ST,
     "\tif req.TutorialDone and num(data.TutorialStep) ~= TUT_DONE then return false end\n", ""),
    ("players past the Forge get the lunchbox", ST, "\t\tif st.Done[gone] then return false end\n", ""),
    ("the card waits in the list", ST, "\t\t\tif def.Pop then openStep(player, id, st.Subs[id]) end -- A23-70: the card opens by itself, once\n", ""),
    ("no answer from the kid", ST, "\t\t\treply = pick.Reply -- A23-70: the other person answers (last, replyLater)\n", ""),
    # 10/08 Play check: the answer was pushed off by the gold / done lines while the card was open
    ("the answer comes first again", ST, "\t\t\treply = pick.Reply -- A23-70: the other person answers (last, replyLater)\n",
     "\t\t\tif pick.Reply then notify(player, pick.Reply, \"good\", \"None\") end\n"),
    ("the answer never waits", ST, "local REPLY_AFTER = 0.35\n", "local REPLY_AFTER = 0\n"),
    ("the answer is never sent", ST, "\t\tif type(reply) == \"string\" then replyLater(player, reply) end\n", ""),
    ("the lunchbox scores Honor", C, 'Good = { Label = "Give it back", Points = 0,', 'Good = { Label = "Give it back", Points = 1,'),
    ("a bite pays nothing", C, "Reward = { Gold = 25 } },", "Reward = { Gold = 0 } },"),
    # 3rd idea round + sound_spec §4-1
    ("a ShowProgress row keeps its numbers", ST,
     "\tif target > 1 and not track.Claim and step and type(step.Text) == \"string\" then\n", "\tif false then\n"),
    ("the seconds lose their unit", ST, "\tif n > 0 then unit = \"s\" end\n", ""),
    ("a 0-point pick stays silent", ST,
     "\t\tnotify(player, (f == \"Halo\" and TXT.OffSideHaloZero or TXT.OffSideHornsZero) .. \" \"\n", "\t\tnotify(player, \"\" .. \" \"\n"),
    ("no Choice sound for a pick", ST, "\t\t\tchoiceFx(player, option)\n", ""),
    ("the finish line without QuestDone", ST, "\tnotify(player, def.Finish or msg, \"reward\", \"QuestDone\")\n",
     "\tnotify(player, def.Finish or msg, \"reward\")\n"),
    ("follow-up lines get the default sound", ST, "\tif def.Finish then notify(player, msg, \"reward\", \"None\") end\n",
     "\tif def.Finish then notify(player, msg, \"reward\") end\n"),
    ("story rows lose their ShortName", ST,
     "\t\tShortName = (step and step.ShortName) or def.ShortName, -- 검수 2026-10-07: the phone HUD quest row (<= 14)\n", ""),
    ("a step's ShortName is ignored", ST, "ShortName = (step and step.ShortName) or def.ShortName,", "ShortName = def.ShortName,"),
    ("H1 opens after M1_1", C, 'Speaker = "Bright", Factions = { Halo = true },\n\t\t\tRequires = { Done = { "M2_3" } },',
     'Speaker = "Bright", Factions = { Halo = true },\n\t\t\tRequires = { Done = { "M1_1" } },'),
    ("H1 spies 1 s", C,
     '"Spy by the woods\' edge %d/%d s", Guide = "WoodsGate",\n\t\t\t\t\tObj = { Type = "Near", Spot = "WoodsGate", Radius = 14, Stay = 10 }',
     '"Spy by the woods\' edge %d/%d s", Guide = "WoodsGate",\n\t\t\t\t\tObj = { Type = "Near", Spot = "WoodsGate", Radius = 14, Stay = 1 }'),
    ("N3 only for the guild", C, 'Speaker = "Tiny", -- everyone (A23-57: no Factions)',
     'Speaker = "Tiny", Factions = { Neutral = true },'),
    # A23-58
    ("an off-side pick adds instead of taking", ST, "S.PlayerService.SetStat(player, stat, have - take)",
     "S.PlayerService.SetStat(player, stat, have + take)"),
    ("no floor at 0", ST, "\tlocal take = math.min(have, pts)\n", "\tlocal take = pts\n"),
    ("the old rule: a pick feeds the other side's score", ST, '\tlocal stat = f == "Halo" and "Honor" or "Infamy"\n\tif (f == "Halo") == (option == "Good") then',
     '\tlocal stat = option == "Good" and "Honor" or "Infamy"\n\tif (f == "Halo") == (option == "Good") then'),
    ("an off-side pick still pays score", ST, '\tif (f == "Halo") == (option == "Good") then\n\t\tS.PlayerService.AddStat',
     '\tif true then\n\t\tS.PlayerService.AddStat'),
    ("no rank-down line", ST, "\t\tnotify(player, f == \"Halo\" and TXT.RankDownHalo or TXT.RankDownHorns, \"info\")\n", ""),
    ("a rank line without a drop", ST, "if rank(have - take) < rank(have) then", "if rank(have - take) <= rank(have) then"),
    ("E0: an old save skips every chapter (the old bug)", ST,
     "\t\t\tif def and num(def.Chapter) <= upTo then st.Done[id] = true end\n", "\t\t\tst.Done[id] = true\n"),
    ("E0: Lv25+ skips only chapters 1-2", C, "SkipChapters = { { Level = 10, UpTo = 2 }, { Level = 25, UpTo = 3, Subs = { \"M3_5\" } } },",
     "SkipChapters = { { Level = 10, UpTo = 2 } },"),
    ("no clue toast", ST, "\tif def.Clue then notify(player, def.Clue, \"info\") end", "\tlocal _ = def.Clue"),
    ("the Halo bridge spot moves away", C, "Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -138)",
     "Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -100)"),
    ("B pays no gold", C, 'Reward = { Potion = "HP", N = 3, Gold = 220 } } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5 },\n\t\t\tFinish = "Smokey: So who',
     'Reward = { Potion = "HP", N = 3 } } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5 },\n\t\t\tFinish = "Smokey: So who'),
    ("leaving the spot keeps the count", ST, "\t\t\t\t\t\tif mine then mine[key] = nil end\n", ""),
    ("a stay counts by ticks, not time", ST, "local held = math.min(obj.Stay, math.floor(os.clock() - mine[key]))",
     "local held = math.min(obj.Stay, num(tr.P) + 1)"),
    ("quest NPCs reachable from anywhere", ST,
     "\tif step.Npc and not npcNear(player, step.Npc) then return end", "\tlocal _ = npcNear"),
    ("no NPC placed = no talk", ST, "\treturn not found\nend", "\treturn false\nend"),
    ("NPC steps pop up by themselves", ST, "\tif step.Npc and manual ~= true then return end\n", ""),
    ("the pick pays nothing of its own", ST, "\t\t\tpayChoice(player, obj, option)\n", ""),
    ("a Neutral A pays Evil's reward", ST, 'payChoice(player, obj, option == "A" and "Good" or "Evil")',
     'payChoice(player, obj, option == "A" and "Evil" or "Good")'),
    ("XPBar ignored", ST, "\tif num(r.XPBar) > 0 then x += math.floor(Config.XPToNext(level) * num(r.XPBar)) end\n", ""),
    ("GoldN ignored", ST, "\tif num(r.GoldN) > 0 then g += math.floor(num(r.GoldN)) end\n", ""),
    ("the guild's own quests offered while off", ST,
     '\tif def.Factions and def.Factions.Neutral and not def.Factions.Halo and not def.Factions.Horns\n\t\tand not Config.FeatureOn("NeutralFaction") then return false end\n', ""),
    ("GrantItem: potions never given", L, "\tif Config.PotionStockKey(id) then\n", "\tif false then\n"),
    ("GrantItem: no upper count limit", L, "n < 1 or n > 99 then return 0 end", "n < 1 then return 0 end"),
    ("Neutral pickable while off", C, '\tif factionId == "Neutral" and not Config.FeatureOn("NeutralFaction") then return false end\n', ""),
    ("the picker ignores the switch", F, "\treturn Config.Pickable(factionId)\n",
     '\treturn (factionId == "Halo" or factionId == "Horns" or factionId == "Neutral") and Config.Factions[factionId] ~= nil\n'),
    ("a refused Neutral pick is not logged", F, "\t\tlogNeutralRefused(player, factionId)\n\t\treturn\n", "\t\treturn\n"),
    ("rebirth into the guild allowed", PR, "\tif not Config.Pickable(factionId) then", "\tif false then"),
    # quest_volume §2-6: 3 sub rows, a town quest in progress never pushed off
    ("MaxSubs back to 2", C, "\tMaxSubs = 3, -- sub rows", "\tMaxSubs = 2, -- sub rows"),
    ("a started sub ranks like an untouched one", ST, '((started or id == "S0" or townOffer) and 2)', '((id == "S0" or townOffer) and 2)'),
    # zone_check_halo #19: a faction town offer ranks with the subs in progress; SendAllSubs sends the rest marked More
    ("a town offer waits behind the subs in progress", ST, '((started or id == "S0" or townOffer) and 2)', '((started or id == "S0") and 2)'),
    ("every waiting card is a town offer", ST, 'local townOffer = waiting and type(def.Factions) == "table" and step.Npc ~= nil', 'local townOffer = waiting'),
    ("an offer without a faction is a town offer", ST, 'local townOffer = waiting and type(def.Factions) == "table" and step.Npc ~= nil', 'local townOffer = waiting and step.Npc ~= nil'),
    ("an offer without an NPC is a town offer", ST, 'local townOffer = waiting and type(def.Factions) == "table" and step.Npc ~= nil', 'local townOffer = waiting and type(def.Factions) == "table"'),
    ("SendAllSubs sends everything always", ST, "for i = 1, SQ.SendAllSubs == true and #rows or math.min(#rows, cap) do", "for i = 1, #rows do"),
    ("SendAllSubs sends nothing more", ST, "for i = 1, SQ.SendAllSubs == true and #rows or math.min(#rows, cap) do", "for i = 1, math.min(#rows, cap) do"),
    ("SendAllSubs any truthy value", ST, "SQ.SendAllSubs == true and #rows", "SQ.SendAllSubs and #rows"),
    ("the rows past MaxSubs are not marked", ST, "\t\tif i > cap then rows[i].More = true end -- past the HUD's rows: the quest window only\n", ""),
    ("every row is marked More", ST, "if i > cap then rows[i].More = true end", "rows[i].More = true"),
    ("More starts one row early", ST, "if i > cap then rows[i].More = true end", "if i >= cap then rows[i].More = true end"),
    ("More starts one row late", ST, "if i > cap then rows[i].More = true end", "if i > cap + 1 then rows[i].More = true end"),
    ("MaxSubs is not read", ST, "local cap = math.max(0, math.floor(num(SQ.MaxSubs, 3)))", "local cap = 3"),
    ("Config: SendAllSubs is on", C, "\tSendAllSubs = false,", "\tSendAllSubs = true,"),
    ("a new offer outranks the subs in progress", ST, "((tr.Claim or (waiting and started)) and 0)", "((tr.Claim or waiting) and 0)"),
    ("older quests first within a rank", ST, "\t\treturn a.Order > b.Order\n", "\t\treturn a.Order < b.Order\n"),
    ("the sort fields reach the client", ST, "\t\trows[i].Rank, rows[i].Order = nil, nil\n", ""),
    # story_depth (나) the beta Easter eggs
    ("egg: the scroll is in front of the Altar", C, "Landmarks.TermsScroll = Vector3.new(0, 0, 51)", "Landmarks.TermsScroll = Vector3.new(0, 0, 40)"),
    ("egg: the slip is behind the Wanted Board", C, "Landmarks.PatchNote = Vector3.new(-52, 0, 0)", "Landmarks.PatchNote = Vector3.new(-58, 0, 0)"),
    ("egg: the goose nest is not the perch", C, "Landmarks.GooseNest = Vector3.new(-30, 0, 30)", "Landmarks.GooseNest = Vector3.new(-30, 0, 40)"),
    ("egg: Patch Note is not hidden", C, "Title = \"Patch Note\", ShortName = \"Patch Note\", Hidden = true,", "Title = \"Patch Note\", ShortName = \"Patch Note\","),
    ("egg: Goose Fan opens after M1_4", C, "Title = \"Goose Fan\", ShortName = \"Goose Fan\", Hidden = true, Speaker = \"Goose\", Requires = { Done = { \"M2_3\" } },",
     "Title = \"Goose Fan\", ShortName = \"Goose Fan\", Hidden = true, Speaker = \"Goose\", Requires = { Done = { \"M1_4\" } },"),
    ("egg: the scroll speaks as the guide", C, "Hidden = true, Speaker = \"Scroll\",", "Hidden = true,"),
    ("egg: the patch note speaks as the guide", C, "ShortName = \"Patch Note\", Hidden = true, Speaker = \"Notice\",", "ShortName = \"Patch Note\", Hidden = true,"),
    ("egg: the goose speaks as the guide", C, "Hidden = true, Speaker = \"Goose\",", "Hidden = true,"),
    ("egg: the sky speaks as the guide", C, "Hidden = true, Speaker = \"Shard\", Requires", "Hidden = true, Requires"),
    ("egg: the bench note speaks as the guide", C, "ShortName = \"Bench clue\", Hidden = true, Speaker = \"Notice\",", "ShortName = \"Bench clue\", Hidden = true,"),
    ("egg: the scroll has no name", C, "Scroll = \"Terms of Fate\", Notice", "Notice"),
    ("egg: the goose has another name", C, "Goose = \"Golden Goose\" }", "Goose = \"Goose\" }"),
    ("egg: the sky still says 'Sky Crown:'", C, "Lines = { All = { \"Stop staring. I'm broken, not famous.\" } } },", "Lines = { All = { \"Sky Crown: Stop staring. I'm broken, not famous.\" } } },"),
    ("egg: the joke pick counts for My Way", C, "Obj = { Type = \"Choice\", MyWay = false, Good", "Obj = { Type = \"Choice\", Good"),
    ("egg: Goose Fan is Halo only", C, "Title = \"Goose Fan\", ShortName = \"Goose Fan\", Hidden = true,", "Title = \"Goose Fan\", ShortName = \"Goose Fan\", Hidden = true, Factions = { Halo = true },"),
    ("egg: the bench radius is 60", C, "{ Text = \"Look under the bench\", Obj = { Type = \"Near\", Spot = \"KidsBench\", Radius = 6 } },",
     "{ Text = \"Look under the bench\", Obj = { Type = \"Near\", Spot = \"KidsBench\", Radius = 60 } },"),
    ("egg: the nest radius is 6 -> 60", C, "Obj = { Type = \"Near\", Spot = \"GooseNest\", Radius = 6 } },", "Obj = { Type = \"Near\", Spot = \"GooseNest\", Radius = 60 } },"),
    ("egg: the sky takes 3 seconds", C, "Spot = \"Fountain\", Radius = 12, Stay = 30 } },", "Spot = \"Fountain\", Radius = 12, Stay = 3 } },"),
    ("egg: the fountain radius is 100", C, "Spot = \"Fountain\", Radius = 12, Stay = 30 } },", "Spot = \"Fountain\", Radius = 100, Stay = 30 } },"),
    ("egg: the fine print is the same for both", C, "Evil = { All = { \"Thanks! You agreed to… something. Not even Fate knows what.\" } },\n\t\t\t\tDefault",
     "Evil = { All = { \"Rule 1: No slimes on the altar. Rule 2: See Rule 1.\", \"…You're still reading? Nobody reads this far.\", \"Page 4,000: Be kind. That was the whole thing.\" } },\n\t\t\t\tDefault"),
    # zone_check_halo #22 / #25 / #30: the town NPC's Talk prompt
    ("npc talk: any distance", ST, "if step and step.Panel == true and step.Npc == npcId and npcNear(player, npcId) then", "if step and step.Panel == true and step.Npc == npcId then"),
    ("npc talk: any NPC", ST, "if step and step.Panel == true and step.Npc == npcId and npcNear(player, npcId) then", "if step and step.Panel == true and npcNear(player, npcId) then"),
    ("npc talk: a quest waiting for [Claim]", ST, "local step = def and not tr.Claim and stepOf(player, def, tr.St) or nil", "local step = def and stepOf(player, def, tr.St) or nil"),
    ("npc talk: the oldest quest first", ST, "\tfor i = #SQ.Subs, 1, -1 do\n\t\tlocal id = SQ.Subs[i]\n\t\tif st.Subs[id] then table.insert(order,", "\tfor i = 1, #SQ.Subs do\n\t\tlocal id = SQ.Subs[i]\n\t\tif st.Subs[id] then table.insert(order,"),
    ("npc talk: a player without a class", ST, "if not S.PlayerService.IsReady(player) or player:GetAttribute(\"ClassChosen\") ~= true then return nil end", "if not S.PlayerService.IsReady(player) then return nil end"),
    ("npc talk: a non-string id", ST, "if typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") or type(npcId) ~= \"string\" then return nil end", "if typeof(player) ~= \"Instance\" or not player:IsA(\"Player\") then return nil end"),
    ("npc talk: the prompt is never heard", ST, "\t\tprompts.PromptTriggered:Connect(function(prompt, player)", "\t\tprompts.Unused:Connect(function(prompt, player)"),
    ("npc talk: any prompt", ST, "if type(npcId) ~= \"string\" or typeof(player) ~= \"Instance\" then return end", "if typeof(player) ~= \"Instance\" then return end\n\t\t\tnpcId = npcId or \"Bright\""),
    ("npc talk: no rate limit", ST, "\t\t\tif not Util.RateLimit(player, \"StoryNpcTalk\", (Config.RateLimits and Config.RateLimits.StoryAction) or 0.4) then return end\n", ""),
    ("egg: the scroll titles are swapped", C, "TitleBy = { Good = \"ActuallyReadIt\", Evil = \"DidntReadIt\" } }", "TitleBy = { Good = \"DidntReadIt\", Evil = \"ActuallyReadIt\" } }"),
    ("egg: reading it all scores a point", C, "Good = { Label = \"Read it all\", Points = 0 }", "Good = { Label = \"Read it all\", Points = 1 }"),
    ("egg: agreeing scores a point", C, "Evil = { Label = \"I agree\", Points = 0 }", "Evil = { Label = \"I agree\", Points = 1 }"),
    ("egg: a Neutral save has no labels", C, "Neutral = { A = \"Read it all\", B = \"I agree\" } } },", "} },"),
    ("egg: Bug Reporter pays gold", C, "Reward = { Title = \"BugReporter\" },", "Reward = { Title = \"BugReporter\", Gold = 1 },"),
    ("egg: Goose Fan pays a title it lacks", C, "Reward = { Title = \"GooseFan\" },", "Reward = { Title = \"GooseFanX\" },"),
    ("egg: the titles are not in the picker", C, "for _, id in { \"ActuallyReadIt\", \"DidntReadIt\", \"BugReporter\", \"GooseFan\", \"SkyWatcher\", \"BenchDetective\" } do",
     "for _, id in {} do"),
    ("egg: Bench Detective has no title def", C, "Config.TitleDefs.BenchDetective = { Name = \"Bench Detective\", NameEn = \"Bench Detective\", Color = Color3.fromRGB(200, 150, 235) }", ""),
    ("egg: the bench dialogue needs an NPC", C, "{ Text = \"Bench Detective\", Panel = true, Obj = { Type = \"Talk\" },", "{ Text = \"Bench Detective\", Panel = true, Npc = \"Bright\", Obj = { Type = \"Talk\" },"),
    ("egg: Sky Watcher is not in the sub list", C, "for _, id in { \"EG01\", \"EG02\", \"EG03\", \"EG04\", \"EG14\" } do table.insert(Config.StoryQuests.Subs, id) end",
     "for _, id in { \"EG01\", \"EG02\", \"EG03\", \"EG14\" } do table.insert(Config.StoryQuests.Subs, id) end"),
    ("egg: the bench's phone name is too long", C, 'Title = "Bench Detective", ShortName = "Bench clue",', 'Title = "Bench Detective", ShortName = "Bench Detective",'),
    ("egg: a start toast", C, "{ Text = \"Read the note\", Obj", "{ Text = \"Read the note\", Start = \"A secret note!\", Obj"),
    # story_depth E1 / E2 / E3 / E5
    ("E1: Requires.Pick ignored", ST,
     "\t\tif pick == nil or (pick ~= req.Pick.Is and SIDE[pick] ~= req.Pick.Is) then return false end\n", ""),
    ("E1: no side grouping (A is not Good)", ST, "(pick ~= req.Pick.Is and SIDE[pick] ~= req.Pick.Is)", "(pick ~= req.Pick.Is)"),
    ("E2: the window gets no Var", ST, "{ Id = id, St = track.St, Var = var }", "{ Id = id, St = track.St }"),
    ("E2: the row gets no Var", ST, "Var = (not track.Claim) and varFor(data, step) or nil },", "Var = nil },"),
    ("E2: no Default", ST, '\treturn "Default"\nend', "\treturn nil\nend"),
    ("E2: the side before the exact pick", ST,
     "\tif pick ~= nil and by[pick] ~= nil then return pick end\n\tlocal side = SIDE[pick]\n\tif side ~= nil and by[side] ~= nil then return side end\n",
     "\tlocal side = SIDE[pick]\n\tif side ~= nil and by[side] ~= nil then return side end\n\tif pick ~= nil and by[pick] ~= nil then return pick end\n"),
    ("E2: no changed-mind line", ST, "\t\tnotify(player, side == \"Good\" and TXT.ChangedGood or TXT.ChangedEvil, \"info\")\n", ""),
    ("E2: 0-point picks count as a change", ST,
     "if side == nil or (num(obj.Good and obj.Good.Points) <= 0 and num(obj.Evil and obj.Evil.Points) <= 0) then return end",
     "if side == nil then return end"),
    ("E2: an artisan pick never counts", ST, "\t\t\tchangedMind(player, st, obj, option)\n", ""),
    ("E2: a broken saved side kept", ST,
     '\tif st.LastSide ~= "Good" and st.LastSide ~= "Evil" then st.LastSide = nil end', ""),
    ("E3: no title", ST, "\t\tlocal ok, new = pcall(titles.Grant, player, titleId)\n", "\t\tlocal ok, new = false, nil\n"),
    ("E3: TitleBy ignores the pick", ST, 'r.TitleBy[SIDE[st.Pick[id]] or ""]', "r.TitleBy.Good"),
    ("E3: 'New title' for one already owned", ST, "if ok and new == true then notify", "if ok then notify"),
    ("E5: a 0-point pick says nothing", ST,
     '\t\t\t\tnotify(player, option == "Good" and TXT.LeanGood or TXT.LeanEvil, "info") -- E5: no "+0", the shard leans\n', ""),
    ("E5: a hidden sub's Start toast", ST, "\tif def.Hidden then return end -- E5: a hidden sub stays secret\n", ""),
    ("E5: a hidden sub listed before it is found", ST, " and (not def.Hidden or found) then", " then"),
    ("E5: found from the start", ST, "local found = tr ~= nil and (tr.Claim or num(tr.St, 1) > 1)",
     "local found = tr ~= nil and (tr.Claim or num(tr.St, 1) >= 1)"),
    # chapter 3 (A23-56 main advance + story_depth beta): Trials Say, E7, Reward.Item, the data
    ("Trials parts say nothing", ST,
     '\t\t\t\t\t\tif cur >= sub.Count and sub.Say then notify(player, sub.Say, "info") end -- one line per part done\n', ""),
    ("E7: everyone counts as graduated", ST, "\t\treturn ok and rookie == false\n", "\t\treturn true\n"),
    ("E7: nobody graduates", ST, "\t\treturn ok and rookie == false\n", "\t\treturn false\n"),
    ("Reward.Item never given", ST, "\tif type(def.Reward) == \"table\" and def.Reward.Item then\n",
     "\tif false then\n"),
    ("M3_4: Dibs pays nothing", C, 'Label = "Into our vault. They took it first!", Points = 3, Reward = { Gold = 192 } },',
     'Label = "Into our vault. They took it first!", Points = 3 },'),
    ("Pip1 for the Evil side", C, 'Requires = { Done = { "M3_4" }, Pick = { Id = "M3_4", Is = "Good" }, Level = 15 },',
     'Requires = { Done = { "M3_4" }, Pick = { Id = "M3_4", Is = "Evil" }, Level = 15 },'),
    ("camp 2 counts from far away", C, 'Near = "GoblinCamp2", Radius = 40,', 'Near = "GoblinCamp2", Radius = 100,'),
    ("M3_2 left out of the chain", C, '"M3_1", "M3_2", "M3_3", "M3_4",', '"M3_1", "M3_3", "M3_4",'),
    ("no Lines fallback on the reaction page", C,
     '{ Text = "Hear the Guide", Panel = true, Obj = { Type = "Talk" }, Lines = { All = { "The shard found a home." } },',
     '{ Text = "Hear the Guide", Panel = true, Obj = { Type = "Talk" },'),
    ("camp 1 outside the woods", C, "Landmarks.GoblinCamp1 = Vector3.new(840, 0, 95)",
     "Landmarks.GoblinCamp1 = Vector3.new(400, 0, -60)"),
    # quest_volume §3-2: the 18 subs
    ("GW7 not waiting for GW1", C, 'Requires = { Done = { "GW1" }, Level = 21 },', 'Requires = { Done = { "M2_7" }, Level = 21 },'),
    ("XR1 before the first ten minutes", C,
     'Kind = "Sub", Title = "Lost & Found", ShortName = "Lost bear", Speaker = "Tiny",\n\t\t\tRequires = { Done = { "M1_4" }, Level = 5 },',
     'Kind = "Sub", Title = "Lost & Found", ShortName = "Lost bear", Speaker = "Tiny",\n\t\t\tRequires = { Done = { "M1_1" }, Level = 1 },'),
    ("a woods-type B pays the old 192", C,
     'Evil = { Label = "Draw a mustache on him", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } },',
     'Evil = { Label = "Draw a mustache on him", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },'),
    ("S6 for Horns without its gold step", C,
     '\t\t\t\t\tHorns = { Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 80 } } },',
     '\t\t\t\t},'),
    ("the hero statue outside Halo Citadel", C, "Landmarks.HeroStatue = Vector3.new(0, 0, -370)",
     "Landmarks.HeroStatue = Vector3.new(0, 0, -200)"),
    ('#71 the town B pays 60 again', C, 'Evil = { Label = "Hang it in my house", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 220 } } } },',
     'Evil = { Label = "Hang it in my house", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } } } },'),
    ('#36 H2: the pick opens in the field', C, '\t\t\t\t{ Text = "Bring the lantern home", Guide = "HaloTown", Start = "The lantern! Take it home to Halo Citadel.",\n\t\t\t\t\tObj = { Type = "Enter", Zone = "HaloTown" } },\n',
     ''),
    ('#36 H2: home is the Crossroads', C, 'Start = "The lantern! Take it home to Halo Citadel.",\n\t\t\t\t\tObj = { Type = "Enter", Zone = "HaloTown" } },',
     'Start = "The lantern! Take it home to Halo Citadel.",\n\t\t\t\t\tObj = { Type = "Enter", Zone = "Crossroads" } },'),
    ('#37 H2 guides to the Crossroads', C, '{ Text = "Look around the fountain", Guide = "Fountain",',
     '{ Text = "Look around the fountain", Guide = "Crossroads",'),
    ('#36 H3: the pick opens in the field', C, '\t\t\t\t{ Text = "Back to Sir Gleam", Guide = "HaloTown", Obj = { Type = "Enter", Zone = "HaloTown" } },\n',
     ''),
    ('#18 H3 without a Start line', C, '\t\t\tStart = "Sir Gleam needs help in Halo Citadel!",\n',
     ''),
    ('#18 H5 without a Start line', C, '\t\t\tStart = "Bright needs a form signed. Find her in Halo Citadel!",\n',
     ''),
    ('#35 H6: the pick opens in the woods', C, '\t\t\t\t{ Text = "Back to the statues", Guide = "HeroStatue", Obj = { Type = "Near", Spot = "HeroStatue", Radius = 16 } },\n',
     ''),
    ('#35 H6: any spot near the statues', C, 'Obj = { Type = "Near", Spot = "HeroStatue", Radius = 16 } },\n\t\t\t\t{ Text = "The statues shine again!"',
     'Obj = { Type = "Near", Spot = "HeroStatue", Radius = 120 } },\n\t\t\t\t{ Text = "The statues shine again!"'),
    ('#38 H1 says near the woods', C, 'Slime Princes in the meadow %d/%d',
     'Slime Princes near the woods %d/%d'),
    ('#40 the oaths under Side', C, '\t\t["story:OathH"] = "Faction", ["story:OathR"] = "Faction", -- 빛 마을 점검 #40\n',
     ''),
    ('#2 the landmark tag renamed', C, '\tLandmarkTag = "StoryLandmark",\n',
     '\tLandmarkTag = "StoryLandmarks",\n'),
    ('#2 Near ignores the world marker', ST, '\t\t\t\tlocal spot = landmark(obj.Spot)',
     '\t\t\t\tlocal spot = SQ.Landmarks[obj.Spot]'),
    ('#2 kill-Near ignores the world marker', ST, '\t\t\tlocal spot = landmark(obj.Near)',
     '\t\t\tlocal spot = SQ.Landmarks[obj.Near]'),
    ('#2 a marker outside the workspace counts', U, 'if inst:GetAttribute("Spot") ~= key or not inst:IsDescendantOf(workspace) then return nil end',
     'if inst:GetAttribute("Spot") ~= key then return nil end'),
    ('#2 any marker moves any spot', U, 'if inst:GetAttribute("Spot") ~= key or not inst:IsDescendantOf(workspace) then return nil end',
     'if not inst:IsDescendantOf(workspace) then return nil end'),
    ('#2 the server skips the marker', ST, 'return Util.TaggedSpot(SQ.LandmarkTag or "StoryLandmark", id) or SQ.Landmarks[id]',
     'return SQ.Landmarks[id]'),
    ('#2 a marker never wins over Config', U, '\t\tif okPos and typeof(pos) == "Vector3" then return pos end\n',
     ''),
    ('H3 talks anywhere again', C, '{ Text = "Talk with Sir Gleam", Guide = "HaloTown", Npc = "Gleam", Panel = true,',
     '{ Text = "Talk with Sir Gleam", Guide = "HaloTown", Panel = true,'),
    ("GW7 forgets the GW1 pick", C, 'LinesBy = { From = "GW1",\n\t\t\t\t\t\tGood = { All = { "Grabbo: Last time',
     'LinesBy = { From = "GW7",\n\t\t\t\t\t\tGood = { All = { "Grabbo: Last time'),
    ("a Neutral save gets the Halo / Horns subs", C,
     'Kind = "Sub", Title = "The Crown War Is Close", ShortName = "Crown War", Factions = { Halo = true, Horns = true },',
     'Kind = "Sub", Title = "The Crown War Is Close", ShortName = "Crown War",'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    story = read(SSS / "StoryQuestService.luau")
    check("Players.PlayerRemoving" not in story, "StoryQuestService needs no new signal (left players pruned in its 1 s loop)")
    check('game:GetService("CollectionService")' in function_block(story, "local function npcNear("),
          "CollectionService is looked up lazily inside npcNear (the module loads without it)")
    config = read(ROOT / "src/ReplicatedStorage/Shared/Config.luau")
    features = next((ln for ln in config.splitlines() if ln.startswith("Config.Features = {")), "")
    check("NeutralFaction = false" in features, "A23-57 switch present and off (other switches may share the line)")
    check('Config.FactionOrder = { "Halo", "Horns", "Neutral" }' in config,
          "Config.FactionOrder untouched (game dev 1's picker reads the switch, A23-57)")
    # 검수 2026-10-07: every story pick has its side (SK2's Guard / Take were missing: no change of mind)
    side = re.search(r"^local SIDE = \{(.*?)\}", story, re.S | re.M)
    side_keys = set(re.findall(r'(\w+) = "(?:Good|Evil)"', side.group(1))) if side else set()
    picks = set(re.findall(r'Pick = "(\w+)"', config))
    check(bool(picks) and picks <= side_keys,
          f"every Pick in Config.StoryQuests has a side in SIDE (missing: {sorted(picks - side_keys)})")
    return count, failures


SUITE = Suite(
    mark="TOWN_QUESTS",
    fixture=ROOT / "tools/fixtures/town_quests_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-06/offline_dev2_town_quests_2026-10-06.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-46: subs H1 (Halo, Bright), R1 (Horns, Smokey), N3 (everyone, Tiny) open after M2_3, once each: talk to "
             "the NPC -> H1 stay 10 s at WoodsGate (outside PvP) -> 2 king slimes / R1 stay 15 s at the fountain "
             "(Crossroads zone) -> 6 slimes / N3 both bridge ends -> 30 hunting gold -> the pick at the NPC (A = one "
             "Enh70, B = 3 HP potions + 220 gold (빛 마을 점검 #71), 1 honor / infamy point, Neutral A / B recorded only) -> +120 gold + half "
             "a level bar of XP, a closing question. E4 Near.Stay counts seconds in one go (leaving resets, the row shows "
             "%d/%d s). E6 pick rewards go through LootService.GrantItem (items / potions, caps, 1..99). Npc steps need "
             "the player within StoryQuests.NpcRange of the CollectionService-tagged NPC (attribute NpcId) when it "
             "exists, never pop up by themselves, and rows carry Story.Npc. A23-57: Config.Features.NeutralFaction = "
             "false -> Config.Pickable refuses Neutral at the picker / altar (logged) and rebirth; the guild-only subs "
             "N1 / N2 are not offered; Neutral saves keep N3. quest_volume §2-6: StoryQuests.MaxSubs = 3 sub rows "
             "(claim / waiting card > situational > started or S0 > the rest, newer first in a rank, no Rank / Order "
             "sent), so a town quest in progress stays on the list. story_depth E1: Requires.Pick { Id, Is } (Is Good / Evil = "
             "that side: Purify / A = Good, Devour / B = Evil; else the exact pick). E2: LinesBy { From, Good, Evil, A, B, "
             "Default } -> Var (exact pick, else its side, else Default) on the OpenPanel payload and row.Story.Var; every "
             "LinesBy has a Default; a real pick (with points) on the other side from the last one adds ChangedGood / "
             "ChangedEvil (data.Story.LastSide, bad values dropped at load). E3: Reward.Title / TitleBy -> "
             "TitleService.Grant + 'New title: %s!' when new. E5: Hidden subs: no Start toast, no row until found (past "
             "step 1 / claim); a 0-point pick says LeanGood / LeanEvil (no score line). 빛 마을 점검 2026-10-10: every Halo-only "
             "pick happens in Halo Citadel (Npc Bright, or after a way-home step: H2 / H3 Enter HaloTown, H6 Near HeroStatue); "
             "H2 step 1 guides to the Fountain; H3 / H5 have Start lines; H1 says 'in the meadow'; OathH / OathR sit in the "
             "Faction tab; a workspace instance tagged StoryLandmark with Spot = <key> moves that landmark (Near steps and "
             "kill-Near), a marker outside the workspace or for another key moves nothing.",
    limitations="NPC models, '!' markers, the talk window and the quest marker routes are game dev 1's (contract: tag "
                "StoryNpc, attribute NpcId, row Story.Npc / Guide). Real walking, physics and the 1 s loop timing are "
                "modelled by moving the root and calling Refresh each second.",
)

if __name__ == "__main__":
    run(SUITE)
