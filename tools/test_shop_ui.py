"""ShopUI offline check (plan docs/design/gameplay_plan_2026-10-13.md §1-A #6 "상점 정리").

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/ShopUI.luau with the CURRENT Config.luau and Util.luau in
tools/fixtures/shop_ui_offline.luau with the installed official Luau CLI (build/luau_cli_0_741): the six pass cards
(+ Sticker Pack, Bubble Pack), the words from Config.PassInfo (no VIP emote promised; the private server card says
rewards are halved there), [Buy] following the live switch PassSales (GameState SwitchPassSales), { Focus = kind } from
a locked sticker / bubble. Static: StickerUI opens the Shop on the pass; ShopUI keeps no words of its own; the HUD's
private-server chip. Mutations: in-memory copies with one rule broken each; each must make a check fail. The layout on
PC / phones is tools/test_shop_layout.py.
Report: docs/art/verification_2026-10-13/offline_shop_ui_2026-10-13.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
MODULE = SCRIPTS / "ShopUI.luau"
STICKER = SCRIPTS / "StickerUI.luau"
HUD = SCRIPTS / "HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
UTIL = ROOT / "src/ReplicatedStorage/Shared/Util.luau"
FIXTURE = ROOT / "tools/fixtures/shop_ui_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-13/offline_shop_ui_2026-10-13.json"

MUTATIONS = [
    ("PassSales ignored on the pass cards",
     "\telseif not salesOn() then\n\t\tsetCapsule(kit, cell, T.Off, kit.Palette.Button, false)\n\telse\n\t\tsetCapsule(kit, cell, string.format(T.PriceF, Util.FormatInt(d.Price))",
     "\telse\n\t\tsetCapsule(kit, cell, string.format(T.PriceF, Util.FormatInt(d.Price))"),
    ("PassSales ignored on the looks",
     "\telseif not salesOn() then\n\t\tsetCapsule(kit, cell, T.Off, kit.Palette.Button, false)\n\telse\n\t\tlocal price = ShopUI.LivePrice(",
     "\telse\n\t\tlocal price = ShopUI.LivePrice("),
    ("a pass prompt while sales are off", "\tif not salesOn() then kit.Toast(T.OffToast, \"info\"); return end\n\tprompt(d.Id, p.Kind)",
     "\tprompt(d.Id, p.Kind)"),
    ("a look prompt while sales are off", "\tif not salesOn() then kit.Toast(T.OffToast, \"info\"); return end\n\tprompt(passId, \"Look\")",
     "\tprompt(passId, \"Look\")"),
    ("no switch sent = off", "\treturn not (gs and gs:GetAttribute(\"SwitchPassSales\") == false)\n",
     "\treturn gs ~= nil and gs:GetAttribute(\"SwitchPassSales\") == true\n"),
    ("the Bubble Pack card missing",
     "\t{ Kind = \"Bubbles\", Badge = \"IconPassBubbles\", Icon = \"BarkBubble\", Slot = \"RewardSlot\", Price = 99, Attr = \"PassBubbles\" },\n", ""),
    ("the Sticker Pack card missing",
     "\t{ Kind = \"Stickers\", Badge = \"IconPassStickers\", Icon = \"EmoHeart\", Slot = \"RewardSlot\", Price = 99, Attr = \"PassStickers\" },\n", ""),
    ("the private server card without the halved line", "\tif p.Info and type(ps) == \"table\"", "\tif false and type(ps) == \"table\""),
    ("names not from Config", "\treturn type(cfg) == \"table\" and type(cfg.Name) == \"string\" and cfg.Name or p.Kind\n", "\treturn p.Kind\n"),
    ("the focus ignored", "\t\tif focus == p.Kind then\n", "\t\tif false then\n"),
    ("every card focused", "\t\tif focus == p.Kind then\n", "\t\tif focus ~= nil then\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, config: str, util: str, name: str):
    path = ROOT / f"build/shop_ui_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal UTIL_SOURCE = " + lua_str(util)
                    + "\nlocal SHOP_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"SHOP_UI_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = MODULE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    util = UTIL.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, config, util, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), config, util, "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    sticker = STICKER.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    shop_words = re.findall(r'"([A-Z][a-z]+(?: [a-z!.]+){2,}[^"]*)"', code)  # an English phrase of 3+ words in the code
    static = [
        ("a locked sticker opens the Shop on the Sticker Pack, a locked bubble on the Bubble Pack",
         'pcall(panels.Open, "Shop", { Focus = kind })' in sticker and sticker.count("openShop(Config.Stickers.Pass)") == 1
         and sticker.count("openShop(Config.Bubbles.Pass)") == 1),
        ("ShopUI keeps no words of its own (Config.PassInfo.Screen)", "local T = type(INFO.Screen)" in src and not shop_words),
        ("the HUD shows one private-server chip from GameState PrivateServer (a press: Config.PrivateServer.Text)",
         'UIKit.GameAttr("PrivateServer", false) == true, TXT.PrivateHalf' in hud and "pcall(UIKit.Toast, ps.Text" in hud
         and '"Boost", "Private",' in hud),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (MODULE, CONFIG, UTIL, STICKER, HUD)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of Panels / UIKit; Roblox's own purchase dialog and the pass ids are the user's "
                             "(Creator Hub, 10/15). The private-server chip needs 게임성 개발 2's GameState PrivateServer."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
