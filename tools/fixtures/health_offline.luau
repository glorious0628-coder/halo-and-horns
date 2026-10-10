-- health_offline.luau : the hourly health report (HealthService, 게임성 개발 3, 2026-10-09; contract
-- docs/design/health_report_server_2026-10-09.md). tools/test_health.py binds CONFIG_SOURCE, UTIL_SOURCE, HEALTH_SOURCE and
-- PROGRESSION_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows. HealthService runs from source on the dev3_world
-- doubles (ProgressionService / GooseService / GrudgeService / MonetizationService / TelemetryService are signal doubles; the REAL
-- ProgressionService is loaded in one group to prove AddXP fires XPEarned). Its two loops are stepped by hand.

local NOON = 1789959600 -- 2026-09-21 03:00 UTC
local KEY = "H2026092103"
local KEY_NEXT = "H2026092104"
local STORE = "HaloHorns_Health_v1_STUDIO"

local function healthWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	local Signal = w.Util.Signal
	w.Reg.ProgressionService.XPEarned = Signal.new()
	w.Reg.GooseService.GooseRewarded = Signal.new()
	if not o.NoTelemetry then w.Reg.TelemetryService = { ClientMetric = Signal.new() } end
	w.Reg.MonetizationService.PassBought = Signal.new()
	w:Service("HealthService", HEALTH_SOURCE)
	w:InitStart({ "HealthService" })
	w.Health = w.Reg.HealthService
	function w:Minute()
		self:Advance(60)
		local ok, waited = coroutine.resume(self.Loops[1])
		assert(ok, waited)
		return waited
	end
	function w:Doc(key, store)
		local s = self.Stores[store or STORE]
		return s and s.Rows[key] or nil
	end
	function w:Gets()
		local n = 0
		for _, c in self.DSCalls do if c.Op == "Get" then n += 1 end end
		return n
	end
	function w:Updates()
		local n = 0
		for _, c in self.DSCalls do if c.Op == "Update" then n += 1 end end
		return n
	end
	return w
end

local function hero(w, id, level)
	return w:Arrive(id, { Data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = level or 3 } })
end

local function pending(w)
	local rows = w.Health.Pending()
	return rows[1] and rows[1].Doc or {}
end

local function keyCount(t)
	local n = 0
	for _ in t or {} do n += 1 end
	return n
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local H = C.Health
	check(H.Enabled == true and H.Store == "HaloHorns_Health_v1" and H.FlushSeconds == 600 and H.ReadHours == 24 and H.MaxReadHours == 72
		and H.MaxKeys == 40, "config: on, HaloHorns_Health_v1, flush 600 s, read 24 h (max 72), 40 keys", show(H))
	local names = {}
	for _, b in H.Bands do table.insert(names, b.Name .. "<=" .. b.Max) end
	check(table.concat(names, ",") == "1-9<=9,10-24<=24,25-49<=49,50+<=1000", "the four level bands (the analytics cut)", table.concat(names, ","))
	local A = H.Alerts
	check(A.MinPlayerMinutes == 60 and A.SurgeRatio == 2 and A.MinBaseline == 3 and A.GooseMinRounds == 10 and A.GooseSkew == 0.75
		and A.QuietHours == 3, "alert starter numbers: 60 player-min, 2x, 3 baseline hours, goose 10 rounds / 75%, quiet 3 h", show(A))
end)

