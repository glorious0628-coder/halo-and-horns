"""Weapon tier 9 (Mythic) + save Version 4 + Spares / Market + LootService spares API (게임성 개발 2, C1, 2026-10-12), offline.

docs/design/save_v4_tables_2026-10-11.md (rules §1) and docs/design/craft_server_2026-10-12.md §6: Config.Weapons[9]
(Damage 2200, MinLevel 50, crafted only: never a drop, jackpot, Forge sale or commission), WeaponGrades.Mythic (Rank 6),
the Crownforged names appended for every class + the tamer, WeaponInfo[9]; Config.Data.Version = Defaults.Version = 4;
DataService migrate's v4 step (a v3 / older record's tier 9 / bit 9 = corruption, a v4 9-bit mask is valid, bit 10 =
corruption); Config.SanitizeSpares / SanitizeMarket through Config.SanitizeSaveV4; LootService.SpareRoom / AddSpare (key
cap 20, total 60, Spares in the Inventory payload) and LootService's own repair keeping Spares / Market. Runs the CURRENT
Config, Util and LootService plus DataService's migrate / fillDefaults with the installed official Luau CLI. No Studio,
network, DataStore or Roblox API calls; mutations run on in-memory copies of the sources.

Usage: py tools/test_weapon_ladder.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-12/offline_dev2_weapon_ladder_2026-10-12.json
"""
from __future__ import annotations

import re

from dev2_offline import ROOT, SHARED, SSS, Suite, function_block, read, run, strip_comments

FILES = {
    "CONFIG_SOURCE": SHARED / "Config.luau",
    "UTIL_SOURCE": SHARED / "Util.luau",
    "LOOT_SOURCE": SSS / "LootService.luau",
    "DATA_SOURCE": SSS / "DataService.luau",
}
C, L, D = "CONFIG_SOURCE", "LOOT_SOURCE", "DATA_SOURCE"


def bindings(sources: dict[str, str]) -> dict[str, str]:
    out = {k: sources[k] for k in ("CONFIG_SOURCE", "UTIL_SOURCE", "LOOT_SOURCE")}
    data = sources[D]
    out["DATA_EXTRACT"] = (
        "local Config, Util, TAG, TUTORIAL_DONE = ...\n"
        + function_block(data, "local function migrate(")
        + function_block(data, "local function fillDefaults(")
        + "\nreturn { Migrate = migrate, Fill = fillDefaults }\n")
    return out


