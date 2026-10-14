"""Shop prices from Roblox (최종 검수 10/14, plan 2-C #10), offline.

ShopUI.LivePrice(id, infoType, fallback[, fetch]) shows MarketplaceService:GetProductInfo(id, infoType).PriceInRobux
(regional prices and sales = the same number as Roblox's buy window). Rules:
1. id 0 / missing = the Config price, and Roblox is never asked.
2. Each id is read ONCE per session in the background (pcall); until it answers the card shows the Config price.
3. A failure or no price (not for sale) = the Config price, remembered (never asked again).
4. A price read later repaints the open shop (PRICE.Refresh = the shop's refreshAll).
5. Call sites: pass cards (GamePass), looks (GamePass), class/faction tickets (Product).
6. Subscription cards (A23-182): ShopUI.SubPrice(id "EXP-...", fallback) = GetSubscriptionProductInfoAsync(id) the same
   way (one shared reader PRICE.Ask): its DisplayPrice text (the player's local money, drawn with MonthTextF) or a
   PriceInRobux number (MonthF); id "" / failure / neither = the Config R$ price.
Extracted and run: the PRICE table + ShopUI.LivePrice with a queued task.spawn and a fetch double. Static: the call sites.
Mutations: each must make a check fail.
Report: docs/art/verification_2026-10-14/offline_shop_price_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / "src/StarterPlayer/StarterPlayerScripts/ShopUI.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_shop_price_2026-10-14.json"
CUT = ("local PRICE = { Cache = {}", "ShopUI._PRICE = PRICE")

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local Q = {}
local spawnErrors = 0
local function flush()
	local q = Q
	Q = {}
	for _, f in q do
		local ok, err = pcall(f)
		if not ok then spawnErrors += 1 print("SPAWN_ERROR " .. tostring(err)) end
	end
end
local calls, mpCalls = {}, {}
local answers = {}
local function fetch(id, t)
	table.insert(calls, tostring(t) .. ":" .. id)
	local a = answers[tostring(t) .. ":" .. id]
	if a == "error" then error("http 500") end
	return a
end
local function count(list, key)
	local n = 0
	for _, v in list do if v == key then n += 1 end end
	return n
end
local MarketplaceService = { GetProductInfo = function(self, id, t)
	table.insert(mpCalls, tostring(t) .. ":" .. id)
	return { PriceInRobux = 77 }
end, GetSubscriptionProductInfoAsync = function(self, id)
	table.insert(mpCalls, "Sub:" .. tostring(id))
	return { DisplayPrice = "$2.99" }
end }
local ShopUI = {}
local env = setmetatable({ ShopUI = ShopUI, MarketplaceService = MarketplaceService,
	task = { spawn = function(f) table.insert(Q, f) end } }, { __index = getfenv() })
local f = assert(loadstring(PART .. "\nreturn PRICE", "=Part"))
setfenv(f, env)
local PRICE = f()
local refreshes = 0
PRICE.Refresh = function() refreshes += 1 end

-- 1. id 0 / nil / "0": the Config price, Roblox never asked
check(ShopUI.LivePrice(0, "GamePass", 199, fetch) == 199 and ShopUI.LivePrice(nil, "GamePass", 99, fetch) == 99
	and ShopUI.LivePrice("0", "Product", 49, fetch) == 49 and #calls == 0 and #Q == 0,
	"id 0 = the Config price, Roblox not asked", #calls)

-- 2. a success: Config price until it answers, asked once, then Roblox's price + one repaint
answers["GamePass:101"] = { PriceInRobux = 149 }
local first = ShopUI.LivePrice(101, "GamePass", 199, fetch)
local second = ShopUI.LivePrice(101, "GamePass", 199, fetch)
check(first == 199 and second == 199, "the Config price until Roblox answers", tostring(first) .. "/" .. tostring(second))
check(#Q == 1, "one background read while it waits (no second request)", #Q)
flush()
check(count(calls, "GamePass:101") == 1, "asked once", count(calls, "GamePass:101"))
check(refreshes == 1, "the open shop repaints once the price arrives", refreshes)
local after = ShopUI.LivePrice(101, "GamePass", 199, fetch)
check(after == 149 and #Q == 0 and count(calls, "GamePass:101") == 1, "then Roblox's price, read from the cache", after)
check(ShopUI.LivePrice("101", "GamePass", 199, fetch) == 149, "a text id finds the same price", "")

-- 3. a failure: the Config price, remembered (not asked again), nothing stuck
answers["GamePass:202"] = "error"
ShopUI.LivePrice(202, "GamePass", 99, fetch)
flush()
check(PRICE.Cache["GamePass:202"] == false and PRICE.Busy["GamePass:202"] == nil, "a failure is remembered, nothing stuck",
	tostring(PRICE.Cache["GamePass:202"]))
check(ShopUI.LivePrice(202, "GamePass", 99, fetch) == 99 and #Q == 0 and count(calls, "GamePass:202") == 1,
	"after a failure: the Config price, not asked again", count(calls, "GamePass:202"))

-- 4. not for sale (no PriceInRobux) / not a table: the Config price
answers["Product:303"] = { Name = "Class ticket" }
answers["Product:304"] = "oops"
ShopUI.LivePrice(303, "Product", 49, fetch)
ShopUI.LivePrice(304, "Product", 59, fetch)
flush()
check(ShopUI.LivePrice(303, "Product", 49, fetch) == 49 and ShopUI.LivePrice(304, "Product", 59, fetch) == 59,
	"no price / odd answer = the Config price", "")

-- 5. a free item (0) is a real price; a fraction is floored
answers["Product:305"] = { PriceInRobux = 0 }
answers["Product:306"] = { PriceInRobux = 24.9 }
ShopUI.LivePrice(305, "Product", 10, fetch)
ShopUI.LivePrice(306, "Product", 10, fetch)
flush()
check(ShopUI.LivePrice(305, "Product", 10, fetch) == 0 and ShopUI.LivePrice(306, "Product", 10, fetch) == 24,
	"0 shows 0, 24.9 shows 24", "")

-- 6. the same id as a pass and as a product = two prices
answers["Product:101"] = { PriceInRobux = 25 }
ShopUI.LivePrice(101, "Product", 30, fetch)
flush()
check(ShopUI.LivePrice(101, "Product", 30, fetch) == 25 and ShopUI.LivePrice(101, "GamePass", 199, fetch) == 149,
	"a pass and a product with one id keep their own prices", "")

-- 7. no fetch given: MarketplaceService:GetProductInfo(id, infoType)
ShopUI.LivePrice(707, "GamePass", 5)
flush()
check(count(mpCalls, "GamePass:707") == 1 and ShopUI.LivePrice(707, "GamePass", 5) == 77,
	"the real read is MarketplaceService:GetProductInfo(id, infoType)", table.concat(mpCalls, ","))

-- 8. a repaint that breaks does not break the price
PRICE.Refresh = function() error("ui gone") end
answers["GamePass:808"] = { PriceInRobux = 300 }
ShopUI.LivePrice(808, "GamePass", 1, fetch)
flush()
check(ShopUI.LivePrice(808, "GamePass", 1, fetch) == 300 and PRICE.Busy["GamePass:808"] == nil
	and spawnErrors == 0, "a broken repaint keeps the price (no error escapes the read)", spawnErrors)
-- 9. subscriptions: "" / "0" = Config, never asked; DisplayPrice text; R$ number; failure = Config; real read
PRICE.Refresh = function() refreshes += 1 end
local subCalls = {}
local subAnswers = { ["EXP-1"] = { DisplayPrice = "$4.99", PriceInRobux = 400 }, ["EXP-2"] = { PriceInRobux = 149 },
	["EXP-3"] = "error", ["EXP-4"] = { DisplayPrice = "" } }
local function subFetch(id)
	table.insert(subCalls, id)
	local a = subAnswers[id]
	if a == "error" then error("http 500") end
	return a
end
check(ShopUI.SubPrice("", 149, subFetch) == 149 and ShopUI.SubPrice("0", 149, subFetch) == 149
	and ShopUI.SubPrice(nil, 149, subFetch) == 149 and #subCalls == 0 and #Q == 0, "no subscription id = Config, not asked",
	#subCalls)
local before = refreshes
for _, id in { "EXP-1", "EXP-2", "EXP-3", "EXP-4" } do
	check(ShopUI.SubPrice(id, 149, subFetch) == 149, "Config price until Roblox answers (" .. id .. ")", "")
	ShopUI.SubPrice(id, 149, subFetch)
end
check(#Q == 4, "one read per subscription", #Q)
flush()
check(ShopUI.SubPrice("EXP-1", 149, subFetch) == "$4.99", "Roblox's own price text first", tostring(ShopUI.SubPrice("EXP-1", 149, subFetch)))
check(ShopUI.SubPrice("EXP-2", 149, subFetch) == 149 and PRICE.Cache["Sub:EXP-2"] == 149, "else its R$ number", "")
check(ShopUI.SubPrice("EXP-3", 99, subFetch) == 99 and PRICE.Cache["Sub:EXP-3"] == false, "a failure = Config, remembered", "")
check(ShopUI.SubPrice("EXP-4", 99, subFetch) == 99, "an empty price text = Config", "")
check(#subCalls == 4 and #Q == 0 and refreshes == before + 4, "asked once each, each answer repaints", #subCalls)
ShopUI.SubPrice("EXP-9", 1)
flush()
check(count(mpCalls, "Sub:EXP-9") == 1 and ShopUI.SubPrice("EXP-9", 1) == "$2.99",
	"the real read is MarketplaceService:GetSubscriptionProductInfoAsync(id)", table.concat(mpCalls, ","))
check(spawnErrors == 0, "no error escapes a read", spawnErrors)
print(("SHOP_PRICE_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("id 0 asks Roblox", "\tif id <= 0 then return fallback end\n", "\tif id < 0 then return fallback end\n"),
    ("the cache ignored", "\tif v ~= nil then return v == false and fallback or v end\n", ""),
    ("a failure not remembered", "(ok and price ~= nil) and price or false", "(ok and price ~= nil) and price or nil"),
    ("asked again while it waits", "\tif not PRICE.Busy[key] then\n", "\tif true then\n"),
    ("busy never cleared", "\t\t\tPRICE.Busy[key] = nil\n", ""),
    ("no repaint", "\t\t\tif PRICE.Refresh then pcall(PRICE.Refresh) end\n", ""),
    ("the repaint without pcall", "if PRICE.Refresh then pcall(PRICE.Refresh) end", "if PRICE.Refresh then PRICE.Refresh() end"),
    ("the read without pcall", "local ok, price = pcall(function()\n\t\t\t\tlocal info = call()\n"
     "\t\t\t\treturn type(info) == \"table\" and read(info) or nil\n\t\t\tend)\n",
     "local ok, price = true, (function()\n\t\t\t\tlocal info = call()\n"
     "\t\t\t\treturn type(info) == \"table\" and read(info) or nil\n\t\t\tend)()\n"),
    ("a free item shows the Config price", "(price and price >= 0)", "(price and price > 0)"),
    ("the pass card keeps the Config price",
     "Price = ShopUI.LivePrice(cfg.Id, Enum.InfoType.GamePass, tonumber(cfg.Price) or tonumber(cfg.PriceHint) or p.Price),",
     "Price = tonumber(cfg.Price) or tonumber(cfg.PriceHint) or p.Price,"),
    ("the looks keep the Config price",
     "local price = ShopUI.LivePrice(def.PassId or def.Id, Enum.InfoType.GamePass, tonumber(def.Price) or 99)",
     "local price = tonumber(def.Price) or 99"),
    ("the tickets read a pass price", "ShopUI.LivePrice(p.Id, Enum.InfoType.Product, p.PriceHint)",
     "ShopUI.LivePrice(p.Id, Enum.InfoType.GamePass, p.PriceHint)"),
    ("the shop never registers its repaint", "\tPRICE.Refresh = refreshAll", "\t-- PRICE.Refresh = refreshAll"),
    ("the ticket button not repainted", "if r.Button and r.PriceText then r.Button.Text = r.PriceText() end", ""),
    ("an empty subscription id asks Roblox", 'if type(id) ~= "string" or id == "" or id == "0" then return fallback end',
     'if type(id) ~= "string" then return fallback end'),
    ("the subscription ignores Roblox's price text",
     '\t\tif type(info.DisplayPrice) == "string" and info.DisplayPrice ~= "" then return info.DisplayPrice end\n', ""),
    ("the subscription ignores its R$ number", "return (robux and robux >= 0) and math.floor(robux) or nil", "return nil"),
    ("the subscription card keeps the Config price", "local price = ShopUI.SubPrice(cell.Sub.Id, cell.Sub.Price)",
     "local price = cell.Sub.Price"),
    ("the price text drawn as R$", 'type(price) == "string" and string.format(T.MonthTextF, price)',
     'false and string.format(T.MonthTextF, price)'),
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
    return text[a:b] if b >= 0 else ""


CONFIG_TEXT = CONFIG.read_text(encoding="utf-8-sig")


def statics(src: str) -> list[tuple[str, bool]]:
    return [
        ("pass cards: GamePass price from Roblox, Config as the fallback",
         "Price = ShopUI.LivePrice(cfg.Id, Enum.InfoType.GamePass, tonumber(cfg.Price) or tonumber(cfg.PriceHint) or p.Price),"
         in src),
        ("looks: GamePass price from Roblox",
         "local price = ShopUI.LivePrice(def.PassId or def.Id, Enum.InfoType.GamePass, tonumber(def.Price) or 99)" in src
         and "Util.FormatInt(price)" in src),
        ("tickets: Product price from Roblox", "ShopUI.LivePrice(p.Id, Enum.InfoType.Product, p.PriceHint)" in src),
        ("subscription cards: Roblox's price, text with MonthTextF, R$ with MonthF",
         "local price = ShopUI.SubPrice(cell.Sub.Id, cell.Sub.Price)" in src
         and 'type(price) == "string" and string.format(T.MonthTextF, price)' in src
         and "or string.format(T.MonthF, Util.FormatInt(price))" in src
         and re.search(r'\bMonthTextF = "%s / mo"', CONFIG_TEXT) is not None),
        ("the shop registers its repaint and repaints ticket buttons",
         "\tPRICE.Refresh = refreshAll" in src
         and "if r.Button and r.PriceText then r.Button.Text = r.PriceText() end" in src),
    ]


def run(src: str) -> tuple[int, int, str]:
    part = cut(src, *CUT)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "shop_price.luau"
        p.write_text("local PART = " + lua_str(part) + "\n" + FIXTURE, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"SHOP_PRICE_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = FILE.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    found = cut(src, *CUT) != ""
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = False
        if hits == 1:
            caught = run(src.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks > 4 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
