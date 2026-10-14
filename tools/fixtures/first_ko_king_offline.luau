-- first_ko_king_offline.luau : A23-110 the first KO King (FirstKOService, 게임성 개발 2), offline. Runs on
-- tools/fixtures/dev2_world.luau (the real CombatService death pipeline, PvPService, GrudgeService, RankingService,
-- LootService ...) with the real FirstKOService and FinisherService; the quest is a StoryQuestService double (CurrentStep /
-- Event) except in the group "quest KO1", which runs the real StoryQuestService with Config's KO1. MonsterService is a
-- double for the world whose records are built by its real hook-field code and die through its real killRecord; its
-- other A23-110 code is run cut out (landAttack, SpawnPersonal, RemovePersonal, GroundAt); PlayerService's real get-up
-- code and QuestService's real kill handler too. No step number is written here: every one comes from Config.FirstKO.
-- (The at-stake, Tell, Near / Hold and one-rematch-win checks follow the critic's corrected version, 2026-10-10.)

------------------------------------------------------------------ vector Unit (getUpCFrame)
do
	local baseIndex = vmt.__index
	vmt.__index = function(v, key)
		if key == "Unit" then
			local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
			if m == 0 then return vec(0, 0, 0) end
			return vec(v.X / m, v.Y / m, v.Z / m)
		end
		return baseIndex(v, key)
	end
end

local FK0 = C0.FirstKOKing
local FQ = C0.FirstKO
local STEP, RETRY = FQ.Step, FQ.RematchStep -- game dev 3's rows (never numbers of our own)
local MEADOW = vec(430, 0, 0) -- the middle of the SlimeMeadow zone
local TOWN = vec(0, 0, 0) -- the Crossroads (a town)
local PLAIN = C0.MonsterTypes.SlimeKing.Damage -- a plain King hit

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

local function fxOf(w, kind, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Fx do
		local f = w.Fx[i]
		if f.Kind == kind and (p == nil or f.Player == p) then table.insert(out, f.Data) end
	end
	return out
end

------------------------------------------------------------------ the world
-- o: Edit(config), Landmark (Vector3: Config.FirstKOKing.Landmark = "KingHill" there), Studio, Story (the real
-- StoryQuestService instead of the double)
local function fkWorld(o)
	o = o or {}
	local w = rankWorld({ Studio = o.Studio == true, EditConfig = function(c)
		if o.Landmark then
			c.FirstKOKing.Landmark = "KingHill"
			c.StoryQuests.Landmarks.KingHill = o.Landmark
		end
		if o.Edit then o.Edit(c) end
	end })
	local cfg, reg = w.Config, w.Registry
	local Signal = w.Util.Signal
	local stage = newInstance("Folder", w)
	w.Kings, w.Removed, w.Spawns, w.Ground, w.Struck, w.Events, w.StepOf, w.StepAsks = {}, {}, {}, {}, {}, {}, {}, {}
	w.Pops = 0
	local M = reg.MonsterService
	-- the real killRecord on this world's MonsterKilled (deathPop / refs / respawn are counted doubles)
	local kill = execute("MonsterService.killRecord", MON_KILL_EXTRACT, w:Env(), {}, cfg, cfg.Monsters, M,
		function(p) return reg.FactionService.GetFaction(p) end, function() end, function() w.Pops += 1 end, function() end,
		function() end, function(_, m) table.insert(w.Warnings, "MonsterService: " .. tostring(m)) end)
	local nextId = 0
	-- MonsterService.SpawnPersonal double: a record `opts.Distance` studs in front (-Z) of the player; its hook fields come
	-- from the real spawnMonster code. w.NoSpot = no ground by the player (Near: nothing)
	function M.SpawnPersonal(player, kind, opts)
		table.insert(w.Spawns, { P = player, Kind = kind, Opts = opts })
		if w.SpawnFails then error("offline spawn failure") end
		if w.NoSpot and opts.Near == true then return nil end
		if w.Reuse then return w.Reuse.Model, w.Reuse end
		nextId += 1
		local model = newInstance("Model", w)
		model.Parent = stage
		local root = newInstance("Part", w)
		root.Name = "Root"
		local proot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		root.Position = (proot and proot.Position or vec(0, 0, 0)) + vec(0, 0, -(opts.Distance or 8))
		root.Parent = model
		local def = cfg.MonsterTypes[kind]
		local hp = opts.HP or def.HP
		local rec = execute("MonsterService.fields", MON_FIELDS_EXTRACT, w:Env(), player, opts, kind, cfg)
		rec.Id, rec.Kind, rec.Def, rec.ZoneId, rec.Owner, rec.Alive = nextId, kind, def, def.Zone, player, true
		rec.HP, rec.MaxHP, rec.Golden, rec.Model, rec.Root, rec.Home = hp, hp, false, model, root, root.Position
		rec._contributors, rec._hits, rec._dmg = {}, {}, {}
		table.insert(w.Kings, rec)
		return model, rec
	end
	function M.RemovePersonal(rec, fade, leaving)
		table.insert(w.Removed, { Rec = rec, Fade = fade, Leaving = leaving })
		if type(rec) ~= "table" or rec.Owner == nil or not rec.Alive then return false end
		rec.Alive = false
		return true
	end
	-- w.Ground["x:z"] = "water" (nil, false); w.NoGround = a bare place (nil, true); else ground at GroundY (default 1)
	function M.GroundAt(x, z)
		if w.Ground[math.floor(x + 0.5) .. ":" .. math.floor(z + 0.5)] == "water" then return nil, false end
		if w.NoGround then return nil, true end
		if w.GroundInTown then return vec(x - 430, w.GroundY or 1, z), false end -- (a town lies there)
		return vec(x, w.GroundY or 1, z), false
	end
	function M.SpawnEvent() w.EventSpawns = (w.EventSpawns or 0) + 1 end
	function M.RemoveEvent() w.EventRemoves = (w.EventRemoves or 0) + 1 end
	-- the owner hit it o3.Hits times (default 3) just now (o3.Manual ~= false: own presses), then the real killRecord
	function w:KillKing(rec, o3)
		o3 = o3 or {}
		local p = rec.Owner
		rec._contributors[p] = self.Clock
		rec._hits[p] = o3.Hits or 3
		rec._dmg[p] = rec.MaxHP
		if o3.Manual ~= false then rec._manualAt = { [p] = self.Clock } end
		kill(rec)
		self:Flush()
	end
	-- what MonsterService.landAttack does for a landed hit (tested cut out below)
	function w:Strike(rec, target, mult)
		table.insert(self.Struck, { Rec = rec, T = target })
		if rec._strike then return rec._strike(rec, target, mult) end
		return reg.CombatService.DamagePlayer(target, rec.Def.Damage * (mult or 1), nil, false, rec.Kind)
	end

	-- the King Slime finisher card (the real FinisherService: a card for a manual King kill)
	reg.Deeds = { Preview = function() return "Honor", 1, true end, Add = function() return "Honor", 1, true, false end }
	if o.Story then
		-- the real StoryQuestService (Config's KO1); its 1 s loop never runs (Refresh / Event by hand)
		reg.QuestService = { MarkDirty = function() end }
		reg.ZoneService.GetZoneId = function() return "SlimeMeadow" end
		reg.ZoneService.ZoneChanged = Signal.new()
		reg.GooseService.GooseFinished = Signal.new()
		local pg = reg.ProgressionService
		pg.GoldEarned, pg.LeveledUp = Signal.new(), Signal.new()
		w.XP = {}
		pg.AddXP = function(_, n) table.insert(w.XP, n) return n end
		function pg.GetTotalGold(p)
			local d = w.Data[p]
			return d and ((d.CarriedGold or 0) + (d.BankGold or 0)) or 0
		end
		w.Services.CollectionService = { GetTagged = function() return {} end }
		local ws = w:Env().workspace
		ws.FindFirstChild = function() return nil end
		local rs = w.Services.ReplicatedStorage
		if not rs.FindFirstChild then rs.FindFirstChild = function() return nil end end
		local story = w:Load("StoryQuestService", STORY_SOURCE)
		reg.StoryQuestService = story
		w.Story = story
	else
		-- StoryQuestService double: w.StepOf[p] = the quest's step (nil = not started / done / claim); Event "FirstKO"
		-- at Config.FirstKO.Step moves it one row on (w.EventStuck = it does not)
		reg.StoryQuestService = {
			CurrentStep = function(p, id)
				table.insert(w.StepAsks, id)
				if w.StepThrows then error("offline step boom") end
				if id ~= cfg.FirstKO.Quest then return nil end
				return w.StepOf[p]
			end,
			Event = function(p, name, info)
				table.insert(w.Events, { P = p, Name = name, Info = info })
				if w.EventThrows then error("offline event boom") end
				local cur = w.StepOf[p]
				if name == "FirstKO" and cur == cfg.FirstKO.Step and not w.EventStuck then
					w.StepOf[p] = cur + 1
					return true
				end
				return false
			end,
		}
	end
	local fin = w:Load("FinisherService", FINISHER_SOURCE)
	reg.FinisherService = fin
	fin.Init(reg)
	if w.Story then w.Story.Init(reg) end
	fin.Start()
	if w.Story then w.Story.Start() end
	w.Spawned = {} -- (the story's 1 s loop)

	local svc = w:Load("FirstKOService", FIRSTKO_SOURCE)
	reg.FirstKOService = svc
	svc.Init(reg)
	local n0 = #w.Spawned
	svc.Start()
	assert(#w.Spawned == n0 + 1, "FirstKOService.Start spawns one loop")
	w.Spawned = {} -- the check loop never runs here: w:FKTick steps FirstKOService.Tick
	w.FK = svc
	w.FirstKOs, w.Beaten, w.Killed, w.KOFired = {}, {}, {}, {}
	svc.FirstKO:Connect(function(p) table.insert(w.FirstKOs, p) end)
	svc.KingBeaten:Connect(function(p, retry) table.insert(w.Beaten, { P = p, Retry = retry }) end)
	M.MonsterKilled:Connect(function(p, info) table.insert(w.Killed, { P = p, Info = info }) end)
	reg.CombatService.KnockedOut:Connect(function(p, by) table.insert(w.KOFired, { P = p, By = by }) end)
	function w:FKTick(seconds)
		self:Advance(seconds or FK0.Tick)
		svc.Tick()
		self:Flush()
	end
	function w:Place(p, pos)
		local root = p.Character:FindFirstChild("HumanoidRootPart")
		root.Position = pos
		root.CFrame = { LookVector = vec(0, 0, -1), Position = pos }
	end
	-- a ready player in the meadow (o2.Pos; o2.Done = the account had its first KO). The double: on the quest's KO row
	-- unless o2.Step (false = no step). The real story: a save that finished M1_1 / M1_2 with no potion (KO1 starts at join)
	function w:Hunter(userId, faction, o2)
		o2 = o2 or {}
		local tier = o2.Tier or 1
		local data = { Class = o2.Class or "Warrior", WeaponTier = tier, FirstKODone = o2.Done == true,
			WeaponOwnedMask = tier >= 1 and bit32.lshift(1, tier - 1) or 0 }
		if self.Story then
			data.TutorialStep = 99
			data.Story = { Main = { Id = "" }, Subs = {}, Done = { M1_1 = true, M1_2 = true }, Pick = {}, First = { Migrated = true } }
		end
		for k, v in o2.Data or {} do data[k] = v end
		local p = self:Join(userId, faction or "Halo", { Level = o2.Level or 3, Carried = o2.Carried, Data = data })
		if not self.Story then
			if o2.Step == nil then self.StepOf[p] = STEP elseif o2.Step ~= false then self.StepOf[p] = o2.Step end
		end
		self:Place(p, o2.Pos or MEADOW)
		self:Flush()
		return p
	end
	function w:Hum(p) return p.Character:FindFirstChildOfClass("Humanoid") end
	function w:KingOf(p)
		for i = #self.Kings, 1, -1 do
			local r = self.Kings[i]
			if r.Owner == p and r.Alive then return r end
		end
		return nil
	end
	function w:KOFx(p)
		local last = nil
		for _, f in self.Fx do
			if f.Kind == "KO" and f.Player == p then last = f.Data end
		end
		return last
	end
	function w:CountKOFx(p)
		local n = 0
		for _, f in self.Fx do
			if f.Kind == "KO" and f.Player == p then n += 1 end
		end
		return n
	end
	function w:EventsOf(p)
		local out = {}
		for _, e in self.Events do
			if e.P == p then table.insert(out, e) end
		end
		return out
	end
	-- the King appears (one check) and lands (DropTime later)
	function w:Meet(p)
		self:FKTick()
		local rec = self:KingOf(p)
		self:Advance(FK0.DropTime + 0.01)
		return rec
	end
	return w
end

------------------------------------------------------------------ 1. config
runGroup("config", function()
	local mz, tz = C0.ZoneAt(MEADOW), C0.ZoneAt(TOWN)
	check(mz.Id == "SlimeMeadow" and mz.Town ~= true and tz.Town == true, "setup: the meadow spot and the Crossroads (a town)",
		show({ mz.Id, tz.Id }))
	check(type(FK0) == "table" and FK0.Enabled == true, "Config.FirstKOKing on (its own table: game dev 3's Config.FirstKO untouched)", show(FK0))
	local def = type(FQ) == "table" and type(FQ.Quest) == "string" and C0.StoryQuests.Defs[FQ.Quest] or nil
	check(def ~= nil and type(STEP) == "number" and type(RETRY) == "number" and STEP < RETRY and FQ.Kind == nil and FQ.OneHitBelow == nil,
		"game dev 3's Config.FirstKO names a story quest, its KO row before its rematch row (no keys of ours in it)", show(FQ))
	local steps = def and def.Steps or {}
	local s1, s2 = steps[STEP], steps[RETRY]
	check(s1 and s1.Obj.Type == "Event" and s1.Obj.Name == "FirstKO" and s1.Obj.Past ~= true and C0.StoryQuests.Events.FirstKO == true,
		"Config.FirstKO.Step = the row waiting for Event FirstKO (a listed happening)", show(s1 and s1.Obj))
	check(s2 and s2.Obj.Type == "Kill" and C0.QuestKind(FK0.Kind) == s2.Obj.Kind and s2.Obj.Personal == true and s2.Obj.Zone == FK0.Zone
		and C0.MonsterTypes[FK0.Kind].Zone == FK0.Zone and (s2.Obj.Count or 1) == 1,
		"Config.FirstKO.RematchStep = one Personal kill of our King in its own zone (what a retry King's kill reports)", show(s2 and s2.Obj))
	check(C0.MonsterTypes[FK0.Kind] ~= nil and FK0.Kind == "SlimeKing" and C0.MonsterTypes.SlimeKing.Boss == true,
		"the King Slime (a boss kind, never in the regular pool)")
	local req = def and def.Requires or {}
	check(FK0.OneHitBelow == 10 and type(req.MaxLevel) == "number" and req.MaxLevel < FK0.OneHitBelow,
		"one hit below Lv 10; the quest opens below that (its start level always gets the KO)", show({ FK0.OneHitBelow, req.MaxLevel }))
	check(FK0.OneHitMult >= 10 and FK0.FirstHP >= C0.MonsterTypes.SlimeKing.HP, "x MaxHealth >= 10 (the Guard cap), the first King hard to kill", show(FK0))
	check(FK0.RespawnIn <= C0.Player.RespawnTime and FK0.RespawnIn > 0, "the first KO gets up no later than a normal KO")
	check(FK0.Zone == "SlimeMeadow" and C0.Zones[FK0.Zone] ~= nil and C0.Zones[FK0.Zone].Town == false, "the meadow (not a town)")
	check(FK0.GetUp.HealthFrac >= 0.2 and FK0.GetUp.HealthFrac <= 0.6, "the get-up leaves the player hurt (a potion is worth drinking)",
		tostring(FK0.GetUp.HealthFrac))
	local pay = C0.MonsterTypes[FK0.Retry.PayAs]
	check(pay ~= nil and pay.XP < C0.MonsterTypes.SlimeKing.XP and pay.Gold < C0.MonsterTypes.SlimeKing.Gold and pay.Boss ~= true,
		"the practice kill pays a small kind's XP / gold (the quest pays the real reward)", show({ FK0.Retry.PayAs, pay and pay.XP }))
	check(FK0.BossClear >= 20 and FK0.BossClear <= 30,
		"BossClear keeps the bodies apart but never blocks the hill for the field King's stay", tostring(FK0.BossClear))
	check(C0.Data.Defaults.FirstKODone == false, "the save field (additive, false)")
	check(C0.Data.Defaults.Version == 6, "Version 6 = A23-186's joke weapons (5 = A23-153's codex, 4 = C1's tier 9) (the first-KO fields are additive)")
	local w = fkWorld({ Edit = function(c) c.FirstKO.Quest = nil end })
	local p = w:Hunter(101, "Halo")
	w:FKTick()
	check(#w.Spawns == 0 and w.FK.StageOf(p) == nil, "no quest named: the service does nothing", tostring(#w.Spawns))
end)

------------------------------------------------------------------ 2. the stage = the quest's CurrentStep
runGroup("stage", function()
	local w = fkWorld()
	local uid = 100
	local function stageAt(step, o2)
		uid += 1
		o2 = o2 or {}
		o2.Step = step
		return w.FK.StageOf(w:Hunter(uid, o2.Faction or "Halo", o2))
	end
	check(stageAt(STEP) == "First", "the quest at Config.FirstKO.Step: the first King")
	for st = STEP + 1, RETRY - 1 do
		check(stageAt(st) == nil, "every row between the KO and the rematch: nothing", tostring(st))
	end
	check(stageAt(RETRY) == "Retry", "the quest at Config.FirstKO.RematchStep: the retry King")
	check(stageAt(false) == nil, "CurrentStep nil (not started / done / waiting for [Claim]): nothing")
	check(stageAt(RETRY + 1) == nil and (STEP <= 1 or stageAt(STEP - 1) == nil), "rows outside: nothing")
	check(stageAt(STEP, { Level = FK0.OneHitBelow - 1 }) == "First", "Lv OneHitBelow - 1: still the first KO")
	check(stageAt(STEP, { Level = FK0.OneHitBelow }) == "Tell", "Lv OneHitBelow on the KO row: never one-shot, the quest is told")
	check(stageAt(STEP, { Done = true }) == "Tell", "the account had its first KO: the quest is told (no King)")
	check(stageAt(RETRY, { Level = 30, Done = true }) == "Retry", "the rematch at any level, after the KO")
	local asked = true
	for _, id in w.StepAsks do
		if id ~= FQ.Quest then asked = false end
	end
	check(#w.StepAsks > 0 and asked, "CurrentStep is asked for game dev 3's quest only", show(w.StepAsks))
	local kz = w:Hunter(150, "Horns")
	kz:SetAttribute("KaijuState", "Active")
	local ks = w:Hunter(151, "Horns")
	ks:SetAttribute("KaijuState", "Siren")
	local kq = w:Hunter(152, "Horns")
	kq:SetAttribute("KaijuState", "Queued")
	check(w.FK.StageOf(kz) == nil and w.FK.StageOf(ks) == nil, "a kaiju (Siren / Active) never: its KO is the kaiju event's")
	check(w.FK.StageOf(kq) == "First", "only queued for the kaiju: the King still comes (its hits stay plain: at stake)")
	-- Enabled = false: no King anywhere, but the KO row is still told (never stuck there); the rematch row gets nothing
	local w2 = fkWorld({ Edit = function(c) c.FirstKOKing.Enabled = false end })
	local d1 = w2:Hunter(160, "Halo")
	local d2 = w2:Hunter(161, "Halo", { Step = RETRY })
	check(w2.FK.StageOf(d1) == "Tell" and w2.FK.StageOf(d2) == nil, "Enabled = false: the KO row is a Tell row, the rematch row has nothing",
		show({ w2.FK.StageOf(d1), w2.FK.StageOf(d2) }))
	w2:FKTick()
	check(#w2.Spawns == 0 and #w2:EventsOf(d1) == 1 and w2.StepOf[d1] == STEP + 1 and #w2:EventsOf(d2) == 0,
		"Enabled = false: no King; the KO row passes (Event FirstKO), nothing for the rematch row", show({ #w2.Spawns, w2.StepOf[d1] }))
	-- game dev 3 adds a row before the rematch (RematchStep + 1): the retry King follows it
	local wx = fkWorld({ Edit = function(c) c.FirstKO.RematchStep = c.FirstKO.RematchStep + 1 end })
	check(wx.FK.StageOf(wx:Hunter(170, "Halo", { Step = RETRY })) == nil
		and wx.FK.StageOf(wx:Hunter(171, "Halo", { Step = RETRY + 1 })) == "Retry",
		"an extra row before the rematch: the old rematch row has no King, the new one has the retry King")
	-- ... and a row before the KO (Step + 1)
	local wy = fkWorld({ Edit = function(c) c.FirstKO.Step, c.FirstKO.RematchStep = c.FirstKO.Step + 1, c.FirstKO.RematchStep + 1 end })
	check(wy.FK.StageOf(wy:Hunter(172, "Halo", { Step = STEP })) == nil
		and wy.FK.StageOf(wy:Hunter(173, "Halo", { Step = STEP + 1 })) == "First",
		"the KO row moved: the first King follows it")
	-- a throwing CurrentStep: nothing (warned); no StoryQuestService: nothing
	local wt = fkWorld()
	local pt = wt:Hunter(180, "Halo")
	wt.StepThrows = true
	wt.AllowWarn = "offline step boom"
	check(wt.FK.StageOf(pt) == nil, "a throwing CurrentStep: nothing")
	wt:FKTick()
	check(#wt.Spawns == 0, "... and no King")
	wt.Registry.StoryQuestService = nil
	wt.StepThrows = false
	check(wt.FK.StageOf(pt) == nil, "no StoryQuestService: nothing")
end)

------------------------------------------------------------------ 3. the King comes
runGroup("spawn", function()
	local w = fkWorld()
	local p = w:Hunter(101, "Halo")
	w:FKTick()
	local s = w.Spawns[1]
	check(#w.Spawns == 1 and s.P == p and s.Kind == "SlimeKing", "one personal King Slime for the player on the KO row", tostring(#w.Spawns))
	check(s and s.Opts.HP == FK0.FirstHP and s.Opts.Quiet == true and type(s.Opts.Strike) == "function"
		and type(s.Opts.OnKilled) == "function" and s.Opts.Distance == FK0.SpawnDistance and s.Opts.Practice == nil,
		"SpawnPersonal opts: FirstHP, Quiet, Strike, OnKilled, SpawnDistance (no Practice)", s and show({ s.Opts.HP, s.Opts.Quiet, s.Opts.Distance }))
	check(s and s.Opts.Near == true and s.Opts.Hold == FK0.DropTime + FK0.FirstLeapAfter,
		"Near (never the home-town spot) and Hold = DropTime + FirstLeapAfter (A23-113: its first leap lands one cycle after the drop)",
		s and show({ s.Opts.Near, s.Opts.Hold }))
	check(s and s.Opts.LeapGrow == FK0.LeapGrow and s.Opts.LeapGrowMax == FK0.LeapGrowMax and FK0.LeapGrow > 0,
		"A23-113: the first King's circle grows LeapGrow after each miss (up to LeapGrowMax)", s and show({ s.Opts.LeapGrow, s.Opts.LeapGrowMax }))
	local rec = w:KingOf(p)
	check(rec ~= nil and rec.Quiet == true and rec.Practice == nil and rec.Model.Attrs.FirstKO == "First" and rec.Model.Attrs.DropAt == w.Time
		and rec.Model.Attrs.DropTime == FK0.DropTime and rec.Model.Attrs.DropRadius == FK0.LandRadius,
		"a quiet King; model attributes FirstKO / DropAt / DropTime / DropRadius = LandRadius (the client's drop and circle)",
		rec and show(rec.Model.Attrs))
	w:FKTick()
	w:FKTick(5)
	check(#w.Spawns == 1, "only one King at a time", tostring(#w.Spawns))
	check((w.EventSpawns or 0) == 0, "never a field (event) King")
	-- the Tell row: no King
	local wtl = fkWorld()
	wtl:Hunter(116, "Halo", { Done = true })
	wtl:FKTick()
	check(#wtl.Spawns == 0, "the account had its KO (Tell): no King")
	-- not in place: town, another zone, dead, not on a King row
	local w2 = fkWorld()
	local t = w2:Hunter(102, "Halo", { Pos = TOWN })
	w2:Hunter(103, "Halo", { Pos = vec(840, 0, 95) }) -- the goblin woods
	local d = w2:Hunter(104, "Halo")
	w2:Hum(d).Health = 0
	w2:Hunter(105, "Halo", { Step = STEP + 1 })
	w2:FKTick()
	check(C0.ZoneAt(vec(840, 0, 95)).Id ~= "SlimeMeadow", "setup: another zone")
	check(#w2.Spawns == 0, "no King in town / another zone / dead / off the King rows", tostring(#w2.Spawns))
	w2:Place(t, MEADOW)
	w2:FKTick()
	check(#w2.Spawns == 1 and w2.Spawns[1].P == t, "walking into the meadow brings it", tostring(#w2.Spawns))
	-- the field King fights nearby: the personal King waits (a slime nearby does not matter)
	local wb = fkWorld()
	local field = { Kind = "SlimeKing", Owner = nil, Alive = true, Root = { Position = MEADOW + vec(FK0.BossClear - 4, 0, 0) } }
	local slime = { Kind = "Slime", Owner = nil, Alive = true, Root = { Position = MEADOW + vec(3, 0, 0) } }
	local around = { field, slime }
	wb.Registry.MonsterService.GetMonstersInRadius = function(pos, radius)
		local out = {}
		for _, r in around do
			if r.Alive and wb.Util.FlatDistance(r.Root.Position, pos) <= radius then table.insert(out, r) end
		end
		return out
	end
	local hb = wb:Hunter(113, "Halo")
	wb:FKTick()
	check(#wb.Spawns == 0, "the field King within BossClear: no personal King")
	field.Root.Position = MEADOW + vec(30, 0, 0)
	wb:FKTick()
	check(#wb.Spawns == 1 and wb.Spawns[1].P == hb,
		"the field King 30 studs away (still by its hill marker): the personal King comes (a slime nearby is fine)")
	-- the King's zone set to a town: still never in a town
	local wt = fkWorld({ Edit = function(c) c.FirstKOKing.Zone = "Crossroads" end })
	wt:Hunter(110, "Halo", { Pos = TOWN })
	wt:FKTick()
	check(#wt.Spawns == 0, "never inside a town")
	-- a shielded owner keeps its King: still one at a time
	local w6 = fkWorld()
	local s6 = w6:Hunter(111, "Halo")
	w6:Hum(s6).TakeDamage = function() end
	for _ = 1, 4 do w6:FKTick(FK0.SpawnGap) end
	check(#w6.Spawns == 1 and w6:KingOf(s6) ~= nil, "a living King is never doubled", tostring(#w6.Spawns))
	-- the landmark radius
	local w3 = fkWorld({ Landmark = vec(500, 0, 60) })
	local far = w3:Hunter(106, "Halo", { Pos = vec(300, 0, -150) })
	local close = w3:Hunter(107, "Halo", { Pos = vec(480, 0, 40) })
	w3:FKTick()
	check(#w3.Spawns == 1 and w3.Spawns[1].P == close, "with a Landmark: only within Radius of it", tostring(#w3.Spawns))
	w3:Place(far, vec(500 - FK0.Radius + 5, 0, 60))
	w3:FKTick()
	check(#w3.Spawns == 2, "inside the Radius now", tostring(#w3.Spawns))
	-- a failing spawn waits SpawnGap
	local w4 = fkWorld()
	w4.AllowWarn = "offline spawn failure"
	w4.SpawnFails = true
	w4:Hunter(108, "Halo")
	w4:FKTick()
	w4.SpawnFails = false
	w4:FKTick()
	check(#w4.Spawns == 1, "after a failed spawn: wait SpawnGap", tostring(#w4.Spawns))
	w4:FKTick(FK0.SpawnGap)
	check(#w4.Spawns == 2, "then try again", tostring(#w4.Spawns))
	-- no ground by the player (Near): no King, no retry before SpawnGap
	local w8 = fkWorld()
	local s8 = w8:Hunter(120, "Halo")
	w8.NoSpot = true
	w8:FKTick()
	w8:FKTick()
	check(#w8.Spawns == 1 and w8:KingOf(s8) == nil, "no ground by the player: no King, no retry before SpawnGap", tostring(#w8.Spawns))
	w8.NoSpot = false
	w8:FKTick(FK0.SpawnGap)
	check(w8:KingOf(s8) ~= nil, "then it comes")
	-- SpawnPersonal handed back an old King of ours (reused): it goes home, ours comes next time
	local w5 = fkWorld()
	local r5 = w5:Hunter(109, "Halo")
	local old = newInstance("Model", w5)
	old:SetAttribute("FirstKO", "First")
	w5.Reuse = { Owner = r5, Alive = true, Quiet = true, Model = old, Root = newInstance("Part", w5) }
	w5:FKTick()
	check(w5.Removed[1] and w5.Removed[1].Rec == w5.Reuse and w5.Removed[1].Leaving == true and w5:KingOf(r5) == nil,
		"a reused old King is sent home (not adopted)", show(w5.Removed[1] and w5.Removed[1].Leaving))
	w5.Reuse = nil
	w5:FKTick(FK0.SpawnGap)
	check(w5:KingOf(r5) ~= nil, "then a fresh King")
	-- a reused King of ours (our hook, its FirstKO attribute) and a foreign personal King (no hook)
	local w7 = fkWorld()
	local r7 = w7:Hunter(114, "Halo")
	w7:FKTick()
	local mine = w7:KingOf(r7)
	local stale = { Owner = r7, Alive = true, Quiet = true, Model = mine.Model, Root = mine.Root, _strike = mine._strike }
	local own = { Owner = r7, Alive = true, Quiet = true, Model = newInstance("Model", w7), Root = mine.Root }
	mine.Alive = false -- (its time ran out)
	w7.Reuse = stale
	w7:FKTick(FK0.SpawnGap)
	w7:FKTick(FK0.SpawnGap)
	check(w7.Removed[#w7.Removed] and w7.Removed[#w7.Removed].Rec == stale and w7:KingOf(r7) == nil,
		"a reused King of ours (already given a stage) is sent home", show(#w7.Removed))
	w7.Reuse = own
	w7:FKTick(FK0.SpawnGap)
	check(w7.Removed[#w7.Removed] and w7.Removed[#w7.Removed].Rec == own, "a personal King Slime without our hook is sent home")
	-- the owner steps into a town while a King is alive: it goes home (a personal King never swings there, so it is never
	-- fought from there), then waits SpawnGap
	local wtw = fkWorld()
	local ptw = wtw:Hunter(121, "Halo", { Step = RETRY })
	wtw:FKTick()
	local ktw = wtw:KingOf(ptw)
	wtw:Place(ptw, TOWN)
	wtw:FKTick()
	check(ktw ~= nil and not ktw.Alive and wtw.Removed[#wtw.Removed] and wtw.Removed[#wtw.Removed].Rec == ktw
		and wtw.Removed[#wtw.Removed].Leaving == true, "the owner in a town: its King goes home (leaving)", show(#wtw.Removed))
	wtw:Place(ptw, MEADOW)
	wtw:FKTick()
	check(wtw:KingOf(ptw) == nil, "back in the meadow: not at once (SpawnGap)")
	wtw:FKTick(FK0.SpawnGap)
	check(wtw:KingOf(ptw) ~= nil, "then the King comes again")
	-- its personal lifetime ran out (MonsterService despawned it, no kill): no new drop at once, SpawnGap first
	local w9 = fkWorld()
	local s9 = w9:Hunter(119, "Halo")
	w9:Hum(s9).TakeDamage = function() end -- (a shielded owner: the King lives on)
	w9:FKTick()
	local r9 = w9:KingOf(s9)
	w9:Advance(FK0.SpawnGap + 1) -- long after its own spawn gap
	r9.Alive = false
	w9:FKTick()
	check(#w9.Spawns == 1, "a King whose time ran out: no new drop at once", tostring(#w9.Spawns))
	w9:FKTick(FK0.SpawnGap)
	check(#w9.Spawns == 2, "then a new one after SpawnGap", tostring(#w9.Spawns))
end)

------------------------------------------------------------------ 4. the landing thud: one hit
runGroup("one hit", function()
	local w = fkWorld()
	local p = w:Hunter(101, "Horns")
	w:FKTick()
	check(w:Hum(p).Health == 100, "no hit before the landing")
	w:Advance(FK0.DropTime - 0.05)
	check(w:Hum(p).Health == 100, "still in the air")
	w:Advance(0.1)
	check(w:Hum(p).Health == 0, "the landing thud knocks the owner out in one hit", tostring(w:Hum(p).Health))
	local hurt = nil
	for _, f in w.Fx do
		if f.Kind == "Hurt" and f.Player == p then hurt = f.Data end
	end
	check(hurt and hurt.Amount == 100, "the hit number shows the HP really lost (no 2000)", show(hurt))
	check(w.FK.GetUp(p) ~= nil and w.FK.GetUp(p).Delay == FK0.RespawnIn and w.FK.GetUp(p).CFrame == nil,
		"at the Died event (not claimed yet) the get-up delay is already known", show(w.FK.GetUp(p)))
	-- a later hit (a dodged landing) is a one-shot too
	local w2 = fkWorld()
	local q = w2:Hunter(102, "Halo")
	w2:FKTick()
	local r2 = w2:KingOf(q)
	w2:Place(q, MEADOW + vec(FK0.LandRadius + 3, 0, -FK0.SpawnDistance))
	w2:Advance(FK0.DropTime + 0.01)
	check(w2:Hum(q).Health == 100, "out of LandRadius: the landing misses")
	w2:Strike(r2, q)
	check(w2:Hum(q).Health == 0, "its next landed hit knocks out in one hit")
	-- A23-113 ①: the drop's circle hits inside LandRadius - BossLeap.Grace (the rule of every leap's circle)
	local edge = FK0.LandRadius - C0.BossLeap.Grace
	for i, case in { { edge - 0.1, 0 }, { edge + 0.1, 100 } } do
		local wl = fkWorld()
		local u = wl:Hunter(120 + i, "Halo")
		wl:FKTick()
		local k = wl:KingOf(u).Root.Position
		wl:Place(u, vec(k.X + case[1], k.Y, k.Z))
		wl:Advance(FK0.DropTime + 0.01)
		check(wl:Hum(u).Health == case[2], string.format("the drop's circle: %.1f studs from it %s", case[1],
			case[2] == 0 and "is hit" or "is not (outside LandRadius - Grace)"), tostring(wl:Hum(u).Health))
	end
	-- high above / below the landing (a cliff): no thud
	local w3 = fkWorld()
	local h = w3:Hunter(103, "Halo")
	w3:FKTick()
	w3:Place(h, MEADOW + vec(0, 20, 0))
	w3:Advance(FK0.DropTime + 0.01)
	check(w3:Hum(h).Health == 100, "20 studs above the landing: no thud")
	-- a 90% Guard (SKL-3 cap) cannot save it
	local wg = fkWorld()
	local gd = wg:Hunter(106, "Halo")
	wg.Registry.SkillService = { GuardOf = function() return 0.9 end }
	wg:FKTick()
	wg:Advance(FK0.DropTime + 0.01)
	check(wg:Hum(gd).Health == 0, "a 90% Guard cannot save it (OneHitMult x MaxHealth)", tostring(wg:Hum(gd).Health))
	-- a ForceField takes the hit: no KO pending
	local w4 = fkWorld()
	local ff = w4:Hunter(104, "Halo")
	w4:Hum(ff).TakeDamage = function() end
	w4:FKTick()
	w4:Advance(FK0.DropTime + 0.01)
	check(w4:Hum(ff).Health == 100 and w4.FK.GetUp(ff) == nil, "a shielded hit leaves no first KO waiting")
	-- the quest moved on while the King was alive: a plain hit, then it goes home
	local w5 = fkWorld()
	local s5 = w5:Hunter(105, "Halo")
	w5:FKTick()
	local r5 = w5:KingOf(s5)
	w5.StepOf[s5] = STEP + 1
	w5:Strike(r5, s5)
	check(w5:Hum(s5).Health == 100 - PLAIN, "after the KO row: the King's own damage only", tostring(w5:Hum(s5).Health))
	w5:FKTick()
	check(not r5.Alive and w5.Removed[1] and w5.Removed[1].Leaving == true, "and the next check sends it home (floating away)")
end)

------------------------------------------------------------------ 5. lossless KO through the real death pipeline
runGroup("lossless", function()
	-- a Horns with a pouch and a bank, nothing at stake: the first KO keeps everything (RespawnIn 2 here)
	local w = fkWorld({ Edit = function(c) c.FirstKOKing.RespawnIn = 2 end })
	local p = w:Hunter(202, "Horns", { Carried = 4000, Data = { BankGold = 700, XP = 33 } })
	local carried, bank = w.Data[p].CarriedGold, w.Data[p].BankGold
	local xp, level, kos = w.Data[p].XP, w.Data[p].Level, w.Data[p].KOs
	check(carried == 4000 and bank == 700, "setup: a pouch and a bank", show({ carried, bank }))
	w:FKTick()
	local rec = w:KingOf(p)
	w:Advance(FK0.DropTime + 0.01)
	check(w:Hum(p).Health == 0, "the King's landing knocks the player out")
	check(#w:EventsOf(p) == 0, "nothing reported before the Died event")
	w:Die(p)
	local ko = w:KOFx(p)
	check(ko and ko.First == true and ko.By == "Monster" and ko.Name == C0.MonsterTypes.SlimeKing.Name and ko.Lost == 0
		and ko.Sack == false and ko.Tip == nil and ko.RespawnIn == 2 and ko.Faction == "",
		"KO fx: First, the King's name, nothing lost, no tip, RespawnIn", show(ko))
	check(w:CountKOFx(p) == 1, "one KO fx")
	local ev = w:EventsOf(p)
	check(#ev == 1 and ev[1].Name == "FirstKO" and ev[1].Info.Kind == "SlimeKing" and ev[1].Info.Beaten == nil,
		"StoryQuestService.Event(player, \"FirstKO\", { Kind = SlimeKing }) once", show(ev[1] and ev[1].Info))
	check(w.StepOf[p] == STEP + 1, "the quest moved to its next row", tostring(w.StepOf[p]))
	check(w.Data[p].CarriedGold == carried and w.Data[p].BankGold == bank, "no gold lost (pouch, bank)",
		show({ w.Data[p].CarriedGold, carried }))
	check(w.Data[p].XP == xp and w.Data[p].Level == level, "no XP / level change")
	check(w.Data[p].KOs == kos, "the KO is not counted (data.KOs)", show({ w.Data[p].KOs, kos }))
	check(w.Data[p].FirstKODone == true and #w.FirstKOs == 1 and w.FirstKOs[1] == p, "FirstKODone + FirstKO(player) once")
	check(#w.KOFired == 1 and w.KOFired[1].By == "Monster", "KnockedOut (telemetry) once, By Monster", tostring(#w.KOFired))
	check(not rec.Alive and w.Removed[#w.Removed].Rec == rec and w.Removed[#w.Removed].Leaving == true,
		"the King floats home (leaving, no splat)")
	check(#w.Killed == 0, "no MonsterKilled anywhere")
	-- the King's source is forgotten: a fall right after getting up is not "King Slime" again
	w:Hum(p).Health = 100
	w:Advance(0.1)
	w:Hum(p).Health = 0
	w:Die(p)
	check(w:KOFx(p).First == nil and w:KOFx(p).Name ~= C0.MonsterTypes.SlimeKing.Name and #w.FirstKOs == 1,
		"the next KO is a normal one and does not name the King", show(w:KOFx(p)))
	-- a save marked done between the hit and the KO (another check) is not claimed again
	local wd = fkWorld()
	local sd = wd:Hunter(205, "Halo")
	wd:Meet(sd)
	wd.Data[sd].FirstKODone = true
	wd:Die(sd)
	check(#wd.FirstKOs == 0 and wd:KOFx(sd).First == nil and #wd:EventsOf(sd) == 0, "FirstKODone already: a normal KO, no signal")
	-- a throwing quest service: the KO is still lossless (warned)
	local we = fkWorld()
	local se = we:Hunter(206, "Halo", { Carried = 300 })
	we.EventThrows = true
	we.AllowWarn = "offline event boom"
	we:Meet(se)
	we:Die(se)
	check(we:KOFx(se) and we:KOFx(se).First == true and we.Data[se].CarriedGold == 300 and #we.FirstKOs == 1,
		"a throwing StoryQuestService.Event: still the lossless first KO", show(we:KOFx(se)))
	-- control: a wanted Horns killed by a slime (no PvP) loses a quarter of the pouch and the stars
	local c2 = fkWorld()
	local v2 = c2:Hunter(304, "Horns", { Carried = 4000, Step = STEP + 1 })
	c2.PvP.DebugSetStars(v2, 2)
	c2.Combat.DamagePlayer(v2, 1000, nil, false, "Slime")
	c2:Die(v2)
	check(c2.Data[v2].CarriedGold < 4000 and c2.PvP.GetStars(v2) == 0, "control: a wanted monster KO loses pouch gold and stars",
		tostring(c2.Data[v2].CarriedGold))
end)

------------------------------------------------------------------ 5b. nothing at stake: no way out of a loss
-- a grudge sack, wanted stars, a bounty, a PvP fight or the kaiju queue would be skipped by the lossless pipeline, so with
-- any of them the King hits like a plain King and a death is the normal one
runGroup("at stake", function()
	-- the full case: a thief with a sack, 2 stars and a knight's hit just before the King's landing
	local w = fkWorld()
	local mark = w:Join(201, "Halo", { Carried = 10000, Level = 3 })
	w:Place(mark, MEADOW)
	local thief = w:Hunter(202, "Horns", { Carried = 4000 })
	local knight = w:Join(203, "Halo", { Level = 3 })
	w:Place(knight, MEADOW)
	w:KO(mark, thief) -- the thief takes a grudge sack
	w:RunSpawned()
	w.PvP.DebugSetStars(thief, 2)
	check(w.Grudge.HasSack(thief) and w.PvP.GetStars(thief) == 2, "setup: a sack and 2 stars")
	local honor = w.Data[knight].Honor
	w:Hit(thief, knight, 5)
	w:RunSpawned()
	local hp0 = w:Hum(thief).Health
	w:FKTick()
	check(w.FK.StageOf(thief) == "First" and w:KingOf(thief) ~= nil, "the King still comes (the quest goes on)")
	w:Advance(FK0.DropTime + 0.01)
	check(w:Hum(thief).Health == hp0 - PLAIN, "at stake: the landing is a plain King hit", show({ w:Hum(thief).Health, hp0 }))
	check(w.FK.GetUp(thief) == nil, "no first KO waiting")
	w.Combat.DamagePlayer(thief, 1000, nil, false, "SlimeKing") -- the King's plain hits finish it
	w:Die(thief)
	local ko = w:KOFx(thief)
	check(ko and ko.First == nil and ko.By == "Player" and not w.Grudge.HasSack(thief) and w.PvP.GetStars(thief) == 0,
		"the normal KO: the knight's PvP KO, the sack resolved, the stars gone", show(ko))
	check(w.Data[knight].Honor > honor, "the knight is credited", show({ w.Data[knight].Honor, honor }))
	check(w.Data[thief].FirstKODone == false and #w.FirstKOs == 0 and #w:EventsOf(thief) == 0, "no first KO used up, nothing reported")
	-- each stake alone (a fresh world each, one-hit expected without it)
	local function landed(setup)
		local ws = fkWorld()
		local s = ws:Hunter(401, "Horns", { Carried = 100 })
		setup(ws, s)
		ws:FKTick()
		ws:Advance(FK0.DropTime + 0.01)
		return ws:Hum(s).Health, ws, s
	end
	check(landed(function() end) == 0, "control: nothing at stake = the one hit")
	local hpSack, wsS, sS = landed(function(ws, s)
		local m = ws:Join(402, "Halo", { Level = 3 })
		ws.Grudge.AddToSack(s, m, 50, 0, 0)
		ws:RunSpawned()
		ws:Hum(s).Health = 100
	end)
	check(wsS.Grudge.HasSack(sS) and wsS.PvP.GetStars(sS) == 0 and hpSack == 100 - PLAIN, "a grudge sack alone: plain hit", tostring(hpSack))
	check(landed(function(_, s) s:SetAttribute("Bounty", 0) end) == 0, "control 2: Bounty 0 and no stars = the one hit")
	local hpWanted = landed(function(ws, s)
		ws.PvP.DebugSetStars(s, 1)
		s:SetAttribute("Bounty", 0)
	end)
	check(hpWanted == 100 - PLAIN, "wanted stars alone: plain hit", tostring(hpWanted))
	local hpBounty = landed(function(_, s) s:SetAttribute("Bounty", 50) end)
	check(hpBounty == 100 - PLAIN, "a bounty alone: plain hit", tostring(hpBounty))
	local hpQueue = landed(function(_, s) s:SetAttribute("KaijuState", "Queued") end)
	check(hpQueue == 100 - PLAIN, "queued for the kaiju: plain hit", tostring(hpQueue))
	-- a PvP fight: plain while tagged, the one hit once the tag is over
	local wf = fkWorld()
	local f = wf:Hunter(403, "Horns", { Carried = 100 })
	local k2 = wf:Join(404, "Halo", { Level = 3 })
	local honor2 = wf.Data[k2].Honor
	wf:Hit(f, k2, 5)
	wf:RunSpawned()
	wf:FKTick()
	local kf = wf:KingOf(f)
	wf:Advance(FK0.DropTime + 0.01)
	check(wf:Hum(f).Health == 95 - PLAIN, "a PvP hit just before: plain hit", tostring(wf:Hum(f).Health))
	wf:Advance(C0.PvP.CombatTagTime + 1)
	wf:Strike(kf, f)
	check(wf:Hum(f).Health == 0, "the fight is over: the next King hit is the one hit")
	wf:Die(f)
	check(#wf.FirstKOs == 1 and wf:KOFx(f).First == true and wf.Data[k2].Honor == honor2, "then the lossless first KO (no PvP credit)",
		show(wf:KOFx(f)))
	-- the attacker side of a fight counts too (combat tag)
	local wa = fkWorld()
	local a = wa:Hunter(405, "Halo")
	local h = wa:Join(406, "Horns", { Level = 3 })
	wa:Hit(h, a, 5)
	wa:RunSpawned()
	wa:FKTick()
	wa:Advance(FK0.DropTime + 0.01)
	check(wa:Hum(a).Health == 100 - PLAIN, "the attacker of a PvP fight: plain hit", tostring(wa:Hum(a).Health))
	-- the stake comes between the lethal hit and the Died event: the claim says no, the normal pipeline runs
	local wl = fkWorld()
	local l = wl:Hunter(407, "Horns", { Carried = 4000 })
	wl:Meet(l)
	check(wl:Hum(l).Health == 0 and wl.FK.GetUp(l) ~= nil, "setup: the first KO waits for its Died event")
	wl.PvP.DebugSetStars(l, 1)
	check(wl.FK.GetUp(l) == nil, "at stake now: no first-KO delay at the Died event")
	wl:Die(l)
	check(#wl.FirstKOs == 0 and wl:KOFx(l).First == nil and wl.Data[l].FirstKODone == false and wl.PvP.GetStars(l) == 0
		and wl.Data[l].CarriedGold < 4000, "the claim says no: a normal wanted KO (the stars and a pouch share go)",
		show({ wl.Data[l].CarriedGold, wl:KOFx(l) }))
	-- a check that throws counts as at stake (no lossless KO when unsure)
	local wt = fkWorld()
	local t = wt:Hunter(408, "Horns")
	wt.Registry.GrudgeService = { HasSack = function() error("offline sack boom") end }
	wt:FKTick()
	wt:Advance(FK0.DropTime + 0.01)
	check(wt:Hum(t).Health == 100 - PLAIN, "a failing stake check: plain hit", tostring(wt:Hum(t).Health))
	-- each other check that throws counts as at stake too: a plain hit, no first-KO delay, and no claim when it starts
	-- failing between the one hit and the Died event
	local function proxy(real, key, fn) return setmetatable({ [key] = fn }, { __index = real }) end
	local function throwing(name, install)
		local ws = fkWorld()
		local s = ws:Hunter(410, "Horns")
		install(ws)
		ws:FKTick()
		ws:Advance(FK0.DropTime + 0.01)
		check(ws:Hum(s).Health == 100 - PLAIN and ws.FK.GetUp(s) == nil, "a failing " .. name .. " check: plain hit, no first KO waiting",
			tostring(ws:Hum(s).Health))
		local wc = fkWorld()
		local c = wc:Hunter(411, "Horns")
		wc:Meet(c)
		local waiting = wc:Hum(c).Health == 0 and wc.FK.GetUp(c) ~= nil
		install(wc)
		check(waiting and wc.FK.GetUp(c) == nil and wc.FK.ClaimKO(c, wc.Clock) == nil and wc.Data[c].FirstKODone == false and #wc.FirstKOs == 0,
			"a failing " .. name .. " check at the Died event: no first-KO delay, no claim", tostring(waiting))
	end
	throwing("stars", function(ws) ws.Registry.PvPService = proxy(ws.Registry.PvPService, "GetStars", function() error("offline stars boom") end) end)
	throwing("combat tag", function(ws)
		ws.Registry.CombatService = proxy(ws.Registry.CombatService, "IsInCombat", function() error("offline tag boom") end)
	end)
	throwing("kaiju", function(ws) ws.Registry.KaijuService = proxy(ws.Registry.KaijuService, "GetState", function() error("offline kaiju boom") end) end)
end)

------------------------------------------------------------------ 6. once per account; the Tell row; never for others
runGroup("once and only mine", function()
	local w = fkWorld()
	local p = w:Hunter(101, "Halo")
	local other = w:Hunter(102, "Halo", { Step = STEP + 1, Pos = MEADOW + vec(2, 0, -FK0.SpawnDistance) })
	local mate = w:Hunter(103, "Halo", { Pos = MEADOW + vec(-2, 0, -FK0.SpawnDistance) })
	w:FKTick()
	local mine = w:KingOf(p)
	local matesKing = w:KingOf(mate)
	check(mine ~= nil and matesKing ~= nil and mine ~= matesKing and w:KingOf(other) == nil,
		"each player on the KO row has an own King; a player off it none")
	w:Advance(FK0.DropTime + 0.01)
	check(w:Hum(other).Health == 100, "my King's landing never hits a bystander (off the row)")
	check(w:Hum(p).Health == 0 and w:Hum(mate).Health == 0, "each King lands on its own owner")
	-- my King's hit on someone else: its plain damage only
	local w2 = fkWorld()
	local a = w2:Hunter(104, "Halo")
	local b = w2:Hunter(105, "Halo")
	w2:FKTick()
	w2:Strike(w2:KingOf(a), b)
	check(w2:Hum(b).Health == 100 - PLAIN, "my King hitting another player on the KO row: plain damage", tostring(w2:Hum(b).Health))
	-- the quest moved on after the KO: no King, nothing told again
	local w3 = fkWorld()
	local s = w3:Hunter(106, "Halo")
	w3:Meet(s)
	w3:Die(s)
	check(#w3.FirstKOs == 1 and w3.StepOf[s] == STEP + 1 and w3.Data[s].FirstKODone == true, "the first KO; the quest moved on")
	w3:Hum(s).Health = 100 -- got up
	w3:FKTick(FK0.SpawnGap + 0.1)
	check(w3:KingOf(s) == nil and #w3.Spawns == 1 and #w3:EventsOf(s) == 1, "the rows after the KO: no King, nothing told again")
	-- the quest did not move (an Event that got lost): told again after SpawnGap, never a second one-hit King
	local wq = fkWorld()
	local sq = wq:Hunter(109, "Halo")
	wq.EventStuck = true
	wq:Meet(sq)
	wq:Die(sq)
	wq:Hum(sq).Health = 100
	wq:FKTick(0.1)
	check(wq.FK.StageOf(sq) == "Tell" and wq:KingOf(sq) == nil and #wq:EventsOf(sq) == 1, "stuck on the KO row: no King, not told at once",
		show(#wq:EventsOf(sq)))
	wq:FKTick(FK0.SpawnGap + 0.1)
	local told = wq:EventsOf(sq)
	check(#told == 2 and told[2].Name == "FirstKO" and told[2].Info.Beaten == nil and wq:KingOf(sq) == nil,
		"told again after SpawnGap (Event FirstKO, no King)", show(#told))
	wq:FKTick(0.5)
	wq:FKTick(0.5)
	check(#wq:EventsOf(sq) == 2, "not again before the next SpawnGap (no tell every tick)", show(#wq:EventsOf(sq)))
	wq.EventStuck = false
	wq:FKTick(FK0.SpawnGap + 0.1)
	check(wq.StepOf[sq] == STEP + 1 and wq.FK.StageOf(sq) == nil and #wq:EventsOf(sq) == 3 and #wq.Spawns == 1, "then it moves on",
		tostring(wq.StepOf[sq]))
	-- a Lv OneHitBelow player on the KO row: the quest is told (never stuck), no King
	local wl = fkWorld()
	local sl = wl:Hunter(110, "Halo", { Level = FK0.OneHitBelow })
	wl:FKTick()
	check(#wl.Spawns == 0 and wl.StepOf[sl] == STEP + 1 and #wl:EventsOf(sl) == 1, "too strong for the one hit: the row passes, no King")
	-- a second KO is a normal KO
	w3.Combat.DamagePlayer(s, 1000, nil, false, "SlimeKing")
	w3:Die(s)
	check(#w3.FirstKOs == 1 and w3:KOFx(s).First == nil and w3:CountKOFx(s) == 2, "a second KO is a normal KO (no signal, no First)",
		show(w3:KOFx(s)))
	-- a slime KO while on the KO row is not the first KO
	local w5 = fkWorld()
	local s5 = w5:Hunter(108, "Halo")
	w5.Combat.DamagePlayer(s5, 1000, nil, false, "Slime")
	w5:Die(s5)
	check(#w5.FirstKOs == 0 and #w5:EventsOf(s5) == 0 and w5:KOFx(s5).First == nil and w5.Data[s5].FirstKODone == false,
		"another monster's KO is never the first KO")
	-- the death long after the lethal hit (ClaimGrace) is a normal death
	local w6 = fkWorld()
	local s6 = w6:Hunter(107, "Halo")
	w6:Meet(s6)
	w6:Advance(FK0.ClaimGrace + 0.5)
	w6:Die(s6)
	check(#w6.FirstKOs == 0 and w6:KOFx(s6).First == nil and #w6:EventsOf(s6) == 0, "a Died event later than ClaimGrace: not claimed")
	check(C0.Data.Defaults.FirstKODone == false and w3.Data[s].FirstKODone == true, "the flag is saved data (a rejoin keeps it)")
end)

------------------------------------------------------------------ 7. the get-up near the fall, hurt
runGroup("get-up", function()
	local w = fkWorld()
	local p = w:Hunter(101, "Halo")
	local rec = w:Meet(p)
	local from = rec.Root.Position
	w:Die(p)
	local up = w.FK.GetUp(p)
	local at = up and up.CFrame and up.CFrame.Args[1]
	local look = up and up.CFrame and up.CFrame.Args[2]
	local fell = MEADOW
	local away = vec(fell.X - from.X, 0, fell.Z - from.Z).Unit
	local want = vec(fell.X + away.X * FK0.GetUp.Back, 1 + FK0.GetUp.Lift, fell.Z + away.Z * FK0.GetUp.Back)
	check(up and up.Delay == FK0.RespawnIn and up.CFrame and up.CFrame.Ctor == "lookAt", "a held get-up: delay + CFrame", show(up))
	check(at and near(at.X, want.X, 1e-3) and near(at.Y, want.Y, 1e-3) and near(at.Z, want.Z, 1e-3),
		"Back studs from where it fell, away from the King, Lift above the ground", show({ at, want }))
	check(look and (look - at).Magnitude > 0.5 and near(((look - at).Unit).Z, -away.Z, 1e-3), "facing where the King was")
	check(C0.ZoneAt(at).Id == "SlimeMeadow" and (at - fell).Magnitude < FK0.GetUp.Back + FK0.GetUp.Lift + 1,
		"in the meadow, right by the fall (not the town spawn)", show(at))
	-- A23-113 ①: a King that leapt ON the player: away from where it leapt from (DropFrom), not from its body
	local wd = fkWorld()
	local pd = wd:Hunter(109, "Halo")
	wd:FKTick()
	local rd = wd:KingOf(pd)
	rd.Model.Attrs.DropFrom = MEADOW + vec(12, 0, 0)
	wd:Advance(FK0.DropTime + 0.01)
	wd:Die(pd)
	local upd = wd.FK.GetUp(pd)
	local atd = upd and upd.CFrame and upd.CFrame.Args[1]
	check(atd and near(atd.X, MEADOW.X - FK0.GetUp.Back, 1e-3) and near(atd.Z, MEADOW.Z, 1e-3),
		"a leaping King: gets up Back studs away from its DropFrom", show(atd))
	-- water at the Back spot: right where it fell
	local w2 = fkWorld()
	local q = w2:Hunter(102, "Halo")
	local r2 = w2:Meet(q)
	local away2 = vec(MEADOW.X - r2.Root.Position.X, 0, MEADOW.Z - r2.Root.Position.Z).Unit
	local bx, bz = MEADOW.X + away2.X * FK0.GetUp.Back, MEADOW.Z + away2.Z * FK0.GetUp.Back
	w2.Ground[math.floor(bx + 0.5) .. ":" .. math.floor(bz + 0.5)] = "water"
	w2:Die(q)
	local at2 = w2.FK.GetUp(q).CFrame.Args[1]
	check(near(at2.X, MEADOW.X, 1e-3) and near(at2.Z, MEADOW.Z, 1e-3), "water behind: gets up where it fell", show(at2))
	-- the ground there lies in a town: the normal spawn
	local wtn = fkWorld()
	local stn = wtn:Hunter(106, "Halo")
	wtn:Meet(stn)
	wtn.GroundInTown = true
	wtn:Die(stn)
	check(C0.ZoneAt(vec(0, 0, 0)).Town == true and wtn.FK.GetUp(stn) and wtn.FK.GetUp(stn).CFrame == nil, "never a get-up in a town")
	-- a bare place (no ground hit): flat ground
	local w3 = fkWorld()
	w3.NoGround = true
	local s3 = w3:Hunter(103, "Halo")
	w3:Meet(s3)
	w3:Die(s3)
	check(w3.FK.GetUp(s3).CFrame.Args[1].Y == FK0.GetUp.Lift, "no ground hit: the flat floor (Y 0) + Lift")
	-- nowhere to stand: the normal spawn (no CFrame), the delay stays
	local w4 = fkWorld()
	local s4 = w4:Hunter(104, "Halo")
	local r4 = w4:Meet(s4)
	local away4 = vec(MEADOW.X - r4.Root.Position.X, 0, MEADOW.Z - r4.Root.Position.Z).Unit
	w4.Ground[math.floor(MEADOW.X + away4.X * FK0.GetUp.Back + 0.5) .. ":" .. math.floor(MEADOW.Z + away4.Z * FK0.GetUp.Back + 0.5)] = "water"
	w4.Ground[math.floor(MEADOW.X + 0.5) .. ":" .. math.floor(MEADOW.Z + 0.5)] = "water"
	w4:Die(s4)
	local up4 = w4.FK.GetUp(s4)
	check(up4 and up4.Delay == FK0.RespawnIn and up4.CFrame == nil, "no dry ground: the normal spawn after the same delay", show(up4))
	-- the get-up spawn: GetUp.HealthFrac of MaxHealth, once; a cosmetic swap keeps both the spot and the HP
	local hum = w:Hum(p)
	hum.Health, hum.MaxHealth = 150, 150 -- the new character, full
	w.PS.CharacterSpawned:Fire(p, p.Character, hum, true)
	check(w.FK.GetUp(p) ~= nil and hum.Health == 150, "a cosmetic swap keeps the get-up and the HP")
	w.PS.CharacterSpawned:Fire(p, p.Character, hum, false)
	local frac = math.max(1, math.floor(150 * FK0.GetUp.HealthFrac + 0.5))
	check(w.FK.GetUp(p) == nil and hum.Health == frac, "the get-up spawn: HealthFrac of MaxHealth (no loss: gold / XP stay)",
		show({ hum.Health, frac }))
	hum.Health = 150
	w.PS.CharacterSpawned:Fire(p, p.Character, hum, false)
	check(hum.Health == 150, "only once: the next spawn is a normal one", tostring(hum.Health))
	-- never a heal: a character that comes in lower stays lower
	local h2 = w2:Hum(q)
	h2.Health, h2.MaxHealth = 20, 150
	w2.PS.CharacterSpawned:Fire(q, q.Character, h2, false)
	check(h2.Health == 20, "the get-up never heals", tostring(h2.Health))
	-- a normal KO's spawn: untouched
	local wn = fkWorld()
	local sn = wn:Hunter(107, "Halo", { Step = STEP + 1 })
	wn.Combat.DamagePlayer(sn, 1000, nil, false, "Slime")
	wn:Die(sn)
	local hn = wn:Hum(sn)
	hn.Health = 100
	wn.PS.CharacterSpawned:Fire(sn, sn.Character, hn, false)
	check(hn.Health == 100, "a normal KO's spawn: full HP as before")
	-- kept at most Keep s
	local w5 = fkWorld()
	local s5 = w5:Hunter(105, "Halo")
	w5:Meet(s5)
	w5:Die(s5)
	w5:Advance(FK0.GetUp.Keep + 1)
	check(w5.FK.GetUp(s5) == nil, "an unused get-up expires after Keep s")
end)

------------------------------------------------------------------ 8. PlayerService: the respawn uses the get-up (real code cut out)
runGroup("player service", function()
	local w = fkWorld({ Edit = function(c) c.FirstKOKing.RespawnIn = 2 end })
	local loads, ready = {}, {}
	local PS = { CharacterDied = w.Util.Signal.new() }
	local zoneCF = { __kind = "CFrame", Ctor = "zone" }
	local api = execute("PlayerService.getup", PLAYER_GETUP_EXTRACT, w:Env(), w.Config, w.Util, w.Registry, ready, {}, PS,
		function(name, err) table.insert(w.Warnings, tostring(name) .. ": " .. tostring(err)) end,
		function(pl) table.insert(loads, { P = pl, At = w.Clock }) end,
		function() return zoneCF end, function() return "SlimeMeadow" end, function() return false end)
	local function bind(pl)
		local hum = w:Hum(pl)
		hum.Died = { Once = function(_, fn) hum.OnDied = fn end }
		ready[pl] = true
		api.Bind(pl, pl.Character, hum)
		return hum
	end
	-- the first KO: died -> the get-up delay (2) not RespawnTime (3), then the spot
	local p = w:Hunter(101, "Halo")
	local hum = bind(p)
	w:FKTick()
	w:Advance(FK0.DropTime + 0.01)
	local t0 = w.Clock
	hum.OnDied()
	w:Die(p) -- the death pipeline claims it (PS.CharacterDied above is the cut-out signal)
	w:Advance(1.9)
	check(#loads == 0, "not up before the first KO's delay")
	w:Advance(0.2)
	check(#loads == 1 and near(loads[1].At - t0, 2.1, 1e-6), "up after RespawnIn (2 s here)", loads[1] and tostring(loads[1].At - t0))
	local spot = api.SpawnSpot(p)
	check(spot ~= zoneCF and spot.Ctor == "lookAt", "spawnSpot = the held get-up", show(spot and spot.Ctor))
	-- the onCharacterAdded line: no context -> spawnSpot
	local pivoted = nil
	local character = { PivotTo = function(_, cf) pivoted = cf end }
	execute("PlayerService.pivot", PLAYER_PIVOT_EXTRACT, w:Env(), character, nil, p, hum, nil,
		function() return "cosmetic" end, api.SpawnSpot)
	check(pivoted == spot, "the respawn stands at spawnSpot")
	local ctx = {}
	execute("PlayerService.pivot", PLAYER_PIVOT_EXTRACT, w:Env(), character, ctx, p, hum, nil,
		function() return "cosmetic" end, api.SpawnSpot)
	check(pivoted == "cosmetic", "a cosmetic swap keeps its own pivot")
	-- a normal KO: RespawnTime and the zone spawn
	local q = w:Hunter(102, "Halo", { Step = STEP + 1 })
	local hq = bind(q)
	w.Combat.DamagePlayer(q, 1000, nil, false, "Slime")
	local t1 = w.Clock
	hq.OnDied()
	w:Die(q)
	w:Advance(2.5)
	check(#loads == 1, "a normal KO waits RespawnTime")
	w:Advance(0.6)
	check(#loads == 2 and loads[2].P == q and near(loads[2].At - t1, 3.1, 1e-6), "up after RespawnTime (3 s)", loads[2] and tostring(loads[2].At - t1))
	check(api.SpawnSpot(q) == zoneCF, "spawnSpot = the zone spawn")
	-- no FirstKOService in the registry (or it throws): the normal respawn
	w.Registry.FirstKOService = nil
	check(api.GetUp(p) == nil and api.SpawnSpot(p) == zoneCF, "no service: nothing held")
	w.Registry.FirstKOService = { GetUp = function() error("offline boom") end }
	w.AllowWarn = "offline boom"
	check(api.GetUp(p) == nil and api.SpawnSpot(p) == zoneCF, "a throwing service: nothing held (warned)")
end)

------------------------------------------------------------------ 9. the retry King: about 2 potions, a normal personal kill
-- the fight model: the King's drop hits at t = 0, its first leap FirstLeapAfter + Warn s later, then every acd s
-- (A23-113 ①: the player never steps out of a circle here - dodging only helps), the player deals its basic-attack DPS x
-- uptime, the faction regen heals every RegenTick (HealPlayer rounds), a potion heals HPRecovery of MaxHealth with
-- PotionCooldown, drunk when HP <= drink x MaxHealth
local function roundDamage(x) return math.max(1, math.floor(x + 0.5)) end -- Util.RoundDamage (HealPlayer)

local function fight(maxHP, kingHP, hit, dps, regen, potions, uptime, acd, drink)
	local V, CB = C0.Vitals, C0.Combat
	local hp, king, t, ready, left = maxHP, kingHP, 0, -math.huge, potions
	-- A23-113 ①: t = 0 is the drop from the sky, which hits (the player stands in its circle); then a leap lands every acd s
	local nextHit, nextRegen = 0, CB.RegenTick
	local dt = 0.02
	while t < 600 do
		t += dt
		king -= dps * uptime * dt
		if king <= 0 then return true, hp / maxHP, t end
		if t >= nextRegen then
			nextRegen += CB.RegenTick
			if regen > 0 and hp < maxHP then hp = math.min(maxHP, hp + roundDamage(maxHP * regen * CB.RegenTick)) end
		end
		if t >= nextHit then
			-- after the drop: its first leap lands FirstLeapAfter + Warn s later, then one every acd s
			nextHit = (nextHit == 0) and (FK0.FirstLeapAfter + C0.BossLeap.Kinds[FK0.Kind].Warn) or (nextHit + acd)
			hp -= hit
			if hp <= 0 then return false, 0, t end
		end
		if left > 0 and hp <= maxHP * drink and t >= ready then
			hp = math.min(maxHP, hp + maxHP * V.HPRecovery)
			ready, left = t + V.PotionCooldown, left - 1
		end
	end
	return false, hp / maxHP, t
end

runGroup("retry numbers", function()
	local w = fkWorld()
	check(w.Util.RoundDamage(2.5) == roundDamage(2.5) and w.Util.RoundDamage(0.2) == roundDamage(0.2), "the model rounds like Util.RoundDamage")
	local R = FK0.Retry
	-- one HP potion is the lesson (KO1 may leave only one): every class x faction x Lv 1-9 x tier 1-3 x +0 / +3 / +5
	local fails = { A = {}, B = {}, C = {}, N = 0, Slow = 0 }
	local minLeft1, minLeft2, minShort = math.huge, math.huge, math.huge
	for _, cls in { "Warrior", "Mage", "Archer" } do
		for _, fac in { "Halo", "Horns", "Neutral" } do
			for lv = 1, 9 do
				for tier = 1, 3 do
					for _, enh in { 0, 3, 5 } do
						fails.N += 1
						local r = C0.FirstKORetry(lv, tier, cls, fac, enh)
						local prof = C0.AttackProfile(cls, tier, fac)
						local f = C0.Factions[fac]
						local per = w.Util.RoundDamage(C0.WeaponDamage(tier, lv, enh) * prof.Damage * (1 + f.DamageBonus) * C0.BasicSkill.SwingImmediate)
						local dps = per / prof.SwingInterval
						local maxHP = C0.MaxHealth(lv, fac, cls)
						local hit = w.Util.RoundDamage(maxHP * r.Hit)
						local tag = cls .. "/" .. fac .. "/Lv" .. lv .. "/T" .. tier .. "+" .. enh
						-- A: no potion loses at 60-80% uptime against a King every 1.5 s, at 60-70% against one every 1.6 s
						for _, case in { { 0.6, 1.5 }, { 0.7, 1.5 }, { 0.8, 1.5 }, { 0.6, 1.6 }, { 0.7, 1.6 } } do
							local u, acd = case[1], case[2]
							local won, _, t = fight(maxHP, r.HP, hit, dps, f.RegenPerSec, 0, u, acd, 0.5)
							if won then table.insert(fails.A, tag .. " u" .. u .. " acd" .. acd) else minShort = math.min(minShort, r.HP / (dps * u) - t) end
						end
						if fight(maxHP, r.HP, hit, dps, f.RegenPerSec, 0, 0.8, 1.6, 0.5) then fails.Slow += 1 end
						-- B: ONE potion wins at 80-110% uptime whenever drunk at 40-60% HP (King every 1.5 s), >= 5% HP left
						for _, u in { 0.8, 0.9, 1.0, 1.1 } do
							for _, drink in { 0.4, 0.5, 0.6 } do
								local won, left = fight(maxHP, r.HP, hit, dps, f.RegenPerSec, 1, u, 1.5, drink)
								if not won or left < 0.05 then table.insert(fails.B, tag .. " u" .. u .. " d" .. drink .. " left" .. string.format("%.2f", left)) end
								if won then minLeft1 = math.min(minLeft1, left) end
							end
						end
						-- C: 2 potions win comfortably at 70-110% uptime (>= 15% HP left)
						for _, u in { 0.7, 0.8, 0.9, 1.0, 1.1 } do
							for _, drink in { 0.4, 0.5, 0.6 } do
								local won, left = fight(maxHP, r.HP, hit, dps, f.RegenPerSec, 2, u, 1.5, drink)
								if not won or left < 0.15 then table.insert(fails.C, tag .. " u" .. u .. " d" .. drink .. " left" .. string.format("%.2f", left)) end
								if won then minLeft2 = math.min(minLeft2, left) end
							end
						end
					end
				end
			end
		end
	end
	check(#fails.A == 0, "0 potions loses: 60-80% uptime (King every 1.5 s) and 60-70% (every 1.6 s), every class / faction / Lv 1-9 / tier 1-3 / +0 +3 +5",
		fails.A[1])
	check(fails.Slow <= fails.N * 0.05, "0 potions at 80% uptime against a slower King (1.6 s): wins for <= 5% of the builds", tostring(fails.Slow))
	check(#fails.B == 0, "1 potion wins: 80-110% uptime, drunk at 40-60% HP, >= 5% HP left", fails.B[1])
	check(#fails.C == 0, "2 potions win comfortably: 70-110% uptime, >= 15% HP left", fails.C[1])
	finding(string.format("retry sweep: %d builds; no potion falls >= %.2f s short (%d no-potion wins at 80%% vs a 1.6 s King); 1 potion leaves >= %.0f%% HP; 2 potions >= %.0f%%",
		fails.N, minShort, fails.Slow, minLeft1 * 100, minLeft2 * 100))
	-- the HP formula against a hand-made example: Lv 3 Halo Warrior, wooden weapon
	local ex = C0.FirstKORetry(3, 1, "Warrior", "Halo", 0)
	local per = w.Util.RoundDamage(8 * (1 + 0.02 * 2) * 1.0 * 1 * 0.5)
	check(ex.HP == math.floor(R.Seconds * per / 1.0 + 0.5) and near(ex.Hit, R.HitPct + 0.02 * C0.Monsters.AttackCooldown),
		"FirstKORetry(Lv3 Halo Warrior T1) = Seconds x 4 dmg/s, HitPct + regen x 1.5", show(ex))
	local bare = C0.FirstKORetry(1, 0, "Archer", "Horns", 0)
	local punch = w.Util.RoundDamage(C0.Combat.Unarmed.Damage * 1.15 * 0.5)
	check(bare.HP == math.max(R.MinHP, math.floor(R.Seconds * punch / C0.Combat.Unarmed.Interval + 0.5)) and near(bare.Hit, R.HitPct),
		"bare hands: the punch (no class); Horns (no regen): HitPct", show(bare))
	local tiny = C0.FirstKORetry(1, 0, "Archer", "Neutral", 0)
	check(tiny.HP >= R.MinHP, "never under MinHP", show(tiny))
	finding(string.format("Lv3 Halo Warrior T1: MaxHP %d, King HP %d, King hit %d (%.1f%%)", C0.MaxHealth(3, "Halo", "Warrior"), ex.HP,
		w.Util.RoundDamage(C0.MaxHealth(3, "Halo", "Warrior") * ex.Hit), ex.Hit * 100))

	-- the HP comes from the best weapon the save may use (Lv 4: tier 2, not the owned tier 3 of Lv 5) with its +3, not the
	-- weapon in hand (tier 1): a swap to a weak weapon never shrinks the King
	local pe = w:Hunter(105, "Halo", { Step = RETRY, Level = 4, Class = "Warrior", Tier = 1,
		Data = { WeaponOwnedMask = 7, WeaponEnhance = { 0, 3, 5 } } })
	w:FKTick()
	local re = w:KingOf(pe)
	local best3 = C0.FirstKORetry(4, 2, "Warrior", "Halo", 3)
	check(best3.HP ~= C0.FirstKORetry(4, 2, "Warrior", "Halo", 0).HP and best3.HP ~= C0.FirstKORetry(4, 1, "Warrior", "Halo", 0).HP
		and best3.HP ~= C0.FirstKORetry(4, 3, "Warrior", "Halo", 5).HP, "setup: the tier, its +N and the level rule each change the King's HP",
		show(best3))
	check(re ~= nil and pe:GetAttribute("WeaponTier") == 1 and re.MaxHP == best3.HP,
		"the retry King's HP: the best usable weapon (tier 2) with its +3, not the weapon in hand (tier 1)", show({ re and re.MaxHP, best3.HP }))
	-- the service spawns the retry King with those numbers and hits with them
	local p = w:Hunter(101, "Horns", { Step = RETRY, Level = 4, Class = "Mage", Tier = 2, Done = true })
	w:FKTick()
	local rec = w:KingOf(p)
	local s = w.Spawns[#w.Spawns]
	local want = C0.FirstKORetry(4, 2, "Mage", "Horns", 0)
	check(rec and rec.MaxHP == want.HP and rec.Model.Attrs.FirstKO == "Retry", "the retry King's HP = FirstKORetry of the player",
		show({ rec and rec.MaxHP, want.HP }))
	check(s.Opts.Quiet == nil and type(s.Opts.OnKilled) == "function" and s.Opts.Practice == R.PayAs and type(s.Opts.Strike) == "function"
		and s.Opts.Near == true and s.Opts.Hold == FK0.DropTime + FK0.FirstLeapAfter and s.Opts.LeapGrow == nil
		and rec.Quiet == nil and rec.Practice == R.PayAs,
		"a normal (not quiet) practice personal King: Practice = Retry.PayAs, the strike / kill hooks, Near, Hold",
		show({ s.Opts.Practice, rec.Practice }))
	w:Advance(FK0.DropTime + 0.01)
	local hit1 = w.Util.RoundDamage(100 * want.Hit)
	check(w:Hum(p).Health == 100 - hit1, "A23-113: the retry King's drop hits inside its circle like a leap (Hit x MaxHealth)",
		tostring(w:Hum(p).Health))
	w:Strike(rec, p)
	check(w:Hum(p).Health == 100 - 2 * hit1, "its hit = Hit x MaxHealth", tostring(w:Hum(p).Health))
	w:Strike(rec, p, 2)
	check(w:Hum(p).Health == 100 - 2 * hit1 - w.Util.RoundDamage(100 * want.Hit * 2), "a landing's mult: Hit x MaxHealth x mult",
		tostring(w:Hum(p).Health))
	-- its kill: the real killRecord - one Personal MonsterKilled with Practice (two hits are enough: a personal monster)
	w:KillKing(rec, { Hits = 2 })
	local k = w.Killed[#w.Killed]
	check(#w.Killed == 1 and k.P == p and k.Info.Kind == FK0.Kind and k.Info.ZoneId == FK0.Zone and k.Info.Personal == true
		and k.Info.Practice == true and k.Info.WarPoints == 0, "its kill: MonsterKilled(owner, { Kind SlimeKing, ZoneId SlimeMeadow, Personal, Practice })",
		k and show({ k.Info.Kind, k.Info.ZoneId, k.Info.Personal, k.Info.Practice }))
	local pay = C0.MonsterTypes[R.PayAs]
	check(k and k.Info.XP == pay.XP and k.Info.Gold == pay.Gold, "it pays the PayAs kind's XP / gold", k and show({ k.Info.XP, k.Info.Gold }))
	check(#w:EventsOf(p) == 0 and w.Pops == 1 and #w.Beaten == 1 and w.Beaten[1].P == p and w.Beaten[1].Retry == true,
		"then KingBeaten(player, true); no FirstKO report; one death pop", show(w.Beaten[1] and w.Beaten[1].Retry))
	-- the quest counted it (the double: done) -> no new King
	w.StepOf[p] = nil
	local n = #w.Spawns
	w:FKTick(FK0.SpawnGap + 0.1)
	check(#w.Spawns == n, "the quest is done: no new King", tostring(#w.Spawns))
	-- the rematch kill did not move the quest (a stuck row): no second rematch King in this session (no farm)
	local q2 = w:Hunter(104, "Halo", { Step = RETRY })
	w:FKTick()
	w:KillKing(w:KingOf(q2))
	local n2 = #w.Spawns
	for _ = 1, 3 do w:FKTick(FK0.SpawnGap + 0.1) end
	check(#w.Spawns == n2 and w.FK.StageOf(q2) == "Retry", "a stuck rematch row: no second King (no farm)", tostring(#w.Spawns - n2))
	w.StepOf[q2] = RETRY - 1 -- the row changes (here: back a step)
	w:FKTick()
	w.StepOf[q2] = RETRY
	w:FKTick(FK0.SpawnGap + 0.1)
	check(#w.Spawns == n2 + 1 and w:KingOf(q2) ~= nil, "once the row changed, the rematch King may come again", tostring(#w.Spawns - n2))
	-- a retry KO is a normal KO
	local q = w:Hunter(102, "Horns", { Step = RETRY })
	w:FKTick()
	local rq = w:KingOf(q)
	for _ = 1, 30 do
		if w:Hum(q).Health > 0 then w:Strike(rq, q) end
	end
	w:Die(q)
	check(w:KOFx(q) and w:KOFx(q).First == nil and #w.FirstKOs == 0 and #w:EventsOf(q) == 0, "a KO by the retry King is a normal KO", show(w:KOFx(q)))
	w:FKTick()
	check(not rq.Alive and w.Removed[#w.Removed].Rec == rq, "the retry King leaves when its owner falls (a retry starts fresh)")
	-- the first King killed anyway: the row still counts (Event FirstKO, Beaten), no MonsterKilled
	local s3 = w:Hunter(103, "Halo")
	w:FKTick()
	local killed = #w.Killed
	w:KillKing(w:KingOf(s3))
	local ev = w:EventsOf(s3)
	check(#ev == 1 and ev[1].Name == "FirstKO" and ev[1].Info.Beaten == true and ev[1].Info.Kind == "SlimeKing" and #w.Killed == killed,
		"the first King killed anyway: Event FirstKO { Beaten = true }, no MonsterKilled", show(ev[1] and ev[1].Info))
	check(w.StepOf[s3] == STEP + 1 and #w.FirstKOs == 0 and w.Data[s3].FirstKODone == false and w.Beaten[#w.Beaten].P == s3
		and w.Beaten[#w.Beaten].Retry == false, "the quest moved on; it was no KO; KingBeaten(player, false)")
end)

------------------------------------------------------------------ 10. MonsterService pieces (real code cut out) + the field King
runGroup("monster service", function()
	local w = fkWorld()
	local p = w:Hunter(101, "Halo", { Step = false })
	local warnings = {}
	local function warnT(_, m) table.insert(warnings, tostring(m)) end
	-- landAttack: a strike hook deals the hit; without one (the field King) Def.Damage with the kind
	local dealt = {}
	local S2 = { CombatService = { DamagePlayer = function(t, n, a, c, kind) table.insert(dealt, { T = t, N = n, A = a, Kind = kind }) return n end } }
	local FACE = { Cos = function() return 1 end, HitCos = 0.8, MaxExtra = 0.3, Active = {}, Recheck = 0.05, Keep = 0.6 }
	local records = {}
	local land = execute("MonsterService.landAttack", MON_LAND_EXTRACT, w:Env(), records, C0.Monsters,
		{ WINDUP_LEEWAY = 2 }, FACE, -3, "AttackSeq", S2, w.Config, w.Util, function() return false end, function() return true end, warnT)
	local function monsterRec(id, owner, strikeFn)
		local model = newInstance("Model", w)
		model.Parent = newInstance("Folder", w)
		local root = newInstance("Part", w)
		root.Position, root.Parent = MEADOW + vec(0, 0, -3), model
		local rec = { Id = id, Kind = "SlimeKing", Def = C0.MonsterTypes.SlimeKing, Alive = true, Model = model, Root = root,
			Owner = owner, _strike = strikeFn, _windup = {} }
		records[id] = rec
		return rec
	end
	local struck = {}
	local mine = monsterRec(1, p, function(rec, target) table.insert(struck, { Rec = rec, T = target }) end)
	land(mine, mine._windup, p, 0)
	check(#struck == 1 and struck[1].T == p and #dealt == 0 and mine.Model.Attrs.AttackSeq == 1,
		"a landed hit of a record with a strike hook goes to the hook (not Def.Damage)", show({ #struck, #dealt }))
	local field = monsterRec(2, nil, nil)
	land(field, field._windup, p, 0)
	check(#dealt == 1 and dealt[1].N == PLAIN and dealt[1].Kind == "SlimeKing" and dealt[1].A == nil,
		"the field King (no hook) deals its own Damage with its kind", dealt[1] and show({ dealt[1].N, dealt[1].Kind }))
	local boom = monsterRec(3, p, function() error("offline strike boom") end)
	land(boom, boom._windup, p, 0)
	check(#warnings == 1 and string.find(warnings[1], "offline strike boom", 1, true) ~= nil and #dealt == 1,
		"a throwing hook is warned, no fallback damage", warnings[1])
	table.remove(warnings, 1) -- (checked; the killRecord checks below count their own)
	-- spawnMonster's record fields: only a personal monster can be quiet / hooked / practice
	local function fields(owner, opts, kind) return execute("MonsterService.fields", MON_FIELDS_EXTRACT, w:Env(), owner, opts, kind or "SlimeKing", w.Config) end
	local f1 = fields(p, { Quiet = true, Strike = print, OnKilled = warn })
	local f2 = fields(nil, { Quiet = true, Strike = print, OnKilled = warn, Practice = "BigSlime" })
	local f3 = fields(p, { Quiet = "yes", Strike = "x" })
	check(f1.Quiet == true and f1._strike == print and f1._onKilled == warn and f1.Practice == nil, "a personal record keeps Quiet / Strike / OnKilled")
	check(f2.Quiet == nil and f2._strike == nil and f2._onKilled == nil and f2.Practice == nil, "a zone / event monster never")
	check(f3.Quiet == nil and f3._strike == nil, "only true / functions count")
	check(fields(p, { Practice = "BigSlime" }).Practice == "BigSlime" and fields(p, { Practice = true }).Practice == "SlimeKing"
		and fields(p, { Practice = "Nope" }).Practice == "SlimeKing" and fields(p, { Practice = false }).Practice == nil
		and fields(p, {}).Practice == nil, "Practice = a monster kind (true / unknown: its own kind), only when asked")
	-- killRecord: quiet = no MonsterKilled, the hook; practice = Practice + the PayAs pay; the field King pays its contributors
	local MS = { MonsterKilled = w.Util.Signal.new() }
	local paid, calls = {}, { Pop = 0, Ref = 0, Respawn = 0 }
	MS.MonsterKilled:Connect(function(pl, info) table.insert(paid, { P = pl, Info = info }) end)
	local kill = execute("MonsterService.killRecord", MON_KILL_EXTRACT, w:Env(), {}, w.Config, C0.Monsters, MS,
		function() return "Halo" end, function() end, function() calls.Pop += 1 end, function() calls.Ref += 1 end,
		function() calls.Respawn += 1 end, warnT)
	local function deadRec(owner, o4)
		o4 = o4 or {}
		local root = newInstance("Part", w)
		root.Position, root.Parent = MEADOW, newInstance("Folder", w)
		return { Id = 9, Kind = "SlimeKing", Def = C0.MonsterTypes.SlimeKing, ZoneId = "SlimeMeadow", Alive = true, HP = 1, MaxHP = 2500,
			Golden = false, Root = root, Home = MEADOW, Owner = owner, Quiet = o4.Quiet, Event = o4.Event, _onKilled = o4.OnKilled,
			Practice = o4.Practice, _contributors = { [p] = w.Clock }, _hits = { [p] = o4.Hits or 5 }, _dmg = { [p] = 2500 } }
	end
	local told = {}
	local q = deadRec(p, { Quiet = true, OnKilled = function(rec) table.insert(told, rec) end })
	kill(q)
	check(#paid == 0 and #told == 1 and told[1] == q and calls.Pop == 1 and calls.Ref == 1 and calls.Respawn == 0 and q.Alive == false,
		"a quiet King: no MonsterKilled, its service told once, the death pop, out of the owner's set, no respawn", show(calls))
	check(next(q._contributors) == nil and next(q._dmg) == nil, "its contributors are cleared")
	kill(deadRec(nil, { Event = true }))
	local K = C0.MonsterTypes.SlimeKing
	check(#paid == 1 and paid[1].P == p and paid[1].Info.Personal == false and paid[1].Info.Practice == nil and paid[1].Info.XP == K.XP
		and calls.Respawn == 0, "the field King: paid to its contributor as before (not personal, no respawn)", show(paid[1] and paid[1].Info.XP))
	kill(deadRec(p))
	check(#paid == 2 and paid[2].Info.Personal == true and paid[2].Info.Practice == nil and paid[2].Info.XP == K.XP,
		"a personal monster without Quiet / Practice still fires MonsterKilled (Personal) with its own pay")
	-- the rematch King (personal, practice, hooked) killed with ONE hit: paid / counted, then its service told
	local order = {}
	MS.MonsterKilled:Connect(function() table.insert(order, "killed") end)
	kill(deadRec(p, { Practice = "BigSlime", Hits = 1, OnKilled = function() table.insert(order, "told") end }))
	local pr = paid[3]
	check(#paid == 3 and pr.Info.Practice == true and pr.Info.Personal == true and pr.Info.Kind == "SlimeKing" and pr.Info.ZoneId == "SlimeMeadow"
		and pr.Info.XP == C0.MonsterTypes.BigSlime.XP and pr.Info.Gold == C0.MonsterTypes.BigSlime.Gold and pr.Info.WarPoints == 0,
		"a practice King (one hit): Personal + Practice, still a SlimeKing in SlimeMeadow, the Slime Prince's XP / gold, no war points",
		pr and show({ pr.Info.XP, pr.Info.Gold, pr.Info.Practice }))
	check(order[1] == "killed" and order[2] == "told" and #order == 2, "MonsterKilled first (the quest's Kill row), then its service", show(order))
	check(K.RewardMinHits == 3, "setup: the King's RewardMinHits is 3")
	kill(deadRec(p, { Hits = 1 }))
	check(#paid == 4, "a personal King with fewer than RewardMinHits hits still pays its owner (only the owner can hit it)")
	kill(deadRec(nil, { Event = true, Hits = K.RewardMinHits - 1 }))
	check(#paid == 4, "the field King still needs RewardMinHits own hits (A23-27)")
	kill(deadRec(p, { OnKilled = function() error("offline onKilled boom") end }))
	check(#paid == 5 and #warnings == 1 and string.find(warnings[1], "offline onKilled boom", 1, true) ~= nil,
		"a throwing hook after a loud kill: warned, the kill already paid", warnings[1])
	-- SpawnPersonal: the record as a second result, the hooks passed on, Distance, reuse
	local made = {}
	local personal = {}
	local folder = newInstance("Folder", w)
	local api = execute("MonsterService.personal", MON_PERSONAL_EXTRACT, w:Env(), w.Config, w.Util, personal, 8, 120,
		function(x, z) return vec(x, 0, z), false end, function() return 0, false end,
		function(kind, opts)
			local m = newInstance("Model", w)
			m.Parent = folder
			local rec = { Kind = kind, Alive = true, Model = m, Opts = opts, Owner = opts.Owner,
				Quiet = (opts.Owner ~= nil and opts.Quiet == true) or nil } -- (spawnMonster's record field)
			table.insert(made, rec)
			return rec
		end,
		function(rec, fade, leaving) rec.Alive = false; rec.Gone = { Fade = fade, Leaving = leaving } end, warnT)
	local strikeFn, killedFn = function() end, function() end
	local model, rec = api.SpawnPersonal(p, "SlimeKing", { HP = 77, Quiet = true, Strike = strikeFn, OnKilled = killedFn, Distance = 12 })
	check(rec and model == rec.Model and rec.Opts.Owner == p and rec.Opts.HP == 77 and rec.Opts.Quiet == true
		and rec.Opts.Strike == strikeFn and rec.Opts.OnKilled == killedFn, "SpawnPersonal -> model, record; the hooks passed on",
		show(rec and rec.Opts.HP))
	check(rec and near(rec.Opts.Position.Z, MEADOW.Z - 12) and near(rec.Opts.Position.X, MEADOW.X), "opts.Distance studs in front",
		show(rec and rec.Opts.Position))
	local model2, rec2 = api.SpawnPersonal(p, "SlimeKing", {})
	check(model2 == model and rec2 == rec and #made == 1, "one living personal King per player: the same model + record")
	rec.Alive = false
	local _, rec3 = api.SpawnPersonal(p, "SlimeKing", { Distance = 500, Practice = "BigSlime" })
	check(rec3 and rec3 ~= rec and near(rec3.Opts.Position.Z, MEADOW.Z - 8) and rec3.Opts.Quiet == false and rec3.Opts.Practice == "BigSlime",
		"a bad Distance: the default 8; no Quiet unless asked; Practice passed on", show(rec3 and rec3.Opts.Position))
	-- Hold = s before its first swing (capped), none = untouched; a quiet King's lifetime end goes home
	local _, rh = api.SpawnPersonal(w:Hunter(102, "Halo", { Step = false }), "SlimeKing", { Quiet = true, Hold = 1.2 })
	check(rh and type(rh._nextAttackAt) == "number" and near(rh._nextAttackAt, w.Clock + 1.2),
		"Hold: its first swing waits for the landing", show(rh and rh._nextAttackAt))
	local _, rc = api.SpawnPersonal(w:Hunter(103, "Halo", { Step = false }), "SlimeKing", { Hold = 50 })
	check(rc and type(rc._nextAttackAt) == "number" and near(rc._nextAttackAt, w.Clock + 10), "Hold is capped at 10 s",
		show(rc and rc._nextAttackAt))
	local _, rn = api.SpawnPersonal(w:Hunter(104, "Halo", { Step = false }), "SlimeKing", { Hold = 0 / 0 })
	check(rn and rn._nextAttackAt == nil, "no / bad Hold: untouched")
	-- Near = by the player or nothing (never the home-zone spot); A23-129 (검수 2026-10-11): the town spot goes through
	-- groundPoint with the body too, so here only that spot is walkable
	local made2 = {}
	local home = w.Config.Zones[w.Config.HomeZoneId("Halo")].Spawn
	local api2 = execute("MonsterService.personal", MON_PERSONAL_EXTRACT, w:Env(), w.Config, w.Util, {}, 8, 120,
		function(x, z)
			if math.abs(x - home.X) < 0.01 and math.abs(z - (home.Z - 8)) < 0.01 then return vec(x, 0, z), false end
			return nil, false
		end, function() return 0, false end,
		function(kind, opts)
			local m = newInstance("Model", w)
			m.Parent = folder
			local r = { Kind = kind, Alive = true, Model = m, Opts = opts, Owner = opts.Owner }
			table.insert(made2, r)
			return r
		end,
		function() end, warnT)
	local nm, nr = api2.SpawnPersonal(p, "SlimeKing", { Near = true })
	check(nm == nil and nr == nil and #made2 == 0, "Near + no ground by the player: nothing", show(#made2))
	local fm = api2.SpawnPersonal(p, "SlimeKing", {})
	check(fm ~= nil and #made2 == 1, "without Near: the home-zone fallback (its spot is walkable here)", show(#made2))
	-- RemovePersonal / GroundAt
	check(api.RemovePersonal(rec3, true, true) == true and rec3.Gone and rec3.Gone.Leaving == true and rec3.Gone.Fade == true,
		"RemovePersonal: a living personal monster leaves (fade, leaving)")
	check(api.RemovePersonal(rec3, true, true) == false, "not twice")
	check(api.RemovePersonal({ Alive = true, Event = true }, true, true) == false and api.RemovePersonal(nil) == false,
		"never a zone / event monster (the field King)")
	local g, noHit = api.GroundAt(3, 4)
	check(g and g.X == 3 and g.Z == 4 and noHit == false, "GroundAt = the monsters' groundPoint")
	local g2, n2 = api.GroundAt(0 / 0, 1)
	check(g2 == nil and n2 == false and api.GroundAt("x", 1) == nil, "GroundAt: bad numbers -> nil")
	w:Advance(121)
	check(rh.Gone and rh.Gone.Fade == true and rh.Gone.Leaving == true, "a quiet King's lifetime end: it goes home (no splat)",
		show(rh.Gone))
	check(rn.Gone and rn.Gone.Fade == true and rn.Gone.Leaving == false, "any other personal monster: as before", show(rn.Gone))
	w.AllowWarn = { "offline strike boom", "offline onKilled boom" }
	check(#warnings == 1, "no other warnings", warnings[2])
end)

------------------------------------------------------------------ 11. the practice kill: no boss credit anywhere
runGroup("no boss credit", function()
	-- gameplay plan 2026-10-13 1-A #10: the finisher card ships off (Kinds = {}); this group turns the card's window on, so the
	-- practice kill's "no card" is still told apart from the control's card
	local w = fkWorld({ Edit = function(c) c.Finisher.Kinds = { SlimeKing = true, CaptainClatter = true } end })
	local items = function(p) return deepCopy(w.Data[p].Items or {}) end
	local p = w:Hunter(101, "Halo", { Step = RETRY })
	w:FKTick()
	local rec = w:KingOf(p)
	local before, fx0 = items(p), #w.Fx
	w:KillKing(rec, { Hits = 5, Manual = true })
	check(#w.Killed == 1 and w.Killed[1].Info.Practice == true and w.Killed[1].Info.Manual == true, "setup: a manual practice King kill")
	check(#fxOf(w, "FinisherCard", p, fx0) == 0, "FinisherService: no King finisher card", show(fxOf(w, "FinisherCard", p, fx0)[1]))
	local after = items(p)
	check(#fxOf(w, "Loot", p, fx0) == 0 and after.SlimeCore == before.SlimeCore and after.Jelly == before.Jelly
		and after.Enh70 == before.Enh70, "LootService: no boss drops (cores, jelly, scrolls, potions)", show(after))
	check((w.EventSpawns or 0) == 0 and #fxOf(w, "KingDefeat", nil, fx0) == 0, "no field-boss defeat: no KingDefeat fx")
	-- control: the same personal King without Practice (the old way): a card and the boss drops
	local q = w:Hunter(102, "Halo", { Step = false })
	local _, ctl = w.Registry.MonsterService.SpawnPersonal(q, "SlimeKing", { HP = 100 })
	local qb, fq = items(q), #w.Fx
	w:KillKing(ctl, { Hits = 5, Manual = true })
	local qa = items(q)
	check(#fxOf(w, "FinisherCard", q, fq) == 1, "control: a non-practice King kill offers the finisher card")
	check((qa.SlimeCore or 0) > (qb.SlimeCore or 0) and #fxOf(w, "Loot", q, fq) == 1, "control: ... and rolls the King's drops", show(qa))
	-- QuestService's daily jobs (the real kill handler cut out)
	local progress = {}
	local qkill = execute("QuestService.onMonsterKilled", QUEST_KILL_EXTRACT, w:Env(), function() return {} end, function() return 99 end,
		function() return 3 end, function() return 1 end, function(_, id) table.insert(progress, id) end, 2, 1, "SlimeMeadow", {},
		function() end, function() end, w.Config)
	qkill(p, w.Killed[1].Info)
	check(#progress == 0, "QuestService: a practice kill counts for no daily job (not even 'Slime Prince x3')", show(progress))
	qkill(q, w.Killed[2].Info)
	check(#progress == 1 and progress[1] == "Kill", "control: another personal King kill counts", show(progress))
	check(w.Killed[1].Info.WarPoints == 0 and w.Killed[1].Info.Personal == true, "no war points (a personal kill)")
end)

------------------------------------------------------------------ 12. the quest KO1 with the real StoryQuestService
runGroup("quest KO1", function()
	local DEF = C0.StoryQuests.Defs[FQ.Quest]
	-- reports every Event row between `from` and `to` (exclusive) the way the shop / quick slot / drink hooks do
	local function passRows(w, p, from, to)
		local steps = w.Config.StoryQuests.Defs[FQ.Quest].Steps
		for st = from + 1, to - 1 do
			local obj = steps[st].Obj
			check(obj.Type == "Event" and w.Config.StoryQuests.Events[obj.Name] == true, "setup: the rows between are Event rows", tostring(st))
			w.Story.Event(p, obj.Name, {})
			w:FKTick()
			check(w:KingOf(p) == nil or w.Story.CurrentStep(p, FQ.Quest) == w.Config.FirstKO.RematchStep,
				"no King on the rows between the KO and the rematch", tostring(st))
		end
	end
	local function play(w, p, label)
		local rematch = w.Config.FirstKO.RematchStep
		local d = w.Data[p]
		check(w.Story.CurrentStep(p, FQ.Quest) == STEP and w.FK.StageOf(p) == "First", label .. ": KO1 started at its KO row: the first King",
			show({ w.Story.CurrentStep(p, FQ.Quest), w.FK.StageOf(p) }))
		local gold0, xp0, lv0 = (d.CarriedGold or 0) + (d.BankGold or 0), d.XP, d.Level
		local rec = w:Meet(p)
		check(rec and rec.Quiet == true and w:Hum(p).Health == 0, label .. ": the King lands: one-hit KO")
		w:Die(p)
		local ko = w:KOFx(p)
		check(ko and ko.First == true and #w.FirstKOs == 1 and d.FirstKODone == true, label .. ": the short lossless KO screen", show(ko))
		check(w.Story.CurrentStep(p, FQ.Quest) == STEP + 1 and d.Story.First.FirstKO == true,
			label .. ": the KO moved KO1 to its next row (StoryQuestService.Event FirstKO)", tostring(w.Story.CurrentStep(p, FQ.Quest)))
		check((d.CarriedGold or 0) + (d.BankGold or 0) >= gold0 and d.XP == xp0 and d.Level == lv0, label .. ": nothing lost (the row's top-up may add gold)",
			show({ d.CarriedGold, d.BankGold, gold0 }))
		local hum = w:Hum(p)
		hum.Health = hum.MaxHealth -- the new character
		w.PS.CharacterSpawned:Fire(p, p.Character, hum, false)
		check(hum.Health == math.max(1, math.floor(hum.MaxHealth * FK0.GetUp.HealthFrac + 0.5)), label .. ": gets up hurt (a potion to buy and drink)",
			tostring(hum.Health))
		w:FKTick(FK0.SpawnGap + 0.1)
		passRows(w, p, STEP, rematch)
		check(w.Story.CurrentStep(p, FQ.Quest) == rematch, label .. ": the shop / drink rows passed: the rematch row", tostring(w.Story.CurrentStep(p, FQ.Quest)))
		w:FKTick(FK0.SpawnGap + 0.1)
		local king = w:KingOf(p)
		check(king and king.Quiet == nil and king.Practice == FK0.Retry.PayAs and king.Model.Attrs.FirstKO == "Retry",
			label .. ": the retry King (not quiet, a practice King)", king and show({ king.Quiet, king.Practice }))
		local items0, fx0, xpN = deepCopy(d.Items or {}), #w.Fx, #w.XP
		local bank0 = d.BankGold or 0
		w:KillKing(king, { Hits = 2, Manual = true }) -- two hits: below the King's RewardMinHits, still the owner's kill
		check(d.Story.Done[FQ.Quest] == true and w.Story.CurrentStep(p, FQ.Quest) == nil, label .. ": its kill finishes KO1 (the Personal Kill row counted it)",
			show({ d.Story.Done[FQ.Quest], w.Story.CurrentStep(p, FQ.Quest) }))
		local it = d.Items or {}
		check((d.BankGold or 0) > bank0 and #w.XP == xpN + 1 and (it.Enh70 or 0) == (items0.Enh70 or 0) + (DEF.Reward.N or 1),
			label .. ": the quest pays its reward (gold, XP, the scroll)", show({ d.BankGold, bank0, it.Enh70 }))
		check(#fxOf(w, "FinisherCard", p, fx0) == 0 and #fxOf(w, "Loot", p, fx0) == 0 and (it.SlimeCore or 0) == (items0.SlimeCore or 0)
			and (it.Jelly or 0) == (items0.Jelly or 0), label .. ": no finisher card, no boss drops", show(it))
		w:FKTick(FK0.SpawnGap + 0.1)
		check(w:KingOf(p) == nil and w.FK.StageOf(p) == nil, label .. ": quest done: no more Kings")
	end
	local w = fkWorld({ Story = true })
	play(w, w:Hunter(201, "Halo", { Level = 4 }), "KO1")
	-- game dev 3 adds a row before the rematch (RematchStep + 1): everything follows Config.FirstKO
	local wx = fkWorld({ Story = true, Edit = function(c)
		local steps = c.StoryQuests.Defs[c.FirstKO.Quest].Steps
		table.insert(steps, c.FirstKO.RematchStep, { Text = "Drink a potion from your quick slot", ShortName = "Drink potion",
			Obj = { Type = "Event", Name = "PotionUsed" } })
		c.FirstKO.RematchStep += 1
	end })
	local px = wx:Hunter(202, "Horns", { Level = 6 })
	check(wx.Config.FirstKO.RematchStep == RETRY + 1 and wx.Config.StoryQuests.Defs[FQ.Quest].Steps[RETRY].Obj.Type == "Event",
		"setup: an extra row before the rematch")
	play(wx, px, "KO1 + a row")
	-- an account that already had its KO starts KO1 again (a rejoin before the row moved): the row is told, no King
	local wt = fkWorld({ Story = true })
	local pt = wt:Hunter(203, "Halo", { Level = 4, Done = true })
	check(wt.Story.CurrentStep(pt, FQ.Quest) == STEP and wt.FK.StageOf(pt) == "Tell", "setup: KO1 at its KO row, the KO already had")
	wt:FKTick()
	check(#wt.Spawns == 0 and wt.Story.CurrentStep(pt, FQ.Quest) == STEP + 1, "the KO already had: the row passes at the next check (no King)",
		tostring(wt.Story.CurrentStep(pt, FQ.Quest)))
end)

------------------------------------------------------------------ 13. Main, leaving, the Studio aid
runGroup("main and lifecycle", function()
	local function list(name)
		local s = string.find(MAIN_SOURCE, "local " .. name .. " = {", 1, true)
		local e = s and string.find(MAIN_SOURCE, "\n}", s, true)
		return s and string.sub(MAIN_SOURCE, s, e) or ""
	end
	local init, start = list("INIT_ORDER"), list("START_ORDER")
	check(string.find(init, "\"FirstKOService\"", 1, true) ~= nil, "FirstKOService in Main INIT_ORDER")
	local at, ps = string.find(start, "\"FirstKOService\"", 1, true), string.find(start, "\"PlayerService\"", 1, true)
	check(at ~= nil and ps ~= nil and at < ps, "FirstKOService in START_ORDER before PlayerService")
	check(string.find(MAIN_SOURCE, "key == \"FirstKO\" then", 1, true) ~= nil, "DebugCommand FirstKO")
	-- leaving forgets everything (MonsterService removes the King itself)
	local w = fkWorld()
	local p = w:Hunter(101, "Halo")
	w:Meet(p)
	w:Leave(p)
	check(w.FK.GetUp(p) == nil and w.FK.ClaimKO(p, w.Clock) == nil, "a leaver: no pending KO, no get-up")
	w:FKTick()
	check(#w.Spawns == 1, "no King for a leaver")
	-- Debug: Studio only
	check(w.FK.Debug(w:Hunter(102, "Halo"), "first") == "Studio only", "Debug outside Studio refused")
	local ws = fkWorld({ Studio = true, Edit = function(c) c.FirstKO.Quest = nil end })
	local s = ws:Hunter(103, "Halo")
	check(ws.FK.StageOf(s) == nil and ws.FK.Debug(s, "first") == "forced first" and ws.FK.StageOf(s) == "First",
		"Studio Debug 'first': the first King without the quest")
	ws:Meet(s)
	ws:Die(s)
	check(#ws.FirstKOs == 1 and ws.FK.StageOf(s) == "Retry", "after it: the retry King (forced first, KO had)")
	check(ws.FK.Debug(s, "reset") == "FirstKODone = false" and ws.Data[s].FirstKODone == false and ws.FK.StageOf(s) == "First",
		"Debug 'reset': the first KO again")
	check(ws.FK.Debug(s, "retry") == "forced retry" and ws.FK.StageOf(s) == "Retry", "Debug 'retry': the retry King without the quest")
	check(ws.FK.Debug(s, "off") == "off" and ws.FK.StageOf(s) == nil, "Debug 'off': back to the quest")
end)

finish()