MUTATIONS = [
    # --- the ladder
    ("config: T9 usable from Lv1", C, "{ Tier = 9, Damage = 2200, Price = 250000, MinLevel = 50,",
     "{ Tier = 9, Damage = 2200, Price = 250000, MinLevel = 1,"),
    ("config: T9 damage 220", C, "{ Tier = 9, Damage = 2200,", "{ Tier = 9, Damage = 220,"),
    ("config: Mythic ranks like Legend", C, "Stars = 6, Color = Color3.fromRGB(255, 70, 130), Rank = 6 }",
     "Stars = 6, Color = Color3.fromRGB(255, 70, 130), Rank = 5 }"),
    ("config: WeaponInfo[9] graded Legend", C, "{ Grade = \"Mythic\", Source = \"Crafted by artisans\" }",
     "{ Grade = \"Legend\", Source = \"Crafted by artisans\" }"),
    ("config: no tier-9 baton name", C, "\"Jelly Crown Baton\", \"Crownforged Baton\" }", "\"Jelly Crown Baton\" }"),
    ("config: T9 dropped by Captain Clatter", C, "{ Item = \"ClatterGem\", P = 0.1 },",
     "{ Item = \"ClatterGem\", P = 0.1 }, { Weapon = 9, P = 0.001 },"),
    ("config: the Forge sells up to T9", C, "Config.WeaponShop = { MaxSoldTier = 3,", "Config.WeaponShop = { MaxSoldTier = 9,"),
    # --- Version 4
    ("migrate: a v3 bit 9 wipes the whole mask", D, "\t\t\td.WeaponOwnedMask = bit32.band(m, bit32.lshift(1, oldTiers) - 1)\n",
     "\t\t\td.WeaponOwnedMask = -1\n"),
    ("config: the version back to 3", C, "so it must refuse v6 records (CR-L3)\n\tVersion = 6,",
     "so it must refuse v6 records (CR-L3)\n\tVersion = 3,"),
    ("config: the default record's version 3", C, "\tDefaults = {\n\t\tVersion = 6,", "\tDefaults = {\n\t\tVersion = 3,"),
    ("DataService: no v4 step", D, "\tif (tonumber(d.Version) or 1) < 4 then\n", "\tif false then\n"),
    ("DataService: the old steps follow MaxWeaponTier", D, "\tlocal oldTiers = 8\n", "\tlocal oldTiers = Config.MaxWeaponTier\n"),
    ("DataService: a v3 tier 9 trusted", D,
     "\t\tif type(d.WeaponTier) == \"number\" and d.WeaponTier > oldTiers then d.WeaponTier = -1 end\n", ""),
    ("DataService: a v3 bit 9 trusted", D,
     "\t\tif type(m) == \"number\" and m == math.floor(m) and m >= bit32.lshift(1, oldTiers) and m < 2 ^ 31 then\n", "\t\tif false then\n"),
    ("DataService: the repair keeps 8 bits", D, "local validMask = bit32.lshift(1, Config.MaxWeaponTier) - 1",
     "local validMask = bit32.lshift(1, 8) - 1"),
    ("DataService: the repair keeps tiers 0..8", D, "or weaponTier > Config.MaxWeaponTier then", "or weaponTier > 8 then"),
    ("DataService: bit 12 kept (A23-186: 11 tiers)", D, "local validMask = bit32.lshift(1, Config.MaxWeaponTier) - 1",
     "local validMask = bit32.lshift(1, Config.MaxWeaponTier + 1) - 1"),
    # --- Spares repair
    ("spares: no per-key cap", C, "\t\tlocal n = V4.int(t[k], 0, L.SpareKeyMax)\n", "\t\tlocal n = V4.int(t[k], 0, math.huge)\n"),
    ("spares: a merged key over 20", C, "\t\t\t\tout[key] = math.min(L.SpareKeyMax, out[key] + n)\n", "\t\t\t\tout[key] += n\n"),
    ("spares: a later key replaces the earlier", C, "\t\t\t\tout[key] = math.min(L.SpareKeyMax, out[key] + n)\n", "\t\t\t\tout[key] = n\n"),
    ("spares: tier 0 kept", C, "t < 1 or t > Config.SaveV4.SpareTierMax", "t < 0 or t > Config.SaveV4.SpareTierMax"),
    ("spares: no tier ceiling", C, "t < 1 or t > Config.SaveV4.SpareTierMax or p", "t < 1 or p"),
    ("spares: no plus cap", C, "Config.SaveV4.SpareTierMax or p > Config.Loot.MaxEnhance then", "Config.SaveV4.SpareTierMax then"),
    ("spares: keys kept as written", C, "return string.format(\"%d:%d\", t, p) -- \"04:0\" -> \"4:0\"", "return s"),
    ("spares: never cut at 64 keys", C, "elseif kept < L.MaxKeys then -- a new key", "else"),
    ("spares: 0 counts kept", C, "\t\tif key and n and n > 0 then\n", "\t\tif key and n then\n"),
    ("spares: the load skips Spares", C, "\td.Spares = Config.SanitizeSpares(d.Spares)\n", ""),
    # --- Market repair
    ("market: any St kept", C, "L.MarketStates[r.St] == true", "true"),
    ("market: N without the cap", C, "V4.int(r.N, 0, L.MarketMaxN)", "V4.int(r.N, 0, math.huge)"),
    ("market: N 0 kept", C, "if not (k and n and n >= 1 and p and st) then return nil end", "if not (k and n and p and st) then return nil end"),
    ("market: Price 0 kept", C, "(p and p >= 1) and p or nil", "(p and p >= 0) and p or nil"),
    ("market: no id length cap", C, "#k >= 1 and #k <= Config.SaveV4.MarketIdLen", "#k >= 1"),
    ("market: rows never cut", C, "if r and kept < Config.SaveV4.MarketRows then", "if r then"),
    ("market: Done keeps the oldest", C, "for i = math.max(1, #ids - L.MarketDone + 1), #ids do", "for i = 1, math.min(#ids, L.MarketDone) do"),
    ("market: Done keeps duplicates", C, "if V4.marketId(id) and not seen[id] then", "if V4.marketId(id) then"),
    ("market: any item key", C, "if string.match(k, \"^I:[%w_]+$\") then return k end", "if string.sub(k, 1, 2) == \"I:\" then return k end"),
    ("market: weapon keys kept as written", C, "return tp and (\"W:\" .. tp) or nil", "return tp and k or nil"),
    ("market: negative counters", C, "out[k] = V4.int(src[k], 0, L.MaxCount) or 0", "out[k] = V4.int(src[k], -math.huge, L.MaxCount) or 0"),
    ("market: unknown keys dropped", C,
     "\treturn V4.keepExtra(src, out, { Out = true, In = true, Done = true, Day = true, Lists = true, Buys = true })",
     "\treturn out"),
    ("market: the load skips Market", C, "\td.Market = Config.SanitizeMarket(d.Market)\n", ""),
    # --- LootService spares API
    ("loot: any number is a tier", L, "\tif not validTier(tier) then return nil end\n\tif type(plus)",
     "\tif type(tier) ~= \"number\" then return nil end\n\tif type(plus)"),
    ("loot: a fractional plus", L, "plus ~= plus or plus ~= math.floor(plus) or plus < 0", "plus ~= plus or plus < 0"),
    ("loot: no plus cap", L, "or plus < 0 or plus > LOOT.MaxEnhance then return nil end", "or plus < 0 then return nil end"),
    ("loot: 21 of one key", L, "math.floor(num(spares[key])) < Config.SaveV4.SpareKeyMax", "math.floor(num(spares[key])) <= Config.SaveV4.SpareKeyMax"),
    ("loot: no total cap", L, "and sum < Config.SaveV4.SpareSum", "and true"),
    ("loot: AddSpare skips the room check", L, "if not data or not spareFits(data, key) then return false end", "if not data then return false end"),
    ("loot: AddSpare adds 2", L, "not spareFits(data, key) then return false end\n\tif type(data.Spares) ~= \"table\" then data.Spares = {} end\n\tdata.Spares[key] = math.max(0, math.floor(num(data.Spares[key]))) + 1",
     "not spareFits(data, key) then return false end\n\tif type(data.Spares) ~= \"table\" then data.Spares = {} end\n\tdata.Spares[key] = math.max(0, math.floor(num(data.Spares[key]))) + 2"),
    ("loot: AddSpare not published", L, "not spareFits(data, key) then return false end\n\tif type(data.Spares) ~= \"table\" then data.Spares = {} end\n\tdata.Spares[key] = math.max(0, math.floor(num(data.Spares[key]))) + 1\n\tpublish(player, data)\n",
     "not spareFits(data, key) then return false end\n\tif type(data.Spares) ~= \"table\" then data.Spares = {} end\n\tdata.Spares[key] = math.max(0, math.floor(num(data.Spares[key]))) + 1\n"),
    ("loot: payload without Spares", L, "WeaponSeq = weaponSeq, Spares = spares }", "WeaponSeq = weaponSeq }"),
    ("loot: sanitize drops Spares / Market", L, "\tdata.Items = items\n", "\tdata.Items = items\n\tdata.Spares, data.Market = nil, nil\n"),
    ("loot: sanitize keeps 8 enhance tiers", L,
     "\tfor tier = 1, Config.MaxWeaponTier do\n\t\tenh[tier] = math.clamp(math.floor(num(old[tier])), 0, LOOT.MaxEnhance)",
     "\tfor tier = 1, 8 do\n\t\tenh[tier] = math.clamp(math.floor(num(old[tier])), 0, LOOT.MaxEnhance)"),
]


