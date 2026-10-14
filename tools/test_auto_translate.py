"""Roblox automatic translation ON (SPEC A23-179, user 10/14: "개발을 영어로 하자고 했지 누가 자동 번역까지 끄래"), offline.

We write English (A23-48) and Roblox translates it (Creator Hub localization). Before: ClientMain set AutoLocalize = false
on every GuiBase2d / ProximityPrompt under PlayerGui and in the world (69f1fe45, 10/07), so every language stayed at 0 %
and the automatic text capture saw nothing. Rules now:
1. No game-wide switch-off: ClientMain has no AutoLocalize watcher; no code turns AutoLocalize off inside a
   DescendantAdded / ChildAdded handler.
2. AutoLocalize = false only at the narrow, listed places - player names (nametag line 1 "[title] name", the Tab list
   name, the supporter board rows), number-only labels (UIKit artText Number = true unless the caller says otherwise,
   the damage-number pool, the skill seconds) and typed text (the nickname box, the market box), plus UIKit.NoTranslate.
   Any other "AutoLocalize = false" in src/ fails (a new one has to be added here on purpose).
3. A loot line on the number pool is translated (spawnNumber: AutoLocalize = look ~= nil); the Altar of Fate prompt is set
   true (the saved place still has it off).
Static (comments stripped). Mutations: each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_auto_translate_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_auto_translate_2026-10-14.json"
SPS = "StarterPlayer/StarterPlayerScripts/"
# (file under src/, a snippet of the line that turns it off) - the whole allowed list
ALLOWED = [
    ("ServerScriptService/CharacterVisuals.luau", "line1.AutoLocalize = false"),
    (SPS + "Fx.luau", "gui.AutoLocalize = false"),
    (SPS + "SkillBar.luau", "AutoLocalize = false, -- A23-179: seconds only"),
    (SPS + "PlayerListUI.luau", "AutoLocalize = false, -- A23-179: a player's name"),
    (SPS + "SupporterBoard.luau", "row.AutoLocalize = false"),
    (SPS + "Panels.luau", 'Name = "NicknameInput", Parent = u.InputArt, AutoLocalize = false'),
    # review 10/14: number-only labels say it themselves (UIKit's Number = the font only)
    (SPS + "HUD.luau", "Number = true, AutoLocalize = false,"),
    (SPS + "AttendanceUI.luau", "Number = true, AutoLocalize = false,"),
    (SPS + "VitalsUI.luau", "Number = true, AutoLocalize = false,"),
    (SPS + "PlayerListUI.luau", "Number = true, AutoLocalize = false,"),
    (SPS + "CharacterUI.luau", "nickLabel.AutoLocalize = false"),
    (SPS + "UIKit.luau", "pcall(function() inst.AutoLocalize = false end)"),
]
REQUIRED = [
    ("the nametag's name line stays as it is", "ServerScriptService/CharacterVisuals.luau", "line1.AutoLocalize = false"),
    ("the HUD level number stays as it is", SPS + "HUD.luau", "Number = true, AutoLocalize = false,"),
    ("the character window's nickname stays as it is", SPS + "CharacterUI.luau", "nickLabel.AutoLocalize = false"),
    ("the nametag's title is its own translated label", "ServerScriptService/CharacterVisuals.luau", 'titleLabel.Name = "Title"'),
    ("damage numbers stay as they are", SPS + "Fx.luau", "gui.AutoLocalize = false"),
    ("a loot line on the number pool is translated", SPS + "Fx.luau", "e.Gui.AutoLocalize = look ~= nil"),
    ("the Tab list name stays as it is", SPS + "PlayerListUI.luau", "AutoLocalize = false, -- A23-179: a player's name"),
    ("supporters' names stay as they are", SPS + "SupporterBoard.luau", "row.AutoLocalize = false"),
    ("the nickname box (typed) stays as it is", SPS + "Panels.luau", "AutoLocalize = false"),
    ("the skill seconds stay as they are", SPS + "SkillBar.luau", "AutoLocalize = false, -- A23-179: seconds only"),
    ("the Altar of Fate prompt is translated again", "ServerScriptService/MapBuilder.luau", "prompt.AutoLocalize = true"),
    ("UIKit.NoTranslate exists", SPS + "UIKit.luau", "function UIKit.NoTranslate(inst)"),
]
MUTATIONS = [
    ("the old watcher comes back", SPS + "ClientMain.client.luau", "local ORDER = {",
     'do\n\tlocal function off(inst)\n\t\tif inst:IsA("GuiBase2d") then inst.AutoLocalize = false end\n\tend\n'
     '\tgame:GetService("Players").LocalPlayer:WaitForChild("PlayerGui").DescendantAdded:Connect(off)\nend\nlocal ORDER = {'),
    ("a plain text label switched off", SPS + "Panels.luau", "\tl.TextXAlignment = opts.Align or Enum.TextXAlignment.Left\n",
     "\tl.TextXAlignment = opts.Align or Enum.TextXAlignment.Left\n\tl.AutoLocalize = false\n"),
    ("the name line translated", "ServerScriptService/CharacterVisuals.luau", "\tline1.AutoLocalize = false", "\tline1.AutoLocalize = true"),
    ("the Number font switches translation off again", SPS + "UIKit.luau", "\t-- A23-179 (review 10/14): Number = the number font only;",
     "\tif props.Number and props.AutoLocalize == nil then p.AutoLocalize = false end\n\t-- A23-179 (review 10/14): Number = the number font only;"),
    ("the title back inside the name line", "ServerScriptService/CharacterVisuals.luau", "local line1 = Util.PlayerDisplayName(player)",
     'local line1 = "[" .. tostring(title) .. "] " .. Util.PlayerDisplayName(player)'),
    ("the Power line switched off", SPS + "HUD.luau", "Name = \"PowerUp\",", "Name = \"PowerUp\", AutoLocalize = false,"),
    ("the character window's name translated", SPS + "CharacterUI.luau", "pcall(function() nickLabel.AutoLocalize = false end)", "local _ = nickLabel"),
    ("loot lines never translated", SPS + "Fx.luau", "e.Gui.AutoLocalize = look ~= nil", "e.Gui.AutoLocalize = false"),
    ("the altar prompt off again", "ServerScriptService/MapBuilder.luau", "prompt.AutoLocalize = true", "prompt.AutoLocalize = false"),
    ("the Language row back in Order", "ReplicatedStorage/Shared/Config.luau", '"Tags", "BagSort", "Cam" },', '"Tags", "Lang", "BagSort", "Cam" },'),
    ("the picker's own crafting words back", SPS + "FactionPicker.luau", '"No loot or Wanted" },',
     '"No loot or Wanted", { "Crafting (soon)", "Crafting soon", "Crafting", "Craft" } },'),
    ("the note copy back", SPS + "FactionPicker.luau", 'local NEUTRAL_NOTE = ""', 'local NEUTRAL_NOTE = "No fight buffs · No PvP · Crafting (coming soon)"'),
    ("supporters' names translated", SPS + "SupporterBoard.luau", "\t\trow.AutoLocalize = false -- A23-179: supporters' names stay as they are\n", ""),
]


def strip(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] if "--" in line and not line.strip().startswith('"') else line
                     for line in text.splitlines())


def sources() -> dict[str, str]:
    out = {}
    for p in SRC.rglob("*.luau"):
        out[p.relative_to(SRC).as_posix()] = p.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    return out


def check(src: dict[str, str]) -> list[tuple[str, bool, str]]:
    rows = []
    cm = strip(src.get(SPS + "ClientMain.client.luau", ""))
    rows.append(("ClientMain has no AutoLocalize switch-off", "AutoLocalize" not in cm, ""))
    watch = []
    for f, text in src.items():
        for m in re.finditer(r"(DescendantAdded|ChildAdded):Connect\(", text):
            window = strip(text[m.start():m.start() + 600])
            body = window.split("\nend", 1)[0]
            if "AutoLocalize = false" in body:
                watch.append(f)
        # a named handler connected to DescendantAdded that switches AutoLocalize off
        for m in re.finditer(r"local function (\w+)\(\w+\)\n(.*?)\nend\n", text, re.S):
            if "AutoLocalize = false" in strip(m.group(2)) and re.search(r"(DescendantAdded|ChildAdded):Connect\(" + m.group(1) + r"\)", text):
                watch.append(f)
    rows.append(("no AutoLocalize = false inside a DescendantAdded / ChildAdded handler", not watch, ", ".join(sorted(set(watch)))))
    extra = []
    for f, text in src.items():
        for line in text.splitlines():
            code = strip(line)
            if re.search(r"AutoLocalize\s*=\s*false", code):
                if not any(f == af and snip in line for af, snip in ALLOWED):
                    extra.append(f"{f}: {line.strip()[:90]}")
    rows.append(("AutoLocalize = false only at the listed name / number / typed-text places", not extra, " | ".join(extra[:5])))
    for name, f, snip in REQUIRED:
        rows.append((name, snip in strip(src.get(f, "")) or snip in src.get(f, ""), f))
    # stale text (최종 검수 10/14, with A23-179 / A23-146): no Language row, the picker keeps no crafting words of its own
    cfg = src.get("ReplicatedStorage/Shared/Config.luau", "")
    start = cfg.find("Config.Settings = {")
    order = re.search(r"\tOrder = \{([^}]*)\}", cfg[start:]) if start >= 0 else None
    sui = strip(src.get(SPS + "SettingsUI.luau", ""))
    rows.append(("no Language row in Settings (auto translation on, no Korean mode)",
                 order is not None and '"Lang"' not in order.group(1) and 'settingsSet("Lang"' not in sui, ""))
    fp = strip(src.get(SPS + "FactionPicker.luau", ""))
    rows.append(("the faction picker keeps no crafting words of its own (Config.UIArt.FactionPerks / Factions.Neutral.Note)",
                 not re.search(r'"Craft(ing)?( \(soon\)| soon| \(coming soon\))?"', fp) and "Crafting (coming soon)" not in fp, ""))
    rows.append(("the Artisan note has no code copy", 'local NEUTRAL_NOTE = ""' in fp, ""))
    # review 10/14: the Number font never switches translation off by itself; the nametag's line 1 is the name alone
    ui = strip(src.get(SPS + "UIKit.luau", ""))
    rows.append(("UIKit's Number font does not turn translation off", "props.Number and props.AutoLocalize" not in ui, ""))
    cv = src.get("ServerScriptService/CharacterVisuals.luau", "")
    rows.append(("nametag line 1 = the name alone (the title is not in it)",
                 "local line1 = Util.PlayerDisplayName(player)" in cv and '"[" .. tostring(title) .. "] " ..' not in cv
                 and "titleLabel.AutoLocalize" not in cv, ""))
    hud = strip(src.get(SPS + "HUD.luau", ""))
    rows.append(("the HUD switches translation off only on its 5 number-only labels (not the Power line)",
                 len(re.findall(r"AutoLocalize\s*=\s*false", hud)) == 5, str(len(re.findall(r"AutoLocalize\s*=\s*false", hud)))))
    return rows


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = sources()
    rows = check(src)
    for name, ok, detail in rows:
        print(("CHECK_OK " if ok else "CHECK_FAIL ") + name + ("" if ok or not detail else f" :: {detail}"))
    muts = []
    for name, f, old, new in MUTATIONS:
        hits = src.get(f, "").count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[f] = src[f].replace(old, new)
            caught = not all(ok for _, ok, _ in check(m))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    failed = sum(1 for _, ok, _ in rows if not ok)
    ok = failed == 0 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": len(rows), "failed": failed, "mutations": muts, "status": status,
                               "rows": [{"check": n, "ok": o, "detail": d} for n, o, d in rows],
                               "contract": __doc__.split("Static")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {len(rows)}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
