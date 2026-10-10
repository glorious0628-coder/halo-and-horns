-- town_quests_offline.luau : A23-46 town people sub quests H1 / R1 / N3 (story_depth §3 / §5-⑥, 검수 decisions) with
-- the engine parts they need (E4 Near.Stay, E6 per-pick rewards + LootService.GrantItem, quest NPC talk), and the
-- A23-57 artisan guild switch (Config.Features.NeutralFaction off: no new Neutral pick at the picker / altar / rebirth,
-- its own quests not offered). tools/test_town_quests.py binds the dev2_combat_world sources (the real
-- StoryQuestService, LootService, CombatService) + FACTION_EXTRACT and REBIRTH_EXTRACT; this file follows the world.

local SQ0 = C0.StoryQuests
local GOOD, EVIL = { Item = "Enh70", N = 1 }, { Potion = "HP", N = 3, Gold = 220 } -- 빛 마을 점검 #71: town B = 220

-- a started story world: StoryQuestService.Start connects its remote + signals (the 1 s loop is never run: Refresh is
-- called by hand), XP is recorded, the zone and the quest NPCs are scripted
local function townWorld(o)
	o = o or {}
	local w = bareWorld({})
	local reg = w.Registry
	local Signal = w.Util.Signal
	-- zone_check_halo #19: the real Config sends every active sub (More past MaxSubs); the groups here are about the three
	-- rows, so they start with the flag off and the send-all-subs group switches it on itself (o.SendAll = true: on)
	w.Config.StoryQuests.SendAllSubs = o.SendAll == true
	-- A23-104: the intro of the daily jobs (D0) starts for everybody past M1_4; only its own group wants it among the subs
	if o.D0 ~= true then
		local subs = w.Config.StoryQuests.Subs
		local at = table.find(subs, "D0")
		if at then table.remove(subs, at) end
	end
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
	w.Marks, w.WS = {}, ws
	if o.Npcs ~= false then
		w.Services.CollectionService = { GetTagged = function(_, tag)
			local out = {}
			if tag == SQ0.NpcTag then for _, n in w.Npcs do table.insert(out, n) end end
			if tag == "StoryLandmark" then for _, m in w.Marks do table.insert(out, m) end end
			return out
		end }
	end
	-- zone_check_halo #22 / #25 / #30: the NPCs' "Talk" prompts come through the ProximityPromptService (only when asked for)
	if o.Prompts then w.Services.ProximityPromptService = { PromptTriggered = Signal.new() } end
	if o.Hooks then o.Hooks(w, reg) end -- A23-64 ②: services Start listens to (ChoiceCard / FinisherService doubles)
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
	-- 빛 마을 점검 #2: a landmark marker (attribute Spot), inside the workspace unless outside == true
	function w:Mark(spot, pos, outside)
		local part = newInstance("Part", self)
		part.Name, part.Position = "Mark" .. spot, pos
		part.Attrs.Spot = spot
		part.IsDescendantOf = function(_, anc) return outside ~= true and anc == ws end
		table.insert(self.Marks, part)
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
			id .. ": A = one 70% scroll, B = 3 HP potions + 220 gold; 1 honor / infamy point", show(obj and { obj.Good, obj.Evil }))
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
	check(h1row and type(SQ0.Defs.H1.ShortName) == "string" and h1row.ShortName == SQ0.Defs.H1.ShortName
		and #h1row.ShortName <= 14, "the H1 row carries the quest's ShortName (the phone quest row)", h1row and h1row.ShortName)
	w.Config.StoryQuests.Defs.H1.Steps[1].ShortName = "Talk to Bright"
	local over = nil
	for _, r in w.Story.SubRows(halo, hd) do if r.Story and r.Story.Id == "H1" then over = r end end
	check(over and over.ShortName == "Talk to Bright", "a step's own ShortName comes before the quest's", over and over.ShortName)
	w.Config.StoryQuests.Defs.H1.Steps[1].ShortName = nil
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
		and row.Text == "Spy by the woods' edge" and row.ProgressUnit == "s",
		"the row counts the seconds: Progress / Target + unit 's', no '%d/%d s' in the text (3rd round #1)",
		show({ tr.P, row and row.Text, row and row.ProgressUnit }))
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
	local fx0 = #w.Fx
	w:Act(p, "H1", "Choose", "Good")
	local choice = nil
	for i = fx0 + 1, #w.Fx do if w.Fx[i].Kind == "Choice" and w.Fx[i].Player == p then choice = w.Fx[i].Data end end
	check(choice and choice.Option == "Good", "the pick sends Fx Choice { Option = 'Good' } (Purify sound)", show(choice))
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
	local sounds, finishSound, nextSound = w:SoundsFor(p, n0), nil, nil
	local quest = 0
	for i, t in lines do
		if t == SQ0.Defs.H1.Finish then finishSound, nextSound = sounds[i], sounds[i + 1] end
		if sounds[i] == "QuestDone" then quest += 1 end
	end
	check(finishSound == "QuestDone" and nextSound == "None" and quest == 1,
		"one QuestDone for the finish; the reward line right after it says Sound 'None'", show({ finishSound, sounds }))
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
	check((d.HPPotionCount or 0) == hp + 3 and (d.Items.Enh70 or 0) == enh and d.BankGold == bank + 220 + 120,
		"B: 3 HP potions + 220 gold (then the quest's 120)", show({ d.HPPotionCount - hp, d.BankGold - bank }))
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
		and e.BankGold == bank + 220 + 120, "Neutral B: recorded, no score, Evil's reward", show({ e.Story.Pick.N3, e.HPPotionCount, e.BankGold - bank }))
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

