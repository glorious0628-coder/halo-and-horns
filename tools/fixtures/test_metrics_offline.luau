-- test_metrics_offline.luau : A23-160 ④ the private test's numbers board (TestMetricsService, 게임성 개발 2, 2026-10-13; contract
-- docs/design/test_metrics_2026-10-13.md). tools/test_test_metrics.py binds CONFIG_SOURCE, UTIL_SOURCE and METRICS_SOURCE in front
-- of dev2_kit.luau + dev3_world.luau; this file follows. TestMetricsService runs from source on the dev3_world doubles
-- (MonetizationService.PassBought / PassAnswer and TelemetryService.ClientMetric are doubles here). Its flush loop is stepped by hand.

local STORE = "HaloHorns_TestMetrics_v1_STUDIO"
local ROUND = "PT1"

local function metricsWorld(o)
	o = o or {}
	local w = dev3World(o)
	local Signal = w.Util.Signal
	w.Reg.TelemetryService = { ClientMetric = Signal.new() }
	w.Reg.MonetizationService.PassBought = Signal.new()
	w.Reg.ProgressionService.XPEarned = Signal.new() -- Codex B6: (player, amount, source)
	w.Owns = {} -- [Player] = { [pass key] = true }: Roblox's answers this session (no table = Roblox has not answered)
	function w.Reg.MonetizationService.PassAnswer(p, key)
		if w.Owns[p] == nil then return nil end
		return w.Owns[p][key] == true
	end
	-- the saved last answer: HasPass says yes, but it proves nothing about this join (never read for Kept)
	function w.Reg.MonetizationService.HasPass() return true end
	w:Service("TestMetricsService", METRICS_SOURCE)
	w:InitStart({ "TestMetricsService" })
	w.TM = w.Reg.TestMetricsService
	function w:Doc(store)
		local s = self.Stores[store or STORE]
		return s and s.Rows[ROUND] or nil
	end
	return w
end

-- a brand-new account (the defaults: no intro, Lv1, no kill, 0 s)
local function rookie(w, id, data)
	return w:Arrive(id, { Data = data or {} })
end

-- a save from before the test
local function veteran(w, id)
	return w:Arrive(id, { Data = { IntroSeen = true, Faction = "Horns", Level = 12, TotalKills = 300, PlaytimeSeconds = 9000 } })
end

-- the same account joining again (its saved data, deep-copied like a reload)
local function rejoin(w, p, d)
	w:Leave(p)
	return w:Arrive(p.UserId, { Data = d })
end

local function at(p, seconds)
	p:SetAttribute("PlaytimeSeconds", seconds)
end

local function pend(w)
	return w.TM.Pending()
end

local function min(d, m, minute)
	return d.Min and d.Min[m] and d.Min[m][tostring(minute)] or 0
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local M = C.TestMetrics
	check(M.Enabled == true and M.Store == "HaloHorns_TestMetrics_v1" and M.Round == "PT1" and M.FlushSeconds == 60,
		"config: on, HaloHorns_TestMetrics_v1, round PT1, flush 60 s", show(M))
	check(M.FreshSeconds == 120 and M.TenMinutes == 10 and M.MaxMinute == 60 and M.KeptDelay == 20,
		"fresh under 120 s, the 10-minute run, minute cap 60, the rejoin check 20 s after the join", show(M))
	check(table.concat(M.Milestones, ",") == "Lv5,Lv10,Weapon,Claim,DropWeapon", "the milestones Lv5, Lv10, Weapon, Claim, DropWeapon (GPT ④)", show(M.Milestones))
	check(C.Tutorial.Steps.Done == 99, "the claimed tutorial step is 99 (the Claim milestone reads it)", show(C.Tutorial.Steps))
end)

