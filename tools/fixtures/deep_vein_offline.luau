-- deep_vein_offline.luau : A23-215 장인 2부, the deep vein run (Shared/Quests/DeepVein.luau) on the real StoryQuestService and
-- LootService (tools/test_deep_vein.py binds the dev2_combat_world sources + DEEPVEIN_SOURCE). The engine parts it needs:
-- def.Run (routes take turns, outside the day's five, never Done), a Kill step's Spawn (one personal guard at a time near its
-- spot), def.ResetOnKO (going down = back to the first mark) and Reward.FreeItems (the shard is NOT bound).

local function pack(c)
	local p = execute("DeepVein", DEEPVEIN_SOURCE, nativeEnv())
	c.AddQuests(p, "DeepVein")
	return p
end
local PACK = pack(execute("Config", CONFIG_SOURCE, nativeEnv()))

-- a started story world with the pack; the 1 s loop is never run (Refresh by hand). w.Spawns = SpawnPersonal calls,
-- w.Removed = RemovePersonal calls; w.Feature[name] = false switches a Config.Features flag off
local function veinWorld(o)
	o = o or {}
	local w = bareWorld({ EditConfig = function(c)
		pack(c)
		c.Features.Crafting = true
		for k, v in o.Features or {} do c.Features[k] = v end
	end })
	local reg = w.Registry
	local Signal = w.Util.Signal
	reg.ZoneService.ZoneChanged = Signal.new()
	reg.ZoneService.GetZoneId = function() return "SkeletonRuins" end
	reg.GooseService.GooseFinished = Signal.new()
	-- (CombatService's own death pipeline also hears CharacterDied; its PvP / grudge parts are not this world's)
	w.AllowWarn = { "death pipeline" }
	reg.RankingService = setmetatable({}, { __index = function() return function() end end })
	local ws = w:Env().workspace
	ws.FindFirstChild = function() return nil end
	local rs = w.Services.ReplicatedStorage
	if not rs.FindFirstChild then rs.FindFirstChild = function() return nil end end
	reg.ProgressionService.AddXP = function() end
	-- story NPC bodies: Pip (his one body, the Daily pack's spot (700, 0, 30); an offer needs a body, nearBody the player close)
	w.Bodies = {}
	for _, npc in { { Id = "Pip", At = vec(700, 0, 30) } } do
		table.insert(w.Bodies, { __kind = "Instance", Attrs = { NpcId = npc.Id }, Position = npc.At,
			GetAttribute = function(self, k) return self.Attrs[k] end, IsDescendantOf = function() return true end,
			IsA = function(_, kind) return kind == "BasePart" end, GetPivot = function(self) return { Position = self.Position } end })
	end
	w.Services.CollectionService = { GetTagged = function(_, tag)
		if tag == w.Config.StoryQuests.NpcTag then return w.Bodies end
		return {}
	end }
	w.Spawns, w.Removed = {}, {}
	local ms = reg.MonsterService
	function ms.SpawnPersonal(p, kind, opts)
		local rec = { Kind = kind, Alive = true, Owner = p, Opts = opts }
		table.insert(w.Spawns, rec)
		return {}, rec
	end
	function ms.RemovePersonal(rec)
		table.insert(w.Removed, rec)
		if rec.Alive then rec.Alive = false return true end
		return false
	end
	w.Story.Start()
	w.Granted = {}
	local loot = reg.LootService
	local grant = loot.GrantItem
	loot.GrantItem = function(p, id, n, source)
		table.insert(w.Granted, { P = p, Id = id, N = n, Source = source })
		return grant(p, id, n, source)
	end
	function w:Act(p, id, action, option)
		self:Advance(1)
		self.Net.Get("StoryAction").OnServerEvent:Fire(p, id, action, option)
		self:Flush()
	end
	function w:Move(p, spot)
		local at = type(spot) == "string" and self.Config.StoryQuests.Landmarks[spot] or spot
		p.Character:FindFirstChild("HumanoidRootPart").Position = at
		self.Story.Refresh(p)
		self:Flush()
	end
	-- the living guard dies: MonsterService's kill report for a personal Skeleton Knight
	function w:KillGuard(p)
		local rec = self.Spawns[#self.Spawns]
		if rec then rec.Alive = false end
		reg.MonsterService.MonsterKilled:Fire(p, { Kind = "SkeletonKnight", ZoneId = "SkeletonRuins", Golden = false, Personal = true,
			Position = vec(0, 0, 0), WarPoints = 0 })
		self:Flush()
	end
	function w:Track(d, id) return d.Story and d.Story.Subs and d.Story.Subs[id] end
	return w
end

local FLINT = vec(705, 0, 30) -- next to Pip (700, 0, 30)

-- a ready Lv30 player past M1_4 standing by Pip
local function joinVein(w, userId, o)
	o = o or {}
	local story = { Main = { Id = "" }, Subs = o.Subs or {}, Done = { M1_1 = true, M1_2 = true, M1_3 = true, M1_4 = true }, Pick = {},
		First = { Migrated = true }, Runs = o.Runs }
	local data = { Story = story }
	for k, v in o.Data or {} do data[k] = v end
	local p, d = w:Join(userId, { Faction = o.Faction or "Halo", Class = "Warrior", Level = o.Level or 30, Data = data })
	p.Character:FindFirstChild("HumanoidRootPart").Position = FLINT
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end

local function offers(p) return p:GetAttribute("StoryOffers") or "" end

-- walk one route from its first mark to the shard
local function runRoute(w, p, d, id)
	local def = w.Config.StoryQuests.Defs[id]
	for i = 1, 3 do w:Move(p, def.Steps[i].Obj.Spot) end
	w:Move(p, def.Steps[4].Spawn.Spot)
	for _ = 1, 3 do
		w.Story.Refresh(p)
		w:KillGuard(p)
	end
	w:Move(p, def.Steps[5].Obj.Spot)
	w:Act(p, id, "Open")
	w:Advance(3)
	w:Act(p, id, "Timing", "3/5")
	w:Move(p, FLINT) -- back to Pip for the next run
end

------------------------------------------------------------------ 1. the pack
runGroup("config", function()
	local defs = {}
	for id in PACK.Defs do table.insert(defs, id) end
	table.sort(defs)
	check(table.concat(defs, ",") == "DV1,DV2,DV3" and table.concat(PACK.Subs, ",") == "DV1,DV2,DV3", "three routes DV1..DV3, offered in order", table.concat(defs, ","))
	for turn, id in { "DV1", "DV2", "DV3" } do
		local def = PACK.Defs[id]
		check(def.Kind == "Sub" and def.Run.Group == "Vein" and def.Run.Turn == turn and def.Run.Of == 3 and def.ResetOnKO == true
			and def.Repeat == nil and def.Offer.Npc == "Pip", id .. ": a run of group Vein (turn " .. turn .. " of 3), ResetOnKO, Pip offers it", show(def.Run))
		local req = def.Requires
		check(req.Level == 25 and req.Feature == "Crafting" and req.Done[1] == "M1_4", id .. ": Lv25, only while Crafting is on, after M1_4", show(req))
		local s = def.Steps
		check(#s == 5 and s[1].Obj.Type == "Near" and s[2].Obj.Type == "Near" and s[3].Obj.Type == "Near", id .. ": three marks (Near)", "")
		check(s[4].Obj.Type == "Kill" and s[4].Obj.Kind == "SkeletonKnight" and s[4].Obj.Personal == true and s[4].Obj.Count == 3
			and s[4].Spawn.Kind == "SkeletonKnight" and s[4].Spawn.Spot == s[4].Guide, id .. ": three personal Skeleton Knight guards, spawned at the guard spot", show(s[4]))
		check(s[5].Obj.Type == "Timing" and s[5].Obj.Spot ~= nil, id .. ": the vein = a Timing panel at its spot", show(s[5].Obj))
		check(#def.Reward.FreeItems == 1 and def.Reward.FreeItems[1].Id == "DeepMoonShard" and def.Reward.FreeItems[1].N == 1
			and def.Reward.Items == nil and def.Reward.Gold == nil, id .. ": one Deep Moon Shard, paid free (not bound), nothing else", show(def.Reward))
		for i, step in s do
			local spot = step.Obj.Spot or (step.Spawn and step.Spawn.Spot)
			local at = spot and PACK.Landmarks[spot]
			check(at ~= nil and at.X >= 1260 and at.X <= 1780 and at.Z >= -290 and at.Z <= 290, id .. " step " .. i .. ": its spot is inside the ruins", show(at))
			check(#step.ShortName <= 14, id .. " step " .. i .. ": a phone short name", step.ShortName)
		end
	end
	check(C0.Loot.Items.DeepMoonShard ~= nil and C0.Loot.Items.DeepMoonShard.Source == "Deep", "the shard item is defined (Source Deep)", "")
end)

------------------------------------------------------------------ 2. offers take turns
runGroup("turns", function()
	local w = veinWorld()
	local p, d = joinVein(w, 3001)
	check(offers(p) == "Pip", "Pip has a '!' (route DV1's turn)", offers(p))
	check(w.Story.TalkToNpc(p, "Pip") ~= nil, "talking to Pip offers a run", "")
	w:Act(p, "DV2", "Accept")
	check(w:Track(d, "DV2") == nil, "DV2 cannot be taken out of turn", show(d.Story.Subs))
	w:Act(p, "DV1", "Accept")
	check(w:Track(d, "DV1") ~= nil and w:Track(d, "DV1").St == 1, "DV1 accepted at Pip", show(d.Story.Subs))
	check(d.Story.Daily == nil or next(d.Story.Daily.Taken or {}) == nil, "a run never counts in the day's five", show(d.Story.Daily))
	runRoute(w, p, d, "DV1")
	check(w:Track(d, "DV1") == nil and d.Story.Done.DV1 == nil and d.Story.Runs.Vein == 1, "DV1 done: never marked Done, Runs.Vein = 1", show(d.Story.Runs))
	w.Story.Refresh(p)
	check(offers(p) == "Pip", "right after: Pip offers again (no wait)", offers(p))
	w:Act(p, "DV1", "Accept")
	check(w:Track(d, "DV1") == nil, "DV1 again is refused (DV2's turn)", show(d.Story.Subs))
	w:Act(p, "DV2", "Accept")
	check(w:Track(d, "DV2") ~= nil, "DV2 accepted", "")
	runRoute(w, p, d, "DV2")
	w:Act(p, "DV3", "Accept")
	runRoute(w, p, d, "DV3")
	check(d.Story.Runs.Vein == 3, "three runs done", show(d.Story.Runs))
	w:Act(p, "DV1", "Accept")
	check(w:Track(d, "DV1") ~= nil, "after DV3 the turn is DV1 again", show(d.Story.Subs))
	local shards = 0
	for _, g in w.Granted do if g.Id == "DeepMoonShard" and g.P == p then shards += g.N end end
	check(shards == 3 and (d.Items.DeepMoonShard or 0) == 3, "one shard per run (3)", show({ shards, d.Items.DeepMoonShard }))
	-- full day's five: a run is still offered
	local q, e = joinVein(w, 3002, { Data = { } })
	e.Story.Daily = { Day = w.Config.DayIndex(os.time()), Taken = { a = true, b = true, c = true, d = true, e = true }, Done = {} }
	w.Story.Refresh(q)
	check(string.find(offers(q), "Pip", 1, true) ~= nil, "the day's five taken: the vein is still offered", offers(q))
end)

------------------------------------------------------------------ 3. who gets it
runGroup("gates", function()
	local w = veinWorld()
	local p = joinVein(w, 3101, { Level = 24 })
	check(offers(p) == "", "Lv24: nothing", offers(p))
	local q = joinVein(w, 3102, { Level = 25, Faction = "Horns" })
	check(offers(q) == "Pip", "Lv25, Horns too", offers(q))
	local off = veinWorld({ Features = { Crafting = false } })
	local r = joinVein(off, 3103)
	check(offers(r) == "", "Crafting off: no run offered", offers(r))
	local x = joinVein(w, 3104, { Runs = { Vein = 4 } })
	check(offers(x) == "Pip", "Runs.Vein 4 = DV2's turn: offered", offers(x))
end)

------------------------------------------------------------------ 4. the run, step by step
runGroup("run", function()
	local w = veinWorld()
	local p, d = joinVein(w, 3201)
	w:Act(p, "DV1", "Accept")
	local def = w.Config.StoryQuests.Defs.DV1
	w:Move(p, def.Steps[2].Obj.Spot)
	check(w:Track(d, "DV1").St == 1, "the second mark first: nothing (marks in order)", show(w:Track(d, "DV1")))
	w:Move(p, def.Steps[1].Obj.Spot)
	check(w:Track(d, "DV1").St == 2, "mark 1 reached: step 2", show(w:Track(d, "DV1")))
	w:Move(p, def.Steps[2].Obj.Spot)
	w:Move(p, def.Steps[3].Obj.Spot)
	w.Story.Refresh(p) -- a tick on the guards' step, still at mark 3 (~95 studs from the guard spot)
	check(w:Track(d, "DV1").St == 4 and #w.Spawns == 0, "mark 3 reached: the guards' step; far from their spot no guard yet", show({ w:Track(d, "DV1"), #w.Spawns }))
	w:Move(p, def.Steps[4].Spawn.Spot)
	check(#w.Spawns == 1 and w.Spawns[1].Kind == "SkeletonKnight" and w.Spawns[1].Opts.Near == true, "at the guard spot: one personal Skeleton Knight (Near)", tostring(w.Spawns[1] and w.Spawns[1].Kind))
	w.Story.Refresh(p)
	check(#w.Spawns == 1, "while it lives: no second guard", #w.Spawns)
	w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = "SkeletonKnight", ZoneId = "SkeletonRuins", Personal = false, Position = vec(0, 0, 0), WarPoints = 0 })
	w:Flush()
	check(w:Track(d, "DV1").P == 0, "a shared Skeleton Knight never counts", show(w:Track(d, "DV1")))
	w:KillGuard(p)
	check(w:Track(d, "DV1").P == 1, "guard 1 down: 1/3", show(w:Track(d, "DV1")))
	w.Story.Refresh(p)
	check(#w.Spawns == 2, "the next guard comes on the next tick", #w.Spawns)
	w:KillGuard(p)
	w.Story.Refresh(p)
	w:KillGuard(p)
	check(w:Track(d, "DV1").St == 5 and #w.Spawns == 3, "three guards down: the vein step, no fourth guard", show({ w:Track(d, "DV1"), #w.Spawns }))
	w.Story.Refresh(p)
	check(#w.Spawns == 3, "still no fourth guard on the vein step", #w.Spawns)
	-- the vein: open far = nothing; at the spot a Timing panel; 2/5 fails (try again), 3/5 passes
	w:Act(p, "DV1", "Open")
	w:Advance(3)
	w:Act(p, "DV1", "Timing", "4/5")
	check(w:Track(d, "DV1").St == 5, "far from the vein: no panel, an answer does nothing", show(w:Track(d, "DV1")))
	w:Move(p, def.Steps[5].Obj.Spot)
	w:Act(p, "DV1", "Open")
	w:Advance(3)
	w:Act(p, "DV1", "Timing", "2/5")
	check(w:Track(d, "DV1") ~= nil and w:Track(d, "DV1").St == 5, "2 of 5: try again (the run stays at the vein)", show(w:Track(d, "DV1")))
	local before = #w.Granted
	w:Advance(3)
	w:Act(p, "DV1", "Timing", "3/5")
	check(w:Track(d, "DV1") == nil, "3 of 5: the run is done", show(d.Story.Subs))
	local g = w.Granted[#w.Granted]
	check(#w.Granted == before + 1 and g.Id == "DeepMoonShard" and g.N == 1 and g.Source == "RewardFree", "one Deep Moon Shard, source RewardFree", show({ g.Id, g.N, g.Source }))
	check((d.Items.DeepMoonShard or 0) == 1 and (type(d.ItemsBound) ~= "table" or (d.ItemsBound.DeepMoonShard or 0) == 0),
		"the shard is in the bag and NOT bound (tradeable)", show({ d.Items.DeepMoonShard, d.ItemsBound }))
end)

------------------------------------------------------------------ 5. going down = back to the first mark
runGroup("ko", function()
	local w = veinWorld()
	local p, d = joinVein(w, 3301)
	w:Act(p, "DV1", "Accept")
	local def = w.Config.StoryQuests.Defs.DV1
	for i = 1, 3 do w:Move(p, def.Steps[i].Obj.Spot) end
	w:Move(p, def.Steps[4].Spawn.Spot)
	w:KillGuard(p)
	w.Story.Refresh(p)
	check(w:Track(d, "DV1").St == 4 and w:Track(d, "DV1").P == 1 and #w.Spawns == 2, "at the guards, 1/3, the second guard up", show(w:Track(d, "DV1")))
	local alive = w.Spawns[2]
	w.PS.CharacterDied:Fire(p, p.Character)
	w:Flush()
	-- 최종 검수 10/16: going down starts the CURRENT step over (the marks passed stay)
	check(w:Track(d, "DV1") ~= nil and w:Track(d, "DV1").St == 4 and w:Track(d, "DV1").P == 0, "down: the guards' step again from 0/3 (marks kept)", show(w:Track(d, "DV1")))
	check(table.find(w.Removed, alive) ~= nil and alive.Alive == false, "the living guard goes away", #w.Removed)
	check((d.Items.DeepMoonShard or 0) == 0, "nothing paid, nothing lost", "")
	w.Story.Refresh(p)
	check(#w.Spawns == 3, "back at the guard spot: a new first guard", #w.Spawns)
	-- down at the vein with its Timing panel open: the panel closes, the step stays
	w:KillGuard(p); w.Story.Refresh(p); w:KillGuard(p); w.Story.Refresh(p); w:KillGuard(p)
	w:Move(p, def.Steps[5].Obj.Spot)
	w:Act(p, "DV1", "Open")
	w.PS.CharacterDied:Fire(p, p.Character)
	w:Flush()
	w:Advance(3)
	w:Act(p, "DV1", "Timing", "5/5")
	check(w:Track(d, "DV1") ~= nil and w:Track(d, "DV1").St == 5, "down at the vein: still the vein step, the open panel's answer no longer counts", show(w:Track(d, "DV1")))
	-- down on a mark step: still that mark (nothing to start over)
	local m, dm = joinVein(w, 3304)
	w:Act(m, "DV1", "Accept")
	w:Move(m, def.Steps[1].Obj.Spot)
	w.PS.CharacterDied:Fire(m, m.Character)
	w:Flush()
	check(w:Track(dm, "DV1").St == 2, "down after the first mark: still mark 2 next", show(w:Track(dm, "DV1")))
	-- a quest without ResetOnKO keeps its step
	local q, e = joinVein(w, 3302, { Subs = { S0 = nil } })
	e.Story.Subs.DV1 = { St = 3, P = 0, T = {}, Claim = false }
	w.Config.StoryQuests.Defs.DV1.ResetOnKO = nil
	w.PS.CharacterDied:Fire(q, q.Character)
	w:Flush()
	check(e.Story.Subs.DV1.St == 3, "no ResetOnKO: going down keeps the step", show(e.Story.Subs.DV1))
	w.Config.StoryQuests.Defs.DV1.ResetOnKO = true
	-- leaving the guard step (another quest's track only) drops the guard: the run is given up via a rejoin at step 1
	local r, f = joinVein(w, 3303)
	f.Story.Subs.DV1 = { St = 4, P = 0, T = {}, Claim = false }
	w:Move(r, def.Steps[4].Spawn.Spot)
	local guard = w.Spawns[#w.Spawns]
	check(guard.Owner == r and guard.Alive, "a saved run at the guards: a guard comes after a rejoin", "")
	f.Story.Subs.DV1 = nil
	w.Story.Refresh(r)
	check(guard.Alive == false and table.find(w.Removed, guard) ~= nil, "the run gone (no guard step open): its guard is removed", "")
end)

------------------------------------------------------------------ 6. the save
runGroup("save", function()
	local w = veinWorld()
	local p, d = joinVein(w, 3401, { Runs = { Vein = 2.7, [""] = 1, Bad = -1, Long = "x" } })
	check(d.Story.Runs.Vein == 2 and d.Story.Runs.Bad == nil and d.Story.Runs.Long == nil, "Runs: whole numbers >= 0 only", show(d.Story.Runs))
	local q, e = joinVein(w, 3402)
	check(type(e.Story.Runs) == "table", "an old save gets an empty Runs table", show(e.Story.Runs))
end)

finish()
