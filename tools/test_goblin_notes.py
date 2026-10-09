"""EG06 Goblin Notes (story_depth (나), 검수 2026-10-10) (게임성 개발 3), offline.

One joke line under the News window, in its own colour, new every week: Config.GoblinNotes = { Title, Lines } (3 patch-note
jokes, easy English, no real brand or person) and the pure picker Config.GoblinNote(dayIndex) = Lines[1 + (KST week) mod #Lines]
(the client shows Config.GoblinNote(Config.DayIndex(os.time())), game dev 1). Reads the CURRENT Config on
tools/fixtures/dev2_kit.luau with tools/fixtures/goblin_notes_offline.luau and the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls; mutations run on in-memory copies of the Config only.

Usage: py tools/test_goblin_notes.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_goblin_notes_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, Suite, read, run, strip_comments

FILES = {"CONFIG_SOURCE": SHARED / "Config.luau"}
C = "CONFIG_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


PICK = "return lines[1 + math.floor(dayIndex / 7) % #lines]"

MUTATIONS = [
    ("a week is 6 days", C, PICK, "return lines[1 + math.floor(dayIndex / 6) % #lines]"),
    ("a week is 8 days", C, PICK, "return lines[1 + math.floor(dayIndex / 8) % #lines]"),
    ("the note changes every day", C, PICK, "return lines[1 + math.floor(dayIndex) % #lines]"),
    ("the note never changes", C, PICK, "return lines[1]"),
    ("the list never wraps", C, PICK, "return lines[1 + math.floor(dayIndex / 7)]"),
    ("the first line is skipped", C, PICK, "return lines[2 + math.floor(dayIndex / 7) % #lines]"),
    ("a broken day index errors", C, "\tif type(dayIndex) ~= \"number\" or dayIndex ~= dayIndex or dayIndex == math.huge or dayIndex == -math.huge or #lines == 0 then\n\t\treturn lines[1]\n\tend\n", ""),
    ("NaN passes", C, "type(dayIndex) ~= \"number\" or dayIndex ~= dayIndex or", "type(dayIndex) ~= \"number\" or"),
    ("infinity passes", C, " or dayIndex == math.huge or dayIndex == -math.huge", ""),
    ("the title is changed", C, "Title = \"Goblin Notes\",", "Title = \"News\","),
    ("a note is missing", C, "\t\t\"Known issue: slimes are squishy. Working as intended.\",\n", ""),
    ("the first note changed", C, "\"Fixed: goblins stealing dust. (Not fixed.)\"", "\"Fixed: goblins.\""),
    ("the third note changed", C, "\"Goblins now steal 0% more. Same as before.\"", "\"Goblins now steal 5% more.\""),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    code = strip_comments(read(SHARED / "Config.luau"))
    block = code.split("Config.GoblinNotes = {", 1)[1].split("\nend\n", 1)[0]
    check(not re.search(r"[가-힣]", block), "Goblin Notes: no Korean outside comments")
    check(code.count("function Config.GoblinNote(") == 1 and code.count("Config.GoblinNotes = {") == 1, "one table and one picker")
    return count, failures


SUITE = Suite(
    mark="GOBLIN_NOTES",
    fixture=ROOT / "tools/fixtures/goblin_notes_offline.luau",
    world=None,
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_goblin_notes_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="Config.GoblinNotes = { Title = 'Goblin Notes', Lines = 3 patch-note jokes }; Config.GoblinNote(dayIndex) = the line of "
             "the KST week (floor(day / 7) mod 3, day 0..6 = line 1), a broken number = line 1, a negative day wraps. The News "
             "window shows it (game dev 1).",
    limitations="Text and the picker only: the News window's bottom line is game dev 1's client work.",
)

if __name__ == "__main__":
    run(SUITE)
