-- commission_offline.luau : A23-86 decision 2 - Otto's commissions (CommissionService, 게임성 개발 3, 2026-10-09).
-- tools/test_commission.py binds CONFIG_SOURCE, UTIL_SOURCE, DEEDS_SOURCE, CARD_SOURCE and COMM_SOURCE in front of
-- dev2_kit.luau + dev3_world.luau; this file follows. CommissionService, ChoiceCard and Deeds run from source;
-- ShopService.CanBuyWeapon, ClassService.GetClass and ProgressionService.SpendGold are small doubles here.

local NOON = 1789959600

local function commWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local on = o.Feature ~= false
	o.EditConfig = function(c) c.Features.Commission = on end
	local w = dev3World(o)
	w.Near = true
	w.Reg.ShopService = { CanBuyWeapon = function(p) return w.Near == true end }
	w.Reg.ClassService.GetClass = function(p) return "Warrior" end
	-- the real SpendGold: carried gold first, then the vault; false when the total is short
	local prog = w.Reg.ProgressionService
	w.Spent = {}
	function prog.SpendGold(p, amount, reason)
		amount = math.ceil(amount)
		local d = w.Data[p]
		local carried, bank = d.CarriedGold or 0, d.BankGold or 0
		if carried + bank < amount then return false end
		local fromCarried = math.min(carried, amount)
		w.PS.SetStat(p, "CarriedGold", carried - fromCarried)
		w.PS.SetStat(p, "BankGold", bank - (amount - fromCarried))
		table.insert(w.Spent, { P = p, N = amount, Reason = reason })
		return true
	end
	w:Service("Deeds", DEEDS_SOURCE)
	w:Service("ChoiceCard", CARD_SOURCE)
	w:Service("CommissionService", COMM_SOURCE)
	w:InitStart({ "Deeds", "ChoiceCard", "CommissionService" })
	return w
end

local function hero(w, id, faction, level, extra)
	local data = { Faction = faction, Class = "Warrior", ClassChosen = true, Level = level, WeaponTier = 3, WeaponOwnedMask = 7,
		BankGold = 0, CarriedGold = 0, Items = {} }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function order(w, p, ...) w:Remote("Commission", p, ...) end
local function lastFx(w, kind, p)
	local list = w:FxOf(kind, p)
	return list[#list] and list[#list].Data
end
local function notices(w, p) return table.concat(w:NoticesFor(p), " | ") end
local function fullKit(tier)
	if tier == 4 then return { BruteHorn = 10, GoblinTooth = 20 } end
	if tier == 5 then return { KnightCrest = 12, Bone = 30 } end
	return { KnightCrest = 30, Bone = 60, CaptainBadge = 1 }
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local K = C.Commission
	check(C.Features.Commission == false and not C.FeatureOn("Commission"), "the switch is off until the Forge window has its row", tostring(C.Features.Commission))
	check(K.Orders[4].Gold == 3000 and K.Orders[4].Items.BruteHorn == 10 and K.Orders[4].Items.GoblinTooth == 20
		and K.Orders[5].Gold == 10000 and K.Orders[6].Gold == 30000, "T4: 3,000 + 10 Brute Horn + 20 Goblin Tooth; T5 10,000; T6 30,000", show(K.Orders))
	check(K.Orders[6].Items.CaptainBadge == 1 and K.Orders[6].Items.KnightCrest == 30 and K.Orders[6].Items.Bone == 60 and K.Orders[5].Items.CaptainBadge == nil,
		"T6 also asks 1 Captain's Badge (Captain Clatter's weekly gift); T5 does not", show(K.Orders[6].Items))
	for tier = 4, 6 do
		check(K.Orders[tier].Gold == C.Weapons[tier].Price, "T" .. tier .. ": the gold is the weapon's own Price", show({ K.Orders[tier].Gold, C.Weapons[tier].Price }))
		for id, n in K.Orders[tier].Items do
			check(C.Loot.Items[id] ~= nil and C.Loot.Items[id].Kind == "Material" and n >= 1, "T" .. tier .. ": " .. id .. " is a material", show(C.Loot.Items[id]))
		end
		check(string.find(C.WeaponInfo[tier].Source, "Forge commission", 1, true) ~= nil, "T" .. tier .. ": the weapon's source names the commission", C.WeaponInfo[tier].Source)
	end
	check(C.Weapons[4].MinLevel == 12 and C.Weapons[5].MinLevel == 20 and C.Weapons[6].MinLevel == 30, "levels 12 / 20 / 30", "")
	check(C.WeaponShop.MaxSoldTier == 3, "the shop still sells only up to T3 (gold alone never buys T4)", tostring(C.WeaponShop.MaxSoldTier))
	check(K.Card == "ApprenticeScratch" and C.ChoiceCard.Kinds.ApprenticeScratch ~= nil, "the apprentice card kind exists", tostring(K.Card))
	local card = C.ChoiceCard.Kinds.ApprenticeScratch
	check(card.Title == "The apprentice scratched the hilt a little." and card.Good.Label == "It's fine. Thank you!"
		and card.Evil.Label == "Fix it AND give me a discount!" and card.Good.Reward.Item == "Enh70" and card.Good.Reward.N == 1
		and card.Evil.Reward.GoldMin == 2 and card.Good.Points == 1 and card.Evil.Points == 1 and card.Seconds == nil,
		"card: scroll vs 2 minutes of gold, 1 point each, saved (no time limit)", show(card))
	check(C.RateLimits.Commission == 1, "Commission 1 s", C.RateLimits.Commission)
	check(C.Tutorial.ShortNames.Commission4 == "Golden weapon" and C.Tutorial.ShortNames.Commission5 == "Crystal weapon"
		and C.Tutorial.ShortNames.Commission6 == "Spirit weapon" and C.Return.GoalZones.Commission4 == "Crossroads", "ladder names + the Forge as the place", "")
	check(not string.find(show(K), "[\234-\237][\128-\191][\128-\191]"), "English only", "")
end)