------------------------------------------------------------------ recorders
runGroup("recorders", function()
	local w = healthWorld()
	local R = w.Reg
	local p, q, r, s = hero(w, 1, 3), hero(w, 2, 12), hero(w, 3, 30), hero(w, 4, 60)
	local d = pending(w)
	check(d.Joins == 4, "four players joined = Joins 4", tostring(d.Joins))
	-- gold in / out
	R.ProgressionService.GoldEarned:Fire(p, 100, "Monster")
	R.ProgressionService.GoldEarned:Fire(q, 250.7, "Quest")
	R.ProgressionService.GoldEarned:Fire(p, 5, "Mon ster!")
	for _, bad in { { p, 0, "X" }, { p, -5, "X" }, { p, 10, 5 }, { p, 10, nil }, { p, "a", "X" }, { p, 0 / 0, "X" } } do
		R.ProgressionService.GoldEarned:Fire(bad[1], bad[2], bad[3])
	end
	R.ProgressionService.GoldSpent:Fire(p, 40, "Weapon")
	R.ProgressionService.GoldSpent:Fire(q, 0, "Potion")
	R.ProgressionService.GoldSpent:Fire(q, 10, 5)
	R.ProgressionService.GoldSpent:Fire(q, 10, nil)
	R.ProgressionService.GoldSpent:Fire(q, -10, "Potion")
	d = pending(w)
	check(d.GoldIn.Monster == 105 and d.GoldIn.Quest == 250 and keyCount(d.GoldIn) == 2,
		"gold in per source (whole gold, odd source names cleaned, zero / negative / non-string ignored)", show(d.GoldIn))
	check(d.GoldOut.Weapon == 40 and keyCount(d.GoldOut) == 1, "gold out per sink (a zero is nothing)", show(d.GoldOut))
	check(d.GoldBand["1-9"].In == 105 and d.GoldBand["1-9"].Out == 40 and d.GoldBand["10-24"].In == 250,
		"gold in / out per level band of the player", show(d.GoldBand))
	-- XP
	R.ProgressionService.XPEarned:Fire(q, 30)
	R.ProgressionService.XPEarned:Fire(r, 12.9)
	R.ProgressionService.XPEarned:Fire(p, 0)
	R.ProgressionService.XPEarned:Fire(p, -3)
	d = pending(w)
	check(d.XP["10-24"] == 30 and d.XP["25-49"] == 12 and keyCount(d.XP) == 2, "XP per level band (whole XP, zero / negative ignored)", show(d.XP))
	-- the minute
	w:Minute()
	d = pending(w)
	check(d.Min["1-9"] == 1 and d.Min["10-24"] == 1 and d.Min["25-49"] == 1 and d.Min["50+"] == 1 and d.Peak == 4,
		"a minute: one player-minute per player in its band, Peak = 4", show({ d.Min, d.Peak }))
	w:Leave(s)
	w:Minute()
	d = pending(w)
	check(d.Min["1-9"] == 2 and d.Min["50+"] == 1 and d.Peak == 4, "a player left: 3 counted, Peak stays the larger", show({ d.Min, d.Peak }))
	-- the goose
	local G = R.GooseService.GooseFinished
	G:Fire("Halo", {}, { Mode = "Versus" })
	G:Fire("Horns", {}, { Mode = "Versus" })
	G:Fire("Tie", {}, { Mode = "Versus" })
	G:Fire("Halo", {}, { Mode = "Coop", Success = true, Side = "Halo" })
	G:Fire("Horns", {}, { Mode = "Coop", Success = false, Side = "Horns" })
	G:Fire("Tie", {}, { Mode = "Pending" })
	G:Fire("Horns", {})
	d = pending(w)
	local g = d.Goose
	check(g.Rounds == 7 and g.Versus == 4 and g.HaloWins == 1 and g.HornsWins == 2 and g.Ties == 1 and g.Coop == 2 and g.CoopWins == 1
		and g.Empty == 1, "goose rounds: versus by winner, co-op with its wins, nobody eligible, no info = versus", show(g))
	local GR = R.GooseService.GooseRewarded
	GR:Fire(p, { Won = true, Rare = false, Gold = 100, XP = 200, Level = 3, Mode = "Versus" })
	GR:Fire(q, { Won = false, Rare = true, Gold = 40, XP = 80, Level = 12, Mode = "Versus" })
	GR:Fire(q, { Won = false, Rare = false, Gold = 60.9, XP = 20, Level = 12, Mode = "Coop" })
	GR:Fire(p, nil)
	GR:Fire(p, 5)
	d = pending(w)
	g = d.Goose
	check(g.Paid == 3 and g.Won == 1 and g.Lost == 2 and g.Rare == 1 and g.Gold == 200 and g.XP == 300,
		"goose pay: paid / won / not won / rare, gold and XP sums (bad payloads ignored)", show(g))
	check(d.GooseBand["1-9"].N == 1 and d.GooseBand["1-9"].Gold == 100 and d.GooseBand["1-9"].XP == 200
		and d.GooseBand["10-24"].N == 2 and d.GooseBand["10-24"].Gold == 100 and d.GooseBand["10-24"].XP == 100,
		"goose pay per level band of the payee's level", show(d.GooseBand))
	-- plunder
	local SR = R.GrudgeService.SackResolved
	SR:Fire(p, "Paid", 500)
	SR:Fire(p, "Paid", 300)
	SR:Fire(p, "Avenged", 700.5)
	SR:Fire(p, "Returned", 100)
	SR:Fire(p, "Nope", 5)
	SR:Fire(p, 5, 5)
	d = pending(w)
	local pl = d.Plunder
	check(pl.PaidN == 2 and pl.PaidG == 800 and pl.AvengedN == 1 and pl.AvengedG == 700 and pl.ReturnedN == 1 and pl.ReturnedG == 100
		and keyCount(pl) == 6, "plunder sacks: count and gold per outcome (unknown outcomes ignored)", show(pl))
	-- passes
	local CM = R.TelemetryService.ClientMetric
	CM:Fire(p, "PassView", "XP2")
	CM:Fire(p, "PassView", "XP2")
	CM:Fire(p, "PurchasePrompt", "XP2")
	CM:Fire(p, "PassView", "VIP")
	CM:Fire(p, "InviteSent", 2)
	CM:Fire(p, "PassView", 5)
	CM:Fire(p, "ShopOpen")
	CM:Fire(p, "PassView", "Look")
	CM:Fire(p, "PassView", "HaloIce") -- a look id is the same funnel row as "Look" (and the same once-an-hour slot)
	CM:Fire(p, "PurchasePrompt", "HornsLava")
	R.MonetizationService.PassBought:Fire(p, "XP2")
	R.MonetizationService.PassBought:Fire(p, "HaloIce") -- the buy is a look id: it is the "Look" row too
	R.MonetizationService.PassBought:Fire(p, nil)
	w.Health.OnPass("Nope", "XP2")
	w.Health.OnPass("Bought", 5)
	d = pending(w)
	check(d.Pass.XP2.View == 1 and d.Pass.XP2.Prompt == 1 and d.Pass.XP2.Bought == 1 and d.Pass.VIP.View == 1 and d.Pass.VIP.Prompt == nil
		and keyCount(d.Pass) == 3 and keyCount(d.Pass.XP2) == 3, "pass funnel: view -> prompt -> bought per pass (other metrics and bad ids ignored; a repeated metric counts once)", show(d.Pass))
	check(d.Pass.Look.View == 1 and d.Pass.Look.Prompt == 1 and d.Pass.Look.Bought == 1 and d.Pass.HaloIce == nil and d.Pass.HornsLava == nil,
		"looks: a look id (bought or reported) is the one 'Look' row of the funnel", show(d.Pass))
	-- a sums table never grows past MaxKeys (+ "Other")
	local before = 0
	for i = 1, 45 do R.ProgressionService.GoldEarned:Fire(p, 1, "S" .. i) end
	d = pending(w)
	for _, v in d.GoldIn do before += v end
	check(keyCount(d.GoldIn) == 41 and d.GoldIn.Other == 7 and before == 105 + 250 + 45,
		"45 new sources: at most 40 keys + Other, nothing lost", show({ keyCount(d.GoldIn), d.GoldIn.Other, before }))
	check(d.V == 1, "a document carries its version", tostring(d.V))
end)

