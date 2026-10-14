-- board_offline.luau : E11 hunting-field job boards (BoardService; quest_volume §3-3 / §4, 검수 OK 2026-10-07).
-- tools/test_board.py binds the dev2_combat_world sources (the real StoryQuestService judges the jobs through
-- StoryQuestService.EventAmount, the real LootService pays the 5th-job scroll) + BOARD_SOURCE; this file follows the
-- world. BoardService's 1 s loop (J10 stays) is stepped by hand: its task.wait yields the loop coroutine.

local B0 = C0.Board
local L0 = C0.StoryQuests.Landmarks

local function boardWorld(o)
	o = o or {}
	local w = bareWorld({})
	local reg = w.Registry
	w.XP, w.Dirty = {}, 0
	reg.ProgressionService.AddXP = function(p, n) table.insert(w.XP, { P = p, N = n }) end
	reg.QuestService = { MarkDirty = function() w.Dirty += 1 end }
	w.Config.Board.Enabled = o.Off ~= true
	local env = w:Env()
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	local n0 = #w.Spawned
	local board = execute("BoardService", BOARD_SOURCE, env)
	reg.BoardService = board
	local deeds = execute("Deeds", DEEDS_SOURCE, env) -- A23-86: the daily deeds ledger (Init only: no loop)
	reg.Deeds = deeds
	deeds.Init(reg)
	board.Init(reg)
	board.Start()
	assert(#w.Spawned == n0 + 1, "BoardService.Start spawns one loop")
	local loop = coroutine.create(w.Spawned[#w.Spawned][1])
	w.Spawned = {}
	assert(coroutine.resume(loop))
	w.Board = board
	function w:BoardTick(seconds, step)
		for _ = 1, seconds or 1 do
			self:Advance(step or 1)
			local ok, err = coroutine.resume(loop)
			assert(ok, err)
		end
	end
	function w:Act(p, ...)
		self:Advance(1) -- RateLimits.BoardAction
		self.Net.Get("BoardAction").OnServerEvent:Fire(p, ...)
		self:Flush()
	end
	function w:MoveTo(p, pos) p.Character:FindFirstChild("HumanoidRootPart").Position = pos end
	function w:LastBoard(p)
		for i = #self.Fired, 1, -1 do
			local f = self.Fired[i]
			if f.Remote == "Board" and f.Player == p then return f.Payload, i end
		end
		return nil, 0
	end
	function w:KillAt(p, kind, pos, extra)
		local info = { Kind = kind, ZoneId = "SlimeMeadow", Golden = false, Personal = false, Position = pos or vec(0, 0, 0), WarPoints = 0 }
		for k, v in extra or {} do info[k] = v end
		reg.MonsterService.MonsterKilled:Fire(p, info)
		self:Flush()
	end
	function w:Gold(p, n, source) reg.ProgressionService.GoldEarned:Fire(p, n, source or "Monster"); self:Flush() end
	function w:Skill(p, hit, auto) reg.CombatService.Released:Fire(p, { Auto = auto == true, MonstersHit = hit }); self:Flush() end
	return w
end

local function cardIds(payload)
	local out = {}
	for _, c in payload and payload.Cards or {} do table.insert(out, c.Id) end
	return out
end
local function said(w, p, from, text)
	for _, t in w:NoticesFor(p, from) do if t == text then return true end end
	return false
end
-- a player at the meadow board; the board's cards set by hand (BoardService keeps valid saved cards)
local function atBoard(w, userId, cards, o)
	o = o or {}
	local spot = L0[B0.Boards[o.Board or "Meadow"].Spot]
	local p, d = w:Join(userId, { Faction = o.Faction or "Halo", Level = o.Level or 6, Pos = vec(spot.X + 3, 0, spot.Z),
		Attrs = o.Attrs, Data = { Board = { Cards = { [o.Board or "Meadow"] = cards }, Day = C0.DayIndex(math.floor(w.Time)) } } })
	return p, d
end

------------------------------------------------------------------ 1. data
runGroup("config", function()
	check(type(B0) == "table" and B0.Enabled == false, "Config.Board.Enabled = false until game dev 1's board window ships",
		show(B0 and B0.Enabled))
	check(B0.Cards == 4 and B0.Hold == 3 and B0.RerollCooldown == 60 and B0.FullPerDay == 10 and B0.AfterMult == 0.5
		and B0.BonusAt == 5 and B0.BonusItem == "Enh30", "4 cards, carry 3, 60 s swap, 10 full a day then half, the 5th +30% scroll",
		show({ B0.Cards, B0.Hold, B0.FullPerDay, B0.BonusAt, B0.BonusItem }))
	check(#B0.Jobs == 10, "J1..J10", #B0.Jobs)
	local g1, x1 = C0.HuntValue(B0.Boards.Meadow.Level, 1)
	local g10, x10 = C0.HuntValue(B0.Boards.Woods.Level, 1)
	check(g1 == 36 and x1 == 60 and g10 == 192 and x10 == 336, "rewards: meadow 36 + 60, woods 192 + 336", show({ g1, x1, g10, x10 }))
	local mz, wz = C0.ZoneAt(L0.MeadowBoard), C0.ZoneAt(L0.WoodsBoard)
	check(mz.PvP == false and wz.PvP == false, "both boards stand outside PvP zones", show({ mz.Id, wz.Id }))
	check(L0.MeadowArrival == C0.Zones.SlimeMeadow.Spawn and L0.WoodsArrival == C0.Zones.GoblinWoods.Spawn,
		"the arrival spots follow the zones' Spawn")
	check(math.abs(L0.MeadowBoard.X - L0.MeadowArrival.X) + math.abs(L0.MeadowBoard.Z - L0.MeadowArrival.Z) <= 12,
		"the meadow board stands beside the meadow arrival", show(L0.MeadowBoard))
	for _, job in B0.Jobs do
		check(type(job.Goal) == "string" and type(job.Kind) ~= "nil" and type(job.Sneaky) ~= "nil", job.Id .. ": goal + two buttons")
	end
	check(B0.Boards.Woods.SafeIds.J6 and B0.Boards.Woods.SafeIds.J10, "the woods board always keeps J6 or J10 (outside PvP)")
end)

------------------------------------------------------------------ 2. off: nothing happens
runGroup("switch off", function()
	local w = boardWorld({ Off = true })
	local p, d = atBoard(w, 101, { "J3", "J6", "J1", "J4" })
	w:Act(p, "Meadow", "Open")
	w:Act(p, "Meadow", "Take", 1, "Kind")
	check(w:LastBoard(p) == nil and #((d.Board or {}).Held or {}) == 0, "off: no board answer, nothing taken", show(d.Board and d.Board.Held))
	check(#w.Board.JobRows(p, d) == 0, "off: no job rows")
end)

------------------------------------------------------------------ 3. cards
runGroup("cards", function()
	local w = boardWorld()
	local p, d = atBoard(w, 201, nil)
	w:Act(p, "Meadow", "Open")
	local pay = w:LastBoard(p)
	local ids = cardIds(pay)
	local unique = {}
	for _, id in ids do unique[id] = true end
	local n = 0
	for _ in unique do n += 1 end
	check(pay and #ids == 4 and n == 4, "four different cards", show(ids))
	for _, c in pay and pay.Cards or {} do
		check(type(c.Kind) == "string" and type(c.Sneaky) == "string" and not string.find(c.Goal, "{", 1, true)
			and c.RewardGold == 36 and c.RewardXP == 60, "card " .. c.Id .. ": two buttons, a goal, 36 gold + 60 XP", show(c))
		check(c.Id ~= "J7", "no Auto Battle job before Auto Battle is unlocked", c.Id)
	end
	check(pay and pay.Held == 0 and pay.Hold == 3 and pay.Kind == 0 and pay.Sneaky == 0, "the board shows carried / Kind / Sneaky counts",
		show(pay))
	-- Auto Battle unlocked: J7 can show up
	local sawAuto = false
	for i = 1, 30 do
		local q = atBoard(w, 300 + i, nil, { Attrs = { AutoCombatUnlocked = true } })
		w:Act(q, "Meadow", "Open")
		for _, id in cardIds(w:LastBoard(q)) do if id == "J7" then sawAuto = true end end
	end
	check(sawAuto, "after Auto Battle is unlocked, J7 shows up")
	-- the woods board always keeps a card done outside the PvP woods (J6 / J10)
	local always = true
	for i = 1, 30 do
		local q = atBoard(w, 400 + i, nil, { Board = "Woods", Level = 12 })
		w:Act(q, "Woods", "Open")
		local safe = false
		for _, id in cardIds(w:LastBoard(q)) do if id == "J6" or id == "J10" then safe = true end end
		if not safe then always = false end
		for _ = 1, 3 do
			w:Advance(61)
			w:Act(q, "Woods", "Reroll", 4)
			local s2 = false
			for _, id in cardIds(w:LastBoard(q)) do if id == "J6" or id == "J10" then s2 = true end end
			if not s2 then always = false end
		end
	end
	check(always, "every woods board view has J6 or J10")
	local q = atBoard(w, 498, { "J3", "J6", "J1", "J4" }, { Board = "Woods", Level = 12 })
	w:Act(q, "Woods", "Open")
	local wp = w:LastBoard(q)
	check(wp and wp.Cards[1].RewardGold == 192 and wp.Cards[1].Target == 1 and wp.Cards[2].Target == 150,
		"woods values: 192 gold, Goblin Brute x1, hunting gold 150", show(wp and wp.Cards[1]))
end)

-- A23-71 S11 (T5): the first skill comes at Lv5, so 'Hit 3 at once' (J4, NeedSkill) waits for it
runGroup("a23-71 skill card", function()
	local w = boardWorld()
	local saw = false
	for i = 1, 30 do
		local q = atBoard(w, 1000 + i, nil, { Level = 4 })
		w:Act(q, "Meadow", "Open")
		for _, id in cardIds(w:LastBoard(q)) do if id == "J4" then saw = true end end
		for _ = 1, 3 do
			w:Advance(61)
			w:Act(q, "Meadow", "Reroll", 1)
			for _, id in cardIds(w:LastBoard(q)) do if id == "J4" then saw = true end end
		end
	end
	check(not saw, "Lv4 (no skill yet): the meadow board never shows 'Hit 3 at once' (J4)")
	-- a J4 card saved before the rule is swapped for another job; the other three stay where they were
	local p = atBoard(w, 1100, { "J3", "J6", "J1", "J4" }, { Level = 4 })
	w:Act(p, "Meadow", "Open")
	local ids = cardIds(w:LastBoard(p))
	check(#ids == 4 and ids[1] == "J3" and ids[2] == "J6" and ids[3] == "J1" and table.find(ids, "J4") == nil,
		"a saved J4 card before the first skill is swapped (the other three stay)", show(ids))
	-- a Lv4 who kept Q (saved slots 1 after a free class change took the level back) keeps it
	local k = atBoard(w, 1101, { "J3", "J6", "J1", "J4" }, { Level = 4, Attrs = { SkillSlots = 1 } })
	w:Act(k, "Meadow", "Open")
	local kept = cardIds(w:LastBoard(k))
	check(kept[4] == "J4", "a Lv4 who kept Q keeps the J4 card", show(kept))
	-- Lv5 learns Q: J4 can show up again
	local sawAt5 = false
	for i = 1, 40 do
		local q = atBoard(w, 1200 + i, nil, { Level = 5 })
		w:Act(q, "Meadow", "Open")
		for _, id in cardIds(w:LastBoard(q)) do if id == "J4" then sawAt5 = true end end
	end
	check(sawAt5, "Lv5: J4 shows up again")
end)

------------------------------------------------------------------ 4. take, progress, pay
runGroup("take and finish", function()
	local w = boardWorld()
	local p, d = atBoard(w, 501, { "J3", "J6", "J1", "J4" })
	w:Act(p, "Meadow", "Take", 1, "Kind") -- J3: Slime Prince x2
	local st = d.Board
	check(#st.Held == 1 and st.Held[1].Id == "J3" and st.Held[1].Side == "Kind" and st.Held[1].Target == 2,
		"took J3 on the Kind side (2 Slime Princes)", show(st.Held))
	local after = cardIds(w:LastBoard(p))
	check(after[1] ~= "J3" and after[2] == "J6" and after[3] == "J1" and after[4] == "J4", "the taken card's slot gets a new card",
		show(after))
	local rows = w.Board.JobRows(p, d)
	check(#rows == 1 and rows[1].Kind == "Job" and rows[1].Text == "Slime Prince 0/2" and rows[1].CanClaim == false and rows[1].Job.Side == "Kind",
		"the quest list row: 'Slime Prince 0/2' (A23-84), Kind Job, no [Claim]", show(rows[1]))
	local j3short = nil
	for _, j in B0.Jobs do if j.Id == "J3" then j3short = j.ShortName end end
	check(type(j3short) == "string" and #j3short <= 14 and rows[1].ShortName == j3short,
		"the job row carries the job's ShortName (검수 2026-10-07: the phone quest row)", show({ rows[1].ShortName, j3short }))
	local bank, honor, infamy, n0 = d.BankGold or 0, d.Honor or 0, d.Infamy or 0, #w.Notices
	w:KillAt(p, "Slime")
	check(st.Held[1].P == 0, "a slime is not a Slime Prince", st.Held[1].P)
	w:KillAt(p, "BigSlime")
	w:KillAt(p, "BigSlime")
	check(#st.Held == 0 and (d.BankGold or 0) == bank + 36 and #w.XP >= 1 and w.XP[#w.XP].N == 60,
		"2 Slime Princes: paid at once (36 gold + 60 XP), the job leaves", show({ st.Held, (d.BankGold or 0) - bank }))
	-- A23-130: no lean line any more ('Your shard leaned to the light.'), the score line says it
	check(said(w, p, n0, string.format(B0.Text.Done, "36", "60")) and not said(w, p, n0, B0.Text.LeanKind),
		"lines: 'Job done! +36 gold · +60 XP', no lean line", show(w:NoticesFor(p, n0)))
	check(d.Story.N.Kind == 1 and (d.Honor or 0) == honor + 1 and (d.Infamy or 0) == infamy and st.Done == 1,
		"the side is counted (Kind 1); A23-86: a Halo's Kind job is one deed, Honor +1 (own side), no Infamy", show({ d.Story.N, d.Honor, d.Infamy }))
	check(said(w, p, n0, "Honor +1") and d.Deeds.N == 1, "the score line 'Honor +1' and one point on the ledger", show({ d.Deeds, w:NoticesFor(p, n0) }))
	w:KillAt(p, "BigSlime")
	check((d.BankGold or 0) == bank + 36, "a finished job never pays twice", (d.BankGold or 0) - bank)
	-- gold, a skill, kills near the arrival
	w:Act(p, "Meadow", "Take", 2, "Sneaky") -- J6: hunting gold 40
	w:Act(p, "Meadow", "Take", 3, "Kind") -- J1: slimes near the meadow arrival x5
	w:Act(p, "Meadow", "Take", 4, "Sneaky") -- J4: 3 at once x2
	check(#st.Held == 3, "carrying 3 jobs", #st.Held)
	local n1 = #w.Notices
	w:Act(p, "Meadow", "Take", 1, "Kind")
	check(#st.Held == 3 and said(w, p, n1, B0.Text.Full), "a 4th job is refused: 'You carry 3 jobs.'", show(w:NoticesFor(p, n1)))
	w:Gold(p, 25, "Sale")
	w:Gold(p, 25, "Monster")
	check(st.Held[1].P == 25, "sale gold does not count, hunting gold does", st.Held[1].P)
	local n2 = #w.Notices
	w:Gold(p, 15, "Monster")
	check(d.Story.N.Sneaky == 1 and #st.Held == 2, "40 hunting gold: done (Sneaky 1)", show(d.Story.N))
	check(not said(w, p, n2, B0.Text.LeanSneaky) and not said(w, p, n2, B0.Text.LeanKind), "a Sneaky job: no lean line (A23-130)",
		show(w:NoticesFor(p, n2)))
	check((d.Honor or 0) == honor and d.Deeds.N == 1 and said(w, p, n2, "Honor -1"),
		"A23-86: a Halo's Sneaky job costs Honor 1 (A23-58), the loss line 'Honor -1' says so, and a loss does not use the ledger", show({ d.Honor, honor, d.Deeds, w:NoticesFor(p, n2) }))
	local arrival = L0.MeadowArrival
	w:KillAt(p, "Slime", vec(arrival.X + 80, 0, arrival.Z))
	check(st.Held[1].P == 0, "a slime far from the arrival does not count", st.Held[1].P)
	for _ = 1, 5 do w:KillAt(p, "Slime", vec(arrival.X + 10, 0, arrival.Z)) end
	check(#st.Held == 1 and st.Held[1].Id == "J4", "5 slimes by the arrival: J1 done", show(st.Held))
	w:Skill(p, 2)
	w:Skill(p, 4, true)
	check(st.Held[1].P == 0, "a 2-hit skill or an auto skill does not count", st.Held[1].P)
	w:Skill(p, 3)
	w:Skill(p, 5)
	check(#st.Held == 0 and st.Done == 4, "two manual skills hitting 3+: done (4 jobs today)", show({ #st.Held, st.Done }))
end)

------------------------------------------------------------------ 5. the day's caps and the 5th-job scroll
runGroup("day caps", function()
	local w = boardWorld()
	local p, d = atBoard(w, 601, { "J6", "J3", "J1", "J4" })
	local st = d.Board
	st.Done = 4
	-- 최종 검수 10/14: a full bag (every slot used, Enh30 not held) still gets the reward
	do
		local mats = {}
		for k, def in C0.Loot.Items do if def.Kind == "Material" and k ~= "Enh30" then table.insert(mats, k) end end
		table.sort(mats)
		d.Items = d.Items or {}
		d.Items.Enh30 = nil
		for _, k in mats do if C0.BagHasRoom(d) then d.Items[k] = 1 end end
		check(not C0.BagHasRoom(d), "(the bag is full before the reward)", C0.BagUsed(d))
	end
	local enh0, n0 = d.Items and d.Items.Enh30 or 0, #w.Notices
	w:Act(p, "Meadow", "Take", 1, "Kind")
	w:Gold(p, 40, "Monster")
	check(st.Done == 5 and st.Bonus == true and (d.Items.Enh30 or 0) == enh0 + 1
		and said(w, p, n0, string.format(B0.Text.Bonus, C0.Loot.Items.Enh30.Name)), "the 5th job of the day: one 30% scroll",
		show({ st.Done, d.Items and d.Items.Enh30, w:NoticesFor(p, n0) }))
	st.Done = 9
	local bank = d.BankGold or 0
	st.Cards.Meadow = { "J6", "J3", "J1", "J4" }
	w:Act(p, "Meadow", "Take", 1, "Kind")
	w:Gold(p, 40, "Monster")
	check((d.BankGold or 0) - bank == 36 and st.Done == 10, "the 10th job still pays in full (36)", (d.BankGold or 0) - bank)
	bank = d.BankGold or 0
	st.Cards.Meadow = { "J6", "J3", "J1", "J4" }
	w:Act(p, "Meadow", "Take", 1, "Kind")
	w:Gold(p, 40, "Monster")
	check((d.BankGold or 0) - bank == 18 and st.Done == 11, "the 11th pays half (18)", (d.BankGold or 0) - bank)
	check((d.Items.Enh30 or 0) == enh0 + 1, "the scroll came once today")
	-- a new KST day: the count and the scroll start again (held jobs stay)
	w:Advance(86400)
	st.Done = 4
	st.Day = C0.DayIndex(math.floor(w.Time)) - 1
	w:Act(p, "Meadow", "Take", 1, "Kind")
	check(st.Done == 0 and st.Bonus == false, "a new day: Done 0, the scroll can come again", show({ st.Done, st.Bonus }))
	for i = 1, 4 do
		st.Held = { { Id = "J6", Board = "Meadow", Side = "Kind", Target = 1, P = 0 } }
		w:Gold(p, 1, "Monster")
	end
	st.Held = { { Id = "J6", Board = "Meadow", Side = "Kind", Target = 1, P = 0 } }
	w:Gold(p, 1, "Monster")
	check(st.Done == 5 and (d.Items.Enh30 or 0) == enh0 + 2, "the next day's 5th job: the scroll again", show({ st.Done, d.Items.Enh30 }))
end)

------------------------------------------------------------------ 6. range, bad calls, swaps
runGroup("remote checks", function()
	local w = boardWorld()
	local p, d = atBoard(w, 701, { "J6", "J3", "J1", "J4" })
	local st = d.Board
	w:MoveTo(p, vec(L0.MeadowBoard.X + 40, 0, L0.MeadowBoard.Z))
	w:Act(p, "Meadow", "Take", 1, "Kind")
	w:Act(p, "Meadow", "Open")
	check(#st.Held == 0 and w:LastBoard(p) == nil, "40 studs from the board: nothing", #st.Held)
	w:MoveTo(p, vec(L0.MeadowBoard.X + 2, 0, L0.MeadowBoard.Z))
	for _, args in { { "Meadow", "Take", 0, "Kind" }, { "Meadow", "Take", 5, "Kind" }, { "Meadow", "Take", 1.5, "Kind" },
		{ "Meadow", "Take", "1", "Kind" }, { "Meadow", "Take", 1, "Evil" }, { "Meadow", "Take", 1, "Kind", "extra" },
		{ "Nowhere", "Open" }, { 7, "Open" }, { "Meadow", "Explode", 1, "Kind" }, { "Woods", "Take", 1, "Kind" } } do
		w:Act(p, table.unpack(args))
	end
	check(#st.Held == 0, "bad slots / sides / boards / extra args / the woods board from the meadow: all ignored", show(st.Held))
	-- swaps: one per 60 s, never one of the last two templates
	w:Act(p, "Meadow", "Reroll", 2)
	local first = cardIds(w:LastBoard(p))
	check(first[2] ~= "J3", "a swap replaces the card", show(first))
	w:Act(p, "Meadow", "Reroll", 2)
	check(cardIds(w:LastBoard(p))[2] == first[2], "a second swap within 60 s is ignored", show(cardIds(w:LastBoard(p))))
	local fresh = true
	for _ = 1, 25 do
		w:Advance(61)
		local before = cardIds(w:LastBoard(p))[2]
		local last = (st.Recent.Meadow or {})[1] -- with the swapped one: the last two templates of this board
		w:Act(p, "Meadow", "Reroll", 2)
		local now = cardIds(w:LastBoard(p))[2]
		if now == before or (last ~= nil and now == last) then fresh = false end
	end
	check(fresh, "a new card is never the swapped one or one of the last two")
end)

------------------------------------------------------------------ 7. J10: stand guard (seconds in one go)
runGroup("stand guard", function()
	local w = boardWorld()
	local p, d = atBoard(w, 801, { "J10", "J3", "J1", "J4" }, { Board = "Woods", Level = 12 })
	w:Act(p, "Woods", "Take", 1, "Sneaky")
	local st = d.Board
	local gate = L0.WoodsGate
	check(st.Held[1] and st.Held[1].Id == "J10" and st.Held[1].Target == 15, "J10: 15 s at the gate", show(st.Held))
	w:MoveTo(p, vec(gate.X + 5, 0, gate.Z))
	w:BoardTick(8)
	check(st.Held[1].P >= 6, "the seconds count while standing there", st.Held[1].P)
	w:MoveTo(p, vec(gate.X + 60, 0, gate.Z))
	w:BoardTick(1)
	check(st.Held[1].P == 0, "stepping away resets the count", st.Held[1].P)
	w:MoveTo(p, vec(gate.X, 0, gate.Z + 3))
	w:BoardTick(1)
	w:BoardTick(1, 3)
	check(st.Held[1].P == 3, "a late loop still counts real seconds (time, not ticks)", st.Held[1].P)
	w:MoveTo(p, vec(gate.X + 60, 0, gate.Z))
	w:BoardTick(1)
	w:MoveTo(p, vec(gate.X, 0, gate.Z + 3))
	w:BoardTick(14)
	check(#st.Held == 1, "14 s is not enough", show(st.Held))
	w:BoardTick(2)
	check(#st.Held == 0 and d.Story.N.Sneaky == 1, "15 s in one go: done (Sneaky)", show({ st.Held, d.Story.N }))
end)

------------------------------------------------------------------ 8. the first-time hint row, old saves
runGroup("hint and saves", function()
	local w = boardWorld()
	local p, d = atBoard(w, 901, { "J6", "J3", "J1", "J4" })
	d.Story = d.Story or {}
	d.Story.Done = d.Story.Done or {}
	check(#w.Board.JobRows(p, d) == 0, "no hint before M1_4")
	d.Story.Done.M1_4 = true
	local rows = w.Board.JobRows(p, d)
	check(#rows == 1 and rows[1].Id == "job:board" and rows[1].Text == B0.Text.Hint and rows[1].Job.Guide == "MeadowBoard",
		"after M1_4: 'Job Board · tap for directions' guides to the meadow board", show(rows[1]))
	check(type(B0.Text.HintShort) == "string" and rows[1].ShortName == B0.Text.HintShort,
		"the hint row's ShortName is Text.HintShort ('Job Board')", rows[1].ShortName)
	w:Act(p, "Meadow", "Take", 1, "Kind")
	rows = w.Board.JobRows(p, d)
	check(#rows == 1 and rows[1].Id == "job:1", "after the first job the hint is gone", show(rows))
	w:Gold(p, 40, "Monster")
	rows = w.Board.JobRows(p, d)
	check(#d.Board.Held == 0 and #rows == 0, "the first job done: the hint does not come back", show(rows))
	-- a broken save is cleaned at load
	local q, e = w:Join(902, { Faction = "Horns", Level = 6, Data = { Board = { Held = {
		{ Id = "J99", Board = "Meadow", Side = "Kind", Target = 3 }, { Id = "J3", Board = "Mars", Side = "Kind", Target = 2 },
		{ Id = "J3", Board = "Meadow", Side = "Evil", Target = 2 }, { Id = "J6", Board = "Meadow", Side = "Kind", Target = -4, P = 99 },
		{ Id = "J1", Board = "Meadow", Side = "Sneaky", Target = 5 }, { Id = "J4", Board = "Meadow", Side = "Kind", Target = 2 },
		{ Id = "J5", Board = "Meadow", Side = "Kind", Target = 6 } }, Cards = { Mars = { "J1" } } } } })
	local held = e.Board.Held
	check(#held == 3 and held[1].Id == "J6" and held[1].Target == 1 and held[1].P == 1 and e.Board.Cards.Mars == nil,
		"a broken saved board: unknown jobs / boards / sides dropped, numbers fixed, at most 3 kept", show(held))
	local _ = q
end)

finish()
