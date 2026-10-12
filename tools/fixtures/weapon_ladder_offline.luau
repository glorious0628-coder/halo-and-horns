-- weapon_ladder_offline.luau : C1 (게임성 개발 2, 2026-10-12) - weapon tier 9 (Mythic, crafted only), save Version 4,
-- Spares / Market repairs (Config.SanitizeSpares / SanitizeMarket, docs/design/save_v4_tables_2026-10-11.md) and
-- LootService.SpareRoom / AddSpare. tools/test_weapon_ladder.py binds CONFIG_SOURCE, UTIL_SOURCE, LOOT_SOURCE and
-- DATA_EXTRACT (DataService migrate / fillDefaults); dev2_kit.luau comes first.

local NAN, INF = 0 / 0, math.huge

local function cfg()
	return execute("Config", CONFIG_SOURCE, nativeEnv())
end

local function sameTable(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not sameTable(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

------------------------------------------------------------------ tier 9 = Mythic, tiers 1-8 frozen
runGroup("ladder", function()
	local C = cfg()
	check(C.MaxWeaponTier == 9 and #C.Weapons == 9, "9 weapon tiers (Config.MaxWeaponTier = #Config.Weapons)", C.MaxWeaponTier)
	local w9 = C.Weapons[9]
	check(w9 and w9.Tier == 9 and w9.Damage == 2200 and w9.MinLevel == 50 and w9.Price == 250000 and w9.Legend == nil
		and w9.RequiresFaction == nil and w9.Color ~= nil, "T9: Damage 2200, MinLevel 50, Price 250000 (a value only), no faction gate",
		show(w9 and { w9.Damage, w9.MinLevel, w9.Price }))
	-- tiers 1-8 as they are on origin/main (Damage, Price, MinLevel)
	local FROZEN = { { 8, 0, 1 }, { 15, 150, 1 }, { 38, 800, 5 }, { 88, 3000, 12 }, { 200, 10000, 20 }, { 450, 30000, 30 },
		{ 1000, 90000, 40 }, { 76, 0, 1 } }
	for t, f in FROZEN do
		local w = C.Weapons[t]
		check(w and w.Tier == t and w.Damage == f[1] and w.Price == f[2] and w.MinLevel == f[3], "tiers 1-8 keep their numbers", t)
	end
	check(C.Weapons[8].Legend == true and C.Weapons[7].RequiresFaction == true, "T8 stays the legendary, T7 the faction weapon", "")
	local G = C.WeaponGrades
	check(G.Mythic and G.Mythic.Name == "Mythic" and G.Mythic.Stars == 6 and G.Mythic.Rank == 6 and G.Mythic.Color ~= nil,
		"WeaponGrades.Mythic = { Name Mythic, Stars 6, Rank 6, a colour }", show(G.Mythic))
	local top = 0
	for id, g in G do if id ~= "Mythic" then top = math.max(top, g.Rank, g.Stars) end end
	check(G.Mythic.Rank > top and G.Mythic.Stars > G.Legend.Stars, "Mythic ranks above every other grade (Legend 5)", top)
	check(C.WeaponInfo[9] and C.WeaponInfo[9].Grade == "Mythic" and C.WeaponInfo[9].Source == "Crafted by artisans"
		and C.WeaponGrade(9).Name == "Mythic" and C.WeaponStars(9) == string.rep("★", 6), "WeaponInfo[9] = Mythic, 'Crafted by artisans'",
		show(C.WeaponInfo[9]))
	local GRADES = { "Common", "Common", "Fine", "Rare", "Epic", "Epic", "Legend", "Legend" }
	for t, g in GRADES do
		check(C.WeaponInfo[t].Grade == g, "tiers 1-8 keep their grades", t)
	end
	-- names: appended at the end only, every class + the tamer's batons; tiers 1-8 as on origin/main
	local NAMES = {
		Warrior = { "Twig", "Wooden Sword", "Iron Sword", "Goblin Thief's Golden Sword", "Old Kingdom Crystal Sword", "Guardian Spirit Sword",
			{ Halo = "Dawn Sword", Horns = "Ruin Sword", None = "Crown Shard Sword" }, "Jelly Crown Sword", "Crownforged Sword" },
		Mage = { "Dry Staff", "Oak Staff", "Iron Staff", "Goblin Thief's Golden Staff", "Old Kingdom Crystal Staff", "Guardian Spirit Staff",
			{ Halo = "Dawn Staff", Horns = "Ruin Staff", None = "Crown Shard Staff" }, "Jelly Crown Staff", "Crownforged Staff" },
		Archer = { "Slingshot Bow", "Wooden Bow", "Iron Bow", "Goblin Thief's Golden Bow", "Old Kingdom Crystal Bow", "Guardian Spirit Bow",
			{ Halo = "Dawn Bow", Horns = "Ruin Bow", None = "Crown Shard Bow" }, "Jelly Crown Bow", "Crownforged Bow" },
		Tamer = { "Twig Baton", "Wooden Baton", "Iron Baton", "Goblin Thief's Golden Baton", "Old Kingdom Crystal Baton",
			"Guardian Spirit Baton", { Halo = "Dawn Baton", Horns = "Ruin Baton", None = "Crown Shard Baton" }, "Jelly Crown Baton",
			"Crownforged Baton" },
	}
	for class, want in NAMES do
		check(sameTable(C.WeaponNames[class], want) and #C.WeaponNames[class] == 9, "names: tiers 1-8 frozen, tier 9 Crownforged (" .. class .. ")",
			show(C.WeaponNames[class][9]))
	end
	check(C.WeaponName(9, "Warrior", "Halo") == "Crownforged Sword" and C.WeaponName(9, "Mage", "Horns") == "Crownforged Staff"
		and C.WeaponName(9, "Archer", "Halo") == "Crownforged Bow" and C.WeaponName(9, "Archer", "Neutral") == "Crownforged Baton",
		"WeaponName(9, ...) per class (the Neutral archer = the tamer's baton)", "")
	-- never dropped / jackpot / sold / commissioned
	local dropped = {}
	for kind, rows in C.Loot.Tables do
		for _, row in rows do
			if row.Weapon == 9 or (type(row.BelowLevel) == "table" and row.BelowLevel.Weapon == 9) then table.insert(dropped, kind) end
		end
	end
	check(#dropped == 0 and C.Loot.Jackpot.Tier == 8, "T9 is never a drop row and never the jackpot", show(dropped))
	check(C.WeaponShop.MaxSoldTier == 3, "the Forge still sells tiers 2-3 only (MaxSoldTier 3)", C.WeaponShop.MaxSoldTier)
	check(C.Commission.Orders[9] == nil and C.Loot.DuplicateWeaponGold[9] == nil, "T9 is no commission order and has no duplicate-drop gold", "")
	check(C.WeaponUsable(9, 50) and not C.WeaponUsable(9, 49) and not C.WeaponUsable(10, 100), "T9 usable from Lv50; tier 10 does not exist", "")
	check(C.BestUsableWeapon(511, 100) == 9 and C.BestUsableWeapon(511, 49) == 7 and C.BestUsableWeapon(255, 100) == 7,
		"BestUsableWeapon: T9 at Lv100, T7 below Lv50, 8-bit masks unchanged", "")
end)

------------------------------------------------------------------ save Version 4: the real load path
runGroup("load", function()
	local w = newWorld({})
	local C = w.Config
	local DS = execute("DataService.extract", DATA_EXTRACT, w:Env(), C, w.Util, "DataService", 99)
	local function load(rec)
		local d = deepCopy(rec)
		DS.Migrate(d, { Name = "P1" })
		DS.Fill(d, "P1")
		return d
	end
	local function row(version, fields)
		local r = { Version = version, Level = 60, Faction = "Halo", Class = "Warrior", ClassChosen = true, TutorialStep = 99 }
		for k, v in fields or {} do r[k] = v end
		return r
	end
	check(C.Data.Version == 4 and C.Data.Defaults.Version == 4, "Config.Data.Version = Defaults.Version = 4", show({ C.Data.Version, C.Data.Defaults.Version }))
	local enh = { 1, 2, 3, 4, 5, 6, 7, 8 }
	local v3 = load(row(3, { WeaponTier = 7, WeaponOwnedMask = 255, WeaponEnhance = deepCopy(enh), BankGold = 500, Items = { Jelly = 3 } }))
	check(v3.Version == 4 and v3.WeaponTier == 7 and v3.WeaponOwnedMask == 255 and sameTable(v3.WeaponEnhance, enh) and v3.BankGold == 500
		and v3.Items.Jelly == 3, "a v3 record loads as v4 with its weapons, mask, +N and the rest kept", show({ v3.Version, v3.WeaponTier, v3.WeaponOwnedMask }))
	check(sameTable(v3.Spares, {}) and sameTable(v3.Market, C.Data.Defaults.Market), "the v3 record gains Spares {} and the default Market", show(v3.Market))
	check(sameTable(load(v3), v3), "loading it again changes nothing (idempotent)", "")
	-- a v3 record was written by an 8-tier server: its bit 9 / tier 9 is corruption (never a free Mythic)
	local bit9 = load(row(3, { WeaponTier = 3, WeaponOwnedMask = 256 + 7 }))
	check(bit9.WeaponOwnedMask == 4 and bit9.WeaponTier == 3, "v3: a mask with bit 9 is corrupted -> the equipped bit only", show({ bit9.WeaponOwnedMask }))
	local t9 = load(row(3, { WeaponTier = 9, WeaponOwnedMask = 7 }))
	check(t9.WeaponTier == 3 and t9.WeaponOwnedMask == 7, "v3: tier 9 equipped is corrupted -> the best usable owned weapon", show({ t9.WeaponTier, t9.WeaponOwnedMask }))
	local old = load(row(2, { WeaponTier = 9, WeaponOwnedMask = 256 + 2 }))
	check(old.Version == 4 and old.WeaponTier == 1 and old.WeaponOwnedMask == 1, "v2: tier 9 / bit 9 -> its tier 1 (the old step stays pinned to 8)",
		show({ old.WeaponTier, old.WeaponOwnedMask }))
	-- v4: the 9-bit mask is valid, the 10th bit is corruption
	local v4 = load(row(4, { WeaponTier = 9, WeaponOwnedMask = 511, WeaponEnhance = { 0, 0, 0, 0, 0, 0, 0, 0, 7 } }))
	check(v4.WeaponTier == 9 and v4.WeaponOwnedMask == 511 and v4.WeaponEnhance[9] == 7, "v4: tier 9, mask 511 and WeaponEnhance[9] kept",
		show({ v4.WeaponTier, v4.WeaponOwnedMask }))
	local low9 = load(row(4, { Level = 40, WeaponTier = 9, WeaponOwnedMask = 256 + 64 }))
	check(low9.WeaponTier == 9 and low9.WeaponOwnedMask == 320, "v4: a stored tier 9 is a valid tier (the level fit is LootService's)",
		show({ low9.WeaponTier, low9.WeaponOwnedMask }))
	local keep9 = load(row(4, { WeaponTier = 2, WeaponOwnedMask = 256 + 2 }))
	check(keep9.WeaponOwnedMask == 258, "v4: a mask with bit 9 is kept", keep9.WeaponOwnedMask)
	local bit10 = load(row(4, { WeaponTier = 2, WeaponOwnedMask = 512 + 2 }))
	check(bit10.WeaponOwnedMask == 2 and bit10.WeaponTier == 2, "v4: bit 10 = corrupted -> the equipped bit only (the existing repair)", bit10.WeaponOwnedMask)
	local t10 = load(row(4, { WeaponTier = 10, WeaponOwnedMask = 256 + 4 }))
	check(t10.WeaponTier == 9 and t10.WeaponOwnedMask == 260, "v4: tier 10 = corrupted -> the best usable owned (T9 at Lv60)", show({ t10.WeaponTier }))
	-- the v4 tables go through their repairs on load
	local bad = load(row(4, { Spares = { ["04:0"] = 3, ["4:0"] = 2, ["0:1"] = 5 }, Market = { Out = { a = { K = "I:Jelly", N = 2, Price = 10, St = "Weird" } },
		Done = { "x", "x" }, Day = -3 } }))
	check(sameTable(bad.Spares, { ["4:0"] = 5 }) and next(bad.Market.Out) == nil and sameTable(bad.Market.Done, { "x" }) and bad.Market.Day == 0,
		"the load repairs Spares / Market (Config.SanitizeSaveV4)", show({ bad.Spares, bad.Market }))
	local wrong = load(row(4, { Spares = "x", Market = 5 }))
	check(sameTable(wrong.Spares, {}) and sameTable(wrong.Market, C.Data.Defaults.Market), "a Spares / Market of the wrong type becomes its default", "")
	w.AllowWarn = { "field Spares had type string", "field Market had type number" }
	local fresh = load(deepCopy(C.Data.Defaults))
	check(fresh.Version == 4 and sameTable(fresh.Spares, {}) and sameTable(fresh.Market, { Out = {}, In = {}, Done = {}, Day = 0, Lists = 0, Buys = 0 }),
		"a brand-new save is v4 with Spares {} and Market { Out, In, Done, Day, Lists, Buys }", show(fresh.Market))
end)

------------------------------------------------------------------ Config.SanitizeSpares
runGroup("spares", function()
	local C = cfg()
	local S = C.SanitizeSpares
	local L = C.SaveV4
	check(L.SpareTierMax == 32 and L.SpareKeyMax == 20 and L.SpareSum == 60 and L.MarketRows == 64 and L.MarketDone == 50
		and L.MarketIdLen == 40 and L.MarketMaxN == 999, "caps: tiers 1..32, 20 a key, 60 in all, 64 market rows, 50 done ids, ids 40, N 999", "")
	check(sameTable(S(nil), {}) and sameTable(S("x"), {}) and sameTable(S(5), {}), "not a table -> {}", "")
	check(sameTable(S({ ["9:2"] = 3, ["1:0"] = 1 }), { ["9:2"] = 3, ["1:0"] = 1 }), "good keys come back as they were", "")
	check(sameTable(S({ ["04:0"] = 3, ["4:0"] = 5 }), { ["4:0"] = 8 }), "'04:0' and '4:0' merge into '4:0'", show(S({ ["04:0"] = 3, ["4:0"] = 5 })))
	check(sameTable(S({ ["04:0"] = 15, ["4:0"] = 15 }), { ["4:0"] = 20 }), "a merged key is cut at 20", "")
	check(sameTable(S({ ["9:2"] = 25 }), { ["9:2"] = 20 }), "a count above 20 is cut at 20", "")
	check(sameTable(S({ ["32:0"] = 2, ["10:10"] = 1 }), { ["32:0"] = 2, ["10:10"] = 1 }), "a later tier (up to 32) and +10 are kept", "")
	local junk = { ["33:0"] = 1, ["0:0"] = 1, ["1:11"] = 1, ["1.5:0"] = 1, ["a:0"] = 1, ["1:0:0"] = 1, ["-1:0"] = 1, ["1:"] = 1,
		[":1"] = 1, ["1234567890123:0"] = 1, [5] = 1, [true] = 1 }
	check(sameTable(S(junk), {}), "bad keys dropped (tier 0 / 33, plus 11, fractions, letters, extra parts, long, not strings)", show(S(junk)))
	local vals = S({ ["1:0"] = NAN, ["2:0"] = INF, ["3:0"] = -INF, ["4:0"] = -1, ["5:0"] = 0, ["6:0"] = "3", ["7:0"] = 1.7, ["8:0"] = {} })
	check(sameTable(vals, { ["7:0"] = 1 }), "NaN / inf / negative / 0 / text / table counts drop the key; 1.7 -> 1", show(vals))
	local many = {}
	for t = 1, 7 do for p = 0, 9 do many[string.format("%d:%d", t, p)] = 1 end end
	local keys = {}
	for k in many do table.insert(keys, k) end
	table.sort(keys)
	local cut = S(many)
	local first64 = true
	for i, k in keys do if (cut[k] ~= nil) ~= (i <= 64) then first64 = false end end
	check(count(cut) == 64 and first64, "70 keys -> the first 64 in sorted order (MaxKeys)", count(cut))
	local over = S({ ["1:0"] = 20, ["2:0"] = 20, ["3:0"] = 20, ["4:0"] = 20 })
	check(count(over) == 4 and over["4:0"] == 20, "the total 60 is not cut by the repair (the writers refuse)", show(over))
	local x = S({ ["04:0"] = 3, ["4:0"] = 25, ["x"] = 1, ["9:1"] = 2.5 })
	check(sameTable(S(x), x), "repairing twice = once", show(x))
end)

------------------------------------------------------------------ Config.SanitizeMarket
runGroup("market", function()
	local C = cfg()
	local M = C.SanitizeMarket
	local D = { Out = {}, In = {}, Done = {}, Day = 0, Lists = 0, Buys = 0 }
	check(sameTable(M(nil), D) and sameTable(M("x"), D), "not a table -> the default", show(M(nil)))
	local good = { Out = { r1 = { K = "I:Jelly", N = 5, Price = 100, St = "Open" }, r2 = { K = "W:9:2", N = 1, Price = 250000, St = "Sold" } },
		In = { b1 = { Price = 40, St = "Paid" } }, Done = { "r0", "b0" }, Day = 20700, Lists = 3, Buys = 1 }
	check(sameTable(M(good), good), "good rows come back as they were", show(M(good)))
	for _, st in { "Open", "Sold", "Cancel", "Expired", "Paid" } do
		check(M({ Out = { a = { K = "I:Jelly", N = 1, Price = 1, St = st } } }).Out.a ~= nil, "every known St is kept", st)
	end
	local rows = M({ Out = {
		st = { K = "I:Jelly", N = 1, Price = 1, St = "open" }, nost = { K = "I:Jelly", N = 1, Price = 1 },
		k0 = { K = "Jelly", N = 1, Price = 1, St = "Open" }, k1 = { K = "I:", N = 1, Price = 1, St = "Open" },
		k2 = { K = "I:a b", N = 1, Price = 1, St = "Open" }, k3 = { K = "W:0:1", N = 1, Price = 1, St = "Open" },
		k4 = { K = "W:9:11", N = 1, Price = 1, St = "Open" }, k5 = { K = "I:" .. string.rep("x", 39), N = 1, Price = 1, St = "Open" },
		k6 = { K = 7, N = 1, Price = 1, St = "Open" },
		n0 = { K = "I:Jelly", N = 0, Price = 1, St = "Open" }, n1 = { K = "I:Jelly", N = NAN, Price = 1, St = "Open" },
		n2 = { K = "I:Jelly", N = -2, Price = 1, St = "Open" }, n3 = { K = "I:Jelly", N = INF, Price = 1, St = "Open" },
		p0 = { K = "I:Jelly", N = 1, Price = 0, St = "Open" }, p1 = { K = "I:Jelly", N = 1, Price = NAN, St = "Open" },
		p2 = { K = "I:Jelly", N = 1, Price = -5, St = "Open" }, p3 = { K = "I:Jelly", N = 1, Price = "10", St = "Open" },
		p4 = { K = "I:Jelly", N = 1, Price = INF, St = "Open" }, t = "row",
	} })
	check(next(rows.Out) == nil, "a row with an unknown St, a bad K, a bad N or a bad Price is dropped (never made up)", show(rows.Out))
	local fix = M({ Out = { a = { K = "W:09:2", N = 1500, Price = 10.5, St = "Open" }, b = { K = "I:Jelly", N = 1.9, Price = 1e12, St = "Open" } },
		In = { c = { Price = 7.9, St = "Cancel" }, d = { Price = 0, St = "Open" }, e = { Price = 5, St = "Gone" } } })
	check(sameTable(fix.Out.a, { K = "W:9:2", N = 999, Price = 10, St = "Open" }) and fix.Out.b.N == 1 and fix.Out.b.Price == C.SaveV4.MaxCount,
		"K written plainly, N cut at 999, fractions floored, Price cut at MaxCount", show(fix.Out))
	check(sameTable(fix.In, { c = { Price = 7, St = "Cancel" } }), "In rows: Price 1..MaxCount and a known St, the rest dropped", show(fix.In))
	local ids = M({ Out = { [string.rep("i", 40)] = { K = "I:Jelly", N = 1, Price = 1, St = "Open" },
		[string.rep("j", 41)] = { K = "I:Jelly", N = 1, Price = 1, St = "Open" }, [""] = { K = "I:Jelly", N = 1, Price = 1, St = "Open" },
		[5] = { K = "I:Jelly", N = 1, Price = 1, St = "Open" } } })
	check(count(ids.Out) == 1 and ids.Out[string.rep("i", 40)] ~= nil, "row ids are strings of 1..40 characters", count(ids.Out))
	local out = {}
	for i = 1, 70 do out[string.format("r%02d", i)] = { K = "I:Jelly", N = 1, Price = i, St = "Open" } end
	local cut = M({ Out = out, In = deepCopy(out) })
	check(count(cut.Out) == 64 and cut.Out.r64 ~= nil and cut.Out.r65 == nil and count(cut.In) == 64 and cut.In.r01 ~= nil,
		"at most 64 rows in Out and In each (the first ids in sorted order)", count(cut.Out))
	local done = {}
	for i = 1, 60 do table.insert(done, "d" .. i) end
	table.insert(done, "d5")
	table.insert(done, 12)
	table.insert(done, string.rep("z", 41))
	local dn = M({ Done = done }).Done
	check(#dn == 50 and dn[1] == "d11" and dn[50] == "d60", "Done keeps the newest 50 sane unique ids (the list end)", show({ #dn, dn[1], dn[50] }))
	local nums = M({ Day = NAN, Lists = -2, Buys = 3.7 })
	check(nums.Day == 0 and nums.Lists == 0 and nums.Buys == 3, "Day / Lists / Buys: whole numbers >= 0 (NaN / negative -> 0)", show(nums))
	local extra = M({ Later = true, Tbl = { 1 }, Out = { a = { K = "I:Jelly", N = 1, Price = 1, St = "Open", Seller = 9, Junk = {} } } })
	check(extra.Later == true and extra.Tbl == nil and extra.Out.a.Seller == 9 and extra.Out.a.Junk == nil,
		"a sane unknown flat key is kept (a later field), tables are not", show(extra))
	local twice = M({ Out = { a = { K = "W:09:2", N = 1500, Price = 10.5, St = "Open" } }, Done = done, Day = 4.5 })
	check(sameTable(M(twice), twice), "repairing twice = once", "")
end)

------------------------------------------------------------------ LootService.SpareRoom / AddSpare
local function lootWorld()
	local w = newWorld({})
	local data = {}
	local L = w:Load("LootService", LOOT_SOURCE)
	L.Init({ PlayerService = {
		GetData = function(p) return data[p] end,
		SetStat = function(p, k, v) data[p][k] = v; p:SetAttribute(k, v) end,
	} })
	local p = w:NewPlayer(1, { WeaponTier = 9 })
	data[p] = { Level = 60, WeaponTier = 9, WeaponOwnedMask = 511, WeaponEnhance = { 0, 0, 0, 0, 0, 0, 0, 0, 7 }, Items = {}, LootFlags = {},
		Spares = {}, Market = { Out = {}, In = {}, Done = {}, Day = 0, Lists = 0, Buys = 0 } }
	local function pushes()
		local list = {}
		for _, f in w.Fired do if f.Remote == "Inventory" and f.Player == p then table.insert(list, f.Payload) end end
		return list
	end
	return w, L, p, data, pushes
end

runGroup("spare api", function()
	local w, L, p, data, pushes = lootWorld()
	check(type(L.SpareRoom) == "function" and type(L.AddSpare) == "function", "LootService.SpareRoom / AddSpare exist", "")
	local function refused(label, tier, plus)
		w:Flush() -- earlier pushes first
		local before = deepCopy(data[p])
		local fired = #pushes()
		local room, add = L.SpareRoom(p, tier, plus), L.AddSpare(p, tier, plus)
		w:Flush()
		check(room == false and add == false and sameTable(data[p], before) and #pushes() == fired,
			"refused, nothing changes, nothing sent: " .. label, show({ room, add }))
	end
	for label, tier in { zero = 0, ten = 10, frac = 1.5, nan = NAN, inf = INF, text = "3", none = false, neg = -1 } do
		refused("tier " .. label, tier, 0)
	end
	for label, plus in { neg = -1, eleven = 11, frac = 0.5, nan = NAN, inf = INF, text = "0", none = false } do
		refused("plus " .. label, 3, plus)
	end
	refused("tier nil", nil, 0)
	refused("plus nil", 3, nil)
	local stranger = w:NewPlayer(2, {})
	check(L.SpareRoom(stranger, 3, 0) == false and L.AddSpare(stranger, 3, 0) == false, "no data -> false", "")
	-- a good one: the key goes up by 1, the inventory is published with Spares (Enhance[9] too)
	local nf = #w.Notices
	check(L.SpareRoom(p, 9, 2) == true and next(data[p].Spares) == nil, "SpareRoom says yes and changes nothing", show(data[p].Spares))
	check(L.AddSpare(p, 9, 2) == true and data[p].Spares["9:2"] == 1, "AddSpare(9, 2) -> Spares['9:2'] = 1", show(data[p].Spares))
	w:Flush()
	local list = pushes()
	local last = list[#list]
	check(#list == 1 and last and type(last.Spares) == "table" and last.Spares["9:2"] == 1 and last.Enhance[9] == 7,
		"the Inventory push carries Spares (and Enhance[9])", show(last and last.Spares))
	check(#w.Notices == nf, "AddSpare says nothing (the caller does)", #w.Notices - nf)
	L.AddSpare(p, 9, 2)
	w:Flush()
	check(data[p].Spares["9:2"] == 2, "a second one makes 2", data[p].Spares["9:2"])
	-- the key cap 20
	local yes = 0
	for _ = 1, 25 do if L.AddSpare(p, 3, 0) then yes += 1 end end
	check(yes == 20 and data[p].Spares["3:0"] == 20 and L.SpareRoom(p, 3, 0) == false, "one key stops at 20 (SpareKeyMax)", show({ yes, data[p].Spares["3:0"] }))
	check(L.SpareRoom(p, 3, 1) == true, "another key still has room", "")
	-- the total cap 60 (every key counts, a later tier too)
	data[p].Spares = { ["1:0"] = 20, ["2:0"] = 20, ["4:0"] = 19 }
	check(L.SpareRoom(p, 5, 0) == true and L.AddSpare(p, 5, 0) == true, "59 in all: one more fits", "")
	check(L.SpareRoom(p, 6, 0) == false, "60 in all: no room (SpareSum)", "")
	refused("all spares at 60", 6, 0)
	data[p].Spares = { ["20:0"] = 20, ["1:0"] = 20, ["2:0"] = 20 }
	check(L.SpareRoom(p, 3, 0) == false, "a later tier's key counts in the total", "")
	data[p].Spares = nil
	check(L.AddSpare(p, 1, 0) == true and sameTable(data[p].Spares, { ["1:0"] = 1 }), "a missing Spares table is made", show(data[p].Spares))
	-- LootService's own repair (DebugReset runs it) never drops Spares / Market
	data[p].Spares = { ["9:1"] = 3 }
	data[p].Market.Lists = 2
	check(L.DebugReset(p, 511) == "ok" and sameTable(data[p].Spares, { ["9:1"] = 3 }) and data[p].Market.Lists == 2 and #data[p].WeaponEnhance == 9,
		"LootService's sanitize keeps Spares and Market (9 enhance tiers)", show({ data[p].Spares, data[p].Market }))
end)

finish()