------------------------------------------------------------------ the first screen
runGroup("first screen", function()
	local w = metricsWorld()
	local p = rookie(w, 1)
	local v = veteran(w, 2)
	local d = pend(w)
	check(d.Players == 2 and d.New == 1 and d.Joins == 2, "two accounts seen, one new (the veteran is not new), two joins", show(d))
	check((d.Intro or 0) == 0 and (d.Faction or 0) == 0, "the veteran's intro and side are not first-screen numbers", show(d))
	p:SetAttribute("IntroSeen", true)
	p:SetAttribute("IntroSeen", false)
	p:SetAttribute("IntroSeen", true)
	d = pend(w)
	check(d.Intro == 1, "the intro finished = Intro 1 (once)", show(d))
	p:SetAttribute("Faction", "None")
	check((pend(w).Faction or 0) == 0, "no side yet (None) = not counted", show(pend(w)))
	p:SetAttribute("Faction", "Halo")
	p:SetAttribute("Faction", "Horns")
	d = pend(w)
	check(d.Faction == 1 and d.Side.Halo == 1 and d.Side.Horns == nil, "the first side picked = Faction 1, Side.Halo 1 (a change later is not)", show(d))
	v:SetAttribute("Level", 13)
	check((pend(w).Min or {}).Lv5 == nil, "a veteran's level-up is not a milestone", show(pend(w)))
	local q = rookie(w, 3, { PlaytimeSeconds = 400 })
	check(pend(w).New == 1 and pend(w).Players == 3, "400 s of play already = not fresh (FreshSeconds 120)", show(pend(w)))
	local i = rookie(w, 6, { IntroSeen = true })
	check(pend(w).New == 1 and pend(w).Players == 4, "the intro seen already = not fresh", show(pend(w)))
	local _i = i
	local r = rookie(w, 4, { Level = 2 })
	local s = rookie(w, 5, { TotalKills = 1 })
	check(pend(w).New == 1 and pend(w).Players == 6, "Lv2 or a kill already = not fresh", show(pend(w)))
	local _ = q and r and s
end)

------------------------------------------------------------------ milestones and the 10-minute run
runGroup("milestones", function()
	local w = metricsWorld()
	local p, d = rookie(w, 1)
	at(p, 200)
	p:SetAttribute("Level", 4)
	check(pend(w).Min == nil or pend(w).Min.Lv5 == nil, "Lv4 is not Lv5", show(pend(w).Min))
	at(p, 250)
	p:SetAttribute("Level", 5)
	p:SetAttribute("Level", 6)
	local t = pend(w)
	check(min(t, "Lv5", 4) == 1 and min(t, "Lv5", 5) == 0, "Lv5 at 250 s = minute 4, once", show(t.Min))
	check(d.Telemetry.Test.M.Lv5 == 4, "the account remembers its Lv5 minute", show(d.Telemetry.Test))
	p:SetAttribute("WeaponOwnedMask", 1)
	check(min(pend(w), "Weapon", 4) == 1, "A23-188: the Forge's tier-1 gift is the first weapon (minute 4)", show(pend(w).Min))
	at(p, 400)
	p:SetAttribute("WeaponOwnedMask", 3)
	check(min(pend(w), "DropWeapon", 6) == 1, "GPT ④: the first dropped weapon (a T2 bit) at 400 s = DropWeapon minute 6", show(pend(w).Min))
	check(min(pend(w), "Weapon", 6) == 0 and min(pend(w), "Weapon", 4) == 1, "a later drop is not counted again", show(pend(w).Min))
	check((pend(w).Ten or 0) == 0, "no claim yet = no 10-minute run", show(pend(w)))
	at(p, 599)
	p:SetAttribute("TutorialStep", 3)
	check(pend(w).Min.Claim == nil, "a tutorial step before the claim is not the claim", show(pend(w).Min))
	p:SetAttribute("TutorialStep", 99)
	t = pend(w)
	check(min(t, "Claim", 9) == 1 and t.Ten == 1, "the claim at 599 s = minute 9 and the 10-minute run (Ten 1)", show(t))
	at(p, 4000)
	p:SetAttribute("Level", 10)
	check(min(pend(w), "Lv10", 60) == 1, "Lv10 after an hour = minute 60 (the cap)", show(pend(w).Min))
	-- a slower one
	local q = rookie(w, 2)
	at(q, 100)
	q:SetAttribute("Level", 5)
	q:SetAttribute("WeaponOwnedMask", 2)
	at(q, 600)
	q:SetAttribute("TutorialStep", 99)
	t = pend(w)
	check(t.Ten == 1 and min(t, "Claim", 10) == 1, "a claim at 600 s (minute 10) is not inside the 10-minute run", show(t))
	-- caught up at the join (a save that reached them on another server of this round)
	local r = rookie(w, 3)
	local rd = w.Data[r]
	at(r, 300)
	rd.Level, rd.WeaponOwnedMask, rd.TutorialStep = 5, 3, 99
	r, rd = rejoin(w, r, rd)
	t = pend(w)
	check(t.Ten == 2 and min(t, "Lv5", 5) == 0, "a rejoin scans at once: what the save already shows is counted", show(t))
	check(t.Players == 3 and t.New == 3 and t.Joins == 4, "a rejoin is a join, not a new player", show(t))
	local _ = rd
end)