runGroup("level bands and key cleaning", function()
	local w = healthWorld()
	local R = w.Reg
	local cases = { { 1, "1-9" }, { 9, "1-9" }, { 10, "10-24" }, { 24, "10-24" }, { 25, "25-49" }, { 49, "25-49" }, { 50, "50+" },
		{ 100, "50+" }, { 1000, "50+" }, { 5000, "50+" }, { 0, "1-9" }, { 9.9, "1-9" }, { 24.5, "10-24" } }
	local expect = {}
	for i, c in cases do
		local p = hero(w, i, c[1])
		R.ProgressionService.XPEarned:Fire(p, 1)
		expect[c[2]] = (expect[c[2]] or 0) + 1
	end
	local d = pending(w)
	check(show(d.XP) == show(expect), "XP bands at the edges: 9 | 10, 24 | 25, 49 | 50, 1000 and above, Lv 0, fractions floor", show({ d.XP, expect }))
	local q = hero(w, 99, 5)
	R.ProgressionService.GoldEarned:Fire(q, 1, string.rep("A", 40))
	R.ProgressionService.GoldEarned:Fire(q, 1, "!!!")
	R.ProgressionService.GoldEarned:Fire(q, 1, "")
	d = pending(w)
	check(d.GoldIn[string.rep("A", 24)] == 1 and d.GoldIn.Other == 2 and keyCount(d.GoldIn) == 2,
		"a source name is cut to 24 letters; nothing left after cleaning = Other", show(d.GoldIn))
	-- passes are capped like the sums tables
	for i = 1, 45 do R.TelemetryService.ClientMetric:Fire(q, "PassView", "P" .. i) end
	d = pending(w)
	local views = 0
	for _, row in d.Pass do views += row.View or 0 end
	check(keyCount(d.Pass) == 41 and d.Pass.Other.View == 5 and views == 45, "45 pass ids: 40 + Other, no view lost", show({ keyCount(d.Pass), views }))
	-- an unreadable Level is band 1-9
	local z = hero(w, 98, 3)
	z:SetAttribute("Level", nil)
	R.ProgressionService.XPEarned:Fire(z, 7)
	check(pending(w).XP["1-9"] == expect["1-9"] + 7, "a player with no Level attribute counts as level 1", show(pending(w).XP))
end)

runGroup("a pass metric counts once an hour per person", function()
	local w = healthWorld()
	local CM = w.Reg.TelemetryService.ClientMetric
	local p, q = hero(w, 10, 3), hero(w, 11, 3)
	local function total(id, kind)
		local n = 0
		for _, row in w.Health.Pending() do
			local r = row.Doc.Pass and row.Doc.Pass[id]
			n += r and r[kind] or 0
		end
		return n
	end
	for _ = 1, 50 do CM:Fire(p, "PassView", "XP2") end
	check(total("XP2", "View") == 1, "one person calling PassView 50 times: one view", tostring(total("XP2", "View")))
	CM:Fire(q, "PassView", "XP2")
	check(total("XP2", "View") == 2, "another person counts as well", tostring(total("XP2", "View")))
	for _ = 1, 20 do CM:Fire(p, "PurchasePrompt", "XP2") end
	CM:Fire(p, "PassView", "VIP")
	check(total("XP2", "Prompt") == 1 and total("VIP", "View") == 1 and total("XP2", "View") == 2,
		"a prompt and another pass are their own once-an-hour slots", show({ total("XP2", "Prompt"), total("VIP", "View"), total("XP2", "View") }))
	CM:Fire(nil, "PassView", "XP2")
	CM:Fire("someone", "PassView", "XP2")
	check(total("XP2", "View") == 2, "a call with no player is not counted", tostring(total("XP2", "View")))
	w:Advance(3599)
	CM:Fire(p, "PassView", "XP2")
	check(total("XP2", "View") == 2, "3599 s later: the same slot, not counted", tostring(total("XP2", "View")))
	w:Advance(1)
	CM:Fire(p, "PassView", "XP2")
	CM:Fire(p, "PassView", "XP2")
	check(total("XP2", "View") == 3, "an hour after the counted one: counted again, once", tostring(total("XP2", "View")))
	CM:Fire(q, "PassView", "XP2")
	check(total("XP2", "View") == 4, "each person has their own clock", tostring(total("XP2", "View")))
	-- the bought count is not a client metric: never limited
	for _ = 1, 3 do w.Reg.MonetizationService.PassBought:Fire(p, "XP2") end
	check(total("XP2", "Bought") == 3, "purchases are counted every time", tostring(total("XP2", "Bought")))
end)

runGroup("nothing leaks: no names, no ids", function()
	local w = healthWorld()
	local p = hero(w, 77, 3)
	p.Name, p.DisplayName = "CoolKid42", "Cool Kid"
	w.Reg.ProgressionService.GoldEarned:Fire(p, 10, "Monster")
	w.Reg.GooseService.GooseRewarded:Fire(p, { Won = true, Rare = false, Gold = 5, XP = 5, Level = 3 })
	w.Reg.GrudgeService.SackResolved:Fire(p, "Paid", 10)
	w.Health.Flush()
	local text = show(w:Doc(KEY))
	check(not string.find(text, "CoolKid", 1, true) and not string.find(text, "Cool Kid", 1, true) and not string.find(text, "77", 1, true),
		"the saved document holds no name and no user id", text)
end)

