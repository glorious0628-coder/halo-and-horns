-- save_v4_offline.luau : the save v4 tables (docs/design/save_v4_tables_2026-10-11.md, 게임성 개발 2 + 3 agreed
-- 2026-10-11): Craft, Research, Gather, Gear, Buffs, Shop and EggHonorAt are additive defaults with one repair each
-- (Config.Sanitize*), run by DataService.fillDefaults through Config.SanitizeSaveV4; the save version stays 3 (게임성
-- 개발 2's C1 bumps it to 4). PetService.Sanitize keeps a pet's Roll { Spd = 5..10 } and drops every other Roll shape.
-- tools/test_save_v4_tables.py binds CONFIG_SOURCE, UTIL_SOURCE, DATA_EXTRACT (DataService migrate / fillDefaults) and
-- PET_EXTRACT (PetService.Sanitize with its helpers); dev2_kit.luau comes first.

local NOW = 1790000000 -- the kit's os.time()

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

local NAN, INF = 0 / 0, math.huge

------------------------------------------------------------------ the defaults and the limits
runGroup("config", function()
	local C = cfg()
	local D = C.Data.Defaults
	-- C1 (게임성 개발 2) bumped the version to 4 on top of these tables (tier 9, Spares, Market)
	check(C.Data.Version == 4 and D.Version == 4, "the save version is 4 (게임성 개발 2's C1), Data and Defaults equal",
		show({ C.Data.Version, D.Version }))
	check(sameTable(D.Craft, { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {} }),
		"Craft: a level per role (Smith / Alch / Tame) + Rep + Made", show(D.Craft))
	check(sameTable(D.Research, { Pts = {}, Sum = {} }), "Research = { Pts, Sum }", show(D.Research))
	check(sameTable(D.Gather, { Day = 0, N = 0, Bloom = 0, Gift = 0, Total = 0, FirstBloom = false }),
		"Gather = { Day, N, Bloom, Gift, Total, FirstBloom }", show(D.Gather))
	check(sameTable(D.Gear, { Own = {}, On = { Armor = "", Ring = "" }, Pet = {} }), "Gear = { Own, On { Armor, Ring }, Pet }",
		show(D.Gear))
	check(sameTable(D.Buffs, {}) and sameTable(D.Shop, { Day = 0, N = 0 }) and D.EggHonorAt == 0,
		"Buffs = {}, Shop = { Day, N }, EggHonorAt = 0", show({ D.Buffs, D.Shop, D.EggHonorAt }))
	local L = C.SaveV4
	check(L.CraftMaxLv == 30 and L.GearMaxTier == 16 and L.OwnKeyMax == 20 and L.BuffMax == 2 and L.BuffSeconds == 180
		and L.ShopDayMax == 50 and L.PetRollSpd[1] == 5 and L.PetRollSpd[2] == 10 and L.KeyLen == 32 and L.MaxKeys == 64,
		"limits: craft Lv30, gear tier 16, 20 a key, 2 buffs of 180 s, Otto 50 a day, pet roll 5..10%, ids 32, 64 keys", show(L))
	local mirrored = {}
	for _, k in C.Data.Mirrored do mirrored[k] = true end
	check(not (mirrored.Craft or mirrored.Research or mirrored.Gather or mirrored.Gear or mirrored.Buffs or mirrored.Shop
		or mirrored.EggHonorAt), "no v4 table is mirrored to attributes", "")
	-- every default is already its own repair (a brand-new save needs nothing)
	check(sameTable(C.SanitizeCraft(D.Craft), D.Craft) and sameTable(C.SanitizeResearch(D.Research), D.Research)
		and sameTable(C.SanitizeGather(D.Gather), D.Gather) and sameTable(C.SanitizeGear(D.Gear), D.Gear)
		and sameTable(C.SanitizeBuffs(D.Buffs, NOW), D.Buffs) and sameTable(C.SanitizeShop(D.Shop), D.Shop)
		and C.SanitizeEggHonorAt(D.EggHonorAt, NOW) == 0, "the defaults pass their own repair unchanged", "")
end)

------------------------------------------------------------------ Craft
runGroup("craft", function()
	local C = cfg()
	local def = C.Data.Defaults.Craft
	check(sameTable(C.SanitizeCraft(nil), def) and sameTable(C.SanitizeCraft("x"), def) and sameTable(C.SanitizeCraft(5), def),
		"nil / text / a number -> the default", "")
	local c = C.SanitizeCraft({ Smith = { Lv = 12, XP = 340 }, Alch = { Lv = 0, XP = -5 }, Tame = { Lv = 99, XP = 1e12 }, Rep = 77,
		Made = { Sword4 = 3 } })
	check(c.Smith.Lv == 12 and c.Smith.XP == 340, "a good role is kept as it is", show(c.Smith))
	check(c.Alch.Lv == 1 and c.Alch.XP == 0, "Lv 0 -> 1, a negative XP -> 0", show(c.Alch))
	check(c.Tame.Lv == 30 and c.Tame.XP == 10000000, "Lv above 30 -> 30, a huge XP is cut to MaxCount", show(c.Tame))
	check(c.Rep == 77 and sameTable(c.Made, { Sword4 = 3 }), "Rep and Made kept", show({ c.Rep, c.Made }))
	local b = C.SanitizeCraft({ Smith = { Lv = NAN, XP = INF }, Alch = "oops", Tame = { Lv = 7.9, XP = 10.5 }, Rep = -INF, Made = "x" })
	check(b.Smith.Lv == 1 and b.Smith.XP == 0, "NaN Lv -> 1, inf XP -> 0 (never a free value)", show(b.Smith))
	check(b.Alch.Lv == 1 and b.Alch.XP == 0, "a broken role -> Lv1 XP0", show(b.Alch))
	check(b.Tame.Lv == 7 and b.Tame.XP == 10, "fractions are floored", show(b.Tame))
	check(b.Rep == 0 and sameTable(b.Made, {}), "-inf Rep -> 0, a broken Made -> {}", show({ b.Rep, b.Made }))
	local m = C.SanitizeCraft({ Made = { Good = 2, Zero = 0, Neg = -3, Frac = 2.5, Nan = NAN, Txt = "4",
		[string.rep("a", 33)] = 5, [7] = 1 } })
	check(sameTable(m.Made, { Good = 2, Frac = 2 }), "Made: counts >= 1 kept (floored), 0 / negative / NaN / text / long ids / number keys dropped",
		show(m.Made))
	local many = {}
	for i = 1, 80 do many[string.format("R%03d", i)] = i end
	local cut = C.SanitizeCraft({ Made = many })
	check(count(cut.Made) == 64 and cut.Made.R001 == 1 and cut.Made.R064 == 64 and cut.Made.R065 == nil,
		"Made keeps at most 64 ids (the first 64 in sorted order, always the same ones)", tostring(count(cut.Made)))
	local x = C.SanitizeCraft({ Later = 3, Flag = true, Word = "ok", Deep = { 1 }, Huge = INF, [string.rep("k", 40)] = 1 })
	check(x.Later == 3 and x.Flag == true and x.Word == "ok" and x.Deep == nil and x.Huge == nil and count(x) == 8,
		"an unknown flat key (number / boolean / short text) is kept for a later version; tables, inf and long keys are not",
		show(x))
	local pd = C.SanitizeCraft({ Pend = { Id = "W3", Plus = 2, Gold = 200, Mats = { SlimeCore = 6, Jelly = 20 } } }).Pend
	check(sameTable(pd, { Id = "W3", Plus = 2, Gold = 200, Mats = { SlimeCore = 6, Jelly = 20 } }), "Pend: a paid craft is kept", show(pd))
	local pc = C.SanitizeCraft({ Pend = { Id = "W1", Plus = 7, Gold = -5, Mats = "x" } }).Pend
	check(pc.Plus == 2 and pc.Gold == 0 and sameTable(pc.Mats, {}), "Pend: Plus cut to 2, a negative gold 0, broken Mats {}", show(pc))
	check(C.SanitizeCraft({ Pend = { Id = "W1", Plus = 0 / 0 } }).Pend.Plus == -1 and C.SanitizeCraft({ Pend = { Id = "W1", Plus = -9 } }).Pend.Plus == -1,
		"Pend: NaN / below -1 = -1 (not hammered yet)", "")
	check(C.SanitizeCraft({ Pend = "W1" }).Pend == nil and C.SanitizeCraft({ Pend = { Id = 5 } }).Pend == nil
		and C.SanitizeCraft({ Pend = { Id = string.rep("w", 33) } }).Pend == nil and C.SanitizeCraft({}).Pend == nil,
		"Pend: a text, a number id, a long id or none = no Pend", "")
	local once = C.SanitizeCraft({ Smith = { Lv = 3, XP = 1 }, Rep = 5, Made = { A = 1 }, Later = 2, Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = { Jelly = 10 } } })
	check(sameTable(C.SanitizeCraft(once), once), "repairing twice = once (idempotent)", "")
end)

