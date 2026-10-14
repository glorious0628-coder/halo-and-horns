"""Help & Safety static check (검수 2026-10-09, system review ③).

Config.Help.Topics has a "Safety" topic right after Controls (block / report through the Roblox menu, the Tab list's
buttons, PvP zones, "Ask a parent before using Robux"), at most 4 lines, English only. PlayerListUI: a press on another
player's name shows [Add friend] / [Block] that call Roblox's own prompts (StarterGui SetCore PromptSendFriendRequest /
PromptBlockPlayer) for that player only (never my own row), and closing the list or the player leaving drops the pick.
The prompts are Roblox CoreGui: their look is a Studio check. Each mutation must make a check fail.

Usage: py tools/test_safety.py
Report: docs/art/verification_2026-10-09/offline_safety_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "LIST": ROOT / "src/StarterPlayer/StarterPlayerScripts/PlayerListUI.luau"}
OUT = ROOT / "docs/art/verification_2026-10-09/offline_safety_2026-10-09.json"


def safety_lines(config: str):
    m = re.search(r'\t\t\{ Id = "Controls", Title = "Controls", Lines = \{\} \},\n(?:\t\t--[^\n]*\n)*'
                  r'\t\t\{ Id = "Safety", Title = "Safety", Lines = \{\n(.*?)\n\t\t\} \},', config, re.S)
    return re.findall(r'"([^"]*)"', m.group(1)) if m else None


def checks(src: dict) -> list[tuple[str, bool]]:
    c, l = src["CONFIG"], src["LIST"]
    lines = safety_lines(c)
    out = [
        ("Help: a Safety topic right after Controls", lines is not None),
        ("Safety: at most 4 lines, English only", bool(lines) and len(lines) <= 4
         and all(not re.search(r"[가-힣]", x) for x in lines)),
        ("Safety: block / report, PvP zones, ask a parent before Robux", bool(lines)
         and any("Block or report" in x for x in lines) and any("PvP" in x for x in lines)
         and any("Ask a parent before using Robux" in x for x in lines)),
        ("Tab list: Add friend / Block call Roblox's own prompts for the picked player",
         'for i, a in { { TXT.Friend, "PromptSendFriendRequest", "Good" }, { TXT.Block, "PromptBlockPlayer", "Bad" } } do' in l
         and "local ok, err = pcall(StarterGui.SetCore, StarterGui, kind, target)" in l
         and 'Friend = "Add friend",' in c and 'Block = "Block",' in c and "local TXT = Config.ClientText.PlayerListUI" in l),
        ("never my own row", 'if typeof(target) ~= "Instance" or target == LocalPlayer or not target.Parent then return end' in l
         and "\tif row.Pick then row.Pick.Visible = not mine end\n" in l
         and "if rec.Player == nil or rec.Player == LocalPlayer then return end" in l),
        ("a second press / closing / leaving drops the pick",
         "S.Pick = (S.Pick ~= rec.Player) and rec.Player or nil" in l and "\t\tS.Open = false\n\t\tS.Pick = nil\n" in l
         and "if S.Pick and not S.Pick.Parent then S.Pick = nil end" in l),
        ("only the picked row shows the buttons", "local on = S.Pick ~= nil and row.Player == S.Pick and row.Frame.Visible" in l),
    ]
    return out


MUTATIONS = [
    ("CONFIG", "no Safety topic", '\t\t{ Id = "Safety", Title = "Safety", Lines = {\n', '\t\t{ Id = "Safe", Title = "Safety", Lines = {\n'),
    # the Safety topic's own line (Config.Help.TouchTopics.Safety repeats it for touch: tools/test_phone_text.py)
    ("CONFIG", "no parent line", '\t\t\t"Ask a parent before using Robux. Never share your password.",\n\t\t} },', "\t\t} },"),
    ("LIST", "my own row gets the buttons", "\tif row.Pick then row.Pick.Visible = not mine end\n", ""),
    ("LIST", "the pick stays after closing", "\t\tS.Open = false\n\t\tS.Pick = nil\n", "\t\tS.Open = false\n"),
    ("LIST", "Block sends a friend request", '{ TXT.Block, "PromptBlockPlayer", "Bad" }', '{ TXT.Block, "PromptSendFriendRequest", "Bad" }'),
    ("LIST", "every row shows the buttons", "local on = S.Pick ~= nil and row.Player == S.Pick and row.Frame.Visible",
     "local on = S.Pick ~= nil and row.Frame.Visible"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    res = checks(src)
    for name, ok in res:
        print(("CHECK_OK " if ok else "CHECK_FAIL ") + name)
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and not all(ok for _, ok in checks(m))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    passed = all(ok for _, ok in res) and all(m["caught"] for m in muts)
    status = "passed" if passed else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": [{"name": n, "ok": ok} for n, ok in res], "mutations": muts, "status": status},
                              indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {sum(ok for _, ok in res)}/{len(res)}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
