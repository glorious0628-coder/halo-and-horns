-- dev3_world.luau : the 게임성 개발 3 (server session) world on top of tools/fixtures/dev2_kit.luau. tools/dev3_offline.py
-- (dev2_offline.Suite with world = this file) puts the suite's source bindings, the kit, this file and the suite fixture
-- together. Only the services a suite does not run from source are doubles here (PlayerService, ProgressionService,
-- LootService, MonetizationService, CombatService, ZoneService, StoryQuestService, QuestService, HalloweenService,
-- WarService, ...); every game module under test runs from the CURRENT src. Loops (task.spawn + task.wait) become
-- coroutines stepped by hand (w:StartLoops / w:Tick).

local function dev3World(o)
	o = o or {}
	local w = newWorld({ Studio = o.Studio, Friends = o.Friends, Time = o.Time, Clock = o.Clock, EditConfig = o.EditConfig,
		Stores = o.Stores, PrivateServerId = o.PrivateServerId })
	local Signal = w.Util.Signal
	local C = w.Config
	w.Data, w.Gold, w.XPs, w.Grants, w.Looks, w.Loops = {}, {}, {}, {}, {}, {}
	w.GoldMult, w.XPMult = o.GoldMult, o.XPMult -- nil = main's ProgressionService (returns nothing); 2 = an A23-75 2x pass
	local mirrored = {}
	for _, k in C.Data.Mirrored do mirrored[k] = true end

	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new(), CharacterDied = Signal.new(), Active = {} }
	function ps.GetData(p) return w.Data[p] end
	function ps.IsReady(p) return w.Ready[p] == true and p.Parent ~= nil end
	function ps.GetReadyPlayers()
		local out = {}
		for _, p in w.PlayerList do if w.Ready[p] and p.Parent ~= nil then table.insert(out, p) end end
		return out
	end
	function ps.SetStat(p, k, v)
		local d = w.Data[p]
		if not d then return end
		d[k] = v
		if mirrored[k] then p:SetAttribute(k, v) end
	end
	function ps.AddStat(p, k, dv)
		local d = w.Data[p]
		if not d then return 0 end
		local v = (tonumber(d[k]) or 0) + (tonumber(dv) or 0)
		ps.SetStat(p, k, v)
		return v
	end
	function ps.MarkActive(p) ps.Active[p] = w.Clock end
	function ps.GetLastOwnActive(p) return ps.Active[p] or 0 end
	function ps.GetLastActive(p) return ps.Active[p] or 0 end
	function ps.IsShuttingDown() return w.Closing == true end

	local prog = { GoldEarned = Signal.new(), GoldSpent = Signal.new(), LeveledUp = Signal.new(), Rebirthed = Signal.new() }
	function prog.AddBankGold(p, n, src)
		if w.GoldFails then error("offline gold failure") end
		local got = math.floor(n * (w.GoldMult or 1))
		table.insert(w.Gold, { P = p, N = n, Got = got, Src = src })
		ps.AddStat(p, "BankGold", got)
		prog.GoldEarned:Fire(p, got, src)
		if w.GoldMult then return got end
		return nil
	end
	prog.AddCarriedGold = prog.AddBankGold
	-- cap: at most this much after the pass (the real AddXP applies the cap after the 2x XP pass)
	function prog.AddXP(p, n, cap)
		local got = math.floor(n * (w.XPMult or 1))
		if cap ~= nil then got = math.min(got, math.max(0, math.floor(cap))) end
		table.insert(w.XPs, { P = p, N = n, Got = got })
		ps.AddStat(p, "XP", got)
		if w.XPMult then return got end
		return nil
	end
	function prog.GetTotalGold(p)
		local d = w.Data[p]
		return d and ((tonumber(d.CarriedGold) or 0) + (tonumber(d.BankGold) or 0)) or 0
	end

	local loot = { ItemsGranted = Signal.new(), Enhanced = Signal.new() }
	function loot.GrantItem(p, id, n, source) -- source: "Reward" = a reward (fits a full bag; Src on w.Grants)
		if w.LootFails then error("offline loot failure") end
		local d = w.Data[p]
		if not d or type(id) ~= "string" or n < 1 or n > 99 then return 0 end
		local key = C.PotionStockKey(id)
		if key then
			local have = tonumber(d[key]) or 0
			local give = math.clamp(n, 0, C.Vitals.PotionInventoryCap - have)
			if give > 0 then ps.SetStat(p, key, have + give) end
			table.insert(w.Grants, { P = p, Id = id, N = give, Src = source })
			return give
		end
		if not C.Loot.Items[id] then return 0 end
		d.Items = type(d.Items) == "table" and d.Items or {}
		local have = tonumber(d.Items[id]) or 0
		local give = math.clamp(n, 0, C.Loot.ItemCap - have)
		if give > 0 then d.Items[id] = have + give end
		table.insert(w.Grants, { P = p, Id = id, N = give, Src = source })
		return give
	end
	function loot.TakeItem(p, id, n)
		local d = w.Data[p]
		local have = d and type(d.Items) == "table" and tonumber(d.Items[id]) or 0
		if not d or have < n then return false end
		d.Items[id] = have - n
		return true
	end

	local mon = {}
	w.LookAsks = {}
	function mon.GrantLook(p, id)
		table.insert(w.LookAsks, id)
		local look = C.Looks and C.Looks[id]
		if not look or type(look.Unlock) ~= "table" then return false end
		local d = w.Data[p]
		d.Looks = type(d.Looks) == "table" and d.Looks or { Owned = {}, On = "" }
		if d.Looks.Owned[id] then return false end
		d.Looks.Owned[id] = w.Time
		table.insert(w.Looks, { P = p, Id = id })
		return true
	end

	w.Reg = { PlayerService = ps, ProgressionService = prog, LootService = loot, MonetizationService = mon,
		FactionService = { FactionChanged = Signal.new() }, ClassService = { ClassChanged = Signal.new() },
		CombatService = { KnockedOut = Signal.new(), MonsterHit = Signal.new(), Released = Signal.new(),
			PlayerDamaged = Signal.new(), InCombat = {} },
		ZoneService = { ZoneChanged = Signal.new(), Travels = {} },
		MonsterService = { MonsterKilled = Signal.new() },
		StoryQuestService = { QuestDone = Signal.new(), Picked = Signal.new() },
		WarService = { RoundEnded = Signal.new() },
		HalloweenService = { KingDefeated = Signal.new() },
		GooseService = { GooseFinished = Signal.new() },
		GrudgeService = { SackResolved = Signal.new(), Sacks = {} },
		SettingsService = { KeysChanged = Signal.new() },
		RankingService = { Viewed = Signal.new() },
		AnnounceService = {},
	}
	w.PS, w.Prog, w.Loot, w.Mon = ps, prog, loot, mon
	function w.Reg.CombatService.IsInCombat(p) return w.Reg.CombatService.InCombat[p] == true end
	function w.Reg.GrudgeService.HasSack(p) return w.Reg.GrudgeService.Sacks[p] == true end
	function w.Reg.ZoneService.GetZoneId(p) return p:GetAttribute("ZoneId") or "Crossroads" end
	-- ZoneService.Travel double: records the call; w.TravelAnswer = { ok, reason } (default ok)
	function w.Reg.ZoneService.Travel(p, dest, instant)
		table.insert(w.Reg.ZoneService.Travels, { P = p, Dest = dest, Instant = instant })
		local a = w.TravelAnswer or { true, nil }
		return a[1], a[2]
	end
	function w.Reg.AnnounceService.PublicName(p) return "Pub" .. p.UserId end

	-- a game module from source in this world; task.wait yields (loops are stepped by w:Tick)
	function w:Service(name, source)
		local env = self:Env()
		env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
		local m = execute(name, source, env)
		self.Reg[name] = m
		return m
	end
	function w:InitStart(names)
		for _, n in names do self.Reg[n].Init(self.Reg) end
		for _, n in names do self.Reg[n].Start() end
		self:StartLoops()
	end
	-- every queued task.spawn becomes a loop coroutine, resumed up to its first wait
	function w:StartLoops()
		local list = self.Spawned
		self.Spawned = {}
		for _, job in list do
			local co = coroutine.create(job[1])
			local ok, err = coroutine.resume(co, table.unpack(job, 2, job.n))
			assert(ok, err)
			table.insert(self.Loops, co)
		end
	end
	-- advance `seconds`, then one pass of every loop (each loop body runs once)
	function w:Tick(seconds)
		self:Advance(seconds or 0)
		for _, co in self.Loops do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				assert(ok, err)
			end
		end
		self:RunSpawned()
	end
	-- a ready player: data = a copy of the defaults + jo.Data (deep), attributes from the mirrored keys + jo.Attrs
	function w:Arrive(id, jo)
		jo = jo or {}
		local p = self:NewPlayer(id, {})
		if jo.Join ~= nil then
			local join = jo.Join
			function p.GetJoinData(_) return join end
		else
			function p.GetJoinData(_) return {} end
		end
		local d = deepCopy(C.Data.Defaults)
		for k, v in jo.Data or {} do d[k] = deepCopy(v) end
		self.Data[p] = d
		for _, key in C.Data.Mirrored do if d[key] ~= nil then p.Attrs[key] = d[key] end end
		for k, v in jo.Attrs or {} do p.Attrs[k] = v end
		self.Ready[p] = true
		ps.PlayerReady:Fire(p, d)
		self:RunSpawned()
		return p, d
	end
	function w:Leave(p)
		ps.PlayerLeaving:Fire(p, self.Data[p])
		self.Ready[p] = nil
		self:Remove(p)
	end
	-- a c->s remote call `gap` s after the last one (rate limits)
	function w:Remote(name, p, ...)
		self:Advance(self.Gap or 1.1)
		self.Net.Get(name).OnServerEvent:Fire(p, ...)
		self:RunSpawned()
	end
	function w:FxOf(kind, p)
		local out = {}
		for _, f in self.Fx do
			if f.Kind == kind and (p == nil or f.Player == p) then table.insert(out, f) end
		end
		return out
	end
	-- the KST day helpers (Config.DayIndex): start of today in os.time, and a jump to `n` days later + `extra` s
	function w:DayStart()
		return C.DayIndex(self.Time) * 86400 - C.Daily.TimezoneOffset
	end
	function w:ToDay(n, extra)
		local target = self:DayStart() + 86400 * n + (extra or 60)
		self:Advance(target - self.Time)
	end
	return w
end
