-- dev2_world.luau : the full server world shared by the 게임성 개발 2 suites that drive real services together
-- (tools/dev2_offline.py puts it after tools/fixtures/dev2_kit.luau and before the suite fixture). Needs the bindings
-- CONFIG_SOURCE, UTIL_SOURCE, RANKING_SOURCE, ANNOUNCE_SOURCE, PVP_SOURCE, GRUDGE_SOURCE, TITLE_SOURCE, LOOT_SOURCE,
-- COMBAT_SOURCE, PROGRESSION_SOURCE, KAIJU_SOURCE, PLAYER_FAME_SOURCE (and NAMETAG_SOURCE for the nametag group).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local R0 = C0.Ranking
local MON62 = 1791126000 -- 2026-10-05 00:00 KST (Monday): the first second of week 2962
local MID62 = 1791342000 -- 2026-10-07 12:00 KST (Wednesday), week 2962
local MON63 = 1791730800 -- 2026-10-12 00:00 KST: week 2963
local SET = "DataStoreRequestType.SetIncrementSortedAsync"
local SORTED = "DataStoreRequestType.GetSortedAsync"

local function storeName(season, board, week) return "HH_Rank_" .. season .. "_" .. board .. "_W" .. week end
-- saved results as RankingService stamps them (a season on every result)
local function OUT(wk, season) return { WeekId = wk, Season = season or "PRE" } end
local function RR(wk, board, rank, season) return { WeekId = wk, Season = season or "PRE", Board = board, Rank = rank } end

