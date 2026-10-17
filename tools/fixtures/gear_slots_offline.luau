-- gear_slots_offline.luau : gear slots (GearService + the hooks, 게임성 개발 3, 2026-10-12; contract
-- docs/design/gear_slots_2026-10-12.md; 게임성 검수 10/12 incl. "+N is only the hammer's +0..+2"). tools/test_gear_slots.py
-- binds CONFIG_SOURCE, UTIL_SOURCE, GEAR_SOURCE, PET_SOURCE, COMBAT_SOURCE, LOOT_SOURCE and the extracts MAXHP_SOURCE
-- (PlayerService.computeMaxHealth), SPEED_SOURCE (ComputeWalkSpeed) and WATCH_SOURCE (JusticeService POWER.Watch) in front of
-- dev2_kit.luau + dev3_world.luau; this file follows. GearService, PetService, CombatService (hits) and LootService (scrolls)
-- run from source; PlayerService / ClassService / FactionService ... are the world's doubles.

local NOON = 1789959600 -- 2026-09-22 12:00 KST

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-9 end

local function fake(attrs)
	return { GetAttribute = function(_, k) return attrs[k] end }
end

local function newConfig(gear, edit)
	local c = execute("Config", CONFIG_SOURCE, nativeEnv())
	if gear then c.Features.Gear = true end
	if edit then edit(c) end
	return c
end

local function fired(w, remote, p)
	local out = {}
	for _, f in w.Fired do
		if f.Remote == remote and f.Player == p then table.insert(out, f.Payload) end
	end
	return out
end

