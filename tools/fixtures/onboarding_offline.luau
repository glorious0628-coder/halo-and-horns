-- Real Config, QuestService and DataService sources are injected by test_onboarding.py.
-- Engine events/storage are doubles; this fixture must not be reported as a live reconnect test.
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
-- Independent contract checks (wording etc.) are collected instead of aborting, so one source defect does not
-- hide the rest of the run. Any collected failure still fails the runner.
local failures = {}
local function soft(ok, message) checks += 1; if not ok then table.insert(failures, message) end end
local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}; for k, x in v do out[k] = copy(x) end; return out
end
-- A finite-value serialization guard for the mock store. This checks the post-sanitization
-- save payload, not the impossible NaN/Infinity records injected into corrupt-load fixtures.
local function serializedCopy(value, active)
	local kind = type(value)
	if kind == "number" then
		assert(value == value and math.abs(value) ~= math.huge, "non-finite number in saved record")
		return value
	elseif kind == "nil" or kind == "boolean" or kind == "string" then
		return value
	end
	assert(kind == "table", "unsupported value in saved record: " .. kind)
	active = active or {}; assert(not active[value], "cyclic saved record"); active[value] = true
	local result = {}
	for key, item in value do
		assert(type(key) == "string" or (type(key) == "number" and key == math.floor(key)
			and key > 0 and key < math.huge), "invalid saved record key")
		result[key] = serializedCopy(item, active)
	end
	active[value] = nil
	return result
end
local function execute(source, env)
	local fn, err = loadstring(source); assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() })); return fn()
end
local function signal()
	local listeners = {}
	return { Connect = function(_, fn)
		local rec = { fn = fn, live = true }; table.insert(listeners, rec)
		return { Disconnect = function() rec.live = false end }
	end, Fire = function(_, ...) for _, rec in listeners do if rec.live then rec.fn(...) end end end }
end
local function encode(v)
	if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
	local keys = {}; for k in v do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}; for _, k in keys do table.insert(out, encode(k) .. "=" .. encode(v[k])) end
	return "{" .. table.concat(out, ";") .. "}"
end
local enum = setmetatable({}, { __index = function(_, key) return setmetatable({}, { __index = function(_, item) return key .. "." .. item end }) end })
local function tuple(...) return { ... } end
local configEnv = { Enum = enum, Color3 = { new = tuple, fromRGB = tuple }, BrickColor = { new = tuple },
	Vector2 = { new = tuple }, Vector3 = { new = tuple }, Rect = { new = tuple }, UDim2 = { fromScale = tuple } }