------------------------------------------------------------------ Codex B6: XP by source up to Lv5 / Lv10
runGroup("xp sources", function()
	local w = metricsWorld()
	local E = w.Reg.ProgressionService.XPEarned
	local p = rookie(w, 41)
	E:Fire(p, 100, "Monster")
	E:Fire(p, 60, nil)
	E:Fire(p, 0, "Monster")
	check(pend(w).XP == nil, "below Lv5: nothing added yet", show(pend(w).XP))
	p:SetAttribute("Level", 5)
	E:Fire(p, 40, "Monster") -- the grant that made Lv5 is counted before the level is looked at
	local x = pend(w).XP
	check(x and x.Lv5 and x.Lv5.Hunt == 140 and x.Lv5.Other == 60 and x.Lv5.N == 1, "Lv5: hunting 140, quests 60, one account", show(x))
	E:Fire(p, 10, "Monster")
	check(pend(w).XP.Lv5.N == 1 and pend(w).XP.Lv5.Hunt == 140, "Lv5 is counted once", show(pend(w).XP))
	E:Fire(p, 200, "Quest")
	p:SetAttribute("Level", 10)
	E:Fire(p, 1, "Monster")
	x = pend(w).XP
	check(x.Lv10 and x.Lv10.Hunt == 151 and x.Lv10.Other == 260 and x.Lv10.N == 1, "Lv10: everything up to it (151 / 260)", show(x))
	local v = veteran(w, 42)
	E:Fire(v, 500, "Monster")
	check(pend(w).XP.Lv5.N == 1 and pend(w).XP.Lv10.N == 1, "a save from before the test: never counted", show(pend(w).XP))
	E:Fire("nobody", 5, "Monster")
	check(true, "a bad player is ignored", "")
end)