local function last(list) return list[#list] end

local function keysFor(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Notices do
		local n = w.Notices[i]
		if n.Player == p and n.Key then table.insert(out, n.Key) end
	end
	return out
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

-- everything a player holds: Own + worn (a thing is in one place only, so a move never changes this number)
local function things(d)
	local n = 0
	for _, c in d.Gear.Own do n += c end
	for _, v in d.Gear.On do
		if v ~= "" then n += 1 end
	end
	for _, row in d.Gear.Pet do
		for _ in row do n += 1 end
	end
	return n
end

local function gWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.Off ~= true then c.Features.Gear = true end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	w.Net.NotifyKey = function(p, key, args, kind)
		table.insert(w.Notices, { Player = p, Key = key, Args = args, Kind = kind, Text = "KEY:" .. tostring(key) })
	end
	w.Services.ServerStorage = newInstance("ServerStorage", w)
	w.Speeds, w.Refreshes = {}, {}
	w.PS.RefreshSpeed = function(p) table.insert(w.Speeds, { P = p, Acc = p:GetAttribute("PetAcc") }) end
	w.PS.RefreshCharacter = function(p, full) table.insert(w.Refreshes, { P = p, Full = full }) end
	w:Service("PetService", PET_SOURCE)
	w:Service("GearService", GEAR_SOURCE)
	-- ⑤: the live switchboard double (Changed(key, value); the gear re-reads the players when Gear comes back on)
	w.Reg.SwitchService = { Changed = w.Util.Signal.new(), On = function() return true end }
	w:InitStart({ "PetService", "GearService" })
	w.G, w.P = w.Reg.GearService, w.Reg.PetService
	return w
end

local function body(w, p)
	w.CharFolder = w.CharFolder or newInstance("Folder", w)
	local char = newInstance("Model", w)
	char.Parent = w.CharFolder
	local root = newInstance("Part", w)
	root.Name = "HumanoidRootPart"
	root.Parent = char
	local hum = newInstance("Humanoid", w)
	hum.Health = 100
	hum.Parent = char
	p.Character = char
	return hum
end

-- a ready, living Halo knight (Lv30 unless extra says otherwise) with the given Gear table
local function gearer(w, id, gear, extra)
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 30, TamerNotice = true }
	if gear then data.Gear = gear end
	for k, v in extra or {} do data[k] = v end
	local p, d = w:Arrive(id, { Data = data })
	body(w, p)
	return p, d
end

local function bag(own, on)
	return { Own = own or {}, On = on or { Armor = "", Ring = "" }, Pet = {} }
end

------------------------------------------------------------------ the table
runGroup("config", function()
	local C = newConfig(false)
	local G = C.Gear
	check(C.Features.Gear == false and C.FeatureOn("Gear") == false, "Config.Features.Gear is off", "")
	check(G.MaxTier == 3 and G.MaxPlus == 2 and G.OwnSum == 60 and C.SaveV4.OwnKeyMax == 20 and C.SaveV4.GearMaxPlus == 2,
		"3 tiers, +0..+2 only, 60 things in Own (20 a key), the save repair keeps P in 0..2", show({ G.MaxTier, G.MaxPlus, G.OwnSum }))
	check(table.concat(G.Slots.Armor.Wear, ",") == "10,20,30" and table.concat(G.Slots.Ring.Wear, ",") == "10,20,30",
		"wear level 10 / 20 / 30 for armor and ring", "")
	check(C.RateLimits.EquipGear == 0.5, "Config.RateLimits.EquipGear = 0.5", "")
	for _, key in { "NotYours", "NeedLevel", "Full", "Equipped", "Removed" } do
		check(type(G.Text[key]) == "string" and G.Text[key] ~= "", "a short text for every notice", key)
	end
	local want = {
		Armor = { { 0.06, 0.08, 0.10 }, { 0.12, 0.14, 0.16 }, { 0.18, 0.20, 0.22 } },
		Ring = { { 0.04, 0.05, 0.06 }, { 0.08, 0.09, 0.10 }, { 0.12, 0.13, 0.14 } },
		PetArmor = { { 0.20, 0.30, 0.40 }, { 0.40, 0.50, 0.60 }, { 0.60, 0.70, 0.80 } },
		PetAcc = { { 0.01, 0.015, 0.02 }, { 0.02, 0.025, 0.03 }, { 0.03, 0.035, 0.04 } },
	}
	for slot, tiers in want do
		local ok = true
		for t, row in tiers do
			for plus = 0, 2 do
				if not near(C.GearBonus(slot, t, plus), row[plus + 1]) then ok = false end
			end
		end
		check(ok, "GearBonus " .. slot .. ": the design table per tier and +N", slot)
	end
	check(near(G.PetAccMax, C.GearBonus("PetAcc", 3, 2)), "PetAccMax = the best PetAcc (T3 +2)", tostring(G.PetAccMax))
	check(near(1 + C.GearBonus("Armor", 3, 2), 1.22) and near(1 + C.GearBonus("Ring", 3, 2), 1.14)
		and math.abs(math.sqrt(1.14 * 1.22) - 1.18) < 0.005, "the top: HP x1.22, hit x1.14, power about +18%", "")
	local zero = true
	for _, args in { { "Hat", 1, 0 }, { "Armor", 0, 0 }, { "Armor", 4, 0 }, { "Armor", 1, 3 }, { "Armor", 1, -1 }, { "Armor", 1.5, 0 },
		{ "Armor", 1, 0.5 }, { "Armor", 0 / 0, 0 }, { "Armor", 1, 0 / 0 }, { "Armor", nil, 0 }, { "Armor", "1", 0 }, { "Armor", 3, 10 },
		{ "Ring", 1, math.huge }, { nil, 1, 0 }, { 5, 1, 0 }, { "Slots", 1, 0 } } do
		if C.GearBonus(args[1], args[2], args[3]) ~= 0 then zero = false end
	end
	check(zero, "GearBonus: 0 for an unknown slot, tier 0 / 4, a plus outside 0..2 (a scroll's +3..+10 is never gear), junk", "")
	local t1, p1 = C.GearParse("1:0")
	local t3, p3 = C.GearParse("3:2")
	local bad = 0
	for _, k in { "01:0", "1:3", "4:0", "0:0", "1:10", "x", "1:00", "1:0 ", " 1:0", "1", "1:-1", "", 5, true } do
		if C.GearParse(k) ~= nil then bad += 1 end
	end
	check(t1 == 1 and p1 == 0 and t3 == 3 and p3 == 2 and bad == 0 and C.GearParse(nil) == nil, "GearParse: plain T:P with T 1..3, P 0..2", tostring(bad))
	check(C.GearMult(1.22) == 1.22 and C.GearMult(nil) == 1 and C.GearMult(0 / 0) == 1 and C.GearMult(0.5) == 1 and C.GearMult(math.huge) == 1
		and C.GearMult("2") == 1 and C.GearMult(true) == 1 and C.GearMult(1) == 1, "GearMult: a real number >= 1, anything else 1", "")
	check(near(C.GearBonusOf("Ring", "2:1"), 0.09) and C.GearBonusOf("Ring", "2:9") == 0 and C.GearBonusOf("Ring", nil) == 0, "GearBonusOf reads a worn T:P", "")
	local a, h = C.GearMultsOf(fake({ GearAtk = 1.14, GearHp = 1.22 }))
	check(a == 1 and h == 1, "GearMultsOf = (1, 1) while the switch is off, whatever the attributes say", show({ a, h }))
	local on = newConfig(true)
	local a2, h2 = on.GearMultsOf(fake({ GearAtk = 1.14, GearHp = 1.22 }))
	check(a2 == 1.14 and h2 == 1.22, "GearMultsOf reads GearAtk / GearHp (the switch on)", show({ a2, h2 }))
	local a3, h3 = on.GearMultsOf(fake({}))
	local a4, h4 = on.GearMultsOf(fake({ GearAtk = 0 / 0, GearHp = 0.5 }))
	local a5, h5 = on.GearMultsOf(fake({ GearAtk = math.huge, GearHp = "1.5" }))
	check(a3 == 1 and h3 == 1 and a4 == 1 and h4 == 1 and a5 == 1 and h5 == 1, "missing / NaN / below 1 / infinity / text = 1", "")
	local a6, h6 = on.GearMultsOf(nil)
	local a7, h7 = on.GearMultsOf({})
	check(a6 == 1 and h6 == 1 and a7 == 1 and h7 == 1, "a nil / broken player never throws: (1, 1)", "")
	local gear = { Pet = { P1 = { PetAcc = "2:1", PetArmor = "3:2" } } }
	check(near(on.PetGearBonus(gear, "P1", "PetAcc"), 0.025) and near(on.PetGearBonus(gear, "P1", "PetArmor"), 0.8), "PetGearBonus: the pet's worn slot", "")
	check(on.PetGearBonus(gear, "P2", "PetAcc") == 0 and on.PetGearBonus(gear, "P1", "Armor") == 0 and on.PetGearBonus(nil, "P1", "PetAcc") == 0
		and on.PetGearBonus({ Pet = { P1 = { PetAcc = "9:9" } } }, "P1", "PetAcc") == 0 and on.PetGearBonus(gear, nil, "PetAcc") == 0
		and C.PetGearBonus(gear, "P1", "PetAcc") == 0, "PetGearBonus: 0 for another pet / a player slot / junk / a broken key / the switch off", "")
	-- the walk speed (PET-1): + PetAcc to the pet's bonus, never for a kaiju or without a pet, Speed.Cap stays
	local base = on.Player.WalkSpeed
	check(near(on.WalkSpeed("Warrior", "BabySlime", 1, false, nil, 0.03), base * 1.10) and near(on.WalkSpeed("Warrior", "BabySlime", 10, false, nil, 0.04), base * 1.14),
		"WalkSpeed: the pet's +7% / +10% plus PetAcc", "")
	check(near(on.WalkSpeed("Warrior", "BabySlime", 1, true, nil, 0.03), base) and near(on.WalkSpeed("Warrior", nil, 0, false, nil, 0.03), base),
		"WalkSpeed: a kaiju or no pet gets no PetAcc", "")
	check(near(on.WalkSpeed("Warrior", "BabySlime", 1, false, nil, 5), base * 1.11) and near(on.WalkSpeed("Warrior", "BabySlime", 1, false, nil, 0 / 0), base * 1.07)
		and near(on.WalkSpeed("Warrior", "BabySlime", 1, false, nil, -1), base * 1.07) and near(on.WalkSpeed("Warrior", "BabySlime", 1, false, nil, "0.03"), base * 1.07),
		"WalkSpeed: PetAcc is cut at PetAccMax; NaN / negative / text ignored", "")
	check(near(on.WalkSpeed("Warrior", "BabySlime", 1), base * 1.07) and near(on.WalkSpeed("Archer", "BabySlime", 4, false, 7), base * 1.1 * 1.08),
		"every old call still works (extra arguments nil)", "")
	local fast = newConfig(true, function(c) c.Classes.Warrior.WalkSpeedMult = 1.3 end)
	check(near(fast.WalkSpeed("Warrior", "BabySlime", 10, false, nil, 0.04), fast.Player.WalkSpeed * 1.35), "WalkSpeed: the Speed.Cap (1.35) still holds", "")
	check(near(C.WalkSpeed("Warrior", "BabySlime", 1, false, nil, 0.03), base * 1.07), "WalkSpeed: PetAcc does nothing while the switch is off", "")
end)

------------------------------------------------------------------ the power number
runGroup("power", function()
	local on, off = newConfig(true), newConfig(false)
	local top = { A = 1.14, H = 1.22 }
	local base = on.CombatPower(30, 3, 5)
	local geared = on.CombatPower(30, 3, 5, nil, top)
	check(geared == math.floor(on.PowerOf(30, 3, 1, 5, nil, top) * 10 + 0.5), "CombatPower = floor(PowerOf with the gear x 10 + 0.5)", tostring(geared))
	check(math.abs(geared / base - math.sqrt(1.14 * 1.22)) < 0.003, "the top gear = power x sqrt(1.14 x 1.22) (about +18%)", tostring(geared / base))
	check(on.CombatPower(30, 3, 5, nil, nil) == base and on.CombatPower(30, 3, 5, nil, {}) == base and on.CombatPower(30, 3, 5, nil, { A = 1, H = 1 }) == base,
		"gear nil / {} / (1, 1) = the old number", "")
	check(on.CombatPower(30, 3, 5, nil, { A = 0 / 0, H = 0.5 }) == base and on.CombatPower(30, 3, 5, nil, { A = "2", H = math.huge }) == base,
		"a bad gear multiplier counts as 1", "")
	local atkOnly = on.PowerOf(30, 3, 1, 5, nil, { A = 1.14, H = 1 }) / on.PowerOf(30, 3, 1, 5)
	local hpOnly = on.PowerOf(30, 3, 1, 5, nil, { A = 1, H = 1.22 }) / on.PowerOf(30, 3, 1, 5)
	check(math.abs(atkOnly - math.sqrt(1.14)) < 1e-9 and math.abs(hpOnly - math.sqrt(1.22)) < 1e-9, "the ring and the armor each multiply their own factor inside the root", show({ atkOnly, hpOnly }))
	local pl = fake({ Level = 30, WeaponTier = 3, WeaponEnhance = 5, GearAtk = 1.14, GearHp = 1.22 })
	check(on.CombatPowerOf(pl) == geared and off.CombatPowerOf(pl) == off.CombatPower(30, 3, 5),
		"CombatPowerOf passes the player's gear (the switch off: the old number)", show({ on.CombatPowerOf(pl), geared }))
	check(on.CombatPowerOf(pl, 0, 0) == on.CombatPower(30, 0, 0, nil, top) and on.CombatPowerOf(pl, 5, 2) == on.CombatPower(30, 5, 2, nil, top),
		"CombatPowerOf with another weapon keeps the gear", "")
	check(on.CombatPowerOf(fake({ Level = 30, WeaponTier = 3, WeaponEnhance = 5 })) == base, "no gear attributes = the old number", "")
	-- MaxCombatPower: the best gear when the switch is on, its own cache value
	local m0 = off.MaxCombatPower()
	-- C1 (tier 9 Mythic): the expected numbers come from the formula - the best of every tier at MaxLevel / MaxEnhance
	local function best(c, even, gear)
		local b, bt = 0, 0
		for t = 1, c.MaxWeaponTier do
			local v = c.CombatPower(c.Levels.MaxLevel, t, c.Loot.MaxEnhance, even, gear)
			if v > b then b, bt = v, t end
		end
		return b, bt
	end
	local wantOff, topTier = best(off, nil, nil)
	local want = best(on, nil, top)
	local m1 = on.MaxCombatPower()
	check(m0 == wantOff and topTier == 9 and m1 == want and m1 > m0 and math.abs(m1 / m0 - math.sqrt(1.14 * 1.22)) < 0.001,
		"MaxCombatPower: off = the best tier (the Mythic, tier 9) at MaxLevel +MaxEnhance; on = the same with the T3 +2 armor and ring",
		show({ m0, wantOff, topTier, m1, want }))
	local both = newConfig(false)
	local x0 = both.MaxCombatPower()
	both.Features.Gear = true
	local x1 = both.MaxCombatPower()
	both.Features.Gear = false
	check(x0 == wantOff and x1 == m1 and both.MaxCombatPower() == x0, "MaxCombatPower: one cached value per switch state (flipping never mixes them)", show({ x0, x1 }))
	local stats = newConfig(true, function(c) c.Features.StatPoints = true end)
	local statsOff = newConfig(false, function(c) c.Features.StatPoints = true end)
	local points = statsOff.StatPoints(statsOff.Levels.MaxLevel)
	local wantStats = best(statsOff, { A = math.floor(points / 2), H = points - math.floor(points / 2) }, nil)
	check(stats.MaxCombatPower() > statsOff.MaxCombatPower() and stats.MaxCombatPower() ~= m1 and statsOff.MaxCombatPower() == wantStats,
		"MaxCombatPower: stat points and gear together are a fourth value", show({ stats.MaxCombatPower(), statsOff.MaxCombatPower() }))
	-- no hit of anything beats the displayed top number
	check(on.CombatPower(on.Levels.MaxLevel, on.MaxWeaponTier, on.Loot.MaxEnhance, nil, top) <= m1, "no gear number goes over MaxCombatPower", "")
end)

------------------------------------------------------------------ equip / take off / swap (one place)
runGroup("equip", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["Armor:1:0"] = 1, ["Armor:2:1"] = 1, ["Ring:3:2"] = 2, ["PetArmor:1:0"] = 1 }))
	local total = things(d)
	local from = #w.Notices
	check(w.G.Equip(p, "Armor", "1:0") == "ok", "Equip: an owned Armor T1 +0 at Lv30", "")
	check(d.Gear.On.Armor == "1:0" and d.Gear.Own["Armor:1:0"] == nil and things(d) == total, "one place: it left Own, it is worn, the total is the same", show(d.Gear))
	check(near(p:GetAttribute("GearHp"), 1.06) and p:GetAttribute("GearAtk") == 1, "GearHp 1.06 (armor T1 +0), GearAtk 1", show({ p:GetAttribute("GearHp"), p:GetAttribute("GearAtk") }))
	local info = last(fired(w, "GearInfo", p))
	check(info and info.On.Armor == "1:0" and info.Own["Armor:2:1"] == 1 and info.Own["Armor:1:0"] == nil and type(info.Pet) == "table", "GearInfo { Own, On, Pet } after the change", show(info))
	check(keysFor(w, p, from)[1] == "Config.Gear.Text.Equipped", "the notice is a key (Equipped)", show(keysFor(w, p, from)))
	check(#w.Refreshes >= 1 and w.Refreshes[#w.Refreshes].P == p and w.Refreshes[#w.Refreshes].Full == false, "a new armor re-reads the max HP (RefreshCharacter, no full heal)", tostring(#w.Refreshes))
	-- swap: the one worn goes back to Own
	check(w.G.Equip(p, "Armor", "2:1") == "ok" and d.Gear.On.Armor == "2:1" and d.Gear.Own["Armor:1:0"] == 1 and d.Gear.Own["Armor:2:1"] == nil and things(d) == total,
		"swap: Armor T2 +1 on, the T1 back in Own (the total stays)", show(d.Gear))
	check(near(p:GetAttribute("GearHp"), 1.14), "GearHp 1.14 (T2 +1)", tostring(p:GetAttribute("GearHp")))
	-- the ring: two of a key, one is worn
	check(w.G.Equip(p, "Ring", "3:2") == "ok" and d.Gear.On.Ring == "3:2" and d.Gear.Own["Ring:3:2"] == 1 and things(d) == total, "two of a key: one worn, one left", show(d.Gear))
	check(near(p:GetAttribute("GearAtk"), 1.14) and near(p:GetAttribute("GearHp"), 1.14), "GearAtk 1.14 (ring T3 +2)", "")
	local refreshes = #w.Refreshes
	check(w.G.Equip(p, "Ring", "3:2") == "same" and d.Gear.Own["Ring:3:2"] == 1 and #w.Refreshes == refreshes, "the same one again: nothing changes", "")
	-- take off
	local f2 = #w.Notices
	check(w.G.Equip(p, "Armor", "") == "ok" and d.Gear.On.Armor == "" and d.Gear.Own["Armor:2:1"] == 1 and things(d) == total, "take off: back to Own, the slot is '' (never nil)", show(d.Gear))
	check(p:GetAttribute("GearHp") == 1 and keysFor(w, p, f2)[1] == "Config.Gear.Text.Removed", "GearHp back to 1, the Removed key", show(keysFor(w, p, f2)))
	check(w.G.Equip(p, "Armor", "") == "none" and #keysFor(w, p, f2) == 1, "nothing worn: 'none', no notice", "")
	check(w.G.Equip(p, "Ring", "") == "ok" and p:GetAttribute("GearAtk") == 1 and d.Gear.On.Ring == "" and d.Gear.Own["Ring:3:2"] == 2 and things(d) == total, "the ring off: GearAtk 1", "")
	-- the kinds do not mix: a Ring is no Armor, a PetArmor is no Armor
	check(w.G.Equip(p, "Armor", "3:2") == "notyours" and d.Gear.On.Armor == "", "a Ring key in the Armor slot: not yours (the kind is the slot)", "")
	check(w.G.Equip(p, "Armor", "1:0") == "ok" and w.G.Equip(p, "Ring", "3:2") == "ok" and things(d) == total, "wear both again", "")
	local mu, mh = w.G.Mults(p)
	check(near(mu, 1.14) and near(mh, 1.06), "Mults(player) = the attributes' numbers", show({ mu, mh }))
end)

------------------------------------------------------------------ the rules
runGroup("rules", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["Armor:1:0"] = 1, ["Armor:2:0"] = 1, ["Armor:3:0"] = 1, ["Ring:1:0"] = 1 }), { Level = 9 })
	local before = show(d.Gear)
	local from = #w.Notices
	local infos = #fired(w, "GearInfo", p)
	check(w.G.Equip(p, "Armor", "1:0") == "level" and show(d.Gear) == before and keysFor(w, p, from)[1] == "Config.Gear.Text.NeedLevel", "Lv9: not even tier 1 (NeedLevel, nothing changes)", "")
	check(#fired(w, "GearInfo", p) == infos + 1 and last(fired(w, "GearInfo", p)).On.Armor == "", "a turned-down change sends GearInfo again (the window shows the truth)", "")
	local levels = { { 10, "1:0", "ok" }, { 19, "2:0", "level" }, { 20, "2:0", "ok" }, { 29, "3:0", "level" }, { 30, "3:0", "ok" } }
	for _, c in levels do
		d.Level = c[1]
		check(w.G.Equip(p, "Armor", c[2]) == c[3], "wear level: tier " .. string.sub(c[2], 1, 1) .. " at Lv" .. c[1] .. " = " .. c[3], show(d.Gear.On))
	end
	d.Level = 10
	check(w.G.Equip(p, "Ring", "1:0") == "ok" and w.G.Equip(p, "Armor", "") == "ok", "Lv10 wears the T1 ring; taking off needs no level", "")
	d.Level = 1
	check(w.G.Equip(p, "Ring", "") == "ok", "taking off has no level check", "")
	d.Level = 30
	local snapshot = show(d.Gear)
	local f2 = #w.Notices
	check(w.G.Equip(p, "Ring", "2:0") == "notyours" and show(d.Gear) == snapshot and keysFor(w, p, f2)[1] == "Config.Gear.Text.NotYours", "not owned: NotYours, nothing changes", "")
	for _, bad in { "01:0", "1:3", "4:0", "0:0", "x", "1:10", " 1:0", "1:0 ", "1", "" .. string.rep("1", 40) } do
		local r = w.G.Equip(p, "Ring", bad)
		check(r == "key" and show(d.Gear) == snapshot, "a bad key is refused: " .. #bad .. " chars", tostring(r))
	end
	check(w.G.Equip(p, "Hat", "1:0") == "slot" and w.G.Equip(p, "PetArmor", "1:0") == "slot" and w.G.Equip(p, nil, "1:0") == "slot" and w.G.Equip(p, 5, "1:0") == "slot"
		and w.G.Equip(p, "Ring", 5) == "key" and w.G.Equip(p, "Ring", nil) == "key" and show(d.Gear) == snapshot, "a bad slot / a pet slot / junk: refused", "")
	-- not ready / dead / not a player
	w.Ready[p] = nil
	check(w.G.Equip(p, "Ring", "") == "state" and w.G.Equip(p, "Armor", "3:0") == "state" and show(d.Gear) == snapshot, "not ready: no change", "")
	w.Ready[p] = true
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	hum.Health = 0
	check(w.G.Equip(p, "Armor", "3:0") == "state" and show(d.Gear) == snapshot, "KO'd: no change", "")
	hum.Health = 100
	check(w.G.Equip(nil, "Armor", "3:0") == "state" and w.G.Equip("x", "Armor", "3:0") == "state", "not a player: no change", "")
	w:Leave(p)
	check(w.G.Equip(p, "Armor", "3:0") == "state", "a player who left: no change", "")
	-- caps: 60 in all, 20 a key
	local w2 = gWorld()
	local full, df = gearer(w2, 1, bag({ ["Ring:1:0"] = 20, ["Ring:2:0"] = 20, ["Ring:3:0"] = 19, ["Armor:1:0"] = 1 }, { Armor = "2:0", Ring = "" }))
	check(things(df) == 61, "setup: 60 in Own + 1 worn", tostring(things(df)))
	local snap2 = show(df.Gear)
	local f3 = #w2.Notices
	check(w2.G.Equip(full, "Armor", "") == "full" and show(df.Gear) == snap2 and keysFor(w2, full, f3)[1] == "Config.Gear.Text.Full", "Own holds 60: taking off is refused (Full), the armor stays on", show(df.Gear))
	check(w2.G.Equip(full, "Armor", "1:0") == "ok" and df.Gear.On.Armor == "1:0" and df.Gear.Own["Armor:2:0"] == 1 and things(df) == 61, "a swap keeps the sum (one in, one out): allowed at 60", show(df.Gear))
	check(w2.G.Equip(full, "Armor", "") == "full", "still 60: still no room", "")
	df.Gear.Own = { ["Armor:1:0"] = 20, ["Ring:1:0"] = 5 }
	check(w2.G.Equip(full, "Armor", "") == "full" and df.Gear.On.Armor == "1:0" and df.Gear.Own["Armor:1:0"] == 20, "20 of that key in Own (room in all): taking off is refused (key cap)", show(df.Gear))
	df.Gear.Own["Armor:3:0"] = 1
	check(w2.G.Equip(full, "Armor", "3:0") == "full" and df.Gear.On.Armor == "1:0" and df.Gear.Own["Armor:3:0"] == 1 and df.Gear.Own["Armor:1:0"] == 20,
		"a swap whose old one has no room (key cap): refused, all of it or nothing", show(df.Gear))
	-- the switch off
	local o = gWorld({ Off = true })
	local q, dq = gearer(o, 1, bag({ ["Armor:1:0"] = 1 }))
	check(o.G.Equip(q, "Armor", "1:0") == "off" and dq.Gear.On.Armor == "" and dq.Gear.Own["Armor:1:0"] == 1 and o.G.EquipPet(q, "P1", "PetAcc", "1:0") == "off",
		"switch off: nothing can be worn", show(dq.Gear))
	check(q:GetAttribute("GearAtk") == nil and q:GetAttribute("GearHp") == nil and #fired(o, "GearInfo", q) == 0 and #o.Refreshes == 0,
		"switch off: no attribute, no GearInfo, no refresh at the join", "")
end)

------------------------------------------------------------------ the join: attributes + GearInfo
-- ⑤ (최종 검수 10/14): a join while the live switch Gear was off is read again when it comes back on
runGroup("switch back on", function()
	local w = gWorld()
	w.Config.LiveOff = { Gear = true }
	local p = gearer(w, 31, bag({}, { Armor = "3:1", Ring = "2:2" }))
	check(p:GetAttribute("GearHp") == nil and w.Config.FeatureOn("Gear") == false, "joined while Gear was off: no gear attributes", "")
	w.Config.LiveOff = nil
	w.Reg.SwitchService.Changed:Fire("Crafting", true)
	check(p:GetAttribute("GearHp") == nil, "another switch: nothing", "")
	w.Reg.SwitchService.Changed:Fire("Gear", true)
	check(near(p:GetAttribute("GearHp"), 1.20) and near(p:GetAttribute("GearAtk"), 1.10) and #fired(w, "GearInfo", p) == 1,
		"Gear back on: the player is read again (GearHp / GearAtk, one GearInfo)", show({ p:GetAttribute("GearHp"), p:GetAttribute("GearAtk") }))
end)

runGroup("join", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["Armor:2:0"] = 3 }, { Armor = "3:1", Ring = "2:2" }))
	check(near(p:GetAttribute("GearHp"), 1.20) and near(p:GetAttribute("GearAtk"), 1.10), "PlayerReady: GearHp / GearAtk from what is worn (armor T3 +1, ring T2 +2)", show({ p:GetAttribute("GearHp"), p:GetAttribute("GearAtk") }))
	local info = fired(w, "GearInfo", p)
	check(#info == 1 and info[1].On.Armor == "3:1" and info[1].On.Ring == "2:2" and info[1].Own["Armor:2:0"] == 3 and next(info[1].Pet) == nil, "PlayerReady: one GearInfo { Own, On, Pet }", show(info[1]))
	info[1].Own["Armor:2:0"] = 99
	info[1].On.Armor = "x"
	check(d.Gear.Own["Armor:2:0"] == 3 and d.Gear.On.Armor == "3:1", "the payload is a copy (the save is never shared)", "")
	local q, dq = gearer(w, 2, nil)
	check(q:GetAttribute("GearHp") == 1 and q:GetAttribute("GearAtk") == 1 and dq.Gear.On.Armor == "" and dq.Gear.On.Ring == "", "no gear: 1 / 1", "")
	local r, dr = gearer(w, 3, { Own = "x", On = 5, Pet = false })
	check(type(dr.Gear.Own) == "table" and dr.Gear.On.Armor == "" and r:GetAttribute("GearHp") == 1 and #w.Warnings == 0, "a broken Gear table is repaired (Config.SanitizeGear), no error", show(dr.Gear))
	-- a worn thing above the wear level (a Lv changed) stays worn but pauses (게임성 검수 10/12): x1 until that level
	local s, ds = gearer(w, 4, bag({}, { Armor = "3:0", Ring = "" }), { Level = 5 })
	check(s:GetAttribute("GearHp") == 1 and ds.Gear.On.Armor == "3:0", "a worn thing stays on at a low level, paused (x1)", tostring(s:GetAttribute("GearHp")))
	-- the armor that stays: a take-off lowers the HP mult
	w.G.Equip(s, "Armor", "")
	check(s:GetAttribute("GearHp") == 1, "taken off: 1", "")
end)

------------------------------------------------------------------ pet slots
runGroup("pets", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["PetAcc:1:0"] = 1, ["PetAcc:2:0"] = 1, ["PetAcc:3:2"] = 1, ["PetArmor:1:0"] = 1, ["PetArmor:2:1"] = 1, ["PetArmor:3:2"] = 1, ["Armor:1:0"] = 1 }))
	local uid = w.P.SummonPet(p, "BabySlime", { Spd = 6 })
	local total = things(d)
	check(uid == "P1" and p:GetAttribute("PetAcc") == nil, "setup: my pet P1 (it follows), no PetAcc (nil)", tostring(p:GetAttribute("PetAcc")))
	local from = #w.Notices
	local speeds = #w.Speeds
	check(w.G.EquipPet(p, "P1", "PetAcc", "1:0") == "ok" and d.Gear.Pet.P1.PetAcc == "1:0" and d.Gear.Own["PetAcc:1:0"] == nil and things(d) == total,
		"EquipPet: PetAcc T1 on my pet (Own -> Pet[uid], one place)", show(d.Gear))
	check(near(p:GetAttribute("PetAcc"), 0.01) and #w.Speeds > speeds and near(w.Speeds[#w.Speeds].Acc, 0.01), "PetService republished: the PetAcc attribute 0.01, then the speed refresh", tostring(w.Speeds[#w.Speeds].Acc))
	local info = last(fired(w, "GearInfo", p))
	check(info and info.Pet.P1 and info.Pet.P1.PetAcc == "1:0" and keysFor(w, p, from)[1] == "Config.Gear.Text.Equipped", "GearInfo.Pet and the Equipped key", show(info and info.Pet))
	check(w.G.EquipPet(p, "P1", "PetAcc", "3:2") == "ok" and near(p:GetAttribute("PetAcc"), 0.04) and d.Gear.Own["PetAcc:1:0"] == 1 and d.Gear.Pet.P1.PetAcc == "3:2" and things(d) == total,
		"swap: PetAcc T3 +2 = 0.04, the T1 back in Own", show(d.Gear))
	check(w.G.EquipPet(p, "P1", "PetAcc", "3:2") == "same", "the same one again: nothing changes", "")
	check(w.G.EquipPet(p, "P1", "PetArmor", "2:1") == "ok" and d.Gear.Pet.P1.PetArmor == "2:1" and near(p:GetAttribute("PetAcc"), 0.04), "PetArmor on the same pet (a row of two slots)", show(d.Gear.Pet))
	-- pet XP: x (1 + PetArmor), floored, in one place
	local lvXP = function(row)
		local n = row.XP
		for l = 1, row.Lv - 1 do n += 15 * l end
		return n
	end
	local x1 = lvXP(d.Pets.List.P1)
	w.P.AddPetXP(p, "P1", 20)
	check(lvXP(d.Pets.List.P1) - x1 == 30, "AddPetXP 20 with PetArmor T2 +1 (x1.5) = 30 pet XP", tostring(lvXP(d.Pets.List.P1) - x1))
	local xp0 = lvXP(d.Pets.List.P1)
	w.P.AddPetXP(p, "P1", 7)
	check(lvXP(d.Pets.List.P1) - xp0 == 10, "7 x 1.5 = 10.5 floors to 10", tostring(lvXP(d.Pets.List.P1) - xp0))
	-- a pet that wears nothing gets the plain XP; the bonus is of THAT pet only
	local u2 = w.P.SummonPet(p, "BabySlime", { Spd = 7 })
	local x2 = lvXP(d.Pets.List[u2])
	w.P.AddPetXP(p, u2, 20)
	check(lvXP(d.Pets.List[u2]) - x2 == 20, "another pet without PetArmor: the plain 20", tostring(lvXP(d.Pets.List[u2]) - x2))
	check(w.G.EquipPet(p, u2, "PetArmor", "3:2") == "ok", "the second pet wears the T3 +2 armor", "")
	local x3 = lvXP(d.Pets.List[u2])
	w.P.AddPetXP(p, u2, 20)
	check(lvXP(d.Pets.List[u2]) - x3 == 36 and near(p:GetAttribute("PetAcc"), 0.04), "20 x 1.8 = 36; PetAcc follows the pet that follows (P1)", tostring(lvXP(d.Pets.List[u2]) - x3))
	-- a kill: XPPerKill (1) x 1.5 floors to 1 (the bonus is for bigger gains)
	local x4 = lvXP(d.Pets.List.P1)
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime", XP = 10, Gold = 5 })
	w:RunSpawned()
	check(lvXP(d.Pets.List.P1) - x4 == 2, "a kill: 1 x 1.5 + the 0.5 kept from 7 x 1.5 = 2 (the same function, fractions kept)",
		tostring(lvXP(d.Pets.List.P1) - x4))
	-- 게임성 개발 2: XPPerKill 1 x 1.2 (PetArmor T1) five kills = 6 pet XP (the fractions add up)
	local fw = gWorld()
	local fp, fd = gearer(fw, 1, bag({ ["PetArmor:1:0"] = 1 }))
	fw.P.SummonPet(fp, "BabySlime", { Spd = 6 })
	fw.G.EquipPet(fp, "P1", "PetArmor", "1:0")
	local f0 = lvXP(fd.Pets.List.P1)
	for _ = 1, 5 do
		fw.Reg.MonsterService.MonsterKilled:Fire(fp, { Kind = "Slime", XP = 10, Gold = 5 })
		fw:RunSpawned()
	end
	check(lvXP(fd.Pets.List.P1) - f0 == 6, "PetArmor T1: 1 x 1.2 five kills = 6 pet XP (not 5)", tostring(lvXP(fd.Pets.List.P1) - f0))
	fw.Reg.MonsterService.MonsterKilled:Fire(fp, { Kind = "Slime", XP = 10, Gold = 5 })
	fw:RunSpawned()
	check(lvXP(fd.Pets.List.P1) - f0 == 7, "a sixth kill: 1 more (the used-up fraction is gone)", tostring(lvXP(fd.Pets.List.P1) - f0))
	-- a kill gives XPPerKill (a bigger number here) x the bonus too
	local kw = gWorld({ EditConfig = function(c) c.Pets.XPPerKill = 10 end })
	local kp, kd = gearer(kw, 1, bag({ ["PetArmor:2:1"] = 1 }))
	kw.P.SummonPet(kp, "BabySlime", { Spd = 6 })
	kw.G.EquipPet(kp, "P1", "PetArmor", "2:1")
	local k0 = lvXP(kd.Pets.List.P1)
	kw.Reg.MonsterService.MonsterKilled:Fire(kp, { Kind = "Slime", XP = 10, Gold = 5 })
	kw:RunSpawned()
	check(lvXP(kd.Pets.List.P1) - k0 == 15, "a kill: XPPerKill 10 x 1.5 = 15 (the kill path uses the same bonus)", tostring(lvXP(kd.Pets.List.P1) - k0))
	kw.Reg.MonsterService.MonsterKilled:Fire(kp, { Kind = "Slime", XP = 10, Gold = 5, Minor = true })
	kw:RunSpawned()
	check(lvXP(kd.Pets.List.P1) - k0 == 15, "a free rider's share still gives nothing", "")
	-- the pet that follows changes: PetAcc follows
	w.Gap = 1
	w:Remote("EquipPet", p, u2)
	check(p:GetAttribute("PetAcc") == nil, "another pet follows (no PetAcc): PetAcc 0", tostring(p:GetAttribute("PetAcc")))
	w.G.EquipPet(p, u2, "PetAcc", "2:0")
	check(near(p:GetAttribute("PetAcc"), 0.02), "... and its own PetAcc 0.02 once it wears one", tostring(p:GetAttribute("PetAcc")))
	-- take off
	check(w.G.EquipPet(p, u2, "PetAcc", "") == "ok" and p:GetAttribute("PetAcc") == nil and d.Gear.Pet[u2].PetAcc == nil and d.Gear.Own["PetAcc:2:0"] == 1, "take off: PetAcc 0, back to Own", show(d.Gear))
	check(w.G.EquipPet(p, u2, "PetArmor", "") == "ok" and d.Gear.Pet[u2] == nil, "a pet that wears nothing has no row", show(d.Gear.Pet))
	check(w.G.EquipPet(p, u2, "PetArmor", "") == "none", "nothing worn: none", "")
	-- my pet only, the right slots, the same checks
	local snap = show(d.Gear)
	check(w.G.EquipPet(p, "P9", "PetAcc", "1:0") == "pet" and w.G.EquipPet(p, "", "PetAcc", "1:0") == "pet" and w.G.EquipPet(p, nil, "PetAcc", "1:0") == "pet"
		and w.G.EquipPet(p, string.rep("P", 33), "PetAcc", "1:0") == "pet" and show(d.Gear) == snap, "not my pet / junk uid: pet, nothing changes", "")
	local k, dk = gearer(w, 2, bag({ ["PetAcc:1:0"] = 1 }))
	check(w.G.EquipPet(k, "P1", "PetAcc", "1:0") == "pet" and dk.Gear.Own["PetAcc:1:0"] == 1 and next(dk.Gear.Pet) == nil, "another player's pet uid: pet (I have none)", "")
	check(w.G.EquipPet(p, "P1", "Armor", "1:0") == "slot" and w.G.EquipPet(p, "P1", "Ring", "1:0") == "slot" and w.G.EquipPet(p, "P1", nil, "1:0") == "slot"
		and w.G.EquipPet(p, "P1", "PetAcc", 5) == "key" and w.G.EquipPet(p, "P1", "PetAcc", "1:3") == "key" and show(d.Gear) == snap, "a player's slot on a pet / junk: refused", "")
	check(w.G.EquipPet(p, "P1", "PetAcc", "3:1") == "notyours" and show(d.Gear) == snap, "a PetAcc I do not own: NotYours", "")
	check(w.G.EquipPet(p, "P1", "PetArmor", "1:0") == "ok" and w.G.EquipPet(p, "P1", "PetAcc", "1:0") == "ok", "T1 pet gear at Lv30 (pets need no level)", "")
	local low, dl = gearer(w, 3, bag({ ["PetArmor:3:2"] = 1 }), { Level = 1 })
	w.P.SummonPet(low, "BabySlime", { Spd = 5 })
	check(w.G.EquipPet(low, "P1", "PetArmor", "3:2") == "ok", "pet gear has no wear level (Lv1 owner, T3 +2)", "")
	-- caps
	local c, dc = gearer(w, 4, bag({ ["PetAcc:1:0"] = 20, ["PetAcc:2:0"] = 20, ["PetAcc:3:0"] = 19, ["PetArmor:1:0"] = 1 }))
	w.P.SummonPet(c, "BabySlime", { Spd = 5 })
	dc.Gear.Pet = { P1 = { PetAcc = "2:2" } }
	check(w.G.EquipPet(c, "P1", "PetAcc", "") == "full" and dc.Gear.Pet.P1.PetAcc == "2:2", "Own holds 60: taking a pet's gear off is refused", show(dc.Gear))
	check(w.G.EquipPet(c, "P1", "PetArmor", "1:0") == "ok" and dc.Gear.Pet.P1.PetArmor == "1:0" and dc.Gear.Pet.P1.PetAcc == "2:2", "a free slot: no old one goes back, so 60 is fine", show(dc.Gear))
	-- the switch off
	local o = gWorld({ Off = true })
	local q, dq = gearer(o, 1, bag({ ["PetAcc:1:0"] = 1 }))
	o.P.SummonPet(q, "BabySlime", { Spd = 6 })
	dq.Gear.Pet = { P1 = { PetAcc = "3:2", PetArmor = "3:2" } }
	o.P.Refresh(q)
	check(q:GetAttribute("PetAcc") == nil, "switch off: a worn PetAcc gives nothing", tostring(q:GetAttribute("PetAcc")))
	local xp0 = lvXP(dq.Pets.List.P1)
	o.P.AddPetXP(q, "P1", 20)
	check(lvXP(dq.Pets.List.P1) - xp0 == 20, "switch off: a worn PetArmor gives nothing (plain pet XP)", tostring(lvXP(dq.Pets.List.P1) - xp0))
end)