------------------------------------------------------------------ merge
runGroup("merge", function()
	local w = healthWorld()
	local H = w.Health
	local empty = H.Merge(nil, nil)
	check(keyCount(empty) == 1 and empty.V == 1, "nothing + nothing = just the version", show(empty))
	local m = H.Merge({ Joins = 3, Peak = 5, GoldIn = { Monster = 10 }, V = 1 }, { Joins = 2, Peak = 9, GoldIn = { Monster = 5, Quest = 7 } })
	check(m.Joins == 5 and m.Peak == 9 and m.GoldIn.Monster == 15 and m.GoldIn.Quest == 7 and m.V == 1,
		"numbers are added, Peak takes the larger one, the version stays 1", show(m))
	m = H.Merge({ Peak = 12 }, { Peak = 9 })
	check(m.Peak == 12, "Peak: the older larger value stays", show(m))
	local a = { Joins = 1 }
	local b = { Joins = 2 }
	H.Merge(a, b)
	check(a.Joins == 1 and b.Joins == 2, "the inputs are not changed", "")
	-- a broken document is repaired, never trusted
	m = H.Merge({ ["a b!"] = 1, [5] = 2, Bad = 0 / 0, Huge = 1e13, Neg = -1e13, Inf = math.huge, Str = "x", Ok = 3 }, nil)
	check(m.ab == 1 and m.Ok == 3 and m.Bad == nil and m.Huge == nil and m.Neg == nil and m.Inf == nil and m.Str == nil and m[5] == nil and m["5"] == nil,
		"keys cleaned, NaN / infinite / over 1e12 / text / non-string keys dropped", show(m))
	m = H.Merge({ A = { B = { C = { D = 1 } } } }, nil)
	check(m.A ~= nil and m.A.B ~= nil and m.A.B.C == nil, "three levels deep at most", show(m))
	local big = {}
	for i = 1, 60 do big["K" .. i] = i end
	m = H.Merge({ Table = big }, nil)
	check(keyCount(m.Table) <= 41 and m.Table.Other ~= nil, "a sums table of a document holds at most 40 keys + Other", tostring(keyCount(m.Table)))
	check(H.Merge({ Joins = "5" }, { Joins = true }).Joins == nil, "non-number values are not sums", "")
	-- the 40-key cap does not count Other: 39 keys + Other + a new key = the new key stays
	local near = { Other = 1 }
	for i = 1, 39 do near["K" .. i] = i end
	m = H.Merge({ Table = near }, { Table = { Knew = 5 } })
	check(m.Table.Knew == 5 and m.Table.Other == 1 and keyCount(m.Table) == 41, "39 keys + Other: the 40th key still fits", show({ keyCount(m.Table), m.Table.Knew, m.Table.Other }))
	near.K40 = 40
	m = H.Merge({ Table = near }, { Table = { Knew = 5 } })
	check(m.Table.Knew == nil and m.Table.Other == 6 and keyCount(m.Table) == 41, "40 keys + Other: the 41st goes to Other", show({ keyCount(m.Table), m.Table.Knew, m.Table.Other }))
end)

