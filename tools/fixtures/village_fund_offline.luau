-- village_fund_offline.luau : A23-178 the village fund (VillageFundService, 게임성 개발 2, 2026-10-14; contract
-- docs/design/village_fund_server_2026-10-14.md). tools/test_village_fund.py binds CONFIG_SOURCE, UTIL_SOURCE and FUND_SOURCE in
-- front of dev2_kit.luau + dev3_world.luau; this file follows. VillageFundService runs from source on the dev3_world doubles
-- (+ SpendGold / GrantFame / SwitchService / Workspace / ProximityPromptService doubles here). Its loops are stepped by hand.

local STORE = "HaloHorns_VillageFund_v1_STUDIO"
local HALO = { X = 22, Y = 10, Z = -590 }

local function fundWorld(o)
	o = o or {}
	local w = dev3World(o)
	local C = w.Config
	local E = w:Env()
	w.V3 = E.Vector3.new
	w.Fame = {} -- { P, Stat, N, Ctx }
	w.Spent = {} -- { P, N, Why }
	w.Switch = true
	-- ProgressionService.SpendGold: carried first, then bank; false = nothing changed (the real rule)
	function w.Prog.SpendGold(p, amount, why)
		local d = w.Data[p]
		if not d then return false end
		local carried, bank = tonumber(d.CarriedGold) or 0, tonumber(d.BankGold) or 0
		if carried + bank < amount then return false end
		local fromC = math.min(carried, amount)
		w.PS.SetStat(p, "CarriedGold", carried - fromC)
		w.PS.SetStat(p, "BankGold", bank - (amount - fromC))
		table.insert(w.Spent, { P = p, N = amount, Why = why })
		return true
	end
	function w.PS.GrantFame(p, stat, n, ctx)
		table.insert(w.Fame, { P = p, Stat = stat, N = n, Ctx = ctx })
		return w.PS.AddStat(p, stat, n)
	end
	w.Reg.SwitchService = { On = function(key)
		if w.SwitchFails then error("switchboard down") end
		if key == "VillageFund" then return w.Switch end
		return true
	end }
	-- the places VillageFundService touches at Start
	local workspace = newInstance("Workspace", w)
	w.Workspace = workspace
	w.Services.Workspace = workspace
	w.Services.ProximityPromptService = { PromptTriggered = rbxSignal(w.Warnings) }
	w:Service("VillageFundService", FUND_SOURCE)
	w:InitStart({ "VillageFundService" })
	w.VF = w.Reg.VillageFundService
	-- a ready child of `side` standing `dist` studs (flat) from the Halo fountain, `dy` higher
	function w:Kid(id, side, gold, dist, data)
		local d = data or {}
		d.Faction = side
		d.CarriedGold = gold or 0
		local p = self:Arrive(id, { Data = d })
		self:Place(p, dist or 4, 3)
		return p, self.Data[p]
	end
	function w:Place(p, dist, dy)
		local char = newInstance("Model", self)
		local hum = newInstance("Humanoid", self)
		hum.Health = 100
		hum.Parent = char
		local root = newInstance("Part", self)
		root.Name = "HumanoidRootPart"
		root.Position = self.V3(HALO.X + dist, HALO.Y + (dy or 3), HALO.Z)
		root.Parent = char
		p.Character = char
		p.Hum = hum
	end
	function w:Give(p, ...)
		self:Remote("FundGive", p, ...)
	end
	function w:Opens(p)
		local out = {}
		for _, f in self.Fired do
			if f.Remote == "FundOpen" and f.Player == p then table.insert(out, f.Payload) end
		end
		return out
	end
	function w:Doc(wk)
		local s = self.Stores[STORE]
		return s and s.Rows["W" .. tostring(wk or C.WeekIndex(self.Time))] or nil
	end
	function w:Week() return C.WeekIndex(self.Time) end
	return w
end

