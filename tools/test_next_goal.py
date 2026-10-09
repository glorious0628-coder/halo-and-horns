"""A23-86 F - the next-goal ladder (content_beyond_10min F) (게임성 개발 3, 2026-10-09), offline.

When no story row is pinned (after the last chapter, after a rebirth) and the early goals are done (iron weapon, first
skills, the woods), the pinned line walks a ladder: feature rows (golden weapon, Captain Clatter, crystal weapon: asked from
their service while their switch is on), then 'Lv50: Rebirth, choose your side again (now Lv47)' from 5 levels before, then
'Rebirth is open'. Runs the CURRENT Config, Util, QuestService (PinnedRow / next-goal entry) and StoryQuestService (MainRow)
on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with tools/fixtures/next_goal_offline.luau and the
installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies only.

Usage: py tools/test_next_goal.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-09/offline_dev3_next_goal_2026-10-09.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "QUEST_SOURCE": SSS / "QuestService.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
}
C, Q = "CONFIG_SOURCE", "QUEST_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("config: rebirth line 10 levels early", C, "Rebirth = { Warn = 5 },", "Rebirth = { Warn = 10 },"),
    ("config: rebirth line only at the level", C, "Rebirth = { Warn = 5 },", "Rebirth = { Warn = 0 },"),
    ("config: Clatter before the golden weapon", C, '{ Kind = "Commission", Service = "CommissionService", Feature = "Commission" },\n\t\t\t{ Kind = "Clatter", Service = "ClatterService", Feature = "Clatter" },',
     '{ Kind = "Clatter", Service = "ClatterService", Feature = "Clatter" },\n\t\t\t{ Kind = "Commission", Service = "CommissionService", Feature = "Commission" },'),
    ("config: the Clatter switch is on", C, "Config.Features = { NeutralFaction = false, Market = false, StatPoints = false }", "Config.Features = { NeutralFaction = false, Market = false, StatPoints = false, Clatter = true }"),
    ("config: no side question for knights", C, 'RebirthNoteHalo = "Stay a knight, or not?"', 'RebirthNoteHalo = ""'),
    ("config: long rebirth short name", C, 'Rebirth = "Rebirth Lv %d"', 'Rebirth = "Rebirth: choose your side again at Lv %d"'),
    ("config: no Chapter 4 line", C, '			Finish = "Chapter 4 is coming!", -- A23-86 F: one closing line, no date, no clock\n', ''),
    ("config: rebirth zone missing", C, 'GoalZones = { Rebirth = "Crossroads", RebirthReady = "Crossroads", Commission = "Crossroads", Crystal = "Crossroads" },', 'GoalZones = {},'),
    ("hooks ignore their switch", Q, "and (row.Feature == nil or Config.FeatureOn(row.Feature)) then", "then"),
    ("an erroring hook breaks the row", Q, "local ok, text = pcall(svc.NextGoal, player, data)\n\t\t\tif ok and type(text) == \"string\" and text ~= \"\" then return text, row.Kind, nil end",
     "local text = svc.NextGoal(player, data)\n\t\t\tif type(text) == \"string\" and text ~= \"\" then return text, row.Kind, nil end"),
    ("an empty hook line is shown", Q, "if ok and type(text) == \"string\" and text ~= \"\" then return text, row.Kind, nil end", "if ok and type(text) == \"string\" then return text, row.Kind, nil end"),
    ("the rebirth level ignores rebirths", Q, "local need = Config.RebirthLevel(math.max(0, math.floor(num(data.Rebirths))))", "local need = Config.RebirthLevel(0)"),
    ("never 'ready'", Q, "if level >= need then\n\t\t\treturn TUT_MESSAGES.NextRebirthReady, \"RebirthReady\", need\n\t\telseif", "if false then\n\t\t\treturn TUT_MESSAGES.NextRebirthReady, \"RebirthReady\", need\n\t\telseif"),
    ("the rebirth line shows at any level", Q, "elseif level >= need - math.max(0, math.floor(num(rb.Warn))) then", "else"),
    ("no side question", Q, "\t\t\t\tentry.GoalNote = f == \"Halo\" and TUT_MESSAGES.RebirthNoteHalo or f == \"Horns\" and TUT_MESSAGES.RebirthNoteHorns or nil\n", ""),
    ("the side question for everyone", Q, "entry.GoalNote = f == \"Halo\" and TUT_MESSAGES.RebirthNoteHalo or f == \"Horns\" and TUT_MESSAGES.RebirthNoteHorns or nil", "entry.GoalNote = TUT_MESSAGES.RebirthNoteHalo"),
    ("the ladder before the early goals", Q, "\tlocal zone = Config.Zones[NEXT_ZONE]\n\tlocal zoneAt = zone and level < zone.MinLevel and zone.MinLevel or nil\n\tif skillAt and",
     "\tlocal zone = Config.Zones[NEXT_ZONE]\n\tlocal zoneAt = zone and level < zone.MinLevel and zone.MinLevel or nil\n\tif level > 5 and TUT_CFG.Ladder and TUT_CFG.Ladder.Rebirth then return TUT_MESSAGES.NextRebirthReady, \"RebirthReady\", 0 end\n\tif skillAt and"),
    ("the goal kind is not published", Q, "\t\t\tentry.GoalKind = kind\n", ""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    quest = read(SSS / "QuestService.luau")
    config = read(SHARED / "Config.luau")
    ret = read(SSS / "ReturnService.luau")
    check("TUT_CFG.Ladder" in quest and "svc.NextGoal" in quest, "QuestService walks Config.Tutorial.Ladder (hook NextGoal)")
    check("R.GoalZones" in ret, "ReturnService leads a ladder goal by Config.Return.GoalZones")
    start = config.find("-- A23-86 F (content_beyond_10min): the next-goal ladder")
    block = config[start: config.find("QuestRewardGold = 150", start)]
    code = "\n".join(l.split("--", 1)[0] for l in block.splitlines())
    check(not re.search(r"[가-힣]", code), "ladder config: English only")
    check("Prompt" not in code and "Robux" not in code and "Gamepass" not in code, "ladder config: nothing sold (A23-79)")
    return count, failures


SUITE = Suite(
    mark="NEXTGOAL",
    fixture=ROOT / "tools/fixtures/next_goal_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-09/offline_dev3_next_goal_2026-10-09.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-86 F: with no story row pinned and the early goals done, the pinned next-goal row walks Config.Tutorial.Ladder: "
             "feature hooks in order (golden weapon / Captain Clatter / crystal weapon: S[Service].NextGoal(player, data), only "
             "while Config.Features[Feature] is on, errors and empty lines skipped), then 'Next goal · Lv50: Rebirth, choose "
             "your side again (now Lv47)' from 5 levels before Config.RebirthLevel(rebirths), then 'Rebirth is open' "
             "(GoalKind Rebirth / RebirthReady, short names, GoalNote = the side's question 'Stay a knight, or not?' / "
             "'Stay a rascal, or not?'); the early goals (iron weapon, skills, the woods) and the story row keep their "
             "place; ReturnService leads the goal to Config.Return.GoalZones; M3_8 closes with 'Chapter 4 is coming!'.",
    limitations="Which level shows what (a veteran who finished every chapter): Lv1-24 the early goals, Lv25-44 BLANK until the "
                "Commission / Clatter / Crystal features exist, Lv45-49 Rebirth, Lv50+ Rebirth is open. The golden weapon "
                "(commission), Captain Clatter and crystal weapon rows only answer once their service exposes NextGoal and "
                "their switch is on. The client's tap-to-guide per GoalKind is game dev 1's (no client reads GoalKind yet).",
)

if __name__ == "__main__":
    run(SUITE)
