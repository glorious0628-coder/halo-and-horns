-- stats_offline.luau : A23-69 stat points, stage 1 (docs/design/stat_points_2026-10-07.md §1-§3, §5-1; the switch
-- Config.Features.StatPoints stays OFF until stage 2 and the 10/20 check). tools/test_stats.py binds CONFIG_SOURCE,
-- UTIL_SOURCE and chunks cut from DataService (DATA_EXTRACT), JusticeService (JUSTICE_EXTRACT), PvPService (PVP_EXTRACT),
-- PlayerService (COLUMN_EXTRACT) and LootService (LOOT_EXTRACT); dev2_kit.luau comes first.

local function cfg(on)
	local c = execute("Config", CONFIG_SOURCE, nativeEnv())
	if on ~= nil then c.Features.StatPoints = on == true end
	return c
end

-- a player double that only answers GetAttribute
local function pl(attrs)
	return { GetAttribute = function(_, key) return attrs[key] end }
end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-9 end

local function sameTable(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not sameTable(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

------------------------------------------------------------------ the table, the switch, the save shape
runGroup("config", function()
	local C = cfg(nil)
	check(C.Features.StatPoints == false and C.FeatureOn("StatPoints") == false,
		"Config.Features.StatPoints is OFF (stage 1: everything works as before)", show(C.Features))
	local S = C.Stats
	local letters = 0
	for _ in S.Letters do letters += 1 end
	check(S.MaxPoints == 99 and letters == 2 and S.Letters.A == true and S.Letters.H == true,
		"99 points at most; the beta letters are A (Attack) and H (Health)", show(S.Letters))
	check(#S.Curve == 3 and S.Curve[1][1] == 20 and S.Curve[1][2] == 0.01 and S.Curve[2][1] == 40 and S.Curve[2][2] == 0.005
		and S.Curve[3][1] == math.huge and S.Curve[3][2] == 0.0025, "the curve: 1% a point to 20, 0.5% to 40, 0.25% after",
		show(S.Curve))
	check(S.AutoPattern.Warrior == "HA" and S.AutoPattern.Mage == "HA" and S.AutoPattern.Archer == "AH",
		"auto patterns: Warrior / Mage HA, Archer AH (the same for Halo and Horns)", show(S.AutoPattern))
	check(C.Data.Version == 7 and C.Data.Defaults.Version == 7, "save Data v7 (A23-219 ②) / v6 = A23-186's joke weapons (5 = A23-153's codex, 4 = C1's tier 9) (검수 2026-10-07: Stats is an additive field)",
		show({ C.Data.Version, C.Data.Defaults.Version }))
	check(sameTable(C.Data.Defaults.Stats, { Auto = true, Order = "" }), "a new save: Stats = { Auto = true, Order = '' }",
		show(C.Data.Defaults.Stats))
	local mirrored = {}
	for _, k in C.Data.Mirrored do mirrored[k] = true end
	check(not mirrored.Stats and not mirrored.StatAtk and not mirrored.StatHp, "no stat key is mirrored (StatService writes the attributes)",
		"")
end)

------------------------------------------------------------------ f(points)
runGroup("curve", function()
	local C = cfg(nil)
	local cases = { { 0, 0 }, { 1, 0.01 }, { 10, 0.1 }, { 20, 0.2 }, { 21, 0.205 }, { 30, 0.25 }, { 40, 0.3 }, { 41, 0.3025 },
		{ 50, 0.325 }, { 99, 0.4475 } }
	for _, c in cases do
		check(near(C.StatBonus(c[1]), c[2]), "f(points): 0 / 1% / 10% / 20% / 20.5% / 25% / 30% / 30.25% / 32.5% / 44.75%",
			show({ c[1], C.StatBonus(c[1]), c[2] }))
	end
	check(near(C.StatBonus(150), C.StatBonus(99)) and near(C.StatBonus(math.huge), C.StatBonus(99)),
		"more than 99 points counts as 99 (never an endless bonus)", show({ C.StatBonus(150), C.StatBonus(math.huge) }))
	check(C.StatBonus(nil) == 0 and C.StatBonus(-5) == 0 and C.StatBonus(0 / 0) == 0 and C.StatBonus("x") == 0
		and near(C.StatBonus(10.9), 0.1), "nil, negative, NaN, text: 0; a fraction is floored", "")
	local prev, grows, shrinks = 0, true, true
	local prevStep = math.huge
	for r = 1, 99 do
		local step = C.StatBonus(r) - C.StatBonus(r - 1)
		if C.StatBonus(r) <= prev then grows = false end
		if step > prevStep + 1e-12 then shrinks = false end
		prev, prevStep = C.StatBonus(r), step
	end
	check(grows and shrinks, "every point adds something, and never more than the point before (a one-stat build tails off)", "")
end)

------------------------------------------------------------------ points, auto, by hand
runGroup("points and alloc", function()
	local C = cfg(nil)
	check(C.StatPoints(1) == 0 and C.StatPoints(2) == 1 and C.StatPoints(10) == 9 and C.StatPoints(100) == 99
		and C.StatPoints(150) == 99 and C.StatPoints(0) == 0 and C.StatPoints(-3) == 0 and C.StatPoints(nil) == 0
		and C.StatPoints(0 / 0) == 0, "points: Lv1 0, Lv2 1, Lv10 9, Lv100 99, above 99 / below 1 / nil / NaN clamped", "")
	local function alloc(stats, level, class) return { C.StatAlloc(stats, level, class) } end
	check(sameTable(alloc(nil, 10, "Warrior"), { 4, 5, 0 }) and sameTable(alloc({ Auto = true, Order = "AAAA" }, 10, "Mage"), { 4, 5, 0 }),
		"auto Lv10 Warrior / Mage: H5 A4 (HA repeated), nothing free, Order ignored", show(alloc(nil, 10, "Warrior")))
	check(sameTable(alloc(nil, 10, "Archer"), { 5, 4, 0 }), "auto Lv10 Archer: A5 H4 (AH)", show(alloc(nil, 10, "Archer")))
	check(sameTable(alloc(nil, 100, "Warrior"), { 49, 50, 0 }) and sameTable(alloc(nil, 100, "Archer"), { 50, 49, 0 }),
		"auto Lv100: Warrior H50 A49, Archer A50 H49", show({ alloc(nil, 100, "Warrior"), alloc(nil, 100, "Archer") }))
	check(sameTable(alloc(nil, 1, "Warrior"), { 0, 0, 0 }) and sameTable(alloc(nil, 10, "Ninja"), { 4, 5, 0 }),
		"Lv1: nothing; an unknown class uses the Warrior pattern", "")
	local hand = { Auto = false, Order = "AAAH" }
	check(sameTable(alloc(hand, 10, "Warrior"), { 3, 1, 5 }), "by hand Lv10, Order AAAH: A3 H1, 5 free", show(alloc(hand, 10, "Warrior")))
	check(sameTable(alloc(hand, 3, "Warrior"), { 2, 0, 0 }) and sameTable(alloc(hand, 2, "Warrior"), { 1, 0, 0 }),
		"a level reset keeps Order: Lv3 counts its first 2 letters, Lv2 its first 1", show(alloc(hand, 3, "Warrior")))
	check(sameTable(alloc({ Auto = false, Order = "" }, 10, "Warrior"), { 0, 0, 9 })
		and sameTable(alloc({ Auto = false, Order = 5 }, 10, "Warrior"), { 0, 0, 9 }), "by hand with nothing picked: all 9 free", "")
	local grow = { Auto = false, Order = "HHAAHA" }
	check(sameTable(alloc(grow, 4, "Warrior"), { 1, 2, 0 }) and sameTable(alloc(grow, 7, "Warrior"), { 3, 3, 0 }),
		"leveling up again rebuilds the same picks in the same order", show({ alloc(grow, 4, "Warrior"), alloc(grow, 7, "Warrior") }))
end)

------------------------------------------------------------------ the switch, a player's points, the save repair
runGroup("mults and sanitize", function()
	local off, on = cfg(false), cfg(true)
	local a1, h1 = off.StatMults(10, 20)
	local a2, h2 = on.StatMults(10, 20)
	check(a1 == 1 and h1 == 1, "switch OFF: StatMults is (1, 1) for any points", show({ a1, h1 }))
	check(near(a2, 1.1) and near(h2, 1.2), "switch ON: (1 + f(A), 1 + f(H))", show({ a2, h2 }))
	local C = cfg(nil)
	check(sameTable(C.StatAllocOf(pl({ StatAtk = 4, StatHp = 5 })), { A = 4, H = 5 }), "StatAllocOf reads StatAtk / StatHp", "")
	check(sameTable(C.StatAllocOf(pl({})), { A = 0, H = 0 }) and sameTable(C.StatAllocOf(pl({ StatAtk = 0 / 0, StatHp = -3 })), { A = 0, H = 0 })
		and sameTable(C.StatAllocOf(pl({ StatAtk = 150, StatHp = 4.7 })), { A = 99, H = 4 }),
		"missing / NaN / negative -> 0, above 99 -> 99, fractions floored", show(C.StatAllocOf(pl({ StatAtk = 150, StatHp = 4.7 }))))
	local function san(t) return C.SanitizeStats(t) end
	check(sameTable(san(nil), { Auto = true, Order = "" }) and sameTable(san("broken"), { Auto = true, Order = "" }),
		"nothing / not a table: Auto ON, nothing picked", "")
	check(sameTable(san({ Auto = false, Order = "HAHA" }), { Auto = false, Order = "HAHA" }), "a good save stays as it is", "")
	check(san({ Auto = "yes" }).Auto == true and san({ Auto = 1 }).Auto == true and san({ Auto = false }).Auto == false,
		"Auto: only a real boolean counts (else ON)", "")
	check(san({ Order = 5 }).Order == "" and san({ Order = { "A" } }).Order == "" and san({ Order = "AHXAHz!" }).Order == "AHXAH",
		"Order: only text, its letters A-Z kept (for later stats), lowercase / digits / signs dropped", show(san({ Order = "AHXAHz!" })))
	check(sameTable({ C.StatAlloc({ Auto = false, Order = "AXH" }, 4, "Warrior") }, { 1, 1, 1 }),
		"a kept letter that is no stat yet (X) counts nothing: its point stays free", show({ C.StatAlloc({ Auto = false, Order = "AXH" }, 4, "Warrior") }))
	check(san({ Order = string.rep("A", 200) }).Order == string.rep("A", 99), "at most 99 letters", #san({ Order = string.rep("A", 200) }).Order)
	check(san({ Order = string.rep("x", 5000) .. "A" }).Order == "", "a huge broken Order is cut (only its first 4096 characters are read)", "")
	local input = { Auto = false, Order = "HA" }
	local out = san(input)
	out.Order = "changed"
	check(input.Order == "HA" and sameTable(san(san({ Order = "AXH", Auto = false })), san({ Order = "AXH", Auto = false })),
		"a new table every time (the input is never changed); sanitizing twice changes nothing", "")
end)

------------------------------------------------------------------ the power numbers
runGroup("power", function()
	local off, on = cfg(false), cfg(true)
	-- OFF: the stat points change nothing
	local same = 0
	for _, level in { 1, 2, 10, 20, 55, 100 } do
		for tier = 0, off.MaxWeaponTier do
			for _, e in { 0, 3, 10 } do
				local split = { A = (level * 7 + tier) % 50, H = (level * 3 + e) % 50 }
				if off.CombatPower(level, tier, e, split) ~= off.CombatPower(level, tier, e)
					or off.PowerOf(level, tier, 1.25, e, split) ~= off.PowerOf(level, tier, 1.25, e) then
					same += 1
				end
			end
		end
	end
	check(same == 0, "switch OFF: every power number is the same with or without stat points", same)
	check(off.CombatPower(20, 5, 0) == 2829 and on.CombatPower(20, 5, 0) == 2829, "no points (alloc nil): the BB4 numbers stay (Lv20 tier 5 = 2,829)",
		on.CombatPower(20, 5, 0))
	-- ON: the design examples (auto builds)
	local function autoPower(c, level, tier, e)
		local a, h = c.StatAlloc(nil, level, "Warrior")
		return c.CombatPower(level, tier, e, { A = a, H = h })
	end
	check(off.CombatPower(10, 3, 0) == 923 and autoPower(on, 10, 3, 0) == 965, "Lv10 tier 3: 923 -> 965 with the auto points (+4.5%)",
		show({ off.CombatPower(10, 3, 0), autoPower(on, 10, 3, 0) }))
	check(autoPower(on, 20, 5, 0) == 3098, "Lv20 tier 5: 2,829 -> 3,098 (+9.5%)", autoPower(on, 20, 5, 0))
	check(off.CombatPower(100, 7, 0) == 18023 and autoPower(on, 100, 7, 0) == 23858, "Lv100 tier 7: 18,023 -> 23,858 (+32.4%)",
		show({ off.CombatPower(100, 7, 0), autoPower(on, 100, 7, 0) }))
	local even = on.PowerOf(100, 7, 1, 0, { A = 49, H = 50 })
	local one = on.PowerOf(100, 7, 1, 0, { A = 99, H = 0 })
	local none = on.PowerOf(100, 7, 1, 0, { A = 0, H = 0 })
	check(math.abs(one / even - 0.909) < 0.001 and math.abs(none / even - 0.755) < 0.001,
		"Lv100: one stat only = 0.909 of the even build, nothing picked = 0.755 (never under the 0.5 bully line)",
		show({ one / even, none / even }))
	check(on.CombatPower(1, 0, 0, { A = 0, H = 0 }) == 0, "Lv1 bare hands is still 0 (A23-34)", on.CombatPower(1, 0, 0, { A = 0, H = 0 }))
	-- the highest number (C1: the Mythic tier 9): 37,805 off / 50,044 on, cached apart; tier 7 alone stays 25,488 / 33,740
	local f = cfg(false)
	check(f.MaxCombatPower() == 37805 and f.Power.MaxCache == 37805 and f.Power.MaxCacheStats == nil,
		"MaxCombatPower OFF = 37,805 (cached in Power.MaxCache)", show({ f.MaxCombatPower(), f.Power.MaxCacheStats }))
	f.Features.StatPoints = true
	check(f.MaxCombatPower() == 50044 and f.Power.MaxCacheStats == 50044 and f.Power.MaxCache == 37805,
		"MaxCombatPower ON = 50,044 (the even 49 / 50 split; its own cache)", show({ f.MaxCombatPower(), f.Power.MaxCache }))
	check(f.CombatPower(100, 7, 10, { A = 49, H = 50 }) == 33740 and f.CombatPower(100, 7, 10) == 25488,
		"tier 7 at Lv100 +10 stays 25,488 off / 33,740 even split (tiers 1-8 unchanged)", "")
	f.Features.StatPoints = false
	check(f.MaxCombatPower() == 37805, "switching back OFF gives 37,805 again", f.MaxCombatPower())
	local over = 0
	local max = on.MaxCombatPower()
	for level = 1, on.Levels.MaxLevel, 3 do
		local pts = on.StatPoints(level)
		for tier = 1, on.MaxWeaponTier do
			for _, split in { { A = pts, H = 0 }, { A = 0, H = pts }, { A = math.floor(pts / 2), H = pts - math.floor(pts / 2) } } do
				if on.CombatPower(level, tier, on.Loot.MaxEnhance, split) > max then over += 1 end
			end
		end
	end
	check(over == 0, "no level / weapon / build goes above MaxCombatPower (ON)", over)
end)

------------------------------------------------------------------ one formula: Config.CombatPowerOf everywhere
runGroup("one formula", function()
	for _, on in { false, true } do
		local C = cfg(on)
		local tag = on and "ON" or "OFF"
		local p = pl({ Level = 20, WeaponTier = 5, WeaponEnhance = 2, StatAtk = 9, StatHp = 10 })
		check(C.CombatPowerOf(p) == C.CombatPower(20, 5, 2, { A = 9, H = 10 }),
			"CombatPowerOf = CombatPower(Level, WeaponTier, WeaponEnhance, { StatAtk, StatHp }) " .. tag, C.CombatPowerOf(p))
		check(C.CombatPowerOf(p, 0, 0) == C.CombatPower(20, 0, 0, { A = 9, H = 10 }) and C.CombatPowerOf(p, 3, 4) == C.CombatPower(20, 3, 4, { A = 9, H = 10 }),
			"the weapon / +N overrides (LootService's 'Power X -> Y') keep the level and the points " .. tag, "")
		check(C.CombatPowerOf(pl({})) == 0 and C.CombatPowerOf(pl({ Level = 0 / 0, WeaponTier = 99 })) == C.CombatPower(1, C.MaxWeaponTier, 0)
			and C.CombatPowerOf(pl({ Level = 5, WeaponTier = -2 })) == C.CombatPower(5, 0, 0)
			and C.CombatPowerOf(pl({ Level = 5, WeaponTier = 0 / 0 })) == C.CombatPower(5, 0, 0),
			"no attributes = Lv1 bare hands (0); NaN level -> 1; the tier clamped to 0..MaxWeaponTier (9; NaN -> 0) " .. tag, "")
		local J = execute("JusticeService.extract", JUSTICE_EXTRACT, nativeEnv(), C)
		local PV = execute("PvPService.extract", PVP_EXTRACT, nativeEnv(), C)
		local COL = execute("PlayerService.leaderstats", COLUMN_EXTRACT, nativeEnv(), C, nil, function() end)
		local diff = 0
		for i = 1, 60 do
			local attrs = { Level = 1 + (i * 7) % 100, WeaponTier = i % 9, WeaponEnhance = i % 11, StatAtk = (i * 3) % 60,
				StatHp = (i * 5) % 60, RebirthBonus = (i % 3) * 0.25 }
			local q = pl(attrs)
			local want = C.CombatPowerOf(q)
			if J.J.GetCombatPower(q) ~= want or PV.combatPower(q, {}) ~= want or PV.combatPower(q, { JusticeService = J.J }) ~= want
				or COL.Power(q) ~= want then
				diff += 1
			end
			local wantPower = C.PowerOf(attrs.Level, attrs.WeaponTier, 1 + attrs.RebirthBonus, attrs.WeaponEnhance,
				{ A = attrs.StatAtk, H = attrs.StatHp })
			if math.abs(J.J.GetPower(q) - wantPower) > 1e-9 then diff += 1 end
		end
		check(diff == 0, "Justice (attribute + faction sum), PvP's fallback (with / without Justice) and the Tab column all give CombatPowerOf " .. tag, diff)
		check(COL.Power(pl({ CombatPower = 777, Level = 50 })) == 777, "the Tab column shows the CombatPower attribute once set " .. tag, "")
	end
	-- the CombatPower attribute follows StatAtk / StatHp (JusticeService POWER.Watch, one deferred refresh a frame)
	local w = newWorld({})
	w.Config.Features.StatPoints = true
	local J = execute("JusticeService.extract", JUSTICE_EXTRACT, w:Env(), w.Config)
	local p = w:NewPlayer(1, { Level = 30, WeaponTier = 3, WeaponEnhance = 0, StatAtk = 0, StatHp = 0 })
	J.POWER.Conns[p] = {}
	J.POWER.Watch(p)
	local before = p:GetAttribute("CombatPower")
	check(before == w.Config.CombatPower(30, 3, 0, { A = 0, H = 0 }), "Watch sets the CombatPower attribute at once", before)
	p:SetAttribute("StatAtk", 14)
	w:Flush()
	local afterAtk = p:GetAttribute("CombatPower")
	p:SetAttribute("StatHp", 15)
	w:Flush()
	check(afterAtk == w.Config.CombatPower(30, 3, 0, { A = 14, H = 0 }) and afterAtk > before
		and p:GetAttribute("CombatPower") == w.Config.CombatPower(30, 3, 0, { A = 14, H = 15 }),
		"a StatAtk / StatHp change updates the CombatPower attribute", show({ before, afterAtk, p:GetAttribute("CombatPower") }))
	-- LootService's first weapon: "Power X -> Y" with the player's points
	local on = cfg(true)
	local equip = execute("LootService.equipIfBare", LOOT_EXTRACT, nativeEnv(), on,
		{ PlayerService = { SetStat = function(pp, k, v) pp.Set[k] = v end } }, { Fx = function() end }, function() end, on.Loot)
	local q = pl({ Level = 6, WeaponTier = 0, WeaponEnhance = 0, StatAtk = 2, StatHp = 3 })
	q.Set = {}
	local x, y = equip(q, { Level = 6, WeaponTier = 0, WeaponEnhance = { [1] = 0 } }, 1)
	check(x == on.CombatPower(6, 0, 0, { A = 2, H = 3 }) and y == on.CombatPower(6, 1, 0, { A = 2, H = 3 }) and q.Set.WeaponTier == 1,
		"the first weapon's 'Power X -> Y' counts the player's stat points on both sides", show({ x, y }))
end)

------------------------------------------------------------------ the save: Stats is additive, Version stays 3 (cut out)
runGroup("data", function()
	local w = newWorld({})
	w.AllowWarn = "field Stats had type string, reset to default" -- the broken save below
	local C = w.Config
	local env = w:Env()
	local DS = execute("DataService.extract", DATA_EXTRACT, env, C, w.Util, "DataService", 99)
	local function load(rec)
		local d = deepCopy(rec)
		DS.Migrate(d, { Name = "P1" })
		DS.Fill(d, "P1")
		return d
	end
	local v3 = { Version = 3, Level = 12, XP = 5, Faction = "Halo", Class = "Mage", ClassChosen = true, TutorialStep = 99,
		WeaponTier = 3, WeaponOwnedMask = 7, BankGold = 300 }
	local d = load(v3)
	check(d.Version == 7 and sameTable(d.Stats, { Auto = true, Order = "" }) and d.Level == 12 and d.WeaponTier == 3 and d.BankGold == 300,
		"a v3 save without Stats becomes v4 (C1) and gains { Auto ON, nothing picked }, nothing else changes", show({ d.Version, d.Stats }))
	local again = load(d)
	check(sameTable(again, d), "loading it again changes nothing (idempotent)", "")
	local hand = load({ Version = 3, Level = 8, TutorialStep = 99, Stats = { Auto = false, Order = "AHXah" } })
	check(sameTable(hand.Stats, { Auto = false, Order = "AHX" }) and hand.Version == 7, "a save's picks are repaired, not reset",
		show(hand.Stats))
	local broken = load({ Version = 3, Level = 8, TutorialStep = 99, Stats = "oops" })
	check(sameTable(broken.Stats, { Auto = true, Order = "" }), "a broken Stats becomes the default", show(broken.Stats))
	local v1 = load({ Level = 5, SwordTier = 2, TutorialStep = 99 })
	check(v1.Version == 7 and v1.WeaponTier == 2 and v1.SwordTier == nil and sameTable(v1.Stats, { Auto = true, Order = "" }),
		"a v1 save runs every step to v4 and gains the default Stats", show({ v1.Version, v1.WeaponTier }))
	local fresh = load(deepCopy(C.Data.Defaults))
	check(fresh.Version == 7 and sameTable(fresh.Stats, { Auto = true, Order = "" }), "a brand-new save is v4 with the default Stats", "")
end)

finish()