def static() -> tuple[int, list[str]]:
    count, failures = 0, []

    def check(ok: bool, name: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(name)

    config = read(SHARED / "Config.luau")
    top_locals = len(re.findall(r"^local ", config, re.M))
    check(top_locals < 190, f"Config's top chunk stays well under 200 locals ({top_locals})")
    data_block = re.search(r"^Config\.Data = \{(.*?)^\}", config, re.M | re.S)
    versions = re.findall(r"^\t{1,2}Version = (\d+),", data_block.group(1), re.M) if data_block else []
    check(versions == ["6", "6"], f"Config.Data.Version and Defaults.Version are both 6 (A23-186; A23-153 made it 5, C1 4) ({versions})")
    check("Config.WeaponShop = { MaxSoldTier = 3," in config, "the Forge's MaxSoldTier stays 3")
    data = read(SSS / "DataService.luau")
    mig = function_block(data, "local function migrate(")
    check("\tlocal oldTiers = 8\n" in mig and "Config.MaxWeaponTier" not in strip_comments(mig),
          "DataService migrate: the old steps are pinned to 8 tiers (no Config.MaxWeaponTier in migrate's code)")
    loot = read(SSS / "LootService.luau")
    add = function_block(loot, "function LootService.AddSpare(")
    check("notify(" not in strip_comments(add) and "Net.Notify" not in add, "AddSpare says nothing (the caller does)")
    craft = read(SSS / "CraftService.luau")
    check("pcall(S.LootService.SpareRoom, player, r.Tier, plus)" in craft and "pcall(S.LootService.AddSpare, player, r.Tier, plus)" in craft,
          "CraftService calls SpareRoom / AddSpare through pcall (the API it needs)")
    return count, failures


SUITE = Suite(
    mark="LADDER",
    fixture=ROOT / "tools/fixtures/weapon_ladder_offline.luau",
    out=ROOT / "docs/art/verification_2026-10-12/offline_dev2_weapon_ladder_2026-10-12.json",
    files=FILES, bindings=bindings, mutations=MUTATIONS, static=static,
    contract="C1 (게임성 개발 2): Config.Weapons[9] = Damage 2200 / MinLevel 50 / Price 250000 (a value), never a drop row, the "
             "jackpot (tier 8), a Forge sale (MaxSoldTier 3) or a commission; tiers 1-8 numbers, grades and names frozen; "
             "WeaponGrades.Mythic { Stars 6, Rank 6 } above Legend; 'Crownforged Sword / Staff / Bow / Baton' appended; "
             "WeaponInfo[9] = Mythic, 'Crafted by artisans'. Config.Data.Version = Defaults.Version = 4; DataService migrate: "
             "v1 / v2 steps pinned to 8 tiers, the v4 step marks an older record's tier > 8 / bit > 8 corrupted (fillDefaults' "
             "usual repair) and sets Version 4; a v4 9-bit mask / tier 9 / WeaponEnhance[9] kept, bit 10 / tier 10 = "
             "corrupted. Config.SanitizeSpares: 'T:P' (T 1..32, P 0..10) written plainly and merged, n 1..20, 64 keys "
             "(sorted), the total 60 not cut. Config.SanitizeMarket: Out { K 'I:<id>' | 'W:T:P', N 1..999, Price "
             "1..MaxCount, St Open/Sold/Cancel/Expired/Paid }, In { Price, St }, ids 1..40 chars, 64 rows each (sorted), "
             "Done = the newest 50 unique ids, Day / Lists / Buys >= 0, sane unknown flat keys kept, idempotent; both run "
             "in Config.SanitizeSaveV4. LootService.SpareRoom / AddSpare(player, tier 1..MaxWeaponTier, plus 0..MaxEnhance): "
             "room = key < 20 and total < 60; AddSpare adds 1 and publishes the Inventory (Spares added to the payload), "
             "false changes nothing, no notice; LootService's own repair keeps Spares / Market.",
    limitations="Numbers like fractions are floored (the V4 helper's rule), not dropped. The CR-L3 refusal of a newer record "
                "(Version 5) by the real DataStore load is in tools/test_onboarding.py; CraftService's use of the API is in "
                "tools/test_craft.py. No MarketService exists yet (only the saved shape). Client display of tier 9 / Spares "
                "is 게임성 개발 1's.",
)

if __name__ == "__main__":
    run(SUITE)
