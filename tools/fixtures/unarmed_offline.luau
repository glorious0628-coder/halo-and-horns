-- A23-34 bare-handed start (server side), run offline. tools/test_unarmed_start.py injects (before
-- tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE, COMBAT_SOURCE, LOOT_SOURCE, STORY_SOURCE, PVP_SOURCE (whole
-- modules) and the extracts SHOP_EXTRACT (onUpgradeWeapon / onSellWeapon / onBlacksmithPrompt), DATA_EXTRACT
-- (migrate / fillDefaults), JUSTICE_EXTRACT (GetCombatPower), VISUALS_EXTRACT (buildWeapon). The world (bareWorld,
-- notices, indexOf, C0, U) is tools/fixtures/dev2_combat_world.luau.

------------------------------------------------------------------ 1. Config: bare-hands numbers
runGroup("config", function()
	local C = C0
	check(C.Data.Defaults.WeaponTier == 0 and C.Data.Defaults.WeaponOwnedMask == 0,
		"a new save starts bare-handed: WeaponTier 0, nothing owned", show({ C.Data.Defaults.WeaponTier, C.Data.Defaults.WeaponOwnedMask }))
	check(C.Data.Version == 3, "save Version stays 3 (A23-34 and A23-69's Stats are additive)", C.Data.Version)
	check(U.Damage == 4 and U.Range == 7 and U.Interval == 0.8 and U.AimCone == 90, "Combat.Unarmed = 4 / 7 / 0.8 s / 90 deg (A23-61 front half)", show(U))
	check(U.Range > C.Monsters.AttackRange, "the punch reaches a slime that attacks me (Range 7 > monster reach 5.5)",
		C.Monsters.AttackRange)
	check(C.WeaponDamage(0, 1, 0) == 4 and C.WeaponDamage(0, 1, 5) == 4, "bare hands = Unarmed.Damage, no scroll +N",
		show({ C.WeaponDamage(0, 1, 0), C.WeaponDamage(0, 1, 5) }))
	check(math.abs(C.WeaponDamage(0, 11, 0) - 4 * 1.2) < 1e-9, "bare hands still grow 2% a level", C.WeaponDamage(0, 11, 0))
	check(C.WeaponDamage(1, 1, 0) == 8 and C.WeaponDamage(2, 1, 0) == 15, "armed damage unchanged (T1 8, T2 15)")
	-- power: Lv1 bare hands = 0, levels add, every weapon is above bare hands, armed numbers are the old ones
	check(C.CombatPower(1, 0, 0) == 0, "combat power at Lv1 bare-handed = 0 (A23-34)", C.CombatPower(1, 0, 0))
	check(C.CombatPower(2, 0, 0) == 12 and C.CombatPower(3, 0, 0) == 23, "Lv2 bare 12, Lv3 bare 23",
		show({ C.CombatPower(2, 0, 0), C.CombatPower(3, 0, 0) }))
	check(C.CombatPower(1, 0, 7) == 0, "bare hands ignore a +N")
	local rising, above, same = true, true, true
	for level = 1, C.Levels.MaxLevel do
		if level > 1 and C.CombatPower(level, 0, 0) < C.CombatPower(level - 1, 0, 0) then rising = false end
		for tier = 1, C.MaxWeaponTier do
			if C.CombatPower(level, tier, 0) <= C.CombatPower(level, 0, 0) then above = false end
			for _, e in { 0, 3, 10 } do
				if C.CombatPower(level, tier, e) ~= math.floor(C.PowerOf(level, tier, 1, e) * 10 + 0.5) then same = false end
			end
		end
	end
	check(rising, "bare power never drops with a level")
	check(above, "any weapon is above bare hands at the same level")
	check(same, "armed combat power = floor(PowerOf x 10 + 0.5) as before (BB4 numbers kept)")
	check(C.CombatPower(1, 1, 0) == 283 and C.CombatPower(2, 1, 0) == 300, "T1 Lv1 283 / Lv2 300",
		show({ C.CombatPower(1, 1, 0), C.CombatPower(2, 1, 0) }))
	-- best usable weapon: 0 = bare hands
	local function m(...)
		local x = 0
		for _, t in { ... } do x = bit32.bor(x, bit32.lshift(1, t - 1)) end
		return x
	end
	for _, case in {
		{ 0, 1, 0, "nothing owned -> 0" }, { nil, 1, 0, "no mask -> 0" }, { m(3), 1, 0, "only T3 at Lv1 -> 0" },
		{ m(3), 5, 3, "only T3 at Lv5 -> T3" }, { m(2), 1, 2, "only T2 (bought first) -> T2" },
		{ m(1, 8), 1, 8, "T1 + jackpot T8 -> T8 (by damage)" }, { m(1), 1, 1, "T1 -> T1" },
	} do
		check(C.BestUsableWeapon(case[1], case[2]) == case[3], "BestUsableWeapon: " .. case[4], C.BestUsableWeapon(case[1], case[2]))
	end
	check(C.WeaponName(0, "Mage", "Halo") == C.Text.BareHands and C.Text.BareHands == "Bare hands", "WeaponName(0) = Bare hands",
		C.WeaponName(0, "Mage", "Halo"))
	check(C.WeaponName(1, "Warrior", "Halo") == "Twig", "WeaponName(1) unchanged")
	check(C.WeaponArtKey(0, "Mage", "Halo") == nil and C.WeaponArtKey(1, "Mage", "Halo") == "Weapon_Mage_T1",
		"WeaponArtKey: bare hands have no icon (nil), T1 keeps its key", tostring(C.WeaponArtKey(0, "Mage", "Halo")))
	-- the punch profile
	for _, id in C.ClassOrder do
		local p0 = C.AttackProfile(id, 0, "Halo")
		check(p0.Style == "Punch" and p0.Unarmed == true and p0.Id == id and p0.Pattern == "Multi" and p0.Targets == 1
			and p0.Range == 7 and p0.SwingInterval == 0.8 and p0.AimCone == 90 and p0.Damage == 1 and p0.Ranged == false
			and (p0.PvPMult or 1) == 1, "AttackProfile(" .. id .. ", 0) = the shared punch", show(p0))
		check(C.AttackProfile(id, 1, "Halo") == C.Classes[id] and C.AttackProfile(id, 8, "Horns") == C.Classes[id],
			"AttackProfile(" .. id .. ", weapon) = the class row itself")
		check(C.AttackProfile(id, 0) == C.AttackProfile(id, 0), "the punch profile is cached (no table per swing)")
	end
	-- the blacksmith's hit count: every class and faction punches a slime 5 times; T1 is a clear upgrade
	for _, id in C.ClassOrder do
		for _, f in { "Halo", "Horns", "Neutral" } do
			check(C.SwingHitsToKill(0, 1, id, "Slime", f) == 5, "SwingHitsToKill bare " .. id .. "/" .. f .. " = 5",
				C.SwingHitsToKill(0, 1, id, "Slime", f))
		end
	end
	check(C.SwingHitsToKill(1, 1, "Warrior", "Slime", "Halo") == 3 and C.SwingHitsToKill(1, 1, "Mage", "Slime", "Halo") == 2,
		"T1 hit counts unchanged (Warrior 3, Mage 2)")
	-- the M1_1 gift and the texts (KO + EN pairs, same placeholders)
	check(C.StoryQuests.Defs.M1_1.GiveWeapon == 1, "M1_1 GiveWeapon = tier 1")
	local function same(a, b)
		local _, na = string.gsub(a or "", "%%[sd]", "")
		local _, nb = string.gsub(b or "", "%%[sd]", "")
		return type(a) == "string" and type(b) == "string" and a ~= "" and b ~= "" and na == nb
	end
	for _, pair in {
		{ C.Text, "BareHands" }, { C.Text, "WeaponFromQuest" }, { C.Loot.Text, "JackpotEquip" },
		{ C.Loot.Text, "FirstScrollBare" }, { C.Loot.Text, "FirstWeapon" }, { C.Loot.Text, "FirstWeaponBag" },
		{ C.Loot.Text, "BareEquip" }, { C.Tutorial.Text, "VisitBlacksmith" }, { C.Tutorial.Text, "Claimed" },
		{ C.Tutorial.Text, "AutoClaimed" }, { C.Tutorial.Text, "ClaimedArmed" }, { C.Tutorial.Text, "AutoClaimedArmed" },
		{ C.Tutorial.Text, "VisitBlacksmithArmed" },
	} do
		check(same(pair[1][pair[2]], pair[1][pair[2] .. "En"]), "text " .. pair[2] .. " has KO + EN with the same placeholders")
	end
	check(not has(C.Tutorial.Text.Claimed, "Check the gear") and has(C.Tutorial.Text.Claimed, "first weapon"),
		"first-mission line points to the free first weapon")
	check(C.WeaponInfo[1].Source ~= "처음부터 가진 무기" and has(C.WeaponInfo[1].Source, "Blacksmith"),
		"tier 1 source = the blacksmith's gift", C.WeaponInfo[1].Source)
end)

------------------------------------------------------------------ 2. save data (DataService migrate + fillDefaults)
runGroup("save", function()
	local w = newWorld({ Time = 1791342000 })
	local migrate, fill = execute("DataService.extract", DATA_EXTRACT, w:Env(), w.Config, w.Util)
	local who = { Name = "P1" }
	local function load(rec)
		local d = deepCopy(rec)
		migrate(d, who)
		fill(d, "P1")
		return d
	end
	local function row(version, fields)
		local r = { Version = version, Level = 1, Faction = "Halo", Class = "Warrior", ClassChosen = true, TutorialStep = 99 }
		for k, v in fields or {} do r[k] = v end
		return r
	end
	local fresh = deepCopy(w.Config.Data.Defaults)
	fill(fresh, "P1")
	check(fresh.WeaponTier == 0 and fresh.WeaponOwnedMask == 0, "a brand-new record stays bare-handed", show({ fresh.WeaponTier, fresh.WeaponOwnedMask }))
	for _, case in {
		{ row(3, { WeaponTier = 0, WeaponOwnedMask = 0 }), 0, 0, "v3 bare-handed save kept (no bit forced)" },
		{ row(3, { WeaponTier = 0, WeaponOwnedMask = 2 }), 0, 2, "v3 stored tier 0 is valid: kept even with a weapon owned" },
		{ row(3, { WeaponTier = 2, WeaponOwnedMask = 2 }), 2, 2, "v3 save that bought T2 first keeps only T2" },
		{ row(3, { WeaponTier = 1, WeaponOwnedMask = 1 }), 1, 1, "v3 legacy save with T1 unchanged" },
		{ row(3, { WeaponTier = 3, WeaponOwnedMask = 7, Level = 5 }), 3, 7, "v3 save with T1-T3 unchanged" },
		{ row(3, { WeaponTier = 2, WeaponOwnedMask = 0 }), 2, 2, "v3 equipped tier is owned (bit added)" },
		{ row(2, { WeaponTier = 2 }), 2, 3, "v2 save without a mask keeps its T1 (A23-4) + the equipped T2" },
		{ row(2, {}), 1, 1, "v2 save without weapon fields = T1 (pre-A23-34 saves always had it)" },
		{ row(2, { WeaponTier = 0 }), 1, 1, "v2 tier 0 = its T1" },
		{ row(2, { WeaponTier = 3, WeaponOwnedMask = 4, Level = 5 }), 3, 5, "v2 mask without T1 gets T1 back" },
		{ row(1, { SwordTier = 3, Level = 5 }), 3, 5, "v1 SwordTier 3 -> T3 + T1" },
		{ row(3, { WeaponTier = 0, WeaponOwnedMask = 0 / 0 }), 0, 0, "v3 NaN mask -> nothing owned" },
		{ row(3, { WeaponTier = 0, WeaponOwnedMask = -1 }), 0, 0, "v3 negative mask -> nothing owned" },
		{ row(3, { WeaponTier = 2, WeaponOwnedMask = 1.5 }), 2, 2, "v3 fraction mask -> only the equipped bit" },
		{ row(3, { WeaponTier = 2, WeaponOwnedMask = 4294967295 }), 2, 2, "v3 0xFFFFFFFF -> only the equipped bit" },
		{ row(3, { WeaponTier = 9, WeaponOwnedMask = 0 }), 0, 0, "v3 tier 9 with nothing owned -> bare hands" },
		{ row(3, { WeaponTier = -1, WeaponOwnedMask = 6 }), 2, 6, "v3 tier -1, owns T2+T3 at Lv1 -> T2" },
		{ row(3, { WeaponTier = 0 / 0, WeaponOwnedMask = 6, Level = 5 }), 3, 6, "v3 NaN tier, owns T2+T3 at Lv5 -> T3" },
		{ row(3, { WeaponTier = 1.5, WeaponOwnedMask = 1 }), 1, 1, "v3 tier 1.5 with T1 -> T1" },
	} do
		local d = load(case[1])
		check(d.WeaponTier == case[2] and d.WeaponOwnedMask == case[3], "load: " .. case[4],
			show({ tier = d.WeaponTier, mask = d.WeaponOwnedMask }))
		local again = load(d)
		check(again.WeaponTier == d.WeaponTier and again.WeaponOwnedMask == d.WeaponOwnedMask and again.Version == 3,
			"load again: " .. case[4] .. " (idempotent, Version 3)")
	end
end)

------------------------------------------------------------------ 3. the punch (CombatService.Swing)
runGroup("punch", function()
	for _, id in C0.ClassOrder do
		local w = bareWorld()
		local p = w:Join(101, { Class = id })
		local near = w:Monster("Slime", 4)
		local second = w:Monster("Slime", 6, 1)
		local far = w:Monster("Slime", 9)
		local behind = w:Monster("Slime", -3)
		local fx0 = #w.Fx
		w.Combat.Swing(p, true)
		w:Flush()
		check(w:Dealt(near) == 2 and w:Dealt(second) == 0 and w:Dealt(far) == 0 and w:Dealt(behind) == 0,
			id .. " bare-handed: one punch = 2 damage to the nearest slime in front only",
			show({ w:Dealt(near), w:Dealt(second), w:Dealt(far), w:Dealt(behind) }))
		check(#w.Mana == 0, id .. " punch spends no MP", #w.Mana)
		local sw = w:FxOf("Swing", fx0)
		local d = sw[1] and sw[1].Data or {}
		check(#sw == 1 and d.Style == "Punch" and d.Class == id and d.ContactDelay == 0.15 and d.LaunchDelay == nil
			and d.FlightTime == nil and d.Radius == 0 and #(d.Targets or {}) == 1, id .. " Fx Swing: Style Punch, contact 0.15, no projectile",
			show({ n = #sw, Style = d.Style, Class = d.Class, C = d.ContactDelay, L = d.LaunchDelay, F = d.FlightTime, R = d.Radius }))
		-- the punch shoves its target at the punch contact (0.15 s), not at the class contact
		w:Advance(0.14)
		check(#w.Shoves == 0, id .. " no shove before the punch contact", #w.Shoves)
		w:Advance(0.02)
		check(#w.Shoves == 1 and w.Shoves[1].Rec == near, id .. " the punch shoves at contact 0.15 s", #w.Shoves)
		local hand = p.Character:FindFirstChild("RightHand")
		check(d.From ~= nil and hand ~= nil and d.From.X == hand.Position.X and d.From.Y == hand.Position.Y,
			id .. " punch Fx starts at the right hand", show(d.From))
		-- the punch interval (0.8 s), whatever the class interval is
		w:Advance(0.34) -- 0.5 s after the first punch
		w.Combat.Swing(p, true)
		w:Flush()
		check(w:Dealt(near) == 2, id .. " no second punch 0.5 s later (punch interval 0.8 s)", w:Dealt(near))
		w:Advance(0.35)
		w.Combat.Swing(p, true)
		w:Flush()
		check(w:Dealt(near) == 4, id .. " the next punch after 0.85 s", w:Dealt(near))
		-- a slime dies in 5 punches
		for _ = 1, 3 do
			w:Advance(0.85)
			w.Combat.Swing(p, true)
		end
		w:Flush()
		check(near.Alive == false and w:Dealt(near) == 10, id .. " a slime falls to the 5th punch", show({ near.Alive, w:Dealt(near) }))
		-- A23-61 server aim (검수 2026-10-07): with nothing in front, the punch turns to the slime 3 studs behind and hits it
		second.Alive, far.Alive = false, false
		w:Advance(1)
		w.Combat.Swing(p, true)
		w:Flush()
		check(w:Dealt(behind) == 2, id .. " nothing in front: the punch turns to the slime behind (A23-61 server aim)", w:Dealt(behind))
		-- a whiff (nothing within 7) still shows the punch, aimed 7 studs ahead (of where I face now)
		local fx1 = #w.Fx
		behind.Alive = false
		p.Character:FindFirstChild("HumanoidRootPart").CFrame = { LookVector = vec(0, 0, -1) }
		w:Advance(1)
		w.Combat.Swing(p, true)
		w:Flush()
		local wh = w:FxOf("Swing", fx1)[1]
		check(wh ~= nil and wh.Data.Style == "Punch" and #wh.Data.Hits == 0 and wh.Data.Targets[1].Z == -7,
			id .. " a punch whiff flies 7 ahead", show(wh and wh.Data.Targets))
	end
	-- Horns +15% still rounds to 2; a weapon brings the class back
	local w = bareWorld()
	local h = w:Join(102, { Class = "Warrior", Faction = "Horns" })
	local s1 = w:Monster("Slime", 4)
	w.Combat.Swing(h, true)
	w:Flush()
	check(w:Dealt(s1) == 2, "a Horns punch: 4 x 1.15 x 0.5 = 2", w:Dealt(s1))
	local w2 = bareWorld()
	local a = w2:Join(103, { Class = "Archer", Tier = 1, Mask = 1 })
	local m1, m2 = w2:Monster("Slime", 12), w2:Monster("Slime", 20, 2)
	local fx0 = #w2.Fx
	w2.Combat.Swing(a, true)
	w2:Flush()
	local d = w2:FxOf("Swing", fx0)[1]
	check(w2:Dealt(m1) > 0 and w2:Dealt(m2) > 0 and d and d.Data.Style == nil and d.Data.LaunchDelay ~= nil,
		"armed Archer: two targets at 30, arrows (no Style)", show({ w2:Dealt(m1), w2:Dealt(m2), d and d.Data.Style }))
	local w3 = bareWorld()
	local mage = w3:Join(104, { Class = "Mage", Tier = 1, Mask = 1 })
	w3:Monster("BigSlime", 20)
	w3.Combat.Swing(mage, true)
	w3:Flush()
	check(#w3.Mana == 1 and w3.Mana[1].Cost == C0.Vitals.MageSwingCost, "armed Mage pays MP for the orb", #w3.Mana)
	w3:Advance(0.43)
	check(#w3.Shoves == 0, "armed Mage: no shove before its orb lands (0.44 s)", #w3.Shoves)
	w3:Advance(0.02)
	check(#w3.Shoves == 1, "armed Mage: the shove at the class contact 0.44 s", #w3.Shoves)
end)

------------------------------------------------------------------ 4. hit numbers (monster / PvP / skill Q)
runGroup("hits", function()
	local w = bareWorld({ Hit = true })
	local a = w:Join(201, { Class = "Archer", Faction = "Halo" })
	local v = w:Join(202, { Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, -4) })
	local bare = C0.AttackProfile("Archer", 0, "Halo")
	local withShape = w.Combat.ComputePvPHit(a, v, bare)
	local classHit = w.Combat.ComputePvPHit(a, v)
	check(math.abs(withShape / classHit - 1 / (0.55 * 0.85)) < 1e-9,
		"PvP punch: no class multiplier (0.55) and no ranged factor (0.85)", show({ withShape, classHit }))
	check(math.abs(w.Combat.ComputeMonsterHit(a, false, bare) - 4) < 1e-9 and math.abs(w.Combat.ComputeMonsterHit(a, false) - 4 * 0.55) < 1e-9,
		"monster hit: punch 4, skill base (class row) 4 x 0.55", show({ w.Combat.ComputeMonsterHit(a, false, bare), w.Combat.ComputeMonsterHit(a, false) }))
	-- a missing WeaponTier attribute reads as bare hands (never a free tier 1)
	a:SetAttribute("WeaponTier", nil)
	check(math.abs(w.Combat.ComputeMonsterHit(a, false, bare) - 4) < 1e-9, "no WeaponTier attribute = bare hands (4)",
		w.Combat.ComputeMonsterHit(a, false, bare))
	a:SetAttribute("WeaponTier", 0)
	-- a manual punch on a player uses the punch numbers too
	local hum = v.Character:FindFirstChildOfClass("Humanoid")
	local before = hum.Health
	w.Combat.Swing(a, true)
	w:Flush()
	local want = w.Util.RoundDamage(withShape * 0.5)
	check(before - hum.Health == want, "a punch on a player = RoundDamage(punch PvP hit x 0.5)", show({ before - hum.Health, want }))
	-- 검수 2026-10-06: in PvP a bare-handed attacker (punch, and the class skill) is weaker per second than every class's
	-- tier-1 attack, against any opponent (tiers 0-8) at the same level: the weapon floor 0.8 never applies to bare hands
	local wm = bareWorld()
	local bad, rows = {}, 0
	local function mk(id, cls, tier, fac)
		local pl = wm:Join(id, { Class = cls, Faction = fac, Tier = tier, Mask = tier > 0 and bit32.lshift(1, tier - 1) or 0 })
		return pl
	end
	local bareA = mk(901, "Warrior", 0, "Horns")
	local t1 = { Warrior = mk(902, "Warrior", 1, "Horns"), Mage = mk(903, "Mage", 1, "Horns"), Archer = mk(904, "Archer", 1, "Horns") }
	local bareQ = { Warrior = bareA, Mage = mk(905, "Mage", 0, "Horns"), Archer = mk(906, "Archer", 0, "Horns") }
	local victim = mk(907, "Warrior", 1, "Halo")
	for _, level in { 1, 15, 30 } do
		for _, pl in { bareA, victim, t1.Warrior, t1.Mage, t1.Archer, bareQ.Mage, bareQ.Archer } do pl:SetAttribute("Level", level) end
		for _, vt in { 0, 1, 2, 3, 4, 5, 6, 8 } do
			victim:SetAttribute("WeaponTier", vt)
			local bareDps = wm.Combat.ComputePvPHit(bareA, victim, C0.AttackProfile("Warrior", 0, "Horns")) * 0.5 / U.Interval
			for _, id in C0.ClassOrder do
				local c = C0.Classes[id]
				local t1Dps = wm.Combat.ComputePvPHit(t1[id], victim, c) * 0.5 / c.SwingInterval
				rows += 1
				if not (bareDps < t1Dps) then table.insert(bad, string.format("Lv%d vs T%d %s: bare %.2f >= T1 %.2f", level, vt, id, bareDps, t1Dps)) end
				-- the class skill bare-handed vs tier 1 (same class): never stronger either
				local qBare, qT1 = wm.Combat.ComputePvPHit(bareQ[id], victim), wm.Combat.ComputePvPHit(t1[id], victim)
				if not (qBare < qT1) then table.insert(bad, string.format("Lv%d vs T%d %s skill: bare %.2f >= T1 %.2f", level, vt, id, qBare, qT1)) end
			end
		end
	end
	check(rows == 72 and #bad == 0, "PvP: bare hands per second < every class's tier 1 (Lv1/15/30 x opponent T0-T8), skill too",
		bad[1] or rows)
	-- skill Q bare-handed: the class skill (class range and multiplier)
	local w2 = bareWorld()
	local q = w2:Join(203, { Class = "Archer" })
	local target = w2:Monster("BigSlime", 20)
	q:SetAttribute("Mana", 100)
	w2.Combat.Release(q, false)
	w2:Flush()
	check(w2:Dealt(target) == w2.Util.RoundDamage(4 * 0.55 * 6), "bare Archer Q at 20 studs: RoundDamage(4 x 0.55 x 6)", w2:Dealt(target))
	local w3 = bareWorld()
	local wq = w3:Join(204, { Class = "Warrior" })
	local s = w3:Monster("Slime", 3)
	w3.Combat.Release(wq, false)
	w3:Flush()
	check(w3:Dealt(s) == 24 and s.Alive == false, "bare Warrior Q (RoundDamage(4 x 6) = 24) one-shots a slime", w3:Dealt(s))
end)

------------------------------------------------------------------ 5. auto combat bare-handed
runGroup("auto", function()
	local w = bareWorld()
	local p = w:Join(301, { Class = "Archer", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true, Mana = 0 } })
	local far = w:Monster("Slime", 20)
	local fx0 = #w.Fx
	w:AutoTick()
	check(#w:FxOf("Swing", fx0) == 0 and w:Dealt(far) == 0, "auto never swings at a slime 20 away bare-handed (punch reach 7)")
	-- the auto tick did not start a swing cooldown: a manual punch right now lands
	local near = w:Monster("Slime", 4)
	w.Combat.Swing(p, true)
	w:Flush()
	check(w:Dealt(near) == 2, "no hidden whiff cooldown from the auto tick", w:Dealt(near))
	-- auto yields to my own presses for the punch interval + 0.3 s (1.1 s)
	w:Advance(0.05)
	w.Remotes.Swing.OnServerEvent:Fire(p) -- a manual press (cooldown: refused, but it counts as my own action)
	w:Advance(0.85) -- 0.9 s after the punch: the cooldown is over, auto still waits
	local dealt = w:Dealt(near)
	w:AutoTick()
	check(w:Dealt(near) == dealt, "auto waits 1.1 s after my own press (punch interval + 0.3)", w:Dealt(near) - dealt)
	w:Advance(0.3)
	w:AutoTick()
	check(w:Dealt(near) == dealt + 2, "then auto punches", w:Dealt(near) - dealt)
	-- auto Q keeps the class reach (Archer 30) bare-handed
	local w2 = bareWorld()
	local q = w2:Join(302, { Class = "Archer", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true, Mana = 100 } })
	local big = w2:Monster("BigSlime", 20)
	w2:AutoTick()
	check(w2:Dealt(big) == w2.Util.RoundDamage(4 * 0.55 * 6), "auto skill Q fires at 20 studs bare-handed (class reach)", w2:Dealt(big))
	check(q ~= nil, "joined")
end)

------------------------------------------------------------------ 6. the blacksmith: buy / sell / tier 1
runGroup("shop", function()
	local w = bareWorld()
	local p, d = w:Join(401, { Carried = 160, Bank = 0 })
	local n0 = #w.Notices
	w:Buy(p, 1)
	check(d.WeaponOwnedMask == 0 and d.WeaponTier == 0 and indexOf(notices(w, p, n0), C0.Text.WeaponFromQuest) ~= nil,
		"tier 1 is not sold (it comes from M1_1): refused with a notice", show(notices(w, p, n0)))
	w:Buy(p, 2)
	check(d.WeaponOwnedMask == 2 and d.WeaponTier == 2 and d.CarriedGold == 10 and p:GetAttribute("WeaponTier") == 2,
		"a bare-handed player buys the wood weapon (150) and holds it", show({ d.WeaponOwnedMask, d.WeaponTier, d.CarriedGold }))
	check(d.BlacksmithVisited == true, "a purchase counts as the visit")
	w:Sell(p, 2)
	check(d.WeaponOwnedMask == 0 and d.WeaponTier == 0 and d.CarriedGold == 25,
		"selling the only weapon: back to bare hands (+15), never a free T1", show({ d.WeaponOwnedMask, d.WeaponTier, d.CarriedGold }))
	-- owning T1: selling the equipped T2 equips T1
	local w2 = bareWorld()
	local q, e = w2:Join(402, { Tier = 2, Mask = 3 })
	w2:Sell(q, 2)
	check(e.WeaponOwnedMask == 1 and e.WeaponTier == 1, "selling the equipped T2 with T1 owned -> T1", show({ e.WeaponOwnedMask, e.WeaponTier }))
	-- the fallback keeps the level rule (A23-28): T1 + T2 + T3 owned, T2 held and sold -> Lv1: T1 (T3 needs Lv5), Lv5: T3
	for _, rowL in { { Level = 1, Want = 1 }, { Level = 5, Want = 3 } } do
		local wl = bareWorld()
		local u, k = wl:Join(405 + rowL.Level, { Level = rowL.Level, Tier = 2, Mask = 7 })
		wl:Sell(u, 2)
		check(k.WeaponOwnedMask == 5 and k.WeaponTier == rowL.Want and u:GetAttribute("WeaponTier") == rowL.Want,
			"selling the equipped T2 (T1 + T3 owned) at Lv" .. rowL.Level .. " -> T" .. rowL.Want, show({ k.WeaponOwnedMask, k.WeaponTier }))
	end
	-- bare-handed with an owned T3 below its level (a level reset): T3 can still be sold
	local w3 = bareWorld()
	local r, f = w3:Join(403, { Tier = 0, Mask = 4, Level = 1 })
	w3:Sell(r, 3)
	check(f.WeaponOwnedMask == 0 and f.WeaponTier == 0 and f.CarriedGold == 80, "bare-handed seller of an unusable T3 (+80)",
		show({ f.WeaponOwnedMask, f.WeaponTier, f.CarriedGold }))
	-- the anvil prompt finishes an active M1_1 before the shop opens
	local w4 = bareWorld()
	local s, g = w4:Join(404, { Level = 2 })
	w4.Story.Refresh(s)
	check(g.Story and g.Story.Main.Id == "M1_1", "M1_1 is the active main quest after the first mission", show(g.Story and g.Story.Main))
	local fired0 = #w4.Fired
	local remote = w4.Net.Get("OpenPanel")
	local origFire, atFire = remote.FireClient, nil
	remote.FireClient = function(r, pl, payload)
		if pl == s and payload == "WeaponShop" then atFire = { s:GetAttribute("WeaponTier"), s:GetAttribute("WeaponOwnedMask") } end
		return origFire(r, pl, payload)
	end
	w4:Anvil(s)
	remote.FireClient = origFire
	check(atFire ~= nil and atFire[1] == 1 and atFire[2] == 1, "the M1_1 gift is in hand when the shop window opens",
		show(atFire or {}))
	local opened = nil
	for i = fired0 + 1, #w4.Fired do
		if w4.Fired[i].Remote == "OpenPanel" then opened = w4.Fired[i] end
	end
	check(opened ~= nil and opened.Payload == "WeaponShop", "the anvil opens the weapon shop")
	check(g.WeaponTier == 1 and g.WeaponOwnedMask == 1 and g.Story.Done.M1_1 == true,
		"the M1_1 gift is in hand by the time the shop opens", show({ g.WeaponTier, g.WeaponOwnedMask }))
end)

------------------------------------------------------------------ 7. the M1_1 gift (both orders)
runGroup("gift", function()
	-- (a) the free tier 1 first, then the wood weapon
	local w = bareWorld()
	local p, d = w:Join(501, { Level = 2, Carried = 150 })
	w.Story.Refresh(p)
	check(d.Story.Main.Id == "M1_1" and d.WeaponTier == 0, "M1_1 active, still bare-handed")
	local n0, fx0 = #w.Notices, #w.Fx
	w.PS.SetStat(p, "BlacksmithVisited", true)
	w.Story.Refresh(p)
	w:Flush()
	local list = notices(w, p, n0)
	local line = string.format(C0.Loot.Text.FirstWeapon, "Twig", "12", "300")
	check(d.WeaponOwnedMask == 1 and d.WeaponTier == 1 and p:GetAttribute("WeaponTier") == 1 and d.Story.Done.M1_1 == true,
		"(a) M1_1 done: tier 1 owned and equipped", show({ d.WeaponOwnedMask, d.WeaponTier }))
	check(p:GetAttribute("WeaponOwnedMask") == 1, "(a) the ownership attribute follows (item list / telemetry read it)",
		p:GetAttribute("WeaponOwnedMask"))
	check(d.WeaponSeq and d.WeaponSeq[1] == 1 and d.ItemSeqNext == 1, "(a) the gift is noted once in '얻은 순' (no double count)",
		show({ d.WeaponSeq and d.WeaponSeq[1], d.ItemSeqNext }))
	local iFinish = indexOf(list, C0.StoryQuests.Defs.M1_1.Finish)
	local iWeapon = indexOf(list, line)
	check(iWeapon ~= nil, "(a) notice 'You got your first weapon, [Twig]! Power 12 → 300' (Lv2)", show(list))
	check(iFinish ~= nil and iWeapon ~= nil and iFinish < iWeapon, "(a) the weapon line comes after the blacksmith's line")
	check(#w:FxOf("Upgrade", fx0) == 1 and w:FxOf("Upgrade", fx0)[1].Data.Tier == 1, "(a) the equip Fx (Upgrade, Tier 1)")
	check(w.Justice.GetCombatPower(p) == 300, "(a) power attribute source: Lv2 T1 = 300", w.Justice.GetCombatPower(p))
	w:Buy(p, 2)
	check(d.WeaponOwnedMask == 3 and d.WeaponTier == 2 and d.CarriedGold == 0, "(a) then the wood weapon: T1 + T2, T2 held")
	-- paid once: a second grant / refresh / rejoin changes nothing (T2 held now, so a repeat would say the bag line)
	local n1, seqBefore = #w.Notices, d.ItemSeqNext
	check(w.Loot.GrantFirstWeapon(p) == nil, "(a) GrantFirstWeapon again: nothing")
	w.Story.Refresh(p)
	w.PS.PlayerReady:Fire(p, d) -- the join safety net
	w:Flush()
	local again = notices(w, p, n1)
	check(indexOf(again, line) == nil and indexOf(again, string.format(C0.Loot.Text.FirstWeaponBag, "Twig")) == nil,
		"(a) no second weapon line (neither the equip line nor the bag line)", show(again))
	check(d.WeaponOwnedMask == 3 and d.WeaponTier == 2 and d.ItemSeqNext == seqBefore, "(a) nothing changed by a repeat (mask, held weapon, '얻은 순')",
		show({ d.WeaponOwnedMask, d.WeaponTier, d.ItemSeqNext, seqBefore }))

	-- (b) the wood weapon first, then the free tier 1 (in the bag, no power line)
	local w2 = bareWorld()
	local q, e = w2:Join(502, { Level = 2, Carried = 150 })
	w2.Story.Refresh(q)
	w2:Buy(q, 2)
	check(e.WeaponOwnedMask == 2 and e.WeaponTier == 2 and e.BlacksmithVisited == true, "(b) bought T2 bare-handed first")
	local m0 = #w2.Notices
	w2.Story.Refresh(q)
	w2:Flush()
	local list2 = notices(w2, q, m0)
	check(e.WeaponOwnedMask == 3 and e.WeaponTier == 2, "(b) M1_1 adds T1 to the bag, T2 stays in hand", show({ e.WeaponOwnedMask, e.WeaponTier }))
	check(q:GetAttribute("WeaponOwnedMask") == 3 and e.WeaponSeq[1] > e.WeaponSeq[2],
		"(b) the bag line points to a weapon the item list shows (attribute 3, T1 the newest gain)",
		show({ q:GetAttribute("WeaponOwnedMask"), e.WeaponSeq[1], e.WeaponSeq[2] }))
	check(indexOf(list2, string.format(C0.Loot.Text.FirstWeaponBag, "Twig")) ~= nil, "(b) the bag line", show(list2))
	for _, t in list2 do
		check(not has(t, "Power "), "(b) no power line when the gift is not equipped", t)
	end

	-- (c) a save from before A23-34 (owns T1) finishing M1_1: nothing, no line
	local w3 = bareWorld()
	local r, f = w3:Join(503, { Level = 3, Tier = 1, Mask = 1 })
	w3.Story.Refresh(r)
	local k0 = #w3.Notices
	w3.PS.SetStat(r, "BlacksmithVisited", true)
	w3.Story.Refresh(r)
	local list3 = notices(w3, r, k0)
	check(f.Story.Done.M1_1 == true and f.WeaponOwnedMask == 1 and f.WeaponTier == 1, "(c) legacy save: M1_1 done, nothing added")
	for _, t in list3 do
		check(not has(t, "first weapon") and not has(t, "also gave you"), "(c) no gift line for a save that owns T1", t)
	end

	-- (d) the join safety net: M1_1 finished but the gift never arrived
	local w4 = bareWorld()
	local s, g = w4:Join(504, { Level = 2, Data = { Story = { Main = { Id = "" }, Subs = {}, Done = { M1_1 = true }, Pick = {},
		First = { Migrated = true } } } })
	check(s:GetAttribute("WeaponOwnedMask") == 1 and g.WeaponSeq[1] == 1, "(d) attribute + '얻은 순' follow the join payment",
		show({ s:GetAttribute("WeaponOwnedMask"), g.WeaponSeq[1] }))
	check(g.WeaponOwnedMask == 1 and g.WeaponTier == 1, "(d) a finished M1_1 that never paid is paid at the join",
		show({ g.WeaponOwnedMask, g.WeaponTier }))
	check(s ~= nil, "joined")
	-- (e) a Mage gets the class weapon name; a Horns Lv1 shows 0 -> 283
	local w5 = bareWorld()
	local t5, h = w5:Join(505, { Class = "Mage", Faction = "Horns", Level = 1 })
	w5.Story.Refresh(t5)
	local j0 = #w5.Notices
	w5.PS.SetStat(t5, "BlacksmithVisited", true)
	w5.Story.Refresh(t5)
	check(indexOf(notices(w5, t5, j0), string.format(C0.Loot.Text.FirstWeapon, "Dry Staff", "0", "283")) ~= nil,
		"(e) Lv1 Mage: 'You got your first weapon, [Dry Staff]! Power 0 → 283'", show(notices(w5, t5, j0)))
	check(h.WeaponTier == 1, "(e) equipped")
	-- (f) paid by an earlier PlayerReady handler (StoryQuestService starts before LootService): still noted once
	local w6 = bareWorld()
	local u, k = w6:Join(506, { Level = 2, BeforeReady = function(pl) w6.Loot.GrantFirstWeapon(pl) end })
	check(k.WeaponOwnedMask == 1 and k.WeaponTier == 1 and k.WeaponSeq and k.WeaponSeq[1] == 1 and k.ItemSeqNext == 1,
		"(f) a gift paid before the mask watcher exists is still noted in '얻은 순' (once)",
		show({ k.WeaponOwnedMask, k.WeaponSeq and k.WeaponSeq[1], k.ItemSeqNext }))
	check(u ~= nil, "joined")
end)

------------------------------------------------------------------ 8. drops and the level fit while bare-handed
runGroup("drops", function()
	-- the slime jackpot before the first weapon: equipped at once
	local w = bareWorld()
	local p, d = w:Join(601, { Level = 1, Tutorial = 0 })
	local n0 = #w.Notices
	w:Drop(p, "Slime", nil, 0)
	check(bit32.btest(d.WeaponOwnedMask, 128) and d.WeaponTier == 8, "a bare-handed jackpot (T8) is equipped at once",
		show({ d.WeaponOwnedMask, d.WeaponTier }))
	local jname = C0.WeaponName(8, "Warrior", "Halo")
	local line = string.format(C0.Loot.Text.JackpotEquip, jname, "0", tostring(C0.CombatPower(1, 8, 0)))
	check(indexOf(notices(w, p, n0), line) ~= nil, "one jackpot line: equipped with the power change", show(notices(w, p, n0)))
	check(indexOf(notices(w, p, n0), string.format(C0.Loot.Text.JackpotSelf, jname)) == nil,
		"no 'equip it in the menu' line for a weapon already in hand")
	-- an armed player's jackpot stays in the bag
	local w2 = bareWorld()
	local q, e = w2:Join(602, { Level = 1, Tier = 2, Mask = 2, Tutorial = 0 })
	w2:Drop(q, "Slime", nil, 0)
	check(bit32.btest(e.WeaponOwnedMask, 128) and e.WeaponTier == 2, "an armed player's jackpot is not equipped", show({ e.WeaponTier }))
	check(indexOf(notices(w2, q, 0), string.format(C0.Loot.Text.JackpotSelf, C0.WeaponName(8, "Warrior", "Halo"))) ~= nil,
		"an armed player's jackpot keeps the 'equip it in the menu' line")
	-- a weapon above the level is owned but not equipped
	local w3 = bareWorld()
	local r, f = w3:Join(603, { Level = 3, Tutorial = 0 })
	w3:Drop(r, "Goblin", { W4 = true })
	check(bit32.btest(f.WeaponOwnedMask, 8) and f.WeaponTier == 0, "a T4 drop at Lv3 stays in the bag (MinLevel 12)",
		show({ f.WeaponOwnedMask, f.WeaponTier }))
	-- the first king-slime scroll while nothing is owned
	local w4 = bareWorld()
	local s = w4:Join(604, { Level = 1, Tutorial = 0 })
	local k0 = #w4.Notices
	w4:Drop(s, "BigSlime", nil)
	check(indexOf(notices(w4, s, k0), C0.Loot.Text.FirstScrollBare) ~= nil, "first scroll bare-handed: the first-weapon hint",
		show(notices(w4, s, k0)))
	local w5 = bareWorld()
	local t = w5:Join(605, { Level = 1, Tier = 1, Mask = 1, Tutorial = 0 })
	local j0 = #w5.Notices
	w5:Drop(t, "BigSlime", nil)
	check(indexOf(notices(w5, t, j0), C0.Loot.Text.FirstScroll) ~= nil, "first scroll with a weapon: the enhance hint")
	-- the level fit: only T3 owned (bought, the M1_1 gift never came), level back to 1 -> never bare hands again
	-- (A23-34: a rebirth / class change does not send a weapon owner back to bare hands): the free tier 1, equipped
	local w6 = bareWorld()
	local u, g = w6:Join(606, { Level = 5, Tier = 3, Mask = 4 })
	w6.PS.SetStat(u, "Level", 1)
	local i0 = #w6.Notices
	w6.Loot.FitWeaponToLevel(u)
	check(g.WeaponTier == 1 and g.WeaponOwnedMask == 5 and u:GetAttribute("WeaponOwnedMask") == 5,
		"level reset with only T3 owned -> the free T1 equipped (T3 kept)", show({ g.WeaponTier, g.WeaponOwnedMask }))
	check(indexOf(notices(w6, u, i0), string.format(C0.Text.WeaponAutoSwap, 5, C0.WeaponName(1, "Warrior", "Halo"))) ~= nil,
		"the usual swap line names T1", show(notices(w6, u, i0)))
	-- a later M1_1 then pays nothing and says nothing (T1 is owned)
	w6.PS.SetStat(u, "TutorialStep", 99)
	w6.Story.Refresh(u)
	local i1 = #w6.Notices
	w6.PS.SetStat(u, "BlacksmithVisited", true)
	w6.Story.Refresh(u)
	for _, x in notices(w6, u, i1) do
		check(not has(x, "first weapon") and not has(x, "also gave you"), "a later M1_1 adds no gift line", x)
	end
	check(g.WeaponOwnedMask == 5, "a later M1_1 adds nothing", g.WeaponOwnedMask)
	-- the Studio reset aid: 0 = a new bare-handed player
	local w7 = bareWorld()
	local v, h = w7:Join(607, { Level = 4, Tier = 2, Mask = 3 })
	w7.Loot.DebugReset(v, 0)
	check(h.WeaponOwnedMask == 0 and h.WeaponTier == 0, "DebugReset(0) = the bare-handed start", show({ h.WeaponOwnedMask, h.WeaponTier }))
end)

------------------------------------------------------------------ 9. power attribute, PvP fallback, the weapon model
runGroup("power-pvp-visuals", function()
	local w = bareWorld()
	local p = w:Join(701, { Level = 1 })
	local q = w:Join(702, { Level = 2 })
	local r = w:Join(703, { Level = 1, Tier = 1, Mask = 1 })
	check(w.Justice.GetCombatPower(p) == 0 and w.Justice.GetCombatPower(q) == 12 and w.Justice.GetCombatPower(r) == 283,
		"JusticeService.GetCombatPower: bare Lv1 0, bare Lv2 12, T1 Lv1 283",
		show({ w.Justice.GetCombatPower(p), w.Justice.GetCombatPower(q), w.Justice.GetCombatPower(r) }))
	-- PvPService's own power fallback (no JusticeService) reads bare hands too; boldness never divides by 0
	local pvpReg = { JusticeService = {}, PlayerService = w.PS, CombatService = { PlayerDamaged = w.Util.Signal.new() },
		FactionService = { FactionChanged = w.Util.Signal.new() } }
	local pvp = w:Load("PvPService", PVP_SOURCE)
	pvp.Init(pvpReg)
	check(pvp.BoldMult(p, r) == 1, "a bare killer (power 0): boldness x1, no division by 0", pvp.BoldMult(p, r))
	check(pvp.BoldMult(r, p) == C0.PvP.BoldWeakMult, "KO of a bare victim (power 0): the weak multiplier", pvp.BoldMult(r, p))
	-- CharacterVisuals.buildWeapon: nothing in the hands at tier 0
	local built, cleared = {}, 0
	local function stubBuild(kind) return function() table.insert(built, kind); return {}, nil end end
	local buildWeapon = execute("CharacterVisuals.extract", VISUALS_EXTRACT, w:Env(), C0, w.Util,
		function() cleared += 1 end, function(pl) return pl:GetAttribute("Class") or "Warrior" end,
		function() return 1 end, function() return {} end, stubBuild("Staff"), stubBuild("Bow"), stubBuild("Sword"),
		function() end, function() end, function(name) local m = newInstance("Model", w); m.Name = name; return m end,
		function() return "Halo" end, function(model) table.insert(built, "mount:" .. model.Name) end)
	buildWeapon(p, p.Character)
	check(cleared == 1 and #built == 0, "tier 0: the old model is cleared and nothing is built", show(built))
	buildWeapon(r, r.Character)
	check(cleared == 2 and built[1] == "Sword" and built[2] == "mount:WeaponModel", "tier 1: the weapon is built", show(built))
end)

finish()
