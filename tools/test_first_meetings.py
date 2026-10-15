"""A23-113 first meetings (게임성 개발 3, 2026-10-10; 검수: "원한 자루·강화 옮기기 주문서·덩치 저울도 처음 만날 때 퀘스트 한 줄"), offline.

The first meeting with three things the screen no longer explains (A23-99) leaves ONE plain talking row, the frame of the daily
jobs' D0: no popup, no toast, no Start / Finish line; pressing the row opens a short dialogue and finishing it pays a minute of
hunting. A meeting is a saved flag (data.Story.First[name]) a quest waits for with Requires.Seen:
  TS1 "Moving a Plus"   <- ScrollMet = a transfer scroll (Config.Loot.Items Kind "Transfer") sits in the bag (a save that already holds one
                           meets it at once; an enhance scroll, an empty stack, a potion never do)
  SZ1 "The Size Scale"  <- ScaleMet  = the player's own SizeMult is above 1 (JusticeService: their side is the smaller one)
  SG1 "The Grudge Sack" <- SackMet   = a PvP KO took gold into a sack (PvPService.PlayerKO info.Stolen > 0), for the thief AND the victim
Runs the CURRENT Config, Util and StoryQuestService (the dev2_combat_world doubles for the other services) with
tools/fixtures/first_meetings_offline.luau and the installed official Luau CLI. The words follow the numbers: 45 s = Config.Grudge.SackSeconds,
1.6 = Config.Justice.MaxScale. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources only.

Usage: py tools/test_first_meetings.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_first_meetings_2026-10-10.json
"""
from __future__ import annotations

from dev2_offline import ROOT, Suite, run
from test_unarmed_start import FILES as UNARMED_FILES, bindings as unarmed_bindings

FILES = dict(UNARMED_FILES)
C, ST = "CONFIG_SOURCE", "STORY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return unarmed_bindings(sources)


SEEN_SCROLL = 'Requires = { Seen = "ScrollMet" },'
SEEN_SACK = 'Requires = { Seen = "SackMet" },'
SEEN_SCALE = 'Requires = { Seen = "ScaleMet" },'
LOOP = "\tif st.First[name] ~= true and type(rule) == \"table\" and metNow(player, data, rule) then\n"
HOLD = "if type(def) == \"table\" and def.Kind == rule.HoldKind and num(n) > 0 then return true end"
OVER = "num(player:GetAttribute(over.Name), 0) > num(over.Over, 0)"

