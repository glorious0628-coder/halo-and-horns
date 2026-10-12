"""Alchemy buff row (게임성 개발 4, 2026-10-12; SPEC A23-133 tonics, A23-130 no words; server contract
src/ServerScriptService/BuffService.luau: the player attribute "Buff_<itemId>" = the SERVER time the tonic ends, 0 = none), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and BuffBar.luau in tools/fixtures/buff_bar_offline.luau (Players /
Instance tree / UIKit / HUD.Layout / task doubles). Checks: Clock (m:ss, rounded up, never negative); Active (the soonest end
first, a steady order on a tie, at most Config.Alchemy.MaxActive, ended ones and 0 dropped, only the Config tonic ids);
the row is built once under UIKit.Gui and hidden while nothing runs, tonics are off, the HUD is hidden or no HUD layout
exists; the tiles (approved slot art SlotCommon 34 du, BagUI's code fallback, the icon in the Inner box, the name's first
letter in the item's colour while the art is missing, the time under each tile in the Number style, no words); an
attribute signal per tonic + one 0.25 s loop that moves the timers; the placement from a fake HUD.Layout (right edge =
hp_bar.X + hp_bar.W, bottom = power_line.Y - 4), Relayout, and a layout the HUD made while the bar did not listen.
Static: ClientMain loads BuffBar after QuickSlots / HUD / UIKit, HUD's relayout list has "BuffBar", BuffBar has no
Enum.KeyCode and no hard-coded English outside TXT. Mutations: each must be caught.

Usage: py tools/test_buff_bar.py
Report: docs/art/verification_2026-10-12/offline_buff_bar_2026-10-12.json
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
FILES = {"BUFF": SPS / "BuffBar.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": SPS / "ClientMain.client.luau", "HUD": SPS / "HUD.luau"}
FIXTURE = ROOT / "tools/fixtures/buff_bar_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_buff_bar_2026-10-12.json"

MUTATIONS = [
    ("BUFF", "the latest end first", "\t\tif a.Ends ~= b.Ends then return a.Ends < b.Ends end\n", "\t\tif a.Ends ~= b.Ends then return a.Ends > b.Ends end\n"),
    ("BUFF", "a tie in the wrong order", "\t\treturn a.Id < b.Id\n", "\t\treturn a.Id > b.Id\n"),
    ("BUFF", "no cap", "\twhile #out > cap do table.remove(out) end\n", ""),
    ("BUFF", "the cap is a fixed 2", "\tlocal cap = maxActive()\n", "\tlocal cap = 2\n"),
    ("BUFF", "the ending second still shows", "\t\tif ends > t then table.insert(out,", "\t\tif ends >= t then table.insert(out,"),
    ("BUFF", "an ended tonic still shows", "\t\tif ends > t then table.insert(out,", "\t\tif ends > 0 then table.insert(out,"),
    ("BUFF", "the time rounds down", "local s = math.max(0, math.ceil(num(seconds, 0)))", "local s = math.max(0, math.floor(num(seconds, 0)))"),
    ("BUFF", "the time can go negative", "local s = math.max(0, math.ceil(num(seconds, 0)))", "local s = math.ceil(num(seconds, 0))"),
    ("BUFF", "seconds not padded", "Clock = \"%d:%02d\",", "Clock = \"%d:%d\","),
    ("BUFF", "shown while tonics are off", "\tif on() then\n\t\tlist = BuffBar.Active(", "\tif true then\n\t\tlist = BuffBar.Active("),
    ("BUFF", "shown with nothing running", "local show = #list > 0 and S.Anchor ~= nil and hudShown()", "local show = S.Anchor ~= nil and hudShown()"),
    ("BUFF", "shown while the HUD is hidden", "local show = #list > 0 and S.Anchor ~= nil and hudShown()", "local show = #list > 0 and S.Anchor ~= nil"),
    ("BUFF", "shown without a HUD layout", "local show = #list > 0 and S.Anchor ~= nil and hudShown()", "local show = #list > 0 and hudShown()"),
    ("BUFF", "the tiles never change", "\tif sig ~= S.Sig then\n", "\tif S.Sig == nil then\n"),
    ("BUFF", "the times never move", "\t\tif tile and tile.Time.Text ~= text then tile.Time.Text = text end\n", ""),
    ("BUFF", "another slot art", "\tSlot = \"SlotCommon\",", "\tSlot = \"SlotRare\","),
    ("BUFF", "a bigger tile", "\tTile = 34,", "\tTile = 40,"),
    ("BUFF", "no letter without art", "\telse\n\t\t-- the icon art is not drawn yet", "\telseif false then\n\t\t-- the icon art is not drawn yet"),
    ("BUFF", "the letter is white", "letter.TextColor3 = (type(def) == \"table\" and typeof(def.Color) == \"Color3\") and def.Color or T.White",
     "letter.TextColor3 = T.White"),
    ("BUFF", "the icon outside the Inner box", "Inner = { X = 76 / 512,", "Inner = { X = 0,"),
    ("BUFF", "the time in another style", "pcall(kit.StyleText, clock, \"Number\")", "pcall(kit.StyleText, clock, \"Title\")"),
    ("BUFF", "the right edge is the bar's left", "S.Anchor = { X = edge.X + edge.W,", "S.Anchor = { X = edge.X,"),
    ("BUFF", "the MP bar ignored (the tiles hang between the bars)", "and tonumber(mp.W)) and mp or hp", "and tonumber(mp.W)) and hp or hp"),
    ("BUFF", "no gap above the power line", "Y = pl.Y - T.Above }", "Y = pl.Y }"),
    ("BUFF", "no attribute signals", "LocalPlayer:GetAttributeChangedSignal(\"Buff_\" .. id):Connect(function()",
     "LocalPlayer:GetAttributeChangedSignal(\"Buff_\" .. id .. \"x\"):Connect(function()"),
    ("BUFF", "the loop is slow", "\tTick = 0.25,", "\tTick = 1,"),
    ("BUFF", "a layout made meanwhile is never read", "\t\t\tif layout ~= S.LayoutRef then BuffBar.Relayout() end -- a layout made while this was not listening\n", ""),
    ("BUFF", "Start runs twice", "\tif S.Built then return end -- Start() runs once\n", ""),
    ("BUFF", "no text table", "L10n.Register(\"BuffBar.TXT\", TXT)\n", ""),
    ("BUFF", "a word on the row", "\tclock.TextSize = T.CapH\n", "\tclock.TextSize = T.CapH\n\tclock.TextTooltip = \"Time left\"\n"),
    ("BUFF", "a fixed key", "\tclock.TextSize = T.CapH\n", "\tclock.TextSize = T.CapH\n\tlocal k = Enum.KeyCode.G\n"),
    ("MAIN", "never loaded", "\"QuickSlots\", \"BuffBar\",", "\"QuickSlots\","),
    ("MAIN", "loaded far from QuickSlots", "\"HUD\", \"EventHUD\",", "\"HUD\", \"BuffBar\", \"EventHUD\","),
    ("HUD", "the HUD never tells it to relayout", "{ \"EventHUD\", \"MiniMap\", \"SkillBar\", \"BuffBar\" }", "{ \"EventHUD\", \"MiniMap\", \"SkillBar\" }"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def code_of(text: str) -> str:
    return "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = code_of(src["BUFF"])
    # the player text lives in TXT only: cut the table, then look for two English words in one string (dev log lines
    # through Util.Warn are not player text)
    body = re.sub(r"local TXT = \{.*?\n\}\n", "", code, count=1, flags=re.S)
    english = [l for l in body.splitlines() if "Util.Warn" not in l
               and any(re.search(r"[A-Za-z]{2,} [A-Za-z]{2,}", s) for s in re.findall(r'"([^"\n]*)"', l))]
    txt = re.search(r"local TXT = \{(.*?)\n\}\n", code, flags=re.S)
    txt_keys = re.findall(r"(\w+)\s*=", txt.group(1)) if txt else ["?"]
    return [
        ("ClientMain loads BuffBar right after QuickSlots, after UIKit and HUD", "BuffBar" in names and "QuickSlots" in names
         and names.index("BuffBar") == names.index("QuickSlots") + 1 and names.index("BuffBar") > names.index("UIKit")
         and names.index("BuffBar") > names.index("HUD")),
        ("HUD's relayout list has \"BuffBar\"", '{ "EventHUD", "MiniMap", "SkillBar", "BuffBar" } do' in src["HUD"]
         and "pcall(m.Relayout)" in src["HUD"]),
        ("BuffBar has no Enum.KeyCode (no fixed key)", "Enum.KeyCode" not in code),
        ("BuffBar has no hard-coded English outside TXT" + (f" ({english[0].strip()})" if english else ""), not english),
        ("BuffBar's TXT is only the clock's shape (no words, A23-130)", txt_keys == ["Clock"]),
        ("BuffBar uses the approved art only through UIKit (ArtFrame / ItemIcon / StyleText)", "kit.ArtFrame(T.Slot," in code
         and "kit.ItemIcon(" in code and "kit.StyleText" in code and "rbxassetid" not in code),
        ("BuffBar uses task.* only and pcall's its loop", "task.spawn(loop)" in code and "task.wait(T.Tick)" in code
         and not re.search(r"(?<![\w.])(wait|spawn|delay)\(", code)),
        ("Config has the tonics BuffBar reads (Alchemy.Tonics, MaxActive, the Tonics switch)", "Config.Alchemy = {" in src["CONFIG"]
         and "MaxActive = 2," in src["CONFIG"] and "Config.Features.Tonics = false" in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal BUFF_SOURCE = " + lua_str(src["BUFF"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "buff_bar.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"BUFF_BAR_SUMMARY checks=(\d+) failed=(\d+)", out)
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
