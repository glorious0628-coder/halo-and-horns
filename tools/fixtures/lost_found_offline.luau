-- lost_found_offline.luau : #45 Lost & Found (LostFoundService, 게임성 개발 3, 2026-10-10; contract
-- docs/design/lost_found_server_2026-10-10.md). tools/test_lost_found.py binds CONFIG_SOURCE, UTIL_SOURCE, DEEDS_SOURCE,
-- CARD_SOURCE and LF_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows. Deeds, ChoiceCard and
-- LostFoundService run from source; PlayerService / ProgressionService / LootService / ZoneService / MonsterService are the
-- dev3_world doubles, QuestService is a MarkDirty counter. Random draws are scripted (w.Script, front first).

local NOON = 1789959600 -- 2026-09-22 12:00 KST
local BENCH = vec(18, 0, 18) -- Config.StoryQuests.Landmarks.KidsBench

local function lfWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.Off ~= true then c.LostFound.Enabled = true end
		if o.Halloween ~= nil then c.Halloween.Enabled = o.Halloween end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	w.Dirty = 0
	w.Reg.QuestService = { MarkDirty = function() w.Dirty += 1 end }
	w:Service("Deeds", DEEDS_SOURCE)
	w:Service("ChoiceCard", CARD_SOURCE)
	w:Service("LostFoundService", LF_SOURCE)
	w:InitStart({ "Deeds", "ChoiceCard", "LostFoundService" })
	w.LF = w.Reg.LostFoundService
	w.Script = {}
	w.Founds, w.Delivered = {}, {}
	w.LF.Found:Connect(function(p, id, zone) table.insert(w.Founds, { P = p, Id = id, Zone = zone }) end)
	w.LF.Delivered:Connect(function(p, id, side, leg, res) table.insert(w.Delivered, { P = p, Id = id, Side = side, Leg = leg, Res = res }) end)
	return w
end

local function hero(w, id, faction, level, extra)
	local data = { Faction = faction or "Halo", Class = "Warrior", ClassChosen = true, Level = level or 5 }
	for k, v in extra or {} do data[k] = v end
	local p, d = w:Arrive(id, { Data = data })
	w.CharFolder = w.CharFolder or newInstance("Folder", w)
	local char = newInstance("Model", w)
	char.Parent = w.CharFolder
	local root = newInstance("Part", w)
	root.Name, root.Position = "HumanoidRootPart", vec(0, 0, 0)
	root.Parent = char
	p.Character = char
	return p, d
end

-- the doubles' lists without the players (show() must never print a player)
local function plain(list)
	local out = {}
	for _, e in list do table.insert(out, { N = e.N, Got = e.Got, Src = e.Src, Id = e.Id, Side = e.Side, Leg = e.Leg }) end
	return out
end

local function kill(w, p, zone, n, o)
	for _ = 1, n or 1 do
		local info = { Kind = "Slime", ZoneId = zone or "SlimeMeadow", Position = vec(0, 0, 0), WarPoints = 0 }
		for k, v in o or {} do info[k] = v end
		w.Reg.MonsterService.MonsterKilled:Fire(p, info)
	end
	w:RunSpawned()
end

local function at(w, p, zone, pos)
	p:SetAttribute("ZoneId", zone)
	p.Character:FindFirstChild("HumanoidRootPart").Position = pos or vec(0, 0, 0)
end

