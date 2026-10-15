"""Friends find each other (최종 검수 10/15 #8), static. Party.luau: a player Party.Marked (my party member or Roblox
friend) farther than Mark.Near studs gets a small round dot in their side's colour over the head (a BillboardGui seen
through walls, up to Mark.Far studs; no name, no words); near or not marked = hidden. The pass runs in Party.Start's loop.
(The minimap's bigger dots for the same players are MiniMap's, A23-201.) Each mutation must make a check fail.

Usage: py tools/test_friend_mark.py
"""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PARTY = ROOT / "src/StarterPlayer/StarterPlayerScripts/Party.luau"
STATIC = [
    ("near / far rule", ["\treturn marked == true and type(d) == \"number\" and d > L.Mark.Near and d <= L.Mark.Far\n",
                         'L.Mark = { Name = "HH_FriendMark", Px = 14, Lift = 3.2, Near = 25, Far = 600, Rim = 2 }']),
    ("the dot follows Party.Marked, round, side colour, seen through walls", [
        "\t\t\tlocal on = Party.MarkShows(Party.Marked(p), d)\n", "\t\t\t\tcorner.CornerRadius = UDim.new(0.5, 0)\n",
        "dot.BackgroundColor3 = sideColor(p:GetAttribute(\"Faction\"))", "bb.AlwaysOnTop, bb.LightInfluence, bb.MaxDistance = true, 0, M.Far"]),
    ("no words on it", []),
    ("the pass runs in Start", ["\t\t\t\tParty.RefreshMarks() -- #8: the far friends' dots\n"]),
]
MUTATIONS = [
    ("shown up close", "and d > L.Mark.Near and", "and"),
    ("shown for everyone", "\t\t\tlocal on = Party.MarkShows(Party.Marked(p), d)\n", "\t\t\tlocal on = Party.MarkShows(true, d)\n"),
    ("the pass never runs", "\t\t\t\tParty.RefreshMarks() -- #8: the far friends' dots\n", ""),
    ("a name on the dot", "\t\t\t\tdot.Parent = bb\n", "\t\t\t\tdot.Parent = bb\n\t\t\t\tlocal tl = Instance.new(\"TextLabel\")\n\t\t\t\ttl.Parent = dot\n"),
]


def check(src: str) -> list[str]:
    fails = [n for n, needles in STATIC if not all(src.count(x) == 1 for x in needles)]
    body = src[src.find("function Party.RefreshMarks()"):src.find("-- the frames")]
    if "TextLabel" in body or ".Text =" in body:
        fails.append("no words on it")
    return fails


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = PARTY.read_text(encoding="utf-8")
    fails = check(src)
    for f in fails:
        print("STATIC_FAIL " + f)
    caught = 0
    for name, old, new in MUTATIONS:
        ok = src.count(old) == 1 and len(check(src.replace(old, new))) > 0
        caught += ok
        print(("MUTATION caught  " if ok else "MUTATION MISSED ") + name)
    status = "passed" if not fails and caught == len(MUTATIONS) else "failed"
    print(f"Status: {status} (mutations {caught}/{len(MUTATIONS)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
