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
	-- Clock: os.clock() as QuestService sees it (F10-4 safety-net timer); the other services keep the real clock
	local f = { Zone = "HaloTown", Alive = true, Ready = true, RateAllowed = true, Loops = {}, LoopOrder = {}, Delayed = {},
		Notices = {}, NoticeLog = {}, Rows = {}, Remote = {}, Sends = 0, Spawned = {}, Panels = {}, Clock = 1000,
		Character = { Name = "Body1" }, FxLog = {}, Travels = {}, TravelOk = true }
	local config = execute(CONFIG_SOURCE, configEnv)
	f.Config = config
	-- A23-74: the forge trip lands at the Crossroads spawn here (no Vector3 / CFrame doubles; test_weapon_first checks
	-- the spot in front of the anvil)
	config.Tutorial.Forge.Landing = "Spawn"
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
		if coroutine.status(co) ~= "dead" then
			if f.Loops[co] == nil and not table.find(f.LoopOrder, co) then table.insert(f.LoopOrder, co) end
			f.Loops[co] = delay
		else
			f.Loops[co] = nil
		end
	end
	local taskMock = { spawn = function(fn, ...)
		local args = table.pack(...); local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end); resume(co)
	end, wait = function(delay) return coroutine.yield(delay or 0) end,
		delay = function(_, fn) table.insert(f.Delayed, fn) end, defer = function(fn, ...) fn(...) end }
	local util = { DeepCopy = copy, Warn = function(tag, msg) if tag ~= "DataService" then error(tag .. ": " .. msg) end end,
		IsAlive = function() return f.Alive end, FormatNumber = tostring, Now = function() return 100 end,
		GetCharacter = function() return f.Character end,
		-- A23-74: no root and no anvil here (QuestService's forge trip lands at the Crossroads only: tools/test_weapon_first.py
		-- checks the spot in front of the anvil)
		GetRoot = function() return nil end,
		FlatDistance = function(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end,
		RateLimit = function() return f.RateAllowed end,
		Signal = { new = signal }, -- A23-88: QuestService.ForgeReached
		Random = { NextNumber = function(_, a, b) return a and (a + b) / 2 or 0.5 end, NextInteger = function(_, a) return a end } }
	local net = { Get = function(name)
		if not f.Remote[name] then f.Remote[name] = { OnServerEvent = signal(), FireClient = function(_, p, payload)
			check(p == f.Player, "publication leaked to wrong player")
			-- A23-81: the payload is { Quests = rows, Book } (an older server sent the JSON of the rows)
			if name == "Quests" then
				f.LastList = copy(type(payload) == "table" and payload.Quests or f.Encoding)
				f.Sends += 1
			elseif name == "OpenPanel" then table.insert(f.Panels, payload)
			else error("unexpected server publication " .. name) end
		end } end
		return f.Remote[name]
	end, Fx = function(p, kind, data)
		check(p == f.Player, "Fx leaked to the wrong player")
		table.insert(f.FxLog, { Kind = kind, Data = data })
	end, Notify = function(p, message, kind, secs)
		table.insert(f.Notices, message)
		table.insert(f.NoticeLog, { Player = p, Text = message, Kind = kind, Secs = secs })
	end }
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
		ClassService = { ClassChanged = signal() }, ZoneService = { ZoneChanged = signal(), GetZoneId = function() return f.Zone end,
			-- A23-68 #1: the accepted mission's move to the meadow (an instant Travel); arriving fires ZoneChanged
			Travel = function(p, dest, instant)
				table.insert(f.Travels, { Dest = dest, Instant = instant })
				if not f.TravelOk then return false end
				f.Zone = dest
				f.Services.ZoneService.ZoneChanged:Fire(p, dest)
				return true
			end },
		CombatService = { Released = signal() }, GooseService = { GooseFinished = signal() },
		PvPService = { PlayerKO = signal(), IsRookie = function() return true end }, KaijuService = { KaijuEnded = signal() },
		-- A23-74: the Crossroads anvil is there (f.NoAnvil = true: the weapon shop closed, the gift comes at once)
		ShopService = { Anvil = function()
			if f.NoAnvil then return nil end
			return { __kind = "Instance", Position = { X = 39, Y = 1.5, Z = 45 }, Size = { X = 4, Y = 3, Z = 2 },
				IsA = function(_, kind) return kind == "BasePart" end }
		end } }
	local questEnv = table.clone(env)
	questEnv.os = setmetatable({ clock = function() return f.Clock end }, { __index = os })
	local quest = execute(QUEST_SOURCE, questEnv); quest.Init(registry); quest.Start()
	ps.PlayerReady:Fire(f.Player, f.Data)
	f.Services, f.DataService, f.Quest = registry, dataService, quest
	-- loops run in the order they were started (QuestService: publish, then tutorial), so every run is the same
	function f:Tick()
		local list = {}
		for _, co in self.LoopOrder do
			local delay = self.Loops[co]
			if delay ~= nil and delay <= 1 then table.insert(list, co) end
		end
		for _, co in list do resume(co) end
	end
	function f:Publish() self:Tick(); self:Tick() end
	-- F10-4: move QuestService's clock on one second per loop tick (the 1 s tutorial loop runs once per Tick)
	function f:Advance(seconds) for _ = 1, seconds do self.Clock += 1; self:Tick() end end
	function f:Kill(kind, personal, zone)
		monster.MonsterKilled:Fire(self.Player, { Kind = kind or "Slime", Personal = personal == true, ZoneId = zone or "SlimeMeadow", Golden = false })
		self:Publish()
	end
	function f:Choose()
		ps.SetStat(self.Player, "Faction", "Halo"); ps.SetStat(self.Player, "ClassChosen", true)
		registry.ClassService.ClassChanged:Fire(self.Player)
	end
	-- A23-74: own the first weapon (a save from before A23-34, or one past the Forge step): [Accept] goes to step 1
	function f:Arm() ps.SetStat(self.Player, "WeaponOwnedMask", 1); ps.SetStat(self.Player, "WeaponTier", 1) end
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
	-- 3rd idea round #3: the row names the side's guide (there is no 'Guide' NPC to look for)
	check(string.find(f.LastList[1].Text, "Hallie", 1, true) ~= nil, "pending guide is not discoverable")
	check(f.LastList[1].ShortName == "Meet Hallie" and f.LastList[1].Text == "Tap here: first quest from Hallie",
		"3rd idea round #3: the welcome row names the guide ('Meet Hallie', 'Tap here: first quest from Hallie'): "
			.. tostring(f.LastList[1].ShortName) .. " / " .. tostring(f.LastList[1].Text))
	f:Publish(); f.Services.PlayerService.CharacterSpawned:Fire(f.Player)
	for _, fn in f.Delayed do fn() end; f:Publish()
	check(#f.Panels == 1 and f.Data.TutorialStep == 0, "closed welcome auto-reopened/accepted")
	f:Request(); check(#f.Panels == 2 and f.Data.TutorialStep == 0, "request did not reopen without accepting")
	-- A23-74 (user 2026-10-07 "무기를 제일 먼저"): a bare-handed acceptance goes to the Forge step first
	local TT, SN = f.Config.Tutorial.Text, f.Config.Tutorial.ShortNames
	f:Accept(); f:Publish()
	check(f.Data.TutorialStep == 3 and f.LastList[1].TutorialStep == 3 and f.LastList[1].Text == TT.Forge
		and f.LastList[1].ShortName == SN.Forge and f.LastList[1].CanClaim == false and f.LastList[1].ShowProgress == false,
		"A23-74: a bare-handed accept pins the Forge row (step 3, 'To the Forge', not claimable)")
	check(#f.FxLog == 0 and #f.Travels == 0, "A23-88: a bare-handed accept starts no trip (no Fx Travel, nobody moved)")
	f:Claim(); check(f.Data.BankGold == 0 and f.Data.TutorialStep == 3, "A23-74: the Forge row pays nothing")
	check(#f.Travels == 0 and f.Data.TutorialStep == 3, "A23-88: nobody moved, still step 3")
	f:ZoneTo("SlimeMeadow"); f:Kill()
	check(f.Data.TutorialStep == 3 and f.Data.TutorialKills == 0, "A23-74: the meadow before the Forge credits no kill")
	check(f.Quest.ForgeGift(f.Player) == true and f.Data.TutorialStep == 2,
		"A23-74: the gift moves the mission on (standing in the meadow: straight to the hunt)")
	check(f.Notices[#f.Notices - 1] == TT.ForgeGift, "A23-74: Otto's gift line", tostring(f.Notices[#f.Notices - 1]))
	check(f.Quest.ForgeGift(f.Player) == false, "A23-74: no second gift after the Forge step")
	f = fixture(); f:Choose(); f:Publish(); f:Arm()
	f:Accept(); f:Publish()
	check(f.Data.TutorialStep == 1 and f.LastList[1].TutorialStep == 1, "accept did not pin meadow travel")
	check(f.LastList[1].ShortName == f.Config.Tutorial.ShortNames.Travel, "the travel row's ShortName")
	check(f.LastList[1].CanClaim == false and f.LastList[1].ShowProgress == false, "travel is claimable/fake counter")
	f:Claim(); check(f.Data.BankGold == 0, "travel guidance paid gold")
	check(#f.Spawned == 0 and f.Data.TutorialKills == 0, "a personal town slime was spawned/credited")
	check(f.LastList[1].TutorialStep == 1 and f.LastList[1].CanClaim == false, "travel is not pinned")
	f:ZoneTo("SlimeMeadow"); check(f.LastList[1].Target == 5 and f.LastList[1].Progress == 0, "meadow entry does not show hunt")
	check(f.LastList[1].ShortName == f.Config.Tutorial.ShortNames.Quest, "the first mission row's ShortName ('Supply road')")
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
		check(f.LastList[1].CanClaim == false and string.find(f.LastList[1].Text, "Forge") ~= nil, "blacksmith followup missing")
	end
end
-- A23-34: an anvil visit before the claim does not count for M1_1 (the first weapon waits for a visit with the jelly)
do
	local initial = saved(2, 5)
	initial.Version, initial.WeaponTier, initial.WeaponOwnedMask, initial.BlacksmithVisited = 3, 0, 0, true -- bare-handed
	local f = fixture(initial)
	check(f.Data.BlacksmithVisited == true and f.Data.WeaponOwnedMask == 0, "fixture: bare-handed, anvil visited before the claim")
	f:Claim()
	local T = f.Config.Tutorial.Text
	check(f.Data.TutorialStep == 99 and f.Data.BlacksmithVisited == false,
		"bare-handed: the claim clears an earlier anvil visit (M1_1 waits for a smithy visit after the first mission)")
	check(f.LastList[1].Text == T.VisitBlacksmith, "bare-handed: the pinned row promises the first weapon", f.LastList[1].Text)
	check(f.LastList[1].ShortName == f.Config.Tutorial.ShortNames.Forge, "the forge row's ShortName")
	local last = f.Notices[#f.Notices]
	check(last == string.format(T.Claimed, tostring(f.Config.Tutorial.QuestRewardGold)), "bare-handed: the Claimed line", last)
end
-- A23-74: the first weapon came at the Forge step, so every claim clears the earlier visit (M1_1 = a new visit with the
-- jelly) and the claim line points to the next weapon; a save that owns a better weapon already gets "check the gear"
do
	local initial = saved(2, 5); initial.BlacksmithVisited = true -- Version 2: owns tier 1 after migrate
	local f = fixture(initial)
	f:Claim()
	local T = f.Config.Tutorial.Text
	check(f.Data.TutorialStep == 99 and f.Data.BlacksmithVisited == false and f.Data.WeaponOwnedMask == 1,
		"A23-74: a tier-1 owner's claim clears the anvil visit too (M1_1 needs a new one)")
	local last = f.Notices[#f.Notices]
	check(last == string.format(T.Claimed, tostring(f.Config.Tutorial.QuestRewardGold)),
		"A23-74: a tier-1 owner gets the next-weapon line", last)
	local h = saved(2, 5); h.Version, h.WeaponTier, h.WeaponOwnedMask, h.BlacksmithVisited = 3, 2, 3, true
	local k = fixture(h)
	k:Claim()
	check(k.Data.BlacksmithVisited == false and k.Notices[#k.Notices] == string.format(T.ClaimedArmed, tostring(k.Config.Tutorial.QuestRewardGold)),
		"A23-74: a save that owns the tier-2 weapon already: the 'check the gear' line", k.Notices[#k.Notices])
	local g = fixture(saved(99, 5)) -- step 99, tier 1 owned, no visit yet: the row has no first-weapon promise
	check(g.LastList[1].Text == T.VisitBlacksmithArmed, "a tier-1 owner's pinned row: 'check the weapons'", g.LastList[1].Text)
end
for _, test in { { -4, 0 }, { 2.8, 2 }, { 99, 5 }, { "4", 0 }, { 0/0, 0 }, { math.huge, 0 }, { -math.huge, 0 } } do
	local f = fixture(saved(2, test[1])); check(f.Data.TutorialKills == test[2], "invalid saved kills not normalized")
end
do
	local f = fixture({ Version = 2, Level = 9 }); check(f.Data.TutorialStep == 99 and f.Data.TutorialKills == 0, "legacy save reopened onboarding")
	for _, step in { 4, -1, 0/0, math.huge } do local g = fixture(saved(step, 4)); check(g.Data.TutorialStep == 99, "invalid step remained stuck") end
	-- A23-74: 3 is the Forge step now (accepted, on the way to the first weapon): kept like the other accepted steps
	local k = fixture(saved(3, 0)); check(k.Data.TutorialStep == 3, "A23-74: the Forge step was reset at load")
	local record = k:SaveAndRejoin()
	check(record.TutorialStep == 3 and k.Data.TutorialStep == 3, "A23-74: the Forge step did not survive save/reload")
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
	-- A23-74: bare-handed, the weapon comes first even when the acceptance happens in the meadow (no kill credited)
	g:Accept(); check(g.Data.TutorialStep == 3 and g.Data.TutorialKills == 0, "A23-74: a bare-handed meadow acceptance skipped the Forge")
	g:Kill(); check(g.Data.TutorialStep == 3 and g.Data.TutorialKills == 0, "A23-74: a meadow kill before the Forge counted")
end
-- Tutorial acceptance is the only step0 transition; no client arguments can select a faction, stage or reward.
for _, faction in { "Halo", "Horns", "Neutral" } do
	local initial = saved(0, 0); initial.Faction = faction
	local f = fixture(initial)
	local welcome = f.Config.Tutorial.Welcome[faction]
	-- ⑪ (lines_pack §1-3) + 3rd idea round #2: the mission card page and the catchphrase page (A23-99: two pages only)
	check(type(welcome.Name) == "string" and #welcome.Lines == 2, faction .. " guide has no two-page dialogue (card + the catchphrase)")
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
for _, step in { 1, 2, 3, 99 } do
	local f = fixture(saved(step, 4)); f:Request(); f:Accept(); f:Publish()
	check(f.Data.TutorialStep == step and f.Data.TutorialKills == 4 and #f.Panels == 0,
		"existing accepted/completed save was reopened or reset")
	-- A23-88: no step asks for a trip any more (the row's tap at the Forge step is the client's path light)
	local trips = 0
	for _, fx in f.FxLog do if fx.Kind == "Travel" then trips += 1 end end
	check(trips == 0, "A23-88: RequestTutorial asks for no trip at any step (step " .. step .. ": " .. trips .. ")")
end
do
	local f = fixture(saved(99, 5)); f:Publish(); check(f.LastList[1].CanClaim == false, "post-reward hint is claimable")
	f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 2)
	f.Services.PlayerService.SetStat(f.Player, "WeaponOwnedMask", 3); f:Publish()
	check(string.find(f.LastList[1].Text, "Forge") ~= nil, "weapon tier incorrectly replaced the actual visit condition")
	f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 1)
	f.Services.PlayerService.SetStat(f.Player, "BlacksmithVisited", true); f:Publish()
	-- A23-3: after the visit the pinned row stays as one next-goal line computed from existing state (no reward).
	local T, iron, woods = f.Config.Tutorial.Text, f.Config.Weapons[3], f.Config.Zones.GoblinWoods
	local SN = f.Config.Tutorial.ShortNames
	local function nextGoal(context, expected, short)
		local row = f.LastList[1]
		check(row.Pinned == true and row.Id == "tutorial" and row.NextGoal == true, context .. " lost the pinned next-goal row")
		check(row.Text == expected, context .. " next-goal text mismatch: " .. tostring(row.Text) .. " ~= " .. expected)
		check(type(short) == "string" and row.ShortName == short and #short <= 14,
			context .. " next-goal ShortName mismatch: " .. tostring(row.ShortName) .. " ~= " .. tostring(short))
		check(row.CanClaim == false and row.ShowProgress == false and row.RewardGold == 0 and row.RewardXP == 0,
			context .. " next goal became claimable or advertised a reward")
		check(#f.LastList == f.Config.Quests.Slots + 1, context .. " hid ordinary quest slots")
		for i = 2, #f.LastList do check(f.LastList[i].Pinned ~= true, context .. " pinned a second row") end
	end
	local function gold() return tostring(math.floor(f.Data.CarriedGold + f.Data.BankGold)) end
	-- the real Config has the guide-finished line off (Nudges.GuideDone, 검수 10/09): this block checks the rule, so turn it on
	f.Config.Nudges.GuideDone = true
	local function guideDone()
		local n = 0
		for _, message in f.Notices do if message == T.GuideDone then n += 1 end end
		return n
	end
	check(iron.MinLevel == 5 and woods.MinLevel == 10, "next-goal fixture expects iron Lv5 and Goblin Woods Lv10")
	-- A23-71 D6 / S16: the first skill comes at the iron weapon's level (Lv5), so a Lv1 without Q sees both in one line
	check(f.Config.Skills.Unlock.Q == iron.MinLevel and f.Data.SkillSlots == 0, "S16 fixture expects Q at the iron level and no Q yet")
	local function goalKind(context, kind)
		check(f.LastList[1].GoalKind == kind, context .. " GoalKind mismatch: " .. tostring(f.LastList[1].GoalKind) .. " ~= " .. kind)
	end
	nextGoal("visit without purchase", string.format(T.NextSkillIron, iron.MinLevel, 1), string.format(SN.SkillIron, iron.MinLevel))
	check(f.LastList[1].Text == "Next goal · Lv5: first skill + Iron weapon (now Lv1)", "S16 wording (D6): "
		.. tostring(f.LastList[1].Text))
	goalKind("visit without purchase", "SkillIron")
	local record = f:SaveAndRejoin()
	check(record.BlacksmithVisited == true and f.Data.BlacksmithVisited == true, "saved blacksmith visit was lost")
	nextGoal("rejoin", string.format(T.NextSkillIron, iron.MinLevel, 1), string.format(SN.SkillIron, iron.MinLevel))
	check(f.Data.WeaponTier == 1, "rejoin forced a purchase/equipment change")
	-- a Lv1 who kept Q (a free class change from Lv5+ took the level back, the slots stay): only the iron weapon is ahead
	f.Services.PlayerService.SetStat(f.Player, "SkillSlots", 1); f:Publish()
	nextGoal("kept Q", string.format(T.NextIronLevel, iron.MinLevel, 1), string.format(SN.IronLevel, iron.MinLevel))
	goalKind("kept Q", "IronLevel")
	f.Services.PlayerService.SetStat(f.Player, "SkillSlots", 0); f:Publish()
	goalKind("Q not kept", "SkillIron")
	f.Services.PlayerService.SetStat(f.Player, "Level", 5); f.Services.ProgressionService.LeveledUp:Fire(f.Player); f:Publish()
	nextGoal("level5", string.format(T.NextIronGold, tostring(iron.Price), gold()), SN.IronGold)
	f.Services.PlayerService.SetStat(f.Player, "CarriedGold", 120); f.Services.PlayerService.SetStat(f.Player, "BankGold", 600); f:Publish()
	nextGoal("level5 gold change", string.format(T.NextIronGold, tostring(iron.Price), "720"), SN.IronGold)
	f.Services.PlayerService.SetStat(f.Player, "Level", 10); f:Publish()
	nextGoal("level10 without iron", string.format(T.NextIronGold, tostring(iron.Price), "720"), SN.IronGold)
	local before = f.Sends; f:Publish(); check(f.Sends == before, "watchdog resends unchanged payload")
	-- iron owned (bought through the separately tested shop contract) below Goblin Woods level -> zone goal
	f.Services.PlayerService.SetStat(f.Player, "Level", 6)
	f.Services.PlayerService.SetStat(f.Player, "WeaponOwnedMask", 5); f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 3); f:Publish()
	nextGoal("iron owned", string.format(T.NextZone, woods.MinLevel, woods.Name, 6), string.format(SN.Zone, woods.MinLevel))
	f.Services.PlayerService.SetStat(f.Player, "WeaponTier", 1); f:Publish()
	nextGoal("owned iron unequipped", string.format(T.NextZone, woods.MinLevel, woods.Name, 6), string.format(SN.Zone, woods.MinLevel))
	-- SKL-3 (skill_kit §2): with the iron weapon owned, the next skill to learn comes before the next zone when it is
	-- earlier (Q; Z / X only while their switch is on)
	local PS = f.Services.PlayerService
	PS.SetStat(f.Player, "Level", 1); f:Publish()
	nextGoal("iron owned, no Q yet", string.format(T.NextSkill, 5, 1), string.format(SN.Skill, 5))
	check(f.LastList[1].Text == "Next goal · New skill at Lv5 (now Lv1)", "SKL-3 next skill wording: " .. tostring(f.LastList[1].Text))
	goalKind("iron owned, no Q yet", "Skill")
	PS.SetStat(f.Player, "SkillSlots", 1); PS.SetStat(f.Player, "Level", 6); f:Publish()
	nextGoal("Q learned, Z switched off", string.format(T.NextZone, woods.MinLevel, woods.Name, 6), string.format(SN.Zone, woods.MinLevel))
	f.Config.Skills.ZEnabled = true; f:Publish()
	nextGoal("Z on at Lv6: the woods (Lv10) first", string.format(T.NextZone, woods.MinLevel, woods.Name, 6), string.format(SN.Zone, woods.MinLevel))
	PS.SetStat(f.Player, "Level", 12); f:Publish()
	nextGoal("Z on at Lv12", string.format(T.NextSkill, 15, 12), string.format(SN.Skill, 15))
	goalKind("Z on at Lv12", "Skill")
	f.Config.Skills.ZEnabled = false
	PS.SetStat(f.Player, "SkillSlots", 0); PS.SetStat(f.Player, "Level", 6); f:Publish()
	nextGoal("back to Lv6 without Q", string.format(T.NextZone, woods.MinLevel, woods.Name, 6), string.format(SN.Zone, woods.MinLevel))
	check(guideDone() == 0, "guide-finished toast fired while a goal remained")
	f.Services.PlayerService.SetStat(f.Player, "Level", 10); f:Publish()
	check(f.LastList[1].Pinned ~= true and #f.LastList == f.Config.Quests.Slots, "finished guide chain kept a pinned row")
	check(guideDone() == 1, "guide-finished toast missing or repeated")
	f:Publish(); f:Publish(); check(guideDone() == 1, "guide-finished toast repeated on unchanged state")
	f:SaveAndRejoin(); f:Publish()
	check(f.LastList[1].Pinned ~= true and guideDone() == 1, "rejoin after the finished guide re-pinned or re-toasted")
	-- Nudges.GuideDone off (the real Config): the chain still ends the same way, with no toast
	f.Config.Nudges.GuideDone = false
	f.Services.PlayerService.SetStat(f.Player, "Level", 6); f:Publish()
	check(f.LastList[1].Pinned == true, "GuideDone off: a goal came back at Lv6 (fixture check)")
	f.Services.PlayerService.SetStat(f.Player, "Level", 10); f:Publish()
	check(f.LastList[1].Pinned ~= true and guideDone() == 1, "Nudges.GuideDone off: the finished guide sends no toast")
end
-- The real QuestService migrates old charged-release quests in both daily and extra slots.
-- Combat signals below are test doubles; this tests service event handling, not real skill hits.
for _, kind in { "Daily", "Extra" } do
	local initial = saved(99, 5)
	initial.BlacksmithVisited = true
	initial.SkillSlots, initial.SkillsA71 = 1, true -- A23-71: this Lv1 player kept Q (a level reset), so a skill daily fits
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
	check(string.find(releaseTemplate.Text, "monster", 1, true) ~= nil, "skill quest template does not require a monster hit")
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
	if kind == "Daily" then
		-- 검수 10/09 (user: too kind): "Daily quest done! Press [Claim]." is a nudge (Config.Nudges.DailyReady), off in the real Config
		local function readyLines()
			local n = 0
			for _, message in f.Notices do if message == f.Config.Text.DailyReady then n += 1 end end
			return n
		end
		check(f.Config.Nudges.DailyReady == false, "Nudges.DailyReady is off in the real Config", tostring(f.Config.Nudges.DailyReady))
		for _ = 1, 8 do f:Kill("Slime") end
		check(f.Data.Quests[2].Progress == 10 and readyLines() == 0, "Nudges.DailyReady off: a finished daily sends no 'Daily quest done' line",
			f.Data.Quests[2].Progress .. " / " .. readyLines())
		f.Config.Nudges.DailyReady = true
		f.Services.CombatService.Released:Fire(f.Player, { Auto = false, MonstersHit = 1 })
		f:Publish()
		check(reloaded.Progress == 5 and readyLines() == 1, "Nudges.DailyReady on: the line comes once when a daily is finished",
			reloaded.Progress .. " / " .. readyLines())
	end
end
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	local template = nil
	for _, def in cfg.Quests.Templates do if def.Id == "Release" then template = def end end
	local text = string.format(template.Text, 3)
	local initial = saved(99, 5)
	initial.BlacksmithVisited, initial.DailyDay = true, cfg.DayIndex(os.time())
	initial.SkillSlots, initial.SkillsA71 = 1, true -- A23-71: this Lv1 player kept Q (a level reset), so a skill quest fits
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
	initial.SkillSlots, initial.SkillsA71 = 1, true -- A23-71: this Lv1 player kept Q (a level reset), so a skill quest fits
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
	-- A23-34 (user 2026-10-06): a new player starts bare-handed (tier 0, nothing owned); M1_1 gives tier 1
	check(f.Data.WeaponOwnedMask == 0 and f.Data.WeaponTier == 0 and f.Data.BlacksmithVisited == false,
		"new player does not start bare-handed (no weapon owned) and no visit")
	check(table.find(f.Config.Data.Mirrored, "WeaponOwnedMask") ~= nil
		and table.find(f.Config.Data.Mirrored, "BlacksmithVisited") ~= nil, "new shop state is not mirrored")
	local record = f:SaveAndRejoin()
	check(record.WeaponOwnedMask == 0 and record.WeaponTier == 0 and f.Data.WeaponOwnedMask == 0 and f.Data.WeaponTier == 0,
		"the bare-handed start changed after save/reload (no weapon may be forced on at load)")
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
-- integer in 0..255; anything else (non-number, NaN, +-inf, fraction, < 0, or any bit above tier 8) is corruption.
-- These rows are Version 2 (saved() = from before A23-34): migrate keeps their always-owned tier 1 (A23-4), so corrupted
-- rows give tier 1 plus the equipped tier's bit. Equipped tier 3 below -> corrupted rows give 1|4 = 5.
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
	-- B4: out-of-range or fractional tiers of a Version 2 save become its tier 1 (never clamped: tier 9/99 must not become
	-- the legendary); A23-34: a Version 2 save's tier 0 is tier 1 too (pre-A23-34 saves always had a weapon)
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
-- newer server is refused without a write or a session lock (CR-L3). A23-69 (검수 2026-10-07): Stats = { Auto, Order }
-- is an additive field: the version stays 3, a record without it gains the default (Auto ON, nothing picked) and
-- nothing else changes.
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	check(cfg.Data.Version == 3 and cfg.Data.Defaults.Version == 3, "Config.Data.Version / Defaults.Version is not 3")
	check(cfg.Data.Defaults.DailyLevel == 0, "additive DailyLevel default is not 0")
	local fresh = fixture()
	check(fresh.Data.Version == 3, "fresh record is not Version 3")
	local record = fresh:SaveAndRejoin()
	check(record.Version == 3 and fresh.Data.Version == 3, "fresh record did not save as Version 3")
	check(type(record.Stats) == "table" and record.Stats.Auto == true and record.Stats.Order == "",
		"fresh record did not save the default Stats (A23-69)")
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
	-- A23-69: a v3 record from before the stat points gains Stats only (still Version 3); a picked build survives the
	-- round trip (its letters A-Z kept, the rest dropped)
	local v3 = saved(99, 5)
	v3.Version, v3.Level, v3.WeaponTier, v3.WeaponOwnedMask, v3.BankGold = 3, 12, 3, 7, 321
	local s3 = fixture(v3)
	check(s3.Data.Version == 3 and s3.Data.Stats.Auto == true and s3.Data.Stats.Order == "" and s3.Data.Level == 12
		and s3.Data.WeaponTier == 3 and s3.Data.BankGold == 321, "a v3 record without Stats got more than the default Stats")
	s3.Data.Stats = { Auto = false, Order = "AHAXa1" }
	local kept = s3:SaveAndRejoin()
	check(kept.Version == 3 and kept.Stats.Auto == false and s3.Data.Stats.Auto == false and s3.Data.Stats.Order == "AHAX",
		"a saved build did not come back (repaired: its letters A-Z kept, the rest dropped)")
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
-- F10-4 safety net (2026-10-06): while TutorialStep == 2 and TutorialKills >= 5, QuestService starts a timer
-- (os.clock = f.Clock, from the first time this server sees it, also right after a rejoin); after
-- Config.Tutorial.AutoClaimSeconds it pays QuestRewardGold once with Text.AutoClaimed. A manual [받기] first clears
-- it, kills < 5 reset it, leaving clears it. The tutorial loop is the fixture's coroutine double (one tick per second).
do
	local cfg = execute(CONFIG_SOURCE, configEnv)
	local T = cfg.Tutorial
	check(T.AutoClaimSeconds == 60, "F10-4 Config.Tutorial.AutoClaimSeconds is 60")
	check(type(T.Text.AutoClaimed) == "string" and string.find(T.Text.AutoClaimed, "%s", 1, true) ~= nil
		and T.Text.AutoClaimed ~= T.Text.Claimed, "F10-4 Text.AutoClaimed is its own line with the gold amount")
	check(type(T.Text.AutoClaimedEn) == "string" and string.find(T.Text.AutoClaimedEn, "%s", 1, true) ~= nil,
		"F10-4 Text.AutoClaimed has its English twin")
end
do
	local function lines(f)
		local gold = tostring(f.Config.Tutorial.QuestRewardGold)
		local T = f.Config.Tutorial.Text
		-- A23-74: only a save that owns a better weapon than the first one gets the lines without the next-weapon promise
		-- (these Version 2 rows own tier 1 only after migrate: the next-weapon lines)
		local armed = bit32.band(math.floor(tonumber(f.Data.WeaponOwnedMask) or 0), bit32.bnot(1)) ~= 0
		return string.format(armed and T.AutoClaimedArmed or T.AutoClaimed, gold), string.format(armed and T.ClaimedArmed or T.Claimed, gold)
	end
	local function count(f, text)
		local n = 0
		for _, message in f.Notices do if message == text then n += 1 end end
		return n
	end
	local function state(f)
		local auto, manual = lines(f)
		return " [step " .. tostring(f.Data.TutorialStep) .. ", kills " .. tostring(f.Data.TutorialKills) .. ", bank "
			.. tostring(f.Data.BankGold) .. ", auto lines " .. count(f, auto) .. ", claimed lines " .. count(f, manual) .. "]"
	end
	local function unpaid(f) return f.Data.TutorialStep == 2 and f.Data.BankGold == 0 end
	local function paidOnce(f, auto)
		local autoText, manualText = lines(f)
		return f.Data.TutorialStep == 99 and f.Data.BankGold == f.Config.Tutorial.QuestRewardGold
			and count(f, autoText) == (if auto then 1 else 0) and count(f, manualText) == (if auto then 0 else 1)
	end

	-- 1. 4/5 never starts it; at 5/5 it pays exactly AutoClaimSeconds later, once, with Text.AutoClaimed
	local f = fixture(saved(2, 0))
	local AUTO = f.Config.Tutorial.AutoClaimSeconds
	for _ = 1, 4 do f:Kill() end
	f:Advance(AUTO * 3)
	check(unpaid(f) and f.Data.TutorialKills == 4, "F10-4 4/5 kills are never auto-claimed (180 s)" .. state(f))
	f:Kill() -- 5/5: the timer starts on the next tutorial tick (same clock)
	f:Advance(AUTO - 1)
	check(unpaid(f) and f.Data.TutorialKills == 5, "F10-4 no auto-claim before AutoClaimSeconds (59 s after 5/5)" .. state(f))
	check(f.LastList[1].CanClaim == true, "F10-4 the [받기] row stays claimable while the safety net waits")
	f:Advance(1)
	check(paidOnce(f, true), "F10-4 at AutoClaimSeconds the safety net pays QuestRewardGold once with Text.AutoClaimed" .. state(f))
	local autoText = lines(f)
	local entry = nil
	for _, e in f.NoticeLog do if e.Text == autoText then entry = e end end
	check(entry ~= nil and entry.Player == f.Player and entry.Kind == "reward", "F10-4 the auto-claim line is a reward notice to that player")
	f:Advance(AUTO * 3); f:Claim()
	check(paidOnce(f, true), "F10-4 the auto-claim pays once (later ticks and a late [받기] pay nothing)" .. state(f))
	check(f.LastList[1].CanClaim == false and string.find(f.LastList[1].Text, "Forge") ~= nil,
		"F10-4 after the auto-claim the pinned row moves on to the blacksmith like a manual claim")
	local record = f:SaveAndRejoin()
	check(record.TutorialStep == 99 and record.BankGold == f.Config.Tutorial.QuestRewardGold,
		"F10-4 the auto-claimed step and gold are saved")
	f:Advance(AUTO * 2); f:Claim()
	check(paidOnce(f, true), "F10-4 a rejoin after the auto-claim pays nothing more" .. state(f))

	-- 2. a manual claim first: the normal Claimed line, and the safety net never pays afterwards
	f = fixture(saved(2, 4)); f:Kill()
	f:Advance(30); f:Claim()
	check(paidOnce(f, false), "F10-4 a [받기] before the timer pays the normal Claimed line" .. state(f))
	f:Advance(AUTO * 3)
	check(paidOnce(f, false), "F10-4 after a manual claim the safety net never pays" .. state(f))
	-- white-box: the claim also clears the timer (a later 5/5 at step 2 counts from 0, not from the first 5/5)
	f.Services.PlayerService.SetStat(f.Player, "TutorialStep", 2)
	f.Services.PlayerService.SetStat(f.Player, "BankGold", 0)
	f:Publish() -- the next tutorial tick (same clock) starts the timer
	f:Advance(AUTO - 1)
	check(f.Data.TutorialStep == 2 and f.Data.BankGold == 0, "F10-4 a manual claim clears the timer" .. state(f))
	f:Advance(1)
	check(f.Data.TutorialStep == 99 and f.Data.BankGold == f.Config.Tutorial.QuestRewardGold,
		"F10-4 a fresh timer after a manual claim still runs" .. state(f))

	-- 3. kills < 5 reset the timer
	f = fixture(saved(2, 5)) -- 5/5 on load: the timer starts at PlayerReady
	f:Advance(50)
	f.Services.PlayerService.SetStat(f.Player, "TutorialKills", 4); f:Advance(1)
	check(unpaid(f), "F10-4 kills < 5 stop the safety net" .. state(f))
	f.Services.PlayerService.SetStat(f.Player, "TutorialKills", 5); f:Advance(1) -- the timer starts again here
	f:Advance(AUTO - 1)
	check(unpaid(f), "F10-4 kills < 5 reset the timer (no auto-claim 59 s after 5/5 again, 111 s after the first)" .. state(f))
	f:Advance(1)
	check(paidOnce(f, true), "F10-4 after a reset the safety net pays AutoClaimSeconds after 5/5 again" .. state(f))

	-- 4. leaving clears the timer (white-box: the same Player object seen again by the tutorial loop starts from 0)
	f = fixture(saved(2, 5))
	f:Advance(50)
	f.Services.PlayerService.PlayerLeaving:Fire(f.Player); f:Advance(1) -- the loop sees the player again: new timer
	f:Advance(AUTO - 1)
	check(unpaid(f), "F10-4 PlayerLeaving clears the timer (no auto-claim 59 s after it, 110 s after 5/5)" .. state(f))
	f:Advance(1)
	check(paidOnce(f, true), "F10-4 a player seen again after PlayerLeaving gets a fresh timer" .. state(f))

	-- 5. a rejoin starts the timer again (an unclaimed 5/5 is saved; leaving pays nothing)
	f = fixture(saved(2, 4)); f:Kill()
	f:Advance(50)
	f:Rejoin()
	check(unpaid(f) and f.Data.TutorialKills == 5, "F10-4 leaving with an unclaimed 5/5 pays nothing and keeps 5/5" .. state(f))
	f:Advance(AUTO - 1)
	check(unpaid(f), "F10-4 after a rejoin the timer starts again (no auto-claim 59 s after the rejoin)" .. state(f))
	f:Advance(1)
	check(paidOnce(f, true), "F10-4 after a rejoin the safety net pays AutoClaimSeconds after the rejoin" .. state(f))

	-- 6. only step 2 is ever auto-claimed (pending, travel and finished missions with 5 saved kills)
	for _, step in { 0, 1, 99 } do
		local g = fixture(saved(step, 5))
		local bank = g.Data.BankGold
		g:Advance(AUTO * 3)
		check(g.Data.TutorialStep == step and g.Data.BankGold == bank and count(g, (lines(g))) == 0,
			"F10-4 the safety net never pays outside step 2 (step " .. step .. ")" .. state(g))
	end
end
-- A23-88 (replaces A23-68 #1 / A23-74's trips): nothing moves the player; #4: until the first [Claim] every other quest
-- row is folded
do
	local f = fixture(); f:Choose(); f:Publish(); f:Arm() -- A23-74: the first weapon in hand (no Forge step)
	local T = f.Config.Tutorial
	check(T.AcceptTravelSeconds == nil and T.RespawnInMeadow == true and T.FoldOthers == true and T.Forge.TravelDelay == nil,
		"A23-88 Config.Tutorial: no accept trip, respawn in the meadow, fold the other rows")
	local before = #f.Delayed
	f:Accept(); f:Publish()
	check(f.Data.TutorialStep == 1 and #f.Travels == 0, "A23-88 accept: step 1, nobody moved")
	check(#f.FxLog == 0 and f.Player:GetAttribute("MoveLockUntil") == nil and #f.Delayed == before,
		"A23-88 accept: no Fx Travel, no lock, nothing delayed (the pad / the map is the lesson)")
	check(f.LastList[1].Text == T.Text.Travel and f.LastList[1].ShortName == T.ShortNames.Travel, "A23-88: the row says 'Travel to Squishy Meadow - the glowing pad (or Map)'",
		tostring(f.LastList[1].Text))
	local folded, open = 0, 0
	for _, row in f.LastList do
		if row.Id == "tutorial" then
			if row.Folded ~= nil then open = -99 end
		elseif row.Folded == true then
			folded += 1
		else
			open += 1
		end
	end
	check(folded == f.Config.Quests.Slots and open == 0, "A23-68 #4: before the first claim every other row is folded")
	f:ZoneTo("SlimeMeadow") -- the player's own travel (the pad, Map -> Travel) or a walk lands in the meadow
	check(f.Data.TutorialStep == 2 and f.LastList[1].Target == 5, "A23-88: arriving in the meadow starts the first mission's hunt (step 2)")
	for _ = 1, 5 do f:Kill() end
	f:Claim()
	check(f.Data.TutorialStep == 99, "A23-68: the first mission is claimed")
	local stillFolded = 0
	for _, row in f.LastList do if row.Folded ~= nil then stillFolded += 1 end end
	check(stillFolded == 0, "A23-68 #4: after the first claim nothing is folded")
	local m = fixture(); m:Choose(); m.Zone = "SlimeMeadow"; m:Publish(); m:Arm()
	local mBefore = #m.Delayed
	m:Accept(); m:Publish()
	check(m.Data.TutorialStep == 2 and #m.Delayed == mBefore and #m.FxLog == 0 and m.Player:GetAttribute("MoveLockUntil") == nil,
		"A23-68: accepting in the meadow moves nobody (no fade, no lock)")
	-- A23-74 / A23-88: bare-handed: [Accept] -> walk to the Forge -> the gift -> travel to the meadow -> the hunt
	local w = fixture(); w:Choose(); w:Publish()
	local wBefore = #w.Delayed
	w:Accept(); w:Publish()
	check(w.Data.TutorialStep == 3 and #w.Delayed == wBefore and #w.FxLog == 0 and w.Player:GetAttribute("MoveLockUntil") == nil
		and w.LastList[1].Text == T.Text.Forge, "A23-88: the Forge step: 'Go to Otto's Forge', no trip, no lock")
	check(w.Quest.ForgeGift(w.Player) == true and w.Data.TutorialStep == 1 and #w.FxLog == 0 and #w.Delayed == wBefore,
		"A23-88: the gift: step 1, no meadow trip (the Stronger! moment, then the pad lesson)")
	w:Publish()
	check(w.LastList[1].Text == T.Text.Travel and w.Data.TutorialStep == 1, "A23-88: the row now teaches the travel pad", tostring(w.LastList[1].Text))
	w:ZoneTo("SlimeMeadow")
	check(w.Zone == "SlimeMeadow" and w.Data.TutorialStep == 2 and w.LastList[1].Target == 5,
		"A23-88: arriving in the meadow by the pad / the map / a walk starts the hunt (step 2)")
	-- PlayerService.respawnZoneId: the meadow entrance while the first mission runs, else home
	local function cut(source, header)
		local a = assert(string.find(source, header, 1, true), header)
		local b = assert(string.find(source, "\nend\n", a, true), header .. " end")
		return string.sub(source, a, b + 4)
	end
	local chunk = "local S, Config = ...\n" .. cut(PLAYER_SOURCE, "local function stat(")
		.. cut(PLAYER_SOURCE, "local function respawnZoneId(") .. "\nreturn respawnZoneId\n"
	local data = { Faction = "Halo" }
	local who = { GetAttribute = function() return nil end }
	local fn = assert(loadstring(chunk))
	local respawnZoneId = fn({ DataService = { Get = function() return data end } }, f.Config)
	local home = f.Config.HomeZoneId("Halo")
	-- A23-74: the Forge step (3) is a town step: home
	for _, case in { { 0, home }, { 1, "SlimeMeadow" }, { 2, "SlimeMeadow" }, { 3, home }, { 99, home } } do
		data.TutorialStep = case[1]
		check(respawnZoneId(who) == case[2], "A23-68 respawn at step " .. case[1] .. " -> " .. tostring(case[2]))
	end
	data.TutorialStep = 2
	f.Config.Tutorial.RespawnInMeadow = false
	check(respawnZoneId(who) == home, "A23-68 RespawnInMeadow off: home again")
	f.Config.Tutorial.RespawnInMeadow = true
end
if #failures > 0 then
	for _, message in failures do print("CONTRACT_FAILURE " .. message) end
	print("ONBOARDING_OFFLINE_FAILED checks=" .. checks .. " failures=" .. #failures)
	error("onboarding contract failures: " .. #failures, 0)
end
print("ONBOARDING_OFFLINE_OK checks=" .. checks)