local function lastCard(w, p)
	local list = w:FxOf("Card", p)
	return list[#list] and list[#list].Data
end

local function pick(w, p, side)
	local card = lastCard(w, p)
	w:Remote("CardAction", p, card.Id, side)
end

local function notices(w, p)
	return table.concat(w:NoticesFor(p), " | ")
end

local function fill(n)
	local out = {}
	for i = 1, n do out[i] = 0.9999999 end
	return out
end

-- a find at once: kills up to the sure one (every earlier draw scripted to "no", the 100th is sure)
local function findNow(w, p, zone)
	local before = #w.Founds
	w.Script = fill(41)
	kill(w, p, zone, 100)
	w.Script = {}
	return #w.Founds > before
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local L = C.LostFound
	check(L.Enabled == false and L.From == 60 and L.Sure == 100 and L.DayCap == 3 and L.RewardMinutes == 2,
		"config: OFF by default, 60..100 kills, 3 a day, 2 minutes of hunting", show({ L.Enabled, L.From, L.Sure, L.DayCap, L.RewardMinutes }))
	check(table.concat(L.Order, ",") == "Teddy,ClubBadge,GuardMedal,CandyBag", "four items in order", table.concat(L.Order, ","))
	check(L.Items.Teddy.Zone == "SlimeMeadow" and L.Items.ClubBadge.Zone == "GoblinWoods" and L.Items.GuardMedal.Zone == "SkeletonRuins"
		and L.Items.CandyBag.Zone == "PumpkinPatch" and L.Items.CandyBag.Season == "Halloween" and L.Items.Teddy.Season == nil,
		"teddy: meadow, badge: woods, medal: ruins, candy bag: pumpkin patch (Halloween only)", "")
	check(L.Items.Teddy.Owner == "Kid" and L.Items.CandyBag.Owner == "Kid" and L.Items.ClubBadge.Owner ~= "Kid" and L.Items.GuardMedal.Owner ~= "Kid",
		"the child's things are the teddy and the candy bag", "")
	for id, def in L.Items do
		local k = C.ChoiceCard.Kinds[def.Card]
		check(type(k) == "table" and type(k.Title) == "string" and k.Good.Label == "Give it back" and k.Good.Points == 1 and k.Evil.Points == 1
			and k.Good.Reward == nil and k.Evil.Reward == nil and k.Seconds == nil,
			"card " .. def.Card .. " (" .. id .. "): a saved card, 1 point each way, no reward of its own", show(k))
		check((def.Owner == "Kid") == (k.Evil.Label == "Finder's fee!") and (def.Owner ~= "Kid") == (k.Evil.Label == "Keep it as a trophy"),
			"card " .. def.Card .. ": a child's thing asks a fee, anything else is kept as a trophy", k.Evil.Label)
	end
	check(C.Data.Defaults.LostFound.Day == 0 and C.Data.Defaults.LostFound.N == 0 and C.Data.Defaults.LostFound.K == 0 and C.Data.Version == 6,
		"save default LostFound { Day 0, N 0, K 0 } (additive; the data version 6 = A23-186's joke weapons (5 = A23-153's codex, 4 = C1's tier 9))", show(C.Data.Defaults.LostFound))
	check(C.LostFound.Bench.Zone == "Crossroads" and C.LostFound.Bench.Spot == "KidsBench" and C.LostFound.Bench.Range == 10
		and C.StoryQuests.Landmarks.KidsBench.X == 18 and C.StoryQuests.Landmarks.KidsBench.Z == 18, "the bench: the Crossroads kids' bench, 10 studs", "")
	local alive = true
	for _, text in L.Text do if type(text) ~= "string" or string.find(text, "[\128-\255]") and not string.find(text, "·", 1, true) then alive = false end end
	check(alive, "every line is plain English (the one bullet is ·)", "")
	check(L.Text.ShortBench == "Lost & Found" and #L.Text.ShortBench <= 14 and #L.Text.ShortVault <= 14, "short names fit 14 letters", "")
end)

runGroup("the beat (Chance)", function()
	local w = lfWorld()
	local c = w.LF.Chance
	check(c(0) == 0 and c(59) == 0 and c(-5) == 0, "below 60 kills: no chance", show({ c(0), c(59) }))
	check(math.abs(c(60) - 1 / 41) < 1e-9 and math.abs(c(80) - 21 / 41) < 1e-9 and math.abs(c(99) - 40 / 41) < 1e-9,
		"60: 1/41, 80: 21/41, 99: 40/41 (evenly rising)", show({ c(60), c(80), c(99) }))
	check(c(100) == 1 and c(1000) == 1 and c(0 / 0) == 0, "100 kills and more: sure", show({ c(100), c(1000) }))
	local up = true
	for k = 60, 99 do if not (c(k + 1) > c(k)) then up = false end end
	check(up, "the chance only rises", "")
	local w2 = lfWorld({ EditConfig = function(cfg) cfg.LostFound.From, cfg.LostFound.Sure = 10, 10 end })
	check(w2.LF.Chance(9) == 0 and w2.LF.Chance(10) == 1, "From = Sure: sure at once", "")
end)

------------------------------------------------------------------ off
runGroup("off: nothing counts", function()
	local w = lfWorld({ Off = true })
	local p, d = hero(w, 1)
	kill(w, p, "SlimeMeadow", 300)
	check(#w.Founds == 0 and d.LostFound.K == 0 and d.LostFound.N == 0 and d.LostFound.Holding == nil and #w:FxOf("Card", p) == 0,
		"Config.LostFound.Enabled = false: 300 kills, no count, no find, no card", show(d.LostFound))
	check(#w.LF.Rows(p, d) == 0 and w.LF.Deliver(p) == false, "no row, no delivery", "")
end)

------------------------------------------------------------------ the beat in play
runGroup("kills count; a find at the right kill", function()
	local w = lfWorld()
	local p, d = hero(w, 1)
	w.Script = { 0.999, 0.999, 0.999 }
	kill(w, p, "SlimeMeadow", 59)
	check(d.LostFound.K == 59 and #w.Founds == 0 and #w.Script == 3, "59 kills: counted, no chance, no draw used", show({ d.LostFound.K, #w.Script }))
	kill(w, p, "SlimeMeadow", 1)
	check(d.LostFound.K == 60 and #w.Founds == 0 and #w.Script == 2, "the 60th kill draws once (a roll of 0.999 is no find)", show({ d.LostFound.K, #w.Script }))
	kill(w, p, "SlimeMeadow", 2)
	check(d.LostFound.K == 62 and #w.Founds == 0 and #w.Script == 0, "each later kill draws once", show({ d.LostFound.K, #w.Script }))
	-- the chance at 80 is 21/41 = 0.512: 0.5 finds, 0.52 does not
	local w2 = lfWorld()
	local q, qd = hero(w2, 2)
	w2.Script = fill(20)
	kill(w2, q, "SlimeMeadow", 79)
	w2.Script = { 0.52 }
	kill(w2, q, "SlimeMeadow", 1)
	check(#w2.Founds == 0 and qd.LostFound.K == 80, "kill 80, roll 0.52: no find", "")
	local w3 = lfWorld()
	local r, rd = hero(w3, 3)
	w3.Script = fill(20)
	kill(w3, r, "SlimeMeadow", 79)
	w3.Script = { 0.5 }
	kill(w3, r, "SlimeMeadow", 1)
	check(#w3.Founds == 1 and w3.Founds[1].Id == "Teddy" and w3.Founds[1].Zone == "SlimeMeadow" and rd.LostFound.K == 0,
		"kill 80, roll 0.5: the teddy, the count starts again", show({ w3.Founds[1] and w3.Founds[1].Id, rd.LostFound.K }))
	-- no roll at all: the 100th kill is sure
	local w4 = lfWorld()
	local s, sd = hero(w4, 4)
	w4.Script = fill(41)
	kill(w4, s, "SlimeMeadow", 100)
	check(#w4.Founds == 1 and sd.LostFound.K == 0, "even with the worst rolls the 100th kill finds it", show({ #w4.Founds, sd.LostFound.K }))
end)

runGroup("what a find does", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	check(findNow(w, p, "SlimeMeadow"), "a find", "")
	local h = d.LostFound.Holding
	check(h and h.Id == "Teddy" and h.Phase == "Choose" and h.First == true and d.LostFound.N == 1 and d.LostFound.K == 0
		and d.LostFound.Day == w.Config.DayIndex(w.Time), "holding the teddy, phase Choose, the day's first, 1 find today", show(d.LostFound))
	local card = lastCard(w, p)
	check(card and card.Kind == "LostTeddy" and card.Title == "A lost teddy! Someone must miss it." and card.Good.Label == "Give it back"
		and card.Evil.Label == "Finder's fee!" and card.Seconds == nil, "the card of the teddy opened (Give it back / Finder's fee!)", show(card))
	check(w.Reg.ChoiceCard.Pending(p) == "LostTeddy" and d.Cards.Pending and d.Cards.Pending.Kind == "LostTeddy" and d.Cards.Pending.Ctx.Item == "Teddy",
		"it is a saved card (it waits for the player; Ctx.Item = Teddy)", show(d.Cards))
	check(#w.LF.Rows(p, d) == 0, "no row while the card is still unanswered", "")
	-- another item's card, or a card that was not answered, starts no walk
	w.Reg.ChoiceCard.Picked:Fire(p, "LostBadge", "Good", {})
	w.Reg.ChoiceCard.Picked:Fire(p, "LostTeddy", "None", {})
	w.Reg.ChoiceCard.Picked:Fire(p, "FlowerPatch", "Good", {})
	check(d.LostFound.Holding.Phase == "Choose", "the badge's card, an unanswered card and another card's answer start no walk", show(d.LostFound.Holding))
	-- one at a time: nothing counts or opens while it is held
	local before = #w:FxOf("Card", p)
	kill(w, p, "SlimeMeadow", 150)
	check(d.LostFound.K == 0 and d.LostFound.N == 1 and #w:FxOf("Card", p) == before and #w.Founds == 1,
		"while one is held: 150 kills, no count, no second find, no second card", show({ d.LostFound.K, d.LostFound.N, #w.Founds }))
end)

runGroup("zones and items", function()
	local w = lfWorld()
	local p, d = hero(w, 1)
	kill(w, p, "Crossroads", 300)
	kill(w, p, "HaloTown", 300)
	kill(w, p, "HauntedHollow", 300)
	check(d.LostFound.K == 0 and #w.Founds == 0, "kills outside the four item zones count nothing", show(d.LostFound))
	local woods = lfWorld()
	local q, qd = hero(woods, 2)
	check(findNow(woods, q, "GoblinWoods") and qd.LostFound.Holding.Id == "ClubBadge" and lastCard(woods, q).Kind == "LostBadge",
		"the woods: the Grab Club badge, its own card", "")
	local ruins = lfWorld()
	local r, rd = hero(ruins, 3)
	check(findNow(ruins, r, "SkeletonRuins") and rd.LostFound.Holding.Id == "GuardMedal" and lastCard(ruins, r).Kind == "LostMedal",
		"the ruins: the old guard medal, its own card", "")
	local off = lfWorld({ Halloween = false })
	local s, sd = hero(off, 4)
	kill(off, s, "PumpkinPatch", 300)
	check(sd.LostFound.K == 0 and #off.Founds == 0, "the pumpkin patch outside Halloween: nothing", show(sd.LostFound))
	local hal = lfWorld({ Halloween = true })
	local t, td = hero(hal, 5)
	check(findNow(hal, t, "PumpkinPatch") and td.LostFound.Holding.Id == "CandyBag" and lastCard(hal, t).Kind == "LostCandy",
		"the pumpkin patch in Halloween: the lost candy bag", "")
	-- the count is the player's own total across the zones with an item
	local mix = lfWorld()
	local u, ud = hero(mix, 6)
	kill(mix, u, "SlimeMeadow", 50)
	kill(mix, u, "Crossroads", 50)
	check(ud.LostFound.K == 50, "town kills in between are not counted", show(ud.LostFound))
	mix.Script = fill(10)
	kill(mix, u, "GoblinWoods", 15)
	check(ud.LostFound.K == 65, "the woods count on from the meadow's 50 (one count per player)", show(ud.LostFound))
end)

runGroup("who counts", function()
	local w = lfWorld()
	local p, d = hero(w, 1)
	kill(w, p, "SlimeMeadow", 120, { Minor = true })
	check(d.LostFound.K == 0 and #w.Founds == 0, "a free rider's small share (Minor) counts nothing", show(d.LostFound))
	w.Reg.MonsterService.MonsterKilled:Fire(nil, { Kind = "Slime", ZoneId = "SlimeMeadow" })
	w.Reg.MonsterService.MonsterKilled:Fire("someone", { Kind = "Slime", ZoneId = "SlimeMeadow" })
	w.Reg.MonsterService.MonsterKilled:Fire(p, nil)
	w.Reg.MonsterService.MonsterKilled:Fire(p, "kill")
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" })
	check(d.LostFound.K == 0, "a kill with no player, no info or no zone counts nothing (and breaks nothing)", show(d.LostFound))
	local gone, gd = hero(w, 2)
	w:Leave(gone)
	kill(w, gone, "SlimeMeadow", 120)
	check(gd.LostFound.K == 0, "a player who left counts nothing", show(gd.LostFound))
	local nr, nrd = hero(w, 3)
	w.Ready[nr] = nil
	kill(w, nr, "SlimeMeadow", 120)
	check(nrd.LostFound.K == 0 and #w.Founds == 0, "a player who is not ready yet counts nothing", show(nrd.LostFound))
end)

runGroup("three a day, then the next KST day", function()
	local w = lfWorld()
	local p, d = hero(w, 1)
	for i = 1, 3 do
		check(findNow(w, p, "SlimeMeadow"), "find " .. i, "")
		pick(w, p, "Good")
		at(w, p, "Crossroads", BENCH)
		check(w.LF.Deliver(p) == true, "delivered " .. i, "")
		at(w, p, "SlimeMeadow", vec(0, 0, 0))
	end
	check(d.LostFound.N == 3 and #w.Founds == 3 and d.LostFound.Holding == nil, "three finds today", show(d.LostFound))
	kill(w, p, "SlimeMeadow", 200)
	check(d.LostFound.N == 3 and #w.Founds == 3 and d.LostFound.K == 0, "the fourth does not come: nothing counts today either", show(d.LostFound))
	w:ToDay(1)
	findNow(w, p, "SlimeMeadow")
	check(#w.Founds == 4 and d.LostFound.N == 1 and d.LostFound.Day == w.Config.DayIndex(w.Time), "the next KST day: the count starts, finds are 1 again", show(d.LostFound))
	check(d.LostFound.Holding and d.LostFound.Holding.First == true, "and it is the new day's first", "")
end)

------------------------------------------------------------------ the pick and the walk
runGroup("the pick: Good / the fee / the trophy", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5, { Honor = 10 })
	findNow(w, p, "SlimeMeadow")
	local dirty = w.Dirty
	pick(w, p, "Good")
	local h = d.LostFound.Holding
	check(h and h.Phase == "Carry" and h.Side == "Good" and h.Leg == "Bench" and d.Honor == 11 and w.Dirty > dirty,
		"Give it back: carrying it to the bench, Honor +1 (a Halo deed), the quest list refreshed", show({ h, d.Honor }))
	local row = w.LF.Rows(p, d)[1]
	check(row and row.Id == "find:Teddy" and row.Kind == "Find" and row.Text == "Bring the Lost Teddy to the Lost & Found · Crossroads"
		and row.ShortName == "Lost & Found" and row.Find.Guide == "Fountain" and row.Find.Leg == "Bench" and row.Find.Item == "Teddy"
		and row.Pinned == false and row.CanClaim == false and row.Target == 1 and row.ShowProgress == false and #w.LF.Rows(p, d) == 1,
		"the row: bring the teddy to the bench (guide: the fountain)", show(row))
	check(row.RewardXP > 0 and row.RewardGold == 0, "a Good walk shows XP, no gold", show({ row.RewardXP, row.RewardGold }))
	-- the fee on a child's thing is the same walk
	local w2 = lfWorld()
	local q, qd = hero(w2, 2, "Horns", 5)
	findNow(w2, q, "SlimeMeadow")
	pick(w2, q, "Evil")
	local fee = qd.LostFound.Holding
	check(fee.Phase == "Carry" and fee.Side == "Evil" and fee.Leg == "Bench" and qd.Infamy == 1, "Finder's fee!: the same bench, Infamy +1 (a Horns deed)", show({ fee, qd.Infamy }))
	local frow = w2.LF.Rows(q, qd)[1]
	check(frow.RewardGold > 0 and frow.RewardXP == 0 and frow.Find.Leg == "Bench", "an Evil walk shows gold, no XP", show(frow))
	-- the trophy of something that is not a child's
	local w3 = lfWorld()
	local r, rd = hero(w3, 3, "Halo", 20)
	findNow(w3, r, "GoblinWoods")
	pick(w3, r, "Evil")
	local trophy = rd.LostFound.Holding
	check(trophy.Phase == "Carry" and trophy.Side == "Evil" and trophy.Leg == "Vault" and (rd.Honor or 0) == 0,
		"Keep it as a trophy: the vault leg (a Halo's Evil deed has nothing to lose at 0)", show({ trophy, rd.Honor }))
	local trow = w3.LF.Rows(r, rd)[1]
	check(trow.Text == "Put the Grab Club Badge in your vault · your town" and trow.ShortName == "Trophy vault" and trow.Find.Guide == "OwnTown"
		and trow.Find.Leg == "Vault", "the vault row: the badge, guide OwnTown", show(trow))
	-- Good on a non-child's thing is the bench
	local w4 = lfWorld()
	local s, sd = hero(w4, 4, "Halo", 30)
	findNow(w4, s, "SkeletonRuins")
	pick(w4, s, "Good")
	check(sd.LostFound.Holding.Leg == "Bench" and sd.LostFound.Holding.Side == "Good", "Give back the medal: the bench", show(sd.LostFound.Holding))
	-- a card that is answered when no find is held, or the wrong one, does nothing
	local w5 = lfWorld()
	local u, ud = hero(w5, 5)
	w5.Reg.ChoiceCard.Offer(u, "LostTeddy", {})
	pick(w5, u, "Good")
	check(ud.LostFound.Holding == nil and #w5.LF.Rows(u, ud) == 0, "a Lost card with no find behind it starts no walk", show(ud.LostFound))
end)

runGroup("the walk's end: the bench", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	findNow(w, p, "SlimeMeadow")
	pick(w, p, "Good")
	at(w, p, "SlimeMeadow", vec(0, 0, 0))
	check(w.LF.Deliver(p) == false and d.LostFound.Holding ~= nil, "in the meadow: not there yet", "")
	at(w, p, "Crossroads", vec(18 + 11, 0, 18))
	check(w.LF.Deliver(p) == false, "11 studs from the bench: not there yet", "")
	at(w, p, "SlimeMeadow", BENCH)
	check(w.LF.Deliver(p) == false, "the bench's coordinates in another zone: no", "")
	at(w, p, "Crossroads", vec(18 + 10, 0, 18))
	local dirty0 = w.Dirty
	w:Tick(1)
	check(#w.Delivered == 1 and d.LostFound.Holding == nil, "exactly 10 studs: the 1 s loop pays by itself", show({ #w.Delivered, d.LostFound.Holding }))
	check(w.Dirty > dirty0, "the quest list is refreshed (the row goes)", show({ w.Dirty, dirty0 }))
	local hp, mp = w.Config.PotionStockKey("HP"), w.Config.PotionStockKey("MP")
	local gold, xp = w.Config.HuntValue(5, 2)
	local grants = {}
	for _, g in w.Grants do grants[g.Id] = (grants[g.Id] or 0) + g.N end
	check(grants.HP == 2 and grants.MP == 2 and grants.Enh70 == 1 and d[hp] == 2 and d[mp] == 2 and d.Items.Enh70 == 1,
		"a good turn-in: 2 HP + 2 MP potions + the day's first scroll", show({ grants, d.Items }))
	check(#w.XPs == 1 and w.XPs[1].N == xp and #w.Gold == 0, "XP = 2 minutes of hunting at Lv5 (" .. xp .. "), no gold", show({ plain(w.XPs), #w.Gold }))
	local line = notices(w, p)
	-- A23-130 (server text verdicts 2026-10-11): the reward parts only, no NPC thank-you lead
	check(not string.find(line, "Thank you", 1, true) and string.find(line, "HP Potion", 1, true)
		and string.find(line, "XP", 1, true), "the line says what it paid (no thank-you lead)", line)
	check(#w.LF.Rows(p, d) == 0 and w.Delivered[1].Id == "Teddy" and w.Delivered[1].Side == "Good" and w.Delivered[1].Leg == "Bench"
		and w.Delivered[1].Res.XP == xp and w.Delivered[1].Res.Gold == 0, "the row is gone; Delivered says what was paid", show(w.Delivered[1] and w.Delivered[1].Res))
	check(w.LF.Deliver(p) == false and #w.XPs == 1, "nothing is paid twice", "")
	-- the second find of the day has no scroll
	findNow(w, p, "SlimeMeadow")
	check(d.LostFound.Holding.First == false, "the day's second find is not the first", "")
	pick(w, p, "Good")
	at(w, p, "Crossroads", BENCH)
	w.Grants = {}
	w.LF.Deliver(p)
	local again = {}
	for _, g in w.Grants do again[g.Id] = (again[g.Id] or 0) + g.N end
	check(again.HP == 2 and again.MP == 2 and again.Enh70 == nil, "the second turn-in: potions only, no scroll", show(again))
end)

runGroup("the walk's end: the fee and the vault", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Horns", 12)
	findNow(w, p, "SlimeMeadow")
	pick(w, p, "Evil")
	at(w, p, "Crossroads", BENCH)
	check(w.LF.Deliver(p) == true, "the fee at the bench", "")
	local gold = w.Config.HuntValue(12, 2)
	check(#w.Gold == 1 and w.Gold[1].N == gold and w.Gold[1].Src == "Choice" and #w.XPs == 0 and #w.Grants == 0,
		"2 minutes of gold at Lv12 (" .. gold .. ") as source Choice, no XP, no items", show(plain(w.Gold)))
	check(string.find(notices(w, p), "Cheeky!", 1, true) == nil and string.find(notices(w, p), "+" .. w.Util.FormatNumber(gold) .. " gold", 1, true) ~= nil,
		"the fee line is the gold only (no 'Cheeky!')", notices(w, p))
	-- the vault: the player's OWN town
	local halo = lfWorld()
	local h, hd = hero(halo, 2, "Halo", 20)
	findNow(halo, h, "GoblinWoods")
	pick(halo, h, "Evil")
	at(halo, h, "HornsTown", vec(0, 0, 515))
	check(halo.LF.Deliver(h) == false, "a Halo player in the Horns town: no vault", "")
	at(halo, h, "Crossroads", BENCH)
	check(halo.LF.Deliver(h) == false, "the bench is not the vault", "")
	at(halo, h, "HaloTown", vec(0, 0, -515))
	halo:Tick(1)
	local g2 = halo.Config.HuntValue(20, 2)
	check(#halo.Delivered == 1 and halo.Delivered[1].Leg == "Vault" and halo.Gold[1].N == g2 and halo.Gold[1].Src == "Choice",
		"the Halo town: the trophy is stashed, 2 minutes of gold", show(plain(halo.Gold)))
	check(string.find(notices(halo, h), "in your vault now", 1, true) == nil and string.find(notices(halo, h), "+" .. halo.Util.FormatNumber(g2) .. " gold", 1, true) ~= nil,
		"the vault line is the gold only", notices(halo, h))
	local horns = lfWorld()
	local u, ud = hero(horns, 3, "Horns", 20)
	findNow(horns, u, "SkeletonRuins")
	pick(horns, u, "Evil")
	at(horns, u, "HaloTown", vec(0, 0, -515))
	check(horns.LF.Deliver(u) == false, "a Horns player in the Halo town: no", "")
	at(horns, u, "HornsTown", vec(0, 0, 515))
	check(horns.LF.Deliver(u) == true, "the Horns town is the Horns player's vault", "")
	-- good turn-ins never pay gold; a 2x pass changes nothing (the card sources are never boosted, XP is capped by its amount)
	local x2 = lfWorld({ XPMult = 2 })
	local v, vd = hero(x2, 4, "Halo", 5)
	findNow(x2, v, "SlimeMeadow")
	pick(x2, v, "Good")
	at(x2, v, "Crossroads", BENCH)
	x2.LF.Deliver(v)
	check(x2.XPs[1].Got == x2.XPs[1].N, "the 2x XP pass does not double it (the amount is its own cap)", show(plain(x2.XPs)))
end)

runGroup("a full bag, failures", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	d.Items = { Enh70 = w.Config.Loot.ItemCap }
	findNow(w, p, "SlimeMeadow")
	pick(w, p, "Good")
	at(w, p, "Crossroads", BENCH)
	check(w.LF.Deliver(p) == true and d.Items.Enh70 == w.Config.Loot.ItemCap and d.LostFound.Holding == nil, "a full scroll bag: paid anyway, nothing breaks", show(d.Items))
	local sell = lfWorld({ EditConfig = function(c) c.LostFound.Reward.Good = { Give = { Jelly = 3 } } end })
	local jp, jd = hero(sell, 8, "Halo", 5)
	jd.Items = { Jelly = sell.Config.Loot.ItemCap }
	findNow(sell, jp, "SlimeMeadow")
	pick(sell, jp, "Good")
	at(sell, jp, "Crossroads", BENCH)
	sell.LF.Deliver(jp)
	check(#sell.Gold == 1 and sell.Gold[1].N == 3 * sell.Config.Loot.Items.Jelly.Sell and sell.Gold[1].Src == "Choice",
		"what the bag cannot hold is paid at the sell price (3 Jelly x " .. sell.Config.Loot.Items.Jelly.Sell .. ") as Choice gold", show(plain(sell.Gold)))
	local f = lfWorld()
	local q, qd = hero(f, 2, "Halo", 5)
	findNow(f, q, "SlimeMeadow")
	pick(f, q, "Good")
	at(f, q, "Crossroads", BENCH)
	f.LootFails = true
	f.AllowWarn = "offline loot failure"
	check(f.LF.Deliver(q) == true and qd.LostFound.Holding == nil and #f.XPs == 1, "a failing item grant: the XP still comes, nothing is paid twice", "")
	local g = lfWorld()
	local r, rd = hero(g, 3, "Halo", 5)
	findNow(g, r, "SlimeMeadow")
	pick(g, r, "Evil")
	at(g, r, "Crossroads", BENCH)
	g.GoldFails = true
	g.AllowWarn = "offline gold failure"
	check(g.LF.Deliver(r) == true and rd.LostFound.Holding == nil and #g.Gold == 0, "a failing gold payment: the turn-in is done, the record is cleared", "")
	check(g.LF.Deliver(r) == false and #g.Gold == 0, "and it is never tried again", "")
end)

------------------------------------------------------------------ cards that wait, and the save
runGroup("switched off on the way", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	findNow(w, p, "SlimeMeadow")
	pick(w, p, "Good")
	at(w, p, "Crossroads", BENCH)
	w.Config.LostFound.Enabled = false
	w:Tick(1)
	check(#w.Delivered == 0 and d.LostFound.Holding ~= nil and #w.LF.Rows(p, d) == 0 and w.LF.Deliver(p) == false,
		"off: no row, no payment, the record waits", show(d.LostFound))
	w.Config.LostFound.Enabled = true
	w:Tick(1)
	check(#w.Delivered == 1 and d.LostFound.Holding == nil, "on again: the walk ends", "")
end)

runGroup("another card is open: the find waits for its card", function()
	local w = lfWorld()
	local p, d = hero(w, 1)
	w.Reg.ChoiceCard.Offer(p, "FlowerPatch", {})
	local flower = lastCard(w, p)
	check(findNow(w, p, "SlimeMeadow"), "a find while a flower card is open", "")
	check(d.LostFound.Holding.Phase == "Choose" and w.Reg.ChoiceCard.Pending(p) == "FlowerPatch" and #w:FxOf("Card", p) == 1,
		"the find is held; no second card opens over the first", show(d.LostFound.Holding))
	kill(w, p, "SlimeMeadow", 3)
	check(w.Reg.ChoiceCard.Pending(p) == "FlowerPatch" and #w:FxOf("Card", p) == 1, "still waiting while the flower card is open", "")
	w:Remote("CardAction", p, flower.Id, "Good")
	kill(w, p, "SlimeMeadow", 1)
	check(w.Reg.ChoiceCard.Pending(p) == "LostTeddy" and #w:FxOf("Card", p) == 2, "the next kill after the flower card: the teddy's card opens", "")
	kill(w, p, "SlimeMeadow", 5)
	check(#w:FxOf("Card", p) == 2, "and it opens once", "")
	check(d.LostFound.Holding.Phase == "Choose" and d.LostFound.N == 1, "still the same find", show(d.LostFound))
end)

runGroup("the save: a thing on its way survives the next join", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	findNow(w, p, "SlimeMeadow")
	pick(w, p, "Good")
	local saved = d.LostFound
	w:Leave(p)
	local q = hero(w, 2, "Halo", 5, { LostFound = saved })
	at(w, q, "Crossroads", BENCH)
	w:Tick(1)
	check(#w.Delivered == 1 and w.Data[q].LostFound.Holding == nil and #w.XPs == 1, "a new join: the walk goes on and ends at the bench", show(plain(w.Delivered)))
	-- a saved card waits too (the Choose phase)
	local r, rd = hero(w, 3, "Halo", 5)
	findNow(w, r, "SlimeMeadow")
	check(w.Reg.ChoiceCard.Pending(r) == "LostTeddy" and rd.Cards.Pending.Kind == "LostTeddy", "a saved Choose-phase card is in the save", show(rd.Cards))
end)

runGroup("a broken save is repaired", function()
	local w = lfWorld()
	local cases = {
		{ Day = "x", N = 99999, K = -5, Holding = "nonsense" },
		{ Day = 0, N = 0.7, K = 3.9, Holding = { Id = "Nope", Phase = "Carry", Side = "Good", Leg = "Bench" } },
		{ Holding = { Id = "Teddy", Phase = "Carry" } }, -- a walk without side or leg
		{ Holding = { Id = "Teddy", Phase = "Carry", Side = "Maybe", Leg = "Bench" } },
		{ Holding = { Id = "Teddy", Phase = "Sleeping" } },
		{ Holding = { Id = 5, Phase = "Choose" } },
		42,
	}
	for i, bad in cases do
		local p, d = hero(w, 10 + i, "Halo", 5)
		d.LostFound = bad
		local rows = w.LF.Rows(p, d)
		local st = d.LostFound
		check(#rows == 0 and type(st) == "table" and st.Holding == nil and st.N >= 0 and st.N <= 1000 and st.K >= 0 and st.K == math.floor(st.K),
			"a broken save " .. i .. ": repaired, no row", show(st))
	end
	local capped, cd = hero(w, 31)
	cd.LostFound = { Day = w.Config.DayIndex(w.Time), N = 99999, K = 1e9 }
	w.LF.Rows(capped, cd)
	check(cd.LostFound.N == 1000 and cd.LostFound.K == 1000000, "today's finds and the count are capped (1000 / 1,000,000)", show(cd.LostFound))
	local p, d = hero(w, 30)
	d.LostFound = { Day = w.Config.DayIndex(w.Time), N = 2, K = 61, Holding = { Id = "Teddy", Phase = "Carry", Side = "Good", Leg = "Bench", First = "yes" } }
	local rows = w.LF.Rows(p, d)
	check(#rows == 1 and d.LostFound.Holding.First == false and d.LostFound.N == 2 and d.LostFound.K == 61, "a good record is kept (First becomes a boolean)", show(d.LostFound))
end)

runGroup("debug aids", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	check(w.LF.DebugFind(p) == "found Teddy" and d.LostFound.Holding.Id == "Teddy", "DebugFind in a town: the first item", show(d.LostFound))
	check(w.LF.DebugFind(p) == "already holding Teddy", "one at a time", "")
	check(w.LF.DebugClear(p) == "cleared" and d.LostFound == nil, "DebugClear wipes the record", "")
	local q, qd = hero(w, 2, "Halo", 5)
	q:SetAttribute("ZoneId", "GoblinWoods")
	check(w.LF.DebugFind(q) == "found ClubBadge" and qd.LostFound.Holding.Id == "ClubBadge" and lastCard(w, q).Kind == "LostBadge",
		"DebugFind: the item of the zone, a real card", show(qd.LostFound))
	w.LF.DebugClear(q)
	check(w.LF.DebugFind(q, "GuardMedal") == "found GuardMedal" and qd.LostFound.Holding.Id == "GuardMedal", "an id names the item", "")
	local r = hero(w, 3, "Halo", 5)
	check(w.LF.DebugFind(r, "Nope") == "found Teddy", "an unknown id falls back to the zone's / first item", "")
end)

runGroup("leaving", function()
	local w = lfWorld()
	local p, d = hero(w, 1, "Halo", 5)
	findNow(w, p, "SlimeMeadow")
	pick(w, p, "Good")
	w:Leave(p)
	w:Tick(2)
	check(#w.Delivered == 0 and d.LostFound.Holding ~= nil, "a player who left is not paid", "")
end)

finish()
