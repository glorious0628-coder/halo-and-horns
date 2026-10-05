-- Grudge sack rules (A), P3 grudge mail (B) and the A23-18 ghost hold (C), run offline (735419e + review 08d6f44).
-- tools/test_grudge.py injects the CURRENT repository sources before this file: CONFIG_SOURCE, NET_SOURCE, UTIL_SOURCE,
-- GRUDGE_SOURCE and PAIR_READY_SOURCE (the real PlayerService.PairReady, extracted). Only engine / service boundaries
-- are doubles: Players, an in-memory DataStore (failure modes: every call, the next N calls, or "written but the
-- reply was lost"), task (a clock-driven scheduler: spawn runs at once, wait / delay wake on f:Advance, the 0.25 s
-- loop is stepped by f:Tick), Net sends, ProgressionService recorders. No Studio, network or Roblox API calls.
-- Callers are modelled like production: OnCarrierDown runs in a pcall like CombatService's pipelineCall, signals are
-- the real Util.Signal (pcall'd handlers), so a GrudgeService error becomes a warning and the checks keep going.
-- Every check is named and collected (a failure never aborts the run); the result is one JSON line.

------------------------------------------------------------------ check collection
local results, order, findings = {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
local groupWarnings = {}

local function check(ok, name, detail)
	total += 1
	local key = currentGroup .. " :: " .. name
	local r = results[key]
	if not r then
		r = { Group = currentGroup, Name = name, Pass = 0, Fail = 0 }
		results[key] = r
		table.insert(order, key)
	end
	if ok then
		r.Pass += 1
	else
		r.Fail += 1
		failedCount += 1
		if r.Fail <= 3 then print("CHECK_FAIL " .. key .. " :: " .. tostring(detail or "")) end
		r.First = r.First or tostring(detail or "")
	end
	return ok == true
end

local function finding(text)
	table.insert(findings, { Group = currentGroup, Text = text })
end

local function runGroup(name, fn)
	currentGroup = name
	groupWarnings = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	check(#groupWarnings == 0, "no unexpected service warnings (pcall-swallowed errors)", groupWarnings[1])
end

------------------------------------------------------------------ helpers
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[deepCopy(k)] = deepCopy(x) end
	return out
end

local function show(v)
	if type(v) ~= "table" then return tostring(v) end
	local parts = {}
	for k, x in v do table.insert(parts, tostring(k) .. "=" .. show(x)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return { Disconnect = function() local i = table.find(callbacks, fn); if i then table.remove(callbacks, i) end end }
		end,
		Fire = function(_, ...) for _, fn in table.clone(callbacks) do fn(...) end end,
	}
end

local function execute(name, source, env, ...)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn(...)
end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function nativeEnv()
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
		Font = ctor("Font"), Enum = enum }
end
local function typeofDouble(v) return type(v) == "table" and v.__kind or type(v) end

local CONFIG = execute("Config", CONFIG_SOURCE, nativeEnv())
-- the real Net.Names list gates every Net.Get (an unknown remote fails like the real assert)
local NET_NAMES = {}
do
	local netServices = { ReplicatedStorage = {}, RunService = { IsServer = function() return true end } }
	local realNet = execute("Net", NET_SOURCE, { game = { GetService = function(_, n) return assert(netServices[n], n) end } })
	for _, n in realNet.Names do NET_NAMES[n] = true end
end

local function makeCharacter()
	local c = { Parent = "Workspace", Hum = { Health = 100 }, Root = { Position = vec(0, 0, 0) } }
	function c:FindFirstChildOfClass(cls) if cls == "Humanoid" then return self.Hum end return nil end
	function c:FindFirstChild(n) if n == "HumanoidRootPart" then return self.Root end return nil end
	return c
end

------------------------------------------------------------------ world (real Config + Util + GrudgeService + PairReady)
local TIME_BASE = 1.8e9
local worldSerial = 0
-- opts: Rows (shared DataStore rows = another server), Grudge (Config.Grudge overrides), InlinePairReady (no
-- PlayerService.PairReady -> GrudgeService's own fallback), GetStoreFail (GetDataStore throws)
local function grudgeWorld(opts)
	opts = opts or {}
	worldSerial += 1
	local f = { Now = 1000, PlayerList = {}, Notices = {}, All = {}, Fx = {}, Bank = {}, Carried = {}, Stats = {}, Resolved = {},
		Delays = {}, Sleepers = {}, Warnings = {}, Active = {}, Rows = opts.Rows or {}, StoreNames = {}, StoreCalls = {},
		DSFail = false, FailNext = 0, FailAfterWrite = 0, GetStoreFail = opts.GetStoreFail == true, Loop = nil, Threads = 0,
		Starting = false, Prunes = 0, OnUpdate = nil }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	for k, v in opts.Grudge or {} do config.Grudge[k] = v end
	f.Config, f.G = config, config.Grudge

	local players = { __kind = "Instance", Name = "Players" }
	function players:GetPlayerByUserId(id)
		for _, p in f.PlayerList do if p.UserId == id and p.Parent ~= nil then return p end end
		return nil
	end
	function players:GetPlayers()
		local out = {}
		for _, p in f.PlayerList do if p.Parent ~= nil then table.insert(out, p) end end
		return out
	end
	-- DataStore double: what a key holds; UpdateAsync's nil return = no write (like the real one)
	local store = {}
	local function access(kind, key)
		table.insert(f.StoreCalls, { Kind = kind, Key = key, Now = f.Now })
		if f.DSFail then error("offline DataStore double: " .. kind .. " failed (502)") end
		if f.FailNext > 0 then
			f.FailNext -= 1
			error("offline DataStore double: " .. kind .. " failed (503)")
		end
	end
	function store:UpdateAsync(key, fn)
		access("UpdateAsync", key)
		if f.BeforeUpdate then f.BeforeUpdate(key) end
		local nextValue = fn(deepCopy(f.Rows[key]))
		if f.OnUpdate then f.OnUpdate(key) end
		if nextValue ~= nil then f.Rows[key] = deepCopy(nextValue) end
		if f.FailAfterWrite > 0 then
			f.FailAfterWrite -= 1
			error("offline DataStore double: written, but the reply was lost")
		end
		return deepCopy(f.Rows[key])
	end
	function store:GetAsync(key) access("GetAsync", key); return deepCopy(f.Rows[key]) end
	function store:SetAsync(key, value) access("SetAsync", key); f.Rows[key] = deepCopy(value) end
	local dss = {}
	function dss:GetDataStore(name)
		table.insert(f.StoreNames, name)
		if f.GetStoreFail then error("offline: DataStore API access is off") end
		return store
	end
	local services = { Players = players, ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		DataStoreService = dss, RunService = { IsServer = function() return true end, IsStudio = function() return true end } }
	local game = { JobId = "offline-grudge", GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	local ws = { GetServerTimeNow = function() return f.Now end }
	local osDouble = { clock = function() return f.Now end, time = function() return math.floor(TIME_BASE + f.Now) end, date = os.date }
	local plainRandom = { new = function()
		local r = {}
		function r:NextNumber(a, b) local v = math.random(); if a ~= nil then return a + (b - a) * v end; return v end
		function r:NextInteger(a, b) return math.random(a, b) end
		return r
	end }
	local function warnDouble(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		local msg = table.concat(parts, " ")
		table.insert(f.Warnings, msg)
		table.insert(groupWarnings, msg)
	end
	f.Warn = warnDouble
	-- task scheduler: spawn runs at once; a thread that waits sleeps until f:Advance reaches its wake time; the one
	-- thread started inside GrudgeService.Start is the 0.25 s loop, stepped by f:Tick
	local function resumeThread(co, ...)
		local ok, res = coroutine.resume(co, ...)
		if not ok then
			warnDouble("task error: " .. tostring(res))
			return
		end
		if coroutine.status(co) == "suspended" then
			if f.Starting then
				f.Threads += 1
				f.Loop = co
			else
				table.insert(f.Sleepers, { Co = co, At = f.Now + (tonumber(res) or 0), From = f.Now })
			end
		end
	end
	local taskDouble = {}
	function taskDouble.spawn(fn, ...)
		local co = coroutine.create(fn)
		resumeThread(co, ...)
		return co
	end
	function taskDouble.wait(d) return coroutine.yield(d or 0) end
	function taskDouble.delay(d, fn, ...) table.insert(f.Delays, { At = f.Now + (tonumber(d) or 0), Fn = fn, Args = table.pack(...) }) end
	function taskDouble.defer(fn, ...) fn(...) end
	f.ResumeThread = resumeThread
	local modules = { Config = config }
	local function env()
		return { game = game, workspace = ws, typeof = typeofDouble, os = osDouble, Random = plainRandom, task = taskDouble,
			Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec }, print = function() end, warn = warnDouble,
			require = function(name) return assert(modules[name], "unexpected require " .. tostring(name)) end }
	end
	local util = execute("Util", UTIL_SOURCE, env())
	modules.Util = util
	f.Util = util

	local remotes = {}
	local net = {}
	function net.Get(name)
		assert(NET_NAMES[name], "Unknown remote: " .. tostring(name))
		if not remotes[name] then remotes[name] = { OnServerEvent = signal() } end
		return remotes[name]
	end
	function net.Notify(p, text, kind) table.insert(f.Notices, { Player = p, Text = text, Kind = kind }) end
	function net.NotifyAll(text, kind) table.insert(f.All, { Text = text, Kind = kind }) end
	function net.Fx(p, kind, data) table.insert(f.Fx, { Player = p, Kind = kind, Data = data }) end
	modules.Net = net
	f.Remotes = remotes

	local ps = { PlayerReady = util.Signal.new(), PlayerLeaving = util.Signal.new() }
	function ps.IsReady(p) return p.Ready == true and p.Parent ~= nil end
	function ps.GetData(p) return p.Data end
	function ps.AddStat(p, key, n) table.insert(f.Stats, { Player = p, Key = key, Amount = n }) end
	function ps.MarkActive(p) f.Active[p] = (f.Active[p] or 0) + 1 end
	if not opts.InlinePairReady then
		local real = execute("PlayerService.PairReady", PAIR_READY_SOURCE, env(),
			{ DataService = { Get = function(p) return type(p) == "table" and p.Data or nil end } },
			{ MinKeep = 1800, MaxKeys = 200, KeepFrom = {} },
			function() f.Prunes += 1 end,
			function(loopName, err) warnDouble("PairCD " .. tostring(loopName) .. ": " .. tostring(err)) end)
		ps.PairReady = real.PairReady
	end
	f.PS = ps
	local prog = { Rebirthed = util.Signal.new() }
	function prog.AddBankGold(p, amount, source)
		-- MailRow: what the mailbox held at the moment of payment (B: cleared first, then paid)
		table.insert(f.Bank, { Player = p, Amount = amount, Source = source, MailRow = deepCopy(f.Rows["M_" .. tostring(p.UserId)]),
			Present = p.Parent ~= nil })
	end
	function prog.AddCarriedGold(p, amount, source) table.insert(f.Carried, { Player = p, Amount = amount, Source = source }) end
	local registry = { PlayerService = ps, ProgressionService = prog,
		FactionService = { FactionChanged = util.Signal.new(), GetFaction = function(p) return p.Faction end },
		ZoneService = { IsPvPZone = function(p) return p.PvP == true end } }
	f.Registry = registry

	local grudge = execute("GrudgeService", GRUDGE_SOURCE, env())
	grudge.SackResolved:Connect(function(thief, outcome, sackTotal)
		table.insert(f.Resolved, { Thief = thief, Outcome = outcome, Total = sackTotal, StillHasSack = grudge.HasSack(thief) })
	end)
	grudge.Init(registry)
	f.Starting = true
	grudge.Start()
	f.Starting = false
	assert(f.Threads == 1 and f.Loop ~= nil, "GrudgeService.Start should leave exactly one waiting loop")
	f.Svc = grudge

	local serial = 0
	-- o: UserId, Rebirths, PairCD, Data, NoData, Ready (false = joined but not ready; no PlayerReady)
	function f:Add(name, factionName, o)
		o = o or {}
		serial += 1
		local data = o.Data or { PairCD = o.PairCD or {} }
		if o.NoData then data = nil end
		local p = { __kind = "Instance", ClassName = "Player", Name = name, DisplayName = name,
			UserId = o.UserId or (worldSerial * 1000 + serial), Parent = players, Attrs = { Rebirths = o.Rebirths or 0 },
			Faction = factionName, Ready = o.Ready ~= false, Data = data, PvP = false }
		function p:IsA(kind) return kind == "Player" end
		function p:GetAttribute(k) return self.Attrs[k] end
		function p:SetAttribute(k, v) self.Attrs[k] = v end
		p.Character = makeCharacter()
		table.insert(self.PlayerList, p)
		if p.Ready then ps.PlayerReady:Fire(p, p.Data) end
		return p
	end
	-- PlayerRemoving: PlayerLeaving fires while the player is still parented, then the player is gone
	function f:Leave(p)
		ps.PlayerLeaving:Fire(p, p.Data)
		p.Parent = nil
	end
	function f:Kill(p) p.Character.Hum.Health = 0 end
	function f:Revive(p) p.Character.Hum.Health = 100 end
	function f:Rebirth(p, n)
		p:SetAttribute("Rebirths", n)
		prog.Rebirthed:Fire(p, n, {})
	end
	-- moves the clock to Now + dt, waking delays / sleeping threads at their own times on the way
	function f:Advance(dt)
		local target = self.Now + dt
		while true do
			local best, kind, idx = nil, nil, nil
			for i, d in self.Delays do if d.At <= target and (best == nil or d.At < best) then best, kind, idx = d.At, "delay", i end end
			for i, s in self.Sleepers do if s.At <= target and (best == nil or s.At < best) then best, kind, idx = s.At, "sleep", i end end
			if not best then break end
			if best > self.Now then self.Now = best end
			if kind == "delay" then
				local d = table.remove(self.Delays, idx)
				d.Fn(table.unpack(d.Args, 1, d.Args.n))
			else
				local s = table.remove(self.Sleepers, idx)
				resumeThread(s.Co, self.Now - s.From)
			end
		end
		self.Now = target
	end
	-- one loop step of `dt` real seconds (task.wait returns the elapsed time)
	function f:Tick(dt)
		dt = dt or self.G.Tick
		self:Advance(dt)
		local ok, err = coroutine.resume(self.Loop, dt)
		assert(ok, err)
	end
	function f:Ticks(n, dt) for _ = 1, n do self:Tick(dt) end end
	function f:Hold(p, ...) self.Remotes.GhostHold.OnServerEvent:Fire(p, ...) end
	function f:Steal(thief, victim, amount, infamy) self.Svc.AddToSack(thief, victim, amount, infamy) end
	-- CombatService.pipelineCall: the death pipeline pcalls OnCarrierDown and warns on an error
	function f:KO(thief, killer)
		local ok, err = pcall(self.Svc.OnCarrierDown, thief, killer)
		if not ok then warnDouble("[CombatService] death pipeline: GrudgeService.OnCarrierDown failed: " .. tostring(err)) end
	end
	function f:BankOf(p, source)
		local n = 0
		for _, e in self.Bank do if e.Player == p and (source == nil or e.Source == source) then n += e.Amount end end
		return n
	end
	function f:Told(p, text, kind)
		local n = 0
		for _, e in self.Notices do if e.Player == p and e.Text == text and (kind == nil or e.Kind == kind) then n += 1 end end
		return n
	end
	function f:NoticeCount(p)
		local n = 0
		for _, e in self.Notices do if e.Player == p then n += 1 end end
		return n
	end
	function f:Calls(key)
		local n = 0
		for _, c in self.StoreCalls do if c.Key == key then n += 1 end end
		return n
	end
	function f:Mail(userId) return self.Rows["M_" .. tostring(userId)] end
	function f:Text(key, ...) return string.format(self.Config.Text[key], ...) end
	function f:Seconds(thief) return thief:GetAttribute("SackSeconds") end
	function f:Target(p) return p:GetAttribute("GrudgeThiefId") end
	function f:Time() return math.floor(TIME_BASE + self.Now) end
	function f:Pending() return self.Svc.MailPending and self.Svc.MailPending() or -1 end
	-- removes expected warnings (plain substring) from the group list; returns how many matched
	function f:TakeWarnings(pattern)
		local n, i = 0, 1
		while i <= #groupWarnings do
			if string.find(groupWarnings[i], pattern, 1, true) then table.remove(groupWarnings, i); n += 1 else i += 1 end
		end
		return n
	end
	return f
end

------------------------------------------------------------------ 0. contract
runGroup("config-contract", function()
	local G = CONFIG.Grudge
	check(G.SackSeconds == 45 and G.AvengeRefundRate == 1.2 and G.ReturnRate == 1.0 and G.RefundBonusCooldown == 600
		and G.AvengerBonus == 100 and G.RestealWindow == 180, "Config.Grudge: 45 s, 120% / 100%, refund bonus per 600 s, avenger 100, resteal 180 s",
		show({ G.SackSeconds, G.AvengeRefundRate, G.ReturnRate, G.RefundBonusCooldown, G.AvengerBonus, G.RestealWindow }))
	check(G.MailStore == "HaloHorns_GrudgeMail_v1" and G.MailMax == 20, "Config.Grudge mail: DataStore HaloHorns_GrudgeMail_v1, MailMax 20",
		show({ G.MailStore, G.MailMax }))
	check(G.HoldAddSeconds == 2 and G.HoldMaxSeconds == 10 and G.HoldGlowSeconds == 3 and G.HoldCooldown == 3,
		"A23-18 hold numbers: +2 s, max +10 s per sack, glow 3 s, client cooldown 3 s",
		show({ G.HoldAddSeconds, G.HoldMaxSeconds, G.HoldGlowSeconds, G.HoldCooldown }))
	check(CONFIG.RateLimits.GhostHold == 2.7 and CONFIG.RateLimits.GhostHold < G.HoldCooldown,
		"Config.RateLimits.GhostHold = 2.7 (a bit under the 3 s client cooldown, so network jitter never eats a press)", CONFIG.RateLimits.GhostHold)
	check(CONFIG.PvP.PairRewardCooldown == 300, "avenger bonus cooldown = Config.PvP.PairRewardCooldown 300", CONFIG.PvP.PairRewardCooldown)
	check(NET_NAMES.GhostHold == true, "Net.Names has the GhostHold remote")
	local T = CONFIG.Text
	for _, case in { { "GrudgeMail", { "1.2K" } }, { "GhostHoldOk", { 2, 10 } }, { "GhostHoldMax", { 10 } }, { "GhostHeld", {} },
		{ "SackPaid", { "5" } }, { "SackLost", {} }, { "GrudgeRefund", { "A", "5" } }, { "GrudgeReturned", { "5" } },
		{ "AvengerBonus", { "100" } }, { "GrudgeAvengedAll", { "A", "B" } } } do
		local text = T[case[1]]
		local specs = type(text) == "string" and select(2, string.gsub(string.gsub(text, "%%%%", ""), "%%[sd]", "")) or -1
		local ok = type(text) == "string" and pcall(string.format, text, table.unpack(case[2]))
		check(ok and specs == #case[2], "Config.Text." .. case[1] .. " has exactly its %s/%d arguments", show({ text, specs }))
	end
	local okText = string.format(T.GhostHoldOk, 2, 10)
	check(string.find(okText, "+2", 1, true) ~= nil and string.find(okText, "+10", 1, true) ~= nil, "GhostHoldOk reads +2 s (max +10 s)", okText)
end)

------------------------------------------------------------------ A. sack rules
runGroup("close-sack", function()
	-- the most common resolution: a present victim. closeSack must finish (SackLost, SackResolved, button update)
	local f = grudgeWorld()
	local T, V = f:Add("Thief", "Horns"), f:Add("Victim", "Halo")
	f:Steal(T, V, 50, 0)
	f:KO(T, nil)
	check(#f.Warnings == 0, "closing a sack with a victim on the server raises no error", f.Warnings[1])
	check(#f.Resolved == 1 and f:Told(T, f:Text("SackLost"), "bad") == 1, "closeSack finishes: SackLost to the thief, SackResolved fired",
		show({ resolved = #f.Resolved, notices = f:NoticeCount(T) }))
	check(f:Target(V) == 0, "closeSack clears the victim's hold button", f:Target(V))
	check(f:BankOf(V, "Refund") == 50 and not f.Svc.HasSack(T), "the victim is refunded and the sack is gone")
end)

runGroup("sack-add", function()
	local f = grudgeWorld()
	local S = f.Svc
	local T = f:Add("Thief", "Horns")
	local V1 = f:Add("VicOne", "Halo")
	local V2 = f:Add("VicTwo", "Neutral")
	check(not S.HasSack(T) and S.GetSackTotal(T) == 0 and not S.HasSack(nil) and S.GetSackTotal(nil) == 0, "no sack before a steal")
	check(S.CanSteal(T, V1) == true and S.CanSteal(nil, V1) == false and S.CanSteal(T, nil) == false, "CanSteal: a fresh pair is allowed, nil refused")
	f:Steal(T, V1, 100, 1)
	check(S.HasSack(T) and S.GetSackTotal(T) == 100, "AddToSack opens a sack with the stolen gold", S.GetSackTotal(T))
	check(T:GetAttribute("SackGold") == 100 and T:GetAttribute("SackSeconds") == 45 and T:GetAttribute("SackVictimName") == "VicOne",
		"the thief's SackGold / SackSeconds 45 / SackVictimName are published", show(T.Attrs))
	check(f:Target(V1) == T.UserId, "A23-18: AddToSack sets the victim's GrudgeThiefId = thief.UserId", show({ f:Target(V1), T.UserId }))
	check(V1.Data.PairCD["steal:" .. T.UserId] == f:Time(), "CR-M4: the steal is recorded in the victim's save (PairCD steal:<thief>)",
		show(V1.Data.PairCD))
	check(S.CanSteal(T, V1) == false and S.CanSteal(T, V2) == true, "the same thief cannot steal from the same victim again; other victims can be robbed")
	f:Steal(T, V1, 50.9, 2)
	f:Steal(T, V2, 30, -5)
	check(S.GetSackTotal(T) == 180 and T:GetAttribute("SackGold") == 180 and T:GetAttribute("SackVictimName") == "VicTwo",
		"steals accumulate in ONE sack (fractions floored), the last victim is shown", show({ S.GetSackTotal(T), T.Attrs }))
	local bad = { { T, V1, 0 }, { T, V1, -10 }, { T, V1, "abc" }, { T, V1, nil }, { nil, V1, 10 }, { T, nil, 10 } }
	for i = 1, #bad do S.AddToSack(bad[i][1], bad[i][2], bad[i][3], 1) end
	check(S.GetSackTotal(T) == 180, "zero / negative / non-number amounts and nil players are ignored", S.GetSackTotal(T))
	T.PvP = true
	f:Ticks(40)
	check(f:Seconds(T) == 35, "10 s in a PvP zone: 35 s left", f:Seconds(T))
	local V3 = f:Add("VicThree", "Halo")
	f:Steal(T, V3, 20, 0)
	check(f:Seconds(T) == 45, "every new steal restarts the countdown at 45 s (no hold seconds yet)", f:Seconds(T))
	-- RestealWindow 180 s (both V1 steals happened at t = 1000)
	f:Advance(169)
	check(S.CanSteal(T, V1) == false, "re-steal still blocked at 179 s")
	f:Advance(1)
	check(S.CanSteal(T, V1) == true, "re-steal allowed again after RestealWindow 180 s")
	f:KO(T, nil)
	check(f:BankOf(V1, "Refund") == 150 and f:BankOf(V2, "Refund") == 30 and f:BankOf(V3, "Refund") == 20,
		"Returned: each victim gets the accumulated share 100% to the bank (source Refund)", show({ f:BankOf(V1), f:BankOf(V2), f:BankOf(V3) }))
	check(#f.Stats == 0 and #f.Carried == 0, "Returned: the thief gets neither gold nor infamy")
	check(f:Told(V1, f:Text("GrudgeReturned", "150"), "good") == 1, "GrudgeReturned notice with the amount")
end)

runGroup("sack-countdown-paid", function()
	local f = grudgeWorld()
	local S = f.Svc
	local T = f:Add("Thief", "Horns")
	local V = f:Add("Victim", "Halo")
	f:Steal(T, V, 200, 1)
	f:Steal(T, V, 0, 2) -- ignored: infamy is not added either
	f:Ticks(40)
	check(f:Seconds(T) == 45 and S.HasSack(T), "outside a PvP zone the countdown never ticks", f:Seconds(T))
	T.PvP = true
	f:Ticks(4)
	check(f:Seconds(T) == 44, "inside a PvP zone it ticks (4 x 0.25 s = 1 s)", f:Seconds(T))
	f:Tick(5)
	check(f:Seconds(T) == 43, "a 5 s server hitch counts at most 1 s (MAX_TICK_STEP)", f:Seconds(T))
	f:Kill(T)
	f:Ticks(20)
	check(f:Seconds(T) == 43 and S.HasSack(T) and #f.Carried == 0, "a dead carrier is never ticked or paid (the death pipeline resolves)",
		f:Seconds(T))
	f:Revive(T)
	local char = T.Character
	T.Character = nil
	f:Ticks(8)
	check(f:Seconds(T) == 43, "no character (not alive): no tick", f:Seconds(T))
	T.Character = char
	f:Ticks(4 * 42)
	check(f:Seconds(T) == 1 and S.HasSack(T) and #f.Carried == 0, "1 s left: not paid yet", f:Seconds(T))
	f:Ticks(3)
	check(S.HasSack(T) and f:Seconds(T) == 1 and #f.Carried == 0, "0.25 s left: still not paid (SackSeconds = ceil)", f:Seconds(T))
	f:Tick()
	check(not S.HasSack(T), "45 s survived in PvP zones: the sack resolves")
	check(#f.Carried == 1 and f.Carried[1].Player == T and f.Carried[1].Amount == 200 and f.Carried[1].Source == "Plunder",
		"Paid: the whole sack to the thief's carried gold (source Plunder)", show(f.Carried))
	check(#f.Stats == 1 and f.Stats[1].Player == T and f.Stats[1].Key == "Infamy" and f.Stats[1].Amount == 1,
		"Paid: the sack's infamy is added once", show(f.Stats))
	check(f:Told(T, f:Text("SackPaid", "200"), "reward") == 1 and f:Told(T, f:Text("SackLost")) == 0, "SackPaid to the thief (no SackLost)")
	check(#f.Bank == 0 and next(f.Rows) == nil, "Paid: victims get nothing back and no mail is written")
	local r = f.Resolved[1] or {}
	check(#f.Resolved == 1 and r.Outcome == "Paid" and r.Total == 200 and r.Thief == T and r.StillHasSack == false,
		"SackResolved(thief, Paid, 200) fires once, after the sack is removed", show(f.Resolved))
	check(T:GetAttribute("SackGold") == 0 and T:GetAttribute("SackSeconds") == 0 and T:GetAttribute("SackVictimName") == ""
		and T:GetAttribute("SackHeldUntil") == 0, "the thief's sack attributes reset", show(T.Attrs))
	check(f:Target(V) == 0, "the victim's hold target is cleared", f:Target(V))
	f:Ticks(8)
	check(#f.Carried == 1, "a paid sack is never paid twice")
	-- an absent victim of a PAID sack gets no letter (the thief kept the gold)
	local g = grudgeWorld()
	local T2, V2 = g:Add("Thief", "Horns"), g:Add("Gone", "Halo")
	g:Steal(T2, V2, 90, 0)
	g:Leave(V2)
	T2.PvP = true
	g:Ticks(4 * 45)
	check(not g.Svc.HasSack(T2) and g.Carried[1] ~= nil and g.Carried[1].Amount == 90 and g:Mail(V2.UserId) == nil,
		"Paid with an absent victim: no grudge mail", show(g.Rows))
end)

runGroup("sack-returned", function()
	local f = grudgeWorld()
	local T, V = f:Add("Thief", "Horns"), f:Add("Victim", "Halo")
	f:Steal(T, V, 120, 3)
	f:Leave(T)
	check(not f.Svc.HasSack(T) and f:BankOf(V, "Refund") == 120 and #f.Carried == 0 and #f.Stats == 0,
		"thief leaves: Returned 100% to the victim, the thief is never paid", show({ f:BankOf(V), #f.Carried }))
	check(f:Told(T, f:Text("SackLost")) == 0, "a leaving thief is not told")
	check(f:Told(V, f:Text("GrudgeReturned", "120"), "good") == 1, "the victim gets GrudgeReturned")
	check((f.Resolved[1] or {}).Outcome == "Returned" and (f.Resolved[1] or {}).Total == 120, "SackResolved Returned 120", show(f.Resolved))
	check(f:Target(V) == 0, "the victim's hold target is cleared")
	local g = grudgeWorld()
	local T2, V2 = g:Add("Thief", "Horns"), g:Add("Victim", "Halo")
	g:Steal(T2, V2, 80, 0)
	T2.Parent = nil
	g:Tick()
	check(not g.Svc.HasSack(T2) and g:BankOf(V2, "Refund") == 80 and #g.Carried == 0, "thief gone without PlayerLeaving: the next tick returns the sack")
	local h = grudgeWorld()
	local T3, V3 = h:Add("Thief", "Horns"), h:Add("Victim", "Halo")
	h:Steal(T3, V3, 60, 0)
	h.Registry.FactionService.FactionChanged:Fire(T3, "Halo", "Horns")
	check(not h.Svc.HasSack(T3) and h:BankOf(V3, "Refund") == 60, "faction change: Returned 100%")
	check(h:Told(T3, h:Text("SackLost"), "bad") == 1, "faction change tells the thief (SackLost)")
	for _, case in { "nil", "self", "Horns", "Neutral", "HaloGone" } do
		local w = grudgeWorld()
		local thief, victim = w:Add("Thief", "Horns"), w:Add("Victim", "Halo")
		local killer = nil
		if case == "self" then
			killer = thief
		elseif case == "Horns" or case == "Neutral" then
			killer = w:Add("Killer", case)
		elseif case == "HaloGone" then
			killer = w:Add("Killer", "Halo")
			killer.Parent = nil
		end
		w:Steal(thief, victim, 90, 0)
		w:KO(thief, killer)
		check(w:BankOf(victim, "Refund") == 90 and (w.Resolved[1] or {}).Outcome == "Returned",
			"KO without a present Halo killer -> Returned 100%", case .. " " .. show({ w:BankOf(victim), w.Resolved }))
		check(killer == nil or killer == thief or w:BankOf(killer) == 0, "no avenger bonus without a Halo killer", case)
		check(#w.All == 0 and w:Told(thief, w:Text("SackLost"), "bad") == 1, "no server-wide avenged line; the thief is told SackLost", case)
	end
	local o = grudgeWorld()
	local To, Vo = o:Add("Thief", "Horns"), o:Add("Victim", "Halo")
	o:Steal(To, Vo, 90, 0)
	Vo:SetAttribute("Rebirths", 1)
	o:KO(To, nil)
	check(o:BankOf(Vo) == 0 and o:Mail(Vo.UserId) == nil and not o.Svc.HasSack(To),
		"Returned: a present victim who rebirthed since gets no pay and no mail (CR-M6)", show({ o:BankOf(Vo), o.Rows }))
	local n = grudgeWorld()
	local P = n:Add("Nobody", "Horns")
	n:KO(P, n:Add("Knight", "Halo"))
	n.Svc.OnCarrierDown(nil, nil)
	check(#n.Resolved == 0 and #n.Bank == 0 and #n.All == 0, "OnCarrierDown without a sack does nothing")
end)

runGroup("sack-avenged", function()
	local f = grudgeWorld()
	local S = f.Svc
	local T, V1, V2, H = f:Add("Thief", "Horns"), f:Add("VicOne", "Halo"), f:Add("VicTwo", "Neutral"), f:Add("Knight", "Halo")
	V1.Character.Root.Position = vec(10, 0, 0)
	T.Character.Root.Position = vec(50, 0, 0)
	f:Steal(T, V1, 100, 0)
	f:Steal(T, V2, 55, 0)
	f:KO(T, H)
	check(not S.HasSack(T) and f:BankOf(V1, "Refund") == 120 and f:BankOf(V2, "Refund") == 66,
		"Avenged: present same-life victims get 120% (floored) to the bank", show({ f:BankOf(V1), f:BankOf(V2) }))
	check(f:Told(V1, f:Text("GrudgeRefund", "Knight", "120"), "good") == 1 and f:Told(V2, f:Text("GrudgeRefund", "Knight", "66"), "good") == 1,
		"GrudgeRefund names the avenger and the amount")
	local fx = nil
	for _, e in f.Fx do if e.Player == V1 then fx = e end end
	check(fx ~= nil and fx.Kind == "Plunder" and fx.Data.Amount == 120 and fx.Data.From.X == 50 and fx.Data.To.X == 10,
		"Plunder Fx flies from the thief to the victim", show(fx))
	check(f:BankOf(H, "Bounty") == 100 and f:Told(H, f:Text("AvengerBonus", "100"), "reward") == 1, "the Halo killer gets the avenger bonus 100 (Bounty)")
	check(#f.All == 1 and f.All[1].Text == f:Text("GrudgeAvengedAll", "Knight", "Thief"), "server-wide avenged line", show(f.All))
	check(f:Told(T, f:Text("SackLost"), "bad") == 1, "the thief is told SackLost")
	check((f.Resolved[1] or {}).Outcome == "Avenged" and (f.Resolved[1] or {}).Total == 155, "SackResolved Avenged 155", show(f.Resolved))
	check(V1.Data.PairCD["refund:0"] == f:Time() and V2.Data.PairCD["refund:0"] == f:Time() and H.Data.PairCD["avenge:0"] == f:Time(),
		"cooldowns live in the saves: victims refund:0, avenger avenge:0", show({ V1.Data.PairCD, H.Data.PairCD }))
	check(next(f.Rows) == nil, "present victims get no mail", show(f.Rows))
	local function avengeAgain(dt, thief)
		f:Advance(dt)
		local before1, beforeH = f:BankOf(V1), f:BankOf(H)
		f:Steal(thief or T, V1, 100, 0)
		f:KO(thief or T, H)
		return f:BankOf(V1) - before1, f:BankOf(H) - beforeH
	end
	local r1, b1 = avengeAgain(100)
	check(r1 == 100 and b1 == 0, "100 s later: the victim gets 100% (refund bonus used), no avenger bonus", show({ r1, b1 }))
	local r2, b2 = avengeAgain(201)
	check(r2 == 100 and b2 == 100, "301 s: the avenger bonus is back (300 s), the victim's 120% still waits (600 s)", show({ r2, b2 }))
	local r3, b3 = avengeAgain(299)
	check(r3 == 120 and b3 == 0, "600 s: the victim's 120% is back; the avenger bonus waits again", show({ r3, b3 }))
	local r4 = avengeAgain(10, f:Add("ThiefTwo", "Horns"))
	check(r4 == 100, "a different thief within 600 s: still 100% (the bonus is per victim, whatever the thief)", r4)
	local g = grudgeWorld()
	local Tg, Vg, Hg = g:Add("Thief", "Horns"), g:Add("Victim", "Halo"), g:Add("Knight", "Halo")
	g:Steal(Tg, Vg, 100, 0)
	Vg:SetAttribute("Rebirths", 1)
	g:KO(Tg, Hg)
	check(g:BankOf(Vg) == 0 and next(g.Rows) == nil and Vg.Data.PairCD["refund:0"] == nil,
		"CR-M6: a victim who rebirthed since gets nothing (no pay, no mail, refund cooldown untouched)", show({ g:BankOf(Vg), g.Rows, Vg.Data.PairCD }))
	check(g:BankOf(Hg, "Bounty") == 100, "the avenger bonus still pays")
	local h = grudgeWorld()
	local Th, Vh = h:Add("Thief", "Horns"), h:Add("Victim", "Halo")
	h:Steal(Th, Vh, 100, 0)
	Vh:SetAttribute("Rebirths", 1)
	h:Steal(Th, Vh, 40, 0)
	check(h.Svc.GetSackTotal(Th) == 140, "a share stolen before a rebirth stays in the sack total", h.Svc.GetSackTotal(Th))
	h:KO(Th, nil)
	check(h:BankOf(Vh) == 40, "only the share stolen in the current life is refunded", h:BankOf(Vh))
end)

------------------------------------------------------------------ B. P3 grudge mail
runGroup("mail-send", function()
	local f = grudgeWorld()
	local T, Gone, Here, H = f:Add("Thief", "Horns"), f:Add("Gone", "Halo", { Rebirths = 2 }), f:Add("Here", "Halo"), f:Add("Knight", "Halo")
	local sackStart = f:Time()
	f:Steal(T, Gone, 100, 0)
	f:Steal(T, Here, 50, 0)
	f:Leave(Gone)
	f:Advance(5)
	f:KO(T, H)
	local box = f:Mail(Gone.UserId)
	local l1 = type(box) == "table" and box[1] or {}
	check(type(box) == "table" and #box == 1 and l1.A == 100 and l1.R == 2 and l1.K == "Avenged" and l1.T == f:Time(),
		"Avenged + absent victim: one letter { A = 100, R = 2 (rebirths when stolen), K = Avenged, T = os.time() } at M_<userId>", show(box))
	check(l1.Id == tostring(T.UserId) .. ":" .. tostring(sackStart) .. ":Avenged",
		"the letter Id = <thief UserId>:<os.time at sack start>:<kind>", show({ l1.Id, T.UserId, sackStart }))
	check(#f.StoreNames == 1 and f.StoreNames[1] == "HaloHorns_GrudgeMail_v1", "the mailbox is DataStore HaloHorns_GrudgeMail_v1 (opened once)",
		show(f.StoreNames))
	check(f:Pending() == 0, "GrudgeService.MailPending() is 0 once the letter is written", f:Pending())
	check(f:BankOf(Gone) == 0 and f:NoticeCount(Gone) == 0, "the absent victim is not paid now")
	check(f:BankOf(Here, "Refund") == 60 and f:Mail(Here.UserId) == nil, "a present victim is paid directly (120%) and gets no mail")
	check(f:BankOf(H, "Bounty") == 100, "the avenger bonus does not depend on who is present")
	local Away = f:Add("Away", "Halo")
	f:Steal(T, Away, 77, 0)
	f:Leave(Away)
	f:KO(T, nil)
	local b3 = f:Mail(Away.UserId)
	check(type(b3) == "table" and #b3 == 1 and b3[1].A == 77 and b3[1].K == "Returned" and b3[1].R == 0
		and string.sub(tostring(b3[1].Id), -9) == ":Returned", "Returned + absent victim: K = Returned, Id ends in :Returned", show(b3))
	local Loading = f:Add("Loading", "Halo")
	f:Steal(T, Loading, 33, 0)
	Loading.Ready = false
	f:KO(T, nil)
	local b4 = f:Mail(Loading.UserId)
	check(type(b4) == "table" and b4[1] ~= nil and b4[1].A == 33 and f:BankOf(Loading) == 0, "a victim who is in the server but not ready gets mail", show(b4))
	local Reborn = f:Add("Reborn", "Halo")
	f:Steal(T, Reborn, 44, 0)
	Reborn:SetAttribute("Rebirths", 1)
	f:KO(T, H)
	check(f:Mail(Reborn.UserId) == nil and f:BankOf(Reborn) == 0, "a present victim from another life gets no pay and no mail (CR-M6)")
	local T6, V6 = f:Add("ThiefSix", "Horns"), f:Add("Six", "Halo")
	f:Steal(T6, V6, 25, 0)
	f:Leave(V6)
	f:Leave(T6)
	local b6 = f:Mail(V6.UserId)
	check(type(b6) == "table" and b6[1] ~= nil and b6[1].K == "Returned" and b6[1].A == 25, "thief leaves: absent victims get a Returned letter", show(b6))
	local Many = f:Add("Many", "Halo")
	local thieves = {}
	for i = 1, 25 do
		thieves[i] = f:Add("T" .. i, "Horns")
		f:Steal(thieves[i], Many, i, 0)
	end
	f:Leave(Many)
	for i = 1, 25 do f:KO(thieves[i], nil) end
	local bm = f:Mail(Many.UserId)
	check(type(bm) == "table" and #bm == 20 and bm[1].A == 6 and bm[20].A == 25, "MailMax 20: letters are appended and the oldest are dropped",
		show({ bm and #bm, bm and bm[1] and bm[1].A, bm and bm[#bm] and bm[#bm].A }))
	-- the DataStore is down for good: 4 tries, the sack still resolves, present victims still paid
	local d = grudgeWorld()
	local Td, Vd, Pd = d:Add("Thief", "Horns"), d:Add("Gone", "Halo"), d:Add("Here", "Halo")
	d:Steal(Td, Vd, 100, 0)
	d:Steal(Td, Pd, 10, 0)
	d:Leave(Vd)
	d.DSFail = true
	d:KO(Td, nil)
	check(not d.Svc.HasSack(Td) and d:BankOf(Pd, "Refund") == 10 and (d.Resolved[1] or {}).Outcome == "Returned",
		"a failing mail send never blocks the sack: it resolves and present victims are paid")
	d:Advance(10)
	check(d:TakeWarnings("grudge mail send") == 4 and d:Pending() == 0 and d:Mail(Vd.UserId) == nil,
		"DataStore down: 4 caught tries, each warned, then MailPending back to 0", show(d.Warnings))
	-- GetDataStore throws (no API access): no crash, nothing written, nothing pending
	local e = grudgeWorld({ GetStoreFail = true })
	local Te, Ve = e:Add("Thief", "Horns"), e:Add("Gone", "Halo")
	e:Steal(Te, Ve, 100, 0)
	e:Leave(Ve)
	e:KO(Te, nil)
	check(not e.Svc.HasSack(Te) and next(e.Rows) == nil and #e.Bank == 0 and e:Pending() == 0,
		"GetDataStore failing: the sack resolves without a crash, nothing is written or left pending")
	check(e:TakeWarnings("grudge mail store unavailable") >= 1, "GetDataStore failing is warned (and retried later)",
		show(e.Warnings))
end)

runGroup("mail-retry", function()
	-- two transient failures: retried after 1 s and 2 s more, written once
	local f = grudgeWorld()
	local T, V = f:Add("Thief", "Horns"), f:Add("Gone", "Halo")
	local key = "M_" .. tostring(V.UserId)
	local sackId = tostring(T.UserId) .. ":" .. tostring(f:Time())
	f:Steal(T, V, 100, 0)
	f:Leave(V)
	local before = f:Calls(key)
	f.FailNext = 2
	f:KO(T, nil)
	check(f:Pending() == 1 and f:Mail(V.UserId) == nil and f:Calls(key) == before + 1, "a failed send stays pending (MailPending 1)",
		show({ f:Pending(), f:Calls(key) - before }))
	f:Advance(0.9)
	check(f:Calls(key) == before + 1, "no retry before 1 s")
	f:Advance(0.2)
	check(f:Calls(key) == before + 2 and f:Pending() == 1, "second try 1 s later (fails again)", f:Calls(key) - before)
	f:Advance(1.8)
	check(f:Calls(key) == before + 2, "no third try before 2 more seconds")
	f:Advance(0.2)
	local box = f:Mail(V.UserId)
	check(f:Calls(key) == before + 3 and type(box) == "table" and #box == 1 and box[1].A == 100 and box[1].Id == sackId .. ":Returned",
		"third try (2 s after the second) writes the letter once", show(box))
	check(f:Pending() == 0, "MailPending back to 0 after the write", f:Pending())
	check(f:TakeWarnings("grudge mail send 1/4 failed") == 1 and f:TakeWarnings("grudge mail send 2/4 failed") == 1,
		"each failed try is warned with its number (1/4, 2/4)", show(f.Warnings))
	f:Advance(30)
	check(f:Calls(key) == before + 3 and #f:Mail(V.UserId) == 1, "no further tries after the success")
	-- written, but the reply was lost: the retry finds its own Id and does not append again
	local g = grudgeWorld()
	local Tg, Vg = g:Add("Thief", "Horns"), g:Add("Gone", "Halo")
	g:Steal(Tg, Vg, 70, 0)
	g:Leave(Vg)
	g.FailAfterWrite = 1
	g:KO(Tg, nil)
	check(g:Pending() == 1 and type(g:Mail(Vg.UserId)) == "table" and #g:Mail(Vg.UserId) == 1, "a write whose reply was lost is retried")
	g:Advance(1.1)
	local gb = g:Mail(Vg.UserId)
	check(type(gb) == "table" and #gb == 1 and gb[1].A == 70 and g:Pending() == 0, "the retry sees the letter Id and does not append it twice", show(gb))
	check(g:TakeWarnings("grudge mail send 1/4 failed") == 1, "the lost reply is warned once")
	-- all four tries fail: 0 s, +1 s, +2 s, +4 s, then give up
	local h = grudgeWorld()
	local Th, Vh = h:Add("Thief", "Horns"), h:Add("Gone", "Halo")
	local hkey = "M_" .. tostring(Vh.UserId)
	h:Steal(Th, Vh, 50, 0)
	h:Leave(Vh)
	local hb = h:Calls(hkey)
	h.DSFail = true
	h:KO(Th, nil)
	h:Advance(6.9)
	check(h:Calls(hkey) == hb + 3 and h:Pending() == 1, "after 6.9 s: 3 tries, still pending", h:Calls(hkey) - hb)
	h:Advance(0.2)
	check(h:Calls(hkey) == hb + 4 and h:Pending() == 0, "the 4th try at 7 s is the last; MailPending 0", h:Calls(hkey) - hb)
	h:Advance(60)
	check(h:Calls(hkey) == hb + 4 and h:TakeWarnings("grudge mail send") == 4, "no 5th try; 4 warnings (1/4..4/4)")
	-- two sacks of the same thief (different seconds) are two different letters
	local k = grudgeWorld()
	local Tk, Vk = k:Add("Thief", "Horns"), k:Add("Gone", "Halo")
	k:Steal(Tk, Vk, 10, 0)
	k:Leave(Vk)
	k:KO(Tk, nil)
	k:Advance(20)
	local Vk2 = k:Add("Gone", "Halo", { UserId = Vk.UserId }) -- rejoins: takes letter 1
	k:Steal(Tk, Vk2, 30, 0)
	k:Leave(Vk2)
	k:KO(Tk, nil)
	local kb = k:Mail(Vk.UserId)
	check(k:BankOf(Vk2, "Refund") == 10 and type(kb) == "table" and #kb == 1 and kb[1].A == 30,
		"the same thief's next sack (20 s later) is a new letter, not a duplicate", show({ k:BankOf(Vk2), kb }))
end)

local function letter(a, r, k) return { A = a, R = r, K = k, T = TIME_BASE } end
local MAIL_UID = 777001
-- o: Rebirths, RefundAgo (refund:0 set that many seconds ago), Inline (fallback pairReady), Fail (DataStore errors)
local function receiveWorld(letters, o)
	o = o or {}
	local rows = {}
	if letters ~= nil then rows["M_" .. MAIL_UID] = deepCopy(letters) end
	local f = grudgeWorld({ Rows = rows, InlinePairReady = o.Inline })
	f.DSFail = o.Fail == true
	local pairCD = {}
	if o.RefundAgo then pairCD["refund:0"] = f:Time() - o.RefundAgo end
	local p = f:Add("Mailee", "Halo", { UserId = MAIL_UID, Rebirths = o.Rebirths or 0, PairCD = pairCD })
	return f, p
end

runGroup("mail-receive", function()
	local cases = {
		{ "one Avenged letter with the refund bonus ready pays 120%", { letter(100, 0, "Avenged") }, 120 },
		{ "only the first Avenged letter gets 120%", { letter(100, 0, "Avenged"), letter(50, 0, "Avenged"), letter(30, 0, "Returned") }, 200 },
		{ "Returned letters never get the bonus; the first Avenged one does", { letter(100, 0, "Returned"), letter(50, 0, "Avenged") }, 160 },
		{ "refund bonus on cooldown (10 s ago) pays 100%", { letter(100, 0, "Avenged") }, 100, { RefundAgo = 10 } },
		{ "refund cooldown just over (600 s ago) pays 120%", { letter(100, 0, "Avenged") }, 120, { RefundAgo = 600 } },
		{ "other-life letters are skipped; the bonus goes to the first same-life Avenged letter",
			{ letter(100, 0, "Avenged"), letter(50, 1, "Avenged"), letter(40, 1, "Returned") }, 100, { Rebirths = 1 } },
		{ "malformed letters are skipped (numbers as strings still count)",
			{ "junk", 5, letter(-10, 0, "Avenged"), { A = "40", R = "0", K = "Returned" }, { A = 10.7, K = "Returned" } }, 50 },
	}
	for _, c in cases do
		local f, p = receiveWorld(c[2], c[4])
		local paid = f:BankOf(p, "Refund")
		check(paid == c[3], "mail at join: " .. c[1], show({ paid = paid, want = c[3] }))
		check(#f.Bank == 1 and f.Bank[1].Source == "Refund" and f.Bank[1].Player == p, "one bank payment (ProgressionService.AddBankGold, source Refund)",
			c[1] .. " " .. show(f.Bank))
		check(f.Bank[1] ~= nil and type(f.Bank[1].MailRow) == "table" and #f.Bank[1].MailRow == 0,
			"the mailbox was already cleared ({}) when the gold was paid", show(f.Bank[1] and f.Bank[1].MailRow))
		check(f:Told(p, f:Text("GrudgeMail", f.Util.FormatNumber(c[3])), "good") == 1 and f:NoticeCount(p) == 1,
			"exactly one GrudgeMail notice with the total", show(f.Notices))
		f:Leave(p)
		local again = f:Add("Mailee", "Halo", { UserId = MAIL_UID, Rebirths = (c[4] or {}).Rebirths or 0, Data = p.Data })
		check(f:BankOf(again) == 0 and f:NoticeCount(again) == 0, "a second join pays nothing (letters were taken)")
	end
	local f1, p1 = receiveWorld({ letter(100, 0, "Avenged") })
	check(p1.Data.PairCD["refund:0"] == f1:Time(), "a mailed 120% commits the victim's refund:0 cooldown", show(p1.Data.PairCD))
	local f2, p2 = receiveWorld({ letter(100, 0, "Returned"), letter(-5, 0, "Avenged"), letter(40, 1, "Avenged") })
	check(p2.Data.PairCD["refund:0"] == nil and f2:BankOf(p2) == 100, "skipped (negative / other-life) and Returned letters never use the refund bonus",
		show({ p2.Data.PairCD, f2:BankOf(p2) }))
	local f3, p3 = receiveWorld({ letter(100, 0, "Avenged") }, { RefundAgo = 10 })
	check(p3.Data.PairCD["refund:0"] == f3:Time() - 10, "a refused bonus does not restart the cooldown", show(p3.Data.PairCD))
	for _, c in { { "no mailbox", nil, nil }, { "empty mailbox", {}, nil },
		{ "only other-life letters", { letter(100, 0, "Avenged"), letter(9, 0, "Returned") }, { Rebirths = 3 } } } do
		local f, p = receiveWorld(c[2], c[3])
		check(#f.Bank == 0 and f:NoticeCount(p) == 0, "nothing to pay -> no gold and no notice", c[1])
		check(p.Data.PairCD["refund:0"] == nil, "nothing to pay -> the refund bonus is not consumed", c[1])
	end
	local f0, p0 = receiveWorld(nil)
	check(f0:Mail(p0.UserId) == nil, "no mailbox: the reader writes nothing (UpdateAsync returns nil)", show(f0.Rows))
	local fo, po = receiveWorld({ letter(100, 0, "Avenged") }, { Rebirths = 3 })
	check(type(fo:Mail(po.UserId)) == "table" and #fo:Mail(po.UserId) == 0, "other-life letters are taken (cleared) and never paid")
	-- DataStore errors are caught; the letters wait for the next join
	local ff, pf = receiveWorld({ letter(100, 0, "Avenged") }, { Fail = true })
	check(#ff.Bank == 0 and ff:NoticeCount(pf) == 0, "DataStore error at join: nothing paid, no notice")
	check(ff:TakeWarnings("grudge mail read failed") == 1, "the read error is caught (pcall) and warned once", show(ff.Warnings))
	check(type(ff:Mail(pf.UserId)) == "table" and #ff:Mail(pf.UserId) == 1, "the letters stay for the next join")
	ff.DSFail = false
	ff:Leave(pf)
	local pf2 = ff:Add("Mailee", "Halo", { UserId = MAIL_UID })
	check(ff:BankOf(pf2, "Refund") == 120, "the next join pays them", ff:BankOf(pf2))
	-- canPay before reading: a victim without save data is not even read
	local rowsN = { ["M_" .. MAIL_UID] = { letter(100, 0, "Avenged") } }
	local fn = grudgeWorld({ Rows = rowsN })
	local pn = fn:Add("Mailee", "Halo", { UserId = MAIL_UID, NoData = true })
	check(fn:Calls("M_" .. MAIL_UID) == 0 and #fn.Bank == 0 and #rowsN["M_" .. MAIL_UID] == 1,
		"no save data (cannot be paid): the mailbox is not touched", show({ calls = fn:Calls("M_" .. MAIL_UID), bank = #fn.Bank }))
	check(fn:NoticeCount(pn) == 0, "... and no notice")
	-- canPay after emptying: the victim leaves while the read is in flight -> the letters are written back
	local rowsL = { ["M_" .. MAIL_UID] = { letter(100, 0, "Avenged"), letter(30, 0, "Returned") } }
	local fl = grudgeWorld({ Rows = rowsL })
	local fired = false
	fl.OnUpdate = function()
		if fired then return end
		fired = true
		for _, p in fl.PlayerList do if p.UserId == MAIL_UID then p.Parent = nil end end
	end
	local pl = fl:Add("Mailee", "Halo", { UserId = MAIL_UID })
	local back = fl:Mail(MAIL_UID)
	check(fl:BankOf(pl) == 0 and type(back) == "table" and #back == 2 and back[1].A == 100 and back[2].A == 30,
		"leaving during the read: nothing paid, the letters are written back", show({ fl:BankOf(pl), back }))
	check(pl.Data.PairCD["refund:0"] == nil, "... and the refund bonus is not consumed")
	fl.OnUpdate = nil
	local pl2 = fl:Add("Mailee", "Halo", { UserId = MAIL_UID })
	check(fl:BankOf(pl2, "Refund") == 150, "the next join pays the written-back letters (120 + 30)", fl:BankOf(pl2))
	-- write-back cap: MailMax
	local full = {}
	for i = 1, 20 do full[i] = letter(i, 0, "Returned") end
	local rowsC = { ["M_" .. MAIL_UID] = full }
	local fc = grudgeWorld({ Rows = rowsC })
	local ccalls = 0
	fc.BeforeUpdate = function(k)
		ccalls += 1
		if ccalls == 2 then -- a new letter lands between the read and the write-back
			local cur = fc.Rows[k] or {}
			table.insert(cur, letter(999, 0, "Returned"))
			fc.Rows[k] = cur
		end
	end
	fc.OnUpdate = function()
		if ccalls ~= 1 then return end
		for _, p in fc.PlayerList do if p.UserId == MAIL_UID then p.Parent = nil end end
	end
	fc:Add("Mailee", "Halo", { UserId = MAIL_UID })
	local cb = fc:Mail(MAIL_UID)
	check(type(cb) == "table" and #cb == 20, "the write-back keeps at most MailMax letters", show({ cb and #cb }))
	local hasLate = false
	for _, m in (type(cb) == "table" and cb or {}) do if type(m) == "table" and m.A == 999 then hasLate = true end end
	check(hasLate, "write-back puts the taken (older) letters in front: a full box drops the oldest, never the newest letter",
		show({ cb and #cb }))
	-- observation: the write-back itself fails
	local rowsW = { ["M_" .. MAIL_UID] = { letter(100, 0, "Avenged") } }
	local fw = grudgeWorld({ Rows = rowsW })
	fw.OnUpdate = function()
		if fw.Hooked then return end
		fw.Hooked = true
		for _, p in fw.PlayerList do if p.UserId == MAIL_UID then p.Parent = nil end end
		fw.FailNext = 1 -- the write-back call
	end
	fw:Add("Mailee", "Halo", { UserId = MAIL_UID })
	local wb = fw:Mail(MAIL_UID)
	check(fw:TakeWarnings("grudge mail write-back failed") == 1, "a failed write-back is warned once (letters lost, never paid twice)",
		show({ wb and #wb, fw.Warnings }))
	-- GrudgeService's own pairReady fallback (no PlayerService.PairReady) follows the same rule
	local fi, pi = receiveWorld({ letter(100, 0, "Avenged"), letter(50, 0, "Avenged") }, { Inline = true })
	check(fi:BankOf(pi) == 170 and pi.Data.PairCD["refund:0"] == fi:Time(), "fallback pairReady: 120% for the first Avenged letter only",
		show({ fi:BankOf(pi), pi.Data.PairCD }))
	local fj, pj = receiveWorld({ letter(100, 0, "Avenged") }, { Inline = true, RefundAgo = 5 })
	check(fj:BankOf(pj) == 100, "fallback pairReady respects the refund cooldown", fj:BankOf(pj))
end)

runGroup("mail-roundtrip", function()
	-- server A: the victim hops away; the sacks resolve there. Server B: the victim joins and is paid.
	local rows = {}
	local A = grudgeWorld({ Rows = rows })
	local T1, T2 = A:Add("Thief", "Horns"), A:Add("ThiefTwo", "Horns")
	local V = A:Add("Traveler", "Halo", { UserId = 555001, Rebirths = 1 })
	local H = A:Add("Knight", "Halo")
	A:Steal(T1, V, 250, 0)
	A:Steal(T1, V, 50, 0)
	A:Steal(T2, V, 40, 0)
	A:Leave(V)
	A:KO(T1, H)
	A:KO(T2, nil)
	local box = rows["M_555001"]
	check(type(box) == "table" and #box == 2 and box[1].A == 300 and box[1].K == "Avenged" and box[2].A == 40 and box[2].K == "Returned"
		and box[1].R == 1 and box[1].Id ~= box[2].Id, "server A wrote one letter per resolved sack (accumulated share, R = 1, own Ids)", show(box))
	local B = grudgeWorld({ Rows = rows })
	local Vb = B:Add("Traveler", "Halo", { UserId = 555001, Rebirths = 1 })
	check(B:BankOf(Vb, "Refund") == 360 + 40, "server B pays 300 x 120% + 40 x 100% at join", B:BankOf(Vb))
	check(B:Told(Vb, B:Text("GrudgeMail", "400"), "good") == 1 and B:NoticeCount(Vb) == 1, "one GrudgeMail notice with 400")
	check(type(rows["M_555001"]) == "table" and #rows["M_555001"] == 0, "the shared mailbox is empty afterwards")
	local C = grudgeWorld({ Rows = rows })
	local Vc = C:Add("Traveler", "Halo", { UserId = 555001, Rebirths = 1 })
	check(C:BankOf(Vc) == 0 and C:NoticeCount(Vc) == 0, "a third server pays nothing (never double-paid)")
end)

------------------------------------------------------------------ C. A23-18 ghost hold
runGroup("ghost-hold", function()
	local f = grudgeWorld()
	local G = f.G
	local T, V = f:Add("Thief", "Horns"), f:Add("Victim", "Halo")
	f:Steal(T, V, 100, 0)
	T.PvP = true
	f:Ticks(20)
	check(f:Seconds(T) == 40, "5 s in a PvP zone: 40 s left", f:Seconds(T))
	f:Kill(V)
	f:Hold(V)
	check(f:Seconds(T) == 40 and f:NoticeCount(V) == 0, "a dead victim cannot hold")
	f:Revive(V)
	local t0 = f.Now
	f:Hold(V)
	check(f:Seconds(T) == 42, "the respawned victim holds: +2 s on the thief's countdown (SackSeconds published)", f:Seconds(T))
	check(T:GetAttribute("SackHeldUntil") == t0 + G.HoldGlowSeconds, "thief SackHeldUntil = Util.Now() + HoldGlowSeconds",
		show({ T:GetAttribute("SackHeldUntil"), t0 }))
	check(f:Told(V, f:Text("GhostHoldOk", 2, 10), "good") == 1, "GhostHoldOk to the victim (+2, max 10)")
	check(f:Told(T, f:Text("GhostHeld"), "bad") == 1, "GhostHeld to the thief")
	check(f.Active[V] == 1, "the holding victim is marked active", f.Active[V])
	f:Advance(2.5)
	f:Hold(V)
	check(f:Seconds(T) == 42 and f:Told(V, f:Text("GhostHoldOk", 2, 10)) == 1, "a second press 2.5 s later is refused (RateLimit GhostHold 2.7)")
	f:Advance(0.25)
	f:Hold(V)
	check(f:Seconds(T) == 44 and T:GetAttribute("SackHeldUntil") == t0 + 5.75, "2.75 s after the first press the next one counts", f:Seconds(T))
	f:Advance(0.5)
	check(T:GetAttribute("SackHeldUntil") == t0 + 5.75, "an older press's timer does not switch off a newer glow", T:GetAttribute("SackHeldUntil"))
	f:Advance(2.5)
	check(T:GetAttribute("SackHeldUntil") == t0 + 5.75, "the glow stays on until HoldGlowSeconds + 0.1 after the last press")
	f:Advance(0.25)
	check(T:GetAttribute("SackHeldUntil") == 0, "then it switches off", T:GetAttribute("SackHeldUntil"))
	for _ = 1, 3 do
		f:Hold(V)
		f:Advance(3)
	end
	check(f:Seconds(T) == 50, "five presses = +10 s (45 -> 55 s for this sack)", f:Seconds(T))
	local heldUntil = T:GetAttribute("SackHeldUntil")
	local activeBefore = f.Active[V]
	f:Hold(V)
	check(f:Seconds(T) == 50, "at the +10 s cap nothing changes", f:Seconds(T))
	check(f:Told(V, f:Text("GhostHoldMax", 10), "info") == 1, "the victim gets GhostHoldMax at the cap")
	check(T:GetAttribute("SackHeldUntil") == heldUntil and f:Told(T, f:Text("GhostHeld")) == 5 and f.Active[V] == activeBefore,
		"at the cap the thief is not told and does not glow again", show({ T:GetAttribute("SackHeldUntil"), heldUntil }))
	f:Ticks(40)
	check(f:Seconds(T) == 40, "10 s later: 40 s left", f:Seconds(T))
	local V2 = f:Add("VictimTwo", "Halo")
	f:Steal(T, V2, 30, 0)
	check(f:Seconds(T) == 55, "a new steal restarts at 45 + held seconds (holds are kept, never shortened)", f:Seconds(T))
	f:Ticks(219)
	check(f.Svc.HasSack(T) and #f.Carried == 0, "still carrying 0.25 s before the end")
	f:Tick()
	check(not f.Svc.HasSack(T) and f.Carried[1] ~= nil and f.Carried[1].Amount == 130, "paid after the full 55 s")
end)

runGroup("ghost-hold-refusals", function()
	local f = grudgeWorld()
	local T, V = f:Add("Thief", "Horns"), f:Add("Victim", "Halo")
	f:Steal(T, V, 100, 0)
	f:Hold(V, "extra")
	f:Hold(V, nil)
	f:Hold(V, 1, 2)
	check(f:Seconds(T) == 45 and f:NoticeCount(V) == 0, "GhostHold with any argument (even one nil) is refused")
	f:Hold(V)
	check(f:Seconds(T) == 47, "the plain call right after works (refused calls do not use the rate limit)", f:Seconds(T))
	f:Advance(3)
	V.Ready = false
	f:Hold(V)
	V.Ready = true
	check(f:Seconds(T) == 47, "a victim who is not ready cannot hold")
	f:Advance(3)
	local char = V.Character
	V.Character = nil
	f:Hold(V)
	V.Character = char
	check(f:Seconds(T) == 47, "a victim without a character cannot hold")
	local N = f:Add("Bystander", "Halo")
	f:Hold(N)
	check(f:Seconds(T) == 47 and f:NoticeCount(N) == 0, "a player who was not robbed cannot hold")
	f:Advance(3)
	N:SetAttribute("GrudgeThiefId", T.UserId)
	f:Hold(N)
	check(f:Seconds(T) == 47 and f:NoticeCount(N) == 0, "a stale GrudgeThiefId without a share in that sack cannot hold")
	check(f:Target(N) == 0, "... and the stale button is fixed (pointVictim -> 0)", f:Target(N))
	local T2, V2 = f:Add("ThiefTwo", "Horns"), f:Add("VictimTwo", "Halo")
	f:Steal(T2, V2, 10, 0)
	f:Hold(V2)
	check(f:Seconds(T) == 47 and f:Seconds(T2) == 47, "a victim of another thief holds only that thief's sack", show({ f:Seconds(T), f:Seconds(T2) }))
	f:Advance(3)
	V:SetAttribute("Rebirths", 1)
	f:Hold(V)
	check(f:Seconds(T) == 47, "a victim who rebirthed since cannot hold (sameLife)")
	check(f:Target(V) == 0, "... and the other-life button is fixed to 0", f:Target(V))
	V:SetAttribute("Rebirths", 0)
	f:Leave(T)
	f:Advance(3)
	f:Hold(V)
	check(f:Target(V) == 0 and f:Told(V, f:Text("GhostHoldOk", 2, 10)) == 1, "after the thief leaves the hold does nothing")
	-- min(HoldAddSeconds, room): a cap that is not a multiple of 2
	local g = grudgeWorld({ Grudge = { HoldMaxSeconds = 9 } })
	local Tg, Vg = g:Add("Thief", "Horns"), g:Add("Victim", "Halo")
	g:Steal(Tg, Vg, 10, 0)
	for _ = 1, 5 do
		g:Hold(Vg)
		g:Advance(3)
	end
	check(g:Seconds(Tg) == 54 and g:Told(Vg, g:Text("GhostHoldOk", 1, 9), "good") == 1, "the last press adds only the room left (+1 s up to max 9)",
		g:Seconds(Tg))
	g:Hold(Vg)
	check(g:Seconds(Tg) == 54 and g:Told(Vg, g:Text("GhostHoldMax", 9), "info") == 1, "then GhostHoldMax")
	g:Steal(Tg, Vg, 10, 0)
	g:Advance(3)
	g:Hold(Vg)
	check(g:Seconds(Tg) == 54 and g:Told(Vg, g:Text("GhostHoldMax", 9)) == 2,
		"a new steal into the same sack keeps the used hold seconds (cap per sack, countdown 45 + held)", g:Seconds(Tg))
	g:KO(Tg, nil)
	g:Steal(Tg, Vg, 10, 0)
	g:Advance(3)
	g:Hold(Vg)
	check(g:Seconds(Tg) == 47, "a new sack starts with Held 0 and can be held again", g:Seconds(Tg))
end)

runGroup("ghost-target", function()
	local f = grudgeWorld()
	local T1, T2, V = f:Add("ThiefOne", "Horns"), f:Add("ThiefTwo", "Horns"), f:Add("Victim", "Halo")
	check(f:Target(V) == 0 and V:GetAttribute("SackGold") == 0 and V:GetAttribute("SackSeconds") == 0
		and V:GetAttribute("SackVictimName") == "" and V:GetAttribute("SackHeldUntil") == 0, "PlayerReady resets the sack / ghost attributes", show(V.Attrs))
	f:Steal(T1, V, 10, 0)
	f:Steal(T2, V, 20, 0)
	check(f:Target(V) == T2.UserId, "the newest thief is the hold target")
	f:KO(T1, nil)
	check(f:Target(V) == T2.UserId, "closing ANOTHER thief's sack keeps my target")
	f:Hold(V)
	check(f:Seconds(T2) == 47, "still holding the newer thief", f:Seconds(T2))
	f:KO(T2, nil)
	check(f:Target(V) == 0, "closing the last sack with my share hides the hold button")
	-- the newer thief resolves first while the older one still carries my share: the button moves
	local g = grudgeWorld()
	local A1, A2, W = g:Add("ThiefOne", "Horns"), g:Add("ThiefTwo", "Horns"), g:Add("Victim", "Halo")
	g:Steal(A1, W, 10, 0)
	g:Steal(A2, W, 20, 0)
	g:KO(A2, nil)
	check(g.Svc.HasSack(A1) and g:Target(W) == A1.UserId, "two thieves: closing one sack moves the button to the other open sack",
		show({ target = g:Target(W), older = A1.UserId }))
	g:Hold(W)
	check(g:Seconds(A1) == 47, "... and the victim can hold that sack", g:Seconds(A1))
	g:KO(A1, nil)
	check(g:Target(W) == 0, "... and the button hides when it closes too", g:Target(W))
	-- a thief who is already gone (not yet resolved) is not a target
	local q = grudgeWorld()
	local Q1, Q2, X = q:Add("ThiefOne", "Horns"), q:Add("ThiefTwo", "Horns"), q:Add("Victim", "Halo")
	q:Steal(Q1, X, 10, 0)
	q:Steal(Q2, X, 20, 0)
	Q1.Parent = nil
	q:KO(Q2, nil)
	check(q:Target(X) == 0, "an open sack whose thief already left is not a hold target", q:Target(X))
	-- rebirth (ProgressionService.Rebirthed): older shares are no longer mine to hold
	local r = grudgeWorld()
	local R1, R2, Y = r:Add("ThiefOne", "Horns"), r:Add("ThiefTwo", "Horns"), r:Add("Victim", "Halo")
	r:Steal(R1, Y, 10, 0)
	r:Rebirth(Y, 1)
	check(r:Target(Y) == 0, "Rebirthed: the button of an other-life share hides at once", r:Target(Y))
	r:Advance(3)
	r:Hold(Y)
	check(r:Seconds(R1) == 45, "... and a hold does nothing")
	r:Steal(R2, Y, 20, 0)
	check(r:Target(Y) == R2.UserId, "a new-life steal points at the new thief")
	r:KO(R2, nil)
	check(r:Target(Y) == 0, "closing it does not fall back to the other-life sack", r:Target(Y))
	-- SackHeldUntil cleared at close even during a glow
	local h = grudgeWorld()
	local Th, Vh = h:Add("Thief", "Horns"), h:Add("Victim", "Halo")
	h:Steal(Th, Vh, 10, 0)
	h:Hold(Vh)
	check((Th:GetAttribute("SackHeldUntil") or 0) > 0, "the hold lights the glow")
	h:KO(Th, nil)
	check(Th:GetAttribute("SackHeldUntil") == 0, "closing the sack switches the glow off at once")
	h:Advance(4)
	check(Th:GetAttribute("SackHeldUntil") == 0, "the pending glow timer leaves it off")
	-- rejoin on the same server
	local j = grudgeWorld()
	local Tj, Vj = j:Add("Thief", "Horns"), j:Add("Victim", "Halo")
	j:Steal(Tj, Vj, 70, 0)
	j:Leave(Vj)
	local Vj2 = j:Add("Victim", "Halo", { UserId = Vj.UserId })
	check(j:Target(Vj2) == Tj.UserId, "a rejoin while the thief still carries my share restores GrudgeThiefId", j:Target(Vj2))
	j:Hold(Vj2)
	check(j:Seconds(Tj) == 47, "the rejoined victim can hold", j:Seconds(Tj))
	j:KO(Tj, nil)
	check(j:BankOf(Vj2, "Refund") == 70 and j:Mail(Vj.UserId) == nil, "the rejoined victim is paid directly (no mail)")
	check(j:Target(Vj2) == 0, "and the hold button goes away")
	local Other = j:Add("Other", "Halo")
	check(j:Target(Other) == 0, "a player with no share gets 0 at PlayerReady")
	local k = grudgeWorld()
	local Tk, Vk = k:Add("Thief", "Horns"), k:Add("Victim", "Halo")
	k:Steal(Tk, Vk, 70, 0)
	k:Leave(Vk)
	local Vk2 = k:Add("Victim", "Halo", { UserId = Vk.UserId, Rebirths = 1 })
	check(k:Target(Vk2) == 0, "a rejoin in another life gets no button for the old share", k:Target(Vk2))
end)

------------------------------------------------------------------ summary
local list = {}
for _, key in order do
	local r = results[key]
	table.insert(list, { Group = r.Group, Name = r.Name, Pass = r.Pass, Fail = r.Fail, FirstFailure = r.First })
end
local function enc(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then return (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.17g", v) end
	if t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, enc(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do table.insert(keys, k) end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, enc(tostring(k)) .. ":" .. enc(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end
print("GRUDGE_RESULT_JSON " .. enc({ Checks = total, Failed = failedCount, Named = list, Findings = findings }))
if failedCount == 0 then
	print("GRUDGE_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
else
	print("GRUDGE_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
end
