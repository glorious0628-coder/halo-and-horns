-- attendance_offline.luau : SPEC A23-77 출석 = 모은 날 수 (게임성 개발 3). tools/test_attendance.py binds CONFIG_SOURCE,
-- UTIL_SOURCE, ATTEND_SOURCE and TITLE_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows.
-- AttendanceService and TitleService run from source; PlayerService / ProgressionService / LootService /
-- MonetizationService are the dev3_world doubles (A23-75's GrantLook and 2x passes included).

local NOON = 1789959600 -- 2026-09-22 12:00 KST (a quiet mid-day start: every test moves days with w:ToDay)
-- dev2's A23-75 attendance looks (Game-dev2-mtest Config.Looks, not on main yet): injected where a test needs them
local function withLooks(c)
	c.Looks = {
		HaloIce = { Faction = "Halo", PassId = 0, Price = 99, Name = "Ice Halo", Order = 1 },
		HaloSprout = { Faction = "Halo", Unlock = { Attendance = 14 }, Name = "Sprout Halo", Order = 5 },
		HornsSprout = { Faction = "Horns", Unlock = { Attendance = 14 }, Name = "Sprout Horns", Order = 6 },
		HaloStarlight = { Faction = "Halo", Unlock = { Attendance = 50 }, Name = "Star Halo", Order = 7 },
		HornsStarlight = { Faction = "Horns", Unlock = { Attendance = 50 }, Name = "Star Horns", Order = 8 },
		HaloPlatinum = { Faction = "Halo", Unlock = { Attendance = 100 }, Name = "Plat Halo", Order = 9 },
		HornsPlatinum = { Faction = "Horns", Unlock = { Attendance = 100 }, Name = "Plat Horns", Order = 10 },
	}
end

local function attendWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	w:Service("TitleService", TITLE_SOURCE)
	w:Service("AttendanceService", ATTEND_SOURCE)
	w:InitStart({ "TitleService", "AttendanceService" })
	return w
end

local function hero(w, id, jo)
	jo = jo or {}
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 1 }
	for k, v in jo.Data or {} do data[k] = v end
	jo.Data = data
	return w:Arrive(id, jo)
end

local function claim(w, p, ...) w:Remote("ClaimAttendance", p, ...) end
local function attrs(p)
	return string.format("days=%s slot=%s ready=%s", tostring(p:GetAttribute("AttendDays")),
		tostring(p:GetAttribute("AttendSlot")), tostring(p:GetAttribute("AttendReady")))
