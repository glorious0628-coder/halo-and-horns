"""③-3 제작 창 (게임성 개발 4, 2026-10-12; SPEC A23-127 / A23-56 / A23-130 / A23-111, contract
docs/design/craft_server_2026-10-12.md §4: CraftStart(recipeId), CraftInfo { Role, Lv, XP, Need, Made, On? }), offline.

Runs the CURRENT Config.luau and CraftWindow.luau in the official Luau CLI (tools/fixtures/craft_window_offline.luau;
the CraftInfo remote, Panels, UIKit, CraftView.IsOpen, CollectionService benches and the Crossroads anvil are doubles).
Checks: the Panels window "Craft" (title, width, L10n table, CraftInfo bound at Init); the menu entry only for an artisan
(faction Neutral, class chosen) while Config.Features.Crafting is on; my role's recipes only (Warrior Smith, Mage Alch,
Archer Tame), lowest level first, a recipe with a material not in the game / Gear (no names yet) hidden, the server's
On list; materials in the loot order with have / need; gold; the craft level lock (CraftInfo of my role only); the
refusal reasons in the server's order (NotArtisan, Auto, Far, NeedLevel, NeedMats, NeedGold) with the server's own
notice texts; the header (Blacksmith Lv N, XP / next, Max); the detail (attack, use-from level, craft XP, made, Forge /
Brew / Make, Checking… while a start waits, off inside the start interval); the window (rows, the gold rim, the ready
check, a locked row's red level, the gold line, a tap picks); Forge = CraftStart(recipeId) once; the ring opening and
closing brings the window back on the same recipe (not over another window); no answer in 3 s = back after the
interval; the bench distance (my role's nearest CraftStation, else the anvil, nothing in sight = not far); auto combat;
the Inventory push / gold / CraftInfo redraw in place; the open arg once; a non-artisan sees the server's line.
Static: ClientMain loads CraftWindow after Panels; it sends CraftStart only; no fixed key; Panels' menu takes opts.Menu
and the window's icon is the approved IconHammer. Mutations: each must be caught.

Usage: py tools/test_craft_window.py
Report: docs/art/verification_2026-10-12/offline_craft_window_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"WIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/CraftWindow.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/craft_window_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_craft_window_2026-10-12.json"

MUTATIONS = [
    ("WIN", "another role's recipes show", "r.Role == role and onList(info, id)", "onList(info, id)"),
    ("WIN", "a recipe with a material not in the game shows",
     "\tfor item in r.Mats do\n\t\tif not Config.Loot.Items[item] then return nil end\n\tend\n\tlocal e =", "\tlocal e ="),
    ("WIN", "Gear without names shows", "\telse\n\t\treturn nil\n\tend\n\tlocal items =", "\tend\n\tlocal items ="),
    ("WIN", "short materials not marked", "Short = have < need,", "Short = false,"),
    ("WIN", "the gold ignored", "e.GoldShort = math.max(0, math.floor(num(ctx.Gold, 0))) < e.Gold", "e.GoldShort = false"),
    ("WIN", "the level lock ignored", "e.Locked = lv < e.Lv", "e.Locked = false"),
    ("WIN", "the server's On list ignored", "\tif type(on) ~= \"table\" then return true end", "\tdo return true end"),
    ("WIN", "another role's CraftInfo counts", "\tif info.Role ~= role then return 1, 0, Config.CraftXPToNext(1) end\n", ""),
    ("WIN", "auto combat is no reason", "Auto = ctx.Auto == true,", "Auto = false,"),
    ("WIN", "reasons out of the server's order", "\"NotArtisan\", \"Auto\", \"Far\", \"NeedLevel\", \"NeedResearch\", \"NeedMats\", \"NeedGold\"",
     "\"NotArtisan\", \"NeedGold\", \"NeedMats\", \"NeedResearch\", \"NeedLevel\", \"Far\", \"Auto\""),
    ("WIN", "research is no reason", "NeedResearch = type(e) == \"table\" and e.ResearchShort == true,", "NeedResearch = false,"),
    ("WIN", "a summon ready without its research", "and not e.GoldShort and not e.ResearchShort", "and not e.GoldShort"),
    ("WIN", "summons while research is off", "if not (CraftWindow.ResearchOn() and type(sp) == \"table\"", "if not (type(sp) == \"table\""),
    ("WIN", "the research tab for every artisan", "local tabs = CraftWindow.RoleOf(ctx) == \"Tame\" and CraftWindow.ResearchOn()",
     "local tabs = CraftWindow.ResearchOn()"),
    ("WIN", "TamerInfo never redraws", "\tS.TamerVer += 1\n\tif VIEW.Kit then CraftWindow.Redraw() end\n", "\tS.TamerVer += 1\n"),
    ("WIN", "a stage counted below its points", "if have >= num(need, math.huge) then stage = i else break end",
     "if have + 1 >= num(need, math.huge) then stage = i else break end"),
    ("WIN", "unnamed families listed", "\t\tif names[f] ~= nil then table.insert(order, f) end\n", "\t\ttable.insert(order, f)\n"),
    ("WIN", "TamerInfo is never bound", "\thook(\"TamerInfo\", CraftWindow.OnTamer)", "\t--"),
    ("WIN", "Forge while a start waits", "if not kit or S.Await or now < S.ReadyAt then return false end",
     "if not kit then return false end"),
    ("WIN", "Forge with a reason against it", "if not e or CraftWindow.Reason(e, ctx) then return false end",
     "if not e then return false end"),
    ("WIN", "no interval after a start", "S.ReadyAt = now + math.max(0, num(Config.RateLimits.CraftStart, 3)) + L.GapMargin",
     "S.ReadyAt = now"),
    ("WIN", "the window never comes back after the ring",
     "\t\tif okOpen and not busy and Util.IsAlive(LocalPlayer) then pcall(panels.Open, L.Window, { Select = a.Id }) end\n", ""),
    ("WIN", "it pushes in over another window", "if okOpen and not busy and", "if okOpen and"),
    ("WIN", "a refusal waits forever", "\t\telseif os.clock() - a.At >= L.PendingTimeout then\n", "\t\telseif false then\n"),
    ("WIN", "the bench's role ignored", "p:GetAttribute(\"Role\") == role", "true"),
    ("WIN", "no anvil fallback", "if anvil and anvil:IsA(\"BasePart\") then best =", "if false then best ="),
    ("WIN", "far with nothing in sight", "return best ~= nil and best > Config.Craft.Range", "return best == nil or best > Config.Craft.Range"),
    ("WIN", "the open arg applied on every rebuild", "\tif arg == S.LastArg then arg = nil else S.LastArg = arg end\n", ""),
    ("WIN", "the update never redraws", "\t\tif sigOf(ctx, CraftWindow.Entries(ctx)) ~= VIEW.Sig then CraftWindow.Redraw() end\n", ""),
    ("WIN", "new materials not in the redraw signature", "\t\tfor _, m in e.Mats do table.insert(parts, m.Have) end\n", ""),
    ("WIN", "the menu for everyone", "\treturn CraftWindow.RoleOf({ Faction = attr(\"Faction\"), ClassChosen = attr(\"ClassChosen\") == true, Class = attr(\"Class\") }) ~= nil",
     "\treturn true"),
    ("WIN", "the menu while crafting is off",
     "\tif not (type(Config.Features) == \"table\" and Config.Features.Crafting == true) then return false end\n", ""),
    ("WIN", "CraftInfo bound only later", "\thook(\"CraftInfo\", CraftWindow.OnInfo) -- before any Start", "\t-- before any Start"),
    ("WIN", "a CraftInfo without a role taken", "if type(payload) ~= \"table\" or type(payload.Role) ~= \"string\" then return end",
     "if type(payload) ~= \"table\" then return end"),
    ("WIN", "Checking… never shows", "\tif ctx.Pending then\n\t\tview.Action = { Text = tx(TXT, \"Checking\"), Enabled = false }\n\telse",
     "\tif false then\n\telse"),
    ("WIN", "an empty window keeps its empty columns", "\tif #list == 0 then\n", "\tif false then\n"),
    ("WIN", "the counts under the detail's scroll bar",
     "\tdetail.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- the counts never sit under the bar (UiSandbox 10/12)\n", ""),
    ("WIN", "tight captions keep the styled text floor", "\t\tl.TextScaled = true\n\t\tlocal tc", "\t\tlocal tc"),
    ("WIN", "the workbench prompt for every player", "local show = mine ~= nil and mine == part:GetAttribute(\"Role\")",
     "local show = true"),
    ("WIN", "the prompt's words never written",
     "\tif action ~= \"\" and prompt.ActionText ~= action then prompt.ActionText = action end\n", ""),
    ("WIN", "an unknown key shown as itself", "if not ok or type(out) ~= \"string\" or out == key then return \"\" end",
     "if not ok or type(out) ~= \"string\" then return \"\" end"),
    ("WIN", "a prompt added after the tag gets no words", "\t\tif child.Name == L.Prompt then pcall(applyStation, part) end\n", ""),
    ("WIN", "the prompts ignore a faction / class change",
     "\t\tLocalPlayer:GetAttributeChangedSignal(name):Connect(CraftWindow.RefreshStations)\n", ""),
    ("WIN", "the prompts ignore the language", "\t\tui.LangChanged:Connect(CraftWindow.RefreshStations)\n", ""),
    ("WIN", "a bench tagged later is never watched", "\t\tCollectionService:GetInstanceAddedSignal(tag):Connect(watchStation)\n", ""),
    ("PANELS", "the menu ignores opts.Menu", "\tfor i, e in extra do table.insert(entries, 2 + i, e) end\n", ""),
    ("MAIN", "the window is never loaded", "\"CraftView\", \"CraftWindow\",", "\"CraftView\","),
    # artisan contract ③ (game dev 1, 10/14): a made weapon -> [Use it] (UnpackSpare) -> worn (EquipWeapon)
    ("WIN", "③ a spare of another tier counts", "if tonumber(t) == e.Tier and have > 0 then", "if have > 0 then"),
    ("WIN", "③ the lowest +N picked", "if tonumber(p) > bestPlus then", "if bestPlus < 0 or tonumber(p) < bestPlus then"),
    ("WIN", "③ a button for a tier I own", "Use = not owned and ctx.Unpacking", "Use = ctx.Unpacking"),
    ("WIN", "③ a button without UnpackSpare on the server", "or ctx.UnpackOn ~= true or", "or"),
    ("WIN", "③ the power ignores the spare's +N", "pcall(ctx.Power, e.Tier, plus)", "pcall(ctx.Power, e.Tier, 0)"),
    ("WIN", "③ the power line uncoloured", "tone == \"Good\" and \"Good\" or (tone == \"Bad\" and \"Bad\" or \"Sub\")", "\"Sub\""),
    ("WIN", "③ the power line at a level that can't use it", "\t\telse -- contract ③: my power now", "\t\tend\n\t\tdo -- contract ③: my power now"),
    ("WIN", "③ the made weapon never worn", "if u.Equip and kit then kit.Fire(\"EquipWeapon\", u.Tier) end", "if false then end"),
    ("WIN", "③ worn at any level", "Equip = Config.WeaponUsable(e.Tier, math.max(1, math.floor(num(ctx.Level, 1)))) }", "Equip = true }"),
    ("WIN", "③ waits forever", "elseif os.clock() - u.At >= L.UnpackTimeout then", "elseif false then"),
    ("WIN", "③ the button on while one waits", "and ctx.Unpacking ~= true and ctx.Pending", "and ctx.Pending"),
    ("WIN", "③ the watch never runs", "\t\t\tlocal okU, errU = pcall(CraftWindow.WatchUnpack)\n", "\t\t\tlocal okU, errU = true, nil\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = "\n".join(l for l in src["WIN"].splitlines() if not l.strip().startswith("--"))
    fires = re.findall(r"kit\.Fire\(\"(\w+)\"", code)
    return [
        ("ClientMain loads CraftWindow after Panels / UIKit / CraftView", "CraftWindow" in names
         and all(n in names and names.index("CraftWindow") > names.index(n) for n in ("Panels", "UIKit", "CraftView"))),
        ("the window sends CraftStart, and UnpackSpare + EquipWeapon for a made weapon (contract ③) only",
         sorted(fires) == ["CraftStart", "EquipWeapon", "UnpackSpare"]),
        ("no fixed key in CraftWindow (BB1)", "Enum.KeyCode" not in code),
        ("③ the 0.25 s loop watches the [Use it] answer", "pcall(CraftWindow.WatchUnpack)" in code),
        ("the refusal lines are the server's own notice texts (Config.Craft.Text), no copies",
         "tx(Config.Craft.Text, why)" in code and "Not enough" not in code and "workbench" not in code),
        ("Panels' menu takes a registered window's opts.Menu", "type(o.Menu) == \"function\"" in src["PANELS"]
         and "table.insert(entries, 2 + i, e)" in src["PANELS"]),
        ("the window's icon is the approved IconHammer", "Craft = \"IconHammer\"" in src["PANELS"]
         and "IconHammer = { Id = \"rbxassetid://" in src["CONFIG"]),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal WINDOW_SOURCE = " + lua_str(src["WIN"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "craft_window.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"CRAFT_WINDOW_SUMMARY checks=(\d+) failed=(\d+)", out)
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
