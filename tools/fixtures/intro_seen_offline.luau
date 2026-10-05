-- A23-9 IntroSeen: real Config, Net, DataService and QuestService sources are injected by tools/test_intro_seen.py.
-- Engine events/storage are doubles (offline store, scheduler); this is not a live reconnect test.
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}; for k, x in v do out[k] = copy(x) end; return out
end
local function execute(source, env)
	local fn, err = loadstring(source); assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() })); return fn()
end
local function signal()
	local listeners = {}
	return { Connect = function(_, fn) table.insert(listeners, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in listeners do fn(...) end end }
end
local enum = setmetatable({}, { __index = function(_, key) return setmetatable({}, { __index = function(_, item) return key .. "." .. item end }) end })
local function tuple(...) return { ... } end
local configEnv = { Enum = enum, Color3 = { new = tuple, fromRGB = tuple }, BrickColor = { new = tuple },
	Vector2 = { new = tuple }, Vector3 = { new = tuple }, Rect = { new = tuple }, UDim2 = { fromScale = tuple } }

do
	local realNet = execute(NET_SOURCE, { game = { GetService = function() return {} end } })
	local seen = 0
	for _, name in realNet.Names do if name == "IntroSeen" then seen += 1 end end
	check(seen == 1, "IntroSeen remote missing or duplicated in the Net registry")
	local cfg = execute(CONFIG_SOURCE, configEnv)
	check(cfg.Data.Defaults.IntroSeen == false, "IntroSeen default is not false")
	check(table.find(cfg.Data.Mirrored, "IntroSeen") ~= nil, "IntroSeen is not mirrored to the client")
end

local serial = 0
local function fixture(saved)
	serial += 1
	local f = { Ready = true, Alive = true, RateAllowed = true, Rows = {}, Remote = {}, Loops = {}, Writes = {}, RateCalls = {} }
	local config = execute(CONFIG_SOURCE, configEnv)
	f.Config = config
	local players = {}
	local function newPlayer()
		local p = { Name = "IntroTester", UserId = serial, Parent = players, Attrs = {}, __kind = "Instance" }
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
		if nextValue ~= nil then f.Rows[k] = copy(nextValue) end
		return copy(f.Rows[k])
	end
	local function resume(co)
		local ok, delay = coroutine.resume(co); assert(ok, delay)
		if coroutine.status(co) ~= "dead" then f.Loops[co] = delay else f.Loops[co] = nil end
	end
	local taskMock = { spawn = function(fn, ...)
		local args = table.pack(...); local co = coroutine.create(function() fn(table.unpack(args, 1, args.n)) end); resume(co)
	end, wait = function(delay) return coroutine.yield(delay or 0) end,
		delay = function() end, defer = function(fn, ...) fn(...) end }
	local util = { DeepCopy = copy, Warn = function(tag, msg) if tag ~= "DataService" then error(tag .. ": " .. msg) end end,
		IsAlive = function() return f.Alive end, FormatNumber = tostring, Now = function() return 100 end,
		RateLimit = function(p, key, interval) table.insert(f.RateCalls, { p, key, interval }); return f.RateAllowed end,
		Random = { NextNumber = function(_, a, b) return a and (a + b) / 2 or 0.5 end, NextInteger = function(_, a) return a end } }
	local net = { Get = function(name)
		if not f.Remote[name] then f.Remote[name] = { OnServerEvent = signal(), FireClient = function() end } end
		return f.Remote[name]
	end, Notify = function() end }
	local token = 0
	local services = { Players = players, ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		DataStoreService = { GetDataStore = function() return store end }, RunService = { IsStudio = function() return true end },
		HttpService = { GenerateGUID = function() token += 1; return "session-" .. serial .. "-" .. token end,
			JSONEncode = function() return "[]" end } }
	local env = { game = { JobId = "offline", GetService = function(_, name) return assert(services[name], name) end },
		workspace = {}, task = taskMock, print = function() end,
		typeof = function(v) return type(v) == "table" and v.__kind or type(v) end,
		require = function(name) if name == "Config" then return config elseif name == "Util" then return util elseif name == "Net" then return net end; error(name) end }
	local dataService = execute(DATA_SOURCE, env); dataService.Init({}); dataService.Start()
	f.Data = assert(dataService.Load(f.Player))
	local ps = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterSpawned = signal(),
		IsReady = function(p) return f.Ready and dataService.Get(p) ~= nil end, GetData = dataService.Get,
		GetReadyPlayers = function() return { f.Player } end }
	function ps.SetStat(p, key, value)
		local d = assert(dataService.Get(p)); d[key] = value
		table.insert(f.Writes, { p, key, value })
		if table.find(config.Data.Mirrored, key) then p:SetAttribute(key, value) end
	end
	function ps.AddStat(p, key, amount) local v = (dataService.Get(p)[key] or 0) + amount; ps.SetStat(p, key, v); return v end
	local registry = { PlayerService = ps, DataService = dataService,
		MonsterService = { MonsterKilled = signal() },
		ProgressionService = { GoldEarned = signal(), Rebirthed = signal(), LevelReset = signal(), LeveledUp = signal(),
			AddBankGold = function(p, amount) ps.AddStat(p, "BankGold", amount) end, AddXP = function(p, amount) ps.AddStat(p, "XP", amount) end },
		FactionService = { FactionChanged = signal(), GetFaction = function(p) return dataService.Get(p).Faction end },
		ClassService = { ClassChanged = signal() }, ZoneService = { ZoneChanged = signal(), GetZoneId = function() return "Crossroads" end },
		CombatService = { Released = signal() }, GooseService = { GooseFinished = signal() },
		PvPService = { PlayerKO = signal(), IsRookie = function() return true end }, KaijuService = { KaijuEnded = signal() },
		MonetizationService = { AddTickets = function() end } }
	local quest = execute(QUEST_SOURCE, env); quest.Init(registry); quest.Start()
	ps.PlayerReady:Fire(f.Player, f.Data)
	for _, key in config.Data.Mirrored do f.Player:SetAttribute(key, f.Data[key]) end -- PlayerService mirrors on ready
	f.Writes = {}
	function f:Seen(...) self.Remote.IntroSeen.OnServerEvent:Fire(self.Player, ...) end
	function f:IntroWrites()
		local n = 0; for _, w in self.Writes do if w[2] == "IntroSeen" then n += 1 end end; return n
	end
	function f:SaveAndRejoin()
		check(dataService.Save(self.Player, false), "DataService save failed")
		local record = copy(self.Rows["P_" .. self.Player.UserId])
		ps.PlayerLeaving:Fire(self.Player); dataService.Release(self.Player); self.Player.Parent = nil
		self.Player = newPlayer(); self.Data = assert(dataService.Load(self.Player))
		ps.PlayerReady:Fire(self.Player, self.Data)
		for _, key in config.Data.Mirrored do self.Player:SetAttribute(key, self.Data[key]) end
		self.Writes = {}
		return record
	end
	return f
