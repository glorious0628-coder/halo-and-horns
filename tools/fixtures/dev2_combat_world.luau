-- dev2_combat_world.luau : the combat server world shared by the 게임성 개발 2 suites that drive CombatService,
-- LootService, StoryQuestService (and PetService) together: tools/test_unarmed_start.py (A23-34) and
-- tools/test_tamer.py (A23-39). tools/dev2_offline.py puts it after tools/fixtures/dev2_kit.luau and before the suite
-- fixture. Needs the bindings CONFIG_SOURCE, UTIL_SOURCE, COMBAT_SOURCE, LOOT_SOURCE, STORY_SOURCE, SHOP_EXTRACT,
-- JUSTICE_EXTRACT; PET_SOURCE is optional (PetService is loaded when it is bound).
-- The world: the real CombatService (its auto-combat loop stepped by hand), LootService, StoryQuestService and
-- PetService on doubles of the other services; characters face -Z with a right / left hand; monsters are records with
-- a root.

------------------------------------------------------------------ vector helpers the target cone needs (Unit / Dot)
do
	local baseIndex = vmt.__index
	vmt.__index = function(v, key)
		if key == "Unit" then
			local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
			if m == 0 then return vec(0, 0, 0) end
			return vec(v.X / m, v.Y / m, v.Z / m)
		end
		if key == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
		return baseIndex(v, key)
	end
end

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local U = C0.Combat.Unarmed

