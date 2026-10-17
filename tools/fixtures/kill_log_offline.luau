-- kill_log_offline.luau : A23-86 D - the monster kill record (KillLog, 게임성 개발 3, 2026-10-09).
-- tools/test_kill_log.py binds CONFIG_SOURCE, UTIL_SOURCE and LOG_SOURCE in front of dev2_kit.luau + dev3_world.luau; this
-- file follows. KillLog runs from source; PlayerService / MonsterService.MonsterKilled are the dev3_world doubles.

local NOON = 1789959600

local function logWorld()
	local w = dev3World({ Time = NOON })
	w:Service("KillLog", LOG_SOURCE)
	w:InitStart({ "KillLog" })
	return w
end

local function hero(w, id, extra)
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 10, WeaponTier = 3 }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function kill(w, p, kind, extra)
	local info = { Kind = kind, ZoneId = "SlimeMeadow", Golden = false, Personal = false }
	for k, v in extra or {} do info[k] = v end
	w.Reg.MonsterService.MonsterKilled:Fire(p, info)
	w:RunSpawned()
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local d = C.Data.Defaults.KillLog
	check(d.Total == 0 and d.M == 0 and d.A == 0 and d.Golden == 0 and next(d.ByKind) == nil and next(d.ByTier) == nil, "save default KillLog", show(d))
	check(C.Data.Version == 7, "data version 7 = A23-219 ②'s crafted options (6 = A23-186's joke weapons, 5 = A23-153's codex, 4 = C1's tier 9) (the kill log is an additive field)", C.Data.Version)
end)

runGroup("counting", function()
	local w = logWorld()
	local p, d = hero(w, 1)
	kill(w, p, "Slime")
	kill(w, p, "Slime")
	kill(w, p, "BigSlime")
	local k = d.KillLog
	check(k.Total == 3 and k.M == 3 and k.A == 0 and k.Golden == 0, "three kills by hand", show(k))
	check(k.ByKind.Slime == 2 and k.ByKind.BigSlime == 1, "by monster kind", show(k.ByKind))
	check(k.ByTier["3"].M == 3 and k.ByTier["3"].A == 0, "by weapon tier 3: M 3 / A 0", show(k.ByTier))
	-- auto combat on: A
	d.AutoCombatEnabled = true
	p:SetAttribute("AutoCombatEnabled", true)
	kill(w, p, "Slime")
	kill(w, p, "Goblin")
	check(k.Total == 5 and k.M == 3 and k.A == 2 and k.ByTier["3"].A == 2 and k.ByTier["3"].M == 3, "auto kills are counted apart (A)", show(k))
	-- a golden one
	kill(w, p, "Slime", { Golden = true })
	check(k.Golden == 1 and k.Total == 6, "a golden monster", show(k))
	-- another weapon tier
	p:SetAttribute("WeaponTier", 4)
	p:SetAttribute("AutoCombatEnabled", false)
	kill(w, p, "Goblin")
	check(k.ByTier["4"] and k.ByTier["4"].M == 1 and k.ByTier["3"].M == 3, "a new weapon tier gets its own row", show(k.ByTier))
	-- bare hands = tier 0
	p:SetAttribute("WeaponTier", 0)
	kill(w, p, "Slime")
	check(k.ByTier["0"] and k.ByTier["0"].M == 1, "tier 0 (bare hands)", show(k.ByTier))
end)

runGroup("what does not count", function()
	local w = logWorld()
	local p, d = hero(w, 2)
	kill(w, p, "Slime", { Personal = true })
	check(d.KillLog == nil or d.KillLog.Total == 0, "a personal (tutorial) monster", show(d.KillLog))
	kill(w, p, "NoSuchMonster")
	kill(w, p, nil)
	w.Reg.MonsterService.MonsterKilled:Fire(p, "oops")
	w.Reg.MonsterService.MonsterKilled:Fire(p, nil)
	w:RunSpawned()
	check(d.KillLog == nil or d.KillLog.Total == 0, "an unknown kind, no kind, a broken info", show(d.KillLog))
	check(#w.Warnings == 0, "and no warning from any of it", show(w.Warnings))
end)

runGroup("two players", function()
	local w = logWorld()
	local a, ad = hero(w, 3)
	local b, bd = hero(w, 4, { WeaponTier = 5 })
	kill(w, a, "Slime")
	kill(w, b, "Goblin")
	kill(w, b, "Goblin")
	check(ad.KillLog.Total == 1 and bd.KillLog.Total == 2 and bd.KillLog.ByTier["5"].M == 2 and ad.KillLog.ByKind.Goblin == nil, "each save is its own", show({ ad.KillLog, bd.KillLog }))
end)

runGroup("the save is repaired", function()
	local w = logWorld()
	local p, d = hero(w, 5, { KillLog = { Total = -5, M = "x", A = 1e12, Golden = 0 / 0, ByKind = { Slime = 7.9, Ghost = 3, [5] = 2, BigSlime = -1 },
		ByTier = { ["3"] = { M = 4, A = -2 }, ["99"] = { M = 1 }, ["x"] = { M = 1 }, ["2.5"] = { M = 1 }, ["4"] = "oops" } } })
	local k = d.KillLog
	check(k.Total == 0 and k.M == 0 and k.A == 1000000000 and k.Golden == 0, "numbers are whole and between 0 and a billion", show(k))
	check(k.ByKind.Slime == 7 and k.ByKind.Ghost == nil and k.ByKind[5] == nil and k.ByKind.BigSlime == 0, "unknown kinds dropped, whole numbers", show(k.ByKind))
	check(k.ByTier["3"].M == 4 and k.ByTier["3"].A == 0 and k.ByTier["99"] == nil and k.ByTier["x"] == nil and k.ByTier["2.5"] == nil and k.ByTier["4"] == nil,
		"only real weapon tiers with a table", show(k.ByTier))
	local q, qd = hero(w, 6, { KillLog = "oops" })
	check(type(qd.KillLog) == "table" and qd.KillLog.Total == 0, "a broken table is replaced", show(qd.KillLog))
	local r, rd = hero(w, 7, { KillLog = { Total = 999999999, M = 999999999, A = 0, Golden = 0, ByKind = { Slime = 999999999 }, ByTier = { ["3"] = { M = 999999999, A = 0 } } } })
	kill(w, r, "Slime")
	kill(w, r, "Slime")
	check(rd.KillLog.Total == 1000000000 and rd.KillLog.M == 1000000000 and rd.KillLog.ByKind.Slime == 1000000000 and rd.KillLog.ByTier["3"].M == 1000000000,
		"a billion is the ceiling", show(rd.KillLog))
end)

finish()