end
local function lastFx(w, p)
	local list = w:FxOf("Attendance", p)
	return list[#list] and list[#list].Data
end
local function goldFor(w, p, src)
	local n = 0
	for _, g in w.Gold do if g.P == p and (src == nil or g.Src == src) then n += g.Got end end
	return n
end
local function lastNotice(w, p)
	local list = w:NoticesFor(p)
	return list[#list]
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local A = C.Attendance
	local b = A.Board
	check(#b == 7, "the board has 7 slots (A23-77)", #b)
	check(b[1].Potion == "HP" and b[1].N == 2 and b[2].GoldMin == 3 and b[3].Item == "Enh70" and b[3].N == 1
		and b[4].GoldMin == 3 and b[5].Potion == "HP" and b[5].N == 3 and b[5].MaterialMin == 4 and b[6].XPMin == 5
		and b[7].GoldMin == 10 and b[7].XPMin == 10 and b[7].Item == "Enh30" and b[7].Box == true,
		"slots: 2 potions · 3 min gold · 70% scroll · 3 min gold · 3 potions + 4 min materials · 5 min XP · box (10 min "
			.. "gold + XP + 30% scroll)", show(b))
	local days = {}
	for _, m in A.Milestones do table.insert(days, m.Days) end
	check(table.concat(days, ",") == "7,14,28,50,100", "milestones at 7 / 14 / 28 / 50 / 100 days", table.concat(days, ","))
	check(A.Milestones[1].Title == "Regular" and A.Milestones[3].Border ~= nil and A.Milestones[4].Title ~= nil
		and A.Milestones[5].Title ~= nil, "7 = 'Regular', 28 = the name frame, 50 / 100 = titles", show(A.Milestones))
	for _, id in { "Regular", "SuperRegular", "MegaRegular" } do
		check(C.TitleDefs[id] ~= nil and table.find(C.TitleOrder, id) ~= nil, "title " .. id .. " defined and pickable",
			show(C.TitleOrder))
	end
	check(table.find(C.TitleOrder, "BetaPioneer") == 1, "older titles keep their place", show(C.TitleOrder))
	local d = C.Data.Defaults.Attendance
	check(type(d) == "table" and d.Days == 0 and d.LastDay == 0 and d.Slot == 1, "save default { Days 0, LastDay 0, Slot 1 }",
		show(d))
	check(C.Data.Version == 5, "data version 5 = A23-153's codex (C1's tier 9 made it 4) (attendance is an additive field)", C.Data.Version)
	check(C.RateLimits.ClaimAttendance == 1, "ClaimAttendance 1 s", C.RateLimits.ClaimAttendance)
	-- A23-77 size: about 3-5 hunting minutes a day, about 30 a week (gold + XP minutes of the board)
	local minutes = 0
	for _, s in b do minutes += (s.GoldMin or 0) / 2 + (s.XPMin or 0) / 2 end
	check(minutes >= 10 and minutes <= 20, "the week's gold + XP is about 15 hunting minutes (items make the rest)", minutes)
end)

runGroup("a week, day by day", function()
	local w = attendWorld()
	local C = w.Config
	local p, d = hero(w, 1)
	check(attrs(p) == "days=0 slot=1 ready=true", "a new hero: a claim is open, slot 1", attrs(p))
	claim(w, p)
	check(d.HPPotionCount == 2 and d.Attendance.Days == 1 and d.Attendance.Slot == 2
		and d.Attendance.LastDay == C.DayIndex(w.Time), "day 1: 2 HP potions; days 1, next slot 2", show(d.Attendance))
	check(attrs(p) == "days=1 slot=2 ready=false", "claimed: no claim open until 00:00 KST", attrs(p))
	local fx = lastFx(w, p)
	check(fx and fx.Slot == 1 and fx.Days == 1 and fx.Items[1].Id == "HP" and fx.Items[1].N == 2 and fx.Box == false,
		"Fx Attendance { Slot 1, Days 1, Items HP x2 }", show(fx))
	check(lastNotice(w, p) == "Day 1 reward! +HP Potion x2", "the line says what came", lastNotice(w, p))
	claim(w, p)
	claim(w, p)
	check(d.HPPotionCount == 2 and d.Attendance.Days == 1 and #w:FxOf("Attendance", p) == 1,
		"the same day: more claims pay nothing", show(d.Attendance))
	-- day 2: 3 minutes of gold at Lv1 (HuntValue)
	w:ToDay(1)
	w:Tick(0)
	check(attrs(p) == "days=1 slot=2 ready=true", "00:00 KST: the claim opens for the online player", attrs(p))
	claim(w, p)
	local g3 = C.HuntValue(1, 3)
	check(goldFor(w, p, "Attendance") == g3 and g3 > 0, "day 2: 3 hunting minutes of gold, source 'Attendance'",
		goldFor(w, p, "Attendance") .. " / " .. g3)
	w:ToDay(1)
	claim(w, p)
	check(d.Items.Enh70 == 1, "day 3: one 70% enhance scroll", show(d.Items))
	w:ToDay(1)
	claim(w, p)
	check(goldFor(w, p, "Attendance") == 2 * g3, "day 4: 3 more minutes of gold", goldFor(w, p, "Attendance"))
	w:ToDay(1)
	claim(w, p)
	local jelly = math.floor(C.Economy.KillsPerMinute * 4 * 0.30 + 0.5)
	check(d.HPPotionCount == 5 and d.Items.Jelly == jelly and jelly == 14,
		"day 5: 3 HP potions + 4 minutes of the zone's materials (slime zone: 14 Jelly)", show(d.Items))
	w:ToDay(1)
	claim(w, p)
	local _, x5 = C.HuntValue(1, 5)
	check(d.XP == x5 and x5 > 0, "day 6: 5 hunting minutes of XP", tostring(d.XP) .. " / " .. x5)
	check(not d.Titles.Regular, "6 days: no 'Regular' yet", show(d.Titles))
	w:ToDay(1)
	local before = #w:NoticesFor(p)
	claim(w, p)
	local g10, x10 = C.HuntValue(1, 10)
	fx = lastFx(w, p)
	check(fx.Slot == 7 and fx.Box == true and fx.Gold == g10 and fx.XP == x10 and d.Items.Enh30 == 1,
		"day 7: the weekly box = 10 minutes of gold + XP + a 30% scroll", show(fx))
	check(d.Titles.Regular ~= nil and p:GetAttribute("TitlesOwned"):find("Regular") ~= nil,
		"7 days collected: the stat-free title 'Regular'", show(d.Titles))
	local lines = w:NoticesFor(p, before)
	-- A23-130: the milestone fanfare rides on its reward line (no "7 days collected!", no empty notice)
	local sounds = w:SoundsFor(p, before)
	local at = table.find(lines, "New title: Regular!")
	check(at ~= nil and sounds[at] == "RankUp" and not table.find(lines, "7 days collected!") and not table.find(lines, ""),
		"7 days: one title line with the RankUp fanfare", show({ lines, sounds }))
	check(attrs(p) == "days=7 slot=1 ready=false", "after the box the board starts at slot 1 again", attrs(p))
	w:ToDay(1)
	claim(w, p)
	check(d.HPPotionCount == 7 and d.Attendance.Days == 8 and d.Attendance.Slot == 2, "day 8 = slot 1 again (2 potions)",
		show(d.Attendance))
	check(#w.XPs == 2, "XP only on day 6 and the box", #w.XPs)
end)

runGroup("missed days never reset", function()
	local w = attendWorld()
	local p, d = hero(w, 1)
	claim(w, p)
	w:ToDay(1)
	claim(w, p)
	check(d.Attendance.Slot == 3 and d.Attendance.Days == 2, "two days: slot 3 next", show(d.Attendance))
	w:Leave(p)
	-- 9 days away, then back on another server with the same save
	local w2 = attendWorld({ Time = w.Time })
	w2:ToDay(9)
	local q, d2 = hero(w2, 1, { Data = { Attendance = deepCopy(d.Attendance), Items = {} } })
	check(attrs(q) == "days=2 slot=3 ready=true", "back after 9 days: the same slot waits, nothing lost", attrs(q))
	claim(w2, q)
	check(d2.Items.Enh70 == 1 and d2.Attendance.Days == 3 and d2.Attendance.Slot == 4,
		"the claim pays slot 3 and counts one more day (missed days are just skipped)", show(d2.Attendance))
end)

runGroup("the KST day line", function()
	local w = attendWorld()
	local p, d = hero(w, 1)
	w:ToDay(1, -30) -- 23:59:30 KST
	claim(w, p)
	check(d.Attendance.Days == 1, "a claim at 23:59:30", show(d.Attendance))
	w:Advance(40) -- 00:00:10 KST the next day
	check(p:GetAttribute("AttendReady") == false, "before the day check runs the attribute still says claimed", attrs(p))
	w:Tick(0)
	check(p:GetAttribute("AttendReady") == true, "the day check turns the claim on after 00:00 KST", attrs(p))
	claim(w, p)
	check(d.Attendance.Days == 2 and d.Attendance.Slot == 3, "a new KST day = a new claim", show(d.Attendance))
end)

runGroup("who may claim", function()
	local w = attendWorld()
	local p, d = w:Arrive(1, { Data = { Faction = "None", ClassChosen = false } })
	check(p:GetAttribute("AttendReady") == false, "before the class pick: no claim", attrs(p))
	claim(w, p)
	check(d.Attendance.Days == 0, "a claim before the class pick is ignored", show(d.Attendance))
	-- the class pick (ClassService sets the stat + attribute): the claim opens at once
	w.PS.SetStat(p, "ClassChosen", true)
	check(p:GetAttribute("AttendReady") == true, "the class pick opens the claim", attrs(p))
	w.Gap = 0.2
	claim(w, p) -- 0.2 s after the refused call: rate limited
	check(d.Attendance.Days == 0, "ClaimAttendance is rate limited (1 s)", show(d.Attendance))
	w.Gap = 1.1
	claim(w, p, "extra")
	check(d.Attendance.Days == 0, "any argument: ignored", show(d.Attendance))
	claim(w, p)
	check(d.Attendance.Days == 1, "then a plain call claims", show(d.Attendance))
	local q, dq = hero(w, 2)
	w.Ready[q] = nil
	claim(w, q)
	check(dq.Attendance.Days == 0, "a player who is not ready: ignored", show(dq.Attendance))
end)

runGroup("broken saves are repaired", function()
	local w = attendWorld()
	local C = w.Config
	local today = C.DayIndex(w.Time)
	local p1, d1 = hero(w, 1, { Data = { Attendance = "broken" } })
	check(type(d1.Attendance) == "table" and d1.Attendance.Days == 0 and d1.Attendance.Slot == 1
		and p1:GetAttribute("AttendReady") == true, "a non-table record starts fresh", show(d1.Attendance))
	local p2, d2 = hero(w, 2, { Data = { Attendance = { Days = -4, LastDay = 1e12, Slot = 99 } } })
	check(d2.Attendance.Days == 0 and d2.Attendance.LastDay == 0 and d2.Attendance.Slot == 1
		and p2:GetAttribute("AttendReady") == true,
		"negative days, a LastDay far in the future, slot 99 -> 0, 0 (claim open), 1", show(d2.Attendance))
	local p3, d3 = hero(w, 3, { Data = { Attendance = { Days = 12.7, LastDay = today, Slot = 3.9 } } })
	check(d3.Attendance.Days == 12 and d3.Attendance.Slot == 3 and p3:GetAttribute("AttendReady") == false,
		"fractions floor; claimed today stays claimed", show(d3.Attendance))
	local p4, d4 = hero(w, 4, { Data = { Attendance = { Days = 0 / 0, LastDay = 0 / 0, Slot = 0 / 0 } } })
	check(d4.Attendance.Days == 0 and d4.Attendance.LastDay == 0 and d4.Attendance.Slot == 1, "NaN -> 0, 0, 1",
		show(d4.Attendance))
	local p5, d5 = hero(w, 5, { Data = { Attendance = { Days = 40, LastDay = today + 1, Slot = 2 } } })
	check(d5.Attendance.LastDay == today + 1 and p5:GetAttribute("AttendReady") == false,
		"a LastDay one day ahead (another server's clock) is kept: no double claim", show(d5.Attendance))
	local _ = p4
end)

runGroup("A23-75 2x passes", function()
	local w = attendWorld({ GoldMult = 2, XPMult = 2 })
	local C = w.Config
	local p, d = hero(w, 1, { Data = { Attendance = { Days = 6, LastDay = 0, Slot = 7 } } })
	claim(w, p)
	local g10, x10 = C.HuntValue(1, 10)
	local fx = lastFx(w, p)
	check(w.Gold[1].N == g10 and w.Gold[1].Src == "Attendance" and w.XPs[1].N == x10,
		"the service asks for the plain amounts (the pass doubles them inside ProgressionService)",
		tostring(w.Gold[1] and w.Gold[1].N) .. " " .. tostring(w.Gold[1] and w.Gold[1].Src))
	check(fx.Gold == 2 * g10 and fx.XP == 2 * x10, "Fx / line show what was really added (doubled)", show(fx))
	check(string.find(w:NoticesFor(p)[1] or "", tostring(2 * g10), 1, true) ~= nil, "the line shows the doubled gold",
		w:NoticesFor(p)[1])
	local _ = d
end)

runGroup("a full potion bag", function()
	local w = attendWorld()
	local C = w.Config
	local cap = C.Vitals.PotionInventoryCap
	local p, d = hero(w, 1, { Data = { HPPotionCount = cap - 1 } })
	claim(w, p)
	check(d.HPPotionCount == cap and goldFor(w, p, "Attendance") == C.Vitals.PotionPrices.HP,
		"one bottle fits, the other is paid at the potion price", tostring(d.HPPotionCount) .. " / " .. goldFor(w, p))
end)

runGroup("rewards follow the level zone", function()
	local w = attendWorld()
	local C = w.Config
	local p, d = hero(w, 1, { Data = { Level = 30, Attendance = { Days = 1, LastDay = 0, Slot = 2 } } })
	claim(w, p)
	check(goldFor(w, p) == C.HuntValue(30, 3), "Lv30: 3 minutes of skeleton-ruins gold", goldFor(w, p))
	w:ToDay(1)
	d.Attendance.Slot = 5
	claim(w, p)
	local skeletonRows = C.Loot.Tables[C.ZoneMainMonster[C.QuestZoneForLevel(30)]]
	local expect = {}
	for _, row in skeletonRows do
		local def = row.Item and C.Loot.Items[row.Item]
		if def and def.Kind == "Material" then
			expect[row.Item] = math.floor(C.Economy.KillsPerMinute * 4 * row.P * (row.N or 1) + 0.5)
		end
	end
	local ok = next(expect) ~= nil
	for id, n in expect do if (d.Items[id] or 0) ~= n then ok = false end end
	check(ok and d.Items.Jelly == nil, "Lv30: the materials of the skeleton table (no jelly)", show(d.Items) .. " vs " .. show(expect))
end)

runGroup("milestones and attendance looks", function()
	local w = attendWorld({ EditConfig = withLooks })
	local p, d = hero(w, 1, { Data = { Attendance = { Days = 13, LastDay = 0, Slot = 7 } } })
	check(#w.Looks == 0, "13 days: no attendance look yet", #w.Looks)
	local before = #w:NoticesFor(p)
	claim(w, p)
	local ids = {}
	for _, l in w.Looks do table.insert(ids, l.Id) end
	table.sort(ids)
	check(table.concat(ids, ",") == "HaloSprout,HornsSprout", "14 days: both factions' 14-day looks (never a sold one)",
		table.concat(ids, ","))
	local lines = w:NoticesFor(p, before)
	check(table.find(lines, "New look: Sprout Halo!") and w:SoundsFor(p, before)[table.find(lines, "New look: Sprout Halo!")] == "RankUp"
		and not table.find(lines, "New look: Sprout Horns!") and not table.find(lines, "14 days collected!"),
		"the lines name my own faction's look only (it carries the fanfare)", show(lines))
	-- 게임성 검수 10/12: the artisan guild (Neutral) gets no Halo / Horns look at 14 days -> one "14 days collected!" line
	local nn, dn = hero(w, 4, { Data = { Faction = "Neutral", Attendance = { Days = 13, LastDay = 0, Slot = 7 } } })
	local fromN = #w.Notices
	claim(w, nn)
	local nLines, nSounds = w:NoticesFor(nn, fromN), w:SoundsFor(nn, fromN)
	local nAt = table.find(nLines, "14 days collected!")
	check(nAt ~= nil and nSounds[nAt] == "RankUp" and not table.find(nLines, "") and not table.find(nLines, "New look: Sprout Halo!"),
		"Neutral at 14 days: '14 days collected!' with the fanfare (never a sound with no words)", show({ nLines, nSounds }))
	-- a save that already has 120 days (e.g. the titles came later): everything up to 120, silently, at join
	local q, dq = hero(w, 2, { Data = { Faction = "Horns", Attendance = { Days = 120, LastDay = 0, Slot = 4 } } })
	check(dq.Titles.Regular and dq.Titles.SuperRegular and dq.Titles.MegaRegular, "120 days: every attendance title at join",
		show(dq.Titles))
	local n = 0
	for _, l in w.Looks do if l.P == q then n += 1 end end
	check(n == 6, "120 days: all 6 attendance looks at join", n)
	check(#w:NoticesFor(q) == 0, "the join catch-up says nothing", show(w:NoticesFor(q)))
	check(not table.find(w.LookAsks, "HaloIce"), "a sold look (no Unlock) is never asked for", table.concat(w.LookAsks, ","))
	-- the 28-day frame
	local r, dr = hero(w, 3, { Data = { Attendance = { Days = 27, LastDay = 0, Slot = 7 } } })
	claim(w, r)
	check(not table.find(w:NoticesFor(r), "") and table.find(w:NoticesFor(r), "New name frame!")
		and r:GetAttribute("AttendDays") == 28, "28 days: the name frame line + AttendDays 28 for the nametag",
		show(w:NoticesFor(r)))
	local _ = { d, dr, dn }
end)

runGroup("without A23-75's looks (main today)", function()
	local w = attendWorld()
	w.Reg.MonetizationService.GrantLook = nil
	local p, d = hero(w, 1, { Data = { Attendance = { Days = 13, LastDay = 0, Slot = 1 } } })
	claim(w, p)
	check(d.Attendance.Days == 14 and #w.Looks == 0, "no Config.Looks / GrantLook: the claim still works", show(d.Attendance))
end)

runGroup("a claim never pays twice", function()
	local w = attendWorld()
	w.AllowWarn = { "pay:", "GrantItem" }
	local p, d = hero(w, 1)
	w.LootFails, w.GoldFails = true, true -- the payment throws after the commit
	claim(w, p)
	check(d.Attendance.Days == 1 and d.Attendance.Slot == 2 and p:GetAttribute("AttendReady") == false,
		"a failing payment after the commit: the day is used, no retry the same day", show(d.Attendance))
	w.LootFails, w.GoldFails = false, false
	claim(w, p)
	check((d.HPPotionCount or 0) == 0 and d.Attendance.Days == 1, "a second call the same day pays nothing", show(d.Attendance))
end)

runGroup("signal for the metrics", function()
	local w = attendWorld()
	local got = {}
	w.Reg.AttendanceService.Claimed:Connect(function(p, slot, days) table.insert(got, p.UserId .. ":" .. slot .. ":" .. days) end)
	local p = hero(w, 1)
	claim(w, p)
	claim(w, p)
	w:ToDay(1)
	claim(w, p)
	check(table.concat(got, ",") == "1:1:1,1:2:2", "Claimed(player, slot, days) once per real claim", table.concat(got, ","))
end)

runGroup("debug next day (Studio aid)", function()
	local w = attendWorld()
	local p, d = hero(w, 1)
	claim(w, p)
	check(w.Reg.AttendanceService.DebugNextDay(p) == "ok" and p:GetAttribute("AttendReady") == true,
		"DebugNextDay opens today's claim again", attrs(p))
	claim(w, p)
	check(d.Attendance.Days == 2 and d.Attendance.Slot == 3, "and the next slot pays", show(d.Attendance))
end)

finish()
