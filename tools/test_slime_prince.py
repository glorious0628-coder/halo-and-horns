"""A23-84: BigSlime's screen name 'King Slime' -> 'Slime Prince', texts only (게임성 개발 3, 2026-10-08), offline.

The new boss King Slime (SlimeKing) is game dev 2's. Every objective that counted the old King Slime still counts
BigSlime (S0, M1_1, M2_6, H1, XR1, R5, the first 70% scroll, the meadow board, the rookie daily). Runs the CURRENT
Config with tools/fixtures/slime_prince_offline.luau on tools/fixtures/dev2_kit.luau and the installed official Luau
CLI: names, no 'King Slime' left in game text (except the new boss's own entries), the quest texts, the slime family
(A23-84 / A23-85), objectives unchanged. Mutations on in-memory copies only.

Usage: py tools/test_slime_prince.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-08/offline_dev3_slime_prince_2026-10-08.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, Suite, read, run

FILES = {"CONFIG_SOURCE": SHARED / "Config.luau"}
C = "CONFIG_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("the old name", C, 'BigSlime = { Name = "Slime Prince", Short = "Slime Prince",', 'BigSlime = { Name = "King Slime", Short = "King Slime",'),
    ("the old short name only", C, 'BigSlime = { Name = "Slime Prince", Short = "Slime Prince",', 'BigSlime = { Name = "Slime Prince", Short = "King Slime",'),
    ("S0 still says King Slime", C, 'Start = "A Slime Prince swallowed a shard!', 'Start = "A King Slime swallowed a shard!'),
    # 10/15 story fields: Otto's M1_1 ask is the Offer's Before line now (the old 'ate the most of it' line is gone)
    ("Otto's ask names the King Slime", C, 'Halo = "Shard dust made him bounce! He swallowed the band!"',
     'Halo = "Shard dust made the King Slime bounce! He swallowed the band!"'),
    ("H1's old step", C, '{ Text = "Slime Princes in the meadow %d/%d"', '{ Text = "King Slimes in the meadow %d/%d"'),
    ("Tiny's old line", C, '"Tiny: A Slime Prince swallowed a teddy bear!"', '"Tiny: A King Slime swallowed a teddy bear!"'),
    ("R5's old step", C, '{ Text = "Slime Prince %d/%d", Guide = "SlimePond"', '{ Text = "King Slime %d/%d", Guide = "SlimePond"'),
    # A23-222: M1_1 = the Prince only (one step; the King is M1_2's); M1_1's Prince step moved to the new boss
    ("M1_1 moved to the new boss", C, 'Obj = { Type = "Kill", Kind = "BigSlime", Zone = "SlimeMeadow", Count = 1 },\n\t\t\t\t\tOn = "Self", Find = "That\'s not a snack!"',
     'Obj = { Type = "Kill", Kind = "SlimeKing", Zone = "SlimeMeadow", Count = 1 },\n\t\t\t\t\tOn = "Self", Find = "That\'s not a snack!"'),
    ("M1_2 hunts one more Prince", C, '{ Text = "Defeat the King Slime", ShortName = "Defeat King", Guide = "MeadowArrival",\n\t\t\tObj = { Type = "Kill", Kind = "SlimeKing"',
     '{ Text = "Defeat the King Slime", ShortName = "Defeat King", Guide = "MeadowArrival",\n\t\t\tObj = { Type = "Kill", Kind = "BigSlime"'),
    ("the first scroll moved to the new boss", C, 'FirstScroll = { Monster = "BigSlime",', 'FirstScroll = { Monster = "SlimeKing",'),
    ("the rookie daily moved", C, '{ Id = "Kill", Weight = 3, Monster = "BigSlime", Strict = true, Targets = { 3 } },',
     '{ Id = "Kill", Weight = 3, Monster = "SlimeKing", Strict = true, Targets = { 3 } },'),
    ("a mom in the family", C, '{ Text = "Beat a Slime Prince %d/%d"', '{ Text = "Beat a Slime Prince and his mom %d/%d"'),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    # the client and server code never write the old name themselves (it comes from Config.MonsterTypes)
    hits = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        for n, line in enumerate(read(path).splitlines(), 1):
            code = line.split("--", 1)[0]
            # the new boss's own words: a line that names SlimeKing, and the rows of KO1 'The King's Hop' (A23-110: the rows say
            # 'Defeat the King Slime' = the new boss, the personal King; the Slime Princes stay BigSlime)
            # A23-127 (plan 10/13 §1-A #2): the iron weapon is the real King Slime's first drop - the drop goal / its short
            # name (게임성 개발 1), the tier-3 source line, the first King's weapon lines (게임성 개발 2)
            drop = re.search(r"\b(NextIronDrop|IronDrop|FirstKingWeapon|FirstKingEquip) = ", code) \
                or 'Source = "King Slime drop' in code or 'King = "King Slime",' in code  # A23-222: M1_2's King mark
            if re.search(r"king slime(?! hill)", code, re.I) and "SlimeKing" not in code and 'Text = "Defeat the King Slime"' not in code \
                    and not drop:
                hits.append(f"{path.relative_to(ROOT).as_posix()}:{n}")
    check(not hits, "no script writes 'King Slime' in code: " + ", ".join(hits[:5]))
    glossary = read(ROOT / "docs/design/glossary_en_2026-10-06.md")
    check("Slime Prince" in glossary, "the English glossary lists 'Slime Prince'")
    return count, failures


SUITE = Suite(
    mark="SLIME_PRINCE",
    fixture=ROOT / "tools/fixtures/slime_prince_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-08/offline_dev3_slime_prince_2026-10-08.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="A23-84: Config.MonsterTypes.BigSlime Name / Short = 'Slime Prince'; no Config text says 'King Slime' "
             "except the new boss's own entries (a SlimeKing path, a story quest that counts SlimeKing, the KO1 rows 'Defeat the King Slime') and 'King Slime "
             "Hill'; S0 / M1_1 / M2_6 / H1 / XR1 / R5 texts say Slime Prince(s); Otto's M1_1 line "
             "carry the family (the princes = big brothers of the green slimes, A23-85: no mom / queen line); every "
             "objective still counts BigSlime (S0, M1_1, M2_6, H1, XR1, R5, Loot.FirstScroll, Board Meadow.Big, the "
             "rookie daily 3 strict).",
    limitations="The barks (Config.Barks.BigSlime 'Royal BOING!') and the icon / 3D crown are other sessions' (검수 "
                "wording -> game dev 2, image dev). The new boss SlimeKing is game dev 2's.",
)

if __name__ == "__main__":
    run(SUITE)
