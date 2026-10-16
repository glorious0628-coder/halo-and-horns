"""A23-218 (2): set a Studio test scene in one call (SceneSetup.luau through Main's Studio-only DebugCommand "Scene").

Usage (a Play session running in the Studio window that tools/studio_mcp.py picks: STUDIO_NAME=UiSandbox / WorldKit /
FilmSet, or HH_MAIN_STUDIO=1 for the main game window - only 메인 반영 1):
    py tools/scene.py list                      the presets
    py tools/scene.py Calm                      a preset (FirstPrince, FountainChoice, OfferM1_3, PipGate, ClatterBoss, Calm,
                                                WarEnd, TutorialTeacher, TutorialForge, ArtisanAlch, ArtisanSmith)
    py tools/scene.py Kill                      beat the nearest monster the scenes made (a real kill: the calm fade)
    py tools/scene.py '{"Level":12,"At":"Zone:GoblinWoods","Monsters":[{"Kind":"Goblin","N":2}]}'   a spec (JSON)
    py tools/scene.py Calm --player Name        another player than the first one in the server
Prints the server's one-line answer ("ok: ..." or the problem). Starting Play steals focus: announce it first (rule 6).
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio_mcp import Client  # noqa: E402

PRESETS = ["FirstPrince", "FountainChoice", "OfferM1_3", "PipGate", "ClatterBoss", "Calm", "WarEnd", "TutorialTeacher",
           "TutorialForge", "ArtisanAlch", "ArtisanSmith"]


def text_of(res: dict) -> str:
    return "".join(p.get("text", "") for p in res.get("content", []))


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv[0] == "list":
        print(" ".join(PRESETS) + "  (+ Kill, or a JSON spec)")
        return 0
    value = argv[0]
    player = None
    if "--player" in argv:
        player = argv[argv.index("--player") + 1]
    who = "game:GetService('Players'):FindFirstChild(%s)" % json.dumps(player) if player \
        else "game:GetService('Players'):GetPlayers()[1]"
    code = ("local p = %s\nif not p then return 'no player in Play' end\n"
            "local fn = game:GetService('ServerScriptService'):FindFirstChild('DebugCommand')\n"
            "if not fn then return 'no DebugCommand (Studio Play only)' end\n"
            "return fn:Invoke(p.Name, 'Scene', %s)" % (who, json.dumps(value)))
    c = Client()
    c.start()
    try:
        res = c.call("execute_luau", {"code": code, "datamodel_type": "Server"})
    finally:
        c.close()
    out = text_of(res)
    print(out)
    return 1 if res.get("isError") or "ok" not in out else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
