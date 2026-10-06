-- town_quests_offline.luau : A23-46 town people sub quests H1 / R1 / N3 (story_depth §3 / §5-⑥, 검수 decisions) with
-- the engine parts they need (E4 Near.Stay, E6 per-pick rewards + LootService.GrantItem, quest NPC talk), and the
-- A23-57 artisan guild switch (Config.Features.NeutralFaction off: no new Neutral pick at the picker / altar / rebirth,
-- its own quests not offered). tools/test_town_quests.py binds the dev2_combat_world sources (the real
-- StoryQuestService, LootService, CombatService) + FACTION_EXTRACT and REBIRTH_EXTRACT; this file follows the world.

local SQ0 = C0.StoryQuests
local GOOD, EVIL = { Item = "Enh70", N = 1 }, { Potion = "HP", N = 3, Gold = 60 }

-- a started story world: StoryQuestService.Start connects its remote + signals (the 1 s loop is never run: Refresh is
-- called by hand), XP is recorded, the zone and the quest NPCs are scripted
local function townWorld(o)
	o = o or {}
	local w = bareWorld({})
	local reg = w.Registry
	local Signal = w.Util.Signal
	reg.ZoneService.ZoneChanged = Signal.new()
	reg.ZoneService.GetZoneId = function(p) return (w.ZoneOf and w.ZoneOf[p]) or "SlimeMeadow" end
	reg.GooseService.GooseFinished = Signal.new()
	w.XP, w.ZoneOf, w.Npcs, w.Opened, w.RankCalls = {}, {}, {}, {}, {}
	reg.RankingService = setmetatable({}, { __index = function(_, key)
		return function(...) table.insert(w.RankCalls, { Key = key, N = select("#", ...) }) end
	end })
	-- the shared workspace double: StoryQuestService.visible (the goose sub S1) looks for a GameState folder there
	local ws = w:Env().workspace
	ws.FindFirstChild = function() return nil end
	local rs = w.Services.ReplicatedStorage
	if not rs.FindFirstChild then rs.FindFirstChild = function() return nil end end
	reg.ProgressionService.AddXP = function(p, n) table.insert(w.XP, { P = p, N = n }) end
	if o.Npcs ~= false then
		w.Services.CollectionService = { GetTagged = function(_, tag)
			local out = {}
			if tag == SQ0.NpcTag then for _, n in w.Npcs do table.insert(out, n) end end
			return out
		end }
	end
	w.Story.Start()
	w.Spawned = {}
	-- the client's OpenPanel "Story" pops (a quest NPC step must never pop by itself)
	w.Net.Get("OpenPanel")
	function w:Npc(id, pos)
		local part = newInstance("Part", self)
		part.Name, part.Position = "Npc" .. id, pos
		part.Attrs.NpcId = id
		table.insert(self.Npcs, part)
		return part
	end
	function w:MoveTo(p, pos)
		p.Character:FindFirstChild("HumanoidRootPart").Position = pos
	end
	function w:Act(p, id, action, option)
		self:Advance(1) -- RateLimits.StoryAction
		self.Net.Get("StoryAction").OnServerEvent:Fire(p, id, action, option)
		self:Flush()
	end
	function w:Tick(p, seconds)
		for _ = 1, seconds or 1 do
			self:Advance(1)
			self.Story.Refresh(p)
		end
	end
	function w:Kill(p, kind, n)
		for _ = 1, n or 1 do
			reg.MonsterService.MonsterKilled:Fire(p, { Kind = kind, ZoneId = "SlimeMeadow", Golden = false, Personal = false,
				Position = vec(0, 0, 0), WarPoints = 0 })
		end
		self:Flush()
	end
	function w:Track(d, id) return d.Story and d.Story.Subs and d.Story.Subs[id] end
	function w:Opens(from)
		local n = 0
		for i = (from or 0) + 1, #self.Fired do
			if self.Fired[i].Remote == "OpenPanel" and self.Fired[i].Payload == "Story" then n += 1 end
		end
		return n
	end
	return w
end

