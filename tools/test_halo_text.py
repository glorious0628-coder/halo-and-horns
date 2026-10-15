"""Halo town text pass (zone_check_halo_2026-10-10 #44 / #55 + the guide's two-page welcome, ui_clutter_review) (게임성 개발 3,
2026-10-10), offline.

- #44: the first-mission row says where the Forge is: Text.Forge = "Go to Otto's Forge in the Crossroads" (phone ShortName
  "To the Forge" stays).
- #55 easy English: the Sprout Oath side quests (OathH / OathR) say "promise" (title, phone name, step, Bright's / Smokey's line),
  H6 "Dusty Heroes" says where the statues are ("... in Halo Citadel"); Hallie's fixed catchphrase stays on page 1 of her
  welcome and opens the M1_4 report; its payoff line in M3_5 is untouched.
- ui_clutter_review (A23-99 less hand-holding): each guide's welcome has two pages (the catchphrase, the mission card).
Reads the CURRENT Config on tools/fixtures/dev2_kit.luau with tools/fixtures/halo_text_offline.luau and the installed official
Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on in-memory copies of the Config only.

Usage: py tools/test_halo_text.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-10/offline_dev3_halo_text_2026-10-10.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {"CONFIG_SOURCE": SHARED / "Config.luau"}
C = "CONFIG_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    ("Forge row forgets the Crossroads", C, "Forge = \"Go to Otto's Forge in the Crossroads\",", "Forge = \"Go to Otto's Forge\","),
    ("Forge row says Smithy", C, "Forge = \"Go to Otto's Forge in the Crossroads\",", "Forge = \"Go to the Smithy in the Crossroads\","),
    ("Halo oath title is back", C, "Title = \"The Sprout Promise\", ShortName = \"Sprout promise\", Speaker = \"Bright\"",
     "Title = \"The Sprout Oath\", ShortName = \"Sprout promise\", Speaker = \"Bright\""),
    ("Horns oath title is back", C, "Title = \"The Sprout Promise\", ShortName = \"Sprout promise\", Speaker = \"Smokey\"",
     "Title = \"The Sprout Oath\", ShortName = \"Sprout promise\", Speaker = \"Smokey\""),
    ("Halo oath phone name is back", C, "ShortName = \"Sprout promise\", Speaker = \"Bright\"", "ShortName = \"Sprout oath\", Speaker = \"Bright\""),
    ("Horns oath phone name is back", C, "ShortName = \"Sprout promise\", Speaker = \"Smokey\"", "ShortName = \"Sprout oath\", Speaker = \"Smokey\""),
    ("Halo oath step is back", C, "{ Text = \"Make your promise to Bright\"", "{ Text = \"Make your oath to Bright\""),
    ("Horns oath step is back", C, "{ Text = \"Make your promise to Rose\"", "{ Text = \"Make your oath to Rose\""),
    ("Bright says oath", C, "Bright: You did it! Make your promise.", "Bright: You did it! Say your oath."),
    ("Rose says oath", C, "Rose: Not bad, rascal! Make your promise.", "Rose: Not bad, rascal! Say your oath."),
    ("H6 forgets the town", C, "{ Text = \"Look at the hero statues in Halo Citadel %d/%d s\"", "{ Text = \"Look at the hero statues %d/%d s\""),
    ("Hallie's catchphrase is replaced", C, "\"Hallie here! Now you know my name. Welcome to the Knights!\",",
     "\"You're back! Good work out there. Welcome to the Knights!\","),
    # 사용자 10/15 (fix/welcome-order): page 1 = the hello, page 2 = the mission
    ("Halo welcome has a third page", C, "\t\t\t\t\"Hallie here! Now you know my name. Welcome to the Knights!\",\n\t\t\t\t\"First, go to Otto's Forge",
     "\t\t\t\t\"Hallie here! Now you know my name. Welcome to the Knights!\",\n\t\t\t\t\"Thank you for joining the Knights of Light.\",\n\t\t\t\t\"First, go to Otto's Forge"),
    ("Horns welcome has a third page", C, "\t\t\t\t\"Finders keepers! HA! You're with us now. I'm Magpie.\",\n\t\t\t\t\"First, go to Otto's Forge",
     "\t\t\t\t\"Finders keepers! HA! You're with us now. I'm Magpie.\",\n\t\t\t\t\"Welcome, rookie!\",\n\t\t\t\t\"First, go to Otto's Forge"),
    ("Guild welcome has a third page", C, "\t\t\t\t\"Fix first. Talk later. I'm Kit. Welcome to the Guild!\",\n\t\t\t\t\"First, go to Otto's Forge",
     "\t\t\t\t\"Fix first. Talk later. I'm Kit. Welcome to the Guild!\",\n\t\t\t\t\"Thanks for joining.\",\n\t\t\t\t\"First, go to Otto's Forge"),
    ("the mission card is gone from page 2 (Halo)", C, "\t\t\t\t\"Hallie here! Now you know my name. Welcome to the Knights!\",\n\t\t\t\t\"First, go to Otto's Forge and get your weapon!\",",
     "\t\t\t\t\"Hallie here! Now you know my name. Welcome to the Knights!\",\n\t\t\t\t\"Hi!\","),
]


def static() -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    cfg = read(SHARED / "Config.luau")
    for quest_id in ("OathH", "OathR"):
        block = cfg.split(f"\t\t{quest_id} = {{", 1)[1].split("\n\t\t},\n", 1)[0]
        body = strip_comments(block.split("\t\t\tFinish =", 1)[0])
        check(re.search(r"\boath\b", body, re.I) is None,
              f"{quest_id}: no 'oath' word in the player-facing text before its closing line (the closing line is game dev 2's, #54)")
    return count, failures


SUITE = Suite(
    mark="HALO_TEXT",
    fixture=ROOT / "tools/fixtures/halo_text_offline.luau",
    world=None,
    out=ROOT / "docs/art/verification_2026-10-10/offline_dev3_halo_text_2026-10-10.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="#44 Text.Forge 'Go to Otto's Forge in the Crossroads' (ShortName 'To the Forge'); #55 OathH / OathR title 'The Sprout "
             "Promise', phone name 'Sprout promise', steps 'Make your promise to Bright / Smokey', 'Make your promise.' in the "
             "guides' lines (no 'oath' in the player-facing text but the closing line, which game dev 2 rewrites in #54); H6 step "
             "'Look at the hero statues in Halo Citadel'; Hallie's catchphrase stays page 1 of her welcome and opens the M1_4 "
             "report; every guide's welcome has two pages (the catchphrase, the mission card).",
    limitations="Text only: where the client draws the welcome (page buttons) is game dev 1's window; the Halo / Horns welcome "
                "counts are also asserted by test_onboarding / test_english.",
)

if __name__ == "__main__":
    run(SUITE)
