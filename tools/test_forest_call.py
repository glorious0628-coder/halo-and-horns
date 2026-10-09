"""A23-86 "Call of the Woods" (content_beyond_10min A) (게임성 개발 3, 2026-10-09), offline.

From Lv10 the second meadow step M2_6 can also be filled by Goblin Brutes in the Goblin Woods (Obj.Alt, AltText row), and
the first time a Lv10 hunter stands on the woods bridge, one small lantern card (sub WB1: A one 70% scroll / B 3 HP potions
+ 1 minute of Lv10 hunting gold, 1 point each way). Runs the CURRENT Config, Util and StoryQuestService on
tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/forest_call_offline.luau and the
installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_forest_call.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_forest_call_2026-10-09.json
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
    # --- the alternative kill
    ("config: Alt level 9", C, "Alt = { MinLevel = 10, Pairs", "Alt = { MinLevel = 9, Pairs"),
    ("config: Alt level 11", C, "Alt = { MinLevel = 10, Pairs", "Alt = { MinLevel = 11, Pairs"),
    ("config: Alt takes any goblin", C, "Pairs = { { Kind = \"GoblinBrute\", Zone = \"GoblinWoods\" } }", "Pairs = { { Kind = \"Goblin\", Zone = \"GoblinWoods\" } }"),
    ("config: Alt brute in the meadow", C, "Pairs = { { Kind = \"GoblinBrute\", Zone = \"GoblinWoods\" } }", "Pairs = { { Kind = \"GoblinBrute\", Zone = \"SlimeMeadow\" } }"),
    ("config: the meadow step changed", C, "Kind = \"BigSlime\", Zone = \"SlimeMeadow\", Count = 2,\n\t\t\t\t\tAlt", "Kind = \"BigSlime\", Zone = \"SlimeMeadow\", Count = 3,\n\t\t\t\t\tAlt"),
    ("config: no alt row text", C, "\t\t\t\tAltText = \"Slime Princes or Goblin Brutes %d/%d\",\n", ""),
    ("no level check on the alternative", ST, "if data and num(data.Level, 1) >= num(a.MinLevel, 1) then", "if data then"),
    ("the alternative ignores the zone", ST, "if Config.QuestKind(info.Kind) == pair.Kind and info.ZoneId == pair.Zone then", "if Config.QuestKind(info.Kind) == pair.Kind then"),
    ("the alternative ignores the kind", ST, "if Config.QuestKind(info.Kind) == pair.Kind and info.ZoneId == pair.Zone then", "if info.ZoneId == pair.Zone then"),
    ("the alternative never counts", ST, "\t\tif not alt then\n\t\t\tif obj.Kind", "\t\talt = false\n\t\tif not alt then\n\t\t\tif obj.Kind"),
    ("the alternative skips the base kind check", ST, "\t\tif not alt then\n\t\t\tif obj.Kind and Config.QuestKind(info.Kind) ~= obj.Kind then return 0 end -- a pumpkin slime counts as a slime\n\t\t\tif obj.Zone and info.ZoneId ~= obj.Zone then return 0 end\n\t\tend\n",
     "\t\tif false then\n\t\tend\n"),
    ("personal monsters count", ST, "\t\tif info.Personal == true then return 0 end\n", ""),
    ("the row never names the woods", ST, "\t\ttemplate = step.AltText\n", ""),
    ("the row names the woods for everyone", ST, "type(obj.Alt) == \"table\" and num(data.Level, 1) >= num(obj.Alt.MinLevel, 1) then", "type(obj.Alt) == \"table\" then"),
    # --- WB1
    ("WB1 is not listed", C, "\t\t\"WB1\" }, -- A23-86 Call of the Woods: the lantern on the woods bridge", "\t\t}, -- A23-86 Call of the Woods: the lantern on the woods bridge"),
    ("WB1 at Lv5", C, "Requires = { Done = { \"M1_4\" }, Level = 10 },\n\t\t\tStart = \"A light flickers", "Requires = { Done = { \"M1_4\" }, Level = 5 },\n\t\t\tStart = \"A light flickers"),
    ("WB1 without M1_4", C, "Requires = { Done = { \"M1_4\" }, Level = 10 },\n\t\t\tStart = \"A light flickers", "Requires = { Level = 10 },\n\t\t\tStart = \"A light flickers"),
    ("WB1 not for Neutral", C, "Factions = { Halo = true, Horns = true, Neutral = true },\n\t\t\tRequires = { Done = { \"M1_4\" }, Level = 10 },", "Factions = { Halo = true, Horns = true },\n\t\t\tRequires = { Done = { \"M1_4\" }, Level = 10 },"),
    ("WB1 at the pond, not the bridge", C, "Guide = \"WoodsGate\", Obj = { Type = \"Near\", Spot = \"WoodsGate\", Radius = 14 } },\n\t\t\t\t{ Text = \"Pick up the lantern?\"", "Guide = \"SlimePond\", Obj = { Type = \"Near\", Spot = \"SlimePond\", Radius = 14 } },\n\t\t\t\t{ Text = \"Pick up the lantern?\""),
    ("WB1 A pays two scrolls", C, "from the trees.\",\n\t\t\t\t\t\t\tReward = { Item = \"Enh70\", N = 1 } },",
     "from the trees.\",\n\t\t\t\t\t\t\tReward = { Item = \"Enh70\", N = 2 } },"),
    ("WB1 B pays less gold", C, "Reward = { Potion = \"HP\", N = 3, Gold = 192 } },\n\t\t\t\t\t\tNeutral = { A = \"Hand it back\"", "Reward = { Potion = \"HP\", N = 3, Gold = 96 } },\n\t\t\t\t\t\tNeutral = { A = \"Hand it back\""),
    ("WB1 B pays more gold", C, "Reward = { Potion = \"HP\", N = 3, Gold = 192 } },\n\t\t\t\t\t\tNeutral = { A = \"Hand it back\"", "Reward = { Potion = \"HP\", N = 3, Gold = 400 } },\n\t\t\t\t\t\tNeutral = { A = \"Hand it back\""),
    ("WB1 A scores 2", C, "Good = { Label = \"Hand it back\", Points = 1, Reply", "Good = { Label = \"Hand it back\", Points = 2, Reply"),
    ("WB1 B scores 2", C, "Evil = { Label = \"Finders keepers!\", Points = 1, Reply", "Evil = { Label = \"Finders keepers!\", Points = 2, Reply"),
    ("WB1 B scores 0", C, "Evil = { Label = \"Finders keepers!\", Points = 1, Reply", "Evil = { Label = \"Finders keepers!\", Points = 0, Reply"),
    ("WB1 has no Neutral labels", C, "Neutral = { A = \"Hand it back\", B = \"Finders keepers!\" } } },\n\t\t\t},\n\t\t\tFinish = \"The woods feel", "} },\n\t\t\t},\n\t\t\tFinish = \"The woods feel"),
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
    check("obj.Alt" in story and "step.AltText" in story, "StoryQuestService reads Obj.Alt and step.AltText")
    block = config[config.find("-- A23-86 Call of the Woods (content_beyond_10min A): the first time"):]
    block = block[: block.find("-- quest_volume")]
    code = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", code), "WB1: English text only")
    check("Prompt" not in code and "Robux" not in code, "WB1: nothing sold, no purchase prompt")
    check(config.count("WB1 = {") == 1, "WB1 is defined once")
    return count, failures


SUITE = Suite(
    mark="FORESTCALL",
    fixture=ROOT / "tools/fixtures/forest_call_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_forest_call_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-86 Call of the Woods: M2_6 (2 Slime Princes in the meadow) can also be filled from Lv10 by Goblin Brutes "
             "in the Goblin Woods (Obj.Alt { MinLevel 10, Pairs { GoblinBrute / GoblinWoods } }, the row names both from "
             "that level, progress kept, the kind AND the zone must match, personal monsters never count, Near / Golden "
             "rules still apply); sub WB1 'The Dropped Lantern' (after M1_4 at Lv10, every side): step 1 the woods bridge "
             "(WoodsGate), step 2 a Choice card, A hand it back = one 70% scroll, B finders keepers = 3 HP potions + 1 "
             "minute of Lv10 hunting gold (192, source 'Choice'), 1 point each way (A23-58), Neutral A / B reward only, once.",
    limitations="The bridge card is the normal story card (client already draws it); the lantern art / sounds are not part "
                "of this change. Real walking onto the bridge is the Near step of the existing engine (not simulated).",
)

if __name__ == "__main__":
    run(SUITE)
