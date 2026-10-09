"""A23-86 Sprout Oath + the graduation side line (content_beyond_10min G) (게임성 개발 3, 2026-10-09), offline.

M3_5 'Sprout Graduation' leaves the main chain (M3_4 -> M3_6) and becomes a side line (row 'Sprout Shield on · ends at Lv15 +
1 hour of play', no minute numbers); a saved in-progress M3_5 moves to the side lines; an old Lv25+ save skips it. Two oath subs
(OathH Halo / OathR Horns) open at Lv15 after M3_4 while the Sprout Shield is still on: a short training (Halo: guard the woods
bridge 15 s + one Goblin Brute; Horns: two goblin camps + one Goblin Brute with basic hits), then an oath card, 2 points each way
(A23-58) and a stat-free title (Guardian Cadet / Rascal Cadet). Runs the CURRENT Config, Util and StoryQuestService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/sprout_oath_offline.luau and the installed
official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_sprout_oath.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_sprout_oath_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
}
C, ST = "CONFIG_SOURCE", "STORY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- the chain
    ("M3_5 back in the main chain", C, '"M3_3", "M3_4", "M3_6", "M3_7", "M3_8" },', '"M3_3", "M3_4", "M3_5", "M3_6", "M3_7", "M3_8" },'),
    ("M3_5 is a main again", C, 'Kind = "Sub", Chapter = 3, Title = "Sprout Graduation"', 'Kind = "Main", Chapter = 3, Title = "Sprout Graduation"'),
    ("M3_5 not in the sub list", C, '"M3_5", "OathH", "OathR" }', '"OathH", "OathR" }'),
    ("M3_5 opens without M3_4", C, 'Requires = { Done = { "M3_4" } },\n\t\t\tSteps = {\n\t\t\t\t{ Text = "Sprout Shield on', 'Requires = {},\n\t\t\tSteps = {\n\t\t\t\t{ Text = "Sprout Shield on'),
    ("the shield row has a clock", C, 'Text = "Sprout Shield on · ends at Lv15 + 1 hour of play"', 'Text = "Sprout Shield on · 60 min left %d"'),
    ("the old-save skip forgets M3_5", C, '{ Level = 25, UpTo = 3, Subs = { "M3_5" } }', '{ Level = 25, UpTo = 3 }'),
    ("the skip applies at Lv10", C, '{ Level = 25, UpTo = 3, Subs = { "M3_5" } }', '{ Level = 25, UpTo = 3 }, { Level = 10, UpTo = 2, Subs = { "M3_5" } }'),
    ("no skip code for subs", ST, "\t\t\t\tfor _, sid in row.Subs or {} do st.Done[sid] = true end\n", ""),
    ("no migration of a saved main", ST, "\t\tif moved and moved.Kind == \"Sub\" and not st.Done[st.Main.Id] and st.Subs[st.Main.Id] == nil then\n", "\t\tif false then\n"),
    ("the migration forgets the step", ST, "st.Subs[st.Main.Id] = { St = st.Main.St, P = st.Main.P, T = st.Main.T, Claim = st.Main.Claim }", "st.Subs[st.Main.Id] = { St = 1, P = 0, T = {}, Claim = false }"),
    ("the migration overwrites a sub", ST, "and not st.Done[st.Main.Id] and st.Subs[st.Main.Id] == nil then", "and not st.Done[st.Main.Id] then"),
    # --- who gets an oath
    ("config: oath at Lv14", C, 'Requires = { Done = { "M3_4" }, Level = 15, Sprout = true },\n\t\t\tStart = "Bright', 'Requires = { Done = { "M3_4" }, Level = 14, Sprout = true },\n\t\t\tStart = "Bright'),
    ("config: oath without M3_4", C, 'Requires = { Done = { "M3_4" }, Level = 15, Sprout = true },\n\t\t\tStart = "Smokey', 'Requires = { Level = 15, Sprout = true },\n\t\t\tStart = "Smokey'),
    ("config: oath for graduates too", C, 'Requires = { Done = { "M3_4" }, Level = 15, Sprout = true },\n\t\t\tStart = "Bright', 'Requires = { Done = { "M3_4" }, Level = 15 },\n\t\t\tStart = "Bright'),
    ("config: OathH for Horns", C, 'Speaker = "Bright", Factions = { Halo = true },\n\t\t\tRequires = { Done = { "M3_4" }, Level = 15', 'Speaker = "Bright", Factions = { Halo = true, Horns = true },\n\t\t\tRequires = { Done = { "M3_4" }, Level = 15'),
    ("config: OathR for Neutral", C, 'Speaker = "Smokey", Factions = { Horns = true },\n\t\t\tRequires = { Done = { "M3_4" }, Level = 15', 'Speaker = "Smokey", Factions = { Horns = true, Neutral = true },\n\t\t\tRequires = { Done = { "M3_4" }, Level = 15'),
    ("Sprout is not checked", ST, '\tif req.Sprout and stateTrue(player, "Graduated") then return false end\n', ""),
    ("Sprout inverted", ST, 'if req.Sprout and stateTrue(player, "Graduated") then return false end', 'if req.Sprout and not stateTrue(player, "Graduated") then return false end'),
    # --- the training
    ("config: the bridge guard 5 s", C, "Radius = 14, Stay = 15 } },\n\t\t\t\t{ Text = \"Goblin Brute %d/%d\"", "Radius = 14, Stay = 5 } },\n\t\t\t\t{ Text = \"Goblin Brute %d/%d\""),
    ("config: Halo kills a plain goblin", C, 'Obj = { Type = "Kill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 } },\n\t\t\t\t{ Text = "Make your promise to Bright"', 'Obj = { Type = "Kill", Kind = "Goblin", Zone = "GoblinWoods", Count = 1 } },\n\t\t\t\t{ Text = "Make your promise to Bright"'),
    ("config: Horns may use skills", C, 'Obj = { Type = "BasicKill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 }', 'Obj = { Type = "Kill", Kind = "GoblinBrute", Zone = "GoblinWoods", Count = 1 }'),
    ("config: Horns skip a camp", C, '{ Text = "Find the second goblin camp", Guide = "GoblinCamp2", Obj = { Type = "Near", Spot = "GoblinCamp2", Radius = 10 } },\n', ''),
    # --- the oath
    ("config: Halo oath A scores 1", C, 'Obj = { Type = "Choice", Good = { Label = "I\'ll guard the small ones", Points = 2 },\n\t\t\t\t\t\tEvil = { Label = "Rascals bow to no one!", Points = 2 } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },\n\t\t\tFinish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR',
     'Obj = { Type = "Choice", Good = { Label = "I\'ll guard the small ones", Points = 1 },\n\t\t\t\t\t\tEvil = { Label = "Rascals bow to no one!", Points = 2 } } },\n\t\t\t},\n\t\t\tReward = { GoldN = 120, XPBar = 0.5, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },\n\t\t\tFinish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR'),
    ("config: the titles are swapped", C, 'TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },\n\t\t\tFinish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR', 'TitleBy = { Good = "RascalCadet", Evil = "GuardianCadet" } },\n\t\t\tFinish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR'),
    ("config: the oath gives no titles", C, 'Reward = { GoldN = 120, XPBar = 0.5, TitleBy = { Good = "GuardianCadet", Evil = "RascalCadet" } },\n\t\t\tFinish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR', 'Reward = { GoldN = 120, XPBar = 0.5 },\n\t\t\tFinish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR'),
    ("config: no Rascal Cadet title", C, 'Config.TitleDefs.RascalCadet = { Name = "Rascal Cadet", NameEn = "Rascal Cadet", Color = Color3.fromRGB(190, 120, 235) }\n', ''),
    ("config: Guardian Cadet not pickable", C, 'for _, id in { "GuardianCadet", "RascalCadet" } do', 'for _, id in { "RascalCadet" } do'),
    ("config: the closing line changed", C, 'Finish = "Oath sworn! Your Sprout Shield ends after 1 hour of play.",\n\t\t},\n\t\tOathR', 'Finish = "Done.",\n\t\t},\n\t\tOathR'),
    ("config: no sprout oath for Horns in the list", C, '"M3_5", "OathH", "OathR" }', '"M3_5", "OathH" }'),
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
    config = read(SHARED / "Config.luau")
    check("req.Sprout" in story, "StoryQuestService reads Requires.Sprout")
    check("row.Subs" in story, "StoryQuestService skips the SkipChapters Subs")
    check("moved.Kind == \"Sub\"" in story, "StoryQuestService moves a saved main that became a sub")
    start = config.find("-- A23-86 Sprout Oath (content_beyond_10min G)")
    block = config[start:config.find("-- A23-86 Call of the Woods (content_beyond_10min A): the first time", start)]
    code = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", code), "the oath subs: English text only")
    check("Prompt" not in code and "Robux" not in code, "the oath subs: nothing sold, no purchase prompt")
    check(config.count("OathH = {") == 1 and config.count("OathR = {") == 1, "each oath is defined once")
    return count, failures


SUITE = Suite(
    mark="SPROUTOATH",
    fixture=ROOT / "tools/fixtures/sprout_oath_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_sprout_oath_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-86 G: M3_5 'Sprout Graduation' is a side line (Kind Sub, after M3_4, the same two steps; main chain "
             "M3_4 -> M3_6; row 'Sprout Shield on · ends at Lv15 + 1 hour of play' without numbers; a saved in-progress main "
             "M3_5 moves to the side lines keeping its step; an old Lv25+ save skips it; a finished one stays finished); "
             "Requires.Sprout = the Sprout Shield is still on; OathH (Halo, Bright) / OathR (Horns, Smokey) open at Lv15 "
             "after M3_4 while a sprout, once, not for graduates / Neutral / below Lv15; Halo: talk, guard the woods bridge "
             "15 s, one Goblin Brute in the woods, the oath; Horns: talk, goblin camp 1, camp 2, one Goblin Brute with basic "
             "hits only, the oath; the oath card 2 points each way (A23-58 floor), Reward TitleBy (Good Guardian Cadet / "
             "Evil Rascal Cadet), the town-sub gold, 'Oath sworn! Your Sprout Shield ends after 1 hour of play.'.",
    limitations="Walking steps (Near) are the existing engine's 1 s loop and are not simulated; the fixture sets the track to "
                "the step it tests. No 'Playtime' objective type was added: the shield clock is the existing State "
                "'Graduated' (PvPService.IsRookie). The NPC lines are new English text for 검수's review.",
)

if __name__ == "__main__":
    run(SUITE)