MUTATIONS = [
    # the definitions
    ("TS1 waits for nothing", C, SEEN_SCROLL, "Requires = {},"),
    ("TS1 waits for the wrong meeting", C, SEEN_SCROLL, 'Requires = { Seen = "ScaleMet" },'),
    ("SG1 waits for the wrong meeting", C, SEEN_SACK, 'Requires = { Seen = "ScrollMet" },'),
    ("SZ1 waits for the wrong meeting", C, SEEN_SCALE, 'Requires = { Seen = "SackMet" },'),
    ("SG1 also needs a level", C, SEEN_SACK, 'Requires = { Seen = "SackMet", Level = 30 },'),
    ("ScrollMet watches enhance scrolls", C, 'ScrollMet = { HoldKind = "Transfer" },', 'ScrollMet = { HoldKind = "Enhance" },'),
    ("ScaleMet needs 1.5", C, 'ScaleMet = { AttrOver = { Name = "SizeMult", Over = 1 } },', 'ScaleMet = { AttrOver = { Name = "SizeMult", Over = 1.5 } },'),
    ("ScaleMet reads another attribute", C, 'ScaleMet = { AttrOver = { Name = "SizeMult", Over = 1 } },',
     'ScaleMet = { AttrOver = { Name = "VisualScale", Over = 1 } },'),
    ("SackMet is not a listed happening", C,
     "Config.StoryQuests.Events.SackMet = true -- A23-113: a PvP KO that took gold into a Grudge Sack (see Meetings above)\n", ""),
    ("TS1 pops up by itself", C, 'Title = "Moving an Upgrade", ShortName = "Move upgrade", Speaker = "Smith",',
     'Title = "Moving an Upgrade", ShortName = "Move upgrade", Speaker = "Smith", Pop = true,'),
    ("TS1 gets a closing line", C, 'Title = "Moving an Upgrade", ShortName = "Move upgrade", Speaker = "Smith",',
     'Title = "Moving an Upgrade", ShortName = "Move upgrade", Speaker = "Smith", Finish = "Done!",'),
    ("SG1 starts with a line", C, 'Title = "The Grudge Sack", ShortName = "Grudge Sack", Speaker = "Notice",',
     'Title = "The Grudge Sack", ShortName = "Grudge Sack", Speaker = "Notice", Start = "Careful!",'),
    ("SZ1 is Halo only", C, 'Title = "The Size Scale", ShortName = "Size scale", Speaker = "Fountain",',
     'Title = "The Size Scale", ShortName = "Size scale", Speaker = "Fountain", Factions = { Halo = true },'),
    ("SG1 says 30 seconds", C, "after 45 seconds in a PvP zone", "after 30 seconds in a PvP zone"),
    ("SZ1 says 2 times", C, "up to 1.6 times", "up to 2 times"),
    ("an SG1 line of 20 words", C, "\"Beat the thief first and the gold goes back to its owner!\"",
     "\"Beat the thief first and the gold goes back to its owner, who will be very happy about it for a long time!\""),
    ("TS1 forgets the plus", C, "A Transfer Scroll moves a weapon's + to another weapon.", "A Transfer Scroll moves a weapon to another weapon."),
    ("SZ1 has the wrong speaker", C, 'Title = "The Size Scale", ShortName = "Size scale", Speaker = "Fountain",',
     'Title = "The Size Scale", ShortName = "Size scale", Speaker = "Notice",'),
    ("SG1 left out of the sub list", C, 'for _, id in { "TS1", "SG1", "SZ1" } do table.insert(Config.StoryQuests.Subs, id) end',
     'for _, id in { "TS1", "SZ1" } do table.insert(Config.StoryQuests.Subs, id) end'),
    ("a Korean line", C, "If it fails, the + stays where it was.", "If it fails, the + stays where it was. 실패!"),
    # the engine
    ("Requires.Seen ignored", ST, "\tif req.Seen and st.First[req.Seen] ~= true then return false end\n", ""),
    ("Requires.Seen reads the wrong table", ST, "if req.Seen and st.First[req.Seen] ~= true then return false end",
     "if req.Seen and st.Done[req.Seen] ~= true then return false end"),
    ("the meetings are never checked", ST, LOOP, "\tif false then\n"),
    ("a meeting is not remembered", ST, "\t\t\tst.First[name] = true\n\t\t\tchanged = true\n\t\tend\n\tend\n", "\t\t\tchanged = true\n\t\tend\n\tend\n"),
    ("any item counts as a scroll", ST, HOLD, "if type(def) == \"table\" and num(n) > 0 then return true end"),
    ("an empty stack counts", ST, HOLD, "if type(def) == \"table\" and def.Kind == rule.HoldKind then return true end"),
    ("the bag is never read", ST, "if type(rule.HoldKind) == \"string\" and type(data.Items) == \"table\" then", "if false then"),
    ("SizeMult 1 counts", ST, OVER, "num(player:GetAttribute(over.Name), 0) >= num(over.Over, 0)"),
    ("a grown body never counts", ST, OVER, "num(player:GetAttribute(over.Name), 0) < num(over.Over, 0)"),
    ("a sack with nothing stolen counts", ST, "if type(info) ~= \"table\" or num(info.Stolen) <= 0 then return end", "if type(info) ~= \"table\" then return end"),
    ("only the thief meets the sack", ST, "\t\t\tpcall(StoryQuestService.Event, victim, \"SackMet\")\n", ""),
    ("only the victim meets the sack", ST, "\t\t\tpcall(StoryQuestService.Event, killer, \"SackMet\")\n", ""),
    ("the sack happening is never connected", ST, "if type(pvp) == \"table\" and type(pvp.PlayerKO) == \"table\" then", "if false then"),
]


def static() -> tuple[int, list[str]]:
    return 0, []


SUITE = Suite(
    mark="FIRST_MEETINGS",
    fixture=ROOT / "tools/fixtures/first_meetings_offline.luau",
    world=ROOT / "tools/fixtures/dev2_combat_world.luau",
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_first_meetings_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-113: three one-row quests for first meetings, the frame of the daily jobs' D0 (no popup, no toast, no Start / Finish, one "
             "talking row, a minute of hunting): TS1 'Moving a Plus' (Requires.Seen ScrollMet: a transfer scroll in the bag), SZ1 'The Size "
             "Scale' (Seen ScaleMet: the player's own SizeMult above 1), SG1 'The Grudge Sack' (Seen SackMet: a PvP KO with info.Stolen > 0, "
             "for the thief and the victim). A meeting is saved in data.Story.First first and stays; Requires.Seen = that flag. The words "
             "follow Config.Grudge.SackSeconds (45 s) and Config.Justice.MaxScale (1.6).",
    limitations="Whether a real SizeMult is above 1 and whether PvPService really sends info.Stolen are the services' own tests; the "
                "dialogue panel and the row look are game dev 1's (the same D0 row frame).",
)

if __name__ == "__main__":
    run(SUITE)