------------------------------------------------------------------ a pet that is gone gives its gear back
runGroup("orphans", function()
	local w = gWorld()
	local q, dq = gearer(w, 2, { Own = { ["PetAcc:1:0"] = 1 }, On = { Armor = "", Ring = "" }, Pet = { P7 = { PetAcc = "2:1", PetArmor = "1:0" }, P1 = { PetAcc = "1:0" } } },
		{ Pets = { List = { P1 = { Sp = "BabySlime", Lv = 1, XP = 0, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" }, Next = 2, Away = false } })
	check(dq.Gear.Pet.P7 == nil and dq.Gear.Own["PetAcc:2:1"] == 1 and dq.Gear.Own["PetArmor:1:0"] == 1 and dq.Gear.Own["PetAcc:1:0"] == 1 and dq.Gear.Pet.P1.PetAcc == "1:0",
		"PlayerReady: a vanished pet's gear goes back to Own, a pet I still have keeps its", show(dq.Gear))
	check(near(q:GetAttribute("PetAcc"), 0.01), "the pet I still have: PetAcc 0.01 at the join", tostring(q:GetAttribute("PetAcc")))
	local full = {}
	for i = 1, 3 do full["Ring:" .. i .. ":0"] = 20 end
	local r, dr = gearer(w, 3, { Own = full, On = { Armor = "", Ring = "" }, Pet = { P7 = { PetAcc = "2:1" } } },
		{ Pets = { List = { P1 = { Sp = "BabySlime", Lv = 1, XP = 0, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" }, Next = 2, Away = false } })
	check(dr.Gear.Pet.P7 and dr.Gear.Pet.P7.PetAcc == "2:1", "no room in Own: the gear stays where it is (never lost)", show(dr.Gear))
	local t, dt = gearer(w, 4, { Own = {}, On = { Armor = "", Ring = "" }, Pet = { P7 = { PetAcc = "2:1" } } }, { Pets = { List = {}, Equipped = {}, Next = 1, Away = false } })
	check(dt.Gear.Pet.P7 == nil and dt.Gear.Own["PetAcc:2:1"] == 1, "no pets at all: it goes back too", show(dt.Gear))
end)

------------------------------------------------------------------ the hooks: hits, max HP, walk speed, the power watch
local function combatWorld(o)
	local w = gWorld(o)
	local C = w.Config
	w.Reg.FactionService.GetFaction = function(p) return p:GetAttribute("Faction") end
	w.Reg.FactionService.GetPerks = function(p) return C.Factions[p:GetAttribute("Faction")] end
	w.Reg.ClassService.GetClass = function(p) return p:GetAttribute("Class") end
	w.Reg.ClassService.GetClassDef = function(p) return C.Classes[p:GetAttribute("Class")] end
	w.Reg.PvPService = { GetStars = function() return 0 end, HasRevenge = function() return false end }
	w.Reg.JusticeService = { GetDamageMult = function() return 1 end }
	w.Reg.KaijuService = { GetState = function() return "None" end }
	w.Reg.PlayerService.CharacterSpawned = w.Util.Signal.new()
	w.Combat = w:Service("CombatService", COMBAT_SOURCE)
	w.Combat.Init(w.Reg)
	local n = 100
	function w.Fighter(tier, level, enhance, extra)
		n += 1
		local attrs = { WeaponTier = tier, Level = level, WeaponEnhance = enhance, Faction = "Halo", Class = "Warrior" }
		for k, v in extra or {} do attrs[k] = v end
		local p = w:NewPlayer(n, {})
		p.Attrs = attrs
		return p
	end
	return w
end

runGroup("hits", function()
	local w = combatWorld()
	local off = combatWorld({ Off = true })
	local C, P = w.Config, w.Config.PvP
	-- a hit on a monster x the ring
	local a0, a1 = w.Fighter(2, 10, 0), w.Fighter(2, 10, 0, { GearAtk = 1.14, GearHp = 1.22 })
	local h0, h1 = w.Combat.ComputeMonsterHit(a0, false), w.Combat.ComputeMonsterHit(a1, false)
	check(near(h1 / h0, 1.14), "ComputeMonsterHit: x the ring's atk mult (1.14)", show({ h0, h1 }))
	local hs = w.Combat.ComputeMonsterHit(a1, false, C.AttackProfile("Warrior", 2, "Halo"))
	check(near(hs / w.Combat.ComputeMonsterHit(a0, false, C.AttackProfile("Warrior", 2, "Halo")), 1.14), "... the swing profile too", "")
	local o1 = off.Fighter(2, 10, 0, { GearAtk = 1.14 })
	check(near(off.Combat.ComputeMonsterHit(o1, false), off.Combat.ComputeMonsterHit(off.Fighter(2, 10, 0), false)), "the switch off: the attribute is ignored", "")
	check(near(w.Combat.ComputeMonsterHit(w.Fighter(2, 10, 0, { GearHp = 1.22 }), false), h0), "the armor does not change my hit", "")
	-- PvP: (attacker weapon x ring) / (victim weapon x ring), the same clamp; the base is the victim's BASE MaxHealth
	local function expected(a, v)
		local c = C.Classes.Warrior
		local ga, gv = a:GetAttribute("GearAtk") or 1, v:GetAttribute("GearAtk") or 1
		local ratio = C.WeaponDamage(a:GetAttribute("WeaponTier"), a:GetAttribute("Level"), a:GetAttribute("WeaponEnhance")) * ga
			/ (C.WeaponDamage(v:GetAttribute("WeaponTier"), v:GetAttribute("Level"), v:GetAttribute("WeaponEnhance")) * gv)
		ratio = math.clamp(ratio, P.PowerRatioMin, P.PowerRatioMax)
		return C.MaxHealth(v:GetAttribute("Level"), "Halo", "Warrior") * P.HitPctOfMaxHP * ratio * (c.Damage or 1) * (1 + w.Combat.GetDamageBonus(a, v))
	end
	local cases = {
		{ { 2, 10, 0 }, { 2, 10, 1 }, 1.14, 1, "attacker with a ring against a +1 weapon (inside the clamp)" },
		{ { 2, 10, 0 }, { 2, 10, 1 }, 1, 1.14, "the victim's ring lowers the ratio" },
		{ { 2, 10, 0 }, { 2, 10, 0 }, 1.14, 1.14, "both rings: the ratio is 1 again" },
		{ { 8, 100, 10 }, { 1, 1, 0 }, 1.14, 1, "far above: still PowerRatioMax (a ring cannot pass the clamp)" },
		{ { 1, 1, 0 }, { 8, 100, 10 }, 1.14, 1, "far below: still PowerRatioMin (a ring cannot pass it)" },
		{ { 3, 10, 4 }, { 3, 10, 0 }, 1, 1.14, "a +4 weapon against a ring on the other side" },
	}
	for _, c in cases do
		local a = w.Fighter(c[1][1], c[1][2], c[1][3], { GearAtk = c[3] })
		local v = w.Fighter(c[2][1], c[2][2], c[2][3], { GearAtk = c[4], GearHp = 1.22 })
		local got = w.Combat.ComputePvPHit(a, v)
		check(near(got, expected(a, v)), "ComputePvPHit: " .. c[5], show({ got, expected(a, v) }))
	end
	local a, v = w.Fighter(2, 10, 0, { GearAtk = 1.14 }), w.Fighter(2, 10, 0)
	local v2 = w.Fighter(2, 10, 0, { GearHp = 1.22 })
	check(near(w.Combat.ComputePvPHit(a, v2), w.Combat.ComputePvPHit(a, v)), "the victim's armor does not change the hit's base (the BASE MaxHealth): it only means more HP to chew through", "")
	local oa = off.Fighter(2, 10, 0, { GearAtk = 1.14 })
	check(near(off.Combat.ComputePvPHit(oa, off.Fighter(2, 10, 0)), off.Combat.ComputePvPHit(off.Fighter(2, 10, 0), off.Fighter(2, 10, 0))), "the switch off: the PvP hit ignores the attribute", "")
	-- the ratio of a weapon-less / enhanced pair keeps the old floor rules
	local bare = w.Fighter(0, 10, 0, { GearAtk = 1.14 })
	local bareOff = w.Fighter(0, 10, 0)
	check(w.Combat.ComputePvPHit(bare, v) >= w.Combat.ComputePvPHit(bareOff, v) and w.Combat.ComputePvPHit(bare, v) <= w.Combat.ComputePvPHit(bareOff, v) * 1.14 + 1e-9,
		"a bare-handed attacker with a ring: the punch floor still applies", "")
end)

runGroup("max hp / speed / watch", function()
	local w = gWorld()
	local C = w.Config
	local env = w:Env()
	local function stat(p, k, d)
		local v = p:GetAttribute(k)
		if v == nil then return d end
		return v
	end
	local maxHP = execute("MaxHP", MAXHP_SOURCE, env, C, stat, function() return 1 end)
	local hpOf = function(extra)
		local attrs = { Level = 20, Faction = "Halo", Class = "Warrior" }
		for k, v in extra do attrs[k] = v end
		return maxHP(fake(attrs))
	end
	local plain = hpOf({})
	check(hpOf({ GearHp = 1.22 }) == math.floor(C.MaxHealth(20, "Halo", "Warrior") * 1.22) and hpOf({ GearHp = 1.06 }) == math.floor(C.MaxHealth(20, "Halo", "Warrior") * 1.06),
		"computeMaxHealth: the real max HP x the armor's hp mult (floored)", show({ plain, hpOf({ GearHp = 1.22 }) }))
	check(hpOf({ GearAtk = 1.14 }) == plain and hpOf({ GearHp = 0 / 0 }) == plain and hpOf({ GearHp = 0.5 }) == plain, "the ring / NaN / below 1: the plain max HP", "")
	-- 게임성 검수 10/12: a Config without gear (test_owner_restore's trimmed one, an older build) never errors
	local trimmed = execute("Config", CONFIG_SOURCE, nativeEnv())
	trimmed.GearMultsOf = nil
	local maxHPt = execute("MaxHP", MAXHP_SOURCE, env, trimmed, stat, function() return 1 end)
	local okT, hpT = pcall(maxHPt, fake({ Level = 20, Faction = "Halo", Class = "Warrior", GearHp = 1.22 }))
	check(okT and hpT == trimmed.MaxHealth(20, "Halo", "Warrior"), "a Config without GearMultsOf: the plain max HP, no error", tostring(hpT))
	local off = gWorld({ Off = true })
	local maxHPoff = execute("MaxHP", MAXHP_SOURCE, off:Env(), off.Config, stat, function() return 1 end)
	check(maxHPoff(fake({ Level = 20, Faction = "Halo", Class = "Warrior", GearHp = 1.22 })) == plain, "the switch off: the plain max HP", "")
	-- ComputeWalkSpeed passes PetAcc
	local registry = { KaijuService = { GetState = function() return "None" end } }
	local ps = {}
	execute("speed", SPEED_SOURCE, env, ps, registry, C, w.Util, function(p) return C.Classes[p:GetAttribute("Class") or "Warrior"] end)
	local base = C.Player.WalkSpeed
	local sp = function(attrs) return ps.ComputeWalkSpeed(fake(attrs)) end
	check(near(sp({ EquippedPet = "BabySlime", PetLv = 1, PetRoll = 0, PetAcc = 0.03 }), base * 1.10), "ComputeWalkSpeed: the pet's bonus + the PetAcc attribute", tostring(sp({ EquippedPet = "BabySlime", PetLv = 1, PetRoll = 0, PetAcc = 0.03 })))
	check(near(sp({ EquippedPet = "BabySlime", PetLv = 1, PetRoll = 0 }), base * 1.07) and near(sp({ PetAcc = 0.03 }), base), "no PetAcc: the old speed; no pet: PetAcc does nothing", "")
	registry.KaijuService.GetState = function() return "Active" end
	check(near(sp({ EquippedPet = "BabySlime", PetLv = 1, PetAcc = 0.03 }), base), "a kaiju: no pet bonus at all", "")
	-- JusticeService POWER.Watch follows GearAtk / GearHp (the bully rule then uses the power with the gear)
	local seen = {}
	local POWER = { Conns = {}, Pending = {}, Drop = function() end, Schedule = function() end, Refresh = function() end }
	execute("watch", WATCH_SOURCE, env, POWER)
	POWER.Watch({ GetAttributeChangedSignal = function(_, attr)
		table.insert(seen, attr)
		return { Connect = function() return { Disconnect = function() end } end }
	end })
	table.sort(seen)
	check(table.concat(seen, ",") == "GearAtk,GearHp,Level,StatAtk,StatHp,WeaponEnhance,WeaponOpt,WeaponTier",
		"POWER.Watch: Level, WeaponTier, WeaponEnhance, StatAtk, StatHp + GearAtk, GearHp + WeaponOpt (A23-219 ②)", table.concat(seen, ","))
	-- the power the bully rule reads includes the gear (Config.CombatPowerOf)
	local pl = fake({ Level = 30, WeaponTier = 3, WeaponEnhance = 0, GearAtk = 1.14, GearHp = 1.22 })
	check(C.CombatPowerOf(pl) > C.CombatPower(30, 3, 0), "CombatPowerOf (the CombatPower attribute, the bully rule) includes the gear", "")
end)

------------------------------------------------------------------ the remotes
runGroup("remotes", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["Armor:1:0"] = 3, ["Ring:1:0"] = 3, ["PetAcc:1:0"] = 3 }))
	w.P.SummonPet(p, "BabySlime", { Spd = 6 })
	w.Gap = 1
	w:Remote("EquipGear", p, "Armor", "1:0")
	check(d.Gear.On.Armor == "1:0", "EquipGear(slot, key): the remote works", show(d.Gear.On))
	w:Remote("EquipGear", p, "Ring")
	w:Remote("EquipGear", p, "Ring", "1:0", "x")
	w:Remote("EquipGear", p)
	w:Remote("EquipGear", p, "Ring", nil)
	w:Remote("EquipGear", p, 5, "1:0")
	w:Remote("EquipGear", p, "Ring", 5)
	w:Remote("EquipGear", p, { "Ring" }, "1:0")
	w:Remote("EquipGear", p, "Ring", string.rep("1", 100))
	w:Remote("EquipGear", p, string.rep("R", 100), "1:0")
	check(d.Gear.On.Ring == "", "EquipGear: the wrong argument count / types / lengths are ignored", show(d.Gear.On))
	w.Gap = 1
	w:Remote("EquipGear", p, "Armor", "")
	w.Gap = 0.1
	w:Remote("EquipGear", p, "Ring", "1:0")
	check(d.Gear.On.Ring == "" and d.Gear.On.Armor == "", "EquipGear: two within half a second (0.5 s) = the second is ignored", show(d.Gear.On))
	w.Gap = 0.6
	w:Remote("EquipGear", p, "Ring", "1:0")
	check(d.Gear.On.Ring == "1:0", "... after half a second it works", show(d.Gear.On))
	w.Gap = 1
	w:Remote("EquipPetGear", p, "P1", "PetAcc")
	w:Remote("EquipPetGear", p, "P1", "PetAcc", "1:0", "x")
	w:Remote("EquipPetGear", p, "P1")
	w:Remote("EquipPetGear", p, "P1", "PetAcc", 5)
	w:Remote("EquipPetGear", p, 7, "PetAcc", "1:0")
	w:Remote("EquipPetGear", p, "P1", nil, "1:0")
	w:Remote("EquipPetGear", p, string.rep("P", 40), "PetAcc", "1:0")
	check(d.Gear.Pet.P1 == nil, "EquipPetGear: the wrong argument count / types / lengths are ignored", show(d.Gear.Pet))
	w:Remote("EquipPetGear", p, "P1", "PetAcc", "1:0")
	check(d.Gear.Pet.P1 and d.Gear.Pet.P1.PetAcc == "1:0", "EquipPetGear(uid, slot, key): the remote works", show(d.Gear.Pet))
	w.Gap = 0.1
	w:Remote("EquipPetGear", p, "P1", "PetAcc", "")
	check(d.Gear.Pet.P1 and d.Gear.Pet.P1.PetAcc == "1:0", "EquipPetGear: two within half a second = the second is ignored", show(d.Gear.Pet))
	w.Gap = 0.6
	w:Remote("EquipPetGear", p, "P1", "PetAcc", "")
	check(d.Gear.Pet.P1 == nil, "... after half a second it works (the take-off)", show(d.Gear.Pet))
	check(#w.Warnings == 0, "no handler error from any of them", show(w.Warnings))
end)

------------------------------------------------------------------ a scroll never touches gear (게임성 검수: +N is only the hammer's)
runGroup("scrolls", function()
	local w = gWorld()
	local gearTable = { Own = { ["Armor:1:0"] = 2, ["Ring:2:1"] = 1, ["PetArmor:1:0"] = 1 }, On = { Armor = "2:2", Ring = "1:2" }, Pet = { P1 = { PetAcc = "1:1" } } }
	local p, d = gearer(w, 1, gearTable, { Items = { Enh70 = 5, Enh30 = 2, Enh10 = 2, Move70 = 2, Move30 = 1, Jelly = 3 }, WeaponOwnedMask = 3, WeaponTier = 1 })
	w.P.SummonPet(p, "BabySlime", { Spd = 6 })
	d.Gear.Pet = { P1 = { PetAcc = "1:1" } }
	w.P.Refresh(p)
	w:Service("LootService", LOOT_SOURCE)
	w.Reg.LootService.Init(w.Reg)
	w.Reg.LootService.Start()
	local snap = show(d.Gear)
	local attrs = show({ p:GetAttribute("GearAtk"), p:GetAttribute("GearHp"), p:GetAttribute("PetAcc") })
	local items = show(d.Items)
	w.Gap = 1
	local probes = {
		{ "Enh70", "Armor:1:0" }, { "Enh70", "Ring" }, { "Enh70", "1:0" }, { "Enh70", "Armor" }, { "Enh10", "PetArmor:1:0" }, { "Enh30", "Ring:2:1" },
		{ "Move70", "Armor:1:0", "Ring:2:1" }, { "Move30", "Ring:2:1", "Armor:1:0" }, { "Move70", "2:2", "1:2" }, { "Enh70", "On" }, { "Enh70", { Slot = "Armor" } },
		{ "Enh70", "Armor", "Plus" }, { "Enh70", 1.5 }, { "Enh70", 0 }, { "Enh70", -1 }, { "Enh70", math.huge }, { "Enh70", 0 / 0 }, { "Move70", 1, "Armor:1:0" },
		{ "Move70", "Armor:1:0" }, { "Armor:1:0" }, { "Enh70", "Armor:1:0", "Ring:1:2", "x" },
	}
	for _, args in probes do
		w:Remote("UseItem", p, table.unpack(args))
	end
	check(show(d.Gear) == snap and show({ p:GetAttribute("GearAtk"), p:GetAttribute("GearHp"), p:GetAttribute("PetAcc") }) == attrs,
		"UseItem with a gear key / slot / junk: the Gear table and its attributes never change", show(d.Gear))
	check(show(d.Items) == items, "... and no scroll is used up by it", show(d.Items))
	check(#w.Warnings == 0, "... and no handler error (a gear key is no weapon tier)", show(w.Warnings))
	-- the control: a real scroll on a weapon tier works in this harness and still leaves the gear alone
	w:Remote("UseItem", p, "Enh70", 1)
	check(d.Items.Enh70 == 4, "control: Enh70 on weapon tier 1 uses the scroll", tostring(d.Items.Enh70))
	check(show(d.Gear) == snap and d.Gear.On.Armor == "2:2" and d.Gear.On.Ring == "1:2", "... and the gear is the same", show(d.Gear))
	-- a worn gear's plus is at most the hammer's +2, and GearService never makes it bigger
	local q, dq = gearer(w, 2, bag({ ["Armor:1:2"] = 1, ["Armor:2:0"] = 1 }))
	w.G.Equip(q, "Armor", "1:2")
	w.G.Equip(q, "Armor", "2:0")
	check(dq.Gear.Own["Armor:1:2"] == 1 and dq.Gear.On.Armor == "2:0", "a swap moves the same key back: the plus stays what it was (+2)", show(dq.Gear))
	local fixed = w.Config.SanitizeGear({ Own = { ["Armor:1:3"] = 1, ["Armor:1:10"] = 2, ["Ring:1:2"] = 1 }, On = { Armor = "2:5", Ring = "1:2" }, Pet = { P1 = { PetAcc = "1:4" } } })
	check(next(fixed.Pet) == nil and fixed.On.Armor == "" and fixed.On.Ring == "1:2" and fixed.Own["Ring:1:2"] == 1 and fixed.Own["Armor:1:3"] == nil and fixed.Own["Armor:1:10"] == nil,
		"a save with a +3..+10 gear: the repair drops it (P stays 0..2)", show(fixed))
end)

------------------------------------------------------------------ not during a fight (게임성 개발 2)
runGroup("combat", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["Armor:1:0"] = 1, ["PetAcc:1:0"] = 1 }))
	w.P.SummonPet(p, "BabySlime", { Spd = 6 })
	w.Reg.CombatService.InCombat[p] = true
	local snap = show(d.Gear)
	local from = #w.Notices
	check(w.G.Equip(p, "Armor", "1:0") == "combat" and show(d.Gear) == snap and p:GetAttribute("GearHp") == 1
		and keysFor(w, p, from)[1] == "Config.Gear.Text.InCombat", "in a fight: no armor on (InCombat, a key), nothing moves", "")
	check(w.G.EquipPet(p, "P1", "PetAcc", "1:0") == "combat" and show(d.Gear) == snap, "in a fight: no pet gear either", "")
	w.Reg.CombatService.InCombat[p] = nil
	check(w.G.Equip(p, "Armor", "1:0") == "ok" and w.G.EquipPet(p, "P1", "PetAcc", "1:0") == "ok", "after the fight: both go on", "")
	w.Reg.CombatService.InCombat[p] = true
	check(w.G.Equip(p, "Armor", "") == "combat" and d.Gear.On.Armor == "1:0", "in a fight: no taking it off", "")
	w.Reg.CombatService.InCombat[p] = nil
	w.Reg.CombatService.IsInCombat = function() error("offline failure") end
	check(w.G.Equip(p, "Armor", "") == "ok", "a failing IsInCombat: not a fight (never stuck)", "")
end)

------------------------------------------------------------------ a level drop pauses gear (게임성 검수 10/12)
runGroup("level drop", function()
	local w = gWorld()
	local p, d = gearer(w, 1, bag({ ["Armor:3:0"] = 1, ["Ring:1:0"] = 1 }))
	check(w.G.Equip(p, "Armor", "3:0") == "ok" and w.G.Equip(p, "Ring", "1:0") == "ok" and near(p:GetAttribute("GearHp"), 1.18)
		and near(p:GetAttribute("GearAtk"), 1.04), "Lv30: armor T3 x1.18, ring T1 x1.04", "")
	local refreshes = #w.Refreshes
	w.PS.SetStat(p, "Level", 1) -- a free class change / a rebirth
	w:RunSpawned()
	check(p:GetAttribute("GearHp") == 1 and p:GetAttribute("GearAtk") == 1 and d.Gear.On.Armor == "3:0" and d.Gear.On.Ring == "1:0"
		and #w.Refreshes > refreshes, "Lv1: both pause (x1), still worn; the max HP re-read", show({ p:GetAttribute("GearHp"), p:GetAttribute("GearAtk") }))
	w.PS.SetStat(p, "Level", 10)
	w:RunSpawned()
	check(p:GetAttribute("GearHp") == 1 and near(p:GetAttribute("GearAtk"), 1.04), "Lv10: the T1 ring counts again, the T3 armor waits for Lv30", "")
	local a, h = w.G.Mults(p)
	check(near(a, 1.04) and h == 1, "GearService.Mults says the same", show({ a, h }))
	w.PS.SetStat(p, "Level", 30)
	w:RunSpawned()
	check(near(p:GetAttribute("GearHp"), 1.18), "Lv30 again: the armor counts", "")
	-- ③ GearService.SendInfo (CraftService after a gear craft)
	local n = #fired(w, "GearInfo", p)
	check(w.G.SendInfo(p) == true and #fired(w, "GearInfo", p) == n + 1, "SendInfo: one GearInfo", "")
	local o = gWorld({ Off = true })
	local q = gearer(o, 1, bag({}))
	check(o.G.SendInfo(q) == false and #fired(o, "GearInfo", q) == 0, "switch off: no GearInfo", "")
end)

finish()