-- A23-70: the lost lunchbox - one card right after the first [Claim], no score, both buttons for every side
runGroup("a23-70 lunchbox", function()
	local w = townWorld({ Npcs = false })
	local T = w.Config.StoryQuests.Text
	local function has(list, text)
		for _, t in list do if t == text then return true end end
		return false
	end
	local L = SQ0.Defs.Lunch1
	check(L and L.Pop == true and L.Steps[1].Obj.Good.Points == 0 and L.Steps[1].Obj.Evil.Points == 0,
		"Config: Lunch1 pops, 0 points both ways", show(L and { L.Pop, L.Requires }))
	local function fresh(id, faction, step, done)
		local p, d = w:Join(id, { Faction = faction, Class = "Warrior", Level = 2,
			Data = { TutorialStep = step, Story = { Main = { Id = "" }, Subs = {}, Done = done or {}, Pick = {}, First = { Migrated = true } } } })
		w.Story.Refresh(p)
		w:Flush()
		return p, d
	end
	local _, d0 = fresh(1701, "Halo", 2)
	check(w:Track(d0, "Lunch1") == nil, "before the first [Claim]: no lunchbox")
	local _, dv = fresh(1702, "Halo", 99, { M1_1 = true })
	check(w:Track(dv, "Lunch1") == nil, "a player past the Forge (M1_1 done) never gets it")
	local opens = w:Opens(0)
	local p, d = fresh(1703, "Halo", 99)
	check(w:Track(d, "Lunch1") ~= nil and w:Opens(0) == opens + 1, "right after the first [Claim]: offered, the card opens once",
		show({ w:Track(d, "Lunch1") ~= nil, w:Opens(0) - opens }))
	w.Story.Refresh(p)
	w:Flush()
	check(w:Opens(0) == opens + 1, "a refresh never opens it again", w:Opens(0) - opens)
	-- [Give it back]: +1 HP potion, the kid's thanks, the Choice sound, no Honor and no lean line
	local n0, fx0, hp, honor = #w.Notices, #w.Fx, d.HPPotionCount or 0, d.Honor or 0
	w:Act(p, "Lunch1", "Choose", "Good")
	check(not has(w:NoticesFor(p, n0), L.Steps[1].Obj.Good.Reply),
		"10/08: the answer waits (not with the gold / done lines while the card is still open)", show(w:NoticesFor(p, n0)))
	w:Advance(0.2)
	check(not has(w:NoticesFor(p, n0), L.Steps[1].Obj.Good.Reply), "... still waiting 0.2 s later (the card closes first)",
		show(w:NoticesFor(p, n0)))
	w:Advance(0.2)
	local lines = w:NoticesFor(p, n0)
	check(#lines > 0 and lines[#lines] == L.Steps[1].Obj.Good.Reply,
		"... and comes 0.35 s later as the newest line (it stays while a window keeps only the newest)", show(lines))
	check((d.HPPotionCount or 0) == hp + 1 and (d.Honor or 0) == honor and d.Story.Done.Lunch1 == true,
		"Give it back: +1 HP potion, Honor unchanged, done", show({ d.HPPotionCount, d.Honor, d.Story.Done.Lunch1 }))
	check(has(lines, L.Steps[1].Obj.Good.Reply) and not has(lines, T.LeanGood), "the kid thanks you (no lean line)", show(lines))
	local fx = nil
	for i = fx0 + 1, #w.Fx do if w.Fx[i].Kind == "Choice" and w.Fx[i].Player == p then fx = w.Fx[i].Data end end
	check(fx and fx.Option == "Good", "Fx Choice { Option = 'Good' }", show(fx))
	-- [One bite!] (a Halo player may bite too): +25 gold to the bank, no Honor / Infamy
	local p2, d2 = fresh(1704, "Halo", 99)
	local bank, n2 = d2.BankGold or 0, #w.Notices
	w:Act(p2, "Lunch1", "Choose", "Evil")
	w:Advance(0.4)
	local bite = w:NoticesFor(p2, n2)
	check(#bite > 0 and bite[#bite] == L.Steps[1].Obj.Evil.Reply, "One bite: 'Yum!' is the last line", show(bite))
	check((d2.BankGold or 0) == bank + 25 and (d2.Honor or 0) == 0 and (d2.Infamy or 0) == 0
		and has(w:NoticesFor(p2, n2), L.Steps[1].Obj.Evil.Reply), "One bite: +25 gold, 'Yum!…', no score",
		show({ (d2.BankGold or 0) - bank, d2.Honor, d2.Infamy, w:NoticesFor(p2, n2) }))
	-- a Horns player may give it back
	local p3, d3 = fresh(1705, "Horns", 99)
	local hp3 = d3.HPPotionCount or 0
	w:Act(p3, "Lunch1", "Choose", "Good")
	w:Advance(0.4)
	check((d3.HPPotionCount or 0) == hp3 + 1 and (d3.Infamy or 0) == 0 and d3.Story.Pick.Lunch1 == "GiveBack",
		"a Horns player can give it back too", show({ d3.HPPotionCount, d3.Infamy, d3.Story.Pick.Lunch1 }))
	-- the artisan guild (Neutral: A / B): its answer waits and comes last the same way
	local p4, d4 = fresh(1706, "Neutral", 99)
	if w:Track(d4, "Lunch1") ~= nil then
		local n4 = #w.Notices
		w:Act(p4, "Lunch1", "Choose", "B")
		local early = w:NoticesFor(p4, n4)
		w:Advance(0.4)
		local late = w:NoticesFor(p4, n4)
		check(not has(early, L.Steps[1].Obj.Evil.Reply) and #late > 0 and late[#late] == L.Steps[1].Obj.Evil.Reply
			and d4.Story.Pick.Lunch1 == "B", "a Neutral B pick: the answer waits and comes last", show({ early, late }))
	else
		check(true, "a Neutral B pick: the answer waits and comes last (the guild is off: no card)")
	end
end)

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
	check((d2.HPPotionCount or 0) == hp + 3 and d2.BankGold == bank + 220 + 120, "the B reward is paid as usual",
		show({ d2.HPPotionCount - hp, d2.BankGold - bank }))
	local l2 = lines(p2, n2)
	check(has(l2, string.format(T.OffSideHalo, 1)) and not has(l2, T.RankDownHalo), "'Not very angel-like! Honor -1', no rank line (5 -> 4)",
		show(l2))
	-- at 0 nothing to take: never below 0 (A23-58), but the pick answers with a line without a number + the lean
	-- (3rd idea round #5), and the Choice sound
	local n3, fx3 = #w.Notices, #w.Fx
	local p3, d3 = atPick(w, 803, "Halo", "H1", { Honor = 0 })
	w:Act(p3, "H1", "Choose", "Evil")
	local zero = T.OffSideHaloZero .. " " .. T.LeanEvil
	check((d3.Honor or 0) == 0 and has(lines(p3, n3), zero) and not has(lines(p3, n3), string.format(T.OffSideHalo, 1)),
		"Honor 0 stays 0, the pick says 'not very angel-like! Your shard leaned to the dark.' (no number)",
		show({ d3.Honor, lines(p3, n3) }))
	local leaned = nil
	for i = fx3 + 1, #w.Fx do if w.Fx[i].Kind == "Choice" and w.Fx[i].Player == p3 then leaned = w.Fx[i].Data end end
	check(leaned and leaned.Option == "Evil", "a 0-point pick still sends Fx Choice { Option = 'Evil' }", show(leaned))
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

-- A23-71 (user 2026-10-07): the first skill comes at Lv5. M1_3 / M2_5 wait for it with a 'Lv5 · Learn your first
-- skill' step, N1 (a skill sub) opens at Lv5, and a skill step / trial before the first skill says when it comes
runGroup("a23-71 skill quests", function()
	local w = townWorld({ Npcs = false })
	local Q = w.Config.Skills.Unlock.Q
	check(Q == 5, "the first skill at Lv5", Q)
	for _, id in { "M1_3", "M2_5" } do
		local steps = SQ0.Defs[id].Steps
		check(steps[1].Obj.Type == "Level" and steps[1].Obj.Level == Q and steps[1].ShortName == "Reach Lv 5"
			and steps[2].Obj.Type == "SkillHit", id .. ": a 'reach Lv5' step before the skill hits (Level = Skills.Unlock.Q)",
			show(steps[1]))
	end
	check(SQ0.Defs.N1.Requires.Level == Q, "N1 (a skill sub) opens at Lv5", show(SQ0.Defs.N1.Requires))
	-- S8: M1_3 has no Start of its own; its Lv5 step says 'Grow to Lv5…' (and guides to the meadow), the skill step says
	-- the old line. Skill: both Lv5 steps also pass once Q is learned below Lv5.
	local m13 = SQ0.Defs.M1_3
	local GROW, DUSTY = "Grow to Lv5 to learn your first skill!", "Dusty slimes move in groups. Skills use MP!"
	check(m13.Start == nil and m13.Steps[1].Start == GROW and m13.Steps[1].Guide == "SlimeMeadow" and m13.Steps[2].Start == DUSTY,
		"S8: M1_3's start lines sit on its steps (the Lv5 step guides to the meadow)",
		show({ m13.Start, m13.Steps[1].Start, m13.Steps[1].Guide, m13.Steps[2].Start }))
	check(m13.Steps[1].Obj.Skill == true and SQ0.Defs.M2_5.Steps[1].Obj.Skill == true, "both Lv5 steps pass once Q is learned (Skill)")
	local function story(main, subs, done)
		return { Main = main or { Id = "" }, Subs = subs or {}, Done = done or {}, Pick = {}, First = { Migrated = true } }
	end
	local function count(p, from, text)
		local n = 0
		for _, t in w:NoticesFor(p, from) do if t == text then n += 1 end end
		return n
	end
	-- M1_3 starts at Lv3 (after M1_2): 'Grow to Lv5…' only; at Lv5 the skill step says its line
	local n0 = #w.Notices
	local ps, ds = w:Join(7103, { Faction = "Halo", Level = 3, Data = { Story = story(nil, {}, { M1_1 = true, M1_2 = true }) } })
	w.Story.Refresh(ps)
	w:Flush()
	check(ds.Story.Main.Id == "M1_3" and ds.Story.Main.St == 1 and count(ps, n0, GROW) == 1 and count(ps, n0, DUSTY) == 0,
		"M1_3 starts at Lv3: 'Grow to Lv5 to learn your first skill!' once, not the skill line", show(w:NoticesFor(ps, n0)))
	local n1 = #w.Notices
	w.PS.SetStat(ps, "Level", 5)
	w.Story.Refresh(ps)
	w:Flush()
	check(ds.Story.Main.St == 2 and count(ps, n1, DUSTY) == 1 and count(ps, n1, GROW) == 0,
		"Lv5: the skill step says 'Dusty slimes move in groups. Skills use MP!'", show(w:NoticesFor(ps, n1)))
	-- M1_3 starts at Lv7: straight to the skill step, its line once, no 'Grow to Lv5'
	local n2 = #w.Notices
	local pq, dq = w:Join(7104, { Faction = "Horns", Level = 7, Data = { Story = story(nil, {}, { M1_1 = true, M1_2 = true }) } })
	w.Story.Refresh(pq)
	w:Flush()
	check(dq.Story.Main.Id == "M1_3" and dq.Story.Main.St == 2 and count(pq, n2, DUSTY) == 1 and count(pq, n2, GROW) == 0,
		"M1_3 starts at Lv7: the skill line once, no 'Grow to Lv5'", show(w:NoticesFor(pq, n2)))
	-- a Lv1 who kept Q (a free class change from Lv5+ took the level back, the slots stay) passes the Lv5 step at once
	local pk, dk = w:Join(7105, { Faction = "Halo", Level = 1, Data = { SkillSlots = 1,
		Story = story({ Id = "M1_3", St = 1, P = 0, T = {}, Claim = false }, {}, { M1_1 = true, M1_2 = true }) } })
	w.Story.Refresh(pk)
	w:Flush()
	check(dk.Story.Main.St == 2, "a Lv1 who kept Q: M1_3's Lv5 step passes at once (Skill)", dk.Story.Main.St)
	local p2, d2 = w:Join(7106, { Faction = "Halo", Level = 1, Data = { SkillSlots = 0,
		Story = story({ Id = "M1_3", St = 1, P = 0, T = {}, Claim = false }, {}, { M1_1 = true, M1_2 = true }) } })
	w.Story.Refresh(p2)
	w:Flush()
	check(d2.Story.Main.St == 1, "a Lv1 without Q still waits at M1_3's Lv5 step", d2.Story.Main.St)
	-- M1_3 at Lv3: the row waits for Lv5; at Lv5 the skill hits begin (no 'Skills come' tail any more)
	local p, d = w:Join(7101, { Faction = "Halo", Level = 3,
		Data = { Story = story({ Id = "M1_3", St = 1, P = 0, T = {}, Claim = false }, {}, { M1_1 = true, M1_2 = true }) } })
	w.Story.Refresh(p)
	w:Flush()
	local row = w.Story.MainRow(p, d)
	check(row and row.Text == "Lv5 · Learn your first skill (now Lv3)" and row.ShortName == "Reach Lv 5" and d.Story.Main.St == 1,
		"M1_3 at Lv3: 'Lv5 · Learn your first skill (now Lv3)' / 'Reach Lv 5'", show(row and { row.Text, row.ShortName }))
	w.PS.SetStat(p, "Level", 5)
	w.Story.Refresh(p)
	w:Flush()
	row = w.Story.MainRow(p, d)
	check(d.Story.Main.St == 2 and row and row.Text == "Hit monsters with a skill" and row.Target == 3,
		"Lv5: the skill hits begin, no 'Skills come' tail", show(row and { d.Story.Main.St, row.Text, row.Target }))
	-- a Lv7 who reaches M1_3 passes the Lv5 step at once
	local p7, d7 = w:Join(7102, { Faction = "Horns", Level = 7,
		Data = { Story = story({ Id = "M1_3", St = 1, P = 0, T = {}, Claim = false }, {}, { M1_1 = true, M1_2 = true }) } })
	w.Story.Refresh(p7)
	w:Flush()
	check(d7.Story.Main.St == 2, "a Lv7 at M1_3: straight to the skill hits", d7.Story.Main.St)
	-- S0's trials (b = a skill hit on 2) before the first skill: the row says when the skill comes
	local function s0(level, t, extra)
		local data = { Story = story(nil, { S0 = { St = 2, P = 0, T = t, Claim = false } }) }
		for k, v in extra or {} do data[k] = v end
		local sp, sd = w:Join(7110 + level * 10 + (extra and 1 or 0) + (t.b and 2 or 0), { Faction = "Halo", Level = level, Data = data })
		return rowOf(w, sp, sd, "S0")
	end
	local r2 = s0(2, { a = 3 })
	check(r2 and r2.Text == "The shard's test · Skills come at Lv5" and r2.Progress == 1 and r2.Target == 3,
		"S0 at Lv2 (skill trial open): 'The shard's test · Skills come at Lv5'", show(r2 and { r2.Text, r2.Progress }))
	local rb = s0(2, { a = 3, b = 1 })
	check(rb and rb.Text == "The shard's test", "the skill trial already done: no tail", rb and rb.Text)
	local r5 = s0(5, { a = 3 })
	check(r5 and r5.Text == "The shard's test", "Lv5 (Q learned): no tail", r5 and r5.Text)
	local rk = s0(2, { a = 3 }, { SkillSlots = 1 })
	check(rk and rk.Text == "The shard's test", "a Lv2 who kept Q (saved slots 1): no tail", rk and rk.Text)
	-- N1 (Neutral, after M1_4; with the guild switch on, A23-57): not before Lv5
	w.Config.Features.NeutralFaction = true
	local n3, nd3 = w:Join(7120, { Faction = "Neutral", Level = 3, Data = { Story = story(nil, {}, { M1_1 = true, M1_2 = true,
		M1_3 = true, M1_4 = true }) } })
	w.Story.Refresh(n3)
	w:Flush()
	check(w:Track(nd3, "N1") == nil, "a Neutral Lv3 after M1_4: no N1 yet")
	w.PS.SetStat(n3, "Level", 5)
	w.Story.Refresh(n3)
	w:Flush()
	check(w:Track(nd3, "N1") ~= nil, "at Lv5: N1 is offered")
end)

-- SKL-3 (skill_kit §2): the practice subs SK1 (Z) / SK2 (X) wait for that skill (its switch on and its slot open);
-- SkillHit Slot counts only that skill's manual casts that hit
runGroup("skl3 subs", function()
	local w = townWorld({ Npcs = false })
	w.Config.StoryQuests.MaxSubs = 9
	local K = w.Config.Skills
	local CS = w.Combat
	local function story()
		return { Main = { Id = "" }, Subs = {}, Done = { M1_1 = true }, Pick = {}, First = { Migrated = true } }
	end
	check(SQ0.Defs.SK1.Requires.Skill == "Z" and SQ0.Defs.SK1.Steps[1].Obj.Slot == "Z" and SQ0.Defs.SK1.Steps[1].Obj.Min == 2
		and SQ0.Defs.SK2.Requires.Skill == "X" and SQ0.Defs.SK2.Steps[3].Obj.Slot == "X" and table.find(SQ0.Subs, "SK1")
		and table.find(SQ0.Subs, "SK2"), "SK1: Z hitting 2 once; SK2: the fountain, a pick, X hits x3 (both in the sub list)", "")
	-- SK1: the Z switch off -> not even with Z's slot saved; on + the slot -> offered; only Q (slot 1) -> not
	local p, d = w:Join(7301, { Faction = "Halo", Level = 15, Data = { SkillSlots = 2, Story = story() } })
	w.Story.Refresh(p)
	w:Flush()
	check(w:Track(d, "SK1") == nil, "ZEnabled off: no SK1, even with Z's slot saved", "")
	K.ZEnabled = true
	local n0 = #w.Notices
	w.Story.Refresh(p)
	w:Flush()
	check(w:Track(d, "SK1") ~= nil and said(w, p, n0, SQ0.Defs.SK1.Start), "the Z switch on and the slot open: SK1 with its Start line",
		show(w:NoticesFor(p, n0)))
	local p14, d14 = w:Join(7302, { Faction = "Halo", Level = 14, Data = { SkillSlots = 1, Story = story() } })
	w.Story.Refresh(p14)
	w:Flush()
	check(w:Track(d14, "SK1") == nil, "only Q learned (slot 1): no SK1", "")
	-- the Slot filter: a Q cast, a Z hitting one, an auto Z never count; a manual Z hitting 2 does
	local tr = w:Track(d, "SK1")
	CS.Released:Fire(p, { Slot = "Q", Auto = false, MonstersHit = 4 })
	CS.Released:Fire(p, { Slot = "Z", Auto = false, MonstersHit = 1 })
	CS.Released:Fire(p, { Slot = "Z", Auto = true, MonstersHit = 3 })
	w:Flush()
	check(w:Track(d, "SK1") ~= nil and (tr.P or 0) == 0 and d.Story.Done.SK1 == nil,
		"a Q cast hitting 4, a Z hitting 1 or an auto Z: not counted", show({ tr.P, d.Story.Done.SK1 }))
	CS.Released:Fire(p, { Slot = "Z", Auto = false, MonstersHit = 2 })
	w:Flush()
	check(d.Story.Done.SK1 == true and w:Track(d, "SK1") == nil, "a manual Z hitting 2: SK1 done", show(d.Story.Done.SK1))
	-- SK2: the X switch + slot 3; the fountain, the pick (Halo 'Guard my friends' = Honor +1), then 3 manual X hits
	local q, e = w:Join(7303, { Faction = "Halo", Level = 25, Data = { SkillSlots = 3, Story = story() }, Pos = vec(60, 0, 60) })
	w.Story.Refresh(q)
	w:Flush()
	check(w:Track(e, "SK2") == nil, "XEnabled off: no SK2", "")
	K.XEnabled = true
	w.Story.Refresh(q)
	w:Flush()
	local t2 = w:Track(e, "SK2")
	check(t2 ~= nil and t2.St == 1, "the X switch on and slot 3: SK2 starts at the fountain step", show(t2))
	w.ZoneOf[q] = "Crossroads"
	w:MoveTo(q, vec(5, 0, 5))
	w.Story.Refresh(q)
	w:Flush()
	check(t2 and t2.St == 2, "at the Crossroads fountain: the pick", t2 and t2.St)
	local honor = e.Honor or 0
	e.Story.LastSide = "Evil" -- an earlier real pick was on the other side
	local nk = #w.Notices
	w:Act(q, "SK2", "Choose", "Good")
	check(e.Story.Pick.SK2 == "Guard" and (e.Honor or 0) == honor + 1 and t2.St == 3, "Halo 'Guard my friends': Pick Guard, Honor +1, then the X step",
		show({ e.Story.Pick.SK2, e.Honor, t2.St }))
	-- 검수 2026-10-07: SK2's picks have their side (Guard = Good, Take = Evil), so the pick is a change of mind like the others
	check(e.Story.LastSide == "Good" and said(w, q, nk, SQ0.Text.ChangedGood),
		"SK2 'Guard' is a Good pick: LastSide Good and the change-of-mind line after an Evil one",
		show({ e.Story.LastSide, w:NoticesFor(q, nk) }))
	CS.Released:Fire(q, { Slot = "Z", Auto = false, MonstersHit = 3 })
	CS.Released:Fire(q, { Slot = "X", Auto = false, MonstersHit = 0 })
	w:Flush()
	check((t2.P or 0) == 0, "a Z cast or an X that hit nothing: not counted", t2.P)
	for _ = 1, 3 do CS.Released:Fire(q, { Slot = "X", Auto = false, MonstersHit = 1 }) end
	w:Flush()
	check(e.Story.Done.SK2 == true and w:Track(e, "SK2") == nil, "3 manual X casts that hit: SK2 done", show(e.Story.Done.SK2))
end)

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
local CH3 = { "M3_1", "M3_2", "M3_3", "M3_4", "M3_6", "M3_7", "M3_8" } -- A23-86: M3_5 is a side line now (checked below)

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
	-- M3_5 (A23-86: a side line, the main chain goes on): the Sprout Shield must be over (E7)
	w.Story.Refresh(p)
	check(main().Id == "M3_6" and w:Track(d, "M3_5") ~= nil and w:Track(d, "M3_5").St == 1, "M3_5 waits for graduation beside M3_6", show({ main(), d.Story.Subs.M3_5 }))
	rookie[p] = false
	w.Story.Refresh(p)
	w:Flush()
	check(w:Track(d, "M3_5").St == 2 and panels[#panels].Arg.Id == "M3_5", "graduated: the Guide's talk opens", show(d.Story.Subs.M3_5))
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
				and sameReward(pick.Evil.Reward, { Potion = "HP", N = 3, Gold = 220 }),
				id .. ": A = one 70% scroll, B = 3 HP potions + 220 gold (town- and woods-type the same, 검수 10/10)", show({ pick.Good.Reward, pick.Evil.Reward }))
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
	check(d.Story.Done.S6 and d.Story.Pick.S6 == "Evil" and (d.Infamy or 0) == infamy + 1 and (d.BankGold or 0) >= bank + 220 + 120,
		"Count it twice: Infamy +1, 3 potions + 220 gold, then 120 gold", show({ d.Infamy, (d.BankGold or 0) - bank }))
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

------------------------------------------------------------------ 빛 마을 점검 2026-10-10 (#2, #18, #35-#38, #40, #71)
local function halo(w, userId, level, through)
	local p, d = joinDone(w, userId, "Halo", level, through)
	w.ZoneOf[p] = "SlimeMeadow"
	return p, d
end
local function storyPanels(panels, id)
	local n = 0
	for _, pn in panels do if pn.Kind == "Story" and pn.Arg and pn.Arg.Id == id then n += 1 end end
	return n
end

runGroup("halo-check-data", function()
	local D = SQ0.Defs
	check(D.H1.Steps[3].Text == "Slime Princes in the meadow %d/%d", "#38 H1: any Slime Prince in the meadow (the row says so)",
		D.H1.Steps[3].Text)
	check(D.H2.Steps[1].Guide == "Fountain", "#37 H2 step 1 guides to the fountain", D.H2.Steps[1].Guide)
	check(type(D.H3.Start) == "string" and D.H3.Start ~= "" and type(D.H5.Start) == "string" and D.H5.Start ~= "",
		"#18 H3 / H5 have a Start line", show({ D.H3.Start, D.H5.Start }))
	-- #56: every Halo-only pick happens in Halo Citadel: at Bright (Npc) or right after a step that brings you home
	local function home(step)
		local o = step and step.Obj
		if not o then return false end
		if o.Type == "Enter" then return o.Zone == "HaloTown" or o.Zone == "OwnTown" end
		if o.Type == "Near" then
			local spot = SQ0.Landmarks[o.Spot]
			return spot ~= nil and C0.ZoneAt(spot).Id == "HaloTown"
		end
		return false
	end
	local seen = 0
	for id, def in D do
		local f = def.Factions
		if type(f) == "table" and f.Halo == true and f.Horns == nil and f.Neutral == nil then
			for i, step in def.Steps do
				if step.Obj and step.Obj.Type == "Choice" then
					seen += 1
					check(step.Npc ~= nil or home(def.Steps[i - 1]), id .. " pick " .. i .. ": in Halo Citadel (Npc, or after a way home)",
						show({ step.Npc, def.Steps[i - 1] and def.Steps[i - 1].Obj }))
					check(step.Panel == true, id .. " pick " .. i .. ": a card", "")
				end
			end
		end
	end
	check(seen >= 6, "the Halo-only picks were all looked at (H1 H2 H3 H5 H6 OathH)", seen)
	check(C0.QuestTab("story:OathH", "Sub") == "Faction" and C0.QuestTab("story:OathR", "Sub") == "Faction",
		"#40 the oaths sit in the Faction tab", show({ C0.QuestTab("story:OathH", "Sub"), C0.QuestTab("story:OathR", "Sub") }))
	check(SQ0.LandmarkTag == "StoryLandmark", "#2 landmark marker tag", SQ0.LandmarkTag)
end)

runGroup("halo-check-h2", function()
	local w = townWorld({ Npcs = false })
	local panels = panelsOf(w)
	local p, d = halo(w, 1401, 8, "M1_4")
	local tr = w:Track(d, "H2")
	check(tr and tr.St == 1, "H2 offered", show(tr))
	w.ZoneOf[p] = "Crossroads"
	local f = SQ0.Landmarks.Fountain
	w:MoveTo(p, vec(f.X + 3, 0, f.Z))
	w:Tick(p, 1)
	check(tr.St == 2, "the fountain: on to the slimes", show(tr))
	w.ZoneOf[p] = "SlimeMeadow"
	local n0 = #w.Notices
	w:Kill(p, "Slime", 5)
	w:Tick(p, 1)
	check(tr.St == 3 and storyPanels(panels, "H2") == 0, "#36 5 slimes: take it home first (no pick card in the meadow)",
		show({ tr.St, storyPanels(panels, "H2") }))
	check(indexOf(w:NoticesFor(p, n0), SQ0.Defs.H2.Steps[3].Start) ~= nil, "the 'take it home' line", show(w:NoticesFor(p, n0)))
	w.ZoneOf[p] = "HaloTown"
	w:Tick(p, 1)
	check(tr.St == 4 and storyPanels(panels, "H2") == 1, "home in Halo Citadel: the pick card opens there", show({ tr.St, storyPanels(panels, "H2") }))
	local hp, bank = d.HPPotionCount or 0, d.BankGold or 0
	w:Act(p, "H2", "Choose", "Evil")
	check(d.Story.Done.H2 and (d.HPPotionCount or 0) == hp + 3 and (d.BankGold or 0) == bank + 220 + 120,
		"#71 Hang it in my house: 3 HP potions + 220 gold, then 120", show({ (d.HPPotionCount or 0) - hp, (d.BankGold or 0) - bank }))
	-- an old save that waited at the pick (old step 3) now walks home first
	local q, e = halo(w, 1402, 8, "M1_4")
	local t2 = w:Track(e, "H2")
	t2.St = 3
	w:Tick(q, 1)
	check(t2.St == 3, "an old save at the old pick step: in the meadow it waits for the way home", show(t2))
	w.ZoneOf[q] = "HaloTown"
	w:Tick(q, 1)
	check(t2.St == 4, "... and gets the card in Halo Citadel", show(t2))
end)

runGroup("halo-check-h3", function()
	local w = townWorld({ Npcs = false })
	local panels = panelsOf(w)
	local p, d = halo(w, 1411, 12)
	local tr = w:Track(d, "H3")
	check(tr ~= nil, "H3 offered", show(d.Story.Subs))
	if not tr then return end
	tr.St = 2
	local before = storyPanels(panels, "H3")
	w:Kill(p, "Slime", 6)
	w:Tick(p, 1)
	check(tr.St == 3 and storyPanels(panels, "H3") == before, "#36 6 slimes: back to Sir Gleam first (no card in the meadow)",
		show({ tr.St, storyPanels(panels, "H3") - before }))
	w.ZoneOf[p] = "HaloTown"
	w:Tick(p, 1)
	-- 검수 10/10: the card is talked through Sir Gleam (Npc "Gleam", the TownNpcs body): it never pops by itself
	check(tr.St == 4 and storyPanels(panels, "H3") == before, "in Halo Citadel: Sir Gleam's card waits for the talk",
		show({ tr.St, storyPanels(panels, "H3") - before }))
	check(SQ0.Defs.H3.Steps[1].Npc == "Gleam" and SQ0.Defs.H3.Steps[4].Npc == "Gleam", "H3's talks are at Sir Gleam",
		show({ SQ0.Defs.H3.Steps[1].Npc, SQ0.Defs.H3.Steps[4].Npc }))
	w:Act(p, "H3", "Open")
	check(storyPanels(panels, "H3") == before + 1, "talking to him opens the card (no Gleam body here: anywhere)",
		storyPanels(panels, "H3") - before)
end)

runGroup("halo-check-h6", function()
	local w = townWorld({ Npcs = false })
	local panels = panelsOf(w)
	local p, d = halo(w, 1421, 22)
	local tr = w:Track(d, "H6")
	check(tr ~= nil, "H6 offered", show(d.Story.Subs))
	if not tr then return end
	tr.St = 3 -- after the goblins
	w.ZoneOf[p] = "GoblinWoods"
	w:MoveTo(p, vec(400, 0, -60))
	w:Tick(p, 1)
	check(tr.St == 3 and storyPanels(panels, "H6") == 0, "#35 in the woods: no statue card", show({ tr.St, storyPanels(panels, "H6") }))
	local hs = SQ0.Landmarks.HeroStatue
	w.ZoneOf[p] = "HaloTown"
	w:MoveTo(p, vec(hs.X + 5, 0, hs.Z))
	w:Tick(p, 1)
	check(tr.St == 4 and storyPanels(panels, "H6") == 1, "at the hero statues: the card opens", show({ tr.St, storyPanels(panels, "H6") }))
end)

runGroup("halo-check-landmark", function()
	local w = townWorld()
	local hs = SQ0.Landmarks.HeroStatue
	local moved = vec(hs.X, 0, hs.Z - 60)
	local p, d = halo(w, 1431, 22)
	local tr = w:Track(d, "H6")
	check(tr ~= nil, "H6 offered", show(d.Story.Subs))
	if not tr then return end
	tr.St = 3
	w.ZoneOf[p] = "HaloTown"
	w:Mark("HeroStatue", moved, true) -- a kit copy outside the workspace: ignored
	w:Mark("LavaCrack", moved) -- another spot's marker: ignored
	w:MoveTo(p, vec(moved.X + 3, 0, moved.Z))
	w:Tick(p, 1)
	check(tr.St == 3, "#2 a marker outside the workspace or for another spot moves nothing", show(tr))
	w:MoveTo(p, vec(hs.X + 3, 0, hs.Z))
	w:Tick(p, 1)
	check(tr.St == 4, "... the Config spot still works", show(tr))
	-- a placed marker moves the spot: the old Config place no longer counts, the marker does
	local q, e = halo(w, 1432, 22)
	local t2 = w:Track(e, "H6")
	t2.St = 3
	w.ZoneOf[q] = "HaloTown"
	w:Mark("HeroStatue", moved)
	w:MoveTo(q, vec(hs.X + 3, 0, hs.Z))
	w:Tick(q, 1)
	check(t2.St == 3, "#2 with the statue marker placed: the old spot no longer counts", show(t2))
	w:MoveTo(q, vec(moved.X + 3, 0, moved.Z))
	w:Tick(q, 1)
	check(t2.St == 4, "... standing at the marker does", show(t2))
	-- kills with Near follow a marker too (S6 Halo: slimes by the meadow arrival)
	local r, f = halo(w, 1433, 6, "M1_4")
	local t3 = w:Track(f, "S6")
	check(t3 and t3.St == 1, "S6 offered", show(f.Story.Subs))
	if not t3 then return end
	local arrival = SQ0.Landmarks.MeadowArrival
	local far = vec(arrival.X + 300, 0, arrival.Z + 300)
	w:Mark("MeadowArrival", far)
	local function slimeAt(pos)
		w.Registry.MonsterService.MonsterKilled:Fire(r, { Kind = "Slime", ZoneId = "SlimeMeadow", Golden = false, Personal = false,
			Position = pos, WarPoints = 0 })
		w:Flush()
	end
	slimeAt(arrival)
	check(math.floor(t3.P or 0) == 0, "#2 a kill at the old arrival spot no longer counts", show(t3))
	slimeAt(far)
	check(math.floor(t3.P or 0) == 1, "... a kill at the marker does", show(t3))
end)

------------------------------------------------------------------ 13. zone_check_halo #19: every active sub is sent (SendAllSubs) + town offers
-- a new faction town-NPC offer ranks with the subs in progress (newer first); with SendAllSubs the rows past MaxSubs come too,
-- marked More = true (the HUD skips them, the quest window lists all)
runGroup("send-all-subs", function()
	check(SQ0.SendAllSubs == true, "SendAllSubs is on in the real Config (the HUD skips More rows, the quest window lists all)", tostring(SQ0.SendAllSubs))
	local w = townWorld()
	w:Npc("Bright", vec(0, 0, -400))
	local p, d = joinAfterM23(w, 702, "Halo", { Pos = vec(2, 0, -398) })
	-- only H1 (Bright's offer) stays active; three older subs are in progress
	w.Story.Refresh(p)
	for _, id in w.Config.StoryQuests.Subs do
		if id ~= "H1" then
			d.Story.Subs[id] = nil
			d.Story.Done[id] = true -- finished: never started again
		end
	end
	local function oldSub(id)
		w.Config.StoryQuests.Defs[id] = { Kind = "Sub", Title = id, Steps = {
			{ Text = "Slimes %d/%d", Obj = { Type = "Kill", Kind = "Slime", Count = 5 } },
			{ Text = "More slimes %d/%d", Obj = { Type = "Kill", Kind = "Slime", Count = 5 } } } }
		table.insert(w.Config.StoryQuests.Subs, 1, id) -- OLDER than H1: first in the list (each next one before it)
		d.Story.Done[id] = nil
		d.Story.Subs[id] = { St = 2, P = 0, T = {}, Claim = false } -- in progress
	end
	for _, id in { "T1", "T2", "T3" } do oldSub(id) end
	-- W1: a Halo-only card with no NPC to talk to (newest in the list): a plain offer, NOT a town-NPC offer
	w.Config.StoryQuests.Defs.W1 = { Kind = "Sub", Title = "W1", Factions = { Halo = true }, Steps = {
		{ Text = "Listen", Panel = true, Lines = { All = { "Hello." } }, Obj = { Type = "Talk" } } } }
	table.insert(w.Config.StoryQuests.Subs, "W1")
	d.Story.Done.W1 = nil
	d.Story.Subs.W1 = { St = 1, P = 0, T = {}, Claim = false }
	w.Story.Refresh(p)
	local function ids(list)
		local out = {}
		for _, r in list do table.insert(out, r.Story and r.Story.Id or "?") end
		return out
	end
	local function more(list)
		local out = {}
		for _, r in list do table.insert(out, r.More == true and "M" or "-") end
		return table.concat(out)
	end
	check(d.Story.Subs.H1 and d.Story.Subs.H1.St == 1, "H1 waits at Bright (its first card)", show(d.Story.Subs.H1))
	local off = w.Story.SubRows(p, d)
	check(table.concat(ids(off), ",") == "T1,T2,T3" and more(off) == "---",
		"a town-NPC offer waits behind the subs in progress: T1, T2, T3 stay (newest first), H1 waits for a free row", table.concat(ids(off), ",") .. " " .. more(off))
	-- SendAllSubs: the fourth active sub is sent too, marked More
	w.Config.StoryQuests.SendAllSubs = true
	local all = w.Story.SubRows(p, d)
	check(table.concat(ids(all), ",") == "T1,T2,T3,H1,W1" and more(all) == "---MM", "SendAllSubs: all five active subs, the 4th and 5th marked More (the town offer before the plain one)",
		table.concat(ids(all), ",") .. " " .. more(all))
	for _, r in all do
		check(r.Rank == nil and r.Order == nil, "the " .. tostring(r.Story and r.Story.Id) .. " row sends no Rank / Order", show({ r.Rank, r.Order }))
	end
	for i = 1, 3 do check(all[i].More == nil, "row " .. i .. " (the HUD's) has no More", tostring(all[i].More)) end
	-- the same first three as with the flag off (the HUD sees no change)
	check(table.concat({ ids(all)[1], ids(all)[2], ids(all)[3] }, ",") == table.concat(ids(off), ","), "the first three rows are the same with the flag on", "")
	-- MaxSubs still decides which rows are the HUD's
	w.Config.StoryQuests.MaxSubs = 2
	local two = w.Story.SubRows(p, d)
	check(more(two) == "--MMM" and #two == 5, "MaxSubs 2: the rows past 2 are More", more(two))
	w.Config.StoryQuests.MaxSubs = 0
	check(more(w.Story.SubRows(p, d)) == "MMMMM", "MaxSubs 0: every row is More", "")
	w.Config.StoryQuests.MaxSubs = 3
	-- only `true` turns it on
	w.Config.StoryQuests.SendAllSubs = 1
	check(#w.Story.SubRows(p, d) == 3, "SendAllSubs = 1 is not true: three rows", tostring(#w.Story.SubRows(p, d)))
	-- flag back off: three rows, none More
	w.Config.StoryQuests.SendAllSubs = false
	local back = w.Story.SubRows(p, d)
	check(#back == 3 and more(back) == "---", "the flag off again: three rows, none More", more(back))
	-- a free row: the town offer takes it before the plain offer (rank 2.5 < 3), after the subs in progress
	d.Story.Subs.T3, d.Story.Done.T3 = nil, true
	-- W2: an NPC card of nobody's faction (no Factions): a plain offer too, not a town offer (it must not outrank H1)
	w.Config.StoryQuests.Defs.W2 = { Kind = "Sub", Title = "W2", Steps = {
		{ Text = "Hello", Panel = true, Npc = "Bright", Lines = { All = { "Hi." } }, Obj = { Type = "Talk" } } } }
	table.insert(w.Config.StoryQuests.Subs, "W2")
	d.Story.Done.W2 = nil
	w.Story.Refresh(p)
	local free = w.Story.SubRows(p, d)
	check(table.concat(ids(free), ",") == "T1,T2,H1" and more(free) == "---", "T3 done: a row is free, the town offer H1 takes it (W1 waits)", table.concat(ids(free), ",") .. " " .. more(free))
	w.Config.StoryQuests.SendAllSubs = true
	local freeAll = w.Story.SubRows(p, d)
	check(table.concat(ids(freeAll), ",") == "T1,T2,H1,W2,W1" and more(freeAll) == "---MM", "and with SendAllSubs the plain offers follow (newer first), marked More", table.concat(ids(freeAll), ",") .. " " .. more(freeAll))
	w.Config.StoryQuests.SendAllSubs = false
	-- a town offer of another faction never shows
	local h, hd = joinAfterM23(w, 703, "Horns", { Pos = vec(2, 0, 398) })
	local hid = {}
	for _, r in w.Story.SubRows(h, hd) do hid[r.Story and r.Story.Id or "?"] = true end
	check(not hid.H1, "a Horns player never gets Bright's offer", show(hid))
end)

------------------------------------------------------------------ A23-104: the intro quest of the daily jobs (QuestService opens them when it ends)
runGroup("daily intro quest (A23-104)", function()
	local w = townWorld({ D0 = true })
	local panels = panelsOf(w)
	local done = {}
	w.Story.QuestDone:Connect(function(_, id) table.insert(done, id) end)
	local def = SQ0.Defs.D0
	check(def.Reward.Gold == 1 and def.Reward.XP == 1 and def.Finish == "Daily jobs are open!" and def.Steps[1].Lines.All[1] ~= nil
		and C0.Daily.IntroQuest == "D0", "D0: a small reward, the closing line 'Daily jobs are open!', the guide speaks (no Speaker)", show(def.Reward))
	-- before the first chapter is over: nothing is offered
	local e, ed = joinAfterM23(w, 970, "Halo", { Before = true })
	w.Story.Refresh(e)
	check(w:Track(ed, "D0") == nil, "D0 is not offered before M1_4", show(w:Track(ed, "D0")))
	local uid = 970
	for _, faction in { "Halo", "Horns", "Neutral" } do
		uid += 1
		local before = #panels
		local p, d = joinAfterM23(w, uid, faction)
		local tr = w:Track(d, "D0")
		local row = rowOf(w, p, d, "D0")
		check(tr ~= nil and tr.St == 1 and #panels == before and row ~= nil and row.Story.Panel == true and row.Text == "Hear about the daily jobs" and row.CanClaim == false,
			faction .. ": after M1_4 the intro starts by itself as a row (nothing pops up); tapping it is the player's move", show({ tr, row and row.Text, #panels - before }))
		w:Act(p, "D0", "Open")
		local card = panels[#panels]
		check(#panels == before + 1 and card.P == p and card.Arg.Id == "D0" and card.Arg.St == 1, faction .. ": tapped: its dialogue opens", show(card and card.Arg))
		local n0 = #w.Notices
		local gold0 = d.BankGold or 0
		w:Act(p, "D0", "Talk")
		check(d.Story.Done.D0 == true and w:Track(d, "D0") == nil and done[#done] == "D0" and (d.BankGold or 0) > gold0
			and said(w, p, n0, "Daily jobs are open!"), faction .. ": talked: done, QuestDone fires, a little gold, 'Daily jobs are open!'", show({ done, d.BankGold }))
		w.Story.Refresh(p)
		w:Act(p, "D0", "Talk")
		local count = 0
		for _, id in done do if id == "D0" then count += 1 end end
		check(count == uid - 970 and w:Track(d, "D0") == nil, faction .. ": never again", tostring(count))
	end
end)

------------------------------------------------------------------ 14. story_depth (나) the beta Easter eggs EG01 / EG02 / EG03 / EG04 / EG14
-- hidden Crossroads subs after M2_3: no toast, no row, no marker; walking to the spot finds one (its dialogue opens by itself);
-- a found egg pays a stat-free title only
runGroup("easter-eggs", function()
	local EGGS = { "EG01", "EG02", "EG03", "EG04", "EG14" }
	local SPOT = { EG01 = "TermsScroll", EG02 = "PatchNote", EG03 = "GooseNest", EG04 = "Fountain", EG14 = "KidsBench" }
	local TITLE = { EG02 = "BugReporter", EG03 = "GooseFan", EG04 = "SkyWatcher", EG14 = "BenchDetective" }
	local w = townWorld()
	local panels = panelsOf(w)
	local owned, grants = {}, {}
	w.Registry.TitleService = { Grant = function(p, id)
		table.insert(grants, id)
		if owned[id] then return false end
		owned[id] = true
		return true
	end }
	-- data
	for _, id in EGGS do
		local def = SQ0.Defs[id]
		check(def and def.Kind == "Sub" and def.Hidden == true and def.Factions == nil and table.concat(def.Requires.Done, ",") == "M2_3",
			id .. ": a hidden sub for everyone after M2_3", show(def and { def.Kind, def.Hidden, def.Factions, def.Requires }))
		check(table.find(SQ0.Subs, id) ~= nil, id .. " is in StoryQuests.Subs", "")
		check(type(def.ShortName) == "string" and #def.ShortName <= 14 and #def.Title > 0, id .. ": a phone name of at most 14 letters", tostring(def.ShortName))
		local first = def.Steps[1]
		check(first.Obj.Type == "Near" and first.Obj.Spot == SPOT[id] and first.Panel ~= true and first.Npc == nil and first.Start == nil,
			id .. ": step 1 = go near " .. SPOT[id] .. " (no NPC, no start line)", show(first))
		check(SQ0.Landmarks[SPOT[id]] ~= nil and C0.ZoneAt(SQ0.Landmarks[SPOT[id]]).Id == "Crossroads", SPOT[id] .. " is in the Crossroads", "")
		local last = def.Steps[#def.Steps]
		check(last.Panel == true and last.Npc == nil and (last.Obj.Type == "Talk"), id .. ": ends with a dialogue that opens by itself", show(last.Obj))
		local r = def.Reward
		check(r.Gold == nil and r.XP == nil and r.GoldN == nil and r.XPBar == nil and r.Item == nil and r.Potion == nil,
			id .. ": the reward is a title only", show(r))
		if TITLE[id] then
			check(r.Title == TITLE[id] and C0.TitleDefs[TITLE[id]] ~= nil and table.find(C0.TitleOrder, TITLE[id]) ~= nil,
				id .. ": title " .. TITLE[id] .. " exists and is in the picker", show(r))
		end
	end
	check(SQ0.Defs.EG01.Reward.TitleBy.Good == "ActuallyReadIt" and SQ0.Defs.EG01.Reward.TitleBy.Evil == "DidntReadIt"
		and C0.TitleDefs.ActuallyReadIt and C0.TitleDefs.DidntReadIt and table.find(C0.TitleOrder, "ActuallyReadIt") and table.find(C0.TitleOrder, "DidntReadIt"),
		"EG01: Read it all = Actually Read It, I agree = Didn't Read It", show(SQ0.Defs.EG01.Reward))
	local pick = SQ0.Defs.EG01.Steps[2].Obj
	check(pick.Type == "Choice" and pick.Good.Label == "Read it all" and pick.Evil.Label == "I agree" and pick.Neutral.A == "Read it all"
		and pick.Neutral.B == "I agree" and pick.Good.Points == 0 and pick.Evil.Points == 0, "EG01: the card's labels (a Neutral save too), 0 points", show(pick))
	check(pick.MyWay == false and SQ0.Defs.EG04.Steps[2].Obj.MyWay == nil, "EG01: the joke pick is marked MyWay = false (only that one)", show(pick))
	check(SQ0.Defs.EG01.Speaker == "Scroll" and SQ0.Defs.EG02.Speaker == "Notice" and SQ0.Defs.EG03.Speaker == "Goose"
		and SQ0.Defs.EG04.Speaker == "Shard" and SQ0.Defs.EG14.Speaker == "Notice"
		and SQ0.Speakers.Scroll == "Terms of Fate" and SQ0.Speakers.Notice == "Notice" and SQ0.Speakers.Goose == "Golden Goose"
		and SQ0.Speakers.Shard == "Crown Shard", "every egg has its own speaker (a scroll, a note, the goose, the Crown Shard): no guide name or face",
		show({ SQ0.Defs.EG01.Speaker, SQ0.Defs.EG02.Speaker, SQ0.Defs.EG03.Speaker, SQ0.Defs.EG04.Speaker, SQ0.Defs.EG14.Speaker }))
	check(SQ0.Portraits.Scroll == nil and SQ0.Portraits.Notice == nil and SQ0.Portraits.Goose == nil and SQ0.Portraits.Shard == "PTR_CrownShard",
		"the scroll, the note and the goose get no face; the Crown Shard keeps hers", show({ SQ0.Portraits.Scroll, SQ0.Portraits.Notice, SQ0.Portraits.Goose, SQ0.Portraits.Shard }))
	check(SQ0.Defs.EG04.Steps[2].Lines.All[1] == "Stop staring. I'm broken, not famous.", "EG04: the Shard's line has no 'Sky Crown:' label (the speaker says it)", SQ0.Defs.EG04.Steps[2].Lines.All[1])
	local speakerOk = true
	for id, def in SQ0.Defs do
		if def.Speaker ~= nil and SQ0.Speakers[def.Speaker] == nil then speakerOk = false end
	end
	check(speakerOk, "every quest's Speaker names a Speakers entry", "")
	check(SQ0.Landmarks.TermsScroll.Z > C0.Map.AltarPosition.Z and SQ0.Landmarks.PatchNote.X > C0.Map.BoardPosition.X
		and SQ0.Landmarks.GooseNest.X == C0.Goose.Position.X and SQ0.Landmarks.GooseNest.Z == C0.Goose.Position.Z,
		"the scroll is behind the Altar, the slip in front of the Wanted Board, the nest is the goose perch", "")
	-- before M2_3 nothing starts; after it all five are hidden
	local early, ed = joinAfterM23(w, 901, "Halo", { Before = true })
	for _, id in EGGS do check(w:Track(ed, id) == nil, id .. ": not started before M2_3", "") end
	local n0 = #w.Notices
	local p, d = joinAfterM23(w, 902, "Halo", { Pos = vec(300, 0, 300) })
	local ids = {}
	for _, r in w.Story.SubRows(p, d) do ids[r.Story and r.Story.Id or "?"] = true end
	for _, id in EGGS do
		check(w:Track(d, id) and w:Track(d, id).St == 1, id .. ": started after M2_3 (step 1)", show(w:Track(d, id)))
		check(rowOf(w, p, d, id) == nil and not ids[id], id .. ": no quest row before it is found", "")
	end
	local toast = false
	for _, t in w:NoticesFor(p, n0) do
		if string.find(t, "Terms of Fate", 1, true) or string.find(t, "Patch Note", 1, true) or string.find(t, "Goose Fan", 1, true)
			or string.find(t, "Sky Watcher", 1, true) or string.find(t, "Bench Detective", 1, true) then toast = true end
	end
	check(not toast, "no start toast for any egg", show(w:NoticesFor(p, n0)))
	local listed = false
	for _, e in w.Story.BookRows(p, d).Available do
		if string.find(e.Id, "story:EG", 1, true) == 1 then listed = true end
	end
	check(not listed, "the quest book does not list an unfound egg", show(w.Story.BookRows(p, d).Available))
	-- the three one-card eggs: walk there, the card opens by itself, [Talk] ends it with a title
	local uid = 910
	for _, id in { "EG02", "EG03", "EG14" } do
		uid += 1
		local spot = SQ0.Landmarks[SPOT[id]]
		local q, qd = joinAfterM23(w, uid, "Halo", { Pos = vec(spot.X + 80, 0, spot.Z) })
		w:Tick(q, 1)
		check(w:Track(qd, id).St == 1 and rowOf(w, q, qd, id) == nil, id .. ": 80 studs away: still hidden", show(w:Track(qd, id)))
		local before = #panels
		w:MoveTo(q, vec(spot.X + 10, 0, spot.Z))
		w:Tick(q, 1)
		check(w:Track(qd, id).St == 1, id .. ": 10 studs away is still too far (radius 6)", show(w:Track(qd, id)))
		w:MoveTo(q, vec(spot.X + 3, 0, spot.Z))
		w:Tick(q, 1)
		local card = panels[#panels]
		check(w:Track(qd, id).St == 2 and #panels == before + 1 and card.Arg.Id == id and card.Arg.St == 2 and rowOf(w, q, qd, id) ~= nil,
			id .. ": 3 studs away: found, the dialogue opens by itself, the row shows", show({ w:Track(qd, id), card and card.Arg }))
		local n1 = #w.Notices
		w:Act(q, id, "Talk")
		check(qd.Story.Done[id] == true and w:Track(qd, id) == nil and grants[#grants] == TITLE[id]
			and said(w, q, n1, string.format(SQ0.Text.NewTitle, C0.TitleDefs[TITLE[id]].Name)),
			id .. ": talked: done, title " .. TITLE[id] .. ", 'New title: ...!'", show({ grants, w:NoticesFor(q, n1) }))
		check((qd.Honor or 0) == 0 and (qd.Infamy or 0) == 0 and (qd.BankGold or 0) == 0, id .. ": no points, no gold", show({ qd.Honor, qd.BankGold }))
		w:Act(q, id, "Talk")
		w.Story.Refresh(q)
		local count = 0
		for _, g in grants do if g == TITLE[id] then count += 1 end end
		check(count == 1 and w:Track(qd, id) == nil, id .. ": never again (not restarted, no second title)", tostring(count))
	end
	-- EG04: 30 seconds at the fountain in one go (leaving resets)
	local fountain = SQ0.Landmarks.Fountain
	local f, fd = joinAfterM23(w, 950, "Horns", { Pos = vec(fountain.X + 5, 0, fountain.Z) })
	w:Tick(f, 29)
	check(w:Track(fd, "EG04").St == 1 and rowOf(w, f, fd, "EG04") == nil, "EG04: 29 s at the fountain: not yet, still hidden", show(w:Track(fd, "EG04")))
	w:MoveTo(f, vec(fountain.X + 60, 0, fountain.Z))
	w:Tick(f, 1)
	w:MoveTo(f, vec(fountain.X + 5, 0, fountain.Z))
	w:Tick(f, 29)
	check(w:Track(fd, "EG04").St == 1, "EG04: leaving the fountain starts the 30 s again", show(w:Track(fd, "EG04")))
	local b4 = #panels
	w:Tick(f, 2)
	local card4 = panels[#panels]
	check(w:Track(fd, "EG04").St == 2 and #panels == b4 + 1 and card4.Arg.Id == "EG04", "EG04: 30 s in one go: found, the Sky Crown speaks", show({ w:Track(fd, "EG04"), card4 and card4.Arg }))
	w:Act(f, "EG04", "Talk")
	check(fd.Story.Done.EG04 and grants[#grants] == "SkyWatcher", "EG04: title Sky Watcher", show(grants))
	-- EG01: the scroll's choice card; Read it all / I agree; a 0-point pick (no score)
	local scroll = SQ0.Landmarks.TermsScroll
	for _, case in { { "Halo", "Good", "ActuallyReadIt", 960 }, { "Horns", "Evil", "DidntReadIt", 961 }, { "Neutral", "A", "ActuallyReadIt", 962 },
		{ "Neutral", "B", "DidntReadIt", 963 } } do
		local side, option, title, userId = case[1], case[2], case[3], case[4]
		local before = #panels
		local q, qd = joinAfterM23(w, userId, side, { Pos = vec(scroll.X + 2, 0, scroll.Z) })
		w:Tick(q, 1)
		local card = panels[#panels]
		check(w:Track(qd, "EG01").St == 2 and #panels == before + 1 and card.Arg.Id == "EG01" and card.Arg.St == 2, "EG01 (" .. side .. "): the scroll's choice opens by itself", show(card and card.Arg))
		w:Act(q, "EG01", "Choose", option)
		local after = panels[#panels]
		local expectVar = (option == "Good" or option == "A") and "Good" or "Evil"
		check(w:Track(qd, "EG01").St == 3 and after.Arg.Id == "EG01" and after.Arg.St == 3 and (after.Arg.Var == expectVar or after.Arg.Var == option),
			"EG01 (" .. side .. " " .. option .. "): the fine print for that pick", show(after and after.Arg))
		check((qd.Honor or 0) == 0 and (qd.Infamy or 0) == 0, "EG01 (" .. side .. " " .. option .. "): a 0-point pick, no score", show({ qd.Honor, qd.Infamy }))
		w:Act(q, "EG01", "Talk")
		check(qd.Story.Done.EG01 == true and grants[#grants] == title, "EG01 (" .. side .. " " .. option .. "): title " .. title, show(grants))
	end
	-- the fine print differs by pick (LinesBy its own pick), and a finished egg lands in the book's Done list
	local ln = SQ0.Defs.EG01.Steps[3].LinesBy
	check(#ln.Good.All == 3 and #ln.Evil.All == 1 and #ln.Default.All == 1 and type(SQ0.Defs.EG01.Steps[3].Lines) == "table",
		"EG01: three pages for 'Read it all', one for 'I agree', a Lines fallback", show({ #ln.Good.All, #ln.Evil.All }))
	local pp, pd = joinAfterM23(w, 970, "Halo", { Pos = vec(SQ0.Landmarks.PatchNote.X + 1, 0, SQ0.Landmarks.PatchNote.Z) })
	w:Tick(pp, 1)
	w:Act(pp, "EG02", "Talk")
	local inDone = false
	for _, id in w.Story.BookRows(pp, pd).Done do if id == "story:EG02" then inDone = true end end
	check(inDone, "a found egg is listed in the quest book's Done", show(w.Story.BookRows(pp, pd).Done))
end)

------------------------------------------------------------------ 15. zone_check_halo #22 / #25 / #30: the town NPC's "Talk" prompt
-- (TownNpcs: attribute StoryNpcId) opens the dialogue of the quest step that is talked through that NPC
runGroup("npc-talk", function()
	local w = townWorld({ Prompts = true })
	local panels = panelsOf(w)
	w:Npc("Bright", vec(0, 0, -400))
	local p, d = joinAfterM23(w, 980, "Halo", { Pos = vec(2, 0, -398) })
	check(w:Track(d, "H1") and w:Track(d, "H1").St == 1, "H1 waits at Bright (its first card)", show(w:Track(d, "H1")))
	local before = #panels
	check(#panels == before, "a step talked through an NPC never pops up by itself", "")
	check(w.Story.TalkToNpc(p, "Bright") == "H1" and #panels == before + 1 and panels[#panels].Arg.Id == "H1" and panels[#panels].Arg.St == 1,
		"talking to Bright opens H1's card", show(panels[#panels] and panels[#panels].Arg))
	-- far from her, another id, bad arguments: nothing
	w:MoveTo(p, vec(80, 0, -400))
	check(w.Story.TalkToNpc(p, "Bright") == nil and #panels == before + 1, "80 studs away: nothing opens", "")
	w:MoveTo(p, vec(2, 0, -398))
	check(w.Story.TalkToNpc(p, "Smokey") == nil and w.Story.TalkToNpc(p, "Nobody") == nil and w.Story.TalkToNpc(p, 5) == nil
		and w.Story.TalkToNpc(p, nil) == nil and w.Story.TalkToNpc(nil, "Bright") == nil and w.Story.TalkToNpc("p", "Bright") == nil and #panels == before + 1,
		"another NPC, a bad id or a bad player: nothing", "")
	-- a player who has not chosen a class / is not ready
	local fresh = joinAfterM23(w, 981, "Halo", { Pos = vec(2, 0, -398) })
	local b1 = #panels
	check(w.Story.TalkToNpc(fresh, "Bright") == "H1", "(the same player with a class: H1 opens)", "")
	fresh:SetAttribute("ClassChosen", false)
	check(w.Story.TalkToNpc(fresh, "Bright") == nil and #panels == b1 + 1, "a player who has not chosen a class: nothing", "")
	before = #panels - 1 -- (the card above is the base: before + 1 = what is open now)
	-- the prompt itself
	local prompt = newInstance("ProximityPrompt", w)
	prompt:SetAttribute("StoryNpcId", "Bright")
	local PP = w.Services.ProximityPromptService.PromptTriggered
	w:Advance(1)
	PP:Fire(prompt, p)
	check(#panels == before + 2 and panels[#panels].Arg.Id == "H1", "the prompt's trigger opens the card", tostring(#panels - before))
	PP:Fire(prompt, p)
	check(#panels == before + 2, "a second trigger within 0.4 s is ignored (rate limit)", tostring(#panels - before))
	w:Advance(1)
	local shop = newInstance("ProximityPrompt", w)
	PP:Fire(shop, p)
	local other = newInstance("ProximityPrompt", w)
	other:SetAttribute("StoryNpcId", 5)
	PP:Fire(other, p)
	PP:Fire(prompt, nil)
	PP:Fire("text", p)
	check(#panels == before + 2, "a prompt without a StoryNpcId, a bad id, no player: nothing", tostring(#panels - before))
	-- after the card is done the step moves on: nothing left to say
	w:Act(p, "H1", "Talk")
	check(w:Track(d, "H1").St == 2 and w.Story.TalkToNpc(p, "Bright") == nil, "H1 moved on (no more card at Bright): nothing opens", show(w:Track(d, "H1")))
	-- two quests wait at Bright: the newest sub first
	local talk = function(who) return { Text = "Talk", Panel = true, Npc = "Bright", Obj = { Type = "Talk" }, Lines = { All = { who } } } end
	addSub(w, "TX_NA", { Requires = { Done = { "M2_3" } }, Steps = { talk("a") } })
	addSub(w, "TX_NB", { Requires = { Done = { "M2_3" } }, Steps = { talk("b") } })
	local q, qd = joinAfterM23(w, 982, "Halo", { Pos = vec(2, 0, -398) })
	local b2 = #panels
	check(w.Story.TalkToNpc(q, "Bright") == "TX_NB" and #panels == b2 + 1 and panels[#panels].Arg.Id == "TX_NB", "two cards wait at Bright: the newest quest (last in Subs) first", show(panels[#panels] and panels[#panels].Arg))
	w:Act(q, "TX_NB", "Talk")
	check(w.Story.TalkToNpc(q, "Bright") == "H1" or w.Story.TalkToNpc(q, "Bright") == "TX_NA", "then the next one waiting", "")
	-- a finished quest waiting for [Claim] is never opened
	local c, cd = joinAfterM23(w, 983, "Halo", { Pos = vec(2, 0, -398) })
	cd.Story.Subs.H1, cd.Story.Subs.TX_NB = nil, nil
	cd.Story.Subs.TX_NA.Claim = true
	local b3 = #panels
	check(w.Story.TalkToNpc(c, "Bright") == nil and #panels == b3, "a quest waiting for [Claim] is skipped", "")
	-- a dialogue that has no NPC is never opened by a nil / missing NPC id
	addSub(w, "TX_NN", { Requires = { Done = { "M2_3" } }, Steps = { { Text = "Talk", Panel = true, Obj = { Type = "Talk" }, Lines = { All = { "n" } } } } })
	local nn, nnd = joinAfterM23(w, 984, "Halo", { Pos = vec(2, 0, -398) })
	local b4 = #panels
	check(w:Track(nnd, "TX_NN") and w.Story.TalkToNpc(nn, nil) == nil and w.Story.TalkToNpc(nn, 5) == nil and w.Story.TalkToNpc(nn, true) == nil and #panels == b4,
		"a nil / non-string NPC id never opens a dialogue that names no NPC", "")
	-- Sir Gleam: H3's first card is talked through him; its choice card (step 4) opens by itself in the town, no NPC
	w:Npc("Gleam", vec(-10, 0, -372))
	local g, gd = joinAfterM23(w, 985, "Halo", { Pos = vec(-8, 0, -370) })
	gd.Story.Subs.H3 = { St = 1, P = 0, T = {}, Claim = false }
	local b5 = #panels
	check(SQ0.Defs.H3.Steps[1].Npc == "Gleam" and SQ0.Defs.H3.Steps[4].Npc == nil and SQ0.Defs.H3.Steps[4].Obj.Type == "Choice",
		"H3: the first card names Sir Gleam, the choice card names nobody", show(SQ0.Defs.H3.Steps[1].Npc))
	check(w.Story.TalkToNpc(g, "Gleam") == "H3" and #panels == b5 + 1 and panels[#panels].Arg.Id == "H3" and panels[#panels].Arg.St == 1,
		"talking to Sir Gleam opens H3's first card", show(panels[#panels] and panels[#panels].Arg))
	check(w.Story.TalkToNpc(g, "Bright") ~= "H3", "... not by talking to Bright", "")
	gd.Story.Subs.H3.St = 4
	local b6 = #panels
	check(w.Story.TalkToNpc(g, "Gleam") == nil and #panels == b6, "H3's choice card has no NPC: nothing to say to Sir Gleam", "")
	-- no talker present in the world at all: the old fallback (anywhere) is kept for NPC ids that have no body
	w:Npc("Tiny", vec(0, 0, 0))
	check(w.Story.TalkToNpc(c, "Smokey") == nil, "an NPC id nobody waits at: nothing", "")
end)

------------------------------------------------------------------ 16. A23-64 ② afterglow + ① townsfolk lines (zone_check_halo #39)
-- player p's Afterglow Fx since index `from`, in order
local function glowsOf(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Fx do
		local f = w.Fx[i]
		if f.Kind == "Afterglow" and type(f.Data) == "table" and f.Data.UserId == p.UserId then table.insert(out, f) end
	end
	return out
end

-- printable: { Side, Seconds, Private, To = "all" | the receiver's UserId } (a Player double is never printed)
local function glowShow(list)
	local out = {}
	for _, f in list do
		table.insert(out, { Side = f.Data.Side, Seconds = f.Data.Seconds, Private = f.Data.Private,
			To = f.Player == nil and "all" or f.Player.UserId })
	end
	return show(out)
end

runGroup("a23-64 afterglow", function()
	local cards, finisher = nil, nil
	local w = townWorld({ Npcs = false, Hooks = function(world, reg)
		cards, finisher = { Picked = world.Util.Signal.new() }, { Picked = world.Util.Signal.new() }
		reg.ChoiceCard, reg.FinisherService = cards, finisher
	end })
	local A = w.Config.Afterglow
	check(type(A) == "table" and A.Enabled == true and A.Seconds == 60 and type(A.From) == "table" and A.From.Story == true
		and A.From.Card == true and A.From.Finisher == true, "Config.Afterglow: on, 60 s, story + card + finisher picks", show(A))
	local pvp = {}
	w.Registry.ZoneService.IsPvPZone = function(p) return pvp[p] == true end
	local function fresh(id, faction)
		local p, d = w:Join(id, { Faction = faction, Class = "Warrior", Level = 2,
			Data = { TutorialStep = 99, Story = { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = { Migrated = true } } } })
		w.Story.Refresh(p)
		w:Flush()
		return p, d
	end
	-- a 0-point story pick (A23-70 Lunch1) in a safe place: one afterglow to every client
	local p, d = fresh(6401, "Halo")
	local fx0 = #w.Fx
	w:Act(p, "Lunch1", "Choose", "Good")
	local g = glowsOf(w, p, fx0)
	check(#g == 1 and g[1].Player == nil and g[1].Data.Side == "Good" and g[1].Data.Seconds == 60 and g[1].Data.Private == false,
		"[Give it back] (0 points): one Afterglow Good 60 s to every client", glowShow(g))
	local choices = 0
	for i = fx0 + 1, #w.Fx do
		if w.Fx[i].Kind == "Choice" and w.Fx[i].Player == p then choices += 1 end
	end
	check(choices == 1 and d.Story.Pick.Lunch1 == "GiveBack", "the Choice sound Fx still goes to the chooser only, once", choices)
	-- in a PvP area: only the chooser
	local q = fresh(6402, "Halo")
	pvp[q] = true
	fx0 = #w.Fx
	w:Act(q, "Lunch1", "Choose", "Evil")
	g = glowsOf(w, q, fx0)
	check(#g == 1 and g[1].Player == q and g[1].Data.Side == "Evil" and g[1].Data.Private == true,
		"[One bite!] in a PvP area: Afterglow Evil to the chooser only (Private)", glowShow(g))
	-- the zone check fails: counted as PvP
	local r = fresh(6403, "Horns")
	w.Registry.ZoneService.IsPvPZone = function() error("offline: no zone sample yet") end
	fx0 = #w.Fx
	w:Act(r, "Lunch1", "Choose", "Good")
	g = glowsOf(w, r, fx0)
	check(#g == 1 and g[1].Player == r and g[1].Data.Private == true, "an unknown zone counts as PvP: the chooser only", glowShow(g))
	w.Registry.ZoneService.IsPvPZone = function(pl) return pvp[pl] == true end
	-- the artisan guild: A = Good, B = Evil (like the Choice sound)
	local n, nd = fresh(6404, "Neutral")
	check(w:Track(nd, "Lunch1") ~= nil, "a Neutral save gets the lunchbox card too (no Factions)", show(nd.Story.Subs))
	fx0 = #w.Fx
	w:Act(n, "Lunch1", "Choose", "B")
	g = glowsOf(w, n, fx0)
	check(#g == 1 and g[1].Data.Side == "Evil" and nd.Story.Pick.Lunch1 == "B", "a Neutral B pick glows purple (Evil)", glowShow(g))
	-- Seconds comes from Config; the switches
	w.Config.Afterglow.Seconds = 45
	local s1 = fresh(6405, "Halo")
	fx0 = #w.Fx
	w:Act(s1, "Lunch1", "Choose", "Good")
	g = glowsOf(w, s1, fx0)
	check(#g == 1 and g[1].Data.Seconds == 45, "Seconds follows Config.Afterglow.Seconds", glowShow(g))
	w.Config.Afterglow.Seconds = 60
	w.Config.Afterglow.From.Story = false
	local s2, s2d = fresh(6406, "Halo")
	fx0 = #w.Fx
	w:Act(s2, "Lunch1", "Choose", "Good")
	check(#glowsOf(w, s2, fx0) == 0 and s2d.Story.Done.Lunch1 == true, "From.Story = false: the pick works, no glow",
		#glowsOf(w, s2, fx0))
	w.Config.Afterglow.From.Story = true
	w.Config.Afterglow.Enabled = false
	local s3 = fresh(6407, "Halo")
	fx0 = #w.Fx
	w:Act(s3, "Lunch1", "Choose", "Evil")
	check(#glowsOf(w, s3, fx0) == 0, "Enabled = false: no afterglow", #glowsOf(w, s3, fx0))
	w.Config.Afterglow.Enabled = true
	-- a choice card (ChoiceCard.Picked) and the King Slime finisher card (FinisherService.Picked)
	fx0 = #w.Fx
	cards.Picked:Fire(p, "FlowerPatch", "Evil", {})
	cards.Picked:Fire(p, "FlowerPatch", "None", {})
	g = glowsOf(w, p, fx0)
	check(#g == 1 and g[1].Data.Side == "Evil" and g[1].Player == nil, "a choice card's Evil pick glows; a time-up 'None' does not",
		glowShow(g))
	fx0 = #w.Fx
	finisher.Picked:Fire(p, "Help", "SlimeKing")
	finisher.Picked:Fire(p, "Tickle", "SlimeKing")
	finisher.Picked:Fire(p, "None", "SlimeKing")
	g = glowsOf(w, p, fx0)
	check(#g == 2 and g[1].Data.Side == "Good" and g[2].Data.Side == "Evil",
		"the finisher card: Help = Good, Tickle = Evil, None = no glow", glowShow(g))
	w.Config.Afterglow.From.Card = false
	fx0 = #w.Fx
	cards.Picked:Fire(p, "FlowerPatch", "Good", {})
	check(#glowsOf(w, p, fx0) == 0, "From.Card = false: a card does not glow", "")
	w.Config.Afterglow.From.Card = true
	-- a player who left gets nothing
	w:Remove(q)
	fx0 = #w.Fx
	cards.Picked:Fire(q, "FlowerPatch", "Good", {})
	check(#glowsOf(w, q, fx0) == 0, "a player who left: no afterglow", "")
end)

runGroup("a23-64 town pick", function()
	local w = townWorld({ Npcs = false })
	local function joinAt(id, faction, level, subs, done)
		return w:Join(id, { Faction = faction, Class = "Warrior", Level = level, Data = { Story = { Main = { Id = "" },
			Subs = subs, Done = done, Pick = {}, First = { Migrated = true } } } })
	end
	local base = { M1_1 = true, M1_2 = true, M1_3 = true, M1_4 = true, Lunch1 = true }
	-- a Halo player at H2's card (the lantern is back): the pick sets TownPick and the save
	local p, d = joinAt(6411, "Halo", 9, { H2 = { St = 4, P = 0, T = {}, Claim = false } }, table.clone(base)) -- step 4: the pick (#36 way home is 3)
	check(p:GetAttribute("TownPick") == "", "no town pick yet: TownPick = ''", tostring(p:GetAttribute("TownPick")))
	w:Act(p, "H2", "Choose", "Good")
	check(d.Story.Pick.H2 == "Good" and d.Story.TownLast == "H2" and p:GetAttribute("TownPick") == "H2:Good",
		"the lantern back: TownPick 'H2:Good', saved as Story.TownLast", show({ d.Story.TownLast, p:GetAttribute("TownPick") }))
	-- a pick that is not a town pick (XR1: Tiny at the Crossroads) leaves it as it is
	d.Story.Subs.XR1 = { St = 3, P = 0, T = {}, Claim = false }
	w:Act(p, "XR1", "Choose", "Evil")
	check(d.Story.Pick.XR1 == "Evil" and p:GetAttribute("TownPick") == "H2:Good" and d.Story.TownLast == "H2",
		"a Crossroads pick (XR1) does not change TownPick", show({ d.Story.Pick.XR1, p:GetAttribute("TownPick") }))
	-- S6 (both towns, the guide's card) later: the newest town pick wins
	d.Story.Subs.S6 = { St = 3, P = 0, T = {}, Claim = false }
	w:Act(p, "S6", "Choose", "Evil")
	check(p:GetAttribute("TownPick") == "S6:Evil" and d.Story.TownLast == "S6", "S6 later: TownPick 'S6:Evil' (the newest)",
		tostring(p:GetAttribute("TownPick")))
	-- a Horns R5; an artisan's GW8 A (its side, never the letter)
	local h = joinAt(6412, "Horns", 9, { R5 = { St = 3, P = 0, T = {}, Claim = false } }, table.clone(base))
	w:Act(h, "R5", "Choose", "Evil")
	check(h:GetAttribute("TownPick") == "R5:Evil", "Horns R5 'Finders keepers!': 'R5:Evil'", tostring(h:GetAttribute("TownPick")))
	local done = table.clone(base)
	done.M2_7 = true
	local n, nd = joinAt(6413, "Neutral", 24, { GW8 = { St = 3, P = 0, T = {}, Claim = false } }, done)
	w:Act(n, "GW8", "Choose", "A")
	check(nd.Story.Pick.GW8 == "A" and n:GetAttribute("TownPick") == "GW8:Good", "an artisan's A: 'GW8:Good' (the side, not the letter)",
		show({ nd.Story.Pick.GW8, n:GetAttribute("TownPick") }))
	-- join: the saved TownLast, else (an old save) the last of TownReact.Order with a saved pick
	local function joinWith(id, faction, st)
		st.Main, st.Subs, st.Done, st.First = { Id = "" }, {}, {}, { Migrated = true }
		return w:Join(id, { Faction = faction, Level = 25, Data = { Story = st } })
	end
	local a, ad = joinWith(6414, "Halo", { Pick = { H2 = "Good", H5 = "Evil", XR1 = "Good" } })
	check(a:GetAttribute("TownPick") == "H5:Evil" and ad.Story.TownLast == "H5", "an old save: the last town pick in Order (H5 after H2)",
		show({ a:GetAttribute("TownPick"), ad.Story.TownLast }))
	local b = joinWith(6415, "Halo", { Pick = { H2 = "Good", H5 = "Evil" }, TownLast = "H2" })
	check(b:GetAttribute("TownPick") == "H2:Good", "a saved TownLast wins over the Order", tostring(b:GetAttribute("TownPick")))
	local c, cd = joinWith(6416, "Halo", { Pick = { H3 = "Evil" }, TownLast = "Nope" })
	check(c:GetAttribute("TownPick") == "H3:Evil" and cd.Story.TownLast == "H3", "an unknown TownLast is replaced",
		show({ c:GetAttribute("TownPick"), cd.Story.TownLast }))
	local e, ed = joinWith(6417, "Halo", { Pick = { H6 = "Good" }, TownLast = "H2" })
	check(e:GetAttribute("TownPick") == "H6:Good" and ed.Story.TownLast == "H6", "a TownLast without its pick is replaced",
		show({ e:GetAttribute("TownPick"), ed.Story.TownLast }))
	local z, zd = joinWith(6418, "Halo", { Pick = { XR1 = "Good", Lunch1 = "Bite" } })
	check(z:GetAttribute("TownPick") == "" and zd.Story.TownLast == nil, "no town pick at all: '' and nothing saved",
		show({ z:GetAttribute("TownPick"), zd.Story.TownLast }))
	local m = joinWith(6419, "Horns", { Pick = { M3_4 = "Evil", R3 = "Good" } })
	check(m:GetAttribute("TownPick") == "M3_4:Evil", "Order: M3_4 comes after R3", tostring(m:GetAttribute("TownPick")))
	-- review 10/10: a town pick belongs to the faction that made it (Story.TownFaction)
	check(d.Story.TownFaction == "Halo", "the pick saves the faction that made it", tostring(d.Story.TownFaction))
	local fc = w.Registry.FactionService.FactionChanged
	p:SetAttribute("Faction", "Horns")
	d.Faction = "Horns"
	fc:Fire(p, "Horns", "Halo", "Altar")
	check(p:GetAttribute("TownPick") == "", "switched to Horns at the Altar: the Halo S6 pick goes quiet (no other town's line)",
		tostring(p:GetAttribute("TownPick")))
	p:SetAttribute("Faction", "Halo")
	d.Faction = "Halo"
	fc:Fire(p, "Halo", "Horns", "Altar")
	check(p:GetAttribute("TownPick") == "S6:Evil", "back to Halo: it is voiced again", tostring(p:GetAttribute("TownPick")))
	-- an old save (no TownFaction) that is Horns now: only a pick a Horn can have (H5 is Halo-only)
	local q = joinWith(6420, "Horns", { Pick = { R3 = "Good", H5 = "Evil" } })
	check(q:GetAttribute("TownPick") == "R3:Good", "an old Horns save: its Horns pick, never the Halo-only H5",
		tostring(q:GetAttribute("TownPick")))
	local r = joinWith(6421, "Horns", { Pick = { H5 = "Evil" }, TownLast = "H5", TownFaction = "Halo" })
	check(r:GetAttribute("TownPick") == "", "a Halo pick saved by a Halo save that is Horns now: quiet", tostring(r:GetAttribute("TownPick")))
end)

runGroup("a23-64 town react lines", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local R = C.TownReact
	local T = type(R) == "table" and R.Text or nil
	check(type(R) == "table" and R.Enabled == true and R.Every == 30 and R.Tag == "TownFolk" and type(T) == "table"
		and type(C.TownReactLines) == "function", "Config.TownReact: on, one line every 30 s a person, tag TownFolk, lines in Text",
		show(R and { R.Every, R.Tag }))
	-- the town people's bodies (Config.TownNpcs Folk entries, TownNpcs tags them TownFolk) stand in a town, so the client's
	-- Town fallback (Config.ZoneAt(the pivot position).Id) is a home zone id (Config.HomeZoneId)
	local homes = { [C.HomeZoneId("Halo")] = true, [C.HomeZoneId("Horns")] = true, [C.HomeZoneId("Neutral")] = true }
	local folk = 0
	for _, e in C.TownNpcs and C.TownNpcs.List or {} do
		if e.Folk then
			folk += 1
			local zone = C.ZoneAt(e.At)
			check(zone ~= nil and homes[zone.Id] == true, "town person " .. tostring(e.Folk) .. " stands in a town zone",
				zone and zone.Id)
		end
	end
	check(folk >= 1, "Config.TownNpcs has town people (Folk) to speak", folk)
	-- every line: short easy English for kids (12 words at most), no format tokens, nothing scary; Bright and Smokey are
	-- she / her (A23-59)
	local BAD = { kill = true, die = true, dead = true, blood = true, hate = true, stupid = true, scary = true }
	local HE = { he = true, him = true, his = true }
	local all = {}
	for f, rows in T.Rank do
		for i, row in rows do
			check(type(row) == "table" and #row >= 1, "Rank." .. f .. "[" .. i .. "] has lines", show(row))
			for _, line in row do table.insert(all, line) end
		end
	end
	check(#T.Rank.Halo == #C.Titles.Halo and #T.Rank.Horns == #C.Titles.Horns, "one Rank row per faction rank (5 each)",
		show({ #T.Rank.Halo, #T.Rank.Horns }))
	for id in C.MyWay.Names do
		check(type(T.Lean[id]) == "table" and #T.Lean[id] >= 1, "a lean line for My Way " .. id, show(T.Lean[id]))
		for _, line in T.Lean[id] or {} do table.insert(all, line) end
	end
	local inOrder = {}
	for _, id in R.Order do inOrder[id] = true end
	for _, id in R.Order do
		local def = C.StoryQuests.Defs[id]
		local choice = false
		for _, step in def and def.Steps or {} do
			if type(step.Obj) == "table" and step.Obj.Type == "Choice" then choice = true end
		end
		check(choice, id .. ": a story quest with a pick", id)
		check(type(T.Good[id]) == "string" and type(T.Evil[id]) == "string", id .. ": a Good and an Evil line",
			show({ T.Good[id], T.Evil[id] }))
	end
	for _, side in { "Good", "Evil" } do
		for id, line in T[side] do
			check(inOrder[id] == true, side .. "." .. tostring(id) .. ": in TownReact.Order (no orphan line)", id)
			table.insert(all, line)
		end
	end
	for f, bySide in T.FactionPick or {} do
		for side, lines in bySide do
			for id, line in lines do
				local def = C.StoryQuests.Defs[id]
				check(inOrder[id] == true and (side == "Good" or side == "Evil") and type(def) == "table"
					and (def.Factions == nil or (type(def.Factions) == "table" and def.Factions[f] == true)),
					"FactionPick." .. tostring(f) .. "." .. tostring(side) .. "." .. tostring(id) .. ": a town pick of that faction",
					show(def and def.Factions))
				table.insert(all, line)
			end
		end
	end
	-- zone_check_halo #56: the nine Halo-town picks and their Horns twins
	for _, id in { "H1", "H2", "H3", "H5", "H6", "OathH", "S6", "M3_4", "GW8", "R1", "R3", "R5", "R6", "R7", "OathR" } do
		check(inOrder[id] == true, id .. " is a town pick (in TownReact.Order)", id)
	end
	for _, line in all do
		local words, bad, he = 0, nil, nil
		for _ in string.gmatch(line, "%S+") do words += 1 end
		for word in string.gmatch(string.lower(line), "%a+") do
			if BAD[word] then bad = word end
			if HE[word] then he = word end
		end
		check(words >= 1 and words <= 12 and not string.find(line, "%", 1, true) and bad == nil,
			"every line: 1-12 words, no format token, nothing scary", line)
		if string.find(line, "Bright", 1, true) or string.find(line, "Smokey", 1, true) then
			check(he == nil, "a line naming Bright or Smokey never says he / him / his (both are she)", line)
		end
	end
	-- Config.TownReactLines (Town = the town person's Config.Zones id)
	local function has(list, text)
		for _, t in list do
			if t == text then return true end
		end
		return false
	end
	local l1, k1 = C.TownReactLines({ Faction = "Halo", Honor = 0, Infamy = 0, MyWay = "", TownPick = "", Town = "HaloTown" })
	check(#l1 == #T.Rank.Halo[1] and has(l1, T.Rank.Halo[1][1]) and has(l1, T.Rank.Halo[1][2]) and k1 == nil,
		"a new Halo in Halo Citadel: the 2 Squire lines only", show(l1))
	local l3 = C.TownReactLines({ Faction = "Halo", Honor = 60, Infamy = 999, MyWay = "", TownPick = "", Town = "Crossroads" })
	check(#l3 == #T.Rank.Halo[3] and has(l3, T.Rank.Halo[3][1]) and not has(l3, T.Rank.Halo[1][1]) and not has(l3, T.Rank.Horns[5][1]),
		"Honor 60 = rank 3 (Paladin) lines only; Infamy never counts for a Halo", show(l3))
	local l5 = C.TownReactLines({ Faction = "Horns", Honor = 0, Infamy = 1000, MyWay = C.MyWay.Names.SoftDevil, TownPick = "",
		Town = "HornsTown" })
	check(#l5 == #T.Rank.Horns[5] + #T.Lean.SoftDevil and has(l5, T.Rank.Horns[5][1]) and has(l5, T.Lean.SoftDevil[1])
		and not has(l5, T.Lean.TrueKnight[1]), "Infamy 1000 = the Demon King lines + the Soft-Hearted Devil lean", show(l5))
	local lp, kp = C.TownReactLines({ Faction = "Halo", Honor = 12, MyWay = "", TownPick = "H2:Good", Town = "HaloTown" })
	check(kp == T.Good.H2 and has(lp, kp) and has(lp, T.Rank.Halo[2][1]),
		"'H2:Good' in Halo Citadel: 'You brought the lantern back!' + the Knight lines", show({ kp, lp }))
	local _, kx = C.TownReactLines({ Faction = "Halo", Honor = 12, TownPick = "H2:Good", Town = "Crossroads" })
	check(kx == nil, "the town pick is said only in the player's own town (not at the Crossroads)", tostring(kx))
	local _, ks = C.TownReactLines({ Faction = "Horns", Infamy = 0, TownPick = "H2:Good", Town = "HornsTown" })
	check(ks == nil, "a past Halo pick is never said in Horns Den (H2 Factions = Halo, after a switch)", tostring(ks))
	local _, k6 = C.TownReactLines({ Faction = "Horns", Infamy = 0, TownPick = "S6:Evil", Town = "HornsTown" })
	check(k6 == T.FactionPick.Horns.Evil.S6 and k6 ~= T.Evil.S6, "S6 in Horns Den: the Horns line", tostring(k6))
	local _, n34 = C.TownReactLines({ Faction = "Neutral", Honor = 0, Infamy = 0, TownPick = "M3_4:Evil", Town = "Crossroads" })
	check(n34 == T.FactionPick.Neutral.Evil.M3_4 and n34 ~= T.Evil.M3_4, "an artisan's M3_4 B (sell the dust back): its own line",
		tostring(n34))
	local _, k7 = C.TownReactLines({ Faction = "Halo", Honor = 0, TownPick = "S6:Good", Town = "HaloTown" })
	check(k7 == T.Good.S6, "S6 in Halo Citadel: the Halo line", tostring(k7))
	local _, km = C.TownReactLines({ Faction = "Horns", Infamy = 0, TownPick = "M3_4:Good", Town = "HornsTown" })
	check(km == T.Good.M3_4, "a quest of both towns (M3_4) in Horns Den", tostring(km))
	-- the artisan guild's own town is the Crossroads (Config.HomeZoneId("Neutral"))
	local _, kn = C.TownReactLines({ Faction = "Neutral", TownPick = "GW8:Good", Town = "Crossroads" })
	check(kn == T.Good.GW8, "a Neutral 'GW8:Good' is said at the Crossroads (the guild's town)", tostring(kn))
	local _, kn2 = C.TownReactLines({ Faction = "Neutral", TownPick = "GW8:Good", Town = "HaloTown" })
	check(kn2 == nil, "a Neutral pick is not said in Halo Citadel", tostring(kn2))
	local _, kh = C.TownReactLines({ Faction = "Halo", Honor = 0, TownPick = "GW8:Evil", Town = "Crossroads" })
	check(kh == nil, "a Halo pick is not said at the Crossroads", tostring(kh))
	for _, bad in { "H2", "H2:Maybe", "Nope:Good", "H2:Good:x", "", 5, "XR1:Good" } do
		local _, kb = C.TownReactLines({ Faction = "Halo", Honor = 0, TownPick = bad, Town = "HaloTown" })
		check(kb == nil, "a bad TownPick says nothing: " .. tostring(bad), tostring(kb))
	end
	local ln = C.TownReactLines({ Faction = "None", Honor = 999, MyWay = C.MyWay.Names.TrueKnight, TownPick = "H2:Good", Town = "HaloTown" })
	check(#ln == 0, "no faction yet: quiet", show(ln))
	local lg, kg = C.TownReactLines({ Faction = "Neutral", TownPick = "", Town = "Crossroads" })
	check(#lg == #T.Rank.Neutral[1] and has(lg, T.Rank.Neutral[1][1]) and kg == nil, "the artisan guild has its own 2 lines",
		show(lg))
	R.Enabled = false
	check(#C.TownReactLines({ Faction = "Halo", Honor = 0, Town = "HaloTown" }) == 0, "Enabled = false: quiet", "")
end)

finish()
