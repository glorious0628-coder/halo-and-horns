-- choice_card_offline.luau : SPEC A23-86 Deeds (the daily good / naughty ledger) + ChoiceCard (the shared choice card),
-- 게임성 개발 3. tools/test_choice_card.py binds CONFIG_SOURCE, UTIL_SOURCE, DEEDS_SOURCE and CARD_SOURCE in front of
-- dev2_kit.luau + dev3_world.luau; this file follows. Deeds and ChoiceCard run from source; PlayerService /
-- ProgressionService / LootService are the dev3_world doubles. Test card kinds are injected (Config.ChoiceCard.Kinds
-- is empty until the content that opens them is built).

local NOON = 1789959600 -- 2026-09-22 12:00 KST

local KINDS = {
	LostBear = {
		Title = "A lost teddy!",
		Good = { Label = "Give it back", Reward = { Item = "Jelly", N = 2 }, Points = 1 },
		Evil = { Label = "Keep it", Reward = { Gold = 4 }, Points = 1 },
	},
	Quick = {
		Title = "Quick!", Seconds = 10,
		Good = { Label = "Help", Reward = { Item = "Jelly", N = 2 } },
		Evil = { Label = "Tickle", Reward = { Gold = 4 } },
	},
	-- A23-87 (게임성 개발 2): an XP reward (the FlowerPatch card's [Replant it])
	Plant = {
		Title = "A flower got squished!",
		Good = { Label = "Replant it", Reward = { XP = 6 } },
		Evil = { Label = "Pick the petals", Reward = { Item = "Jelly", N = 2 } },
	},
}

local function cardWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	o.EditConfig = function(c)
		c.ChoiceCard.Kinds = KINDS
	end
	local w = dev3World(o)
	w:Service("Deeds", DEEDS_SOURCE)
	w:Service("ChoiceCard", CARD_SOURCE)
	w:InitStart({ "Deeds", "ChoiceCard" })
	return w
end

local function hero(w, id, faction, extra)
	local data = { Faction = faction, Class = "Warrior", ClassChosen = true, Level = 1 }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function pick(w, p, id, side) w:Remote("CardAction", p, id, side) end
local function lastFx(w, kind, p)
	local list = w:FxOf(kind, p)
	return list[#list] and list[#list].Data
end
local function notices(w, p)
	return table.concat(w:NoticesFor(p), " | ")
end
local function rankOf(C, f, score)
	local _, r = C.GetTitle(f, f == "Halo" and score or 0, f == "Horns" and score or 0)
	return r
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	check(C.Deeds.PerDay == 6 and C.Deeds.Points == 1, "6 points a day, a deed is 1 (A23-86)", show(C.Deeds))
	check(C.Data.Defaults.Deeds.Day == 0 and C.Data.Defaults.Deeds.N == 0, "save default Deeds { Day 0, N 0 }", show(C.Data.Defaults.Deeds))
	check(C.Data.Defaults.Cards.Serial == 0 and C.Data.Defaults.Cards.Pending == nil, "save default Cards { Serial 0 }", show(C.Data.Defaults.Cards))
	check(C.Data.Version == 4, "data version 4 = C1's tier 9 (the card fields are additive)", C.Data.Version)
	check(C.RateLimits.CardAction == 0.3, "CardAction 0.3 s", C.RateLimits.CardAction)
	check(type(C.ChoiceCard.Kinds) == "table" and C.ChoiceCard.Grace == 1, "ChoiceCard.Kinds table, Grace 1 s", show(C.ChoiceCard))
	check(C.ChoiceCard.Text.Full == "Your shard is full for today. Come back tomorrow!", "the full line (A23-86)", C.ChoiceCard.Text.Full)
end)

runGroup("deeds: the day's six points", function()
	local w = cardWorld()
	local D = w.Reg.Deeds
	local p, d = hero(w, 1, "Halo", { Honor = 10 })
	check(p:GetAttribute("DeedsToday") == 0 and p:GetAttribute("DeedsMax") == 6, "join: DeedsToday 0 / DeedsMax 6", show({ p:GetAttribute("DeedsToday"), p:GetAttribute("DeedsMax") }))
	local stat, change, mine, down, full = D.Add(p, "Good")
	check(stat == "Honor" and change == 1 and mine == true and down == false and full == false and d.Honor == 11,
		"Halo + Good: Honor +1 (own side)", show({ stat, change, mine, down, full, d.Honor }))
	check(p:GetAttribute("DeedsToday") == 1 and D.Left(p) == 5 and D.Used(p) == 1, "one point used, five left", show({ p:GetAttribute("DeedsToday"), D.Left(p) }))
	for _ = 1, 4 do D.Add(p, "Good") end
	check(d.Honor == 15 and D.Left(p) == 1, "five points in: Honor 15, one left", show({ d.Honor, D.Left(p) }))
	local _, c6, _, _, f6 = D.Add(p, "Good")
	check(c6 == 1 and f6 == false and d.Honor == 16 and D.Left(p) == 0, "the sixth point fits (not full yet)", show({ c6, f6, d.Honor }))
	local _, c7, m7, _, f7 = D.Add(p, "Good")
	check(c7 == 0 and m7 == true and f7 == true and d.Honor == 16, "the seventh: no points, full = true, Honor stays", show({ c7, f7, d.Honor }))
	check(p:GetAttribute("DeedsToday") == 6, "the attribute stops at 6", p:GetAttribute("DeedsToday"))
	-- the other side still takes points away on a full day, and does not use the cap
	local st8, c8, m8 = D.Add(p, "Evil")
	check(st8 == "Honor" and c8 == -1 and m8 == false and d.Honor == 15, "a full day: the other side still costs 1 (A23-58)", show({ c8, d.Honor }))
	check(D.Used(p) == 6, "a loss does not use the cap", D.Used(p))
	-- a new day: back to 0 for a player who stays on
	w:ToDay(1)
	w:Tick(120)
	check(p:GetAttribute("DeedsToday") == 0 and D.Left(p) == 6, "00:00 KST: DeedsToday back to 0, six open", show({ p:GetAttribute("DeedsToday"), D.Left(p) }))
	local _, c9 = D.Add(p, "Good")
	check(c9 == 1 and d.Honor == 16, "a new day pays again", show({ c9, d.Honor }))
end)

-- A23-113 #8: every deed that happens is announced (the daily 'Choice' counts it): own side or other side, points or none, full day or not
runGroup("deeds: the Booked signal", function()
	local w = cardWorld()
	local D = w.Reg.Deeds
	local log = {}
	D.Booked:Connect(function(player, side, change, mine) table.insert(log, { P = player, Side = side, Change = change, Mine = mine }) end)
	local p, d = hero(w, 21, "Halo", { Honor = 0 })
	D.Add(p, "Good")
	check(#log == 1 and log[1].P == p and log[1].Side == "Good" and log[1].Change == 1 and log[1].Mine == true, "Halo + Good: Booked (Good, +1, mine)", show({ log[1] and log[1].Side, log[1] and log[1].Change }))
	for _ = 1, 5 do D.Add(p, "Good") end
	D.Add(p, "Good")
	check(#log == 7 and log[7].Change == 0 and log[7].Mine == true, "a full day's pick is still a deed (change 0)", show({ #log, log[7] and log[7].Change }))
	D.Add(p, "Evil")
	check(#log == 8 and log[8].Side == "Evil" and log[8].Change == -1 and log[8].Mine == false, "the other side: Booked (Evil, -1, not mine)", show({ log[8] and log[8].Change }))
	local q = hero(w, 22, "Halo", { Honor = 0 })
	D.Add(q, "Evil")
	check(#log == 9 and log[9].P == q and log[9].Change == 0 and log[9].Mine == false, "a naughty pick with no points to lose is still a deed (change 0)", show({ log[9] and log[9].Change }))
	local before = #log
	D.Add(p, "None")
	D.Add(p, "Maybe")
	D.Add(p, nil)
	D.Add(p, "Good", 0)
	D.Add(p, "Good", -3)
	check(#log == before, "no side / a bad side / no points: nothing is announced", tostring(#log - before))
	local n = hero(w, 23, "None", {})
	D.Add(n, "Good")
	check(#log == before, "a player with no side makes no deed", tostring(#log - before))
end)

runGroup("deeds: sides, floor, ranks", function()
	local w = cardWorld()
	local C = w.Config
	local D = w.Reg.Deeds
	-- Horns: Evil is own side
	local h, hd = hero(w, 2, "Horns", { Infamy = 5, Honor = 40 })
	local st, c, mine = D.Add(h, "Evil")
	check(st == "Infamy" and c == 1 and mine == true and hd.Infamy == 6 and hd.Honor == 40, "Horns + Evil: Infamy +1, Honor untouched", show({ st, c, hd.Infamy, hd.Honor }))
	local st2, c2, mine2 = D.Add(h, "Good")
	check(st2 == "Infamy" and c2 == -1 and mine2 == false and hd.Infamy == 5, "Horns + Good: Infamy -1", show({ st2, c2, hd.Infamy }))
	-- the floor
	local z, zd = hero(w, 3, "Halo", { Honor = 0 })
	local _, cz = D.Add(z, "Evil")
	check(cz == 0 and zd.Honor == 0, "Honor 0 + the other side: stays 0 (A23-58 floor)", show({ cz, zd.Honor }))
	-- a rank lost
	local edge = 0
	for _, t in C.Titles.Thresholds do if t > 0 then edge = t break end end
	check(edge > 1, "the first rank threshold exists", edge)
	local r, rd = hero(w, 4, "Halo", { Honor = edge })
	local _, cr, _, down = D.Add(r, "Evil")
	check(cr == -1 and down == (rankOf(C, "Halo", edge - 1) < rankOf(C, "Halo", edge)) and down == true and rd.Honor == edge - 1,
		"at a rank edge: -1 reports the lost rank", show({ cr, down, rd.Honor }))
	local _, _, _, down2 = D.Add(r, "Evil")
	check(down2 == false, "a second loss inside the rank: not 'down'", show(down2))
	-- previews match
	local pv, pd = hero(w, 5, "Halo", { Honor = 3 })
	local s1, v1, m1 = D.Preview(pv, "Good")
	local s2, v2, m2 = D.Preview(pv, "Evil")
	check(s1 == "Honor" and v1 == 1 and m1 == true and s2 == "Honor" and v2 == -1 and m2 == false, "Preview: Good +1 / Evil -1", show({ s1, v1, m1, s2, v2, m2 }))
	local _, a1 = D.Add(pv, "Good")
	check(a1 == v1 and pd.Honor == 4, "Add changes what Preview said", show({ a1, v1, pd.Honor }))
	D.Take(pv, 5)
	local _, v3 = D.Preview(pv, "Good")
	check(v3 == 0, "Preview of a full day: 0", v3)
	-- a size above 1 (a bigger deed) is cut to what is left
	local bg, bd = hero(w, 6, "Halo", { Honor = 0 })
	local _, big = D.Add(bg, "Good", 4)
	local _, big2, _, _, bigFull = D.Add(bg, "Good", 4)
	check(big == 4 and big2 == 2 and bigFull == true and bd.Honor == 6 and D.Left(bg) == 0, "a size-4 deed twice: 4 then the 2 left (full)", show({ big, big2, bigFull, bd.Honor }))
	-- no side
	local n, nd = hero(w, 7, "None", {})
	local ns, nc = D.Add(n, "Good")
	check(ns == "None" and nc == 0 and nd.Honor == 0 and nd.Infamy == 0 and D.Used(n) == 0, "no faction: nothing moves, nothing used", show({ ns, nc }))
	local bs, bc = D.Add(z, "Sideways")
	check(bs == "None" and bc == 0, "an unknown side: nothing", show({ bs, bc }))
	local _, c0 = D.Add(z, "Good", 0)
	check(c0 == 0 and D.Used(z) == 0, "size 0: nothing", show(c0))
	local _, cn = D.Add(z, "Good", -3)
	check(cn == 0, "a negative size: nothing", show(cn))
	local ng, ngd = hero(w, 14, "Halo", { Honor = 9 })
	local _, cng = D.Add(ng, "Evil", -3)
	check(cng == 0 and ngd.Honor == 9, "a negative size on the losing side: nothing (never a gain)", show({ cng, ngd.Honor }))
	local _, cbig = D.Add(ng, "Evil", 1e9)
	check(cbig == -6 and ngd.Honor == 3, "a huge size is cut to the day's six", show({ cbig, ngd.Honor }))
	local _, cnan = D.Add(z, "Good", 0 / 0)
	check(cnan == 1, "NaN falls back to the default size 1", show(cnan))
end)

runGroup("deeds: the save", function()
	local w = cardWorld()
	local D = w.Reg.Deeds
	local day = w.Config.DayIndex(w.Time)
	local a, ad = hero(w, 8, "Halo", { Deeds = { Day = day, N = 99 } })
	check(D.Used(a) == 6 and D.Left(a) == 0, "N above the cap is repaired to 6", show({ D.Used(a), D.Left(a) }))
	local b, bd = hero(w, 9, "Halo", { Deeds = { Day = day, N = -4 } })
	check(D.Used(b) == 0, "negative N is repaired to 0", D.Used(b))
	local c, cd = hero(w, 10, "Halo", { Deeds = "oops" })
	check(D.Left(c) == 6 and type(cd.Deeds) == "table", "a broken table is replaced", show(cd.Deeds))
	local e, ed = hero(w, 11, "Halo", { Deeds = { Day = day - 3, N = 6 } })
	check(D.Used(e) == 0 and ed.Deeds.Day == day, "an old day starts again at 0", show(ed.Deeds))
	local f, fd = hero(w, 12, "Halo", { Deeds = { Day = day, N = 2.7 } })
	check(D.Used(f) == 2, "a fraction is floored", D.Used(f))
	local g, gd = hero(w, 13, "Halo", { Deeds = { Day = day, N = 0 / 0 } })
	check(D.Used(g) == 0, "NaN is repaired to 0", D.Used(g))
end)

runGroup("card: an XP reward, never 2x (A23-87)", function()
	local w = cardWorld()
	local p = hero(w, 70, "Halo")
	local CCS = w.Reg.ChoiceCard
	w.XPMult = 2 -- the 2x XP pass
	check(CCS.Offer(p, "Plant") == true, "(the card opens)")
	local card = lastFx(w, "Card", p)
	check(card and card.Good.XP == 6 and card.Good.Label == "Replant it", "the card shows Good XP 6", show(card and card.Good))
	local n0 = #w.Notices
	pick(w, p, card.Id, "Good")
	local xp = w.XPs[#w.XPs]
	check(xp and xp.P == p and xp.N == 6 and xp.Got == 6, "AddXP(6, cap 6): the 2x pass never doubles a card's XP",
		show(xp and { xp.N, xp.Got }))
	local e = lastFx(w, "CardEnd", p)
	check(e and e.Side == "Good" and e.XP == 6 and e.Gold == 0 and e.N == 0, "CardEnd says XP 6", show(e))
	local lines = {}
	for i = n0 + 1, #w.Notices do table.insert(lines, w.Notices[i].Text) end
	check(lines[1] and string.find(lines[1], "+6 XP", 1, true) ~= nil, "the reward line names the XP", show(lines))
	-- the real Config's FlowerPatch card
	local FP = execute("Config", CONFIG_SOURCE, nativeEnv()).ChoiceCard.Kinds.FlowerPatch
	check(FP and FP.Good.Reward.XP > 0 and FP.Evil.Reward.Item == "Petal" and FP.Evil.Reward.N == 2,
		"Config.ChoiceCard.Kinds.FlowerPatch: Replant = XP, Pick = 2 petals", show(FP))
end)

runGroup("card: offer, pick, reward", function()
	local w = cardWorld()
	local C = w.Config
	local p, d = hero(w, 20, "Halo", { Honor = 5 })
	local CCS = w.Reg.ChoiceCard
	local ok, why = CCS.Offer(p, "LostBear")
	check(ok == true and why == nil, "Offer opens a saved card", show({ ok, why }))
	local card = lastFx(w, "Card", p)
	check(card and card.Id == 1 and card.Kind == "LostBear" and card.Title == "A lost teddy!" and card.Seconds == nil and card.Stat == "Honor",
		"Fx Card { Id 1, Kind, Title, no Seconds, Stat Honor }", show(card))
	check(card and card.Good.Label == "Give it back" and card.Good.Item == "Jelly" and card.Good.N == 2 and card.Good.Score == 1 and card.Good.Hint == nil,
		"Good side: label, 2 Jelly, +1, no hint", show(card and card.Good))
	check(card and card.Evil.Label == "Keep it" and card.Evil.Gold == 4 and card.Evil.Score == -1 and card.Evil.Hint == nil,
		"Evil side (the other side for a Halo): 4 gold, -1", show(card and card.Evil))
	check(d.Cards.Pending and d.Cards.Pending.Id == 1 and d.Cards.Pending.Kind == "LostBear" and d.Cards.Serial == 1, "saved: Pending { 1, LostBear }", show(d.Cards))
	check(CCS.Pending(p) == "LostBear", "ChoiceCard.Pending says the kind", show(CCS.Pending(p)))
	local ok2, why2 = CCS.Offer(p, "LostBear")
	check(ok2 == false and why2 == "open" and #w:FxOf("Card", p) == 1, "a second card while one is open: false 'open'", show({ ok2, why2 }))
	-- bad input never closes it (an early bad call also uses up the rate limit window)
	w.Net.Get("CardAction").OnServerEvent:Fire(p, 99, "Good")
	w.Net.Get("CardAction").OnServerEvent:Fire(p, 1, "Good")
	w:RunSpawned()
	check(CCS.Pending(p) == "LostBear" and #w:FxOf("CardEnd", p) == 0, "two calls inside 0.3 s: the second is rate limited", show(CCS.Pending(p)))
	pick(w, p, 2, "Good")
	pick(w, p, 1, "Neutral")
	pick(w, p, "1", "Good")
	pick(w, p, 1, nil)
	pick(w, p, 1.5, "Good")
	pick(w, p, 0 / 0, "Good")
	w:Remote("CardAction", p, 1, "Good", "extra")
	w:Remote("CardAction", p, 1)
	w:Remote("CardAction", p)
	check(CCS.Pending(p) == "LostBear" and #w:FxOf("CardEnd", p) == 0 and d.Honor == 5, "wrong id / side / type / argument count: ignored", show({ CCS.Pending(p), d.Honor }))
	-- the pick
	pick(w, p, 1, "Good")
	local en = lastFx(w, "CardEnd", p)
	check(en and en.Id == 1 and en.Kind == "LostBear" and en.Side == "Good" and en.Stat == "Honor" and en.Score == 1 and en.Item == "Jelly" and en.N == 2 and en.Gold == 0 and en.Full == false,
		"Fx CardEnd { Good, Honor +1, 2 Jelly }", show(en))
	check(d.Items and d.Items.Jelly == 2 and d.Honor == 6, "2 Jelly in the bag, Honor 6", show({ d.Items, d.Honor }))
	check(d.Cards.Pending == nil and CCS.Pending(p) == nil, "the card is gone, nothing pending", show(d.Cards))
	check(d.Story.N.LostBear.Good == 1 and d.Story.N.LostBear.Evil == nil, "counted: Story.N.LostBear.Good = 1", show(d.Story))
	check(p:GetAttribute("DeedsToday") == 1, "the pick used one deed point", p:GetAttribute("DeedsToday"))
	local n = notices(w, p)
	-- A23-130: the gains only (no 'Kind choice!' label)
	check(string.find(n, "+Jelly ×2 · Honor +1", 1, true) and not string.find(n, "Kind choice!", 1, true), "one line: +Jelly ×2 · Honor +1", n)
	pick(w, p, 1, "Good")
	check(d.Items.Jelly == 2 and d.Honor == 6 and #w:FxOf("CardEnd", p) == 1, "the same card twice: paid once", show({ d.Items, d.Honor }))
	-- the next card has a new id; the other side
	local ok3 = CCS.Offer(p, "LostBear")
	local card2 = lastFx(w, "Card", p)
	check(ok3 == true and card2.Id == 2 and d.Cards.Serial == 2, "the next card: Id 2", show({ ok3, card2 and card2.Id }))
	pick(w, p, 2, "Evil")
	local en2 = lastFx(w, "CardEnd", p)
	check(en2 and en2.Side == "Evil" and en2.Score == -1 and en2.Gold == 4 and en2.N == 0 and d.Honor == 5 and (d.BankGold or 0) == 4,
		"Halo takes the Evil option: 4 gold, Honor -1 (A23-58)", show({ en2, d.Honor, d.BankGold }))
	local sources = {}
	for _, g in w.Gold do table.insert(sources, g.Src) end
	check(#sources == 1 and sources[1] == "Choice", "gold source 'Choice' (never boosted by a pass)", show(sources))
	check(string.find(notices(w, p), "Honor", 1, true) ~= nil and d.Story.N.LostBear.Evil == 1, "off-side answer + counted", notices(w, p))
	CCS.Offer(p, "LostBear")
	pick(w, p, 3, "Good")
	check(d.Story.N.LostBear.Good == 2 and d.Story.N.LostBear.Evil == 1, "counted again: Good 2, Evil 1", show(d.Story.N))
	-- an unknown kind / a player who is not ready
	local okk, whyk = CCS.Offer(p, "Nope")
	check(okk == false and whyk == "kind", "unknown kind: false 'kind'", show({ okk, whyk }))
	local okt, whyt = CCS.Offer(p, 5)
	check(okt == false and whyt == "kind", "a non-string kind: false 'kind'", show({ okt, whyt }))
	w.Ready[p] = false
	local okr, whyr = CCS.Offer(p, "Quick")
	w.Ready[p] = true
	check(okr == false and whyr == "notready", "a player who is not ready: false 'notready'", show({ okr, whyr }))
	local okn, whyn = CCS.Offer(nil, "LostBear")
	check(okn == false and whyn == "gone", "no player: false 'gone'", show({ okn, whyn }))
end)

runGroup("card: a full day keeps the reward", function()
	local w = cardWorld()
	local CCS = w.Reg.ChoiceCard
	local p, d = hero(w, 21, "Halo", { Honor = 0 })
	w.Reg.Deeds.Take(p, 6)
	CCS.Offer(p, "LostBear")
	local card = lastFx(w, "Card", p)
	check(card.Good.Score == 0 and card.Good.Hint == "Full" and card.Evil.Score == 0 and card.Evil.Hint == "Zero", "the card says Full / Zero", show(card))
	pick(w, p, 1, "Good")
	local en = lastFx(w, "CardEnd", p)
	check(en.Score == 0 and en.Full == true and en.N == 2 and d.Items.Jelly == 2 and d.Honor == 0, "no points, the reward still comes, Full = true", show(en))
	-- A23-130: no 'shard is full' line (the card said Full before the pick); the reward line still comes
	check(string.find(notices(w, p), w.Config.ChoiceCard.Text.Full, 1, true) == nil and string.find(notices(w, p), "+Jelly ×2", 1, true) ~= nil,
		"no 'shard is full' line, the reward line only", notices(w, p))
end)

runGroup("card: no faction, bag full", function()
	local w = cardWorld()
	local CCS = w.Reg.ChoiceCard
	local n, nd = hero(w, 22, "None", {})
	CCS.Offer(n, "LostBear")
	local card = lastFx(w, "Card", n)
	check(card.Stat == "None" and card.Good.Hint == "Neutral" and card.Evil.Hint == "Neutral" and card.Good.Score == 0, "no side: Neutral hints", show(card))
	pick(w, n, 1, "Evil")
	check((nd.BankGold or 0) == 4 and nd.Honor == 0 and nd.Infamy == 0, "no side: the reward only", show({ nd.BankGold, nd.Honor, nd.Infamy }))
	-- a full bag pays the Jelly at its sell price
	local full = w.Config.Loot.ItemCap
	local f, fd = hero(w, 23, "Halo", { Items = { Jelly = full } })
	CCS.Offer(f, "LostBear")
	pick(w, f, 1, "Good")
	local en = lastFx(w, "CardEnd", f)
	check(en.N == 0 and en.Gold == 4 and fd.Items.Jelly == full and (fd.BankGold or 0) == 4, "a full bag: 2 Jelly paid as 4 gold (sell price 2)", show({ en, fd.BankGold }))
end)

runGroup("card: saved across a join", function()
	local w = cardWorld()
	local CCS = w.Reg.ChoiceCard
	local p, d = hero(w, 24, "Halo", {})
	CCS.Offer(p, "LostBear", { From = "bear" })
	local saved = w.Config and d.Cards
	w:Leave(p)
	local q, qd = hero(w, 24, "Halo", { Cards = { Serial = 1, Pending = { Id = 1, Kind = "LostBear", Ctx = { From = "bear" } } } })
	local list = w:FxOf("Card", q)
	check(#list == 1 and list[1].Data.Id == 1 and list[1].Data.Kind == "LostBear", "next join: the saved card is shown again", show(list[1] and list[1].Data))
	check(CCS.Pending(q) == "LostBear", "it is the open card", show(CCS.Pending(q)))
	pick(w, q, 1, "Good")
	check(qd.Cards.Pending == nil and qd.Cards.Serial == 1, "picked: cleared, serial kept", show(qd.Cards))
	local ok = CCS.Offer(q, "LostBear")
	check(ok == true and lastFx(w, "Card", q).Id == 2, "the next card continues the serial (Id 2)", show(lastFx(w, "Card", q)))
	-- leaving with a card open keeps it saved
	w:Leave(q)
	check(qd.Cards.Pending and qd.Cards.Pending.Id == 2, "left with a card open: still saved", show(qd.Cards))
	-- repairs
	local a, ad = hero(w, 25, "Halo", { Cards = { Serial = 3, Pending = { Id = 3, Kind = "Gone" } } })
	check(ad.Cards.Pending == nil and #w:FxOf("Card", a) == 0, "an unknown kind is dropped", show(ad.Cards))
	local b, bd = hero(w, 26, "Halo", { Cards = { Serial = 4, Pending = { Id = 4, Kind = "Quick" } } })
	check(bd.Cards.Pending == nil and #w:FxOf("Card", b) == 0, "a timed kind is never restored", show(bd.Cards))
	local c, cd = hero(w, 27, "Halo", { Cards = { Serial = -9, Pending = "oops" } })
	check(cd.Cards.Pending == nil and cd.Cards.Serial == 0, "broken numbers / tables are repaired", show(cd.Cards))
	local e, ed = hero(w, 28, "Halo", { Cards = { Serial = 1, Pending = { Id = 7, Kind = "LostBear" } } })
	check(ed.Cards.Serial == 7 and #w:FxOf("Card", e) == 1, "a pending Id above the serial lifts the serial (no repeated ids)", show(ed.Cards))
end)

runGroup("card: timed", function()
	local w = cardWorld()
	local CCS = w.Reg.ChoiceCard
	local p, d = hero(w, 29, "Halo", {})
	CCS.Offer(p, "Quick")
	local card = lastFx(w, "Card", p)
	check(card.Seconds == 10 and d.Cards.Pending == nil, "a timed card: Seconds 10, nothing saved", show({ card.Seconds, d.Cards }))
	w:Advance(10.5)
	check(#w:FxOf("CardEnd", p) == 0 and CCS.Pending(p) == "Quick", "10.5 s: the Grace second still counts", show(CCS.Pending(p)))
	w.Net.Get("CardAction").OnServerEvent:Fire(p, 1, "Good")
	w:RunSpawned()
	check(lastFx(w, "CardEnd", p).Side == "Good" and d.Items.Jelly == 2, "a pick inside the Grace is paid", show(lastFx(w, "CardEnd", p)))
	w:Advance(5)
	check(#w:FxOf("CardEnd", p) == 1, "the picked card's own timer ends nothing twice", #w:FxOf("CardEnd", p))
	-- time up
	CCS.Offer(p, "Quick")
	w:Advance(12)
	local en = lastFx(w, "CardEnd", p)
	check(en and en.Side == "None" and en.Id == 2 and d.Items.Jelly == 2 and (d.BankGold or 0) == 0, "time up: 'None', nothing paid", show(en))
	check(CCS.Pending(p) == nil, "the card is closed", show(CCS.Pending(p)))
	pick(w, p, 2, "Good")
	check(d.Items.Jelly == 2, "a pick after the end is ignored", show(d.Items))
	-- leaving with a timed card
	CCS.Offer(p, "Quick")
	w:Leave(p)
	local last = lastFx(w, "CardEnd", p)
	check(CCS.Pending(p) == nil, "a timed card ends when the player leaves", show(CCS.Pending(p)))
	-- a timed card does not stop a saved one's next turn
	local q = hero(w, 30, "Halo", {})
	check(CCS.Offer(q, "Quick") == true and CCS.Offer(q, "LostBear") == false, "one card at a time across kinds", "")
end)

runGroup("card: rate limit and rank", function()
	local w = cardWorld()
	local C = w.Config
	local CCS = w.Reg.ChoiceCard
	local p, d = hero(w, 31, "Halo", { Honor = 3 })
	CCS.Offer(p, "LostBear")
	-- two picks inside 0.3 s: the first one wins, the second is rate limited (and the card is gone anyway)
	w.Net.Get("CardAction").OnServerEvent:Fire(p, 1, "Evil")
	w.Net.Get("CardAction").OnServerEvent:Fire(p, 1, "Good")
	w:RunSpawned()
	local ends = w:FxOf("CardEnd", p)
	check(#ends == 1 and ends[1].Data.Side == "Evil", "two picks at once: the first counts only", #ends)
	-- a rank lost by the Evil pick
	local edge = 0
	for _, t in C.Titles.Thresholds do if t > 0 then edge = t break end end
	local r, rd = hero(w, 32, "Halo", { Honor = edge })
	CCS.Offer(r, "LostBear")
	pick(w, r, 1, "Evil")
	local text = notices(w, r)
	check(rd.Honor == edge - 1 and string.find(text, C.StoryQuests.Text.RankDownHalo, 1, true) ~= nil, "a lost rank gets the rank line", text)
end)

runGroup("card: the signal", function()
	local w = cardWorld()
	local CCS = w.Reg.ChoiceCard
	local seen = {}
	CCS.Picked:Connect(function(player, kind, side, result) table.insert(seen, { kind, side, result.Score }) end)
	local p = hero(w, 33, "Horns", {})
	CCS.Offer(p, "LostBear")
	pick(w, p, 1, "Evil")
	CCS.Offer(p, "Quick")
	w:Advance(12)
	check(#seen == 2 and seen[1][1] == "LostBear" and seen[1][2] == "Evil" and seen[1][3] == 1 and seen[2][1] == "Quick" and seen[2][2] == "None",
		"Picked fires for a pick and for a time up", show(seen))
	CCS.Offer(p, "Quick")
	w:Leave(p)
	check(#seen == 3 and seen[3][2] == "None", "a player leaving with a timed card: it ends ('None')", show(seen))
	w:Advance(12)
	check(#seen == 3, "and its timer ends nothing again", show(seen))
end)

finish()