------------------------------------------------------------------ the server world
-- opts: Time, Clock, Studio (default false = the PRE season), Memory (DataService memory mode), PrivateServerId,
-- Stores (shared = another server), Budget, Friends, FriendError, EditConfig, Progression (load the real
-- ProgressionService for GetXPMult), PvPLoop (step PvPService's 1 s loop by hand: w:PvPTick)
local function rankWorld(opts)
	opts = opts or {}
	local w = newWorld({ Time = opts.Time or MID62, Clock = opts.Clock or 5000, Studio = opts.Studio == true,
		PrivateServerId = opts.PrivateServerId, EditConfig = opts.EditConfig, Budget = opts.Budget,
		Friends = opts.Friends, FriendError = opts.FriendError, Stores = opts.Stores })
	local cfg = w.Config
	local Signal = w.Util.Signal
	w.Data, w.Gold, w.Label = {}, {}, { Text = "" }
	local data = w.Data
	local mirrored = {}
	for _, key in cfg.Data.Mirrored do mirrored[key] = true end

	-- PlayerService double + the REAL GrantFame / MarkActive / GetLastActive / GetLastOwnActive
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new(), CharacterSpawned = Signal.new(),
		CharacterDied = Signal.new() }
	function ps.GetData(p) return data[p] end
	function ps.IsReady(p) return w.Ready[p] == true and p.Parent ~= nil end
	function ps.GetReadyPlayers()
		local out = {}
		for _, p in w.PlayerList do
			if w.Ready[p] and p.Parent ~= nil then table.insert(out, p) end
		end
		return out
	end
	function ps.SetStat(p, key, value)
		local d = data[p]
		if not d then return end
		d[key] = value
		if mirrored[key] then p:SetAttribute(key, value) end
	end
	function ps.AddStat(p, key, delta)
		local d = data[p]
		if not d then return 0 end
		local v = (tonumber(d[key]) or 0) + delta
		ps.SetStat(p, key, v)
		return v
	end
	function ps.IsShuttingDown() return w.Closing == true end
	function ps.Respawn() end
	function ps.RefreshCharacter() end
	local reg = { PlayerService = ps }
	w.Registry, w.PS = reg, ps
	execute("PlayerService.fame", PLAYER_FAME_SOURCE, w:Env(), ps, reg, w.Ready,
		function(name, err) table.insert(w.Warnings, "PlayerService " .. tostring(name) .. ": " .. tostring(err)) end)

	reg.DataService = { IsMemoryMode = function() return opts.Memory == true end }
	reg.FactionService = { FactionChanged = Signal.new(),
		GetFaction = function(p)
			local f = p:GetAttribute("Faction")
			return type(f) == "string" and f or "None"
		end,
		GetPerks = function(p) return cfg.Factions[p:GetAttribute("Faction") or "None"] or cfg.Factions.None end }
	reg.JusticeService = {
		GetBullyStacks = function(p) return tonumber(p:GetAttribute("BullyStacks")) or 0 end,
		GetCombatPower = function(p) return tonumber(p:GetAttribute("Power")) or 1000 end,
		AddBullyStack = function(p)
			local n = (tonumber(p:GetAttribute("BullyStacks")) or 0) + 1
			p:SetAttribute("BullyStacks", n)
			return n
		end,
		GetDamageMult = function() return 1 end,
	}
	reg.ClassService = { ClassChanged = Signal.new(), GetClass = function() return "Warrior" end,
		GetClassDef = function() return cfg.Classes.Warrior end }
	-- 빛 마을 점검 #42 / #41: w.InTown[p] = standing in a town; w.ZoneIdOf[p] = a Config.Zones id (GetZone, and the PvP
	-- answer follows that zone's PvP flag). Players without a ZoneIdOf keep the old answers (PvP unless w.PvPZone == false).
	w.InTown, w.ZoneIdOf = {}, {}
	reg.ZoneService = { IsPvPZone = function(p)
			local z = w.ZoneIdOf[p] and cfg.Zones[w.ZoneIdOf[p]]
			if z then return z.PvP == true end
			return w.PvPZone ~= false
		end,
		IsTown = function(p) return w.InTown[p] == true end,
		GetZone = function(p) return cfg.Zones[w.ZoneIdOf[p] or ""] or cfg.Zones.SlimeMeadow end,
		IsPlausible = function() return true end }
	reg.KaijuService = { GetState = function(p)
			local s = p:GetAttribute("KaijuState")
			return type(s) == "string" and s or "None"
		end,
		GetHealthMult = function() return 1 end, HandleKaijuDeath = function() end }
	reg.MapBuilder = { GetBoardLabel = function() return w.Label end }
	reg.ProgressionService = { Rebirthed = Signal.new(),
		-- gold moves through SetStat like the real ProgressionService (the mirrored attributes follow)
		AddCarriedGold = function(p, n, src)
			if data[p] then ps.SetStat(p, "CarriedGold", (data[p].CarriedGold or 0) + n) end
			table.insert(w.Gold, { P = p, N = n, Src = src })
		end,
		AddBankGold = function(p, n, src)
			if data[p] then ps.SetStat(p, "BankGold", (data[p].BankGold or 0) + n) end
			table.insert(w.Gold, { P = p, N = n, Src = src })
		end,
		TakeCarriedGold = function(p, n)
			local have = data[p] and data[p].CarriedGold or 0
			local t = math.min(have, n)
			if data[p] then ps.SetStat(p, "CarriedGold", have - t) end
			return t
		end }
	reg.MonsterService = { MonsterKilled = Signal.new(), GetMonstersInRadius = function() return {} end,
		DamageMonster = function() return false end, Shove = function() end }
	reg.ShopService = { CanBuyWeapon = function() return true end }
	reg.GooseService = { GetPosition = function() return nil end, RegisterHit = function() end }
	reg.VitalsService = { TrySpendMana = function() return true end }
	reg.WarService = { HasBlessing = function() return false end }
	reg.JusticeService.RefreshScale = function() end
	reg.WarService.AddFactionPoints = function() end

	-- the real services (Init in Main's INIT_ORDER order, Start in START_ORDER order)
	local function load(name, source, env)
		local m = env and execute(name, source, env) or w:Load(name, source)
		reg[name] = m
		return m
	end
	load("CombatService", COMBAT_SOURCE)
	local penv
	if opts.PvPLoop then
		-- PvPService's 1 s loop (protection expiry, star decay, graduation) is stepped by hand (w:PvPTick)
		penv = w:Env()
		penv.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = penv.task })
	end
	load("PvPService", PVP_SOURCE, penv)
	-- GrudgeService's 0.25 s loop is stepped by hand (w:GrudgeTick): its task.wait yields the loop coroutine
	local genv = w:Env()
	genv.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = genv.task })
	load("GrudgeService", GRUDGE_SOURCE, genv)
	local kenv
	if opts.Kaiju then
		-- the real KaijuService; its 0.25 s loop is stepped by hand (w:KaijuTick)
		kenv = w:Env()
		kenv.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = kenv.task })
		kenv.RaycastParams = { new = function() return {} end }
		load("KaijuService", KAIJU_SOURCE, kenv)
	end
	load("AnnounceService", ANNOUNCE_SOURCE)
	load("RankingService", RANKING_SOURCE)
	load("LootService", LOOT_SOURCE)
	load("TitleService", TITLE_SOURCE)
	for _, name in { "CombatService", "PvPService", "GrudgeService", "AnnounceService", "RankingService", "LootService",
		"TitleService" } do
		reg[name].Init(reg)
		if name == "GrudgeService" and opts.Kaiju then reg.KaijuService.Init(reg) end
	end
	reg.CombatService.Start()
	local p0 = #w.Spawned
	reg.PvPService.Start()
	local pvpLoop = nil
	if opts.PvPLoop then
		assert(#w.Spawned == p0 + 1, "PvPService.Start spawns one loop")
		pvpLoop = coroutine.create(w.Spawned[#w.Spawned][1])
	end
	local before = #w.Spawned
	reg.GrudgeService.Start()
	assert(#w.Spawned == before + 1, "GrudgeService.Start spawns one loop")
	local grudgeLoop = coroutine.create(w.Spawned[#w.Spawned][1])
	local kaijuLoop
	if opts.Kaiju then
		local n0 = #w.Spawned
		reg.KaijuService.Start()
		assert(#w.Spawned == n0 + 1, "KaijuService.Start spawns one loop")
		kaijuLoop = coroutine.create(w.Spawned[#w.Spawned][1])
	end
	for _, name in { "AnnounceService", "LootService", "TitleService", "RankingService" } do reg[name].Start() end
	w.Spawned = {} -- the services' own forever-loops never run here; the tests step the Tick functions directly
	assert(coroutine.resume(grudgeLoop))
	if kaijuLoop then assert(coroutine.resume(kaijuLoop)) end
	if pvpLoop then assert(coroutine.resume(pvpLoop)) end
	-- advance `seconds` (default 1) and run PvPService's loop once (opts.PvPLoop)
	function w:PvPTick(seconds)
		self:Advance(seconds or 1)
		local ok, err = coroutine.resume(assert(pvpLoop, "rankWorld { PvPLoop = true }"))
		assert(ok, err)
	end
	-- advance `seconds` and run the kaiju loop once
	function w:KaijuTick(seconds)
		self:Advance(seconds or 0.25)
		local ok, err = coroutine.resume(kaijuLoop, seconds or 0.25)
		assert(ok, err)
	end
	function w:GrudgeTick(dt)
		local ok, err = coroutine.resume(grudgeLoop, dt)
		assert(ok, err)
	end
	function w:GrudgeRun(seconds)
		for _ = 1, seconds do self:GrudgeTick(1) end
	end
	w.Ranking, w.PvP, w.Grudge, w.Loot, w.Combat, w.Title, w.Announce = reg.RankingService, reg.PvPService,
		reg.GrudgeService, reg.LootService, reg.CombatService, reg.TitleService, reg.AnnounceService

	if opts.Progression then
		-- GetXPMult only: its own signal stand-ins keep its join / kill handlers out of this world
		local preg = setmetatable({ MonsterService = { MonsterKilled = Signal.new() },
			PlayerService = setmetatable({ PlayerReady = Signal.new(), PlayerLeaving = Signal.new() }, { __index = ps }) },
			{ __index = reg })
		local prog = w:Load("ProgressionService", PROGRESSION_SOURCE)
		prog.Init(preg)
		w.Progression = prog
	end

	-- a character the services see as alive (Humanoid + HumanoidRootPart under a parented model)
	local stage = newInstance("Folder", w)
	function w:Body(p)
		local model = newInstance("Model", w)
		model.Name = p.Name
		local hum = newInstance("Humanoid", w)
		hum.Name, hum.Health, hum.MaxHealth = "Humanoid", 100, 100
		function hum.TakeDamage(self2, n) self2.Health = math.max(0, self2.Health - n) end
		function hum.GetState(self2) return self2.State or "HumanoidStateType.Running" end
		hum.Parent = model
		local root = newInstance("Part", w)
		root.Name, root.Position = "HumanoidRootPart", vec(0, 0, 0)
		root.Parent = model
		model.Parent = stage
		p.Character = model
		return model
	end
	-- a ready player. o: Power, AccountAge, Playtime, Level, Hide, Carried, Data (save fields), Saved (a whole saved
	-- record, e.g. from an earlier session), Attrs, Active (default true: an own action now), Body (default true)
	function w:Join(userId, faction, o)
		o = o or {}
		local p = self:NewPlayer(userId, {})
		p.AccountAge = o.AccountAge or 30
		local d = o.Saved or deepCopy(cfg.Data.Defaults)
		if not o.Saved then
			d.Faction = faction or "None"
			d.Level = o.Level or 20
			d.PlaytimeSeconds = o.Playtime or 20000
			d.HideAnnounceName = o.Hide == true
			d.ClassChosen = true
			d.CarriedGold = o.Carried or 0
			for k, v in o.Data or {} do d[k] = deepCopy(v) end
		end
		cfg.SanitizeRank(d, math.floor(self.Time)) -- what DataService.fillDefaults does at load
		data[p] = d
		for key in mirrored do
			if d[key] ~= nil then p:SetAttribute(key, d[key]) end
		end
		p:SetAttribute("Power", o.Power or 1000)
		for k, v in o.Attrs or {} do p:SetAttribute(k, v) end
		if o.Body ~= false then self:Body(p) end
		self.Ready[p] = true
		if o.Active ~= false then ps.MarkActive(p) end
		ps.PlayerReady:Fire(p, d)
		return p, d
	end
	function w:Leave(p)
		ps.PlayerLeaving:Fire(p, data[p])
		self.Ready[p] = nil
		self:Remove(p)
		self:Flush()
	end
	function w:SetFaction(p, f)
		local old = reg.FactionService.GetFaction(p)
		ps.SetStat(p, "Faction", f)
		reg.FactionService.FactionChanged:Fire(p, f, old, "Altar")
	end
	-- PvPService.HandleKO the way CombatService's death pipeline calls it: the friend answer is resolved first
	function w:KO(victim, killer, ctx)
		reg.RankingService.WarmFriends(killer, victim) -- what the hits before a KO start in the background
		self:RunSpawned() -- background jobs (that friend answer) finish first
		reg.RankingService.ResolveFriends(killer, victim)
		reg.PvPService.HandleKO(victim, killer, ctx)
	end
	function w:Hit(victim, attacker, amount) return reg.CombatService.DamagePlayer(victim, amount or 5, attacker) end
	-- the real death pipeline: CharacterDied -> (deferred) CombatService.runDeathPipeline -> GrudgeService / PvPService
	function w:Die(victim)
		self:RunSpawned() -- background jobs (the friend warm-up of earlier hits) finish first
		ps.CharacterDied:Fire(victim, victim.Character)
		self:Flush()
	end
	function w:Tick()
		local R = reg.RankingService
		for _, step in { R.TickWeek, R.TickWrite, R.TickRead, R.TickSettle } do step() end
	end
	function w:Rank(p) return data[p].Rank end
	function w:Calls(op, prefix)
		local out = {}
		for _, c in self.DSCalls do
			if c.Op == op and (prefix == nil or string.sub(c.Store, 1, #prefix) == prefix) then table.insert(out, c) end
		end
		return out
	end
	function w:Row(name, key)
		local s = self.Stores[name]
		return s and s.Rows[key]
	end
	function w:Seed(name, key, value) self.StoreOf(name, "Ordered").SetAsync(nil, key, value) end
	function w:LastRankings(p)
		for i = #self.Fired, 1, -1 do
			local f = self.Fired[i]
			if f.Remote == "Rankings" and f.Player == p then return f.Payload, i end
		end
		return nil, 0
	end
	function w:CountNotices(p, text)
		local n = 0
		for _, x in self.Notices do
			if x.Player == p and x.Text == text then n += 1 end
		end
		return n
	end
	-- one scripted kill: rows whose Item is in `want` draw 0 (drop), every other row 0.999999; the jackpot draw (Slime)
	-- is `jackpotDraw` or a miss
	function w:Drop(p, kind, want, jackpotDraw, golden)
		local script = {}
		for _, row in cfg.Loot.Tables[kind] do
			table.insert(script, (row.Item and want and want[row.Item]) and 0 or 0.999999)
		end
		if cfg.Loot.Jackpot.Monsters[kind] then table.insert(script, jackpotDraw or 0.999999) end
		self.Script = script
		reg.MonsterService.MonsterKilled:Fire(p, { Kind = kind, Golden = golden == true, Position = vec(0, 0, 0) })
		local left = #self.Script
		self.Script = nil
		return left
	end
	-- the UseItem remote with a scripted success draw (and a fail-drop draw)
	function w:Enhance(p, id, tier, success, dropOnFail)
		self:Advance(1) -- RateLimits.UseItem
		self.Script = success and { 0 } or { 0.999999, dropOnFail and 0 or 0.999999 }
		self.Remotes.UseItem.OnServerEvent:Fire(p, id, tier)
		self.Script = nil
	end
	return w
end

local function refused(w, reason) return w.Ranking.Stats.Refused[reason] or 0 end

-- a Halo knight K (101) and a Horns V (202): equal power, both acted just now, old accounts, the PRE season
local function duel(o)
	o = o or {}
	local w = rankWorld(o)
	local k = w:Join(101, o.KillerFaction or "Halo", { Power = o.KillerPower or 1000, Attrs = o.KillerAttrs })
	local v = w:Join(202, o.VictimFaction or "Horns", { Power = o.VictimPower or 1000, AccountAge = o.VictimAge,
		Playtime = o.VictimPlay, Carried = o.Carried, Attrs = o.VictimAttrs })
	w:RunSpawned() -- join-time background jobs (grudge mail, PvPService's A23-113 friend check of the pair)
	-- A23-113 ①: PvPService asked IsFriendsWith once at the join (its own cache); FriendCalls from here on counts only
	-- RankingService's calls (its board cache), as before
	w.JoinFriendCalls, w.FriendCalls = w.FriendCalls, 0
	return w, k, v
end

