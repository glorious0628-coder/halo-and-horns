"""C-5 / C-7 the player market (MarketService, 게임성 개발 2, 2026-10-13), offline.

SPEC A23-127 / A23-133; design docs/design/market_server_2026-10-13.md; the window MarketWindow.luau (게임성 개발 4,
docs/design/market_window_2026-10-12.md §6). One market for every server: the ledger DataStore row "L_<id>" is the truth,
the MemoryStore maps list what is open. List / buy / cancel save the player FIRST (DataService.Save must succeed), then the
ledger (one UpdateAsync: two buyers -> one wins), then the maps; the seller is paid by its own server (a sold hint, the
ledger round, the join check) once (Done), never 2x; a server that stops between two steps loses nothing (the join check).
Gates A23-133 (buy Lv5, sell Lv10 + 1 hour + a 7-day account), 10 open, 20 lists / 30 buys a KST day, 3 a day from one
seller, 10% fee. Runs the CURRENT Config, Util, LootService and MarketService on tools/fixtures/dev2_kit.luau +
tools/fixtures/dev3_world.luau with tools/fixtures/market_offline.luau (a MemoryStore double; two worlds sharing the stores
= two servers) and the installed official Luau CLI. No Studio, network, DataStore or Roblox API calls; mutations run on
in-memory copies only.

Usage: py tools/test_market.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-13/offline_dev2_market_2026-10-13.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "MARKET_SOURCE": SSS / "MarketService.luau",
}
C, L, X = "CONFIG_SOURCE", "LOOT_SOURCE", "MARKET_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    return dict(sources)


MUTATIONS = [
    # --- config
    ("config: the switch ships on", C, "Config.Features = { NeutralFaction = false, Market = false,", "Config.Features = { NeutralFaction = false, Market = true,"),
    ("config: buying from Lv1", C, "BuyLevel = 5, ListLevel = 10,", "BuyLevel = 1, ListLevel = 10,"),
    ("config: no playtime gate", C, "ListPlaySeconds = 3600,", "ListPlaySeconds = 0,"),
    ("unpack: only with the market", X, "if not data or not (switchOn() or Config.FeatureOn(\"Crafting\")) then return end",
     "if not data or not switchOn() then return end"),
    ("unpack: always", X, "if not data or not (switchOn() or Config.FeatureOn(\"Crafting\")) then return end",
     "if not data then return end"),
    ("config: a 10% fee again", C, "\tFee = 0.07, -- A23-183", "\tFee = 0.10, -- A23-183"),
    ("config: Pend flags dropped by the save", C, "\t\treturn V4.keepExtra(r, { K = k, N = n, Price = p, St = st }, { K = true, N = true, Price = true, St = true })",
     "\t\treturn { K = k, N = n, Price = p, St = st }"),
    ("config: market gold 2x", C, "for name, s in { MarketIndex = 1,", "Config.PassBoost.GoldSources.Market = true\nfor name, s in { MarketIndex = 1,"),
    ("config: tonics cannot be listed", C, "Kinds = { Material = true, Enhance = true, Transfer = true, Tonic = true, Treat = true },",
     "Kinds = { Material = true, Enhance = true, Transfer = true, Treat = true },"),
    ("config: tier 1 can be listed", C, "if not tier or not plus or tier < 2 or tier > Config.MaxWeaponTier", "if not tier or not plus or tier < 1 or tier > Config.MaxWeaponTier"),
    ("config: no plus cap", C, "or plus > Config.Loot.MaxEnhance then return nil end\n\treturn string.format(\"W:%d:%d\"", "then return nil end\n\treturn string.format(\"W:%d:%d\""),
    ("config: a material's Min below its Sell", C, "return sell * M.MaterialRef, sell, sell * M.MaterialMax", "return sell * M.MaterialRef, 1, sell * M.MaterialMax"),
    ("config: weapon Ref without the plus", C, "local ref = math.floor(base * (1 + M.PlusRef * info.Plus))", "local ref = math.floor(base)"),
    # --- LootService helpers
    ("loot: TakeSpare takes more than there is", L, "\tif have < n then return false end\n\tdata.Spares[key] = have > n", "\tdata.Spares[key] = have > n"),
    ("loot: a bought weapon without its +N", L, "\tdata.WeaponEnhance[tier] = plus\n\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\"", "\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\""),
    ("loot: pack the weapon in hand", L, "\tif math.floor(num(data.WeaponTier, 0)) == tier then return \"InHand\" end\n", ""),
    ("loot: pack keeps the tier owned", L, "\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\", bit32.band(", "\tlocal _ = (bit32.band("),
    ("loot: pack keeps the +N on the tier", L, "\tdata.WeaponEnhance[tier] = 0\n\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\", bit32.band(",
     "\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\", bit32.band("),
    ("loot: unpack an owned tier", L, "\tif owns(data, tier) then return \"Owned\" end\n\tLootService.TakeSpare(", "\tLootService.TakeSpare("),
    # --- gates
    ("gate: no buy level", X, "\tif level < M.BuyLevel then\n\t\tg.Buy = \"NeedLevelBuy\"\n\telseif", "\tif false then\n\t\tg.Buy = \"NeedLevelBuy\"\n\telseif"),
    ("gate: no account age", X, "\telseif num(age, 0) < M.ListAccountDays then\n", "\telseif false then\n"),
    ("gate: no open cap", X, "\telseif openRows(m) >= M.OpenMax then\n", "\telseif false then\n"),
    ("gate: no daily buys", X, "\telseif m.Buys >= M.DayBuys then\n", "\telseif false then\n"),
    ("gate: the day never resets", X, "\tif m.Day ~= today then\n\t\tm.Day, m.Lists, m.Buys = today, 0, 0\n", "\tif false then\n\t\tm.Day, m.Lists, m.Buys = today, 0, 0\n"),
    ("gate: the pair counts kept over days", X, "\t\t\tif type(k) == \"string\" and string.match(k, \"^P%d+$\") then m[k] = nil end", "\t\t\tlocal _ = k"),
    ("gate: Studio memory mode open", X, "\tif not persistent() then\n\t\tg.Buy, g.List = \"Resting\", \"Resting\"", "\tif false then\n\t\tg.Buy, g.List = \"Resting\", \"Resting\""),
    # --- list
    ("list: no price range", X, "\tif price < lo or price > hi then return note(player, \"PriceRange\") end\n", ""),
    ("list: several weapons in a row", X, "\tif info.Kind == \"W\" and n ~= 1 then return note(player, \"CantSell\") end\n", ""),
    ("list: the ledger before the save", X, "\tif not saveNow(player) then -- nothing is public yet: undo\n\t\tm.Lists -= 1",
     "\tif false then -- nothing is public yet: undo\n\t\tm.Lists -= 1"),
    ("list: a failed save keeps the things away", X, "\t\tlocal left = giveThing(player, data, key, n)\n\t\tif left > 0 then",
     "\t\tlocal left = 0\n\t\tif left > 0 then"),
    ("list: the ledger row overwritten", X, "\t\tcreated = false\n\t\tif old ~= nil then return nil end\n", "\t\tcreated = false\n"),
    ("list: a map error loses the listing", X, "\tif not mapPut(lid, rec) then row.Idx = false end\n", "\tmapPut(lid, rec)\n"),
    # --- buy
    ("buy: my own listing", X, "\tif rec.Seller == player.UserId then return note(player, \"Own\") end\n", ""),
    ("buy: any price", X, "\tif math.floor(num(rec.Price, -1)) ~= price then return note(player, \"PriceChanged\") end\n", ""),
    ("buy: an owned weapon tier", X, "\tif info.Kind == \"W\" and ownsTier(data, info.Tier) then return note(player, \"Owned\") end\n", ""),
    ("buy: no room check", X, "\tif info.Kind == \"I\" and not hasRoom(data, rec.K, n) then return note(player, \"CantReceive\") end\n", ""),
    ("buy: no pair limit", X, "\tif math.floor(num(m[pairKey], 0)) >= M.PairDay then return note(player, \"PairLimit\") end\n", ""),
    ("buy: one unit's price for the row", X, "\tlocal total = price * n\n", "\tlocal total = price\n"),
    ("buy: an ended listing sold", X, "\t\tif old and old.St == \"Open\" and os.time() < num(old.Exp, 0) and old.Seller ~= uid and old.Price == rec.Price",
     "\t\tif old and old.St == \"Open\" and old.Seller ~= uid and old.Price == rec.Price"),
    ("buy: an expired read still bought", X, "\tif not rec or rec.St ~= \"Open\" or os.time() >= num(rec.Exp, 0) then\n", "\tif not rec or rec.St ~= \"Open\" then\n"),
    ("buy: the ledger before the save", X, "\tif not saveNow(player) then -- nothing changed in the market: undo", "\tif false then -- nothing changed in the market: undo"),
    ("buy: a failed save keeps the gold", X, "\t\tpcall(S.ProgressionService.AddBankGold, player, total, \"MarketRefund\")\n\t\treturn note(player, \"Resting\")",
     "\t\treturn note(player, \"Resting\")"),
    ("buy: a sold row bought again (two winners)", X, "\t\tif old and old.St == \"Open\" and os.time() < num(old.Exp, 0)", "\t\tif old and (old.St == \"Open\" or old.St == \"Sold\") and os.time() < num(old.Exp, 0)"),
    ("buy: a written-then-error buy refunded", X, "\t\tafter, won = again, again ~= nil and again.St == \"Sold\" and again.Buyer == uid", "\t\tafter, won = again, false"),
    ("buy: no answer refunded at once", X, "\t\tif not okA then return note(player, \"Checking\") end", "\t\tif not okA then won = false end"),
    ("buy: no seller hint", X, "\t\thintSold(rec.Seller, id)\n", ""),
    ("buy: stays on the map", X, "\t\thintSold(rec.Seller, id)\n\t\tmapDrop(rec.K, id)\n", "\t\thintSold(rec.Seller, id)\n"),
    # --- settle
    ("pay: no fee", X, "\tlocal get = total - math.floor(total * M.Fee)\n", "\tlocal get = total\n"),
    ("pay: as 2x-able gold", X, "pcall(S.ProgressionService.AddBankGold, player, get, \"Market\")", "pcall(S.ProgressionService.AddBankGold, player, get, \"Monster\")"),
    ("refund: no Done check", X, "\t\tm.In[id] = nil\n\t\treturn\n\tend\n\tlocal gold = math.floor(num(row.Price, 0))",
     "\t\tm.In[id] = nil\n\tend\n\tlocal gold = math.floor(num(row.Price, 0))"),
    ("pay: a Paid row paid again", X, "\tif row.St == \"Paid\" or row.St == \"Cancel\" or row.St == \"Expired\" then return end -- finished",
     "\tif row.St == \"Cancel\" or row.St == \"Expired\" then return end -- finished"),
    ("pay: the ledger Paid before the save", X, "\t\tif saveNow(player) then\n\t\t\tlupdate(id, function(old)", "\t\tif true then\n\t\t\tlupdate(id, function(old)"),
    ("pay: a ledger Paid row paid", X, "\tif rec.Paid == true then -- paid by a save", "\tif false then -- paid by a save"),
    ("deliver: twice", X, "\tif isDone(m, id) then\n\t\tm.In[id] = nil\n\t\treturn\n\tend\n\tlocal info = Config.MarketParse(row.K)\n",
     "\tlocal info = Config.MarketParse(row.K)\n"),
    ("refund: to the pocket", X, "pcall(S.ProgressionService.AddBankGold, player, gold, \"MarketRefund\")", "pcall(S.ProgressionService.AddCarriedGold, player, gold, \"MarketRefund\")"),
    ("settle: a Pend row without a ledger row stays", X, "\t\t\tgiveBack(player, data, id, row, \"Cancel\") -- never published: the things come back\n", "\t\t\tlocal _ = row\n"),
    ("settle: a Pend row with a ledger row given back", X, "\t\tif row.Pend == true then\n\t\t\trow.Pend, row.Idx = nil, false\n\t\tend\n",
     "\t\tif row.Pend == true then\n\t\t\tgiveBack(player, data, id, row, \"Cancel\")\n\t\t\treturn\n\t\tend\n"),
    ("settle: an In row with a still-open listing delivered", X, "\tif rec and rec.St == \"Sold\" and rec.Buyer == uid then\n\t\tdeliver(",
     "\tif rec and (rec.St == \"Sold\" or rec.St == \"Open\") then\n\t\tdeliver("),
    ("expire: never", X, "\t\tif os.time() >= num(rec.Exp, 0) then\n\t\t\tlocal won = false", "\t\tif false then\n\t\t\tlocal won = false"),
    ("cancel: no room check", X, "\tif not hasRoom(data, row.K, math.floor(num(row.N, 0))) then return note(player, \"CantReceive\") end\n", ""),
    ("cancel: a sold row given back", X, "\t\tif old and old.St == \"Open\" and old.Seller == uid then\n\t\t\told.St = \"Cancel\"",
     "\t\tif old and (old.St == \"Open\" or old.St == \"Sold\") and old.Seller == uid then\n\t\t\told.St = \"Cancel\""),
    ("round: no join check", X, "\t\t\t\tST.LedgerAt[player] = os.clock()\n\t\t\t\tround(player, true)\n", "\t\t\t\tST.LedgerAt[player] = os.clock()\n"),
    ("round: hints ignored", X, "\t\tfor _, id in takeHints(player) do hinted[id] = true end\n", ""),
    ("round: finished rows kept forever", X, "\t\t\t\tm.Out[id] = nil\n\t\t\tend\n\t\tend\n\tend)", "\t\t\t\tlocal _ = id\n\t\t\tend\n\t\tend\n\tend)"),
    # --- answers
    ("page: my own rows shown", X, "\t\tif r.Seller ~= player.UserId and num(r.X, 0) > now then table.insert(mine, r) end",
     "\t\tif num(r.X, 0) > now then table.insert(mine, r) end"),
    ("page: the seller in the rows", X, "table.insert(out, { Id = r.Id, Price = r.Price, N = r.N, Plus = plusOf(key),",
     "table.insert(out, { Id = r.Id, Seller = r.Seller, Price = r.Price, N = r.N, Plus = plusOf(key),"),
    ("index: no cache", X, "\tif not idx or os.clock() - idx.At >= M.IndexCache then\n", "\tif true then\n"),
    ("mine: Paid shown as Paid state", X, "(r.St == \"Paid\" and \"Sold\" or r.St)", "r.St"),
    ("quest: no MarketPaid happening", X, "\thappened(player, MarketService.Paid, \"MarketPaid\", get)\n", ""),
    ("quest: no MarketBought happening", X, "\thappened(player, MarketService.Bought, \"MarketBought\")\n", ""),
    ("quest: no MarketListed happening", X, "\thappened(player, MarketService.Listed, \"MarketListed\")\n", ""),
    ("quest: the buy quest at Lv1", C, "Requires = { Level = 5, Feature = \"Market\" },", "Requires = { Level = 1, Feature = \"Market\" },"),
    ("switch: off still lists", X, "\tif not switchOn() then\n\t\tg.Buy, g.List = \"Off\", \"Off\"", "\tif false then\n\t\tg.Buy, g.List = \"Off\", \"Off\""),
    ("switch: off stops the payouts", X, "\t\t\tif persistent() then\n\t\t\t\tfor _, player in S.PlayerService.GetReadyPlayers() do",
     "\t\t\tif persistent() and switchOn() then\n\t\t\t\tfor _, player in S.PlayerService.GetReadyPlayers() do"),
    # review 10/14: the duplication races and the fixes
    ("BLOCK 1: no tombstone", X, "\t\t\twon = true\n\t\t\treturn { Id = id, Seller = uid, St = \"Cancel\", At = os.time(), Tomb = true }",
     "\t\t\twon = true\n\t\t\treturn nil"),
    ("BLOCK 1: give back before the ledger decides", X, "\t\tif not ok then return end -- tried again at the next round\n\t\tif won then\n\t\t\tgiveBack(player, data, id, row, \"Cancel\") -- never published",
     "\t\tgiveBack(player, data, id, row, \"Cancel\")\n\t\tif not ok then return end -- tried again at the next round\n\t\tif won then\n\t\t\tgiveBack(player, data, id, row, \"Cancel\") -- never published"),
    ("BLOCK 2: refund without the void", X, "\tif rec and rec.St == \"Open\" then\n\t\t-- review 10/14 BLOCK 2",
     "\tif false then\n\t\t-- review 10/14 BLOCK 2"),
    ("BLOCK 2: the buy write ignores a void", X, " and not (type(old.Void) == \"table\" and old.Void[tok]) then", " then"),
    ("BLOCK 2: no attempt token", X, "\tlocal row = { Price = total, St = \"Sold\", Pay = true, K = rec.K, N = n, Tok = tok }",
     "\tlocal row = { Price = total, St = \"Sold\", Pay = true, K = rec.K, N = n }"),
    ("FIX: cached ledger reads", X, "pcall(store.GetAsync, store, \"L_\" .. id, getOpts())", "pcall(store.GetAsync, store, \"L_\" .. id)"),
    ("FIX: the undo drops what does not fit", X,
     "\t\tlocal left = giveThing(player, data, key, n)\n\t\tif left > 0 then\n\t\t\trow.St, row.Pend, row.N, row.Ret = \"Cancel\", nil, left, true\n\t\telse\n\t\t\tm.Out[lid] = nil\n\t\tend",
     "\t\tgiveThing(player, data, key, n)\n\t\tm.Out[lid] = nil"),
    ("FIX: Pend is a new state again", C, "MarketStates = { Open = true, Sold = true, Cancel = true, Expired = true, Paid = true },",
     "MarketStates = { Open = true, Sold = true, Cancel = true, Expired = true, Paid = true, Pend = true, Pay = true },"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    main = read(SSS / "Main.server.luau")
    init = re.search(r"local INIT_ORDER = \{(.*?)\n\}", main, re.S)
    start = re.search(r"local START_ORDER = \{(.*?)\n\}", main, re.S)
    names = re.compile(r'"(\w+)"')
    init_list = names.findall(strip_comments(init.group(1))) if init else []
    start_list = names.findall(strip_comments(start.group(1))) if start else []
    check(init_list.count("MarketService") == 1 and start_list.count("MarketService") == 1, "MarketService is in both lists once")
    check(start_list[-1] == "PlayerService" and start_list.index("MarketService") < start_list.index("PlayerService")
          and init_list.index("MarketService") > init_list.index("LootService")
          and init_list.index("MarketService") > init_list.index("DataService"), "MarketService after DataService / LootService, before PlayerService")
    check(sorted(init_list) == sorted(start_list), "every service is in both lists")
    net = read(SHARED / "Net.luau")
    net_names = names.findall(strip_comments(net[net.find("Net.Names = {"):net.find("Net.GameStateDefaults")]))
    want = ("MarketIndex", "MarketBrowse", "MarketPage", "MarketMine", "MarketList", "MarketBuy", "MarketCancel", "PackWeapon", "UnpackSpare")
    check(all(net_names.count(n) == 1 for n in want), "Net.Names has the 9 market remotes once")
    window = read(ROOT / "src/StarterPlayer/StarterPlayerScripts/MarketWindow.luau")
    sends = re.search(r"Sends = \{([^}]*)\}", window)
    check(bool(sends) and set(names.findall(sends.group(1))) <= set(want), "every remote the window sends exists")
    hooks = set(re.findall(r'hook\("(\w+)"', window))
    check(hooks <= set(want), "every remote the window listens to exists")
    market = strip_comments(read(SSS / "MarketService.luau"))
    check("MemoryStoreService" in market and "UpdateAsync" in market and "DataService.Save" in market, "ledger + maps + the forced save")
    check("MonetizationService" not in market and "Robux" not in market, "no Robux path (stats never sold, A23-75)")
    check('"Market")' in market and '"MarketRefund")' in market and '"Monster"' not in market, "market gold sources Market / MarketRefund only")
    config = read(SHARED / "Config.luau")
    section = config[config.find("-- C-5 / C-7 the player market"):]
    check(bool(section) and not re.search(r"^local ", section, re.M), "the market section adds no top-level local (200-locals limit)")
    strings = re.findall(r'"([^"\n]*)"', strip_comments(section))
    check(not any(re.search("[가-힣]", s) for s in strings), "the market section's game text is English only")
    story = read(SSS / "StoryQuestService.luau")
    check("if req.Feature and not Config.FeatureOn(req.Feature) then return false end" in story,
          "StoryQuestService: Requires.Feature waits for the switch (the market quests)")
    doc = ROOT / "docs/design/market_server_2026-10-13.md"
    check(doc.is_file(), "the server design doc exists")
    return count, failures


SUITE = Suite(
    mark="MARKET",
    fixture=ROOT / "tools/fixtures/market_offline.luau",
    world=ROOT / "tools/fixtures/dev3_world.luau",
    out=ROOT / "docs/art/verification_2026-10-13/offline_dev2_market_2026-10-13.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="C-5 / C-7: one market for every server. Ledger DataStore 'L_<id>' { Id, Seller, K, N, Price (one unit), At, Exp, "
             "St, Buyer, SoldAt, Paid } = the truth; MemoryStore maps (key map sorted by price, index { L, C }, sold hints) "
             "only list. List: checks (A23-133 gates, 72 h, 10 open, 20 a day, range) -> things out, Out Pend -> SAVE -> ledger "
             "row only if none -> Open -> map. Buy: checks (Lv5, own, price, room, owned weapon, 3 a day per seller, gold) -> "
             "gold out, In Pay -> SAVE -> one UpdateAsync Open -> Sold + Buyer (an ended / sold row never) -> deliver, or "
             "refund 'MarketRefund'. The seller's server pays total - 10% as bank gold 'Market' once (Done / Paid row), then "
             "marks the ledger Paid after its save. Cancel / end -> things back (room checked, owed rows wait). The join "
             "check settles Pend / Pay / Sold / ended rows. Switch off: no new listing / purchase, settling goes on.",
    limitations="The market quests (A23-133: first buy / first list / first sale paid) hook MarketService.Listed / Bought / "
                "Paid in their own commit; telemetry events are not in yet. MemoryStore limits (memory, requests) are only "
                "modelled as errors; the real budget is checked in Studio with API access.",
)

if __name__ == "__main__":
    run(SUITE)
