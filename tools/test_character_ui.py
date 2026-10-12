"""BB8 Hero window "Character" (CharacterUI, 게임성 개발 1, 2026-10-12; design docs/design/beta_basics_2026-10-05.md BB8, SPEC
A23-48 English only / A23-78 E key / A23-99 / A23-111 text tables / A23-130 / A23-133 gear row), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and CharacterUI.luau in tools/fixtures/character_ui_offline.luau
(Players / Instance tree / Panels / UIKit doubles, a fake GearSlots and PetWindow). Checks: the window registers as "Character"
(fixed body, redraws itself, an L10n text table); the pure model - Weapons() lists the owned tiers + the worn one, worn first
then by Damage; EquipState words and enabled flags (Equipped / From Lv N / Checking… / In a fight / Equip); Titles() = Auto +
the owned titles in Config.TitleOrder, exactly one current, an unowned selection falls back to Auto; PetState() nil without
pets; NextRank() names / points, nil at the top; StatRows(); Equip(tier) fires EquipWeapon once (a second press inside the
rate gap and a second request while one waits send nothing); SetTitle(id) fires SetTitle ("" = Auto). The GEAR CELL RULE:
with a GearSlots (a table with Build) CharacterUI draws NO cell of its own - GearSlots.Build(EquipSlotsFrame, { Refresh })
runs once across opens, GearSlots.Refresh() on every open, opts.Refresh lays the window out around the frame's new size
(the title list moves beside it), a failing Build = the fallback; WITHOUT GearSlots the fallback draws the Weapon cell (opens
the owned list with [Equip]), the Pet cell (only with pets) and four SlotEmpty cells. Every text the window shows is a TXT
line, a Config name or a number (runtime scan) and no text is a literal in a Text = / label / Button call (static scan).
Static: ClientMain loads CharacterUI right after BagUI; Panels' title icon; the HUD Hero tile / E key. Mutations: each must be
caught.

Usage: py tools/test_character_ui.py
Report: docs/art/verification_2026-10-12/offline_character_ui_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = "src/StarterPlayer/StarterPlayerScripts/"
FILES = {"UI": ROOT / (SPS + "CharacterUI.luau"),
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / (SPS + "ClientMain.client.luau"),
         "HUD": ROOT / (SPS + "HUD.luau"),
         "PANELS": ROOT / (SPS + "Panels.luau"),
         "SETTINGS": ROOT / (SPS + "SettingsUI.luau")}
FIXTURE = ROOT / "tools/fixtures/character_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_character_ui_2026-10-12.json"

# the only literals a Text = / label(...) / corner(...) / Button(...) call may take besides TXT words (explicit list)
ALLOWED_LITERALS = {'corner(box, "+" ..'}  # the "+N" mark of a weapon cell is a number with a plus, not a word

MUTATIONS = [
    ("UI", "registers under another id", "Window = \"Character\", Width = 600,", "Window = \"Hero\", Width = 600,"),
    ("UI", "no text table", "L10n.Register(\"CharacterUI.TXT\", TXT)\n", ""),
    ("UI", "Open ignores the tab", "type(tab) == \"string\" and { Tab = tab } or nil", "nil"),
    ("UI", "unowned weapons show", "\t\tif owns(ctx.Mask, tier) or tier == equipped then\n", "\t\tif true then\n"),
    ("UI", "the worn weapon only when owned", "\t\tif owns(ctx.Mask, tier) or tier == equipped then\n", "\t\tif owns(ctx.Mask, tier) then\n"),
    ("UI", "weapons sorted by tier number", "\t\tif da ~= db then return da > db end\n", "\t\tif false then return da > db end\n"),
    ("UI", "the worn weapon not first", "\t\tif a.Equipped ~= b.Equipped then return a.Equipped end\n", ""),
    ("UI", "the worn weapon can be equipped", "\tif row.Equipped then return tx(TXT, \"Equipped\"), false end\n",
     "\tif row.Equipped then return tx(TXT, \"Equipped\"), true end\n"),
    ("UI", "a locked weapon says Equip", "\tif not row.Usable then return tx(TXT, \"FromLv\", row.MinLevel), false end\n", ""),
    ("UI", "a waiting request is not shown", "\tif ctx.Pending and ctx.Pending.Tier == row.Tier then return tx(TXT, \"Checking\"), false end\n", ""),
    ("UI", "no fight tag", "\tif ctx.Combat then return tx(TXT, \"InFight\"), false end\n", ""),
    ("UI", "two requests may wait", "\treturn tx(TXT, \"Equip\"), ctx.Pending == nil\n", "\treturn tx(TXT, \"Equip\"), true\n"),
    ("UI", "unowned titles listed", "if owned[id] and def then\n", "if def then\n"),
    ("UI", "an unowned selection stays", "\tif sel ~= \"\" and not (owned[sel] and Config.TitleDefs[sel]) then sel = \"\" end\n", ""),
    ("UI", "Auto is never current", "Name = tx(TXT, \"TitleAuto\"), Current = sel == \"\" }", "Name = tx(TXT, \"TitleAuto\"), Current = false }"),
    ("UI", "a pet cell without pets", "or #rows == 0 then return nil end", "then return nil end"),
    ("UI", "the next rank is the same one", "\t\tif points < t and names[i] then return names[i], t - points end\n",
     "\t\tif points <= t and names[i] then return names[i], t - points end\n"),
    ("UI", "no top rank line", "nextName and tx(TXT, \"NextValue\", nextName, toGo) or tx(TXT, \"TopRank\")",
     "tx(TXT, \"NextValue\", nextName or \"\", toGo or 0)"),
    ("UI", "rebirth rows without data", "if rebirths >= L.ShowRebirthMin or bonus > 0 or fall > 0 or redeem > 0 then", "if true then"),
    ("UI", "two equips at once", "if not kit or (pending and S.Pending) or now < (S.ReadyAt[key] or 0) then return false end",
     "if not kit then return false end"),
    ("UI", "the rate gap ignored", "or now < (S.ReadyAt[key] or 0) then return false end", "then return false end"),
    ("UI", "a request waits for nothing", "if not kit or (pending and S.Pending) or", "if not kit or"),
    ("UI", "equip below the level", "if not row or row.Equipped or not row.Usable or inCombat() then return false end",
     "if not row or row.Equipped or inCombat() then return false end"),
    ("UI", "equip in a fight", "if not row or row.Equipped or not row.Usable or inCombat() then return false end",
     "if not row or row.Equipped or not row.Usable then return false end"),
    ("UI", "the answered weapon never ends the wait", "\t\tif math.floor(num(attr(\"WeaponTier\"), 0)) ~= p.WeaponTier then\n",
     "\t\tif false then\n"),
    ("UI", "the shown title is sent again", "\t\t\tif t.Current then return false end\n", ""),
    ("UI", "SetTitle sends the name", "return send(\"SetTitle\", nil, id)", "return send(\"SetTitle\", nil, t.Name)"),
    ("UI", "a watched attribute does not redraw", "if CharacterUI.Watch[name] then\n", "if false then\n"),
    ("UI", "the Stats page never shows", "\tif VIEW.StatsPage then VIEW.StatsPage.Visible = id == \"Stats\" end\n", ""),
    ("UI", "an equip button never switches off", "kit.SetEnabled(b, enabled)\n", ""),
    ("UI", "the weapon cell opens nothing", "slot(frame, worn.Grade, function() CharacterUI.ShowView(S.View == \"Weapons\" and \"Slots\" or \"Weapons\") end,",
     "slot(frame, worn.Grade, function() CharacterUI.ShowView(\"Slots\") end,"),
    ("UI", "no empty cells in the fallback", "\tfor _, id in L.Fallback do\n", "\tfor _, id in {} do\n"),
    ("UI", "a Pet cell always", "\tlocal pet = data.Pet\n\tif pet then\n\t\tlocal row = pet.Equipped\n",
     "\tlocal pet = data.Pet or { Equipped = nil }\n\tif pet then\n\t\tlocal row = pet.Equipped\n"),
    ("UI", "its own cells beside GearSlots", "\tif not (gearModule() or S.GearBuilt) then -- the fallback cells (GearSlots draws its own)\n",
     "\tif true then -- the fallback cells (GearSlots draws its own)\n"),
    ("UI", "Build on every open", "\tif not S.GearBuilt then\n\t\tS.GearBuilt = true\n", "\tif true then\n\t\tS.GearBuilt = true\n"),
    ("UI", "GearSlots.Refresh never called", "\tif afterDraw and type(g.Refresh) == \"function\" then\n", "\tif false then\n"),
    ("UI", "a new frame every open", "\tlocal f = S.Equip\n\tif f ~= nil and not pcall", "\tlocal f = nil\n\tif f ~= nil and not pcall"),
    ("UI", "the frame stays in the closed window", "\tif f then pcall(function() f.Parent = nil end) end -- Panels clears", "\tif false then end -- Panels clears"),
    ("UI", "opts.Refresh does nothing", "{ Refresh = function() CharacterUI.Relayout() end }", "{ Refresh = function() end }"),
    ("UI", "the layout ignores the frame's size", "\ttitles.Position = UDim2.fromOffset(w + L.TitleGap, 0)\n",
     "\ttitles.Position = UDim2.fromOffset(L.FrameW + L.TitleGap, 0)\n"),
    ("UI", "an empty size is taken as it is", "\tif w <= 0 or h <= 0 then return L.FrameW, L.FrameH end\n", ""),
    ("UI", "the open window never lays out", "\tCharacterUI.Relayout() -- the frame may be another size than the default (GearSlots resized it)\n", ""),
    ("UI", "a failed Build is kept", "S.GearBuilt, S.GearOff = false, true", "S.GearBuilt = true"),
    ("UI", "a failed Build leaves its cells", "\t\t\tpcall(function()\n\t\t\t\tfor _, ch in frame:GetChildren() do ch:Destroy() end\n\t\t\tend)\n", ""),
    ("UI", "a failed Build is not reported", "\t\t\tUtil.Warn(TAG, \"GearSlots.Build failed: \" .. tostring(err))\n", ""),
    ("UI", "a Back word written in code", "kit.Button(header, tx(TXT, \"Back\"),", "kit.Button(header, \"Back\","),
    ("MAIN", "CharacterUI is never loaded", "\"BagUI\", \"CharacterUI\", \"GatherView\",", "\"BagUI\", \"GatherView\","),
    ("MAIN", "CharacterUI before BagUI", "\"BagUI\", \"CharacterUI\", \"GatherView\",", "\"CharacterUI\", \"BagUI\", \"GatherView\","),
    # 최종 검수 10/13 (ref_rpg_ui #1 / #2)
    ("UI", "#1: no power parts", "\tfor i, part in { { \"Attack\", \"IconSword\", ctx.Attack }, { \"Health\", \"IconHeart\", ctx.Health } } do\n",
     "\tfor i, part in {} do\n"),
    ("UI", "#1: the chips never open their sources", "\t\t\t\tS.Why = S.Why ~= id and id or nil\n", ""),
    ("UI", "#1: the weapon left out of Attack's sources",
     "\t\t\ttable.insert(lines, tx(TXT.Why, \"Weapon\", Config.WeaponName(tier, ctx.Class, ctx.Faction), math.floor(num(ctx.Plus, 0))))\n", ""),
    ("UI", "#2: the old 'A -> B' line", "\t\t\t\tline, color = CharacterUI.DiffLine(r.PowerNow, r.PowerWith)\n",
     "\t\t\t\tline = tx(TXT, \"PowerChange\", Util.FormatInt(r.PowerNow), Util.FormatInt(r.PowerWith))\n"),
    ("UI", "#2: a drop shown grey", "\tif tone == \"Bad\" then return string.format(t.Down, Util.FormatInt(d)), \"Bad\" end\n",
     "\tif tone == \"Bad\" then return string.format(t.Down, Util.FormatInt(d)), \"Same\" end\n"),
    ("CONFIG", "#1: Attack without the +N", "return math.floor(Config.WeaponDamage(tier, level, enhance) * atkMult + 0.5)",
     "return math.floor(Config.WeaponDamage(tier, level, 0) * atkMult + 0.5)"),
    ("PANELS", "the window has no title icon", "\t\t\tCharacter = \"IconCharacter\" },", "\t\t\t},"),
    # 게임성 검수 10/12 (API review fixes)
    ("UI", "the other side's blessing shown as mine", "if (blessing == \"Halo\" or blessing == \"Horns\") and blessing == faction then",
     "if (blessing == \"Halo\" or blessing == \"Horns\") then"),
    ("UI", "the blessing without its XP", "Blessing = \"Gold & XP +%d%%\" },", "Blessing = \"Gold +%d%%\" },"),
    # 최종 검수 10/13 (ref_rpg_ui #5)
    ("UI", "#5: the Horns' gold bonus left out", "\t\tif num(fdef.GoldBonus, 0) > 0 then chip(\"Gold\", tx(TXT.Chip, \"Gold\", pct(fdef.GoldBonus))) end\n", ""),
    ("UI", "#5: the perk sentences back", "\tif #effects > 0 then\n\t\thead(\"Effects\")",
     "\tfor _, t in type(fdef) == \"table\" and fdef.Perks or {} do table.insert(rows, { Kind = \"Line\", Text = t }) end\n\tif #effects > 0 then\n\t\thead(\"Effects\")"),
    ("UI", "#5: cards without icons", "then card(\"MaxHP\", \"IconHeart\",", "then card(\"MaxHP\", nil,"),
    # 최종 검수 10/13 (ref_rpg_ui #9)
    ("UI", "#9: no ribbon", "\tif shown then\n\t\tlocal ribbon", "\tif false then\n\t\tlocal ribbon"),
    ("UI", "#9: the bar never fills", "Size = UDim2.fromScale(math.max(0.04, rb.Fill), 1)", "Size = UDim2.fromScale(1, 1)"),
    ("UI", "#9: points to go off by the rank's floor", "local fill = hi and math.clamp((points - lo) / math.max(1, hi - lo), 0, 1) or 1",
     "local fill = hi and math.clamp(points / math.max(1, hi), 0, 1) or 1"),
    ("UI", "#9: locked titles left out", "\tfor _, t in CharacterUI.LockedTitles(attr(\"TitlesOwned\", \"\")) do\n", "\tfor _, t in {} do\n"),
    ("UI", "#9: a locked title pressable", "\t\tb.Name = \"Locked_\" .. t.Id\n\t\tb.LayoutOrder = order\n\t\tkit.SetEnabled(b, false)\n",
     "\t\tb.Name = \"Locked_\" .. t.Id\n\t\tb.LayoutOrder = order\n"),
    ("UI", "#5: cards drawn as text rows", "\t\tif r.Kind == \"Card\" then\n", "\t\tif false then\n"),
    ("UI", "the hit row claims the final damage", "Hit = \"Base hit\",", "Hit = \"Hit damage\","),
    ("UI", "no nickname row", "Name = \"Nickname\", Size = UDim2.new(1, 0, 0, L.Size.Name + 4),",
     "Name = \"Nick_\", Size = UDim2.new(1, 0, 0, L.Size.Name + 4),"),
    ("UI", "[Change] opens another window", "pcall(pk.Open, \"Nickname\")", "pcall(pk.Open, \"Settings\")"),
    ("UI", "equip while dead", "if ctx.Dead or ctx.NoClass or (row.NeedSide and ctx.Faction == \"None\") then",
     "if ctx.NoClass or (row.NeedSide and ctx.Faction == \"None\") then"),
    ("UI", "equip before a class", "if ctx.Dead or ctx.NoClass or (row.NeedSide and ctx.Faction == \"None\") then",
     "if ctx.Dead or (row.NeedSide and ctx.Faction == \"None\") then"),
    ("UI", "a side weapon without a side", "if ctx.Dead or ctx.NoClass or (row.NeedSide and ctx.Faction == \"None\") then",
     "if ctx.Dead or ctx.NoClass then"),
    ("UI", "the power from the old formula (not CombatPowerOf)", "if power == nil then power = okP and tonumber(now) or 0 end",
     "if power == nil then power = Config.CombatPower(level, tier, plus) end"),
    ("SETTINGS", "Lv 1 cannot change the name (the row gone once the window exists)",
     'return not hasCharacter or not Config.HudReveal.TileShows("Character", { Level = level })', "return not hasCharacter"),
    ("SETTINGS", "the row never comes back / leaves on a level up", "Rebuild = { VacationDays = true, DataLoaded = true, Level = true },",
     "Rebuild = { VacationDays = true, DataLoaded = true },"),
    ("HUD", "the face opens the window below Lv 2 (the tile's lock skipped)", "\tif L.TileLocked(\"Character\") then\n\t\tL.TileWiggle(\"Character\")",
     "\tif false then\n\t\tL.TileWiggle(\"Character\")"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def strip_comments(text: str) -> str:
    return "\n".join(re.sub(r"\s--.*$", "", l) if not l.strip().startswith("--") else "" for l in text.splitlines())


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = strip_comments(src["UI"])
    # every text goes through TXT: no literal as the text of Text = / label / corner / Button
    literals = re.findall(r'\bText\s*=\s*"[^"]*"', code)
    literals += re.findall(r'\blabel\(\s*[\w\.]+\s*,\s*"[^"]*"', code)
    literals += re.findall(r'\bButton\(\s*[\w\.]+\s*,\s*"[^"]*"', code)
    literals += [m for m in re.findall(r'\bcorner\(\s*\w+\s*,\s*"[^"]*" \.\.', code) if m not in ALLOWED_LITERALS and
                 re.sub(r"\s+", " ", m) not in ALLOWED_LITERALS]
    sends = sorted(set(re.findall(r'\bsend\("(\w+)"', code)))
    header = src["UI"].split("local Players", 1)[0]
    return [
        ("ClientMain loads CharacterUI right after BagUI (and after Panels / UIKit)", "CharacterUI" in names and "BagUI" in names
         and names.count("CharacterUI") == 1 and names.index("CharacterUI") == names.index("BagUI") + 1
         and names.index("CharacterUI") > names.index("Panels") and names.index("CharacterUI") > names.index("UIKit")),
        ("no player text written in code: " + (", ".join(literals) if literals else "none"), not literals),
        ("the window sends EquipWeapon and SetTitle only (the server checks both)", sends == ["EquipWeapon", "SetTitle"]),
        ("no 'local x <const>' (Luau rule)", re.search(r"local\s+\w+\s*<const>", code) is None),
        ("the header states the GearSlots rule (all six cells, none of its own, Build once, Refresh each open, opts.Refresh)",
         "ALL SIX cells" in header and "NO cell of its own" in header and "Build(frame, { Refresh = fn }) once" in header
         and "Refresh() on every open" in header and "opts.Refresh" in header and "WITHOUT GearSlots" in header),
        ("Panels: the Character window has the hero icon, and the art exists",
         'Character = "IconCharacter"' in src["PANELS"] and 'IconCharacter = { Id = "rbxassetid://' in src["CONFIG"]),
        ("the HUD Hero tile opens \"Character\" (locked below Lv 2 by Config.HudReveal)",
         '{ Id = "Character", Icon = "IconCharacter", Window = "Character", Key = "Character", Keep = 2 },' in src["HUD"]
         and 'Config.HudReveal.Tiles = { Character = "LevelUp",' in src["CONFIG"]),
        ("게임성 검수 10/12: the HUD face / power line obeys the Hero tile's lock (a wiggle below Lv 2, no window)",
         "function L.PowerOpen()\n\t-- 게임성 검수 10/12" in src["HUD"]
         and "\tif L.TileLocked(\"Character\") then\n\t\tL.TileWiggle(\"Character\")\n\t\treturn\n\tend" in src["HUD"]),
        ("게임성 검수 10/12: the power goes through Config.CombatPowerOf only (tools/test_stats)", "Config.CombatPower(" not in code),
        # 최종 검수 10/13 (API review): below Lv 2 the Hero window is locked everywhere, so Settings keeps the Nickname row
        ("최종 검수 10/13: Settings keeps its Nickname row while the Hero window is locked (Lv 1; the HUD's TileShows rule) "
         "and redraws on a level up", 'return not hasCharacter or not Config.HudReveal.TileShows("Character", { Level = level })'
         in src["SETTINGS"] and 'if SettingsUI.NicknameRow(panelsHas("Character"), kit.Num("Level")) then' in src["SETTINGS"]
         and "Rebuild = { VacationDays = true, DataLoaded = true, Level = true }," in src["SETTINGS"]
         and 'Config.HudReveal.Tiles = { Character = "LevelUp",' in src["CONFIG"]),
        ("the E key opens \"Character\" (Soon: live once the window is registered)",
         '{ Id = "Character", Group = "Window", Key = "E",' in src["CONFIG"] and 'Window = "Character", Soon = true }' in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal UI_SOURCE = " + lua_str(src["UI"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "character_ui.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"CHARACTER_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
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