------------------------------------------------------------------ Research
runGroup("research", function()
	local C = cfg()
	check(sameTable(C.SanitizeResearch(nil), { Pts = {}, Sum = {} }), "nil -> { Pts = {}, Sum = {} }", "")
	local r = C.SanitizeResearch({ Pts = { Slime = 120, Goblin = -1, Bad = NAN }, Sum = { Slime = 2, Huge = 1e15 }, Note = 1 })
	check(sameTable(r.Pts, { Slime = 120 }), "Pts: good counts kept, negative / NaN dropped", show(r.Pts))
	check(sameTable(r.Sum, { Slime = 2, Huge = 10000000 }), "Sum: a huge count is cut to MaxCount", show(r.Sum))
	check(r.Note == 1, "an unknown flat key is kept", show(r))
	check(sameTable(C.SanitizeResearch({ Pts = "x", Sum = 5 }), { Pts = {}, Sum = {} }), "broken maps -> empty maps", "")
end)

------------------------------------------------------------------ Gather
runGroup("gather", function()
	local C = cfg()
	local def = C.Data.Defaults.Gather
	check(sameTable(C.SanitizeGather(nil), def) and sameTable(C.SanitizeGather({}), def), "nil / {} -> the default", "")
	local g = C.SanitizeGather({ Day = 20500, N = 399, Bloom = 2, Gift = 10, Total = 4321, FirstBloom = true })
	check(sameTable(g, { Day = 20500, N = 399, Bloom = 2, Gift = 10, Total = 4321, FirstBloom = true }), "a good Gather is kept",
		show(g))
	local b = C.SanitizeGather({ Day = -4, N = NAN, Bloom = 2.7, Gift = INF, Total = "9", FirstBloom = "yes" })
	check(b.Day == 0 and b.N == 0 and b.Bloom == 2 and b.Gift == 0 and b.Total == 0 and b.FirstBloom == false,
		"negative / NaN / inf / text -> 0, a fraction floored, FirstBloom only when it is true", show(b))
	check(C.SanitizeGather({ N = 1e12 }).N == 10000000, "a huge count is cut", "")
	check(C.SanitizeGather({ Later = 4 }).Later == 4, "an unknown flat key is kept", "")
end)