local serial = 0
local function fixture(saved, opts)
	serial += 1
	local f = { Zone = "HaloTown", Alive = true, Ready = true, RateAllowed = true, Loops = {}, Delayed = {},
		Notices = {}, Rows = {}, Remote = {}, Sends = 0, Spawned = {}, Panels = {} }
	local config = execute(CONFIG_SOURCE, configEnv)
	f.Config = config
	local players = {}
	local function newPlayer()
		local p = { Name = "OnboardingTester", UserId = serial, Parent = players, Attrs = {}, __kind = "Instance" }
		function p:SetAttribute(k, v) self.Attrs[k] = v end
		function p:GetAttribute(k) return self.Attrs[k] end
		function p:IsA(kind) return kind == "Player" end
		return p
	end
	f.Player = newPlayer()
	if saved then f.Rows["P_" .. serial] = copy(saved) end
	local store = {}
	function store:GetAsync(k) return copy(f.Rows[k]) end
	function store:UpdateAsync(k, callback)
		local nextValue = callback(copy(f.Rows[k]))
		if nextValue ~= nil then f.Rows[k] = if f.CheckSerialization then serializedCopy(nextValue) else copy(nextValue) end
		return copy(f.Rows[k])
	end
	local function resume(co)
		local ok, delay = coroutine.resume(co); assert(ok, delay)
		if coroutine.status(co) ~= "dead" then f.Loops[co] = delay else f.Loops[co] = nil end
	end
	local taskMock = { spawn = function(fn, ...)
		local args = table.pack(...); local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end); resume(co)
	end, wait = function(delay) return coroutine.yield(delay or 0) end,
		delay = function(_, fn) table.insert(f.Delayed, fn) end, defer = function(fn, ...) fn(...) end }
	local util = { DeepCopy = copy, Warn = function(tag, msg) if tag ~= "DataService" then error(tag .. ": " .. msg) end end,
		IsAlive = function() return f.Alive end, FormatNumber = tostring, Now = function() return 100 end,
		RateLimit = function() return f.RateAllowed end,
		Random = { NextNumber = function(_, a, b) return a and (a + b) / 2 or 0.5 end, NextInteger = function(_, a) return a end } }
	local net = { Get = function(name)
		if not f.Remote[name] then f.Remote[name] = { OnServerEvent = signal(), FireClient = function(_, p, payload)
			check(p == f.Player, "publication leaked to wrong player")
			if name == "Quests" then f.LastList = copy(f.Encoding); f.Sends += 1
			elseif name == "OpenPanel" then table.insert(f.Panels, payload)
			else error("unexpected server publication " .. name) end
		end } end
		return f.Remote[name]
	end, Notify = function(_, message) table.insert(f.Notices, message) end }
	local token = 0
	local services = { Players = players, ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		DataStoreService = { GetDataStore = function() return store end }, RunService = { IsStudio = function() return true end },
		HttpService = { GenerateGUID = function() token += 1; return "session-" .. serial .. "-" .. token end,
			JSONEncode = function(_, value) f.Encoding = copy(value); return encode(value) end } }
	local world = {}
	local env = { game = { JobId = "offline", GetService = function(_, name) return assert(services[name], name) end },
		workspace = world, task = taskMock, print = function() end,
		typeof = function(v) return type(v) == "table" and v.__kind or type(v) end,
		require = function(name) if name == "Config" then return config elseif name == "Util" then return util elseif name == "Net" then return net end; error(name) end }
	if serial == 1 then
		local realNet, seen = execute(NET_SOURCE, env), {}
		for _, name in realNet.Names do check(not seen[name], "duplicate registered remote " .. name); seen[name] = true end
		check(seen.RequestTutorial and seen.AcceptTutorial, "tutorial remotes missing from actual Net registry")
	end
	local dataService = execute(DATA_SOURCE, env); dataService.Init({}); dataService.Start()
	local loaded = dataService.Load(f.Player)
	if opts and opts.AllowRefused and loaded == nil then
		f.Refused, f.DataService = true, dataService
		return f
	end
	f.Data = assert(loaded)
	local ps = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterSpawned = signal(),
		IsReady = function(p) return f.Ready and dataService.Get(p) ~= nil end, GetData = dataService.Get,
		GetReadyPlayers = function() return { f.Player } end }
	function ps.SetStat(p, key, value) local d = assert(dataService.Get(p)); d[key] = value; if table.find(config.Data.Mirrored, key) then p:SetAttribute(key, value) end end
	function ps.AddStat(p, key, amount) local v = (dataService.Get(p)[key] or 0) + amount; ps.SetStat(p, key, v); return v end
	local monster = { MonsterKilled = signal(), SpawnPersonal = function()
		local model = { Parent = world, __kind = "Instance", AncestryChanged = signal() }
		function model:IsDescendantOf(parent) return self.Parent == parent end
		table.insert(f.Spawned, model); return model
	end }
	local prog = { GoldEarned = signal(), Rebirthed = signal(), LevelReset = signal(), LeveledUp = signal(),
		AddBankGold = function(p, amount) ps.AddStat(p, "BankGold", amount) end,
		AddXP = function(p, amount) ps.AddStat(p, "XP", amount) end }
	local registry = { PlayerService = ps, DataService = dataService, MonsterService = monster, ProgressionService = prog,
		FactionService = { FactionChanged = signal(), GetFaction = function(p) return dataService.Get(p).Faction end },
		ClassService = { ClassChanged = signal() }, ZoneService = { ZoneChanged = signal(), GetZoneId = function() return f.Zone end },
		CombatService = { Released = signal() }, GooseService = { GooseFinished = signal() },
		PvPService = { PlayerKO = signal(), IsRookie = function() return true end }, KaijuService = { KaijuEnded = signal() } }
	local quest = execute(QUEST_SOURCE, env); quest.Init(registry); quest.Start()
	ps.PlayerReady:Fire(f.Player, f.Data)
	f.Services, f.DataService = registry, dataService
	function f:Tick()
		local list = {}; for co, delay in self.Loops do if delay <= 1 then table.insert(list, co) end end
		for _, co in list do resume(co) end
	end
	function f:Publish() self:Tick(); self:Tick() end
	function f:Kill(kind, personal, zone)
		monster.MonsterKilled:Fire(self.Player, { Kind = kind or "Slime", Personal = personal == true, ZoneId = zone or "SlimeMeadow", Golden = false })
		self:Publish()
	end
	function f:Choose()
		ps.SetStat(self.Player, "Faction", "Halo"); ps.SetStat(self.Player, "ClassChosen", true)
		registry.ClassService.ClassChanged:Fire(self.Player)
	end
	function f:ZoneTo(zone) self.Zone = zone; registry.ZoneService.ZoneChanged:Fire(self.Player, zone); self:Publish() end
	function f:Claim() self.Remote.ClaimQuest.OnServerEvent:Fire(self.Player, "tutorial"); self:Publish() end
	function f:Request(...) self.Remote.RequestTutorial.OnServerEvent:Fire(self.Player, ...) end
	function f:Accept(...) self.Remote.AcceptTutorial.OnServerEvent:Fire(self.Player, ...) end
	function f:Rejoin()
		ps.PlayerLeaving:Fire(self.Player); dataService.Release(self.Player); self.Player.Parent = nil
		self.Player = newPlayer(); self.Data = assert(dataService.Load(self.Player)); ps.PlayerReady:Fire(self.Player, self.Data); self:Publish()
	end
	function f:SaveAndRejoin()
		self.CheckSerialization = true
		check(dataService.Save(self.Player, false), "actual DataService save failed serialization")
		local snapshot = serializedCopy(self.Rows["P_" .. self.Player.UserId])
		self:Rejoin()
		return snapshot
	end
	return f
end

local function saved(step, kills)
	return { Version = 2, TutorialStep = step, TutorialKills = kills, ClassChosen = true, Faction = "Halo", Level = 1, WeaponTier = 1 }
