"""A23-143 chat stickers, the client side (게임성 개발 1, 2026-10-13; the server = 게임성 개발 2's SendSticker), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and StickerUI.luau (tools/fixtures/sticker_ui_offline.luau) on
doubles. Rows: the 18 Config.Stickers.Order keys, the 5 free ones (the art part's Free) always open, the other 13 locked
without my PassStickers. CanSend: a sticker key only (never the monsters' pain stickers or words), free or the pass, alive,
at most every Config.RateLimits.SendSticker s. Send fires SendSticker(key) once and keeps the gap. The Fx "Sticker"
{ UserId, Key } draws that art over that player's head (one per player, a new one replaces it, gone after
Config.Stickers.Seconds + the fade, gone when they leave); other kinds / bad keys / bad ids are ignored. The picker (the
Keybinds "Stickers" action, P): PanelCard art, 18 SlotCommon cells, a locked one dimmed with IconLock and a press opens the
Shop; an open one sends and closes; a game-processed key does nothing; the pass unlocks at once; the key again closes.
Static: ClientMain loads StickerUI once, Config.Keybinds has the Stickers action on P, no player text in the module.
Mutations: each must be caught.

Usage: py tools/test_sticker_ui.py
Report: docs/art/verification_2026-10-13/offline_sticker_ui_2026-10-13.json
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
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "UI": SPS / "StickerUI.luau",
         "MAIN": SPS / "ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/sticker_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_sticker_ui_2026-10-13.json"

MUTATIONS = [
    ("UI", "every sticker open without the pass", "Locked = not free and hasPass ~= true", "Locked = false"),
    ("UI", "a pack sticker sent without the pass", "if not (Config.StickerFree(key) or ctx.Pass == true) then return false end", ""),
    ("UI", "any key sent", "if type(Config.IsSticker) ~= \"function\" or not Config.IsSticker(key) then return false end", ""),
    ("UI", "no gap between stickers", "return (tonumber(ctx.Now) or 0) - (tonumber(ctx.LastAt) or -math.huge) >= gap + L.GapPad",
     "return true"),
    ("UI", "sent while dead", "\tif ctx.Alive == false then return false end\n", ""),
    ("UI", "the gap never starts", "\tif ok then S.LastAt = now end\n", ""),
    ("UI", "two stickers over one head", "\tif rec and rec.Gui then pcall(function() rec.Gui:Destroy() end) end\n\tlocal gui",
     "\tlocal gui"),
    ("UI", "the sticker stays forever", "\t\t\t\tpcall(function() gui:Destroy() end)\n", ""),
    ("UI", "any Fx key drawn", "or not (type(Config.IsSticker) == \"function\" and Config.IsSticker(data.Key)) then return end", "then return end"),
    ("UI", "a locked press sends instead of the shop", "\t\t\tif cell and cell.Locked then\n", "\t\t\tif false then\n"),
    ("UI", "no lock badge", "\t\t\tif cell.Lock then cell.Lock.Visible = row.Locked end\n", ""),
    ("UI", "typing opens the picker", "if processed or keys.IsCapturing() or UserInputService:GetFocusedTextBox() then return end",
     "if keys.IsCapturing() then return end"),
    ("UI", "the pass never unlocks the open picker", "\t\tif S.Gui then pcall(paint) end\n", ""),
    ("UI", "a leaving player's sticker stays", "\t\tif rec and rec.Gui then pcall(function() rec.Gui:Destroy() end) end\n\t\tS.Heads[p.UserId] = nil",
     "\t\tS.Heads[p.UserId] = nil"),
    ("CONFIG", "no key for the picker", '{ Id = "Stickers", Group = "Other", Key = "P",', '{ Id = "Stickers", Group = "Other", Key = "",'),
    ("MAIN", "StickerUI never loaded", '"PlayerListUI", "StickerUI", "MonsterLabels"', '"PlayerListUI", "MonsterLabels"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = "\n".join(l for l in src["UI"].splitlines() if not l.strip().startswith("--"))
    literals = re.findall(r'\bText\s*=\s*"[^"]+"', code)
    return [
        ("ClientMain loads StickerUI once (after UIKit, Keybinds, Panels)", names.count("StickerUI") == 1
         and names.index("StickerUI") > max(names.index("UIKit"), names.index("Keybinds"), names.index("Panels"))),
        ("Config.Keybinds: the Stickers action (Group Other, key P)",
         '{ Id = "Stickers", Group = "Other", Key = "P",' in src["CONFIG"]),
        ("no player text in StickerUI (A23-130: pictures only)", not literals),
        ("the server's contract: SendSticker remote, Fx 'Sticker', Config.Stickers / StickerFree / IsSticker",
         'Remote = "SendSticker"' in src["UI"] and 'kind ~= "Sticker"' in src["UI"] and "Config.Stickers = {" in src["CONFIG"]
         and "function Config.StickerFree(key)" in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal UI_SOURCE = " + lua_str(src["UI"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "sticker_ui.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"STICKER_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
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
