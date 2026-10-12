"""A23-144 chat bubble skins, the client side (게임성 개발 1, 2026-10-13; the server = 게임성 개발 2's SetBubble / BubbleOn),
offline.

Runs, in the official Luau CLI, the CURRENT Config.luau, BubbleUI.luau and StickerUI.luau
(tools/fixtures/bubble_ui_offline.luau) on doubles. BubbleUI owns TextChatService.OnBubbleAdded (the only assignment in
src/): the speaker's BubbleOn skin (else their side's free one; none without a side) as a BubbleChatMessageProperties -
the skin's art as a 9-slice ImageLabel once uploaded, else its colours (background, text, round corners, a gradient); a
system line or a gone player = Roblox's own bubble. Rows: my side's free one first + the 6 pack ones (never the other
sides' free ones), locked without PassBubbles, the worn one marked. Pick: SetBubble once per Config.RateLimits.SetBubble,
my free one = "", nothing for a locked or worn one. The sticker picker (P) shows the bubble row: 7 cells, the worn one
framed, a locked one with IconLock opening the Shop, the pack unlocking at once, a press sending and closing.
Static: OnBubbleAdded is set only in BubbleUI.luau; ClientMain loads BubbleUI before StickerUI. Mutations: each must be caught.

Usage: py tools/test_bubble_ui.py
Report: docs/art/verification_2026-10-13/offline_bubble_ui_2026-10-13.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "BUBBLE": SPS / "BubbleUI.luau",
         "STICKER": SPS / "StickerUI.luau", "MAIN": SPS / "ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/bubble_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_bubble_ui_2026-10-13.json"

MUTATIONS = [
    ("BUBBLE", "never hooked", "local ok, err = pcall(function() TextChatService.OnBubbleAdded = onBubble end)",
     "local ok, err = true, nil"),
    ("BUBBLE", "BubbleOn ignored (always the side's)", "if type(Config.IsBubble) == \"function\" and Config.IsBubble(bubbleOn) then return bubbleOn end",
     ""),
    ("BUBBLE", "other sides' free bubbles offered", "\t\tif Config.BubbleSide(key) == nil then\n", "\t\tif key ~= mine then\n"),
    ("BUBBLE", "the pack open to everyone", "Locked = hasPass ~= true, Worn = worn == key", "Locked = false, Worn = worn == key"),
    ("BUBBLE", "no worn mark", "Free = true, Locked = false, Worn = worn == mine", "Free = true, Locked = false, Worn = false"),
    ("BUBBLE", "art never used", "local art = (type(part) == \"table\" and type(part.Id) == \"string\" and part.Id ~= \"\") and part or nil",
     "local art = nil"),
    ("BUBBLE", "the code look loses its colour", "\t\tprops.BackgroundColor3 = look.Bg\n", ""),
    ("BUBBLE", "a locked skin sent", "if not row or row.Locked or row.Worn then return false end", "if not row or row.Worn then return false end"),
    ("BUBBLE", "my free one sent as its key", "local send = row.Free and \"\" or key", "local send = key"),
    ("BUBBLE", "no gap", "if now - S.LastAt < gap + L.GapPad then return false end", ""),
    ("STICKER", "no bubble row", "\tfor i, row in bubbles do\n", "\tfor i, row in {} do\n"),
    ("STICKER", "a locked bubble sends", "local cell = S.Bubbles[key]\n\t\t\tif cell and cell.Locked then\n",
     "local cell = S.Bubbles[key]\n\t\t\tif false then\n"),
    ("STICKER", "the worn frame never moves", "\t\t\tif cell.Worn then cell.Worn.Enabled = row.Worn == true end\n", ""),
    ("STICKER", "the pack never unlocks the open picker", 'for _, a in { "PassBubbles", "BubbleOn" } do', 'for _, a in { "BubbleOn" } do'),
    ("MAIN", "BubbleUI never loaded", '"BubbleUI", "StickerUI"', '"StickerUI"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    owners = [p.name for p in (ROOT / "src").rglob("*.luau")
              if re.search(r"\bOnBubbleAdded\s*=", p.read_text(encoding="utf-8", errors="replace"))]
    code = "\n".join(l for l in src["BUBBLE"].splitlines() if not l.strip().startswith("--"))
    return [
        ("only BubbleUI sets TextChatService.OnBubbleAdded (one callback)", owners == ["BubbleUI.luau"]),
        ("ClientMain loads BubbleUI once, before StickerUI", names.count("BubbleUI") == 1 and "StickerUI" in names
         and names.index("BubbleUI") < names.index("StickerUI")),
        ("no player text in BubbleUI (A23-130)", re.search(r'\bText\s*=\s*"[^"]+"', code) is None),
        ("the server's contract: SetBubble, BubbleOn, PassBubbles, Config.Bubbles.Free / Order / BubbleSide",
         'Remote = "SetBubble"' in src["BUBBLE"] and 'GetAttribute("BubbleOn")' in src["BUBBLE"]
         and "Config.Bubbles = {" in src["CONFIG"] and "function Config.BubbleSide(key)" in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal BUBBLE_SOURCE = " + lua_str(src["BUBBLE"])
            + "\nlocal STICKER_SOURCE = " + lua_str(src["STICKER"]) + "\n" + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "bubble_ui.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"BUBBLE_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