end
do
	local f = fixture(); f:Choose(); f:Publish()
	check(f.LastList[1].Pinned and f.LastList[1].TutorialStep == 0, "class choice bypassed welcome acceptance")
	check(#f.Panels == 1 and f.Panels[1] == "Welcome", "class choice did not open the guide")
	check(string.find(f.LastList[1].Text, "안내자") ~= nil, "pending guide is not discoverable")
	f:Publish(); f.Services.PlayerService.CharacterSpawned:Fire(f.Player)
	for _, fn in f.Delayed do fn() end; f:Publish()
	check(#f.Panels == 1 and f.Data.TutorialStep == 0, "closed welcome auto-reopened/accepted")
	f:Request(); check(#f.Panels == 2 and f.Data.TutorialStep == 0, "request did not reopen without accepting")
	f:Accept(); f:Publish()
	check(f.Data.TutorialStep == 1 and f.LastList[1].TutorialStep == 1, "accept did not pin meadow travel")
	check(f.LastList[1].CanClaim == false and f.LastList[1].ShowProgress == false, "travel is claimable/fake counter")
	f:Claim(); check(f.Data.BankGold == 0, "travel guidance paid gold")
	check(#f.Spawned == 0 and f.Data.TutorialKills == 0, "a personal town slime was spawned/credited")
	check(f.LastList[1].TutorialStep == 1 and f.LastList[1].CanClaim == false, "travel is not pinned")
	f:ZoneTo("SlimeMeadow"); check(f.LastList[1].Target == 5 and f.LastList[1].Progress == 0, "meadow entry does not show hunt")
end
do
	local f = fixture(saved(0, 0)); f.Zone = "SlimeMeadow"; f:Kill()
	check(f.Data.TutorialStep == 0 and f.Data.TutorialKills == 0, "direct meadow kill bypassed acceptance")
	f:ZoneTo("SlimeMeadow"); check(f.Data.TutorialStep == 0, "zone event bypassed acceptance")
	f:Accept(); check(f.Data.TutorialStep == 2 and f.Data.TutorialKills == 0, "meadow acceptance invented a kill")
	f:Kill(); check(f.Data.TutorialKills == 1, "first accepted meadow kill was discarded")
	local g = fixture(saved(1, 0)); g:Kill()
	check(g.Data.TutorialStep == 2 and g.Data.TutorialKills == 1, "kill before ZoneChanged was discarded")
end
do
	local f = fixture(); f.Alive = false; f:Choose(); f:Publish()
	check(#f.Panels == 0 and f.Data.TutorialStep == 0, "guide opened before a living character existed")
	f.Alive = true; f.Services.PlayerService.CharacterSpawned:Fire(f.Player)
	for _, fn in f.Delayed do fn() end; f:Publish()
	check(#f.Panels == 1 and f.Data.TutorialStep == 0, "first living spawn did not open pending guide")
	f:Publish(); check(#f.Panels == 1, "living watchdog reopened pending guide")
end
do
	local f = fixture(saved(2, 0)); f:Kill("Slime", true); f:Kill("Slime", false, "GoblinWoods"); f:Kill("Goblin", false)
	check(f.Data.TutorialKills == 0, "wrong/personal monster counted")
	f:Kill("BigSlime"); check(f.Data.TutorialKills == 1, "meadow BigSlime contribution did not count")
end
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	check(cfg.Tutorial.QuestRewardGold == 150, "A23-3 first mission reward is not 150 gold")
	check(cfg.Tutorial.QuestRewardGold >= cfg.Weapons[2].Price, "first mission reward cannot afford the wood weapon")
end
for _, count in { 4, 5 } do
	local f = fixture(saved(2, 0)); for _ = 1, count do f:Kill() end
	local reward = f.Config.Tutorial.QuestRewardGold
	check(f.Data.TutorialKills == count, "kill counter mismatch")
	f:Rejoin(); check(f.Data.TutorialKills == count and f.LastList[1].Progress == count, "save/rejoin lost partial or ready progress")
	check(f.Data.TutorialStep == 2, "rejoin prematurely claimed reward")
	local before = f.Data.BankGold; f:Claim()
	if count == 4 then
		check(f.Data.BankGold == before and f.Data.TutorialStep == 2, "incomplete quest paid")
	else
		check(f.Data.BankGold == before + reward and f.Data.TutorialStep == 99, "completed reward missing")
		f:Claim(); check(f.Data.BankGold == before + reward, "duplicate request paid twice")
		f:Rejoin(); f:Claim(); check(f.Data.BankGold == before + reward, "claimed reward paid again after reconnect")
		check(f.LastList[1].CanClaim == false and string.find(f.LastList[1].Text, "대장간") ~= nil, "blacksmith followup missing")
	end
end
for _, test in { { -4, 0 }, { 2.8, 2 }, { 99, 5 }, { "4", 0 }, { 0/0, 0 }, { math.huge, 0 }, { -math.huge, 0 } } do
	local f = fixture(saved(2, test[1])); check(f.Data.TutorialKills == test[2], "invalid saved kills not normalized")
end
do
	local f = fixture({ Version = 2, Level = 9 }); check(f.Data.TutorialStep == 99 and f.Data.TutorialKills == 0, "legacy save reopened onboarding")
	for _, step in { 3, -1, 0/0, math.huge } do local g = fixture(saved(step, 4)); check(g.Data.TutorialStep == 99, "invalid step remained stuck") end
end
do
	local f = fixture(saved(2, 4)); f.Alive = false; f.Services.PlayerService.CharacterSpawned:Fire(f.Player)
	f.Services.FactionService.FactionChanged:Fire(f.Player, "Neutral"); f.Services.ClassService.ClassChanged:Fire(f.Player)
	for _, fn in f.Delayed do fn() end; f:Publish()
	check(f.Data.TutorialKills == 4, "respawn/faction/class change reset saved progress")
end
do
	local f = fixture(saved(0, 0)); f:Publish()
	check(#f.Spawned == 0 and f.Data.TutorialStep == 0, "pending step0 bypassed dialogue")
	f.Services.PlayerService.CharacterSpawned:Fire(f.Player)
	for _, fn in f.Delayed do fn() end; f:Publish()
	check(#f.Spawned == 0 and f.Data.TutorialKills == 0, "respawn created a town slime or credited a kill")
	f:ZoneTo("SlimeMeadow"); f:Kill()
	check(f.Data.TutorialStep == 0 and f.Data.TutorialKills == 0, "respawn/kill bypassed welcome acceptance")
	f:Accept(); f:Kill()
	check(f.Data.TutorialStep == 2 and f.Data.TutorialKills == 1, "accepted meadow combat did not count1/5")
	local g = fixture(); g.Zone = "SlimeMeadow"; g:Choose(); g:Publish()
	check(g.Data.TutorialStep == 0 and #g.Spawned == 0, "class choice in meadow bypassed dialogue")
	g:Accept(); check(g.Data.TutorialStep == 2 and g.Data.TutorialKills == 0, "meadow acceptance failed")
end
-- Tutorial acceptance is the only step0 transition; no client arguments can select a faction, stage or reward.
for _, faction in { "Halo", "Horns", "Neutral" } do
	local initial = saved(0, 0); initial.Faction = faction
	local f = fixture(initial)
	local welcome = f.Config.Tutorial.Welcome[faction]
	check(type(welcome.Name) == "string" and #welcome.Lines == 3, faction .. " guide has no three-page dialogue")
	for _, line in welcome.Lines do check(type(line) == "string" and #line > 0, faction .. " guide page missing") end
	check(f.Panels[1] == "Welcome" and f.Data.TutorialStep == 0, faction .. " guide did not open pending")
	local beforeGold = f.Data.BankGold
	f:Accept(); f:Accept(); f:Request()
	check(f.Data.TutorialStep == 1 and f.Data.TutorialKills == 0 and f.Data.BankGold == beforeGold,
		faction .. " acceptance invented progress/reward")
	check(#f.Panels == 1, faction .. " accepted dialogue re-opened")
	local record = f:SaveAndRejoin()
	check(record.TutorialStep == 1 and f.Data.TutorialStep == 1 and #f.Panels == 1,
		faction .. " accepted progress did not survive reload")
end
do
	local f = fixture(saved(0, 0))
	for _, payload in { table.pack(nil), table.pack(true), table.pack("Halo"), table.pack({}), table.pack(1, 2), table.pack(0/0) } do
		f:Request(table.unpack(payload, 1, payload.n)); f:Accept(table.unpack(payload, 1, payload.n))
		check(f.Data.TutorialStep == 0 and #f.Panels == 1, "malformed welcome payload accepted")
	end
	f.RateAllowed = false; f:Request(); f:Accept()
	check(f.Data.TutorialStep == 0 and #f.Panels == 1, "rate-limited welcome was accepted")
	f.RateAllowed = true
	for _, state in { "Alive", "Ready" } do
		f[state] = false; f:Request(); f:Accept(); f:Publish()
		check(f.Data.TutorialStep == 0 and #f.Panels == 1, state .. " invalid player opened/accepted welcome")
		f[state] = true
	end
	local priorParent = f.Player.Parent; f.Player.Parent = nil; f:Request(); f:Accept()
	check(f.Data.TutorialStep == 0 and #f.Panels == 1, "departed player accepted")
	f.Player.Parent = priorParent
	for _, field in { "Faction", "Class", "ClassChosen" } do
		local prior = f.Data[field]; f.Data[field] = if field == "ClassChosen" then false else "Invalid"
		f:Request(); f:Accept(); f:Publish()
		check(f.Data.TutorialStep == 0 and #f.Panels == 1, "invalid " .. field .. " accepted")
		f.Data[field] = prior
	end
	f:SaveAndRejoin()
	check(f.Data.TutorialStep == 0 and #f.Panels == 2, "pending welcome not restored once in new session")
end
for _, step in { 1, 2, 99 } do
	local f = fixture(saved(step, 4)); f:Request(); f:Accept(); f:Publish()
	check(f.Data.TutorialStep == step and f.Data.TutorialKills == 4 and #f.Panels == 0,
		"existing accepted/completed save was reopened or reset")
end
do
	local f = fixture(saved(99, 5)); f:Publish(); check(f.LastList[1].CanClaim == false, "post-reward hint is claimable")
	f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 2)
	f.Services.PlayerService.SetStat(f.Player, "WeaponOwnedMask", 3); f:Publish()
	check(string.find(f.LastList[1].Text, "대장간") ~= nil, "weapon tier incorrectly replaced the actual visit condition")
	f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 1)
	f.Services.PlayerService.SetStat(f.Player, "BlacksmithVisited", true); f:Publish()
	-- A23-3: after the visit the pinned row stays as one next-goal line computed from existing state (no reward).
	local T, iron, woods = f.Config.Tutorial.Text, f.Config.Weapons[3], f.Config.Zones.GoblinWoods
	local function nextGoal(context, expected)
		local row = f.LastList[1]
		check(row.Pinned == true and row.Id == "tutorial" and row.NextGoal == true, context .. " lost the pinned next-goal row")
		check(row.Text == expected, context .. " next-goal text mismatch: " .. tostring(row.Text) .. " ~= " .. expected)
		check(row.CanClaim == false and row.ShowProgress == false and row.RewardGold == 0 and row.RewardXP == 0,
			context .. " next goal became claimable or advertised a reward")
		check(#f.LastList == f.Config.Quests.Slots + 1, context .. " hid ordinary quest slots")
		for i = 2, #f.LastList do check(f.LastList[i].Pinned ~= true, context .. " pinned a second row") end
	end
	local function gold() return tostring(math.floor(f.Data.CarriedGold + f.Data.BankGold)) end
	local function guideDone()
		local n = 0
		for _, message in f.Notices do if message == T.GuideDone then n += 1 end end
		return n
	end
	check(iron.MinLevel == 5 and woods.MinLevel == 10, "next-goal fixture expects iron Lv5 and Goblin Woods Lv10")
	nextGoal("visit without purchase", string.format(T.NextIronLevel, iron.MinLevel, 1))
	local record = f:SaveAndRejoin()
	check(record.BlacksmithVisited == true and f.Data.BlacksmithVisited == true, "saved blacksmith visit was lost")
	nextGoal("rejoin", string.format(T.NextIronLevel, iron.MinLevel, 1))
	check(f.Data.WeaponTier == 1, "rejoin forced a purchase/equipment change")
	f.Services.PlayerService.SetStat(f.Player, "Level", 5); f.Services.ProgressionService.LeveledUp:Fire(f.Player); f:Publish()
	nextGoal("level5", string.format(T.NextIronGold, tostring(iron.Price), gold()))
	f.Services.PlayerService.SetStat(f.Player, "CarriedGold", 120); f.Services.PlayerService.SetStat(f.Player, "BankGold", 600); f:Publish()
	nextGoal("level5 gold change", string.format(T.NextIronGold, tostring(iron.Price), "720"))
	f.Services.PlayerService.SetStat(f.Player, "Level", 10); f:Publish()
	nextGoal("level10 without iron", string.format(T.NextIronGold, tostring(iron.Price), "720"))
	local before = f.Sends; f:Publish(); check(f.Sends == before, "watchdog resends unchanged payload")
	-- iron owned (bought through the separately tested shop contract) below Goblin Woods level -> zone goal
	f.Services.PlayerService.SetStat(f.Player, "Level", 6)
	f.Services.PlayerService.SetStat(f.Player, "WeaponOwnedMask", 5); f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 3); f:Publish()
	nextGoal("iron owned", string.format(T.NextZone, woods.MinLevel, woods.Name, 6))
	f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 1); f:Publish()
	nextGoal("owned iron unequipped", string.format(T.NextZone, woods.MinLevel, woods.Name, 6))
	check(guideDone() == 0, "guide-finished toast fired while a goal remained")
	f.Services.PlayerService.SetStat(f.Player, "Level", 10); f:Publish()
	check(f.LastList[1].Pinned ~= true and #f.LastList == f.Config.Quests.Slots, "finished guide chain kept a pinned row")
	check(guideDone() == 1, "guide-finished toast missing or repeated")
	f:Publish(); f:Publish(); check(guideDone() == 1, "guide-finished toast repeated on unchanged state")
	f:SaveAndRejoin(); f:Publish()
	check(f.LastList[1].Pinned ~= true and guideDone() == 1, "rejoin after the finished guide re-pinned or re-toasted")
end
-- The real QuestService migrates old charged-release quests in both daily and extra slots.
-- Combat signals below are test doubles; this tests service event handling, not real skill hits.
for _, kind in { "Daily", "Extra" } do
	local initial = saved(99, 5)
	initial.BlacksmithVisited = true
	initial.DailyDay = execute(CONFIG_SOURCE, configEnv).DayIndex(os.time())
	initial.Quests = {
		{ Id = "Release", Kind = kind, Target = 5, Progress = 1, RewardGold = 123, RewardXP = 45,
			Text = "50 충전 발사 5번 사용하기", MinStacks = 50, Unit = "Slime" },
		{ Id = "Kill", Kind = "Daily", Target = 10, Progress = 2, RewardGold = 12, RewardXP = 4,
			Text = "슬라임 10마리 쓰러뜨리기", Unit = "Slime" },
		{ Id = "Gold", Kind = "Daily", Target = 100, Progress = 3, RewardGold = 12, RewardXP = 4,
			Text = "사냥으로 골드 100 벌기", Unit = "Slime" },
	}
	local f = fixture(initial)
	local q = f.Data.Quests[1]
	local releaseTemplate = nil
	for _, def in f.Config.Quests.Templates do if def.Id == "Release" then releaseTemplate = def end end
	check(releaseTemplate ~= nil and releaseTemplate.MinStacks == nil, "new skill quest retains old charge requirement")
	-- A23-1 wording: the template says the skill must hit a monster; migrated quests must use the same wording.
	local expectedText = string.format(releaseTemplate.Text, 5)
	check(string.find(releaseTemplate.Text, "몬스터", 1, true) ~= nil, "skill quest template does not require a monster hit")
	check(q.Id == "Release" and q.Kind == kind and q.MinStacks == nil, kind .. " saved stack threshold survived")
	check(q.Target == 5 and q.Progress == 1 and not string.find(q.Text, "충전", 1, true),
		kind .. " migration changed target/progress or kept old charge wording")
	soft(q.Text == expectedText, kind .. " migrated skill quest text '" .. q.Text .. "' differs from the A23 template '"
		.. expectedText .. "' (QuestService ensureSlots hardcodes the old wording)")
	check(q.RewardGold == 123 and q.RewardXP == 45, kind .. " migration changed the stored reward")
	-- the A23-3 next-goal row is pinned first after the visit; ordinary quests are addressed by Slot
	local function slotRow(slot)
		for _, entry in f.LastList do if entry.Slot == slot then return entry end end
		return {}
	end
	check(f.LastList[1].NextGoal == true and slotRow(1).Text == q.Text and slotRow(1).Progress == 1,
		kind .. " migrated skill quest was not published")
	local beforeGold, beforeXP = f.Data.BankGold, f.Data.XP
	f.Services.CombatService.Released:Fire(f.Player, { Auto = true, Stacks = 100, Total = 999, MonstersHit = 3 })
	f.Services.CombatService.Released:Fire(f.Player, nil)
	f.Services.CombatService.Released:Fire(f.Player, "invalid")
	-- A23-1: whiffs, player-only hits and malformed monster counts never count
	f.Services.CombatService.Released:Fire(f.Player, { Auto = false, Stacks = 0, Total = 10 })
	for _, hit in { 0, -1, 0.5, 0/0, math.huge, "1", true } do
		f.Services.CombatService.Released:Fire(f.Player, { Auto = false, Total = 10, MonstersHit = hit, PlayersHit = 1 })
	end
	f:Publish()
	check(q.Progress == 1, kind .. " automatic/whiff/malformed skill event advanced progress")
	f.Services.CombatService.Released:Fire(f.Player, { Auto = false, Stacks = 0, Total = 10, MonstersHit = 1 })
	f:Publish()
	check(q.Progress == 2 and slotRow(1).Progress == 2, kind .. " manual one-monster skill did not count exactly once")
	f.Services.CombatService.Released:Fire(f.Player, { Auto = false, Total = 10, MonstersHit = 4 }) -- no obsolete Stacks
	f:Publish()
	check(q.Progress == 3, kind .. " manual multi-monster skill did not count exactly once")
	check(f.Data.Quests[2].Progress == 2 and f.Data.Quests[3].Progress == 3,
		kind .. " skill event advanced unrelated quest types")
	check(f.Data.BankGold == beforeGold and f.Data.XP == beforeXP, kind .. " incomplete skill quest paid a reward")
	local record = f:SaveAndRejoin()
	local stored, reloaded = record.Quests[1], f.Data.Quests[1]
	check(stored.MinStacks == nil and stored.Text == q.Text and stored.Progress == 3,
		kind .. " save reintroduced the stack gate or lost progress")
	check(reloaded.MinStacks == nil and reloaded.Text == stored.Text and reloaded.Progress == 3
		and reloaded.Target == 5 and reloaded.Kind == kind, kind .. " rejoin migration was not idempotent")
	f.Services.CombatService.Released:Fire(f.Player, { Auto = true, Stacks = 100, MonstersHit = 2 })
	f:Publish(); check(reloaded.Progress == 3, kind .. " auto event counted after reconnect")
	f.Services.CombatService.Released:Fire(f.Player, { Auto = false, MonstersHit = 1 })
	f:Publish(); check(reloaded.Progress == 4, kind .. " manual hit after reconnect did not count")
end
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	local template = nil
	for _, def in cfg.Quests.Templates do if def.Id == "Release" then template = def end end
	local text = string.format(template.Text, 3)
	local initial = saved(99, 5)
	initial.BlacksmithVisited, initial.DailyDay = true, cfg.DayIndex(os.time())
	initial.Quests = {
		{ Id = "Release", Kind = "Extra", Target = 3, Progress = 0, RewardGold = 10, RewardXP = 5, Text = text, Unit = "Slime" },
		{ Id = "Kill", Kind = "Daily", Target = 10, Progress = 2, RewardGold = 12, RewardXP = 4, Text = "슬라임 10마리 쓰러뜨리기", Unit = "Slime" },
		{ Id = "Gold", Kind = "Daily", Target = 100, Progress = 3, RewardGold = 12, RewardXP = 4, Text = "사냥으로 골드 100 벌기", Unit = "Slime" },
	}
	local f = fixture(initial)
	soft(f.Data.Quests[1].Text == text, "current-template skill quest '" .. text .. "' was rewritten on load to '"
		.. f.Data.Quests[1].Text .. "'")
	f:SaveAndRejoin()
	soft(f.Data.Quests[1].Text == text, "current-template skill quest wording changed after save/rejoin")
	check(f.Data.Quests[1].Target == 3 and f.Data.Quests[1].Progress == 0, "current-template skill quest target/progress changed")
end
-- A23-3: before the first mission is accepted, quest completion is quiet (folded dailies), but still paid.
do
	local initial = saved(0, 0)
	initial.DailyDay = execute(CONFIG_SOURCE, configEnv).DayIndex(os.time())
	initial.Quests = {
		{ Id = "Release", Kind = "Extra", Target = 2, Progress = 1, RewardGold = 10, RewardXP = 5, Text = "x", Unit = "Slime" },
		{ Id = "Kill", Kind = "Daily", Target = 10, Progress = 2, RewardGold = 12, RewardXP = 4, Text = "y", Unit = "Slime" },
		{ Id = "Gold", Kind = "Daily", Target = 100, Progress = 3, RewardGold = 12, RewardXP = 4, Text = "z", Unit = "Slime" },
	}
	local f = fixture(initial)
	local notices, gold = #f.Notices, f.Data.BankGold
	f.Services.CombatService.Released:Fire(f.Player, { Auto = false, MonstersHit = 1 }); f:Publish()
	check(f.Data.BankGold == gold + 10 and f.Data.Quests[1].Id ~= nil, "pre-acceptance extra quest was not paid/replaced")
	check(#f.Notices == notices, "pre-acceptance quest completion showed a toast")
	check(f.Data.TutorialStep == 0, "quest completion accepted the first mission")
end
do
	local f = fixture()
	check(f.Data.WeaponOwnedMask == 1 and f.Data.WeaponTier == 1 and f.Data.BlacksmithVisited == false,
		"new player does not start with exactly the free weapon and no visit")
	check(table.find(f.Config.Data.Mirrored, "WeaponOwnedMask") ~= nil
		and table.find(f.Config.Data.Mirrored, "BlacksmithVisited") ~= nil, "new shop state is not mirrored")
	local record = f:SaveAndRejoin()
	check(record.WeaponOwnedMask == 1 and f.Data.WeaponOwnedMask == 1, "new ownership changed after save/reload")
end
-- Post-transaction states come from the separately tested ShopService contract. These
-- checks exercise actual DataService save/release/load; they do not run another trade.
for _, row in {
	{ Label = "direct iron purchase", Tier = 3, Mask = 5 },
	{ Label = "both weapons retained while starter equipped", Tier = 1, Mask = 7 },
	{ Label = "unequipped wood sold", Tier = 3, Mask = 5 },
	{ Label = "equipped iron sold, wood retained", Tier = 1, Mask = 3 },
	{ Label = "all saleable weapons sold", Tier = 1, Mask = 1 },
} do
	local initial = saved(99, 5)
	initial.Level, initial.WeaponTier, initial.WeaponOwnedMask = 5, row.Tier, row.Mask
	initial.BlacksmithVisited, initial.CarriedGold, initial.BankGold = true, 95, 250
	local f = fixture(initial)
	check(f.Data.WeaponOwnedMask == row.Mask and f.Data.WeaponTier == row.Tier, row.Label .. " changed on load")
	local record = f:SaveAndRejoin()
	check(record.WeaponOwnedMask == row.Mask and record.WeaponTier == row.Tier, row.Label .. " serialized wrong ownership")
	check(f.Data.WeaponOwnedMask == row.Mask and f.Data.WeaponTier == row.Tier, row.Label .. " resurrected/lost a weapon")
	check(f.Data.BlacksmithVisited == true and f.Data.CarriedGold == 95 and f.Data.BankGold == 250,
		row.Label .. " changed visit or gold after reload")
	f:SaveAndRejoin()
	check(f.Data.WeaponOwnedMask == row.Mask, row.Label .. " migration was not idempotent")
end
do
	local initial = saved(99, 5); initial.Level, initial.WeaponTier = 12, 4
	local f = fixture(initial)
	check(f.Data.WeaponTier == 4 and f.Data.WeaponOwnedMask == 9, "legacy rare weapon was lost or earlier tiers were invented")
	local record = f:SaveAndRejoin()
	check(record.WeaponOwnedMask == 9 and f.Data.WeaponTier == 4 and f.Data.WeaponOwnedMask == 9,
		"legacy rare weapon did not survive serialization/reload")
	check(bit32.band(f.Data.WeaponOwnedMask, 6) == 0, "legacy migration granted unproven wood/iron ownership")
end
-- B4 (A23-12, Data Version 3): Config.MaxWeaponTier = 8 (tier 8 = the slime legendary, mask bit 7). A valid mask is an
-- integer in 1..255; anything else (non-number, NaN, +-inf, fraction, < 1, or any bit above tier 8) is corruption and
-- becomes the starting weapon plus the equipped tier's bit. Equipped tier 3 below -> corrupted rows give 1|4 = 5.
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	check(cfg.MaxWeaponTier == 8 and #cfg.Weapons == 8, "fixture expects 8 weapon tiers (Config.MaxWeaponTier)")
	check(cfg.Weapons[8].Legend == true, "tier 8 is not the slime legendary")
end
for _, row in {
	{ Value = 0, Expected = 5 }, { Value = -1, Expected = 5 }, { Value = 0/0, Expected = 5 },
	{ Value = math.huge, Expected = 5 }, { Value = -math.huge, Expected = 5 },
	{ Value = "7", Expected = 5 }, { Value = false, Expected = 5 }, { Value = {}, Expected = 5 },
	{ Value = 7.9, Expected = 5 },
	{ Value = 128, Expected = 133 }, -- legendary bit kept, plus the starter and equipped bits
	{ Value = 255, Expected = 255 }, { Value = 127, Expected = 127 }, { Value = 129, Expected = 133 },
	{ Value = 256, Expected = 5 }, { Value = 260, Expected = 5 }, { Value = 511, Expected = 5 }, -- a tier-9 bit is never tier 8
	{ Value = 4294967295, Expected = 5 }, -- 0xFFFFFFFF must not grant every weapon
	{ Value = 4294967423, Expected = 5 }, { Value = 4294967303, Expected = 5 },
	{ Value = 9007199254740991, Expected = 5 }, { Value = 1e300, Expected = 5 },
} do
	local initial = saved(99, 5); initial.WeaponTier, initial.WeaponOwnedMask = 3, row.Value
	local f = fixture(initial)
	check(f.Data.WeaponOwnedMask == row.Expected, "invalid ownership was not safely normalized: "
		.. tostring(row.Value) .. " -> " .. tostring(f.Data.WeaponOwnedMask) .. " (expected " .. row.Expected .. ")")
	local record = f:SaveAndRejoin()
	check(record.WeaponOwnedMask == row.Expected and f.Data.WeaponOwnedMask == row.Expected,
		"normalized ownership did not serialize/reload safely")
end
for _, row in {
	{ Value = 0/0, Tier = 1, Mask = 1 }, { Value = math.huge, Tier = 1, Mask = 1 },
	{ Value = -math.huge, Tier = 1, Mask = 1 }, { Value = -2, Tier = 1, Mask = 1 },
	{ Value = "4", Tier = 1, Mask = 1 }, { Value = false, Tier = 1, Mask = 1 },
	-- B4: out-of-range or fractional tiers become the free weapon (never clamped: tier 9/99 must not become the legendary)
	{ Value = 3.8, Tier = 1, Mask = 1 }, { Value = 99, Tier = 1, Mask = 1 }, { Value = 9, Tier = 1, Mask = 1 },
	{ Value = 0, Tier = 1, Mask = 1 }, { Value = 8.5, Tier = 1, Mask = 1 },
	-- valid tiers keep their ownership bit (tier 8 = the legendary, bit 7)
	{ Value = 8, Tier = 8, Mask = 129 }, { Value = 7, Tier = 7, Mask = 65 },
} do
	local initial = saved(99, 5); initial.WeaponTier = row.Value
	local f = fixture(initial)
	check(f.Data.WeaponTier == row.Tier and f.Data.WeaponOwnedMask == row.Mask, "invalid equipped tier normalization failed: "
		.. tostring(row.Value) .. " -> " .. tostring(f.Data.WeaponTier) .. "/" .. tostring(f.Data.WeaponOwnedMask))
	local record = f:SaveAndRejoin()
	check(record.WeaponTier == row.Tier and f.Data.WeaponOwnedMask == row.Mask, "invalid tier survived serialization")
end
for _, value in { 1, 0, "true", {}, 0/0, math.huge } do
	local initial = saved(99, 5); initial.BlacksmithVisited = value
	local f = fixture(initial); check(f.Data.BlacksmithVisited == false, "nonboolean visit bypassed the actual visit condition")
	local record = f:SaveAndRejoin()
	check(record.BlacksmithVisited == false and f.Data.BlacksmithVisited == false, "invalid visit survived serialization")
end
-- B4 (A23-12): save data Version 3. v2 -> v3 changes no fields; v1 -> v2 -> v3 runs every step; a record saved by a
-- newer server (Version > 3) is refused without a write or a session lock (CR-L3).
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	check(cfg.Data.Version == 3 and cfg.Data.Defaults.Version == 3, "Config.Data.Version / Defaults.Version is not 3")
	check(cfg.Data.Defaults.DailyLevel == 0, "additive DailyLevel default is not 0")
	local fresh = fixture()
	check(fresh.Data.Version == 3, "fresh record is not Version 3")
	local record = fresh:SaveAndRejoin()
	check(record.Version == 3 and fresh.Data.Version == 3, "fresh record did not save as Version 3")
	-- v2 record with a legendary, enhancement, items and loot flags: only Version changes
	local v2 = saved(99, 5)
	v2.Level, v2.WeaponTier, v2.WeaponOwnedMask, v2.CarriedGold, v2.BankGold = 7, 8, 135, 33, 444
	v2.WeaponEnhance = { 2, 0, 5, 0, 0, 0, 0, 9 }
	v2.Items = { Jelly = 4, Enh70 = 2 }
	v2.LootFlags = { FirstScroll = true }
	local f = fixture(v2)
	check(f.Data.Version == 3, "v2 record did not migrate to Version 3")
	check(f.Data.WeaponTier == 8 and f.Data.WeaponOwnedMask == 135 and f.Data.Level == 7
		and f.Data.CarriedGold == 33 and f.Data.BankGold == 444, "v2 -> v3 changed weapon/level/gold fields")
	check(encode(f.Data.WeaponEnhance) == encode(v2.WeaponEnhance) and encode(f.Data.Items) == encode(v2.Items)
		and f.Data.LootFlags.FirstScroll == true, "v2 -> v3 changed enhancement/items/loot flags")
	local stored = f:SaveAndRejoin()
	check(stored.Version == 3 and stored.WeaponTier == 8 and stored.WeaponOwnedMask == 135, "v3 record serialized wrong")
	check(f.Data.Version == 3 and f.Data.WeaponTier == 8 and f.Data.WeaponOwnedMask == 135, "v3 reload not idempotent")
	-- v1 record (SwordTier) runs both steps
	local v1 = { Version = 1, Level = 6, SwordTier = 3, Faction = "Halo", TutorialStep = 99 }
	local g = fixture(v1)
	check(g.Data.Version == 3 and g.Data.WeaponTier == 3 and g.Data.SwordTier == nil and g.Data.WeaponOwnedMask == 5,
		"v1 -> v2 -> v3 migration lost the renamed weapon tier or the version")
	-- newer-than-this-server records are refused and never rewritten
	for _, version in { 4, 99 } do
		local newer = saved(99, 5); newer.Version, newer.WeaponTier, newer.WeaponOwnedMask = version, 9, 511
		local h = fixture(newer, { AllowRefused = true })
		local row = h.Rows["P_" .. h.Player.UserId]
		check(h.Refused == true, "Version " .. version .. " record was loaded by a Version 3 server")
		check(row.Version == version and row.WeaponTier == 9 and row.WeaponOwnedMask == 511 and row.SessionLock == nil
			and row.SessionToken == nil, "Version " .. version .. " record was rewritten or locked")
	end
end
if #failures > 0 then
	for _, message in failures do print("CONTRACT_FAILURE " .. message) end
	print("ONBOARDING_OFFLINE_FAILED checks=" .. checks .. " failures=" .. #failures)
	error("onboarding contract failures: " .. #failures, 0)
end
print("ONBOARDING_OFFLINE_OK checks=" .. checks)
