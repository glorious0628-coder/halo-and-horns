"""First-weapon screen check (A23-127, plan docs/design/gameplay_plan_2026-10-13.md §1-A #2, 게임성 개발 1's part).

The server switch is 게임성 개발 2's Config.WeaponShop.Buy = false (the Forge sells no weapon; the first Slime Prince drops
tier 2, the first King Slime tier 3). The screen's part, checked here:
  - Config.WeaponSource / WeaponInfo: where a weapon comes from follows Buy (fixture tools/fixtures/first_weapon_client_offline.luau)
  - the drop goal's words (Tutorial.Text.NextIronDrop, ShortNames.IronDrop)
  - static: Panels' Forge window hides [Buy] for a weapon I do not own while the Forge sells none (WSHOP.Sells), shows
    "Get it: <source>", keeps [Equip] / [Sell] for owned ones, guards send(); HUD keeps the server's GoalKind and asks
    QuestTarget.IronGold (its behaviour is tools/test_quest_target.py); M1_1's scroll step (Guide "Bag", 게임성 개발 2)
    opens the bag on the scroll and makes the Bag tile glow.
  - static (A23-156, same branch): ClientMain applies 게임성 개발 2's test-server switch (Config.ApplyTestServer) before any
    module is required.
Mutations: in-memory copies of Config with one rule broken each; each must make a fixture check fail.
Report: docs/art/verification_2026-10-13/offline_first_weapon_client_2026-10-13.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
PANELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
QT = ROOT / "src/StarterPlayer/StarterPlayerScripts/QuestTarget.luau"
MAIN = ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/first_weapon_client_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_first_weapon_client_2026-10-13.json"

MUTATIONS = [
    ("the source ignores the switch (always the shop line)",
     "\tif info and info.ShopSource and not (type(Config.WeaponShop) == \"table\" and Config.WeaponShop.Buy == false) then\n",
     "\tif info and info.ShopSource then\n"),
    ("the source never uses the shop line", "\tif info and info.ShopSource and not (type(Config.WeaponShop)",
     "\tif false and info.ShopSource and not (type(Config.WeaponShop)"),
    ("tier 2 still 'Sold at the Forge' as its drop line",
     "{ Grade = \"Common\", Source = \"Slime Prince drop (your first one always drops it)\", ShopSource = \"Sold at the Forge\" },",
     "{ Grade = \"Common\", Source = \"Sold at the Forge\", ShopSource = \"Sold at the Forge\" },"),
    ("the drop goal asks for gold", "\t\tNextIronDrop = \"Next goal · Beat a King Slime for an Iron weapon\",",
     "\t\tNextIronDrop = \"Next goal · Beat a King Slime or pay %s gold\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, name: str):
    path = ROOT / f"build/first_weapon_client_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"FIRST_WEAPON_CLIENT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = config.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    panels = PANELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    qt = QT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    main = MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    static = [
        ("Panels: WSHOP.Sells() = Config.WeaponShop.Buy ~= false",
         "function WSHOP.Sells()\n\tlocal shop = Config.WeaponShop\n\treturn not (type(shop) == \"table\" and shop.Buy == false)\nend" in panels),
        ("Panels: a weapon I do not own and the Forge does not sell = no buttons, 'Get it: <source>', no buy reason",
         "local dropOnly = info ~= nil and not sells and not info.Owned and ui.Tier > 1" in panels
         and "ui.Buttons.Visible = not dropOnly" in panels and "if dropOnly then buyReason = nil end" in panels
         and "(dropOnly and string.format(T.WeaponFromF, Config.WeaponSource(ui.Tier)))" in panels
         and "ui.Sale" not in panels),
        ("Panels: owned weapons keep [Equip] (DisplayedAction) and the level line",
         'ui.DisplayedAction = info.Owned and "Equip" or (not dropOnly and "Buy" or nil)' in panels
         and "or string.format(T.WeaponLevelF, info.MinLevel, info.Level)" in panels),
        ("Panels: send() never buys while the Forge sells none (tier 1 = the gift path stays)",
         'if action == "Buy" and tier > 1 and not WSHOP.Sells() then return end' in panels),
        # A23-191 (English dump 10/15, 게임성 개발 1): no note, no far line, no first-weapon price / reason line
        ("Panels: the forge window has no explanation lines (note, far line, first weapon's price / reason)",
         "T.WeaponNote" not in panels and "T.WeaponFarDrop" not in panels and "T.WeaponFar" not in panels
         and "T.WeaponStarter\n" not in panels and '\t\taccessLabel.Text = far and "" or (access or "")\n' in panels
         and "ui.Price.Visible = info ~= nil and ui.Tier > 1" in panels and "T.WeaponSaleNoteF" not in panels
         and "T.WeaponSaleEquipped" not in panels
         and "ui.Sell.Visible = info ~= nil and info.Owned == true and ui.Tier > 1" in panels
         and "local closed = WSHOP.Closed(ui.Tier, info)" in panels and 'UIKit.ArtImage("IconLock", { Name = "ForgeLock",' in panels
         and "ui.Reason.Text = (ui.Tier > 1 and buyReason ~= T.WeaponEquipped and buyReason) or \"\"" in panels),
        ("HUD keeps the server's GoalKind and asks QuestTarget.IronGold for the anvil trip",
         'GoalKind = type(e.GoalKind) == "string" and e.GoalKind or nil' in hud
         and "qt.IronGold(e, level) == true" in hud and "if not e.NextGoal or ironGold then" in hud),
        ("HUD: Guide 'Bag' opens the bag on the scroll for the weapon in hand; the Bag tile glows during that step",
         'panels.Open("Bag", { Use = L.BagGuideScroll, Tier = math.floor(num("WeaponTier", 1)) })' in hud
         and 'L.BagGuideScroll = "Enh70"' in hud and 'e.Story.Guide == "Bag" then return true end' in hud
         and 'L.SetGlow("bag", ui.bagGlow, L.ItemsHint() or L.BagGuide())' in hud
         and 'if g == "PotionShop" or g == "QuickSlot" or g == "Bag" then' in hud),
        ("ClientMain: Config.ApplyTestServer() (A23-156) runs before the first module require, guarded",
         0 <= main.find("pcall(Config.ApplyTestServer)") < main.find("C[name] = require(script.Parent:WaitForChild(name))")
         and 'if type(Config.ApplyTestServer) == "function" then' in main),
        ("QuestTarget.IronGold: never while the Forge sells none; GoalKind before the text search",
         "function QuestTarget.IronGold(entry, level)" in qt and "Config.WeaponShop.Buy == false then return false end" in qt
         and 'if type(entry.GoalKind) == "string" then return entry.GoalKind == "IronGold" end' in qt),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (CONFIG, PANELS, HUD, QT, MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "The Forge window itself is checked statically here; how it looks with Buy = false is a Studio "
                             "photo (메인 반영 1, after the merge together with 게임성 개발 2's switch and first King T3)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