local function gold(d) return (tonumber(d.CarriedGold) or 0) + (tonumber(d.BankGold) or 0) end
-- the fame calls without the player object (show() of a player overflows the stack)
local function fameRows(w)
	local out = {}
	for _, f in w.Fame do table.insert(out, { Stat = f.Stat, N = f.N, Ctx = f.Ctx }) end
	return out
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local V = C.VillageFund
	check(V.Enabled == true and V.Step == 1000 and V.PerDay == 3 and V.Points == 1, "on, 1,000 a gift, 3 a day, +1 a gift", show(V))
	check(V.Spots.Halo ~= nil and V.Spots.Halo.Pos.X == 22 and V.Spots.Halo.Pos.Y == 10 and V.Spots.Halo.Pos.Z == -590
		and V.Spots.Halo.Radius == 16 and V.Spots.Halo.Zone == "HaloTown", "the Halo spot: the Town_Halo_Fountain3 pool (22, 10, -590), radius 16, HaloTown", show(V.Spots.Halo))
	check(V.Spots.Horns == nil, "no Horns spot until its town is rebuilt (final review 10/14)", show(V.Spots))
	check(V.Goals.Lanterns == 30000 and V.Goals.Fireworks == 100000, "goals 30,000 lanterns / 100,000 fireworks", show(V.Goals))
	check(V.Store == "HaloHorns_VillageFund_v1" and V.FlushSeconds == 60 and V.ReadSeconds == 60, "store, flush 60, read 60", show(V))
	check(V.Stat.Halo == "Honor" and V.Stat.Horns == "Infamy", "Halo -> Honor, Horns -> Infamy (shown as Mischief)", show(V.Stat))
	check(C.Data.Defaults.FundDay == 0 and C.Data.Defaults.FundToday == 0 and C.Data.Defaults.FundGiven == 0, "three new save keys from 0", "")
	local sw = C.Switches.Defs.VillageFund
	check(type(sw) == "table" and sw.Type == "Bool" and sw.Default == true, "live switch VillageFund: Bool, on", show(sw))
	check(C.RateLimits.FundGive == 1, "FundGive: one a second", tostring(C.RateLimits.FundGive))
	local T = V.Text
	for _, side in { "Halo", "Horns" } do
		local t = T[side]
		check(type(t.Prompt) == "string" and type(t.Give) == "string" and type(t.Done) == "string" and type(t.Lanterns) == "string"
			and type(t.Fireworks) == "string", side .. ": Prompt / Give / Done / Lanterns / Fireworks lines", show(t))
	end
	check(string.find(T.Halo.Prompt, "Share") ~= nil and string.find(T.Horns.Prompt, "Show off") ~= nil
		and string.find(T.Horns.Done, "Mischief") ~= nil and string.find(T.Halo.Done, "Honor") ~= nil,
		"Halo shares (Honor), Horns shows off (Mischief)", show(T))
	local all = {}
	local function walk(t) for _, v in t do if type(v) == "table" then walk(v) else table.insert(all, tostring(v)) end end end
	walk(T)
	local korean = false
	for _, s in all do if string.find(s, "[\234-\237]") then korean = true end end
	check(not korean, "English only", "")
end)