------------------------------------------------------------------ Gear
runGroup("gear", function()
	local C = cfg()
	local def = C.Data.Defaults.Gear
	check(sameTable(C.SanitizeGear(nil), def) and sameTable(C.SanitizeGear({}), def) and sameTable(C.SanitizeGear("x"), def),
		"nil / {} / text -> the default (On always has Armor and Ring)", "")
	local g = C.SanitizeGear({ Own = { ["Armor:1:0"] = 2, ["Ring:3:2"] = 1, ["PetArmor:2:0"] = 4, ["PetAcc:1:1"] = 1 },
		On = { Armor = "2:1", Ring = "" }, Pet = { P7 = { Armor = "1:0", Acc = "2:2" } } })
	check(sameTable(g.Own, { ["Armor:1:0"] = 2, ["Ring:3:2"] = 1, ["PetArmor:2:0"] = 4, ["PetAcc:1:1"] = 1 }),
		"Own: good keys of every kind kept", show(g.Own))
	check(sameTable(g.On, { Armor = "2:1", Ring = "" }) and sameTable(g.Pet, { P7 = { Armor = "1:0", Acc = "2:2" } }),
		"On and Pet: good worn things kept", show({ g.On, g.Pet }))
	local o = C.SanitizeGear({ Own = { ["Armor:01:0"] = 3, ["Armor:1:00"] = 2, ["Armor:0:0"] = 1, ["Armor:17:0"] = 1,
		["Ring:1:11"] = 1, ["Ring:1:-1"] = 1, ["Ring:1"] = 1, ["9x:1:0"] = 1, ["Ring:1:0"] = 0, ["Ring:2:0"] = NAN,
		["Ring:3:0"] = 50, ["Amulet:2:0"] = 1, [string.rep("A", 17) .. ":1:0"] = 1, [5] = 1, ["Ring:4:0"] = "2" } })
	check(o.Own["Armor:1:0"] == 5, "'Armor:01:0' and 'Armor:1:00' are written plainly and merged (3 + 2)", show(o.Own))
	check(o.Own["Armor:0:0"] == nil and o.Own["Armor:17:0"] == nil and o.Own["Ring:1:11"] == nil and o.Own["Ring:1:-1"] == nil,
		"tier 0 / tier 17 / plus 11 / a negative plus dropped", show(o.Own))
	check(o.Own["Ring:1"] == nil and o.Own["9x:1:0"] == nil and o.Own[5] == nil and o.Own[string.rep("A", 17) .. ":1:0"] == nil,
		"a key without the plus / a non-letter kind / a number key / a 17-letter kind dropped", show(o.Own))
	check(o.Own["Ring:1:0"] == nil and o.Own["Ring:2:0"] == nil and o.Own["Ring:4:0"] == nil, "0 / NaN / text counts dropped",
		show(o.Own))
	check(o.Own["Ring:3:0"] == 20, "one key holds at most 20", show(o.Own["Ring:3:0"]))
	check(o.Own["Amulet:2:0"] == 1, "a later kind (letters only) is kept", show(o.Own))
	local merged = C.SanitizeGear({ Own = { ["Ring:1:0"] = 15, ["Ring:01:0"] = 15 } })
	check(merged.Own["Ring:1:0"] == 20, "a merged key is cut at 20 too", show(merged.Own))
	local w = C.SanitizeGear({ On = { Armor = "01:2", Ring = "0:0", Belt = "3:1", ["2x"] = "1:0", Hat = "1:12", Cape = 5 } })
	check(w.On.Armor == "1:2" and w.On.Ring == "" and w.On.Belt == "3:1" and w.On["2x"] == nil and w.On.Hat == nil
		and w.On.Cape == nil, "On: plain 'T:P' kept, a bad worn value -> '' (Armor / Ring) or dropped (others)", show(w.On))
	local p = C.SanitizeGear({ Pet = { P1 = { Armor = "9:0" }, P2 = { Armor = "x" }, P3 = "x", [string.rep("u", 33)] = { Acc = "1:0" },
		P4 = {} } })
	check(sameTable(p.Pet, { P1 = { Armor = "9:0" } }), "Pet: an entry that wears nothing / a broken entry / a long uid dropped",
		show(p.Pet))
	local pets = {}
	for i = 1, 70 do pets[string.format("P%03d", i)] = { Armor = "1:0" } end
	local cut = C.SanitizeGear({ Pet = pets })
	check(count(cut.Pet) == 64 and cut.Pet.P001 ~= nil and cut.Pet.P065 == nil, "Pet keeps at most 64 pets (sorted)",
		tostring(count(cut.Pet)))
	local own = {}
	for _, kind in { "Armor", "Ring" } do for i = 1, 16 do for k = 0, 2 do own[string.format("%s:%d:%d", kind, i, k)] = 1 end end end
	check(count(C.SanitizeGear({ Own = own }).Own) == 64, "Own keeps at most 64 keys", "")
	-- ⑥ gear (게임성 개발 3): a gear's plus is the hammer's +0..+2 only (a scroll's +3..+10 is never gear)
	local plus = C.SanitizeGear({ Own = { ["Ring:1:2"] = 1, ["Ring:1:3"] = 1, ["Armor:2:10"] = 1 }, On = { Armor = "1:3", Ring = "1:2" },
		Pet = { P1 = { PetAcc = "1:3" }, P2 = { PetAcc = "1:2" } } })
	check(plus.Own["Ring:1:2"] == 1 and plus.Own["Ring:1:3"] == nil and plus.Own["Armor:2:10"] == nil and plus.On.Armor == ""
		and plus.On.Ring == "1:2" and plus.Pet.P1 == nil and plus.Pet.P2.PetAcc == "1:2", "gear keeps P in 0..2 (+3 / +10 dropped everywhere)", show(plus))
	check(C.SaveV4.GearMaxPlus == 2, "Config.SaveV4.GearMaxPlus = 2", "")
	local x = C.SanitizeGear({ Later = 2, Deep = { 1 } })
	check(x.Later == 2 and x.Deep == nil, "an unknown flat key is kept, an unknown table is not", show(x))
	local once = C.SanitizeGear({ Own = { ["Armor:01:0"] = 3, ["Amulet:2:0"] = 1 }, On = { Armor = "01:2", Belt = "1:0" },
		Pet = { P1 = { Acc = "2:0" } }, Later = 1 })
	check(sameTable(C.SanitizeGear(once), once), "repairing twice = once (idempotent)", "")
end)

------------------------------------------------------------------ Buffs
runGroup("buffs", function()
	local C = cfg()
	check(sameTable(C.SanitizeBuffs(nil, NOW), {}) and sameTable(C.SanitizeBuffs("x", NOW), {}), "nil / text -> {}", "")
	local b = C.SanitizeBuffs({ Might = NOW + 100, Guard = NOW - 1, Lucky = NOW, Wise = NOW + 9999 }, NOW)
	check(b.Might == NOW + 100, "a buff still running keeps its end", show(b))
	check(b.Guard == nil and b.Lucky == nil, "an ended buff (in the past or ending now) is dropped", show(b))
	check(sameTable(C.SanitizeBuffs({ Old = NOW - 5, Now = NOW }, NOW), {}), "only ended buffs -> {} (none comes back)", "")
	check(b.Wise == NOW + 180, "an end later than now + 180 is cut to now + 180 (never a longer buff)", show(b))
	local three = C.SanitizeBuffs({ A = NOW + 10, B = NOW + 50, C = NOW + 30 }, NOW)
	check(sameTable(three, { B = NOW + 50, C = NOW + 30 }), "at most two: the ones that end last", show(three))
	local tie = C.SanitizeBuffs({ Z = NOW + 50, Y = NOW + 50, X = NOW + 50 }, NOW)
	check(sameTable(tie, { X = NOW + 50, Y = NOW + 50 }), "a tie is broken by the id (always the same two)", show(tie))
	local bad = C.SanitizeBuffs({ A = NAN, B = "x", C = INF, [string.rep("t", 33)] = NOW + 5, [4] = NOW + 5 }, NOW)
	check(sameTable(bad, {}), "NaN / text / inf ends, long ids and number keys dropped", show(bad))
	check(C.SanitizeBuffs({ A = NOW + 60.7 }, NOW).A == NOW + 60, "a fractional end is floored", "")
end)

------------------------------------------------------------------ Shop, EggHonorAt
runGroup("shop and egg", function()
	local C = cfg()
	check(sameTable(C.SanitizeShop(nil), { Day = 0, N = 0 }), "Shop nil -> { Day = 0, N = 0 }", "")
	local s = C.SanitizeShop({ Day = 20500, N = 73 })
	check(s.Day == 20500 and s.N == 50, "Shop.N is cut at 50 (Otto's cheap materials a day)", show(s))
	local b = C.SanitizeShop({ Day = NAN, N = -2, Later = true })
	check(b.Day == 0 and b.N == 0 and b.Later == true, "Shop: NaN / negative -> 0, an unknown flat key kept", show(b))
	check(C.SanitizeEggHonorAt(NOW - 60, NOW) == NOW - 60, "EggHonorAt in the past is kept", "")
	check(C.SanitizeEggHonorAt(NOW, NOW) == NOW, "EggHonorAt = now is kept", "")
	check(C.SanitizeEggHonorAt(NOW + 1, NOW) == NOW and C.SanitizeEggHonorAt(NOW + 9999, NOW) == NOW,
		"a future EggHonorAt is cut to now (never 0: the hourly +5 never reopens early)", "")
	check(C.SanitizeEggHonorAt(NAN, NOW) == 0 and C.SanitizeEggHonorAt("x", NOW) == 0 and C.SanitizeEggHonorAt(-5, NOW) == 0
		and C.SanitizeEggHonorAt(INF, NOW) == 0, "NaN / text / negative / inf -> 0", "")
	check(C.SanitizeEggHonorAt(NOW - 0.5, NOW) == NOW - 1, "a fraction is floored", "")
end)

------------------------------------------------------------------ DataService: the real load path
runGroup("load", function()
	local w = newWorld({})
	w.AllowWarn = { "field Craft had type string, reset to default", "field Gear had type number, reset to default" }
	local C = w.Config
	local env = w:Env()
	local DS = execute("DataService.extract", DATA_EXTRACT, env, C, w.Util, "DataService", 99)
	local function load(rec)
		local d = deepCopy(rec)
		DS.Migrate(d, { Name = "P1" })
		DS.Fill(d, "P1")
		return d
	end
	local v3 = { Version = 3, Level = 12, Faction = "Halo", Class = "Mage", ClassChosen = true, TutorialStep = 99, WeaponTier = 3,
		WeaponOwnedMask = 7, BankGold = 300 }
	local d = load(v3)
	local D = C.Data.Defaults
	check(d.Version == 4 and d.Level == 12 and d.WeaponTier == 3 and d.BankGold == 300 and d.WeaponOwnedMask == 7,
		"a v3 save becomes v4 (C1) and keeps everything it had", show({ d.Version, d.Level }))
	check(sameTable(d.Craft, D.Craft) and sameTable(d.Research, D.Research) and sameTable(d.Gather, D.Gather)
		and sameTable(d.Gear, D.Gear) and sameTable(d.Buffs, D.Buffs) and sameTable(d.Shop, D.Shop) and d.EggHonorAt == 0,
		"it gains every v4 table with its default", "")
	check(sameTable(load(d), d), "loading it again changes nothing (idempotent)", "")
	local kept = load({ Version = 3, Level = 30, TutorialStep = 99, Craft = { Smith = { Lv = 9, XP = 40 }, Alch = { Lv = 2, XP = 0 },
		Tame = { Lv = 1, XP = 0 }, Rep = 15, Made = { Sword3 = 2 } }, Gear = { Own = { ["Ring:2:1"] = 1 }, On = { Armor = "1:0", Ring = "" },
		Pet = { P1 = { Acc = "1:0" } } }, Buffs = { Might = 1790000100 }, EggHonorAt = 1789999000, Shop = { Day = 20700, N = 12 } })
	check(kept.Craft.Smith.Lv == 9 and kept.Craft.Rep == 15 and kept.Gear.Own["Ring:2:1"] == 1 and kept.Gear.On.Armor == "1:0"
		and kept.Gear.Pet.P1.Acc == "1:0" and kept.Buffs.Might == 1790000100 and kept.EggHonorAt == 1789999000 and kept.Shop.N == 12,
		"a save's good v4 values come back as they were", show({ kept.Craft.Smith, kept.Gear, kept.Buffs }))
	local broken = load({ Version = 3, Level = 3, TutorialStep = 99, Craft = "oops", Gear = 5, Buffs = { Might = 1790009999 },
		EggHonorAt = 1790009999, Shop = { N = 99 }, Gather = { N = -1, FirstBloom = 1 } })
	check(sameTable(broken.Craft, D.Craft) and sameTable(broken.Gear, D.Gear), "a broken table becomes its default", "")
	check(broken.Buffs.Might == 1790000180 and broken.EggHonorAt == 1790000000 and broken.Shop.N == 50 and broken.Gather.N == 0
		and broken.Gather.FirstBloom == false, "the load uses the server clock: a long buff is cut, a future egg hour is cut to now",
		show({ broken.Buffs, broken.EggHonorAt }))
	local fixed = load({ Version = 3, Level = 3, TutorialStep = 99, Gear = { Own = { ["Armor:01:0"] = 3, ["Ring:0:0"] = 1 },
		On = { Armor = "1:99" } } })
	check(sameTable(fixed.Gear, { Own = { ["Armor:1:0"] = 3 }, On = { Armor = "", Ring = "" }, Pet = {} }),
		"the load repairs a Gear table of the right type (keys written plainly, bad things dropped, slots filled)",
		show(fixed.Gear))
	local fresh = load(deepCopy(D))
	check(fresh.Version == 4 and sameTable(fresh.Gear, D.Gear) and sameTable(fresh.Craft, D.Craft)
		and sameTable(fresh.Spares, D.Spares) and sameTable(fresh.Market, D.Market), "a brand-new save is v4 with the defaults", "")
end)

------------------------------------------------------------------ PetService.Sanitize keeps Roll
runGroup("pet roll", function()
	local C = cfg()
	local Sanitize = execute("PetService.extract", PET_EXTRACT, nativeEnv(), C)
	local species = next(C.Pets.Species)
	local function row(roll)
		return { Sp = species, Lv = 3, XP = 5, Name = "", Lean = "", Bound = true, Roll = roll }
	end
	local function one(roll)
		local data = { Pets = { List = { P1 = row(roll) }, Equipped = { "P1" }, Next = 2 } }
		Sanitize(data)
		return data.Pets.List.P1
	end
	local p = one({ Spd = 7 })
	check(type(p) == "table" and sameTable(p.Roll, { Spd = 7 }), "a good Roll { Spd = 7 } is kept", show(p))
	check(p.Lv == 3 and p.XP == 5 and p.Bound == true and p.Sp == species, "the rest of the pet row is as before", show(p))
	check(sameTable(one({ Spd = 5 }).Roll, { Spd = 5 }) and sameTable(one({ Spd = 10 }).Roll, { Spd = 10 }), "5 and 10 are the ends", "")
	for _, bad in { { Spd = 4 }, { Spd = 11 }, { Spd = 7.5 }, { Spd = NAN }, { Spd = INF }, { Spd = "7" }, { Spd = 7, Atk = 1 }, {}, "x", 7 } do
		check(one(bad).Roll == nil, "any other Roll shape drops the whole Roll (4 / 11 / 7.5 / NaN / inf / text / an extra key / {} / not a table)",
			show(bad))
	end
	check(one(nil).Roll == nil, "a pet without a Roll stays without one", "")
end)

finish()
