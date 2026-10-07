-- stat_service_offline.luau : A23-69 stat points, stage 2 (docs/design/stat_points_2026-10-07.md §2, §3-3, §5-2, §6).
-- tools/test_stat_service.py binds the unarmed suite's sources (Config, Util, CombatService, LootService,
-- StoryQuestService, PvPService + extracts), STAT_SOURCE (StatService) and MAXHP_EXTRACT (PlayerService.computeMaxHealth)
-- in front of dev2_kit.luau and dev2_combat_world.luau. Players face -Z at the origin; the switch
-- Config.Features.StatPoints is set per world (stat = true).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())

-- a world with StatService; o.On = the StatPoints switch
local function statWorld(o)
	o = o or {}
	local w = bareWorld({ Hit = o.Hit })
	w.Config.Features.StatPoints = o.On ~= false
	function w:Hero(id, jo)
		jo = jo or {}
		jo.Data = jo.Data or {}
		jo.Data.Story = jo.Data.Story or { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = { Migrated = true } }
		return self:Join(id, jo)
	end
	function w:Act(p, ...)
		self:Advance(0.2) -- RateLimits.StatAction 0.15
		self.Net.Get("StatAction").OnServerEvent:Fire(p, ...)
		self:Flush()
	end
	function w:Attrs(p)
		return { A = p:GetAttribute("StatAtk"), H = p:GetAttribute("StatHp"), Free = p:GetAttribute("StatFree"),
			Auto = p:GetAttribute("AutoStat") }
	end
	function w:Level(p, level)
		self.PS.SetStat(p, "Level", level)
		self.Registry.ProgressionService.LeveledUp:Fire(p, level)
		self:Flush()
	end
	return w
end

local function texts(w, p, from)
	return w:NoticesFor(p, from)
end
local function hasText(list, text)
	for _, t in list do if t == text then return true end end
	return false
end
local function refreshes(w, p, from)
	local n, full = 0, false
	for i = (from or 0) + 1, #w.Refreshed do
		if w.Refreshed[i].P == p then
			n += 1
			if w.Refreshed[i].Full ~= false then full = true end
		end
	end
	return n, full
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