------------------------------------------------------------------ prompts
runGroup("prompts", function()
	local w = fundWorld()
	local folder = w.Workspace:FindFirstChild("VillageFund")
	local spot = folder and folder:FindFirstChild("FundSpot_Halo")
	local prompt = spot and spot:FindFirstChild("FundPrompt")
	check(prompt ~= nil and folder:FindFirstChild("FundSpot_Horns") == nil, "one prompt part for Halo, none for Horns", "")
	check(spot ~= nil and spot.Anchored == true and spot.CanCollide == false and spot.Transparency == 1 and spot.CanQuery == false
		and spot.CanTouch == false and spot.Position.X == 22 and spot.Position.Z == -590, "an invisible anchored part at the pool", "")
	check(prompt ~= nil and prompt.ClassName == "ProximityPrompt" and prompt.MaxActivationDistance == 16 and prompt.HoldDuration == 0
		and prompt.ActionText == "" and prompt:GetAttribute("ActionKey") == "Config.VillageFund.Text.Halo.Prompt"
		and prompt:GetAttribute("ObjectKey") == "Config.VillageFund.Text.Title" and prompt:GetAttribute("Faction") == "Halo",
		"the prompt: radius 16, no hold, words by key, Faction Halo (the client hides it from others)", "")
	local pps = w.Services.ProximityPromptService
	local h = w:Kid(1, "Halo", 5000)
	local r = w:Kid(2, "Horns", 5000)
	pps.PromptTriggered:Fire(prompt, h)
	local o = w:Opens(h)
	check(#o == 1 and o[1].Faction == "Halo" and o[1].Today == 0 and o[1].PerDay == 3 and o[1].Step == 1000 and o[1].Gold == 5000
		and o[1].Can == true and o[1].Why == nil and o[1].Sum == 0 and o[1].Level == 0 and o[1].Goals.Lanterns == 30000,
		"a Halo child at the fountain: the card's numbers (FundOpen)", show(o))
	pps.PromptTriggered:Fire(prompt, r)
	check(#w:Opens(r) == 0, "a Horns child at the Halo fountain: nothing", "")
	pps.PromptTriggered:Fire(newInstance("ProximityPrompt", w), h)
	check(#w:Opens(h) == 1, "another prompt: nothing", "")
	w:Place(h, 30, 3)
	pps.PromptTriggered:Fire(prompt, h)
	check(#w:Opens(h) == 1, "too far: nothing", "")
	check(#w.Warnings == 0, "no warning", table.concat(w.Warnings, " | "))
end)

------------------------------------------------------------------ both sides (a Horns spot, as after its rebuild)
runGroup("both sides", function()
	local w = fundWorld({ EditConfig = function(c)
		c.VillageFund.Spots.Horns = { Pos = nativeEnv().Vector3.new(60, 10, -590), Radius = 50, Zone = "HornsTown" }
	end })
	local folder = w.Workspace:FindFirstChild("VillageFund")
	local hp = folder:FindFirstChild("FundSpot_Halo"):FindFirstChild("FundPrompt")
	local rp = folder:FindFirstChild("FundSpot_Horns") and folder:FindFirstChild("FundSpot_Horns"):FindFirstChild("FundPrompt")
	check(rp ~= nil and rp:GetAttribute("Faction") == "Horns" and rp:GetAttribute("ActionKey") == "Config.VillageFund.Text.Horns.Prompt"
		and rp.MaxActivationDistance == 50, "a Horns spot gets its own prompt", "")
	-- a Horns child at the Halo fountain (4 studs) is also inside the Horns spot (38 studs, radius 50)
	local r, dr = w:Kid(1, "Horns", 5000)
	local pps = w.Services.ProximityPromptService
	pps.PromptTriggered:Fire(hp, r)
	check(#w:Opens(r) == 0, "the Halo prompt never opens for a Horns child", "")
	pps.PromptTriggered:Fire(rp, r)
	check(#w:Opens(r) == 1 and w:Opens(r)[1].Faction == "Horns", "the Horns prompt opens the Horns card", "")
	w:Give(r)
	local n = w:NoticesFor(r)
	check(gold(dr) == 4000 and #w.Fame == 1 and w.Fame[1].Stat == "Infamy" and dr.Infamy == 1
		and n[#n] == "You showed off 1,000 gold! Mischief +1", "Horns: Infamy +1, 'showed off ... Mischief +1'", show(n))
	check(w.VF.Pending()[w:Week()].Horns == 1000 and w.GameState:GetAttribute("FundHorns") == 1000
		and w.GameState:GetAttribute("FundHalo") == 0, "the Horns sum, apart from Halo's", "")
end)

------------------------------------------------------------------ a gift
runGroup("gift", function()
	local w = fundWorld()
	local p, d = w:Kid(1, "Halo", 600, 4, { BankGold = 1000 })
	w:Give(p)
	check(d.CarriedGold == 0 and d.BankGold == 600 and #w.Spent == 1 and w.Spent[1].N == 1000 and w.Spent[1].Why == "Fund",
		"1,000 paid, carried first then bank (SpendGold reason Fund)", show({ d.CarriedGold, d.BankGold }))
	check(#w.Fame == 1 and w.Fame[1].Stat == "Honor" and w.Fame[1].N == 1 and w.Fame[1].Ctx.Fund == true
		and w.Fame[1].Ctx.PvP == nil and w.Fame[1].Ctx.RankPoints == nil and d.Honor == 1,
		"Honor +1 through GrantFame ctx Fund (never the weekly boards)", show(fameRows(w)))
	check(d.FundDay == w.Config.DayIndex(w.Time) and d.FundToday == 1 and d.FundGiven == 1000, "saved: today, 1 gift, 1,000 given",
		show({ d.FundDay, d.FundToday, d.FundGiven }))
	local n = w:NoticesFor(p)
	check(n[#n] == "You shared 1,000 gold! Honor +1" and w:SoundsFor(p)[#w:SoundsFor(p)] == "RankUp", "the line: shared, Honor +1", show(n))
	local o = w:Opens(p)
	check(#o == 1 and o[1].Today == 1 and o[1].Gold == 600 and o[1].Can == false and o[1].Why == "Poor" and o[1].Sum == 1000,
		"FundOpen again after the gift (today 1, 600 left: Poor)", show(o))
	local pend = w.VF.Pending()[w:Week()]
	check(pend and pend.Halo == 1000 and (pend.Horns or 0) == 0, "the week's pending sum +1,000 for Halo", show(w.VF.Pending()))
	check(w.GameState:GetAttribute("FundHalo") == 1000 and w.GameState:GetAttribute("FundWeek") == w:Week()
		and w.GameState:GetAttribute("FundLevelHalo") == 0, "GameState FundHalo 1,000, this week, level 0", "")
	-- the client sends numbers: ignored
	local q, dq = w:Kid(2, "Halo", 50000)
	w:Give(q, 1000000000, "Horns", { Step = 1 })
	check(gold(dq) == 49000 and #w.Fame == 2 and w.Fame[2].Stat == "Honor" and w.Fame[2].N == 1,
		"arguments are ignored: still 1,000 and Honor +1", show({ gold(dq), fameRows(w) }))
	check(#w.Warnings == 0, "no warning", table.concat(w.Warnings, " | "))
end)

------------------------------------------------------------------ refusals
runGroup("refusals", function()
	local w = fundWorld()
	local function same(p, d, before, label)
		check(gold(d) == before and (d.FundToday or 0) == 0 and #w.Fame == 0 and #w.Spent == 0, label, show({ gold(d), d.FundToday, #w.Fame }))
		local _ = p
	end
	local r, dr = w:Kid(1, "Horns", 5000)
	w:Give(r)
	same(r, dr, 5000, "Horns (no spot yet): nothing")
	check(#w:NoticesFor(r) == 0 and #w:Opens(r) == 0, "Horns: no line, no card", show(w:NoticesFor(r)))
	local n, dn = w:Kid(2, "Neutral", 5000)
	w:Give(n)
	same(n, dn, 5000, "Neutral: nothing")
	local z, dz = w:Kid(3, "None", 5000)
	w:Give(z)
	same(z, dz, 5000, "no side yet: nothing")
	local far, dfar = w:Kid(4, "Halo", 5000, 17)
	w:Give(far)
	same(far, dfar, 5000, "17 studs away (radius 16): nothing")
	w:Place(far, 15.9, 40)
	w:Give(far)
	check(gold(dfar) == 4000, "15.9 studs flat, 40 higher: the gift counts (height ignored)", gold(dfar))
	w.Fame, w.Spent = {}, {}
	local dead, dd = w:Kid(5, "Halo", 5000)
	dead.Hum.Health = 0
	w:Give(dead)
	same(dead, dd, 5000, "dead: nothing")
	local noChar, dnc = w:Kid(6, "Halo", 5000)
	noChar.Character = nil
	w:Give(noChar)
	same(noChar, dnc, 5000, "no character: nothing")
	local nr, dnr = w:Kid(7, "Halo", 5000)
	w.Ready[nr] = nil
	w:Give(nr)
	same(nr, dnr, 5000, "not ready: nothing")
	local poor, dp = w:Kid(8, "Halo", 999)
	w:Give(poor)
	same(poor, dp, 999, "999 gold: nothing paid")
	local np = w:NoticesFor(poor)
	check(np[#np] == "You need 1,000 gold." and w:Opens(poor)[1].Why == "Poor", "999: 'You need 1,000 gold.' + the card (Poor)", show(np))
	check(#w.Warnings == 0, "no warning", table.concat(w.Warnings, " | "))
end)

------------------------------------------------------------------ the day, the rate, the switch
runGroup("limits", function()
	local w = fundWorld()
	local p, d = w:Kid(1, "Halo", 10000)
	for _ = 1, 3 do w:Give(p) end
	check(gold(d) == 7000 and d.FundToday == 3 and #w.Fame == 3, "three gifts today", show({ gold(d), d.FundToday }))
	w:Give(p)
	local n = w:NoticesFor(p)
	check(gold(d) == 7000 and d.FundToday == 3 and #w.Fame == 3 and n[#n] == "That's 3 for today. Come back tomorrow!",
		"the 4th today: nothing, 'That's 3 for today'", show(n))
	local o = w:Opens(p)
	check(o[#o].Why == "Full" and o[#o].Can == false, "the card says Full", show(o[#o]))
	w:ToDay(1)
	w:Give(p)
	check(gold(d) == 6000 and d.FundToday == 1 and d.FundDay == w.Config.DayIndex(w.Time) and d.FundGiven == 4000,
		"the next KST day: counting from 1 again (FundGiven adds up)", show({ d.FundToday, d.FundGiven }))
	-- one a second
	w.Gap = 0.4
	w:Give(p)
	check(d.FundToday == 1, "0.4 s after: refused (rate)", d.FundToday)
	w.Gap = nil
	w:Give(p)
	check(d.FundToday == 2, "a second later: counts", d.FundToday)
	-- the switch
	w.Switch = false
	w:Give(p)
	n = w:NoticesFor(p)
	check(d.FundToday == 2 and gold(d) == 5000 and n[#n] == "The fund is closed right now." and w:Opens(p)[#w:Opens(p)].Why == "Closed",
		"switch VillageFund off: nothing, 'closed', the card says Closed", show(n))
	w.Switch = true
	w.SwitchFails = true
	w:Give(p)
	check(d.FundToday == 3, "a failing switchboard = on", d.FundToday)
	check(#w.Warnings == 0, "no warning", table.concat(w.Warnings, " | "))
end)

------------------------------------------------------------------ the week's document
runGroup("week", function()
	local stores = {}
	local w = fundWorld({ Stores = stores })
	local p = w:Kid(1, "Halo", 100000)
	w:Give(p)
	w:Give(p)
	check(w:Doc() == nil, "nothing written before the flush", show(w:Doc()))
	check(w.VF.Flush() == true and w:Doc() and w:Doc().Halo == 2000 and (w:Doc().Horns or 0) == 0, "the flush writes W<week> Halo 2,000",
		show(w:Doc()))
	check(next(w.VF.Pending()) == nil and w.VF.SumOf("Halo") == 2000, "nothing pending; the shown sum stays 2,000", show(w.VF.Pending()))
	-- another server of the same game
	local w2 = fundWorld({ Stores = stores })
	local q = w2:Kid(2, "Halo", 100000)
	w2:Give(q)
	w2.VF.Flush()
	check(w2:Doc().Halo == 3000, "a second server adds (UpdateAsync merge): 3,000", show(w2:Doc()))
	w.VF.Read()
	check(w.VF.SumOf("Halo") == 3000 and w.GameState:GetAttribute("FundHalo") == 3000, "the first server reads 3,000", w.VF.SumOf("Halo"))
	-- a failed write keeps the gifts
	w:Give(p)
	w.AllowWarn = "save"
	w.Fail[STORE .. ":Update"] = 1
	check(w.VF.Flush() == false and w.VF.Pending()[w:Week()].Halo == 1000 and w:Doc().Halo == 3000, "a failed write: kept pending",
		show(w.VF.Pending()))
	check(w.VF.SumOf("Halo") == 4000, "the shown sum still counts it", w.VF.SumOf("Halo"))
	check(w.VF.Flush() == true and w:Doc().Halo == 4000, "the next flush adds it: 4,000", show(w:Doc()))
	-- the week turns before the flush: the gift stays in its own week
	local wk = w:Week()
	local monday = w.Config.WeekStart(wk + 1)
	w:Advance(monday - 30 - w.Time)
	w:Give(p)
	w:Advance(120)
	check(w:Week() == wk + 1 and w.VF.SumOf("Halo") == 0, "a new week: the shown sum starts at 0", w.VF.SumOf("Halo"))
	w.VF.Flush()
	check(w:Doc(wk).Halo == 5000 and w:Doc(wk + 1) == nil, "the gift before Monday went to last week's document", show(w:Doc(wk)))
	-- the close
	w:Give(p)
	for _, fn in w.BoundToClose do fn() end
	check(w:Doc(wk + 1) and w:Doc(wk + 1).Halo == 1000, "the close flushes", show(w:Doc(wk + 1)))
	check(#w.Warnings == 1 and string.find(w.Warnings[1], "save") ~= nil, "one warning (the failed save)", table.concat(w.Warnings, " | "))
end)

------------------------------------------------------------------ the loops
runGroup("loops", function()
	local stores = {}
	local w = fundWorld({ Stores = stores })
	local wk = w:Week()
	stores[STORE] = stores[STORE] or { Name = STORE, Kind = "Standard", Rows = {} }
	stores[STORE].Rows["W" .. wk] = { V = 1, Halo = 700, Horns = 0 }
	local p = w:Kid(1, "Halo", 5000)
	w:Give(p)
	w:Tick(70)
	w:Tick(100)
	check(w:Doc().Halo == 1700, "the flush loop writes within its time (60 s x0.5..1.5)", show(w:Doc()))
	check(w.VF.SumOf("Halo") == 1700, "the read loop reads the week", w.VF.SumOf("Halo"))
end)

------------------------------------------------------------------ the town lights
runGroup("levels", function()
	local edit = function(c) c.VillageFund.Goals = { Lanterns = 2000, Fireworks = 3000 } end
	local stores = {}
	local w = fundWorld({ Stores = stores, EditConfig = edit })
	check(w.VF.LevelOf(1999) == 0 and w.VF.LevelOf(2000) == 1 and w.VF.LevelOf(2999) == 1 and w.VF.LevelOf(3000) == 2,
		"levels: lanterns at Goals.Lanterns, fireworks at Goals.Fireworks", "")
	w.VF.Read()
	local a = w:Kid(1, "Halo", 100000, 4, nil)
	a:SetAttribute("ZoneId", "HaloTown")
	local away = w:Kid(2, "Halo", 0)
	away:SetAttribute("ZoneId", "SlimeMeadow")
	local L = w.Config.VillageFund.Text.Halo
	local function count(p, line)
		local c = 0
		for _, t in w:NoticesFor(p) do if t == line then c += 1 end end
		return c
	end
	w:Give(a)
	check(count(a, L.Lanterns) == 0, "1,000: no light yet", "")
	w:Give(a)
	check(count(a, L.Lanterns) == 1 and count(away, L.Lanterns) == 0 and w.GameState:GetAttribute("FundLevelHalo") == 1,
		"2,000: the lanterns line once, only in the town; level 1", show(w:NoticesFor(a)))
	w:Give(a)
	check(count(a, L.Fireworks) == 1 and w.GameState:GetAttribute("FundLevelHalo") == 2, "3,000: the fireworks line; level 2", "")
	w:ToDay(1)
	w:Give(a)
	check(count(a, L.Lanterns) == 1 and count(a, L.Fireworks) == 1, "never twice a week", show(w:NoticesFor(a)))
	w.VF.Flush()
	-- a new server reading a week already lit: no line
	local w2 = fundWorld({ Stores = stores, EditConfig = edit })
	local b = w2:Kid(3, "Halo", 100000)
	b:SetAttribute("ZoneId", "HaloTown")
	w2:Tick(1)
	check(w2.GameState:GetAttribute("FundLevelHalo") == 2 and count(b, L.Fireworks) == 0 and #w2:NoticesFor(b) == 0,
		"a new server: level 2 shown, no line for what was reached before", show(w2:NoticesFor(b)))
	-- the week turns with children in town: the new week's first read (already lit by other servers) says nothing
	local wk = w2:Week()
	stores[STORE].Rows["W" .. (wk + 1)] = { V = 1, Halo = 5000, Horns = 0 }
	w2:Advance(w2.Config.WeekStart(wk + 1) + 10 - w2.Time)
	w2:Tick(1)
	check(w2.VF.SumOf("Halo") == 5000 and w2.GameState:GetAttribute("FundLevelHalo") == 2 and #w2:NoticesFor(b) == 0,
		"a new week read while children are in town: level 2 shown, no line", show(w2:NoticesFor(b)))
end)

------------------------------------------------------------------ off
runGroup("off", function()
	local w = fundWorld({ EditConfig = function(c) c.VillageFund.Enabled = false end })
	check(w.Workspace:FindFirstChild("VillageFund") == nil, "Enabled = false: no prompt", "")
	local p, d = w:Kid(1, "Halo", 5000)
	w:Give(p)
	check(gold(d) == 5000 and #w.Fame == 0 and #w:Opens(p) == 0, "Enabled = false: nothing", show(w:NoticesFor(p)))
end)

finish()
