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
    # A23-197 (10/15): Lost Lunchbox is a story (no pop-up card), the slimes by the pond and the box's spot count
    ("lunchbox pops again", C, "Title = \"Lost Lunchbox!\", ShortName = \"Lost lunchbox\", Speaker = \"Tiny\",",
     "Title = \"Lost Lunchbox!\", ShortName = \"Lost lunchbox\", Speaker = \"Tiny\", Pop = true,"),
    ("lunchbox: any slime counts", C, "Obj = { Type = \"Kill\", Kind = \"Slime\", Near = \"SlimePond\", Radius = 45, Count = 2 } },",
     "Obj = { Type = \"Kill\", Kind = \"Slime\", Count = 2 } },"),
    ("lunchbox: picked up from afar", C, "Obj = { Type = \"Near\", Spot = \"Lunchbox\", Radius = 10 } },",
     "Obj = { Type = \"Near\", Spot = \"Lunchbox\", Radius = 100 } },"),
    # A23-199 (최종 검수 10/15): offers, pickups, deliveries
    ("offer: taken by itself", ST, "\t\tif def and type(def.Offer) == \"table\" and not st.Done[id] and not st.Subs[id] then",
     "\t\tif false then"),
    ("offer: no StoryOffers", ST, "\tif player:GetAttribute(\"StoryOffers\") ~= offerAttr then player:SetAttribute(\"StoryOffers\", offerAttr) end\n", ""),
    ("offer: Accept anywhere", ST, "\tif not offerable(player, data, id) or not npcNear(player, DEFS[id].Offer.Npc) then return false end",
     "\tif not offerable(player, data, id) then return false end"),
    ("offer: Accept without the requirements", ST, "\t\tand requirementsMet(player, data, def)\nend", "\nend"),
    ("offer: Decline saves the quest", ST, "\tif action == \"Decline\" then\n\t\tStoryQuestService.Declined:Fire(player, id)\n\t\treturn true",
     "\tif action == \"Decline\" then\n\t\tstory(data).Subs[id] = { St = 1, P = 0, T = {}, Claim = false }\n\t\treturn true"),
    ("offer: no Offer panel", ST, "\t\t\tNet.Get(\"OpenPanel\"):FireClient(player, \"Offer\", { Id = offered[1], Npc = npcId })\n", ""),
    ("pickup: anywhere", ST, "\t\tif pickupOk(player, step.Obj) then advance(player, data, id, tr) end", "\t\tadvance(player, data, id, tr)"),
    ("deliver: anywhere", ST, "\t\tif npcNear(player, step.Obj.Npc or step.Npc) then advance(player, data, id, tr) end", "\t\tadvance(player, data, id, tr)"),
    ("deliver: a talk does not hand it over", ST, "\t\tif step and step.Panel ~= true and step.Obj.Type == \"Deliver\"", "\t\tif false and step and step.Panel ~= true and step.Obj.Type == \"Deliver\""),
    # feedback_audit #7 (최종 검수 10/15): the Choice Fx after the points, with the score / rank before and after
    ("Choice: no after score", ST, "\t\t\tlocal after = math.max(0, math.floor(num(data[stat])))\n", "\t\t\tlocal after = before\n"),
    ("Choice: no rank", ST, "RankFrom = rankOf(before), RankTo = rankOf(after) })", "})"),
    # bag slots (2026-10-14)
    ("bag: Reward.BagSlots ignored", ST, "if type(def.Reward) == \"table\" and num(def.Reward.BagSlots) > 0 and S.LootService",
     "if false and S.LootService"),
    ("bag: a story reward refused when full", ST, "math.floor(num(n, 1)), \"Reward\") -- a reward fits a full bag (10/14)", "math.floor(num(n, 1))) --"),
    ("bag: no Gained line", ST, "\t\tif ok and num(added) > 0 then notify(player, string.format(Config.BagSlots.Text.Gained, added), \"reward\", \"None\") end\n", ""),
    ("bag: no catch-up at the join", ST, "\t\t\tlocal okBag, errBag = pcall(StoryQuestService.CatchUpBagSlots, player, data)\n\t\t\tif not okBag", "\t\t\tlocal okBag, errBag = true, nil\n\t\t\tif not okBag"),
    ("bag: no catch-up on a chapter skip", ST, "\t\tlocal okBag, errBag = pcall(StoryQuestService.CatchUpBagSlots, player, data)\n\t\tif not okBag", "\t\tlocal okBag, errBag = true, nil\n\t\tif not okBag"),
    ("bag: catch-up adds again", ST, "\tif want > have then loot.AddBagSlots(player, want - have) end", "\tif want > Config.BagSlots.Default then loot.AddBagSlots(player, want - Config.BagSlots.Default) end"),
    ("bag: Lunch1 without slots", C, "			Reward = { BagSlots = 4 }, -- bag slots 10/14: the first upgrade", "			-- bag slots 10/14: the first upgrade"),
    ("bag: M2_7 without slots", C, "Reward = { Gold = 2, XP = 2, BagSlots = 4 }, -- bag slots 10/14", "Reward = { Gold = 2, XP = 2 }, -- bag slots 10/14"),
    ("Codex B1: the trials row says 0/3 again", ST, "\t\t\telseif first == nil and type(sub.Text) == \"string\" then\n\t\t\t\tfirst = sub\n",
     "\t\t\telseif false then\n\t\t\t\tfirst = sub\n"),
    # 장인 ② (2026-10-14): N0 / N0b / N4 and the Gather / Craft / SellMat steps
    ("artisan: any item gathered counts", ST, "\t\tif obj.Item and ev.Item ~= obj.Item then return 0 end\n", ""),
    ("artisan: a gather counts 1", ST, "\t\treturn math.max(0, math.floor(num(ev.N)))\n\telseif ev.Kind == \"Craft\"", "\t\treturn 1\n\telseif ev.Kind == \"Craft\""),
    ("artisan: an unknown recipe counts", ST, "\t\tif type(r) ~= \"table\" then return 0 end\n\t\tif obj.Role", "\t\tif obj.Role"),
    ("artisan: sales never count", ST, "\t\treturn t == \"SellMat\" and math.max(0, math.floor(num(ev.N))) or 0\n", "\t\treturn 0\n"),
    ("artisan: a Feature list ignored", ST, "\tfor _, f in type(req.Feature) == \"table\" and req.Feature or {} do -- 장인 ②: every switch of a list\n\t\tif not Config.FeatureOn(f) then return false end",
     "\tfor _, f in type(req.Feature) == \"table\" and req.Feature or {} do -- 장인 ②: every switch of a list\n\t\tif false then return false end"),
    ("artisan: no crafted weapon in hand", ST, "\tif r and r.EquipCrafted == true and S.LootService", "\tif false and S.LootService"),
    ("artisan: a weaker spare replaces the weapon", L, "and (num(def.Damage) > bestDamage or (best == tier and plus > bestPlus)) then", "then"),
    ("artisan: the spare stays packed", L, "\tif not best or LootService.UnpackSpare(player, best, bestPlus) ~= true then return nil end\n", "\tif not best then return nil end\n"),
    ("artisan: no Gathered hook", ST, "\t\t{ \"GatherService\", \"Gathered\", function", "\t\t{ \"GatherService\", \"GatheredX\", function"),
    ("artisan: N0 for every side", C, "Speaker = \"Guild\", Factions = { Neutral = true },\n\t\t\tRequires = { TutorialDone = true, Feature = { \"Gathering\", \"Crafting\" }, Classes = { Warrior = true } },",
     "Speaker = \"Guild\",\n\t\t\tRequires = { TutorialDone = true, Feature = { \"Gathering\", \"Crafting\" }, Classes = { Warrior = true } },"),
    # 최종 검수 10/15: one first harvest per artisan class (Requires.Classes) and N0b after any of them (Requires.DoneAny)
    ("artisan: Classes ignored", ST, "\tif type(req.Classes) == \"table\" and not (data.ClassChosen == true and req.Classes[data.Class] == true) then return false end\n", ""),
    ("artisan: DoneAny ignored", ST, "\t\tif not any then return false end\n", ""),
    ("artisan: DoneAny needs all", ST, "\t\t\tif st.Done[id] then any = true end\n", "\t\t\tif not st.Done[id] then any = false break end\n\t\t\tany = true\n"),
    ("artisan: the tamer's harvest is copper", C, "\t\t\tStart = \"Kit: Pick herbs, then make pet treats!\",\n\t\t\tSteps = {\n\t\t\t\t{ Text = \"Pick herbs %d/%d\", Obj = { Type = \"Gather\", Item = \"Herb\", Count = 3 } },",
     "\t\t\tStart = \"Kit: Pick herbs, then make pet treats!\",\n\t\t\tSteps = {\n\t\t\t\t{ Text = \"Pick herbs %d/%d\", Obj = { Type = \"Gather\", Item = \"CopperOre\", Count = 3 } },"),
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
    # A23-130 (server text verdicts 2026-10-11): no quest / step Start lines; putting one back must fail
    ("a step Start line back", ST, "\t\t-- A23-130: no step Start line (the row switches to the new step text)\n",
     "\t\tdo local ns = stepOf(player, def, track.St); if ns and ns.Start then notify(player, ns.Start, \"info\") end end\n"),
    ("a sub's Start line back", ST, "\t\t\tst.Subs[id] = { St = 1, P = 0, T = {}, Claim = false }\n",
     "\t\t\tst.Subs[id] = { St = 1, P = 0, T = {}, Claim = false }\n\t\t\tif def.Start then notify(player, def.Start, \"info\") end\n"),
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
    # A23-130 (user 2026-10-11): no Reply line after a pick, the reward toast only (no lean / saved line either)
    ("the kid thanks you again", C, 'Good = { Label = "Give it back", Points = 0, Pick = "GiveBack",',
     'Good = { Label = "Give it back", Points = 0, Pick = "GiveBack", Reply = "Thank you! Here, take this potion.",'),
    ("a 0-point pick leans again", ST, "\t\t\tif pts > 0 then pickScore(player, f, option, pts) end\n",
     "\t\t\tif pts > 0 then pickScore(player, f, option, pts) else notify(player, option == \"Good\" and TXT.LeanGood or TXT.LeanEvil, \"info\") end\n"),
    ("no reward toast", ST, "\tif #parts > 0 then notify(player, table.concat(parts, \" · \"), \"reward\", \"None\") end",
     "\tif false then end"),
    ("the lunchbox scores Honor", C, 'Good = { Label = "Give it back", Points = 0,', 'Good = { Label = "Give it back", Points = 1,'),
    ("a bite pays nothing", C, "Reward = { Gold = 25 } },", "Reward = { Gold = 0 } },"),
    # 3rd idea round + sound_spec §4-1
    ("a ShowProgress row keeps its numbers", ST,
     "\tif target > 1 and not track.Claim and step and type(step.Text) == \"string\" then\n", "\tif false then\n"),
    ("the seconds lose their unit", ST, "\tif n > 0 then unit = \"s\" end\n", ""),
    ("the zero-score remark back", ST, "\t\treturn -- nothing to take (A23-58 floor): A23-130 no line, the Choice Fx answers the pick\n",
     "\t\tnotify(player, (f == \"Halo\" and TXT.OffSideHaloZero or TXT.OffSideHornsZero) .. \" \" .. (option == \"Good\" and TXT.LeanGood or TXT.LeanEvil), \"info\")\n\t\treturn\n"),
    ("no Choice sound for a pick", ST, "\t\t\tchoiceFx(player, option)\n", ""),
    ("the reward line without QuestDone", ST, "\tnotify(player, msg, \"reward\", \"QuestDone\")\n", "\tnotify(player, msg, \"reward\")\n"),
    ("the Finish lore line back", ST, "\tnotify(player, msg, \"reward\", \"QuestDone\")\n",
     "\tnotify(player, def.Finish or msg, \"reward\", \"QuestDone\")\n"),
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
    ("the clue toast back", ST, "\t-- A23-130: no def.Clue toast (lore)\n", "\tif def.Clue then notify(player, def.Clue, \"info\") end\n"),
    ("the Halo bridge spot moves away", C, "Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -138)",
     "Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -100)"),
    ("B pays no gold", C, 'Reward = { Potion = "HP", N = 3, Gold = 220 } } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5 },\n\t\t\tFinish = "Rose: So who',
     'Reward = { Potion = "HP", N = 3 } } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5 },\n\t\t\tFinish = "Rose: So who'),
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
    ("a started sub ranks like an untouched one", ST, '((started or id == "S0") and 2)', '((id == "S0") and 2)'),
    # zone_check_halo #19: a faction town offer ranks with the subs in progress; SendAllSubs sends the rest marked More
    ("a town offer ranks with the subs in progress", ST, '(townOffer and 2.5)', '(townOffer and 2)'),
    ("a town offer is no better than a plain offer", ST, '(townOffer and 2.5) or ', ''),
    ("a town offer ranks below the plain offers", ST, '(townOffer and 2.5)', '(townOffer and 3.5)'),
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
    ("Config: SendAllSubs is off", C, "\tSendAllSubs = true,", "\tSendAllSubs = false,"),
    ("a new offer outranks the subs in progress", ST, "((tr.Claim or (waiting and started)) and 0)", "((tr.Claim or waiting) and 0)"),
    ("older quests first within a rank", ST, "\t\treturn a.Order > b.Order\n", "\t\treturn a.Order < b.Order\n"),
    ("the sort fields reach the client", ST, "\t\trows[i].Rank, rows[i].Order = nil, nil\n", ""),
    # story_depth (나) the beta Easter eggs
    ("egg: the scroll is in front of the Altar", C, "Landmarks.TermsScroll = Vector3.new(0, 0, 51)", "Landmarks.TermsScroll = Vector3.new(0, 0, 40)"),
    ("egg: the slip is behind the Wanted Board", C, "Landmarks.PatchNote = Vector3.new(-52, 0, 0)", "Landmarks.PatchNote = Vector3.new(-58, 0, 0)"),
    ("egg: the goose nest is not the Knights' nest", C, "Landmarks.GooseNest = Vector3.new(-30, 0, -30)", "Landmarks.GooseNest = Vector3.new(-30, 0, 30)"),
    ("egg: Patch Note is not hidden", C, "Title = \"Patch Note\", ShortName = \"Patch Note\", Hidden = true,", "Title = \"Patch Note\", ShortName = \"Patch Note\","),
    ("egg: Goose Fan opens after M1_4", C, "Title = \"Goose Fan\", ShortName = \"Goose Fan\", Hidden = true, Speaker = \"Goose\", Requires = { Done = { \"M2_3\" } },",
     "Title = \"Goose Fan\", ShortName = \"Goose Fan\", Hidden = true, Speaker = \"Goose\", Requires = { Done = { \"M1_4\" } },"),
    ("daily intro: offered at once", C, "Title = \"Daily Jobs\", ShortName = \"Daily jobs\", Requires = { Done = { \"M1_4\" } },",
     "Title = \"Daily Jobs\", ShortName = \"Daily jobs\", Requires = { Done = { \"M1_1\" } },"),
    ("daily intro: only for Halo", C, "Title = \"Daily Jobs\", ShortName = \"Daily jobs\", Requires", "Title = \"Daily Jobs\", ShortName = \"Daily jobs\", Factions = { Halo = true }, Requires"),
    ("daily intro: a closing toast again", C, "\tReward = { Gold = 1, XP = 1 }, -- no Finish line", "\tFinish = \"Daily jobs are open!\",\n\tReward = { Gold = 1, XP = 1 }, -- no Finish line"),
    ("daily intro: pays nothing", C, "\tReward = { Gold = 1, XP = 1 }, -- no Finish line", "\t-- no Finish line"),
    ("daily intro: not in the sub list", C, "table.insert(Config.StoryQuests.Subs, \"D0\")\n", ""),
    ("daily intro: it pops up by itself", C, "\tReward = { Gold = 1, XP = 1 }, -- no Finish line", "\tReward = { Gold = 1, XP = 1 },\n\tPop = true, -- no Finish line"),
    ("daily intro: not a dialogue", C, "{ Text = \"Hear about the daily jobs\", Panel = true, Obj = { Type = \"Talk\" },", "{ Text = \"Hear about the daily jobs\", Obj = { Type = \"Talk\" },"),
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
    ("npc talk: H3 is not Sir Gleam's", C, "{ Text = \"Talk to Sir Gleam\", Guide = \"HaloTown\", Npc = \"Gleam\", Panel = true,", "{ Text = \"Talk to Sir Gleam\", Guide = \"HaloTown\", Panel = true,"),
    ("npc talk: H3's choice card is nobody's", C, "{ Text = \"Talk with Sir Gleam\", Guide = \"HaloTown\", Npc = \"Gleam\", Panel = true,", "{ Text = \"Talk with Sir Gleam\", Guide = \"HaloTown\", Panel = true,"),
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
    # A23-130: the change-of-mind line is off (the side is still saved); putting it back must fail
    ("E2: the changed-mind line back", ST, "\tst.LastSide = side -- A23-130: saved only, no ChangedGood / ChangedEvil line\n",
     "\tif st.LastSide ~= nil and st.LastSide ~= side then notify(player, side == \"Good\" and TXT.ChangedGood or TXT.ChangedEvil, \"info\") end\n"
     "\tst.LastSide = side\n"),
    ("E2: 0-point picks count as a change", ST,
     "if side == nil or (num(obj.Good and obj.Good.Points) <= 0 and num(obj.Evil and obj.Evil.Points) <= 0) then return end",
     "if side == nil then return end"),
    ("E2: an artisan pick never counts", ST, "\t\t\tchangedMind(player, st, obj, option)\n", ""),
    ("E2: a broken saved side kept", ST,
     '\tif st.LastSide ~= "Good" and st.LastSide ~= "Evil" then st.LastSide = nil end', ""),
    ("E3: no title", ST, "\t\tlocal ok, new = pcall(titles.Grant, player, titleId)\n", "\t\tlocal ok, new = false, nil\n"),
    ("E3: TitleBy ignores the pick", ST, 'r.TitleBy[SIDE[st.Pick[id]] or ""]', "r.TitleBy.Good"),
    ("E3: 'New title' for one already owned", ST, "if ok and new == true then notify", "if ok then notify"),
    # (A23-130: 0-point picks and quest starts say nothing any more; "a 0-point pick leans again" / "a sub's Start line
    # back" above cover them)
    ("E5: a hidden sub listed before it is found", ST, " and (not def.Hidden or found) then", " then"),
    ("E5: found from the start", ST, "local found = tr ~= nil and (tr.Claim or num(tr.St, 1) > 1)",
     "local found = tr ~= nil and (tr.Claim or num(tr.St, 1) >= 1)"),
    # chapter 3 (A23-56 main advance + story_depth beta): Trials Say, E7, Reward.Item, the data
    ("Trials Say lines back (A23-130)", ST, "\t\t\t\t\t\ttr.T[sub.Key] = cur\n\t\t\t\t\t\tchanged = true\n",
     "\t\t\t\t\t\ttr.T[sub.Key] = cur\n\t\t\t\t\t\tchanged = true\n"
     "\t\t\t\t\t\tif cur >= sub.Count and sub.Say then notify(player, sub.Say, \"info\") end\n"),
    ("E7: everyone counts as graduated", ST, "\t\treturn ok and rookie == false\n", "\t\treturn true\n"),
    ("E7: nobody graduates", ST, "\t\treturn ok and rookie == false\n", "\t\treturn false\n"),
    ("Reward.Item never given", ST, "\tif type(def.Reward) == \"table\" and def.Reward.Item then\n",
     "\tif false then\n"),
    ("M3_4: Dibs pays nothing", C, 'Label = "Keep it. Goblins stole it first!", Points = 3, Reward = { Gold = 192 } },',
     'Label = "Keep it. Goblins stole it first!", Points = 3 },'),
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
     '\t\t\t\t\tHorns = { Text = "Gold from monsters %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 80 } } },',
     '\t\t\t\t},'),
    ("the hero statue outside Halo Citadel", C, "Landmarks.HeroStatue = Vector3.new(0, 0, -370)",
     "Landmarks.HeroStatue = Vector3.new(0, 0, -200)"),
    ('A23-64 review: the pick does not save its faction', ST, 'st.TownLast, st.TownFaction = id, faction(player) -- A23-64',
     'st.TownLast, st.TownFaction = id, nil -- A23-64'),
    ("A23-64 review: another faction's pick is voiced", ST, 'if not side or (st.TownFaction ~= nil and st.TownFaction ~= f) then return "" end',
     'if not side then return "" end'),
    ('A23-64 review: no TownPick update on a faction switch', ST, '\t\t\t\tif data then publishTownPick(player, story(data)) end\n\t\t\tend)',
     '\t\t\t\tlocal _ = data\n\t\t\tend)'),
    ("A23-64 review: the backfill ignores the save's faction", ST, '(type(fs) ~= "table" or fs[data.Faction] == true) then st.TownLast = id end',
     'true then st.TownLast = id end'),
    ("A23-64 review: the artisan's M3_4 B gets the vault line", C, '\t\t\t\tEvil = { M3_4 = "Sold the dust back? Business is business!" },\n',
     ''),
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
    # A23-64 ② the afterglow (zone_check_halo #39)
    ("A23-64: a story pick never glows", ST,
     "\tafterglow(player, option, \"Story\") -- A23-64 ②: every story pick, a 0-point one too (A23-70 Lunch1)\n", ""),
    ("A23-64: the afterglow goes to everyone in a PvP area", ST, "local private = not okZ or pvp ~= false", "local private = false"),
    ("A23-64: an unknown zone counts as safe", ST, "local private = not okZ or pvp ~= false", "local private = okZ and pvp == true"),
    ("A23-64: the afterglow goes only to the chooser everywhere", ST,
     "pcall(Net.Fx, private and player or nil, \"Afterglow\", payload)", "pcall(Net.Fx, player, \"Afterglow\", payload)"),
    ("A23-64: Private is not sent", ST, "Seconds = math.max(1, num(A.Seconds, 60)), Private = private }",
     "Seconds = math.max(1, num(A.Seconds, 60)) }"),
    ("A23-64: Seconds not read from Config", ST, "Seconds = math.max(1, num(A.Seconds, 60))", "Seconds = 60"),
    ("A23-64: the switch is ignored", ST,
     "if type(A) ~= \"table\" or A.Enabled ~= true or (side ~= \"Good\" and side ~= \"Evil\") then return end",
     "if type(A) ~= \"table\" or (side ~= \"Good\" and side ~= \"Evil\") then return end"),
    ("A23-64: a time-up card glows", ST, "or (side ~= \"Good\" and side ~= \"Evil\") then return end", "or side == nil then return end"),
    ("A23-64: From is ignored", ST, "\tif type(A.From) == \"table\" and A.From[from] ~= true then return end\n", ""),
    ("A23-64: a Neutral B glows gold", ST, "choiceFx(player, option == \"A\" and \"Good\" or \"Evil\")",
     "choiceFx(player, option == \"B\" and \"Good\" or \"Evil\")"),
    ("A23-64: choice cards never glow", ST,
     "\t\tcards.Picked:Connect(function(player, _, side) afterglow(player, side, \"Card\") end)\n", ""),
    ("A23-64: the finisher card never glows", ST, "\t\tfinisher.Picked:Connect(function(player, pick)\n",
     "\t\tlocal _ = (function(player, pick)\n"),
    ("A23-64: Tickle glows gold", ST, "(pick == \"Tickle\" and \"Evil\")", "(pick == \"Tickle\" and \"Good\")"),
    ("A23-64: a player who left still glows", ST,
     " or not player:IsA(\"Player\") or player.Parent ~= Players then return end", " or not player:IsA(\"Player\") then return end"),
    ("Config: the afterglow lasts 30 s", C, "\tSeconds = 60, -- A23-64 ②: how long it stays at the feet",
     "\tSeconds = 30, -- A23-64 ②: how long it stays at the feet"),
    ("Config: the afterglow is off", C, "\tEnabled = true, -- A23-64 ②: the afterglow switch",
     "\tEnabled = false, -- A23-64 ②: the afterglow switch"),
    ("Config: the finisher card does not glow", C, "From = { Story = true, Card = true, Finisher = true },",
     "From = { Story = true, Card = true },"),
    # A23-64 ① the last town pick (attribute TownPick, data.Story.TownLast; town picks = Config.TownReact.Order)
    ("A23-64: a town pick is not saved", ST,
     "\t\t\tst.TownLast, st.TownFaction = id, faction(player) -- A23-64 ①: the townsfolk remember this town pick (saved; its side = SIDE[st.Pick[id]])\n", ""),
    ("A23-64: every pick is a town pick at the pick", ST, "\t\tif isTownPick(id) then\n", "\t\tif true then\n"),
    ("A23-64: every quest counts as a town quest", ST,
     "return type(id) == \"string\" and type(R) == \"table\" and type(R.Order) == \"table\" and table.find(R.Order, id) ~= nil",
     "return type(id) == \"string\""),
    ("A23-64: TownPick not sent at the pick", ST, "\t\t\tpublishTownPick(player, st)\n", ""),
    ("A23-64: no TownPick at join", ST,
     "\t\t\tpublishTownPick(player, story(data)) -- A23-64 ①: TownPick from the save (sanitize backfilled it)\n", ""),
    ("A23-64: no backfill at join", ST, "\t\t\tif SIDE[st.Pick[id]] ~= nil and (type(fs) ~= \"table\" or fs[data.Faction] == true) then st.TownLast = id end\n", ""),
    ("A23-64: the backfill keeps the first, not the last", ST, "fs[data.Faction] == true) then st.TownLast = id end",
     "fs[data.Faction] == true) and st.TownLast == nil then st.TownLast = id end"),
    ("A23-64: a saved TownLast is thrown away at join", ST, "\tif townPickOf(st, st.TownFaction or data.Faction) == \"\" then\n", "\tif true then\n"),
    ("A23-64: a bad saved TownLast is kept", ST, "\tif townPickOf(st, st.TownFaction or data.Faction) == \"\" then\n", "\tif st.TownLast == nil then\n"),
    ("A23-64: TownPick holds the raw pick", ST, "local side = isTownPick(id) and SIDE[st.Pick[id]] or nil",
     "local side = isTownPick(id) and st.Pick[id] or nil"),
    # A23-64 ① Config.TownReact (lines in Config.TownReact.Text) / Config.TownReactLines
    ("Config: TownReact talks every 10 s", C, "\tEvery = 30, -- s between two lines of one town person (A23-64 ①)",
     "\tEvery = 10, -- s between two lines of one town person (A23-64 ①)"),
    ("Config: H2 left out of the Order", C, "\"S6\", \"H1\", \"R1\", \"H2\", \"R5\",", "\"S6\", \"H1\", \"R1\", \"R5\","),
    ("Config: a 14-word line", C, "\"Prank 201! Same as 200! Classic!\"",
     "\"Prank 201! Same as 200! Classic! We love pranks so much, you know, really!\""),
    ("Config: a mean word", C, "\"Hey, Rascal! No pranks today, okay?\"", "\"Hey, Rascal! I hate pranks today, okay?\""),
    ("Config: Rose is a he again", C, "\"You gave Rose her sack back? How nice…\"",
     "\"You gave Rose his sack back? How nice…\""),
    ("TownReactLines: the pick said in any town", C, " or p.Town ~= Config.HomeZoneId(f) then return out, nil end",
     " then return out, nil end"),
    ("TownReactLines: the own town compared with the faction name", C, "p.Town ~= Config.HomeZoneId(f)", "p.Town ~= f"),
    ("TownReactLines: a Halo-only pick said in Horns Den", C, "(type(def.Factions) == \"table\" and not def.Factions[f])", "false"),
    ("TownReactLines: no lean lines", C, "\t\t\tfor _, line in T.Lean[id] or {} do table.insert(out, line) end\n", ""),
    ("TownReactLines: one rank too high", C, "byRank[math.clamp(rank, 1, #byRank)]", "byRank[math.clamp(rank + 1, 1, #byRank)]"),
    ("TownReactLines: the faction's own lines ignored", C, "local line = (type(own) == \"table\" and own[id]) or",
     "local line = (false) or"),
    ("TownReactLines: Infamy counts for a Halo", C, "Config.GetTitle(f, tonumber(p.Honor) or 0, tonumber(p.Infamy) or 0)",
     "Config.GetTitle(f, tonumber(p.Infamy) or 0, tonumber(p.Infamy) or 0)"),
    ("TownReactLines: the switch is ignored", C,
     "if type(R) ~= \"table\" or R.Enabled ~= true or type(R.Text) ~= \"table\" or type(p) ~= \"table\" then return out, nil end",
     "if type(R) ~= \"table\" or type(R.Text) ~= \"table\" or type(p) ~= \"table\" then return out, nil end"),
    ("TownReactLines: a player without a side gets lines", C,
     "if f ~= \"Halo\" and f ~= \"Horns\" and f ~= \"Neutral\" then return out, nil end", "if f == nil then return out, nil end"),
    ("a Neutral save gets the Halo / Horns subs", C,
     'Kind = "Sub", Title = "The Crown War Is Close", ShortName = "Crown War", Factions = { Halo = true, Horns = true },',
     'Kind = "Sub", Title = "The Crown War Is Close", ShortName = "Crown War",'),
    # A23-113 #6: the five Halo people's own reaction lines
    ("own lines: Npc never read", C, 'local own = type(p.Npc) == "string" and', 'local own = false and type(p.Npc) == "string" and'),
    ("own lines: the shared rank lines are mixed in", C,
     "\tif type(ownLine) == \"string\" then\n\t\ttable.insert(out, ownLine)\n\telse\n\t\tlocal byRank",
     "\tif type(ownLine) == \"string\" then\n\t\ttable.insert(out, ownLine)\n\tend\n\tdo\n\t\tlocal byRank"),
    ("own lines: the own rank line is never used", C, "\tif type(ownLine) == \"string\" then\n\t\ttable.insert(out, ownLine)\n", "\tif false then\n\t\ttable.insert(out, ownLine)\n"),
    ("own lines: the own lean line is never used", C, "\t\t\tif type(ownLean) == \"string\" then\n", "\t\t\tif false then\n"),
    ("own lines: the lean falls back never", C, "\t\t\telseif type(T.Lean) == \"table\" then\n\t\t\t\tfor _, line in T.Lean[id] or {} do table.insert(out, line) end\n", "\t\t\telse\n"),
    ("own lines: the rank index ignores the rank", C, "ownLine = ownRank[math.clamp(rank, 1, #ownRank)]", "ownLine = ownRank[1]"),
    ("own lines: Gleam is not a town person", C, "\t\t\tGleam = { -- the town knight", "\t\t\tGleam_ = { -- the town knight"),
    ("own lines: a Bright line is too long", C, "\"Archangel! I'm too happy to talk!\"",
     "\"Archangel! I'm so happy that I truly cannot say one more word to you today!\""),
    ("own lines: Bright says he", C, "\"Knight! Your halo is glowing today!\"", "\"Knight! He is glowing today!\""),
    ("own lines: a line is a shared one", C, "\"Welcome, Squire! I'm Bright. Stay shiny!\"", "\"Welcome, little Squire!\""),
    ("own lines: the baker has no guild line", C, "\t\t\t\t\tNeutral = \"A crafter! Can you fix my oven?\",\n", ""),
    ("own lines: the juice man has no lean line", C, "\t\t\t\t\tBalanceWalker = \"Kind or sneaky? Mixed juice for you!\",\n", ""),
    ("own lines: a lean line of no My Way name", C, "\t\t\t\t\tSoftDevil = \"A sweet devil! Mango for you!\",", "\t\t\t\t\tSoftDevil = \"A sweet devil! Mango for you!\",\n\t\t\t\t\tNobody = \"Who?\","),
    ("own lines: a scary word", C, "\"Warlord! Don't squeeze my bottles!\"", "\"Warlord! Don't scary bottles!\""),
    # --- quest P1 ① (docs/design/quest_p1_server_contract_2026-10-15.md)
    ("P1: an offer without the NPC's body", ST, "if npc and npcBody(npc) and requirementsMet(player, data, def) then offers[npc] = true end",
     "if npc and requirementsMet(player, data, def) then offers[npc] = true end"),
    ("P1: Accept without the body", ST, "if not offerable(player, data, id) or not nearBody(player, npc) then return false end",
     "if not offerable(player, data, id) then return false end"),
    ("P1: Offer.Npc by side ignored", ST, "\tif type(npc) == \"table\" then npc = npc[faction(player)] end\n", "\tif type(npc) == \"table\" then npc = npc.Halo end\n"),
    ("P1: no reward preview", ST, "Reward = reward })", "Reward = nil })"),
    ("P1: the preview forgets GoldN", ST, "\tif num(r.GoldN) > 0 then g += math.floor(num(r.GoldN)) end\n\tif num(r.XPBar) > 0 then x += math.floor(Config.XPToNext(level) * num(r.XPBar)) end\n\tlocal out = {}",
     "\tlocal out = {}"),
    ("P1: no accept scene", ST, "if type(def.Offer.AcceptScene) == \"string\" then scene(player, id, def.Offer.AcceptScene, npc) end", ""),
    ("P1: an offered main starts by itself", ST, "if def and type(def.Offer) == \"table\" and npc and npcBody(npc) then", "if false then"),
    ("P1: an offered main ignores its level", ST,
     "\t\t\tif requirementsMet(player, data, def) then offers[npc] = true end", "\t\t\toffers[npc] = true"),
    ("P1: a main never offered", ST, "if main and offerNpc(player, DEFS[main]) == npcId and offerable(player, data, main) then table.insert(out, main) end", ""),
    ("P1: a practice swing from anywhere", ST, "Util.FlatDistance(ev.Pos, spot) > num(obj.Radius, 8) then return 0 end", "false then return 0 end"),
    ("P1: a practice swing facing away", ST, "look.Unit:Dot(to.Unit) < num(SQ.PracticeFacing, 0.3) then return 0 end", "false then return 0 end"),
    ("P1: no PracticeTool", ST, "if player:GetAttribute(\"PracticeTool\") ~= practice then player:SetAttribute(\"PracticeTool\", practice) end", ""),
    ("P1: swings not heard", ST, "\t\tcombat.BasicSwing:Connect(onBasicSwing)\n", ""),
    ("P1: an emote anywhere", ST, "if not spot or not root or Util.FlatDistance(root.Position, spot) > num(obj.Radius, 10) then return end", "if false then return end"),
    ("P1: any emote", ST, "\tif side ~= \"Good\" and side ~= \"Evil\" then return end\n\tlocal spot = landmark(obj.Spot)", "\tside = side or \"Good\"\n\tlocal spot = landmark(obj.Spot)"),
    ("P1: the emote's flag never written", ST, "\tflagBySide(player, data, id, obj.Flag, side)\n\tStoryQuestService.Picked", "\tStoryQuestService.Picked"),
    ("P1: StoryFlags never set", ST, "if player:GetAttribute(\"StoryFlags\") ~= value then player:SetAttribute(\"StoryFlags\", value) end", ""),
    ("P1: no scene Fx", ST, "local ok, err = pcall(Net.Fx, player, \"StoryScene\", { Id = id, Key = key, Value = value })", "local ok, err = true, nil"),
    ("P1: a bad flag kept", ST, "\t\t\tst.Flags[k] = nil\n", ""),
    ("P1: the match answer sent", ST, "{ Id = id, Target = obj.Target, Options = options }", "{ Id = id, Target = obj.Target, Options = options, Answer = table.find(options, obj.Target) }"),
    ("P1: any match pick passes", ST, "\t\tif pick == p.Answer then", "\t\tif true then"),
    ("P1: timing too soon passes", ST, "\t\tand os.clock() - num(p.At) >= num(SQ.TimingMinSeconds, 2)\n", "\n"),
    ("P1: timing few good taps pass", ST, "and good >= math.floor(num(SQ.TimingPass, 3))", "and good >= 0"),
    ("P1: timing good over tries", ST, "and good <= tries and", "and"),
    ("P1: an answer without a panel", ST, "\tif type(p) ~= \"table\" or p.Kind ~= action or type(option) ~= \"string\" then return end\n",
     "\tif type(option) ~= \"string\" then return end\n\tp = p or { Kind = action, At = -1e9, Answer = tonumber(option) }\n"),
    ("P1: Learn passes at once", ST, "\t\t\t\tdone = learned(data, obj.Slot)", "\t\t\t\tdone = true"),
    ("P1: the learn gate always open", ST, "\treturn step ~= nil and type(step.Obj) == \"table\" and step.Obj.Type == \"Learn\" and (step.Obj.Slot or \"Q\") == slot\n",
     "\treturn true\n"),
    # --- quest P1 ③
    ("P1: M1_1 starts by itself", C, "\t\t\tOffer = { Npc = \"Otto\", Lines = {\n\t\t\t\tHalo = { \"Otto: Please free", "\t\t\tOffer_ = { Npc = \"Otto\", Lines = {\n\t\t\t\tHalo = { \"Otto: Please free"),
    ("P1: Lunch1 only before M1_1 again", C, "\t\t\tRequires = { TutorialDone = true },\n\t\t\tOffer = { Npc = \"Tiny\"", "\t\t\tRequires = { TutorialDone = true, NotDone = { \"M1_1\" } },\n\t\t\tOffer = { Npc = \"Tiny\""),
    ("P1: the lunchbox picked up by standing there", C, "Obj = { Type = \"Pickup\", Spot = \"Lunchbox\", Radius = 10 }", "Obj = { Type = \"Near\", Spot = \"Lunchbox\", Radius = 10 }"),
    ("P1: old Lunch1 saves not moved", ST, "\tmigrate(st)\n", ""),
    ("P1: the migration every join", ST, "\tst.Schema = 2\n", ""),
    ("P1: an old pond hunt loses its count", ST, "\t\tif old ~= 2 then tr.P, tr.T = 0, {} end\n", "\t\ttr.P, tr.T = 0, {}\n"),
    ("P1: the band before Lv3", C, "\tRequires = { Done = { \"M1_1\" }, Level = 3 },\n\tOffer = { Npc = \"Bright\"", "\tRequires = { Done = { \"M1_1\" } },\n\tOffer = { Npc = \"Bright\""),
    ("P1: the band's flag never written", C, "\t\t\t\tFlag = { Key = \"Band\", Good = \"Show\", Evil = \"Hide\" } } },", "\t\t\t\tFlag_ = { Key = \"Band\", Good = \"Show\", Evil = \"Hide\" } } },"),
    ("P1: the choice flag ignored", ST, "\t\t\tflagBySide(player, data, id, obj.Flag, option) -- P1 ①-4\n", ""),
    # --- quest P1 ⑤
    ("P1: an artisan's own craft not recognised", ST, "\t\tif role == \"Own\" then", "\t\tif false then"),
    ("P1: old M1_3 saves not moved", ST, "\t\tif st.Main.Id == \"M1_3\" then st.Main.St, st.Main.P, st.Main.T, st.Main.Claim = 1, 0, {}, false end\n", ""),
    ("P1: no learn gate", C, "Config.Skills.Learn.Gate = { Q = \"M1_3\" }", "Config.Skills.Learn.Gate = nil"),
    ("P1: the test counts skill kills", C, "Obj = { Type = \"BasicKill\", Kind = \"Slime\", Count = 4 } },\n\t\t\t\t{ Text = \"Pick up the lost bag\"",
     "Obj = { Type = \"Kill\", Kind = \"Slime\", Count = 4 } },\n\t\t\t\t{ Text = \"Pick up the lost bag\""),
    # --- quest P1 ⑦
    ("P1: the craft scene not by class", ST, "\t\tif value == \"Class\" then -- P1 ⑦", "\t\tif false then -- P1 ⑦"),
    ("P1: old M1_4 saves not moved", ST, "\t\tif st.Main.Id == \"M1_4\" and st.Main.Claim ~= true then st.Main.St, st.Main.P, st.Main.T = 1, 0, {} end\n", ""),
    ("P1: the lamp leaves no flag", C, "\t\t\t\t\t\tNeutral = { A = \"Light the town lamp\", B = \"Light my work lamp\" },\n\t\t\t\t\t\tFlag = { Key = \"Lamp\", Good = \"Common\", Evil = \"Mine\" } },",
     "\t\t\t\t\t\tNeutral = { A = \"Light the town lamp\", B = \"Light my work lamp\" } },"),
    ("P1: the lamp picks have no side", ST, "\tCommon = \"Good\", Mine = \"Evil\" } -- P1 ⑦ M1_4's lamp", "\tCommon_ = \"Good\" } -- P1 ⑦ M1_4's lamp"),
    ("P1: the bag leaves no scene", C, "\t\t\t\t\tSetFlag = { Key = \"Help\", Value = \"Bag\" }, -- P1 ⑦", "\t\t\t\t\t-- P1 ⑦"),
    # --- quest P1 ④
    ("P1: old N0 saves not moved", ST, "\t\t\tif type(tr) == \"table\" and math.floor(num(tr.St, 1)) >= 2 then tr.St = math.floor(num(tr.St, 1)) + 1 end\n", ""),
    ("P1: the order tag gone", C, "\t\t\t\t\tObj = { Type = \"Match\", Target = \"Knot\", Wrong = { \"Seal\", \"Tag\" } } }, -- P1 ④ (bible N03: the order box)\n",
     "\t\t\t\t\tObj = { Type = \"Talk\" } }, -- P1 ④ (bible N03: the order box)\n"),
    ("P1: N0 before Lv3", C, "\t\t\tRequires = { TutorialDone = true, Level = 3, Feature = { \"Gathering\", \"Crafting\" }, Classes = { Warrior = true } },",
     "\t\t\tRequires = { TutorialDone = true, Feature = { \"Gathering\", \"Crafting\" }, Classes = { Warrior = true } },"),
    ("P1: the Lv5 test before Lv5", C, "\t\t\tRequires = { Level = 5 },\n\t\t\tSteps = {\n\t\t\t\t{ Text = \"Beat slimes using only basic attacks", "\t\t\tSteps = {\n\t\t\t\t{ Text = \"Beat slimes using only basic attacks"),
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
    # only the story table (Config.Gather.Text has a button label 'Pick = "Pick"', 2026-10-12)
    sq = re.search(r"^Config\.StoryQuests = \{.*?^\}", config, re.S | re.M)
    picks = set(re.findall(r'Pick = "(\w+)"', sq.group(0))) if sq else set()
    check(bool(picks) and picks <= side_keys,
          f"every Pick in Config.StoryQuests has a side in SIDE (missing: {sorted(picks - side_keys)})")
    # A23-64: the afterglow leaves from one place (afterglow, through Net.Fx) and TownPick is set in one place
    check(story.count('"Afterglow", payload') == 1, "StoryQuestService sends Fx Afterglow from one place (afterglow)")
    check(story.count('SetAttribute("TownPick"') == 1, "the TownPick attribute is set in one place (publishTownPick)")
    # A23-64 ①: game dev 1's TownReact looks up the bodies TownNpcs tags for the town people (Folk entries)
    town_npcs = read(SSS / "TownNpcs.luau")
    folk_tag = re.search(r'elseif entry\.Folk then\s+CollectionService:AddTag\(npc, "(\w+)"\)', town_npcs)
    react_tag = re.search(r'^Config\.TownReact = \{.*?^\tTag = "(\w+)",', config, re.S | re.M)
    check(bool(folk_tag and react_tag) and folk_tag.group(1) == react_tag.group(1),
          "Config.TownReact.Tag = the tag TownNpcs gives the town people (Folk)")
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
             "step 1 / claim); a 0-point pick says LeanGood / LeanEvil (no score line). A23-64 ② (zone_check_halo #39): every "
             "story pick (0-point and Neutral A / B too), a ChoiceCard Good / Evil pick and a finisher Help / Tickle "
             "send one Fx Afterglow { UserId, Side, Seconds = Config.Afterglow.Seconds (60), Private } to every client, "
             "or only to the chooser in a PvP area (an unknown zone counts as PvP); None / Enabled off / From off = none. "
             "A23-64 ①: a Config.TownReact.Order quest's pick saves Story.TownLast and sets the attribute TownPick "
             "'<id>:Good|Evil' (Neutral A / B = their side); a join backfills it (bad / missing = the last of "
             "TownReact.Order with a saved pick). Config.TownReactLines: rank + lean + the town pick; the town pick is "
             "said only in the player's own town (npc Town == Config.HomeZoneId(faction), zone ids) and only to the "
             "quest's own factions (Defs[id].Factions); lines live in Config.TownReact.Text (Good / Evil by quest id, "
             "FactionPick overrides); every line <= 12 words, no format tokens, no scary words, Bright / Smokey = she. "
             "Config.TownReact.Tag = the tag TownNpcs gives its Folk bodies, which stand in a town zone. "
             "빛 마을 점검 2026-10-10: every Halo-only "
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
