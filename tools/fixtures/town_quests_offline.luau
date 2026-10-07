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
	w.Config.StoryQuests.MaxSubs = 20 -- the row itself (A23-56's other new offers share the 3 list rows)
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
	w.Config.StoryQuests.MaxSubs = 9 -- every sub row (this checks the row itself, not the list length)
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
	-- the real chapter 3 + a chapter 4 main as it will come (a test-only def on this world's Config)
	SQ.Defs.M4_T = { Kind = "Main", Chapter = 4, Title = "Test Chapter 4", Steps = { { Text = "Lv%d", Obj = { Type = "Level", Level = 99 } } } }
	table.insert(SQ.Main, "M4_T")
	check(SQ.SkipChapters and #SQ.SkipChapters == 2, "Config.StoryQuests.SkipChapters (Lv10 -> 2, Lv25 -> 3)", show(SQ.SkipChapters))
	local function oldSave(userId, level, migrated)
		local data = { Story = migrated and { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = { Migrated = true } } or nil }
		local p, d = w:Join(userId, { Faction = "Halo", Level = level, Data = data })
		w.Story.Refresh(p)
		return p, d
	end
	local _, a = oldSave(901, 12)
	check(a.Story.Done.M2_7 and a.Story.Done.M1_1 and not a.Story.Done.M3_1 and a.Story.Main.Id == "M3_1",
		"an old Lv12 save: chapters 1-2 done, chapter 3 starts (M3_1)", show({ a.Story.Main.Id, a.Story.Done.M3_1 }))
	local _, b = oldSave(902, 30)
	check(b.Story.Done.M3_1 and b.Story.Done.M3_8 and not b.Story.Done.M4_T and b.Story.Main.Id == "M4_T",
		"an old Lv30 save: chapters 1-3 done (M3_1..M3_8), chapter 4 starts", show({ b.Story.Main.Id, b.Story.Done.M4_T }))
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

------------------------------------------------------------------ 11. MaxSubs 3: a town quest row is never pushed off
-- quest_volume §2-6 (검수): 3 sub rows (the HUD shows 2, the open list all); a started sub outranks untouched ones,
-- ties go to the newer quest, and the order never swaps between refreshes
runGroup("max-subs", function()
	check(SQ0.MaxSubs == 3, "MaxSubs = 3 (the HUD shows 2, the open list all)", SQ0.MaxSubs)
	local w = townWorld()
	w:Npc("Bright", vec(0, 0, -400))
	local p, d = joinAfterM23(w, 701, "Halo", { Pos = vec(2, 0, -398) })
	local subs = d.Story.Subs
	check(subs.S0 and subs.S1 and subs.S2 and subs.S3 and subs.H1 and subs.N3,
		"the busy Halo list after M2_3: S0 (never done), S1, S2, S3, H1, N3", show(subs))
	local function ids()
		local out = {}
		for _, r in w.Story.SubRows(p, d) do table.insert(out, r.Story and r.Story.Id or "?") end
		return out
	end
	local function has(list, id)
		for _, v in list do if v == id then return true end end
		return false
	end
	-- (the A23-56 town-type subs S6 / XR1 are done here, so the list is about the town quests)
	for _, id in { "S6", "XR1" } do
		d.Story.Done[id] = true
		d.Story.Subs[id] = nil
	end
	local first = ids()
	check(#first == 3 and has(first, "H1") and has(first, "N3"), "both town quests wait at their NPC: on the list",
		show(first))
	-- talk to Bright: H1 is started (no card waits any more); then the goose comes (S1, situational)
	w:Act(p, "H1", "Talk")
	check(w:Track(d, "H1").St == 2, "H1 started (step 2)", w:Track(d, "H1").St)
	w.GameState.Attrs.GooseActive = true
	local busy = ids()
	check(#busy == 3 and busy[1] == "S1" and busy[2] == "H1" and busy[3] == "S0",
		"the goose + H1 in progress + S0: H1 stays on the list (N3's new offer, S2 / S3 wait)", show(busy))
	check(table.concat(ids(), ",") == table.concat(busy, ","), "the same order on every refresh (no swapping)", show(ids()))
	w.GameState.Attrs.GooseActive = false
	local calm = ids()
	check(#calm == 3 and calm[1] == "H1" and calm[2] == "S0" and calm[3] == "N3", "the goose gone: H1, S0, then N3's offer",
		show(calm))
	-- a new offer (XR1's first card) never pushes a sub in progress off the list; a card waiting mid-quest comes first
	d.Story.Done.XR1 = nil
	d.Story.Subs.XR1 = { St = 1, P = 0, T = {}, Claim = false }
	local offer = ids()
	check(offer[1] == "H1" and offer[2] == "S0" and offer[3] == "XR1", "XR1's new offer joins after the subs in progress",
		show(offer))
	d.Story.Subs.XR1.St = 3 -- XR1's pick card waits mid-quest
	local pickFirst = ids()
	check(pickFirst[1] == "XR1" and pickFirst[2] == "H1", "a pick card waiting mid-quest comes first", show(pickFirst))
	for _, r in w.Story.SubRows(p, d) do
		check(r.Rank == nil and r.Order == nil, "the " .. tostring(r.Story and r.Story.Id) .. " row sends no Rank / Order",
			show({ r.Rank, r.Order }))
	end
end)

------------------------------------------------------------------ 12. story_depth E1 / E2 / E3 / E5 (the engine for 3장 and the easter eggs)
-- test quests are added to this world's own Config (every world runs its own copy)
local function addSub(w, id, def)
	def.Kind = "Sub"
	def.Title = def.Title or id
	w.Config.StoryQuests.Defs[id] = def
	table.insert(w.Config.StoryQuests.Subs, id)
end
local function choiceStep(goodPts, evilPts, extra)
	local step = { Text = "Pick", Panel = true, Lines = { All = { "Which one?" } },
		Obj = { Type = "Choice", Good = { Label = "Give", Points = goodPts }, Evil = { Label = "Keep", Points = evilPts },
			Neutral = { A = "Give", B = "Keep" } } }
	for k, v in extra or {} do step[k] = v end
	return step
end
local function panelsOf(w)
	local out = {}
	local op = w.Net.Get("OpenPanel")
	local base = op.FireClient
	op.FireClient = function(self, p, kind, arg)
		table.insert(out, { P = p, Kind = kind, Arg = arg })
		return base(self, p, kind, arg)
	end
	return out
end
local function rowOf(w, p, d, id)
	w.Config.StoryQuests.MaxSubs = 20
	for _, r in w.Story.SubRows(p, d) do
		if r.Story and r.Story.Id == id then return r end
	end
	return nil
end
local function said(w, p, from, text)
	for _, t in w:NoticesFor(p, from) do
		if t == text then return true end
	end
	return false
end

runGroup("e1-pick-gate", function()
	local w = townWorld()
	local CORE = { Text = "Visit the Crossroads", Obj = { Type = "Enter", Zone = "Crossroads" } }
	addSub(w, "TX_Pip", { Requires = { Pick = { Id = "M2_3", Is = "Good" } }, Steps = { CORE } })
	addSub(w, "TX_Dibs", { Requires = { Pick = { Id = "M2_3", Is = "Evil" } }, Steps = { CORE } })
	addSub(w, "TX_Exact", { Requires = { Pick = { Id = "S0", Is = "Purify" } }, Steps = { CORE } })
	local function joinWith(userId, faction, picks)
		local p, d = joinAfterM23(w, userId, faction)
		for k, v in picks do d.Story.Pick[k] = v end
		w.Story.Refresh(p)
		return p, d
	end
	local _, good = joinWith(801, "Halo", { M2_3 = "Good" })
	local _, evil = joinWith(802, "Horns", { M2_3 = "Evil" })
	local _, none = joinWith(803, "Halo", {})
	local _, a = joinWith(804, "Neutral", { M2_3 = "A" })
	local _, b = joinWith(805, "Neutral", { M2_3 = "B" })
	local _, purify = joinWith(806, "Halo", { S0 = "Purify" })
	local _, devour = joinWith(807, "Horns", { S0 = "Devour" })
	check(w:Track(good, "TX_Pip") and not w:Track(good, "TX_Dibs"), "Pick M2_3 = Good: the Good-side sub only", show(good.Story.Subs))
	check(w:Track(evil, "TX_Dibs") and not w:Track(evil, "TX_Pip"), "Pick M2_3 = Evil: the Evil-side sub only", show(evil.Story.Subs))
	check(not w:Track(none, "TX_Pip") and not w:Track(none, "TX_Dibs"), "no pick yet (an old save): neither")
	check(w:Track(a, "TX_Pip") and not w:Track(a, "TX_Dibs"), "an artisan's A counts as the Good side", show(a.Story.Subs))
	check(w:Track(b, "TX_Dibs") and not w:Track(b, "TX_Pip"), "an artisan's B counts as the Evil side", show(b.Story.Subs))
	check(w:Track(purify, "TX_Exact") and not w:Track(devour, "TX_Exact"), "Is = Purify: only that exact pick",
		show({ purify.Story.Subs.TX_Exact ~= nil, devour.Story.Subs.TX_Exact ~= nil }))
end)

runGroup("e2-lines-by", function()
	-- every LinesBy in the game's own quests has a Default and a real From (old saves have no picks)
	for id, def in SQ0.Defs do
		for i, step in def.Steps do
			if step.LinesBy ~= nil then
				check(type(step.LinesBy) == "table" and type(step.LinesBy.Default) == "table" and SQ0.Defs[step.LinesBy.From] ~= nil,
					id .. " step " .. i .. ": LinesBy has a Default and a real From", show(step.LinesBy))
			end
		end
	end
	local w = townWorld()
	local panels = panelsOf(w)
	local by = { From = "M2_3", Good = { All = { "g" } }, Evil = { All = { "e" } }, A = { All = { "a" } }, Default = { All = { "d" } } }
	addSub(w, "TX_Lines", { Requires = { Done = { "M2_3" } },
		Steps = { { Text = "Talk", Panel = true, LinesBy = by, Obj = { Type = "Talk" } } } })
	addSub(w, "TX_Side", { Requires = { Done = { "M2_3" } },
		Steps = { { Text = "Talk", Panel = true, LinesBy = { From = "S0", Good = { All = { "g" } }, Default = { All = { "d" } } },
			Obj = { Type = "Talk" } } } })
	local cases = { { 811, "Halo", { M2_3 = "Good" }, "Good" }, { 812, "Horns", { M2_3 = "Evil" }, "Evil" },
		{ 813, "Halo", {}, "Default" }, { 814, "Neutral", { M2_3 = "A" }, "A" }, { 815, "Neutral", { M2_3 = "B" }, "Evil" } }
	for _, c in cases do
		local p, d = joinAfterM23(w, c[1], c[2])
		for k, v in c[3] do d.Story.Pick[k] = v end
		local row = rowOf(w, p, d, "TX_Lines")
		check(row ~= nil and row.Story.Var == c[4], c[2] .. " " .. show(c[3]) .. ": Var " .. c[4] .. " on the row",
			show(row and row.Story.Var))
		local n0 = #panels
		w:Act(p, "TX_Lines", "Open")
		local last = panels[#panels]
		check(#panels == n0 + 1 and last.Kind == "Story" and last.Arg.Id == "TX_Lines" and last.Arg.Var == c[4],
			c[2] .. " " .. show(c[3]) .. ": the window opens with Var " .. c[4], show(last and last.Arg))
	end
	-- a Purify pick reads the Good entry when the step lists no Purify one
	local p, d = joinAfterM23(w, 816, "Halo")
	d.Story.Pick.S0 = "Purify"
	local row = rowOf(w, p, d, "TX_Side")
	check(row ~= nil and row.Story.Var == "Good", "Purify -> its side (Good)", show(row and row.Story.Var))
	-- a plain step sends no Var
	local h1 = rowOf(w, p, d, "H1")
	check(h1 ~= nil and h1.Story.Var == nil, "a step without LinesBy: no Var", show(h1 and h1.Story.Var))
end)

runGroup("e2-changed-mind", function()
	local w = townWorld()
	for i = 1, 4 do addSub(w, "TX_C" .. i, { Requires = { Done = { "M2_3" } }, Steps = { choiceStep(1, 1) } }) end
	addSub(w, "TX_Egg", { Requires = { Done = { "M2_3" } }, Steps = { choiceStep(0, 0) } })
	local p, d = joinAfterM23(w, 821, "Halo")
	d.Honor = 5
	local n0 = #w.Notices
	w:Act(p, "TX_C1", "Choose", "Good")
	check(not said(w, p, n0, SQ0.Text.ChangedGood) and not said(w, p, n0, SQ0.Text.ChangedEvil) and d.Story.LastSide == "Good",
		"the first real pick: no line, its side saved", show({ d.Story.LastSide, w:NoticesFor(p, n0) }))
	local n1 = #w.Notices
	w:Act(p, "TX_C2", "Choose", "Evil")
	check(said(w, p, n1, SQ0.Text.ChangedEvil) and d.Story.LastSide == "Evil", "Good then Evil: 'You gave it last time…'",
		show(w:NoticesFor(p, n1)))
	-- an easter egg (0 points) leans the shard, never counts as a change, never moves the score
	local n2, honor = #w.Notices, d.Honor
	w:Act(p, "TX_Egg", "Choose", "Good")
	local eggLines = w:NoticesFor(p, n2)
	check(said(w, p, n2, SQ0.Text.LeanGood) and not said(w, p, n2, SQ0.Text.ChangedGood) and d.Story.LastSide == "Evil"
		and d.Honor == honor and d.Story.Pick.TX_Egg == "Good", "a 0-point pick: 'Your shard leaned to the light.', no change line, no score",
		show({ eggLines, d.Story.LastSide, d.Honor }))
	for _, t in eggLines do
		check(t ~= string.format(SQ0.Text.Good, 0) and t ~= string.format(SQ0.Text.OffSideHalo, 0), "no '+0' / '-0' line", t)
	end
	local n3 = #w.Notices
	w:Act(p, "TX_C3", "Choose", "Evil")
	check(not said(w, p, n3, SQ0.Text.ChangedEvil) and not said(w, p, n3, SQ0.Text.ChangedGood), "Evil after Evil (the egg between): no line",
		show(w:NoticesFor(p, n3)))
	-- an artisan's A after B is a change too; a broken saved side is dropped at load
	local q, e = joinAfterM23(w, 822, "Neutral")
	e.Story.LastSide = "Sideways"
	w.PS.PlayerReady:Fire(q, e)
	local n4 = #w.Notices
	w:Act(q, "TX_C1", "Choose", "B")
	check(not said(w, q, n4, SQ0.Text.ChangedEvil) and e.Story.LastSide == "Evil", "a bad saved side is dropped: no line on the first pick",
		show({ e.Story.LastSide, w:NoticesFor(q, n4) }))
	local n5 = #w.Notices
	w:Act(q, "TX_C2", "Choose", "A")
	check(said(w, q, n5, SQ0.Text.ChangedGood), "an artisan's A after B: 'You kept it last time…'", show(w:NoticesFor(q, n5)))
end)

runGroup("e3-titles", function()
	local w = townWorld()
	local owned, grants = {}, {}
	w.Registry.TitleService = { Grant = function(p, id)
		table.insert(grants, id)
		if owned[id] then return false end
		owned[id] = true
		return true
	end }
	w.Config.TitleDefs.TX_Plain = { Name = "Tester" }
	w.Config.TitleDefs.TX_Give = { Name = "Giver" }
	w.Config.TitleDefs.TX_Keep = { Name = "Keeper" }
	local talk = { Text = "Talk", Panel = true, Lines = { All = { "Hi" } }, Obj = { Type = "Talk" } }
	addSub(w, "TX_T1", { Requires = { Done = { "M2_3" } }, Steps = { talk }, Reward = { Title = "TX_Plain" } })
	addSub(w, "TX_T2", { Requires = { Done = { "M2_3" } }, Steps = { choiceStep(0, 0) },
		Reward = { TitleBy = { Good = "TX_Give", Evil = "TX_Keep" } } })
	addSub(w, "TX_T3", { Requires = { Done = { "M2_3" } }, Steps = { talk }, Reward = { Title = "TX_Plain" } })
	addSub(w, "TX_T4", { Requires = { Done = { "M2_3" } }, Steps = { talk }, Reward = { Title = "TX_NoSuchTitle" } })
	local p, d = joinAfterM23(w, 831, "Horns")
	local n0 = #w.Notices
	w:Act(p, "TX_T1", "Talk")
	check(d.Story.Done.TX_T1 and grants[1] == "TX_Plain" and said(w, p, n0, string.format(SQ0.Text.NewTitle, "Tester")),
		"Reward.Title: granted once, 'New title: Tester!'", show({ grants, w:NoticesFor(p, n0) }))
	local n1 = #w.Notices
	w:Act(p, "TX_T2", "Choose", "Evil")
	check(grants[2] == "TX_Keep" and said(w, p, n1, string.format(SQ0.Text.NewTitle, "Keeper")),
		"Reward.TitleBy: the Evil pick gets the Evil title", show({ grants, w:NoticesFor(p, n1) }))
	local n2 = #w.Notices
	w:Act(p, "TX_T3", "Talk")
	check(grants[3] == "TX_Plain" and not said(w, p, n2, string.format(SQ0.Text.NewTitle, "Tester")),
		"a title already owned: no 'New title' line", show({ grants, w:NoticesFor(p, n2) }))
	w:Act(p, "TX_T4", "Talk")
	check(#grants == 3 and d.Story.Done.TX_T4, "an unknown title id: nothing granted, the quest still ends", show(grants))
	local q = joinAfterM23(w, 832, "Neutral")
	w:Act(q, "TX_T2", "Choose", "A")
	check(grants[4] == "TX_Give", "an artisan's A gets the Good-side title", show(grants))
end)

runGroup("e5-hidden", function()
	local w = townWorld()
	local panels = panelsOf(w)
	local spot = SQ0.Landmarks.Fountain
	addSub(w, "TX_Egg", { Hidden = true, Start = "A secret!", Requires = { Done = { "M2_3" } }, Finish = "Egg found",
		Steps = {
			{ Text = "Find it", Obj = { Type = "Near", Spot = "Fountain", Radius = 6 } },
			choiceStep(0, 0),
			{ Text = "After", Panel = true, Obj = { Type = "Talk" },
				LinesBy = { From = "TX_Egg", Good = { All = { "g" } }, Evil = { All = { "e" } }, Default = { All = { "d" } } } },
		} })
	addSub(w, "TX_Sky", { Hidden = true, Requires = { Done = { "M2_3" } }, Finish = "Sky found",
		Steps = { { Text = "Look up %d/%d s", Obj = { Type = "Near", Spot = "Fountain", Radius = 6, Stay = 3 } } } })
	local n0 = #w.Notices
	local p, d = joinAfterM23(w, 841, "Halo", { Pos = vec(spot.X + 60, 0, spot.Z) })
	check(w:Track(d, "TX_Egg") and not said(w, p, n0, "A secret!"), "a hidden sub is offered without its Start toast",
		show(w:NoticesFor(p, n0)))
	check(rowOf(w, p, d, "TX_Egg") == nil and rowOf(w, p, d, "TX_Sky") == nil, "…and no row before it is found")
	-- found: past its first step (the choice card opens by itself; the row shows from now on)
	w:MoveTo(p, vec(spot.X + 2, 0, spot.Z))
	w:Tick(p, 1)
	check(w:Track(d, "TX_Egg").St == 2 and rowOf(w, p, d, "TX_Egg") ~= nil, "found: step 2 and its row", show(w:Track(d, "TX_Egg")))
	local card = panels[#panels]
	check(card ~= nil and card.Arg.Id == "TX_Egg" and card.Arg.St == 2, "the pick card opens", show(card and card.Arg))
	w:Tick(p, 1)
	check(rowOf(w, p, d, "TX_Sky") == nil and w:Track(d, "TX_Sky").P >= 1, "a one-step egg counting its seconds stays hidden",
		show(w:Track(d, "TX_Sky")))
	local honor = d.Honor or 0
	local n1 = #w.Notices
	w:Act(p, "TX_Egg", "Choose", "Evil")
	check(said(w, p, n1, SQ0.Text.LeanEvil) and (d.Honor or 0) == honor and d.Story.Pick.TX_Egg == "Evil",
		"a 0-point egg pick: the lean line only (no score)", show({ w:NoticesFor(p, n1), d.Honor }))
	local after = panels[#panels]
	check(after.Arg.Id == "TX_Egg" and after.Arg.St == 3 and after.Arg.Var == "Evil", "LinesBy its own pick: Var Evil",
		show(after.Arg))
	w:Tick(p, 3)
	check(d.Story.Done.TX_Sky and said(w, p, n1, "Sky found"), "the one-step egg ends after its seconds (never listed)",
		show(w:Track(d, "TX_Sky")))
end)

------------------------------------------------------------------ 13. chapter 3 "Grab Club" (A23-56 main advance + story_depth beta)
local CH3 = { "M3_1", "M3_2", "M3_3", "M3_4", "M3_5", "M3_6", "M3_7", "M3_8" }

runGroup("ch3-data", function()
	local SQ = SQ0
	local at = table.find(SQ.Main, "M2_7")
	for i, id in CH3 do
		local def = SQ.Defs[id]
		check(at ~= nil and SQ.Main[at + i] == id, id .. " follows in StoryQuests.Main", show(SQ.Main[at and at + i or 0]))
		check(def and def.Kind == "Main" and def.Chapter == 3, id .. ": a chapter 3 main", show(def and def.Chapter))
		local ends = id == "M3_4" or id == "M3_8"
		local r = def and def.Reward
		check(r and ((ends and def.Claim == true and r.Gold == 2 and r.XP == 2) or (not ends and not def.Claim and r.Gold == 1 and r.XP == nil)),
			id .. (ends and ": a chapter end ([Claim], Gold 2 + XP 2)" or ": G1 (Gold 1)"), show(r))
		for s, step in def and def.Steps or {} do
			if step.LinesBy then
				check(type(step.Lines) == "table", id .. " step " .. s .. ": a Lines fallback for clients without LinesBy",
					show(step.Lines))
			end
		end
	end
	-- the camps sit inside the woods; each has its line (Trials Say)
	for i = 1, 3 do
		local spot = SQ.Landmarks["GoblinCamp" .. i]
		check(spot ~= nil and C0.ZoneAt(spot).Id == "GoblinWoods", "GoblinCamp" .. i .. " is in the Goblin Woods",
			show(spot and C0.ZoneAt(spot).Id))
	end
	local camps = SQ.Defs.M3_2.Steps[1].Obj.List
	check(#camps == 3 and camps[1].Say and camps[2].Say and camps[3].Say and camps[1].Near == "GoblinCamp1",
		"M3_2: three camps, one line each", show(camps))
	local pick = SQ.Defs.M3_4.Steps[2]
	check(pick.Obj.Type == "Choice" and pick.Obj.Good.Points == 3 and pick.Obj.Evil.Points == 3
		and pick.Obj.Evil.Reward and pick.Obj.Evil.Reward.Gold == 192 and pick.Obj.Good.Reward == nil and pick.LinesBy.From == "M2_3",
		"M3_4: +3 either way; Evil (Dibs) pays 192 gold now; page 1 remembers M2_3", show(pick.Obj))
	local pip = SQ.Defs.Pip1
	check(table.find(SQ.Subs, "Pip1") ~= nil and pip.Requires.Pick.Id == "M3_4" and pip.Requires.Pick.Is == "Good"
		and pip.Requires.Level == 15 and pip.Reward.Item == "Enh70" and pip.Speaker == "Pip" and SQ.Speakers.Pip ~= nil,
		"Pip1: after a Good / A pick of M3_4, Lv15, one 70% scroll", show(pip and pip.Requires))
	check(SQ.Speakers.Dibs ~= nil and SQ.Speakers.Grabbo ~= nil, "Speakers Dibs / Grabbo (names only in the beta)")
end)

-- a Halo / Horns / Neutral player who finished chapter 2 (Done M1_1..M2_7), at `level`, with saved picks
local function joinCh3(w, userId, faction, level, picks)
	local done = {}
	for _, id in w.Config.StoryQuests.Main do
		if string.sub(id, 1, 2) ~= "M3" then done[id] = true end
	end
	local p, d = w:Join(userId, { Faction = faction, Level = level, Data = { Story = { Main = { Id = "" }, Subs = {},
		Done = done, Pick = picks or {}, First = { Migrated = true } } } })
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end
local function killAt(w, p, kind, zone, pos, n)
	for _ = 1, n or 1 do
		w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = kind, ZoneId = zone, Golden = false, Personal = false,
			Position = pos or vec(720, 0, 0), WarPoints = 0 })
	end
	w:Flush()
end
local function setLevel(w, p, d, level)
	d.Level = level
	p:SetAttribute("Level", level)
	w.Story.Refresh(p)
	w:Flush()
end

runGroup("ch3-halo-good", function()
	local w = townWorld({ Npcs = false })
	local panels = panelsOf(w)
	local rookie = {}
	w.Registry.PvPService.IsRookie = function(p) return rookie[p] ~= false end
	local p, d = joinCh3(w, 1001, "Halo", 10, { M2_3 = "Good" })
	local function main() return d.Story.Main end
	check(main().Id == "M3_1", "after chapter 2 at Lv10: M3_1 starts", show(main()))
	killAt(w, p, "Goblin", "SlimeMeadow", nil, 5)
	check(main().Id == "M3_1" and main().P == 0, "goblins outside the woods do not count", show(main()))
	local n0 = #w.Notices
	killAt(w, p, "Goblin", "GoblinWoods", nil, 5)
	check(d.Story.Done.M3_1 and said(w, p, n0, SQ0.Defs.M3_1.Finish), "5 goblins in the woods: M3_1 done ('IOU 1 dust')",
		show(w:NoticesFor(p, n0)))
	w.Story.Refresh(p)
	check(main().Id == "M3_2", "M3_2 starts", show(main()))
	-- one goblin near each camp; each camp says its line once
	local L = SQ0.Landmarks
	local n1 = #w.Notices
	killAt(w, p, "Goblin", "GoblinWoods", L.GoblinCamp1 + vec(10, 0, 5))
	killAt(w, p, "Goblin", "GoblinWoods", L.GoblinCamp1 + vec(-8, 0, 0))
	local campLines = 0
	for _, t in w:NoticesFor(p, n1) do
		if t == SQ0.Defs.M3_2.Steps[1].Obj.List[1].Say then campLines += 1 end
	end
	check(campLines == 1 and main().T.a == 1 and main().T.b == nil, "camp 1: its line once (a second goblin there adds nothing)",
		show({ campLines, main().T }))
	killAt(w, p, "Goblin", "GoblinWoods", L.GoblinCamp2 + vec(80, 0, 0))
	check(main().T.b == nil, "a goblin 80 studs from camp 2 does not count", show(main().T))
	killAt(w, p, "Goblin", "GoblinWoods", L.GoblinCamp2)
	killAt(w, p, "Goblin", "GoblinWoods", L.GoblinCamp3 + vec(0, 0, 30))
	check(d.Story.Done.M3_2 and said(w, p, n1, SQ0.Defs.M3_2.Steps[1].Obj.List[3].Say), "all three camps: M3_2 done",
		show(d.Story.Done.M3_2))
	w.Story.Refresh(p)
	local n2 = #w.Notices
	killAt(w, p, "GoblinBrute", "GoblinWoods")
	check(d.Story.Done.M3_3 and said(w, p, n2, SQ0.Defs.M3_3.Finish) and said(w, p, n2, SQ0.Defs.M3_3.Clue),
		"M3_3: the Brute's line, then the crayon clue", show(w:NoticesFor(p, n2)))
	-- M3_4: home -> the pick card remembers M2_3 -> +3 honor -> the Guide's reaction -> [Claim]
	w.Story.Refresh(p)
	check(main().Id == "M3_4" and main().St == 1, "M3_4 starts: go home", show(main()))
	w.ZoneOf[p] = "HaloTown"
	w.Story.Refresh(p)
	w:Flush()
	local card = panels[#panels]
	check(main().St == 2 and card and card.Arg.Id == "M3_4" and card.Arg.St == 2 and card.Arg.Var == "Good",
		"at home: the pick card opens with Var Good (gave the shard back in M2_3)", show(card and card.Arg))
	local honor, bank = d.Honor or 0, d.BankGold or 0
	w:Act(p, "M3_4", "Choose", "Good")
	check((d.Honor or 0) == honor + 3 and (d.BankGold or 0) == bank and d.Story.Pick.M3_4 == "Good",
		"Leave some for their lamps: Honor +3, no gold now", show({ d.Honor, d.BankGold }))
	local react = panels[#panels]
	check(main().St == 3 and react.Arg.St == 3 and react.Arg.Var == "Good", "the Guide's reaction: Var Good", show(react.Arg))
	w:Act(p, "M3_4", "Talk")
	check(main().Claim == true, "M3_4 waits for [Claim] (chapter part end)", show(main()))
	w.Story.Claim(p, "M3_4")
	check(d.Story.Done.M3_4, "claimed")
	-- M3_5: the Sprout Shield must be over (E7)
	w.Story.Refresh(p)
	check(main().Id == "M3_5" and main().St == 1, "M3_5 waits for graduation", show(main()))
	rookie[p] = false
	w.Story.Refresh(p)
	w:Flush()
	check(main().St == 2 and panels[#panels].Arg.Id == "M3_5", "graduated: the Guide's talk opens", show(main()))
	w:Act(p, "M3_5", "Talk")
	check(d.Story.Done.M3_5, "M3_5 done")
	-- Pip1 waits for Lv15
	w.Story.Refresh(p)
	check(w:Track(d, "Pip1") == nil, "Pip1 not before Lv15", show(d.Story.Subs.Pip1))
	check(main().Id == "M3_6" and main().St == 1, "M3_6: Lv18 first", show(main()))
	setLevel(w, p, d, 18)
	check(main().St == 2 and w:Track(d, "Pip1") ~= nil, "Lv18: the Brute hunt starts, Pip1 is offered (Lv15+ and Good)",
		show({ main(), d.Story.Subs.Pip1 }))
	killAt(w, p, "GoblinBrute", "GoblinWoods", nil, 2)
	w.Story.Refresh(p)
	check(d.Story.Done.M3_6 and main().Id == "M3_7", "M3_6 done, M3_7 next", show(main()))
	setLevel(w, p, d, 21)
	local released = w.Registry.CombatService.Released
	released:Fire(p, { Auto = false, MonstersHit = 2 })
	released:Fire(p, { Auto = true, MonstersHit = 4 })
	check(main().P == 0, "2 at once or an auto skill do not count", show(main()))
	released:Fire(p, { Auto = false, MonstersHit = 3 })
	released:Fire(p, { Auto = false, MonstersHit = 5 })
	w:Flush()
	w.Story.Refresh(p)
	check(d.Story.Done.M3_7 and main().Id == "M3_8", "two skills hitting 3+: M3_7 done", show(main()))
	setLevel(w, p, d, 25)
	w.ZoneOf[p] = "SkeletonRuins"
	w.Story.Refresh(p)
	w:Flush()
	check(main().St == 3 and panels[#panels].Arg.Id == "M3_8", "Lv25 + the ruins: the tombs talk", show(main()))
	w:Act(p, "M3_8", "Talk")
	w.Story.Claim(p, "M3_8")
	w.Story.Refresh(p)
	check(d.Story.Done.M3_8 and main().Id == "", "M3_8 claimed: chapter 3 is over (no chapter 4 in the beta)", show(main()))
	-- Pip's lamp (the Good echo): the woods' edge -> talk -> one 70% scroll
	local gate = SQ0.Landmarks.WoodsGate
	w:MoveTo(p, vec(gate.X + 2, 0, gate.Z))
	w.Story.Refresh(p)
	w:Flush()
	local enh, n3 = d.Items and d.Items.Enh70 or 0, #w.Notices
	w:Act(p, "Pip1", "Talk")
	check(d.Story.Done.Pip1 and (d.Items.Enh70 or 0) == enh + 1
		and said(w, p, n3, string.format(w.Config.Loot.Text.Got, w.Config.Loot.Items.Enh70.Name)),
		"Pip1: one 70% scroll and its line", show({ d.Items.Enh70, w:NoticesFor(p, n3) }))
end)

runGroup("ch3-horns-evil", function()
	local w = townWorld({ Npcs = false })
	local panels = panelsOf(w)
	local p, d = joinCh3(w, 1101, "Horns", 16, { M2_3 = "Evil" })
	d.Story.Done.M3_1, d.Story.Done.M3_2, d.Story.Done.M3_3 = true, true, true
	d.Story.Main = { Id = "" }
	w.Story.Refresh(p)
	check(d.Story.Main.Id == "M3_4", "a Horns player at M3_4", show(d.Story.Main))
	w.ZoneOf[p] = "HornsTown"
	w.Story.Refresh(p)
	w:Flush()
	check(panels[#panels].Arg.Var == "Evil", "page 1 remembers keeping the shard (Var Evil)", show(panels[#panels].Arg))
	local infamy, bank, n0 = d.Infamy or 0, d.BankGold or 0, #w.Notices
	w:Act(p, "M3_4", "Choose", "Evil")
	check((d.Infamy or 0) == infamy + 3 and (d.BankGold or 0) == bank + 192 and said(w, p, n0, string.format(SQ0.Text.ChoiceGold, "192")),
		"Into our vault: Infamy +3 and Dibs's 192 gold at once", show({ d.Infamy, (d.BankGold or 0) - bank, w:NoticesFor(p, n0) }))
	check(panels[#panels].Arg.Var == "Evil", "the reaction page: Var Evil (Dibs: Ka-ching!)", show(panels[#panels].Arg))
	local react = SQ0.Defs.M3_4.Steps[3].LinesBy.Evil.Horns
	check(react and react[#react] == "Dibs: Ka-ching! Same as always? Same as always!", "the Horns reaction ends with Dibs", show(react))
	w:Act(p, "M3_4", "Talk")
	w.Story.Claim(p, "M3_4")
	w.Story.Refresh(p)
	check(d.Story.Done.M3_4 and w:Track(d, "Pip1") == nil, "an Evil pick never meets Pip (Lv16)", show(d.Story.Subs.Pip1))
	-- an artisan's A counts as the Good side: Pip comes; B pays Dibs's gold
	local q, e = joinCh3(w, 1102, "Neutral", 16, {})
	e.Story.Done.M3_1, e.Story.Done.M3_2, e.Story.Done.M3_3 = true, true, true
	e.Story.Main = { Id = "" }
	w.Story.Refresh(q)
	w.ZoneOf[q] = w.Config.HomeZoneId("Neutral")
	w.Story.Refresh(q)
	check(e.Story.Main.Id == "M3_4" and e.Story.Main.St == 2, "an artisan at home: the M3_4 card", show(e.Story.Main))
	local bankA, infamyA, honorA = e.BankGold or 0, e.Infamy or 0, e.Honor or 0
	w:Act(q, "M3_4", "Choose", "A")
	check(e.Story.Pick.M3_4 == "A" and (e.BankGold or 0) == bankA and (e.Infamy or 0) == infamyA and (e.Honor or 0) == honorA,
		"an artisan A: recorded only, no Dibs gold, no score", show({ e.Story.Pick.M3_4, e.BankGold }))
	w:Act(q, "M3_4", "Talk")
	w.Story.Claim(q, "M3_4")
	w.Story.Refresh(q)
	check(e.Story.Done.M3_4 and w:Track(e, "Pip1") ~= nil, "…and Pip1 comes at Lv15+ (A = the Good side)", show(e.Story.Subs.Pip1))
end)

------------------------------------------------------------------ 14. quest_volume §3-2: 12 new subs + 6 pulled (A23-56)
local SUBS18 = { "S6", "XR1", "H2", "R5", "GW1", "H3", "R3", "GW2", "GW3", "H5", "R6", "GW4", "GW5", "GW6", "GW7", "H6", "R7", "GW8" }
local TOWN_TYPE = { S6 = true, XR1 = true, H2 = true, R5 = true }

runGroup("subs18-data", function()
	local SQ = SQ0
	for _, id in SUBS18 do
		local def = SQ.Defs[id]
		check(def ~= nil and def.Kind == "Sub" and table.find(SQ.Subs, id) ~= nil, id .. ": a sub in StoryQuests.Subs", show(def and def.Kind))
		if def then
			local last = def.Steps[#def.Steps]
			local pick = last.Obj
			if pick.Type ~= "Choice" then -- GW1 ends with Grabbo's answer after the pick
				for _, step in def.Steps do if step.Obj.Type == "Choice" then pick = step.Obj end end
			end
			check(pick.Type == "Choice" and pick.Good.Points == 1 and pick.Evil.Points == 1, id .. ": an A / B pick, 1 point each",
				show(pick and pick.Type))
			local town = TOWN_TYPE[id]
			check(sameReward(pick.Good.Reward, { Item = "Enh70", N = 1 })
				and sameReward(pick.Evil.Reward, { Potion = "HP", N = 3, Gold = town and 60 or 192 }),
				id .. ": A = one 70% scroll, B = 3 HP potions + " .. (town and "60" or "192") .. " gold", show({ pick.Good.Reward, pick.Evil.Reward }))
			check(town and sameReward(def.Reward, { GoldN = 120, XPBar = 0.5 }) or (not town and sameReward(def.Reward, { Gold = 2, XP = 2 })),
				id .. ": " .. (town and "town-type 120 gold + half a bar" or "woods-type 2 minutes of gold + XP"), show(def.Reward))
			check(type(def.Finish) == "string" and string.find(def.Finish, "?", 1, true) ~= nil, id .. ": ends with a question", def.Finish)
			local req = def.Requires or {}
			local base = req.Done and req.Done[1]
			check(req.Level and req.Level >= 5 and (base == "M1_4" or base == "M2_7" or (id == "GW7" and base == "GW1")),
				id .. ": opens after M1_4 / M2_7 at Lv5+ (the first ten minutes stay as they are)", show(req))
			if def.Factions == nil and id ~= "S6" then
				check(pick.Neutral ~= nil, id .. ": everyone's sub keeps A / B labels for a Neutral save", show(pick.Neutral))
			end
			for _, step in def.Steps do
				local o = step.Obj
				if o.Spot then check(SQ.Landmarks[o.Spot] ~= nil, id .. ": spot " .. o.Spot .. " exists", o.Spot) end
				if o.Near then check(SQ.Landmarks[o.Near] ~= nil, id .. ": spot " .. o.Near .. " exists", o.Near) end
				if step.LinesBy then
					check(type(step.Lines) == "table" and type(step.LinesBy.Default) == "table", id .. ": LinesBy with a Default and a Lines fallback")
				end
			end
			if def.Speaker then check(SQ.Speakers[def.Speaker] ~= nil, id .. ": the speaker has a name", def.Speaker) end
		end
	end
	check(C0.ZoneAt(SQ.Landmarks.HeroStatue).Id == "HaloTown" and C0.ZoneAt(SQ.Landmarks.LavaCrack).Id == "HornsTown",
		"HeroStatue is in Halo Citadel, LavaCrack in Horns Den", show({ C0.ZoneAt(SQ.Landmarks.HeroStatue).Id, C0.ZoneAt(SQ.Landmarks.LavaCrack).Id }))
	check(SQ.Defs.GW7.Requires.Done[1] == "GW1", "GW7 follows GW1")
	check(SQ.Speakers.Gleam == "Sir Gleam" and SQ.Speakers.Rex == "Rascal Rex", "Sir Gleam / Rascal Rex")
end)

-- a player who finished chapter 2 (M1_1..M2_7 done) at `level`
local function joinDone(w, userId, faction, level, through)
	local done = {}
	for _, id in w.Config.StoryQuests.Main do
		done[id] = true
		if id == (through or "M2_7") then break end
	end
	local p, d = w:Join(userId, { Faction = faction, Level = level, Data = { Story = { Main = { Id = "" }, Subs = {},
		Done = done, Pick = {}, First = { Migrated = true } } } })
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end
local function offered(d)
	local out = {}
	for _, id in SUBS18 do if d.Story.Subs[id] then table.insert(out, id) end end
	return out
end

runGroup("subs18-offered", function()
	local w = townWorld({ Npcs = false })
	local hp, h = joinDone(w, 1201, "Halo", 23)
	local _, r = joinDone(w, 1202, "Horns", 23)
	local _, n = joinDone(w, 1203, "Neutral", 23)
	local hs, rs, ns = offered(h), offered(r), offered(n)
	local function has(list, id) return table.find(list, id) ~= nil end
	check(has(hs, "H2") and has(hs, "H3") and has(hs, "H5") and has(hs, "H6") and has(hs, "S6") and has(hs, "GW4") and has(hs, "GW5")
		and not has(hs, "R5") and not has(hs, "R7") and not has(hs, "GW7"), "Halo Lv23: the Halo subs + everyone's (GW7 waits for GW1)", show(hs))
	check(has(rs, "R3") and has(rs, "R5") and has(rs, "R6") and has(rs, "R7") and not has(rs, "H2") and not has(rs, "H6"),
		"Horns Lv23: the Horns subs", show(rs))
	check(has(ns, "XR1") and has(ns, "GW1") and has(ns, "GW8") and not has(ns, "S6") and not has(ns, "GW4") and not has(ns, "H2")
		and not has(ns, "R5"), "a Neutral save: everyone's subs only", show(ns))
	local _, low = joinDone(w, 1204, "Halo", 5, "M1_4")
	local ls = offered(low)
	check(#ls == 2 and has(ls, "S6") and has(ls, "XR1"), "Lv5 after M1_4: S6 + XR1 only", show(ls))
	local _, early = joinDone(w, 1205, "Halo", 6, "M1_3")
	check(#offered(early) == 0, "before M1_4: none of them (the first ten minutes stay)", show(offered(early)))
	-- GW7 opens after GW1 is done
	h.Story.Done.GW1 = true
	h.Story.Subs.GW1 = nil
	w.Story.Refresh(hp)
	check(h.Story.Subs.GW7 ~= nil, "GW1 done: GW7 is offered", show(offered(h)))
end)

runGroup("subs18-flow", function()
	local w = townWorld({ Npcs = false })
	-- S6 for Horns: hunting gold 80 -> home -> the Horns pick labels
	local p, d = joinDone(w, 1301, "Horns", 6, "M1_4")
	local tr = w:Track(d, "S6")
	check(tr and tr.St == 1, "S6 offered", show(tr))
	w.Registry.ProgressionService.GoldEarned:Fire(p, 50, "Sale")
	w.Registry.ProgressionService.GoldEarned:Fire(p, 80, "Monster")
	w:Flush()
	check(tr.St == 2, "Horns: 80 hunting gold (not sale gold) finishes step 1", show(tr))
	w.ZoneOf[p] = "HornsTown"
	w.Story.Refresh(p)
	w:Flush()
	check(tr.St == 3, "home: the pick", show(tr))
	local infamy, bank = d.Infamy or 0, d.BankGold or 0
	w:Act(p, "S6", "Choose", "Evil")
	check(d.Story.Done.S6 and d.Story.Pick.S6 == "Evil" and (d.Infamy or 0) == infamy + 1 and (d.BankGold or 0) >= bank + 60 + 120,
		"Count it twice: Infamy +1, 3 potions + 60 gold, then 120 gold", show({ d.Infamy, (d.BankGold or 0) - bank }))
	-- XR1 through Tiny (no NPC placed: anywhere), the King Slime, the pick
	local q, e = joinDone(w, 1302, "Halo", 6, "M1_4")
	local x = w:Track(e, "XR1")
	w:Act(q, "XR1", "Talk")
	w:Kill(q, "BigSlime", 1)
	check(x.St == 3, "XR1: talk, a King Slime, then the pick", show(x))
	local enh = e.Items and e.Items.Enh70 or 0
	w:Act(q, "XR1", "Choose", "Good")
	check(e.Story.Done.XR1 and (e.Items.Enh70 or 0) == enh + 1, "Return it to its owner: one 70% scroll", show(e.Items))
	-- GW7 remembers the GW1 pick (E2)
	local panels = panelsOf(w)
	local g, gd = joinDone(w, 1303, "Halo", 21)
	gd.Story.Done.GW1 = true
	gd.Story.Subs.GW1 = nil
	gd.Story.Pick.GW1 = "Evil"
	w.Story.Refresh(g)
	local camp = SQ0.Landmarks.GoblinCamp1
	w:MoveTo(g, vec(camp.X + 2, 0, camp.Z))
	w:Tick(g, 1)
	local card = panels[#panels]
	check(card and card.Arg.Id == "GW7" and card.Arg.Var == "Evil", "GW7 at the camp: Grabbo remembers the MORE vote (Var Evil)",
		show(card and card.Arg))
end)

finish()