runGroup("an order, start to end", function()
	local w = commWorld()
	local C = w.Config
	local p, d = hero(w, 1, "Halo", 12, { CarriedGold = 1000, BankGold = 2500, Items = { BruteHorn = 12, GoblinTooth = 20 } })
	local made = {}
	w.Reg.CommissionService.Made:Connect(function(player, tier) table.insert(made, tier) end)
	order(w, p, 4)
	check(bit32.btest(d.WeaponOwnedMask, 8) and d.WeaponTier == 4 and d.BlacksmithVisited == true, "the golden weapon is owned and equipped", show({ d.WeaponOwnedMask, d.WeaponTier }))
	check((d.CarriedGold or 0) == 0 and d.BankGold == 500, "3,000 gold: the carried 1,000 first, then 2,000 of the vault", show({ d.CarriedGold, d.BankGold }))
	check(d.Items.BruteHorn == 2 and d.Items.GoblinTooth == 0, "10 Brute Horn and 20 Goblin Tooth taken (2 horns left)", show(d.Items))
	check(#w.Spent == 1 and w.Spent[1].Reason == "Commission" and w.Spent[1].N == 3000, "one spend, reason 'Commission'", #w.Spent)
	local fx = lastFx(w, "Commission", p)
	check(fx and fx.Tier == 4 and fx.Name == "Goblin Thief's Golden Sword", "Fx Commission { Tier 4, the class name }", show(fx))
	check(lastFx(w, "Upgrade", p) and lastFx(w, "Upgrade", p).Tier == 4, "and the existing Upgrade fx (power A -> B)", show(lastFx(w, "Upgrade", p)))
	check(string.find(notices(w, p), "Goblin Thief's Golden Sword equipped!", 1, true) ~= nil, "the line", notices(w, p))
	check(#made == 1 and made[1] == 4, "Made signal", show(made))
	-- the card comes a moment later
	w:Advance(0.5)
	check(#w:FxOf("Card", p) == 0, "no card yet (the equip line first)", "")
	w:Advance(1.2)
	local card = lastFx(w, "Card", p)
	check(card and card.Kind == "ApprenticeScratch" and card.Title == "The apprentice scratched the hilt a little." and card.Good.Item == "Enh70"
		and card.Evil.Gold == select(1, C.HuntValue(12, 2)), "the apprentice card: scroll / 2 minutes of gold at Lv12", show(card))
	check(d.Cards.Pending and d.Cards.Pending.Kind == "ApprenticeScratch", "saved (waits with no time limit)", show(d.Cards))
	-- both options
	w:Remote("CardAction", p, card.Id, "Evil")
	check((d.BankGold or 0) == 500 + select(1, C.HuntValue(12, 2)), "the discount: 2 minutes of gold back", show(d.BankGold))
	local sources = {}
	for _, g in w.Gold do table.insert(sources, g.Src) end
	check(table.concat(sources, ",") == "Choice", "gold source 'Choice' (never 2x)", table.concat(sources, ","))
	check(d.Honor == nil or d.Honor == 0, "Halo took the Evil option: -1 floors at 0", show(d.Honor))
	-- already owned
	local before = d.BankGold
	order(w, p, 4)
	check(d.BankGold == before and #made == 1 and string.find(notices(w, p), "You already have this weapon.", 1, true) ~= nil, "ordering it again pays nothing", show(made))
end)

runGroup("T5 and T6", function()
	local w = commWorld()
	local p, d = hero(w, 2, "Horns", 30, { BankGold = 50000, Items = { KnightCrest = 50, Bone = 100, CaptainBadge = 2 } })
	order(w, p, 5)
	check(bit32.btest(d.WeaponOwnedMask, 16) and d.WeaponTier == 5 and d.BankGold == 40000 and d.Items.KnightCrest == 38 and d.Items.Bone == 70,
		"T5: 10,000 + 12 Knight Crest + 30 Bone", show({ d.WeaponTier, d.BankGold, d.Items }))
	order(w, p, 6)
	check(bit32.btest(d.WeaponOwnedMask, 32) and d.WeaponTier == 6 and d.BankGold == 10000 and d.Items.KnightCrest == 8 and d.Items.Bone == 10 and d.Items.CaptainBadge == 1,
		"T6: 30,000 + 30 Knight Crest + 60 Bone + 1 Captain's Badge (one of the two kept)", show({ d.WeaponTier, d.BankGold, d.Items }))
	check(lastFx(w, "Commission", p).Name == "Guardian Spirit Sword", "T6 name", show(lastFx(w, "Commission", p)))
	-- T6 without the badge: refused, nothing taken
	local w2 = commWorld()
	local q, qd = hero(w2, 3, "Halo", 30, { BankGold = 30000, WeaponOwnedMask = 31, Items = { KnightCrest = 30, Bone = 60 } })
	order(w2, q, 6)
	check(qd.WeaponTier == 3 and qd.BankGold == 30000 and qd.Items.KnightCrest == 30 and string.find(notices(w2, q), "Not enough materials.", 1, true) ~= nil,
		"T6 without the Captain's Badge: refused, nothing taken", show({ qd.WeaponTier, qd.BankGold, qd.Items }))
	-- the ladder line names the badge when it is the missing piece
	local line = w2.Reg.CommissionService.NextGoal(q, qd)
	check(line == "Next goal · Spirit weapon: Captain's Badge 0/1 · 30K/30K gold", "the next goal names the badge", tostring(line))
	-- the card is already waiting from T5 (one at a time): no second card
	w:Advance(2)
	check(#w:FxOf("Card", p) == 1, "one card open at a time: T6 does not add a second", #w:FxOf("Card", p))
end)

runGroup("refusals pay nothing", function()
	local function fresh(extra, feature)
		local w = commWorld({ Feature = feature })
		local data = { BankGold = 3000, Items = { BruteHorn = 10, GoblinTooth = 20 } }
		for k, v in extra or {} do data[k] = v end
		local p, d = hero(w, 3, "Halo", data.Level or 12, data)
		return w, p, d
	end
	local function untouched(d) return d.BankGold == 3000 and d.Items.BruteHorn == 10 and d.Items.GoblinTooth == 20 and d.WeaponTier == 3 and not bit32.btest(d.WeaponOwnedMask, 8) end
	local w, p, d = fresh({}, false)
	order(w, p, 4)
	check(untouched(d), "the switch off: nothing happens", show({ d.BankGold, d.Items }))
	w, p, d = fresh({})
	w.Near = false
	order(w, p, 4)
	check(untouched(d) and string.find(notices(w, p), w.Config.Text.WeaponShopFar, 1, true) ~= nil, "away from the Forge: refused with the shop's line", notices(w, p))
	w, p, d = fresh({ Level = 11 })
	order(w, p, 4)
	check(untouched(d) and string.find(notices(w, p), "You need Lv 12.", 1, true) ~= nil, "Lv11: refused (the weapon needs Lv12)", notices(w, p))
	w, p, d = fresh({ Items = { BruteHorn = 10, GoblinTooth = 19 } })
	order(w, p, 4)
	check(d.BankGold == 3000 and d.Items.GoblinTooth == 19 and d.Items.BruteHorn == 10 and d.WeaponTier == 3 and string.find(notices(w, p), "Not enough materials.", 1, true) ~= nil,
		"one tooth short: refused, nothing taken (gold untouched too)", show({ d.BankGold, d.Items }))
	w, p, d = fresh({ BankGold = 2999 })
	order(w, p, 4)
	check(d.BankGold == 2999 and d.Items.BruteHorn == 10 and d.Items.GoblinTooth == 20 and d.WeaponTier == 3 and string.find(notices(w, p), "Not enough gold.", 1, true) ~= nil,
		"one gold short: refused, no material taken", show({ d.BankGold, d.Items }))
	w, p, d = fresh({})
	w.Reg.CombatService.InCombat[p] = true
	order(w, p, 4)
	check(untouched(d), "in combat: refused", show(d.BankGold))
	w, p, d = fresh({ WeaponOwnedMask = 15 })
	order(w, p, 4)
	check(d.BankGold == 3000 and d.WeaponTier == 3, "already owned (mask): refused", show({ d.BankGold, d.WeaponTier }))
	w, p, d = fresh({})
	for _, bad in { "4", 4.5, 0 / 0, 0, 1, 3, 7, 99, -4, nil, true, {} } do
		order(w, p, bad)
	end
	w:Remote("Commission", p, 4, 5)
	w:Remote("Commission", p)
	check(untouched(d), "bad tiers / arguments are ignored", show({ d.BankGold, d.WeaponTier }))
	w, p, d = fresh({ Level = 11 })
	w.Net.Get("Commission").OnServerEvent:Fire(p, 4) -- refused for the level, but it used up the 1 s window
	d.Level = 12
	p:SetAttribute("Level", 12)
	w.Net.Get("Commission").OnServerEvent:Fire(p, 4)
	w:RunSpawned()
	check(untouched(d), "two calls inside 1 s: the second is rate limited", show({ d.BankGold }))
	w, p, d = fresh({})
	w.Ready[p] = false
	order(w, p, 4)
	w.Ready[p] = true
	check(untouched(d), "a player who is not ready: nothing", "")
end)

runGroup("next goal", function()
	local w = commWorld()
	local K = w.Reg.CommissionService
	local C = w.Config
	local nextId = 40
	local function goal(extra, level)
		nextId += 1
		local p, d = hero(w, nextId, "Halo", level or 12, extra)
		return K.NextGoal(p, d)
	end
	local t1, k1 = goal({ BankGold = 2140, Items = { BruteHorn = 6, GoblinTooth = 20 } })
	check(t1 == "Next goal · Golden weapon: Brute Horn 6/10 · 2.1K/3K gold" and k1 == "Commission4", "the design's line (worst material, then gold)", tostring(t1))
	local t2 = goal({ BankGold = 5000, Items = { BruteHorn = 10, GoblinTooth = 5 } })
	check(t2 == "Next goal · Golden weapon: Goblin Tooth 5/20 · 3K/3K gold", "the furthest material is named; gold capped at the price", tostring(t2))
	local t2b = goal({ BankGold = 5000, Items = { BruteHorn = 9, GoblinTooth = 5 } })
	check(t2b == "Next goal · Golden weapon: Goblin Tooth 5/20 · 3K/3K gold", "two materials short: the furthest one (not the first) is named", tostring(t2b))
	local t3, k3 = goal({ BankGold = 1000, Items = { BruteHorn = 10, GoblinTooth = 20 } })
	check(t3 == "Next goal · Golden weapon: 1K/3K gold" and k3 == "Commission4", "materials done: the gold", tostring(t3))
	local t4, k4 = goal({ BankGold = 5000, Items = { BruteHorn = 10, GoblinTooth = 20 } })
	check(t4 == "Next goal · Golden weapon is ready at the Forge!" and k4 == "Commission4", "all done: ready", tostring(t4) .. tostring(k4))
	local t5, k5 = goal({ BankGold = 5000, Items = { BruteHorn = 10, GoblinTooth = 20 } }, 11)
	check(t5 == "Next goal · Golden weapon: Lv12 (now Lv11)" and k5 == "Commission4", "Lv11 with everything: the level line", tostring(t5))
	check(goal({}, 9) == nil, "below Lv10: not named yet", "")
	-- T4 owned -> T5 only from Lv25
	local t6 = goal({ WeaponOwnedMask = 15, BankGold = 100, Items = {} }, 24)
	check(t6 == nil, "T4 owned, Lv24: the next order is not named yet (Ruins open at 25)", tostring(t6))
	local t7, k7 = goal({ WeaponOwnedMask = 15, BankGold = 100, Items = { KnightCrest = 4, Bone = 30 } }, 26)
	check(t7 == "Next goal · Crystal weapon: Rusty Knight Crest 4/12 · 100/10K gold" and k7 == "Commission5", "Lv26: Crystal weapon, Knight Crest 4/12", tostring(t7))
	local t8, k8 = goal({ WeaponOwnedMask = 31, BankGold = 0, Items = {} }, 30)
	check(k8 == "Commission6" and string.find(t8, "Spirit weapon", 1, true) ~= nil, "T5 owned: the spirit weapon", tostring(t8))
	check(goal({ WeaponOwnedMask = 63, Items = {} }, 40) == nil, "all three owned: nothing", "")
	local w2 = commWorld({ Feature = false })
	local p2, d2 = hero(w2, 80, "Halo", 12, { BankGold = 5000, Items = fullKit(4) })
	check(w2.Reg.CommissionService.NextGoal(p2, d2) == nil, "the switch off: no line", "")
	check(K.NextGoal(nil, nil) == nil, "no data: nothing", "")
end)

finish()