------------------------------------------------------------------ passes
runGroup("passes", function()
	local w = metricsWorld()
	local p, d = rookie(w, 1)
	local Bought = w.Reg.MonetizationService.PassBought
	w.Owns[p] = { VIP = true, HaloIce = true }
	Bought:Fire(p, "VIP")
	Bought:Fire(p, "HaloIce")
	Bought:Fire(p, "XP2")
	Bought:Fire(p, "NoSuchPass")
	Bought:Fire(p, 5)
	local t = pend(w)
	check(t.Pass.VIP.Bought == 1 and t.Pass.HaloIce.Bought == 1 and t.Pass.XP2.Bought == 1 and t.Pass.NoSuchPass == nil,
		"bought: a game pass and a look count, an unknown key does not", show(t.Pass))
	w:Advance(60)
	check(t.Pass.VIP.Back == nil and pend(w).Pass.VIP.Back == nil, "the same join is not a rejoin", show(pend(w).Pass))
	p, d = rejoin(w, p, d)
	w.Owns[p] = { VIP = true, HaloIce = true } -- XP2 refunded / not seen by Roblox
	w:Advance(19)
	check(pend(w).Pass.VIP.Back == nil, "the rejoin check waits KeptDelay s (the join's ownership check runs first)", show(pend(w).Pass))
	w:Advance(2)
	t = pend(w)
	check(t.Pass.VIP.Back == 1 and t.Pass.VIP.Kept == 1 and t.Pass.HaloIce.Kept == 1, "rejoined: the pass still works = Back 1, Kept 1", show(t.Pass))
	check(t.Pass.XP2.Back == 1 and t.Pass.XP2.Kept == nil, "rejoined without the pass working = Back 1, Kept 0", show(t.Pass.XP2))
	p, d = rejoin(w, p, d)
	w.Owns[p] = { VIP = true }
	w:Advance(30)
	check(pend(w).Pass.VIP.Back == 1, "a third join does not count the same pass again", show(pend(w).Pass))
	-- bought again on a later join: the first purchase's join stays
	Bought:Fire(p, "VIP")
	check(pend(w).Pass.VIP.Bought == 2 and d.Telemetry.Test.P.VIP == 1, "a second purchase signal adds Bought; the record keeps the first join", show(d.Telemetry.Test))
	-- a purchase already recorded for the join number this join gets is not a rejoin
	local u = w:Arrive(3, { Data = { Telemetry = { Test = { R = "PT1", J = 1, N = false, M = {}, P = { VIP = 2 }, K = {} } } } })
	w.Owns[u] = { VIP = true }
	w:Advance(30)
	check(pend(w).Pass.VIP.Back == 1, "J 2 with the purchase at J 2 = no rejoin check", show(pend(w).Pass.VIP))
	-- PlayerReady twice for one join (two checks queued): counted once
	local x, xd = rookie(w, 4)
	Bought:Fire(x, "Stickers")
	x, xd = rejoin(w, x, xd)
	w.TM.OnJoin(x, xd)
	w.Owns[x] = { Stickers = true }
	w:Advance(30)
	check(pend(w).Pass.Stickers.Back == 1 and pend(w).Pass.Stickers.Kept == 1, "two queued checks of one pass count once", show(pend(w).Pass.Stickers))
	-- leaving before the check: nothing
	local q, qd = rookie(w, 2)
	Bought:Fire(q, "Gold2")
	q, qd = rejoin(w, q, qd)
	w:Leave(q)
	w:Advance(30)
	check(pend(w).Pass.Gold2.Back == nil, "left before the rejoin check = not counted", show(pend(w).Pass.Gold2))
	-- 최종 검수 10/13 review: Roblox has not answered by the check (only the saved answer exists): Unknown, never Kept
	local z, zd = rookie(w, 5)
	Bought:Fire(z, "Bubbles")
	z, zd = rejoin(w, z, zd)
	w:Advance(30)
	check(pend(w).Pass.Bubbles.Back == 1 and pend(w).Pass.Bubbles.Kept == nil and pend(w).Pass.Bubbles.Unknown == 1,
		"no answer from Roblox yet: Back 1, Unknown 1, not Kept", show(pend(w).Pass.Bubbles))
	check(pend(w).Pass.XP2.Unknown == nil, "Roblox's 'no' is not Unknown", show(pend(w).Pass.XP2))
end)

------------------------------------------------------------------ devices
runGroup("devices", function()
	local w = metricsWorld()
	local p = rookie(w, 1)
	local v = veteran(w, 2)
	local CM = w.Reg.TelemetryService.ClientMetric
	CM:Fire(p, "Perf", { D = "Phone", F = 40, W = 30, M = 900, Q = 3 })
	CM:Fire(p, "Perf", { D = "Desktop" })
	CM:Fire(v, "Perf", { D = "Desktop" })
	CM:Fire(p, "ShopOpen", nil)
	local q = rookie(w, 3)
	CM:Fire(q, "Perf", { D = "Toaster" })
	CM:Fire(q, "Perf", "Phone")
	local t = pend(w)
	check(t.Device and t.Device.Phone == 1 and t.Device.Desktop == nil and t.Device.Toaster == nil,
		"a new account's first Perf device only (a veteran, a second sample, an unknown device, a bad arg: nothing)", show(t.Device))
end)

