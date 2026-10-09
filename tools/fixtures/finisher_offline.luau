-- finisher_offline.luau : the King Slime finisher card (게임성 개발 2, 2026-10-08; docs/design/king_finisher_2026-10-08.md).
-- tools/test_finisher.py runs it after dev2_kit.luau and dev2_combat_world.luau: the REAL CombatService, SkillService,
-- DamageWindow, LootService and StoryQuestService of the combat world, with MonsterService's REAL DamageMonster +
-- killRecord (KILL_SOURCE, cut from the current MonsterService.luau) put on the world's MonsterService, and the REAL
-- Deeds (the daily ledger) and FinisherService on the same registry (TelemetryService and the gold calls are recorded). A press
-- (swing / Q / Z, manual or auto) kills a King Slime record end to end; the card, the pick remote, the timer and leaving
-- run through FinisherService's own Start() connections.

local C0F = execute("Config", CONFIG_SOURCE, nativeEnv())
local FIN = C0F.Finisher
-- the King Slime's card (Config.Finisher.Cards[kind], 2026-10-09: per boss kind; Captain Clatter has the other)
local CARD = FIN.Cards.SlimeKing

-- the world: o.Z = Z skills on; o.Edit(cfg) before the services see Config; o.RealRules = keep the King Slime's A23-27
-- reward rules (3 own hits, 0.5% of MaxHP): the other groups kill one-hit records, so they turn them off
local function finWorld(o)
	o = o or {}
	local w = bareWorld({})
	local cfg = w.Config
	if not o.RealRules then
		cfg.MonsterTypes.SlimeKing.RewardMinHits, cfg.MonsterTypes.SlimeKing.RewardMinDamageFrac = 0, 0
	end
	local K = cfg.Skills
	K.ZEnabled = o.Z == true
	K.Unlock = { Q = 1, Z = 5, X = 8 }
	if o.Edit then o.Edit(cfg) end
	local reg = w.Registry
	local Signal = w.Util.Signal
	local ms = reg.MonsterService
	ms.Moment = Signal.new()
	-- the real kill: MonsterService.DamageMonster (replaces the world's double) + killRecord
	w.Records, w.Pops, w.Kills = {}, {}, {}
	local H = { records = w.Records }
	function H.updateBar() end
	function H.deathPop(rec) table.insert(w.Pops, rec) end
	function H.factionOf(p) return p:GetAttribute("Faction") or "None" end
	function H.removePersonalRef() end
	function H.markHurt() end
	function H.zoneIdOf(p) return reg.ZoneService.GetZoneId(p) end
	function H.scheduleRespawn() end
	function H.warnThrottled(key, msg) table.insert(w.Warnings, "MonsterService " .. tostring(key) .. ": " .. tostring(msg)) end
	execute("MonsterService.kill", KILL_SOURCE, w:Env(), cfg, w.Util, cfg.Monsters, ms, H)
	ms.MonsterKilled:Connect(function(p, info) table.insert(w.Kills, { P = p, Info = info }) end)
	-- gold calls with their source (the world's double keeps adding to the bank, returns nothing like main)
	w.GoldCalls = {}
	local bank = reg.ProgressionService.AddBankGold
	reg.ProgressionService.AddBankGold = function(p, n, source)
		table.insert(w.GoldCalls, { P = p, N = n, Source = source })
		bank(p, n)
		if o.GoldReturns then return o.GoldReturns(n) end
		return nil
	end
	w.Metrics = {}
	reg.TelemetryService = { Custom = function(p, name, value, a, b, c)
		table.insert(w.Metrics, { P = p, Name = name, Value = value, A = a, B = b, C = c })
	end }
	if o.GrantFails then
		reg.LootService.GrantItem = function() error("offline GrantItem failure") end
	end
	-- the daily deeds ledger (game dev 3, A23-86): the finisher's points go through it (its day loop is never run)
	local deeds = w:Load("Deeds", DEEDS_SOURCE)
	local fin = w:Load("FinisherService", FINISHER_SOURCE)
	reg.Deeds, reg.FinisherService = deeds, fin
	w.Deeds = deeds
	deeds.Init(reg)
	fin.Init(reg)
	deeds.Start()
	fin.Start()
	w.Budget, w.Fin = budget, fin
	w.PickedLog = {}
	fin.Picked:Connect(function(p, pick, kind) table.insert(w.PickedLog, { P = p, Pick = pick, Kind = kind }) end)

	w.Serial = 0
	-- a King Slime boss (or o2.Kind) record dz studs in front of the origin, HP 1 (one hit kills), in the meadow
	function w:King(o2)
		o2 = o2 or {}
		self.Serial += 1
		local kind = o2.Kind or "SlimeKing"
		local rec = self:Monster(kind, o2.Dz or 3, o2.Dx or 0, o2.HP or 1)
		rec.Id, rec.MaxHP = self.Serial, cfg.MonsterTypes[kind].HP
		rec.Home, rec.Owner, rec.Golden = rec.Root.Position, o2.Owner, o2.Golden == true
		rec._contributors, rec._hits, rec._dmg = {}, {}, {}
		self.Records[rec.Id] = rec
		return rec
	end
	-- a ready hero at the origin facing -Z (Level 9, Q / Z / X slots, MP); jo as w:Join
	function w:Hero(id, jo)
		jo = jo or {}
		jo.Level = jo.Level or 9
		jo.Data = jo.Data or {}
		jo.Data.SkillSlots = 3
		jo.Attrs = jo.Attrs or {}
		jo.Attrs.Mana = 100
		if jo.Auto then
			jo.Attrs.AutoCombatUnlocked, jo.Attrs.AutoCombatEnabled = true, true
		end
		return self:Join(id, jo)
	end
	function w:Swing(p)
		self:Advance(2)
		self.Combat.Swing(p, true)
		self:Flush()
	end
	function w:Use(p, slot)
		self:Advance(4) -- the skill gap and cooldowns
		self.Net.Get("UseSkill").OnServerEvent:Fire(p, slot)
		self:Flush()
	end
	-- a direct hit as MonsterService sees it (manual = the player's own press)
	function w:Hit(rec, p, amount, manual)
		return self.Registry.MonsterService.DamageMonster(rec, amount or 1, p, false, nil, manual)
	end
	function w:Cards(p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Fx do
			local f = self.Fx[i]
			if f.Kind == "FinisherCard" and (p == nil or f.Player == p) then table.insert(out, f.Data) end
		end
		return out
	end
	function w:Ends(p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Fx do
			local f = self.Fx[i]
			if f.Kind == "FinisherEnd" and (p == nil or f.Player == p) then table.insert(out, f.Data) end
		end
		return out
	end
	function w:Pick(p, ...)
		self:Advance(0.31) -- RateLimits.FinisherPick
		self.Net.Get("FinisherPick").OnServerEvent:Fire(p, ...)
		self:Flush()
	end
	-- the newest card of p (a fresh Studio-style card when `fresh`)
	function w:Offer(p)
		local ok = self.Fin.DebugOffer(p)
		self:Flush()
		local cards = self:Cards(p)
		return ok, cards[#cards]
	end
	function w:Jelly(p) return math.floor(tonumber(self.Data[p].Items and self.Data[p].Items.Jelly) or 0) end
	function w:MetricsOf(p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Metrics do
			local m = self.Metrics[i]
			if m.P == p then table.insert(out, m.Name .. ":" .. tostring(m.A) .. ":" .. tostring(m.B)) end
		end
		return table.concat(out, ",")
	end
	return w
end

------------------------------------------------------------------ config
runGroup("config", function()
	check(FIN.Kinds.SlimeKing == true and FIN.Kinds.BigSlime == nil, "the King Slime boss gives the card, the Slime Prince not")
	local kinds = 0
	for k in FIN.Kinds do
		kinds += 1
		check(type(FIN.Cards[k]) == "table", "every card kind has its Cards entry", k)
	end
	check(kinds == 2 and FIN.Kinds.CaptainClatter == true, "only the field bosses (King Slime, Captain Clatter)", kinds)
	check(FIN.Seconds == 10 and FIN.Grace == 1 and FIN.Points == 1, "10 s to pick (+1 s network grace), 1 point", show({ FIN.Seconds, FIN.Grace, FIN.Points }))
	local jelly = C0F.Loot.Items[CARD.Help.Item]
	check(CARD.Help.Item == "Jelly" and jelly ~= nil and jelly.Kind == "Material", "Help gives Jelly (a material)")
	check(CARD.Help.N * jelly.Sell == CARD.Tickle.Gold and CARD.Tickle.Gold > 0, "the same size: Help.N x Jelly sell == Tickle gold",
		show({ CARD.Help.N, jelly.Sell, CARD.Tickle.Gold }))
	check(C0F.Deeds.PerDay == 6 and C0F.ScoreBudget == nil, "one daily cap: the deeds ledger, 6 points a KST day",
		C0F.Deeds.PerDay)
	check(C0F.RateLimits.FinisherPick == 0.3, "FinisherPick rate limit 0.3 s", C0F.RateLimits.FinisherPick)
	local T = CARD.Text
	check(T.Title == "The King Slime is dizzy!" and T.Help == "Help it hop home" and T.Tickle == "Tickle out its coins",
		"the card's words (검수 2026-10-08)", show({ T.Title, T.Help, T.Tickle }))
	local banned = false
	for _, texts in { FIN.Text, FIN.Cards.SlimeKing.Text, FIN.Cards.CaptainClatter.Text } do
		for _, s in texts do
			if string.find(string.lower(s), "shake", 1, true) then banned = true end
		end
	end
	check(not banned, "no 'Shake it down' anywhere in the card text")
	local PB = C0F.PassBoost
	check(PB == nil or type(PB.GoldSources) ~= "table" or PB.GoldSources.Finisher == nil,
		"card gold is never 2x (not a PassBoost gold source)")
end)

------------------------------------------------------------------ Captain Clatter's card (J, Config.Finisher.Cards)
runGroup("Captain Clatter's card", function()
	local CC = FIN.Cards.CaptainClatter
	local cap = C0F.Loot.ItemCap or 999
	local w = finWorld()
	-- a full scroll bag: the rest is paid at the card's Worth (a scroll has no Sell)
	local p = w:Hero(151, { Faction = "Halo", Data = { Items = { Enh70 = cap } } })
	local boss = w:King({ Kind = "CaptainClatter" })
	-- A23-27: 3 own hits and the damage share (two hits and 500 damage before this swing)
	boss._hits[p], boss._dmg[p], boss._contributors[p] = 2, 500, os.clock()
	w:Swing(p)
	check(boss.Alive == false, "(a manual swing finished Captain Clatter)")
	local cards = w:Cards(p)
	local c = cards[1]
	check(#cards == 1 and c.Kind == "CaptainClatter" and c.Help.Item == "Enh70" and c.Help.N == 1 and c.Tickle.Gold == 300,
		"his own card: [Let him rest] 1 Enh70, [Count the old treasure!] 300 gold", show(c))
	w:Pick(p, c.Id, "Help")
	local e = w:Ends(p)[1]
	check(e.Item == "Enh70" and e.N == 0 and e.Gold == CC.Help.Worth and (w.Data[p].BankGold or 0) == CC.Help.Worth,
		"a full bag: the scroll paid at its Worth (300)", show(e))
	local lines = w:NoticesFor(p)
	check(table.concat(lines, " | "):find(CC.Text.HelpDone, 1, true) ~= nil,
		"his own HelpDone line", table.concat(lines, " | "))
	-- room in the bag: the scroll itself
	local q = w:Hero(152, { Faction = "Horns" })
	local b2 = w:King({ Kind = "CaptainClatter" })
	b2._hits[q], b2._dmg[q], b2._contributors[q] = 2, 500, os.clock()
	w:Swing(q)
	local c2 = w:Cards(q)[1]
	w:Pick(q, c2.Id, "Tickle")
	local e2 = w:Ends(q)[1]
	check(e2.Gold == CC.Tickle.Gold and e2.N == 0 and table.concat(w:NoticesFor(q), " | "):find(CC.Text.TickleDone, 1, true) ~= nil,
		"Tickle: 300 bank gold and his TickleDone line", show(e2))
end)

------------------------------------------------------------------ who gets a card (kills through the real presses)
runGroup("who gets a card", function()
	-- a manual swing kills it: a card, and the kill itself is paid as before (Manual on the info)
	local w = finWorld()
	local p = w:Hero(101)
	local king = w:King()
	w:Swing(p)
	check(king.Alive == false, "(a manual swing killed the king)")
	local cards = w:Cards(p)
	check(#cards == 1 and cards[1].Kind == "SlimeKing" and cards[1].Seconds == FIN.Seconds and cards[1].Id == 1,
		"a manual swing kill: one card (Id 1, SlimeKing, 10 s)", show(cards[1]))
	check(#w.Kills == 1 and w.Kills[1].P == p and w.Kills[1].Info.Manual == true and w.Kills[1].Info.Kind == "SlimeKing"
		and w.Kills[1].Info.XP == C0F.MonsterTypes.SlimeKing.XP, "the kill is paid as before, info.Manual = true",
		show({ #w.Kills, w.Kills[1] and w.Kills[1].Info.Manual }))
	-- auto combat only: no card, the kill still paid
	local a = finWorld()
	local ap = a:Hero(102, { Auto = true })
	local ak = a:King()
	for _ = 1, 4 do
		if ak.Alive then
			a:Advance(2)
			a:AutoTick()
		end
	end
	check(ak.Alive == false, "(auto combat killed the king)")
	check(#a:Cards(ap) == 0, "an auto-combat-only kill: no card", #a:Cards(ap))
	check(#a.Kills == 1 and a.Kills[1].Info.Manual == false, "the auto kill is still paid (Manual = false)",
		show({ #a.Kills, a.Kills[1] and a.Kills[1].Info.Manual }))
	-- the Slime Prince (the old King Slime, BigSlime): no card, and A23-12's first 70% scroll is still its
	local pr = finWorld()
	local prp = pr:Hero(106)
	local prince = pr:King({ Kind = "BigSlime" })
	pr:Swing(prp)
	check(prince.Alive == false and #pr:Cards(prp) == 0 and #pr.Kills == 1, "a manual Slime Prince kill: paid, no card",
		show({ #pr:Cards(prp), #pr.Kills }))
	check((pr.Data[prp].LootFlags or {}).FirstScroll == true and (w.Data[p].LootFlags or {}).FirstScroll ~= true,
		"A23-12: the first 70% scroll stays the Slime Prince's (not the boss's)")
	-- a Shard Slime (not the king): no card
	local s = finWorld()
	local sp = s:Hero(103)
	local slime = s:King({ Kind = "Slime" })
	s:Swing(sp)
	check(slime.Alive == false and #s:Cards(sp) == 0, "a manual Shard Slime kill: no card", #s:Cards(sp))
	-- the boss's own reward rules (A23-27) come first: a 1-hit manual helper is not paid and gets no card
	local r = finWorld({ RealRules = true })
	local tap = r:Hero(104)
	local hunter = r:Hero(105)
	local big = r:King({ HP = 20 })
	r:Hit(big, tap, 1, true)
	for _ = 1, 3 do r:Hit(big, hunter, 5, true) end
	r:Hit(big, hunter, 5, true)
	check(big.Alive == false and #r:Cards(hunter) == 1 and #r:Cards(tap) == 0 and #r.Kills == 1 and r.Kills[1].P == hunter,
		"real rules: the 4-hit hunter is paid with a card, the 1-hit tapper neither", show({ #r:Cards(hunter), #r:Cards(tap), #r.Kills }))
end)

runGroup("manual hits and the window", function()
	local w = finWorld()
	local a = w:Hero(111)
	local b = w:Hero(112)
	-- a manual hit 130 s before an auto finish: outside the King's 120 s window -> no card
	local k1 = w:King({ HP = 3 })
	w:Hit(k1, a, 1, true)
	w:Advance(130)
	w:Hit(k1, a, 1, false)
	w:Hit(k1, a, 5, false)
	check(k1.Alive == false and #w:Cards(a) == 0, "a manual hit 130 s before the (auto) kill: no card", #w:Cards(a))
	check(#w.Kills == 1 and w.Kills[1].Info.Manual == false, "(still paid, Manual = false)")
	-- a manual hit 100 s before an auto finish: inside -> a card
	local k2 = w:King({ HP = 3 })
	w:Hit(k2, a, 1, true)
	w:Advance(100)
	w:Hit(k2, a, 5, false)
	check(#w:Cards(a) == 1, "a manual hit 100 s before the (auto) kill: a card", #w:Cards(a))
	-- two hunters: a manual, b auto only -> only a's card; both paid
	local w2 = finWorld()
	local c = w2:Hero(113)
	local d = w2:Hero(114)
	local k3 = w2:King({ HP = 3 })
	w2:Hit(k3, d, 1, false)
	w2:Hit(k3, c, 5, true)
	check(#w2:Cards(c) == 1 and #w2:Cards(d) == 0, "manual c gets a card, auto-only d does not", show({ #w2:Cards(c), #w2:Cards(d) }))
	check(#w2.Kills == 2, "both are paid for the kill (the same kill for everyone)", #w2.Kills)
	-- a manual hit the zone rule refused (standing outside the meadow) is not a manual hit
	local w3 = finWorld()
	local e = w3:Hero(115)
	local k4 = w3:King({ HP = 3 })
	w3.ZoneOf[e] = "GoblinWoods"
	check(w3:Hit(k4, e, 1, true) == false and k4._contributors[e] == nil, "(a refused hit: no contribution)")
	w3.ZoneOf[e] = nil
	w3:Hit(k4, e, 5, false)
	check(#w3:Cards(e) == 0, "a refused manual hit + an auto kill: no card", #w3:Cards(e))
	-- the record forgets its manual hits at the kill
	check(type(k4._manualAt) == "table" and next(k4._manualAt) == nil, "the kill clears the manual hits", show(k4._manualAt))
end)

runGroup("manual presses", function()
	-- Q pressed by hand: a card; Q by auto combat: none
	local w = finWorld()
	local p = w:Hero(121)
	local k = w:King({ Dz = 2 })
	w:Use(p, "Q")
	check(k.Alive == false and #w:Cards(p) == 1, "a manual Q kill: a card", show({ k.Alive, #w:Cards(p) }))
	local a = finWorld()
	local ap = a:Hero(122, { Auto = true })
	local ak = a:King({ Dz = 2 })
	a:Advance(4)
	a.Skills.Cast(ap, "Q", true)
	a:Flush()
	check(ak.Alive == false and #a:Cards(ap) == 0, "an auto Q kill: no card", show({ ak.Alive, #a:Cards(ap) }))
	-- Z by hand: a card; Z by auto combat: none
	local z = finWorld({ Z = true })
	local zp = z:Hero(123)
	local zk = z:King({ Dz = 3 })
	z:Use(zp, "Z")
	check(zk.Alive == false and #z:Cards(zp) == 1, "a manual Z kill: a card", show({ zk.Alive, #z:Cards(zp) }))
	local za = finWorld({ Z = true })
	local zap = za:Hero(124, { Auto = true })
	local zak = za:King({ Dz = 3 })
	za:Advance(4)
	za.Skills.Cast(zap, "Z", true)
	za:Flush()
	check(zak.Alive == false and #za:Cards(zap) == 0, "an auto Z kill: no card", show({ zak.Alive, #za:Cards(zap) }))
end)

------------------------------------------------------------------ the card's payload
runGroup("card payload", function()
	local w = finWorld()
	local halo = w:Hero(131, { Faction = "Halo" })
	local _, c = w:Offer(halo)
	check(c.Stat == "Honor" and c.Help.Item == "Jelly" and c.Help.N == CARD.Help.N and c.Help.Score == 1
		and c.Tickle.Gold == CARD.Tickle.Gold and c.Tickle.Score == 0 and c.Help.Hint == nil and c.Tickle.Hint == "Zero",
		"Halo, Honor 0: Help = Jelly x2 (+1), Tickle = 4 gold (0: nothing to lose)", show(c))
	local h3 = w:Hero(132, { Faction = "Halo", Data = { Honor = 3 } })
	local _, c3 = w:Offer(h3)
	check(c3.Help.Score == 1 and c3.Tickle.Score == -1 and c3.Help.Hint == nil and c3.Tickle.Hint == nil,
		"Halo, Honor 3: Help +1, Tickle -1 (no hints)", show({ c3.Help.Score, c3.Tickle.Score }))
	local horns = w:Hero(133, { Faction = "Horns", Data = { Infamy = 2 } })
	local _, ch = w:Offer(horns)
	check(ch.Stat == "Infamy" and ch.Tickle.Score == 1 and ch.Help.Score == -1, "Horns, Infamy 2: Tickle +1, Help -1", show(ch))
	local h0 = w:Hero(136, { Faction = "Horns" })
	local _, c0 = w:Offer(h0)
	check(c0.Help.Score == 0 and c0.Help.Hint == "Zero" and c0.Tickle.Hint == nil, "Horns, Infamy 0: Help hint Zero", show(c0))
	local neutral = w:Hero(134, { Faction = "Neutral" })
	local _, cn = w:Offer(neutral)
	check(cn.Stat == "None" and cn.Help.Score == 0 and cn.Tickle.Score == 0 and cn.Help.Hint == "Neutral"
		and cn.Tickle.Hint == "Neutral", "Neutral: no score on either side (hint Neutral)", show(cn))
	local full = w:Hero(135, { Faction = "Halo", Data = { Deeds = { Day = C0F.DayIndex(w.Time), N = 6 } } })
	local _, cf = w:Offer(full)
	check(cf.Help.Score == 0 and cf.Help.Hint == "Full" and cf.Tickle.Hint == "Zero",
		"Halo with today's budget used up: Help shows 0, hint Full", show(cf))
	local T = FIN.Text
	check(type(T.HintFull) == "string" and type(T.HintZero) == "string" and type(T.HintNeutral) == "string"
		and string.format(T.ScoreDown, "Honor", 1) == "Honor -1", "hint texts and the minus line exist")
end)

------------------------------------------------------------------ picks: gifts and points
runGroup("picks", function()
	local w = finWorld()
	-- Halo + Help: 2 Jelly, Honor +1
	local h = w:Hero(141, { Faction = "Halo" })
	local _, c = w:Offer(h)
	local n0, m0, j0 = #w.Notices, #w.Metrics, w:Jelly(h)
	w:Pick(h, c.Id, "Help")
	local e = w:Ends(h)
	check(w:Jelly(h) == j0 + 2 and w.Data[h].Honor == 1, "Halo Help: +2 Jelly, Honor +1", show({ w:Jelly(h) - j0, w.Data[h].Honor }))
	check(#e == 1 and e[1].Id == c.Id and e[1].Pick == "Help" and e[1].Stat == "Honor" and e[1].Score == 1 and e[1].N == 2
		and e[1].Gold == 0, "FinisherEnd says what happened", show(e[1]))
	local lines = w:NoticesFor(h, n0)
	check(#lines == 1 and has(lines[1], CARD.Text.HelpDone) and has(lines[1], "Jelly") and has(lines[1], "Honor +1"),
		"one line: 'It hops home happy! · +Jelly ×2 · Honor +1'", show(lines))
	check(w:SoundsFor(h, n0)[1] == "None", "the pick line is silent (never QuestDone; the client plays the pick)",
		show(w:SoundsFor(h, n0)))
	check(w:MetricsOf(h, m0) == "FinisherPick:Halo:Halo", "metric FinisherPick (Halo, my faction Halo)", w:MetricsOf(h, m0))
	check(#w.PickedLog == 1 and w.PickedLog[1].Pick == "Help" and w.PickedLog[1].Kind == "SlimeKing", "Picked signal (Help, SlimeKing)")
	-- Halo + Tickle with Honor 5: 4 bank gold (source Finisher), Honor -1, the guide's off-side line
	local h2 = w:Hero(142, { Faction = "Halo", Data = { Honor = 5 } })
	local _, c2 = w:Offer(h2)
	local bank0, g0, n2 = w.Data[h2].BankGold or 0, #w.GoldCalls, #w.Notices
	w:Pick(h2, c2.Id, "Tickle")
	check((w.Data[h2].BankGold or 0) - bank0 == CARD.Tickle.Gold and w.Data[h2].Honor == 4,
		"Halo Tickle: +4 bank gold, Honor 5 -> 4 (A23-58)", show({ (w.Data[h2].BankGold or 0) - bank0, w.Data[h2].Honor }))
	check(#w.GoldCalls == g0 + 1 and w.GoldCalls[#w.GoldCalls].Source == "Finisher", "the gold's source is Finisher",
		tostring(w.GoldCalls[#w.GoldCalls] and w.GoldCalls[#w.GoldCalls].Source))
	local l2 = w:NoticesFor(h2, n2)
	check(#l2 == 2 and has(l2[1], CARD.Text.TickleDone) and has(l2[1], "+4 gold") and not has(l2[1], "Honor")
		and l2[2] == string.format(C0F.StoryQuests.Text.OffSideHalo, 1), "Tickle line + the off-side line (Honor -1)", show(l2))
	check(w:Ends(h2)[1].Score == -1 and w:Ends(h2)[1].Gold == CARD.Tickle.Gold, "FinisherEnd: Score -1, Gold 4", show(w:Ends(h2)[1]))
	-- Halo + Tickle at Honor 0: nothing to take (never below 0), the zero line
	local h3 = w:Hero(143, { Faction = "Halo" })
	local _, c3 = w:Offer(h3)
	local n3 = #w.Notices
	w:Pick(h3, c3.Id, "Tickle")
	check((w.Data[h3].Honor or 0) == 0 and w:NoticesFor(h3, n3)[2] == C0F.StoryQuests.Text.OffSideHaloZero .. " "
		.. C0F.StoryQuests.Text.LeanEvil,
		"Halo Tickle at Honor 0: stays 0, the zero line", show(w:NoticesFor(h3, n3)))
	-- Horns + Tickle: Infamy +1; Horns + Help: Infamy -1
	local r = w:Hero(144, { Faction = "Horns", Data = { Infamy = 2 } })
	local _, c4 = w:Offer(r)
	w:Pick(r, c4.Id, "Tickle")
	check(w.Data[r].Infamy == 3, "Horns Tickle: Infamy +1", w.Data[r].Infamy)
	local _, c5 = w:Offer(r)
	local n5 = #w.Notices
	w:Pick(r, c5.Id, "Help")
	check(w.Data[r].Infamy == 2 and w:NoticesFor(r, n5)[2] == string.format(C0F.StoryQuests.Text.OffSideHorns, 1),
		"Horns Help: Infamy -1 + the off-side line", show({ w.Data[r].Infamy, w:NoticesFor(r, n5) }))
	check(w:MetricsOf(r) == "FinisherPick:Horns:Horns,FinisherPick:Halo:Horns", "metrics: Tickle = Horns, Help = Halo",
		w:MetricsOf(r))
	-- Neutral: the gift only
	local nu = w:Hero(145, { Faction = "Neutral" })
	local _, c6 = w:Offer(nu)
	local jn = w:Jelly(nu)
	w:Pick(nu, c6.Id, "Help")
	check(w:Jelly(nu) == jn + 2 and (w.Data[nu].Honor or 0) == 0 and (w.Data[nu].Infamy or 0) == 0
		and w:Ends(nu)[1].Stat == "None", "Neutral Help: the Jelly only, no score", show(w:Ends(nu)[1]))
	check(w:MetricsOf(nu) == "FinisherPick:Halo:Neutral", "Neutral metric field 2", w:MetricsOf(nu))
	-- rank down: Honor 10 (Knight) -> 9 (Squire) says so
	local k = w:Hero(146, { Faction = "Halo", Data = { Honor = 10 } })
	local _, c7 = w:Offer(k)
	local n7 = #w.Notices
	w:Pick(k, c7.Id, "Tickle")
	local l7 = w:NoticesFor(k, n7)
	check(w.Data[k].Honor == 9 and l7[3] == C0F.StoryQuests.Text.RankDownHalo, "Honor 10 -> 9 crosses a rank: the rank-down line",
		show(l7))
	-- the points never reach the weekly ranking (AddStat only): no RankingService in this world, nothing warned
	check(#w.Warnings == 0, "no warnings", show(w.Warnings))
end)

runGroup("daily cap", function()
	-- the one daily cap is the deeds ledger (A23-86 decision 1, Config.Deeds.PerDay = 6), shared with every repeated deed
	local w = finWorld()
	local cap = C0F.Deeds.PerDay
	local h = w:Hero(151, { Faction = "Halo" })
	for _ = 1, cap do
		local _, c = w:Offer(h)
		w:Pick(h, c.Id, "Help")
	end
	check(w.Data[h].Honor == cap and w.Data[h].Deeds.N == cap, "six Help picks: Honor 6 (the day's cap)",
		show({ w.Data[h].Honor, w.Data[h].Deeds }))
	local _, cx = w:Offer(h)
	check(cx.Help.Score == 0, "the next card shows Help 0", cx.Help.Score)
	local j, nx = w:Jelly(h), #w.Notices
	w:Pick(h, cx.Id, "Help")
	local lx = w:NoticesFor(h, nx)
	check(w.Data[h].Honor == cap and w:Jelly(h) == j + 2 and w:Ends(h)[cap + 1].Score == 0, "past the cap: the Jelly, no point",
		show({ w.Data[h].Honor, w:Jelly(h) - j }))
	check(#lx == 2 and not has(lx[1], "Honor") and lx[2] == FIN.Text.HintFull, "past the cap: no points line + 'No more points today'",
		show(lx))
	-- an off-side drop is not limited by the cap (and uses none of it)
	local _, c7 = w:Offer(h)
	w:Pick(h, c7.Id, "Tickle")
	check(w.Data[h].Honor == cap - 1 and w.Data[h].Deeds.N == cap, "a Tickle still drops Honor 6 -> 5 at the cap",
		show({ w.Data[h].Honor, w.Data[h].Deeds.N }))
	-- the next KST day: open again
	local day = C0F.DayIndex(w.Time)
	w:Advance(86400)
	check(C0F.DayIndex(w.Time) == day + 1, "(a day later)")
	local _, c8 = w:Offer(h)
	check(c8.Help.Score == 1, "the next day the card shows Help +1 again", c8.Help.Score)
	w:Pick(h, c8.Id, "Help")
	check(w.Data[h].Honor == cap and w.Data[h].Deeds.N == 1 and w.Data[h].Deeds.Day == day + 1,
		"the next day: Honor +1, the ledger restarts", show(w.Data[h].Deeds))
	-- the cap is shared: another deed (Deeds.Add from a choice card, the board, ...) takes from the same day
	local h2 = w:Hero(152, { Faction = "Halo" })
	local D = w.Deeds
	check(select(2, D.Add(h2, "Good", 4)) == 4 and D.Left(h2) == 2, "(another deed used 4 of 6)", D.Left(h2))
	local _, c9 = w:Offer(h2)
	check(c9.Help.Score == 1, "a card after another deed: Help +1 while points are left", c9.Help.Score)
	w:Pick(h2, c9.Id, "Help")
	check(select(2, D.Add(h2, "Good", 3)) == 1 and D.Left(h2) == 0, "the card and the other deed share one day of 6", D.Left(h2))
	local _, c10 = w:Offer(h2)
	check(c10.Help.Score == 0 and c10.Help.Hint == "Full", "then the card shows Help 0, hint Full", show(c10.Help))
end)

------------------------------------------------------------------ the remote's rules
runGroup("pick validation", function()
	local w = finWorld()
	local h = w:Hero(161, { Faction = "Halo" })
	local _, c = w:Offer(h)
	local j = w:Jelly(h)
	w:Pick(h, c.Id + 1, "Help")
	w:Pick(h, c.Id, "Shake")
	w:Pick(h, tostring(c.Id), "Help")
	w:Pick(h, 0 / 0, "Help")
	w:Pick(h, c.Id, "Help", "extra")
	w:Pick(h, c.Id)
	check(#w:Ends(h) == 0 and w:Jelly(h) == j, "a wrong id / option / type / NaN / extra arg / no option: ignored", #w:Ends(h))
	-- someone else's card id
	local o = w:Hero(162, { Faction = "Halo" })
	w:Pick(o, c.Id, "Help")
	check(#w:Ends(o) == 0 and w:Jelly(o) == 0, "another player cannot pick my card")
	-- the right pick, then a second pick: once only
	w:Pick(h, c.Id, "Help")
	w:Pick(h, c.Id, "Tickle")
	check(#w:Ends(h) == 1 and w:Jelly(h) == j + 2 and (w.Data[h].BankGold or 0) == 0, "picked once; a second pick is ignored",
		show({ #w:Ends(h), w:Jelly(h) - j }))
	-- rate limit: two pick calls inside 0.3 s -> the second one is dropped
	local _, c2 = w:Offer(h)
	w:Advance(0.31)
	w.Net.Get("FinisherPick").OnServerEvent:Fire(h, c2.Id + 5, "Help")
	w.Net.Get("FinisherPick").OnServerEvent:Fire(h, c2.Id, "Help")
	w:Flush()
	check(#w:Ends(h) == 1, "a pick right after another call (0.3 s) is dropped", #w:Ends(h))
	w:Pick(h, c2.Id, "Help")
	check(#w:Ends(h) == 2, "(and goes through after the gap)")
end)

runGroup("one card at a time", function()
	local w = finWorld()
	local p = w:Hero(171)
	w:King()
	w:Swing(p)
	local first = w:Cards(p)
	w:King()
	w:Swing(p)
	check(#w:Cards(p) == 1 and #w.Kills == 2, "a second king kill while the card is open: no new card (both kills paid)",
		show({ #w:Cards(p), #w.Kills }))
	w:Pick(p, first[1].Id, "Help")
	w:King()
	w:Swing(p)
	local all = w:Cards(p)
	check(#all == 2 and all[2].Id == first[1].Id + 1, "after the pick, the next kill: a new card (next Id)", show(all))
	check(w.Fin.DebugOffer(p) == false, "DebugOffer while a card is open: false")
end)

runGroup("time", function()
	local w = finWorld()
	local h = w:Hero(181, { Faction = "Halo", Data = { Honor = 3 } })
	local _, c = w:Offer(h)
	local j, m0 = w:Jelly(h), #w.Metrics
	-- inside the network grace (10.5 s): still taken
	w:Advance(FIN.Seconds + 0.2)
	w:Pick(h, c.Id, "Help")
	check(#w:Ends(h) == 1 and w:Ends(h)[1].Pick == "Help", "a pick 10.5 s after the card (inside the 1 s grace): taken", show(w:Ends(h)))
	-- not picked: the card ends at 11 s as None (no gift, no points), FinisherEnd + metric None
	local _, c2 = w:Offer(h)
	local honor, j2 = w.Data[h].Honor, w:Jelly(h)
	w:Advance(FIN.Seconds + FIN.Grace - 0.5)
	check(#w:Ends(h) == 1, "(still open at 10.5 s)")
	w:Advance(0.6)
	local e = w:Ends(h)
	check(#e == 2 and e[2].Id == c2.Id and e[2].Pick == "None" and e[2].Score == 0 and e[2].N == 0 and e[2].Gold == 0,
		"not picked: ends at 11 s as None", show(e[2]))
	check(w.Data[h].Honor == honor and w:Jelly(h) == j2, "None: no gift, no points")
	check(w:MetricsOf(h, m0) == "FinisherPick:Halo:Halo,FinisherPick:None:Halo", "metric None for the unpicked card", w:MetricsOf(h, m0))
	check(w.PickedLog[#w.PickedLog].Pick == "None", "Picked signal None")
	-- a pick after the end: ignored
	w:Pick(h, c2.Id, "Help")
	check(#w:Ends(h) == 2 and w:Jelly(h) == j2, "a pick after the card ended: ignored")
	-- a late pick that arrives before the timer runs (clock past Ends + Grace): refused, the timer ends it
	local _, c3 = w:Offer(h)
	w.Clock += FIN.Seconds + FIN.Grace + 0.2
	w.Time += FIN.Seconds + FIN.Grace + 0.2
	w.Net.Get("FinisherPick").OnServerEvent:Fire(h, c3.Id, "Help")
	w:Flush()
	check(#w:Ends(h) == 2, "a pick past 11 s is refused even before the timer ran", #w:Ends(h))
	w:Advance(0)
	check(#w:Ends(h) == 3 and w:Ends(h)[3].Pick == "None", "(the timer then ends it as None)")
	local _ = j
end)

runGroup("leaving", function()
	local w = finWorld()
	local h = w:Hero(191, { Faction = "Halo" })
	local _, c = w:Offer(h)
	w.Players.PlayerRemoving:Fire(h)
	check(w:MetricsOf(h) == "FinisherPick:None:Halo" and w.PickedLog[1].Pick == "None", "leaving with an open card: None (metric, signal)",
		w:MetricsOf(h))
	w:Remove(h)
	w:Advance(FIN.Seconds + FIN.Grace + 1)
	check(#w.Metrics == 1 and w:Jelly(h) == 0, "the timer later does nothing more", #w.Metrics)
	w:Pick(h, c.Id, "Help")
	check(w:Jelly(h) == 0, "no gift after leaving")
end)

runGroup("jelly full", function()
	local cap = C0F.Loot.ItemCap
	local w = finWorld()
	-- one short of full: 1 Jelly + 2 gold
	local a = w:Hero(201, { Faction = "Halo", Data = { Items = { Jelly = cap - 1 } } })
	local _, c = w:Offer(a)
	w:Pick(a, c.Id, "Help")
	local e = w:Ends(a)[1]
	check(w:Jelly(a) == cap and e.N == 1 and e.Gold == C0F.Loot.Items.Jelly.Sell and (w.Data[a].BankGold or 0) == e.Gold,
		"one room left: 1 Jelly + the other at its sell price (2 gold)", show(e))
	check(w.Data[a].Honor == 1, "(the point still comes)")
	-- full: 0 Jelly + 4 gold (the same size as Tickle)
	local b = w:Hero(202, { Faction = "Halo", Data = { Items = { Jelly = cap } } })
	local _, c2 = w:Offer(b)
	w:Pick(b, c2.Id, "Help")
	local e2 = w:Ends(b)[1]
	check(e2.N == 0 and e2.Gold == CARD.Tickle.Gold and (w.Data[b].BankGold or 0) == CARD.Tickle.Gold, "a full bag: all of it as gold (4)",
		show(e2))
	-- GrantItem throws: paid as gold, warned
	local f = finWorld({ GrantFails = true })
	local fp = f:Hero(203, { Faction = "Halo" })
	local _, c3 = f:Offer(fp)
	f:Pick(fp, c3.Id, "Help")
	check(f:Ends(fp)[1].Gold == CARD.Tickle.Gold and #f.Warnings >= 1, "GrantItem failing: paid as gold, warned", show(f.Warnings))
	f.AllowWarn = "GrantItem"
	-- A23-75 servers return what was really added (here one more, as if boosted): FinisherEnd shows that amount
	local r = finWorld({ GoldReturns = function(n) return n + 1 end })
	local rp = r:Hero(204, { Faction = "Horns" })
	local _, c4 = r:Offer(rp)
	r:Pick(rp, c4.Id, "Tickle")
	check(r:Ends(rp)[1].Gold == CARD.Tickle.Gold + 1, "AddBankGold returning the added amount: that is shown", show(r:Ends(rp)[1]))
end)

finish()
