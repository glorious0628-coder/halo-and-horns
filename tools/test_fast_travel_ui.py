"""Fast Travel = a monthly subscription (SPEC A23-182, user 10/14; 정정: not a pass), the client side, offline.

The Travel window and its HUD square are for a subscriber only (the server's player attribute SubFastTravel, game dev 2);
everyone else walks or uses the glowing / PvP pads (A23-88, untouched). The shop shows one subscription card per
Config.SubscriptionInfo row whose Id is a real subscription id ("" / "0" / missing = no card); its tap =
MarketplaceService:PromptSubscriptionPurchase, subscribed = "Owned".
Extracted and run (official Luau CLI): Panels.TravelOn, HUD L.TileWindow, ShopUI.SubCards. Static: every way into the
Travel window (Panels.Open gate, the Menu row, the HUD square refresh on SubFastTravel, SkillBook's [Where to hunt]) and
the shop card's prompt / refresh. Mutations: each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_fast_travel_ui_2026-10-14.json (do not commit)
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
FILES = {"PANELS": SPS / "Panels.luau", "HUD": SPS / "HUD.luau", "SHOP": SPS / "ShopUI.luau", "BOOK": SPS / "SkillBook.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_fast_travel_ui_2026-10-14.json"
CUTS = {"PANELS": ("function Panels.TravelOn()", "\nend\n"), "HUD": ("function L.TileWindow(def)", "\nend\n"),
        "SHOP": ("function ShopUI.SubCards()", "\nend\n")}

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local ATTR = {}
local player = { GetAttribute = function(_, k) return ATTR[k] end }
Panels, L, ShopUI, Config = {}, {}, {}, {}
local env = setmetatable({ Panels = Panels, L = L, ShopUI = ShopUI, Config = Config, player = player }, { __index = getfenv() })
local f = assert(loadstring(PART, "=Part"))
setfenv(f, env)
f()
local REG = { Travel = true, Shop = true, Help = true }
env.C = { Panels = { Has = function(id) return REG[id] == true end, TravelOn = Panels.TravelOn } }
-- 1) the Travel window / square
check(Panels.TravelOn() == false, "no subscription: Travel off", "")
check(L.TileWindow({ Window = "Travel" }) == nil, "no subscription: no Travel square", "")
check(L.TileWindow({ Window = "Shop" }) == "Shop" and L.TileWindow({ Window = "Help" }) == "Help", "other squares untouched", "")
ATTR.SubFastTravel = "yes"
check(Panels.TravelOn() == false and L.TileWindow({ Window = "Travel" }) == nil, "only true counts (not a string)", "")
ATTR.SubFastTravel = true
check(Panels.TravelOn() == true and L.TileWindow({ Window = "Travel" }) == "Travel", "subscribed: the Travel square", "")
-- 2) the shop's subscription cards
check(#ShopUI.SubCards() == 0, "no Config.SubscriptionInfo: no card", "")
Config.SubscriptionInfo = { FastTravel = { Id = "", Name = "Fast Travel", Price = 149 } }
check(#ShopUI.SubCards() == 0, "an empty id: no card", "")
Config.SubscriptionInfo.FastTravel.Id = "0"
check(#ShopUI.SubCards() == 0, "id 0: no card", "")
Config.SubscriptionInfo.FastTravel.Id = 12345
check(#ShopUI.SubCards() == 0, "a number id (not a subscription id string): no card", "")
Config.SubscriptionInfo.FastTravel.Id = "EXP-123"
local cards = ShopUI.SubCards()
check(#cards == 1 and cards[1].Kind == "FastTravel" and cards[1].Id == "EXP-123" and cards[1].Attr == "SubFastTravel"
	and cards[1].Price == 149 and cards[1].Icon == "IconTravel", "a real id: one card (attr SubFastTravel, price, icon)", #cards)
Config.SubscriptionInfo.FastTravel.Name = nil
check(#ShopUI.SubCards() == 0, "no name (no words): no card", "")
print(("FAST_TRAVEL_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("PANELS", "a string counts as subscribed", 'return player:GetAttribute("SubFastTravel") == true', 'return player:GetAttribute("SubFastTravel") ~= nil'),
    ("HUD", "the Travel square for everyone",
     '\tif def.Window == "Travel" and not (type(panels.TravelOn) == "function" and panels.TravelOn() == true) then return nil end\n', ""),
    ("SHOP", "an empty id still shows a card", 'and d.Id ~= "" and d.Id ~= "0"', ""),
    ("SHOP", "a number id shows a card", 'type(d.Id) == "string" and d.Id ~= ""', '(d.Id ~= nil) and d.Id ~= ""'),
    ("SHOP", "the wrong attribute", 'or ("Sub" .. kind)', 'or kind'),
    ("PANELS", "the Travel window opens for anyone", '\tif id == "Travel" and not Panels.TravelOn() then return end -- A23-182: Fast Travel subscribers only\n', ""),
    ("PANELS", "the Menu keeps its Travel row", '\t\t\tif entries[i].Id == "Travel" then table.remove(entries, i) end\n', ""),
    ("HUD", "the square never refreshes", '\tUIKit.OnAttr({ "SubFastTravel" }, function() if ui.foldOpen then L.PlaceFold(false) end end) -- A23-182: the Travel square\n', ""),
    ("SHOP", "the card buys a game pass", "pcall(MarketplaceService.PromptSubscriptionPurchase, MarketplaceService, player, id)",
     "pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, id)"),
    ("SHOP", "the card never repaints", "\t\trefreshSubs()\n\t\tfor _, cell in lookCells", "\t\tfor _, cell in lookCells"),
    ("BOOK", "[Where to hunt] without the check", "if row.Locked and travelOn then", "if row.Locked then"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    p, h, s, b = src["PANELS"], src["HUD"], src["SHOP"], src["BOOK"]
    return [
        ("Panels.Open refuses Travel without the subscription", 'if id == "Travel" and not Panels.TravelOn() then return end' in p),
        ("the Menu drops its Travel row without it", 'if entries[i].Id == "Travel" then table.remove(entries, i) end' in p
         and "if not Panels.TravelOn() then" in p),
        ("the HUD square follows SubFastTravel", 'UIKit.OnAttr({ "SubFastTravel" }, function() if ui.foldOpen then L.PlaceFold(false) end end)' in h),
        ("SkillBook's [Where to hunt] only with it", "if row.Locked and travelOn then" in b),
        ("the shop card prompts the subscription and repaints", "pcall(MarketplaceService.PromptSubscriptionPurchase, MarketplaceService, player, id)" in s and "\t\trefreshSubs()\n\t\tfor _, cell in lookCells" in s
         and "setCapsule(kit, cell, T.Owned, kit.Palette.Free, true)" in s),
    ]


def run(src: dict) -> tuple[int, int, str]:
    part = "\n".join(cut(src[k], *v) for k, v in CUTS.items())
    with tempfile.TemporaryDirectory() as d:
        pth = Path(d) / "fast_travel.luau"
        pth.write_text("local PART = " + lua_str(part) + "\n" + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(pth)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"FAST_TRAVEL_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(src[k], *v) for k, v in CUTS.items())
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
    ok = found and failed == 0 and checks > 3 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