------------------------------------------------------------------ rounds
runGroup("rounds", function()
	local w = metricsWorld()
	local p, d = rookie(w, 1)
	d.Telemetry.Test.R = "PT0"
	d.Telemetry.Test.J = 5
	d.IntroSeen, d.Level = true, 6 -- played the older round
	p, d = rejoin(w, p, d)
	local t = pend(w)
	check(t.Players == 2 and d.Telemetry.Test.R == "PT1" and d.Telemetry.Test.J == 1,
		"an older round's record starts over (counted as a player of this round)", show({ t, d.Telemetry.Test }))
	check(t.New == 1 and d.Telemetry.Test.N == false, "an account that played the older round is not new in this one (its save decides)", show(t))
end)

------------------------------------------------------------------ the document
runGroup("document", function()
	local w = metricsWorld()
	local p = rookie(w, 1)
	p:SetAttribute("IntroSeen", true)
	check(w.TM.Flush() == true, "a flush works", show(w.DSCalls))
	local doc = w:Doc()
	check(doc and doc.Players == 1 and doc.New == 1 and doc.Intro == 1 and doc.V == 1, "the round's document in the _STUDIO copy", show(doc))
	check(next(pend(w)) == nil or pend(w).Players == nil, "the saved sums leave the memory", show(pend(w)))
	check(w.TM.Flush() == true and #w.DSCalls == 1, "nothing new = no write", show(w.DSCalls))
	rookie(w, 2)
	w.Fail[STORE .. ":Update"] = 1
	check(w.TM.Flush() == false and pend(w).Players == 1 and #w.Warnings >= 1, "a failed write: false, a warning, the sums kept", show(pend(w)))
	w.Warnings = {} -- the expected warning
	rookie(w, 3)
	check(w.TM.Flush() == true and w:Doc().Players == 3 and w:Doc().New == 3, "the next flush writes both", show(w:Doc()))
	-- another server of the same game adds to the same document
	local w2 = metricsWorld({ Stores = w.Stores })
	rookie(w2, 9)
	w2.TM.Flush()
	check(w:Doc().Players == 4, "two servers add into one document (UpdateAsync merge)", show(w:Doc()))
	-- the close
	rookie(w, 4)
	for _, fn in w.BoundToClose do fn() end
	check(w:Doc().Players == 5, "the close flushes", show(w:Doc()))
	-- the loop
	rookie(w, 5)
	w:Tick(90)
	check(w:Doc().Players == 6, "the flush loop writes", show(w:Doc()))
	-- the merge
	local m = w.TM.Merge({ Players = 2, Min = { Lv5 = { ["3"] = 1 } }, Bad = "x" }, { Players = 1, Min = { Lv5 = { ["3"] = 2, ["4"] = 1 } } })
	check(m.Players == 3 and m.Min.Lv5["3"] == 3 and m.Min.Lv5["4"] == 1 and m.Bad == nil and m.V == 1,
		"merge: numbers added (nested), other values dropped, V = 1", show(m))
	-- a live server writes the real name
	local w3 = metricsWorld({ Studio = false })
	rookie(w3, 1)
	w3.TM.Flush()
	local live = w3.Config.StoreName("HaloHorns_TestMetrics_v1")
	check(w3:Doc(live) and w3:Doc(live).Players == 1 and w3.Stores[STORE] == nil, "a published server writes Config.StoreName(Store) (no _STUDIO)", show(w3.Stores))
end)

------------------------------------------------------------------ off
runGroup("off", function()
	local w = metricsWorld({ EditConfig = function(C) C.TestMetrics.Enabled = false end })
	local p = rookie(w, 1)
	p:SetAttribute("IntroSeen", true)
	check(pend(w).Players == nil and pend(w).Intro == nil and #w.BoundToClose == 0 and #w.Loops == 0, "Enabled = false: nothing counted, no loop, no close hook", show(pend(w)))
	-- 최종 검수 10/13 review: never on the Live game, even with Enabled = true
	local live = metricsWorld({ EditConfig = function(C) C.Env.Default = "Live" end })
	local q = rookie(live, 1)
	q:SetAttribute("IntroSeen", true)
	check(pend(live).Players == nil and #live.BoundToClose == 0 and #live.Loops == 0 and q ~= nil, "the Live game: nothing counted, no loop", show(pend(live)))
end)

finish()
