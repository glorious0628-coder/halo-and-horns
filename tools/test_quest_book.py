"""A23-81 quest window book: the "Available" / "Done" lists (게임성 개발 3, 2026-10-08), offline.

The "Quests" remote now carries { Quests = the rows, Book = { Available, Done } }. Runs StoryQuestService.BookRows from
the CURRENT source on tools/fixtures/dev2_kit.luau + tools/fixtures/dev3_world.luau with
tools/fixtures/quest_book_offline.luau and the installed official Luau CLI. Static checks: QuestService.publish sends
the table payload (HUD / Audio read .Quests) and dedupes rows + book together. Mutations on in-memory copies only.

Usage: py tools/test_quest_book.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_quest_book_2026-10-08.json
"""
from __future__ import annotations

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "STORY_SOURCE": SSS / "StoryQuestService.luau",
}
C, ST = "CONFIG_SOURCE", "STORY_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("Done oldest first", ST, "\t\tfor i = #list, 1, -1 do\n\t\t\tif #done >= maxDone then break end\n",
     "\t\tfor i = 1, #list do\n\t\t\tif #done >= maxDone then break end\n"),
    ("Done without a cap", ST, "\t\t\tif #done >= maxDone then break end\n", ""),
    ("hidden subs listed", ST, "\t\tif def and not def.Hidden and not st.Done[id] and not st.Subs[id] and okVis and shown then\n",
     "\t\tif def and not st.Done[id] and not st.Subs[id] and okVis and shown then\n"),
    ("started subs listed", ST, "\t\tif def and not def.Hidden and not st.Done[id] and not st.Subs[id] and okVis and shown then\n",
     "\t\tif def and not def.Hidden and not st.Done[id] and okVis and shown then\n"),
    ("a failed visibility check shows the sub", ST, "and not st.Subs[id] and okVis and shown then", "and not st.Subs[id] and (not okVis or shown) then"),
    ("level-waiting subs ignore the other requirements", ST,
     "\t\t\t\tif requirementsMet(player, setmetatable({ Level = need }, { __index = data }), def) then\n", "\t\t\t\tif true then\n"),
    ("the level view writes the save", ST, "setmetatable({ Level = need }, { __index = data })", "(function() data.Level = need; return data end)()"),
    ("no level on a waiting sub", ST, "\t\t\t\t\ttable.insert(avail, { Id = \"story:\" .. id, Kind = \"Sub\", Level = need,\n",
     "\t\t\t\t\ttable.insert(avail, { Id = \"story:\" .. id, Kind = \"Sub\",\n"),
    ("ready subs not listed", ST, "\t\t\telseif requirementsMet(player, data, def) then\n\t\t\t\ttable.insert(avail, { Id = \"story:\" .. id, Kind = \"Sub\" })\n",
     "\t\t\telseif false then\n\t\t\t\ttable.insert(avail, { Id = \"story:\" .. id, Kind = \"Sub\" })\n"),
    ("highest level first", ST, "return (a.Level or 0) < (b.Level or 0) end", "return (a.Level or 0) > (b.Level or 0) end"),
    ("no AvailableMax", ST, "\tfor i = #avail, math.floor(num(QB.AvailableMax, 10)) + 1, -1 do avail[i] = nil end\n", ""),
    ("Config: Done keeps 10", C, "\tDoneMax = 60,", "\tDoneMax = 10,"),
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
    pub = function_block(quest, "local function publish(")
    check('Net.Get("Quests"):FireClient(player, { Quests = list, Book = book })' in pub,
          "publish sends { Quests = rows, Book = book } (HUD / Audio read .Quests)")
    check("pcall(story.BookRows, player, data)" in pub, "publish asks StoryQuestService.BookRows (pcall)")
    check('local sentKey = json .. "|" .. (okBookJson and bookJson or "")' in pub and "if lastSent[player] == sentKey then return end" in pub
          and "lastSent[player] = sentKey" in pub, "the change check covers rows + book together")
    hud = read(ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau")
    audio = read(ROOT / "src/StarterPlayer/StarterPlayerScripts/Audio.luau")
    check('type(payload) == "table" and type(payload.Quests) == "table"' in hud
          and 'type(payload) == "table" and type(payload.Quests) == "table"' in audio,
          "today's clients (HUD.onQuests, Audio.OnQuests) read the table payload's .Quests")
    return count, failures


SUITE = Suite(
    mark="QUEST_BOOK",
    fixture=ROOT / "tools/fixtures/quest_book_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_quest_book_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-81: Quests remote payload { Quests = rows, Book = { Available, Done } }. Done = finished story quests as "
             "'story:<id>', mains newest first then subs newest first, known ids only, at most 60. Available = subs that "
             "only wait for a level ({ Id, Kind = 'Sub', Level, Text = 'Title · Opens at Lv N' }, the other requirements "
             "checked on a read-only level view) + ready subs not started yet, never hidden / started / done / other "
             "faction, lowest level first, at most 10; no main (the chain has no level gate).",
    limitations="The Q window (tabs, Config.QuestTabs) is game dev 1's client. Today's dailies are not in Done (a claimed "
                "daily's row is replaced, only the count is kept). The real publish loop runs in the onboarding / "
                "weapon_first suites (their fixtures read the new table payload).",
)

if __name__ == "__main__":
    run(SUITE)