end

-- 1. A new player starts unseen; the remote with ANY argument (including an explicit nil) is rejected.
do
	local f = fixture()
	check(f.Data.IntroSeen == false and f.Player.Attrs.IntroSeen == false, "new player starts with the intro already seen")
	for _, payload in { table.pack(nil), table.pack(true), table.pack(false), table.pack("seen"), table.pack(1),
		table.pack({}), table.pack(0/0), table.pack(true, true), table.pack(nil, nil) } do
		f:Seen(table.unpack(payload, 1, payload.n))
		check(f.Data.IntroSeen == false and f:IntroWrites() == 0, "IntroSeen remote accepted an argument")
	end
	check(#f.RateCalls == 0, "argument-carrying IntroSeen spent the rate limit before being rejected")
	-- unready / rate-limited requests change nothing
	f.Ready = false; f:Seen(); check(f.Data.IntroSeen == false and f:IntroWrites() == 0, "unready player set IntroSeen")
	f.Ready = true; f.RateAllowed = false; f:Seen()
	check(f.Data.IntroSeen == false and f:IntroWrites() == 0, "rate-limited IntroSeen was accepted")
	local last = f.RateCalls[#f.RateCalls]
	check(last and last[2] == "IntroSeen" and last[3] == 1, "IntroSeen is not rate limited per player (1 s)")
	f.RateAllowed = true
	-- a client-side attribute is not the saved flag: only the server's data decides
	f.Player:SetAttribute("IntroSeen", true)
	check(f.Data.IntroSeen == false, "a client attribute changed the saved flag")
	local record = f:SaveAndRejoin()
	check(record.IntroSeen == false and f.Data.IntroSeen == false, "unseen flag did not survive save/reload as false")
	-- 2. the zero-argument remote sets it exactly once, through the server's SetStat, and it is mirrored
	f:Seen()
	check(f.Data.IntroSeen == true and f.Player.Attrs.IntroSeen == true and f:IntroWrites() == 1, "zero-argument IntroSeen was not saved once")
	for _ = 1, 5 do f:Seen() end
	f:Seen(false)
	check(f.Data.IntroSeen == true and f:IntroWrites() == 1, "IntroSeen was written again or reset")
	record = f:SaveAndRejoin()
	check(record.IntroSeen == true and f.Data.IntroSeen == true and f.Player.Attrs.IntroSeen == true, "IntroSeen did not survive save/reload")
	f:Seen(); check(f:IntroWrites() == 0, "IntroSeen was rewritten after reconnect")
end

-- 3. No other server entry point writes IntroSeen (tutorial / quest / claim remotes, kills, class/faction events).
do
	local f = fixture({ Version = 2, Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 1, TutorialStep = 0 })
	for _, name in { "RequestTutorial", "AcceptTutorial", "ClaimQuest", "RerollQuest", "ClaimVacation" } do
		local remote = f.Remote[name]
		check(remote ~= nil, name .. " remote missing")
		for _, payload in { table.pack(), table.pack(true), table.pack("tutorial"), table.pack(1) } do
			remote.OnServerEvent:Fire(f.Player, table.unpack(payload, 1, payload.n))
		end
	end
	check(f.Data.IntroSeen == false and f:IntroWrites() == 0, "another remote wrote IntroSeen")
end

-- 4. Saved values: only a real boolean true survives; corrupt values load as unseen (DataService type repair).
for _, row in { { true, true }, { false, false }, { "true", false }, { 1, false }, { {}, false }, { nil, false } } do
	local f = fixture({ Version = 2, IntroSeen = row[1] })
	check(f.Data.IntroSeen == row[2], "saved IntroSeen " .. tostring(row[1]) .. " loaded as " .. tostring(f.Data.IntroSeen))
end
print("INTRO_SEEN_OFFLINE_OK checks=" .. checks .. " Studio/API calls=0")