------------------------------------------------------------------ the switch off: nothing changes
runGroup("switch off", function()
	check(C0.Features.StatPoints == false, "Config.Features.StatPoints = false (beta: switched on at the 10/20 check)",
		show(C0.Features))
	local w = statWorld({ On = false })
	local p, d = w:Hero(1, { Level = 10, Tier = 2, Mask = 3, Data = { Stats = { Auto = false, Order = "AAAA" } } })
	local at = w:Attrs(p)
	check(at.A == nil and at.H == nil and at.Free == nil and at.Auto == nil, "no stat attributes at all", show(at))
	local n0 = #w.Notices
	w:Act(p, "add", "A")
	w:Act(p, "reset")
	w:Act(p, "auto", true)
	check(d.Stats.Order == "AAAA" and d.Stats.Auto == false and #w.Notices == n0, "the remote does nothing",
		show({ d.Stats, #w.Notices - n0 }))
	local hit = w.Combat.ComputeMonsterHit(p, false)
	local plain = C0.WeaponDamage(2, 10, 0) * C0.Classes.Warrior.Damage * (1 + w.Combat.GetDamageBonus(p, nil))
		* w.Combat.GetDamageMult(p, nil)
	check(near(hit, plain), "a monster hit is the plain formula", show({ hit, plain }))
	check(C0.StatMaxHealth(30, "Halo", "Warrior", 40) == C0.MaxHealth(30, "Halo", "Warrior"),
		"Config.StatMaxHealth = Config.MaxHealth", show({ C0.StatMaxHealth(30, "Halo", "Warrior", 40), C0.MaxHealth(30, "Halo", "Warrior") }))
	w:Level(p, 11)
	check(p:GetAttribute("StatAtk") == nil and #w:FxOf("Stat", 0) == 0, "a level-up writes no stat attribute, no Fx")
end)

------------------------------------------------------------------ the attributes follow the save
runGroup("attributes", function()
	local w = statWorld()
	local auto = w:Hero(1, { Level = 10 })
	local at = w:Attrs(auto)
	check(at.A == 4 and at.H == 5 and at.Free == 0 and at.Auto == true, "Lv10 Warrior, Auto: HAHAHAHAH = A4 H5, 0 free",
		show(at))
	local archer = w:Hero(2, { Level = 10, Class = "Archer" })
	at = w:Attrs(archer)
	check(at.A == 5 and at.H == 4, "Lv10 Archer, Auto: AHAHAHAHA = A5 H4", show(at))
	local hand = w:Hero(3, { Level = 10, Data = { Stats = { Auto = false, Order = "AAH" } } })
	at = w:Attrs(hand)
	check(at.A == 2 and at.H == 1 and at.Free == 6 and at.Auto == false, "by hand: Order AAH at Lv10 = A2 H1, 6 free", show(at))
	local lv1 = w:Hero(4, { Level = 1 })
	at = w:Attrs(lv1)
	check(at.A == 0 and at.H == 0 and at.Free == 0, "Lv1: no point yet", show(at))
	local junk = w:Hero(5, { Level = 6, Data = { Stats = { Auto = false, Order = "AZ" } } })
	at = w:Attrs(junk)
	check(at.A == 1 and at.H == 0 and at.Free == 4, "a later stage's letter (Z) keeps its point free", show(at))
end)

------------------------------------------------------------------ add / add5 / reset / auto
runGroup("actions", function()
	local w = statWorld()
	local p, d = w:Hero(1, { Level = 10, Tier = 2, Mask = 3, Data = { Stats = { Auto = false, Order = "" } } })
	local r0, n0 = #w.Refreshed, #w.Notices
	local power0 = w.Config.CombatPowerOf(p) -- the world's Config: the switch on
	w:Act(p, "add", "A")
	check(d.Stats.Order == "A" and p:GetAttribute("StatAtk") == 1 and p:GetAttribute("StatFree") == 8,
		"[+] Attack: Order A, StatAtk 1, 8 free", show({ d.Stats.Order, w:Attrs(p) }))
	local n, full = refreshes(w, p, r0)
	check(n == 1 and not full, "the character is re-read once, never fully healed (RefreshCharacter(p, false))", show({ n, full }))
	local power1 = w.Config.CombatPowerOf(p)
	check(power1 > power0 and hasText(texts(w, p, n0), string.format(C0.Power.Text.Change, w.Util.FormatNumber(power0),
		w.Util.FormatNumber(power1))), "a 'Power X → Y' line", show({ power0, power1, texts(w, p, n0) }))
	local fx = w:FxOf("Stat", 0)
	check(#fx >= 1 and fx[#fx].Player == p and fx[#fx].Data.Kind == "Action" and fx[#fx].Data.From == power0
		and fx[#fx].Data.To == power1, "Fx Stat { Kind = Action, From, To }", show(fx[#fx] and fx[#fx].Data))
	w:Act(p, "add5", "H")
	check(d.Stats.Order == "AHHHHH" and p:GetAttribute("StatHp") == 5 and p:GetAttribute("StatFree") == 3,
		"[+5] Health: 5 points", show({ d.Stats.Order, w:Attrs(p) }))
	w:Act(p, "add5", "H")
	check(d.Stats.Order == "AHHHHHHHH" and p:GetAttribute("StatFree") == 0, "[+5] with 3 free places 3", d.Stats.Order)
	local nFull, fFull = #w.Notices, #w:FxOf("Stat", 0)
	w:Act(p, "add", "A")
	check(d.Stats.Order == "AHHHHHHHH" and #w.Notices == nFull and #w:FxOf("Stat", 0) == fFull, "no free point: nothing (no line, no Fx)",
		show({ d.Stats.Order, #w.Notices - nFull, #w:FxOf("Stat", 0) - fFull }))
	-- reset: free, at most once every 3 s
	w:Act(p, "reset")
	check(d.Stats.Order == "" and w:Attrs(p).A == 0 and w:Attrs(p).H == 0 and w:Attrs(p).Free == 9, "Reset: every point free",
		show({ d.Stats.Order, w:Attrs(p) }))
	w:Act(p, "add", "A")
	w:Act(p, "reset")
	check(d.Stats.Order == "A", "a second reset inside 3 s waits", d.Stats.Order)
	w:Advance(3)
	w:Act(p, "reset")
	check(d.Stats.Order == "", "after 3 s it resets again", d.Stats.Order)
	-- Auto on: the picks go back to the class pattern; [+] / [+5] / Reset are refused while it is on
	w:Act(p, "add5", "A")
	w:Act(p, "auto", true)
	check(d.Stats.Auto == true and d.Stats.Order == "" and w:Attrs(p).A == 4 and w:Attrs(p).H == 5 and w:Attrs(p).Auto == true,
		"Auto on: Order cleared, the class pattern (A4 H5)", show({ d.Stats, w:Attrs(p) }))
	w:Act(p, "add", "A")
	w:Act(p, "reset")
	check(d.Stats.Order == "" and w:Attrs(p).A == 4, "with Auto on [+] and Reset do nothing", show({ d.Stats, w:Attrs(p) }))
	-- an odd save: Auto on with old picks left in Order: Reset still waits for Auto off (Auto and the picks stay)
	local odd, od = w:Hero(9, { Level = 10, Data = { Stats = { Auto = true, Order = "AAA" } } })
	local fOdd = #w:FxOf("Stat", 0)
	w:Act(odd, "reset")
	w:Act(odd, "add", "H")
	check(od.Stats.Auto == true and od.Stats.Order == "AAA" and #w:FxOf("Stat", 0) == fOdd,
		"Auto on with picks left in Order: Reset / [+] change nothing", show({ od.Stats, #w:FxOf("Stat", 0) - fOdd }))
	-- Auto off: the placed letters become the picks, not one number moves; the first time a hint, once
	local before = w:Attrs(p)
	local n1 = #w.Notices
	w:Act(p, "auto", false)
	local after = w:Attrs(p)
	check(d.Stats.Auto == false and d.Stats.Order == "HAHAHAHAH" and after.A == before.A and after.H == before.H
		and after.Free == 0, "Auto off: Order = what Auto placed, the same numbers", show({ d.Stats, after }))
	check(hasText(texts(w, p, n1), C0.Stats.Text.FirstManual) and d.Story.First.StatManual == true,
		"the first time: 'Tap + to pick. Reset is free!'", show(texts(w, p, n1)))
	w:Act(p, "auto", true)
	local n2 = #w.Notices
	w:Act(p, "auto", false)
	check(not hasText(texts(w, p, n2), C0.Stats.Text.FirstManual), "never twice", show(texts(w, p, n2)))
	local n3 = #w.Notices
	w:Act(p, "auto", false)
	check(#w.Notices == n3, "Auto off when already off: nothing", #w.Notices - n3)
end)

------------------------------------------------------------------ refusals
runGroup("refusals", function()
	local w = statWorld({ Hit = true })
	local p, d = w:Hero(1, { Level = 10, Faction = "Halo", Tier = 2, Mask = 3, Data = { Stats = { Auto = false, Order = "" } } })
	local function same(label)
		check(d.Stats.Order == "" and d.Stats.Auto == false, label, show(d.Stats))
	end
	for _, args in { { "hack", "A" }, { "add", "C" }, { "add", "a" }, { "add", 1 }, { "add", 0 / 0 }, { "add", {} },
		{ "add" }, { "add5", "Z" }, { "auto", "true" }, { "auto", 1 }, { 5, "A" }, { nil, "A" } } do
		w:Act(p, args[1], args[2])
	end
	same("bad ops and args do nothing (only A / H, a boolean for auto)")
	w:Act(p, "add", "A", "extra")
	same("an extra argument: nothing")
	w:Act(p, "reset", "A")
	same("reset with an argument: nothing")
	-- the rate limit: two presses inside 0.15 s
	w:Advance(0.2)
	w.Net.Get("StatAction").OnServerEvent:Fire(p, "add", "A")
	w.Net.Get("StatAction").OnServerEvent:Fire(p, "add", "A")
	w:Flush()
	check(d.Stats.Order == "A", "two presses at once: one point (RateLimits.StatAction)", d.Stats.Order)
	-- PvP combat tag, kaiju, grudge sack: refused with the class change's words; dead: silently
	local foe = w:Hero(2, { Level = 10, Faction = "Horns", Tier = 2, Mask = 3 })
	w.Combat.DamagePlayer(p, 1, foe)
	local n0 = #w.Notices
	w:Act(p, "add", "H")
	check(d.Stats.Order == "A" and hasText(texts(w, p, n0), C0.Text.TravelBlockedCombat), "in PvP combat: refused",
		show({ d.Stats.Order, texts(w, p, n0) }))
	w:Advance(C0.PvP.CombatTagTime + 1)
	w.KaijuOf[p] = "Active"
	n0 = #w.Notices
	w:Act(p, "add", "H")
	check(d.Stats.Order == "A" and hasText(texts(w, p, n0), C0.Text.BlockedKaiju), "a kaiju: refused", texts(w, p, n0))
	w.KaijuOf[p] = nil
	w.Sacks[p] = true
	n0 = #w.Notices
	w:Act(p, "reset")
	check(d.Stats.Order == "A" and hasText(texts(w, p, n0), C0.Text.BlockedSack), "carrying the grudge sack: refused",
		texts(w, p, n0))
	w.Sacks[p] = nil
	local hum = w.Util.GetHumanoid(p)
	hum.Health = 0
	n0 = #w.Notices
	w:Act(p, "add", "H")
	check(d.Stats.Order == "A" and #w.Notices == n0, "dead: refused silently", show({ d.Stats.Order, #w.Notices - n0 }))
	hum.Health = hum.MaxHealth
	w:Act(p, "add", "H")
	check(d.Stats.Order == "AH", "alive and calm again: works", d.Stats.Order)
	-- not ready / no class yet
	w.Ready[p] = false
	w:Act(p, "add", "H")
	check(d.Stats.Order == "AH", "not ready: nothing", d.Stats.Order)
	w.Ready[p] = true
	p:SetAttribute("ClassChosen", false)
	w:Act(p, "add", "H")
	check(d.Stats.Order == "AH", "no class chosen: nothing", d.Stats.Order)
end)

------------------------------------------------------------------ level / class signals and the lines of §6
runGroup("levels", function()
	local w = statWorld()
	local p, d = w:Hero(1, { Level = 4, Tier = 2, Mask = 3 })
	local n0 = #w.Notices
	w:Level(p, 5)
	check(w:Attrs(p).H == 2 and w:Attrs(p).A == 2 and hasText(texts(w, p, n0), C0.Stats.Text.FirstPoint)
		and d.Story.First.StatPoint == true, "the first point after the first [Claim]: placed, 'New Stat Point!' once",
		show({ w:Attrs(p), texts(w, p, n0) }))
	local fx = w:FxOf("Stat", 0)
	check(#fx >= 1 and fx[#fx].Data.Kind == "First", "Fx Stat { Kind = First } (the power chip glows)", show(fx[#fx] and fx[#fx].Data))
	local before = w.Config.CombatPowerOf(p)
	n0 = #w.Notices
	w:Level(p, 6) -- HAHAH -> the 5th letter H
	local after = w.Config.CombatPowerOf(p)
	local want = string.format(C0.Stats.Text.LevelAuto, "+1 Health", w.Util.FormatNumber(before), w.Util.FormatNumber(after))
	check(hasText(texts(w, p, n0), want), "Auto level-up: '+1 Health · Power X → Y'", show(texts(w, p, n0)))
	n0 = #w.Notices
	before = w.Config.CombatPowerOf(p)
	w:Level(p, 9) -- +3 points: A, H, A
	after = w.Config.CombatPowerOf(p)
	want = string.format(C0.Stats.Text.LevelAuto, "+2 Attack +1 Health", w.Util.FormatNumber(before), w.Util.FormatNumber(after))
	check(hasText(texts(w, p, n0), want), "three levels at once: '+2 Attack +1 Health · Power …'", show(texts(w, p, n0)))
	-- by hand: the new points wait
	local m, md = w:Hero(2, { Level = 4, Data = { Stats = { Auto = false, Order = "AAA" } } })
	n0 = #w.Notices
	w:Level(m, 5)
	check(w:Attrs(m).Free == 1 and hasText(texts(w, m, n0), "+1 Stat Point! Tap Power."), "by hand: '+1 Stat Point! Tap Power.'",
		show({ w:Attrs(m), texts(w, m, n0) }))
	n0 = #w.Notices
	w:Level(m, 7)
	check(w:Attrs(m).Free == 3 and hasText(texts(w, m, n0), string.format(C0.Stats.Text.LevelPoints, 3)),
		"by hand, two levels later: '+3 Stat Points! Tap Power.' (the free points)", show({ w:Attrs(m), texts(w, m, n0) }))
	-- before the first [Claim]: numbers only, no line
	local q = w:Hero(3, { Level = 2, Tutorial = 2 })
	n0 = #w.Notices
	w:Level(q, 3)
	check(w:Attrs(q).H == 1 and w:Attrs(q).A == 1 and #texts(w, q, n0) == 0, "before the first [Claim]: placed, no line",
		show({ w:Attrs(q), texts(w, q, n0) }))
	-- a level drop keeps Order: growing back re-places the same picks
	local r, rd = w:Hero(4, { Level = 10, Data = { Stats = { Auto = false, Order = "AAHHAHAAA" } } })
	w.PS.SetStat(r, "Level", 1)
	w.Registry.ProgressionService.LevelReset:Fire(r)
	w:Flush()
	check(rd.Stats.Order == "AAHHAHAAA" and w:Attrs(r).A == 0 and w:Attrs(r).H == 0, "a level reset: Order kept, no point at Lv1",
		show({ rd.Stats.Order, w:Attrs(r) }))
	w:Level(r, 6)
	check(w:Attrs(r).A == 3 and w:Attrs(r).H == 2 and w:Attrs(r).Free == 0, "back at Lv6: AAHHA again (A3 H2)", show(w:Attrs(r)))
	w.PS.SetStat(r, "Level", 1)
	w.PS.SetStat(r, "Rebirths", 1)
	w.Registry.ProgressionService.Rebirthed:Fire(r, 1)
	w:Flush()
	check(w:Attrs(r).A == 0 and w:Attrs(r).H == 0 and rd.Stats.Order == "AAHHAHAAA", "a rebirth: Lv1, the picks kept, no extra point",
		show({ w:Attrs(r), rd.Stats.Order }))
	-- a class change re-reads the pattern
	local c = w:Hero(5, { Level = 10 })
	w.PS.SetStat(c, "Class", "Archer")
	w.Registry.ClassService.ClassChanged:Fire(c, "Archer")
	w:Flush()
	check(w:Attrs(c).A == 5 and w:Attrs(c).H == 4, "Warrior -> Archer (Auto): AH pattern, A5 H4", show(w:Attrs(c)))
	-- a level-up while in PvP combat still places (never blocked)
	local f = w:Hero(6, { Level = 4, Faction = "Halo" })
	local foe = w:Hero(7, { Level = 4, Faction = "Horns" })
	w.Combat.DamagePlayer(f, 1, foe)
	w:Level(f, 5)
	check(w:Attrs(f).A + w:Attrs(f).H == 4, "in combat a level-up still places its point", show(w:Attrs(f)))
end)

------------------------------------------------------------------ the numbers: monster hits, max HP, PvP
runGroup("numbers", function()
	local w = statWorld()
	local p, d = w:Hero(1, { Level = 30, Tier = 3, Mask = 7, Data = { Stats = { Auto = false, Order = "" } } })
	local base = w.Combat.ComputeMonsterHit(p, false)
	for _ = 1, 4 do w:Act(p, "add5", "A") end -- 20 Attack
	local withA = w.Combat.ComputeMonsterHit(p, false)
	check(p:GetAttribute("StatAtk") == 20 and near(withA, base * 1.2), "20 Attack: every monster hit x1.20", show({ base, withA }))
	local punch = w.Combat.ComputeMonsterHit(p, false, { Damage = 1 })
	check(punch > 0 and near(punch / base, withA / base / C0.Classes.Warrior.Damage), "a basic swing shape too",
		show({ punch, base }))
	-- max HP: StatMaxHealth, and PlayerService.computeMaxHealth multiplies the Justice health mult on top
	local CW = w.Config -- the switch on
	local mh = CW.StatMaxHealth(30, "Halo", "Warrior", 40)
	check(mh == math.floor(CW.MaxHealth(30, "Halo", "Warrior") * 1.3), "40 Health: max HP x1.30", show({ mh, CW.MaxHealth(30, "Halo", "Warrior") }))
	local compute = execute("PlayerService.computeMaxHealth", MAXHP_EXTRACT, nativeEnv(), CW,
		function(pl, key, default) return pl[key] or default end, function() return 1.25 end)
	local fake = { Level = 30, Faction = "Halo", Class = "Warrior" }
	function fake:GetAttribute(k) return ({ StatAtk = 0, StatHp = 40 })[k] end
	local v = compute(fake)
	check(v == math.floor(mh * 1.25), "computeMaxHealth = StatMaxHealth(Health points) x Justice health mult",
		show({ v, math.floor(mh * 1.25) }))
	-- PvP: inside the old 0.8-1.5 clamp, the victim's Health once (base up, ratio down)
	local function duel(aA, aH, vA, vH, aTier, vTier, level)
		local w2 = statWorld({ Hit = true })
		local function order(a, h) return string.rep("A", a) .. string.rep("H", h) end
		local att = w2:Hero(10, { Level = level, Faction = "Halo", Tier = aTier, Mask = 255,
			Data = { Stats = { Auto = false, Order = order(aA, aH) } } })
		local vic = w2:Hero(11, { Level = level, Faction = "Horns", Tier = vTier, Mask = 255,
			Data = { Stats = { Auto = false, Order = order(vA, vH) } } })
		local shape = { Damage = 1 }
		local hit = w2.Combat.ComputePvPHit(att, vic, shape)
			/ ((1 + w2.Combat.GetDamageBonus(att, vic)) * w2.Combat.GetDamageMult(att, vic, shape))
		local vMax = w2.Config.StatMaxHealth(level, "Horns", "Warrior", vH)
		return vMax / hit
	end
	local even = duel(10, 10, 10, 10, 3, 3, 21)
	local none = duel(0, 0, 0, 0, 3, 3, 21)
	check(near(even, none) and near(none, 10), "equal builds, equal weapons: 10 hits like today", show({ even, none }))
	local tanky = duel(20, 0, 0, 40, 3, 3, 61)
	local thin = duel(20, 0, 0, 0, 3, 3, 61)
	check(tanky > thin + 1, "the victim's Health makes it last longer (not only a bigger hit base)", show({ tanky, thin }))
	local rnd = w.Util.Random
	local bad = {}
	for i = 1, 300 do
		local level = rnd:NextInteger(2, 100)
		local pts = level - 1
		local aA = rnd:NextInteger(0, pts)
		local aH = rnd:NextInteger(0, pts - aA)
		local vA = rnd:NextInteger(0, pts)
		local vH = rnd:NextInteger(0, pts - vA)
		local t1, t2 = rnd:NextInteger(1, 7), rnd:NextInteger(1, 7)
		local hits = duel(aA, aH, vA, vH, t1, t2, level)
		if hits < 10 / 1.5 - 1e-6 or hits > 10 / 0.8 + 1e-6 then table.insert(bad, { i, hits }) end
	end
	check(#bad == 0, "300 random builds / weapons / levels: 6.67-12.5 hits to knock out", show(bad[1]))
end)

finish()