------------------------------------------------------------------ the document
runGroup("flush", function()
	local w = healthWorld()
	local H = w.Health
	local p = hero(w, 1, 3)
	w.Reg.ProgressionService.GoldEarned:Fire(p, 100, "Monster")
	w:Minute()
	check(w:Updates() == 0 and w.Stores[STORE] == nil, "nothing is written before the flush (sums stay in memory)", "")
	check(H.Flush() == true, "a flush succeeds", "")
	local doc = w:Doc(KEY)
	check(doc and doc.V == 1 and doc.Servers == 1 and doc.Joins == 1 and doc.GoldIn.Monster == 100 and doc.Min["1-9"] == 1 and doc.Peak == 1,
		"ONE document for the UTC hour, key H<YYYYMMDDHH> in the Studio copy: sums and this server counted once", show(doc))
	check(#H.Pending() == 0, "after a flush nothing is pending", #H.Pending())
	local calls = w:Updates()
	check(H.Flush() == true and w:Updates() == calls, "a flush with nothing new writes nothing", w:Updates() - calls)
	-- more sums, the same hour: added, Servers stays 1
	w.Reg.ProgressionService.GoldEarned:Fire(p, 50, "Monster")
	w.Reg.ProgressionService.GoldSpent:Fire(p, 20, "Potion")
	H.Flush()
	doc = w:Doc(KEY)
	check(doc.GoldIn.Monster == 150 and doc.GoldOut.Potion == 20 and doc.Servers == 1 and doc.Joins == 1,
		"a second flush adds to the same document; this server is still counted once", show(doc))
	-- the next hour is another document
	w:Advance(3600)
	w.Reg.ProgressionService.GoldEarned:Fire(p, 7, "Quest")
	H.Flush()
	check(w:Doc(KEY_NEXT) and w:Doc(KEY_NEXT).GoldIn.Quest == 7 and w:Doc(KEY_NEXT).Servers == 1 and w:Doc(KEY).GoldIn.Quest == nil,
		"a new UTC hour is a new document (this server counted in it too); the old hour is not touched", show(w:Doc(KEY_NEXT)))
	local rows = H.ReadRows("stored", 3)
	check(#rows == 2 and rows[1].T == NOON and rows[2].T == NOON + 3600, "ReadRows: oldest hour first", show({ #rows, rows[1] and rows[1].T, rows[2] and rows[2].T }))
	rows = H.ReadRows("stored", 1)
	check(#rows == 1 and rows[1].T == NOON + 3600, "ReadRows(1) is the current hour", show({ #rows, rows[1] and rows[1].T }))
end)

runGroup("flush: other servers, failures, events during a write", function()
	-- another server wrote this hour first
	local w = healthWorld()
	local H = w.Health
	local p = hero(w, 1, 3)
	w.StoreOf(STORE, "Standard")
	w.Stores[STORE].Rows[KEY] = { V = 1, Servers = 2, Peak = 9, Joins = 5, GoldIn = { Monster = 1000 } }
	w.Reg.ProgressionService.GoldEarned:Fire(p, 100, "Monster")
	w:Minute()
	H.Flush()
	local doc = w:Doc(KEY)
	check(doc.Servers == 3 and doc.Peak == 9 and doc.Joins == 6 and doc.GoldIn.Monster == 1100,
		"merged with another server's sums (Servers 2 + 1, Peak the larger, the rest added)", show(doc))
	-- a failed write: the sums wait for the next flush and are not doubled
	local w2 = healthWorld()
	local p2 = hero(w2, 1, 3)
	w2.Reg.ProgressionService.GoldEarned:Fire(p2, 100, "Monster")
	w2.Fail[STORE .. ":Update"] = 1
	check(w2.Health.Flush() == false and #w2.Warnings >= 1 and w2:Doc(KEY) == nil, "a failed write: false, a warning, nothing saved", tostring(#w2.Warnings))
	w2.Warnings = {} -- the expected warning
	w2.Reg.ProgressionService.GoldEarned:Fire(p2, 5, "Monster")
	check(pending(w2).GoldIn.Monster == 105, "the failed sums are still pending (plus what came since)", show(pending(w2).GoldIn))
	check(w2.Health.Flush() == true, "the next flush succeeds", "")
	doc = w2:Doc(KEY)
	check(doc.GoldIn.Monster == 105 and doc.Servers == 1 and doc.Joins == 1, "saved exactly once: 105 gold, this server counted once", show(doc))
	w2.Fail[STORE .. ":Update"] = 2
	w2.Reg.ProgressionService.GoldEarned:Fire(p2, 1, "Monster")
	w2.Health.Flush()
	w2.Health.Flush()
	w2.Health.Flush()
	w2.Warnings = {}
	check(w2:Doc(KEY).GoldIn.Monster == 106 and w2:Doc(KEY).Servers == 1, "two failures in a row, then it lands once", show(w2:Doc(KEY)))
	-- events that happen while a write waits belong to the next flush
	local w3 = healthWorld()
	local p3 = hero(w3, 1, 3)
	w3.Reg.ProgressionService.GoldEarned:Fire(p3, 10, "Monster")
	w3.BeforeUpdate = function()
		w3.BeforeUpdate = nil
		w3.Reg.ProgressionService.GoldEarned:Fire(p3, 3, "Monster")
	end
	w3.Health.Flush()
	check(w3:Doc(KEY).GoldIn.Monster == 10, "an event during the write is not in this document", show(w3:Doc(KEY).GoldIn))
	w3.Health.Flush()
	check(w3:Doc(KEY).GoldIn.Monster == 13, "... it goes in the next flush", show(w3:Doc(KEY).GoldIn))
	-- a failed write after an event during the failing write: nothing lost, nothing doubled
	local w4 = healthWorld()
	local p4 = hero(w4, 1, 3)
	w4.Reg.ProgressionService.GoldEarned:Fire(p4, 10, "Monster")
	w4.Fail[STORE .. ":Update"] = 1
	w4.Health.Flush()
	w4.Warnings = {}
	w4.Reg.ProgressionService.GoldEarned:Fire(p4, 1, "Monster")
	w4.Health.Flush()
	check(w4:Doc(KEY).GoldIn.Monster == 11, "fail, new event, flush: 11 gold in total", show(w4:Doc(KEY).GoldIn))
	-- an event that comes while the write is on its way and the write then fails: kept, once
	local w5 = healthWorld()
	local p5 = hero(w5, 1, 3)
	w5.Reg.ProgressionService.GoldEarned:Fire(p5, 10, "Monster")
	w5.BeforeUpdate = function()
		w5.BeforeUpdate = nil
		w5.Reg.ProgressionService.GoldEarned:Fire(p5, 3, "Monster")
		error("offline write failure")
	end
	check(w5.Health.Flush() == false and w5:Doc(KEY) == nil, "a write that fails while an event comes in", "")
	w5.Warnings = {}
	check(pending(w5).GoldIn.Monster == 13, "both the old sums and the new event are pending", show(pending(w5).GoldIn))
	w5.Health.Flush()
	check(w5:Doc(KEY).GoldIn.Monster == 13 and w5:Doc(KEY).Servers == 1, "saved once: 13 gold, this server counted once", show(w5:Doc(KEY)))
end)

runGroup("flush: store names", function()
	local w = healthWorld()
	hero(w, 1, 3)
	w.Health.Flush()
	check(w.Stores["HaloHorns_Health_v1_STUDIO"] ~= nil and w.Stores["HaloHorns_Health_v1"] == nil, "Studio writes its own _STUDIO copy only", "")
	local wb = healthWorld({ Studio = false })
	wb.Config.EnvName = function() return "Beta" end
	hero(wb, 1, 3)
	wb.Health.Flush()
	check(wb.Stores["HaloHorns_Health_v1_Beta"] ~= nil and wb.Stores["HaloHorns_Health_v1_Beta"].Rows[KEY] ~= nil,
		"a Beta place writes HaloHorns_Health_v1_Beta (Config.StoreName)", show(wb.Stores))
	local wl = healthWorld({ Studio = false })
	wl.Config.EnvName = function() return "Live" end
	hero(wl, 1, 3)
	wl.Health.Flush()
	check(wl.Stores["HaloHorns_Health_v1_Live"] ~= nil, "a Live place writes HaloHorns_Health_v1_Live", "")
	local wd = healthWorld({ Studio = false })
	hero(wd, 1, 3)
	wd.Health.Flush()
	check(wd.Stores["HaloHorns_Health_v1"] ~= nil, "the dev place keeps the plain name", "")
end)

------------------------------------------------------------------ the loops and the close
runGroup("start: loops, close, switch", function()
	local w = healthWorld()
	local p = hero(w, 1, 3)
	w.Reg.ProgressionService.GoldEarned:Fire(p, 9, "Monster")
	check(w:Updates() == 0, "no write yet", "")
	w:Advance(901) -- the flush loop waits 300..900 s (x0.5..1.5 of 600)
	local okLoop, nextWait = coroutine.resume(w.Loops[2])
	assert(okLoop, nextWait)
	check(nextWait >= 300 and nextWait <= 900, "the next flush wait is 0.5x..1.5x of 600 s (servers do not all write together)", tostring(nextWait))
	check(w:Minute() == 60, "the minute loop waits 60 s", "")
	local waits, spread = {}, true
	for _ = 1, 20 do
		local ok, waited = coroutine.resume(w.Loops[2])
		assert(ok, waited)
		if waited < 300 or waited > 900 then spread = false end
		waits[waited] = true
	end
	check(spread and keyCount(waits) >= 2, "20 more waits: all 300..900 s and not all the same", tostring(keyCount(waits)))
	check(w:Doc(KEY) ~= nil and w:Doc(KEY).GoldIn.Monster == 9, "the flush loop writes after its random wait", show(w:Doc(KEY)))
	w.Reg.ProgressionService.GoldEarned:Fire(p, 1, "Monster")
	for _, fn in w.BoundToClose do fn() end
	check(w:Doc(KEY).GoldIn.Monster == 10, "when the server closes, the rest is saved", show(w:Doc(KEY)))
	-- disabled by the config
	local off = healthWorld({ EditConfig = function(c) c.Health.Enabled = false end })
	local po = hero(off, 1, 3)
	off.Reg.ProgressionService.GoldEarned:Fire(po, 9, "Monster")
	check(#off.Health.Pending() == 0 and #off.BoundToClose == 0, "Config.Health.Enabled = false: nothing is recorded, nothing is bound", "")
	-- a service that is missing costs nothing
	local nt = healthWorld({ NoTelemetry = true })
	local pn = hero(nt, 1, 3)
	nt.Reg.ProgressionService.GoldEarned:Fire(pn, 9, "Monster")
	check(pending(nt).GoldIn.Monster == 9 and #nt.Warnings == 0, "no TelemetryService in the registry: everything else still works", "")
end)

------------------------------------------------------------------ the report
runGroup("report (end to end)", function()
	local w = healthWorld()
	local p, q = hero(w, 1, 3), hero(w, 2, 12)
	local R = w.Reg
	R.ProgressionService.GoldEarned:Fire(p, 600, "Monster")
	R.ProgressionService.GoldEarned:Fire(q, 400, "Quest")
	R.ProgressionService.GoldSpent:Fire(p, 300, "Weapon")
	R.ProgressionService.XPEarned:Fire(p, 1200)
	R.ProgressionService.XPEarned:Fire(q, 4000)
	for _ = 1, 30 do w:Minute() end
	for _ = 1, 3 do R.GooseService.GooseFinished:Fire("Halo", {}, { Mode = "Versus" }) end
	R.GooseService.GooseFinished:Fire("Horns", {}, { Mode = "Versus" })
	R.GooseService.GooseRewarded:Fire(p, { Won = true, Gold = 120, XP = 300, Level = 3, Rare = false })
	R.GooseService.GooseRewarded:Fire(q, { Won = false, Gold = 60, XP = 100, Level = 12, Rare = true })
	R.GrudgeService.SackResolved:Fire(p, "Paid", 500)
	R.GrudgeService.SackResolved:Fire(p, "Paid", 300)
	R.GrudgeService.SackResolved:Fire(p, "Avenged", 700)
	R.TelemetryService.ClientMetric:Fire(p, "PassView", "XP2")
	R.TelemetryService.ClientMetric:Fire(p, "PurchasePrompt", "XP2")
	R.MonetizationService.PassBought:Fire(p, "XP2")
	w.Health.Flush()
	local rows = w.Health.ReadRows("stored", 3)
	check(#rows == 1 and rows[1].T == NOON and rows[1].Doc.Joins == 2, "ReadRows reads the last hours, oldest first, skipping hours with no document", show(rows))
	local text = w.Health.Text(rows, NOON + 1800, "stored")
	local function has(part) return string.find(text, part, 1, true) ~= nil end
	check(has("Health (stored): 1 hours with data (09-21 12:00 .. 09-21 12:00 KST), 1 server-hours, 2 joins, up to 2 ready on one server"),
		"header: hours, server-hours, joins, the most ready on one server (Korea time)", text)
	check(has("Player-hours: 1-9 0.5 | 10-24 0.5"), "player-hours per band (30 minutes each)", text)
	check(has("XP per player-hour: 1-9 2.4K | 10-24 8K"), "XP per player-hour per band", text)
	check(has("Gold in 1K (Monster 600, Quest 400) / out 300 (Weapon 300) / net +700"), "gold in / out with the biggest sources and the net", text)
	check(has("Gold in per player-hour: 1-9 1.2K | 10-24 800"), "gold in per player-hour per band", text)
	check(has("Goose: 4 rounds (versus 4: Halo 3, Horns 1, ties 0; coop 0, won 0; nobody paid 0); paid 2: won 1, not won 1, rare 1; per paid player 90 gold, 200 XP"),
		"goose line: rounds, winners, pay, the average pay per paid player", text)
	check(has("Goose pay per player by level band: 1-9 1 paid, 120 gold, 300 XP | 10-24 1 paid, 60 gold, 100 XP"), "goose pay per level band", text)
	check(has("Plunder sacks: kept 2 (avg 400 gold), avenged 1 (avg 700 gold), returned 0 (avg - gold)"), "plunder amounts per outcome", text)
	check(has("Passes: XP2 view 1 / prompt 1 / bought 1"), "pass funnel", text)
	check(has("Alerts: none"), "no alert for a quiet hour", text)
	local none = w.Health.Text({}, NOON, "live")
	check(none == "Health (live): no data in this window", "no rows: a plain line", none)
end)

runGroup("alerts", function()
	local w = healthWorld()
	local H = w.Health
	local function row(i, xp, goldIn, minutes, goose)
		return { T = NOON + i * 3600, Doc = { V = 1, Servers = 1, Min = { ["10-24"] = minutes }, XP = { ["10-24"] = xp },
			GoldBand = { ["10-24"] = { In = goldIn } }, Goose = goose } }
	end
	local function rowsOf(list) -- list of { xp, goldIn, minutes, goose }
		local out = {}
		for i, v in list do table.insert(out, row(i, v[1], v[2], v[3], v[4])) end
		return out
	end
	local now = NOON + 20 * 3600
	local base = { { 1000, 2000, 120 }, { 1000, 2000, 120 }, { 1000, 2000, 120 }, { 1000, 2000, 120 } }
	-- 3x XP in the newest full hour: a surge
	local list = {}
	for _, v in base do table.insert(list, v) end
	table.insert(list, { 3000, 2000, 120 })
	local alerts = H.Alerts(rowsOf(list), NOON + 5 * 3600 + 3600 + 600)
	check(#alerts == 1 and string.find(alerts[1], "SURGE: XP per player-hour in 10-24 is 3.0x the earlier hours (1.5K vs 500)", 1, true),
		"3x XP per player-hour: one SURGE line (the quiet check is not triggered)", show(alerts))
	-- the same for gold in
	list[5] = { 1000, 6000, 120 }
	alerts = H.Alerts(rowsOf(list), NOON + 6 * 3600 + 600)
	check(#alerts == 1 and string.find(alerts[1], "SURGE: Gold in per player-hour in 10-24 is 3.0x", 1, true), "3x gold in: a SURGE line for gold", show(alerts))
	-- exactly 2x flags, just under does not
	list[5] = { 2000, 2000, 120 }
	check(#H.Alerts(rowsOf(list), NOON + 6 * 3600 + 600) == 1, "exactly 2.0x flags (>= SurgeRatio)", "")
	list[5] = { 1990, 2000, 120 }
	check(#H.Alerts(rowsOf(list), NOON + 6 * 3600 + 600) == 0, "1.99x does not", "")
	-- fewer than 3 baseline hours: no judgement
	local short = { { 1000, 2000, 120 }, { 1000, 2000, 120 }, { 9000, 2000, 120 } }
	check(#H.Alerts(rowsOf(short), NOON + 4 * 3600 + 600) == 0, "only 2 baseline hours: no alert (not enough to compare)", "")
	-- an hour with too few player-minutes is skipped: the earlier full hour is the newest that counts
	list[5] = { 9000, 2000, 120 }
	table.insert(list, { 99999, 99999, 30 })
	check(#H.Alerts(rowsOf(list), NOON + 7 * 3600 + 600) == 1, "the newest hour has 30 player-minutes: skipped, the one before is judged", "")
	-- the hour that has not ended yet is never judged
	check(#H.Alerts(rowsOf(list), NOON + 5 * 3600 + 600) == 0, "an hour still running is not judged", "")
	-- hours with too few minutes are not part of the baseline
	local thin = { { 5000, 5000, 20 }, { 5000, 5000, 20 }, { 5000, 5000, 20 }, { 1000, 2000, 120 }, { 3000, 2000, 120 } }
	check(#H.Alerts(rowsOf(thin), NOON + 6 * 3600 + 600) == 0, "thin hours are not a baseline (only 1 qualifying earlier hour)", "")
	-- quiet
	local one = rowsOf({ { 100, 100, 120 } })
	local newestEnd = one[1].T + 3600
	check(#H.Alerts(one, newestEnd + 3 * 3600 - 1) == 0, "just under 3 quiet hours: nothing", "")
	alerts = H.Alerts(one, newestEnd + 3 * 3600)
	check(#alerts == 1 and string.find(alerts[1], "QUIET: no server wrote data since 09-21 13:00 KST (4 h)", 1, true), "3 quiet hours: a QUIET line", show(alerts))
	check(#H.Alerts({}, now) == 0, "no rows: no alert lines (the report says no data)", "")
	-- the goose
	local lop = rowsOf({ { 100, 100, 120, { HaloWins = 9, HornsWins = 1 } } })
	alerts = H.Alerts(lop, lop[1].T + 3600 + 600)
	check(#alerts == 1 and string.find(alerts[1], "GOOSE: Halo won 9 of 10 decided rounds", 1, true), "one side wins 9 of 10: a GOOSE line", show(alerts))
	local even = rowsOf({ { 100, 100, 120, { HaloWins = 8, HornsWins = 4 } } })
	check(#H.Alerts(even, even[1].T + 3600 + 600) == 0, "8 of 12 (67%): fine", "")
	local few = rowsOf({ { 100, 100, 120, { HaloWins = 7, HornsWins = 0 } } })
	check(#H.Alerts(few, few[1].T + 3600 + 600) == 0, "7 rounds: too few to judge", "")
	local horns = rowsOf({ { 100, 100, 120, { HaloWins = 2, HornsWins = 10 } } })
	check(string.find(H.Alerts(horns, horns[1].T + 3600 + 600)[1], "GOOSE: Horns won 10 of 12", 1, true) ~= nil, "Horns can be the lopsided side too", "")
	local manyTies = rowsOf({ { 100, 100, 120, { HaloWins = 9, HornsWins = 1, Ties = 20 } } })
	check(#H.Alerts(manyTies, manyTies[1].T + 3600 + 600) == 1, "ties are not decided rounds: 9 of 10 decided still flags", "")
	local tied = rowsOf({ { 100, 100, 120, { HaloWins = 5, HornsWins = 5, Ties = 40 } } })
	check(#H.Alerts(tied, tied[1].T + 3600 + 600) == 0, "ties do not count as a win for anyone", "")
	-- boundaries: exactly 3 baseline hours, exactly 60 player-minutes, a full hour ends exactly at `now`, exactly 75%
	local three = rowsOf({ { 1000, 2000, 60 }, { 1000, 2000, 60 }, { 1000, 2000, 60 }, { 4000, 2000, 60 } })
	check(#H.Alerts(three, three[4].T + 3600) == 1, "3 baseline hours, 60 player-minutes each, the hour ends exactly now: judged", show(H.Alerts(three, three[4].T + 3600)))
	check(#H.Alerts(three, three[4].T + 3599) == 0, "one second before the hour ends: not judged", "")
	local fifty9 = rowsOf({ { 1000, 2000, 60 }, { 1000, 2000, 60 }, { 1000, 2000, 59 }, { 4000, 2000, 60 } })
	check(#H.Alerts(fifty9, fifty9[4].T + 3600) == 0, "59 player-minutes is not a baseline hour (2 left)", "")
	local quarter = rowsOf({ { 100, 100, 120, { HaloWins = 9, HornsWins = 3 } } })
	check(#H.Alerts(quarter, quarter[1].T + 3600 + 600) == 1, "exactly 75% of 12 decided rounds flags", "")
	local ten = rowsOf({ { 100, 100, 120, { HaloWins = 10, HornsWins = 0 } } })
	check(#H.Alerts(ten, ten[1].T + 3600 + 600) == 1, "exactly 10 decided rounds are enough", "")
	local nineOnly = rowsOf({ { 100, 100, 120, { HaloWins = 9, HornsWins = 0 } } })
	check(#H.Alerts(nineOnly, nineOnly[1].T + 3600 + 600) == 0, "9 decided rounds are too few", "")
	-- a negative net, the order of a top list
	local neg = H.Text({ { T = NOON, Doc = { V = 1, GoldIn = { Quest = 100, Monster = 500 }, GoldOut = { Weapon = 900 } } } }, NOON + 100, "stored")
	check(string.find(neg, "Gold in 600 (Monster 500, Quest 100) / out 900 (Weapon 900) / net -300", 1, true) ~= nil, "net can be negative; the biggest source first", neg)
	-- the alerts show in the text
	local text = H.Text(lop, lop[1].T + 3600 + 600, "stored")
	check(string.find(text, "Alerts:\n  - GOOSE: Halo won 9 of 10 decided rounds", 1, true) ~= nil, "the report lists the alert lines", text)
end)

runGroup("Debug (the Studio command)", function()
	local w = healthWorld()
	local H = w.Health
	local p = hero(w, 1, 3)
	w.Reg.ProgressionService.GoldEarned:Fire(p, 100, "Monster")
	local text = H.Debug(nil)
	check(string.find(text, "Health (this server, not saved yet): 1 hours with data", 1, true) ~= nil and string.find(text, "Gold in 100 (Monster 100)", 1, true) ~= nil,
		"no value: this server's unsaved sums", text)
	H.Flush()
	check(string.find(H.Debug(nil), "no data in this window", 1, true) ~= nil, "after the flush nothing is unsaved", H.Debug(nil))
	text = H.Debug("stored")
	check(string.find(text, "Health (stored): 1 hours with data", 1, true) ~= nil and string.find(text, "Gold in 100 (Monster 100)", 1, true) ~= nil,
		"'stored' reads this environment's saved documents", text)
	local gets = w:Gets()
	H.Debug("stored:5")
	check(w:Gets() - gets == 5, "'stored:5' reads the last 5 hours", tostring(w:Gets() - gets))
	gets = w:Gets()
	H.Debug("stored:500")
	check(w:Gets() - gets == 72, "hours are capped at 72", tostring(w:Gets() - gets))
	gets = w:Gets()
	H.Debug("stored")
	check(w:Gets() - gets == 24, "no hours: 24", tostring(w:Gets() - gets))
	gets = w:Gets()
	H.Debug("stored:0")
	check(w:Gets() - gets == 1, "0 hours is read as 1", tostring(w:Gets() - gets))
	-- 'live' reads the real game's store name (read only), not the _STUDIO copy
	w.StoreOf("HaloHorns_Health_v1", "Standard")
	w.Stores["HaloHorns_Health_v1"].Rows[KEY] = { V = 1, Servers = 4, Joins = 40, GoldIn = { Monster = 5000 } }
	text = H.Debug("live:2")
	check(string.find(text, "Health (live): 1 hours with data", 1, true) ~= nil and string.find(text, "Gold in 5K (Monster 5K)", 1, true) ~= nil and string.find(text, "4 server-hours", 1, true) ~= nil,
		"'live' reads the plain store name", text)
	local writes = 0
	for _, c in w.DSCalls do if c.Store == "HaloHorns_Health_v1" and c.Op ~= "Get" then writes += 1 end end
	check(writes == 0, "reading live never writes", tostring(writes))
	-- a broken document is repaired when it is read
	w.Stores[STORE].Rows[KEY] = { GoldIn = { ["a b"] = 5, Huge = 1e13 }, Joins = 3, Evil = "x" }
	local fixed = H.ReadRows("stored", 1)[1].Doc
	check(fixed.GoldIn.ab == 5 and fixed.GoldIn.Huge == nil and fixed.Joins == 3 and fixed.Evil == nil and fixed.V == 1,
		"ReadRows repairs a document (cleaned keys, no huge numbers, no text)", show(fixed))
	-- a read that fails half way: the rows already read stay
	w.Stores[STORE].Rows[KEY] = { V = 1, Joins = 7 }
	w:Advance(3600)
	local dss = w.Services.DataStoreService
	local realGet = dss.GetDataStore
	dss.GetDataStore = function(self, name, scope)
		local st = realGet(self, name, scope)
		local n = 0
		local get = st.GetAsync
		st.GetAsync = function(a, key)
			n += 1
			if n == 2 then error("second read failed") end
			return get(a, key)
		end
		return st
	end
	local rowsHalf, errHalf = H.ReadRows("stored", 2)
	dss.GetDataStore = realGet
	check(#rowsHalf == 1 and rowsHalf[1].Doc.Joins == 7 and errHalf ~= nil, "a read that fails on its second hour: the first hour's row and the error", show({ #rowsHalf, errHalf }))
	local textHalf = H.Text(rowsHalf, w.Time, "stored")
	check(string.find(textHalf, "2 hours", 1, true) == nil and string.find(textHalf, "1 hours with data", 1, true) ~= nil, "... and a report from it", textHalf)
	w:Advance(-3600)
	-- a read failure keeps what was read and says so
	w.Fail[STORE .. ":Get"] = 1
	text = H.Debug("stored")
	check(string.find(text, "(read stopped: ", 1, true) ~= nil and string.find(text, "no data in this window", 1, true) ~= nil, "a failed read: the rows so far and a note", text)
	check(H.Debug("stored:abc") ~= nil and string.find(H.Debug("stored:abc"), "this server", 1, true) ~= nil, "an unreadable value falls back to this server", "")
end)

------------------------------------------------------------------ the real ProgressionService
runGroup("ProgressionService.AddXP fires XPEarned", function()
	local w = healthWorld()
	local p, d = hero(w, 1, 5)
	d.XP = 0
	w.PS.RefreshCharacter = function() end
	local prog = w:Load("ProgressionService", PROGRESSION_SOURCE)
	prog.Init(w.Reg)
	local got = {}
	prog.XPEarned:Connect(function(pl, n) table.insert(got, { pl == p, n }) end)
	local added = prog.AddXP(p, 10)
	check(added == 10 and #got == 1 and got[1][1] == true and got[1][2] == 10, "AddXP fires XPEarned(player, the XP really added)", show({ added, got }))
	prog.AddXP(p, 0)
	prog.AddXP(p, -5)
	check(#got == 1, "zero and negative XP fire nothing", #got)
	local capped = prog.AddXP(p, 1000, 20)
	check(capped == 20 and got[2] and got[2][2] == 20, "the amount after the cap is what is fired", show(got))
	local before = #got
	local lvl = tonumber(d.Level)
	prog.AddXP(p, 100000)
	check(#got == before + 1 and tonumber(d.Level) > lvl, "a level-up still fires it once", show({ #got - before, d.Level }))
	-- the whole chain: the real signal feeds HealthService
	local w2 = healthWorld()
	local p2, d2 = hero(w2, 1, 5)
	d2.XP = 0
	w2.PS.RefreshCharacter = function() end
	local prog2 = w2:Load("ProgressionService", PROGRESSION_SOURCE)
	prog2.Init(w2.Reg)
	prog2.XPEarned:Connect(function(pl, n) w2.Health.OnXP(pl, n) end)
	prog2.AddXP(p2, 25)
	check(pending(w2).XP["1-9"] == 25, "the XP of the real AddXP lands in the player's band", show(pending(w2).XP))
end)

finish()