-- a ready player who finished M2_3 (chapter 2's fountain) standing at `pos`
local function joinAfterM23(w, userId, faction, o)
	o = o or {}
	local done = { M1_1 = true, M1_2 = true, M1_3 = true, M1_4 = true, M2_1 = true, M2_2 = true, M2_3 = true }
	if o.Before then done = { M1_1 = true, M1_2 = true } end
	local p, d = w:Join(userId, { Faction = faction, Class = o.Class or "Warrior", Level = o.Level or 6, Pos = o.Pos,
		Data = { Story = { Main = { Id = "" }, Subs = {}, Done = done, Pick = {}, First = { Migrated = true } } } })
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end

local function sameReward(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for k, v in a do if b[k] ~= v then return false end end
	for k, v in b do if a[k] ~= v then return false end end
	return true
end

------------------------------------------------------------------ 1. data
runGroup("config", function()
	local SQ = SQ0
	local subs = {}
	for _, id in SQ.Subs do subs[id] = true end
	check(subs.H1 and subs.R1 and subs.N3, "H1 / R1 / N3 are in StoryQuests.Subs", show(SQ.Subs))
	local want = { H1 = { Halo = true }, R1 = { Horns = true }, N3 = "everyone" }
	for id, factions in want do
		local def = SQ.Defs[id]
		local who = factions == "everyone" and def and def.Factions == nil or (def and sameReward(def.Factions, factions))
		check(def and def.Kind == "Sub" and who, id .. ": a sub for " .. show(factions), show(def and def.Factions))
		check(def and def.Requires and def.Requires.Done and def.Requires.Done[1] == "M2_3" and #def.Requires.Done == 1,
			id .. ": opens after M2_3 (검수: the three at the same time)", show(def and def.Requires))
		check(def and def.Reward and def.Reward.GoldN == 120 and def.Reward.XPBar == 0.5 and def.Reward.Gold == nil,
			id .. ": 120 gold + half a level bar of XP", show(def and def.Reward))
		local last = def and def.Steps[#def.Steps]
		local obj = last and last.Obj
		check(obj and obj.Type == "Choice" and last.Npc ~= nil and last.Panel == true, id .. ": ends with a pick at its NPC",
			show(last and { last.Npc, obj and obj.Type }))
		check(obj and obj.Good and obj.Evil and sameReward(obj.Good.Reward, GOOD) and sameReward(obj.Evil.Reward, EVIL)
			and obj.Good.Points == 1 and obj.Evil.Points == 1,
			id .. ": A = one 70% scroll, B = 3 HP potions + 60 gold; 1 honor / infamy point", show(obj and { obj.Good, obj.Evil }))
		local first = def and def.Steps[1]
		check(first and first.Obj.Type == "Talk" and first.Npc == last.Npc and SQ.Speakers[first.Npc] ~= nil and def.Speaker == first.Npc,
			id .. ": starts by talking to the same NPC (a speaker name)", show(first and first.Npc))
		check(def and type(def.Finish) == "string" and string.find(def.Finish, "?", 1, true) ~= nil,
			id .. ": the last line is a question (story_depth §1)", def and def.Finish)
	end
	check(SQ.Defs.N3.Steps[#SQ.Defs.N3.Steps].Obj.Neutral ~= nil, "N3 keeps A / B labels for a Neutral save")
	-- the steps 검수 set: H1 spies 10 s at the woods' edge, then 2 king slimes; R1 listens 15 s at the fountain, then 6 slimes
	local h1, r1 = SQ.Defs.H1.Steps, SQ.Defs.R1.Steps
	check(h1[2].Obj.Type == "Near" and h1[2].Obj.Spot == "WoodsGate" and h1[2].Obj.Stay == 10
		and h1[3].Obj.Type == "Kill" and h1[3].Obj.Kind == "BigSlime" and h1[3].Obj.Count == 2 and h1[3].Obj.Zone == "SlimeMeadow",
		"H1: Near WoodsGate Stay 10 -> King Slime 2 (meadow)", show({ h1[2].Obj, h1[3].Obj }))
	check(r1[2].Obj.Type == "Near" and r1[2].Obj.Spot == "Fountain" and r1[2].Obj.Stay == 15 and r1[2].Obj.Zone == "Crossroads"
		and r1[3].Obj.Kind == "Slime" and r1[3].Obj.Count == 6, "R1: Near Fountain Stay 15 -> Slime 6", show({ r1[2].Obj, r1[3].Obj }))
	-- the spots: in the open (never a PvP zone or a town), each next to its bridge end
	local L = SQ.Landmarks
	local function bridge(name)
		for _, b in C0.Map.Bridges do if b.Name == name then return b end end
		return nil
	end
	check(L.WoodsGate and C0.ZoneAt(L.WoodsGate).PvP == false and C0.ZoneAt(L.WoodsGate).Town == false
		and C0.ZoneAt(L.WoodsGate).MinLevel <= 1, "WoodsGate is outside the PvP woods and every level gate",
		show(L.WoodsGate and C0.ZoneAt(L.WoodsGate).Id))
	local near = function(a, b, r) return a and b and math.abs(a.X - b.X) + math.abs(a.Z - b.Z) <= r end
	check(near(L.WoodsGate, bridge("Goblin").From, 20) and near(L.HaloBridge, bridge("Halo").From, 20)
		and near(L.HornsBridge, bridge("Horns").From, 20), "each spot stays within 20 studs of its bridge end (Config.Map.Bridges)",
		show({ L.WoodsGate, L.HaloBridge, L.HornsBridge }))
	check(SQ.NpcTag == "StoryNpc" and SQ.NpcRange == 16, "NPC contract: tag StoryNpc + attribute NpcId, 16 studs", show({ SQ.NpcTag, SQ.NpcRange }))
end)

------------------------------------------------------------------ 2. who gets what, when
runGroup("offered", function()
	local w = townWorld()
	local halo, hd = joinAfterM23(w, 101, "Halo")
	local _, rd = joinAfterM23(w, 102, "Horns")
	local _, ed = joinAfterM23(w, 103, "Halo", { Before = true })
	check(w:Track(hd, "H1") and w:Track(hd, "N3") and not w:Track(hd, "R1"), "a Halo player after M2_3: H1 + N3", show(hd.Story.Subs))
	check(w:Track(rd, "R1") and w:Track(rd, "N3") and not w:Track(rd, "H1"), "a Horns player after M2_3: R1 + N3", show(rd.Story.Subs))
	check(not w:Track(ed, "H1") and not w:Track(ed, "N3"), "before M2_3: none of them", show(ed.Story.Subs))
	-- A23-57: an old Neutral save still gets N3, never the artisan-only N1 / N2 while the switch is off
	local _, gd = joinAfterM23(w, 104, "Neutral")
	check(w:Track(gd, "N3") and not w:Track(gd, "N1") and not w:Track(gd, "N2"), "a Neutral save (switch off): N3, not N1 / N2",
		show(gd.Story.Subs))
	local w2 = townWorld()
	w2.Config.Features.NeutralFaction = true
	local _, gd2 = joinAfterM23(w2, 105, "Neutral")
	check(w2:Track(gd2, "N1") and w2:Track(gd2, "N2") and w2:Track(gd2, "N3"), "switch on: N1 / N2 come back (data kept)",
		show(gd2.Story.Subs))
	-- the row carries the NPC (game dev 1 puts '!' over it) and a waiting talk never pops a window by itself
	local rows = w.Story.SubRows(halo, hd)
	local h1row = nil
	for _, r in rows do if r.Story and r.Story.Id == "H1" then h1row = r end end
	check(h1row and h1row.Story.Npc == "Bright" and h1row.Story.Guide == "HaloTown" and h1row.Text == SQ0.Defs.H1.Steps[1].Text,
		"the H1 row: 'Talk to Bright' with Story.Npc = Bright", show(h1row and h1row.Story))
end)

------------------------------------------------------------------ 3. H1 all the way (A side)
runGroup("h1-good", function()
	local w = townWorld()
	w:Npc("Bright", vec(0, 0, -400))
	local p, d = joinAfterM23(w, 201, "Halo", { Pos = vec(0, 0, -300) })
	local tr = w:Track(d, "H1")
	-- the NPC is in the world: talking from far away does nothing, next to it works
	w:Act(p, "H1", "Talk")
	check(tr.St == 1, "Talk 100 studs from Bright: refused", tr.St)
	w:Act(p, "H1", "Open")
	check(w:Opens(0) == 0, "Open from far away: no window", w:Opens(0))
	w:MoveTo(p, vec(4, 0, -396))
	w:Act(p, "H1", "Open")
	check(w:Opens(0) == 1, "Open next to Bright: the talk window", w:Opens(0))
	w:Act(p, "H1", "Talk")
	check(tr.St == 2, "Talk next to Bright: step 2", tr.St)
	-- E4: 10 s in one go at the woods' edge; leaving starts again
	local gate = SQ0.Landmarks.WoodsGate
	w:MoveTo(p, vec(gate.X + 3, 0, gate.Z))
	w:Tick(p, 6)
	for _ = 1, 4 do w.Story.Refresh(p) end -- on-demand refreshes (a zone change, a level up) in the same second
	check(tr.P == 5, "the count is time, not refreshes (6 ticks, 4 extra refreshes: 5 s)", tr.P)
	w.Config.StoryQuests.MaxSubs = 9 -- every sub row (the list shows 2; this checks the row itself)
	local row = nil
	for _, r in w.Story.SubRows(p, d) do if r.Story and r.Story.Id == "H1" then row = r end end
	check(tr.St == 2 and tr.P >= 5 and row and row.Target == 10 and row.Progress == tr.P
		and row.Text == string.format(SQ0.Defs.H1.Steps[2].Text, tr.P, 10), "the row counts the seconds (%d/%d s)",
		show({ tr.P, row and row.Text }))
	w:MoveTo(p, vec(gate.X + 40, 0, gate.Z))
	w:Tick(p, 1)
	check(tr.St == 2 and tr.P == 0, "stepping away resets the count", show({ tr.St, tr.P }))
	w:MoveTo(p, vec(gate.X, 0, gate.Z + 5))
	w:Tick(p, 9)
	check(tr.St == 2, "9 s is not enough", show({ tr.St, tr.P }))
	w:Tick(p, 2)
	check(tr.St == 3, "10 s in one go: step 3", show({ tr.St, tr.P }))
	-- 2 king slimes, then the pick waits at Bright (no window pops by itself)
	local opens = w:Opens(0)
	w:Kill(p, "BigSlime", 2)
	check(tr.St == 4 and w:Opens(0) == opens, "2 king slimes: step 4 waits at Bright (no pop-up)", show({ tr.St, w:Opens(0) - opens }))
	w:MoveTo(p, vec(-60, 0, -380))
	w:Act(p, "H1", "Choose", "Good")
	check(tr.St == 4 and d.Story.Pick.H1 == nil, "choosing far from Bright: refused", show({ tr.St, d.Story.Pick.H1 }))
	w:MoveTo(p, vec(2, 0, -402))
	local enh, bank, honor, xpN, n0 = d.Items and d.Items.Enh70 or 0, d.BankGold or 0, d.Honor or 0, #w.XP, #w.Notices
	local hp = d.HPPotionCount or 0
	w:Act(p, "H1", "Choose", "Good")
	check(d.Story.Pick.H1 == "Good" and (d.Honor or 0) == honor + 1, "A: Pick 'Good', honor +1", show({ d.Story.Pick.H1, d.Honor }))
	check((d.Items.Enh70 or 0) == enh + 1 and (d.HPPotionCount or 0) == hp, "A: one 70% scroll (no potions)",
		show({ d.Items.Enh70, d.HPPotionCount }))
	local wantXP = math.floor(w.Config.XPToNext(6) * 0.5)
	check(d.BankGold == bank + 120 and #w.XP == xpN + 1 and w.XP[#w.XP].N == wantXP, "the quest: +120 gold, +half a Lv6 bar of XP",
		show({ d.BankGold - bank, w.XP[#w.XP] and w.XP[#w.XP].N, wantXP }))
	check(d.Story.Done.H1 == true and w:Track(d, "H1") == nil, "H1 done (once)")
	local lines = w:NoticesFor(p, n0)
	local hasFinish, hasScroll = false, false
	for _, t in lines do
		if t == SQ0.Defs.H1.Finish then hasFinish = true end
		if t == string.format(w.Config.Loot.Text.Got, w.Config.Loot.Items.Enh70.Name) then hasScroll = true end
	end
	check(hasFinish and hasScroll, "lines: '+Enhance Scroll 70%' and the closing question", show(lines))
	local clueAt, finishAt = nil, nil
	for i, t in lines do
		if t == SQ0.Defs.H1.Clue then clueAt = i end
		if t == SQ0.Defs.H1.Finish then finishAt = i end
	end
	check(clueAt ~= nil and finishAt ~= nil and clueAt > finishAt, "the wristband clue comes after the closing lines", show(lines))
	local before = { d.BankGold, d.Items.Enh70 }
	w:Act(p, "H1", "Choose", "Evil")
	check(d.BankGold == before[1] and d.Items.Enh70 == before[2], "a second pick after the end pays nothing")
end)

------------------------------------------------------------------ 4. R1 (B side) + E6 potions
runGroup("r1-evil", function()
	local w = townWorld() -- NPCs are tagged, but Smokey is not placed yet: talking works anywhere
	w:Npc("Bright", vec(0, 0, -400))
	local p, d = joinAfterM23(w, 301, "Horns", { Pos = vec(500, 0, 500) })
	local tr = w:Track(d, "R1")
	w:Act(p, "R1", "Talk")
	check(tr.St == 2, "Smokey not placed yet (only Bright is): the talk works anywhere", tr.St)
	local fountain = SQ0.Landmarks.Fountain
	w:MoveTo(p, fountain)
	w.ZoneOf[p] = "SlimeMeadow"
	w:Tick(p, 16)
	check(tr.St == 2 and tr.P == 0, "the fountain spot counts only in the Crossroads zone", show({ tr.St, tr.P }))
	w.ZoneOf[p] = "Crossroads"
	w:Tick(p, 14)
	check(tr.St == 2, "14 s at the fountain is not enough", tr.P)
	w:Tick(p, 2)
	check(tr.St == 3, "15 s: step 3", show({ tr.St, tr.P }))
	w:Kill(p, "Slime", 5)
	check(tr.St == 3 and tr.P == 5, "5 slimes", tr.P)
	w:Kill(p, "Slime", 1)
	check(tr.St == 4, "6 slimes: step 4", tr.St)
	local bank, infamy, enh, hp = d.BankGold or 0, d.Infamy or 0, d.Items and d.Items.Enh70 or 0, d.HPPotionCount or 0
	w:Act(p, "R1", "Choose", "Evil")
	check(d.Story.Pick.R1 == "Evil" and (d.Infamy or 0) == infamy + 1, "B: Pick 'Evil', infamy +1", show({ d.Story.Pick.R1, d.Infamy }))
	check((d.HPPotionCount or 0) == hp + 3 and (d.Items.Enh70 or 0) == enh and d.BankGold == bank + 60 + 120,
		"B: 3 HP potions + 60 gold (then the quest's 120)", show({ d.HPPotionCount - hp, d.BankGold - bank }))
	check(d.Story.Done.R1 == true, "R1 done")
end)

------------------------------------------------------------------ 5. N3 for a Halo player and a Neutral save
runGroup("n3", function()
	local w = townWorld({ Npcs = false })
	local p, d = joinAfterM23(w, 401, "Halo")
	local tr = w:Track(d, "N3")
	w:Act(p, "N3", "Talk")
	w:MoveTo(p, SQ0.Landmarks.HaloBridge)
	w:Tick(p, 1)
	check(tr.St == 3, "the Halo bridge: a plain Near (arrive = done)", tr.St)
	w:MoveTo(p, SQ0.Landmarks.HornsBridge)
	w:Tick(p, 1)
	check(tr.St == 4, "the Horns bridge", tr.St)
	w.Registry.ProgressionService.GoldEarned:Fire(p, 30, "Monster")
	w:Flush()
	check(tr.St == 5, "30 hunting gold", tr.St)
	local enh = d.Items and d.Items.Enh70 or 0
	w:Act(p, "N3", "Choose", "Good")
	check(d.Story.Pick.N3 == "Good" and (d.Items.Enh70 or 0) == enh + 1 and d.Story.Done.N3, "a Halo player picks A: the scroll",
		show({ d.Story.Pick.N3, d.Items.Enh70 }))
	-- an old Neutral save: A / B, recorded only (no score), A = Good's reward, B = Evil's
	local q, e = joinAfterM23(w, 402, "Neutral")
	local tq = w:Track(e, "N3")
	tq.St = #SQ0.Defs.N3.Steps
	local bank, honor = e.BankGold or 0, e.Honor or 0
	w:Act(q, "N3", "Choose", "Good")
	check(tq.St == #SQ0.Defs.N3.Steps and e.Story.Pick.N3 == nil, "a Neutral save cannot send Good / Evil", show(e.Story.Pick.N3))
	w:Act(q, "N3", "Choose", "B")
	check(e.Story.Pick.N3 == "B" and (e.Honor or 0) == honor and (e.Infamy or 0) == 0 and (e.HPPotionCount or 0) == 3
		and e.BankGold == bank + 60 + 120, "Neutral B: recorded, no score, Evil's reward", show({ e.Story.Pick.N3, e.HPPotionCount, e.BankGold - bank }))
end)

------------------------------------------------------------------ 5b. A23-58: an off-side pick lowers my own score
-- (a player standing at the last step of a quest, its NPC not placed: the pick only)
local function atPick(w, userId, faction, quest, stats)
	local p, d = joinAfterM23(w, userId, faction)
	for k, v in stats or {} do
		d[k] = v
		p:SetAttribute(k, v)
	end
	local tr = w:Track(d, quest)
	tr.St = #SQ0.Defs[quest].Steps
	return p, d, tr
end

runGroup("a23-58", function()
	local w = townWorld({ Npcs = false })
	local T = w.Config.StoryQuests.Text
	local function lines(p, from) return w:NoticesFor(p, from) end
	local function has(list, text)
		for _, t in list do if t == text then return true end end
		return false
	end
	-- Halo, angel pick: honor up, infamy never moves
	local p1, d1 = atPick(w, 801, "Halo", "H1", { Honor = 5, Infamy = 3 })
	w:Act(p1, "H1", "Choose", "Good")
	check(d1.Honor == 6 and d1.Infamy == 3, "Halo + angel pick: Honor +1, Infamy untouched", show({ d1.Honor, d1.Infamy }))
	-- Halo, devil pick: my honor down (never the other side's infamy up), items and gold as before
	local n2 = #w.Notices
	local p2, d2 = atPick(w, 802, "Halo", "H1", { Honor = 5, Infamy = 0 })
	local hp, bank = d2.HPPotionCount or 0, d2.BankGold or 0
	w:Act(p2, "H1", "Choose", "Evil")
	check(d2.Honor == 4 and (d2.Infamy or 0) == 0, "Halo + devil pick: Honor -1, Infamy stays 0", show({ d2.Honor, d2.Infamy }))
	check((d2.HPPotionCount or 0) == hp + 3 and d2.BankGold == bank + 60 + 120, "the B reward is paid as usual",
		show({ d2.HPPotionCount - hp, d2.BankGold - bank }))
	local l2 = lines(p2, n2)
	check(has(l2, string.format(T.OffSideHalo, 1)) and not has(l2, T.RankDownHalo), "'Not very angel-like! Honor -1', no rank line (5 -> 4)",
		show(l2))
	-- at 0 nothing to take: no line, never below 0
	local n3 = #w.Notices
	local p3, d3 = atPick(w, 803, "Halo", "H1", { Honor = 0 })
	w:Act(p3, "H1", "Choose", "Evil")
	check((d3.Honor or 0) == 0 and not has(lines(p3, n3), string.format(T.OffSideHalo, 1)), "Honor 0 stays 0 (no line)",
		show({ d3.Honor, lines(p3, n3) }))
	-- 10 -> 9: the Knight rank drops to Squire: one line
	local n4 = #w.Notices
	local p4, d4 = atPick(w, 804, "Halo", "H1", { Honor = 10 })
	local _, before = w.Config.GetTitle("Halo", 10, 0)
	w:Act(p4, "H1", "Choose", "Evil")
	local _, after = w.Config.GetTitle("Halo", d4.Honor, 0)
	check(d4.Honor == 9 and after < before and has(lines(p4, n4), T.RankDownHalo), "Honor 10 -> 9: the rank drops, one line",
		show({ d4.Honor, before, after, lines(p4, n4) }))
	-- Horns: devil pick up, angel pick down (honor never moves)
	local p5, d5 = atPick(w, 805, "Horns", "R1", { Infamy = 3, Honor = 2 })
	w:Act(p5, "R1", "Choose", "Evil")
	check(d5.Infamy == 4 and d5.Honor == 2, "Horns + devil pick: Infamy +1, Honor untouched", show({ d5.Infamy, d5.Honor }))
	local n6 = #w.Notices
	local p6, d6 = atPick(w, 806, "Horns", "R1", { Infamy = 10, Honor = 0 })
	w:Act(p6, "R1", "Choose", "Good")
	local l6 = lines(p6, n6)
	check(d6.Infamy == 9 and (d6.Honor or 0) == 0, "Horns + angel pick: Infamy -1, Honor stays 0", show({ d6.Infamy, d6.Honor }))
	check(has(l6, string.format(T.OffSideHorns, 1)) and has(l6, T.RankDownHorns), "'Too nice for a devil! Infamy -1' + the rank line (10 -> 9)",
		show(l6))
	-- N3 for both sides follows the same rule; a Neutral save only records
	local p7, d7 = atPick(w, 807, "Horns", "N3", { Infamy = 4 })
	w:Act(p7, "N3", "Choose", "Good")
	check(d7.Infamy == 3 and d7.Story.Pick.N3 == "Good", "N3, Horns angel pick: Infamy -1", show({ d7.Infamy, d7.Story.Pick.N3 }))
	local p8, d8 = atPick(w, 808, "Neutral", "N3", { Honor = 5, Infamy = 5 })
	w:Act(p8, "N3", "Choose", "A")
	check(d8.Honor == 5 and d8.Infamy == 5 and d8.Story.Pick.N3 == "A", "a Neutral save: recorded only", show({ d8.Honor, d8.Infamy }))
	check(#w.RankCalls == 0, "no pick reaches the weekly boards (A23-23 D1)", show(w.RankCalls))
end)

------------------------------------------------------------------ 5c. story_depth §2-1 clue lines (beta)
runGroup("clues", function()
	local C, SQ = C0, SQ0
	check(SQ.Speakers.Kids == "Bright & Smokey" and SQ.Landmarks.KidsBench and SQ.Landmarks.KidsBench.X == 18
		and SQ.Landmarks.KidsBench.Z == 18, "Speakers.Kids + Landmarks.KidsBench (18, 0, 18)", show(SQ.Landmarks.KidsBench))
	check(#C.Story.OpeningRumor == 3 and string.find(C.Story.OpeningRumor[1], "They say", 1, true) == 1
		and #C.Story.Premise == 3 and C.Story.OpeningAsk == "Which side will you choose?", "opening: 3 rumor lines, 3 premise lines, the ask",
		show({ C.Story.OpeningRumor, C.Story.OpeningAsk }))
	for _, line in C.Story.Premise do
		check(not string.find(line, "two kids", 1, true) and not string.find(line, "Bright", 1, true), "the opening never tells the truth",
			line)
	end
	check(string.find(SQ.Defs.M1_2.Finish, "braided band", 1, true) ~= nil, "M1_2: the braided band", SQ.Defs.M1_2.Finish)
	check(string.find(SQ.Defs.M2_3.Finish or "", "Two kids", 1, true) ~= nil, "M2_3: two kids run off", SQ.Defs.M2_3.Finish)
	check(string.find(SQ.Defs.H1.Clue or "", "wristband", 1, true) ~= nil and string.find(SQ.Defs.R1.Clue or "", "wristband", 1, true) ~= nil,
		"H1 / R1: the wristband toasts", show({ SQ.Defs.H1.Clue, SQ.Defs.R1.Clue }))
	local function anyLine(def, word)
		for _, step in def.Steps do
			for _, list in step.Lines or {} do
				for _, l in list do if string.find(l, word, 1, true) then return true end end
			end
		end
		return false
	end
	check(anyLine(SQ.Defs.H1, "Page 12") and anyLine(SQ.Defs.H1, "Happy birthday, S.") and anyLine(SQ.Defs.R1, "signed 'B.'")
		and anyLine(SQ.Defs.R1, "gold spyglass") and anyLine(SQ.Defs.N3, "two kids"), "H1 / R1 / N3 carry their clues")
	check(anyLine(SQ.Defs.M1_4, "What will you do with the next one?") and anyLine(SQ.Defs.M2_7, "why would a goblin need dust?"),
		"chapter-end questions (M1_4, M2_7)")
end)

------------------------------------------------------------------ 5d. story_depth E0: old saves skip only the chapters below them
runGroup("e0-old-saves", function()
	local w = townWorld({ Npcs = false })
	local SQ = w.Config.StoryQuests
	-- chapter 3 / 4 mains as they will come (test-only defs on this world's Config)
	SQ.Defs.M3_T = { Kind = "Main", Chapter = 3, Title = "Test Chapter 3", Steps = { { Text = "Lv%d", Obj = { Type = "Level", Level = 99 } } } }
	SQ.Defs.M4_T = { Kind = "Main", Chapter = 4, Title = "Test Chapter 4", Steps = { { Text = "Lv%d", Obj = { Type = "Level", Level = 99 } } } }
	table.insert(SQ.Main, "M3_T")
	table.insert(SQ.Main, "M4_T")
	check(SQ.SkipChapters and #SQ.SkipChapters == 2, "Config.StoryQuests.SkipChapters (Lv10 -> 2, Lv25 -> 3)", show(SQ.SkipChapters))
	local function oldSave(userId, level, migrated)
		local data = { Story = migrated and { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = { Migrated = true } } or nil }
		local p, d = w:Join(userId, { Faction = "Halo", Level = level, Data = data })
		w.Story.Refresh(p)
		return p, d
	end
	local _, a = oldSave(901, 12)
	check(a.Story.Done.M2_7 and a.Story.Done.M1_1 and not a.Story.Done.M3_T and a.Story.Main.Id == "M3_T",
		"an old Lv12 save: chapters 1-2 done, chapter 3 starts", show({ a.Story.Main.Id, a.Story.Done.M3_T }))
	local _, b = oldSave(902, 30)
	check(b.Story.Done.M3_T and not b.Story.Done.M4_T and b.Story.Main.Id == "M4_T", "an old Lv30 save: chapters 1-3 done, chapter 4 starts",
		show({ b.Story.Main.Id, b.Story.Done.M4_T }))
	local _, c = oldSave(903, 5)
	check(not c.Story.Done.M1_1 and c.Story.Main.Id == "M1_1", "a Lv5 save starts at the beginning", show(c.Story.Main.Id))
	local _, e = oldSave(904, 12, true)
	check(next(e.Story.Done) == nil and e.Story.Main.Id == "M1_1", "a save that already went through the migration is not skipped again",
		show(e.Story.Main.Id))
	local gold = { a.BankGold or 0, b.BankGold or 0 }
	check(gold[1] == 0 and gold[2] == 0 and (a.Honor or 0) == 0 and #w.XP == 0, "skipped chapters pay nothing", show({ gold, a.Honor, #w.XP }))
end)

------------------------------------------------------------------ 6. LootService.GrantItem (E6)
runGroup("grant-item", function()
	local w = townWorld({ Npcs = false })
	local p, d = joinAfterM23(w, 501, "Halo")
	local G = w.Loot.GrantItem
	check(G(p, "Enh70", 2) == 2 and d.Items.Enh70 == 2, "2 scrolls", show(d.Items))
	check(G(p, "HP", 3) == 3 and d.HPPotionCount == 3 and p:GetAttribute("HPPotionCount") == 3, "3 HP potions (the attribute too)",
		show({ d.HPPotionCount, p:GetAttribute("HPPotionCount") }))
	check(G(p, "Dragon", 1) == 0 and G(p, "Enh70", 0) == 0 and G(p, "Enh70", 100) == 0 and G(p, "Enh70", 0 / 0) == 0
		and G(p, nil, 1) == 0 and d.Items.Enh70 == 2, "bad id / count: nothing")
	d.HPPotionCount = w.Config.Vitals.PotionInventoryCap - 1
	check(G(p, "HP", 3) == 1 and d.HPPotionCount == w.Config.Vitals.PotionInventoryCap, "potions stop at the cap",
		d.HPPotionCount)
	local q = w:NewPlayer(599, {})
	check(G(q, "Enh70", 1) == 0, "no data: nothing")
end)

------------------------------------------------------------------ 7. A23-57 the artisan guild switch
runGroup("neutral-switch", function()
	local C = C0
	check(C.Features and C.Features.NeutralFaction == false and C.FeatureOn("NeutralFaction") == false,
		"Config.Features.NeutralFaction = false (beta)", show(C.Features))
	check(C.Pickable("Halo") and C.Pickable("Horns") and not C.Pickable("Neutral") and not C.Pickable("None")
		and not C.Pickable("Dragon") and not C.Pickable(nil), "Pickable: Halo / Horns only")
	local on = execute("Config", CONFIG_SOURCE, nativeEnv())
	on.Features.NeutralFaction = true
	check(on.Pickable("Neutral") and on.Factions.Neutral ~= nil, "switch on: Neutral pickable again (data kept)")
	-- FactionService: the picker and the altar refuse Neutral (ignored + a log line); Halo still works
	local w = newWorld({})
	local set, rate, warned = {}, {}, {}
	local S = { PlayerService = { IsReady = function() return true end, SetStat = function() end, Respawn = function() end },
		JusticeService = { GetWeakerFaction = function() return "None" end }, ProgressionService = { AddBankGold = function() end } }
	local FS = { GetFaction = function(p) return p:GetAttribute("Faction") or "None" end,
		SetFaction = function(p, f) table.insert(set, { P = p, F = f }); p:SetAttribute("Faction", f) end }
	local util = setmetatable({ RateLimit = function(_, key) table.insert(rate, key); return true end,
		Warn = function(_, msg) table.insert(warned, msg) end }, { __index = w.Util })
	local F = execute("FactionService.extract", FACTION_EXTRACT, w:Env(), w.Config, util, S, FS, function() return false end)
	local a = w:NewPlayer(601, { Faction = "None" })
	local function picked()
		local out = {}
		for _, s in set do table.insert(out, s.F) end
		return out
	end
	F.Choose(a, "Neutral")
	check(#set == 0 and #rate == 0, "the faction picker: Neutral is ignored", show(picked()))
	check(#warned == 1 and string.find(warned[1], "A23-57", 1, true) ~= nil, "…with one log line", show(warned))
	F.Choose(a, "Halo")
	check(#set == 1 and set[1].F == "Halo", "Halo is still taken", show(picked()))
	local b = w:NewPlayer(602, { Faction = "Halo" })
	F.Switch(b, false, "Neutral")
	check(#rate == 1, "the altar: a Neutral target stops before anything else", show(rate))
	F.Switch(b, false, "Horns")
	check(#rate == 2, "a Horns target goes on to the altar checks", show(rate))
	-- rebirth into the guild is refused too
	local reb = execute("ProgressionService.extract", REBIRTH_EXTRACT, w:Env(), w.Config, util, {
		GrudgeService = { HasSack = function() return false end }, KaijuService = { GetState = function() return "None" end },
		CombatService = { IsInCombat = function() return false end } }, function() return { Level = 1, Rebirths = 0 } end)
	local okN, whyN = reb.TryRebirth(b, "Neutral")
	local okH, whyH = reb.TryRebirth(b, "Halo")
	check(okN == false and whyN == nil and string.find(warned[#warned], "reborn", 1, true) ~= nil,
		"rebirth into the guild: refused quietly + logged", show({ okN, whyN, warned[#warned] }))
	check(okH == false and type(whyH) == "string" and string.find(whyH, "Lv", 1, true) ~= nil,
		"rebirth into Halo goes on to its normal checks (here: the level)", show({ okH, whyH }))
end)

finish()
