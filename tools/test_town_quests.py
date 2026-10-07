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
    ("E0: Lv25+ skips only chapters 1-2", C, "SkipChapters = { { Level = 10, UpTo = 2 }, { Level = 25, UpTo = 3 } },",
     "SkipChapters = { { Level = 10, UpTo = 2 } },"),
    ("no clue toast", ST, "\tif def.Clue then notify(player, def.Clue, \"info\") end", "\tlocal _ = def.Clue"),
    ("the Halo bridge spot moves away", C, "Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -161)",
     "Config.StoryQuests.Landmarks.HaloBridge = Vector3.new(0, 0, -100)"),
    ("B pays no gold", C, 'Reward = { Potion = "HP", N = 3, Gold = 60 } } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5 },\n\t\t\tFinish = "Smokey: So who',
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
    ("a started sub ranks like an untouched one", ST, '((started or id == "S0") and 2)', '(id == "S0" and 2)'),
    ("a new offer outranks the subs in progress", ST, "((tr.Claim or (waiting and started)) and 0)", "((tr.Claim or waiting) and 0)"),
    ("older quests first within a rank", ST, "\t\treturn a.Order > b.Order\n", "\t\treturn a.Order < b.Order\n"),
    ("the sort fields reach the client", ST, "\t\trows[i].Rank, rows[i].Order = nil, nil\n", ""),
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
    ("E5: a hidden sub's Start toast", ST, "if def.Start and not def.Hidden then notify", "if def.Start then notify"),
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
    ("camp 1 outside the woods", C, "Landmarks.GoblinCamp1 = Vector3.new(660, 0, -60)",
     "Landmarks.GoblinCamp1 = Vector3.new(400, 0, -60)"),
    # quest_volume §3-2: the 18 subs
    ("GW7 not waiting for GW1", C, 'Requires = { Done = { "GW1" }, Level = 21 },', 'Requires = { Done = { "M2_7" }, Level = 21 },'),
    ("XR1 before the first ten minutes", C,
     'Kind = "Sub", Title = "Lost & Found", ShortName = "Lost bear", Speaker = "Tiny",\n\t\t\tRequires = { Done = { "M1_4" }, Level = 5 },',
     'Kind = "Sub", Title = "Lost & Found", ShortName = "Lost bear", Speaker = "Tiny",\n\t\t\tRequires = { Done = { "M1_1" }, Level = 1 },'),
    ("a woods-type B pays the town gold", C,
     'Evil = { Label = "Draw a mustache on him", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 192 } },',
     'Evil = { Label = "Draw a mustache on him", Points = 1, Reward = { Potion = "HP", N = 3, Gold = 60 } },'),
    ("S6 for Horns without its gold step", C,
     '\t\t\t\t\tHorns = { Text = "Hunting gold %d/%d", Obj = { Type = "EarnGold", Source = "Monster", Count = 80 } } },',
     '\t\t\t\t},'),
    ("the hero statue outside Halo Citadel", C, "Landmarks.HeroStatue = Vector3.new(0, 0, -360)",
     "Landmarks.HeroStatue = Vector3.new(0, 0, -200)"),
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
    check("Config.Features = { NeutralFaction = false }" in config, "A23-57 switch present and off")
    check('Config.FactionOrder = { "Halo", "Horns", "Neutral" }' in config,
          "Config.FactionOrder untouched (game dev 1's picker reads the switch, A23-57)")
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
             "Enh70, B = 3 HP potions + 60 gold, 1 honor / infamy point, Neutral A / B recorded only) -> +120 gold + half "
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
             "step 1 / claim); a 0-point pick says LeanGood / LeanEvil (no score line).",
    limitations="NPC models, '!' markers, the talk window and the quest marker routes are game dev 1's (contract: tag "
                "StoryNpc, attribute NpcId, row Story.Npc / Guide). Real walking, physics and the 1 s loop timing are "
                "modelled by moving the root and calling Refresh each second.",
)

if __name__ == "__main__":
    run(SUITE)
