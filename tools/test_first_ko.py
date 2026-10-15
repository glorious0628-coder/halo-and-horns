"""A23-109 / A23-110 the King's Hop quest KO1 (게임성 개발 3, 2026-10-10), offline.

Design docs/design/first_ko_quest_2026-10-10.md (검수 approved the numbers 2026-10-10): after the Slime Prince (M1_1) a new player
with no potions (Lv <= 8) gets the side quest KO1 as five plain rows - no popup, no toast: 1 Defeat the King Slime (game dev 2's
personal King hops over and lands on the player: a lossless KO, reported with StoryQuestService.Event "FirstKO"), 2 Buy a
potion (the step opens with the carried gold topped up to 50 = two potions; ShopService.BuyPotion reports "PotionBought"),
3 Put the potion in a quick slot (a new player's slots start empty; QuickSlotService reports "QuickSlotSet"; an old save whose
slots already hold HP / MP passes it at once), 4 Drink it from your quick slot (VitalsService reports "PotionUsed"; at full HP / MP
a practice sip counts for the step and keeps the potion, so the step never dead-ends), 5 Defeat the King Slime again (a PERSONAL King kill in the meadow); the
reward is two minutes of hunting gold + XP and one 70% scroll. A step whose happening was seen before it opened passes at once.
Runs the CURRENT Config, Util, StoryQuestService, LootService and CombatService (the dev2_combat_world doubles for the other
services) with tools/fixtures/first_ko_offline.luau and the installed official Luau CLI. The shop / drink hooks are checked in
tools/test_potions.py. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_first_ko.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_first_ko_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
C, ST = "CONFIG_SOURCE", "STORY_SOURCE"
FILES["VITALS_SOURCE"] = SSS / "VitalsService.luau"
FILES["QUICK_SOURCE"] = SSS / "QuickSlotService.luau"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = unarmed_bindings(sources)
    out["QUICK_SOURCE"] = sources["QUICK_SOURCE"]  # the real QuickSlotService runs in the brand-new-save group
    out["DATA_SOURCE"] = sources["DATA_SOURCE"]  # ... and the real DataService builds its memory-mode record
    return out

DEF_STEP2 = 'Obj = { Type = "Event", Name = "PotionBought", Past = true } },'
DEF_STEP3 = 'Obj = { Type = "Event", Name = "QuickSlotSet", Past = true, Held = "QuickSlots" } },'
DEF_STEP4 = 'Obj = { Type = "Event", Name = "PotionUsed", Past = true } },'
DEF_STEP5 = 'Obj = { Type = "Kill", Kind = "SlimeKing", Zone = "SlimeMeadow", Personal = true, Count = 1 } },'

MUTATIONS = [
    # the definition
    ("KO1 opens before M1_1", C, 'Requires = { Done = { "M1_1" }, MaxLevel = 8, NoPotionYet = true, KingOn = true },',
     'Requires = { MaxLevel = 8, NoPotionYet = true, KingOn = true },'),
    ("KO1 has no level cap", C, 'Requires = { Done = { "M1_1" }, MaxLevel = 8, NoPotionYet = true, KingOn = true },',
     'Requires = { Done = { "M1_1" }, NoPotionYet = true, KingOn = true },'),
    ("KO1 level cap 9", C, 'Requires = { Done = { "M1_1" }, MaxLevel = 8, NoPotionYet = true, KingOn = true },',
     'Requires = { Done = { "M1_1" }, MaxLevel = 9, NoPotionYet = true, KingOn = true },'),
    ("KO1 does not need the King", C, 'Requires = { Done = { "M1_1" }, MaxLevel = 8, NoPotionYet = true, KingOn = true },',
     'Requires = { Done = { "M1_1" }, MaxLevel = 8, NoPotionYet = true },'),
    ("KingOn ignored", ST, "\tif req.KingOn and kingOff() then return false end\n", ""),
    ("a started quest stays when the King goes off", ST,
     "elseif st.Subs[id] and type(def.Requires) == \"table\" and def.Requires.KingOn and kingOff() then", "elseif false then"),
    ("the King is never off", ST, "return type(k) == \"table\" and k.Enabled == false", "return false"),
    ("a missing King table counts as off", ST, "return type(k) == \"table\" and k.Enabled == false", "return type(k) ~= \"table\" or k.Enabled == false"),
    ("KO1 is offered to players with potions", C,'Requires = { Done = { "M1_1" }, MaxLevel = 8, NoPotionYet = true, KingOn = true },',
     'Requires = { Done = { "M1_1" }, MaxLevel = 8 },'),
    ("KO1 step 1 passes on an old KO", C, 'Obj = { Type = "Event", Name = "FirstKO" } },',
     'Obj = { Type = "Event", Name = "FirstKO", Past = true } },'),
    ("KO1 step 2 never passes early", C, DEF_STEP2, 'Obj = { Type = "Event", Name = "PotionBought" } },'),
    ("KO1 step 3 never passes early", C, DEF_STEP3, 'Obj = { Type = "Event", Name = "QuickSlotSet", Held = "QuickSlots" } },'),
    ("KO1 step 3 ignores a filled slot", C, DEF_STEP3, 'Obj = { Type = "Event", Name = "QuickSlotSet", Past = true } },'),
    ("KO1 step 3 reads another field", C, DEF_STEP3, 'Obj = { Type = "Event", Name = "QuickSlotSet", Past = true, Held = "Quick" } },'),
    ("KO1 step 3 waits for the wrong happening", C, DEF_STEP3,
     'Obj = { Type = "Event", Name = "PotionBought", Past = true, Held = "QuickSlots" } },'),
    ("KO1 step 4 never passes early", C, DEF_STEP4, 'Obj = { Type = "Event", Name = "PotionUsed" } },'),
    ("KO1 step 4 waits for the wrong happening", C, DEF_STEP4, 'Obj = { Type = "Event", Name = "QuickSlotSet", Past = true } },'),
    ("KO1 step 2 waits for the wrong happening", C, DEF_STEP2, 'Obj = { Type = "Event", Name = "PotionUsed", Past = true } },'),
    ("KO1 guides step 2 to the old spot", C, 'Guide = "PotionShop", TopUpGold = 50,', 'Guide = "Crossroads", TopUpGold = 50,'),
    ("KO1 guides step 3 nowhere", C, 'ShortName = "Quick slot", Guide = "QuickSlot",', 'ShortName = "Quick slot",'),
    ("QuickSlotSet not a listed happening", C, "Config.StoryQuests.Events = { FirstKO = true, PotionBought = true, QuickSlotSet = true, PotionUsed = true }",
     "Config.StoryQuests.Events = { FirstKO = true, PotionBought = true, PotionUsed = true }"),
    ("KO1 tops up to 25 only", C, "TopUpGold = 50,", "TopUpGold = 25,"),
    ("KO1 never tops up", C, "Guide = \"PotionShop\", TopUpGold = 50,", "Guide = \"PotionShop\","),
    ("KO1 rematch counts any King", C, DEF_STEP5,
     'Obj = { Type = "Kill", Kind = "SlimeKing", Zone = "SlimeMeadow", Count = 1 } },'),
    ("KO1 rematch in any zone", C, DEF_STEP5, 'Obj = { Type = "Kill", Kind = "SlimeKing", Personal = true, Count = 1 } },'),
    ("KO1 rematch kills any slime", C, DEF_STEP5,
     'Obj = { Type = "Kill", Kind = "Slime", Zone = "SlimeMeadow", Personal = true, Count = 1 } },'),
    ("KO1 pays no scroll", C, 'Reward = { Gold = 2, XP = 2, Item = "Enh70", N = 1 },', 'Reward = { Gold = 2, XP = 2 },'),
    ("KO1 pays no XP", C, 'Reward = { Gold = 2, XP = 2, Item = "Enh70", N = 1 },', 'Reward = { Gold = 2, Item = "Enh70", N = 1 },'),
    ("KO1 pays no gold", C, 'Reward = { Gold = 2, XP = 2, Item = "Enh70", N = 1 },', 'Reward = { XP = 2, Item = "Enh70", N = 1 },'),
    ("KO1 gets a closing toast", C, 'Reward = { Gold = 2, XP = 2, Item = "Enh70", N = 1 },',
     'Finish = "King Slime: Nap time!", Reward = { Gold = 2, XP = 2, Item = "Enh70", N = 1 },'),
    ("KO1 pops up by itself", C, 'Kind = "Sub", Title = "The King\'s Hop", ShortName = "King\'s hop",',
     'Kind = "Sub", Title = "The King\'s Hop", ShortName = "King\'s hop", Pop = true,'),
    ("KO1 starts with a toast", C, 'Kind = "Sub", Title = "The King\'s Hop", ShortName = "King\'s hop",',
     'Kind = "Sub", Title = "The King\'s Hop", ShortName = "King\'s hop", Start = "The King is coming!",'),
    ("KO1 forgotten in the sub list", C, 'table.insert(Config.StoryQuests.Subs, "KO1")', ""),
    ("KO1 the rematch step moved", C, "RematchStep = 5, SipAttr", "RematchStep = 4, SipAttr"),
    ("KO1 the KO step moved", C, "Config.FirstKO = { Quest = \"KO1\", Step = 1,", "Config.FirstKO = { Quest = \"KO1\", Step = 2,"),
    ("KO1 PotionUsed not a listed happening", C, "Config.StoryQuests.Events = { FirstKO = true, PotionBought = true, QuickSlotSet = true, PotionUsed = true }",
     "Config.StoryQuests.Events = { FirstKO = true, PotionBought = true, QuickSlotSet = true }"),
    ("KO1 no practice-sip line", C, '\tPotionPractice = "Cheers! The potion stays in your bag.",', "\tPotionPracticeX = \"Cheers!\","),
    # the engine
    ("a personal kill counts for a normal kill step", ST, "if (info.Personal == true) ~= (obj.Personal == true) then return 0 end",
     "if obj.Personal == true and info.Personal ~= true then return 0 end"),
    ("a Personal step never counts", ST, "if (info.Personal == true) ~= (obj.Personal == true) then return 0 end",
     "if info.Personal == true then return 0 end"),
    ("a Personal step counts shared kills too", ST, "if (info.Personal == true) ~= (obj.Personal == true) then return 0 end",
     "if info.Personal == true and obj.Personal ~= true then return 0 end"),
    ("NoPotionYet ignores a bought / drunk potion", ST,
     "\tif st.First.PotionBought == true or st.First.PotionUsed == true then return false end\n", ""),
    ("NoPotionYet ignores the stock", ST, "\t\tif key and num(data[key]) > 0 then return false end\n", ""),
    ("NoPotionYet checks only HP", ST, "for _, kind in { \"HP\", \"MP\" } do\n\t\tlocal key = Config.PotionStockKey(kind)",
     "for _, kind in { \"HP\" } do\n\t\tlocal key = Config.PotionStockKey(kind)"),
    ("Requires.MaxLevel ignored", ST, "\tif req.MaxLevel and num(data.Level, 1) > req.MaxLevel then return false end\n", ""),
    ("Requires.MaxLevel off by one", ST, "num(data.Level, 1) > req.MaxLevel then return false end", "num(data.Level, 1) >= req.MaxLevel then return false end"),
    ("Requires.NoPotionYet ignored", ST, "\tif req.NoPotionYet and not noPotionYet(data) then return false end\n", ""),
    ("a seen happening never passes a later step", ST, "\tif story(data).First[obj.Name] == true then return true end\n", ""),
    ("Past ignored (every seen happening passes)", ST, " or obj.Past ~= true then return false end", " then return false end"),
    ("Held ignored (a filled slot does not pass the step)", ST,
     "\treturn type(held) == \"string\" and type(data[held]) == \"string\" and string.find(data[held], \"%a\") ~= nil\n", "\treturn false\n"),
    ("Held counts any text (',,' too)", ST, "string.find(data[held], \"%a\") ~= nil", "data[held] ~= \"\""),
    ("Held counts a missing field", ST, "return type(held) == \"string\" and type(data[held]) == \"string\" and", "return type(held) == \"string\" and"),
    ("the 1 s loop never passes a seen happening", ST, "\t\t\telseif obj.Type == \"Event\" then\n\t\t\t\tdone = eventPast(data, obj)\n",
     "\t\t\telseif obj.Type == \"Event\" then\n\t\t\t\tdone = false\n"),
    ("TopUpGold never paid", ST, "\t\ttopUpGold(player, data, id, track)\n", ""),
    ("TopUpGold not saved first", ST, "\tfirst[key] = true -- saved before the gold, so it can never be paid twice\n", ""),
    ("TopUpGold always pays the full 50", ST, "if have < want then S.ProgressionService.AddCarriedGold(player, want - have, \"Choice\") end",
     "if have < want then S.ProgressionService.AddCarriedGold(player, want, \"Choice\") end"),
    ("TopUpGold pays even when rich", ST, "if have < want then S.ProgressionService.AddCarriedGold(player, want - have, \"Choice\") end",
     "S.ProgressionService.AddCarriedGold(player, want - have, \"Choice\")"),
    ("TopUpGold is doubled by the gold pass", ST, "AddCarriedGold(player, want - have, \"Choice\")", "AddCarriedGold(player, want - have, \"Monster\")"),
    ("TopUpGold counts the carried gold only", ST, "local have = S.ProgressionService.GetTotalGold(player)",
     "local have = math.floor(num(data.CarriedGold))"),
    ("TopUpGold paid for a step that passes at once", ST, "if want <= 0 or eventPast(data, step.Obj) then return end", "if want <= 0 then return end"),
    ("Event names are not checked", ST, "\tif SQ.Events == nil or SQ.Events[name] ~= true then return false end\n", ""),
    ("Event ignores readiness", ST, "\tif not S.PlayerService.IsReady(player) then return false end\n\tlocal data = getData(player)\n\tif not data then return false end\n\tstory(data).First[name] = true",
     "\tlocal data = getData(player)\n\tif not data then return false end\n\tstory(data).First[name] = true"),
    ("Event forgets what it saw", ST, "\tstory(data).First[name] = true\n\tlocal moved = false", "\tlocal moved = false"),
    ("Event moves a step that waits for another name", ST, "if obj and obj.Type == \"Event\" and obj.Name == name then\n\t\t\tadvance(player, data, t.Id, tr)",
     "if obj and obj.Type == \"Event\" then\n\t\t\tadvance(player, data, t.Id, tr)"),
    ("Event never moves a step", ST, "if obj and obj.Type == \"Event\" and obj.Name == name then\n\t\t\tadvance(player, data, t.Id, tr)",
     "if false then\n\t\t\tadvance(player, data, t.Id, tr)"),
    ("Event never refreshes the next step", ST, "\tif moved then\n\t\t-- the steps that pass at once", "\tif false then\n\t\t-- the steps that pass at once"),
    ("Event refreshes only once (one step per call)", ST, "\t\t\tif stepsSum(data) == before then break end\n", "\t\t\tbreak\n"),
    ("Event does not say if it moved", ST, "\t\t\tif stepsSum(data) == before then break end\n\t\tend\n\tend\n\treturn moved\n",
     "\t\t\tif stepsSum(data) == before then break end\n\t\tend\n\tend\n\treturn false\n"),
    ("Wants is always true", ST, "if obj and obj.Type == \"Event\" and obj.Name == name and not eventPast(data, obj) then return true end",
     "if obj and obj.Type == \"Event\" then return true end"),
    ("Wants ignores the name", ST, "if obj and obj.Type == \"Event\" and obj.Name == name and not eventPast(data, obj) then return true end",
     "if obj and obj.Type == \"Event\" and not eventPast(data, obj) then return true end"),
    ("CurrentStep names a quest waiting for [Claim]", ST, "if type(tr) ~= \"table\" or tr.Claim == true or st.Done[id] then return nil end",
     "if type(tr) ~= \"table\" or st.Done[id] then return nil end"),
    # the brand-new Studio save (DataService memory mode) must start with empty slots, or KO1's slot step passes at once
    ("a Studio memory-mode record gets no slots (HP, MP: the slot step passes at once)", "DATA_SOURCE", "\t\tgiveNewQuickSlots(d) -- ", "\t\tlocal _ = d -- "),
    ("a new record gets the slots of an old save (HP, MP)", "DATA_SOURCE", "\t\td.QuickSlots = table.concat(Config.QuickSlots.Default, \",\")\n\tend\nend",
     "\t\td.QuickSlots = \"HP,MP,\"\n\tend\nend"),
    # A23-113 #2: the funnel feed
    ("StepDone never fires", ST, "\tStoryQuestService.StepDone:Fire(player, id, track.St)\n", ""),
    ("StepDone names the next step", ST, "StoryQuestService.StepDone:Fire(player, id, track.St)", "StoryQuestService.StepDone:Fire(player, id, track.St + 1)"),
    # Studio test aids (Main's DebugCommand StorySub / StoryDone)
    ("DebugSub keeps a Done mark", ST, "\tst.Done[id] = nil\n\tlocal track = { St = n", "\tlocal track = { St = n"),
    ("DebugSub starts any quest", ST, 'if not def or def.Kind ~= "Sub" then return "no such sub quest "', 'if not def then return "no such sub quest "'),
    ("DebugSub does not check the step", ST, '\tif n < 1 or n > #def.Steps then return string.format("%s has steps 1-%d", id, #def.Steps) end\n', ""),
    ("DebugSub forgets the step's gold", ST,
     "\ttopUpGold(player, data, id, track)\n\tgiveStepItem(player, data, id, track)\n\tdirty(player)\n\tlocal ok, err = pcall(refresh, player)",
     "\tgiveStepItem(player, data, id, track)\n\tdirty(player)\n\tlocal ok, err = pcall(refresh, player)"),
    ("DebugSub does not round the step", ST, "local n = math.floor(num(step, 1))", "local n = num(step, 1)"),
    ("DebugDone does not mark it done", ST, "\tst.Done[id] = true\n\tst.Subs[id] = nil\n\tif st.Main.Id == id then st.Main = { Id = \"\" } end\n\tdirty(player)\n\treturn \"ok\"",
     "\tst.Subs[id] = nil\n\tif st.Main.Id == id then st.Main = { Id = \"\" } end\n\tdirty(player)\n\treturn \"ok\""),
    ("DebugDone keeps the track", ST, "\tst.Done[id] = true\n\tst.Subs[id] = nil\n\tif st.Main.Id == id then st.Main = { Id = \"\" } end\n\tdirty(player)\n\treturn \"ok\"",
     "\tst.Done[id] = true\n\tif st.Main.Id == id then st.Main = { Id = \"\" } end\n\tdirty(player)\n\treturn \"ok\""),
    ("DebugDone keeps the main quest", ST, "\tif st.Main.Id == id then st.Main = { Id = \"\" } end\n\tdirty(player)\n\treturn \"ok\"", "\tdirty(player)\n\treturn \"ok\""),
    # the client flag (VitalsUI lets a full bar be used while a step waits for the drink)
    ("the sip flag is never published", ST, "\t\tif player:GetAttribute(sipAttr) ~= want then player:SetAttribute(sipAttr, want) end\n", ""),
    ("the sip flag is never cleared", ST, "\t\tif player:GetAttribute(sipAttr) ~= want then player:SetAttribute(sipAttr, want) end\n",
     "\t\tif want and player:GetAttribute(sipAttr) ~= want then player:SetAttribute(sipAttr, want) end\n"),
    ("the sip flag is always on", ST, "local want = wantsEvent(player, data, \"PotionUsed\")\n\t\tif player:GetAttribute(sipAttr)",
     "local want = true\n\t\tif player:GetAttribute(sipAttr)"),
    ("the sip flag waits for the wrong happening", ST, "local want = wantsEvent(player, data, \"PotionUsed\")\n\t\tif player:GetAttribute(sipAttr)",
     "local want = wantsEvent(player, data, \"PotionBought\")\n\t\tif player:GetAttribute(sipAttr)"),
    ("the sip flag has another name", C, 'RematchStep = 5, SipAttr = "PotionSip" }', 'RematchStep = 5, SipAttr = "SipFlag" }'),
    ("the sip flag has no name", C, 'RematchStep = 5, SipAttr = "PotionSip" }', "RematchStep = 5 }"),
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
    shop = read(SSS / "ShopService.luau")
    vitals = read(SSS / "VitalsService.luau")
    config = read(SHARED / "Config.luau")
    for name in ("Event", "Wants", "CurrentStep"):
        check(story.count(f"function StoryQuestService.{name}(") == 1, f"StoryQuestService.{name} is defined once")
    # the happenings: the hooks and the quest steps name exactly the listed ones
    events = re.search(r"^Config\.StoryQuests\.Events = \{(.*?)\}", config, re.M)
    listed = set(re.findall(r"(\w+) = true", events.group(1))) if events else set()
    # added one per line after the table: A23-113 SackMet, gameplay plan 2026-10-13 1-A #2 ScrollUsed (M1_1 step 2)
    later = set(re.findall(r"^Config\.StoryQuests\.Events\.(\w+) = true", config, re.M))
    used = set(re.findall(r'Type = "Event", Name = "(\w+)"', config))
    # C-5 / C-7 (the market): MarketBought / MarketListed / MarketPaid for the market quests MK1-MK3
    check(listed == {"FirstKO", "PotionBought", "QuickSlotSet", "PotionUsed"}
          and later == {"SackMet", "ScrollUsed", "MarketBought", "MarketListed", "MarketPaid"} and used <= (listed | later),
          f"Config.StoryQuests.Events lists the four happenings (+ SackMet, ScrollUsed, the 3 market ones) and the steps use only those ({sorted(used)})")
    check(shop.count('pcall(story.Event, player, "PotionBought"') == 1, "ShopService reports PotionBought once (a successful BuyPotion)")
    buy = function_block(shop, "function M.BuyPotion(")
    check(buy.index("S.PlayerService.SetStat(player, key, count + amount)") < buy.index('"PotionBought"'),
          "PotionBought is reported only after the stock was added (every refusal returns before)")
    check(vitals.count('pcall(story.Event, player, "PotionUsed"') == 2, "VitalsService reports PotionUsed from the real drink and the practice sip")
    use = function_block(vitals, "local function usePotion(")
    check(use.index("S.PlayerService.SetStat(player, stockKey, count - 1)") < use.index('"PotionUsed"'),
          "a real PotionUsed comes after the stock went down")
    check(use.count("practiceSip(player, kind)") == 2, "the practice sip is tried at full HP and at full MP only")
    check(all(token in config for token in ('PotionPractice = "Cheers! The potion stays in your bag."', "Config.FirstKO = {")),
          "the practice-sip line and Config.FirstKO exist")
    # nothing else reports a happening: a client has no way to send one (StoryAction is Open / Talk / Choose, and since
    # A23-199 Accept / Decline an offer, Pickup / Deliver - steps the server checks itself, never a named happening)
    check(story.count("OnServerEvent:Connect(") == 1, "StoryQuestService has one remote handler (StoryAction)")
    check(re.search(r'action == "(?!Open"|Talk"|Choose"|Accept"|Decline"|Pickup"|Deliver")\w+"',
                    function_block(story, "local function onStoryAction(")) is None
          and "StoryQuestService.Event(" not in function_block(story, "local function onStoryAction("),
          "StoryAction has no action that could report a happening")
    data_src = read(SSS / "DataService.luau")
    check(data_src.count("giveNewQuickSlots(d)") == 3 and "local function giveNewQuickSlots(" in data_src,
          "DataService gives new quick slots in BOTH new-record paths (a first DataStore record and the Studio memory-mode record)")
    # the Studio aids live only in Main's Studio block, and they change the save (DebugTainted), so they are not read-only
    main = read(SSS / "Main.server.luau")
    studio = main.index('if game:GetService("RunService"):IsStudio() then')
    read_only = main.split("local READ_ONLY = {")[1].split("}")[0]
    check(main.index('key == "StorySub"') > studio and main.index('key == "StoryDone"') > studio and main.count('key == "StorySub"') == 1,
          "StorySub / StoryDone exist once, inside Main's IsStudio block")
    check("StorySub" not in read_only and "StoryDone" not in read_only, "StorySub / StoryDone change the save: they taint it (not read-only)")
    check("S.StoryQuestService.DebugSub(player" in main and "S.StoryQuestService.DebugDone(player" in main, "Main calls the two StoryQuestService aids")
    return count, failures


SUITE = Suite(
    mark="FIRST_KO",
    fixture=ROOT / "tools/fixtures/first_ko_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_first_ko_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-109 / A23-110: the sub KO1 'The King's Hop' starts by itself after M1_1 for a Lv <= 8 save with no potion (no stock, "
             "none bought or drunk, Requires.MaxLevel / NoPotionYet), as a plain row (no popup, no toast, no Start / Finish): "
             "Defeat the King Slime (Event FirstKO) -> Buy a potion (Event PotionBought, TopUpGold 50: the missing part of 50 "
             "gold is added to the carried gold once, source Choice, nothing when already rich or when the step passes at once) "
             "-> Put the potion in a quick slot (Event QuickSlotSet; Held = data.QuickSlots with a letter in it passes it at once) "
             "-> Drink it from your quick slot (Event PotionUsed) -> Defeat the King Slime (a Personal kill: only a "
             "personal King Slime in the meadow counts, shared kills never) -> two minutes of hunting gold + XP and one 70% scroll, "
             "once. StoryQuestService.Event(player, name, info) = the one way a service reports a named happening (listed in "
             "Config.StoryQuests.Events; unknown names, non-players, players not ready: nothing): it is saved in "
             "data.Story.First[name] first, the open Event step that waits for it moves on, the next steps are checked at once; "
             "an Event step with Past passes at once when its happening was seen before it opened (never a dead end for a player "
             "who ran ahead); a client has no way to report one (StoryAction is Open / Talk / Choose and an Event step has no "
             "panel). Wants(player, name) = a step waits for it; CurrentStep(player, id) = the step of a started quest. "
             "Config.FirstKO = { Quest, Step, RematchStep } is what game dev 2's personal King reads.",
    limitations="The shop / drink hooks and the practice sip (full HP / MP) are tested in tools/test_potions.py. The personal King "
                "itself (hop, landing, lossless KO, rematch numbers) is game dev 2's; the row guide, the quick-slot highlight and "
                "the KO screen are game dev 1's. The 1 s loop timing is modelled by calling Refresh by hand.",
)

if __name__ == "__main__":
    run(SUITE)