------------------------------------------------------------------ the server world
-- o: Hit = true (the target picker treats every player as a valid PvP target)
local function bareWorld(o)
	o = o or {}
	local w = newWorld({ Time = 1791342000, Clock = 5000, EditConfig = function(c) c.Combat.CritChance = 0 end })
	local cfg = w.Config
	local Signal = w.Util.Signal
	w.Data, w.Mana, w.Damage, w.Announced, w.Monsters, w.Opened, w.Shoves = {}, {}, {}, {}, {}, {}, {}
	local data = w.Data
	local mirrored = {}
	for _, key in cfg.Data.Mirrored do mirrored[key] = true end

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
		local v = (tonumber(data[p] and data[p][key]) or 0) + delta
		ps.SetStat(p, key, v)
		return v
	end
	function ps.MarkActive() end
	function ps.GetLastActive() return w.Clock end
	local reg = { PlayerService = ps }
	w.Registry, w.PS = reg, ps
	reg.DataService = { IsMemoryMode = function() return false end }
	reg.FactionService = { FactionChanged = Signal.new(),
		GetFaction = function(p)
			local f = p:GetAttribute("Faction")
			return type(f) == "string" and f or "None"
		end,
		GetPerks = function(p) return cfg.Factions[p:GetAttribute("Faction") or "None"] or cfg.Factions.None end }
	reg.ClassService = { ClassChanged = Signal.new(),
		GetClass = function(p) return p:GetAttribute("Class") or "Warrior" end,
		GetClassDef = function(p) return cfg.Classes[p:GetAttribute("Class") or "Warrior"] or cfg.Classes.Warrior end }
	local J = execute("JusticeService.extract", JUSTICE_EXTRACT, w:Env(), cfg)
	reg.JusticeService = { GetDamageMult = function() return 1 end, GetCombatPower = J.GetCombatPower }
	w.Justice = J
	reg.ZoneService = { IsPlausible = function() return true end, GetZoneId = function() return "SlimeMeadow" end,
		IsPvPZone = function() return true end, IsTown = function() return false end }
	reg.KaijuService = { GetState = function() return "None" end, GetHealthMult = function() return 1 end }
	local stage = newInstance("Folder", w)
	reg.MonsterService = { MonsterKilled = Signal.new(),
		Shove = function(rec) table.insert(w.Shoves, { Rec = rec, At = w.Clock }) end }
	function reg.MonsterService.GetMonstersInRadius(point, radius)
		local out = {}
		for _, rec in w.Monsters do
			if rec.Alive and w.Util.FlatDistance(rec.Root.Position, point) <= radius then table.insert(out, rec) end
		end
		return out
	end
	function reg.MonsterService.DamageMonster(rec, dealt, player)
		table.insert(w.Damage, { Rec = rec, N = dealt, P = player })
		rec.HP = math.max(0, rec.HP - dealt)
		if rec.HP <= 0 and rec.Alive then
			rec.Alive = false
			return true
		end
		return false
	end
	reg.GooseService = { GetPosition = function() return nil end, RegisterHit = function() return 0 end }
	reg.VitalsService = { TrySpendMana = function(p, cost)
		table.insert(w.Mana, { P = p, Cost = cost })
		return true
	end }
	reg.PvPService = { GetStars = function() return 0 end, HasRevenge = function() return false end,
		BreakProtection = function() end, CanAttack = function() return o.Hit == true end }
	reg.ProgressionService = { LevelReset = Signal.new(), Rebirthed = Signal.new(), LeveledUp = Signal.new(),
		GoldEarned = Signal.new(),
		AddCarriedGold = function(p, n) ps.SetStat(p, "CarriedGold", (data[p].CarriedGold or 0) + n) end,
		AddBankGold = function(p, n) ps.SetStat(p, "BankGold", (data[p].BankGold or 0) + n) end,
		AddXP = function() end,
		-- the pouch first, then the bank (A23-4)
		SpendGold = function(p, n)
			local d = data[p]
			if (d.CarriedGold or 0) + (d.BankGold or 0) < n then return false end
			local fromPouch = math.min(d.CarriedGold or 0, n)
			ps.SetStat(p, "CarriedGold", d.CarriedGold - fromPouch)
			ps.SetStat(p, "BankGold", d.BankGold - (n - fromPouch))
			return true
		end }
	reg.ShopService = { CanBuyWeapon = function() return true end }
	reg.AnnounceService = { Announce = function(p, key, args, grade)
		table.insert(w.Announced, { P = p, Key = key, Args = args, Grade = grade })
	end }
	reg.QuestService = { MarkDirty = function() end }
	w.Tickets = {}
	reg.MonetizationService = { AddTickets = function(p, kind, n)
		table.insert(w.Tickets, { P = p, Kind = kind, N = n })
		return n
	end }

	-- the real services; CombatService's two forever-loops are captured (the auto-combat one is stepped by hand)
	local cenv = w:Env()
	cenv.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = cenv.task })
	local combat = execute("CombatService", COMBAT_SOURCE, cenv)
	reg.CombatService = combat
	local loot = w:Load("LootService", LOOT_SOURCE)
	reg.LootService = loot
	local story = w:Load("StoryQuestService", STORY_SOURCE)
	reg.StoryQuestService = story
	local pet = PET_SOURCE and w:Load("PetService", PET_SOURCE) or nil
	reg.PetService = pet
	combat.Init(reg)
	loot.Init(reg)
	story.Init(reg)
	if pet then pet.Init(reg) end
	local n0 = #w.Spawned
	combat.Start()
	assert(#w.Spawned == n0 + 2, "CombatService.Start spawns the regen and the auto-combat loop")
	local autoLoop = coroutine.create(w.Spawned[n0 + 2][1])
	w.Spawned = {}
	loot.Start()
	if pet then pet.Start() end
	w.Spawned = {}
	assert(coroutine.resume(autoLoop)) -- runs to its first task.wait
	w.Combat, w.Loot, w.Story, w.Pet = combat, loot, story, pet
	-- one auto-combat step for every ready player
	function w:AutoTick()
		local ok, err = coroutine.resume(autoLoop)
		assert(ok, err)
		self:Flush()
	end

	-- the blacksmith (ShopService extract: the real handlers, the anvil distance check = M.CanBuyWeapon)
	local prompt = newInstance("ProximityPrompt", w)
	prompt.Name = "HHC_BlacksmithPrompt"
	local M = { CanBuyWeapon = function() return true end }
	w.Shop = execute("ShopService.extract", SHOP_EXTRACT, w:Env(), cfg, w.Util, w.Net, reg, M,
		{ PromptName = "HHC_BlacksmithPrompt", Distance = 12, PromptRate = 0.5 }, function() return nil, prompt end)
	w.Prompt = prompt
	function w:Buy(p, tier)
		self:Advance(1) -- RateLimits.UpgradeWeapon
		self.Shop.Upgrade(p, tier)
		self:Flush()
	end
	function w:Sell(p, tier)
		self:Advance(1)
		self.Shop.Sell(p, tier)
		self:Flush()
	end
	function w:Anvil(p)
		self:Advance(1)
		self.Shop.Prompt(prompt, p)
		self:Flush()
	end

	-- a character facing -Z: root at `pos`, right hand at +X, left hand at -X
	function w:Body(p, pos)
		pos = pos or vec(0, 0, 0)
		local model = newInstance("Model", w)
		model.Name = p.Name
		local hum = newInstance("Humanoid", w)
		hum.Name, hum.Health, hum.MaxHealth = "Humanoid", 100, 100
		function hum.TakeDamage(self2, n) self2.Health = math.max(0, self2.Health - n) end
		function hum.GetState() return "HumanoidStateType.Running" end
		hum.Parent = model
		local root = newInstance("Part", w)
		root.Name, root.Position = "HumanoidRootPart", pos
		root.CFrame = { LookVector = vec(0, 0, -1) }
		root.Parent = model
		for name, x in { RightHand = 1, LeftHand = -1 } do
			local hand = newInstance("BasePart", w)
			hand.Name, hand.Position = name, pos + vec(x, 1, 0)
			hand.Parent = model
		end
		model.Parent = stage
		p.Character = model
		return model
	end
	-- a ready player: o.Class, o.Faction, o.Level, o.Tier, o.Mask, o.Carried, o.Bank, o.Tutorial, o.Data, o.Saved, o.Attrs
	function w:Join(userId, jo)
		jo = jo or {}
		local p = self:NewPlayer(userId, {})
		local d = jo.Saved or deepCopy(cfg.Data.Defaults)
		if not jo.Saved then
			d.Class, d.Faction, d.ClassChosen = jo.Class or "Warrior", jo.Faction or "Halo", true
			d.Level = jo.Level or 1
			d.WeaponTier, d.WeaponOwnedMask = jo.Tier or d.WeaponTier, jo.Mask or d.WeaponOwnedMask
			d.CarriedGold, d.BankGold = jo.Carried or 0, jo.Bank or 0
			d.TutorialStep = jo.Tutorial or 99
			for k, v in jo.Data or {} do d[k] = deepCopy(v) end
		end
		data[p] = d
		for key in mirrored do
			if d[key] ~= nil then p:SetAttribute(key, d[key]) end
		end
		for k, v in jo.Attrs or {} do p:SetAttribute(k, v) end
		self:Body(p, jo.Pos)
		self.Ready[p] = true
		if jo.BeforeReady then jo.BeforeReady(p, d) end
		ps.PlayerReady:Fire(p, d)
		self:Flush()
		return p, d
	end
	-- a monster record `dz` studs in front (-Z) and `dx` to the side of the origin
	function w:Monster(kind, dz, dx, hp)
		local root = newInstance("Part", w)
		root.Position = vec(dx or 0, 0, -dz)
		root.Parent = stage
		local def = cfg.MonsterTypes[kind]
		local rec = { Kind = kind, Def = def, HP = hp or def.HP, Alive = true, Root = root, ZoneId = "SlimeMeadow" }
		table.insert(w.Monsters, rec)
		return rec
	end
	function w:FxOf(kind, from)
		local out = {}
		for i = (from or 0) + 1, #self.Fx do
			if self.Fx[i].Kind == kind then table.insert(out, self.Fx[i]) end
		end
		return out
	end
	function w:Dealt(rec)
		local n = 0
		for _, d in self.Damage do if d.Rec == rec then n += d.N end end
		return n
	end
	-- one scripted kill: rows whose Item / Weapon is in `want` drop, the jackpot draw (Slime) is `jackpot` or a miss
	function w:Drop(p, kind, want, jackpot)
		local script = {}
		for _, row in cfg.Loot.Tables[kind] do
			local hit = (row.Item and want and want[row.Item]) or (row.Weapon and want and want["W" .. row.Weapon])
			table.insert(script, hit and 0 or 0.999999)
		end
		if cfg.Loot.Jackpot.Monsters[kind] then table.insert(script, jackpot or 0.999999) end
		self.Script = script
		reg.MonsterService.MonsterKilled:Fire(p, { Kind = kind, Golden = false, Position = vec(0, 0, 0), ZoneId = "SlimeMeadow" })
		self.Script = nil
		self:Flush()
	end
	return w
end

local function notices(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Notices do
		if w.Notices[i].Player == p then table.insert(out, w.Notices[i].Text) end
	end
	return out
end

local function indexOf(list, text)
	for i, x in list do if x == text then return i end end
	return nil
end

