"""H-1 가방 창 (게임성 개발 4, 2026-10-12; SPEC A23-32 / A23-19 / A23-99 / A23-130 / A23-98 / A23-127 / A23-133, design
docs/design/beta_basics_2026-10-05.md BB7 'user decision 2026-10-06'), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and BagUI.luau in tools/fixtures/bag_ui_offline.luau (Players /
Instance tree / Panels / UIKit / Settings / QuickSlots doubles). Checks: the window "Bag" is registered (fixed body,
redraws itself, its own narrow / wide width <= 780 du, an L10n text table); the model - owned weapons with their own
+N and the equipped one, potions with stock, known items only, the tab of each kind, the BB6 grades, spares
('tier:plus', A23-127), new = gained after the first data and not looked at; the four sorts (Newest = the server's order
numbers, Name, Grade, Type) are the Settings.BagSort options and BagWide is a saved Bool; columns 4 / 8 (>= 3 when the
window is squeezed); the potion button (cooldown, full, the KO1 sip, none left, busy); the scroll steps (enhance:
+Max can't be picked; transfer: source +1 or more, receiver below +Max, tap the source again to drop it; a step drops
back when its weapon / scroll is gone); the detail column (Equipped / Equip / From Lv N / In a fight / Checking…, the
power change, a potion's Drink + quick slots, a scroll's Use, a material's price + seen monsters that drop it, the
confirm with before → after + chance + the fail result before anything is sent); the Inventory payload filter and the
'new' base; the window itself (four tabs, the worn row with empty armor / ring / pet gear places, grade slots, +N /
count / equipped marks, empty slots filling the rows, tap = pick, Equip -> EquipWeapon once until the answer, Use ->
pick -> Enhance -> UseItem, Cancel, Drink -> UsePotion, quick slot set / clear, the sort cycle, the size toggle, the
gold line, tab counts and dots of new things that clear when the tab is left, the fight tag repainting in place).
Static: ClientMain loads BagUI after Panels; Panels gives a registered window its own width, has the bag icon, stops the
B14 glow when the bag opens and hands out the last scroll result; the HUD Bag tile / I key open "Bag" (Items until
then); the KO1 quick slot row opens the bag on Use. Mutations: each must be caught.

Usage: py tools/test_bag_ui.py
Report: docs/art/verification_2026-10-12/offline_bag_ui_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"BAG": ROOT / "src/StarterPlayer/StarterPlayerScripts/BagUI.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau",
         "HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau",
         "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"}
FIXTURE = ROOT / "tools/fixtures/bag_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_bag_ui_2026-10-12.json"

MUTATIONS = [
    ("BAG", "unowned weapons show", "\t\tif owns(ctx.Mask, tier) or tier == equipped then\n", "\t\tif true then\n"),
    ("BAG", "the equipped flag lost", "\t\t\t\tEquipped = tier == equipped })", "\t\t\t\tEquipped = false })"),
    ("BAG", "empty potions show", "def.Use == \"Potion\" and n >= 1 then", "def.Use == \"Potion\" then"),
    ("BAG", "every item Common", "\treturn L.ItemGrade[id] or \"Common\"\n", "\treturn \"Common\"\n"),
    ("BAG", "spares never parsed", "\t\t\tif tier and Config.Weapons[tier] and n >= 1 then\n", "\t\t\tif false then\n"),
    ("BAG", "everything is new", "cell.New = type(base) == \"number\" and cell.Seq > base and", "cell.New = true or"),
    ("BAG", "Newest = oldest first", "\t\t\tif a.Seq ~= b.Seq then return a.Seq > b.Seq end\n", "\t\t\tif a.Seq ~= b.Seq then return a.Seq < b.Seq end\n"),
    ("BAG", "grade sort ignores the grade", "\t\t\tif a.Rank ~= b.Rank then return a.Rank > b.Rank end\n\t\t\tif kind(a) ~= kind(b)",
     "\t\t\tif kind(a) ~= kind(b)"),
    ("BAG", "wide never wider", "return 2 * L.Pad + gridW(wide and L.Wide or L.Narrow)", "return 2 * L.Pad + gridW(L.Narrow)"),
    ("BAG", "a squeezed window keeps 8 columns", "return math.clamp(math.min(want, fit), 3, want)", "return want"),
    ("BAG", "a full bar may drink", "if num(p.Amount, 0) >= num(p.Max, 1) and p.Sip ~= true then", "if false then"),
    ("BAG", "no cooldown on the potion", "\tif left > 0 then return tx(TXT, \"Wait\", math.ceil(left)), false end\n", ""),
    ("BAG", "a +Max weapon can be enhanced", "\tif def.Kind == \"Enhance\" then return cell.Plus < max end\n",
     "\tif def.Kind == \"Enhance\" then return true end\n"),
    ("BAG", "a +0 source can send", "\tif not mode.From then return cell.Plus > 0 end\n", "\tif not mode.From then return true end\n"),
    ("BAG", "the source can't be dropped", "\tif cell.Tier == mode.From then return { Item = mode.Item } end\n", ""),
    ("BAG", "a +Max step never drops back", "\t\tif mode.Tier and (not w or w.Plus >= max) then return { Item = mode.Item } end\n", ""),
    ("BAG", "the confirm hides the chance", "tx(TXT, \"ConfirmEnh\", w.Name, w.Plus, math.min(max, w.Plus + plus), pct(sdef.Chance))",
     "tx(TXT, \"ConfirmEnh\", w.Name, w.Plus, math.min(max, w.Plus + plus), 0)"),
    ("BAG", "no fail line", "\t\t\t\tline(failLine(w.Plus), \"Sub\")\n", ""),
    ("BAG", "scrolls during a fight", "\t\t\telseif ctx.Combat then\n\t\t\t\tact(go, tx(TXT, \"InFight\"), false, \"Free\")",
     "\t\t\telseif false then\n\t\t\t\tact(go, tx(TXT, \"InFight\"), false, \"Free\")"),
    ("BAG", "equip below MinLevel", "\t\telseif not Config.WeaponUsable(cell.Tier, level) then\n", "\t\telseif false then\n"),
    ("BAG", "a locked weapon shows a power change", "elseif now and with and Config.WeaponUsable(cell.Tier, level) then",
     "elseif now and with then"),
    ("BAG", "weapon swap during a fight", "\t\telseif ctx.Combat then\n\t\t\tact(\"Equip\", tx(TXT, \"InFight\"), false, \"Free\")",
     "\t\telseif false then\n\t\t\tact(\"Equip\", tx(TXT, \"InFight\"), false, \"Free\")"),
    ("BAG", "no power change", "\t\t\tline(tx(TXT, \"Power\", Util.FormatInt(now), Util.FormatInt(with))", "\t\t\tline((\"\")"),
    ("BAG", "no quick slot row", "\t\tview.Quick = cell.Id\n", ""),
    ("BAG", "From names unseen monsters", "if rows and type(seen) == \"table\" and seen[kind] and", "if rows and"),
    ("BAG", "the payload keeps unknown ids", "if type(id) == \"string\" and loot.Items[id] ~= nil and c >= 1 then",
     "if type(id) == \"string\" and c >= 1 then"),
    ("BAG", "every payload resets the base", "\tif S.SeqBase == nil then\n", "\tif true then\n"),
    ("BAG", "two equips at once", "if not kit or (pending and S.Pending) or now < (S.ReadyAt[key] or 0) then return false end",
     "if not kit then return false end"),
    ("BAG", "the weapon change never answers", "\t\t\tdone = math.floor(num(attr(\"WeaponTier\"), 0)) ~= p.WeaponTier\n", ""),
    ("BAG", "Use does not switch to the weapons", "\t\tS.Tab = \"Gear\"\n\t\tBagUI.Redraw()", "\t\tBagUI.Redraw()"),
    ("BAG", "Cancel forgets the scroll", "\t\t\tS.Tab, S.Sel = \"Scroll\", \"I:\" .. item\n", ""),
    ("BAG", "the sort is not saved", "pcall(st.Set, \"BagSort\", L.Sorts[i % #L.Sorts + 1])", "pcall(st.Set, \"BagSort\", \"Default\")"),
    ("BAG", "the size does not relayout", "\t\tkit.Rebuild(true) -- Panels lays the window out again", "\t\t-- Panels lays the window out again"),
    ("BAG", "no empty slots", "\tfor i = #list + 1, total do\n", "\tfor i = 1, 0 do\n"),
    ("BAG", "no worn row", "\tif S.Tab == \"Gear\" then top = drawWorn(area, all, cols) end\n", ""),
    ("BAG", "a count of 1 is written", "\tif cell.Count > 1 then\n", "\tif cell.Count > 0 then\n"),
    ("BAG", "no letter for an icon without art", "\t\telseif type(mark) == \"table\" and type(mark.Text) == \"string\" then\n",
     "\t\telseif false then\n"),
    ("BAG", "leaving a tab never clears its new things", "\t\tmarkSeen(S.Tab)\n\t\tS.Mode, S.Result = nil, nil\n", "\t\tS.Mode, S.Result = nil, nil\n"),
    ("BAG", "the fight tag never repaints", "local parts = { inCombat() and \"c\" or \"\",", "local parts = { \"\","),
    ("BAG", "Drink sends nothing", "if ok and def and send(\"UsePotion\", nil, def.Kind) then", "if false then"),
    ("BAG", "no text table", "L10n.Register(\"BagUI.TXT\", TXT)\n", ""),
    ("BAG", "the size watcher is never dropped", "\tif conn and type(conn.Disconnect) == \"function\" then pcall(conn.Disconnect, conn) end\n", ""),
    ("BAG", "a taller window never redraws", "\t\tif BagUI.LayoutSig() ~= VIEW.LayoutSig then BagUI.Redraw() end\n", ""),
    ("MAIN", "the bag is never loaded", "\"QuestBook\", \"BagUI\",", "\"QuestBook\","),
    ("PANELS", "Panels ignores the bag's width", "\tif type(want) == \"number\" and want == want then winW",
     "\tif false then winW"),
    ("PANELS", "the bag never stops the scroll glow", "if id == \"Items\" or id == \"Bag\" then ITEMS.Seen = true end",
     "if id == \"Items\" then ITEMS.Seen = true end"),
    ("HUD", "the KO1 quick slot row opens the old list", "panels.Open(bag and \"Bag\" or \"Items\", bag and { Tab = \"Use\" } or nil)",
     "panels.Open(\"Items\")"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [
        ("ClientMain loads BagUI after Panels (and QuickSlots / Settings are in the registry)", "BagUI" in names
         and "Panels" in names and names.index("BagUI") > names.index("Panels") and "QuickSlots" in names and "Settings" in names),
        ("Panels: a registered window may ask for its own width (opts.Width)",
         "local want = currentId ~= nil and REG.Opts[currentId] ~= nil and REG.Opts[currentId].Width or nil" in src["PANELS"]
         and "if type(want) == \"number\" and want == want then winW = math.max(280, math.min(want, WINDOW_MAX_W, w - 24)) end" in src["PANELS"]),
        ("Panels: the bag has the bag icon", 'Bag = "IconBag" },' in src["PANELS"]),
        ("Panels: opening the bag stops the B14 scroll glow", 'if id == "Items" or id == "Bag" then ITEMS.Seen = true end' in src["PANELS"]),
        ("Panels: LastEnhance hands out the last scroll result", "function Panels.LastEnhance()" in src["PANELS"]
         and "return table.clone(ITEMS.Result), ITEMS.ResultAt" in src["PANELS"]),
        ("the HUD Bag tile opens \"Bag\" (Items until it is registered)",
         '{ Id = "Bag", Icon = "IconBag", Window = "Bag", Alt = "Items", Key = "Bag", Keep = 1 },' in src["HUD"]),
        ("the I key opens \"Bag\"", '{ Id = "Bag", Group = "Window", Key = "I",' in src["CONFIG"] and 'Window = "Bag", Alt = "Items" },' in src["CONFIG"]),
        ("the KO1 quick slot row opens the bag on Use",
         'panels.Open(bag and "Bag" or "Items", bag and { Tab = "Use" } or nil)' in src["HUD"]),
        ("the approved slot / glyph art exists (bundle 7)", all(f"\t\t{k} = {{ Id = \"rbxassetid://" in src["CONFIG"] for k in
            ("SlotCommon", "SlotUncommon", "SlotRare", "SlotEpic", "SlotLegendary", "SlotEmpty", "GlyphSort", "GlyphShrink", "GlyphExpand"))),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal BAG_SOURCE = " + lua_str(src["BAG"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "bag_ui.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"BAG_UI_SUMMARY checks=(\d+) failed=(\d+)", out)
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
